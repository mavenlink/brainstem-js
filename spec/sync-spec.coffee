Backbone = require 'backbone'
Backbone.$ = require 'jquery'

Model = require '../src/model'
TimeEntries = require './helpers/models/time-entries.coffee'


describe "Sync", ->
  ajaxSpy = null

  beforeEach ->
    ajaxSpy = spyOn(Backbone.$, 'ajax')

  describe 'custom headers', ->
    beforeSend = null
    collection = null
    setRequestHeader = null

    describe 'X-Feature-Name', ->
      beforeEach ->
        collection = new TimeEntries()
        setRequestHeader = jasmine.createSpy('setRequestHeader')

      it 'is not undefined', ->
        jqXhr = collection.fetch()
        beforeSend = ajaxSpy.calls.mostRecent().args[0].beforeSend
        beforeSend({ setRequestHeader })
        expect(setRequestHeader).not.toHaveBeenCalledWith('X-Feature-Name', undefined)

      it 'settable via feature_name', ->
        jqXhr = collection.fetch(headers: featureName: 'ima-feature')
        beforeSend = ajaxSpy.calls.mostRecent().args[0].beforeSend
        beforeSend({ setRequestHeader })
        expect(setRequestHeader).toHaveBeenCalledWith('X-Feature-Name', 'ima-feature')

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
