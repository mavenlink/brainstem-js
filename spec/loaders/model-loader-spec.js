/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const $ = require('jquery');
const _ = require('underscore');
const Backbone = require('backbone');
Backbone.$ = $; // TODO remove after upgrading to backbone 1.2+
const StorageManager = require('../../src/storage-manager');
const ModelLoader = require('../../src/loaders/model-loader');

const Task = require('../helpers/models/task');
const Tasks = require('../helpers/models/tasks');

describe('Loaders ModelLoader', function() {
  let opts;
  let loader = (opts = null);
  const fakeNestedInclude = [
    'parent',
    { project: ['participants'] },
    { assignees: ['something_else'] }
  ];
  const loaderClass = ModelLoader;

  const defaultLoadOptions = () => ({
    name: 'task',
    only: 1
  });

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

  return describe('ModelLoader behavior', function() {
    beforeEach(function() {
      loader = createLoader();
      return (opts = defaultLoadOptions());
    });

    describe('#getModel', () =>
      it('should return the externalObject', function() {
        loader.setup(opts);
        return expect(loader.getModel()).toEqual(loader.externalObject);
      }));

    describe('#_getCollectionName', () =>
      it('returns the pluralized name of the model', function() {
        loader.setup(opts);
        return expect(loader._getCollectionName()).toEqual('tasks');
      }));

    describe('#_getModel', () =>
      it('returns the constructor of the internalObject', function() {
        loader.setup(opts);
        return expect(loader._getModel()).toEqual(Task);
      }));

    describe('#_getModelsForAssociation', () =>
      it('returns the models from the internalObject for a given association', function() {
        loader.setup(opts);
        const user = buildAndCacheUser();
        loader.internalObject.set('assignee_ids', [user.id]);

        expect(loader._getModelsForAssociation('assignees')).toEqual([user]); // Association with a model in it
        expect(loader._getModelsForAssociation('parent')).toEqual([]); // Association without any models
        return expect(loader._getModelsForAssociation('adfasfa')).toEqual([]);
      })); // Association that does not exist

    describe('#_createObjects', function() {
      let model = null;

      context('there is a matching model in the storageManager', () =>
        it('sets the internalObject to be the cached model', function() {
          model = buildAndCacheTask({ id: 1 });
          loader.setup(opts);
          return expect(loader.internalObject).toEqual(model);
        })
      );

      context(
        'there is not a matching model in the storageManager',
        function() {
          it('creates a new model and uses that as the internalObject', function() {
            model = new Task();
            spyOn(loader.storageManager, 'createNewModel').and.returnValue(
              model
            );
            loader.setup(opts);
            return expect(loader.internalObject).toEqual(model);
          });

          return it('sets the ID on that model', function() {
            loader.setup(opts);
            return expect(loader.internalObject.id).toEqual('1');
          });
        }
      );

      return it('uses the internalObject as the externalObject', function() {
        loader.setup(opts);
        return expect(loader.internalObject).toEqual(loader.externalObject);
      });
    });

    describe('#_updateStorageManagerFromResponse', () =>
      it('calls parse on the internalObject with the response', function() {
        loader.setup(opts);
        spyOn(loader.internalObject, 'parse');

        loader._updateStorageManagerFromResponse('test response');
        return expect(loader.internalObject.parse).toHaveBeenCalledWith(
          'test response'
        );
      }));

    return describe('#_updateObjects', function() {
      it('works with a Backbone.Model', function() {
        loader.setup(opts);
        loader._updateObjects(
          loader.internalObject,
          new Backbone.Model({ name: 'foo' })
        );
        return expect(loader.internalObject.get('name')).toEqual('foo');
      });

      it('works with an array with a Backbone.Model', function() {
        loader.setup(opts);
        loader._updateObjects(loader.internalObject, [
          new Backbone.Model({ name: 'foo' })
        ]);
        return expect(loader.internalObject.get('name')).toEqual('foo');
      });

      return it('works with an array of data', function() {
        loader.setup(opts);
        loader._updateObjects(loader.internalObject, [{ name: 'foo' }]);
        return expect(loader.internalObject.get('name')).toEqual('foo');
      });
    });
  });
});
