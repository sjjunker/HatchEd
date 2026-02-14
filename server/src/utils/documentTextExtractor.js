/**
 * Extract plain text from uploaded work files for portfolio AI (quotes, Student Work Samples).
 * Supports: text/plain, .docx (Word), .pdf, .pages (Apple Pages: PDF preview or native IWA).
 */
import { createRequire } from 'module'

const require = createRequire(import.meta.url)
const { dechunk, uncompress } = require('keynote-archives')

/**
 * Extract readable UTF-8 strings from IWA decompressed buffer (protobuf-style binary).
 * Uses simple heuristic: runs of printable characters (min length 4).
 */
function extractStringsFromIwaBuffer (buffer) {
  if (!buffer || buffer.length === 0) return ''
  const decoded = (Buffer.isBuffer(buffer) ? buffer : Buffer.from(buffer)).toString('utf8', { replacement: ' ' })
  const runs = decoded.match(/[\x20-\x7E\u00A0-\u024F\s]{4,}/g)
  return runs ? runs.map(s => s.trim()).filter(Boolean).join(' ') : ''
}

/**
 * Whether this file type or name suggests we can try to extract text.
 */
export function canExtractText (fileType, fileName) {
  const ft = (fileType || '').toLowerCase()
  const name = (fileName || '').toLowerCase()
  if (ft.startsWith('text/') || ft.includes('plain')) return true
  if (ft.includes('wordprocessingml') || ft.includes('docx') || name.endsWith('.docx')) return true
  if (ft.includes('pdf') || name.endsWith('.pdf')) return true
  if (ft.includes('pages') || ft.includes('iwork') || name.endsWith('.pages')) return true
  return false
}

/**
 * Extract text from a file buffer. Returns a string or null if unsupported / failed.
 * @param {Buffer} buffer - Raw file bytes (e.g. from base64 decode of fileData)
 * @param {string} fileType - MIME type (e.g. application/vnd.openxmlformats-...)
 * @param {string} fileName - Original file name (e.g. report.docx)
 * @returns {Promise<string|null>}
 */
export async function extractTextFromBuffer (buffer, fileType, fileName) {
  if (!buffer || !Buffer.isBuffer(buffer)) return null
  const ft = (fileType || '').toLowerCase()
  const name = (fileName || '').toLowerCase()

  // Plain text
  if (ft.startsWith('text/') || ft.includes('plain')) {
    try {
      const text = buffer.toString('utf8')
      return text && text.trim().length > 0 ? text : null
    } catch {
      return null
    }
  }

  // DOCX (Word)
  if (ft.includes('wordprocessingml') || ft.includes('docx') || name.endsWith('.docx')) {
    try {
      const { extractRawText } = await import('mammoth')
      const result = await extractRawText({ buffer })
      const text = result?.value?.trim()
      return text && text.length > 0 ? text : null
    } catch (err) {
      console.warn('[documentTextExtractor] DOCX extract failed:', fileName, err?.message)
      return null
    }
  }

  // PDF
  if (ft.includes('pdf') || name.endsWith('.pdf')) {
    try {
      const { PDFParse } = await import('pdf-parse')
      const parser = new PDFParse({ data: buffer })
      const result = await parser.getText()
      await parser.destroy?.()
      const text = result?.text?.trim()
      return text && text.length > 0 ? text : null
    } catch (err) {
      console.warn('[documentTextExtractor] PDF extract failed:', fileName, err?.message)
      return null
    }
  }

  // Apple Pages (.pages is a zip; may contain Preview.pdf or native IWA)
  if (ft.includes('pages') || ft.includes('iwork') || name.endsWith('.pages')) {
    try {
      const AdmZip = (await import('adm-zip')).default
      const zip = new AdmZip(buffer)
      const entries = zip.getEntries()
      // 1) Prefer Preview.pdf or any .pdf inside (Pages often embeds a PDF preview)
      let pdfEntry = entries.find(e => e.entryName === 'Preview.pdf' || e.entryName.endsWith('.pdf'))
      if (!pdfEntry) {
        const quickLook = entries.find(e => e.entryName.includes('QuickLook') && e.entryName.endsWith('.pdf'))
        if (quickLook) pdfEntry = quickLook
      }
      if (pdfEntry && !pdfEntry.isDirectory) {
        const pdfBuffer = zip.readFile(pdfEntry)
        if (pdfBuffer && Buffer.isBuffer(pdfBuffer)) {
          const { PDFParse } = await import('pdf-parse')
          const parser = new PDFParse({ data: pdfBuffer })
          const result = await parser.getText()
          await parser.destroy?.()
          const text = result?.text?.trim()
          if (text && text.length > 0) return text
        }
      }
      // 2) Native .pages: decompress IWA chunks and extract text from protobuf payloads
      const iwaEntries = entries.filter(e => !e.isDirectory && e.entryName.endsWith('.iwa'))
      if (iwaEntries.length > 0) {
        const parts = []
        for (const entry of iwaEntries) {
          const iwaBuffer = zip.readFile(entry)
          if (!iwaBuffer || !Buffer.isBuffer(iwaBuffer)) continue
          const iwaBytes = new Uint8Array(iwaBuffer)
          try {
            for await (const chunk of dechunk(iwaBytes)) {
              try {
                const decompressed = await uncompress(chunk.data)
                const text = extractStringsFromIwaBuffer(decompressed)
                if (text) parts.push(text)
              } catch (_) { /* skip bad chunk */ }
            }
          } catch (_) { /* skip bad .iwa file */ }
        }
        const text = parts.join('\n').trim()
        return text && text.length > 0 ? text : null
      }
      console.warn('[documentTextExtractor] Pages file has no PDF and no .iwa:', fileName)
      return null
    } catch (err) {
      console.warn('[documentTextExtractor] Pages extract failed:', fileName, err?.message)
      return null
    }
  }

  return null
}
