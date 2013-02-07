class App.Models.Task extends Brainstem.Model
  paramRoot: 'task'

  @associations:
    project: "projects"
    assignees: ["users"]
    sub_tasks: ["tasks"]
    parent: "tasks"

class App.Collections.Tasks extends Brainstem.Collection
  model: App.Models.Task
  url: '/api/tasks.json'

  @defaultFilters: ["archived:false"]

  @filters: (field, value) ->
    if field == "parents_only"
      if value == "true"
        return (model) -> !model.get("parent_id")
      else
        return (model) -> true
    else
      super