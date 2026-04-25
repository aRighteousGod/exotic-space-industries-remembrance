# Query Flow

1. Classify the question:
   - runtime API
   - prototype/data-stage API
   - auxiliary topic
   - wiki scripting guidance
   - Factorio-vs-general-Lua assumption check
2. If the question is an assumption check, read `factorio-lua-assumptions` first.
3. Query the local cache first with `invoke-factorio-lua-docs.ps1`.
4. Prefer exact name lookup when the symbol is known.
5. For broader "how do I..." questions, search the wiki or auxiliary stages.
6. Include the official URL in the final answer.
7. Open the live page when:
   - the user asks for the latest nuance
   - the cache is missing a symbol
   - you need a long example or table that the cache only summarizes

Do not run a blank `query` task. Use either `-Query <text>` or `-ExactName <symbol>`.

Good query patterns:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\invoke-factorio-lua-docs.ps1 -Task query -ExactName LuaEntity -Stage runtime
powershell -ExecutionPolicy Bypass -File .\scripts\invoke-factorio-lua-docs.ps1 -Task query -Query on_player_created -Stage runtime -Kind event
powershell -ExecutionPolicy Bypass -File .\scripts\invoke-factorio-lua-docs.ps1 -Task query -ExactName RecipePrototype -Stage prototype
powershell -ExecutionPolicy Bypass -File .\scripts\invoke-factorio-lua-docs.ps1 -Task query -Query migrations -Stage auxiliary
powershell -ExecutionPolicy Bypass -File .\scripts\invoke-factorio-lua-docs.ps1 -Task query -Query libraries -Stage auxiliary
powershell -ExecutionPolicy Bypass -File .\scripts\invoke-factorio-lua-docs.ps1 -Task query -Query "data lifecycle" -Stage auxiliary
powershell -ExecutionPolicy Bypass -File .\scripts\invoke-factorio-lua-docs.ps1 -Task query -Query storage -Stage auxiliary
powershell -ExecutionPolicy Bypass -File .\scripts\invoke-factorio-lua-docs.ps1 -Task query -Query "script interfaces" -Stage wiki
powershell -ExecutionPolicy Bypass -File .\scripts\invoke-factorio-lua-docs.ps1 -Task query -Query data.raw -Stage wiki
```

Add `-RefreshIfMissing` only when a cache/network write is acceptable.

When the question is "can I use normal Lua behavior here?", read `factorio-lua-assumptions` before choosing a pattern.
