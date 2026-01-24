// Updated with assistance from Cursor (ChatGPT) on 11/7/25.

import { Router } from 'express'
import { asyncHandler } from '../middleware/asyncHandler.js'
import { requireAuth } from '../middleware/requireAuth.js'
import { createFamilyForUser, getCurrentUser, joinFamilyWithCode, updateProfile } from '../controllers/userController.js'
import { setupTwoFactorHandler, verifyTwoFactorHandler, disableTwoFactorHandler } from '../controllers/twoFactorController.js'

const router = Router()

router.use(requireAuth)

router.get('/me', asyncHandler(getCurrentUser))
router.patch('/me', asyncHandler(updateProfile))
router.post('/me/family', asyncHandler(createFamilyForUser))
router.post('/me/family/join', asyncHandler(joinFamilyWithCode))

// Two-factor authentication routes
router.post('/me/2fa/setup', asyncHandler(setupTwoFactorHandler))
router.post('/me/2fa/verify', asyncHandler(verifyTwoFactorHandler))
router.post('/me/2fa/disable', asyncHandler(disableTwoFactorHandler))

export default router

