require 'minitest/autorun'
require_relative '../jobs/meter_helper/tibber_meter_client' #name of file with class

class UnitTest < Minitest::Test

  def test_tibber_meter_client_is_initialized
    tibber_meter_client = TibberMeter.new()
    assert(tibber_meter_client.get_meter_count == nil, "Meter count should be nil")
  end


    def test_tibber_meter_client_get_meter_count_from_tibber
      tibber_meter_client = TibberMeter.new()
      assert(tibber_meter_client.get_meter_count_from_tibber == nil, "Meter count should be nil")
    end
end