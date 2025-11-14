// Updated with assistance from Cursor (ChatGPT) on 11/7/25.

import { ObjectId } from 'mongodb'
import { getCollection } from '../lib/mongo.js'

const COURSES_COLLECTION = 'courses'

function coursesCollection () {
  return getCollection(COURSES_COLLECTION)
}

export async function createCourse ({ familyId, name, subjectId, studentUserId, grade }) {
  const course = {
    familyId: new ObjectId(familyId),
    name,
    subjectId: subjectId ? new ObjectId(subjectId) : null,
    studentUserId: new ObjectId(studentUserId),
    grade: grade ?? null,
    assignments: [],
    createdAt: new Date(),
    updatedAt: new Date()
  }

  const result = await coursesCollection().insertOne(course)
  return { ...course, _id: result.insertedId }
}

export async function findCoursesByFamilyId (familyId) {
  return coursesCollection().find({ familyId: new ObjectId(familyId) }).sort({ name: 1 }).toArray()
}

export async function findCoursesByStudentId (studentUserId) {
  return coursesCollection().find({ studentUserId: new ObjectId(studentUserId) }).sort({ name: 1 }).toArray()
}

export async function findCourseById (id) {
  return coursesCollection().findOne({ _id: new ObjectId(id) })
}

export async function updateCourse (id, { name, subjectId, grade }) {
  const update = {}
  if (name !== undefined) update.name = name
  if (subjectId !== undefined) update.subjectId = subjectId ? new ObjectId(subjectId) : null
  if (grade !== undefined) update.grade = grade
  update.updatedAt = new Date()

  const result = await coursesCollection().findOneAndUpdate(
    { _id: new ObjectId(id) },
    { $set: update },
    { returnDocument: 'after' }
  )

  return result.value
}

export async function deleteCourse (id) {
  const result = await coursesCollection().deleteOne({ _id: new ObjectId(id) })
  return result.deletedCount > 0
}

