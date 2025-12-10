require 'httparty'

class WeatherClient
  @@last_values = {}

  # Rathenow, Brandenburg
  LATITUDE = 52.6048
  LONGITUDE = 12.3370

  OPEN_METEO_URL = "https://api.open-meteo.com/v1/forecast"

  attr_reader :temperature, :weather_code, :wind_speed, :weather_description, :weather_icon, :climacon_code,
              :forecast1, :forecast1_climacon, :forecast1_day,
              :forecast2, :forecast2_climacon, :forecast2_day

  GERMAN_WEEK_DAYS = {
    'Monday' => 'Montag', 'Tuesday' => 'Dienstag', 'Wednesday' => 'Mittwoch',
    'Thursday' => 'Donnerstag', 'Friday' => 'Freitag', 'Saturday' => 'Samstag', 'Sunday' => 'Sonntag'
  }

  def initialize
    fetch_weather_data
  end

  def fetch_weather_data
    response = HTTParty.get(OPEN_METEO_URL, query: {
      latitude: LATITUDE,
      longitude: LONGITUDE,
      current: 'temperature_2m,weather_code,wind_speed_10m',
      daily: 'weather_code,temperature_2m_max,temperature_2m_min',
      forecast_days: 3,
      timezone: 'Europe/Berlin'
    })

    data = response.parsed_response
    current = data['current']
    @temperature = current['temperature_2m'].round(1)
    @weather_code = current['weather_code']
    @wind_speed = current['wind_speed_10m'].round(1)
    @weather_description, @weather_icon = weather_code_to_description(@weather_code)
    @climacon_code = weather_code_to_climacon(@weather_code)

    # Forecast für morgen und übermorgen (Index 1 und 2, Index 0 ist heute)
    daily = data['daily']
    @forecast1 = "#{daily['temperature_2m_min'][1].round}° - #{daily['temperature_2m_max'][1].round}°"
    @forecast1_climacon = weather_code_to_climacon(daily['weather_code'][1])
    @forecast1_day = german_weekday(daily['time'][1])

    @forecast2 = "#{daily['temperature_2m_min'][2].round}° - #{daily['temperature_2m_max'][2].round}°"
    @forecast2_climacon = weather_code_to_climacon(daily['weather_code'][2])
    @forecast2_day = german_weekday(daily['time'][2])

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
      weather_icon: @weather_icon,
      climacon_code: @climacon_code,
      forecast1: @forecast1,
      forecast1_climacon: @forecast1_climacon,
      forecast1_day: @forecast1_day,
      forecast2: @forecast2,
      forecast2_climacon: @forecast2_climacon,
      forecast2_day: @forecast2_day
    }
  end

  def restore_last_values
    @temperature = @@last_values[:temperature] || 0.0
    @weather_code = @@last_values[:weather_code] || 0
    @wind_speed = @@last_values[:wind_speed] || 0.0
    @weather_description = @@last_values[:weather_description] || 'Keine Daten'
    @weather_icon = @@last_values[:weather_icon] || '?'
    @climacon_code = @@last_values[:climacon_code] || 32
    @forecast1 = @@last_values[:forecast1] || '-'
    @forecast1_climacon = @@last_values[:forecast1_climacon] || 32
    @forecast1_day = @@last_values[:forecast1_day] || '-'
    @forecast2 = @@last_values[:forecast2] || '-'
    @forecast2_climacon = @@last_values[:forecast2_climacon] || 32
    @forecast2_day = @@last_values[:forecast2_day] || '-'
  end

  def german_weekday(date_string)
    date = Date.parse(date_string)
    GERMAN_WEEK_DAYS[date.strftime('%A')]
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

  def weather_code_to_climacon(code)
    case code
    when 0 then 32                # Klar -> Sonne
    when 1, 2, 3 then 26          # Teilweise bewölkt -> Wolke mit Sonne
    when 45, 48 then 20           # Nebel
    when 51, 53, 55 then 9        # Nieselregen
    when 61, 63, 65 then 12       # Regen
    when 66, 67 then 18           # Gefrierender Regen
    when 71, 73, 75 then 16       # Schnee
    when 77 then 17               # Schneekörner
    when 80, 81, 82 then 11       # Regenschauer
    when 85, 86 then 16           # Schneeschauer
    when 95 then 6                # Gewitter
    when 96, 99 then 6            # Gewitter mit Hagel
    else 32                       # Fallback: Sonne
    end
  end
end

if defined?(SCHEDULER)
  SCHEDULER.every '10m', first_in: 0 do
    weather = WeatherClient.new

    send_event('weather_temperature', {
      current: weather.temperature,
      icon: weather.weather_icon,
      climacon_code: weather.climacon_code,
      moreinfo: "#{weather.weather_description}, Wind: #{weather.wind_speed} km/h",
      forecast1: weather.forecast1,
      forecast1_climacon: weather.forecast1_climacon,
      forecast1_day: weather.forecast1_day,
      forecast2: weather.forecast2,
      forecast2_climacon: weather.forecast2_climacon,
      forecast2_day: weather.forecast2_day
    })
  end
end
