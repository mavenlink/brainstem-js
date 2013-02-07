class App.Models.Story extends Brainstem.Model
  paramRoot: 'story'

  methodUrl: (method) ->
    switch method
      when "delete" then "/api/stories/#{@id}?workspace_id=#{@attributes.workspace_id}"
      when "create" then "/api/stories"
      else "/api/stories/#{@id}"

  @associations:
    workspace: "workspaces"
    assignees: ["users"]
    sub_stories: ["stories"]
    parent: "stories"

class App.Collections.Stories extends Brainstem.Collection
  model: App.Models.Story
  url: '/api/stories.json'

  @defaultFilters: ["archived:false"]

  @filters: (field, value) ->
    if field == "parents_only"
      if value == "true"
        return (model) -> !model.get("parent_id")
      else
        return (model) -> true
    else
      super