Backbone = require 'backbone'
Backbone.$ = require 'jquery'

Model = require '../src/model'
createSync = require '../src/create-sync'


describe "createSync", ->
  ajaxSpy = null

  beforeEach ->
    ajaxSpy = spyOn(Backbone.$, 'ajax')

  describe "updating models", ->
    it "should use toServerJSON instead of toJSON", ->
      modelSpy = spyOn(Model.prototype, 'toServerJSON')
      model = buildTimeEntry()
      model.save()
      expect(modelSpy).toHaveBeenCalled()

    it "should pass options.include through the JSON", ->
      model = buildTimeEntry()
      model.save({}, include: 'creator')
      expect(ajaxSpy.calls.mostRecent().args[0].data).toMatch(/"include":"creator"/)

    it "should accept an array for options.include", ->
      model = buildTimeEntry()
      model.save({}, include: ['creator', 'story'])
      expect(ajaxSpy.calls.mostRecent().args[0].data).toMatch(/"include":"creator,story"/)

    it "should pass options.optionalFields through the JSON", ->
      model = buildTimeEntry()
      model.save({}, optionalFields: 'is_invoiced')
      expect(ajaxSpy.calls.mostRecent().args[0].data).toMatch(/"optional_fields":"is_invoiced"/)

    it "should accept an array for options.optionalFields", ->
      model = buildTimeEntry()
      model.save({}, optionalFields: ['invoice_id', 'story_id'])
      expect(ajaxSpy.calls.mostRecent().args[0].data).toMatch(/"optional_fields":"invoice_id,story_id"/)

    it "should include additional 'params' from options", ->
      model = buildTimeEntry()
      model.save({}, params: { test: true })
      expect(ajaxSpy.calls.mostRecent().args[0].data).toMatch(/"test":true/)

    it "should setup param roots when models have a paramRoot set", ->
      model = buildTimeEntry()
      model.save({})
      expect(ajaxSpy.calls.mostRecent().args[0].data).toMatch(/"time_entry":{/)

  describe "when there is a configured host", ->
    oldSync = null

    beforeEach ->
      oldSync = Backbone.sync
      Backbone.sync = createSync(host: 'https://api.host.com', withCredentials: true)

    afterEach ->
      Backbone.sync = oldSync

    it "uses the host for the API endpoint", ->
      model = buildTimeEntry()
      model.save()
      expect(ajaxSpy.calls.mostRecent().args[0].url).toMatch(/https:\/\/api\.host\.com/)

    it "uses the withCredentials option for the XHR", ->
      model = buildTimeEntry()
      model.save()
      expect(ajaxSpy.calls.mostRecent().args[0].xhrFields.withCredentials).toBe(true)

    it "defaults withCredentials to false", ->
      Backbone.sync = createSync(host: 'https://api.host.com')
      model = buildTimeEntry()
      model.save()
      expect(ajaxSpy.calls.mostRecent().args[0].xhrFields.withCredentials).toBe(false)
