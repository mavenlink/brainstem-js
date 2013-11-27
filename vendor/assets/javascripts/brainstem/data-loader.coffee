window.Brainstem ?= {}

class Brainstem.CollectionLoader
  constructor: (options = {}) ->
    @storageManager = options.storageManager

  _parseLoadOptions: (loadOptions) ->
    @loadOptions = $.extend {}, loadOptions
    @loadOptions.only = if @loadOptions.only then _.map((Brainstem.Utils.extractArray "only", @loadOptions), (id) -> String(id)) else null
    @loadOptions.filters ?= {}
    @loadOptions.include = _(@loadOptions.include).map((i) -> _.keys(i)[0]) # pull off the top layer of includes

    # Build cache key
    filterKeys = _.map(@loadOptions.filters, (v, k) -> "#{k}:#{v}").join(',')
    @loadOptions.cacheKey = [@loadOptions.order || "updated_at:desc", filterKeys, @loadOptions.page, @loadOptions.perPage, @loadOptions.limit, @loadOptions.offset].join('|')

    # Generate collection references
    @cachedCollection = @storageManager.storage @loadOptions.name
    @internalCollection = @storageManager.createNewCollection @loadOptions.name, []

  _checkCache: ->
    unless @loadOptions.cache == false
      if @loadOptions.only?
        @alreadyLoadedIds = _.select @loadOptions.only, (id) => @cachedCollection.get(id)?.associationsAreLoaded(@loadOptions.include)
        if @alreadyLoadedIds.length == @loadOptions.only.length
          # We've already seen every id that is being asked for and have all the associated data.
          @_success @loadOptions, @internalCollection, _.map @loadOptions.only, (id) => @cachedCollection.get(id)
          return @internalCollection
      else
        # Check if we have, at some point, requested enough records with this this order and filter(s).
        if @storageManager.getCollectionDetails(@loadOptions.name).cache[@loadOptions.cacheKey]
          subset = _(@storageManager.getCollectionDetails(@loadOptions.name).cache[@loadOptions.cacheKey]).map (result) => @storageManager.storage(result.key).get(result.id)
          if (_.all(subset, (model) => model.associationsAreLoaded(@loadOptions.include)))
            @_success @loadOptions, @internalCollection, subset
            return @internalCollection

    return false

  loadCollection: (loadOptions) ->
    @_parseLoadOptions(loadOptions)

    # Check the cache
    if collection = @_checkCache()
      return collection

    # If we haven't returned yet, we need to go to the server to load some missing data.
    modelOrCollection = @internalCollection
    modelOrCollection = @loadOptions.model if @loadOptions.only && @loadOptions.model
    
    jqXhr = Backbone.sync.call @internalCollection, 'read', modelOrCollection, @_buildSyncOptions()

    if @loadOptions.returnValues
      @loadOptions.returnValues.jqXhr = jqXhr

    @internalCollection

  onLoadSuccess: (resp, status, xhr) =>
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
      data = _(results).map (result) -> base.data.storage(result.key).get(result.id)

    @_success @loadOptions, @internalCollection, data

  _buildSyncOptions: ->
    syncOptions =
      data: {}
      parse: true
      error: @loadOptions.error
      success: @onLoadSuccess

    syncOptions.data.include = @loadOptions.include.join(",") if @loadOptions.include.length
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

  _success: (options, collection, data) ->
    if data
      data = data.models if data.models?
      collection.setLoaded true, trigger: false
      if collection.length
        collection.add data
      else
        collection.reset data
    collection.setLoaded true
    options.success(collection) if options.success?

####################################

