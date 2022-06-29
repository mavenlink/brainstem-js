/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const $ = require('jquery');
const _ = require('underscore');
const inflection = require('inflection');

const StorageManager = require('../../src/storage-manager');

const Post = require('./models/post');
const Project = require('./models/project');
const Task = require('./models/task');
const TimeEntry = require('./models/time-entry');
const User = require('./models/user');

if (window.spec == null) {
  window.spec = {};
}

spec.defineBuilders = function() {
  window.defineBuilder = function(name, klass, defaultOptions) {
    const class_defaults = {};

    for (var key in defaultOptions) {
      var value = defaultOptions[key];
      if (typeof value === 'function') {
        (function() {
          const seq_name = name + '_' + key;
          BackboneFactory.define_sequence(seq_name, value);
          return (class_defaults[key] = function() {
            const next = BackboneFactory.next(seq_name);
            if (isIdAttr(seq_name)) {
              return arrayPreservedToString(next);
            } else {
              return next;
            }
          });
        })();
      } else {
        class_defaults[key] = isIdAttr(key)
          ? arrayPreservedToString(value)
          : value;
      }
    }

    const factory = BackboneFactory.define(name, klass, () => class_defaults);
    const builder = opts =>
      BackboneFactory.create(
        name,
        $.extend({}, class_defaults, idsToStrings(opts))
      );

    const creator = function(opts) {
      const storageManager = StorageManager.get();
      const obj = builder(idsToStrings(opts));
      const storageName = inflection.transform(name, [
        'underscore',
        'pluralize'
      ]);
      if (storageManager.collectionExists(storageName)) {
        storageManager.storage(storageName).add(obj);
      }
      return obj;
    };

    window[
      inflection.camelize(`build_${inflection.underscore(name)}`, true)
    ] = builder;
    return (window[
      inflection.camelize(
        `build_and_cache_${inflection.underscore(name)}`,
        true
      )
    ] = creator);
  };

  var isIdAttr = attrName =>
    attrName === 'id' || attrName.match(/_id$/) || attrName.match(/_ids$/);

  var arrayPreservedToString = function(value) {
    if (_.isArray(value)) {
      return _.map(value, v => arrayPreservedToString(v));
    } else if (value != null && !$.isPlainObject(value)) {
      return String(value);
    } else {
      return value;
    }
  };

  var idsToStrings = function(builderOpts) {
    for (let key in builderOpts) {
      const value = builderOpts[key];
      if (isIdAttr(key)) {
        builderOpts[key] = arrayPreservedToString(value);
      }
    }

    return builderOpts;
  };

  window.defineBuilder('user', User, {
    id(n) {
      return n;
    }
  });

  window.defineBuilder('project', Project, {
    id(n) {
      return n;
    },
    title: 'new project'
  });

  const getTimeEntryDefaults = function() {
    const project = buildProject();

    return {
      id(n) {
        return n;
      },
      project_id: project.get('id')
    };
  };
  window.defineBuilder('timeEntry', TimeEntry, getTimeEntryDefaults());

  const getTaskDefaults = function() {
    const project = buildProject();

    return {
      id(n) {
        return n;
      },
      project_id: project.get('id'),
      description: 'a very interesting task',
      title(n) {
        return `new Task${n}`;
      },
      archived: false,
      parent_id: null
    };
  };
  window.defineBuilder('task', Task, getTaskDefaults());

  return window.defineBuilder('post', Post, {});
};
