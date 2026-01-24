// Image storage utility for downloading and storing DALL-E generated images in the database
import https from 'https'
import http from 'http'
import { createPortfolioImage } from '../models/portfolioImageModel.js'

/**
 * Download an image from a URL and convert to base64
 * @param {string} imageUrl - URL of the image to download
 * @returns {Promise<{data: string, contentType: string}>} Base64 image data and content type
 */
async function downloadImageAsBase64(imageUrl) {
  return new Promise((resolve, reject) => {
    const protocol = imageUrl.startsWith('https:') ? https : http
    
    protocol.get(imageUrl, (response) => {
      // Check if response is successful
      if (response.statusCode !== 200) {
        reject(new Error(`Failed to download image: HTTP ${response.statusCode}`))
        return
      }
      
      // Check content type
      const contentType = response.headers['content-type'] || 'image/png'
      if (!contentType.startsWith('image/')) {
        reject(new Error(`Invalid content type: ${contentType}`))
        return
      }
      
      // Collect image data
      const chunks = []
      
      response.on('data', (chunk) => {
        chunks.push(chunk)
      })
      
      response.on('end', () => {
        const buffer = Buffer.concat(chunks)
        const base64Data = buffer.toString('base64')
        console.log('[Image Storage] Image downloaded and converted to base64:', {
          size: buffer.length,
          contentType
        })
        resolve({ data: base64Data, contentType })
      })
      
      response.on('error', (error) => {
        reject(error)
      })
    }).on('error', (error) => {
      reject(error)
    })
  })
}

/**
 * Download and store multiple images in the database
 * @param {Array<{description: string, url: string}>} images - Array of image objects
 * @param {string} portfolioId - Portfolio ID to associate images with
 * @param {string} baseUrl - Base URL for the server (e.g., 'http://localhost:4000')
 * @returns {Promise<Array<{id: string, description: string, url: string}>>} Array of images with database IDs and server URLs
 */
export async function downloadAndStoreImages(images, portfolioId, baseUrl = '') {
  if (!images || images.length === 0) {
    return []
  }
  
  if (!portfolioId) {
    throw new Error('Portfolio ID is required to store images')
  }
  
  console.log('[Image Storage] Downloading and storing', images.length, 'images in database...')
  
  const storedImages = []
  
  for (let i = 0; i < images.length; i++) {
    const image = images[i]
    try {
      // Download image and convert to base64
      const { data: imageData, contentType } = await downloadImageAsBase64(image.url)
      
      // Store in database
      const imageRecord = await createPortfolioImage({
        portfolioId,
        description: image.description || '',
        imageData,
        contentType
      })
      
      // Create server URL for the image
      const imageId = imageRecord._id.toString()
      const serverUrl = `${baseUrl}/api/portfolios/images/${imageId}`
      
      storedImages.push({
        id: imageId,
        description: image.description || '',
        url: serverUrl
      })
      
      console.log(`[Image Storage] Image ${i + 1}/${images.length} stored in database: ${imageId}`)
    } catch (error) {
      console.error(`[Image Storage] Failed to store image ${i + 1}:`, error.message)
      // Continue with other images even if one fails
      // Use original URL as fallback
      storedImages.push({
        id: `fallback-${i}`,
        description: image.description || '',
        url: image.url // Keep original URL as fallback
      })
    }
  }
  
  console.log('[Image Storage] Completed storing images in database:', storedImages.length, 'of', images.length)
  return storedImages
}
