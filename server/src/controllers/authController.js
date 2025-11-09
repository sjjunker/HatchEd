// Updated with assistance from Cursor (ChatGPT) on 11/7/25.

import { verifyAppleIdentityToken } from '../services/appleAuth.js'
import { upsertUserByAppleId } from '../models/userModel.js'
import { signToken } from '../utils/jwt.js'
import { serializeUser } from '../utils/serializers.js'
import { ObjectId } from 'mongodb'

export async function appleSignIn (req, res) {
  const { identityToken, fullName, email } = req.body
  if (!identityToken) {
    return res.status(400).json({ error: { message: 'identityToken is required' } })
  }

  const audience = process.env.APPLE_CLIENT_ID
  const payload = await verifyAppleIdentityToken(identityToken, audience)

  const appleId = payload.sub
  const updateData = {}
  const resolvedEmail = email ?? payload.email
  if (resolvedEmail) updateData.email = resolvedEmail
  const resolvedName = fullName ?? payload.name
  if (resolvedName) updateData.name = resolvedName
  if (payload.role) updateData.role = payload.role

  const user = await upsertUserByAppleId(appleId, updateData)

  const userId = user._id instanceof ObjectId ? user._id.toString() : user._id

  const token = signToken({
    userId,
    appleId: user.appleId,
    role: user.role
  })

  res.json({
    token,
    user: serializeUser({ ...user, _id: userId })
  })
}

