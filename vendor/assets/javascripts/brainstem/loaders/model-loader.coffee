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

    @internalObject = @storageManager.storage(@_getCollectionName()).get(id) ||
                      @storageManager.createNewModel(@loadOptions.name, id: id)
    @externalObject = @internalObject

  _updateStorageManagerFromResponse: (resp) ->
    @internalObject.parse(resp)

  _updateObjects: (object, data) ->
    if _.isArray(data) && data.length == 1
      data = data[0]
    
    if data instanceof Backbone.Model
      data = data.attributes

    object.set(data)
