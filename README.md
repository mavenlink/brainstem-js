# Brainstem.js

Some code to load your data into some other code.

## Dependencies

  - PhantomJS. If you're on OS X, run `brew install phantomjs`.

## Development

To run the specs on the command line, run:

    bundle exec rake

To run the specs in a server with live code reloading and compilation:

    bundle exec rake server

To develop your application  against a local checkout of brainstem-js, run:

    bundle config local.brainstem-js ~/workspace/brainstem-js

When you're done, run:

    bundle config --delete local.brainstem-js
