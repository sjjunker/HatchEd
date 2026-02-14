// Updated with assistance from Cursor (ChatGPT) on 11/7/25.

import { ObjectId } from 'mongodb'
import { findUserById } from '../models/userModel.js'
import { createPortfolio, findPortfoliosByFamilyId, findPortfolioById, updatePortfolio, deletePortfolio, portfoliosCollection } from '../models/portfolioModel.js'
import { findStudentWorkFilesByStudentId, createStudentWorkFile, findStudentWorkFileById, deleteStudentWorkFile } from '../models/studentWorkFileModel.js'
import { findCoursesByStudentId } from '../models/courseModel.js'
import { findAttendanceForStudent } from '../models/attendanceModel.js'
import { serializePortfolio, serializeStudentWorkFile, serializeCourse } from '../utils/serializers.js'
import { compilePortfolioWithChatGPT } from '../services/chatgptService.js'
import multer from 'multer'
import path from 'path'
import fs from 'fs/promises'
import { UPLOADS_DIR } from '../lib/uploadsPath.js'

// Max size for student work file uploads (stored in MongoDB as base64)
const MAX_STUDENT_WORK_FILE_SIZE = 10 * 1024 * 1024 // 10MB

// Configure multer for file uploads (temp dir; we read into DB then delete)
const upload = multer({
  dest: UPLOADS_DIR,
  limits: { fileSize: MAX_STUDENT_WORK_FILE_SIZE },
  fileFilter: (req, file, cb) => {
    console.log('[Multer] File filter called', {
      fieldname: file.fieldname,
      originalname: file.originalname,
      mimetype: file.mimetype
    })
    cb(null, true)
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
      return res.status(400).json({ error: { message: `File too large. Maximum size is ${MAX_STUDENT_WORK_FILE_SIZE / (1024 * 1024)}MB.` } })
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
  console.log('[Portfolio Controller] Found', portfolios.length, 'portfolios for family', user.familyId)
  
  const portfoliosWithDetails = portfolios.map(portfolio => serializePortfolio(portfolio))
  
  // Log first portfolio structure for debugging
  if (portfoliosWithDetails.length > 0) {
    console.log('[Portfolio Controller] Sample portfolio structure:', {
      id: portfoliosWithDetails[0].id,
      studentName: portfoliosWithDetails[0].studentName,
      designPattern: portfoliosWithDetails[0].designPattern,
      hasGeneratedImages: Array.isArray(portfoliosWithDetails[0].generatedImages),
      generatedImagesCount: portfoliosWithDetails[0].generatedImages?.length || 0
    })
  }
  
  res.json({ portfolios: portfoliosWithDetails })
}

export async function createPortfolioHandler (req, res) {
  const { studentId, studentName, designPattern, studentWorkFileIds, usePhotoFileIds, studentRemarks, instructorRemarks, reportCardSnapshot, sectionData } = req.body

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
    (studentWorkFileIds || []).map(async (fileId) => {
      return await findStudentWorkFileById(fileId)
    })
  )
  const validWorkFiles = studentWorkFiles.filter(Boolean)
  const providedPhotoWorkFiles = (usePhotoFileIds || [])
    .map((id) => validWorkFiles.find((f) => f._id?.toString() === id))
    .filter(Boolean)

  // Read text from work files for quote extraction (text, DOCX, PDF, Pages from DB fileData)
  const { canExtractText, extractTextFromBuffer } = await import('../utils/documentTextExtractor.js')
  const textExcerpts = []
  for (const file of validWorkFiles) {
    if (!file.fileData || !canExtractText(file.fileType, file.fileName)) continue
    try {
      const buffer = Buffer.from(file.fileData, 'base64')
      const content = await extractTextFromBuffer(buffer, file.fileType, file.fileName)
      if (content && content.trim().length > 0) {
        textExcerpts.push({ fileName: file.fileName || 'document', text: content })
      }
    } catch (err) {
      console.warn('[Portfolio Controller] Could not extract text for quotes:', file.fileName, err.message)
    }
  }

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
  let compilationWarnings = []
  
  try {
    console.log('[Portfolio Controller] Starting portfolio compilation...')
    const compilationResult = await compilePortfolioWithChatGPT({
      studentName,
      designPattern,
      studentWorkFiles: validWorkFiles,
      providedPhotoWorkFiles,
      textExcerpts,
      studentRemarks,
      instructorRemarks,
      reportCardSnapshot,
      attendanceSummary,
      courses: coursesWithDetails,
      sectionData
    })
    compiledContent = compilationResult.content || ''
    snippet = compilationResult.snippet || ''
    generatedImages = compilationResult.images || []
    console.log('[Portfolio Controller] Portfolio compilation completed successfully')
  } catch (error) {
    const errMsg = error?.message || String(error)
    console.error('[Portfolio Controller] Error compiling portfolio with ChatGPT:', errMsg)
    compilationWarnings.push(errMsg)
    // Continue so portfolio is still created; user will see message and warnings in response
    compiledContent = `Portfolio compilation could not be completed.\n\nReason: ${errMsg}\n\nPlease check your OpenAI API key and connection, then try again.`
    snippet = 'Compilation failed. Please try again.'
    generatedImages = []
  }

  try {
    console.log('[Portfolio Controller] Creating portfolio in database...')
    // Create portfolio first with temporary image URLs
    const portfolio = await createPortfolio({
      familyId: user.familyId,
      studentId,
      studentName,
      designPattern,
      studentWorkFileIds: studentWorkFileIds || [],
      studentRemarks,
      instructorRemarks,
      reportCardSnapshot,
      sectionData: sectionData || null,
      compiledContent,
      snippet,
      generatedImages: [] // Will be updated after storing images
    })
    
    console.log('[Portfolio Controller] Portfolio created successfully:', portfolio._id)

    // Extract placeholder order: [PROVIDED_PHOTO: n] and [IMAGE: description]
    const providedPhotoRegex = /\[PROVIDED_PHOTO:\s*(\d+)\]/g
    const imageRegex = /\[IMAGE:\s*([^\]]+)\]/g
    const placeholders = []
    const contentWithPlaceholderMarkers = compiledContent
      .replace(providedPhotoRegex, (_, n) => {
        placeholders.push({ type: 'provided', n: parseInt(n, 10) })
        return `\u0000P${placeholders.length - 1}\u0000`
      })
    const tempContent = contentWithPlaceholderMarkers.replace(imageRegex, (_, desc) => {
      placeholders.push({ type: 'generated', description: desc.trim() })
      return `\u0000G${placeholders.length - 1}\u0000`
    })
    const providedCount = placeholders.filter(p => p.type === 'provided').length
    const generatedCount = placeholders.filter(p => p.type === 'generated').length
    console.log('[Portfolio Controller] Placeholders:', placeholders.length, '(provided:', providedCount, ', generated:', generatedCount, ')')

    // Reference user-provided photos by their existing studentWorkFile _id (no copy to portfolioImages)
    const providedImageRecords = providedPhotoWorkFiles.map((file) => ({
      id: file._id.toString(),
      description: 'Provided photo'
    }))

    // Store generated (DALL-E) images
    let storedGeneratedImages = []
    if (generatedImages.length > 0) {
      try {
        const { downloadAndStoreImages } = await import('../utils/imageStorage.js')
        storedGeneratedImages = await downloadAndStoreImages(generatedImages, portfolio._id.toString())
      } catch (err) {
        console.error('[Portfolio Controller] Error storing generated images:', err)
        storedGeneratedImages = generatedImages.map((img, idx) => ({
          id: `fallback-${idx}`,
          description: img.description || ''
        }))
      }
    }

    // Build merged image list in placeholder order
    let genIdx = 0
    const mergedImages = []
    for (let i = 0; i < placeholders.length; i++) {
      const p = placeholders[i]
      if (p.type === 'provided' && p.n >= 1 && p.n <= providedImageRecords.length) {
        mergedImages.push(providedImageRecords[p.n - 1])
      } else if (p.type === 'generated' && genIdx < storedGeneratedImages.length) {
        mergedImages.push(storedGeneratedImages[genIdx++])
      } else {
        mergedImages.push({ id: `missing-${i}`, description: '' })
      }
    }
    // Replace placeholder markers with [IMAGE] only - no URLs. Client uses generatedImages[i].id to load from GET /images/:id
    let replIdx = 0
    const finalContent = tempContent.replace(/\u0000[PG]\d+\u0000/g, () => {
      replIdx++
      return '[IMAGE]'
    })
    if (replIdx !== mergedImages.length) {
      console.warn('[Portfolio Controller] Placeholder count mismatch: replaced', replIdx, 'markers but mergedImages has', mergedImages.length)
    }

    // Single atomic update so content and images are always in sync
    await updatePortfolio(portfolio._id.toString(), {
      compiledContent: finalContent,
      snippet,
      generatedImages: mergedImages
    })
    portfolio.compiledContent = finalContent
    portfolio.generatedImages = mergedImages
    console.log('[Portfolio Controller] Portfolio updated with', mergedImages.length, 'image references (content + images saved together)')
    // Always send a successful response even if there were compilation warnings
    res.status(201).json({ 
      portfolio: serializePortfolio(portfolio),
      warnings: compilationWarnings.length > 0 ? compilationWarnings : undefined
    })
  } catch (error) {
    console.error('[Portfolio Controller] Error creating portfolio:', error)
    throw error // Let asyncHandler catch this
  }
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

  // Verify portfolio belongs to user's family
  if (portfolio.familyId.toString() !== user.familyId.toString()) {
    return res.status(403).json({ error: { message: 'Access denied' } })
  }

  // Delete associated images from database
  try {
    const { deleteImagesByPortfolioId } = await import('../models/portfolioImageModel.js')
    const deletedCount = await deleteImagesByPortfolioId(id)
    console.log('[Portfolio Controller] Deleted', deletedCount, 'images for portfolio', id)
  } catch (error) {
    console.error('[Portfolio Controller] Error deleting portfolio images:', error)
    // Continue with portfolio deletion even if image deletion fails
  }

  const deleted = await deletePortfolio(id)
  if (!deleted) {
    return res.status(404).json({ error: { message: 'Portfolio not found' } })
  }

  res.json({ success: true, message: 'Portfolio deleted' })
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

    const fileSize = req.file.size
    const fileName = req.file.originalname || req.file.filename
    const fileType = req.file.mimetype || 'application/octet-stream'

    const buf = await fs.readFile(req.file.path)
    const fileData = buf.toString('base64')
    await fs.unlink(req.file.path).catch(() => {})

    const file = await createStudentWorkFile({
      familyId: user.familyId,
      studentId,
      fileName,
      fileType,
      fileSize,
      fileData
    })

    if (!file) {
      console.error('[Upload] Failed to create file record in database')
      return res.status(500).json({ error: { message: 'Failed to save file record' } })
    }

    console.log('[Upload] File uploaded successfully', {
      fileId: file._id?.toString(),
      fileName: file.fileName
    })

    // Ensure response is properly formatted
    const response = { file: serializeStudentWorkFile(file) }
    res.status(201).json(response)
    
    console.log('[Upload] Response sent', {
      fileId: file._id?.toString(),
      responseSize: JSON.stringify(response).length
    })
  } catch (error) {
    console.error('[Upload] Error in upload handler', {
      error: error.message,
      stack: error.stack,
      timestamp: new Date().toISOString()
    })
    res.status(500).json({ error: { message: error.message || 'Internal server error' } })
  }
}

export async function deleteStudentWorkFileHandler (req, res) {
  const { id } = req.params

  const user = await findUserById(req.user.userId)
  if (!user || !user.familyId) {
    return res.status(400).json({ error: { message: 'User must belong to a family' } })
  }

  const file = await findStudentWorkFileById(id)
  if (!file) {
    return res.status(404).json({ error: { message: 'File not found' } })
  }

  if (file.familyId?.toString() !== user.familyId.toString()) {
    return res.status(403).json({ error: { message: 'Not authorized' } })
  }

  const deleted = await deleteStudentWorkFile(id)
  if (!deleted) {
    return res.status(404).json({ error: { message: 'File not found' } })
  }

  res.json({ success: true })
}

// Export multer middleware
export { upload, handleMulterError }

