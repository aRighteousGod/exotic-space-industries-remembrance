from PIL import Image
import os

def generate_mipmaps(input_path, output_path=None):
    base_image = Image.open(input_path).convert("RGBA")
    mip_sizes = [512, 256, 128, 64, 32]

    mipmaps = [base_image.resize((size, size), Image.LANCZOS) for size in mip_sizes]

    total_width = sum(mipmap.width for mipmap in mipmaps)
    height = base_image.height
    combined = Image.new("RGBA", (total_width, height))

    x_offset = 0
    for mipmap in mipmaps:
        combined.paste(mipmap, (x_offset, 0))
        x_offset += mipmap.width

    if output_path is None:
        base_name, ext = os.path.splitext(input_path)
        output_path = f"{base_name}_mip.png"

    combined.save(output_path)
    print(f"Saved mipmap strip as '{output_path}'.")

generate_mipmaps('ceramic.png')
generate_mipmaps('ceramic-2.png')
generate_mipmaps('ceramic-3.png')
