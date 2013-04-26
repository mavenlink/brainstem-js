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
    @errorInterceptor = interceptor || (handler, modelOrCollection, options, jqXHR, requestParams) -> handler?(modelOrCollection, jqXHR)

  # Request a model to be loaded, optionally ensuring that associations be included as well.  A collection is returned immediately and is reset
  # when the load, and any dependent loads, are complete.
  #     model = manager.loadModel "time_entry"
  #     model = manager.loadModel "time_entry", fields: ["title", "notes"]
  #     model = manager.loadModel "time_entry", include: ["project", "task"]
  loadModel: (name, id, options) =>
    options = _.clone(options || {})
    oldSuccess = options.success
    collectionName = name.pluralize()
    model = new (@getCollectionDetails(collectionName).modelKlass)()
    @loadCollection collectionName, _.extend options,
      only: id
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

    collection = options.collection || @createNewCollection name, []
    collection.setLoaded false
    collection.reset([], silent: false) if options.reset
    collection.lastFetchOptions = _.pick($.extend(true, {}, options), 'name', 'filters', 'include', 'page', 'perPage', 'order', 'search')

    if @expectations?
      @handleExpectations name, collection, options
    else
      @_loadCollectionWithFirstLayer($.extend({}, options, include: include, success: ((firstLayerCollection) =>
        expectedAdditionalLoads = @_countRequiredServerRequests(include) - 1
        if expectedAdditionalLoads > 0
          timesCalled = 0
          @_handleNextLayer firstLayerCollection, include, =>
            timesCalled += 1
            if timesCalled == expectedAdditionalLoads
              @_success(options, collection, firstLayerCollection)
        else
          @_success(options, collection, firstLayerCollection)
      )))

    collection

  _handleNextLayer: (collection, include, callback) =>
    # Collection is a fully populated collection of tasks whose first layer of associations are loaded.
    # include is a hierarchical list of associations on those tasks:
    #   [{ 'time_entries': ['project': [], 'task': [{ 'assignees': []}]] }, { 'project': [] }]

    _(include).each (hash) => # { 'time_entries': ['project': [], 'task': [{ 'assignees': []}]] }
      association = _.keys(hash)[0] # time_entries
      nextLevelInclude = hash[association] # ['project': [], 'task': [{ 'assignees': []}]]
      if nextLevelInclude.length
        association_ids = _(collection.models).chain().
        map((m) -> if (a = m.get(association)) instanceof Backbone.Collection then a.models else a).
        flatten().uniq().compact().pluck("id").sort().value()
        newCollectionName = collection.model.associationDetails(association).collectionName
        @_loadCollectionWithFirstLayer name: newCollectionName, only: association_ids, include: nextLevelInclude, success: (loadedAssociationCollection) =>
          @_handleNextLayer(loadedAssociationCollection, nextLevelInclude, callback)
          callback()

  _loadCollectionWithFirstLayer: (options) =>
    options = $.extend({}, options)
    name = options.name
    only = if options.only then _.map((Brainstem.Utils.extractArray "only", options), (id) -> String(id)) else null
    search = options.search
    include = _(options.include).map((i) -> _.keys(i)[0]) # pull off the top layer of includes
    filters = Brainstem.Utils.extractArray "filters", options
    order = options.order || "updated_at:desc"
    cacheKey = "#{order}|#{_.chain(filters).pairs().map(([k, v]) -> "#{k}:#{v}" ).value().join(",")}|#{options.page}|#{options.perPage}"

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
    _.extend(syncOptions.data, _(filters).omit('include', 'only', 'order', 'per_page', 'page', 'search')) if _(filters).keys().length
    syncOptions.data.per_page = options.perPage unless only?
    syncOptions.data.page = options.page unless only?
    syncOptions.data.search = search if search

    Backbone.sync.call collection, 'read', collection, syncOptions

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
