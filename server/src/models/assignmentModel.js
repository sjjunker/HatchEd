// Updated with assistance from Cursor (ChatGPT) on 11/7/25.

import { ObjectId } from 'mongodb'
import { getCollection } from '../lib/mongo.js'
import { sortedWorkDates, utcCalendarDayMs } from '../utils/workSessionUtils.js'

const ASSIGNMENTS_COLLECTION = 'assignments'

function assignmentsCollection () {
  return getCollection(ASSIGNMENTS_COLLECTION)
}

export async function createAssignment ({ familyId, title, studentId, workDates, workDurationsMinutes, dueDate, instructions, pointsPossible, pointsAwarded, courseId, strictWorkSessionProgress }) {
  const normalizedWorkDates = Array.isArray(workDates) ? workDates.filter(Boolean).map(date => new Date(date)) : []
  const normalizedDurations = normalizedWorkDates.map((_, index) => {
    const duration = Array.isArray(workDurationsMinutes) ? Number(workDurationsMinutes[index]) : NaN
    return Number.isFinite(duration) ? Math.max(15, Math.round(duration)) : 60
  })
  const assignment = {
    familyId: new ObjectId(familyId),
    title,
    studentId: new ObjectId(studentId),
    workDates: normalizedWorkDates,
    workDurationsMinutes: normalizedDurations,
    dueDate: dueDate ? new Date(dueDate) : null,
    instructions: instructions ?? null,
    pointsPossible: pointsPossible ?? null,
    pointsAwarded: pointsAwarded ?? null,
    courseId: courseId ? new ObjectId(courseId) : null,
    questions: [],
    workSessionsCompleted: 0,
    strictWorkSessionProgress: strictWorkSessionProgress === true,
    completed: pointsAwarded != null, // Mark as completed if points are awarded
    createdAt: new Date(),
    updatedAt: new Date()
  }

  const result = await assignmentsCollection().insertOne(assignment)
  return { ...assignment, _id: result.insertedId }
}

export async function findAssignmentsByFamilyId (familyId) {
  return assignmentsCollection().find({ familyId: new ObjectId(familyId) }).sort({ dueDate: -1, createdAt: -1 }).toArray()
}

export async function findAssignmentsByCourseId (courseId) {
  try {
    return await assignmentsCollection().find({ courseId: new ObjectId(courseId) }).sort({ dueDate: -1, createdAt: -1 }).toArray()
  } catch (error) {
    console.error('Error finding assignments by courseId:', error)
    // Return empty array if there's an error (e.g., invalid ObjectId)
    return []
  }
}

export async function findAssignmentById (id) {
  return assignmentsCollection().findOne({ _id: new ObjectId(id) })
}

export async function updateAssignment (id, patch) {
  const existing = await findAssignmentById(id)
  if (!existing) return null

  const skipWorkSessionCompletionCheck = patch.skipWorkSessionCompletionCheck === true

  const normalizedWorkDates = patch.workDates !== undefined
    ? (Array.isArray(patch.workDates) ? patch.workDates.filter(Boolean).map(date => new Date(date)) : [])
    : existing.workDates
  const N = Array.isArray(normalizedWorkDates) ? normalizedWorkDates.length : 0

  let nextWorkSessions = existing.workSessionsCompleted ?? 0
  let nextStrict = existing.strictWorkSessionProgress === true

  if (patch.workDates !== undefined) {
    nextWorkSessions = Math.min(nextWorkSessions, N)
  }

  if (patch.incrementWorkSession === true) {
    if (N === 0) {
      const e = new Error('No work sessions configured for this assignment.')
      e.code = 'NO_WORK_SESSIONS'
      throw e
    }
    if (nextWorkSessions >= N) {
      const e = new Error('All work sessions are already marked complete.')
      e.code = 'SESSIONS_COMPLETE'
      throw e
    }
    if (nextStrict) {
      const dates = sortedWorkDates(normalizedWorkDates)
      const today = utcCalendarDayMs(new Date())
      const required = utcCalendarDayMs(dates[nextWorkSessions])
      if (today < required) {
        const e = new Error('This work session is not available until its scheduled day.')
        e.code = 'SESSION_LOCKED'
        throw e
      }
    }
    nextWorkSessions += 1
  }

  if (patch.workSessionsCompleted !== undefined) {
    const v = Number(patch.workSessionsCompleted)
    nextWorkSessions = Number.isFinite(v) ? Math.max(0, Math.min(N, Math.round(v))) : 0
  }

  if (patch.strictWorkSessionProgress !== undefined) {
    nextStrict = Boolean(patch.strictWorkSessionProgress)
  }

  const update = {}
  if (patch.title !== undefined) update.title = patch.title

  if (patch.workDates !== undefined) {
    update.workDates = normalizedWorkDates
    if (patch.workDurationsMinutes !== undefined) {
      update.workDurationsMinutes = normalizedWorkDates.map((_, index) => {
        const duration = Array.isArray(patch.workDurationsMinutes) ? Number(patch.workDurationsMinutes[index]) : NaN
        return Number.isFinite(duration) ? Math.max(15, Math.round(duration)) : 60
      })
    } else {
      const existingDurations = Array.isArray(existing.workDurationsMinutes) ? existing.workDurationsMinutes : []
      update.workDurationsMinutes = normalizedWorkDates.map((_, index) => {
        const duration = Number(existingDurations[index])
        return Number.isFinite(duration) ? Math.max(15, Math.round(duration)) : 60
      })
    }
  } else if (patch.workDurationsMinutes !== undefined) {
    update.workDurationsMinutes = Array.isArray(patch.workDurationsMinutes)
      ? patch.workDurationsMinutes.map(value => {
        const duration = Number(value)
        return Number.isFinite(duration) ? Math.max(15, Math.round(duration)) : 60
      })
      : []
  }

  if (patch.clearDueDate === true) {
    update.dueDate = null
  } else if (patch.dueDate !== undefined) {
    update.dueDate = patch.dueDate ? new Date(patch.dueDate) : null
  }
  if (patch.instructions !== undefined) update.instructions = patch.instructions
  if (patch.pointsPossible !== undefined) update.pointsPossible = patch.pointsPossible

  if (patch.pointsAwarded !== undefined) {
    update.pointsAwarded = patch.pointsAwarded
    update.completed = patch.pointsAwarded != null
  }

  if (patch.completed !== undefined && patch.pointsAwarded === undefined) {
    if (existing.pointsAwarded == null) {
      const wantComplete = Boolean(patch.completed)
      if (wantComplete && N > 0 && nextWorkSessions < N && !skipWorkSessionCompletionCheck) {
        const e = new Error('Complete all work sessions before marking this assignment done.')
        e.code = 'INCOMPLETE_SESSIONS'
        throw e
      }
      update.completed = wantComplete
    }
  }

  if (patch.courseId !== undefined) update.courseId = patch.courseId ? new ObjectId(patch.courseId) : null

  update.workSessionsCompleted = nextWorkSessions
  update.strictWorkSessionProgress = nextStrict
  update.updatedAt = new Date()

  const result = await assignmentsCollection().findOneAndUpdate(
    { _id: new ObjectId(id) },
    { $set: update },
    { returnDocument: 'after' }
  )

  if (result?.value) {
    return result.value
  }

  return await findAssignmentById(id)
}

export async function deleteAssignment (id) {
  const result = await assignmentsCollection().deleteOne({ _id: new ObjectId(id) })
  return result.deletedCount > 0
}

export async function deleteAssignmentsByStudentId (studentId) {
  const result = await assignmentsCollection().deleteMany({
    studentId: new ObjectId(studentId)
  })
  return result.deletedCount
}
