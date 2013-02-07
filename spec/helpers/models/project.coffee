class App.Models.Project extends Brainstem.Model
  paramRoot: 'project'

  @associations:
    tasks: ["tasks"]
    time_entries: ["time_entries"]
    primary_counterpart: "users"

class App.Collections.Projects extends Brainstem.Collection
  model: App.Models.Project
  url: '/api/projects'

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
