# Meshy API Workflows

Use this reference after `$meshy-api` triggers and before making direct REST calls.

## Current Sources

- Official API docs: `https://docs.meshy.ai`
- Agent docs index: `https://docs.meshy.ai/llms.txt`
- MCP setup and tool list: `https://docs.meshy.ai/api/ai`
- Blender DCC Bridge docs: `https://docs.meshy.ai/blender-plugin/bridge-to-blender`
- Animation library reference: `https://docs.meshy.ai/api/animation-library`
- Per-page Markdown can be fetched by appending `.md` to endpoint docs.

Verify current docs before adding new endpoint parameters. Meshy changes models, costs, and available task fields over time.

## Credentials And Safety

- Use `MESHY_API_KEY` only.
- Send auth as `Authorization: Bearer <env value>`.
- Do not call Meshy REST endpoints from browser JavaScript; use server-side or local scripts.
- Do not log auth headers, full environment dumps, or raw command lines containing secrets.
- A `402` means insufficient credits. A `429` can mean request-rate or queued-task limits.

## Async Task Pattern

Meshy generation and post-processing endpoints return a task id in `result`.

1. `POST` a task payload.
2. Save the returned task id.
3. Poll `GET /<task-endpoint>/:id` or stream `GET /<task-endpoint>/:id/stream`.
4. Stop on `SUCCEEDED`, `FAILED`, or `CANCELED`.
5. On `SUCCEEDED`, download from `model_urls`, `image_urls`, rigging URLs, animation URLs, or print output URLs, depending on task type.
6. Save the final task JSON beside the downloaded files.

Task status normally moves through `PENDING`, `IN_PROGRESS`, then `SUCCEEDED`, `FAILED`, or `CANCELED`. If `FAILED`, inspect `task_error.message` and keep the task id for debugging.

Use `--dry-run` on helper task-creation commands when planning commands, reviewing payloads, or avoiding credit-consuming calls. Dry-run prints the method, URL, task type, and JSON payload without reading `MESHY_API_KEY` or contacting Meshy.

For PowerShell inline JSON passed to native executables, double embedded quotes:

```powershell
$payload = '{""input_task_id"":""TASK_ID"",""target_formats"":[""glb""]}'
python .codex/skills/meshy-api/scripts/meshy_rest.py create remesh `
  --payload-json $payload `
  --dry-run
```

For larger payloads, prefer `--payload-file path\to\payload.json`.

Prefer typed helper commands such as `remesh`, `retexture`, `text-3d-preview`, and `image-3d` when they cover the task; reserve raw `create` for endpoint fields the helper does not expose yet.

## Endpoint Families

The bundled REST helper uses these endpoint keys:

| Key | Endpoint | Typical Use |
| --- | --- | --- |
| `text-3d` | `/openapi/v2/text-to-3d` | Text-to-3D preview and refine |
| `image-3d` | `/openapi/v1/image-to-3d` | Single image to 3D |
| `multi-image-3d` | `/openapi/v1/multi-image-to-3d` | 1-4 images of the same object to 3D |
| `remesh` | `/openapi/v1/remesh` | Topology, polycount, and format conversion |
| `retexture` | `/openapi/v1/retexture` | Apply a new text or image-driven texture |
| `rigging` | `/openapi/v1/rigging` | Rig humanoid/bipedal models |
| `animation` | `/openapi/v1/animations` | Apply an animation to a rigged character |
| `text-image` | `/openapi/v1/text-to-image` | Generate 2D source images |
| `image-image` | `/openapi/v1/image-to-image` | Transform source images |
| `multi-color-print` | `/openapi/v1/print/multi-color` | Convert supported textured models to multi-color print output |
| `balance` | `/openapi/v1/balance` | Check remaining API credits |

Documented public non-task helper:

| Helper | Endpoint | Typical Use |
| --- | --- | --- |
| `animation-library` | `https://api.meshy.ai/web/public/animations/resources` | Look up animation `action_id` values before creating animation tasks |

## Site And Library Assets

As of the latest checked official docs, Meshy documents task list/get/download endpoints and plugin bridge flows, but not a public REST endpoint for a user's personal web-app "My Assets" library.

Use these paths instead:

- API-generated assets: use `list`, `get`, or `download` with the relevant task type and task id.
- Web-app-generated assets: use Meshy's official DCC Bridge to Blender, which runs a local server on port `5324` and receives a direct model URL from the Meshy website.
- Animation presets: use `animation-library` to find `action_id` values; this is a public catalog endpoint and does not require `MESHY_API_KEY`.

Do not build workflows against private web-app routes unless Meshy publishes them in the official API docs. For manual site assets, stage downloaded files under `output/meshy/manual/` or the relevant asset folder before feeding them into Blender/export skills.

## Common Payloads

Text-to-3D preview:

```json
{
  "mode": "preview",
  "prompt": "readable game asset silhouette",
  "target_formats": ["glb"]
}
```

Text-to-3D refine:

```json
{
  "mode": "refine",
  "preview_task_id": "TASK_ID",
  "enable_pbr": true,
  "target_formats": ["glb"]
}
```

Image-to-3D:

```json
{
  "image_url": "https://example.com/reference.png",
  "should_texture": true,
  "enable_pbr": true,
  "target_formats": ["glb"]
}
```

Retexture:

```json
{
  "input_task_id": "TASK_ID",
  "text_style_prompt": "corroded black sigil metal, emissive signal scars",
  "enable_pbr": true
}
```

Remesh:

```json
{
  "input_task_id": "TASK_ID",
  "target_formats": ["glb"],
  "topology": "quad",
  "target_polycount": 50000
}
```

## Cost And Retention Checks

- Check balance before batch generation.
- Current public pricing lists credit costs for Text-to-3D preview/refine, Image-to-3D, Multi-Image-to-3D, Retexture, Remesh, Auto-Rigging, Animation, Text/Image-to-Image, and Multi-Color Print.
- Rate limits are account-wide and include request-per-second and queued-task limits.
- Generated API assets for non-Enterprise customers may be retained for only 3 days. Download anything important into `output/meshy/`.

## ESIR Prompt Bias

For ESIR concept work, prefer clear industrial silhouettes over detail density:

- strong primary shape
- visible top-down identity
- limited tiny appendages
- no embedded readable text
- texture prompts that separate metal, void, glass, bone, signal light, and corrosion
- optional Remembrance voice: black sigil, oathbreaker, mirror-protocol, threshold, daemon, signal-corruption
