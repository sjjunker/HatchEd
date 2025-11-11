//
//  attendance.js
//  HatchEd Server
//
//  Created by Cursor (ChatGPT) on 11/7/25.
//

import { Router } from 'express'
import { asyncHandler } from '../middleware/asyncHandler.js'
import { requireAuth } from '../middleware/requireAuth.js'
import { recordAttendance, getStudentAttendance } from '../controllers/attendanceController.js'

const router = Router()

router.use(requireAuth)

router.post('/', asyncHandler(recordAttendance))
router.get('/students/:studentUserId', asyncHandler(getStudentAttendance))

export default router
