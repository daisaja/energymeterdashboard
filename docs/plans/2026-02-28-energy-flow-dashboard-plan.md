# Energy Flow Dashboard Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** New Smashing dashboard `energyflow.erb` with animated SVG energy flow widget showing real-time power flows between Solar, Grid, Powerwall, House and Heat pump.

**Architecture:** Two parallel PRs — PR 1 (Ruby job + TDD, Agent A) and PR 2 (SVG widget + dashboard, Agent B). The job sends a single `energyflow` event with all instantaneous W values. Detail kacheln in the dashboard reuse existing event IDs from existing jobs. PR 3 (optional) adds Tesla Wall Connector.

**Tech Stack:** Ruby/Smashing, Minitest + WebMock, SVG + CSS keyframe animation, CoffeeScript (Dashing widget pattern), HTTParty.

---

## PR 1: Core Job + Tests (Agent A)

**Branch:** `feature/energyflow-job`
**Start:** `git checkout master && git pull && git checkout -b feature/energyflow-job`

### Relevant existing files to read first
- `jobs/grid_watts.rb` — how GridMeasurements + SolarMeasurements + OpenDTU are used
- `jobs/powerwall.rb` — how PowerwallClient is used (`.power_watts`, `.soc_percent`)
- `jobs/meter_helper/heating_meter_client.rb` — HeatingMeasurements API (`.heating_watts_current`)
- `test/grid_watts_test.rb` — WebMock stub patterns to copy
- `jobs/energy_meter_summary.rb` — `current_consumption` helper pattern

---

### Task 1: Create test file skeleton

**Files:**
- Create: `test/energyflow_test.rb`

**Step 1: Create the test file**

```ruby
require 'minitest/autorun'
require 'ostruct'
require_relative '../jobs/energyflow'

class EnergyflowTest < Minitest::Test
  # Tests will go here
end
```

**Step 2: Run to verify it loads**

```bash
bundle exec ruby -Itest test/energyflow_test.rb
```
Expected: `0 runs, 0 assertions, 0 failures, 0 errors`

---

### Task 2: Write failing test — house consumption formula

The house consumption formula is:
`house_w = solar_w + grid_supply_w - grid_feed_w + battery_discharge_w`

Battery discharge = max(-battery_w, 0) because battery_w positive = charging (power flowing IN to battery).

**Step 1: Add test**

