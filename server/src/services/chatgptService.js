// Updated with assistance from Cursor (ChatGPT) on 11/7/25.

import OpenAI from 'openai'

// Lazy client so API key is read after dotenv has loaded
function getOpenAI () {
  const key = process.env.OPENAI_API_KEY
  if (!key || typeof key !== 'string' || key.trim() === '') {
    return null
  }
  return new OpenAI({ apiKey: key })
}

/**
 * Extract image descriptions and their section context from portfolio content (HTML or markdown)
 * @param {string} content - Portfolio content with [IMAGE: description] placeholders
 * @returns {Array<{description: string, sectionContext?: string}>}
 */
function extractImageDescriptionsWithContext (content) {
  const results = []
  const imageRegex = /\[IMAGE:\s*([^\]]+)\]/g
  let match

  while ((match = imageRegex.exec(content)) !== null) {
    const description = match[1].trim()
    const beforeMatch = content.substring(0, match.index)
    let sectionContext = null
    // HTML: <h2>, <section> with data-section, or <h1>
    const htmlH2 = beforeMatch.match(/<h2[^>]*>([^<]+)<\/h2>/gi)
    const htmlH1 = beforeMatch.match(/<h1[^>]*>([^<]+)<\/h1>/gi)
    const htmlSection = beforeMatch.match(/<section[^>]*data-section=["']([^"']+)["'][^>]*>/gi)
    if (htmlH2 && htmlH2.length > 0) {
      sectionContext = htmlH2[htmlH2.length - 1].replace(/<h2[^>]*>|<\/h2>/gi, '').trim()
    } else if (htmlSection && htmlSection.length > 0) {
      const last = htmlSection[htmlSection.length - 1]
      const m = last.match(/data-section=["']([^"']+)["']/)
      if (m) sectionContext = m[1]
    } else if (htmlH1 && htmlH1.length > 0) {
      sectionContext = htmlH1[htmlH1.length - 1].replace(/<h1[^>]*>|<\/h1>/gi, '').trim()
    } else {
      const mdSection = beforeMatch.match(/##\s+([^\n]+)/g)
      if (mdSection && mdSection.length > 0) {
        sectionContext = mdSection[mdSection.length - 1].replace(/^##\s+/, '').trim()
      }
    }
    results.push({ description, sectionContext })
  }

  return results
}

/**
 * Generate an image using DALL-E based on description
 * @param {string} description - Image description (should be contextual to section)
 * @param {string} audience - Portfolio audience for style consistency
 * @param {string} [sectionContext] - Optional section name for additional context
 * @returns {Promise<string|null>} Image URL or null if generation fails
 */
async function generateImage (description, audience, sectionContext) {
  const openai = getOpenAI()
  if (!openai) return null
  try {
    const a = (audience || 'family').toLowerCase()
    let styleHint = 'clean, professional, appropriate for an educational portfolio'
    if (a === 'college') styleHint = 'polished, aspirational, suitable for college admissions materials'
    if (a === 'state') styleHint = 'formal, document-style, clear and professional for official records'
    if (a === 'family') styleHint = 'warm, celebratory, suitable for a family keepsake'
    const contextPart = sectionContext ? ` The image is for the "${sectionContext}" section of a student portfolio.` : ''
    const enhancedPrompt = `CRITICAL: Create an image that depicts EXACTLY and LITERALLY the following scene. Do not deviate, add unrelated elements, or interpret loosely.

EXACT SCENE TO DEPICT: "${description}"
${contextPart}

Style: ${styleHint}. Photorealistic or realistic illustration. The image MUST match the description precisely so it appears next to the correct section.`
    
    const imageStartTime = Date.now()
    const response = await openai.images.generate({
      model: 'dall-e-3',
      prompt: enhancedPrompt,
      size: '1024x1024',
      quality: 'standard',
      n: 1
    })
    
    const imageDuration = Date.now() - imageStartTime
    const imageUrl = response.data[0]?.url
    if (imageUrl) {
      console.log('[ChatGPT Service] Image generated successfully', { duration: `${imageDuration}ms` })
      return imageUrl
    } else {
      console.warn('[ChatGPT Service] Image generation returned no URL in response')
      return null
    }
  } catch (error) {
    console.error('[ChatGPT Service] Error generating image:', {
      message: error.message,
      type: error.constructor?.name,
      status: error.status,
      code: error.code,
      response: error.response?.data
    })
    
    // If it's a rate limit error, log it specifically
    if (error.status === 429) {
      console.error('[ChatGPT Service] Rate limit exceeded - consider adding longer delays between image generations')
    }
    
    return null
  }
}

/**
 * Get work summaries from student work file IDs
 * @param {Array} studentWorkFiles - Array of student work file objects
 * @returns {Array<string>} Array of work summaries
 */
function getWorkSummaries (studentWorkFiles) {
  if (!studentWorkFiles || studentWorkFiles.length === 0) {
    return []
  }

  return studentWorkFiles.map((file, index) => {
    const summary = []
    summary.push(`Work Sample ${index + 1}: ${file.fileName || 'Untitled'}`)
    if (file.fileType) {
      summary.push(`Type: ${file.fileType}`)
    }
    if (file.fileSize) {
      summary.push(`Size: ${(file.fileSize / 1024).toFixed(2)} KB`)
    }
    // Add any additional metadata if available
    return summary.join(' | ')
  })
}

/**
 * Get audience-specific instructions for tone, emphasis, and content focus.
 */
function getAudienceInstructions (audience) {
  const a = (audience || 'family').toLowerCase()
  if (a === 'college' || a === 'college admissions') {
    return `AUDIENCE: College Admissions. Focus on building a compelling narrative that showcases the student's growth, unique strengths, and potential. Emphasize achievements, reflection, and standout moments. Tone: polished, confident, aspirational. Make the student memorable and distinct. Use ONLY facts and content provided—never invent or fabricate information.`
  }
  if (a === 'state' || a === 'state compliance' || a === 'statecompliance') {
    return `AUDIENCE: State Compliance / Official Documentation. MINIMALIST format. Include ONLY: (1) Grades—exact numbers from the report card data provided, (2) Attendance—exact statistics provided, (3) Subjects/Curriculum—list of courses from the data. Optionally include instructor comments, student achievements, or student service ONLY if that data was explicitly provided. You MAY include [PROVIDED_PHOTO: n] placeholders if the parent provided work sample images—place them in a Work Samples or Evidence section. Do NOT use [IMAGE: description] (no AI-generated decorative images). CRITICAL: Never invent, fabricate, or embellish any facts. Use ONLY the exact data provided.`
  }
  // family (default)
  return `AUDIENCE: Family & Keepsake. Focus on celebrating the student's journey, milestones, and personal growth. Emphasize warmth, pride, and memorable moments. Tone: warm, personal, celebratory. Use ONLY facts and content provided—never invent or fabricate information.`
}

/**
 * Get audience-specific HTML/CSS styling instructions for the portfolio output.
 */
function getAudienceStylingInstructions (audience) {
  const a = (audience || 'family').toLowerCase()
  if (a === 'college' || a === 'college admissions') {
    return `STYLING (professional advertisement / university viewbook): Design like a high-end brand campaign or admissions viewbook—NOT a basic webpage.

PALETTE: Deep navy #0f172a or charcoal #1e293b for headers/accents; crisp white #ffffff for content cards; subtle off-white #f8fafc for page background. Accent: refined gold #b8860b or navy #1e40af. Text: #0f172a (headings), #334155 (body). High contrast, premium feel.

TYPOGRAPHY: Bold, confident hierarchy. h1: 2.2rem, font-weight: 700, letter-spacing: -0.02em, color: #0f172a. h2: 1.4rem, font-weight: 600, text-transform: uppercase, letter-spacing: 0.08em, color: #1e293b. Body: "Georgia", serif or system-ui, 1rem, line-height: 1.7, color: #334155. Use weight contrast (bold headlines, regular body).

LAYOUT: Hero treatment for the title—centered or left-aligned with strong presence. Section cards: white background, box-shadow: 0 4px 24px rgba(15,23,42,0.08), border-radius: 8px, padding: 2em, margin-bottom: 2em. Consider image-left/text-right or image-right/text-left alternation for visual interest. Generous whitespace—avoid cramped layouts.

IMAGES: Use [IMAGE: description] liberally. Style images with border-radius: 6px, box-shadow: 0 4px 20px rgba(0,0,0,0.12), object-fit: cover. Place images prominently—think magazine spread or ad campaign, not clip-art.

AVOID: Plain borders, generic "website" look, weak typography, low contrast, float (causes overlap). Use flexbox or block layout—never float for image/text placement. Aim for the polish of a university brochure or luxury brand advertisement—aspirational, confident, memorable.`
  }
  if (a === 'family' || a.includes('keepsake')) {
    return `STYLING (warm, cohesive, album-like): Use a UNIFIED WARM PALETTE—do NOT mix cool colors (no blue, teal, green). Stick to warm tones only.

PALETTE: body background #faf8f5 (warm cream); section cards #fffefb (soft ivory) with subtle shadow (box-shadow: 0 2px 12px rgba(139,90,60,0.08)); accent color #b86d4a (warm terracotta) for h2, borders, or left accent bars. Text #3d342c (warm brown-black). Secondary text #6b5b52.

SECTIONS: Wrap each in <section class="keepsake-section"> with padding: 1.5em 2em; margin-bottom: 1.5em; background: #fffefb; border-radius: 12px; border-left: 4px solid #b86d4a; box-shadow: 0 2px 12px rgba(139,90,60,0.08). Use ONE style for all sections—no alternating colors that clash.

TYPOGRAPHY: Georgia for body (font-size: 1.05rem; line-height: 1.7). Headings: "Segoe UI", system-ui, sans-serif; h2 color #b86d4a; font-weight: 600. Keep it elegant and readable.

AVOID: multiple accent colors, bright or cool hues, harsh borders, busy patterns, clashing section backgrounds, float (causes overlap). Use flexbox or block layout—never float for image/text placement. The result should feel like a polished photo album—warm, inviting, and cohesive.`
  }
  return `STYLING: Use semantic HTML with a <style> block for typography, spacing, and layout.`
}

/**
 * Build a minimalist State Compliance prompt (grades, attendance, curriculum only; optional comments/achievements/service; optional work sample images).
 */
function buildStateCompliancePrompt ({ studentName, instructorRemarks, reportCardSnapshot, attendanceSummary, courses, sectionData, providedPhotoBySection }) {
  const promptParts = []

  promptParts.push(`Create a State Compliance / Official Documentation portfolio for ${studentName}.`)
  promptParts.push(`\n${getAudienceInstructions('state')}`)
  promptParts.push(`\n\nOUTPUT FORMAT: Valid HTML only—no markdown. Start with <!DOCTYPE html><html><head><meta charset="utf-8"><style>...</style></head><body> and end with </body></html>. Use <h1>, <h2>, <h3>, <section>, <p>, <ul>, <li>.`)
  promptParts.push(`\n\nSTYLING (minimalist but readable): Include a <style> block that provides: (1) SECTION BARRIERS—wrap each section in <section style="..."> with border-bottom, or border-left accent, or subtle background (#f8f9fa) and padding so sections are clearly separated; (2) LAYOUT VARIETY—use display:block for some sections, consider a simple two-column layout for grades/courses using CSS grid or flexbox; (3) FONT VARIETY—use different font-weights (bold for h2, semibold for h3, regular for body), consider Georgia or a serif for body text, sans-serif for headers; (4) TEXT ALIGNMENT—center h1 and section headers, left-align body text; (5) SPACING—generous margin and padding between sections (1.5em–2em), line-height 1.5–1.6 for readability. Keep it professional and data-focused—no decorative images. Do NOT use [IMAGE: description] (no AI-generated images).`)
  const stateSectionKeys = Object.keys(providedPhotoBySection || {})
  if (stateSectionKeys.length > 0) {
    promptParts.push(`\n\nPROVIDED PHOTOS (place each in its designated section):`)
    for (const sectionKey of stateSectionKeys) {
      const sectionLabel = sectionKey.replace(/([A-Z])/g, ' $1').replace(/^./, (s) => s.toUpperCase()).trim()
      promptParts.push(`- ${sectionLabel} section: Include [PROVIDED_PHOTO: ${sectionKey}] in that section's content.`)
    }
  }
  promptParts.push(`\n\nREQUIRED SECTIONS (use ONLY the exact data provided below; never invent):`)
  promptParts.push(`\n1. Grades / Report Card — List each course and grade exactly as provided.`)
  promptParts.push(`\n2. Attendance — Use the exact attendance statistics provided.`)
  promptParts.push(`\n3. Subjects / Curriculum — List the courses/subjects from the data.`)

  promptParts.push(`\n\nOPTIONAL SECTIONS (include ONLY if data was provided):`)
  if (instructorRemarks) {
    promptParts.push(`\n- Instructor Comments: ${instructorRemarks}`)
  }
  if (sectionData?.achievementsAndAwards) {
    promptParts.push(`\n- Student Achievements: ${sectionData.achievementsAndAwards}`)
  }
  if (sectionData?.serviceLog) {
    promptParts.push(`\n- Student Service: ${sectionData.serviceLog}`)
  }
  if (!instructorRemarks && !sectionData?.achievementsAndAwards && !sectionData?.serviceLog) {
    promptParts.push(`\n(No optional data provided—omit these sections.)`)
  }

  if (reportCardSnapshot) {
    try {
      const reportCard = JSON.parse(reportCardSnapshot)
      if (reportCard && Array.isArray(reportCard) && reportCard.length > 0) {
        promptParts.push(`\n\n--- GRADES DATA (use exactly) ---`)
        reportCard.forEach(course => {
          if (course.name && course.grade != null) {
            promptParts.push(`\n${course.name}: ${course.grade.toFixed(1)}%`)
          }
        })
      }
    } catch (_) {}
  }

  if (attendanceSummary) {
    promptParts.push(`\n\n--- ATTENDANCE DATA (use exactly) ---`)
    promptParts.push(`Classes Attended: ${attendanceSummary.classesAttended}`)
    promptParts.push(`Classes Missed: ${attendanceSummary.classesMissed}`)
    promptParts.push(`Attendance Rate: ${(attendanceSummary.average * 100).toFixed(1)}%`)
  }

  if (courses && courses.length > 0) {
    promptParts.push(`\n\n--- SUBJECTS/CURRICULUM DATA ---`)
    courses.forEach(course => {
      promptParts.push(`\n${course.name}` + (course.grade != null ? ` — Grade: ${course.grade.toFixed(1)}%` : ''))
    })
  }

  promptParts.push(`\n\nOutput a well-structured HTML document with clear section markers and readable typography. Use ONLY the data above. Do NOT invent, embellish, or add any information not provided.`)

  return promptParts.join('\n')
}

/**
 * Build the portfolio prompt for OpenAI (College or Family audience)
 * @param {Object} params - Portfolio parameters
 * @returns {string} Formatted prompt
 */
function buildPortfolioPrompt ({ studentName, audience, studentRemarks, instructorRemarks, reportCardSnapshot, studentWorkSummaries, attendanceSummary, courses, sectionData, providedPhotoBySection, textExcerpts }) {
  const a = (audience || 'family').toLowerCase()
  const isState = a === 'state' || a === 'state compliance' || a === 'statecompliance'

  if (isState) {
    return buildStateCompliancePrompt({ studentName, instructorRemarks, reportCardSnapshot, attendanceSummary, courses, sectionData, providedPhotoBySection: providedPhotoBySection || {} })
  }

  const promptParts = []

  promptParts.push(`Create a comprehensive, visually rich academic portfolio for ${studentName}.`)
  promptParts.push(`\n${getAudienceInstructions(audience)}`)
  promptParts.push(`\n\nOUTPUT FORMAT: You MUST output valid HTML only—no markdown. Start with <!DOCTYPE html><html><head><meta charset="utf-8"><style>...</style></head><body> and end with </body></html>. Use semantic HTML: <h1>, <h2>, <section>, <p>, <ul>, <li>.`)
  promptParts.push(`\n\n${getAudienceStylingInstructions(audience)}`)
  promptParts.push(`\n\nCRITICAL: Use ONLY facts and content provided below. Never invent, fabricate, or embellish information.`)
  promptParts.push(`\n\nIMPORTANT: The portfolio must include ALL of the following sections. Use the provided information where available, and enhance it appropriately for the audience—but never add made-up facts.`)
  const sectionKeysWithPhotos = Object.keys(providedPhotoBySection || {})
  if (sectionKeysWithPhotos.length > 0) {
    promptParts.push(`\n\nPROVIDED PHOTOS (place each in its designated section):`)
    for (const sectionKey of sectionKeysWithPhotos) {
      const sectionLabel = sectionKey.replace(/([A-Z])/g, ' $1').replace(/^./, (s) => s.toUpperCase()).trim()
      promptParts.push(`- ${sectionLabel} section: Include [PROVIDED_PHOTO: ${sectionKey}] in that section's content.`)
    }
    promptParts.push(`\nIMPORTANT: The sections above (${sectionKeysWithPhotos.join(', ')}) ALREADY have user-provided images. Do NOT add [IMAGE: description] to those sections—they already have images. Only use [IMAGE: description] for sections that do NOT have a provided photo.`)
  }
  const isCollege = a === 'college' || a === 'college admissions'
  if (isCollege) {
    const excludeNote = sectionKeysWithPhotos.length > 0 ? ` Do NOT use [IMAGE: description] in ${sectionKeysWithPhotos.join(', ')}—those sections already have provided photos. ` : ' '
    promptParts.push(`${excludeNote}Use [IMAGE: description] liberally in other sections—About Me, Achievements, Yearly Accomplishments, Extracurriculars, and Student Work Samples (only where no provided photo exists). Each [IMAGE: description] MUST be unique and highly specific to its section so the generated image matches correctly (e.g. "High school student at wooden desk studying math textbook, natural window light, academic setting" for one section; "Student receiving science fair award on stage, trophy, applause" for another). Never reuse the same description twice.`)
  } else {
    const excludeNote = sectionKeysWithPhotos.length > 0 ? ` Do NOT use [IMAGE: description] in sections that have provided photos (${sectionKeysWithPhotos.join(', ')}). ` : ' '
    promptParts.push(`${excludeNote}For other sections, use [IMAGE: description] as placeholders where they enhance the content. Each [IMAGE: description] MUST be unique and highly specific to its section—describe the exact scene, subject, and mood so the generated image matches that section. Never reuse the same description twice.`)
  }
  
  // About Me section
  if (sectionData?.aboutMe) {
    promptParts.push(`\n\n## About Me Section`)
    promptParts.push(`Use this provided information (do not invent additional details):`)
    promptParts.push(`${sectionData.aboutMe}`)
  } else {
    promptParts.push(`\n\n## About Me Section`)
    promptParts.push(`If no About Me data was provided, write only a brief neutral line such as "Portfolio for [student name]." Do NOT invent interests, goals, or personality.`)
  }
  
  // Achievements and Awards section
  if (sectionData?.achievementsAndAwards) {
    promptParts.push(`\n\n## Achievements and Awards Section`)
    promptParts.push(`Use this provided information (do not invent additional achievements):`)
    promptParts.push(`${sectionData.achievementsAndAwards}`)
  } else {
    promptParts.push(`\n\n## Achievements and Awards Section`)
    promptParts.push(`If no achievements data was provided, write "No additional achievements on file" or omit. Do NOT invent awards or recognitions.`)
  }
  
  // Attendance section
  promptParts.push(`\n\n## Attendance Section`)
  if (sectionData?.attendanceNotes) {
    promptParts.push(`Include these notes: ${sectionData.attendanceNotes}`)
  }
  if (attendanceSummary) {
    promptParts.push(`Include the attendance statistics: ${attendanceSummary.classesAttended} classes attended, ${attendanceSummary.classesMissed} missed, ${(attendanceSummary.average * 100).toFixed(1)}% attendance rate.`)
  }
  
  // Yearly Accomplishments by Subject
  promptParts.push(`\n\n## Yearly Accomplishments by Subject Section`)
  promptParts.push(`Summarize accomplishments using ONLY the course/assignment data provided below. Do NOT invent assignments, projects, or accomplishments.`)
  
  // Extracurricular Activities section
  if (sectionData?.extracurricularActivities) {
    promptParts.push(`\n\n## Extracurricular Activities Section`)
    promptParts.push(`Use this provided information (do not invent additional activities):`)
    promptParts.push(`${sectionData.extracurricularActivities}`)
  } else {
    promptParts.push(`\n\n## Extracurricular Activities Section`)
    promptParts.push(`If no extracurricular data was provided, write "No extracurricular activities on file" or omit. Do NOT invent clubs, sports, or interests.`)
  }
  
  // Report Card section
  promptParts.push(`\n\n## Report Card Section`)
  promptParts.push(`Include grades from the report card data below. Use ONLY the exact grades provided—do not invent or alter.`)
  
  // Service Log section
  if (sectionData?.serviceLog) {
    promptParts.push(`\n\n## Service Log Section`)
    promptParts.push(`Use this provided information (do not invent additional service):`)
    promptParts.push(`${sectionData.serviceLog}`)
  } else {
    promptParts.push(`\n\n## Service Log Section`)
    promptParts.push(`If no service log data was provided, write "No service hours on file" or omit. Do NOT invent community service or volunteer work.`)
  }

  if (studentRemarks) {
    promptParts.push(`\n\nStudent Remarks:\n${studentRemarks}`)
  }

  if (instructorRemarks) {
    promptParts.push(`\n\nInstructor Remarks:\n${instructorRemarks}`)
  }

  // Work file list (metadata only—do NOT describe or invent content for these)
  const workSummariesArr = Array.isArray(studentWorkSummaries)
    ? studentWorkSummaries
    : (typeof studentWorkSummaries === 'string' && studentWorkSummaries.length > 0 ? [studentWorkSummaries] : [])
  if (workSummariesArr.length > 0) {
    promptParts.push(`\n\nWork files on file (metadata only; do not invent or write descriptions of these):\n${workSummariesArr.join('\n')}`)
  }

  // Text excerpts = the ONLY source for the Student Work Samples section (real quotes only)
  if (textExcerpts && textExcerpts.length > 0) {
    promptParts.push(`\n\n--- STUDENT WORK SAMPLES SECTION (use only the content below) ---`)
    promptParts.push(`\nYou MUST include a section titled "## Student Work Samples". SELECT the most impactful and representative quotes from the text below. Choose quotes that: (1) best represent what each piece of work is about, (2) showcase the student's voice, insight, or achievement, (3) provide variety—include different subjects, types of thinking (analytical, creative, reflective), and strengths. Aim for quality over quantity. Attribute each quote to its source (e.g. "From [filename]: \"...\"" or "— [filename]"). Use ONLY real quotes—do NOT make up or invent content.`)
    promptParts.push(`\nActual text from the student's work (select the best excerpts for the Student Work Samples section):\n`)
    textExcerpts.forEach(({ fileName, text }) => {
      promptParts.push(`\n--- ${fileName} ---\n${text.substring(0, 6000)}\n`)
    })
  } else if (workSummariesArr.length > 0) {
    promptParts.push(`\n\nStudent Work Samples section: No text content was extracted from the work files (e.g. they may be images or non-text). Include a short line such as "Work samples are on file; see uploaded materials." Do NOT make up or invent descriptions of work samples.`)
  }

  if (reportCardSnapshot) {
    try {
      const reportCard = JSON.parse(reportCardSnapshot)
      if (reportCard && Array.isArray(reportCard) && reportCard.length > 0) {
        promptParts.push(`\n\nAcademic Performance (Report Card):`)
        reportCard.forEach(course => {
          if (course.name && course.grade != null) {
            promptParts.push(`- ${course.name}: ${course.grade.toFixed(1)}%`)
            if (course.assignments && course.assignments.length > 0) {
              const completedAssignments = course.assignments.filter(a => a.completed || a.pointsAwarded != null).length
              promptParts.push(`  (${completedAssignments} completed assignments)`)
            }
          }
        })
      }
    } catch (error) {
      console.warn('[ChatGPT Service] Error parsing report card snapshot:', error.message)
    }
  }

  if (attendanceSummary) {
    promptParts.push(`\n\nAttendance Summary:`)
    promptParts.push(`- Classes Attended: ${attendanceSummary.classesAttended}`)
    promptParts.push(`- Classes Missed: ${attendanceSummary.classesMissed}`)
    promptParts.push(`- Attendance Rate: ${(attendanceSummary.average * 100).toFixed(1)}%`)
    if (attendanceSummary.streakDays > 0) {
      promptParts.push(`- Current Attendance Streak: ${attendanceSummary.streakDays} days`)
    }
  }

  if (courses && courses.length > 0) {
    promptParts.push(`\n\nCourse Details for Yearly Accomplishments:`)
    courses.forEach(course => {
      promptParts.push(`- ${course.name}`)
      if (course.grade != null) {
        promptParts.push(`  Grade: ${course.grade.toFixed(1)}%`)
      }
      if (course.assignments && course.assignments.length > 0) {
        const gradedAssignments = course.assignments.filter(a => a.pointsAwarded != null && a.pointsPossible != null)
        if (gradedAssignments.length > 0) {
          promptParts.push(`  Notable Assignments: ${gradedAssignments.length} graded assignments`)
        }
      }
    })
  }

  promptParts.push(`\n\nPlease create a comprehensive, engaging portfolio with all required sections as valid HTML. Use <h2> for section titles, <p> for paragraphs, <ul>/<li> for lists. Include [IMAGE: description] and [PROVIDED_PHOTO: sectionKey] placeholders as specified above. Make the content detailed, positive, and reflective of the student's growth and achievements. Use ONLY the data provided—never invent facts, grades, achievements, or quotes. Output ONLY the HTML document—no markdown, no explanation.`)

  return promptParts.join('\n')
}

/**
 * Compile portfolio with OpenAI ChatGPT
 * @param {Object} params - Portfolio compilation parameters
 * @returns {Promise<{content: string, snippet: string}>}
 */
export async function compilePortfolioWithChatGPT ({ studentName, audience, studentWorkFiles, providedPhotoBySection, studentRemarks, instructorRemarks, reportCardSnapshot, attendanceSummary, courses, sectionData, textExcerpts }) {
  const startTime = Date.now()
  const providedPhotoCount = Object.keys(providedPhotoBySection || {}).length
  const apiKey = process.env.OPENAI_API_KEY
  const hasKey = !!apiKey && typeof apiKey === 'string' && apiKey.trim().length > 0 && apiKey.startsWith('sk-')

  if (!hasKey) {
    console.error('[ChatGPT Service] OPENAI_API_KEY is missing or invalid (must be set in .env and start with "sk-"). Using fallback compilation (no AI).')
    return getFallbackCompilation({ studentName, audience, studentWorkFiles, studentRemarks, instructorRemarks, reportCardSnapshot, attendanceSummary, courses, sectionData })
  }

  const openai = getOpenAI()
  if (!openai) {
    console.error('[ChatGPT Service] Could not create OpenAI client. Using fallback compilation.')
    return getFallbackCompilation({ studentName, audience, studentWorkFiles, studentRemarks, instructorRemarks, reportCardSnapshot, attendanceSummary, courses, sectionData })
  }

  try {
    console.log('[ChatGPT Service] Starting portfolio compilation with OpenAI', {
      studentName,
      audience: audience || 'family',
      workFilesCount: studentWorkFiles?.length || 0,
      providedPhotoCount: Object.keys(providedPhotoBySection || {}).length,
      timestamp: new Date().toISOString()
    })

    // Get work summaries
    const workSummaries = getWorkSummaries(studentWorkFiles || [])

    // Build the prompt
    const prompt = buildPortfolioPrompt({
      studentName,
      audience: audience || 'family',
      studentRemarks,
      instructorRemarks,
      reportCardSnapshot,
      studentWorkSummaries: workSummaries,
      attendanceSummary,
      courses,
      sectionData,
      providedPhotoBySection: providedPhotoBySection || {},
      textExcerpts
    })

    console.log('[ChatGPT Service] Sending request to OpenAI...', {
      promptLength: prompt.length,
      model: 'gpt-4o' // Using gpt-4o instead of gpt-5.1 (which doesn't exist)
    })

    // Call OpenAI API
    const openaiResponse = await openai.chat.completions.create({
      model: process.env.OPENAI_MODEL || 'gpt-4o', // Use gpt-4o (or gpt-3.5-turbo for cost savings)
      messages: [
        {
          role: 'system',
          content: 'You are an expert portfolio generator. Create academic portfolios from the data provided. Output ONLY valid HTML (no markdown)—start with <!DOCTYPE html><html> and end with </html>. Use semantic HTML: <h1>, <h2>, <section>, <p>, <ul>, <li>. Include a comprehensive <style> block—audience dictates styling: State Compliance = minimalist with section barriers, layout variety, font variety, alignment; Family/Keepsake = unified warm palette only (cream, ivory, terracotta—NO blue/teal/green), consistent section styling, cohesive album-like feel; College = professional advertisement / university viewbook style—deep navy/charcoal, premium typography, card-based layout with shadows, magazine-style image placement, aspirational and memorable. CRITICAL: Never invent, fabricate, or embellish facts. Use ONLY the exact data provided. For "Student Work Samples": use ONLY real quotes from the text provided. For [IMAGE: description]: each description MUST be unique and specific so the generated image matches that exact section—never reuse the same description. For [PROVIDED_PHOTO: sectionKey]: place in the section matching that key (e.g. [PROVIDED_PHOTO: aboutMe] in About Me). Never add [IMAGE: description] to a section that already has [PROVIDED_PHOTO: sectionKey]—those sections have user-provided images. LAYOUT: Never use float—it causes overlapping. Use block layout, flexbox, or grid for image/text placement.'
        },
        {
          role: 'user',
          content: prompt
        }
      ],
      temperature: 0.7,
      max_tokens: 4000
    })

    let portfolioText = openaiResponse.choices[0]?.message?.content

    if (!portfolioText) {
      throw new Error('No content returned from OpenAI')
    }

    const a = (audience || 'family').toLowerCase()
    const isState = a === 'state' || a === 'state compliance' || a === 'statecompliance'

    // State Compliance: no AI-generated images—strip [IMAGE: ...] only; keep [PROVIDED_PHOTO: n] for work samples
    if (isState) {
      portfolioText = portfolioText.replace(/\[IMAGE:\s*[^\]]*\]/g, '')
    }

    const duration = Date.now() - startTime
    console.log('[ChatGPT Service] Portfolio compilation completed', {
      duration: `${duration}ms`,
      contentLength: portfolioText.length,
      tokensUsed: openaiResponse.usage?.total_tokens,
      isStateCompliance: isState
    })

    // Extract image descriptions and generate images (skip for State Compliance)
    const imageDescriptionsWithContext = isState ? [] : extractImageDescriptionsWithContext(portfolioText)
    console.log('[ChatGPT Service] Found image placeholders:', imageDescriptionsWithContext.length)

    const generatedImages = []
    if (imageDescriptionsWithContext.length > 0) {
      try {
        console.log('[ChatGPT Service] Starting image generation for', imageDescriptionsWithContext.length, 'images')
        for (let i = 0; i < imageDescriptionsWithContext.length; i++) {
          const { description, sectionContext } = imageDescriptionsWithContext[i]
          console.log(`[ChatGPT Service] Generating image ${i + 1}/${imageDescriptionsWithContext.length}:`, description.substring(0, 50), sectionContext ? `(section: ${sectionContext})` : '')

          const imageStartTime = Date.now()
          const imageUrl = await generateImage(description, audience || 'family', sectionContext)
          const imageDuration = Date.now() - imageStartTime
          
          if (imageUrl) {
            generatedImages.push({
              description,
              url: imageUrl
            })
            console.log(`[ChatGPT Service] Image ${i + 1} generated successfully (${imageDuration}ms)`)
          } else {
            // Keep a slot so placeholder order matches; controller will fill with missing/placeholder
            generatedImages.push({
              description,
              url: '' // Failed; controller will assign missing slot so indices stay in sync
            })
            console.warn(`[ChatGPT Service] Image ${i + 1} generation failed, keeping slot for order`)
          }
          
          // Add a small delay between image generations to avoid rate limiting
          // DALL-E has rate limits, so we wait 2 seconds between requests
          if (i < imageDescriptionsWithContext.length - 1) {
            await new Promise(resolve => setTimeout(resolve, 2000))
          }
        }
        console.log('[ChatGPT Service] Image generation complete:', generatedImages.length, 'of', imageDescriptionsWithContext.length, 'images generated')
      } catch (error) {
        console.error('[ChatGPT Service] Error during image generation loop:', error)
        console.error('[ChatGPT Service] Continuing with', generatedImages.length, 'successfully generated images')
        // Continue with whatever images we have - partial success is better than total failure
      }
    }

    // Generate snippet (first 200 characters)
    const snippet = portfolioText.substring(0, 200) + (portfolioText.length > 200 ? '...' : '')

    return {
      content: portfolioText,
      snippet,
      images: generatedImages
    }
  } catch (error) {
    const duration = Date.now() - startTime
    const errMsg = error.message || String(error)
    console.error('[ChatGPT Service] Error compiling portfolio with OpenAI', {
      error: errMsg,
      errorType: error.constructor?.name,
      duration: `${duration}ms`,
      timestamp: new Date().toISOString()
    })
    if (error.status) console.error('[ChatGPT Service] HTTP status:', error.status)
    if (error.response?.data) console.error('[ChatGPT Service] API response:', JSON.stringify(error.response.data).slice(0, 500))
    if (error.code) console.error('[ChatGPT Service] Error code:', error.code)

    // Re-throw so the controller can surface this to the client instead of silent fallback
    throw new Error(`Portfolio AI failed: ${errMsg}`)
  }
}

