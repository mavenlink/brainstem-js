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
const StorageManager = require('../../src/storage-manager');
const CollectionLoader = require('../../src/loaders/collection-loader');
const Collection = require('../../src/collection');

const Task = require('../helpers/models/task');
const Tasks = require('../helpers/models/tasks');

describe('Loaders CollectionLoader', function() {
  let opts;
  let loader = (opts = null);
  const fakeNestedInclude = [
    'parent',
    { project: ['participants'] },
    { assignees: ['something_else'] }
  ];
  const loaderClass = CollectionLoader;

  const defaultLoadOptions = () => ({ name: 'tasks' });

  const createLoader = function(opts) {
    if (opts == null) {
      opts = {};
    }
    const storageManager = StorageManager.get();
    storageManager.addCollection('tasks', Tasks);

    const defaults = { storageManager };

    loader = new loaderClass(_.extend({}, defaults, opts));
    return loader;
  };

  // It should keep the AbstractLoader behavior.
  itShouldBehaveLike('AbstractLoaderSharedBehavior', { loaderClass });

  return describe('CollectionLoader behavior', function() {
    beforeEach(function() {
      loader = createLoader();
      return (opts = defaultLoadOptions());
    });

    describe('#getCollection', () =>
      it('should return the externalObject', function() {
        loader.setup(opts);
        return expect(loader.getCollection()).toEqual(loader.externalObject);
      }));

    describe('#_getCollectionName', () =>
      it('should return the name from loadOptions', function() {
        loader.setup(opts);
        return expect(loader._getCollectionName()).toEqual('tasks');
      }));

    describe('#_getModel', () =>
      it('returns the model from the internal collection', function() {
        loader.setup(opts);
        return expect(loader._getModel()).toEqual(Task);
      }));

    describe('#_getModelsForAssociation', () =>
      it('returns the models for a given association from all of the models in the internal collection', function() {
        loader.setup(opts);
        const user = buildAndCacheUser();
        const user2 = buildAndCacheUser();

        loader.internalObject.add(new Task({ assignee_ids: [user.id] }));
        loader.internalObject.add(new Task({ assignee_ids: [user2.id] }));

        expect(loader._getModelsForAssociation('assignees')).toEqual([
          [user],
          [user2]
        ]); // Association with a model in it
        expect(loader._getModelsForAssociation('parent')).toEqual([[], []]); // Association without any models
        return expect(loader._getModelsForAssociation('adfasfa')).toEqual([
          [],
          []
        ]);
      })); // Association that does not exist

    describe('#_createObjects', function() {
      let collection = null;

      beforeEach(function() {
        collection = new Tasks();
        return spyOn(
          loader.storageManager,
          'createNewCollection'
        ).and.returnValue(collection);
      });

      it('creates a new collection from the name in loadOptions', function() {
        loader.setup(opts);
        expect(loader.storageManager.createNewCollection.calls.count()).toEqual(
          2
        );
        return expect(loader.internalObject).toEqual(collection);
      });

      context('collection is passed in to loadOptions', () =>
        it('uses the collection that is passed in', function() {
          if (opts.collection == null) {
            opts.collection = new Tasks();
          }
          loader.setup(opts);
          return expect(loader.externalObject).toEqual(opts.collection);
        })
      );

      context('collection is not passed in to loadOptions', () =>
        it('creates a new collection from the name in loadOptions', function() {
          loader.setup(opts);
          expect(
            loader.storageManager.createNewCollection.calls.count()
          ).toEqual(2);
          return expect(loader.externalObject).toEqual(collection);
        })
      );

      it('sets the collection to not loaded', function() {
        spyOn(collection, 'setLoaded');
        loader.setup(opts);
        return expect(collection.setLoaded).toHaveBeenCalledWith(false);
      });

      describe('resetting the collection', function() {
        context('loadOptions.reset is true', function() {
          beforeEach(() => (opts.reset = true));

          return it('calls reset on the collection', function() {
            spyOn(collection, 'reset');
            loader.setup(opts);
            return expect(collection.reset).toHaveBeenCalled();
          });
        });

        return context('loadOptions.reset is false', () =>
          it('does not reset the collection', function() {
            spyOn(collection, 'reset');
            loader.setup(opts);
            return expect(collection.reset).not.toHaveBeenCalled();
          })
        );
      });

      return it('sets lastFetchOptions on the collection', function() {
        const list = [
          'filters',
          'page',
          'perPage',
          'limit',
          'offset',
          'order',
          'search'
        ];

        for (var e of Array.from(list)) {
          opts[e] = true;
        }

        opts.include = 'parent';
        loader.setup(opts);

        expect(loader.externalObject.lastFetchOptions.name).toEqual('tasks');
        expect(loader.externalObject.lastFetchOptions.include).toEqual(
          'parent'
        );
        expect(loader.externalObject.lastFetchOptions.cacheKey).toEqual(
          loader.loadOptions.cacheKey
        );

        return (() => {
          const result = [];
          for (e of Array.from(list)) {
            result.push(
              expect(loader.externalObject.lastFetchOptions[e]).toEqual(true)
            );
          }
          return result;
        })();
      });
    });

    describe('#_updateObject', function() {
      it('triggers loaded on the object after the attributes have been set', function() {
        const loadedSpy = jasmine.createSpy().and.callFake(function() {
          return expect(this.length).toEqual(1);
        }); // make sure that the spy is called after the models have been added (tests the trigger: false)

        loader.setup(opts);
        loader.internalObject.listenTo(
          loader.internalObject,
          'loaded',
          loadedSpy
        );

        loader._updateObjects(loader.internalObject, [{ foo: 'bar' }]);
        return expect(loadedSpy).toHaveBeenCalled();
      });

      it('works with a Backbone.Collection', function() {
        loader.setup(opts);
        loader._updateObjects(
          loader.internalObject,
          new Backbone.Collection([new Backbone.Model({ name: 'foo' })])
        );
        return expect(loader.internalObject.length).toEqual(1);
      });

      it('works with an array of models', function() {
        loader.setup(opts);
        loader._updateObjects(loader.internalObject, [
          new Backbone.Model({ name: 'foo' }),
          new Backbone.Model({ name: 'test' })
        ]);
        return expect(loader.internalObject.length).toEqual(2);
      });

      return it('works with a single model', function() {
        loader.setup(opts);
        const spy = jasmine.createSpy();
        loader.internalObject.listenTo(loader.internalObject, 'reset', spy);

        loader._updateObjects(
          loader.internalObject,
          new Backbone.Model({ name: 'foo' })
        );
        expect(loader.internalObject.length).toEqual(1);
        return expect(spy).toHaveBeenCalled();
      });
    });

    return describe('#_updateStorageManagerFromResponse', function() {
      // TODO: everything that is not tested here is tested right now through integration tests for StorageManager.

      let fakeResponse = null;

      beforeEach(
        () =>
          (fakeResponse = {
            count: 5,
            results: [
              { key: 'tasks', id: 1 },
              { key: 'tasks', id: 2 },
              { key: 'tasks', id: 3 },
              { key: 'tasks', id: 4 },
              { key: 'tasks', id: 5 }
            ]
          })
      );

      describe('forwarding the silent argument to Collection#update', function() {
        beforeEach(function() {
          spyOn(Collection.prototype, 'update');
          return (fakeResponse = {
            count: 1,
            results: [{ key: 'tasks', id: 1 }],
            tasks: [{ id: 1, title: 'title' }]
          });
        });

        context('when the silent argument is true', function() {
          beforeEach(function() {
            loader.setup(_.extend(opts, { silent: true }));
            return loader._updateStorageManagerFromResponse(fakeResponse);
          });

          return it('calls Collection#update with { silent: true }', () =>
            expect(
              Collection.prototype.update
            ).toHaveBeenCalledWith(fakeResponse.tasks, { silent: true }));
        });

        return context('when the silent argument is false', function() {
          beforeEach(function() {
            loader.setup(_.extend(opts, { silent: false }));
            return loader._updateStorageManagerFromResponse(fakeResponse);
          });

          return it('calls Collection#update with { silent: false }', () =>
            expect(
              Collection.prototype.update
            ).toHaveBeenCalledWith(fakeResponse.tasks, { silent: false }));
        });
      });

      return describe('updating the cache', function() {
        it('caches the count from the response in the cacheObject', function() {
          loader.setup(opts);
          expect(loader.getCacheObject()).toBeUndefined();

          loader._updateStorageManagerFromResponse(fakeResponse);
          const cacheObject = loader.getCacheObject();
          expect(cacheObject).not.toBeUndefined();
          expect(cacheObject.count).toEqual(fakeResponse.count);
          return expect(cacheObject.results).toEqual(fakeResponse.results);
        });

        return describe('cache option', function() {
          it('updates the cache when true', function() {
            loader.setup(_.extend(opts, { cache: true }));
            expect(loader.getCacheObject()).toBeUndefined();

            loader._updateStorageManagerFromResponse(fakeResponse);
            return expect(loader.getCacheObject()).not.toBeUndefined();
          });

          return it('updates the cache when false', function() {
            loader.setup(_.extend(opts, { cache: false }));
            expect(loader.getCacheObject()).toBeUndefined();

            loader._updateStorageManagerFromResponse(fakeResponse);
            return expect(loader.getCacheObject()).not.toBeUndefined();
          });
        });
      });
    });
  });
});
