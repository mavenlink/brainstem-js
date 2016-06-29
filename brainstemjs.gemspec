# encoding: utf-8

lib = File.expand_path('../lib', __FILE__)

$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'brainstem/js/version'

Gem::Specification.new do |gem|
  gem.name          = 'brainstem-js'
  gem.version       = Brainstem::Js::VERSION
  gem.authors       = ['Mavenlink']
  gem.email         = ['opensource@mavenlink.com']
  gem.description   = 'The Brainstem API adapter library for Backbone.js'
  gem.summary       = 'Easily connect Backbone.js with Brainstem APIs.  Get relational models in Backbone.'
  gem.homepage      = 'http://github.com/mavenlink/brainstem-js'

  gem.files         = `git ls-files`.split($/)
  gem.require_paths = ['lib']
end
