require_relative 'test_helper'
require_relative '../jobs/weather'

class WeatherTest < Minitest::Test
  OPEN_METEO_API_REGEX = /api\.open-meteo\.com\/v1\/forecast/

  def setup
    WebMock.disable_net_connect!
  end

  def weather_response(current_temp: 18.5, current_code: 3, wind: 12.3)
    {
      'current' => {
        'temperature_2m' => current_temp,
        'weather_code'   => current_code,
        'wind_speed_10m' => wind
      },
      'daily' => {
        'time'              => ['2025-12-10', '2025-12-11', '2025-12-12'],
        'weather_code'      => [current_code, 61, 0],
        'temperature_2m_max' => [10.0, 8.0, 12.0],
        'temperature_2m_min' => [2.0,  1.0,  3.0]
      }
    }
  end

  def stub_weather(body)
    stub_request(:get, OPEN_METEO_API_REGEX)
      .to_return(status: 200, body: body.to_json, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })
  end

  def test_weather_client_basic_values
    stub_weather(weather_response)

    weather = WeatherClient.new
    assert_equal(18.5,              weather.temperature)
    assert_equal(3,                 weather.weather_code)
    assert_equal(12.3,              weather.wind_speed)
    assert_equal('Teilweise bewölkt', weather.weather_description)
    assert_equal('⛅',              weather.weather_icon)
    assert_equal(26,                weather.climacon_code)
  end

  def test_weather_forecast
    stub_weather(weather_response)

    weather = WeatherClient.new
    assert_equal('1° - 8°',   weather.forecast1)
    assert_equal(12,           weather.forecast1_climacon)
    assert_equal('Donnerstag', weather.forecast1_day)
    assert_equal('3° - 12°',  weather.forecast2)
    assert_equal(32,           weather.forecast2_climacon)
    assert_equal('Freitag',   weather.forecast2_day)
  end

  def test_weather_client_error_handling
    WeatherClient.class_variable_set(:@@last_values, {})
    stub_request(:get, OPEN_METEO_API_REGEX).to_raise(Errno::ECONNREFUSED)

    weather = WeatherClient.new
    assert_equal(0.0,         weather.temperature)
    assert_equal(0,           weather.weather_code)
    assert_equal(0.0,         weather.wind_speed)
    assert_equal('Keine Daten', weather.weather_description)
    assert_equal('?',         weather.weather_icon)
    assert_equal(32,          weather.climacon_code)
    assert_equal('-',         weather.forecast1)
    assert_equal('-',         weather.forecast1_day)
  end

  def test_weather_client_keeps_last_values_on_error
    stub_weather(weather_response)

    weather = WeatherClient.new
    assert_equal(18.5, weather.temperature)

    WebMock.reset!
    stub_request(:get, OPEN_METEO_API_REGEX).to_raise(Errno::ECONNREFUSED)

    weather2 = WeatherClient.new
    assert_equal(18.5,              weather2.temperature)
    assert_equal(3,                 weather2.weather_code)
    assert_equal(12.3,              weather2.wind_speed)
    assert_equal('Teilweise bewölkt', weather2.weather_description)
    assert_equal('⛅',              weather2.weather_icon)
    assert_equal(26,                weather2.climacon_code)
    assert_equal('1° - 8°',        weather2.forecast1)
    assert_equal('Donnerstag',      weather2.forecast1_day)
  end

  def test_weather_code_snow
    stub_weather(weather_response(current_temp: 5.0, current_code: 71, wind: 8.0))

    weather = WeatherClient.new
    assert_equal('Schnee', weather.weather_description)
    assert_equal('❄',     weather.weather_icon)
    assert_equal(16,       weather.climacon_code)
  end

  def test_weather_code_clear_sky
    stub_weather(weather_response(current_temp: 25.0, current_code: 0, wind: 5.0))

    weather = WeatherClient.new
    assert_equal('Klar', weather.weather_description)
    assert_equal('☀',   weather.weather_icon)
    assert_equal(32,     weather.climacon_code)
  end

  def test_weather_code_rain
    stub_weather(weather_response(current_temp: 12.0, current_code: 61, wind: 15.0))

    weather = WeatherClient.new
    assert_equal('Regen', weather.weather_description)
    assert_equal('☂',    weather.weather_icon)
    assert_equal(12,      weather.climacon_code)
  end

  def test_weather_code_thunderstorm
    stub_weather(weather_response(current_temp: 18.0, current_code: 95, wind: 25.0))

    weather = WeatherClient.new
    assert_equal('Gewitter', weather.weather_description)
    assert_equal('⚡',       weather.weather_icon)
    assert_equal(6,          weather.climacon_code)
  end

  def test_weather_code_unknown
    stub_weather(weather_response(current_temp: 10.0, current_code: 999, wind: 10.0))

    weather = WeatherClient.new
    assert_equal('Unbekannt', weather.weather_description)
    assert_equal('?',         weather.weather_icon)
    assert_equal(32,          weather.climacon_code)
  end

  def test_weather_temperature_rounding
    stub_weather(weather_response(current_temp: 18.567, current_code: 1, wind: 12.345))

    weather = WeatherClient.new
    assert_equal(18.6, weather.temperature)
    assert_equal(12.3, weather.wind_speed)
  end
end
