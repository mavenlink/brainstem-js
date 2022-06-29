/*
 * decaffeinate suggestions:
 * DS206: Consider reworking classes to avoid initClass
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const Model = require('../../../src/model');

class Project extends Model {
  static initClass() {
    this.prototype.brainstemKey = 'projects';
    this.prototype.paramRoot = 'project';
    this.prototype.urlRoot = '/api/projects';

    this.associations = {
      tasks: ['tasks'],
      time_entries: ['time_entries'],
      primary_counterpart: 'users'
    };
  }
}
Project.initClass();

module.exports = Project;
