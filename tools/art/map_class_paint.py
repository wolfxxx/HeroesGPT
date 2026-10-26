"""Mounted map heroes per class, as the classic game (each hero class has its own figure on the adventure map).
The faction figures are a Knight (assets/heroes/map_haven*.png) and a dark lance knight read as the Death Knight
(map_necropolis*.png); the other class of each faction is the same horse in the same poses repainted with another rider.
python tools/art/map_class_paint.py prep           ->  imagegen/batch32/in/<class>.png (standing + 4 gallop frames)
python tools/art/map_class_paint.py paint [names]  ->  imagegen/batch32/out/<class>.png
python tools/art/map_class_paint.py ingest         ->  assets/heroes/map_<class>.png, map_<class>_run<0-3>.png + anchors

All five poses of a class are painted in one sheet (3x2 cells, the sixth a second standing pose that is not used), so
the model keeps the rider identical between them. Ingest keys out each cell, scales it back to its source figure
(hooves on the same line, the horse's legs at the same place), gives it the gallop frames' synthetic cast shadow and
anchors it on that figure's foot point."""
import os, sys, json
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from pose_paint import key_out, drop_specks, shadow

BATCH = "imagegen/batch32"
D = "assets/heroes"
MAGENTA = (255, 0, 255)
CELL_W, CELL_H = 912, 768  # 3x2 cells: a 16:9 sheet (2736x1536)
CELLS = ["", "_run0", "_run1", "_run2", "_run3", ""]
CLASSES = {
    "cleric": ("haven", "a Cleric: a holy battle priest in a long white and blue robe with gold trim over a light mail "
               "shirt, a simple gold circlet and no helmet, holding the reins and a flanged gold mace resting on the "
               "right shoulder, the arm bent and relaxed, NOT raised (NO lance, NO spear, NO banner), sitting "
               "naturally in the saddle as a rider does"),
    "necromancer": ("necropolis", "a Necromancer: a gaunt robed sorcerer in a hooded tattered black and deep purple "
                    "robe, a pale skull-like face in the hood, holding upright a long dark staff topped with a skull "
                    "and a faint green glow (NO lance, NO spear, NO plate armour, NO helmet)"),
    # session67: the Illuminated: their faction figure (an Alchemist, map_tower*.png) and the Wizard
    "tower": ("haven", "an Alchemist of a secret order: a scholar-warrior in a long midnight-blue coat with gold trim over a light breastplate, a wide-brimmed dark hat, a leather bandolier of glowing glass flasks across the chest, holding the reins in the left hand and a short brass-tipped rod in the right hand resting on the thigh, sitting naturally in the saddle (NO lance, NO spear, NO helmet)"),
    "wizard": ("haven", "a Wizard: a bearded sage in flowing white-and-gold robes under a deep blue hooded mantle, holding upright a tall staff topped with a glowing pale-blue crystal in the right hand, the reins in the left (NO lance, NO armour, NO helmet)"),
    # session68: Agartha: their faction figure (an Overlord, map_dungeon*.png) and the Warlock
    "dungeon": ("haven", "an Overlord of the kingdom beneath the earth: a warlord in heavy dark violet-black plate armour with bronze trim, a horned bronze helm with the visor open, a short dark cape, holding the reins in the left hand and a heavy war-axe resting upright against the right shoulder (NO lance, NO spear)"),
    "warlock": ("haven", "a Warlock of the inner world: a sorcerer in long deep violet robes with bronze trim and a hood thrown back, a pointed dark beard, holding upright a tall black staff topped with a glowing amber crystal in the right hand, the reins in the left (NO lance, NO armour, NO helmet)"),
}
PROMPT = ("The image shows the same mounted hero six times, standing and galloping, as small figures for the adventure "
          "map of a hand-painted fantasy strategy game, seen from a 3/4 top-down view, on a flat magenta backdrop. "
          "Repaint ONLY the rider in every cell as {who}, the same rider in all six cells. Keep every horse EXACTLY as "
          "it is (same horse, barding, colours, legs and pose, same position and size in its cell), each figure facing "
          "right, the same hand-painted style, palette and lighting from the upper left. The background must stay a "
          "perfectly flat, pure magenta (#FF00FF) everywhere: no ground, no shadow, no scenery, no grid lines, no text.")


def _fig(path):
    """A map hero sprite's figure without its cast shadow (the painted figure is opaque, the shadow translucent)."""
    a = np.asarray(Image.open(path).convert("RGBA"), dtype=np.float32)
    lo = 228 if "_run" not in path else 150  # (the standing render's shadow core is denser than the gallop's)
    alpha = np.clip((a[..., 3] - lo) / 25, 0, 1) * 255
    return Image.fromarray(np.dstack([a[..., :3], alpha]).astype(np.uint8), "RGBA")


