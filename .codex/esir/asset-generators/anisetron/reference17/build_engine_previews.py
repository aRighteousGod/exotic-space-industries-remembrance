"""Build review boards and looping GIFs from existing standard engine captures.

This copies/resizes the captured pixels for review. It does not alter the model,
materials, source sprites, engine lighting, or shipping assets.
"""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--art", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    capture_path = args.art / "capture-manifest.json"
    capture = json.loads(capture_path.read_text())
    if capture["channel_view"] != "all" or capture["direction_count"] != 128:
        raise ValueError("Native review requires both visible channels and128-direction shipping art")
    results = []
    hashes = {str(capture_path): hashlib.sha256(capture_path.read_bytes()).hexdigest()}
    for family in ("ring", "motion"):
        metadata = json.loads((args.art / f"{family}-poses.json").read_text())
        if len(metadata) != 24:
            raise ValueError(f"Expected24 {family} frames, received{len(metadata)}")
        for lighting in ("day", "night"):
            shots = [args.art / f"{family}-{lighting}" / f"{frame:03d}.png" for frame in range(1, 25)]
            frames = [Image.open(path).convert("RGB") for path in shots]
            for path in shots:
                hashes[str(path)] = hashlib.sha256(path.read_bytes()).hexdigest()
            cell, caption = 256, 20
            board = Image.new("RGB", (6 * cell, 4 * (cell + caption)), "#111111")
            draw = ImageDraw.Draw(board)
            for index, (frame, pose) in enumerate(zip(frames, metadata)):
                left, top = index % 6 * cell, index // 6 * (cell + caption)
                thumb = frame.resize((cell, cell), Image.Resampling.LANCZOS)
                board.paste(thumb, (left, top + caption))
                label = f"{index+1:02d}  tick {pose.get('tick', '?')}"
                if family == "motion":
                    label += f"  speed {abs(pose['speed']):.3f}"
                draw.text((left + 5, top + 4), label, fill="white")
            board_path = args.output / f"{family}-{lighting}-board.png"
            board.save(board_path)
            # One shared palette avoids palette flicker between engine frames.
            palette = board.quantize(colors=256, method=Image.Quantize.MEDIANCUT)
            gif_frames = []
            for index, frame in enumerate(frames):
                preview = frame.resize((512, 512), Image.Resampling.LANCZOS)
                overlay = ImageDraw.Draw(preview)
                overlay.rectangle((0, 0, 512, 18), fill="#111111")
                overlay.text((6, 4), f"ANISETRON17  {family} / {lighting}   {index+1:02d}/24", fill="white")
                gif_frames.append(preview.quantize(palette=palette, dither=Image.Dither.NONE))
            gif_path = args.output / f"{family}-{lighting}.gif"
            gif_frames[0].save(gif_path, save_all=True, append_images=gif_frames[1:], duration=200,
                               loop=0, optimize=False, disposal=2)
            results.append({"family": family, "lighting": lighting, "frames": 24,
                            "board": str(board_path), "gif": str(gif_path),
                            "gif_resolution": [512, 512], "duration_per_frame_ms": 200,
                            "source_images": [str(path) for path in shots]})
            if family == "motion":
                # Native zoom1 detail crops retain one source pixel per output
                # pixel. Full-context boards/GIFs remain alongside these crops.
                crop_bounds = (224, 232, 544, 552)
                selected = (1, 4, 8, 12, 16, 19, 20, 24)
                details = [frame.crop(crop_bounds) for frame in frames]
                detail_board = Image.new("RGB", (4 * 320, 2 * 340), "#111111")
                label = ImageDraw.Draw(detail_board)
                for number, index in enumerate(selected):
                    x, y = number % 4 * 320, number // 4 * 340
                    detail_board.paste(details[index-1], (x, y + 20))
                    label.text((x + 5, y + 4), f"{index:02d} / native zoom1 / speed {abs(metadata[index-1]['speed']):.3f}", fill="white")
                detail_board_path = args.output / f"motion-{lighting}-detail-board.png"
                detail_board.save(detail_board_path)
                detail_palette = detail_board.quantize(colors=256, method=Image.Quantize.MEDIANCUT)
                detail_frames = [frame.quantize(palette=detail_palette, dither=Image.Dither.NONE) for frame in details]
                detail_gif_path = args.output / f"motion-{lighting}-detail.gif"
                detail_frames[0].save(detail_gif_path, save_all=True, append_images=detail_frames[1:],
                                      duration=200, loop=0, optimize=False, disposal=2)
                results.append({"family": "motion-detail", "lighting": lighting, "frames": 24,
                                "board": str(detail_board_path), "gif": str(detail_gif_path),
                                "gif_resolution": [320, 320], "duration_per_frame_ms": 200,
                                "source_crop": list(crop_bounds), "source_pixels_per_output_pixel": 1,
                                "board_selected_frames": list(selected), "source_images": [str(path) for path in shots]})
    report = {"kind": "reference17-standard-engine-review-previews", "source": str(args.art),
              "fidelity": capture["fidelity"], "capture_manifest": capture,
              "results": results, "source_hashes": hashes,
              "scope": "Review copies of engine captures; GIFs use a shared256-color palette. Detail crops keep native pixels; full-context GIFs resize for compact review."}
    (args.output / "preview-manifest.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"previews": len(results), "boards": len(results), "gifs": len(results),
                      "output": str(args.output)}))


if __name__ == "__main__":
    main()
