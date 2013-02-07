class App.Models.Post extends Brainstem.Model
  paramRoot: 'post'

  methodUrl: (method) ->
    switch method
      when "delete" then "/api/posts/#{@id}?post_id=#{@attributes.workspace_id}"
      when "create" then "/api/posts"
      else "/api/posts/#{@id}"

  @associations:
    replies:            ["posts"]
    newest_reply:       "posts"
    newest_reply_user:  "users"
    recipients:         ["users"]
    workspace:          "workspaces"
    story:              "stories"
    user:               "users"
    assets:             ["assets"]
    google_documents:   ["google_documents"]

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