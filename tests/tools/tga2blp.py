#!/usr/bin/env python3
"""Pure-python TGA -> BLP2 (uncompressed BGRA) converter.

Purpose: some 3.3.5-era clients fail to load .tga textures referenced from
WoW addon code (this addon already ships .blp alternatives for the minimap
icon for that reason). This tool converts the user's BCI_*.tga category
icons to matching .blp so the raid-frame header works on those clients.

Writes an uncompressed BLP2 (compression=3, alphaBits=8, alphaType=0) with
the full mip chain (N/2 down to 1) using 2x2 box-average downsampling.

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


def mip_pad4(v):
    return v if v % 4 == 0 else v + (4 - v % 4)


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


def write_blp(path, w, h, pix):
    """Write uncompressed BLP2 with full mip chain."""
    mips = [pix]
    cw, ch = w, h
    cur = pix
    while max(cw, ch) > 1:
        cw, ch, cur = downsample(cw, ch, cur)
        mips.append(cur)
    while len(mips) < 16:
        mips.append(b"")
    header_size = 4 + 4 + 4 + 4 + 4 + 64 + 64 + 1024  # 1172
    offsets, sizes = [], []
    ofs = header_size
    for m in mips[:16]:
        if m:
            offsets.append(ofs)
            sizes.append(len(m))
            ofs += len(m)
        else:
            offsets.append(0)
            sizes.append(0)
    with open(path, "wb") as fh:
        fh.write(b"BLP2")
        fh.write(struct.pack("<I", 1))        # type
        fh.write(struct.pack("<BBBB", 3, 8, 0, 1))  # compression=raw, alphaBits=8, alphaType=0, hasMips
        fh.write(struct.pack("<II", w, h))
        fh.write(struct.pack("<16I", *offsets))
        fh.write(struct.pack("<16I", *sizes))
        fh.write(b"\x00" * 1024)               # no palette for raw encoding
        for m in mips[:16]:
            if m:
                fh.write(m)


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
        print(f"OK   {name} -> {os.path.basename(dst)} ({w}x{h})")
        done += 1
    print(f"converted {done}, skipped {skipped}")


if __name__ == "__main__":
    convert_folder(sys.argv[1] if len(sys.argv) > 1 else "media/BUFFCATICONS")
