# Home Stitch Implementation Notes

## Source of Truth Used
- `docs/design/stitch/Home/code.html`
- `docs/design/stitch/Home/screen.png`
- `docs/design/stitch/Home/DESIGN.md`

## Section Mapping (UI Only)
- Hero (`Best Match`, contextual label, CTA): reused existing `featuredRecipe`, `homeHero*` copy, and existing fridge matches navigation.
- Ready to Cook Now: reused existing `fridgeMatches` from `buildFridgeSection` / fridge recommendation flow.
- Peak Season Now: reused existing seasonal spotlight source from `buildSeasonalSpotlight(usageCountByID:)`.
- Weekly Discoveries: reused existing dynamic feed cards from `activeMiniFeedItems + remainingFeedItems`.

## Constraints Respected
- No business logic/data source changes.
- No API/model changes.
- Existing navigation destinations preserved.
