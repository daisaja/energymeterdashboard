require 'minitest/autorun'
require 'webmock/minitest'

# Set environment variables BEFORE requiring the files that use them
ENV['GRID_METER_HOST'] = '192.168.178.103'
ENV['OPENDTU_HOST'] = '192.168.1.100'

require_relative '../jobs/meter_helper/grid_meter_client'
require_relative '../jobs/meter_helper/opendtu_meter_client'
require_relative '../jobs/weather'

class UnitTest < Minitest::Test

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
      .to_return(status: 200, body: grid_meter_response.to_json, headers: { 'Content-Type' => 'application/json' })

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
      .to_return(status: 200, body: opendtu_response.to_json, headers: { 'Content-Type' => 'application/json' })

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

    stub_request(:get, /api\.open-meteo\.com\/v1\/forecast/)
      .to_return(status: 200, body: weather_response.to_json, headers: { 'Content-Type' => 'application/json' })

    weather = WeatherClient.new
    assert_equal(18.5, weather.temperature)
    assert_equal(3, weather.weather_code)
    assert_equal(12.3, weather.wind_speed)
    assert_equal('Teilweise bewölkt', weather.weather_description)
  end

  def test_weather_client_error_handling
    stub_request(:get, /api\.open-meteo\.com\/v1\/forecast/)
      .to_raise(Errno::ECONNREFUSED)

    weather = WeatherClient.new
    assert_equal(0.0, weather.temperature)
    assert_equal(0, weather.weather_code)
    assert_equal(0.0, weather.wind_speed)
    assert_equal('Keine Daten', weather.weather_description)
  end

  def test_weather_code_descriptions
    weather_response = {
      'current' => {
        'temperature_2m' => 5.0,
        'weather_code' => 71,
        'wind_speed_10m' => 8.0
      }
    }

    stub_request(:get, /api\.open-meteo\.com\/v1\/forecast/)
      .to_return(status: 200, body: weather_response.to_json, headers: { 'Content-Type' => 'application/json' })

    weather = WeatherClient.new
    assert_equal('Schnee', weather.weather_description)
  end

end
