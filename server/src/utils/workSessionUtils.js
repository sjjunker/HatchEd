/** Calendar-day comparison in UTC (YYYY-MM-DD as UTC) for work-session gating. */

export function utcCalendarDayMs (date) {
  const d = new Date(date)
  return Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate())
}

export function sortedWorkDates (workDates) {
  if (!Array.isArray(workDates) || workDates.length === 0) return []
  return [...workDates].sort((a, b) => new Date(a) - new Date(b))
}
