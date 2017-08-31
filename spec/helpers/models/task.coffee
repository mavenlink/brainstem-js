Model = require '../../../src/model'


class Task extends Model
  brainstemKey: "tasks"
  paramRoot: 'task'
  urlRoot: '/api/tasks'

  @associations:
    project: "projects"
    assignees: ["users"]
    sub_tasks: ["tasks"]
    parent: "tasks"

module.exports = Task
