"""Repo-owned ESIR portal inventory, capture, composition and page assembly."""
from __future__ import annotations

import argparse
import hashlib
import html
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
from datetime import datetime, timezone

from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[2]
PACK = ROOT / "exotic-space-industries-remembrance"
OUT = ROOT / "output/portal-media"
INTERNAL_MODELS = {"admin-runtime-registry", "camera-windows", "runtime-orchestration", "shared-runtime-helpers", "runtime-scheduler", "startup-and-integration"}


def read(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))


def write(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def digest(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def local(path):
    resolved = (ROOT / path).resolve()
    if not resolved.is_relative_to(ROOT):
        raise ValueError(f"Path outside repository: {path}")
    return resolved


def stamp():
    return datetime.now(timezone.utc).isoformat()


def feature_sources(feature):
    found = set()
    for model in [feature.get("model"), *feature.get("extra_models", [])]:
        if not model:
            continue
        path = ROOT / f".codex/esir/blueprints/{model}.md"
        if not path.is_file():
            raise ValueError(f"Missing model: {path}")
        found.add(path)
        text = path.read_text(encoding="utf-8-sig")
        section = text.split("## Implementation sources", 1)[-1].split("\n## ", 1)[0]
        for match in re.findall(r"\]\(([^)#]+)(?:#[^)]*)?\)", section):
            source = (path.parent / match).resolve()
            if source.is_file() and source.is_relative_to(ROOT):
                found.add(source)
    for root in feature.get("source_roots", []):
        path = local(root)
        if not path.exists():
            raise ValueError(f"Missing feature source: {root}")
        found.update(path.rglob("*.lua") if path.is_dir() else [path])
    return sorted(found)


def inventory(features, save=False):
    mappings = {}
    feature_rows = []
    for feature in features:
        sources = feature_sources(feature)
        source_rows=[{"path": p.relative_to(ROOT).as_posix(), "sha256": digest(p)} for p in sources]
        published_receipt=ROOT/"portal/media"/f"{feature['id']}.json"
        accepted=read(published_receipt) if published_receipt.exists() else {}
        fresh=bool(accepted and accepted.get("feature_sources")==source_rows)
        feature_rows.append({"id": feature["id"], "status": feature["status"],
            "origin": feature.get("origin", "origin-unresolved"),
            "sources": source_rows,
            "behavior_review": "native-capture-verified" if fresh and accepted.get("evidence",{}).get("pass") else "pending",
            "editorial_review":accepted.get("review",{}).get("status","pending") if fresh else "pending"})
        for path in sources:
            mappings.setdefault(path, []).append(feature["id"])
    rows = []
    for path in sorted(PACK.rglob("*.lua")):
        text = path.read_text(encoding="utf-8-sig")
        match = re.search(r"-- blueprint: .*?/([^/#]+)\.md#", text)
        internal = bool(match and match[1] in INTERNAL_MODELS)
        ids = mappings.get(path, [])
        classification = "represented-needs-review" if ids else ("supporting-implementation" if internal else "needs-review")
        rows.append({"path": path.relative_to(ROOT).as_posix(), "sha256": digest(path), "classification": classification, "features": ids})
    result = {"schema_version": 1, "generated_at": stamp(), "coverage_complete": False,
        "note": "File coverage is not feature acceptance. Broad age groups need splitting during their content review.",
        "feature_count": len(features), "source_count": len(rows),
        "unmapped_count": sum(r["classification"] == "needs-review" for r in rows),
        "features": feature_rows, "sources": rows}
    if save:
        write(ROOT / "portal/coverage.json", result)
    return result


def capture_fingerprint(batch):
    h = hashlib.sha256(json.dumps(batch, sort_keys=True).encode())
    files = [p for p in PACK.rglob("*") if p.is_file() and p.suffix in {".lua", ".cfg", ".json"}]
    files += list((ROOT / "scripts/portal-media/native").rglob("*"))
    files += [ROOT / "scripts/invoke-portal-capture.ps1", ROOT / "scripts/portal-media/pack_media.py", ROOT / "scripts/portal-media/window.ps1", local(batch["save_input"])]
    files += list((ROOT / ".factorio-qc/fmqc/mods-live").glob("*.zip"))
    files += [ROOT / ".factorio-qc/fmqc/mods-live/mod-list.json"]
    for path in sorted(p for p in files if p.is_file()):
        h.update(path.relative_to(ROOT).as_posix().encode()); h.update(digest(path).encode())
    for source in sorted(ROOT.glob("exotic-space-industries-remembrance-graphics-*")):
        for path in sorted(p for p in source.rglob("*") if p.is_file()):
            h.update(f"{path.relative_to(ROOT)}:{path.stat().st_size}:{path.stat().st_mtime_ns}".encode())
    return h.hexdigest()


def state_path(batch):
    return OUT / batch["id"] / "state.json"


def capture(batch):
    identity = capture_fingerprint(batch)
    path = state_path(batch)
    if path.exists():
        old = read(path)
        report_path = local(old["capture_root"]) / "script-output/portal/report.json"
        if old.get("capture_fingerprint") == identity and report_path.exists():
            report = read(report_path)
            if report.get("complete") and report.get("connected") and not report.get("probe") and report.get("frames") and all((report_path.parent / f["path"]).is_file() for f in report["frames"]):
                return {"overall_status": "ok", "reused": True, **old}
    command = ["powershell", "-ExecutionPolicy", "Bypass", "-File", str(ROOT / "scripts/invoke-portal-capture.ps1"), "-Scene", batch["scene"], "-SaveInput", str(local(batch["save_input"]))]
    command += ["-Width",str(batch["capture_resolution"][0]),"-Height",str(batch["capture_resolution"][1])]
    process = subprocess.run(command, cwd=ROOT, text=True, capture_output=True)
    if process.returncode:
        raise RuntimeError(process.stdout[-5000:] + process.stderr[-2000:])
    result = json.loads(process.stdout[process.stdout.index("{"):])
    if capture_fingerprint(batch) != identity:
        raise RuntimeError("Source changed during capture; result retained but not reusable")
    state = {"capture_fingerprint": identity, "capture_root": Path(result["path"]).relative_to(ROOT).as_posix(), "capture_run_id": result["run_id"], "captured_at": stamp()}
    write(path, state)
    return {"overall_status": "ok", **state}


def load_capture(batch):
    state = read(state_path(batch))
    if state["capture_fingerprint"] != capture_fingerprint(batch):
        raise ValueError("Native captures are stale; rerun portal-capture")
    directory = local(state["capture_root"]) / "script-output/portal"
    report = read(directory / "report.json")
    if not report.get("complete") or report.get("probe") or not report.get("connected"):
        raise ValueError("Native report is incomplete")
    return state, directory, report


def fitted_text(draw, text, font_path, size, box_width):
    font = ImageFont.truetype(font_path, size)
    while draw.textlength(text, font=font) > box_width and size > 22:
        size -= 1; font = ImageFont.truetype(font_path, size)
    if draw.textlength(text, font=font) > box_width:
        raise ValueError(f"Caption too long: {text}")
    return font


def compose(source, feature, frame, style):
    image = Image.new("RGB", (style["width"], style["height"]), style["background"])
    draw = ImageDraw.Draw(image)
    width, height = image.size
    top, bottom = style["header_height"], height - style["footer_height"]
    with Image.open(source) as captured:
        view = captured.convert("RGB")
    crop=frame.get("crop") or (feature.get("gui_crop") if frame.get("gui") else None)
    if crop:
        left,upper,right,lower=crop
        if not (0<=left<right<=view.width and 0<=upper<lower<=view.height):
            raise ValueError(f"Crop is outside the native capture: {feature['id']}")
        view = view.crop(crop)
    elif not frame.get("gui"):
        view = ImageOps.fit(view,(width,bottom-top),Image.Resampling.LANCZOS)
    view = ImageOps.contain(view, (width, bottom-top), Image.Resampling.LANCZOS)
    image.paste(view, ((width-view.width)//2, top+(bottom-top-view.height)//2))
    draw.rectangle((0, top-4, width, top-1), fill=style["accent"])
    title = fitted_text(draw, feature["title"], style["font_bold"], style["title_size"], width-80)
    draw.text((32,18), feature["title"], font=title, fill=style["text"])
    caption = frame["caption"]
    font = fitted_text(draw, caption, style["font_regular"], style["caption_size"], width-64)
    draw.text((32,bottom+14), caption, font=font, fill=style["text"])
    if frame.get("speed", 1) != 1 or frame.get("reading_hold"):
        speed_label = "Paused for reading" if frame.get("reading_hold") else f"Time-lapse | {frame['speed']:g}x speed"
        font = ImageFont.truetype(style["font_regular"], 24)
        draw.rectangle((width-325,top+12,width-16,top+52), fill=style["background"])
        draw.text((width-313,top+18), speed_label, font=font, fill=style["accent"])
    return image


def render(batch, features, style):
    state, directory, report = load_capture(batch)
    output = OUT / batch["id"] / "candidate"
    output.mkdir(parents=True, exist_ok=True)
    feature_map = {f["id"]: f for f in features}
    receipts = []
    for feature_id in batch["features"]:
        feature = feature_map[feature_id]
        frames = [f for f in report["frames"] if f["feature"] == feature_id]
        evidence = report["evidence"].get(feature_id, {})
        if not frames or not evidence.get("pass"):
            raise ValueError(f"Missing or failed native evidence: {feature_id}: {evidence}")
        images, durations = [], []
        sources = []
        gui_elapsed=0
        for frame in frames:
            source = (directory / frame["path"]).resolve()
            if not source.is_relative_to(directory):
                raise ValueError("Capture frame escapes its run")
            display_frame=dict(frame)
            if frame.get("gui"):
                for view in feature.get("gui_views",[]):
                    if gui_elapsed>=view.get("at_ms",0) and view.get("match_caption","") in frame["caption"]:
                        display_frame["crop"]=view["crop"]
                        display_frame["caption"]=view.get("caption",frame["caption"])
                gui_elapsed+=frame["duration_ms"]
            else:
                gui_elapsed=0
            images.append(compose(source, feature, display_frame, style))
            durations.append(frame["duration_ms"])
            sources.append({"path": frame["path"], "sha256": digest(source), "tick": frame["tick"]})
        target = output / f"{feature_id}.webp"
        images[0].save(target, "WEBP", save_all=True, append_images=images[1:], duration=durations, loop=0,
            quality=style["webp_quality"], method=style["webp_method"])
        images[0].save(output / f"{feature_id}.poster.webp", "WEBP", quality=90, method=4)
        sheet = Image.new("RGB", (960,540), style["background"])
        for index in range(6):
            selected = round(index*(len(images)-1)/5)
            thumb = images[selected].resize((320,180),Image.Resampling.LANCZOS)
            sheet.paste(thumb, ((index%3)*320,(index//3)*180))
        sheet.save(output / f"{feature_id}.contact.jpg", quality=90)
        receipt = {"schema_version":1, "feature":feature_id, "created_at":stamp(), "capture":state,
            "environment":{"engine_version":"2.0.77","mod_versions":report["mods"],
                "startup_settings":report["startup_settings"],"capture_resolution":report["resolution"],"ui_scale":report["scale"]},
            "native_report_sha256":digest(directory/"report.json"),
            "feature_sources":[{"path":p.relative_to(ROOT).as_posix(),"sha256":digest(p)} for p in feature_sources(feature)],
            "source_frames":sources, "evidence":evidence, "file_sha256":digest(target), "bytes":target.stat().st_size,
            "intended_duration_ms":sum(durations), "source_frame_count":len(images),
            "style_sha256":digest(ROOT/"portal/style.json"), "renderer_sha256":digest(__file__),
            "feature_sha256":hashlib.sha256(json.dumps(feature,sort_keys=True).encode()).hexdigest(),
            "review":{"status":"pending"}, "portal_preview":"unverified"}
        write(output / f"{feature_id}.json", receipt)
        receipts.append({"id":feature_id,"bytes":receipt["bytes"],"duration_ms":sum(durations)})
    return {"overall_status":"ok", "media":receipts, "total_bytes":sum(r["bytes"] for r in receipts)}


def validate(batch, features, style):
    state, directory, report = load_capture(batch)
    output = OUT / batch["id"] / "candidate"
    rows = []
    for feature_id in batch["features"]:
        receipt = read(output / f"{feature_id}.json")
        if receipt["capture"] != state:
            raise ValueError(f"Export belongs to an older capture: {feature_id}")
        for source in receipt["source_frames"]:
            path = (directory / source["path"]).resolve()
            if not path.is_relative_to(directory) or digest(path) != source["sha256"]:
                raise ValueError(f"Missing or changed source frame: {feature_id}")
        path = output / f"{feature_id}.webp"
        if digest(path) != receipt["file_sha256"] or receipt["style_sha256"] != digest(ROOT/"portal/style.json") or receipt["renderer_sha256"] != digest(__file__):
            raise ValueError(f"Stale or changed export: {feature_id}")
        feature = next(f for f in features if f["id"] == feature_id)
        if receipt["feature_sha256"] != hashlib.sha256(json.dumps(feature,sort_keys=True).encode()).hexdigest():
            raise ValueError(f"Copy changed after export: {feature_id}")
        duration = 0
        with Image.open(path) as image:
            if image.size != (style["width"],style["height"]) or image.n_frames < 2:
                raise ValueError(f"Invalid animated output: {feature_id}")
            for frame in range(image.n_frames):
                image.seek(frame);image.load();duration += image.info["duration"]
            count = image.n_frames
        if abs(duration-receipt["intended_duration_ms"]) > 10:
            raise ValueError(f"Playback timing changed: {feature_id}")
        if not 10000 <= duration <= 20000:
            raise ValueError(f"Pilot duration is outside 10-20 seconds: {feature_id}")
        if not report["evidence"][feature_id]["pass"]:
            raise ValueError(f"Failed native evidence: {feature_id}")
        rows.append({"id":feature_id,"frames":count,"duration_ms":duration,"bytes":path.stat().st_size,
                     "editorial_review":receipt["review"]["status"]})
    result = {"overall_status":"ok","checked_at":stamp(),"media":rows,"total_bytes":sum(r["bytes"] for r in rows),"portal_preview":"unverified"}
    write(OUT/batch["id"]/"validation.json",result)
    return result


def page(batch, features, content):
    validate(batch, features, read(ROOT/"portal/style.json"))
    output = OUT/batch["id"]
    output.mkdir(parents=True,exist_ok=True)
    candidate = output/"candidate"
    markdown = [f"# {content['title']}",content["introduction"],content["requirements"]]
    navigation = " · ".join(f"[{c['title']}](#{c['id']})" for c in content["categories"])
    markdown.append(navigation)
    review_cards = []
    included = []
    for category in content["categories"]:
        section = []
        introduction=category.get("introduction", "")
        review_cards.append(f'<div id="{html.escape(category["id"])}"><h2>{html.escape(category["title"])}</h2><p>{html.escape(introduction)}</p>')
        for feature in features:
            if feature["category"] != category["id"]:
                continue
            feature_id=feature["id"]
            source_dir=candidate
            path=source_dir/f"{feature_id}.json"
            if not path.exists():
                source_dir=ROOT/"portal/media"
                path=source_dir/f"{feature_id}.json"
            if not path.exists():
                continue
            receipt=read(path)
            media_path=source_dir/f"{feature_id}.webp"
            if digest(media_path)!=receipt["file_sha256"]:
                raise ValueError(f"Changed reviewed media: {feature_id}")
            description=feature.get("summary", "")+" "+feature.get("detail", "")
            review_src=Path(os.path.relpath(media_path,output)).as_posix()
            review_cards.append(f'<section id="{html.escape(feature_id)}"><h2>{html.escape(feature["title"])}</h2><img src="{html.escape(review_src)}" alt="{html.escape(description)}"><p>{html.escape(description)}</p><small>Review: {html.escape(receipt["review"]["status"])} · {receipt["bytes"]/1048576:.2f} MiB · Portal preview unverified</small></section>')
            if receipt["review"]["status"] != "reviewed":
                continue
            media=ROOT/"portal/media"
            media.mkdir(parents=True,exist_ok=True)
            if source_dir!=media:
                for suffix in [".webp",".poster.webp",".json"]:
                    shutil.copy2(source_dir/(feature_id+suffix),media/(feature_id+suffix))
            section += [f"### {feature['title']}",f"![{feature['summary']}]({content['media_base_url']}{feature_id}.webp)",description]
            included.append(feature_id)
        markdown += [f'<a id="{category["id"]}"></a>',f"## {category['title']}",introduction,*section]
        review_cards.append('</div>')
    for section in content["closing"]:
        markdown += [f"## {section['title']}",section["text"]]
        review_cards.append(f'<h2>{html.escape(section["title"])}</h2><p>{html.escape(section["text"])}</p>')
    markdown.append("\n".join(f"- [{label}]({url})" for label,url in content["links"].items()))
    (ROOT/"portal/MOD_PORTAL.md").write_text("\n\n".join(markdown)+"\n",encoding="utf-8")
    (ROOT/"portal/SUMMARY.txt").write_text(content["summary"]+"\n",encoding="utf-8")
    pending=[f for f in features if f["id"] not in included]
    queue="".join(f'<li>{html.escape(f["title"])} — {html.escape(f["status"])}</li>' for f in pending)
    document='<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>ESIR portal review</title><style>body{background:#171918;color:#eee;font:17px/1.6 system-ui;margin:0}main{max-width:800px;margin:40px auto;padding:0 20px}h1,h2{line-height:1.2}section{margin:48px 0}img{max-width:100%;height:auto;display:block}a{color:#edb85d}small{color:#bdc3be}.notice{border-left:3px solid #edb85d;padding:12px 20px;background:#252928}button{padding:10px}</style><main>'
    document+=f'<h1>{html.escape(content["title"])}</h1><p class="notice">Local draft. Native demonstrations are development-build captures. Publication and actual Portal WebP preview have not been performed.</p><p>{html.escape(content["introduction"])}</p><p>{html.escape(content["requirements"])}</p>'
    document+='<button onclick="document.querySelectorAll(\'section img\').forEach(i=>{i.src=i.src.includes(\'.poster.\')?i.src.replace(\'.poster.\',\'.\'):i.src.replace(\'.webp\',\'.poster.webp\')})">Toggle still / animation</button>'
    document+=''.join(review_cards)+f'<details><summary>Remaining catalogue ({len(pending)} entries)</summary><ul>{queue}</ul></details></main></html>'
    (output/"index.html").write_text(document,encoding="utf-8")
    return {"overall_status":"ok","preview":str(output/"index.html"),"reviewed_features":included,"pending_count":len(pending)}


def review(batch, features, style, review_file):
    """Record a completed visual review; never infer review from validation."""
    validate(batch, features, style)
    record = read(local(review_file))
    if record.get("batch") != batch["id"] or not record.get("reviewer"):
        raise ValueError("Review must identify its batch and reviewer")
    directory = OUT / batch["id"] / "candidate"
    for feature_id in batch["features"]:
        item = record["features"][feature_id]
        receipt_path = directory / f"{feature_id}.json"
        receipt = read(receipt_path)
        if item.get("sha256") != receipt["file_sha256"] or not item.get("notes") or item.get("status") not in {"reviewed", "needs-revision"}:
            raise ValueError(f"Review is missing, incomplete or stale: {feature_id}")
    for feature_id in batch["features"]:
        receipt_path = directory / f"{feature_id}.json"
        receipt = read(receipt_path)
        receipt["review"] = {**record["features"][feature_id], "reviewer": record["reviewer"], "recorded_at": stamp()}
        write(receipt_path, receipt)
    return {"overall_status": "ok", "review": review_file}


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("operation",choices=["plan","capture","render","validate","page","inventory","review"])
    parser.add_argument("--batch",default="portal/batches/001-pilots.json")
    parser.add_argument("--review-file")
    args=parser.parse_args()
    batch=read(local(args.batch));features=read(ROOT/"portal/features.json")["features"]
    style=read(ROOT/"portal/style.json");content=read(ROOT/"portal/content.json")
    ids=[f["id"] for f in features]
    if len(ids)!=len(set(ids)) or len(batch["features"])!=len(set(batch["features"])) or set(batch["features"])-set(ids):
        raise ValueError("Duplicate or unknown feature ID")
    if not re.fullmatch(r"[a-z0-9-]+",batch["id"]):
        raise ValueError("Invalid batch ID")
    if len(content["summary"])>500:
        raise ValueError("Listing summary exceeds 500 characters")
    if batch.get("capture_scale") != 1:
        raise ValueError("This capture driver requires native UI scale 1")
    if args.operation in {"plan","inventory"}:
        coverage=inventory(features,save=args.operation=="inventory")
        result={"overall_status":"ok","features":batch["features"],"catalogue_count":len(features),"unmapped_sources":coverage["unmapped_count"],"capture_fingerprint":capture_fingerprint(batch),"seed_exists":local(batch["save_input"]).exists(),"publication":"local-draft"}
    elif args.operation=="capture":result=capture(batch)
    elif args.operation=="render":result=render(batch,features,style)
    elif args.operation=="validate":result=validate(batch,features,style)
    elif args.operation=="review":
        if not args.review_file:raise ValueError("review requires --review-file with completed visual review notes and matching hashes")
        result=review(batch,features,style,args.review_file)
    else:result=page(batch,features,content)
    print(json.dumps(result,ensure_ascii=True,indent=2))


if __name__=="__main__":
    try:main()
    except Exception as error:
        print(json.dumps({"overall_status":"failed","error":str(error)},ensure_ascii=True),file=sys.stderr)
        sys.exit(1)
