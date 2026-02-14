// Family resource folders – user-created folders to organize resources.

import { ObjectId } from 'mongodb'
import { getCollection } from '../lib/mongo.js'

const RESOURCE_FOLDERS_COLLECTION = 'resourceFolders'

function resourceFoldersCollection () {
  return getCollection(RESOURCE_FOLDERS_COLLECTION)
}

export async function createResourceFolder ({ familyId, name, parentFolderId }) {
  const folder = {
    familyId: new ObjectId(familyId),
    name: name?.trim() || 'New Folder',
    parentFolderId: parentFolderId ? new ObjectId(parentFolderId) : null,
    createdAt: new Date(),
    updatedAt: new Date()
  }
  const result = await resourceFoldersCollection().insertOne(folder)
  return { ...folder, _id: result.insertedId }
}

export async function findResourceFoldersByFamilyId (familyId) {
  const docs = await resourceFoldersCollection()
    .find({ familyId: new ObjectId(familyId) })
    .sort({ name: 1 })
    .toArray()
  return docs
}

export async function findResourceFolderById (id) {
  const doc = await resourceFoldersCollection().findOne({ _id: new ObjectId(id) })
  return doc
}

export async function updateResourceFolder (id, { name, parentFolderId }) {
  const update = { updatedAt: new Date() }
  if (name !== undefined) update.name = name?.trim() ?? ''
  if (parentFolderId !== undefined) update.parentFolderId = parentFolderId ? new ObjectId(parentFolderId) : null
  const result = await resourceFoldersCollection().findOneAndUpdate(
    { _id: new ObjectId(id) },
    { $set: update },
    { returnDocument: 'after' }
  )
  return result?.value ?? null
}

export async function deleteResourceFolder (id) {
  const result = await resourceFoldersCollection().deleteOne({ _id: new ObjectId(id) })
  return result.deletedCount > 0
}
