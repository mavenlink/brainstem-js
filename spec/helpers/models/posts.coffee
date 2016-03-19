Collection = require '../../../src/collection'

Post = require './post'


class Posts extends Collection
  model: Post
  url: '/api/posts'


module.exports = Posts
