Backbone = require 'backbone'

Error = require '../src/error'
Utils = require '../src/utils'


describe 'Brainstem Utils', ->
  describe '.throwError', ->
    throwError = ->
      Utils.throwError('the error')

    context 'Backbone.history.getFragment returns a fragment', ->

      beforeEach ->
        spyOn(Backbone.history, 'getFragment').and.returnValue('the/fragment#hash')

      it 'throws an error including the message', ->
        expect(throwError).toThrowError(Error, /the error/)

      it 'throws an error including the fragment', ->
        expect(throwError).toThrowError(Error, /the\/fragment#hash/)

    context 'Backbone.history.getFragment throws an error', ->
      beforeEach ->
        spyOn(Backbone.history, 'getFragment').and.callFake(-> throw new Error('error'))

      it 'throws an error including the message', ->
        expect(throwError).toThrowError(Error, 'the error')

  describe ".matches", ->
    it "should recursively compare objects and arrays", ->
      expect(Utils.matches(2, 2)).toBe true
      expect(Utils.matches([2], [2])).toBe true, '[2], [2]'
      expect(Utils.matches([2, 3], [2])).toBe false
      expect(Utils.matches([2, 3], [2, 3])).toBe true, '[2, 3], [2, 3]'
      expect(Utils.matches({ hi: "there" }, { hi: "there" })).toBe true, '{ hi: "there" }, { hi: "there" }'
      expect(Utils.matches([2, { hi: "there" }], [2, { hi: 2 }])).toBe false
      expect(Utils.matches([2, { hi: "there" }], [2, { hi: "there" }])).toBe true, '[2, { hi: "there" }], [2, { hi: "there" }]'
      expect(Utils.matches([2, { hi: ["there", 3] }], [2, { hi: ["there", 2] }])).toBe false
      expect(Utils.matches([2, { hi: ["there", 2] }], [2, { hi: ["there", 2] }])).toBe true, '[2, { hi: ["there", 2] }], [2, { hi: ["there", 2] }]'

  describe ".wrapObjects", ->
    it "wraps elements in an array with objects unless they are already objects", ->
      expect(Utils.wrapObjects([])).toEqual []
      expect(Utils.wrapObjects(['a', 'b'])).toEqual [{a: []}, {b: []}]
      expect(Utils.wrapObjects(['a', 'b': []])).toEqual [{a: []}, {b: []}]
      expect(Utils.wrapObjects(['a', 'b': 'c'])).toEqual [{a: []}, {b: [{c: []}]}]
      expect(Utils.wrapObjects([{'a':[], b: 'c', d: 'e' }])).toEqual [{a: []}, {b: [{c: []}]}, {d: [{e: []}]}]
      expect(Utils.wrapObjects(['a', { b: 'c', d: 'e' }])).toEqual [{a: []}, {b: [{c: []}]}, {d: [{e: []}]}]
      expect(Utils.wrapObjects([{'a': []}, {'b': ['c', d: []]}])).toEqual [{a: []}, {b: [{c: []}, {d: []}]}]

  describe '.wrapError', ->
    options = model = null
    beforeEach ->
      options = model = {}
      model.trigger = jasmine.createSpy()

    it 'triggers error on the model', ->
      options.error = jasmine.createSpy()
      Utils.wrapError(model, options)
      options.error('asdf')

      expect(model.trigger).toHaveBeenCalledWith('error', model, 'asdf', options)

    context 'when an error handler is defined', ->
      originalError = null

      beforeEach ->
        originalError = options.error = jasmine.createSpy()
        Utils.wrapError(model, options)
        options.error('asdf')

      it 'calls original error handler', ->
        expect(originalError).toHaveBeenCalledWith model, 'asdf', options

    context 'when an error handler is not defined', ->
      beforeEach ->
        expect(options.error).toBeUndefined()
        Utils.wrapError(model, options)

      it 'sets a function on options.error', ->
        expect(options.error).toBeDefined()
        expect(options.error).toEqual(jasmine.any(Function))
