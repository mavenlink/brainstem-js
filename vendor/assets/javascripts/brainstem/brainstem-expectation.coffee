window.Brainstem ?= {}

class window.Brainstem.Expectation
  constructor: (collectionName, options, manager) ->
    @collectionName = collectionName
    @manager = manager
    @manager.dataLoader._setDefaultPageSettings options
    @options = options
    @results = []
    @matches = []
    @triggerError = options.triggerError
    @immediate = options.immediate
    delete options.immediate
    @associated = {}
    @collections = {}
    @requestQueue = []
    @options.response(@) if @options.response?

  remove: ->
    @disabled = true

  recordRequest: (loader) ->
    if @immediate
      @handleRequest(loader)
    else
      @requestQueue.push(loader)

  respond: ->
    for request in @requestQueue
      @handleRequest request
    @requestQueue = []

  handleRequest: (loader) ->
    @matches.push loader.originalOptions

    if @triggerError?
      return @manager.errorInterceptor(loader.originalOptions.error, loader.externalObject, loader.originalOptions, @triggerError)

    for key, values of @associated
      values = [values] unless values instanceof Array
      for value in values
        @manager.storage(value.brainstemKey).update [value]

    for result in @results
      if result instanceof Brainstem.Model
        @manager.storage(result.brainstemKey).update [result]

    returnedModels = _.map @results, (result) =>
      if result instanceof Brainstem.Model
        @manager.storage(result.brainstemKey).get(result.id)
      else
        @manager.storage(result.key).get(result.id)

    # we don't need to fetch additional things from the server in an expectation.
    loader.loadOptions.include = []

    loader._onLoadSuccess(returnedModels)

  optionsMatch: (name, options) ->
    @manager.dataLoader._checkPageSettings options
    if !@disabled && @collectionName == name
      _(['include', 'only', 'order', 'filters', 'perPage', 'page', 'limit', 'offset', 'search']).all (optionType) =>
        @options[optionType] == "*" || Brainstem.Utils.matches(_.compact(_.flatten([options[optionType]])), _.compact(_.flatten([@options[optionType]])))
    else
      false

  lastMatch: ->
    @matches[@matches.length - 1]