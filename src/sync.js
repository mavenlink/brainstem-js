/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const _ = require('underscore');
const Backbone = require('backbone');
Backbone.$ = require('jquery'); // TODO remove after upgrading to backbone 1.2+

const Utils = require('./utils');

module.exports = function(method, model, options) {
  let data;
  const methodMap = {
    create: 'POST',
    update: 'PUT',
    patch: 'PATCH',
    delete: 'DELETE',
    read: 'GET'
  };

  const type = methodMap[method];

  // Default options, unless specified.
  _.defaults(options || (options = {}), {
    emulateHTTP: Backbone.emulateHTTP,
    emulateJSON: Backbone.emulateJSON
  });

  // Default JSON-request options.
  const params = { type, dataType: 'json' };

  // Ensure that we have a URL.
  if (!options.url) {
    params.url = _.result(model, 'url') || urlError();
  }

  // Ensure that we have the appropriate request data.
  if (
    options.data == null &&
    model &&
    (method === 'create' || method === 'update' || method === 'patch')
  ) {
    let json;
    params.contentType = 'application/json';
    data = options.attrs || {};

    if (model.toServerJSON != null) {
      json = model.toServerJSON(method, options);
    } else {
      json = model.toJSON(options);
    }

    if (model.paramRoot) {
      data[model.paramRoot] = json;
    } else {
      data = json;
    }

    data.include = Utils.extractArray('include', options).join(',');
    data.filters = Utils.extractArray('filters', options).join(',');
    data.optional_fields = Utils.extractArray('optionalFields', options).join(
      ','
    );

    _.extend(data, options.params || {});

    params.data = JSON.stringify(data);
  }

  // For older servers, emulate JSON by encoding the request into an HTML-form.
  if (options.emulateJSON) {
    params.contentType = 'application/x-www-form-urlencoded';
    params.data = params.data ? { model: params.data } : {};
  }

  // For older servers, emulate HTTP by mimicking the HTTP method with `_method`
  // And an `X-HTTP-Method-Override` header.
  if (
    options.emulateHTTP &&
    (type === 'PUT' || type === 'DELETE' || type === 'PATCH')
  ) {
    params.type = 'POST';
    if (options.emulateJSON) {
      params.data._method = type;
    }
    const { beforeSend } = options;
    options.beforeSend = function(xhr) {
      xhr.setRequestHeader('X-HTTP-Method-Override', type);
      return beforeSend != null ? beforeSend.apply(this, arguments) : undefined;
    };
  }

  // Clear out default data for DELETE requests, fixes a firefox issue where this
  // exception is thrown: JavaScript component does not have a method named: “available”
  if (params.type === 'DELETE') {
    params.data = null;
  }

  // Don't process data on a non-GET request.
  if (params.type !== 'GET' && !options.emulateJSON) {
    params.processData = false;
  }

  // If we're sending a `PATCH` request, and we're in an old Internet Explorer
  // that still has ActiveX enabled by default, override jQuery to use that
  // for XHR instead. Remove this line when jQuery supports `PATCH` on IE8.
  if (
    params.type === 'PATCH' &&
    window.ActiveXObject &&
    !(window.external && window.external.msActiveXFilteringEnabled)
  ) {
    params.xhr = () => new ActiveXObject('Microsoft.XMLHTTP');
  }

  // Make the request, allowing the user to override any Ajax options.
  const xhr = (options.xhr = Backbone.ajax(_.extend(params, options)));
  model.trigger('request', model, xhr, options);
  return xhr;
};
