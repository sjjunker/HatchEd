// Updated with assistance from Cursor (ChatGPT) on 11/7/25.

import { AppError, handleMongoError, handleJWTError } from '../utils/errors.js'

export function errorHandler (err, req, res, next) {
  // Log error with context
  const errorContext = {
    message: err.message,
    stack: process.env.NODE_ENV === 'development' ? err.stack : undefined,
    url: req.originalUrl,
    method: req.method,
    ip: req.ip,
    user: req.user?.userId || 'anonymous',
    timestamp: new Date().toISOString()
  }

  // Handle MongoDB errors
  const mongoError = handleMongoError(err)
  if (mongoError) {
    console.error('MongoDB Error:', {
      ...errorContext,
      originalError: err.message,
      mongoCode: err.code
    })
    return res.status(mongoError.statusCode).json({
      error: {
        message: mongoError.message,
        code: mongoError.code,
        ...(mongoError.fields && { fields: mongoError.fields })
      }
    })
  }

  // Handle JWT errors
  const jwtError = handleJWTError(err)
  if (jwtError) {
    console.error('JWT Error:', errorContext)
    return res.status(jwtError.statusCode).json({
      error: {
        message: jwtError.message,
        code: jwtError.code
      }
    })
  }

  // Handle custom AppError instances
  if (err instanceof AppError) {
    console.error('Application Error:', errorContext)
    return res.status(err.statusCode).json({
      error: {
        message: err.message,
        code: err.code,
        ...(err.fields && { fields: err.fields })
      }
    })
  }

  // Handle errors with status property (legacy support)
  if (err.status || err.statusCode) {
    const status = err.status || err.statusCode
    console.error('HTTP Error:', errorContext)
    return res.status(status).json({
      error: {
        message: err.message || 'An error occurred',
        code: err.code || 'HTTP_ERROR'
      }
    })
  }

  // Handle multer file upload errors
  if (err.name === 'MulterError') {
    console.error('File Upload Error:', errorContext)
    if (err.code === 'LIMIT_FILE_SIZE') {
      return res.status(400).json({
        error: {
          message: 'File size exceeds the maximum allowed size',
          code: 'FILE_TOO_LARGE'
        }
      })
    }
    return res.status(400).json({
      error: {
        message: 'File upload error',
        code: 'UPLOAD_ERROR',
        details: err.message
      }
    })
  }

  // Handle syntax errors (malformed JSON, etc.)
  if (err instanceof SyntaxError && err.status === 400 && 'body' in err) {
    console.error('JSON Parse Error:', errorContext)
    return res.status(400).json({
      error: {
        message: 'Invalid JSON in request body',
        code: 'INVALID_JSON'
      }
    })
  }

  // Handle unhandled promise rejections and other unexpected errors
  console.error('Unhandled Error:', {
    ...errorContext,
    errorName: err.name,
    errorType: err.constructor?.name
  })

  // Don't leak error details in production
  const isDevelopment = process.env.NODE_ENV === 'development'
  const message = isDevelopment ? err.message : 'Internal Server Error'
  const stack = isDevelopment ? err.stack : undefined

  res.status(500).json({
    error: {
      message,
      code: 'INTERNAL_SERVER_ERROR',
      ...(isDevelopment && { stack })
    }
  })
}

