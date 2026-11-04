require_relative 'meter_helper/grid_meter_client'

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

# Bewertet, ob der vzlogger lebt (letzter erfolgreicher Abruf über das lokale httpd, Port 8081).
#
# last_local_success: Time des letzten erfolgreichen Abrufs (nil = seit Start nie)
# now:                aktuelle Zeit (testbar ohne Stubbing)
# threshold:          Sekunden, ab denen der Abruf als veraltet gilt
# Rückgabe: { status: 'ok' | 'warning', message: String }
def vzlogger_status(last_local_success, now = Time.now, threshold = STATUS_THRESHOLD_SECONDS)
  if last_local_success.nil?
    { status: 'warning', message: 'vzlogger: seit Start keine Daten' }
  elsif now - last_local_success > threshold
    { status: 'warning', message: "vzlogger offline seit #{format_duration(now - last_local_success)}" }
  else
    { status: 'ok', message: 'vzlogger OK' }
  end
end

if defined?(SCHEDULER)
  # Bewusst ohne first_in => 0: Der Grid-Client braucht nach dem Start erst einen Abruf.
  SCHEDULER.every '60s', :overlap => false do
    result = vzlogger_status(GridMeasurements.last_success_at)
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
