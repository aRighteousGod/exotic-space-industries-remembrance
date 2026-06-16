# Query Flow

1. Classify the question:
   - runtime API
   - prototype/data-stage API
   - auxiliary topic
   - wiki scripting guidance
   - command-line or executable option guidance
   - Factorio-vs-general-Lua assumption check
2. If the question is an assumption check, read `factorio-lua-assumptions` first.
3. Run `-Task status` when version freshness matters, and `-Task refresh` when the cache is stale or missing.
4. Query the local cache first with `invoke-factorio-lua-docs.ps1`.
5. Prefer exact name lookup when the symbol is known.
6. For broader "how do I..." questions, search the wiki or auxiliary stages.
7. Include the official URL in the final answer.
8. Open the live page when:
   - the user asks for the latest nuance
   - the cache is missing a symbol
   - you need a long example or table that the cache only summarizes
9. For installed Factorio file surveys or local CLI availability, compare the docs cache version with `factorio.exe --version` or `factorio.exe --help`; do not infer local executable behavior from the hosted `latest` docs alone.

Do not run a blank `query` task. Use either `-Query <text>` or `-ExactName <symbol>`.

Good query patterns:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\invoke-factorio-lua-docs.ps1 -Task status
powershell -ExecutionPolicy Bypass -File .\scripts\invoke-factorio-lua-docs.ps1 -Task query -ExactName LuaEntity -Stage runtime
powershell -ExecutionPolicy Bypass -File .\scripts\invoke-factorio-lua-docs.ps1 -Task query -Query on_player_created -Stage runtime -Kind event
powershell -ExecutionPolicy Bypass -File .\scripts\invoke-factorio-lua-docs.ps1 -Task query -ExactName RecipePrototype -Stage prototype
powershell -ExecutionPolicy Bypass -File .\scripts\invoke-factorio-lua-docs.ps1 -Task query -Query migrations -Stage auxiliary
powershell -ExecutionPolicy Bypass -File .\scripts\invoke-factorio-lua-docs.ps1 -Task query -Query libraries -Stage auxiliary
powershell -ExecutionPolicy Bypass -File .\scripts\invoke-factorio-lua-docs.ps1 -Task query -Query "data lifecycle" -Stage auxiliary
powershell -ExecutionPolicy Bypass -File .\scripts\invoke-factorio-lua-docs.ps1 -Task query -Query storage -Stage auxiliary
powershell -ExecutionPolicy Bypass -File .\scripts\invoke-factorio-lua-docs.ps1 -Task query -Query "script interfaces" -Stage wiki
powershell -ExecutionPolicy Bypass -File .\scripts\invoke-factorio-lua-docs.ps1 -Task query -Query "Command line parameters" -Stage wiki
powershell -ExecutionPolicy Bypass -File .\scripts\invoke-factorio-lua-docs.ps1 -Task query -Query data.raw -Stage wiki
```

Add `-RefreshIfMissing` only when a cache/network write is acceptable.

When the question is "can I use normal Lua behavior here?", read `factorio-lua-assumptions` before choosing a pattern.
