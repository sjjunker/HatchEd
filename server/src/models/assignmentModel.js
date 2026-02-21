// Updated with assistance from Cursor (ChatGPT) on 11/7/25.

import { ObjectId } from 'mongodb'
import { getCollection } from '../lib/mongo.js'

const ASSIGNMENTS_COLLECTION = 'assignments'

function assignmentsCollection () {
  return getCollection(ASSIGNMENTS_COLLECTION)
}

export async function createAssignment ({ familyId, title, studentId, workDates, dueDate, instructions, pointsPossible, pointsAwarded, courseId }) {
  const assignment = {
    familyId: new ObjectId(familyId),
    title,
    studentId: new ObjectId(studentId),
    workDates: Array.isArray(workDates) ? workDates.filter(Boolean).map(date => new Date(date)) : [],
    dueDate: dueDate ? new Date(dueDate) : null,
    instructions: instructions ?? null,
    pointsPossible: pointsPossible ?? null,
    pointsAwarded: pointsAwarded ?? null,
    courseId: courseId ? new ObjectId(courseId) : null,
    questions: [],
    completed: pointsAwarded != null, // Mark as completed if points are awarded
    createdAt: new Date(),
    updatedAt: new Date()
  }

  const result = await assignmentsCollection().insertOne(assignment)
  return { ...assignment, _id: result.insertedId }
}

export async function findAssignmentsByFamilyId (familyId) {
  return assignmentsCollection().find({ familyId: new ObjectId(familyId) }).sort({ dueDate: -1, createdAt: -1 }).toArray()
}

export async function findAssignmentsByCourseId (courseId) {
  try {
    return await assignmentsCollection().find({ courseId: new ObjectId(courseId) }).sort({ dueDate: -1, createdAt: -1 }).toArray()
  } catch (error) {
    console.error('Error finding assignments by courseId:', error)
    // Return empty array if there's an error (e.g., invalid ObjectId)
    return []
  }
}

export async function findAssignmentById (id) {
  return assignmentsCollection().findOne({ _id: new ObjectId(id) })
}

export async function updateAssignment (id, { title, workDates, dueDate, clearDueDate, instructions, pointsPossible, pointsAwarded, courseId }) {
  const update = {}
  if (title !== undefined) update.title = title
  if (workDates !== undefined) {
    update.workDates = Array.isArray(workDates) ? workDates.filter(Boolean).map(date => new Date(date)) : []
  }
  if (clearDueDate === true) {
    update.dueDate = null
  } else if (dueDate !== undefined) {
    update.dueDate = dueDate ? new Date(dueDate) : null
  }
  if (instructions !== undefined) update.instructions = instructions
  if (pointsPossible !== undefined) update.pointsPossible = pointsPossible
  if (pointsAwarded !== undefined) {
    update.pointsAwarded = pointsAwarded
    // Automatically mark as completed when points are awarded
    update.completed = pointsAwarded != null
  }
  if (courseId !== undefined) update.courseId = courseId ? new ObjectId(courseId) : null
  update.updatedAt = new Date()

  const result = await assignmentsCollection().findOneAndUpdate(
    { _id: new ObjectId(id) },
    { $set: update },
    { returnDocument: 'after' }
  )

  // If findOneAndUpdate didn't return the document, fetch it manually
  if (result?.value) {
    return result.value
  }
  
  // Fallback: fetch the updated assignment
  return await findAssignmentById(id)
}

export async function deleteAssignment (id) {
  const result = await assignmentsCollection().deleteOne({ _id: new ObjectId(id) })
  return result.deletedCount > 0
}

export async function deleteAssignmentsByStudentId (studentId) {
  const result = await assignmentsCollection().deleteMany({
    studentId: new ObjectId(studentId)
  })
  return result.deletedCount
}

