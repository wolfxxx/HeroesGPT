"""Adventure-map objects repainted as other objects of the secret-history setting (docs/SETTING.md): the Shrine of
Magic as a stone circle, the Watchtower as an observatory. The existing sprite is the reference for viewpoint, size and
light; the new object is painted on magenta, keyed out, fitted into the old figure's box standing on its foot point,
and given a synthetic cast shadow, on the old sprite's canvas (so the map places and sizes it as before).
python tools/art/map_object_paint.py prep [names]    ->  imagegen/batch34/in/<name>.png (old figure on magenta)
python tools/art/map_object_paint.py paint [names]   ->  imagegen/batch34/out/<name>.png
python tools/art/map_object_paint.py ingest [names]  ->  assets/map/<name>.png (old ones in ignored shots/session67/art_old)
(names: only those; none: every one)"""
import os, sys, json
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from pose_paint import key_out, drop_specks, shadow

BATCH = "imagegen/batch34"
D = "assets/map"
MAGENTA = (255, 0, 255)
W, H = 1536, 1536
OBJECTS = {
    "shrine": "a stone circle on a ley line: a ring of seven tall weathered grey standing stones on a low grassy mound, "
              "one great flat altar stone in the middle, faint blue-white spirals and cup-and-ring carvings "
              "glowing on the stones (abstract carvings, no letters or runes)",
    "pyramid": "a great ancient Egyptian pyramid of weathered golden sandstone blocks with a gilded capstone, a dark "
               "doorway at its base facing the viewer flanked by two small obelisks, drifts of sand at its foot",
    "dwelling_mummy": "the Tomb of Curses: an ancient Egyptian rock-cut tomb entrance in a weathered sandstone outcrop, a "
                      "dark doorway framed by carved pillars and painted hieroglyphs, a winged scarab relief above, "
                      "torn linen strips at the threshold and a faint green glow inside",
    # session67: HoMM3's Giant and Red Dragon dwellings and its Hill Fort (the Illuminated's and Agartha's beings)
    "dwelling_giant": "the Cloud Temple: a small temple of white marble columns with a gilded dome on top of a steep "
                      "rocky crag, wreathed in soft white clouds, a broad stair of giant-sized steps climbing to its door",
    "dwelling_red_dragon": "the Dragon Cave: a great dark cave mouth in a hill of black volcanic rock, a deep red glow and "
                           "a wisp of smoke from inside, scorched ground, scattered gold coins and old bones at the "
                           "threshold",
    "hill_fort": "the Hill Fort: a sturdy little fort on a grassy hilltop, a squat round stone keep with a slate roof "
                 "and a red-and-gold pennant, a wooden palisade around it with an open gate facing the viewer, a "
                 "smithy's anvil and a weapon rack in the yard",
    "watchtower": "a small round stone observatory tower of an astrologer, with a domed copper roof opened by a slit, "
                  "a long brass telescope pointing out of the slit at the sky, a little wooden door at its foot",
}
# how much larger than a fit into the old figure's box (a low stone circle in place of a tall domed shrine read as
# much smaller on the map; so did a squat observatory in place of a watchtower on long legs)
GROW = {"shrine": 1.4, "watchtower": 1.6, "pyramid": 2.2, "dwelling_mummy": 1.2, "dwelling_giant": 2.3,
        "dwelling_red_dragon": 1.5, "hill_fort": 2.2}
# a new object painted over another one's old sprite (its view, size and light): the Pyramid over the domed shrine
REFS = {"pyramid": "shrine", "dwelling_mummy": "dwelling_neutral", "dwelling_giant": "dwelling_neutral",
        "dwelling_red_dragon": "dwelling_neutral", "hill_fort": "dwelling_neutral"}
PROMPT = ("The image shows an object of the adventure map of a hand-painted fantasy strategy game, seen from a 3/4 "
          "top-down view, on a flat magenta backdrop. Repaint it as {what}. Keep the same viewpoint, the same size and "
          "place in the image, standing on the same spot, the same hand-painted style and palette, lighting from the "
          "upper left. The background must stay a perfectly flat, pure magenta (#FF00FF) everywhere: no ground, no "
          "grass around it, no cast shadow, no scenery, no text.")


def _ref(name):
    """The old sprite, kept by prep (so ingest can run again after the asset was replaced); a new object's is its
    reference object's (REFS)."""
    return f"{BATCH}/in/{REFS.get(name, name)}_ref.png"


