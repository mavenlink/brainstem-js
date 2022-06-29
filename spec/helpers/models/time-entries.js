/*
 * decaffeinate suggestions:
 * DS206: Consider reworking classes to avoid initClass
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const Collection = require('../../../src/collection');

const TimeEntry = require('./time-entry');

class TimeEntries extends Collection {
  static initClass() {
    this.prototype.model = TimeEntry;
    this.prototype.url = '/api/time_entries';
  }
}
TimeEntries.initClass();

module.exports = TimeEntries;
