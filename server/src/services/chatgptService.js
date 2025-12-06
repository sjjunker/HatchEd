// Updated with assistance from Cursor (ChatGPT) on 11/7/25.

import OpenAI from 'openai'
import { AppError } from '../utils/errors.js'

// Initialize OpenAI client
const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY
})

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
function buildPortfolioPrompt ({ studentName, designPattern, studentRemarks, instructorRemarks, reportCardSnapshot, studentWorkSummaries }) {
  const promptParts = []

  promptParts.push(`Create a comprehensive academic portfolio for ${studentName}.`)
  promptParts.push(`\nDesign Pattern: ${designPattern}`)

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
        promptParts.push(`\n\nAcademic Performance:`)
        reportCard.forEach(course => {
          if (course.name && course.grade != null) {
            promptParts.push(`- ${course.name}: ${course.grade.toFixed(1)}%`)
          }
        })
      }
    } catch (error) {
      console.warn('[ChatGPT Service] Error parsing report card snapshot:', error.message)
    }
  }

  promptParts.push(`\n\nPlease create a well-structured, professional portfolio that highlights the student's achievements, growth, and academic progress. Use markdown formatting with appropriate headings, sections, and formatting.`)

  return promptParts.join('\n')
}

/**
 * Compile portfolio with OpenAI ChatGPT
 * @param {Object} params - Portfolio compilation parameters
 * @returns {Promise<{content: string, snippet: string}>}
 */
export async function compilePortfolioWithChatGPT ({ studentName, designPattern, studentWorkFiles, studentRemarks, instructorRemarks, reportCardSnapshot }) {
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
      studentWorkSummaries: workSummaries.join('\n\n')
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
          content: 'You are an expert portfolio generator. Create professional, well-structured academic portfolios that highlight student achievements, growth, and progress. Use markdown formatting with clear sections and appropriate headings.'
        },
        {
          role: 'user',
          content: prompt
        }
      ],
      temperature: 0.7,
      max_tokens: 2000
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

    // Generate snippet (first 200 characters)
    const snippet = portfolioText.substring(0, 200) + (portfolioText.length > 200 ? '...' : '')

    return {
      content: portfolioText,
      snippet
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
    return getFallbackCompilation({ studentName, designPattern, studentWorkFiles, studentRemarks, instructorRemarks, reportCardSnapshot })
  }
}

/**
 * Fallback compilation when OpenAI is unavailable
 * @param {Object} params - Portfolio parameters
 * @returns {{content: string, snippet: string}}
 */
function getFallbackCompilation ({ studentName, designPattern, studentWorkFiles, studentRemarks, instructorRemarks, reportCardSnapshot }) {
  const portfolioSections = []

  // Introduction
  portfolioSections.push(`# ${studentName} - ${designPattern} Portfolio\n\n`)
  portfolioSections.push(`This portfolio showcases the academic achievements and work of ${studentName}.\n\n`)

  // Student Remarks
  if (studentRemarks) {
    portfolioSections.push(`## Student Remarks\n\n${studentRemarks}\n\n`)
  }

  // Instructor Remarks
  if (instructorRemarks) {
    portfolioSections.push(`## Instructor Remarks\n\n${instructorRemarks}\n\n`)
  }

  // Student Work
  if (studentWorkFiles && studentWorkFiles.length > 0) {
    portfolioSections.push(`## Student Work Samples\n\n`)
    studentWorkFiles.forEach((file, index) => {
      portfolioSections.push(`${index + 1}. ${file.fileName}\n`)
    })
    portfolioSections.push(`\n`)
  }

  // Report Card
  if (reportCardSnapshot) {
    try {
      const reportCard = JSON.parse(reportCardSnapshot)
      if (reportCard && reportCard.length > 0) {
        portfolioSections.push(`## Academic Performance\n\n`)
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

