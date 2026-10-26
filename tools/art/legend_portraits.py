"""Portraits of the heroes from legend (docs/SETTING.md), painted in the style of the existing hero portraits: a
same-faction portrait is the reference for style, framing, light and background, and the prompt describes the person.
python tools/art/legend_portraits.py paint [ids]   ->  imagegen/batch35/out/<id>.png
python tools/art/legend_portraits.py ingest [ids]  ->  assets/heroes/portraits/<id>.png (256 px), listed in painted.json"""
import os, sys, json
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))

BATCH = "imagegen/batch35"
D = "assets/heroes/portraits"
HEROES = {
    "jacques_de_molay": ("sir_aldric", "Jacques de Molay, the last Grand Master of the Knights Templar: an old, stern "
                         "knight with a long grey beard and deep-set eyes, a mail coif, a white Templar mantle with a red "
                         "cross pattee on the shoulder, his hands resting on the pommel of a sword"),
    "hugues_de_payens": ("lord_gareth", "Hugues de Payens, the founder of the Knights Templar: a weathered knight in his "
                         "forties with a short brown beard, a mail hauberk under a white surcoat with a red cross pattee, "
                         "an open-faced steel helmet held under one arm, a pilgrim's road behind him in the haze"),
    "saint_germain": ("vesna_nightshade", "the Count of Saint-Germain, the immortal alchemist: an ageless, elegant "
                      "nobleman with a pale fine face, dark hair tied back, a black velvet coat with silver embroidery and "
                      "a lace jabot, a ring with a large glowing green gem, holding a small crystal vial of glowing "
                      "golden-red elixir"),
    "edward_kelley": ("ilsa_grimveil", "Edward Kelley, the Elizabethan scryer and alchemist: a gaunt man with a pointed "
                      "dark beard and a black skullcap pulled low over his ears, a dark scholar's gown, gazing into a "
                      "polished black obsidian scrying mirror that glows with a faint ghostly light"),
    # session67: the Illuminated (HoMM3's Tower), all from legend; their colours midnight blue, white and gold
    "nicolas_flamel": ("lady_seraphine", "Nicolas Flamel, the medieval Parisian alchemist said to have made the "
                       "Philosopher's Stone: a calm, kindly man in his fifties with a short grey beard, a dark blue "
                       "scrivener's hood and gown, holding up a small glowing red stone between his fingers"),
    "perenelle_flamel": ("lady_seraphine", "Perenelle Flamel, the alchemist's wife who shared his secret: a serene, "
                         "clever woman in her forties with auburn hair braided and pinned up under a fine gold hairnet (no veil, "
                         "no wimple), a deep blue velvet gown with gold trim, holding an open old book of alchemical "
                         "drawings, a soft golden glow on the page"),
    "paracelsus": ("lord_gareth", "Paracelsus, the wandering Swiss physician and alchemist: a bald, stocky, fierce man "
                   "with a broad face and a short beard, a fur-trimmed red-brown doctor's robe, a long sword with a "
                   "round pommel said to hold his elixir, its pommel glowing faintly"),
    "christian_rosenkreuz": ("brother_tomas", "Christian Rosenkreuz, the legendary founder of the Rosicrucian "
                             "brotherhood: an ancient, gentle sage with a long white beard and calm eyes, a plain white "
                             "robe with a red rose on a golden cross embroidered on the breast"),
    "adam_weishaupt": ("brother_tomas", "Adam Weishaupt, the Bavarian professor who founded the order of the "
                       "Illuminati in 1776: a sharp-eyed young scholar with a powdered white wig tied at the neck, a dark "
                       "blue eighteenth-century coat with a lace cravat, a candle and quill behind him, a gold owl pin "
                       "on his lapel"),
    "cagliostro": ("vesna_nightshade", "Count Cagliostro, the eighteenth-century magician and adventurer: a plump, "
                   "charming man with dark lively eyes and a knowing smile, a powdered wig, a rich crimson coat "
                   "embroidered with gold, a large ring with an eye-shaped gem, holding a small glowing flask"),
    # session68: Agartha (HoMM3's Dungeon), the legends of the Hollow Earth; their colours violet, black and bronze
    "john_symmes": ("lord_gareth", "John Cleves Symmes, the American army captain who claimed the Earth is hollow with "
                    "openings at the poles: a stern, square-jawed officer in his forties with short dark hair and long "
                    "sideburns, a dark blue 1812-era officer's coat with a high collar and brass buttons, a rolled map "
                    "of the polar openings under his arm"),
    "olaf_jansen": ("sir_aldric", "Olaf Jansen, the old Norse sailor of The Smoky God who sailed through the north polar "
                    "opening into the inner world: a weathered seaman with a white beard and a knitted cap, a thick dark "
                    "wool sea-coat, a faint smoky-golden glow of the inner sun behind him"),
    "niels_klim": ("lord_gareth", "Niels Klim, the Norwegian student who fell into the inner world and became its "
                   "emperor: a young man with a bold, surprised face and fair hair, a dark violet imperial cloak over "
                   "an eighteenth-century coat, a bronze crown slightly too big for him"),
    "edmond_halley": ("brother_tomas", "Edmond Halley, the English astronomer who argued that the Earth is made of "
                      "hollow shells lit from within: a thoughtful man in his fifties with a long curled grey "
                      "periwig, a dark scholar's coat with a white cravat, holding a brass armillary of nested spheres"),
    "arne_saknussemm": ("ilsa_grimveil", "Arne Saknussemm, Jules Verne's sixteenth-century Icelandic alchemist who first "
                        "went down to the centre of the Earth: a gaunt, intense scholar with a long pale-blond beard, a "
                        "dark fur-trimmed robe, an old runic manuscript in one hand and a lantern glowing amber in the "
                        "other"),
    "vera_zarovitch": ("vesna_nightshade", "Vera Zarovitch, the Russian noblewoman who found Mizora, the hidden kingdom "
                       "of women inside the pole: a proud, clever woman in her thirties with dark hair pinned up, a "
                       "fur-trimmed dark violet travelling coat, a small silver brooch, pale blue light of the inner "
                       "world on her face"),
    # session68: Eridu, the Anunnaki of Sumerian myth (docs/ERIDU.md): gods of the old tablets, painted as people
    "alalu": ("lord_gareth", "Alalu, the exiled king of distant Nibiru who first came down to Earth in a fallen sky-ship: "
              "a proud, weathered old king with a long curled grey beard and fierce eyes, a battered gold horned crown, "
              "a cloak of deep blue wool over bronze scale, a faint cold-blue crystal glow behind him like a distant star"),
    "ninurta": ("sir_aldric", "Ninurta, the war god of Sumerian myth: a powerful bearded warrior in his prime with a "
                "long curled black beard, a gold horned helmet, a bronze scale cuirass, holding the winged mace Sharur "
                "of bronze and glowing crystal over his shoulder"),
    "enlil": ("hugues_de_payens", "Enlil, lord of the wind and giver of commands in Sumerian myth: a stern, majestic "
              "bearded king with a long curled beard bound in gold, a tall horned crown of gold, a fringed robe of "
              "white and gold, wind stirring his cloak, an air of command"),
    "enki": ("brother_tomas", "Enki, lord of Eridu, the deep waters and the Me in Sumerian myth: a wise, kindly bearded "
             "sage with a long white-streaked curled beard, a horned crown, a fringed robe of lapis blue, streams of "
             "water with fish flowing from his shoulders, holding a glowing pale-blue crystal tablet"),
    "ninhursag": ("vesna_nightshade", "Ninhursag, the mother goddess of Sumerian myth who shaped the first workers from "
                  "clay: a calm, strong woman of middle age with dark braided hair under a horned crown, a fringed "
                  "robe of earth-brown and gold, holding a small figure of clay in her open palm"),
    "inanna": ("ilsa_grimveil", "Inanna, the goddess of Sumerian myth who carried the Me away from Eridu to Uruk: a "
               "striking young woman with long black hair, kohl-lined eyes, a gold horned crown with an eight-pointed "
               "star-disc, a lapis-bead necklace, a deep red and gold fringed robe, a glowing crystal tablet held to "
               "her chest"),
}
PROMPT = ("The image is a hero portrait from a hand-painted fantasy strategy game. Paint a NEW portrait of a different "
          "person in exactly the same style, framing (head and shoulders, centred), lighting and background (the same "
          "soft glowing painterly backdrop and colours): {who}. Hand-painted digital fantasy illustration, rich colours, "
          "visible brushwork. Square image. No text, no border, no frame.")


