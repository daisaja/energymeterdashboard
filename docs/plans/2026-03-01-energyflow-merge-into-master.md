# EnergyFlow Branch Merge Implementation Plan

> **Status: ABGESCHLOSSEN** – PR #50 gemergt, Branch `feature/energyflow` gelöscht (2026-03-01)

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Merge `feature/energyflow` into `master` without breaking Powerwall-Integration und Connection-Fixes, dann lokal verifizieren und Branch löschen.

**Architecture:** Option A – `master` in `feature/energyflow` mergen, Konflikte manuell auflösen (energyflow-Version bevorzugen, außer bei rescue-Strukturen), Tests laufen lassen, Smashing prüfen, PR erstellen.

**Tech Stack:** Ruby 4.0, Minitest/WebMock, Smashing/Thin, Git

---

## Bekannte Konflikte und Auflösungsregel

| Datei | Konflikt | Auflösung |
|---|---|---|
| `jobs/grid_watts.rb` | energyflow entfernt `SolarMeasurements.new()`, liest `$solar_watts_combined`; master hat `SolarMeasurements.new()` | **energyflow-Version** – architektonisch sauberer, vermeidet doppelte HTTP-Calls |
| `jobs/meter_helper/heating_meter_client.rb` | energyflow: `rescue StandardError => e` (einheitlich); master: split rescue EHOSTUNREACH + generic | **energyflow-Version** – einfacher, mit Fehlermeldung im Log |
| `jobs/powerwall.rb` | energyflow ergänzt `:overlap => false` + `$powerwall_soc_percent` | **energyflow-Version** – Erweiterung ohne Widerspruch |
| `test/heating_meter_client_test.rb` | energyflow hat 2 neue Tests, master hat teslawall-Tests | **Beide kombinieren** – alle Tests behalten |
| `test/unit_test.rb` | energyflow ergänzt `require_relative 'energyflow_test'` | **Beide kombinieren** |

---

### Task 1: Branch wechseln und Ausgangspunkt prüfen

**Files:** keine

**Step 1: Checkout energyflow branch**

```bash
git checkout feature/energyflow
```

Expected: `Zu Branch 'feature/energyflow' gewechselt`

**Step 2: Ausgangspunkt verifizieren**

```bash
git log --oneline -3
```

Expected: Top commit ist `52c7ad8 fix: eliminate duplicate HTTP calls...`

**Step 3: Working tree sauber?**

```bash
git status
```

Expected: Sauberer Stand, nur untracked `docs/` (ok).

---

### Task 2: master in energyflow mergen

**Files:** Mehrere (siehe Konfliktliste oben)

**Step 1: Merge starten**

```bash
git merge master
```

Expected: CONFLICT in mehreren Dateien.

**Step 2: Alle Konflikte auflisten**

```bash
git diff --name-only --diff-filter=U
```

Erwartete Konflikte (kann variieren):
- `jobs/grid_watts.rb`
- `jobs/meter_helper/heating_meter_client.rb`
- `jobs/powerwall.rb`
- `test/heating_meter_client_test.rb`
- `test/unit_test.rb`
- ggf. weitere

**Step 3: Konflikt lösen – `jobs/grid_watts.rb`**

**energyflow-Version behalten** (kein `SolarMeasurements.new()`, liest Globals):

