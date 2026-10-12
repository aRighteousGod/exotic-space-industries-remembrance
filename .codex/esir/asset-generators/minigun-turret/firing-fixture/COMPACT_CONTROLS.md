# Compact native flash controls

Staged implementation only. The active production render and accepted pilot are unchanged.

`-CompactHeadingTemplates` enables nine cells per native/flash control group and captures only offsets -1, 0 and 1. Actual firing captures retain the complete original appearance/decay sequence. The diagnostic `-HeadingTemplates` option remains available and cannot be combined with the compact option.

The nine cells are three independently constructed native rays (center/source/visual, each with the measured twice-projected Y convention). Each ray receives two zero-height cells on different fixed backgrounds and a third cell at the source explosion's authored height on another background. At the actual shot, all nine choose the observed native source variation. The pre-shot image has the same fixed cell layout.

The fitter recovers the flash foreground/opacity from the first two backgrounds, then searches the entire third cell for the native-height image. Its measured displacement must agree with the authored height and its independent compositing residual must remain below 0.001. The actual firing image also receives a full translation search, with the predicted muzzle position excluded from that search. Close ray alternatives and their attachment spread are retained. This is diagnostic metrology; it does not approve visual alignment, physical barrel attachment, moving shots or decay.

The compact template pixel area is approximately `9/50 * 3/14 = 3.86%` of the earlier fifty-cell diagnostic. Exact output bytes still require measurement. The controls are fixture-only and never enter either shipping archive.

Six offline tests exercise recovery on independent backgrounds, deliberate heldout misregistration, source-variation/registration rejection, unrestricted fitting at a point far from the proposed muzzle, and evidence rejection for missing/duplicate controls, wrong heights, nonfinite residuals and changed image identities. Both changed Lua files parse with the local Lua 5.4 compiler; native Factorio 2.0.77 validation remains required before using the compact measurement as evidence.

The initial native smoke should be the eight-direction SD/BD-on calibration subset with these compact controls. Keep existing accepted pilot evidence intact. If any control fails, diagnose its actual images; do not relax the source or registration checks.

The builder records a SHA256-bound inventory of the complete referenced SD/HD PNG union. The analyzer checks that inventory and retains the actual atlas bytes. `-CaptureStorage hardlink` is the wrapper default for new same-volume runs; it preserves both source and retained paths, verifies identical bytes, and refuses replacement of different existing evidence. Do not modify either hardlink alias in place. Historical stages without this option retain their original behavior.

Moving captures are shared only between shot events on the same native tick and the same turret variant. All shot/source/projectile events and ammunition measurements remain separate. This removes duplicate frame requests that the engine cannot render at distinct sub-tick times, without reducing temporal coverage.
