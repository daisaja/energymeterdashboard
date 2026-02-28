require 'httparty'
require 'json'

class PowerwallClient
  @@auth_token = nil
  @@last_values = {}

  attr_reader :soc_percent, :power_watts, :stored_kwh

  def initialize
    @host = ENV['POWERWALL_HOST']
    @base_url = "https://#{@host}"
    fetch_data
  end

  def fetch_data
    login unless @@auth_token
    fetch_metrics
  rescue Errno::EHOSTUNREACH, Errno::ECONNREFUSED => e
    puts "[Powerwall] Verbindung zu #{@host} fehlgeschlagen: Gerät nicht erreichbar" unless @@last_values.empty?
    restore_last_values
  rescue => e
    puts "[Powerwall] Fehler: #{e.message}" unless @@last_values.empty?
    restore_last_values
  end

  def to_s
    super + " soc_percent: #{soc_percent} power_watts: #{power_watts} stored_kwh: #{stored_kwh}"
  end

  private

  def login
    response = HTTParty.post(
      "#{@base_url}/api/login/Basic",
      body: { username: 'customer', password: ENV['POWERWALL_PASSWORD'],
              email: ENV['POWERWALL_EMAIL'], force_sm_off: false }.to_json,
      headers: { 'Content-Type' => 'application/json' },
      verify: false
    )
    @@auth_token = response.parsed_response['token']
    raise "Login fehlgeschlagen (HTTP #{response.code})" unless @@auth_token
  end

  def authenticated_get(path)
    response = HTTParty.get("#{@base_url}#{path}", headers: auth_headers, verify: false)
    if response.code == 401
      @@auth_token = nil
      login
      response = HTTParty.get("#{@base_url}#{path}", headers: auth_headers, verify: false)
    end
    response
  end

  def auth_headers
    { 'Cookie' => "AuthCookie=#{@@auth_token}" }
  end

  def fetch_metrics
    soe      = authenticated_get('/api/system_status/soe')
    meters   = authenticated_get('/api/meters/aggregates')
    status   = authenticated_get('/api/system_status')

    @soc_percent = soe.parsed_response['percentage'].to_f.round(1)
    # API: positive instant_power = discharging; invert so positive = charging (Laden)
    @power_watts = (-meters.parsed_response['battery']['instant_power'].to_f).round(0)
    @stored_kwh  = (status.parsed_response['nominal_energy_remaining'].to_f / 1000.0).round(1)
    save_values
  end

  def save_values
    @@last_values = {
      soc_percent: @soc_percent,
      power_watts: @power_watts,
      stored_kwh:  @stored_kwh
    }
  end

  def restore_last_values
    @soc_percent = @@last_values[:soc_percent] || 0.0
    @power_watts = @@last_values[:power_watts] || 0.0
    @stored_kwh  = @@last_values[:stored_kwh]  || 0.0
  end
end
