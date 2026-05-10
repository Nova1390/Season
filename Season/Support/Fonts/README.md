# Font bundle — Season v2

I font richiesti dal design system sono gia presenti in questa cartella e registrati in `Season-Info.plist` tramite `UIAppFonts`.

Usa questa pagina come checklist di manutenzione: se un font viene rimosso, rinominato o aggiornato, mantieni allineati questa cartella, `Season-Info.plist` e `Season/Views/DesignSystem.swift`.

## Font inclusi

### 1. Newsreader
https://fonts.google.com/specimen/Newsreader → "Get font" → scarica lo zip.

- `Newsreader-Regular.ttf`
- `Newsreader-Medium.ttf`
- `Newsreader-Italic.ttf`

### 2. Inter
https://fonts.google.com/specimen/Inter → "Get font".

- `Inter-Regular.ttf`
- `Inter-Medium.ttf`
- `Inter-SemiBold.ttf`
- `Inter-Bold.ttf`

### 3. JetBrains Mono
https://fonts.google.com/specimen/JetBrains+Mono → "Get font".

- `JetBrainsMono-Regular.ttf`
- `JetBrainsMono-Medium.ttf`

## Totale: 9 file .ttf, ~2 MB

## Verifica

1. Controlla che i 9 file `.ttf` siano presenti in `Season/Support/Fonts`.
2. Controlla che gli stessi file siano elencati in `Season-Info.plist` sotto `UIAppFonts`.
3. Controlla che i nomi PostScript usati da `Season/Views/DesignSystem.swift` restino coerenti.

## Fallback
`DesignSystem.swift` e scritto in modo che, se un font non e caricato, cade su `.system`; l'app continua a funzionare anche senza i file.
