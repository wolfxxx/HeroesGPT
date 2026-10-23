"""One siege backdrop per fortification level (as the classic game: a Fort has a wall and a gate, a Citadel adds the
keep and the moat, a Castle the two round arrow towers at the ends of the wall), each with its own breach overlays.
python tools/art/siege_levels_paint.py collage            ->  imagegen/batch28/in/collage_<faction>.png (layout guide)
python tools/art/siege_levels_paint.py paint [names...]   ->  imagegen/batch28/out/<level>_<faction>.png
python tools/art/siege_levels_paint.py breach [names...]  ->  imagegen/batch28/out/breach_<level>_<faction>_<seg>.png
python tools/art/siege_levels_paint.py retop              ->  the Castle's lower tower gets a battlement top (then breach
                                                              breach_castle_<faction>_5/6 again, then ingest)
python tools/art/siege_levels_paint.py damage [names...]  ->  imagegen/batch28/out/dmg_<level>_<faction>_<seg>.png (hit once)
python tools/art/siege_levels_paint.py ingest             ->  assets/battle/bg_siege_<faction>_<level>.png,
                                                              assets/battle/siege_<faction>_<level>_{ruin,dmg}_<seg>.png,
                                                              assets/battle/siege.json ("<faction>_<level>": positions)
Levels: 1 fort, 2 citadel, 3 castle.

The wall now matches the rules' segments (battle_logic.gd SEGMENTS): a corner tower on row 0 and row 10 (Castle only;
otherwise the wall runs on to the picture's edges), wall stretches on rows 1-2, 3-4, 6-7 and 8-9, the gate on row 5.
The collage moves pieces of the first siege painting (siege_wall_paint.py, whose towers covered rows 0-2 and 6-10)
into that layout; the model repaints it into one picture (the Castle); the Citadel is the Castle with its two round
towers replaced by more wall, the Fort the Citadel without the keep and the moat. Breaches are repainted crops, one
per segment and level, as in siege_wall_paint.py."""
import os, sys, json
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(__file__))

BATCH = "imagegen/batch28"
FACTIONS = ["haven", "necropolis"]
LEVELS = {1: "fort", 2: "citadel", 3: "castle"}

# battle.gd geometry (1920x1080)
HEX_W, ROW_STEP, X0, Y0 = 96.0, 68.0, 264.0, 272.0
WALL_X, MOAT_X = 11, 10
SEGMENTS = [[0], [1, 2], [3, 4], [5], [6, 7], [8, 9], [10]]  # battle_logic.gd SEGMENTS


def hex_pos(x, y):
    return X0 + x * HEX_W + (HEX_W * 0.5 if y % 2 else 0.0), Y0 + y * ROW_STEP


def row_y(r):
    return Y0 + r * ROW_STEP


# The screen band (y) each segment owns: halfway between its rows and the next segment's (the towers to the edges).
BANDS = [(0, 306), (306, 442), (442, 578), (578, 646), (646, 782), (782, 918), (918, 1080)]

# pieces of the first painting (1920x1080): the walk between the old upper tower and the gatehouse, the gatehouse,
# the two towers
WALK = (1290, 300, 1376, 370)       # one stretch of wall walk with its merlons (tiles every 70 px)
GATEHOUSE = (1240, 392, 1430, 668)  # from its battlements to the foot of the gate
UPPER = (1238, 0, 1436, 300)        # the old upper tower, roof to its door (its foot is cut off)
LOWER = (1240, 560, 1440, 1080)     # the old lower tower, roof to the bottom edge


def _paste_mask(size, feather=10):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rectangle((feather, feather, size[0] - feather, size[1] - feather), fill=255)
    return m.filter(ImageFilter.GaussianBlur(feather / 2))


