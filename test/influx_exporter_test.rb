require_relative 'test_helper'
require_relative '../jobs/influx_exporter'

# Minimal spy that records what was passed to write()
class WriteApiSpy
  attr_reader :last_write_args

  def write(**kwargs)
    @last_write_args = kwargs
  end
end

class InfluxExporterTest < Minitest::Test
  def test_influx_exporter_initialization
    exporter = InfluxExporter.new
    refute_nil(exporter.influx_client)
  end

  def test_send_data_calls_write_with_correct_bucket_and_org
    exporter = InfluxExporter.new
    spy = WriteApiSpy.new
    stub_instance(exporter.influx_client, :create_write_api, spy) do
      exporter.send_data({ name: 'wattmeter_test', fields: { power: 500 } })
    end
    assert_equal 'strommessung', spy.last_write_args[:bucket]
    assert_equal '@home',        spy.last_write_args[:org]
  end

  def test_send_data_adds_time_key_to_hash
    exporter = InfluxExporter.new
    hash = { name: 'wattmeter_test', fields: { power: 500 } }
    spy = WriteApiSpy.new
    stub_instance(exporter.influx_client, :create_write_api, spy) do
      exporter.send_data(hash)
    end
    assert hash.key?(:time), 'send_data should add :time to the data hash'
    assert_instance_of Time, hash[:time]
  end

  def test_send_data_passes_original_fields_to_write
    exporter = InfluxExporter.new
    spy = WriteApiSpy.new
    stub_instance(exporter.influx_client, :create_write_api, spy) do
      exporter.send_data({ name: 'wattmeter_solar', tags: { meter_type: 'solar' }, fields: { watts: 1200.0 } })
    end
    data = spy.last_write_args[:data]
    assert_equal 'wattmeter_solar',      data[:name]
    assert_equal({ meter_type: 'solar' }, data[:tags])
    assert_equal 1200.0,                 data[:fields][:watts]
  end
end
