require 'rubygems'
require 'sinatra'
Dir['./lib/*.rb'].each { |path| require path }

require File.expand_path '../manifest-server.rb', __FILE__

if ENV["RACK_ENV"] && ENV["RACK_ENV"] == "production"
    run Sinatra::Application
else
    # to properly run the internal webserver
    run Sinatra::Application.run!
end
