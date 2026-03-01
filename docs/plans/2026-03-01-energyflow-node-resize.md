# EnergyFlow Node Resize Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Scale all SVG nodes in the energyflow widget to 1.5× their current size for better dashboard readability.

**Architecture:** Pure SVG coordinate change — no Ruby, no jobs, no tests needed. Two files change: `energyflow.html` (geometry) and `energyflow.scss` (font sizes). The SVG uses `viewBox` for coordinate space; expanding it vertically lets the Battery node fit without overflowing. All other layout is adjusted by scaling radii, `dy` text offsets, icon font-sizes, and flow-path endpoints proportionally.

**Tech Stack:** SVG, SCSS. No Ruby. No tests (UI-only widget change).

---

### Task 1: Expand viewBox and move node positions

**Files:**
- Modify: `widgets/energyflow/energyflow.html`

**Step 1: Change the viewBox**

In `energyflow.html` line 2, change:
```html
<svg viewBox="0 0 760 360"
```
to:
```html
<svg viewBox="0 0 760 445"
```

**Step 2: Update Solar node position and radius**

Find `id="node-solar"` (around line 31). Change:
```html
<g class="ef-node" id="node-solar" transform="translate(380,75)">
  <circle class="node-circle solar" r="40"/>
```
to:
```html
<g class="ef-node" id="node-solar" transform="translate(380,65)">
  <circle class="node-circle solar" r="60"/>
```

**Step 3: Update Grid node position and radius**

Find `id="node-grid"` (around line 39). Change:
```html
<g class="ef-node" id="node-grid" transform="translate(90,200)">
  <circle class="node-circle grid" r="40"/>
```
to:
```html
<g class="ef-node" id="node-grid" transform="translate(90,215)">
  <circle class="node-circle grid" r="60"/>
```

**Step 4: Update House node position and radius**

Find `id="node-house"` (around line 48). Change:
```html
<g class="ef-node" id="node-house" transform="translate(380,200)">
  <circle class="node-circle house" r="46"/>
```
to:
```html
<g class="ef-node" id="node-house" transform="translate(380,215)">
  <circle class="node-circle house" r="69"/>
```

**Step 5: Update Heatpump node position and radius**

Find `id="node-heatpump"` (around line 57). Change:
```html
<g class="ef-node" id="node-heatpump" transform="translate(670,200)">
  <circle class="node-circle heatpump" r="40"/>
```
to:
```html
<g class="ef-node" id="node-heatpump" transform="translate(670,215)">
  <circle class="node-circle heatpump" r="60"/>
```

**Step 6: Update Battery node position and radius**

Find `id="node-battery"` (around line 71). Change:
```html
<g class="ef-node" id="node-battery" transform="translate(380,330)">
  <circle class="node-circle battery" r="40"/>
```
to:
```html
<g class="ef-node" id="node-battery" transform="translate(380,375)">
  <circle class="node-circle battery" r="60"/>
```

**Step 7: Commit**

```bash
git add widgets/energyflow/energyflow.html
git commit -m "feat: move node positions for 1.5x resize"
```

---

### Task 2: Update flow paths to match new circle edges

**Files:**
- Modify: `widgets/energyflow/energyflow.html`

Flow paths connect circle *edges*, not centers. With new radii and positions, all four paths need new endpoints.

Formula: path start = center + radius (in direction of flow), path end = other_center - radius.

**Step 1: Solar → House path**

Solar center (380,65), r=60 → bottom edge y = 65+60 = 125
House center (380,215), r=69 → top edge y = 215-69 = 146

Change:
```html
<path data-flow="solar-house"
      class="flow-path"
      d="M 380,115 L 380,162"/>
```
to:
```html
<path data-flow="solar-house"
      class="flow-path"
      d="M 380,125 L 380,146"/>
```

**Step 2: Grid ↔ House path**

Grid center (90,215), r=60 → right edge x = 90+60 = 150
House center (380,215), r=69 → left edge x = 380-69 = 311

Change:
```html
<path data-flow="grid-house"
      class="flow-path"
      d="M 140,200 L 332,200"/>
```
to:
```html
<path data-flow="grid-house"
      class="flow-path"
      d="M 150,215 L 311,215"/>
```

**Step 3: House → Heatpump path**

House center (380,215), r=69 → right edge x = 380+69 = 449
Heatpump center (670,215), r=60 → left edge x = 670-60 = 610

Change:
```html
<path data-flow="house-heatpump"
      class="flow-path"
      d="M 428,200 L 620,200"/>
```
to:
```html
<path data-flow="house-heatpump"
      class="flow-path"
      d="M 449,215 L 610,215"/>
```

