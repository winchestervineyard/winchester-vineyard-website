require 'sinatra'
require 'sass'
require 'builder'

require 'dalli'
require 'rack-cache'
require 'kgio'
require 'active_support/core_ext/time/calculations'

# Defined in ENV on Heroku. To try locally, start memcached and uncomment:
# ENV["MEMCACHE_SERVERS"] = "localhost"
if memcache_servers = ENV["MEMCACHE_SERVERS"]
  client = Dalli::Client.new(ENV["MEMCACHIER_SERVERS"],
                             :username => ENV["MEMCACHIER_USERNAME"],
                             :password => ENV["MEMCACHIER_PASSWORD"],
                             :failover => true,
                             :socket_timeout => 1.5,
                             :socket_failure_delay => 0.2,
                             :value_max_bytes => 10485760)
  use Rack::Cache,
    verbose: true,
    metastore:   client,
    entitystore: client

  # Flush the cache
  client.flush
end

set :static_cache_control, [:public, max_age: 1800]

before do
  cache_control :public, max_age: 1800  # 30 mins
end

require 'httparty'

CHURCHAPP_HEADERS = {"Content-type" => "application/json", "X-Account" => "winvin", "X-Application" => "Group Slideshow", "X-Auth" => ENV['CHURCHAPP_AUTH']}

require 'google_drive'

helpers do
  def protect!
    unless authorized?
      response['WWW-Authenticate'] = %(Basic realm="Restricted Area")
      throw(:halt, [401, "Not authorized\n"])
    end
  end
  def authorized?
    @auth ||=  Rack::Auth::Basic::Request.new(request.env)
    username = ENV['GROUPS_SIGNUP_USERNAME']
    password = ENV['GROUPS_SIGNUP_PASSWORD']
    @auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == [username, password]
  end
    
  def fetch_events(page)
    response = HTTParty.get("https://api.churchsuite.co.uk/v1/calendar/events?page=#{page}+featured=(1)", headers: CHURCHAPP_HEADERS)
    json = JSON.parse(response.body)
    if json["events"]
      json["events"].map { |e| Event.new(e) }
    else
      []
    end
  end
end

get '/' do
  events = (fetch_events(1) + fetch_events(2) + fetch_events(3)).uniq(&:start_time)
  @featured_events = events.select(&:featured?)
  @healing_events = events.select { |e| e.category == 'Healing' }
  @term = GroupTerm.new(Date.today)
  @talks = get_talks
  @hellobar = hellobar
  haml :index
end

get '/courses' do
  events = (fetch_events(1) + fetch_events(2) + fetch_events(3)).uniq(&:start_time)
  @courses_events = events.select { |e| e.category == 'Courses' }
  haml :courses
end

get '/groups-list/?' do
  response = HTTParty.get('https://api.churchsuite.co.uk/v1/smallgroups/groups?view=active', headers: CHURCHAPP_HEADERS)
  @groups = JSON.parse(response.body)["groups"].map { |g| Group.new(g) }
  haml :groups_list, layout: nil
end

get '/groups-slideshow/?' do
  response = HTTParty.get('https://api.churchsuite.co.uk/v1/smallgroups/groups?view=active', headers: CHURCHAPP_HEADERS)
  puts response.body
  @groups = JSON.parse(response.body)["groups"].map { |g| Group.new(g) }
  haml :groups, layout: nil
end


get '/groups-signup/?' do
  redirect 'https://winchester-vineyard.herokuapp.com/groups-signup' unless request.secure?
  protect!
  response = HTTParty.get('https://api.churchsuite.co.uk/v1/addressbook/contacts?per_page=400', headers: CHURCHAPP_HEADERS)
  @contacts = JSON.parse(response.body)["contacts"]

  response = HTTParty.get('https://api.churchsuite.co.uk/v1/smallgroups/groups?view=active', headers: CHURCHAPP_HEADERS)
  @groups = JSON.parse(response.body)["groups"].map { |g| Group.new(g) }

  haml :groups_signup, layout: nil
end

post '/groups-signup/:group_id/:contact_id' do |group_id, contact_id|
  halt 426 unless request.secure?
  body = {
    "action" => "add",
    "members" => {
      "contacts" => [ contact_id.to_i ],
    }
  }.to_json
  url = 'https://api.churchsuite.co.uk/v1/smallgroups/group/'+group_id+'/members'
  puts body, url
  response = HTTParty.post(url, headers: CHURCHAPP_HEADERS, body: body)
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

