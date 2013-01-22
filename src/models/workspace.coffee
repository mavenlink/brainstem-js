class App.Models.Workspace extends Mavenlink.Model
  paramRoot: 'workspace'

  defaults:
    consultant_role_name: 'Consultants'
    client_role_name: 'Clients'

  methodUrl: (method) ->
    switch method
      when "create" then "/api/workspaces"
      else "/api/workspaces/#{@id}"

  @associations:
    stories: ["stories"]
    time_entries: ["time_entries"]
    primary_counterpart: "users"
    participants: ["users"]
    participations: ["participations"]

  validate: (attrs) =>
    window.App.Validator(attrs, {
    title:
      required: { message: "A title is required." }
    due_date:
      custom: @validateDueDate
    price:
      custom: @validatePrice
    })

  validatePrice: (field, attrs, settings) =>
    unless attrs["price"] == "TBD"
      if attrs["budgeted"] && attrs["price"]?
        attrs["price"] = parseInt(Utils.stripLeadingCharacters(String(attrs["price"]))) #server can send back price as $10..etc
        if (isNaN(attrs["price"]) || attrs["price"] < 0)
          return "Budget must be a positive number."
      else
        if attrs["price"]?
          return "Project must be budgeted to have a budget."

  validateDueDate: (field, attrs, settings) =>
    if attrs["due_date"]
      dueDateAtMidnight = Utils.dateAtMidnight(attrs["due_date"])
      if isNaN(dueDateAtMidnight.getTime())
        return "Invalid due date format"
      else if (dueDateAtMidnight < Utils.dateAtMidnight(new Date()))
        return "Due date should be in the future."

  isOverdue: =>
    unless (@get("effective_due_date"))
      return false

    d = new Date(Utils.nowInMs())
    today = new Date(d.getFullYear(), d.getMonth(), d.getDate(), 0 ,0 ,0 ,0).getTime()
    due_date = new Date(Utils.slashedDateFormat(@get("effective_due_date"))).getTime()

    if due_date < today
      true
    else
      false

  remainingBudget: =>
    return "TBD" if !@get("budgeted") || @get("price") == "TBD"

    budgetUsed = Utils.currencyToCents(@get("budget_used"), @get("currency_base_unit"))
    price = Utils.currencyToCents(@get("price"), @get("currency_base_unit"))

    remaining = (price - budgetUsed) / @get("currency_base_unit")
    remainingBudget = if remaining < 0 then "-" else ""
    remainingBudget += "#{@get("currency_symbol")}#{Utils.numberWithCommas(Math.abs(remaining))}"

  percentBudgetUsed: =>
    return 0 if !@get("budgeted") || @get("price") == "TBD"

    budgetUsed = Utils.currencyToCents(@get("budget_used"), @get("currency_base_unit"))
    price = Utils.currencyToCents(@get("price"), @get("currency_base_unit"))

    parseInt(budgetUsed/price * 100)

class App.Collections.Workspaces extends Mavenlink.Collection
  model: App.Models.Workspace
  url: '/api/workspaces'

  @defaultFilters: ["include_archived:false"]

  @filters: (field, value) ->
    if field == "include_archived"
      if value == "false"
        return (model) -> !model.get("archived")
      else
        return (model) -> true
    else
      super

  comparator: (model) -> model.get("updated_at") * -1