```ruby
require_relative 'meter_helper/grid_meter_client'

if defined?(SCHEDULER)
  SCHEDULER.every '2s', :first_in => 0, :overlap => false do |job|
    grid_measurements = GridMeasurements.new()

    grid_supply_current = (grid_measurements.grid_supply_current * 1000).round(0)
    grid_feed_current = (grid_measurements.grid_feed_current * 1000).round(0)

    $grid_supply_kw = grid_measurements.grid_supply_current
    $grid_feed_kw   = grid_measurements.grid_feed_current

    # Read combined solar (SMA + OpenDTU) from global set by solar_watts.rb
    solar_watts_current = defined?($solar_watts_combined) ? $solar_watts_combined.to_f : 0.0
    battery_power = defined?($powerwall_battery_power) ? $powerwall_battery_power.to_f : 0.0
    house_consumption = current_consumption(solar_watts_current, grid_supply_current, grid_feed_current, battery_power)

    send_event('wattmeter_grid_supply', { value: grid_supply_current })
    send_event('wattmeter_grid_feed', { value: grid_feed_current })
    send_event('wattmeter_house_power_consumption', { value: house_consumption })
    report_grid(grid_supply_current, grid_feed_current, house_consumption)
  end
end

def current_consumption(solar_production, grid_supply, grid_feed, battery_power = 0.0)
  battery_discharge = [-battery_power, 0].max
  return solar_production + grid_supply - grid_feed + battery_discharge
end

def report_grid(grid_supply_current, grid_feed_current, current_consumption)
  reporter = InfluxExporter.new()
  hash = {
           name: 'wattmeter_grid',
           tags: {meter_type: 'grid'},
           fields: {wattmeter_grid_supply: grid_supply_current, wattmeter_grid_feed: grid_feed_current, wattmeter_house_power_consumption: current_consumption.to_i},
         }
  reporter.send_data(hash)
end
```

**Step 4: Konflikt lösen – `jobs/meter_helper/heating_meter_client.rb`**

**energyflow-Version** für den äußeren rescue (einfacher, mit `e.message`):

```ruby
  rescue StandardError => e
    puts "[HeatingMeter] Verbindung zu #{HEATING_METER_HOST} fehlgeschlagen: #{e.message}"
    restore_last_values
```

Kein split-rescue (kein separater `Errno::EHOSTUNREACH`-Block).

**Step 5: Konflikt lösen – `jobs/powerwall.rb`**

**energyflow-Version** behalten (`:overlap => false` + `$powerwall_soc_percent`):

```ruby
SCHEDULER.every '5s', :first_in => 0, :overlap => false do |job|
  client = PowerwallClient.new

  $powerwall_battery_power = client.power_watts
  $powerwall_soc_percent   = client.soc_percent

  send_event('powerwall_soc',    { value: client.soc_percent })
  send_event('powerwall_power',  { current: client.power_watts })
  send_event('powerwall_energy', { value: client.energy_kwh })
end
```

**Step 6: Konflikt lösen – `test/unit_test.rb`**

**Beide kombinieren** – alle require_relative behalten, `energyflow_test` ergänzen:

```ruby
require_relative 'grid_meter_client_test'
require_relative 'solar_meter_client_test'
require_relative 'heating_meter_client_test'
require_relative 'opendtu_meter_client_test'
require_relative 'weather_test'
require_relative 'influx_exporter_test'
require_relative 'grid_watts_test'
require_relative 'state_manager_test'
require_relative 'powerwall_client_test'
require_relative 'energyflow_test'
```

**Step 7: Konflikt lösen – `test/heating_meter_client_test.rb`**

**Beide kombinieren** – teslawall-Tests + energyflow-Tests alle behalten. Die 2 neuen Tests aus energyflow ans Ende der Klasse hängen:
- `test_socket_error_falls_back_to_last_values`
- `test_current_watts_preserved_when_secondary_requests_fail`

**Step 8: Alle weiteren Konflikte prüfen**

```bash
git diff --name-only --diff-filter=U
```

Für alle verbleibenden Konflikte: energyflow-Version bevorzugen (sind Erweiterungen, keine Widersprüche). Conflict-Marker entfernen.

**Step 9: Merge-Konfliktmarker prüfen**

```bash
grep -rn "<<<<<<\|======\|>>>>>>" jobs/ test/ 2>/dev/null
```

Expected: keine Ausgabe

**Step 10: Merge abschließen**

```bash
git add -A
git commit --no-edit
```

---

### Task 3: Tests laufen lassen

**Files:** `test/`

**Step 1: Gesamten Test-Suite ausführen**

```bash
export $(cat .env | grep -v '^#' | xargs) && bundle exec ruby -r simplecov -Itest test/unit_test.rb 2>&1
```

Expected: Alle Tests grün. Falls Failures → analysieren und beheben, dann committen.

**Step 2: Energyflow-Tests einzeln**

```bash
export $(cat .env | grep -v '^#' | xargs) && bundle exec ruby -Itest test/energyflow_test.rb 2>&1
```

Expected: Grün.

**Step 3: Heating-Tests einzeln (hat neue Tests aus energyflow)**

