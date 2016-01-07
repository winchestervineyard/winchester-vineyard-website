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

require 'httparty'

churchapp_headers = {"Content-type" => "application/json", "X-Account" => "winvin", "X-Application" => "Group Slideshow", "X-Auth" => ENV['CHURCHAPP_AUTH']}

get '/groups-list/?' do
  response = HTTParty.get('https://api.churchapp.co.uk/v1/smallgroups/groups?view=active', headers: churchapp_headers)
  @groups = JSON.parse(response.body)["groups"].map { |g| Group.new(g) }
  haml :groups_list, layout: nil
end

get '/groups-slideshow/?' do
  response = HTTParty.get('https://api.churchapp.co.uk/v1/smallgroups/groups?view=active', headers: churchapp_headers)
  @groups = JSON.parse(response.body)["groups"].map { |g| Group.new(g) }
  haml :groups, layout: nil
end

get '/groups-signup/?' do
  response = HTTParty.get('https://api.churchapp.co.uk/v1/addressbook/contacts?per_page=400', headers: churchapp_headers)
  @contacts = JSON.parse(response.body)["contacts"]

  response = HTTParty.get('https://api.churchapp.co.uk/v1/smallgroups/groups?view=active', headers: churchapp_headers)
  @groups = JSON.parse(response.body)["groups"].map { |g| Group.new(g) }

  haml :groups_signup, layout: nil
end

post '/groups-signup/:group_id/:contact_id' do |group_id, contact_id|
  body = {
    "action" => "add",
    "members" => {
      "contacts" => [ contact_id.to_i ],
    }
  }.to_json
  url = 'https://api.churchapp.co.uk/v1/smallgroups/group/'+group_id+'/members'
  puts body, url
  response = HTTParty.post(url, headers: churchapp_headers, body: body)
  puts response.body
  response.code
end

helpers do
  def secs_until(n)
    Time.parse(n['datetime']) - Time.now
  end
end

SECONDS_IN_A_DAY = 86400
SECONDS_IN_A_WEEK = 86400 * 7

get '/feed.xml' do
  require 'firebase'

  firebase = Firebase::Client.new('https://winvin.firebaseio.com/')
  all = firebase.get('news').body.values

  soon = all.select do |n|
    secs_until(n) >= 0 && secs_until(n) < SECONDS_IN_A_DAY
  end
  soon.each do |n|
    n['id'] += '-soon'
    n['pubDate'] = Time.parse(n['datetime']) - SECONDS_IN_A_DAY
  end

  upcoming = all.select do |n|
    secs_until(n) >= SECONDS_IN_A_DAY && secs_until(n) < SECONDS_IN_A_WEEK
  end
  upcoming.each do |n|
    n['id'] += '-upcoming'
    n['pubDate'] = Time.parse(n['datetime']) - SECONDS_IN_A_WEEK
  end

  @news = soon + upcoming

  builder :news
end

class Talk
  attr :full_name, :who, :date, :download_url, :slides_url, :id, :slug, :series_name

  def initialize(hash)
    @id = hash['id']
    @series_name = hash['series_name']
    @full_name = (hash['series_name'].present? ? "[" + hash['series_name'] + "] " : "" ) + hash['title']
    @who = hash['who']
    @date = Time.parse(hash['datetime'])
    @download_url = hash['download_url']
    @slides_url = hash['slides_url']
    @published = hash['published']
    @slug = hash['slug']
  end

  def part_of_a_series?
    @series_name.present?
  end

  def has_slides?
    @slides_url.present?
  end

  def long_title
    [
      @date.strftime("%a %d %b %Y"),
      ": ",
      @full_name,
      " (",
      @who,
      ")"
    ].join
  end

  def description
    "Given by #{@who} on #{@date.strftime("%a %d %b %y")}."
  end

  def published?
    !!@published
  end
end

Group = Struct.new(:hash) do
  def visible?
    hash["embed_visible"] == "1"
  end

  def id
    hash["id"]
  end

  def full?
    signup? && spaces <= 0
  end

  def signup?
    !!hash["signup_capacity"]
  end

  def image?
    !hash["images"].empty?
  end

  def location?
    !hash["location"].empty?
  end

  def first_sentence
    hash["description"].match(/^(.*?)[.?!]\s/)
  end

  def address
    hash["location"]["address"]
  end

  def image
    hash["images"]["square_500"]
  end

  def spaces
    if signup?
      hash["signup_capacity"].to_i - hash["no_members"].to_i
    end
  end

  def day
    if (hash["day"].nil?)
      "TBC"
    else
      %w(Sundays Mondays Tuesdays Wednesdays Thursdays Fridays Saturdays)[hash["day"].to_i]
    end
  end

  def time
    hash["time"]
  end

  def name
    hash["name"].sub(/\(.*201.\)/, '')
  end
end

get '/talks/:slug' do |slug|
  require 'firebase'
  firebase = Firebase::Client.new('https://winvin.firebaseio.com/')
  talk_id = firebase.get('talks-by-slug/' + slug ).body
  halt 404 if (talk_id.nil?)
  @talk = Talk.new(firebase.get('talks/' + talk_id).body)
  halt 404 unless @talk.published?
  @og_url = 'http://winvin.org.uk/talks/' + slug
  @og_title = "Winchester Vineyard Talk: #{@talk.full_name}"
  @og_description = @talk.description
  haml :talk
end

helpers do
  def get_talks
    require 'firebase'
    firebase = Firebase::Client.new('https://winvin.firebaseio.com/')
    firebase.get('talks').body.values.map {|t| Talk.new(t) }.sort_by(&:date).reverse
  end
end

get '/audio_plain' do
  @talks = get_talks
  haml :audio, :layout => false
end

get '/audio.xml' do
  @talks = get_talks
  builder :audio
end

get '/students/?' do
  haml :students
end

get '/lifegroups/?' do
  haml :lifegroups
end

get '/adventconspiracy/?' do
  haml :adventconspiracy
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

not_found do
  status 404
  haml :not_found
end

get('/feedback/?') { redirect 'https://docs.google.com/forms/d/10iS6tahkIYb_rFu1uNUB9ytjsy_xS138PJcs915qASo/viewform?usp=send_form' }

get('/data-protection-policy/?') { redirect 'https://s3-eu-west-1.amazonaws.com/winchester-vineyard-website-assets/uploads/data-protection-policy.pdf' }

get('/makingithappen/?') { redirect 'https://docs.google.com/forms/d/12LKbZo-FXRk5JAPESu_Zfog7FAtCXtdMAfdHCbQ8OXs/viewform?c=0&w=1' }
get('/requestasozo/?') { redirect 'https://docs.google.com/forms/d/16l71KEmGGhZar84lQIMpkcZuR6bVxlzGB8r0-cSni7s/viewform?fbzx=-1795998873449154632' }

get('/connect/?') { redirect 'https://docs.google.com/forms/d/1KuBo4sLPU9tcNpCbihhY_jydWgCCKpCdx7X35sLgmgg/viewform' }

get('/landing-banner-code/?') { redirect '/students' }
get('/kidstea/?') { redirect 'https://winvin.churchapp.co.uk/events/pl5wgmwz' }
get('/comedynight/?') { redirect 'https://winvin.churchapp.co.uk/events/yespcs01' }

get '/audio/?*' do
  redirect '/#wv-talks'
end

get('/events/?') { redirect '/#wv-news' }

run Sinatra::Application
