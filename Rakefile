begin
  require 'jasmine'
  require File.expand_path("../spec/support/jasmine_config.rb", __FILE__)
  load 'jasmine/tasks/jasmine.rake'
  load 'jasmine-phantom/tasks.rake'
rescue LoadError => e
  puts e.message
  abort "You didn't run bundle install, did you?"
end

task :spec do
  begin
    Rake::Task["jasmine:phantom:ci"].invoke
  rescue Errno::ENOENT => e
    puts "Couldn't find phantomjs."
    abort "You didn't run `brew install phantomjs`, did you?"
  end
end

task :default => :spec