class Brainstem.DataLoader
  constructor: (options = {}) ->
    @storageManager = options.storageManager

  # Request a model to be loaded, optionally ensuring that associations be included as well.  A collection is returned immediately and is reset
  # when the load, and any dependent loads, are complete.
  #     model = manager.loadModel "time_entry"
  #     model = manager.loadModel "time_entry", fields: ["title", "notes"]
  #     model = manager.loadModel "time_entry", include: ["project", "task"]
  loadModel: (name, id, options) =>
    options = _.clone(options || {})
    oldSuccess = options.success
    collectionName = name.pluralize()
    
    model = options.model || new (@storageManager.getCollectionDetails(collectionName).modelKlass)(id: id)
    model.setLoaded false, trigger: false

    @loadCollection collectionName, _.extend options,
      only: id
      model: model
      success: (collection) ->
        model.setLoaded true, trigger: false
        model.set collection.get(id).attributes
        model.setLoaded true
        oldSuccess(model) if oldSuccess
    model

  # Request a set of data to be loaded, optionally ensuring that associations be included as well.  A collection is returned immediately and is reset
  # when the load, and any dependent loads, are complete.
  #     collection = manager.loadCollection "time_entries"
  #     collection = manager.loadCollection "time_entries", only: [2, 6]
  #     collection = manager.loadCollection "time_entries", fields: ["title", "notes"]
  #     collection = manager.loadCollection "time_entries", include: ["project", "task"]
  #     collection = manager.loadCollection "time_entries", include: ["project:title,description", "task:due_date"]
  #     collection = manager.loadCollection "tasks",      include: ["assets", { "assignees": "account" }, { "sub_tasks": ["assignees", "assets"] }]
  #     collection = manager.loadCollection "time_entries", filters: ["project_id:6", "editable:true"], order: "updated_at:desc", page: 1, perPage: 20
  loadCollection: (name, options) =>
    options = $.extend({}, options, name: name)
    @_checkPageSettings options
    include = @_wrapObjects(Brainstem.Utils.extractArray "include", options)
    if options.search
      options.cache = false

    collection = options.collection || @storageManager.createNewCollection name, []
    collection.setLoaded false
    collection.reset([], silent: false) if options.reset
    collection.lastFetchOptions = _.pick($.extend(true, {}, options), 'name', 'filters', 'include', 'page', 'perPage', 'limit', 'offset', 'order', 'search')

    if @storageManager.expectations?
      @storageManager.handleExpectations name, collection, options
    else
      opts = $.extend {}, options, include: include, success: (firstLayerCollection) =>
        @_success(options, collection, firstLayerCollection)

      cl = new Brainstem.CollectionLoader(storageManager: @storageManager)
      cl.loadCollection(opts)

      # @_loadCollectionWithFirstLayer($.extend({}, options, include: include, success: ((firstLayerCollection) =>
      #   expectedAdditionalLoads = @_countRequiredServerRequests(include) - 1

      #   if expectedAdditionalLoads > 0
      #     timesCalled = 0
      #     @_handleNextLayer collection: firstLayerCollection, include: include, error: options.error, success: =>
      #       timesCalled += 1
      #       if timesCalled == expectedAdditionalLoads
      #         @_success(options, collection, firstLayerCollection)
      #   else
      #     @_success(options, collection, firstLayerCollection)
      # )))

    collection

  # _handleNextLayer: (options) =>
  #   # Collection is a fully populated collection of tasks whose first layer of associations are loaded.
  #   # include is a hierarchical list of associations on those tasks:
  #   #   [{ 'time_entries': ['project': [], 'task': [{ 'assignees': []}]] }, { 'project': [] }]

  #   _(options.include).each (hash) => # { 'time_entries': ['project': [], 'task': [{ 'assignees': []}]] }
  #     association = _.keys(hash)[0] # time_entries
  #     nextLevelInclude = hash[association] # ['project': [], 'task': [{ 'assignees': []}]]
  #     if nextLevelInclude.length
  #       association_ids = _(options.collection.models).chain().
  #       map((m) -> if (a = m.get(association)) instanceof Backbone.Collection then a.models else a).
  #       flatten().uniq().compact().pluck("id").sort().value()
  #       newCollectionName = options.collection.model.associationDetails(association).collectionName
  #       @_loadCollectionWithFirstLayer name: newCollectionName, only: association_ids, include: nextLevelInclude, error: options.error, success: (loadedAssociationCollection) =>
  #         @_handleNextLayer(collection: loadedAssociationCollection, include: nextLevelInclude, error: options.error, success: options.success)
  #         options.success()

  _success: (options, collection, data) =>
    if data
      data = data.models if data.models?
      collection.setLoaded true, trigger: false
      if collection.length
        collection.add data
      else
        collection.reset data
    collection.setLoaded true
    options.success(collection) if options.success?

  # Helpers

  _checkPageSettings: (options) =>
    if options.limit? && options.limit != '' && options.offset? && options.offset != ''
      options.perPage = options.page = undefined
    else
      options.limit = options.offset = undefined

    @_setDefaultPageSettings(options)

  _setDefaultPageSettings: (options) =>
    if options.limit? && options.offset?
      options.limit = 1 if options.limit < 1
      options.offset = 0 if options.offset < 0
    else
      options.perPage = options.perPage || 20
      options.perPage = 1 if options.perPage < 1
      options.page = options.page || 1
      options.page = 1 if options.page < 1

  _wrapObjects: (array) =>
    output = []
    _(array).each (elem) =>
      if elem.constructor == Object
        for key, value of elem
          o = {}
          o[key] = @_wrapObjects(if value instanceof Array then value else [value])
          output.push o
      else
        o = {}
        o[elem] = []
        output.push o
    output

  # _countRequiredServerRequests: (array, wrapped = false) =>
  #   if array?.length
  #     array = @_wrapObjects(array) unless wrapped
  #     sum = 1
  #     _(array).each (elem) =>
  #       sum += @_countRequiredServerRequests(_(elem).values()[0], true)
  #     sum
  #   else
  #     0