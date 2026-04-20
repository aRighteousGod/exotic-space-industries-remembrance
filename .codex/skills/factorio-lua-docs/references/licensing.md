# Licensing And Cache Boundaries

- The Factorio API docs include a license page at `https://lua-api.factorio.com/latest/license.html`.
- The official wiki copyright page is `https://wiki.factorio.com/Factorio:Copyrights`.

Practical rule for this skill:

- cache official docs locally for lookup and summary
- keep that cache ignored under `.factorio-lua-docs-cache`
- do not check in a full mirrored corpus
- prefer summaries plus links over large verbatim excerpts

This keeps the skill usable without turning the repo into a documentation mirror.