def collage(fac):
    old = Image.open(f"imagegen/batch25/out/wall_{fac}.png").convert("RGB").resize((1920, 1080), Image.LANCZOS)  # (the first siege)
    out = old.copy()
    # clear the old towers' footprint above and below the gatehouse back to the courtyard / town behind: the town
    # band right of the wall (x 1440-1480) stretched over it, so the model sees open ground there, not stone
    for y0, y1 in [(0, GATEHOUSE[1] + 6), (GATEHOUSE[3] - 6, 1080)]:
        strip = old.crop((1440, y0, 1500, y1)).resize((200, y1 - y0))
        out.paste(strip, (1238, y0))
    # the moat keeps running up and down beside the wall: its old column, left of the towers, stays as it was
    out.paste(old.crop((1150, 0, 1238, 1080)), (1150, 0))
    # the wall walk, edge to edge, centred on the wall column
    walk = old.crop(WALK)
    xw = 1290
    for y in range(-10, 1080, WALK[3] - WALK[1]):
        out.paste(walk, (xw, y))
    # the gatehouse where it stood (its gate already sits on row 5, before the drawbridge)
    gh = old.crop(GATEHOUSE)
    out.paste(gh, GATEHOUSE[:2], _paste_mask(gh.size, 6))
    # (the old lower tower's spire rose in front of the foot of the gate: the door and the passage instead)
    d = ImageDraw.Draw(out)
    door = old.getpixel((1338, 560))
    floor = old.getpixel((1335, 655))
    d.rectangle((1318, 572, 1362, 612), fill=door)
    d.rectangle((1318, 612, 1362, 668), fill=floor)
    # the upper tower, standing on row 0: its base just below the row
    up = old.crop(UPPER)
    shift = int(row_y(0) - 70 - UPPER[3])  # (the model lengthens its foot by about a row)
    out.paste(up, (UPPER[0], UPPER[1] + shift), _paste_mask(up.size, 6))
    # the lower tower, squat, on row 10 at the bottom edge: its roof (whose peak was 15 px under the crop's top)
    # must not rise over rows 8-9, whose stretch of wall has to show its breach
    lo = old.crop(LOWER)
    k = 0.8
    lo = lo.resize((int(lo.width * k), int(lo.height * k)), Image.LANCZOS)
    x = int((LOWER[0] + LOWER[2]) / 2 - lo.width / 2) + 8
    out.paste(lo, (x, int(row_y(9) - 24)), _paste_mask(lo.size, 6))
    os.makedirs(f"{BATCH}/in", exist_ok=True)
    out.save(f"{BATCH}/in/collage_{fac}.png")
    print("collage", fac)


CASTLE = ("This picture is a rough collage of pieces of a hand-painted castle siege battlefield from a fantasy strategy "
          "game: a castle wall runs straight down the middle-right of the picture from the top edge to the bottom edge, with "
          "a gatehouse and closed wooden gate in its middle before a lowered drawbridge over the moat, a tall round arrow "
          "tower with a conical roof at its top end, a smaller round arrow tower with a conical roof at its bottom end, and "
          "a big round keep tower on the far right (which must stay in the picture, as big as it is). Repaint it as ONE seamless, finished picture in the same "
          "painted style. " + "{style}" + "\n"
          "VERY IMPORTANT: keep every piece exactly where it is and the same size: the wall, the gatehouse and gate, the "
          "two round towers, the keep, the moat and the drawbridge must line up with a game grid laid over the picture "
          "later. The tall top tower stands only at the very top: its round foot ends just below its door, where the wall walk "
          "starts; from there down to the gatehouse the wall walk is a FREE-STANDING stretch of wall (as long as the "
          "tower is wide), with the moat on its left and the town's roofs on its right showing on both sides of it; the "
          "tower's body does NOT reach down beside it. The wall between the gatehouse and each tower is a plain straight stretch of crenellated curtain wall "
          "with its wall walk (seen from high above, as in the collage), with no doors, towers or turrets on it. Clean up "
          "the seams: where the collage shows stretched or repeated scraps beside the wall, paint the courtyard of trodden "
          "earth and flagstones (lower half) or the roofs of the town behind (upper half), matching their surroundings. "
          "The moat of dark water runs along the left foot of the wall all the way from the top edge to the bottom edge. "
          "Keep the left two thirds of the picture (grass, sky, mountains) exactly as it is. No units, no people, no "
          "grid, no text.")

