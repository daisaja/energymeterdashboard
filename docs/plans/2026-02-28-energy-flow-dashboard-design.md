# Energy Flow Dashboard — Design Doc

**Datum:** 2026-02-28
**Status:** Approved
**Branch-Strategie:** 2 Core-PRs + 1 optionaler PR (Tesla Wall Connector)

---

## Ziel

Neues Smashing-Dashboard `energyflow.erb` das alle Energieflüsse im Haus visualisiert: Quellen (Solar, Netz, Powerwall) und Verbraucher (Haus-Grundlast, Wärmepumpe) als animiertes SVG-Diagramm mit fließenden Punkten entlang gerichteter Pfade.

---

## Scope

### In Scope (Core)
- Neues Widget `energyflow` (4×2 Kacheln, SVG + CSS-Animation)
- Neues Dashboard `energyflow.erb`
- Neuer Job `energyflow.rb` (aggregiert alle Quellen, ein Event)
- Detail-Kacheln rechts (4× Number-Widget für Tageswerte)
- TDD: `test/energyflow_test.rb`

### Optional (PR 3)
- Tesla Wall Connector als weiterer Verbraucher-Knoten
- `WallConnectorClient` via lokale HTTP-API (`/api/1/vitals`, `/api/1/lifetime`)

### Out of Scope
- Änderungen an bestehenden Dashboards/Jobs
- D3.js oder externe Charting-Libraries
- Cloud-API-Calls

---

## Architektur

### Neue Dateien

```
widgets/energyflow/
  energyflow.html    — SVG-Knoten + Pfade, data-bind für Watt-Werte
  energyflow.coffee  — onData: setzt CSS-Klassen + Werte
  energyflow.scss    — Knoten-Farben, @keyframes flow-animation

jobs/energyflow.rb   — Aggregator-Job, alle 3s, ein send_event
dashboards/energyflow.erb — Layout: 4×2 Flow-Widget + 4 Detail-Kacheln

test/energyflow_test.rb — Minitest + WebMock
```

### Bestehende Dateien (unverändert)

Alle bestehenden Jobs (`grid_watts.rb`, `powerwall.rb` etc.) bleiben unberührt.
`energyflow.rb` ruft dieselben Clients direkt auf — kein Shared-State via Globals.

---

## Datenfluss

```
GridMeasurements    ─┐
SolarMeasurements   ─┤
PowerwallClient     ─┼─► energyflow.rb (alle 3s) ─► send_event('energyflow', payload)
HeatingMeasurements ─┤                                      │
                      ┘                              energyflow Widget
                                                     (CoffeeScript onData)
```

### Event-Payload

```ruby
send_event('energyflow', {
  solar_w:       2400,   # aktuelle PV-Leistung in W
  grid_w:        -350,   # positiv = Bezug, negativ = Einspeisung
  battery_w:      800,   # positiv = Laden, negativ = Entladen
  battery_soc:     78,   # Ladestand in %
  house_w:       1850,   # Hausverbrauch gesamt in W
  heatpump_w:     600,   # Wärmepumpe in W
  solar_kwh:      12.3,  # PV-Tagesproduktion
  grid_kwh:        1.2,  # Netzbezug heute
  feed_kwh:        8.7,  # Einspeisung heute
  heatpump_kwh:    4.1   # WP-Tagesverbrauch
})
```

---

## Widget-Design

### SVG-Layout (ca. 800×400px)

```
        [☀️ Solar]
             │
[⚡ Netz] ───[🏠 Haus]─── [🌡️ WP]
             │
        [🔋 Akku]
```

Jeder Knoten: Kreis + Font-Awesome-Icon + Watt-Wert darunter.

### Knotenfarben

| Knoten     | Farbe        |
|------------|-------------|
| Solar      | `#f5a623` (Gelb) |
| Netz       | `#4a90e2` (Blau) |
| Akku       | `#7ed321` (Grün) |
| Haus       | `#ffffff` (Weiß) |
| Wärmepumpe | `#e8824a` (Orange) |

### Pfad-Aktivierungslogik (Schwellwert: 50W)

| Pfad              | Bedingung               | Richtung |
|-------------------|-------------------------|----------|
| Solar → Haus      | `solar_w > 50`          | vorwärts |
| Netz → Haus       | `grid_w > 50`           | vorwärts |
| Haus → Netz       | `grid_w < -50`          | vorwärts |
| Solar/Haus → Akku | `battery_w > 50`        | vorwärts |
| Akku → Haus       | `battery_w < -50`       | vorwärts |
| Haus → WP         | `heatpump_w > 50`       | vorwärts |

### CSS-Animation

