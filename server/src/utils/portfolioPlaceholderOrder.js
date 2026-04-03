/**
 * Find every [PROVIDED_PHOTO: sectionKey] and [IMAGE: description] in **document order**
 * (left-to-right). Build parallel `placeholders` and a string with sentinel markers \u0000M{i}\u0000
 * so merged image order matches the order of [IMAGE] tokens the client renders.
 */
export function extractPlaceholdersInDocumentOrder (compiledContent) {
  const placeholders = []
  if (!compiledContent || typeof compiledContent !== 'string') {
    return { placeholders, tempContent: compiledContent || '' }
  }

  const matches = []
  const reProv = /\[PROVIDED_PHOTO:\s*(\w+)\]/g
  let m
  while ((m = reProv.exec(compiledContent)) !== null) {
    matches.push({
      index: m.index,
      length: m[0].length,
      type: 'provided',
      sectionKey: m[1]
    })
  }
  const reImg = /\[IMAGE:\s*([^\]]+)\]/g
  while ((m = reImg.exec(compiledContent)) !== null) {
    matches.push({
      index: m.index,
      length: m[0].length,
      type: 'generated',
      description: m[1].trim()
    })
  }

  matches.sort((a, b) => a.index - b.index)

  for (const x of matches) {
    placeholders.push(
      x.type === 'provided'
        ? { type: 'provided', sectionKey: x.sectionKey }
        : { type: 'generated', description: x.description }
    )
  }

  let tempContent = ''
  let last = 0
  for (let i = 0; i < matches.length; i++) {
    const x = matches[i]
    tempContent += compiledContent.slice(last, x.index)
    tempContent += `\u0000M${i}\u0000`
    last = x.index + x.length
  }
  tempContent += compiledContent.slice(last)

  return { placeholders, tempContent }
}
