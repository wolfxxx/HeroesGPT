"""Wrecks of the war machines (as the classic, a destroyed machine leaves its broken remains on its hex), drawn by an
image model from the painted idle sprite. The ballista's (round 47) came from tools/art/ballista_wreck_prompt.md.
python tools/art/machine_wreck_paint.py prep           ->  imagegen/batch30/in/<id>.png (idle sprite on magenta)
python tools/art/machine_wreck_paint.py paint [ids...] ->  imagegen/batch30/out/<id>.png
python tools/art/machine_wreck_paint.py ingest         ->  assets/creatures/<id>_dead.png + anchors.json
python tools/art/machine_wreck_paint.py shrink         ->  every wreck resampled to SHRINK_W wide
then python tools/art/sprite_sizes.py <id>_dead.png measures it (battle.gd scales a wreck to the idle machine's width).
The battle draws a wreck at about a quarter (the ballista's original: a tenth) of its painted size with no mipmaps,
which speckles the fine splinters; shrink resamples each, once and smoothly, to about 1.5x its on-screen size.
"""
import os, sys, json
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from pose_paint import key_out, drop_specks, figure, shadow

BATCH = "imagegen/batch30"
D = "assets/creatures"
W, H = 1600, 1200  # (4:3)
SHRINK_W = {"ballista": 250, "first_aid_tent": 205, "ammo_cart": 250, "catapult": 250}  # (canvas widths; on screen ~165/136/168)
WHAT = {
    "first_aid_tent": ("a field hospital tent of cream canvas with red trim and a red heart emblem", (
        "The tent has COLLAPSED: its centre pole snapped and leaning out, the canvas roof caved in and slumped to the "
        "ground in folds, one side torn open with a ragged rip, a guy rope loose; the little bench is knocked over and "
        "rolls of bandage and a medicine box are spilled on the ground beside it. The heart emblem is still visible "
        "on a fold of the fallen canvas.")),
    "ammo_cart": ("a two-wheeled wooden ammunition cart loaded with barrels and bundles of arrows", (
        "The cart is WRECKED: its axle broken so the cart bed lies tilted on the ground, one big spoked wheel snapped "
        "off and lying flat beside it, a shaft broken in two, a barrel split open, and bundles of arrows and loose "
        "arrows spilled across the ground in front of it.")),
    "catapult": ("a wooden siege catapult on four wheels with a long throwing arm and a sling holding a stone", (
        "The catapult is SMASHED: its throwing arm snapped in two with the broken half lying on the ground, the "
        "A-frame uprights cracked and collapsed sideways, the chassis broken so it sags to the ground, one wheel "
        "broken off and lying flat, the sling torn and its round stone rolled away, splintered beams and loose rope "
        "around it.")),
}
PROMPT = ("The image shows {what} from a battle in a hand-painted fantasy strategy game, seen side-on from slightly "
          "above, on a flat magenta backdrop. Repaint it as the same object DESTROYED in battle. {how} Keep the same "
          "hand-painted style, colours, materials, line work and lighting from the upper left, the same camera angle, "
          "and about the same width; the wreck lies low on the ground. Clearly destroyed, not the intact object tipped "
          "over. No people, no fire, no smoke, no ground patch, no shadow, no text. The background must stay a "
          "perfectly flat, pure magenta (#FF00FF) everywhere around it.")


