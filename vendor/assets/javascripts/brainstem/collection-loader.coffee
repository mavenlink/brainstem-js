window.Brainstem ?= {}

class Brainstem.CollectionLoader
  constructor: (options = {}) ->
    @storageManager = options.storageManager

    if options.loadOptions
      @setup(options.loadOptions)

  setup: (loadOptions) ->
    @_parseLoadOptions(loadOptions)
    @_createCollectionReferences()
    @_interceptOldSuccess()
    @_calculateAdditionalIncludes()

  load: ->
    if not @loadOptions
      throw "You must call #setup first or pass loadOptions into the constructor"

    # Check the cache to see if we have everything that we need.
    if collection = @_checkCacheForData()
      return collection

    # If we didn't return the collection from the cache, we need to go to the server to load some missing data.
    modelOrCollection = @internalCollection
    modelOrCollection = @loadOptions.model if @loadOptions.only && @loadOptions.model
    
    jqXhr = Backbone.sync.call @internalCollection, 'read', modelOrCollection, @_buildSyncOptions()

    if @loadOptions.returnValues
      @loadOptions.returnValues.jqXhr = jqXhr

    @externalCollection

  _parseLoadOptions: (loadOptions) ->
    @loadOptions = $.extend {}, loadOptions
    @loadOptions.plainInclude = @loadOptions.include
    @loadOptions.include = Brainstem.Utils.wrapObjects(Brainstem.Utils.extractArray "include", @loadOptions)
    @loadOptions.only = if @loadOptions.only then _.map((Brainstem.Utils.extractArray "only", @loadOptions), (id) -> String(id)) else null
    @loadOptions.filters ?= {}
    @loadOptions.thisLayerInclude = _(@loadOptions.include).map((i) -> _.keys(i)[0]) # pull off the top layer of includes

    # Build cache key
    filterKeys = _.map(@loadOptions.filters, (v, k) -> "#{k}:#{v}").join(',')
    @loadOptions.cacheKey = [@loadOptions.order || "updated_at:desc", filterKeys, @loadOptions.page, @loadOptions.perPage, @loadOptions.limit, @loadOptions.offset].join('|')

  _interceptOldSuccess: ->
    externalSuccess = @loadOptions.success
    @loadOptions.success = =>
      @_updateCollection(@externalCollection, @internalCollection)
      externalSuccess(@externalCollection) if externalSuccess

  _createCollectionReferences: ->
    @cachedCollection = @storageManager.storage @loadOptions.name
    @internalCollection = @storageManager.createNewCollection @loadOptions.name, []

    @externalCollection = @loadOptions.collection || @storageManager.createNewCollection @loadOptions.name, []
    @externalCollection.setLoaded false
    @externalCollection.reset([], silent: false) if @loadOptions.reset
    @externalCollection.lastFetchOptions = _.pick($.extend(true, {}, @loadOptions), 'name', 'filters', 'page', 'perPage', 'limit', 'offset', 'order', 'search')
    @externalCollection.lastFetchOptions.include = @loadOptions.plainInclude

  _calculateAdditionalIncludes: ->
    @additionalIncludesCount = 0
    @completedIncludesCount = 0

    if @loadOptions.include
      for elem in @loadOptions.include when _.values(elem)[0].length
        @additionalIncludesCount += 1

  _onSyncSuccess: (resp, status, xhr) =>
    @_updateStorageManagerFromResponse(resp)

  _onCollectionLoadSuccess: (data) ->
    @_updateCollection(@internalCollection, data)

    if @additionalIncludesCount
      @_loadAdditionalIncludes()
    else
      @loadOptions.success()

  _onAdditionalIncludeLoadSuccess: =>
    @completedIncludesCount += 1

    if @completedIncludesCount == @additionalIncludesCount
      @loadOptions.success()

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

    unless @loadOptions.cache == false || @loadOptions.only?
      @storageManager.getCollectionDetails(@loadOptions.name).cache[@loadOptions.cacheKey] = results

    if @loadOptions.only?
      data = _.map(@loadOptions.only, (id) => @cachedCollection.get(id))
    else
      data = _.map(results, (result) => @storageManager.storage(result.key).get(result.id))

    @_onCollectionLoadSuccess(data)

  _updateCollection: (collection, data) ->
    if data
      data = data.models if data.models?
      collection.setLoaded true, trigger: false
      if collection.length
        collection.add data
      else
        collection.reset data
    collection.setLoaded true

  _loadAdditionalIncludes: ->
    for hash in @loadOptions.include
      associationName = _.keys(hash)[0]
      nextLevelInclude = hash[associationName]

      if nextLevelInclude.length
        collectionName = @internalCollection.model.associationDetails(associationName).collectionName
        loadOptions =
          only: @_getIdsForAssociation(associationName)
          include: nextLevelInclude
          error: @loadOptions.error
          success: @_onAdditionalIncludeLoadSuccess

        @storageManager.loadCollection(collectionName, loadOptions)

  _getIdsForAssociation: (association) ->
    models = @internalCollection.map (m) -> if (a = m.get(association)) instanceof Backbone.Collection then a.models else a
    _(models).chain().flatten().pluck("id").compact().uniq().sort().value()

  _checkCacheForData: ->
    unless @loadOptions.cache == false
      if @loadOptions.only?
        @alreadyLoadedIds = _.select @loadOptions.only, (id) => @cachedCollection.get(id)?.associationsAreLoaded(@loadOptions.thisLayerInclude)
        if @alreadyLoadedIds.length == @loadOptions.only.length
          # We've already seen every id that is being asked for and have all the associated data.
          @_onCollectionLoadSuccess(_.map @loadOptions.only, (id) => @cachedCollection.get(id))
          return @externalCollection
      else
        # Check if we have, at some point, requested enough records with this this order and filter(s).
        if @storageManager.getCollectionDetails(@loadOptions.name).cache[@loadOptions.cacheKey]
          subset = _(@storageManager.getCollectionDetails(@loadOptions.name).cache[@loadOptions.cacheKey]).map (result) => @storageManager.storage(result.key).get(result.id)
          if (_.all(subset, (model) => model.associationsAreLoaded(@loadOptions.thisLayerInclude)))
            @_onCollectionLoadSuccess(subset)
            return @externalCollection

    return false

  _buildSyncOptions: ->
    syncOptions =
      data: {}
      parse: true
      error: @loadOptions.error
      success: @_onSyncSuccess

    syncOptions.data.include = @loadOptions.thisLayerInclude.join(",") if @loadOptions.thisLayerInclude.length
    syncOptions.data.only = _.difference(@loadOptions.only, @alreadyLoadedIds).join(",") if @loadOptions.only?
    syncOptions.data.order = @loadOptions.order if @loadOptions.order?
    _.extend(syncOptions.data, _(@loadOptions.filters).omit('include', 'only', 'order', 'per_page', 'page', 'limit', 'offset', 'search')) if _(@loadOptions.filters).keys().length

    unless @loadOptions.only?
      if @loadOptions.limit? && @loadOptions.offset?
        syncOptions.data.limit = @loadOptions.limit
        syncOptions.data.offset = @loadOptions.offset
      else
        syncOptions.data.per_page = @loadOptions.perPage
        syncOptions.data.page = @loadOptions.page

    syncOptions.data.search = @loadOptions.search if @loadOptions.search
    syncOptions