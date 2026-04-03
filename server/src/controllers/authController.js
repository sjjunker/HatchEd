// Updated with assistance from Cursor (ChatGPT) on 11/7/25.

import bcrypt from 'bcryptjs'
import { verifyAppleIdentityToken } from '../services/appleAuth.js'
import { verifyGoogleIdToken } from '../services/googleAuth.js'
import {
  upsertUserByAppleId,
  findUserByAppleId,
  upsertUserByGoogleId,
  findUserByGoogleId,
  findUserByUsername,
  createUserWithPassword,
  findUserByInviteToken,
  linkAppleIdToUser,
  linkGoogleIdToUser,
  clearInviteToken,
  findUserById,
  updateUserProfile,
  setUsernamePasswordForUser
} from '../models/userModel.js'
import { verifyTwoFactorCode } from './twoFactorController.js'
import { signToken } from '../utils/jwt.js'
import { serializeUser } from '../utils/serializers.js'
import { ObjectId } from 'mongodb'
import { ValidationError, AppError, ConflictError } from '../utils/errors.js'

export async function appleSignIn (req, res, next) {
  const startTime = Date.now()
  try {
    const { identityToken, fullName, email, intent: intentRaw, inviteToken: inviteTokenRaw, role: roleRaw } = req.body
    const intent = intentRaw === 'signUp' ? 'signUp' : 'signIn'
    const inviteToken = typeof inviteTokenRaw === 'string' ? inviteTokenRaw.trim() : ''
    const signupRole = roleRaw === 'parent' ? 'parent' : undefined

    console.log('[Sign In] Apple request', {
      timestamp: new Date().toISOString(),
      ip: req.ip,
      hasIdentityToken: !!identityToken,
      intent,
      hasInviteToken: !!inviteToken
    })

    if (!identityToken) {
      throw new ValidationError('identityToken is required')
    }

    const audience = process.env.APPLE_CLIENT_ID
    if (!audience) {
      throw new AppError('Apple Client ID not configured', 500, 'CONFIGURATION_ERROR')
    }

    const payload = await verifyAppleIdentityToken(identityToken, audience)
    const appleId = payload.sub

    // Student signup: link Apple ID to the invited child account
    if (inviteToken) {
      const inviteUser = await findUserByInviteToken(inviteToken)
      if (!inviteUser) {
        throw new AppError('Invite link is invalid or expired', 404, 'NOT_FOUND')
      }
      if (inviteUser.role !== 'student') throw new ValidationError('Invalid invite')

      const existingApple = await findUserByAppleId(appleId)
      if (existingApple && existingApple._id.toString() !== inviteUser._id.toString()) {
        throw new ConflictError('This Apple ID is already used by another account')
      }

      try {
        await linkAppleIdToUser(inviteUser._id.toString(), appleId)
      } catch (err) {
        if (err.message?.includes('already')) throw new ConflictError(err.message)
        throw err
      }

      const resolvedEmail = email ?? payload.email
      const resolvedName = fullName ?? payload.name
      await updateUserProfile(inviteUser._id.toString(), {
        name: resolvedName || undefined,
        email: resolvedEmail || undefined
      })

      await clearInviteToken(inviteUser._id.toString())
      let user = await findUserById(inviteUser._id.toString())
      const userId = user._id instanceof ObjectId ? user._id.toString() : user._id
      const token = signToken({ userId, appleId: user.appleId, role: user.role })
      const duration = Date.now() - startTime
      console.log('[Sign In] Apple invite signup completed', { userId, duration })
      return res.json({ token, user: serializeUser({ ...user, _id: userId }) })
    }

    const existingUser = await findUserByAppleId(appleId)

    // Sign-in only: existing account required
    if (intent === 'signIn') {
      if (!existingUser) {
        throw new AppError('No account found for this Apple ID. Use Sign Up to create one.', 404, 'ACCOUNT_NOT_FOUND')
      }
      const updateData = {}
      const resolvedEmail = email ?? payload.email
      if (resolvedEmail) updateData.email = resolvedEmail
      const resolvedName = fullName ?? payload.name
      if (resolvedName) updateData.name = resolvedName
      if (payload.role) updateData.role = payload.role
      else if (existingUser.role) updateData.role = existingUser.role

      const user = await upsertUserByAppleId(appleId, updateData)
      let finalUser = user
      if (!finalUser.role && existingUser?.role) {
        const refetched = await findUserByAppleId(appleId)
        if (refetched?.role) finalUser = refetched
      }
      const userId = finalUser._id instanceof ObjectId ? finalUser._id.toString() : finalUser._id
      const token = signToken({ userId, appleId: finalUser.appleId, role: finalUser.role })
      const duration = Date.now() - startTime
      console.log('[Sign In] Apple sign-in completed', { userId, duration })
      return res.json({ token, user: serializeUser({ ...finalUser, _id: userId }) })
    }

    // Sign-up (new parent account)
    const updateData = {}
    const resolvedEmail = email ?? payload.email
    if (resolvedEmail) updateData.email = resolvedEmail
    const resolvedName = fullName ?? payload.name
    if (resolvedName) updateData.name = resolvedName
    if (payload.role) updateData.role = payload.role
    else if (existingUser?.role) updateData.role = existingUser.role
    else if (signupRole === 'parent') updateData.role = 'parent'

    const user = await upsertUserByAppleId(appleId, updateData)
    let finalUser = user
    if (!finalUser.role && existingUser?.role) {
      const refetched = await findUserByAppleId(appleId)
      if (refetched?.role) finalUser = refetched
    }
    const userId = finalUser._id instanceof ObjectId ? finalUser._id.toString() : finalUser._id
    const token = signToken({ userId, appleId: finalUser.appleId, role: finalUser.role })
    const duration = Date.now() - startTime
    console.log('[Sign In] Apple sign-up completed', { userId, duration })
    res.json({ token, user: serializeUser({ ...finalUser, _id: userId }) })
  } catch (error) {
    const duration = Date.now() - startTime
    console.error('[Sign In] Apple failed', { error: error.message, duration })
    next(error)
  }
}

