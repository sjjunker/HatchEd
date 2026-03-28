// Updated with assistance from Cursor (ChatGPT) on 11/7/25.

import { ObjectId } from 'mongodb'
import { findUserById } from '../models/userModel.js'
import { findFamilyById } from '../models/familyModel.js'
import { createCourse, findCoursesByFamilyId, findCoursesByStudentId, updateCourse, deleteCourse, findCourseById } from '../models/courseModel.js'
import { createAssignment, findAssignmentsByFamilyId, findAssignmentsByCourseId, updateAssignment, deleteAssignment, findAssignmentById } from '../models/assignmentModel.js'
import { serializeCourse, serializeAssignment } from '../utils/serializers.js'
import { unlinkResourcesByAssignmentId } from '../models/resourceModel.js'

// Courses
export async function createCourseHandler (req, res) {
  const { name, colorName, studentUserId, studentUserIds } = req.body
  if (!name || !name.trim()) {
    return res.status(400).json({ error: { message: 'Course name is required' } })
  }
  const ids = Array.isArray(studentUserIds) && studentUserIds.length > 0
    ? studentUserIds
    : (studentUserId ? [studentUserId] : [])
  if (ids.length === 0) {
    return res.status(400).json({ error: { message: 'At least one student is required' } })
  }

  const user = await findUserById(req.user.userId)
  if (!user || !user.familyId) {
    return res.status(400).json({ error: { message: 'User must belong to a family' } })
  }

  // Verify all students belong to the same family
  const students = await Promise.all(ids.map(id => findUserById(id)))
  const invalid = students.some((s, i) => !s || s.familyId?.toString() !== user.familyId.toString())
  if (invalid) {
    return res.status(400).json({ error: { message: 'All students must belong to your family' } })
  }

  const course = await createCourse({
    familyId: user.familyId,
    name: name.trim(),
    colorName: colorName || 'Blue',
    studentUserIds: ids
  })
  res.status(201).json({ course: serializeCourse(course, students) })
}

export async function getCoursesHandler (req, res) {
  const user = await findUserById(req.user.userId)
  if (!user || !user.familyId) {
    return res.json({ courses: [] })
  }

  const courses = await findCoursesByFamilyId(user.familyId)
  const coursesWithDetails = await Promise.all(
    courses.map(async (course) => {
      const ids = course.studentUserIds?.length
        ? course.studentUserIds
        : (course.studentUserId ? [course.studentUserId] : [])
      const students = await Promise.all(ids.map(id => findUserById(id.toString?.() ?? id)))
      const assignments = await findAssignmentsByCourseId(course._id.toString())
      const serializedAssignments = assignments.map(assignment => serializeAssignment(assignment))
      const courseWithAssignments = { ...course, assignments: serializedAssignments }
      return serializeCourse(courseWithAssignments, students)
    })
  )
  res.json({ courses: coursesWithDetails })
}

export async function updateCourseHandler (req, res) {
  try {
    const { id } = req.params
    const { name, colorName, studentUserIds } = req.body

    const user = await findUserById(req.user.userId)
    if (!user || !user.familyId) {
      return res.status(400).json({ error: { message: 'User must belong to a family' } })
    }

    const course = await findCourseById(id)
    if (!course) {
      return res.status(404).json({ error: { message: 'Course not found' } })
    }

    if (course.familyId.toString() !== user.familyId.toString()) {
      return res.status(403).json({ error: { message: 'Not authorized' } })
    }

    if (studentUserIds !== undefined && Array.isArray(studentUserIds) && studentUserIds.length === 0) {
      return res.status(400).json({ error: { message: 'At least one student is required' } })
    }
    if (studentUserIds !== undefined && Array.isArray(studentUserIds)) {
      const students = await Promise.all(studentUserIds.map(sid => findUserById(sid)))
      const invalid = students.some((s, i) => !s || s.familyId?.toString() !== user.familyId.toString())
      if (invalid) {
        return res.status(400).json({ error: { message: 'All students must belong to your family' } })
      }
    }

    const updated = await updateCourse(id, { name, colorName, studentUserIds })
    if (!updated || updated === null) {
      console.error('updateCourse returned null/undefined for course:', id)
      return res.status(500).json({ error: { message: 'Failed to update course' } })
    }

    const ids = updated.studentUserIds?.length
      ? updated.studentUserIds
      : (updated.studentUserId ? [updated.studentUserId] : [])
    const students = await Promise.all(ids.map(sid => findUserById(sid.toString?.() ?? sid)))
    let assignments = []
    try {
      assignments = await findAssignmentsByCourseId(id)
    } catch (assignmentsError) {
      console.error('Error fetching assignments for course:', assignmentsError)
    }
    const serializedAssignments = assignments.map(assignment => serializeAssignment(assignment))
    const courseWithAssignments = { ...updated, assignments: serializedAssignments }
    res.json({ course: serializeCourse(courseWithAssignments, students) })
  } catch (error) {
    console.error('Error updating course:', error)
    console.error('Error stack:', error.stack)
    res.status(500).json({ error: { message: error.message || 'Internal server error', code: 'UPDATE_COURSE_ERROR' } })
  }
}

export async function deleteCourseHandler (req, res) {
  const { id } = req.params

  const user = await findUserById(req.user.userId)
  if (!user || !user.familyId) {
    return res.status(400).json({ error: { message: 'User must belong to a family' } })
  }

  const course = await findCourseById(id)
  if (!course) {
    return res.status(404).json({ error: { message: 'Course not found' } })
  }

  if (course.familyId.toString() !== user.familyId.toString()) {
    return res.status(403).json({ error: { message: 'Not authorized' } })
  }

  await deleteCourse(id)
  res.json({ success: true })
}

