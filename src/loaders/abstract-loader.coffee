$ = require 'jquery'
_ = require 'underscore'
Backbone = require 'backbone'
Backbone.$ = $ # TODO remove after upgrading to backbone 1.2+

Utils = require '../utils'


class AbstractLoader

  #
  # Properties

  internalObject: null
  externalObject: null


  #
  # Init

  constructor: (options = {}) ->
    @storageManager = options.storageManager

    @_deferred = $.Deferred()
    @_deferred.promise(this)

    if options.loadOptions
      @setup(options.loadOptions)

  ###*
   * Setup the loader with a list of Brainstem specific loadOptions
   * @param  {object} loadOptions Brainstem specific loadOptions (filters, include, only, etc)
   * @return {object} externalObject that was created.
  ###
  setup: (loadOptions) ->
    @_parseLoadOptions(loadOptions)
    @_createObjects()

    @externalObject


  #
  # Accessors

  ###*
   * Returns the cache object from the storage manager.
   * @return {object} Object containing `count` and `results` that were cached.
  ###
  getCacheObject: ->
    @storageManager.getCollectionDetails(@_getCollectionName()).cache[@loadOptions.cacheKey]


  #
  # Control

  ###*
   * Loads the model from memory or the server.
   * @return {object} the loader's `externalObject`
  ###
  load: ->
    if not @loadOptions
      throw new Error('You must call #setup first or pass loadOptions into the constructor')

    # Check the cache to see if we have everything that we need.
    if @loadOptions.cache && data = @_checkCacheForData()
      data
    else
      @_loadFromServer()


  #
  # Private

  # Accessors

  ###*
   * Returns the name of the collection that this loader maps to and will update in the storageManager.
   * @return {string} name of the collection
  ###
  _getCollectionName: ->
    throw new Error('Implement in your subclass')

  ###*
   * Returns the name that expectations will be stubbed with (story or stories etc)
   * @return {string} name of the stub
  ###
  _getExpectationName: ->
    throw new Error('Implement in your subclass')

  ###*
   * This needs to return a constructor for the model that associations will be compared with.
   * This typically will be the current collection's model/current model constructor.
   * @return {Model}
  ###
  _getModel: ->
    throw new Error('Implement in your subclass')

  ###*
   * This needs to return an array of models that correspond to the supplied association.
   * @return {array} models that are associated with this association
  ###
  _getModelsForAssociation: (association) ->
    throw new Error('Implement in your subclass')

  ###*
   * Returns an array of IDs that need to be loaded for this association.
   * @param  {string} association name of the association
   * @return {array} array of IDs to fetch for this association.
  ###
  _getIdsForAssociation: (association) ->
    models = @_getModelsForAssociation(association)
    if _.isArray(models)
      _(models).chain().flatten().pluck('id').compact().uniq().sort().value()
    else
      [models.id]


  # Control

  ###*
   * Sets up both the `internalObject` and `externalObject`.
   * In the case of models the `internalObject` and `externalObject` are the same.
   * In the case of collections the `internalObject` is a proxy object that updates
   * the `externalObject` when all loading is completed.
  ###
  _createObjects: ->
    throw new Error('Implement in your subclass')

  ###*
   * Updates the object with the supplied data. Will be called:
   *   + after the server responds, `object` will be `internalObject` and
   *     data will be the result of `_updateStorageManagerFromResponse`
   *   + after all loading is complete, `object` will be the `externalObject`
   *     and data will be the `internalObject`
   * @param  {object} object object that will receive the data
   * @param  {object} data data that needs set on the object
   * @param  {boolean} silent whether or not to trigger loaded at the end of the update
   * @return {undefined}
  ###
  _updateObjects: (object, data, silent = false) ->
    throw new Error('Implement in your subclass')

  ###*
   * Parse supplied loadOptions, add defaults, transform them into
   * appropriate structures, and pull out important pieces.
   * @param  {object} loadOptions
   * @return {object} transformed loadOptions
  ###
  _parseLoadOptions: (loadOptions = {}) ->
    @originalOptions = _.clone(loadOptions)
    @loadOptions = _.clone(loadOptions)
    @loadOptions.include = Utils.wrapObjects(Utils.extractArray('include', @loadOptions))
    @loadOptions.optionalFields = Utils.extractArray('optionalFields', @loadOptions)
    @loadOptions.filters ?= {}
    @loadOptions.thisLayerInclude = _.map @loadOptions.include, (i) -> _.keys(i)[0] # pull off the top layer of includes

    if @loadOptions.only
      @loadOptions.only = _.map((Utils.extractArray 'only', @loadOptions), (id) -> String(id))
    else
      @loadOptions.only = null

    # Determine whether or not we should look at the cache
    @loadOptions.cache ?= true
    @loadOptions.cache = false if @loadOptions.search
    @loadOptions.cacheKey = @_buildCacheKey()

    @cachedCollection = @storageManager.storage @_getCollectionName()

    @loadOptions

  ###*
   * Builds a cache key to represent this object
   * @return {string} cache key
  ###
  _buildCacheKey: ->
    filterKeys = if _.isObject(@loadOptions.filters) && _.size(@loadOptions.filters) > 0
      JSON.stringify(@loadOptions.filters)
    else
      ''

    onlyIds = (@loadOptions.only || []).sort().join(',')

    @loadOptions.cacheKey = [
      @loadOptions.order || 'updated_at:desc'
      filterKeys
      onlyIds
      @loadOptions.page
      @loadOptions.perPage
      @loadOptions.limit
      @loadOptions.offset
      @loadOptions.search
    ].join('|')

  ###*
   * Checks to see if the current requested data is available in the caching layer.
   * If it is available then update the externalObject with that data (via `_onLoadSuccess`).
   * @return {[boolean|object]} returns false if not found otherwise returns the externalObject.
  ###
  _checkCacheForData: ->
    if @loadOptions.only?
      alreadyLoadedIds = _.select @loadOptions.only, (id) =>
        @cachedCollection.get(id)?.dependenciesAreLoaded(@loadOptions)
      if alreadyLoadedIds.length == @loadOptions.only.length
        @_onLoadSuccess(_.map @loadOptions.only, (id) => @cachedCollection.get(id))
        return @externalObject
    else
      # Check if we have a cache for this request and if so make sure that
      # all of the requested includes for this layer are loaded on those models.
      cacheObject = @getCacheObject()

      if cacheObject && cacheObject.valid
        subset = _.map cacheObject.results, (result) => @storageManager.storage(result.key).get(result.id)
        if (_.all(subset, (model) => model.dependenciesAreLoaded(@loadOptions)))
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
   * Called when the server responds with data and needs to be persisted to the storageManager.
   * @param  {object} resp JSON data from the server
   * @return {[array|object]} array of models or model that was parsed.
  ###
  _updateStorageManagerFromResponse: (resp) ->
    throw new Error('Implement in your subclass')

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
      includedAssociation = hash[associationName]

      if associationIds.length
        association = {
          ids: associationIds
        }

        if includedAssociation instanceof Backbone.Collection
          association.collection = includedAssociation

          @additionalIncludes.push association
        else if includedAssociation.length
          association.include = includedAssociation
          association.name = associationName

          @additionalIncludes.push association

  ###*
   * Loads the next layer of includes from the server.
   * When all loads are complete, it will call `_onLoadingCompleted` which will resolve this layer.
   * @return {undefined}
  ###
  _loadAdditionalIncludes: ->
    promises = []

    for association in @additionalIncludes
      loadOptions =
        cache: @loadOptions.cache
        only: association.ids
        params:
          apply_default_filters: false

      if association.collection
        promises.push association.collection.fetch(loadOptions)
      else
        collectionName = @_getModel().associationDetails(association.name).collectionName
        loadOptions.include = association.include
        promises.push(@storageManager.loadObject(collectionName, loadOptions))

    $.when.apply($, promises)
      .done(@_onLoadingCompleted)
      .fail(@_onServerLoadError)


  ###*
   * Generates the Brainstem specific options that are passed to Backbone.sync.
   * @return {object} options that are passed to Backbone.sync
  ###
  _buildSyncOptions: ->
    options = @loadOptions
    syncOptions =
      data: {}
      parse: true
      error: @_onServerLoadError
      success: @_onServerLoadSuccess

    syncOptions.data.include = options.thisLayerInclude.join(',') if options.thisLayerInclude.length
    syncOptions.data.only = options.only.join(',') if options.only && @_shouldUseOnly()
    syncOptions.data.order = options.order if options.order?
    syncOptions.data.search = options.search if options.search
    syncOptions.data.optional_fields = @loadOptions.optionalFields.join(',') if @loadOptions.optionalFields?.length

    blacklist = ['include', 'only', 'order', 'per_page', 'page', 'limit', 'offset', 'search', 'optional_fields']
    _(syncOptions.data).chain()
      .extend(_(options.filters).omit(blacklist))
      .extend(_(options.params).omit(blacklist))
      .value()

    unless options.only?
      if options.limit? && options.offset?
        syncOptions.data.limit = options.limit
        syncOptions.data.offset = options.offset
      else
        syncOptions.data.per_page = options.perPage
        syncOptions.data.page = options.page

    syncOptions

  ###*
   * Decides whether or not the `only` filter should be applied in the syncOptions.
   * Models will not use the `only` filter as they use show routes.
   * @return {boolean} whether or not to use the `only` filter
  ###
  _shouldUseOnly: ->
    @internalObject instanceof Backbone.Collection

  ###*
   * Parses the result of model.get(associationName) to either return a collection's models
   * or the model itself.
   * @param  {object|Backbone.Collection} obj result of calling `.get` on a model with an association name.
   * @return {object|array} either a model object or an array of models from a collection.
  ###
  _modelsOrObj: (obj) ->
    if obj instanceof Backbone.Collection
      obj.models
    else if obj instanceof Array
      obj
    else if obj
      [obj]
    else
      []

  # Events

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
   * Called when the Backbone.sync has errored.
   * @param  {object} jqXhr
   * @param  {string} textStatus
   * @param  {string} errorThrown
  ###
  _onServerLoadError: (jqXHR, textStatus, errorThrown) =>
    @_deferred.reject.apply(this, arguments)

  ###*
   * Updates the internalObject with the data in the storageManager and either loads more data or resolves this load.
   * Called after sync + storage manager updating.
   * @param  {array|object} data array of models or model from _updateStorageManagerFromResponse
   * @return {undefined}
  ###
  _onLoadSuccess: (data) ->
    @_updateObjects(@internalObject, data, true)
    @_calculateAdditionalIncludes()

    if @additionalIncludes.length
      @_loadAdditionalIncludes()
    else
      @_onLoadingCompleted()

  ###*
   * Called when all loading (including nested loads) are complete.
   * Updates the `externalObject` with the data that was gathered and resolves the promise.
   * @return {undefined}
  ###
  _onLoadingCompleted: =>
    @_updateObjects(@externalObject, @internalObject)
    @_deferred.resolve(@externalObject)


module.exports = AbstractLoader
