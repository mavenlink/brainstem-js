class App.Models.TimeEntry extends Brainstem.Model
  brainstemKey: "time_entries"
  paramRoot: 'time_entry'
  urlRoot: '/api/time_entries'

  @associations:
    project: "projects"
    task: "tasks"
    user: "users"

class App.Collections.TimeEntries extends Brainstem.Collection
  model: App.Models.TimeEntry
  url: '/api/time_entries'
