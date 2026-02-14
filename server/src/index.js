// Updated with assistance from Cursor (ChatGPT) on 11/7/25.

import express from 'express'
import cors from 'cors'
import helmet from 'helmet'
import cookieParser from 'cookie-parser'
import dotenv from 'dotenv'
import { fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'

import { connectToDatabase } from './lib/mongo.js'
import authRoutes from './routes/auth.js'
import userRoutes from './routes/users.js'
import familyRoutes from './routes/families.js'
import notificationRoutes from './routes/notifications.js'
import attendanceRoutes from './routes/attendance.js'
import subjectsRoutes from './routes/subjects.js'
import portfolioRoutes from './routes/portfolios.js'
import plannerRoutes from './routes/planner.js'
import inviteRoutes from './routes/invite.js'
import { errorHandler } from './middleware/errorHandler.js'
import { notFoundHandler } from './middleware/notFoundHandler.js'

const __filename = fileURLToPath(import.meta.url)
const __dirname = dirname(__filename)
dotenv.config({ path: join(__dirname, '../.env') })

const app = express()

// Trust proxy - required for correct IP addresses and x-forwarded-* headers behind Render's load balancer
app.set('trust proxy', 1)

// Request logging middleware (before other middleware)
app.use((req, res, next) => {
  const startTime = Date.now()
  console.log('[Request]', {
    method: req.method,
    path: req.path,
    ip: req.ip,
    timestamp: new Date().toISOString()
  })
  
  res.on('finish', () => {
    const duration = Date.now() - startTime
    console.log('[Request]', {
      method: req.method,
      path: req.path,
      status: res.statusCode,
      duration: `${duration}ms`,
      timestamp: new Date().toISOString()
    })
  })
  next()
})

// HTTPS redirect middleware (production only)
if (process.env.NODE_ENV === 'production') {
  app.use((req, res, next) => {
    if (req.headers['x-forwarded-proto'] !== 'https') {
      return res.redirect(`https://${req.headers.host}${req.url}`)
    }
    next()
  })
}

app.use(helmet())
app.use(cors({ origin: true, credentials: true }))
app.use(express.json({ limit: '10mb' }))
app.use(cookieParser())

// Request timeout middleware
app.use((req, res, next) => {
  // Set a longer timeout for portfolio creation (5 minutes), shorter for other requests (30 seconds)
  const timeout = req.path.includes('/api/portfolios') && req.method === 'POST' ? 300000 : 30000
  req.setTimeout(timeout, () => {
    if (!res.headersSent) {
      res.status(408).json({
        error: {
          message: 'Request timeout',
          code: 'REQUEST_TIMEOUT'
        }
      })
    }
  })
  next()
})

app.get('/', (_req, res) => {
  res.json({ 
    message: 'HatchEd API Server',
    version: '1.0.0',
    status: 'running',
    timestamp: new Date().toISOString(),
    endpoints: {
      health: '/health',
      auth: '/api/auth',
      users: '/api/users',
      families: '/api/families',
      notifications: '/api/notifications',
      attendance: '/api/attendance',
      subjects: '/api/subjects',
      portfolios: '/api/portfolios',
      planner: '/api/planner',
      invite: '/api/invite'
    }
  })
})

app.get('/health', (_req, res) => {
  res.json({ 
    status: 'ok',
    timestamp: new Date().toISOString(),
    database: app.locals.db ? 'connected' : 'disconnected'
  })
})

app.use('/api/auth', authRoutes)
app.use('/api/users', userRoutes)
app.use('/api/families', familyRoutes)
app.use('/api/notifications', notificationRoutes)
app.use('/api/attendance', attendanceRoutes)
app.use('/api/subjects', subjectsRoutes)
app.use('/api/portfolios', portfolioRoutes)
app.use('/api/planner', plannerRoutes)
app.use('/api/invite', inviteRoutes)

// Serve uploaded files
app.use('/uploads', express.static('uploads'))

// 404 handler - must be after all routes
app.use(notFoundHandler)

// Error handler - must be last
app.use(errorHandler)

// Handle uncaught exceptions
process.on('uncaughtException', (error) => {
  console.error('Uncaught Exception:', {
    message: error.message,
    stack: error.stack,
    timestamp: new Date().toISOString()
  })
  process.exit(1)
})

// Handle unhandled promise rejections
process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise, 'reason:', reason)
  // In production, you might want to log this to an error tracking service
  // For now, we'll just log it but not exit the process
})

const port = process.env.PORT || 4000

async function start () {
  try {
    console.log('[Server] Starting server initialization...', {
      timestamp: new Date().toISOString(),
      port,
      nodeEnv: process.env.NODE_ENV || 'development'
    })

    console.log('[Server] Connecting to database...')
    const dbStartTime = Date.now()
    const db = await connectToDatabase()
    const dbDuration = Date.now() - dbStartTime
    console.log('[Server] Database connection completed', {
      duration: `${dbDuration}ms`,
      databaseName: db.databaseName
    })

    app.locals.db = db
    console.log('[Server] Database instance attached to app.locals')

    // Check OpenAI API key configuration
    if (process.env.OPENAI_API_KEY) {
      const keyPreview = process.env.OPENAI_API_KEY.substring(0, 7) + '...' + process.env.OPENAI_API_KEY.slice(-4)
      console.log('[Server] OpenAI API key configured', { preview: keyPreview })
    } else {
      console.warn('[Server] WARNING: OPENAI_API_KEY not set! Portfolio AI generation will not work.')
      console.warn('[Server] Set OPENAI_API_KEY in your .env file or environment variables.')
    }

    console.log('[Server] Starting HTTP server...')
    // Listen on all interfaces (0.0.0.0) to allow network access
    app.listen(port, '0.0.0.0', () => {
      console.log('[Server] API server started successfully', {
        port,
        host: '0.0.0.0',
        timestamp: new Date().toISOString(),
        environment: process.env.NODE_ENV || 'development',
        accessibleAt: [
          `http://localhost:${port}`,
          `http://127.0.0.1:${port}`,
          ...(process.env.NODE_ENV === 'production' ? [] : [
            `https://hatched-46ar.onrender.com`
          ])
        ]
      })
    })
    
    // Set up background task to check for overdue assignments once per day
    const { checkAllFamiliesOverdueAssignments } = await import('./services/assignmentNotificationService.js')
    const ONE_DAY_MS = 24 * 60 * 60 * 1000
    setInterval(() => {
      checkAllFamiliesOverdueAssignments().catch(err => {
        console.error('Error in scheduled overdue assignment check:', {
          message: err.message,
          stack: err.stack,
          timestamp: new Date().toISOString()
        })
      })
    }, ONE_DAY_MS)
    // Run first check 60 seconds after startup
    setTimeout(() => {
      checkAllFamiliesOverdueAssignments().catch(err => {
        console.error('Error in initial overdue assignment check:', {
          message: err.message,
          stack: err.stack,
          timestamp: new Date().toISOString()
        })
      })
    }, 60000)
  } catch (error) {
    console.error('Failed to start server:', {
      message: error.message,
      stack: error.stack,
      timestamp: new Date().toISOString()
    })
    process.exit(1)
  }
}

start()

