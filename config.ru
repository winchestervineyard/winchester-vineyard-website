require 'sinatra'
require 'sass'
require 'builder'

require 'carrierwave_direct'
require 'dalli'
require 'rack-cache'
#
# Defined in ENV on Heroku. To try locally, start memcached and uncomment:
# ENV["MEMCACHE_SERVERS"] = "localhost"
if memcache_servers = ENV["MEMCACHE_SERVERS"]
  use Rack::Cache,
    verbose: true,
    metastore:   "memcached://#{memcache_servers}",
    entitystore: "memcached://#{memcache_servers}"

  # Flush the cache
  Dalli::Client.new.flush
end

set :static_cache_control, [:public, max_age: 1800]

before do
  cache_control :public, max_age: 1800  # 30 mins
end

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

helpers do
  def talk_title(talk)
    [
      Time.parse(talk['datetime']).strftime("%a %d %b %Y"),
      ": ",
      talk['series_name'].present? ? talk['series_name'] + " - " : "",
      talk['title'],
      " (",
      talk['who'],
      ")"
    ].join
  end
end

get '/audio.xml' do
  require 'firebase'
  firebase = Firebase::Client.new('https://winvin.firebaseio.com/')
  @talks = firebase.get('talks').body.values
  @talks.sort_by! {|t| Time.parse(t['datetime'])}.reverse!
  builder :audio
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
