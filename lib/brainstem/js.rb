require "brainstem/js/version"
require "brainstem/js/engine" if defined?(::Rails::Engine)

module Brainstem
  module Js
    def self.path
      File.expand_path("../../../vendor/assets/javascripts", __FILE__)
    end
  end
end
