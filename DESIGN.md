---
name: Reforged
description: Warm, calm, devotional-but-modern Bible study & Scripture-memory app — a thoughtful friend for a daily habit with God's Word.
colors:
  charcoal: "#333333"
  cream: "#E8E4DC"
  coral: "#E94560"
  coral-deep: "#C32C45"
  coral-wash: "#FDF1F3"
  gold: "#D4A574"
  gold-deep: "#B07F4E"
  gold-wash: "#FAF3E9"
  app-bg: "#FAF8F5"
  card: "#FFFFFF"
  sunken: "#EFEDE9"
  text-primary: "#2D2D2D"
  text-secondary: "#666666"
  text-tertiary: "#9A9A9C"
  reference: "#B07F4E"
  track-green: "#339966"
  track-indigo: "#4D4D99"
  track-purple: "#804D99"
  border-card: "#E5E5E5"
  dark-app-bg: "#1C1C1F"
  dark-card: "#2B2B2E"
typography:
  display:
    fontFamily: "Archivo, system-ui, sans-serif"
    fontSize: "64px"
    fontWeight: 900
    lineHeight: 1.05
    letterSpacing: "-0.02em"
  headline:
    fontFamily: "-apple-system, system-ui, 'Roboto Flex', sans-serif"
    fontSize: "34px"
    fontWeight: 700
    lineHeight: 1.2
    letterSpacing: "-0.01em"
  title:
    fontFamily: "-apple-system, system-ui, 'Roboto Flex', sans-serif"
    fontSize: "22px"
    fontWeight: 700
    lineHeight: 1.2
    letterSpacing: "-0.01em"
  body:
    fontFamily: "-apple-system, system-ui, 'Roboto Flex', sans-serif"
    fontSize: "16px"
    fontWeight: 400
    lineHeight: 1.4
    letterSpacing: "normal"
  scripture:
    fontFamily: "'New York', 'Libre Baskerville', Georgia, serif"
    fontSize: "18px"
    fontWeight: 400
    lineHeight: 1.65
    letterSpacing: "normal"
  label:
    fontFamily: "-apple-system, system-ui, 'Roboto Flex', sans-serif"
    fontSize: "13px"
    fontWeight: 600
    lineHeight: 1.2
    letterSpacing: "0.12em"
rounded:
  xs: "8px"
  sm: "12px"
  md: "16px"
  lg: "20px"
  xl: "24px"
  pill: "999px"
spacing:
  xs: "4px"
  sm: "8px"
  s3: "12px"
  md: "16px"
  s5: "20px"
  lg: "24px"
  xl: "32px"
  xxl: "48px"
components:
  button-primary:
    backgroundColor: "{colors.coral}"
    textColor: "{colors.card}"
    rounded: "{rounded.pill}"
    typography: "{typography.title}"
    padding: "16px 24px"
    height: "52px"
  button-primary-hover:
    backgroundColor: "{colors.coral-deep}"
    textColor: "{colors.card}"
    rounded: "{rounded.pill}"
    height: "52px"
  button-ghost:
    backgroundColor: "{colors.card}"
    textColor: "{colors.coral}"
    rounded: "{rounded.pill}"
    padding: "16px 24px"
    height: "52px"
  card:
    backgroundColor: "{colors.card}"
    textColor: "{colors.text-primary}"
    rounded: "{rounded.md}"
    padding: "16px"
  card-hero:
    backgroundColor: "{colors.charcoal}"
    textColor: "{colors.cream}"
    rounded: "{rounded.xl}"
    padding: "24px"
  stat-tile-coral:
    backgroundColor: "{colors.coral-wash}"
    textColor: "{colors.coral-deep}"
    rounded: "{rounded.md}"
    padding: "16px"
  stat-tile-gold:
    backgroundColor: "{colors.gold-wash}"
    textColor: "{colors.gold-deep}"
    rounded: "{rounded.md}"
    padding: "16px"
  chip:
    backgroundColor: "{colors.sunken}"
    textColor: "{colors.text-secondary}"
    rounded: "{rounded.xs}"
    padding: "6px 12px"
  input:
    backgroundColor: "{colors.card}"
    textColor: "{colors.text-primary}"
    rounded: "{rounded.sm}"
    height: "52px"
    padding: "0 16px"
---

# Design System: Reforged

## Overview

**Creative North Star: "The Devotional Companion"**

Reforged is designed as a thoughtful friend who sits beside you while you read —
warm, sincere, and quietly confident, never a marketer and never a teacher
scolding from the front. Every surface is built to feel like a calm, unhurried
place you *want* to return to each day: a warm paper-like off-white canvas, soft
white cards, and generous quiet space, with the interface receding so Scripture
and the reader's own progress can lead. The mood is devotional-but-modern —
gentle and gamified at once, but the gamification is a companion's encouragement,
not a casino's pull.

