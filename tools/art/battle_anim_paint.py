"""Battle hero animation, as the classic game (the heroes beside the battlefield idle now and then and act out every
spell they cast): a 4-frame idle loop and a casting pose for each class's battle figure.
python tools/art/battle_anim_paint.py prep           ->  imagegen/batch33/in/<fig>_idle.png (2x2 sheet), <fig>_cast.png
python tools/art/battle_anim_paint.py paint [names]  ->  imagegen/batch33/out/... (names: haven cleric necropolis death_knight)
python tools/art/battle_anim_paint.py ingest         ->  assets/heroes/battle_<fig>_idle<0-3>.png, battle_<fig>_cast.png

Every frame is painted from the standing figure (heroes/battle_<fig>.png) on magenta, so the horse and rider stay the
same. Ingest keys each frame out, scales it back, stands it on the figure's own feet (the legs' centre and the lowest
hoof) on the same canvas, and lays it over the figure's cast shadow (hero_class_paint._split), so battle.gd can swap
the textures in place."""
import os, sys
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from pose_paint import key_out, drop_specks, shadow as cast_shadow
from hero_class_paint import _split
from map_class_paint import _feet

BATCH = "imagegen/batch33"
D = "assets/heroes"
MAGENTA = (255, 0, 255)
CELL_W, CELL_H = 1376, 768  # 2x2 cells: a 16:9 sheet
W, H = 1920, 1080  # one cast pose: 16:9
FIGS = {
    "haven": ("a knight in plate armour on an armoured horse, holding a tall lance upright",
              "raises his free right hand high, open palm, a soft golden light shining from it, the lance still upright"),
    "cleric": ("a cleric in a white and blue robe, a flanged gold mace resting on the shoulder",
               "raises the gold mace high overhead, a radiant golden holy glow around its head"),
    "necropolis": ("a hooded necromancer on a skeletal horse, holding a tall skull-topped staff",
                   "raises the skull staff high overhead, the skull blazing with green necromantic light"),
    "death_knight": ("a death knight in black spiked armour on a skeletal horse, holding a huge jagged sword upright",
                     "raises the huge sword high overhead, a sickly green glow along the blade"),
    "tower": ("an alchemist in a midnight-blue coat and wide-brimmed hat with a bandolier of glowing flasks, a brass rod "
              "resting on the thigh", "raises the brass rod high, a swirl of golden alchemical light around its tip"),
    "wizard": ("a wizard in white-and-gold robes and a blue hooded mantle, holding a tall crystal-topped staff upright "
               "in the right hand in every frame (he never lets go of the staff)",
               "raises the crystal staff high overhead, the crystal blazing with pale-blue light"),
    "dungeon": ("an overlord in dark violet-black plate armour with bronze trim and a horned helm, a war-axe resting "
                "against the shoulder", "raises the war-axe high overhead, a dark violet glow along its blade"),
    "warlock": ("a warlock in deep violet robes with bronze trim, holding a tall black staff topped with an amber crystal "
                "upright in the right hand in every frame (he never lets go of the staff)",
                "raises the black staff high overhead, the amber crystal blazing with fiery light"),
}
IDLE = ("The image shows the same mounted hero four times, {who}, from the battle screen of a hand-painted fantasy "
        "strategy game, side view facing right, on a flat magenta backdrop. Repaint the four cells as the four frames "
        "of a gentle idle animation: top left as it is; top right the horse lowers its head a little and swishes its "
        "tail; bottom left the horse lifts one front hoof a little and whatever loose cloth the rider already wears "
        "sways; bottom right the horse raises its head again, almost as at the start. The rider keeps the same pose, "
        "the same clothes and armour and holds the same weapon, the same length, in every cell: add nothing (no new "
        "cloak, cape or banner); the horse stays in place, its standing hooves on the same line and the same size. Same "
        "hand-painted style, palette and lighting from the upper left. The background must stay a perfectly flat, pure "
        "magenta (#FF00FF) everywhere: no ground, no shadow, no grid lines, no text.")
CAST = ("The image shows a mounted hero, {who}, from the battle screen of a hand-painted fantasy strategy game, side "
        "view facing right, on a flat magenta backdrop. Repaint ONLY the rider casting a spell: the rider {cast}. Keep "
        "the horse EXACTLY as it is (same horse, barding, colours, legs and pose, same position and size), the same "
        "hand-painted style, palette and lighting from the upper left. The background must stay a perfectly flat, pure "
        "magenta (#FF00FF) everywhere: no ground, no shadow, no scenery, no text.")


def _fig(name):
    fig, _ = _split(name)
    return fig


def _place(img, size, s, cw, ch):
    """The figure scaled by s, standing at 88% of a cw x ch cell's height, centred: (image, x, y)."""
    big = img.resize((int(img.width * s), int(img.height * s)), Image.LANCZOS)
    return big, (cw - big.width) // 2, int(ch * 0.88) - big.height


