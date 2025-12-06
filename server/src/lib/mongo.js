// Updated with assistance from Cursor (ChatGPT) on 11/7/25.

import { MongoClient } from 'mongodb'
import dotenv from 'dotenv'
import { DatabaseError } from '../utils/errors.js'
dotenv.config()

const uri = process.env.MONGODB_URI

console.log('[Database] Initializing MongoDB connection...', {
  timestamp: new Date().toISOString(),
  hasUri: !!uri,
  uriLength: uri ? uri.length : 0,
  uriPreview: uri ? `${uri.substring(0, 20)}...` : 'missing'
})

if (!uri) {
  console.error('[Database] MONGODB_URI environment variable is required')
  throw new Error('MONGODB_URI env var is required')
}

let client
let db
let connectionAttempts = 0
const MAX_RETRIES = 3

export async function connectToDatabase () {
  if (db) {
    console.log('[Database] Using existing database connection')
    return db
  }

  const connectionStartTime = Date.now()
  try {
    connectionAttempts++
    console.log('[Database] Starting connection attempt', {
      attempt: connectionAttempts,
      maxRetries: MAX_RETRIES,
      timestamp: new Date().toISOString()
    })

    console.log('[Database] Creating MongoClient instance...', {
      serverSelectionTimeoutMS: 5000,
      retryWrites: true
    })

    client = new MongoClient(uri, {
      serverSelectionTimeoutMS: 30000, // Increased to 30 seconds
      connectTimeoutMS: 30000, // Connection timeout
      socketTimeoutMS: 45000, // Socket timeout for operations
      retryWrites: true,
      maxPoolSize: 10,
      minPoolSize: 1
    })

    console.log('[Database] Attempting to connect to MongoDB server...')
    const connectStartTime = Date.now()
    await client.connect()
    const connectDuration = Date.now() - connectStartTime

    console.log('[Database] MongoDB client connected successfully', {
      duration: `${connectDuration}ms`,
      timestamp: new Date().toISOString()
    })

    console.log('[Database] Getting database instance...')
    db = client.db()
    const dbName = db.databaseName
    const totalDuration = Date.now() - connectionStartTime

    console.log('[Database] Database connection established successfully', {
      databaseName: dbName,
      totalDuration: `${totalDuration}ms`,
      timestamp: new Date().toISOString()
    })

    // Log connection status
    try {
      const adminDb = db.admin()
      const serverStatus = await adminDb.serverStatus()
      console.log('[Database] Server status retrieved', {
        version: serverStatus.version,
        uptime: serverStatus.uptime,
        connections: serverStatus.connections
      })
    } catch (statusError) {
      console.warn('[Database] Could not retrieve server status', {
        error: statusError.message
      })
    }

    connectionAttempts = 0
    return db
  } catch (error) {
    const duration = Date.now() - connectionStartTime
    console.error('[Database] Connection attempt failed', {
      attempt: connectionAttempts,
      error: error.message,
      errorName: error.name,
      duration: `${duration}ms`,
      timestamp: new Date().toISOString()
    })

    if (connectionAttempts < MAX_RETRIES) {
      const retryDelay = 1000 * connectionAttempts
      console.log('[Database] Scheduling retry', {
        attempt: connectionAttempts,
        maxRetries: MAX_RETRIES,
        retryDelay: `${retryDelay}ms`,
        nextRetryAt: new Date(Date.now() + retryDelay).toISOString()
      })
      await new Promise(resolve => setTimeout(resolve, retryDelay))
      return connectToDatabase()
    }

    console.error('[Database] All connection attempts exhausted', {
      totalAttempts: connectionAttempts,
      maxRetries: MAX_RETRIES,
      finalError: error.message
    })
    throw new DatabaseError('Failed to connect to MongoDB after multiple attempts', error)
  }
}

export function getDb () {
  if (!db) {
    console.error('[Database] Attempted to get database but connection not established')
    throw new DatabaseError('Database connection has not been established')
  }
  return db
}

export async function pingDatabase () {
  try {
    if (!db) {
      throw new DatabaseError('Database not connected')
    }
    const adminDb = db.admin()
    const result = await adminDb.ping()
    return result.ok === 1
  } catch (error) {
    console.error('[Database] Ping failed', {
      error: error.message
    })
    return false
  }
}

export function getCollection (name) {
  try {
    console.log('[Database] Getting collection', {
      collectionName: name,
      databaseName: db?.databaseName
    })
    
    if (!db) {
      throw new DatabaseError('Database connection not established')
    }
    
    const collection = getDb().collection(name)
    console.log('[Database] Collection retrieved successfully', {
      collectionName: name
    })
    return collection
  } catch (error) {
    console.error('[Database] Failed to get collection', {
      collectionName: name,
      error: error.message
    })
    throw new DatabaseError(`Failed to get collection: ${name}`, error)
  }
}

// Handle graceful shutdown
process.on('SIGINT', async () => {
  console.log('[Database] SIGINT received, closing MongoDB connection...', {
    timestamp: new Date().toISOString()
  })
  if (client) {
    try {
      const closeStartTime = Date.now()
      await client.close()
      const closeDuration = Date.now() - closeStartTime
      console.log('[Database] MongoDB connection closed successfully', {
        duration: `${closeDuration}ms`,
        timestamp: new Date().toISOString()
      })
    } catch (error) {
      console.error('[Database] Error closing MongoDB connection', {
        error: error.message,
        timestamp: new Date().toISOString()
      })
    }
  } else {
    console.log('[Database] No active client connection to close')
  }
  process.exit(0)
})

process.on('SIGTERM', async () => {
  console.log('[Database] SIGTERM received, closing MongoDB connection...', {
    timestamp: new Date().toISOString()
  })
  if (client) {
    try {
      const closeStartTime = Date.now()
      await client.close()
      const closeDuration = Date.now() - closeStartTime
      console.log('[Database] MongoDB connection closed successfully', {
        duration: `${closeDuration}ms`,
        timestamp: new Date().toISOString()
      })
    } catch (error) {
      console.error('[Database] Error closing MongoDB connection', {
        error: error.message,
        timestamp: new Date().toISOString()
      })
    }
  } else {
    console.log('[Database] No active client connection to close')
  }
  process.exit(0)
})

