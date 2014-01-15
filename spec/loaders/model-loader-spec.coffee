describe 'Loaders ModelLoader', ->
  loader = opts = null
  fakeNestedInclude = ['parent', { project: ['participants'] }, { assignees: ['something_else'] }]
  loaderClass = Brainstem.ModelLoader
  
  defaultLoadOptions = ->
    name: 'task'
    only: 1

  createLoader = (opts = {}) ->
    storageManager = base.data
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

    describe '#getModel', ->
      it 'should return the externalObject', ->
        loader.setup(opts)
        expect(loader.getModel()).toEqual loader.externalObject

    describe '#_getCollectionName', ->
      it 'returns the pluralized name of the model', ->
        loader.setup(opts)
        expect(loader._getCollectionName()).toEqual 'tasks'

    describe '#_createObjects', ->
      model = null

      context 'there is a matching model in the storageManager', ->
        it 'sets the internalObject to be the cached model', ->
          model = buildAndCacheTask(id: 1)
          loader.setup(opts)
          expect(loader.internalObject).toEqual model

      context 'there is not a matching model in the storageManager', ->
        it 'creates a new model and uses that as the internalObject', ->
          model = new App.Models.Task()
          spyOn(loader.storageManager, 'createNewModel').andReturn model
          loader.setup(opts)
          expect(loader.internalObject).toEqual model

        it 'sets the ID on that model', ->
          loader.setup(opts)
          expect(loader.internalObject.id).toEqual '1'

      it 'uses the internalObject as the externalObject', ->
        loader.setup(opts)
        expect(loader.internalObject).toEqual loader.externalObject

    describe '#_updateStorageManagerFromResponse', ->
      it 'calls parse on the internalObject with the response', ->
        loader.setup(opts)
        spyOn(loader.internalObject, 'parse')

        loader._updateStorageManagerFromResponse('test response')
        expect(loader.internalObject.parse).toHaveBeenCalledWith 'test response'

    describe '#_updateObject', ->
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