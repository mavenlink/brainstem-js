class App.Models.Story extends Mavenlink.Model
  paramRoot: 'story'

  validate: (attrs) =>
    window.App.Validator(attrs, {
      due_date:
        format: { regex: /^\d{2,4}[\/\-]\d{1,2}[\/\-]\d{1,2}$/, message: "The provided due date is not valid", allowBlank: true}
      start_date:
        format: { regex: /^\d{2,4}[\/\-]\d{1,2}[\/\-]\d{1,2}$/, message: "The provided start date is not valid", allowBlank: true}
        custom: @validateStartDateNotAfterDueDate
      parent_id:
        numeric: { min: 0, allowBlank: true, message: "This is not a valid parent story."}
      workspace_id:
        numeric: { min: 0, message: "A workspace is required." }
      title:
        required: {message: "A title is required."}
      story_type:
        custom: @validateStoryType
    })

  substoryCount: =>
    @get("sub_stories").length

  methodUrl: (method) ->
    switch method
      when "delete" then "/api/stories/#{@id}?workspace_id=#{@attributes.workspace_id}"
      when "create" then "/api/stories"
      else "/api/stories/#{@id}"

  validateStoryType: (field, attrs, settings) ->
    type = attrs[field]
    allowedTypes = ['deliverable', 'task', 'milestone']
    unless type in allowedTypes
      "Item type must be one of the following: #{allowedTypes.join(', ')}"

  validateStartDateNotAfterDueDate: (field, attrs, settings) ->
    start_date = new Date(Utils.slashedDateFormat(attrs['start_date'])).getTime() if attrs['start_date']
    due_date = new Date(Utils.slashedDateFormat(attrs['due_date'])).getTime() if attrs['due_date']
    if start_date && due_date && start_date > due_date
      "Start date cannot be after due date"

  getDisplayState: =>
    unless (@get("due_date"))
      return @get("state")

    if @isOverdue() then "overdue" else @get("state")

  isOverdue: =>
    unless (@get("due_date"))
      return false

    d = new Date(Utils.nowInMs())
    today = new Date(d.getFullYear(), d.getMonth(), d.getDate(), 0 ,0 ,0 ,0).getTime()
    due_date = new Date(Utils.slashedDateFormat(@get("due_date"))).getTime()

    if (due_date < today && @get('state') != 'completed') then true else false

  isOverstart: =>
    unless (@get("start_date"))
      return false

    d = new Date(Utils.nowInMs())
    today = new Date(d.getFullYear(), d.getMonth(), d.getDate(), 0 ,0 ,0 ,0).getTime()
    start_date = new Date(Utils.slashedDateFormat(@get("start_date"))).getTime()
    if (start_date < today && @get('state') == 'not started') then true else false

  isMilestone: =>
    @get('story_type') == 'milestone'

  isSubstory: =>
    @get('parent_id')?

  isParent: =>
    @substoryCount() > 0

  getAssigneeText: =>
    assignees = @get("assignees")

    if !assignees? || assignees.length == 0
      return "Unassigned"
    else if assignees.length == 1
      return "Assigned to " + assignees.at(0).getDisplayName()
    else
      return 'Assigned to ' + assignees.length + " people"

  getAssigneeShortText: =>
    assignees = @get("assignees")

    if !assignees? || assignees.length == 0
      return "Unassigned"
    else if assignees.length == 1
      return assignees.at(0).getDisplayName()
    else
      return "Multiple people"

  @associations:
    workspace: "workspaces"
    assignees: ["users"]
    sub_stories: ["stories"]
    parent: "stories"

class App.Collections.Stories extends Mavenlink.Collection
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

  getWithAssocation: (id) =>
    model = super

    unless model
      for story in @models
        model = story.get('sub_stories')?.get(id)
        break if model

    return model