# Brainstem.js

Brainstem is a Ruby library designed to power rich APIs in Rails or Sinatra. The Brainstem gem provides a framework for converting
ActiveRecord objects into structured JSON, complete with user-requested sorts, filters,
and association loads.  The Brainstem.js library is a companion library for Backbone.js that makes integration with Brainstem APIs a breeze.

## Usage






## Development

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
