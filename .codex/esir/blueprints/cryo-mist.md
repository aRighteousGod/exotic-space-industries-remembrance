# Native cold mist

<a id="contract"></a>
## Contract

The data-final pass appends one named `ei-cryo-mist` working visual to the
hypercooler and each existing copper/iron nitrogen-beacon source assembler.
It runs after Nonstandard Beacons creates the sources and after fuel lighting.
Native working state gates visibility; playback speed stays constant at 0.15.
Supplied beacon sources may operate without modules or recipients, matching their
existing consumption behavior. No new runtime handlers, storage or helpers exist.

The unchanged 60-frame sheet ships in **Graphics 6** under `graphics/entities/`.
Its provenance and graphics license are recorded in that pack's attribution.txt
and the main pack's CREDITS.md.
The additive animation emits no light. The hypercooler's three broad lights are
removed at their declaration; its base and red/green indicator remain unchanged.
Beacon sources explicitly use zero flicker intensity because omitted fields
would restore native white lighting. All other graphics and gameplay are retained.

The native [presentation scenes](entity-presentation.md#scenes) explicitly provide
the existing source body because native previews do not run mod build handlers.

## Implementation sources

- [Cold mist finalizer](../../../exotic-space-industries-remembrance/scripts/data-final-updates/cryo-mist.lua)

## Verification

Use scripts/invoke-cryo-mist-qc.ps1 for final-prototype preservation, native
working/stopped transitions, real Nonstandard Beacons helper lifecycle, reload,
full-loop day/night captures and exact preview init/update execution. Source-only
and headless checks cannot establish rendered appearance. Native scene captures
do not prove the Factoriopedia window layout or multiplayer behavior.