// Assignments
export async function createAssignmentHandler (req, res) {
  const { title, studentId, workDates, workDurationsMinutes, dueDate, instructions, pointsPossible, pointsAwarded, courseId, strictWorkSessionProgress } = req.body
  if (!title || !title.trim()) {
    return res.status(400).json({ error: { message: 'Assignment title is required' } })
  }
  
  if (!studentId) {
    return res.status(400).json({ error: { message: 'Student ID is required' } })
  }

  if (!courseId) {
    return res.status(400).json({ error: { message: 'Course ID is required' } })
  }

  const user = await findUserById(req.user.userId)
  if (!user || !user.familyId) {
    return res.status(400).json({ error: { message: 'User must belong to a family' } })
  }

  const assignment = await createAssignment({
    familyId: user.familyId,
    title: title.trim(),
    studentId,
    workDates,
    workDurationsMinutes,
    dueDate,
    instructions,
    pointsPossible,
    pointsAwarded,
    courseId,
    strictWorkSessionProgress
  })
  
  res.status(201).json({ assignment: serializeAssignment(assignment) })
}

export async function getAssignmentsHandler (req, res) {
  const user = await findUserById(req.user.userId)
  if (!user || !user.familyId) {
    return res.json({ assignments: [] })
  }

  let assignments = await findAssignmentsByFamilyId(user.familyId)
  if (user.role === 'student') {
    const studentId = user._id.toString()
    assignments = assignments.filter(a => a.studentId?.toString() === studentId)
  }

  const assignmentsWithDetails = assignments.map(assignment => serializeAssignment(assignment))
  
  // Check for overdue assignments in the background
  const { checkOverdueAssignmentsOnFetch } = await import('../services/assignmentNotificationService.js')
  checkOverdueAssignmentsOnFetch(user.familyId)
  
  res.json({ assignments: assignmentsWithDetails })
}

export async function updateAssignmentHandler (req, res) {
  const { id } = req.params
  const body = req.body

  const user = await findUserById(req.user.userId)
  if (!user || !user.familyId) {
    return res.status(400).json({ error: { message: 'User must belong to a family' } })
  }

  const assignment = await findAssignmentById(id)
  if (!assignment) {
    return res.status(404).json({ error: { message: 'Assignment not found' } })
  }

  if (assignment.familyId.toString() !== user.familyId.toString()) {
    return res.status(403).json({ error: { message: 'Not authorized' } })
  }

  if (user.role === 'student') {
    if (assignment.studentId.toString() !== user._id.toString()) {
      return res.status(403).json({ error: { message: 'Not authorized' } })
    }
    const allowed = new Set(['completed', 'incrementWorkSession'])
    const keys = Object.keys(body).filter(k => body[k] !== undefined && body[k] !== null)
    const bad = keys.filter(k => !allowed.has(k))
    if (bad.length > 0) {
      return res.status(403).json({ error: { message: 'Students may only update completion or work session progress.' } })
    }
  }

  if (body.incrementWorkSession === true) {
    if (user.role !== 'student' || assignment.studentId.toString() !== user._id.toString()) {
      return res.status(403).json({ error: { message: 'Only the assigned student can log a work session.' } })
    }
  }

  if (body.workSessionsCompleted !== undefined && user.role !== 'parent') {
    return res.status(403).json({ error: { message: 'Only parents can set work session count directly.' } })
  }

  if (body.strictWorkSessionProgress !== undefined && user.role !== 'parent') {
    return res.status(403).json({ error: { message: 'Only parents can change strict work session mode.' } })
  }

  const skipWorkSessionCompletionCheck = user.role === 'parent'

  try {
    const updated = await updateAssignment(id, {
      title: body.title,
      workDates: body.workDates,
      workDurationsMinutes: body.workDurationsMinutes,
      dueDate: body.dueDate,
      clearDueDate: body.clearDueDate,
      instructions: body.instructions,
      pointsPossible: body.pointsPossible,
      pointsAwarded: body.pointsAwarded,
      courseId: body.courseId,
      completed: body.completed,
      incrementWorkSession: body.incrementWorkSession,
      workSessionsCompleted: body.workSessionsCompleted,
      strictWorkSessionProgress: body.strictWorkSessionProgress,
      skipWorkSessionCompletionCheck
    })
    if (!updated) {
      return res.status(404).json({ error: { message: 'Assignment not found or could not be updated' } })
    }
    res.json({ assignment: serializeAssignment(updated) })
  } catch (error) {
    const code = error.code
    if (code === 'NO_WORK_SESSIONS' || code === 'SESSIONS_COMPLETE' || code === 'SESSION_LOCKED' || code === 'INCOMPLETE_SESSIONS') {
      return res.status(400).json({ error: { message: error.message, code } })
    }
    throw error
  }
}

export async function deleteAssignmentHandler (req, res) {
  const { id } = req.params

  const user = await findUserById(req.user.userId)
  if (!user || !user.familyId) {
    return res.status(400).json({ error: { message: 'User must belong to a family' } })
  }

  const assignment = await findAssignmentById(id)
  if (!assignment) {
    return res.status(404).json({ error: { message: 'Assignment not found' } })
  }

  if (assignment.familyId.toString() !== user.familyId.toString()) {
    return res.status(403).json({ error: { message: 'Not authorized' } })
  }

  await unlinkResourcesByAssignmentId(id)
  await deleteAssignment(id)
  res.json({ success: true })
}
