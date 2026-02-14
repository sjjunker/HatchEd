// Updated with assistance from Cursor (ChatGPT) on 11/7/25.

import crypto from 'crypto'
import { ObjectId } from 'mongodb'
import { getCollection, pingDatabase } from '../lib/mongo.js'
import { encrypt, decrypt, hashForLookup } from '../utils/piiCrypto.js'

const USERS_COLLECTION = 'users'

function usersCollection () {
  return getCollection(USERS_COLLECTION)
}

function decryptUser (doc) {
  if (!doc) return null
  const out = { ...doc }
  if (out.name != null) out.name = decrypt(out.name)
  if (out.email != null) out.email = decrypt(out.email)
  if (out.username != null) out.username = decrypt(out.username)
  return out
}

function encryptUserPII (data) {
  const out = { ...data }
  if (out.name != null && out.name !== '') out.name = encrypt(out.name)
  if (out.email != null && out.email !== '') out.email = encrypt(out.email)
  if (out.username != null && out.username !== '') {
    out.usernameHash = hashForLookup(out.username)
    out.username = encrypt(out.username)
  }
  return out
}

export async function findUserByAppleId (appleId) {
  const doc = await usersCollection().findOne({ appleId })
  return decryptUser(doc)
}

export async function findUserByGoogleId (googleId) {
  const doc = await usersCollection().findOne({ googleId })
  return decryptUser(doc)
}

export async function findUserByUsername (username) {
  const hash = hashForLookup(username)
  let doc = await usersCollection().findOne({ usernameHash: hash })
  if (!doc) {
    doc = await usersCollection().findOne({ username })
  }
  return decryptUser(doc)
}

export async function findUserById (id) {
  const doc = await usersCollection().findOne({ _id: new ObjectId(id) })
  return decryptUser(doc)
}

