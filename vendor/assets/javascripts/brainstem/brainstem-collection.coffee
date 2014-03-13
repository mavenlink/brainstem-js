#= require ./loading-mixin

class window.Brainstem.Collection extends Backbone.Collection
  constructor: ->
    super
    @setLoaded false

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

    success = (collection) =>
      options.success(collection, collection.length == oldLength + pageSize) if options.success?
    base.data.loadCollection @lastFetchOptions.name, _.extend({}, @lastFetchOptions, options, paginationOptions, collection: this, success: success)

  reload: (options) ->
    base.data.reset()
    @reset [], silent: true
    @setLoaded false
    base.data.loadCollection @lastFetchOptions.name, _.extend({}, @lastFetchOptions, options, page: 1, collection: this)

  getWithAssocation: (id) ->
    @get(id)

  getServerCount: ->
    if @lastFetchOptions
      base.data.getCollectionDetails(@lastFetchOptions.name)?.cache[@lastFetchOptions.cacheKey]?.count

  toServerJSON: (method) ->
    @toJSON()

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

_.extend(Brainstem.Collection.prototype, Brainstem.LoadingMixin);