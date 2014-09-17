require 'sinatra'
require 'sass'

require 'carrierwave_direct'

CarrierWave.configure do |config|
  config.fog_credentials = {
    :provider               => 'AWS',
    :aws_access_key_id      => ENV['AWS_ACCESS_KEY_ID'],
    :aws_secret_access_key  => ENV['AWS_SECRET_ACCESS_KEY']
  }
  config.fog_directory  = ENV['AWS_FOG_DIRECTORY'] # bucket name
end

class ImageUploader < CarrierWave::Uploader::Base
  include CarrierWaveDirect::Uploader
end

get '/' do
  haml :index
end

get '/students/?' do
  haml :students
end

get '/css/styles.css' do
  scss :styles, :style => :expanded
end

get('/node/168/?') { redirect '/#wv-news' }
get('/node/2/?') { redirect '/#wv-sundays' }
get('/node/319/?') { redirect '/#wv-team' }
get('/node/74/?') { redirect '/#wv-growing' }

get '/node/?*' do
  redirect '/'
end

get('/feedback/?') { redirect 'https://docs.google.com/forms/d/10iS6tahkIYb_rFu1uNUB9ytjsy_xS138PJcs915qASo/viewform?usp=send_form' }

get('/landing-banner-code/?') { redirect '/students' }

get '/audio/?*' do
  redirect '/#wv-talks'
end

run Sinatra::Application
