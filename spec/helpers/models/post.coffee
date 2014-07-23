class App.Models.Post extends Brainstem.Model
  brainstemKey: "posts"
  paramRoot: 'post'
  urlRoot: '/api/posts'

  @associations:
    replies:            ["posts"]
    project:            "projects"
    task:               "tasks"
    user:               "users"
    subject:            ["tasks", "projects"]


class App.Collections.Posts extends Brainstem.Collection
  model: App.Models.Post
  url: '/api/posts'
