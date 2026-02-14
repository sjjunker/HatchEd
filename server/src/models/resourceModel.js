// Family resources – files, links, photos with optional assignment link.

import { ObjectId } from 'mongodb'
import { getCollection } from '../lib/mongo.js'

const RESOURCES_COLLECTION = 'resources'

const VALID_TYPES = ['file', 'link', 'photo']

function resourcesCollection () {
  return getCollection(RESOURCES_COLLECTION)
}

function normalizeType (type) {
  const t = (type || '').toLowerCase()
  return VALID_TYPES.includes(t) ? t : 'file'
}

export async function createResource ({
  familyId,
  folderId,
  displayName,
  type,
  fileUrl,
  url,
  mimeType,
  fileSize,
  assignmentId
}) {
  const resourceType = normalizeType(type)
  const resource = {
    familyId: new ObjectId(familyId),
    folderId: folderId ? new ObjectId(folderId) : null,
    displayName: (displayName || '').trim() || 'Untitled',
    type: resourceType,
    fileUrl: fileUrl || null,
    url: url || null,
    mimeType: mimeType || null,
    fileSize: fileSize != null ? Number(fileSize) : null,
    assignmentId: assignmentId ? new ObjectId(assignmentId) : null,
    createdAt: new Date(),
    updatedAt: new Date()
  }
  const result = await resourcesCollection().insertOne(resource)
  return { ...resource, _id: result.insertedId }
}

export async function findResourcesByFamilyId (familyId, { folderId } = {}) {
  const query = { familyId: new ObjectId(familyId) }
  if (folderId !== undefined) {
    query.folderId = folderId ? new ObjectId(folderId) : null
  }
  const docs = await resourcesCollection()
    .find(query)
    .sort({ displayName: 1, createdAt: -1 })
    .toArray()
  return docs
}

export async function findResourcesByAssignmentId (assignmentId) {
  const docs = await resourcesCollection()
    .find({ assignmentId: new ObjectId(assignmentId) })
    .sort({ displayName: 1 })
    .toArray()
  return docs
}

export async function findResourceById (id) {
  const doc = await resourcesCollection().findOne({ _id: new ObjectId(id) })
  return doc
}

export async function updateResource (id, { displayName, folderId, assignmentId }) {
  const update = { updatedAt: new Date() }
  if (displayName !== undefined) update.displayName = (displayName || '').trim() || 'Untitled'
  if (folderId !== undefined) update.folderId = folderId ? new ObjectId(folderId) : null
  if (assignmentId !== undefined) update.assignmentId = assignmentId ? new ObjectId(assignmentId) : null
  const result = await resourcesCollection().findOneAndUpdate(
    { _id: new ObjectId(id) },
    { $set: update },
    { returnDocument: 'after' }
  )
  return result?.value ?? null
}

export async function deleteResource (id) {
  const result = await resourcesCollection().deleteOne({ _id: new ObjectId(id) })
  return result.deletedCount > 0
}

/** Unlink all resources from an assignment (e.g. when assignment is deleted). */
export async function unlinkResourcesByAssignmentId (assignmentId) {
  const result = await resourcesCollection().updateMany(
    { assignmentId: new ObjectId(assignmentId) },
    { $set: { assignmentId: null, updatedAt: new Date() } }
  )
  return result.modifiedCount
}

/** Delete all resources in a folder (for folder delete cascade). */
export async function deleteResourcesByFolderId (folderId) {
  const result = await resourcesCollection().deleteMany({ folderId: new ObjectId(folderId) })
  return result.deletedCount
}

/** Delete all resources for a family (for cascade). */
export async function deleteResourcesByFamilyId (familyId) {
  const result = await resourcesCollection().deleteMany({ familyId: new ObjectId(familyId) })
  return result.deletedCount
}