def _cell(k):
    return (k % 3) * CELL_W, (k // 3) * CELL_H


def _feet(alpha):
    """The foot point of a figure: the centre of its legs (its lowest 30%) and its lowest solid row."""
    ys, xs = np.nonzero(alpha > 128)
    low = ys >= ys.min() + 0.7 * (ys.max() - ys.min())
    return float(xs[low].mean()), float(ys.max())


def prep(names=None):
    os.makedirs(f"{BATCH}/in", exist_ok=True)
    info = {}
    for cls, (fac, _) in CLASSES.items():
        if names and cls not in names:
            continue
        figs = [_fig(f"{D}/map_{fac}{c}.png") for c in CELLS]
        crops = [f.crop(f.getbbox()) for f in figs]
        s = min(min(CELL_W * 0.7 / c.width, CELL_H * 0.78 / c.height) for c in crops)
        sheet = Image.new("RGBA", (CELL_W * 3, CELL_H * 2), MAGENTA + (255,))
        for k, c in enumerate(crops):
            big = c.resize((int(c.width * s), int(c.height * s)), Image.LANCZOS)
            cx, cy = _cell(k)
            sheet.alpha_composite(big, (cx + (CELL_W - big.width) // 2, cy + int(CELL_H * 0.88) - big.height))
        sheet.convert("RGB").save(f"{BATCH}/in/{cls}.png")
        info[cls] = {"faction": fac, "scale": s}
        print("prep", cls, "scale", round(s, 3))
    json.dump(info, open(f"{BATCH}/in/classes.json", "w"), indent=1)


def paint(names):
    from google import genai
    import vertex_paint as vp
    client = genai.Client(vertexai=True, project=vp.PROJECT, location=vp.LOCATION)
    os.makedirs(f"{BATCH}/out", exist_ok=True)
    for cls, (fac, who) in CLASSES.items():
        if names and cls not in names:
            continue
        img = vp.paint(client, "gemini-nano-banana-2.1", f"{BATCH}/in/{cls}.png", PROMPT.format(who=who), "16:9", "2K")
        if img:
            img.save(f"{BATCH}/out/{cls}.png"); print("done", cls, flush=True)
        else:
            print("FAILED", cls, flush=True)


def ingest(names=None):
    info = json.load(open(f"{BATCH}/in/classes.json"))
    anchors = json.load(open(f"{D}/anchors.json"))
    for cls, d in info.items():
        src = f"{BATCH}/out/{cls}.png"
        if not os.path.exists(src):
            continue
        fac, s = d["faction"], d["scale"]
        sheet = Image.open(src).convert("RGB").resize((CELL_W * 3, CELL_H * 2), Image.LANCZOS)
        for k, c in enumerate(CELLS[:5]):
            old = _fig(f"{D}/map_{fac}{c}.png")
            oa = np.asarray(old)[..., 3]
            cx, cy = _cell(k)
            cut = drop_specks(key_out(sheet.crop((cx + 4, cy + 4, cx + CELL_W - 4, cy + CELL_H - 4))), keep=0.05)
            cut = cut.resize((max(1, int(cut.width / s)), max(1, int(cut.height / s))), Image.LANCZOS)
            cut = cut.crop(cut.getbbox())
            na = np.asarray(cut)[..., 3]
            f = float(np.clip(np.sqrt((oa > 128).sum() / max(1, (na > 128).sum())), 0.85, 1.15))
            cut = cut.resize((max(1, int(cut.width * f)), max(1, int(cut.height * f))), Image.LANCZOS)
            na = np.asarray(cut)[..., 3]
            ox, oy = _feet(oa)
            nx, ny = _feet(na)
            # the new figure on a canvas around the old figure's foot point, large enough for it and its shadow
            pad = 10
            sh_w = int(cut.height * 0.2) + 24
            left = int(round(ox - nx))
            top = int(round(oy - ny))
            x0, y0 = min(0, left - pad), min(0, top - pad)
            x1 = max(old.width, left + cut.width + pad + sh_w)
            y1 = max(old.height, top + cut.height + pad)
            W, H = x1 - x0, y1 - y0
            fa = np.zeros((H, W), np.uint8)
            fa[top - y0:top - y0 + cut.height, left - x0:left - x0 + cut.width] = na
            fx, fy = ox - x0, oy - y0
            sha = shadow(fa, fx, fy)
            out = Image.fromarray(np.dstack([np.full((H, W, 3), (12, 10, 8), np.uint8), (sha * 255).astype(np.uint8)]), "RGBA")
            out.alpha_composite(cut, (left - x0, top - y0))
            name = f"map_{cls}{c}.png"
            out.save(f"{D}/{name}")
            # the old sprite's anchor, moved with the canvas
            ax, ay = anchors[f"map_{fac}{c}.png"]
            anchors[name] = [round((ax * old.width - x0) / W, 4), round((ay * old.height - y0) / H, 4)]
            print("ingested", name, "scale", round(f, 3), "size", (W, H))
    json.dump(anchors, open(f"{D}/anchors.json", "w"), indent=0, sort_keys=True)


if __name__ == "__main__":
    {"prep": lambda: prep(sys.argv[2:]), "paint": lambda: paint(sys.argv[2:]), "ingest": lambda: ingest(sys.argv[2:])}[sys.argv[1]]()
