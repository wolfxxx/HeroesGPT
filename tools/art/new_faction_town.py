"""A new faction's town screen, painted in another faction's layout (session67: the Illuminated in the Order of the
Dragon's): every layer of the source town (assets/town/<src>_<id>.png at its rect in layout_<src>.json) is shown to the
image model on magenta, padded, and replaced by a DIFFERENT building of the new faction in the same place, size and
view; the backdrop is repainted as the new faction's site with the same ground and horizon. Upgraded dwellings are
painted from the new faction's base dwelling (prep them after ingesting the bases).
python tools/art/new_faction_town.py prep <faction> [ids]    ->  imagegen/batch40/in/<faction>__<id>.png + town.json
python tools/art/new_faction_town.py paint <faction> [ids]   ->  imagegen/batch40/out/<faction>__<id>.png
python tools/art/new_faction_town.py ingest <faction> [ids]  ->  assets/town/<faction>_<id>.png + layout_<faction>.json
(ids: "bg" the backdrop, building / sprite ids; none: every one of the faction's table. A special the source town has
no place for ("extra") is painted over another faction's sprite at a rect of its own.)
python tools/art/new_faction_town.py map <faction> paint|ingest  ->  assets/map/town_<faction>.png (the full castle on
    the adventure map, painted over the source faction's on its canvas, the same anchor; then town_levels_paint.py
    derives the village and the walled town)"""
import os, sys, json
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from pose_paint import key_out, drop_specks

BATCH = "imagegen/batch40"
D = "assets/town"
MAGENTA = (255, 0, 255)
VIEW = (1920, 810)
PAD = 0.12      # room around each layer for a new silhouette
LONG = 1536     # the canvas' long side sent to the model

