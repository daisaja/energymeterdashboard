# EnergyFlow-Änderungen in separaten Branch auslagern

## Kontext

Alle EnergyFlow-bezogenen Änderungen seit PR #41/#42 wurden in einem
separaten Branch gebündelt und master auf den Stand vor EnergyFlow zurückgesetzt.

**Grund**: Saubere Trennung zwischen "stable pre-EnergyFlow" und "EnergyFlow feature work".

---

## Ausgangszustand (vor dieser Aktion)

```
4f93184  ← Merge PR #40 (letzter Commit VOR EnergyFlow)
    ↓
dfeceb8  ← Merge PR #41 (energyflow-widget)
b194c5f  ← Merge PR #42 (energyflow-job)
   ...  ← ~12 weitere Commits (kWh, weather, design)
27c61a8  ← Merge PR #44 (weather-in-energyflow)
    ↓
b20916a  ← fix HeatingMeasurements  (feature branch)
52c7ad8  ← fix Race Condition        (feature branch)
    ↑
    HEAD (feature/fix-heatpump-flow-when-grid-bezug)
```

**master** zeigte auf: `d96fa3a` (= Merge PR #44 + vorherige EF-Merges)

---

## Ergebnis

```
master:                  4f93184  ← zurückgesetzt auf "vor EnergyFlow"
feature/energyflow:      52c7ad8  ← enthält alle EF-Arbeit + beide Bug-fixes
```

---

## Durchgeführte Schritte

### 1. Branch `feature/energyflow` erstellt und gesichert
```bash
git checkout feature/fix-heatpump-flow-when-grid-bezug
git checkout -b feature/energyflow
git push -u origin feature/energyflow
```
→ Branch enthält alle 4 EF-PRs + beide Bug-fix-Commits (52c7ad8)

### 2. master auf Pre-EnergyFlow-Stand zurückgesetzt
```bash
git checkout master
git reset --hard 4f93184
git push --force origin master
```
→ master ist wieder bei "Merge PR #40 (split-tests-into-separate-files)"

**Hinweis:** GitHub Branch-Protection-Regel für master musste temporär
deaktiviert werden (Allow force pushes), danach wieder aktiviert.

### 3. Alten Feature-Branch gelöscht (lokal + remote)
```bash
git branch -D feature/fix-heatpump-flow-when-grid-bezug
git push origin --delete feature/fix-heatpump-flow-when-grid-bezug
```
→ `-D` (statt `-d`) nötig, da master nach dem Reset "vor" dem Branch lag

---

## Commits in `feature/energyflow` (vs. Pre-EF master)

26 Commits ab `4f93184`, darunter:
- `dfeceb8` – Merge PR #41 (widget)
- `b194c5f` – Merge PR #42 (job + TDD)
- `4ffd417` – Merge PR #43 (kWh)
- `27c61a8` – Merge PR #44 (weather)
- `b20916a` – fix: HeatingMeasurements error handling
- `52c7ad8` – fix: Race condition / duplicate HTTP calls

---

## Aktueller Branch-Überblick (nach Aktion)

| Branch | Stand | Zweck |
|---|---|---|
| `master` | `4f93184` | Stabiler Pre-EnergyFlow-Stand |
| `feature/energyflow` | `52c7ad8` | Alle EF-Arbeit, bereit für PR |
| `feature/energyflow-design-doc` | – | Design-Dokumentation |
| `tibber-client` | – | Tibber-Integration (in Entwicklung) |
