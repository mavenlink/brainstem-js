StorageManager = require '../src/storage-manager'

# This spec file cannot be included with other specs because it requires a pristine
# StorageManager singleton instance. Instead, ensure this works by unpending it and
# focusing.

xdescribe 'Singleton#get with window.base.data', ->
  stubbedStorageManager = null

  beforeAll ->
    stubbedStorageManager = {
      addCollection: ->
      restore: ->
    }

    window.base = { data: stubbedStorageManager }

  it 'uses the window.base.data reference', ->
    expect(StorageManager.get()).toBe(stubbedStorageManager)