FACTIONS = {
    "tower": {
        "src": "necropolis",
        "specials": {"library": "necromancy_amplifier", "wall_of_knowledge": "skeleton_transformer"},
        "style": ("It belongs to the town of the Illuminated, a hidden order of alchemists and sages high in snowy "
                  "mountains: white marble and pale stone, gold trim and gold domes, deep blue roofs and blue banners "
                  "with a small gold eye-in-a-triangle, glowing pale-blue crystals and brass instruments, a little "
                  "snow on the roofs and ledges. No religious symbols: no crosses, crescents or six-pointed stars."),
        "map": ("the castle of the Illuminated on the adventure map: a citadel of white marble on a round snowy rock base, "
                "curtain walls with slender round towers capped by gold domes and blue conical spires, a tall central "
                "keep with a gold dome and a small observatory, blue banners, the gate at the front centre"),
        "bg": ("a high mountain plateau above the clouds: jagged snowy peaks and a clear cold sky of pale gold and blue at "
               "the back, a sea of white clouds beyond the far edges, the town site itself a broad plateau of pale stone "
               "flagstones with light snow and a few snowy pines at the sides"),
        "layers": {
            "fort": "the town's fortifications: a long curtain wall of white marble across the back of the town with round "
                    "towers capped by blue conical roofs, a great arched gate with gold doors in the middle, all on a "
                    "snowy rock shelf",
            "citadel": "the town's fortifications grown stronger: the long white marble curtain wall with round towers "
                       "and blue conical roofs, a great gold-doored gate, and behind it a tall square keep with a gold "
                       "dome, on a snowy rock shelf",
            "castle": "the town's full castle: a long white marble curtain wall with tall slender towers capped by gold "
                      "domes and blue spires, a great gold-doored gate, a tall keep with a gold dome and an observatory "
                      "with a great brass telescope, on a snowy rock shelf",
            "village_hall": "a small hall of white stone with a blue roof, a small gold armillary sphere on its ridge and a blue "
                            "banner",
            "town_hall": "a larger hall of white marble with columns in front, a blue roof and a small gold dome",
            "city_hall": "a grand domed hall of white marble with a portico of columns, a large gold dome and blue banners",
            "capitol": "a magnificent palace of white marble and gold with a great golden dome crowned by a gold "
                       "armillary sphere, tall columns and blue and gold banners",
            "tavern": "a cosy inn of pale stone and dark timber with a blue slate roof, warm lit windows and a hanging "
                      "sign showing a golden alembic",
            "marketplace": "a market square with stalls under blue and white striped awnings selling glass flasks, "
                           "books, crystals and brass instruments, crates and barrels between them",
            "mage_guild_1": "a slender round white stone tower with a blue conical roof and a glowing pale-blue crystal "
                            "set on its tip",
            "mage_guild_2": "a tall, many-tiered round white stone wizard tower with gold balconies, a blue conical roof "
                            "and a large glowing pale-blue crystal floating above its tip",
            "blacksmith": "an alchemist's forge of stone with a tall chimney, a furnace glow at its open front, brass pipes "
                          "and an ammunition cart full of shot standing outside",
            "dwelling_1": "the Workshop: a cluttered alchemist's laboratory of stone and dark timber, a round chimney "
                          "puffing green smoke, glass retorts and alembics on the windowsills, a big glass flask by the door",
            "dwelling_2": "the Parapet: a high crenellated stone parapet wall on an arched base, with stone gargoyle "
                          "statues perched along its top",
            "dwelling_3": "the Golem Factory: a heavy stone workshop with a great arched door, a forge glow inside and a "
                          "half-made stone golem standing outside",
            "dwelling_4": "the Mage Tower: a tall round white tower with a blue conical roof, blue banners with gold "
                          "stars, and an open balcony at the top with a brass telescope",
            "dwelling_5": "the Altar of Wishes: an open round shrine of white columns around a great brass oil lamp on a "
                          "pedestal, pale-blue smoke curling up from it",
            "dwelling_6": "the Golden Pavilion: an elegant open pavilion with a curved gold roof on slender white columns "
                          "over a small pool, stone serpent statues at its steps",
            "dwelling_7": "the Cloud Temple: a white marble temple with a gold dome on top of a steep rocky crag, a few "
                          "small puffs of white cloud clinging to the crag's sides (the clouds stay close to the crag, "
                          "well inside the frame, never reaching its edges), a stair of giant steps climbing to it",
            "library": "the Library: a two-storey white stone library with tall arched windows, a small gold-domed "
                       "reading room on top and shelves of books glimpsed inside",
            "wall_of_knowledge": "the Wall of Knowledge: a long white stone wall carved with glowing pale-blue alchemical "
                                 "diagrams, star charts and symbols, a few steps leading up to it",
        },
        "upgrades": {
            "dwelling_1u": "the upgraded Workshop: larger, with brass pipes, bubbling glass vats, a second chimney with "
                           "coloured smoke and glowing green flasks stacked outside",
            "dwelling_2u": "the upgraded Parapet: taller, its stone trimmed with glossy black obsidian, more gargoyles "
                           "along its top and a small watch tower at one end",
            "dwelling_3u": "the upgraded Golem Factory: larger, plated with riveted iron, smoking chimneys and an iron "
                           "golem standing outside",
            "dwelling_4u": "the upgraded Mage Tower: taller and grander, with a gold dome, gold balconies and a great "
                           "brass telescope at the top",
            "dwelling_5u": "the upgraded Altar of Wishes: the round shrine crowned by a gold dome, the great brass lamp "
                           "blazing with golden light",
            "dwelling_6u": "the upgraded Golden Pavilion: grander, with a second gold-roofed tier and jewelled serpent "
                           "statues",
            "dwelling_7u": "the upgraded Cloud Temple: a larger temple with a gleaming gold dome and gold columns, "
                           "lightning flickering in small clouds close around the crag (well inside the frame)",
        },
    },
    # session68: Agartha (HoMM3's Dungeon) in the Order of the Dragon's layout; the Portal of Summoning at the front
    # right, where that town has no building
    "dungeon": {
        "src": "necropolis",
        "specials": {"mana_vortex": "necromancy_amplifier", "battle_scholar_academy": "skeleton_transformer"},
        "extra": {"portal_of_summoning": ("haven", "brotherhood", [1690, 560, 230, 250])},
        "style": ("It belongs to the town of Agartha, the hidden kingdom inside the Hollow Earth: dark violet-black "
                  "basalt and obsidian, dark bronze trim and fittings, dark violet roofs, warm amber lamplight in the "
                  "windows, glowing violet and pale-teal crystals, a few giant mushrooms. Its banners are deep violet "
                  "with a small bronze dragon's claw. No religious symbols: no crosses, crescents or six-pointed stars; "
                  "no black suns or sun wheels."),
        "map": ("the castle of Agartha on the adventure map: a fortress of dark violet-black basalt rising from a round "
                "base of dark rock with glowing violet crystals, curtain walls with round towers under dark violet "
                "conical roofs with bronze finials, a tall central keep with amber-lit windows, a few giant mushrooms "
                "at its foot, violet banners, the gate at the front centre"),
        "bg": ("a vast cavern inside the Hollow Earth: a high vaulted rock ceiling with hanging stalactites fading into a "
               "warm amber haze, far off in the haze a small bright golden inner sun glowing softly (a bright warm orb "
               "of light, never dark, no rays or wheel), distant cliffs with glowing violet crystal veins and thin "
               "waterfalls, the town site itself a broad floor of dark grey-violet flagstones and rock with patches of "
               "glowing pale-teal moss and a few giant mushrooms at the sides"),
        "layers": {
            "fort": "the town's fortifications: a long curtain wall of dark violet-black basalt across the back of the "
                    "town with round towers under dark violet conical roofs, a great arched gate with bronze doors in "
                    "the middle, all on a dark rock shelf",
            "citadel": "the town's fortifications grown stronger: the long dark basalt curtain wall with round towers and "
                       "violet conical roofs, a great bronze-doored gate, and behind it a tall square keep with amber-lit "
                       "windows, on a dark rock shelf",
            "castle": "the town's full castle: a long dark basalt curtain wall with tall towers under violet spires with "
                      "bronze finials, a great bronze-doored gate, a tall keep crowned with glowing violet crystals, on a "
                      "dark rock shelf",
            "village_hall": "a small hall of dark stone with a violet roof, amber-lit windows and a violet banner",
            "town_hall": "a larger hall of dark basalt with heavy square columns in front, a violet roof and bronze trim",
            "city_hall": "a grand hall of dark basalt and obsidian with a portico of heavy columns, a bronze dome and "
                         "violet banners",
            "capitol": "a magnificent palace of black obsidian and bronze with a great bronze dome crowned by a glowing "
                       "violet crystal, tall columns and violet and bronze banners",
            "tavern": "a low inn of rough dark stone built half into a rock, a mushroom-shaped roof of violet slate, warm "
                      "amber-lit windows and a hanging sign showing a bronze tankard",
            "marketplace": "a market under violet and black striped awnings selling glowing crystals, mushrooms, ores "
                           "and bronze wares, crates and barrels between the stalls",
            "mage_guild_1": "a slender dark stone tower with a violet conical roof and a glowing violet crystal set on "
                            "its tip",
            "mage_guild_2": "a tall many-tiered dark stone sorcerer's tower with bronze balconies, a violet conical roof "
                            "and a large glowing violet crystal floating above its tip",
            "blacksmith": "a forge of dark stone with a tall chimney, a lava-red furnace glow at its open front, an anvil "
                          "and a ballista standing outside",
            "dwelling_1": "the Warren: a low rocky mound riddled with dark burrow holes and tunnel mouths, crude wooden "
                          "props, a few glowing mushrooms around it",
            "dwelling_2": "the Harpy Loft: a tall jagged spire of dark rock with ledges and big untidy nests of sticks "
                          "and bones on its top and sides",
            "dwelling_3": "the Pillar of Eyes: a tall pillar of dark violet stone carved with many staring eyes, a large "
                          "glowing amber eye set at its top",
            "dwelling_4": "the Chapel of Stilled Voices: a dark stone sanctum with a pointed arched doorway, stone "
                          "statues of men frozen in terror around its steps, snake carvings on its columns",
            "dwelling_5": "the Labyrinth: a squat round maze of high dark stone walls seen from above, a great horned "
                          "bull's skull carved over its single entrance",
            "dwelling_6": "the Manticore Lair: a craggy cave mouth in a tall rock, gnawed bones at its entrance and deep "
                          "claw marks on the stone",
            "dwelling_7": "the Dragon Cave: a huge dark cave mouth in a tall rocky crag with a red-orange glow and wisps "
                          "of smoke inside, piles of gold glinting at its entrance (all well inside the frame)",
            "mana_vortex": "the Mana Vortex: a round pool of dark stone ringed with glowing violet crystals, a swirling "
                           "vortex of violet and blue magical light spinning up out of it",
            "battle_scholar_academy": "the Battle Scholar Academy: a stern hall of dark stone with a bronze-roofed "
                                      "porch, racks of weapons and shields along its walls and a training yard with "
                                      "a straw target in front",
            "portal_of_summoning": "the Portal of Summoning: a tall arch of dark standing stones carved with glowing "
                                   "violet runes, a swirling violet portal of light inside the arch",
        },
        "upgrades": {
            "dwelling_1u": "the upgraded Warren: a larger burrowed mound with a stone-framed tunnel gate, bronze lamps "
                           "and red-glowing mushrooms around it",
            "dwelling_2u": "the upgraded Harpy Loft: a taller, crueller rock spire, more nests of bones and dark violet "
                           "feathers, iron spikes along its ledges",
            "dwelling_3u": "the upgraded Pillar of Eyes: taller, its many carved eyes glowing red, a great blood-red eye "
                           "at its top",
            "dwelling_4u": "the upgraded Chapel of Stilled Voices: grander, with bronze serpent statues at its doors and "
                           "more frozen stone figures on its steps",
            "dwelling_5u": "the upgraded Labyrinth: larger, its walls topped with bronze spikes and a gold-capped bull's "
                           "skull over the entrance",
            "dwelling_6u": "the upgraded Manticore Lair: a bigger cave in the crag, a scorpion-tail carving over its "
                           "mouth and green venom stains on the rock",
            "dwelling_7u": "the upgraded Dragon Cave: a vast cavern mouth in a black crag, a fierce red glow and smoke "
                           "within, great heaps of gold and black dragon scales at its entrance (all inside the frame)",
        },
    },
}

