require 'influxdb-client'

class InfluxExporter

  INFLUXDB_HOST = ENV['INFLUXDB_HOST']
  INFLUXDB_TOKEN = ENV['INFLUXDB_TOKEN']
  INFLUXDB_URL = "http://" + INFLUXDB_HOST + ":8086"
  INFLUXDB_ORG = '@home'
  INFLUXDB_BUCKET = 'strommessung'

  attr_accessor :influx_client

  def initialize()
    @influx_client = InfluxDB2::Client.new(INFLUXDB_URL, INFLUXDB_TOKEN,
      precision: InfluxDB2::WritePrecision::NANOSECOND, use_ssl: false)
  end

  def send_data(hash)
    write_api = @influx_client.create_write_api
    write_api.write(data: hash, bucket: INFLUXDB_BUCKET, org: INFLUXDB_ORG)
  end
end
