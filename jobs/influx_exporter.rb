require 'influxdb-client'

class InfluxExporter

  INFLUXDB_HOST = ENV['INFLUXDB_HOST']
  INFLUXDB_TOKEN = ENV['INFLUXDB_TOKEN']
  INFLUXDB_URL = "http://#{INFLUXDB_HOST}:8086"
  INFLUXDB_ORG = '@home'
  
  #INFLUXDB_REMOTE_URL = ENV['INFLUXDB_REMOTE_URL']
  #INFLUXDB_REMOTE_ORG = ENV['INFLUXDB_REMOTE_ORG']
  #INFLUXDB_REMOTE_TOKEN = ENV['INFLUXDB_REMOTE_TOKEN']
  
  INFLUXDB_BUCKET = 'strommessung'

  attr_accessor :influx_client

  def initialize()
    @influx_client = InfluxDB2::Client.new(INFLUXDB_URL, INFLUXDB_TOKEN,
      precision: InfluxDB2::WritePrecision::NANOSECOND, use_ssl: false)
     
      # with ssl
   #@influx_client = InfluxDB2::Client.new(INFLUXDB_URL, INFLUXDB_TOKEN,
      # precision: InfluxDB2::WritePrecision::NANOSECOND, use_ssl: true)
  end

  def send_data(hash)
      write_api = @influx_client.create_write_api
      hash.merge({time: Time.now})
      #puts "!!! Influx data: #{hash}\n bucket: #{INFLUXDB_BUCKET}\n org: #{INFLUXDB_ORG}"
      write_api.write(data: hash, bucket: INFLUXDB_BUCKET, org: INFLUXDB_ORG)
  end
end