```ruby
def test_house_consumption_solar_only
  # Solar produces 2400W, nothing else active
  payload = build_energyflow_payload(
    OpenStruct.new(grid_supply_current: 0.0, grid_feed_current: 0.0),
    OpenStruct.new(solar_watts_current: 2400),
    OpenStruct.new(power_watts: 0.0, soc_percent: 80),
    OpenStruct.new(heating_watts_current: 0)
  )
  assert_equal 2400, payload[:house_w]
  assert_equal 2400, payload[:solar_w]
  assert_equal 0,    payload[:grid_w]
end

def test_house_consumption_grid_supply
  # 1kW from grid, 0 solar
  payload = build_energyflow_payload(
    OpenStruct.new(grid_supply_current: 1.0, grid_feed_current: 0.0),
    OpenStruct.new(solar_watts_current: 0),
    OpenStruct.new(power_watts: 0.0, soc_percent: 50),
    OpenStruct.new(heating_watts_current: 0)
  )
  assert_equal 1000, payload[:house_w]
  assert_equal 1000, payload[:grid_w]   # positive = supply (Bezug)
end

def test_grid_w_negative_when_feeding_in
  # Solar produces 3kW, house uses 1kW → feed 2kW
  payload = build_energyflow_payload(
    OpenStruct.new(grid_supply_current: 0.0, grid_feed_current: 2.0),
    OpenStruct.new(solar_watts_current: 3000),
    OpenStruct.new(power_watts: 0.0, soc_percent: 100),
    OpenStruct.new(heating_watts_current: 0)
  )
  assert_equal(-2000, payload[:grid_w])   # negative = Einspeisung
  assert_equal 1000,  payload[:house_w]   # 3000 - 2000 = 1000W house
end

def test_battery_discharge_adds_to_house
  # Battery discharges 500W (power_watts = -500)
  payload = build_energyflow_payload(
    OpenStruct.new(grid_supply_current: 0.0, grid_feed_current: 0.0),
    OpenStruct.new(solar_watts_current: 1000),
    OpenStruct.new(power_watts: -500.0, soc_percent: 60),
    OpenStruct.new(heating_watts_current: 0)
  )
  assert_equal(-500, payload[:battery_w])
  assert_equal 1500, payload[:house_w]    # 1000 solar + 500 discharge
end

def test_battery_charging_does_not_add_to_house
  # Battery charges 800W (power_watts = +800) — charging takes power FROM house, not adds
  payload = build_energyflow_payload(
    OpenStruct.new(grid_supply_current: 0.0, grid_feed_current: 0.0),
    OpenStruct.new(solar_watts_current: 3000),
    OpenStruct.new(power_watts: 800.0, soc_percent: 40),
    OpenStruct.new(heating_watts_current: 0)
  )
  assert_equal 800,  payload[:battery_w]
  assert_equal 3000, payload[:house_w]   # battery_discharge = 0, so house = solar only
end

def test_heatpump_w_from_heating_client
  payload = build_energyflow_payload(
    OpenStruct.new(grid_supply_current: 0.5, grid_feed_current: 0.0),
    OpenStruct.new(solar_watts_current: 0),
    OpenStruct.new(power_watts: 0.0, soc_percent: 70),
    OpenStruct.new(heating_watts_current: 600)
  )
  assert_equal 600, payload[:heatpump_w]
end

def test_battery_soc_included
  payload = build_energyflow_payload(
    OpenStruct.new(grid_supply_current: 0.0, grid_feed_current: 0.0),
    OpenStruct.new(solar_watts_current: 0),
    OpenStruct.new(power_watts: 0.0, soc_percent: 78),
    OpenStruct.new(heating_watts_current: 0)
  )
  assert_equal 78, payload[:battery_soc]
end
```

**Step 2: Run to confirm all fail**

```bash
bundle exec ruby -Itest test/energyflow_test.rb
```
Expected: `NoMethodError: undefined method 'build_energyflow_payload'`

---

### Task 3: Implement `energyflow.rb` job

**Files:**
- Create: `jobs/energyflow.rb`

**Step 1: Write the job with the testable helper extracted**

```ruby
require_relative 'meter_helper/grid_meter_client'
require_relative 'meter_helper/solar_meter_client'
require_relative 'meter_helper/opendtu_meter_client'
require_relative 'meter_helper/powerwall_client'
require_relative 'meter_helper/heating_meter_client'

if defined?(SCHEDULER)
  SCHEDULER.every '3s', :first_in => 0 do |job|
    begin
      grid     = GridMeasurements.new
      solar    = SolarMeasurements.new
      opendtu  = OpenDTUMeterClient.new
      powerwall = PowerwallClient.new
      heating  = HeatingMeasurements.new

      # Combine SMA inverter + OpenDTU (same pattern as solar_watts.rb)
      combined_solar = OpenStruct.new(
        solar_watts_current: solar.solar_watts_current + opendtu.power_watts
      )

      payload = build_energyflow_payload(grid, combined_solar, powerwall, heating)
      send_event('energyflow', payload)
    rescue => e
      puts "[EnergyFlow] Error: #{e.message}"
    end
  end
end

# Extracted for testability — takes duck-typed client objects
def build_energyflow_payload(grid, solar, powerwall, heating)
  solar_w       = solar.solar_watts_current.to_f
  grid_supply_w = (grid.grid_supply_current * 1000).round(0)
  grid_feed_w   = (grid.grid_feed_current * 1000).round(0)
  battery_w     = powerwall.power_watts.to_f
  heatpump_w    = heating.heating_watts_current.to_f

  # positive = Bezug (supply from grid), negative = Einspeisung (feed into grid)
  grid_w = grid_supply_w - grid_feed_w

  # Battery: positive = charging, negative = discharging
  # Discharge adds to available power (makes house consumption appear higher)
  battery_discharge = [-battery_w, 0].max
  house_w = solar_w + grid_supply_w - grid_feed_w + battery_discharge

  {
    solar_w:     solar_w.round(0),
    grid_w:      grid_w,
    battery_w:   battery_w.round(0),
    battery_soc: powerwall.soc_percent,
    house_w:     house_w.round(0),
    heatpump_w:  heatpump_w.round(0)
  }
end
```