The system is **refined and restrained**: typography, whitespace, and a single
warm brand mark carry the identity, and decoration is kept off the page. Color is
used with discipline — a charcoal-and-cream foundation drawn straight from the
logo, warmed by exactly two living accents (coral for action and streak, gold for
reward and Scripture). Those accents appear as small, deliberate moments —
a streak flame, a level star, a verse reference — against large calm neutrals, so
they always read as meaningful rather than loud. Reforged is honest and
ad-free by design; the visual language must never feel like an engagement funnel.

Depth is **layered and lifted**: cards sit clearly above the paper on a
consistent, deliberate elevation ladder, so the eye always knows what floats and
what rests. The shadows themselves stay warm and soft — the lift is structural,
never harsh — and the reward tiles and floating navigation sit highest. Motion is
minimal and purposeful: a gentle tactile press, an animating progress fill, a
spring only for a genuine celebration. Nothing loops, nothing decorates.

**Key Characteristics:**
- Warm paper off-white canvas; soft white cards; charcoal logo mark.
- Two-accent discipline: coral (action/streak/memory), gold (reward/level/Scripture).
- Refined and restrained — type and whitespace lead; ornament stays out.
- Layered, lifted depth on a soft warm shadow ladder; reward tiles float highest.
- Scripture is sacred: serif, always referenced and translation-tagged, never paraphrased.
- Calm, honest, ad-free — no gradients in chrome, no textures, no dark patterns.

## Colors

A charcoal-and-cream foundation from the logo, set on warm off-white paper, warmed
by exactly two accents — coral for action, gold for reward — with a small set of
muted category hues reserved for learning tracks.

### Primary
- **Signal Coral** (`#E94560`): the single action accent — primary buttons, the
  streak flame, "verses due" and memory prompts, notification/error state. It is
  the app's call to *act*. Deep Coral (`#C32C45`) is its pressed/hover shade.

### Secondary
- **Devotional Gold** (`#D4A574`): the reward accent — XP, levels, badges, and
  Scripture references. Warm and earned, never urgent. Deep Gold (`#B07F4E`,
  `--reference`) sets verse references like "— Romans 6:23" so they read on light
  paper.

### Tertiary
- **Track accents** — used only to color learning-track and category tiles, never
  general UI: **Track Green** (`#339966`), **Track Indigo** (`#4D4D99`), **Track
  Purple** (`#804D99`). "Blue"-named tracks resolve to charcoal-navy, not a true blue.

### Neutral
- **Logo Charcoal** (`#333333`): the brand mark, the dark hero/greeting card, and
  the strongest UI ink. *Foundational, not a "navy" — see the rule below.*
- **Logo Cream** (`#E8E4DC`): text and marks set on the charcoal hero surface.
- **Warm Paper** (`#FAF8F5`): the app background — a warm, low-contrast off-white,
  never pure white and never gray.
- **Card White** (`#FFFFFF`): resting card surface, lifted above the paper.
- **Sunken** (`#EFEDE9`): inset quote/verse blocks and pressed wells.
- **Ink** — Primary text `#2D2D2D`, Secondary `#666666`, Tertiary `#9A9A9C`.
- **Hairline** (`#E5E5E5`): card borders, mostly subtle or absent.

### Dark & AMOLED
Full first-class dark mode mirrors `Theme.swift`: app `#1C1C1F`, card `#2B2B2E`,
sunken `#242427`, primary text `#EDEDF0`. AMOLED drops the app to pure `#000000`
with `#141416` cards. Coral and gold carry across all themes unchanged; only the
neutrals swap.

### Named Rules
**The Two-Accent Rule.** Coral and gold are the *only* expressive colors. Coral
means "act," gold means "earned/Scripture" — never blur them, and never introduce
a third brand accent. Track hues are the sole exception and live only on track tiles.

**The Charcoal-Not-Navy Rule.** The tokens historically named `reforgedNavy` /
`reforgedDarkBlue` are charcoal greys (`#333333` / darker), not blue. Any icon or
accent that "should be navy" must resolve through `adaptiveNavyText(colorScheme)`
so it flips to off-white on dark surfaces — a raw charcoal literal disappears on a
dark card. Only gold, coral, and the track hues are safe as literals in both themes.

**The Warm-Paper Rule.** The canvas is warm off-white (`#FAF8F5`), never pure
white and never cool gray. Cards are the white; the ground stays warm.

## Typography

