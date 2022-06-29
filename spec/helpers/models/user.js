/*
 * decaffeinate suggestions:
 * DS206: Consider reworking classes to avoid initClass
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const Model = require('../../../src/model');

class User extends Model {
  static initClass() {
    this.prototype.brainstemKey = 'users';
    this.prototype.paramRoot = 'user';
    this.prototype.urlRoot = '/api/users';
  }
}
User.initClass();

module.exports = User;
