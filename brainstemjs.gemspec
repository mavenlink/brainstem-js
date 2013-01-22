# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'brainstemjs/version'

Gem::Specification.new do |gem|
  gem.name          = "brainstemjs"
  gem.version       = Brainstemjs::VERSION
  gem.authors       = ["André Arko", "Reid Gillette"]
  gem.email         = ["dev@mavenlink.com"]
  gem.description   = %q{The Brainstem storage manager JS library}
  gem.summary       = %q{Brainstem's JS components}
  gem.homepage      = "http://github.com/mavenlink/brainstemjs"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
  
  gem.add_development_dependency "bundler"
  gem.add_development_dependency "rake"
end
