require 'net/http'
require "json"
require "date"
require "net/https"
require 'openssl'
require "erb"

# WOEID for location:
# http://woeid.rosselliot.co.nz
woeid  = 686990

# Units for temperature:
# f: Fahrenheit
# c: Celsius
format = "c"

#yahoo app id
appid = ENV['EM_APP_ID']
consumerKey = ENV['EM_CONSUMER_KEY']
consumerSecret = ENV['EM_CONSUMER_SECRET']

url = URI::encode "https://weather-ydn-yql.media.yahoo.com/forecastrss";

query  = URI::encode "?woeid=#{woeid}&format=json&u=#{format}"

def query_string(params)
  pairs = []
  params.sort.each { | key, val |
    pairs.push( "#{  key  }=#{  val.to_s  }" )
  }
  pairs.join '&'
end

SCHEDULER.every "15m", :first_in => 0 do |job|

  #nonce = OpenSSL::Random.random_bytes 2
  nonce = Array.new( 5 ) { rand(256) }.pack('C*').unpack('H*').first
  timestamp = Time.now.to_i

   #params = URI::encode "format=json&oauth_consumer_key=#{consumerKey}&oauth_nonce=#{nonce}&oauth_signature_method=HMAC-SHA1&oauth_timestamp=#{timestamp}&oauth_version=1.0&woeid=#{woeid}"
  params = {
    'format' => 'json',
    'oauth_consumer_key' => consumerKey,
    'oauth_nonce' => nonce,
    'oauth_signature_method' => 'HMAC-SHA1',
    'oauth_timestamp' => timestamp,
    'oauth_version' => '1.0',
	'woeid' => woeid,
	'u' => format
  }

  parameterString = query_string(params)


  signature = "GET&#{ERB::Util.url_encode(url)}&" + ERB::Util.url_encode(parameterString)

  oauth_signature = Base64.encode64("#{OpenSSL::HMAC.digest('sha1',"#{consumerSecret}&", signature)}").chomp.gsub( /\n/, '')

  authorizationLine = "OAuth oauth_consumer_key=\"#{consumerKey}\", oauth_nonce=\"#{nonce}\", oauth_timestamp=\"#{timestamp}\", oauth_signature_method=\"HMAC-SHA1\", oauth_signature=\"#{oauth_signature}\", oauth_version=\"1.0\""

  http = Net::HTTP.new("weather-ydn-yql.media.yahoo.com", 443)
  http.use_ssl = true

  req = Net::HTTP::Get.new("/forecastrss#{query}" , {"Content-Type" => "application/json", "X-Yahoo-App-Id" => appid, "Authorization" => authorizationLine})


  response = http.request(req)

  json = JSON.parse response.body
  results = json

  german_week_days = { "MON" => "Montag", "TUE" => "Dienstag", "WED" => "Mittwoch", "THU"  => "Donnerstag", "FRI" => "Freitag", "SAT" => "Samstag", "SUN" => "Sonntag" }

  if results
    # General
    location  = results["location"]
    # Today
    today = results["current_observation"]["condition"]
    # Forecast
    forecast = results["forecasts"]
    send_event "klimato", { location: location["city"], temperature: today["temperature"], code: today["code"], format: format,
    forecast1: forecast[1]["low"].to_s+"\u00b0 - "+forecast[1]["high"].to_s+"\u00b0", forecast1Icon: forecast[1]["code"], forecast1day: german_week_days[forecast[1]["day"].upcase],
    forecast2: forecast[2]["low"].to_s+"\u00b0 - "+forecast[2]["high"].to_s+"\u00b0", forecast2Icon: forecast[2]["code"], forecast2day: german_week_days[forecast[2]["day"].upcase]}
  end
end
