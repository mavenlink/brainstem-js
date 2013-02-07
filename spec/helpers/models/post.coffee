class App.Models.Post extends Brainstem.Model
  paramRoot: 'post'

  @associations:
    replies:            ["posts"]
    workspace:          "workspaces"
    story:              "stories"
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

  @getComparator: (field) ->
    if field == "newest_reply_at"
      return (a, b) -> a.getNewestReplyOrCreatedAt().getTime() - b.getNewestReplyOrCreatedAt().getTime()
    else
      super