**Display Font:** Archivo (Black, 900) — marketing posters and hero campaign
headlines only, uppercase with tight tracking. Never inside app chrome.
**UI Font:** SF Pro / system-ui (bundled **Roboto Flex** as the selectable custom
face) — every screen title, label, button, and body string.
**Scripture Font:** the **system serif (New York)** in the running app; **Libre
Baskerville** is the brand's canonical serif for web and marketing. Verse and
devotional text only, at a relaxed 1.65 line-height; italic for devotional quotes.

**Character:** a clean, confident sans carries the interface so it feels native
and calm, while a warm serif gives Scripture its own reverent voice. The two never
trade jobs — UI is never serif, Scripture is never sans.

### Hierarchy
- **Display** (Archivo 900, 64/44/32px, 1.05, `-0.02em`, UPPERCASE): marketing
  posters only — "YOUR FAITH NEEDS MORE THAN INSPIRATION."
- **Headline / Screen Title** (system bold 700, 34px, 1.2, `-0.01em`): large
  navigation titles ("Scripture Memory"), collapsing to inline on scroll.
- **Title / Card Headline** (system bold 700, 22px, 1.2): card and section heads.
- **Body** (system 400, 16px, 1.4): default UI copy. Scripture reading defaults
  to 18px.
- **Scripture** (serif 400, 18px, 1.65): verse text and devotional quotes; italic
  for reflective pull-quotes. Honors the reader's font-size and spacing settings.
- **Label / Eyebrow** (system semibold 600, 13px, `0.12em`, UPPERCASE, gold): the
  small wide-tracked labels above sections and book names ("JOHN", "VERSES DUE").

### Named Rules
**The Sacred-Serif Rule.** Scripture is *always* serif, *always* carries its
reference and translation tag (ESV/KJV/CSB/NKJV/NASB), and is *never* paraphrased.
The serif face is reserved for Scripture and devotional copy — using it for chrome
cheapens it.

**The Sentence-Case Rule.** UI and body copy are sentence case; Title Case is only
for screen titles and named features; ALL-CAPS display is only for marketing. The
voice is a friend's, not a headline's.

## Layout

A single-column, phone-first canvas (max content width ~440px) with 24px screen
gutters and a base-8 spacing scale (4 · 8 · 12 · 16 · 20 · 24 · 32 · 48). Cards
stack with 12–16px gaps and carry 16px inner padding (20px for larger cards, 24px
for the hero). Controls and inputs stand 52px tall; every hit target clears the
iOS 44px minimum with breathing room between neighbors.

On iPad the app becomes a genuine two-pane workspace: a persistent 320px
`NavigationSplitView` sidebar (Home / Discipleship / Bible / Memory / Groups /
Profile / Settings) beside a ≥400px detail pane, and the Bible reader gains a
trailing study-tools rail whose panels dock and reflow the reading column rather
than covering it. iPhone is the primary target; iPad is a first-class, uncompromised
scale-up — never a stretched phone layout.

### Named Rules
**The Base-8 Rule.** All spacing, padding, and gaps come from the 4/8-based scale.
No arbitrary one-off margins.

## Elevation & Depth

Depth is **layered and lifted**, and it is a real structuring device: surfaces are
not flat. Cards rest visibly above the warm paper, and the system reads as a
deliberate stack — resting cards, then elevated sheets and popovers, then floating
navigation and action buttons. The *lift* is structural and consistent; the
*shadows* are soft, warm-black, and diffuse, so nothing ever looks harsh or
web-heavy. Colored reward tiles (streak/level) add a faint same-hue glow that makes
them feel gently backlit, and they — with the floating tab bar — sit at the top of
the ladder.

### Shadow Vocabulary
- **Resting Card** (`box-shadow: 0 4px 8px rgba(0,0,0,0.06)`): every default white card.
- **Elevated / Sheet** (`0 8px 16px rgba(0,0,0,0.12)`): sheets, popovers, raised cards.
- **Floating Nav / FAB** (`0 6px 16px rgba(0,0,0,0.16)`): the tab bar and floating actions.
- **Coral Glow** (`0 6px 18px rgba(233,69,96,0.22)`): coral reward/streak tiles.
- **Gold Glow** (`0 6px 18px rgba(212,165,116,0.22)`): gold level/XP tiles.
- **Sunken Inset** (`inset 0 1px 2px rgba(0,0,0,0.04)`): inset quote/verse wells.

### Named Rules
**The Warm-Shadow Rule.** Every shadow is warm-black, low-opacity, and diffuse —
lift comes from a bigger, softer shadow, never a darker or tighter one. Harsh or
high-contrast drop shadows are off-brand.

**The Elevation-Ladder Rule.** Use exactly the ladder: 0.06 resting → 0.12
elevated → 0.16 floating. Reward tiles glow same-hue; they do not invent new depths.

