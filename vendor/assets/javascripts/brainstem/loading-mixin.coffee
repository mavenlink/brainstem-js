window.Brainstem ?= {}

Brainstem.LoadingMixin =
  setLoaded: (state, options) ->
    options = { trigger: true } unless options? && options.trigger? && !options.trigger
    @loaded = state
    @trigger 'loaded', this if state && options.trigger