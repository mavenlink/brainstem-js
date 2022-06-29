/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const Collection = require('../src/collection');
const AbstractLoader = require('../src/loaders/abstract-loader');
const CollectionLoader = require('../src/loaders/collection-loader');
const Expectation = require('../src/expectation');

const StorageManager = require('../src/storage-manager');

describe('Expectations', function() {
  let project1, project2, task1;
  let storageManager = (project1 = project2 = task1 = null);

  beforeEach(function() {
    storageManager = StorageManager.get();
    storageManager.enableExpectations();

    project1 = buildProject({ id: 1, task_ids: [1] });
    project2 = buildProject({ id: 2 });
    return (task1 = buildTask({ id: 1, project_id: project1.id }));
  });

  afterEach(() => storageManager.disableExpectations());

  describe('fetch returned value', () =>
    describe('xhr api', () =>
      it('has abort', function() {
        storageManager.stub('projects', { response(stub) {} });
        const collection = storageManager.storage('projects');
        return expect(collection.fetch().abort).toBeDefined();
      })));

  describe('stubbing responses', function() {
    it('should update returned collections', function() {
      const expectation = storageManager.stub('projects', {
        response(stub) {
          return (stub.results = [project1, project2]);
        }
      });
      const collection = storageManager.loadCollection('projects');
      expect(collection.length).toEqual(0);
      expectation.respond();
      expect(collection.length).toEqual(2);
      expect(collection.get(1)).toEqual(project1);
      return expect(collection.get(2)).toEqual(project2);
    });

    it('should call callbacks', function() {
      const expectation = storageManager.stub('projects', {
        response(stub) {
          return (stub.results = [project1, project2]);
        }
      });
      let collection = null;
      storageManager.loadCollection('projects', {
        success(c) {
          return (collection = c);
        }
      });
      expect(collection).toBeNull();
      expectation.respond();
      expect(collection.length).toEqual(2);
      expect(collection.get(1)).toEqual(project1);
      return expect(collection.get(2)).toEqual(project2);
    });

    it('should add to passed-in collections', function() {
      const expectation = storageManager.stub('projects', {
        response(stub) {
          return (stub.results = [project1, project2]);
        }
      });
      const collection = new Collection();
      storageManager.loadCollection('projects', { collection });
      expect(collection.length).toEqual(0);
      expectation.respond();
      expect(collection.length).toEqual(2);
      expect(collection.get(1)).toEqual(project1);
      return expect(collection.get(2)).toEqual(project2);
    });

    it('should work with results hashes', function() {
      const expectation = storageManager.stub('projects', {
        response(stub) {
          stub.results = [
            { key: 'projects', id: 2 },
            { key: 'projects', id: 1 }
          ];
          return (stub.associated.projects = [project1, project2]);
        }
      });
      const collection = storageManager.loadCollection('projects');
      expectation.respond();
      expect(collection.length).toEqual(2);
      expect(collection.models[0]).toEqual(project2);
      return expect(collection.models[1]).toEqual(project1);
    });

    it('can populate associated objects', function() {
      const expectation = storageManager.stub('projects', {
        include: ['tasks'],
        response(stub) {
          stub.results = [project1, project2];
          stub.associated.projects = [project1, project2];
          return (stub.associated.tasks = [task1]);
        }
      });
      const collection = new Collection();
      storageManager.loadCollection('projects', {
        collection,
        include: ['tasks']
      });
      expectation.respond();
      expect(collection.get(1).get('tasks').models).toEqual([task1]);
      return expect(collection.get(2).get('tasks').models).toEqual([]);
    });

    context('count option is supplied', function() {
      let collection = null;

      beforeEach(function() {
        const expectation = storageManager.stub('projects', {
          count: 20,
          response(stub) {
            return (stub.results = [project1, project2]);
          }
        });

        collection = storageManager.loadCollection('projects');
        return expectation.respond();
      });

      return it('mocks cache object to return mocked count from getServerCount', () =>
        expect(collection.getServerCount()).toEqual(20));
    });

    context('count option is not supplied', function() {
      let collection = null;

      beforeEach(function() {
        const expectation = storageManager.stub('projects', {
          response(stub) {
            return (stub.results = [project1, project2]);
          }
        });

        collection = storageManager.loadCollection('projects');
        return expectation.respond();
      });

      return it('mocks cache object to return default count (result length) from getServerCount', () =>
        expect(collection.getServerCount()).toEqual(2));
    });

    describe('recursive loading', function() {
      context('recursive option is false', () =>
        it('should not try to recursively load includes in an expectation', function() {
          const expectation = storageManager.stub('projects', {
            include: '*',
            response(stub) {
              stub.results = [project1, project2];
              stub.associated.projects = [project1, project2];
              return (stub.associated.tasks = [task1]);
            }
          });

          const spy = spyOn(
            AbstractLoader.prototype,
            '_loadAdditionalIncludes'
          );
          const collection = storageManager.loadCollection('projects', {
            include: [{ tasks: ['time_entries'] }]
          });
          expectation.respond();
          return expect(spy).not.toHaveBeenCalled();
        })
      );

      return context('recursive option is true', () =>
        it('should recursively load includes in an expectation', function() {
          const expectation = storageManager.stub('projects', {
            include: '*',
            response(stub) {
              stub.results = [project1, project2];
              stub.associated.projects = [project1, project2];
              stub.associated.tasks = [task1];
              return (stub.recursive = true);
            }
          });

          const spy = spyOn(
            AbstractLoader.prototype,
            '_loadAdditionalIncludes'
          );
          const collection = storageManager.loadCollection('projects', {
            include: [{ tasks: ['time_entries'] }]
          });
          expectation.respond();
          return expect(spy).toHaveBeenCalled();
        })
      );
    });

    describe('triggering errors', function() {
      it('triggers errors when asked to do so', function() {
        const errorSpy = jasmine.createSpy();

        const collection = new Collection();

        const resp = {
          readyState: 4,
          status: 401,
          responseText: ''
        };

        const expectation = storageManager.stub('projects', {
          collection,
          triggerError: resp
        });

        storageManager.loadCollection('projects', { error: errorSpy });

        expectation.respond();
        expect(errorSpy).toHaveBeenCalled();
        return expect(errorSpy.calls.mostRecent().args[0]).toEqual(resp);
      });

      return it('does not trigger errors when asked not to', function() {
        const errorSpy = jasmine.createSpy();
        const expectation = storageManager.stub('projects', {
          response(exp) {
            return (exp.results = [project1, project2]);
          }
        });

        storageManager.loadCollection('projects', { error: errorSpy });

        expectation.respond();
        return expect(errorSpy).not.toHaveBeenCalled();
      });
    });

    return it('should work without specifying results', function() {
      storageManager.stubImmediate('projects');
      return expect(() =>
        storageManager.loadCollection('projects')
      ).not.toThrow();
    });
  });

  describe('responding immediately', () =>
    it('uses stubImmediate', function() {
      const expectation = storageManager.stubImmediate('projects', {
        include: ['tasks'],
        response(stub) {
          stub.results = [project1, project2];
          return (stub.associated.tasks = [task1]);
        }
      });
      const collection = storageManager.loadCollection('projects', {
        include: ['tasks']
      });
      return expect(collection.get(1).get('tasks').models).toEqual([task1]);
    }));

  describe('multiple stubs', function() {
    it('should match the first valid expectation', function() {
      storageManager.stubImmediate('projects', {
        only: [1],
        response(stub) {
          return (stub.results = [project1]);
        }
      });
      storageManager.stubImmediate('projects', {
        response(stub) {
          return (stub.results = [project1, project2]);
        }
      });
      storageManager.stubImmediate('projects', {
        only: [2],
        response(stub) {
          return (stub.results = [project2]);
        }
      });
      expect(
        storageManager.loadCollection('projects', { only: 1 }).models
      ).toEqual([project1]);
      expect(storageManager.loadCollection('projects').models).toEqual([
        project1,
        project2
      ]);
      return expect(
        storageManager.loadCollection('projects', { only: 2 }).models
      ).toEqual([project2]);
    });

    it('should fail if it cannot find a specific match', function() {
      storageManager.stubImmediate('projects', {
        response(stub) {
          return (stub.results = [project1]);
        }
      });
      storageManager.stubImmediate('projects', {
        include: ['tasks'],
        filters: { something: 'else' },
        response(stub) {
          stub.results = [project1, project2];
          return (stub.associated.tasks = [task1]);
        }
      });
      expect(
        storageManager.loadCollection('projects', {
          include: ['tasks'],
          filters: { something: 'else' }
        }).models
      ).toEqual([project1, project2]);
      expect(() =>
        storageManager.loadCollection('projects', {
          include: ['tasks'],
          filters: { something: 'wrong' }
        })
      ).toThrow();
      expect(() =>
        storageManager.loadCollection('projects', {
          include: ['users'],
          filters: { something: 'else' }
        })
      ).toThrow();
      expect(() =>
        storageManager.loadCollection('projects', {
          filters: { something: 'else' }
        })
      ).toThrow();
      expect(() =>
        storageManager.loadCollection('projects', { include: ['users'] })
      ).toThrow();
      return expect(storageManager.loadCollection('projects').models).toEqual([
        project1
      ]);
    });

    it('should ignore empty arrays', function() {
      storageManager.stubImmediate('projects', {
        response(stub) {
          return (stub.results = [project1, project2]);
        }
      });
      return expect(
        storageManager.loadCollection('projects', { include: [] }).models
      ).toEqual([project1, project2]);
    });

    return it('should allow wildcard params', function() {
      storageManager.stubImmediate('projects', {
        include: '*',
        response(stub) {
          stub.results = [project1, project2];
          return (stub.associated.tasks = [task1]);
        }
      });
      expect(
        storageManager.loadCollection('projects', { include: ['tasks'] }).models
      ).toEqual([project1, project2]);
      expect(
        storageManager.loadCollection('projects', { include: ['users'] }).models
      ).toEqual([project1, project2]);
      return expect(storageManager.loadCollection('projects').models).toEqual([
        project1,
        project2
      ]);
    });
  });

  describe('recording', () =>
    it('should record options', function() {
      const expectation = storageManager.stubImmediate('projects', {
        filters: { something: 'else' },
        response(stub) {
          return (stub.results = [project1, project2]);
        }
      });
      storageManager.loadCollection('projects', {
        filters: { something: 'else' }
      });
      return expect(expectation.matches[0].filters).toEqual({
        something: 'else'
      });
    }));

  describe('clearing expectations', () =>
    it('expectations can be removed', function() {
      const expectation = storageManager.stub('projects', {
        include: ['tasks'],
        response(stub) {
          stub.results = [project1, project2];
          return (stub.associated.tasks = [task1]);
        }
      });

      const collection = storageManager.loadCollection('projects', {
        include: ['tasks']
      });
      expectation.respond();
      expect(collection.get(1).get('tasks').models).toEqual([task1]);

      const collection2 = storageManager.loadCollection('projects', {
        include: ['tasks']
      });
      expect(collection2.get(1)).toBeFalsy();
      expectation.respond();
      expect(collection2.get(1).get('tasks').models).toEqual([task1]);

      expectation.remove();
      return expect(() => storageManager.loadCollection('projects')).toThrow();
    }));

  describe('lastMatch', function() {
    it('retrives the last match object', function() {
      const expectation = storageManager.stubImmediate('projects', {
        include: '*',
        response(stub) {
          return (stub.results = []);
        }
      });

      storageManager.loadCollection('projects', { include: ['tasks'] });
      storageManager.loadCollection('projects', { include: ['users'] });

      expect(expectation.matches.length).toEqual(2);
      return expect(expectation.lastMatch().include).toEqual(['users']);
    });

    return it('returns undefined if no matches exist', function() {
      const expectation = storageManager.stub('projects', {
        response(stub) {
          return (stub.results = []);
        }
      });
      return expect(expectation.lastMatch()).toBeUndefined();
    });
  });

  describe('loaderOptionsMatch', function() {
    it('should ignore wrapping arrays', function() {
      const expectation = new Expectation(
        'projects',
        { include: 'workspaces' },
        storageManager
      );
      const loader = new CollectionLoader({ storageManager });

      loader.setup({ name: 'projects', include: 'workspaces' });
      expect(expectation.loaderOptionsMatch(loader)).toBe(true);

      loader.setup({ name: 'projects', include: ['workspaces'] });
      return expect(expectation.loaderOptionsMatch(loader)).toBe(true);
    });

    it('should treat * as an any match', function() {
      const expectation = new Expectation(
        'projects',
        { include: '*' },
        storageManager
      );

      let loader = new CollectionLoader({ storageManager });
      loader.setup({ name: 'projects', include: 'workspaces' });
      expect(expectation.loaderOptionsMatch(loader)).toBe(true);

      loader = new CollectionLoader({ storageManager });
      loader.setup({ name: 'projects', include: ['anything'] });
      expect(expectation.loaderOptionsMatch(loader)).toBe(true);

      loader = new CollectionLoader({ storageManager });
      loader.setup({ name: 'projects' }, {});
      return expect(expectation.loaderOptionsMatch(loader)).toBe(true);
    });

    it('should treat strings and numbers the same when appropriate', function() {
      const expectation = new Expectation(
        'projects',
        { only: '1' },
        storageManager
      );

      let loader = new CollectionLoader({ storageManager });
      loader.setup({ name: 'projects', only: 1 });
      expect(expectation.loaderOptionsMatch(loader)).toBe(true);

      loader = new CollectionLoader({ storageManager });
      loader.setup({ name: 'projects', only: '1' });
      return expect(expectation.loaderOptionsMatch(loader)).toBe(true);
    });

    it('should treat null, empty array, and empty object the same', function() {
      let expectation = new Expectation(
        'projects',
        { filters: {} },
        storageManager
      );

      let loader = new CollectionLoader({ storageManager });
      loader.setup({ name: 'projects', filters: null });
      expect(expectation.loaderOptionsMatch(loader)).toBe(true);

      loader = new CollectionLoader({ storageManager });
      loader.setup({ name: 'projects', filters: {} });
      expect(expectation.loaderOptionsMatch(loader)).toBe(true);

      loader = new CollectionLoader({ storageManager });
      loader.setup({ name: 'projects' }, {});
      expect(expectation.loaderOptionsMatch(loader)).toBe(true);

      loader = new CollectionLoader({ storageManager });
      loader.setup({ name: 'projects', filters: { foo: 'bar' } });
      expect(expectation.loaderOptionsMatch(loader)).toBe(false);

      expectation = new Expectation('projects', {}, storageManager);

      loader = new CollectionLoader({ storageManager });
      loader.setup({ name: 'projects', filters: null });
      expect(expectation.loaderOptionsMatch(loader)).toBe(true);

      loader = new CollectionLoader({ storageManager });
      loader.setup({ name: 'projects', filters: {} });
      expect(expectation.loaderOptionsMatch(loader)).toBe(true);

      loader = new CollectionLoader({ storageManager });
      loader.setup({ name: 'projects' }, {});
      expect(expectation.loaderOptionsMatch(loader)).toBe(true);

      loader = new CollectionLoader({ storageManager });
      loader.setup({ name: 'projects', filters: { foo: 'bar' } });
      return expect(expectation.loaderOptionsMatch(loader)).toBe(false);
    });

    return context('when collection loader is given valid options', function() {
      let expected_filters,
        expected_optionalFields,
        expected_order,
        expected_page,
        expected_perPage,
        expected_search;
      let expected_include = (expected_filters = expected_page = expected_perPage = null);
      let expected_limit_offset = (expected_order = expected_search = expected_optionalFields = null);

      beforeEach(function() {
        expected_include = new Expectation(
          'projects',
          { include: {} },
          storageManager
        );
        expected_filters = new Expectation(
          'projects',
          { filters: {} },
          storageManager
        );
        expected_page = new Expectation(
          'projects',
          { page: {} },
          storageManager
        );
        expected_perPage = new Expectation(
          'projects',
          { perPage: {} },
          storageManager
        );
        expected_limit_offset = new Expectation(
          'projects',
          { limit: '1', offset: '20' },
          storageManager
        );
        expected_order = new Expectation(
          'projects',
          { order: {} },
          storageManager
        );
        expected_search = new Expectation(
          'projects',
          { search: {} },
          storageManager
        );
        return (expected_optionalFields = new Expectation(
          'projects',
          { optionalFields: {} },
          storageManager
        ));
      });

      context('when loaded values match expected values', () =>
        it('expects loader to be valid', function() {
          let loader = new CollectionLoader({ storageManager });
          loader.setup({ name: 'projects', include: {} });
          expect(expected_include.loaderOptionsMatch(loader)).toBe(true);

          loader = new CollectionLoader({ storageManager });
          loader.setup({ name: 'projects', filters: {} });
          expect(expected_filters.loaderOptionsMatch(loader)).toBe(true);

          loader = new CollectionLoader({ storageManager });
          loader.setup({ name: 'projects', page: {} });
          expect(expected_page.loaderOptionsMatch(loader)).toBe(true);

          loader = new CollectionLoader({ storageManager });
          loader.setup({ name: 'projects', perPage: {} });
          expect(expected_perPage.loaderOptionsMatch(loader)).toBe(true);

          // limit and offset must be present, or this will always return false
          // this is due to storage-manager._checkPageSettings
          loader = new CollectionLoader({ storageManager });
          loader.setup({ name: 'projects', limit: '1', offset: '20' });
          expect(expected_limit_offset.loaderOptionsMatch(loader)).toBe(true);

          loader = new CollectionLoader({ storageManager });
          loader.setup({ name: 'projects', order: {} });
          expect(expected_order.loaderOptionsMatch(loader)).toBe(true);

          loader = new CollectionLoader({ storageManager });
          loader.setup({ name: 'projects', search: {} });
          expect(expected_search.loaderOptionsMatch(loader)).toBe(true);

          loader = new CollectionLoader({ storageManager });
          loader.setup({ name: 'projects', optionalFields: {} });
          return expect(
            expected_optionalFields.loaderOptionsMatch(loader)
          ).toBe(true);
        })
      );

      return context('when loaded values do not match expected values', () =>
        it('expects the loader to not be valid', function() {
          let loader = new CollectionLoader({ storageManager });
          loader.setup({ name: 'projects', include: { foo: 'bar' } });
          expect(expected_include.loaderOptionsMatch(loader)).toBe(false);

          loader = new CollectionLoader({ storageManager });
          loader.setup({ name: 'projects', filters: { foo: 'bar' } });
          expect(expected_filters.loaderOptionsMatch(loader)).toBe(false);

          loader = new CollectionLoader({ storageManager });
          loader.setup({ name: 'projects', page: { foo: 'bar' } });
          expect(expected_page.loaderOptionsMatch(loader)).toBe(false);

          loader = new CollectionLoader({ storageManager });
          loader.setup({ name: 'projects', perPage: { foo: 'bar' } });
          expect(expected_perPage.loaderOptionsMatch(loader)).toBe(false);

          // limit and offset must be present, or this will always return false
          // this is due to storage-manager._checkPageSettings
          loader = new CollectionLoader({ storageManager });
          loader.setup({ name: 'projects', limit: '1', offset: '25' });
          expect(expected_limit_offset.loaderOptionsMatch(loader)).toBe(false);
          loader.setup({ name: 'projects', limit: '3', offset: '20' });
          expect(expected_limit_offset.loaderOptionsMatch(loader)).toBe(false);
          loader.setup({ name: 'projects', limit: '3', offset: '25' });
          expect(expected_limit_offset.loaderOptionsMatch(loader)).toBe(false);
          loader.setup({ name: 'projects', limit: '1' });
          expect(expected_limit_offset.loaderOptionsMatch(loader)).toBe(false);
          loader.setup({ name: 'projects', offset: '20' });
          expect(expected_limit_offset.loaderOptionsMatch(loader)).toBe(false);

          loader = new CollectionLoader({ storageManager });
          loader.setup({ name: 'projects', order: { foo: 'bar' } });
          expect(expected_order.loaderOptionsMatch(loader)).toBe(false);

          loader = new CollectionLoader({ storageManager });
          loader.setup({ name: 'projects', search: { foo: 'bar' } });
          expect(expected_search.loaderOptionsMatch(loader)).toBe(false);

          loader = new CollectionLoader({ storageManager });
          loader.setup({ name: 'projects', optionalFields: { foo: 'bar' } });
          return expect(
            expected_optionalFields.loaderOptionsMatch(loader)
          ).toBe(false);
        })
      );
    });
  });

  return describe('stubbing models', function() {
    context(
      'a model that matches the load is already in the storage storageManager',
      () =>
        it('updates that model', function() {
          const project = buildAndCacheProject();

          const expectation = storageManager.stubModel('project', project.id, {
            response(stub) {
              return (stub.result = buildProject({
                id: project.id,
                title: 'foobar'
              }));
            }
          });

          const loaderSpy = jasmine
            .createSpy('loader')
            .and.callFake(function(model) {
              expect(model.id).toEqual(project.id);
              return expect(model.get('title')).toEqual('foobar');
            });

          const loader = storageManager.loadModel('project', project.id);
          loader.done(loaderSpy);

          expectation.respond();
          expect(loaderSpy).toHaveBeenCalled();
          return expect(storageManager.storage('projects').length).toEqual(1);
        })
    );

    return context('a model is not already in the storage storageManager', () =>
      it('adds the model from the loader to the storageManager', function() {
        const project = buildProject();
        const stubbedProject = buildProject({
          id: project.id,
          title: 'foobar'
        });

        const expectation = storageManager.stubModel('project', project.id, {
          response(stub) {
            return (stub.result = stubbedProject);
          }
        });

        const loader = storageManager.loadModel('project', project.id);

        const loaderSpy = jasmine
          .createSpy('loader')
          .and.callFake(function(model) {
            expect(model).toEqual(loader.getModel());
            expect(model.attributes).toEqual(stubbedProject.attributes);
            expect(storageManager.storage('projects').get(project.id)).toEqual(
              loader.getModel()
            );
            return expect(model.get('title')).toEqual('foobar');
          });

        loader.done(loaderSpy);

        expectation.respond();
        expect(loaderSpy).toHaveBeenCalled();
        return expect(storageManager.storage('projects').length).toEqual(1);
      })
    );
  });
});
