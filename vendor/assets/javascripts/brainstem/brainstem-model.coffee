#= require ./loading-mixin

# Extend Backbone.Model to include associations.
class window.Brainstem.Model extends Backbone.Model

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
            type: "BelongsTo"
            collectionName: associator
            key: "#{association}_ref"
            polymorphic: true
          }
        else if isArray
          {
            type: "HasMany"
            collectionName: associator[0]
            key: "#{association.singularize()}_ids"
          }
        else
          {
            type: "BelongsTo"
            collectionName: associator
            key: "#{association}_id"
          }

  # Parse ISO8601 attribute strings into date objects
  @parse: (modelObject) ->
    for k,v of modelObject
      # Date.parse will parse ISO 8601 in ECMAScript 5, but we include a shim for now
      if /^\d{4}-\d{2}-\d{2}T\d{2}\:\d{2}\:\d{2}[-+]\d{2}:\d{2}$/.test(v)
        modelObject[k] = Date.parse(v)
    return modelObject


  #
  # Accessors

  # Override Model#get to access associations as well as fields.
  get: (field, options = {}) ->
    if details = @constructor.associationDetails(field)
      if details.type == "BelongsTo"
        pointer = super(details.key) # project_id
        if pointer
          if details.polymorphic
            id = pointer.id
            collectionName = pointer.key
          else
            id = pointer
            collectionName = details.collectionName

          model = base.data.storage(collectionName).get(pointer)

          if not model && not options.silent
            Brainstem.Utils.throwError("Unable to find #{field} with id #{id} in our cached #{details.collectionName} collection.  We know about #{base.data.storage(details.collectionName).pluck("id").join(", ")}")

          model
      else
        ids = super(details.key) # time_entry_ids
        models = []
        notFoundIds = []
        if ids
          for id in ids
            model = base.data.storage(details.collectionName).get(id)
            models.push(model)
            notFoundIds.push(id) unless model
          if notFoundIds.length && not options.silent
            Brainstem.Utils.throwError("Unable to find #{field} with ids #{notFoundIds.join(", ")} in our cached #{details.collectionName} collection.  We know about #{base.data.storage(details.collectionName).pluck("id").join(", ")}")
        if options.order
          comparator = base.data.getCollectionDetails(details.collectionName).klass.getComparatorWithIdFailover(options.order)
          collectionOptions = { comparator: comparator }
        else
          collectionOptions = {}
        if options.link
          @_linkCollection(details.collectionName, models, collectionOptions, field)
        else
          base.data.createNewCollection(details.collectionName, models, collectionOptions)
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

    unless options.name
      Brainstem.Utils.throwError('Either model must have a brainstemKey defined or name option must be provided')

    Brainstem.Utils.wrapError(this, options)

    base.data.loadObject(options.name, options, isCollection: false)
      .done((response) =>
        @trigger('sync', response, options)
      )
      .promise(options.returnValues.jqXhr)

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
        collection = base.data.storage(underscoredModelName)
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

      if details.type == "BelongsTo"
        if pointer == null
          true
        else if details.polymorphic
          base.data.storage(pointer.key).get(pointer.id)
        else
          base.data.storage(details.collectionName).get(pointer)
      else
        _.all pointer, (id) ->
          base.data.storage(details.collectionName).get(id)

  invalidateCache: ->
    for cacheKey, cacheObject of base.data.getCollectionDetails(@brainstemKey).cache
      if _.find(cacheObject.results, (result) => result.id == @id)
        cacheObject.valid = false

  toServerJSON: (method, options) ->
    json = @toJSON(options)
    blacklist = @defaultJSONBlacklist()

    switch method
      when "create"
        blacklist = blacklist.concat @createJSONBlacklist()
      when "update"
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
      @_associatedCollections[field] = base.data.createNewCollection(collectionName, models, collectionOptions)
      @_associatedCollections[field].on 'add', => @_onAssociatedCollectionChange.call(this, field, arguments)
      @_associatedCollections[field].on 'remove', => @_onAssociatedCollectionChange.call(this, field, arguments)
      
    @_associatedCollections[field]

  _onAssociatedCollectionChange: (field, collectionChangeDetails) =>
    @attributes[@constructor.associationDetails(field).key] = collectionChangeDetails[1].pluck('id')
