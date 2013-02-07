class App.Models.Workspace extends Brainstem.Model
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

class App.Collections.Workspaces extends Brainstem.Collection
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
