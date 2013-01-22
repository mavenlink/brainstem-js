class App.Models.WorkspaceInvitation extends Mavenlink.Model
  paramRoot: 'workspace_invitation'

  validate: (attrs) =>
    window.App.Validator(attrs, {
      email_address:
        custom: @validateEmailAddress
      full_name:
        required: {allowBlank: false, message: "Invitee name is required."}
    })

  validateEmailAddress: (field, attrs, settings) =>
    if !attrs["email_address"]?
      return "An email address is required"

    unless Utils.looksLikeEmailAddress(attrs["email_address"])
      return "The email address appears to be invalid."

  methodUrl: (method) ->
    switch method
      when "create" then "/api/workspaces/invite"

class App.Collections.WorkspaceInvitations extends Mavenlink.Collection
  model: App.Models.WorkspaceInvitation