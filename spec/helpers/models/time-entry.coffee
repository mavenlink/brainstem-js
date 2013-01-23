class App.Models.TimeEntry extends Mavenlink.Model
  paramRoot: 'time_entry'

  defaults:
    billable: true

  validate: (attrs) =>
    window.App.Validator(attrs, {
      date_performed:
        format: { regex: /^\d{2,4}[\/\-]\d{1,2}[\/\-]\d{1,2}$/, message: "A valid date is required." }
      time_in_minutes:
        numeric: { min: 0, max: 1441, message: "Time must be between one minute and 24 hours." }
      rate_in_cents:
        custom: @validateRateInCents
      workspace_id:
        numeric: { min: 0, message: "You must select a workspace." }
      story_id:
        numeric: { min: 0, allowBlank: true }
    })

  validateRateInCents: (field, attrs, settings) =>
    rate = attrs[field]
    if isNaN(rate) || typeof(rate) is "string"
      return "Billing rate must be a positive number"

    if base.currentUserCanSeeRates()
      if rate is null || rate is undefined || rate < 0
        return "Billing rate must be a positive number"
      else if attrs["billable"] && rate is 0
        return "Billing rate must be a positive number"

  methodUrl: (method) ->
    switch method
      when "delete" then "/api/time_entries/#{@id}?workspace_id=#{@attributes.workspace_id}"
      when "create" then "/api/time_entries"
      else "/api/time_entries/#{@id}"

  getDatePerformedOrToday: ->
    Utils.getDatePerformedOrToday(@get('date_performed'))

  getRate: ->
    return "- -" if @get('rate_in_cents') is null || !@get('billable')?
    Utils.centsToCurrency @get('rate_in_cents'), @get('currency_base_unit'), @get('currency_symbol')

  getPrice: ->
    if @get('billable') && @get('rate_in_cents') != null
      price_in_cents = @get('rate_in_cents') * @get('time_in_minutes')/60
      Utils.centsToCurrency(price_in_cents, @get('currency_base_unit'), @get('currency_symbol'))

  getDatePerformed: =>
    new Date(Utils.slashedDateFormat(@get('date_performed')))

  getDisplayTime: =>
    time_in_minutes = @get('time_in_minutes')
    hours = Utils.formatDigitDisplay(parseInt(time_in_minutes / 60))
    minutes = Utils.formatDigitDisplay(time_in_minutes % 60)
    "#{hours}:#{minutes}"

  @associations:
    workspace: "workspaces"
    story: "stories"
    user: "users"

class App.Collections.TimeEntries extends Mavenlink.Collection
  model: App.Models.TimeEntry
  url: '/api/time_entries'

  @getComparator: (field) ->
    if field == "date_performed"
      return (a, b) -> a.getDatePerformed().getTime() - b.getDatePerformed().getTime()
    else
      super