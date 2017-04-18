_ = require 'underscore'
$ = require 'jquery'
Backbone = require 'backbone'
Backbone.$ = require 'jquery' # TODO remove after upgrading to backbone 1.2+
inflection = require 'inflection'

Utils = require './utils'
StorageManager = require './storage-manager'


isDateAttr = (key) ->
  key.indexOf('date') > -1 || /_at$/.test(key)

class Model extends Backbone.Model

  #
  # Properties

  @OPTION_KEYS =  ['name', 'include', 'cacheKey']


  #
  # Class Methods

  # Retreive details about a named association.  This is a class method.
  #     Model.associationDetails("project") # => {}
  #     timeEntry.constructor.associationDetails("project") # => {}
  @associationDetails: (association) ->
    @associationDetailsCache ||= {}
    if @associations && @associations[association]
      @associationDetailsCache[association] ||= do =>
        associator = @associations[association]
        isArray = _.isArray associator
        if isArray && associator.length > 1
          {
            type: 'BelongsTo'
            collectionName: associator
            key: "#{association}_ref"
            polymorphic: true
          }
        else if isArray
          {
            type: 'HasMany'
            collectionName: associator[0]
            key: "#{inflection.singularize(association)}_ids"
          }
        else
          {
            type: 'BelongsTo'
            collectionName: associator
            key: "#{association}_id"
          }

  # Parse ISO8601 attribute strings into date objects
  @parse: (modelObject) ->
    for k,v of modelObject
      # Date.parse will parse ISO 8601 in ECMAScript 5, but we include a shim for now
      if isDateAttr(k) && /^\d{4}-\d{2}-\d{2}T\d{2}\:\d{2}\:\d{2}[-+]\d{2}:\d{2}$/.test(v)
        modelObject[k] = Date.parse(v)
    return modelObject


  #
  # Init

  constructor: (attributes = {}, options = {}) ->
    @storageManager = StorageManager.get()

    try cache = @storageManager.storage(@brainstemKey)

    if options.cached != false && attributes.id && @brainstemKey && cache
      existing = cache.get(attributes.id)
      blacklist = options.blacklist || @_associationKeyBlacklist()
      valid = existing?.set(_.omit(attributes, blacklist))

      return existing if valid

    super

  _associationKeyBlacklist: ->
    return [] unless @constructor.associations

    _.chain(@constructor.associations)
      .keys()
      .map((association) => @constructor.associationDetails(association).key)
      .value()


  #
  # Accessors

  # Override Model#get to access associations as well as fields.
  get: (field, options = {}) ->
    if details = @constructor.associationDetails(field)
      if details.type == 'BelongsTo'
        pointer = super(details.key) # project_id
        if pointer
          if details.polymorphic
            id = pointer.id
            collectionName = pointer.key
          else
            id = pointer
            collectionName = details.collectionName

          model = @storageManager.storage(collectionName).get(pointer)

          if not model && not options.silent
            Utils.throwError("""
              Unable to find #{field} with id #{id} in our cached {details.collectionName} collection.
              We know about #{@storageManager.storage(details.collectionName).pluck('id').join(', ')}
            """)

          model
      else
        ids = super(details.key) # time_entry_ids
        models = []
        notFoundIds = []
        if ids
          for id in ids
            model = @storageManager.storage(details.collectionName).get(id)
            models.push(model)
            notFoundIds.push(id) unless model
          if notFoundIds.length && not options.silent
            Utils.throwError("""
              Unable to find #{field} with ids #{notFoundIds.join(', ')} in our
              cached #{details.collectionName} collection.  We know about
              #{@storageManager.storage(details.collectionName).pluck('id').join(', ')}
            """)
        if options.order
          klass = @storageManager.getCollectionDetails(details.collectionName).klass
          comparator = klass.getComparatorWithIdFailover(options.order)
          collectionOptions = { comparator: comparator }
        else
          collectionOptions = {}
        if options.link
          @_linkCollection(details.collectionName, models, collectionOptions, field)
        else
          @storageManager.createNewCollection(details.collectionName, models, collectionOptions)
    else
      super(field)

  className: ->
    @paramRoot


  #
  # Control

  fetch: (options) ->
    options = if options then _.clone(options) else {}

    id = @id || options.id

    options.only = [id] if id
    options.parse = options.parse ? true
    options.name = options.name ? @brainstemKey
    options.cache = false
    options.returnValues ?= {}
    options.model = this

    unless options.name
      Utils.throwError('Either model must have a brainstemKey defined or name option must be provided')

    Utils.wrapError(this, options)

    @storageManager.loadObject(options.name, options, isCollection: false)
      .done((response) =>
        @trigger('sync', response, options)
      )
      .promise(options.returnValues.jqXhr)

  destroy: (options = {}) ->
    cleanUpAssociatedReferences = =>
      _.each @storageManager.collections, (collection) ->
        _.each collection.modelKlass.associations, (associator, reference) ->
          associationKey = collection.modelKlass.associationDetails(reference).key
          if @_collectionHasMany(associator)
            collection.storage.each (model) ->
              model.set(associationKey, _.without(model.get(associationKey), @id))
            , this
          else if @_collectionBelongsTo(associator)
            collection.storage.each (model) ->
              model.unset(associationKey) if model.get(associationKey) == @id
            , this
        , this
      , this

    @listenTo this, 'destroy', cleanUpAssociatedReferences
    super(options)

  # Handle create and update responses with JSON root keys
  parse: (resp, xhr) ->
    @updateStorageManager(resp)
    modelObject = @_parseResultsResponse(resp)
    super(@constructor.parse(modelObject), xhr)

  updateStorageManager: (resp) ->
    results = resp['results']
    return if _.isEmpty(results)

    keys = _.reject(_.keys(resp), (key) -> key == 'count' || key == 'results')
    primaryModelKey = results[0]['key']
    keys.splice(keys.indexOf(primaryModelKey), 1)
    keys.push(primaryModelKey)

    for underscoredModelName in keys
      models = resp[underscoredModelName]
      for id, attributes of models
        @constructor.parse(attributes)
        collection = @storageManager.storage(underscoredModelName)
        collectionModel = collection.get(id)
        if collectionModel
          collectionModel.set(attributes)
        else
          if @brainstemKey == underscoredModelName && (@isNew() || @id == attributes.id)
            @set(attributes)
            collection.add(this)
          else
            collection.add(attributes)

  dependenciesAreLoaded: (loadOptions) ->
    @associationsAreLoaded(loadOptions.thisLayerInclude) && @optionalFieldsAreLoaded(loadOptions.optionalFields)

  optionalFieldsAreLoaded: (optionalFields) ->
    return true unless optionalFields?
    _.all optionalFields, (optionalField) => @attributes.hasOwnProperty(optionalField)

  # This method determines if all of the provided associations have been loaded for this model.  If no associations are
  # provided, all associations are assumed.
  #   model.associationsAreLoaded(["project", "task"]) # => true|false
  #   model.associationsAreLoaded() # => true|false
  associationsAreLoaded: (associations) ->
    associations ||= _.keys(@constructor.associations)
    associations = _.filter associations, (association) => @constructor.associationDetails(association)

    _.all associations, (association) =>
      details = @constructor.associationDetails association
      key = details.key

      return false unless _(@attributes).has key

      pointer = @attributes[key]

      if details.type == 'BelongsTo'
        if pointer == null
          true
        else if details.polymorphic
          @storageManager.storage(pointer.key).get(pointer.id)
        else
          @storageManager.storage(details.collectionName).get(pointer)
      else
        _.all pointer, (id) =>
          @storageManager.storage(details.collectionName).get(id)

  setLoaded: (state, options) ->
    options = { trigger: true } unless options? && options.trigger? && !options.trigger
    @loaded = state
    @trigger 'loaded', this if state && options.trigger

  invalidateCache: ->
    for cacheKey, cacheObject of @storageManager.getCollectionDetails(@brainstemKey).cache
      if _.find(cacheObject.results, (result) => result.id == @id)
        cacheObject.valid = false

  toServerJSON: (method, options) ->
    json = @toJSON(options)
    blacklist = @defaultJSONBlacklist()

    switch method
      when 'create'
        blacklist = blacklist.concat @createJSONBlacklist()
      when 'update'
        if this.useUpdateWhitelist && this.get('update_whitelist')
          blacklist = _.difference(Object.keys(this.attributes), this.get('update_whitelist'))
        else
          blacklist = blacklist.concat @updateJSONBlacklist()

    for blacklistKey in blacklist
      delete json[blacklistKey]

    json

  defaultJSONBlacklist: ->
    ['id', 'created_at', 'updated_at']

  createJSONBlacklist: ->
    []

  updateJSONBlacklist: ->
    []


  #
  # Private

  clone: ->
    new this.constructor(this.attributes, { cached: false })

  _parseResultsResponse: (resp) ->
    return resp unless resp['results']

    if resp['results'].length
      key = resp['results'][0].key
      id = resp['results'][0].id
      resp[key][id]
    else
      {}

  _linkCollection: (collectionName, models, collectionOptions, field) ->
    @_associatedCollections ?= {}

    unless @_associatedCollections[field]
      @_associatedCollections[field] = @storageManager.createNewCollection(collectionName, models, collectionOptions)
      @_associatedCollections[field].on 'add', => @_onAssociatedCollectionChange.call(this, field, arguments)
      @_associatedCollections[field].on 'remove', => @_onAssociatedCollectionChange.call(this, field, arguments)

    @_associatedCollections[field]

  _onAssociatedCollectionChange: (field, collectionChangeDetails) =>
    @attributes[@constructor.associationDetails(field).key] = collectionChangeDetails[1].pluck('id')

  _collectionHasMany: (associator) ->
    _.isArray(associator) &&
    _.find(associator, (collectionName) => inflection.singularize(collectionName) == @className())

  _collectionBelongsTo: (associator) ->
    !_.isArray(associator) && inflection.singularize(associator) == @className()

module.exports = Model
