// Updated with assistance from Cursor (ChatGPT) on 11/7/25.

import { ObjectId } from 'mongodb'
import { getCollection } from '../lib/mongo.js'
import { encrypt, decrypt } from '../utils/piiCrypto.js'

const STUDENT_WORK_FILES_COLLECTION = 'studentWorkFiles'

function studentWorkFilesCollection () {
  return getCollection(STUDENT_WORK_FILES_COLLECTION)
}

function decryptStudentWorkFile (doc) {
  if (!doc) return null
  const out = { ...doc }
  if (out.fileName != null) out.fileName = decrypt(out.fileName)
  return out
}

export async function createStudentWorkFile ({ familyId, studentId, fileName, fileUrl, fileType, fileSize }) {
  const file = {
    familyId: new ObjectId(familyId),
    studentId: new ObjectId(studentId),
    fileName: fileName ? encrypt(fileName) : fileName,
    fileUrl,
    fileType,
    fileSize,
    uploadedAt: new Date(),
    createdAt: new Date(),
    updatedAt: new Date()
  }

  const result = await studentWorkFilesCollection().insertOne(file)
  return decryptStudentWorkFile({ ...file, _id: result.insertedId })
}

export async function findStudentWorkFilesByStudentId (studentId) {
  const docs = await studentWorkFilesCollection().find({ studentId: new ObjectId(studentId) }).sort({ uploadedAt: -1 }).toArray()
  return docs.map(decryptStudentWorkFile)
}

export async function findStudentWorkFilesByFamilyId (familyId) {
  const docs = await studentWorkFilesCollection().find({ familyId: new ObjectId(familyId) }).sort({ uploadedAt: -1 }).toArray()
  return docs.map(decryptStudentWorkFile)
}

export async function findStudentWorkFileById (id) {
  const doc = await studentWorkFilesCollection().findOne({ _id: new ObjectId(id) })
  return decryptStudentWorkFile(doc)
}

export async function deleteStudentWorkFile (id) {
  const result = await studentWorkFilesCollection().deleteOne({ _id: new ObjectId(id) })
  return result.deletedCount > 0
}

export async function deleteStudentWorkFilesByStudentId (studentId) {
  const result = await studentWorkFilesCollection().deleteMany({
    studentId: new ObjectId(studentId)
  })
  return result.deletedCount
}

