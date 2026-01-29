// Updated with assistance from Cursor (ChatGPT) on 11/7/25.

import { ObjectId } from 'mongodb'
import { getCollection } from '../lib/mongo.js'
import { encrypt, decrypt } from '../utils/piiCrypto.js'

const COURSES_COLLECTION = 'courses'

function coursesCollection () {
  return getCollection(COURSES_COLLECTION)
}

function decryptCourse (doc) {
  if (!doc) return null
  const out = { ...doc }
  if (out.name != null) out.name = decrypt(out.name)
  return out
}

export async function createCourse ({ familyId, name, studentUserId, grade }) {
  const course = {
    familyId: new ObjectId(familyId),
    name: name ? encrypt(name) : name,
    studentUserId: new ObjectId(studentUserId),
    grade: grade ?? null,
    assignments: [],
    createdAt: new Date(),
    updatedAt: new Date()
  }

  const result = await coursesCollection().insertOne(course)
  return decryptCourse({ ...course, _id: result.insertedId })
}

export async function findCoursesByFamilyId (familyId) {
  const docs = await coursesCollection().find({ familyId: new ObjectId(familyId) }).sort({ createdAt: 1 }).toArray()
  return docs.map(decryptCourse)
}

export async function findCoursesByStudentId (studentUserId) {
  const docs = await coursesCollection().find({ studentUserId: new ObjectId(studentUserId) }).sort({ createdAt: 1 }).toArray()
  return docs.map(decryptCourse)
}

export async function findCourseById (id) {
  const doc = await coursesCollection().findOne({ _id: new ObjectId(id) })
  return decryptCourse(doc)
}

export async function updateCourse (id, { name, grade }) {
  const update = { updatedAt: new Date() }
  if (name !== undefined) update.name = name ? encrypt(name) : name
  if (grade !== undefined) update.grade = grade

  const result = await coursesCollection().findOneAndUpdate(
    { _id: new ObjectId(id) },
    { $set: update },
    { returnDocument: 'after' }
  )

  if (!result || !result.value) {
    console.error('findOneAndUpdate returned null for course:', id)
    const course = await findCourseById(id)
    if (course) {
      if (name !== undefined) course.name = typeof name === 'string' ? name : course.name
      if (grade !== undefined) course.grade = grade
      course.updatedAt = new Date()
      return course
    }
    return null
  }

  return decryptCourse(result.value)
}

export async function deleteCourse (id) {
  const result = await coursesCollection().deleteOne({ _id: new ObjectId(id) })
  return result.deletedCount > 0
}

