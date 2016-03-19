AbstractLoader = require '../../src/loaders/abstract-loader'

describe 'Loaders AbstractLoader', ->
  loaderClass = AbstractLoader
  itShouldBehaveLike "AbstractLoaderSharedBehavior", loaderClass: loaderClass
