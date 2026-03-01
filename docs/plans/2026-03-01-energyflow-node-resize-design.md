# Design: EnergyFlow Node Resize (1.5x)

**Date:** 2026-03-01
**Goal:** Make SVG nodes in the energyflow widget 1.5× larger for better readability.

## Approach

Scale node circles, icons, and text by 1.5×. Expand viewBox height to accommodate larger Battery node. Adjust node positions to prevent overlap. No tile size change.

## Files Changed

- `widgets/energyflow/energyflow.html` — viewBox, radii, dy-offsets, icon font-sizes, flow paths, node positions
- `widgets/energyflow/energyflow.scss` — node-label, node-value, node-kwh, node-soc font sizes

## Geometry

### ViewBox
`0 0 760 360` → `0 0 760 445`

### Node Positions (SVG coordinates)

| Node    | Old pos       | New pos       | Old r | New r |
|---------|--------------|--------------|-------|-------|
| Solar   | (380, 75)    | (380, 65)    | 40    | 60    |
| Grid    | (90, 200)    | (90, 215)    | 40    | 60    |
| House   | (380, 200)   | (380, 215)   | 46    | 69    |
| Heatpump| (670, 200)   | (670, 215)   | 40    | 60    |
| Battery | (380, 330)   | (380, 375)   | 40    | 60    |

### Gap Verification (no overlap)
- Solar ↔ House: |215−65|=150 > 60+69=129 ✓ (21px gap)
- Grid ↔ House: |380−90|=290 > 60+69=129 ✓
- House ↔ Heatpump: |670−380|=290 > 69+60=129 ✓
- House ↔ Battery: |375−215|=160 > 69+60=129 ✓ (31px gap)
- Battery bottom: 375+60=435 < 445 ✓

### Flow Paths (new endpoints)
- Solar→House: `M 380,125 L 380,146`
- Grid→House: `M 150,215 L 311,215`
- House→Heatpump: `M 449,215 L 610,215`
- House→Battery: `M 380,284 L 380,315`

### Text dy Offsets (scaled by r_new/r_old)

**Standard nodes (r=40→60, factor 1.5):**
| Text       | Old dy | New dy |
|-----------|--------|--------|
| icon       | -10    | -15    |
| label      | 5      | 8      |
| value      | 19     | 29     |
| kwh        | 31     | 47     |

**House (r=46→69, factor 1.5):**
| Text       | Old dy | New dy |
|-----------|--------|--------|
| icon       | -6     | -9     |
| label      | 12     | 18     |
| value      | 28     | 42     |

**Battery (r=40→60, factor 1.5):**
| Text       | Old dy | New dy |
|-----------|--------|--------|
| icon       | -8     | -12    |
| soc        | 6      | 9      |
| value      | 22     | 33     |

### Icon Font Sizes (inline in HTML)
- Standard nodes: `22` → `33`
- House: `26` → `39`

### Heatpump Fan Propeller (scale ×1.5)
- translate: `(0,-14)` → `(0,-21)`
- ellipse: `cx="2" cy="-5" rx="2.5" ry="6"` → `cx="3" cy="-8" rx="4" ry="9"`
- center circle: `r="2.5"` → `r="4"`

### SCSS Font Sizes

| Class        | Old  | New  |
|-------------|------|------|
| .node-label  | 11px | 16px |
| .node-value  | 13px | 19px |
| .node-kwh    | 10px | 15px |
| .node-soc    | 13px | 19px |

## Unchanged
- Tile size: `sizex=4, sizey=2`
- Weather panel position and sizes
- Flow path animations (stroke-dasharray, keyframes)
- Node colors