def prep(names=None):
    os.makedirs(f"{BATCH}/in", exist_ok=True)
    for name in FIGS:
        if names and name not in names:
            continue
        fig = _fig(name)
        c = fig.crop(fig.getbbox())
        s = min(CELL_W * 0.8 / c.width, CELL_H * 0.8 / c.height)
        sheet = Image.new("RGBA", (CELL_W * 2, CELL_H * 2), MAGENTA + (255,))
        for k in range(4):
            big, x, y = _place(c, c.size, s, CELL_W, CELL_H)
            sheet.alpha_composite(big, ((k % 2) * CELL_W + x, (k // 2) * CELL_H + y))
        sheet.convert("RGB").save(f"{BATCH}/in/{name}_idle.png")
        s2 = min(W * 0.55 / c.width, H * 0.75 / c.height)  # (room above the head for a raised weapon)
        canvas = Image.new("RGBA", (W, H), MAGENTA + (255,))
        big, x, y = _place(c, c.size, s2, W, H)
        canvas.alpha_composite(big, (x, y))
        canvas.convert("RGB").save(f"{BATCH}/in/{name}_cast.png")
        print("prep", name, round(s, 3), round(s2, 3))


def paint(names):
    from google import genai
    import vertex_paint as vp
    client = genai.Client(vertexai=True, project=vp.PROJECT, location=vp.LOCATION)
    os.makedirs(f"{BATCH}/out", exist_ok=True)
    for name, (who, cast) in FIGS.items():
        if names and name not in names:
            continue
        for kind, prompt in [("idle", IDLE.format(who=who)), ("cast", CAST.format(who=who, cast=cast))]:
            img = vp.paint(client, "gemini-nano-banana-2.1", f"{BATCH}/in/{name}_{kind}.png", prompt, "16:9", "2K")
            if img:
                img.save(f"{BATCH}/out/{name}_{kind}.png"); print("done", name, kind, flush=True)
            else:
                print("FAILED", name, kind, flush=True)


def _stand(cut, fig, _shadow, out_path):
    """A keyed frame (at sprite scale) on the figure's canvas, its feet on the figure's feet, with a cast shadow of its
    own outline (the standing figure's painted shadow had a hole where its own outline was, which showed as a light
    fringe around a frame that differs a little)."""
    oa = np.asarray(fig)[..., 3]
    na = np.asarray(cut)[..., 3]
    f = float(np.clip(np.sqrt((oa > 128).sum() / max(1, (na > 128).sum())), 0.9, 1.1))
    if abs(f - 1) > 0.02:
        cut = cut.resize((max(1, int(cut.width * f)), max(1, int(cut.height * f))), Image.LANCZOS)
        na = np.asarray(cut)[..., 3]
    ox, oy = _feet(oa)
    nx, ny = _feet(na)
    layer = Image.new("RGBA", fig.size, (0, 0, 0, 0))
    layer.paste(cut, (int(round(ox - nx)), int(round(oy - ny))))  # (paste: a raised weapon may reach past the top)
    la = np.asarray(layer)[..., 3]
    sha = cast_shadow(la, ox, oy)
    out = Image.fromarray(np.dstack([np.full(la.shape + (3,), (12, 10, 8), np.uint8), (sha * 255).astype(np.uint8)]), "RGBA")
    Image.alpha_composite(out, layer).save(out_path)


def ingest(names=None):
    for name in FIGS:
        if names and name not in names:
            continue
        fig, shadow = _split(name)
        c = fig.crop(fig.getbbox())
        p = f"{BATCH}/out/{name}_idle.png"
        if os.path.exists(p):
            s = min(CELL_W * 0.8 / c.width, CELL_H * 0.8 / c.height)
            sheet = Image.open(p).convert("RGB").resize((CELL_W * 2, CELL_H * 2), Image.LANCZOS)
            for k in range(4):
                cx, cy = (k % 2) * CELL_W, (k // 2) * CELL_H
                cut = drop_specks(key_out(sheet.crop((cx + 4, cy + 4, cx + CELL_W - 4, cy + CELL_H - 4))), keep=0.2)
                cut = cut.crop(cut.getbbox())
                cut = cut.resize((max(1, int(cut.width / s)), max(1, int(cut.height / s))), Image.LANCZOS)
                _stand(cut, fig, shadow, f"{D}/battle_{name}_idle{k}.png")
            print("ingested", name, "idle")
        p = f"{BATCH}/out/{name}_cast.png"
        if os.path.exists(p):
            s2 = min(W * 0.55 / c.width, H * 0.75 / c.height)
            cut = drop_specks(key_out(Image.open(p).convert("RGB").resize((W, H), Image.LANCZOS)), keep=0.2)
            cut = cut.crop(cut.getbbox())
            cut = cut.resize((max(1, int(cut.width / s2)), max(1, int(cut.height / s2))), Image.LANCZOS)
            _stand(cut, fig, shadow, f"{D}/battle_{name}_cast.png")
            print("ingested", name, "cast")


if __name__ == "__main__":
    {"prep": lambda: prep(sys.argv[2:]), "paint": lambda: paint(sys.argv[2:]), "ingest": lambda: ingest(sys.argv[2:])}[sys.argv[1]]()
