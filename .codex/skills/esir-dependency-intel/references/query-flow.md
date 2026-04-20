# Query Flow

Default flow:

1. Run `query` against the checked-in catalog.
2. Narrow with `-Scope`, `-Category`, `-ModName`, `-Pack`, or `-Path`.
3. Add `-ResolveInstalled` only when local presence or local file roots matter.
4. Read the owning source file before editing behavior.
5. After behavior changes, run `refresh` and usually `diff`.

Useful sidecar role labels for read-only parallel analysis:

- `dependency-touchpoint explorer`
- `dependency-runtime explorer`
- `dependency-prototype explorer`
- `dependency-presence explorer`

Good first prompts:

- "Query all touchpoints for `DiscoScience`."
- "Show remote-interface touchpoints for `informatron`."
- "Show planet/content touchpoints for `planet-muluna`."
- "Resolve local presence for `zzz-nonstandard-beacons`."
