/*
 * decaffeinate suggestions:
 * DS206: Consider reworking classes to avoid initClass
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const Collection = require('../../../src/collection');

const User = require('./user');

class Users extends Collection {
  static initClass() {
    this.prototype.model = User;
    this.prototype.url = '/api/users';
  }
}
Users.initClass();

module.exports = Users;
