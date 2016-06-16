_ = require 'underscore'
Backbone = require 'backbone'
Backbone.$ = require 'jquery' # TODO remove after upgrading to backbone 1.2+

Error = require './error'


class Utils
  @warn: (args...) ->
    console?.log 'Error: ', args...

  @throwError: (message) ->
    fragment = try Backbone.history?.getFragment()
    message += ", fragment: #{fragment}" if fragment

    throw new Error(message)

  @matches: (object1, object2) ->
    if @empty(object1) && @empty(object2)
      true
    else if object1 instanceof Array && object2 instanceof Array
      obj1.length == obj2.length && _.every object1, (value, index) => @matches(value, object2[index])
    else if object1 instanceof Object && object2 instanceof Object
      obj1Keys = _(object1).keys()
      obj2Keys = _(object2).keys()
      obj1Keys.length == obj2Keys.length && _.every obj1Keys, (key) => @matches(object1[key], object2[key])
    else
      String(object1) == String(object2)

  @empty: (thing) ->
    if thing == null || thing == undefined || thing == ''
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
