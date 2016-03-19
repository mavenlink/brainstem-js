Collection = require '../../../src/collection'

Project = require './project'


class Projects extends Collection
  model: Project
  url: '/api/projects'


module.exports = Projects
