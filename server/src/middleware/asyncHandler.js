// Updated with assistance from Cursor (ChatGPT) on 11/7/25.

export function asyncHandler (fn) {
  return function wrapped (req, res, next) {
    Promise.resolve(fn(req, res, next)).catch((error) => {
      // Add request context to error for better logging
      if (!error.requestContext) {
        error.requestContext = {
          url: req.originalUrl,
          method: req.method,
          body: req.body,
          params: req.params,
          query: req.query
        }
      }
      next(error)
    })
  }
}

