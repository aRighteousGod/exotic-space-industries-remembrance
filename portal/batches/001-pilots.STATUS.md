# Pilot handoff - automatic capture stopped

Stopped at the user's request on 2026-10-19. The next workflow is user-recorded
footage followed by consistent edits and WebP conversions. Do not restart the
automatic capture effort unless requested.

## Retained work

- Reusable portal skill, plain-language copy, shared visual settings, feature queue,
  source coverage map, batch definitions and local rendering/review tools.
- Pilot subjects: Phased-array radar, A. S. H. Sentry, Auric inoculation vat,
  gates, and Spidertron upgrades, weapon cycling and overkill mode.
- Partial automatic renders and source frames are retained as unapproved evidence.
  The active batch state and candidate folder were renamed to `aborted-state.json`
  and `aborted-candidate/` under `output/portal-media/001-pilots/`, so normal render
  and review commands cannot mistake them for a ready batch.
- Last capture: `.factorio-qc/pm/6c7e7709`, housekeeping run
  `8e8716eddc184fec8c1b3f3351833a62`. Its run ownership was closed; source evidence
  was retained. No pilot media was promoted or published.

## Known limitations of the abandoned fixture

- A staging inserter overlapped the gate and removed one plate: 100 loaded,
  99 received, zero left. Gate conservation evidence failed. This was a fixture
  issue awaiting correction, not an accepted gameplay demonstration.
- Automatic dismissal of the ESIR rebuild activity window was still pending.
  Always close it before each take and GUI capture, and again if it reappears.
- Three partial WebP candidates exist (radar, sentry, vat); the five-feature batch
  did not finish rendering or receive final visual review.
- The renderer currently consumes native screenshot manifests. Manual video import
  must be adapted when footage is available; it is not supported by the existing
  capture command. Actual Mod Portal animated-WebP playback remains unverified.

## Manual footage handoff

Keep original videos unchanged. Prefer a steady camera, native resolution, a dark
editor background and only necessary terrain. Show the setup, action and visible
result; hold relevant GUI panels long enough to read. Preserve normal-speed combat
and identify any time-lapse. Rough feature names or useful timestamps are enough
to associate recordings with the queue. Apply the shared title, caption, crop and
export style during conversion, then review before promoting media.
