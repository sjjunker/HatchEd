import { Router } from 'express'
import { asyncHandler } from '../middleware/asyncHandler.js'
import { requireAuth } from '../middleware/requireAuth.js'
import { getFamily } from '../controllers/userController.js'

const router = Router()

router.use(requireAuth)

router.get('/:familyId', asyncHandler(getFamily))

export default router

