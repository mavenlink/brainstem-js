/*
 * decaffeinate suggestions:
 * DS206: Consider reworking classes to avoid initClass
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const Collection = require('../../../src/collection');

const Post = require('./post');

class Posts extends Collection {
  static initClass() {
    this.prototype.model = Post;
    this.prototype.url = '/api/posts';
  }
}
Posts.initClass();

module.exports = Posts;
