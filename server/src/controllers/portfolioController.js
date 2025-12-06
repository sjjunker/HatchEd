// Updated with assistance from Cursor (ChatGPT) on 11/7/25.

import { ObjectId } from 'mongodb'
import { findUserById } from '../models/userModel.js'
import { createPortfolio, findPortfoliosByFamilyId, findPortfolioById, updatePortfolio, deletePortfolio } from '../models/portfolioModel.js'
import { findStudentWorkFilesByStudentId, createStudentWorkFile, findStudentWorkFileById } from '../models/studentWorkFileModel.js'
import { serializePortfolio, serializeStudentWorkFile } from '../utils/serializers.js'
import { compilePortfolioWithChatGPT } from '../services/chatgptService.js'
import multer from 'multer'
import path from 'path'
import fs from 'fs/promises'

// Configure multer for file uploads
// Accepts all file types (documents, images, videos, etc.)
const upload = multer({
  dest: 'uploads/',
  limits: { fileSize: 50 * 1024 * 1024 }, // 50MB limit
  // No fileFilter - accepts all file types
})

export async function getPortfoliosHandler (req, res) {
  const user = await findUserById(req.user.userId)
  if (!user || !user.familyId) {
    return res.json({ portfolios: [] })
  }

  const portfolios = await findPortfoliosByFamilyId(user.familyId)
  const portfoliosWithDetails = portfolios.map(portfolio => serializePortfolio(portfolio))
  res.json({ portfolios: portfoliosWithDetails })
}

export async function createPortfolioHandler (req, res) {
  const { studentId, studentName, designPattern, studentWorkFileIds, studentRemarks, instructorRemarks, reportCardSnapshot } = req.body

  if (!studentId || !studentName || !designPattern) {
    return res.status(400).json({ error: { message: 'Student ID, name, and design pattern are required' } })
  }

  const user = await findUserById(req.user.userId)
  if (!user || !user.familyId) {
    return res.status(400).json({ error: { message: 'User must belong to a family' } })
  }

  // Verify student belongs to the same family
  const student = await findUserById(studentId)
  if (!student || student.familyId?.toString() !== user.familyId.toString()) {
    return res.status(400).json({ error: { message: 'Student must belong to the same family' } })
  }

  // Fetch student work files
  const studentWorkFiles = await Promise.all(
    studentWorkFileIds.map(async (fileId) => {
      return await findStudentWorkFileById(fileId)
    })
  )

  // Compile portfolio with ChatGPT
  let compiledContent = ''
  let snippet = ''
  try {
    const compilationResult = await compilePortfolioWithChatGPT({
      studentName,
      designPattern,
      studentWorkFiles: studentWorkFiles.filter(Boolean),
      studentRemarks,
      instructorRemarks,
      reportCardSnapshot
    })
    compiledContent = compilationResult.content
    snippet = compilationResult.snippet
  } catch (error) {
    console.error('Error compiling portfolio with ChatGPT:', error)
    // Continue with empty content - portfolio will be created but not compiled
    compiledContent = 'Portfolio compilation pending. Please try again later.'
    snippet = 'Portfolio compilation in progress...'
  }

  const portfolio = await createPortfolio({
    familyId: user.familyId,
    studentId,
    studentName,
    designPattern,
    studentWorkFileIds,
    studentRemarks,
    instructorRemarks,
    reportCardSnapshot,
    compiledContent,
    snippet
  })

  res.status(201).json({ portfolio: serializePortfolio(portfolio) })
}

export async function getPortfolioHandler (req, res) {
  const { id } = req.params

  const user = await findUserById(req.user.userId)
  if (!user || !user.familyId) {
    return res.status(400).json({ error: { message: 'User must belong to a family' } })
  }

  const portfolio = await findPortfolioById(id)
  if (!portfolio) {
    return res.status(404).json({ error: { message: 'Portfolio not found' } })
  }

  if (portfolio.familyId.toString() !== user.familyId.toString()) {
    return res.status(403).json({ error: { message: 'Not authorized' } })
  }

  res.json({ portfolio: serializePortfolio(portfolio) })
}

export async function deletePortfolioHandler (req, res) {
  const { id } = req.params

  const user = await findUserById(req.user.userId)
  if (!user || !user.familyId) {
    return res.status(400).json({ error: { message: 'User must belong to a family' } })
  }

  const portfolio = await findPortfolioById(id)
  if (!portfolio) {
    return res.status(404).json({ error: { message: 'Portfolio not found' } })
  }

  if (portfolio.familyId.toString() !== user.familyId.toString()) {
    return res.status(403).json({ error: { message: 'Not authorized' } })
  }

  await deletePortfolio(id)
  res.json({ success: true })
}

// Student Work Files
export async function getStudentWorkFilesHandler (req, res) {
  const { studentId } = req.params

  const user = await findUserById(req.user.userId)
  if (!user || !user.familyId) {
    return res.json({ files: [] })
  }

  // Verify student belongs to the same family
  const student = await findUserById(studentId)
  if (!student || student.familyId?.toString() !== user.familyId.toString()) {
    return res.status(403).json({ error: { message: 'Not authorized' } })
  }

  const files = await findStudentWorkFilesByStudentId(studentId)
  const filesWithDetails = files.map(file => serializeStudentWorkFile(file))
  res.json({ files: filesWithDetails })
}

export async function uploadStudentWorkFileHandler (req, res) {
  const user = await findUserById(req.user.userId)
  if (!user || !user.familyId) {
    return res.status(400).json({ error: { message: 'User must belong to a family' } })
  }

  const { studentId } = req.body
  if (!studentId) {
    return res.status(400).json({ error: { message: 'Student ID is required' } })
  }

  // Verify student belongs to the same family
  const student = await findUserById(studentId)
  if (!student || student.familyId?.toString() !== user.familyId.toString()) {
    return res.status(403).json({ error: { message: 'Not authorized' } })
  }

  if (!req.file) {
    return res.status(400).json({ error: { message: 'No file uploaded' } })
  }

  // In production, you'd want to upload to cloud storage (S3, etc.)
  // For now, we'll store the file path
  const fileUrl = `/uploads/${req.file.filename}`
  const fileSize = req.file.size
  const fileName = req.file.originalname || req.file.filename
  const fileType = req.file.mimetype || 'application/octet-stream'

  const file = await createStudentWorkFile({
    familyId: user.familyId,
    studentId,
    fileName,
    fileUrl,
    fileType,
    fileSize
  })

  res.status(201).json({ file: serializeStudentWorkFile(file) })
}

// Export multer middleware
export { upload }

