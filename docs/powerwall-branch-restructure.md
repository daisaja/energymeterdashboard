# Powerwall/Teslawall-Änderungen in separaten Branch auslagern

## Kontext

Die Powerwall-Integration (PR #38, #39) verursachte Connection-Probleme auf dem Server.
Master wurde auf den stabilen Stand vor Powerwall zurückgesetzt.

**Symptom**: Server lief stabil mit Pre-Powerwall-Code, nach Deployment der Powerwall-
Änderungen traten Connection-Fehler in Grid/Solar/Heating-Clients auf.

---

## Identifizierte Ursachen

### 1. URL-Bug in `heating_meter_client.rb`

```ruby
# Alt (fehlerhaft):
YOULESS_MONTHS_URL = "http://#{HEATING_METER_HOST}/V?m=%{month}&?f=j"
#                                                              ^ stray '?'

# Fix:
YOULESS_MONTHS_URL = "http://#{HEATING_METER_HOST}/V?m=%{month}&f=j"
```
→ Jede Monats-Anfrage schlug seit dem Merge von PR #38 fehl.

### 2. Fehlende Generic-Rescue in Meter-Clients

Alle drei Clients (`GridMeter`, `SolarMeter`, `HeatingMeter`) fingen nur
`Errno::EHOSTUNREACH` und `Errno::ECONNREFUSED`. `SocketError`, `Timeout::Error`,
SSL-Fehler propagierten unkontrolliert und unterbrachen den Job-Scheduler.

```ruby
# Fix (ergänzt in allen drei Clients):
rescue => e
  puts "[Client] Fehler: #{e.message}"
  restore_last_values
```

### 3. Kein `:overlap => false` in `powerwall.rb`

```ruby
# Alt:
SCHEDULER.every '5s', :first_in => 0 do |job|

# Fix:
SCHEDULER.every '5s', :first_in => 0, :overlap => false do |job|
```
→ Bei langsamer/nicht erreichbarer Powerwall HTTPS-Verbindung stapelten sich Jobs.

### 4. Sekundäre Heating-Requests nicht abgesichert

Monats-/Tageswerte in eigenem `begin/rescue` – ein Fehler dort verwarf
den bereits gelesenen `heating_watts_current`.

---

## Ausgangszustand (vor dieser Aktion)

```
1a02a96  ← Add C4 Component diagram (letzter Commit VOR Powerwall)
    ↓
ae011bc  ← Merge PR #38 (powerwall-integration)
aac5256  ← Merge PR #39 (powerwall-house-consumption)
4f93184  ← Merge PR #40 (split-tests)
    ↓
0dc0fcc  ← fix: robust connection error handling  (feature/fix-powerwall-connection)
    ↑
    HEAD (feature/teslawall)
```

**master** zeigte auf: `4f93184`

---

## Ergebnis

```
master:            1a02a96  ← zurückgesetzt auf "vor Powerwall"
feature/teslawall: 0dc0fcc  ← enthält alle Powerwall-Arbeit + Connection-Fixes
```

---

## Durchgeführte Schritte

### 1. Branch `feature/teslawall` gesichert
```bash
git checkout feature/fix-powerwall-connection
git checkout -b feature/teslawall
git push -u origin feature/teslawall
```

### 2. master auf Pre-Powerwall-Stand zurückgesetzt
```bash
git checkout master
git reset --hard 1a02a96
git push --force origin master
```
**Hinweis:** GitHub Branch-Protection-Regel für master musste temporär deaktiviert werden.

### 3. Alten Fix-Branch und PR aufgeräumt
```bash
git branch -D feature/fix-powerwall-connection
git push origin --delete feature/fix-powerwall-connection
gh pr close 47 --comment "Superseded by feature/teslawall"
```

---

## Commits in `feature/teslawall` (vs. Pre-Powerwall master)

| Commit | Inhalt |
|---|---|
| `b7f42b6` | Add Tesla Powerwall integration |
| `ae011bc` | Merge PR #38 (powerwall-integration) |
| `3480820` | Include Powerwall battery discharge in house consumption |
| `aac5256` | Merge PR #39 (powerwall-house-consumption) |
| `ccdc4d4` | Split unit_test.rb |
| `4f93184` | Merge PR #40 (split-tests) |
| `0dc0fcc` | fix: robust connection error handling and URL bug |

---

## Hinweise für spätere Reaktivierung

Vor dem Merge von `feature/teslawall` zurück in master:
1. `:overlap => false` in `powerwall.rb` ist bereits enthalten
2. URL-Bug in `YOULESS_MONTHS_URL` ist bereits gefixt
3. Generic-Rescue in allen 3 Meter-Clients ist bereits ergänzt
4. HTTParty sortiert Query-Parameter alphabetisch → Test-Stubs brauchen `f=j&m=\d+` (nicht `m=\d+&f=j`)
5. POWERWALL_HOST, POWERWALL_PASSWORD, POWERWALL_EMAIL als Env-Vars nötig
