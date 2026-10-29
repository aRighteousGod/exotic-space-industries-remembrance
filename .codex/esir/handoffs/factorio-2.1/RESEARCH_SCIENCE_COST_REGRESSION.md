# Computer Age science-cost regression repair

Accepted in local source for ESIR **1.4.1**, Factorio **2.1.23**, 2026-10-29.
No version bump, package rebuild, deployment or publication belongs to this fix.
The user owns rebuilding. The reporting player's save/mod list was unavailable.

## Reproduction and cause

The required core dependency set reproduces the reported Metallurgic science
cost, including ten research units requiring one of each of the four ESIR age
packs **plus the Metallurgic pack being unlocked**. Its Vulcanus prerequisite
chain has the same accidental requirement. No optional mod is needed.

`scripts/data-updates/vanilla-updates/planets/vulcanus.lua` assigned the shared
`ei_data.science["computer-age"]` table directly to `ei-acid-neutralisation-t2`.
Appending Metallurgic science to that technology also modified the age template.
Final research passes then copied or inherited the polluted ingredient list.
Stage snapshots prove the four-pack template is intact in initial data and
corrupted during data-updates, before the final research passes.

The production fix deep-copies the template when creating the acid technology.
It is the only executable behavior change. The source ownership comment,
research blueprint/index, 1.4.1 changelog and private regression fixture accompany
it. Existing shared science mutation helpers already copy their input; no new
helper or final-stage blanket removal is introduced.

## Exact effect

- **206 of 804 technologies** lose one unintended `metallurgic-science-pack`
  ingredient per research unit in the tested default core configuration.
- **29 technologies retain** their intended Metallurgic requirement, including
  tier-2 acid neutralisation, coal liquefaction, cliff explosives and late-game
  planetary technologies. The acid technology still requires the four ESIR age
  packs plus Metallurgic science. Its normal prerequisite list is unchanged.
- All other captured technology fields are equal to the reproduced baseline:
  count/formula, time, other ingredient amounts/order, prerequisites, unlocks,
  effects, trigger, age, enabled and hidden flags. Captured ingredient/result and
  visibility fields for all **2,840 recipes** are also equal.
- In science-cost mode, Metallurgic science requires **10 units**, **10 seconds
  per unit**, and one each of Dark Age, Steam Age, Electricity Age and Computer
  Age science. In native-trigger mode it retains crafting `tungsten-plate` as its
  trigger. This repair does not change the chosen mode.
- No item/recipe/technology identities, settings, locale keys, remote interfaces,
  runtime storage owners or recurring work change. No new migration script is
  needed to change these data-stage technology costs.

The exhaustive changed/retained technology lists, exact mod versions, source
hashes and evidence hashes are in
[RESEARCH_SCIENCE_COST_REGRESSION.json](RESEARCH_SCIENCE_COST_REGRESSION.json).

## Verification

Protected run: `.factorio-qc/research-bootstrap-20261029`, artifact ID
`a6ea7b639fe04bbe9a682884f98adb40`.

| Check | Result / evidence |
| --- | --- |
| Unfixed negative control | `before.json`: checker rejects the mutated shared template; original owner saved as `vulcanus.before.lua`. |
| Science costs, normal tree | `verified-default.json`: actual settings asserted, engine create succeeds, template/ancestry/cost checks pass. |
| Native triggers, normal tree | `verified-triggers.json`: actual settings asserted, native trigger retained, engine create/checks pass. |
| Science costs, flattened tree | `verified-flat.json`: actual settings asserted, engine create/checks pass. |
| Native triggers, flattened tree | `verified-flat-triggers.json`: actual settings asserted, engine create/checks pass. |
| All shared age templates | Equal across initial data, data-updates and final data in all four cases. |
| Science-unlock ancestry | Eight same-identity unlocks checked, including all four planetary packs, space/promethium and both ESIR Computer Age variants; no technology in their prerequisite ancestry requires the pack being unlocked. |
| Full captured default delta | `verified-checks.json`: exactly 206 removals, 29 legitimate requirements retained; no other captured technology/recipe changes. |
| Native laboratory research | `engine/script-output/research-bootstrap-native.json`: real Big Lab consumes exactly ten of each ESIR age pack, receives zero Metallurgic packs, completes the real technology through `by_script=false`, and enables the recipe. |
| Existing test save / checkpoint | Native test starts from `engine/before.zip`, created before the fix. `engine/native-save.checkpoint.json` verifies the real server checkpoint ZIP, timestamp, hash and completed save. |
| Save/reload preservation | `engine/script-output/research-bootstrap-reload.json`: exact equality for all 105 researched technology levels, one queued research at 0.375 progress, four remaining inventory counts of 30, and the enabled science recipe. |
| Static checks | Touched production and fixture Lua parse, Python compilation, focused diff whitespace and conceptual blueprint audit pass (65 models, 209 source owners, zero findings). |

The private lab force completes prerequisites by script and uses a laboratory
speed modifier to shorten the test. Its actual target research, costs, lab and
ordinary completion event are unchanged. This is not a full factory playthrough.

Initial alternate-setting attempts were superseded: their visible boolean
settings did not honor `forced_value`, leaving saved settings in effect. The
fixture now hides the two private test settings, asserts actual values, and
checks the expected final trigger/unit representation. Only the `verified-*`
snapshots support the setting matrix. One initial native fixture attempt used
the removed `research_queue_enabled` property; that test-only line was removed
before the passing native run. Diagnostic logs remain preserved.

## Migration and limits

Rebuild and install the corrected ESIR package, restart Factorio and load the
save. Technology prototypes acquire the corrected costs without resetting
research, recipes or surfaces. The native test confirms loading a pre-fix core
test save and a subsequent populated checkpoint reload. It does not certify the
reporting player's unavailable save, full optional-mod selection or every
possible partially active research queue during a package-version upgrade.

Existing flattening behavior remains: with native triggers enabled, its
unit-based science-unlock lookup omits the acid technology's direct Metallurgic
prerequisite edge; the required science ingredient still gates that technology.
This patch leaves that separate flattening policy unchanged. The ancestry
checker is not an exhaustive production solver and does not cover different-name
science unlocks automatically.

No rendered technology-screen, multiplayer-client, audio or performance claim
is made. The private loopback server is used only to create a real saved
checkpoint. Rebuilding and publication remain with the user. The sprite audit
report was canceled at the user's request; its partial evidence was preserved
and its task registry released.
