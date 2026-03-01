require_relative 'test_helper'
require_relative '../jobs/influx_exporter'

class InfluxExporterTest < Minitest::Test
  def test_influx_exporter_initialization
    exporter = InfluxExporter.new
    refute_nil(exporter.influx_client)
  end
end
