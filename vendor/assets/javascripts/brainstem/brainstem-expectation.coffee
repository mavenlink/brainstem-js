window.Brainstem ?= {}

class window.Brainstem.Expectation
  constructor: (name, options, manager) ->
    @name = name
    @manager = manager
    @manager._setDefaultPageSettings options
    @options = options
    @matches = []
    @recursive = false
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

    unless @recursive
      # we don't need to fetch additional things from the server in an expectation.
      loader.loadOptions.include = []

    if @triggerError?
      loader._onServerLoadError(@triggerError)

    @_handleAssociations(loader)

    if loader instanceof Brainstem.CollectionLoader
      returnedData = @_handleCollectionResults(loader)
    else
      returnedData = @_handleModelResults(loader)

    loader._onLoadSuccess(returnedData)

  loaderOptionsMatch: (loader) ->
    return false if @disabled
    return false if @name != loader._getExpectationName()

    @manager._checkPageSettings(loader.originalOptions)

    _.all ['include', 'only', 'order', 'filters', 'perPage', 'page', 'limit', 'offset', 'search'], (optionType) =>
      return true if @options[optionType] == '*'

      option = _.compact(_.flatten([loader.originalOptions[optionType]]))
      expectedOption = _.compact(_.flatten([@options[optionType]]))

      if optionType == 'include'
        option = Brainstem.Utils.wrapObjects(option)
        expectedOption = Brainstem.Utils.wrapObjects(expectedOption)

      Brainstem.Utils.matches(option, expectedOption)

  _handleAssociations: (_loader) ->
    for key, values of @associated
      values = [values] unless values instanceof Array
      for value in values
        @manager.storage(value.brainstemKey).update [value]

  _handleCollectionResults: (loader) ->
    return if not @results

    for result in @results
      if result instanceof Brainstem.Model
        @manager.storage(result.brainstemKey).update [result]

    returnedModels = _.map @results, (result) =>
      if result instanceof Brainstem.Model
        @manager.storage(result.brainstemKey).get(result.id)
      else
        @manager.storage(result.key).get(result.id)

    returnedModels

  _handleModelResults: (loader) ->
    return if !@result

    # Put main (loader) model in storage manager.
    if @result instanceof Brainstem.Model
      key = @result.brainstemKey
      attributes = @result.attributes
    else
      key = @result.key
      attributes = _.omit @result, 'key'

    if !key
      throw 'Brainstem key is required on the result (brainstemKey on model or key in JSON)'

    existingModel = @manager.storage(key).get(attributes.id)

    unless existingModel
      existingModel = loader.getModel()
      @manager.storage(key).add(existingModel)

    existingModel.set(attributes)
    existingModel

  lastMatch: ->
    @matches[@matches.length - 1]