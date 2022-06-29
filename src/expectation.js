/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * DS205: Consider reworking code to avoid use of IIFEs
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
let Expectation;
const _ = require('underscore');
const Error = require('./error');
const CollectionLoader = require('./loaders/collection-loader');

const Utils = require('./utils');

module.exports = Expectation = class Expectation {
  //
  // Init

  constructor(name, options, manager) {
    this.Model = require('./model');

    this.name = name;
    this.manager = manager;
    this.manager._setDefaultPageSettings(options);
    this.options = options;
    this.matches = [];
    this.recursive = false;
    this.triggerError = options.triggerError;
    this.count = options.count;
    this.immediate = options.immediate;
    delete options.immediate;
    this.associated = {};
    this.collections = {};
    this.requestQueue = [];
    if (this.options.response != null) {
      this.options.response(this);
    }
  }

  //
  // Control

  handleRequest(loader) {
    let returnedData;
    this.matches.push(loader.originalOptions);

    if (!this.recursive) {
      // we don't need to fetch additional things from the server in an expectation.
      loader.loadOptions.include = [];
    }

    if (this.triggerError != null) {
      loader._onServerLoadError(this.triggerError);
    }

    this._handleAssociations(loader);

    if (loader instanceof CollectionLoader) {
      returnedData = this._handleCollectionResults(loader);
    } else {
      returnedData = this._handleModelResults(loader);
    }

    return loader._onLoadSuccess(returnedData);
  }

  recordRequest(loader) {
    if (this.immediate) {
      return this.handleRequest(loader);
    } else {
      return this.requestQueue.push(loader);
    }
  }

  respond() {
    for (let request of Array.from(this.requestQueue)) {
      this.handleRequest(request);
    }
    return (this.requestQueue = []);
  }

  remove() {
    return (this.disabled = true);
  }

  lastMatch() {
    return this.matches[this.matches.length - 1];
  }

  loaderOptionsMatch(loader) {
    if (this.disabled) {
      return false;
    }
    if (this.name !== loader._getExpectationName()) {
      return false;
    }

    this.manager._checkPageSettings(loader.originalOptions);

    const optionKeys = [
      'include',
      'only',
      'order',
      'filters',
      'perPage',
      'page',
      'limit',
      'offset',
      'search',
      'optionalFields'
    ];

    return _.all(optionKeys, optionType => {
      if (this.options[optionType] === '*') {
        return true;
      }

      let option = _.compact(_.flatten([loader.originalOptions[optionType]]));
      let expectedOption = _.compact(_.flatten([this.options[optionType]]));

      if (optionType === 'include') {
        option = Utils.wrapObjects(option);
        expectedOption = Utils.wrapObjects(expectedOption);
      }

      return Utils.matches(option, expectedOption);
    });
  }

  //
  // Private

  _handleAssociations(_loader) {
    return (() => {
      const result = [];
      for (let key in this.associated) {
        let values = this.associated[key];
        if (!(values instanceof Array)) {
          values = [values];
        }
        result.push(
          Array.from(values).map(value =>
            this.manager.storage(value.brainstemKey).update([value])
          )
        );
      }
      return result;
    })();
  }

  _handleCollectionResults(loader) {
    if (!this.results) {
      return;
    }

    const cachedData = {
      count: this.count != null ? this.count : this.results.length,
      results: this.results,
      valid: true
    };

    this.manager.getCollectionDetails(loader.loadOptions.name).cache[
      loader.loadOptions.cacheKey
    ] = cachedData;

    for (let result of Array.from(this.results)) {
      if (result instanceof this.Model) {
        this.manager
          .storage(result.brainstemKey)
          .update([result], { silent: loader.loadOptions.silent });
      }
    }

    const returnedModels = _.map(this.results, result => {
      if (result instanceof this.Model) {
        return this.manager.storage(result.brainstemKey).get(result.id);
      } else {
        return this.manager.storage(result.key).get(result.id);
      }
    });

    return returnedModels;
  }

  _handleModelResults(loader) {
    let attributes, key;
    if (!this.result) {
      return;
    }

    // Put main (loader) model in storage manager.
    if (this.result instanceof this.Model) {
      key = this.result.brainstemKey;
      ({ attributes } = this.result);
    } else {
      ({ key } = this.result);
      attributes = _.omit(this.result, 'key');
    }

    if (!key) {
      throw Error(
        'Brainstem key is required on the result (brainstemKey on model or key in JSON)'
      );
    }

    let existingModel = this.manager.storage(key).get(attributes.id);

    if (!existingModel) {
      existingModel = loader.getModel();
      this.manager.storage(key).add(existingModel);
    }

    existingModel.set(attributes);
    return existingModel;
  }
};
