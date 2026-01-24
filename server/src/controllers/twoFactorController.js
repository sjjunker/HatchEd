// Updated with assistance from Cursor (ChatGPT)
import speakeasy from 'speakeasy'
import QRCode from 'qrcode'
import { findUserById, updateUserTwoFactor } from '../models/userModel.js'
import { ValidationError } from '../utils/errors.js'

export async function setupTwoFactorHandler (req, res, next) {
  try {
    const userId = req.user.userId
    
    // Generate a secret
    const secret = speakeasy.generateSecret({
      name: `HatchEd (${req.user.email || req.user.username || 'User'})`,
      issuer: 'HatchEd'
    })
    
    // Generate QR code
    const qrCodeUrl = await QRCode.toDataURL(secret.otpauth_url)
    
    // Store the secret temporarily (not enabled yet - user must verify first)
    await updateUserTwoFactor(userId, {
      twoFactorSecret: secret.base32,
      twoFactorEnabled: false
    })
    
    res.json({
      secret: secret.base32,
      qrCode: qrCodeUrl,
      manualEntryKey: secret.base32
    })
  } catch (error) {
    console.error('[2FA] Setup failed:', error)
    next(error)
  }
}

export async function verifyTwoFactorHandler (req, res, next) {
  try {
    const userId = req.user.userId
    const { code } = req.body
    
    if (!code) {
      throw new ValidationError('Verification code is required')
    }
    
    const user = await findUserById(userId)
    if (!user || !user.twoFactorSecret) {
      throw new ValidationError('Two-factor authentication is not set up')
    }
    
    // Verify the code
    const verified = speakeasy.totp.verify({
      secret: user.twoFactorSecret,
      encoding: 'base32',
      token: code,
      window: 2 // Allow 2 time steps (60 seconds) of tolerance
    })
    
    if (!verified) {
      throw new ValidationError('Invalid verification code')
    }
    
    // Enable 2FA
    await updateUserTwoFactor(userId, {
      twoFactorEnabled: true
    })
    
    res.json({ success: true, message: 'Two-factor authentication enabled' })
  } catch (error) {
    console.error('[2FA] Verification failed:', error)
    next(error)
  }
}

export async function disableTwoFactorHandler (req, res, next) {
  try {
    const userId = req.user.userId
    const { code } = req.body
    
    const user = await findUserById(userId)
    if (!user || !user.twoFactorEnabled) {
      throw new ValidationError('Two-factor authentication is not enabled')
    }
    
    // Verify code before disabling
    if (code) {
      const verified = speakeasy.totp.verify({
        secret: user.twoFactorSecret,
        encoding: 'base32',
        token: code,
        window: 2
      })
      
      if (!verified) {
        throw new ValidationError('Invalid verification code')
      }
    }
    
    // Disable 2FA and clear secret
    await updateUserTwoFactor(userId, {
      twoFactorEnabled: false,
      twoFactorSecret: null
    })
    
    res.json({ success: true, message: 'Two-factor authentication disabled' })
  } catch (error) {
    console.error('[2FA] Disable failed:', error)
    next(error)
  }
}

export async function verifyTwoFactorCode (userId, code) {
  const user = await findUserById(userId)
  if (!user || !user.twoFactorEnabled || !user.twoFactorSecret) {
    return false
  }
  
  return speakeasy.totp.verify({
    secret: user.twoFactorSecret,
    encoding: 'base32',
    token: code,
    window: 2
  })
}
