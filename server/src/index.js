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
import { errorHandler } from './middleware/errorHandler.js'

const __filename = fileURLToPath(import.meta.url)
const __dirname = dirname(__filename)
dotenv.config({ path: join(__dirname, '../.env') })

const app = express()

app.use(helmet())
app.use(cors({ origin: true, credentials: true }))
app.use(express.json())
app.use(cookieParser())

app.get('/health', (_req, res) => {
  res.json({ status: 'ok' })
})

app.use('/api/auth', authRoutes)
app.use('/api/users', userRoutes)
app.use('/api/families', familyRoutes)
app.use('/api/notifications', notificationRoutes)
app.use('/api/attendance', attendanceRoutes)

app.use(errorHandler)

const port = process.env.PORT || 4000

async function start () {
  try {
    const db = await connectToDatabase()
    app.locals.db = db
    app.listen(port, () => {
      console.log(`API listening on port ${port}`)
    })
  } catch (error) {
    console.error('Failed to start server', error)
    process.exit(1)
  }
}

start()

