/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * DS205: Consider reworking code to avoid use of IIFEs
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const _ = require('underscore');
const $ = require('jquery');
const Backbone = require('backbone');
Backbone.$ = $; // TODO remove after upgrading to backbone 1.2+

const StorageManager = require('../../src/storage-manager');

const Tasks = require('../helpers/models/tasks');

registerSharedBehavior('AbstractLoaderSharedBehavior', function(sharedContext) {
  let loaderClass;
  let loader = (loaderClass = null);

  beforeEach(() => (loaderClass = sharedContext.loaderClass));

  const fakeNestedInclude = [
    'parent',
    { project: ['participants'] },
    { assignees: ['something_else'] }
  ];

  const defaultLoadOptions = () => ({ name: 'tasks' });

  const createLoader = function(opts) {
    if (opts == null) {
      opts = {};
    }
    const storageManager = StorageManager.get();
    storageManager.addCollection('tasks', Tasks);

    const defaults = { storageManager };

    loader = new loaderClass(_.extend({}, defaults, opts));
    loader._getCollectionName = () => 'tasks';
    loader._createObjects = function() {
      this.internalObject = { bar: 'foo' };
      return (this.externalObject = { foo: 'bar' });
    };

    loader._getModelsForAssociation = () => [
      { id: 5 },
      { id: 2 },
      { id: 1 },
      { id: 4 },
      { id: 1 },
      [{ id: 6 }],
      { id: null }
    ];
    loader._getModel = () => Tasks.prototype.model;
    loader._updateStorageManagerFromResponse = jasmine.createSpy();
    loader._updateObjects = function(obj, data, silent) {
      if (!silent) {
        return obj.setLoaded(true);
      }
    };

    spyOn(loader, '_updateObjects');

    return loader;
  };

  describe('#constructor', function() {
    it('saves off a reference to the passed in StorageManager', function() {
      const storageManager = StorageManager.get();
      loader = createLoader({ storageManager });
      return expect(loader.storageManager).toEqual(storageManager);
    });

    it('creates a deferred object and turns the loader into a promise', function() {
      const spy = jasmine.createSpy('promise spy');

      loader = createLoader();
      expect(loader._deferred).not.toBeUndefined();
      loader.then(spy);

      loader._deferred.resolve();
      return expect(spy).toHaveBeenCalled();
    });

    return describe('options.loadOptions', function() {
      it('calls #setup with loadOptions if loadOptions were passed in', function() {
        const spy = spyOn(loaderClass.prototype, 'setup');

        loader = createLoader({ loadOptions: defaultLoadOptions() });
        return expect(spy).toHaveBeenCalledWith(defaultLoadOptions());
      });

      return it('does not call #setup if loadOptions were not passed in', function() {
        const spy = spyOn(loaderClass.prototype, 'setup');

        loader = createLoader();
        return expect(spy).not.toHaveBeenCalled();
      });
    });
  });

  describe('#setup', function() {
    it('calls #_parseLoadOptions with the loadOptions', function() {
      loader = createLoader();
      spyOn(loader, '_parseLoadOptions');

      const opts = { foo: 'bar' };

      loader.setup(opts);
      return expect(loader._parseLoadOptions).toHaveBeenCalledWith(opts);
    });

    it('calls _createObjects', function() {
      loader = createLoader();
      spyOn(loader, '_createObjects');

      loader.setup();
      return expect(loader._createObjects).toHaveBeenCalled();
    });

    return it('returns the externalObject', function() {
      loader = createLoader();
      spyOn(loader, '_parseLoadOptions');

      const externalObject = loader.setup();
      return expect(externalObject).toEqual(loader.externalObject);
    });
  });

  describe('#getCacheObject', () =>
    it('returns the object', function() {
      loader = createLoader();
      const opts = defaultLoadOptions();
      loader.setup(opts);
      const { cacheKey } = loader.loadOptions;

      expect(loader.getCacheObject()).toBeUndefined();
      const fakeCache = [{ key: 'tasks', id: 5 }];
      loader.storageManager.getCollectionDetails(
        loader._getCollectionName()
      ).cache[cacheKey] = fakeCache;
      return expect(loader.getCacheObject()).toEqual(fakeCache);
    }));

  describe('#load', function() {
    describe('sanity checking loadOptions', function() {
      let funct = null;

      beforeEach(function() {
        loader = createLoader();
        spyOn(loader, '_checkCacheForData');
        spyOn(loader, '_loadFromServer');
        return (funct = () => loader.load());
      });

      it('throws if there are no loadOptions', () => expect(funct).toThrow());

      return it('does not throw if there are loadOptions', function() {
        loader.loadOptions = {};
        return expect(funct).not.toThrow();
      });
    });

    return describe('checking the cache', function() {
      beforeEach(function() {
        loader = createLoader();
        spyOn(loader, '_checkCacheForData');
        return spyOn(loader, '_loadFromServer');
      });

      context('loadOptions.cache is true', function() {
        it('calls #_checkCacheForData', function() {
          loader.setup();
          expect(loader.loadOptions.cache).toEqual(true);

          loader.load();
          return expect(loader._checkCacheForData).toHaveBeenCalled();
        });

        context('#_checkCacheForData returns data', () =>
          it('returns the data', function() {
            const fakeData = ['some', 'stuff'];
            loader._checkCacheForData.and.returnValue(fakeData);

            loader.setup();
            return expect(loader.load()).toEqual(fakeData);
          })
        );

        return context('#_checkCacheForData does not return data', () =>
          it('calls #_loadFromServer', function() {
            loader.setup();
            loader.load();
            return expect(loader._loadFromServer).toHaveBeenCalled();
          })
        );
      });

      return context('loadOptions.cache is false', function() {
        it('does not call #_checkCacheForData', function() {
          loader.setup({ cache: false });

          loader.load();
          return expect(loader._checkCacheForData).not.toHaveBeenCalled();
        });

        return it('calls #_loadFromServer', function() {
          loader.setup();
          loader.load();
          return expect(loader._loadFromServer).toHaveBeenCalled();
        });
      });
    });
  });

  describe('#_getIdsForAssociation', () =>
    it('returns the flattened, unique, sorted, and non-null IDs from the models that are returned from #_getModelsForAssociation', function() {
      loader = createLoader();
      return expect(loader._getIdsForAssociation('foo')).toEqual([
        1,
        2,
        4,
        5,
        6
      ]);
    }));

  describe('#_updateObjects', function() {
    let fakeObj = null;

    beforeEach(function() {
      loader = createLoader();
      fakeObj = { setLoaded: jasmine.createSpy() };
      return loader._updateObjects.and.callThrough();
    });

    it('sets the object to loaded if silent is false', function() {
      loader._updateObjects(fakeObj, {});
      return expect(fakeObj.setLoaded).toHaveBeenCalled();
    });

    return it('does not set the object to loaded if silent is true', function() {
      loader._updateObjects(fakeObj, {}, true);
      return expect(fakeObj.setLoaded).not.toHaveBeenCalled();
    });
  });

  describe('#_parseLoadOptions', function() {
    let opts = null;

    beforeEach(function() {
      loader = createLoader();
      return (opts = defaultLoadOptions());
    });

    it('saves off a reference of the loadOptions as originalOptions', function() {
      loader._parseLoadOptions(defaultLoadOptions());
      return expect(loader.originalOptions).toEqual(defaultLoadOptions());
    });

    it('parses the include options', function() {
      opts.include = [{ foo: ['bar'] }, 'toad', 'stool'];
      const loadOptions = loader._parseLoadOptions(opts);

      return expect(loadOptions.include).toEqual([
        { foo: [{ bar: [] }] },
        { toad: [] },
        { stool: [] }
      ]);
    });

    describe('only parsing', function() {
      context('only is present', () =>
        it('sets only as an array of strings from the original only', function() {
          opts.only = [1, 2, 3, 4];
          const loadOptions = loader._parseLoadOptions(opts);

          return expect(loadOptions.only).toEqual(['1', '2', '3', '4']);
        })
      );

      return context('only is not present', () =>
        it('sets only as null', function() {
          const loadOptions = loader._parseLoadOptions(opts);
          return expect(loadOptions.only).toEqual(null);
        })
      );
    });

    it('defaults filters to an empty object', function() {
      let filters;
      let loadOptions = loader._parseLoadOptions(opts);
      expect(loadOptions.filters).toEqual({});

      // make sure it leaves them alone if they are present
      opts.filters = filters = { foo: 'bar' };
      loadOptions = loader._parseLoadOptions(opts);
      return expect(loadOptions.filters).toEqual(filters);
    });

    it('pulls of the top layer of includes and sets them as thisLayerInclude', function() {
      opts.include = [{ foo: ['bar'], toad: ['stool'] }, 'mushroom'];
      const loadOptions = loader._parseLoadOptions(opts);
      return expect(loadOptions.thisLayerInclude).toEqual([
        'foo',
        'toad',
        'mushroom'
      ]);
    });

    it('defaults cache to true', function() {
      let loadOptions = loader._parseLoadOptions(opts);
      expect(loadOptions.cache).toEqual(true);

      // make sure it leaves cache alone if it is present
      opts.cache = false;
      loadOptions = loader._parseLoadOptions(opts);
      return expect(loadOptions.cache).toEqual(false);
    });

    it('sets cache to false if search is present', function() {
      opts = _.extend(opts, { cache: true, search: 'term' });

      const loadOptions = loader._parseLoadOptions(opts);
      return expect(loadOptions.cache).toEqual(false);
    });

    it('builds a cache key', function() {
      // order, filterKeys, page, perPage, limit, offset
      const myOpts = {
        order: 'myOrder',
        filters: {
          key1: 'value1',
          key2: 'value2',
          key3: {
            value1: 'a',
            value2: 'b'
          }
        },
        page: 1,
        perPage: 200,
        limit: 50,
        offset: 0,
        only: [3, 1, 2],
        search: 'foobar'
      };

      opts = _.extend(opts, myOpts);
      const loadOptions = loader._parseLoadOptions(opts);
      return expect(loadOptions.cacheKey).toEqual(
        'myOrder|{"key1":"value1","key2":"value2","key3":{"value1":"a","value2":"b"}}|1,2,3|1|200|50|0|foobar'
      );
    });

    return it('sets the cachedCollection on the loader from the storageManager', function() {
      loader._parseLoadOptions(opts);
      return expect(loader.cachedCollection).toEqual(
        loader.storageManager.storage(loader.loadOptions.name)
      );
    });
  });

  describe('#_checkCacheForData', function() {
    let taskTwo;
    let opts = null;
    let taskOne = (taskTwo = null);

    beforeEach(function() {
      loader = createLoader();
      opts = defaultLoadOptions();
      spyOn(loader, '_onLoadSuccess');

      taskOne = buildTask({ id: 2 });
      return (taskTwo = buildTask({ id: 3 }));
    });

    const notFound = function(loader, opts) {
      loader.setup(opts);
      const ret = loader._checkCacheForData();

      expect(ret).toEqual(false);
      return expect(loader._onLoadSuccess).not.toHaveBeenCalled();
    };

    context('only query', function() {
      beforeEach(() => (opts.only = ['2', '3']));

      context('the requested IDs have all been loaded', function() {
        beforeEach(() =>
          loader.storageManager.storage('tasks').add([taskOne, taskTwo])
        );

        return it('calls #_onLoadSuccess with the models from the cache', function() {
          loader.setup(opts);
          loader._checkCacheForData();
          return expect(loader._onLoadSuccess.calls.argsFor(0)[0]).toEqual([
            taskOne,
            taskTwo
          ]);
        });
      });

      context('the requested IDs have not all been loaded', function() {
        beforeEach(() => loader.storageManager.storage('tasks').add([taskOne]));

        return it('returns false and does not call #_onLoadSuccess', function() {
          loader.setup(opts);
          return notFound(loader, opts);
        });
      });

      context(
        'when optional fields have been requested but the fields arent on all the tasks',
        function() {
          beforeEach(function() {
            opts.optionalFields = ['test_field'];
            taskOne.set('test_field', 'fake value');
            loader.storageManager.storage('tasks').add([taskOne, taskTwo]);
            return loader.setup(opts);
          });

          it('returns false', () =>
            expect(loader._checkCacheForData()).toEqual(false));

          return it('does not call #_onLoadSuccess', function() {
            loader._checkCacheForData();
            return expect(loader._onLoadSuccess).not.toHaveBeenCalled();
          });
        }
      );

      return context(
        'when optional fields have been requested and the fields are already on the tasks',
        function() {
          beforeEach(function() {
            opts.optionalFields = ['test_field'];
            taskOne.set('test_field', 'fake value for one');
            taskTwo.set('test_field', 'fake value for two');
            loader.storageManager.storage('tasks').add([taskOne, taskTwo]);
            loader.setup(opts);
            return loader._checkCacheForData();
          });

          return it('calls #_onLoadSuccess with the models from the cache', () =>
            expect(loader._onLoadSuccess.calls.argsFor(0)[0]).toEqual([
              taskOne,
              taskTwo
            ]));
        }
      );
    });

    return context('not an only query', function() {
      context('there exists a cache with this cacheKey', function() {
        beforeEach(() => loader.storageManager.storage('tasks').add(taskOne));

        context('cache is valid', function() {
          beforeEach(function() {
            const fakeCacheObject = {
              count: 1,
              results: [{ key: 'tasks', id: taskOne.id }],
              valid: true
            };

            return (loader.storageManager.getCollectionDetails('tasks').cache[
              'updated_at:desc|||||||'
            ] = fakeCacheObject);
          });

          context(
            'all of the cached models have their associations loaded',
            function() {
              beforeEach(() =>
                taskOne.set('project_id', buildAndCacheProject().id, {
                  silent: true
                })
              );

              return it('calls #_onLoadSuccess with the models from the cache', function() {
                opts.include = ['project'];
                loader.setup(opts);
                loader._checkCacheForData();
                return expect(
                  loader._onLoadSuccess.calls.argsFor(0)[0]
                ).toEqual([taskOne]);
              });
            }
          );

          context(
            'all of the cached models do not have their associations loaded',
            () =>
              it('returns false and does not call #_onLoadSuccess', function() {
                opts.include = ['project'];
                loader.setup(opts);
                return notFound(loader, opts);
              })
          );

          context(
            'all of the cached models have their optional fields loaded',
            function() {
              beforeEach(function() {
                taskOne.set('test_field', 'test value', { silent: true });
                opts.optionalFields = ['test_field'];
                loader.setup(opts);
                return loader._checkCacheForData();
              });

              return it('calls #_onLoadSuccess with the models from the cache', () =>
                expect(loader._onLoadSuccess).toHaveBeenCalledWith([taskOne]));
            }
          );

          return context(
            'all of the cached models do not have their optional fields loaded',
            function() {
              beforeEach(function() {
                opts.optionalFields = ['test_field'];
                return loader.setup(opts);
              });

              it('returns false', () =>
                expect(loader._checkCacheForData()).toEqual(false));

              return it('does not call #_onLoadSuccess', function() {
                loader._checkCacheForData();
                return expect(loader._onLoadSuccess).not.toHaveBeenCalled();
              });
            }
          );
        });

        return context('cache is invalid', function() {
          beforeEach(function() {
            const fakeCacheObject = {
              count: 1,
              results: [{ key: 'tasks', id: taskOne.id }],
              valid: false
            };

            return (loader.storageManager.getCollectionDetails('tasks').cache[
              'updated_at:desc||||||'
            ] = fakeCacheObject);
          });

          return it('returns false and does not call #_onLoadSuccess', function() {
            loader.setup(opts);
            return notFound(loader, opts);
          });
        });
      });

      return context('there is no cache with this cacheKey', () =>
        it('does not call #_onLoadSuccess and returns false', function() {
          loader.setup(opts);
          return notFound(loader, opts);
        })
      );
    });
  });

  describe('#_loadFromServer', function() {
    let syncOpts;
    let opts = (syncOpts = null);

    beforeEach(function() {
      loader = createLoader();
      opts = defaultLoadOptions();
      syncOpts = { data: 'foo' };

      spyOn(Backbone, 'sync').and.returnValue($.ajax());
      return spyOn(loader, '_buildSyncOptions').and.returnValue(syncOpts);
    });

    it('calls Backbone.sync with the read, the, internalObject, and #_buildSyncOptions', function() {
      loader.setup(opts);
      loader._loadFromServer();
      return expect(Backbone.sync).toHaveBeenCalledWith(
        'read',
        loader.internalObject,
        syncOpts
      );
    });

    it('puts the jqXhr on the returnValues if present', function() {
      let returnValues;
      opts.returnValues = returnValues = {};
      loader.setup(opts);

      loader._loadFromServer();
      return expect(returnValues.jqXhr.success).not.toBeUndefined();
    });

    return it('returns the externalObject', function() {
      loader.setup(opts);
      const ret = loader._loadFromServer();
      return expect(ret).toEqual(loader.externalObject);
    });
  });

  describe('#_calculateAdditionalIncludes', function() {
    let opts = null;

    beforeEach(function() {
      loader = createLoader();
      opts = defaultLoadOptions();

      return spyOn(loader, '_getIdsForAssociation').and.returnValue([1, 2]);
    });

    return it('adds each additional (sub) include to the additionalIncludes array', function() {
      opts.include = fakeNestedInclude;
      loader.setup(opts);

      loader._calculateAdditionalIncludes();
      expect(loader.additionalIncludes.length).toEqual(2);
      return expect(loader.additionalIncludes).toEqual([
        { name: 'project', ids: [1, 2], include: [{ participants: [] }] },
        { name: 'assignees', ids: [1, 2], include: [{ something_else: [] }] }
      ]);
    });
  });

  describe('#_loadAdditionalIncludes', function() {
    let opts = null;

    beforeEach(function() {
      loader = createLoader();
      opts = _.extend(defaultLoadOptions(), {
        cache: false,
        headers: {
          'X-Feature-Name': 'a-feature'
        }
      });
      opts.include = fakeNestedInclude;

      loader.setup(opts);
      loader._calculateAdditionalIncludes();

      return spyOn(loader, '_onLoadingCompleted');
    });

    it('respects "cache" option in nested includes', function() {
      spyOn(loader.storageManager, 'loadObject');
      loader._loadAdditionalIncludes();
      const { calls } = loader.storageManager.loadObject;
      expect(calls.count()).toBeGreaterThan(0);

      return Array.from(calls.all()).map(call =>
        expect(call.args[1].cache).toBe(false)
      );
    });

    it('respects "feature_name" option in nested includes', function() {
      spyOn(loader.storageManager, 'loadObject');
      loader._loadAdditionalIncludes();
      const { calls } = loader.storageManager.loadObject;
      expect(calls.count()).toBeGreaterThan(0);

      return Array.from(calls.all()).map(call =>
        expect(call.args[1].headers['X-Feature-Name']).toBe('a-feature')
      );
    });

    it('creates a request for each additional include and calls #_onLoadingCompleted when they all are done', function() {
      const promises = [];
      spyOn(loader.storageManager, 'loadObject').and.callFake(function() {
        const promise = $.Deferred();
        promises.push(promise);
        return promise;
      });

      loader._loadAdditionalIncludes();
      expect(loader.storageManager.loadObject.calls.count()).toEqual(2);
      expect(promises.length).toEqual(2);
      expect(loader._onLoadingCompleted).not.toHaveBeenCalled();

      for (let promise of Array.from(promises)) {
        promise.resolve();
      }

      return expect(loader._onLoadingCompleted).toHaveBeenCalled();
    });

    return describe('batching', function() {
      beforeEach(function() {
        spyOn(loader, '_getIdsForAssociation').and.returnValue([1, 2, 3, 4, 5]);
        return spyOn(loader.storageManager, 'loadObject');
      });

      context('there are less than the associated ID limit', function() {
        beforeEach(() => (loader.associationIdLimit = 100));

        return it('makes a single request for each association', function() {
          loader._loadAdditionalIncludes();
          return expect(loader.storageManager.loadObject.calls.count()).toEqual(
            2
          );
        });
      });

      return context('there are more than the associated ID limit', function() {
        beforeEach(() => (loader.associationIdLimit = 2));

        return it('makes multiple requests for each association', function() {
          loader._loadAdditionalIncludes();
          return expect(loader.storageManager.loadObject.calls.count()).toEqual(
            6
          );
        });
      });
    });
  });

  describe('#_buildSyncOptions', function() {
    let opts;
    const syncOptions = (opts = null);

    beforeEach(function() {
      loader = createLoader();
      return (opts = defaultLoadOptions());
    });

    const getSyncOptions = function(loader, opts) {
      loader.setup(opts);
      return loader._buildSyncOptions();
    };

    it('sets parse to true', () =>
      expect(getSyncOptions(loader, opts).parse).toEqual(true));

    it('sets error as #_onServerLoadError', () =>
      expect(getSyncOptions(loader, opts).error).toEqual(
        loader._onServerLoadError
      ));

    it('sets success as #_onServerLoadSuccess', () =>
      expect(getSyncOptions(loader, opts).success).toEqual(
        loader._onServerLoadSuccess
      ));

    it('sets data.include to be the layer of includes that this loader is loading', function() {
      opts.include = [
        { task: [{ workspace: ['participants'] }] },
        'time_entries'
      ];

      return expect(getSyncOptions(loader, opts).data.include).toEqual(
        'task,time_entries'
      );
    });

    it('sets the headers', function() {
      opts.headers = {
        'X-Custom-Header': 'custom-header-value'
      };

      return expect(
        getSyncOptions(loader, opts).headers['X-Custom-Header']
      ).toEqual('custom-header-value');
    });

    describe('data.only', function() {
      context('this is an only load', function() {
        context('#_shouldUseOnly returns true', function() {
          beforeEach(() =>
            spyOn(loader, '_shouldUseOnly').and.returnValue(true)
          );

          return it('sets data.only to comma separated ids', function() {
            opts.only = [1, 2, 3, 4];
            return expect(getSyncOptions(loader, opts).data.only).toEqual(
              '1,2,3,4'
            );
          });
        });

        return context('#_shouldUseOnly returns false', function() {
          beforeEach(() =>
            spyOn(loader, '_shouldUseOnly').and.returnValue(true)
          );

          return it('does not set data.only', () =>
            expect(getSyncOptions(loader, opts).data.only).toBeUndefined());
        });
      });

      return context('this is not an only load', () =>
        it('does not set data.only', () =>
          expect(getSyncOptions(loader, opts).data.only).toBeUndefined())
      );
    });

    describe('data.order', () =>
      it('sets order to be loadOptions.order if present', function() {
        opts.order = 'foo';
        return expect(getSyncOptions(loader, opts).data.order).toEqual('foo');
      }));

    describe('extending data with filters and custom params', function() {
      const blacklist = [
        'include',
        'only',
        'order',
        'per_page',
        'page',
        'limit',
        'offset',
        'search'
      ];

      const excludesBlacklistFromObject = function(object) {
        for (var key of Array.from(blacklist)) {
          object[key] = 'overwritten';
        }

        const { data } = getSyncOptions(loader, opts);

        return (() => {
          const result = [];
          for (key of Array.from(blacklist)) {
            result.push(expect(data[key]).toBeUndefined());
          }
          return result;
        })();
      };

      context('filters do not exist', function() {
        beforeEach(() => (opts.filters = undefined));

        return it('does not throw an error parsing filters', function() {
          expect();
          return expect(() => getSyncOptions(loader, opts)).not.toThrow();
        });
      });

      context('filters exist', function() {
        beforeEach(() => (opts.filters = {}));

        it('includes filter in data object', function() {
          opts.filters.foo = 'bar';

          const { data } = getSyncOptions(loader, opts);

          return expect(data.foo).toEqual('bar');
        });

        return it('excludes blacklisted brainstem specific keys from filters', () =>
          excludesBlacklistFromObject(opts.filters));
      });

      context('params do not exist', function() {
        beforeEach(() => (opts.params = undefined));

        return it('does not throw an error parsing params', () =>
          expect(() => getSyncOptions(loader, opts)).not.toThrow());
      });

      return context('custom params exist', function() {
        beforeEach(() => (opts.params = {}));

        it('includes custom params in data object', function() {
          opts.params = { color: 'red' };

          const { data } = getSyncOptions(loader, opts);

          return expect(data.color).toEqual('red');
        });

        return it('excludes blacklisted brainstem specific keys from custom params', () =>
          excludesBlacklistFromObject(opts.params));
      });
    });

    describe('pagination', function() {
      beforeEach(function() {
        opts.offset = 0;
        opts.limit = 25;
        opts.perPage = 25;
        return (opts.page = 1);
      });

      context('not an only request', function() {
        context('there is a limit and offset', function() {
          it('adds limit and offset', function() {
            const { data } = getSyncOptions(loader, opts);
            expect(data.limit).toEqual(25);
            return expect(data.offset).toEqual(0);
          });

          return it('does not add per_page and page', function() {
            const { data } = getSyncOptions(loader, opts);
            expect(data.per_page).toBeUndefined();
            return expect(data.page).toBeUndefined();
          });
        });

        return context('there is not a limit and offset', function() {
          beforeEach(function() {
            delete opts.limit;
            return delete opts.offset;
          });

          it('adds per_page and page', function() {
            const { data } = getSyncOptions(loader, opts);
            expect(data.per_page).toEqual(25);
            return expect(data.page).toEqual(1);
          });

          return it('does not add limit and offset', function() {
            const { data } = getSyncOptions(loader, opts);
            expect(data.limit).toBeUndefined();
            return expect(data.offset).toBeUndefined();
          });
        });
      });

      return context('only request', function() {
        beforeEach(() => (opts.only = 1));

        return it('does not add limit, offset, per_page, or page', function() {
          const { data } = getSyncOptions(loader, opts);
          expect(data.limit).toBeUndefined();
          expect(data.offset).toBeUndefined();
          expect(data.per_page).toBeUndefined();
          return expect(data.page).toBeUndefined();
        });
      });
    });

    return describe('data.search', () =>
      it('sets data.search to be loadOptions.search if present', function() {
        opts.search = 'term';
        return expect(getSyncOptions(loader, opts).data.search).toEqual('term');
      }));
  });

  describe('#_shouldUseOnly', function() {
    it('returns true if internalObject is an instance of a Backbone.Collection', function() {
      loader = createLoader();
      loader.internalObject = new Backbone.Collection();
      return expect(loader._shouldUseOnly()).toEqual(true);
    });

    return it('returns false if internalObject is not an instance of a Backbone.Collection', function() {
      loader = createLoader();
      loader.internalObject = new Backbone.Model();
      return expect(loader._shouldUseOnly()).toEqual(false);
    });
  });

  describe('#_modelsOrObj', function() {
    beforeEach(() => (loader = createLoader()));

    context('obj is a Backbone.Collection', () =>
      it('returns the models from the collection', function() {
        const collection = new Backbone.Collection();
        collection.add([new Backbone.Model(), new Backbone.Model()]);
        return expect(loader._modelsOrObj(collection)).toEqual(
          collection.models
        );
      })
    );

    context('obj is a single object', () =>
      it('returns obj wrapped in an array', function() {
        const obj = new Backbone.Model();
        return expect(loader._modelsOrObj(obj)).toEqual([obj]);
      })
    );

    context('obj is an array', () =>
      it('returns obj', function() {
        const obj = [];
        return expect(loader._modelsOrObj(obj)).toEqual(obj);
      })
    );

    return context('obj is undefined', () =>
      it('returns an empty array', function() {
        const obj = null;
        return expect(loader._modelsOrObj(obj)).toEqual([]);
      })
    );
  });

  describe('#_onServerLoadSuccess', function() {
    beforeEach(function() {
      loader = createLoader();
      return spyOn(loader, '_onLoadSuccess');
    });

    it('calls #_updateStorageManagerFromResponse with the response', function() {
      loader._onServerLoadSuccess('response');
      return expect(
        loader._updateStorageManagerFromResponse
      ).toHaveBeenCalledWith('response');
    });

    return it('calls #_onServerLoadSuccess with the result from #_updateStorageManagerFromResponse', function() {
      loader._updateStorageManagerFromResponse.and.returnValue('data');

      loader._onServerLoadSuccess();
      return expect(loader._onLoadSuccess).toHaveBeenCalledWith('data');
    });
  });

  describe('#_onLoadSuccess', function() {
    beforeEach(function() {
      loader = createLoader();
      loader.additionalIncludes = [];
      spyOn(loader, '_onLoadingCompleted');
      spyOn(loader, '_loadAdditionalIncludes');
      return spyOn(loader, '_calculateAdditionalIncludes');
    });

    it('calls #_updateObjects with the internalObject, the data, and silent set to true', function() {
      loader._onLoadSuccess('test data');
      return expect(loader._updateObjects).toHaveBeenCalledWith(
        loader.internalObject,
        'test data',
        true
      );
    });

    it('calls #_calculateAdditionalIncludes', function() {
      loader._onLoadSuccess();
      return expect(loader._calculateAdditionalIncludes).toHaveBeenCalled();
    });

    context('additional includes are needed', () =>
      it('calls #_loadAdditionalIncludes', function() {
        loader._calculateAdditionalIncludes.and.callFake(function() {
          return (this.additionalIncludes = ['foo']);
        });

        loader._onLoadSuccess();
        expect(loader._loadAdditionalIncludes).toHaveBeenCalled();
        return expect(loader._onLoadingCompleted).not.toHaveBeenCalled();
      })
    );

    return context('additional includes are not needed', () =>
      it('calls #_onLoadingCompleted', function() {
        loader._onLoadSuccess();
        expect(loader._onLoadingCompleted).toHaveBeenCalled();
        return expect(loader._loadAdditionalIncludes).not.toHaveBeenCalled();
      })
    );
  });

  return describe('#_onLoadingCompleted', function() {
    beforeEach(() => (loader = createLoader()));

    it('calls #_updateObjects with the externalObject and internalObject', function() {
      loader._onLoadingCompleted();
      return expect(loader._updateObjects).toHaveBeenCalledWith(
        loader.externalObject,
        loader.internalObject
      );
    });

    return it('resolves the deferred object with the externalObject', function() {
      const spy = jasmine.createSpy();
      loader.then(spy);

      loader._onLoadingCompleted();
      return expect(spy).toHaveBeenCalledWith(loader.externalObject);
    });
  });
});
