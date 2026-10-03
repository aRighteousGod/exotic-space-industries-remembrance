# Native coordinator shutdown acceptance

On 2026-09-29, installed Factorio **2.0.77** passed **39/39 cumulative checks**
through real hidden graphical clients and a native autosave. The enabled capture
contributed 18 preparation checks; the disabled reload added 21 cleanup and
preservation checks. This is one connected-player lifecycle result. It is not a
multiplayer, visual interaction, or whole-factory performance measurement.

The exact enabled archive was saved at tick 1631 with an owned god controller,
cheat mode, character invulnerability, speed 2, instant research, an admin window,
camera, active remote selector and two pending world jobs. A completed chest and
peaceful-mode edit were already present. Before the normal disabled coordinator
ran, the fixture confirmed those saved jobs and owned states still existed.

The final disabled reload restored the same character **unit 58 on surface 3** by
its first observed tick 1632. At tick 1662 it confirmed original destructibility
and cheat mode, character control, normal speed, removed mode ownership, destroyed
admin/camera windows, cleared selector/automation/job state, and preserved the
completed chest and peaceful-mode edit. Exactly one copy of each tagged normal,
rare and legendary test item remained, with original nested tag values; the
returned item-with-inventory still contained 13 rare steel plates.

This fixture exposed a real native precondition: after loading a saved remote
view, the god controller was on Nauvis while its parked body was on surface 3.
Character attachment failed with:

```text
LuaEntity belongs to surface admin-shutdown-probe (index 3) but a LuaEntity belonging to surface nauvis (index 1) was expected.
```

The failed run retained the valid protected body and three escrow slots while
retries reached their existing limit. The integrated correction moves the owned
god controller to the original body's current surface before attaching and
revalidates that body after teleport callbacks. The passing run loaded the exact
same enabled archive; the temporary diagnostic logger was removed. No fixture
callback forced restoration or modified pending recovery state.

Local evidence retained in ignored staging:

- `.factorio-qc/asd/sf3/enabled/saves/_autosave-admin-shutdown-enabled.zip`
- `.factorio-qc/asd/sf3/enabled/script-output/shutdown-qc.json`
- `.factorio-qc/asd/sf3/disabled/script-output/shutdown-qc.json`
- Per-profile native logs, process records and `source-hashes.json` files.
- `output/admin-implementation/shutdown-pending-before-diagnostic.json` and `.log`.
- `output/admin-implementation/shutdown-cross-surface-failure.json` and `.log`.

SHA-256 evidence:

| Artifact | SHA-256 |
| --- | --- |
| Exact enabled autosave | `69E5DC0558D0589C558E6630EE29B89C62D3EA7557E2EB076052748EF2C008D6` |
| Passing disabled report | `411E38954470EA49D243492F24C762F7B288F9452F37C6DCC84F0A4D414BC985` |
| Tested players owner | `E19AA268289B00E17254D6BEB56243AE4051704145A13C62F0B6EC3A9207C5C5` |
| Final fixture probe | `4672F446D053D5A9A833FC3906B7B0637D13F1352777111DC6D5EA18F6F18FE5` |

The enabled archive predates the correction; the final disabled profile used the
corrected player owner and current restriction owner. Its relevant coordinator,
world, targeting and camera sources otherwise matched the staged capture. The
driver copies neither account credentials nor player-data files, preserves its
input save and live profiles, and stops only the clients it launches.

A further replay on **2026-10-02** staged the current shipping sources into a
fresh `.factorio-qc/asd/sf4` profile and loaded the exact same retained enabled
autosave. This includes the subsequent targeting cancellation correction that
restores a prior god controller's physical location after native remote view.
It again passed **39/39 cumulative checks**. The original body was already
restored at tick 1632, with final checks at tick 1662. Its JSON result is byte
identical to the sf3 passing result; this replay is additional lifecycle evidence,
not 39 new independent scenarios. No new enabled save was made.

Before this replay, the sf3 report, log and source manifest were retained under
`output/admin-implementation/shutdown-sf3-retained`. The original archive, the
sf4 retained copy and the actual disabled input all still have SHA-256
`69E5DC0558D0589C558E6630EE29B89C62D3EA7557E2EB076052748EF2C008D6`.
The sf4 disabled result, logs, source manifest and process record remain under
`.factorio-qc/asd/sf4/disabled`.

| Current sf4 source | SHA-256 |
| --- | --- |
| Player owner | `E19AA268289B00E17254D6BEB56243AE4051704145A13C62F0B6EC3A9207C5C5` |
| Targeting owner | `452FFEB6C8F27FB3FE04FD3DCC90E22FDC030C96B016A12759B7DBE0334C504B` |
| Admin coordinator | `AF32F14A075A352CE9B0197E5FFB82EAC11DD0C248F16DDB8B0A1F9E65864CE0` |

This final replay reused the unchanged fixture probe. It confirms safe shutdown
with the current targeting and restoration sources. Ordinary targeting return
without shutting down is covered by the separate functional fixture.
