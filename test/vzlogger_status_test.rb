require_relative 'test_helper'
require_relative '../jobs/vzlogger_status'

class VzloggerStatusTest < Minitest::Test
  NOW = Time.new(2026, 11, 2, 12, 0, 0)

  def status(local, threshold = 300)
    vzlogger_status(local, NOW, threshold)
  end

  # --- format_duration ---

  def test_format_duration_under_a_minute
    assert_equal('< 1 min', format_duration(30))
  end

  def test_format_duration_minutes
    assert_equal('14 min', format_duration(14 * 60 + 20))
  end

  def test_format_duration_hours
    assert_equal('3 h', format_duration(3 * 3600 + 120))
  end

  def test_format_duration_days
    assert_equal('2 Tage', format_duration(2 * 86_400 + 3600))
  end

  def test_format_duration_one_day
    assert_equal('1 Tag', format_duration(86_400))
  end

  # --- vzlogger_status ---

  def test_ok_when_fresh
    result = status(NOW - 5)
    assert_equal('ok', result[:status])
    assert_equal('vzlogger OK', result[:message])
  end

  def test_ok_exactly_at_threshold
    assert_equal('ok', status(NOW - 300)[:status])
  end

  def test_local_offline
    result = status(NOW - 14 * 60)
    assert_equal('warning', result[:status])
    assert_equal('vzlogger offline seit 14 min', result[:message])
  end

  def test_local_offline_days
    assert_equal('vzlogger offline seit 2 Tage', status(NOW - 2 * 86_400)[:message])
  end

  def test_local_nil
    result = status(nil)
    assert_equal('warning', result[:status])
    assert_equal('vzlogger: seit Start keine Daten', result[:message])
  end

  def test_custom_threshold
    assert_equal('ok', status(NOW - 600, 900)[:status])
    assert_equal('warning', status(NOW - 600, 300)[:status])
  end

  def test_future_timestamp_is_ok
    # Uhrenabweichung zwischen Pi und Server darf keine Warnung auslösen
    assert_equal('ok', status(NOW + 30)[:status])
  end
end
