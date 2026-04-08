-- Upstream Tesla's Legacy runtime is intentionally inactive here.
--
-- Keep this file inert:
-- - EI's top-level `control.lua` is the only event registrar.
-- - `scripts/control/teslas-legacy.lua` owns the live Tesla runtime.
-- - This vendored file exists only so future source updates have an obvious place to diff
--   against, not because the vendored module should register hooks on its own.
return {}
