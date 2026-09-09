# ToTo Cafe — Design System

Reference this file whenever generating or editing UI components. Do not introduce
colors, fonts, radii, or spacing values outside what's defined here.

## 1. Brand & Mood

- Cozy, warm, plant-filled neighborhood coffee shop — "Coffee & Comfort"
- Tone: calm, artisanal, tactile (wood, ceramics, natural light)
- Not minimal/corporate — warm serif headings + soft cream backgrounds

## 2. Color Palette

| Token | Hex | Usage |
|---|---|---|
| `--color-bg` | `#F5F1E4` | Page background (warm cream/off-white) |
| `--color-surface` | `#FBF9F2` | Cards, modals, panels |
| `--color-primary` | `#3F5F35` | Forest green — primary buttons, active nav, selected states |
| `--color-primary-hover` | `#334D2B` | Primary button hover/pressed |
| `--color-secondary` | `#5B3A29` | Dark brown — secondary CTA (e.g. "Proceed to Payment"), accents |
| `--color-text-heading` | `#4A2F1E` | Headings, logo (brown) |
| `--color-text-heading-accent` | `#3F5F35` | Alternating letters/words in logo (green) |
| `--color-text-body` | `#3A362E` | Body copy |
| `--color-text-muted` | `#8A8374` | Secondary text, labels, prices subtitle |
| `--color-border` | `#E4DECC` | Card borders, dividers, input outlines |
| `--color-border-selected` | `#3F5F35` | Selected chip/option border |
| `--color-white` | `#FFFFFF` | Text on filled green/brown buttons |

Do not use pure black (`#000`) or pure white backgrounds anywhere — always the warm
cream/brown palette above.

## 3. Typography

- **Headings / logo**: Serif, bold (e.g. "Playfair Display", "Georgia", or similar
  high-contrast serif). Used for cafe name, section titles, product names, modal titles.
- **Body / UI text**: Clean sans-serif (e.g. "Inter", "Helvetica Neue", system-ui).
  Used for descriptions, nav items, buttons, prices, form labels.
- **Eyebrow / label text**: Sans-serif, uppercase, letter-spacing ~0.15em, small size,
  muted color (e.g. "COFFEE & COMFORT", "SWEETNESS", "MILK TYPE").

| Style | Font | Size | Weight |
|---|---|---|---|
| Logo | Serif | 32px | 700 |
| Page/Section title (e.g. "Hot Coffee") | Serif | 24px | 700 |
| Product/Modal name | Serif | 20px | 700 |
| Body text | Sans | 14–15px | 400 |
| Button label | Sans | 15px | 600 |
| Eyebrow label | Sans | 11px | 600, uppercase, letter-spacing 0.15em |
| Price | Sans | 15px | 700 |

## 4. Spacing Scale

Use a 4px base unit: `4, 8, 12, 16, 24, 32, 48, 64px`

- Card internal padding: 16–24px
- Section gaps: 32–48px
- Page margin: 24–32px

## 5. Radius & Shape

| Element | Radius |
|---|---|
| Buttons (primary CTA, pill) | Full pill (999px) |
| Cards / product tiles | 16px |
| Images (hero, product photo) | 16–20px |
| Modal | 20px |
| Chips / option selectors | Full pill (999px) |
| Small badges (QR card, item count) | 12–999px depending on shape |

## 6. Components

### Buttons
- **Primary (green pill)**: `--color-primary` bg, white text, full pill radius,
  used for "Tap to start ordering", "Add to cart". Hover → `--color-primary-hover`.
- **Secondary (dark brown pill)**: `--color-secondary` bg, white text, used for
  final/high-commitment actions like "Proceed to Payment".
- **Outline chip (unselected)**: transparent bg, `--color-border` outline,
  `--color-text-body` text, pill radius.
- **Outline chip (selected)**: `--color-primary` bg, white text, pill radius —
  used for sweetness %, milk type selectors.

### Cards (product tiles)
- `--color-surface` background, 16px radius, subtle border (`--color-border`) or
  soft shadow, image on top (rounded top corners), name (serif bold), short
  description (muted sans), price + "Add to cart" pill button aligned bottom row.

### Navigation (sidebar)
- Vertical list, no borders between items.
- Active item: `--color-primary` filled pill/rounded-rect background, white text.
- Inactive item: transparent bg, `--color-text-body`, no border.

### Modal (item customization)
- Centered overlay, `--color-surface` bg, 20px radius, dimmed backdrop.
- Close (×) button top-right, circular, subtle bg.
- Hero image full-width at top, rounded top corners only.
- Eyebrow label → serif product name → muted description.
- Option groups (Sweetness, Milk Type): eyebrow label, then row of pill chips.
- Sticky footer button: full-width primary pill, label left / price right.

### Order summary panel
- Right-side fixed panel, `--color-surface` bg.
- Header with item count badge (pill, muted bg).
- Line items: thumbnail (rounded), name (serif), modifiers (muted sans),
  quantity stepper (circular +/− buttons), price.
- Totals block (Subtotal / Tax / Total) right-aligned, divider above.
- Footer CTA: dark brown pill "Proceed to Payment".

### QR / promo card
- Small floating card, `--color-surface` bg, 16px radius, soft shadow.
- QR code left, bold serif/sans title + muted description right.

## 7. Layout Notes

- Kiosk/tablet-first ordering flow: hero screen → category + product grid → cart panel.
- Three-column layout on product screen: left = category nav (fixed width ~180px),
  center = product grid (flexible), right = order summary (fixed width ~280–300px).
- Generous whitespace; avoid dense grids — 3 products per row max on center panel.

## 8. Imagery

- Warm, natural-light photography; wood textures, ceramics, plants.
- Product photos: square or 4:5, rounded corners, no hard drop shadows.
- Avoid stock-looking, oversaturated, or cool-toned photography.
