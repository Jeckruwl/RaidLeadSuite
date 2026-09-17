#!/usr/bin/env python3
"""Pure-python TGA -> BLP2 (DXT3) converter.

Purpose: some 3.3.5-era clients fail to load .tga textures referenced from
WoW addon code (this addon already ships .blp alternatives for the minimap
icon for that reason), AND v1.9.2 proved they also reject RAW/uncompressed
BLP2 (compression=3): the only BLP flavour guaranteed to load is the one the
repo's working icons (media/save.blp, alliance/hordeicon.blp) already use:

    type=1  compression=2 (DXT)  alphaBits=4  alphaType=1 (DXT3)  hasMips=1

This tool converts the user's BCI_*.tga category icons to exactly that
format, byte-compatible with the pre-existing working files (a 32x32 icon
produces a 2564-byte file, identical layout to media/save.blp).

DXT3 block layout (16 bytes per 4x4 block, blocks row-major top-down):
  [0:8]  64-bit little-endian alpha: 4 bits per pixel, pixel i at bits 4*i
  [8:10] color0 RGB565 LE
  [10:12] color1 RGB565 LE (always color0 >= color1)
  [12:16] 32-bit little-endian 2-bit palette indices, pixel i at bits 2*i

Mips: full chain N -> N/2 -> ... -> 1 via 2x2 box average; levels smaller
than 4 still occupy whole 4x4 blocks (16 bytes for 4x4, 2x2 and 1x1),
exactly like the shipped working icons.

Usage:  python3 tests/tools/tga2blp.py media/BUFFCATICONS
"""

import os
import struct
import sys


def read_tga(path):
    """Read an uncompressed true-color TGA. Returns (w, h, bgra_bytes)."""
    data = open(path, "rb").read()
    if len(data) < 18:
        raise ValueError(f"{path}: too short for a TGA")
    idlen, cmaptype, imgtype = data[0], data[1], data[2]
    if cmaptype != 0 or imgtype != 2:
        raise ValueError(f"{path}: only uncompressed true-color TGA (type 2) supported")
    w = data[12] | (data[13] << 8)
    h = data[14] | (data[15] << 8)
    depth = data[16]
    if depth != 32:
        raise ValueError(f"{path}: expected 32bpp, got {depth}bpp")
    desc = data[17]
    top_origin = (desc & 0x20) != 0
    pix = data[18 + idlen:18 + idlen + w * h * 4]
    if len(pix) != w * h * 4:
        raise ValueError(f"{path}: truncated pixel data")
    # BLP data is stored top-down. If the TGA is bottom-origin flip rows.
    if not top_origin:
        flipped = bytearray()
        for y in range(h - 1, -1, -1):
            flipped += pix[y * w * 4:(y + 1) * w * 4]
        pix = bytes(flipped)
    return w, h, pix