class GroupTerm
  DATA = {
    spring: {
      name: "Spring",
      signup_month: "January",
      start_month: "February",
      end_month: "April"
    },
    summer: {
      name: "Summer",
      signup_month: "May",
      start_month: "June",
      end_month: "August"
    },
    autumn: {
      name: "Autumn",
      signup_month: "September",
      start_month: "October",
      end_month: "December"
    }
  }
  def initialize(date)
    @date = date
    @term = case @date.month
    when 1..4
      :spring
    when 5..8
      :summer
    else
      :autumn
    end
  end

  def next
    GroupTerm.new(@date.advance(months: 4))
  end

  def signup_month?
    [1, 5, 9].include? @date.month
  end

  def name; DATA[@term][:name]; end
  def signup_month; DATA[@term][:signup_month]; end
  def start_month; DATA[@term][:start_month]; end
  def end_month; DATA[@term][:end_month]; end
end

class Talk
  attr :full_name, :who, :date, :download_url, :slides_url, :slug, :series_name, :title

  def initialize(hash)
    @series_name = hash['Series']
    @full_name = (!hash['Series'].blank? ? "[" + hash['Series'] + "] " : "" ) + hash['Title']
    @who = hash['Speaker(s)']
    @date = Time.parse(hash['Date'])
    @download_url = hash['Talk URL']
    @slides_url = hash['Slides URL']
    @slug = hash['Slug']
    @title = hash['Title']
  end

  def id
    @slug
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
    true
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
    hash["description"].match(/^(.*?)[.!]\s?/)
  end

  def address
    hash["location"]["address"]
  end

  def image
    hash["images"]["original_500"]
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

Event = Struct.new(:hash) do
  def description
    re = /<div[^>]*>|<\/div>/
    hash["description"].gsub(re, '').match(/^(((.*?)[.?!]){3}|(.*))/)
  end
  def featured?
    hash["signup_options"]["public"]["featured"] == "1"
  end

  def category
    hash["category"]["name"]
  end

  def name
    hash["name"]
  end

  def can_signup?
    hash["signup_options"]["tickets"]["enabled"] == "1"
  end

  def ticket_url
    hash["signup_options"]["tickets"]["url"]
  end

  def image?
    !hash["images"].empty?
  end

  def image_url
    hash["images"]["original_500"]
  end

  def start_time
    Time.parse(hash["datetime_start"])
  end

  def start_date
    start_time.midnight
  end

  def end_time
    Time.parse(hash["datetime_end"])
  end

  def end_date
    end_time.midnight
  end

  def end_date_string
    end_date.strftime("%d %b")
  end

  def start_date_string
    start_date.strftime("%d %b")
  end

  def start_time_string
    start_time.strftime("%H:%M")
  end

  def end_time_string
    end_time.strftime("%H:%M")
  end

  def full_date_string
    if self.start_date != self.end_date
      "#{self.start_date_string} - #{self.end_date_string}"
    else
      "#{self.start_date_string} #{self.start_time_string} - #{self.end_time_string}"
    end
  end

  def location?
    hash["location"].size > 0
  end

  def location_url
    "http://maps.google.co.uk/?q=" + hash["location"]["address"] rescue nil
  end

  def location_title
    hash["location"]["name"]
  end
end

get '/talks/:slug' do |slug|
  talk_row = talks.select { |t| t["Slug"] == slug }
  halt 404 if (talk_row.nil? or talk_row["Date"].empty?)
  @talk = Talk.new(talk_row)
  @og_url = 'http://winvin.org.uk/talks/' + slug
  @og_title = "Winchester Vineyard Talk: #{@talk.full_name}"
  @og_description = @talk.description
  haml :talk
end

helpers do
  def sheet
    session = GoogleDrive::Session.from_service_account_key(ENV["GOOGLE_API_SECRET"] ? StringIO.new(ENV["GOOGLE_API_SECRET"]) : "secret.json")
    session.spreadsheet_by_key("1B9G8efynCzeWsHBoHAJeJRpO00AdrzaAZQaS50QCwXI")
  end

  def hellobar
    worksheet = sheet.worksheet_by_sheet_id(0)
    [worksheet[1, 2], worksheet[2, 2]]
  end

  def talks
    sheet.worksheet_by_sheet_id("1813659711").list
  end

  def get_talks
    talks.
      select {|t| t["Date"].present? }.
      map { |t| Talk.new(t) }.
      sort_by(&:date).
      reverse
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

get '/welcome/?' do
  @talks = get_talks.select(&:published?).select {|t| t.series_name == "What on earth is the Vineyard" }
  haml :welcome
end

get '/buildingforthefuture/?' do
  @talks = get_talks.select(&:published?).select {|t| t.series_name == "Building for the future" }
  haml :building
end

get '/mydata/?' do
  haml :mydata
end

get '/courses/?' do
  haml :courses
end

get('/bethelsozo/?') do
  haml :sozo
end

get '/lifegroups/?' do
  @term = GroupTerm.new(Date.today)
  haml :lifegroups