def prep():
    os.makedirs(f"{BATCH}/in", exist_ok=True)
    info = {}
    for mid in WHAT:
        im, fig, (x0, y0, x1, y1) = figure(mid)
        s = W * 0.6 / (x1 - x0)
        big = fig.crop((x0, y0, x1, y1))
        big = big.resize((int(big.width * s), int(big.height * s)), Image.LANCZOS)
        canvas = Image.new("RGBA", (W, H), (255, 0, 255, 255))
        canvas.alpha_composite(big, ((W - big.width) // 2, int(H * 0.82) - big.height))
        canvas.convert("RGB").save(f"{BATCH}/in/{mid}.png")
        info[mid] = s
    json.dump(info, open(f"{BATCH}/in/scale.json", "w"))
    print("prep", list(info))


def paint(ids):
    from google import genai
    import vertex_paint as vp
    client = genai.Client(vertexai=True, project=vp.PROJECT, location=vp.LOCATION)
    os.makedirs(f"{BATCH}/out", exist_ok=True)
    for mid, (what, how) in WHAT.items():
        if ids and mid not in ids:
            continue
        img = vp.paint(client, "gemini-nano-banana-2.1", f"{BATCH}/in/{mid}.png", PROMPT.format(what=what, how=how),
                       "4:3", "2K")
        if img:
            img.save(f"{BATCH}/out/{mid}.png"); print("done", mid, flush=True)
        else:
            print("FAILED", mid, flush=True)


def ingest():
    scale = json.load(open(f"{BATCH}/in/scale.json"))
    anchors = json.load(open(f"{D}/anchors.json"))
    for mid, s in scale.items():
        p = f"{BATCH}/out/{mid}.png"
        if not os.path.exists(p):
            continue
        cut = drop_specks(key_out(Image.open(p).convert("RGB").resize((W, H), Image.LANCZOS)))
        cut = cut.resize((int(W / s), int(H / s)), Image.LANCZOS)  # (back to the idle sprite's scale)
        a = np.asarray(cut)[..., 3]
        ys, xs = np.nonzero(a > 20)
        fig = cut.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
        fa = np.asarray(fig)[..., 3]
        sy, sx = np.nonzero(fa > 128)
        fx, fy = float(np.median(sx)), float(sy.max())  # (the wreck's foot: bottom of its solid mass, middle)
        pad, sh_w = 12, int(fig.height * 0.55 * 0.32) + 30
        w2, h2 = fig.width + 2 * pad + sh_w, fig.height + 2 * pad + 10
        al = np.zeros((h2, w2), np.uint8)
        al[pad:pad + fig.height, pad:pad + fig.width] = fa
        sha = shadow(al, pad + fx, pad + fy)
        out = Image.fromarray(np.dstack([np.zeros((h2, w2, 3), np.uint8) + np.array([12, 10, 8], np.uint8),
                                         (sha * 255).astype(np.uint8)]), "RGBA")
        out.alpha_composite(fig, (pad, pad))
        out.save(f"{D}/{mid}_dead.png")
        anchors[f"{mid}_dead.png"] = [round((pad + fx) / w2, 4), round((pad + fy) / h2, 4)]
        print("ingested", mid, out.size, anchors[f"{mid}_dead.png"])
    json.dump(anchors, open(f"{D}/anchors.json", "w"), indent=0, sort_keys=True)


def shrink():
    for mid, w in SHRINK_W.items():
        p = f"{D}/{mid}_dead.png"
        im = Image.open(p).convert("RGBA")
        if im.width <= w:
            continue
        # (premultiplied, so the transparent surround doesn't bleed dark fringes into the edge)
        a = np.asarray(im, np.float32) / 255
        pre = Image.fromarray((np.dstack([a[..., :3] * a[..., 3:], a[..., 3]]) * 255).astype(np.uint8), "RGBA")
        h = max(1, round(im.height * w / im.width))
        b = np.asarray(pre.resize((w, h), Image.LANCZOS), np.float32) / 255
        rgb = b[..., :3] / np.maximum(b[..., 3:], 1e-3)
        Image.fromarray((np.dstack([rgb, b[..., 3]]).clip(0, 1) * 255).astype(np.uint8), "RGBA").save(p)
        print("shrunk", mid, im.size, "->", (w, h))


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "prep":
        prep()
    elif cmd == "paint":
        paint(sys.argv[2:])
    elif cmd == "shrink":
        shrink()
    else:
        ingest()
