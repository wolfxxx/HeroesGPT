"""The town on the adventure map grows with its fortifications, as in the classic game: a village of houses with no
wall until the Fort is built, a walled town with a Fort or a Citadel, and the full castle (the existing painting,
assets/map/town_<faction>.png) once the Castle stands.
python tools/art/town_levels_paint.py prep              ->  imagegen/batch29/in/town_<faction>.png (castle on magenta)
python tools/art/town_levels_paint.py paint [names...]  ->  imagegen/batch29/out/<level>_<faction>.png
python tools/art/town_levels_paint.py ingest            ->  assets/map/town_<faction>_<level>.png (village, fort)

Each picture is a repaint of the castle on a magenta backdrop, keeping its round cobbled base and the gate at the
front centre (where heroes stand), so it fits the same footprint on the map; ingest keys out the magenta and casts
a fresh soft shadow like the castle's."""
import os, sys, json
import numpy as np
from PIL import Image, ImageFilter

sys.path.insert(0, os.path.dirname(__file__))
from pose_paint import key_out, drop_specks

BATCH = "imagegen/batch29"
FACTIONS = ["haven", "necropolis", "tower", "dungeon"]
MAGENTA = (255, 0, 255)
W, H = 1920, 1080  # (16:9, as the model returns it)

STYLE_OF = {"haven": "white limestone with blue slate roofs and gold trim, blue-and-gold banners",
            "necropolis": "black basalt and dark slate with bone ornaments, violet banners and green ghost-light in the "
                          "windows",
            "dungeon": "dark violet-black basalt and obsidian with bronze trim, violet roofs, amber-lit windows and "
                       "glowing violet crystals, on a dark rock base",
            "tower": "white marble with gold domes and trim, deep blue conical roofs and blue banners, light snow on the "
                     "roofs and a snowy rock base"}
LEVEL = {
    "village": ("a small unwalled VILLAGE: NO castle wall, NO towers and NO battlements at all; a modest town hall with "
                "a pitched roof at the centre back, a few small houses and a tavern around a little cobbled square, and "
                "a low wooden fence or hedge at most; an open archway or path at the front centre where the gate was"),
    "fort": ("a small WALLED TOWN: one plain low crenellated stone curtain wall around the same round base with a single "
             "gatehouse and closed wooden gate at the front centre, and only square wall corners (NO round towers, NO "
             "conical tower roofs, NO keep); behind the wall the pitched roofs of a town hall and a few houses"),
}
PROMPT = ("The image shows a town as seen on the adventure map of a fantasy strategy game, from a high three-quarter "
          "angle, on a flat magenta backdrop. Repaint it as {what}, built of {mat}. Same hand-painted style, palette, "
          "line work and lighting from the upper left, same camera angle. VERY IMPORTANT: keep the same round cobbled "
          "base, the same size and position in the frame, and the entrance at the front centre exactly where the gate "
          "is now. The background must stay a perfectly flat, pure magenta (#FF00FF) everywhere around it: no ground, "
          "no cast shadow, no scenery, no text.")


def _solid(fac):
    """The castle sprite without its cast shadow: only the building and its base (opaque, painted) pixels."""
    im = Image.open(f"assets/map/town_{fac}.png").convert("RGBA")
    a = np.asarray(im).copy()
    rgb = a[..., :3].astype(np.int16)
    # (the shadow is translucent black; the building is opaque and coloured)
    shadow = (a[..., 3] < 235) | (rgb.max(2) < 12)
    a[shadow, 3] = 0
    return Image.fromarray(a, "RGBA")


def _frame(fac):
    """Where the sprite's canvas sits on the 1920x1080 paint canvas (scaled to fill most of its height)."""
    im = Image.open(f"assets/map/town_{fac}.png")
    s = min(W * 0.86 / im.width, H * 0.86 / im.height)
    w, h = int(im.width * s), int(im.height * s)
    return s, (W - w) // 2, (H - h) // 2, w, h


def prep(only=None):
    os.makedirs(f"{BATCH}/in", exist_ok=True)
    for fac in FACTIONS:
        if only and fac not in only:
            continue
        s, x, y, w, h = _frame(fac)
        canvas = Image.new("RGBA", (W, H), MAGENTA + (255,))
        canvas.alpha_composite(_solid(fac).resize((w, h), Image.LANCZOS), (x, y))
        canvas.convert("RGB").save(f"{BATCH}/in/town_{fac}.png")
        print("prep", fac)


