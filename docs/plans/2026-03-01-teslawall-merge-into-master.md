# Teslawall Branch Merge Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Merge `feature/teslawall` into `master` without breaking the connection-error fixes and solar meter key fix already on master, then verify locally before deleting the branch.

**Architecture:** Merge master into teslawall (Option A), resolve the one known conflict in `solar_meter_client.rb` keeping master's fix (`017A-xxxxx26F` as primary, single rescue), then run tests and smashing locally to verify, and finally create a PR.

**Tech Stack:** Ruby 4.0, Minitest, Smashing/Thin, Git

---

## Known Conflict

`jobs/meter_helper/solar_meter_client.rb` – teslawall still uses `017A-B339126F` as primary key with double rescue. Master has `017A-xxxxx26F` as primary with single rescue. **Keep master's version.**

---

### Task 1: Switch to teslawall branch

**Files:** keine

**Step 1: Checkout teslawall branch**

```bash
git checkout feature/teslawall
```

Expected: `Switched to branch 'feature/teslawall'`

**Step 2: Verify starting point**

```bash
git log --oneline -5
```

Expected: Top commit ist `0dc0fcc fix: robust connection error handling...`

---

### Task 2: Merge master in teslawall

**Files:** `jobs/meter_helper/solar_meter_client.rb`

**Step 1: Merge master**

```bash
git merge master
```

Expected: Merge-Konflikt in `jobs/meter_helper/solar_meter_client.rb`

**Step 2: Konflikt prüfen**

```bash
git diff --name-only --diff-filter=U
```

Expected: Nur `jobs/meter_helper/solar_meter_client.rb` erscheint.

**Step 3: Konflikt auflösen – master-Version behalten**

In `jobs/meter_helper/solar_meter_client.rb` den Konflikt-Block so auflösen (master-Version):

```ruby
    begin
      @solar_watts_current = response.parsed_response['result']['017A-xxxxx26F']['6100_40263F00']['1'][0]['val']
    rescue StandardError
      puts '[SolarMeter] Konnte Wert nicht aus Antwort lesen'
      @solar_watts_current = -1
    end
```

Kein `017A-B339126F`, kein doppelter rescue.

**Step 4: Merge abschließen**

```bash
git add jobs/meter_helper/solar_meter_client.rb
git commit
```

Expected: Merge-Commit mit Default-Message wird erstellt.

---

### Task 3: Tests laufen lassen

**Files:** `test/`

**Step 1: Alle Tests ausführen**

```bash
bundle exec ruby -r simplecov -Itest test/unit_test.rb
```

Expected: Alle Tests grün, keine Failures.

**Step 2: Neue Test-Files aus teslawall prüfen**

```bash
ls test/
```

Expected: Separate Test-Files vorhanden (`grid_meter_client_test.rb`, `powerwall_client_test.rb`, etc.)

**Step 3: Einzelne Test-Files ausführen**

```bash
bundle exec ruby -Itest test/powerwall_client_test.rb
bundle exec ruby -Itest test/grid_meter_client_test.rb
```

Expected: Grün.

---

### Task 4: Smashing lokal starten und prüfen

**Files:** keine

**Step 1: Umgebungsvariablen laden und Smashing starten**

```bash
export $(cat .env | grep -v '^#' | xargs)
bundle exec smashing start
```

**Step 2: Log auf Fehler prüfen (nach ~10s)**

Erwartete Ausgabe: Keine `[GridMeter] Fehler:`, `[SolarMeter] Fehler:`, `[HeatingMeter] Fehler:` oder `[OpenDTU] Fehler:`-Meldungen.

Akzeptabel (bekannte macOS-Einschränkung): `EHOSTUNREACH` nur wenn Homebrew-Ruby keine lokale Netzwerkerlaubnis hat.
→ In dem Fall via TCP-Test prüfen ob Verbindungen funktionieren (siehe Connection-Debugging in MEMORY.md).

**Step 3: Smashing beenden**

```bash
lsof -ti :3030 | xargs kill -9
```

---

### Task 5: PR erstellen und mergen

**Step 1: Branch pushen**

```bash
git push origin feature/teslawall
```

**Step 2: PR erstellen**

```bash
gh pr create --title "feat: Powerwall integration, test splitting, bug fixes" --body "$(cat <<'EOF'
## Summary
- Adds Tesla Powerwall integration with dedicated dashboard (`teslawall.erb`)
- Includes battery discharge in house consumption calculation (`grid_watts.rb`)
- Splits `unit_test.rb` into focused test files per component
- Fixes InfluxDB `hash.merge!` bug
- Cleans up `solar_production_per_day.rb` (removes null-check helper)
- Adds `solar_meter_client` require in `energy_meter_summary.rb` and `grid_watts.rb`

## Conflict Resolution
`solar_meter_client.rb`: Kept master's fix (`017A-xxxxx26F` as primary key, single rescue).

## Test plan
- [ ] `bundle exec ruby -r simplecov -Itest test/unit_test.rb` → grün
- [ ] `bundle exec ruby -Itest test/powerwall_client_test.rb` → grün
- [ ] Smashing lokal gestartet, keine Verbindungsfehler

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
git checkout master
git pull
```

**Step 2: Branch löschen (lokal + remote)**

```bash
git branch -d feature/teslawall
git push origin --delete feature/teslawall
```

Expected: Branch lokal und remote gelöscht.
