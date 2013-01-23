require "brainstemjs/version"
require "brainstemjs/engine" if defined?(::Rails::Engine)

module Brainstemjs
  def self.path
    File.expand_path("../../src", __FILE__)
  end
end
