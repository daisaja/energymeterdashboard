# Weather in Energyflow Widget – Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Wetterdaten (Temperatur, Icon, Wind, 2-Tages-Forecast) oben-rechts im Energyflow-SVG anzeigen.

**Architecture:** Das Energyflow-Widget subscribt über `Dashing.on 'weather_temperature'` manuell auf einen zweiten Event. `weather.rb` und `energyflow.rb` bleiben unverändert. Alle Änderungen sind rein frontend: HTML (SVG-Elemente), SCSS (Styling), CoffeeScript (Event-Handler + Icon-Mapping).

**Tech Stack:** Smashing (Dashing fork), SVG, CoffeeScript, SCSS

---

## Hintergrund

- SVG viewBox: `0 0 760 360`
- Solar-Node: `translate(380,75)` r=40 → belegt x:340–420, y:35–115
- Freie Fläche oben-rechts: x≈455–752, y≈15–115
- Weather-Event: `weather_temperature` mit Feldern `current` (Temp), `climacon_code`, `wind_speed`, `forecast1`, `forecast1_climacon`, `forecast1_day`, `forecast2`, `forecast2_climacon`, `forecast2_day`
- Climacon-Codes sind Zahlen (32=Sonne, 26=Wolke+Sonne, 20=Nebel, 12=Regen, etc.)

---

## Task 1: SVG-Wetter-Panel in `energyflow.html` einfügen

**Files:**
- Modify: `widgets/energyflow/energyflow.html`

**Step 1: Wetter-Gruppe vor dem schließenden `</svg>` einfügen**

Füge diese `<g>`-Gruppe direkt vor `</svg>` ein (nach dem Akku-Node):

```html
    <!-- ═══ WEATHER PANEL (top-right) ═══ -->
    <g id="weather-panel">
      <!-- Current weather: icon + temperature -->
      <text id="weather-icon"
            class="weather-icon"
            x="471" y="44"
            text-anchor="middle">--</text>
      <text id="weather-temp"
            class="weather-temp"
            x="497" y="44">--°</text>

      <!-- Wind speed -->
      <text id="weather-wind"
            class="weather-wind"
            x="497" y="60">-- km/h</text>

      <!-- Separator line -->
      <line class="weather-separator" x1="455" y1="68" x2="752" y2="68"/>

      <!-- Forecast 1 -->
      <g id="fc1-group" transform="translate(490, 0)">
        <text id="fc1-day"  class="weather-fc-day"  x="0" y="83">---</text>
        <text id="fc1-icon" class="weather-fc-icon" x="0" y="100">--</text>
        <text id="fc1-temp" class="weather-fc-temp" x="0" y="114">--</text>
      </g>

      <!-- Forecast 2 -->
      <g id="fc2-group" transform="translate(625, 0)">
        <text id="fc2-day"  class="weather-fc-day"  x="0" y="83">---</text>
        <text id="fc2-icon" class="weather-fc-icon" x="0" y="100">--</text>
        <text id="fc2-temp" class="weather-fc-temp" x="0" y="114">--</text>
      </g>
    </g>
```

**Step 2: Datei vergleichen / prüfen**

Öffne `widgets/energyflow/energyflow.html` und stelle sicher:
- Die `<g id="weather-panel">` steht vor `</svg>` (nach dem Akku-Node `</g>`)
- Alle IDs sind korrekt: `weather-icon`, `weather-temp`, `weather-wind`, `fc1-day`, `fc1-icon`, `fc1-temp`, `fc2-day`, `fc2-icon`, `fc2-temp`

**Step 3: Commit**

```bash
git add widgets/energyflow/energyflow.html
git commit -m "feat: add weather panel SVG elements to energyflow widget"
```

---

## Task 2: CSS-Styling in `energyflow.scss`

**Files:**
- Modify: `widgets/energyflow/energyflow.scss`

**Step 1: Wetter-Styles am Ende des `.widget-energyflow`-Blocks einfügen**

Füge vor der letzten schließenden `}` des `.widget-energyflow`-Blocks ein:

```scss
  // ─── Weather panel (top-right) ────────────────────────
  .weather-icon {
    fill: rgba(255, 255, 255, 0.95);
    font-size: 22px;
  }

  .weather-temp {
    fill: #ffffff;
    font-size: 20px;
    font-weight: 600;
  }

  .weather-wind {
    fill: rgba(255, 255, 255, 0.55);
    font-size: 12px;
    font-weight: 300;
  }

  .weather-separator {
    stroke: rgba(255, 255, 255, 0.15);
    stroke-width: 1;
  }

  .weather-fc-day {
    fill: rgba(255, 255, 255, 0.55);
    font-size: 11px;
    font-weight: 300;
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }

  .weather-fc-icon {
    fill: rgba(255, 255, 255, 0.9);
    font-size: 17px;
  }

  .weather-fc-temp {
    fill: rgba(255, 255, 255, 0.75);
    font-size: 11px;
  }
```

**Step 2: Commit**

```bash
git add widgets/energyflow/energyflow.scss
git commit -m "feat: add weather panel styles to energyflow widget"
```

---

## Task 3: CoffeeScript – Weather-Event subscriben und Panel befüllen

**Files:**
- Modify: `widgets/energyflow/energyflow.coffee`

**Step 1: Climacon→Emoji-Map und Dashing.on-Handler hinzufügen**

Füge am **Anfang** der Klasse (direkt nach `class Dashing.Energyflow extends Dashing.Widget`) ein:

