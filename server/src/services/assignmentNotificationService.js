// Service to check for overdue assignments and create notifications

import { findAssignmentsByFamilyId } from '../models/assignmentModel.js'
import { createNotification, createNotificationsForParents, findNotificationsForFamily } from '../models/notificationModel.js'
import { listStudentsForFamily } from '../models/userModel.js'

// Track ongoing checks to prevent concurrent execution
const ongoingChecks = new Set()

export async function checkOverdueAssignments (familyId) {
  const familyIdStr = familyId.toString()
  
  // Prevent concurrent execution for the same family
  if (ongoingChecks.has(familyIdStr)) {
    console.log(`Skipping duplicate check for family ${familyIdStr}`)
    return
  }
  
  ongoingChecks.add(familyIdStr)
  
  try {
    const assignments = await findAssignmentsByFamilyId(familyId)
    const students = await listStudentsForFamily(familyId)
    const now = new Date()
    
    // Group assignments by student
    const assignmentsByStudent = {}
    for (const assignment of assignments) {
      const studentId = assignment.studentId?.toString()
      if (!studentId) continue
      
      if (!assignmentsByStudent[studentId]) {
        assignmentsByStudent[studentId] = []
      }
      assignmentsByStudent[studentId].push(assignment)
    }
    
    // Check each student's assignments
    for (const student of students) {
      const studentId = student._id.toString()
      const studentAssignments = assignmentsByStudent[studentId] || []
      
      for (const assignment of studentAssignments) {
        // Skip if already graded
        if (assignment.pointsAwarded != null) continue
        
        // Skip if no due date
        if (!assignment.dueDate) continue
        
        const dueDate = new Date(assignment.dueDate)
        const assignmentId = assignment._id.toString()
        
        // Check if overdue (past due date)
        if (dueDate < now) {
          // Check if we've already notified for this assignment
          // Look for existing notifications about this assignment
          const existingNotifications = await findNotificationsForFamily(familyId)
          const alreadyNotified = existingNotifications.some(n => {
            if (!n.body || !n.createdAt) return false
            
            // Check if notification is about this specific assignment by title and "overdue" text
            const isAboutThisAssignment = n.body.includes(assignment.title) && n.body.includes('overdue')
            
            // Only check notifications from the last 7 days to prevent duplicate notifications
            const notificationAge = now - new Date(n.createdAt)
            const isRecent = notificationAge < 7 * 24 * 60 * 60 * 1000
            
            return isAboutThisAssignment && isRecent
          })
          
          if (!alreadyNotified) {
            const studentName = student.name || 'Student'
            const daysOverdue = Math.floor((now - dueDate) / (1000 * 60 * 60 * 24))
            
            const studentBody = `"${assignment.title}" is ${daysOverdue === 0 ? 'due today' : `${daysOverdue} day${daysOverdue > 1 ? 's' : ''} overdue`}`
            const parentBody = `${studentName}'s assignment "${assignment.title}" is ${daysOverdue === 0 ? 'due today' : `${daysOverdue} day${daysOverdue > 1 ? 's' : ''} overdue`}`
            
            // Create notification for student
            await createNotification({
              title: 'Overdue Assignment',
              body: studentBody,
              userId: studentId,
              familyId: familyId.toString()
            })
            
            // Create notification for parents
            await createNotificationsForParents({
              title: 'Overdue Assignment',
              body: parentBody,
              familyId: familyId.toString()
            })
          }
        }
      }
    }
  } catch (error) {
    console.error('Error checking overdue assignments:', error)
  } finally {
    // Remove from ongoing checks
    ongoingChecks.delete(familyIdStr)
  }
}

// Function to check all families (for background task)
export async function checkAllFamiliesOverdueAssignments () {
  try {
    const { listAllFamilies } = await import('../models/familyModel.js')
    const families = await listAllFamilies()
    
    for (const family of families) {
      await checkOverdueAssignments(family._id)
    }
  } catch (error) {
    console.error('Error checking all families for overdue assignments:', error)
  }
}

// Function to check overdue assignments when assignments are fetched
export async function checkOverdueAssignmentsOnFetch (familyId) {
  // Run asynchronously without blocking
  setImmediate(() => {
    checkOverdueAssignments(familyId).catch(err => {
      console.error('Error in background overdue check:', err)
    })
  })
}

