window.spec ?= {}

spec.defineBuilders = ->
  window.defineBuilder = (name, klass, defaultOptions) ->
    class_defaults = {}

    for key, value of defaultOptions
      if typeof(value) == "function"
        do ->
          seq_name = name + "_" + key
          BackboneFactory.define_sequence(seq_name, value)
          class_defaults[key] = -> BackboneFactory.next(seq_name)
      else
        class_defaults[key] = value

    factory = BackboneFactory.define(name, klass, -> return class_defaults)
    builder = (opts) ->
      BackboneFactory.create(name, $.extend({}, class_defaults, opts))

    creator = (opts) ->
      obj = builder(opts)
      storageName = name.underscore().pluralize()
      window.base.data.storage(storageName).add obj if window.base.data.collectionExists(storageName)
      obj

    eval("window.#{"build_#{name.underscore()}".camelize(true)} = builder")
    eval("window.#{"create_#{name.underscore()}".camelize(true)} = creator")

  window.defineBuilder "user", App.Models.User, {
    id: (n) -> return n
  }

  window.defineBuilder "project", App.Models.Project, {
    id: (n) -> return n
    title: "new project"
  }

  getTimeEntryDefaults = ->
    project = buildProject()

    return {
      id: (n)-> return n
      project_id: project.get("id")
    }
  window.defineBuilder "timeEntry", App.Models.TimeEntry, getTimeEntryDefaults()

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
  window.defineBuilder "task", App.Models.Task, getTaskDefaults()

  window.defineBuilder "post", App.Models.Post, {}
