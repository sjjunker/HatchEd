// Updated with assistance from Cursor (ChatGPT) on 11/7/25.

import { serializeNotification } from '../utils/serializers.js'
import { deleteNotificationForUser, findNotificationsForUser } from '../models/notificationModel.js'

export async function listNotifications (req, res) {
  const notifications = await findNotificationsForUser(req.user.userId)
  res.json({ notifications: notifications.map(serializeNotification) })
}

export async function removeNotification (req, res) {
  const { notificationId } = req.params
  const deleted = await deleteNotificationForUser(notificationId, req.user.userId)
  if (!deleted) {
    return res.status(404).json({ error: { message: 'Notification not found' } })
  }
  res.status(204).end()
}
