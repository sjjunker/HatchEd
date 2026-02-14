// Family resources: folders and resources (file, link, photo) with optional assignment link.

import path from 'node:path'
import fs from 'node:fs'
import { findUserById } from '../models/userModel.js'
import {
  createResourceFolder,
  findResourceFoldersByFamilyId,
  findResourceFolderById,
  updateResourceFolder,
  deleteResourceFolder
} from '../models/resourceFolderModel.js'
import {
  createResource,
  findResourcesByFamilyId,
  findResourcesByAssignmentId,
  findResourceById,
  updateResource,
  deleteResource,
  deleteResourcesByFolderId,
  unlinkResourcesByAssignmentId
} from '../models/resourceModel.js'
import { serializeResourceFolder, serializeResource } from '../utils/serializers.js'
import multer from 'multer'

  const upload = multer({
  dest: 'uploads/',
  limits: { fileSize: 50 * 1024 * 1024 }, // 50MB
  fileFilter: (_req, file, cb) => cb(null, true)
})

export const handleMulterError = (err, req, res, next) => {
  if (err instanceof multer.MulterError) {
    if (err.code === 'LIMIT_FILE_SIZE') {
      return res.status(400).json({ error: { message: 'File too large. Maximum size is 50MB.' } })
    }
    return res.status(400).json({ error: { message: `Upload error: ${err.message}` } })
  }
  if (err) return res.status(500).json({ error: { message: 'File upload failed' } })
  next()
}

// --- Folders ---
export async function getFoldersHandler (req, res) {
  const user = await findUserById(req.user.userId)
  if (!user?.familyId) return res.json({ folders: [] })
  const folders = await findResourceFoldersByFamilyId(user.familyId)
  res.json({ folders: folders.map(serializeResourceFolder) })
}

export async function createFolderHandler (req, res) {
  const user = await findUserById(req.user.userId)
  if (!user?.familyId) return res.status(400).json({ error: { message: 'User must belong to a family' } })
  const { name, parentFolderId } = req.body
  const folder = await createResourceFolder({
    familyId: user.familyId,
    name: name?.trim() || 'New Folder',
    parentFolderId: parentFolderId || null
  })
  res.status(201).json({ folder: serializeResourceFolder(folder) })
}

export async function updateFolderHandler (req, res) {
  const user = await findUserById(req.user.userId)
  if (!user?.familyId) return res.status(400).json({ error: { message: 'User must belong to a family' } })
  const folder = await findResourceFolderById(req.params.id)
  if (!folder) return res.status(404).json({ error: { message: 'Folder not found' } })
  if (folder.familyId.toString() !== user.familyId.toString()) return res.status(403).json({ error: { message: 'Not authorized' } })
  const { name, parentFolderId } = req.body
  const updated = await updateResourceFolder(req.params.id, { name, parentFolderId })
  res.json({ folder: serializeResourceFolder(updated) })
}

export async function deleteFolderHandler (req, res) {
  const user = await findUserById(req.user.userId)
  if (!user?.familyId) return res.status(400).json({ error: { message: 'User must belong to a family' } })
  const folder = await findResourceFolderById(req.params.id)
  if (!folder) return res.status(404).json({ error: { message: 'Folder not found' } })
  if (folder.familyId.toString() !== user.familyId.toString()) return res.status(403).json({ error: { message: 'Not authorized' } })
  await deleteResourcesByFolderId(req.params.id)
  await deleteResourceFolder(req.params.id)
  res.json({ success: true })
}

// --- Resources ---
export async function getResourcesHandler (req, res) {
  const user = await findUserById(req.user.userId)
  if (!user?.familyId) return res.json({ resources: [] })
  const folderId = req.query.folderId
  // No folderId or empty = root only (folderId null); otherwise filter by that folder
  const filterFolderId = folderId === undefined || folderId === '' ? null : folderId
  const resources = await findResourcesByFamilyId(user.familyId, { folderId: filterFolderId })
  res.json({ resources: resources.map(serializeResource) })
}

export async function getResourcesForAssignmentHandler (req, res) {
  const user = await findUserById(req.user.userId)
  if (!user?.familyId) return res.json({ resources: [] })
  const assignmentId = req.params.assignmentId
  const resources = await findResourcesByAssignmentId(assignmentId)
  res.json({ resources: resources.map(serializeResource) })
}

