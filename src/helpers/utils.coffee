window.p = -> console?.log arguments

window.Utils =
  warn: (args...) ->
    console?.log "Error:", args...

  alert: (message) ->
    alert message

  confirm: (message) ->
    confirm message

  combineFunctions: ->
    functions = arguments
    return ->
      originalArguments = arguments
      result = undefined
      for func in functions
        result = func.apply this, originalArguments if typeof(func) == "function"
      result

  timeToMinutes: (value) ->
    colonMatch = /(\d*):(\d*)/.exec(value)
    if colonMatch
      (parseInt(colonMatch[1]) || 0) * 60 + (parseInt(colonMatch[2]) || 0)
    else if /\d\s*[hm]/i.test(value)
      minutes = 0
      hourMatch = /([\d\.]+)\s*h/i.exec(value)
      minuteMatch = /([\d\.]+)\s*m/i.exec(value)
      minutes += parseFloat(hourMatch[1]) * 60 if hourMatch
      minutes += parseInt(minuteMatch[1], 10) if minuteMatch
      minutes
    else
      hoursValue = parseFloat(value)
      if isNaN(hoursValue)
        null
      else
        Math.ceil(hoursValue * 60)

  formatTime: (time, orig) ->
    return orig if time == null

    hours = Math.floor(time / 60)
    minutes = Math.ceil(time % 60)
    hours + "h " + minutes + "m"

  formatDigitDisplay: (val) ->
    if (val >= 10)
      return val.toString();
    else
      return "0" + val.toString()

  formatDateFromMicrosoftEpoch: (daysFromEpoch) ->
    # MS's epoch is Jan 1 1900, hope that never changes....
    d = new Date(1900, 0, daysFromEpoch)
    return Utils.dashedDate(d)

  formatDateFromMillis: (millis) ->
    d = new Date(millis)
    "#{@formatDigitDisplay(d.getMonth() + 1)}/#{@formatDigitDisplay(d.getDate())}/#{@formatDigitDisplay(d.getFullYear() % 100)}"

  formatDate: (dateString) ->
    @_formatDateString(dateString, true)

  formatDateMonth: (dateString) ->
    @_formatDateString(dateString, false)

  _formatDateString: (dateString, includeYear) ->
    date = @dashedDateFormat(dateString)
    [date, year, month, day] = date.match(/(\d+)-(\d+)-(\d+)/)
    str = "#{month}/#{day}"
    str += "/#{year.slice(2)}" if includeYear
    str

  slashedDateFormat: (dateString) ->
    if typeof(dateString) == "string"
      dateString = dateString.replace(/\-/g, "/")

    dateString

  dashedDateFormat: (dateString) ->
    if typeof(dateString) == "string"
      dateString = dateString.replace(/\//g, "-")

    dateString

  dashedDate: (date) ->
    "#{date.getFullYear()}-#{Utils.formatDigitDisplay(date.getMonth() + 1)}-#{Utils.formatDigitDisplay(date.getDate())}"

  dateAtMidnight: (date) ->
    if date && /^(\d{4})\-(\d\d)-(\d\d)$/.test(date)
      date = date.replace(/\-/gi, '/')
    date = new Date(date)
    new Date(date.getFullYear(), date.getMonth(), date.getDate())

  weeksBefore: (startDate = Utils.nowInMs(), numWeeks = 2) ->
    startDate = new Date(parseInt(startDate)) if typeof(startDate) == 'number'
    new Date(startDate.getTime() - (numWeeks * 7) * 1000 * 60 * 60 * 24)

  weeksAfter: (startDate = Utils.nowInMs(), numWeeks = 2) ->
    startDate = new Date(parseInt(startDate)) if typeof(startDate) == 'number'
    new Date(startDate.getTime() + (numWeeks * 7) * 1000 * 60 * 60 * 24)

  getDatePerformedOrToday: (date) ->
    if (!date?)
      d = new Date()
      date = "#{d.getFullYear()}-#{Utils.formatDigitDisplay(d.getMonth() + 1)}-#{Utils.formatDigitDisplay(d.getDate())}"
    else
      date = date.replace(/\//g, "-")
    date

  centsToCurrency: (cents, subUnit=100, symbol="$") ->
    placesAfterDecimal = 0
    numerator = subUnit
    while numerator != 1
      numerator /= 10
      placesAfterDecimal++

    amount = (Math.abs(cents / subUnit)).toFixed(placesAfterDecimal)

    amount = Utils.numberWithCommas(amount)
    amount = symbol + amount
    amount = "-" + amount if cents < 0
    amount

  currencyToCents: (currencyString, subUnit=100) ->
    subUnit *= -1 if currencyString.charAt(0) == "-"
    [currencyString, symbol, cents] = currencyString.replace(/,/g, '').match(/(\D*)(\d+\.?\d*)/)
    cents = parseFloat(cents)
    cents *= subUnit
    parseInt(cents)

  numberWithCommas: (num) ->
    parts = String(num).split(".");
    parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",")
    parts.join(".")

  nowInMs: ->
   new Date().getTime()

  nowInSeconds: ->
    Utils.nowInMs() / 1000

  timeAgoInWords: (seconds) ->
    milliseconds = seconds * 1000
    date = new Date(milliseconds)
    ago = Utils.nowInMs() - milliseconds
    if (ago < 60 * 1000)
      return "now"
    else if (ago < 60 * 60 * 1000)
      minutes = Math.floor(ago / 60 / 1000)
      return minutes + ' min'
    else if (ago < 60 * 60 * 24 * 1000)
      hours = Math.floor(ago / 60 / 60 / 1000)
      return hours + (if hours == 1 then " hr" else " hrs")
    else if (ago < 6 * 24 * 60 * 60 * 1000)
      days = Math.floor(ago / 60 / 60 / 24 / 1000)
      return days + (if days == 1 then " day" else " days")
    else
      return Utils.formatDateFromMillis(milliseconds)

  escapeHtml: (html) ->
    html.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/'/g, '&#39;').replace(/"/g, '&#34;')

  truncate: (string, length=30, escape=false) ->
    string = $.trim(string)
    if (string && string.length > length)
      string = string.substring(0, length - 3)
      (if escape then Utils.escapeHtml(string) else string) + "..."
    else
      if escape then Utils.escapeHtml(string) else string

  toSentence: (arr, useAnd=false) ->
    len = arr.length
    result = undefined
    conjunction = if useAnd then 'and' else '&'
    switch len
      when 0 then result = ''
      when 1 then result = arr[0]
      when 2 then result = "#{arr[0]} #{conjunction} #{arr[1]}"
      else result = "#{arr.slice(0, -1).join(', ')} #{conjunction} #{arr[len - 1]}"

    result

  toCountSentence: (arr, withRecipients = false) ->
    len = arr.length

    if withRecipients || len < 3
      return Utils.toSentence(arr, true)

    "#{arr[0]} and #{len - 1} others"

  scrollTo: (idOrClass, duration = 0) ->
    $('body,html').animate({scrollTop: $(idOrClass).offset().top}, duration)

  isAndroidNativeBrowser4: ->
    Utils.userAgent().match(/AppleWebKit\/534\.30/i)?

  isiOS: ->
    Utils.userAgent().match(/(iPhone|iPod|iPad)/)?

  isiOS6: ->
    Utils.isiOS() && Utils.userAgent().match(/(6_\d)/)?

  isAppMode: ->
    Utils.isiOS() && Utils.standalone()

  isSupportedOS: ->
    invalidUserAgentRegexes = []
    if Utils.isiOS()
      invalidUserAgentRegexes.push(/OS [2-3]_\d(_\d)? like Mac OS X/i)
      invalidUserAgentRegexes.push(/CPU like Mac OS X/i)
    # else
    #   add some non-idevices devices

    if _.any(invalidUserAgentRegexes, (regex) -> regex.test(Utils.userAgent()))
      return false

    return true

  userAgent: ->
    navigator.userAgent

  standalone: ->
    navigator.standalone

  simpleFormat: (text) ->
    text = '' if !text?
    start_tag = "<p>"
    text = Utils.escapeHtml(text)
    text = text.replace(/\r\n?/gm, "\n")
    text = text.replace(/\n\n+/gm, "</p>\n\n" + start_tag)
    text = text.replace(/([^\n]\n)(?=[^\n])/gm, '$1<br />')

    start_tag + text + "</p>"

  splitStringToInt: (string, delim = ',') ->
    if (string)
      ret = _.map(string.split(delim), (i) -> parseInt(i, 10))
    else
      ret = []

  capitalize: (s) ->
    return s.toLowerCase().replace( /\b./g, (c) -> c.toUpperCase() )

  trackPageView: (path) ->
    if window._gaq?
      @_trackPageView(path)

  _trackPageView: (path) ->
    window._gaq.push(['_trackPageview', "/#{path}"])

  filesizeInWords: (bytes, precision) ->
    window.filesize(bytes , precision)

  airbrake: (message, stack = '') =>
    setTimeout (=> Hoptoad?.notify(message: message, stack: stack)), 50

  getPhotoHTML: (user) ->
    if user
      "<img src='" + user.get('photo_path') + "' height='36px' width='36px' />"
    else
      "<img src='/images/default-profile-images/default.png' height='36px' width='36px' />"

  throwError: (message) =>
    throw new Error("#{Backbone.history.getFragment()} (user #{base.currentUserId()}): #{message}")

  stripLeadingCharacters: (str) =>
    for i in [0..str.length - 1]
      charCode = str.charCodeAt(i)
      if (charCode > 47) && (charCode <  58)
        if i > 0 && str[i-1] == '-'
          return str.substring(i-1)
        else
          return str.substring(i)

    return ""

  linkify: (text) ->
    urlPattern = /\b(https?:\/\/|www\.)[-A-Za-z0-9+&@#/%?=~_()|!:,.;]*\.[-A-Za-z0-9+&@#/%?=~_()|!:,.;]*[-A-Za-z0-9+&@#/%=~_()|]/gim
    text.replace(urlPattern, (sub, group1, offset, full) ->
      removeRParen = Utils._hasHangingRParen(sub)
      ender = ""
      if removeRParen
        sub = sub.slice(0, -1)
        ender = ")"

      target = sub
      unless sub.match('https?:\/\/')
        target = "http://" + target

      '<a href="' + target + '" target="_blank">' + sub + '</a>' + ender
      )

  _hasHangingRParen: (substring) =>
    numLParens = substring.match(/\(/)?.length || 0
    numRParens = substring.match(/\)/)?.length || 0
    substring.lastIndexOf(')') == (substring.length - 1) && numLParens != numRParens

  looksLikeEmailAddress: (string) ->
      #the ultimate email regex matcher from http://fightingforalostcause.net/misc/2006/compare-email-regex.php
      return /^[-a-z0-9~!$%^&*_=+}{\'?]+(\.[-a-z0-9~!$%^&*_=+}{\'?]+)*@([a-z0-9_][-a-z0-9_]*(\.[-a-z0-9_]+)*\.(aero|arpa|asia|biz|cat|com|coop|edu|gov|info|int|jobs|mil|museum|name|net|org|pro|tel|travel|mobi|xxx|[a-z][a-z])|([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}))(:[0-9]{1,5})?$/i.test(string);

  fullDOMHeight: ->
    $("#split-view")?.outerHeight() || $(document).height()

  buildSelector: (options, className) ->
    html = "<select #{"class='" + className + "'" if className}>"
    for option in options
      html += "<option value='#{option.value}' #{if option.default then "selected='selected'" else ""}>#{option.text}</option>"
    html += "</select>"

  getCssClassForExtension: (extension) =>
    switch (extension)
      when "jpg", "jpeg" then "icon-type-jpg"
      when "png", "gif", "zip", "txt", "csv", "pdf" then "icon-type-#{extension}"
      when "doc", "docx" then "icon-type-doc"
      when "xls", "xlsx" then "icon-type-xls"
      when "ppt", "pptx" then "icon-type-ppt"
      else "icon-type-other"

  getFilenameExtension: (filename) =>
    index = filename.lastIndexOf('.')

    if (index == -1)
      return ""

    ext = filename.substr(index + 1)