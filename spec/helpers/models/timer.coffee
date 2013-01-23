class App.Models.Timer extends Mavenlink.Model
  url: "/api/timer.json"

  defaults:
    time_before_started: 0
    time_started: null
    active: false

  fetch: (options) =>
    $.ajax url: "/api/timer.json", type: 'get', dataType: 'json', success: Utils.combineFunctions(@handleServerResponse, options.success), error: base.makeErrorHandler()

  start: =>
    unless @get("active")
      @set active: true, time_started: @now()
      $.ajax url: "/api/timer/start.json", type: 'post', dataType: 'json', success: @handleServerResponse, error: base.makeErrorHandler()

  pause: =>
    if @get("active")
      elapsedTime = @elapsedTime()
      @set active: false, time_started: null, time_before_started: elapsedTime
      $.ajax url: "/api/timer/pause.json", type: 'post', dataType: 'json', success: @handleServerResponse, error: base.makeErrorHandler()

  reset: =>
    @set active: false, time_started: null, time_before_started: 0
    $.ajax url: "/api/timer/reset.json", type: 'post', dataType: 'json', success: @handleServerResponse, error: base.makeErrorHandler()

  handleServerResponse: (json) =>
    @set time_before_started: json.elapsed_time, active: json.active, time_started: (if json.active then @now() else null)

  now: -> parseInt((new Date()).getTime() / 1000)

  elapsedTime: =>
    if @get 'active'
      @get('time_before_started') + (@now() - @get("time_started"))
    else
      @get 'time_before_started'

  getElapsedTimeHash: =>
    elapsedTime = @elapsedTime()
    secondsToMinutes = 60
    secondsToHours = 60 * 60
    timeHours = parseInt(elapsedTime / secondsToHours)
    timeMinutes = parseInt((elapsedTime - timeHours * secondsToHours) / secondsToMinutes)
    timeSeconds = elapsedTime - timeHours * secondsToHours - timeMinutes * secondsToMinutes

    { hours: Utils.formatDigitDisplay(timeHours), minutes: Utils.formatDigitDisplay(timeMinutes), seconds: Utils.formatDigitDisplay(timeSeconds) }