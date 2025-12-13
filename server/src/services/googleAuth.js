// Google OAuth token verification service

import { OAuth2Client } from 'google-auth-library'

const client = new OAuth2Client()

export async function verifyGoogleIdToken (idToken) {
  if (!idToken) {
    console.error('[Google Auth] Missing ID token')
    throw new Error('Missing ID token')
  }

  console.log('[Google Auth] Starting token verification', {
    tokenLength: idToken.length
  })

  try {
    // Verify the token
    const ticket = await client.verifyIdToken({
      idToken,
      audience: process.env.GOOGLE_CLIENT_ID // This should be the iOS client ID
    })

    const payload = ticket.getPayload()

    console.log('[Google Auth] Token verified successfully', {
      googleId: payload.sub,
      email: payload.email,
      name: payload.name,
      issuer: payload.iss,
      expiresAt: payload.exp ? new Date(payload.exp * 1000).toISOString() : null
    })

    return payload
  } catch (error) {
    console.error('[Google Auth] Token verification failed', {
      error: error.message,
      name: error.name
    })
    throw error
  }
}

