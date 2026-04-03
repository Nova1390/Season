# Season Project Rules

- This is a production SwiftUI app.
- Do not break authentication flows.
- Do not invent backend changes.

## DESIGN SYSTEM

- Always check docs/design/ before implementing UI.
- Treat docs/design/ as the source of truth for UI decisions.
- If a design is missing, create a new folder under docs/design/.

## IMPLEMENTATION

- Use AuthGateView.swift for login.
- Keep UI premium, minimal, editorial.
- Reuse components when possible.

- Always explain changes and list modified files.

## DESIGN SOURCE OF TRUTH

- Always check docs/design/ before implementing any UI.
- The folder docs/design/stitch/ contains design exports and references.
- Treat files inside docs/design/stitch/ as the primary design source.
- If multiple designs exist, use the most recent or most complete one.
- If design files are unclear, infer the intended UI but stay consistent with the design system.

- Never ignore docs/design/stitch/ when working on UI.
