// Updated with assistance from Cursor (ChatGPT) on 11/7/25.

import { ObjectId } from 'mongodb'
import { findUserById } from '../models/userModel.js'
import { findFamilyById } from '../models/familyModel.js'
import { createSubject, findSubjectsByFamilyId, updateSubject, deleteSubject, findSubjectById } from '../models/subjectModel.js'
import { createCourse, findCoursesByFamilyId, findCoursesByStudentId, updateCourse, deleteCourse, findCourseById } from '../models/courseModel.js'
import { createAssignment, findAssignmentsByFamilyId, findAssignmentsByCourseId, updateAssignment, deleteAssignment, findAssignmentById } from '../models/assignmentModel.js'
import { serializeSubject, serializeCourse, serializeAssignment } from '../utils/serializers.js'

// Subjects
export async function createSubjectHandler (req, res) {
  const { name } = req.body
  if (!name || !name.trim()) {
    return res.status(400).json({ error: { message: 'Subject name is required' } })
  }

  const user = await findUserById(req.user.userId)
  if (!user || !user.familyId) {
    return res.status(400).json({ error: { message: 'User must belong to a family' } })
  }

  const subject = await createSubject({ familyId: user.familyId, name: name.trim() })
  res.status(201).json({ subject: serializeSubject(subject) })
}

export async function getSubjectsHandler (req, res) {
  const user = await findUserById(req.user.userId)
  if (!user || !user.familyId) {
    return res.json({ subjects: [] })
  }

  const subjects = await findSubjectsByFamilyId(user.familyId)
  res.json({ subjects: subjects.map(serializeSubject) })
}

export async function updateSubjectHandler (req, res) {
  const { id } = req.params
  const { name } = req.body

  const user = await findUserById(req.user.userId)
  if (!user || !user.familyId) {
    return res.status(400).json({ error: { message: 'User must belong to a family' } })
  }

  const subject = await findSubjectById(id)
  if (!subject) {
    return res.status(404).json({ error: { message: 'Subject not found' } })
  }

  if (subject.familyId.toString() !== user.familyId.toString()) {
    return res.status(403).json({ error: { message: 'Not authorized' } })
  }

  const updated = await updateSubject(id, { name })
  res.json({ subject: serializeSubject(updated) })
}

export async function deleteSubjectHandler (req, res) {
  const { id } = req.params

  const user = await findUserById(req.user.userId)
  if (!user || !user.familyId) {
    return res.status(400).json({ error: { message: 'User must belong to a family' } })
  }

  const subject = await findSubjectById(id)
  if (!subject) {
    return res.status(404).json({ error: { message: 'Subject not found' } })
  }

  if (subject.familyId.toString() !== user.familyId.toString()) {
    return res.status(403).json({ error: { message: 'Not authorized' } })
  }

  await deleteSubject(id)
  res.json({ success: true })
}

// Courses
export async function createCourseHandler (req, res) {
  const { name, subjectId, studentUserId, grade } = req.body
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
    subjectId,
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
      const subject = course.subjectId ? await findSubjectById(course.subjectId) : null
      return serializeCourse(course, student, subject)
    })
  )
  res.json({ courses: coursesWithDetails })
}

export async function updateCourseHandler (req, res) {
  const { id } = req.params
  const { name, subjectId, grade } = req.body

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

  const updated = await updateCourse(id, { name, subjectId, grade })
  const student = await findUserById(updated.studentUserId)
  const subject = updated.subjectId ? await findSubjectById(updated.subjectId) : null
  res.json({ course: serializeCourse(updated, student, subject) })
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
  const { title, dueDate, instructions, subjectId, grade, courseId } = req.body
  if (!title || !title.trim()) {
    return res.status(400).json({ error: { message: 'Assignment title is required' } })
  }

  const user = await findUserById(req.user.userId)
  if (!user || !user.familyId) {
    return res.status(400).json({ error: { message: 'User must belong to a family' } })
  }

  const assignment = await createAssignment({
    familyId: user.familyId,
    title: title.trim(),
    dueDate,
    instructions,
    subjectId,
    grade,
    courseId
  })
  
  const subject = assignment.subjectId ? await findSubjectById(assignment.subjectId) : null
  res.status(201).json({ assignment: serializeAssignment(assignment, subject) })
}

export async function getAssignmentsHandler (req, res) {
  const user = await findUserById(req.user.userId)
  if (!user || !user.familyId) {
    return res.json({ assignments: [] })
  }

  const assignments = await findAssignmentsByFamilyId(user.familyId)
  const assignmentsWithDetails = await Promise.all(
    assignments.map(async (assignment) => {
      const subject = assignment.subjectId ? await findSubjectById(assignment.subjectId) : null
      return serializeAssignment(assignment, subject)
    })
  )
  res.json({ assignments: assignmentsWithDetails })
}

export async function updateAssignmentHandler (req, res) {
  const { id } = req.params
  const { title, dueDate, instructions, subjectId, grade } = req.body

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

  const updated = await updateAssignment(id, { title, dueDate, instructions, subjectId, grade })
  const subject = updated.subjectId ? await findSubjectById(updated.subjectId) : null
  res.json({ assignment: serializeAssignment(updated, subject) })
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

