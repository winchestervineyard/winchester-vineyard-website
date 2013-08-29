require 'sinatra'

get '/' do
  haml :index
end

run Sinatra::Application