def paint(names):
    from google import genai
    import vertex_paint as vp
    client = genai.Client(vertexai=True, project=vp.PROJECT, location=vp.LOCATION)
    os.makedirs(f"{BATCH}/out", exist_ok=True)
    for fac in FACTIONS:
        for lvl, what in LEVEL.items():
            n = f"{lvl}_{fac}"
            if names and n not in names:
                continue
            dst = f"{BATCH}/out/{n}.png"
            if os.path.exists(dst) and not names:
                print("skip", n); continue
            img = vp.paint(client, "gemini-nano-banana-2.1", f"{BATCH}/in/town_{fac}.png",
                           PROMPT.format(what=what, mat=STYLE_OF[fac]), "16:9", "2K")
            if img:
                img.save(dst); print("done", n, flush=True)
            else:
                print("FAILED", n, flush=True)


def _cast(alpha):
    """A soft shadow falling back and to the right, like the castle's: the building squashed onto the ground from
    its base line and leaned right."""
    h, w = alpha.shape
    ys = np.nonzero(alpha.max(1) > 128)[0]
    fy = int(ys.max()) - int(0.12 * (ys.max() - ys.min()))  # (the base's middle, not its front edge)
    squash, shear = 0.45, 0.9
    coeffs = (1, shear / squash, -shear / squash * fy, 0, 1 / squash, fy - fy / squash)
    sh = Image.fromarray(alpha).transform((w, h), Image.AFFINE, coeffs, Image.BILINEAR).filter(ImageFilter.GaussianBlur(6))
    return np.asarray(sh, np.float32) / 255 * 0.45


def ingest(only=None):
    anchors = json.load(open("assets/map/anchors.json"))
    for fac in FACTIONS:
        if only and fac not in only:
            continue
        old = Image.open(f"assets/map/town_{fac}.png")
        for lvl in LEVEL:
            p = f"{BATCH}/out/{lvl}_{fac}.png"
            if not os.path.exists(p):
                continue
            cut = drop_specks(key_out(Image.open(p).convert("RGB").resize((W, H), Image.LANCZOS)))
            # as wide as the castle, its base's front centre (the entrance) where the castle's is
            ref = np.asarray(_solid(fac))[..., 3] > 128
            ry, rx = np.nonzero(ref)
            cy, cx = np.nonzero(np.asarray(cut)[..., 3] > 128)
            k = (rx.max() - rx.min()) / max(1, cx.max() - cx.min())
            cut = cut.crop((int(cx.min()), int(cy.min()), int(cx.max()) + 1, int(cy.max()) + 1))
            cut = cut.resize((max(1, int(cut.width * k)), max(1, int(cut.height * k))), Image.LANCZOS)
            canvas = Image.new("RGBA", old.size, (0, 0, 0, 0))
            bx = int((rx.min() + rx.max()) / 2 - cut.width / 2)
            canvas.alpha_composite(cut, (max(0, bx), max(0, int(ry.max()) + 1 - cut.height)))
            cut = canvas
            fig = np.asarray(cut).astype(np.float32)
            a = fig[..., 3] / 255
            sh = _cast(fig[..., 3].astype(np.uint8)) * (1 - a)
            out_a = a + sh
            rgb = fig[..., :3] * (a / np.maximum(out_a, 1e-3))[..., None]
            out = np.dstack([rgb, out_a * 255]).clip(0, 255).astype(np.uint8)
            Image.fromarray(out, "RGBA").save(f"assets/map/town_{fac}_{lvl}.png")
            anchors[f"town_{fac}_{lvl}.png"] = anchors[f"town_{fac}.png"]  # (same canvas, same foot)
            print("ingested", fac, lvl)
    json.dump(anchors, open("assets/map/anchors.json", "w"), indent=0, sort_keys=True)


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "prep":  # (prep [factions], paint [level_faction names], ingest [factions])
        prep(sys.argv[2:])
    elif cmd == "paint":
        paint(sys.argv[2:])
    else:
        ingest(sys.argv[2:])