## Shapes

Soft, rounded, friendly geometry on a fixed radius ladder: **8px** for chips and
small controls, **12px** for compact cards and inputs, **16px** for the default
card, **20px** for larger cards, **24px** for the hero card and sheets, and a full
**pill (999px)** for badges, the tab selection pill, primary CTAs, and FABs.
Corners are never sharp. Borders are hairline (1px) and mostly subtle or absent —
separation comes from surface color and elevation, not lines. Inset blocks (verse
quotes, wells) use a sunken fill plus a faint inner shadow to feel pressed in.

### Named Rules
**The No-Sharp-Corners Rule.** Nothing ships with a 0px radius. The smallest
allowed corner is 8px; the brand's warmth lives in its roundness.

## Components

Components are **refined and restrained**: calm surfaces, generous padding, one
clear job each, and just enough response to feel alive under the finger.

### Buttons
- **Shape:** full pill (999px), 52px tall.
- **Primary:** solid Signal Coral (`#E94560`) with white label; used once per
  screen for the single most important action ("Review now").
- **Hover / Press:** background deepens to `#C32C45`; press scales to `0.97` and
  the shadow collapses — a quiet tactile acknowledgment, not a bounce.
- **Ghost / Secondary:** white (or transparent) surface with a coral or charcoal
  label for lower-priority actions; same pill shape, no fill.

### Chips
- **Style:** soft charcoal wash (`rgba(51,51,58,0.08)`) with secondary-ink label,
  8px radius, no border. Used for the small "Problem / Penalty / Payment / Promise"
  style tags and filters.
- **State:** selected chips take a coral or charcoal fill with reversed text.

### Cards / Containers
- **Corner Style:** 16px default (20px large, 24px hero).
- **Background:** Card White on the warm paper; the **hero/greeting card** inverts
  to charcoal with cream text.
- **Shadow Strategy:** Resting Card (`0.06`) at rest; see Elevation & Depth.
- **Border:** hairline `#E5E5E5`, usually omitted in favor of elevation.
- **Internal Padding:** 16px (20–24px for large/hero).

### Stat Tiles (signature)
- Compact colored KPI tiles for streak, level, and XP. Coral tiles use a faint
  coral wash (`#FDF1F3`) + coral glow; gold tiles use a gold wash (`#FAF3E9`) +
  gold glow. The number is large and bold; the label is a small eyebrow. They are
  the one place color fills a surface — the reward *is* the color.

### Verse Card (signature)
- Scripture set in serif at 1.65 line-height with the reference and translation
  tag beneath in gold. The shareable variant lays the verse over a muted
  photographic background (mountains, field, forest, ocean, sky, sunset) — the
  only photographic imagery in the system.

### Inputs / Fields
- **Style:** Card White fill, 12px radius, 52px tall, hairline border.
- **Focus:** border shifts toward coral; no heavy glow.

### Navigation
- **iPhone:** a translucent, backdrop-blurred bottom tab bar (`rgba(250,248,245,
  0.92)`) with a rounded selection pill behind the active tab; active mark
  charcoal, inactive grey, labels 11px. SF Symbols throughout (Lucide substitutes
  on web).
- **iPad:** the persistent split-view sidebar replaces the tab bar; the Bible
  reader adds a docking study-tools rail.

## Do's and Don'ts

### Do:
- **Do** keep the canvas warm off-white (`#FAF8F5`) and let white cards lift above it.
- **Do** reserve coral for "act" and gold for "earned/Scripture," and keep them to
  small, deliberate moments against large neutrals (the Two-Accent Rule).
- **Do** set all Scripture in serif with its reference and translation tag; honor
  the reader's font and spacing settings.
- **Do** route any "navy" icon/accent through `adaptiveNavyText(colorScheme)` so it
  survives dark mode.
- **Do** build depth from the soft warm ladder (0.06 → 0.12 → 0.16) and let reward
  tiles glow same-hue.
- **Do** press with `scale(0.97)` and animate progress fills; keep motion minimal
  and purposeful.
- **Do** design and test light, dark, and AMOLED, and large Dynamic Type sizes.

### Don't:
- **Don't** introduce a third brand accent, gradients in app chrome, textures, or noise.
- **Don't** use the serif for UI chrome, or the sans for Scripture.
- **Don't** use pure white as the app background or pure black shadows; nothing sharp-cornered (8px floor).
- **Don't** treat charcoal `#333333` as navy or drop a raw charcoal literal onto a dark card.
- **Don't** let the gamification read as pressure — no guilt, no dark patterns, no ad surfaces.
- **Don't** paraphrase Scripture or drop its reference/translation tag.
