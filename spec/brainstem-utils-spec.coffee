describe 'Brainstem Utils', ->
  describe '.throwError', ->
    beforeEach ->
      spyOn(Brainstem, 'Error').andCallThrough()

    context 'Backbone.history.getFragment returns a fragment', ->
      beforeEach ->
        spyOn(Backbone.history, 'getFragment').andReturn('the/fragment#hash')

      it 'throws an error including the message', ->
        expect(-> Brainstem.Utils.throwError('the error')).toThrow()
        expect(Brainstem.Error).toHaveBeenCalled()
        expect(Brainstem.Error.mostRecentCall.args[0]).toMatch(/the error/)

      it 'throws an error including the fragment', ->
        expect(-> Brainstem.Utils.throwError('the error')).toThrow()
        expect(Brainstem.Error.mostRecentCall.args[0]).toMatch(/the\/fragment#hash/)

    context 'Backbone.history.getFragment throws an error', ->
      beforeEach ->
        spyOn(Backbone.history, 'getFragment').andCallFake(-> throw new Error('error'))

      it 'throws an error including the message', ->
        expect(-> Brainstem.Utils.throwError('the error')).toThrow()
        expect(Brainstem.Error).toHaveBeenCalled()
        expect(Brainstem.Error.mostRecentCall.args[0]).toMatch(/the error/)

  describe ".matches", ->
    it "should recursively compare objects and arrays", ->
      expect(Brainstem.Utils.matches(2, 2)).toBe true
      expect(Brainstem.Utils.matches([2], [2])).toBe true, '[2], [2]'
      expect(Brainstem.Utils.matches([2, 3], [2])).toBe false
      expect(Brainstem.Utils.matches([2, 3], [2, 3])).toBe true, '[2, 3], [2, 3]'
      expect(Brainstem.Utils.matches({ hi: "there" }, { hi: "there" })).toBe true, '{ hi: "there" }, { hi: "there" }'
      expect(Brainstem.Utils.matches([2, { hi: "there" }], [2, { hi: 2 }])).toBe false
      expect(Brainstem.Utils.matches([2, { hi: "there" }], [2, { hi: "there" }])).toBe true, '[2, { hi: "there" }], [2, { hi: "there" }]'
      expect(Brainstem.Utils.matches([2, { hi: ["there", 3] }], [2, { hi: ["there", 2] }])).toBe false
      expect(Brainstem.Utils.matches([2, { hi: ["there", 2] }], [2, { hi: ["there", 2] }])).toBe true, '[2, { hi: ["there", 2] }], [2, { hi: ["there", 2] }]'

  describe ".wrapObjects", ->
    it "wraps elements in an array with objects unless they are already objects", ->
      expect(Brainstem.Utils.wrapObjects([])).toEqual []
      expect(Brainstem.Utils.wrapObjects(['a', 'b'])).toEqual [{a: []}, {b: []}]
      expect(Brainstem.Utils.wrapObjects(['a', 'b': []])).toEqual [{a: []}, {b: []}]
      expect(Brainstem.Utils.wrapObjects(['a', 'b': 'c'])).toEqual [{a: []}, {b: [{c: []}]}]
      expect(Brainstem.Utils.wrapObjects([{'a':[], b: 'c', d: 'e' }])).toEqual [{a: []}, {b: [{c: []}]}, {d: [{e: []}]}]
      expect(Brainstem.Utils.wrapObjects(['a', { b: 'c', d: 'e' }])).toEqual [{a: []}, {b: [{c: []}]}, {d: [{e: []}]}]
      expect(Brainstem.Utils.wrapObjects([{'a': []}, {'b': ['c', d: []]}])).toEqual [{a: []}, {b: [{c: []}, {d: []}]}]

  describe '.wrapError', ->
    options = model = null
    beforeEach ->
      options = model = {}
      model.trigger = jasmine.createSpy()

    it 'triggers error on the model', ->
      options.error = jasmine.createSpy()
      Brainstem.Utils.wrapError(model, options)
      options.error('asdf')

      expect(model.trigger).toHaveBeenCalledWith('error', model, 'asdf', options)

    context 'when an error handler is defined', ->
      originalError = null

      beforeEach ->
        originalError = options.error = jasmine.createSpy()
        Brainstem.Utils.wrapError(model, options)
        options.error('asdf')

      it 'calls original error handler', ->
        expect(originalError).toHaveBeenCalledWith model, 'asdf', options

    context 'when an error handler is not defined', ->
      beforeEach ->
        expect(options.error).toBeUndefined()
        Brainstem.Utils.wrapError(model, options)
          
      it 'sets a function on options.error', ->
        expect(options.error).toBeDefined()
        expect(options.error).toEqual(jasmine.any(Function))
