/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * DS205: Consider reworking code to avoid use of IIFEs
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const $ = require('jquery');
const _ = require('underscore');
const Backbone = require('backbone');
Backbone.$ = $; // TODO remove after upgrading to backbone 1.2+

const jqueryMatchers = require('jasmine-jquery-matchers');
const BackboneFactory = require('backbone-factory');

const StorageManager = require('../../src/storage-manager');

const TimeEntries = require('./models/time-entries');
const Posts = require('./models/posts');
const Tasks = require('./models/tasks');
const Projects = require('./models/projects');
const Users = require('./models/users');

window.resultsArray = (key, models) =>
  _(models).map(model => ({ key, id: model.get('id') }));

window.resultsObject = function(models) {
  const results = {};
  for (let model of Array.from(models)) {
    results[model.id] = model;
  }
  return results;
};

window.convertTopLevelKeysToObjects = data =>
  (() => {
    const result = [];
    for (let key of Array.from(_(data).keys())) {
      if (['count', 'results'].includes(key)) {
        continue;
      }
      if (data[key] instanceof Array) {
        result.push(
          (data[key] = _(data[key]).reduce(function(memo, item) {
            memo[item.id] = item;
            return memo;
          }, {}))
        );
      } else {
        result.push(undefined);
      }
    }
    return result;
  })();

window.respondWith = function(server, url, options) {
  let data;
  if (options.resultsFrom != null) {
    data = $.extend({}, options.data, {
      results: resultsArray(
        options.resultsFrom,
        options.data[options.resultsFrom]
      )
    });
  } else {
    ({ data } = options);
  }
  convertTopLevelKeysToObjects(data);
  return server.respondWith(options.method || 'GET', url, [
    options.status || 200,
    { 'Content-Type': options.content_type || 'application/json' },
    JSON.stringify(data)
  ]);
};

beforeEach(function() {
  // Disable jQuery animations.
  $.fx.off = true;

  // Basic page fixture
  $(document.body).html(`\
<div id="jasmine_content">
  <div id="wrapper"></div>
  <div id="overlays"></div>
  <div id="side-nav"></div>
  <div id="main-view"></div>
</div>\
`);

  // Instantiate storage manager
  const storageManager = StorageManager.get();
  storageManager.addCollection('time_entries', TimeEntries);
  storageManager.addCollection('posts', Posts);
  storageManager.addCollection('tasks', Tasks);
  storageManager.addCollection('projects', Projects);
  storageManager.addCollection('users', Users);

  // Define builders
  spec.defineBuilders();

  // Mock out all Ajax requests.
  window.server = sinon.fakeServer.create();

  // Prevent any actual navigation.
  spyOn(Backbone.History.prototype, 'start');
  spyOn(Backbone.History.prototype, 'navigate');

  // Use Jasmine's mock clock.  You can make time pass with jasmine.Clock.tick(N).
  jasmine.clock().install();

  return jasmine.addMatchers(jqueryMatchers);
});

afterEach(function() {
  window.clearLiveEventBindings();
  window.server.restore();

  $(document.body).empty();

  return jasmine.clock().uninstall();
});

window.clearLiveEventBindings = function() {
  const events = $.data(document, 'events');
  return (() => {
    const result = [];
    for (let key in events) {
      const value = events[key];
      result.push(delete events[key]);
    }
    return result;
  })();
};

window.context = describe;
window.xcontext = xdescribe;

// Shared Behaviors
if (window.SharedBehaviors == null) {
  window.SharedBehaviors = {};
}

window.registerSharedBehavior = function(behaviorName, funct) {
  if (!behaviorName) {
    throw 'Invalid shared behavior name';
  }

  if (typeof funct !== 'function') {
    throw 'Invalid shared behavior, it must be a function';
  }

  return (window.SharedBehaviors[behaviorName] = funct);
};

window.itShouldBehaveLike = function(behaviorName, context) {
  const behavior = window.SharedBehaviors[behaviorName];
  if (context == null) {
    context = {};
  }

  if (!behavior || typeof behavior !== 'function') {
    throw `Shared behavior ${behaviorName} not found.`;
  } else {
    return jasmine
      .getEnv()
      .describe(`${behaviorName} (shared behavior)`, function() {
        return behavior.call(this, context);
      });
  }
};
