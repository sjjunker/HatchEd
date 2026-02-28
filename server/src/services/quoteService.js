const API_NINJAS_DAILY_QUOTE_URL = 'https://api.api-ninjas.com/v2/quoteoftheday'

let cachedDayKey = null
let cachedQuote = null

function utcDayKey (date = new Date()) {
  return date.toISOString().slice(0, 10)
}

function normalizeQuote (payload) {
  const raw = Array.isArray(payload) ? payload[0] : payload
  if (!raw || typeof raw !== 'object') {
    throw new Error('Daily quote API returned an unexpected response format.')
  }

  const quoteText = typeof raw.quote === 'string' ? raw.quote.trim() : ''
  if (!quoteText) {
    throw new Error('Daily quote API returned an empty quote.')
  }

  return {
    quote: quoteText,
    author: typeof raw.author === 'string' && raw.author.trim() ? raw.author.trim() : null,
    work: typeof raw.work === 'string' && raw.work.trim() ? raw.work.trim() : null,
    categories: Array.isArray(raw.categories) ? raw.categories.filter(item => typeof item === 'string') : [],
    dayKey: utcDayKey()
  }
}

async function fetchQuoteFromProvider () {
  const apiKey = process.env.API_NINJAS_KEY
  if (!apiKey || !apiKey.trim()) {
    const error = new Error('API_NINJAS_KEY is not configured.')
    error.code = 'QUOTE_API_KEY_MISSING'
    throw error
  }

  const response = await fetch(API_NINJAS_DAILY_QUOTE_URL, {
    method: 'GET',
    headers: {
      Accept: 'application/json',
      'X-Api-Key': apiKey
    }
  })

  if (!response.ok) {
    const body = await response.text()
    const error = new Error(`Daily quote provider request failed (${response.status}). ${body}`.trim())
    error.code = 'QUOTE_PROVIDER_FAILED'
    throw error
  }

  const payload = await response.json()
  return normalizeQuote(payload)
}

export async function getDailyQuoteShared () {
  const today = utcDayKey()
  if (cachedDayKey === today && cachedQuote) {
    return cachedQuote
  }

  const freshQuote = await fetchQuoteFromProvider()
  cachedDayKey = today
  cachedQuote = freshQuote
  return freshQuote
}

