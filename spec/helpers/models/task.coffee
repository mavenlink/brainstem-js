class App.Models.Task extends Brainstem.Model
  brainstemKey: "tasks"
  paramRoot: 'task'
  urlRoot: '/api/tasks'

  @associations:
    project: "projects"
    assignees: ["users"]
    sub_tasks: ["tasks"]
    parent: "tasks"

class App.Collections.Tasks extends Brainstem.Collection
  model: App.Models.Task
  url: '/api/tasks'