/** Serve the actual file for a resource (auth required, streams file from disk using DB record). */
export async function getResourceFileHandler (req, res) {
  const user = await findUserById(req.user.userId)
  if (!user?.familyId) return res.status(400).json({ error: { message: 'User must belong to a family' } })
  const resource = await findResourceById(req.params.id)
  if (!resource) return res.status(404).json({ error: { message: 'Resource not found' } })
  if (resource.familyId.toString() !== user.familyId.toString()) return res.status(403).json({ error: { message: 'Not authorized' } })
  if (!resource.fileUrl || typeof resource.fileUrl !== 'string') return res.status(404).json({ error: { message: 'Resource has no file' } })
  const filePath = path.join(process.cwd(), resource.fileUrl.replace(/^\//, ''))
  if (!fs.existsSync(filePath)) return res.status(404).json({ error: { message: 'File not found' } })
  res.setHeader('Content-Type', resource.mimeType || 'application/octet-stream')
  res.setHeader('Content-Disposition', 'inline')
  res.sendFile(path.resolve(filePath))
}

export async function createResourceHandler (req, res) {
  const user = await findUserById(req.user.userId)
  if (!user?.familyId) return res.status(400).json({ error: { message: 'User must belong to a family' } })
  const { displayName, folderId, type, url, assignmentId } = req.body
  const resourceType = (type || 'link').toLowerCase()
  if (resourceType !== 'link') {
    return res.status(400).json({ error: { message: 'Use upload endpoint for file or photo' } })
  }
  const resource = await createResource({
    familyId: user.familyId,
    folderId: folderId || null,
    displayName: (displayName || '').trim() || 'Untitled',
    type: 'link',
    url: (url || '').trim() || null,
    assignmentId: assignmentId || null
  })
  res.status(201).json({ resource: serializeResource(resource) })
}

export async function uploadResourceHandler (req, res) {
  const user = await findUserById(req.user.userId)
  if (!user?.familyId) return res.status(400).json({ error: { message: 'User must belong to a family' } })
  const { displayName, folderId, type, assignmentId } = req.body || {}
  if (!req.file) return res.status(400).json({ error: { message: 'No file uploaded' } })
  const resourceType = ['file', 'photo'].includes((type || 'file').toLowerCase()) ? type.toLowerCase() : 'file'
  const fileUrl = `/uploads/${req.file.filename}`
  let mimeType = req.file.mimetype || 'application/octet-stream'
  if (mimeType === 'application/octet-stream' && req.file.originalname) {
    const ext = req.file.originalname.split('.').pop()?.toLowerCase()
    if (ext === 'docx') mimeType = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
    else if (ext === 'doc') mimeType = 'application/msword'
  }
  const fileSize = req.file.size
  const resource = await createResource({
    familyId: user.familyId,
    folderId: folderId || null,
    displayName: (displayName || '').trim() || req.file.originalname || 'Untitled',
    type: resourceType,
    fileUrl,
    mimeType,
    fileSize,
    assignmentId: assignmentId || null
  })
  res.status(201).json({ resource: serializeResource(resource) })
}

export async function updateResourceHandler (req, res) {
  const user = await findUserById(req.user.userId)
  if (!user?.familyId) return res.status(400).json({ error: { message: 'User must belong to a family' } })
  const resource = await findResourceById(req.params.id)
  if (!resource) return res.status(404).json({ error: { message: 'Resource not found' } })
  if (resource.familyId.toString() !== user.familyId.toString()) return res.status(403).json({ error: { message: 'Not authorized' } })
  const { displayName, folderId, assignmentId } = req.body
  const updated = await updateResource(req.params.id, { displayName, folderId, assignmentId })
  res.json({ resource: serializeResource(updated) })
}

export async function deleteResourceHandler (req, res) {
  const user = await findUserById(req.user.userId)
  if (!user?.familyId) return res.status(400).json({ error: { message: 'User must belong to a family' } })
  const resource = await findResourceById(req.params.id)
  if (!resource) return res.status(404).json({ error: { message: 'Resource not found' } })
  if (resource.familyId.toString() !== user.familyId.toString()) return res.status(403).json({ error: { message: 'Not authorized' } })
  await deleteResource(req.params.id)
  res.json({ success: true })
}

export { upload }
