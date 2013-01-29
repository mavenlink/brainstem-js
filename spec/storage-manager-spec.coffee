describe 'Storage Manager', ->
  manager = null

  beforeEach ->
    manager = new App.StorageManager()

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
      createStory()
      createWorkspace()
      expect(base.data.storage("workspaces").length).toEqual 1
      expect(base.data.storage("stories").length).toEqual 1
      base.data.collections["workspaces"].sortLengths = { "foo": "bar" }
      base.data.reset()
      expect(base.data.collections["workspaces"].sortLengths).toEqual {}
      expect(base.data.storage("workspaces").length).toEqual 0
      expect(base.data.storage("stories").length).toEqual 0

  describe "loadModel", ->
    beforeEach ->
      stories = [buildStory(id: 2, title: "a story", workspace_id: 15)]
      workspaces = [buildWorkspace(id: 15)]
      timeEntries = [buildTimeEntry(story_id: 2, workspace_id: 15, id: 1, title: "a time entry")]
      server.respondWith "GET", "/api/time_entries?only=1", [ 200, {"Content-Type": "application/json"}, JSON.stringify(time_entries: timeEntries) ]
      server.respondWith "GET", "/api/time_entries?include=workspace%3Bstory&only=1", [ 200, {"Content-Type": "application/json"}, JSON.stringify(time_entries: timeEntries, stories: stories, workspaces: workspaces) ]

    it "loads a single model from the server, including associations", ->
      model = base.data.loadModel "time_entry", 1, include: ["workspace", "story"]
      expect(model.loaded).toBe false
      server.respond()
      expect(model.loaded).toBe true
      expect(model.id).toEqual 1
      expect(model.get("title")).toEqual "a time entry"
      expect(model.get('story').get('title')).toEqual "a story"
      expect(model.get('workspace').id).toEqual 15

    it "works even when the server returned associations of the same type", ->
      posts = [buildPost(id: 2, reply: true), buildPost(id: 3, reply: true), buildPost(id: 1, reply: false, reply_ids: [2, 3])]
      server.respondWith "GET", "/api/posts?include=replies&only=1", [ 200, {"Content-Type": "application/json"}, JSON.stringify(posts: posts) ]
      model = base.data.loadModel "post", 1, include: ["replies"]
      expect(model.loaded).toBe false
      server.respond()
      expect(model.loaded).toBe true
      expect(model.id).toEqual 1
      expect(model.get("replies").pluck("id")).toEqual [2, 3]

    it "triggers changes", ->
      model = base.data.loadModel "time_entry", 1, include: ["workspace", "story"]
      spy = jasmine.createSpy().andCallFake ->
        expect(model.loaded).toBe true
        expect(model.get("title")).toEqual "a time entry"
        expect(model.get('story').get('title')).toEqual "a story"
        expect(model.get('workspace').id).toEqual 15
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

  describe 'loadCollection', ->
    it "loads a collection of models", ->
      server.respondWith "GET", "/api/time_entries?per_page=20&page=1", [ 200, {"Content-Type": "application/json"}, JSON.stringify(time_entries: [buildTimeEntry(), buildTimeEntry()]) ]
      collection = base.data.loadCollection "time_entries"
      expect(collection.length).toBe 0
      server.respond()
      expect(collection.length).toBe 2

    it "accepts a success function", ->
      server.respondWith "GET", "/api/time_entries?per_page=20&page=1", [ 200, {"Content-Type": "application/json"}, JSON.stringify(time_entries: [buildTimeEntry(), buildTimeEntry()]) ]
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
        server.respondWith "GET", "/api/time_entries?per_page=20&page=1", [ 200, {"Content-Type": "application/json"}, JSON.stringify(time_entries: [buildTimeEntry()]) ]
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
        server.respondWith "GET", "/api/time_entries?per_page=20&page=1", [ 200, {"Content-Type": "application/json"}, JSON.stringify(time_entries: [buildTimeEntry()]) ]
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
      server.respondWith "GET", "/api/time_entries?per_page=20&page=1", [ 200, {"Content-Type": "application/json"}, JSON.stringify(time_entries: [buildTimeEntry(), buildTimeEntry()]) ]
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
        stories = [buildStory(id: 2, title: "a story")]
        workspaces = [buildWorkspace(id: 15), buildWorkspace(id: 10)]
        timeEntries = [buildTimeEntry(story_id: 2, workspace_id: 15, id: 1), buildTimeEntry(story_id: null, workspace_id: 10, id: 2)]
        server.respondWith "GET", /\/api\/time_entries\?include=workspace%3Bstory&per_page=\d+&page=\d+/, [ 200, {"Content-Type": "application/json"}, JSON.stringify(time_entries: timeEntries, stories: stories, workspaces: workspaces) ]
        server.respondWith "GET", /\/api\/time_entries\?include=workspace&per_page=\d+&page=\d+/, [ 200, {"Content-Type": "application/json"}, JSON.stringify(time_entries: timeEntries, workspaces: workspaces) ]

      it "loads collections that should be included", ->
        collection = base.data.loadCollection "time_entries", include: ["workspace", "story"]
        spy = jasmine.createSpy().andCallFake ->
          expect(collection.loaded).toBe true
          expect(collection.get(1).get('story').get('title')).toEqual "a story"
          expect(collection.get(2).get('story')).toBeFalsy()
          expect(collection.get(1).get('workspace').id).toEqual 15
          expect(collection.get(2).get('workspace').id).toEqual 10
        collection.bind "reset", spy
        expect(collection.loaded).toBe false
        server.respond()
        expect(collection.loaded).toBe true
        expect(spy).toHaveBeenCalled()

      it "applies filters when loading collections from the server (so that associations of the same type as the primary can be handled- posts with replies; stories with substories, etc.)", ->
        posts = [buildPost(workspace_id: 15, id: 1, reply_ids: [2]), buildPost(workspace_id: 15, id: 2, subject_id: 1, reply: true)]
        server.respondWith "GET", "/api/posts?include=replies&filters=parents_only%3Atrue&per_page=20&page=1", [ 200, {"Content-Type": "application/json"}, JSON.stringify(posts: posts) ]
        collection = base.data.loadCollection "posts", include: ["replies"], filters: "parents_only:true"
        server.respond()
        expect(collection.pluck("id")).toEqual [1]
        expect(collection.get(1).get('replies').pluck("id")).toEqual [2]

      describe "fetching multiple levels of associations", ->
        # We cannot have default filters that restrict the dataset.  At least not for only queries.
        it "seperately requests each layer of associations", ->
          workspaceOneTimeEntryStory = buildStory()
          workspaceOneTimeEntry = buildTimeEntry(title: "without story"); workspaceOneTimeEntryWithStory = buildTimeEntry(id: workspaceOneTimeEntry.id, story_id: workspaceOneTimeEntryStory.id, title: "with story")
          workspaceOne = buildWorkspace(); workspaceOneWithTimeEntries = buildWorkspace(id: workspaceOne.id, time_entry_ids: [workspaceOneTimeEntry.id])
          workspaceTwo = buildWorkspace(); workspaceTwoWithTimeEntries = buildWorkspace(id: workspaceTwo.id, time_entry_ids: [])
          storyOneAssignee = buildUser()
          storyTwoAssignee = buildUser()
          storyOneSubAssignee = buildUser()
          storyOneSub = buildStory(workspace_id: workspaceOne.id, parent_id: 10); storyOneSubWithAssignees = buildStory(id: storyOneSub.id, assignee_ids: [storyOneSubAssignee.id], parent_id: 10)
          storyTwoSub = buildStory(workspace_id: workspaceTwo.id, parent_id: 11); storyTwoSubWithAssignees = buildStory(id: storyTwoSub.id, assignee_ids: [storyTwoAssignee.id], parent_id: 11)
          storyOne = buildStory(id: 10, workspace_id: workspaceOne.id, assignee_ids: [storyOneAssignee.id], sub_story_ids: [storyOneSub])
          storyTwo = buildStory(id: 11, workspace_id: workspaceTwo.id, assignee_ids: [storyTwoAssignee.id], sub_story_ids: [storyTwoSub])

          server.respondWith "GET", "/api/stories.json?include=assignees%3Bworkspace%3Bsub_stories&filters=parents_only%3Atrue&per_page=20&page=1",
              [ 200, {"Content-Type": "application/json"}, JSON.stringify(stories: [storyOne, storyTwo, storyOneSub, storyTwoSub], users: [storyOneAssignee, storyTwoAssignee], workspaces: [workspaceOne, workspaceTwo]) ]

          server.respondWith "GET", "/api/stories.json?include=assignees&only=#{storyOneSub.id}%2C#{storyTwoSub.id}",
              [ 200, {"Content-Type": "application/json"}, JSON.stringify(stories: [storyOneSubWithAssignees, storyTwoSubWithAssignees], users: [storyOneSubAssignee, storyTwoAssignee]) ]

          server.respondWith "GET", "/api/workspaces?include=time_entries&only=#{workspaceOne.id}%2C#{workspaceTwo.id}",
              [ 200, {"Content-Type": "application/json"}, JSON.stringify(workspaces: [workspaceOneWithTimeEntries, workspaceTwoWithTimeEntries], time_entries: [workspaceOneTimeEntry]) ]

          server.respondWith "GET", "/api/time_entries?include=story&only=#{workspaceOneTimeEntry.id}",
              [ 200, {"Content-Type": "application/json"}, JSON.stringify(time_entries: [workspaceOneTimeEntryWithStory], stories: [workspaceOneTimeEntryStory]) ]

          callCount = 0
          checkStructure = (collection) ->
            expect(collection.pluck("id").sort()).toEqual [storyOne.id, storyTwo.id]
            expect(collection.get(storyOne.id).get("workspace").id).toEqual workspaceOne.id
            expect(collection.get(storyOne.id).get("assignees").pluck("id")).toEqual [storyOneAssignee.id]
            expect(collection.get(storyTwo.id).get("assignees").pluck("id")).toEqual [storyTwoAssignee.id]
            expect(collection.get(storyOne.id).get("sub_stories").pluck("id")).toEqual [storyOneSub.id]
            expect(collection.get(storyTwo.id).get("sub_stories").pluck("id")).toEqual [storyTwoSub.id]
            expect(collection.get(storyOne.id).get("sub_stories").get(storyOneSub.id).get("assignees").pluck("id")).toEqual [storyOneSubAssignee.id]
            expect(collection.get(storyTwo.id).get("sub_stories").get(storyTwoSub.id).get("assignees").pluck("id")).toEqual [storyTwoAssignee.id]
            expect(collection.get(storyOne.id).get("workspace").get("time_entries").pluck("id")).toEqual [workspaceOneTimeEntry.id]
            expect(collection.get(storyOne.id).get("workspace").get("time_entries").models[0].get("story").id).toEqual workspaceOneTimeEntryStory.id
            callCount += 1

          success = jasmine.createSpy().andCallFake checkStructure
          collection = base.data.loadCollection "stories", filters: "parents_only:true", success: success, include: [
                                                                      "assignees",
                                                                      "workspace": ["time_entries": "story"],
                                                                      "sub_stories": ["assignees"]
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
            collection1 = base.data.loadCollection "time_entries", include: ["workspace", "story"], page: 1, perPage: 2
            server.respond()
            expect(collection1.loaded).toBe true
            spy = jasmine.createSpy()
            collection2 = base.data.loadCollection "time_entries", include: ["workspace", "story"], page: 1, perPage: 2, success: spy
            expect(spy).toHaveBeenCalled()
            expect(collection2.loaded).toBe true
            expect(collection2.get(1).get('story').get('title')).toEqual "a story"
            expect(collection2.get(2).get('story')).toBeFalsy()
            expect(collection2.get(1).get('workspace').id).toEqual 15
            expect(collection2.get(2).get('workspace').id).toEqual 10

          it "does go to the server when more records are requested than it has previously requested, and remembers previously requested pages", ->
            collection1 = base.data.loadCollection "time_entries", include: ["workspace", "story"], page: 1, perPage: 2
            server.respond()
            expect(collection1.loaded).toBe true
            collection2 = base.data.loadCollection "time_entries", include: ["workspace", "story"], page: 2, perPage: 2
            expect(collection2.loaded).toBe false
            server.respond()
            expect(collection2.loaded).toBe true
            collection3 = base.data.loadCollection "time_entries", include: ["workspace"], page: 1, perPage: 2
            expect(collection3.loaded).toBe true

          it "does go to the server when some associations are missing, when otherwise it would have the data", ->
            collection1 = base.data.loadCollection "time_entries", include: ["workspace"], page: 1, perPage: 2
            server.respond()
            expect(collection1.loaded).toBe true
            collection2 = base.data.loadCollection "time_entries", include: ["workspace", "story"], page: 1, perPage: 2
            expect(collection2.loaded).toBe false

          it "goes to the server when a page size change neccesitates it", ->
            collection1 = base.data.loadCollection "time_entries", include: ["workspace"], page: 1, perPage: 2
            server.respond()
            expect(collection1.loaded).toBe true
            collection2 = base.data.loadCollection "time_entries", include: ["workspace"], page: 1, perPage: 1
            expect(collection2.loaded).toBe true
            collection3 = base.data.loadCollection "time_entries", include: ["workspace"], page: 1, perPage: 3
            expect(collection3.loaded).toBe false

          it "raises an error when more than one additional page is requested", ->
            collection1 = base.data.loadCollection "time_entries", include: ["workspace"], page: 1, perPage: 2
            server.respond()
            expect(collection1.loaded).toBe true

            collection1 = base.data.loadCollection "time_entries", include: ["workspace"], page: 3, perPage: 1
            expect(collection1.loaded).toBe false

            expect(-> base.data.loadCollection "time_entries", include: ["workspace"], page: 3, perPage: 2).toThrow()
            expect(-> base.data.loadCollection "time_entries", include: ["workspace"], page: 4, perPage: 2).toThrow()
            expect(-> base.data.loadCollection "time_entries", include: ["workspace"], page: 4, perPage: 1).toThrow()
            expect(-> base.data.loadCollection "time_entries", include: ["workspace"], page: 5, perPage: 1).toThrow()

        describe "with ordering and filtering", ->
          now = ws10 = ws11 = te1Ws10 = te2Ws10 = te1Ws11 = te2Ws11 = null

          beforeEach ->
            now = (new Date()).getTime() / 1000
            ws10 = buildWorkspace(id: 10)
            ws11 = buildWorkspace(id: 11)
            te1Ws10 = buildTimeEntry(story_id: null, workspace_id: 10, id: 1, created_at: now - 20, updated_at: now - 10)
            te2Ws10 = buildTimeEntry(story_id: null, workspace_id: 10, id: 2, created_at: now - 10, updated_at: now - 5)
            te1Ws11 = buildTimeEntry(story_id: null, workspace_id: 11, id: 3, created_at: now - 100, updated_at: now - 4)
            te2Ws11 = buildTimeEntry(story_id: null, workspace_id: 11, id: 4, created_at: now - 200, updated_at: now - 12)

          it "cuts pages correctly in the client", ->
            server.respondWith "GET", "/api/time_entries?order=created_at%3Aasc&per_page=2&page=1", [ 200, {"Content-Type": "application/json"},
              JSON.stringify(time_entries: [te2Ws11, te1Ws11]) ]
            server.respondWith "GET", "/api/time_entries?order=created_at%3Aasc&per_page=2&page=2", [ 200, {"Content-Type": "application/json"},
              JSON.stringify(time_entries: [te1Ws10, te2Ws10]) ]

            collection = base.data.loadCollection "time_entries", order: "created_at:asc", page: 1, perPage: 2
            server.respond()
            expect(collection.pluck("id")).toEqual [te2Ws11.id, te1Ws11.id]
            base.data.loadCollection "time_entries", collection: collection, order: "created_at:asc", page: 2, perPage: 2
            server.respond()
            expect(collection.pluck("id")).toEqual [te2Ws11.id, te1Ws11.id, te1Ws10.id, te2Ws10.id]

          it "seperately keeps track of the depth of data requested by sort order and filter", ->
            server.responses = []

            server.respondWith "GET", "/api/time_entries?include=workspace%3Bstory&order=updated_at%3Adesc&filters=workspace_id%3A10&per_page=2&page=1", [ 200, {"Content-Type": "application/json"},
              JSON.stringify(time_entries: [te2Ws10, te1Ws10], stories: [], workspaces: [ws10]) ]
            server.respondWith "GET", "/api/time_entries?include=workspace%3Bstory&order=updated_at%3Adesc&filters=workspace_id%3A11&per_page=2&page=1", [ 200, {"Content-Type": "application/json"},
              JSON.stringify(time_entries: [te1Ws11, te2Ws11], stories: [], workspaces: [ws11]) ]
            server.respondWith "GET", "/api/time_entries?include=workspace%3Bstory&order=created_at%3Aasc&filters=workspace_id%3A11&per_page=2&page=1", [ 200, {"Content-Type": "application/json"},
              JSON.stringify(time_entries: [te2Ws11, te1Ws11], stories: [], workspaces: [ws11]) ]
            server.respondWith "GET", "/api/time_entries?include=workspace%3Bstory&order=created_at%3Aasc&per_page=4&page=1", [ 200, {"Content-Type": "application/json"},
              JSON.stringify(time_entries: [te2Ws11, te1Ws11, te1Ws10, te2Ws10], stories: [], workspaces: [ws10, ws11]) ]
            server.respondWith "GET", "/api/time_entries?include=workspace%3Bstory&per_page=4&page=1", [ 200, {"Content-Type": "application/json"},
              JSON.stringify(time_entries: [te1Ws11, te2Ws10, te1Ws10, te2Ws11], stories: [], workspaces: [ws10, ws11]) ]

            # Make a server request
            collection1 = base.data.loadCollection "time_entries", include: ["workspace", "story"], order: "updated_at:desc", filters: ["workspace_id:10"], page: 1, perPage: 2
            expect(collection1.loaded).toBe false
            server.respond()
            expect(collection1.loaded).toBe true
            expect(collection1.pluck("id")).toEqual [te2Ws10.id, te1Ws10.id] # Show that it came back in the explicit order setup above
            # Make another request, this time handled by the cache.
            collection2 = base.data.loadCollection "time_entries", include: ["workspace", "story"], order: "updated_at:desc", filters: ["workspace_id:10"], page: 1, perPage: 2
            expect(collection2.loaded).toBe true
            expect(collection2.pluck("id")).toEqual [te2Ws10.id, te1Ws10.id] # Show that it also came back in the correct order.

            # Do it again, this time with a different filter.
            collection3 = base.data.loadCollection "time_entries", include: ["workspace", "story"], order: "updated_at:desc", filters: ["workspace_id:11"], page: 1, perPage: 2
            expect(collection3.loaded).toBe false
            server.respond()
            expect(collection3.loaded).toBe true
            expect(collection3.pluck("id")).toEqual [te1Ws11.id, te2Ws11.id]
            collection4 = base.data.loadCollection "time_entries", include: ["workspace"], order: "updated_at:desc", filters: ["workspace_id:11"], page: 1, perPage: 2
            expect(collection4.loaded).toBe true
            expect(collection4.pluck("id")).toEqual [te1Ws11.id, te2Ws11.id]

            # Do it again, this time with a different order.
            collection5 = base.data.loadCollection "time_entries", include: ["workspace", "story"], order: "created_at:asc", filters: ["workspace_id:11"], page: 1, perPage: 2
            expect(collection5.loaded).toBe false
            server.respond()
            expect(collection5.loaded).toBe true
            expect(collection5.pluck("id")).toEqual [te2Ws11.id, te1Ws11.id]
            collection6 = base.data.loadCollection "time_entries", include: ["story"], order: "created_at:asc", filters: ["workspace_id:11"], page: 1, perPage: 2
            expect(collection6.loaded).toBe true
            expect(collection6.pluck("id")).toEqual [te2Ws11.id, te1Ws11.id]

            # Do it again, this time without a filter.
            collection7 = base.data.loadCollection "time_entries", include: ["workspace", "story"], order: "created_at:asc", page: 1, perPage: 4
            expect(collection7.loaded).toBe false
            server.respond()
            expect(collection7.loaded).toBe true
            expect(collection7.pluck("id")).toEqual [te2Ws11.id, te1Ws11.id, te1Ws10.id, te2Ws10.id]
            collection8 = base.data.loadCollection "time_entries", include: ["workspace", "story"], order: "created_at:asc", page: 1, perPage: 3
            expect(collection8.loaded).toBe true
            expect(collection8.pluck("id")).toEqual [te2Ws11.id, te1Ws11.id, te1Ws10.id]

            # Do it again, this time without an order, so it should use the default (updated_at:desc).
            collection9 = base.data.loadCollection "time_entries", include: ["workspace", "story"], page: 1, perPage: 4
            expect(collection9.loaded).toBe false
            server.respond()
            expect(collection9.loaded).toBe true
            expect(collection9.pluck("id")).toEqual [te1Ws11.id, te2Ws10.id, te1Ws10.id, te2Ws11.id]
            collection10 = base.data.loadCollection "time_entries", include: ["workspace", "story"], page: 1, perPage: 3
            expect(collection10.loaded).toBe true
            expect(collection10.pluck("id")).toEqual [te1Ws11.id, te2Ws10.id, te1Ws10.id]

    describe "handling of only", ->
      describe "when getting data from the server", ->
        it "returns the requested ids with includes, triggering reset and success", ->
          server.respondWith "GET", "/api/time_entries?include=workspace%3Bstory&only=2", [ 200, {"Content-Type": "application/json"}, JSON.stringify(time_entries: [buildTimeEntry(story_id: null, workspace_id: 10, id: 2)], stories: [], workspaces: [buildWorkspace(id: 10)]) ]

          spy2 = jasmine.createSpy().andCallFake (collection) ->
            expect(collection.loaded).toBe true
          collection = base.data.loadCollection "time_entries", include: ["workspace", "story"], only: 2, success: spy2
          spy = jasmine.createSpy().andCallFake ->
            expect(collection.loaded).toBe true
            expect(collection.get(2).get('story')).toBeFalsy()
            expect(collection.get(2).get('workspace').id).toEqual 10
            expect(collection.length).toEqual 1
          collection.bind "reset", spy
          expect(collection.loaded).toBe false
          server.respond()
          expect(collection.loaded).toBe true
          expect(spy).toHaveBeenCalled()
          expect(spy2).toHaveBeenCalled()

        it "only requests ids that we don't already have", ->
          server.respondWith "GET", "/api/time_entries?include=workspace%3Bstory&only=2", [ 200, {"Content-Type": "application/json"}, JSON.stringify(time_entries: [buildTimeEntry(story_id: null, workspace_id: 10, id: 2)], stories: [], workspaces: [buildWorkspace(id: 10)]) ]
          server.respondWith "GET", "/api/time_entries?include=workspace%3Bstory&only=3", [ 200, {"Content-Type": "application/json"}, JSON.stringify(time_entries: [buildTimeEntry(story_id: null, workspace_id: 11, id: 3)], stories: [], workspaces: [buildWorkspace(id: 11)]) ]

          collection = base.data.loadCollection "time_entries", include: ["workspace", "story"], only: 2
          expect(collection.loaded).toBe false
          server.respond()
          expect(collection.loaded).toBe true
          expect(collection.get(2).get('workspace').id).toEqual 10
          collection2 = base.data.loadCollection "time_entries", include: ["workspace", "story"], only: [2, 3]
          expect(collection2.loaded).toBe false
          server.respond()
          expect(collection2.loaded).toBe true
          expect(collection2.get(2).get('workspace').id).toEqual 10
          expect(collection2.get(3).get('workspace').id).toEqual 11
          expect(collection2.length).toEqual 2

        it "does request ids from the server again when they don't have all associations loaded yet", ->
          server.respondWith "GET", "/api/time_entries?include=workspace&only=2", [ 200, {"Content-Type": "application/json"}, JSON.stringify(time_entries: [buildTimeEntry(workspace_id: 10, id: 2, story_id: 5)], workspaces: [buildWorkspace(id: 10)]) ]
          server.respondWith "GET", "/api/time_entries?include=workspace%3Bstory&only=2", [ 200, {"Content-Type": "application/json"}, JSON.stringify(time_entries: [buildTimeEntry(workspace_id: 10, id: 2, story_id: 5)], stories: [buildStory(id: 5)], workspaces: [buildWorkspace(id: 10)]) ]
          server.respondWith "GET", "/api/time_entries?include=workspace%3Bstory&only=3", [ 200, {"Content-Type": "application/json"}, JSON.stringify(time_entries: [buildTimeEntry(workspace_id: 11, id: 3, story_id: null)], stories: [], workspaces: [buildWorkspace(id: 11)]) ]

          base.data.loadCollection "time_entries", include: ["workspace"], only: 2
          server.respond()
          base.data.loadCollection "time_entries", include: ["workspace", "story"], only: 3
          server.respond()
          collection2 = base.data.loadCollection "time_entries", include: ["workspace", "story"], only: [2, 3]
          expect(collection2.loaded).toBe false
          server.respond()
          expect(collection2.loaded).toBe true
          expect(collection2.get(2).get('story').id).toEqual 5
          expect(collection2.length).toEqual 2

        it "doesn't go to the server if it doesn't need to", ->
          server.respondWith "GET", "/api/time_entries?include=workspace%3Bstory&only=2%2C3", [ 200, {"Content-Type": "application/json"}, JSON.stringify(time_entries: [buildTimeEntry(workspace_id: 10, id: 2, story_id: null), buildTimeEntry(workspace_id: 11, id: 3)], stories: [], workspaces: [buildWorkspace(id: 10), buildWorkspace(id: 11)]) ]
          collection = base.data.loadCollection "time_entries", include: ["workspace", "story"], only: [2, 3]
          expect(collection.loaded).toBe false
          server.respond()
          expect(collection.loaded).toBe true
          expect(collection.get(2).get('workspace').id).toEqual 10
          expect(collection.get(3).get('workspace').id).toEqual 11
          expect(collection.length).toEqual 2
          spy = jasmine.createSpy()
          collection2 = base.data.loadCollection "time_entries", include: ["workspace"], only: [2, 3], success: spy
          expect(spy).toHaveBeenCalled()
          expect(collection2.loaded).toBe true
          expect(collection2.get(2).get('workspace').id).toEqual 10
          expect(collection2.get(3).get('workspace').id).toEqual 11
          expect(collection2.length).toEqual 2

        it "returns an empty collection when passed in an empty array", ->
          timeEntries = [buildTimeEntry(story_id: 2, workspace_id: 15, id: 1), buildTimeEntry(workspace_id: 10, id: 2)]
          server.respondWith "GET", "/api/time_entries?per_page=20&page=1", [ 200, {"Content-Type": "application/json"}, JSON.stringify(time_entries: timeEntries) ]

          collection = base.data.loadCollection "time_entries", only: []
          expect(collection.loaded).toBe true
          expect(collection.length).toEqual 0

          collection = base.data.loadCollection "time_entries", only: null
          server.respond()
          expect(collection.loaded).toBe true
          expect(collection.length).toEqual 2

        it "accepts a success function that gets triggered on cache hit", ->
          server.respondWith "GET", "/api/time_entries?include=workspace%3Bstory&only=2%2C3", [ 200, {"Content-Type": "application/json"}, JSON.stringify(time_entries: [buildTimeEntry(workspace_id: 10, id: 2, story_id: null), buildTimeEntry(workspace_id: 11, id: 3, story_id: null)], stories: [], workspaces: [buildWorkspace(id: 10), buildWorkspace(id: 11)]) ]
          base.data.loadCollection "time_entries", include: ["workspace", "story"], only: [2, 3]
          server.respond()
          spy = jasmine.createSpy().andCallFake (collection) ->
            expect(collection.loaded).toBe true
            expect(collection.get(2).get('workspace').id).toEqual 10
            expect(collection.get(3).get('workspace').id).toEqual 11
          collection2 = base.data.loadCollection "time_entries", include: ["workspace"], only: [2, 3], success: spy
          expect(spy).toHaveBeenCalled()

        it "does not update sort lengths on only queries", ->
          server.respondWith "GET", "/api/time_entries?include=workspace%3Bstory&only=2%2C3", [ 200, {"Content-Type": "application/json"}, JSON.stringify(time_entries: [buildTimeEntry(workspace_id: 10, id: 2, story_id: null), buildTimeEntry(workspace_id: 11, id: 3, story_id: null)], stories: [], workspaces: [buildWorkspace(id: 10), buildWorkspace(id: 11)]) ]
          collection = base.data.loadCollection "time_entries", include: ["workspace", "story"], only: [2, 3]
          expect(Object.keys base.data.getCollectionDetails("time_entries")["sortLengths"]).toEqual []
          server.respond()
          expect(Object.keys base.data.getCollectionDetails("time_entries")["sortLengths"]).toEqual []

        it "does go to the server on a repeat request if an association is missing", ->
          server.respondWith "GET", "/api/time_entries?include=workspace&only=2", [ 200, {"Content-Type": "application/json"}, JSON.stringify(time_entries: [buildTimeEntry(workspace_id: 10, id: 2, story_id: 6)], workspaces: [buildWorkspace(id: 10)]) ]
          server.respondWith "GET", "/api/time_entries?include=workspace%3Bstory&only=2", [ 200, {"Content-Type": "application/json"}, JSON.stringify(time_entries: [buildTimeEntry(workspace_id: 10, id: 2, story_id: 6)], stories: [buildStory(id: 6)], workspaces: [buildWorkspace(id: 10)]) ]

          collection = base.data.loadCollection "time_entries", include: ["workspace"], only: 2
          expect(collection.loaded).toBe false
          server.respond()
          expect(collection.loaded).toBe true
          collection2 = base.data.loadCollection "time_entries", include: ["workspace", "story"], only: 2
          expect(collection2.loaded).toBe false

    describe "searching", ->
      it "returns the matching items with includes, triggering reset and success", ->
        server.respondWith "GET", "/api/stories.json?per_page=20&page=1&search=go+go+gadget+search", [ 200, {"Content-Type": "application/json"}, JSON.stringify(stories: [buildStory()]) ]

        spy2 = jasmine.createSpy().andCallFake (collection) ->
          expect(collection.loaded).toBe true
        collection = base.data.loadCollection "stories", search: "go go gadget search", success: spy2
        spy = jasmine.createSpy().andCallFake ->
          expect(collection.loaded).toBe true
        collection.bind "reset", spy
        expect(collection.loaded).toBe false
        server.respond()
        expect(collection.loaded).toBe true
        expect(spy).toHaveBeenCalled()
        expect(spy2).toHaveBeenCalled()

      it 'it goes to server even if we have matching items in cache', ->
        expect(false).toBeTruthy()

      it 'does not apply local filters/sorts', ->
        expect(false).toBeTruthy()

      it 'does not blow up when no results are returned', ->
        expect(false).toBeTruthy()

      it 'acts as if no search options were passed if the search string is blank', ->
        expect(false).toBeTruthy()

  describe "createNewCollection", ->
    it "makes a new collection of the appropriate type", ->
      expect(base.data.createNewCollection("stories", [buildStory(), buildStory()]) instanceof App.Collections.Stories).toBe true

    it "can accept a 'loaded' flag", ->
      collection = base.data.createNewCollection("stories", [buildStory(), buildStory()])
      expect(collection.loaded).toBe false
      collection = base.data.createNewCollection("stories", [buildStory(), buildStory()], loaded: true)
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

