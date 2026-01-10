// Updated with assistance from Cursor (ChatGPT) on 12/13/25.

import { Router } from 'express'
import { asyncHandler } from '../middleware/asyncHandler.js'
import { requireAuth } from '../middleware/requireAuth.js'
import {
  createPlannerTaskHandler,
  getPlannerTasksHandler,
  updatePlannerTaskHandler,
  deletePlannerTaskHandler
} from '../controllers/plannerController.js'

const router = Router()

router.use(requireAuth)

// Planner Tasks (for tasks without subjects)
router.post('/tasks', asyncHandler(createPlannerTaskHandler))
router.get('/tasks', asyncHandler(getPlannerTasksHandler))
router.patch('/tasks/:id', asyncHandler(updatePlannerTaskHandler))
router.delete('/tasks/:id', asyncHandler(deletePlannerTaskHandler))

export default router

