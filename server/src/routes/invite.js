// Public invite acceptance (no auth required).

import { Router } from 'express'
import { asyncHandler } from '../middleware/asyncHandler.js'
import { acceptInvite } from '../controllers/userController.js'

const router = Router()

router.post('/accept', asyncHandler(acceptInvite))
router.get('/accept', asyncHandler(acceptInvite))

export default router
