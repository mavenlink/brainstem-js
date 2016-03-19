Model = require '../../../src/model'


class TimeEntry extends Model
  brainstemKey: "time_entries"
  paramRoot: 'time_entry'
  urlRoot: '/api/time_entries'

  @associations:
    project: "projects"
    task: "tasks"
    user: "users"


module.exports = TimeEntry
