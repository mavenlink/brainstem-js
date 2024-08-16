{ isArray } = require '../utility-functions'
Backbone = require 'backbone'
Backbone.$ = require 'jquery' # TODO remove after upgrading to backbone 1.2+
inflection = require 'inflection'

AbstractLoader = require './abstract-loader'


class ModelLoader extends AbstractLoader

  #
  # Accessors

  getModel: ->
    @externalObject


  #
  # Private

  # Accessors

  _getCollectionName: ->
    @loadOptions.name = inflection.pluralize(@loadOptions.name)

  _getExpectationName: ->
    @loadOptions.name

  _getModel: ->
    @internalObject.constructor

  _getModelsForAssociation: (association) ->
    @_modelsOrObj(@internalObject.get(association))


  # Control

  _createObjects: ->
    id = @loadOptions.only[0]
    storage = @storageManager.storage(@_getCollectionName())
    model = @loadOptions.model

    storage.add(model, remove: false) if model && model.id

    @internalObject =
    @externalObject = storage.get(id) || @storageManager.createNewModel(@loadOptions.name, id: id)

  _updateStorageManagerFromResponse: (resp) ->
    attributes = @internalObject.parse(resp)

  _updateObjects: (object, data) ->
    if isArray(data) && data.length == 1
      data = data[0]

    if data instanceof Backbone.Model
      data = data.attributes

    object.set(data)


module.exports = ModelLoader
