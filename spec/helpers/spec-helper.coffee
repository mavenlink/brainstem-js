$ = require 'jquery'
_ = require 'underscore'
Backbone = require 'backbone'
Backbone.$ = $ # TODO remove after upgrading to backbone 1.2+
merge = require 'lodash.merge'

jqueryMatchers = require 'jasmine-jquery-matchers'
BackboneFactory = require 'backbone-factory'

StorageManager = require '../../src/storage-manager'

TimeEntries = require './models/time-entries'
Posts = require './models/posts'
Tasks = require './models/tasks'
Projects = require './models/projects'
Users = require './models/users'


window.resultsArray = (key, models) ->
  _(models).map (model) -> { key: key, id: model.get("id") }

window.resultsObject = (models) ->
  results = {}
  for model in models
    results[model.id] = model
  results

window.convertTopLevelKeysToObjects = (data) ->
  for key in _(data).keys()
    continue if key in ["count", "results"]
    if data[key] instanceof Array
      data[key] = _(data[key]).reduce(((memo, item) -> memo[item.id] = item; memo ), {})

window.respondWith = (server, url, options) ->
  if options.resultsFrom?
    data = merge({}, options.data, { results: resultsArray(options.resultsFrom, options.data[options.resultsFrom]) })
  else
    data = options.data
  convertTopLevelKeysToObjects data
  server.respondWith options.method || "GET",
                     url, [ options.status || 200,
                           {"Content-Type": options.content_type || "application/json"},
                           JSON.stringify(data) ]

beforeEach ->
  # Disable jQuery animations.
  $.fx.off = true

  # Basic page fixture
  $(document.body).html('''
    <div id="jasmine_content">
      <div id="wrapper"></div>
      <div id="overlays"></div>
      <div id="side-nav"></div>
      <div id="main-view"></div>
    </div>
  ''')

  # Instantiate storage manager
  storageManager = StorageManager.get()
  storageManager.addCollection 'time_entries', TimeEntries
  storageManager.addCollection 'posts', Posts
  storageManager.addCollection 'tasks', Tasks
  storageManager.addCollection 'projects', Projects
  storageManager.addCollection 'users', Users

  # Define builders
  spec.defineBuilders()

  # Mock out all Ajax requests.
  window.server = sinon.fakeServer.create()

  # Prevent any actual navigation.
  spyOn Backbone.History.prototype, 'start'
  spyOn Backbone.History.prototype, 'navigate'

  # Use Jasmine's mock clock.  You can make time pass with jasmine.Clock.tick(N).
  jasmine.clock().install()

  jasmine.addMatchers(jqueryMatchers)

afterEach ->
  window.clearLiveEventBindings()
  window.server.restore()

  $(document.body).empty()

  jasmine.clock().uninstall()

window.clearLiveEventBindings = ->
  events = $.data document, "events"
  for key, value of events
    delete events[key]

window.context = describe
window.xcontext = xdescribe

# Shared Behaviors
window.SharedBehaviors ?= {};

window.registerSharedBehavior = (behaviorName, funct) ->
  if not behaviorName
    throw "Invalid shared behavior name"

  if typeof funct != 'function'
    throw "Invalid shared behavior, it must be a function"

  window.SharedBehaviors[behaviorName] = funct

window.itShouldBehaveLike = (behaviorName, context) ->
  behavior = window.SharedBehaviors[behaviorName];
  context ?= {}

  if not behavior || typeof behavior != 'function'
    throw "Shared behavior #{behaviorName} not found."
  else
    jasmine.getEnv().describe "#{behaviorName} (shared behavior)", -> behavior.call(this, context)
