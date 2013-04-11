class App.Models.TimeEntry extends Brainstem.Model
  brainstemKey: "time_entries"
  paramRoot: 'time_entry'

  methodUrl: (method) ->
    switch method
      when "delete" then "/api/time_entries"
      when "create" then "/api/time_entries"
      else "/api/time_entries/#{@id}"

  @associations:
    project: "projects"
    task: "tasks"
    user: "users"

class App.Collections.TimeEntries extends Brainstem.Collection
  model: App.Models.TimeEntry
  url: '/api/time_entries'
