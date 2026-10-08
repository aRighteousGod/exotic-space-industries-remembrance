"""Measure isolated reference17 emitters against registered native body frames.

Final evidence requires 128 real raw frames, isolated crown/facade captures,
complete day/night heading coverage, and the fixture camera/endpoint metadata.
--draft allows the existing eight-source preview and older composite captures
for diagnostics; its results never certify the final 128-direction contract.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter


ANCHOR_NAMES = {"crown": "top_crystal", "facade": "facade"}


def point(value):
    if isinstance(value, dict):
        return np.array([value["x"], value["y"]], dtype=float)
    return np.array(value, dtype=float)


def channel(pose, emitter):
    return ((pose.get("owner") or {}).get("burst") or {}).get(emitter, {})


def discover(root):
    """Read only the documented fixture families, keeping moving metadata paired."""
    samples = []
    manifest_file = root / "capture-manifest.json"
    capture = json.loads(manifest_file.read_text()) if manifest_file.exists() else {}
    for tick, lighting in ((180, "day"), (220, "night")):
        path = root / f"twin-muzzles-{tick}.json"
        if path.exists():
            for index, pose in enumerate(json.loads(path.read_text())):
                samples.append((f"pose-{index}-{lighting}", root / f"pose-{index}-{lighting}.png",
                                pose, "eight-headings", lighting, path))
    for family in ("directions128", "turn", "counterclockwise", "north-wrap"):
        folder = root / family
        path = folder / "poses.json"
        if path.exists():
            for number, pose in enumerate(json.loads(path.read_text())):
                if family == "directions128":
                    for lighting in ("day", "night"):
                        samples.append((f"{family}/{number:03d}-{lighting}",
                                        folder / f"{number:03d}-{lighting}.png", pose,
                                        family, lighting, path))
                else:
                    samples.append((f"{family}/{number+1:03d}", folder / f"{number+1:03d}.png",
                                    pose, family, "day", path))
        for extra in sorted(set(folder.glob("frozen*.json")) | set(folder.glob("static-*.json"))):
            samples.append((f"{family}/{extra.stem}", extra.with_suffix(".png"),
                            json.loads(extra.read_text()), family + "-stop", "day", extra))
    return samples, capture, manifest_file


class Evaluator:
    def __init__(self, bundle, draft=False):
        self.bundle = bundle
        self.manifest_file = bundle / "factorio-preset-render-manifest.json"
        self.manifest = json.loads(self.manifest_file.read_text())
        preflight = self.manifest["preflight"]
        self.count = preflight["anisetron_direction_count"]
        self.source_count = self.manifest["directions"]
        self.anchors = preflight["anisetron_anchor_pixels"]
        self.scale = preflight["anisetron_sprite_scale"]
        self.frame_size = 512
        assert self.count == 128
        assert all(len(self.anchors[name]) == self.count for name in ANCHOR_NAMES.values())
        if not draft and self.source_count != self.count:
            raise ValueError("Final evaluation requires128 actual raw body frames; preview is draft-only")
        self.cache = {}
        self.hashes = {}
        self.hash(self.manifest_file)

    def hash(self, path):
        key = str(path)
        if key not in self.hashes:
            self.hashes[key] = hashlib.sha256(path.read_bytes()).hexdigest()

    def frame(self, index, zoom):
        source_index = int(index * self.source_count / self.count + .5) % self.source_count
        key = source_index, zoom
        if key not in self.cache:
            path = self.bundle / "Object" / f"{source_index+1:04d}.png"
            self.hash(path)
            size = round(self.frame_size * self.scale * zoom)
            raw = Image.open(path).convert("RGBA").resize((size, size), Image.Resampling.BILINEAR)
            bounds = raw.getchannel("A").getbbox()
            if not bounds:
                raise ValueError(f"Empty raw body:{path}")
            ref = np.asarray(raw.crop(bounds), dtype=np.float32) / 255
            self.cache[key] = raw, bounds, ref, source_index
        return self.cache[key]

    def anchor(self, emitter, index, pivot, zoom):
        item = self.anchors[ANCHOR_NAMES[emitter]][index]
        return pivot + (point(item["anchor"]) - point(item["pivot"])) * self.scale * zoom

    @staticmethod
    def camera(pose, shape):
        info = pose.get("camera", {})
        zoom = float(info.get("zoom", 1))
        centre = point(info.get("position", point(pose["position"]) + [0, -5]))
        resolution = info.get("resolution", [shape[1], shape[0]])
        if list(resolution) != [shape[1], shape[0]]:
            raise ValueError("Camera resolution differs from PNG")
        origin = np.array([shape[1] / 2, shape[0] / 2])
        ground = origin + (point(pose["position"]) - centre) * 32 * zoom
        return zoom, centre, origin, ground, bool(info)

    def endpoint(self, pose, emitter, centre, origin, zoom, draft=False):
        item = channel(pose, emitter)
        endpoint = item.get("endpoint") or pose.get("target")
        exact = bool(item.get("endpoint"))
        if endpoint is None and draft:
            angle = pose["torso"] * math.tau
            endpoint = point(pose["position"]) + [math.sin(angle) * 20, -math.cos(angle) * 20]
        if endpoint is None:
            raise ValueError(f"Missing actual {emitter} beam endpoint")
        return origin + (point(endpoint) - centre) * 32 * zoom, exact

    @staticmethod
    def score(gray, sy, sx, reference, denominator, x, y):
        actual = gray[y + sy, x + sx]
        actual = actual - actual.mean()
        return float((reference * actual).sum() / (denominator * np.sqrt((actual * actual).sum())))

    def register(self, screen, pose, zoom, ground, endpoints):
        gray = screen.mean(2)
        q = pose["torso"] * self.count
        expected = math.floor(q + .5) % self.count
        if self.source_count != self.count:
            # Preview sheets repeat eight sources. A post-tick turn may cross
            # one repetition boundary; compare neighbouring source bins too.
            stride = self.count // self.source_count
            candidates = sorted({(expected + offset) % self.count
                                 for offset in (-stride, 0, stride)})
        else:
            candidates = sorted({(base + shift) % self.count
                                 for base in (math.floor(q), math.ceil(q), math.floor(q + .5))
                                 for shift in (-1, 0, 1)})
        guesses = []
        for index in candidates:
            raw, bounds, ref, source_index = self.frame(index, zoom)
            half = raw.width / 2
            # Baseheight plus a broad bob/movement search; fit determines the pivot.
            estimate = ground + [0, -70 * zoom]
            gx, gy = round(estimate[0] + bounds[0] - half), round(estimate[1] + bounds[1] - half)
            gold = ((ref[:, :, 3] > .95) & (ref[:, :, 0] > ref[:, :, 2] * 1.15)
                    & (ref[:, :, 0] > .035))
            ry, rx = np.indices(gold.shape)
            for emitter, endpoint in endpoints.items():
                muzzle = self.anchor(emitter, expected, estimate, zoom)
                direction = endpoint - muzzle
                direction /= np.linalg.norm(direction)
                normal = np.array([-direction[1], direction[0]])
                dx, dy = rx + gx - muzzle[0], ry + gy - muzzle[1]
                gold &= ~((dx * direction[0] + dy * direction[1] > -45 * zoom)
                          & (np.abs(dx * normal[0] + dy * normal[1]) < 42 * zoom))
            sy, sx = np.nonzero(gold)
            if len(sx) < 200:
                raise ValueError("Insufficient unaffected architecture pixels")
            reference = ref[:, :, :3].mean(2)[gold]
            reference -= reference.mean()
            denominator = np.sqrt((reference * reference).sum())
            def score(x, y):
                if min(x, y) < 1 or x + ref.shape[1] >= gray.shape[1] or y + ref.shape[0] >= gray.shape[0]:
                    return -1
                return self.score(gray, sy, sx, reference, denominator, x, y)
            radius = max(34, round(40 * zoom))
            best = max((score(x, y), x, y) for y in range(gy - radius, gy + radius + 1, 2)
                       for x in range(gx - 10, gx + 11, 2))
            base = best
            best = max((score(x, y), x, y) for y in range(base[2] - 1, base[2] + 2)
                       for x in range(base[1] - 1, base[1] + 2))
            guesses.append((best, index, source_index, raw, bounds, sy, sx, reference, denominator))
        guesses.sort(key=lambda entry: entry[0][0], reverse=True)
        (corr, x, y), index, source_index, raw, bounds, sy, sx, reference, denominator = guesses[0]
        def score(xa, ya):
            return self.score(gray, sy, sx, reference, denominator, xa, ya)
        xm, xp, ym, yp = score(x - 1, y), score(x + 1, y), score(x, y - 1), score(x, y + 1)
        ox = float(np.clip(.5 * (xm - xp) / (xm - 2 * corr + xp), -.5, .5))
        oy = float(np.clip(.5 * (ym - yp) / (ym - 2 * corr + yp), -.5, .5))
        pivot = np.array([x + ox + raw.width / 2 - bounds[0], y + oy + raw.height / 2 - bounds[1]])
        body_index = source_index * self.count // self.source_count
        return {"correlation": corr, "index": index, "body_index": body_index, "pivot": pivot,
                "raw": raw, "candidates": {str(g[1]): g[0][0] for g in guesses}}

    def measure(self, shot, pose, emitter, capture, draft=False):
        self.hash(shot)
        screen = np.asarray(Image.open(shot).convert("RGB"), dtype=np.float32) / 255
        zoom, centre, origin, ground, exact_camera = self.camera(pose, screen.shape)
        endpoints, exact_endpoint = {}, False
        for name in ANCHOR_NAMES:
            try:
                endpoint, exact = self.endpoint(pose, name, centre, origin, zoom, draft)
                endpoints[name] = endpoint
                if name == emitter:
                    exact_endpoint = exact
            except ValueError:
                if name == emitter:
                    raise
        registration = self.register(screen, pose, zoom, ground, endpoints)
        pivot, raw, index = registration["pivot"], registration["raw"], registration["body_index"]
        muzzle = self.anchor(emitter, index, pivot, zoom)
        endpoint = endpoints[emitter]
        direction = endpoint - muzzle
        direction /= np.linalg.norm(direction)
        normal = np.array([-direction[1], direction[0]])
        yy, xx = np.indices(screen.shape[:2])
        # Pixel centres share the same image-boundary coordinate convention as Blender projection.
        x, y = xx + .5, yy + .5
        along = (x - muzzle[0]) * direction[0] + (y - muzzle[1]) * direction[1]
        across = (x - muzzle[0]) * normal[0] + (y - muzzle[1]) * normal[1]
        occupied = Image.new("L", (screen.shape[1], screen.shape[0]))
        occupied.paste(raw.getchannel("A"), (round(pivot[0] - raw.width / 2), round(pivot[1] - raw.height / 2)))
        occupied = np.asarray(occupied.filter(ImageFilter.MaxFilter(11))) > 20
        color = screen * 255
        bright = ((color.max(2) - color.min(2) > 55) & (color.max(2) > 140)
                  & (color[:, :, 1] + color[:, :, 2] > 210))
        selected = bright & ~occupied & (along > 25 * zoom) & (np.abs(across) < 22 * zoom)
        view = pose.get("channel_view", capture.get("channel_view", "all"))
        isolated = view == emitter
        ambiguous = False
        if not isolated:
            other = "facade" if emitter == "crown" else "crown"
            other_muzzle = self.anchor(other, index, pivot, zoom)
            other_direction = endpoints.get(other, endpoint) - other_muzzle
            other_direction /= np.linalg.norm(other_direction)
            other_normal = np.array([-other_direction[1], other_direction[0]])
            separation = abs(float((muzzle - other_muzzle) @ other_normal))
            ambiguous = abs(float(direction @ other_normal)) < .04 and separation < 25 * zoom
            if not ambiguous:
                other_across = (x - other_muzzle[0]) * other_normal[0] + (y - other_muzzle[1]) * other_normal[1]
                selected &= np.abs(other_across) > 25 * zoom
        if ambiguous:
            return {"status": "overlapping-unisolated-rays", "isolated": False, "pass": False}
        coordinates = np.stack((x[selected], y[selected]), axis=1)
        if len(coordinates) < 100:
            raise ValueError(f"Insufficient separated beam pixels:{len(coordinates)}")
        broad_mean = coordinates.mean(0)
        broad_centred = coordinates - broad_mean
        _, broad_vectors = np.linalg.eigh(broad_centred.T @ broad_centred)
        broad_normal = np.array([-broad_vectors[1, -1], broad_vectors[0, -1]])
        halo_distance = abs(float((muzzle - broad_mean) @ broad_normal))
        # The Lance texture has deliberately asymmetric cyan/magenta shoulders,
        # doubled in the crown. Their area centroid is not the luminous axis.
        # Weight by the minimum RGB channel to isolate its white central core.
        weights = screen.min(2)[selected] ** 4
        if float(weights.sum()) < 1e-8:
            raise ValueError("Insufficient white-core energy")
        mean = (coordinates * weights[:, None]).sum(0) / weights.sum()
        centred = coordinates - mean
        _, vectors = np.linalg.eigh((centred * weights[:, None]).T @ centred)
        line = vectors[:, -1]
        line_normal = np.array([-line[1], line[0]])
        distance = abs(float((muzzle - mean) @ line_normal))
        paid = channel(pose, emitter)
        runtime_index = paid.get("muzzle_index")
        index_matches = runtime_index is not None and runtime_index - 1 == index
        valid_beam = paid.get("beam") is True
        return {"status": "measured", "isolated": isolated, "exact_camera": exact_camera,
                "exact_endpoint": exact_endpoint, "body_index": index,
                "matched_native_index": registration["index"], "body_frame_exact": self.source_count == self.count,
                "runtime_index": None if runtime_index is None else runtime_index - 1,
                "runtime_index_matches_body": index_matches,
                "correlation": round(registration["correlation"], 6),
                "candidate_correlations": {k: round(v, 6) for k, v in registration["candidates"].items()},
                "pivot_px": np.round(pivot, 6).tolist(), "anchor_px": np.round(muzzle, 6).tolist(),
                "centerline_distance_px": round(distance, 6), "beam_pixels": len(coordinates),
                "halo_centroid_distance_px": round(halo_distance, 6),
                "axis_measurement_method": "min-channel-fourth-power-weighted-pca",
                "beam_endpoint_px": np.round(endpoint, 6).tolist(),
                "beam_entity_valid": paid.get("beam"),
                "pass": distance <= 2 and registration["correlation"] > .95
                        and (draft or (index_matches and valid_beam))}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bundle", required=True, type=Path)
    parser.add_argument("--capture", required=True, action="append", help="crown=ARTDIR or facade=ARTDIR; repeat for both")
    parser.add_argument("--draft", action="store_true")
    parser.add_argument("--families", default="all", help="comma-separated family filter for diagnostics")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    evaluator = Evaluator(args.bundle, args.draft)
    rows = []
    capture_modes = {}
    for specification in args.capture:
        emitter, path = specification.split("=", 1)
        if emitter not in ANCHOR_NAMES:
            parser.error("Capture emitter must be crown orfacade")
        root = Path(path)
        samples, capture, capture_file = discover(root)
        if capture_file.exists():
            evaluator.hash(capture_file)
        capture_modes[emitter] = capture.get("channel_view", "all")
        for name, shot, pose, family, lighting, metadata_file in samples:
            if args.families != "all" and family not in args.families.split(","):
                continue
            evaluator.hash(metadata_file)
            row = {"emitter": emitter, "sample": name, "family": family, "lighting": lighting,
                   "torso": pose["torso"], "orientation": pose.get("orientation"),
                   "speed": pose.get("speed"), "shot": str(shot)}
            try:
                row.update(evaluator.measure(shot, pose, emitter, capture, args.draft))
            except (ValueError, FileNotFoundError) as error:
                row.update({"status": "unmeasurable", "reason": str(error), "pass": False})
            rows.append(row)
    coverage = {}
    for emitter in ANCHOR_NAMES:
        coverage[emitter] = {}
        for lighting in ("day", "night"):
            valid = {r["body_index"] for r in rows if r["emitter"] == emitter and r["family"] == "directions128"
                     and r["lighting"] == lighting and r.get("pass") and r.get("isolated")
                     and r.get("exact_endpoint") and r.get("exact_camera") and r.get("body_frame_exact")}
            coverage[emitter][lighting] = {"passed": len(valid), "missing": sorted(set(range(128)) - valid)}
    measured = [r for r in rows if r.get("status") == "measured"]
    complete = all(coverage[emitter][lighting]["passed"] == 128
                   for emitter in ANCHOR_NAMES for lighting in ("day", "night"))
    certified = not args.draft and complete and all(r.get("pass", False) for r in rows)
    report = {"kind": "reference17-two-emitter-alignment", "criterion_px": 2,
              "directions": evaluator.count, "raw_source_directions": evaluator.source_count,
              "indices": "zero-based", "draft": args.draft, "certified": certified,
              "capture_modes": capture_modes, "samples": len(rows), "measured": len(measured),
              "maximum_distance_px": max((r["centerline_distance_px"] for r in measured), default=None),
              "coverage": coverage, "results": rows, "sha256": evaluator.hashes,
              "axis_measurement_method": "min-channel-fourth-power-weighted-pca",
              "scope": "White-core-weighted perpendicular axis alignment against actual displayed raw-body anchors. Asymmetric colored-halo centroids are diagnostic only. Texture taper/occlusion prevents general longitudinal endpoint proof."}
    serialized = json.dumps(report, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(serialized, encoding="utf-8")
    summary = {k: report[k] for k in ("draft", "certified", "samples", "measured", "maximum_distance_px")}
    summary["coverage"] = {emitter: {lighting: value["passed"] for lighting, value in lights.items()}
                           for emitter, lights in coverage.items()}
    print(json.dumps(summary))
    if not args.draft and not certified:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
