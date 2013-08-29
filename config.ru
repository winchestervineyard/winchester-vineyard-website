require 'sinatra'
require 'sass'

get '/' do
  haml :index
end

get '/css/styles.css' do
  scss :styles, :style => :expanded
end

run Sinatra::Application
