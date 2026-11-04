require_relative 'test_helper'
require_relative '../jobs/meter_helper/opendtu_meter_client'

class OpenDTUMeterClientTest < Minitest::Test
  OPENDTU_URL = 'http://192.168.1.100:80/api/livedata/status'

  def setup
    WebMock.disable_net_connect!
  end

  def opendtu_response(power: 2450.5, yield_day: 12.5, yield_total: 1463.25)
    { 'total' => { 'Power' => { 'v' => power }, 'YieldDay' => { 'v' => yield_day }, 'YieldTotal' => { 'v' => yield_total } } }
  end

  def stub_opendtu(body)
    stub_request(:get, OPENDTU_URL)
      .to_return(status: 200, body: body.to_json, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })
  end

  def test_opendtu_meter_client
    stub_opendtu(opendtu_response)

    opendtu = OpenDTUMeterClient.new
    assert_equal(2451.0,  opendtu.power_watts)
    assert_equal(13.0,    opendtu.yield_day)    # 12.5.round(0) = 13
    assert_equal(1463.0,  opendtu.yield_total)
  end

  def test_opendtu_meter_client_error_handling
    OpenDTUMeterClient.class_variable_set(:@@last_values, {})
    stub_request(:get, OPENDTU_URL).to_raise(Errno::ECONNREFUSED)

    opendtu = OpenDTUMeterClient.new
    assert_equal(0.0, opendtu.power_watts)
    assert_equal(0.0, opendtu.yield_day)
    assert_equal(0.0, opendtu.yield_total)
  end

  def test_opendtu_meter_client_keeps_last_values_on_error
    stub_opendtu(opendtu_response)

    opendtu = OpenDTUMeterClient.new
    assert_equal(2451.0, opendtu.power_watts)

    WebMock.reset!
    stub_request(:get, OPENDTU_URL).to_raise(Errno::ECONNREFUSED)

    opendtu2 = OpenDTUMeterClient.new
    assert_equal(2451.0,  opendtu2.power_watts)
    assert_equal(13.0,    opendtu2.yield_day)
    assert_equal(1463.0,  opendtu2.yield_total)
  end

  def test_opendtu_total_yield_kwh_keeps_decimals
    OpenDTUMeterClient.class_variable_set(:@@last_values, {})
    stub_opendtu(opendtu_response(yield_total: 2226.125977))   # echte Antwort, Einheit kWh

    assert_equal(2226.126, OpenDTUMeterClient.new.yield_total_kwh)
  end

  def test_opendtu_total_yield_kwh_nil_when_missing_or_zero
    OpenDTUMeterClient.class_variable_set(:@@last_values, {})
    stub_opendtu(opendtu_response(yield_total: 0))
    assert_nil(OpenDTUMeterClient.new.yield_total_kwh)

    OpenDTUMeterClient.class_variable_set(:@@last_values, {})
    stub_request(:get, OPENDTU_URL).to_return(status: 200, body: { 'total' => { 'Power' => { 'v' => 1 } } }.to_json,
                                              headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })
    assert_nil(OpenDTUMeterClient.new.yield_total_kwh)
  end

  def test_opendtu_total_yield_kwh_nil_on_error_without_history
    OpenDTUMeterClient.class_variable_set(:@@last_values, {})
    stub_request(:get, OPENDTU_URL).to_raise(Errno::ECONNREFUSED)

    assert_nil(OpenDTUMeterClient.new.yield_total_kwh)
  end
end
