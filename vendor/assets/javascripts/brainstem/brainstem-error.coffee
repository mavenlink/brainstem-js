window.Brainstem ?= {}

class Brainstem.Error extends Error

  constructor: (message) ->
    @name = 'BrainstemError'
    @message = (message || '')
