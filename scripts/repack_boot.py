#!/usr/bin/env python3
"""Replace the kernel inside a Samsung (header v1-style, DTBH) boot.img.

Usage: repack_boot.py <stock boot.img> <new Image> <out boot.img>

Layout (from LineageOS 20 crownlte boot.img):
  header page | kernel | ramdisk | second | DT (DTBH) | tail ("SEANDROIDENFORCE" etc.)
Samsung stores the DT size in the header_version slot (offset 40).
Only kernel_size and the SHA1 id are changed; everything else is copied as-is.
"""
import hashlib
import struct
import sys

src, img, out = sys.argv[1:4]
d = bytearray(open(src, "rb").read())
new_k = open(img, "rb").read()

assert d[:8] == b"ANDROID!", "not an Android boot image"
ks, ka, rs, ra, ss, sa, ta, ps, dts = struct.unpack_from("<9I", d, 8)
pg = lambda n: (n + ps - 1) // ps * ps

off = ps
kernel = d[off:off + ks]; off += pg(ks)
ramdisk = d[off:off + rs]; off += pg(rs)
second = d[off:off + ss]; off += pg(ss)
dt = d[off:off + dts]; off += pg(dts)
tail = d[off:]
assert dt[:4] == b"DTBH", "expected Samsung DTBH block"

hdr = bytearray(d[:ps])
struct.pack_into("<I", hdr, 8, len(new_k))
sha = hashlib.sha1()
for blob in (new_k, ramdisk, second, dt):
    sha.update(blob)
    sha.update(struct.pack("<I", len(blob)))
hdr[576:576 + 32] = sha.digest().ljust(32, b"\0")

pad = lambda b: bytes(b) + b"\0" * (pg(len(b)) - len(b))
res = bytes(hdr) + pad(new_k) + pad(ramdisk) + pad(second) + pad(dt) + bytes(tail)
open(out, "wb").write(res)
print(f"old kernel {ks} -> new {len(new_k)}; image {len(d)} -> {len(res)} bytes; tail {bytes(tail[:16])!r}")
if len(res) > 57671680:
    sys.exit("ERROR: larger than BOOT partition (57671680)")
