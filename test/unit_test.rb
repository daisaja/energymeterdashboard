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
    # Mock the Grid Meter API response
    grid_meter_response = {
      'data' => [
        {
          'uuid' => 'aface870-4a00-11ea-aa3c-8f09c95f5b9c',
          'tuples' => [[1234567890000, 2500]]
        },
        {
          'uuid' => 'e564e6e0-4a00-11ea-af71-a55e127a0bfc',
          'tuples' => [[1234567890000, 12345]]
        },
        {
          'uuid' => '0185bb38-769c-401f-9372-b89d615c9920',
          'tuples' => [[1234567890000, 542]]
        },
        {
          'uuid' => '007aeef0-4a01-11ea-8773-6bda87ed0b9a',
          'tuples' => [[1234567890000, 8765]]
        },
        {
          'uuid' => '472573b2-a888-4851-ada9-ffd8cd386001',
          'tuples' => [[1234567890000, 234]]
        },
        {
          'uuid' => 'c6ada300-4a00-11ea-99d0-7577b1612d91',
          'tuples' => [[1234567890000, 1200]]
        }
      ]
    }

    stub_request(:get, "http://192.168.178.103:8081/")
      .to_return(status: 200, body: grid_meter_response.to_json, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })

    grid_measures = GridMeasurements.new()
    assert_equal(2500, grid_measures.grid_feed_current)
    assert_equal(12345, grid_measures.grid_feed_total)
    assert_equal(542, grid_measures.grid_feed_per_month)
    assert_equal(8765, grid_measures.grid_supply_total)
    assert_equal(234, grid_measures.grid_supply_per_month)
    assert_equal(1200, grid_measures.grid_supply_current)
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
    # Mock OpenDTU being unavailable
    stub_request(:get, "http://192.168.1.100:80/api/livedata/status")
      .to_raise(Errno::ECONNREFUSED)

    opendtu_measures = OpenDTUMeterClient.new()
    assert_equal(0.0, opendtu_measures.power_watts)
    assert_equal(0.0, opendtu_measures.yield_day)
    assert_equal(0.0, opendtu_measures.yield_total)
  end

  # WeatherClient Tests
  def test_weather_client
    weather_response = {
      'current' => {
        'temperature_2m' => 18.5,
        'weather_code' => 3,
        'wind_speed_10m' => 12.3
      }
    }

    stub_request(:get, OPEN_METEO_API_REGEX)
      .to_return(status: 200, body: weather_response.to_json, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })

    weather = WeatherClient.new
    assert_equal(18.5, weather.temperature)
    assert_equal(3, weather.weather_code)
    assert_equal(12.3, weather.wind_speed)
    assert_equal('Teilweise bewölkt', weather.weather_description)
    assert_equal('⛅', weather.weather_icon)
  end

  def test_weather_client_error_handling
    stub_request(:get, OPEN_METEO_API_REGEX)
      .to_raise(Errno::ECONNREFUSED)

    weather = WeatherClient.new
    assert_equal(0.0, weather.temperature)
    assert_equal(0, weather.weather_code)
    assert_equal(0.0, weather.wind_speed)
    assert_equal('Keine Daten', weather.weather_description)
    assert_equal('?', weather.weather_icon)
  end

  def test_weather_code_descriptions
    weather_response = {
      'current' => {
        'temperature_2m' => 5.0,
        'weather_code' => 71,
        'wind_speed_10m' => 8.0
      }
    }

    stub_request(:get, OPEN_METEO_API_REGEX)
      .to_return(status: 200, body: weather_response.to_json, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })

    weather = WeatherClient.new
    assert_equal('Schnee', weather.weather_description)
    assert_equal('❄', weather.weather_icon)
  end

  def test_weather_code_clear_sky
    weather_response = {
      'current' => {
        'temperature_2m' => 25.0,
        'weather_code' => 0,
        'wind_speed_10m' => 5.0
      }
    }

    stub_request(:get, OPEN_METEO_API_REGEX)
      .to_return(status: 200, body: weather_response.to_json, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })

    weather = WeatherClient.new
    assert_equal('Klar', weather.weather_description)
    assert_equal('☀', weather.weather_icon)
  end

  def test_weather_code_rain
    weather_response = {
      'current' => {
        'temperature_2m' => 12.0,
        'weather_code' => 61,
        'wind_speed_10m' => 15.0
      }
    }

    stub_request(:get, OPEN_METEO_API_REGEX)
      .to_return(status: 200, body: weather_response.to_json, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })

    weather = WeatherClient.new
    assert_equal('Regen', weather.weather_description)
    assert_equal('☂', weather.weather_icon)
  end

  def test_weather_code_thunderstorm
    weather_response = {
      'current' => {
        'temperature_2m' => 18.0,
        'weather_code' => 95,
        'wind_speed_10m' => 25.0
      }
    }

    stub_request(:get, OPEN_METEO_API_REGEX)
      .to_return(status: 200, body: weather_response.to_json, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })

    weather = WeatherClient.new
    assert_equal('Gewitter', weather.weather_description)
    assert_equal('⚡', weather.weather_icon)
  end

  def test_weather_code_unknown
    weather_response = {
      'current' => {
        'temperature_2m' => 10.0,
        'weather_code' => 999,
        'wind_speed_10m' => 10.0
      }
    }

    stub_request(:get, OPEN_METEO_API_REGEX)
      .to_return(status: 200, body: weather_response.to_json, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })

    weather = WeatherClient.new
    assert_equal('Unbekannt', weather.weather_description)
    assert_equal('?', weather.weather_icon)
  end

  def test_weather_temperature_rounding
    weather_response = {
      'current' => {
        'temperature_2m' => 18.567,
        'weather_code' => 1,
        'wind_speed_10m' => 12.345
      }
    }

    stub_request(:get, OPEN_METEO_API_REGEX)
      .to_return(status: 200, body: weather_response.to_json, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })

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
    # Mock Youless being unavailable
    stub_request(:get, "http://192.168.178.50/a?f=j")
      .to_raise(Errno::ECONNREFUSED)

    stub_request(:get, %r{http://192\.168\.178\.50/V\?\?f=j&m=\d+})
      .to_raise(Errno::ECONNREFUSED)

    stub_request(:get, "http://192.168.178.50/V?d=0&f=j")
      .to_raise(Errno::ECONNREFUSED)

    stub_request(:get, "http://192.168.178.50/V?d=1&f=j")
      .to_raise(Errno::ECONNREFUSED)

    assert_raises(Errno::ECONNREFUSED) do
      HeatingMeasurements.new()
    end
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
    # SolarMeasurements hat keine Fehlerbehandlung für HTTP-Fehler
    stub_request(:post, SOLAR_METER_URL)
      .to_raise(Errno::ECONNREFUSED)

    assert_raises(Errno::ECONNREFUSED) do
      SolarMeasurements.new()
    end
  end

  # InfluxExporter Tests
  def test_influx_exporter_initialization
    exporter = InfluxExporter.new
    refute_nil(exporter.influx_client)
  end

  # is_new_day helper function tests
  def test_is_new_day_at_midnight
    # Stub Time.now to return a time just after midnight
    Time.stub :now, Time.new(2024, 1, 15, 0, 5, 0) do
      assert_equal(true, is_new_day())
    end
  end

  def test_is_new_day_during_day
    # Stub Time.now to return midday
    Time.stub :now, Time.new(2024, 1, 15, 12, 0, 0) do
      assert_equal(false, is_new_day())
    end
  end

  def test_is_new_day_after_window
    # Stub Time.now to return 11 minutes after midnight (outside 600s window)
    Time.stub :now, Time.new(2024, 1, 15, 0, 11, 0) do
      assert_equal(false, is_new_day())
    end
  end

end
