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
