window.Brainstem ?= {}

class window.Brainstem.Utils
  @makeErrorHandler: (oldhandler, params = {}) =>
    return -> oldhandler(params) if oldhandler && typeof(oldhandler) == 'function'

  @warn: (args...) ->
    console?.log "Error:", args...

  @throwError: (message) =>
    throw new Error("#{Backbone.history.getFragment()}: #{message}")

  @matchesArray: (array1, array2) ->
    return false unless array1.length == array2.length
    for index in [0...array1.length]
      if array1[index] instanceof Array && array2[index] instanceof Array
        return false unless matchesArray(array1[index], array2[index])
      else
        return false if String(array1[index]) != String(array2[index])
    true