export async function googleSignIn (req, res, next) {
  const startTime = Date.now()
  try {
    const { idToken, fullName, email, intent: intentRaw, inviteToken: inviteTokenRaw, role: roleRaw } = req.body
    const intent = intentRaw === 'signUp' ? 'signUp' : 'signIn'
    const inviteToken = typeof inviteTokenRaw === 'string' ? inviteTokenRaw.trim() : ''
    const signupRole = roleRaw === 'parent' ? 'parent' : undefined

    console.log('[Sign In] Google request', {
      timestamp: new Date().toISOString(),
      ip: req.ip,
      hasIdToken: !!idToken,
      intent,
      hasInviteToken: !!inviteToken
    })

    if (!idToken) {
      throw new ValidationError('idToken is required')
    }

    if (!process.env.GOOGLE_CLIENT_ID) {
      throw new AppError('Google Client ID not configured', 500, 'CONFIGURATION_ERROR')
    }

    const payload = await verifyGoogleIdToken(idToken)
    const googleId = payload.sub

    if (inviteToken) {
      const inviteUser = await findUserByInviteToken(inviteToken)
      if (!inviteUser) {
        throw new AppError('Invite link is invalid or expired', 404, 'NOT_FOUND')
      }
      if (inviteUser.role !== 'student') throw new ValidationError('Invalid invite')

      const existingGoogle = await findUserByGoogleId(googleId)
      if (existingGoogle && existingGoogle._id.toString() !== inviteUser._id.toString()) {
        throw new ConflictError('This Google account is already used by another account')
      }

      try {
        await linkGoogleIdToUser(inviteUser._id.toString(), googleId)
      } catch (err) {
        if (err.message?.includes('already')) throw new ConflictError(err.message)
        throw err
      }

      const resolvedEmail = email ?? payload.email
      const resolvedName = fullName ?? payload.name
      await updateUserProfile(inviteUser._id.toString(), {
        name: resolvedName || undefined,
        email: resolvedEmail || undefined
      })

      await clearInviteToken(inviteUser._id.toString())
      let user = await findUserById(inviteUser._id.toString())
      const userId = user._id instanceof ObjectId ? user._id.toString() : user._id
      const token = signToken({ userId, googleId: user.googleId, role: user.role })
      const duration = Date.now() - startTime
      console.log('[Sign In] Google invite signup completed', { userId, duration })
      return res.json({ token, user: serializeUser({ ...user, _id: userId }) })
    }

    const existingUser = await findUserByGoogleId(googleId)

    if (intent === 'signIn') {
      if (!existingUser) {
        throw new AppError('No account found for this Google account. Use Sign Up to create one.', 404, 'ACCOUNT_NOT_FOUND')
      }
      const updateData = {}
      const resolvedEmail = email ?? payload.email
      if (resolvedEmail) updateData.email = resolvedEmail
      const resolvedName = fullName ?? payload.name
      if (resolvedName) updateData.name = resolvedName
      if (payload.role) updateData.role = payload.role
      else if (existingUser.role) updateData.role = existingUser.role

      const user = await upsertUserByGoogleId(googleId, updateData)
      let finalUser = user
      if (!finalUser.role && existingUser?.role) {
        const refetched = await findUserByGoogleId(googleId)
        if (refetched?.role) finalUser = refetched
      }
      const userId = finalUser._id instanceof ObjectId ? finalUser._id.toString() : finalUser._id
      const token = signToken({ userId, googleId: finalUser.googleId, role: finalUser.role })
      const duration = Date.now() - startTime
      console.log('[Sign In] Google sign-in completed', { userId, duration })
      return res.json({ token, user: serializeUser({ ...finalUser, _id: userId }) })
    }

    const updateData = {}
    const resolvedEmail = email ?? payload.email
    if (resolvedEmail) updateData.email = resolvedEmail
    const resolvedName = fullName ?? payload.name
    if (resolvedName) updateData.name = resolvedName
    if (payload.role) updateData.role = payload.role
    else if (existingUser?.role) updateData.role = existingUser.role
    else if (signupRole === 'parent') updateData.role = 'parent'

    const user = await upsertUserByGoogleId(googleId, updateData)
    let finalUser = user
    if (!finalUser.role && existingUser?.role) {
      const refetched = await findUserByGoogleId(googleId)
      if (refetched?.role) finalUser = refetched
    }
    const userId = finalUser._id instanceof ObjectId ? finalUser._id.toString() : finalUser._id
    const token = signToken({ userId, googleId: finalUser.googleId, role: finalUser.role })
    const duration = Date.now() - startTime
    console.log('[Sign In] Google sign-up completed', { userId, duration })
    res.json({ token, user: serializeUser({ ...finalUser, _id: userId }) })
  } catch (error) {
    const duration = Date.now() - startTime
    console.error('[Sign In] Google failed', { error: error.message, duration })
    next(error)
  }
}

