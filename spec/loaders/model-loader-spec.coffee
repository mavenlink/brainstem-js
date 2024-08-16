$ = require 'jquery'
{ extend } = require '../../src/utility-functions'
Backbone = require 'backbone'
Backbone.$ = $ # TODO remove after upgrading to backbone 1.2+
StorageManager = require '../../src/storage-manager'
ModelLoader = require '../../src/loaders/model-loader'

Task = require '../helpers/models/task'
Tasks = require '../helpers/models/tasks'


describe 'Loaders ModelLoader', ->
  loader = opts = null
  fakeNestedInclude = ['parent', { project: ['participants'] }, { assignees: ['something_else'] }]
  loaderClass = ModelLoader
  
  defaultLoadOptions = ->
    name: 'task'
    only: 1

  createLoader = (opts = {}) ->
    storageManager = StorageManager.get()
    storageManager.addCollection('tasks', Tasks)

    defaults = 
      storageManager: storageManager

    loader = new loaderClass(extend {}, defaults, opts)
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

    describe '#_getModel', ->
      it 'returns the constructor of the internalObject', ->
        loader.setup(opts)
        expect(loader._getModel()).toEqual Task

    describe '#_getModelsForAssociation', ->
      it 'returns the models from the internalObject for a given association', ->
        loader.setup(opts)
        user = buildAndCacheUser()
        loader.internalObject.set('assignee_ids', [user.id])

        expect(loader._getModelsForAssociation('assignees')).toEqual [user] # Association with a model in it
        expect(loader._getModelsForAssociation('parent')).toEqual [] # Association without any models
        expect(loader._getModelsForAssociation('adfasfa')).toEqual [] # Association that does not exist

    describe '#_createObjects', ->
      model = null

      context 'there is a matching model in the storageManager', ->
        it 'sets the internalObject to be the cached model', ->
          model = buildAndCacheTask(id: 1)
          loader.setup(opts)
          expect(loader.internalObject).toEqual model

      context 'there is not a matching model in the storageManager', ->
        it 'creates a new model and uses that as the internalObject', ->
          model = new Task()
          spyOn(loader.storageManager, 'createNewModel').and.returnValue model
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

    describe '#_updateObjects', ->
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
