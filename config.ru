require 'sinatra'
require 'sass'
require 'builder'

require 'dalli'
require 'rack-cache'
require 'kgio'
require 'active_support/core_ext/time/calculations'

# Defined in ENV on Heroku. To try locally, start memcached and uncomment:
# ENV["MEMCACHE_SERVERS"] = "localhost"
if memcache_servers = ENV["MEMCACHIER_SERVERS"]
  client = Dalli::Client.new((ENV["MEMCACHIER_SERVERS"] || "").split(","),
                      {:username => ENV["MEMCACHIER_USERNAME"],
                       :password => ENV["MEMCACHIER_PASSWORD"],
                       :failover => true,            # default is true
                       :socket_timeout => 1.5,       # default is 0.5
                       :socket_failure_delay => 0.2, # default is 0.01
                       :down_retry_delay => 60       # default is 60
  })
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
    response = HTTParty.get("https://api.churchsuite.co.uk/v1/calendar/events?page=#{page}", headers: CHURCHAPP_HEADERS)
    json = JSON.parse(response.body)
    if json["events"]
      json["events"].map { |e| Event.new(e) }
    else
      []
    end
  end
end

get %r{/(.*)} do
  path =  params['captures'].first
  redirect "https://winchestervineyard.org/#{path}"
end

run Sinatra::Application
