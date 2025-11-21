// Updated with assistance from Cursor (ChatGPT) on 11/7/25.

import { serializeNotification } from '../utils/serializers.js'
import { deleteNotificationForUser, findNotificationsForUser, createNotification, createNotificationsForParents } from '../models/notificationModel.js'
import { findUserById } from '../models/userModel.js'

export async function listNotifications (req, res) {
  const notifications = await findNotificationsForUser(req.user.userId)
  res.json({ notifications: notifications.map(serializeNotification) })
}

export async function createNotificationHandler (req, res) {
  const { title, body, userId, familyId } = req.body
  
  if (!title || !title.trim()) {
    return res.status(400).json({ error: { message: 'Notification title is required' } })
  }
  
  if (!body || !body.trim()) {
    return res.status(400).json({ error: { message: 'Notification body is required' } })
  }
  
  const user = await findUserById(req.user.userId)
  if (!user || !user.familyId) {
    return res.status(400).json({ error: { message: 'User must belong to a family' } })
  }
  
  let notification
  
  if (familyId && !userId) {
    // Create notifications for all parents in the family (for help requests)
    const notifications = await createNotificationsForParents({
      title: title.trim(),
      body: body.trim(),
      familyId: user.familyId.toString()
    })
    return res.status(201).json({ notifications: notifications.map(serializeNotification) })
  } else if (userId) {
    // Create notification for specific user
    notification = await createNotification({
      title: title.trim(),
      body: body.trim(),
      userId,
      familyId: user.familyId.toString()
    })
  } else {
    // Create notification for current user
    notification = await createNotification({
      title: title.trim(),
      body: body.trim(),
      userId: req.user.userId,
      familyId: user.familyId.toString()
    })
  }
  
  res.status(201).json({ notification: serializeNotification(notification) })
}

export async function removeNotification (req, res) {
  const { notificationId } = req.params
  const deleted = await deleteNotificationForUser(notificationId, req.user.userId)
  if (!deleted) {
    return res.status(404).json({ error: { message: 'Notification not found' } })
  }
  res.status(204).end()
}
