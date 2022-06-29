/*
 * decaffeinate suggestions:
 * DS206: Consider reworking classes to avoid initClass
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const Collection = require('../../../src/collection');

const Project = require('./project');

class Projects extends Collection {
  static initClass() {
    this.prototype.model = Project;
    this.prototype.url = '/api/projects';
  }
}
Projects.initClass();

module.exports = Projects;
