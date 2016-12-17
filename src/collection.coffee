$ = require 'jquery'
_ = require 'underscore'
Backbone = require 'backbone'
Backbone.$ = $ # TODO remove after upgrading to backbone 1.2+

Utils = require './utils'


module.exports = class Collection extends Backbone.Collection

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
    'optionalFields'
    'associationsOptionalFields'
  ]

  @getComparatorWithIdFailover: (order) ->
    [field, direction] = order.split(':')
    comp = @getComparator(field)
    (a, b) ->
      [b, a] = [a, b] if direction.toLowerCase() == 'desc'
      result = comp(a, b)
      if result == 0
        a.get('id') - b.get('id')
      else
        result

  @getComparator: (field) ->
    return (a, b) -> a.get(field) - b.get(field)

  @pickFetchOptions: (options) ->
    _.pick options, @OPTION_KEYS


  #
  # Properties

  lastFetchOptions: null
  firstFetchOptions: null

  model: (attrs, options) ->
    Model = require('./model')
    new Model(attrs, options)


  #
  # Init

  constructor: (models, options) ->
    super

    @storageManager = require('./storage-manager').get()

    @firstFetchOptions = Collection.pickFetchOptions(options) if options
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
    options.returnValues ?= {}

    unless options.name
      Utils.throwError(
        'Either collection must have model with brainstemKey defined or name option must be provided'
      )

    unless @firstFetchOptions
      @firstFetchOptions = Collection.pickFetchOptions options

    Utils.wrapError(this, options)

    loader = @storageManager.loadObject(options.name, _.extend({}, @firstFetchOptions, options))
    xhr = options.returnValues.jqXhr

    @trigger('request', this, xhr, options)

    loader.then(-> loader.internalObject.models)
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
      )
      .then(-> loader.externalObject)
      .promise(xhr)

  refresh: (options = {}) ->
    @fetch _.extend(@lastFetchOptions, options, cache: false)

  setLoaded: (state, options) ->
    options = { trigger: true } unless options? && options.trigger? && !options.trigger
    @loaded = state
    @trigger 'loaded', this if state && options.trigger

  update: (models) ->
    models = models.models if models.models?
    for model in models
      model = this.model.parse(model) if this.model.parse?
      backboneModel = @_prepareModel(model, blacklist: [])
      if backboneModel
        if modelInCollection = @get(backboneModel.id)
          modelInCollection.set backboneModel.attributes
        else
          @add backboneModel
      else
        Utils.warn 'Unable to update collection with invalid model', model

  reload: (options) ->
    @storageManager.reset()
    @reset [], silent: true
    @setLoaded false
    loadOptions = _.extend({}, @lastFetchOptions, options, page: 1, collection: this)
    @storageManager.loadCollection @lastFetchOptions.name, loadOptions

  loadNextPage: (options = {}) ->
    if _.isFunction(options.success)
      success = options.success
      delete options.success

    @getNextPage(_.extend(options, add: true)).done(=> success?(this, @hasNextPage()))

  getPageIndex: ->
    return 1 unless @lastFetchOptions

    if @lastFetchOptions.offset?
      Math.ceil(@lastFetchOptions.offset / @lastFetchOptions.limit) + 1
    else
      @lastFetchOptions.page

  getNextPage: (options = {}) ->
    @getPage(@getPageIndex() + 1, options)

  getPreviousPage: (options = {}) ->
    @getPage(@getPageIndex() - 1, options)

  getFirstPage: (options = {}) ->
    @getPage(1, options)

  getLastPage: (options = {}) ->
    @getPage(Infinity, options)

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

  hasNextPage: ->
    return false unless @_canPaginate()

    if @lastFetchOptions.offset?
      if @_maxOffset() > @lastFetchOptions.offset then true else false
    else
      if @_maxPage() > @lastFetchOptions.page then true else false

  hasPreviousPage: ->
    return false unless @_canPaginate()

    if @lastFetchOptions.offset?
      if @lastFetchOptions.offset > @lastFetchOptions.limit then true else false
    else
      if @lastFetchOptions.page > 1 then true else false

  invalidateCache: ->
    @_getCacheObject()?.valid = false

  toServerJSON: (method) ->
    @map (model) -> _.extend(model.toServerJSON(method), id: model.id)


  #
  # Private

  _canPaginate: (throwError = false) ->
    options = @lastFetchOptions
    count = try @getServerCount()

    throwOrReturn = (message) ->
      if throwError
        Utils.throwError message
      else
        return false

    return throwOrReturn('(pagination) collection must have been fetched once') unless options
    return throwOrReturn('(pagination) collection must have a count') unless count
    return throwOrReturn('(pagination) perPage or limit must be defined') unless options.perPage || options.limit

    true

  _maxOffset: ->
    limit = @lastFetchOptions.limit
    Utils.throwError('(pagination) you must define limit when using offset') if _.isUndefined(limit)
    limit * Math.ceil(@getServerCount() / limit) - limit

  _maxPage: ->
    perPage = @lastFetchOptions.perPage
    Utils.throwError('(pagination) you must define perPage when using page') if _.isUndefined(perPage)
    Math.ceil(@getServerCount() / perPage)

  _getCacheObject: ->
    if @lastFetchOptions
      @storageManager.getCollectionDetails(@lastFetchOptions.name)?.cache[@lastFetchOptions.cacheKey]
