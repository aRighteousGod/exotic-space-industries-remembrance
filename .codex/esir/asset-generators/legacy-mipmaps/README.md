# Legacy Graphics-3 mipmap generators

These original development scripts were moved out of Graphics 3 on 2026-10-28
because executable files cannot ship in a Mod Portal package. Their contents are
unchanged. They are retained tooling, not part of any mod archive.

- `generate_icon_mip.py`: formerly `graphics/icons/generate_mip.py`; reads
  `gatling-turret.png` from the current working directory.
- `generate_technology_mip.py`: formerly `graphics/tech/generate_mip.py`; reads
  `advanced-cargo-wagon.png` from the current working directory.

Both require Pillow and write a `_mip.png` beside the input. Use a scratch working
directory with a copy of the intended input, and run with `python -B` to avoid
creating bytecode caches. They retain their historical fixed mip sizes; inspect
the output before promoting any generated image into a shipping pack.
