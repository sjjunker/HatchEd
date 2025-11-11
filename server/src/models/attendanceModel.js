//
//  attendanceModel.js
//  HatchEd Server
//
//  Created by Cursor (ChatGPT) on 11/7/25.
//

import { ObjectId } from 'mongodb'
import { getCollection } from '../lib/mongo.js'

const ATTENDANCE_COLLECTION = 'attendanceRecords'

function attendanceCollection () {
  return getCollection(ATTENDANCE_COLLECTION)
}

function normalizeDateToUTC (date) {
  const normalized = new Date(date)
  normalized.setUTCHours(0, 0, 0, 0)
  return normalized
}

export async function upsertAttendanceRecords ({ familyId, recordedByUserId, date, records }) {
  if (!records.length) {
    return { matchedCount: 0, modifiedCount: 0, upsertedCount: 0 }
  }

  const attendanceDate = normalizeDateToUTC(date)
  const now = new Date()
  const familyObjectId = new ObjectId(familyId)
  const recordedByObjectId = new ObjectId(recordedByUserId)

  const operations = records.map(({ studentUserId, isPresent }) => ({
    updateOne: {
      filter: {
        familyId: familyObjectId,
        studentUserId: new ObjectId(studentUserId),
        date: attendanceDate
      },
      update: {
        $set: {
          familyId: familyObjectId,
          studentUserId: new ObjectId(studentUserId),
          date: attendanceDate,
          isPresent: Boolean(isPresent),
          status: Boolean(isPresent) ? 'present' : 'absent',
          recordedByUserId: recordedByObjectId,
          updatedAt: now
        },
        $setOnInsert: {
          createdAt: now
        }
      },
      upsert: true
    }
  }))

  const result = await attendanceCollection().bulkWrite(operations, { ordered: false })

  return {
    matchedCount: result.matchedCount ?? 0,
    modifiedCount: result.modifiedCount ?? 0,
    upsertedCount: result.upsertedCount ?? 0
  }
}

export async function findAttendanceForFamilyOnDate (familyId, date) {
  const attendanceDate = normalizeDateToUTC(date)
  return attendanceCollection()
    .find({ familyId: new ObjectId(familyId), date: attendanceDate })
    .toArray()
}

export async function findAttendanceForStudent ({ familyId, studentUserId, limit, startDate, endDate }) {
  const query = {
    familyId: new ObjectId(familyId),
    studentUserId: new ObjectId(studentUserId)
  }

  if (startDate || endDate) {
    query.date = {}
    if (startDate) {
      query.date.$gte = normalizeDateToUTC(startDate)
    }
    if (endDate) {
      query.date.$lte = normalizeDateToUTC(endDate)
    }
  }

  const cursor = attendanceCollection()
    .find(query)
    .sort({ date: -1 })

  if (limit && Number.isFinite(limit)) {
    cursor.limit(limit)
  }

  return cursor.toArray()
}
