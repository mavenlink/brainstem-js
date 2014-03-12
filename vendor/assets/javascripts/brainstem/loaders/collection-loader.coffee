window.Brainstem ?= {}

class Brainstem.CollectionLoader extends Brainstem.AbstractLoader
  getCollection: ->
    @externalObject

  _getCollectionName: ->
    @loadOptions.name

  _getExpectationName: ->
    @_getCollectionName()

  _createObjects: ->
    @internalObject = @storageManager.createNewCollection @loadOptions.name, []

    @externalObject = @loadOptions.collection || @storageManager.createNewCollection @loadOptions.name, []
    @externalObject.setLoaded false
    @externalObject.reset([], silent: false) if @loadOptions.reset
    @externalObject.lastFetchOptions = _.pick($.extend(true, {}, @loadOptions), 'name', 'filters', 'page', 'perPage', 'limit', 'offset', 'order', 'search')
    @externalObject.lastFetchOptions.include = @originalOptions.include

  _updateStorageManagerFromResponse: (resp) ->
    # The server response should look something like this:
    #  {
    #    count: 200,
    #    results: [{ key: "tasks", id: 10 }, { key: "tasks", id: 11 }],
    #    time_entries: [{ id: 2, title: "te1", project_id: 6, task_id: [10, 11] }]
    #    projects: [{id: 6, title: "some project", time_entry_ids: [2] }]
    #    tasks: [{id: 10, title: "some task" }, {id: 11, title: "some other task" }]
    #  }
    # Loop over all returned data types and update our local storage to represent any new data.

    results = resp['results']
    keys = _.reject(_.keys(resp), (key) -> key == 'count' || key == 'results')
    unless _.isEmpty(results)
      keys.splice(keys.indexOf(@loadOptions.name), 1) if keys.indexOf(@loadOptions.name) != -1
      keys.push(@loadOptions.name)

    for underscoredModelName in keys
      @storageManager.storage(underscoredModelName).update _(resp[underscoredModelName]).values()

    if @loadOptions.cache && !@loadOptions.only?
      cachedData =
        count: resp.count
        results: results

      @storageManager.getCollectionDetails(@loadOptions.name).cache[@loadOptions.cacheKey] = cachedData

    if @loadOptions.only?
      data = _.map(@loadOptions.only, (id) => @cachedCollection.get(id))
    else
      data = _.map(results, (result) => @storageManager.storage(result.key).get(result.id))

    data

  _updateObjects: (object, data, silent = false) ->
    object.setLoaded true, trigger: false

    if data
      data = data.models if data.models?
      if object.length
        object.add data
      else
        object.reset data

    object.setLoaded true unless silent

  _getModel: ->
    @internalObject.model

  _getModelsForAssociation: (association) ->
    @internalObject.map (m) => @_modelsOrObj(m.get(association))
