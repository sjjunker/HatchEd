// Portfolio Image Model - stores AI-generated images in the database
import { ObjectId } from 'mongodb'
import { getCollection } from '../lib/mongo.js'
import { encrypt, decrypt } from '../utils/piiCrypto.js'

const PORTFOLIO_IMAGES_COLLECTION = 'portfolioImages'

function portfolioImagesCollection() {
  return getCollection(PORTFOLIO_IMAGES_COLLECTION)
}

function decryptPortfolioImage (doc) {
  if (!doc) return null
  const out = { ...doc }
  if (out.description != null) out.description = decrypt(out.description)
  return out
}

/**
 * Create a portfolio image record with base64 data
 * @param {Object} params - Image parameters
 * @param {string} params.portfolioId - Portfolio ID
 * @param {string} params.description - Image description
 * @param {string} params.imageData - Base64 encoded image data
 * @param {string} params.contentType - Image content type (default: image/png)
 * @returns {Promise<Object>} Created image record
 */
export async function createPortfolioImage({ portfolioId, description, imageData, contentType = 'image/png' }) {
  const image = {
    portfolioId: new ObjectId(portfolioId),
    description: description ? encrypt(description) : '',
    imageData: imageData,
    contentType: contentType,
    createdAt: new Date()
  }

  const result = await portfolioImagesCollection().insertOne(image)
  return decryptPortfolioImage({ ...image, _id: result.insertedId })
}

/**
 * Find images by portfolio ID
 * @param {string} portfolioId - Portfolio ID
 * @returns {Promise<Array>} Array of image records
 */
export async function findImagesByPortfolioId(portfolioId) {
  const docs = await portfolioImagesCollection()
    .find({ portfolioId: new ObjectId(portfolioId) })
    .sort({ createdAt: 1 })
    .toArray()
  return docs.map(decryptPortfolioImage)
}

/**
 * Find image by ID
 * @param {string} imageId - Image ID
 * @returns {Promise<Object|null>} Image record or null
 */
export async function findImageById(imageId) {
  const doc = await portfolioImagesCollection().findOne({ _id: new ObjectId(imageId) })
  return decryptPortfolioImage(doc)
}

/**
 * Delete images by portfolio ID
 * @param {string} portfolioId - Portfolio ID
 * @returns {Promise<number>} Number of deleted images
 */
export async function deleteImagesByPortfolioId(portfolioId) {
  const result = await portfolioImagesCollection().deleteMany({ portfolioId: new ObjectId(portfolioId) })
  return result.deletedCount
}

/**
 * Delete image by ID
 * @param {string} imageId - Image ID
 * @returns {Promise<boolean>} True if deleted
 */
export async function deleteImageById(imageId) {
  const result = await portfolioImagesCollection().deleteOne({ _id: new ObjectId(imageId) })
  return result.deletedCount > 0
}
