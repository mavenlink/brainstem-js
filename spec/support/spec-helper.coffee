window.App ?= {}
window.App.Models ?= {}
window.App.Collections ?= {}


window.spec ?= {}

beforeEach ->
  # Disable jQuery animations.
  $.fx.off = true

  # Basic page fixture
  $('#jasmine_content').html("<div id='wrapper'></div><div id='overlays'></div><div id='side-nav'></div><div id='main-view'></div></div>")

  # Setup a new base.
  window.base = new App.Mobile.Base(mavenlinkUserId: 55662187)

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
  spyOn base, "navigateAway"
  spyOn base, "setupWakeupTimer"

  # Use Jasmine's mock clock.  You can make time pass with jasmine.Clock.tick(N).
  jasmine.Clock.useMock()

afterEach ->
  window.clearLiveEventBindings()
  window?.base?.cleanup()
  window.server.restore()
  $('#jasmine_content').html("")
  jasmine.Clock.reset()

window.clearLiveEventBindings = ->
  events = jQuery.data document, "events"
  for key, value of events
    delete events[key]

window.context = describe
window.xcontext = xdescribe
