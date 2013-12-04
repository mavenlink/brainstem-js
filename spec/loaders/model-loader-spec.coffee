describe 'Loaders ModelLoader', ->
  loader = opts = null
  fakeNestedInclude = ['parent', { project: ['participants'] }, { assignees: ['something_else'] }]
  loaderClass = Brainstem.ModelLoader
  
  defaultLoadOptions = ->
    name: 'task'
    only: 1

  createLoader = (opts = {}) ->
    storageManager = new Brainstem.StorageManager()
    storageManager.addCollection('tasks', App.Collections.Tasks)

    defaults = 
      storageManager: storageManager

    loader = new loaderClass(_.extend {}, defaults, opts)
    loader

  # It should keep the AbstractLoader behavior.
  itShouldBehaveLike "AbstractLoaderSharedBehavior", loaderClass: loaderClass

  describe 'ModelLoader behavior', ->
    beforeEach ->
      loader = createLoader()
      opts = defaultLoadOptions()

    describe '#getCollectionName', ->
      it 'returns the pluralized name of the model', ->
        loader.setup(opts)
        expect(loader.getCollectionName()).toEqual 'tasks'

    describe '#_createInternalObject', ->
      model = null

      beforeEach ->
        spyOn(loader, '_createExternalObject')
        model = new App.Models.Task()
        spyOn(loader.storageManager, 'createNewModel').andReturn model

      it 'creates a new model from the name in loadOptions', ->
        loader.setup(opts)
        expect(loader.storageManager.createNewModel.callCount).toEqual 1
        expect(loader.internalObject).toEqual model

      it 'sets the id on the internalObjecrt', ->
        loader.setup(opts)
        expect(loader.internalObject.id).toEqual '1'

    describe '#_createExternalObject', ->
      model = null

      beforeEach ->
        spyOn(loader, '_createInternalObject')
        model = new App.Models.Task()
        spyOn(loader.storageManager, 'createNewModel').andReturn model

      context 'model is passed in to loadOptions', ->
        it 'uses the model that is passed in', ->
          opts.model ?= new App.Models.Task()
          loader.setup(opts)
          expect(loader.storageManager.createNewModel).not.toHaveBeenCalled()
          expect(loader.externalObject).toEqual opts.model

      context 'model is not passed in to loadOptions', ->
        it 'creates a new model from the name in loadOptions', ->
          loader.setup(opts)
          expect(loader.storageManager.createNewModel.callCount).toEqual 1
          expect(loader.externalObject).toEqual model

      it 'sets the id on the externalObject', ->
        loader.setup(opts)
        expect(loader.externalObject.id).toEqual '1'

    describe '#_updateStorageManagerFromResponse', ->
      it 'calls parse on the internalObject with the response', ->
        loader.setup(opts)
        spyOn(loader.internalObject, 'parse')

        loader._updateStorageManagerFromResponse('test response')
        expect(loader.internalObject.parse).toHaveBeenCalledWith 'test response'

    describe '#_updateObject', ->
      it 'triggers loaded on the object after the attributes have been set', ->
        loadedSpy = jasmine.createSpy().andCallFake -> 
          expect(this.get('foo')).toEqual 'bar' # make sure that the spy is called after the attribute has been set (tests the trigger: false)

        loader.setup(opts)
        loader.internalObject.listenTo loader.internalObject, 'loaded', loadedSpy

        loader._updateObjects(loader.internalObject, foo: 'bar')
        expect(loadedSpy).toHaveBeenCalled()

      it 'works with a Backbone.Model', ->
        loader.setup(opts)
        loader._updateObjects(loader.internalObject, new Backbone.Model(name: 'foo'))
        expect(loader.internalObject.get('name')).toEqual 'foo'

      it 'works with an array with a Backbone.Model', ->
        loader.setup(opts)
        loader._updateObjects(loader.internalObject, [new Backbone.Model(name: 'foo')])
        expect(loader.internalObject.get('name')).toEqual 'foo'

      it 'works with an array of data', ->
        loader.setup(opts)
        loader._updateObjects(loader.internalObject, [name: 'foo'])
        expect(loader.internalObject.get('name')).toEqual 'foo'

    describe '#_getModel', ->
      it 'returns the constructor of the internalObject', ->
        loader.setup(opts)
        expect(loader._getModel()).toEqual App.Models.Task

    describe '#_getModelsForAssociation', ->
      it 'returns the models from the internalObject for a given association', ->
        loader.setup(opts)
        user = buildAndCacheUser()
        loader.internalObject.set('assignee_ids', [user.id])

        expect(loader._getModelsForAssociation('assignees')).toEqual [user] # Association with a model in it
        expect(loader._getModelsForAssociation('parent')).toEqual [] # Association without any models
        expect(loader._getModelsForAssociation('adfasfa')).toEqual [] # Association that does not exist