export async function deleteUserById (id) {
  const result = await usersCollection().deleteOne({ _id: new ObjectId(id) })
  return result.deletedCount === 1
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
  const encryptedData = encryptUserPII(filteredData)

    console.log('[Database] Filtered user data', {
      filteredKeys: Object.keys(filteredData),
      hasRole: 'role' in filteredData
    })

  const update = {
    $set: {
      ...encryptedData,
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
    return decryptUser(result.value)
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
        return decryptUser(fetchedUser)
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
    return decryptUser(fallback)
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
    const encryptedData = encryptUserPII(filteredData)

    console.log('[Database] Filtered user data', {
      filteredKeys: Object.keys(filteredData),
      hasRole: 'role' in filteredData
    })

    const update = {
      $set: {
        ...encryptedData,
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
      return decryptUser(result.value)
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
        return decryptUser(fetchedUser)
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
  return decryptUser(fallback)
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
  const docs = await usersCollection().find({ familyId: new ObjectId(familyId), role: 'student' }).toArray()
  return docs.map(decryptUser)
}

export async function listUsersForFamily (familyId) {
  const docs = await usersCollection().find({ familyId: new ObjectId(familyId) }).toArray()
  return docs.map(decryptUser)
}

export async function listParentsForFamily (familyId) {
  const docs = await usersCollection().find({ familyId: new ObjectId(familyId), role: 'parent' }).toArray()
  return docs.map(decryptUser)
}

export async function createUserWithPassword (userData) {
  const startTime = Date.now()
  console.log('[Database] Starting createUserWithPassword', {
    username: userData.username,
    hasEmail: !!userData.email,
    hasName: !!userData.name,
    timestamp: new Date().toISOString()
  })

  try {
    const isConnected = await pingDatabase()
    if (!isConnected) {
      throw new Error('Database connection not available')
    }
    console.log('[Database] Database connection verified via ping')

    // Check if username already exists
    const existingUser = await findUserByUsername(userData.username)
    if (existingUser) {
      throw new Error('Username already exists')
    }

    const filteredData = Object.fromEntries(
      Object.entries(userData).filter(([, value]) => value !== undefined && value !== null)
    )
    const encryptedData = encryptUserPII(filteredData)

    const newUser = {
      ...encryptedData,
      createdAt: new Date(),
      updatedAt: new Date()
    }

    console.log('[Database] Inserting new user...')
    const operationStartTime = Date.now()
    const result = await usersCollection().insertOne(newUser)
    const operationDuration = Date.now() - operationStartTime

    console.log('[Database] User inserted successfully', {
      userId: result.insertedId,
      duration: `${operationDuration}ms`
    })

    const createdUser = await usersCollection().findOne({ _id: result.insertedId })
    const totalDuration = Date.now() - startTime
    console.log('[Database] User created successfully', {
      userId: createdUser._id,
      role: createdUser.role || 'null/empty',
      duration: `${totalDuration}ms`
    })
    return decryptUser(createdUser)
  } catch (error) {
    const totalDuration = Date.now() - startTime
    console.error('[Database] Error in createUserWithPassword', {
      username: userData.username,
      error: error.message,
      errorName: error.name,
      duration: `${totalDuration}ms`,
      timestamp: new Date().toISOString()
    })
    throw error
  }
}

export async function updateUserTwoFactor (userId, twoFactorData) {
  const update = {
    $set: {
      ...twoFactorData,
      updatedAt: new Date()
    }
  }
  await usersCollection().updateOne({ _id: new ObjectId(userId) }, update)
  return await findUserById(userId)
}

export async function updateUserProfile (userId, { role, name }) {
  const update = { updatedAt: new Date() }
  if (role !== undefined) update.role = role
  if (name !== undefined && name !== '') {
    update.name = encrypt(name)
  }
  const result = await usersCollection().findOneAndUpdate(
    { _id: new ObjectId(userId) },
    { $set: update },
    { returnDocument: 'after' }
  )
  const doc = result?.value ?? await usersCollection().findOne({ _id: new ObjectId(userId) })
  return decryptUser(doc)
}

/** Create a child user for a family (invite flow). Child exists immediately; they use invite link to activate. */
export async function createChildForFamily (familyId, parentUserId, { name, email }) {
  const token = crypto.randomBytes(32).toString('base64url')
  const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000) // 7 days
  const encryptedData = encryptUserPII({
    name: name?.trim() || null,
    email: email?.trim() || null
  })
  const newUser = {
    ...encryptedData,
    role: 'student',
    familyId: new ObjectId(familyId),
    inviteToken: token,
    inviteTokenExpiresAt: expiresAt,
    createdAt: new Date(),
    updatedAt: new Date()
  }
  const result = await usersCollection().insertOne(newUser)
  const created = await usersCollection().findOne({ _id: result.insertedId })
  return { user: decryptUser(created), inviteToken: token }
}

/** Find user by valid invite token (for accepting invite). */
export async function findUserByInviteToken (token) {
  if (!token || !token.trim()) return null
  const doc = await usersCollection().findOne({
    inviteToken: token.trim(),
    inviteTokenExpiresAt: { $gt: new Date() }
  })
  return decryptUser(doc)
}

/** Link Apple ID to an existing user (e.g. child after first login). Fails if another user already has this appleId. */
export async function linkAppleIdToUser (userId, appleId) {
  const existing = await usersCollection().findOne({ appleId })
  if (existing && existing._id.toString() !== userId) {
    throw new Error('This Apple ID is already used by another account')
  }
  const update = { $set: { appleId, updatedAt: new Date() } }
  await usersCollection().updateOne({ _id: new ObjectId(userId) }, update)
  return findUserById(userId)
}

/** Link Google ID to an existing user. Fails if another user already has this googleId. */
export async function linkGoogleIdToUser (userId, googleId) {
  const existing = await usersCollection().findOne({ googleId })
  if (existing && existing._id.toString() !== userId) {
    throw new Error('This Google account is already used by another account')
  }
  const update = { $set: { googleId, updatedAt: new Date() } }
  await usersCollection().updateOne({ _id: new ObjectId(userId) }, update)
  return findUserById(userId)
}

/** Set username and/or password for an existing user (e.g. child adding sign-in method). Username must be unique. */
export async function setUsernamePasswordForUser (userId, { username, passwordHash }) {
  const update = { $set: { updatedAt: new Date() } }
  if (username != null && username.trim() !== '') {
    const existing = await findUserByUsername(username.trim())
    if (existing) {
      const existingId = existing._id?.toString?.() ?? existing._id
      if (existingId !== userId) throw new Error('Username already taken')
    }
    const encrypted = encryptUserPII({ username: username.trim() })
    update.$set.username = encrypted.username
    update.$set.usernameHash = encrypted.usernameHash
  }
  if (passwordHash) {
    update.$set.password = passwordHash
  }
  await usersCollection().updateOne({ _id: new ObjectId(userId) }, update)
  return findUserById(userId)
}

/** Clear invite token and expiry after child accepts (account activated). */
export async function clearInviteToken (userId) {
  await usersCollection().updateOne(
    { _id: new ObjectId(userId) },
    { $unset: { inviteToken: '', inviteTokenExpiresAt: '' }, $set: { updatedAt: new Date() } }
  )
  return findUserById(userId)
}
