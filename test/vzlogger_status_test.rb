require_relative 'test_helper'
require_relative '../jobs/vzlogger_status'

class VzloggerStatusTest < Minitest::Test
  NOW = Time.new(2026, 11, 2, 12, 0, 0)

  def status(local, middleware, threshold = 300)
    vzlogger_status(local, middleware, NOW, threshold)
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

  def test_ok_when_both_fresh
    result = status(NOW - 5, NOW - 60)
    assert_equal('ok', result[:status])
    assert_equal('vzlogger OK', result[:message])
  end

  def test_ok_exactly_at_threshold
    assert_equal('ok', status(NOW - 300, NOW - 300)[:status])
  end

  def test_local_offline
    result = status(NOW - 14 * 60, NOW - 60)
    assert_equal('warning', result[:status])
    assert_equal('vzlogger offline seit 14 min', result[:message])
  end

  def test_middleware_stale
    result = status(NOW - 5, NOW - 3 * 3600)
    assert_equal('warning', result[:status])
    assert_equal('Middleware erhält keine Daten seit 3 h', result[:message])
  end

  def test_local_nil
    result = status(nil, NOW - 60)
    assert_equal('warning', result[:status])
    assert_equal('vzlogger: seit Start keine Daten', result[:message])
  end

  def test_middleware_nil
    result = status(NOW - 5, nil)
    assert_equal('warning', result[:status])
    assert_equal('Middleware: seit Start keine Daten', result[:message])
  end

  def test_both_problems_combined
    result = status(NOW - 2 * 86_400, NOW - 2 * 86_400)
    assert_equal('warning', result[:status])
    assert_equal('vzlogger offline seit 2 Tage / Middleware erhält keine Daten seit 2 Tage', result[:message])
  end

  def test_both_nil
    result = status(nil, nil)
    assert_equal('vzlogger: seit Start keine Daten / Middleware: seit Start keine Daten', result[:message])
  end

  def test_custom_threshold
    assert_equal('ok', status(NOW - 600, NOW - 600, 900)[:status])
    assert_equal('warning', status(NOW - 600, NOW - 600, 300)[:status])
  end

  def test_future_timestamp_is_ok
    # Uhrenabweichung zwischen Pi und Server darf keine Warnung auslösen
    assert_equal('ok', status(NOW + 30, NOW + 30)[:status])
  end
end
