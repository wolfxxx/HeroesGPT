"""Temple fort (haven_fort): the tower at the right end of its wall had a plain white cone for a roof, with a window in
it (the render left it unfinished: the Mage Guild's tower stands on that spot once built), and a faint dark smudge
beside it. The image model gives it a slate cone like the fort's other towers; only the roof rows of that tower are
taken from the repaint (the rest of the sprite is untouched, and the click area hardly changes).
python tools/art/fort_tower_paint.py paint   ->  imagegen/batch39/out/fort_tower.png
python tools/art/fort_tower_paint.py ingest  ->  assets/town/haven_fort.png (the old sprite kept in tools/art/raw/town/)"""
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
HAZE = (940, 1127, 305, 60)
RING = (246, 260, 984, 1088)  # the old top ring's scalloped ends stuck out under the new ring: rows, kept columns
SLIVER = (975, 1000, 244, 290, 150)  # a dark sliver of backdrop baked onto the tower's left side: cols, rows, max light  # columns, rows above and alpha below which the render's faint shadow haze is cleared
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


if __name__ == "__main__":
    {"paint": paint, "ingest": ingest}[sys.argv[1]]()
