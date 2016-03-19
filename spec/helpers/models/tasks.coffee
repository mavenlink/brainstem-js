Collection = require '../../../src/collection'

Task = require './task'


class Tasks extends Collection
  model: Task
  url: '/api/tasks'


module.exports = Tasks
