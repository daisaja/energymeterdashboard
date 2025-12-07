require 'httparty'

class WeatherClient
  @@last_values = {}

  # Rathenow, Brandenburg
  LATITUDE = 52.6048
  LONGITUDE = 12.3370

  OPEN_METEO_URL = "https://api.open-meteo.com/v1/forecast"

  attr_reader :temperature, :weather_code, :wind_speed, :weather_description, :weather_icon

  def initialize
    fetch_weather_data
  end

  def fetch_weather_data
    response = HTTParty.get(OPEN_METEO_URL, query: {
      latitude: LATITUDE,
      longitude: LONGITUDE,
      current: 'temperature_2m,weather_code,wind_speed_10m',
      timezone: 'Europe/Berlin'
    })

    current = response.parsed_response['current']
    @temperature = current['temperature_2m'].round(1)
    @weather_code = current['weather_code']
    @wind_speed = current['wind_speed_10m'].round(1)
    @weather_description, @weather_icon = weather_code_to_description(@weather_code)
    save_values
  rescue Errno::EHOSTUNREACH, Errno::ECONNREFUSED => e
    puts "[Weather] Verbindung zu Open-Meteo API fehlgeschlagen: Server nicht erreichbar"
    restore_last_values
  rescue => e
    puts "[Weather] Fehler: #{e.message}"
    restore_last_values
  end

  def save_values
    @@last_values = {
      temperature: @temperature,
      weather_code: @weather_code,
      wind_speed: @wind_speed,
      weather_description: @weather_description,
      weather_icon: @weather_icon
    }
  end

  def restore_last_values
    @temperature = @@last_values[:temperature] || 0.0
    @weather_code = @@last_values[:weather_code] || 0
    @wind_speed = @@last_values[:wind_speed] || 0.0
    @weather_description = @@last_values[:weather_description] || 'Keine Daten'
    @weather_icon = @@last_values[:weather_icon] || '?'
  end

  def weather_code_to_description(code)
    case code
    when 0 then ['Klar', '☀']
    when 1, 2, 3 then ['Teilweise bewölkt', '⛅']
    when 45, 48 then ['Nebel', '☁']
    when 51, 53, 55 then ['Nieselregen', '☂']
    when 61, 63, 65 then ['Regen', '☂']
    when 66, 67 then ['Gefrierender Regen', '☂']
    when 71, 73, 75 then ['Schnee', '❄']
    when 77 then ['Schneekörner', '❄']
    when 80, 81, 82 then ['Regenschauer', '☔']
    when 85, 86 then ['Schneeschauer', '❄']
    when 95 then ['Gewitter', '⚡']
    when 96, 99 then ['Gewitter mit Hagel', '⚡']
    else ['Unbekannt', '?']
    end
  end
end

if defined?(SCHEDULER)
  SCHEDULER.every '10m', first_in: 0 do
    weather = WeatherClient.new

    send_event('weather_temperature', {
      current: weather.temperature,
      icon: weather.weather_icon,
      moreinfo: "#{weather.weather_description}, Wind: #{weather.wind_speed} km/h"
    })
  end
end
