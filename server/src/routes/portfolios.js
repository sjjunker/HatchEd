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

// All routes require authentication
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

