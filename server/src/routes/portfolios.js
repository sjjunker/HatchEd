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

// Portfolio Images - serve stored images (public route, no auth required for images)
// This must be BEFORE the requireAuth middleware
import path from 'path'
router.get('/images/:filename', asyncHandler(async (req, res) => {
  const { filename } = req.params
  const { getImagePath, imageExists } = await import('../utils/imageStorage.js')
  
  // Security: prevent directory traversal
  if (filename.includes('..') || filename.includes('/') || filename.includes('\\')) {
    return res.status(400).json({ error: { message: 'Invalid filename' } })
  }
  
  const imagePath = getImagePath(filename)
  
  // Check if image exists
  if (!(await imageExists(filename))) {
    return res.status(404).json({ error: { message: 'Image not found' } })
  }
  
  // Send the image file with proper headers
  res.setHeader('Content-Type', 'image/png')
  res.setHeader('Cache-Control', 'public, max-age=31536000') // Cache for 1 year
  res.sendFile(path.resolve(imagePath))
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

