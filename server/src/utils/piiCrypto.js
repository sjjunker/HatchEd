/**
 * PII encryption utility – encrypts/decrypts PII before storing in the database.
 * Uses AES-256-GCM. Lookup hashes use SHA-256 for queryable fields (e.g. username).
 */

import crypto from 'crypto'

const ALGORITHM = 'aes-256-gcm'
const IV_LENGTH = 12
const AUTH_TAG_LENGTH = 16
const KEY_LENGTH = 32
const PII_PREFIX = 'pii:'

let keyCache = null
let noKeyWarned = false

function getKey () {
  if (keyCache) return keyCache
  const raw = process.env.PII_ENCRYPTION_KEY
  if (!raw || typeof raw !== 'string') {
    if (!noKeyWarned) {
      noKeyWarned = true
      console.warn('[PII] PII_ENCRYPTION_KEY not set – PII will be stored in plaintext. Set a 32-byte key (base64 or hex) for encryption.')
    }
    return null
  }
  const trimmed = raw.trim()
  let buf
  if (trimmed.length === 44 && /^[A-Za-z0-9+/]+=*$/.test(trimmed)) {
    buf = Buffer.from(trimmed, 'base64')
  } else if (trimmed.length === 64 && /^[0-9a-fA-F]+$/.test(trimmed)) {
    buf = Buffer.from(trimmed, 'hex')
  } else {
    buf = crypto.createHash('sha256').update(trimmed, 'utf8').digest()
  }
  if (buf.length !== KEY_LENGTH) {
    throw new Error(`PII_ENCRYPTION_KEY must be 32 bytes (use base64 or hex). Got ${buf.length} bytes.`)
  }
  keyCache = buf
  return keyCache
}

/**
 * Encrypt a string. Returns plaintext if key is not set (with warning).
 * @param {string|null|undefined} plaintext
 * @returns {string}
 */
export function encrypt (plaintext) {
  if (plaintext === null || plaintext === undefined || plaintext === '') {
    return plaintext
  }
  const str = String(plaintext)
  const key = getKey()
  if (!key) return str

  const iv = crypto.randomBytes(IV_LENGTH)
  const cipher = crypto.createCipheriv(ALGORITHM, key, iv, { authTagLength: AUTH_TAG_LENGTH })
  const enc = Buffer.concat([cipher.update(str, 'utf8'), cipher.final()])
  const authTag = cipher.getAuthTag()
  const combined = Buffer.concat([iv, authTag, enc])
  return PII_PREFIX + combined.toString('base64')
}

/**
 * Decrypt a string. Returns input unchanged if not encrypted or key missing (backward compatible).
 * @param {string|null|undefined} ciphertext
 * @returns {string|null|undefined}
 */
export function decrypt (ciphertext) {
  if (ciphertext === null || ciphertext === undefined || ciphertext === '') {
    return ciphertext
  }
  const str = String(ciphertext)
  if (!str.startsWith(PII_PREFIX)) {
    return ciphertext
  }
  const key = getKey()
  if (!key) return ciphertext

  try {
    const combined = Buffer.from(str.slice(PII_PREFIX.length), 'base64')
    if (combined.length < IV_LENGTH + AUTH_TAG_LENGTH) return ciphertext
    const iv = combined.subarray(0, IV_LENGTH)
    const authTag = combined.subarray(IV_LENGTH, IV_LENGTH + AUTH_TAG_LENGTH)
    const enc = combined.subarray(IV_LENGTH + AUTH_TAG_LENGTH)
    const decipher = crypto.createDecipheriv(ALGORITHM, key, iv, { authTagLength: AUTH_TAG_LENGTH })
    decipher.setAuthTag(authTag)
    return decipher.update(enc) + decipher.final('utf8')
  } catch {
    return ciphertext
  }
}

/**
 * Hash for lookup index (e.g. username). Same input always gives same hash.
 * @param {string} plaintext
 * @returns {string} hex digest
 */
export function hashForLookup (plaintext) {
  if (plaintext === null || plaintext === undefined) return ''
  return crypto.createHash('sha256').update(String(plaintext).trim().toLowerCase()).digest('hex')
}

/**
 * Encrypt object values for a list of keys. Modifies the object in place; returns it.
 * @param {Object} obj
 * @param {string[]} keys
 * @returns {Object}
 */
export function encryptFields (obj, keys) {
  if (!obj) return obj
  for (const k of keys) {
    if (obj[k] !== undefined && obj[k] !== null && obj[k] !== '') {
      obj[k] = encrypt(obj[k])
    }
  }
  return obj
}

/**
 * Decrypt object values for a list of keys. Modifies the object in place; returns it.
 * @param {Object} obj
 * @param {string[]} keys
 * @returns {Object}
 */
export function decryptFields (obj, keys) {
  if (!obj) return obj
  for (const k of keys) {
    if (obj[k] !== undefined && obj[k] !== null) {
      obj[k] = decrypt(obj[k])
    }
  }
  return obj
}
