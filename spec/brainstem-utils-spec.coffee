describe 'Brainstem Utils', ->
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