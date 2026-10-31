# Source Map

Primary official sources:

- API docs home/version selector: `https://lua-api.factorio.com/`
- Current installed documentation root (verify version before use): `C:\Program Files (x86)\Steam\steamapps\common\Factorio\doc-html`
- Runtime API docs: `https://lua-api.factorio.com/2.1.24/index-runtime.html`
- Prototype API docs: `https://lua-api.factorio.com/2.1.24/index-prototype.html`
- Auxiliary docs: `https://lua-api.factorio.com/2.1.24/index-auxiliary.html`
- Runtime JSON docs: `https://lua-api.factorio.com/2.1.24/runtime-api.json`
- Prototype JSON docs: `https://lua-api.factorio.com/2.1.24/prototype-api.json`

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

The wrapper defaults to exact hosted Factorio 2.1.24, verifies both JSON stages and `application_version`, and writes only on explicit refresh into `.factorio-lua-docs-cache/2.1.24`. Select historical versions explicitly; refresh them through hosted docs or an independently verified matching installation. Never infer a `/latest/` URL or use the legacy flat 2.1.15 cache as a fallback. Verify the executable and adjacent data version independently before engine tests.
