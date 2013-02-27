window.Brainstem ?= {}

class window.Brainstem.Expectation
  constructor: (collectionName, options, manager) ->
    @collectionName = collectionName
    @manager = manager
    @manager._checkPageSettings options
    @options = options
    @results = []
    @matches = []
    @immediate = options.immediate
    delete options.immediate
    @associated = {}
    @collections = {}
    @requestQueue = []
    @options.response(@) if @options.response?

  remove: =>
    @disabled = true

  recordRequest: (collection, callOptions) =>
    if @immediate
      @handleRequest collection: collection, callOptions: callOptions
    else
      @requestQueue.push collection: collection, callOptions: callOptions

  respond: =>
    for request in @requestQueue
      @handleRequest request
    @requestQueue = []

  handleRequest: (options) =>
    @matches.push options.callOptions

    for key, values of @associated
      values = [values] unless values instanceof Array
      for value in values
        @manager.storage(value.brainstemKey).update [value]

    for result in @results
      if result instanceof Brainstem.Model
        @manager.storage(result.brainstemKey).update [result]

    returnedModels = _(@results).map (result) =>
      if result instanceof Brainstem.Model
        @manager.storage(result.brainstemKey).get(result.id)
      else
        @manager.storage(result.key).get(result.id)

    @manager._success(options.callOptions, options.collection, returnedModels)

  optionsMatch: (name, options) =>
    if !@disabled && @collectionName == name
      _(['include', 'only', 'fields', 'order', 'filters', 'perPage', 'page', 'search']).all (optionType) =>
        @options[optionType] == "*" || options[optionType] == @options[optionType] || Brainstem.Utils.matchesArray(_.compact(_.flatten([options[optionType]])), _.compact(_.flatten([@options[optionType]])))
    else
      false

  lastMatch: ->
    @matches[@matches.length - 1]