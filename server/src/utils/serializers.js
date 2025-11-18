// Updated with assistance from Cursor (ChatGPT) on 11/7/25.

export function serializeUser (user) {
  if (!user) return null
  return {
    id: user._id?.toString?.() ?? user._id,
    appleId: user.appleId,
    name: user.name ?? null,
    email: user.email ?? null,
    role: user.role ?? null,
    familyId: user.familyId ? user.familyId.toString() : null,
    createdAt: user.createdAt,
    updatedAt: user.updatedAt
  }
}

export function serializeFamily (family) {
  if (!family) return null
  return {
    id: family._id?.toString?.() ?? family._id,
    name: family.name,
    joinCode: family.joinCode,
    members: family.members?.map(member => member.toString()) ?? [],
    createdAt: family.createdAt,
    updatedAt: family.updatedAt
  }
}

export function serializeNotification (notification) {
  if (!notification) return null
  return {
    id: notification._id?.toString?.() ?? notification._id,
    title: notification.title ?? null,
    body: notification.body ?? null,
    createdAt: notification.createdAt,
    deletedAt: notification.deletedAt ?? null,
    userId: notification.userId?.toString?.() ?? notification.userId,
    read: notification.read ?? false
  }
}

export function serializeAttendanceRecord (record) {
  if (!record) return null
  return {
    id: record._id?.toString?.() ?? record._id,
    familyId: record.familyId?.toString?.() ?? record.familyId,
    studentUserId: record.studentUserId?.toString?.() ?? record.studentUserId,
    recordedByUserId: record.recordedByUserId?.toString?.() ?? record.recordedByUserId,
    date: record.date,
    status: record.status ?? (record.isPresent ? 'present' : 'absent'),
    isPresent: Boolean(record.isPresent),
    createdAt: record.createdAt,
    updatedAt: record.updatedAt
  }
}

export function serializeSubject (subject) {
  if (!subject) return null
  return {
    id: subject._id?.toString?.() ?? subject._id,
    name: subject.name,
    createdAt: subject.createdAt,
    updatedAt: subject.updatedAt
  }
}

export function serializeCourse (course, student, subject) {
  if (!course) return null
  return {
    id: course._id?.toString?.() ?? course._id,
    name: course.name,
    grade: course.grade ?? null,
    subject: subject ? serializeSubject(subject) : null,
    student: student ? {
      id: student._id?.toString?.() ?? student._id,
      name: student.name ?? null,
      email: student.email ?? null
    } : null,
    assignments: course.assignments ?? [],
    createdAt: course.createdAt,
    updatedAt: course.updatedAt
  }
}

export function serializeAssignment (assignment, subject) {
  if (!assignment) return null
  return {
    id: assignment._id?.toString?.() ?? assignment._id,
    title: assignment.title,
    studentId: assignment.studentId?.toString?.() ?? assignment.studentId,
    dueDate: assignment.dueDate ?? null,
    instructions: assignment.instructions ?? null,
    pointsPossible: assignment.pointsPossible ?? null,
    pointsAwarded: assignment.pointsAwarded ?? null,
    subject: subject ? serializeSubject(subject) : null,
    questions: assignment.questions ?? [],
    createdAt: assignment.createdAt,
    updatedAt: assignment.updatedAt
  }
}

