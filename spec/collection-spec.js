/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * DS205: Consider reworking code to avoid use of IIFEs
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const $ = require('jquery');
const _ = require('underscore');
const Backbone = require('backbone');
Backbone.$ = $; // TODO remove after upgrading to backbone 1.2+

const Utils = require('../src/utils');
const Model = require('../src/model');
const Collection = require('../src/collection');
const StorageManager = require('../src/storage-manager');

const Post = require('./helpers/models/post');
const Posts = require('./helpers/models/posts');
const Tasks = require('./helpers/models/tasks');

describe('Collection', function() {
  let storageManager, updateArray;
  let collection = (storageManager = updateArray = null);

  beforeEach(function() {
    storageManager = StorageManager.get();
    collection = new Collection([
      { id: 2, title: '1' },
      { id: 3, title: '2' },
      { title: '3' }
    ]);
    return (updateArray = [
      { id: 2, title: '1 new' },
      { id: 4, title: 'this is new' }
    ]);
  });

  describe('#constructor', function() {
    let pickFetchOptionsSpy;
    let setLoadedSpy = (pickFetchOptionsSpy = null);

    beforeEach(function() {
      pickFetchOptionsSpy = spyOn(
        Collection,
        'pickFetchOptions'
      ).and.callThrough();
      setLoadedSpy = spyOn(Collection.prototype, 'setLoaded');

      return (collection = new Collection(null, { name: 'posts' }));
    });

    it('sets `setLoaded` to false', () =>
      expect(setLoadedSpy).toHaveBeenCalled());

    context('when options are passed', function() {
      it('calls `pickFetchOptions` with options', () =>
        expect(pickFetchOptionsSpy).toHaveBeenCalledWith({ name: 'posts' }));

      return it('sets `firstFetchOptions`', function() {
        expect(collection.firstFetchOptions).toBeDefined();
        return expect(collection.firstFetchOptions.name).toEqual('posts');
      });
    });

    return context('no options are passed', () =>
      it('does not throw an error trying to pick options', () =>
        expect(() => new Collection()).not.toThrow())
    );
  });

  describe('#pickFetchOptions', function() {
    let sampleOptions;
    let keys = (sampleOptions = null);
    beforeEach(function() {
      sampleOptions = {
        name: 1,
        filters: 1,
        page: 1,
        perPage: 1,
        limit: 1,
        offset: 1,
        order: 1,
        search: 1,
        cacheKey: 1,
        bogus: 1,
        stuff: 1
      };
      return (keys = _.keys(Collection.pickFetchOptions(sampleOptions)));
    });

    it('returns an array with picked option keys', () =>
      (() => {
        const result = [];
        for (let key in sampleOptions) {
          if (key === 'bogus' || 'stuff') {
            continue;
          }
          result.push(expect(keys).toContain(key));
        }
        return result;
      })());

    return it('does not contain non whitelisted options', function() {
      expect(keys).not.toContain('bogus');
      return expect(keys).not.toContain('stuff');
    });
  });

  describe('#getServerCount', function() {
    context('lastFetchOptions are set', () =>
      it('returns the cached count', function() {
        const posts = [1, 2, 3, 4, 5].map(i =>
          buildPost({ message: 'old post', reply_ids: [] })
        );
        respondWith(
          server,
          '/api/posts?include=replies&parents_only=true&per_page=5&page=1',
          { resultsFrom: 'posts', data: { count: posts.length, posts } }
        );
        const loader = storageManager.loadObject('posts', {
          include: ['replies'],
          filters: { parents_only: 'true' },
          perPage: 5
        });

        expect(loader.getCollection().getServerCount()).toBeUndefined();
        server.respond();
        expect(loader.getCacheObject().count).toEqual(posts.length);
        return expect(loader.getCollection().getServerCount()).toEqual(
          posts.length
        );
      })
    );

    return context('lastFetchOptions are not set', () =>
      it('returns undefined', function() {
        collection = storageManager.createNewCollection('tasks');
        return expect(collection.getServerCount()).toBeUndefined();
      })
    );
  });

  describe('#getWithAssocation', () =>
    it('defaults to the regular get', function() {
      spyOn(collection, 'get');
      collection.getWithAssocation(10);
      return expect(collection.get).toHaveBeenCalledWith(10);
    }));

  describe('#fetch', function() {
    context('collection has no model', function() {
      beforeEach(() => (collection.model = undefined));

      return it('throws a "BrainstemError"', () =>
        expect(() => collection.fetch()).toThrow());
    });

    context('collection has model without a brainstemKey defined', function() {
      beforeEach(() => (collection.model = Backbone.Model));

      return it('throws a "BrainstemError"', () =>
        expect(() => collection.fetch()).toThrow());
    });

    context('the collection has brainstemKey defined', function() {
      beforeEach(() => (collection.model = Post));

      it('does not throw', () =>
        expect(() => collection.fetch()).not.toThrow());

      it('assigns its BrainstemKey to the options object', function() {
        const loadObjectSpy = spyOn(
          storageManager,
          'loadObject'
        ).and.returnValue(new $.Deferred());

        collection.fetch();

        return expect(loadObjectSpy.calls.mostRecent().args[1].name).toEqual(
          'posts'
        );
      });

      return it('triggers "request"', function() {
        const options = { returnValues: {} };

        spyOn(collection, 'trigger');
        collection.fetch(options);

        return expect(collection.trigger).toHaveBeenCalledWith(
          'request',
          collection,
          options.returnValues.jqXhr,
          jasmine.any(Object)
        );
      });
    });

    context('options has a name property', () =>
      it('uses options name property over the collections brainstemKey', function() {
        const loadObjectSpy = spyOn(
          storageManager,
          'loadObject'
        ).and.returnValue(new $.Deferred());

        collection.brainstemKey = 'attachments';
        collection.fetch({ name: 'posts' });

        return expect(loadObjectSpy.calls.mostRecent().args[1].name).toEqual(
          'posts'
        );
      })
    );

    it('assigns firstFetchOptions if they do not exist', function() {
      collection.firstFetchOptions = null;
      collection.fetch({ name: 'posts' });

      expect(collection.firstFetchOptions).toBeDefined();
      return expect(collection.firstFetchOptions.name).toEqual('posts');
    });

    it('wraps options-passed error function', function() {
      const wrapSpy = spyOn(Utils, 'wrapError');
      const options = {
        error() {
          return 'hi!';
        }
      };
      collection.model = Post;
      collection.fetch(options);
      expect(wrapSpy).toHaveBeenCalledWith(collection, jasmine.any(Object));
      return expect(wrapSpy.calls.mostRecent().args[1].error).toBe(
        options.error
      );
    });

    describe('loading brainstem object', function() {
      let options;
      let loadObjectSpy = (options = null);

      beforeEach(function() {
        const promise = new $.Deferred();

        loadObjectSpy = spyOn(storageManager, 'loadObject').and.returnValue(
          promise
        );

        collection.firstFetchOptions = {};
        return (collection.model = Post);
      });

      it('calls `loadObject` with collection name', function() {
        collection.fetch();
        return expect(loadObjectSpy).toHaveBeenCalledWith(
          'posts',
          jasmine.any(Object)
        );
      });

      it('mixes passed options into options passed to `loadObject`', function() {
        options = { parse: false, url: 'sick url', reset: true };

        collection.fetch(options);

        return (() => {
          const result = [];
          for (let key in options) {
            expect(_.keys(loadObjectSpy.calls.mostRecent().args[1])).toContain(
              key
            );
            result.push(
              expect(loadObjectSpy.calls.mostRecent().args[1][key]).toEqual(
                options[key]
              )
            );
          }
          return result;
        })();
      });

      return it('does not modify `firstFetchOptions`', function() {
        const firstFetchOptions = _.clone(collection.firstFetchOptions);

        collection.fetch({ bla: 'bla' });

        return expect(collection.firstFetchOptions).toEqual(firstFetchOptions);
      });
    });

    describe('brainstem request and response', function() {
      let expectation, posts;
      let options = (expectation = posts = null);

      beforeEach(function() {
        posts = [buildPost(), buildPost(), buildPost()];
        collection.model = Post;
        options = {
          offset: 0,
          limit: 5,
          response(res) {
            return (res.results = posts);
          }
        };

        storageManager.enableExpectations();
        return (expectation = storageManager.stub('posts', options));
      });

      afterEach(() => storageManager.disableExpectations());

      it('updates `lastFetchOptions` on the collection instance', function() {
        expect(collection.lastFetchOptions).toBeNull();

        collection.fetch(options);
        expectation.respond();

        const { lastFetchOptions } = collection;
        expect(lastFetchOptions).toEqual(jasmine.any(Object));
        expect(lastFetchOptions.offset).toEqual(0);
        return expect(lastFetchOptions.limit).toEqual(5);
      });

      it('updates `lastFetchOptions` BEFORE invoking (set/reset/add) method on collection', function() {
        expect(collection.lastFetchOptions).toBeNull();

        const fakeReset = function() {
          const { lastFetchOptions } = collection;
          expect(lastFetchOptions).toEqual(jasmine.any(Object));
          expect(lastFetchOptions.offset).toEqual(0);
          return expect(lastFetchOptions.limit).toEqual(5);
        };

        spyOn(collection, 'set').and.callFake(fakeReset);

        collection.fetch(options);
        return expectation.respond();
      });

      it('triggers sync', function() {
        spyOn(collection, 'trigger');

        collection.fetch(options);
        expectation.respond();

        return expect(collection.trigger).toHaveBeenCalledWith(
          'sync',
          collection,
          jasmine.any(Array),
          jasmine.any(Object)
        );
      });

      describe('Collection#update silent option', function() {
        beforeEach(() => spyOn(Collection.prototype, 'update'));

        it('is true when silent is true', function() {
          collection.fetch(_.extend(options, { silent: true }));
          expectation.respond();
          return expect(
            Collection.prototype.update
          ).toHaveBeenCalledWith(jasmine.any(Array), { silent: true });
        });

        return it('is false when silent is false', function() {
          collection.fetch(_.extend(options, { silent: false }));
          expectation.respond();
          return expect(
            Collection.prototype.update
          ).toHaveBeenCalledWith(jasmine.any(Array), { silent: false });
        });
      });

      context('reset option is set to false', function() {
        beforeEach(function() {
          options.reset = false;
          spyOn(collection, 'set');
          return collection.fetch(options);
        });

        it('sets the server response on the collection', function() {
          expectation.respond();

          const objects = collection.set.calls.mostRecent().args[0];
          expect(_.pluck(objects, 'id')).toEqual(_.pluck(posts, 'id'));
          return Array.from(objects).map(object =>
            expect(object).toEqual(jasmine.any(Post))
          );
        });

        return context('add option is set to true', function() {
          beforeEach(function() {
            options.add = true;
            spyOn(collection, 'add');
            return collection.fetch(options);
          });

          return it('adds the server response to the collection', function() {
            expectation.respond();

            const objects = collection.add.calls.mostRecent().args[0];
            expect(_.pluck(objects, 'id')).toEqual(_.pluck(posts, 'id'));
            return Array.from(objects).map(object =>
              expect(object).toEqual(jasmine.any(Post))
            );
          });
        });
      });

      context('reset option is set to true', function() {
        beforeEach(function() {
          options.reset = true;
          collection.fetch(options);
          return spyOn(collection, 'reset');
        });

        return it('it resets the collection with the server response', function() {
          expectation.respond();

          const objects = collection.reset.calls.mostRecent().args[0];
          expect(_.pluck(objects, 'id')).toEqual(_.pluck(posts, 'id'));
          return Array.from(objects).map(object =>
            expect(object).toEqual(jasmine.any(Post))
          );
        });
      });

      return context(
        'collection is fetched again with different options',
        function() {
          let firstOptions, secondOptions;
          let secondPosts = (secondOptions = firstOptions = null);

          beforeEach(function() {
            secondPosts = [buildPost(), buildPost()];
            secondOptions = {
              offset: 5,
              limit: 3,
              response(res) {
                return (res.results = secondPosts);
              }
            };
            const secondExpectation = storageManager.stub(
              'posts',
              secondOptions
            );

            spyOn(collection, 'set');

            collection.fetch(options);
            expectation.respond();

            firstOptions = collection.lastFetchOptions;

            collection.fetch(secondOptions);
            return secondExpectation.respond();
          });

          it('returns only the second set of results', function() {
            const objects = collection.set.calls.mostRecent().args[0];
            expect(_.pluck(objects, 'id')).toEqual(_.pluck(secondPosts, 'id'));
            return Array.from(objects).map(object =>
              expect(object).toEqual(jasmine.any(Post))
            );
          });

          return it('updates `lastFetchOptions` on the collection instance', function() {
            expect(collection.lastFetchOptions).not.toBe(firstOptions);

            const { lastFetchOptions } = collection;
            expect(lastFetchOptions).toEqual(jasmine.any(Object));
            expect(lastFetchOptions.offset).toEqual(5);
            return expect(lastFetchOptions.limit).toEqual(3);
          });
        }
      );
    });

    return describe('integration', function() {
      let posts1, posts2;
      let options = (collection = posts1 = posts2 = null);

      beforeEach(function() {
        posts1 = [
          buildPost(),
          buildPost(),
          buildPost(),
          buildPost(),
          buildPost()
        ];
        posts2 = [buildPost(), buildPost()];

        options = { page: 1, perPage: 5 };
        return (collection = new Posts(null, options));
      });

      it('returns a promise with jqXhr methods', function() {
        respondWith(server, '/api/posts?per_page=5&page=1', {
          resultsFrom: 'posts',
          data: { posts: posts1 }
        });

        const jqXhr = $.ajax();
        const promise = collection.fetch();

        return (() => {
          const result = [];
          for (let key in jqXhr) {
            const value = jqXhr[key];
            const object = {};
            object[key] = jasmine.any(value.constructor);
            result.push(
              expect(promise).toEqual(jasmine.objectContaining(object))
            );
          }
          return result;
        })();
      });

      it('returns a promise without jQuery Deferred methods', function() {
        respondWith(server, '/api/posts?per_page=5&page=1', {
          resultsFrom: 'posts',
          data: { posts: posts1 }
        });

        const promise = collection.fetch();
        const methods = _.keys(promise);

        return ['reject', 'resolve', 'rejectWith', 'resolveWith'].map(method =>
          expect(methods).not.toContain(method)
        );
      });

      it('passes collection instance to chained done method', function() {
        const onDoneSpy = jasmine.createSpy('onDone');

        respondWith(server, '/api/posts?per_page=5&page=1', {
          resultsFrom: 'posts',
          data: { posts: posts1 }
        });

        collection.fetch().done(onDoneSpy);
        server.respond();

        const response = onDoneSpy.calls.mostRecent().args[0];
        return expect(response.toJSON()).toEqual(collection.toJSON());
      });

      it('updates collection with response', function() {
        respondWith(server, '/api/posts?per_page=5&page=1', {
          resultsFrom: 'posts',
          data: { posts: posts1 }
        });

        collection.fetch();
        server.respond();

        return expect(collection.pluck('id')).toEqual(_(posts1).pluck('id'));
      });

      it('responds to requests with custom params', function() {
        const paramsOnDoneSpy = jasmine.createSpy('paramsOnDoneSpy');

        respondWith(
          server,
          '/api/posts?my_custom_param=theparam&per_page=5&page=1',
          { resultsFrom: 'posts', data: { posts: posts2 } }
        );
        collection
          .fetch({ params: { my_custom_param: 'theparam' } })
          .done(paramsOnDoneSpy);

        server.respond();

        return expect(paramsOnDoneSpy).toHaveBeenCalled();
      });

      return describe('subsequent fetches', function() {
        beforeEach(function() {
          respondWith(server, '/api/posts?per_page=5&page=1', {
            resultsFrom: 'posts',
            data: { posts: posts1 }
          });

          collection.fetch();
          return server.respond();
        });

        it('returns data from storage manager cache', function() {
          collection.fetch();

          expect(collection.pluck('id')).toEqual(_.pluck(posts1, 'id'));
          return expect(collection.pluck('id')).not.toEqual(
            _.pluck(posts2, 'id')
          );
        });

        return context('different options are provided', function() {
          beforeEach(function() {
            respondWith(server, '/api/posts?per_page=5&page=2', {
              resultsFrom: 'posts',
              data: { posts: posts2 }
            });
            collection.fetch({ page: 2 });
            return server.respond();
          });

          return it('updates collection with new data', function() {
            expect(collection.pluck('id')).not.toEqual(_.pluck(posts1, 'id'));
            return expect(collection.pluck('id')).toEqual(
              _.pluck(posts2, 'id')
            );
          });
        });
      });
    });
  });

  describe('#refresh', function() {
    beforeEach(function() {
      collection.lastFetchOptions = {};
      spyOn(collection, 'fetch');
      return collection.refresh();
    });

    return it('should call fetch with the correct options', () =>
      expect(collection.fetch).toHaveBeenCalledWith({ cache: false }));
  });

  describe('#update', function() {
    it('works with an array', function() {
      collection.update(updateArray);
      expect(collection.get(2).get('title')).toEqual('1 new');
      expect(collection.get(3).get('title')).toEqual('2');
      return expect(collection.get(4).get('title')).toEqual('this is new');
    });

    it('works with a collection', function() {
      const newCollection = new Collection(updateArray);
      collection.update(newCollection);
      expect(collection.get(2).get('title')).toEqual('1 new');
      expect(collection.get(3).get('title')).toEqual('2');
      return expect(collection.get(4).get('title')).toEqual('this is new');
    });

    it('should update copies of the model that are already in the collection', function() {
      const model = collection.get(2);
      const spy = jasmine.createSpy();
      model.bind('change:title', spy);
      collection.update(updateArray);
      expect(model.get('title')).toEqual('1 new');
      return expect(spy).toHaveBeenCalled();
    });

    context('when the silent option is true', () =>
      it('should call Backbone.Collection#add with { silent: true }', function() {
        spyOn(collection, 'add');
        collection.update(updateArray, { silent: true });
        return expect(collection.add).toHaveBeenCalledWith(jasmine.anything(), {
          silent: true
        });
      })
    );

    context('when the silent option is false', () =>
      it('should call Backbone.Collection#add with { silent: false }', function() {
        spyOn(collection, 'add');
        collection.update(updateArray, { silent: false });
        return expect(collection.add).toHaveBeenCalledWith(jasmine.anything(), {
          silent: false
        });
      })
    );

    return context('when the silent option is undefined', () =>
      it('should call Backbone.Collection#add with no options', function() {
        spyOn(collection, 'add');
        collection.update(updateArray);
        return expect(collection.add).toHaveBeenCalledWith(
          jasmine.anything(),
          {}
        );
      })
    );
  });

  describe('#reload', () =>
    it('reloads the collection with the original params', function() {
      respondWith(
        server,
        '/api/posts?include=replies&parents_only=true&per_page=5&page=1',
        {
          resultsFrom: 'posts',
          data: { posts: [buildPost({ message: 'old post', reply_ids: [] })] }
        }
      );
      collection = storageManager.loadCollection('posts', {
        include: ['replies'],
        filters: { parents_only: 'true' },
        perPage: 5
      });
      server.respond();
      expect(collection.lastFetchOptions.page).toEqual(1);
      expect(collection.lastFetchOptions.perPage).toEqual(5);
      expect(collection.lastFetchOptions.include).toEqual(['replies']);
      server.responses = [];
      respondWith(
        server,
        '/api/posts?include=replies&parents_only=true&per_page=5&page=1',
        {
          resultsFrom: 'posts',
          data: { posts: [buildPost({ message: 'new post', reply_ids: [] })] }
        }
      );
      expect(collection.models[0].get('message')).toEqual('old post');
      const resetCounter = jasmine.createSpy('resetCounter');
      const loadedCounter = jasmine.createSpy('loadedCounter');
      const callback = jasmine.createSpy('callback spy');
      collection.bind('reset', resetCounter);
      collection.bind('loaded', loadedCounter);

      collection.reload({ success: callback });

      expect(collection.loaded).toBe(false);
      expect(collection.length).toEqual(0);
      server.respond();
      expect(collection.length).toEqual(1);
      expect(collection.models[0].get('message')).toEqual('new post');
      expect(resetCounter.calls.count()).toEqual(1);
      expect(loadedCounter.calls.count()).toEqual(1);
      return expect(callback).toHaveBeenCalledWith(collection);
    }));

  describe('#loadNextPage', function() {
    it('loads the next page of data for a collection that has previously been loaded in the storage manager, returns the collection and whether it thinks there is another page or not', function() {
      respondWith(server, '/api/time_entries?per_page=2&page=1', {
        resultsFrom: 'time_entries',
        data: { time_entries: [buildTimeEntry(), buildTimeEntry()], count: 5 }
      });
      respondWith(server, '/api/time_entries?per_page=2&page=2', {
        resultsFrom: 'time_entries',
        data: { time_entries: [buildTimeEntry(), buildTimeEntry()], count: 5 }
      });
      respondWith(server, '/api/time_entries?per_page=2&page=3', {
        resultsFrom: 'time_entries',
        data: { time_entries: [buildTimeEntry()], count: 5 }
      });
      collection = storageManager.loadCollection('time_entries', {
        perPage: 2
      });
      expect(collection.length).toEqual(0);
      server.respond();
      expect(collection.length).toEqual(2);
      expect(collection.lastFetchOptions.page).toEqual(1);

      let spy = jasmine.createSpy();
      collection.loadNextPage({ success: spy });
      server.respond();
      expect(spy).toHaveBeenCalledWith(collection, true);
      expect(collection.lastFetchOptions.page).toEqual(2);
      expect(collection.length).toEqual(4);

      spy = jasmine.createSpy();
      collection.loadNextPage({ success: spy });
      expect(collection.length).toEqual(4);
      server.respond();
      expect(spy).toHaveBeenCalledWith(collection, false);
      expect(collection.lastFetchOptions.page).toEqual(3);
      return expect(collection.length).toEqual(5);
    });

    return it('fetches based on the last limit and offset if they were the pagination options used', function() {
      respondWith(server, '/api/time_entries?limit=2&offset=0', {
        resultsFrom: 'time_entries',
        data: { time_entries: [buildTimeEntry(), buildTimeEntry()], count: 5 }
      });
      respondWith(server, '/api/time_entries?limit=2&offset=2', {
        resultsFrom: 'time_entries',
        data: { time_entries: [buildTimeEntry(), buildTimeEntry()], count: 5 }
      });
      respondWith(server, '/api/time_entries?limit=2&offset=4', {
        resultsFrom: 'time_entries',
        data: { time_entries: [buildTimeEntry()], count: 5 }
      });
      collection = storageManager.loadCollection('time_entries', {
        limit: 2,
        offset: 0
      });
      expect(collection.length).toEqual(0);
      server.respond();
      expect(collection.length).toEqual(2);
      expect(collection.lastFetchOptions.offset).toEqual(0);

      let spy = jasmine.createSpy();
      collection.loadNextPage({ success: spy });
      server.respond();
      expect(spy).toHaveBeenCalledWith(collection, true);
      expect(collection.lastFetchOptions.offset).toEqual(2);
      expect(collection.length).toEqual(4);

      spy = jasmine.createSpy();
      collection.loadNextPage({ success: spy });
      expect(collection.length).toEqual(4);
      server.respond();
      expect(spy).toHaveBeenCalledWith(collection, false);
      expect(collection.lastFetchOptions.offset).toEqual(4);
      return expect(collection.length).toEqual(5);
    });
  });

  describe('#getPageIndex', function() {
    collection = null;

    beforeEach(() => (collection = new Tasks()));

    context(
      'lastFetchOptions is not defined (collection has not been fetched)',
      function() {
        beforeEach(() => (collection.lastFetchOptions = undefined));

        return it('returns 1', () =>
          expect(collection.getPageIndex()).toEqual(1));
      }
    );

    return context(
      'lastFetchOptions is defined (collection has been fetched)',
      function() {
        context('limit and offset are defined', function() {
          beforeEach(function() {
            collection.lastFetchOptions = { limit: 10, offset: 50 };
            return spyOn(collection, 'getServerCount').and.returnValue(100);
          });

          return it('returns correct page index', () =>
            expect(collection.getPageIndex()).toEqual(6));
        });

        return context('perPage and page are defined', function() {
          beforeEach(function() {
            collection.lastFetchOptions = { perPage: 10, page: 6 };
            return spyOn(collection, 'getServerCount').and.returnValue(100);
          });

          return it('returns correct page index', () =>
            expect(collection.getPageIndex()).toEqual(6));
        });
      }
    );
  });

  describe('#getNextPage', function() {
    beforeEach(function() {
      collection = new Tasks();
      collection.lastFetchOptions = {};

      spyOn(collection, 'fetch');
      return spyOn(collection, 'getServerCount').and.returnValue(100);
    });

    context(
      'when limit and offset are definded in lastFetchOptions',
      function() {
        context('fetching from middle of collection', function() {
          beforeEach(function() {
            collection.lastFetchOptions = { offset: 20, limit: 10 };
            return collection.getNextPage();
          });

          return it('calls fetch with correct limit and offset options for next page', function() {
            const options = collection.fetch.calls.mostRecent().args[0];
            expect(options.limit).toEqual(10);
            return expect(options.offset).toEqual(30);
          });
        });

        return context('fetching from end of collection', function() {
          beforeEach(function() {
            collection.lastFetchOptions = { offset: 80, limit: 20 };
            return collection.getNextPage();
          });

          return it('calls fetch with correct limit and offset options for next page', function() {
            const options = collection.fetch.calls.mostRecent().args[0];
            expect(options.limit).toEqual(20);
            return expect(options.offset).toEqual(80);
          });
        });
      }
    );

    return context(
      'when page and perPage are defined in lastFetchOptions',
      function() {
        context('fetching from middle of collection', function() {
          beforeEach(function() {
            collection.lastFetchOptions = { perPage: 20, page: 2 };
            return collection.getNextPage();
          });

          return it('calls fetch with the correct page and perPage options for next page', function() {
            const options = collection.fetch.calls.mostRecent().args[0];
            expect(options.perPage).toEqual(20);
            return expect(options.page).toEqual(3);
          });
        });

        return context('fetching from end of collection', function() {
          beforeEach(function() {
            collection.lastFetchOptions = { perPage: 20, page: 5 };
            return collection.getNextPage();
          });

          return it('calls fetch with the correct page and perPage options for next page', function() {
            const options = collection.fetch.calls.mostRecent().args[0];
            expect(options.perPage).toEqual(20);
            return expect(options.page).toEqual(5);
          });
        });
      }
    );
  });

  describe('#getPreviousPage', function() {
    beforeEach(function() {
      collection = new Tasks();
      collection.lastFetchOptions = {};

      spyOn(collection, 'fetch');
      return spyOn(collection, 'getServerCount').and.returnValue(100);
    });

    context(
      'when limit and offset are definded in lastFetchOptions',
      function() {
        context('fetching from middle of collection', function() {
          beforeEach(function() {
            collection.lastFetchOptions = { offset: 20, limit: 10 };
            return collection.getPreviousPage();
          });

          return it('calls fetch with correct limit and offset options for next page', function() {
            const options = collection.fetch.calls.mostRecent().args[0];
            expect(options.limit).toEqual(10);
            return expect(options.offset).toEqual(10);
          });
        });

        return context('fetching from end of collection', function() {
          beforeEach(function() {
            collection.lastFetchOptions = { offset: 0, limit: 20 };
            return collection.getPreviousPage();
          });

          return it('calls fetch with correct limit and offset options for next page', function() {
            const options = collection.fetch.calls.mostRecent().args[0];
            expect(options.limit).toEqual(20);
            return expect(options.offset).toEqual(0);
          });
        });
      }
    );

    return context(
      'when page and perPage are defined in lastFetchOptions',
      function() {
        context('fetching from middle of collection', function() {
          beforeEach(function() {
            collection.lastFetchOptions = { perPage: 20, page: 2 };
            return collection.getPreviousPage();
          });

          return it('calls fetch with the correct page and perPage options for next page', function() {
            const options = collection.fetch.calls.mostRecent().args[0];
            expect(options.perPage).toEqual(20);
            return expect(options.page).toEqual(1);
          });
        });

        return context('fetching from end of collection', function() {
          beforeEach(function() {
            collection.lastFetchOptions = { perPage: 20, page: 1 };
            return collection.getPreviousPage();
          });

          return it('calls fetch with the correct page and perPage options for next page', function() {
            const options = collection.fetch.calls.mostRecent().args[0];
            expect(options.perPage).toEqual(20);
            return expect(options.page).toEqual(1);
          });
        });
      }
    );
  });

  describe('#getFirstPage', function() {
    collection = null;

    beforeEach(function() {
      collection = new Tasks();
      collection.lastFetchOptions = {};

      spyOn(collection, 'fetch');
      return spyOn(collection, 'getServerCount').and.returnValue(50);
    });

    it('calls _canPaginate', function() {
      spyOn(collection, '_canPaginate');
      spyOn(collection, '_maxPage');

      collection.getFirstPage();

      return expect(collection._canPaginate).toHaveBeenCalled();
    });

    context('offset is not defined in lastFetchOptions', function() {
      beforeEach(function() {
        collection.lastFetchOptions = { page: 3, perPage: 5 };
        return collection.getFirstPage();
      });

      it('calls fetch', () => expect(collection.fetch).toHaveBeenCalled());

      return it('calls fetch with correct "perPage" options', () =>
        expect(collection.fetch.calls.mostRecent().args[0].page).toEqual(1));
    });

    return context('offset is defined in lastFetchOptions', function() {
      beforeEach(function() {
        collection.lastFetchOptions = { offset: 20, limit: 10 };
        return collection.getFirstPage();
      });

      it('calls fetch', () => expect(collection.fetch).toHaveBeenCalled());

      return it('calls fetch with correct "perPage" options', () =>
        expect(collection.fetch.calls.mostRecent().args[0].offset).toEqual(0));
    });
  });

  describe('#getLastPage', function() {
    collection = null;

    beforeEach(function() {
      collection = new Tasks();
      collection.lastFetchOptions = {};
      return spyOn(collection, 'fetch');
    });

    it('calls _canPaginate', function() {
      spyOn(collection, '_canPaginate');
      spyOn(collection, '_maxPage');

      collection.getLastPage();

      return expect(collection._canPaginate).toHaveBeenCalled();
    });

    context(
      'both offset and limit are defined in lastFetchOptions',
      function() {
        beforeEach(
          () => (collection.lastFetchOptions = { offset: 15, limit: 5 })
        );

        context('last page is a partial page', function() {
          beforeEach(() =>
            spyOn(collection, 'getServerCount').and.returnValue(33)
          );

          return it('fetches with offset and limit defined correctly', function() {
            collection.getLastPage();

            expect(collection.fetch).toHaveBeenCalled();
            const fetchOptions = collection.fetch.calls.mostRecent().args[0];
            expect(fetchOptions.offset).toEqual(30);
            return expect(fetchOptions.limit).toEqual(5);
          });
        });

        return context('last page is a complete page', function() {
          beforeEach(() =>
            spyOn(collection, 'getServerCount').and.returnValue(35)
          );

          return it('fetches with offset and limit defined correctly', function() {
            collection.getLastPage();

            expect(collection.fetch).toHaveBeenCalled();
            const fetchOptions = collection.fetch.calls.mostRecent().args[0];
            expect(fetchOptions.offset).toEqual(30);
            return expect(fetchOptions.limit).toEqual(5);
          });
        });
      }
    );

    return context(
      'offset is not defined, both perPage and page are defined in lastFetchOptions',
      function() {
        beforeEach(function() {
          collection.lastFetchOptions = { perPage: 10, page: 2 };
          return spyOn(collection, 'getServerCount').and.returnValue(53);
        });

        return it('fetches with perPage and page defined', function() {
          collection.getLastPage();

          expect(collection.fetch).toHaveBeenCalled();
          const fetchOptions = collection.fetch.calls.mostRecent().args[0];
          expect(fetchOptions.page).toEqual(6);
          return expect(fetchOptions.perPage).toEqual(10);
        });
      }
    );
  });

  describe('#getPage', function() {
    collection = null;

    beforeEach(function() {
      collection = new Tasks();
      collection.lastFetchOptions = {};
      return spyOn(collection, 'fetch');
    });

    it('calls _canPaginate with throwError = true', function() {
      spyOn(collection, '_canPaginate');
      spyOn(collection, '_maxPage');

      collection.getPage();

      return expect(collection._canPaginate).toHaveBeenCalledWith(true);
    });

    context('perPage and page are defined in lastFetchOptions', function() {
      beforeEach(function() {
        collection.lastFetchOptions = { perPage: 20, page: 5 };
        return spyOn(collection, 'getServerCount').and.returnValue(400);
      });

      context('there is a page to fetch', () =>
        it('fetches the page', function() {
          collection.getPage(10);

          expect(collection.fetch).toHaveBeenCalled();
          const options = collection.fetch.calls.mostRecent().args[0];
          expect(options.page).toEqual(10);
          return expect(options.perPage).toEqual(20);
        })
      );

      return context('an index greater than the max page is specified', () =>
        it('gets called with max page index', function() {
          collection.getPage(21);
          const options = collection.fetch.calls.mostRecent().args[0];
          return expect(options.page).toEqual(20);
        })
      );
    });

    return context('collection has limit and offset defined', function() {
      beforeEach(function() {
        collection.lastFetchOptions = { limit: 20, offset: 20 };
        return spyOn(collection, 'getServerCount').and.returnValue(400);
      });

      context('when offset is zero', function() {
        beforeEach(() => (collection.lastFetchOptions.offset = 0));

        return it('still uses limit and offset to fetch', function() {
          collection.getPage(2);
          const options = collection.fetch.calls.mostRecent().args[0];
          return expect(options.offset).toEqual(20);
        });
      });

      context('there is a page to fetch', () =>
        it('fetches the page', function() {
          collection.getPage(10);

          expect(collection.fetch).toHaveBeenCalled();
          const options = collection.fetch.calls.mostRecent().args[0];
          expect(options.limit).toEqual(20);
          return expect(options.offset).toEqual(180);
        })
      );

      return context('an index greater than the max page is specified', () =>
        it('gets called with max page index', function() {
          collection.getPage(21);
          const options = collection.fetch.calls.mostRecent().args[0];
          return expect(options.offset).toEqual(380);
        })
      );
    });
  });

  describe('#hasNextPage', function() {
    collection = null;
    beforeEach(function() {
      collection = new Tasks();
      return spyOn(collection, 'getServerCount').and.returnValue(100);
    });

    context("collection's `lastFetchOptions` are undefined", function() {
      beforeEach(() => (collection.lastFetchOptions = undefined));

      it('returns false', () =>
        expect(collection.hasNextPage()).toEqual(false));

      return it("doesn't throw an error", () =>
        expect(() => collection.hasNextPage()).not.toThrow());
    });

    context('offset is defined', function() {
      context('at the end of a collection', function() {
        beforeEach(
          () => (collection.lastFetchOptions = { limit: 20, offset: 80 })
        );

        return it('returns false', () =>
          expect(collection.hasNextPage()).toEqual(false));
      });

      return context('in the middle of a collection', function() {
        beforeEach(
          () => (collection.lastFetchOptions = { limit: 20, offset: 40 })
        );

        return it('returns true', () =>
          expect(collection.hasNextPage()).toEqual(true));
      });
    });

    return context('page is defined', function() {
      context('at the end of a collection', function() {
        beforeEach(
          () => (collection.lastFetchOptions = { page: 5, perPage: 20 })
        );

        return it('returns false', () =>
          expect(collection.hasNextPage()).toEqual(false));
      });

      return context('in the middle of a collection', function() {
        beforeEach(
          () => (collection.lastFetchOptions = { page: 3, perPage: 20 })
        );

        return it('returns true', () =>
          expect(collection.hasNextPage()).toEqual(true));
      });
    });
  });

  describe('#hasPreviousPage', function() {
    collection = null;
    beforeEach(function() {
      collection = new Tasks();
      return spyOn(collection, 'getServerCount').and.returnValue(100);
    });

    context("collection's `lastFetchOptions` are undefined", function() {
      beforeEach(() => (collection.lastFetchOptions = undefined));

      it('returns false', () =>
        expect(collection.hasNextPage()).toEqual(false));

      return it("doesn't throw an error", () =>
        expect(() => collection.hasNextPage()).not.toThrow());
    });

    context('offset is defined', function() {
      context('at the front of a collection', function() {
        beforeEach(
          () => (collection.lastFetchOptions = { limit: 20, offset: 0 })
        );

        return it('returns false', () =>
          expect(collection.hasPreviousPage()).toEqual(false));
      });

      return context('in the middle of a collection', function() {
        beforeEach(
          () => (collection.lastFetchOptions = { limit: 20, offset: 40 })
        );

        return it('returns true', () =>
          expect(collection.hasPreviousPage()).toEqual(true));
      });
    });

    return context('page is defined', function() {
      context('at the front of a collection', function() {
        beforeEach(
          () => (collection.lastFetchOptions = { page: 0, perPage: 20 })
        );

        return it('returns false', () =>
          expect(collection.hasPreviousPage()).toEqual(false));
      });

      return context('in the middle of a collection', function() {
        beforeEach(
          () => (collection.lastFetchOptions = { page: 3, perPage: 20 })
        );

        return it('returns true', () =>
          expect(collection.hasPreviousPage()).toEqual(true));
      });
    });
  });

  describe('#invalidateCache', () =>
    it('invalidates the cache object', function() {
      const posts = [1, 2, 3, 4, 5].map(i =>
        buildPost({ message: 'old post', reply_ids: [] })
      );
      respondWith(
        server,
        '/api/posts?include=replies&parents_only=true&per_page=5&page=1',
        { resultsFrom: 'posts', data: { count: posts.length, posts } }
      );
      const loader = storageManager.loadObject('posts', {
        include: ['replies'],
        filters: { parents_only: 'true' },
        perPage: 5
      });

      expect(loader.getCacheObject()).toBeUndefined();
      server.respond();

      expect(loader.getCacheObject().valid).toEqual(true);
      loader.getCollection().invalidateCache();
      return expect(loader.getCacheObject().valid).toEqual(false);
    }));

  describe('#toServerJSON', function() {
    beforeEach(() =>
      Array.from(collection.models).map(model =>
        spyOn(model, 'toServerJSON').and.callThrough()
      )
    );

    it('returns model contents serialized using model server json', () =>
      expect(_(collection.toServerJSON()).pluck('id')).toEqual(
        collection.pluck('id')
      ));

    return it('passes method to model method calls', function() {
      collection.toServerJSON('update');
      return Array.from(collection.models).map(model =>
        expect(model.toServerJSON).toHaveBeenCalledWith('update')
      );
    });
  });

  describe('#setLoaded', function() {
    it('should set the values of @loaded', function() {
      collection.setLoaded(true);
      expect(collection.loaded).toEqual(true);
      collection.setLoaded(false);
      return expect(collection.loaded).toEqual(false);
    });

    it('triggers "loaded" when becoming true', function() {
      const spy = jasmine.createSpy();
      collection.bind('loaded', spy);
      collection.setLoaded(false);
      expect(spy).not.toHaveBeenCalled();
      collection.setLoaded(true);
      return expect(spy).toHaveBeenCalled();
    });

    it('doesnt trigger loaded if trigger: false is provided', function() {
      const spy = jasmine.createSpy();
      collection.bind('loaded', spy);
      collection.setLoaded(true, { trigger: false });
      return expect(spy).not.toHaveBeenCalled();
    });

    return it('returns self', function() {
      const spy = jasmine.createSpy();
      collection.bind('loaded', spy);
      collection.setLoaded(true);
      return expect(spy).toHaveBeenCalledWith(collection);
    });
  });

  describe('ordering and filtering', function() {
    beforeEach(
      () =>
        (collection = new Collection([
          new Model({ id: 2, title: 'Alpha', updated_at: 2, cool: false }),
          new Model({ id: 3, title: 'Beta', updated_at: 10, cool: true }),
          new Model({ id: 4, title: 'Gamma', updated_at: 5, cool: false }),
          new Model({ id: 6, title: 'Gamma', updated_at: 5, cool: false }),
          new Model({ id: 5, title: 'Gamma', updated_at: 4, cool: true })
        ]))
    );

    return describe('@getComparatorWithIdFailover', () =>
      it('returns a comparator that works for numerical ordering of unix timestamps, failing over to id when theyre the same', function() {
        let newCollection = new Collection(collection.models, {
          comparator: Collection.getComparatorWithIdFailover('updated_at:desc')
        });
        newCollection.sort();
        expect(newCollection.pluck('id')).toEqual([3, 6, 4, 5, 2]);

        newCollection = new Collection(collection.models, {
          comparator: Collection.getComparatorWithIdFailover('updated_at:asc')
        });
        newCollection.sort();
        return expect(newCollection.pluck('id')).toEqual([2, 5, 4, 6, 3]);
      }));
  });

  describe('#_canPaginate', function() {
    beforeEach(function() {
      collection = new Tasks();
      return spyOn(Utils, 'throwError').and.callThrough();
    });

    context('lastFetchOptions is not defined', function() {
      beforeEach(() => (collection.lastFetchOptions = undefined));

      context('throwError is passed as false', () =>
        it('returns false', () => expect(collection._canPaginate()).toBe(false))
      );

      return context('throwError is passed as true', () =>
        it('throws an error', function() {
          expect(() => collection._canPaginate(true)).toThrow();
          return expect(Utils.throwError.calls.mostRecent().args[0]).toMatch(
            /collection must have been fetched once/
          );
        })
      );
    });

    return context('lastFetchOptions is defined', function() {
      beforeEach(() => (collection.lastFetchOptions = {}));

      context('collection has count', function() {
        beforeEach(() =>
          spyOn(collection, 'getServerCount').and.returnValue(10)
        );

        return context('neither limit nor perPage are defined', function() {
          beforeEach(
            () =>
              (collection.lastFetchOptions = {
                limit: undefined,
                perPage: undefined
              })
          );

          context('throwError is passed as false', () =>
            it('returns false', () =>
              expect(collection._canPaginate()).toBe(false))
          );

          return context('throwError is passed as true', () =>
            it('throws an error', function() {
              expect(() => collection._canPaginate(true)).toThrow();
              return expect(
                Utils.throwError.calls.mostRecent().args[0]
              ).toMatch(/perPage or limit must be defined/);
            })
          );
        });
      });

      context('collection does not have count', function() {
        beforeEach(() => (collection.lastFetchOptions.name = 'tasks'));

        context('throwError is passed as false', () =>
          it('returns false', () =>
            expect(collection._canPaginate()).toBe(false))
        );

        return context('throwError is passed as true', () =>
          it('throws an error', function() {
            expect(() => collection._canPaginate(true)).toThrow();
            return expect(Utils.throwError.calls.mostRecent().args[0]).toMatch(
              /collection must have a count/
            );
          })
        );
      });

      return context('name is not defined in lastFetchOptions', function() {
        beforeEach(() => delete collection.lastFetchOptions.name);

        context('throwError is passed as false', () =>
          it('still returns false', () =>
            expect(collection._canPaginate()).toBe(false))
        );

        return context('throwError is passed as true', () =>
          it('still throws the correct error', function() {
            expect(() => collection._canPaginate(true)).toThrow();
            return expect(Utils.throwError.calls.mostRecent().args[0]).toMatch(
              /collection must have a count/
            );
          })
        );
      });
    });
  });

  describe('#_maxOffset', function() {
    beforeEach(() => (collection = new Tasks()));

    context('limit is not defined in lastFetchOptions', function() {
      beforeEach(() => (collection.lastFetchOptions = { limit: undefined }));

      return it('throws if limit is not defined', () =>
        expect(() => collection._maxOffset()).toThrow());
    });

    return context('limit is defined', function() {
      beforeEach(function() {
        collection.lastFetchOptions = { limit: 20 };
        return spyOn(collection, 'getServerCount').and.returnValue(100);
      });

      return it('returns the maximum possible offset', () =>
        expect(collection._maxOffset()).toEqual(
          collection.getServerCount() - collection.lastFetchOptions.limit
        ));
    });
  });

  return describe('#_maxPage', function() {
    beforeEach(() => (collection = new Tasks()));

    context('perPage is not defined in lastFetchOptions', function() {
      beforeEach(() => (collection.lastFetchOptions = { perPage: undefined }));

      return it('throws if perPage is not defined', () =>
        expect(() => collection._maxPage()).toThrow());
    });

    return context('perPage is defined', function() {
      beforeEach(function() {
        collection.lastFetchOptions = { perPage: 20 };
        return spyOn(collection, 'getServerCount').and.returnValue(100);
      });

      return it('returns the maximum possible page', () =>
        expect(collection._maxPage()).toEqual(
          collection.getServerCount() / collection.lastFetchOptions.perPage
        ));
    });
  });
});
