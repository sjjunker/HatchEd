import { Router } from 'express'
import { asyncHandler } from '../middleware/asyncHandler.js'
import { requireAuth } from '../middleware/requireAuth.js'
import { createFamilyForUser, getCurrentUser, joinFamilyWithCode, updateProfile } from '../controllers/userController.js'

const router = Router()

router.use(requireAuth)

router.get('/me', asyncHandler(getCurrentUser))
router.patch('/me', asyncHandler(updateProfile))
router.post('/me/family', asyncHandler(createFamilyForUser))
router.post('/me/family/join', asyncHandler(joinFamilyWithCode))

export default router

