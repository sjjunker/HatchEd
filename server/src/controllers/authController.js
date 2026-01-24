// Updated with assistance from Cursor (ChatGPT) on 11/7/25.

import bcrypt from 'bcryptjs'
import { verifyAppleIdentityToken } from '../services/appleAuth.js'
import { verifyGoogleIdToken } from '../services/googleAuth.js'
import { upsertUserByAppleId, findUserByAppleId, upsertUserByGoogleId, findUserByGoogleId, findUserByUsername, createUserWithPassword } from '../models/userModel.js'
import { verifyTwoFactorCode } from './twoFactorController.js'
import { signToken } from '../utils/jwt.js'
import { serializeUser } from '../utils/serializers.js'
import { ObjectId } from 'mongodb'
import { ValidationError, AppError } from '../utils/errors.js'

export async function appleSignIn (req, res, next) {
  const startTime = Date.now()
  try {
    console.log('[Sign In] Apple sign-in request received', {
      timestamp: new Date().toISOString(),
      ip: req.ip,
      hasIdentityToken: !!req.body.identityToken,
      hasFullName: !!req.body.fullName,
      hasEmail: !!req.body.email
    })

  const { identityToken, fullName, email } = req.body
  if (!identityToken) {
      console.log('[Sign In] Validation failed: identityToken is missing')
      throw new ValidationError('identityToken is required')
  }

  const audience = process.env.APPLE_CLIENT_ID
    if (!audience) {
      console.error('[Sign In] Configuration error: APPLE_CLIENT_ID not set')
      throw new AppError('Apple Client ID not configured', 500, 'CONFIGURATION_ERROR')
    }

    console.log('[Sign In] Verifying Apple identity token...', {
      audience,
      tokenLength: identityToken.length
    })

  const payload = await verifyAppleIdentityToken(identityToken, audience)

    console.log('[Sign In] Apple token verified successfully', {
      appleId: payload.sub,
      hasEmail: !!payload.email,
      hasName: !!payload.name,
      hasRole: !!payload.role
    })

  const appleId = payload.sub
  
  // Check if user already exists to preserve their role
  const existingUser = await findUserByAppleId(appleId)
  console.log('[Sign In] Existing user check', {
    appleId,
    exists: !!existingUser,
    existingRole: existingUser?.role || 'none',
    existingName: existingUser?.name || 'none'
  })
  
  const updateData = {}
  const resolvedEmail = email ?? payload.email
  if (resolvedEmail) updateData.email = resolvedEmail
  const resolvedName = fullName ?? payload.name
  if (resolvedName) updateData.name = resolvedName
  
  // Only set role from payload if it exists (it won't from Apple, but preserve existing role)
  if (payload.role) {
    updateData.role = payload.role
    console.log('[Sign In] Role provided in payload:', payload.role)
  } else if (existingUser?.role) {
    // Preserve existing role - explicitly include it so it's not lost
    updateData.role = existingUser.role
    console.log('[Sign In] Preserving existing role:', existingUser.role)
  } else {
    console.log('[Sign In] No role found - user will need to select one')
  }

    console.log('[Sign In] Upserting user in database...', {
      appleId,
      updateData: {
        hasEmail: !!updateData.email,
        hasName: !!updateData.name,
        hasRole: !!updateData.role,
        role: updateData.role || 'null'
      }
    })

  const user = await upsertUserByAppleId(appleId, updateData)
  
  // Double-check: if user still doesn't have role but existing user did, fetch again
  if (!user.role && existingUser?.role) {
    console.log('[Sign In] Role missing after upsert, fetching user again...')
    const refetchedUser = await findUserByAppleId(appleId)
    if (refetchedUser?.role) {
      user.role = refetchedUser.role
      console.log('[Sign In] Role restored from refetch:', refetchedUser.role)
    }
  }

  const userId = user._id instanceof ObjectId ? user._id.toString() : user._id

    console.log('[Sign In] User found/created', {
      userId,
      appleId: user.appleId,
      role: user.role,
      name: user.name,
      isNewUser: !user.createdAt || (Date.now() - new Date(user.createdAt).getTime()) < 5000
    })

    console.log('[Sign In] Generating JWT token...')
  const token = signToken({
    userId,
    appleId: user.appleId,
    role: user.role
  })

    const duration = Date.now() - startTime
    const serializedUser = serializeUser({ ...user, _id: userId })
    console.log('[Sign In] Sign-in completed successfully', {
      userId,
      role: user.role,
      duration: `${duration}ms`,
      timestamp: new Date().toISOString(),
      userData: {
        id: serializedUser?.id,
        role: serializedUser?.role,
        name: serializedUser?.name,
        hasFamilyId: !!serializedUser?.familyId
      }
    })

    const response = {
    token,
      user: serializedUser
    }
    console.log('[Sign In] Sending response to client', {
      hasToken: !!response.token,
      hasUser: !!response.user,
      userRole: response.user?.role
    })
    res.json(response)
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

export async function googleSignIn (req, res, next) {
  const startTime = Date.now()
  try {
    console.log('[Sign In] Google sign-in request received', {
      timestamp: new Date().toISOString(),
      ip: req.ip,
      hasIdToken: !!req.body.idToken,
      hasFullName: !!req.body.fullName,
      hasEmail: !!req.body.email
    })

    const { idToken, fullName, email } = req.body
    if (!idToken) {
      console.log('[Sign In] Validation failed: idToken is missing')
      throw new ValidationError('idToken is required')
    }

    const clientId = process.env.GOOGLE_CLIENT_ID
    if (!clientId) {
      console.error('[Sign In] Configuration error: GOOGLE_CLIENT_ID not set')
      throw new AppError('Google Client ID not configured', 500, 'CONFIGURATION_ERROR')
    }

    console.log('[Sign In] Verifying Google ID token...', {
      clientId,
      tokenLength: idToken.length
    })

    const payload = await verifyGoogleIdToken(idToken)

    console.log('[Sign In] Google token verified successfully', {
      googleId: payload.sub,
      hasEmail: !!payload.email,
      hasName: !!payload.name
    })

    const googleId = payload.sub

    // Check if user already exists to preserve their role
    const existingUser = await findUserByGoogleId(googleId)
    console.log('[Sign In] Existing user check', {
      googleId,
      exists: !!existingUser,
      existingRole: existingUser?.role || 'none',
      existingName: existingUser?.name || 'none'
    })

    const updateData = {}
    const resolvedEmail = email ?? payload.email
    if (resolvedEmail) updateData.email = resolvedEmail
    const resolvedName = fullName ?? payload.name
    if (resolvedName) updateData.name = resolvedName

    // Preserve existing role
    if (existingUser?.role) {
      updateData.role = existingUser.role
      console.log('[Sign In] Preserving existing role:', existingUser.role)
    } else {
      console.log('[Sign In] No role found - user will need to select one')
    }

    console.log('[Sign In] Upserting user in database...', {
      googleId,
      updateData: {
        hasEmail: !!updateData.email,
        hasName: !!updateData.name,
        hasRole: !!updateData.role,
        role: updateData.role || 'null'
      }
    })

    const user = await upsertUserByGoogleId(googleId, updateData)

    // Double-check: if user still doesn't have role but existing user did, fetch again
    if (!user.role && existingUser?.role) {
      console.log('[Sign In] Role missing after upsert, fetching user again...')
      const refetchedUser = await findUserByGoogleId(googleId)
      if (refetchedUser?.role) {
        user.role = refetchedUser.role
        console.log('[Sign In] Role restored from refetch:', refetchedUser.role)
      }
    }

    const userId = user._id instanceof ObjectId ? user._id.toString() : user._id

    console.log('[Sign In] User found/created', {
      userId,
      googleId: user.googleId,
      role: user.role,
      name: user.name,
      isNewUser: !user.createdAt || (Date.now() - new Date(user.createdAt).getTime()) < 5000
    })

    console.log('[Sign In] Generating JWT token...')
    const token = signToken({
      userId,
      googleId: user.googleId,
      role: user.role
    })

    const duration = Date.now() - startTime
    const serializedUser = serializeUser({ ...user, _id: userId })
    console.log('[Sign In] Sign-in completed successfully', {
      userId,
      role: user.role,
      duration: `${duration}ms`,
      timestamp: new Date().toISOString(),
      userData: {
        id: serializedUser?.id,
        role: serializedUser?.role,
        name: serializedUser?.name,
        hasFamilyId: !!serializedUser?.familyId
      }
    })

    const response = {
      token,
      user: serializedUser
    }
    console.log('[Sign In] Sending response to client', {
      hasToken: !!response.token,
      hasUser: !!response.user,
      userRole: response.user?.role
    })
    res.json(response)
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

export async function signUp (req, res, next) {
  const startTime = Date.now()
  try {
    console.log('[Sign Up] Username/password sign-up request received', {
      timestamp: new Date().toISOString(),
      ip: req.ip,
      hasUsername: !!req.body.username,
      hasPassword: !!req.body.password
    })

    const { username, password, email, name } = req.body

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

    // Check if username already exists
    const existingUser = await findUserByUsername(username)
    if (existingUser) {
      throw new ValidationError('Username already exists')
    }

    // Hash the password
    const saltRounds = 10
    const hashedPassword = await bcrypt.hash(password, saltRounds)

    console.log('[Sign Up] Creating user...')
    const userData = {
      username,
      password: hashedPassword,
      email: email || undefined,
      name: name || undefined
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
        // Return a response indicating 2FA is required
        return res.status(200).json({
          requiresTwoFactor: true,
          userId: userId,
          message: 'Two-factor authentication code required'
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

