class App.Models.Post extends Brainstem.Model
  paramRoot: 'post'

  @associations:
    replies:            ["posts"]
    project:            "projects"
    task:               "tasks"
    user:               "users"

class App.Collections.Posts extends Brainstem.Collection
  model: App.Models.Post
  url: '/api/posts'

  @defaultFilters: ["parents_only:true"]

  @filters: (field, value) ->
    if field == "parents_only"
      if value == "true"
        return (model) -> !model.get("reply")
      else
        return (model) -> true
    else
      super