**Step 4: House ↔ Battery path**

House center (380,215), r=69 → bottom edge y = 215+69 = 284
Battery center (380,375), r=60 → top edge y = 375-60 = 315

Change:
```html
<path data-flow="house-battery"
      class="flow-path"
      d="M 380,238 L 380,292"/>
```
to:
```html
<path data-flow="house-battery"
      class="flow-path"
      d="M 380,284 L 380,315"/>
```

**Step 5: Commit**

```bash
git add widgets/energyflow/energyflow.html
git commit -m "feat: update flow paths for 1.5x node positions"
```

---

### Task 3: Scale text dy-offsets and icon sizes

**Files:**
- Modify: `widgets/energyflow/energyflow.html`

`dy` is the vertical offset of each text element from the circle center. Scale by `r_new / r_old`. Standard nodes: ×1.5. House: ×1.5 (46→69).

**Step 1: Solar node text**

Change (inside `id="node-solar"`):
```html
<text class="node-icon" font-family="FontAwesome" font-size="22" text-anchor="middle" dy="-10">&#xf185;</text>
<text class="node-label" text-anchor="middle" dy="5">Solar</text>
<text class="node-value" id="val-solar" text-anchor="middle" dy="19">-- W</text>
<text class="node-kwh" id="val-solar-kwh" text-anchor="middle" dy="31">-- kWh</text>
```
to:
```html
<text class="node-icon" font-family="FontAwesome" font-size="33" text-anchor="middle" dy="-15">&#xf185;</text>
<text class="node-label" text-anchor="middle" dy="8">Solar</text>
<text class="node-value" id="val-solar" text-anchor="middle" dy="29">-- W</text>
<text class="node-kwh" id="val-solar-kwh" text-anchor="middle" dy="47">-- kWh</text>
```

**Step 2: Grid node text**

Change (inside `id="node-grid"`):
```html
<text class="node-icon" font-family="FontAwesome" font-size="22" text-anchor="middle" dy="-10">&#xf0e7;</text>
<text class="node-label" id="lbl-grid" text-anchor="middle" dy="5">Netz</text>
<text class="node-value" id="val-grid" text-anchor="middle" dy="19">-- W</text>
<text class="node-kwh" id="val-grid-kwh" text-anchor="middle" dy="31">-- kWh</text>
```
to:
```html
<text class="node-icon" font-family="FontAwesome" font-size="33" text-anchor="middle" dy="-15">&#xf0e7;</text>
<text class="node-label" id="lbl-grid" text-anchor="middle" dy="8">Netz</text>
<text class="node-value" id="val-grid" text-anchor="middle" dy="29">-- W</text>
<text class="node-kwh" id="val-grid-kwh" text-anchor="middle" dy="47">-- kWh</text>
```

**Step 3: House node text**

Change (inside `id="node-house"`):
```html
<text class="node-icon" font-family="FontAwesome" font-size="26" text-anchor="middle" dy="-6">&#xf015;</text>
<text class="node-label" text-anchor="middle" dy="12">Haus</text>
<text class="node-value" id="val-house" text-anchor="middle" dy="28">-- W</text>
```
to:
```html
<text class="node-icon" font-family="FontAwesome" font-size="39" text-anchor="middle" dy="-9">&#xf015;</text>
<text class="node-label" text-anchor="middle" dy="18">Haus</text>
<text class="node-value" id="val-house" text-anchor="middle" dy="42">-- W</text>
```

**Step 4: Heatpump node text**

Change (inside `id="node-heatpump"`):
```html
<text class="node-label" text-anchor="middle" dy="5">WP</text>
<text class="node-value" id="val-heatpump" text-anchor="middle" dy="19">-- W</text>
<text class="node-kwh" id="val-heatpump-kwh" text-anchor="middle" dy="31">-- kWh</text>
```
to:
```html
<text class="node-label" text-anchor="middle" dy="8">WP</text>
<text class="node-value" id="val-heatpump" text-anchor="middle" dy="29">-- W</text>
<text class="node-kwh" id="val-heatpump-kwh" text-anchor="middle" dy="47">-- kWh</text>
```

**Step 5: Heatpump fan propeller (scale ×1.5)**

