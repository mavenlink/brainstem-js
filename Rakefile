begin
  require 'jasmine'
  require File.expand_path("../spec/support/jasmine_config.rb", __FILE__)
  load 'jasmine/tasks/jasmine.rake'
rescue LoadError
  task :jasmine do
    abort "Jasmine is not available. Run `bundle install`."
  end
end

begin
  load 'jasmine-phantom/tasks.rake'
rescue LoadError
  namespace :jasmine do
    namespace :phantom do
      task :ci do
        abort "Jasmine-phantom is not available. Run `bundle install`."
      end
    end
  end
end

task :spec => "jasmine:phantom:ci"
task :default => :spec