// Image storage utility for downloading and storing DALL-E generated images
import fs from 'fs/promises'
import { createWriteStream } from 'fs'
import path from 'path'
import { fileURLToPath } from 'url'
import https from 'https'
import http from 'http'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

// Directory for storing portfolio images
const PORTFOLIO_IMAGES_DIR = path.join(__dirname, '../../uploads/portfolio-images')

/**
 * Ensure the portfolio images directory exists
 */
async function ensureImagesDirectory() {
  try {
    await fs.mkdir(PORTFOLIO_IMAGES_DIR, { recursive: true })
  } catch (error) {
    console.error('[Image Storage] Error creating images directory:', error)
    throw error
  }
}

/**
 * Download an image from a URL and save it to disk
 * @param {string} imageUrl - URL of the image to download
 * @param {string} filename - Filename to save the image as
 * @returns {Promise<string>} Path to the saved image file
 */
async function downloadAndSaveImage(imageUrl, filename) {
  await ensureImagesDirectory()
  
  const filePath = path.join(PORTFOLIO_IMAGES_DIR, filename)
  
  return new Promise((resolve, reject) => {
    const protocol = imageUrl.startsWith('https:') ? https : http
    
    protocol.get(imageUrl, (response) => {
      // Check if response is successful
      if (response.statusCode !== 200) {
        reject(new Error(`Failed to download image: HTTP ${response.statusCode}`))
        return
      }
      
      // Check content type
      const contentType = response.headers['content-type']
      if (!contentType || !contentType.startsWith('image/')) {
        reject(new Error(`Invalid content type: ${contentType}`))
        return
      }
      
      // Create write stream
      const fileStream = createWriteStream(filePath)
      
      response.pipe(fileStream)
      
      fileStream.on('finish', () => {
        fileStream.close()
        console.log('[Image Storage] Image saved:', filename)
        resolve(filePath)
      })
      
      fileStream.on('error', (error) => {
        fs.unlink(filePath).catch(() => {}) // Delete the file on error
        reject(error)
      })
    }).on('error', (error) => {
      reject(error)
    })
  })
}

/**
 * Generate a unique filename for an image
 * @param {string} description - Image description
 * @param {number} index - Image index
 * @returns {string} Unique filename
 */
function generateImageFilename(description, index) {
  // Create a safe filename from description
  const safeDescription = description
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .substring(0, 50) // Limit length
  
  const timestamp = Date.now()
  const random = Math.random().toString(36).substring(2, 8)
  
  return `${timestamp}-${index}-${safeDescription}-${random}.png`
}

/**
 * Download and save multiple images
 * @param {Array<{description: string, url: string}>} images - Array of image objects
 * @param {string} baseUrl - Base URL for the server (e.g., 'http://localhost:4000')
 * @returns {Promise<Array<{description: string, url: string}>>} Array of images with updated URLs
 */
export async function downloadAndStoreImages(images, baseUrl = '') {
  if (!images || images.length === 0) {
    return []
  }
  
  console.log('[Image Storage] Downloading and storing', images.length, 'images...')
  
  const storedImages = []
  
  for (let i = 0; i < images.length; i++) {
    const image = images[i]
    try {
      const filename = generateImageFilename(image.description, i)
      await downloadAndSaveImage(image.url, filename)
      
      // Create server URL for the image
      const serverUrl = `${baseUrl}/api/portfolios/images/${filename}`
      
      storedImages.push({
        description: image.description,
        url: serverUrl
      })
      
      console.log(`[Image Storage] Image ${i + 1}/${images.length} stored: ${filename}`)
    } catch (error) {
      console.error(`[Image Storage] Failed to store image ${i + 1}:`, error.message)
      // Continue with other images even if one fails
      // Use original URL as fallback
      storedImages.push({
        description: image.description,
        url: image.url // Keep original URL as fallback
      })
    }
  }
  
  console.log('[Image Storage] Completed storing images:', storedImages.length, 'of', images.length)
  return storedImages
}

/**
 * Get the path to a stored image file
 * @param {string} filename - Image filename
 * @returns {string} Full path to the image file
 */
export function getImagePath(filename) {
  return path.join(PORTFOLIO_IMAGES_DIR, filename)
}

/**
 * Check if an image file exists
 * @param {string} filename - Image filename
 * @returns {Promise<boolean>} True if file exists
 */
export async function imageExists(filename) {
  try {
    const filePath = getImagePath(filename)
    await fs.access(filePath)
    return true
  } catch {
    return false
  }
}
