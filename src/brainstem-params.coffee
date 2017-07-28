class BrainstemParams

  constructor: (params) ->
    for key, value of params
      @[key] = value


module.exports = BrainstemParams
