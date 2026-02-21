// Updated with assistance from Cursor (ChatGPT) on 12/13/25.

import { ObjectId } from 'mongodb'
import { findUserById } from '../models/userModel.js'
import { createPlannerTask, findPlannerTasksByFamilyId, findPlannerTaskById, updatePlannerTask, deletePlannerTask } from '../models/plannerTaskModel.js'
import { serializePlannerTask } from '../utils/serializers.js'

// Planner Tasks (for tasks without subjects)
export async function createPlannerTaskHandler (req, res) {
  const { title, startDate, durationMinutes, subject } = req.body
  if (!title || !title.trim()) {
    return res.status(400).json({ error: { message: 'Title is required' } })
  }
  if (!startDate) {
    return res.status(400).json({ error: { message: 'Start date is required' } })
  }

  const user = await findUserById(req.user.userId)
  if (!user || !user.familyId) {
    return res.status(400).json({ error: { message: 'User must belong to a family' } })
  }

  // Only save as planner task if subject is NOT provided
  if (subject) {
    return res.status(400).json({ error: { message: 'Tasks with subjects should be saved as assignments' } })
  }

  const task = await createPlannerTask({
    familyId: user.familyId,
    userId: req.user.userId,
    title: title.trim(),
    startDate,
    durationMinutes: durationMinutes || 60,
    colorName: 'Blue',
    subject: null
  })
  res.status(201).json({ task: serializePlannerTask(task) })
}

export async function getPlannerTasksHandler (req, res) {
  const user = await findUserById(req.user.userId)
  if (!user || !user.familyId) {
    return res.json({ tasks: [] })
  }

  const tasks = await findPlannerTasksByFamilyId(user.familyId)
  res.json({ tasks: tasks.map(serializePlannerTask) })
}

export async function updatePlannerTaskHandler (req, res) {
  const { id } = req.params
  const { title, startDate, durationMinutes, subject } = req.body

  const user = await findUserById(req.user.userId)
  if (!user || !user.familyId) {
    return res.status(400).json({ error: { message: 'User must belong to a family' } })
  }

  const task = await findPlannerTaskById(id)
  if (!task) {
    return res.status(404).json({ error: { message: 'Task not found' } })
  }

  if (task.familyId.toString() !== user.familyId.toString()) {
    return res.status(403).json({ error: { message: 'Not authorized' } })
  }

  // If subject is being added, this should be converted to an assignment instead
  if (subject && !task.subject) {
    return res.status(400).json({ error: { message: 'Cannot add subject to planner task. Convert to assignment instead.' } })
  }

  const updated = await updatePlannerTask(id, { title, startDate, durationMinutes, colorName: 'Blue', subject: subject || null })
  res.json({ task: serializePlannerTask(updated) })
}

export async function deletePlannerTaskHandler (req, res) {
  const { id } = req.params

  const user = await findUserById(req.user.userId)
  if (!user || !user.familyId) {
    return res.status(400).json({ error: { message: 'User must belong to a family' } })
  }

  const task = await findPlannerTaskById(id)
  if (!task) {
    return res.status(404).json({ error: { message: 'Task not found' } })
  }

  if (task.familyId.toString() !== user.familyId.toString()) {
    return res.status(403).json({ error: { message: 'Not authorized' } })
  }

  await deletePlannerTask(id)
  res.json({ success: true })
}

