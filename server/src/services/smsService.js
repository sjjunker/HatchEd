// Updated with assistance from Cursor (ChatGPT)
import twilio from 'twilio'

// Initialize Twilio client (will be null if credentials not provided)
let twilioClient = null
if (process.env.TWILIO_ACCOUNT_SID && process.env.TWILIO_AUTH_TOKEN) {
  twilioClient = twilio(process.env.TWILIO_ACCOUNT_SID, process.env.TWILIO_AUTH_TOKEN)
}

// In-memory storage for verification codes (in production, use Redis or database)
const verificationCodes = new Map()

// Clean up expired codes every 10 minutes
setInterval(() => {
  const now = Date.now()
  for (const [key, data] of verificationCodes.entries()) {
    if (data.expiresAt < now) {
      verificationCodes.delete(key)
    }
  }
}, 10 * 60 * 1000)

export function generateVerificationCode () {
  // Generate a 6-digit code
  return Math.floor(100000 + Math.random() * 900000).toString()
}

export function storeVerificationCode (userId, code, phoneNumber) {
  const expiresAt = Date.now() + 10 * 60 * 1000 // 10 minutes
  verificationCodes.set(`${userId}:${phoneNumber}`, {
    code,
    phoneNumber,
    expiresAt,
    attempts: 0
  })
}

export function verifyCode (userId, phoneNumber, code) {
  const key = `${userId}:${phoneNumber}`
  const stored = verificationCodes.get(key)
  
  if (!stored) {
    return { valid: false, message: 'No verification code found. Please request a new code.' }
  }
  
  if (Date.now() > stored.expiresAt) {
    verificationCodes.delete(key)
    return { valid: false, message: 'Verification code has expired. Please request a new code.' }
  }
  
  if (stored.attempts >= 5) {
    verificationCodes.delete(key)
    return { valid: false, message: 'Too many failed attempts. Please request a new code.' }
  }
  
  if (stored.code !== code) {
    stored.attempts++
    return { valid: false, message: 'Invalid verification code.' }
  }
  
  // Code is valid - remove it
  verificationCodes.delete(key)
  return { valid: true }
}

export async function sendVerificationCode (phoneNumber, code) {
  if (!twilioClient) {
    // In development, just log the code
    console.log(`[SMS] Verification code for ${phoneNumber}: ${code}`)
    console.log('[SMS] Twilio not configured - code logged above for testing')
    return { success: true, message: 'Code sent (logged in development)' }
  }
  
  try {
    const fromNumber = process.env.TWILIO_PHONE_NUMBER
    if (!fromNumber) {
      throw new Error('TWILIO_PHONE_NUMBER not configured')
    }
    
    const message = await twilioClient.messages.create({
      body: `Your HatchEd verification code is: ${code}. This code will expire in 10 minutes.`,
      from: fromNumber,
      to: phoneNumber
    })
    
    console.log(`[SMS] Verification code sent to ${phoneNumber}, SID: ${message.sid}`)
    return { success: true, message: 'Code sent successfully' }
  } catch (error) {
    console.error('[SMS] Failed to send verification code:', error)
    throw new Error(`Failed to send SMS: ${error.message}`)
  }
}

export function clearVerificationCode (userId, phoneNumber) {
  const key = `${userId}:${phoneNumber}`
  verificationCodes.delete(key)
}
