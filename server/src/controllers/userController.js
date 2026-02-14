// Updated with assistance from Cursor (ChatGPT) on 11/7/25.

import bcrypt from 'bcryptjs'
import { ObjectId } from 'mongodb'
import { findUserById, updateUserFamily, listStudentsForFamily, updateUserProfile, createChildForFamily, findUserByInviteToken, clearInviteToken, linkAppleIdToUser, linkGoogleIdToUser, setUsernamePasswordForUser, deleteUserById } from '../models/userModel.js'
import { addMemberToFamily, createFamily, findFamilyByJoinCode, findFamilyById, removeMemberFromFamily } from '../models/familyModel.js'
import { deleteNotificationsByUserId } from '../models/notificationModel.js'
import { deleteAttendanceRecordsByStudentUserId } from '../models/attendanceModel.js'
import { deleteAssignmentsByStudentId } from '../models/assignmentModel.js'
import { removeStudentFromAllCourses } from '../models/courseModel.js'
import { findPortfoliosByStudentId, deletePortfoliosByStudentId } from '../models/portfolioModel.js'
import { deleteImagesByPortfolioId } from '../models/portfolioImageModel.js'
import { deleteStudentWorkFilesByStudentId } from '../models/studentWorkFileModel.js'
import { deletePlannerTasksByUserId } from '../models/plannerTaskModel.js'
import { serializeFamily, serializeUser, serializeUserWithInvite } from '../utils/serializers.js'
import { signToken } from '../utils/jwt.js'
import { verifyAppleIdentityToken } from '../services/appleAuth.js'
import { verifyGoogleIdToken } from '../services/googleAuth.js'
import { ValidationError, NotFoundError, ForbiddenError } from '../utils/errors.js'

export async function getCurrentUser (req, res, next) {
  try {
    let user = await findUserById(req.user.userId)
    if (!user) {
      throw new NotFoundError('User')
    }
    // Auto-create a family for parents who don't have one
    if (user.role === 'parent' && !user.familyId) {
      const familyName = user.name ? `${user.name}'s Family` : 'My Family'
      const family = await createFamily({ name: familyName })
      await updateUserFamily(req.user.userId, family._id)
      await addMemberToFamily({ familyId: family._id, userId: req.user.userId })
      user = await findUserById(req.user.userId)
    }
    res.json({ user: serializeUser(user) })
  } catch (error) {
    next(error)
  }
}

