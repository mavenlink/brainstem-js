describe 'Brainstem.Collection', ->
  collection = updateArray = null

  beforeEach ->
    collection = new Brainstem.Collection([{id: 2, title: "1"}, {id: 3, title: "2"}, {title: "3"}])
    updateArray = [{id: 2, title: "1 new"}, {id: 4, title: "this is new"}]

  describe 'update', ->
    it "works with an array", ->
      collection.update updateArray
      expect(collection.get(2).get('title')).toEqual "1 new"
      expect(collection.get(3).get('title')).toEqual "2"
      expect(collection.get(4).get('title')).toEqual "this is new"

    it "works with a collection", ->
      newCollection = new Brainstem.Collection(updateArray)
      collection.update newCollection
      expect(collection.get(2).get('title')).toEqual "1 new"
      expect(collection.get(3).get('title')).toEqual "2"
      expect(collection.get(4).get('title')).toEqual "this is new"

    it "should update copies of the model that are already in the collection", ->
      model = collection.get(2)
      spy = jasmine.createSpy()
      model.bind "change:title", spy
      collection.update updateArray
      expect(model.get('title')).toEqual "1 new"
      expect(spy).toHaveBeenCalled()

  describe "loadNextPage", ->
    it "loads the next page of data for a collection that has previously been loaded in the storage manager, returns the collection and whether it thinks there is another page or not", ->
      respondWith server, "/api/time_entries?per_page=2&page=1", resultsFrom: "time_entries", data: { time_entries: [buildTimeEntry(), buildTimeEntry()] }
      respondWith server, "/api/time_entries?per_page=2&page=2", resultsFrom: "time_entries", data: { time_entries: [buildTimeEntry(), buildTimeEntry()] }
      respondWith server, "/api/time_entries?per_page=2&page=3", resultsFrom: "time_entries", data: { time_entries: [buildTimeEntry()] }
      collection = base.data.loadCollection "time_entries", perPage: 2
      server.respond()
      expect(collection.lastFetchOptions.page).toEqual 1

      spy = jasmine.createSpy()
      collection.loadNextPage success: spy
      expect(collection.length).toEqual 2
      server.respond()
      expect(spy).toHaveBeenCalledWith(collection, true)
      expect(collection.lastFetchOptions.page).toEqual 2
      expect(collection.length).toEqual 4

      spy = jasmine.createSpy()
      collection.loadNextPage success: spy
      expect(collection.length).toEqual 4
      server.respond()
      expect(spy).toHaveBeenCalledWith(collection, false)
      expect(collection.lastFetchOptions.page).toEqual 3
      expect(collection.length).toEqual 5

  describe "reload", ->
    it "reloads the collection with the original params", ->
      respondWith server, "/api/posts?include=replies&filters=parents_only%3Atrue&per_page=5&page=1", resultsFrom: "posts", data: { posts: [buildPost(message: "old post", reply_ids: [])] }
      collection = base.data.loadCollection "posts", include: ["replies"], filters: "parents_only:true", perPage: 5
      server.respond()
      expect(collection.lastFetchOptions.page).toEqual 1
      expect(collection.lastFetchOptions.perPage).toEqual 5
      expect(collection.lastFetchOptions.include).toEqual ["replies"]
      server.responses = []
      respondWith server, "/api/posts?include=replies&filters=parents_only%3Atrue&per_page=5&page=1", resultsFrom: "posts", data: { posts: [buildPost(message: "new post", reply_ids: [])] }
      expect(collection.models[0].get("message")).toEqual "old post"
      resetCounter = jasmine.createSpy("resetCounter")
      loadedCounter = jasmine.createSpy("loadedCounter")
      callback = jasmine.createSpy("callback spy")
      collection.bind "reset", resetCounter
      collection.bind "loaded", loadedCounter

      collection.reload success: callback

      expect(collection.loaded).toBe false
      expect(collection.length).toEqual 0
      server.respond()
      expect(collection.length).toEqual 1
      expect(collection.models[0].get("message")).toEqual "new post"
      expect(resetCounter.callCount).toEqual 1
      expect(loadedCounter.callCount).toEqual 1
      expect(callback).toHaveBeenCalledWith(collection)

  describe "getWithAssocation", ->
    it "defaults to the regular get", ->
      spyOn(collection, 'get')
      collection.getWithAssocation(10)
      expect(collection.get).toHaveBeenCalledWith(10)

  describe 'ids', ->
    it "should return an array of ids", ->
      expect(collection.ids()).toEqual(['2', '3'])

  describe 'setLoaded', ->
    it "should set the values of @loaded", ->
      collection.setLoaded true
      expect(collection.loaded).toEqual(true)
      collection.setLoaded false
      expect(collection.loaded).toEqual(false)

    it "triggers 'loaded' when becoming true", ->
      spy = jasmine.createSpy()
      collection.bind "loaded", spy
      collection.setLoaded false
      expect(spy).not.toHaveBeenCalled()
      collection.setLoaded true
      expect(spy).toHaveBeenCalled()

    it "doesn't trigger loaded if trigger: false is provided", ->
      spy = jasmine.createSpy()
      collection.bind "loaded", spy
      collection.setLoaded true, trigger: false
      expect(spy).not.toHaveBeenCalled()

    it "returns self", ->
      spy = jasmine.createSpy()
      collection.bind "loaded", spy
      collection.setLoaded true
      expect(spy).toHaveBeenCalledWith(collection)

  describe "toServerJSON", ->
    it "calls through to toJSON", ->
      spy = spyOn(collection, 'toJSON')
      collection.toServerJSON()
      expect(spy).toHaveBeenCalled()

  describe "ordering and filtering", ->
    beforeEach ->
      collection = new Brainstem.Collection([
        new Brainstem.Model(id: 2, title: "Alpha", updated_at: 2,  cool: false),
        new Brainstem.Model(id: 3, title: "Beta",  updated_at: 10, cool: true),
        new Brainstem.Model(id: 4, title: "Gamma", updated_at: 5,  cool: false),
        new Brainstem.Model(id: 6, title: "Gamma", updated_at: 5,  cool: false),
        new Brainstem.Model(id: 5, title: "Gamma", updated_at: 4,  cool: true)
      ])

    describe "@getComparatorWithIdFailover", ->
      it "returns a comparator that works for numerical ordering of unix timestamps, failing over to id when they're the same", ->
        newCollection = new Brainstem.Collection collection.models, comparator: Brainstem.Collection.getComparatorWithIdFailover("updated_at:desc")
        newCollection.sort()
        expect(newCollection.pluck("id")).toEqual [3, 6, 4, 5, 2]

        newCollection = new Brainstem.Collection collection.models, comparator: Brainstem.Collection.getComparatorWithIdFailover("updated_at:asc")
        newCollection.sort()
        expect(newCollection.pluck("id")).toEqual [2, 5, 4, 6, 3]

    describe "@getFilterer", ->
      it "returns a filter that can handle filtering any attribute by an exact value", ->
        expect(_(collection.filter(Brainstem.Collection.getFilterer("updated_at:10"))).pluck("id")).toEqual [3]
        expect(_(collection.filter(Brainstem.Collection.getFilterer("title:Gamma"))).pluck("id")).toEqual [4, 6, 5]

      it "works with booleans", ->
        expect(_(collection.filter(Brainstem.Collection.getFilterer("cool:true"))).pluck("id")).toEqual [3, 5]
        expect(_(collection.filter(Brainstem.Collection.getFilterer("cool:false"))).pluck("id")).toEqual [2, 4, 6]

      it "can accept an array of filters and compose them", ->
        expect(_(collection.filter(Brainstem.Collection.getFilterer(["updated_at:10", "title:foo"]))).pluck("id")).toEqual []
        expect(_(collection.filter(Brainstem.Collection.getFilterer(["title:Gamma", "updated_at:4"]))).pluck("id")).toEqual [5]

      it "can accept a search param and calls matchesSearch on the model", ->
        expect(_(collection.filter(Brainstem.Collection.getFilterer(["updated_at:5", "search:Ga"]))).pluck("id")).toEqual [4, 6]
        expect(_(collection.filter(Brainstem.Collection.getFilterer(["updated_at:5", "search:Gat"]))).pluck("id")).toEqual []

      it "handles default filters", ->
        class ProjectsWithDefault extends Brainstem.Collection
          @defaultFilters: ["title:Gamma"]

        expect(_(collection.filter(ProjectsWithDefault.getFilterer())).pluck("id")).toEqual [4, 6, 5]
        expect(_(collection.filter(ProjectsWithDefault.getFilterer([]))).pluck("id")).toEqual [4, 6, 5]
        expect(_(collection.filter(ProjectsWithDefault.getFilterer("cool:true"))).pluck("id")).toEqual [5]
        expect(_(collection.filter(ProjectsWithDefault.getFilterer("title:Alpha"))).pluck("id")).toEqual [2]
