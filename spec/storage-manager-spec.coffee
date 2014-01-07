describe 'Brainstem Storage Manager', ->
  manager = null

  beforeEach ->
    manager = new Brainstem.StorageManager()

  describe 'addCollection and getCollectionDetails', ->
    it "tracks a named collection", ->
      manager.addCollection 'time_entries', App.Collections.TimeEntries
      expect(manager.getCollectionDetails("time_entries").klass).toBe App.Collections.TimeEntries

    it "raises an error if the named collection doesn't exist", ->
      expect(-> manager.getCollectionDetails('foo')).toThrow()

  describe "storage", ->
    beforeEach ->
      manager.addCollection 'time_entries', App.Collections.TimeEntries

    it "accesses a cached collection of the appropriate type", ->
      expect(manager.storage('time_entries') instanceof App.Collections.TimeEntries).toBeTruthy()
      expect(manager.storage('time_entries').length).toBe 0

    it "raises an error if the named collection doesn't exist", ->
      expect(-> manager.storage('foo')).toThrow()

  describe "reset", ->
    it "should clear all storage and sort lengths", ->
      buildAndCacheTask()
      buildAndCacheProject()
      expect(base.data.storage("projects").length).toEqual 1
      expect(base.data.storage("tasks").length).toEqual 1
      base.data.collections["projects"].cache = { "foo": "bar" }
      base.data.reset()
      expect(base.data.collections["projects"].cache).toEqual {}
      expect(base.data.storage("projects").length).toEqual 0
      expect(base.data.storage("tasks").length).toEqual 0

  describe "loadModel", ->
    beforeEach ->
      tasks = [buildTask(id: 2, title: "a task", project_id: 15)]
      projects = [buildProject(id: 15)]
      timeEntries = [buildTimeEntry(id: 1, task_id: 2, project_id: 15, title: "a time entry")]
      respondWith server, "/api/time_entries/1", resultsFrom: "time_entries", data: { time_entries: timeEntries }
      respondWith server, "/api/time_entries/1?include=project%2Ctask", resultsFrom: "time_entries", data: { time_entries: timeEntries, tasks: tasks, projects: projects }

    it "uses a passed in model if present", ->
      existingModel = buildTimeEntry(id: 55)

      newModel = base.data.loadModel "time_entry", existingModel.id, model: existingModel, include: ["project", "task"]
      expect(newModel).toEqual(existingModel)

      newModel = base.data.loadModel "time_entry", existingModel.id, include: ["project", "task"]
      expect(newModel).not.toEqual(existingModel)

    it "creates a new model with the supplied id", ->
      newModel = base.data.loadModel "time_entry", "333"
      expect(newModel.id).toEqual "333"

    xit "calls loadCollection with the model", ->
      spyOn(base.data.dataLoader, 'loadCollection')
      newModel = base.data.loadModel "time_entry", "333"

      expect(base.data.dataLoader.loadCollection).toHaveBeenCalled()
      expect(base.data.dataLoader.loadCollection.mostRecentCall.args[1].model).toEqual newModel

    it "calls Backbone.sync with a model", ->
      spyOn(Backbone, 'sync')
      newModel = base.data.loadModel "time_entry", "333"
      expect(Backbone.sync).toHaveBeenCalledWith 'read', jasmine.any(App.Models.TimeEntry), jasmine.any(Object)

    it "loads a single model from the server, including associations", ->
      model = base.data.loadModel "time_entry", 1, include: ["project", "task"]
      expect(model.loaded).toBe false
      server.respond()
      expect(model.loaded).toBe true
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

      respondWith server, "/api/tasks/#{mainTask.id}?include=assignees%2Csub_tasks%2Cproject", resultsFrom: "tasks", data: { results: resultsArray("tasks", [mainTask]), tasks: resultsObject([mainTask, subTask]), projects: resultsObject([mainProject]), users: resultsObject([mainTaskAssignee]) }
      respondWith server, "/api/tasks?include=assignees&only=#{subTask.id}", resultsFrom: "tasks", data: { results: resultsArray("tasks", [subTask]), tasks: resultsObject([subTask]), users: resultsObject([subTaskAssignee]) }
      respondWith server, "/api/projects?include=time_entries&only=#{mainProject.id}", resultsFrom: "projects", data: { results: resultsArray("projects", [mainProject]), time_entries: resultsObject([timeEntry]), projects: resultsObject([mainProject]) }
      respondWith server, "/api/time_entries?include=task&only=" + timeEntry.id, resultsFrom: "time_entries", data: { results: resultsArray("time_entries", [timeEntry]), time_entries: resultsObject([timeEntry]), tasks: resultsObject([timeTask]) }

      model = base.data.loadModel "task", mainTask.id, include: ["assignees", {"sub_tasks": ["assignees"]}, { "project" : [{ "time_entries": ["task"] }] }]
      server.respond()

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
      spy = spyOn(Brainstem.AbstractLoader.prototype, '_loadFromServer')

      model = base.data.loadModel "task", task.id
      expect(model.attributes).toEqual(task.attributes)
      expect(spy).not.toHaveBeenCalled()

    it "works even when the server returned associations of the same type", ->
      posts = [buildPost(id: 2, reply: true), buildPost(id: 3, reply: true), buildPost(id: 1, reply: false, reply_ids: [2, 3])]
      respondWith server, "/api/posts/1?include=replies", data: { results: [{ key: "posts", id: 1 }], posts: posts }
      model = base.data.loadModel "post", 1, include: ["replies"]
      expect(model.loaded).toBe false
      server.respond()
      expect(model.loaded).toBe true
      expect(model.id).toEqual "1"
      expect(model.get("replies").pluck("id")).toEqual ["2", "3"]

    it "updates associations before the primary model", ->
      events = []
      base.data.storage('time_entries').on "add", -> events.push "time_entries"
      base.data.storage('tasks').on "add", -> events.push "tasks"
      base.data.loadModel "time_entry", 1, include: ["project", "task"]
      server.respond()
      expect(events).toEqual ["tasks", "time_entries"]

    it "triggers changes", ->
      model = base.data.loadModel "time_entry", 1, include: ["project", "task"]
      spy = jasmine.createSpy().andCallFake ->
        expect(model.loaded).toBe true
        expect(model.get("title")).toEqual "a time entry"
        expect(model.get('task').get('title')).toEqual "a task"
        expect(model.get('project').id).toEqual "15"
      model.bind "change", spy
      expect(spy).not.toHaveBeenCalled()
      server.respond()
      expect(spy).toHaveBeenCalled()
      expect(spy.callCount).toEqual 1

    it "accepts a success function", ->
      spy = jasmine.createSpy().andCallFake (model) ->
        expect(model.loaded).toBe true
      model = base.data.loadModel "time_entry", 1, success: spy
      server.respond()
      expect(spy).toHaveBeenCalled()

    it "can disable caching", ->
      spy = spyOn(Brainstem.ModelLoader.prototype, '_checkCacheForData').andCallThrough()
      model = base.data.loadModel "time_entry", 1, cache: false
      expect(spy).not.toHaveBeenCalled()

    it "invokes the error callback when the server responds with a 404", ->
      successSpy = jasmine.createSpy('successSpy')
      errorSpy = jasmine.createSpy('errorSpy')
      respondWith server, "/api/time_entries/1337", data: { results: [] }, status: 404
      base.data.loadModel "time_entry", 1337, success: successSpy, error: errorSpy

      server.respond()
      expect(successSpy).not.toHaveBeenCalled()
      expect(errorSpy).toHaveBeenCalled()

    it "does not trigger loaded until all of the associations are included", ->
      base.data.enableExpectations()

      project = buildProject()
      user = buildUser()

      task = buildTask(title: 'foobar', project_id: project.id)
      task2 = buildTask(project_id: project.id)
      task3 = buildTask(project_id: project.id, assignee_ids: [user.id])

      project.set('task_ids', [task.id, task2.id, task3.id])

      taskExpectation = base.data.stub "tasks", include: ['project': [{ 'tasks': ['assignees'] }]], only: task.id, name: "task", response: (stub) ->
        stub.results = [task]
        stub.associated.project = [project]
        stub.recursive = true

      projectExpectation = base.data.stub "projects", include: ['tasks': ['assignees']], only: project.id, name: "projects", response: (stub) ->
        stub.results = [project]
        stub.associated.tasks = [task, task2, task3]
        stub.recursive = true

      taskWithAssigneesExpectation = base.data.stub "tasks", only: [task.id, task2.id, task3.id], include: ['assignees'], name: "tasks", response: (stub) ->
        stub.results = [task]
        stub.associated.users = [user]

      loadedSpy = jasmine.createSpy('loaded')

      model = buildTask(id: task.id)
      model.on 'loaded', loadedSpy

      base.data.loadModel "task", model.id, model: model, include: ['project': [{ 'tasks': ['assignees'] }]]

      taskExpectation.respond()
      expect(loadedSpy).not.toHaveBeenCalled()

      projectExpectation.respond()
      expect(loadedSpy).not.toHaveBeenCalled()

      taskWithAssigneesExpectation.respond()
      expect(loadedSpy).toHaveBeenCalled()

  describe 'loadCollection', ->
    it "loads a collection of models", ->
      timeEntries = [buildTimeEntry(), buildTimeEntry()]
      respondWith server, "/api/time_entries?per_page=20&page=1", resultsFrom: "time_entries", data: { time_entries: timeEntries }
      collection = base.data.loadCollection "time_entries"
      expect(collection.length).toBe 0
      server.respond()
      expect(collection.length).toBe 2

    it "accepts a success function", ->
      timeEntries = [buildTimeEntry(), buildTimeEntry()]
      respondWith server, "/api/time_entries?per_page=20&page=1", resultsFrom: "time_entries", data: { time_entries: timeEntries }
      spy = jasmine.createSpy().andCallFake (collection) ->
        expect(collection.loaded).toBe true
      collection = base.data.loadCollection "time_entries", success: spy
      server.respond()
      expect(spy).toHaveBeenCalledWith(collection)

    it "saves it's options onto the returned collection", ->
      collection = base.data.loadCollection "time_entries", order: "baz:desc", filters: { bar: 2 }
      expect(collection.lastFetchOptions.order).toEqual "baz:desc"
      expect(collection.lastFetchOptions.filters).toEqual { bar: 2 }
      expect(collection.lastFetchOptions.collection).toBeFalsy()

    describe "passing an optional collection", ->
      it "accepts an optional collection instead of making a new one", ->
        timeEntry = buildTimeEntry()
        respondWith server, "/api/time_entries?per_page=20&page=1", data: { results: [{ key: "time_entries", id: timeEntry.id }], time_entries: [timeEntry] }
        collection = new App.Collections.TimeEntries([buildTimeEntry(), buildTimeEntry()])
        collection.setLoaded true
        base.data.loadCollection "time_entries", collection: collection
        expect(collection.lastFetchOptions.collection).toBeFalsy()
        expect(collection.loaded).toBe false
        expect(collection.length).toEqual 2
        server.respond()
        expect(collection.loaded).toBe true
        expect(collection.length).toEqual 3

      it "can take an optional reset command to reset the collection before using it", ->
        timeEntry = buildTimeEntry()
        respondWith server, "/api/time_entries?per_page=20&page=1", data: { results: [{ key: "time_entries", id: timeEntry.id }], time_entries: [timeEntry] }
        collection = new App.Collections.TimeEntries([buildTimeEntry(), buildTimeEntry()])
        collection.setLoaded true
        spyOn(collection, 'reset').andCallThrough()
        base.data.loadCollection "time_entries", collection: collection, reset: true
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
      collection = base.data.loadCollection "posts", filters: { filter1: true, filter2: false, filter3: "true", filter4: "false", filter5: 2, filter6: "baz" }
      server.respond()

    it "triggers reset", ->
      timeEntry = buildTimeEntry()
      respondWith server, "/api/time_entries?per_page=20&page=1", data: { results: [{ key: "time_entries", id: timeEntry.id}], time_entries: [timeEntry] }
      collection = base.data.loadCollection "time_entries"
      expect(collection.loaded).toBe false
      spy = jasmine.createSpy().andCallFake ->
        expect(collection.loaded).toBe true
      collection.bind "reset", spy
      server.respond()
      expect(spy).toHaveBeenCalled()

    it "ignores count and honors results", ->
      server.respondWith "GET", "/api/time_entries?per_page=20&page=1", [ 200, {"Content-Type": "application/json"}, JSON.stringify(count: 2, results: [{ key: "time_entries", id: 2 }], time_entries: [buildTimeEntry(), buildTimeEntry()]) ]
      collection = base.data.loadCollection "time_entries"
      server.respond()
      expect(collection.length).toEqual(1)

    it "works with an empty response", ->
      exceptionSpy = spyOn(sinon, 'logError').andCallThrough()
      respondWith server, "/api/time_entries?per_page=20&page=1", resultsFrom: "time_entries", data: { time_entries: [] }
      base.data.loadCollection "time_entries"
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
        collection = base.data.loadCollection "time_entries", include: ["project", "task"]
        spy = jasmine.createSpy().andCallFake ->
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
        collection = base.data.loadCollection "posts", include: ["replies"], filters: { parents_only: "true" }
        server.respond()
        expect(collection.pluck("id")).toEqual ["1"]
        expect(collection.get(1).get('replies').pluck("id")).toEqual ["2"]

      describe "fetching multiple levels of associations", ->
        it "seperately requests each layer of associations", ->
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
          respondWith server, "/api/tasks?include=assignees&only=#{taskOneSub.id}%2C#{taskTwoSub.id}", data: { results: resultsArray("tasks", [taskOneSub, taskTwoSub]), tasks: resultsObject([taskOneSubWithAssignees, taskTwoSubWithAssignees]), users: resultsObject([taskOneSubAssignee, taskTwoAssignee]) }
          respondWith server, "/api/projects?include=time_entries&only=#{projectOne.id}%2C#{projectTwo.id}", data: { results: resultsArray("projects", [projectOne, projectTwo]), projects: resultsObject([projectOneWithTimeEntries, projectTwoWithTimeEntries]), time_entries: resultsObject([projectOneTimeEntry]) }
          respondWith server, "/api/time_entries?include=task&only=#{projectOneTimeEntry.id}", data: { results: resultsArray("time_entries", [projectOneTimeEntry]), time_entries: resultsObject([projectOneTimeEntryWithTask]), tasks: resultsObject([projectOneTimeEntryTask]) }

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

          success = jasmine.createSpy().andCallFake checkStructure
          collection = base.data.loadCollection "tasks", filters: { parents_only: "true" }, success: success, include: [
                                                                      "assignees",
                                                                      "project": ["time_entries": "task"],
                                                                      "sub_tasks": ["assignees"]
                                                                    ]
          collection.bind "loaded", checkStructure
          collection.bind "reset", checkStructure
          expect(success).not.toHaveBeenCalled()
          server.respond()
          expect(success).toHaveBeenCalledWith(collection)
          expect(callCount).toEqual 3

      describe "caching", ->
        describe "without ordering", ->
          it "doesn't go to the server when it already has the data", ->
            collection1 = base.data.loadCollection "time_entries", include: ["project", "task"], page: 1, perPage: 2
            server.respond()
            expect(collection1.loaded).toBe true
            expect(collection1.get(1).get('project').id).toEqual "15"
            expect(collection1.get(2).get('project').id).toEqual "10"
            spy = jasmine.createSpy()
            collection2 = base.data.loadCollection "time_entries", include: ["project", "task"], page: 1, perPage: 2, success: spy
            expect(spy).toHaveBeenCalled()
            expect(collection2.loaded).toBe true
            expect(collection2.get(1).get('task').get('title')).toEqual "a task"
            expect(collection2.get(2).get('task')).toBeFalsy()
            expect(collection2.get(1).get('project').id).toEqual "15"
            expect(collection2.get(2).get('project').id).toEqual "10"

          context "using perPage and page", ->
            it "does go to the server when more records are requested than it has previously requested, and remembers previously requested pages", ->
              collection1 = base.data.loadCollection "time_entries", include: ["project", "task"], page: 1, perPage: 2
              server.respond()
              expect(collection1.loaded).toBe true
              collection2 = base.data.loadCollection "time_entries", include: ["project", "task"], page: 2, perPage: 2
              expect(collection2.loaded).toBe false
              server.respond()
              expect(collection2.loaded).toBe true
              collection3 = base.data.loadCollection "time_entries", include: ["project"], page: 1, perPage: 2
              expect(collection3.loaded).toBe true

          context "using limit and offset", ->
            it "does go to the server when more records are requested than it knows about", ->
              timeEntries = [buildTimeEntry(), buildTimeEntry()]
              respondWith server, "/api/time_entries?limit=2&offset=0", resultsFrom: "time_entries", data: { time_entries: timeEntries }
              respondWith server, "/api/time_entries?limit=2&offset=2", resultsFrom: "time_entries", data: { time_entries: timeEntries }

              collection1 = base.data.loadCollection "time_entries", limit: 2, offset: 0
              server.respond()
              expect(collection1.loaded).toBe true
              collection2 = base.data.loadCollection "time_entries", limit: 2, offset: 2
              expect(collection2.loaded).toBe false
              server.respond()
              expect(collection2.loaded).toBe true
              collection3 = base.data.loadCollection "time_entries", limit: 2, offset: 0
              expect(collection3.loaded).toBe true

          it "does go to the server when some associations are missing, when otherwise it would have the data", ->
            collection1 = base.data.loadCollection "time_entries", include: ["project"], page: 1, perPage: 2
            server.respond()
            expect(collection1.loaded).toBe true
            collection2 = base.data.loadCollection "time_entries", include: ["project", "task"], page: 1, perPage: 2
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
            collection = base.data.loadCollection "time_entries", order: "created_at:asc", page: 1, perPage: 2
            server.respond()
            expect(collection.pluck("id")).toEqual [te2Ws11.id, te1Ws11.id]
            base.data.loadCollection "time_entries", collection: collection, order: "created_at:asc", page: 2, perPage: 2
            server.respond()
            expect(collection.pluck("id")).toEqual [te2Ws11.id, te1Ws11.id, te1Ws10.id, te2Ws10.id]

          it "does not re-sort the results", ->
            respondWith server, "/api/time_entries?order=created_at%3Adesc&per_page=2&page=1", data: { results: resultsArray("time_entries", [te2Ws11, te1Ws11]), time_entries: [te1Ws11, te2Ws11] }
            # it's really created_at:asc
            collection = base.data.loadCollection "time_entries", order: "created_at:desc", page: 1, perPage: 2
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
            collection1 = base.data.loadCollection "time_entries", include: ["project", "task"], order: "updated_at:desc", filters: { project_id: 10 }, page: 1, perPage: 2
            expect(collection1.loaded).toBe false
            server.respond()
            expect(collection1.loaded).toBe true
            expect(collection1.pluck("id")).toEqual [te2Ws10.id, te1Ws10.id] # Show that it came back in the explicit order setup above
            # Make another request, this time handled by the cache.
            collection2 = base.data.loadCollection "time_entries", include: ["project", "task"], order: "updated_at:desc", filters: { project_id: 10 }, page: 1, perPage: 2
            expect(collection2.loaded).toBe true

            # Do it again, this time with a different filter.
            collection3 = base.data.loadCollection "time_entries", include: ["project", "task"], order: "updated_at:desc", filters: { project_id: 11 }, page: 1, perPage: 2
            expect(collection3.loaded).toBe false
            server.respond()
            expect(collection3.loaded).toBe true
            expect(collection3.pluck("id")).toEqual [te1Ws11.id, te2Ws11.id]
            collection4 = base.data.loadCollection "time_entries", include: ["project"], order: "updated_at:desc", filters: { project_id: 11 }, page: 1, perPage: 2
            expect(collection4.loaded).toBe true
            expect(collection4.pluck("id")).toEqual [te1Ws11.id, te2Ws11.id]

            # Do it again, this time with a different order.
            collection5 = base.data.loadCollection "time_entries", include: ["project", "task"], order: "created_at:asc", filters: { project_id: 11 } , page: 1, perPage: 2
            expect(collection5.loaded).toBe false
            server.respond()
            expect(collection5.loaded).toBe true
            expect(collection5.pluck("id")).toEqual [te2Ws11.id, te1Ws11.id]
            collection6 = base.data.loadCollection "time_entries", include: ["task"], order: "created_at:asc", filters: { project_id: 11 }, page: 1, perPage: 2
            expect(collection6.loaded).toBe true
            expect(collection6.pluck("id")).toEqual [te2Ws11.id, te1Ws11.id]

            # Do it again, this time without a filter.
            collection7 = base.data.loadCollection "time_entries", include: ["project", "task"], order: "created_at:asc", page: 1, perPage: 4
            expect(collection7.loaded).toBe false
            server.respond()
            expect(collection7.loaded).toBe true
            expect(collection7.pluck("id")).toEqual [te2Ws11.id, te1Ws11.id, te1Ws10.id, te2Ws10.id]

            # Do it again, this time without an order, so it should use the default (updated_at:desc).
            collection9 = base.data.loadCollection "time_entries", include: ["project", "task"], page: 1, perPage: 4
            expect(collection9.loaded).toBe false
            server.respond()
            expect(collection9.loaded).toBe true
            expect(collection9.pluck("id")).toEqual [te1Ws11.id, te2Ws10.id, te1Ws10.id, te2Ws11.id]

    describe "handling of only", ->
      describe "when getting data from the server", ->
        it "returns the requested ids with includes, triggering reset and success", ->
          respondWith server, "/api/time_entries?include=project%2Ctask&only=2",
                      resultsFrom: "time_entries", data: { time_entries: [buildTimeEntry(task_id: null, project_id: 10, id: 2)], tasks: [], projects: [buildProject(id: 10)] }
          spy2 = jasmine.createSpy().andCallFake (collection) ->
            expect(collection.loaded).toBe true
          collection = base.data.loadCollection "time_entries", include: ["project", "task"], only: 2, success: spy2
          spy = jasmine.createSpy().andCallFake ->
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

        it "only requests ids that we don't already have", ->
          respondWith server, "/api/time_entries?include=project%2Ctask&only=2",
                      resultsFrom: "time_entries", data: { time_entries: [buildTimeEntry(task_id: null, project_id: 10, id: 2)], tasks: [], projects: [buildProject(id: 10)] }
          respondWith server, "/api/time_entries?include=project%2Ctask&only=3",
                      resultsFrom: "time_entries", data: { time_entries: [buildTimeEntry(task_id: null, project_id: 11, id: 3)], tasks: [], projects: [buildProject(id: 11)] }

          collection = base.data.loadCollection "time_entries", include: ["project", "task"], only: 2
          expect(collection.loaded).toBe false
          server.respond()
          expect(collection.loaded).toBe true
          expect(collection.get(2).get('project').id).toEqual "10"
          collection2 = base.data.loadCollection "time_entries", include: ["project", "task"], only: ["2", "3"]
          expect(collection2.loaded).toBe false
          server.respond()
          expect(collection2.loaded).toBe true
          expect(collection2.length).toEqual 2
          expect(collection2.get(2).get('project').id).toEqual "10"
          expect(collection2.get(3).get('project').id).toEqual "11"

        it "does request ids from the server again when they don't have all associations loaded yet", ->
          respondWith server, "/api/time_entries?include=project&only=2",
                      resultsFrom: "time_entries", data: { time_entries: [buildTimeEntry(project_id: 10, id: 2, task_id: 5)], projects: [buildProject(id: 10)] }
          respondWith server, "/api/time_entries?include=project%2Ctask&only=2",
                      resultsFrom: "time_entries", data: { time_entries: [buildTimeEntry(project_id: 10, id: 2, task_id: 5)], tasks: [buildTask(id: 5)], projects: [buildProject(id: 10)] }
          respondWith server, "/api/time_entries?include=project%2Ctask&only=3",
                      resultsFrom: "time_entries", data: { time_entries: [buildTimeEntry(project_id: 11, id: 3, task_id: null)], tasks: [], projects: [buildProject(id: 11)] }

          base.data.loadCollection "time_entries", include: ["project"], only: 2
          server.respond()
          base.data.loadCollection "time_entries", include: ["project", "task"], only: 3
          server.respond()
          collection2 = base.data.loadCollection "time_entries", include: ["project", "task"], only: [2, 3]
          expect(collection2.loaded).toBe false
          server.respond()
          expect(collection2.loaded).toBe true
          expect(collection2.get(2).get('task').id).toEqual "5"
          expect(collection2.length).toEqual 2

        it "doesn't go to the server if it doesn't need to", ->
          respondWith server, "/api/time_entries?include=project%2Ctask&only=2%2C3",
                      resultsFrom: "time_entries", data: { time_entries: [buildTimeEntry(project_id: 10, id: 2, task_id: null), buildTimeEntry(project_id: 11, id: 3)], tasks: [], projects: [buildProject(id: 10), buildProject(id: 11)] }
          collection = base.data.loadCollection "time_entries", include: ["project", "task"], only: [2, 3]
          expect(collection.loaded).toBe false
          server.respond()
          expect(collection.loaded).toBe true
          expect(collection.get(2).get('project').id).toEqual "10"
          expect(collection.get(3).get('project').id).toEqual "11"
          expect(collection.length).toEqual 2
          spy = jasmine.createSpy()
          collection2 = base.data.loadCollection "time_entries", include: ["project"], only: [2, 3], success: spy
          expect(spy).toHaveBeenCalled()
          expect(collection2.loaded).toBe true
          expect(collection2.get(2).get('project').id).toEqual "10"
          expect(collection2.get(3).get('project').id).toEqual "11"
          expect(collection2.length).toEqual 2

        it "returns an empty collection when passed in an empty array", ->
          timeEntries = [buildTimeEntry(task_id: 2, project_id: 15, id: 1), buildTimeEntry(project_id: 10, id: 2)]
          respondWith server, "/api/time_entries?per_page=20&page=1", resultsFrom: "time_entries", data: { time_entries: timeEntries }
          collection = base.data.loadCollection "time_entries", only: []
          expect(collection.loaded).toBe true
          expect(collection.length).toEqual 0

          collection = base.data.loadCollection "time_entries", only: null
          server.respond()
          expect(collection.loaded).toBe true
          expect(collection.length).toEqual 2

        it "accepts a success function that gets triggered on cache hit", ->
          respondWith server, "/api/time_entries?include=project%2Ctask&only=2%2C3",
                      resultsFrom: "time_entries", data: { time_entries: [buildTimeEntry(project_id: 10, id: 2, task_id: null), buildTimeEntry(project_id: 11, id: 3, task_id: null)], tasks: [], projects: [buildProject(id: 10), buildProject(id: 11)] }
          base.data.loadCollection "time_entries", include: ["project", "task"], only: [2, 3]
          server.respond()
          spy = jasmine.createSpy().andCallFake (collection) ->
            expect(collection.loaded).toBe true
            expect(collection.get(2).get('project').id).toEqual "10"
            expect(collection.get(3).get('project').id).toEqual "11"
          collection2 = base.data.loadCollection "time_entries", include: ["project"], only: [2, 3], success: spy
          expect(spy).toHaveBeenCalled()

        it "does not cache only queries", ->
          respondWith server, "/api/time_entries?include=project%2Ctask&only=2%2C3",
                      resultsFrom: "time_entries", data: { time_entries: [buildTimeEntry(project_id: 10, id: 2, task_id: null), buildTimeEntry(project_id: 11, id: 3, task_id: null)], tasks: [], projects: [buildProject(id: 10), buildProject(id: 11)] }
          collection = base.data.loadCollection "time_entries", include: ["project", "task"], only: [2, 3]
          expect(Object.keys base.data.getCollectionDetails("time_entries")["cache"]).toEqual []
          server.respond()
          expect(Object.keys base.data.getCollectionDetails("time_entries")["cache"]).toEqual []

        it "does go to the server on a repeat request if an association is missing", ->
          respondWith server, "/api/time_entries?include=project&only=2",
                      resultsFrom: "time_entries", data: { time_entries: [buildTimeEntry(project_id: 10, id: 2, task_id: 6)], projects: [buildProject(id: 10)] }
          respondWith server, "/api/time_entries?include=project%2Ctask&only=2",
                      resultsFrom: "time_entries", data: { time_entries: [buildTimeEntry(project_id: 10, id: 2, task_id: 6)], tasks: [buildTask(id: 6)], projects: [buildProject(id: 10)] }
          collection = base.data.loadCollection "time_entries", include: ["project"], only: 2
          expect(collection.loaded).toBe false
          server.respond()
          expect(collection.loaded).toBe true
          collection2 = base.data.loadCollection "time_entries", include: ["project", "task"], only: 2
          expect(collection2.loaded).toBe false

    describe "disabling caching", ->
      item = null

      beforeEach ->
        item = buildTask()
        respondWith server, "/api/tasks?per_page=20&page=1", resultsFrom: "tasks", data: { tasks: [item] }

      it "goes to server even if we have matching items in cache", ->
        syncSpy = spyOn(Backbone, 'sync')
        collection = base.data.loadCollection "tasks", cache: false, only: item.id
        expect(syncSpy).toHaveBeenCalled()

      it "still adds results to the cache", ->
        spy = spyOn(base.data.storage('tasks'), 'update')
        collection = base.data.loadCollection "tasks", cache: false
        server.respond()
        expect(spy).toHaveBeenCalled()

    describe "types of pagination", ->
      it "prioritizes limit and offset over per page and page", ->
        respondWith server, "/api/time_entries?limit=1&offset=0", resultsFrom: "time_entries", data: { time_entries: [buildTimeEntry()] }
        base.data.loadCollection "time_entries", limit: 1, offset: 0, perPage: 5, page: 10
        server.respond()

      it "limits to at least 1 and offset 0", ->
        respondWith server, "/api/time_entries?limit=1&offset=0", resultsFrom: "time_entries", data: { time_entries: [buildTimeEntry()] }
        base.data.loadCollection "time_entries", limit: -5, offset: -5
        server.respond()

      it "falls back to per page and page if both limit and offset are not complete", ->
        respondWith server, "/api/time_entries?per_page=5&page=10", resultsFrom: "time_entries", data: { time_entries: [buildTimeEntry()] }
        base.data.loadCollection "time_entries", limit: "", offset: "", perPage: 5, page: 10
        server.respond()

        base.data.loadCollection "time_entries", limit: "", perPage: 5, page: 10
        server.respond()

        base.data.loadCollection "time_entries", offset: "", perPage: 5, page: 10
        server.respond()

    describe "searching", ->
      it 'turns off caching', ->
        spy = spyOn(Brainstem.AbstractLoader.prototype, '_checkCacheForData').andCallThrough()
        collection = base.data.loadCollection "tasks", search: "the meaning of life"
        expect(spy).not.toHaveBeenCalled()

      it "returns the matching items with includes, triggering reset and success", ->
        task = buildTask()
        respondWith server, "/api/tasks?per_page=20&page=1&search=go+go+gadget+search",
                    data: { results: [{key: "tasks", id: task.id}], tasks: [task] }
        spy2 = jasmine.createSpy().andCallFake (collection) ->
          expect(collection.loaded).toBe true
        collection = base.data.loadCollection "tasks", search: "go go gadget search", success: spy2
        spy = jasmine.createSpy().andCallFake ->
          expect(collection.loaded).toBe true
        collection.bind "reset", spy
        expect(collection.loaded).toBe false
        server.respond()
        expect(collection.loaded).toBe true
        expect(spy).toHaveBeenCalled()
        expect(spy2).toHaveBeenCalled()

      it 'does not blow up when no results are returned', ->
        respondWith server, "/api/tasks?per_page=20&page=1&search=go+go+gadget+search", data: { results: [], tasks: [] }
        collection = base.data.loadCollection "tasks", search: "go go gadget search"
        server.respond()

      it 'acts as if no search options were passed if the search string is blank', ->
        respondWith server, "/api/tasks?per_page=20&page=1", data: { results: [], tasks: [] }
        collection = base.data.loadCollection "tasks", search: ""
        server.respond()

    describe 'return values', ->
      it 'adds the jQuery XHR object to the return values if returnValues is passed in', ->
        baseXhr = $.ajax()
        returnValues = {}

        base.data.loadCollection "tasks", search: "the meaning of life", returnValues: returnValues
        expect(returnValues.jqXhr).not.toBeUndefined()

        # if it has most of the functions of a jQuery XHR object then it's probably a jQuery XHR object
        jqXhrKeys = ['setRequestHeader', 'getAllResponseHeaders', 'getResponseHeader', 'overrideMimeType', 'abort']

        for functionName in jqXhrKeys
          funct = returnValues.jqXhr[functionName]
          expect(funct).not.toBeUndefined()
          expect(funct.toString()).toEqual(baseXhr[functionName].toString())

  describe "createNewCollection", ->
    it "makes a new collection of the appropriate type", ->
      expect(base.data.createNewCollection("tasks", [buildTask(), buildTask()]) instanceof App.Collections.Tasks).toBe true

    it "can accept a 'loaded' flag", ->
      collection = base.data.createNewCollection("tasks", [buildTask(), buildTask()])
      expect(collection.loaded).toBe false
      collection = base.data.createNewCollection("tasks", [buildTask(), buildTask()], loaded: true)
      expect(collection.loaded).toBe true

  describe "_countRequiredServerRequests", ->
    xit "should count the number of loads needed to get the date", ->
      expect(base.data.dataLoader._countRequiredServerRequests(['a'])).toEqual 1
      expect(base.data.dataLoader._countRequiredServerRequests(['a', 'b', 'c': []])).toEqual 1
      expect(base.data.dataLoader._countRequiredServerRequests([{'a': ['d']}, 'b', 'c': ['e']])).toEqual 3
      expect(base.data.dataLoader._countRequiredServerRequests([{'a': ['d']}, 'b', 'c': ['e': []]])).toEqual 3
      expect(base.data.dataLoader._countRequiredServerRequests([{'a': ['d']}, 'b', 'c': ['e': ['f']]])).toEqual 4
      expect(base.data.dataLoader._countRequiredServerRequests([{'a': ['d']}, 'b', 'c': ['e': ['f', 'g': ['h']]]])).toEqual 5
      expect(base.data.dataLoader._countRequiredServerRequests([{'a': ['d': ['h']]}, { 'b':['g'] }, 'c': ['e': ['f', 'i']]])).toEqual 6

  describe "error handling", ->
    describe "setting a storage manager default error handler", ->
      it "allows an error interceptor to be set on construction", ->
        interceptor = (handler, modelOrCollection, options, jqXHR, requestParams) -> 5
        manager = new Brainstem.StorageManager(errorInterceptor: interceptor)
        expect(manager.errorInterceptor).toEqual interceptor

      it "allows an error interceptor to be set later", ->
        spy = jasmine.createSpy()
        base.data.setErrorInterceptor (handler, modelOrCollection, options, jqXHR) -> spy(modelOrCollection, jqXHR)
        server.respondWith "GET", "/api/time_entries?per_page=20&page=1", [ 401, {"Content-Type": "application/json"}, JSON.stringify({ errors: ["Invalid OAuth 2 Request"]}) ]
        base.data.loadCollection 'time_entries'
        server.respond()
        expect(spy).toHaveBeenCalled()

    describe "passing in a custom error handler when loading a collection", ->
      it "gets called when there is an error", ->
        customHandler = jasmine.createSpy('customHandler')
        server.respondWith "GET", "/api/time_entries?per_page=20&page=1", [ 401, {"Content-Type": "application/json"}, JSON.stringify({ errors: ["Invalid OAuth 2 Request"]}) ]
        base.data.loadCollection('time_entries', error: customHandler)
        server.respond()
        expect(customHandler).toHaveBeenCalled()

      it "should also get called any amount of layers deep", ->
        errorHandler = jasmine.createSpy('errorHandler')
        successHandler = jasmine.createSpy('successHandler')
        taskOne = buildTask(id: 10, sub_task_ids: [12])
        taskOneSub = buildTask(id: 12, parent_id: 10, sub_task_ids: [13], project_id: taskOne.get('workspace_id'))
        respondWith server, "/api/tasks?include=sub_tasks&parents_only=true&per_page=20&page=1", data: { results: resultsArray("tasks", [taskOne]), tasks: resultsObject([taskOne, taskOneSub]) }
        server.respondWith "GET", "/api/tasks?include=sub_tasks&only=12", [ 401, {"Content-Type": "application/json"}, JSON.stringify({ errors: ["Invalid OAuth 2 Request"]}) ]
        base.data.loadCollection("tasks", filters: { parents_only: "true" }, include: [ "sub_tasks": ["sub_tasks"] ], success: successHandler, error: errorHandler)

        expect(successHandler).not.toHaveBeenCalled()
        expect(errorHandler).not.toHaveBeenCalled()
        server.respond()
        expect(successHandler).not.toHaveBeenCalled()
        expect(errorHandler).toHaveBeenCalled()
        expect(errorHandler.callCount).toEqual(1)

    describe "when no storage manager error interceptor is given", ->
      it "has a default error interceptor", ->
        manager = new Brainstem.StorageManager()
        expect(manager.errorInterceptor).not.toBeUndefined()

      it "does nothing on unhandled errors", ->
        spyOn(sinon, 'logError').andCallThrough()
        server.respondWith "GET", "/api/time_entries?per_page=20&page=1", [ 401, {"Content-Type": "application/json"}, JSON.stringify({ errors: ["Invalid OAuth 2 Request"]}) ]
        base.data.loadCollection 'time_entries'
        server.respond()
        expect(sinon.logError).not.toHaveBeenCalled()
