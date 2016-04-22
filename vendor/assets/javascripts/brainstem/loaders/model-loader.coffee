window.Brainstem ?= {}

class Brainstem.ModelLoader extends Brainstem.AbstractLoader

  #
  # Accessors

  getModel: ->
    @externalObject


  #
  # Private

  # Accessors

  _getCollectionName: ->
    @loadOptions.name.pluralize()

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

    @internalObject = storage.get(id) || @storageManager.createNewModel(@loadOptions.name, id: id)
    @externalObject = model || @internalObject

  _updateStorageManagerFromResponse: (resp) ->
    attributes = @internalObject.parse(resp)
    # @externalObject.set(attributes)

  _updateObjects: (object, data) ->
    if _.isArray(data) && data.length == 1
      data = data[0]

    if data instanceof Backbone.Model
      data = data.attributes

    object.set(data)
