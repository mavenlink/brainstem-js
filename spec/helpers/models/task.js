/*
 * decaffeinate suggestions:
 * DS206: Consider reworking classes to avoid initClass
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const Model = require('../../../src/model');

class Task extends Model {
  static initClass() {
    this.prototype.brainstemKey = 'tasks';
    this.prototype.paramRoot = 'task';
    this.prototype.urlRoot = '/api/tasks';

    this.associations = {
      project: 'projects',
      assignees: ['users'],
      sub_tasks: ['tasks'],
      parent: 'tasks'
    };
  }
}
Task.initClass();

module.exports = Task;
