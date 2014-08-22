#= require ./loading-mixin

class window.Brainstem.Collection extends Backbone.Collection

  @OPTION_KEYS = ['name', 'filters', 'page', 'perPage', 'limit', 'offset', 'order', 'search', 'cacheKey']

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

  @getComparator: (field) ->
    return (a, b) -> a.get(field) - b.get(field)

  @pickFetchOptions: (options) ->
    _.pick options, Brainstem.Collection.OPTION_KEYS


  #
  # Properties

  lastFetchOptions: null
  firstFetchOptions: null


  #
  # Init

  constructor: (models, options) ->
    super
    @firstFetchOptions = Brainstem.Collection.pickFetchOptions(options) if options
    @setLoaded false


  #
  # Accessors

  getServerCount: ->
    @_getCacheObject()?.count

  getWithAssocation: (id) ->
    @get(id)


  #
  # Control

  fetch: (options) ->
    options = if options then _.clone(options) else {}
    
    options.parse = options.parse ? true
    options.name = options.name ? @model?.prototype.brainstemKey

    unless options.name
      Brainstem.Utils.throwError(
        'Either collection must have model with brainstemKey defined or name option must be provided'
      )

    unless @firstFetchOptions
      @firstFetchOptions = Brainstem.Collection.pickFetchOptions options

    Brainstem.Utils.wrapError(this, options)

    loader = base.data.loadObject(options.name, _.extend(@firstFetchOptions, options))
    
    loader.pipe(-> loader.internalObject.models)
      .done((response) =>
        method = if options.reset then 'reset' else 'set'
        @[method](response, options)
        @lastFetchOptions = loader.externalObject.lastFetchOptions

        @trigger('sync', this, response, options)
      ).promise()

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

  reload: (options) ->
    base.data.reset()
    @reset [], silent: true
    @setLoaded false
    loadOptions = _.extend({}, @lastFetchOptions, options, page: 1, collection: this)
    base.data.loadCollection @lastFetchOptions.name, loadOptions

  loadNextPage: (options) ->
    oldLength = @length
    pageSize = 0
    paginationOptions = {}

    if @lastFetchOptions.perPage
      paginationOptions.page = @lastFetchOptions.page + 1
      pageSize = @lastFetchOptions.perPage
    else
      paginationOptions.offset = @lastFetchOptions.offset + @lastFetchOptions.limit
      pageSize = @lastFetchOptions.limit

    success = (collection) ->
      options.success(collection, collection.length == oldLength + pageSize) if options.success?

    fetchOptions = _.extend({}, @lastFetchOptions, options, paginationOptions, collection: this, success: success)
    base.data.loadCollection @lastFetchOptions.name, fetchOptions

  getFirstPage: (options = {}) ->
    @getPage(1, options)

  getLastPage: (options = {}) ->
    @getPage(Infinity, options)

  getPage: (index, options = {}) ->
    @_canPaginate()

    options = _.extend(options, @lastFetchOptions)
    options.reset ?= true

    index = 1 if index < 1

    unless _.isUndefined(@lastFetchOptions.offset)
      max = @_maxOffset()
      offset = @lastFetchOptions.limit * index - @lastFetchOptions.limit
      options.offset = if offset < max then offset else max
    else
      max = @_maxPage()
      options.page = if index < max then index else max

    @fetch(options)

  invalidateCache: ->
    @_getCacheObject()?.valid = false

  toServerJSON: (method) ->
    @toJSON()


  #
  # Private

  _canPaginate: ->
    options = @lastFetchOptions
    throwError = Brainstem.Utils.throwError

    throwError('(pagination) collection must have been fetched once') unless options
    throwError('(pagination) perPage or limit must be defined') unless options.perPage || options.limit

  _maxOffset: ->
    limit = @lastFetchOptions.limit
    Brainstem.Utils.throwError('(pagination) you must define limit when using offset') unless limit
    limit * Math.ceil(@getServerCount() / limit) - limit

  _maxPage: ->
    perPage = @lastFetchOptions.perPage
    Brainstem.Utils.throwError('(pagination) you must define perPage when using page') unless perPage
    Math.ceil(@getServerCount() / perPage)

  _getCacheObject: ->
    if @lastFetchOptions
      base.data.getCollectionDetails(@lastFetchOptions.name)?.cache[@lastFetchOptions.cacheKey]


# Mixins

_.extend(Brainstem.Collection.prototype, Brainstem.LoadingMixin)
