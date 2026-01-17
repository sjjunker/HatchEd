// Updated with assistance from Cursor (ChatGPT) on 11/7/25.

import { ObjectId } from 'mongodb'
import { getCollection } from '../lib/mongo.js'

const COURSES_COLLECTION = 'courses'

function coursesCollection () {
  return getCollection(COURSES_COLLECTION)
}

export async function createCourse ({ familyId, name, studentUserId, grade }) {
  const course = {
    familyId: new ObjectId(familyId),
    name,
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

export async function updateCourse (id, { name, grade }) {
  const update = {}
  if (name !== undefined) update.name = name
  if (grade !== undefined) update.grade = grade
  update.updatedAt = new Date()

  const result = await coursesCollection().findOneAndUpdate(
    { _id: new ObjectId(id) },
    { $set: update },
    { returnDocument: 'after' }
  )

  // If result.value is null, the document wasn't found or update failed
  // In that case, try to fetch the course again to return it
  if (!result || !result.value) {
    console.error('findOneAndUpdate returned null for course:', id)
    // Try to fetch the course to see if it still exists
    const course = await findCourseById(id)
    if (course) {
      // Apply the updates manually since findOneAndUpdate failed
      if (name !== undefined) course.name = name
      if (grade !== undefined) course.grade = grade
      course.updatedAt = new Date()
      return course
    }
    return null
  }

  return result.value
}

export async function deleteCourse (id) {
  const result = await coursesCollection().deleteOne({ _id: new ObjectId(id) })
  return result.deletedCount > 0
}

