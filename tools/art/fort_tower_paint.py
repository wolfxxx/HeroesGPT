"""Temple fort (haven_fort): the tower at the right end of its wall had a plain white cone for a roof, with a window in
it (the render left it unfinished: the Mage Guild's tower stands on that spot once built), and a faint dark smudge
beside it. The image model gives it a slate cone like the fort's other towers; only the roof rows of that tower are
taken from the repaint (the rest of the sprite is untouched, and the click area hardly changes).
python tools/art/fort_tower_paint.py paint   ->  imagegen/batch39/out/fort_tower.png
python tools/art/fort_tower_paint.py ingest  ->  assets/town/haven_fort.png (the old sprite kept in tools/art/raw/town/)
Then the tower's body, cut off by a straight line just right of its windows (a third of the round tower missing),
is completed as a whole cylinder under a roof as wide (the user saw it): the repaint decides the tower right of
column WX; the sprite grows to the right if the tower needs it, and its rect in layout_haven.json with it.
python tools/art/fort_tower_paint.py widen          ->  imagegen/batch39/out/fort_tower_whole.png
python tools/art/fort_tower_paint.py widen_ingest   ->  assets/town/haven_fort.png (the roofed one kept in raw/)"""
import os, sys, shutil
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from pose_paint import key_out

BATCH = "imagegen/batch39"
DST = "assets/town/haven_fort.png"
OLD = "tools/art/raw/town/haven_fort_white_cone.png"
BOX = (720, 60, 1127, 499)   # sprite px sent to the model: a slate-roofed tower (the reference), the wall, the tower
X0, X1 = 975, 1110           # the tower's columns (sprite px) where the repaint is taken
CUT, FADE = 238, 10          # rows taken from the repaint (the roof, down to its top gold ring), then cross-faded
HAZE = (940, 1127, 305, 60)  # columns, rows above and alpha below which the render's faint shadow haze is cleared
RING = (246, 260, 984, 1088)  # the old top ring's scalloped ends stuck out under the new ring: rows, kept columns
SLIVER = (975, 1000, 244, 290, 150)  # a dark sliver of backdrop baked onto the tower's left side: cols, rows, max light
PAD = 40
PROMPT = ("This is part of a painted fantasy castle (a sprite on a flat magenta background). The round white tower at "
          "the right has an unfinished top: a plain white cone with a window in it. Replace that white cone with a "
          "proper conical roof of dark grey slate tiles, with gold trim along its lower edge and a small gold finial on "
          "top, exactly like the slate-roofed round tower further left, in the same painting style, perspective and "
          "lighting, sitting on the tower's top gold ring. Also remove the faint dark smudge next to that tower's top. "
          "Do not change anything else: the tower body, its windows and gold rings, the walls and the other tower stay "
          "exactly the same, same size and position. Keep the background flat pure magenta (#FF00FF), no ground, no "
          "shadow, no text.")


def _src():
    return Image.open(OLD if os.path.exists(OLD) else DST).convert("RGBA")


def paint():
    import vertex_paint as vp
    from google import genai
    os.makedirs(f"{BATCH}/in", exist_ok=True)
    os.makedirs(f"{BATCH}/out", exist_ok=True)
    os.makedirs(os.path.dirname(OLD), exist_ok=True)
    if not os.path.exists(OLD):
        shutil.copy(DST, OLD)
    a = np.asarray(_src()).copy()
    a[..., 3] = np.where(a[..., 3] > 160, 255, 0)
    crop = Image.fromarray(a).crop(BOX)
    canvas = Image.new("RGBA", (crop.width + 2 * PAD, crop.height + 2 * PAD), (255, 0, 255, 255))
    canvas.alpha_composite(crop, (PAD, PAD))
    canvas.convert("RGB").save(f"{BATCH}/in/fort_tower.png")
    client = genai.Client(vertexai=True, project=vp.PROJECT, location=vp.LOCATION)
    img = vp.paint(client, "gemini-nano-banana-2.1", f"{BATCH}/in/fort_tower.png", PROMPT, "1:1", "1K")
    if img:
        img.save(f"{BATCH}/out/fort_tower.png")
        print("done", img.size, "from", canvas.size)


