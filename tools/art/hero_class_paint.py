"""Mounted battle heroes per class, as the classic game (each hero class has its own figure beside the battlefield).
The faction figures are a Knight (assets/heroes/battle_haven.png) and a Necromancer (battle_necropolis.png); the
other class of each faction is the same horse and pose repainted with another rider by the image model.
python tools/art/hero_class_paint.py prep           ->  imagegen/batch31/in/<class>.png (the figure on magenta)
python tools/art/hero_class_paint.py paint [names]  ->  imagegen/batch31/out/<class>.png
python tools/art/hero_class_paint.py ingest         ->  assets/heroes/battle_<class>.png (battle.gd picks it by class)

Ingest keys out the magenta, fits the new figure over the old one's place (same canvas, hooves on the same line)
and lays it over the old figure's cast shadow (the horse is the same, so its shadow still fits)."""
import os, sys
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from pose_paint import key_out, drop_specks

BATCH = "imagegen/batch31"
MAGENTA = (255, 0, 255)
W, H = 1920, 1080
CLASSES = {
    "cleric": ("haven", "a Cleric: a holy battle priest in a long white and blue robe with gold trim over a light mail "
               "shirt, a hood or a simple circlet instead of a helmet, holding the reins in the left hand and a flanged "
               "gold mace in the right hand resting on the right shoulder, the arm bent and relaxed, NOT raised "
               "(NO lance, NO spear), a small round holy symbol on the chest, sitting naturally in the saddle"),
    "death_knight": ("necropolis", "a Death Knight: a hulking warrior in heavy black spiked plate armour with a horned "
                     "helm and glowing green eye slits, a tattered dark cape, holding a huge two-handed jagged black "
                     "sword upright in the right hand (NO staff, NO robes, NO hood)"),
    # session67: the Illuminated: their faction figure (an Alchemist, battle_tower.png) and the Wizard
    "tower": ("haven", "an Alchemist of a secret order: a scholar-warrior in a long midnight-blue coat with gold trim over a light breastplate, a wide-brimmed dark hat, a leather bandolier of glowing glass flasks across the chest, holding the reins in the left hand and a short brass-tipped rod in the right hand resting on the thigh, sitting naturally in the saddle (NO lance, NO spear, NO helmet)"),
    "wizard": ("haven", "a Wizard: a bearded sage in flowing white-and-gold robes under a deep blue hooded mantle, holding upright a tall staff topped with a glowing pale-blue crystal in the right hand, the reins in the left (NO lance, NO armour, NO helmet)"),
    # session68: Agartha: their faction figure (an Overlord, battle_dungeon*.png) and the Warlock
    "dungeon": ("haven", "an Overlord of the kingdom beneath the earth: a warlord in heavy dark violet-black plate armour with bronze trim, a horned bronze helm with the visor open, a short dark cape, holding the reins in the left hand and a heavy war-axe resting upright against the right shoulder (NO lance, NO spear)"),
    "warlock": ("haven", "a Warlock of the inner world: a sorcerer in long deep violet robes with bronze trim and a hood thrown back, a pointed dark beard, holding upright a tall black staff topped with a glowing amber crystal in the right hand, the reins in the left (NO lance, NO armour, NO helmet)"),
    # session68: Eridu: their faction figure (a Lugal, battle_eridu*.png) and the Keeper
    "eridu": ("haven", "a Lugal, a warrior-king of ancient Sumer: a bearded king with long curled black hair and a curled beard, a tall gold horned crown-helmet, a bronze scale cuirass over a fringed kilt of deep lapis blue, a gold-studded belt, a short cloak of blue wool, holding the reins in the left hand and a bronze war-mace with a crystal-inlaid head resting upright against the right shoulder (NO lance, NO spear); the horse in a caparison of lapis blue with gold rosettes"),
    "keeper": ("haven", "a Keeper of the Me, a priest-sage of ancient Sumer: a bearded man in a long fringed robe of white and lapis blue wool, a tall horned crown of gold, a gold collar, holding upright in the right hand a tall gilded staff topped with a glowing pale-blue crystal tablet, the reins in the left (NO lance, NO armour, NO helmet); the horse in a caparison of lapis blue with gold rosettes"),
}
PROMPT = ("The image shows a mounted hero beside a battlefield in a hand-painted fantasy strategy game, seen from the "
          "side, on a flat magenta backdrop. Repaint ONLY the rider as {who}. Keep the horse EXACTLY as it is (same "
          "horse, barding, colours, legs and pose, same position and size in the frame), the same side view facing "
          "right, the same hand-painted style, palette and lighting from the upper left. The background must stay a "
          "perfectly flat, pure magenta (#FF00FF) everywhere: no ground, no shadow, no scenery, no text.")


def _split(fac):
    """The faction figure: its opaque figure on its own, and its translucent cast shadow on its own (dark, and on the
    ground: the soft edges of a lance or a staff's glow up in the air are not shadow)."""
    a = np.asarray(Image.open(f"assets/heroes/battle_{fac}.png").convert("RGBA")).copy()
    fig = a.copy()
    fig[a[..., 3] < 235, 3] = 0
    ys = np.nonzero((a[..., 3] >= 235).any(1))[0]
    ground = ys.min() + 0.6 * (ys.max() - ys.min())  # (below the horse's belly)
    rows = np.arange(a.shape[0])[:, None]
    sh = a.copy()
    sh[(a[..., 3] >= 235) | (a[..., :3].max(2) > 60) | (rows < ground), 3] = 0
    return Image.fromarray(fig, "RGBA"), Image.fromarray(sh, "RGBA")


def _frame(size):
    s = min(W * 0.9 / size[0], H * 0.9 / size[1])
    return s, int((W - size[0] * s) / 2), int((H - size[1] * s) / 2)


def prep(names=None):
    os.makedirs(f"{BATCH}/in", exist_ok=True)
    for cls, (fac, _) in CLASSES.items():
        if names and cls not in names:
            continue
        fig, _ = _split(fac)
        s, x, y = _frame(fig.size)
        canvas = Image.new("RGBA", (W, H), MAGENTA + (255,))
        canvas.alpha_composite(fig.resize((int(fig.width * s), int(fig.height * s)), Image.LANCZOS), (x, y))
        canvas.convert("RGB").save(f"{BATCH}/in/{cls}.png")
        print("prep", cls)


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
    for cls, (fac, _) in CLASSES.items():
        if names and cls not in names:
            continue
        p = f"{BATCH}/out/{cls}.png"
        if not os.path.exists(p):
            continue
        fig, shadow = _split(fac)
        s, x, y = _frame(fig.size)
        cut = drop_specks(key_out(Image.open(p).convert("RGB").resize((W, H), Image.LANCZOS)), keep=0.08)
        # back onto the sprite's canvas where the figure was painted from
        cut = cut.crop((x, y, x + int(fig.width * s), y + int(fig.height * s))).resize(fig.size, Image.LANCZOS)
        # hooves on the old line: shift by the difference of the lowest solid rows
        oa, na = np.asarray(fig)[..., 3] > 128, np.asarray(cut)[..., 3] > 128
        dy = int(np.nonzero(oa.any(1))[0].max()) - int(np.nonzero(na.any(1))[0].max())
        out = shadow.copy()
        out.alpha_composite(cut, (0, dy))
        out.save(f"assets/heroes/battle_{cls}.png")
        print("ingested", cls, "dy", dy)


if __name__ == "__main__":
    {"prep": lambda: prep(sys.argv[2:]), "paint": lambda: paint(sys.argv[2:]), "ingest": lambda: ingest(sys.argv[2:])}[sys.argv[1]]()
