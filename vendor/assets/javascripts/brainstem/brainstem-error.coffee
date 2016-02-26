class Error extends Error

  constructor: (message) ->
    @name = 'BrainstemError'
    @message = (message || '')


modules.export = Error
