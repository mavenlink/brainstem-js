window.App ?= {}

class window.App.Base
  constructor: (appData) ->
    @setupRouters()

    @history = []
    @appData = appData || {}
    @flash = {}
    @historyWithPosition = {}
    @dataFilters = {}

    # @timer = new App.Models.Timer()

    @data = new App.StorageManager()
    @data.addCollection 'time_entries', App.Collections.TimeEntries
    @data.addCollection 'expenses', App.Collections.Expenses
    @data.addCollection 'posts', App.Collections.Posts
    @data.addCollection 'assets', App.Collections.Assets
    @data.addCollection 'google_documents', App.Collections.GoogleDocuments
    @data.addCollection 'stories', App.Collections.Stories
    @data.addCollection 'workspaces', App.Collections.Workspaces
    @data.addCollection 'workspace_invitations', App.Collections.WorkspaceInvitations
    @data.addCollection 'users', App.Collections.Users
    @data.addCollection 'contacts', App.Collections.Contacts
    @data.addCollection 'participations', App.Collections.Participations

  currentUserId: =>
    @appData.mavenlinkUserId

  currentUserPlanType: =>
    @appData.mavenlinkUserPlanType

  currentUserHasQuickbooks: =>
    @appData.mavenlinkUserQuickbooksEnabled == 'true'

  currentUserAccountPermission: =>
    @appData.mavenlinkUserAccountPermission

  currentUserCsrfToken: =>
    @appData.mavenlinkUserCSRFToken

  currentUserCanSeeRates: =>
    permission = @currentUserAccountPermission()
    permission == "owner" || permission == "administrator" || permission == "project_lead"

  currentUserAccountCurrencySymbol: =>
    @appData.mavenlinkUserAccountCurrencySymbol

  currentUserAccountDefaultConsultantRoleName: =>
    @appData.mavenlinkUserAccountDefaultConsultantRoleName || "Consultants"

  currentUserAccountDefaultClientRoleName: =>
    @appData.mavenlinkUserAccountDefaultClientRoleName || "Clients"

  onOrientationChange: =>
    #hook for orientation change
    @postPageDisplayTweaks(false)

  # Display Manager

  cleanup: =>
    @currentView.cleanup() if @currentView
    @previousView.cleanup() if @previousView
    clearTimeout @wakeupTimer if @wakeupTimer

  trackHistoryAndDetectBackLink: =>
    back = false
    fragment = Backbone.history.getFragment()
    if fragment? && fragment in @history
      back = true
      f = null
      f = @history.pop() while f != fragment
    @history.push fragment
    back

  display: (options) =>
    options = { view: options } if typeof options == 'function'
    view = @_setupForNextView(Backbone.history.getFragment(), @trackHistoryAndDetectBackLink(), options)
    $('#main-view').html(view.render().$el)

  displayOverlay: (view) =>
    if view.el.children.length
      $("#overlays").append view.el
    else
      $("#overlays").append view.render().el
    @lastOverlay = view
    view

  _setupForNextView: (fragment, back, options) =>
    if $('#overlays').children().length > 0 && fragment? && fragment in @history
      @lastOverlay?.cleanup()
      @lastOverlay = null

    if fragment == @previousFragment && @previousView.reusable && !@refreshNextDisplay
      view = @previousView
    else
      view = options.view()
      view.reusable = if options.reusable? then options.reusable else true
      @previousView.cleanup() if @previousView

    # setup for next display
    @refreshNextDisplay = false
    @silenceNextAnalyticsEvent = false
    @previousView = @currentView
    @previousFragment = @currentFragment
    @currentView = view
    @currentFragment = Backbone.history.getFragment()
    view

  postPageDisplayTweaks: (shouldScroll = true) =>
    return

  fragmentHasKnownPosition: =>
    @currentFragment of @historyWithPosition

  forceBrowserRedraw: =>
    $("#main-view").toggle()  # this forces a browser redraw, which puts position fixed things where they should be
    $("#main-view").toggle()

  windowHeight: =>
    $(window).height()

  scrollTo: (yOffset) =>
    window.scrollTo(0, yOffset)

  rememberScrollPosition: =>
    scrollPosition = document.body.scrollTop
    currentFragment = Backbone.history.getFragment()
    @historyWithPosition[currentFragment] = position: scrollPosition

  navigate: (path, options = {}) =>
    @refreshNextDisplay = options.forceRefresh if options.forceRefresh?
    @flash = options.flash
    @silenceNextAnalyticsEvent = options.silenceNextAnalyticsEvent if options.silenceNextAnalyticsEvent?
    @homeRouter.navigate.apply(this, arguments)

  clearCaches: =>
    @refreshNextDisplay = true
    @data.reset()

  navigateAway: (url) =>
    window.location = url

  navigateBackOr: (path) =>
    if @history.length > 1
      backPath = "#/#{@history[@history.length - 2]}"
    else
      backPath = path
    @navigate(backPath)

  makeErrorHandler: (oldhandler, params = {}) =>
    return (json, resp) =>
      try
        error = $.parseJSON(json.responseText) || {}
      catch e
        error = {}

      if error.server_error && error.server_error == "Access token no longer valid" # { server_error: "Access token no longer valid" }
        $.cookie("oauthRedirect", "#/#{Backbone.history.getFragment()}")
        @navigateAway "/logout"
      else
        if error.errors && error.errors.length > 0
          Utils.airbrake "Server error on #{params.url}: #{error.errors.join(", ")}", JSON.stringify?(params.data)
          Utils.alert "A server error occurred.  Please contact support@mavenlink.com if you need assistance.  The error was:\n#{error.errors.join(", ")}"
        else if json.status == 0
          if Utils.confirm "Unable to contact the Mavenlink server.  Please make sure that you are currently online.  Reload?"
            @navigateAway "/" + Backbone.history.getFragment()
        else if json.status == 404
          Utils.airbrake "404 error on #{params.url}", JSON.stringify?(params.data)
          Utils.alert "That resource could not be found.  Please contact support@mavenlink.com if you need assistance."
        oldhandler.apply(this, arguments) if oldhandler?

  setupRouters: () =>
    # Do this in your subclass
    return

  registerRouter: (routerKlass) =>
    router = new routerKlass()
    router.bind 'all', =>
      unless $.cookie("oauthRedirect") || @silenceNextAnalyticsEvent
        Utils.trackPageView('/' + Backbone.history.getFragment().replace('#', ''))
    router

  isFiltered: =>
    Object.keys(@dataFilters).length > 0

  setFilter: (type, id) =>
    @dataFilters[type] = id
    @trigger('filtered')

  getFilter: (type = null) =>
    if type
      @dataFilters[type]
    else
      $.extend({}, @dataFilters)

  clearFilter: =>
    @dataFilters = {}
    @trigger('filtered')

_.extend(window.App.Base.prototype, Backbone.Events);
