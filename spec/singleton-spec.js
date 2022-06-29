/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const StorageManager = require('../src/storage-manager');

describe('Singleton#get without window.base.data', () =>
  it('uses a cached references', function() {
    const cachedStorageManager = StorageManager.get();
    return expect(StorageManager.get()).toBe(cachedStorageManager);
  }));
