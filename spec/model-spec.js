/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * DS205: Consider reworking code to avoid use of IIFEs
 * DS206: Consider reworking classes to avoid initClass
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const _ = require('underscore');
const $ = require('jquery');
const Backbone = require('backbone');
Backbone.$ = $; // TODO remove after upgrading to backbone 1.2+

const Utils = require('../src/utils');
const Model = require('../src/model');
const StorageManager = require('../src/storage-manager');

const Post = require('./helpers/models/post');
const Project = require('./helpers/models/project');
const Task = require('./helpers/models/task');
const User = require('./helpers/models/user');
const TimeEntry = require('./helpers/models/time-entry');

describe('Model', function() {
  let storageManager;
  let model = (storageManager = null);

  beforeEach(function() {
    storageManager = StorageManager.get();
    return storageManager.reset();
  });

  describe('instantiation', function() {
    let newModel = null;

    const itReturnsCachedInstance = () =>
      it('returns cached instance', () => expect(newModel).toEqual(model));

    const itReturnsNewInstance = () =>
      it('returns new instance', function() {
        expect(newModel).not.toEqual(model);
        return expect(newModel).toEqual(jasmine.any(Task));
      });

    beforeEach(
      () =>
        (model = storageManager
          .storage('tasks')
          .add(buildTask({ project_id: 1 })))
    );

    context('id is provided', function() {
      context('storage manager cache does not exist', function() {
        let cache = null;

        beforeEach(function() {
          cache = storageManager.collections;
          return (storageManager.collections = {});
        });

        afterEach(() => (storageManager.collections = cache));

        return it('does not throw an error trying to access storage manager', () =>
          expect(() => new Task({ id: model.id })).not.toThrow());
      });

      context('model is cached in storage manager', function() {
        context('"cached" option is set to `false`', function() {
          beforeEach(
            () => (newModel = new Task({ id: model.id }, { cached: false }))
          );

          return itReturnsNewInstance();
        });

        context('new model attributes are valid', function() {
          beforeEach(function() {
            spyOn(model, '_validate').and.returnValue(true);
            return (newModel = new Task({ id: model.id }));
          });

          itReturnsCachedInstance();

          context('model class does not define associations', function() {
            beforeEach(function() {
              model = storageManager.storage('users').add(buildUser());
              return (newModel = new User({ id: model.id }));
            });

            return itReturnsCachedInstance();
          });

          return context('association attributes are provided', function() {
            beforeEach(
              () => (newModel = new Task({ id: model.id, project_id: 2 }))
            );

            itReturnsCachedInstance();

            it('does not overwrite existing association attributes', () =>
              expect(+newModel.get('project_id')).toEqual(1));

            return context('with blacklist option', function() {
              beforeEach(
                () =>
                  (newModel = new Task(
                    { id: model.id, project_id: 2 },
                    { blacklist: [] }
                  ))
              );

              return it('does overwrite the existing association attributes', () =>
                expect(+newModel.get('project_id')).toEqual(2));
            });
          });
        });

        return context('new model attributes are invalid', function() {
          beforeEach(function() {
            spyOn(model, '_validate').and.returnValue(false);
            return (newModel = new Task({ id: model.id }));
          });

          return itReturnsNewInstance();
        });
      });

      return context('model is not cached in storage manager', function() {
        beforeEach(() => (newModel = new Task({ id: model.id + 1 })));

        return itReturnsNewInstance();
      });
    });

    return context('id is not provided', function() {
      beforeEach(() => (newModel = new Task()));

      return itReturnsNewInstance();
    });
  });

  describe('#clone', function() {
    let clonedCachedModel, clonedModel;
    let cachedModel = (clonedModel = clonedCachedModel = null);

    beforeEach(function() {
      model = buildTask();
      cachedModel = buildAndCacheTask();

      clonedModel = model.clone();
      return (clonedCachedModel = cachedModel.clone());
    });

    it('clones model', function() {
      expect(model.attributes).toEqual(clonedModel.attributes);
      return expect(model.cid).not.toEqual(clonedModel.cid);
    });

    return it('clones cached model', function() {
      expect(cachedModel.attributes).toEqual(clonedCachedModel.attributes);
      return expect(cachedModel.cid).not.toEqual(clonedCachedModel.cid);
    });
  });

  describe('#fetch', function() {
    let deferred = null;

    beforeEach(function() {
      deferred = $.Deferred();
      model = buildAndCacheTask();

      return spyOn(storageManager, 'loadObject').and.returnValue(deferred);
    });

    context(
      'options has no name property and the model does not have a brainstem key',
      function() {
        beforeEach(() => (model.brainstemKey = undefined));

        return it('throws a brainstem error', () =>
          expect(() => model.fetch()).toThrow());
      }
    );

    context(
      'options has a name property and the model does not have a brainstem key',
      function() {
        beforeEach(() => (model.brainstemKey = undefined));

        return it('does not throw a brainstem error', () =>
          expect(() => model.fetch({ name: 'posts' })).not.toThrow());
      }
    );

    context(
      'options has no name property and the model does have a brainstem key',
      function() {
        beforeEach(() => (model.brainstemKey = 'posts'));

        return it('does not throw a brainstem error', () =>
          expect(() => model.fetch()).not.toThrow());
      }
    );

    it('calls wrapError', function() {
      const options = {
        only: [model.id],
        parse: true,
        name: 'posts',
        cache: false,
        returnValues: jasmine.any(Object)
      };

      spyOn(Utils, 'wrapError');

      model.fetch(options);

      return expect(Utils.wrapError).toHaveBeenCalledWith(
        model,
        jasmine.objectContaining(options)
      );
    });

    it('calls loadObject', function() {
      model.fetch();

      return expect(storageManager.loadObject).toHaveBeenCalledWith(
        'tasks',
        {
          only: [model.id],
          parse: true,
          name: 'tasks',
          error: jasmine.any(Function),
          cache: false,
          returnValues: jasmine.any(Object),
          model
        },
        { isCollection: false }
      );
    });

    it('on success, triggers sync', function() {
      const newModel = {};

      spyOn(model, 'trigger');

      model.fetch();
      deferred.resolve(newModel);

      return expect(model.trigger).toHaveBeenCalledWith('sync', newModel, {
        only: [model.id],
        name: 'tasks',
        parse: true,
        error: jasmine.any(Function),
        cache: false,
        returnValues: jasmine.any(Object),
        model
      });
    });

    return it('returns a promise', () =>
      expect(model.fetch()).toEqual(
        jasmine.objectContaining({
          done: jasmine.any(Function),
          fail: jasmine.any(Function),
          always: jasmine.any(Function)
        })
      ));
  });

  describe('fetch integration', function() {
    it('updates model with fetched attributes', function() {
      model = buildAndCacheTask();
      const updatedModel = buildTask({ description: 'updated description' });

      respondWith(server, `/api/tasks/${model.id}`, {
        resultsFrom: 'tasks',
        data: updatedModel
      });

      model.fetch();
      server.respond();

      return expect(model.attributes).toEqual(updatedModel.attributes);
    });

    it('caches new model reference on fetch', function() {
      const newTask = buildTask();

      respondWith(server, `/api/tasks/${newTask.id}`, {
        resultsFrom: 'tasks',
        data: newTask
      });

      const newModel = new Task({ id: newTask.id });
      newModel.fetch();

      server.respond();

      return expect(storageManager.storage('tasks').get(newModel.id)).toEqual(
        newModel
      );
    });

    it('updates new model reference', function() {
      const task = buildAndCacheTask();

      respondWith(server, `/api/tasks/${task.id}`, {
        resultsFrom: 'tasks',
        data: task
      });

      const newModel = new Task({ id: task.id });
      newModel.fetch();

      server.respond();

      return expect(task.attributes).toEqual(newModel.attributes);
    });

    context('model reference already exists in cache', () =>
      it('does not duplicate model reference ', function() {
        respondWith(server, '/api/tasks/1', {
          resultsFrom: 'tasks',
          data: model
        });

        model.fetch();
        server.respond();

        return expect(
          storageManager.storage('tasks').where({ id: model.id }).length
        ).toEqual(1);
      })
    );

    return it('returns a promise with jqXhr methods', function() {
      const task = buildTask();
      respondWith(server, '/api/tasks/1', { resultsFrom: 'tasks', data: task });

      const jqXhr = $.ajax();
      const promise = model.fetch();

      return (() => {
        const result = [];
        for (let key in jqXhr) {
          const value = jqXhr[key];
          const object = {};
          object[key] = jasmine.any(value.constructor);
          result.push(
            expect(promise).toEqual(jasmine.objectContaining(object))
          );
        }
        return result;
      })();
    });
  });

  describe('#parse', function() {
    let response = null;

    beforeEach(function() {
      model = new Task();
      return (response = {
        count: 1,
        results: [{ id: 1, key: 'tasks' }],
        tasks: { 1: { id: 1, title: 'Do Work' } }
      });
    });

    it('extracts object data from JSON with root keys', function() {
      const parsed = model.parse(response);
      return expect(parsed.id).toEqual(1);
    });

    it('passes through object data from flat JSON', function() {
      const parsed = model.parse({ id: 1 });
      return expect(parsed.id).toEqual(1);
    });

    it('should update the storage manager with the new model and its associations', function() {
      response.tasks[1].assignee_ids = [5, 6];
      response.users = {
        5: { id: 5, name: 'Jon' },
        6: { id: 6, name: 'Betty' }
      };

      model.parse(response);

      expect(storageManager.storage('tasks').get(1).attributes).toEqual(
        response.tasks[1]
      );
      expect(storageManager.storage('users').get(5).attributes).toEqual(
        response.users[5]
      );
      return expect(storageManager.storage('users').get(6).attributes).toEqual(
        response.users[6]
      );
    });

    context('when attributes are timestamp like', function() {
      let parsedAttrs = null;

      context('with a key ending in _at', function() {
        beforeEach(
          () =>
            (parsedAttrs = model.parse({
              updated_at: '2017-02-03T16:41:12+00:00'
            }))
        );

        return it('parse the date into a timestamp number', () =>
          expect(parsedAttrs.updated_at).toEqual(1486140072000));
      });

      context('with a key containing _at', function() {
        beforeEach(
          () =>
            (parsedAttrs = model.parse({
              thing_at_noon: '2017-02-03T16:41:12+00:00'
            }))
        );

        return it('keeps the value as is', () =>
          expect(parsedAttrs.thing_at_noon).toEqual(
            '2017-02-03T16:41:12+00:00'
          ));
      });

      context('with a key containing date', function() {
        beforeEach(
          () =>
            (parsedAttrs = model.parse({
              my_date_thing: '2017-02-03T16:41:12+00:00'
            }))
        );

        return it('parse the date into a timestamp number', () =>
          expect(parsedAttrs.my_date_thing).toEqual(1486140072000));
      });

      return context('with a generic key', function() {
        beforeEach(
          () =>
            (parsedAttrs = model.parse({ value: '2017-02-03T16:41:12+00:00' }))
        );

        return it('keeps the value as is', () =>
          expect(parsedAttrs.value).toEqual('2017-02-03T16:41:12+00:00'));
      });
    });

    describe('adding new models to the storage manager', function() {
      context('there is an ID on the model already', function() {
        // usually happens when fetching an existing model and not using StorageManager#loadModel
        // new Task(id: 5).fetch()

        beforeEach(() => model.set('id', 1));

        context('model ID matches response ID', () =>
          it('should add the parsing model to the storage manager', function() {
            response.tasks[1].id = 1;
            expect(storageManager.storage('tasks').get(1)).toBeUndefined();

            model.parse(response);
            expect(storageManager.storage('tasks').get(1)).not.toBeUndefined();
            expect(storageManager.storage('tasks').get(1)).toEqual(model);
            return expect(
              storageManager.storage('tasks').get(1).attributes
            ).toEqual(response.tasks[1]);
          })
        );

        return context('model ID does not match response ID', () =>
          // this only happens when an association has the same brainstemKey as the parent record
          // we want to add a new model to the storage manager and not worry about ourself

          it('should not add the parsing model to the storage manager', function() {
            response.tasks[1].id = 2345;
            expect(storageManager.storage('tasks').get(1)).toBeUndefined();

            model.parse(response);
            expect(storageManager.storage('tasks').get(1)).toBeUndefined();
            return expect(
              storageManager.storage('tasks').get(2345)
            ).not.toEqual(model);
          })
        );
      });

      return context(
        'there is not an ID on the model instance already',
        function() {
          // usually happens when creating a new model:
          // new Task(title: 'test').save()

          beforeEach(() => expect(model.id).toBeUndefined());

          return it('should add the parsing model to the storage manager', function() {
            response.tasks[1].title = 'Hello';
            expect(storageManager.storage('tasks').get(1)).toBeUndefined();

            model.parse(response);
            expect(storageManager.storage('tasks').get(1)).toEqual(model);
            return expect(
              storageManager
                .storage('tasks')
                .get(1)
                .get('title')
            ).toEqual('Hello');
          });
        }
      );
    });

    it('should work with an empty response', () =>
      expect(() =>
        model.parse({ tasks: {}, results: [], count: 0 })
      ).not.toThrow());

    describe('updateStorageManager', function() {
      it('updates the associations before the new model', function() {
        let tasksIndex;
        spyOn(storageManager, 'storage').and.callThrough();

        response.tasks[1].assignee_ids = [5];
        response.users = { 5: { id: 5, name: 'Jon' } };

        model.updateStorageManager(response);

        let usersIndex = (tasksIndex = null);

        _.each(storageManager.storage.calls.all(), function(call, index) {
          switch (call.args[0]) {
            case 'users':
              return (usersIndex = index);
            case 'tasks':
              return (tasksIndex = index);
          }
        });

        return expect(usersIndex).toBeLessThan(tasksIndex);
      });

      return it('should work with an empty response', () =>
        expect(() =>
          model.updateStorageManager({ count: 0, results: [] })
        ).not.toThrow());
    });

    it('should return the first object from the result set', function() {
      response.tasks[2] = { id: 2, title: 'foo' };
      response.results.unshift({ id: 2, key: 'tasks' });
      const parsed = model.parse(response);
      expect(parsed.id).toEqual(2);
      return expect(parsed.title).toEqual('foo');
    });

    it('should not blow up on server side validation error', function() {
      response = {
        errors: [
          "Invalid task state. Valid states are:'notstarted','started',and'completed'."
        ]
      };
      return expect(() => model.parse(response)).not.toThrow();
    });

    return describe('date handling', function() {
      it('parses ISO 8601 dates into date objects / milliseconds', function() {
        const parsed = model.parse({ created_at: '2013-01-25T11:25:57-08:00' });
        return expect(parsed.created_at).toEqual(1359141957000);
      });

      it('passes through dates in milliseconds already', function() {
        const parsed = model.parse({ created_at: 1359142047000 });
        return expect(parsed.created_at).toEqual(1359142047000);
      });

      it('parses dates on associated models', function() {
        response.tasks[1].created_at = '2013-01-25T11:25:57-08:00';
        response.tasks[1].assignee_ids = [5, 6];
        response.users = {
          5: { id: 5, name: 'John', created_at: '2013-02-25T11:25:57-08:00' },
          6: { id: 6, name: 'Betty', created_at: '2013-01-30T11:25:57-08:00' }
        };

        const parsed = model.parse(response);
        expect(parsed.created_at).toEqual(1359141957000);
        expect(
          storageManager
            .storage('users')
            .get(5)
            .get('created_at')
        ).toEqual(1361820357000);
        return expect(
          storageManager
            .storage('users')
            .get(6)
            .get('created_at')
        ).toEqual(1359573957000);
      });

      it('does not handle ISO 8601 dates with other characters', function() {
        const parsed = model.parse({
          created_at: 'blargh 2013-01-25T11:25:57-08:00 churghZ'
        });
        return expect(parsed.created_at).toEqual(
          'blargh 2013-01-25T11:25:57-08:00 churghZ'
        );
      });

      return it('parses a UTC date', function() {
        const parsed = model.parse({ created_at: '2019-04-23T18:30:29Z' });
        return expect(parsed.created_at).toEqual(1556044229000);
      });
    });
  });

  describe('associations', function() {
    class TestClass extends Model {
      static initClass() {
        this.associations = {
          user: 'users',
          project: 'projects',
          users: ['users'],
          projects: ['projects'],
          activity: ['tasks', 'posts']
        };
      }
    }
    TestClass.initClass();

    describe('associationDetails', function() {
      it('returns a hash containing the key, type and plural of the association', function() {
        expect(TestClass.associationDetails('user')).toEqual({
          key: 'user_id',
          type: 'BelongsTo',
          collectionName: 'users'
        });

        return expect(TestClass.associationDetails('users')).toEqual({
          key: 'user_ids',
          type: 'HasMany',
          collectionName: 'users'
        });
      });

      it('returns the correct association details for polymorphic associations', () =>
        expect(TestClass.associationDetails('activity')).toEqual({
          key: 'activity_ref',
          type: 'BelongsTo',
          collectionName: ['tasks', 'posts'],
          polymorphic: true
        }));

      it('is cached on the class for speed', function() {
        const original = TestClass.associationDetails('users');
        TestClass.associations.users = 'something_else';

        return expect(TestClass.associationDetails('users')).toEqual(original);
      });

      return it('returns falsy if the association cannot be found', () =>
        expect(TestClass.associationDetails("I'mNotAThing")).toBeFalsy());
    });

    describe('associationsAreLoaded', function() {
      let testClass = null;

      describe("when association is of type 'BelongsTo'", function() {
        context('and is not polymorphic', function() {
          beforeEach(
            () =>
              (testClass = new TestClass({
                id: 10,
                user_id: 20,
                project_id: 30
              }))
          );

          context('when association is loaded', function() {
            beforeEach(() => buildAndCacheUser({ id: 20 }));

            it('returns true', () =>
              expect(testClass.associationsAreLoaded(['user'])).toBe(true));

            context(
              'when association is requested with another association described on model class',
              function() {
                context('when other association is loaded', function() {
                  beforeEach(() => buildAndCacheProject({ id: 30 }));

                  return it('returns true', () =>
                    expect(
                      testClass.associationsAreLoaded(['user', 'project'])
                    ).toBe(true));
                });

                return context('when other association is not loaded', () =>
                  it('returns false', () =>
                    expect(
                      testClass.associationsAreLoaded(['user', 'project'])
                    ).toBe(false))
                );
              }
            );

            return context(
              'when association is requested with a association not described on model class',
              () =>
                it('returns true', () =>
                  expect(
                    testClass.associationsAreLoaded(['user', 'non_association'])
                  ).toBe(true))
            );
          });

          return context('when association is not loaded', function() {
            beforeEach(() =>
              expect(storageManager.storage('users').get(20)).toBeFalsy()
            );

            it('returns false', () =>
              expect(testClass.associationsAreLoaded(['user'])).toBe(false));

            context(
              'when association is requested with another association described on model class',
              function() {
                context('when other association is loaded', function() {
                  beforeEach(() => buildAndCacheProject({ id: 30 }));

                  return it('returns false', () =>
                    expect(
                      testClass.associationsAreLoaded(['user', 'project'])
                    ).toBe(false));
                });

                return context('when other association is not loaded', () =>
                  it('returns false', () =>
                    expect(
                      testClass.associationsAreLoaded(['user', 'project'])
                    ).toBe(false))
                );
              }
            );

            return context(
              'when association is requested with a association not described on model class',
              () =>
                it('returns false', () =>
                  expect(
                    testClass.associationsAreLoaded(['user', 'non_association'])
                  ).toBe(false))
            );
          });
        });

        return context('and is polymorphic', function() {
          beforeEach(
            () =>
              (testClass = new TestClass({
                id: 10,
                activity_ref: { id: 40, key: 'posts' },
                project_id: 30
              }))
          );

          context('when association is loaded', function() {
            beforeEach(() => buildAndCachePost({ id: 40 }));

            it('returns true', () =>
              expect(testClass.associationsAreLoaded(['activity'])).toBe(true));

            context(
              'when association is requested with another association described on model class',
              function() {
                context('when other association is loaded', function() {
                  beforeEach(() => buildAndCacheProject({ id: 30 }));

                  return it('returns true', () =>
                    expect(
                      testClass.associationsAreLoaded(['activity', 'project'])
                    ).toBe(true));
                });

                return context('when other association is not loaded', () =>
                  it('returns false', () =>
                    expect(
                      testClass.associationsAreLoaded(['activity', 'project'])
                    ).toBe(false))
                );
              }
            );

            return context(
              'when association is requested with a association not described on model class',
              () =>
                it('returns true', () =>
                  expect(
                    testClass.associationsAreLoaded([
                      'activity',
                      'non_association'
                    ])
                  ).toBe(true))
            );
          });

          return context('when association is not loaded', function() {
            beforeEach(() =>
              expect(storageManager.storage('posts').get(20)).toBeFalsy()
            );

            it('returns false', () =>
              expect(testClass.associationsAreLoaded(['activity'])).toBe(
                false
              ));

            context(
              'when association is requested with another association described on model class',
              function() {
                context('when other association is loaded', function() {
                  beforeEach(() => buildAndCacheProject({ id: 30 }));

                  return it('returns false', () =>
                    expect(
                      testClass.associationsAreLoaded(['activity', 'project'])
                    ).toBe(false));
                });

                return context('when other association is not loaded', () =>
                  it('returns false', () =>
                    expect(
                      testClass.associationsAreLoaded(['activity', 'project'])
                    ).toBe(false))
                );
              }
            );

            return context(
              'when association is requested with a association not described on model class',
              () =>
                it('returns false', () =>
                  expect(
                    testClass.associationsAreLoaded([
                      'activity',
                      'non_association'
                    ])
                  ).toBe(false))
            );
          });
        });
      });

      describe("when association is of type 'HasMany'", function() {
        beforeEach(
          () =>
            (testClass = new TestClass({
              id: 10,
              user_ids: [20, 30],
              project_ids: [40, 50]
            }))
        );

        context('when association is partially loaded', function() {
          beforeEach(() => buildAndCacheUser({ id: 20 }));

          return it('returns false', () =>
            expect(testClass.associationsAreLoaded(['users'])).toBe(false));
        });

        context('when association is loaded', function() {
          beforeEach(function() {
            buildAndCacheUser({ id: 20 });
            return buildAndCacheUser({ id: 30 });
          });

          it('returns true', () =>
            expect(testClass.associationsAreLoaded(['users'])).toBe(true));

          context(
            'when association is requested with another association described on model class',
            function() {
              context('when other association is loaded', function() {
                beforeEach(function() {
                  buildAndCacheProject({ id: 40 });
                  return buildAndCacheProject({ id: 50 });
                });

                return it('returns true', () =>
                  expect(
                    testClass.associationsAreLoaded(['users', 'projects'])
                  ).toBe(true));
              });

              return context('when other association is not loaded', () =>
                it('returns false', () =>
                  expect(
                    testClass.associationsAreLoaded(['users', 'projects'])
                  ).toBe(false))
              );
            }
          );

          return context(
            'when association is requested with a association not described on model class',
            () =>
              it('returns true', () =>
                expect(
                  testClass.associationsAreLoaded(['users', 'non_associations'])
                ).toBe(true))
          );
        });

        return context('when association is not loaded', function() {
          beforeEach(function() {
            expect(storageManager.storage('users').get(20)).toBeFalsy();
            return expect(storageManager.storage('users').get(30)).toBeFalsy();
          });

          it('returns false', () =>
            expect(testClass.associationsAreLoaded(['users'])).toBe(false));

          context(
            'when association is requested with another association described on model class',
            function() {
              context('when other association is loaded', function() {
                beforeEach(function() {
                  buildAndCacheProject({ id: 40 });
                  return buildAndCacheProject({ id: 50 });
                });

                return it('returns false', () =>
                  expect(
                    testClass.associationsAreLoaded(['users', 'projects'])
                  ).toBe(false));
              });

              return context('when other association is not loaded', () =>
                it('returns false', () =>
                  expect(
                    testClass.associationsAreLoaded(['users', 'projects'])
                  ).toBe(false))
              );
            }
          );

          return context(
            'when association is requested with a association not described on model class',
            () =>
              it('returns false', () =>
                expect(
                  testClass.associationsAreLoaded(['users', 'non_associations'])
                ).toBe(false))
          );
        });
      });

      describe('when given association does not exist', function() {
        beforeEach(() => (testClass = new TestClass()));

        return it('returns true', () =>
          expect(testClass.associationsAreLoaded(['non_association'])).toBe(
            true
          ));
      });

      return describe('when given association is empty', function() {
        beforeEach(() => (testClass = new TestClass()));

        return it('returns true', () =>
          expect(testClass.associationsAreLoaded([])).toBe(true));
      });
    });

    return describe('#get', function() {
      let timeEntry = null;

      afterEach(() => storageManager.reset());

      describe('attributes not defined as associations', function() {
        beforeEach(
          () =>
            (timeEntry = new TimeEntry({
              id: 5,
              project_id: 10,
              task_id: 2,
              title: 'foo'
            }))
        );

        context('when attribute exists', function() {
          it('should delegate to Backbone.Model#get', function() {
            const getSpy = spyOn(Backbone.Model.prototype, 'get');

            timeEntry.get('title');

            return expect(getSpy).toHaveBeenCalledWith('title');
          });

          return it('returns correct value', () =>
            expect(timeEntry.get('title')).toEqual('foo'));
        });

        return context('does attribute does not exist', () =>
          it('returns undefined', () =>
            expect(timeEntry.get('missing')).toBeUndefined())
        );
      });

      describe('attributes defined as associations', function() {
        let collection = null;

        beforeEach(() => (timeEntry = new TimeEntry({ id: 5, task_id: 2 })));

        context('when an association id and association exists', function() {
          let user1, user2;
          let task = (user1 = user2 = null);

          beforeEach(function() {
            storageManager
              .storage('tasks')
              .add(buildTask({ id: 2, title: 'second time entry' }));

            user1 = buildAndCacheUser();
            user2 = buildAndCacheUser();

            return (task = buildAndCacheTask({
              id: 5,
              assignee_ids: [user1.id]
            }));
          });

          it('returns correct value', () =>
            expect(timeEntry.get('task')).toEqual(
              storageManager.storage('tasks').get(2)
            ));

          context('option link is true', function() {
            beforeEach(
              () => (collection = task.get('assignees', { link: true }))
            );

            it('changes to the returned collection are reflected on the models ids array', function() {
              expect(collection.at(0)).toBe(user1);

              collection.add(user2);

              expect(task.get('assignees').at(1).cid).toBe(user2.cid);

              collection.remove(user1);

              expect(task.get('assignees').at(1)).toBeUndefined();
              return expect(task.get('assignees').at(0).cid).toBe(user2.cid);
            });

            return it('asking for another linked collection returns the same instance of the collection', () =>
              expect(task.get('assignees', { link: true })).toBe(collection));
          });

          return context('option link is falsey', function() {
            beforeEach(
              () => (collection = task.get('assignees', { link: false }))
            );

            it('changes to the returned collection are not relfected on the models ids array', function() {
              expect(collection.at(0)).toBe(user1);

              collection.add(user2);

              return expect(task.get('assignees').at(1)).toBeUndefined();
            });

            return it('asking for another linked collection returns a new instance of the collection', () =>
              expect(task.get('assignees', { link: false })).not.toBe(
                collection
              ));
          });
        });

        return context(
          'when we have an association id that cannot be found',
          function() {
            beforeEach(() =>
              expect(storageManager.storage('tasks').get(2)).toBeFalsy()
            );

            it('should throw when silent is not supplied or falsy', function() {
              expect(() => timeEntry.get('task')).toThrow();
              expect(() => timeEntry.get('task', { silent: null })).toThrow();
              expect(() =>
                timeEntry.get('task', { silent: undefined })
              ).toThrow();
              return expect(() =>
                timeEntry.get('task', { silent: false })
              ).toThrow();
            });

            return it('should not throw when silent is true', () =>
              expect(() =>
                timeEntry.get('task', { silent: true })
              ).not.toThrow());
          }
        );
      });

      describe('BelongsTo associations', function() {
        beforeEach(() =>
          storageManager
            .storage('projects')
            .add({ id: 10, title: 'a project!' })
        );

        describe('when association is a non-polymorphic', function() {
          beforeEach(
            () =>
              (timeEntry = new TimeEntry({
                id: 5,
                project_id: 10,
                title: 'foo'
              }))
          );

          context('when association id is not present', () =>
            it('should return undefined', () =>
              expect(timeEntry.get('task')).toBeUndefined())
          );

          return context('when association id is present', function() {
            it('should delegate to Backbone.Model#get', function() {
              const getSpy = spyOn(Backbone.Model.prototype, 'get');

              timeEntry.get('project');

              return expect(getSpy).toHaveBeenCalledWith('project_id');
            });

            return it('should return association', () =>
              expect(timeEntry.get('project')).toEqual(
                storageManager.storage('projects').get(10)
              ));
          });
        });

        describe('when association is polymorphic', function() {
          let post = null;

          context('when association reference is not present', function() {
            beforeEach(() => (post = new Post({ id: 5 })));

            return it('should return undefined', () =>
              expect(post.get('subject')).toBeUndefined());
          });

          return context('when association reference is present', function() {
            beforeEach(
              () =>
                (post = new Post({
                  id: 5,
                  subject_ref: { id: '10', key: 'projects' }
                }))
            );

            it('should delegate to Backbone.Model#get', function() {
              const getSpy = spyOn(Backbone.Model.prototype, 'get');

              post.get('subject');

              return expect(getSpy).toHaveBeenCalledWith('subject_ref');
            });

            return it('should return association', () =>
              expect(post.get('subject')).toEqual(
                storageManager.storage('projects').get(10)
              ));
          });
        });

        return describe('when a form sets an association id to an empty string', function() {
          beforeEach(() => timeEntry.set('project_id', ''));

          return it('should not throw a Brainstem error', function() {
            expect(() => timeEntry.get('project')).not.toThrow();
            return expect(timeEntry.get('project')).toBe(undefined);
          });
        });
      });

      return describe('HasMany associations', function() {
        let project = null;

        beforeEach(function() {
          storageManager.storage('tasks').add({ id: 10, title: 'First Task' });
          storageManager.storage('tasks').add({ id: 11, title: 'Second Task' });
          return (project = new Project({ id: 25, task_ids: [10, 11] }));
        });

        context('when there are null values in id list', () =>
          it('ignores the null values', function() {
            project = new Project({
              id: 25,
              task_ids: [10, 11, null, undefined]
            });
            return expect(() => project.get('tasks')).not.toThrowError();
          })
        );

        context('when association ids is not present', () =>
          it('returns an empty collection', () =>
            expect(project.get('time_entries').models).toEqual([]))
        );

        return context('when association ids is present', function() {
          it('should delegate to Backbone.Model#get', function() {
            const getSpy = spyOn(Backbone.Model.prototype, 'get');

            project.get('tasks');

            return expect(getSpy).toHaveBeenCalledWith('task_ids');
          });

          it('should return association', function() {
            const tasks = project.get('tasks');

            expect(tasks.get(10)).toEqual(
              storageManager.storage('tasks').get(10)
            );
            return expect(tasks.get(11)).toEqual(
              storageManager.storage('tasks').get(11)
            );
          });

          return context('sort order', function() {
            let task = null;

            beforeEach(function() {
              buildAndCacheTask({ id: 103, position: 3, updated_at: 845785 });
              buildAndCacheTask({ id: 77, position: 2, updated_at: 995785 });
              buildAndCacheTask({ id: 99, position: 1, updated_at: 635785 });

              return (task = buildAndCacheTask({
                id: 5,
                sub_task_ids: [103, 77, 99]
              }));
            });

            context('not explicitly specified', () =>
              it('applies the default sort order', function() {
                const subTasks = task.get('sub_tasks');

                expect(subTasks.at(0).get('position')).toEqual(3);
                expect(subTasks.at(1).get('position')).toEqual(2);
                return expect(subTasks.at(2).get('position')).toEqual(1);
              })
            );

            return context('is explicitly specified', () =>
              it('applies the specified sort order', function() {
                const subTasks = task.get('sub_tasks', {
                  order: 'position:asc'
                });

                expect(subTasks.at(0).get('position')).toEqual(1);
                expect(subTasks.at(1).get('position')).toEqual(2);
                return expect(subTasks.at(2).get('position')).toEqual(3);
              })
            );
          });
        });
      });
    });
  });

  describe('#invalidateCache', () =>
    it('invalidates all cache objects that a model is a result in', function() {
      const { cache } = storageManager.getCollectionDetails(model.brainstemKey);
      model = buildTask();

      const cacheKey = {
        matching1: 'foo|bar',
        matching2: 'foo|bar|filter',
        notMatching: 'bar|bar'
      };

      cache[cacheKey.matching1] = {
        results: [
          { id: model.id },
          { id: buildTask().id },
          { id: buildTask().id }
        ],
        valid: true
      };

      cache[cacheKey.notMatching] = {
        results: [
          { id: buildTask().id },
          { id: buildTask().id },
          { id: buildTask().id }
        ],
        valid: true
      };

      cache[cacheKey.matching2] = {
        results: [
          { id: model.id },
          { id: buildTask().id },
          { id: buildTask().id }
        ],
        valid: true
      };

      // all cache objects should be valid
      expect(cache[cacheKey.matching1].valid).toEqual(true);
      expect(cache[cacheKey.matching2].valid).toEqual(true);
      expect(cache[cacheKey.notMatching].valid).toEqual(true);

      model.invalidateCache();

      // matching cache objects should be invalid
      expect(cache[cacheKey.matching1].valid).toEqual(false);
      expect(cache[cacheKey.matching2].valid).toEqual(false);
      return expect(cache[cacheKey.notMatching].valid).toEqual(true);
    }));

  describe('#toServerJSON', function() {
    it('calls toJSON', function() {
      const spy = spyOn(model, 'toJSON').and.callThrough();
      model.toServerJSON();
      return expect(spy).toHaveBeenCalled();
    });

    it('always removes default blacklisted keys', function() {
      const defaultBlacklistKeys = model.defaultJSONBlacklist();
      expect(defaultBlacklistKeys.length).toEqual(3);

      model.set('safe', true);
      for (var key of Array.from(defaultBlacklistKeys)) {
        model.set(key, true);
      }

      const json = model.toServerJSON('create');
      expect(json['safe']).toEqual(true);
      return (() => {
        const result = [];
        for (key of Array.from(defaultBlacklistKeys)) {
          result.push(expect(json[key]).toBeUndefined());
        }
        return result;
      })();
    });

    it('removes blacklisted keys for create actions', function() {
      const createBlacklist = ['flies', 'ants', 'fire ants'];
      spyOn(model, 'createJSONBlacklist').and.returnValue(createBlacklist);

      for (var key of Array.from(createBlacklist)) {
        model.set(key, true);
      }

      const json = model.toServerJSON('create');
      return (() => {
        const result = [];
        for (key of Array.from(createBlacklist)) {
          result.push(expect(json[key]).toBeUndefined());
        }
        return result;
      })();
    });

    it('removes blacklisted keys for update actions', function() {
      const updateBlacklist = ['possums', 'racoons', 'potatoes'];
      spyOn(model, 'updateJSONBlacklist').and.returnValue(updateBlacklist);

      for (var key of Array.from(updateBlacklist)) {
        model.set(key, true);
      }

      const json = model.toServerJSON('update');
      return (() => {
        const result = [];
        for (key of Array.from(updateBlacklist)) {
          result.push(expect(json[key]).toBeUndefined());
        }
        return result;
      })();
    });

    return describe('createJSONWhitelist, updateJSONWhitelist', function() {
      let expectedBlacklist, whitelist;
      let attributeKeys = (expectedBlacklist = whitelist = null);

      beforeEach(function() {
        whitelist = ['label', 'name'];

        model.updateJSONWhitelist = () => whitelist;

        model.createJSONWhitelist = () => whitelist;

        attributeKeys = ['possums', 'racoons', 'potatoes', 'label', 'name'];

        for (let key of Array.from(attributeKeys)) {
          model.set(key, true);
        }

        return (expectedBlacklist = ['possums', 'racoons', 'potatoes']);
      });

      context('create', () =>
        it("sets the blacklist to the model's attributes except for those in the whitelist", function() {
          const json = model.toServerJSON('create');

          for (var key of Array.from(expectedBlacklist)) {
            expect(json[key]).toBeUndefined();
          }

          return (() => {
            const result = [];
            for (key of Array.from(whitelist)) {
              result.push(expect(json[key]).toBeTruthy());
            }
            return result;
          })();
        })
      );

      return context('update', () =>
        it("sets the blacklist to the model's attributes except for those in the whitelist", function() {
          const json = model.toServerJSON('update');

          for (var key of Array.from(expectedBlacklist)) {
            expect(json[key]).toBeUndefined();
          }

          return (() => {
            const result = [];
            for (key of Array.from(whitelist)) {
              result.push(expect(json[key]).toBeTruthy());
            }
            return result;
          })();
        })
      );
    });
  });

  describe('#_linkCollection', function() {
    let story = null;

    beforeEach(() => (story = new Task()));

    context('when there is not an associated collection', function() {
      let collectionName, collectionOptions, field;
      let dummyCollection = (collectionName = collectionOptions = field = null);
      beforeEach(function() {
        collectionName = 'users';
        collectionOptions = {};
        field = 'assignees';
        expect(story._associatedCollections).toBeUndefined();

        dummyCollection = {
          on() {
            return 'dummy Collection';
          }
        };

        return spyOn(storageManager, 'createNewCollection').and.returnValue(
          dummyCollection
        );
      });

      it('returns an associated collection', function() {
        const collection = story._linkCollection(
          collectionName,
          [],
          collectionOptions,
          field
        );
        return expect(collection).toBe(dummyCollection);
      });

      it('saves a reference to the associated collection', function() {
        const collection = story._linkCollection(
          collectionName,
          [],
          collectionOptions,
          field
        );
        return expect(collection).toBe(story._associatedCollections.assignees);
      });

      return it('getting a different collection craetes a second key on _associatedCollections', function() {
        const collection = story._linkCollection(
          collectionName,
          [],
          collectionOptions,
          field
        );
        const collection2 = story._linkCollection(
          'tasks',
          [],
          collectionOptions,
          'sub_tasks'
        );

        expect(story._associatedCollections.field).toBeUndefined();
        expect(collection).toBe(story._associatedCollections.assignees);
        return expect(collection2).toBe(story._associatedCollections.sub_tasks);
      });
    });

    return context(
      'when there is already an associated collection',
      function() {
        let collection, collectionName, collectionOptions, field;
        let returnedCollection = (collection = collectionName = collectionOptions = field = null);
        beforeEach(function() {
          collectionName = 'users';
          collectionOptions = {};
          field = 'assignees';
          collection = storageManager.createNewCollection(
            collectionName,
            [],
            collectionOptions
          );
          story._associatedCollections = {};
          story._associatedCollections[field] = collection;
          spyOn(storageManager, 'createNewCollection');
          return (returnedCollection = story._linkCollection(
            collectionName,
            [],
            collectionOptions,
            field
          ));
        });

        it('returns an associated collection', () =>
          expect(collection).toBe(returnedCollection));

        return it('should not create a new collection', () =>
          expect(storageManager.createNewCollection).not.toHaveBeenCalled());
      }
    );
  });

  return describe('#destroy', function() {
    let project;
    let task = (project = null);

    beforeEach(function() {
      task = buildAndCacheTask({ id: 5, project_id: 10 });
      project = buildAndCacheProject({ id: 10, task_ids: [task.id] });
    });

    it('should delegate to Backbone.Model#destroy', function() {
      const options = { an: 'option' };
      const destroySpy = spyOn(Backbone.Model.prototype, 'destroy');

      task.destroy(options);

      return expect(destroySpy).toHaveBeenCalledWith(options);
    });

    context( 'when deleted object is referenced in a belongs-to relationship', function() {
        it('should set the associated reference to undefined', function() {
          project.destroy();

          expect(task.get('project_id')).toBeUndefined();
        });

        return it('should not remove associations to other objects', function() {
          task = buildAndCacheTask({
            id: 27,
            project_id: buildAndCacheProject({ id: 34 }).id
          });

          project.destroy();
          return expect(task.get('project_id')).toEqual('34');
        });
      }
    );

    context(
      'when the deleted object is referenced in a has-many relationship',
      () =>
        it('should remove the reference to the deleted object', function() {
          const childTaskToDelete = buildAndCacheTask({
            id: 103,
            position: 3,
            updated_at: 845785,
            parent_task_id: 7
          });
          const survivingChildTaskIds = _.pluck(
            [
              buildAndCacheTask({
                id: 77,
                position: 2,
                updated_at: 995785,
                parent_task_id: 7
              }),
              buildAndCacheTask({
                id: 99,
                position: 1,
                updated_at: 635785,
                parent_task_id: 7
              })
            ],
            'id'
          );

          task = buildAndCacheTask({ id: 7, sub_task_ids: [103, 77, 99] });

          childTaskToDelete.destroy();

          expect(task.get('sub_task_ids')).toEqual(survivingChildTaskIds);
          return expect(task.get('sub_tasks').pluck('id')).toEqual(
            survivingChildTaskIds
          );
        })
    );

    return context('using wait option', () =>
      it('should remove the associations on success of the delete and returns a promise', function() {
        const result = project.destroy({ wait: true });

        expect(task.get('project').id).toEqual(project.id);

        project.trigger('destroy');

        expect(task.get('project_id')).toBeUndefined();
        return expect(result.done).toBeDefined();
      })
    );
  });
});
