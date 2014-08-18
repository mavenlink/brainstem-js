#= require ./loading-mixin

class window.Brainstem.Collection extends Backbone.Collection

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


  #
  # Properties

  lastFetchOptions: null
  firstFetchOptions: null


  #
  # Init

  constructor: ->
    super
    @setLoaded false


  #
  # Accessors

  getServerCount: ->
    @_getCacheObject()?.count

  getWithAssocation: (id) ->
    @get(id)


  #
  # Control

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

  invalidateCache: ->
    @_getCacheObject()?.valid = false

  toServerJSON: (method) ->
    @toJSON()


  #
  # Private

  _getCacheObject: ->
    if @lastFetchOptions
      base.data.getCollectionDetails(@lastFetchOptions.name)?.cache[@lastFetchOptions.cacheKey]


# Mixins

_.extend(Brainstem.Collection.prototype, Brainstem.LoadingMixin)
