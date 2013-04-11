class App.Models.Post extends Brainstem.Model
  brainstemKey: "posts"
  paramRoot: 'post'

  @associations:
    replies:            ["posts"]
    project:            "projects"
    task:               "tasks"
    user:               "users"

class App.Collections.Posts extends Brainstem.Collection
  model: App.Models.Post
  url: '/api/posts'