def ingest():
    old = _src()
    src = Image.open(f"{BATCH}/in/fort_tower.png").convert("RGB")
    out = key_out(Image.open(f"{BATCH}/out/fort_tower.png").convert("RGB"))
    # the model answers at its own size and framing: map it back onto the input canvas by the drawing's left and
    # right edges (across) and by the reference tower's apex and the drawing's bottom (down)
    sa = np.asarray(src).astype(int)
    smask = ~((sa[..., 0] > 200) & (sa[..., 1] < 80) & (sa[..., 2] > 200))
    omask = np.asarray(out)[..., 3] > 128
    def feats(m):
        ys, xs = np.nonzero(m)
        l, r = xs.min(), xs.max()
        ref = m[:, l:l + int((r - l) * 0.4)]
        return l, r, np.nonzero(ref.any(axis=1))[0].min(), ys.max()
    sl, sr, st, sb = feats(smask)
    ol, orr, ot, ob = feats(omask)
    kx, ky = (orr - ol) / (sr - sl), (ob - ot) / (sb - st)
    print("  scale", round(kx, 3), round(ky, 3))
    out = out.transform(src.size, Image.AFFINE, (kx, 0, ol - sl * kx, 0, ky, ot - st * ky), Image.BICUBIC)
    o = np.asarray(out).astype(np.float32)
    s = np.asarray(src).astype(np.float32)
    body = (slice(PAD + CUT - BOX[1] + 20, PAD + CUT - BOX[1] + 140), slice(PAD + X0 - BOX[0] + 20, PAD + X1 - BOX[0] - 20))
    oa = o[body][..., 3] > 128
    print("  tower body colour difference:", round(float(np.abs(o[body][..., :3] - s[body])[oa].mean()), 1) if oa.any() else "none")
    # the repaint in sprite coordinates
    rep = np.zeros((old.height, old.width, 4), np.float32)
    rep[BOX[1]:BOX[3], BOX[0]:BOX[2]] = o[PAD:PAD + BOX[3] - BOX[1], PAD:PAD + BOX[2] - BOX[0]]
    rep[..., 3] = (rep[..., 3] > 128) * 255.0
    base = np.asarray(old).astype(np.float32)
    w = np.zeros((old.height, 1, 1), np.float32)
    w[:CUT] = 1
    w[CUT:CUT + FADE, 0, 0] = np.linspace(1, 0, FADE)
    cols = np.zeros((1, old.width, 1), np.float32)
    cols[0, X0:X1, 0] = 1
    wt = w * cols
    new = rep * wt + base * (1 - wt)
    # above the cut, inside the tower's columns, the repaint decides the shape (the old cone and smudge go)
    blank = (wt[..., 0] >= 1) & (rep[..., 3] == 0)
    new[blank] = 0
    # the render's faint shadow haze around the tower (the old backdrop's trees hid it)
    x0, x1, y1, amax = HAZE
    hz = new[:y1, x0:x1]
    hz[hz[..., 3] < amax] = 0
    r0, r1, k0, k1 = RING
    new[r0:r1, :k0][..., 3] = np.where(np.arange(k0) >= X0 - 10, 0, new[r0:r1, :k0][..., 3])
    new[r0:r1, k1:X1 + 10] = 0
    c0, c1, s0, s1, lmax = SLIVER
    sv = new[s0:s1, c0:c1]
    sv[sv[..., :3].mean(axis=-1) < lmax] = 0
    Image.fromarray(new.clip(0, 255).astype(np.uint8), "RGBA").save(DST)
    print("  town/haven_fort.png", old.size)


ROOFED = "tools/art/raw/town/haven_fort_roofed.png"
LAYOUT = "assets/town/layout_haven.json"
WBOX = (860, 100, 1127, 499)  # sprite px sent for the widening (the wall's end and the tower)
WSIZE, WAT = 520, (40, 60)    # a square canvas (the model keeps a square's proportions), the crop's place on it
WX, WFADE = 968, 8            # columns from WX are the repaint's (after a cross-fade); left of it the sprite stays
GROW = 48                     # room added at the sprite's right
WPROMPT = ("This is part of a painted fantasy castle (a sprite on a flat magenta background): the end of a white "
           "crenellated wall and ONE round white tower with a slate cone roof. The tower's body is cut off by a "
           "straight vertical line on its right side, right next to its right-hand windows, which makes it look "
           "flat and broken. Fix only that: keep it one single slim round tower (never two towers side by side, no "
           "crease down its middle), make its body only about a quarter wider to the right, so there is curved white "
           "plaster to the right of the right-hand windows, shaded darker as the cylinder turns away from the light, "
           "and let the gold rings, the scalloped trims and the base ring curve round to that new edge. Widen the "
           "slate roof by the same amount so its eave overhangs the tower evenly on both sides, its tip over the "
           "middle. Everything left of the tower's middle (the wall, the left windows, the left half of the tower "
           "and roof) stays exactly the same, same size and position. Keep the background flat pure magenta "
           "(#FF00FF), no ground, no shadow, no text.")