Note: `require 'ostruct'` is needed in tests (already in Gemfile). The job itself uses real clients; tests use OpenStruct mocks.

**Step 2: Run tests**

```bash
bundle exec ruby -Itest test/energyflow_test.rb
```
Expected: All 7 tests pass, 0 failures.

**Step 3: Commit**

```bash
git add jobs/energyflow.rb test/energyflow_test.rb
git commit -m "feat: add energyflow job with TDD

Aggregator job sending real-time W values for all energy sources
and consumers as single 'energyflow' event.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 4: Full test suite check + PR

**Step 1: Run complete test suite**

```bash
bundle exec ruby -r simplecov -Itest test/unit_test.rb
```
Expected: All existing tests still pass (energyflow.rb adds no SCHEDULER call when SCHEDULER undefined).

**Step 2: Push and open PR**

```bash
git push -u origin feature/energyflow-job
gh pr create \
  --title "feat: energy flow aggregator job" \
  --body "Adds energyflow.rb job with build_energyflow_payload helper (fully tested with OpenStruct mocks). Sends single 'energyflow' event with solar_w, grid_w, battery_w, battery_soc, house_w, heatpump_w every 3s."
```

---

## PR 2: Widget + Dashboard (Agent B)

**Branch:** `feature/energyflow-widget`
**Start:** `git checkout master && git pull && git checkout -b feature/energyflow-widget`

**Note:** Can be developed in parallel with PR 1. The widget is standalone — test with fixture data in browser.

### Relevant existing files to read first
- `widgets/number/number.html` + `number.coffee` — existing widget pattern
- `widgets/meter/meter.html` — existing widget pattern
- `dashboards/teslawall.erb` — most recent dashboard, copy structure
- `config/smashing` or `Dashing.config` — check column count if unsure

---

### Task 5: Create widget directory + HTML (SVG)

**Files:**
- Create: `widgets/energyflow/energyflow.html`

**Step 1: Create the SVG widget HTML**

The SVG uses `viewBox="0 0 760 360"` and scales to the widget container.
Nodes are SVG groups at fixed positions. Paths connect them.
Font Awesome is available as icon font (already in Smashing).

```html
<div class="energyflow-container">
  <svg viewBox="0 0 760 360" xmlns="http://www.w3.org/2000/svg" class="energyflow-svg">

    <!-- ═══ FLOW PATHS (drawn behind nodes) ═══ -->

    <!-- Solar → Haus (top to center, downward) -->
    <path data-flow="solar-house"
          class="flow-path"
          d="M 380,115 L 380,162"/>

    <!-- Grid ↔ Haus (left to center, horizontal) -->
    <!-- Same path used for Bezug (forward) and Einspeisung (reverse) -->
    <path data-flow="grid-house"
          class="flow-path"
          d="M 140,200 L 332,200"/>

    <!-- Haus → WP (center to right, horizontal) -->
    <path data-flow="house-heatpump"
          class="flow-path"
          d="M 428,200 L 620,200"/>

    <!-- Haus ↔ Akku (center to bottom, downward) -->
    <!-- Same path: forward = charging, reverse = discharging -->
    <path data-flow="house-battery"
          class="flow-path"
          d="M 380,238 L 380,292"/>

    <!-- ═══ NODES ═══ -->

    <!-- Solar: top center (380, 75) -->
    <g class="ef-node" id="node-solar" transform="translate(380,75)">
      <circle class="node-circle solar" r="40"/>
      <text class="node-icon" font-family="FontAwesome" font-size="22" text-anchor="middle" dy="-5">&#xf185;</text>
      <text class="node-label" text-anchor="middle" dy="10">Solar</text>
      <text class="node-value" id="val-solar" text-anchor="middle" dy="26">-- W</text>
    </g>

    <!-- Grid: left middle (90, 200) -->
    <g class="ef-node" id="node-grid" transform="translate(90,200)">
      <circle class="node-circle grid" r="40"/>
      <text class="node-icon" font-family="FontAwesome" font-size="22" text-anchor="middle" dy="-5">&#xf0e7;</text>
      <text class="node-label" id="lbl-grid" text-anchor="middle" dy="10">Netz</text>
      <text class="node-value" id="val-grid" text-anchor="middle" dy="26">-- W</text>
    </g>

    <!-- Haus: center (380, 200) -->
    <g class="ef-node" id="node-house" transform="translate(380,200)">
      <circle class="node-circle house" r="46"/>
      <text class="node-icon" font-family="FontAwesome" font-size="26" text-anchor="middle" dy="-6">&#xf015;</text>
      <text class="node-label" text-anchor="middle" dy="12">Haus</text>
      <text class="node-value" id="val-house" text-anchor="middle" dy="28">-- W</text>
    </g>

    <!-- Wärmepumpe: right middle (670, 200) -->
    <g class="ef-node" id="node-heatpump" transform="translate(670,200)">
      <circle class="node-circle heatpump" r="40"/>
      <text class="node-icon" font-family="FontAwesome" font-size="22" text-anchor="middle" dy="-5">&#xf06d;</text>
      <text class="node-label" text-anchor="middle" dy="10">WP</text>
      <text class="node-value" id="val-heatpump" text-anchor="middle" dy="26">-- W</text>
    </g>

    <!-- Akku: bottom center (380, 330) -->
    <g class="ef-node" id="node-battery" transform="translate(380,330)">
      <circle class="node-circle battery" r="40"/>
      <text class="node-icon" font-family="FontAwesome" font-size="22" text-anchor="middle" dy="-8">&#xf240;</text>
      <text class="node-soc" id="val-soc" text-anchor="middle" dy="6">--%</text>
      <text class="node-value" id="val-battery" text-anchor="middle" dy="22">-- W</text>
    </g>

  </svg>
