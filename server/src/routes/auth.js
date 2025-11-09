import { Router } from 'express'
import { appleSignIn } from '../controllers/authController.js'
import { asyncHandler } from '../middleware/asyncHandler.js'

const router = Router()

router.post('/apple', asyncHandler(appleSignIn))

export default router