LAYER = ("This image shows one building of the town screen of a hand-painted fantasy strategy game (in the style of the "
         "classic late-1990s ones), on a flat magenta backdrop. Replace it with a DIFFERENT building: {what}. {style} "
         "Keep the same place, size, footprint and viewpoint (the same elevated front view), the same hand-painted "
         "style with rich colour and lighting from the upper left. Keep the whole building inside the frame. Nothing "
         "of the old building remains. The background must stay a perfectly flat, pure magenta (#FF00FF) everywhere "
         "around the building: no ground, no sky, no cast shadow, no other buildings, no text.")
UPGRADE = ("This image shows one building of the town screen of a hand-painted fantasy strategy game, on a flat magenta "
           "backdrop. Repaint it as its upgraded, grander version: {what}. {style} Keep the same place, footprint and "
           "viewpoint, the same style and lighting from the upper left; it may grow a little. Keep the whole building "
           "inside the frame. The background must stay a perfectly flat, pure magenta (#FF00FF) everywhere: no ground, "
           "no sky, no cast shadow, no other buildings, no text.")
BG = ("This image is the empty backdrop of a fantasy town screen of a hand-painted strategy game (the town's buildings "
      "are drawn over it). Repaint it as {what}. Keep exactly the same horizon line, the same ground shapes and their "
      "height on the picture, the same composition, so that buildings standing where the old ground was still stand on "
      "ground. Hand-painted style, rich colour, lighting from the upper left. No buildings, no people, no text.")


