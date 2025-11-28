// Custom error classes for better error handling

export class AppError extends Error {
  constructor(message, statusCode = 500, code = 'SERVER_ERROR', isOperational = true) {
    super(message)
    this.statusCode = statusCode
    this.status = statusCode
    this.code = code
    this.isOperational = isOperational
    Error.captureStackTrace(this, this.constructor)
  }
}

export class ValidationError extends AppError {
  constructor(message, fields = {}) {
    super(message, 400, 'VALIDATION_ERROR', true)
    this.fields = fields
  }
}

export class NotFoundError extends AppError {
  constructor(resource = 'Resource') {
    super(`${resource} not found`, 404, 'NOT_FOUND', true)
    this.resource = resource
  }
}

export class UnauthorizedError extends AppError {
  constructor(message = 'Authentication required') {
    super(message, 401, 'UNAUTHORIZED', true)
  }
}

export class ForbiddenError extends AppError {
  constructor(message = 'Access forbidden') {
    super(message, 403, 'FORBIDDEN', true)
  }
}

export class ConflictError extends AppError {
  constructor(message = 'Resource conflict') {
    super(message, 409, 'CONFLICT', true)
  }
}

export class DatabaseError extends AppError {
  constructor(message = 'Database operation failed', originalError = null) {
    super(message, 500, 'DATABASE_ERROR', true)
    this.originalError = originalError
  }
}

// Helper function to handle MongoDB errors
export function handleMongoError(error) {
  // Duplicate key error (E11000)
  if (error.code === 11000) {
    const field = Object.keys(error.keyPattern || {})[0] || 'field'
    return new ConflictError(`${field} already exists`)
  }

  // Validation error
  if (error.name === 'ValidationError') {
    const fields = {}
    if (error.errors) {
      Object.keys(error.errors).forEach(key => {
        fields[key] = error.errors[key].message
      })
    }
    return new ValidationError('Validation failed', fields)
  }

  // Cast error (invalid ObjectId, etc.)
  if (error.name === 'CastError') {
    return new ValidationError(`Invalid ${error.path || 'ID'}`)
  }

  // MongoDB connection errors
  if (error.name === 'MongoServerError' || error.name === 'MongoNetworkError') {
    return new DatabaseError('Database connection error', error)
  }

  // Generic MongoDB error
  if (error.name?.includes('Mongo')) {
    return new DatabaseError('Database operation failed', error)
  }

  return null
}

// Helper function to handle JWT errors
export function handleJWTError(error) {
  if (error.name === 'JsonWebTokenError') {
    return new UnauthorizedError('Invalid token')
  }
  if (error.name === 'TokenExpiredError') {
    return new UnauthorizedError('Token expired')
  }
  return null
}

