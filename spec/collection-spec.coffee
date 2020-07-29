$ = require 'jquery'
_ = require 'underscore'
Backbone = require 'backbone'
Backbone.$ = $ # TODO remove after upgrading to backbone 1.2+

Utils = require '../src/utils'
Model = require '../src/model'
Collection = require '../src/collection'
StorageManager = require '../src/storage-manager'

Post = require './helpers/models/post'
Posts = require './helpers/models/posts'
Tasks = require './helpers/models/tasks'


describe 'Collection', ->
  collection = storageManager = updateArray = null

  beforeEach ->
    storageManager = StorageManager.get()
    collection = new Collection([{id: 2, title: '1'}, {id: 3, title: '2'}, {title: '3'}])
    updateArray = [{id: 2, title: '1 new'}, {id: 4, title: 'this is new'}]

  describe '#constructor', ->
    setLoadedSpy = pickFetchOptionsSpy = null

    beforeEach ->
      pickFetchOptionsSpy = spyOn(Collection, 'pickFetchOptions').and.callThrough()
      setLoadedSpy = spyOn(Collection.prototype, 'setLoaded')

      collection = new Collection(null, name: 'posts')

    it 'sets `setLoaded` to false', ->
      expect(setLoadedSpy).toHaveBeenCalled()

    context 'when options are passed', ->
      it 'calls `pickFetchOptions` with options', ->
        expect(pickFetchOptionsSpy).toHaveBeenCalledWith(name: 'posts')

      it 'sets `firstFetchOptions`', ->
        expect(collection.firstFetchOptions).toBeDefined()
        expect(collection.firstFetchOptions.name).toEqual('posts')

    context 'no options are passed', ->
      it 'does not throw an error trying to pick options', ->
        expect(-> new Collection()).not.toThrow()

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
      keys = _.keys(Collection.pickFetchOptions(sampleOptions))

    it 'returns an array with picked option keys', ->
      for key of sampleOptions
        continue if key is 'bogus' or 'stuff'
        expect(keys).toContain(key)

    it 'does not contain non allowlisted options', ->
      expect(keys).not.toContain('bogus')
      expect(keys).not.toContain('stuff')

  describe '#getServerCount', ->
    context 'lastFetchOptions are set', ->
      it 'returns the cached count', ->
        posts = (buildPost(message: 'old post', reply_ids: []) for i in [1..5])
        respondWith server, '/api/posts?include=replies&parents_only=true&per_page=5&page=1', resultsFrom: 'posts', data: { count: posts.length, posts: posts }
        loader = storageManager.loadObject 'posts', include: ['replies'], filters: { parents_only: 'true' }, perPage: 5

        expect(loader.getCollection().getServerCount()).toBeUndefined()
        server.respond()
        expect(loader.getCacheObject().count).toEqual posts.length
        expect(loader.getCollection().getServerCount()).toEqual posts.length

    context 'lastFetchOptions are not set', ->
      it 'returns undefined', ->
        collection = storageManager.createNewCollection 'tasks'
        expect(collection.getServerCount()).toBeUndefined()

  describe '#getWithAssocation', ->
    it 'defaults to the regular get', ->
      spyOn(collection, 'get')
      collection.getWithAssocation(10)
      expect(collection.get).toHaveBeenCalledWith(10)

  describe '#fetch', ->
    context 'collection has no model', ->
      beforeEach ->
        collection.model = undefined

      it 'throws a "BrainstemError"', ->
        expect(-> collection.fetch()).toThrow()

    context 'collection has model without a brainstemKey defined', ->
      beforeEach ->
        collection.model = Backbone.Model

      it 'throws a "BrainstemError"', ->
        expect(-> collection.fetch()).toThrow()

    context 'the collection has brainstemKey defined', ->
      beforeEach ->
        collection.model = Post

      it 'does not throw', ->
        expect(-> collection.fetch()).not.toThrow()

      it 'assigns its BrainstemKey to the options object', ->
        loadObjectSpy = spyOn(storageManager, 'loadObject').and.returnValue(new $.Deferred)

        collection.fetch()

        expect(loadObjectSpy.calls.mostRecent().args[1].name).toEqual('posts')

      it 'triggers "request"', ->
        options = returnValues: {}

        spyOn(collection, 'trigger')
        collection.fetch(options)

        expect(collection.trigger).toHaveBeenCalledWith('request', collection, options.returnValues.jqXhr, jasmine.any(Object))

    context 'options has a name property', ->
      it 'uses options name property over the collections brainstemKey', ->
        loadObjectSpy = spyOn(storageManager, 'loadObject').and.returnValue(new $.Deferred)

        collection.brainstemKey = 'attachments'
        collection.fetch(name: 'posts')

        expect(loadObjectSpy.calls.mostRecent().args[1].name).toEqual('posts')

    it 'assigns firstFetchOptions if they do not exist', ->
      collection.firstFetchOptions = null
      collection.fetch(name: 'posts')

      expect(collection.firstFetchOptions).toBeDefined()
      expect(collection.firstFetchOptions.name).toEqual('posts')

    it 'wraps options-passed error function', ->
      wrapSpy = spyOn(Utils, 'wrapError')
      options = error: -> 'hi!'
      collection.model = Post
      collection.fetch(options)
      expect(wrapSpy).toHaveBeenCalledWith(collection, jasmine.any(Object))
      expect(wrapSpy.calls.mostRecent().args[1].error).toBe(options.error)

    describe 'loading brainstem object', ->
      loadObjectSpy = options = null

      beforeEach ->
        promise = new $.Deferred()

        loadObjectSpy = spyOn(storageManager, 'loadObject').and.returnValue(promise)

        collection.firstFetchOptions = {}
        collection.model = Post

      it 'calls `loadObject` with collection name', ->
        collection.fetch()
        expect(loadObjectSpy).toHaveBeenCalledWith('posts', jasmine.any(Object))

      it 'mixes passed options into options passed to `loadObject`', ->
        options = { parse: false, url: 'sick url', reset: true }

        collection.fetch(options)

        for key of options
          expect(_.keys(loadObjectSpy.calls.mostRecent().args[1])).toContain key
          expect(loadObjectSpy.calls.mostRecent().args[1][key]).toEqual options[key]

      it 'does not modify `firstFetchOptions`', ->
        firstFetchOptions = _.clone collection.firstFetchOptions

        collection.fetch(bla: 'bla')

        expect(collection.firstFetchOptions).toEqual firstFetchOptions

    describe 'brainstem request and response', ->
      options = expectation = posts = null

      beforeEach ->
        posts = [buildPost(), buildPost(), buildPost()]
        collection.model = Post
        options = { offset: 0, limit: 5, response: (res) -> res.results = posts }

        storageManager.enableExpectations()
        expectation = storageManager.stub 'posts', options

      afterEach ->
        storageManager.disableExpectations()

      it 'updates `lastFetchOptions` on the collection instance', ->
        expect(collection.lastFetchOptions).toBeNull()

        collection.fetch(options)
        expectation.respond()

        lastFetchOptions = collection.lastFetchOptions
        expect(lastFetchOptions).toEqual(jasmine.any Object)
        expect(lastFetchOptions.offset).toEqual(0)
        expect(lastFetchOptions.limit).toEqual(5)


      it 'updates `lastFetchOptions` BEFORE invoking (set/reset/add) method on collection', ->
        expect(collection.lastFetchOptions).toBeNull()

        fakeReset = ->
          lastFetchOptions = collection.lastFetchOptions
          expect(lastFetchOptions).toEqual(jasmine.any Object)
          expect(lastFetchOptions.offset).toEqual(0)
          expect(lastFetchOptions.limit).toEqual(5)

        spyOn(collection, 'set').and.callFake(fakeReset)

        collection.fetch(options)
        expectation.respond()

      it 'triggers sync', ->
        spyOn(collection, 'trigger')

        collection.fetch(options)
        expectation.respond()
        expect(collection.trigger).toHaveBeenCalledWith('sync', collection, jasmine.any(Array), jasmine.any(Object), jasmine.any(String))

      context 'reset option is set to false', ->
        beforeEach ->
          options.reset = false
          spyOn(collection, 'set')
          collection.fetch(options)

        it 'sets the server response on the collection', ->
          expectation.respond()

          objects = collection.set.calls.mostRecent().args[0]
          expect(_.pluck(objects, 'id')).toEqual(_.pluck(posts, 'id'))
          expect(object).toEqual(jasmine.any Post) for object in objects

        context 'add option is set to true', ->
          beforeEach ->
            options.add = true
            spyOn(collection, 'add')
            collection.fetch(options)

          it 'adds the server response to the collection', ->
            expectation.respond()

            objects = collection.add.calls.mostRecent().args[0]
            expect(_.pluck(objects, 'id')).toEqual(_.pluck(posts, 'id'))
            expect(object).toEqual(jasmine.any Post) for object in objects

      context 'reset option is set to true', ->
        beforeEach ->
          options.reset = true
          collection.fetch(options)
          spyOn(collection, 'reset')

        it 'it resets the collection with the server response', ->
          expectation.respond()

          objects = collection.reset.calls.mostRecent().args[0]
          expect(_.pluck(objects, 'id')).toEqual(_.pluck(posts, 'id'))
          expect(object).toEqual(jasmine.any Post) for object in objects

      context 'collection is fetched again with different options', ->
        secondPosts = secondOptions = firstOptions = null

        beforeEach ->
          secondPosts = [buildPost(), buildPost()]
          secondOptions = { offset: 5, limit: 3, response: (res) -> res.results = secondPosts }
          secondExpectation = storageManager.stub 'posts', secondOptions

          spyOn(collection, 'set')

          collection.fetch(options)
          expectation.respond()

          firstOptions = collection.lastFetchOptions

          collection.fetch(secondOptions)
          secondExpectation.respond()

        it 'returns only the second set of results', ->
          objects = collection.set.calls.mostRecent().args[0]
          expect(_.pluck(objects, 'id')).toEqual(_.pluck(secondPosts, 'id'))
          expect(object).toEqual(jasmine.any Post) for object in objects

        it 'updates `lastFetchOptions` on the collection instance', ->
          expect(collection.lastFetchOptions).not.toBe(firstOptions)

          lastFetchOptions = collection.lastFetchOptions
          expect(lastFetchOptions).toEqual(jasmine.any Object)
          expect(lastFetchOptions.offset).toEqual(5)
          expect(lastFetchOptions.limit).toEqual(3)

    describe 'integration', ->
      options = collection = posts1 = posts2 = null

      beforeEach ->
        posts1 = [buildPost(), buildPost(), buildPost(), buildPost(), buildPost()]
        posts2 = [buildPost(), buildPost()]

        options = { page: 1, perPage: 5 }
        collection = new Posts(null, options)

      it 'returns a promise with jqXhr methods', ->
        respondWith(server, '/api/posts?per_page=5&page=1', resultsFrom: 'posts', data: { posts: posts1 })

        jqXhr = $.ajax()
        promise = collection.fetch()

        for key, value of jqXhr
          object = {}
          object[key] = jasmine.any(value.constructor)
          expect(promise).toEqual jasmine.objectContaining(object)

      it 'returns a promise without jQuery Deferred methods', ->
        respondWith(server, '/api/posts?per_page=5&page=1', resultsFrom: 'posts', data: { posts: posts1 })

        promise = collection.fetch()
        methods = _.keys(promise)

        for method in ['reject', 'resolve', 'rejectWith', 'resolveWith']
          expect(methods).not.toContain(method)

      it 'passes collection instance to chained done method', ->
        onDoneSpy = jasmine.createSpy('onDone')

        respondWith(server, '/api/posts?per_page=5&page=1', resultsFrom: 'posts', data: { posts: posts1 })

        collection.fetch().done(onDoneSpy)
        server.respond()

        response = onDoneSpy.calls.mostRecent().args[0]
        expect(response.toJSON()).toEqual(collection.toJSON())

      it 'updates collection with response', ->
        respondWith(server, '/api/posts?per_page=5&page=1', resultsFrom: 'posts', data: { posts: posts1 })

        collection.fetch()
        server.respond()

        expect(collection.pluck('id')).toEqual(_(posts1).pluck('id'))

      it 'responds to requests with custom params', ->
        paramsOnDoneSpy = jasmine.createSpy('paramsOnDoneSpy')

        respondWith(server, '/api/posts?my_custom_param=theparam&per_page=5&page=1', resultsFrom: 'posts', data: { posts: posts2 })
        collection.fetch({params: {my_custom_param: 'theparam'}}).done(paramsOnDoneSpy)

        server.respond()

        expect(paramsOnDoneSpy).toHaveBeenCalled()

      describe 'subsequent fetches', ->
        beforeEach ->
          respondWith(server, '/api/posts?per_page=5&page=1', resultsFrom: 'posts', data: { posts: posts1 })

          collection.fetch()
          server.respond()

        it 'returns data from storage manager cache', ->
          collection.fetch()

          expect(collection.pluck 'id').toEqual(_.pluck posts1, 'id')
          expect(collection.pluck 'id').not.toEqual(_.pluck posts2, 'id')

        context 'different options are provided', ->
          beforeEach ->
            respondWith(server, '/api/posts?per_page=5&page=2', resultsFrom: 'posts', data: { posts: posts2 })
            collection.fetch({page: 2})
            server.respond()

          it 'updates collection with new data', ->
            expect(collection.pluck 'id').not.toEqual(_.pluck posts1, 'id')
            expect(collection.pluck 'id').toEqual(_.pluck posts2, 'id')

  describe '#refresh', ->
    beforeEach ->
      collection.lastFetchOptions = {}
      spyOn(collection, 'fetch')
      collection.refresh()

    it 'should call fetch with the correct options', ->
      expect(collection.fetch).toHaveBeenCalledWith(cache: false)

  describe '#update', ->
    it 'works with an array', ->
      collection.update updateArray
      expect(collection.get(2).get('title')).toEqual '1 new'
      expect(collection.get(3).get('title')).toEqual '2'
      expect(collection.get(4).get('title')).toEqual 'this is new'

    it 'works with a collection', ->
      newCollection = new Collection(updateArray)
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
      collection = storageManager.loadCollection 'posts', include: ['replies'], filters: { parents_only: 'true' }, perPage: 5
      server.respond()
      expect(collection.lastFetchOptions.page).toEqual 1
      expect(collection.lastFetchOptions.perPage).toEqual 5
      expect(collection.lastFetchOptions.include).toEqual ['replies']
      server.responses = []

      posts = [buildPost(message: 'new post', reply_ids: [])]
      responseData = { posts: resultsObject(posts), results: resultsArray("posts", posts) }
      respondWith server, '/api/posts?include=replies&parents_only=true&per_page=5&page=1', data: responseData
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
      expect(resetCounter.calls.count()).toEqual 1
      expect(loadedCounter.calls.count()).toEqual 1

      expectedResponse = JSON.parse(JSON.stringify(responseData))
      expect(callback).toHaveBeenCalledWith(collection, expectedResponse)

  describe '#loadNextPage', ->
    it 'loads the next page of data for a collection that has previously been loaded in the storage manager, returns the collection and whether it thinks there is another page or not', ->
      respondWith server, '/api/time_entries?per_page=2&page=1', resultsFrom: 'time_entries', data: { time_entries: [buildTimeEntry(), buildTimeEntry()], count: 5 }
      respondWith server, '/api/time_entries?per_page=2&page=2', resultsFrom: 'time_entries', data: { time_entries: [buildTimeEntry(), buildTimeEntry()], count: 5 }
      respondWith server, '/api/time_entries?per_page=2&page=3', resultsFrom: 'time_entries', data: { time_entries: [buildTimeEntry()], count: 5 }
      collection = storageManager.loadCollection 'time_entries', perPage: 2
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
      respondWith server, '/api/time_entries?limit=2&offset=0', resultsFrom: 'time_entries', data: { time_entries: [buildTimeEntry(), buildTimeEntry()], count: 5 }
      respondWith server, '/api/time_entries?limit=2&offset=2', resultsFrom: 'time_entries', data: { time_entries: [buildTimeEntry(), buildTimeEntry()], count: 5 }
      respondWith server, '/api/time_entries?limit=2&offset=4', resultsFrom: 'time_entries', data: { time_entries: [buildTimeEntry()], count: 5 }
      collection = storageManager.loadCollection 'time_entries', limit: 2, offset: 0
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

  describe '#getPageIndex', ->
    collection = null

    beforeEach ->
      collection = new Tasks()

    context 'lastFetchOptions is not defined (collection has not been fetched)', ->
      beforeEach ->
        collection.lastFetchOptions = undefined

      it 'returns 1', ->
        expect(collection.getPageIndex()).toEqual 1

    context 'lastFetchOptions is defined (collection has been fetched)', ->
      context 'limit and offset are defined', ->
        beforeEach ->
          collection.lastFetchOptions = { limit: 10, offset: 50 }
          spyOn(collection, 'getServerCount').and.returnValue(100)

        it 'returns correct page index', ->
          expect(collection.getPageIndex()).toEqual(6)

      context 'perPage and page are defined', ->
        beforeEach ->
          collection.lastFetchOptions = { perPage: 10, page: 6 }
          spyOn(collection, 'getServerCount').and.returnValue(100)

        it 'returns correct page index', ->
          expect(collection.getPageIndex()).toEqual(6)

  describe '#getNextPage', ->
    beforeEach ->
      collection = new Tasks()
      collection.lastFetchOptions = {}

      spyOn(collection, 'fetch')
      spyOn(collection, 'getServerCount').and.returnValue(100)

    context 'when limit and offset are definded in lastFetchOptions', ->
      context 'fetching from middle of collection', ->
        beforeEach ->
          collection.lastFetchOptions = { offset: 20, limit: 10 }
          collection.getNextPage()

        it 'calls fetch with correct limit and offset options for next page', ->
          options = collection.fetch.calls.mostRecent().args[0]
          expect(options.limit).toEqual 10
          expect(options.offset).toEqual 30

      context 'fetching from end of collection', ->
        beforeEach ->
          collection.lastFetchOptions = { offset: 80, limit: 20 }
          collection.getNextPage()

        it 'calls fetch with correct limit and offset options for next page', ->
          options = collection.fetch.calls.mostRecent().args[0]
          expect(options.limit).toEqual 20
          expect(options.offset).toEqual 80

    context 'when page and perPage are defined in lastFetchOptions', ->
      context 'fetching from middle of collection', ->
        beforeEach ->
          collection.lastFetchOptions = { perPage: 20, page: 2 }
          collection.getNextPage()

        it 'calls fetch with the correct page and perPage options for next page', ->
          options = collection.fetch.calls.mostRecent().args[0]
          expect(options.perPage).toEqual 20
          expect(options.page).toEqual 3

      context 'fetching from end of collection', ->
        beforeEach ->
          collection.lastFetchOptions = { perPage: 20, page: 5 }
          collection.getNextPage()

        it 'calls fetch with the correct page and perPage options for next page', ->
          options = collection.fetch.calls.mostRecent().args[0]
          expect(options.perPage).toEqual 20
          expect(options.page).toEqual 5

  describe '#getPreviousPage', ->
    beforeEach ->
      collection = new Tasks()
      collection.lastFetchOptions = {}

      spyOn(collection, 'fetch')
      spyOn(collection, 'getServerCount').and.returnValue(100)

    context 'when limit and offset are definded in lastFetchOptions', ->
      context 'fetching from middle of collection', ->
        beforeEach ->
          collection.lastFetchOptions = { offset: 20, limit: 10 }
          collection.getPreviousPage()

        it 'calls fetch with correct limit and offset options for next page', ->
          options = collection.fetch.calls.mostRecent().args[0]
          expect(options.limit).toEqual 10
          expect(options.offset).toEqual 10

      context 'fetching from end of collection', ->
        beforeEach ->
          collection.lastFetchOptions = { offset: 0, limit: 20 }
          collection.getPreviousPage()

        it 'calls fetch with correct limit and offset options for next page', ->
          options = collection.fetch.calls.mostRecent().args[0]
          expect(options.limit).toEqual 20
          expect(options.offset).toEqual 0

    context 'when page and perPage are defined in lastFetchOptions', ->
      context 'fetching from middle of collection', ->
        beforeEach ->
          collection.lastFetchOptions = { perPage: 20, page: 2 }
          collection.getPreviousPage()

        it 'calls fetch with the correct page and perPage options for next page', ->
          options = collection.fetch.calls.mostRecent().args[0]
          expect(options.perPage).toEqual 20
          expect(options.page).toEqual 1

      context 'fetching from end of collection', ->
        beforeEach ->
          collection.lastFetchOptions = { perPage: 20, page: 1 }
          collection.getPreviousPage()

        it 'calls fetch with the correct page and perPage options for next page', ->
          options = collection.fetch.calls.mostRecent().args[0]
          expect(options.perPage).toEqual 20
          expect(options.page).toEqual 1

  describe '#getFirstPage', ->
    collection = null

    beforeEach ->
      collection = new Tasks()
      collection.lastFetchOptions = {}

      spyOn(collection, 'fetch')
      spyOn(collection, 'getServerCount').and.returnValue(50)

    it 'calls _canPaginate', ->
      spyOn(collection, '_canPaginate')
      spyOn(collection, '_maxPage')

      collection.getFirstPage()

      expect(collection._canPaginate).toHaveBeenCalled()

    context 'offset is not defined in lastFetchOptions', ->
      beforeEach ->
        collection.lastFetchOptions = { page: 3, perPage: 5 }
        collection.getFirstPage()

      it 'calls fetch', ->
        expect(collection.fetch).toHaveBeenCalled()

      it 'calls fetch with correct "perPage" options', ->
        expect(collection.fetch.calls.mostRecent().args[0].page).toEqual(1)

    context 'offset is defined in lastFetchOptions', ->
      beforeEach ->
        collection.lastFetchOptions = { offset: 20, limit: 10 }
        collection.getFirstPage()

      it 'calls fetch', ->
        expect(collection.fetch).toHaveBeenCalled()

      it 'calls fetch with correct "perPage" options', ->
        expect(collection.fetch.calls.mostRecent().args[0].offset).toEqual(0)

  describe '#getLastPage', ->
    collection = null

    beforeEach ->
      collection = new Tasks()
      collection.lastFetchOptions = {}
      spyOn(collection, 'fetch')

    it 'calls _canPaginate', ->
      spyOn(collection, '_canPaginate')
      spyOn(collection, '_maxPage')

      collection.getLastPage()

      expect(collection._canPaginate).toHaveBeenCalled()

    context 'both offset and limit are defined in lastFetchOptions', ->
      beforeEach ->
        collection.lastFetchOptions = { offset: 15, limit: 5 }

      context 'last page is a partial page', ->
        beforeEach ->
          spyOn(collection, 'getServerCount').and.returnValue(33)

        it 'fetches with offset and limit defined correctly', ->
          collection.getLastPage()

          expect(collection.fetch).toHaveBeenCalled()
          fetchOptions = collection.fetch.calls.mostRecent().args[0]
          expect(fetchOptions.offset).toEqual(30)
          expect(fetchOptions.limit).toEqual(5)

      context 'last page is a complete page', ->
        beforeEach ->
          spyOn(collection, 'getServerCount').and.returnValue(35)

        it 'fetches with offset and limit defined correctly', ->
          collection.getLastPage()

          expect(collection.fetch).toHaveBeenCalled()
          fetchOptions = collection.fetch.calls.mostRecent().args[0]
          expect(fetchOptions.offset).toEqual(30)
          expect(fetchOptions.limit).toEqual(5)

    context 'offset is not defined, both perPage and page are defined in lastFetchOptions', ->
      beforeEach ->
        collection.lastFetchOptions = { perPage: 10, page: 2 }
        spyOn(collection, 'getServerCount').and.returnValue(53)

      it 'fetches with perPage and page defined', ->
        collection.getLastPage()

        expect(collection.fetch).toHaveBeenCalled()
        fetchOptions = collection.fetch.calls.mostRecent().args[0]
        expect(fetchOptions.page).toEqual(6)
        expect(fetchOptions.perPage).toEqual(10)

  describe '#getPage', ->
    collection = null

    beforeEach ->
      collection = new Tasks()
      collection.lastFetchOptions = {}
      spyOn(collection, 'fetch')

    it 'calls _canPaginate with throwError = true', ->
      spyOn(collection, '_canPaginate')
      spyOn(collection, '_maxPage')

      collection.getPage()

      expect(collection._canPaginate).toHaveBeenCalledWith(true)

    context 'perPage and page are defined in lastFetchOptions', ->
      beforeEach ->
        collection.lastFetchOptions = { perPage: 20, page: 5 }
        spyOn(collection, 'getServerCount').and.returnValue(400)

      context 'there is a page to fetch', ->
        it 'fetches the page', ->
          collection.getPage(10)

          expect(collection.fetch).toHaveBeenCalled()
          options = collection.fetch.calls.mostRecent().args[0]
          expect(options.page).toEqual(10)
          expect(options.perPage).toEqual(20)

      context 'an index greater than the max page is specified', ->
        it 'gets called with max page index', ->
          collection.getPage(21)
          options = collection.fetch.calls.mostRecent().args[0]
          expect(options.page).toEqual(20)

    context 'collection has limit and offset defined', ->
      beforeEach ->
        collection.lastFetchOptions = { limit: 20, offset: 20 }
        spyOn(collection, 'getServerCount').and.returnValue(400)

      context 'when offset is zero', ->
        beforeEach ->
          collection.lastFetchOptions.offset = 0

        it 'still uses limit and offset to fetch', ->
          collection.getPage(2)
          options = collection.fetch.calls.mostRecent().args[0]
          expect(options.offset).toEqual(20)

      context 'there is a page to fetch', ->
        it 'fetches the page', ->
          collection.getPage(10)

          expect(collection.fetch).toHaveBeenCalled()
          options = collection.fetch.calls.mostRecent().args[0]
          expect(options.limit).toEqual(20)
          expect(options.offset).toEqual(180)

      context 'an index greater than the max page is specified', ->
        it 'gets called with max page index', ->
          collection.getPage(21)
          options = collection.fetch.calls.mostRecent().args[0]
          expect(options.offset).toEqual(380)

  describe '#hasNextPage', ->
    collection = null
    beforeEach ->
      collection = new Tasks()
      spyOn(collection, 'getServerCount').and.returnValue(100)

    context 'collection\'s `lastFetchOptions` are undefined', ->
      beforeEach ->
        collection.lastFetchOptions = undefined

      it 'returns false', ->
        expect(collection.hasNextPage()).toEqual(false)

      it 'doesn\'t throw an error', ->
        expect(-> collection.hasNextPage()).not.toThrow()

    context 'offset is defined', ->
      context 'at the end of a collection', ->
        beforeEach ->
          collection.lastFetchOptions = { limit: 20, offset: 80 }

        it 'returns false', ->
          expect(collection.hasNextPage()).toEqual(false)

      context 'in the middle of a collection', ->
        beforeEach ->
          collection.lastFetchOptions = { limit: 20, offset: 40 }

        it 'returns true', ->
          expect(collection.hasNextPage()).toEqual(true)

    context 'page is defined', ->
      context 'at the end of a collection', ->
        beforeEach ->
          collection.lastFetchOptions = { page: 5, perPage: 20 }

        it 'returns false', ->
          expect(collection.hasNextPage()).toEqual(false)

      context 'in the middle of a collection', ->
        beforeEach ->
          collection.lastFetchOptions = { page: 3, perPage: 20 }

        it 'returns true', ->
          expect(collection.hasNextPage()).toEqual(true)

  describe '#hasPreviousPage', ->
    collection = null
    beforeEach ->
      collection = new Tasks()
      spyOn(collection, 'getServerCount').and.returnValue(100)

    context 'collection\'s `lastFetchOptions` are undefined', ->
      beforeEach ->
        collection.lastFetchOptions = undefined

      it 'returns false', ->
        expect(collection.hasNextPage()).toEqual(false)

      it 'doesn\'t throw an error', ->
        expect(-> collection.hasNextPage()).not.toThrow()

    context 'offset is defined', ->
      context 'at the front of a collection', ->
        beforeEach ->
          collection.lastFetchOptions = { limit: 20, offset: 0 }

        it 'returns false', ->
          expect(collection.hasPreviousPage()).toEqual(false)

      context 'in the middle of a collection', ->
        beforeEach ->
          collection.lastFetchOptions = { limit: 20, offset: 40 }

        it 'returns true', ->
          expect(collection.hasPreviousPage()).toEqual(true)

    context 'page is defined', ->
      context 'at the front of a collection', ->
        beforeEach ->
          collection.lastFetchOptions = { page: 0, perPage: 20 }

        it 'returns false', ->
          expect(collection.hasPreviousPage()).toEqual(false)

      context 'in the middle of a collection', ->
        beforeEach ->
          collection.lastFetchOptions = { page: 3, perPage: 20 }

        it 'returns true', ->
          expect(collection.hasPreviousPage()).toEqual(true)

  describe '#invalidateCache', ->
    it 'invalidates the cache object', ->
      posts = (buildPost(message: 'old post', reply_ids: []) for i in [1..5])
      respondWith server, '/api/posts?include=replies&parents_only=true&per_page=5&page=1', resultsFrom: 'posts', data: { count: posts.length, posts: posts }
      loader = storageManager.loadObject 'posts', include: ['replies'], filters: { parents_only: 'true' }, perPage: 5

      expect(loader.getCacheObject()).toBeUndefined()
      server.respond()

      expect(loader.getCacheObject().valid).toEqual true
      loader.getCollection().invalidateCache()
      expect(loader.getCacheObject().valid).toEqual false

  describe '#toServerJSON', ->
    beforeEach ->
      spyOn(model, 'toServerJSON').and.callThrough() for model in collection.models

    it 'returns model contents serialized using model server json', ->
      expect(_(collection.toServerJSON()).pluck('id')).toEqual(collection.pluck('id'))

    it 'passes method to model method calls', ->
      collection.toServerJSON('update')
      expect(model.toServerJSON).toHaveBeenCalledWith('update') for model in collection.models

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
      collection = new Collection([
        new Model(id: 2, title: 'Alpha', updated_at: 2,  cool: false),
        new Model(id: 3, title: 'Beta',  updated_at: 10, cool: true),
        new Model(id: 4, title: 'Gamma', updated_at: 5,  cool: false),
        new Model(id: 6, title: 'Gamma', updated_at: 5,  cool: false),
        new Model(id: 5, title: 'Gamma', updated_at: 4,  cool: true)
      ])

    describe '@getComparatorWithIdFailover', ->
      it 'returns a comparator that works for numerical ordering of unix timestamps, failing over to id when theyre the same', ->
        newCollection = new Collection collection.models, comparator: Collection.getComparatorWithIdFailover('updated_at:desc')
        newCollection.sort()
        expect(newCollection.pluck('id')).toEqual [3, 6, 4, 5, 2]

        newCollection = new Collection collection.models, comparator: Collection.getComparatorWithIdFailover('updated_at:asc')
        newCollection.sort()
        expect(newCollection.pluck('id')).toEqual [2, 5, 4, 6, 3]

  describe '#_canPaginate', ->
    beforeEach ->
      collection = new Tasks()
      spyOn(Utils, 'throwError').and.callThrough()

    context 'lastFetchOptions is not defined', ->
      beforeEach ->
        collection.lastFetchOptions = undefined

      context 'throwError is passed as false', ->
        it 'returns false', ->
          expect(collection._canPaginate()).toBe false

      context 'throwError is passed as true', ->
        it 'throws an error', ->
          expect(-> collection._canPaginate(true)).toThrow()
          expect(Utils.throwError.calls.mostRecent().args[0]).toMatch(/collection must have been fetched once/)

    context 'lastFetchOptions is defined', ->
      beforeEach ->
        collection.lastFetchOptions = {}

      context 'collection has count', ->
        beforeEach ->
          spyOn(collection, 'getServerCount').and.returnValue(10)

        context 'neither limit nor perPage are defined', ->
          beforeEach ->
            collection.lastFetchOptions = { limit: undefined, perPage: undefined }


          context 'throwError is passed as false', ->
            it 'returns false', ->
              expect(collection._canPaginate()).toBe false

          context 'throwError is passed as true', ->
            it 'throws an error', ->
              expect(-> collection._canPaginate(true)).toThrow()
              expect(Utils.throwError.calls.mostRecent().args[0]).toMatch(/perPage or limit must be defined/)



      context 'collection does not have count', ->
        beforeEach ->
          collection.lastFetchOptions.name = 'tasks'

        context 'throwError is passed as false', ->
          it 'returns false', ->
            expect(collection._canPaginate()).toBe false

        context 'throwError is passed as true', ->
          it 'throws an error', ->
            expect(-> collection._canPaginate(true)).toThrow()
            expect(Utils.throwError.calls.mostRecent().args[0]).toMatch(/collection must have a count/)

      context 'name is not defined in lastFetchOptions', ->
        beforeEach ->
          delete collection.lastFetchOptions.name

        context 'throwError is passed as false', ->
          it 'still returns false', ->
            expect(collection._canPaginate()).toBe false

        context 'throwError is passed as true', ->
          it 'still throws the correct error', ->
            expect(-> collection._canPaginate(true)).toThrow()
            expect(Utils.throwError.calls.mostRecent().args[0]).toMatch(/collection must have a count/)

  describe '#_maxOffset', ->
    beforeEach ->
      collection = new Tasks()

    context 'limit is not defined in lastFetchOptions', ->
      beforeEach ->
        collection.lastFetchOptions = { limit: undefined }

      it 'throws if limit is not defined', ->
        expect(-> collection._maxOffset()).toThrow()

    context 'limit is defined', ->
      beforeEach ->
        collection.lastFetchOptions = { limit: 20 }
        spyOn(collection, 'getServerCount').and.returnValue(100)

      it 'returns the maximum possible offset', ->
        expect(collection._maxOffset()).toEqual(collection.getServerCount() - collection.lastFetchOptions.limit)

  describe '#_maxPage', ->
    beforeEach ->
      collection = new Tasks()

    context 'perPage is not defined in lastFetchOptions', ->
      beforeEach ->
        collection.lastFetchOptions = { perPage: undefined }

      it 'throws if perPage is not defined', ->
        expect(-> collection._maxPage()).toThrow()

    context 'perPage is defined', ->
      beforeEach ->
        collection.lastFetchOptions = { perPage: 20 }
        spyOn(collection, 'getServerCount').and.returnValue(100)

      it 'returns the maximum possible page', ->
        expect(collection._maxPage()).toEqual(collection.getServerCount() / collection.lastFetchOptions.perPage )