def _fig(name):
    """The old sprite's figure without its cast shadow (the painted figure is opaque, the shadow translucent)."""
    a = np.asarray(Image.open(_ref(name)).convert("RGBA"), dtype=np.float32)
    alpha = np.clip((a[..., 3] - 228) / 25, 0, 1) * 255
    return Image.fromarray(np.dstack([a[..., :3], alpha]).astype(np.uint8), "RGBA")


def _scale(c):
    return min(W * 0.6 / c.width, H * 0.6 / c.height)


def prep(names=None):
    os.makedirs(f"{BATCH}/in", exist_ok=True)
    for name in OBJECTS:
        if names and name not in names:
            continue
        if not os.path.exists(_ref(name)):
            Image.open(f"{D}/{REFS.get(name, name)}.png").save(_ref(name))
        c = _fig(name)
        c = c.crop(c.getbbox())
        s = _scale(c)
        big = c.resize((int(c.width * s), int(c.height * s)), Image.LANCZOS)
        canvas = Image.new("RGBA", (W, H), MAGENTA + (255,))
        canvas.alpha_composite(big, ((W - big.width) // 2, int(H * 0.8) - big.height))
        canvas.convert("RGB").save(f"{BATCH}/in/{name}.png")
        print("prep", name, round(s, 3))


def paint(names):
    from google import genai
    import vertex_paint as vp
    client = genai.Client(vertexai=True, project=vp.PROJECT, location=vp.LOCATION)
    os.makedirs(f"{BATCH}/out", exist_ok=True)
    for name, what in OBJECTS.items():
        if names and name not in names:
            continue
        img = vp.paint(client, "gemini-nano-banana-2.1", f"{BATCH}/in/{name}.png", PROMPT.format(what=what), "1:1", "2K")
        if img:
            img.save(f"{BATCH}/out/{name}.png"); print("done", name, flush=True)
        else:
            print("FAILED", name, flush=True)


def ingest(names=None):
    for name in OBJECTS:
        if names and name not in names:
            continue
        p = f"{BATCH}/out/{name}.png"
        if not os.path.exists(p):
            continue
        old = Image.open(_ref(name)).convert("RGBA")
        fig = _fig(name)
        box = fig.getbbox()
        cut = drop_specks(key_out(Image.open(p).convert("RGB").resize((W, H), Image.LANCZOS)), keep=0.05)
        cut = cut.crop(cut.getbbox())
        # fitted into the old figure's box, standing on its bottom centre
        s = min((box[2] - box[0]) / cut.width, (box[3] - box[1]) / cut.height) * GROW.get(name, 1.0)
        cut = cut.resize((max(1, int(cut.width * s)), max(1, int(cut.height * s))), Image.LANCZOS)
        fx, fy = (box[0] + box[2]) // 2, box[3]  # (the foot point, on the old canvas)
        x = fx - cut.width // 2
        y = fy - cut.height
        # the old canvas, grown where a larger figure and its shadow (leaning back-right) need more room
        x0, y0 = min(0, x - 8), min(0, y - 8)
        x1 = max(old.width, x + cut.width + int(cut.height * 0.35) + 8)
        y1 = old.height
        cw, ch = x1 - x0, y1 - y0
        layer = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
        layer.paste(cut, (x - x0, y - y0))
        la = np.asarray(layer)[..., 3]
        sha = shadow(la, fx - x0, fy - y0 - 2)
        out = Image.fromarray(np.dstack([np.full(la.shape + (3,), (12, 10, 8), np.uint8), (sha * 255).astype(np.uint8)]), "RGBA")
        Image.alpha_composite(out, layer).save(f"{D}/{name}.png")
        # a new object's anchor (its foot point), or one whose canvas grew; the others keep their rendered anchors
        anchors = json.load(open(f"{D}/anchors.json"))
        if f"{name}.png" not in anchors or (cw, ch) != old.size:
            anchors[f"{name}.png"] = [round((fx - x0) / cw, 4), round((fy - y0) / ch, 4)]
            json.dump(anchors, open(f"{D}/anchors.json", "w"), indent=0, sort_keys=True)
        print("ingested", name, "scale", round(s, 3), "size", (cw, ch))


if __name__ == "__main__":
    {"prep": lambda: prep(sys.argv[2:]), "paint": lambda: paint(sys.argv[2:]), "ingest": lambda: ingest(sys.argv[2:])}[sys.argv[1]]()