def downsample(w, h, pix):
    """2x2 box average. Returns (w2, h2, bgra)."""
    w2, h2 = max(1, w // 2), max(1, h // 2)
    out = bytearray(w2 * h2 * 4)
    for y in range(h2):
        for x in range(w2):
            for c in range(4):
                acc = 0
                for dy in range(2):
                    for dx in range(2):
                        sx = min(w - 1, x * 2 + dx)
                        sy = min(h - 1, y * 2 + dy)
                        acc += pix[(sy * w + sx) * 4 + c]
                out[(y * w2 + x) * 4 + c] = acc // 4
    return w2, h2, bytes(out)


# --- DXT3 (BC2) encoding ---------------------------------------------------

def _pack565(r, g, b):
    return ((r & 0xF8) << 8) | ((g & 0xFC) << 3) | (b >> 3)


def _expand565(c):
    r = ((c >> 11) & 0x1F) * 255 // 0x1F
    g = ((c >> 5) & 0x3F) * 255 // 0x3F
    b = (c & 0x1F) * 255 // 0x1F
    return (r, g, b)


def _encode_dxt3_block(block):
    """block = list of 16 (r,g,b,a) tuples. Returns 16 bytes."""
    # alpha first: 4-bit per pixel, little-endian
    a64 = 0
    for i, (r, g, b, a) in enumerate(block):
        a64 |= ((a * 15 + 127) // 255) << (4 * i)
    # color endpoints: per-channel min/max corners
    rs = [p[0] for p in block]
    gs = [p[1] for p in block]
    bs = [p[2] for p in block]
    c0 = _pack565(max(rs), max(gs), max(bs))
    c1 = _pack565(min(rs), min(gs), min(bs))
    if c0 < c1:
        c0, c1 = c1, c0
    r0, g0, b0 = _expand565(c0)
    r1, g1, b1 = _expand565(c1)
    palette = (
        (r0, g0, b0),
        (r1, g1, b1),
        ((2 * r0 + r1) // 3, (2 * g0 + g1) // 3, (2 * b0 + b1) // 3),
        ((r0 + 2 * r1) // 3, (g0 + 2 * g1) // 3, (b0 + 2 * b1) // 3),
    )
    idx32 = 0
    for i, (r, g, b, a) in enumerate(block):
        best, best_d = 0, None
        for k, (pr, pg, pb) in enumerate(palette):
            dr, dg, db = r - pr, g - pg, b - pb
            d = 3 * dr * dr + 6 * dg * dg + db * db   # rough luma weighting
            if best_d is None or d < best_d:
                best, best_d = k, d
        idx32 |= best << (2 * i)
    return struct.pack("<QHHI", a64, c0, c1, idx32)


def encode_dxt3(w, h, pix):
    """Encode a BGRA top-down image as DXT3 (padded to whole 4x4 blocks)."""
    bw, bh = max(1, (w + 3) // 4), max(1, (h + 3) // 4)
    out = bytearray()
    for by_ in range(bh):
        for bx in range(bw):
            block = []
            for dy in range(4):
                for dx in range(4):
                    sx = min(w - 1, bx * 4 + dx)
                    sy = min(h - 1, by_ * 4 + dy)
                    o = (sy * w + sx) * 4
                    b, g, r, a = pix[o], pix[o + 1], pix[o + 2], pix[o + 3]
                    block.append((r, g, b, a))
            out += _encode_dxt3_block(block)
    return bytes(out)


def dxt3_mip_size(w, h):
    return 16 * max(1, (w + 3) // 4) * max(1, (h + 3) // 4)


# --- BLP2 writer ------------------------------------------------------------

HEADER_SIZE = 4 + 4 + 4 + 4 + 4 + 64 + 64 + 1024   # 1172


def write_blp(path, w, h, pix):
    """Write DXT3 BLP2 with full mip chain (same flavour as media/save.blp)."""
    levels = [(w, h, pix)]
    cw, ch, cur = w, h, pix
    while max(cw, ch) > 1:
        cw, ch, cur = downsample(cw, ch, cur)
        levels.append((cw, ch, cur))
    offsets, sizes, blobs = [], [], []
    ofs = HEADER_SIZE
    for i in range(16):
        if i < len(levels):
            lw, lh, lpix = levels[i]
            blob = encode_dxt3(lw, lh, lpix)
            assert len(blob) == dxt3_mip_size(lw, lh)
            offsets.append(ofs)
            sizes.append(len(blob))
            ofs += len(blob)
            blobs.append(blob)
        else:
            offsets.append(0)
            sizes.append(0)
    with open(path, "wb") as fh:
        fh.write(b"BLP2")
        fh.write(struct.pack("<I", 1))                 # type 1 = uncompressed/DXT
        fh.write(struct.pack("<BBBB", 2, 4, 1, 1))     # compression=DXT, alphaBits=4, alphaType=1 (DXT3), hasMips
        fh.write(struct.pack("<II", w, h))
        fh.write(struct.pack("<16I", *offsets))
        fh.write(struct.pack("<16I", *sizes))
        fh.write(b"\x00" * 1024)                        # palette unused for DXT
        for blob in blobs:
            fh.write(blob)


def convert_folder(folder):
    done, skipped = 0, 0
    for name in sorted(os.listdir(folder)):
        if not name.lower().endswith(".tga"):
            continue
        src = os.path.join(folder, name)
        dst = src[:-4] + ".blp"
        try:
            w, h, pix = read_tga(src)
        except ValueError as exc:
            print(f"SKIP {name}: {exc}")
            skipped += 1
            continue
        write_blp(dst, w, h, pix)
        print(f"OK   {name} -> {os.path.basename(dst)} ({w}x{h}, DXT3)")
        done += 1
    print(f"converted {done}, skipped {skipped}")


if __name__ == "__main__":
    convert_folder(sys.argv[1] if len(sys.argv) > 1 else "media/BUFFCATICONS")
