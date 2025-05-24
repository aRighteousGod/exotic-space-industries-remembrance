from PIL import Image

# Parameters
frame_size = (32, 32)
frames = [
    (220, 40, 40, int(0.05 * 255)),   # ember fade-in
    (220, 40, 40, int(0.10 * 255)),   # peak ember
    (220, 40, 40, int(0.07 * 255)),   # soften
    (220, 40, 40, int(0.03 * 255)),   # smoldering low
]

# Create final image (width = 4 frames)
sheet_width = frame_size[0] * len(frames)
sheet_height = frame_size[1]
spritesheet = Image.new("RGBA", (sheet_width, sheet_height), (0, 0, 0, 0))

# Draw each frame
for i, rgba in enumerate(frames):
    frame = Image.new("RGBA", frame_size, rgba)
    spritesheet.paste(frame, (i * frame_size[0], 0))

# Save output
spritesheet.save("glow-pulse-4.png")
print("Saved glow-pulse-4.png")
