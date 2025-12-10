// Updated with assistance from Cursor (ChatGPT) on 11/7/25.

import { ObjectId } from 'mongodb'
import { getCollection } from '../lib/mongo.js'

const ASSIGNMENTS_COLLECTION = 'assignments'

function assignmentsCollection () {
  return getCollection(ASSIGNMENTS_COLLECTION)
}

export async function createAssignment ({ familyId, title, studentId, dueDate, instructions, pointsPossible, pointsAwarded, courseId }) {
  const assignment = {
    familyId: new ObjectId(familyId),
    title,
    studentId: new ObjectId(studentId),
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
  return assignmentsCollection().find({ courseId: new ObjectId(courseId) }).sort({ dueDate: -1, createdAt: -1 }).toArray()
}

export async function findAssignmentById (id) {
  return assignmentsCollection().findOne({ _id: new ObjectId(id) })
}

export async function updateAssignment (id, { title, dueDate, instructions, pointsPossible, pointsAwarded }) {
  const update = {}
  if (title !== undefined) update.title = title
  if (dueDate !== undefined) update.dueDate = dueDate ? new Date(dueDate) : null
  if (instructions !== undefined) update.instructions = instructions
  if (pointsPossible !== undefined) update.pointsPossible = pointsPossible
  if (pointsAwarded !== undefined) {
    update.pointsAwarded = pointsAwarded
    // Automatically mark as completed when points are awarded
    update.completed = pointsAwarded != null
  }
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