```bash
export $(cat .env | grep -v '^#' | xargs) && bundle exec ruby -Itest test/heating_meter_client_test.rb 2>&1
```

Expected: Grün (inkl. `test_socket_error_falls_back_to_last_values` und `test_current_watts_preserved_when_secondary_requests_fail`).

---

### Task 4: Smashing lokal starten und prüfen

**Step 1: Port freimachen**

```bash
lsof -ti :3030 | xargs kill -9 2>/dev/null; echo "Port clear"
```

**Step 2: Smashing starten und Verbindungen prüfen**

```bash
export $(cat .env | grep -v '^#' | xargs) && bundle exec smashing start > /tmp/smashing_energyflow.log 2>&1 &
sleep 10
cat /tmp/smashing_energyflow.log
```

Expected: Server startet auf Port 3030. Keine `Fehler:`-Meldungen von Meter-Clients.

**Step 3: TCP-Test aller Meter**

```bash
ruby -rsocket -e "
{
  'GridMeter'   => ['192.168.178.103', 8081],
  'OpenDTU'     => ['192.168.178.74',  80],
  'Heating'     => ['192.168.178.10',  80],
  'SolarMeter'  => ['192.168.178.37',  443],
  'Powerwall'   => ['192.168.178.147', 443],
}.each do |name, (host, port)|
  begin
    TCPSocket.new(host, port).close
    puts \"[OK]   #{name} #{host}:#{port}\"
  rescue => e
    puts \"[FAIL] #{name} #{host}:#{port} – #{e.message}\"
  end
end
"
```

Expected: Alle `[OK]`.

**Step 4: Smashing beenden**

```bash
lsof -ti :3030 | xargs kill -9 2>/dev/null
```

---

### Task 5: PR erstellen und mergen

**Step 1: Branch pushen**

```bash
git push origin feature/energyflow
```

**Step 2: PR erstellen**

```bash
gh pr create --title "feat: EnergyFlow widget, weather integration, global vars refactoring" --body "$(cat <<'EOF'
## Summary
- Adds EnergyFlow dashboard widget (`widgets/energyflow/`) mit SVG-Visualisierung
- Neues energyflow-Dashboard (`dashboards/energyflow.erb`)
- Wetter-Integration in EnergyFlow (Climacons-Icons, Temperatur, Wind)
- Globale Variablen für Job-übergreifende Datenweitergabe (`$solar_watts_combined`, `$grid_supply_kw`, `$grid_feed_kw`, `$heating_watts_current`, `$heatpump_kwh_current_day`, `$powerwall_soc_percent`)
- `:overlap => false` in allen relevanten Jobs ergänzt (grid_watts, solar_watts, heating_watts, powerwall, energy_meter_summary)
- `jobs/grid_watts.rb` refaktoriert: kein duplikater SMA-HTTP-Call, liest `$solar_watts_combined` aus `solar_watts.rb`
- `wind_speed` als separates Feld im Weather-Event
- 2 neue Tests in `heating_meter_client_test.rb` (SocketError, sekundäre Requests)

## Conflict Resolution
- `grid_watts.rb`: energyflow-Version (kein doppelter SMA-Call)
- `heating_meter_client.rb`: energyflow rescue-Struktur (einheitliches StandardError)
- `powerwall.rb`: energyflow-Version (`:overlap => false` + `$powerwall_soc_percent`)
- `test/heating_meter_client_test.rb`: beide Versionen kombiniert

## Test Results
- Alle Tests grün
- Smashing lokal gestartet, alle Meter-Clients verbunden

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

**Step 3: PR mergen**

```bash
gh pr merge --merge
```

---

### Task 6: Aufräumen

**Step 1: Zu master wechseln und pullen**

```bash
git checkout master && git pull
```

**Step 2: Branch löschen**

```bash
git branch -d feature/energyflow
git push origin --delete feature/energyflow
```

Expected: Branch lokal und remote gelöscht.

**Step 3: Memory und Plan-Dokument aktualisieren**

MEMORY.md Branch-Tabelle anpassen:
- `feature/energyflow` aus Tabelle entfernen
- `master` Commit-Hash + Inhalt aktualisieren
- EnergyFlow-Sektion ergänzen
