// Updated with assistance from Cursor (ChatGPT) on 11/7/25.

import { ObjectId } from 'mongodb'
import { findUserById } from '../models/userModel.js'
import { createPortfolio, findPortfoliosByFamilyId, findPortfolioById, updatePortfolio, deletePortfolio } from '../models/portfolioModel.js'
import { findStudentWorkFilesByStudentId, createStudentWorkFile, findStudentWorkFileById } from '../models/studentWorkFileModel.js'
import { findCoursesByStudentId } from '../models/courseModel.js'
import { findAttendanceForStudent } from '../models/attendanceModel.js'
import { serializePortfolio, serializeStudentWorkFile, serializeCourse } from '../utils/serializers.js'
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
  fileFilter: (req, file, cb) => {
    console.log('[Multer] File filter called', {
      fieldname: file.fieldname,
      originalname: file.originalname,
      mimetype: file.mimetype
    })
    cb(null, true) // Accept all files
  }
})

// Error handling middleware for multer
const handleMulterError = (err, req, res, next) => {
  if (err instanceof multer.MulterError) {
    console.error('[Multer] Multer error', {
      code: err.code,
      message: err.message,
      field: err.field
    })
    if (err.code === 'LIMIT_FILE_SIZE') {
      return res.status(400).json({ error: { message: 'File too large. Maximum size is 50MB.' } })
    }
    return res.status(400).json({ error: { message: `Upload error: ${err.message}` } })
  } else if (err) {
    console.error('[Multer] Unknown error', {
      message: err.message,
      stack: err.stack
    })
    return res.status(500).json({ error: { message: 'File upload failed' } })
  }
  next()
}

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
  const { studentId, studentName, designPattern, studentWorkFileIds, studentRemarks, instructorRemarks, reportCardSnapshot, sectionData } = req.body

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

  // Fetch courses for the student
  const courses = await findCoursesByStudentId(studentId)
  const coursesWithDetails = await Promise.all(
    courses.map(async (course) => {
      const student = await findUserById(course.studentUserId)
      return serializeCourse(course, student)
    })
  )

  // Fetch attendance records for the student
  let attendanceSummary = null
  try {
    const attendanceRecords = await findAttendanceForStudent({
      familyId: user.familyId,
      studentUserId: studentId,
      limit: 365 // Last year
    })
    
    if (attendanceRecords && attendanceRecords.length > 0) {
      const attended = attendanceRecords.filter(r => r.isPresent).length
      const missed = attendanceRecords.filter(r => !r.isPresent).length
      const total = attended + missed
      const average = total > 0 ? attended / total : 0
      
      // Calculate streak
      const sortedRecords = attendanceRecords.sort((a, b) => new Date(b.date) - new Date(a.date))
      let streak = 0
      for (const record of sortedRecords) {
        if (record.isPresent) {
          streak++
        } else {
          break
        }
      }
      
      attendanceSummary = {
        classesAttended: attended,
        classesMissed: missed,
        average: average,
        streakDays: streak
      }
    }
  } catch (error) {
    console.warn('Error fetching attendance for portfolio:', error)
  }

  // Compile portfolio with ChatGPT
  let compiledContent = ''
  let snippet = ''
  let generatedImages = []
  try {
    const compilationResult = await compilePortfolioWithChatGPT({
      studentName,
      designPattern,
      studentWorkFiles: studentWorkFiles.filter(Boolean),
      studentRemarks,
      instructorRemarks,
      reportCardSnapshot,
      attendanceSummary,
      courses: coursesWithDetails,
      sectionData
    })
    compiledContent = compilationResult.content
    snippet = compilationResult.snippet
    generatedImages = compilationResult.images || []
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
    sectionData: sectionData || null,
    compiledContent,
    snippet,
    generatedImages
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
  try {
    console.log('[Upload] Starting file upload handler', {
      userId: req.user?.userId,
      hasFile: !!req.file,
      body: req.body,
      timestamp: new Date().toISOString()
    })

    const user = await findUserById(req.user.userId)
    if (!user || !user.familyId) {
      console.error('[Upload] User validation failed', { userId: req.user?.userId })
      return res.status(400).json({ error: { message: 'User must belong to a family' } })
    }

    const { studentId } = req.body
    if (!studentId) {
      console.error('[Upload] Student ID missing', { body: req.body })
      return res.status(400).json({ error: { message: 'Student ID is required' } })
    }

    // Verify student belongs to the same family
    const student = await findUserById(studentId)
    if (!student || student.familyId?.toString() !== user.familyId.toString()) {
      console.error('[Upload] Student authorization failed', {
        studentId,
        studentFamilyId: student?.familyId?.toString(),
        userFamilyId: user.familyId?.toString()
      })
      return res.status(403).json({ error: { message: 'Not authorized' } })
    }

    if (!req.file) {
      console.error('[Upload] No file in request', {
        files: req.files,
        body: req.body,
        headers: req.headers['content-type']
      })
      return res.status(400).json({ error: { message: 'No file uploaded' } })
    }

    console.log('[Upload] File received', {
      filename: req.file.filename,
      originalname: req.file.originalname,
      mimetype: req.file.mimetype,
      size: req.file.size,
      path: req.file.path
    })

    // In production, you'd want to upload to cloud storage (S3, etc.)
    // For now, we'll store the file path
    const fileUrl = `/uploads/${req.file.filename}`
    const fileSize = req.file.size
    const fileName = req.file.originalname || req.file.filename
    const fileType = req.file.mimetype || 'application/octet-stream'

    console.log('[Upload] Creating student work file record', {
      studentId,
      fileName,
      fileType,
      fileSize,
      fileUrl
    })

    const file = await createStudentWorkFile({
      familyId: user.familyId,
      studentId,
      fileName,
      fileUrl,
      fileType,
      fileSize
    })

    if (!file) {
      console.error('[Upload] Failed to create file record in database')
      return res.status(500).json({ error: { message: 'Failed to save file record' } })
    }

    console.log('[Upload] File uploaded successfully', {
      fileId: file._id?.toString(),
      fileName: file.fileName
    })

    res.status(201).json({ file: serializeStudentWorkFile(file) })
  } catch (error) {
    console.error('[Upload] Error in upload handler', {
      error: error.message,
      stack: error.stack,
      timestamp: new Date().toISOString()
    })
    res.status(500).json({ error: { message: error.message || 'Internal server error' } })
  }
}

// Export multer middleware
export { upload, handleMulterError }

