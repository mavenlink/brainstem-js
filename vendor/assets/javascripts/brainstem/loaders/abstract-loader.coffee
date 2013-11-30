window.Brainstem ?= {}

class Brainstem.AbstractLoader
  constructor: (options = {}) ->
    @storageManager = options.storageManager
    @_createPromise()

    if options.loadOptions
      @setup(options.loadOptions)

  setup: (loadOptions) ->
    @_parseLoadOptions(loadOptions)
    @_createObjectReferences()

    @externalObject

  load: ->
    if not @loadOptions
      throw "You must call #setup first or pass loadOptions into the constructor"

    # Check the cache to see if we have everything that we need.
    if @loadOptions.cache && data = @_checkCacheForData()
      data
    else
      @_loadData()

  getCollectionName: ->
    throw "Implement in your subclass"

  _parseLoadOptions: (loadOptions) ->
    @originalOptions = _.clone(loadOptions)
    @loadOptions = _.clone(loadOptions)
    @loadOptions.plainInclude = @loadOptions.include
    @loadOptions.include = Brainstem.Utils.wrapObjects(Brainstem.Utils.extractArray "include", @loadOptions)
    @loadOptions.only = if @loadOptions.only then _.map((Brainstem.Utils.extractArray "only", @loadOptions), (id) -> String(id)) else null
    @loadOptions.filters ?= {}
    @loadOptions.thisLayerInclude = _(@loadOptions.include).map((i) -> _.keys(i)[0]) # pull off the top layer of includes

    # Determine whether or not we should look at the cache
    @loadOptions.cache ?= true
    @loadOptions.cache = false if @loadOptions.search

    # Build cache key
    filterKeys = _.map(@loadOptions.filters, (v, k) -> "#{k}:#{v}").join(',')
    @loadOptions.cacheKey = [@loadOptions.order || "updated_at:desc", filterKeys, @loadOptions.page, @loadOptions.perPage, @loadOptions.limit, @loadOptions.offset].join('|')

    @cachedCollection = @storageManager.storage @getCollectionName()

  _createObjectReferences: ->
    throw "Implement in your subclass"

  _checkCacheForData: ->
    if @loadOptions.only?
      @alreadyLoadedIds = _.select @loadOptions.only, (id) => @cachedCollection.get(id)?.associationsAreLoaded(@loadOptions.thisLayerInclude)
      if @alreadyLoadedIds.length == @loadOptions.only.length
        # We've already seen every id that is being asked for and have all the associated data.
        @_onLoadSuccess(_.map @loadOptions.only, (id) => @cachedCollection.get(id))
        return @externalObject
    else
      # Check if we have, at some point, requested enough records with this this order and filter(s).
      if @storageManager.getCollectionDetails(@getCollectionName()).cache[@loadOptions.cacheKey]
        subset = _(@storageManager.getCollectionDetails(@getCollectionName()).cache[@loadOptions.cacheKey]).map (result) => @storageManager.storage(result.key).get(result.id)
        if (_.all(subset, (model) => model.associationsAreLoaded(@loadOptions.thisLayerInclude)))
          @_onLoadSuccess(subset)
          return @externalObject

    return false

  _loadData: ->
    jqXhr = Backbone.sync.call @internalObject, 'read', @internalObject, @_buildSyncOptions()

    if @loadOptions.returnValues
      @loadOptions.returnValues.jqXhr = jqXhr

    @externalObject

  _shouldUseOnly: ->
    @internalObject instanceof Backbone.Collection

  _buildSyncOptions: ->
    syncOptions =
      data: {}
      parse: true
      error: @loadOptions.error
      success: @_onSyncSuccess

    syncOptions.data.include = @loadOptions.thisLayerInclude.join(",") if @loadOptions.thisLayerInclude.length

    if @loadOptions.only && @_shouldUseOnly()
      syncOptions.data.only = _.difference(@loadOptions.only, @alreadyLoadedIds).join(",")

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

  _onSyncSuccess: (resp, _status, _xhr) =>
    data = @_updateStorageManagerFromResponse(resp)
    @_onLoadSuccess(data)

  _updateStorageManagerFromResponse: ->
    throw "Implement in your subclass"

  _calculateAdditionalIncludes: ->
    @additionalIncludes = []

    for hash in @loadOptions.include 
      associationName = _.keys(hash)[0]
      associationIds = @_getIdsForAssociation(associationName)
      associationInclude = hash[associationName]

      if associationIds.length && associationInclude.length
        @additionalIncludes.push
          name: associationName
          ids: associationIds
          include: associationInclude

  _onLoadSuccess: (data) ->
    @_updateObjects(@internalObject, data)
    @_calculateAdditionalIncludes()

    if @additionalIncludes.length
      @_loadAdditionalIncludes()
    else
      @_onLoadingCompleted()

  _createPromise: ->
    @deferred = $.Deferred()
    @deferred.promise(this)

  _onLoadingCompleted: =>
    @_updateObjects(@externalObject, @internalObject)
    @deferred.resolve(@externalObject)

  _updateObjects: ->
    throw "Implement in your subclass"

  _loadAdditionalIncludes: ->
    promises = []

    for association in @additionalIncludes
      collectionName = @_getModel().associationDetails(association.name).collectionName

      loadOptions =
        only: association.ids
        include: association.include
        error: @loadOptions.error

      promises.push(@storageManager.loadObject(collectionName, loadOptions))

    $.when.apply($, promises).done(@_onLoadingCompleted)

  _getModel: ->
    throw "Implement in your subclass"

  _getModelsForAssociation: ->
    throw "Implement in your subclass"

  _getIdsForAssociation: (association) ->
    models = @_getModelsForAssociation(association)
    _(models).chain().flatten().pluck("id").compact().uniq().sort().value()

  _modelsOrObj: (obj) ->
    if obj instanceof Backbone.Collection
      obj.models
    else
      obj || [] # TODO: revisit this.. we shouldn't be getting to this stage.
