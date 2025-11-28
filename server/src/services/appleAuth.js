// Updated with assistance from Cursor (ChatGPT) on 11/7/25.

import axios from 'axios'
import jwt from 'jsonwebtoken'
import jwkToPem from 'jwk-to-pem'

const APPLE_KEYS_URL = 'https://appleid.apple.com/auth/keys'

let cachedKeys = null
let cacheExpiry = 0

async function fetchAppleKeys () {
  const now = Date.now()
  if (cachedKeys && cacheExpiry > now) {
    console.log('[Apple Auth] Using cached Apple public keys')
    return cachedKeys
  }

  console.log('[Apple Auth] Fetching Apple public keys from', APPLE_KEYS_URL)
  try {
    const { data } = await axios.get(APPLE_KEYS_URL, {
      timeout: 10000, // 10 second timeout
      headers: {
        'User-Agent': 'HatchEd-Server/1.0'
      }
    })
    cachedKeys = data.keys
    cacheExpiry = now + (60 * 60 * 1000)
    console.log('[Apple Auth] Apple public keys fetched and cached', {
      keyCount: cachedKeys.length,
      cacheExpiry: new Date(cacheExpiry).toISOString()
    })
    return cachedKeys
  } catch (error) {
    console.error('[Apple Auth] Failed to fetch Apple public keys', {
      error: error.message,
      code: error.code,
      isTimeout: error.code === 'ECONNABORTED' || error.message.includes('timeout')
    })
    // If we have cached keys, use them even if expired
    if (cachedKeys) {
      console.log('[Apple Auth] Using expired cached keys due to fetch failure')
      return cachedKeys
    }
    throw new Error(`Failed to fetch Apple public keys: ${error.message}`)
  }
}

export async function verifyAppleIdentityToken (identityToken, audience) {
  if (!identityToken) {
    console.error('[Apple Auth] Missing identity token')
    throw new Error('Missing identity token')
  }

  console.log('[Apple Auth] Starting token verification', {
    audience,
    tokenLength: identityToken.length
  })

  const keys = await fetchAppleKeys()
  const decodedHeader = jwt.decode(identityToken, { complete: true })
  if (!decodedHeader) {
    console.error('[Apple Auth] Unable to decode identity token header')
    throw new Error('Unable to decode identity token')
  }

  const keyId = decodedHeader.header.kid
  console.log('[Apple Auth] Decoded token header', {
    keyId,
    algorithm: decodedHeader.header.alg
  })

  const key = keys.find(k => k.kid === keyId)
  if (!key) {
    console.error('[Apple Auth] No matching Apple public key found', {
      keyId,
      availableKeyIds: keys.map(k => k.kid)
    })
    throw new Error('Unable to find matching Apple public key')
  }

  console.log('[Apple Auth] Found matching public key, verifying token signature...')
  const publicKey = jwkToPem(key)

  try {
    const verified = jwt.verify(identityToken, publicKey, {
      algorithms: ['RS256'],
      audience,
      issuer: 'https://appleid.apple.com'
    })

    console.log('[Apple Auth] Token verified successfully', {
      appleId: verified.sub,
      issuer: verified.iss,
      audience: verified.aud,
      expiresAt: verified.exp ? new Date(verified.exp * 1000).toISOString() : null
    })

    return verified
  } catch (verifyError) {
    console.error('[Apple Auth] Token verification failed', {
      error: verifyError.message,
      name: verifyError.name
    })
    throw verifyError
  }
}

