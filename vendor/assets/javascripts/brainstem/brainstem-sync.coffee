Backbone.sync = (method, model, options) ->
  methodMap =
    create: 'POST'
    update: 'PUT'
    patch:  'PATCH'
    delete: 'DELETE'
    read:   'GET'

  type = methodMap[method];

  # Default options, unless specified.
  _.defaults(options || (options = {}), {
    emulateHTTP: Backbone.emulateHTTP,
    emulateJSON: Backbone.emulateJSON
  })

  # Default JSON-request options.
  params = { type: type, dataType: 'json' }

  # Ensure that we have a URL.
  if (!options.url)
    params.url = _.result(model, 'url') || urlError()

  # Ensure that we have the appropriate request data.
  if !options.data? && model && (method == 'create' || method == 'update' || method == 'patch')
    params.contentType = 'application/json'
    data = options.attrs || {}

    if model.toServerJSON?
      json = model.toServerJSON(method, options)
    else
      json = model.toJSON(options)

    if model.paramRoot
      data[model.paramRoot] = json
    else
      data = json

    data.include = Brainstem.Utils.extractArray("include", options).join(";")
    data.filters = Brainstem.Utils.extractArray("filters", options).join(",")
    params.data = JSON.stringify(data)

  # For older servers, emulate JSON by encoding the request into an HTML-form.
  if options.emulateJSON
    params.contentType = 'application/x-www-form-urlencoded'
    params.data = if params.data then {model: params.data} else {}

  # For older servers, emulate HTTP by mimicking the HTTP method with `_method`
  # And an `X-HTTP-Method-Override` header.
  if options.emulateHTTP && (type == 'PUT' || type == 'DELETE' || type == 'PATCH')
    params.type = 'POST'
    if options.emulateJSON
      params.data._method = type
    beforeSend = options.beforeSend
    options.beforeSend = (xhr) ->
      xhr.setRequestHeader 'X-HTTP-Method-Override', type
      if beforeSend
        beforeSend.apply this, arguments

  # Don't process data on a non-GET request.
  if params.type != 'GET' && !options.emulateJSON
    params.processData = false

  # If we're sending a `PATCH` request, and we're in an old Internet Explorer
  # that still has ActiveX enabled by default, override jQuery to use that
  # for XHR instead. Remove this line when jQuery supports `PATCH` on IE8.
  if params.type == 'PATCH' && window.ActiveXObject && !(window.external && window.external.msActiveXFilteringEnabled)
    params.xhr = -> new ActiveXObject("Microsoft.XMLHTTP")

  errorHandler = options.error
  options.error = (jqXHR, textStatus, errorThrown) -> base?.data?.errorInterceptor?(errorHandler, model, options, jqXHR, params)

  # Make the request, allowing the user to override any Ajax options.
  xhr = options.xhr = Backbone.ajax(_.extend(params, options))
  model.trigger 'request', model, xhr, options
  xhr
