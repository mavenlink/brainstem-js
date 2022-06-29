/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * DS103: Rewrite code to no longer use __guard__
 * DS205: Consider reworking code to avoid use of IIFEs
 * DS206: Consider reworking classes to avoid initClass
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const $ = require('jquery');
const _ = require('underscore');
const Backbone = require('backbone');
Backbone.$ = $; // TODO remove after upgrading to backbone 1.2+

const Utils = require('../utils');

class AbstractLoader {
  static initClass() {
    //
    // Properties

    this.prototype.internalObject = null;
    this.prototype.externalObject = null;
    this.prototype.associationIdLimit = 150;
  }

  //
  // Init

  constructor(options) {
    this._onServerLoadSuccess = this._onServerLoadSuccess.bind(this);
    this._onServerLoadError = this._onServerLoadError.bind(this);
    this._onLoadingCompleted = this._onLoadingCompleted.bind(this);
    if (options == null) {
      options = {};
    }
    this.storageManager = options.storageManager;

    this._deferred = $.Deferred();
    this._deferred.promise(this);

    if (options.loadOptions) {
      this.setup(options.loadOptions);
    }
  }

  /**
   * Setup the loader with a list of Brainstem specific loadOptions
   * @param  {object} loadOptions Brainstem specific loadOptions (filters, include, only, etc)
   * @return {object} externalObject that was created.
   */
  setup(loadOptions) {
    this._parseLoadOptions(loadOptions);
    this._createObjects();

    return this.externalObject;
  }

  //
  // Accessors

  /**
   * Returns the cache object from the storage manager.
   * @return {object} Object containing `count` and `results` that were cached.
   */
  getCacheObject() {
    return this.storageManager.getCollectionDetails(this._getCollectionName())
      .cache[this.loadOptions.cacheKey];
  }

  //
  // Control

  /**
   * Loads the model from memory or the server.
   * @return {object} the loader's `externalObject`
   */
  load() {
    let data;
    if (!this.loadOptions) {
      throw new Error(
        'You must call #setup first or pass loadOptions into the constructor'
      );
    }

    // Check the cache to see if we have everything that we need.
    if (this.loadOptions.cache && (data = this._checkCacheForData())) {
      return data;
    } else {
      return this._loadFromServer();
    }
  }

  //
  // Private

  // Accessors

  /**
   * Returns the name of the collection that this loader maps to and will update in the storageManager.
   * @return {string} name of the collection
   */
  _getCollectionName() {
    throw new Error('Implement in your subclass');
  }

  /**
   * Returns the name that expectations will be stubbed with (story or stories etc)
   * @return {string} name of the stub
   */
  _getExpectationName() {
    throw new Error('Implement in your subclass');
  }

  /**
   * This needs to return a constructor for the model that associations will be compared with.
   * This typically will be the current collection's model/current model constructor.
   * @return {Model}
   */
  _getModel() {
    throw new Error('Implement in your subclass');
  }

  /**
   * This needs to return an array of models that correspond to the supplied association.
   * @return {array} models that are associated with this association
   */
  _getModelsForAssociation(association) {
    throw new Error('Implement in your subclass');
  }

  /**
   * Returns an array of IDs that need to be loaded for this association.
   * @param  {string} association name of the association
   * @return {array} array of IDs to fetch for this association.
   */
  _getIdsForAssociation(association) {
    const models = this._getModelsForAssociation(association);
    if (_.isArray(models)) {
      return _(models)
        .chain()
        .flatten()
        .pluck('id')
        .compact()
        .uniq()
        .sort()
        .value();
    } else {
      return [models.id];
    }
  }

  // Control

  /**
   * Sets up both the `internalObject` and `externalObject`.
   * In the case of models the `internalObject` and `externalObject` are the same.
   * In the case of collections the `internalObject` is a proxy object that updates
   * the `externalObject` when all loading is completed.
   */
  _createObjects() {
    throw new Error('Implement in your subclass');
  }

