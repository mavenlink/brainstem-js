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
      @storageManager._loadCollectionWithFirstLayer($.extend({}, options, include: include, success: ((firstLayerCollection) =>
        expectedAdditionalLoads = @storageManager._countRequiredServerRequests(include) - 1
        if expectedAdditionalLoads > 0
          timesCalled = 0
          @storageManager._handleNextLayer collection: firstLayerCollection, include: include, error: options.error, success: =>
            timesCalled += 1
            if timesCalled == expectedAdditionalLoads
              @storageManager._success(options, collection, firstLayerCollection)
        else
          @storageManager._success(options, collection, firstLayerCollection)
      )))

    collection