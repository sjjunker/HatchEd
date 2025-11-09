import { ObjectId } from 'mongodb'
import { findUserById, updateUserFamily, listStudentsForFamily } from '../models/userModel.js'
import { addMemberToFamily, createFamily, findFamilyByJoinCode, findFamilyById } from '../models/familyModel.js'
import { serializeFamily, serializeUser } from '../utils/serializers.js'

export async function getCurrentUser (req, res) {
  const user = await findUserById(req.user.userId)
  res.json({ user: serializeUser(user) })
}

export async function updateProfile (req, res) {
  const { role, name } = req.body
  const update = {}
  if (role) update.role = role
  if (name) update.name = name

  const users = req.app.locals.db.collection('users')
  const result = await users.findOneAndUpdate(
    { _id: new ObjectId(req.user.userId) },
    {
      $set: {
        ...update,
        updatedAt: new Date()
      }
    },
    { returnDocument: 'after' }
  )

  let userDoc = result.value
  if (!userDoc) {
    userDoc = await users.findOne({ _id: new ObjectId(req.user.userId) })
    if (!userDoc) {
      return res.status(404).json({ error: { message: 'User not found' } })
    }
  }

  res.json({ user: serializeUser(userDoc) })
}

export async function createFamilyForUser (req, res) {
  const { name } = req.body
  if (!name) {
    return res.status(400).json({ error: { message: 'Family name is required' } })
  }

  const family = await createFamily({ name })
  await updateUserFamily(req.user.userId, family._id)
  await addMemberToFamily({ familyId: family._id, userId: req.user.userId })

  res.status(201).json({ family: serializeFamily(family) })
}

export async function joinFamilyWithCode (req, res) {
  const { joinCode } = req.body
  if (!joinCode) {
    return res.status(400).json({ error: { message: 'Join code is required' } })
  }

  const family = await findFamilyByJoinCode(joinCode.trim().toUpperCase())
  if (!family) {
    return res.status(404).json({ error: { message: 'Family not found' } })
  }

  await updateUserFamily(req.user.userId, family._id)
  await addMemberToFamily({ familyId: family._id, userId: req.user.userId })

  res.json({ family: serializeFamily(family) })
}

export async function getFamily (req, res) {
  const { familyId } = req.params
  const family = await findFamilyById(familyId)
  if (!family) {
    return res.status(404).json({ error: { message: 'Family not found' } })
  }

  const students = await listStudentsForFamily(family._id)
  res.json({
    family: serializeFamily(family),
    students: students.map(serializeUser)
  })
}