  /**
   * Updates the object with the supplied data. Will be called:
   *   + after the server responds, `object` will be `internalObject` and
   *     data will be the result of `_updateStorageManagerFromResponse`
   *   + after all loading is complete, `object` will be the `externalObject`
   *     and data will be the `internalObject`
   * @param  {object} object object that will receive the data
   * @param  {object} data data that needs set on the object
   * @param  {boolean} silent whether or not to trigger loaded at the end of the update
   * @return {undefined}
   */
  _updateObjects(object, data, silent) {
    if (silent == null) {
      silent = false;
    }
    throw new Error('Implement in your subclass');
  }

  /**
   * Parse supplied loadOptions, add defaults, transform them into
   * appropriate structures, and pull out important pieces.
   * @param  {object} loadOptions
   * @return {object} transformed loadOptions
   */
  _parseLoadOptions(loadOptions) {
    if (loadOptions == null) {
      loadOptions = {};
    }
    this.originalOptions = _.clone(loadOptions);
    this.loadOptions = _.clone(loadOptions);
    const ignoreWrappingBrainstemParams = options =>
      options.brainstemParams !== true;
    this.loadOptions.include = Utils.wrapObjects(
      Utils.extractArray('include', this.loadOptions),
      ignoreWrappingBrainstemParams
    );
    this.loadOptions.optionalFields = Utils.extractArray(
      'optionalFields',
      this.loadOptions
    );
    if (this.loadOptions.filters == null) {
      this.loadOptions.filters = {};
    }
    this.loadOptions.thisLayerInclude = _.map(
      this.loadOptions.include,
      i => _.keys(i)[0]
    ); // pull off the top layer of includes

    if (this.loadOptions.only) {
      this.loadOptions.only = _.map(
        Utils.extractArray('only', this.loadOptions),
        id => String(id)
      );
    } else {
      this.loadOptions.only = null;
    }

    // Determine whether or not we should look at the cache
    if (this.loadOptions.cache == null) {
      this.loadOptions.cache = true;
    }
    if (this.loadOptions.search) {
      this.loadOptions.cache = false;
    }
    this.loadOptions.cacheKey = this._buildCacheKey();

    this.cachedCollection = this.storageManager.storage(
      this._getCollectionName()
    );

    return this.loadOptions;
  }

  /**
   * Builds a cache key to represent this object
   * @return {string} cache key
   */
  _buildCacheKey() {
    const filterKeys =
      _.isObject(this.loadOptions.filters) &&
      _.size(this.loadOptions.filters) > 0
        ? JSON.stringify(this.loadOptions.filters)
        : '';

    const onlyIds = (this.loadOptions.only || []).sort().join(',');

    return (this.loadOptions.cacheKey = [
      this.loadOptions.order || 'updated_at:desc',
      filterKeys,
      onlyIds,
      this.loadOptions.page,
      this.loadOptions.perPage,
      this.loadOptions.limit,
      this.loadOptions.offset,
      this.loadOptions.search
    ].join('|'));
  }

  /**
   * Checks to see if the current requested data is available in the caching layer.
   * If it is available then update the externalObject with that data (via `_onLoadSuccess`).
   * @return {[boolean|object]} returns false if not found otherwise returns the externalObject.
   */
  _checkCacheForData() {
    if (this.loadOptions.only != null) {
      const alreadyLoadedIds = _.select(this.loadOptions.only, id => {
        return __guard__(this.cachedCollection.get(id), x =>
          x.dependenciesAreLoaded(this.loadOptions)
        );
      });
      if (alreadyLoadedIds.length === this.loadOptions.only.length) {
        this._onLoadSuccess(
          _.map(this.loadOptions.only, id => this.cachedCollection.get(id))
        );
        return this.externalObject;
      }
    } else {
      // Check if we have a cache for this request and if so make sure that
      // all of the requested includes for this layer are loaded on those models.
      const cacheObject = this.getCacheObject();

      if (cacheObject && cacheObject.valid) {
        const subset = _.map(cacheObject.results, result =>
          this.storageManager.storage(result.key).get(result.id)
        );
        if (
          _.all(subset, model => model.dependenciesAreLoaded(this.loadOptions))
        ) {
          this._onLoadSuccess(subset);
          return this.externalObject;
        }
      }
    }

    return false;
  }

