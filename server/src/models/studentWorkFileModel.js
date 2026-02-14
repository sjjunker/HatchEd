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

/**
 * Create a student work file. File content is stored in DB as base64 (like portfolioImages).
 * @param {Object} params
 * @param {string} params.fileData - Base64-encoded file content
 */
export async function createStudentWorkFile ({ familyId, studentId, fileName, fileType, fileSize, fileData }) {
  const file = {
    familyId: new ObjectId(familyId),
    studentId: new ObjectId(studentId),
    fileName: fileName ? encrypt(fileName) : fileName,
    fileType,
    fileSize,
    fileData: fileData ?? null,
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

