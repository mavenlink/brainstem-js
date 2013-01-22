window.App.Mobile ?= {}

class window.App.Mobile.Base extends window.App.Base
  constructor: (appData) ->
    super

    @wakeupDeltaThreshold = 1000 * 60 * 5 #5mins

    # @sideNavView = new Mobile.Views.Common.SideNavigationMenu()
    # $('#side-nav').html(@sideNavView.render().$el)

    @setupWakeupTimer()

  checkForDeviceWakeup: =>
    currentTime = new Date()
    delta = currentTime.getTime() - @previousWakeupCheck.getTime()

    if delta > @wakeupDeltaThreshold
      @previousWakeupCheck = currentTime
      @clearCaches()
      @currentView?.onDeviceWakeUp(delta)

    @previousWakeupCheck = currentTime
    @wakeupTimer = setTimeout(@checkForDeviceWakeup, 200)

  setupWakeupTimer: =>
    unless @previousWakeupCheck?
      @previousWakeupCheck = new Date()
      @wakeupTimer = setTimeout(@checkForDeviceWakeup, 200)

  onOrientationChange: =>
    @postPageDisplayTweaks(false)

  display: (options) =>
    options = { view: options } if typeof options == 'function'
    @sideNavView.hide()
    @highlightCurrentSideNavItem()

    fragment = Backbone.history.getFragment()
    back = @trackHistoryAndDetectBackLink()
    view = @_setupForNextView(fragment, back, options)

    $("#wrapper").append("<div id='next-view'></div>")
    $main = $("#main-view")
    $next = $("#next-view")

    $next.css visibility: "hidden"
    if view.$el.children().length
      view.restoreEvents()
      $next.html view.$el
    else
      $next.html view.render().$el
    $next.css visibility: "visible"

    if @previousView
      if (back)
        $main.addClass 'back-slide-out'
        $next.addClass 'back-slide-in'
      else
        $main.addClass 'slide-out'
        $next.addClass 'slide-in'

      setTimeout (=>
        $main.remove()
        $next.removeClass 'slide-in back-slide-in'
        $next.attr "id", "main-view"
        @postPageDisplayTweaks()
        @displayOverlay new Mobile.Views.Common.FlashOverlayView(message: @flash.notice) if @flash?.notice?
        @flash = {}
      ), 150
    else
      $main.remove()
      $next.attr "id", "main-view"
      @postPageDisplayTweaks()

    view

  highlightCurrentSideNavItem: =>
    sideNavItem = @getSideNavSelectedItem()
    if sideNavItem
      @sideNavView.highlightItem(sideNavItem)

  getSideNavSelectedItem: =>
    fragment = Backbone.history.getFragment()
    selectedItem = switch fragment
      when "posts" then $('.side-nav-list li[data-item-id="activity-feed"]')
      when "stories" then $('.side-nav-list li[data-item-id="project-tracker"]')
      when "time" then $('.side-nav-list li[data-item-id="time-tracking"]')
      when "expenses" then $('.side-nav-list li[data-item-id="log-expenses"]')
      when "workspaces" then $('.side-nav-list li[data-item-id="projects"]')
      when "posts/new" then $('.side-nav-list li[data-item-id="post-message"]')
      when "stories/new" then $('.side-nav-list li[data-item-id="create-story"]')
      when "time/new" then $('.side-nav-list li[data-item-id="add-time"]')
      when "expenses/new" then $('.side-nav-list li[data-item-id="add-expense"]')
      when "workspaces/new" then $('.side-nav-list li[data-item-id="create-workspace"]')
      else @_getSideNavSelectedItemRegex(fragment)

    selectedItem

  _getSideNavSelectedItemRegex: (fragment) =>
    $('.side-nav-list li[data-item-id="projects"]') if fragment.match(/workspaces\//)

  postPageDisplayTweaks: (shouldScroll = true) =>
    @currentView?.headerView?.adjustShimHeight?()

    if @fragmentHasKnownPosition()
      @scrollTo(@historyWithPosition[@currentFragment].position)
      delete @historyWithPosition[@currentFragment]
      @forceBrowserRedraw() if Utils.isiOS()
      return

    @adjustMainViewHeight()
    @adjustCurrentViewHeight()
    @hideMobileBrowserBar() if shouldScroll
    @adjustSideNavHeight()
    @adjustSelectorViewHeight()

    @forceBrowserRedraw()

  windowHeight: =>
    windowHeight = $(window).height()
    if (Utils.isiOS())
      windowHeight += 60 #height of the apple url bar in mobile safari

    windowHeight

  isLandscapeMode: =>
    if window.hasOwnProperty "orientation"
      orientation != 0

  mavenlinkHeaderHeight: =>
    $(".mavenlink-header").outerHeight(true)

  adjustSideNavHeight: =>
    mainViewHeight = $("#main-view").outerHeight(true)
    $("#side-nav").height(mainViewHeight)

  adjustMainViewHeight: =>
    $("#main-view").css("min-height" , "#{@windowHeight()}px")

  adjustCurrentViewHeight: =>
    if @currentView?.contentView?
      return @currentView.contentView.adjustViewHeight?()

    @currentView?.adjustViewHeight?()

  setHeightForBackgroundColorFill: =>
    actualViewHeight = @windowHeight() - @mavenlinkHeaderHeight()
    $(".full-height").height(actualViewHeight)

  adjustSelectorViewHeight: =>
    if $("#please-wait").length > 0 || $("#selector-container #selector-content").length == 0
      return

    windowHeight = @windowHeight()
    contentHeight = windowHeight - $(".selector-wrapper .header").outerHeight(true) - parseInt($(".selector-wrapper").css("padding-top")) - parseInt($(".selector-wrapper").css("padding-bottom"))

    $("#selector-content").css("min-height","#{contentHeight}px")

  hideMobileBrowserBar: =>
    window.scrollTo(0, 1)

  toggleSideNav: =>
    # @sideNavView.toggle()

  setupRouters: () =>
    # @homeRouter = @registerRouter Mobile.Routers.HomeRouter
    # @timeEntriesRouter = @registerRouter Mobile.Routers.TimeEntriesRouter
    # @postsRouter = @registerRouter Mobile.Routers.PostsRouter
    # @expensesRouter = @registerRouter Mobile.Routers.ExpensesRouter
    # @storiesRouter = @registerRouter Mobile.Routers.StoriesRouter
    # @workspacesRouter = @registerRouter Mobile.Routers.WorkspacesRouter

  getFilterBarDisplayText: =>
    workspaceId = @getFilter('workspace')
    if workspaceId
      "#{@data.storage('workspaces').get(workspaceId).get('title')}"
    else
      "Unfiltered"
