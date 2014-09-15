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

get '/admin/?' do
  @uploader = ImageUploader.new
  @uploader.success_action_redirect = request.url
  haml :admin
end

get '/css/styles.css' do
  scss :styles, :style => :expanded
end

run Sinatra::Application
