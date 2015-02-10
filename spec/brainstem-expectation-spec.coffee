describe 'Brainstem Expectations', ->
  manager = project1 = project2 = task1 = null

  beforeEach ->
    manager = base.data
    manager.enableExpectations()

    project1 = buildProject(id: 1, task_ids: [1])
    project2 = buildProject(id: 2)
    task1 = buildTask(id: 1, project_id: project1.id)

  describe "stubbing responses", ->
    it "should update returned collections", ->
      expectation = manager.stub "projects", response: (stub) ->
        stub.results = [project1, project2]
      collection = manager.loadCollection "projects"
      expect(collection.length).toEqual 0
      expectation.respond()
      expect(collection.length).toEqual 2
      expect(collection.get(1)).toEqual project1
      expect(collection.get(2)).toEqual project2

    it "should call callbacks", ->
      expectation = manager.stub "projects", response: (stub) ->
        stub.results = [project1, project2]
      collection = null
      manager.loadCollection "projects", success: (c) -> collection = c
      expect(collection).toBeNull()
      expectation.respond()
      expect(collection.length).toEqual 2
      expect(collection.get(1)).toEqual project1
      expect(collection.get(2)).toEqual project2

    it "should add to passed-in collections", ->
      expectation = manager.stub "projects", response: (stub) ->
        stub.results = [project1, project2]
      collection = new Brainstem.Collection()
      manager.loadCollection "projects", collection: collection
      expect(collection.length).toEqual 0
      expectation.respond()
      expect(collection.length).toEqual 2
      expect(collection.get(1)).toEqual project1
      expect(collection.get(2)).toEqual project2

    it "should work with results hashes", ->
      expectation = manager.stub "projects", response: (stub) ->
        stub.results = [{ key: "projects", id: 2 }, { key: "projects", id: 1 }]
        stub.associated.projects = [project1, project2]
      collection = manager.loadCollection "projects"
      expectation.respond()
      expect(collection.length).toEqual 2
      expect(collection.models[0]).toEqual project2
      expect(collection.models[1]).toEqual project1

    it "can populate associated objects", ->
      expectation = manager.stub "projects", include: ["tasks"], response: (stub) ->
        stub.results = [project1, project2]
        stub.associated.projects = [project1, project2]
        stub.associated.tasks = [task1]
      collection = new Brainstem.Collection()
      manager.loadCollection "projects", collection: collection, include: ["tasks"]
      expectation.respond()
      expect(collection.get(1).get("tasks").models).toEqual [task1]
      expect(collection.get(2).get("tasks").models).toEqual []

    context "count option is supplied", ->
      collection = null

      beforeEach ->
        expectation = manager.stub "projects",
          count: 20
          response: (stub) ->
            stub.results = [project1, project2]

        collection = manager.loadCollection "projects"
        expectation.respond()

      it "mocks cache object to return mocked count from getServerCount", ->
        expect(collection.getServerCount()).toEqual 20

    describe 'recursive loading', ->
      context 'recursive option is false', ->
        it "should not try to recursively load includes in an expectation", ->
          expectation = manager.stub "projects", include: '*', response: (stub) ->
            stub.results = [project1, project2]
            stub.associated.projects = [project1, project2]
            stub.associated.tasks = [task1]

          spy = spyOn(Brainstem.AbstractLoader.prototype, '_loadAdditionalIncludes')
          collection = manager.loadCollection "projects", include: ["tasks" : ["time_entries"]]
          expectation.respond()
          expect(spy).not.toHaveBeenCalled()

      context 'recursive option is true', ->
        it "should recursively load includes in an expectation", ->
          expectation = manager.stub "projects", include: '*', response: (stub) ->
            stub.results = [project1, project2]
            stub.associated.projects = [project1, project2]
            stub.associated.tasks = [task1]
            stub.recursive = true

          spy = spyOn(Brainstem.AbstractLoader.prototype, '_loadAdditionalIncludes')
          collection = manager.loadCollection "projects", include: ["tasks" : ["time_entries"]]
          expectation.respond()
          expect(spy).toHaveBeenCalled()

    describe "triggering errors", ->
      it "triggers errors when asked to do so", ->
        errorSpy = jasmine.createSpy()

        collection = new Brainstem.Collection()

        resp =
          readyState: 4
          status: 401
          responseText: ""

        expectation = manager.stub "projects", collection: collection, triggerError: resp

        manager.loadCollection "projects", error: errorSpy

        expectation.respond()
        expect(errorSpy).toHaveBeenCalled()
        expect(errorSpy.mostRecentCall.args[0]).toEqual resp

      it "does not trigger errors when asked not to", ->
        errorSpy = jasmine.createSpy()
        expectation = manager.stub "projects", response: (exp) -> exp.results = [project1, project2]

        manager.loadCollection "projects", error: errorSpy

        expectation.respond()
        expect(errorSpy).not.toHaveBeenCalled()

    it "should work without specifying results", ->
      manager.stubImmediate "projects"
      expect(-> manager.loadCollection("projects")).not.toThrow()

  describe "responding immediately", ->
    it "uses stubImmediate", ->
      expectation = manager.stubImmediate "projects", include: ["tasks"], response: (stub) ->
        stub.results = [project1, project2]
        stub.associated.tasks = [task1]
      collection = manager.loadCollection "projects", include: ["tasks"]
      expect(collection.get(1).get("tasks").models).toEqual [task1]

  describe "multiple stubs", ->
    it "should match the first valid expectation", ->
      manager.stubImmediate "projects", only: [1], response: (stub) ->
        stub.results = [project1]
      manager.stubImmediate "projects", response: (stub) ->
        stub.results = [project1, project2]
      manager.stubImmediate "projects", only: [2], response: (stub) ->
        stub.results = [project2]
      expect(manager.loadCollection("projects", only: 1).models).toEqual [project1]
      expect(manager.loadCollection("projects").models).toEqual [project1, project2]
      expect(manager.loadCollection("projects", only: 2).models).toEqual [project2]

    it "should fail if it cannot find a specific match", ->
      manager.stubImmediate "projects", response: (stub) ->
        stub.results = [project1]
      manager.stubImmediate "projects", include: ["tasks"], filters: { something: "else" }, response: (stub) ->
        stub.results = [project1, project2]
        stub.associated.tasks = [task1]
      expect(manager.loadCollection("projects", include: ["tasks"], filters: { something: "else" }).models).toEqual [project1, project2]
      expect(-> manager.loadCollection("projects", include: ["tasks"], filters: { something: "wrong" })).toThrow()
      expect(-> manager.loadCollection("projects", include: ["users"], filters: { something: "else" })).toThrow()
      expect(-> manager.loadCollection("projects", filters: { something: "else" })).toThrow()
      expect(-> manager.loadCollection("projects", include: ["users"])).toThrow()
      expect(manager.loadCollection("projects").models).toEqual [project1]

    it "should ignore empty arrays", ->
      manager.stubImmediate "projects", response: (stub) ->
        stub.results = [project1, project2]
      expect(manager.loadCollection("projects", include: []).models).toEqual [project1, project2]

    it "should allow wildcard params", ->
      manager.stubImmediate "projects", include: '*', response: (stub) ->
        stub.results = [project1, project2]
        stub.associated.tasks = [task1]
      expect(manager.loadCollection("projects", include: ["tasks"]).models).toEqual [project1, project2]
      expect(manager.loadCollection("projects", include: ["users"]).models).toEqual [project1, project2]
      expect(manager.loadCollection("projects").models).toEqual [project1, project2]

  describe "recording", ->
    it "should record options", ->
      expectation = manager.stubImmediate "projects", filters: { something: "else" }, response: (stub) ->
        stub.results = [project1, project2]
      manager.loadCollection("projects", filters: { something: "else" })
      expect(expectation.matches[0].filters).toEqual { something: "else" }

  describe "clearing expectations", ->
    it "expectations can be removed", ->
      expectation = manager.stub "projects", include: ["tasks"], response: (stub) ->
        stub.results = [project1, project2]
        stub.associated.tasks = [task1]

      collection = manager.loadCollection "projects", include: ["tasks"]
      expectation.respond()
      expect(collection.get(1).get("tasks").models).toEqual [task1]

      collection2 = manager.loadCollection "projects", include: ["tasks"]
      expect(collection2.get(1)).toBeFalsy()
      expectation.respond()
      expect(collection2.get(1).get("tasks").models).toEqual [task1]

      expectation.remove()
      expect(-> manager.loadCollection "projects").toThrow()

  describe "lastMatch", ->
    it "retrives the last match object", ->
      expectation = manager.stubImmediate "projects", include: "*", response: (stub) ->
        stub.results = []

      manager.loadCollection("projects", include: ["tasks"])
      manager.loadCollection("projects", include: ["users"])

      expect(expectation.matches.length).toEqual(2)
      expect(expectation.lastMatch().include).toEqual(["users"])

    it "returns undefined if no matches exist", ->
      expectation = manager.stub "projects", response: (stub) ->
        stub.results = []
      expect(expectation.lastMatch()).toBeUndefined()

  describe "loaderOptionsMatch", ->
    it "should ignore wrapping arrays", ->
      expectation = new Brainstem.Expectation("projects", { include: "workspaces" }, manager)
      loader = new Brainstem.CollectionLoader(storageManager: manager)

      loader.setup(name: "projects", include: "workspaces")
      expect(expectation.loaderOptionsMatch(loader)).toBe true

      loader.setup(name: "projects", include: ["workspaces"])
      expect(expectation.loaderOptionsMatch(loader)).toBe true

    it "should treat * as an any match", ->
      expectation = new Brainstem.Expectation("projects", { include: "*" }, manager)

      loader = new Brainstem.CollectionLoader(storageManager: manager)
      loader.setup(name: "projects", include: "workspaces")
      expect(expectation.loaderOptionsMatch(loader)).toBe true

      loader = new Brainstem.CollectionLoader(storageManager: manager)
      loader.setup(name: "projects", include: ["anything"])
      expect(expectation.loaderOptionsMatch(loader)).toBe true

      loader = new Brainstem.CollectionLoader(storageManager: manager)
      loader.setup(name: "projects", {})
      expect(expectation.loaderOptionsMatch(loader)).toBe true

    it "should treat strings and numbers the same when appropriate", ->
      expectation = new Brainstem.Expectation("projects", { only: "1" }, manager)

      loader = new Brainstem.CollectionLoader(storageManager: manager)
      loader.setup(name: "projects", only: 1)
      expect(expectation.loaderOptionsMatch(loader)).toBe true

      loader = new Brainstem.CollectionLoader(storageManager: manager)
      loader.setup(name: "projects", only: "1")
      expect(expectation.loaderOptionsMatch(loader)).toBe true

    it "should treat null, empty array, and empty object the same", ->
      expectation = new Brainstem.Expectation("projects", { filters: {} }, manager)

      loader = new Brainstem.CollectionLoader(storageManager: manager)
      loader.setup(name: "projects", filters: null)
      expect(expectation.loaderOptionsMatch(loader)).toBe true

      loader = new Brainstem.CollectionLoader(storageManager: manager)
      loader.setup(name: "projects", filters: {})
      expect(expectation.loaderOptionsMatch(loader)).toBe true

      loader = new Brainstem.CollectionLoader(storageManager: manager)
      loader.setup(name: "projects", {})
      expect(expectation.loaderOptionsMatch(loader)).toBe true

      loader = new Brainstem.CollectionLoader(storageManager: manager)
      loader.setup(name: "projects", filters: { foo: "bar" })
      expect(expectation.loaderOptionsMatch(loader)).toBe false

      expectation = new Brainstem.Expectation("projects", {}, manager)

      loader = new Brainstem.CollectionLoader(storageManager: manager)
      loader.setup(name: "projects", filters: null)
      expect(expectation.loaderOptionsMatch(loader)).toBe true

      loader = new Brainstem.CollectionLoader(storageManager: manager)
      loader.setup(name: "projects", filters: {})
      expect(expectation.loaderOptionsMatch(loader)).toBe true

      loader = new Brainstem.CollectionLoader(storageManager: manager)
      loader.setup(name: "projects", {})
      expect(expectation.loaderOptionsMatch(loader)).toBe true

      loader = new Brainstem.CollectionLoader(storageManager: manager)
      loader.setup(name: "projects", filters: { foo: "bar" })
      expect(expectation.loaderOptionsMatch(loader)).toBe false

  describe 'stubbing models', ->
    context 'a model that matches the load is already in the storage manager', ->
      it 'updates that model', ->
        project = buildAndCacheProject()

        expectation = manager.stubModel 'project', project.id, response: (stub) ->
          stub.result = buildProject(id: project.id, title: 'foobar')

        loaderSpy = jasmine.createSpy('loader').andCallFake (model) ->
          expect(model).toEqual project
          expect(model.get('title')).toEqual 'foobar'

        loader = manager.loadModel 'project', project.id
        loader.done(loaderSpy)

        expectation.respond()
        expect(loaderSpy).toHaveBeenCalled()
        expect(manager.storage('projects').length).toEqual 1

    context 'a model is not already in the storage manager', ->
      it 'adds the model from the loader to the storageManager', ->
        project = buildProject()
        stubbedProject = buildProject(id: project.id, title: 'foobar')

        expectation = manager.stubModel 'project', project.id, response: (stub) ->
          stub.result = stubbedProject

        loader = manager.loadModel 'project', project.id

        loaderSpy = jasmine.createSpy('loader').andCallFake (model) ->
          expect(model).toEqual loader.getModel()
          expect(model.attributes).toEqual stubbedProject.attributes
          expect(manager.storage('projects').get(project.id)).toEqual loader.getModel()
          expect(model.get('title')).toEqual 'foobar'

        loader.done(loaderSpy)

        expectation.respond()
        expect(loaderSpy).toHaveBeenCalled()
        expect(manager.storage('projects').length).toEqual 1
