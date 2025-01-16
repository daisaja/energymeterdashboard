require 'minitest/autorun'
require_relative '../jobs/meter_helper/grid_meter_client' #name of file with class
require_relative '../jobs/meter_helper/opendtu_meter_client'

class UnitTest < Minitest::Test

  def test_intialized_data_object
    grid_measures = GridMeasurements.new()
    assert(grid_measures.grid_feed_total>0)
  end

  def test_opendtu_meter_client
    opendtu_measures = OpenDTUMeterClient.new()
    assert(opendtu_measures.power_watts >= 0.0)
    assert(opendtu_measures.yield_day >= 0.0)
    assert(opendtu_measures.yield_total >= 0.0)
    puts opendtu_measures.to_s
  end

end
