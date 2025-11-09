import { MongoClient } from 'mongodb'
import dotenv from 'dotenv'
dotenv.config()

const uri = process.env.MONGODB_URI

if (!uri) {
  console.log(uri)
  throw new Error('MONGODB_URI env var is required')
}

let client
let db

export async function connectToDatabase () {
  if (db) {
    return db
  }

  client = new MongoClient(uri)
  await client.connect()
  db = client.db()
  console.log('Connected to MongoDB')
  return db
}

export function getDb () {
  if (!db) {
    throw new Error('Database connection has not been established')
  }
  return db
}

export function getCollection (name) {
  return getDb().collection(name)
}

process.on('SIGINT', async () => {
  if (client) {
    await client.close()
  }
  process.exit(0)
})

