# import-recipe-from-url

Minimal structured-data URL importer for internal/admin usage.

## Input

```json
{
  "url": "https://example.com/recipe"
}
```

## Success output

```json
{
  "title": "...",
  "ingredients": ["..."],
  "steps": ["..."],
  "source_url": "https://example.com/recipe",
  "source_name": "example.com"
}
```

## Error output

```json
{
  "ok": false,
  "error": {
    "code": "NO_STRUCTURED_DATA",
    "message": "No recipe structured data found."
  }
}
```

## Notes
- Extracts only `application/ld+json` recipe data.
- No raw HTML is returned.
- Requires authenticated user JWT or service role credentials.
