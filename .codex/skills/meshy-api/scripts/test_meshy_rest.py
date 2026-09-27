"""Offline CLI payload checks; the transport is replaced with a fail-fast stub."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path

path = Path(__file__).with_name("meshy_rest.py")
spec = importlib.util.spec_from_file_location("meshy_rest", path)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
mod.request_json = lambda *a, **kw: (_ for _ in ()).throw(AssertionError("Unexpected network"))

def run(args, code=0):
    out = io.StringIO()
    with contextlib.redirect_stdout(out), contextlib.redirect_stderr(io.StringIO()):
        try:
            actual = mod.main([*args, "--dry-run"])
        except SystemExit as exc:
            actual = exc.code
    assert actual == code, (args, actual)
    return json.loads(out.getvalue())["payload"] if code == 0 else None

base = ["image-3d", "--image-url", "https://example.com/reference.png"]
assert run([*base, "--ai-model", "meshy-7.1", "--geometry-resolution", "4k"])["geometry_resolution"] == "4k"
assert run([*base, "--model-type", "smart-topology", "--target-polycount", "15000"])["ai_model"] == "meshy-t2"
run([*base, "--model-type", "smart-topology", "--target-polycount", "30000"], 1)
run([*base, "--model-type", "smart-topology", "--topology", "quad"], 1)
run([*base, "--ai-model", "meshy-6", "--geometry-resolution", "2k"], 1)
assert run([*base, "--no-should-texture"])["should_texture"] is False
run([*base, "--no-should-texture", "--enable-pbr"], 1)
run([*base, "--ai-model", "meshy-5"], 2)
run(["multi-image-3d", "--image-url", "https://example.com/x.png", "--geometry-resolution", "4k"], 2)
assert run(["text-3d-preview", "--prompt", "water turret", "--model-type", "smart-topology"])["ai_model"] == "meshy-t2"
assert run(["image-image", "--prompt", "blue paint", "--input-task-id", "source", "--remove-background"])["input_task_id"] == "source"
assert run(["text-image", "--prompt", "blue turret", "--ai-model", "gpt-image-2-5-flare", "--remove-background"])["remove_background"] is True
assert mod.endpoint_path("auto-split") == "/v1/print/split"
print("13 offline REST checks passed; no credentials or API calls")
