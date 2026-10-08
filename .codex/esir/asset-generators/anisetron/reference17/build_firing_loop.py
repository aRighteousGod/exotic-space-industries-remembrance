"""Build ANISETRON audio from the CC0 Lance body; writes ignored output only.

Replay from the repo root:
  python -B .codex/esir/asset-generators/anisetron/reference17/build_firing_loop.py
Requires the already installed numpy and imageio_ffmpeg. No network or paid API.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import wave
from pathlib import Path

import imageio_ffmpeg
import numpy as np


RATE = 44100
CHANNELS = 2
DURATION = 3.2
HOP = 4410  # 100ms; 32 overlaps make the exact 3.2s circular output.
GRAIN = HOP * 2
BODY_START = 0.075
SEED = 170128


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def ffmpeg(*arguments: str, input_bytes: bytes | None = None) -> bytes:
    process = subprocess.run(
        [imageio_ffmpeg.get_ffmpeg_exe(), "-hide_banner", "-loglevel", "error", *arguments],
        input=input_bytes, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False,
    )
    if process.returncode:
        raise RuntimeError(process.stderr.decode("utf-8", errors="replace"))
    return process.stdout


def decode(path: Path) -> np.ndarray:
    raw = ffmpeg("-i", str(path), "-f", "f32le", "-ac", str(CHANNELS), "-ar", str(RATE), "-")
    return np.frombuffer(raw, dtype="<f4").reshape(-1, CHANNELS).astype(np.float64)


def carrier(samples: np.ndarray, salt: int) -> np.ndarray:
    body = samples[round(BODY_START * RATE):round(BODY_START * RATE) + GRAIN].copy()
    if len(body) != GRAIN:
        raise ValueError("Lance body is shorter than the selected middle grain")
    body -= body.mean(axis=0)
    length = round(RATE * DURATION)
    result = np.zeros((length, CHANNELS), dtype=np.float64)
    weights = np.zeros(length, dtype=np.float64)
    window = .5 - .5 * np.cos(2 * np.pi * np.arange(GRAIN) / GRAIN)
    rng = np.random.default_rng(SEED + salt)
    shifts = rng.integers(0, GRAIN, size=length // HOP)
    for index, shift in enumerate(shifts):
        destination = (index * HOP + np.arange(GRAIN)) % length
        result[destination] += np.roll(body, int(shift), axis=0) * window[:, None]
        weights[destination] += window
    return result / weights[:, None]


def metrics(samples: np.ndarray) -> dict:
    delta = np.diff(samples, axis=0)
    join = samples[0] - samples[-1]
    percentile = float(np.percentile(np.abs(delta), 99))
    count = len(samples)
    hop = round(.020 * RATE)
    rms20 = [float(np.sqrt(np.mean(samples[index:index + hop] ** 2)))
             for index in range(0, count, hop)]
    return {
        "samples": count, "duration_seconds": count / RATE,
        "peak": float(np.max(np.abs(samples))),
        "rms": float(np.sqrt(np.mean(samples ** 2))),
        "dc_by_channel": samples.mean(axis=0).tolist(),
        "clipped_samples_abs_ge_1": int(np.count_nonzero(np.abs(samples) >= 1)),
        "join_step_by_channel": join.tolist(),
        "join_step_max": float(np.max(np.abs(join))),
        "ordinary_step_abs_p99": percentile,
        "join_to_p99_ratio": float(np.max(np.abs(join))) / max(percentile, 1e-12),
        "rms20ms_min": min(rms20), "rms20ms_max": max(rms20),
        "rms20ms_by_block": rms20,
    }


def wav(path: Path, samples: np.ndarray) -> None:
    pcm = np.rint(np.clip(samples, -.999969, .999969) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as stream:
        stream.setnchannels(CHANNELS)
        stream.setsampwidth(2)
        stream.setframerate(RATE)
        stream.writeframes(pcm.tobytes())


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=Path.cwd())
    parser.add_argument("--output", type=Path, default=Path("output/meshy/anisetron/reference17/audio"))
    args = parser.parse_args()
    repo = args.repo.resolve()
    output = args.output.resolve()
    allowed = (repo / "output/meshy/anisetron/reference17").resolve()
    if not output.is_relative_to(allowed):
        raise ValueError("Audio output must remain under output/meshy/anisetron/reference17")
    output.mkdir(parents=True, exist_ok=True)
    paths = [repo / "exotic-space-industries-remembrance-graphics-4/sounds" /
             f"singularity-lance-beam-{index}.ogg" for index in (2, 3)]
    sources = [decode(path) for path in paths]
    low, high = [carrier(samples, salt) for samples, salt in zip(sources, (2, 3))]
    phase = np.arange(len(low)) / len(low) * 2 * np.pi
    low_gain = .72 + .06 * np.cos(phase)
    high_gain = .28 - .06 * np.cos(phase)
    mixed = low * low_gain[:, None] + high * high_gain[:, None]
    mixed -= mixed.mean(axis=0)
    mixed *= .70 / np.max(np.abs(mixed))
    # Rotate to the smallest stereo seam within naturally low-amplitude samples.
    # Circular overlap-add has already blended the wrap; this changes phase only.
    steps = mixed - np.roll(mixed, 1, axis=0)
    cost = np.max(np.abs(steps), axis=1) + .1 * np.max(np.abs(mixed), axis=1)
    offset = int(np.argmin(cost))
    mixed = np.roll(mixed, -offset, axis=0)
    master = output / "anisetron-firing-loop-master.wav"
    encoded = output / "anisetron-firing-loop.ogg"
    wav(master, mixed)
    encoding = ("-fflags", "+bitexact", "-flags:a", "+bitexact", "-c:a", "libvorbis", "-q:a", "7")
    ffmpeg("-y", "-i", str(master), *encoding, str(encoded))
    decoded = decode(encoded)
    preview = np.tile(decoded, (6, 1))  # 19.2s, five joins, no artificial attacks.
    preview_wav = output / "anisetron-firing-loop-six-loops.wav"
    preview_ogg = output / "anisetron-firing-loop-six-loops.ogg"
    wav(preview_wav, preview)
    ffmpeg("-y", "-i", str(preview_wav), *encoding, str(preview_ogg))
    measured = metrics(decoded)
    accepted = (len(decoded) == round(RATE * DURATION)
                and measured["clipped_samples_abs_ge_1"] == 0
                and measured["peak"] < .9 and measured["join_to_p99_ratio"] < .25)
    dossier = {
        "draft_only": True, "recipe_version": 1,
        "source_license": {
            "text": "Pulsar.wav by wcoltd; Creative Commons 0",
            "url": "https://freesound.org/s/440783/",
            "repo_attribution": "exotic-space-industries-remembrance-graphics-4/sounds/singularity-lance-beam attribution.txt",
        },
        "sources": [{"path": path.relative_to(repo).as_posix(), "sha256": sha256(path),
                     "decoded_seconds": len(samples) / RATE}
                    for path, samples in zip(paths, sources)],
        "mix": {"sample_rate": RATE, "channels": CHANNELS, "duration_seconds": DURATION,
                "grain_body_seconds": [BODY_START, BODY_START + GRAIN / RATE],
                "grain_seconds": GRAIN / RATE, "hop_seconds": HOP / RATE,
                "overlap": "50 percent Hann circular overlap-add; no original onset/tail retrigger",
                "lower_gain": ".72 + .06*cos(one cycle)", "higher_gain": ".28 - .06*cos(one cycle)",
                "pitch_resampling": False, "peak_normalization": .70,
                "phase_rotation_samples": offset, "deterministic_seed": SEED},
        "pcm_master": metrics(mixed), "decoded_ogg": measured,
        "proof": {"pass": accepted, "joins_in_preview": 5,
                  "measurement_scope": "Decoded offline waveform; not audible Factorio loop, mixing or spatial playback proof"},
        "outputs": [{"path": path.relative_to(repo).as_posix(), "sha256": sha256(path),
                    "bytes": path.stat().st_size} for path in (master, encoded, preview_wav, preview_ogg)],
        "replay": "python -B .codex/esir/asset-generators/anisetron/reference17/build_firing_loop.py",
        "generator": {"path": Path(__file__).resolve().relative_to(repo).as_posix(),
                      "sha256": sha256(Path(__file__)), "encoding_arguments": list(encoding)},
        "tool": {"ffmpeg": imageio_ffmpeg.get_ffmpeg_exe(), "numpy": np.__version__},
    }
    (output / "audio-dossier.json").write_text(json.dumps(dossier, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"pass": accepted, "dossier": str(output / "audio-dossier.json"),
                      "loop": str(encoded), "preview": str(preview_ogg),
                      "decoded_peak": measured["peak"], "join_step": measured["join_step_max"],
                      "join_to_p99_ratio": measured["join_to_p99_ratio"]}, indent=2))
    if not accepted:
        raise SystemExit("Offline waveform QC failed; retain draft for inspection")


if __name__ == "__main__":
    main()
