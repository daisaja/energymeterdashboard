require_relative 'meter_helper/heating_meter_client'

SCHEDULER.every '2s', :first_in => 0 do |job|
  heating_measurements = HeatingMeasurements.new()
  send_event('wattmeterheating',   { value: heating_measurements.heating_watts_current})
  report_heating(heating_measurements.heating_watts_current)
end

def report_heating(heating_watts_current)
  reporter = InfluxExporter.new()
  hash = {
           name: 'wattmeter_heating',
           tags: {meter_type: 'heating'},
           fields: {heating_watts_current: heating_watts_current},
         }
  reporter.send_data(hash)
end
