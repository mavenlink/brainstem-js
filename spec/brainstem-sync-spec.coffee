describe "Brainstem.Sync", ->
  describe "updating models", ->
    it "should use toServerJSON instead of toJSON", ->
      spyOn($, 'ajax')
      modelSpy = spyOn(Brainstem.Model.prototype, 'toServerJSON')
      model = buildTimeEntry()
      model.save()
      expect(modelSpy).toHaveBeenCalled()
