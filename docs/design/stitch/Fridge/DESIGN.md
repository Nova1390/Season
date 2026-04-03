# Design System Specification: Editorial Organicism

## 1. Overview & Creative North Star
The Creative North Star for this design system is **"The Digital Greenhouse."** We are moving away from the rigid, boxed-in layouts of traditional mobile apps toward an editorial experience that feels grown, not manufactured. 

To achieve a premium, high-end feel that rivals Apple and Notion, this system breaks the "template" look through **Intentional Asymmetry** and **Tonal Depth**. We prioritize high-contrast typography scales and generous whitespace over structural lines. By layering soft, organic surfaces and utilizing large-scale food photography as a structural element rather than just decoration, we create an interface that feels intelligent, trustworthy, and effortless.

---

## 2. Colors & Surface Philosophy
The palette is rooted in nature, using muted Sage (`primary`) and Earthy Terracotta (`secondary`) to accent a sophisticated range of off-whites and warm grays.

### The "No-Line" Rule
**Explicit Instruction:** Do not use 1px solid borders to section content. Boundaries must be defined solely through background color shifts. For example, a `surface-container-low` section sitting on a `surface` background creates a soft, natural break. High-contrast lines clutter the visual field; we use "negative space" as our primary divider.

### Surface Hierarchy & Nesting
Treat the UI as a series of physical layers—like stacked sheets of heavy-stock vellum.
- **Base:** `surface` (#f9f9f7)
- **Secondary Layouts:** `surface-container-low` (#f4f4f2)
- **Interactive Elevated Cards:** `surface-container-lowest` (#ffffff)
- **Deep Inset Elements:** `surface-container-high` (#e8e8e6)

### The "Glass & Gradient" Rule
To move beyond a "standard" flat look, use Glassmorphism for floating navigation bars or modal headers. Use a `surface-container-lowest` color at 70% opacity with a `20px` backdrop-blur. 
**Signature Texture:** For primary CTAs, apply a subtle linear gradient from `primary` (#526048) to `primary_container` (#6a795f) at a 135° angle. This adds "soul" and depth that flat hex codes cannot replicate.

---

## 3. Typography
We use a dual-font strategy to balance editorial authority with functional clarity.

*   **Display & Headline (Manrope):** Chosen for its geometric yet organic warmth. High tracking-reduction (-0.02em) should be applied to `display-lg` to create a tight, professional "masthead" feel.
*   **Title & Body (Inter/SF Pro Style):** Optimized for high readability. Use `title-lg` for recipe names to ensure they command attention without the weight of a headline.

**Hierarchy as Brand:** Use `label-sm` in all-caps with `0.05em` letter spacing for "Seasonal Tags" (e.g., "AUTUMN"). This creates an authoritative, curated feel.

---

## 4. Elevation & Depth
In this system, depth is a whisper, not a shout. We convey hierarchy through **Tonal Layering** rather than traditional structural shadows.

*   **The Layering Principle:** Place a `surface-container-lowest` card (Pure White) on a `surface-container-low` section. The contrast in brightness provides a natural lift.
*   **Ambient Shadows:** If a "floating" effect is required (e.g., a Bottom Sheet), use a custom shadow: 
    *   `Y: 8px, Blur: 24px, Color: rgba(26, 28, 27, 0.04)` (a tint of `on_surface`). 
    *   Never use pure black for shadows; always use a desaturated version of your surface ink.
*   **The "Ghost Border" Fallback:** If a border is required for accessibility, use the `outline_variant` (#c5c8bd) at **15% opacity**. It should be felt, not seen.

---

## 5. Components

### Buttons
*   **Primary:** `primary` (#526048) background with `on_primary` (#ffffff) text. Corner radius: `md` (1.5rem).
*   **Secondary:** `secondary_fixed` (#ffdbcf) background with `on_secondary_container` (#793e29) text. This provides a warm, earthy contrast for secondary actions like "Save to Favorites."
*   **Tertiary:** Transparent background, `primary` text, with a `sm` (0.5rem) padding for a clean, text-link look.

### Cards & Imagery
*   **The "Bleed" Layout:** Food photography should frequently bleed to the edges of cards or the top of the screen. 
*   **Rounding:** Apply `lg` (2rem) or `xl` (3rem) corner radius to image containers to mimic the soft shapes of nature.
*   **No Dividers:** In lists (e.g., ingredients), use `3.5rem` (`spacing-10`) of vertical whitespace instead of a divider line.

### Input Fields
*   **Style:** Minimalist. Use `surface-container-highest` for the background with a `sm` (0.5rem) corner radius. 
*   **State:** On focus, transition the background to `surface-container-lowest` and add a "Ghost Border" of `primary` at 20% opacity.

### Selection Chips
*   **Unselected:** `surface-container-high` background, `on_surface_variant` text.
*   **Selected:** `primary` background, `on_primary` text. Use `full` (9999px) rounding for a pill shape.

---

## 6. Do's and Don'ts

### Do
*   **Do** use asymmetrical margins. For example, a headline might have a `spacing-8` left margin, while body text has `spacing-12` to create a sophisticated editorial rhythm.
*   **Do** use large-scale imagery as the background for entire scroll sections, overlaying `surface` containers with high transparency.
*   **Do** prioritize the `surface-container` tiers to create "islands" of content rather than a continuous vertical stack.

### Don't
*   **Don't** use 100% opaque, high-contrast borders. This breaks the "calm" and "effortless" feeling.
*   **Don't** use standard iOS "Blue" for links. Use `secondary` (Terracotta) for a curated, bespoke aesthetic.
*   **Don't** crowd the screen. If a screen feels busy, increase the spacing from `spacing-4` to `spacing-6` or `spacing-8`. Silence is as important as the content.
*   **Don't** use sharp corners. Everything in this system should feel soft to the touch, referencing the organic nature of seasonal food.