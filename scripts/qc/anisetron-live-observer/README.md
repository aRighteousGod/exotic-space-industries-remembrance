# ANISETRON real-input observer

This optional helper records the actual keyboard-input case that an automated
`walking_state` fixture cannot reproduce faithfully. It changes no vehicle,
input, health, equipment, ammunition, targeting, or movement state. The command
is administrator-only, idle recording has no tick subscription, and each trace
is bounded to 12,000 ticks. It is not loaded by ESIR and is not shipped in its pack.

Install the helper folder as `zzz-esir-anisetron-observer_0.0.1` alongside ESIR
only when diagnosing a problem. On a copy of the affected save, enter ANISETRON
or stand within 20 tiles and run:

```text
/anisetron-motion-trace
```

Drive normally, including the release/repress action that clears the reported
pause. The default capture lasts two minutes. `/anisetron-motion-trace stop`
finishes early. The report is written locally to Factorio's
`script-output/anisetron-motion-trace.json`; a later capture replaces that file.
The report contains per-tick position, speed, player input, autopilot destination,
leg positions, health, and sticker aggregates and names. It contains no account
credentials or chat text. Remove the helper when finished.

This recorder supplies evidence; its presence does not establish that the
intermittent no-sticker movement report has been fixed.
