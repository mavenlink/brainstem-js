/*
 * decaffeinate suggestions:
 * DS206: Consider reworking classes to avoid initClass
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const Model = require('../../../src/model');

class Post extends Model {
  static initClass() {
    this.prototype.brainstemKey = 'posts';
    this.prototype.paramRoot = 'post';
    this.prototype.urlRoot = '/api/posts';

    this.associations = {
      replies: ['posts'],
      project: 'projects',
      task: 'tasks',
      user: 'users',
      subject: ['tasks', 'projects']
    };
  }
}
Post.initClass();

module.exports = Post;
