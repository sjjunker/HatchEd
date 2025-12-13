// Updated with assistance from Cursor (ChatGPT) on 11/7/25.

import { Router } from 'express'
import { appleSignIn, googleSignIn, signUp, usernamePasswordSignIn } from '../controllers/authController.js'
import { asyncHandler } from '../middleware/asyncHandler.js'

const router = Router()

router.post('/apple', asyncHandler(appleSignIn))
router.post('/google', asyncHandler(googleSignIn))
router.post('/signup', asyncHandler(signUp))
router.post('/signin', asyncHandler(usernamePasswordSignIn))

export default router

