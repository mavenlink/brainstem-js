Model = require '../../../src/model'


class Post extends Model
  brainstemKey: "posts"
  paramRoot: 'post'
  urlRoot: '/api/posts'

  @associations:
    replies:  ["posts"]
    project:  "projects"
    task:     "tasks"
    user:     "users"
    subject:  ["tasks", "projects"]


module.exports = Post
