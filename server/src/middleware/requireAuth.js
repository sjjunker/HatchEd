// Updated with assistance from Cursor (ChatGPT) on 11/7/25.

import { verifyToken } from '../utils/jwt.js'
import { UnauthorizedError, handleJWTError } from '../utils/errors.js'

export function requireAuth (req, _res, next) {
  const authHeader = req.headers.authorization
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return next(new UnauthorizedError('Authentication required'))
  }

  const token = authHeader.replace('Bearer ', '')

  try {
    const payload = verifyToken(token)
    req.user = payload
    next()
  } catch (error) {
    // Try to convert JWT errors to our custom error types
    const jwtError = handleJWTError(error)
    if (jwtError) {
      return next(jwtError)
    }
    // Fallback to generic unauthorized error
    return next(new UnauthorizedError('Invalid authentication token'))
  }
}

