Collection = require '../../collection'

Post = require './post'


class Posts extends Brainstem.Collection
  model: Post
  url: '/api/posts'


module.exports = Posts