def _table(fac):
    f = FACTIONS[fac]
    return {**f["layers"], **f["upgrades"]}


def _src_id(fac, lid):
    return FACTIONS[fac]["specials"].get(lid, lid)


def _source(fac, lid, lay):
    """The rect and the sprite a layer is painted over: the source town's, or for an extra special another faction's
    sprite at a rect of its own."""
    f = FACTIONS[fac]
    if lid in f.get("extra", {}):
        sf, sid, rect = f["extra"][lid]
        return rect, f"{D}/{sf}_{sid}.png"
    return lay[_src_id(fac, lid)], f"{D}/{f['src']}_{_src_id(fac, lid)}.png"


def prep(fac, ids):
    f = FACTIONS[fac]
    os.makedirs(f"{BATCH}/in", exist_ok=True)
    pj = f"{BATCH}/in/town.json"
    info = json.load(open(pj)) if os.path.exists(pj) else {}
    lay = json.load(open(f"{D}/layout_{f['src']}.json"))
    names = ids or ["bg"] + list(_table(fac))
    for lid in names:
        key = f"{fac}__{lid}"
        if lid == "bg":
            Image.open(f"{D}/{f['src']}_bg.png").convert("RGB").save(f"{BATCH}/in/{key}.png")
            info[key] = {"bg": True}
            continue
        if lid in f["upgrades"]:  # (from the new faction's own base dwelling, once ingested)
            base = lid[:-1]
            nl = json.load(open(f"{D}/layout_{fac}.json"))
            rect, sprite = nl[base], f"{D}/{fac}_{base}.png"
        else:
            rect, sprite = _source(fac, lid, lay)
        x, y, w, h = rect
        px, py = int(w * PAD), int(h * PAD)
        cw, ch = w + 2 * px, h + 2 * py
        canvas = Image.new("RGBA", (cw, ch), MAGENTA + (255,))
        sp = Image.open(sprite).convert("RGBA").resize((w, h), Image.LANCZOS)
        a = np.asarray(sp).copy()
        a[..., 3] = np.where(a[..., 3] > 140, 255, 0)  # (a crisp silhouette on the magenta)
        canvas.alpha_composite(Image.fromarray(a), (px, py))
        s = LONG / max(cw, ch)
        canvas.convert("RGB").resize((int(cw * s), int(ch * s)), Image.LANCZOS).save(f"{BATCH}/in/{key}.png")
        info[key] = {"rect": [x - px, y - py, cw, ch], "ratio": _ratio(cw / ch)}
        print("prep", key, info[key]["rect"])
    json.dump(info, open(pj, "w"), indent=1)


