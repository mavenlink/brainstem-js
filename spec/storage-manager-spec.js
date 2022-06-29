/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * DS205: Consider reworking code to avoid use of IIFEs
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const $ = require('jquery');
const Backbone = require('backbone');
Backbone.$ = $; // TODO remove after upgrading to backbone 1.2+

const StorageManager = require('../src/storage-manager');
const AbstractLoader = require('../src/loaders/abstract-loader');
const ModelLoader = require('../src/loaders/model-loader');

const Tasks = require('./helpers/models/tasks');
const TimeEntries = require('./helpers/models/time-entries');
const Projects = require('./helpers/models/projects');

describe('Brainstem Storage Manager', function() {
  let manager = null;

  beforeEach(function() {
    manager = StorageManager.get();
    return manager.reset();
  });

  describe('storage', function() {
    beforeEach(() => manager.addCollection('time_entries', TimeEntries));

    it('accesses a cached collection of the appropriate type', function() {
      expect(
        manager.storage('time_entries') instanceof TimeEntries
      ).toBeTruthy();
      return expect(manager.storage('time_entries').length).toBe(0);
    });

    return it("raises an error if the named collection doesn't exist", () =>
      expect(() => manager.storage('foo')).toThrow());
  });

  describe('addCollection and getCollectionDetails', function() {
    it('tracks a named collection', function() {
      manager.addCollection('time_entries', TimeEntries);
      return expect(manager.getCollectionDetails('time_entries').klass).toBe(
        TimeEntries
      );
    });

    it("raises an error if the named collection doesn't exist", () =>
      expect(() => manager.getCollectionDetails('foo')).toThrow());

    it('binds to the collection for remove and calls invalidateCache on the model', function() {
      manager.addCollection('time_entries', TimeEntries);

      const timeEntry = buildTimeEntry();
      spyOn(timeEntry, 'invalidateCache');

      manager.storage('time_entries').add(timeEntry);

      expect(timeEntry.invalidateCache).not.toHaveBeenCalled();
      timeEntry.collection.remove(timeEntry);
      return expect(timeEntry.invalidateCache).toHaveBeenCalled();
    });

    return it('initializes firstFetchOptions is an empty object', function() {
      manager.addCollection('time_entries', TimeEntries);
      return expect(manager.storage('time_entries').firstFetchOptions).toEqual(
        {}
      );
    });
  });

  describe('reset', () =>
    it('should clear all storage and sort lengths', function() {
      buildAndCacheTask();
      buildAndCacheProject();

      expect(manager.storage('projects').length).toEqual(1);
      expect(manager.storage('tasks').length).toEqual(1);

      manager.collections['projects'].cache = { foo: 'bar' };
      manager.reset();

      expect(manager.collections['projects'].cache).toEqual({});
      expect(manager.storage('projects').length).toEqual(0);
      return expect(manager.storage('tasks').length).toEqual(0);
    }));

  describe('complete callback', function() {
    describe('loadModel', function() {
      it('fires when there is an error', function() {
        const completeSpy = jasmine.createSpy('completeSpy');
        respondWith(server, '/api/time_entries/1337', {
          data: { results: [] },
          status: 404
        });
        manager.loadModel('time_entry', 1337, { complete: completeSpy });

        server.respond();
        return expect(completeSpy).toHaveBeenCalled();
      });

      return it('fires on success', function() {
        const completeSpy = jasmine.createSpy('completeSpy');
        respondWith(server, '/api/time_entries/1337', {
          data: { results: [] }
        });
        manager.loadModel('time_entry', 1337, { complete: completeSpy });

        server.respond();
        return expect(completeSpy).toHaveBeenCalled();
      });
    });

    return describe('loadCollection', function() {
      it('fires when there is an error', function() {
        const completeSpy = jasmine.createSpy('completeSpy');
        respondWith(server, '/api/time_entries?per_page=20&page=1', {
          data: { results: [] },
          status: 404
        });
        manager.loadCollection('time_entries', { complete: completeSpy });

        server.respond();
        return expect(completeSpy).toHaveBeenCalled();
      });

      return it('fires on success', function() {
        const completeSpy = jasmine.createSpy('completeSpy');
        respondWith(server, '/api/time_entries?per_page=20&page=1', {
          data: { results: [] }
        });
        manager.loadCollection('time_entries', { complete: completeSpy });

        server.respond();
        return expect(completeSpy).toHaveBeenCalled();
      });
    });
  });

  describe('createNewCollection', function() {
    it('makes a new collection of the appropriate type', () =>
      expect(
        manager.createNewCollection('tasks', [
          buildTask(),
          buildTask()
        ]) instanceof Tasks
      ).toBe(true));

    return it("can accept a 'loaded' flag", function() {
      let collection = manager.createNewCollection('tasks', [
        buildTask(),
        buildTask()
      ]);
      expect(collection.loaded).toBe(false);
      collection = manager.createNewCollection(
        'tasks',
        [buildTask(), buildTask()],
        { loaded: true }
      );
      return expect(collection.loaded).toBe(true);
    });
  });

  describe('loadModel', function() {
    beforeEach(function() {
      const tasks = [buildTask({ id: 2, title: 'a task', project_id: 15 })];
      const projects = [buildProject({ id: 15 })];
      const timeEntries = [
        buildTimeEntry({
          id: 1,
          task_id: 2,
          project_id: 15,
          title: 'a time entry'
        })
      ];
      respondWith(server, '/api/time_entries/1', {
        resultsFrom: 'time_entries',
        data: { time_entries: timeEntries }
      });
      return respondWith(server, '/api/time_entries/1?include=project%2Ctask', {
        resultsFrom: 'time_entries',
        data: { time_entries: timeEntries, tasks, projects }
      });
    });

    it('creates a new model with the supplied id', function() {
      const loader = manager.loadModel('time_entry', '333');
      return expect(loader.getModel().id).toEqual('333');
    });

    it('calls Backbone.sync with the model from the loader', function() {
      spyOn(Backbone, 'sync');
      const loader = manager.loadModel('time_entry', '333');
      return expect(Backbone.sync).toHaveBeenCalledWith(
        'read',
        loader.getModel(),
        loader._buildSyncOptions()
      );
    });

    it('loads a single model from the server, including associations', function() {
      let loaded = false;
      const loader = manager.loadModel('time_entry', 1, {
        include: ['project', 'task']
      });
      loader.done(() => (loaded = true));
      const model = loader.getModel();

      expect(loaded).toBe(false);
      server.respond();
      expect(loaded).toBe(true);
      expect(model.id).toEqual('1');
      expect(model.get('title')).toEqual('a time entry');
      expect(model.get('task').get('title')).toEqual('a task');
      return expect(model.get('project').id).toEqual('15');
    });

    it('works with complex associations', function() {
      const mainProject = buildProject({ title: 'my project' });
      const mainTask = buildTask({ project_id: mainProject.id, title: 'foo' });
      const timeTask = buildTask({ title: 'hello' });
      let timeEntry = buildTimeEntry({
        project_id: mainProject.id,
        task_id: timeTask.id,
        time: 50
      });
      mainProject.set('time_entry_ids', [timeEntry.id]);

      const subTask = buildTask();
      mainTask.set('sub_task_ids', [subTask.id]);

      const mainTaskAssignee = buildUser({ name: 'Kimbo' });
      mainTask.set('assignee_ids', [mainTaskAssignee.id]);

      const subTaskAssignee = buildUser({ name: 'Slice' });
      subTask.set('assignee_ids', [subTaskAssignee.id]);

      respondWith(
        server,
        `/api/tasks/${mainTask.id}?include=assignees%2Csub_tasks%2Cproject`,
        {
          resultsFrom: 'tasks',
          data: {
            results: resultsArray('tasks', [mainTask]),
            tasks: resultsObject([mainTask, subTask]),
            projects: resultsObject([mainProject]),
            users: resultsObject([mainTaskAssignee])
          }
        }
      );
      respondWith(
        server,
        `/api/tasks?include=assignees&only=${subTask.id}&apply_default_filters=false`,
        {
          resultsFrom: 'tasks',
          data: {
            results: resultsArray('tasks', [subTask]),
            tasks: resultsObject([subTask]),
            users: resultsObject([subTaskAssignee])
          }
        }
      );
      respondWith(
        server,
        `/api/projects?include=time_entries&only=${mainProject.id}&apply_default_filters=false`,
        {
          resultsFrom: 'projects',
          data: {
            results: resultsArray('projects', [mainProject]),
            time_entries: resultsObject([timeEntry]),
            projects: resultsObject([mainProject])
          }
        }
      );
      respondWith(
        server,
        `/api/time_entries?include=task&only=${timeEntry.id}&apply_default_filters=false`,
        {
          resultsFrom: 'time_entries',
          data: {
            results: resultsArray('time_entries', [timeEntry]),
            time_entries: resultsObject([timeEntry]),
            tasks: resultsObject([timeTask])
          }
        }
      );

      const loader = manager.loadModel('task', mainTask.id, {
        include: [
          'assignees',
          { sub_tasks: ['assignees'] },
          { project: [{ time_entries: ['task'] }] }
        ]
      });

      const model = loader.getModel();

      while (server.queue.length !== 0) {
        server.respond();
      }

      // check main model
      expect(model.attributes).toEqual(mainTask.attributes);

      // check assignees
      expect(model.get('assignees').length).toEqual(1);
      expect(
        model
          .get('assignees')
          .first()
          .get('name')
      ).toEqual('Kimbo');

      // check sub_tasks
      const subTasks = model.get('sub_tasks');
      expect(subTasks.length).toEqual(1);

      // check sub_tasks -> assignees
      const assignees = subTasks.at(0).get('assignees');
      expect(assignees.length).toEqual(1);
      expect(assignees.at(0).get('name')).toEqual('Slice');

      // check project
      const project = model.get('project');
      expect(project.get('title')).toEqual('my project');

      // check project -> time_entries
      const timeEntries = project.get('time_entries');
      expect(timeEntries.length).toEqual(1);

      timeEntry = timeEntries.at(0);
      expect(timeEntry.get('time')).toEqual(50);

      // check project -> time_entries -> task
      return expect(timeEntry.get('task').get('title')).toEqual('hello');
    });

    it('uses the cache if it can', function() {
      const task = buildAndCacheTask({ id: 200 });
      const spy = spyOn(AbstractLoader.prototype, '_loadFromServer');

      const loader = manager.loadModel('task', task.id);
      const model = loader.getModel();
      expect(model.attributes).toEqual(task.attributes);
      return expect(spy).not.toHaveBeenCalled();
    });

    it('works even when the server returned associations of the same type', function() {
      const posts = [
        buildPost({ id: 2, reply: true }),
        buildPost({ id: 3, reply: true }),
        buildPost({ id: 1, reply: false, reply_ids: [2, 3] })
      ];
      respondWith(server, '/api/posts/1?include=replies', {
        data: { results: [{ key: 'posts', id: 1 }], posts }
      });
      let loaded = false;
      const loader = manager.loadModel('post', 1, { include: ['replies'] });
      loader.done(() => (loaded = true));
      const model = loader.getModel();
      expect(loaded).toBe(false);
      server.respond();
      expect(loaded).toBe(true);
      expect(model.id).toEqual('1');
      return expect(model.get('replies').pluck('id')).toEqual(['2', '3']);
    });

    it('updates associations before the primary model', function() {
      const events = [];
      manager
        .storage('time_entries')
        .on('add', () => events.push('time_entries'));
      manager.storage('tasks').on('add', () => events.push('tasks'));
      manager.loadModel('time_entry', 1, { include: ['project', 'task'] });
      server.respond();
      return expect(events).toEqual(['tasks', 'time_entries']);
    });

    it('triggers changes', function() {
      let loaded = false;
      const loader = manager.loadModel('time_entry', 1, {
        include: ['project', 'task']
      });
      loader.done(() => (loaded = true));
      const model = loader.getModel();
      const spy = jasmine.createSpy().and.callFake(function() {
        expect(model.get('title')).toEqual('a time entry');
        expect(model.get('task').get('title')).toEqual('a task');
        return expect(model.get('project').id).toEqual('15');
      });
      model.bind('change', spy);
      expect(spy).not.toHaveBeenCalled();
      expect(loaded).toBe(false);
      server.respond();
      expect(spy).toHaveBeenCalled();
      expect(spy.calls.count()).toEqual(1);
      return expect(loaded).toBe(true);
    });

    it('accepts a success function', function() {
      const spy = jasmine.createSpy();
      manager.loadModel('time_entry', 1, { success: spy });
      server.respond();
      return expect(spy).toHaveBeenCalled();
    });

    it('can disable caching', function() {
      const spy = spyOn(
        ModelLoader.prototype,
        '_checkCacheForData'
      ).and.callThrough();
      manager.loadModel('time_entry', 1, { cache: false });
      return expect(spy).not.toHaveBeenCalled();
    });

    it('invokes the error callback when the server responds with a 404', function() {
      const successSpy = jasmine.createSpy('successSpy');
      const errorSpy = jasmine.createSpy('errorSpy');
      respondWith(server, '/api/time_entries/1337', {
        data: { results: [] },
        status: 404
      });
      manager.loadModel('time_entry', 1337, {
        success: successSpy,
        error: errorSpy
      });

      server.respond();
      expect(successSpy).not.toHaveBeenCalled();
      return expect(errorSpy).toHaveBeenCalled();
    });

    return it('does not resolve until all of the associations are included', function() {
      manager.enableExpectations();

      const project = buildProject();
      const user = buildUser();

      const task = buildTask({ title: 'foobar', project_id: project.id });
      const task2 = buildTask({ project_id: project.id });
      const task3 = buildTask({
        project_id: project.id,
        assignee_ids: [user.id]
      });

      project.set('task_ids', [task.id, task2.id, task3.id]);

      const taskExpectation = manager.stubModel('task', task.id, {
        include: [{ project: [{ tasks: ['assignees'] }] }],
        response(stub) {
          stub.result = task;
          stub.associated.project = [project];
          return (stub.recursive = true);
        }
      });

      const projectExpectation = manager.stub('projects', {
        only: project.id,
        include: [{ tasks: ['assignees'] }],
        params: { apply_default_filters: false },
        response(stub) {
          stub.results = [project];
          stub.associated.tasks = [task, task2, task3];
          return (stub.recursive = true);
        }
      });

      const taskWithAssigneesExpectation = manager.stub('tasks', {
        only: [task.id, task2.id, task3.id],
        include: ['assignees'],
        params: { apply_default_filters: false },
        response(stub) {
          stub.results = [task];
          return (stub.associated.users = [user]);
        }
      });

      const resolvedSpy = jasmine.createSpy('resolved');

      const model = buildAndCacheTask({ id: task.id });
      const loader = manager.loadModel('task', model.id, {
        include: [{ project: [{ tasks: ['assignees'] }] }]
      });
      loader.done(resolvedSpy);

      taskExpectation.respond();
      expect(resolvedSpy).not.toHaveBeenCalled();

      projectExpectation.respond();
      expect(resolvedSpy).not.toHaveBeenCalled();

      taskWithAssigneesExpectation.respond();
      expect(resolvedSpy).toHaveBeenCalled();

      return manager.disableExpectations();
    });
  });

  describe('loadCollection', function() {
    it('loads a collection of models', function() {
      const timeEntries = [buildTimeEntry(), buildTimeEntry()];
      respondWith(server, '/api/time_entries?per_page=20&page=1', {
        resultsFrom: 'time_entries',
        data: { time_entries: timeEntries }
      });
      const collection = manager.loadCollection('time_entries');
      expect(collection.length).toBe(0);
      server.respond();
      return expect(collection.length).toBe(2);
    });

    it('accepts a success function', function() {
      const timeEntries = [buildTimeEntry(), buildTimeEntry()];
      respondWith(server, '/api/time_entries?per_page=20&page=1', {
        resultsFrom: 'time_entries',
        data: { time_entries: timeEntries }
      });
      const spy = jasmine
        .createSpy()
        .and.callFake(collection => expect(collection.loaded).toBe(true));
      const collection = manager.loadCollection('time_entries', {
        success: spy
      });
      server.respond();
      return expect(spy).toHaveBeenCalledWith(collection);
    });

    it("saves it's options onto the returned collection", function() {
      const collection = manager.loadCollection('time_entries', {
        order: 'baz:desc',
        filters: { bar: 2 }
      });
      expect(collection.lastFetchOptions.order).toEqual('baz:desc');
      expect(collection.lastFetchOptions.filters).toEqual({ bar: 2 });
      return expect(collection.lastFetchOptions.collection).toBeFalsy();
    });

    describe('passing an optional collection', function() {
      it('accepts an optional collection instead of making a new one', function() {
        const timeEntry = buildTimeEntry();
        respondWith(server, '/api/time_entries?per_page=20&page=1', {
          data: {
            results: [{ key: 'time_entries', id: timeEntry.id }],
            time_entries: [timeEntry]
          }
        });
        const collection = new TimeEntries([
          buildTimeEntry(),
          buildTimeEntry()
        ]);
        collection.setLoaded(true);
        manager.loadCollection('time_entries', { collection });
        expect(collection.lastFetchOptions.collection).toBeFalsy();
        expect(collection.loaded).toBe(false);
        expect(collection.length).toEqual(2);
        server.respond();
        expect(collection.loaded).toBe(true);
        return expect(collection.length).toEqual(3);
      });

      return it('can take an optional reset command to reset the collection before using it', function() {
        const timeEntry = buildTimeEntry();
        respondWith(server, '/api/time_entries?per_page=20&page=1', {
          data: {
            results: [{ key: 'time_entries', id: timeEntry.id }],
            time_entries: [timeEntry]
          }
        });
        const collection = new TimeEntries([
          buildTimeEntry(),
          buildTimeEntry()
        ]);
        collection.setLoaded(true);
        spyOn(collection, 'reset').and.callThrough();
        manager.loadCollection('time_entries', { collection, reset: true });
        expect(collection.reset).toHaveBeenCalled();
        expect(collection.lastFetchOptions.collection).toBeFalsy();
        expect(collection.loaded).toBe(false);
        expect(collection.length).toEqual(0);
        server.respond();
        expect(collection.loaded).toBe(true);
        return expect(collection.length).toEqual(1);
      });
    });

    it('accepts filters', function() {
      const posts = [
        buildPost({ project_id: 15, id: 1 }),
        buildPost({ project_id: 15, id: 2 })
      ];
      respondWith(
        server,
        '/api/posts?filter1=true&filter2=false&filter3=true&filter4=false&filter5=2&filter6=baz&per_page=20&page=1',
        { data: { results: [{ key: 'posts', id: 1 }], posts } }
      );
      const collection = manager.loadCollection('posts', {
        filters: {
          filter1: true,
          filter2: false,
          filter3: 'true',
          filter4: 'false',
          filter5: 2,
          filter6: 'baz'
        }
      });
      return server.respond();
    });

    it('triggers reset', function() {
      const timeEntry = buildTimeEntry();
      respondWith(server, '/api/time_entries?per_page=20&page=1', {
        data: {
          results: [{ key: 'time_entries', id: timeEntry.id }],
          time_entries: [timeEntry]
        }
      });
      const collection = manager.loadCollection('time_entries');
      expect(collection.loaded).toBe(false);
      const spy = jasmine
        .createSpy()
        .and.callFake(() => expect(collection.loaded).toBe(true));
      collection.bind('reset', spy);
      server.respond();
      return expect(spy).toHaveBeenCalled();
    });

    it('ignores count and honors results', function() {
      server.respondWith('GET', '/api/time_entries?per_page=20&page=1', [
        200,
        { 'Content-Type': 'application/json' },
        JSON.stringify({
          count: 2,
          results: [{ key: 'time_entries', id: 2 }],
          time_entries: [buildTimeEntry(), buildTimeEntry()]
        })
      ]);
      const collection = manager.loadCollection('time_entries');
      server.respond();
      return expect(collection.length).toEqual(1);
    });

    it('works with an empty response', function() {
      const exceptionSpy = spyOn(sinon, 'logError').and.callThrough();
      respondWith(server, '/api/time_entries?per_page=20&page=1', {
        resultsFrom: 'time_entries',
        data: { time_entries: [] }
      });
      manager.loadCollection('time_entries');
      server.respond();
      return expect(exceptionSpy).not.toHaveBeenCalled();
    });

    describe('fetching of associations', function() {
      const json = null;

      beforeEach(function() {
        const tasks = [buildTask({ id: 2, title: 'a task' })];
        const projects = [buildProject({ id: 15 }), buildProject({ id: 10 })];
        const timeEntries = [
          buildTimeEntry({ task_id: 2, project_id: 15, id: 1 }),
          buildTimeEntry({ task_id: null, project_id: 10, id: 2 })
        ];

        respondWith(
          server,
          /\/api\/time_entries\?include=project%2Ctask&per_page=\d+&page=\d+/,
          {
            resultsFrom: 'time_entries',
            data: { time_entries: timeEntries, tasks, projects }
          }
        );
        return respondWith(
          server,
          /\/api\/time_entries\?include=project&per_page=\d+&page=\d+/,
          {
            resultsFrom: 'time_entries',
            data: { time_entries: timeEntries, projects }
          }
        );
      });

      it('loads collections that should be included', function() {
        const collection = manager.loadCollection('time_entries', {
          include: ['project', 'task']
        });
        const spy = jasmine.createSpy().and.callFake(function() {
          expect(collection.loaded).toBe(true);
          expect(
            collection
              .get(1)
              .get('task')
              .get('title')
          ).toEqual('a task');
          expect(collection.get(2).get('task')).toBeFalsy();
          expect(collection.get(1).get('project').id).toEqual('15');
          return expect(collection.get(2).get('project').id).toEqual('10');
        });
        collection.bind('reset', spy);
        expect(collection.loaded).toBe(false);
        server.respond();
        expect(collection.loaded).toBe(true);
        return expect(spy).toHaveBeenCalled();
      });

      it('applies uses the results array from the server (so that associations of the same type as the primary can be handled- posts with replies; tasks with subtasks, etc.)', function() {
        const posts = [
          buildPost({ project_id: 15, id: 1, reply_ids: [2] }),
          buildPost({ project_id: 15, id: 2, subject_id: 1, reply: true })
        ];
        respondWith(
          server,
          '/api/posts?include=replies&parents_only=true&per_page=20&page=1',
          { data: { results: [{ key: 'posts', id: 1 }], posts } }
        );
        const collection = manager.loadCollection('posts', {
          include: ['replies'],
          filters: { parents_only: 'true' }
        });
        server.respond();
        expect(collection.pluck('id')).toEqual(['1']);
        return expect(
          collection
            .get(1)
            .get('replies')
            .pluck('id')
        ).toEqual(['2']);
      });

      describe('fetching multiple levels of associations', function() {
        let checkStructure, success;
        let callCount = (success = checkStructure = null);

        context('deeply nested associations', function() {
          beforeEach(function() {
            const projectOneTimeEntryTask = buildTask();
            const projectOneTimeEntry = buildTimeEntry({
              title: 'without task'
            });
            const projectOneTimeEntryWithTask = buildTimeEntry({
              id: projectOneTimeEntry.id,
              task_id: projectOneTimeEntryTask.id,
              title: 'with task'
            });
            const projectOne = buildProject();
            const projectOneWithTimeEntries = buildProject({
              id: projectOne.id,
              time_entry_ids: [projectOneTimeEntry.id]
            });
            const projectTwo = buildProject();
            const projectTwoWithTimeEntries = buildProject({
              id: projectTwo.id,
              time_entry_ids: []
            });
            const taskOneAssignee = buildUser();
            const taskTwoAssignee = buildUser();
            const taskOneSubAssignee = buildUser();
            const taskOneSub = buildTask({
              project_id: projectOne.id,
              parent_id: 10
            });
            const taskOneSubWithAssignees = buildTask({
              id: taskOneSub.id,
              assignee_ids: [taskOneSubAssignee.id],
              parent_id: 10
            });
            const taskTwoSub = buildTask({
              project_id: projectTwo.id,
              parent_id: 11
            });
            const taskTwoSubWithAssignees = buildTask({
              id: taskTwoSub.id,
              assignee_ids: [taskTwoAssignee.id],
              parent_id: 11
            });
            const taskOne = buildTask({
              id: 10,
              project_id: projectOne.id,
              assignee_ids: [taskOneAssignee.id],
              sub_task_ids: [taskOneSub.id]
            });
            const taskTwo = buildTask({
              id: 11,
              project_id: projectTwo.id,
              assignee_ids: [taskTwoAssignee.id],
              sub_task_ids: [taskTwoSub.id]
            });
            respondWith(
              server,
              '/api/tasks?include=assignees%2Cproject%2Csub_tasks&parents_only=true&per_page=20&page=1',
              {
                data: {
                  results: resultsArray('tasks', [taskOne, taskTwo]),
                  tasks: resultsObject([
                    taskOne,
                    taskTwo,
                    taskOneSub,
                    taskTwoSub
                  ]),
                  users: resultsObject([taskOneAssignee, taskTwoAssignee]),
                  projects: resultsObject([projectOne, projectTwo])
                }
              }
            );
            respondWith(
              server,
              `/api/tasks?include=assignees&only=${taskOneSub.id}%2C${taskTwoSub.id}&apply_default_filters=false`,
              {
                data: {
                  results: resultsArray('tasks', [taskOneSub, taskTwoSub]),
                  tasks: resultsObject([
                    taskOneSubWithAssignees,
                    taskTwoSubWithAssignees
                  ]),
                  users: resultsObject([taskOneSubAssignee, taskTwoAssignee])
                }
              }
            );
            respondWith(
              server,
              `/api/projects?include=time_entries&only=${projectOne.id}%2C${projectTwo.id}&apply_default_filters=false`,
              {
                data: {
                  results: resultsArray('projects', [projectOne, projectTwo]),
                  projects: resultsObject([
                    projectOneWithTimeEntries,
                    projectTwoWithTimeEntries
                  ]),
                  time_entries: resultsObject([projectOneTimeEntry])
                }
              }
            );
            respondWith(
              server,
              `/api/time_entries?include=task&only=${projectOneTimeEntry.id}&apply_default_filters=false`,
              {
                data: {
                  results: resultsArray('time_entries', [projectOneTimeEntry]),
                  time_entries: resultsObject([projectOneTimeEntryWithTask]),
                  tasks: resultsObject([projectOneTimeEntryTask])
                }
              }
            );

            callCount = 0;
            checkStructure = function(collection) {
              expect(collection.pluck('id').sort()).toEqual([
                taskOne.id,
                taskTwo.id
              ]);
              expect(collection.get(taskOne.id).get('project').id).toEqual(
                projectOne.id
              );
              expect(
                collection
                  .get(taskOne.id)
                  .get('assignees')
                  .pluck('id')
              ).toEqual([taskOneAssignee.id]);
              expect(
                collection
                  .get(taskTwo.id)
                  .get('assignees')
                  .pluck('id')
              ).toEqual([taskTwoAssignee.id]);
              expect(
                collection
                  .get(taskOne.id)
                  .get('sub_tasks')
                  .pluck('id')
              ).toEqual([taskOneSub.id]);
              expect(
                collection
                  .get(taskTwo.id)
                  .get('sub_tasks')
                  .pluck('id')
              ).toEqual([taskTwoSub.id]);
              expect(
                collection
                  .get(taskOne.id)
                  .get('sub_tasks')
                  .get(taskOneSub.id)
                  .get('assignees')
                  .pluck('id')
              ).toEqual([taskOneSubAssignee.id]);
              expect(
                collection
                  .get(taskTwo.id)
                  .get('sub_tasks')
                  .get(taskTwoSub.id)
                  .get('assignees')
                  .pluck('id')
              ).toEqual([taskTwoAssignee.id]);
              expect(
                collection
                  .get(taskOne.id)
                  .get('project')
                  .get('time_entries')
                  .pluck('id')
              ).toEqual([projectOneTimeEntry.id]);
              expect(
                collection
                  .get(taskOne.id)
                  .get('project')
                  .get('time_entries')
                  .models[0].get('task').id
              ).toEqual(projectOneTimeEntryTask.id);
              return (callCount += 1);
            };

            return (success = jasmine.createSpy().and.callFake(checkStructure));
          });

          context('with json structure', () =>
            it('separately requests each layer of associations', function() {
              const collection = manager.loadCollection('tasks', {
                filters: { parents_only: 'true' },
                success,
                include: [
                  'assignees',
                  { project: [{ time_entries: 'task' }] },
                  { sub_tasks: ['assignees'] }
                ]
              });

              collection.bind('loaded', checkStructure);
              collection.bind('reset', checkStructure);

              expect(success).not.toHaveBeenCalled();

              while (server.queue.length !== 0) {
                server.respond();
              }

              expect(success).toHaveBeenCalledWith(collection);
              return expect(callCount).toEqual(3);
            })
          );

          context('using a backbone collection', () =>
            it('separately requests each layer of associations', function() {
              let projectCollection;
              return (projectCollection = new Projects(null, {
                include: [{ time_entries: 'task' }],
                test: 10
              }));
            })
          );

          return context('using brainstemParams', () =>
            it('separately requests each layer of associations', function() {
              const projectParams = {
                brainstemParams: true,
                include: [{ time_entries: 'task' }],
                test: 10
              };

              const collection = manager.loadCollection('tasks', {
                filters: { parents_only: 'true' },
                success,
                include: [
                  'assignees',
                  { project: projectParams },
                  { sub_tasks: ['assignees'] }
                ]
              });

              collection.bind('loaded', checkStructure);
              collection.bind('reset', checkStructure);

              expect(success).not.toHaveBeenCalled();

              while (server.queue.length !== 0) {
                server.respond();
              }
              expect(success).toHaveBeenCalled();
              return expect(callCount).toEqual(3);
            })
          );
        });

        return context('a shallowly nested json structure', function() {
          let projectTwo;
          let projectOne = (projectTwo = null);

          beforeEach(function() {
            const projectOneTimeEntryTask = buildTask();
            const projectOneTimeEntry = buildTimeEntry({
              title: 'without task'
            });
            const projectOneTimeEntryWithTask = buildTimeEntry({
              id: projectOneTimeEntry.id,
              task_id: projectOneTimeEntryTask.id,
              title: 'with task'
            });
            projectOne = buildProject();
            const projectOneWithTimeEntries = buildProject({
              id: projectOne.id,
              time_entry_ids: [projectOneTimeEntry.id]
            });
            projectTwo = buildProject();
            const projectTwoWithTimeEntries = buildProject({
              id: projectTwo.id,
              time_entry_ids: []
            });
            const taskOneAssignee = buildUser();
            const taskTwoAssignee = buildUser();
            const taskOneSubAssignee = buildUser();
            const taskOneSub = buildTask({
              project_id: projectOne.id,
              parent_id: 10
            });
            const taskOneSubWithAssignees = buildTask({
              id: taskOneSub.id,
              assignee_ids: [taskOneSubAssignee.id],
              parent_id: 10
            });
            const taskTwoSub = buildTask({
              project_id: projectTwo.id,
              parent_id: 11
            });
            const taskTwoSubWithAssignees = buildTask({
              id: taskTwoSub.id,
              assignee_ids: [taskTwoAssignee.id],
              parent_id: 11
            });
            const taskOne = buildTask({
              id: 10,
              project_id: projectOne.id,
              assignee_ids: [taskOneAssignee.id],
              sub_task_ids: [taskOneSub.id]
            });
            const taskTwo = buildTask({
              id: 11,
              project_id: projectTwo.id,
              assignee_ids: [taskTwoAssignee.id],
              sub_task_ids: [taskTwoSub.id]
            });
            respondWith(
              server,
              '/api/tasks?include=assignees%2Cproject%2Csub_tasks&parents_only=true&per_page=20&page=1',
              {
                data: {
                  results: resultsArray('tasks', [taskOne, taskTwo]),
                  tasks: resultsObject([
                    taskOne,
                    taskTwo,
                    taskOneSub,
                    taskTwoSub
                  ]),
                  users: resultsObject([taskOneAssignee, taskTwoAssignee]),
                  projects: resultsObject([projectOne, projectTwo])
                }
              }
            );
            respondWith(
              server,
              `/api/tasks?include=assignees&only=${taskOneSub.id}%2C${taskTwoSub.id}&apply_default_filters=false`,
              {
                data: {
                  results: resultsArray('tasks', [taskOneSub, taskTwoSub]),
                  tasks: resultsObject([
                    taskOneSubWithAssignees,
                    taskTwoSubWithAssignees
                  ]),
                  users: resultsObject([taskOneSubAssignee, taskTwoAssignee])
                }
              }
            );
            respondWith(
              server,
              `/api/projects?only=${projectOne.id}%2C${projectTwo.id}&apply_default_filters=false&test=10`,
              {
                data: {
                  results: resultsArray('projects', [projectOne, projectTwo]),
                  projects: resultsObject([
                    projectOneWithTimeEntries,
                    projectTwoWithTimeEntries
                  ])
                }
              }
            );

            callCount = 0;
            checkStructure = function(collection) {
              expect(collection.pluck('id').sort()).toEqual([
                taskOne.id,
                taskTwo.id
              ]);
              expect(collection.get(taskOne.id).get('project').id).toEqual(
                projectOne.id
              );
              expect(
                collection
                  .get(taskOne.id)
                  .get('assignees')
                  .pluck('id')
              ).toEqual([taskOneAssignee.id]);
              expect(
                collection
                  .get(taskTwo.id)
                  .get('assignees')
                  .pluck('id')
              ).toEqual([taskTwoAssignee.id]);
              expect(
                collection
                  .get(taskOne.id)
                  .get('sub_tasks')
                  .pluck('id')
              ).toEqual([taskOneSub.id]);
              expect(
                collection
                  .get(taskTwo.id)
                  .get('sub_tasks')
                  .pluck('id')
              ).toEqual([taskTwoSub.id]);
              expect(
                collection
                  .get(taskOne.id)
                  .get('sub_tasks')
                  .get(taskOneSub.id)
                  .get('assignees')
                  .pluck('id')
              ).toEqual([taskOneSubAssignee.id]);
              expect(
                collection
                  .get(taskTwo.id)
                  .get('sub_tasks')
                  .get(taskTwoSub.id)
                  .get('assignees')
                  .pluck('id')
              ).toEqual([taskTwoAssignee.id]);

              return (callCount += 1);
            };

            return (success = jasmine.createSpy().and.callFake(checkStructure));
          });

          return it('separately requests each layer of associations with filters', function() {
            const projectCollection = new Projects(null, {
              filters: {
                test: 10
              }
            });

            spyOn(
              projectCollection.storageManager,
              'loadObject'
            ).and.callThrough();

            const collection = manager.loadCollection('tasks', {
              filters: { parents_only: 'true' },
              success,
              include: [
                'assignees',
                { project: projectCollection },
                { sub_tasks: ['assignees'] }
              ]
            });

            collection.bind('loaded', checkStructure);
            collection.bind('reset', checkStructure);

            expect(success).not.toHaveBeenCalled();

            while (server.queue.length !== 0) {
              server.respond();
            }
            expect(success).toHaveBeenCalled();
            expect(callCount).toEqual(3);

            const expectedFilters = projectCollection.storageManager.loadObject.calls.all()[1]
              .args[1].filters;

            expect(
              projectCollection.storageManager.loadObject
            ).toHaveBeenCalled();
            expect(expectedFilters).toEqual({ test: 10 });

            expect(projectCollection.first().id).toEqual(projectOne.id);
            return expect(projectCollection.last().id).toEqual(projectTwo.id);
          });
        });
      });

      return describe('caching', function() {
        describe('without ordering', function() {
          it("doesn't go to the server when it already has the data", function() {
            const collection1 = manager.loadCollection('time_entries', {
              include: ['project', 'task'],
              page: 1,
              perPage: 2
            });
            server.respond();
            expect(collection1.loaded).toBe(true);
            expect(collection1.get(1).get('project').id).toEqual('15');
            expect(collection1.get(2).get('project').id).toEqual('10');
            const spy = jasmine.createSpy();
            const collection2 = manager.loadCollection('time_entries', {
              include: ['project', 'task'],
              page: 1,
              perPage: 2,
              success: spy
            });
            expect(spy).toHaveBeenCalled();
            expect(collection2.loaded).toBe(true);
            expect(
              collection2
                .get(1)
                .get('task')
                .get('title')
            ).toEqual('a task');
            expect(collection2.get(2).get('task')).toBeFalsy();
            expect(collection2.get(1).get('project').id).toEqual('15');
            return expect(collection2.get(2).get('project').id).toEqual('10');
          });

          context('using perPage and page', () =>
            it('does go to the server when more records are requested than it has previously requested, and remembers previously requested pages', function() {
              const collection1 = manager.loadCollection('time_entries', {
                include: ['project', 'task'],
                page: 1,
                perPage: 2
              });
              server.respond();
              expect(collection1.loaded).toBe(true);
              const collection2 = manager.loadCollection('time_entries', {
                include: ['project', 'task'],
                page: 2,
                perPage: 2
              });
              expect(collection2.loaded).toBe(false);
              server.respond();
              expect(collection2.loaded).toBe(true);
              const collection3 = manager.loadCollection('time_entries', {
                include: ['project'],
                page: 1,
                perPage: 2
              });
              return expect(collection3.loaded).toBe(true);
            })
          );

          context('using limit and offset', () =>
            it('does go to the server when more records are requested than it knows about', function() {
              const timeEntries = [buildTimeEntry(), buildTimeEntry()];
              respondWith(server, '/api/time_entries?limit=2&offset=0', {
                resultsFrom: 'time_entries',
                data: { time_entries: timeEntries }
              });
              respondWith(server, '/api/time_entries?limit=2&offset=2', {
                resultsFrom: 'time_entries',
                data: { time_entries: timeEntries }
              });

              const collection1 = manager.loadCollection('time_entries', {
                limit: 2,
                offset: 0
              });
              server.respond();
              expect(collection1.loaded).toBe(true);
              const collection2 = manager.loadCollection('time_entries', {
                limit: 2,
                offset: 2
              });
              expect(collection2.loaded).toBe(false);
              server.respond();
              expect(collection2.loaded).toBe(true);
              const collection3 = manager.loadCollection('time_entries', {
                limit: 2,
                offset: 0
              });
              return expect(collection3.loaded).toBe(true);
            })
          );

          return it('does go to the server when some associations are missing, when otherwise it would have the data', function() {
            const collection1 = manager.loadCollection('time_entries', {
              include: ['project'],
              page: 1,
              perPage: 2
            });
            server.respond();
            expect(collection1.loaded).toBe(true);
            const collection2 = manager.loadCollection('time_entries', {
              include: ['project', 'task'],
              page: 1,
              perPage: 2
            });
            return expect(collection2.loaded).toBe(false);
          });
        });

        return describe('with ordering and filtering', function() {
          let te1Ws10, te1Ws11, te2Ws10, te2Ws11, ws10, ws11;
          let now = (ws10 = ws11 = te1Ws10 = te2Ws10 = te1Ws11 = te2Ws11 = null);

          beforeEach(function() {
            now = new Date().getTime();
            ws10 = buildProject({ id: 10 });
            ws11 = buildProject({ id: 11 });
            te1Ws10 = buildTimeEntry({
              task_id: null,
              project_id: 10,
              id: 1,
              created_at: now - 20 * 1000,
              updated_at: now - 10 * 1000
            });
            te2Ws10 = buildTimeEntry({
              task_id: null,
              project_id: 10,
              id: 2,
              created_at: now - 10 * 1000,
              updated_at: now - 5 * 1000
            });
            te1Ws11 = buildTimeEntry({
              task_id: null,
              project_id: 11,
              id: 3,
              created_at: now - 100 * 1000,
              updated_at: now - 4 * 1000
            });
            return (te2Ws11 = buildTimeEntry({
              task_id: null,
              project_id: 11,
              id: 4,
              created_at: now - 200 * 1000,
              updated_at: now - 12 * 1000
            }));
          });

          it('goes to the server for pages of data and updates the collection', function() {
            respondWith(
              server,
              '/api/time_entries?order=created_at%3Aasc&per_page=2&page=1',
              {
                data: {
                  results: resultsArray('time_entries', [te2Ws11, te1Ws11]),
                  time_entries: [te2Ws11, te1Ws11]
                }
              }
            );
            respondWith(
              server,
              '/api/time_entries?order=created_at%3Aasc&per_page=2&page=2',
              {
                data: {
                  results: resultsArray('time_entries', [te1Ws10, te2Ws10]),
                  time_entries: [te1Ws10, te2Ws10]
                }
              }
            );
            const collection = manager.loadCollection('time_entries', {
              order: 'created_at:asc',
              page: 1,
              perPage: 2
            });
            server.respond();
            expect(collection.pluck('id')).toEqual([te2Ws11.id, te1Ws11.id]);
            manager.loadCollection('time_entries', {
              collection,
              order: 'created_at:asc',
              page: 2,
              perPage: 2
            });
            server.respond();
            return expect(collection.pluck('id')).toEqual([
              te2Ws11.id,
              te1Ws11.id,
              te1Ws10.id,
              te2Ws10.id
            ]);
          });

          it('does not re-sort the results', function() {
            respondWith(
              server,
              '/api/time_entries?order=created_at%3Adesc&per_page=2&page=1',
              {
                data: {
                  results: resultsArray('time_entries', [te2Ws11, te1Ws11]),
                  time_entries: [te1Ws11, te2Ws11]
                }
              }
            );
            // it's really created_at:asc
            const collection = manager.loadCollection('time_entries', {
              order: 'created_at:desc',
              page: 1,
              perPage: 2
            });
            server.respond();
            return expect(collection.pluck('id')).toEqual([
              te2Ws11.id,
              te1Ws11.id
            ]);
          });

          return it('seperately caches data requested by different sort orders and filters', function() {
            server.responses = [];
            respondWith(
              server,
              '/api/time_entries?include=project%2Ctask&order=updated_at%3Adesc&project_id=10&per_page=2&page=1',
              {
                data: {
                  results: resultsArray('time_entries', [te2Ws10, te1Ws10]),
                  time_entries: [te2Ws10, te1Ws10],
                  tasks: [],
                  projects: [ws10]
                }
              }
            );
            respondWith(
              server,
              '/api/time_entries?include=project%2Ctask&order=updated_at%3Adesc&project_id=11&per_page=2&page=1',
              {
                data: {
                  results: resultsArray('time_entries', [te1Ws11, te2Ws11]),
                  time_entries: [te1Ws11, te2Ws11],
                  tasks: [],
                  projects: [ws11]
                }
              }
            );
            respondWith(
              server,
              '/api/time_entries?include=project%2Ctask&order=created_at%3Aasc&project_id=11&per_page=2&page=1',
              {
                data: {
                  results: resultsArray('time_entries', [te2Ws11, te1Ws11]),
                  time_entries: [te2Ws11, te1Ws11],
                  tasks: [],
                  projects: [ws11]
                }
              }
            );
            respondWith(
              server,
              '/api/time_entries?include=project%2Ctask&order=created_at%3Aasc&per_page=4&page=1',
              {
                data: {
                  results: resultsArray('time_entries', [
                    te2Ws11,
                    te1Ws11,
                    te1Ws10,
                    te2Ws10
                  ]),
                  time_entries: [te2Ws11, te1Ws11, te1Ws10, te2Ws10],
                  tasks: [],
                  projects: [ws10, ws11]
                }
              }
            );
            respondWith(
              server,
              '/api/time_entries?include=project%2Ctask&per_page=4&page=1',
              {
                data: {
                  results: resultsArray('time_entries', [
                    te1Ws11,
                    te2Ws10,
                    te1Ws10,
                    te2Ws11
                  ]),
                  time_entries: [te1Ws11, te2Ws10, te1Ws10, te2Ws11],
                  tasks: [],
                  projects: [ws10, ws11]
                }
              }
            );
            // Make a server request
            const collection1 = manager.loadCollection('time_entries', {
              include: ['project', 'task'],
              order: 'updated_at:desc',
              filters: { project_id: 10 },
              page: 1,
              perPage: 2
            });
            expect(collection1.loaded).toBe(false);
            server.respond();
            expect(collection1.loaded).toBe(true);
            expect(collection1.pluck('id')).toEqual([te2Ws10.id, te1Ws10.id]); // Show that it came back in the explicit order setup above
            // Make another request, this time handled by the cache.
            const collection2 = manager.loadCollection('time_entries', {
              include: ['project', 'task'],
              order: 'updated_at:desc',
              filters: { project_id: 10 },
              page: 1,
              perPage: 2
            });
            expect(collection2.loaded).toBe(true);

            // Do it again, this time with a different filter.
            const collection3 = manager.loadCollection('time_entries', {
              include: ['project', 'task'],
              order: 'updated_at:desc',
              filters: { project_id: 11 },
              page: 1,
              perPage: 2
            });
            expect(collection3.loaded).toBe(false);
            server.respond();
            expect(collection3.loaded).toBe(true);
            expect(collection3.pluck('id')).toEqual([te1Ws11.id, te2Ws11.id]);
            const collection4 = manager.loadCollection('time_entries', {
              include: ['project'],
              order: 'updated_at:desc',
              filters: { project_id: 11 },
              page: 1,
              perPage: 2
            });
            expect(collection4.loaded).toBe(true);
            expect(collection4.pluck('id')).toEqual([te1Ws11.id, te2Ws11.id]);

            // Do it again, this time with a different order.
            const collection5 = manager.loadCollection('time_entries', {
              include: ['project', 'task'],
              order: 'created_at:asc',
              filters: { project_id: 11 },
              page: 1,
              perPage: 2
            });
            expect(collection5.loaded).toBe(false);
            server.respond();
            expect(collection5.loaded).toBe(true);
            expect(collection5.pluck('id')).toEqual([te2Ws11.id, te1Ws11.id]);
            const collection6 = manager.loadCollection('time_entries', {
              include: ['task'],
              order: 'created_at:asc',
              filters: { project_id: 11 },
              page: 1,
              perPage: 2
            });
            expect(collection6.loaded).toBe(true);
            expect(collection6.pluck('id')).toEqual([te2Ws11.id, te1Ws11.id]);

            // Do it again, this time without a filter.
            const collection7 = manager.loadCollection('time_entries', {
              include: ['project', 'task'],
              order: 'created_at:asc',
              page: 1,
              perPage: 4
            });
            expect(collection7.loaded).toBe(false);
            server.respond();
            expect(collection7.loaded).toBe(true);
            expect(collection7.pluck('id')).toEqual([
              te2Ws11.id,
              te1Ws11.id,
              te1Ws10.id,
              te2Ws10.id
            ]);

            // Do it again, this time without an order, so it should use the default (updated_at:desc).
            const collection9 = manager.loadCollection('time_entries', {
              include: ['project', 'task'],
              page: 1,
              perPage: 4
            });
            expect(collection9.loaded).toBe(false);
            server.respond();
            expect(collection9.loaded).toBe(true);
            return expect(collection9.pluck('id')).toEqual([
              te1Ws11.id,
              te2Ws10.id,
              te1Ws10.id,
              te2Ws11.id
            ]);
          });
        });
      });
    });

    describe('handling of only', () =>
      describe('when getting data from the server', function() {
        it('returns the requested ids with includes, triggering reset and success', function() {
          respondWith(
            server,
            '/api/time_entries?include=project%2Ctask&only=2',
            {
              resultsFrom: 'time_entries',
              data: {
                time_entries: [
                  buildTimeEntry({ task_id: null, project_id: 10, id: 2 })
                ],
                tasks: [],
                projects: [buildProject({ id: 10 })]
              }
            }
          );
          const spy2 = jasmine
            .createSpy()
            .and.callFake(collection => expect(collection.loaded).toBe(true));
          const collection = manager.loadCollection('time_entries', {
            include: ['project', 'task'],
            only: 2,
            success: spy2
          });
          const spy = jasmine.createSpy().and.callFake(function() {
            expect(collection.loaded).toBe(true);
            expect(collection.get(2).get('task')).toBeFalsy();
            expect(collection.get(2).get('project').id).toEqual('10');
            return expect(collection.length).toEqual(1);
          });
          collection.bind('reset', spy);
          expect(collection.loaded).toBe(false);
          server.respond();
          expect(collection.loaded).toBe(true);
          expect(spy).toHaveBeenCalled();
          return expect(spy2).toHaveBeenCalled();
        });

        it('requests all ids even onces that that we already have', function() {
          respondWith(
            server,
            '/api/time_entries?include=project%2Ctask&only=2',
            {
              resultsFrom: 'time_entries',
              data: {
                time_entries: [
                  buildTimeEntry({ task_id: null, project_id: 10, id: 2 })
                ],
                tasks: [],
                projects: [buildProject({ id: 10 })]
              }
            }
          );
          respondWith(
            server,
            '/api/time_entries?include=project%2Ctask&only=2%2C3',
            {
              resultsFrom: 'time_entries',
              data: {
                time_entries: [
                  buildTimeEntry({ task_id: null, project_id: 10, id: 2 }),
                  buildTimeEntry({ task_id: null, project_id: 11, id: 3 })
                ],
                tasks: [],
                projects: [buildProject({ id: 10 }), buildProject({ id: 11 })]
              }
            }
          );

          const collection = manager.loadCollection('time_entries', {
            include: ['project', 'task'],
            only: 2
          });
          expect(collection.loaded).toBe(false);
          server.respond();
          expect(collection.loaded).toBe(true);
          expect(collection.get(2).get('project').id).toEqual('10');
          const collection2 = manager.loadCollection('time_entries', {
            include: ['project', 'task'],
            only: ['2', '3']
          });
          expect(collection2.loaded).toBe(false);
          server.respond();
          expect(collection2.loaded).toBe(true);
          expect(collection2.length).toEqual(2);
          expect(collection2.get(2).get('project').id).toEqual('10');
          return expect(collection2.get(3).get('project').id).toEqual('11');
        });

        it("doesn't go to the server if it doesn't need to", function() {
          respondWith(
            server,
            '/api/time_entries?include=project%2Ctask&only=2%2C3',
            {
              resultsFrom: 'time_entries',
              data: {
                time_entries: [
                  buildTimeEntry({ project_id: 10, id: 2, task_id: null }),
                  buildTimeEntry({ project_id: 11, id: 3 })
                ],
                tasks: [],
                projects: [buildProject({ id: 10 }), buildProject({ id: 11 })]
              }
            }
          );
          const collection = manager.loadCollection('time_entries', {
            include: ['project', 'task'],
            only: [2, 3]
          });
          expect(collection.loaded).toBe(false);
          server.respond();
          expect(collection.loaded).toBe(true);
          expect(collection.get(2).get('project').id).toEqual('10');
          expect(collection.get(3).get('project').id).toEqual('11');
          expect(collection.length).toEqual(2);
          const spy = jasmine.createSpy();
          const collection2 = manager.loadCollection('time_entries', {
            include: ['project'],
            only: [2, 3],
            success: spy
          });
          expect(spy).toHaveBeenCalled();
          expect(collection2.loaded).toBe(true);
          expect(collection2.get(2).get('project').id).toEqual('10');
          expect(collection2.get(3).get('project').id).toEqual('11');
          return expect(collection2.length).toEqual(2);
        });

        it('returns an empty collection when passed in an empty array', function() {
          const timeEntries = [
            buildTimeEntry({ task_id: 2, project_id: 15, id: 1 }),
            buildTimeEntry({ project_id: 10, id: 2 })
          ];
          respondWith(server, '/api/time_entries?per_page=20&page=1', {
            resultsFrom: 'time_entries',
            data: { time_entries: timeEntries }
          });
          let collection = manager.loadCollection('time_entries', { only: [] });
          expect(collection.loaded).toBe(true);
          expect(collection.length).toEqual(0);

          collection = manager.loadCollection('time_entries', { only: null });
          server.respond();
          expect(collection.loaded).toBe(true);
          return expect(collection.length).toEqual(2);
        });

        it('accepts a success function that gets triggered on cache hit', function() {
          respondWith(
            server,
            '/api/time_entries?include=project%2Ctask&only=2%2C3',
            {
              resultsFrom: 'time_entries',
              data: {
                time_entries: [
                  buildTimeEntry({ project_id: 10, id: 2, task_id: null }),
                  buildTimeEntry({ project_id: 11, id: 3, task_id: null })
                ],
                tasks: [],
                projects: [buildProject({ id: 10 }), buildProject({ id: 11 })]
              }
            }
          );
          manager.loadCollection('time_entries', {
            include: ['project', 'task'],
            only: [2, 3]
          });
          server.respond();
          const spy = jasmine.createSpy().and.callFake(function(collection) {
            expect(collection.loaded).toBe(true);
            expect(collection.get(2).get('project').id).toEqual('10');
            return expect(collection.get(3).get('project').id).toEqual('11');
          });
          const collection2 = manager.loadCollection('time_entries', {
            include: ['project'],
            only: [2, 3],
            success: spy
          });
          return expect(spy).toHaveBeenCalled();
        });

        return it('does go to the server on a repeat request if an association is missing', function() {
          respondWith(server, '/api/time_entries?include=project&only=2', {
            resultsFrom: 'time_entries',
            data: {
              time_entries: [
                buildTimeEntry({ project_id: 10, id: 2, task_id: 6 })
              ],
              projects: [buildProject({ id: 10 })]
            }
          });
          respondWith(
            server,
            '/api/time_entries?include=project%2Ctask&only=2',
            {
              resultsFrom: 'time_entries',
              data: {
                time_entries: [
                  buildTimeEntry({ project_id: 10, id: 2, task_id: 6 })
                ],
                tasks: [buildTask({ id: 6 })],
                projects: [buildProject({ id: 10 })]
              }
            }
          );
          const collection = manager.loadCollection('time_entries', {
            include: ['project'],
            only: 2
          });
          expect(collection.loaded).toBe(false);
          server.respond();
          expect(collection.loaded).toBe(true);
          const collection2 = manager.loadCollection('time_entries', {
            include: ['project', 'task'],
            only: 2
          });
          return expect(collection2.loaded).toBe(false);
        });
      }));

    describe('disabling caching', function() {
      let item = null;

      beforeEach(function() {
        item = buildTask();
        return respondWith(server, '/api/tasks?per_page=20&page=1', {
          resultsFrom: 'tasks',
          data: { tasks: [item] }
        });
      });

      it('goes to server even if we have matching items in cache', function() {
        const syncSpy = spyOn(Backbone, 'sync');
        const collection = manager.loadCollection('tasks', {
          cache: false,
          only: item.id
        });
        return expect(syncSpy).toHaveBeenCalled();
      });

      return it('still adds results to the cache', function() {
        const spy = spyOn(manager.storage('tasks'), 'update');
        const collection = manager.loadCollection('tasks', { cache: false });
        server.respond();
        return expect(spy).toHaveBeenCalled();
      });
    });

    describe('types of pagination', function() {
      it('prioritizes limit and offset over per page and page', function() {
        respondWith(server, '/api/time_entries?limit=1&offset=0', {
          resultsFrom: 'time_entries',
          data: { time_entries: [buildTimeEntry()] }
        });
        manager.loadCollection('time_entries', {
          limit: 1,
          offset: 0,
          perPage: 5,
          page: 10
        });
        return server.respond();
      });

      it('limits to at least 1 and offset 0', function() {
        respondWith(server, '/api/time_entries?limit=1&offset=0', {
          resultsFrom: 'time_entries',
          data: { time_entries: [buildTimeEntry()] }
        });
        manager.loadCollection('time_entries', { limit: -5, offset: -5 });
        return server.respond();
      });

      return it('falls back to per page and page if both limit and offset are not complete', function() {
        respondWith(server, '/api/time_entries?per_page=5&page=10', {
          resultsFrom: 'time_entries',
          data: { time_entries: [buildTimeEntry()] }
        });
        manager.loadCollection('time_entries', {
          limit: '',
          offset: '',
          perPage: 5,
          page: 10
        });
        server.respond();

        manager.loadCollection('time_entries', {
          limit: '',
          perPage: 5,
          page: 10
        });
        server.respond();

        manager.loadCollection('time_entries', {
          offset: '',
          perPage: 5,
          page: 10
        });
        return server.respond();
      });
    });

    describe('searching', function() {
      it('turns off caching', function() {
        const spy = spyOn(
          AbstractLoader.prototype,
          '_checkCacheForData'
        ).and.callThrough();
        const collection = manager.loadCollection('tasks', {
          search: 'the meaning of life'
        });
        return expect(spy).not.toHaveBeenCalled();
      });

      it('does not overwrite the existing non-search cache', function() {
        const fakeCache = {
          count: 2,
          results: [
            { key: 'task', id: 1 },
            { key: 'task', id: 2 }
          ]
        };

        const loader = manager.loadObject('tasks');
        manager.collections.tasks.cache[
          loader.loadOptions.cacheKey
        ] = fakeCache;
        expect(loader.getCacheObject()).toEqual(fakeCache);

        const searchLoader = manager.loadObject('tasks', { search: 'foobar' });
        searchLoader._updateStorageManagerFromResponse({
          count: 0,
          results: []
        });

        return expect(loader.getCacheObject()).toEqual(fakeCache);
      });

      it('returns the matching items with includes, triggering reset and success', function() {
        const task = buildTask();
        respondWith(
          server,
          '/api/tasks?search=go+go+gadget+search&per_page=20&page=1',
          { data: { results: [{ key: 'tasks', id: task.id }], tasks: [task] } }
        );
        const spy2 = jasmine
          .createSpy()
          .and.callFake(collection => expect(collection.loaded).toBe(true));
        const collection = manager.loadCollection('tasks', {
          search: 'go go gadget search',
          success: spy2
        });
        const spy = jasmine
          .createSpy()
          .and.callFake(() => expect(collection.loaded).toBe(true));
        collection.bind('reset', spy);
        expect(collection.loaded).toBe(false);
        server.respond();
        expect(collection.loaded).toBe(true);
        expect(spy).toHaveBeenCalled();
        return expect(spy2).toHaveBeenCalled();
      });

      it('does not blow up when no results are returned', function() {
        respondWith(
          server,
          '/api/tasks?search=go+go+gadget+search&per_page=20&page=1',
          { data: { results: [], tasks: [] } }
        );
        const collection = manager.loadCollection('tasks', {
          search: 'go go gadget search'
        });
        return server.respond();
      });

      return it('acts as if no search options were passed if the search string is blank', function() {
        respondWith(server, '/api/tasks?per_page=20&page=1', {
          data: { results: [], tasks: [] }
        });
        const collection = manager.loadCollection('tasks', { search: '' });
        return server.respond();
      });
    });

    return describe('return values', () =>
      it('adds the jQuery XHR object to the return values if returnValues is passed in', function() {
        const baseXhr = $.ajax();
        const returnValues = {};

        manager.loadCollection('tasks', {
          search: 'the meaning of life',
          returnValues
        });
        expect(returnValues.jqXhr).not.toBeUndefined();

        // if it has most of the functions of a jQuery XHR object then it's probably a jQuery XHR object
        const jqXhrKeys = [
          'setRequestHeader',
          'getAllResponseHeaders',
          'getResponseHeader',
          'overrideMimeType',
          'abort'
        ];

        return (() => {
          const result = [];
          for (let functionName of Array.from(jqXhrKeys)) {
            const funct = returnValues.jqXhr[functionName];
            expect(funct).not.toBeUndefined();
            result.push(
              expect(funct.toString()).toEqual(baseXhr[functionName].toString())
            );
          }
          return result;
        })();
      }));
  });

  describe('bootstrap', function() {
    let task = null;

    beforeEach(function() {
      task = buildTask({ title: 'Booting!', description: 'shenanigans' });

      const responseJson = {
        count: 1,
        results: [{ key: 'tasks', id: task.id }],
        tasks: {
          [task.id]: task.attributes
        }
      };

      const loadOptions = {
        order: 'the other way',
        includes: 'foo',
        filters: { bar: 'baz' }
      };
      return manager.bootstrap('tasks', responseJson, loadOptions);
    });

    it('loads models into the storage manager', function() {
      const cachedTask = manager.storage('tasks').get(task.id);
      expect(cachedTask).toBeDefined();

      return (() => {
        const result = [];
        for (let attribute in task.attributes) {
          const value = task.attributes[attribute];
          result.push(expect(cachedTask.get(attribute)).toEqual(value));
        }
        return result;
      })();
    });

    return it('caches response as it were an actual request', function() {
      const cache = manager.getCollectionDetails('tasks').cache[
        'the other way|{"bar":"baz"}||||||'
      ];
      return expect(cache).toBeDefined();
    });
  });

  return describe('error handling', () =>
    describe('passing in a custom error handler when loading a collection', function() {
      it('gets called when there is an error', function() {
        const customHandler = jasmine.createSpy('customHandler');
        server.respondWith('GET', '/api/time_entries?per_page=20&page=1', [
          401,
          { 'Content-Type': 'application/json' },
          JSON.stringify({ errors: ['Invalid OAuth 2 Request'] })
        ]);
        manager.loadCollection('time_entries', { error: customHandler });
        server.respond();
        return expect(customHandler).toHaveBeenCalled();
      });

      return it('should also get called any amount of layers deep', function() {
        const errorHandler = jasmine.createSpy('errorHandler');
        const successHandler = jasmine.createSpy('successHandler');
        const taskOne = buildTask({ id: 10, sub_task_ids: [12] });
        const taskOneSub = buildTask({
          id: 12,
          parent_id: 10,
          sub_task_ids: [13],
          project_id: taskOne.get('workspace_id')
        });
        respondWith(
          server,
          '/api/tasks?include=sub_tasks&parents_only=true&per_page=20&page=1',
          {
            data: {
              results: resultsArray('tasks', [taskOne]),
              tasks: resultsObject([taskOne, taskOneSub])
            }
          }
        );
        server.respondWith(
          'GET',
          '/api/tasks?include=sub_tasks&only=12&apply_default_filters=false',
          [
            401,
            { 'Content-Type': 'application/json' },
            JSON.stringify({ errors: ['Invalid OAuth 2 Request'] })
          ]
        );
        manager.loadCollection('tasks', {
          filters: { parents_only: 'true' },
          include: [{ sub_tasks: ['sub_tasks'] }],
          success: successHandler,
          error: errorHandler
        });

        expect(successHandler).not.toHaveBeenCalled();
        expect(errorHandler).not.toHaveBeenCalled();
        server.respond();
        server.respond();
        expect(successHandler).not.toHaveBeenCalled();
        expect(errorHandler).toHaveBeenCalled();
        return expect(errorHandler.calls.count()).toEqual(1);
      });
    }));
});
