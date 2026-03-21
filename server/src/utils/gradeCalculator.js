/**
 * Calculate course grade using the same formula as report cards (iOS Course.calculatedGrade).
 * Grade = (sum of pointsAwarded / sum of pointsPossible) * 100
 * Only includes assignments where: pointsAwarded and pointsPossible exist, possible > 0, studentId matches.
 */
export function calculateCourseGrade (course, studentId) {
  if (!course || !studentId) return null
  const assignments = course.assignments ?? []
  const sid = String(studentId)

  const relevantAssignments = assignments.filter((a) => {
    const awarded = a.pointsAwarded
    const possible = a.pointsPossible
    if (awarded == null || possible == null || possible <= 0) return false
    const aStudentId = a.studentId?.toString?.() ?? a.studentId
    return String(aStudentId) === sid && Number(awarded) >= 0
  })

  if (relevantAssignments.length === 0) return null
  const totalAwarded = relevantAssignments.reduce((sum, a) => sum + (Number(a.pointsAwarded) || 0), 0)
  const totalPossible = relevantAssignments.reduce((sum, a) => sum + (Number(a.pointsPossible) || 0), 0)
  if (totalPossible <= 0) return null
  return (totalAwarded / totalPossible) * 100
}
