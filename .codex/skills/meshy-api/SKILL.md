---
name: meshy-api
description: "Use when Codex should work with Meshy.ai API or MCP workflows for text-to-3D, image-to-3D, multi-image-to-3D, remesh, retexture, rigging, animation, animation-library lookup, 2D image generation, balance checks, downloads, manual site asset handoff, or ESIR asset prototyping with safe environment-based credentials."
---

# Meshy API

Use this skill when a task needs Meshy.ai model, image, texture, rigging, animation, animation-library lookup, print, task-management, site/manual asset handoff, or account-balance workflows.

## Hard Rules

- Never write, print, echo, or ask the user to paste a Meshy API key.
- Read credentials only from `MESHY_API_KEY` in the local environment.
- Prefer Meshy MCP tools when they are already configured and visible.
- In this workspace, the Codex MCP server is configured globally as `meshy`.
- Fall back to `scripts/meshy_rest.py` when MCP tools are unavailable or when a deterministic local download is useful.
- Treat generation calls as credit-consuming unless the environment is intentionally using Meshy's documented test-mode key.
- Keep generated assets, task metadata, and experiments under ignored `output/meshy/` unless the user gives another path.
- Keep durable prompt notes in `.codex/esir/art-prompts/` and reusable generator/replay scripts in `.codex/esir/asset-generators/`; `output/` is not a commit-safe source home.
- Do not wire generated assets into ESIR prototypes, graphics folders, locale, or changelogs unless the user explicitly asks for that follow-up.

## Workflow

1. Clarify the desired output only if it affects cost, format, or irreversible deletion.
2. Check whether Meshy MCP tools are available. If they are, use them for generate, status, download, and balance work.
3. If MCP is not available, read `references/api-workflows.md`, then use the REST helper from the repo root.
4. Use `--dry-run` when preparing or reviewing a generation command without spending credits.
5. For async tasks, create the task, record the task ID, poll or stream until a terminal status, then download any needed outputs before retention expires.
6. Save task JSON next to downloaded outputs so the prompt, status, credit use, and source task stay inspectable.
7. For assets generated manually in the Meshy web app, prefer the official DCC Bridge to Blender or a user-provided signed asset URL. Do not assume there is a public REST "My Assets" library endpoint; current official API docs expose task list/get/download and the public animation catalog, not a documented personal asset-library API.

## REST Helper

Run from the repo root:

```powershell
python .codex/skills/meshy-api/scripts/meshy_rest.py --help
```

Examples:

```powershell
python .codex/skills/meshy-api/scripts/meshy_rest.py balance

python .codex/skills/meshy-api/scripts/meshy_rest.py text-3d-preview `
  --prompt "black sigil industrial threshold obelisk, readable game asset silhouette" `
  --target-format glb `
  --dry-run

python .codex/skills/meshy-api/scripts/meshy_rest.py text-3d-preview `
  --prompt "black sigil industrial threshold obelisk, readable game asset silhouette" `
  --target-format glb `
  --poll `
  --download

python .codex/skills/meshy-api/scripts/meshy_rest.py image-3d `
  --image-url "https://example.com/reference.png" `
  --enable-pbr `
  --should-texture `
  --target-format glb `
  --poll `
  --download

$payload = '{""input_task_id"":""TASK_ID"",""target_formats"":[""glb""],""target_polycount"":50000}'
python .codex/skills/meshy-api/scripts/meshy_rest.py remesh `
  --input-task-id TASK_ID `
  --target-format glb `
  --target-polycount 50000 `
  --dry-run

python .codex/skills/meshy-api/scripts/meshy_rest.py animation-library `
  --search "walk" `
  --free-only `
  --limit 20
```

## ESIR Asset Notes

- Bias prompts toward silhouettes that read at Factorio scale: strong outline, low clutter, clear top-down identity, no tiny text.
- Use Remembrance language when it helps the asset direction: recursion, rupture, signal, memory, machinery, oath, blade, devotion, decay, threshold, fracture, cosmic industry.
- Prefer GLB for quick local review and OBJ/FBX only when downstream tooling needs them.
- When an asset should communicate ownership, ask for distinct neutral material groups or readable trim named like `team_color`, `force_trim`, or `color_mask` so Blender can render a separate runtime-tint mask. Use this for owner-readability only, such as turrets, vehicles, rolling stock, train stops/remotes, force-facing logistics/control devices, and ownership-critical entities.
- Do not request universal player/force recoloring for neutral terrain, decoratives, resources, ruins, pure environmental/alien forms, or assets whose baked ESIR chromatic identity should stay fixed.
- After a Meshy image-to-3D download, hand off to `$meshy-blender-spritesheet` using the local Factorio preset renderer by default, including orthographic framing, upper-left lighting, lower-right shadows, and separate base/shadow/light/mask passes before staging through `$esir-factorio-asset-export`; dark, edge-touching, or non-preset first drafts are test results, not promotion candidates.
- Download immediately when a result matters; non-Enterprise API assets may expire after 3 days.