  /**
   * Makes a GET request to the server via Backbone.sync with the built syncOptions.
   * @return {object} externalObject that will be updated when everything is complete.
   */
  _loadFromServer() {
    const jqXhr = Backbone.sync.call(
      this.internalObject,
      'read',
      this.internalObject,
      this._buildSyncOptions()
    );

    if (this.loadOptions.returnValues) {
      this.loadOptions.returnValues.jqXhr = jqXhr;
    }

    return this.externalObject;
  }

  /**
   * Called when the server responds with data and needs to be persisted to the storageManager.
   * @param  {object} resp JSON data from the server
   * @return {[array|object]} array of models or model that was parsed.
   */
  _updateStorageManagerFromResponse(resp) {
    throw new Error('Implement in your subclass');
  }

  /**
   * Called after the server responds with the first layer of includes to determine if any more loads are needed.
   * It will only make additional loads if there were IDs returned during this load for a given association.
   * @return {undefined}
   */
  _calculateAdditionalIncludes() {
    this.additionalIncludes = [];

    return (() => {
      const result = [];
      for (let hash of Array.from(this.loadOptions.include)) {
        const associationName = _.keys(hash)[0];
        const associationIds = this._getIdsForAssociation(associationName);
        const includedAssociation = hash[associationName];

        if (associationIds.length) {
          const association = {
            ids: associationIds
          };

          if (includedAssociation instanceof Backbone.Collection) {
            association.collection = includedAssociation;
            result.push(this.additionalIncludes.push(association));
          } else if (includedAssociation.brainstemParams) {
            association.loadOptions = includedAssociation;
            association.name = associationName;
            result.push(this.additionalIncludes.push(association));
          } else if (includedAssociation.length) {
            association.include = includedAssociation;
            association.name = associationName;

            result.push(this.additionalIncludes.push(association));
          } else {
            result.push(undefined);
          }
        } else {
          result.push(undefined);
        }
      }
      return result;
    })();
  }

  /**
   * Loads the next layer of includes from the server.
   * When all loads are complete, it will call `_onLoadingCompleted` which will resolve this layer.
   * @return {undefined}
   */
  _loadAdditionalIncludes() {
    const promises = [];

    for (let association of Array.from(this.additionalIncludes)) {
      const batches = Utils.chunk(association.ids, this.associationIdLimit);
      const batchPromises = batches.map(
        this._loadAdditionalIncludesBatch.bind(this, association)
      );
      promises.push(...Array.from(batchPromises || []));
    }

    return $.when
      .apply($, promises)
      .done(this._onLoadingCompleted)
      .fail(this._onServerLoadError);
  }

  _loadAdditionalIncludesBatch(association, ids) {
    let loadOptions = {
      cache: this.loadOptions.cache,
      headers: this.loadOptions.headers,
      only: ids,
      params: {
        apply_default_filters: false
      }
    };

    if (association.collection) {
      return association.collection.fetch(loadOptions);
    } else {
      const { collectionName } = this._getModel().associationDetails(
        association.name
      );
      if (association.loadOptions) {
        loadOptions = _.extend(loadOptions, association.loadOptions);
      } else {
        loadOptions.include = association.include;
      }

      return this.storageManager.loadObject(collectionName, loadOptions);
    }
  }

