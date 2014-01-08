window.Brainstem ?= {}

class Brainstem.ModelLoader extends Brainstem.AbstractLoader
  _getCollectionName: ->
    @loadOptions.name.pluralize()

  _createObjects: ->
    id = @loadOptions.only[0]

    @internalObject = @storageManager.storage(@_getCollectionName()).get(id) || @storageManager.createNewModel(@loadOptions.name, id: id)
    @externalObject = @internalObject
    @externalObject.setLoaded false, trigger: false

  _updateStorageManagerFromResponse: (resp) ->
    @internalObject.parse(resp)

  _updateObjects: (object, data, silent = false) ->
    object.setLoaded true, trigger: false

    if _.isArray(data) && data.length == 1
      data = data[0]
    
    if data instanceof Backbone.Model
      data = data.attributes

    object.set(data)
    object.setLoaded true unless silent

  _getModel: ->
    @internalObject.constructor

  _getModelsForAssociation: (association) ->
    @_modelsOrObj(@internalObject.get(association))