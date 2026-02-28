import { getDailyQuoteShared } from '../services/quoteService.js'

export async function getDailyQuoteHandler (_req, res) {
  try {
    const quote = await getDailyQuoteShared()
    res.json({ quote })
  } catch (error) {
    if (error.code === 'QUOTE_API_KEY_MISSING') {
      return res.status(500).json({
        error: { message: 'Quote service is not configured. Set API_NINJAS_KEY on the server.' }
      })
    }

    return res.status(502).json({
      error: { message: 'Unable to fetch daily quote right now.' }
    })
  }
}

