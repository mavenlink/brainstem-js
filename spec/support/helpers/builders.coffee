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

  getUserDefaults = ->
    return {
      id: (n)-> return n
      email_address: (n)-> return "user_#{n}@example.com"
      full_name: (n)-> return "User_#{n}"
      photo_path: (n)-> return "photo_#{n}.jpg"
    }

  window.defineBuilder "user", App.Models.User, getUserDefaults()

  getContactDefaults = ->
    return {
      id: (n)-> return n
      interaction_count: 1
      consultant_occurrences: 1
      client_occurrences: 0
    }

  window.defineBuilder "contact", App.Models.Contact, getContactDefaults()

  getWorkspaceDefaults = {
    id: (n)-> return n
    title: "new workspace"
    description: "workspace description"
    effective_due_date: null
    can_create_line_items: true
    budgeted: false
    change_orders_enabled: false
    currency_symbol: "$"
    currency_base_unit: 100
    archived: false
    primary_counterpart_id: null
    price: null
    can_invite: true
    has_budget_access: true
    consultant_role_name: "Consultants",
    client_role_name: "Clients",
    updated_at: (new Date("September 19, 1984 11:13:00")).getTime() / 1000
    created_at: (new Date("September 13, 1984 03:33:33")).getTime() / 1000
  }
  window.defineBuilder "workspace", App.Models.Workspace, getWorkspaceDefaults

  getTimeEntryDefaults = ->
    workspace = buildWorkspace()

    return {
      id: (n)-> return n
      created_at: (new Date("September 25, 1989 11:13:00")).getTime() / 1000
      date_performed: "2010-02-15"
      time_in_minutes: 20
      billable: true
      user_can_edit: true
      notes: "some important notes"
      rate_in_cents: 2000
      currency: "USD"
      currency_symbol: "$"
      currency_base_unit: 100
      workspace_id: workspace.get("id")
    }
  window.defineBuilder "timeEntry", App.Models.TimeEntry, getTimeEntryDefaults()

  getStoryDefaults = ->
    workspace = buildWorkspace()

    return {
      id: (n) -> n
      workspace_id: workspace.get("id")
      description: "a very interesting story"
      updated_at: (new Date("September 19, 1984 11:13:00")).getTime() / 1000
      created_at: (new Date("September 13, 1984 03:33:33")).getTime() / 1000
      title: (n) -> "new Story#{n}"
      story_type: "task"
      state: "not started"
      archived: false
      parent_id: null
      position: (n) -> return n
    }
  window.defineBuilder "story", App.Models.Story, getStoryDefaults()

  window.defineBuilder "timer", App.Models.Timer, elapsed_time: 0, active: false

  getExpenseDefaults = ->
    workspace = buildWorkspace()

    return {
      id: (n)-> n
      created_at: (new Date("September 25, 1989 11:13:00")).getTime() / 1000
      date: "2010-03-15"
      billable: true
      notes: "some expensive notes"
      user_can_edit: true
      amount_in_cents: 2000
      category: "Entertainment"
      currency: "USD"
      currency_symbol: "$"
      currency_base_unit: 100
      workspace_id: workspace.get("id")
      is_invoiced: false
    }
  window.defineBuilder "expense", App.Models.Expense, getExpenseDefaults()

  getPostDefaults = ->
    workspace = buildWorkspace()
    return {
          id: (n) -> n
          created_at: (new Date("September 25, 1989 11:13:00")).getTime() / 1000
          reply: false
          workspace_id: workspace.get("id")
          message: "Valid posts have messages."
          subject_id: null
          has_attachments: false
          private: false
    }
  window.defineBuilder "post", App.Models.Post, getPostDefaults()

  getAssetDefaults = ->
    return {
      id: (n) -> n
      updated_at: (new Date("September 19, 1984 11:13:00")).getTime() / 1000
      created_at: (new Date("September 13, 1984 03:33:33")).getTime() / 1000
      filesize: 1024 * 100
      filename: (n) -> "file #{n}.png"
      url: (n) -> "http://wwww.lowercaseomega.com/file#{n}.png"
      deleted_at: null
    }

  window.defineBuilder "asset", App.Models.Asset, getAssetDefaults()

  getGoogleDocumentDefaults = ->
    return {
    id: (n) -> n
    updated_at: (new Date("September 19, 1984 11:13:00")).getTime() / 1000
    created_at: (new Date("September 13, 1984 03:33:33")).getTime() / 1000
    type: "google_document_document"
    filename: (n) -> "My Document"
    url: (n) -> "http://wwww.lowercaseomega.com/file#{n}.doc"
    deleted_at: null
    }

  window.defineBuilder "google_document", App.Models.GoogleDocument, getGoogleDocumentDefaults()

  getParticipationDefaults = ->
    user = buildUser()
    workspace = buildWorkspace()

    return {
      id: (n)-> return n
      user_id: user.get("id")
      workspace_id: workspace.get("id")
      role: "maven"
      is_team_lead: false
    }

  window.defineBuilder "participation", App.Models.Participation, getParticipationDefaults()
