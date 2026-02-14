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
 * Download and store multiple images in the database.
 * Returns only references: { id, description } for the portfolio's generatedImages array.
 * No URLs are stored; clients load images by id from GET /api/portfolios/images/:id.
 */
export async function downloadAndStoreImages(images, portfolioId) {
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
    if (!image.url || image.url.trim() === '') {
      console.warn(`[Image Storage] Skipping image ${i + 1} (no URL - generation failed)`)
      storedImages.push({ id: `failed-${i}`, description: image.description || '' })
      continue
    }
    try {
      const { data: imageData, contentType } = await downloadImageAsBase64(image.url)
      const imageRecord = await createPortfolioImage({
        portfolioId,
        description: image.description || '',
        imageData,
        contentType
      })
      const imageId = imageRecord._id.toString()
      storedImages.push({ id: imageId, description: image.description || '' })
      console.log(`[Image Storage] Image ${i + 1}/${images.length} stored in database: ${imageId}`)
    } catch (error) {
      console.error(`[Image Storage] Failed to store image ${i + 1}:`, error.message)
      storedImages.push({ id: `fallback-${i}`, description: image.description || '' })
    }
  }
  console.log('[Image Storage] Completed storing images in database:', storedImages.length, 'of', images.length)
  return storedImages
}
