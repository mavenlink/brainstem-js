describe "Brainstem.Sync", ->

  describe "error handling", ->

    describe "oAuth invalidation", ->
      it "Logs out the user and stores where the user was trying to go", ->
        spyOn(Utils, 'alert')
        spyOn($, 'cookie')
        spec.fragment = "time_entries"
        server.respondWith "GET", "/api/time_entries?per_page=20&page=1", [ 401, {"Content-Type": "application/json"}, JSON.stringify({server_error: "Access token no longer valid"}) ]
        base.data.loadCollection "time_entries"
        server.respond()
        expect(base.navigateAway).toHaveBeenCalledWith('/logout')
        expect($.cookie).toHaveBeenCalledWith('oauthRedirect', "#/time_entries")

    describe "api errors", ->
      it "shows an alert listing the errors returned from the user", ->
        spyOn(Utils, 'alert')
        spyOn(Utils, 'airbrake')
        model = buildPost()
        model.set { message: "" }, silent: true
        server.respondWith "PUT", "/api/posts/1", [ 422, {"Content-Type": "application/json"}, JSON.stringify({errors: ["was too short"]}) ]
        model.save()
        server.respond()
        expect(Utils.alert).toHaveBeenCalled()
        expect(Utils.alert.mostRecentCall.args[0]).toMatch(/was too short/)
        expect(Utils.airbrake).toHaveBeenCalled()

    describe "other errors", ->
      it "uses its normal error handler if it is not an oAuth Error", ->
        server.respondWith "GET", "/api/time_entries?per_page=20&page=1", [ 401, {"Content-Type": "application/json"}, JSON.stringify({other_error: "Something bad happened"}) ]
        callCount = 0
        base.data.loadCollection "time_entries", error: -> callCount += 1
        server.respond()
        expect(callCount).toEqual(1)

  describe "updating models", ->
    it "should use toServerJSON instead of toJSON", ->
      spyOn($, 'ajax')
      modelSpy = spyOn(Mavenlink.Model.prototype, 'toServerJSON')
      model = buildTimeEntry()
      model.save()
      expect(modelSpy).toHaveBeenCalled()
