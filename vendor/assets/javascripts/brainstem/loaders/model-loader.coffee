window.Brainstem ?= {}

class Brainstem.ModelLoader extends Brainstem.AbstractLoader
  _getCollectionName: ->
    @loadOptions.name.pluralize()

  _createObjects: ->
    id = @loadOptions.only[0]

    cachedModel = @storageManager.storage(@_getCollectionName()).get(id)

    if cachedModel && @loadOptions.model && cachedModel != @loadOptions.model
      throw "model already in storage manager"

    @internalObject = @storageManager.createNewModel @loadOptions.name
    @internalObject.set('id', id)

    @externalObject = @loadOptions.model || @storageManager.createNewModel @loadOptions.name
    @externalObject.setLoaded false, trigger: false
    @externalObject.set('id', id)

  _updateStorageManagerFromResponse: (resp) ->
    @internalObject.parse(resp)

  _updateObjects: (object, data) ->
    object.setLoaded true, trigger: false

    if _.isArray(data) && data.length == 1
      data = data[0]
    
    if data instanceof Backbone.Model
      data = data.attributes

    object.set(data)
    object.setLoaded true

  _getModel: ->
    @internalObject.constructor

  _getModelsForAssociation: (association) ->
    @_modelsOrObj(@internalObject.get(association))