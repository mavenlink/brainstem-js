Backbone.sync = (method, modelOrCollection, options) ->
  getUrl = (model, method) ->
    if model.methodUrl && _.isFunction model.methodUrl
      model.methodUrl(method || 'read') || (Brainstem.Utils.throwError("A 'url' property or function must be specified"))
    else
      if model.url && _.isFunction model.url
        model.url()
      else
        model.url || (Brainstem.Utils.throwError("A 'url' property or function must be specified"))

  methodMap =
    create: 'POST'
    update: 'PUT'
    delete: 'DELETE'
    read  : 'GET'

  type = methodMap[method]

  params = _.extend({
    type:         type
    dataType:     'json'
    url:          options.url || getUrl modelOrCollection, method
    processData: type == 'GET'
    complete: (jqXHR, textStatus) ->
      modelOrCollection.trigger 'sync:end'
      options.complete(jqXHR, textStatus) if options.complete?
    beforeSend: (xhr) ->
      modelOrCollection.trigger 'sync:start'
  }, options)

  params.error = (jqXHR, textStatus, errorThrown) -> base.data.errorInterceptor(options.error, modelOrCollection, options, jqXHR, params)

  if !params.data && modelOrCollection && (method == 'create' || method == 'update')
    params.contentType = 'application/json'
    data = {}

    if modelOrCollection.toServerJSON?
      json = modelOrCollection.toServerJSON(method)
    else
      json = modelOrCollection.toJSON()

    if modelOrCollection.paramRoot
      data[modelOrCollection.paramRoot] = json
    else
      data = json

    data.include = options.include
    params.data = JSON.stringify(data)

  $.ajax params