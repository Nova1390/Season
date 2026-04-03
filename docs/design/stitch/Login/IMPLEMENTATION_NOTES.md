# Stitch Login Implementation Notes

## Source Files Used
- `docs/design/stitch/code.html`
- `docs/design/stitch/screen.png`
- `docs/design/stitch/DESIGN.md`

## Applied Design Signals
- Full-bleed food photo background (`object-cover` behavior in Stitch HTML)
- Soft top-to-bottom readability gradient while keeping imagery visible
- No top logo/brand mark (none present in Stitch export)
- Hero copy:
  - `Eat better, in season.`
  - `Turn what’s in your fridge into smarter seasonal meals.`
- CTA stack and order:
  - Primary: `Continue with Apple`
  - Secondary: `Sign up with email`
  - Footer link: `Already have an account? Log in`
- Rounded, pill-shaped buttons and restrained earthy green gradient for email CTA

## Notes
- The Stitch export references a hosted image URL for background art. A local app asset (`auth_stitch_login_bg`) was added from that source URL to avoid runtime network dependency.
