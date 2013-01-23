# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'brainstem/js/version'

Gem::Specification.new do |gem|
  gem.name          = "brainstem-js"
  gem.version       = Brainstem::Js::VERSION
  gem.authors       = ["André Arko", "Reid Gillette"]
  gem.email         = ["dev@mavenlink.com"]
  gem.description   = %q{The Brainstem storage manager JS library}
  gem.summary       = %q{Brainstem's JS components}
  gem.homepage      = "http://github.com/mavenlink/brainstem-js"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_development_dependency 'bundler', '~> 1.2'
  gem.add_development_dependency 'coffee-script', '~> 2.2'
  gem.add_development_dependency 'jasmine-core', '~> 1.3.1'
  gem.add_development_dependency 'rake-pipeline-web-filters', '~> 0.6.0'
end
