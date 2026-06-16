# Offshore Pump Cap Mask

Generates transparent, cap-only overlay masks from frame 0 of Factorio's vanilla offshore pump body sheets.

Outputs:
- `exotic-space-industries-remembrance-graphics-4/graphics/entities/offshore-pump/offshore-pump-cap-mask-North.png`
- `exotic-space-industries-remembrance-graphics-4/graphics/entities/offshore-pump/offshore-pump-cap-mask-East.png`
- `exotic-space-industries-remembrance-graphics-4/graphics/entities/offshore-pump/offshore-pump-cap-mask-South.png`
- `exotic-space-industries-remembrance-graphics-4/graphics/entities/offshore-pump/offshore-pump-cap-mask-West.png`

Preview:
- `output/offshore-pump-cap-mask/offshore-pump-cap-mask-preview.png`

Run from the repo root:

```powershell
python .codex/esir/asset-generators/offshore-pump-cap-mask/generate_offshore_pump_cap_mask.py
```

The masks are intended as fixed-tint overlay layers for burner and steam offshore pump variants. They use one static frame per direction and are repeated over the vanilla 32-frame pump animation.
