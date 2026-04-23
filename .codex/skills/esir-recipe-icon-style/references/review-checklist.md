# Review Checklist

Use this checklist when reviewing a generated batch or deciding whether a prototype is ready to move from planning into an actual Lua patch.

## Baseline Checks

- Was the companion baseline generated from the local zip, not guessed from screenshots?
- Was the latest baseline diff checked for unmapped features or new ESIR support notes?
- Does the manifest entry carry honest preset tags instead of vague "styled" wording?

## Icon Checks

- Does the icon still read at Factorio scale?
- Is the overlay family consistent with similar recipes?
- Is the composition simple enough to survive a small preview slot?
- If the preview uses a placeholder, is that called out clearly?
- If the preview depends on non-repo art, does `preview.resolved_sources` explain where the slot was sourced from?

## Sorting Checks

- Are subgroup and order shown as separate before and after values?
- Is the proposed sort family grounded in the companion rule files instead of intuition?
- If combat or facility centralization is involved, is the chosen preset explicit?

## Visibility Checks

- Are Factoriopedia visibility and player-crafting visibility shown separately?
- If a recipe is redirected instead of hidden, is the alternative prototype named?
- If a signal is hidden, is it because of an explicit helper call or the same-name heuristic?

## Risk Checks

- Is the entry marked `manual-review-needed` when the parser could not prove the result?
- Does the notes field explain aggressive behaviors such as purge or extra hiding?
- Are newly discovered companion features tagged as `ready-to-map`, `needs-rule-design`, or `out-of-scope-v1` instead of being ignored?
