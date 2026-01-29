// Updated with assistance from Cursor (ChatGPT) on 11/7/25.

import { ObjectId } from 'mongodb'
import { getCollection } from '../lib/mongo.js'
import { encrypt, decrypt } from '../utils/piiCrypto.js'

const PORTFOLIOS_COLLECTION = 'portfolios'

export function portfoliosCollection () {
  return getCollection(PORTFOLIOS_COLLECTION)
}

function encryptPortfolioPII (obj) {
  const out = { ...obj }
  if (out.studentName != null && out.studentName !== '') out.studentName = encrypt(out.studentName)
  if (out.studentRemarks != null && out.studentRemarks !== '') out.studentRemarks = encrypt(out.studentRemarks)
  if (out.instructorRemarks != null && out.instructorRemarks !== '') out.instructorRemarks = encrypt(out.instructorRemarks)
  if (out.reportCardSnapshot != null) {
    const val = out.reportCardSnapshot
    out.reportCardSnapshot = encrypt(typeof val === 'string' ? val : JSON.stringify(val))
  }
  if (out.sectionData != null) {
    const val = out.sectionData
    out.sectionData = encrypt(typeof val === 'string' ? val : JSON.stringify(val))
  }
  if (out.compiledContent != null && out.compiledContent !== '') out.compiledContent = encrypt(out.compiledContent)
  if (out.snippet != null && out.snippet !== '') out.snippet = encrypt(out.snippet)
  return out
}

function decryptPortfolio (doc) {
  if (!doc) return null
  const out = { ...doc }
  if (out.studentName != null) out.studentName = decrypt(out.studentName)
  if (out.studentRemarks != null) out.studentRemarks = decrypt(out.studentRemarks)
  if (out.instructorRemarks != null) out.instructorRemarks = decrypt(out.instructorRemarks)
  if (out.reportCardSnapshot != null) {
    const d = decrypt(out.reportCardSnapshot)
    try {
      out.reportCardSnapshot = JSON.parse(d)
    } catch {
      out.reportCardSnapshot = d
    }
  }
  if (out.sectionData != null) {
    const d = decrypt(out.sectionData)
    try {
      out.sectionData = JSON.parse(d)
    } catch {
      out.sectionData = d
    }
  }
  if (out.compiledContent != null) out.compiledContent = decrypt(out.compiledContent)
  if (out.snippet != null) out.snippet = decrypt(out.snippet)
  return out
}

export async function createPortfolio ({ familyId, studentId, studentName, designPattern, studentWorkFileIds, studentRemarks, instructorRemarks, reportCardSnapshot, sectionData, compiledContent, snippet, generatedImages }) {
  const raw = {
    familyId: new ObjectId(familyId),
    studentId: new ObjectId(studentId),
    studentName: studentName ?? '',
    designPattern,
    studentWorkFileIds: studentWorkFileIds.map(id => new ObjectId(id)),
    studentRemarks: studentRemarks ?? null,
    instructorRemarks: instructorRemarks ?? null,
    reportCardSnapshot: reportCardSnapshot ?? null,
    sectionData: sectionData ?? null,
    compiledContent: compiledContent ?? '',
    snippet: snippet ?? '',
    generatedImages: generatedImages ?? [],
    createdAt: new Date(),
    updatedAt: new Date()
  }
  const portfolio = encryptPortfolioPII(raw)

  const result = await portfoliosCollection().insertOne(portfolio)
  return decryptPortfolio({ ...portfolio, _id: result.insertedId })
}

export async function findPortfoliosByFamilyId (familyId) {
  const docs = await portfoliosCollection().find({ familyId: new ObjectId(familyId) }).sort({ createdAt: -1 }).toArray()
  return docs.map(decryptPortfolio)
}

export async function findPortfolioById (id) {
  const doc = await portfoliosCollection().findOne({ _id: new ObjectId(id) })
  return decryptPortfolio(doc)
}

export async function updatePortfolio (id, { compiledContent, snippet }) {
  const update = { updatedAt: new Date() }
  if (compiledContent !== undefined) update.compiledContent = encrypt(compiledContent)
  if (snippet !== undefined) update.snippet = encrypt(snippet)

  const result = await portfoliosCollection().findOneAndUpdate(
    { _id: new ObjectId(id) },
    { $set: update },
    { returnDocument: 'after' }
  )

  return decryptPortfolio(result.value)
}

export async function deletePortfolio (id) {
  const result = await portfoliosCollection().deleteOne({ _id: new ObjectId(id) })
  return result.deletedCount > 0
}

