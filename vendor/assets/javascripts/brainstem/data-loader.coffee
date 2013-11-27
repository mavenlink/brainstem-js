window.Brainstem ?= {}

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
    @storageManager._checkPageSettings options
    include = @storageManager._wrapObjects(Brainstem.Utils.extractArray "include", options)
    if options.search
      options.cache = false

    collection = options.collection || @storageManager.createNewCollection name, []
    collection.setLoaded false
    collection.reset([], silent: false) if options.reset
    collection.lastFetchOptions = _.pick($.extend(true, {}, options), 'name', 'filters', 'include', 'page', 'perPage', 'limit', 'offset', 'order', 'search')

    if @storageManager.expectations?
      @storageManager.handleExpectations name, collection, options
    else
      @_loadCollectionWithFirstLayer($.extend({}, options, include: include, success: ((firstLayerCollection) =>
        expectedAdditionalLoads = @storageManager._countRequiredServerRequests(include) - 1
        if expectedAdditionalLoads > 0
          timesCalled = 0
          @_handleNextLayer collection: firstLayerCollection, include: include, error: options.error, success: =>
            timesCalled += 1
            if timesCalled == expectedAdditionalLoads
              @_success(options, collection, firstLayerCollection)
        else
          @_success(options, collection, firstLayerCollection)
      )))

    collection

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

    cachedCollection = @storageManager.storage name
    collection = @storageManager.createNewCollection name, []

    unless options.cache == false
      if only?
        alreadyLoadedIds = _.select only, (id) => cachedCollection.get(id)?.associationsAreLoaded(include)
        if alreadyLoadedIds.length == only.length
          # We've already seen every id that is being asked for and have all the associated data.
          @_success options, collection, _.map only, (id) => cachedCollection.get(id)
          return collection
      else
        # Check if we have, at some point, requested enough records with this this order and filter(s).
        if @storageManager.getCollectionDetails(name).cache[cacheKey]
          subset = _(@storageManager.getCollectionDetails(name).cache[cacheKey]).map (result) => @storageManager.storage(result.key).get(result.id)
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
          @storageManager.storage(underscoredModelName).update _(resp[underscoredModelName]).values()

        unless options.cache == false || only?
          @storageManager.getCollectionDetails(name).cache[cacheKey] = results

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