CITADEL = ("This is a castle siege battlefield from a fantasy strategy game. Paint EXACTLY the same picture, same camera, "
           "every shape in the same place, with one change: REMOVE the two round towers at the top and bottom ends of the "
           "castle wall (the one at the top edge and the smaller one at the bottom), roofs and all, and continue the same "
           "plain straight crenellated curtain wall with its wall walk in their place, so the wall runs unbroken from the "
           "top edge of the picture to the bottom edge, as wide as the rest of the wall. Where a tower stood out beside "
           "the wall, paint what is around it: the moat on the left, the courtyard of earth and flagstones or the town's "
           "roofs on the right. Keep the gatehouse, the gate, the drawbridge, the moat, the big keep on the far right, the "
           "sky, the grass and everything else exactly as it is. {style}\nNo units, no people, no text.")

FORT = ("This is a castle siege battlefield from a fantasy strategy game. Paint EXACTLY the same picture, same camera, "
        "every shape in the same place, with two changes: (1) REMOVE the big round keep on the far right completely and "
        "paint the open courtyard of trodden earth and flagstones in its place (the town's houses stay behind, along "
        "the top of the picture: no buildings in the lower half of the picture right of the wall, where soldiers stand); (2) REMOVE the "
        "moat: where the channel of water runs along the left foot of the castle wall, paint the same grass and earth as "
        "the battlefield next to it, and take away the drawbridge, leaving a short dirt path to the gate. Keep the castle "
        "wall, the gatehouse and its closed gate exactly as they are, and the sky, the grass and everything else exactly "
        "as it is. {style}\nNo units, no people, no text.")


def paint(names):
    from google import genai
    import vertex_paint as vp
    client = genai.Client(vertexai=True, project=vp.PROJECT, location=vp.LOCATION)
    os.makedirs(f"{BATCH}/out", exist_ok=True)
    for fac in FACTIONS:
        for lvl in [3, 2, 1]:  # (each level from the one above it)
            n = f"{LEVELS[lvl]}_{fac}"
            if names and n not in names:
                continue
            dst = f"{BATCH}/out/{n}.png"
            if os.path.exists(dst) and not names:
                print("skip", n); continue
            extra = None
            if lvl == 3:
                src = f"{BATCH}/in/collage_{fac}.png"
                prompt = CASTLE.format(style=vp.STYLE)
            else:
                src = f"{BATCH}/in/{n}_from.png"
                Image.open(f"{BATCH}/out/{LEVELS[lvl + 1]}_{fac}.png").convert("RGB").resize((1920, 1080), Image.LANCZOS).save(src)
                prompt = (CITADEL if lvl == 2 else FORT).format(style=vp.STYLE)
            img = vp.paint(client, "gemini-nano-banana-2.1", src, prompt, "16:9", "2K", extra)
            if img:
                img.save(dst); print("done", n, flush=True)
            else:
                print("FAILED", n, flush=True)


# Which segments can fall at each level: the four stretches of wall and the gate; the round towers only with a Castle
# (otherwise rows 0 and 10 are the wall's unbroken ends).
def breakable(lvl):
    return [0, 1, 2, 3, 4, 5, 6] if lvl >= 3 else [1, 2, 3, 4, 5]


_GAP = ("the stretch of curtain wall that runs straight down through the MIDDLE band of the picture (and nothing "
        "else): knock a wide, deep OPEN BREACH right through it, the wall walk and its battlements completely gone and "
        "the wall cut down nearly to the ground, the ground behind showing THROUGH the gap; jagged, stepped broken ends "
        "of the wall stand above and below it, their exposed inner faces in DEEP DARK SHADOW so the thickness of the "
        "wall reads; a low sloping cone of broken blocks and rubble spills out through the gap to the left{moat}; dust")
