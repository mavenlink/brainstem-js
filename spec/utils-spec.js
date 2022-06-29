/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const $ = require('jquery');
const Backbone = require('backbone');
Backbone.$ = $; // TODO remove after upgrading to backbone 1.2+

const Error = require('../src/error');
const Utils = require('../src/utils');

describe('Brainstem Utils', function() {
  describe('.throwError', function() {
    const throwError = () => Utils.throwError('the error');

    context('Backbone.history.getFragment returns a fragment', function() {
      beforeEach(() =>
        spyOn(Backbone.history, 'getFragment').and.returnValue(
          'the/fragment#hash'
        )
      );

      it('throws an error including the message', () =>
        expect(throwError).toThrowError(Error, /the error/));

      return it('throws an error including the fragment', () =>
        expect(throwError).toThrowError(Error, /the\/fragment#hash/));
    });

    return context('Backbone.history.getFragment throws an error', function() {
      beforeEach(() =>
        spyOn(Backbone.history, 'getFragment').and.callFake(function() {
          throw new Error('error');
        })
      );

      return it('throws an error including the message', () =>
        expect(throwError).toThrowError(Error, 'the error'));
    });
  });

  describe('.matches', () =>
    it('should recursively compare objects and arrays', function() {
      expect(Utils.matches(2, 2)).toBe(true);
      expect(Utils.matches([2], [2])).toBe(true, '[2], [2]');
      expect(Utils.matches([2, 3], [2])).toBe(false);
      expect(Utils.matches([2, 3], [2, 3])).toBe(true, '[2, 3], [2, 3]');
      expect(Utils.matches({ hi: 'there' }, { hi: 'there' })).toBe(
        true,
        '{ hi: "there" }, { hi: "there" }'
      );
      expect(Utils.matches([2, { hi: 'there' }], [2, { hi: 2 }])).toBe(false);
      expect(Utils.matches([2, { hi: 'there' }], [2, { hi: 'there' }])).toBe(
        true,
        '[2, { hi: "there" }], [2, { hi: "there" }]'
      );
      expect(
        Utils.matches([2, { hi: ['there', 3] }], [2, { hi: ['there', 2] }])
      ).toBe(false);
      return expect(
        Utils.matches([2, { hi: ['there', 2] }], [2, { hi: ['there', 2] }])
      ).toBe(true, '[2, { hi: ["there", 2] }], [2, { hi: ["there", 2] }]');
    }));

  describe('.wrapObjects', () =>
    it('wraps elements in an array with objects unless they are already objects', function() {
      expect(Utils.wrapObjects([])).toEqual([]);
      expect(Utils.wrapObjects(['a', 'b'])).toEqual([{ a: [] }, { b: [] }]);
      expect(Utils.wrapObjects(['a', { b: [] }])).toEqual([
        { a: [] },
        { b: [] }
      ]);
      expect(Utils.wrapObjects(['a', { b: 'c' }])).toEqual([
        { a: [] },
        { b: [{ c: [] }] }
      ]);
      expect(Utils.wrapObjects([{ a: [], b: 'c', d: 'e' }])).toEqual([
        { a: [] },
        { b: [{ c: [] }] },
        { d: [{ e: [] }] }
      ]);
      expect(Utils.wrapObjects(['a', { b: 'c', d: 'e' }])).toEqual([
        { a: [] },
        { b: [{ c: [] }] },
        { d: [{ e: [] }] }
      ]);
      return expect(
        Utils.wrapObjects([{ a: [] }, { b: ['c', { d: [] }] }])
      ).toEqual([{ a: [] }, { b: [{ c: [] }, { d: [] }] }]);
    }));

  describe('.wrapError', function() {
    let model;
    let options = (model = null);
    beforeEach(function() {
      options = model = {};
      return (model.trigger = jasmine.createSpy());
    });

    it('triggers error on the model', function() {
      options.error = jasmine.createSpy();
      Utils.wrapError(model, options);
      options.error('asdf');

      return expect(model.trigger).toHaveBeenCalledWith(
        'error',
        model,
        'asdf',
        options
      );
    });

    context('when an error handler is defined', function() {
      let originalError = null;

      beforeEach(function() {
        originalError = options.error = jasmine.createSpy();
        Utils.wrapError(model, options);
        return options.error('asdf');
      });

      return it('calls original error handler', () =>
        expect(originalError).toHaveBeenCalledWith(model, 'asdf', options));
    });

    return context('when an error handler is not defined', function() {
      beforeEach(function() {
        expect(options.error).toBeUndefined();
        return Utils.wrapError(model, options);
      });

      return it('sets a function on options.error', function() {
        expect(options.error).toBeDefined();
        return expect(options.error).toEqual(jasmine.any(Function));
      });
    });
  });

  return describe('.chunk', function() {
    it('returns an array of arrays of specified length', () =>
      expect(Utils.chunk([1, 2, 3, 4], 2)).toEqual([
        [1, 2],
        [3, 4]
      ]));

    it('handles counts that do not divide evenly into the array length', () =>
      expect(Utils.chunk([1, 2, 3, 4, 5], 2)).toEqual([[1, 2], [3, 4], [5]]));

    it('handles non-arrays', () => expect(Utils.chunk(null, 2)).toEqual([]));

    it('handles non-number counts', () =>
      expect(Utils.chunk([1, 2], null)).toEqual([]));

    it('handles a count of zero', () =>
      expect(Utils.chunk([1, 2], 0)).toEqual([]));

    return it('handles a negative count', () =>
      expect(Utils.chunk([1, 2], -1)).toEqual([]));
  });
});
