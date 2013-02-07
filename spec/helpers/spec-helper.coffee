window.App ?= {}
window.App.Models ?= {}
window.App.Collections ?= {}

beforeEach ->
  # Disable jQuery animations.
  $.fx.off = true

  # Basic page fixture
  $('#jasmine_content').html("<div id='wrapper'></div><div id='overlays'></div><div id='side-nav'></div><div id='main-view'></div></div>")

  # Setup a new base.
  window.base = {}
  window.base.data = new Brainstem.StorageManager()
  window.base.data.addCollection 'time_entries', App.Collections.TimeEntries
  window.base.data.addCollection 'expenses', App.Collections.Expenses
  window.base.data.addCollection 'posts', App.Collections.Posts
  window.base.data.addCollection 'assets', App.Collections.Assets
  window.base.data.addCollection 'google_documents', App.Collections.GoogleDocuments
  window.base.data.addCollection 'stories', App.Collections.Stories
  window.base.data.addCollection 'workspaces', App.Collections.Workspaces
  window.base.data.addCollection 'workspace_invitations', App.Collections.WorkspaceInvitations
  window.base.data.addCollection 'users', App.Collections.Users
  window.base.data.addCollection 'contacts', App.Collections.Contacts
  window.base.data.addCollection 'participations', App.Collections.Participations


  # Define builders
  spec.defineBuilders()

  # Mock out all Ajax requests.
  window.server = sinon.fakeServer.create()
  sinon.log = -> console.log arguments

  # Requests for Backbone.history.getFragment() will always return the contents of spec.fragment.
  Backbone.history ||= new Backbone.History
  spyOn(Backbone.history, 'getFragment').andCallFake -> window.spec.fragment
  window.spec.fragment = "mock/path"

  # Prevent any actual navigation.
  spyOn Backbone.History.prototype, 'start'
  spyOn Backbone.History.prototype, 'navigate'

  # Use Jasmine's mock clock.  You can make time pass with jasmine.Clock.tick(N).
  jasmine.Clock.useMock()

afterEach ->
  window.clearLiveEventBindings()
  window.server.restore()
  $('#jasmine_content').html("")
  jasmine.Clock.reset()

window.clearLiveEventBindings = ->
  events = jQuery.data document, "events"
  for key, value of events
    delete events[key]

window.context = describe
window.xcontext = xdescribe
