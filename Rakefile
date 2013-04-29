#!/usr/bin/env rake
require "bundler/gem_tasks"

task :clean do
  sh "rakep clean"
end

task :build do
  sh "rakep build"
end

task :spec => :build do
  begin
    exec *%w(phantomjs build/headless.js build/headless.html)
  rescue Errno::ENOENT => e
    puts "Couldn't find phantomjs."
    abort "You didn't run `brew install phantomjs`, did you?"
  end
end

task :server => :clean do
  exec "rakep server"
end

task :default => :spec
