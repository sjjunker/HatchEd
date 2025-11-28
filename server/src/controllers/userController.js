// Updated with assistance from Cursor (ChatGPT) on 11/7/25.

import { ObjectId } from 'mongodb'
import { findUserById, updateUserFamily, listStudentsForFamily } from '../models/userModel.js'
import { addMemberToFamily, createFamily, findFamilyByJoinCode, findFamilyById } from '../models/familyModel.js'
import { serializeFamily, serializeUser } from '../utils/serializers.js'
import { ValidationError, NotFoundError, ForbiddenError } from '../utils/errors.js'

export async function getCurrentUser (req, res, next) {
  try {
    const user = await findUserById(req.user.userId)
    if (!user) {
      throw new NotFoundError('User')
    }
    res.json({ user: serializeUser(user) })
  } catch (error) {
    next(error)
  }
}

export async function updateProfile (req, res, next) {
  try {
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
        throw new NotFoundError('User')
      }
    }

    res.json({ user: serializeUser(userDoc) })
  } catch (error) {
    next(error)
  }
}

export async function createFamilyForUser (req, res, next) {
  try {
    const { name } = req.body
    if (!name || !name.trim()) {
      throw new ValidationError('Family name is required')
    }

    const family = await createFamily({ name: name.trim() })
    await updateUserFamily(req.user.userId, family._id)
    await addMemberToFamily({ familyId: family._id, userId: req.user.userId })

    res.status(201).json({ family: serializeFamily(family) })
  } catch (error) {
    next(error)
  }
}

export async function joinFamilyWithCode (req, res, next) {
  try {
    const { joinCode } = req.body
    if (!joinCode || !joinCode.trim()) {
      throw new ValidationError('Join code is required')
    }

    const family = await findFamilyByJoinCode(joinCode.trim().toUpperCase())
    if (!family) {
      throw new NotFoundError('Family')
    }

    await updateUserFamily(req.user.userId, family._id)
    await addMemberToFamily({ familyId: family._id, userId: req.user.userId })

    res.json({ family: serializeFamily(family) })
  } catch (error) {
    next(error)
  }
}

export async function getFamily (req, res, next) {
  try {
    const { familyId } = req.params
    const family = await findFamilyById(familyId)
    if (!family) {
      throw new NotFoundError('Family')
    }

    // Verify user has access to this family
    const user = await findUserById(req.user.userId)
    if (!user || user.familyId?.toString() !== family._id.toString()) {
      throw new ForbiddenError('You do not have access to this family')
    }

    const students = await listStudentsForFamily(family._id)
    res.json({
      family: serializeFamily(family),
      students: students.map(serializeUser)
    })
  } catch (error) {
    next(error)
  }
}

