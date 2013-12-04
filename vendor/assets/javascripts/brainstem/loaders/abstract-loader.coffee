window.Brainstem ?= {}

class Brainstem.AbstractLoader
  internalObject: null
  externalObject: null

  constructor: (options = {}) ->
    @storageManager = options.storageManager
    @_createPromise()

    if options.loadOptions
      @setup(options.loadOptions)

  _createPromise: ->
    @deferred = $.Deferred()
    @deferred.promise(this)

  ###*
   * Setup the loader with a list of Brainstem specific loadOptions
   * @param  {object} loadOptions Brainstem specific loadOptions (filters, include, only, etc)
   * @return {object} externalObject that was created.
  ###
  setup: (loadOptions) ->
    @_parseLoadOptions(loadOptions)
    @_createInternalObject()
    @_createExternalObject()

    @externalObject

  ###*
   * Parse supplied loadOptions, add defaults, transform them into appropriate structures, and pull out important pieces.
   * @param  {object} loadOptions
   * @return {object} transformed loadOptions
  ###
  _parseLoadOptions: (loadOptions = {}) ->
    @originalOptions = _.clone(loadOptions)
    @loadOptions = _.clone(loadOptions)
    @loadOptions.include = Brainstem.Utils.wrapObjects(Brainstem.Utils.extractArray "include", @loadOptions)
    @loadOptions.only = if @loadOptions.only then _.map((Brainstem.Utils.extractArray "only", @loadOptions), (id) -> String(id)) else null
    @loadOptions.filters ?= {}
    @loadOptions.thisLayerInclude = _.map @loadOptions.include, (i) -> _.keys(i)[0] # pull off the top layer of includes

    # Determine whether or not we should look at the cache
    @loadOptions.cache ?= true
    @loadOptions.cache = false if @loadOptions.search

    # Build cache key
    filterKeys = _.map(@loadOptions.filters, (v, k) -> "#{k}:#{v}").join(',')
    @loadOptions.cacheKey = [@loadOptions.order || "updated_at:desc", filterKeys, @loadOptions.page, @loadOptions.perPage, @loadOptions.limit, @loadOptions.offset].join('|')

    @cachedCollection = @storageManager.storage @_getCollectionName()

    @loadOptions

  ###*
   * Creates a new proxy object on the loader (`internalObject`) that will serve as the middleman between the server and the external object.
   * When the server responds with models/attributes it will update the internalObject first and when everything is complete it will update
   * the externalObject.
   * @return {undefined}
  ###
  _createInternalObject: ->
    throw "Implement in your subclass"

  ###*
   * Creates a new object on the loader (`externalObject`) that will be returned by setup and resolved with the promise (as the first argument).  This object will not
   * be updated until all loading (including additional loads) are complete.
   * @return {undefined}
  ###
  _createExternalObject: ->
    throw "Implement in your subclass"

  ###*
   * Loads the model from memory or the server.
   * @return {object} the loader's `externalObject`
  ###
  load: ->
    if not @loadOptions
      throw "You must call #setup first or pass loadOptions into the constructor"

    # Check the cache to see if we have everything that we need.
    if @loadOptions.cache && data = @_checkCacheForData()
      data
    else
      @_loadFromServer()

  ###*
   * Checks to see if the current requested data is available in the caching layer.
   * If it is available then update the externalObject with that data (via `_onLoadSuccess`).
   * @return {[boolean|object]} returns false if not found otherwise returns the externalObject.
  ###
  _checkCacheForData: ->
    if @loadOptions.only?
      @alreadyLoadedIds = _.select @loadOptions.only, (id) => @cachedCollection.get(id)?.associationsAreLoaded(@loadOptions.thisLayerInclude)
      if @alreadyLoadedIds.length == @loadOptions.only.length
        # We've already seen every id that is being asked for and have all the associated data.
        @_onLoadSuccess(_.map @loadOptions.only, (id) => @cachedCollection.get(id))
        return @externalObject
    else
      # Check if we have, at some point, requested enough records with this this order and filter(s).
      if @storageManager.getCollectionDetails(@_getCollectionName()).cache[@loadOptions.cacheKey]
        subset = _(@storageManager.getCollectionDetails(@_getCollectionName()).cache[@loadOptions.cacheKey]).map (result) => @storageManager.storage(result.key).get(result.id)
        if (_.all(subset, (model) => model.associationsAreLoaded(@loadOptions.thisLayerInclude)))
          @_onLoadSuccess(subset)
          return @externalObject

    return false

  ###*
   * Makes a GET request to the server via Backbone.sync with the built syncOptions.
   * @return {object} externalObject that will be updated when everything is complete.
  ###
  _loadFromServer: ->
    jqXhr = Backbone.sync.call @internalObject, 'read', @internalObject, @_buildSyncOptions()

    if @loadOptions.returnValues
      @loadOptions.returnValues.jqXhr = jqXhr

    @externalObject

  ###*
   * Called when the Backbone.sync successfully responds from the server.
   * @param  {object} resp    JSON response from the server.
   * @param  {string} _status
   * @param  {object} _xhr    jQuery XHR object
   * @return {undefined}
  ###
  _onServerLoadSuccess: (resp, _status, _xhr) =>
    data = @_updateStorageManagerFromResponse(resp)
    @_onLoadSuccess(data)

  ###*
   * Called when the server responds with data and needs to be persisted to the storageManager.
   * @param  {object} resp JSON data from the server
   * @return {[array|object]} array of models or model that was parsed.
  ###
  _updateStorageManagerFromResponse: (resp) ->
    throw "Implement in your subclass"

  ###*
   * Updates the internalObject with the data in the storageManager and either loads more data or resolves this load.
   * Called after sync + storage manager upadting.
   * @param  {array|object} data array of models or model from _updateStorageManagerFromResponse
   * @return {undefined}
  ###
  _onLoadSuccess: (data) ->
    @_updateObjects(@internalObject, data)
    @_calculateAdditionalIncludes()

    if @additionalIncludes.length
      @_loadAdditionalIncludes()
    else
      @_onLoadingCompleted()

  ###*
   * Called after the server responds with the first layer of includes to determine if any more loads are needed.
   * It will only make additional loads if there were IDs returned during this load for a given association.
   * @return {undefined}
  ###
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

  ###*
   * Loads the next layer of includes from the server.
   * When all loads are complete, it will call `_onLoadingCompleted` which will resolve this layer.
   * @return {undefined}
  ###
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

  ###*
   * Called when all loading (including nested loads) are complete.
   * Updates the `externalObject` with the data that was gathered and resolves the promise.
   * @return {undefined}
  ###
  _onLoadingCompleted: =>
    @_updateObjects(@externalObject, @internalObject)
    @deferred.resolve(@externalObject)

  ###*
   * Updates the object with the supplied data. Will be called:
   *   + after the server responds, `object` will be `internalObject` and data will be the result of `_updateStorageManagerFromResponse`
   *   + after all loading is complete, `object` will be the `externalObject` and data will be the `internalObject`
   * @param  {object} object object that will receive the data
   * @param  {object} data data that needs set on the object
   * @return {undefined}
  ###
  _updateObjects: (object, data) ->
    throw "Implement in your subclass"

  ###*
   * Generates the Brainstem specific options that are passed to Backbone.sync.
   * @return {object} options that are passed to Backbone.sync
  ###
  _buildSyncOptions: ->
    syncOptions =
      data: {}
      parse: true
      error: @loadOptions.error
      success: @_onServerLoadSuccess

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

  ###*
   * Decides whether or not the `only` filter should be applied in the syncOptions.
   * Models will not use the `only` filter as they use show routes.
   * @return {boolean} whether or not to use the `only` filter
  ###
  _shouldUseOnly: ->
    @internalObject instanceof Backbone.Collection

  ###*
   * Returns the name of the collection that this loader maps to and will update in the storageManager.
   * @return {string} name of the collection
  ###
  _getCollectionName: ->
    throw "Implement in your subclass"

  ###*
   * This needs to return a constructor for the model that associations will be compared with.
   * This typically will be the current collection's model/current model constructor.
   * @return {Brainstem.Model}
  ###
  _getModel: ->
    throw "Implement in your subclass"

  ###*
   * This needs to return an array of models that correspond to the supplied association.
   * @return {array} models that are associated with this association
  ###
  _getModelsForAssociation: (association) ->
    throw "Implement in your subclass"

  ###*
   * Returns an array of IDs that need to be loaded for this association.
   * @param  {string} association name of the association
   * @return {array} array of IDs to fetch for this association.
  ###
  _getIdsForAssociation: (association) ->
    models = @_getModelsForAssociation(association)
    _(models).chain().flatten().pluck("id").compact().uniq().sort().value()

  ###*
   * Parses the result of model.get(associationName) to either return a collection's models
   * or the model itself.
   * @param  {object|Backbone.Collection} obj result of calling `.get` on a model with an association name.
   * @return {object|array} either a model object or an array of models from a collection.
  ###
  _modelsOrObj: (obj) ->
    if obj instanceof Backbone.Collection
      obj.models
    else
      obj || [] # TODO: revisit this.. we shouldn't be getting to this stage.
