#!/usr/bin/env python3
"""Safe Meshy REST fallback helper.

Reads only MESHY_API_KEY from the environment and never prints auth headers.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any


BASE_URL = "https://api.meshy.ai/openapi"
ANIMATION_LIBRARY_URL = "https://api.meshy.ai/web/public/animations/resources"
DEFAULT_OUTPUT_DIR = Path("output/meshy")
TERMINAL_STATUSES = {"SUCCEEDED", "FAILED", "CANCELED"}

ENDPOINTS = {
    "text-3d": "/v2/text-to-3d",
    "image-3d": "/v1/image-to-3d",
    "multi-image-3d": "/v1/multi-image-to-3d",
    "remesh": "/v1/remesh",
    "retexture": "/v1/retexture",
    "rigging": "/v1/rigging",
    "animation": "/v1/animations",
    "text-image": "/v1/text-to-image",
    "image-image": "/v1/image-to-image",
    "multi-color-print": "/v1/print/multi-color",
}


class MeshyError(RuntimeError):
    pass


def endpoint_path(task_type: str) -> str:
    try:
        return ENDPOINTS[task_type]
    except KeyError as exc:
        choices = ", ".join(sorted(ENDPOINTS))
        raise MeshyError(f"Unknown task type {task_type!r}. Choices: {choices}") from exc


def api_key() -> str:
    key = os.environ.get("MESHY_API_KEY")
    if not key:
        raise MeshyError("MESHY_API_KEY is not set in the environment.")
    return key


def request_json(
    method: str,
    path: str,
    payload: dict[str, Any] | None = None,
    query: dict[str, Any] | None = None,
) -> Any:
    url = BASE_URL + path
    if query:
        clean_query = {k: v for k, v in query.items() if v is not None}
        if clean_query:
            url += "?" + urllib.parse.urlencode(clean_query)

    data = None
    headers = {
        "Authorization": f"Bearer {api_key()}",
        "Accept": "application/json",
    }
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"

    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=60) as response:
            raw = response.read()
            if not raw:
                return {}
            return json.loads(raw.decode("utf-8"))
    except urllib.error.HTTPError as exc:
        message = exc.reason
        raw = exc.read()
        if raw:
            try:
                body = json.loads(raw.decode("utf-8"))
                message = body.get("message") or json.dumps(body)
            except Exception:
                message = raw.decode("utf-8", errors="replace")
        raise MeshyError(f"Meshy API returned HTTP {exc.code}: {message}") from exc
    except urllib.error.URLError as exc:
        raise MeshyError(f"Meshy API request failed: {exc.reason}") from exc


def request_public_json(url: str) -> Any:
    req = urllib.request.Request(url, headers={"Accept": "application/json"}, method="GET")
    try:
        with urllib.request.urlopen(req, timeout=60) as response:
            raw = response.read()
            if not raw:
                return {}
            return json.loads(raw.decode("utf-8"))
    except urllib.error.HTTPError as exc:
        message = exc.reason
        raw = exc.read()
        if raw:
            try:
                body = json.loads(raw.decode("utf-8"))
                message = body.get("message") or json.dumps(body)
            except Exception:
                message = raw.decode("utf-8", errors="replace")
        raise MeshyError(f"Meshy public endpoint returned HTTP {exc.code}: {message}") from exc
    except urllib.error.URLError as exc:
        raise MeshyError(f"Meshy public endpoint request failed: {exc.reason}") from exc


def read_payload(args: argparse.Namespace) -> dict[str, Any]:
    sources = [bool(getattr(args, "payload_json", None)), bool(getattr(args, "payload_file", None))]
    if sum(sources) != 1:
        raise MeshyError("Provide exactly one of --payload-json or --payload-file.")

    if args.payload_json:
        try:
            value = json.loads(args.payload_json)
        except json.JSONDecodeError as exc:
            raise MeshyError(f"--payload-json is not valid JSON: {exc}") from exc
    else:
        try:
            value = json.loads(Path(args.payload_file).read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            raise MeshyError(f"--payload-file is not valid JSON: {exc}") from exc

    if not isinstance(value, dict):
        raise MeshyError("Payload must be a JSON object.")
    return value


def print_json(value: Any) -> None:
    print(json.dumps(value, indent=2, sort_keys=True))


def print_dry_run(task_type: str, payload: dict[str, Any]) -> None:
    print_json(
        {
            "dry_run": True,
            "method": "POST",
            "url": BASE_URL + endpoint_path(task_type),
            "task_type": task_type,
            "payload": payload,
            "note": "No API key was read and no Meshy request was made.",
        }
    )


def task_id_from_create(response: Any) -> str:
    if not isinstance(response, dict) or not response.get("result"):
        raise MeshyError("Create response did not contain a result task id.")
    return str(response["result"])


def get_task(task_type: str, task_id: str) -> dict[str, Any]:
    task = request_json("GET", f"{endpoint_path(task_type)}/{task_id}")
    if not isinstance(task, dict):
        raise MeshyError("Task response was not a JSON object.")
    return task


def poll_task(task_type: str, task_id: str, interval: float, timeout: float) -> dict[str, Any]:
    started = time.monotonic()
    while True:
        task = get_task(task_type, task_id)
        status = str(task.get("status", "UNKNOWN"))
        progress = task.get("progress")
        if progress is None:
            print(f"{task_id}: {status}")
        else:
            print(f"{task_id}: {status} {progress}%")

        if status in TERMINAL_STATUSES:
            return task
        if timeout > 0 and time.monotonic() - started >= timeout:
            raise MeshyError(f"Timed out waiting for {task_id}; last status was {status}.")
        time.sleep(interval)


def stream_task(task_type: str, task_id: str) -> None:
    url = BASE_URL + f"{endpoint_path(task_type)}/{task_id}/stream"
    headers = {
        "Authorization": f"Bearer {api_key()}",
        "Accept": "text/event-stream",
    }
    req = urllib.request.Request(url, headers=headers, method="GET")
    try:
        with urllib.request.urlopen(req, timeout=60) as response:
            for raw_line in response:
                line = raw_line.decode("utf-8", errors="replace").strip()
                if not line.startswith("data:"):
                    continue
                payload = line[5:].strip()
                if not payload:
                    continue
                try:
                    data = json.loads(payload)
                except json.JSONDecodeError:
                    print(payload)
                    continue
                status = data.get("status")
                progress = data.get("progress")
                if progress is None:
                    print_json(data)
                else:
                    print(f"{task_id}: {status} {progress}%")
                if status in TERMINAL_STATUSES:
                    break
    except urllib.error.HTTPError as exc:
        raise MeshyError(f"Meshy stream returned HTTP {exc.code}: {exc.reason}") from exc
    except urllib.error.URLError as exc:
        raise MeshyError(f"Meshy stream failed: {exc.reason}") from exc


def safe_filename(task_id: str, url: str, index: int | None = None, preferred_format: str | None = None) -> str:
    parsed = urllib.parse.urlparse(url)
    suffix = Path(parsed.path).suffix
    if not suffix and preferred_format:
        suffix = "." + preferred_format.lstrip(".")
    if not suffix:
        suffix = ".bin"
    if index is None:
        return f"{task_id}{suffix}"
    return f"{task_id}-{index}{suffix}"


def download_url(url: str, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    with urllib.request.urlopen(url, timeout=120) as response:
        destination.write_bytes(response.read())


def output_urls(task: dict[str, Any], fmt: str | None) -> list[tuple[str, str | None, int | None]]:
    if fmt:
        urls = task.get("model_urls")
        if isinstance(urls, dict):
            if fmt not in urls:
                available = ", ".join(sorted(urls))
                raise MeshyError(f"Format {fmt!r} is not available. Available model formats: {available}")
            return [(str(urls[fmt]), fmt, None)]

    urls = task.get("model_urls")
    if isinstance(urls, dict) and urls:
        if fmt:
            available = ", ".join(sorted(urls))
            raise MeshyError(f"Format {fmt!r} is not available. Available model formats: {available}")
        return [(str(url), key, None) for key, url in urls.items()]

    image_urls = task.get("image_urls")
    if isinstance(image_urls, list) and image_urls:
        if fmt and fmt not in {"png", "jpg", "jpeg", "webp"}:
            raise MeshyError("Image tasks do not expose model formats; omit --format or use an image extension hint.")
        return [(str(url), fmt, idx + 1) for idx, url in enumerate(image_urls)]

    extra_keys = [
        "rigged_character_glb_url",
        "rigged_character_fbx_url",
        "animated_model_glb_url",
        "animated_model_fbx_url",
        "model_url",
        "result_url",
    ]
    found: list[tuple[str, str | None, int | None]] = []
    for key in extra_keys:
        value = task.get(key)
        if isinstance(value, str) and value:
            found.append((value, None, len(found) + 1))
    if found:
        return found

    raise MeshyError("No downloadable output URLs were found in the task response.")


def write_metadata(task: dict[str, Any], output_dir: Path, task_id: str) -> Path:
    output_dir.mkdir(parents=True, exist_ok=True)
    metadata_path = output_dir / f"{task_id}.task.json"
    metadata_path.write_text(json.dumps(task, indent=2, sort_keys=True), encoding="utf-8")
    return metadata_path


def download_task_outputs(task: dict[str, Any], output_dir: Path, fmt: str | None) -> list[Path]:
    task_id = str(task.get("id") or task.get("result") or "meshy-task")
    paths: list[Path] = []
    for url, format_hint, index in output_urls(task, fmt):
        filename = safe_filename(task_id, url, index=index, preferred_format=format_hint or fmt)
        destination = output_dir / filename
        download_url(url, destination)
        paths.append(destination)
        print(f"Downloaded {destination}")
    metadata_path = write_metadata(task, output_dir, task_id)
    print(f"Wrote {metadata_path}")
    return paths


def maybe_poll_and_download(
    task_type: str,
    task_id: str,
    args: argparse.Namespace,
) -> None:
    final_task: dict[str, Any] | None = None
    if getattr(args, "stream", False):
        stream_task(task_type, task_id)
        if getattr(args, "download", False):
            final_task = get_task(task_type, task_id)
    elif getattr(args, "poll", False) or getattr(args, "download", False):
        final_task = poll_task(task_type, task_id, args.interval, args.timeout)

    if getattr(args, "download", False):
        if final_task is None:
            final_task = get_task(task_type, task_id)
        if final_task.get("status") != "SUCCEEDED":
            raise MeshyError(f"Refusing to download task with status {final_task.get('status')!r}.")
        download_task_outputs(final_task, Path(args.output_dir), getattr(args, "format", None))


def add_common_async_flags(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--dry-run", action="store_true", help="Print the request payload without reading credentials or calling Meshy.")
    parser.add_argument("--poll", action="store_true", help="Poll until the task reaches a terminal status.")
    parser.add_argument("--stream", action="store_true", help="Stream task progress with Server-Sent Events.")
    parser.add_argument("--download", action="store_true", help="Download outputs after the task succeeds.")
    parser.add_argument("--output-dir", default=str(DEFAULT_OUTPUT_DIR), help="Directory for downloaded assets and task JSON.")
    parser.add_argument("--format", dest="format", help="Preferred model format, such as glb, fbx, obj, stl, or usdz.")
    parser.add_argument("--interval", type=float, default=5.0, help="Polling interval in seconds.")
    parser.add_argument("--timeout", type=float, default=1800.0, help="Polling timeout in seconds; 0 disables timeout.")


def add_target_format_flags(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "--target-format",
        action="append",
        dest="target_formats",
        help="Requested output format. Repeat for multiple formats.",
    )


def apply_target_formats(payload: dict[str, Any], args: argparse.Namespace) -> None:
    if getattr(args, "target_formats", None):
        payload["target_formats"] = args.target_formats


def command_balance(_: argparse.Namespace) -> None:
    print_json(request_json("GET", "/v1/balance"))


def command_create(args: argparse.Namespace) -> None:
    payload = read_payload(args)
    if args.dry_run:
        print_dry_run(args.task_type, payload)
        return
    response = request_json("POST", endpoint_path(args.task_type), payload)
    print_json(response)
    maybe_poll_and_download(args.task_type, task_id_from_create(response), args)


def command_get(args: argparse.Namespace) -> None:
    print_json(get_task(args.task_type, args.task_id))


def command_list(args: argparse.Namespace) -> None:
    query = {
        "page_num": args.page_num,
        "page_size": args.page_size,
        "sort_by": args.sort_by,
    }
    print_json(request_json("GET", endpoint_path(args.task_type), query=query))


def command_poll(args: argparse.Namespace) -> None:
    task = poll_task(args.task_type, args.task_id, args.interval, args.timeout)
    print_json(task)


def command_stream(args: argparse.Namespace) -> None:
    stream_task(args.task_type, args.task_id)


def command_download(args: argparse.Namespace) -> None:
    task = get_task(args.task_type, args.task_id)
    if task.get("status") != "SUCCEEDED":
        raise MeshyError(f"Refusing to download task with status {task.get('status')!r}.")
    download_task_outputs(task, Path(args.output_dir), args.format)


def animation_library_items(data: Any) -> tuple[list[dict[str, Any]], int | None]:
    if isinstance(data, dict):
        result = data.get("result")
        if isinstance(result, dict):
            items = result.get("list")
            total = result.get("total")
            if isinstance(items, list):
                return [item for item in items if isinstance(item, dict)], total if isinstance(total, int) else None
        items = data.get("list")
        total = data.get("total")
        if isinstance(items, list):
            return [item for item in items if isinstance(item, dict)], total if isinstance(total, int) else None
    if isinstance(data, list):
        return [item for item in data if isinstance(item, dict)], len(data)
    raise MeshyError("Animation library response did not contain a list of animations.")


def animation_matches(item: dict[str, Any], args: argparse.Namespace) -> bool:
    if args.category and str(item.get("category", "")).lower() != args.category.lower():
        return False
    if args.sub_category and str(item.get("subCategory", "")).lower() != args.sub_category.lower():
        return False
    if args.rig_type and str(item.get("rigType", "")).lower() != args.rig_type.lower():
        return False
    if args.free_only and item.get("isFree") is not True:
        return False
    if args.search:
        haystack = " ".join(
            str(item.get(key, ""))
            for key in ("id", "key", "name", "category", "subCategory", "rigType", "tag")
        ).lower()
        if args.search.lower() not in haystack:
            return False
    return True


def command_animation_library(args: argparse.Namespace) -> None:
    data = request_public_json(ANIMATION_LIBRARY_URL)
    if args.raw:
        print_json(data)
        return

    items, total = animation_library_items(data)
    filtered = [item for item in items if animation_matches(item, args)]
    if args.limit is not None and args.limit > 0:
        filtered = filtered[: args.limit]

    output = {
        "source": ANIMATION_LIBRARY_URL,
        "total": total if total is not None else len(items),
        "matched": len([item for item in items if animation_matches(item, args)]),
        "returned": len(filtered),
        "items": [
            {
                "id": item.get("id"),
                "key": item.get("key"),
                "name": item.get("name"),
                "category": item.get("category"),
                "subCategory": item.get("subCategory"),
                "rigType": item.get("rigType"),
                "tag": item.get("tag"),
                "isFree": item.get("isFree"),
                "previewUrl": item.get("previewUrl"),
            }
            for item in filtered
        ],
    }

    if args.output_file:
        path = Path(args.output_file)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(output, indent=2, sort_keys=True), encoding="utf-8")
        print(f"Wrote {path}")
    else:
        print_json(output)


def command_text_3d_preview(args: argparse.Namespace) -> None:
    payload: dict[str, Any] = {
        "mode": "preview",
        "prompt": args.prompt,
    }
    if args.ai_model:
        payload["ai_model"] = args.ai_model
    if args.negative_prompt:
        payload["negative_prompt"] = args.negative_prompt
    if args.art_style:
        payload["art_style"] = args.art_style
    if args.should_remesh:
        payload["should_remesh"] = True
    if args.target_polycount is not None:
        payload["target_polycount"] = args.target_polycount
    apply_target_formats(payload, args)
    if args.dry_run:
        print_dry_run("text-3d", payload)
        return
    response = request_json("POST", endpoint_path("text-3d"), payload)
    print_json(response)
    maybe_poll_and_download("text-3d", task_id_from_create(response), args)


def command_text_3d_refine(args: argparse.Namespace) -> None:
    payload: dict[str, Any] = {
        "mode": "refine",
        "preview_task_id": args.preview_task_id,
    }
    if args.enable_pbr:
        payload["enable_pbr"] = True
    if args.texture_prompt:
        payload["texture_prompt"] = args.texture_prompt
    if args.auto_size:
        payload["auto_size"] = True
    apply_target_formats(payload, args)
    if args.dry_run:
        print_dry_run("text-3d", payload)
        return
    response = request_json("POST", endpoint_path("text-3d"), payload)
    print_json(response)
    maybe_poll_and_download("text-3d", task_id_from_create(response), args)


def command_image_3d(args: argparse.Namespace) -> None:
    payload: dict[str, Any] = {"image_url": args.image_url}
    if args.enable_pbr:
        payload["enable_pbr"] = True
    if args.should_remesh:
        payload["should_remesh"] = True
    if args.should_texture:
        payload["should_texture"] = True
    if args.pose_mode:
        payload["pose_mode"] = args.pose_mode
    if args.target_polycount is not None:
        payload["target_polycount"] = args.target_polycount
    apply_target_formats(payload, args)
    if args.dry_run:
        print_dry_run("image-3d", payload)
        return
    response = request_json("POST", endpoint_path("image-3d"), payload)
    print_json(response)
    maybe_poll_and_download("image-3d", task_id_from_create(response), args)


def command_multi_image_3d(args: argparse.Namespace) -> None:
    payload: dict[str, Any] = {"image_urls": args.image_url}
    if args.enable_pbr:
        payload["enable_pbr"] = True
    if args.should_remesh:
        payload["should_remesh"] = True
    if args.should_texture:
        payload["should_texture"] = True
    if args.target_polycount is not None:
        payload["target_polycount"] = args.target_polycount
    apply_target_formats(payload, args)
    if args.dry_run:
        print_dry_run("multi-image-3d", payload)
        return
    response = request_json("POST", endpoint_path("multi-image-3d"), payload)
    print_json(response)
    maybe_poll_and_download("multi-image-3d", task_id_from_create(response), args)


def command_text_image(args: argparse.Namespace) -> None:
    payload: dict[str, Any] = {
        "ai_model": args.ai_model,
        "prompt": args.prompt,
    }
    if args.aspect_ratio:
        payload["aspect_ratio"] = args.aspect_ratio
    if args.generate_multi_view:
        payload["generate_multi_view"] = True
    if args.dry_run:
        print_dry_run("text-image", payload)
        return
    response = request_json("POST", endpoint_path("text-image"), payload)
    print_json(response)
    maybe_poll_and_download("text-image", task_id_from_create(response), args)


def command_image_image(args: argparse.Namespace) -> None:
    payload: dict[str, Any] = {
        "ai_model": args.ai_model,
        "prompt": args.prompt,
        "reference_image_urls": args.reference_image_url,
    }
    if args.dry_run:
        print_dry_run("image-image", payload)
        return
    response = request_json("POST", endpoint_path("image-image"), payload)
    print_json(response)
    maybe_poll_and_download("image-image", task_id_from_create(response), args)


def command_remesh(args: argparse.Namespace) -> None:
    payload: dict[str, Any] = {}
    if args.input_task_id:
        payload["input_task_id"] = args.input_task_id
    if args.model_url:
        payload["model_url"] = args.model_url
    if not payload:
        raise MeshyError("Provide --input-task-id or --model-url.")
    if args.topology:
        payload["topology"] = args.topology
    if args.target_polycount is not None:
        payload["target_polycount"] = args.target_polycount
    if args.auto_size:
        payload["auto_size"] = True
    if args.resize_height is not None:
        payload["resize_height"] = args.resize_height
    if args.origin_at:
        payload["origin_at"] = args.origin_at
    apply_target_formats(payload, args)
    if args.dry_run:
        print_dry_run("remesh", payload)
        return
    response = request_json("POST", endpoint_path("remesh"), payload)
    print_json(response)
    maybe_poll_and_download("remesh", task_id_from_create(response), args)


def command_retexture(args: argparse.Namespace) -> None:
    payload: dict[str, Any] = {}
    if args.input_task_id:
        payload["input_task_id"] = args.input_task_id
    if args.model_url:
        payload["model_url"] = args.model_url
    if not payload:
        raise MeshyError("Provide --input-task-id or --model-url.")
    if args.text_style_prompt:
        payload["text_style_prompt"] = args.text_style_prompt
    if args.image_style_url:
        payload["image_style_url"] = args.image_style_url
    if not args.text_style_prompt and not args.image_style_url:
        raise MeshyError("Provide --text-style-prompt or --image-style-url.")
    if args.ai_model:
        payload["ai_model"] = args.ai_model
    if args.enable_pbr:
        payload["enable_pbr"] = True
    if args.enable_original_uv:
        payload["enable_original_uv"] = True
    apply_target_formats(payload, args)
    if args.dry_run:
        print_dry_run("retexture", payload)
        return
    response = request_json("POST", endpoint_path("retexture"), payload)
    print_json(response)
    maybe_poll_and_download("retexture", task_id_from_create(response), args)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Safe Meshy REST fallback helper.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    balance = subparsers.add_parser("balance", help="Check Meshy credit balance.")
    balance.set_defaults(func=command_balance)

    create = subparsers.add_parser("create", help="Create a task from raw JSON payload.")
    create.add_argument("task_type", choices=sorted(ENDPOINTS))
    create.add_argument("--payload-json", help="JSON object payload.")
    create.add_argument("--payload-file", help="Path to JSON object payload.")
    add_common_async_flags(create)
    create.set_defaults(func=command_create)

    get = subparsers.add_parser("get", help="Fetch a task by id.")
    get.add_argument("task_type", choices=sorted(ENDPOINTS))
    get.add_argument("task_id")
    get.set_defaults(func=command_get)

    list_parser = subparsers.add_parser("list", help="List recent tasks.")
    list_parser.add_argument("task_type", choices=sorted(ENDPOINTS))
    list_parser.add_argument("--page-num", type=int, default=1)
    list_parser.add_argument("--page-size", type=int, default=10)
    list_parser.add_argument("--sort-by", default="-created_at")
    list_parser.set_defaults(func=command_list)

    poll = subparsers.add_parser("poll", help="Poll a task until terminal status.")
    poll.add_argument("task_type", choices=sorted(ENDPOINTS))
    poll.add_argument("task_id")
    poll.add_argument("--interval", type=float, default=5.0)
    poll.add_argument("--timeout", type=float, default=1800.0)
    poll.set_defaults(func=command_poll)

    stream = subparsers.add_parser("stream", help="Stream task progress with SSE.")
    stream.add_argument("task_type", choices=sorted(ENDPOINTS))
    stream.add_argument("task_id")
    stream.set_defaults(func=command_stream)

    download = subparsers.add_parser("download", help="Download outputs for a succeeded task.")
    download.add_argument("task_type", choices=sorted(ENDPOINTS))
    download.add_argument("task_id")
    download.add_argument("--output-dir", default=str(DEFAULT_OUTPUT_DIR))
    download.add_argument("--format", dest="format", help="Preferred model format.")
    download.set_defaults(func=command_download)

    animation_library = subparsers.add_parser(
        "animation-library",
        help="Search Meshy's public animation action_id catalog; does not read MESHY_API_KEY.",
    )
    animation_library.add_argument("--search", help="Case-insensitive search across id, key, name, category, and tag.")
    animation_library.add_argument("--category", help="Filter by category, such as WalkAndRun or Fighting.")
    animation_library.add_argument("--sub-category", help="Filter by subCategory, such as Walking or Running.")
    animation_library.add_argument("--rig-type", help="Filter by rigType, such as biped or style_02.")
    animation_library.add_argument("--free-only", action="store_true", help="Return only free animations.")
    animation_library.add_argument("--limit", type=int, default=50, help="Maximum filtered records to return; use 0 for no limit.")
    animation_library.add_argument("--raw", action="store_true", help="Print the raw endpoint response.")
    animation_library.add_argument("--output-file", help="Write filtered JSON to this path instead of stdout.")
    animation_library.set_defaults(func=command_animation_library)

    text3d = subparsers.add_parser("text-3d-preview", help="Create a Text-to-3D preview task.")
    text3d.add_argument("--prompt", required=True)
    text3d.add_argument("--ai-model", default="latest")
    text3d.add_argument("--negative-prompt")
    text3d.add_argument("--art-style")
    text3d.add_argument("--should-remesh", action="store_true")
    text3d.add_argument("--target-polycount", type=int)
    add_target_format_flags(text3d)
    add_common_async_flags(text3d)
    text3d.set_defaults(func=command_text_3d_preview)

    refine = subparsers.add_parser("text-3d-refine", help="Create a Text-to-3D refine task.")
    refine.add_argument("--preview-task-id", required=True)
    refine.add_argument("--texture-prompt")
    refine.add_argument("--enable-pbr", action="store_true")
    refine.add_argument("--auto-size", action="store_true")
    add_target_format_flags(refine)
    add_common_async_flags(refine)
    refine.set_defaults(func=command_text_3d_refine)

    image3d = subparsers.add_parser("image-3d", help="Create an Image-to-3D task.")
    image3d.add_argument("--image-url", required=True)
    image3d.add_argument("--enable-pbr", action="store_true")
    image3d.add_argument("--should-remesh", action="store_true")
    image3d.add_argument("--should-texture", action="store_true")
    image3d.add_argument("--pose-mode", choices=["a-pose", "t-pose"])
    image3d.add_argument("--target-polycount", type=int)
    add_target_format_flags(image3d)
    add_common_async_flags(image3d)
    image3d.set_defaults(func=command_image_3d)

    multi_image = subparsers.add_parser("multi-image-3d", help="Create a Multi-Image-to-3D task.")
    multi_image.add_argument("--image-url", action="append", required=True, help="Image URL or data URI. Repeat 1-4 times.")
    multi_image.add_argument("--enable-pbr", action="store_true")
    multi_image.add_argument("--should-remesh", action="store_true")
    multi_image.add_argument("--should-texture", action="store_true")
    multi_image.add_argument("--target-polycount", type=int)
    add_target_format_flags(multi_image)
    add_common_async_flags(multi_image)
    multi_image.set_defaults(func=command_multi_image_3d)

    text_image = subparsers.add_parser("text-image", help="Create a Text-to-Image task.")
    text_image.add_argument("--prompt", required=True)
    text_image.add_argument("--ai-model", default="nano-banana")
    text_image.add_argument("--aspect-ratio")
    text_image.add_argument("--generate-multi-view", action="store_true")
    add_common_async_flags(text_image)
    text_image.set_defaults(func=command_text_image)

    image_image = subparsers.add_parser("image-image", help="Create an Image-to-Image task.")
    image_image.add_argument("--prompt", required=True)
    image_image.add_argument("--reference-image-url", action="append", required=True)
    image_image.add_argument("--ai-model", default="nano-banana")
    add_common_async_flags(image_image)
    image_image.set_defaults(func=command_image_image)

    remesh = subparsers.add_parser("remesh", help="Create a Remesh task.")
    remesh.add_argument("--input-task-id")
    remesh.add_argument("--model-url")
    remesh.add_argument("--topology")
    remesh.add_argument("--target-polycount", type=int)
    remesh.add_argument("--auto-size", action="store_true")
    remesh.add_argument("--resize-height", type=float)
    remesh.add_argument("--origin-at")
    add_target_format_flags(remesh)
    add_common_async_flags(remesh)
    remesh.set_defaults(func=command_remesh)

    retexture = subparsers.add_parser("retexture", help="Create a Retexture task.")
    retexture.add_argument("--input-task-id")
    retexture.add_argument("--model-url")
    retexture.add_argument("--text-style-prompt")
    retexture.add_argument("--image-style-url")
    retexture.add_argument("--ai-model")
    retexture.add_argument("--enable-pbr", action="store_true")
    retexture.add_argument("--enable-original-uv", action="store_true")
    add_target_format_flags(retexture)
    add_common_async_flags(retexture)
    retexture.set_defaults(func=command_retexture)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if getattr(args, "poll", False) and getattr(args, "stream", False):
        parser.error("--poll and --stream are mutually exclusive.")
    try:
        args.func(args)
        return 0
    except MeshyError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
