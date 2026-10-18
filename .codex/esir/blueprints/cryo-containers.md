<a id="contract"></a>
# Cryo container families

## Implementation sources

- [cryo-containers.lua](../../../exotic-space-industries-remembrance/prototypes/cryo-containers.lua)

The data-stage module declares nine filled items, eighteen transfer recipes and
four technologies after the ESIR planet fluids exist. `data.lua` calls `declare`;
`data-final-fixes.lua` calls `finalize` immediately before technology icon badges.
There is no control-stage state, scheduling, migration or research callback.

<a id="registry"></a>
## Registry and conservation

| Family | Fluids | Milestone in addition to `ei-cryo-container` |
| --- | --- | --- |
| Propellant | Thruster fuel, thruster oxidizer | `space-platform-thruster` |
| Electrochemical | Holmium solution, electrolyte | `electromagnetic-plant` |
| Aquilan | Ammoniacal solution, ammonia, fluorine, lithium brine | `planet-discovery-aquilo` |
| Auric vapor | `ei-auric-vapor` | `ei-auric-precipitation` |

The registry is closed. Nitrogen and oxygen keep their original prototypes and
research. No molten materials, computation, steam, heated fusion fluids, plasma,
hidden helper fluids, parameter fluids or optional-mod additions are admitted.
Acidic water and both fluoroketones retain ordinary barreling.

Each operation takes one second in `crafting-with-fluid`, uses one container,
and transfers `ei-barrel-capacity` units (50–2,000; default 1,000). Filled items
stack to 50. Transfer recipes forbid productivity, quality generation and automatic
reverse recycling. No extra consumable, surface restriction or spoilage applies.

Filling requires exactly the declared temperature; emptying restores it. Propellants
and fluorine use 25°C, holmium/electrolyte/brine 15°C, ammoniacal solution −50°C,
ammonia −35°C and auric vapor 500°C. A single item cannot encode arbitrary heat;
rejecting other temperatures prevents free heating or cooling through packaging.

<a id="finalization"></a>
## Research and presentation

New researches start at count 100, time 20 and then participate in normal ESIR
cost scaling. Finalization retains scaled counts while resolving science ingredients
and the two explicit prerequisites after compatibility passes. Propellants use
Computer Age; electrochemical uses Computer Age plus space science; Aquilan and
auric inherit final ingredients from their respective milestone technologies.
New research remains unresearched in existing saves. Existing cryo research is
never reset or granted by this module.

Icons reuse the cryo casing and existing fill/empty cues with layered fluid symbols.
Names use reusable locale templates and existing fluid localisation. Recipes sort
by family after the existing cryo transfers in the existing barrel subgroups.

## Verification

`scripts/invoke-cryo-container-qc.ps1` creates a prior-version fixture and tests
fresh/upgrade unlocks, native machine cycles, wrong-temperature rejection and
capacity extremes. Its helper checks final prototypes and exact registry scope.
Run ESIR preflight and qc-fast; inspect crafting/Factoriopedia presentation separately.
Focused engine results do not imply a full playthrough or non-English native review.
