#= require ./loading-mixin

# Extend Backbone.Model to include associations.
class window.Brainstem.Model extends Backbone.Model
  constructor: ->
    super
    @setLoaded false

  # class method to parse ISO8601 dates into seconds since epoch
  @parse: (modelObject) ->
    for k,v of modelObject
      # Date.parse will support ISO 8601 natively in ECMAScript 5, this uses a shim
      if /\d{4}-\d{2}-\d{2}T\d{2}\:\d{2}\:\d{2}[-+]\d{2}:\d{2}/.test(v)
        # ruby times were seconds, not ms, so we convert to seconds here
        modelObject[k] = (Date.parse(v) / 1000)
    return modelObject

  # Handle create and update responses with JSON root keys
  parse: (resp, xhr) =>
    modelObject = resp[this.paramRoot.pluralize()]?[0] || resp
    super(this.constructor.parse(modelObject), xhr)

  # Retreive details about a named association.  This is a class method.
  #     Model.associationDetails("project") # => {}
  #     timeEntry.constructor.associationDetails("project") # => {}
  @associationDetails: (association) ->
    @associationDetailsCache ||= {}
    if @associations && @associations[association]
      @associationDetailsCache[association] ||= do =>
        if @associations[association] instanceof Array
          {
            type: "HasMany"
            collectionName: @associations[association][0]
            key: "#{association.singularize()}_ids"
          }
        else
          {
            type: "BelongsTo"
            collectionName: @associations[association]
            key: "#{association}_id"
          }

  # This method determines if all of the provided associations have been loaded for this model.  If no associations are
  # provided, all associations are assumed.
  #   model.associationsAreLoaded(["project", "task"]) # => true|false
  #   model.associationsAreLoaded() # => true|false
  associationsAreLoaded: (associations) =>
    associations ||= _.keys(@constructor.associations)
    _.all associations, (association) =>
      [association, fields] = association.split(":")
      details = @constructor.associationDetails(association)
      if details.type == "BelongsTo"
        @attributes.hasOwnProperty(details.key) && (@attributes[details.key] == null || base.data.storage(details.collectionName).get(@attributes[details.key]))
      else
        @attributes.hasOwnProperty(details.key) && _.all(@attributes[details.key], (id) -> base.data.storage(details.collectionName).get(id))

  # Override Model#get to access associations as well as fields.
  get: (field, options = {}) =>
    if details = @constructor.associationDetails(field)
      if details.type == "BelongsTo"
        id = @get(details.key) # project_id
        if id?
          base.data.storage(details.collectionName).get(id) || (Utils.throwError("Unable to find #{field} with id #{id} in our cached #{details.collectionName} collection.  We know about #{base.data.storage(details.collectionName).pluck("id").join(", ")}"))
      else
        ids = @get(details.key) # time_entry_ids
        models = []
        notFoundIds = []
        if ids
          for id in ids
            model = base.data.storage(details.collectionName).get(id)
            models.push(model)
            notFoundIds.push(id) unless model
          if notFoundIds.length
            Utils.throwError("Unable to find #{field} with ids #{notFoundIds.join(", ")} in our cached #{details.collectionName} collection.  We know about #{base.data.storage(details.collectionName).pluck("id").join(", ")}")
        if options.order
          comparator = base.data.getCollectionDetails(details.collectionName).klass.getComparatorWithIdFailover(options.order)
          collectionOptions = { comparator: comparator }
        else
          collectionOptions = {}
        base.data.createNewCollection(details.collectionName, models, collectionOptions)
    else
      super(field)

  className: =>
    @paramRoot

  defaultJSONBlacklist: ->
    ['id', 'created_at', 'updated_at']

  createJSONBlacklist: ->
    []

  updateJSONBlacklist: ->
    []

  toServerJSON: (method) =>
    json = @toJSON()
    blacklist = @defaultJSONBlacklist()

    switch method
      when "create"
        blacklist = blacklist.concat @createJSONBlacklist()
      when "update"
        blacklist = blacklist.concat @updateJSONBlacklist()

    for blacklistKey in blacklist
      delete json[blacklistKey]

    json

_.extend(Brainstem.Model.prototype, Brainstem.LoadingMixin);