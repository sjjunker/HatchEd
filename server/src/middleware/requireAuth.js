// Updated with assistance from Cursor (ChatGPT) on 11/7/25.

import { verifyToken } from '../utils/jwt.js'

export function requireAuth (req, _res, next) {
  const authHeader = req.headers.authorization
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    const err = new Error('Authentication required')
    err.status = 401
    throw err
  }

  const token = authHeader.replace('Bearer ', '')

  try {
    const payload = verifyToken(token)
    req.user = payload
    next()
  } catch (error) {
    error.status = 401
    throw error
  }
}

