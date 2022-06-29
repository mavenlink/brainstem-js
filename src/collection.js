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
let Collection;
const $ = require('jquery');
const _ = require('underscore');
const Backbone = require('backbone');
Backbone.$ = $; // TODO remove after upgrading to backbone 1.2+

const Utils = require('./utils');

module.exports = Collection = (function() {
  Collection = class Collection extends Backbone.Collection {
    static initClass() {
      this.OPTION_KEYS = [
        'name',
        'include',
        'filters',
        'page',
        'perPage',
        'limit',
        'offset',
        'order',
        'search',
        'cache',
        'cacheKey',
        'optionalFields',
        'silent'
      ];

      //
      // Properties

      this.prototype.lastFetchOptions = null;
      this.prototype.firstFetchOptions = null;
    }

    static getComparatorWithIdFailover(order) {
      const [field, direction] = Array.from(order.split(':'));
      const comp = this.getComparator(field);
      return function(a, b) {
        if (direction.toLowerCase() === 'desc') {
          [b, a] = Array.from([a, b]);
        }
        const result = comp(a, b);
        if (result === 0) {
          return a.get('id') - b.get('id');
        } else {
          return result;
        }
      };
    }

    static getComparator(field) {
      return (a, b) => a.get(field) - b.get(field);
    }

    static pickFetchOptions(options) {
      return _.pick(options, this.OPTION_KEYS);
    }

    model(attrs, options) {
      const Model = require('./model');
      return new Model(attrs, options);
    }

    //
    // Init

    constructor(models, options) {
      super(...arguments);

      this.storageManager = require('./storage-manager').get();

      if (options) {
        this.firstFetchOptions = Collection.pickFetchOptions(options);
      }
      this.setLoaded(false);
    }

    //
    // Accessors

    getServerCount() {
      return __guard__(this._getCacheObject(), x => x.count);
    }

    getWithAssocation(id) {
      return this.get(id);
    }

    //
    // Control

    fetch(options) {
      options = options ? _.clone(options) : {};

      options.parse = options.parse != null ? options.parse : true;
      options.name =
        options.name != null
          ? options.name
          : this.model != null
          ? this.model.prototype.brainstemKey
          : undefined;
      if (options.returnValues == null) {
        options.returnValues = {};
      }

      if (!options.name) {
        Utils.throwError(
          'Either collection must have model with brainstemKey defined or name option must be provided'
        );
      }

      if (!this.firstFetchOptions) {
        this.firstFetchOptions = Collection.pickFetchOptions(options);
      }

      Utils.wrapError(this, options);

      const loader = this.storageManager.loadObject(
        options.name,
        _.extend({}, this.firstFetchOptions, options)
      );
      const xhr = options.returnValues.jqXhr;

      this.trigger('request', this, xhr, options);

      return loader
        .then(() => loader.internalObject.models)
        .done(response => {
          let method;
          this.lastFetchOptions = loader.externalObject.lastFetchOptions;

          if (options.add) {
            method = 'add';
          } else if (options.reset) {
            method = 'reset';
          } else {
            method = 'set';
          }

          this[method](response, options);

          return this.trigger('sync', this, response, options);
        })
        .then(() => loader.externalObject)
        .promise(xhr);
    }

    refresh(options) {
      if (options == null) {
        options = {};
      }
      return this.fetch(
        _.extend(this.lastFetchOptions, options, { cache: false })
      );
    }

    setLoaded(state, options) {
      if (options == null || options.trigger == null || !!options.trigger) {
        options = { trigger: true };
      }
      this.loaded = state;
      if (state && options.trigger) {
        return this.trigger('loaded', this);
      }
    }

    update(models, options) {
      if (options == null) {
        options = {};
      }
      const addOpts = _.pick(options, 'silent');
      if (models.models != null) {
        ({ models } = models);
      }
      return (() => {
        const result = [];
        for (let model of Array.from(models)) {
          if (this.model.parse != null) {
            model = this.model.parse(model);
          }
          const backboneModel = this._prepareModel(model, { blacklist: [] });
          if (backboneModel) {
            var modelInCollection;
            if ((modelInCollection = this.get(backboneModel.id))) {
              result.push(modelInCollection.set(backboneModel.attributes));
            } else {
              result.push(this.add(backboneModel, addOpts));
            }
          } else {
            result.push(
              Utils.warn(
                'Unable to update collection with invalid model',
                model
              )
            );
          }
        }
        return result;
      })();
    }

    reload(options) {
      this.storageManager.reset();
      this.reset([], { silent: true });
      this.setLoaded(false);
      const loadOptions = _.extend({}, this.lastFetchOptions, options, {
        page: 1,
        collection: this
      });
      return this.storageManager.loadCollection(
        this.lastFetchOptions.name,
        loadOptions
      );
    }

    loadNextPage(options) {
      let success;
      if (options == null) {
        options = {};
      }
      if (_.isFunction(options.success)) {
        ({ success } = options);
        delete options.success;
      }

      return this.getNextPage(_.extend(options, { add: true })).done(() =>
        typeof success === 'function'
          ? success(this, this.hasNextPage())
          : undefined
      );
    }

    getPageIndex() {
      if (!this.lastFetchOptions) {
        return 1;
      }

      if (this.lastFetchOptions.offset != null) {
        return (
          Math.ceil(
            this.lastFetchOptions.offset / this.lastFetchOptions.limit
          ) + 1
        );
      } else {
        return this.lastFetchOptions.page;
      }
    }

    getNextPage(options) {
      if (options == null) {
        options = {};
      }
      return this.getPage(this.getPageIndex() + 1, options);
    }

    getPreviousPage(options) {
      if (options == null) {
        options = {};
      }
      return this.getPage(this.getPageIndex() - 1, options);
    }

    getFirstPage(options) {
      if (options == null) {
        options = {};
      }
      return this.getPage(1, options);
    }

    getLastPage(options) {
      if (options == null) {
        options = {};
      }
      return this.getPage(Infinity, options);
    }

    getPage(index, options) {
      let max;
      if (options == null) {
        options = {};
      }
      this._canPaginate(true);

      options = _.extend(options, this.lastFetchOptions);

      if (index < 1) {
        index = 1;
      }

      if (this.lastFetchOptions.offset != null) {
        max = this._maxOffset();
        const offset =
          this.lastFetchOptions.limit * index - this.lastFetchOptions.limit;
        options.offset = offset < max ? offset : max;
      } else {
        max = this._maxPage();
        options.page = index < max ? index : max;
      }

      return this.fetch(_.extend(options, { reset: true }));
    }

    hasNextPage() {
      if (!this._canPaginate()) {
        return false;
      }

      if (this.lastFetchOptions.offset != null) {
        if (this._maxOffset() > this.lastFetchOptions.offset) {
          return true;
        } else {
          return false;
        }
      } else {
        if (this._maxPage() > this.lastFetchOptions.page) {
          return true;
        } else {
          return false;
        }
      }
    }

    hasPreviousPage() {
      if (!this._canPaginate()) {
        return false;
      }

      if (this.lastFetchOptions.offset != null) {
        if (this.lastFetchOptions.offset > this.lastFetchOptions.limit) {
          return true;
        } else {
          return false;
        }
      } else {
        if (this.lastFetchOptions.page > 1) {
          return true;
        } else {
          return false;
        }
      }
    }

    invalidateCache() {
      return __guard__(this._getCacheObject(), x => (x.valid = false));
    }

    toServerJSON(method) {
      return this.map(model =>
        _.extend(model.toServerJSON(method), { id: model.id })
      );
    }

    //
    // Private

    _canPaginate(throwError) {
      if (throwError == null) {
        throwError = false;
      }
      const options = this.lastFetchOptions;
      const count = (() => {
        try {
          return this.getServerCount();
        } catch (error) {}
      })();

      const throwOrReturn = function(message) {
        if (throwError) {
          return Utils.throwError(message);
        } else {
          return false;
        }
      };

      if (!options) {
        return throwOrReturn(
          '(pagination) collection must have been fetched once'
        );
      }
      if (!count) {
        return throwOrReturn('(pagination) collection must have a count');
      }
      if (!options.perPage && !options.limit) {
        return throwOrReturn('(pagination) perPage or limit must be defined');
      }

      return true;
    }

    _maxOffset() {
      const { limit } = this.lastFetchOptions;
      if (_.isUndefined(limit)) {
        Utils.throwError(
          '(pagination) you must define limit when using offset'
        );
      }
      return limit * Math.ceil(this.getServerCount() / limit) - limit;
    }

    _maxPage() {
      const { perPage } = this.lastFetchOptions;
      if (_.isUndefined(perPage)) {
        Utils.throwError(
          '(pagination) you must define perPage when using page'
        );
      }
      return Math.ceil(this.getServerCount() / perPage);
    }

    _getCacheObject() {
      if (this.lastFetchOptions) {
        return __guard__(
          this.storageManager.getCollectionDetails(this.lastFetchOptions.name),
          x => x.cache[this.lastFetchOptions.cacheKey]
        );
      }
    }
  };
  Collection.initClass();
  return Collection;
})();

function __guard__(value, transform) {
  return typeof value !== 'undefined' && value !== null
    ? transform(value)
    : undefined;
}
