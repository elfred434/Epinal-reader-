---
name: Atelier Imagerie & Lettres
colors:
  surface: '#fff8f5'
  surface-dim: '#e7d7cd'
  surface-bright: '#fff8f5'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#fff1e9'
  surface-container: '#fcebe1'
  surface-container-high: '#f6e5db'
  surface-container-highest: '#f0dfd6'
  on-surface: '#221a14'
  on-surface-variant: '#59413d'
  inverse-surface: '#382e28'
  inverse-on-surface: '#ffede4'
  outline: '#8d706c'
  outline-variant: '#e1bfb9'
  surface-tint: '#b02d1e'
  primary: '#a62518'
  on-primary: '#ffffff'
  primary-container: '#c83e2d'
  on-primary-container: '#fff1ee'
  inverse-primary: '#ffb4a8'
  secondary: '#455f87'
  on-secondary: '#ffffff'
  secondary-container: '#b5d0fd'
  on-secondary-container: '#3e5980'
  tertiary: '#744f00'
  on-tertiary: '#ffffff'
  tertiary-container: '#946600'
  on-tertiary-container: '#fff1e1'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#ffdad4'
  primary-fixed-dim: '#ffb4a8'
  on-primary-fixed: '#410100'
  on-primary-fixed-variant: '#8e1308'
  secondary-fixed: '#d5e3ff'
  secondary-fixed-dim: '#adc8f5'
  on-secondary-fixed: '#001c3b'
  on-secondary-fixed-variant: '#2d486d'
  tertiary-fixed: '#ffdead'
  tertiary-fixed-dim: '#fabc4d'
  on-tertiary-fixed: '#281900'
  on-tertiary-fixed-variant: '#604100'
  background: '#fff8f5'
  on-background: '#221a14'
  surface-variant: '#f0dfd6'
  sepia-parchment-bg: '#FBF7EE'
  sepia-ink: '#2D241E'
  sepia-border: '#E8DEC9'
  velin-light-bg: '#FAF9F6'
  velin-ink: '#1A1A1A'
  velin-border: '#E3E0D8'
  nuit-canvas-bg: '#141619'
  nuit-surface-card: '#1E2226'
  nuit-ink: '#D8D4CF'
  nuit-border: '#2E3339'
  highlight-amber: '#FDE68A'
  highlight-vermillon: '#FECACA'
  highlight-ultramarine: '#BFDBFE'
typography:
  display-hero:
    fontFamily: Merriweather
    fontSize: 40px
    fontWeight: '700'
    lineHeight: 52px
  display-hero-mobile:
    fontFamily: Merriweather
    fontSize: 30px
    fontWeight: '700'
    lineHeight: 38px
  headline-lg:
    fontFamily: Merriweather
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 42px
  headline-lg-mobile:
    fontFamily: Merriweather
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 32px
  headline-md:
    fontFamily: Merriweather
    fontSize: 22px
    fontWeight: '700'
    lineHeight: 30px
  headline-sm:
    fontFamily: Merriweather
    fontSize: 18px
    fontWeight: '700'
    lineHeight: 26px
  reader-body-lg:
    fontFamily: Merriweather
    fontSize: 20px
    fontWeight: '400'
    lineHeight: 34px
  reader-body-md:
    fontFamily: Merriweather
    fontSize: 17px
    fontWeight: '400'
    lineHeight: 29px
  reader-body-sm:
    fontFamily: Merriweather
    fontSize: 15px
    fontWeight: '400'
    lineHeight: 24px
  ui-body-lg:
    fontFamily: Manrope
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  ui-body-md:
    fontFamily: Manrope
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-md:
    fontFamily: Manrope
    fontSize: 13px
    fontWeight: '600'
    lineHeight: 18px
    letterSpacing: 0.02em
  label-sm:
    fontFamily: Manrope
    fontSize: 11px
    fontWeight: '700'
    lineHeight: 16px
    letterSpacing: 0.05em
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  gutter: 1rem
  gutter-mobile: 0.75rem
  margin: 2rem
  margin-mobile: 1.25rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2.5rem
---

## Brand & Style

This design system draws its inspiration from the historic woodcut prints and stenciled vignettes of 19th-century Épinal imagery, synthesized with contemporary French editorial typography and calm digital ergonomics.

The personality balances **scholarly refinement** with **approachable folk artistry**. It avoids both clinical minimalism and cluttered nostalgia, choosing instead a clean, bookmaker's aesthetic: structured framing, generous margins, sharp contrast, and purposeful flourishes of traditional hand-inked pigments (garance madder red, deep ultramarine, and illumination gold).

The visual movement is a hybrid of **French Editorial Classicism** and **Modern Tactile Content-First Design**. Visual interfaces step backward to let text breathe; surfaces evoke genuine paper weights, rich printing inks, and artisanal bookbinding rather than generic digital glass or synthetic neon.

## Colors

The palette establishes an intentional dialogue between vibrant folkloric printmaking accents and rigorous optical reading substrates.

### Heritage Identity Accents
- **Rouge Garance (`#C83E2D`)**: The primary brand accent, echoing the signature vermillon stencils of traditional French woodblock prints. Used for primary CTAs, active reading chapter markers, bookmark ribbons, and crucial focus points.
- **Bleu Outremer (`#1E3A5F`)**: The deep indigo stabilizing tone. Used for system navigation, secondary buttons, collection headers, and metadata tags.
- **Or d'Enluminure (`#E5A93C`)**: Warm illumination yellow used for rating stars, annotation callouts, active highlights, and reading milestones.