export async function signUp (req, res, next) {
  const startTime = Date.now()
  try {
    console.log('[Sign Up] Username/password sign-up request received', {
      timestamp: new Date().toISOString(),
      ip: req.ip,
      hasUsername: !!req.body.username,
      hasPassword: !!req.body.password,
      hasInviteToken: !!req.body.inviteToken
    })

    const { username, password, email, name, inviteToken: inviteTokenRaw, role: roleRaw } = req.body
    const inviteToken = typeof inviteTokenRaw === 'string' ? inviteTokenRaw.trim() : ''
    const signupRole = roleRaw === 'parent' ? 'parent' : undefined

    if (!username || !password) {
      console.log('[Sign Up] Validation failed: username or password missing')
      throw new ValidationError('Username and password are required')
    }

    if (username.length < 3) {
      throw new ValidationError('Username must be at least 3 characters')
    }

    if (password.length < 6) {
      throw new ValidationError('Password must be at least 6 characters')
    }

    const saltRounds = 10
    const hashedPassword = await bcrypt.hash(password, saltRounds)

    // Student: attach username/password to invited child account
    if (inviteToken) {
      const inviteUser = await findUserByInviteToken(inviteToken)
      if (!inviteUser) {
        throw new AppError('Invite link is invalid or expired', 404, 'NOT_FOUND')
      }
      if (inviteUser.role !== 'student') throw new ValidationError('Invalid invite')
      const existingWithUsername = await findUserByUsername(username)
      if (existingWithUsername) {
        throw new ValidationError('Username already exists')
      }
      try {
        await setUsernamePasswordForUser(inviteUser._id.toString(), {
          username: username.trim(),
          passwordHash: hashedPassword
        })
      } catch (err) {
        if (err.message?.includes('taken')) throw new ValidationError(err.message)
        throw err
      }
      await clearInviteToken(inviteUser._id.toString())
      const user = await findUserById(inviteUser._id.toString())
      const userId = user._id instanceof ObjectId ? user._id.toString() : user._id
      const token = signToken({
        userId,
        username: user.username,
        role: user.role
      })
      const serializedUser = serializeUser({ ...user, _id: userId })
      delete serializedUser.password
      console.log('[Sign Up] Invite username signup completed', { userId })
      return res.json({ token, user: serializedUser })
    }

    const existingUser = await findUserByUsername(username)
    if (existingUser) {
      throw new ValidationError('Username already exists')
    }

    console.log('[Sign Up] Creating user...')
    const userData = {
      username,
      password: hashedPassword,
      email: email || undefined,
      name: name || undefined
    }
    if (signupRole === 'parent') {
      userData.role = 'parent'
    }

    const user = await createUserWithPassword(userData)

    const userId = user._id instanceof ObjectId ? user._id.toString() : user._id

    console.log('[Sign Up] User created', {
      userId,
      username: user.username,
      role: user.role
    })

    // Generate JWT token
    console.log('[Sign Up] Generating JWT token...')
    const token = signToken({
      userId,
      username: user.username,
      role: user.role
    })

    const duration = Date.now() - startTime
    const serializedUser = serializeUser({ ...user, _id: userId })
    // Don't send password hash in response
    delete serializedUser.password

    console.log('[Sign Up] Sign-up completed successfully', {
      userId,
      role: user.role,
      duration: `${duration}ms`,
      timestamp: new Date().toISOString()
    })

    res.json({
      token,
      user: serializedUser
    })
  } catch (error) {
    const duration = Date.now() - startTime
    console.error('[Sign Up] Sign-up failed', {
      error: error.message,
      code: error.code,
      status: error.status || error.statusCode,
      duration: `${duration}ms`,
      timestamp: new Date().toISOString()
    })
    next(error)
  }
}

