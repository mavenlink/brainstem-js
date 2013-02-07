window.Brainstem ?= {}

class window.Brainstem.Utils
  @makeErrorHandler: (oldhandler, params = {}) =>
    return -> oldhandler(params) if oldhandler && typeof(oldhandler) == 'function'

  @warn: (args...) ->
    console?.log "Error:", args...

  @throwError: (message) =>
    throw new Error("#{Backbone.hitask.getFragment()}: #{message}")
