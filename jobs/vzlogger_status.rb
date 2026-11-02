require_relative 'meter_helper/grid_meter_client'
require_relative 'meter_helper/vz_middleware_client'

STATUS_THRESHOLD_SECONDS = 300

# Formatiert eine Dauer in Sekunden für die Anzeige: "< 1 min", "14 min", "3 h", "2 Tage".
def format_duration(seconds)
  seconds = seconds.to_i
  if seconds < 60
    '< 1 min'
  elsif seconds < 3600
    "#{seconds / 60} min"
  elsif seconds < 86_400
    "#{seconds / 3600} h"
  else
    days = seconds / 86_400
    days == 1 ? '1 Tag' : "#{days} Tage"
  end
end

# Bewertet, ob der vzlogger lebt und die Middleware Daten erhält.
#
# last_local_success:    Time des letzten erfolgreichen Abrufs von Port 8081 (nil = seit Start nie)
# last_middleware_tuple: Ergebnis von VzMiddlewareClient.fetch: Time | :empty | :error | :db_error (nil = :empty)
# now:                   aktuelle Zeit (testbar ohne Stubbing)
# threshold:             Sekunden, ab denen ein Wert als veraltet gilt
# Rückgabe: { status: 'ok' | 'warning', message: String }
def vzlogger_status(last_local_success, last_middleware_tuple, now = Time.now, threshold = STATUS_THRESHOLD_SECONDS)
  problems = []

  if last_local_success.nil?
    problems << 'vzlogger: seit Start keine Daten'
  elsif now - last_local_success > threshold
    problems << "vzlogger offline seit #{format_duration(now - last_local_success)}"
  end

  case last_middleware_tuple
  when :error    then problems << 'Middleware nicht erreichbar'
  when :db_error then problems << 'Middleware: Datenbank nicht erreichbar'
  when :empty, nil then problems << 'Middleware: keine Daten'
  else
    if now - last_middleware_tuple > threshold
      problems << "Middleware erhält keine Daten seit #{format_duration(now - last_middleware_tuple)}"
    end
  end

  return { status: 'ok', message: 'vzlogger OK' } if problems.empty?

  { status: 'warning', message: problems.join(' / ') }
end

if defined?(SCHEDULER)
  # Bewusst ohne first_in => 0: Der Grid-Client braucht nach dem Start erst einen Abruf.
  SCHEDULER.every '60s', :overlap => false do
    result = vzlogger_status(GridMeasurements.last_success_at, VzMiddlewareClient.fetch)
    warning = result[:status] == 'warning'

    $vzlogger_warning = warning ? result[:message] : nil
    send_event('vzlogger_status', {
      title: 'vzlogger',
      text: result[:message],
      warning: warning,
      ok: !warning
    })
  end
end
