$ = require 'jquery'
_ = require 'underscore'

Collection = require '../collection'
AbstractLoader = require './abstract-loader'

knownResponseKeys = ['count', 'results', 'meta']

class CollectionLoader extends AbstractLoader

  #
  # Accessors

  getCollection: ->
    @externalObject


  #
  # Private

  # Accessors

  _getCollectionName: ->
    @loadOptions.name

  _getExpectationName: ->
    @_getCollectionName()

  _getModel: ->
    @internalObject.model

  _getModelsForAssociation: (association) ->
    @internalObject.map (m) => @_modelsOrObj(m.get(association))


  # Control

  _createObjects: ->
    @internalObject = @storageManager.createNewCollection @loadOptions.name, []

    @externalObject = @loadOptions.collection || @storageManager.createNewCollection @loadOptions.name, []
    @externalObject.setLoaded false
    @externalObject.reset([], silent: false) if @loadOptions.reset
    @externalObject.lastFetchOptions = _.pick($.extend(true, {}, @loadOptions), Collection.OPTION_KEYS)
    @externalObject.lastFetchOptions.include = @originalOptions.include

  _updateObjects: (object, data, silent = false) ->
    object.setLoaded true, trigger: false

    if data
      data = data.models if data.models?
      if object.length
        object.add data
      else
        object.reset data

    object.setLoaded true unless silent

  _updateStorageManagerFromResponse: (resp) ->
    # The server response should look something like this:
    #  {
    #    count: 200,
    #    results: [{ key: "tasks", id: 10 }, { key: "tasks", id: 11 }],
    #    time_entries: [{ id: 2, title: "te1", project_id: 6, task_id: [10, 11] }]
    #    projects: [{id: 6, title: "some project", time_entry_ids: [2] }]
    #    tasks: [{id: 10, title: "some task" }, {id: 11, title: "some other task" }]
    #    meta: {
    #      count: 200,
    #      page_number: 1,
    #      page_count: 10,
    #      page_size: 20
    #    }
    #  }
    # Loop over all returned data types and update our local storage to represent any new data.

    results = resp['results']
    keys = _.without(_.keys(resp), knownResponseKeys...)
    unless _.isEmpty(results)
      keys.splice(keys.indexOf(@loadOptions.name), 1) if keys.indexOf(@loadOptions.name) != -1
      keys.push(@loadOptions.name)

    for underscoredModelName in keys
      @storageManager.storage(underscoredModelName).update _(resp[underscoredModelName]).values()

    cachedData =
      count: resp.count
      results: results
      valid: true

    @storageManager.getCollectionDetails(@loadOptions.name).cache[@loadOptions.cacheKey] = cachedData
    _.map(results, (result) => @storageManager.storage(result.key).get(result.id))


module.exports = CollectionLoader
