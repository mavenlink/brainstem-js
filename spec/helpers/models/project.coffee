Model = require '../../../src/model'


class Project extends Model
  brainstemKey: "projects"
  paramRoot: 'project'
  urlRoot: '/api/projects'

  @associations:
    tasks: ["tasks"]
    time_entries: ["time_entries"]
    primary_counterpart: "users"


module.exports = Project