end

get '/adventconspiracy/?' do
  haml :adventconspiracy
end

get '/donate/?' do
  haml :donate
end

get '/dy/?' do
  haml :dy
end

get '/storehouse/?' do
  haml :storehouse
end

get '/yobl/?' do
  @talks = get_talks.select(&:published?).select {|t| t.series_name == "Year of Biblical Literacy" }
  haml :yobl
end

get '/givehope/?' do
  events = (1..4).reduce([]) { |memo, x| memo + fetch_events(x) }
  @christmas_events = events.select { |e| e.category == 'Christmas' }
  haml :givehope
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


get '/audio/?*' do
  redirect '/#wv-talks'
end

get('/survey/?') { redirect 'https://docs.google.com/forms/d/e/1FAIpQLScpGATm9QhMj1Qsm46-ISbAecbbQx2s3XsXbpz-1Ki3sAS8qw/viewform?' + request.query_string }
get('/mystory/?') { redirect 'https://goo.gl/forms/TlkzGBBkzctP1azp2' }
get('/groupsslideshow/?') { redirect '/groups-slideshow/' }
get('/feedback/?') { redirect 'https://docs.google.com/forms/d/10iS6tahkIYb_rFu1uNUB9ytjsy_xS138PJcs915qASo/viewform?usp=send_form' }
get('/data-protection-policy/?') { redirect 'https://s3-eu-west-1.amazonaws.com/winchester-vineyard-website-assets/uploads/data-protection-policy.pdf' }
get('/makingithappen/?') { redirect 'https://docs.google.com/forms/d/12LKbZo-FXRk5JAPESu_Zfog7FAtCXtdMAfdHCbQ8OXs/viewform?c=0&w=1' }
get('/connect/?') { redirect '/welcome' }
get('/landing-banner-code/?') { redirect '/students' }
get('/find-us/?') { redirect '/#wv-find-us' }
get('/globalpartners/?') { redirect 'https://winvin.churchsuite.co.uk/donate/fund/0sfturgn' }
get('/focus-on-kids/?') { redirect 'https://winchester-vineyard-website-assets.s3.amazonaws.com/assets/Focus%20on%20Kids%20and%20Youth%20Vision.pdf' }
get('/whatson/?') { redirect '/#wv-news' }
get('/compassion/?') { redirect '/#wv-compassion' }
get('/healing/?') { redirect '/#wv-healing' }
get('/missions/?') { redirect 'https://drive.google.com/file/d/1L0hBqZDUXfOuVkA8maERoBZGE2qKL8Ji/view' }


# Redirect Events
get('/destinyactivator/?') { redirect 'https://winvin.churchsuite.co.uk/events/lvgzikzj' }
get('/reset/?') { redirect 'https://winvin.churchsuite.co.uk/events/6huru7lc' }
get('/alpha/?') { redirect 'https://winvin.churchsuite.co.uk/events/juc5yyeq' }
get('/dna/?') { redirect 'https://winvin.churchsuite.co.uk/events/xt3ipa6x' }
get('/dtidonate/?') { redirect 'https://winvin.churchsuite.co.uk/donate/fund/afc9ezmg' }
get('/lggl/?') { redirect 'https://winvin.churchsuite.co.uk/events/zdqmm234' }
get('/dadsgroup/?') { redirect 'https://winvin.churchsuite.co.uk/events/5kb8ci1g' }
get('/breakthrough/?') { redirect 'https://winvin.churchsuite.co.uk/events/fkfjjukg' }
get('/worship/?') { redirect 'https://winvin.churchsuite.co.uk/events/1viau2gi' }
get('/scatteredservants/?') { redirect 'https://winvin.churchsuite.co.uk/events/0bzjr20p' }
get('/regionalworship/?') { redirect 'https://winvin.churchsuite.co.uk/events/ag2pvw28' }
get('/sozotraining/?') { redirect 'https://winvin.churchsuite.co.uk/events/squ6fpcj' }
get('/mindfulness/?') { redirect 'https://winvin.churchsuite.co.uk/events/ggf9rzml' }
get('/reach/?') { redirect 'https://winvin.churchsuite.co.uk/events/rrqeumey' }
get('/hunger/?') { redirect 'https://winvin.churchsuite.co.uk/events/pdmeqdxn' }
get('/comedynight/?') { redirect 'https://winvin.churchsuite.co.uk/events/kzd3shlq' }
get('/leadership/?') { redirect 'https://winvin.churchsuite.co.uk/events/jxkyfbcf' }
get('/deeper/?') { redirect 'https://winvin.churchsuite.co.uk/events/nhzazfdq' }
get('/datenight/?') { redirect 'https://winvin.churchsuite.co.uk/events/0drrferu' }

run Sinatra::Application

