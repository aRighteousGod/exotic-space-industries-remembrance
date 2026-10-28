# Source Map

Primary official sources:

- API docs home/version selector: `https://lua-api.factorio.com/`
- Historical installed documentation root (2.0.77): `C:\Program Files (x86)\Steam\steamapps\common\Factorio\doc-html`
- Runtime API docs: `https://lua-api.factorio.com/2.1.23/index-runtime.html`
- Prototype API docs: `https://lua-api.factorio.com/2.1.23/index-prototype.html`
- Auxiliary docs: `https://lua-api.factorio.com/2.1.23/index-auxiliary.html`
- Runtime JSON docs: `https://lua-api.factorio.com/2.1.23/runtime-api.json`
- Prototype JSON docs: `https://lua-api.factorio.com/2.1.23/prototype-api.json`

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

The wrapper defaults to exact hosted Factorio 2.1.23, verifies both JSON stages and `application_version`, and writes only on explicit refresh into `.factorio-lua-docs-cache/2.1.23`. Select `-Source installed -Version 2.0.77` for migration work; its versioned cache remains separate. Never infer a `/latest/` URL or use the legacy flat 2.1.15 cache as a fallback. Verify the executable and adjacent data version independently before engine tests.
