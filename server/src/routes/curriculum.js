// Updated with assistance from Cursor (ChatGPT) on 11/7/25.

import { Router } from 'express'
import { asyncHandler } from '../middleware/asyncHandler.js'
import { requireAuth } from '../middleware/requireAuth.js'
import {
  createSubjectHandler,
  getSubjectsHandler,
  updateSubjectHandler,
  deleteSubjectHandler,
  createCourseHandler,
  getCoursesHandler,
  updateCourseHandler,
  deleteCourseHandler,
  createAssignmentHandler,
  getAssignmentsHandler,
  updateAssignmentHandler,
  deleteAssignmentHandler
} from '../controllers/curriculumController.js'

const router = Router()

router.use(requireAuth)

// Subjects
router.post('/subjects', asyncHandler(createSubjectHandler))
router.get('/subjects', asyncHandler(getSubjectsHandler))
router.patch('/subjects/:id', asyncHandler(updateSubjectHandler))
router.delete('/subjects/:id', asyncHandler(deleteSubjectHandler))

// Courses
router.post('/courses', asyncHandler(createCourseHandler))
router.get('/courses', asyncHandler(getCoursesHandler))
router.patch('/courses/:id', asyncHandler(updateCourseHandler))
router.delete('/courses/:id', asyncHandler(deleteCourseHandler))

// Assignments
router.post('/assignments', asyncHandler(createAssignmentHandler))
router.get('/assignments', asyncHandler(getAssignmentsHandler))
router.patch('/assignments/:id', asyncHandler(updateAssignmentHandler))
router.delete('/assignments/:id', asyncHandler(deleteAssignmentHandler))

export default router

