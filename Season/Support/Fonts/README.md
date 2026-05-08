# Font bundle — Season v2

Scarica i 3 font da Google Fonts e trascina i file `.ttf` elencati qui dentro questa cartella.

## 1. Newsreader
https://fonts.google.com/specimen/Newsreader → "Get font" → scarica lo zip.
Dallo zip, copia in questa cartella **solo** i file static (`Newsreader/static/`):

- `Newsreader-Regular.ttf`
- `Newsreader-Medium.ttf`
- `Newsreader-Italic.ttf`

## 2. Inter
https://fonts.google.com/specimen/Inter → "Get font".
Dallo zip, copia (`Inter/static/`):

- `Inter-Regular.ttf`
- `Inter-Medium.ttf`
- `Inter-SemiBold.ttf`
- `Inter-Bold.ttf`

## 3. JetBrains Mono
https://fonts.google.com/specimen/JetBrains+Mono → "Get font".
Dallo zip, copia (`JetBrains_Mono/static/`):

- `JetBrainsMono-Regular.ttf`
- `JetBrainsMono-Medium.ttf`

## Totale: 9 file .ttf, ~2 MB

## Dopo aver trascinato i file
1. Apri `Season.xcodeproj` in Xcode
2. Seleziona la cartella `Support/Fonts` nel navigator → trascina i 9 `.ttf` nel progetto se non sono già visibili (target: Season, "Copy items if needed" NON spuntato, dato che sono già nella cartella)
3. In `Season-Info.plist` i font verranno registrati automaticamente tramite `UIAppFonts` (lo aggiungo io al codice in `DesignSystem.swift`, vedi task successivo)

## Fallback
`DesignSystem.swift` è scritto in modo che, se un font non è caricato, cade su `.system` — l'app continua a funzionare anche senza i file. Niente crash.
