describe 'Brainstem.Collection', ->
  collection = updateArray = null

  beforeEach ->
    collection = new Brainstem.Collection([{id: 2, title: '1'}, {id: 3, title: '2'}, {title: '3'}])
    updateArray = [{id: 2, title: '1 new'}, {id: 4, title: 'this is new'}]


  describe '#pickFetchOptions', ->
    keys = sampleOptions = null
    beforeEach ->
      sampleOptions =
        name      : 1
        filters   : 1
        page      : 1
        perPage   : 1
        limit     : 1
        offset    : 1
        order     : 1
        search    : 1
        cacheKey  : 1
        bogus     : 1
        stuff     : 1
      keys = _.keys(Brainstem.Collection.pickFetchOptions(sampleOptions))

    it 'returns an array with picked option keys', ->
      for key of sampleOptions
        continue if key is 'bogus' or 'stuff'
        expect(keys).toContain(key)
      
    it 'does not contain non whitelisted options', ->
      expect(keys).not.toContain('bogus')
      expect(keys).not.toContain('stuff')

  describe '#getServerCount', ->
    context 'lastFetchOptions are set', ->
      it 'returns the cached count', ->
        posts = (buildPost(message: 'old post', reply_ids: []) for i in [1..5])
        respondWith server, '/api/posts?include=replies&parents_only=true&per_page=5&page=1', resultsFrom: 'posts', data: { count: posts.length, posts: posts }
        loader = base.data.loadObject 'posts', include: ['replies'], filters: { parents_only: 'true' }, perPage: 5
        
        expect(loader.getCollection().getServerCount()).toBeUndefined()
        server.respond()
        expect(loader.getCacheObject().count).toEqual posts.length
        expect(loader.getCollection().getServerCount()).toEqual posts.length

    context 'lastFetchOptions are not set', ->
      it 'returns undefined', ->
        collection = base.data.createNewCollection 'tasks'
        expect(collection.getServerCount()).toBeUndefined()

  describe '#getWithAssocation', ->
    it 'defaults to the regular get', ->
      spyOn(collection, 'get')
      collection.getWithAssocation(10)
      expect(collection.get).toHaveBeenCalledWith(10)

  describe '#fetch', ->
    # collection = new Brainstem.Collection([{id: 2, title: '1'}, {id: 3, title: '2'}, {title: '3'}])
    
    context 'collection has no brainstemKey defined', ->
      it 'throws a "BrainstemError"', ->
        expect(-> collection.fetch()).toThrow()

    context 'the collection has brainstemKey defined', ->
      beforeEach ->
        collection.brainstemKey = 'posts'

      it 'does not throw', ->
        expect(-> collection.fetch()).not.toThrow()

      it 'assigns its BrainstemKey to the options object', ->
        loadObjectSpy = spyOn(base.data, 'loadObject').andReturn(new $.Deferred)

        collection.fetch()

        expect(loadObjectSpy.mostRecentCall.args[1].name).toEqual('posts')

    context 'options has a name property', ->
      it 'uses options name property over the collections brainstemKey', ->
        loadObjectSpy = spyOn(base.data, 'loadObject').andReturn(new $.Deferred)

        collection.brainstemKey = 'attachments'
        collection.fetch(name: 'posts')

        expect(loadObjectSpy.mostRecentCall.args[1].name).toEqual('posts')

    it 'assigns firstFetchOptions if they do not exist', ->
      collection.firstFetchOptions = null
      collection.fetch(name: 'posts')

      expect(collection.firstFetchOptions).toBeDefined()
      expect(collection.firstFetchOptions.name).toEqual('posts')

    it 'wraps options-passed error function', ->
      wrapSpy = spyOn(Brainstem.Utils, 'wrapError')
      options = error: -> 'hi!'
      collection.brainstemKey = 'posts'
      collection.fetch(options)
      expect(wrapSpy).toHaveBeenCalledWith(collection, jasmine.any(Object))
      expect(wrapSpy.mostRecentCall.args[1].error).toBe(options.error)

    it 'returns a promise', ->
      deferred =
        pipe: -> { done: (->) }
        promise: -> 'le-promise'

      spyOn(base.data, 'loadObject').andReturn(deferred)
      collection.brainstemKey = 'posts'
      expect(collection.fetch()).toEqual('le-promise')

    describe 'loading brainstem object', ->
      loadObjectSpy = options = null

      beforeEach ->
        promise = new $.Deferred()

        loadObjectSpy = spyOn(base.data, 'loadObject').andReturn(promise)
        collection.brainstemKey = 'posts'
      
      it 'calls `loadObject` with collection name', ->
        collection.fetch()
        expect(loadObjectSpy).toHaveBeenCalledWith('posts', jasmine.any(Object))

      it 'mixes passed options into options passed to `loadObject`', ->
        options = { parse: false, url: 'sick url', reset: true }

        collection.fetch(options)

        for key of options
          expect(_.keys(loadObjectSpy.mostRecentCall.args[1])).toContain key
          expect(loadObjectSpy.mostRecentCall.args[1][key]).toEqual options[key]

    describe 'brainstem request and response', ->
      options = server = posts = null

      beforeEach ->
        posts = [buildPost(), buildPost(), buildPost()]
        collection.brainstemKey = 'posts'
        options = { offset: 0, limit: 5, response: (res) -> res.results = posts }

        base.data.enableExpectations()
        server = base.data.stub 'posts', options

      it 'updates `lastFetchOptions` on the collection instance', ->
        expect(collection.lastFetchOptions).toBeNull()

        collection.fetch(options)
        server.respond()

        lastFetchOptions = collection.lastFetchOptions
        expect(lastFetchOptions).toEqual(jasmine.any Object)
        expect(lastFetchOptions.offset).toEqual(0)
        expect(lastFetchOptions.limit).toEqual(5)

      it 'triggers sync', ->
        spyOn(collection, 'trigger')

        collection.fetch(options)
        server.respond()

        expect(collection.trigger).toHaveBeenCalledWith('sync', collection, jasmine.any(Array), jasmine.any(Object))

      context 'reset option is set to false', ->
        beforeEach ->
          options.reset = false
          spyOn(collection, 'set')
          collection.fetch(options)

        it 'sets the server response on the collection', ->
          server.respond()

          objects = collection.set.mostRecentCall.args[0]
          expect(_.pluck(objects, 'id')).toEqual(_.pluck(posts, 'id'))
          expect(object).toEqual(jasmine.any App.Models.Post) for object in objects

      context 'reset option is set to true', ->
        beforeEach ->
          options.reset = true
          collection.fetch(options)
          spyOn(collection, 'reset')
          
        it 'it resets the collection with the server response', ->
          server.respond()

          objects = collection.reset.mostRecentCall.args[0]
          expect(_.pluck(objects, 'id')).toEqual(_.pluck(posts, 'id'))
          expect(object).toEqual(jasmine.any App.Models.Post) for object in objects

      context 'collection is fetched again with different options', ->
        secondPosts = secondOptions = firstOptions = null

        beforeEach ->
          secondPosts = [buildPost(), buildPost()]
          secondOptions = { offset: 5, limit: 3, response: (res) -> res.results = secondPosts }
          secondServer = base.data.stub 'posts', secondOptions

          spyOn(collection, 'set')

          collection.fetch(options)
          server.respond()

          firstOptions = collection.lastFetchOptions

          collection.fetch(secondOptions)
          secondServer.respond()

        it 'returns only the second set of results', ->
          objects = collection.set.mostRecentCall.args[0]
          expect(_.pluck(objects, 'id')).toEqual(_.pluck(secondPosts, 'id'))
          expect(object).toEqual(jasmine.any App.Models.Post) for object in objects

        it 'updates `lastFetchOptions` on the collection instance', ->
          expect(collection.lastFetchOptions).not.toBe(firstOptions)

          lastFetchOptions = collection.lastFetchOptions
          expect(lastFetchOptions).toEqual(jasmine.any Object)
          expect(lastFetchOptions.offset).toEqual(5)
          expect(lastFetchOptions.limit).toEqual(3)

  describe '#update', ->
    it 'works with an array', ->
      collection.update updateArray
      expect(collection.get(2).get('title')).toEqual '1 new'
      expect(collection.get(3).get('title')).toEqual '2'
      expect(collection.get(4).get('title')).toEqual 'this is new'

    it 'works with a collection', ->
      newCollection = new Brainstem.Collection(updateArray)
      collection.update newCollection
      expect(collection.get(2).get('title')).toEqual '1 new'
      expect(collection.get(3).get('title')).toEqual '2'
      expect(collection.get(4).get('title')).toEqual 'this is new'

    it 'should update copies of the model that are already in the collection', ->
      model = collection.get(2)
      spy = jasmine.createSpy()
      model.bind 'change:title', spy
      collection.update updateArray
      expect(model.get('title')).toEqual '1 new'
      expect(spy).toHaveBeenCalled()

  describe '#reload', ->
    it 'reloads the collection with the original params', ->
      respondWith server, '/api/posts?include=replies&parents_only=true&per_page=5&page=1', resultsFrom: 'posts', data: { posts: [buildPost(message: 'old post', reply_ids: [])] }
      collection = base.data.loadCollection 'posts', include: ['replies'], filters: { parents_only: 'true' }, perPage: 5
      server.respond()
      expect(collection.lastFetchOptions.page).toEqual 1
      expect(collection.lastFetchOptions.perPage).toEqual 5
      expect(collection.lastFetchOptions.include).toEqual ['replies']
      server.responses = []
      respondWith server, '/api/posts?include=replies&parents_only=true&per_page=5&page=1', resultsFrom: 'posts', data: { posts: [buildPost(message: 'new post', reply_ids: [])] }
      expect(collection.models[0].get('message')).toEqual 'old post'
      resetCounter = jasmine.createSpy('resetCounter')
      loadedCounter = jasmine.createSpy('loadedCounter')
      callback = jasmine.createSpy('callback spy')
      collection.bind 'reset', resetCounter
      collection.bind 'loaded', loadedCounter

      collection.reload success: callback

      expect(collection.loaded).toBe false
      expect(collection.length).toEqual 0
      server.respond()
      expect(collection.length).toEqual 1
      expect(collection.models[0].get('message')).toEqual 'new post'
      expect(resetCounter.callCount).toEqual 1
      expect(loadedCounter.callCount).toEqual 1
      expect(callback).toHaveBeenCalledWith(collection)

  describe '#loadNextPage', ->
    it 'loads the next page of data for a collection that has previously been loaded in the storage manager, returns the collection and whether it thinks there is another page or not', ->
      respondWith server, '/api/time_entries?per_page=2&page=1', resultsFrom: 'time_entries', data: { time_entries: [buildTimeEntry(), buildTimeEntry()] }
      respondWith server, '/api/time_entries?per_page=2&page=2', resultsFrom: 'time_entries', data: { time_entries: [buildTimeEntry(), buildTimeEntry()] }
      respondWith server, '/api/time_entries?per_page=2&page=3', resultsFrom: 'time_entries', data: { time_entries: [buildTimeEntry()] }
      collection = base.data.loadCollection 'time_entries', perPage: 2
      expect(collection.length).toEqual 0
      server.respond()
      expect(collection.length).toEqual 2
      expect(collection.lastFetchOptions.page).toEqual 1

      spy = jasmine.createSpy()
      collection.loadNextPage success: spy
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

    it 'fetches based on the last limit and offset if they were the pagination options used', ->
      respondWith server, '/api/time_entries?limit=2&offset=0', resultsFrom: 'time_entries', data: { time_entries: [buildTimeEntry(), buildTimeEntry()] }
      respondWith server, '/api/time_entries?limit=2&offset=2', resultsFrom: 'time_entries', data: { time_entries: [buildTimeEntry(), buildTimeEntry()] }
      respondWith server, '/api/time_entries?limit=2&offset=4', resultsFrom: 'time_entries', data: { time_entries: [buildTimeEntry()] }
      collection = base.data.loadCollection 'time_entries', limit: 2, offset: 0
      expect(collection.length).toEqual 0
      server.respond()
      expect(collection.length).toEqual 2
      expect(collection.lastFetchOptions.offset).toEqual 0

      spy = jasmine.createSpy()
      collection.loadNextPage success: spy
      server.respond()
      expect(spy).toHaveBeenCalledWith(collection, true)
      expect(collection.lastFetchOptions.offset).toEqual 2
      expect(collection.length).toEqual 4

      spy = jasmine.createSpy()
      collection.loadNextPage success: spy
      expect(collection.length).toEqual 4
      server.respond()
      expect(spy).toHaveBeenCalledWith(collection, false)
      expect(collection.lastFetchOptions.offset).toEqual 4
      expect(collection.length).toEqual 5

  describe '#invalidateCache', ->
    it 'invalidates the cache object', ->
      posts = (buildPost(message: 'old post', reply_ids: []) for i in [1..5])
      respondWith server, '/api/posts?include=replies&parents_only=true&per_page=5&page=1', resultsFrom: 'posts', data: { count: posts.length, posts: posts }
      loader = base.data.loadObject 'posts', include: ['replies'], filters: { parents_only: 'true' }, perPage: 5
      
      expect(loader.getCacheObject()).toBeUndefined()
      server.respond()

      expect(loader.getCacheObject().valid).toEqual true
      loader.getCollection().invalidateCache()
      expect(loader.getCacheObject().valid).toEqual false

  describe '#toServerJSON', ->
    it 'calls through to toJSON', ->
      spy = spyOn(collection, 'toJSON')
      collection.toServerJSON()
      expect(spy).toHaveBeenCalled()

  describe '#setLoaded', ->
    it 'should set the values of @loaded', ->
      collection.setLoaded true
      expect(collection.loaded).toEqual(true)
      collection.setLoaded false
      expect(collection.loaded).toEqual(false)

    it 'triggers "loaded" when becoming true', ->
      spy = jasmine.createSpy()
      collection.bind 'loaded', spy
      collection.setLoaded false
      expect(spy).not.toHaveBeenCalled()
      collection.setLoaded true
      expect(spy).toHaveBeenCalled()

    it 'doesnt trigger loaded if trigger: false is provided', ->
      spy = jasmine.createSpy()
      collection.bind 'loaded', spy
      collection.setLoaded true, trigger: false
      expect(spy).not.toHaveBeenCalled()

    it 'returns self', ->
      spy = jasmine.createSpy()
      collection.bind 'loaded', spy
      collection.setLoaded true
      expect(spy).toHaveBeenCalledWith(collection)

  describe 'ordering and filtering', ->
    beforeEach ->
      collection = new Brainstem.Collection([
        new Brainstem.Model(id: 2, title: 'Alpha', updated_at: 2,  cool: false),
        new Brainstem.Model(id: 3, title: 'Beta',  updated_at: 10, cool: true),
        new Brainstem.Model(id: 4, title: 'Gamma', updated_at: 5,  cool: false),
        new Brainstem.Model(id: 6, title: 'Gamma', updated_at: 5,  cool: false),
        new Brainstem.Model(id: 5, title: 'Gamma', updated_at: 4,  cool: true)
      ])

    describe '@getComparatorWithIdFailover', ->
      it 'returns a comparator that works for numerical ordering of unix timestamps, failing over to id when theyre the same', ->
        newCollection = new Brainstem.Collection collection.models, comparator: Brainstem.Collection.getComparatorWithIdFailover('updated_at:desc')
        newCollection.sort()
        expect(newCollection.pluck('id')).toEqual [3, 6, 4, 5, 2]

        newCollection = new Brainstem.Collection collection.models, comparator: Brainstem.Collection.getComparatorWithIdFailover('updated_at:asc')
        newCollection.sort()
        expect(newCollection.pluck('id')).toEqual [2, 5, 4, 6, 3]
