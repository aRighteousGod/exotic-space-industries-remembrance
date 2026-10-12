"""Reuse the first opaque WebP bitstream at the final parked endpoint.

No image is recompressed. ANMF fields follow Google's WebP container specification:
https://developers.google.com/speed/webp/docs/riff_container#animation
"""
import hashlib
import io
import json
import struct
from pathlib import Path
from PIL import Image


def seal(payload, size, limit=10_000_000):
    assert payload[:4] == b'RIFF' and payload[8:12] == b'WEBP'
    assert int.from_bytes(payload[4:8], 'little') + 8 == len(payload)
    chunks, offset = [], 12
    while offset < len(payload):
        length = int.from_bytes(payload[offset+4:offset+8], 'little')
        end = offset + 8 + length + length % 2
        assert end <= len(payload)
        chunks.append((payload[offset:offset+4], payload[offset+8:offset+8+length]))
        offset = end
    indices = [i for i, (tag, _) in enumerate(chunks) if tag == b'ANMF']
    first, last = chunks[indices[0]][1], chunks[indices[-1]][1]
    assert first[:6] == b'\x00' * 6
    assert [1+int.from_bytes(first[i:i+3], 'little') for i in (6, 9)] == list(size)
    replacement = bytearray(first)
    replacement[12:15] = last[12:15]
    replacement[15] = 2  # Whole opaque canvas: overwrite, then retain.
    chunks[indices[-1]] = (b'ANMF', bytes(replacement))
    body = b'WEBP' + b''.join(tag + struct.pack('<I', len(data)) + data
                             + (b'\x00' if len(data) % 2 else b'') for tag, data in chunks)
    result = b'RIFF' + struct.pack('<I', len(body)) + body
    assert len(result) < limit
    # Verify every earlier decoded frame, all timings and the new exact endpoint.
    with Image.open(io.BytesIO(payload)) as before, Image.open(io.BytesIO(result)) as after:
        assert before.n_frames == after.n_frames and after.size == tuple(size)
        before.seek(0); first_pixels = before.convert('RGBA').tobytes()
        assert before.convert('RGBA').getchannel('A').getextrema() == (255, 255)
        for i in range(before.n_frames):
            before.seek(i); before.load(); after.seek(i); after.load()
            assert before.info['duration'] == after.info['duration']
            expected = first_pixels if i == before.n_frames-1 else before.convert('RGBA').tobytes()
            assert after.convert('RGBA').tobytes() == expected
    return result


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    args = parser.parse_args()
    report_path = args.directory / 'teaser-report.json'
    report = json.loads(report_path.read_text())
    path = args.directory / report['file']
    payload = path.read_bytes()
    assert hashlib.sha256(payload).hexdigest() == report['sha256']
    sealed = seal(payload, report['size'], report['strict_limit_bytes'])
    path.write_bytes(sealed)
    report.update(bytes=len(sealed), decimal_mb=len(sealed)/1_000_000,
                  sha256=hashlib.sha256(sealed).hexdigest(),
                  loop_endpoint_decoded_identical=True, webp_method=4,
                  loop_seal='first opaque frame bitstream reused at final endpoint; all other decoded frames and timings unchanged')
    report_path.write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps({k: report[k] for k in ('bytes', 'decimal_mb', 'sha256', 'loop_endpoint_decoded_identical')}))
