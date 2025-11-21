// Updated with assistance from Cursor (ChatGPT) on 11/7/25.

import { ObjectId } from 'mongodb'
import { getCollection } from '../lib/mongo.js'

const FAMILIES_COLLECTION = 'families'

function familiesCollection () {
  return getCollection(FAMILIES_COLLECTION)
}

export async function createFamily ({ name }) {
  const family = {
    name,
    joinCode: generateJoinCode(),
    createdAt: new Date(),
    updatedAt: new Date()
  }

  const result = await familiesCollection().insertOne(family)
  return { ...family, _id: result.insertedId }
}

export async function findFamilyById (id) {
  return familiesCollection().findOne({ _id: new ObjectId(id) })
}

export async function findFamilyByJoinCode (joinCode) {
  return familiesCollection().findOne({ joinCode })
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

export async function listAllFamilies () {
  return familiesCollection().find({}).toArray()
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

