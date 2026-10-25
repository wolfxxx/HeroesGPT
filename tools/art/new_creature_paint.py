"""New creatures painted by an image model over an existing creature's idle figure and portrait (its pose, size and
framing), as upgrade_paint.py does for upgrades but as a different being.
python tools/art/new_creature_paint.py prep [ids]     ->  imagegen/batch36/in/nc__<id>.png, ncport__<id>.png + new.json
python tools/art/new_creature_paint.py paint [ids]    ->  imagegen/batch36/out/...
python tools/art/new_creature_paint.py ingest [ids]   ->  assets/creatures/<id>.png (+ anchors.json), portraits/<id>.png
(ids: only those; none: every one. An upgrade painted over a new creature (the Titan over the Giant) is prepped
after its base is ingested.)
Then the poses and move cycles come from the usual tools, which paint only what is missing:
python tools/art/pose_paint.py prep <ids>; python tools/art/vertex_paint.py --batch imagegen/batch6; pose_paint ingest
python tools/art/cycle_paint.py prep <ids>; python tools/art/vertex_paint.py --batch imagegen/batch8; cycle_paint ingest
python tools/art/sprite_sizes.py <id>.png <id>_attack.png ..."""
import os, sys, json
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import upgrade_paint as up

BATCH = "imagegen/batch36"
D = "assets/creatures"
# new id -> (base creature whose figure and portrait it is painted over, what it is)
NEW = {
    "gold_golem": ("swordsman", "a Gilded Ushabti: an ancient Egyptian tomb figurine come to life as a man-sized warrior "
                   "statue, its whole body of gilded wood and beaten gold, mummiform and stiff, with a striped blue-and-gold "
                   "nemes headdress, a calm painted face with kohl-lined eyes, bands of painted hieroglyphs down its body, "
                   "holding a bronze khopesh sword point-down in front of it where the knight holds his sword"),
    "diamond_golem": ("swordsman", "a Crystal Ushabti: an ancient Egyptian tomb figurine come to life as a man-sized "
                      "warrior statue carved from clear rock crystal, faintly glowing pale blue inside, with gold inlay, a "
                      "lapis-lazuli striped nemes headdress, a calm carved face, hieroglyphs etched down its body, holding "
                      "a gold khopesh sword point-down in front of it where the knight holds his sword"),
    "mummy": ("zombie", "a Mummy: an ancient Egyptian mummy risen from its tomb, its gaunt body tightly wrapped in "
              "yellowed, age-stained linen bandages with loose torn strips trailing, a faded painted gold collar and a "
              "scarab amulet on its chest, dark empty eye sockets with a faint green glow, reaching forward with "
              "bandaged hands, shambling"),
    # session67: HoMM3's Tower and Dungeon top creatures (the upgrades painted over their new base, as upgrade_paint)
    "giant": ("zealot", "a Giant: a towering, broad-shouldered bearded man of enormous strength, his skin weathered, in "
              "a short belted tunic of rough undyed wool, bare muscular arms with heavy gold armbands, a plain gold "
              "circlet on his brow, leather sandals, his arms held out with big clenched fists where the figure's hands "
              "are, no glow, no magic"),
    "titan": ("giant", "a Titan: a colossal warrior-god in gleaming gold-and-white plate armour over a white tunic, a "
              "crested gold Greek helmet, a short white cloak, the same build and stance as the giant, crackling blue-"
              "white lightning gathered in both hands where the figure's fists are, small sparks around them"),
    "red_dragon": ("bone_dragon", "a Red Dragon: a living dragon with gleaming crimson-red scales, a paler golden belly, "
                   "large leathery red wings with dark ribs, curved ivory horns, glowing amber eyes and a wisp of smoke "
                   "curling from its jaws, standing in the same pose, all flesh and scales, no bones showing"),
    "black_dragon": ("red_dragon", "a Black Dragon: a huge living dragon with glossy jet-black scales with a dark "
                     "violet sheen, black leathery wings, black horns with red tips, burning red eyes and faint red "
                     "embers between its teeth, standing in the same pose"),
    # session67: the Illuminated (HoMM3's Tower), the alchemists' order: white, midnight blue and gold
    "homunculus": ("skeleton", "a Homunculus: a small wizened artificial man the size of a child, grown by alchemists in a "
                   "glass flask, pale waxy skin, a bald head, large dark eyes, a ragged leather apron, dragging a heavy "
                   "iron ball on a chain in one hand"),
    "master_homunculus": ("homunculus", "a Master Homunculus: the same small pale artificial man, now in a stitched "
                          "alchemist's leather coat with brass goggles pushed up on his bald head and a bandolier of "
                          "glowing green glass flasks across his chest, holding one flask ready to throw"),
    "gargoyle": ("vampire", "a Gargoyle: a winged grotesque of weathered grey cathedral stone come to life, horned, with a "
                 "snarling face, clawed hands and feet and stony bat wings, crouched ready to spring"),
    "obsidian_gargoyle": ("gargoyle", "an Obsidian Gargoyle: the same winged stone grotesque carved from glossy black "
                          "volcanic glass with sharp chipped edges and a faint violet sheen, its eyes glowing violet"),
    "stone_golem": ("swordsman", "a Stone Golem: the golem of old Prague, a huge heavy man-shaped figure of grey clay and "
                    "stone, crudely shaped, with a broad chest, thick arms ending in big stone fists, empty dark eyes and "
                    "a small glowing sigil on its forehead, no armour, no weapon"),
    "iron_golem": ("stone_golem", "an Iron Golem: the same massive man-shaped figure forged of riveted dark iron plates, "
                   "furnace-orange glowing eyes, a glowing sigil on its forehead, big iron fists, no weapon"),
    "magus": ("monk", "a Magus: a sage of a secret alchemists' order in a long hooded midnight-blue robe trimmed with "
              "gold, a grey beard, a gold clasp shaped like an eye in a triangle on his cloak, holding a staff topped "
              "with a glowing pale-blue crystal, the other hand raised with a soft blue glow"),
    "arch_magus": ("magus", "an Arch Magus: a grander sage in flowing white-and-gold robes under a deep blue mantle, a gold "
                   "circlet on his brow, a long white beard, holding a tall staff topped with a radiant crystal sphere"),
    "genie": ("ghost", "a Genie: a djinn bound by King Solomon's ring, a muscular blue-skinned spirit with a white turban "
              "and a gold armlet, bare-chested, his body tapering below the waist into a swirl of pale-blue smoke, "
              "floating, fists clenched"),
    "master_genie": ("genie", "a Master Genie: a greater djinn with deep violet skin, a jeweled gold turban with a white "
                     "plume, gold bracers and a crimson sash, his lower body a swirl of violet smoke, floating, one hand "
                     "raised holding a small glowing golden orb"),
    "naga": ("cavalier", "a Naga: a serpent woman, her upper body a stern warrior woman in a gold breastplate and a gold "
             "helm, with six arms each holding a curved sword, her lower body a long coiled green-scaled snake tail "
             "lying along the ground behind her, upright and poised to strike"),
    "naga_queen": ("naga", "a Naga Queen: the same six-armed serpent warrior woman, crowned with a tall gold crown, in "
                   "jewelled gold armour, her six curved swords gleaming, her long snake tail emerald and gold"),
}
IDLE = ("This is a battle unit sprite from a fantasy strategy game. Redraw it as a DIFFERENT creature in exactly the same "
        "side view facing right, the same pose, the same size in the frame, standing on the same ground line at the same "
        "spot: {desc}. Nothing of the original creature's clothes, armour or face remains. Same hand-painted style and lighting "
        "from the upper left. Keep the whole figure inside the frame.\nThe background must stay a perfectly flat, pure "
        "magenta (#FF00FF) everywhere around the figure: no ground, no cast shadow, no scenery, no effects, no text.")
