// Updated with assistance from Cursor (ChatGPT) on 11/7/25.

import { ObjectId } from 'mongodb'
import { getCollection } from '../lib/mongo.js'

const NOTIFICATIONS_COLLECTION = 'notifications'

function notificationsCollection () {
  return getCollection(NOTIFICATIONS_COLLECTION)
}

export async function findNotificationsForUser (userId) {
  return notificationsCollection()
    .find({ userId: new ObjectId(userId), deletedAt: null })
    .sort({ createdAt: -1 })
    .toArray()
}

export async function findNotificationsForFamily (familyId) {
  return notificationsCollection()
    .find({ familyId: new ObjectId(familyId), deletedAt: null })
    .sort({ createdAt: -1 })
    .toArray()
}

export async function createNotification ({ title, body, userId, familyId }) {
  const notification = {
    title,
    body,
    userId: userId ? new ObjectId(userId) : null,
    familyId: familyId ? new ObjectId(familyId) : null,
    read: false,
    deletedAt: null,
    createdAt: new Date(),
    updatedAt: new Date()
  }

  const result = await notificationsCollection().insertOne(notification)
  return { ...notification, _id: result.insertedId }
}

export async function createNotificationsForFamily ({ title, body, familyId }) {
  // Get all users in the family
  const { listUsersForFamily } = await import('./userModel.js')
  const users = await listUsersForFamily(familyId)
  
  // Create notifications for each user
  const notifications = []
  for (const user of users) {
    const notification = await createNotification({
      title,
      body,
      userId: user._id.toString(),
      familyId
    })
    notifications.push(notification)
  }
  
  return notifications
}

export async function createNotificationsForParents ({ title, body, familyId }) {
  // Get only parent users in the family
  const { listParentsForFamily } = await import('./userModel.js')
  const parents = await listParentsForFamily(familyId)
  
  // Create notifications for each parent
  const notifications = []
  for (const parent of parents) {
    const notification = await createNotification({
      title,
      body,
      userId: parent._id.toString(),
      familyId
    })
    notifications.push(notification)
  }
  
  return notifications
}

export async function deleteNotificationForUser (notificationId, userId) {
  const result = await notificationsCollection().updateOne(
    {
      _id: new ObjectId(notificationId),
      userId: new ObjectId(userId)
    },
    {
      $set: {
        deletedAt: new Date(),
        updatedAt: new Date()
      }
    }
  )
  return result.modifiedCount === 1
}
