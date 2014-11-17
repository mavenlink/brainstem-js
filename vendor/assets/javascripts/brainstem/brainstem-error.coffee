window.Brainstem ?= {}

class window.Brainstem.Error extends Error

  constructor: (message) ->
    @name = 'BrainstemError'
    @message = (message || '')