### Reading Paper Substrates & Modes
The design system supports three dedicated reading modes with matched foreground-to-background contrast ratios meeting WCAG AAA for body text:
- **Mode Sépia (Confort Visuel / Parchemin)**: Base background `#FBF7EE` paired with iron gall ink `#2D241E` and subtle raw fiber dividers `#E8DEC9`.
- **Mode Clair (Papier Vélin)**: Crisp, non-blinding natural ivory `#FAF9F6` paired with carbon ink `#1A1A1A` and structural border tone `#E3E0D8`.
- **Mode Nuit (Encre Noire Douce)**: Velvety lampblack `#141619` with elevated card surface `#1E2226`, text rendered in muted newsprint chalk `#D8D4CF`, and borders softened with `#2E3339` to eliminate ocular vibration in pitch darkness.

## Typography

The typographic hierarchy enforces a disciplined division of labor:
1. **The Literary Voice (`Merriweather`)**: Dedicated to reading canvases, book titles, author credits, and chapter headpieces. Its sturdy serifs, open counters, and mild stroke modulation recreate the warmth of relief type without degrading legibility on standard DPI mobile screens.
2. **The Instrument Voice (`Manrope`)**: A clean, balanced sans-serif employed for chrome, catalog tables, settings sheets, progress indicators, and library shelf metadata.

Reading body text enforces a default line-height of `1.7x` font size to optimize continuous track scanning. Dynamic type controls scale the `reader-body-*` tier independently of the surrounding UI chrome.

## Layout & Spacing

Layouts follow an asymmetric book spread model.

- **Reading Viewport**: Centered single-column fluid column capped at a maximum width of `680px` on tablets/foldables, preserving the ideal 60–75 characters-per-line (CPL) reading metric.
- **Library Grid**: Adaptive 2-column grid on mobile (`<600px`), shifting to 4-to-6 columns on tablets (`>=600px`) and desktop viewports (`>=1024px`).
- **Margins & Gutters**: Outer margins adapt from `1.25rem` on mobile handsets to `2rem` on wide tablets. Spacing utilizes strict multiples of `4px` with `space-md` (`1rem`) anchoring default card paddings and list separators.

## Elevation & Depth

This system avoids floating, glossy dropshadows, drawing instead from physical paper sheets, hand-pressed block ink, and bookmaker binding layers:

- **Level 0 (Flat Page Canvas)**: The primary substrate (`#FAF9F6`, `#FBF7EE`, or `#141619`).
- **Level 1 (Card & Shelf Surfaces)**: Delineated not by heavy drop shadows, but through 1px crisp outline seams (`sepia-border` or `velin-border`) and micro-tinted backgrounds.
- **Level 2 (Overlays, Floating Control Ribbons & Sheets)**: Gentle ambient feathering mimicking paper held above paper: `box-shadow: 0 4px 20px -2px rgba(45, 36, 30, 0.08)` in light/sepia modes, and `0 4px 24px -2px rgba(0, 0, 0, 0.45)` in dark mode.
- **Page Curl & Transition ("Livre Animé")**: Physical skeuomorphic shading applied along the binding spine with a linear gradient mask fading from `rgba(0,0,0,0.12)` to `transparent` across `16px` to represent page depth.

## Shapes

Shapes emulate trimmed paper stock and book edges. Corner radiuses remain modest (`0.25rem` base, `0.5rem` on cards and floating sheets).

Avoid hyper-rounded pill buttons or circular bubbles for text-heavy widgets, reserving true rounds only for circular iconography (such as audio-playback badges, font size increment toggles, or avatar stamps). Book covers maintain straight, crisp corners (`0px` or `2px` micro-radius) with an embossed spine seam on the left edge.

## Components

### Buttons & Action Bars
- **Primary Action (Garance Vermillon)**: Solid background `#C83E2D`, text `#FFFFFF`, border-radius `0.25rem`. Subtle pressed state shifts lightness down to `#AD3425`.
- **Secondary Action (Outremer Outline)**: 1.5px border `#1E3A5F`, text `#1E3A5F`, background transparent.
- **Subtle Reader Controls**: Borderless buttons with icon glyphs rendered in the active ink tone (`sepia-ink` or `velin-ink`), displaying a gentle 10% opacity tint on active press.

### Chips & Badges
- **Editorial Chips**: Minimalist borders with typography set in `label-sm` uppercase.
- **Genre/Status Tags**: Tinted backgrounds using 10% primary garance or secondary outremer pigments with high-contrast text.

### Book Cards (Library Grid)
- Aspect ratio `1:1.48` for covers, surrounded by a 1px border.
- Bottom metadata container features the book title in `Merriweather` (`headline-sm`), author in `Manrope` (`ui-body-md`), and reading progress percentage displayed via a thin 2px bar colored in `tertiary_color_hex` (`#E5A93C`).

### EPUB Reading Engine HUD & Sliders
- **Floating Sheet ("Confort de Lecture")**: A bottom drawer displaying active font toggles, line-spacing steppers, and brightness.
- **Mode Toggle**: Three segmented round tokens displaying visual swatches for Vélin, Sépia, and Nuit, bounded by a 2px active indicator ring.
- **Progress Track**: A hairline 3px slider with an `#E5A93C` filled segment and an antique brass circular thumb (`14px`).

### Text Selection & Annotation Popover
- Compact floating toolbar hovering directly above highlight anchors.
- Includes 3 quick swatch dots: Amber illumination (`#FDE68A`), Vermillon wash (`#FECACA`), and Outremer wash (`#BFDBFE`), accompanied by a text-note quill icon.