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

/** Normalize to array of ObjectIds. Accepts studentUserId (single) or studentUserIds (array). */
function normalizeStudentUserIds (studentUserId, studentUserIds) {
  if (studentUserIds && Array.isArray(studentUserIds) && studentUserIds.length > 0) {
    return studentUserIds.map(id => new ObjectId(id))
  }
  if (studentUserId) {
    return [new ObjectId(studentUserId)]
  }
  return []
}

export async function createCourse ({ familyId, name, studentUserId, studentUserIds }) {
  const ids = normalizeStudentUserIds(studentUserId, studentUserIds)
  if (ids.length === 0) {
    throw new Error('At least one student is required')
  }
  const course = {
    familyId: new ObjectId(familyId),
    name: name ? encrypt(name) : name,
    studentUserIds: ids,
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

/** Get courses that include this student (supports legacy studentUserId or studentUserIds). */
export async function findCoursesByStudentId (studentUserId) {
  const oid = new ObjectId(studentUserId)
  const docs = await coursesCollection().find({
    $or: [
      { studentUserIds: oid },
      { studentUserId: oid }
    ]
  }).sort({ createdAt: 1 }).toArray()
  return docs.map(decryptCourse)
}

export async function findCourseById (id) {
  const doc = await coursesCollection().findOne({ _id: new ObjectId(id) })
  return decryptCourse(doc)
}

export async function updateCourse (id, { name, studentUserIds }) {
  const update = { updatedAt: new Date() }
  if (name !== undefined) update.name = name ? encrypt(name) : name
  if (studentUserIds !== undefined) {
    const ids = Array.isArray(studentUserIds) && studentUserIds.length > 0
      ? studentUserIds.map(sid => new ObjectId(sid))
      : []
    update.studentUserIds = ids
  }

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
      if (studentUserIds !== undefined) course.studentUserIds = (studentUserIds || []).map(sid => new ObjectId(sid))
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

/** Delete courses that have only this student (for cascade delete). */
export async function deleteCoursesByStudentUserId (studentUserId) {
  const oid = new ObjectId(studentUserId)
  const result = await coursesCollection().deleteMany({
    $or: [
      { studentUserIds: oid },
      { studentUserId: oid }
    ]
  })
  return result.deletedCount
}

/** Remove student from all courses; delete course if they were the only student. Used in cascade delete. */
export async function removeStudentFromAllCourses (studentUserId) {
  const oid = new ObjectId(studentUserId)
  const coll = coursesCollection()
  // Legacy: delete courses that have only studentUserId equal to this
  await coll.deleteMany({ studentUserId: oid })
  // Courses with studentUserIds: pull this student, then delete if empty
  await coll.updateMany(
    { studentUserIds: oid },
    { $pull: { studentUserIds: oid }, $set: { updatedAt: new Date() } }
  )
  await coll.deleteMany({ studentUserIds: { $size: 0 } })
}