Change the fan icon group (inside `id="node-heatpump"`):
```html
<g transform="translate(0,-14)" fill="rgba(255,255,255,0.9)">
  <g transform="rotate(0)">  <ellipse cx="2" cy="-5" rx="2.5" ry="6"/></g>
  <g transform="rotate(120)"><ellipse cx="2" cy="-5" rx="2.5" ry="6"/></g>
  <g transform="rotate(240)"><ellipse cx="2" cy="-5" rx="2.5" ry="6"/></g>
  <circle r="2.5"/>
</g>
```
to:
```html
<g transform="translate(0,-21)" fill="rgba(255,255,255,0.9)">
  <g transform="rotate(0)">  <ellipse cx="3" cy="-8" rx="4" ry="9"/></g>
  <g transform="rotate(120)"><ellipse cx="3" cy="-8" rx="4" ry="9"/></g>
  <g transform="rotate(240)"><ellipse cx="3" cy="-8" rx="4" ry="9"/></g>
  <circle r="4"/>
</g>
```

**Step 6: Battery node text**

Change (inside `id="node-battery"`):
```html
<text class="node-icon" font-family="FontAwesome" font-size="22" text-anchor="middle" dy="-8">&#xf240;</text>
<text class="node-soc" id="val-soc" text-anchor="middle" dy="6">--%</text>
<text class="node-value" id="val-battery" text-anchor="middle" dy="22">-- W</text>
```
to:
```html
<text class="node-icon" font-family="FontAwesome" font-size="33" text-anchor="middle" dy="-12">&#xf240;</text>
<text class="node-soc" id="val-soc" text-anchor="middle" dy="9">--%</text>
<text class="node-value" id="val-battery" text-anchor="middle" dy="33">-- W</text>
```

**Step 7: Commit**

```bash
git add widgets/energyflow/energyflow.html
git commit -m "feat: scale node text dy-offsets and icon sizes 1.5x"
```

---

### Task 4: Update SCSS font sizes

**Files:**
- Modify: `widgets/energyflow/energyflow.scss`

**Step 1: Update node text font sizes**

Change the four class rules (lines ~61–84):

```scss
.node-label {
  fill: rgba(255, 255, 255, 0.65);
  font-size: 11px;       // change to 16px
  font-weight: 300;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.node-value {
  fill: #ffffff;
  font-size: 13px;       // change to 19px
  font-weight: 600;
}

.node-kwh {
  fill: rgba(255, 255, 255, 0.55);
  font-size: 10px;       // change to 15px
  font-weight: 400;
}

.node-soc {
  fill: #a5d6a7;
  font-size: 13px;       // change to 19px
  font-weight: 600;
}
```

Apply all four changes — result should be:

```scss
.node-label {
  fill: rgba(255, 255, 255, 0.65);
  font-size: 16px;
  font-weight: 300;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.node-value {
  fill: #ffffff;
  font-size: 19px;
  font-weight: 600;
}

.node-kwh {
  fill: rgba(255, 255, 255, 0.55);
  font-size: 15px;
  font-weight: 400;
}

.node-soc {
  fill: #a5d6a7;
  font-size: 19px;
  font-weight: 600;
}
```

**Step 2: Commit**

```bash
git add widgets/energyflow/energyflow.scss
git commit -m "feat: scale node font sizes 1.5x in SCSS"
```

---

### Task 5: Visual verification and final cleanup

**Step 1: Start the dashboard locally**

```bash
docker run -p 3030:3030 --env-file .env daisaja/energymeter:latest
```

Then open `http://localhost:3030/energyflow` in a browser.

**Step 2: Verify visually**

Check:
- [ ] All 5 nodes visible, no overlap
- [ ] Flow path animations play (animated dashes on active flows)
- [ ] Text (W values, kWh, SOC%) is inside each circle
- [ ] Heatpump fan propeller centered inside its circle
- [ ] Weather panel still visible in top-right
- [ ] Battery node not clipped at bottom

**Step 3: Push and open PR**

```bash
git push -u origin feature/energyflow-node-resize
gh pr create --title "feat: scale energyflow SVG nodes 1.5x" --body "$(cat <<'EOF'
## Summary
- Increase all node circle radii from 40→60 (house: 46→69)
- Expand SVG viewBox height from 360→445 to fit larger Battery node
- Update all text dy-offsets, icon font-sizes, and flow path endpoints proportionally
- Scale SCSS font sizes (node-label, node-value, node-kwh, node-soc) by 1.5×

## Test plan
- [ ] Open /energyflow dashboard and verify all nodes are visibly larger
- [ ] Confirm no node overlap and all text stays within circles
- [ ] Confirm flow animations still work on all 4 paths
- [ ] Confirm weather panel is still visible top-right

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```
