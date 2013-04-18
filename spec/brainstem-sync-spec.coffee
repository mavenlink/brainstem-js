describe "Brainstem.Sync", ->
  describe "updating models", ->
    ajaxSpy = null

    beforeEach ->
      ajaxSpy = spyOn($, 'ajax')

    it "should use toServerJSON instead of toJSON", ->
      modelSpy = spyOn(Brainstem.Model.prototype, 'toServerJSON')
      model = buildTimeEntry()
      model.save()
      expect(modelSpy).toHaveBeenCalled()

    it "should pass options.includes through the JSON", ->
      model = buildTimeEntry()
      model.save({}, include: 'creator')
      expect(ajaxSpy.mostRecentCall.args[0].data).toMatch(/"include":"creator"/)

    it "should setup param roots when models have a paramRoot set", ->
      model = buildTimeEntry()
      model.save({})
      expect(ajaxSpy.mostRecentCall.args[0].data).toMatch(/"time_entry":{/)