PORT = ("This is a creature portrait from a fantasy strategy game (the unit portrait shown when recruiting). Repaint it "
        "as a DIFFERENT creature: {desc}. " + up.STYLE + "\nKeep the same framing, camera angle and the head in the same "
        "place, and the same soft painted background in warm brown and amber colours. Square image. No text, no border, "
        "no frame, no signature.")


def prep(ids=None):
    os.makedirs(f"{BATCH}/in", exist_ok=True)
    pj = f"{BATCH}/in/new.json"
    info = json.load(open(pj)) if ids and os.path.exists(pj) else {}
    for nid, (base, _) in NEW.items():
        if ids and nid not in ids:
            continue
        canvas, origin, s, r = up.idle_canvas(base)
        canvas.convert("RGB").save(f"{BATCH}/in/nc__{nid}.png")
        info[nid] = {"base": base, "origin": origin, "scale": s, "ratio": r}
        Image.open(f"{D}/portraits/{base}.png").convert("RGB").resize((1024, 1024), Image.LANCZOS).save(
            f"{BATCH}/in/ncport__{nid}.png")
    json.dump(info, open(f"{BATCH}/in/new.json", "w"), indent=1)
    print(len(info), "new creatures")


def paint(ids):
    from google import genai
    import vertex_paint as vp
    client = genai.Client(vertexai=True, project=vp.PROJECT, location=vp.LOCATION)
    info = json.load(open(f"{BATCH}/in/new.json"))
    os.makedirs(f"{BATCH}/out", exist_ok=True)
    for nid, (base, desc) in NEW.items():
        if ids and nid not in ids:
            continue
        for name, prompt, ratio in [(f"nc__{nid}", IDLE.format(desc=desc), info[nid]["ratio"]),
                                    (f"ncport__{nid}", PORT.format(desc=desc), "1:1")]:
            img = vp.paint(client, "gemini-nano-banana-2.1", f"{BATCH}/in/{name}.png", prompt, ratio, "2K")
            if img:
                img.save(f"{BATCH}/out/{name}.png"); print("done", name, flush=True)
            else:
                print("FAILED", name, flush=True)


def ingest(ids=None):
    info = json.load(open(f"{BATCH}/in/new.json"))
    anchors = json.load(open(f"{D}/anchors.json"))
    for nid, d in info.items():
        if ids and nid not in ids:
            continue
        src = f"{BATCH}/out/nc__{nid}.png"
        if os.path.exists(src):
            up.ingest_figure(src, f"{BATCH}/in/nc__{nid}.png", d["base"], d["scale"], nid, anchors, grow=1.15)
        ps = f"{BATCH}/out/ncport__{nid}.png"
        if os.path.exists(ps):
            Image.open(ps).convert("RGB").resize((256, 256), Image.LANCZOS).save(f"{D}/portraits/{nid}.png")
    json.dump(anchors, open(f"{D}/anchors.json", "w"), indent=0, sort_keys=True)


if __name__ == "__main__":
    {"prep": lambda: prep(sys.argv[2:]), "paint": lambda: paint(sys.argv[2:]), "ingest": lambda: ingest(sys.argv[2:])}[sys.argv[1]]()