export async function usernamePasswordSignIn (req, res, next) {
  const startTime = Date.now()
  try {
    console.log('[Sign In] Username/password sign-in request received', {
      timestamp: new Date().toISOString(),
      ip: req.ip,
      hasUsername: !!req.body.username,
      hasPassword: !!req.body.password
    })

    const { username, password } = req.body

    if (!username || !password) {
      console.log('[Sign In] Validation failed: username or password missing')
      throw new ValidationError('Username and password are required')
    }

    // Find user by username
    const user = await findUserByUsername(username)
    if (!user) {
      throw new ValidationError('Invalid username or password')
    }

    // Check if user has a password (might be OAuth-only user)
    if (!user.password) {
      throw new ValidationError('This account uses a different sign-in method')
    }

    // Verify password
    const isPasswordValid = await bcrypt.compare(password, user.password)
    if (!isPasswordValid) {
      throw new ValidationError('Invalid username or password')
    }

    const userId = user._id instanceof ObjectId ? user._id.toString() : user._id

    console.log('[Sign In] User authenticated', {
      userId,
      username: user.username,
      role: user.role,
      has2FA: !!user.twoFactorEnabled
    })

    // Check if 2FA is enabled
    if (user.twoFactorEnabled) {
      const { twoFactorCode } = req.body
      
      if (!twoFactorCode) {
        return res.status(200).json({
          requiresTwoFactor: true,
          userId: userId,
          message: 'Enter the code from your authenticator app'
        })
      }
      
      // Verify 2FA code
      const isCodeValid = await verifyTwoFactorCode(userId, twoFactorCode)
      if (!isCodeValid) {
        throw new ValidationError('Invalid two-factor authentication code')
      }
    }

    // Generate JWT token
    console.log('[Sign In] Generating JWT token...')
    const token = signToken({
      userId,
      username: user.username,
      role: user.role
    })

    const duration = Date.now() - startTime
    const serializedUser = serializeUser({ ...user, _id: userId })
    // Don't send password hash in response
    delete serializedUser.password

    console.log('[Sign In] Sign-in completed successfully', {
      userId,
      role: user.role,
      duration: `${duration}ms`,
      timestamp: new Date().toISOString()
    })

    res.json({
      token,
      user: serializedUser
    })
  } catch (error) {
    const duration = Date.now() - startTime
    console.error('[Sign In] Sign-in failed', {
      error: error.message,
      code: error.code,
      status: error.status || error.statusCode,
      duration: `${duration}ms`,
      timestamp: new Date().toISOString()
    })
    next(error)
  }
}

