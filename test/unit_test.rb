require 'simplecov'
SimpleCov.start do
  add_filter '/test/'
end

require 'minitest/autorun'
require 'webmock/minitest'

# Set test environment variables before loading application code
ENV['GRID_METER_HOST'] = '192.168.178.103'
ENV['OPENDTU_HOST'] = '192.168.1.100'
ENV['HEATING_METER_HOST'] = '192.168.178.50'
ENV['SOLAR_METER_HOST'] = '192.168.178.60'
ENV['INFLUXDB_HOST'] = '192.168.178.70'
ENV['INFLUXDB_TOKEN'] = 'test-token'

require_relative '../jobs/meter_helper/grid_meter_client'
require_relative '../jobs/meter_helper/opendtu_meter_client'
require_relative '../jobs/meter_helper/heating_meter_client'
require_relative '../jobs/meter_helper/solar_meter_client'
require_relative '../jobs/weather'
require_relative '../jobs/influx_exporter'

class UnitTest < Minitest::Test
  # Test constants to avoid duplication
  CONTENT_TYPE_JSON = 'Content-Type'
  APPLICATION_JSON = 'application/json'
  OPEN_METEO_API_REGEX = /api\.open-meteo\.com\/v1\/forecast/
  SOLAR_METER_URL = 'https://192.168.178.60/dyn/getDashValues.json'

  def setup
    # Disable real HTTP requests and enable webmock
    WebMock.disable_net_connect!
  end

  def test_grid_meter_client
    # E320 via SML: 3 Kanäle, Zählerstände in Wh, Momentanleistung in W (vorzeichenbehaftet)
    # Positiver 16.7.0-Wert → Bezug, kein Einspeisung
    grid_meter_response = {
      'data' => [
        {
          'uuid' => '11755f30-0e65-11f1-a7d4-cfd94d2fa168',  # UUID_GRID_FEED_TOTAL
          'tuples' => [[1234567890000, 12345000]]              # 12345000 Wh = 12345.0 kWh
        },
        {
          'uuid' => 'e52fc000-0e64-11f1-b37f-4db1c53870b5',  # UUID_GRID_SUPPLY_TOTAL
          'tuples' => [[1234567890000, 8765000]]               # 8765000 Wh = 8765.0 kWh
        },
        {
          'uuid' => '2c58c270-0e65-11f1-8833-19d9403165de',  # UUID_GRID_SUPPLY_CURRENT (16.7.0 signed)
          'tuples' => [[1234567890000, 1200]]                  # 1200 W = 1.2 kW, positiv = Bezug
        }
      ]
    }

    stub_request(:get, "http://192.168.178.103:8081/")
      .to_return(status: 200, body: grid_meter_response.to_json, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })

    grid_measures = GridMeasurements.new()
    assert_equal(12345.0, grid_measures.grid_feed_total)
    assert_equal(0.0,     grid_measures.grid_feed_per_month)   # nicht mehr vom Zähler geliefert
    assert_equal(0.0,     grid_measures.grid_feed_current)     # kein Einspeisung bei positivem Wert
    assert_equal(8765.0,  grid_measures.grid_supply_total)
    assert_equal(0.0,     grid_measures.grid_supply_per_month) # nicht mehr vom Zähler geliefert
    assert_equal(1.2,     grid_measures.grid_supply_current)
  end

  def test_grid_meter_client_feed_current_with_negative_power
    # Negativer 16.7.0-Wert → Einspeisung, kein Bezug
    grid_meter_response = {
      'data' => [
        { 'uuid' => '11755f30-0e65-11f1-a7d4-cfd94d2fa168', 'tuples' => [[1234567890000, 0]] },
        { 'uuid' => 'e52fc000-0e64-11f1-b37f-4db1c53870b5', 'tuples' => [[1234567890000, 0]] },
        {
          'uuid' => '2c58c270-0e65-11f1-8833-19d9403165de',  # 16.7.0 signed
          'tuples' => [[1234567890000, -2500]]                # -2500 W = 2.5 kW Einspeisung
        }
      ]
    }

    stub_request(:get, "http://192.168.178.103:8081/")
      .to_return(status: 200, body: grid_meter_response.to_json, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })

    grid_measures = GridMeasurements.new()
    assert_equal(2.5, grid_measures.grid_feed_current)
    assert_equal(0.0, grid_measures.grid_supply_current)
  end

  def test_grid_meter_client_missing_tuples
    # 16.7.0 ohne tuples-Array (E320 Momentanleistung noch nicht im erweiterten Modus)
    grid_meter_response = {
      'data' => [
        { 'uuid' => 'e52fc000-0e64-11f1-b37f-4db1c53870b5', 'tuples' => [[1234567890000, 526000]] },
        { 'uuid' => '11755f30-0e65-11f1-a7d4-cfd94d2fa168', 'tuples' => [[1234567890000, 0]] },
        { 'uuid' => '2c58c270-0e65-11f1-8833-19d9403165de', 'last' => 0, 'interval' => -1 }
      ]
    }

    stub_request(:get, "http://192.168.178.103:8081/")
      .to_return(status: 200, body: grid_meter_response.to_json, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })

    grid_measures = GridMeasurements.new()
    assert_equal(526.0, grid_measures.grid_supply_total)
    assert_equal(0.0,   grid_measures.grid_supply_current)  # kein Absturz bei fehlendem tuples
    assert_equal(0.0,   grid_measures.grid_feed_current)
  end

  def test_grid_meter_client_connection_refused_first_time
    GridMeasurements.class_variable_set(:@@last_values, {})
    stub_request(:get, "http://192.168.178.103:8081/")
      .to_raise(Errno::ECONNREFUSED)

    grid_measures = GridMeasurements.new
    assert_equal(0.0, grid_measures.grid_feed_current)
    assert_equal(0.0, grid_measures.grid_feed_total)
    assert_equal(0.0, grid_measures.grid_supply_current)
    assert_equal(0.0, grid_measures.grid_supply_total)
  end

  def test_grid_meter_client_host_unreachable_first_time
    GridMeasurements.class_variable_set(:@@last_values, {})
    stub_request(:get, "http://192.168.178.103:8081/")
      .to_raise(Errno::EHOSTUNREACH)

    grid_measures = GridMeasurements.new
    assert_equal(0.0, grid_measures.grid_feed_current)
    assert_equal(0.0, grid_measures.grid_feed_total)
    assert_equal(0.0, grid_measures.grid_supply_current)
    assert_equal(0.0, grid_measures.grid_supply_total)
  end

  def test_grid_meter_client_keeps_last_values_on_error
    # First successful request: negativer 16.7.0-Wert → Einspeisung
    grid_meter_response = {
      'data' => [
        { 'uuid' => '11755f30-0e65-11f1-a7d4-cfd94d2fa168', 'tuples' => [[1234567890000, 12345000]] },
        { 'uuid' => 'e52fc000-0e64-11f1-b37f-4db1c53870b5', 'tuples' => [[1234567890000, 8765000]] },
        { 'uuid' => '2c58c270-0e65-11f1-8833-19d9403165de', 'tuples' => [[1234567890000, -2500]] }
      ]
    }

    stub_request(:get, "http://192.168.178.103:8081/")
      .to_return(status: 200, body: grid_meter_response.to_json, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })

    grid_measures = GridMeasurements.new
    assert_equal(2.5, grid_measures.grid_feed_current)

    # Second request fails - should keep old values
    WebMock.reset!
    stub_request(:get, "http://192.168.178.103:8081/")
      .to_raise(Errno::ECONNREFUSED)

    grid_measures2 = GridMeasurements.new
    assert_equal(2.5,     grid_measures2.grid_feed_current)
    assert_equal(12345.0, grid_measures2.grid_feed_total)
  end

  def test_opendtu_meter_client
    # Mock the OpenDTU API response
    opendtu_response = {
      'total' => {
        'Power' => { 'v' => 2450.5 },
        'YieldDay' => { 'v' => 12.5 },
        'YieldTotal' => { 'v' => 1463.25 }
      }
    }

    stub_request(:get, "http://192.168.1.100:80/api/livedata/status")
      .to_return(status: 200, body: opendtu_response.to_json, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })

    opendtu_measures = OpenDTUMeterClient.new()
    assert_equal(2451.0, opendtu_measures.power_watts)
    assert_equal(13.0, opendtu_measures.yield_day)  # 12.5.round(0) = 13
    assert_equal(1463.0, opendtu_measures.yield_total)
  end

  def test_opendtu_meter_client_error_handling
    OpenDTUMeterClient.class_variable_set(:@@last_values, {})
    # Mock OpenDTU being unavailable
    stub_request(:get, "http://192.168.1.100:80/api/livedata/status")
      .to_raise(Errno::ECONNREFUSED)

    opendtu_measures = OpenDTUMeterClient.new()
    assert_equal(0.0, opendtu_measures.power_watts)
    assert_equal(0.0, opendtu_measures.yield_day)
    assert_equal(0.0, opendtu_measures.yield_total)
  end

  def test_opendtu_meter_client_keeps_last_values_on_error
    opendtu_response = {
      'total' => {
        'Power' => { 'v' => 2450.5 },
        'YieldDay' => { 'v' => 12.5 },
        'YieldTotal' => { 'v' => 1463.25 }
      }
    }

    stub_request(:get, "http://192.168.1.100:80/api/livedata/status")
      .to_return(status: 200, body: opendtu_response.to_json, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })

    opendtu = OpenDTUMeterClient.new
    assert_equal(2451.0, opendtu.power_watts)

    # Second request fails - should keep old values
    WebMock.reset!
    stub_request(:get, "http://192.168.1.100:80/api/livedata/status")
      .to_raise(Errno::ECONNREFUSED)

    opendtu2 = OpenDTUMeterClient.new
    assert_equal(2451.0, opendtu2.power_watts)
    assert_equal(13.0, opendtu2.yield_day)
    assert_equal(1463.0, opendtu2.yield_total)
  end

  # WeatherClient Tests
  def weather_response_with_forecast(current_temp: 18.5, current_code: 3, wind: 12.3)
    {
      'current' => {
        'temperature_2m' => current_temp,
        'weather_code' => current_code,
        'wind_speed_10m' => wind
      },
      'daily' => {
        'time' => ['2025-12-10', '2025-12-11', '2025-12-12'],
        'weather_code' => [current_code, 61, 0],
        'temperature_2m_max' => [10.0, 8.0, 12.0],
        'temperature_2m_min' => [2.0, 1.0, 3.0]
      }
    }
  end

  def test_weather_client
    stub_request(:get, OPEN_METEO_API_REGEX)
      .to_return(status: 200, body: weather_response_with_forecast.to_json, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })

    weather = WeatherClient.new
    assert_equal(18.5, weather.temperature)
    assert_equal(3, weather.weather_code)
    assert_equal(12.3, weather.wind_speed)
    assert_equal('Teilweise bewölkt', weather.weather_description)
    assert_equal('⛅', weather.weather_icon)
    assert_equal(26, weather.climacon_code)
  end

  def test_weather_forecast
    stub_request(:get, OPEN_METEO_API_REGEX)
      .to_return(status: 200, body: weather_response_with_forecast.to_json, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })

    weather = WeatherClient.new
    assert_equal('1° - 8°', weather.forecast1)
    assert_equal(12, weather.forecast1_climacon)
    assert_equal('Donnerstag', weather.forecast1_day)
    assert_equal('3° - 12°', weather.forecast2)
    assert_equal(32, weather.forecast2_climacon)
    assert_equal('Freitag', weather.forecast2_day)
  end

  def test_weather_client_error_handling
    WeatherClient.class_variable_set(:@@last_values, {})
    stub_request(:get, OPEN_METEO_API_REGEX)
      .to_raise(Errno::ECONNREFUSED)

    weather = WeatherClient.new
    assert_equal(0.0, weather.temperature)
    assert_equal(0, weather.weather_code)
    assert_equal(0.0, weather.wind_speed)
    assert_equal('Keine Daten', weather.weather_description)
    assert_equal('?', weather.weather_icon)
    assert_equal(32, weather.climacon_code)
    assert_equal('-', weather.forecast1)
    assert_equal('-', weather.forecast1_day)
  end

  def test_weather_client_keeps_last_values_on_error
    stub_request(:get, OPEN_METEO_API_REGEX)
      .to_return(status: 200, body: weather_response_with_forecast.to_json, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })

    weather = WeatherClient.new
    assert_equal(18.5, weather.temperature)

    # Second request fails - should keep old values
    WebMock.reset!
    stub_request(:get, OPEN_METEO_API_REGEX)
      .to_raise(Errno::ECONNREFUSED)

    weather2 = WeatherClient.new
    assert_equal(18.5, weather2.temperature)
    assert_equal(3, weather2.weather_code)
    assert_equal(12.3, weather2.wind_speed)
    assert_equal('Teilweise bewölkt', weather2.weather_description)
    assert_equal('⛅', weather2.weather_icon)
    assert_equal(26, weather2.climacon_code)
    assert_equal('1° - 8°', weather2.forecast1)
    assert_equal('Donnerstag', weather2.forecast1_day)
  end

  def test_weather_code_descriptions
    stub_request(:get, OPEN_METEO_API_REGEX)
      .to_return(status: 200, body: weather_response_with_forecast(current_temp: 5.0, current_code: 71, wind: 8.0).to_json, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })

    weather = WeatherClient.new
    assert_equal('Schnee', weather.weather_description)
    assert_equal('❄', weather.weather_icon)
    assert_equal(16, weather.climacon_code)
  end

  def test_weather_code_clear_sky
    stub_request(:get, OPEN_METEO_API_REGEX)
      .to_return(status: 200, body: weather_response_with_forecast(current_temp: 25.0, current_code: 0, wind: 5.0).to_json, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })

    weather = WeatherClient.new
    assert_equal('Klar', weather.weather_description)
    assert_equal('☀', weather.weather_icon)
    assert_equal(32, weather.climacon_code)
  end

  def test_weather_code_rain
    stub_request(:get, OPEN_METEO_API_REGEX)
      .to_return(status: 200, body: weather_response_with_forecast(current_temp: 12.0, current_code: 61, wind: 15.0).to_json, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })

    weather = WeatherClient.new
    assert_equal('Regen', weather.weather_description)
    assert_equal('☂', weather.weather_icon)
    assert_equal(12, weather.climacon_code)
  end

  def test_weather_code_thunderstorm
    stub_request(:get, OPEN_METEO_API_REGEX)
      .to_return(status: 200, body: weather_response_with_forecast(current_temp: 18.0, current_code: 95, wind: 25.0).to_json, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })

    weather = WeatherClient.new
    assert_equal('Gewitter', weather.weather_description)
    assert_equal('⚡', weather.weather_icon)
    assert_equal(6, weather.climacon_code)
  end

  def test_weather_code_unknown
    stub_request(:get, OPEN_METEO_API_REGEX)
      .to_return(status: 200, body: weather_response_with_forecast(current_temp: 10.0, current_code: 999, wind: 10.0).to_json, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })

    weather = WeatherClient.new
    assert_equal('Unbekannt', weather.weather_description)
    assert_equal('?', weather.weather_icon)
    assert_equal(32, weather.climacon_code)
  end

  def test_weather_temperature_rounding
    response = weather_response_with_forecast(current_temp: 18.567, current_code: 1, wind: 12.345)
    stub_request(:get, OPEN_METEO_API_REGEX)
      .to_return(status: 200, body: response.to_json, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })

    weather = WeatherClient.new
    assert_equal(18.6, weather.temperature)
    assert_equal(12.3, weather.wind_speed)
  end

  # HeatingMeasurements Tests
  def test_heating_meter_client
    heating_response = {
      'pwr' => 1500
    }
    
    month_response = {
      'val' => [10, 15, 20, 25]
    }
    
    day_response = {
      'val' => [100, 200, 300, 400]
    }

    stub_request(:get, "http://192.168.178.50/a?f=j")
      .to_return(status: 200, body: heating_response.to_json, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })
    
    stub_request(:get, %r{http://192\.168\.178\.50/V\?\?f=j&m=\d+})
      .to_return(status: 200, body: month_response.to_json, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })
    
    stub_request(:get, "http://192.168.178.50/V?d=0&f=j")
      .to_return(status: 200, body: day_response.to_json, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })
    
    stub_request(:get, "http://192.168.178.50/V?d=1&f=j")
      .to_return(status: 200, body: day_response.to_json, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })

    heating = HeatingMeasurements.new
    assert_equal(1500, heating.heating_watts_current)
    assert_equal(70.0, heating.heating_per_month)
    assert_equal(1, heating.heating_kwh_current_day)
    assert_equal(1, heating.heating_kwh_last_day)
  end

  def test_heating_meter_client_error_handling
    HeatingMeasurements.class_variable_set(:@@last_values, {})
    stub_request(:get, "http://192.168.178.50/a?f=j")
      .to_raise(Errno::ECONNREFUSED)

    stub_request(:get, %r{http://192\.168\.178\.50/V\?\?f=j&m=\d+})
      .to_raise(Errno::ECONNREFUSED)

    stub_request(:get, "http://192.168.178.50/V?d=0&f=j")
      .to_raise(Errno::ECONNREFUSED)

    stub_request(:get, "http://192.168.178.50/V?d=1&f=j")
      .to_raise(Errno::ECONNREFUSED)

    heating = HeatingMeasurements.new
    assert_equal(0.0, heating.heating_watts_current)
    assert_equal(0.0, heating.heating_per_month)
    assert_equal(0.0, heating.heating_kwh_current_day)
    assert_equal(0.0, heating.heating_kwh_last_day)
  end

  def test_heating_meter_client_host_unreachable
    HeatingMeasurements.class_variable_set(:@@last_values, {})
    stub_request(:get, "http://192.168.178.50/a?f=j")
      .to_raise(Errno::EHOSTUNREACH)

    heating = HeatingMeasurements.new
    assert_equal(0.0, heating.heating_watts_current)
    assert_equal(0.0, heating.heating_per_month)
    assert_equal(0.0, heating.heating_kwh_current_day)
    assert_equal(0.0, heating.heating_kwh_last_day)
  end

  def test_heating_meter_client_keeps_last_values_on_error
    heating_response = { 'pwr' => 1500 }
    month_response = { 'val' => [10, 15, 20, 25] }
    day_response = { 'val' => [100, 200, 300, 400] }

    stub_request(:get, "http://192.168.178.50/a?f=j")
      .to_return(status: 200, body: heating_response.to_json, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })
    stub_request(:get, %r{http://192\.168\.178\.50/V\?\?f=j&m=\d+})
      .to_return(status: 200, body: month_response.to_json, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })
    stub_request(:get, "http://192.168.178.50/V?d=0&f=j")
      .to_return(status: 200, body: day_response.to_json, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })
    stub_request(:get, "http://192.168.178.50/V?d=1&f=j")
      .to_return(status: 200, body: day_response.to_json, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })

    heating = HeatingMeasurements.new
    assert_equal(1500, heating.heating_watts_current)

    # Second request fails - should keep old values
    WebMock.reset!
    stub_request(:get, "http://192.168.178.50/a?f=j")
      .to_raise(Errno::ECONNREFUSED)

    heating2 = HeatingMeasurements.new
    assert_equal(1500, heating2.heating_watts_current)
    assert_equal(70.0, heating2.heating_per_month)
    assert_equal(1, heating2.heating_kwh_current_day)
    assert_equal(1, heating2.heating_kwh_last_day)
  end

  # SolarMeasurements Tests
  def test_solar_meter_client
    solar_response = {
      'result' => {
        '017A-B339126F' => {
          '6100_40263F00' => {
            '1' => [{ 'val' => 3500 }]
          }
        }
      }
    }

    stub_request(:post, SOLAR_METER_URL)
      .to_return(status: 200, body: solar_response.to_json, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })

    solar = SolarMeasurements.new
    assert_equal(3500, solar.solar_watts_current)
    assert_equal(0.0, solar.solar_watts_per_month)
  end

  def test_solar_meter_client_fallback
    solar_response = {
      'result' => {
        '017A-xxxxx26F' => {
          '6100_40263F00' => {
            '1' => [{ 'val' => 2500 }]
          }
        }
      }
    }

    stub_request(:post, SOLAR_METER_URL)
      .to_return(status: 200, body: solar_response.to_json, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })

    solar = SolarMeasurements.new
    assert_equal(2500, solar.solar_watts_current)
  end

  def test_solar_meter_client_nil_value
    solar_response = {
      'result' => {
        '017A-B339126F' => {
          '6100_40263F00' => {
            '1' => [{ 'val' => nil }]
          }
        }
      }
    }

    stub_request(:post, SOLAR_METER_URL)
      .to_return(status: 200, body: solar_response.to_json, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })

    solar = SolarMeasurements.new
    assert_equal(0.0, solar.solar_watts_current)
  end

  def test_solar_meter_client_error_handling
    SolarMeasurements.class_variable_set(:@@last_values, {})
    stub_request(:post, SOLAR_METER_URL)
      .to_raise(Errno::ECONNREFUSED)

    solar = SolarMeasurements.new
    assert_equal(0.0, solar.solar_watts_current)
    assert_equal(0.0, solar.solar_watts_per_month)
  end

  def test_solar_meter_client_host_unreachable
    SolarMeasurements.class_variable_set(:@@last_values, {})
    stub_request(:post, SOLAR_METER_URL)
      .to_raise(Errno::EHOSTUNREACH)

    solar = SolarMeasurements.new
    assert_equal(0.0, solar.solar_watts_current)
    assert_equal(0.0, solar.solar_watts_per_month)
  end

  def test_solar_meter_client_keeps_last_values_on_error
    solar_response = {
      'result' => {
        '017A-B339126F' => {
          '6100_40263F00' => {
            '1' => [{ 'val' => 3500 }]
          }
        }
      }
    }

    stub_request(:post, SOLAR_METER_URL)
      .to_return(status: 200, body: solar_response.to_json, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })

    solar = SolarMeasurements.new
    assert_equal(3500, solar.solar_watts_current)

    # Second request fails - should keep old values
    WebMock.reset!
    stub_request(:post, SOLAR_METER_URL)
      .to_raise(Errno::ECONNREFUSED)

    solar2 = SolarMeasurements.new
    assert_equal(3500, solar2.solar_watts_current)
    assert_equal(0.0, solar2.solar_watts_per_month)
  end

  # InfluxExporter Tests
  def test_influx_exporter_initialization
    exporter = InfluxExporter.new
    refute_nil(exporter.influx_client)
  end

  # is_new_day helper function tests
  def test_is_new_day_at_midnight
    assert_equal(true, is_new_day(Time.new(2024, 1, 15, 0, 5, 0)))
  end

  def test_is_new_day_during_day
    assert_equal(false, is_new_day(Time.new(2024, 1, 15, 12, 0, 0)))
  end

  def test_is_new_day_after_window
    # 11 Minuten nach Mitternacht = außerhalb des 600s-Fensters
    assert_equal(false, is_new_day(Time.new(2024, 1, 15, 0, 11, 0)))
  end

  # is_new_month helper function tests
  def test_is_new_month_at_start_of_month
    assert_equal(true, is_new_month(Time.new(2024, 2, 1, 0, 5, 0)))
  end

  def test_is_new_month_mid_month
    assert_equal(false, is_new_month(Time.new(2024, 2, 15, 12, 0, 0)))
  end

  def test_is_new_month_after_window
    # 11 Minuten nach Monatsbeginn = außerhalb des 600s-Fensters
    assert_equal(false, is_new_month(Time.new(2024, 2, 1, 0, 11, 0)))
  end

end
