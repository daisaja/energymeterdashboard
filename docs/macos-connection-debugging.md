# macOS Verbindungsprobleme debuggen

Smashing läuft lokal mit Homebrew Ruby. Unter macOS Tahoe (26+) kann es vorkommen,
dass die Meter-Clients alle mit `Errno::EHOSTUNREACH` fehlschlagen – obwohl `curl`
dieselben Hosts problemlos erreicht.

---

## Symptom

Smashing-Log zeigt:

```
[GridMeter] Verbindung zu 192.168.178.103:8081 fehlgeschlagen: Gerät nicht erreichbar
[OpenDTU] Verbindung zu 192.168.178.74 fehlgeschlagen: Gerät nicht erreichbar
[HeatingMeter] Verbindung zu 192.168.178.10 fehlgeschlagen: Gerät nicht erreichbar
[SolarMeter] Verbindung zu 192.168.178.37 fehlgeschlagen: Gerät nicht erreichbar
```

Gleichzeitig funktioniert:

```bash
curl -s http://192.168.178.103:8081/  # → HTTP 200
```

---

## Ursachen

### Ursache 1: macOS Lokales-Netzwerk-Berechtigung fehlt

macOS Tahoe verlangt für jede App eine explizite Erlaubnis, auf das lokale Netzwerk
zuzugreifen. Diese Berechtigung ist **pro Terminal-App** – iTerm2 und Terminal.app
brauchen je eine eigene Erlaubnis.

Homebrew Ruby läuft im Kontext der Terminal-App. Ohne Berechtigung blockt macOS
den TCP-Connect still (kein Dialog, keine Fehlermeldung im System).

`curl` nutzt einen anderen Systemaufruf-Pfad und ist davon nicht betroffen.

### Ursache 2: Docker Desktop aktiv

Docker Desktop erstellt beim Start eine `bridge100` VM-Bridge mit einer
Default-Reject-Route. Diese stört Rubys Routing zu lokalen IPs.
`curl` ist nicht betroffen (anderer Pfad).

---

## Diagnose

### Schritt 1: Ist es ein Ruby-Berechtigungsproblem?

```bash
# Homebrew Ruby – schlägt fehl wenn Berechtigung fehlt:
ruby -rsocket -e "TCPSocket.new('192.168.178.103', 8081).close; puts 'OK'"

# System Ruby – immer trusted, zum Vergleich:
/usr/bin/ruby -rsocket -e "TCPSocket.new('192.168.178.103', 8081).close; puts 'OK'"
```

- Homebrew schlägt fehl, System-Ruby OK → **Ursache 1** (Berechtigung)
- Beide schlagen fehl → **Ursache 2** (Docker) oder tatsächliches Netzwerkproblem

### Schritt 2: Ist Docker Desktop schuld?

```bash
netstat -rn | grep bridge100
```

Wenn `bridge100` als Route mit `!` (Reject) auftaucht → Docker Desktop beenden.

### Schritt 3: Alle Meter-Verbindungen auf einmal testen

```bash
ruby -rsocket -e "
{
  'GridMeter (vzlogger)'   => ['192.168.178.103', 8081],
  'OpenDTU'                => ['192.168.178.74',  80],
  'HeatingMeter (Youless)' => ['192.168.178.10',  80],
  'SolarMeter (SMA)'       => ['192.168.178.37',  443],
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

---

## Lösungen

### Fix A: Netzwerkberechtigung für die Terminal-App erteilen

1. **Systemeinstellungen → Datenschutz & Sicherheit → Lokales Netzwerk**
2. Die verwendete Terminal-App aktivieren (iTerm2, Terminal.app – je nachdem welche genutzt wird)
3. Smashing neu starten

> Wichtig: Die Berechtigung ist pro App. iTerm2 und Terminal.app brauchen je eine eigene.

### Fix B: Berechtigungs-Dialog manuell triggern

Falls kein Dialog erschienen ist, kann der Netzwerkzugriff per Swift-Snippet getriggert werden:

```bash
cat > /tmp/trigger_network.swift << 'EOF'
import Network
let conn = NWConnection(host: "192.168.178.103", port: 8081, using: .tcp)
conn.start(queue: .main)
RunLoop.main.run(until: Date(timeIntervalSinceNow: 2))
EOF
swift /tmp/trigger_network.swift
```

macOS zeigt dann den Berechtigungs-Dialog. Danach Smashing neu starten.

### Fix C: Docker Desktop beenden

Docker Desktop vollständig beenden (nicht nur das Fenster schließen – im Menü
"Docker Desktop beenden" wählen). Danach `netstat -rn | grep bridge100` prüfen –
die Route sollte verschwunden sein.

---

## Wichtig: Lokale Fehler ≠ Server-Fehler

Connection-Fehler im lokalen Smashing-Log bedeuten **nicht**, dass es auf dem
Raspberry Pi / Synology-Server Probleme gibt. Auf dem Server läuft Linux mit
Ruby 3.3.x – die macOS-Einschränkungen existieren dort nicht.

Vor dem Debuggen auf dem Server prüfen: Läuft Smashing dort sauber?

```bash
# Auf dem Pi:
docker logs energymeter --tail 50
```
