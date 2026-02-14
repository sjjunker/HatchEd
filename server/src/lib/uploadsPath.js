// Resolve uploads directory relative to server app root (same path for multer and file reads)
import path from 'path'
import fs from 'fs/promises'
import { fileURLToPath } from 'node:url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
// From src/lib -> server/src/lib -> go up to server -> server/uploads
export const UPLOADS_DIR = path.join(__dirname, '..', '..', 'uploads')

/**
 * Get the filename from a stored fileUrl (e.g. "/uploads/abc123" -> "abc123").
 */
function filenameFromFileUrl (fileUrl) {
  if (!fileUrl || typeof fileUrl !== 'string') return null
  const parts = fileUrl.replace(/^\//, '').split('/').filter(Boolean)
  return parts.length >= 2 ? parts[1] : parts[0] || null
}

/**
 * Resolve a stored fileUrl (e.g. "/uploads/filename") to an absolute path for reading.
 * Tries: 1) UPLOADS_DIR (server/uploads), 2) cwd/uploads, 3) cwd/../uploads (project root when cwd is server/).
 * Returns { path: string | null, tried: string[] } so callers can log tried paths when missing.
 */
export async function resolveUploadPath (fileUrl) {
  const filename = filenameFromFileUrl(fileUrl)
  if (!filename) return { path: null, tried: [] }
  const candidates = [
    path.join(UPLOADS_DIR, filename),
    path.join(process.cwd(), 'uploads', filename),
    path.join(process.cwd(), '..', 'uploads', filename)
  ]
  const tried = candidates.map(p => path.resolve(p))
  for (const filePath of candidates) {
    try {
      await fs.access(filePath)
      return { path: filePath, tried }
    } catch {
      continue
    }
  }
  return { path: null, tried }
}