</div>

<p class="updated-at" data-bind="updatedAtMessage"></p>
```

**Step 2: No test — verify by opening dashboard in browser after Task 9.**

---

### Task 6: Create widget SCSS

**Files:**
- Create: `widgets/energyflow/energyflow.scss`

```scss
.widget-energyflow {
  padding: 5px;

  .energyflow-container {
    width: 100%;
    height: calc(100% - 20px);
  }

  .energyflow-svg {
    width: 100%;
    height: 100%;
  }

  // ─── Flow paths ───────────────────────────────────────────
  .flow-path {
    fill: none;
    stroke: rgba(255, 255, 255, 0.12);
    stroke-width: 5;
    stroke-linecap: round;
    stroke-dasharray: none;
    transition: stroke 0.5s ease;

    &.active {
      stroke: rgba(255, 255, 255, 0.75);
      stroke-dasharray: 8 18;
      animation: flow-forward 1.8s linear infinite;
    }

    &.active.reverse {
      animation: flow-reverse 1.8s linear infinite;
    }
  }

  @keyframes flow-forward {
    from { stroke-dashoffset: 26; }
    to   { stroke-dashoffset: 0; }
  }

  @keyframes flow-reverse {
    from { stroke-dashoffset: 0; }
    to   { stroke-dashoffset: 26; }
  }

  // ─── Nodes ────────────────────────────────────────────────
  .node-circle {
    stroke: rgba(255, 255, 255, 0.25);
    stroke-width: 2;

    &.solar    { fill: #c8860a; }  // amber
    &.grid     { fill: #2a6db5; }  // blue
    &.house    { fill: #4a4a6a; }  // dark blue-grey
    &.heatpump { fill: #a0522d; }  // sienna
    &.battery  { fill: #2e7d32; }  // green
  }

  .node-icon {
    fill: rgba(255, 255, 255, 0.9);
  }

  .node-label {
    fill: rgba(255, 255, 255, 0.65);
    font-size: 11px;
    font-weight: 300;
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }

  .node-value {
    fill: #ffffff;
    font-size: 13px;
    font-weight: 600;
  }

  .node-soc {
    fill: #a5d6a7;
    font-size: 13px;
    font-weight: 600;
  }

  // ─── Bottom label ─────────────────────────────────────────
  .updated-at {
    font-size: 10px;
    opacity: 0.5;
  }
}
```

**Step 2: No automated test — verify visually in browser.**

---

### Task 7: Create widget CoffeeScript

**Files:**
- Create: `widgets/energyflow/energyflow.coffee`

```coffeescript
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
```

**Step 2: No automated test — verify in browser after Task 9.**

---

### Task 8: Create dashboard ERB

**Files:**
- Create: `dashboards/energyflow.erb`

The detail kacheln on the right reuse **existing event IDs** from already-running jobs — no extra job code needed.

```erb
<div class="gridster">
  <ul>

    <!-- ═══ 4×2 Energy Flow Widget ═══ -->
    <li data-row="1" data-col="1" data-sizex="4" data-sizey="2">
      <div data-id="energyflow"
           data-view="Energyflow"
           data-title=""
           style="background: linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%);">
      </div>
    </li>

    <!-- ═══ Detail Kacheln (rechts, 1×1 je) ═══ -->

    <!-- Solar Tagesproduktion — Event von solar_production_per_day.rb -->
    <li data-row="1" data-col="5" data-sizex="1" data-sizey="1">
      <div data-id="wattmetersolar_sum"
           data-view="Number"
           data-title="Solar heute"
           data-moreinfo="kWh"
           style="background-color:#c8860a;">
      </div>
    </li>

    <!-- Powerwall SOC — Event von powerwall.rb -->
    <li data-row="1" data-col="6" data-sizex="1" data-sizey="1">
      <div data-id="powerwall_soc"
           data-view="Meter"
           data-title="Akku"
           data-moreinfo="Ladestand in %"
           data-min="0"
           data-max="100"
           style="background-color:#2e7d32;">
      </div>
    </li>

    <!-- Netzbezug heute — Event von grid_consumption_per_day.rb -->
    <li data-row="2" data-col="5" data-sizex="1" data-sizey="1">
      <div data-id="meter_grid_supply_sum"
           data-view="Number"
           data-title="Netzbezug"
           data-moreinfo="kWh heute"
           style="background-color:#2a6db5;">
      </div>
    </li>

    <!-- Wärmepumpe heute — Event von heating_consumption_per_day.rb -->
    <li data-row="2" data-col="6" data-sizex="1" data-sizey="1">
      <div data-id="wattmeterheating_sum"
           data-view="Number"
           data-title="Wärmepumpe"
           data-moreinfo="kWh heute"
           style="background-color:#a0522d;">
      </div>
    </li>

  </ul>
</div>
```

**Note on column count:** The dashboard uses 6 columns (4 for widget + 2 for kacheln). Verify `config/smashing` for `columns` setting. If default is 5, adjust by making the flow widget 3×2 or the kacheln stacked differently.

---

### Task 9: Manual browser verification + commit + PR

**Step 1: Start Smashing locally**

```bash
docker run -p 3030:3030 --env-file .env daisaja/energymeter:latest
```
Or locally: `bundle exec smashing start`

**Step 2: Open dashboard**

Navigate to `http://localhost:3030/energyflow`

**Verify:**
- [ ] SVG renders with 5 nodes (Solar, Netz, Haus, WP, Akku)
- [ ] All node circles visible with correct colors
- [ ] Flow paths visible as faint lines
- [ ] When energyflow job runs: values update, paths animate
- [ ] Grid path shows `Einspeisung` label and reverse animation when feeding in
- [ ] Battery path reverses when discharging
- [ ] Detail kacheln (right side) show values from existing jobs
- [ ] Animation speed varies with watt values

**Step 3: Commit**

```bash
git add widgets/energyflow/ dashboards/energyflow.erb
git commit -m "feat: add energyflow widget and dashboard

SVG energy flow widget with CSS keyframe animation.
5 nodes: Solar, Netz, Haus, Wärmepumpe, Akku.
Bidirectional paths for grid (Bezug/Einspeisung) and battery
(Laden/Entladen). Animation speed scales with watt values.
Detail kacheln reuse existing event IDs.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

**Step 4: Push and open PR**

```bash
git push -u origin feature/energyflow-widget
gh pr create \
  --title "feat: energy flow SVG widget and dashboard" \
  --body "Adds energyflow widget (4x2) with SVG animation and energyflow.erb dashboard. Depends on: feature/energyflow-job PR."
```

---

## PR 3: Tesla Wall Connector (optional, later)

**Branch:** `feature/wallconnector`
**Prerequisites:** PR 1 + PR 2 merged

### What to build

1. `jobs/meter_helper/wallconnector_client.rb` — HTTP client for local TWC API
2. `test/wallconnector_client_test.rb` — WebMock tests
3. Extend `jobs/energyflow.rb` — add `ev_w` to payload
4. Extend `widgets/energyflow/energyflow.html` — add 🚗 EV node (right side, below WP)
5. Extend `widgets/energyflow/energyflow.coffee` — handle `ev_w` flow

### WallConnector API

```ruby
# Required env var: WALLCONNECTOR_HOST
GET http://#{WALLCONNECTOR_HOST}/api/1/vitals
# Returns JSON with: vehicle_connected (bool), session_energy_wh (float),
#   voltageA_v, currentA_a, voltageB_v, currentB_a, voltageC_v, currentC_a

GET http://#{WALLCONNECTOR_HOST}/api/1/lifetime
# Returns JSON with: energy_wh (cumulative float)
```

```ruby
# Power calculation:
ev_w = (voltageA * currentA) + (voltageB * currentB) + (voltageC * currentC)
```

### Client skeleton (pattern: copy from opendtu_meter_client.rb)

```ruby
require 'httparty'

WALLCONNECTOR_HOST = ENV['WALLCONNECTOR_HOST']

class WallConnectorClient
  @@last_values = {}

  attr_reader :power_watts, :vehicle_connected, :session_energy_wh

  def initialize
    fetch_vitals
  end

  private

  def fetch_vitals
    response = HTTParty.get("http://#{WALLCONNECTOR_HOST}/api/1/vitals")
    data = response.parsed_response
    @vehicle_connected  = data['vehicle_connected']
    @session_energy_wh  = data['session_energy_wh'].to_f
    @power_watts = (data['voltageA_v'].to_f * data['currentA_a'].to_f) +
                   (data['voltageB_v'].to_f * data['currentB_a'].to_f) +
                   (data['voltageC_v'].to_f * data['currentC_a'].to_f)
    save_values
  rescue Errno::EHOSTUNREACH, Errno::ECONNREFUSED => e
    puts "[WallConnector] Not reachable: #{e.message}"
    restore_last_values
  end

  def save_values
    @@last_values = { power_watts: @power_watts,
                      vehicle_connected: @vehicle_connected,
                      session_energy_wh: @session_energy_wh }
  end

  def restore_last_values
    @power_watts       = @@last_values[:power_watts] || 0.0
    @vehicle_connected = @@last_values[:vehicle_connected] || false
    @session_energy_wh = @@last_values[:session_energy_wh] || 0.0
  end
end
```

### EV Node placement in SVG

Add below Wärmepumpe (right side, row 2):

```html
<!-- EV: right lower (670, 310) -->
<g class="ef-node" id="node-ev" transform="translate(670,310)">
  <circle class="node-circle ev" r="40"/>
  <text class="node-icon" font-family="FontAwesome" font-size="22" text-anchor="middle" dy="-5">&#xf1b9;</text>
  <text class="node-label" text-anchor="middle" dy="10">Auto</text>
  <text class="node-value" id="val-ev" text-anchor="middle" dy="26">-- W</text>
</g>
```

Add path `house-ev`: `M 428,218 Q 560,270 630,295`
Add to SCSS: `.ev { fill: #c62828; }` (Tesla red)

---

## Agent Dispatch Instructions

### For dispatching-parallel-agents skill:

**Agent A task (PR 1):**
> Implement PR 1 from the plan at `docs/plans/2026-02-28-energy-flow-dashboard-plan.md`. Tasks 1-4. Branch: `feature/energyflow-job`. Follow TDD strictly: write failing tests first, then implement. Run full test suite at the end.

**Agent B task (PR 2):**
> Implement PR 2 from the plan at `docs/plans/2026-02-28-energy-flow-dashboard-plan.md`. Tasks 5-9. Branch: `feature/energyflow-widget`. Read the design doc at `docs/plans/2026-02-28-energy-flow-dashboard-design.md` for context. Create widget HTML, SCSS, CoffeeScript, and dashboard ERB exactly as specified.
