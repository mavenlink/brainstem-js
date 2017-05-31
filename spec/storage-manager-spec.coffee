$ = require 'jquery'
Backbone = require 'backbone'
Backbone.$ = $ # TODO remove after upgrading to backbone 1.2+

StorageManager = require '../src/storage-manager'
AbstractLoader = require '../src/loaders/abstract-loader'
ModelLoader = require '../src/loaders/model-loader'

Tasks = require './helpers/models/tasks'
TimeEntries = require './helpers/models/time-entries'
Projects = require './helpers/models/projects'


describe 'Brainstem Storage Manager', ->
  manager = null

  beforeEach ->
    manager = StorageManager.get()
    manager.reset()

  describe 'storage', ->
    beforeEach ->
      manager.addCollection 'time_entries', TimeEntries

    it "accesses a cached collection of the appropriate type", ->
      expect(manager.storage('time_entries') instanceof TimeEntries).toBeTruthy()
      expect(manager.storage('time_entries').length).toBe 0

    it "raises an error if the named collection doesn't exist", ->
      expect(-> manager.storage('foo')).toThrow()

  describe 'addCollection and getCollectionDetails', ->

    it "tracks a named collection", ->
      manager.addCollection 'time_entries', TimeEntries
      expect(manager.getCollectionDetails("time_entries").klass).toBe TimeEntries

    it "raises an error if the named collection doesn't exist", ->
      expect(-> manager.getCollectionDetails('foo')).toThrow()

    it "binds to the collection for remove and calls invalidateCache on the model", ->
      manager.addCollection 'time_entries', TimeEntries

      timeEntry = buildTimeEntry()
      spyOn(timeEntry, 'invalidateCache')

      manager.storage('time_entries').add(timeEntry)

      expect(timeEntry.invalidateCache).not.toHaveBeenCalled()
      timeEntry.collection.remove(timeEntry)
      expect(timeEntry.invalidateCache).toHaveBeenCalled()

    it 'initializes firstFetchOptions is an empty object', ->
      manager.addCollection 'time_entries', TimeEntries
      expect(manager.storage('time_entries').firstFetchOptions).toEqual({})

  describe "reset", ->
    beforeEach ->
      buildAndCacheTask()
      buildAndCacheProject()

    it "should clear all storage and sort lengths", ->
      expect(manager.storage("projects").length).toEqual 1
      expect(manager.storage("tasks").length).toEqual 1

      manager.collections["projects"].cache = { "foo": "bar" }
      manager.reset()

      expect(manager.collections["projects"].cache).toEqual {}
      expect(manager.storage("projects").length).toEqual 0
      expect(manager.storage("tasks").length).toEqual 0

  describe "complete callback", ->
    describe "loadModel", ->
      it "fires when there is an error", ->
        completeSpy = jasmine.createSpy('completeSpy')
        respondWith server, "/api/time_entries/1337", data: { results: [] }, status: 404
        manager.loadModel "time_entry", 1337, complete: completeSpy

        server.respond()
        expect(completeSpy).toHaveBeenCalled()

      it "fires on success", ->
        completeSpy = jasmine.createSpy('completeSpy')
        respondWith server, "/api/time_entries/1337", data: { results: [] }
        manager.loadModel "time_entry", 1337, complete: completeSpy

        server.respond()
        expect(completeSpy).toHaveBeenCalled()

    describe "loadCollection", ->
      it "fires when there is an error", ->
        completeSpy = jasmine.createSpy('completeSpy')
        respondWith server, "/api/time_entries?per_page=20&page=1", data: { results: [] }, status: 404
        manager.loadCollection "time_entries", complete: completeSpy

        server.respond()
        expect(completeSpy).toHaveBeenCalled()

      it "fires on success", ->
        completeSpy = jasmine.createSpy('completeSpy')
        respondWith server, "/api/time_entries?per_page=20&page=1", data: { results: [] }
        manager.loadCollection "time_entries", complete: completeSpy

        server.respond()
        expect(completeSpy).toHaveBeenCalled()

  describe "createNewCollection", ->
    it "makes a new collection of the appropriate type", ->
      expect(manager.createNewCollection("tasks", [buildTask(), buildTask()]) instanceof Tasks).toBe true

    it "can accept a 'loaded' flag", ->
      collection = manager.createNewCollection("tasks", [buildTask(), buildTask()])
      expect(collection.loaded).toBe false
      collection = manager.createNewCollection("tasks", [buildTask(), buildTask()], loaded: true)
      expect(collection.loaded).toBe true

  describe "loadModel", ->
    beforeEach ->
      tasks = [buildTask(id: 2, title: "a task", project_id: 15)]
      projects = [buildProject(id: 15)]
      timeEntries = [buildTimeEntry(id: 1, task_id: 2, project_id: 15, title: "a time entry")]
      respondWith server, "/api/time_entries/1", resultsFrom: "time_entries", data: { time_entries: timeEntries }
      respondWith server, "/api/time_entries/1?include=project%2Ctask", resultsFrom: "time_entries", data: { time_entries: timeEntries, tasks: tasks, projects: projects }

    it "creates a new model with the supplied id", ->
      loader = manager.loadModel "time_entry", "333"
      expect(loader.getModel().id).toEqual "333"

    it "calls Backbone.sync with the model from the loader", ->
      spyOn(Backbone, 'sync')
      loader = manager.loadModel "time_entry", "333"
      expect(Backbone.sync).toHaveBeenCalledWith 'read', loader.getModel(), loader._buildSyncOptions()

    it "loads a single model from the server, including associations", ->
      loaded = false
      loader = manager.loadModel "time_entry", 1, include: ["project", "task"]
      loader.done -> loaded = true
      model = loader.getModel()

      expect(loaded).toBe false
      server.respond()
      expect(loaded).toBe true
      expect(model.id).toEqual "1"
      expect(model.get("title")).toEqual "a time entry"
      expect(model.get('task').get('title')).toEqual "a task"
      expect(model.get('project').id).toEqual "15"

    it "works with complex associations", ->
      mainProject = buildProject(title: "my project")
      mainTask = buildTask(project_id: mainProject.id, title: "foo")
      timeTask = buildTask(title: 'hello')
      timeEntry = buildTimeEntry(project_id: mainProject.id, task_id: timeTask.id, time: 50)
      mainProject.set('time_entry_ids', [timeEntry.id])

      subTask = buildTask()
      mainTask.set('sub_task_ids', [subTask.id])

      mainTaskAssignee = buildUser(name: 'Kimbo')
      mainTask.set('assignee_ids', [mainTaskAssignee.id])

      subTaskAssignee = buildUser(name: 'Slice')
      subTask.set('assignee_ids', [subTaskAssignee.id])

      respondWith server, "/api/tasks/#{mainTask.id}?include=assignees%2Csub_tasks%2Cproject",
        resultsFrom: "tasks"
        data:
          results: resultsArray("tasks", [mainTask])
          tasks: resultsObject([mainTask, subTask])
          projects: resultsObject([mainProject])
          users: resultsObject([mainTaskAssignee])
      respondWith server, "/api/tasks?include=assignees&only=#{subTask.id}&apply_default_filters=false",
        resultsFrom: "tasks"
        data:
          results: resultsArray("tasks", [subTask])
          tasks: resultsObject([subTask])
          users: resultsObject([subTaskAssignee])
      respondWith server, "/api/projects?include=time_entries&only=#{mainProject.id}&apply_default_filters=false",
        resultsFrom: "projects"
        data:
          results: resultsArray("projects", [mainProject])
          time_entries: resultsObject([timeEntry])
          projects: resultsObject([mainProject])
      respondWith server, "/api/time_entries?include=task&only=#{timeEntry.id}&apply_default_filters=false",
        resultsFrom: "time_entries"
        data:
          results: resultsArray("time_entries", [timeEntry])
          time_entries: resultsObject([timeEntry])
          tasks: resultsObject([timeTask])

      loader = manager.loadModel "task", mainTask.id,
        include: [
          "assignees",
          { sub_tasks: ["assignees"] },
          { project: [{ time_entries: ["task"] }] }
        ]

      model = loader.getModel()

      server.respond() until server.queue.length == 0

      # check main model
      expect(model.attributes).toEqual(mainTask.attributes)

      # check assignees
      expect(model.get('assignees').length).toEqual(1)
      expect(model.get('assignees').first().get('name')).toEqual('Kimbo')

      # check sub_tasks
      subTasks = model.get('sub_tasks')
      expect(subTasks.length).toEqual(1)

      # check sub_tasks -> assignees
      assignees = subTasks.at(0).get('assignees')
      expect(assignees.length).toEqual(1)
      expect(assignees.at(0).get('name')).toEqual('Slice')

      # check project
      project = model.get('project')
      expect(project.get('title')).toEqual('my project')

      # check project -> time_entries
      timeEntries = project.get('time_entries')
      expect(timeEntries.length).toEqual(1)

      timeEntry = timeEntries.at(0)
      expect(timeEntry.get('time')).toEqual(50)

      # check project -> time_entries -> task
      expect(timeEntry.get('task').get('title')).toEqual('hello')

    it "uses the cache if it can", ->
      task = buildAndCacheTask(id: 200)
      spy = spyOn(AbstractLoader.prototype, '_loadFromServer')

      loader = manager.loadModel "task", task.id
      model = loader.getModel()
      expect(model.attributes).toEqual(task.attributes)
      expect(spy).not.toHaveBeenCalled()

    it "works even when the server returned associations of the same type", ->
      posts = [buildPost(id: 2, reply: true), buildPost(id: 3, reply: true), buildPost(id: 1, reply: false, reply_ids: [2, 3])]
      respondWith server, "/api/posts/1?include=replies", data: { results: [{ key: "posts", id: 1 }], posts: posts }
      loaded = false
      loader = manager.loadModel "post", 1, include: ["replies"]
      loader.done -> loaded = true
      model = loader.getModel()
      expect(loaded).toBe false
      server.respond()
      expect(loaded).toBe true
      expect(model.id).toEqual "1"
      expect(model.get("replies").pluck("id")).toEqual ["2", "3"]

    it "updates associations before the primary model", ->
      events = []
      manager.storage('time_entries').on "add", -> events.push "time_entries"
      manager.storage('tasks').on "add", -> events.push "tasks"
      manager.loadModel "time_entry", 1, include: ["project", "task"]
      server.respond()
      expect(events).toEqual ["tasks", "time_entries"]

    it "triggers changes", ->
      loaded = false
      loader = manager.loadModel "time_entry", 1, include: ["project", "task"]
      loader.done -> loaded = true
      model = loader.getModel()
      spy = jasmine.createSpy().and.callFake ->
        expect(model.get("title")).toEqual "a time entry"
        expect(model.get('task').get('title')).toEqual "a task"
        expect(model.get('project').id).toEqual "15"
      model.bind "change", spy
      expect(spy).not.toHaveBeenCalled()
      expect(loaded).toBe false
      server.respond()
      expect(spy).toHaveBeenCalled()
      expect(spy.calls.count()).toEqual 1
      expect(loaded).toBe true

    it "accepts a success function", ->
      spy = jasmine.createSpy()
      manager.loadModel "time_entry", 1, success: spy
      server.respond()
      expect(spy).toHaveBeenCalled()

    it "can disable caching", ->
      spy = spyOn(ModelLoader.prototype, '_checkCacheForData').and.callThrough()
      manager.loadModel "time_entry", 1, cache: false
      expect(spy).not.toHaveBeenCalled()

    it "invokes the error callback when the server responds with a 404", ->
      successSpy = jasmine.createSpy('successSpy')
      errorSpy = jasmine.createSpy('errorSpy')
      respondWith server, "/api/time_entries/1337", data: { results: [] }, status: 404
      manager.loadModel "time_entry", 1337, success: successSpy, error: errorSpy

      server.respond()
      expect(successSpy).not.toHaveBeenCalled()
      expect(errorSpy).toHaveBeenCalled()

    it "does not resolve until all of the associations are included", ->
      manager.enableExpectations()

      project = buildProject()
      user = buildUser()

      task = buildTask(title: 'foobar', project_id: project.id)
      task2 = buildTask(project_id: project.id)
      task3 = buildTask(project_id: project.id, assignee_ids: [user.id])

      project.set('task_ids', [task.id, task2.id, task3.id])

      taskExpectation = manager.stubModel "task", task.id, include: ['project': [{ 'tasks': ['assignees'] }]], response: (stub) ->
        stub.result = task
        stub.associated.project = [project]
        stub.recursive = true

      projectExpectation = manager.stub "projects", only: project.id, include: ['tasks': ['assignees']], params: { apply_default_filters: false }, response: (stub) ->
        stub.results = [project]
        stub.associated.tasks = [task, task2, task3]
        stub.recursive = true

      taskWithAssigneesExpectation = manager.stub "tasks", only: [task.id, task2.id, task3.id], include: ['assignees'], params: { apply_default_filters: false }, response: (stub) ->
        stub.results = [task]
        stub.associated.users = [user]

      resolvedSpy = jasmine.createSpy('resolved')

      model = buildAndCacheTask(id: task.id)
      loader = manager.loadModel "task", model.id, include: ['project': [{ 'tasks': ['assignees'] }]]
      loader.done(resolvedSpy)

      taskExpectation.respond()
      expect(resolvedSpy).not.toHaveBeenCalled()

      projectExpectation.respond()
      expect(resolvedSpy).not.toHaveBeenCalled()

      taskWithAssigneesExpectation.respond()
      expect(resolvedSpy).toHaveBeenCalled()

      manager.disableExpectations()

  describe 'loadCollection', ->
    it "loads a collection of models", ->
      timeEntries = [buildTimeEntry(), buildTimeEntry()]
      respondWith server, "/api/time_entries?per_page=20&page=1", resultsFrom: "time_entries", data: { time_entries: timeEntries }
      collection = manager.loadCollection "time_entries"
      expect(collection.length).toBe 0
      server.respond()
      expect(collection.length).toBe 2

    it "accepts a success function", ->
      timeEntries = [buildTimeEntry(), buildTimeEntry()]
      respondWith server, "/api/time_entries?per_page=20&page=1", resultsFrom: "time_entries", data: { time_entries: timeEntries }
      spy = jasmine.createSpy().and.callFake (collection) ->
        expect(collection.loaded).toBe true
      collection = manager.loadCollection "time_entries", success: spy
      server.respond()
      expect(spy).toHaveBeenCalledWith(collection)

    it "saves it's options onto the returned collection", ->
      collection = manager.loadCollection "time_entries", order: "baz:desc", filters: { bar: 2 }
      expect(collection.lastFetchOptions.order).toEqual "baz:desc"
      expect(collection.lastFetchOptions.filters).toEqual { bar: 2 }
      expect(collection.lastFetchOptions.collection).toBeFalsy()

    describe "passing an optional collection", ->
      it "accepts an optional collection instead of making a new one", ->
        timeEntry = buildTimeEntry()
        respondWith server, "/api/time_entries?per_page=20&page=1", data: { results: [{ key: "time_entries", id: timeEntry.id }], time_entries: [timeEntry] }
        collection = new TimeEntries([buildTimeEntry(), buildTimeEntry()])
        collection.setLoaded true
        manager.loadCollection "time_entries", collection: collection
        expect(collection.lastFetchOptions.collection).toBeFalsy()
        expect(collection.loaded).toBe false
        expect(collection.length).toEqual 2
        server.respond()
        expect(collection.loaded).toBe true
        expect(collection.length).toEqual 3

      it "can take an optional reset command to reset the collection before using it", ->
        timeEntry = buildTimeEntry()
        respondWith server, "/api/time_entries?per_page=20&page=1", data: { results: [{ key: "time_entries", id: timeEntry.id }], time_entries: [timeEntry] }
        collection = new TimeEntries([buildTimeEntry(), buildTimeEntry()])
        collection.setLoaded true
        spyOn(collection, 'reset').and.callThrough()
        manager.loadCollection "time_entries", collection: collection, reset: true
        expect(collection.reset).toHaveBeenCalled()
        expect(collection.lastFetchOptions.collection).toBeFalsy()
        expect(collection.loaded).toBe false
        expect(collection.length).toEqual 0
        server.respond()
        expect(collection.loaded).toBe true
        expect(collection.length).toEqual 1

    it "accepts filters", ->
      posts = [buildPost(project_id: 15, id: 1), buildPost(project_id: 15, id: 2)]
      respondWith server, "/api/posts?filter1=true&filter2=false&filter3=true&filter4=false&filter5=2&filter6=baz&per_page=20&page=1", data: { results: [{ key: "posts", id: 1}], posts: posts }
      collection = manager.loadCollection "posts", filters: { filter1: true, filter2: false, filter3: "true", filter4: "false", filter5: 2, filter6: "baz" }
      server.respond()

    it "triggers reset", ->
      timeEntry = buildTimeEntry()
      respondWith server, "/api/time_entries?per_page=20&page=1", data: { results: [{ key: "time_entries", id: timeEntry.id}], time_entries: [timeEntry] }
      collection = manager.loadCollection "time_entries"
      expect(collection.loaded).toBe false
      spy = jasmine.createSpy().and.callFake ->
        expect(collection.loaded).toBe true
      collection.bind "reset", spy
      server.respond()
      expect(spy).toHaveBeenCalled()

    it "ignores count and honors results", ->
      server.respondWith "GET", "/api/time_entries?per_page=20&page=1", [ 200, {"Content-Type": "application/json"}, JSON.stringify(count: 2, results: [{ key: "time_entries", id: 2 }], time_entries: [buildTimeEntry(), buildTimeEntry()]) ]
      collection = manager.loadCollection "time_entries"
      server.respond()
      expect(collection.length).toEqual(1)

    it "works with an empty response", ->
      exceptionSpy = spyOn(sinon, 'logError').and.callThrough()
      respondWith server, "/api/time_entries?per_page=20&page=1", resultsFrom: "time_entries", data: { time_entries: [] }
      manager.loadCollection "time_entries"
      server.respond()
      expect(exceptionSpy).not.toHaveBeenCalled()

    describe "fetching of associations", ->
      json = null

      beforeEach ->
        tasks = [buildTask(id: 2, title: "a task")]
        projects = [buildProject(id: 15), buildProject(id: 10)]
        timeEntries = [buildTimeEntry(task_id: 2, project_id: 15, id: 1), buildTimeEntry(task_id: null, project_id: 10, id: 2)]

        respondWith server, /\/api\/time_entries\?include=project%2Ctask&per_page=\d+&page=\d+/, resultsFrom: "time_entries", data: { time_entries: timeEntries, tasks: tasks, projects: projects }
        respondWith server, /\/api\/time_entries\?include=project&per_page=\d+&page=\d+/, resultsFrom: "time_entries", data: { time_entries: timeEntries, projects: projects }

      it "loads collections that should be included", ->
        collection = manager.loadCollection "time_entries", include: ["project", "task"]
        spy = jasmine.createSpy().and.callFake ->
          expect(collection.loaded).toBe true
          expect(collection.get(1).get('task').get('title')).toEqual "a task"
          expect(collection.get(2).get('task')).toBeFalsy()
          expect(collection.get(1).get('project').id).toEqual "15"
          expect(collection.get(2).get('project').id).toEqual "10"
        collection.bind "reset", spy
        expect(collection.loaded).toBe false
        server.respond()
        expect(collection.loaded).toBe true
        expect(spy).toHaveBeenCalled()

      it "applies uses the results array from the server (so that associations of the same type as the primary can be handled- posts with replies; tasks with subtasks, etc.)", ->
        posts = [buildPost(project_id: 15, id: 1, reply_ids: [2]), buildPost(project_id: 15, id: 2, subject_id: 1, reply: true)]
        respondWith server, "/api/posts?include=replies&parents_only=true&per_page=20&page=1", data: { results: [{ key: "posts", id: 1}], posts: posts }
        collection = manager.loadCollection "posts", include: ["replies"], filters: { parents_only: "true" }
        server.respond()
        expect(collection.pluck("id")).toEqual ["1"]
        expect(collection.get(1).get('replies').pluck("id")).toEqual ["2"]

      describe "fetching multiple levels of associations", ->
        callCount = success = checkStructure = null

        context 'deeply nested associations', ->
          beforeEach ->
            projectOneTimeEntryTask = buildTask()
            projectOneTimeEntry = buildTimeEntry(title: "without task"); projectOneTimeEntryWithTask = buildTimeEntry(id: projectOneTimeEntry.id, task_id: projectOneTimeEntryTask.id, title: "with task")
            projectOne = buildProject(); projectOneWithTimeEntries = buildProject(id: projectOne.id, time_entry_ids: [projectOneTimeEntry.id])
            projectTwo = buildProject(); projectTwoWithTimeEntries = buildProject(id: projectTwo.id, time_entry_ids: [])
            taskOneAssignee = buildUser()
            taskTwoAssignee = buildUser()
            taskOneSubAssignee = buildUser()
            taskOneSub = buildTask(project_id: projectOne.id, parent_id: 10); taskOneSubWithAssignees = buildTask(id: taskOneSub.id, assignee_ids: [taskOneSubAssignee.id], parent_id: 10)
            taskTwoSub = buildTask(project_id: projectTwo.id, parent_id: 11); taskTwoSubWithAssignees = buildTask(id: taskTwoSub.id, assignee_ids: [taskTwoAssignee.id], parent_id: 11)
            taskOne = buildTask(id: 10, project_id: projectOne.id, assignee_ids: [taskOneAssignee.id], sub_task_ids: [taskOneSub.id])
            taskTwo = buildTask(id: 11, project_id: projectTwo.id, assignee_ids: [taskTwoAssignee.id], sub_task_ids: [taskTwoSub.id])
            respondWith server, "/api/tasks?include=assignees%2Cproject%2Csub_tasks&parents_only=true&per_page=20&page=1", data: { results: resultsArray("tasks", [taskOne, taskTwo]), tasks: resultsObject([taskOne, taskTwo, taskOneSub, taskTwoSub]), users: resultsObject([taskOneAssignee, taskTwoAssignee]), projects: resultsObject([projectOne, projectTwo]) }
            respondWith server, "/api/tasks?include=assignees&only=#{taskOneSub.id}%2C#{taskTwoSub.id}&apply_default_filters=false", data: { results: resultsArray("tasks", [taskOneSub, taskTwoSub]), tasks: resultsObject([taskOneSubWithAssignees, taskTwoSubWithAssignees]), users: resultsObject([taskOneSubAssignee, taskTwoAssignee]) }
            respondWith server, "/api/projects?include=time_entries&only=#{projectOne.id}%2C#{projectTwo.id}&apply_default_filters=false", data: { results: resultsArray("projects", [projectOne, projectTwo]), projects: resultsObject([projectOneWithTimeEntries, projectTwoWithTimeEntries]), time_entries: resultsObject([projectOneTimeEntry]) }
            respondWith server, "/api/time_entries?include=task&only=#{projectOneTimeEntry.id}&apply_default_filters=false", data: { results: resultsArray("time_entries", [projectOneTimeEntry]), time_entries: resultsObject([projectOneTimeEntryWithTask]), tasks: resultsObject([projectOneTimeEntryTask]) }

            callCount = 0
            checkStructure = (collection) ->
              expect(collection.pluck("id").sort()).toEqual [taskOne.id, taskTwo.id]
              expect(collection.get(taskOne.id).get("project").id).toEqual projectOne.id
              expect(collection.get(taskOne.id).get("assignees").pluck("id")).toEqual [taskOneAssignee.id]
              expect(collection.get(taskTwo.id).get("assignees").pluck("id")).toEqual [taskTwoAssignee.id]
              expect(collection.get(taskOne.id).get("sub_tasks").pluck("id")).toEqual [taskOneSub.id]
              expect(collection.get(taskTwo.id).get("sub_tasks").pluck("id")).toEqual [taskTwoSub.id]
              expect(collection.get(taskOne.id).get("sub_tasks").get(taskOneSub.id).get("assignees").pluck("id")).toEqual [taskOneSubAssignee.id]
              expect(collection.get(taskTwo.id).get("sub_tasks").get(taskTwoSub.id).get("assignees").pluck("id")).toEqual [taskTwoAssignee.id]
              expect(collection.get(taskOne.id).get("project").get("time_entries").pluck("id")).toEqual [projectOneTimeEntry.id]
              expect(collection.get(taskOne.id).get("project").get("time_entries").models[0].get("task").id).toEqual projectOneTimeEntryTask.id
              callCount += 1

            success = jasmine.createSpy().and.callFake checkStructure

          context 'with json structure', ->
            it "separately requests each layer of associations", ->
              collection = manager.loadCollection "tasks",
                filters: { parents_only: "true" },
                success: success,
                include: [
                  'assignees',
                  { project: ["time_entries": "task"] },
                  { sub_tasks: ["assignees"] }
                ]

              collection.bind "loaded", checkStructure
              collection.bind "reset", checkStructure

              expect(success).not.toHaveBeenCalled()

              server.respond() until server.queue.length == 0

              expect(success).toHaveBeenCalledWith(collection)
              expect(callCount).toEqual 3

          context 'using a backbone collection', ->
            it "separately requests each layer of associations", ->
              projectCollection = new Projects null,
                include: ["time_entries": "task"]
                test: 10

              collection = manager.loadCollection "tasks",
                filters: { parents_only: "true" },
                success: success,
                include: [
                  'assignees',
                  { project: projectCollection },
                  { sub_tasks: ["assignees"] }
                ]

              collection.bind "loaded", checkStructure
              collection.bind "reset", checkStructure

              expect(success).not.toHaveBeenCalled()

              server.respond() until server.queue.length == 0
              expect(success).toHaveBeenCalled()
              expect(callCount).toEqual 3

        context 'a shallowly nested json structure', ->
          projectOne = projectTwo = null

          beforeEach ->
            projectOneTimeEntryTask = buildTask()
            projectOneTimeEntry = buildTimeEntry(title: "without task"); projectOneTimeEntryWithTask = buildTimeEntry(id: projectOneTimeEntry.id, task_id: projectOneTimeEntryTask.id, title: "with task")
            projectOne = buildProject(); projectOneWithTimeEntries = buildProject(id: projectOne.id, time_entry_ids: [projectOneTimeEntry.id])
            projectTwo = buildProject(); projectTwoWithTimeEntries = buildProject(id: projectTwo.id, time_entry_ids: [])
            taskOneAssignee = buildUser()
            taskTwoAssignee = buildUser()
            taskOneSubAssignee = buildUser()
            taskOneSub = buildTask(project_id: projectOne.id, parent_id: 10); taskOneSubWithAssignees = buildTask(id: taskOneSub.id, assignee_ids: [taskOneSubAssignee.id], parent_id: 10)
            taskTwoSub = buildTask(project_id: projectTwo.id, parent_id: 11); taskTwoSubWithAssignees = buildTask(id: taskTwoSub.id, assignee_ids: [taskTwoAssignee.id], parent_id: 11)
            taskOne = buildTask(id: 10, project_id: projectOne.id, assignee_ids: [taskOneAssignee.id], sub_task_ids: [taskOneSub.id])
            taskTwo = buildTask(id: 11, project_id: projectTwo.id, assignee_ids: [taskTwoAssignee.id], sub_task_ids: [taskTwoSub.id])
            respondWith server, "/api/tasks?include=assignees%2Cproject%2Csub_tasks&parents_only=true&per_page=20&page=1", data: { results: resultsArray("tasks", [taskOne, taskTwo]), tasks: resultsObject([taskOne, taskTwo, taskOneSub, taskTwoSub]), users: resultsObject([taskOneAssignee, taskTwoAssignee]), projects: resultsObject([projectOne, projectTwo]) }
            respondWith server, "/api/tasks?include=assignees&only=#{taskOneSub.id}%2C#{taskTwoSub.id}&apply_default_filters=false", data: { results: resultsArray("tasks", [taskOneSub, taskTwoSub]), tasks: resultsObject([taskOneSubWithAssignees, taskTwoSubWithAssignees]), users: resultsObject([taskOneSubAssignee, taskTwoAssignee]) }
            respondWith server, "/api/projects?only=#{projectOne.id}%2C#{projectTwo.id}&apply_default_filters=false&test=10", data: { results: resultsArray("projects", [projectOne, projectTwo]), projects: resultsObject([projectOneWithTimeEntries, projectTwoWithTimeEntries]) }

            callCount = 0
            checkStructure = (collection) ->
              expect(collection.pluck("id").sort()).toEqual [taskOne.id, taskTwo.id]
              expect(collection.get(taskOne.id).get("project").id).toEqual projectOne.id
              expect(collection.get(taskOne.id).get("assignees").pluck("id")).toEqual [taskOneAssignee.id]
              expect(collection.get(taskTwo.id).get("assignees").pluck("id")).toEqual [taskTwoAssignee.id]
              expect(collection.get(taskOne.id).get("sub_tasks").pluck("id")).toEqual [taskOneSub.id]
              expect(collection.get(taskTwo.id).get("sub_tasks").pluck("id")).toEqual [taskTwoSub.id]
              expect(collection.get(taskOne.id).get("sub_tasks").get(taskOneSub.id).get("assignees").pluck("id")).toEqual [taskOneSubAssignee.id]
              expect(collection.get(taskTwo.id).get("sub_tasks").get(taskTwoSub.id).get("assignees").pluck("id")).toEqual [taskTwoAssignee.id]

              callCount += 1

            success = jasmine.createSpy().and.callFake checkStructure

          it "separately requests each layer of associations with filters", ->
            projectCollection = new Projects null,
              filters:
                test: 10

            spyOn(projectCollection.storageManager, 'loadObject').and.callThrough()

            collection = manager.loadCollection "tasks",
              filters: { parents_only: "true" },
              success: success,
              include: [
                'assignees',
                { project: projectCollection },
                { sub_tasks: ["assignees"] }
              ]

            collection.bind "loaded", checkStructure
            collection.bind "reset", checkStructure

            expect(success).not.toHaveBeenCalled()

            server.respond() until server.queue.length == 0
            expect(success).toHaveBeenCalled()
            expect(callCount).toEqual 3

            expectedFilters = projectCollection.storageManager.loadObject.calls.all()[1].args[1].filters

            expect(projectCollection.storageManager.loadObject).toHaveBeenCalled()
            expect(expectedFilters).toEqual({ test: 10 })

            expect(projectCollection.first().id).toEqual(projectOne.id)
            expect(projectCollection.last().id).toEqual(projectTwo.id)

      describe "caching", ->
        describe "without ordering", ->
          it "doesn't go to the server when it already has the data", ->
            collection1 = manager.loadCollection "time_entries", include: ["project", "task"], page: 1, perPage: 2
            server.respond()
            expect(collection1.loaded).toBe true
            expect(collection1.get(1).get('project').id).toEqual "15"
            expect(collection1.get(2).get('project').id).toEqual "10"
            spy = jasmine.createSpy()
            collection2 = manager.loadCollection "time_entries", include: ["project", "task"], page: 1, perPage: 2, success: spy
            expect(spy).toHaveBeenCalled()
            expect(collection2.loaded).toBe true
            expect(collection2.get(1).get('task').get('title')).toEqual "a task"
            expect(collection2.get(2).get('task')).toBeFalsy()
            expect(collection2.get(1).get('project').id).toEqual "15"
            expect(collection2.get(2).get('project').id).toEqual "10"

          context "using perPage and page", ->
            it "does go to the server when more records are requested than it has previously requested, and remembers previously requested pages", ->
              collection1 = manager.loadCollection "time_entries", include: ["project", "task"], page: 1, perPage: 2
              server.respond()
              expect(collection1.loaded).toBe true
              collection2 = manager.loadCollection "time_entries", include: ["project", "task"], page: 2, perPage: 2
              expect(collection2.loaded).toBe false
              server.respond()
              expect(collection2.loaded).toBe true
              collection3 = manager.loadCollection "time_entries", include: ["project"], page: 1, perPage: 2
              expect(collection3.loaded).toBe true

          context "using limit and offset", ->
            it "does go to the server when more records are requested than it knows about", ->
              timeEntries = [buildTimeEntry(), buildTimeEntry()]
              respondWith server, "/api/time_entries?limit=2&offset=0", resultsFrom: "time_entries", data: { time_entries: timeEntries }
              respondWith server, "/api/time_entries?limit=2&offset=2", resultsFrom: "time_entries", data: { time_entries: timeEntries }

              collection1 = manager.loadCollection "time_entries", limit: 2, offset: 0
              server.respond()
              expect(collection1.loaded).toBe true
              collection2 = manager.loadCollection "time_entries", limit: 2, offset: 2
              expect(collection2.loaded).toBe false
              server.respond()
              expect(collection2.loaded).toBe true
              collection3 = manager.loadCollection "time_entries", limit: 2, offset: 0
              expect(collection3.loaded).toBe true

          it "does go to the server when some associations are missing, when otherwise it would have the data", ->
            collection1 = manager.loadCollection "time_entries", include: ["project"], page: 1, perPage: 2
            server.respond()
            expect(collection1.loaded).toBe true
            collection2 = manager.loadCollection "time_entries", include: ["project", "task"], page: 1, perPage: 2
            expect(collection2.loaded).toBe false

        describe "with ordering and filtering", ->
          now = ws10 = ws11 = te1Ws10 = te2Ws10 = te1Ws11 = te2Ws11 = null

          beforeEach ->
            now = (new Date()).getTime()
            ws10 = buildProject(id: 10)
            ws11 = buildProject(id: 11)
            te1Ws10 = buildTimeEntry(task_id: null, project_id: 10, id: 1, created_at: now - 20 * 1000, updated_at: now - 10 * 1000)
            te2Ws10 = buildTimeEntry(task_id: null, project_id: 10, id: 2, created_at: now - 10 * 1000, updated_at: now - 5 * 1000)
            te1Ws11 = buildTimeEntry(task_id: null, project_id: 11, id: 3, created_at: now - 100 * 1000, updated_at: now - 4 * 1000)
            te2Ws11 = buildTimeEntry(task_id: null, project_id: 11, id: 4, created_at: now - 200 * 1000, updated_at: now - 12 * 1000)

          it "goes to the server for pages of data and updates the collection", ->
            respondWith server, "/api/time_entries?order=created_at%3Aasc&per_page=2&page=1", data: { results: resultsArray("time_entries", [te2Ws11, te1Ws11]), time_entries: [te2Ws11, te1Ws11] }
            respondWith server, "/api/time_entries?order=created_at%3Aasc&per_page=2&page=2", data: { results: resultsArray("time_entries", [te1Ws10, te2Ws10]), time_entries: [te1Ws10, te2Ws10] }
            collection = manager.loadCollection "time_entries", order: "created_at:asc", page: 1, perPage: 2
            server.respond()
            expect(collection.pluck("id")).toEqual [te2Ws11.id, te1Ws11.id]
            manager.loadCollection "time_entries", collection: collection, order: "created_at:asc", page: 2, perPage: 2
            server.respond()
            expect(collection.pluck("id")).toEqual [te2Ws11.id, te1Ws11.id, te1Ws10.id, te2Ws10.id]

          it "does not re-sort the results", ->
            respondWith server, "/api/time_entries?order=created_at%3Adesc&per_page=2&page=1", data: { results: resultsArray("time_entries", [te2Ws11, te1Ws11]), time_entries: [te1Ws11, te2Ws11] }
            # it's really created_at:asc
            collection = manager.loadCollection "time_entries", order: "created_at:desc", page: 1, perPage: 2
            server.respond()
            expect(collection.pluck("id")).toEqual [te2Ws11.id, te1Ws11.id]

          it "seperately caches data requested by different sort orders and filters", ->
            server.responses = []
            respondWith server, "/api/time_entries?include=project%2Ctask&order=updated_at%3Adesc&project_id=10&per_page=2&page=1",
                        data: { results: resultsArray("time_entries", [te2Ws10, te1Ws10]), time_entries: [te2Ws10, te1Ws10], tasks: [], projects: [ws10] }
            respondWith server, "/api/time_entries?include=project%2Ctask&order=updated_at%3Adesc&project_id=11&per_page=2&page=1",
                        data: { results: resultsArray("time_entries", [te1Ws11, te2Ws11]), time_entries: [te1Ws11, te2Ws11], tasks: [], projects: [ws11] }
            respondWith server, "/api/time_entries?include=project%2Ctask&order=created_at%3Aasc&project_id=11&per_page=2&page=1",
                        data: { results: resultsArray("time_entries", [te2Ws11, te1Ws11]), time_entries: [te2Ws11, te1Ws11], tasks: [], projects: [ws11] }
            respondWith server, "/api/time_entries?include=project%2Ctask&order=created_at%3Aasc&per_page=4&page=1",
                        data: { results: resultsArray("time_entries", [te2Ws11, te1Ws11, te1Ws10, te2Ws10]), time_entries: [te2Ws11, te1Ws11, te1Ws10, te2Ws10], tasks: [], projects: [ws10, ws11] }
            respondWith server, "/api/time_entries?include=project%2Ctask&per_page=4&page=1",
                        data: { results: resultsArray("time_entries", [te1Ws11, te2Ws10, te1Ws10, te2Ws11]), time_entries: [te1Ws11, te2Ws10, te1Ws10, te2Ws11], tasks: [], projects: [ws10, ws11] }
            # Make a server request
            collection1 = manager.loadCollection "time_entries", include: ["project", "task"], order: "updated_at:desc", filters: { project_id: 10 }, page: 1, perPage: 2
            expect(collection1.loaded).toBe false
            server.respond()
            expect(collection1.loaded).toBe true
            expect(collection1.pluck("id")).toEqual [te2Ws10.id, te1Ws10.id] # Show that it came back in the explicit order setup above
            # Make another request, this time handled by the cache.
            collection2 = manager.loadCollection "time_entries", include: ["project", "task"], order: "updated_at:desc", filters: { project_id: 10 }, page: 1, perPage: 2
            expect(collection2.loaded).toBe true

            # Do it again, this time with a different filter.
            collection3 = manager.loadCollection "time_entries", include: ["project", "task"], order: "updated_at:desc", filters: { project_id: 11 }, page: 1, perPage: 2
            expect(collection3.loaded).toBe false
            server.respond()
            expect(collection3.loaded).toBe true
            expect(collection3.pluck("id")).toEqual [te1Ws11.id, te2Ws11.id]
            collection4 = manager.loadCollection "time_entries", include: ["project"], order: "updated_at:desc", filters: { project_id: 11 }, page: 1, perPage: 2
            expect(collection4.loaded).toBe true
            expect(collection4.pluck("id")).toEqual [te1Ws11.id, te2Ws11.id]

            # Do it again, this time with a different order.
            collection5 = manager.loadCollection "time_entries", include: ["project", "task"], order: "created_at:asc", filters: { project_id: 11 } , page: 1, perPage: 2
            expect(collection5.loaded).toBe false
            server.respond()
            expect(collection5.loaded).toBe true
            expect(collection5.pluck("id")).toEqual [te2Ws11.id, te1Ws11.id]
            collection6 = manager.loadCollection "time_entries", include: ["task"], order: "created_at:asc", filters: { project_id: 11 }, page: 1, perPage: 2
            expect(collection6.loaded).toBe true
            expect(collection6.pluck("id")).toEqual [te2Ws11.id, te1Ws11.id]

            # Do it again, this time without a filter.
            collection7 = manager.loadCollection "time_entries", include: ["project", "task"], order: "created_at:asc", page: 1, perPage: 4
            expect(collection7.loaded).toBe false
            server.respond()
            expect(collection7.loaded).toBe true
            expect(collection7.pluck("id")).toEqual [te2Ws11.id, te1Ws11.id, te1Ws10.id, te2Ws10.id]

            # Do it again, this time without an order, so it should use the default (updated_at:desc).
            collection9 = manager.loadCollection "time_entries", include: ["project", "task"], page: 1, perPage: 4
            expect(collection9.loaded).toBe false
            server.respond()
            expect(collection9.loaded).toBe true
            expect(collection9.pluck("id")).toEqual [te1Ws11.id, te2Ws10.id, te1Ws10.id, te2Ws11.id]

    describe "handling of only", ->
      describe "when getting data from the server", ->
        it "returns the requested ids with includes, triggering reset and success", ->
          respondWith server, "/api/time_entries?include=project%2Ctask&only=2",
                      resultsFrom: "time_entries", data: { time_entries: [buildTimeEntry(task_id: null, project_id: 10, id: 2)], tasks: [], projects: [buildProject(id: 10)] }
          spy2 = jasmine.createSpy().and.callFake (collection) ->
            expect(collection.loaded).toBe true
          collection = manager.loadCollection "time_entries", include: ["project", "task"], only: 2, success: spy2
          spy = jasmine.createSpy().and.callFake ->
            expect(collection.loaded).toBe true
            expect(collection.get(2).get('task')).toBeFalsy()
            expect(collection.get(2).get('project').id).toEqual "10"
            expect(collection.length).toEqual 1
          collection.bind "reset", spy
          expect(collection.loaded).toBe false
          server.respond()
          expect(collection.loaded).toBe true
          expect(spy).toHaveBeenCalled()
          expect(spy2).toHaveBeenCalled()

        it "requests all ids even onces that that we already have", ->
          respondWith server, "/api/time_entries?include=project%2Ctask&only=2",
                      resultsFrom: "time_entries", data: { time_entries: [buildTimeEntry(task_id: null, project_id: 10, id: 2)], tasks: [], projects: [buildProject(id: 10)] }
          respondWith server, "/api/time_entries?include=project%2Ctask&only=2%2C3",
                      resultsFrom: "time_entries", data: { time_entries: [buildTimeEntry(task_id: null, project_id: 10, id: 2), buildTimeEntry(task_id: null, project_id: 11, id: 3)], tasks: [], projects: [buildProject(id: 10), buildProject(id: 11)] }

          collection = manager.loadCollection "time_entries", include: ["project", "task"], only: 2
          expect(collection.loaded).toBe false
          server.respond()
          expect(collection.loaded).toBe true
          expect(collection.get(2).get('project').id).toEqual "10"
          collection2 = manager.loadCollection "time_entries", include: ["project", "task"], only: ["2", "3"]
          expect(collection2.loaded).toBe false
          server.respond()
          expect(collection2.loaded).toBe true
          expect(collection2.length).toEqual 2
          expect(collection2.get(2).get('project').id).toEqual "10"
          expect(collection2.get(3).get('project').id).toEqual "11"

        it "doesn't go to the server if it doesn't need to", ->
          respondWith server, "/api/time_entries?include=project%2Ctask&only=2%2C3",
                      resultsFrom: "time_entries", data: { time_entries: [buildTimeEntry(project_id: 10, id: 2, task_id: null), buildTimeEntry(project_id: 11, id: 3)], tasks: [], projects: [buildProject(id: 10), buildProject(id: 11)] }
          collection = manager.loadCollection "time_entries", include: ["project", "task"], only: [2, 3]
          expect(collection.loaded).toBe false
          server.respond()
          expect(collection.loaded).toBe true
          expect(collection.get(2).get('project').id).toEqual "10"
          expect(collection.get(3).get('project').id).toEqual "11"
          expect(collection.length).toEqual 2
          spy = jasmine.createSpy()
          collection2 = manager.loadCollection "time_entries", include: ["project"], only: [2, 3], success: spy
          expect(spy).toHaveBeenCalled()
          expect(collection2.loaded).toBe true
          expect(collection2.get(2).get('project').id).toEqual "10"
          expect(collection2.get(3).get('project').id).toEqual "11"
          expect(collection2.length).toEqual 2

        it "returns an empty collection when passed in an empty array", ->
          timeEntries = [buildTimeEntry(task_id: 2, project_id: 15, id: 1), buildTimeEntry(project_id: 10, id: 2)]
          respondWith server, "/api/time_entries?per_page=20&page=1", resultsFrom: "time_entries", data: { time_entries: timeEntries }
          collection = manager.loadCollection "time_entries", only: []
          expect(collection.loaded).toBe true
          expect(collection.length).toEqual 0

          collection = manager.loadCollection "time_entries", only: null
          server.respond()
          expect(collection.loaded).toBe true
          expect(collection.length).toEqual 2

        it "accepts a success function that gets triggered on cache hit", ->
          respondWith server, "/api/time_entries?include=project%2Ctask&only=2%2C3",
                      resultsFrom: "time_entries", data: { time_entries: [buildTimeEntry(project_id: 10, id: 2, task_id: null), buildTimeEntry(project_id: 11, id: 3, task_id: null)], tasks: [], projects: [buildProject(id: 10), buildProject(id: 11)] }
          manager.loadCollection "time_entries", include: ["project", "task"], only: [2, 3]
          server.respond()
          spy = jasmine.createSpy().and.callFake (collection) ->
            expect(collection.loaded).toBe true
            expect(collection.get(2).get('project').id).toEqual "10"
            expect(collection.get(3).get('project').id).toEqual "11"
          collection2 = manager.loadCollection "time_entries", include: ["project"], only: [2, 3], success: spy
          expect(spy).toHaveBeenCalled()

        it "does go to the server on a repeat request if an association is missing", ->
          respondWith server, "/api/time_entries?include=project&only=2",
                      resultsFrom: "time_entries", data: { time_entries: [buildTimeEntry(project_id: 10, id: 2, task_id: 6)], projects: [buildProject(id: 10)] }
          respondWith server, "/api/time_entries?include=project%2Ctask&only=2",
                      resultsFrom: "time_entries", data: { time_entries: [buildTimeEntry(project_id: 10, id: 2, task_id: 6)], tasks: [buildTask(id: 6)], projects: [buildProject(id: 10)] }
          collection = manager.loadCollection "time_entries", include: ["project"], only: 2
          expect(collection.loaded).toBe false
          server.respond()
          expect(collection.loaded).toBe true
          collection2 = manager.loadCollection "time_entries", include: ["project", "task"], only: 2
          expect(collection2.loaded).toBe false

    describe "disabling caching", ->
      item = null

      beforeEach ->
        item = buildTask()
        respondWith server, "/api/tasks?per_page=20&page=1", resultsFrom: "tasks", data: { tasks: [item] }

      it "goes to server even if we have matching items in cache", ->
        syncSpy = spyOn(Backbone, 'sync')
        collection = manager.loadCollection "tasks", cache: false, only: item.id
        expect(syncSpy).toHaveBeenCalled()

      it "still adds results to the cache", ->
        spy = spyOn(manager.storage('tasks'), 'update')
        collection = manager.loadCollection "tasks", cache: false
        server.respond()
        expect(spy).toHaveBeenCalled()

    describe "types of pagination", ->
      it "prioritizes limit and offset over per page and page", ->
        respondWith server, "/api/time_entries?limit=1&offset=0", resultsFrom: "time_entries", data: { time_entries: [buildTimeEntry()] }
        manager.loadCollection "time_entries", limit: 1, offset: 0, perPage: 5, page: 10
        server.respond()

      it "limits to at least 1 and offset 0", ->
        respondWith server, "/api/time_entries?limit=1&offset=0", resultsFrom: "time_entries", data: { time_entries: [buildTimeEntry()] }
        manager.loadCollection "time_entries", limit: -5, offset: -5
        server.respond()

      it "falls back to per page and page if both limit and offset are not complete", ->
        respondWith server, "/api/time_entries?per_page=5&page=10", resultsFrom: "time_entries", data: { time_entries: [buildTimeEntry()] }
        manager.loadCollection "time_entries", limit: "", offset: "", perPage: 5, page: 10
        server.respond()

        manager.loadCollection "time_entries", limit: "", perPage: 5, page: 10
        server.respond()

        manager.loadCollection "time_entries", offset: "", perPage: 5, page: 10
        server.respond()

    describe "searching", ->
      it 'turns off caching', ->
        spy = spyOn(AbstractLoader.prototype, '_checkCacheForData').and.callThrough()
        collection = manager.loadCollection "tasks", search: "the meaning of life"
        expect(spy).not.toHaveBeenCalled()

      it 'does not overwrite the existing non-search cache', ->
        fakeCache =
          count: 2
          results: [{ key: "task", id: 1 }, { key: "task", id: 2 }]

        loader = manager.loadObject "tasks"
        manager.collections.tasks.cache[loader.loadOptions.cacheKey] = fakeCache
        expect(loader.getCacheObject()).toEqual fakeCache

        searchLoader = manager.loadObject "tasks", search: "foobar"
        searchLoader._updateStorageManagerFromResponse(count: 0, results: [])

        expect(loader.getCacheObject()).toEqual fakeCache

      it "returns the matching items with includes, triggering reset and success", ->
        task = buildTask()
        respondWith server, "/api/tasks?search=go+go+gadget+search&per_page=20&page=1",
                    data: { results: [{key: "tasks", id: task.id}], tasks: [task] }
        spy2 = jasmine.createSpy().and.callFake (collection) ->
          expect(collection.loaded).toBe true
        collection = manager.loadCollection "tasks", search: "go go gadget search", success: spy2
        spy = jasmine.createSpy().and.callFake ->
          expect(collection.loaded).toBe true
        collection.bind "reset", spy
        expect(collection.loaded).toBe false
        server.respond()
        expect(collection.loaded).toBe true
        expect(spy).toHaveBeenCalled()
        expect(spy2).toHaveBeenCalled()

      it 'does not blow up when no results are returned', ->
        respondWith server, "/api/tasks?search=go+go+gadget+search&per_page=20&page=1", data: { results: [], tasks: [] }
        collection = manager.loadCollection "tasks", search: "go go gadget search"
        server.respond()

      it 'acts as if no search options were passed if the search string is blank', ->
        respondWith server, "/api/tasks?per_page=20&page=1", data: { results: [], tasks: [] }
        collection = manager.loadCollection "tasks", search: ""
        server.respond()

    describe 'return values', ->
      it 'adds the jQuery XHR object to the return values if returnValues is passed in', ->
        baseXhr = $.ajax()
        returnValues = {}

        manager.loadCollection "tasks", search: "the meaning of life", returnValues: returnValues
        expect(returnValues.jqXhr).not.toBeUndefined()

        # if it has most of the functions of a jQuery XHR object then it's probably a jQuery XHR object
        jqXhrKeys = ['setRequestHeader', 'getAllResponseHeaders', 'getResponseHeader', 'overrideMimeType', 'abort']

        for functionName in jqXhrKeys
          funct = returnValues.jqXhr[functionName]
          expect(funct).not.toBeUndefined()
          expect(funct.toString()).toEqual(baseXhr[functionName].toString())

  describe 'bootstrap', ->
    task = null

    beforeEach ->
      task = buildTask(title: 'Booting!', description: 'shenanigans')

      responseJson =
        count: 1
        results: [{ key: 'tasks', id: task.id }]
        tasks:
          "#{task.id}": task.attributes

      loadOptions = order: 'the other way', includes: 'foo', filters: { bar: 'baz' }
      manager.bootstrap 'tasks', responseJson, loadOptions

    it 'loads models into the storage manager', ->
      cachedTask = manager.storage('tasks').get(task.id)
      expect(cachedTask).toBeDefined()

      for attribute, value of task.attributes
        expect(cachedTask.get(attribute)).toEqual value

    it 'caches response as it were an actual request', ->
      cache = manager.getCollectionDetails('tasks').cache['the other way|{"bar":"baz"}||||||']
      expect(cache).toBeDefined()

  describe "error handling", ->
    describe "passing in a custom error handler when loading a collection", ->
      it "gets called when there is an error", ->
        customHandler = jasmine.createSpy('customHandler')
        server.respondWith "GET", "/api/time_entries?per_page=20&page=1", [ 401, {"Content-Type": "application/json"}, JSON.stringify({ errors: ["Invalid OAuth 2 Request"]}) ]
        manager.loadCollection('time_entries', error: customHandler)
        server.respond()
        expect(customHandler).toHaveBeenCalled()

      it "should also get called any amount of layers deep", ->
        errorHandler = jasmine.createSpy('errorHandler')
        successHandler = jasmine.createSpy('successHandler')
        taskOne = buildTask(id: 10, sub_task_ids: [12])
        taskOneSub = buildTask(id: 12, parent_id: 10, sub_task_ids: [13], project_id: taskOne.get('workspace_id'))
        respondWith server, "/api/tasks?include=sub_tasks&parents_only=true&per_page=20&page=1", data: { results: resultsArray("tasks", [taskOne]), tasks: resultsObject([taskOne, taskOneSub]) }
        server.respondWith "GET", "/api/tasks?include=sub_tasks&only=12&apply_default_filters=false", [ 401, {"Content-Type": "application/json"}, JSON.stringify({ errors: ["Invalid OAuth 2 Request"]}) ]
        manager.loadCollection("tasks", filters: { parents_only: "true" }, include: [ "sub_tasks": ["sub_tasks"] ], success: successHandler, error: errorHandler)

        expect(successHandler).not.toHaveBeenCalled()
        expect(errorHandler).not.toHaveBeenCalled()
        server.respond()
        server.respond()
        expect(successHandler).not.toHaveBeenCalled()
        expect(errorHandler).toHaveBeenCalled()
        expect(errorHandler.calls.count()).toEqual(1)
