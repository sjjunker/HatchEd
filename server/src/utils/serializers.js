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

