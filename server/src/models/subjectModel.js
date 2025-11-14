// Updated with assistance from Cursor (ChatGPT) on 11/7/25.

import { ObjectId } from 'mongodb'
import { getCollection } from '../lib/mongo.js'

const SUBJECTS_COLLECTION = 'subjects'

function subjectsCollection () {
  return getCollection(SUBJECTS_COLLECTION)
}

export async function createSubject ({ familyId, name }) {
  const subject = {
    familyId: new ObjectId(familyId),
    name,
    createdAt: new Date(),
    updatedAt: new Date()
  }

  const result = await subjectsCollection().insertOne(subject)
  return { ...subject, _id: result.insertedId }
}

export async function findSubjectsByFamilyId (familyId) {
  return subjectsCollection().find({ familyId: new ObjectId(familyId) }).sort({ name: 1 }).toArray()
}

export async function findSubjectById (id) {
  return subjectsCollection().findOne({ _id: new ObjectId(id) })
}

export async function updateSubject (id, { name }) {
  const update = {}
  if (name !== undefined) update.name = name
  update.updatedAt = new Date()

  const result = await subjectsCollection().findOneAndUpdate(
    { _id: new ObjectId(id) },
    { $set: update },
    { returnDocument: 'after' }
  )

  return result.value
}

export async function deleteSubject (id) {
  const result = await subjectsCollection().deleteOne({ _id: new ObjectId(id) })
  return result.deletedCount > 0
}

