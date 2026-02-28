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
    pendingDeletionAt: null,
    scheduledDeletionAt: null,
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
  if (result?.value) return result.value
  const fallback = await resourceFoldersCollection().findOne({ _id: new ObjectId(id) })
  return fallback ?? null
}

export async function deleteResourceFolder (id) {
  const result = await resourceFoldersCollection().deleteOne({ _id: new ObjectId(id) })
  return result.deletedCount > 0
}

export async function deleteResourceFoldersByIds (folderIds) {
  const ids = Array.isArray(folderIds) ? folderIds.filter(Boolean).map(id => new ObjectId(id)) : []
  if (!ids.length) return 0
  const result = await resourceFoldersCollection().deleteMany({ _id: { $in: ids } })
  return result.deletedCount
}

export async function scheduleResourceFolderDeletion (id, scheduledDeletionAt) {
  const now = new Date()
  const result = await resourceFoldersCollection().findOneAndUpdate(
    { _id: new ObjectId(id) },
    {
      $set: {
        pendingDeletionAt: now,
        scheduledDeletionAt,
        updatedAt: now
      }
    },
    { returnDocument: 'after' }
  )
  if (result?.value) return result.value
  const fallback = await resourceFoldersCollection().findOne({ _id: new ObjectId(id) })
  return fallback ?? null
}

export async function undoScheduledResourceFolderDeletion (id) {
  const now = new Date()
  const result = await resourceFoldersCollection().findOneAndUpdate(
    { _id: new ObjectId(id) },
    {
      $set: {
        pendingDeletionAt: null,
        scheduledDeletionAt: null,
        updatedAt: now
      }
    },
    { returnDocument: 'after' }
  )
  if (result?.value) return result.value
  const fallback = await resourceFoldersCollection().findOne({ _id: new ObjectId(id) })
  return fallback ?? null
}
