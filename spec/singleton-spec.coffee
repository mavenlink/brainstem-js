StorageManager = require '../src/storage-manager'


describe 'Singleton#get without window.base.data', ->
  it 'uses a cached references', ->
    cachedStorageManager = StorageManager.get()
    expect(StorageManager.get()).toBe(cachedStorageManager)