def paint(ids):
    from google import genai
    import vertex_paint as vp
    client = genai.Client(vertexai=True, project=vp.PROJECT, location=vp.LOCATION)
    os.makedirs(f"{BATCH}/in", exist_ok=True)
    os.makedirs(f"{BATCH}/out", exist_ok=True)
    for hid, (ref, who) in HEROES.items():
        if ids and hid not in ids:
            continue
        src = f"{BATCH}/in/{hid}.png"
        Image.open(f"{D}/{ref}.png").convert("RGB").resize((1024, 1024), Image.LANCZOS).save(src)
        img = vp.paint(client, "gemini-nano-banana-2.1", src, PROMPT.format(who=who), "1:1", "1K")
        if img:
            img.save(f"{BATCH}/out/{hid}.png"); print("done", hid, flush=True)
        else:
            print("FAILED", hid, flush=True)


def ingest(ids=None):
    pj = f"{D}/painted.json"
    painted = json.load(open(pj))
    for hid in HEROES:
        if ids and hid not in ids:
            continue
        p = f"{BATCH}/out/{hid}.png"
        if not os.path.exists(p):
            continue
        Image.open(p).convert("RGB").resize((256, 256), Image.LANCZOS).save(f"{D}/{hid}.png")
        if hid not in painted:
            painted.append(hid)
        print("ingested", hid)
    json.dump(sorted(painted), open(pj, "w"))


if __name__ == "__main__":
    {"paint": lambda: paint(sys.argv[2:]), "ingest": lambda: ingest(sys.argv[2:])}[sys.argv[1]]()
