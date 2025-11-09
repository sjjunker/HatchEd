// Updated with assistance from Cursor (ChatGPT) on 11/7/25.

import { Router } from 'express'
import { listNotifications, removeNotification } from '../controllers/notificationController.js'
import { asyncHandler } from '../middleware/asyncHandler.js'
import { requireAuth } from '../middleware/requireAuth.js'

const router = Router()

router.use(requireAuth)

router.get('/', asyncHandler(listNotifications))
router.delete('/:notificationId', asyncHandler(removeNotification))

export default router
