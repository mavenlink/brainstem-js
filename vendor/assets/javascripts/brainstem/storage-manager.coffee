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
