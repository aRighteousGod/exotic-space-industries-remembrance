# Source Map

Primary official sources:

- API docs home/version selector: `https://lua-api.factorio.com/`
- Default installed documentation root: `C:\Program Files (x86)\Steam\steamapps\common\Factorio\doc-html`
- Runtime API docs: `https://lua-api.factorio.com/2.0.77/index-runtime.html`
- Prototype API docs: `https://lua-api.factorio.com/2.0.77/index-prototype.html`
- Auxiliary docs: `https://lua-api.factorio.com/2.0.77/index-auxiliary.html`
- Runtime JSON docs: `https://lua-api.factorio.com/2.0.77/runtime-api.json`
- Prototype JSON docs: `https://lua-api.factorio.com/2.0.77/prototype-api.json`

Important auxiliary topics:

- Data Lifecycle
- Storage
- Mod Structure
- Libraries and functions
- Migrations
- Instrument Mode
- Defines
- Runtime JSON Format
- Prototype JSON Format

Official wiki topics covered by the cache:

- Tutorial:Scripting
- Tutorial:Script interfaces
- Tutorial:Localisation
- Scenario System
- Command line parameters
- Console
- data.raw
- Tutorial:Modding tutorial

Use the JSON docs for exact symbol lookup and the auxiliary/wiki pages for workflow guidance and examples. The wiki is unversioned and must be labeled as such; it is not evidence for version-sensitive API decisions.

The wrapper defaults to installed Factorio 2.0.77 and verifies both JSON stages and `application_version` before replacing `.factorio-lua-docs-cache/2.0.77`. Hosted documents require an explicit source and exact numeric version. Never infer a `/latest/` URL, and never use the legacy flat 2.1.15 cache for the default profile.
