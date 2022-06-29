/*
 * decaffeinate suggestions:
 * DS206: Consider reworking classes to avoid initClass
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const Collection = require('../../../src/collection');

const Task = require('./task');

class Tasks extends Collection {
  static initClass() {
    this.prototype.model = Task;
    this.prototype.url = '/api/tasks';
  }
}
Tasks.initClass();

module.exports = Tasks;
