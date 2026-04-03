import test from 'node:test'
import assert from 'node:assert'
import { extractPlaceholdersInDocumentOrder } from './portfolioPlaceholderOrder.js'

test('extractPlaceholdersInDocumentOrder interleaves provided and generated', () => {
  const html = `<p>A</p>[IMAGE: first ai]<p>B</p>[PROVIDED_PHOTO: aboutMe]<p>C</p>[IMAGE: second ai]`
  const { placeholders, tempContent } = extractPlaceholdersInDocumentOrder(html)
  assert.deepStrictEqual(placeholders, [
    { type: 'generated', description: 'first ai' },
    { type: 'provided', sectionKey: 'aboutMe' },
    { type: 'generated', description: 'second ai' }
  ])
  assert.ok(tempContent.includes('\u0000M0\u0000'))
  assert.ok(tempContent.includes('\u0000M1\u0000'))
  assert.ok(tempContent.includes('\u0000M2\u0000'))
  assert.ok(!tempContent.includes('[IMAGE:'), 'markers replaced in temp')
  assert.ok(!tempContent.includes('[PROVIDED_PHOTO:'), 'provided replaced in temp')
})

test('extractPlaceholdersInDocumentOrder all provided then images matches old single-type order', () => {
  const html = `[PROVIDED_PHOTO: a][PROVIDED_PHOTO: b][IMAGE: x]`
  const { placeholders } = extractPlaceholdersInDocumentOrder(html)
  assert.strictEqual(placeholders.length, 3)
  assert.strictEqual(placeholders[0].type, 'provided')
  assert.strictEqual(placeholders[2].type, 'generated')
})
