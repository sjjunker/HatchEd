// Updated with assistance from Cursor (ChatGPT) on 11/7/25.

import OpenAI from 'openai'
import { AppError } from '../utils/errors.js'

// Initialize OpenAI client
const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY
})

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
  try {
    // Enhance prompt with design pattern context
    const enhancedPrompt = `Create a professional, academic portfolio illustration: ${description}. Style: ${designPattern.toLowerCase()}, clean and appropriate for an educational portfolio.`
    
    console.log('[ChatGPT Service] Generating image:', enhancedPrompt.substring(0, 100))
    
    const response = await openai.images.generate({
      model: 'dall-e-3',
      prompt: enhancedPrompt,
      size: '1024x1024',
      quality: 'standard',
      n: 1
    })
    
    const imageUrl = response.data[0]?.url
    if (imageUrl) {
      console.log('[ChatGPT Service] Image generated successfully')
      return imageUrl
    }
    
    return null
  } catch (error) {
    console.error('[ChatGPT Service] Error generating image:', error.message)
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
function buildPortfolioPrompt ({ studentName, designPattern, studentRemarks, instructorRemarks, reportCardSnapshot, studentWorkSummaries, attendanceSummary, courses, sectionData }) {
  const promptParts = []

  promptParts.push(`Create a comprehensive, visually rich academic portfolio for ${studentName}.`)
  promptParts.push(`\nDesign Pattern: ${designPattern}`)
  promptParts.push(`\n\nIMPORTANT: The portfolio must include ALL of the following sections. Use the provided information where available, and enhance it with engaging descriptions. Note where images should be placed (use [IMAGE: description] as placeholders for images).`)
  
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

  if (studentWorkSummaries && studentWorkSummaries.length > 0) {
    promptParts.push(`\n\nStudent Work Samples:\n${studentWorkSummaries.join('\n')}`)
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
export async function compilePortfolioWithChatGPT ({ studentName, designPattern, studentWorkFiles, studentRemarks, instructorRemarks, reportCardSnapshot, attendanceSummary, courses, sectionData }) {
  const startTime = Date.now()

  try {
    if (!process.env.OPENAI_API_KEY) {
      console.warn('[ChatGPT Service] OPENAI_API_KEY not set, using fallback compilation')
      return getFallbackCompilation({ studentName, designPattern, studentWorkFiles, studentRemarks, instructorRemarks, reportCardSnapshot })
    }

    console.log('[ChatGPT Service] Starting portfolio compilation with OpenAI', {
      studentName,
      designPattern,
      workFilesCount: studentWorkFiles?.length || 0,
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
      studentWorkSummaries: workSummaries.join('\n\n'),
      attendanceSummary,
      courses,
      sectionData
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
          content: 'You are an expert portfolio generator. Create comprehensive, engaging academic portfolios that highlight student achievements, growth, and progress. Use markdown formatting with clear sections (## for section titles). Include [IMAGE: description] placeholders throughout to indicate where images would enhance the content. Make the content detailed, positive, and reflective of the student\'s journey.'
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
        for (const description of imageDescriptions) {
          const imageUrl = await generateImage(description, designPattern)
          if (imageUrl) {
            generatedImages.push({
              description,
              url: imageUrl
            })
          }
        }
        console.log('[ChatGPT Service] Generated images:', generatedImages.length)
      } catch (error) {
        console.error('[ChatGPT Service] Error generating images:', error)
        // Continue without images if generation fails
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
    console.error('[ChatGPT Service] Error compiling portfolio with OpenAI', {
      error: error.message,
      errorType: error.constructor?.name,
      duration: `${duration}ms`,
      timestamp: new Date().toISOString()
    })

    // Fallback to basic compilation if OpenAI fails
    console.log('[ChatGPT Service] Falling back to basic compilation')
    return getFallbackCompilation({ studentName, designPattern, studentWorkFiles, studentRemarks, instructorRemarks, reportCardSnapshot, attendanceSummary, courses, sectionData })
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

