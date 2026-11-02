require_relative 'test_helper'
require_relative '../jobs/meter_helper/vz_middleware_client'

class VzMiddlewareClientTest < Minitest::Test
  URL_PATTERN = %r{\Ahttp://192\.168\.178\.103/middleware\.php/data/e52fc000-0e64-11f1-b37f-4db1c53870b5\.json\?.*}

  def setup
    WebMock.disable_net_connect!
  end

  def stub_middleware(body, status: 200)
    stub_request(:get, URL_PATTERN)
      .to_return(status: status, body: body.to_json, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })
  end

  def test_returns_timestamp_of_newest_tuple
    stub_middleware({ 'data' => { 'tuples' => [[1_700_000_000_000, 1.0, 1], [1_700_000_060_000, 2.0, 1]] } })
    assert_equal(Time.at(1_700_000_060), VzMiddlewareClient.last_tuple_time)
  end

  def test_picks_newest_even_if_unsorted
    stub_middleware({ 'data' => { 'tuples' => [[1_700_000_060_000, 2.0, 1], [1_700_000_000_000, 1.0, 1]] } })
    assert_equal(Time.at(1_700_000_060), VzMiddlewareClient.last_tuple_time)
  end

  def test_nil_when_no_tuples
    stub_middleware({ 'data' => { 'tuples' => [] } })
    assert_nil(VzMiddlewareClient.last_tuple_time)
  end

  def test_nil_when_tuples_missing
    stub_middleware({ 'data' => {} })
    assert_nil(VzMiddlewareClient.last_tuple_time)
  end

  def test_nil_on_http_error
    stub_middleware({ 'exception' => 'x' }, status: 500)
    assert_nil(VzMiddlewareClient.last_tuple_time)
  end

  def test_nil_on_connection_error
    stub_request(:get, URL_PATTERN).to_raise(Errno::ECONNREFUSED)
    assert_nil(VzMiddlewareClient.last_tuple_time)
  end

  def test_nil_on_timeout
    stub_request(:get, URL_PATTERN).to_timeout
    assert_nil(VzMiddlewareClient.last_tuple_time)
  end

  def test_requests_window_in_milliseconds
    now = Time.at(1_700_000_000)
    stub = stub_request(:get, URL_PATTERN)
           .with(query: { 'from' => ((now.to_i - 3600) * 1000).to_s, 'to' => (now.to_i * 1000).to_s })
           .to_return(status: 200, body: { 'data' => { 'tuples' => [] } }.to_json,
                      headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })
    VzMiddlewareClient.last_tuple_time(now)
    assert_requested(stub)
  end

  DB_EXCEPTION_BODY = '{"version":"0.3","exception":{"message":"An exception occurred in driver: SQLSTATE[HY000] [2002] Verbindungsaufbau abgelehnt","type":"ConnectionException","code":0}}'

  def test_fetch_returns_time_for_tuple
    stub_middleware({ 'data' => { 'tuples' => [[1_700_000_060_000, 2.0, 1]] } })
    assert_equal(Time.at(1_700_000_060), VzMiddlewareClient.fetch)
  end

  def test_fetch_returns_empty_for_valid_response_without_tuples
    stub_middleware({ 'data' => { 'tuples' => [] } })
    assert_equal(:empty, VzMiddlewareClient.fetch)
  end

  def test_fetch_returns_db_error_for_sqlstate_exception_body
    stub_request(:get, URL_PATTERN)
      .to_return(status: 200, body: DB_EXCEPTION_BODY, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })
    assert_equal(:db_error, VzMiddlewareClient.fetch)
  end

  def test_fetch_returns_error_for_other_exception_body
    stub_middleware({ 'exception' => { 'message' => 'Unknown UUID' } })
    assert_equal(:error, VzMiddlewareClient.fetch)
  end

  def test_fetch_returns_error_on_http_error
    stub_middleware({ 'data' => {} }, status: 500)
    assert_equal(:error, VzMiddlewareClient.fetch)
  end

  def test_fetch_returns_error_on_connection_error
    stub_request(:get, URL_PATTERN).to_raise(Errno::ECONNREFUSED)
    assert_equal(:error, VzMiddlewareClient.fetch)
  end

  def test_last_tuple_time_nil_for_db_exception_body
    stub_request(:get, URL_PATTERN)
      .to_return(status: 200, body: DB_EXCEPTION_BODY, headers: { CONTENT_TYPE_JSON => APPLICATION_JSON })
    assert_nil(VzMiddlewareClient.last_tuple_time)
  end
end
