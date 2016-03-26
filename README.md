# Brainstem.js

[![Gitter](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/mavenlink/brainstem-js?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge) [![Build Status](https://travis-ci.org/mavenlink/brainstem-js.png)](https://travis-ci.org/mavenlink/brainstem-js)

[Brainstem](https://github.com/mavenlink/brainstem) is designed to power rich APIs in Rails. The Brainstem gem provides a presenter library that handles converting ActiveRecord objects into structured JSON and a set of API abstractions that allow users to request sorts, filters, and association loads, allowing for simpler implementations, fewer requests, and smaller responses.

**Brainstem.js** is a companion library for [Backbone.js](http://backbonejs.org/) that makes integration with Brainstem APIs a breeze.  Brainstem.js adds an identity map and relational models to Backbone.

### Why Brainstem.js?

* Speaks natively to [Brainstem](https://github.com/mavenlink/brainstem) APIs
* Provides a caching layer to avoid loading already-available records
* Adds relational models in Backbone, allowing you to setup `has_one`, `has_many`, and `belongs_to` relationships
* Supports Brainstem association side-loading of multiple objects for fast, single-request workflows
* Interprets the Brainstem server API results array and hashes for you, abstracting away the Brainstem JSON protocol


## Installation

### NPM

`npm install --save brainstem-js`

### Bundler (Rails)

Add Brainstem.js to your `Gemfile`:

`gem 'brainstem-js`

Require using Sprockets directive:

`//= require brainstem-js`

### Script Tag

`<script type="text/javascript" src="vendor/javascripts/brainstem.js"></script>`


## Usage

### Models and Collections

Brainstem.js models and collections behave very similarly to Backbone models and collections. However, in Brainstem.js models have the ability to specify associations that map to other Brainstem models in the StorageManager. These associations leverage the power of the Brainstem server API to facilitate side-loading related data in a single `fetch`.

Sub-class Brainstem.js collections and models for each Brainstem server endpoint to map client-side models to your Brainstem server-side models.

### Model associations

Assocations are defined as a map in the class property **associations** to declare the mapping between association names and `StorageManager` collections where the data can be located.

- **Strings** inidicate `has_one` or `belongs_to` relationships
- **Arrays** with a single item indicate `has_many` relationships
- **Arrays** with *multiple items* indecate polymorphic `belongs_to` relationships


#### Examples

##### CommonJS

Model:

```javascript
BrainstemModel = require('brainstem/model');

Post = BrainstemModel.extend({
  paramRoot: 'post',
  brainstemKey: 'posts',
  urlRoot: '/api/v1/posts'
}, {
  associations: {
    user: 'users', # has_one
    comments: ['comments'], # has_many
    account: 'accounts', # belongs_to
    parent: ['category', 'post'] # belongs_to (polymorphic)
  }
});

module.exports = Post;
```
Collection:

```javascript
BrainstemCollection = require('brainstem/collection');
Post = require('./models/post');

Posts = BrainstemCollection.extend({
  model: Post,
  url: '/api/v1/posts'
});

module.exports = Posts;
```

##### Vanilla JavaScript

Model:

```javascript
Application.Models.Post = Brainstem.Model.extend({
  paramRoot: 'post',
  brainstemKey: 'posts',
  urlRoot: '/api/v1/posts'
}, {
  associations: {
    user: 'users', # has_one
    comments: ['comments'], # has_many
    account: 'accounts', # belongs_to
    parent: ['category', 'post'] # belongs_to (polymorphic)
  }
});
```

Collection:

```javascript
Application.Collections.Posts = Brainstem.Collection.extend({
  model: Application.Models.Post,
  url: '/api/v1/posts'
});
```

-

### StorageManager

The Brainstem.js `StorageManager` is the data store in charge of loading data from a Brainstem API, as well as managing cached data. The StorageManager should be set up when your application starts.

Use the StorageManager `addCollection` API to register Brainstem.js collections that map to your Brainstem server API endpoints.

```javascript
storageManager.addCollection([brainstem key], [collection class])
```
*Note: The StorageManager is implemented as a singleton. The StorageManager instance can be obtained using `StorageManager.get()`. Once instantiated the manager instance will maintain state and cache throughout the duration of your application's runtime.*

#### Examples

##### CommonJS

```javascript
StorageManager = require('brainstem/storage-manager');
Users = require('./collections/users);
Posts = require('./collections/posts);
Comments = require('./collections/comments);

storageManger = StorageManager.get();
storageManager.addCollection('users', Users);
storageManager.addCollection('posts', Posts);
storageManager.addCollection('comments', Comments);
```

##### Vanilla JavaScript

```javascript
Application = {};

Application.storageManager = StorageManager.get();
Application.storageManager.addCollection('users', Application.Collections.Users);
Application.storageManager.addCollection('posts', Application.Collections.Posts);
Application.storageManager.addCollection('comments', Application.Collections.Comments);
```

-

### Fetching data

Brainstem.js extends the Backbone `fetch` API so requesting data from a Brainstem API should be familiar to fetching data from any RESTful API using just Backbone.

### Models

In addition to basic REST requests, the Brainstem.js model `fetch` method supports an `include` option to side-load associated model data.

#### Examples

##### CommonJS

```javascript
Post = require('./models/post');

new Post({ id: 1 }).fetch({ include: ['user', 'comments'] })
  .done(/* handle result */)
  .fail(/* handle error */);
```

##### Vanilla JavaScript

```javascript
new Application.Models.Post({ id: 1 }).fetch({ include: ['user', 'comments'] })
  .done(/* handle result */)
  .fail(/* handle error */);
```

### Collections

In addition to basic REST requests, the Brainstem.js model `fetch` method supports additional Brainstem options:

- Pagination using `page` and `perPage`, or `offset` and `limit`
- Filtering using `filters` object
- Ordering user `order` string

#### Examples

##### CommonJS

```javascript
Posts = require('./collections/posts');

new Posts().fetch({
  page: 1,
  perPage: 10,
  order: 'date:desc',
  filters: {
    title: 'collections',
    description: 'fetching'
 })
}).done(/* handle result */)
  .fail(/* handle error */);
```

##### Vanilla JavaScript

```javascript
new Application.Collections.Posts().fetch({
  page: 1,
  perPage: 10,
  order: 'date:desc',
  filters: {
    title: 'collections',
    description: 'fetching'
  })
}).done(/* handle result */)
  .fail(/* handle error */);
```
-

### Accessing Model Associations

```javascript
// TODO: examples
```

-

### Manipulating Collections

```javascript
// TODO: examples
```
-

### View Integration

```javascript
// TODO: examples
```

## Development

We're always open to pull requests!

### Dependencies

  - [Node](https://nodejs.org/en/)
  - [Gulp](http://gulpjs.com/)
  - [Google Chrome](https://www.google.com/chrome/browser/desktop/)

### Development Environment

    npm install -g gulp
    npm install

### Running Specs

To run the specs on the command line, run:

    gulp test

To run the specs in a server with live code reloading and compilation:

    gulp test-watch
    
## License

Brainstem and Brainstem.js were created by Mavenlink, Inc. and are available under the MIT License.