export async function updateProfile (req, res, next) {
  try {
  const { role, name } = req.body
  const userDoc = await updateUserProfile(req.user.userId, { role, name })
  if (!userDoc) {
    throw new NotFoundError('User')
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
  const baseUrl = process.env.INVITE_BASE_URL || 'https://hatched-46ar.onrender.com'
  res.json({
    family: serializeFamily(family),
    students: students.map((s) => serializeUserWithInvite(s, baseUrl))
  })
  } catch (error) {
    next(error)
  }
}

/** Link Apple ID to the current user (e.g. student after first login via invite). */
export async function linkApple (req, res, next) {
  try {
    const { identityToken } = req.body
    if (!identityToken) throw new ValidationError('identityToken is required')
    const audience = process.env.APPLE_CLIENT_ID
    if (!audience) throw new ValidationError('Apple Sign In is not configured')
    const payload = await verifyAppleIdentityToken(identityToken, audience)
    const appleId = payload.sub
    await linkAppleIdToUser(req.user.userId, appleId)
    const updated = await findUserById(req.user.userId)
    res.json({ user: serializeUser(updated) })
  } catch (error) {
    next(error)
  }
}

/** Link Google account to the current user. */
export async function linkGoogle (req, res, next) {
  try {
    const { idToken } = req.body
    if (!idToken) throw new ValidationError('idToken is required')
    const payload = await verifyGoogleIdToken(idToken)
    const googleId = payload.sub
    await linkGoogleIdToUser(req.user.userId, googleId)
    const updated = await findUserById(req.user.userId)
    res.json({ user: serializeUser(updated) })
  } catch (error) {
    next(error)
  }
}

/** Set username and/or password for the current user (e.g. student adding sign-in method). */
export async function setUsernamePassword (req, res, next) {
  try {
    const { username, password } = req.body
    const current = await findUserById(req.user.userId)
    if (!current) throw new NotFoundError('User')
    const hasUsername = current.username != null && String(current.username).trim() !== ''
    if (!hasUsername && (!username || String(username).trim() === '')) {
      throw new ValidationError('Username is required when you do not have one yet')
    }
    if (password != null && String(password).length > 0) {
      if (String(password).length < 6) throw new ValidationError('Password must be at least 6 characters')
    }
    const usernameTrimmed = username != null ? String(username).trim() : ''
    let passwordHash = null
    if (password != null && String(password).length >= 6) {
      passwordHash = await bcrypt.hash(String(password), 10)
    }
    const setUsername = !hasUsername && usernameTrimmed !== '' ? usernameTrimmed : undefined
    if (!setUsername && !passwordHash) throw new ValidationError('Provide username and/or password to set')
    await setUsernamePasswordForUser(req.user.userId, {
      username: setUsername,
      passwordHash: passwordHash || undefined
    })
    const updated = await findUserById(req.user.userId)
    res.json({ user: serializeUser(updated) })
  } catch (error) {
    next(error)
  }
}

/** Get invite link/token for a child (parent only, child must be in same family and have pending invite). */
export async function getChildInvite (req, res, next) {
  try {
    const parent = await findUserById(req.user.userId)
    if (!parent) throw new NotFoundError('User')
    if (parent.role !== 'parent') throw new ForbiddenError('Only parents can get a child invite')
    const familyId = parent.familyId?.toString()
    if (!familyId) throw new ValidationError('Create or join a family first')

    const childId = req.params.childId
    if (!childId) throw new ValidationError('Child ID is required')
    const child = await findUserById(childId)
    if (!child) throw new NotFoundError('Child')
    if (child.familyId?.toString() !== familyId) throw new ForbiddenError('Child is not in your family')
    if (!child.inviteToken) throw new NotFoundError('No pending invite for this child')

    const baseUrl = process.env.INVITE_BASE_URL || 'https://hatched-46ar.onrender.com'
    const invitePath = `/invite?token=${encodeURIComponent(child.inviteToken)}`
    const inviteLink = `${baseUrl}${invitePath}`

    res.json({ inviteLink, inviteToken: child.inviteToken })
  } catch (error) {
    next(error)
  }
}

/** Parent removes a child from the family and deletes the child account. */
export async function deleteChild (req, res, next) {
  try {
    const parent = await findUserById(req.user.userId)
    if (!parent) throw new NotFoundError('User')
    if (parent.role !== 'parent') throw new ForbiddenError('Only parents can remove children')
    const familyId = parent.familyId?.toString()
    if (!familyId) throw new ValidationError('No family')

    const childId = req.params.childId
    if (!childId) throw new ValidationError('Child ID is required')
    const child = await findUserById(childId)
    if (!child) throw new NotFoundError('Child')
    if (child.familyId?.toString() !== familyId) throw new ForbiddenError('Child is not in your family')
    if (child.role !== 'student') throw new ForbiddenError('Can only remove student accounts')

    // Cascade delete: remove all data for this child before removing the user
    await deleteNotificationsByUserId(childId)
    await deleteAttendanceRecordsByStudentUserId(childId)
    await deleteAssignmentsByStudentId(childId)
    await removeStudentFromAllCourses(childId)
    const portfolios = await findPortfoliosByStudentId(childId)
    for (const p of portfolios) {
      await deleteImagesByPortfolioId(p._id.toString())
    }
    await deletePortfoliosByStudentId(childId)
    await deleteStudentWorkFilesByStudentId(childId)
    await deletePlannerTasksByUserId(childId)

    await removeMemberFromFamily({ familyId, userId: childId })
    const deleted = await deleteUserById(childId)
    if (!deleted) throw new NotFoundError('Child')
    res.status(204).send()
  } catch (error) {
    next(error)
  }
}

/** Parent adds a child. Child user is created immediately; invite link lets child activate account. */
export async function createChild (req, res, next) {
  try {
    const parent = await findUserById(req.user.userId)
    if (!parent) throw new NotFoundError('User')
    if (parent.role !== 'parent') throw new ForbiddenError('Only parents can add children')
    const familyId = parent.familyId?.toString()
    if (!familyId) throw new ValidationError('Create or join a family first')

    const name = req.body.name?.trim()
    if (!name) throw new ValidationError('Child name is required')

    const { user: child, inviteToken } = await createChildForFamily(familyId, req.user.userId, {
      name,
      email: req.body.email?.trim() || null
    })
    await addMemberToFamily({ familyId, userId: child._id.toString() })

    const baseUrl = process.env.INVITE_BASE_URL || 'https://hatched-46ar.onrender.com'
    const invitePath = `/invite?token=${encodeURIComponent(inviteToken)}`
    const inviteLink = `${baseUrl}${invitePath}`

    res.status(201).json({
      child: serializeUser(child),
      inviteLink,
      inviteToken
    })
  } catch (error) {
    next(error)
  }
}

/** Accept an invite (no auth). Validates token, activates child account, returns JWT + user. */
export async function acceptInvite (req, res, next) {
  try {
    const token = req.body.token?.trim() || req.query.token?.trim()
    if (!token) throw new ValidationError('Invite token is required')

    const user = await findUserByInviteToken(token)
    if (!user) throw new NotFoundError('Invite link is invalid or expired')

    await clearInviteToken(user._id.toString())
    const activated = await findUserById(user._id.toString())
    const jwt = signToken({ userId: activated._id.toString() })

    res.json({
      token: jwt,
      user: serializeUser(activated)
    })
  } catch (error) {
    next(error)
  }
}

