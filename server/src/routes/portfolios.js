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
  upload,
  handleMulterError
} from '../controllers/portfolioController.js'

const router = express.Router()

// Portfolio Images - serve stored images from database (public route, no auth required for images)
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
    
    if (!image || !image.imageData) {
      return res.status(404).json({ error: { message: 'Image not found' } })
    }
    
    // Decode base64 image data
    const imageBuffer = Buffer.from(image.imageData, 'base64')
    
    // Set headers
    res.setHeader('Content-Type', image.contentType || 'image/png')
    res.setHeader('Content-Length', imageBuffer.length)
    res.setHeader('Cache-Control', 'public, max-age=31536000') // Cache for 1 year
    
    // Send the image
    res.send(imageBuffer)
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
router.get('/:id', asyncHandler(getPortfolioHandler))
router.delete('/:id', asyncHandler(deletePortfolioHandler))

// Student Work Files
router.get('/student-work/:studentId', asyncHandler(getStudentWorkFilesHandler))
router.post('/student-work/upload', upload.single('file'), handleMulterError, asyncHandler(uploadStudentWorkFileHandler))


export default router