/**
 * Fallback compilation when OpenAI is unavailable
 * @param {Object} params - Portfolio parameters
 * @returns {{content: string, snippet: string}}
 */
function getFallbackCompilation ({ studentName, audience, studentWorkFiles, studentRemarks, instructorRemarks, reportCardSnapshot, attendanceSummary, courses, sectionData }) {
  const a = (audience || 'family').toLowerCase()
  const isState = a === 'state' || a === 'state compliance' || a === 'statecompliance'
  const audienceLabel = (a === 'college' || a === 'college admissions') ? 'College Admissions' : isState ? 'State Compliance' : 'Portfolio'
  const parts = []
  const push = (html) => parts.push(html)

  push(`<!DOCTYPE html><html><head><meta charset="utf-8"><style>body{font-family:system-ui,sans-serif;max-width:800px;margin:0 auto;padding:24px;line-height:1.6;color:#333}h1,h2{color:#1a1a1a}h2{margin-top:2em;border-bottom:1px solid #eee;padding-bottom:.25em}p{margin:1em 0}ul{margin:1em 0;padding-left:1.5em}img{max-width:100%;height:auto;border-radius:8px;margin:1em 0}</style></head><body>`)
  push(`<h1>${escapeHtml(studentName)} - ${escapeHtml(audienceLabel)}</h1>`)

  if (isState) {
    // State Compliance: minimalist, data-only
    push(`<h2>Grades</h2>`)
    if (reportCardSnapshot) {
      try {
        const reportCard = JSON.parse(reportCardSnapshot)
        if (reportCard && Array.isArray(reportCard) && reportCard.length > 0) {
          push(`<ul>`)
          reportCard.forEach(course => {
            if (course.name && course.grade != null) {
              push(`<li>${escapeHtml(course.name)}: ${course.grade.toFixed(1)}%</li>`)
            }
          })
          push(`</ul>`)
        }
      } catch (_) {}
    }

    push(`<h2>Attendance</h2>`)
    if (attendanceSummary) {
      push(`<ul><li>Classes Attended: ${attendanceSummary.classesAttended}</li><li>Classes Missed: ${attendanceSummary.classesMissed}</li><li>Attendance Rate: ${(attendanceSummary.average * 100).toFixed(1)}%</li></ul>`)
    }
    if (sectionData?.attendanceNotes) push(`<p>${escapeHtml(sectionData.attendanceNotes)}</p>`)

    push(`<h2>Subjects / Curriculum</h2>`)
    if (courses && courses.length > 0) {
      push(`<ul>`)
      courses.forEach(course => {
        push(`<li>${escapeHtml(course.name)}${course.grade != null ? ` — ${course.grade.toFixed(1)}%` : ''}</li>`)
      })
      push(`</ul>`)
    }

    if (instructorRemarks) {
      push(`<h2>Instructor Comments</h2><p>${escapeHtml(instructorRemarks)}</p>`)
    }
    if (sectionData?.achievementsAndAwards) {
      push(`<h2>Student Achievements</h2><p>${escapeHtml(sectionData.achievementsAndAwards)}</p>`)
    }
    if (sectionData?.serviceLog) {
      push(`<h2>Student Service</h2><p>${escapeHtml(sectionData.serviceLog)}</p>`)
    }
  } else {
    // College / Family: full portfolio
    push(`<p>This portfolio showcases the academic achievements and work of ${escapeHtml(studentName)}.</p>`)
    push(`<h2>About Me</h2>`)
    push(`[IMAGE: Student photo or illustration]`)
    push(sectionData?.aboutMe ? `<p>${escapeHtml(sectionData.aboutMe)}</p>` : `<p>${escapeHtml(studentName)} is a dedicated student committed to academic excellence and personal growth.</p>`)

    if (studentRemarks) {
      push(`<h2>Student Remarks</h2><p>${escapeHtml(studentRemarks)}</p>`)
    }
    if (instructorRemarks) {
      push(`<h2>Instructor Remarks</h2><p>${escapeHtml(instructorRemarks)}</p>`)
    }

    push(`<h2>Achievements and Awards</h2>`)
    push(`[IMAGE: Awards or certificates]`)
    push(sectionData?.achievementsAndAwards ? `<p>${escapeHtml(sectionData.achievementsAndAwards)}</p>` : `<p>This section highlights the student's notable achievements and recognitions.</p>`)

    push(`<h2>Attendance</h2>`)
    push(`[IMAGE: Attendance chart or calendar]`)
    if (attendanceSummary) {
      push(`<ul><li>Classes Attended: ${attendanceSummary.classesAttended}</li><li>Classes Missed: ${attendanceSummary.classesMissed}</li><li>Attendance Rate: ${(attendanceSummary.average * 100).toFixed(1)}%</li>`)
      if (attendanceSummary.streakDays > 0) push(`<li>Current Streak: ${attendanceSummary.streakDays} days</li>`)
      push(`</ul>`)
    }
    if (sectionData?.attendanceNotes) push(`<p>${escapeHtml(sectionData.attendanceNotes)}</p>`)

    if (courses && courses.length > 0) {
      push(`<h2>Yearly Accomplishments by Subject</h2>`)
      courses.forEach(course => {
        push(`<h3>${escapeHtml(course.name)}</h3>`)
        push(`[IMAGE: Work sample from ${escapeHtml(course.name)}]`)
        if (course.grade != null) push(`<p>Grade: ${course.grade.toFixed(1)}%</p>`)
        if (course.assignments?.length) {
          const n = course.assignments.filter(a => a.completed || a.pointsAwarded != null).length
          push(`<p>Completed ${n} assignments.</p>`)
        }
      })
    }

    push(`<h2>Extracurricular Activities</h2>`)
    push(`[IMAGE: Extracurricular activities]`)
    push(sectionData?.extracurricularActivities ? `<p>${escapeHtml(sectionData.extracurricularActivities)}</p>` : `<p>This section showcases the student's involvement in activities outside of academics.</p>`)

    if (reportCardSnapshot) {
      try {
        const reportCard = JSON.parse(reportCardSnapshot)
        if (reportCard && Array.isArray(reportCard) && reportCard.length > 0) {
          push(`<h2>Report Card</h2>`)
          push(`[IMAGE: Report card visualization]`)
          push(`<ul>`)
          reportCard.forEach(course => {
            if (course.grade != null) push(`<li>${escapeHtml(course.name)}: ${course.grade.toFixed(1)}%</li>`)
          })
          push(`</ul>`)
        }
      } catch (_) {}
    }

    push(`<h2>Service Log</h2>`)
    push(`[IMAGE: Community service activities]`)
    push(sectionData?.serviceLog ? `<p>${escapeHtml(sectionData.serviceLog)}</p>` : `<p>This section documents the student's community service and volunteer work.</p>`)

    if (studentWorkFiles && studentWorkFiles.length > 0) {
      push(`<h2>Student Work Samples</h2>`)
      studentWorkFiles.forEach((file, index) => {
        push(`[IMAGE: ${escapeHtml(file.fileName)}]`)
        push(`<p>${index + 1}. ${escapeHtml(file.fileName)}</p>`)
      })
    }

    push(`<h2>Summary</h2>`)
    push(`<p>This portfolio represents the dedication and progress of ${escapeHtml(studentName)} throughout their academic journey.</p>`)
  }

  push(`</body></html>`)

  const compiledContent = parts.join('')
  const snippet = compiledContent.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim().substring(0, 200) + (compiledContent.length > 200 ? '...' : '')
  return { content: compiledContent, snippet }
}

function escapeHtml (s) {
  if (s == null) return ''
  const t = String(s)
  return t.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;')
}

