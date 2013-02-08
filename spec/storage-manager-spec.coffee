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
      createTask()
      createProject()
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
      respondWith server, "/api/time_entries?only=1", resultsFrom: "time_entries", data: { time_entries: timeEntries }
      respondWith server, "/api/time_entries?include=project%3Btask&only=1", resultsFrom: "time_entries", data: { time_entries: timeEntries, tasks: tasks, projects: projects }

    it "loads a single model from the server, including associations", ->
      model = base.data.loadModel "time_entry", 1, include: ["project", "task"]
      expect(model.loaded).toBe false
      server.respond()
      expect(model.loaded).toBe true
      expect(model.id).toEqual 1
      expect(model.get("title")).toEqual "a time entry"
      expect(model.get('task').get('title')).toEqual "a task"
      expect(model.get('project').id).toEqual 15

    it "works even when the server returned associations of the same type", ->
      posts = [buildPost(id: 2, reply: true), buildPost(id: 3, reply: true), buildPost(id: 1, reply: false, reply_ids: [2, 3])]
      respondWith server, "/api/posts?include=replies&only=1", data: { results: [["posts", 1]], posts: posts }
      model = base.data.loadModel "post", 1, include: ["replies"]
      expect(model.loaded).toBe false
      server.respond()
      expect(model.loaded).toBe true
      expect(model.id).toEqual 1
      expect(model.get("replies").pluck("id")).toEqual [2, 3]

    it "triggers changes", ->
      model = base.data.loadModel "time_entry", 1, include: ["project", "task"]
      spy = jasmine.createSpy().andCallFake ->
        expect(model.loaded).toBe true
        expect(model.get("title")).toEqual "a time entry"
        expect(model.get('task').get('title')).toEqual "a task"
        expect(model.get('project').id).toEqual 15
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

    it "can disbale caching", ->
      spy = spyOn(base.data, 'loadCollection')
      model = base.data.loadModel "time_entry", 1, cache: false
      expect(spy.mostRecentCall.args[1]['cache']).toBe(false)

  describe 'loadCollection', ->
    it "loads a collection of models", ->
      timeEntries = [buildTimeEntry(), buildTimeEntry()]
      respondWith server, "/api/time_entries?per_page=20&page=1", data: { results: resultsArray("time_entries", timeEntries), time_entries: timeEntries }
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
      collection = base.data.loadCollection "time_entries", order: "baz:desc", filters: "bar:2"
      expect(collection.lastFetchOptions.order).toEqual "baz:desc"
      expect(collection.lastFetchOptions.filters).toEqual "bar:2"
      expect(collection.lastFetchOptions.collection).toBeFalsy()

    describe "passing an optional collection", ->
      it "accepts an optional collection instead of making a new one", ->
        timeEntry = buildTimeEntry()
        respondWith server, "/api/time_entries?per_page=20&page=1", data: { results: [["time_entries", timeEntry.id]], time_entries: [timeEntry] }
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
        respondWith server, "/api/time_entries?per_page=20&page=1", data: { results: [["time_entries", timeEntry.id]], time_entries: [timeEntry] }
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

    it "triggers reset", ->
      timeEntry = buildTimeEntry()
      respondWith server, "/api/time_entries?per_page=20&page=1", data: { results: [["time_entries", timeEntry.id]], time_entries: [timeEntry] }
      collection = base.data.loadCollection "time_entries"
      expect(collection.loaded).toBe false
      spy = jasmine.createSpy().andCallFake ->
        expect(collection.loaded).toBe true
      collection.bind "reset", spy
      server.respond()
      expect(spy).toHaveBeenCalled()

    describe "fetching of associations", ->
      json = null

      beforeEach ->
        tasks = [buildTask(id: 2, title: "a task")]
        projects = [buildProject(id: 15), buildProject(id: 10)]
        timeEntries = [buildTimeEntry(task_id: 2, project_id: 15, id: 1), buildTimeEntry(task_id: null, project_id: 10, id: 2)]

        respondWith server, /\/api\/time_entries\?include=project%3Btask&per_page=\d+&page=\d+/, data: { results: resultsArray("time_entries", timeEntries), time_entries: timeEntries, tasks: tasks, projects: projects }
        respondWith server, /\/api\/time_entries\?include=project&per_page=\d+&page=\d+/, data: { results: resultsArray("time_entries", timeEntries), time_entries: timeEntries, projects: projects }

      it "loads collections that should be included", ->
        collection = base.data.loadCollection "time_entries", include: ["project", "task"]
        spy = jasmine.createSpy().andCallFake ->
          expect(collection.loaded).toBe true
          expect(collection.get(1).get('task').get('title')).toEqual "a task"
          expect(collection.get(2).get('task')).toBeFalsy()
          expect(collection.get(1).get('project').id).toEqual 15
          expect(collection.get(2).get('project').id).toEqual 10
        collection.bind "reset", spy
        expect(collection.loaded).toBe false
        server.respond()
        expect(collection.loaded).toBe true
        expect(spy).toHaveBeenCalled()

      it "applies filters when loading collections from the server (so that associations of the same type as the primary can be handled- posts with replies; tasks with subtasks, etc.)", ->
        posts = [buildPost(project_id: 15, id: 1, reply_ids: [2]), buildPost(project_id: 15, id: 2, subject_id: 1, reply: true)]
        respondWith server, "/api/posts?include=replies&filters=parents_only%3Atrue&per_page=20&page=1", data: { results: [["posts", 1]], posts: posts }
        collection = base.data.loadCollection "posts", include: ["replies"], filters: "parents_only:true"
        server.respond()
        expect(collection.pluck("id")).toEqual [1]
        expect(collection.get(1).get('replies').pluck("id")).toEqual [2]

      describe "fetching multiple levels of associations", ->
        # We cannot have default filters that restrict the dataset.  At least not for only queries.
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
          taskOne = buildTask(id: 10, project_id: projectOne.id, assignee_ids: [taskOneAssignee.id], sub_task_ids: [taskOneSub])
          taskTwo = buildTask(id: 11, project_id: projectTwo.id, assignee_ids: [taskTwoAssignee.id], sub_task_ids: [taskTwoSub])
          respondWith server, "/api/tasks.json?include=assignees%3Bproject%3Bsub_tasks&filters=parents_only%3Atrue&per_page=20&page=1", data: { results: resultsArray("tasks", [taskOne, taskTwo]), tasks: [taskOne, taskTwo, taskOneSub, taskTwoSub], users: [taskOneAssignee, taskTwoAssignee], projects: [projectOne, projectTwo] }
          respondWith server, "/api/tasks.json?include=assignees&only=#{taskOneSub.id}%2C#{taskTwoSub.id}", data: { results: resultsArray("tasks", [taskOneSub, taskTwoSub]), tasks: [taskOneSubWithAssignees, taskTwoSubWithAssignees], users: [taskOneSubAssignee, taskTwoAssignee] }
          respondWith server, "/api/projects?include=time_entries&only=#{projectOne.id}%2C#{projectTwo.id}", data: { results: resultsArray("projects", [projectOne, projectTwo]), projects: [projectOneWithTimeEntries, projectTwoWithTimeEntries], time_entries: [projectOneTimeEntry] }
          respondWith server, "/api/time_entries?include=task&only=#{projectOneTimeEntry.id}", data: { results: resultsArray("time_entries", [projectOneTimeEntry]), time_entries: [projectOneTimeEntryWithTask], tasks: [projectOneTimeEntryTask] }
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
          collection = base.data.loadCollection "tasks", filters: "parents_only:true", success: success, include: [
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
            expect(collection1.get(1).get('project').id).toEqual 15
            expect(collection1.get(2).get('project').id).toEqual 10
            spy = jasmine.createSpy()
            collection2 = base.data.loadCollection "time_entries", include: ["project", "task"], page: 1, perPage: 2, success: spy
            expect(spy).toHaveBeenCalled()
            expect(collection2.loaded).toBe true
            expect(collection2.get(1).get('task').get('title')).toEqual "a task"
            expect(collection2.get(2).get('task')).toBeFalsy()
            expect(collection2.get(1).get('project').id).toEqual 15
            expect(collection2.get(2).get('project').id).toEqual 10

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

          it "cuts pages correctly in the client", ->
            respondWith server, "/api/time_entries?order=created_at%3Aasc&per_page=2&page=1", data: { results: resultsArray("time_entries", [te2Ws11, te1Ws11]), time_entries: [te2Ws11, te1Ws11] }
            respondWith server, "/api/time_entries?order=created_at%3Aasc&per_page=2&page=2", data: { results: resultsArray("time_entries", [te1Ws10, te2Ws10]), time_entries: [te1Ws10, te2Ws10] }
            collection = base.data.loadCollection "time_entries", order: "created_at:asc", page: 1, perPage: 2
            server.respond()
            expect(collection.pluck("id")).toEqual [te2Ws11.id, te1Ws11.id]
            base.data.loadCollection "time_entries", collection: collection, order: "created_at:asc", page: 2, perPage: 2
            server.respond()
            expect(collection.pluck("id")).toEqual [te2Ws11.id, te1Ws11.id, te1Ws10.id, te2Ws10.id]

          it "seperately caches data requested by different sort orders and filters", ->
            server.responses = []
            respondWith server, "/api/time_entries?include=project%3Btask&order=updated_at%3Adesc&filters=project_id%3A10&per_page=2&page=1",
                        data: { results: resultsArray("time_entries", [te2Ws10, te1Ws10]), time_entries: [te2Ws10, te1Ws10], tasks: [], projects: [ws10] }
            respondWith server, "/api/time_entries?include=project%3Btask&order=updated_at%3Adesc&filters=project_id%3A11&per_page=2&page=1",
                        data: { results: resultsArray("time_entries", [te1Ws11, te2Ws11]), time_entries: [te1Ws11, te2Ws11], tasks: [], projects: [ws11] }
            respondWith server, "/api/time_entries?include=project%3Btask&order=created_at%3Aasc&filters=project_id%3A11&per_page=2&page=1",
                        data: { results: resultsArray("time_entries", [te2Ws11, te1Ws11]), time_entries: [te2Ws11, te1Ws11], tasks: [], projects: [ws11] }
            respondWith server, "/api/time_entries?include=project%3Btask&order=created_at%3Aasc&per_page=4&page=1",
                        data: { results: resultsArray("time_entries", [te2Ws11, te1Ws11, te1Ws10, te2Ws10]), time_entries: [te2Ws11, te1Ws11, te1Ws10, te2Ws10], tasks: [], projects: [ws10, ws11] }
            respondWith server, "/api/time_entries?include=project%3Btask&per_page=4&page=1",
                        data: { results: resultsArray("time_entries", [te1Ws11, te2Ws10, te1Ws10, te2Ws11]), time_entries: [te1Ws11, te2Ws10, te1Ws10, te2Ws11], tasks: [], projects: [ws10, ws11] }
            # Make a server request
            collection1 = base.data.loadCollection "time_entries", include: ["project", "task"], order: "updated_at:desc", filters: ["project_id:10"], page: 1, perPage: 2
            expect(collection1.loaded).toBe false
            server.respond()
            expect(collection1.loaded).toBe true
            expect(collection1.pluck("id")).toEqual [te2Ws10.id, te1Ws10.id] # Show that it came back in the explicit order setup above
#            # Make another request, this time handled by the cache.
            collection2 = base.data.loadCollection "time_entries", include: ["project", "task"], order: "updated_at:desc", filters: ["project_id:10"], page: 1, perPage: 2
            expect(collection2.loaded).toBe true
#            expect(collection2.pluck("id")).toEqual [te2Ws10.id, te1Ws10.id] # Show that it also came back in the correct order.
#
#            # Do it again, this time with a different filter.
#            collection3 = base.data.loadCollection "time_entries", include: ["project", "task"], order: "updated_at:desc", filters: ["project_id:11"], page: 1, perPage: 2
#            expect(collection3.loaded).toBe false
#            server.respond()
#            expect(collection3.loaded).toBe true
#            expect(collection3.pluck("id")).toEqual [te1Ws11.id, te2Ws11.id]
#            collection4 = base.data.loadCollection "time_entries", include: ["project"], order: "updated_at:desc", filters: ["project_id:11"], page: 1, perPage: 2
#            expect(collection4.loaded).toBe true
#            expect(collection4.pluck("id")).toEqual [te1Ws11.id, te2Ws11.id]
#
#            # Do it again, this time with a different order.
#            collection5 = base.data.loadCollection "time_entries", include: ["project", "task"], order: "created_at:asc", filters: ["project_id:11"], page: 1, perPage: 2
#            expect(collection5.loaded).toBe false
#            server.respond()
#            expect(collection5.loaded).toBe true
#            expect(collection5.pluck("id")).toEqual [te2Ws11.id, te1Ws11.id]
#            collection6 = base.data.loadCollection "time_entries", include: ["task"], order: "created_at:asc", filters: ["project_id:11"], page: 1, perPage: 2
#            expect(collection6.loaded).toBe true
#            expect(collection6.pluck("id")).toEqual [te2Ws11.id, te1Ws11.id]
#
#            # Do it again, this time without a filter.
#            collection7 = base.data.loadCollection "time_entries", include: ["project", "task"], order: "created_at:asc", page: 1, perPage: 4
#            expect(collection7.loaded).toBe false
#            server.respond()
#            expect(collection7.loaded).toBe true
#            expect(collection7.pluck("id")).toEqual [te2Ws11.id, te1Ws11.id, te1Ws10.id, te2Ws10.id]
#
#            # Do it again, this time without an order, so it should use the default (updated_at:desc).
#            collection9 = base.data.loadCollection "time_entries", include: ["project", "task"], page: 1, perPage: 4
#            expect(collection9.loaded).toBe false
#            server.respond()
#            expect(collection9.loaded).toBe true
#            expect(collection9.pluck("id")).toEqual [te1Ws11.id, te2Ws10.id, te1Ws10.id, te2Ws11.id]

    describe "handling of only", ->
      describe "when getting data from the server", ->
        it "returns the requested ids with includes, triggering reset and success", ->
          respondWith server, "/api/time_entries?include=project%3Btask&only=2",
                      data: { results: [["time_entries", 2]], time_entries: [buildTimeEntry(task_id: null, project_id: 10, id: 2)], tasks: [], projects: [buildProject(id: 10)] }
          spy2 = jasmine.createSpy().andCallFake (collection) ->
            expect(collection.loaded).toBe true
          collection = base.data.loadCollection "time_entries", include: ["project", "task"], only: 2, success: spy2
          spy = jasmine.createSpy().andCallFake ->
            expect(collection.loaded).toBe true
            expect(collection.get(2).get('task')).toBeFalsy()
            expect(collection.get(2).get('project').id).toEqual 10
            expect(collection.length).toEqual 1
          collection.bind "reset", spy
          expect(collection.loaded).toBe false
          server.respond()
          expect(collection.loaded).toBe true
          expect(spy).toHaveBeenCalled()
          expect(spy2).toHaveBeenCalled()

        it "only requests ids that we don't already have", ->
          respondWith server, "/api/time_entries?include=project%3Btask&only=2",
                      data: { results: [["time_entries", 2]], time_entries: [buildTimeEntry(task_id: null, project_id: 10, id: 2)], tasks: [], projects: [buildProject(id: 10)] }
          respondWith server, "/api/time_entries?include=project%3Btask&only=3",
                      data: { results: [["time_entries", 3]], time_entries: [buildTimeEntry(task_id: null, project_id: 11, id: 3)], tasks: [], projects: [buildProject(id: 11)] }

          collection = base.data.loadCollection "time_entries", include: ["project", "task"], only: 2
          expect(collection.loaded).toBe false
          server.respond()
          expect(collection.loaded).toBe true
          expect(collection.get(2).get('project').id).toEqual 10
          collection2 = base.data.loadCollection "time_entries", include: ["project", "task"], only: [2, 3]
          expect(collection2.loaded).toBe false
          server.respond()
          expect(collection2.loaded).toBe true
          expect(collection2.length).toEqual 2
          expect(collection2.get(2).get('project').id).toEqual 10
          expect(collection2.get(3).get('project').id).toEqual 11

        it "does request ids from the server again when they don't have all associations loaded yet", ->
          respondWith server, "/api/time_entries?include=project&only=2",
                      data: { results: [["time_entries", 2]], time_entries: [buildTimeEntry(project_id: 10, id: 2, task_id: 5)], projects: [buildProject(id: 10)] }
          respondWith server, "/api/time_entries?include=project%3Btask&only=2",
                      data: { results: [["time_entries", 2]], time_entries: [buildTimeEntry(project_id: 10, id: 2, task_id: 5)], tasks: [buildTask(id: 5)], projects: [buildProject(id: 10)] }
          respondWith server, "/api/time_entries?include=project%3Btask&only=3",
                      data: { results: [["time_entries", 3]], time_entries: [buildTimeEntry(project_id: 11, id: 3, task_id: null)], tasks: [], projects: [buildProject(id: 11)] }

          base.data.loadCollection "time_entries", include: ["project"], only: 2
          server.respond()
          base.data.loadCollection "time_entries", include: ["project", "task"], only: 3
          server.respond()
          collection2 = base.data.loadCollection "time_entries", include: ["project", "task"], only: [2, 3]
          expect(collection2.loaded).toBe false
          server.respond()
          expect(collection2.loaded).toBe true
          expect(collection2.get(2).get('task').id).toEqual 5
          expect(collection2.length).toEqual 2

        it "doesn't go to the server if it doesn't need to", ->
          respondWith server, "/api/time_entries?include=project%3Btask&only=2%2C3",
                      data: { results: [["time_entries", 2], ["time_entries", 3]], time_entries: [buildTimeEntry(project_id: 10, id: 2, task_id: null), buildTimeEntry(project_id: 11, id: 3)], tasks: [], projects: [buildProject(id: 10), buildProject(id: 11)] }
          collection = base.data.loadCollection "time_entries", include: ["project", "task"], only: [2, 3]
          expect(collection.loaded).toBe false
          server.respond()
          expect(collection.loaded).toBe true
          expect(collection.get(2).get('project').id).toEqual 10
          expect(collection.get(3).get('project').id).toEqual 11
          expect(collection.length).toEqual 2
          spy = jasmine.createSpy()
          collection2 = base.data.loadCollection "time_entries", include: ["project"], only: [2, 3], success: spy
          expect(spy).toHaveBeenCalled()
          expect(collection2.loaded).toBe true
          expect(collection2.get(2).get('project').id).toEqual 10
          expect(collection2.get(3).get('project').id).toEqual 11
          expect(collection2.length).toEqual 2

        it "returns an empty collection when passed in an empty array", ->
          timeEntries = [buildTimeEntry(task_id: 2, project_id: 15, id: 1), buildTimeEntry(project_id: 10, id: 2)]
          respondWith server, "/api/time_entries?per_page=20&page=1",
                      data: { results: [["time_entries", 1], ["time_entries", 2]], time_entries: timeEntries }
          collection = base.data.loadCollection "time_entries", only: []
          expect(collection.loaded).toBe true
          expect(collection.length).toEqual 0

          collection = base.data.loadCollection "time_entries", only: null
          server.respond()
          expect(collection.loaded).toBe true
          expect(collection.length).toEqual 2

        it "accepts a success function that gets triggered on cache hit", ->
          respondWith server, "/api/time_entries?include=project%3Btask&only=2%2C3",
                      data: { results: [["time_entries", 2], ["time_entries", 3]], time_entries: [buildTimeEntry(project_id: 10, id: 2, task_id: null), buildTimeEntry(project_id: 11, id: 3, task_id: null)], tasks: [], projects: [buildProject(id: 10), buildProject(id: 11)] }
          base.data.loadCollection "time_entries", include: ["project", "task"], only: [2, 3]
          server.respond()
          spy = jasmine.createSpy().andCallFake (collection) ->
            expect(collection.loaded).toBe true
            expect(collection.get(2).get('project').id).toEqual 10
            expect(collection.get(3).get('project').id).toEqual 11
          collection2 = base.data.loadCollection "time_entries", include: ["project"], only: [2, 3], success: spy
          expect(spy).toHaveBeenCalled()

        it "does not update sort lengths on only queries", ->
          respondWith server, "/api/time_entries?include=project%3Btask&only=2%2C3",
                      data: { results: [["time_entries", 2], ["time_entries", 3]], time_entries: [buildTimeEntry(project_id: 10, id: 2, task_id: null), buildTimeEntry(project_id: 11, id: 3, task_id: null)], tasks: [], projects: [buildProject(id: 10), buildProject(id: 11)] }
          collection = base.data.loadCollection "time_entries", include: ["project", "task"], only: [2, 3]
          expect(Object.keys base.data.getCollectionDetails("time_entries")["cache"]).toEqual []
          server.respond()
          expect(Object.keys base.data.getCollectionDetails("time_entries")["cache"]).toEqual []

        it "does go to the server on a repeat request if an association is missing", ->
          respondWith server, "/api/time_entries?include=project&only=2",
                      data: { results: [["time_entries", 2]], time_entries: [buildTimeEntry(project_id: 10, id: 2, task_id: 6)], projects: [buildProject(id: 10)] }
          respondWith server, "/api/time_entries?include=project%3Btask&only=2",
                      data: { results: [["time_entries", 2]], time_entries: [buildTimeEntry(project_id: 10, id: 2, task_id: 6)], tasks: [buildTask(id: 6)], projects: [buildProject(id: 10)] }
          collection = base.data.loadCollection "time_entries", include: ["project"], only: 2
          expect(collection.loaded).toBe false
          server.respond()
          expect(collection.loaded).toBe true
          collection2 = base.data.loadCollection "time_entries", include: ["project", "task"], only: 2
          expect(collection2.loaded).toBe false

    describe "disabling caching", ->
      item = null

      beforeEach ->
        item = createTask()
        respondWith server, "/api/tasks.json?per_page=20&page=1", data: { results: [["tasks", item.id]], tasks: [item] }

      it "goes to server even if we have matching items in cache", ->
        syncSpy = spyOn(Backbone, 'sync')
        collection = base.data.loadCollection "tasks", cache: false, only: item.id
        expect(syncSpy).toHaveBeenCalled()

      it "still adds results to the cache", ->
        spy = spyOn(base.data.storage('tasks'), 'update')
        collection = base.data.loadCollection "tasks", cache: false
        server.respond()
        expect(spy).toHaveBeenCalled()

    describe "searching", ->
      it 'turns off caching', ->
        spy = spyOn(base.data, '_loadCollectionWithFirstLayer')
        collection = base.data.loadCollection "tasks", search: "the meaning of life"
        expect(spy.mostRecentCall.args[0]['cache']).toBe(false)
      
      it "returns the matching items with includes, triggering reset and success", ->
        task = buildTask()
        respondWith server, "/api/tasks.json?per_page=20&page=1&search=go+go+gadget+search",
                    data: { results: [["tasks", task.id]], tasks: [task] }
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
        respondWith server, "/api/tasks.json?per_page=20&page=1&search=go+go+gadget+search", data: { results: [], tasks: [] }
        collection = base.data.loadCollection "tasks", search: "go go gadget search"
        server.respond()

      it 'acts as if no search options were passed if the search string is blank', ->
        respondWith server, "/api/tasks.json?per_page=20&page=1", data: { results: [], tasks: [] }
        collection = base.data.loadCollection "tasks", search: ""
        server.respond()

  describe "createNewCollection", ->
    it "makes a new collection of the appropriate type", ->
      expect(base.data.createNewCollection("tasks", [buildTask(), buildTask()]) instanceof App.Collections.Tasks).toBe true

    it "can accept a 'loaded' flag", ->
      collection = base.data.createNewCollection("tasks", [buildTask(), buildTask()])
      expect(collection.loaded).toBe false
      collection = base.data.createNewCollection("tasks", [buildTask(), buildTask()], loaded: true)
      expect(collection.loaded).toBe true

  describe "_wrapObjects", ->
    it "wraps elements in an array with objects unless they are already objects", ->
      expect(base.data._wrapObjects([])).toEqual []
      expect(base.data._wrapObjects(['a', 'b'])).toEqual [{a: []}, {b: []}]
      expect(base.data._wrapObjects(['a', 'b': []])).toEqual [{a: []}, {b: []}]
      expect(base.data._wrapObjects(['a', 'b': 'c'])).toEqual [{a: []}, {b: [{c: []}]}]
      expect(base.data._wrapObjects([{'a':[], b: 'c', d: 'e' }])).toEqual [{a: []}, {b: [{c: []}]}, {d: [{e: []}]}]
      expect(base.data._wrapObjects(['a', { b: 'c', d: 'e' }])).toEqual [{a: []}, {b: [{c: []}]}, {d: [{e: []}]}]
      expect(base.data._wrapObjects([{'a': []}, {'b': ['c', d: []]}])).toEqual [{a: []}, {b: [{c: []}, {d: []}]}]

  describe "_countRequiredServerRequests", ->
    it "should count the number of loads needed to get the date", ->
      expect(base.data._countRequiredServerRequests(['a'])).toEqual 1
      expect(base.data._countRequiredServerRequests(['a', 'b', 'c': []])).toEqual 1
      expect(base.data._countRequiredServerRequests([{'a': ['d']}, 'b', 'c': ['e']])).toEqual 3
      expect(base.data._countRequiredServerRequests([{'a': ['d']}, 'b', 'c': ['e': []]])).toEqual 3
      expect(base.data._countRequiredServerRequests([{'a': ['d']}, 'b', 'c': ['e': ['f']]])).toEqual 4
      expect(base.data._countRequiredServerRequests([{'a': ['d']}, 'b', 'c': ['e': ['f', 'g': ['h']]]])).toEqual 5
      expect(base.data._countRequiredServerRequests([{'a': ['d': ['h']]}, { 'b':['g'] }, 'c': ['e': ['f', 'i']]])).toEqual 6

