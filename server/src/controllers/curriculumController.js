// Updated with assistance from Cursor (ChatGPT) on 11/7/25.

import { ObjectId } from 'mongodb'
import { findUserById } from '../models/userModel.js'
import { findFamilyById } from '../models/familyModel.js'
import { createCourse, findCoursesByFamilyId, findCoursesByStudentId, updateCourse, deleteCourse, findCourseById } from '../models/courseModel.js'
import { createAssignment, findAssignmentsByFamilyId, findAssignmentsByCourseId, updateAssignment, deleteAssignment, findAssignmentById } from '../models/assignmentModel.js'
import { serializeCourse, serializeAssignment } from '../utils/serializers.js'

// Courses
export async function createCourseHandler (req, res) {
  const { name, studentUserId, grade } = req.body
  if (!name || !name.trim()) {
    return res.status(400).json({ error: { message: 'Course name is required' } })
  }
  if (!studentUserId) {
    return res.status(400).json({ error: { message: 'Student is required' } })
  }

  const user = await findUserById(req.user.userId)
  if (!user || !user.familyId) {
    return res.status(400).json({ error: { message: 'User must belong to a family' } })
  }

  // Verify student belongs to the same family
  const student = await findUserById(studentUserId)
  if (!student || student.familyId?.toString() !== user.familyId.toString()) {
    return res.status(400).json({ error: { message: 'Student must belong to the same family' } })
  }

  const course = await createCourse({
    familyId: user.familyId,
    name: name.trim(),
    studentUserId,
    grade
  })
  res.status(201).json({ course: serializeCourse(course, student) })
}

export async function getCoursesHandler (req, res) {
  const user = await findUserById(req.user.userId)
  if (!user || !user.familyId) {
    return res.json({ courses: [] })
  }

  const courses = await findCoursesByFamilyId(user.familyId)
  const coursesWithDetails = await Promise.all(
    courses.map(async (course) => {
      const student = await findUserById(course.studentUserId)
      return serializeCourse(course, student)
    })
  )
  res.json({ courses: coursesWithDetails })
}

export async function updateCourseHandler (req, res) {
  const { id } = req.params
  const { name, grade } = req.body

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

  const updated = await updateCourse(id, { name, grade })
  const student = await findUserById(updated.studentUserId)
  res.json({ course: serializeCourse(updated, student) })
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
  const { title, dueDate, instructions, pointsPossible, pointsAwarded } = req.body

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

  const updated = await updateAssignment(id, { title, dueDate, instructions, pointsPossible, pointsAwarded })
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

  await deleteAssignment(id)
  res.json({ success: true })
}

