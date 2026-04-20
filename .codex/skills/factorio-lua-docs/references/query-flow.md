# Query Flow

1. Classify the question:
   - runtime API
   - prototype/data-stage API
   - auxiliary topic
   - wiki scripting guidance
2. Query the local cache first with `invoke-factorio-lua-docs.ps1`.
3. Prefer exact name lookup when the symbol is known.
4. For broader “how do I…” questions, search the wiki or auxiliary stages.
5. Include the official URL in the final answer.
6. Open the live page when:
   - the user asks for the latest nuance
   - the cache is missing a symbol
   - you need a long example or table that the cache only summarizes

Good query patterns:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\invoke-factorio-lua-docs.ps1 -Task query -ExactName LuaEntity -Stage runtime -RefreshIfMissing
powershell -ExecutionPolicy Bypass -File .\scripts\invoke-factorio-lua-docs.ps1 -Task query -Query on_player_created -Stage runtime -Kind event -RefreshIfMissing
powershell -ExecutionPolicy Bypass -File .\scripts\invoke-factorio-lua-docs.ps1 -Task query -ExactName RecipePrototype -Stage prototype -RefreshIfMissing
powershell -ExecutionPolicy Bypass -File .\scripts\invoke-factorio-lua-docs.ps1 -Task query -Query migrations -Stage auxiliary -RefreshIfMissing
```
