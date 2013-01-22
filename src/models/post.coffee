class App.Models.Post extends Mavenlink.Model
  paramRoot: 'post'

  validate: (attrs) =>
    window.App.Validator(attrs, {
      message:
        custom: @validateReplyMessage
      workspace_id:
        numeric: { min: 0, message: "A workspace is required." }
      story_id:
        numeric: { min: 0, allowBlank: true }
    })

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

  validateReplyMessage: (field, attrs, settings) ->
    unless attrs.id
      msg = $.trim(attrs[field])
      if msg == ""
        return "Message may not be blank"
      else if msg.length > 10000
        return "Message must be between 1 and 10000 characters."

  latestReply: =>
    if @get('newest_reply') then @get('newest_reply') else @

  getNewestReplyOrCreatedAt: =>
    new Date(Utils.slashedDateFormat(@get('newest_reply_at') || @get('created_at')))

  addNewReply: (reply) =>
    @attributes.newest_reply_id = reply.id
    @attributes.newest_reply_user_id = reply.attributes.user_id
    delete @attributes.reply_ids

  getAttachments: =>
    attachments = []
    if @get("has_attachments")
      attachments = [].concat(@get('assets').models, @get('google_documents').models)
    attachments


class App.Collections.Posts extends Mavenlink.Collection
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

  getWithAssocation: (id) =>
    model = super

    unless model
      for post in @models
        model = post.get('replies')?.get(id)
        break if model

    return model