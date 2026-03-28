/**
 * Unit tests for work-session date helpers (run: npm test)
 */
import { describe, it } from 'node:test'
import assert from 'node:assert/strict'
import { utcCalendarDayMs, sortedWorkDates } from './workSessionUtils.js'

describe('utcCalendarDayMs', () => {
  it('normalizes to UTC calendar day', () => {
    const a = new Date('2026-03-15T08:00:00.000Z')
    const b = new Date('2026-03-15T23:59:59.999Z')
    assert.equal(utcCalendarDayMs(a), utcCalendarDayMs(b))
  })

  it('differs across UTC calendar boundaries', () => {
    const day1 = new Date('2026-03-15T12:00:00.000Z')
    const day2 = new Date('2026-03-16T12:00:00.000Z')
    assert.notEqual(utcCalendarDayMs(day1), utcCalendarDayMs(day2))
  })
})

describe('sortedWorkDates', () => {
  it('returns empty for non-array or empty', () => {
    assert.deepEqual(sortedWorkDates([]), [])
    assert.deepEqual(sortedWorkDates(null), [])
    assert.deepEqual(sortedWorkDates(undefined), [])
  })

  it('sorts chronologically', () => {
    const later = new Date('2026-06-01T12:00:00.000Z')
    const earlier = new Date('2026-03-01T12:00:00.000Z')
    const mid = new Date('2026-04-01T12:00:00.000Z')
    const out = sortedWorkDates([later, earlier, mid])
    assert.equal(out[0].getTime(), earlier.getTime())
    assert.equal(out[1].getTime(), mid.getTime())
    assert.equal(out[2].getTime(), later.getTime())
  })

  it('does not mutate original array', () => {
    const a = new Date('2026-01-02T00:00:00.000Z')
    const b = new Date('2026-01-01T00:00:00.000Z')
    const arr = [a, b]
    sortedWorkDates(arr)
    assert.equal(arr[0], a)
  })
})
