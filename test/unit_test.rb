require 'minitest/autorun'
require_relative '../jobs/meter_helper/grid_meter_client' #name of file with class

class UnitTest < Minitest::Test

  def test_intialized_data_object
    grid_measures = GridMeasurements.new()
    assert(grid_measures.grid_feed_total>0)
  end

end
