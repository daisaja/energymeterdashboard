require_relative 'test_helper'
require_relative '../jobs/meter_helper/powerwall_client'

class PowerwallClientTest < Minitest::Test
  POWERWALL_HOST       = '192.168.178.200'
  POWERWALL_LOGIN_URL  = "https://#{POWERWALL_HOST}/api/login/Basic"
  POWERWALL_SOE_URL    = "https://#{POWERWALL_HOST}/api/system_status/soe"
  POWERWALL_METERS_URL = "https://#{POWERWALL_HOST}/api/meters/aggregates"
  POWERWALL_STATUS_URL = "https://#{POWERWALL_HOST}/api/system_status"

  def setup
    WebMock.disable_net_connect!
    PowerwallClient.class_variable_set(:@@auth_token, nil)
    PowerwallClient.class_variable_set(:@@last_values, {})
  end

  def stub_login(token: 'testtoken123')
    stub_request(:post, POWERWALL_LOGIN_URL)
      .to_return(status: 200, body: { 'token' => token }.to_json, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })
  end

  def stub_metrics(soc: 75.5, instant_power: -1200.0, energy_remaining: 10_200)
    stub_request(:get, POWERWALL_SOE_URL)
      .to_return(status: 200, body: { 'percentage' => soc }.to_json, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })
    stub_request(:get, POWERWALL_METERS_URL)
      .to_return(status: 200, body: { 'battery' => { 'instant_power' => instant_power } }.to_json, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })
    stub_request(:get, POWERWALL_STATUS_URL)
      .to_return(status: 200, body: { 'nominal_energy_remaining' => energy_remaining }.to_json, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })
  end

  def test_powerwall_client_basic_values
    stub_login
    stub_metrics

    client = PowerwallClient.new
    assert_equal(75.5,   client.soc_percent)
    assert_equal(1200.0, client.power_watts)   # API -1200 (charging) → inverted → +1200
    assert_equal(10.2,   client.stored_kwh)    # 10200 Wh / 1000
  end

  def test_powerwall_client_discharging_inverts_sign
    stub_login
    stub_metrics(instant_power: 800.0)  # positive API = discharging

    client = PowerwallClient.new
    assert_equal(-800.0, client.power_watts)   # inverted → -800 (Entladen)
  end

  def test_powerwall_client_token_cached_across_instances
    stub_login
    stub_metrics

    PowerwallClient.new
    PowerwallClient.new  # second instance should NOT call login again

    assert_requested(:post, POWERWALL_LOGIN_URL, times: 1)
  end

  def test_powerwall_client_retries_login_on_401
    stub_login
    stub_request(:get, POWERWALL_SOE_URL)
      .to_return(status: 401, body: '').then
      .to_return(status: 200, body: { 'percentage' => 50.0 }.to_json, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })
    stub_metrics(soc: 50.0)
    # Second login stub for retry
    stub_request(:post, POWERWALL_LOGIN_URL)
      .to_return(status: 200, body: { 'token' => 'newtoken456' }.to_json, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })

    client = PowerwallClient.new
    assert_equal(50.0, client.soc_percent)
  end

  def test_powerwall_client_connection_refused_returns_defaults
    stub_request(:post, POWERWALL_LOGIN_URL).to_raise(Errno::ECONNREFUSED)

    client = PowerwallClient.new
    assert_equal(0.0, client.soc_percent)
    assert_equal(0.0, client.power_watts)
    assert_equal(0.0, client.stored_kwh)
  end

  def test_powerwall_client_host_unreachable_returns_defaults
    stub_request(:post, POWERWALL_LOGIN_URL).to_raise(Errno::EHOSTUNREACH)

    client = PowerwallClient.new
    assert_equal(0.0, client.soc_percent)
    assert_equal(0.0, client.power_watts)
    assert_equal(0.0, client.stored_kwh)
  end

  def test_powerwall_client_keeps_last_values_on_error
    stub_login
    stub_metrics

    client = PowerwallClient.new
    assert_equal(75.5, client.soc_percent)

    # Second request fails – token is cached, so failure happens in fetch_metrics
    WebMock.reset!
    stub_request(:get, POWERWALL_SOE_URL).to_raise(Errno::ECONNREFUSED)
    stub_request(:get, POWERWALL_METERS_URL).to_raise(Errno::ECONNREFUSED)
    stub_request(:get, POWERWALL_STATUS_URL).to_raise(Errno::ECONNREFUSED)

    client2 = PowerwallClient.new
    assert_equal(75.5,   client2.soc_percent)
    assert_equal(1200.0, client2.power_watts)
    assert_equal(10.2,   client2.stored_kwh)
  end
end
