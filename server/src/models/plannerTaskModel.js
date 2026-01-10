// Updated with assistance from Cursor (ChatGPT) on 12/13/25.

import { ObjectId } from 'mongodb'
import { getCollection } from '../lib/mongo.js'

const PLANNER_TASKS_COLLECTION = 'plannerTasks'

function plannerTasksCollection () {
  return getCollection(PLANNER_TASKS_COLLECTION)
}

export async function createPlannerTask ({ familyId, userId, title, startDate, durationMinutes, colorName, subject }) {
  const task = {
    familyId: new ObjectId(familyId),
    userId: new ObjectId(userId),
    title,
    startDate: new Date(startDate),
    durationMinutes,
    colorName,
    subject: subject || null,
    createdAt: new Date(),
    updatedAt: new Date()
  }

  const result = await plannerTasksCollection().insertOne(task)
  return { ...task, _id: result.insertedId }
}

export async function findPlannerTasksByFamilyId (familyId) {
  return plannerTasksCollection().find({ familyId: new ObjectId(familyId) }).sort({ startDate: 1, createdAt: 1 }).toArray()
}

export async function findPlannerTasksByUserId (userId) {
  return plannerTasksCollection().find({ userId: new ObjectId(userId) }).sort({ startDate: 1, createdAt: 1 }).toArray()
}

export async function findPlannerTaskById (id) {
  return plannerTasksCollection().findOne({ _id: new ObjectId(id) })
}

export async function updatePlannerTask (id, { title, startDate, durationMinutes, colorName, subject }) {
  const update = {}
  if (title !== undefined) update.title = title
  if (startDate !== undefined) update.startDate = new Date(startDate)
  if (durationMinutes !== undefined) update.durationMinutes = durationMinutes
  if (colorName !== undefined) update.colorName = colorName
  if (subject !== undefined) update.subject = subject || null
  update.updatedAt = new Date()

  const result = await plannerTasksCollection().findOneAndUpdate(
    { _id: new ObjectId(id) },
    { $set: update },
    { returnDocument: 'after' }
  )

  if (result?.value) {
    return result.value
  }
  
  return await findPlannerTaskById(id)
}

export async function deletePlannerTask (id) {
  const result = await plannerTasksCollection().deleteOne({ _id: new ObjectId(id) })
  return result.deletedCount > 0
}

