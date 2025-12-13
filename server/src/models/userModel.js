// Updated with assistance from Cursor (ChatGPT) on 11/7/25.

import { ObjectId } from 'mongodb'
import { getCollection, pingDatabase } from '../lib/mongo.js'

const USERS_COLLECTION = 'users'

function usersCollection () {
  return getCollection(USERS_COLLECTION)
}

export async function findUserByAppleId (appleId) {
  return usersCollection().findOne({ appleId })
}

export async function findUserByGoogleId (googleId) {
  return usersCollection().findOne({ googleId })
}

export async function findUserById (id) {
  return usersCollection().findOne({ _id: new ObjectId(id) })
}

export async function upsertUserByAppleId (appleId, userData) {
  const startTime = Date.now()
  console.log('[Database] Starting upsertUserByAppleId', {
    appleId,
    hasUserData: !!userData,
    userDataKeys: Object.keys(userData || {}),
    timestamp: new Date().toISOString()
  })

  try {
    // Verify database connection before operation
    const isConnected = await pingDatabase()
    if (!isConnected) {
      throw new Error('Database connection not available')
    }
    console.log('[Database] Database connection verified via ping')
    const filteredData = Object.fromEntries(
      Object.entries(userData).filter(([, value]) => value !== undefined)
    )

    console.log('[Database] Filtered user data', {
      filteredKeys: Object.keys(filteredData),
      hasRole: 'role' in filteredData
    })

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

    console.log('[Database] Executing findOneAndUpdate...')
    const options = { upsert: true, returnDocument: 'after' }
    const operationStartTime = Date.now()
    const result = await usersCollection().findOneAndUpdate({ appleId }, update, options)
    const operationDuration = Date.now() - operationStartTime

    console.log('[Database] findOneAndUpdate completed', {
      duration: `${operationDuration}ms`,
      hasResult: !!result,
      hasValue: !!result?.value,
      hasUpsertedId: !!result?.lastErrorObject?.upserted
    })

    if (result.value) {
      const totalDuration = Date.now() - startTime
      console.log('[Database] User upserted successfully (from result.value)', {
        userId: result.value._id,
        role: result.value.role || 'null/empty',
        duration: `${totalDuration}ms`
      })
      return result.value
    }

    const upsertedId = result.lastErrorObject?.upserted
    if (upsertedId) {
      console.log('[Database] Fetching upserted user by ID...', { upsertedId })
      const fetchedUser = await usersCollection().findOne({ _id: upsertedId })
      if (fetchedUser) {
        const totalDuration = Date.now() - startTime
        console.log('[Database] User upserted successfully (from upsertedId)', {
          userId: fetchedUser._id,
          role: fetchedUser.role || 'null/empty',
          duration: `${totalDuration}ms`
        })
        return fetchedUser
      }
    }

    console.log('[Database] Fallback: fetching user by appleId...')
    const fallback = await usersCollection().findOne({ appleId })
    if (!fallback) {
      const totalDuration = Date.now() - startTime
      console.error('[Database] Failed to load user after upsert', {
        appleId,
        duration: `${totalDuration}ms`
      })
      throw new Error('Failed to load user after upsert')
    }
    
    const totalDuration = Date.now() - startTime
    console.log('[Database] User retrieved via fallback', {
      userId: fallback._id,
      role: fallback.role || 'null/empty',
      duration: `${totalDuration}ms`
    })
    return fallback
  } catch (error) {
    const totalDuration = Date.now() - startTime
    console.error('[Database] Error in upsertUserByAppleId', {
      appleId,
      error: error.message,
      errorName: error.name,
      duration: `${totalDuration}ms`,
      timestamp: new Date().toISOString()
    })
    throw error
  }
}

export async function upsertUserByGoogleId (googleId, userData) {
  const startTime = Date.now()
  console.log('[Database] Starting upsertUserByGoogleId', {
    googleId,
    hasUserData: !!userData,
    userDataKeys: Object.keys(userData || {}),
    timestamp: new Date().toISOString()
  })

  try {
    // Verify database connection before operation
    const isConnected = await pingDatabase()
    if (!isConnected) {
      throw new Error('Database connection not available')
    }
    console.log('[Database] Database connection verified via ping')
    const filteredData = Object.fromEntries(
      Object.entries(userData).filter(([, value]) => value !== undefined)
    )

    console.log('[Database] Filtered user data', {
      filteredKeys: Object.keys(filteredData),
      hasRole: 'role' in filteredData
    })

    const update = {
      $set: {
        ...filteredData,
        updatedAt: new Date()
      },
      $setOnInsert: {
        googleId,
        createdAt: new Date()
      }
    }

    console.log('[Database] Executing findOneAndUpdate...')
    const options = { upsert: true, returnDocument: 'after' }
    const operationStartTime = Date.now()
    const result = await usersCollection().findOneAndUpdate({ googleId }, update, options)
    const operationDuration = Date.now() - operationStartTime

    console.log('[Database] findOneAndUpdate completed', {
      duration: `${operationDuration}ms`,
      hasResult: !!result,
      hasValue: !!result?.value,
      hasUpsertedId: !!result?.lastErrorObject?.upserted
    })

    if (result.value) {
      const totalDuration = Date.now() - startTime
      console.log('[Database] User upserted successfully (from result.value)', {
        userId: result.value._id,
        role: result.value.role || 'null/empty',
        duration: `${totalDuration}ms`
      })
      return result.value
    }

    const upsertedId = result.lastErrorObject?.upserted
    if (upsertedId) {
      console.log('[Database] Fetching upserted user by ID...', { upsertedId })
      const fetchedUser = await usersCollection().findOne({ _id: upsertedId })
      if (fetchedUser) {
        const totalDuration = Date.now() - startTime
        console.log('[Database] User upserted successfully (from upsertedId)', {
          userId: fetchedUser._id,
          role: fetchedUser.role || 'null/empty',
          duration: `${totalDuration}ms`
        })
        return fetchedUser
      }
    }

    console.log('[Database] Fallback: fetching user by googleId...')
    const fallback = await usersCollection().findOne({ googleId })
    if (!fallback) {
      const totalDuration = Date.now() - startTime
      console.error('[Database] Failed to load user after upsert', {
        googleId,
        duration: `${totalDuration}ms`
      })
      throw new Error('Failed to load user after upsert')
    }
    
    const totalDuration = Date.now() - startTime
    console.log('[Database] User retrieved via fallback', {
      userId: fallback._id,
      role: fallback.role || 'null/empty',
      duration: `${totalDuration}ms`
    })
    return fallback
  } catch (error) {
    const totalDuration = Date.now() - startTime
    console.error('[Database] Error in upsertUserByGoogleId', {
      googleId,
      error: error.message,
      errorName: error.name,
      duration: `${totalDuration}ms`,
      timestamp: new Date().toISOString()
    })
    throw error
  }
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

export async function listUsersForFamily (familyId) {
  return usersCollection().find({ familyId: new ObjectId(familyId) }).toArray()
}

export async function listParentsForFamily (familyId) {
  return usersCollection().find({ familyId: new ObjectId(familyId), role: 'parent' }).toArray()
}

