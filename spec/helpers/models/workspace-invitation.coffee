class App.Models.WorkspaceInvitation extends Brainstem.Model
  paramRoot: 'workspace_invitation'

  methodUrl: (method) ->
    switch method
      when "create" then "/api/workspaces/invite"

class App.Collections.WorkspaceInvitations extends Brainstem.Collection
  model: App.Models.WorkspaceInvitation