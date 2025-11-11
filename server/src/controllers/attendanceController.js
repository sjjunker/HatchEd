//
//  attendanceController.js
//  HatchEd Server
//
//  Created by Cursor (ChatGPT) on 11/7/25.
//

import { upsertAttendanceRecords, findAttendanceForFamilyOnDate, findAttendanceForStudent } from '../models/attendanceModel.js'
import { findUserById, listStudentsForFamily } from '../models/userModel.js'
import { serializeAttendanceRecord } from '../utils/serializers.js'

function validateRequestBody (body) {
  if (!body || typeof body !== 'object') {
    return 'Request body is required.'
  }

  const { date, records } = body

  if (!date) {
    return 'date is required.'
  }

  const parsedDate = new Date(date)
  if (Number.isNaN(parsedDate.getTime())) {
    return 'date must be a valid ISO 8601 string.'
  }

  if (!Array.isArray(records) || records.length === 0) {
    return 'records must be a non-empty array.'
  }

  for (const record of records) {
    if (!record.studentUserId) {
      return 'Each record must include studentUserId.'
    }
    if (typeof record.isPresent !== 'boolean') {
      return 'Each record must include an isPresent boolean.'
    }
  }

  return null
}

export async function recordAttendance (req, res) {
  const bodyError = validateRequestBody(req.body)
  if (bodyError) {
    return res.status(400).json({ error: { message: bodyError } })
  }

  const { date, records } = req.body
  const requestingUserId = req.user?.userId

  const requestingUser = await findUserById(requestingUserId)
  if (!requestingUser) {
    return res.status(404).json({ error: { message: 'Requesting user not found.' } })
  }

  if (requestingUser.role !== 'parent') {
    return res.status(403).json({ error: { message: 'Only parent users can record attendance.' } })
  }

  if (!requestingUser.familyId) {
    return res.status(400).json({ error: { message: 'Parent must belong to a family before recording attendance.' } })
  }

  const students = await listStudentsForFamily(requestingUser.familyId)
  const allowedStudentIds = new Set(students.map(student => student._id.toString()))

  for (const record of records) {
    if (!allowedStudentIds.has(record.studentUserId)) {
      return res.status(400).json({ error: { message: `Student ${record.studentUserId} is not linked to this family.` } })
    }
  }

  const uniqueRecords = new Map()
  for (const record of records) {
    uniqueRecords.set(record.studentUserId, { studentUserId: record.studentUserId, isPresent: record.isPresent })
  }

  const normalizedDate = new Date(date)

  await upsertAttendanceRecords({
    familyId: requestingUser.familyId.toString(),
    recordedByUserId: requestingUserId,
    date: normalizedDate,
    records: Array.from(uniqueRecords.values())
  })

  const attendance = await findAttendanceForFamilyOnDate(requestingUser.familyId.toString(), normalizedDate)
  res.json({
    attendance: attendance.map(serializeAttendanceRecord)
  })
}

export async function getStudentAttendance (req, res) {
  const { studentUserId } = req.params
  const { limit, startDate, endDate } = req.query

  const requestingUserId = req.user?.userId
  const requestingUser = await findUserById(requestingUserId)
  if (!requestingUser) {
    return res.status(404).json({ error: { message: 'Requesting user not found.' } })
  }

  const student = await findUserById(studentUserId)
  if (!student || student.role !== 'student') {
    return res.status(404).json({ error: { message: 'Student not found.' } })
  }

  const studentFamilyId = student.familyId?.toString()
  if (!studentFamilyId) {
    return res.status(400).json({ error: { message: 'Student is not assigned to a family.' } })
  }

  if (requestingUser.role === 'parent') {
    if (!requestingUser.familyId || requestingUser.familyId.toString() !== studentFamilyId) {
      return res.status(403).json({ error: { message: 'Parent does not belong to the same family as the student.' } })
    }
  } else if (requestingUser.role === 'student') {
    if (requestingUser._id.toString() !== studentUserId) {
      return res.status(403).json({ error: { message: 'Students can only view their own attendance.' } })
    }
  } else {
    return res.status(403).json({ error: { message: 'Unauthorized role for attendance view.' } })
  }

  const numericLimit = limit ? parseInt(limit, 10) : undefined
  const records = await findAttendanceForStudent({
    familyId: studentFamilyId,
    studentUserId,
    limit: Number.isFinite(numericLimit) ? numericLimit : undefined,
    startDate,
    endDate
  })

  res.json({ attendance: records.map(serializeAttendanceRecord) })
}
