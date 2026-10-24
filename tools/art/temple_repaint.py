"""The Temple (faction id `haven`) repainted in the Templars' colours (docs/SETTING.md): its town-screen layers, the
backdrop, the building cards and the map town keep their silhouettes, sizes and places; only colours and emblems change
(banners and flags white with a red cross pattee, blue roofs grey slate, shields with the red cross).
python tools/art/temple_repaint.py prep [names]    ->  imagegen/batch37/in/<name>.png + temple.json
python tools/art/temple_repaint.py paint [names]   ->  imagegen/batch37/out/<name>.png
python tools/art/temple_repaint.py ingest [names]  ->  the assets (old ones copied to ignored shots/session67/temple_old/)
python tools/art/temple_repaint.py slate [files]   ->  blue roofs to slate only (default: the siege paintings and pieces;
                                                       also used on the map towns, too small for the model's roofs)
Names: town__<layer> (assets/town/haven_<layer>.png; "bg" the backdrop), card__<id> (icons/building_haven_<id>.png),
map__<file> (map/town_haven*.png), ui__main_menu_bg (the title screen). Layers are painted on a flat backdrop like upgrade_paint's dwellings and pasted back
inside the old alpha (the soft edge keeps the old pixels), so they still fit the layout exactly."""
import os, sys, json, glob, shutil
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import upgrade_paint as up

BATCH = "imagegen/batch37"
OLD = "shots/session67/temple_old"
BG = (148, 140, 124)
LOOK = ("in the colours of the Knights Templar: keep the white stone walls and the gold trim, but every banner, pennant "
        "and flag becomes white with a red Templar cross pattee (a cross with flared arms), every blue roof becomes dark "
        "grey slate, blue cloth and trim becomes deep red or white, and shields and emblems show the red cross pattee")
LAYER = ("This is a town building from a fantasy strategy game, seen from a high three-quarter angle. Repaint it " + LOOK +
         ". " + up.STYLE + "\nVERY IMPORTANT: keep exactly the same building with the same outline, silhouette, size, "
         "position in the frame and camera angle; change only colours, banners and emblems. Keep the background a "
         "perfectly plain, flat grey-beige colour exactly like the original: no ground, cast shadows, scenery, frame or "
         "text.")
BACK = ("This is the backdrop of a town screen in a fantasy strategy game: a castle on a hill. Repaint it " + LOOK + ". " +
        up.STYLE + "\nKeep exactly the same composition, landscape, sky, castle shapes and their positions; change only "
        "colours, banners and emblems. No text, no people.")
CARD = ("This is a picture of a single town building for the building screen of a fantasy strategy game. Repaint it " +
        LOOK + ". " + up.STYLE + "\nKeep the same setting, landscape, lighting, camera angle and composition, with the "
        "building in the same place at the same size; change only colours, banners and emblems. No people, no text, no "
        "border.")
MENU = ("This is the title-screen painting of a fantasy strategy game: a castle in a landscape. Repaint it " + LOOK + ". " +
        up.STYLE + "\nKeep exactly the same composition, landscape, sky, light and castle shapes and their positions; "
        "change only colours, banners and emblems. No text, no people.")
MAP = ("This is a town as seen on the adventure map of a fantasy strategy game, from a 3/4 top-down view, on a flat "
       "backdrop. Repaint it " + LOOK + ". " + up.STYLE + "\nKeep exactly the same town, outline, size and position; "
       "change only colours, banners and emblems. Keep the background a perfectly plain, flat grey-beige colour: no "
       "ground, no shadow, no text.")


def _src(name):
    kind, rest = name.split("__", 1)
    return {"town": f"assets/town/haven_{rest}.png", "card": f"assets/icons/building_haven_{rest}.png",
            "map": f"assets/map/{rest}.png", "ui": f"assets/ui/{rest}.png"}[kind]


def all_names():
    out = ["town__" + os.path.basename(p)[6:-4] for p in sorted(glob.glob("assets/town/haven_*.png"))]
    out += ["card__" + os.path.basename(p)[15:-4] for p in sorted(glob.glob("assets/icons/building_haven_*.png"))]
    out += ["map__" + os.path.basename(p)[:-4] for p in sorted(glob.glob("assets/map/town_haven*.png"))]
    return out + ["ui__main_menu_bg"]  # (the main menu's castle: the Temple's)


