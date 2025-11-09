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
    return cachedKeys
  }

  const { data } = await axios.get(APPLE_KEYS_URL)
  cachedKeys = data.keys
  cacheExpiry = now + (60 * 60 * 1000)
  return cachedKeys
}

export async function verifyAppleIdentityToken (identityToken, audience) {
  if (!identityToken) {
    throw new Error('Missing identity token')
  }

  const keys = await fetchAppleKeys()
  const decodedHeader = jwt.decode(identityToken, { complete: true })
  if (!decodedHeader) {
    throw new Error('Unable to decode identity token')
  }

  const key = keys.find(k => k.kid === decodedHeader.header.kid)
  if (!key) {
    throw new Error('Unable to find matching Apple public key')
  }

  const publicKey = jwkToPem(key)

  const verified = jwt.verify(identityToken, publicKey, {
    algorithms: ['RS256'],
    audience,
    issuer: 'https://appleid.apple.com'
  })

  return verified
}

