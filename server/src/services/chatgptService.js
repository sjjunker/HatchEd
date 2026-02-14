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
 * Extract image descriptions from portfolio content
 * @param {string} content - Portfolio content with [IMAGE: description] placeholders
 * @returns {Array<string>} Array of image descriptions
 */
function extractImageDescriptions (content) {
  const descriptions = []
  const imageRegex = /\[IMAGE:\s*([^\]]+)\]/g
  let match
  
  while ((match = imageRegex.exec(content)) !== null) {
    descriptions.push(match[1].trim())
  }
  
  return descriptions
}

/**
 * Generate an image using DALL-E based on description
 * @param {string} description - Image description
 * @param {string} designPattern - Portfolio design pattern for style consistency
 * @returns {Promise<string|null>} Image URL or null if generation fails
 */
async function generateImage (description, designPattern) {
  const openai = getOpenAI()
  if (!openai) return null
  try {
    // Enhance prompt with design pattern context
    const enhancedPrompt = `Create a professional, academic portfolio illustration: ${description}. Style: ${designPattern.toLowerCase()}, clean and appropriate for an educational portfolio.`
    
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
 * Build the portfolio prompt for OpenAI
 * @param {Object} params - Portfolio parameters
 * @returns {string} Formatted prompt
 */
function buildPortfolioPrompt ({ studentName, designPattern, studentRemarks, instructorRemarks, reportCardSnapshot, studentWorkSummaries, attendanceSummary, courses, sectionData, providedPhotoCount, textExcerpts }) {
  const promptParts = []

  promptParts.push(`Create a comprehensive, visually rich academic portfolio for ${studentName}.`)
  promptParts.push(`\nDesign Pattern: ${designPattern}`)
  promptParts.push(`\n\nIMPORTANT: The portfolio must include ALL of the following sections. Use the provided information where available, and enhance it with engaging descriptions.`)
  if (providedPhotoCount > 0) {
    promptParts.push(` The parent has provided ${providedPhotoCount} photo(s) to include. Use the placeholder [PROVIDED_PHOTO: 1] through [PROVIDED_PHOTO: ${providedPhotoCount}] in the portfolio where those photos would fit (e.g. About Me, Achievements, work samples). Use these instead of [IMAGE: ...] for those slots.`)
  }
  promptParts.push(` For any other image slots use [IMAGE: description] as placeholders.`)
  
  // About Me section
  if (sectionData?.aboutMe) {
    promptParts.push(`\n\n## About Me Section`)
    promptParts.push(`Use this provided information and enhance it professionally:`)
    promptParts.push(`${sectionData.aboutMe}`)
  } else {
    promptParts.push(`\n\n## About Me Section`)
    promptParts.push(`Create a personal introduction highlighting the student's interests, goals, and personality.`)
  }
  
  // Achievements and Awards section
  if (sectionData?.achievementsAndAwards) {
    promptParts.push(`\n\n## Achievements and Awards Section`)
    promptParts.push(`Use this provided information and enhance it professionally:`)
    promptParts.push(`${sectionData.achievementsAndAwards}`)
  } else {
    promptParts.push(`\n\n## Achievements and Awards Section`)
    promptParts.push(`List and describe all academic achievements, awards, recognitions, and honors.`)
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
  promptParts.push(`Create detailed accomplishments for each course/subject taken.`)
  
  // Extracurricular Activities section
  if (sectionData?.extracurricularActivities) {
    promptParts.push(`\n\n## Extracurricular Activities Section`)
    promptParts.push(`Use this provided information and enhance it professionally:`)
    promptParts.push(`${sectionData.extracurricularActivities}`)
  } else {
    promptParts.push(`\n\n## Extracurricular Activities Section`)
    promptParts.push(`List all extracurricular activities, clubs, sports, and interests.`)
  }
  
  // Report Card section
  promptParts.push(`\n\n## Report Card Section`)
  promptParts.push(`Include the academic performance summary.`)
  
  // Service Log section
  if (sectionData?.serviceLog) {
    promptParts.push(`\n\n## Service Log Section`)
    promptParts.push(`Use this provided information and enhance it professionally:`)
    promptParts.push(`${sectionData.serviceLog}`)
  } else {
    promptParts.push(`\n\n## Service Log Section`)
    promptParts.push(`Document community service, volunteer work, and service learning activities.`)
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
    promptParts.push(`\nYou MUST include a section titled "## Student Work Samples". In that section, use ONLY real quotes or short excerpts from the text below. Attribute each quote to its source (e.g. "From [filename]: \"...\"" or "— [filename]"). Do NOT make up work sample descriptions. Do NOT describe or invent content for work samples. If you use a quote, it must appear in the text below.`)
    promptParts.push(`\nActual text from the student's work (use only these for the Student Work Samples section):\n`)
    textExcerpts.forEach(({ fileName, text }) => {
      promptParts.push(`\n--- ${fileName} ---\n${text.substring(0, 4000)}\n`)
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

  promptParts.push(`\n\nPlease create a comprehensive, engaging portfolio with all required sections. Use markdown formatting with clear headings (## for section titles). Include [IMAGE: description] placeholders throughout to indicate where images would enhance the content. Make the content detailed, positive, and reflective of the student's growth and achievements.`)

  return promptParts.join('\n')
}

/**
 * Compile portfolio with OpenAI ChatGPT
 * @param {Object} params - Portfolio compilation parameters
 * @returns {Promise<{content: string, snippet: string}>}
 */
export async function compilePortfolioWithChatGPT ({ studentName, designPattern, studentWorkFiles, providedPhotoWorkFiles, studentRemarks, instructorRemarks, reportCardSnapshot, attendanceSummary, courses, sectionData, textExcerpts }) {
  const startTime = Date.now()
  const providedPhotoCount = providedPhotoWorkFiles?.length ?? 0
  const apiKey = process.env.OPENAI_API_KEY
  const hasKey = !!apiKey && typeof apiKey === 'string' && apiKey.trim().length > 0 && apiKey.startsWith('sk-')

  if (!hasKey) {
    console.error('[ChatGPT Service] OPENAI_API_KEY is missing or invalid (must be set in .env and start with "sk-"). Using fallback compilation (no AI).')
    return getFallbackCompilation({ studentName, designPattern, studentWorkFiles, studentRemarks, instructorRemarks, reportCardSnapshot, attendanceSummary, courses, sectionData })
  }

  const openai = getOpenAI()
  if (!openai) {
    console.error('[ChatGPT Service] Could not create OpenAI client. Using fallback compilation.')
    return getFallbackCompilation({ studentName, designPattern, studentWorkFiles, studentRemarks, instructorRemarks, reportCardSnapshot, attendanceSummary, courses, sectionData })
  }

  try {
    console.log('[ChatGPT Service] Starting portfolio compilation with OpenAI', {
      studentName,
      designPattern,
      workFilesCount: studentWorkFiles?.length || 0,
      providedPhotoCount,
      timestamp: new Date().toISOString()
    })

    // Get work summaries
    const workSummaries = getWorkSummaries(studentWorkFiles || [])

    // Build the prompt
    const prompt = buildPortfolioPrompt({
      studentName,
      designPattern,
      studentRemarks,
      instructorRemarks,
      reportCardSnapshot,
      studentWorkSummaries: workSummaries,
      attendanceSummary,
      courses,
      sectionData,
      providedPhotoCount,
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
          content: 'You are an expert portfolio generator. Create comprehensive, engaging academic portfolios that highlight student achievements, growth, and progress. Use markdown formatting with clear sections (## for section titles). For the "Student Work Samples" section: use only real quotes or excerpts from the text the user provides; never make up or invent work sample descriptions. Include [IMAGE: description] placeholders where images would enhance the content. Make the content detailed, positive, and reflective of the student\'s journey.'
        },
        {
          role: 'user',
          content: prompt
        }
      ],
      temperature: 0.7,
      max_tokens: 4000
    })

    const portfolioText = openaiResponse.choices[0]?.message?.content

    if (!portfolioText) {
      throw new Error('No content returned from OpenAI')
    }

    const duration = Date.now() - startTime
    console.log('[ChatGPT Service] Portfolio compilation completed', {
      duration: `${duration}ms`,
      contentLength: portfolioText.length,
      tokensUsed: openaiResponse.usage?.total_tokens
    })

    // Extract image descriptions and generate images
    const imageDescriptions = extractImageDescriptions(portfolioText)
    console.log('[ChatGPT Service] Found image placeholders:', imageDescriptions.length)
    
    const generatedImages = []
    if (imageDescriptions.length > 0) {
      try {
        console.log('[ChatGPT Service] Starting image generation for', imageDescriptions.length, 'images')
        for (let i = 0; i < imageDescriptions.length; i++) {
          const description = imageDescriptions[i]
          console.log(`[ChatGPT Service] Generating image ${i + 1}/${imageDescriptions.length}:`, description.substring(0, 50))
          
          const imageStartTime = Date.now()
          const imageUrl = await generateImage(description, designPattern)
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
          if (i < imageDescriptions.length - 1) {
            await new Promise(resolve => setTimeout(resolve, 2000))
          }
        }
        console.log('[ChatGPT Service] Image generation complete:', generatedImages.length, 'of', imageDescriptions.length, 'images generated')
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
function getFallbackCompilation ({ studentName, designPattern, studentWorkFiles, studentRemarks, instructorRemarks, reportCardSnapshot, attendanceSummary, courses, sectionData }) {
  const portfolioSections = []

  // Introduction
  portfolioSections.push(`# ${studentName} - ${designPattern} Portfolio\n\n`)
  portfolioSections.push(`This portfolio showcases the academic achievements and work of ${studentName}.\n\n`)

  // About Me
  portfolioSections.push(`## About Me\n\n`)
  portfolioSections.push(`[IMAGE: Student photo or illustration]\n\n`)
  if (sectionData?.aboutMe) {
    portfolioSections.push(`${sectionData.aboutMe}\n\n`)
  } else {
    portfolioSections.push(`${studentName} is a dedicated student committed to academic excellence and personal growth. This portfolio represents their journey, achievements, and progress throughout the academic year.\n\n`)
  }

  // Student Remarks
  if (studentRemarks) {
    portfolioSections.push(`## Student Remarks\n\n${studentRemarks}\n\n`)
  }

  // Instructor Remarks
  if (instructorRemarks) {
    portfolioSections.push(`## Instructor Remarks\n\n${instructorRemarks}\n\n`)
  }

  // Achievements and Awards
  portfolioSections.push(`## Achievements and Awards\n\n`)
  portfolioSections.push(`[IMAGE: Awards or certificates]\n\n`)
  if (sectionData?.achievementsAndAwards) {
    portfolioSections.push(`${sectionData.achievementsAndAwards}\n\n`)
  } else {
    portfolioSections.push(`This section highlights the student's notable achievements and recognitions.\n\n`)
  }

  // Attendance
  portfolioSections.push(`## Attendance\n\n`)
  portfolioSections.push(`[IMAGE: Attendance chart or calendar]\n\n`)
  if (attendanceSummary) {
    portfolioSections.push(`- Classes Attended: ${attendanceSummary.classesAttended}\n`)
    portfolioSections.push(`- Classes Missed: ${attendanceSummary.classesMissed}\n`)
    portfolioSections.push(`- Attendance Rate: ${(attendanceSummary.average * 100).toFixed(1)}%\n`)
    if (attendanceSummary.streakDays > 0) {
      portfolioSections.push(`- Current Attendance Streak: ${attendanceSummary.streakDays} days\n`)
    }
  }
  if (sectionData?.attendanceNotes) {
    portfolioSections.push(`\n${sectionData.attendanceNotes}\n`)
  }
  portfolioSections.push(`\n`)

  // Yearly Accomplishments by Subject
  if (courses && courses.length > 0) {
    portfolioSections.push(`## Yearly Accomplishments by Subject\n\n`)
    courses.forEach(course => {
      portfolioSections.push(`### ${course.name}\n\n`)
      portfolioSections.push(`[IMAGE: Work sample from ${course.name}]\n\n`)
      if (course.grade != null) {
        portfolioSections.push(`Grade: ${course.grade.toFixed(1)}%\n\n`)
      }
      if (course.assignments && course.assignments.length > 0) {
        const completedAssignments = course.assignments.filter(a => a.completed || a.pointsAwarded != null)
        portfolioSections.push(`Completed ${completedAssignments.length} assignments in this course.\n\n`)
      }
    })
  }

  // Extracurricular Activities
  portfolioSections.push(`## Extracurricular Activities\n\n`)
  portfolioSections.push(`[IMAGE: Extracurricular activities]\n\n`)
  if (sectionData?.extracurricularActivities) {
    portfolioSections.push(`${sectionData.extracurricularActivities}\n\n`)
  } else {
    portfolioSections.push(`This section showcases the student's involvement in activities outside of academics.\n\n`)
  }

  // Report Card
  if (reportCardSnapshot) {
    try {
      const reportCard = JSON.parse(reportCardSnapshot)
      if (reportCard && Array.isArray(reportCard) && reportCard.length > 0) {
        portfolioSections.push(`## Report Card\n\n`)
        portfolioSections.push(`[IMAGE: Report card visualization]\n\n`)
        reportCard.forEach(course => {
          if (course.grade != null) {
            portfolioSections.push(`- ${course.name}: ${course.grade.toFixed(1)}%\n`)
          }
        })
        portfolioSections.push(`\n`)
      }
    } catch (error) {
      console.error('Error parsing report card snapshot:', error)
    }
  }

  // Service Log
  portfolioSections.push(`## Service Log\n\n`)
  portfolioSections.push(`[IMAGE: Community service activities]\n\n`)
  if (sectionData?.serviceLog) {
    portfolioSections.push(`${sectionData.serviceLog}\n\n`)
  } else {
    portfolioSections.push(`This section documents the student's community service and volunteer work.\n\n`)
  }

  // Student Work
  if (studentWorkFiles && studentWorkFiles.length > 0) {
    portfolioSections.push(`## Student Work Samples\n\n`)
    studentWorkFiles.forEach((file, index) => {
      portfolioSections.push(`[IMAGE: ${file.fileName}]\n\n`)
      portfolioSections.push(`${index + 1}. ${file.fileName}\n\n`)
    })
  }

  // Conclusion
  portfolioSections.push(`## Summary\n\n`)
  portfolioSections.push(`This portfolio represents the dedication and progress of ${studentName} throughout their academic journey.\n`)

  const compiledContent = portfolioSections.join('')
  const snippet = compiledContent.substring(0, 200) + (compiledContent.length > 200 ? '...' : '')

  return {
    content: compiledContent,
    snippet
  }
}

