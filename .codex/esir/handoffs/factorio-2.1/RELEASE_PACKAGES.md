# ESIR 1.4.0 release candidates

Status: all 12 candidate ZIPs passed the combined exact Factorio 2.1.23 load,
fresh-save and 600-tick smoke test. All 35 selected files were actual ZIPs.
The archive-only final-data dump also passes all 24 crystal contracts and
matches the accepted core26 compact gameplay inventory except for the
explicitly approved native Quality recipe-buffer changes and removal of
the Rocket silo personal-travel grant. Native planet discoveries grant
personal travel instead. The complete buffer
field inventory is retained beside the final-data receipt.
The rebuilt main ZIP also verifies native quality inheritance on all
five ESIR locomotive bodies, four cargo wagons and three fluid wagons.
Native silo quality modifiers are 0.2/0.45/0.15, with phase-aligned
pollution and plumes verified separately across all five qualities.
**Nothing in this candidate set has been published.** The user owns
uploads. Acceptance and limits are in [the upgrade synopsis](UPGRADE_SYNOPSIS.md).

Publication order: the two new dependency continuations and NSBC; six
graphics packs and two soundtracks; then the main mod. Preserve the old
2.0 releases. Versions were checked against public Portal metadata on
2026-10-27 and exceed both published and previously staged versions.

| Package | Version | Bytes | SHA-256 |
|---|---|---:|---|
| `doeworks-deer-continued` | 1.0.0 | 4,338,587 | `599aa5a472abec7dc916cab40795c29157780f625fb1cf9aab9d420044b9c2b5` |
| `enhanced-walls-continued` | 1.0.0 | 1,202,318 | `55448519cd79ab45c0eee181f30108bf28c0a6cfef54bad40babf0e669291048` |
| `exotic-space-industries-remembrance-graphics-1` | 1.1.0 | 218,709,076 | `a21884a1d72da8b480f984472ebb887ecd15f6255d6f805d42271d5c8fa69a92` |
| `exotic-space-industries-remembrance-graphics-2` | 1.1.0 | 256,656,498 | `e5e683918cf1f7fb664ff0e6074b520b6860b1b22ab14c69459f1eedc8f8fe86` |
| `exotic-space-industries-remembrance-graphics-3` | 1.1.0 | 209,771,849 | `5711eed5c4eff1dcb30bbf9044b8bc0d719b68918c7a766f2708ccc9b09c1315` |
| `exotic-space-industries-remembrance-graphics-4` | 1.1.0 | 164,243,007 | `216a57fd979312268050230dd7ab2a8fc102fc4f5525f742f3e4d807e2bd14bc` |
| `exotic-space-industries-remembrance-graphics-5` | 1.1.0 | 186,401,513 | `9476dce4a0053c19a9a6e9202c912872c0206d7a7941d5dcd9db9e43a3d5cda0` |
| `exotic-space-industries-remembrance-graphics-6` | 1.1.0 | 173,118,095 | `7e3fd27cc4bfb2f23d081a222896ab0e3f9c9975044e3df7b85ad1798bd80240` |
| `exotic-space-industries-remembrance-soundtrack-1` | 1.1.0 | 246,688,685 | `05cca6d8fc43157377618242126fdbc4b7fa23d9f6820b4c1ca191fc7a9c3b6f` |
| `exotic-space-industries-remembrance-soundtrack-2` | 1.1.0 | 168,789,999 | `1f8950be6f184b75acea4b363658ecfa4bf9b62e4896420dba1c3ca259b705cb` |
| `exotic-space-industries-remembrance` | 1.4.0 | 7,846,171 | `a8fb077a851004e409a74c0450872bddfdee16a4b121dd2f3f2be90509f94822` |
| `zzz-nonstandard-beacons-continued` | 1.0.0 | 82,419 | `c088e7dfe475473c81b9d64053ffd608745f4330e8d557b7a7a2fefbd5d19cd3` |

The full 35-package selection, archive paths and hashes are retained in
[RELEASE_PACKAGES.json](RELEASE_PACKAGES.json). License/source provenance,
required replacements, conflicts and optional dispositions are recorded in
[the dependency matrix](DEPENDENCY_MATRIX.md) and its JSON companion.
The deer continuation retains its mixed upstream licensing; it is not
represented as an entirely GPLv3 asset package. NSBC retains its captured
MIT provenance separately from PEREL and newer upstream code.

Evidence under the protected run:
- `package-core-26/packages-01.receipt.json` — native ZIP-only smoke.
- `package-core-26/packages-final-data.receipt.json` — native final data.
- `package-core-26/compact/` — gameplay, crystal and rolling-stock quality audit.
- Archive selection SHA-256: `b23d6ab200b861983df82698f93a456d22e84e55fc13004e6ee580c262a24586`.
- Compact gameplay inventory SHA-256:
  `d7290f480a3f4ef44e5bad1a24c6fb15c8b70d5d4cbd442146b327e188ff99ed`.
- Approved native buffer field changes: 1581.