```scss
@keyframes flow {
  from { stroke-dashoffset: 30; }
  to   { stroke-dashoffset: 0;  }
}

.flow-path.active .dot {
  animation: flow 2s linear infinite;
}
.flow-path.active.reverse .dot {
  animation: flow 2s linear infinite reverse;
}
```

Animationsgeschwindigkeit skaliert mit Leistung (stärker = schneller):

```coffeescript
speed = Math.max(0.5, 3 - watts / 2000)   # 0.5s bei 5kW, 3s bei 0W
el.style.animationDuration = "#{speed}s"
```

### CoffeeScript-Kernlogik

```coffeescript
THRESHOLD = 50

onData: (data) ->
  @setNodeValue('solar',    data.solar_w,    'W')
  @setNodeValue('grid',     Math.abs(data.grid_w), 'W')
  @setNodeValue('battery',  Math.abs(data.battery_w), 'W')
  @setNodeValue('house',    data.house_w,    'W')
  @setNodeValue('heatpump', data.heatpump_w, 'W')

  @setFlow('solar-house',   data.solar_w    >  THRESHOLD)
  @setFlow('grid-house',    data.grid_w     >  THRESHOLD)
  @setFlow('house-grid',    data.grid_w     < -THRESHOLD)
  @setFlow('house-battery', data.battery_w  >  THRESHOLD)
  @setFlow('battery-house', data.battery_w  < -THRESHOLD)
  @setFlow('house-heatpump',data.heatpump_w >  THRESHOLD)

setFlow: (path, active, reverse = false) ->
  el = @node.querySelector("[data-flow='#{path}']")
  return unless el
  el.classList.toggle('active', active)
  el.classList.toggle('reverse', reverse)
```

---

## Dashboard-Layout (`energyflow.erb`)

```
+---+---+---+---+  +--+--+
|                |  |☀️ |🔋 |
|  energyflow    |  |kWh|SOC|
|  SVG 4×2       |  +--+--+
|                |  |⚡ |🌡️ |
+---+---+---+---+  |kWh|kWh|
                    +--+--+
```

Detail-Kacheln: `energyflow_solar_kwh`, `energyflow_battery`, `energyflow_grid_kwh`, `energyflow_heatpump_kwh` — alle als Number-Widget.

---

## Testing-Strategie

**`test/energyflow_test.rb`** — Minitest + WebMock

```ruby
# Getestete Verhaltensweisen:
test "solar feeds house when solar_w > 50"
test "grid_w negative triggers feed-in direction"
test "battery_w positive means charging"
test "house_w = solar + grid_supply - grid_feed + battery_discharge"
test "heatpump_w from heating meter client"
test "flow inactive below 50W threshold"
test "graceful fallback when API unavailable"
```

View-Logik (SVG, CSS, CoffeeScript): kein automatisierter Test — manuelle Browser-Prüfung.

---

## PR-Plan

### PR 1 — Core Job + Tests
**Branch:** `feature/energyflow-job`
**Dateien:** `jobs/energyflow.rb`, `test/energyflow_test.rb`
**Agent:** Agent A (TDD, unabhängig ausführbar)

### PR 2 — Widget + Dashboard
**Branch:** `feature/energyflow-widget`
**Dateien:** `widgets/energyflow/*`, `dashboards/energyflow.erb`
**Agent:** Agent B (parallel zu PR 1, arbeitet mit Fixture-Daten)
**Abhängigkeit:** Setzt PR 1 voraus für vollständige Integration

### PR 3 — Tesla Wall Connector (optional)
**Branch:** `feature/wallconnector`
**Dateien:** `jobs/meter_helper/wallconnector_client.rb`, `test/wallconnector_client_test.rb`, Erweiterung `energyflow.rb` + Widget
**API:** `GET http://<HOST>/api/1/vitals` (lokal, kein Auth)
**Neuer Knoten:** 🚗 EV zwischen Haus und rechtem Rand

---

## Tesla Wall Connector API (für PR 3)

Lokale HTTP-API, kein API-Key:

```
GET http://<WALLCONNECTOR_HOST>/api/1/vitals
→ vehicle_connected: bool
→ session_energy_wh: float
→ voltageA_v, currentA_a (+ B, C für 3-phasig)

GET http://<WALLCONNECTOR_HOST>/api/1/lifetime
→ energy_wh: float  (kumuliert)
```

Leistung = `(voltageA_v * currentA_a) + (voltageB_v * currentB_a) + (voltageC_v * currentC_a)`
Benötigt: `WALLCONNECTOR_HOST` Umgebungsvariable (analog zu `OPENDTU_HOST`).
