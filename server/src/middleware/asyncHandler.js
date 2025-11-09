// Updated with assistance from Cursor (ChatGPT) on 11/7/25.

export function asyncHandler (fn) {
  return function wrapped (req, res, next) {
    Promise.resolve(fn(req, res, next)).catch(next)
  }
}

