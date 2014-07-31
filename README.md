# Brainstem.js

[![Build Status](https://travis-ci.org/mavenlink/brainstem-js.png)](https://travis-ci.org/mavenlink/brainstem-js)

[Brainstem](https://github.com/mavenlink/brainstem) is designed to power rich APIs in Rails. The Brainstem gem provides a presenter library that handles converting ActiveRecord objects into structured JSON and a set of API abstractions that allow users to request sorts, filters, and association loads, allowing for simpler implementations, fewer requests, and smaller responses.

The Brainstem.js library is a companion library for Backbone.js that makes integration with Brainstem APIs a breeze.  Brainstem.js adds an identity map and relational models to Backbone.

## Why Brainstem.js?

* Speaks natively to Brainstem APIs
* Adds relational models in Backbone, allowing you to setup has_one, has_many, and belongs_to relationships.
* Provides an Identity Map to avoid loading already-available records.
* Supports Brainstem side-loading of multiple objects for fast, single-request workflows.
* Interprets the Brainstem results array and hashes for you, abstracting away the JSON protocol.
* Written in CoffeeScript.

## Usage

If you're in Rails, just add `brainstem-js` to your Gemfile and require `brainstem` in `application.js`.

We have a [comprehensive demo available](https://github.com/mavenlink/brainstem-demo-rails).  We recommend that you start there.

What follows is an overview.

### StorageManager

The `Brainstem.StorageManager` is in charge of loading data over the API, as well as returning already cached data.  We recommend setting one up in a singleton App class.

	class Application
	  constructor: ->
	    @data = new Brainstem.StorageManager()
	    @data.addCollection 'widgets', Collections.Widgets
	    @data.addCollection 'locations', Collections.Locations
	    @data.addCollection 'features', Collections.Features
	    @homeRouter = new Routers.WidgetsRouter()
	
	$ ->
	  window.base = new Application()
	  Backbone.history.start(root: "/")

At the moment, the global StorageManager *must* be available at `window.base.data`.  For this reason, we recommend making a singleton instance of an `Application` class for holding your `StorageManager` and any other shared resources.

### Brainstem.Models and Brainstem.Collections

Once you have a StorageManager, you should setup some `Brainstem.Models` and `Brainstem.Collections`:

	window.Models ?= {}
	window.Collections ?= {}
	
	class Models.Widget extends Brainstem.Model
	  paramRoot: 'widget'
	  brainstemKey: 'widgets'
	  urlRoot: '/api/v1/widgets'
	
	  @associations:
	    features: ["features"] # Has many
	    location: "locations" # Belongs to
	    parent: ["sprocket", "widget"] # Belongs to (polymorphic)
	
	class Collections.Widgets extends Brainstem.Collection
	  model: Models.Widget
	  url: '/api/v1/widgets'
	
	class Models.Feature extends Brainstem.Model
	  paramRoot: 'feature'
	  brainstemKey: 'features'
	  urlRoot: '/api/v1/features'
	
	  @associations:
	    widgets: ["widgets"]
	
	class Collections.Features extends Brainstem.Collection
	  model: Models.Feature
	  url: '/api/v1/features'

Use the `@associations` class method to declare the mapping between association names and `StorageManager` collections where the data can be located.  Arrays indicate has_many relationships.  Other than a few additions, these are just Backbone Models and Collections.

### Backbone.Views

Now that you have models, collections, and a `StorageManager`, it's time to load some data (probably in Backbone.Views).  For example:

	class Views.Widgets.IndexView extends Backbone.View
	  template: JST["backbone/templates/widgets/index"]
	
	  initialize: ->
	    @collection = base.data.loadCollection "widgets", include: ["location", "features"], order: 'updated_at:desc'
	    @collection.bind 'reset', @addAll
	    @collection.bind 'remove', @addAll
	
	  render: =>
	    @$el.html @template()
	
	    if @collection.loaded
	      @addAll()
	    else
	      @$("#widgets-list").text "Just a moment..."
	
	    return this
	
	  addAll: =>
	    @$("#widgets-list").empty()
	    @collection.each(@addOne)
	    @addLocations()
	
	  addOne: (model) =>
	    view = new Views.Widgets.WidgetView(model: model)
	    @$("#widgets-list").append view.render().el

And finally, in your templates, you can access the relational data just like you'd normally access model data in Backbone.

    @model.get('location').get('name')
    
    for feature in @model.get('features').models:
    
Etc.

## Development

We're always open to pull requests!

### Dependencies

  - PhantomJS. If you're on OS X, run `brew install phantomjs`.

### Running Specs

To run the specs on the command line, run:

    bundle exec rake

To run the specs in a server with live code reloading and compilation:

    bundle exec rake server

To develop your application against a local checkout of brainstem-js, we suggest using Bundler's local gems:

    bundle config local.brainstem-js ~/workspace/brainstem-js

And when you're done, run:

    bundle config --delete local.brainstem-js
    
# License

Brainstem and Brainstem.js were created by Mavenlink, Inc. and are available under the MIT License.
