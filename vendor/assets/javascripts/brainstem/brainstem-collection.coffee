#= require ./loading-mixin

class window.Brainstem.Collection extends Backbone.Collection

  # 
  # Properties

  # Properties that form the firstFetchOptions object on instantianion.  Subsequent 
  #  calls to fetch with an options object that contains these properties will update the
  #  lastFetchOptions object.
  @OPTION_KEYS = [
    'name'
    'include'
    'filters'
    'page'
    'perPage'
    'limit'
    'offset'
    'order'
    'search'
    'cache'
    'cacheKey'
  ]


  #
  # Class Methods

  # Returns a collection comparator using the provided options.  If the two sorting values
  #   are equal, the comparator will default to a model's id.
  # 
  # @example Sort by property {duration} in descending order
  #   Collections.Tasks.getComparatorWithIdFailover('duration:desc') # sorts descending duration
  # @param [String] order Attribute to use for ordering.  Syntax of order is a ```{property}:{direction}``` 
  @getComparatorWithIdFailover: (order) ->
    [field, direction] = order.split(":")
    comp = @getComparator(field)
    (a, b) ->
      [b, a] = [a, b] if direction.toLowerCase() == "desc"
      result = comp(a, b)
      if result == 0
        a.get('id') - b.get('id')
      else
        result
  
  # Returns a comparator function.  Assumes the ```field``` value on the model's attributes
  #   is a number.
  @getComparator: (field) ->
    return (a, b) -> a.get(field) - b.get(field)

  # Picks only options related to a fetch operation out of the passed object
  @pickFetchOptions: (options) ->
    _.pick options, @OPTION_KEYS


  #
  # Properties

  lastFetchOptions: null
  firstFetchOptions: null


  #
  # Init

  # Constructor delegates to Backbone#Collection.  The collection has an internal flag, {setLoaded}
  #   to denote whether or not the collection has been fetched from the server yet.
  # 
  # @param [Array] models An array of Brainstem Models that the collection will contain.  These 
  #   models will be set on the collection by Backbone.
  # @param [Object] options An options object.  A number of these properties are used as fetch options.
  # @see {window.Brainstem.Collection#OPTION_KEYS} Properties that are picked for firstFetchOptions from the options object
  constructor: (models, options) ->
    super
    @firstFetchOptions = Brainstem.Collection.pickFetchOptions(options) if options
    @setLoaded false


  #
  # Accessors

  # @return [Integer] Total number of models stored on the server that match 
  #   the collections most recent fetch options.
  getServerCount: ->
    @_getCacheObject()?.count

  # ???
  getWithAssocation: (id) ->
    @get(id)


  #
  # Control

  fetch: (options) ->
    options = if options then _.clone(options) else {}
    
    options.parse = options.parse ? true
    options.name = options.name ? @model?.prototype.brainstemKey
    options.returnValues ?= {}

    unless options.name
      Brainstem.Utils.throwError(
        'Either collection must have model with brainstemKey defined or name option must be provided'
      )

    unless @firstFetchOptions
      @firstFetchOptions = Brainstem.Collection.pickFetchOptions options

    Brainstem.Utils.wrapError(this, options)

    loader = base.data.loadObject(options.name, _.extend({}, @firstFetchOptions, options))
    
    @trigger('request', this, options.returnValues.jqXhr, options)

    loader.pipe(-> loader.internalObject.models)
      .done((response) =>
        @lastFetchOptions = loader.externalObject.lastFetchOptions

        if options.add
          method = 'add'
        else if options.reset
          method = 'reset'
        else
          method = 'set'

        @[method](response, options)

        @trigger('sync', this, response, options)
      ).promise()

  # Calls #fetch with the lastFetchOptions object.  By default, cache is set to false.
  # 
  # @param [Object] options Options object.  See #fetch for options.
  # 
  # @see {Brainstem.Collection#fetch]} Fetch options object.
  refresh: (options = {}) ->
    @fetch _.extend(@lastFetchOptions, options, cache: false)

  # Manually update the collection with an array of new models.  For each model, 
  #   if the collection does not contain the model it will be #added.  If the model already
  #   exists in the collection it will be #set with the new model's attributes.
  # 
  # @param [Array] models Array of models to update the collection with.
  update: (models) ->
    models = models.models if models.models?
    for model in models
      model = this.model.parse(model) if this.model.parse?
      backboneModel = @_prepareModel(model)
      if backboneModel
        if modelInCollection = @get(backboneModel.id)
          modelInCollection.set backboneModel.attributes
        else
          @add backboneModel
      else
        Brainstem.Utils.warn "Unable to update collection with invalid model", model

  # Reset the collection, removing all models contained within the collection.  
  #   The collection then fetches itself with its lastFetchOptions.
  reload: (options) ->
    base.data.reset()
    @reset [], silent: true
    @setLoaded false
    loadOptions = _.extend({}, @lastFetchOptions, options, page: 1, collection: this)
    base.data.loadCollection @lastFetchOptions.name, loadOptions

  # Loads the next page of data.  Uses default options provided by 
  # 
  # @param [Object] options Options object
  # @option options [Function] success Success callback.
  loadNextPage: (options = {}) ->
    if _.isFunction(options.success)
      success = options.success
      delete options.success

    @getNextPage(_.extend(options, add: true)).done(=> success?(this, @hasNextPage()))

  # Returns the current page index of the collection.  If the collection has not yet
  #   been fetched the page defaults to 0.
  # 
  # @return [Integer] current page index of the collection.
  getPageIndex: ->
    return 1 unless @lastFetchOptions

    if @lastFetchOptions.offset?
      Math.ceil(@lastFetchOptions.offset / @lastFetchOptions.limit) + 1
    else
      @lastFetchOptions.page

  # Fetches the next page of the collection
  #  
  # @param [object] Fetch options
  # 
  # @return [jQuery Promise] Promise object. 
  # @see {window.Brainstem.Collection#fetch} See #fetch for fetch options
  getNextPage: (options = {}) ->
    @getPage(@getPageIndex() + 1, options)

  # Fetches the previous page of the collection
  #  
  # @param [object] Fetch options
  # 
  # @return [jQuery Promise] Promise object. 
  # @see {window.Brainstem.Collection#fetch} See #fetch for fetch options
  getPreviousPage: (options = {}) ->
    @getPage(@getPageIndex() - 1, options)

  # Fetches the first page of the collection
  #  
  # @param [Object] Fetch options
  # 
  # @return [jQuery Promise] Promise object. 
  # @see {window.Brainstem.Collection#fetch} See #fetch for fetch options
  getFirstPage: (options = {}) ->
    @getPage(1, options)

  # Fetches the last page of the collection
  #  
  # @param [Object] Fetch options
  # 
  # @return [jQuery Promise] Promise object. 
  # @see {window.Brainstem.Collection#fetch} See #fetch for fetch options
  getLastPage: (options = {}) ->
    @getPage(Infinity, options)

  # Fetches a specific page of the collection
  #  
  # @param [Integer]
  # @param [Object] Fetch options
  # 
  # @return [jQuery Promise] Promise object. 
  # @see {window.Brainstem.Collection#fetch} See #fetch for fetch options
  getPage: (index, options = {}) ->
    @_canPaginate(true)

    options = _.extend(options, @lastFetchOptions)

    index = 1 if index < 1

    if @lastFetchOptions.offset?
      max = @_maxOffset()
      offset = @lastFetchOptions.limit * index - @lastFetchOptions.limit
      options.offset = if offset < max then offset else max
    else
      max = @_maxPage()
      options.page = if index < max then index else max

    @fetch _.extend(options, { reset: true })
    
  # @return [Boolean] True if the collection has a next page that it can fetch.
  hasNextPage: ->
    return false unless @_canPaginate()

    if @lastFetchOptions.offset?
      if @_maxOffset() > @lastFetchOptions.offset then true else false
    else
      if @_maxPage() > @lastFetchOptions.page then true else false

  # @return [Boolean] True if the collection has a previous page that it can fetch.
  hasPreviousPage: ->
    return false unless @_canPaginate()

    if @lastFetchOptions.offset?
      if @lastFetchOptions.offset > @lastFetchOptions.limit then true else false
    else
      if @lastFetchOptions.page > 1 then true else false

  # ???
  invalidateCache: ->
    @_getCacheObject()?.valid = false

  # @return [Object] Returns a JSON representation of all the models of the collection.
  toServerJSON: (method) ->
    @toJSON()


  #
  # Private

  _canPaginate: (throwError = false) ->
    options = @lastFetchOptions
    count = try @getServerCount()

    throwOrReturn = (message) ->
      if throwError
        Brainstem.Utils.throwError message
      else
        return false

    return throwOrReturn('(pagination) collection must have been fetched once') unless options
    return throwOrReturn('(pagination) collection must have a count') unless count
    return throwOrReturn('(pagination) perPage or limit must be defined') unless options.perPage || options.limit

    true

  _maxOffset: ->
    limit = @lastFetchOptions.limit
    Brainstem.Utils.throwError('(pagination) you must define limit when using offset') if _.isUndefined(limit)
    limit * Math.ceil(@getServerCount() / limit) - limit

  _maxPage: ->
    perPage = @lastFetchOptions.perPage
    Brainstem.Utils.throwError('(pagination) you must define perPage when using page') if _.isUndefined(perPage)
    Math.ceil(@getServerCount() / perPage)

  _getCacheObject: ->
    if @lastFetchOptions
      base.data.getCollectionDetails(@lastFetchOptions.name)?.cache[@lastFetchOptions.cacheKey]


# Mixins

_.extend(Brainstem.Collection.prototype, Brainstem.LoadingMixin)
