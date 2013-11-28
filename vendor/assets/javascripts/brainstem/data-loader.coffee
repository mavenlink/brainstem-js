window.Brainstem ?= {}

class Brainstem.DataLoader
  constructor: (options = {}) ->
    @storageManager = options.storageManager

  # Request a model to be loaded, optionally ensuring that associations be included as well.  A collection is returned immediately and is reset
  # when the load, and any dependent loads, are complete.
  #     model = manager.loadModel "time_entry"
  #     model = manager.loadModel "time_entry", fields: ["title", "notes"]
  #     model = manager.loadModel "time_entry", include: ["project", "task"]
  loadModel: (name, id, options = {}) ->
    options = $.extend({}, options, name: name, only: id)
    @_checkPageSettings options
    
    ml = new Brainstem.ModelLoader(storageManager: @storageManager)
    ml.setup(options)
    ml.load()

  # Request a set of data to be loaded, optionally ensuring that associations be included as well.  A collection is returned immediately and is reset
  # when the load, and any dependent loads, are complete.
  #     collection = manager.loadCollection "time_entries"
  #     collection = manager.loadCollection "time_entries", only: [2, 6]
  #     collection = manager.loadCollection "time_entries", fields: ["title", "notes"]
  #     collection = manager.loadCollection "time_entries", include: ["project", "task"]
  #     collection = manager.loadCollection "time_entries", include: ["project:title,description", "task:due_date"]
  #     collection = manager.loadCollection "tasks",      include: ["assets", { "assignees": "account" }, { "sub_tasks": ["assignees", "assets"] }]
  #     collection = manager.loadCollection "time_entries", filters: ["project_id:6", "editable:true"], order: "updated_at:desc", page: 1, perPage: 20
  loadCollection: (name, options = {}) ->
    options = $.extend({}, options, name: name)
    @_checkPageSettings options

    cl = new Brainstem.CollectionLoader(storageManager: @storageManager)
    collection = cl.setup(options)

    if @storageManager.expectations?
      @storageManager.handleExpectations name, collection, options
    else
      cl.load()

    collection

  # Helpers

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