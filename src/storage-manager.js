/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * DS205: Consider reworking code to avoid use of IIFEs
 * DS206: Consider reworking classes to avoid initClass
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const _ = require('underscore');
const $ = require('jquery');
const Backbone = require('backbone');
Backbone.$ = $; // TODO remove after upgrading to backbone 1.2+
const inflection = require('inflection');

const Utils = require('./utils');
const Expectation = require('./expectation');
const ModelLoader = require('./loaders/model-loader');
const CollectionLoader = require('./loaders/collection-loader');
const sync = require('./sync');

// The StorageManager class is used to manage a set of Collections.
// It is responsible for loading data and maintaining caches.
class _StorageManager {
  //
  // Init

  constructor(options) {
    if (options == null) {
      options = {};
    }
    Backbone.sync = sync;

    this.collections = {};

    this;
  }

  //
  // Accessors

  // Access the cache for a particular collection.
  // manager.storage("time_entries").get(12).get("title")
  storage(name) {
    return this.getCollectionDetails(name).storage;
  }

  dataUsage() {
    let sum = 0;
    for (let dataType of Array.from(this.collectionNames())) {
      sum += this.storage(dataType).length;
    }
    return sum;
  }

  // Access details of a collection.  An error will be thrown if the collection cannot be found.
  getCollectionDetails(name) {
    return this.collections[name] || this.collectionError(name);
  }

  collectionNames() {
    return _.keys(this.collections);
  }

  collectionExists(name) {
    return !!this.collections[name];
  }

  //
  // Control

  // Add a collection to the StorageManager.  All collections that will be loaded or used in associations must be added.
  //    manager.addCollection "time_entries", TimeEntries
  addCollection(name, collectionClass) {
    const collection = new collectionClass([], {});

    collection.on('remove', model => model.invalidateCache());

    return (this.collections[name] = {
      klass: collectionClass,
      modelKlass: collectionClass.prototype.model,
      storage: collection,
      cache: {}
    });
  }

  reset() {
    return (() => {
      const result = [];
      for (let name in this.collections) {
        const attributes = this.collections[name];
        attributes.storage.reset([]);
        result.push((attributes.cache = {}));
      }
      return result;
    })();
  }

  createNewCollection(collectionName, models, options) {
    if (models == null) {
      models = [];
    }
    if (options == null) {
      options = {};
    }
    const { loaded } = options;
    delete options.loaded;
    const collection = new (this.getCollectionDetails(collectionName).klass)(
      models,
      options
    );
    if (loaded) {
      collection.setLoaded(true, { trigger: false });
    }
    return collection;
  }

  createNewModel(modelName, options) {
    return new (this.getCollectionDetails(
      inflection.pluralize(modelName)
    ).modelKlass)(options || {});
  }

  // Request a model to be loaded, optionally ensuring that associations be included as well.
  // A loader (which is a jQuery promise) is returned immediately and is resolved with the model
  // from the StorageManager when the load, and any dependent loads, are complete.
  //     loader = manager.loadModel "time_entry", 2
  //     loader = manager.loadModel "time_entry", 2, fields: ["title", "notes"]
  //     loader = manager.loadModel "time_entry", 2, include: ["project", "task"]
  //     manager.loadModel("time_entry", 2, include: ["project", "task"]).done (model) -> console.log model
  loadModel(name, id, options) {
    if (options == null) {
      options = {};
    }
    if (!id) {
      return;
    }

    const loader = this.loadObject(name, $.extend({}, options, { only: id }), {
      isCollection: false
    });
    return loader;
  }

  // Request a set of data to be loaded, optionally ensuring that associations be
  // included as well.  A collection is returned immediately and is reset
  // when the load, and any dependent loads, are complete.
  //     collection = manager.loadCollection "time_entries"
  //     collection = manager.loadCollection "time_entries", only: [2, 6]
  //     collection = manager.loadCollection "time_entries", fields: ["title", "notes"]
  //     collection = manager.loadCollection "time_entries", include: ["project", "task"]
  //     collection = manager.loadCollection "time_entries", include: ["project:title,description", "task:due_date"]
  //     collection = manager.loadCollection "tasks",
  //       include: ["assets", { "assignees": "account" }, { "sub_tasks": ["assignees", "assets"] }]
  //     collection = manager.loadCollection "time_entries",
  //       filters: ["project_id:6", "editable:true"], order: "updated_at:desc", page: 1, perPage: 20
  loadCollection(name, options) {
    if (options == null) {
      options = {};
    }
    const loader = this.loadObject(name, options);
    return loader.externalObject;
  }

