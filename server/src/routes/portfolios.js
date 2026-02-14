// Updated with assistance from Cursor (ChatGPT) on 11/7/25.

import express from 'express'
import { requireAuth } from '../middleware/requireAuth.js'
import { asyncHandler } from '../middleware/asyncHandler.js'
import {
  getPortfoliosHandler,
  createPortfolioHandler,
  getPortfolioHandler,
  deletePortfolioHandler,
  getStudentWorkFilesHandler,
  uploadStudentWorkFileHandler,
  deleteStudentWorkFileHandler,
  upload,
  handleMulterError
} from '../controllers/portfolioController.js'

const router = express.Router()

// Portfolio Images - serve from portfolioImages (AI-generated) or studentWorkFiles (user-provided)
// This must be BEFORE the requireAuth middleware
router.get('/images/:imageId', asyncHandler(async (req, res) => {
  const { imageId } = req.params

  // Security: validate ObjectId format
  if (!imageId || imageId.length !== 24 || !/^[0-9a-fA-F]{24}$/.test(imageId)) {
    return res.status(400).json({ error: { message: 'Invalid image ID' } })
  }

  try {
    const { findImageById } = await import('../models/portfolioImageModel.js')
    const image = await findImageById(imageId)

    if (image && image.imageData) {
      // AI-generated image from portfolioImages
      const imageBuffer = Buffer.from(image.imageData, 'base64')
      res.setHeader('Content-Type', image.contentType || 'image/png')
      res.setHeader('Content-Length', imageBuffer.length)
      res.setHeader('Cache-Control', 'public, max-age=31536000')
      return res.send(imageBuffer)
    }

    // Not in portfolioImages: try studentWorkFiles (user-provided photo)
    const { findStudentWorkFileById } = await import('../models/studentWorkFileModel.js')
    const file = await findStudentWorkFileById(imageId)
    if (!file) {
      console.log('[Portfolio Routes] Image not found: no studentWorkFile for id', imageId)
      return res.status(404).json({ error: { message: 'Image not found' } })
    }
    const contentType = (file.fileType || '').split(';')[0].trim()
    if (!contentType.startsWith('image/')) {
      console.log('[Portfolio Routes] Image not found: not an image type', imageId, file.fileType)
      return res.status(404).json({ error: { message: 'Image not found' } })
    }
    if (!file.fileData) {
      console.log('[Portfolio Routes] Image not found: studentWorkFile has no fileData', imageId)
      return res.status(404).json({ error: { message: 'Image not found' } })
    }
    const imageBuffer = Buffer.from(file.fileData, 'base64')
    res.setHeader('Content-Type', contentType || 'image/png')
    res.setHeader('Content-Length', imageBuffer.length)
    res.setHeader('Cache-Control', 'public, max-age=31536000')
    return res.send(imageBuffer)
  } catch (error) {
    console.error('[Portfolio Routes] Error serving image:', error)
    res.status(500).json({ error: { message: 'Failed to serve image' } })
  }
}))

// All other routes require authentication
router.use(requireAuth)

// Portfolios
router.get('/', asyncHandler(getPortfoliosHandler))
router.post('/', asyncHandler(createPortfolioHandler))
// Student Work Files (before /:id so "student-work" is not captured as portfolio id)
router.get('/student-work/:studentId', asyncHandler(getStudentWorkFilesHandler))
router.post('/student-work/upload', upload.single('file'), handleMulterError, asyncHandler(uploadStudentWorkFileHandler))
router.delete('/student-work/:id', asyncHandler(deleteStudentWorkFileHandler))
router.get('/:id', asyncHandler(getPortfolioHandler))
router.delete('/:id', asyncHandler(deletePortfolioHandler))


export default router

