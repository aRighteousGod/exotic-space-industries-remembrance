# Auric Fumarole QC Helper

Use this helper when ESIR work needs hard evidence about Vulcanus auric fumarole spawning rather than just log-triaging the normal runtime harness.

## Canonical Asset

- Helper mod folder: [`../assets/zzz-auric-fumarole-qc_0.0.1`](../assets/zzz-auric-fumarole-qc_0.0.1)
- Main probe file: [`../assets/zzz-auric-fumarole-qc_0.0.1/control.lua`](../assets/zzz-auric-fumarole-qc_0.0.1/control.lua)

## What It Measures

- Vulcanus chunk bands for `0-3`, `3-6`, `6-16`, `16-24`, `24-32`, and `32+`
- Eligible chunk counts using the same `0 at <= 3 / full by 32` distance ramp shape as the runtime module
- Auric fumarole counts by band
- Eligible-chunk and auric axis/quadrant counts so origin-offset asymmetry and rebuild order are visible in the report
- Sulfuric geyser axis/quadrant counts so geology-side rejection patterns are easier to spot
- Off-center placement count and sample positions
- Inner dead-zone violations
- Non-Vulcanus auric count
- Surface list present during the run
- Sulfuric geyser count on Vulcanus
- Iterator-prefix quadrant samples plus delta-from-start / delta-from-previous summaries for rebuild-style progression reads
- Sampled active-population stability metrics: minimum active count, zero-active sample count, below-floor sample count, and longest sampled streaks
- Generated-area quota-band diagnostics aligned to the live runtime densities:
  - generated chunk and generated eligible chunk counts
  - per-band target counts for `3-6`, `6-16`, `16-24`, `24-32`, and `32+`
  - per-band fill ratios, deficits, surpluses, and weakest-band tracking
  - sampled below-band streak counts and recovery-attempt budget windows using the `4` / `6` attempt budget logic

## Quota-Band Report Fields

- `vulcanus_generated_chunks`
- `vulcanus_generated_chunks_all`
- `vulcanus_generated_eligible_chunks`
- `vulcanus_generated_chunks_eligible`
- `auric_quota_band_densities`
- `auric_quota_band_targets`
- `auric_quota_band_fill_ratios`
- `auric_quota_band_deficit`
- `auric_quota_band_surplus`
- `auric_quota_total_target`
- `auric_quota_total_fill_ratio`
- `auric_quota_weakest_band`
- `auric_quota_weakest_fill_ratio`
- `auric_below_quota_band_sample_count`
- `auric_longest_below_quota_band_sample_streak`
- `auric_recovery_attempt_pulse_ticks`
- `auric_recovery_attempts_per_pulse`
- `auric_recovery_attempts_per_pulse_low_total`
- `auric_recovery_low_total_ratio`
- `auric_recovery_pulses_previous`
- `auric_recovery_attempt_budget_previous`
- `auric_recovery_attempt_budget_per_pulse`
- `auric_recovery_attempt_budget_total`
- `auric_recovery_attempt_window_count`
- `auric_recovery_success_window_count`
- `auric_recovery_failed_window_count`
- `auric_recovery_delta_previous`
- `auric_recovery_observed_spawn_delta_total`

## Important Behavior

- If the benchmark save does not already have a `vulcanus` surface, the helper creates or attaches to one through `game.planets["vulcanus"]`.
- It force-generates a `64` chunk radius around `{0, 0}` so the runtime module has real outer chunks to evaluate.
- It writes `auric-fumarole-qc.txt` at `2`, `60`, `600`, `1800`, `36000`, `40000`, `126000`, `162000`, `198000`, `234000`, and `414000` ticks after helper activation or configuration change, so it covers early generation, untouched self-seal timing, early post-seal recovery pressure, and a later cooldown/recovery checkpoint.
- It updates population stability counters only when a scheduled report is written; this keeps the helper QC-only and avoids per-tick entity scans.
- The helper-local active floor is `2` active fumaroles. This is a diagnostic threshold for `auric_below_floor_sample_count`, not a runtime setting.
- The quota-band target uses the same generated-area densities as the runtime plan: `3-6=0.25%`, `6-16=0.80%`, `16-24=1.30%`, `24-32=1.80%`, `32+=1.00%` of generated eligible chunks in each band.
- Recovery-attempt fields are validation-budget telemetry inferred from sampled windows where at least one band is below `70%` fill. They do not claim direct access to runtime internal attempts.

## Staging Steps

1. Copy `assets/zzz-auric-fumarole-qc_0.0.1` into `.factorio-qc/fmqc/mods-live/`.
2. Add or enable the `zzz-auric-fumarole-qc` entry in `.factorio-qc/fmqc/mods-live/mod-list.json`.
3. Run the usual ESIR runtime benchmark or a direct Factorio benchmark against the target save.
4. Inspect `.factorio-qc/fmqc/<run-data>/script-output/auric-fumarole-qc.txt`.

## Interpretation Notes

- `0-3=0` in `auric_bands` and `auric_inner_dead_zone=0` means the hard inner exclusion held.
- `non_vulcanus_auric_entities=0` means the Vulcanus-only runtime gate held.
- Very high `auric_off_center_total` is expected now; the helper is supposed to prove multi-probe placement is live.
- If `surface_iterator_prefix_*` looks one-sided but `auric_quadrant_delta_*` stays mixed, the rebuilt queue is no longer just replaying raw iterator order.
- `auric_min_active_since_reset`, `auric_zero_sample_count`, `auric_below_floor_sample_count`, `auric_longest_zero_sample_streak`, and `auric_longest_below_floor_sample_streak` are sampled report-window metrics; use them to compare stability between runtime tuning branches, not as exact per-tick uptime measurements.
- `auric_quota_band_fill_ratios` reports active/target by distance band, and `auric_quota_weakest_band` plus `auric_quota_weakest_fill_ratio` point at the current recovery priority.
- `auric_quota_band_deficit` and `auric_quota_band_surplus` show which bands are under or over target, using the same generated-area targets as the runtime pass.
- `auric_recovery_attempt_budget_previous` is the number of hypothetical recovery attempts available between the previous report and this report if the previous sample had any band below `70%` fill. Use it with `auric_recovery_delta_previous` and success/failure window counts to validate whether the quota controller is strong enough.
- If the helper reveals far more fumaroles than intended, tune runtime spawn weights or chance constants, not the helper.

## Scope

This helper is QC-only. Do not ship it inside the released mod packs.
