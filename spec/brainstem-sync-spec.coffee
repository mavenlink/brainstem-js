describe "Brainstem.Sync", ->
  ajaxSpy = null

  beforeEach ->
    ajaxSpy = spyOn($, 'ajax')

  describe "updating models", ->
    it "should use toServerJSON instead of toJSON", ->
      modelSpy = spyOn(Brainstem.Model.prototype, 'toServerJSON')
      model = buildTimeEntry()
      model.save()
      expect(modelSpy).toHaveBeenCalled()

    it "should pass options.include through the JSON", ->
      model = buildTimeEntry()
      model.save({}, include: 'creator')
      expect(ajaxSpy.mostRecentCall.args[0].data).toMatch(/"include":"creator"/)

    it "should accept an array for options.include", ->
      model = buildTimeEntry()
      model.save({}, include: ['creator', 'story'])
      expect(ajaxSpy.mostRecentCall.args[0].data).toMatch(/"include":"creator,story"/)

    it "should include additional 'params' from options", ->
      model = buildTimeEntry()
      model.save({}, params: { test: true })
      expect(ajaxSpy.mostRecentCall.args[0].data).toMatch(/"test":true/)

    it "should setup param roots when models have a paramRoot set", ->
      model = buildTimeEntry()
      model.save({})
      expect(ajaxSpy.mostRecentCall.args[0].data).toMatch(/"time_entry":{/)
