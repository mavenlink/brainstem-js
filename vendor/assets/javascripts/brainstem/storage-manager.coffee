window.Brainstem ?= {}

# Todo: Record access timestamps on all Brainstem.Models by overloading #get and #set.  Keep a sorted list (Heap?) of model references.
#    clean up the oldest ones if memory is low
#    allow passing a recency parameter to the StorageManager

# The StorageManager class is used to manage a set of Brainstem.Collections.  It is responsible for loading data and
# maintaining caches.
class window.Brainstem.StorageManager
  constructor: (options = {}) ->
    @collections = {}
    @setErrorInterceptor(options.errorInterceptor)
    @dataLoader = new Brainstem.DataLoader(storageManager: this)

  # Add a collection to the StorageManager.  All collections that will be loaded or used in associations must be added.
  #    manager.addCollection "time_entries", App.Collections.TimeEntries
  addCollection: (name, collectionClass) ->
    @collections[name] =
      klass: collectionClass
      modelKlass: collectionClass.prototype.model
      storage: new collectionClass()
      cache: {}

  # Access the cache for a particular collection.
  #    manager.storage("time_entries").get(12).get("title")
  storage: (name) =>
    @getCollectionDetails(name).storage

  dataUsage: =>
    sum = 0
    for dataType in @collectionNames()
      sum += @storage(dataType).length
    sum

  reset: =>
    for name, attributes of @collections
      attributes.storage.reset []
      attributes.cache = {}

  # Access details of a collection.  An error will be thrown if the collection cannot be found.
  getCollectionDetails: (name) =>
    @collections[name] || @collectionError(name)

  collectionNames: =>
    _.keys(@collections)

  collectionExists: (name) =>
    !!@collections[name]

  setErrorInterceptor: (interceptor) =>
    @errorInterceptor = interceptor || (handler, modelOrCollection, options, jqXHR, requestParams) -> handler?(jqXHR)


  loadModel: =>
    @dataLoader.loadModel.apply(@dataLoader, arguments)

  loadCollection: =>
    @dataLoader.loadCollection.apply(@dataLoader, arguments)

  _handleNextLayer: (options) =>
    # Collection is a fully populated collection of tasks whose first layer of associations are loaded.
    # include is a hierarchical list of associations on those tasks:
    #   [{ 'time_entries': ['project': [], 'task': [{ 'assignees': []}]] }, { 'project': [] }]

    _(options.include).each (hash) => # { 'time_entries': ['project': [], 'task': [{ 'assignees': []}]] }
      association = _.keys(hash)[0] # time_entries
      nextLevelInclude = hash[association] # ['project': [], 'task': [{ 'assignees': []}]]
      if nextLevelInclude.length
        association_ids = _(options.collection.models).chain().
        map((m) -> if (a = m.get(association)) instanceof Backbone.Collection then a.models else a).
        flatten().uniq().compact().pluck("id").sort().value()
        newCollectionName = options.collection.model.associationDetails(association).collectionName
        @_loadCollectionWithFirstLayer name: newCollectionName, only: association_ids, include: nextLevelInclude, error: options.error, success: (loadedAssociationCollection) =>
          @_handleNextLayer(collection: loadedAssociationCollection, include: nextLevelInclude, error: options.error, success: options.success)
          options.success()

  _loadCollectionWithFirstLayer: (options) =>
    options = $.extend({}, options)
    name = options.name
    only = if options.only then _.map((Brainstem.Utils.extractArray "only", options), (id) -> String(id)) else null
    search = options.search
    include = _(options.include).map((i) -> _.keys(i)[0]) # pull off the top layer of includes
    filters = options.filters || {}
    order = options.order || "updated_at:desc"
    filterKeys = _.map(filters, (v, k) -> "#{k}:#{v}").join(',')
    cacheKey = [order, filterKeys, options.page, options.perPage, options.limit, options.offset].join('|')

    cachedCollection = @storage name
    collection = @createNewCollection name, []

    unless options.cache == false
      if only?
        alreadyLoadedIds = _.select only, (id) => cachedCollection.get(id)?.associationsAreLoaded(include)
        if alreadyLoadedIds.length == only.length
          # We've already seen every id that is being asked for and have all the associated data.
          @_success options, collection, _.map only, (id) => cachedCollection.get(id)
          return collection
      else
        # Check if we have, at some point, requested enough records with this this order and filter(s).
        if @getCollectionDetails(name).cache[cacheKey]
          subset = _(@getCollectionDetails(name).cache[cacheKey]).map (result) -> base.data.storage(result.key).get(result.id)
          if (_.all(subset, (model) => model.associationsAreLoaded(include)))
            @_success options, collection, subset
            return collection

    # If we haven't returned yet, we need to go to the server to load some missing data.
    syncOptions =
      data: {}
      parse: true
      error: options.error
      success: (resp, status, xhr) =>
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
          keys.splice(keys.indexOf(name), 1) if keys.indexOf(name) != -1
          keys.push(name)

        for underscoredModelName in keys
          @storage(underscoredModelName).update _(resp[underscoredModelName]).values()

        unless options.cache == false || only?
          @getCollectionDetails(name).cache[cacheKey] = results

        if only?
          @_success options, collection, _.map(only, (id) -> cachedCollection.get(id))
        else
          @_success options, collection, _(results).map (result) -> base.data.storage(result.key).get(result.id)


    syncOptions.data.include = include.join(",") if include.length
    syncOptions.data.only = _.difference(only, alreadyLoadedIds).join(",") if only?
    syncOptions.data.order = options.order if options.order?
    _.extend(syncOptions.data, _(filters).omit('include', 'only', 'order', 'per_page', 'page', 'limit', 'offset', 'search')) if _(filters).keys().length

    unless only?
      if options.limit? && options.offset?
        syncOptions.data.limit = options.limit
        syncOptions.data.offset = options.offset
      else
        syncOptions.data.per_page = options.perPage
        syncOptions.data.page = options.page

    syncOptions.data.search = search if search

    modelOrCollection = collection
    modelOrCollection = options.model if options.only && options.model
    
    jqXhr = Backbone.sync.call collection, 'read', modelOrCollection, syncOptions

    if options.returnValues
      options.returnValues.jqXhr = jqXhr

    collection

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

  collectionError: (name) =>
    Brainstem.Utils.throwError("Unknown collection #{name} in StorageManager.  Known collections: #{_(@collections).keys().join(", ")}")

  createNewCollection: (collectionName, models = [], options = {}) =>
    loaded = options.loaded
    delete options.loaded
    collection = new (@getCollectionDetails(collectionName).klass)(models, options)
    collection.setLoaded(true, trigger: false) if loaded
    collection

  createNewModel: (modelName, options) =>
    new (@getCollectionDetails(modelName.pluralize()).modelKlass)(options || {})

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

  _countRequiredServerRequests: (array, wrapped = false) =>
    if array?.length
      array = @_wrapObjects(array) unless wrapped
      sum = 1
      _(array).each (elem) =>
        sum += @_countRequiredServerRequests(_(elem).values()[0], true)
      sum
    else
      0

  # Expectations and stubbing

  stub: (collectionName, options) =>
    if @expectations?
      expectation = new Brainstem.Expectation(collectionName, options, @)
      @expectations.push expectation
      expectation
    else
      throw "You must call #enableExpectations on your instance of Brainstem.StorageManager before you can set expectations."

  stubImmediate: (collectionName, options) =>
    @stub collectionName, $.extend({}, options, immediate: true)

  enableExpectations: =>
    @expectations = []

  handleExpectations: (name, collection, options) =>
    for expectation in @expectations
      if expectation.optionsMatch(name, options)
        expectation.recordRequest(collection, options)
        return
    throw "No expectation matched #{name} with #{JSON.stringify options}"
