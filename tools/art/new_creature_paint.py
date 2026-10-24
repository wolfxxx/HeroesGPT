"""New creatures painted by an image model over an existing creature's idle figure and portrait (its pose, size and
framing), as upgrade_paint.py does for upgrades but as a different being.
python tools/art/new_creature_paint.py prep           ->  imagegen/batch36/in/nc__<id>.png, ncport__<id>.png + new.json
python tools/art/new_creature_paint.py paint [ids]    ->  imagegen/batch36/out/...
python tools/art/new_creature_paint.py ingest         ->  assets/creatures/<id>.png (+ anchors.json), portraits/<id>.png
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


def prep():
    os.makedirs(f"{BATCH}/in", exist_ok=True)
    info = {}
    for nid, (base, _) in NEW.items():
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


def ingest():
    info = json.load(open(f"{BATCH}/in/new.json"))
    anchors = json.load(open(f"{D}/anchors.json"))
    for nid, d in info.items():
        src = f"{BATCH}/out/nc__{nid}.png"
        if os.path.exists(src):
            up.ingest_figure(src, f"{BATCH}/in/nc__{nid}.png", d["base"], d["scale"], nid, anchors, grow=1.15)
        ps = f"{BATCH}/out/ncport__{nid}.png"
        if os.path.exists(ps):
            Image.open(ps).convert("RGB").resize((256, 256), Image.LANCZOS).save(f"{D}/portraits/{nid}.png")
    json.dump(anchors, open(f"{D}/anchors.json", "w"), indent=0, sort_keys=True)


if __name__ == "__main__":
    {"prep": lambda: prep(), "paint": lambda: paint(sys.argv[2:]), "ingest": lambda: ingest()}[sys.argv[1]]()