```coffeescript
  CLIMACON_TO_EMOJI =
    32: '☀'   # Sonne
    26: '⛅'  # Wolke + Sonne
    20: '🌫'  # Nebel
    12: '🌧'  # Regen
    11: '🌧'  # Regenschauer
    9:  '🌦'  # Nieselregen
    18: '🌨'  # Gefrierender Regen / Schneeregen
    16: '❄'   # Schnee
    17: '❄'   # Schneekörner
    6:  '⚡'  # Gewitter
```

Füge dann in der `ready:`-Methode (oder als neue Methode nach `ready:`) den zweiten Event-Listener ein:

```coffeescript
  ready: ->
    # Initial state: all paths inactive
    paths = @node.querySelectorAll('.flow-path')
    path.classList.remove('active', 'reverse') for path in paths

    # Subscribe to weather event (independent of energyflow event)
    self = @
    Dashing.on 'weather_temperature', (event, data) ->
      return unless data
      self.updateWeather(data)
```

Füge am Ende der Klasse die `updateWeather`-Methode hinzu:

```coffeescript
  updateWeather: (data) ->
    icon = CLIMACON_TO_EMOJI[data.climacon_code] or '?'
    @setText('weather-icon', icon)
    @setText('weather-temp', "#{data.current}°")
    @setText('weather-wind', "≈ #{data.wind_speed} km/h")

    fc1Icon = CLIMACON_TO_EMOJI[data.forecast1_climacon] or '?'
    @setText('fc1-day',  data.forecast1_day)
    @setText('fc1-icon', fc1Icon)
    @setText('fc1-temp', data.forecast1)

    fc2Icon = CLIMACON_TO_EMOJI[data.forecast2_climacon] or '?'
    @setText('fc2-day',  data.forecast2_day)
    @setText('fc2-icon', fc2Icon)
    @setText('fc2-temp', data.forecast2)
```

**Step 2: Vollständige Datei prüfen**

Die finale Struktur von `energyflow.coffee` sollte so aussehen:

```
class Dashing.Energyflow extends Dashing.Widget

  THRESHOLD = 50
  CLIMACON_TO_EMOJI = { ... }

  ready: ->
    # paths inactive ...
    # Dashing.on 'weather_temperature' ...

  onData: (data) ->
    # setText calls for energy values ...
    # setFlow / setSpeed calls ...

  setFlow: (flowId, active, reverse) -> ...
  setSpeed: (flowId, watts) -> ...
  setText: (id, text) -> ...
  updateWeather: (data) -> ...
```

**Step 3: Commit**

```bash
git add widgets/energyflow/energyflow.coffee
git commit -m "feat: subscribe to weather event and display in energyflow widget"
```

---

## Task 4: Manueller Test im Dashboard

**Step 1: Dashboard starten**

```bash
bundle exec smashing start
# Öffne http://localhost:3030/energyflow
```

**Step 2: Prüfen**

- [ ] Oben-rechts erscheinen Wetter-Platzhalter (`--°`, `-- km/h`)
- [ ] Nach max. 10 Minuten (oder nach `curl -d '{}' http://localhost:3030/widgets/weather_temperature`): echte Wetterdaten erscheinen
- [ ] Icon, Temperatur und Wind werden angezeigt
- [ ] Forecast-Bereich zeigt Wochentag, Icon, Min/Max-Temperatur
- [ ] Wetter-Panel überlagert keine Energie-Nodes (visuell prüfen)
- [ ] Energie-Flow (Pfeile, Werte) funktioniert weiterhin normal

**Step 3: Weather-Event manuell auslösen (für schnellen Test)**

```bash
# In einem anderen Terminal, während Dashboard läuft:
curl -d '{"current": "8.5", "climacon_code": 26, "wind_speed": "12.3", "forecast1": "6° – 12°", "forecast1_climacon": 32, "forecast1_day": "Montag", "forecast2": "8° – 15°", "forecast2_climacon": 0, "forecast2_day": "Dienstag"}' \
     http://localhost:3030/widgets/weather_temperature
```

**Step 4: Abschluss-Commit (falls kosmetische Korrekturen nötig)**

```bash
git add widgets/energyflow/
git commit -m "fix: adjust weather panel layout in energyflow widget"
```

---

## Zusammenfassung der Dateien

| Datei | Änderung |
|-------|----------|
| `widgets/energyflow/energyflow.html` | Neue `<g id="weather-panel">` mit 9 Text-/Line-Elementen |
| `widgets/energyflow/energyflow.scss` | 7 neue CSS-Klassen für Wetter-Elemente |
| `widgets/energyflow/energyflow.coffee` | `CLIMACON_TO_EMOJI`-Map, `Dashing.on`-Handler, `updateWeather()`-Methode |

**Backend-Änderung** – `weather.rb` ergänzt um `wind_speed` als separates Feld im Event-Payload.

---

## Debugging-Erkenntnisse (nach Implementierung)

### Problem 1: `Dashing.on` ist das falsche API
`Dashing.on` ist Batman.App's Lifecycle-Event-System (`'run'`, `'reload'`), kein SSE-Subscription-Mechanismus. Die Callbacks wurden nie aufgerufen.

### Problem 2: `ready:` ist zu spät für SSE-Registrierung
Smashing baut die SSE-URL in `@layout.on 'ready'` aus `Object.keys(Dashing.widgets)`. Das Verhältnis zwischen Widget-`ready:` und Layout-`ready` ist in Batman.js asynchron/unzuverlässig. **Fix: Registrierung in den Constructor verschieben** – der läuft garantiert vor dem SSE-Aufbau.

### Problem 3: `wind_speed` fehlte im Event-Payload
`weather.rb` sendete `wind_speed` nur als Teil des `moreinfo`-Strings, nicht als separates Feld. Ergebnis: `"≈ undefined km/h"` im Widget.
