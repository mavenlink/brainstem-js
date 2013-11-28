class App.Models.Project extends Brainstem.Model
  brainstemKey: "projects"
  paramRoot: 'project'
  urlRoot: '/api/projects'

  @associations:
    tasks: ["tasks"]
    time_entries: ["time_entries"]
    primary_counterpart: "users"

class App.Collections.Projects extends Brainstem.Collection
  model: App.Models.Project
  url: '/api/projects'
