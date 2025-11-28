// Updated with assistance from Cursor (ChatGPT) on 11/7/25.

import { ObjectId } from 'mongodb'
import { getCollection } from '../lib/mongo.js'

const STUDENT_WORK_FILES_COLLECTION = 'studentWorkFiles'

function studentWorkFilesCollection () {
  return getCollection(STUDENT_WORK_FILES_COLLECTION)
}

export async function createStudentWorkFile ({ familyId, studentId, fileName, fileUrl, fileType, fileSize }) {
  const file = {
    familyId: new ObjectId(familyId),
    studentId: new ObjectId(studentId),
    fileName,
    fileUrl,
    fileType,
    fileSize,
    uploadedAt: new Date(),
    createdAt: new Date(),
    updatedAt: new Date()
  }

  const result = await studentWorkFilesCollection().insertOne(file)
  return { ...file, _id: result.insertedId }
}

export async function findStudentWorkFilesByStudentId (studentId) {
  return studentWorkFilesCollection().find({ studentId: new ObjectId(studentId) }).sort({ uploadedAt: -1 }).toArray()
}

export async function findStudentWorkFilesByFamilyId (familyId) {
  return studentWorkFilesCollection().find({ familyId: new ObjectId(familyId) }).sort({ uploadedAt: -1 }).toArray()
}

export async function findStudentWorkFileById (id) {
  return studentWorkFilesCollection().findOne({ _id: new ObjectId(id) })
}

export async function deleteStudentWorkFile (id) {
  const result = await studentWorkFilesCollection().deleteOne({ _id: new ObjectId(id) })
  return result.deletedCount > 0
}

