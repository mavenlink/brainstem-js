Error = require('./error')


class Utils
  @warn: (args...) ->
    console?.log "Error:", args...

  @throwError: (message) ->
    message = "#{message}"
    fragment = try Backbone.history?.getFragment()

    message += ", fragment: #{fragment}" if fragment

    throw new Error(message)

  @matches: (obj1, obj2) ->
    if @empty(obj1) && @empty(obj2)
      true
    else if obj1 instanceof Array && obj2 instanceof Array
      obj1.length == obj2.length && _.every obj1, (value, index) => @matches(value, obj2[index])
    else if obj1 instanceof Object && obj2 instanceof Object
      obj1Keys = _(obj1).keys()
      obj2Keys = _(obj2).keys()
      obj1Keys.length == obj2Keys.length && _.every obj1Keys, (key) => @matches(obj1[key], obj2[key])
    else
      String(obj1) == String(obj2)

  @empty: (thing) ->
    if thing == null || thing == undefined || thing == ""
      true
    if thing instanceof Array
      thing.length == 0 || thing.length == 1 && @empty(thing[0])
    else if thing instanceof Object
      _.keys(thing).length == 0
    else
      false

  @extractArray: (option, options) ->
    result = options[option]
    result = [result] unless result instanceof Array
    _.compact(result)

  @wrapObjects: (array) ->
    output = []
    _(array).each (elem) =>
      if elem.constructor == Object
        for key, value of elem
          o = {}
          o[key] = @wrapObjects(if value instanceof Array then value else [value])
          output.push o
      else
        o = {}
        o[elem] = []
        output.push o
    output

  @wrapError = (collection, options) ->
    error = options.error
    options.error = (response) ->
      error(collection, response, options) if error
      collection.trigger('error', collection, response, options)


module.exports = Utils
