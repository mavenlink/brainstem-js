describe 'Brainstem.Model', ->
  model = null

  beforeEach ->
    model = new App.Models.Task()

  describe 'parse', ->
    response = null

    beforeEach ->
      response = count: 1, results: [id: 1, key: 'tasks'], tasks: [id: 1, title: 'Do Work']

    it "extracts object data from JSON with root keys", ->
      parsed = model.parse(response)
      expect(parsed.id).toEqual(1)

    it "passes through object data from flat JSON", ->
      parsed = model.parse({id: 1})
      expect(parsed.id).toEqual(1)

    it 'should update the storage manager with the new model and its associations', ->
      response.tasks[0].assignee_ids = [5, 6]
      response.users = [{id: 5, name: 'Jon'}, {id: 6, name: 'Betty'}]

      model.parse(response)

      expect(base.data.storage('tasks').get(1).attributes).toEqual(response.tasks[0])
      expect(base.data.storage('users').get(5).attributes).toEqual(response.users[0])
      expect(base.data.storage('users').get(6).attributes).toEqual(response.users[1])

    it 'should work with an empty response', ->
      expect( -> model.parse(tasks: [], results: [], count: 0)).not.toThrow()

    describe 'updateStorageManager', ->
      it 'should update the associations before the new model', ->
        response.tasks[0].assignee_ids = [5]
        response.users = [{id: 5, name: 'Jon'}]

        spy = spyOn(base.data, 'storage').andCallThrough()
        model.updateStorageManager(response)
        expect(spy.calls[0].args[0]).toEqual('users')
        expect(spy.calls[1].args[0]).toEqual('tasks')

      it 'should work with an empty response', ->
        expect( -> model.updateStorageManager(count: 0, results: [])).not.toThrow()

    it 'should return the first object from the result set', ->
      response.tasks.unshift([id: 2, name: 'Bobby'])

      parsed = model.parse(response)
      expect(parsed.id).toEqual(1)

    it 'should not blow up on server side validation error', ->
      response = errors: ["Invalid task state. Valid states are:'notstarted','started',and'completed'."]
      expect(-> model.parse(response)).not.toThrow()

    describe 'date handling', ->
      it "parses ISO 8601 dates into date objects / milliseconds", ->
        parsed = model.parse({created_at: "2013-01-25T11:25:57-08:00"})
        expect(parsed.created_at).toEqual(1359141957000)

      it "passes through dates in milliseconds already", ->
        parsed = model.parse({created_at: 1359142047000})
        expect(parsed.created_at).toEqual(1359142047000)

      it 'parses dates on associated models', ->
        response.tasks[0].created_at = "2013-01-25T11:25:57-08:00"
        response.tasks[0].assignee_ids = [5, 6]
        response.users = [{id: 5, name: 'John', created_at: "2013-02-25T11:25:57-08:00"}, {id: 6, name: 'Betty', created_at: "2013-01-30T11:25:57-08:00"}]

        parsed = model.parse(response)
        expect(parsed.created_at).toEqual(1359141957000)
        expect(base.data.storage('users').get(5).get('created_at')).toEqual(1361820357000)
        expect(base.data.storage('users').get(6).get('created_at')).toEqual(1359573957000)

  describe 'setLoaded', ->
    it "should set the values of @loaded", ->
      model.setLoaded true
      expect(model.loaded).toEqual(true)
      model.setLoaded false
      expect(model.loaded).toEqual(false)

    it "triggers 'loaded' when becoming true", ->
      spy = jasmine.createSpy()
      model.bind "loaded", spy
      model.setLoaded false
      expect(spy).not.toHaveBeenCalled()
      model.setLoaded true
      expect(spy).toHaveBeenCalled()

    it "doesn't trigger loaded if trigger: false is provided", ->
      spy = jasmine.createSpy()
      model.bind "loaded", spy
      model.setLoaded true, trigger: false
      expect(spy).not.toHaveBeenCalled()

    it "returns self", ->
      spy = jasmine.createSpy()
      model.bind "loaded", spy
      model.setLoaded true
      expect(spy).toHaveBeenCalledWith(model)

  describe 'associations', ->
    describe 'associationDetails', ->

      class TestClass extends Brainstem.Model
        @associations:
          my_users: ["storage_system_collection_name"]
          my_user: "users"
          user: "users"
          users: ["users"]

      it "returns a hash containing the key, type and plural of the association", ->
        testClass = new TestClass()
        expect(TestClass.associationDetails('my_users')).toEqual key: "my_user_ids", type: "HasMany",    collectionName: "storage_system_collection_name"
        expect(TestClass.associationDetails('my_user')).toEqual  key: "my_user_id",  type: "BelongsTo",  collectionName: "users"
        expect(TestClass.associationDetails('user')).toEqual     key: "user_id",     type: "BelongsTo",  collectionName: "users"
        expect(TestClass.associationDetails('users')).toEqual    key: "user_ids",    type: "HasMany",    collectionName: "users"

        expect(testClass.constructor.associationDetails('users')).toEqual   key: "user_ids",    type: "HasMany",    collectionName: "users"

      it "is cached on the class for speed", ->
        original = TestClass.associationDetails('my_users')
        TestClass.associations.my_users = "something_else"
        expect(TestClass.associationDetails('my_users')).toEqual original

      it "returns falsy if the association cannot be found", ->
        expect(TestClass.associationDetails("I'mNotAThing")).toBeFalsy()

    describe 'associationsAreLoaded', ->
      describe "with BelongsTo associations", ->
        it "should return true when all provided associations are loaded for the model", ->
          timeEntry = new App.Models.TimeEntry(id: 5, project_id: 10, task_id: 2)
          expect(timeEntry.associationsAreLoaded(["project", "task"])).toBeFalsy()
          buildAndCacheProject( id: 10, title: "a project!")
          expect(timeEntry.associationsAreLoaded(["project", "task"])).toBeFalsy()
          expect(timeEntry.associationsAreLoaded(["project"])).toBeTruthy()
          buildAndCacheTask(id: 2, title: "a task!")
          expect(timeEntry.associationsAreLoaded(["project", "task"])).toBeTruthy()
          expect(timeEntry.associationsAreLoaded(["project"])).toBeTruthy()
          expect(timeEntry.associationsAreLoaded(["task"])).toBeTruthy()

        it "should default to all of the associations defined on the model", ->
          timeEntry = new App.Models.TimeEntry(id: 5, project_id: 10, task_id: 2, user_id: 666)
          expect(timeEntry.associationsAreLoaded()).toBeFalsy()
          buildAndCacheProject(id: 10, title: "a project!")
          expect(timeEntry.associationsAreLoaded()).toBeFalsy()
          buildAndCacheTask(id: 2, title: "a task!")
          expect(timeEntry.associationsAreLoaded()).toBeFalsy()
          buildAndCacheUser(id:666)
          expect(timeEntry.associationsAreLoaded()).toBeTruthy()

        it "should appear loaded when an association is null, but not loaded when the key is missing", ->
          timeEntry = buildAndCacheTimeEntry()
          delete timeEntry.attributes.project_id
          expect(timeEntry.associationsAreLoaded(["project"])).toBeFalsy()
          timeEntry = new App.Models.TimeEntry(id: 5, project_id: null)
          expect(timeEntry.associationsAreLoaded(["project"])).toBeTruthy()
          timeEntry = new App.Models.TimeEntry(id: 5, project_id: 2)
          expect(timeEntry.associationsAreLoaded(["project"])).toBeFalsy()

      describe "with HasMany associations", ->
        it "should return true when all provided associations are loaded", ->
          project = new App.Models.Project(id: 5, time_entry_ids: [10, 11], task_ids: [2, 3])
          expect(project.associationsAreLoaded(["time_entries", "tasks"])).toBeFalsy()
          buildAndCacheTimeEntry(id: 10)
          expect(project.associationsAreLoaded(["time_entries"])).toBeFalsy()
          buildAndCacheTimeEntry(id: 11)
          expect(project.associationsAreLoaded(["time_entries"])).toBeTruthy()
          expect(project.associationsAreLoaded(["time_entries", "tasks"])).toBeFalsy()
          expect(project.associationsAreLoaded(["tasks"])).toBeFalsy()
          buildAndCacheTask(id: 2)
          expect(project.associationsAreLoaded(["tasks"])).toBeFalsy()
          buildAndCacheTask(id: 3)
          expect(project.associationsAreLoaded(["tasks"])).toBeTruthy()
          expect(project.associationsAreLoaded(["tasks", "time_entries"])).toBeTruthy()

        it "should appear loaded when an association is an empty array, but not loaded when the key is missing", ->
          project = new App.Models.Project(id: 5, time_entry_ids: [])
          expect(project.associationsAreLoaded(["time_entries"])).toBeTruthy()
          expect(project.associationsAreLoaded(["tasks"])).toBeFalsy()

    describe "get", ->
      it "should delegate to Backbone.Model#get for anything that is not an association", ->
        timeEntry = new App.Models.TimeEntry(id: 5, project_id: 10, task_id: 2, title: "foo")
        expect(timeEntry.get("title")).toEqual "foo"
        expect(timeEntry.get("missing")).toBeUndefined()

      describe "BelongsTo associations", ->
        it "should return associations", ->
          timeEntry = new App.Models.TimeEntry(id: 5, project_id: 10, task_id: 2)
          expect(-> timeEntry.get("project")).toThrow()
          base.data.storage("projects").add { id: 10, title: "a project!" }
          expect(timeEntry.get("project").get("title")).toEqual "a project!"
          expect(timeEntry.get("project")).toEqual base.data.storage("projects").get(10)

        it "should return null when we don't have an association id", ->
          timeEntry = new App.Models.TimeEntry(id: 5, task_id: 2)
          expect(timeEntry.get("project")).toBeFalsy()

        it "should throw when we have an association id but it cannot be found", ->
          timeEntry = new App.Models.TimeEntry(id: 5, task_id: 2)
          expect(-> timeEntry.get("task")).toThrow()

      describe "HasMany associations", ->
        it "should return HasMany associations", ->
          project = new App.Models.Project(id: 5, time_entry_ids: [2, 5])
          expect(-> project.get("time_entries")).toThrow()
          base.data.storage("time_entries").add buildTimeEntry(id: 2, project_id: 5, title: "first time entry")
          base.data.storage("time_entries").add buildTimeEntry(id: 5, project_id: 5, title: "second time entry")
          expect(project.get("time_entries").get(2).get("title")).toEqual "first time entry"
          expect(project.get("time_entries").get(5).get("title")).toEqual "second time entry"

        it "should return null when we don't have any association ids", ->
          project = new App.Models.Project(id: 5)
          expect(project.get("time_entries").models).toEqual []

        it "should throw when we have an association id but it cannot be found", ->
          project = new App.Models.Project(id: 5, time_entry_ids: [2, 5])
          expect(-> project.get("time_entries")).toThrow()

        it "should apply a sort order to has many associations if it is provided at time of get", ->
          task = buildAndCacheTask(id: 5, sub_task_ids: [103, 77, 99])
          buildAndCacheTask(id:103 , position: 3, updated_at: 845785)
          buildAndCacheTask(id:77 , position: 2, updated_at: 995785)
          buildAndCacheTask(id:99 , position: 1, updated_at: 635785)

          subTasks = task.get("sub_tasks")
          expect(subTasks.at(0).get('position')).toEqual(3)
          expect(subTasks.at(1).get('position')).toEqual(2)
          expect(subTasks.at(2).get('position')).toEqual(1)

          subTasks = task.get("sub_tasks", order: "position:asc")
          expect(subTasks.at(0).get('position')).toEqual(1)
          expect(subTasks.at(1).get('position')).toEqual(2)
          expect(subTasks.at(2).get('position')).toEqual(3)

          subTasks = task.get("sub_tasks", order: "updated_at:desc")
          expect(subTasks.at(0).get('id')).toEqual(77)
          expect(subTasks.at(1).get('id')).toEqual(103)
          expect(subTasks.at(2).get('id')).toEqual(99)

  describe "toServerJSON", ->
    it "calls toJSON", ->
      spy = spyOn(model, "toJSON").andCallThrough()
      model.toServerJSON()
      expect(spy).toHaveBeenCalled()

    it "always removes default blacklisted keys", ->
      defaultBlacklistKeys = model.defaultJSONBlacklist()
      expect(defaultBlacklistKeys.length).toEqual(0)

      model.defaultJSONBlacklist = -> ['foo', 'bar']

      model.set('safe', true)
      for key in defaultBlacklistKeys
        model.set(key, true)

      json = model.toServerJSON("create")
      expect(json['safe']).toEqual(true)
      for key in defaultBlacklistKeys
        expect(json[key]).toBeUndefined()

    it "removes blacklisted keys for create actions", ->
      createBlacklist = ['flies', 'ants', 'fire ants']
      spyOn(model, 'createJSONBlacklist').andReturn(createBlacklist)

      for key in createBlacklist
        model.set(key, true)

      json = model.toServerJSON("create")
      for key in createBlacklist
        expect(json[key]).toBeUndefined()

    it "removes blacklisted keys for update actions", ->
      updateBlacklist = ['possums', 'racoons', 'potatoes']
      spyOn(model, 'updateJSONBlacklist').andReturn(updateBlacklist)

      for key in updateBlacklist
        model.set(key, true)

      json = model.toServerJSON("update")
      for key in updateBlacklist
        expect(json[key]).toBeUndefined()