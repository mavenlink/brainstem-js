class BrainstemError extends Error

  constructor: (message) ->
    @name = 'BrainstemError'
    @message = (message || '')


module.exports = Error