  /**
   * Generates the Brainstem specific options that are passed to Backbone.sync.
   * @return {object} options that are passed to Backbone.sync
   */
  _buildSyncOptions() {
    const options = this.loadOptions;
    const syncOptions = {
      data: {},
      headers: options.headers,
      parse: true,
      error: this._onServerLoadError,
      success: this._onServerLoadSuccess
    };

    if (options.thisLayerInclude.length) {
      syncOptions.data.include = options.thisLayerInclude.join(',');
    }
    if (options.only && this._shouldUseOnly()) {
      syncOptions.data.only = options.only.join(',');
    }
    if (options.order != null) {
      syncOptions.data.order = options.order;
    }
    if (options.search) {
      syncOptions.data.search = options.search;
    }
    if (
      this.loadOptions.optionalFields != null
        ? this.loadOptions.optionalFields.length
        : undefined
    ) {
      syncOptions.data.optional_fields = this.loadOptions.optionalFields.join(
        ','
      );
    }

    const blacklist = [
      'include',
      'limit',
      'offset',
      'only',
      'optional_fields',
      'order',
      'page',
      'per_page',
      'search'
    ];
    _(syncOptions.data)
      .chain()
      .extend(_(options.filters).omit(blacklist))
      .extend(_(options.params).omit(blacklist))
      .value();

    if (options.only == null) {
      if (options.limit != null && options.offset != null) {
        syncOptions.data.limit = options.limit;
        syncOptions.data.offset = options.offset;
      } else {
        syncOptions.data.per_page = options.perPage;
        syncOptions.data.page = options.page;
      }
    }

    return syncOptions;
  }

  /**
   * Decides whether or not the `only` filter should be applied in the syncOptions.
   * Models will not use the `only` filter as they use show routes.
   * @return {boolean} whether or not to use the `only` filter
   */
  _shouldUseOnly() {
    return this.internalObject instanceof Backbone.Collection;
  }

  /**
   * Parses the result of model.get(associationName) to either return a collection's models
   * or the model itself.
   * @param  {object|Backbone.Collection} obj result of calling `.get` on a model with an association name.
   * @return {object|array} either a model object or an array of models from a collection.
   */
  _modelsOrObj(obj) {
    if (obj instanceof Backbone.Collection) {
      return obj.models;
    } else if (obj instanceof Array) {
      return obj;
    } else if (obj) {
      return [obj];
    } else {
      return [];
    }
  }

  // Events

  /**
   * Called when the Backbone.sync successfully responds from the server.
   * @param  {object} resp    JSON response from the server.
   * @param  {string} _status
   * @param  {object} _xhr    jQuery XHR object
   * @return {undefined}
   */
  _onServerLoadSuccess(resp, _status, _xhr) {
    const data = this._updateStorageManagerFromResponse(resp);
    return this._onLoadSuccess(data);
  }

  /**
   * Called when the Backbone.sync has errored.
   * @param  {object} jqXhr
   * @param  {string} textStatus
   * @param  {string} errorThrown
   */
  _onServerLoadError(jqXHR, textStatus, errorThrown) {
    return this._deferred.reject.apply(this, arguments);
  }

  /**
   * Updates the internalObject with the data in the storageManager and either loads more data or resolves this load.
   * Called after sync + storage manager updating.
   * @param  {array|object} data array of models or model from _updateStorageManagerFromResponse
   * @return {undefined}
   */
  _onLoadSuccess(data) {
    this._updateObjects(this.internalObject, data, true);
    this._calculateAdditionalIncludes();

    if (this.additionalIncludes.length) {
      return this._loadAdditionalIncludes();
    } else {
      return this._onLoadingCompleted();
    }
  }

  /**
   * Called when all loading (including nested loads) are complete.
   * Updates the `externalObject` with the data that was gathered and resolves the promise.
   * @return {undefined}
   */
  _onLoadingCompleted() {
    this._updateObjects(this.externalObject, this.internalObject);
    return this._deferred.resolve(this.externalObject);
  }
}
AbstractLoader.initClass();

module.exports = AbstractLoader;

function __guard__(value, transform) {
  return typeof value !== 'undefined' && value !== null
    ? transform(value)
    : undefined;
}
