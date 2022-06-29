/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const Backbone = require('backbone');
Backbone.$ = require('jquery');

const Model = require('../src/model');
const TimeEntries = require('./helpers/models/time-entries');

describe('Sync', function() {
  let ajaxSpy = null;

  beforeEach(() => (ajaxSpy = spyOn(Backbone.$, 'ajax')));

  return describe('updating models', function() {
    it('should use toServerJSON instead of toJSON', function() {
      const modelSpy = spyOn(Model.prototype, 'toServerJSON');
      const model = buildTimeEntry();
      model.save();
      return expect(modelSpy).toHaveBeenCalled();
    });

    it('should pass options.include through the JSON', function() {
      const model = buildTimeEntry();
      model.save({}, { include: 'creator' });
      return expect(ajaxSpy.calls.mostRecent().args[0].data).toMatch(
        /"include":"creator"/
      );
    });

    it('should accept an array for options.include', function() {
      const model = buildTimeEntry();
      model.save({}, { include: ['creator', 'story'] });
      return expect(ajaxSpy.calls.mostRecent().args[0].data).toMatch(
        /"include":"creator,story"/
      );
    });

    it('should pass options.optionalFields through the JSON', function() {
      const model = buildTimeEntry();
      model.save({}, { optionalFields: 'is_invoiced' });
      return expect(ajaxSpy.calls.mostRecent().args[0].data).toMatch(
        /"optional_fields":"is_invoiced"/
      );
    });

    it('should accept an array for options.optionalFields', function() {
      const model = buildTimeEntry();
      model.save({}, { optionalFields: ['invoice_id', 'story_id'] });
      return expect(ajaxSpy.calls.mostRecent().args[0].data).toMatch(
        /"optional_fields":"invoice_id,story_id"/
      );
    });

    it("should include additional 'params' from options", function() {
      const model = buildTimeEntry();
      model.save({}, { params: { test: true } });
      return expect(ajaxSpy.calls.mostRecent().args[0].data).toMatch(
        /"test":true/
      );
    });

    return it('should setup param roots when models have a paramRoot set', function() {
      const model = buildTimeEntry();
      model.save({});
      return expect(ajaxSpy.calls.mostRecent().args[0].data).toMatch(
        /"time_entry":{/
      );
    });
  });
});
