window.Brainstem ?= {}

# TODO: Record access timestamps on all Brainstem.Models by overloading #get and #set.
#    - Keep a sorted list (Heap?) of model references
#    - Clean up the oldest ones if memory is low
#    - Allow passing a recency parameter to the StorageManager

# The StorageManager class is used to manage a set of Brainstem.Collections.  It is responsible for loading data and
# maintaining caches.
class window.Brainstem.StorageManager

  #
  # Init

  constructor: (options = {}) ->
    @collections = {}


  #
  # Accessors

  # Access the cache for a particular collection.
  # manager.storage("time_entries").get(12).get("title")
  storage: (name) ->
    @getCollectionDetails(name).storage

  dataUsage: ->
    sum = 0
    for dataType in @collectionNames()
      sum += @storage(dataType).length
    sum

  # Access details of a collection.  An error will be thrown if the collection cannot be found.
  getCollectionDetails: (name) ->
    @collections[name] || @collectionError(name)

  collectionNames: ->
    _.keys(@collections)

  collectionExists: (name) ->
    !!@collections[name]


  #
  # Control

  # Add a collection to the StorageManager.  All collections that will be loaded or used in associations must be added.
  #    manager.addCollection "time_entries", App.Collections.TimeEntries
  addCollection: (name, collectionClass) ->
    collection = new collectionClass()

    collection.on 'remove', (model) ->
      model.invalidateCache()

    @collections[name] =
      klass: collectionClass
      modelKlass: collectionClass.prototype.model
      storage: collection
      cache: {}

  reset: ->
    for name, attributes of @collections
      attributes.storage.reset []
      attributes.cache = {}

  createNewCollection: (collectionName, models = [], options = {}) ->
    loaded = options.loaded
    delete options.loaded
    collection = new (@getCollectionDetails(collectionName).klass)(models, options)
    collection.setLoaded(true, trigger: false) if loaded
    collection

  createNewModel: (modelName, options) ->
    new (@getCollectionDetails(modelName.pluralize()).modelKlass)(options || {})

  # Request a model to be loaded, optionally ensuring that associations be included as well.
  # A loader (which is a jQuery promise) is returned immediately and is resolved with the model
  # from the StorageManager when the load, and any dependent loads, are complete.
  #     loader = manager.loadModel "time_entry", 2
  #     loader = manager.loadModel "time_entry", 2, fields: ["title", "notes"]
  #     loader = manager.loadModel "time_entry", 2, include: ["project", "task"]
  #     manager.loadModel("time_entry", 2, include: ["project", "task"]).done (model) -> console.log model
  loadModel: (name, id, options = {}) ->
    return if not id

    loader = @loadObject(name, $.extend({}, options, only: id), isCollection: false)
    loader

  # Request a set of data to be loaded, optionally ensuring that associations be
  # included as well.  A collection is returned immediately and is reset
  # when the load, and any dependent loads, are complete.
  #     collection = manager.loadCollection "time_entries"
  #     collection = manager.loadCollection "time_entries", only: [2, 6]
  #     collection = manager.loadCollection "time_entries", fields: ["title", "notes"]
  #     collection = manager.loadCollection "time_entries", include: ["project", "task"]
  #     collection = manager.loadCollection "time_entries", include: ["project:title,description", "task:due_date"]
  #     collection = manager.loadCollection "tasks", include: ["assets", { "assignees": "account" }, { "sub_tasks": ["assignees", "assets"] }]
  #     collection = manager.loadCollection "time_entries", filters: ["project_id:6", "editable:true"], order: "updated_at:desc", page: 1, perPage: 20
  loadCollection: (name, options = {}) ->
    loader = @loadObject(name, options)
    loader.externalObject

  # Helpers
  loadObject: (name, loadOptions = {}, options = {}) ->
    options = $.extend({}, { isCollection: true }, options)

    completeCallback = loadOptions.complete
    successCallback = loadOptions.success
    errorCallback = loadOptions.error

    loadOptions = _.omit(loadOptions, 'success', 'error', 'complete')
    loadOptions = $.extend({}, loadOptions, name: name)

    if options.isCollection
      loaderClass = Brainstem.CollectionLoader
    else
      loaderClass = Brainstem.ModelLoader

    @_checkPageSettings loadOptions

    loader = new loaderClass(storageManager: this)
    loader.setup(loadOptions)

    if completeCallback? && _.isFunction(completeCallback)
      loader.always(completeCallback)

    if successCallback? && _.isFunction(successCallback)
      loader.done(successCallback)

    if errorCallback? && _.isFunction(errorCallback)
      loader.fail(errorCallback)

    if @expectations?
      @handleExpectations(loader)
    else
      loader.load()

    loader

  # Cache model(s) directly into the storage manager. Response should be structured exactly as a
  # brainstem AJAX response. Useful in avoiding unnecessary AJAX request(s) when rendering the page.
  bootstrap: (name, response, loadOptions = {}) ->
    loader = new Brainstem.CollectionLoader storageManager: this
    loader.setup $.extend({}, loadOptions, name: name)
    loader._updateStorageManagerFromResponse response

  collectionError: (name) ->
    Brainstem.Utils.throwError("""
      Unknown collection #{name} in StorageManager. Known collections: #{_(@collections).keys().join(", ")}
    """)


  #
  # Test Helpers

  stub: (collectionName, options = {}) ->
    if @expectations?
      expectation = new Brainstem.Expectation(collectionName, options, this)
      @expectations.push expectation
      expectation
    else
      throw new Error("You must call #enableExpectations on your instance of Brainstem.StorageManager before you can set expectations.")

  stubModel: (modelName, modelId, options = {}) ->
    @stub(modelName, $.extend({}, options, only: modelId))

  stubImmediate: (collectionName, options) ->
    @stub collectionName, $.extend({}, options, immediate: true)

  enableExpectations: ->
    @expectations = []

  handleExpectations: (loader) ->
    for expectation in @expectations
      if expectation.loaderOptionsMatch(loader)
        expectation.recordRequest(loader)
        return
    throw  new Error("No expectation matched #{name} with #{JSON.stringify loader.originalOptions}")


  #
  # Private

  _checkPageSettings: (options) ->
    if options.limit? && options.limit != '' && options.offset? && options.offset != ''
      options.perPage = options.page = undefined
    else
      options.limit = options.offset = undefined

    @_setDefaultPageSettings(options)

  _setDefaultPageSettings: (options) ->
    if options.limit? && options.offset?
      options.limit = 1 if options.limit < 1
      options.offset = 0 if options.offset < 0
    else
      options.perPage = options.perPage || 20
      options.perPage = 1 if options.perPage < 1
      options.page = options.page || 1
      options.page = 1 if options.page < 1
