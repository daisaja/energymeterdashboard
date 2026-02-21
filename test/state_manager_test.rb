require_relative 'test_helper'
require_relative '../jobs/meter_helper/state_manager'

class StateManagerTest < Minitest::Test
  def setup
    @tmp_dir    = Dir.mktmpdir
    @state_file = File.join(@tmp_dir, 'state.json')
    ENV['STATE_FILE'] = @state_file
  end

  def teardown
    ENV.delete('STATE_FILE')
    FileUtils.remove_entry(@tmp_dir)
  end

  def sample_state
    {
      day:   { 'date' => Date.today.to_s, 'supply_baseline' => 1234.5, 'feed_baseline' => 567.8,
               'last_supply' => 10.0, 'last_feed' => 2.0 },
      month: { 'year_month' => Time.now.strftime('%Y-%m'), 'supply_baseline' => 1100.0,
               'feed_baseline' => 500.0, 'last_supply' => 80.0, 'last_feed' => 20.0 },
      year:  { 'year' => Time.now.year.to_s, 'supply_baseline' => 900.0, 'feed_baseline' => 300.0 }
    }
  end

  def test_load_returns_nil_when_file_missing
    assert_nil StateManager.load
  end

  def test_load_returns_nil_on_corrupt_json
    File.write(@state_file, 'not valid json }{')
    assert_nil StateManager.load
  end

  def test_load_returns_nil_when_section_missing
    File.write(@state_file, JSON.generate({ 'day' => {}, 'month' => {} }))
    assert_nil StateManager.load
  end

  def test_save_and_load_roundtrip
    StateManager.save(**sample_state)
    result = StateManager.load

    refute_nil result
    assert_equal Date.today.to_s,           result['day']['date']
    assert_equal 1234.5,                    result['day']['supply_baseline']
    assert_equal Time.now.strftime('%Y-%m'), result['month']['year_month']
    assert_equal 1100.0,                    result['month']['supply_baseline']
    assert_equal Time.now.year.to_s,        result['year']['year']
    assert_equal 900.0,                     result['year']['supply_baseline']
  end

  def test_save_leaves_no_tmp_file
    StateManager.save(**sample_state)
    refute File.exist?(@state_file + '.tmp'), 'Temp file should be removed after save'
  end

  def test_save_overwrites_previous_state
    StateManager.save(**sample_state)
    updated = sample_state
    updated[:day]['supply_baseline'] = 9999.0
    StateManager.save(**updated)

    result = StateManager.load
    assert_equal 9999.0, result['day']['supply_baseline']
  end

  def test_saved_at_timestamp_is_present
    StateManager.save(**sample_state)
    result = StateManager.load
    refute_nil result['saved_at']
    assert_match(/^\d{4}-\d{2}-\d{2}T/, result['saved_at'])
  end
end
