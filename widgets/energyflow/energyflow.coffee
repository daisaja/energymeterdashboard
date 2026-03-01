class Dashing.Energyflow extends Dashing.Widget

  THRESHOLD = 50    # Watts below which a flow is considered inactive

  # Unicode chars from Climacons-Font (matches climacons-font.css index mapping)
  CLIMACON_TO_CHAR =
    32: '\ue028'  # Sonne
    26: '\ue000'  # Wolke + Sonne
    20: '\ue01b'  # Nebel
    12: '\ue006'  # Regen
    11: '\ue006'  # Regenschauer
    9:  '\ue00c'  # Nieselregen
    18: '\ue00f'  # Schneeregen
    16: '\ue018'  # Schnee
    17: '\ue012'  # Schneekörner
    6:  '\ue015'  # Gewitter

  constructor: ->
    super
    # Register for weather_temperature events before the SSE URL is built.
    # Smashing filters SSE by Dashing.widgets keys (built at layout ready),
    # which fires AFTER ready: — so we register here in the constructor instead.
    Dashing.widgets['weather_temperature'] ||= []
    Dashing.widgets['weather_temperature'].push(@)

  ready: ->
    # Initial state: all paths inactive
    paths = @node.querySelectorAll('.flow-path')
    path.classList.remove('active', 'reverse') for path in paths

  onData: (data) ->
    return unless data

    # Route weather events — they share onData since we registered for both
    if data.id == 'weather_temperature'
      @updateWeather(data)
      return

    # ─── Update node watt displays ───────────────────────────
    @setText('val-solar',    "#{data.solar_w} W")
    @setText('val-grid',     "#{Math.abs(data.grid_w)} W")
    @setText('val-house',    "#{data.house_w} W")
    @setText('val-heatpump', "#{data.heatpump_w} W")
    @setText('val-battery',  "#{Math.abs(data.battery_w)} W")
    @setText('val-soc',      "#{data.battery_soc}%")

    # ─── Update kWh daily totals ─────────────────────────────
    @setText('val-solar-kwh',    "#{data.solar_kwh} kWh")
    @setText('val-grid-kwh',     "#{data.grid_kwh} kWh")
    @setText('val-heatpump-kwh', "#{data.heatpump_kwh} kWh")

    # Grid label flips between Bezug and Einspeisung
    @setText('lbl-grid', if data.grid_w < -THRESHOLD then 'Einspeisung' else 'Netz')

    # ─── Solar → Haus ────────────────────────────────────────
    @setFlow('solar-house', data.solar_w > THRESHOLD, false)
    @setSpeed('solar-house', data.solar_w)

    # ─── Grid ↔ Haus (same path, direction via reverse class) ─
    if data.grid_w > THRESHOLD
      @setFlow('grid-house', true, false)   # Bezug: grid → haus
    else if data.grid_w < -THRESHOLD
      @setFlow('grid-house', true, true)    # Einspeisung: haus → grid
    else
      @setFlow('grid-house', false, false)
    @setSpeed('grid-house', Math.abs(data.grid_w))

    # ─── Haus → Wärmepumpe ───────────────────────────────────
    @setFlow('house-heatpump', data.heatpump_w > THRESHOLD, false)
    @setSpeed('house-heatpump', data.heatpump_w)

    # ─── Haus ↔ Akku (same path, direction via reverse class) ─
    if data.battery_w > THRESHOLD
      @setFlow('house-battery', true, false)   # Laden: haus → akku
    else if data.battery_w < -THRESHOLD
      @setFlow('house-battery', true, true)    # Entladen: akku → haus
    else
      @setFlow('house-battery', false, false)
    @setSpeed('house-battery', Math.abs(data.battery_w))

  # Toggle active/reverse CSS classes on a flow path
  setFlow: (flowId, active, reverse) ->
    el = @node.querySelector("[data-flow='#{flowId}']")
    return unless el
    el.classList.toggle('active', active)
    el.classList.toggle('reverse', active and reverse)

  # Scale animation speed to watt value (faster = more power)
  # Range: 0.6s at 5000W → 3.0s at 0W
  setSpeed: (flowId, watts) ->
    el = @node.querySelector("[data-flow='#{flowId}']")
    return unless el
    return unless el.classList.contains('active')
    speed = Math.max(0.6, 3.0 - (watts / 2000.0))
    el.style.animationDuration = "#{speed.toFixed(1)}s"

  # Safely update SVG text content by element ID
  setText: (id, text) ->
    el = @node.querySelector("##{id}")
    el.textContent = text if el

  updateWeather: (data) ->
    @setText('weather-icon', CLIMACON_TO_CHAR[data.climacon_code] or '?')
    @setText('weather-temp', "#{data.current}°")
    @setText('weather-wind', "≈ #{data.wind_speed} km/h")
    @setText('fc1-day',  data.forecast1_day)
    @setText('fc1-icon', CLIMACON_TO_CHAR[data.forecast1_climacon] or '?')
    @setText('fc1-temp', data.forecast1)
    @setText('fc2-day',  data.forecast2_day)
    @setText('fc2-icon', CLIMACON_TO_CHAR[data.forecast2_climacon] or '?')
    @setText('fc2-temp', data.forecast2)