SEG_WHAT = {
    0: "the tall round tower at the top: smash it to a jagged broken stump, its roof gone, blocks and rubble heaped at "
       "its foot{moat}, a dark hollow inside the broken top",
    1: _GAP, 2: ("the top of the gatehouse: blow its whole crenellated top and the upper part of its front wall away, "
                 "leaving a big ragged open hole down into the gatehouse, its broken inner walls in DEEP DARK SHADOW, "
                 "through which the dirt ground behind is visible; a cone of broken blocks and rubble spills out of the "
                 "hole over the gate arch{moat}"),
    3: ("the gatehouse's gate: smash the gate itself open, the heavy doors torn off their hinges and lying broken and "
        "splintered at its foot, the archway now an open dark passage with the ground behind visible through it; the "
        "gatehouse itself still stands"),
    4: _GAP, 5: _GAP,
    6: "the smaller round tower at the bottom: smash its roof in and blast its body to a jagged broken stump, blocks "
       "and rubble heaped at its foot{moat}",
}
MAT = {"haven": "pale cream limestone, blue slate roofs", "necropolis": "black basalt, dark violet roofs"}
MOAT = {1: "", 2: " and into the moat", 3: " and into the moat"}
BREACH = ("This is a crop of a castle siege battlefield from a fantasy strategy game. Paint EXACTLY the same picture, "
          "same framing, every shape in the same place, but with {what} smashed by catapult fire, a little dust; the stone keeps "
          "exactly its colours and material ({mat}). It must "
          "read at a glance as a hole you can walk through, not a damaged wall. Only that part changes; the top and "
          "bottom edges of the picture, the grass, the courtyard and the town behind stay exactly as they are. {style}"
          "\nNo units, no people, no text.")
TOWER_BREACH = BREACH.replace("It must read at a glance as a hole you can walk through, not a damaged wall. ", "")
BOX = 460  # (square crop around each segment for its breach)


