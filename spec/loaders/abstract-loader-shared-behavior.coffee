registerSharedBehavior "AbstractLoaderSharedBehavior", (sharedContext) ->
  loader = loaderClass = null

  beforeEach ->
    loaderClass = sharedContext.loaderClass

  fakeNestedInclude = ['parent', { project: ['participants'] }, { assignees: ['something_else'] }]

  defaultLoadOptions = ->
    name: 'tasks'

  createLoader = (opts = {}) ->
    storageManager = new Brainstem.StorageManager()
    storageManager.addCollection('tasks', App.Collections.Tasks)

    defaults =
      storageManager: storageManager

    loader = new loaderClass(_.extend {}, defaults, opts)
    loader._getCollectionName = -> 'tasks'
    loader._createObjects = ->
      @internalObject = bar: 'foo'
      @externalObject = foo: 'bar'

    loader._getModelsForAssociation = -> [{ id: 5 }, { id: 2 }, { id: 1 }, { id: 4 }, { id: 1 }, [{ id: 6 }], { id: null }]
    loader._getModel = -> App.Collections.Tasks::model
    loader._updateStorageManagerFromResponse = jasmine.createSpy()
    loader._updateObjects = (obj, data, silent) ->
      obj.setLoaded true unless silent

    spyOn(loader, '_updateObjects')

    loader

  describe '#constructor', ->
    it 'saves off a reference to the passed in StorageManager', ->
      storageManager = new Brainstem.StorageManager()
      loader = createLoader(storageManager: storageManager)
      expect(loader.storageManager).toEqual storageManager

    it 'creates a deferred object and turns the loader into a promise', ->
      spy = jasmine.createSpy('promise spy')

      loader = createLoader()
      expect(loader._deferred).not.toBeUndefined()
      loader.then(spy)

      loader._deferred.resolve()
      expect(spy).toHaveBeenCalled()

    describe 'options.loadOptions', ->
      it 'calls #setup with loadOptions if loadOptions were passed in', ->
        spy = spyOn(loaderClass.prototype, 'setup')

        loader = createLoader(loadOptions: defaultLoadOptions())
        expect(spy).toHaveBeenCalledWith defaultLoadOptions()

      it 'does not call #setup if loadOptions were not passed in', ->
        spy = spyOn(loaderClass.prototype, 'setup')

        loader = createLoader()
        expect(spy).not.toHaveBeenCalled()

  describe '#setup', ->
    it 'calls #_parseLoadOptions with the loadOptions', ->
      loader = createLoader()
      spyOn(loader, '_parseLoadOptions')

      opts = foo: 'bar'

      loader.setup(opts)
      expect(loader._parseLoadOptions).toHaveBeenCalledWith(opts)

    it 'calls _createObjects', ->
      loader = createLoader()
      spyOn(loader, '_createObjects')

      loader.setup()
      expect(loader._createObjects).toHaveBeenCalled()

    it 'returns the externalObject', ->
      loader = createLoader()
      spyOn(loader, '_parseLoadOptions')

      externalObject = loader.setup()
      expect(externalObject).toEqual(loader.externalObject)

  describe '#getCacheObject', ->
    it 'returns the object', ->
      loader = createLoader()
      opts = defaultLoadOptions()
      loader.setup(opts)
      cacheKey = loader.loadOptions.cacheKey

      expect(loader.getCacheObject()).toBeUndefined()
      fakeCache = [key: "tasks", id: 5]
      loader.storageManager.getCollectionDetails(loader._getCollectionName()).cache[cacheKey] = fakeCache
      expect(loader.getCacheObject()).toEqual fakeCache

  describe '#load', ->
    describe 'sanity checking loadOptions', ->
      funct = null

      beforeEach ->
        loader = createLoader()
        spyOn(loader, '_checkCacheForData')
        spyOn(loader, '_loadFromServer')
        funct = -> loader.load()

      it 'throws if there are no loadOptions', ->
        expect(funct).toThrow()

      it 'does not throw if there are loadOptions', ->
        loader.loadOptions = {}
        expect(funct).not.toThrow()

    describe 'checking the cache', ->
      beforeEach ->
        loader = createLoader()
        spyOn(loader, '_checkCacheForData')
        spyOn(loader, '_loadFromServer')

      context 'loadOptions.cache is true', ->
        it 'calls #_checkCacheForData', ->
          loader.setup()
          expect(loader.loadOptions.cache).toEqual(true)

          loader.load()
          expect(loader._checkCacheForData).toHaveBeenCalled()

        context '#_checkCacheForData returns data', ->
          it 'returns the data', ->
            fakeData = ['some', 'stuff']
            loader._checkCacheForData.andReturn(fakeData)

            loader.setup()
            expect(loader.load()).toEqual(fakeData)

        context '#_checkCacheForData does not return data', ->
          it 'calls #_loadFromServer', ->
            loader.setup()
            loader.load()
            expect(loader._loadFromServer).toHaveBeenCalled()

      context 'loadOptions.cache is false', ->
        it 'does not call #_checkCacheForData', ->
          loader.setup(cache: false)

          loader.load()
          expect(loader._checkCacheForData).not.toHaveBeenCalled()

        it 'calls #_loadFromServer', ->
          loader.setup()
          loader.load()
          expect(loader._loadFromServer).toHaveBeenCalled()

  describe '#_getIdsForAssociation', ->
    it 'returns the flattened, unique, sorted, and non-null IDs from the models that are returned from #_getModelsForAssociation', ->
      loader = createLoader()
      expect(loader._getIdsForAssociation('foo')).toEqual [1, 2, 4, 5, 6]

  describe '#_updateObjects', ->
    fakeObj = null

    beforeEach ->
      loader = createLoader()
      fakeObj = setLoaded: jasmine.createSpy()
      loader._updateObjects.andCallThrough()

    it 'sets the object to loaded if silent is false', ->
      loader._updateObjects(fakeObj, {})
      expect(fakeObj.setLoaded).toHaveBeenCalled()

    it 'does not set the object to loaded if silent is true', ->
      loader._updateObjects(fakeObj, {}, true)
      expect(fakeObj.setLoaded).not.toHaveBeenCalled()

  describe '#_parseLoadOptions', ->
    opts = null

    beforeEach ->
      loader = createLoader()
      opts = defaultLoadOptions()

    it 'saves off a reference of the loadOptions as originalOptions', ->
      loader._parseLoadOptions(defaultLoadOptions())
      expect(loader.originalOptions).toEqual(defaultLoadOptions())

    it 'parses the include options', ->
      opts.include = ['foo': ['bar'], 'toad', 'stool']
      loadOptions = loader._parseLoadOptions(opts)

      expect(loadOptions.include).toEqual [
        { foo: [{ bar: [ ]}] }
        { toad: [] }
        { stool: [] }
      ]

    describe 'only parsing', ->
      context 'only is present', ->
        it 'sets only as an array of strings from the original only', ->
          opts.only = [1, 2, 3, 4]
          loadOptions = loader._parseLoadOptions(opts)

          expect(loadOptions.only).toEqual ['1', '2', '3', '4']

      context 'only is not present', ->
        it 'sets only as null', ->
          loadOptions = loader._parseLoadOptions(opts)
          expect(loadOptions.only).toEqual(null)

    it 'defaults filters to an empty object', ->
      loadOptions = loader._parseLoadOptions(opts)
      expect(loadOptions.filters).toEqual {}

      # make sure it leaves them alone if they are present
      opts.filters = filters = foo: 'bar'
      loadOptions = loader._parseLoadOptions(opts)
      expect(loadOptions.filters).toEqual filters

    it 'pulls of the top layer of includes and sets them as thisLayerInclude', ->
      opts.include = ['foo': ['bar'], 'toad': ['stool'], 'mushroom']
      loadOptions = loader._parseLoadOptions(opts)
      expect(loadOptions.thisLayerInclude).toEqual ['foo', 'toad', 'mushroom']

    it 'defaults cache to true', ->
      loadOptions = loader._parseLoadOptions(opts)
      expect(loadOptions.cache).toEqual true

      # make sure it leaves cache alone if it is present
      opts.cache = false
      loadOptions = loader._parseLoadOptions(opts)
      expect(loadOptions.cache).toEqual false

    it 'sets cache to false if search is present', ->
      opts = _.extend opts, cache: true, search: 'term'

      loadOptions = loader._parseLoadOptions(opts)
      expect(loadOptions.cache).toEqual false

    it 'builds a cache key', ->
      # order, filterKeys, page, perPage, limit, offset
      myOpts =
        order: 'myOrder'
        filters:
          key1: 'value1'
          key2: 'value2'
          key3:
            value1: 'a'
            value2: 'b'
        page: 1
        perPage: 200
        limit: 50
        offset: 0
        only: [3, 1, 2]
        search: 'foobar'

      opts = _.extend(opts, myOpts)
      loadOptions = loader._parseLoadOptions(opts)
      expect(loadOptions.cacheKey).toEqual 'myOrder|{"key1":"value1","key2":"value2","key3":{"value1":"a","value2":"b"}}|1,2,3|1|200|50|0|foobar'

    it 'sets the cachedCollection on the loader from the storageManager', ->
      loader._parseLoadOptions(opts)
      expect(loader.cachedCollection).toEqual loader.storageManager.storage(loader.loadOptions.name)

  describe '#_checkCacheForData', ->
    opts = null
    taskOne = taskTwo = null

    beforeEach ->
      loader = createLoader()
      opts = defaultLoadOptions()
      spyOn(loader, '_onLoadSuccess')

      taskOne = buildTask(id: 2)
      taskTwo = buildTask(id: 3)

    notFound = (loader, opts) ->
      loader.setup(opts)
      ret = loader._checkCacheForData()

      expect(ret).toEqual false
      expect(loader._onLoadSuccess).not.toHaveBeenCalled()

    context 'only query', ->
      beforeEach ->
        opts.only = ['2', '3']

      context 'the requested IDs have all been loaded', ->
        beforeEach ->
          loader.storageManager.storage('tasks').add([taskOne, taskTwo])

        it 'calls #_onLoadSuccess with the models from the cache', ->
          loader.setup(opts)
          loader._checkCacheForData()
          expect(loader._onLoadSuccess).toHaveBeenCalledWith([taskOne, taskTwo])

      context 'the requested IDs have not all been loaded', ->
        beforeEach ->
          loader.storageManager.storage('tasks').add([taskOne])

        it 'returns false and does not call #_onLoadSuccess', ->
          loader.setup(opts)
          notFound(loader, opts)

      context 'when optional fields have been requested but the fields arent on all the tasks', ->
        beforeEach ->
          opts.optionalFields = ['test_field']
          taskOne.set('test_field', 'fake value')
          loader.storageManager.storage('tasks').add([taskOne, taskTwo])
          loader.setup(opts)

        it 'returns false', ->
          expect(loader._checkCacheForData()).toEqual(false)

        it 'does not call #_onLoadSuccess', ->
          loader._checkCacheForData()
          expect(loader._onLoadSuccess).not.toHaveBeenCalled()

      context 'when optional fields have been requested and the fields are already on the tasks', ->
        beforeEach ->
          opts.optionalFields = ['test_field']
          taskOne.set('test_field', 'fake value for one')
          taskTwo.set('test_field', 'fake value for two')
          loader.storageManager.storage('tasks').add([taskOne, taskTwo])
          loader.setup(opts)
          loader._checkCacheForData()

        it 'calls #_onLoadSuccess with the models from the cache', ->
          expect(loader._onLoadSuccess).toHaveBeenCalledWith([taskOne, taskTwo])

    context 'not an only query', ->
      context 'there exists a cache with this cacheKey', ->
        beforeEach ->
          loader.storageManager.storage('tasks').add taskOne

        context 'cache is valid', ->
          beforeEach ->
            fakeCacheObject =
              count: 1
              results: [key: "tasks", id: taskOne.id]
              valid: true

            loader.storageManager.getCollectionDetails('tasks').cache['updated_at:desc|||||||'] = fakeCacheObject

          context 'all of the cached models have their associations loaded', ->
            beforeEach ->
              taskOne.set('project_id', buildAndCacheProject().id)

            it 'calls #_onLoadSuccess with the models from the cache', ->
              opts.include = ['project']
              loader.setup(opts)
              loader._checkCacheForData()
              expect(loader._onLoadSuccess).toHaveBeenCalledWith([taskOne])

          context 'all of the cached models do not have their associations loaded', ->
            it 'returns false and does not call #_onLoadSuccess', ->
              opts.include = ['project']
              loader.setup(opts)
              notFound(loader, opts)

          context 'all of the cached models have their optional fields loaded', ->
            beforeEach ->
              taskOne.set('test_field', 'test value')
              opts.optionalFields = ['test_field']
              loader.setup(opts)
              loader._checkCacheForData()

            it 'calls #_onLoadSuccess with the models from the cache', ->
              expect(loader._onLoadSuccess).toHaveBeenCalledWith([taskOne])

          context 'all of the cached models do not have their optional fields loaded', ->
            beforeEach ->
              opts.optionalFields = ['test_field']
              loader.setup(opts)

            it 'returns false', ->
              expect(loader._checkCacheForData()).toEqual(false)

            it 'does not call #_onLoadSuccess', ->
              loader._checkCacheForData()
              expect(loader._onLoadSuccess).not.toHaveBeenCalled()

        context 'cache is invalid', ->
          beforeEach ->
            fakeCacheObject =
              count: 1
              results: [key: "tasks", id: taskOne.id]
              valid: false

            loader.storageManager.getCollectionDetails('tasks').cache['updated_at:desc||||||'] = fakeCacheObject

          it 'returns false and does not call #_onLoadSuccess', ->
            loader.setup(opts)
            notFound(loader, opts)

      context 'there is no cache with this cacheKey', ->
        it 'does not call #_onLoadSuccess and returns false', ->
          loader.setup(opts)
          notFound(loader, opts)

  describe '#_loadFromServer', ->
    opts = syncOpts = null

    beforeEach ->
      loader = createLoader()
      opts = defaultLoadOptions()
      syncOpts = data: 'foo'

      spyOn(Backbone, 'sync').andReturn $.ajax()
      spyOn(loader, '_buildSyncOptions').andReturn(syncOpts)

    it 'calls Backbone.sync with the read, the, internalObject, and #_buildSyncOptions', ->
      loader.setup(opts)
      loader._loadFromServer()
      expect(Backbone.sync).toHaveBeenCalledWith 'read', loader.internalObject, syncOpts

    it 'puts the jqXhr on the returnValues if present', ->
      opts.returnValues = returnValues = {}
      loader.setup(opts)

      loader._loadFromServer()
      expect(returnValues.jqXhr.success).not.toBeUndefined()

    it 'returns the externalObject', ->
      loader.setup(opts)
      ret = loader._loadFromServer()
      expect(ret).toEqual loader.externalObject

  describe '#_calculateAdditionalIncludes', ->
    opts = null

    beforeEach ->
      loader = createLoader()
      opts = defaultLoadOptions()

      spyOn(loader, '_getIdsForAssociation').andReturn [1, 2]

    it 'adds each additional (sub) include to the additionalIncludes array', ->
      opts.include = fakeNestedInclude
      loader.setup(opts)

      loader._calculateAdditionalIncludes()
      expect(loader.additionalIncludes.length).toEqual 2
      expect(loader.additionalIncludes).toEqual [
        { name: 'project', ids: [1, 2], include: [participants: []] }
        { name: 'assignees', ids: [1, 2], include: [something_else: []] }
      ]

  describe '#_loadAdditionalIncludes', ->
    opts = null

    beforeEach ->
      loader = createLoader()
      opts = _.extend(defaultLoadOptions(), cache: false)
      opts.include = fakeNestedInclude

      loader.setup(opts)
      loader._calculateAdditionalIncludes()

      spyOn(loader, '_onLoadingCompleted')

    it 'respects "cache" option in nested includes', ->
      spyOn(loader.storageManager, 'loadObject')
      loader._loadAdditionalIncludes()

      for call in loader.storageManager.loadObject.calls
        expect(call.args[1].cache).toBeFalsey

    it 'creates a request for each additional include and calls #_onLoadingCompleted when they all are done', ->
      promises = []
      spyOn(loader.storageManager, 'loadObject').andCallFake ->
        promise = $.Deferred()
        promises.push(promise)
        promise

      loader._loadAdditionalIncludes()
      expect(loader.storageManager.loadObject.callCount).toEqual 2
      expect(promises.length).toEqual 2
      expect(loader._onLoadingCompleted).not.toHaveBeenCalled()

      for promise in promises
        promise.resolve()

      expect(loader._onLoadingCompleted).toHaveBeenCalled()

  describe '#_buildSyncOptions', ->
    syncOptions = opts = null

    beforeEach ->
      loader = createLoader()
      opts = defaultLoadOptions()

    getSyncOptions = (loader, opts) ->
      loader.setup(opts)
      loader._buildSyncOptions()

    it 'sets parse to true', ->
      expect(getSyncOptions(loader, opts).parse).toEqual(true)

    it 'sets error as #_onServerLoadError', ->
      expect(getSyncOptions(loader, opts).error).toEqual(loader._onServerLoadError)

    it 'sets success as #_onServerLoadSuccess', ->
      expect(getSyncOptions(loader, opts).success).toEqual(loader._onServerLoadSuccess)

    it 'sets data.include to be the layer of includes that this loader is loading', ->
      opts.include = [
        task: [ workspace: ['participants'] ]
        'time_entries'
      ]

      expect(getSyncOptions(loader, opts).data.include).toEqual('task,time_entries')

    describe 'data.only', ->
      context 'this is an only load', ->
        context '#_shouldUseOnly returns true', ->
          beforeEach ->
            spyOn(loader, '_shouldUseOnly').andReturn(true)

          it 'sets data.only to comma separated ids', ->
            opts.only = [1, 2, 3, 4]
            expect(getSyncOptions(loader, opts).data.only).toEqual '1,2,3,4'

        context '#_shouldUseOnly returns false', ->
          beforeEach ->
            spyOn(loader, '_shouldUseOnly').andReturn(true)

          it 'does not set data.only', ->
            expect(getSyncOptions(loader, opts).data.only).toBeUndefined()

      context 'this is not an only load', ->
        it 'does not set data.only', ->
          expect(getSyncOptions(loader, opts).data.only).toBeUndefined()

    describe 'data.order', ->
      it 'sets order to be loadOptions.order if present', ->
        opts.order = 'foo'
        expect(getSyncOptions(loader, opts).data.order).toEqual 'foo'

    describe 'extending data with filters and custom params', ->
      blacklist = ['include', 'only', 'order', 'per_page', 'page', 'limit', 'offset', 'search']

      excludesBlacklistFromObject = (object) ->
        object[key] = 'overwritten' for key in blacklist

        data = getSyncOptions(loader, opts).data

        expect(data[key]).toBeUndefined() for key in blacklist

      context 'filters do not exist', ->
        beforeEach ->
          opts.filters = undefined

        it 'does not throw an error parsing filters', ->
          expect()
          expect(-> getSyncOptions(loader, opts)).not.toThrow()

      context 'filters exist', ->
        beforeEach ->
          opts.filters = {}

        it 'includes filter in data object', ->
          opts.filters.foo = 'bar'

          data = getSyncOptions(loader, opts).data

          expect(data.foo).toEqual 'bar'

        it 'excludes blacklisted brainstem specific keys from filters', ->
          excludesBlacklistFromObject(opts.filters)

      context 'params do not exist', ->
        beforeEach ->
          opts.params = undefined

        it 'does not throw an error parsing params', ->
          expect(-> getSyncOptions(loader, opts)).not.toThrow()

      context 'custom params exist', ->
        beforeEach ->
          opts.params = {}

        it 'includes custom params in data object', ->
          opts.params = { color: 'red' }

          data = getSyncOptions(loader, opts).data

          expect(data.color).toEqual 'red'

        it 'excludes blacklisted brainstem specific keys from custom params', ->
          excludesBlacklistFromObject(opts.params)

    describe 'pagination', ->
      beforeEach ->
        opts.offset = 0
        opts.limit = 25
        opts.perPage = 25
        opts.page = 1

      context 'not an only request', ->
        context 'there is a limit and offset', ->
          it 'adds limit and offset', ->
            data = getSyncOptions(loader, opts).data
            expect(data.limit).toEqual 25
            expect(data.offset).toEqual 0

          it 'does not add per_page and page', ->
            data = getSyncOptions(loader, opts).data
            expect(data.per_page).toBeUndefined()
            expect(data.page).toBeUndefined()

        context 'there is not a limit and offset', ->
          beforeEach ->
            delete opts.limit
            delete opts.offset

          it 'adds per_page and page', ->
            data = getSyncOptions(loader, opts).data
            expect(data.per_page).toEqual 25
            expect(data.page).toEqual 1

          it 'does not add limit and offset', ->
            data = getSyncOptions(loader, opts).data
            expect(data.limit).toBeUndefined()
            expect(data.offset).toBeUndefined()

      context 'only request', ->
        beforeEach ->
          opts.only = 1

        it 'does not add limit, offset, per_page, or page', ->
          data = getSyncOptions(loader, opts).data
          expect(data.limit).toBeUndefined()
          expect(data.offset).toBeUndefined()
          expect(data.per_page).toBeUndefined()
          expect(data.page).toBeUndefined()

    describe 'data.search', ->
      it 'sets data.search to be loadOptions.search if present', ->
        opts.search = 'term'
        expect(getSyncOptions(loader, opts).data.search).toEqual 'term'

  describe '#_shouldUseOnly', ->
    it 'returns true if internalObject is an instance of a Backbone.Collection', ->
      loader = createLoader()
      loader.internalObject = new Backbone.Collection()
      expect(loader._shouldUseOnly()).toEqual true

    it 'returns false if internalObject is not an instance of a Backbone.Collection', ->
      loader = createLoader()
      loader.internalObject = new Backbone.Model()
      expect(loader._shouldUseOnly()).toEqual false

  describe '#_modelsOrObj', ->
    beforeEach ->
      loader = createLoader()

    context 'obj is a Backbone.Collection', ->
      it 'returns the models from the collection', ->
        collection = new Backbone.Collection()
        collection.add([new Backbone.Model(), new Backbone.Model])
        expect(loader._modelsOrObj(collection)).toEqual(collection.models)

    context 'obj is a single object', ->
      it 'returns obj wrapped in an array', ->
        obj = new Backbone.Model()
        expect(loader._modelsOrObj(obj)).toEqual([obj])

    context 'obj is an array', ->
      it 'returns obj', ->
        obj = []
        expect(loader._modelsOrObj(obj)).toEqual(obj)

    context 'obj is undefined', ->
      it 'returns an empty array', ->
        obj = null
        expect(loader._modelsOrObj(obj)).toEqual([])

  describe '#_onServerLoadSuccess', ->
    beforeEach ->
      loader = createLoader()
      spyOn(loader, '_onLoadSuccess')

    it 'calls #_updateStorageManagerFromResponse with the response', ->
      loader._onServerLoadSuccess('response')
      expect(loader._updateStorageManagerFromResponse).toHaveBeenCalledWith 'response'

    it 'calls #_onServerLoadSuccess with the result from #_updateStorageManagerFromResponse', ->
      loader._updateStorageManagerFromResponse.andReturn 'data'

      loader._onServerLoadSuccess()
      expect(loader._onLoadSuccess).toHaveBeenCalledWith 'data'

  describe '#_onLoadSuccess', ->
    beforeEach ->
      loader = createLoader()
      loader.additionalIncludes = []
      spyOn(loader, '_onLoadingCompleted')
      spyOn(loader, '_loadAdditionalIncludes')
      spyOn(loader, '_calculateAdditionalIncludes')

    it 'calls #_updateObjects with the internalObject, the data, and silent set to true', ->
      loader._onLoadSuccess('test data')
      expect(loader._updateObjects).toHaveBeenCalledWith(loader.internalObject, 'test data', true)

    it 'calls #_calculateAdditionalIncludes', ->
      loader._onLoadSuccess()
      expect(loader._calculateAdditionalIncludes).toHaveBeenCalled()

    context 'additional includes are needed', ->
      it 'calls #_loadAdditionalIncludes', ->
        loader._calculateAdditionalIncludes.andCallFake -> @additionalIncludes = ['foo']

        loader._onLoadSuccess()
        expect(loader._loadAdditionalIncludes).toHaveBeenCalled()
        expect(loader._onLoadingCompleted).not.toHaveBeenCalled()

    context 'additional includes are not needed', ->
      it 'calls #_onLoadingCompleted', ->
        loader._onLoadSuccess()
        expect(loader._onLoadingCompleted).toHaveBeenCalled()
        expect(loader._loadAdditionalIncludes).not.toHaveBeenCalled()

  describe '#_onLoadingCompleted', ->
    beforeEach ->
      loader = createLoader()

    it 'calls #_updateObjects with the externalObject and internalObject', ->
      loader._onLoadingCompleted()
      expect(loader._updateObjects).toHaveBeenCalledWith(loader.externalObject, loader.internalObject)

    it 'resolves the deferred object with the externalObject', ->
      spy = jasmine.createSpy()
      loader.then(spy)

      loader._onLoadingCompleted()
      expect(spy).toHaveBeenCalledWith(loader.externalObject)
