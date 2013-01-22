class App.Models.Expense extends Mavenlink.Model
  paramRoot: 'expense'

  defaults:
    billable: true

  validate: (attrs) =>
    window.App.Validator(attrs, {
      date:
        format: { regex: /^\d{2,4}[\/\-]\d{1,2}[\/\-]\d{1,2}$/, message: "A valid date is required." }
      amount_in_cents:
        numeric: { min: 1, max: 100000000000, message: "The billing amount must be a positive number." }
      workspace_id:
        numeric: { min: 0, message: "A workspace is required." }
      category:                   #May want to validate or something to prevent <script> injections...?
        required: { message: "A category is required."}
    })

  categoryIsValid: (field, attrs, fieldValue) ->
    categories = ["Travel", "Mileage", "Lodging", "Food", "Entertainment", "Other"]
    unless fieldValue in categories
      "#{fieldValue} must be a selectable category in the list #{categories.join(', ')}."

  methodUrl: (method) ->
    switch method
      when "delete" then "/api/expenses/#{@id}?workspace_id=#{@attributes.workspace_id}"
      when "create" then "/api/expenses"
      else "/api/expenses/#{@id}"

  getDatePerformedOrToday: ->
    Utils.getDatePerformedOrToday(@get('date'))

  getAmount: ->
    Utils.centsToCurrency @get('amount_in_cents'), @get("currency_base_unit"), @get("currency_symbol")

  getDate: =>
    new Date(Utils.slashedDateFormat(@get('date')))

  hasReceipt: =>
    @get("receipt")?

  @associations:
    workspace: "workspaces"
    user: "users"
    receipt: "assets"

class App.Collections.Expenses extends Mavenlink.Collection
  model: App.Models.Expense
  url: '/api/expenses'

  @getComparator: (field) ->
    if field == "date"
      return (a, b) -> a.getDate().getTime() - b.getDate().getTime()
    else
      super