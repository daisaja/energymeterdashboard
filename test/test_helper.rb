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

# Temporarily replaces a top-level (Object-level) method for the duration of the block.
def stub_method(name, value, &block)
  original = Object.instance_method(name)
  callable = value.respond_to?(:call) ? value : ->(*) { value }
  Object.send(:define_method, name) { |*a, **kw| callable.call(*a, **kw) }
  block.call
ensure
  Object.send(:define_method, name, original)
end

# Temporarily replaces a class/singleton method on an object for the duration of the block.
def stub_on(target, name, value = nil, &block)
  original   = target.method(name)
  callable   = value.respond_to?(:call) ? value : ->(*) { value }
  target.define_singleton_method(name) { |*a, **kw| callable.call(*a, **kw) }
  block.call
ensure
  target.define_singleton_method(name, original)
end

# Temporarily replaces an instance method on a specific object instance.
def stub_instance(obj, name, value, &block)
  callable = value.respond_to?(:call) ? value : ->(*) { value }
  obj.define_singleton_method(name) { |*a, **kw| callable.call(*a, **kw) }
  block.call
ensure
  obj.singleton_class.send(:remove_method, name)
end
