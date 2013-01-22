require 'rake-pipeline'
require 'rake-pipeline/middleware'

use Rake::Pipeline::Middleware, Rake::Pipeline::Project.new("Assetfile")

use Rack::Static, :root => File.expand_path('../build', __FILE__),
  :index => 'index.html', :urls => ["/"]

run lambda{ |env| [ 404, { 'Content-Type'  => 'text/html' }, ['not found'] ] }