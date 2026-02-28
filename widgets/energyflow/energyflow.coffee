class Dashing.Energyflow extends Dashing.Widget

  THRESHOLD = 50    # Watts below which a flow is considered inactive

  ready: ->
    # Initial state: all paths inactive
    paths = @node.querySelectorAll('.flow-path')
    path.classList.remove('active', 'reverse') for path in paths

  onData: (data) ->
    return unless data

    # ─── Update node watt displays ───────────────────────────
    @setText('val-solar',    "#{data.solar_w} W")
    @setText('val-grid',     "#{Math.abs(data.grid_w)} W")
    @setText('val-house',    "#{data.house_w} W")
    @setText('val-heatpump', "#{data.heatpump_w} W")
    @setText('val-battery',  "#{Math.abs(data.battery_w)} W")
    @setText('val-soc',      "#{data.battery_soc}%")

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
