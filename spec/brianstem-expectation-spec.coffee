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
      expectation = manager.stub "projects", includes: ["tasks"], response: (stub) ->
        stub.results = [project1, project2]
        stub.associated.projects = [project1, project2]
        stub.associated.tasks = [task1]
      collection = new Brainstem.Collection()
      manager.loadCollection "projects", collection: collection
      expectation.respond()
      expect(collection.get(1).get("tasks").models).toEqual [task1]
      expect(collection.get(2).get("tasks").models).toEqual []

  describe "responding immediately", ->
    it "uses stubImmediate", ->
      expectation = manager.stubImmediate "projects", includes: ["tasks"], response: (stub) ->
        stub.results = [project1, project2]
        stub.associated.tasks = [task1]
      collection = manager.loadCollection "projects"
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
      manager.stubImmediate "projects", include: ["tasks"], filters: ["something:else"], response: (stub) ->
        stub.results = [project1, project2]
        stub.associated.tasks = [task1]
      expect(manager.loadCollection("projects", include: ["tasks"], filters: ["something:else"]).models).toEqual [project1, project2]
      expect(-> manager.loadCollection("projects", include: ["tasks"], filters: ["something:wrong"])).toThrow()
      expect(-> manager.loadCollection("projects", include: ["users"], filters: ["something:else"])).toThrow()
      expect(-> manager.loadCollection("projects", filters: ["something:else"])).toThrow()
      expect(-> manager.loadCollection("projects", include: ["users"])).toThrow()
      expect(manager.loadCollection("projects").models).toEqual [project1]

    it "should ignore empty arrays", ->
      manager.stubImmediate "projects", response: (stub) ->
        stub.results = [project1, project2]
      expect(manager.loadCollection("projects", include: []).models).toEqual [project1, project2]

    it "should allow wildcard params", ->
      manager.stubImmediate "projects", include: '*', response: (stub) ->
        stub.results = [project1, project2]
      expect(manager.loadCollection("projects", include: ["tasks"]).models).toEqual [project1, project2]
      expect(manager.loadCollection("projects", include: ["users"]).models).toEqual [project1, project2]
      expect(manager.loadCollection("projects").models).toEqual [project1, project2]

  describe "recording", ->
    it "should record options", ->
      expectation = manager.stubImmediate "projects", filters: ["something:else"], response: (stub) ->
        stub.results = [project1, project2]
      manager.loadCollection("projects", filters: ["something:else"])
      expect(expectation.matches[0].filters).toEqual ["something:else"]

  describe "clearing expectations", ->
    it "expectations can be removed", ->
      expectation = manager.stub "projects", includes: ["tasks"], response: (stub) ->
        stub.results = [project1, project2]
        stub.associated.tasks = [task1]

      collection = manager.loadCollection "projects"
      expectation.respond()
      expect(collection.get(1).get("tasks").models).toEqual [task1]

      collection2 = manager.loadCollection "projects"
      expect(collection2.get(1)).toBeFalsy()
      expectation.respond()
      expect(collection2.get(1).get("tasks").models).toEqual [task1]

      expectation.remove()
      expect(-> manager.loadCollection "projects").toThrow()