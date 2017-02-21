# StorageManager = require '../src/storage-manager'
#
# # This spec file cannot be included with other specs because it requires a pristine
# # StorageManager singleton instance. Instead, ensure this works by commenting it in
# # and running it by itself
#
# describe 'Singleton#get with window.base.data', ->
#   stubbedStorageManager = null
#
#   beforeAll ->
#     stubbedStorageManager = {
#       addCollection: ->
#       restore: ->
#     }
#
#     window.base = { data: stubbedStorageManager }
#
#   fit 'uses the window.base.data reference', ->
#     expect(StorageManager.get()).toBe(stubbedStorageManager)
