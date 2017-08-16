Collection = require '../src/collection'
AbstractLoader = require '../src/loaders/abstract-loader'
CollectionLoader = require '../src/loaders/collection-loader'
Expectation = require '../src/expectation'

StorageManager = require '../src/storage-manager'


describe 'Expectations', ->
  storageManager = project1 = project2 = task1 = null

  beforeEach ->
    storageManager = StorageManager.get()
    storageManager.enableExpectations()

    project1 = buildProject(id: 1, task_ids: [1])
    project2 = buildProject(id: 2)
    task1 = buildTask(id: 1, project_id: project1.id)

  afterEach ->
    storageManager.disableExpectations()

  describe "fetch returned value", ->
    describe "xhr api", ->
      it "has abort", ->
        storageManager.stub "projects", response: (stub) ->
        collection = storageManager.storage("projects")
        expect(collection.fetch().abort).toBeDefined()

  describe "stubbing responses", ->
    it "should update returned collections", ->
      expectation = storageManager.stub "projects", response: (stub) ->
        stub.results = [project1, project2]
      collection = storageManager.loadCollection "projects"
      expect(collection.length).toEqual 0
      expectation.respond()
      expect(collection.length).toEqual 2
      expect(collection.get(1)).toEqual project1
      expect(collection.get(2)).toEqual project2

    it "should call callbacks", ->
      expectation = storageManager.stub "projects", response: (stub) ->
        stub.results = [project1, project2]
      collection = null
      storageManager.loadCollection "projects", success: (c) -> collection = c
      expect(collection).toBeNull()
      expectation.respond()
      expect(collection.length).toEqual 2
      expect(collection.get(1)).toEqual project1
      expect(collection.get(2)).toEqual project2

    it "should add to passed-in collections", ->
      expectation = storageManager.stub "projects", response: (stub) ->
        stub.results = [project1, project2]
      collection = new Collection()
      storageManager.loadCollection "projects", collection: collection
      expect(collection.length).toEqual 0
      expectation.respond()
      expect(collection.length).toEqual 2
      expect(collection.get(1)).toEqual project1
      expect(collection.get(2)).toEqual project2

    it "should work with results hashes", ->
      expectation = storageManager.stub "projects", response: (stub) ->
        stub.results = [{ key: "projects", id: 2 }, { key: "projects", id: 1 }]
        stub.associated.projects = [project1, project2]
      collection = storageManager.loadCollection "projects"
      expectation.respond()
      expect(collection.length).toEqual 2
      expect(collection.models[0]).toEqual project2
      expect(collection.models[1]).toEqual project1

    it "can populate associated objects", ->
      expectation = storageManager.stub "projects", include: ["tasks"], response: (stub) ->
        stub.results = [project1, project2]
        stub.associated.projects = [project1, project2]
        stub.associated.tasks = [task1]
      collection = new Collection()
      storageManager.loadCollection "projects", collection: collection, include: ["tasks"]
      expectation.respond()
      expect(collection.get(1).get("tasks").models).toEqual [task1]
      expect(collection.get(2).get("tasks").models).toEqual []

    context "count option is supplied", ->
      collection = null

      beforeEach ->
        expectation = storageManager.stub "projects",
          count: 20
          response: (stub) ->
            stub.results = [project1, project2]

        collection = storageManager.loadCollection "projects"
        expectation.respond()

      it "mocks cache object to return mocked count from getServerCount", ->
        expect(collection.getServerCount()).toEqual 20

    context "count option is not supplied", ->
      collection = null

      beforeEach ->
        expectation = storageManager.stub "projects",
          response: (stub) ->
            stub.results = [project1, project2]

        collection = storageManager.loadCollection "projects"
        expectation.respond()

      it "mocks cache object to return default count (result length) from getServerCount", ->
        expect(collection.getServerCount()).toEqual 2

    describe 'recursive loading', ->
      context 'recursive option is false', ->
        it "should not try to recursively load includes in an expectation", ->
          expectation = storageManager.stub "projects", include: '*', response: (stub) ->
            stub.results = [project1, project2]
            stub.associated.projects = [project1, project2]
            stub.associated.tasks = [task1]

          spy = spyOn(AbstractLoader.prototype, '_loadAdditionalIncludes')
          collection = storageManager.loadCollection "projects", include: ["tasks" : ["time_entries"]]
          expectation.respond()
          expect(spy).not.toHaveBeenCalled()

      context 'recursive option is true', ->
        it "should recursively load includes in an expectation", ->
          expectation = storageManager.stub "projects", include: '*', response: (stub) ->
            stub.results = [project1, project2]
            stub.associated.projects = [project1, project2]
            stub.associated.tasks = [task1]
            stub.recursive = true

          spy = spyOn(AbstractLoader.prototype, '_loadAdditionalIncludes')
          collection = storageManager.loadCollection "projects", include: ["tasks" : ["time_entries"]]
          expectation.respond()
          expect(spy).toHaveBeenCalled()

    describe "triggering errors", ->
      it "triggers errors when asked to do so", ->
        errorSpy = jasmine.createSpy()

        collection = new Collection()

        resp =
          readyState: 4
          status: 401
          responseText: ""

        expectation = storageManager.stub "projects", collection: collection, triggerError: resp

        storageManager.loadCollection "projects", error: errorSpy

        expectation.respond()
        expect(errorSpy).toHaveBeenCalled()
        expect(errorSpy.calls.mostRecent().args[0]).toEqual resp

      it "does not trigger errors when asked not to", ->
        errorSpy = jasmine.createSpy()
        expectation = storageManager.stub "projects", response: (exp) -> exp.results = [project1, project2]

        storageManager.loadCollection "projects", error: errorSpy

        expectation.respond()
        expect(errorSpy).not.toHaveBeenCalled()

    it "should work without specifying results", ->
      storageManager.stubImmediate "projects"
      expect(-> storageManager.loadCollection("projects")).not.toThrow()

  describe "responding immediately", ->
    it "uses stubImmediate", ->
      expectation = storageManager.stubImmediate "projects", include: ["tasks"], response: (stub) ->
        stub.results = [project1, project2]
        stub.associated.tasks = [task1]
      collection = storageManager.loadCollection "projects", include: ["tasks"]
      expect(collection.get(1).get("tasks").models).toEqual [task1]

  describe "multiple stubs", ->
    it "should match the first valid expectation", ->
      storageManager.stubImmediate "projects", only: [1], response: (stub) ->
        stub.results = [project1]
      storageManager.stubImmediate "projects", response: (stub) ->
        stub.results = [project1, project2]
      storageManager.stubImmediate "projects", only: [2], response: (stub) ->
        stub.results = [project2]
      expect(storageManager.loadCollection("projects", only: 1).models).toEqual [project1]
      expect(storageManager.loadCollection("projects").models).toEqual [project1, project2]
      expect(storageManager.loadCollection("projects", only: 2).models).toEqual [project2]

    it "should fail if it cannot find a specific match", ->
      storageManager.stubImmediate "projects", response: (stub) ->
        stub.results = [project1]
      storageManager.stubImmediate "projects", include: ["tasks"], filters: { something: "else" }, response: (stub) ->
        stub.results = [project1, project2]
        stub.associated.tasks = [task1]
      expect(storageManager.loadCollection("projects", include: ["tasks"], filters: { something: "else" }).models).toEqual [project1, project2]
      expect(-> storageManager.loadCollection("projects", include: ["tasks"], filters: { something: "wrong" })).toThrow()
      expect(-> storageManager.loadCollection("projects", include: ["users"], filters: { something: "else" })).toThrow()
      expect(-> storageManager.loadCollection("projects", filters: { something: "else" })).toThrow()
      expect(-> storageManager.loadCollection("projects", include: ["users"])).toThrow()
      expect(storageManager.loadCollection("projects").models).toEqual [project1]

    it "should ignore empty arrays", ->
      storageManager.stubImmediate "projects", response: (stub) ->
        stub.results = [project1, project2]
      expect(storageManager.loadCollection("projects", include: []).models).toEqual [project1, project2]

    it "should allow wildcard params", ->
      storageManager.stubImmediate "projects", include: '*', response: (stub) ->
        stub.results = [project1, project2]
        stub.associated.tasks = [task1]
      expect(storageManager.loadCollection("projects", include: ["tasks"]).models).toEqual [project1, project2]
      expect(storageManager.loadCollection("projects", include: ["users"]).models).toEqual [project1, project2]
      expect(storageManager.loadCollection("projects").models).toEqual [project1, project2]

  describe "recording", ->
    it "should record options", ->
      expectation = storageManager.stubImmediate "projects", filters: { something: "else" }, response: (stub) ->
        stub.results = [project1, project2]
      storageManager.loadCollection("projects", filters: { something: "else" })
      expect(expectation.matches[0].filters).toEqual { something: "else" }

  describe "clearing expectations", ->
    it "expectations can be removed", ->
      expectation = storageManager.stub "projects", include: ["tasks"], response: (stub) ->
        stub.results = [project1, project2]
        stub.associated.tasks = [task1]

      collection = storageManager.loadCollection "projects", include: ["tasks"]
      expectation.respond()
      expect(collection.get(1).get("tasks").models).toEqual [task1]

      collection2 = storageManager.loadCollection "projects", include: ["tasks"]
      expect(collection2.get(1)).toBeFalsy()
      expectation.respond()
      expect(collection2.get(1).get("tasks").models).toEqual [task1]

      expectation.remove()
      expect(-> storageManager.loadCollection "projects").toThrow()

  describe "lastMatch", ->
    it "retrives the last match object", ->
      expectation = storageManager.stubImmediate "projects", include: "*", response: (stub) ->
        stub.results = []

      storageManager.loadCollection("projects", include: ["tasks"])
      storageManager.loadCollection("projects", include: ["users"])

      expect(expectation.matches.length).toEqual(2)
      expect(expectation.lastMatch().include).toEqual(["users"])

    it "returns undefined if no matches exist", ->
      expectation = storageManager.stub "projects", response: (stub) ->
        stub.results = []
      expect(expectation.lastMatch()).toBeUndefined()

  describe "loaderOptionsMatch", ->
    it "should ignore wrapping arrays", ->
      expectation = new Expectation("projects", { include: "workspaces" }, storageManager)
      loader = new CollectionLoader(storageManager: storageManager)

      loader.setup(name: "projects", include: "workspaces")
      expect(expectation.loaderOptionsMatch(loader)).toBe true

      loader.setup(name: "projects", include: ["workspaces"])
      expect(expectation.loaderOptionsMatch(loader)).toBe true

    it "should treat * as an any match", ->
      expectation = new Expectation("projects", { include: "*" }, storageManager)

      loader = new CollectionLoader(storageManager: storageManager)
      loader.setup(name: "projects", include: "workspaces")
      expect(expectation.loaderOptionsMatch(loader)).toBe true

      loader = new CollectionLoader(storageManager: storageManager)
      loader.setup(name: "projects", include: ["anything"])
      expect(expectation.loaderOptionsMatch(loader)).toBe true

      loader = new CollectionLoader(storageManager: storageManager)
      loader.setup(name: "projects", {})
      expect(expectation.loaderOptionsMatch(loader)).toBe true

    it "should treat strings and numbers the same when appropriate", ->
      expectation = new Expectation("projects", { only: "1" }, storageManager)

      loader = new CollectionLoader(storageManager: storageManager)
      loader.setup(name: "projects", only: 1)
      expect(expectation.loaderOptionsMatch(loader)).toBe true

      loader = new CollectionLoader(storageManager: storageManager)
      loader.setup(name: "projects", only: "1")
      expect(expectation.loaderOptionsMatch(loader)).toBe true

    it "should treat null, empty array, and empty object the same", ->
      expectation = new Expectation("projects", { filters: {} }, storageManager)

      loader = new CollectionLoader(storageManager: storageManager)
      loader.setup(name: "projects", filters: null)
      expect(expectation.loaderOptionsMatch(loader)).toBe true

      loader = new CollectionLoader(storageManager: storageManager)
      loader.setup(name: "projects", filters: {})
      expect(expectation.loaderOptionsMatch(loader)).toBe true

      loader = new CollectionLoader(storageManager: storageManager)
      loader.setup(name: "projects", {})
      expect(expectation.loaderOptionsMatch(loader)).toBe true

      loader = new CollectionLoader(storageManager: storageManager)
      loader.setup(name: "projects", filters: { foo: "bar" })
      expect(expectation.loaderOptionsMatch(loader)).toBe false

      expectation = new Expectation("projects", {}, storageManager)

      loader = new CollectionLoader(storageManager: storageManager)
      loader.setup(name: "projects", filters: null)
      expect(expectation.loaderOptionsMatch(loader)).toBe true

      loader = new CollectionLoader(storageManager: storageManager)
      loader.setup(name: "projects", filters: {})
      expect(expectation.loaderOptionsMatch(loader)).toBe true

      loader = new CollectionLoader(storageManager: storageManager)
      loader.setup(name: "projects", {})
      expect(expectation.loaderOptionsMatch(loader)).toBe true

      loader = new CollectionLoader(storageManager: storageManager)
      loader.setup(name: "projects", filters: { foo: "bar" })
      expect(expectation.loaderOptionsMatch(loader)).toBe false

    context 'when collection loader is given valid options', ->
      expected_include = expected_filters = expected_page = expected_perPage = expected_limit_offset = null
      expected_order = expected_search = expected_cacheKey = expected_optionalFields = null

      beforeEach ->
        expected_include = new Expectation("projects", {include:{}}, storageManager)
        expected_filters = new Expectation("projects", {filters:{}}, storageManager)
        expected_page = new Expectation("projects", {page:{}}, storageManager)
        expected_perPage = new Expectation("projects", {perPage:{}}, storageManager)
        expected_limit_offset = new Expectation("projects", {limit:'1', offset:'20'}, storageManager)
        expected_order = new Expectation("projects", {order:{}}, storageManager)
        expected_search = new Expectation("projects", {search:{}}, storageManager)
        expected_cacheKey = new Expectation("projects", {cacheKey:{}}, storageManager)
        expected_optionalFields = new Expectation("projects", {optionalFields:{}}, storageManager)

      context 'when loaded values match expected values', ->
        it 'expects loader to be valid', ->
          loader = new CollectionLoader(storageManager: storageManager)
          loader.setup(name: "projects", include:{})
          expect(expected_include.loaderOptionsMatch(loader)).toBe true

          loader = new CollectionLoader(storageManager: storageManager)
          loader.setup(name: "projects", filters:{})
          expect(expected_filters.loaderOptionsMatch(loader)).toBe true

          loader = new CollectionLoader(storageManager: storageManager)
          loader.setup(name: "projects", page:{})
          expect(expected_page.loaderOptionsMatch(loader)).toBe true

          loader = new CollectionLoader(storageManager: storageManager)
          loader.setup(name: "projects", perPage:{})
          expect(expected_perPage.loaderOptionsMatch(loader)).toBe true

          # limit and offset must be present, or this will always return false
          # this is due to storage-manager._checkPageSettings
          loader = new CollectionLoader(storageManager: storageManager)
          loader.setup(name: "projects",limit:'1', offset:'20')
          expect(expected_limit_offset.loaderOptionsMatch(loader)).toBe true

          loader = new CollectionLoader(storageManager: storageManager)
          loader.setup(name: "projects", order:{})
          expect(expected_order.loaderOptionsMatch(loader)).toBe true

          loader = new CollectionLoader(storageManager: storageManager)
          loader.setup(name: "projects", search:{})
          expect(expected_search.loaderOptionsMatch(loader)).toBe true

          loader = new CollectionLoader(storageManager: storageManager)
          loader.setup(name: "projects", cacheKey:{})
          expect(expected_cacheKey.loaderOptionsMatch(loader)).toBe true

          loader = new CollectionLoader(storageManager: storageManager)
          loader.setup(name: "projects", optionalFields:{})
          expect(expected_optionalFields.loaderOptionsMatch(loader)).toBe true

      context 'when loaded values do not match expected values', ->
        it 'expects the loader to not be valid', ->
          loader = new CollectionLoader(storageManager: storageManager)
          loader.setup(name: "projects", include:{foo:'bar'})
          expect(expected_include.loaderOptionsMatch(loader)).toBe false

          loader = new CollectionLoader(storageManager: storageManager)
          loader.setup(name: "projects", filters:{foo:'bar'})
          expect(expected_filters.loaderOptionsMatch(loader)).toBe false

          loader = new CollectionLoader(storageManager: storageManager)
          loader.setup(name: "projects", page:{foo:'bar'})
          expect(expected_page.loaderOptionsMatch(loader)).toBe false

          loader = new CollectionLoader(storageManager: storageManager)
          loader.setup(name: "projects", perPage:{foo:'bar'})
          expect(expected_perPage.loaderOptionsMatch(loader)).toBe false

          # limit and offset must be present, or this will always return false
          # this is due to storage-manager._checkPageSettings
          loader = new CollectionLoader(storageManager: storageManager)
          loader.setup(name: "projects",limit: '1',offset:'25')
          expect(expected_limit_offset.loaderOptionsMatch(loader)).toBe false
          loader.setup(name: "projects",limit: '3',offset:'20')
          expect(expected_limit_offset.loaderOptionsMatch(loader)).toBe false
          loader.setup(name: "projects",limit: '3',offset:'25')
          expect(expected_limit_offset.loaderOptionsMatch(loader)).toBe false
          loader.setup(name: "projects",limit: '1')
          expect(expected_limit_offset.loaderOptionsMatch(loader)).toBe false
          loader.setup(name: "projects",offset:'20')
          expect(expected_limit_offset.loaderOptionsMatch(loader)).toBe false

          loader = new CollectionLoader(storageManager: storageManager)
          loader.setup(name: "projects", order:{foo:'bar'})
          expect(expected_order.loaderOptionsMatch(loader)).toBe false

          loader = new CollectionLoader(storageManager: storageManager)
          loader.setup(name: "projects", search:{foo:'bar'})
          expect(expected_search.loaderOptionsMatch(loader)).toBe false

          loader = new CollectionLoader(storageManager: storageManager)
          loader.setup(name: "projects", cacheKey:{foo:'bar'})
          expect(expected_cacheKey.loaderOptionsMatch(loader)).toBe false

          loader = new CollectionLoader(storageManager: storageManager)
          loader.setup(name: "projects", optionalFields:{foo:'bar'})
          expect(expected_optionalFields.loaderOptionsMatch(loader)).toBe false

  describe 'stubbing models', ->
    context 'a model that matches the load is already in the storage storageManager', ->
      it 'updates that model', ->
        project = buildAndCacheProject()

        expectation = storageManager.stubModel 'project', project.id, response: (stub) ->
          stub.result = buildProject(id: project.id, title: 'foobar')

        loaderSpy = jasmine.createSpy('loader').and.callFake (model) ->
          expect(model.id).toEqual project.id
          expect(model.get('title')).toEqual 'foobar'

        loader = storageManager.loadModel 'project', project.id
        loader.done(loaderSpy)

        expectation.respond()
        expect(loaderSpy).toHaveBeenCalled()
        expect(storageManager.storage('projects').length).toEqual 1

    context 'a model is not already in the storage storageManager', ->
      it 'adds the model from the loader to the storageManager', ->
        project = buildProject()
        stubbedProject = buildProject(id: project.id, title: 'foobar')

        expectation = storageManager.stubModel 'project', project.id, response: (stub) ->
          stub.result = stubbedProject

        loader = storageManager.loadModel 'project', project.id

        loaderSpy = jasmine.createSpy('loader').and.callFake (model) ->
          expect(model).toEqual loader.getModel()
          expect(model.attributes).toEqual stubbedProject.attributes
          expect(storageManager.storage('projects').get(project.id)).toEqual loader.getModel()
          expect(model.get('title')).toEqual 'foobar'

        loader.done(loaderSpy)

        expectation.respond()
        expect(loaderSpy).toHaveBeenCalled()
        expect(storageManager.storage('projects').length).toEqual 1
