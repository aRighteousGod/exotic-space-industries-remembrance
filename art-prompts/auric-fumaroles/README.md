# Auric Fumarole Art Helper

Use the Firefox ChatGPT companion in supervised mode. The helper stages a prompt, opens Firefox, and tracks downloads; you still log in, send the prompt, and click download yourself.

## Prompt Files

- `01a-base-vent-pass-01.txt`
- `01b-base-vent-mutation-pass-02.txt`
- `01c-base-vent-refine-pass-03.txt`
- `01-entity-pass-01.txt`
- `02-core-icon-pass-01.txt`
- `03-vapor-icon-pass-01.txt`
- `04-slag-icon-pass-01.txt`
- `05-afterglow-pass-01.txt`
- `06-steam-overlay-pass-01.txt`

`01a-base-vent-pass-01.txt` is the recommended first entity pass if you want the fumarole split into a static crack base and a separate future steam overlay.
`01b-base-vent-mutation-pass-02.txt` is the follow-up edit pass for darkening the perimeter and reducing sulfur spread so the base vent sits more naturally on Vulcanus tiles.
`01c-base-vent-refine-pass-03.txt` is the narrow polish pass for the selected fissure variant: less outer rock mass, more chipped edges, and faster transparency falloff.
`06-steam-overlay-pass-01.txt` is the first pass for the separate steam-only overlay that will sit above the chosen vent base.

## Start A Session

Run one prompt at a time:

```powershell
powershell -ExecutionPolicy Bypass -File C:\Users\Theorun\.codex\skills\chatgpt-firefox-companion\scripts\invoke-chatgpt-firefox-companion.ps1 `
  -Mode start `
  -RepoRoot C:\Users\Theorun\Documents\github\exotic-space-industries-remembrance-2 `
  -PromptFile C:\Users\Theorun\Documents\github\exotic-space-industries-remembrance-2\art-prompts\auric-fumaroles\01-entity-pass-01.txt `
  -SessionName auric-entity-pass-01
```

Swap the `-PromptFile` and `-SessionName` for the other assets.

## Manual Browser Step

1. Firefox opens to ChatGPT.
2. Log in if needed.
3. Paste or confirm the staged prompt.
4. Generate variants.
5. Download the ones you want into your normal Downloads folder.

## Collect Downloads

After downloading:

```powershell
powershell -ExecutionPolicy Bypass -File C:\Users\Theorun\.codex\skills\chatgpt-firefox-companion\scripts\invoke-chatgpt-firefox-companion.ps1 `
  -Mode collect `
  -RepoRoot C:\Users\Theorun\Documents\github\exotic-space-industries-remembrance-2
```

The helper copies newly downloaded images into the session artifact folder and writes a manifest.

## Check Status

```powershell
powershell -ExecutionPolicy Bypass -File C:\Users\Theorun\.codex\skills\chatgpt-firefox-companion\scripts\invoke-chatgpt-firefox-companion.ps1 `
  -Mode status `
  -RepoRoot C:\Users\Theorun\Documents\github\exotic-space-industries-remembrance-2
```

## Notes

- In this repo, collected artifacts should land under `.factorio-qc\chatgpt-firefox\...`.
- Keep transparent-background downloads when possible.
- For Factorio use, favor silhouette clarity over extra detail.
- After collection, pick the strongest output and move or adapt it into the graphics repo as needed.
