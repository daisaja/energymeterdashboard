require 'simplecov'
SimpleCov.start do
  add_filter '/test/'
end

require 'minitest/autorun'
require 'webmock/minitest'

# Set environment variables BEFORE requiring the files that use them
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
require_relative '../jobs/influx_exporter'

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

  # HeatingMeasurements Tests
  def test_heating_meter_client
    current_month = Date.today.month

    # Mock Youless API responses
    stub_request(:get, "http://192.168.178.50/a?f=j")
      .to_return(status: 200, body: { 'pwr' => 1500 }.to_json, headers: { 'Content-Type' => 'application/json' })

    stub_request(:get, "http://192.168.178.50/V?m=#{current_month}&?f=j")
      .to_return(status: 200, body: { 'val' => ['10.5', '20.3', '15.2'] }.to_json, headers: { 'Content-Type' => 'application/json' })

    stub_request(:get, "http://192.168.178.50/V?d=0&f=j")
      .to_return(status: 200, body: { 'val' => [500, 600, 400] }.to_json, headers: { 'Content-Type' => 'application/json' })

    stub_request(:get, "http://192.168.178.50/V?d=1&f=j")
      .to_return(status: 200, body: { 'val' => [800, 700, 500] }.to_json, headers: { 'Content-Type' => 'application/json' })

    heating_measures = HeatingMeasurements.new()
    assert_equal(1500, heating_measures.heating_watts_current)
    assert_in_delta(46.0, heating_measures.heating_per_month, 0.1)  # 10.5 + 20.3 + 15.2 = 46.0
    assert_equal(1, heating_measures.heating_kwh_current_day)  # (500+600+400)/1000 = 1
    assert_equal(2, heating_measures.heating_kwh_last_day)  # (800+700+500)/1000 = 2
  end

  def test_heating_meter_client_error_handling
    current_month = Date.today.month

    # Mock Youless being unavailable
    stub_request(:get, "http://192.168.178.50/a?f=j")
      .to_raise(Errno::ECONNREFUSED)

    stub_request(:get, "http://192.168.178.50/V?m=#{current_month}&?f=j")
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
    sma_response = {
      'result' => {
        '017A-B339126F' => {
          '6100_40263F00' => {
            '1' => [{ 'val' => 3500 }]
          }
        }
      }
    }

    stub_request(:post, "https://192.168.178.60/dyn/getDashValues.json")
      .to_return(status: 200, body: sma_response.to_json, headers: { 'Content-Type' => 'application/json' })

    solar_measures = SolarMeasurements.new()
    assert_equal(3500, solar_measures.solar_watts_current)
    assert_equal(0.0, solar_measures.solar_watts_per_month)  # not implemented
  end

  def test_solar_meter_client_fallback_device_id
    sma_response = {
      'result' => {
        '017A-xxxxx26F' => {
          '6100_40263F00' => {
            '1' => [{ 'val' => 2800 }]
          }
        }
      }
    }

    stub_request(:post, "https://192.168.178.60/dyn/getDashValues.json")
      .to_return(status: 200, body: sma_response.to_json, headers: { 'Content-Type' => 'application/json' })

    solar_measures = SolarMeasurements.new()
    assert_equal(2800, solar_measures.solar_watts_current)
  end

  def test_solar_meter_client_error_handling
    # SolarMeasurements hat keine Fehlerbehandlung für HTTP-Fehler
    stub_request(:post, "https://192.168.178.60/dyn/getDashValues.json")
      .to_raise(Errno::ECONNREFUSED)

    assert_raises(Errno::ECONNREFUSED) do
      SolarMeasurements.new()
    end
  end

  def test_solar_meter_client_nil_value
    sma_response = {
      'result' => {
        '017A-B339126F' => {
          '6100_40263F00' => {
            '1' => [{ 'val' => nil }]
          }
        }
      }
    }

    stub_request(:post, "https://192.168.178.60/dyn/getDashValues.json")
      .to_return(status: 200, body: sma_response.to_json, headers: { 'Content-Type' => 'application/json' })

    solar_measures = SolarMeasurements.new()
    assert_equal(0.0, solar_measures.solar_watts_current)
  end

  # InfluxExporter Tests
  def test_influx_exporter_initialization
    exporter = InfluxExporter.new()
    assert_instance_of(InfluxDB2::Client, exporter.influx_client)
  end

  # is_new_day() Helper Tests
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
