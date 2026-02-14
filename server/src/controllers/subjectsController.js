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
  const { name, studentUserId, studentUserIds, grade } = req.body
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
    studentUserIds: ids,
    grade
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
    let { name, grade, studentUserIds } = req.body

    // Normalize grade: convert empty string, null, or undefined to null
    if (grade === '' || grade === null || grade === undefined) {
      grade = null
    } else if (typeof grade === 'string') {
      const parsed = parseFloat(grade)
      grade = isNaN(parsed) ? null : parsed
    }

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

    const updated = await updateCourse(id, { name, grade, studentUserIds })
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
  const { title, studentId, dueDate, instructions, pointsPossible, pointsAwarded, courseId } = req.body
  if (!title || !title.trim()) {
    return res.status(400).json({ error: { message: 'Assignment title is required' } })
  }
  
  if (!studentId) {
    return res.status(400).json({ error: { message: 'Student ID is required' } })
  }

  const user = await findUserById(req.user.userId)
  if (!user || !user.familyId) {
    return res.status(400).json({ error: { message: 'User must belong to a family' } })
  }

  const assignment = await createAssignment({
    familyId: user.familyId,
    title: title.trim(),
    studentId,
    dueDate,
    instructions,
    pointsPossible,
    pointsAwarded,
    courseId
  })
  
  res.status(201).json({ assignment: serializeAssignment(assignment) })
}

export async function getAssignmentsHandler (req, res) {
  const user = await findUserById(req.user.userId)
  if (!user || !user.familyId) {
    return res.json({ assignments: [] })
  }

  const assignments = await findAssignmentsByFamilyId(user.familyId)
  const assignmentsWithDetails = assignments.map(assignment => serializeAssignment(assignment))
  
  // Check for overdue assignments in the background
  const { checkOverdueAssignmentsOnFetch } = await import('../services/assignmentNotificationService.js')
  checkOverdueAssignmentsOnFetch(user.familyId)
  
  res.json({ assignments: assignmentsWithDetails })
}

export async function updateAssignmentHandler (req, res) {
  const { id } = req.params
  const { title, dueDate, instructions, pointsPossible, pointsAwarded, courseId } = req.body

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

  const updated = await updateAssignment(id, { title, dueDate, instructions, pointsPossible, pointsAwarded, courseId })
  if (!updated) {
    return res.status(404).json({ error: { message: 'Assignment not found or could not be updated' } })
  }
  res.json({ assignment: serializeAssignment(updated) })
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
