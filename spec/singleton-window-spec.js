/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const StorageManager = require('../src/storage-manager');

// This spec file cannot be included with other specs because it requires a pristine
// StorageManager singleton instance. Instead, ensure this works by unpending it and
// focusing.

xdescribe('Singleton#get with window.base.data', function() {
  let stubbedStorageManager = null;

  beforeAll(function() {
    stubbedStorageManager = {
      addCollection() {},
      restore() {}
    };

    return (window.base = { data: stubbedStorageManager });
  });

  return it('uses the window.base.data reference', () =>
    expect(StorageManager.get()).toBe(stubbedStorageManager));
});
