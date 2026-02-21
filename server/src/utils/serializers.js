// Updated with assistance from Cursor (ChatGPT) on 11/7/25.

export function serializeUser (user) {
  if (!user) return null
  const payload = {
    id: user._id?.toString?.() ?? user._id,
    appleId: user.appleId,
    googleId: user.googleId,
    username: user.username,
    name: user.name ?? null,
    email: user.email ?? null,
    role: user.role ?? null,
    familyId: user.familyId ? user.familyId.toString() : null,
    invitePending: !!(user.inviteToken != null),
    createdAt: user.createdAt,
    updatedAt: user.updatedAt
  }
  return payload
}

/** Like serializeUser but adds inviteLink and inviteToken when user has a pending invite (for family students so parent can copy link later). */
export function serializeUserWithInvite (user, baseUrl) {
  const payload = serializeUser(user)
  if (!payload) return null
  if (user.inviteToken) {
    const invitePath = `/invite?token=${encodeURIComponent(user.inviteToken)}`
    payload.inviteLink = `${baseUrl}${invitePath}`
    payload.inviteToken = user.inviteToken
  }
  return payload
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

/** Serialize a single student for course.students. */
function serializeCourseStudent (student) {
  if (!student) return null
  return {
    id: student._id?.toString?.() ?? student._id,
    name: student.name ?? null,
    email: student.email ?? null
  }
}

/** Serialize course with students array. students is array of user objects. */
export function serializeCourse (course, students) {
  if (!course) return null
  const studentsList = Array.isArray(students) ? students : (students ? [students] : [])
  return {
    id: course._id?.toString?.() ?? course._id,
    name: course.name,
    colorName: course.colorName || 'Blue',
    students: studentsList.map(serializeCourseStudent).filter(Boolean),
    assignments: course.assignments ?? [],
    createdAt: course.createdAt,
    updatedAt: course.updatedAt
  }
}

export function serializeAssignment (assignment) {
  if (!assignment) return null
  return {
    id: assignment._id?.toString?.() ?? assignment._id,
    title: assignment.title,
    studentId: assignment.studentId?.toString?.() ?? assignment.studentId,
    dueDate: assignment.dueDate ?? null,
    instructions: assignment.instructions ?? null,
    pointsPossible: assignment.pointsPossible ?? null,
    pointsAwarded: assignment.pointsAwarded ?? null,
    courseId: assignment.courseId?.toString?.() ?? assignment.courseId ?? null,
    questions: assignment.questions ?? [],
    completed: assignment.completed ?? false, // Default to false if not set
    createdAt: assignment.createdAt,
    updatedAt: assignment.updatedAt
  }
}

export function serializePortfolio (portfolio) {
  if (!portfolio) return null
  
  // generatedImages are references only: { id, description }. No URLs; client loads from GET /api/portfolios/images/:id
  const generatedImages = (portfolio.generatedImages ?? []).map((img, index) => {
    if (typeof img === 'object' && img !== null) {
      return {
        id: img.id || `img-${index}`,
        description: img.description || ''
      }
    }
    return img
  })
  
  // Client expects reportCardSnapshot as a string (JSON); after PII decrypt we may have an object
  let reportCardSnapshot = portfolio.reportCardSnapshot ?? null
  if (reportCardSnapshot != null && typeof reportCardSnapshot === 'object') {
    reportCardSnapshot = JSON.stringify(reportCardSnapshot)
  }

  // Client expects sectionData as an object; after PII decrypt we may have object or string
  let sectionData = portfolio.sectionData ?? null
  if (typeof sectionData === 'string') {
    try {
      sectionData = sectionData ? JSON.parse(sectionData) : null
    } catch {
      sectionData = null
    }
  }

  return {
    id: portfolio._id?.toString?.() ?? portfolio._id,
    studentId: portfolio.studentId?.toString?.() ?? portfolio.studentId,
    studentName: portfolio.studentName,
    designPattern: portfolio.designPattern,
    studentWorkFileIds: portfolio.studentWorkFileIds?.map(id => id.toString()) ?? [],
    studentRemarks: portfolio.studentRemarks ?? null,
    instructorRemarks: portfolio.instructorRemarks ?? null,
    reportCardSnapshot,
    sectionData,
    compiledContent: portfolio.compiledContent ?? '',
    snippet: portfolio.snippet ?? '',
    generatedImages: generatedImages,
    createdAt: portfolio.createdAt,
    updatedAt: portfolio.updatedAt
  }
}

export function serializeStudentWorkFile (file) {
  if (!file) return null
  return {
    id: file._id?.toString?.() ?? file._id,
    fileName: file.fileName,
    fileUrl: file.fileUrl ?? null,
    fileType: file.fileType,
    fileSize: file.fileSize,
    studentId: file.studentId?.toString?.() ?? file.studentId,
    uploadedAt: file.uploadedAt,
    createdAt: file.createdAt,
    updatedAt: file.updatedAt
  }
}

export function serializeResourceFolder (folder) {
  if (!folder) return null
  return {
    id: folder._id?.toString?.() ?? folder._id,
    name: folder.name,
    parentFolderId: folder.parentFolderId?.toString?.() ?? folder.parentFolderId ?? null,
    createdAt: folder.createdAt,
    updatedAt: folder.updatedAt
  }
}

export function serializeResource (resource) {
  if (!resource) return null
  return {
    id: resource._id?.toString?.() ?? resource._id,
    folderId: resource.folderId?.toString?.() ?? resource.folderId ?? null,
    displayName: resource.displayName,
    type: resource.type ?? 'file',
    fileUrl: resource.fileUrl ?? null,
    url: resource.url ?? null,
    mimeType: resource.mimeType ?? null,
    fileSize: resource.fileSize ?? null,
    assignmentId: resource.assignmentId?.toString?.() ?? resource.assignmentId ?? null,
    createdAt: resource.createdAt,
    updatedAt: resource.updatedAt
  }
}

export function serializePlannerTask (task) {
  if (!task) return null
  return {
    id: task._id?.toString?.() ?? task._id,
    title: task.title,
    startDate: task.startDate,
    durationMinutes: task.durationMinutes,
    colorName: task.colorName,
    subject: task.subject ?? null,
    createdAt: task.createdAt,
    updatedAt: task.updatedAt
  }
}

