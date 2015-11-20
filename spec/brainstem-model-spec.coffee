describe 'Brainstem.Model', ->
  model = null

  beforeEach ->
    base.data.reset()
    model = buildTask()

  describe '#fetch', ->
    beforeEach ->
      base.data.storage('tasks').add model

    context 'options has no name property and the model does not have a brainstem key', ->
      beforeEach ->
        model.brainstemKey = undefined

      it 'throws a brainstem error', ->
        expect(-> model.fetch()).toThrow()

    context 'options has a name property and the model does not have a brainstem key', ->
      beforeEach ->
        model.brainstemKey = undefined

      it 'does not throw a brainstem error', ->
        expect(-> model.fetch({name: 'posts'})).not.toThrow()

    context 'options has no name property and the model does have a brainstem key', ->
      beforeEach ->
        model.brainstemKey = 'posts'

      it 'does not throw a brainstem error', ->
        expect(-> model.fetch()).not.toThrow()

    it 'calls wrapError', ->
      spyOn(Brainstem.Utils, 'wrapError')

      model.fetch(options = {only: [model.id], parse: true, name: 'posts', cache: false})

      expect(Brainstem.Utils.wrapError).toHaveBeenCalledWith(model, options)

    it 'calls loadObject', ->
      promise = done: (-> {promise: (->)})
      spyOn(base.data, 'loadObject').andReturn(promise)

      model.fetch()

      expect(base.data.loadObject).toHaveBeenCalledWith(
        'tasks',
        { only: [model.id], parse: true, name: 'tasks', error: jasmine.any(Function), cache: false },
        isCollection: false
      )

    it 'on success, triggers sync', ->
      deferred = new $.Deferred
      newModel = {}

      spyOn(base.data, 'loadObject').andReturn(deferred)
      spyOn(model, 'trigger')

      model.fetch()
      deferred.resolve(newModel)

      expect(model.trigger).toHaveBeenCalledWith('sync', newModel, {only: [model.id], name: 'tasks', parse: true, error: jasmine.any(Function), cache: false})

    it 'returns a promise', ->
      promise = (new $.Deferred).promise()

      spyOn(base.data, 'loadObject').andReturn(promise)
      spyOn(model, 'trigger')

      expect(model.fetch()).toEqual(promise)

    describe 'integration', ->
      it 'something', ->
        task = buildTask()
        respondWith(server, '/api/tasks/1', resultsFrom: 'tasks', data: task)

        model.fetch()
        server.respond()

        expect(model.attributes).toEqual(task.attributes)


  describe '#parse', ->
    response = null

    beforeEach ->
      model = new App.Models.Task()
      response = count: 1, results: [id: 1, key: 'tasks'], tasks: { 1: { id: 1, title: 'Do Work' } }

    it "extracts object data from JSON with root keys", ->
      parsed = model.parse(response)
      expect(parsed.id).toEqual(1)

    it "passes through object data from flat JSON", ->
      parsed = model.parse({id: 1})
      expect(parsed.id).toEqual(1)

    it 'should update the storage manager with the new model and its associations', ->
      response.tasks[1].assignee_ids = [5, 6]
      response.users = { 5: {id: 5, name: 'Jon'}, 6: {id: 6, name: 'Betty'} }

      model.parse(response)

      expect(base.data.storage('tasks').get(1).attributes).toEqual(response.tasks[1])
      expect(base.data.storage('users').get(5).attributes).toEqual(response.users[5])
      expect(base.data.storage('users').get(6).attributes).toEqual(response.users[6])

    describe 'adding new models to the storage manager', ->
      context 'there is an ID on the model already', ->
        # usually happens when fetching an existing model and not using StorageManager#loadModel
        # new App.Models.Task(id: 5).fetch()

        beforeEach ->
          model.set('id', 1)

        context 'model ID matches response ID', ->
          it 'should add the parsing model to the storage manager', ->
            response.tasks[1].id = 1
            expect(base.data.storage('tasks').get(1)).toBeUndefined()

            model.parse(response)
            expect(base.data.storage('tasks').get(1)).not.toBeUndefined()
            expect(base.data.storage('tasks').get(1)).toEqual model
            expect(base.data.storage('tasks').get(1).attributes).toEqual response.tasks[1]

        context 'model ID does not match response ID', ->
          # this only happens when an association has the same brainstemKey as the parent record
          # we want to add a new model to the storage manager and not worry about ourself

          it 'should not add the parsing model to the storage manager', ->
            response.tasks[1].id = 2345
            expect(base.data.storage('tasks').get(1)).toBeUndefined()

            model.parse(response)
            expect(base.data.storage('tasks').get(1)).toBeUndefined()
            expect(base.data.storage('tasks').get(2345)).not.toEqual model

      context 'there is not an ID on the model instance already', ->
        # usually happens when creating a new model:
        # new App.Models.Task(title: 'test').save()

        beforeEach ->
          expect(model.id).toBeUndefined()

        it 'should add the parsing model to the storage manager', ->
          response.tasks[1].title = 'Hello'
          expect(base.data.storage('tasks').get(1)).toBeUndefined()

          model.parse(response)
          expect(base.data.storage('tasks').get(1)).toEqual(model)
          expect(base.data.storage('tasks').get(1).get('title')).toEqual('Hello')

    it 'should work with an empty response', ->
      expect( -> model.parse(tasks: {}, results: [], count: 0)).not.toThrow()

    describe 'updateStorageManager', ->
      it 'should update the associations before the new model', ->
        response.tasks[1].assignee_ids = [5]
        response.users = { 5: {id: 5, name: 'Jon'} }

        spy = spyOn(base.data, 'storage').andCallThrough()
        model.updateStorageManager(response)
        expect(spy.calls[0].args[0]).toEqual('users')
        expect(spy.calls[1].args[0]).toEqual('tasks')

      it 'should work with an empty response', ->
        expect( -> model.updateStorageManager(count: 0, results: [])).not.toThrow()

    it 'should return the first object from the result set', ->
      response.tasks[2] = (id: 2, title: 'foo')
      response.results.unshift(id: 2, key: 'tasks')
      parsed = model.parse(response)
      expect(parsed.id).toEqual 2
      expect(parsed.title).toEqual 'foo'

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
        response.tasks[1].created_at = "2013-01-25T11:25:57-08:00"
        response.tasks[1].assignee_ids = [5, 6]
        response.users = { 5: {id: 5, name: 'John', created_at: "2013-02-25T11:25:57-08:00"}, 6: {id: 6, name: 'Betty', created_at: "2013-01-30T11:25:57-08:00"} }

        parsed = model.parse(response)
        expect(parsed.created_at).toEqual(1359141957000)
        expect(base.data.storage('users').get(5).get('created_at')).toEqual(1361820357000)
        expect(base.data.storage('users').get(6).get('created_at')).toEqual(1359573957000)

      it "does not handle ISO 8601 dates with other characters", ->
        parsed = model.parse({created_at: "blargh 2013-01-25T11:25:57-08:00 churgh"})
        expect(parsed.created_at).toEqual("blargh 2013-01-25T11:25:57-08:00 churgh")

  describe 'associations', ->

    class TestClass extends Brainstem.Model
      @associations:
        user: "users"
        project: "projects"
        users: ["users"]
        projects: ["projects"]
        activity: ["tasks", "posts"]

    describe 'associationDetails', ->
      it "returns a hash containing the key, type and plural of the association", ->
        expect(TestClass.associationDetails('user')).toEqual
          key: "user_id"
          type: "BelongsTo"
          collectionName: "users"

        expect(TestClass.associationDetails('users')).toEqual
          key: "user_ids"
          type: "HasMany"
          collectionName: "users"

      it 'returns the correct association details for polymorphic associations', ->
        expect(TestClass.associationDetails('activity')).toEqual
          key: "activity_ref"
          type: "BelongsTo"
          collectionName: ["tasks", "posts"]
          polymorphic: true

      it "is cached on the class for speed", ->
        original = TestClass.associationDetails('users')
        TestClass.associations.users = "something_else"

        expect(TestClass.associationDetails('users')).toEqual original

      it "returns falsy if the association cannot be found", ->
        expect(TestClass.associationDetails("I'mNotAThing")).toBeFalsy()

    describe 'associationsAreLoaded', ->
      testClass = null

      describe "when association is of type 'BelongsTo'", ->
        context "and is not polymorphic", ->
          beforeEach ->
            testClass = new TestClass(id: 10, user_id: 20, project_id: 30)

          context 'when association is loaded', ->
            beforeEach ->
              buildAndCacheUser(id: 20)

            it 'returns true', ->
              expect(testClass.associationsAreLoaded(["user"])).toBe true

            context 'when association is requested with another association described on model class', ->
              context 'when other association is loaded', ->
                beforeEach ->
                  buildAndCacheProject(id: 30)

                it "returns true", ->
                  expect(testClass.associationsAreLoaded(["user", "project"])).toBe true

              context "when other association is not loaded", ->
                it "returns false", ->
                  expect(testClass.associationsAreLoaded(["user", "project"])).toBe false

            context "when association is requested with a association not described on model class", ->
              it "returns true", ->
                expect(testClass.associationsAreLoaded(["user", "non_association"])).toBe true

          context "when association is not loaded", ->
            beforeEach ->
              expect(base.data.storage("users").get(20)).toBeFalsy()

            it 'returns false', ->
              expect(testClass.associationsAreLoaded(["user"])).toBe false

            context 'when association is requested with another association described on model class', ->
              context 'when other association is loaded', ->
                beforeEach ->
                  buildAndCacheProject(id: 30)

                it "returns false", ->
                  expect(testClass.associationsAreLoaded(["user", "project"])).toBe false

              context "when other association is not loaded", ->
                it "returns false", ->
                  expect(testClass.associationsAreLoaded(["user", "project"])).toBe false

            context "when association is requested with a association not described on model class", ->
              it "returns false", ->
                expect(testClass.associationsAreLoaded(["user", "non_association"])).toBe false

        context "and is polymorphic", ->
          beforeEach ->
            testClass = new TestClass(id: 10, activity_ref: { id: 40, key: "posts" }, project_id: 30)

          context 'when association is loaded', ->
            beforeEach ->
              buildAndCachePost(id: 40)

            it 'returns true', ->
              expect(testClass.associationsAreLoaded(["activity"])).toBe true

            context 'when association is requested with another association described on model class', ->
              context 'when other association is loaded', ->
                beforeEach ->
                  buildAndCacheProject(id: 30)

                it "returns true", ->
                  expect(testClass.associationsAreLoaded(["activity", "project"])).toBe true

              context "when other association is not loaded", ->
                it "returns false", ->
                  expect(testClass.associationsAreLoaded(["activity", "project"])).toBe false

            context "when association is requested with a association not described on model class", ->
              it "returns true", ->
                expect(testClass.associationsAreLoaded(["activity", "non_association"])).toBe true

          context "when association is not loaded", ->
            beforeEach ->
              expect(base.data.storage("posts").get(20)).toBeFalsy()

            it 'returns false', ->
              expect(testClass.associationsAreLoaded(["activity"])).toBe false

            context 'when association is requested with another association described on model class', ->
              context 'when other association is loaded', ->
                beforeEach ->
                  buildAndCacheProject(id: 30)

                it "returns false", ->
                  expect(testClass.associationsAreLoaded(["activity", "project"])).toBe false

              context "when other association is not loaded", ->
                it "returns false", ->
                  expect(testClass.associationsAreLoaded(["activity", "project"])).toBe false

            context "when association is requested with a association not described on model class", ->
              it "returns false", ->
                expect(testClass.associationsAreLoaded(["activity", "non_association"])).toBe false

      describe "when association is of type 'HasMany'", ->
        beforeEach ->
          testClass = new TestClass(id: 10, user_ids: [20, 30], project_ids: [40, 50])

        context 'when association is partially loaded', ->
          beforeEach ->
            buildAndCacheUser(id: 20)

          it 'returns false', ->
            expect(testClass.associationsAreLoaded(["users"])).toBe false

        context 'when association is loaded', ->
          beforeEach ->
            buildAndCacheUser(id: 20)
            buildAndCacheUser(id: 30)

          it 'returns true', ->
            expect(testClass.associationsAreLoaded(["users"])).toBe true

          context 'when association is requested with another association described on model class', ->
            context 'when other association is loaded', ->
              beforeEach ->
                buildAndCacheProject(id: 40)
                buildAndCacheProject(id: 50)

              it "returns true", ->
                expect(testClass.associationsAreLoaded(["users", "projects"])).toBe true

            context "when other association is not loaded", ->
              it "returns false", ->
                expect(testClass.associationsAreLoaded(["users", "projects"])).toBe false

          context "when association is requested with a association not described on model class", ->
            it "returns true", ->
              expect(testClass.associationsAreLoaded(["users", "non_associations"])).toBe true

        context "when association is not loaded", ->
          beforeEach ->
            expect(base.data.storage("users").get(20)).toBeFalsy()
            expect(base.data.storage("users").get(30)).toBeFalsy()

          it 'returns false', ->
            expect(testClass.associationsAreLoaded(["users"])).toBe false

          context 'when association is requested with another association described on model class', ->
            context 'when other association is loaded', ->
              beforeEach ->
                buildAndCacheProject(id: 40)
                buildAndCacheProject(id: 50)

              it "returns false", ->
                expect(testClass.associationsAreLoaded(["users", "projects"])).toBe false

            context "when other association is not loaded", ->
              it "returns false", ->
                expect(testClass.associationsAreLoaded(["users", "projects"])).toBe false

          context "when association is requested with a association not described on model class", ->
            it "returns false", ->
              expect(testClass.associationsAreLoaded(["users", "non_associations"])).toBe false

      describe "when given association does not exist", ->
        beforeEach ->
          testClass = new TestClass()

        it "returns true", ->
          expect(testClass.associationsAreLoaded(['non_association'])).toBe true

      describe "when given association is empty", ->
        beforeEach ->
          testClass = new TestClass()

        it "returns true", ->
          expect(testClass.associationsAreLoaded([])).toBe true

    describe "#get", ->
      timeEntry = null

      afterEach ->
        base.data.reset()

      describe "attributes not defined as associations", ->
        beforeEach ->
          timeEntry = new App.Models.TimeEntry(id: 5, project_id: 10, task_id: 2, title: "foo")

        context "when attribute exists", ->
          it "should delegate to Backbone.Model#get", ->
            getSpy = spyOn(Backbone.Model.prototype, 'get')

            timeEntry.get("title")

            expect(getSpy).toHaveBeenCalledWith "title"

          it "returns correct value", ->
            expect(timeEntry.get("title")).toEqual "foo"

        context "does attribute does not exist", ->
          it "returns undefined", ->
            expect(timeEntry.get("missing")).toBeUndefined()

      describe "attributes defined as associations", ->
        collection = null

        beforeEach ->
          timeEntry = new App.Models.TimeEntry(id: 5, task_id: 2)

        context 'when an association id and association exists', ->
          task = user1 = user2 = null

          beforeEach ->
            base.data.storage("tasks").add buildTask(id: 2, title: "second time entry")

            user1 = buildAndCacheUser()
            user2 = buildAndCacheUser()

            task = buildAndCacheTask(id: 5, assignee_ids: [user1.id])

          it "returns correct value", ->
            expect(timeEntry.get("task")).toEqual base.data.storage("tasks").get(2)

          context 'option link is true', ->
            beforeEach ->
              collection = task.get('assignees', link: true)

            it 'changes to the returned collection are reflected on the models ids array', ->
              expect(collection.at(0)).toBe(user1)

              collection.add(user2)

              expect(task.get('assignees').at(1).cid).toBe(user2.cid)

              collection.remove(user1)

              expect(task.get('assignees').at(1)).toBeUndefined()
              expect(task.get('assignees').at(0).cid).toBe(user2.cid)

            it 'asking for another linked collection returns the same instance of the collection', ->
              expect(task.get('assignees', link: true)).toBe(collection)

          context 'option link is falsey', ->
            beforeEach ->
              collection = task.get('assignees', link: false)

            it 'changes to the returned collection are not relfected on the models ids array', ->
              expect(collection.at(0)).toBe(user1)

              collection.add(user2)

              expect(task.get('assignees').at(1)).toBeUndefined()

            it 'asking for another linked collection returns a new instance of the collection', ->
              expect(task.get('assignees', link: false)).not.toBe(collection)


        context "when we have an association id that cannot be found", ->
          beforeEach ->
            expect(base.data.storage("tasks").get(2)).toBeFalsy()

          it "should throw when silent is not supplied or falsy", ->
            expect(-> timeEntry.get("task")).toThrow()
            expect(-> timeEntry.get("task", silent: null)).toThrow()
            expect(-> timeEntry.get("task", silent: undefined)).toThrow()
            expect(-> timeEntry.get("task", silent: false)).toThrow()

          it "should not throw when silent is true", ->
            expect(-> timeEntry.get("task", silent: true)).not.toThrow()

      describe "BelongsTo associations", ->
        beforeEach ->
          base.data.storage("projects").add { id: 10, title: "a project!" }

        describe "when association is a non-polymorphic", ->
          beforeEach ->
            timeEntry = new App.Models.TimeEntry(id: 5, project_id: 10, title: "foo")

          context "when association id is not present", ->
            it "should return undefined", ->
              expect(timeEntry.get("task")).toBeUndefined()

          context "when association id is present", ->
            it "should delegate to Backbone.Model#get", ->
              getSpy = spyOn(Backbone.Model.prototype, 'get')

              timeEntry.get("project")

              expect(getSpy).toHaveBeenCalledWith "project_id"

            it "should return association", ->
              expect(timeEntry.get("project")).toEqual base.data.storage("projects").get(10)

        describe 'when association is polymorphic', ->
          post = null

          context "when association reference is not present", ->
            beforeEach ->
              post = new App.Models.Post(id: 5)

            it "should return undefined", ->
              expect(post.get("subject")).toBeUndefined()

          context "when association reference is present", ->
            beforeEach ->
              post = new App.Models.Post(id: 5, subject_ref: { id: "10", key: "projects" })

            it "should delegate to Backbone.Model#get", ->
              getSpy = spyOn(Backbone.Model.prototype, 'get')

              post.get("subject")

              expect(getSpy).toHaveBeenCalledWith "subject_ref"

            it "should return association", ->
              expect(post.get("subject")).toEqual base.data.storage("projects").get(10)

        describe 'when a form sets an association id to an empty string', ->
          beforeEach ->
            timeEntry.set('project_id', '')

          it 'should not throw a Brainstem error', ->
            expect(-> timeEntry.get("project")).not.toThrow()
            expect(timeEntry.get("project")).toBe(undefined)

      describe "HasMany associations", ->
        project = null

        beforeEach ->
          base.data.storage("tasks").add { id: 10, title: "First Task" }
          base.data.storage("tasks").add { id: 11, title: "Second Task" }
          project = new App.Models.Project(id: 25, task_ids: [10, 11])

        context "when association ids is not present", ->
          it "returns an empty collection", ->
            expect(project.get("time_entries").models).toEqual []

        context "when association ids is present", ->
          it "should delegate to Backbone.Model#get", ->
            getSpy = spyOn(Backbone.Model.prototype, 'get')

            project.get("tasks")

            expect(getSpy).toHaveBeenCalledWith "task_ids"

          it "should return association", ->
            tasks = project.get("tasks")

            expect(tasks.get(10)).toEqual base.data.storage("tasks").get(10)
            expect(tasks.get(11)).toEqual base.data.storage("tasks").get(11)

          context 'sort order', ->
            task = null

            beforeEach ->
              buildAndCacheTask(id:103 , position: 3, updated_at: 845785)
              buildAndCacheTask(id:77 , position: 2, updated_at: 995785)
              buildAndCacheTask(id:99 , position: 1, updated_at: 635785)

              task = buildAndCacheTask(id: 5, sub_task_ids: [103, 77, 99])

            context 'not explicitly specified', ->
              it "applies the default sort order", ->
                subTasks = task.get("sub_tasks")

                expect(subTasks.at(0).get('position')).toEqual(3)
                expect(subTasks.at(1).get('position')).toEqual(2)
                expect(subTasks.at(2).get('position')).toEqual(1)

            context 'is explicitly specified', ->
              it "applies the specified sort order", ->
                subTasks = task.get("sub_tasks", order: "position:asc")

                expect(subTasks.at(0).get('position')).toEqual(1)
                expect(subTasks.at(1).get('position')).toEqual(2)
                expect(subTasks.at(2).get('position')).toEqual(3)

  describe '#invalidateCache', ->
    it 'invalidates all cache objects that a model is a result in', ->
      cache = base.data.getCollectionDetails(model.brainstemKey).cache
      model = buildTask()

      cacheKey = {
        matching1: 'foo|bar'
        matching2: 'foo|bar|filter'
        notMatching: 'bar|bar'
      }

      cache[cacheKey.matching1] =
        results: [{ id: model.id }, { id: buildTask().id }, { id: buildTask().id }]
        valid: true

      cache[cacheKey.notMatching] =
        results: [{ id: buildTask().id }, { id: buildTask().id }, { id: buildTask().id }]
        valid: true

      cache[cacheKey.matching2] =
        results: [{ id: model.id }, { id: buildTask().id }, { id: buildTask().id }]
        valid: true

      # all cache objects should be valid
      expect(cache[cacheKey.matching1].valid).toEqual true
      expect(cache[cacheKey.matching2].valid).toEqual true
      expect(cache[cacheKey.notMatching].valid).toEqual true

      model.invalidateCache()

      # matching cache objects should be invalid
      expect(cache[cacheKey.matching1].valid).toEqual false
      expect(cache[cacheKey.matching2].valid).toEqual false
      expect(cache[cacheKey.notMatching].valid).toEqual true

  describe '#toServerJSON', ->
    it "calls toJSON", ->
      spy = spyOn(model, "toJSON").andCallThrough()
      model.toServerJSON('create')
      expect(spy).toHaveBeenCalled()

    it "always removes default blacklisted keys", ->
      defaultBlacklistKeys = model.defaultJSONBlacklist()
      expect(defaultBlacklistKeys.length).toEqual(3)

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

    it "only sends back changed fields on update actions", ->
      expect(_.keys(model.toServerJSON('update'))).toEqual []

      model.set('title', 'new title')

      expect(_.keys(model.toServerJSON('update'))).toEqual ['title']

    it "resets changed fields on save", ->
      model.set('title', 'new title')
      model.set('description', 'new description')

      expect(_.keys(model.toServerJSON('update'))).toEqual ['title', 'description']

      model.save()

      model.set('description', 'another description')

      expect(_.keys(model.toServerJSON('update'))).toEqual ['description']

    it "sends back all fields on create actions", ->
      expect(_.keys(model.toServerJSON('create'))).toEqual _.chain(model.attributes).keys().without('id').value()

  describe '#_linkCollection', ->
    story = null

    beforeEach ->
      story = new App.Models.Task()

    context 'when there is not an associated collection', ->
      dummyCollection = collectionName = collectionOptions = field = null
      beforeEach ->
        collectionName = 'users'
        collectionOptions = {}
        field = 'assignees'
        expect(story._associatedCollections).toBeUndefined()

        dummyCollection = on: -> 'dummy Collection'

        spyOn(base.data, 'createNewCollection').andReturn(dummyCollection)

      it 'returns an associated collection' ,->
        collection = story._linkCollection(collectionName, [], collectionOptions, field)
        expect(collection).toBe(dummyCollection)

      it 'saves a reference to the associated collection', ->
        collection = story._linkCollection(collectionName, [], collectionOptions, field)
        expect(collection).toBe(story._associatedCollections.assignees)

      it 'getting a different collection craetes a second key on _associatedCollections', ->
        collection = story._linkCollection(collectionName, [], collectionOptions, field)
        collection2 = story._linkCollection("tasks", [], collectionOptions, "sub_tasks")

        expect(story._associatedCollections.field).toBeUndefined()
        expect(collection).toBe(story._associatedCollections.assignees)
        expect(collection2).toBe(story._associatedCollections.sub_tasks)

    context 'when there is already an associated collection', ->
      returnedCollection = collection = collectionName = collectionOptions = field = null
      beforeEach ->
        collectionName = 'users'
        collectionOptions = {}
        field = 'assignees'
        collection = base.data.createNewCollection(collectionName, [], collectionOptions)
        story._associatedCollections = {}
        story._associatedCollections[field] = collection
        spyOn(base.data, 'createNewCollection')
        returnedCollection = story._linkCollection(collectionName, [], collectionOptions, field)

      it 'returns an associated collection' ,->
        expect(collection).toBe(returnedCollection)

      it 'should not create a new collection', ->
        expect(base.data.createNewCollection).not.toHaveBeenCalled()
