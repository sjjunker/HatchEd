import { ObjectId } from 'mongodb'
import { getCollection } from '../lib/mongo.js'

const USERS_COLLECTION = 'users'

function usersCollection () {
  return getCollection(USERS_COLLECTION)
}

export async function findUserByAppleId (appleId) {
  return usersCollection().findOne({ appleId })
}

export async function findUserById (id) {
  return usersCollection().findOne({ _id: new ObjectId(id) })
}

export async function upsertUserByAppleId (appleId, userData) {
  const filteredData = Object.fromEntries(
    Object.entries(userData).filter(([, value]) => value !== undefined)
  )

  const update = {
    $set: {
      ...filteredData,
      updatedAt: new Date()
    },
    $setOnInsert: {
      appleId,
      createdAt: new Date()
    }
  }

  const options = { upsert: true, returnDocument: 'after' }
  const result = await usersCollection().findOneAndUpdate({ appleId }, update, options)

  if (result.value) {
    return result.value
  }

  const upsertedId = result.lastErrorObject?.upserted
  if (upsertedId) {
    return await usersCollection().findOne({ _id: upsertedId })
  }

  const fallback = await usersCollection().findOne({ appleId })
  if (!fallback) {
    throw new Error('Failed to load user after upsert')
  }
  return fallback
}

export async function updateUserFamily (userId, familyId) {
  const update = {
    $set: {
      familyId: familyId ? new ObjectId(familyId) : null,
      updatedAt: new Date()
    }
  }
  await usersCollection().updateOne({ _id: new ObjectId(userId) }, update)
}

export async function listStudentsForFamily (familyId) {
  return usersCollection().find({ familyId: new ObjectId(familyId), role: 'student' }).toArray()
}