def prep(names):
    os.makedirs(f"{BATCH}/in", exist_ok=True)
    pj = f"{BATCH}/in/temple.json"
    info = json.load(open(pj)) if os.path.exists(pj) else {}
    for name in names or all_names():
        src = _src(name)
        if not os.path.exists(f"{OLD}/{os.path.basename(src)}"):  # (the original, kept before any repaint)
            os.makedirs(OLD, exist_ok=True)
            shutil.copy(src, f"{OLD}/{os.path.basename(src)}")
        im = Image.open(f"{OLD}/{os.path.basename(src)}")
        if im.mode != "RGBA":  # (the backdrop and the cards: a whole picture)
            w, h = im.size
            r = up._ratio(w, h)
            im.convert("RGB").save(f"{BATCH}/in/{name}.png")
            info[name] = {"whole": True, "ratio": r}
            continue
        sp = im.convert("RGBA")
        bb = sp.getchannel("A").point(lambda v: 255 if v > 20 else 0).getbbox()
        crop = sp.crop(bb)
        w, h = crop.width * 1.15, crop.height * 1.15
        r = up._ratio(w, h)
        if w / h > up.RATIOS[r]:
            h = w / up.RATIOS[r]
        else:
            w = h * up.RATIOS[r]
        s = up.LONG / max(w, h)
        W, H = int(round(w * s)), int(round(h * s))
        canvas = Image.new("RGBA", (W, H), BG + (255,))
        big = crop.resize((int(round(crop.width * s)), int(round(crop.height * s))), Image.LANCZOS)
        ox, oy = (W - big.width) // 2, (H - big.height) // 2
        canvas.alpha_composite(big, (ox, oy))
        canvas.convert("RGB").save(f"{BATCH}/in/{name}.png")
        info[name] = {"whole": False, "bbox": list(bb), "box": [ox, oy, big.width, big.height], "ratio": r}
    json.dump(info, open(pj, "w"), indent=1)
    print(len(info), "references")


def _prompt(name):
    kind, rest = name.split("__", 1)
    if kind == "card":
        return CARD
    if kind == "map":
        return MAP
    if kind == "ui":
        return MENU
    return BACK if rest == "bg" else LAYER


def paint(names):
    from google import genai
    import vertex_paint as vp
    client = genai.Client(vertexai=True, project=vp.PROJECT, location=vp.LOCATION)
    info = json.load(open(f"{BATCH}/in/temple.json"))
    os.makedirs(f"{BATCH}/out", exist_ok=True)
    for name in names or list(info):
        img = vp.paint(client, "gemini-nano-banana-2.1", f"{BATCH}/in/{name}.png", _prompt(name), info[name]["ratio"], "2K")
        if img:
            img.save(f"{BATCH}/out/{name}.png"); print("done", name, flush=True)
        else:
            print("FAILED", name, flush=True)


def ingest(names):
    info = json.load(open(f"{BATCH}/in/temple.json"))
    for name in names or list(info):
        p = f"{BATCH}/out/{name}.png"
        if not os.path.exists(p):
            continue
        d = info[name]
        src = _src(name)
        old = Image.open(f"{OLD}/{os.path.basename(src)}")
        if d["whole"]:
            Image.open(p).convert("RGB").resize(old.size, Image.LANCZOS).save(src)
            print("ingested", name); continue
        base = old.convert("RGBA")
        ref = Image.open(f"{BATCH}/in/{name}.png")
        painted = Image.open(p).convert("RGB").resize(ref.size, Image.LANCZOS)
        ox, oy, bw, bh = d["box"]
        x0, y0, x1, y1 = d["bbox"]
        part = painted.crop((ox, oy, ox + bw, oy + bh)).resize((x1 - x0, y1 - y0), Image.LANCZOS)
        out = base.copy()
        a = np.asarray(base)[y0:y1, x0:x1].astype(np.float32)
        q = np.asarray(part).astype(np.float32)
        k = np.clip((a[..., 3:4] - 120) / 100, 0, 1)  # (painted colour inside the silhouette; the soft edge keeps the old)
        a[..., :3] = a[..., :3] * (1 - k) + q * k
        out.paste(Image.fromarray(a.astype(np.uint8), "RGBA"), (x0, y0))
        out.save(src)
        print("ingested", name)


def slate_rgba(im):
    """Blue roofs to cool slate grey, everything else untouched (hue 190-265 degrees, saturation above 0.07, ramped):
    for pictures too small for the model to repaint, and for the siege paintings, whose walls must not move."""
    a = np.asarray(im.convert("RGBA")).astype(np.float32) / 255.0
    rgb = a[..., :3]
    mx, mn = rgb.max(-1), rgb.min(-1)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    d = np.maximum(mx - mn, 1e-6)
    hue = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) * 60
    blue = (hue > 190) & (hue < 265) & (sat > 0.07)
    lum = (0.3 * r + 0.59 * g + 0.11 * b)[..., None]
    grey = np.clip(lum * np.array([0.93, 0.96, 1.04]) * 1.04, 0, 1)
    k = np.clip((sat - 0.07) / 0.1, 0, 1)[..., None] * blue[..., None]
    return Image.fromarray((np.dstack([rgb * (1 - k) + grey * k, a[..., 3:]]) * 255).astype(np.uint8), "RGBA")


def slate(paths):
    """`slate` the given asset files (default: the Temple's siege paintings and their damage pieces), from the copies
    kept in shots/session67/temple_old (made on first use)."""
    paths = paths or sorted(glob.glob("assets/battle/bg_siege_haven_*.png") + glob.glob("assets/battle/siege_haven_*_*_*.png"))
    os.makedirs(OLD, exist_ok=True)
    for p in paths:
        keep = f"{OLD}/{os.path.basename(p)}"
        if not os.path.exists(keep):
            shutil.copy(p, keep)
        src = Image.open(p if "town_haven" in p else keep)  # (the map towns: over their painted flags)
        out = slate_rgba(src)
        out = out if src.mode == "RGBA" else out.convert("RGB")
        out.save(p)
        print("slate", p)


if __name__ == "__main__":
    {"prep": prep, "paint": paint, "ingest": ingest, "slate": slate}[sys.argv[1]](sys.argv[2:])