def _ratio(r):
    opts = {"1:1": 1.0, "4:3": 4 / 3, "3:2": 1.5, "16:9": 16 / 9, "21:9": 21 / 9, "3:4": 0.75, "2:3": 2 / 3, "4:5": 0.8,
            "5:4": 1.25, "9:16": 9 / 16}
    return min(opts, key=lambda k: abs(np.log(opts[k] / r)))


def paint(fac, ids):
    from google import genai
    import vertex_paint as vp
    client = genai.Client(vertexai=True, project=vp.PROJECT, location=vp.LOCATION)
    f = FACTIONS[fac]
    info = json.load(open(f"{BATCH}/in/town.json"))
    os.makedirs(f"{BATCH}/out", exist_ok=True)
    for lid in ids or ["bg"] + list(_table(fac)):
        key = f"{fac}__{lid}"
        if key not in info:
            continue
        if lid == "bg":
            prompt, ratio = BG.format(what=f["bg"]), "21:9"
        else:
            tmpl = UPGRADE if lid in f["upgrades"] else LAYER
            prompt, ratio = tmpl.format(what=_table(fac)[lid], style=f["style"]), info[key]["ratio"]
        img = vp.paint(client, "gemini-nano-banana-2.1", f"{BATCH}/in/{key}.png", prompt, ratio, "2K")
        if img:
            img.save(f"{BATCH}/out/{key}.png"); print("done", key, flush=True)
        else:
            print("FAILED", key, flush=True)


