// Updated with assistance from Cursor (ChatGPT) on 11/7/25.

import { ObjectId } from 'mongodb'
import { getCollection } from '../lib/mongo.js'

const PORTFOLIOS_COLLECTION = 'portfolios'

function portfoliosCollection () {
  return getCollection(PORTFOLIOS_COLLECTION)
}

export async function createPortfolio ({ familyId, studentId, studentName, designPattern, studentWorkFileIds, studentRemarks, instructorRemarks, reportCardSnapshot, compiledContent, snippet, generatedImages }) {
  const portfolio = {
    familyId: new ObjectId(familyId),
    studentId: new ObjectId(studentId),
    studentName,
    designPattern,
    studentWorkFileIds: studentWorkFileIds.map(id => new ObjectId(id)),
    studentRemarks: studentRemarks ?? null,
    instructorRemarks: instructorRemarks ?? null,
    reportCardSnapshot: reportCardSnapshot ?? null,
    compiledContent: compiledContent ?? '',
    snippet: snippet ?? '',
    generatedImages: generatedImages ?? [],
    createdAt: new Date(),
    updatedAt: new Date()
  }

  const result = await portfoliosCollection().insertOne(portfolio)
  return { ...portfolio, _id: result.insertedId }
}

export async function findPortfoliosByFamilyId (familyId) {
  return portfoliosCollection().find({ familyId: new ObjectId(familyId) }).sort({ createdAt: -1 }).toArray()
}

export async function findPortfolioById (id) {
  return portfoliosCollection().findOne({ _id: new ObjectId(id) })
}

export async function updatePortfolio (id, { compiledContent, snippet }) {
  const update = {}
  if (compiledContent !== undefined) update.compiledContent = compiledContent
  if (snippet !== undefined) update.snippet = snippet
  update.updatedAt = new Date()

  const result = await portfoliosCollection().findOneAndUpdate(
    { _id: new ObjectId(id) },
    { $set: update },
    { returnDocument: 'after' }
  )

  return result.value
}

export async function deletePortfolio (id) {
  const result = await portfoliosCollection().deleteOne({ _id: new ObjectId(id) })
  return result.deletedCount > 0
}

