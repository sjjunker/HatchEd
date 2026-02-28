import { Router } from 'express'
import { asyncHandler } from '../middleware/asyncHandler.js'
import { requireAuth } from '../middleware/requireAuth.js'
import { getDailyQuoteHandler } from '../controllers/quoteController.js'

const router = Router()

router.use(requireAuth)

router.get('/daily', asyncHandler(getDailyQuoteHandler))

export default router

