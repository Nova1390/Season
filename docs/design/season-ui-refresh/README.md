# Season UI Refresh — Design Direction

## Goal
Upgrade the visual design of the Season iOS app from a functional utility style to a more:
- editorial
- premium
- lifestyle-oriented product

The app should feel closer to a curated food experience than a database.

---

## Design References

All visual references are inside this folder:
- `_research/stitch/` → main visual inspiration (PNG screens)
- `Season Editorial Forager.html` → structured layout reference
- `screens-a.jsx / screens-b.jsx / screens-c.jsx` → component & layout breakdown
- `ui.jsx` → reusable UI primitives
- `frames/` → device framing

These are NOT to be replicated pixel-perfect.
They define direction, not strict UI specs.

---

## Key Principles

### 1. Strong Visual Hierarchy
- Large hero sections
- Clear separation between sections
- Less “flat list”, more “content blocks”

### 2. Editorial Feel
- Content should feel curated
- Not just “data display”
- More storytelling (images first, text second)

### 3. Breathing Space
- More spacing between elements
- Avoid dense stacked cards
- Reduce visual noise

### 4. Consistent Design Language
- Same corner radius across app
- Same spacing system
- Same typography scale
- Same card style

---

## What MUST NOT change

- Supabase logic
- ViewModels
- Data flow
- Business logic
- Authentication

This is a **UI/UX refactor only**

---

## Priority Screens

1. HomeView
2. RecipeDetailView
3. Search / Discovery

---

## Implementation Strategy

- Do NOT rewrite everything
- Refactor progressively
- Reuse existing components when possible
- Create new reusable UI components if needed

---

## Notes

The current app feels:
- too “system UI”
- too neutral
- not memorable

Target:
- visually distinctive
- modern
- emotionally engaging