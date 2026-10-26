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
    # session68: Agartha (HoMM3's Dungeon), the kingdom inside the Hollow Earth: violet, black, bronze and amber
    "morlock": ("skeleton", "a Morlock, one of H. G. Wells's pale folk of the underworld: a small stooped ape-like man "
                "with greyish-white skin, long arms, a hunched back, a shock of pale hair, large milky-white blind eyes, "
                "a ragged loincloth, holding a crude stone-tipped spear"),
    "infernal_morlock": ("morlock", "an Infernal Morlock: the same small stooped pale underworld man, now his skin "
                         "ashen red, small curved horns, a crude bronze collar and leather harness, milky-white blind "
                         "eyes, holding a jagged black obsidian-tipped spear"),
    "harpy": ("vampire", "a Harpy: a fierce winged woman of Greek myth, her upper body a wild-haired woman with a "
              "snarling face, a dark leather harness and a feathered leather vest covering her chest, great brown-and-grey "
              "eagle wings for arms spread wide, the lower body and legs of a bird of prey ending in big hooked talons"),
    "harpy_hag": ("harpy", "a Harpy Hag: the same winged woman, older and crueller, with tangled black hair, dark "
                  "violet-black feathered wings, a dark leather vest covering her chest, a necklace of small bones and longer, "
                  "blood-red talons"),
    "watcher": ("ghost", "a Watcher: a floating orb of mottled grey-green hide the size of a man, with ONE huge central "
                "eye with an amber iris, a wide fanged mouth below it, a few smaller eyes set in the hide around it, and "
                "short limp tentacles hanging underneath (NO eye stalks), hovering above the ground"),
    "evil_eye": ("watcher", "an Evil Eye: the same floating orb, its hide dark violet and scarred, its great eye glowing "
                 "blood-red, the smaller eyes glowing red too, longer barbed tentacles hanging underneath (NO eye "
                 "stalks), hovering above the ground"),
    "medusa": ("naga", "a Medusa: a serpent woman, her upper body a pale green-skinned woman with living green snakes "
               "for hair, a bronze breastplate, holding a recurved bow with an arrow nocked, two arms only, her lower "
               "body a long coiled dark-green snake tail lying along the ground behind her"),
    "medusa_queen": ("medusa", "a Medusa Queen: the same serpent woman with living snakes for hair, crowned with a "
                     "thin bronze crown, in a jewelled violet-and-bronze breastplate, holding a gilded recurved bow with "
                     "an arrow nocked, her long snake tail dark green with violet bands"),
    "minotaur": ("swordsman", "a Minotaur: a huge bull-headed man with a bull's head, long curved horns and a ring in its "
                 "nose, a broad hairy chest, a bronze-studded leather kilt and bracers, hooved bull's legs, gripping a "
                 "heavy double-bladed bronze axe in front of it where the knight holds his sword"),
    "minotaur_king": ("minotaur", "a Minotaur King: the same bull-headed giant, with gold-capped horns and a gold crown "
                      "between them, gold-trimmed black armour plates on its shoulders and chest, gripping a great "
                      "gilded double-bladed axe"),
    "manticore": ("griffin", "a Manticore: a great red-maned lion with a fierce bearded man-like face, huge leathery "
                  "bat-like dark red wings, and a long tail ending in a cluster of sharp spikes"),
    "scorpicore": ("manticore", "a Scorpicore: the same winged lion with a man-like face, its hide darker, its wings "
                   "violet-black, its tail a segmented scorpion's tail with a glistening venomous sting"),
    # session68: Eridu, the Anunnaki of Sumerian myth (docs/ERIDU.md): ancient Mesopotamia first (bronze, lapis,
    # blue-glazed brick, gold), their star-science only a cold crystal glow; nothing modern, no metal robots
    "lulu": ("pikeman", "a Lulu, one of the clay-shaped workers of Sumerian myth: a lean, bare-chested dark-haired man "
             "with sun-browned skin and blue tattooed lines on his arms and chest, a short white wool kilt with a "
             "fringed hem, bare feet, holding a simple bronze-headed spear upright where the figure holds its weapon"),
    "adamu": ("lulu", "an Adamu, the perfected first of the Sumerian workers: the same lean man, taller and prouder, "
              "his tattoos glowing faintly cold blue, a fringed kilt of blue-dyed wool with a bronze-studded leather "
              "belt, a small round bronze shield on his arm, holding a longer bronze spear with a leaf-shaped blade"),
    "igigi": ("archer", "an Igigi, a sky-watcher of Sumerian myth: a slender bearded man in a tall conical cap and a "
              "long fringed robe of pale blue wool, a bronze bracer, drawing a short curved bow of dark wood and bronze "
              "whose arrow is a thin shaft of cold pale-blue light, the same pose as the archer"),
    "igigi_skywatcher": ("igigi", "an Igigi Skywatcher: the same slender bearded sky-watcher in a taller gold-banded "
                         "conical cap and a fringed robe of deep lapis blue with gold trim, a gold star-disc pendant on "
                         "his chest, drawing a gilded curved bow whose arrow is a bright shaft of cold blue-white light"),
    "scorpion_man": ("swordsman", "a Scorpion Man, the girtablilu guardian of the mountain gate in the Gilgamesh epic: "
                     "from the waist up a bearded man with long curled black hair and a bronze conical helmet, bare "
                     "muscular arms holding a bronze spear, from the waist down the body of a giant dark-brown scorpion "
                     "with six jointed legs on the ground, its segmented tail curled high over its back ending in a "
                     "venomous sting"),
    "scorpion_guardian": ("scorpion_man", "a Scorpion Guardian: the same scorpion-man of the mountain gate, his "
                          "scorpion body glossy black with gold banding, a bronze scale cuirass on his man's chest, a "
                          "gold-horned helmet, holding a long bronze spear and a small round shield, the sting of his "
                          "high-curled tail glowing a faint cold green"),
    "sharur": ("ghost", "a Sharur, the living weapon of the war god Ninurta in Sumerian myth: a great flying mace-head "
               "the size of a man, a heavy round head of dark bronze ringed with knobs and inlaid with lapis lazuli, "
               "a band of glowing pale-blue crystal around it, with a pair of spread golden feathered wings, hovering "
               "above the ground with no handle and no body, no face"),
    "shargaz": ("sharur", "a Shargaz, the war god Ninurta's greater weapon: the same flying winged mace-head, larger, "
                "of gilded bronze with sharp flanges, its crystal band glowing bright cold blue-white with faint "
                "crackling light, two pairs of golden feathered wings, hovering above the ground, no face"),
    "apkallu": ("monk", "an Apkallu, one of the seven sages of Sumerian myth who brought the arts to mankind: a bearded "
                "sage in a long fringed robe with a great fish-skin cloak over his head and back, the fish's head "
                "forming a hood above his own and its tail at his heels, holding a small bronze bucket in one hand and "
                "raising a pine cone in the other, the cone glowing with cold pale-blue light"),
    "abgal": ("apkallu", "an Abgal, a great sage of Sumerian myth: the same robed sage now with the head of an eagle "
              "and two great feathered wings folded at his back, in a long fringed robe of white and lapis blue, "
              "holding a small golden bucket and raising a glowing pine cone of bright cold blue-white light"),
    "lamassu": ("cavalier", "a Lamassu, the colossal guardian of Assyrian palace gates: a huge winged bull of pale carved "
                "limestone come to life, with a crowned bearded human head in a tall horned cap, a long curled beard, "
                "great feathered stone wings folded along its back, a curled-stone mane and four heavy stone hooves, "
                "faint cold-blue crystal light in its eyes, walking"),
    "shedu": ("lamassu", "a Shedu, the greater gate guardian: the same colossal winged human-headed bull, its stone "
              "now dark polished basalt inlaid with gold, a gold horned crown, a gold-banded curled beard, its wings "
              "edged with gold, cold-blue crystal light glowing in its eyes and the band of its crown"),
    "anzu": ("red_dragon", "the Anzu, the storm bird of Sumerian myth who stole the Tablets of Destiny: a gigantic eagle "
             "with the head of a roaring lion, a lion's tawny mane, huge spread eagle wings of brown and gold feathers, "
             "an eagle's body and great taloned feet, its feathers swirling with wisps of storm wind and faint "
             "blue-white lightning, standing in the same pose"),
    "imdugud": ("anzu", "the Imdugud, the storm bird in its full might: the same gigantic lion-headed eagle, its "
                "feathers now deep storm-grey and lapis blue edged with gold, a darker black mane, crackling "
                "blue-white lightning around its spread wings and roaring jaws, standing in the same pose"),
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
