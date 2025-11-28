// 404 handler for unmatched routes

import { NotFoundError } from '../utils/errors.js'

export function notFoundHandler (req, res, next) {
  const error = new NotFoundError(`Route ${req.method} ${req.originalUrl}`)
  next(error)
}

