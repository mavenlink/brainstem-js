window.App ?= {}
window.App.Validator = (attrs, configuration) ->
  errors = {}
  for field, validations of configuration
    for validation, validationSettings of validations
      if validation == 'custom'
        validationResult = validationSettings.call(this, field, attrs, attrs[field])
        if validationResult?
          errors[field] ||= []
          errors[field].push validationResult
      else if window.App.Validator.builtinValidations[validation]?
        validationResult = window.App.Validator.builtinValidations[validation].call(attrs, field, attrs, validationSettings)
        if validationResult?
          errors[field] ||= []
          errors[field].push validationResult
      else
        raise "Unknown validation type #{validation}"
  return errors if Object.keys(errors).length > 0

window.App.Validator.util =
  _checkMinMax: (value, field, settings) ->
    if settings.min? && value < settings.min
      return settings.message || "#{field} cannot be less than #{settings.min}"
    else if settings.max? && value > settings.max
      return settings.message || "#{field} cannot be greater than #{settings.max}"

window.App.Validator.builtinValidations =
  strlen: (field, attrs, settings) ->
    if !attrs[field]? || (attrs[field] == "" && !settings.allowBlank)
      return settings.message || "#{field} may not be blank"
    else
      str = String(attrs[field])
      if str
        return window.App.Validator.util._checkMinMax(str.length, field, settings)

  required: (field, attrs, settings) ->
    if !attrs[field]? || (attrs[field] == "" && !settings.allowBlank)
      settings.message || "#{field} is required"

  numeric: (field, attrs, settings) ->
    value = String(attrs[field])

    if (!attrs[field]? || value == "")
      if settings.allowBlank
        return
      else
        return settings.message || "#{field} must be present and numeric"

    unless value.match(/^-?\d+\.?\d*$/)
      return settings.message || "#{field} is not numeric"

    return window.App.Validator.util._checkMinMax(parseInt(value, 10), field, settings)

  format: (field, attrs, settings) ->
    value = attrs[field]
    if (!value? || value == "")
      if settings.allowBlank
        return
      else
        settings.message || "#{field} is not formatted correctly"
    else
      unless value.match settings.regex
        settings.message || "#{field} is not formatted correctly"