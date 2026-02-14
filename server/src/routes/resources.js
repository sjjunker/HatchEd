import { Router } from 'express'
import { asyncHandler } from '../middleware/asyncHandler.js'
import { requireAuth } from '../middleware/requireAuth.js'
import {
  getFoldersHandler,
  createFolderHandler,
  updateFolderHandler,
  deleteFolderHandler,
  getResourcesHandler,
  getResourcesForAssignmentHandler,
  getResourceFileHandler,
  createResourceHandler,
  uploadResourceHandler,
  updateResourceHandler,
  deleteResourceHandler,
  upload,
  handleMulterError
} from '../controllers/resourcesController.js'

const router = Router()
router.use(requireAuth)

// Folders
router.get('/folders', asyncHandler(getFoldersHandler))
router.post('/folders', asyncHandler(createFolderHandler))
router.patch('/folders/:id', asyncHandler(updateFolderHandler))
router.delete('/folders/:id', asyncHandler(deleteFolderHandler))

// Resources
router.get('/', asyncHandler(getResourcesHandler))
router.post('/', asyncHandler(createResourceHandler))
router.post('/upload', upload.single('file'), handleMulterError, asyncHandler(uploadResourceHandler))
router.patch('/:id', asyncHandler(updateResourceHandler))
router.delete('/:id', asyncHandler(deleteResourceHandler))

// Resources linked to an assignment (for students/parents)
router.get('/for-assignment/:assignmentId', asyncHandler(getResourcesForAssignmentHandler))

// Serve the actual file for a resource (auth required; used for preview)
router.get('/:id/file', asyncHandler(getResourceFileHandler))

export default router
