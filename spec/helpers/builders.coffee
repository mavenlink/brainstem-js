$ = require 'jquery'
_ = require 'underscore'
inflection = require 'inflection'

StorageManager = require '../../src/storage-manager'

Post = require './models/post'
Project = require './models/project'
Task = require './models/task'
TimeEntry = require './models/time-entry'
User = require './models/user'


window.spec ?= {}

spec.defineBuilders = ->
  window.defineBuilder = (name, klass, defaultOptions) ->
    class_defaults = {}

    for key, value of defaultOptions
      if typeof(value) == "function"
        do ->
          seq_name = name + "_" + key
          BackboneFactory.define_sequence(seq_name, value)
          class_defaults[key] = ->
            next = BackboneFactory.next(seq_name)
            if isIdAttr(seq_name) then arrayPreservedToString(next) else next
      else
        class_defaults[key] = if isIdAttr(key) then arrayPreservedToString(value) else value

    factory = BackboneFactory.define(name, klass, -> return class_defaults)
    builder = (opts) ->
      BackboneFactory.create(name, Object.assign({}, class_defaults, idsToStrings(opts)))

    creator = (opts) ->
      storageManager = StorageManager.get()
      obj = builder(idsToStrings(opts))
      storageName = inflection.transform(name, ['underscore', 'pluralize'])
      storageManager.storage(storageName).add obj if storageManager.collectionExists(storageName)
      obj

    window[inflection.camelize("build_#{inflection.underscore(name)}", true)] = builder
    window[inflection.camelize("build_and_cache_#{inflection.underscore(name)}", true)] = creator

  isIdAttr = (attrName) ->
    attrName == 'id' || attrName.match(/_id$/) || (attrName.match(/_ids$/))

  arrayPreservedToString = (value) ->
    if _.isArray(value)
      _.map(value, (v) -> arrayPreservedToString(v))
    else if value? && !$.isPlainObject(value)
      String(value)
    else
      value

  idsToStrings = (builderOpts) ->
    for key, value of builderOpts
      if isIdAttr(key)
        builderOpts[key] = arrayPreservedToString(value)

    builderOpts

  window.defineBuilder "user", User, {
    id: (n) -> return n
  }

  window.defineBuilder "project", Project, {
    id: (n) -> return n
    title: "new project"
  }

  getTimeEntryDefaults = ->
    project = buildProject()

    return {
      id: (n)-> return n
      project_id: project.get("id")
    }
  window.defineBuilder "timeEntry", TimeEntry, getTimeEntryDefaults()

  getTaskDefaults = ->
    project = buildProject()

    return {
      id: (n) -> n
      project_id: project.get("id")
      description: "a very interesting task"
      title: (n) -> "new Task#{n}"
      archived: false
      parent_id: null
    }
  window.defineBuilder "task", Task, getTaskDefaults()

  window.defineBuilder "post", Post, {}