  // Helpers
  loadObject(name, loadOptions, options) {
    let loaderClass;
    if (loadOptions == null) {
      loadOptions = {};
    }
    if (options == null) {
      options = {};
    }
    options = $.extend({}, { isCollection: true }, options);

    const completeCallback = loadOptions.complete;
    const successCallback = loadOptions.success;
    const errorCallback = loadOptions.error;

    loadOptions = _.omit(loadOptions, 'success', 'error', 'complete');
    loadOptions = $.extend({}, loadOptions, { name });

    if (options.isCollection) {
      loaderClass = CollectionLoader;
    } else {
      loaderClass = ModelLoader;
    }

    this._checkPageSettings(loadOptions);

    const loader = new loaderClass({ storageManager: this });
    loader.setup(loadOptions);

    if (completeCallback != null && _.isFunction(completeCallback)) {
      loader.always(completeCallback);
    }

    if (successCallback != null && _.isFunction(successCallback)) {
      loader.done(successCallback);
    }

    if (errorCallback != null && _.isFunction(errorCallback)) {
      loader.fail(errorCallback);
    }

    if (this.expectations != null) {
      this.handleExpectations(loader);
      if (loader.loadOptions.returnValues == null) {
        loader.loadOptions.returnValues = {};
      }
      loader.loadOptions.returnValues.jqXhr = { abort() {} };
    } else {
      loader.load();
    }

    return loader;
  }

  // Cache model(s) directly into the storage manager. Response should be structured exactly as a
  // brainstem AJAX response. Useful in avoiding unnecessary AJAX request(s) when rendering the page.
  bootstrap(name, response, loadOptions) {
    if (loadOptions == null) {
      loadOptions = {};
    }
    const loader = new CollectionLoader({ storageManager: this });
    loader.setup($.extend({}, loadOptions, { name }));
    return loader._updateStorageManagerFromResponse(response);
  }

  collectionError(name) {
    return Utils.throwError(`\
Unknown collection ${name} in StorageManager. Known collections: ${_(
      this.collections
    )
      .keys()
      .join(', ')}\
`);
  }

  //
  // Test Helpers

  stub(collectionName, options) {
    if (options == null) {
      options = {};
    }
    if (this.expectations != null) {
      const expectation = new Expectation(collectionName, options, this);
      this.expectations.push(expectation);
      return expectation;
    } else {
      throw new Error(`\
You must call #enableExpectations on your instance of \
Brainstem.StorageManager before you can set expectations.\
`);
    }
  }

  stubModel(modelName, modelId, options) {
    if (options == null) {
      options = {};
    }
    return this.stub(
      inflection.pluralize(modelName),
      $.extend({}, options, { only: modelId })
    );
  }

  stubImmediate(collectionName, options) {
    return this.stub(
      collectionName,
      $.extend({}, options, { immediate: true })
    );
  }

  enableExpectations() {
    return (this.expectations = []);
  }

  disableExpectations() {
    return (this.expectations = null);
  }

  handleExpectations(loader) {
    for (let expectation of Array.from(this.expectations)) {
      if (expectation.loaderOptionsMatch(loader)) {
        expectation.recordRequest(loader);
        return;
      }
    }
    throw new Error(
      `No expectation matched ${name} with ${JSON.stringify(
        loader.originalOptions
      )}`
    );
  }

  //
  // Private

  _checkPageSettings(options) {
    if (
      options.limit != null &&
      options.limit !== '' &&
      options.offset != null &&
      options.offset !== ''
    ) {
      options.perPage = options.page = undefined;
    } else {
      options.limit = options.offset = undefined;
    }

    return this._setDefaultPageSettings(options);
  }

  _setDefaultPageSettings(options) {
    if (options.limit != null && options.offset != null) {
      if (options.limit < 1) {
        options.limit = 1;
      }
      if (options.offset < 0) {
        return (options.offset = 0);
      }
    } else {
      options.perPage = options.perPage || 20;
      if (options.perPage < 1) {
        options.perPage = 1;
      }
      options.page = options.page || 1;
      if (options.page < 1) {
        return (options.page = 1);
      }
    }
  }
}

var StorageManager = (function() {
  let instance = undefined;
  StorageManager = class StorageManager {
    static initClass() {
      instance = null;
    }

    static get() {
      return instance != null
        ? instance
        : (instance =
            (window.base != null ? window.base.data : undefined) != null
              ? window.base != null
                ? window.base.data
                : undefined
              : new _StorageManager(arguments));
    }
  };
  StorageManager.initClass();
  return StorageManager;
})();

module.exports = StorageManager;
