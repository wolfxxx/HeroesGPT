"""Temple town backdrop (haven_bg): the Templar repaint (distant castle, hills, sky) above, the original painting's
ground below. The repaint had moved the plaza about 110 px lower, and every building sprite stands on the original
ground; the two meet in a blend across rows 400..450, which the Fort's walls hide. The original lamp post at the
right is taken whole from the original (the blend cut it in half).
python tools/art/town_bg_blend.py <templar_bg.png> <original_bg.png>   ->  assets/town/haven_bg.png
  templar: git show 5c35890^:assets/town/haven_bg.png ; original: git show eac8cc0:assets/town/haven_bg.png"""
import sys
import numpy as np
from PIL import Image

DST = "assets/town/haven_bg.png"
TOP, BOTTOM = 400, 450                # the blend: the repaint above TOP, the original below BOTTOM
LAMP = (1515, 1570, 325, 475)          # the original's lamp post at the right: columns, rows


def main(templar, original):
    new = np.asarray(Image.open(templar).convert("RGB")).astype(np.float32)
    old = np.asarray(Image.open(original).convert("RGB")).astype(np.float32)
    h, w = new.shape[:2]
    wt = np.repeat(np.clip((np.arange(h) - TOP) / (BOTTOM - TOP), 0, 1)[:, None], w, axis=1)
    x0, x1, y0, y1 = LAMP
    box = old[y0:y1, x0:x1]
    r, g, b = box[..., 0], box[..., 1], box[..., 2]
    lamp = np.zeros((h, w), np.uint8)
    lamp[y0:y1, x0:x1] = ((g <= r) | ((r + g + b) / 3 > 215)) * 255  # not grass: the post, its lantern and globe
    from PIL import ImageFilter
    lm = np.asarray(Image.fromarray(lamp).filter(ImageFilter.GaussianBlur(0.7))).astype(np.float32) / 255
    wt = np.maximum(wt, lm)
    out = new * (1 - wt[..., None]) + old * wt[..., None]
    Image.fromarray(out.clip(0, 255).astype(np.uint8)).save(DST)
    print(DST, (w, h))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
