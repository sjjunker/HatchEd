// Updated with assistance from Cursor (ChatGPT) on 11/7/25.

import { ObjectId } from 'mongodb'
import { getCollection } from '../lib/mongo.js'

const NOTIFICATIONS_COLLECTION = 'notifications'

function notificationsCollection () {
  return getCollection(NOTIFICATIONS_COLLECTION)
}

export async function findNotificationsForUser (userId) {
  return notificationsCollection()
    .find({ userId: new ObjectId(userId) })
    .sort({ createdAt: -1 })
    .toArray()
}

export async function deleteNotificationForUser (notificationId, userId) {
  const result = await notificationsCollection().deleteOne({
    _id: new ObjectId(notificationId),
    userId: new ObjectId(userId)
  })
  return result.deletedCount === 1
}