def ingest(fac, ids):
    f = FACTIONS[fac]
    info = json.load(open(f"{BATCH}/in/town.json"))
    lp = f"{D}/layout_{fac}.json"
    lay = json.load(open(lp)) if os.path.exists(lp) else {}
    for lid in ids or ["bg"] + list(_table(fac)):
        key = f"{fac}__{lid}"
        src = f"{BATCH}/out/{key}.png"
        if key not in info or not os.path.exists(src):
            continue
        if lid == "bg":
            Image.open(src).convert("RGB").resize(VIEW, Image.LANCZOS).save(f"{D}/{fac}_bg.png")
            print("  bg")
            continue
        x, y, cw, ch = info[key]["rect"]
        cut = drop_specks(key_out(Image.open(src).convert("RGB").resize((cw, ch), Image.LANCZOS)), keep=0.03)
        bb = cut.getbbox()
        if bb is None:
            print("  EMPTY", key); continue
        # (inside the view: a building can't reach past the screen)
        x0, y0 = max(bb[0], -x), max(bb[1], -y)
        x1, y1 = min(bb[2], VIEW[0] - x), min(bb[3], VIEW[1] - y)
        cut.crop((x0, y0, x1, y1)).save(f"{D}/{fac}_{lid}.png")
        lay[lid] = [x + x0, y + y0, x1 - x0, y1 - y0]
        print("  %s %s" % (lid, lay[lid]))
    json.dump(lay, open(lp, "w"), indent=0)


MAP = ("The image shows a town of a hand-painted fantasy strategy game as it stands on the adventure map, seen from a "
       "3/4 top-down view, on a flat magenta backdrop. Repaint it as a DIFFERENT town: {what}. Keep the same viewpoint, "
       "the same round base in the same place and size, the gate at the front centre where heroes stand, the same "
       "hand-painted style and lighting from the upper left. The background must stay a perfectly flat, pure magenta "
       "(#FF00FF) everywhere: no ground around it, no cast shadow, no scenery, no text.")


def map_town(fac, step):
    from pose_paint import shadow
    f = FACTIONS[fac]
    src = Image.open(f"assets/map/town_{f['src']}.png").convert("RGBA")
    inp, out = f"{BATCH}/in/map__{fac}.png", f"{BATCH}/out/map__{fac}.png"
    if step == "paint":
        from google import genai
        import vertex_paint as vp
        a = np.asarray(src).copy()
        a[..., 3] = np.where(a[..., 3] > 200, 255, 0)
        c = Image.new("RGBA", src.size, MAGENTA + (255,))
        c.alpha_composite(Image.fromarray(a))
        c.convert("RGB").resize((1920, int(1920 * src.height / src.width)), Image.LANCZOS).save(inp)
        client = genai.Client(vertexai=True, project=vp.PROJECT, location=vp.LOCATION)
        img = vp.paint(client, "gemini-nano-banana-2.1", inp, MAP.format(what=f["map"]), _ratio(src.width / src.height), "2K")
        if img:
            img.save(out); print("done", out)
        return
    cut = drop_specks(key_out(Image.open(out).convert("RGB").resize(src.size, Image.LANCZOS)), keep=0.03)
    la = np.asarray(cut)[..., 3]
    anchors = json.load(open("assets/map/anchors.json"))
    ax, ay = anchors[f"town_{f['src']}.png"]
    sha = shadow(la, ax * src.width, ay * src.height - 2)
    base = Image.fromarray(np.dstack([np.full(la.shape + (3,), (12, 10, 8), np.uint8), (sha * 255).astype(np.uint8)]), "RGBA")
    Image.alpha_composite(base, cut).save(f"assets/map/town_{fac}.png")
    anchors[f"town_{fac}.png"] = [ax, ay]
    json.dump(anchors, open("assets/map/anchors.json", "w"), indent=0, sort_keys=True)
    print("  map/town_%s.png" % fac, src.size)


if __name__ == "__main__":
    if sys.argv[1] == "map":
        map_town(sys.argv[2], sys.argv[3])
    else:
        {"prep": prep, "paint": paint, "ingest": ingest}[sys.argv[1]](sys.argv[2], sys.argv[3:])
