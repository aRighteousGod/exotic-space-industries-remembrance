# Spider technology icon family

The 41 technologies use eight original transparent subjects and twelve reusable
modifier/tier layers in the main mod's `graphics/technology/spider-vehicles/`
directory. Assault Spidertron uses its dependency's
existing technology portrait; the original rocket Spidertron keeps vanilla art.
Weapon research reuses existing weapon/ammunition art, including ESIR's siege
artillery rocket and the full-size Minigun/Heavy minigun technology portraits.

`prompts.json` records the built-in image_gen prompts and source locations.
`prepare.py` resizes the approved subjects without recoloring or reconstructing
them, and draws the original geometric UI glyphs. Each semantic layer ships
separately; the engine composes the final technology icons. These assets ship
with the gameplay pack; Graphics 5 and its minimum dependency remain at 1.0.0.

The generator and prompts live here because the session's `.codex` tree is
read-only. Generated staging, data dumps and previews remain ignored.

```powershell
python scripts/art/spider-technology-icons/prepare.py
# After inspecting the staged exports:
python scripts/art/spider-technology-icons/prepare.py --promote
python scripts/art/spider-technology-icons/review.py --dump <data-raw-dump.json> --baseline <previous-data-raw-dump.json>
```

The source images must be available at the paths in `prompts.json` to reproduce
their mechanical export. The shipped PNGs are self-contained. Generating new art
from the saved prompts is a new image-generation run, not a deterministic rebuild.

The review reads actual final prototypes, resolves assets through the existing
ESIR icon-review resolver, and renders 256/64/32px compositions. The contact sheet
also shows grayscale and an explicit worst-case cost-badge overlay. It validates
41 unique compositions, seven-locale parity, resolved research titles, and
unchanged technology fields apart from icons and localized names when a baseline
is supplied. The standalone HTML embeds every image for portable review.

Research names for the four artillery rocket technologies have their own locale
entries. Weapon and GUI names remain shorter; internal `doeworks` keys and
prototype names are intentionally preserved for saves and API compatibility.
Remaining appearances of the upstream name in dependency IDs and attribution
are not gameplay terminology.

Manual in-game verification is excluded at the user's request. Use the existing
headless spider acceptance fixture for production GUI callback and state checks;
the contact sheet proves asset composition, not native GUI layout or input.

Validation on Factorio 2.0.77 (2026-09-21): all 41 final icon compositions are
distinct, all seven locales have the same 83 spider keys, and the technology
comparison found no changes outside icons and localized names. The final
headless acceptance fixture passed all 184 runtime checks. The data-stage load
and whitespace checks passed. Preflight passed its syntax, reference, encoding,
and version checks, with existing module-header warnings in two unrelated
control modules; the quick-load wrapper also retains integration log warnings.
The staged review covers 256/64/32px, grayscale, and cost-badge clearance.