def _breach_box(i):
    y0, y1 = BANDS[i]
    cy = min(max((y0 + y1) // 2, BOX // 2), 1080 - BOX // 2)
    return (1385 - BOX // 2, cy - BOX // 2, 1385 + BOX // 2, cy + BOX // 2)


def breach(names):
    from google import genai
    import vertex_paint as vp
    client = genai.Client(vertexai=True, project=vp.PROJECT, location=vp.LOCATION)
    for fac in FACTIONS:
        for lvl, lname in LEVELS.items():
            wall = Image.open(f"{BATCH}/out/{lname}_{fac}.png").convert("RGB").resize((1920, 1080), Image.LANCZOS)
            for i in breakable(lvl):
                n = f"breach_{lname}_{fac}_{i}"
                if names and n not in names:
                    continue
                dst = f"{BATCH}/out/{n}.png"
                if os.path.exists(dst) and not names:
                    print("skip", n); continue
                src = f"{BATCH}/in/{n}.png"
                wall.crop(_breach_box(i)).resize((1024, 1024), Image.LANCZOS).save(src)
                what = SEG_WHAT[i].format(moat=MOAT[lvl])
                prompt = (TOWER_BREACH if i in (0, 6) else BREACH).format(what=what, style=vp.STYLE, mat=MAT[fac])
                img = vp.paint(client, "gemini-nano-banana-2.1", src, prompt, "1:1", "1K")
                if img:
                    img.save(dst); print("done", n, flush=True)
                else:
                    print("FAILED", n, flush=True)


# A segment hit once (of its two hits) stands battered, as the classic's damaged wall pieces: still whole, no way through.
_BATTERED = ("battered by catapult fire but STILL STANDING AND WHOLE: several merlons of its battlements knocked off, "
             "a few big chunks of stone chipped out of its face leaving rough pale scars with dark shadowed edges, "
             "two or three cracks running along the joints of the masonry, a little rubble and a few loose blocks at "
             "its foot{moat}")
DMG_WHAT = {
    0: "the tall round tower at the top " + _BATTERED,
    1: "the stretch of curtain wall that runs straight down through the MIDDLE band of the picture (and nothing else) "
       + _BATTERED,
    2: "the crenellated top of the gatehouse " + _BATTERED,
    3: ("the gatehouse's gate: its heavy wooden doors battered and splintered, a few planks cracked and broken, an iron "
        "band bent, but the doors still SHUT and the gatehouse itself unchanged"),
    6: "the smaller round tower at the bottom " + _BATTERED,
}
DMG_WHAT[4] = DMG_WHAT[5] = DMG_WHAT[1]
DAMAGE = ("This is a crop of a castle siege battlefield from a fantasy strategy game. Paint EXACTLY the same picture, "
          "same framing, every shape in the same place, but with {what}; the stone keeps exactly its colours and "
          "material ({mat}). There is NO hole or gap through the wall: it still blocks the way. Only that part "
          "changes; the top and bottom edges of the picture, the grass, the courtyard and the town behind stay "
          "exactly as they are. {style}\nNo units, no people, no text.")


def damage(names):
    from google import genai
    import vertex_paint as vp
    client = genai.Client(vertexai=True, project=vp.PROJECT, location=vp.LOCATION)
    for fac in FACTIONS:
        for lvl, lname in LEVELS.items():
            wall = Image.open(f"{BATCH}/out/{lname}_{fac}.png").convert("RGB").resize((1920, 1080), Image.LANCZOS)
            for i in breakable(lvl):
                n = f"dmg_{lname}_{fac}_{i}"
                if names and n not in names:
                    continue
                dst = f"{BATCH}/out/{n}.png"
                if os.path.exists(dst) and not names:
                    print("skip", n); continue
                src = f"{BATCH}/in/{n}.png"
                wall.crop(_breach_box(i)).resize((1024, 1024), Image.LANCZOS).save(src)
                prompt = DAMAGE.format(what=DMG_WHAT[i].format(moat=MOAT[lvl]), style=vp.STYLE, mat=MAT[fac])
                img = vp.paint(client, "gemini-nano-banana-2.1", src, prompt, "1:1", "1K")
                if img:
                    img.save(dst); print("done", n, flush=True)
                else:
                    print("FAILED", n, flush=True)


# The lower tower stands on row 10, at the command bar: only its top shows. Painted with a conical roof, its archer
# stood on the spire; like the upper tower it gets a crenellated fighting top for the archer instead.
RETOP = ("This is a crop of a castle siege battlefield from a fantasy strategy game. Paint EXACTLY the same picture, "
         "same framing, every shape in the same place, except the small round tower at the bottom centre: take off its "
         "pointed conical roof and give it a FLAT crenellated battlement top instead, a ring of square merlons around "
         "an open round fighting platform where an archer can stand, the platform's floor visible; the top of the "
         "merlons where the roof's lower rim is now, the tower's body, width and position unchanged; same stone and "
         "colours ({mat}). The wall, the moat, the grass and the courtyard stay exactly as they are. {style}"
         "\nNo units, no people, no text.")
RETOP_BOX = (1155, 620, 1615, 1080)  # (= _breach_box(6))
RETOP_CUT = (1240, 840, 1490, 1080)  # (only the tower's top is taken from the repaint)


def retop():
    from google import genai
    import vertex_paint as vp
    client = genai.Client(vertexai=True, project=vp.PROJECT, location=vp.LOCATION)
    for fac in FACTIONS:
        p, keep = f"{BATCH}/out/castle_{fac}.png", f"{BATCH}/out/castle_{fac}_cone.png"
        if not os.path.exists(keep):
            Image.open(p).convert("RGB").resize((1920, 1080), Image.LANCZOS).save(keep)
        wall = Image.open(keep).convert("RGB")
        src = f"{BATCH}/in/retop_{fac}.png"
        wall.crop(RETOP_BOX).resize((1024, 1024), Image.LANCZOS).save(src)
        img = vp.paint(client, "gemini-nano-banana-2.1", src, RETOP.format(style=vp.STYLE, mat=MAT[fac]), "1:1", "1K")
        if not img:
            print("FAILED", fac); continue
        img.save(f"{BATCH}/out/retop_{fac}.png")
        bw, bh = RETOP_BOX[2] - RETOP_BOX[0], RETOP_BOX[3] - RETOP_BOX[1]
        new = wall.copy()
        new.paste(img.convert("RGB").resize((bw, bh), Image.LANCZOS), RETOP_BOX[:2])
        m = Image.new("L", wall.size, 0)
        ImageDraw.Draw(m).rectangle(RETOP_CUT, fill=255)
        m = m.filter(ImageFilter.GaussianBlur(10))
        Image.composite(new, wall, m).save(p)
        print("retopped", fac, flush=True)

FEATHER = 24
# (the cut of a segment's overlay: its band, but the gatehouse's top reaches down into the gatehouse and the gate's
# up over the whole door, so each hole reads as a way through)
CUT_BANDS = {2: (380, 540), 3: (490, 668)}


def ingest():
    """Per level the finished backdrop, and per breakable segment a feathered cut of its breach painting and of its
    battered painting (where each differs from the intact wall) with their position on the screen (the same for both)."""
    meta = {}
    for fac in FACTIONS:
        for lvl, lname in LEVELS.items():
            w = f"{BATCH}/out/{lname}_{fac}.png"
            if not os.path.exists(w):
                continue
            wall = Image.open(w).convert("RGB").resize((1920, 1080), Image.LANCZOS)
            wall.save(f"assets/battle/bg_siege_{fac}_{lvl}.png")
            segs = {}
            for i, kind in [(i, k) for i in breakable(lvl) for k in ("breach", "dmg")]:
                bp = f"{BATCH}/out/{kind}_{lname}_{fac}_{i}.png"
                if not os.path.exists(bp):
                    continue
                y0, y1 = CUT_BANDS.get(i, BANDS[i])
                y0, y1 = max(0, y0 - FEATHER // 2), min(1080, y1 + FEATHER // 2)
                x0, x1 = 1200, 1570
                box = (x0, y0, x1, y1)
                bb = _breach_box(i)
                src = wall.copy()
                src.paste(Image.open(bp).convert("RGB").resize((bb[2] - bb[0], bb[3] - bb[1]), Image.LANCZOS), bb[:2])
                a = np.abs(np.asarray(src.crop(box), np.int16) - np.asarray(wall.crop(box), np.int16)).sum(2)
                grow = 25 if i in (0, 6) and kind == "breach" else 9  # (a fallen tower's edge covers its outline)
                m = Image.fromarray(np.clip((a - 18) * 6, 0, 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(grow))
                ma = np.asarray(m.filter(ImageFilter.GaussianBlur(6)), np.float32)
                ramp = np.ones(ma.shape[0], np.float32)
                if y0 > 0:
                    ramp[:FEATHER] = np.linspace(0, 1, FEATHER)
                if y1 < 1080:
                    ramp[-FEATHER:] = np.linspace(1, 0, FEATHER)
                side = np.ones(ma.shape[1], np.float32)
                side[:30] = np.linspace(0, 1, 30)
                side[-70:] = np.linspace(1, 0, 70)
                ma = ma * ramp[:, None] * side[None, :]
                out = src.crop(box).convert("RGBA")
                out.putalpha(Image.fromarray(ma.astype(np.uint8)))
                out.save(f"assets/battle/siege_{fac}_{lvl}_{'ruin' if kind == 'breach' else 'dmg'}_{i}.png")
                segs[str(i)] = [x0, y0]
            meta[f"{fac}_{lvl}"] = segs
            print("ingested", fac, lname)
    json.dump(meta, open("assets/battle/siege.json", "w"), indent=1)


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "collage":
        for f in FACTIONS:
            collage(f)
    elif cmd == "paint":
        paint(sys.argv[2:])
    elif cmd == "breach":
        breach(sys.argv[2:])
    elif cmd == "damage":
        damage(sys.argv[2:])
    elif cmd == "retop":
        retop()
    elif cmd == "ingest":
        ingest()
