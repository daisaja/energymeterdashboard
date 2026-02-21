require 'simplecov'
SimpleCov.start do
  add_filter '/test/'
end

require 'minitest/autorun'
require 'webmock/minitest'

# Set test environment variables before loading any application code
ENV['GRID_METER_HOST']    = '192.168.178.103'
ENV['OPENDTU_HOST']       = '192.168.1.100'
ENV['HEATING_METER_HOST'] = '192.168.178.50'
ENV['SOLAR_METER_HOST']   = '192.168.178.60'
ENV['INFLUXDB_HOST']      = '192.168.178.70'
ENV['INFLUXDB_TOKEN']     = 'test-token'
ENV['POWERWALL_HOST']     = '192.168.178.200'
ENV['POWERWALL_EMAIL']    = 'test@example.com'
ENV['POWERWALL_PASSWORD'] = 'testpassword'

CONTENT_TYPE_JSON = 'Content-Type'
APPLICATION_JSON  = 'application/json'
