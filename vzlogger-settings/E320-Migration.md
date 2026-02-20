# E320 Zähler – Migration VZLogger & Dashboard

## Erkenntnisse: Alter Zähler (d0) vs. Neuer Zähler (E320 / SML)

### Protokoll-Unterschied

| Eigenschaft | Alter Zähler | E320 (neu) |
|-------------|-------------|------------|
| Protokoll | D0 (IEC 62056-21, optisch) | SML (Smart Message Language, binär) |
| Gerät | `/dev/ttyUSB0` | `/dev/ttyUSB0` |
| Baudrate | 300 (Init) / 9600 (Lesen) | 9600 |
| Parität | 7e1 | 8n1 |

### OBIS-Codes und Einheiten

Der wichtigste Unterschied: **Der E320 liefert andere Einheiten und weniger OBIS-Codes.**

| OBIS-Code | Alter Zähler (d0) | E320 (SML) |
|-----------|-------------------|------------|
| `1.8.0` | Bezug gesamt in **kWh** | Bezug gesamt in **Wh** |
| `2.8.0` | Einspeisung gesamt in **kWh** | Einspeisung gesamt in **Wh** |
| `1.7.0` | Momentaner Bezug in **kW** | ❌ nicht verfügbar |
| `2.7.0` | Momentane Einspeisung in **kW** | ❌ nicht verfügbar |
| `16.7.0` | ❌ nicht vorhanden | Momentanleistung in **W** (vorzeichenbehaftet: + = Bezug, − = Einspeisung) |
| `1.9.0` | Bezug aktueller Monat in kWh | ❌ nicht verfügbar |
| `2.9.0` | Einspeisung aktueller Monat in kWh | ❌ nicht verfügbar |
| `1.8.0*53/54` | Tages-/Monatswerte historisch | ❌ nicht verfügbar |

**Fazit:** Der E320 liefert nur 3 Werte direkt – Tages-/Monats-/Jahreswerte müssen im Dashboard aus Zählerstandsdifferenzen berechnet werden.

### Einheiten-Problem (kritisch!)

Das Dashboard hat bisher kWh/kW erwartet (alter Zähler). Der E320 liefert Wh/W.
Ohne Korrektur wären alle Werte **1000× zu groß** – scheinbar funktionierend, aber komplett falsch.

Lösung: In `grid_meter_client.rb` wird durch 1000 geteilt, damit das Interface nach außen unverändert bleibt.

---

## Vorgenommene Änderungen

### 1. `vzlogger.conf`
- Local HTTP Server aktiviert (`enabled: true`, `index: true`) – war zuvor deaktiviert, Dashboard bekam keine Daten
- Kanal `1-0:2.8.0` (Einspeisung gesamt) neu hinzugefügt
- UUIDs korrigiert auf die im Dashboard verwendeten Werte

### 2. `jobs/meter_helper/grid_meter_client.rb`
- Wh → kWh Konvertierung für Zählerstände (`/ 1000.0`)
- `16.7.0` Vorzeichenlogik: positiver Wert = Bezug, negativer Wert = Einspeisung (ersetzt die zwei separaten Kanäle 1.7.0 / 2.7.0)
- `is_new_month()` Hilfsfunktion ergänzt

### 3. `jobs/grid_consumption_per_month.rb` (neu)
- Berechnet monatliche und jährliche kWh-Deltas aus Zählerstandsdifferenzen
- Sendet Events: `meter_grid_supply_month`, `meter_grid_feed_month`, `meter_grid_supply_year`, `meter_grid_feed_year`

---

## Manuelles Testen auf dem Raspberry Pi

### Schritt 1: Config deployen

```bash
sudo cp /pfad/zur/vzlogger.conf /etc/vzlogger.conf
```

### Schritt 2: VZLogger neu starten

```bash
sudo systemctl restart vzlogger
```

### Schritt 3: Log prüfen – alle 3 OBIS-Codes müssen erscheinen

```bash
tail -f /var/log/vzlogger.log
```

Erwartete Ausgabe (innerhalb weniger Sekunden):

```
[sml] Parsed reading: 1-0:1.8.0  value=...  Wh
[sml] Parsed reading: 1-0:2.8.0  value=...  Wh
[sml] Parsed reading: 1-0:16.7.0 value=...  W
```

> **Falls `1-0:2.8.0` fehlt:** Der E320 ist noch im Einweg-Messmodus (+A only) konfiguriert. Das muss beim Netzbetreiber angefragt werden (Umstellung auf bidirektionalen Messmodus +A/-A).

### Schritt 4: Local HTTP API prüfen

```bash
curl http://localhost:8081/ | python3 -m json.tool
```

Erwartetes Ergebnis: JSON mit einem `data`-Array mit **3 Einträgen** (je eine UUID für 1.8.0, 2.8.0, 16.7.0).

```json
{
  "data": [
    { "uuid": "007aeef0-...", "tuples": [[<timestamp>, <wert_wh>]] },
    { "uuid": "e564e6e0-...", "tuples": [[<timestamp>, <wert_wh>]] },
    { "uuid": "c6ada300-...", "tuples": [[<timestamp>, <wert_w>]] }
  ]
}
```

### Schritt 5: Werte plausibel prüfen

```bash
# Zählerstand Bezug (sollte in kWh-Bereich liegen, z.B. 5000–50000)
curl -s http://localhost:8081/ | python3 -c "
import json,sys
data = json.load(sys.stdin)['data']
for d in data:
    print(d['uuid'][:8], d['tuples'][0][1])
"
```

Plausibilitäts-Checks:
- Zählerstand Bezug (1.8.0): Rohwert in **Wh**, z.B. `5.734.400` (= 5.734 kWh) ✓
- Zählerstand Einspeisung (2.8.0): Rohwert in **Wh**, ähnliche Größenordnung ✓
- Momentanleistung (16.7.0): Wert in **W**, z.B. `347` (Bezug) oder `-892` (Einspeisung) ✓

### Schritt 6: Dashboard starten und Werte kontrollieren

```bash
# Im Projekt-Verzeichnis
docker run -p 3030:3030 --env-file .env daisaja/energymeter:latest
```

Dann im Browser `http://localhost:3030` öffnen und prüfen:

| Widget | Erwarteter Wert |
|--------|----------------|
| Aktueller Bezug (W) | Realistisch, z.B. 200–3000 W |
| Aktuelle Einspeisung (W) | 0 W wenn keine Sonne, sonst > 0 |
| Tagesbezug (kWh) | Realistisch, z.B. 2–15 kWh |
| Tageseinspeisung (kWh) | Realistisch je nach PV-Produktion |

> **Achtung:** Wenn Werte 1000× zu groß oder zu klein wirken, Einheiten-Konvertierung in `grid_meter_client.rb` prüfen.

### Schritt 7: Monatswerte (neuer Job)

Die Monatswerte starten nach jedem Neustart des Dashboards bei 0 und wachsen ab dann kumulativ. Das ist das erwartete Verhalten – eine persistente Speicherung über Neustarts ist noch nicht implementiert.

---

## Bekannte Einschränkung

Die `is_new_month()` und `is_new_day()` Logik nutzt ein **10-Minuten-Zeitfenster** nach Mitternacht bzw. Monatswechsel. Wenn das Dashboard in dieser Zeitspanne nicht läuft, wird der Zählerstand-Snapshot für den neuen Tag/Monat verpasst. Der Wert springt dann nicht auf 0, sondern zeigt eine zu große Differenz an. Neustart des Dashboards in diesem Fall schafft Abhilfe.
