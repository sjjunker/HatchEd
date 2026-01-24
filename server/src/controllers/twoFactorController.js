// Updated with assistance from Cursor (ChatGPT)
import { findUserById, updateUserTwoFactor } from '../models/userModel.js'
import { ValidationError } from '../utils/errors.js'
import { generateVerificationCode, storeVerificationCode, sendVerificationCode } from '../services/smsService.js'

export async function setupTwoFactorHandler (req, res, next) {
  try {
    const userId = req.user.userId
    const { phoneNumber } = req.body
    
    if (!phoneNumber) {
      throw new ValidationError('Phone number is required')
    }
    
    // Validate phone number format (basic validation)
    const cleanedPhone = phoneNumber.replace(/\D/g, '')
    if (cleanedPhone.length < 10) {
      throw new ValidationError('Invalid phone number format')
    }
    
    // Format phone number with country code if not present
    const formattedPhone = cleanedPhone.startsWith('1') && cleanedPhone.length === 11
      ? `+${cleanedPhone}`
      : `+1${cleanedPhone}`
    
    // Generate verification code
    const code = generateVerificationCode()
    
    // Store code temporarily
    storeVerificationCode(userId, code, formattedPhone)
    
    // Send SMS with verification code
    await sendVerificationCode(formattedPhone, code)
    
    // Store phone number temporarily (not enabled yet - user must verify first)
    await updateUserTwoFactor(userId, {
      twoFactorPhoneNumber: formattedPhone,
      twoFactorEnabled: false
    })
    
    res.json({
      success: true,
      message: 'Verification code sent to your phone number',
      phoneNumber: formattedPhone.replace(/(\d{1})(\d{3})(\d{3})(\d{4})/, '+$1 ($2) $3-$4') // Format for display
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
    if (!user || !user.twoFactorPhoneNumber) {
      throw new ValidationError('Two-factor authentication is not set up')
    }
    
    // Verify the code using SMS service
    const { verifyCode } = await import('../services/smsService.js')
    const verification = verifyCode(userId, user.twoFactorPhoneNumber, code)
    
    if (!verification.valid) {
      throw new ValidationError(verification.message)
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
    
    // Verify code before disabling (optional but recommended)
    if (code && user.twoFactorPhoneNumber) {
      const { verifyCode } = await import('../services/smsService.js')
      const verification = verifyCode(userId, user.twoFactorPhoneNumber, code)
      
      if (!verification.valid) {
        throw new ValidationError(verification.message)
      }
    }
    
    // Disable 2FA and clear phone number
    await updateUserTwoFactor(userId, {
      twoFactorEnabled: false,
      twoFactorPhoneNumber: null
    })
    
    res.json({ success: true, message: 'Two-factor authentication disabled' })
  } catch (error) {
    console.error('[2FA] Disable failed:', error)
    next(error)
  }
}

export async function verifyTwoFactorCode (userId, code) {
  const user = await findUserById(userId)
  if (!user || !user.twoFactorEnabled || !user.twoFactorPhoneNumber) {
    return false
  }
  
  const { verifyCode } = await import('../services/smsService.js')
  const verification = verifyCode(userId, user.twoFactorPhoneNumber, code)
  return verification.valid
}

export async function sendLoginCode (userId, phoneNumber) {
  const { generateVerificationCode, storeVerificationCode, sendVerificationCode } = await import('../services/smsService.js')
  
  const code = generateVerificationCode()
  storeVerificationCode(userId, code, phoneNumber)
  await sendVerificationCode(phoneNumber, code)
  
  return { success: true, message: 'Verification code sent' }
}
