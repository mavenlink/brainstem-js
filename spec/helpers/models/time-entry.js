/*
 * decaffeinate suggestions:
 * DS206: Consider reworking classes to avoid initClass
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const Model = require('../../../src/model');

class TimeEntry extends Model {
  static initClass() {
    this.prototype.brainstemKey = 'time_entries';
    this.prototype.paramRoot = 'time_entry';
    this.prototype.urlRoot = '/api/time_entries';

    this.associations = {
      project: 'projects',
      task: 'tasks',
      user: 'users'
    };
  }
}
TimeEntry.initClass();

module.exports = TimeEntry;
