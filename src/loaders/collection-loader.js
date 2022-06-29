/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const $ = require('jquery');
const _ = require('underscore');

const Collection = require('../collection');
const AbstractLoader = require('./abstract-loader');
const { knownResponseKeys } = require('../constants');

class CollectionLoader extends AbstractLoader {
  //
  // Accessors

  getCollection() {
    return this.externalObject;
  }

  //
  // Private

  // Accessors

  _getCollectionName() {
    return this.loadOptions.name;
  }

  _getExpectationName() {
    return this._getCollectionName();
  }

  _getModel() {
    return this.internalObject.model;
  }

  _getModelsForAssociation(association) {
    return this.internalObject.map(m => this._modelsOrObj(m.get(association)));
  }

  // Control

  _createObjects() {
    this.internalObject = this.storageManager.createNewCollection(
      this.loadOptions.name,
      []
    );

    this.externalObject =
      this.loadOptions.collection ||
      this.storageManager.createNewCollection(this.loadOptions.name, []);
    this.externalObject.setLoaded(false);
    if (this.loadOptions.reset) {
      this.externalObject.reset([], { silent: false });
    }
    this.externalObject.lastFetchOptions = _.pick(
      $.extend(true, {}, this.loadOptions),
      Collection.OPTION_KEYS
    );
    return (this.externalObject.lastFetchOptions.include = this.originalOptions.include);
  }

  _updateObjects(object, data, silent) {
    if (silent == null) {
      silent = false;
    }
    object.setLoaded(true, { trigger: false });

    if (data) {
      if (data.models != null) {
        data = data.models;
      }
      if (object.length) {
        object.add(data);
      } else {
        object.reset(data);
      }
    }

    if (!silent) {
      return object.setLoaded(true);
    }
  }

  _updateStorageManagerFromResponse(resp) {
    // The server response should look something like this:
    //  {
    //    count: 200,
    //    results: [{ key: "tasks", id: 10 }, { key: "tasks", id: 11 }],
    //    time_entries: [{ id: 2, title: "te1", project_id: 6, task_id: [10, 11] }]
    //    projects: [{id: 6, title: "some project", time_entry_ids: [2] }]
    //    tasks: [{id: 10, title: "some task" }, {id: 11, title: "some other task" }]
    //    meta: {
    //      count: 200,
    //      page_number: 1,
    //      page_count: 10,
    //      page_size: 20
    //    }
    //  }
    // Loop over all returned data types and update our local storage to represent any new data.

    const results = resp['results'];
    const keys = _.without(_.keys(resp), ...Array.from(knownResponseKeys));
    if (!_.isEmpty(results)) {
      if (keys.indexOf(this.loadOptions.name) !== -1) {
        keys.splice(keys.indexOf(this.loadOptions.name), 1);
      }
      keys.push(this.loadOptions.name);
    }

    for (let underscoredModelName of Array.from(keys)) {
      this.storageManager
        .storage(underscoredModelName)
        .update(_(resp[underscoredModelName]).values(), {
          silent: this.loadOptions.silent
        });
    }

    const cachedData = {
      count: resp.count,
      results,
      valid: true
    };

    this.storageManager.getCollectionDetails(this.loadOptions.name).cache[
      this.loadOptions.cacheKey
    ] = cachedData;
    return _.map(results, result =>
      this.storageManager.storage(result.key).get(result.id)
    );
  }
}

module.exports = CollectionLoader;
