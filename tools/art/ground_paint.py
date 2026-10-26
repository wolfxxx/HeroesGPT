"""Agartha's Subterranean ground (session68): the adventure-map texture and the battlefield backdrop, painted by the
image model over the Dirt ones (their scale, light and composition kept).
python tools/art/ground_paint.py paint [tile|battle]   ->  imagegen/batch41/out/<name>.png
python tools/art/ground_paint.py ingest [tile|battle]  ->  assets/terrain/subterranean.png (512x512, made seamless as
                                                          snow_paint.py), assets/battle/bg_subterranean.png (1920x1080)"""
import os, sys
import numpy as np
from PIL import Image, ImageFilter

sys.path.insert(0, os.path.dirname(__file__))
from snow_paint import seamless

BATCH = "imagegen/batch41"
JOBS = {
    "tile": ("assets/terrain/dirt.png", "1:1", "1K",
             "Paint over this image a seamless top-down ground texture of a cave floor deep under the earth for a fantasy "
             "strategy game's adventure map, seen from straight above: dark grey-violet rock and packed cave earth, "
             "flat worn stone slabs with fine cracks, scattered small pebbles and grit, here and there a tiny patch of "
             "faintly glowing pale-teal moss. Even light from the upper left, the same density of detail everywhere, no "
             "large features, no objects, no mushrooms, no crystals, no holes, no horizon. Hand-painted, crisp and "
             "detailed, the same scale of detail as the original."),
    "battle": ("assets/battle/bg_dirt.png", "16:9", "2K",
               "Repaint this battlefield backdrop of a hand-painted fantasy strategy game as a battlefield deep inside the "
               "Hollow Earth, keeping exactly the same composition: the same camera, the same horizon line, the same "
               "broad open flat ground filling the middle and bottom of the picture (the hex grid is laid over it later, "
               "so it must stay open, even and free of obstacles). The ground: a dark grey-violet cavern floor of worn "
               "rock and packed earth with a few patches of faintly glowing pale-teal moss and small pebbles. Along the "
               "horizon at the top: a vast cavern, distant cliffs with glowing violet crystal veins, a few giant "
               "mushrooms and stalagmites far off, the cavern lit warm amber by a small bright golden inner sun high in "
               "a hazy sky (a bright warm orb of light, never dark, no rays or wheel). Hand-painted style, rich colours, "
               "light from the upper left. No units, no people, no text."),
}


def paint(names):
    import vertex_paint as vp
    from google import genai
    client = genai.Client(vertexai=True, project=vp.PROJECT, location=vp.LOCATION)
    os.makedirs(f"{BATCH}/in", exist_ok=True)
    os.makedirs(f"{BATCH}/out", exist_ok=True)
    for name in names:
        src, ratio, size, prompt = JOBS[name]
        im = Image.open(src).convert("RGB")
        im.resize((1024, 1024) if name == "tile" else (1920, 1080), Image.LANCZOS).save(f"{BATCH}/in/{name}.png")
        img = vp.paint(client, "gemini-nano-banana-2.1", f"{BATCH}/in/{name}.png", prompt, ratio, size)
        if img:
            img.save(f"{BATCH}/out/{name}.png")
            print("done", name, img.size, flush=True)
        else:
            print("FAILED", name, flush=True)


def ingest(names):
    for name in names:
        src = f"{BATCH}/out/{name}.png"
        if not os.path.exists(src):
            continue
        if name == "tile":
            a = np.asarray(Image.open(src).convert("RGB").resize((1024, 1024), Image.LANCZOS), np.float32)
            Image.fromarray(np.clip(seamless(a), 0, 255).astype(np.uint8)).resize((512, 512), Image.LANCZOS) \
                .filter(ImageFilter.UnsharpMask(1.2, 60, 2)).save("assets/terrain/subterranean.png")
            print("  terrain/subterranean.png")
        else:
            Image.open(src).convert("RGB").resize((1920, 1080), Image.LANCZOS).save("assets/battle/bg_subterranean.png")
            print("  battle/bg_subterranean.png")


if __name__ == "__main__":
    {"paint": paint, "ingest": ingest}[sys.argv[1]](sys.argv[2:] or list(JOBS))
