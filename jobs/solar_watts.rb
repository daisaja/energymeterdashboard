require_relative 'meter_helper/grid_meter_client'
require_relative 'meter_helper/solar_meter_client'
require_relative 'meter_helper/opendtu_meter_client'

$solar_peak_of_the_day = 0

if defined?(SCHEDULER)
  SCHEDULER.every '2s', :first_in => 0 do |job|
    solar_measurements = SolarMeasurements.new()
    opendtu_measures = OpenDTUMeterClient.new()

    reset_solar_peak_meter()
    set_solar_current_peak(solar_measurements.solar_watts_current)

    send_event('wattmetersolar', { value: solar_measurements.solar_watts_current + opendtu_measures.power_watts })
    send_event('solar_peak_meter', { value: $solar_peak_of_the_day })
    report_solar(solar_measurements.solar_watts_current + opendtu_measures.power_watts)
  end
end

def reset_solar_peak_meter()
  if is_new_day()
    $solar_peak_of_the_day = 0
  end
end

def set_solar_current_peak(current_watts)
  if $solar_peak_of_the_day < current_watts
    $solar_peak_of_the_day = current_watts
  end
end

def report_solar(solar_watts_current)
  reporter = InfluxExporter.new()
  hash = {
           name: 'wattmeter_solar',
           tags: {meter_type: 'solar'},
           fields: {solar_watts_current: solar_watts_current.to_f},
         }
  reporter.send_data(hash)
end
