class App.Models.Expense extends Brainstem.Model
  paramRoot: 'expense'

  defaults:
    billable: true

  @associations:
    workspace: "workspaces"
    user: "users"
    receipt: "assets"

class App.Collections.Expenses extends Brainstem.Collection
  model: App.Models.Expense
  url: '/api/expenses'

  @getComparator: (field) ->
    if field == "date"
      return (a, b) -> a.getDate().getTime() - b.getDate().getTime()
    else
      super