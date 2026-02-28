require_relative 'test_helper'
require_relative '../jobs/meter_helper/grid_meter_client'

class GridMeterClientTest < Minitest::Test
  def setup
    WebMock.disable_net_connect!
  end

  def grid_response(feed_total_wh: 0, supply_total_wh: 0, current_power_w: 0)
    {
      'data' => [
        { 'uuid' => '11755f30-0e65-11f1-a7d4-cfd94d2fa168', 'tuples' => [[1234567890000, feed_total_wh]] },
        { 'uuid' => 'e52fc000-0e64-11f1-b37f-4db1c53870b5', 'tuples' => [[1234567890000, supply_total_wh]] },
        { 'uuid' => '2c58c270-0e65-11f1-8833-19d9403165de', 'tuples' => [[1234567890000, current_power_w]] }
      ]
    }
  end

  def stub_grid(body)
    stub_request(:get, "http://192.168.178.103:8081/")
      .to_return(status: 200, body: body.to_json, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })
  end

  # E320 via SML: 3 Kanäle, Zählerstände in Wh, Momentanleistung in W (vorzeichenbehaftet)
  # Positiver 16.7.0-Wert → Bezug, kein Einspeisung
  def test_grid_meter_client
    stub_grid(grid_response(feed_total_wh: 12_345_000, supply_total_wh: 8_765_000, current_power_w: 1200))

    grid_measures = GridMeasurements.new
    assert_equal(12345.0, grid_measures.grid_feed_total)
    assert_equal(0.0,     grid_measures.grid_feed_per_month)   # nicht mehr vom Zähler geliefert
    assert_equal(0.0,     grid_measures.grid_feed_current)     # kein Einspeisung bei positivem Wert
    assert_equal(8765.0,  grid_measures.grid_supply_total)
    assert_equal(0.0,     grid_measures.grid_supply_per_month) # nicht mehr vom Zähler geliefert
    assert_equal(1.2,     grid_measures.grid_supply_current)
  end

  # Negativer 16.7.0-Wert → Einspeisung, kein Bezug
  def test_grid_meter_client_feed_current_with_negative_power
    stub_grid(grid_response(current_power_w: -2500))

    grid_measures = GridMeasurements.new
    assert_equal(2.5, grid_measures.grid_feed_current)
    assert_equal(0.0, grid_measures.grid_supply_current)
  end

  # 16.7.0 ohne tuples-Array (E320 Momentanleistung noch nicht im erweiterten Modus)
  def test_grid_meter_client_missing_tuples
    response = {
      'data' => [
        { 'uuid' => 'e52fc000-0e64-11f1-b37f-4db1c53870b5', 'tuples' => [[1234567890000, 526_000]] },
        { 'uuid' => '11755f30-0e65-11f1-a7d4-cfd94d2fa168', 'tuples' => [[1234567890000, 0]] },
        { 'uuid' => '2c58c270-0e65-11f1-8833-19d9403165de', 'last' => 0, 'interval' => -1 }
      ]
    }
    stub_grid(response)

    grid_measures = GridMeasurements.new
    assert_equal(526.0, grid_measures.grid_supply_total)
    assert_equal(0.0,   grid_measures.grid_supply_current)  # kein Absturz bei fehlendem tuples
    assert_equal(0.0,   grid_measures.grid_feed_current)
  end

  def test_grid_meter_client_connection_refused_first_time
    GridMeasurements.class_variable_set(:@@last_values, {})
    stub_request(:get, "http://192.168.178.103:8081/").to_raise(Errno::ECONNREFUSED)

    grid_measures = GridMeasurements.new
    assert_equal(0.0, grid_measures.grid_feed_current)
    assert_equal(0.0, grid_measures.grid_feed_total)
    assert_equal(0.0, grid_measures.grid_supply_current)
    assert_equal(0.0, grid_measures.grid_supply_total)
  end

  def test_grid_meter_client_host_unreachable_first_time
    GridMeasurements.class_variable_set(:@@last_values, {})
    stub_request(:get, "http://192.168.178.103:8081/").to_raise(Errno::EHOSTUNREACH)

    grid_measures = GridMeasurements.new
    assert_equal(0.0, grid_measures.grid_feed_current)
    assert_equal(0.0, grid_measures.grid_feed_total)
    assert_equal(0.0, grid_measures.grid_supply_current)
    assert_equal(0.0, grid_measures.grid_supply_total)
  end

  def test_grid_meter_client_socket_error_returns_defaults
    GridMeasurements.class_variable_set(:@@last_values, {})
    stub_request(:get, "http://192.168.178.103:8081/").to_raise(SocketError)

    grid_measures = GridMeasurements.new
    assert_equal(0.0, grid_measures.grid_feed_current)
    assert_equal(0.0, grid_measures.grid_feed_total)
    assert_equal(0.0, grid_measures.grid_supply_current)
    assert_equal(0.0, grid_measures.grid_supply_total)
  end

  def test_grid_meter_client_keeps_last_values_on_error
    stub_grid(grid_response(feed_total_wh: 12_345_000, supply_total_wh: 8_765_000, current_power_w: -2500))

    grid_measures = GridMeasurements.new
    assert_equal(2.5, grid_measures.grid_feed_current)

    WebMock.reset!
    stub_request(:get, "http://192.168.178.103:8081/").to_raise(Errno::ECONNREFUSED)

    grid_measures2 = GridMeasurements.new
    assert_equal(2.5,     grid_measures2.grid_feed_current)
    assert_equal(12345.0, grid_measures2.grid_feed_total)
  end

  # is_new_day helper (defined in grid_meter_client.rb)
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

  # is_new_month helper (defined in grid_meter_client.rb)
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
