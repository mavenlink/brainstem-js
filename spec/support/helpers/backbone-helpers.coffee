beforeEach ->
  this.addMatchers {
    toBeValid: ->
      errors = JSON.stringify @actual.validate(@actual.attributes)
      if @isNot
        @message = -> "Expected not valid, got valid"
      else
        @message = -> "Expected valid, got not valid with errors: #{errors}"
      @actual.isValid()
  }