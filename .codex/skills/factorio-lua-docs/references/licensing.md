# Licensing And Cache Boundaries

- The pinned Factorio 2.0.77 API docs include a license page at `https://lua-api.factorio.com/2.0.77/license.html`.
- The official wiki copyright page is `https://wiki.factorio.com/Factorio:Copyrights`.

Practical rule for this skill:

- cache official docs locally for lookup and summary
- keep each profile ignored under `.factorio-lua-docs-cache/<version>`
- do not check in a full mirrored corpus
- prefer summaries plus links over large verbatim excerpts

This keeps the skill usable without turning the repo into a documentation mirror.

The official wiki links are intentionally unversioned and are guidance, not evidence for version-sensitive API decisions. The legacy flat 2.1.15 files remain untouched and outside the default installed 2.0.77 profile.