def widen():
    import vertex_paint as vp
    from google import genai
    os.makedirs(f"{BATCH}/in", exist_ok=True)
    os.makedirs(f"{BATCH}/out", exist_ok=True)
    if not os.path.exists(ROOFED):
        shutil.copy(DST, ROOFED)
    a = np.asarray(Image.open(ROOFED).convert("RGBA")).copy()
    a[..., 3] = np.where(a[..., 3] > 160, 255, 0)
    canvas = Image.new("RGBA", (WSIZE, WSIZE), (255, 0, 255, 255))
    canvas.alpha_composite(Image.fromarray(a).crop(WBOX), WAT)
    canvas.convert("RGB").save(f"{BATCH}/in/fort_tower_whole.png")
    client = genai.Client(vertexai=True, project=vp.PROJECT, location=vp.LOCATION)
    img = vp.paint(client, "gemini-nano-banana-2.1", f"{BATCH}/in/fort_tower_whole.png", WPROMPT, "1:1", "1K")
    if img:
        img.save(f"{BATCH}/out/fort_tower_whole.png")
        print("done", img.size)


def widen_ingest():
    import json
    old = Image.open(ROOFED).convert("RGBA")
    src = Image.open(f"{BATCH}/in/fort_tower_whole.png").convert("RGB")
    out = key_out(Image.open(f"{BATCH}/out/fort_tower_whole.png").convert("RGB"))
    # map back by the wall's left end (across), the roof's apex and the wall's bottom at the left (down): one scale
    sa = np.asarray(src).astype(int)
    smask = ~((sa[..., 0] > 200) & (sa[..., 1] < 80) & (sa[..., 2] > 200))
    omask = np.asarray(out)[..., 3] > 128
    def feats(m):
        ys, xs = np.nonzero(m)
        l = xs.min()
        left = m[:, l:l + 40]
        return l, ys.min(), np.nonzero(left.any(axis=1))[0].max()
    sl, st, sb = feats(smask)
    ol, ot, ob = feats(omask)
    k = (ob - ot) / (sb - st)
    print("  scale", round(k, 3))
    out = out.transform(src.size, Image.AFFINE, (k, 0, ol - sl * k, 0, k, ot - st * k), Image.BICUBIC)
    o = np.asarray(out).astype(np.float32)
    W, H = old.width + GROW, old.height
    rep = np.zeros((H, W, 4), np.float32)
    x0, y0 = WBOX[0] - WAT[0], WBOX[1] - WAT[1]  # the canvas's origin in sprite px
    cx0, cy0 = max(0, -x0), max(0, -y0)
    ex, ey = min(W, x0 + WSIZE), min(H, y0 + WSIZE)
    rep[y0 + cy0:ey, x0 + cx0:ex] = o[cy0:ey - y0, cx0:ex - x0]
    rep[..., 3] = (rep[..., 3] > 128) * 255.0
    base = np.zeros((H, W, 4), np.float32)
    base[:, :old.width] = np.asarray(old).astype(np.float32)
    # a last nudge of a few pixels, matched on the wall just left of the join (both paintings have it)
    def err(dx, dy):
        r = np.roll(rep, (dy, dx), axis=(0, 1))[300:480, WX - 60:WX]
        b = base[300:480, WX - 60:WX]
        m = (r[..., 3] > 0) & (b[..., 3] > 200)
        return np.abs(r[..., :3] - b[..., :3])[m].mean() if m.sum() > 500 else 999
    best = min(((err(dx, dy), dx, dy) for dx in range(-10, 11) for dy in range(-10, 11)))
    print("  nudge", best[1], best[2], "wall difference", round(float(best[0]), 1), "from", round(float(err(0, 0)), 1))
    rep = np.roll(rep, (best[2], best[1]), axis=(0, 1))
    wt = np.zeros((1, W, 1), np.float32)
    wt[0, WX:WX + WFADE, 0] = np.linspace(0, 1, WFADE)
    wt[0, WX + WFADE:, 0] = 1
    rows = np.zeros((H, 1, 1), np.float32)
    rows[WBOX[1]:WBOX[3]] = 1  # (above the box the sprite stays: nothing of the tower is there)
    wt = wt * rows
    new = rep * wt + base * (1 - wt)
    new[(wt[..., 0] >= 1) & (rep[..., 3] == 0)] = 0
    img = Image.fromarray(new.clip(0, 255).astype(np.uint8), "RGBA")
    right = img.getbbox()[2]
    img = img.crop((0, 0, max(right, old.width), H))
    img.save(DST)
    lay = json.load(open(LAYOUT))
    lay["fort"][2] = img.width
    json.dump(lay, open(LAYOUT, "w"), indent=0)
    print("  town/haven_fort.png", img.size, "rect", lay["fort"])


if __name__ == "__main__":
    {"paint": paint, "ingest": ingest, "widen": widen, "widen_ingest": widen_ingest}[sys.argv[1]]()
