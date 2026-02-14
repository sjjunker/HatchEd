// Updated with assistance from Cursor (ChatGPT) on 11/7/25.

import { ObjectId } from 'mongodb'
import { getCollection } from '../lib/mongo.js'
import { encrypt, decrypt } from '../utils/piiCrypto.js'

const FAMILIES_COLLECTION = 'families'

function familiesCollection () {
  return getCollection(FAMILIES_COLLECTION)
}

function decryptFamily (doc) {
  if (!doc) return null
  const out = { ...doc }
  if (out.name != null) out.name = decrypt(out.name)
  return out
}

export async function createFamily ({ name }) {
  const family = {
    name: name ? encrypt(name) : name,
    joinCode: generateJoinCode(),
    createdAt: new Date(),
    updatedAt: new Date()
  }

  const result = await familiesCollection().insertOne(family)
  return decryptFamily({ ...family, _id: result.insertedId })
}

export async function findFamilyById (id) {
  const doc = await familiesCollection().findOne({ _id: new ObjectId(id) })
  return decryptFamily(doc)
}

export async function findFamilyByJoinCode (joinCode) {
  const doc = await familiesCollection().findOne({ joinCode })
  return decryptFamily(doc)
}

export async function addMemberToFamily ({ familyId, userId }) {
  await familiesCollection().updateOne(
    { _id: new ObjectId(familyId) },
    {
      $addToSet: { members: new ObjectId(userId) },
      $set: { updatedAt: new Date() }
    }
  )
}

export async function removeMemberFromFamily ({ familyId, userId }) {
  await familiesCollection().updateOne(
    { _id: new ObjectId(familyId) },
    {
      $pull: { members: new ObjectId(userId) },
      $set: { updatedAt: new Date() }
    }
  )
}

export async function listAllFamilies () {
  const docs = await familiesCollection().find({}).toArray()
  return docs.map(decryptFamily)
}

function generateJoinCode (length = 6) {
  const characters = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
  let code = ''
  for (let i = 0; i < length; i++) {
    const index = Math.floor(Math.random() * characters.length)
    code += characters[index]
  }
  return code
}

