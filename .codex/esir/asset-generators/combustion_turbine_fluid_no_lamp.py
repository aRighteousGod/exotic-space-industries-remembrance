from pathlib import Path
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[3]
SOURCE_ENTITY_DIR = ROOT / "exotic-space-industries-remembrance-graphics-1" / "graphics" / "entities"
OUTPUT_ENTITY_DIR = ROOT / "exotic-space-industries-remembrance" / "graphics" / "entities"
SOURCE_SHEET = SOURCE_ENTITY_DIR / "combustion-turbine_animation.png"
OUTPUT_SHEET = OUTPUT_ENTITY_DIR / "combustion-turbine-fluid_animation.png"

FRAME_SIZE = 512
LINE_LENGTH = 4
FRAME_COUNT = 16

# The fluid-mode generator has no burner idle-animation slot, so its lamp cannot
# natively change red/green. Keep the mask tight to the lamp unit so nearby wall
# strips and rail details stay intact.
LAMP_BODY_REGION = (378, 335, 442, 405)
LAMP_MASK_POLYGONS = (
    ((386, 335), (407, 335), (438, 348), (439, 371), (427, 386), (392, 386), (381, 376), (382, 350)),
    ((380, 371), (424, 371), (429, 385), (421, 404), (386, 404), (378, 390)),
    ((427, 378), (441, 382), (441, 390), (430, 390), (424, 386)),
)


def is_lamp_color_pixel(r: int, g: int, b: int, a: int) -> bool:
    if a == 0:
        return False

    saturation = max(r, g, b) - min(r, g, b)
    is_green_lamp = g > r + 22 and g > b + 22 and g >= 55
    is_orange_lamp = r > g + 20 and r > b + 20 and r >= 55
    return saturation > 22 or is_green_lamp or is_orange_lamp


def neutral_lamp_color(r: int, g: int, b: int, a: int) -> tuple[int, int, int, int]:
    luminance = int((0.2126 * r) + (0.7152 * g) + (0.0722 * b))
    neutral = max(18, min(94, int(luminance * 0.42)))
    return neutral, neutral, min(108, neutral + 8), a


def remove_lamp_from_frame(sheet: Image.Image, frame_index: int) -> None:
    column = frame_index % LINE_LENGTH
    row = frame_index // LINE_LENGTH
    frame_x = column * FRAME_SIZE
    frame_y = row * FRAME_SIZE

    pixels = sheet.load()
    mask = Image.new("1", (FRAME_SIZE, FRAME_SIZE), 0)
    mask_draw = ImageDraw.Draw(mask)
    for polygon in LAMP_MASK_POLYGONS:
        mask_draw.polygon(polygon, fill=1)
    mask_pixels = mask.load()

    left, top, right, bottom = LAMP_BODY_REGION
    for y in range(top, bottom):
        for x in range(left, right):
            if not mask_pixels[x, y]:
                continue

            absolute_x = frame_x + x
            absolute_y = frame_y + y
            pixel = pixels[absolute_x, absolute_y]
            if is_lamp_color_pixel(*pixel):
                pixels[absolute_x, absolute_y] = neutral_lamp_color(*pixel)


def main() -> None:
    sheet = Image.open(SOURCE_SHEET).convert("RGBA")
    expected_size = (FRAME_SIZE * LINE_LENGTH, FRAME_SIZE * LINE_LENGTH)
    if sheet.size != expected_size:
        raise SystemExit(f"Unexpected sheet size {sheet.size}; expected {expected_size}")

    for frame_index in range(FRAME_COUNT):
        remove_lamp_from_frame(sheet, frame_index)

    OUTPUT_ENTITY_DIR.mkdir(parents=True, exist_ok=True)
    sheet.save(OUTPUT_SHEET, optimize=True)
    print(f"Wrote {OUTPUT_SHEET}")


if __name__ == "__main__":
    main()
