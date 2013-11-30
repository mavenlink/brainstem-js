window.Brainstem ?= {}

class Brainstem.ModelLoader extends Brainstem.AbstractLoader
  getCollectionName: ->
    @loadOptions.name.pluralize()
    
  _createObjectReferences: ->
    @internalObject = @storageManager.createNewModel @loadOptions.name
    @externalObject = @loadOptions.model || @storageManager.createNewModel @loadOptions.name
    @externalObject.setLoaded false, trigger: false

    @internalObject.set('id', @loadOptions.only[0])
    @externalObject.set('id', @loadOptions.only[0])

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
