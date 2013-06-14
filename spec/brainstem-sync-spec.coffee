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

    it "should pass options.includes through the JSON", ->
      model = buildTimeEntry()
      model.save({}, include: 'creator')
      expect(ajaxSpy.mostRecentCall.args[0].data).toMatch(/"include":"creator"/)

    it "should setup param roots when models have a paramRoot set", ->
      model = buildTimeEntry()
      model.save({})
      expect(ajaxSpy.mostRecentCall.args[0].data).toMatch(/"time_entry":{/)

  describe 'error handler', ->
    it 'wraps the error handler in an errorInterceptor', ->
      model = buildTimeEntry()
      base.data.errorInterceptor = jasmine.createSpy('errorInterceptor')

      model.save({})
      ajaxSpy.mostRecentCall.args[0].error()
      expect(base.data.errorInterceptor).toHaveBeenCalled()

    it 'only wraps the error handler if base.data.errorInterceptor is defined', ->
      delete base.data.errorInterceptor
      model = buildTimeEntry()
      errorSpy = jasmine.createSpy('error spy')

      model.save({}, error: errorSpy)
      ajaxSpy.mostRecentCall.args[0].error()
      expect(errorSpy).toHaveBeenCalled()