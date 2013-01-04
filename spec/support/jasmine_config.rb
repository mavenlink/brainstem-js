# Overwrite hardcoded configuration file location
module Jasmine
  class Config
    def simple_config_file
      File.join(project_root, 'spec/support/jasmine.yml')
    end
  end
end
