describe 'Loaders CollectionLoader', ->
  loader = opts = null
  fakeNestedInclude = ['parent', { project: ['participants'] }, { assignees: ['something_else'] }]
  loaderClass = Brainstem.CollectionLoader
  
  defaultLoadOptions = ->
    name: 'tasks'

  createLoader = (opts = {}) ->
    storageManager = new Brainstem.StorageManager()
    storageManager.addCollection('tasks', App.Collections.Tasks)

    defaults = 
      storageManager: storageManager

    loader = new loaderClass(_.extend {}, defaults, opts)
    loader

  # It should keep the AbstractLoader behavior.
  itShouldBehaveLike "AbstractLoaderSharedBehavior", loaderClass: loaderClass

  describe 'CollectionLoader behavior', ->
    beforeEach ->
      loader = createLoader()
      opts = defaultLoadOptions()

    describe '#_getCollectionName', ->
      it 'should return the name from loadOptions', ->
        loader.setup(opts)
        expect(loader._getCollectionName()).toEqual 'tasks'

    describe '#_createInternalObject', ->
      collection = null

      beforeEach ->
        spyOn(loader, '_createExternalObject')
        collection = new App.Collections.Tasks()
        spyOn(loader.storageManager, 'createNewCollection').andReturn collection

      it 'creates a new collection from the name in loadOptions', ->
        loader.setup(opts)
        expect(loader.storageManager.createNewCollection.callCount).toEqual 1
        expect(loader.internalObject).toEqual collection

    describe '#_createExternalObject', ->
      collection = null

      beforeEach ->
        spyOn(loader, '_createInternalObject')
        collection = new App.Collections.Tasks()
        spyOn(loader.storageManager, 'createNewCollection').andReturn collection

      context 'collection is passed in to loadOptions', ->
        it 'uses the collection that is passed in', ->
          opts.collection ?= new App.Collections.Tasks()
          loader.setup(opts)
          expect(loader.storageManager.createNewCollection).not.toHaveBeenCalled()
          expect(loader.externalObject).toEqual opts.collection

      context 'collection is not passed in to loadOptions', ->
        it 'creates a new collection from the name in loadOptions', ->
          loader.setup(opts)
          expect(loader.storageManager.createNewCollection.callCount).toEqual 1
          expect(loader.externalObject).toEqual collection

      it 'sets the collection to not loaded', ->
        spyOn(collection, 'setLoaded')
        loader.setup(opts)
        expect(collection.setLoaded).toHaveBeenCalledWith false

      describe 'resetting the collection', ->
        context 'loadOptions.reset is true', ->
          beforeEach ->
            opts.reset = true

          it 'calls reset on the collection', ->
            spyOn(collection, 'reset')
            loader.setup(opts)
            expect(collection.reset).toHaveBeenCalled()

        context 'loadOptions.reset is false', ->
          it 'does not reset the collection', ->
            spyOn(collection, 'reset')
            loader.setup(opts)
            expect(collection.reset).not.toHaveBeenCalled()

      it 'sets lastFetchOptions on the collection', ->
        list = ['filters', 'page', 'perPage', 'limit', 'offset', 'order', 'search']

        for e in list
          opts[e] = true

        opts.include = 'parent'
        loader.setup(opts)

        expect(loader.externalObject.lastFetchOptions.name).toEqual 'tasks'
        expect(loader.externalObject.lastFetchOptions.include).toEqual 'parent'

        for e in list
          expect(loader.externalObject.lastFetchOptions[e]).toEqual true

    # describe '#_updateStorageManagerFromResponse', ->
      # TODO: test this, it's tested right now through integration tests.

    describe '#_updateObject', ->
      it 'triggers loaded on the object after the attributes have been set', ->
        loadedSpy = jasmine.createSpy().andCallFake -> 
          expect(this.length).toEqual 1 # make sure that the spy is called after the models have been added (tests the trigger: false)

        loader.setup(opts)
        loader.internalObject.listenTo loader.internalObject, 'loaded', loadedSpy

        loader._updateObjects(loader.internalObject, [{foo: 'bar'}])
        expect(loadedSpy).toHaveBeenCalled()

      it 'works with a Backbone.Collection', ->
        loader.setup(opts)
        loader._updateObjects(loader.internalObject, new Backbone.Collection([new Backbone.Model(name: 'foo')]))
        expect(loader.internalObject.length).toEqual 1

      it 'works with an array of models', ->
        loader.setup(opts)
        loader._updateObjects(loader.internalObject, [new Backbone.Model(name: 'foo'), new Backbone.Model(name: 'test')])
        expect(loader.internalObject.length).toEqual 2

      it 'works with a single model', ->
        loader.setup(opts)
        spy = jasmine.createSpy()
        loader.internalObject.listenTo loader.internalObject, 'reset', spy

        loader._updateObjects(loader.internalObject, new Backbone.Model(name: 'foo'))
        expect(loader.internalObject.length).toEqual 1
        expect(spy).toHaveBeenCalled()

    describe '#_getModel', ->
      it 'returns the model from the internal collection', ->
        loader.setup(opts)
        expect(loader._getModel()).toEqual App.Models.Task

    describe '#_getModelsForAssociation', ->
      it 'returns the models for a given association from all of the models in the internal collection', ->
        loader.setup(opts)
        user = buildAndCacheUser()
        user2 = buildAndCacheUser()

        loader.internalObject.add(new App.Models.Task(assignee_ids: [user.id]))
        loader.internalObject.add(new App.Models.Task(assignee_ids: [user2.id]))

        expect(loader._getModelsForAssociation('assignees')).toEqual [[user], [user2]] # Association with a model in it
        expect(loader._getModelsForAssociation('parent')).toEqual [[], []] # Association without any models
        expect(loader._getModelsForAssociation('adfasfa')).toEqual [[], []] # Association that does not exist