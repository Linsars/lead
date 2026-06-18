import struct

with open("/tmp/tf", "rb") as f:
    d = f.read()

# Parse Mach-O
ncmds = struct.unpack("<I", d[16:20])[0]
pos = 32
to = ts = so = st = ns = 0

for _ in range(ncmds):
    ct, cs = struct.unpack("<II", d[pos:pos+8])
    if ct == 2:
        so, st, ns = struct.unpack("<III", d[pos+8:pos+20])
    if ct == 0x19 and d[pos+8:pos+24].split(b"\x00")[0].decode() == "__TEXT":
        n_sects = struct.unpack("<I", d[pos+72:pos+76])[0]
        sec = pos + 80
        for _ in range(n_sects):
            sn = d[sec:sec+16].split(b"\x00")[0].decode()
            if sn == "__text":
                to, ts = struct.unpack("<QQ", d[sec+32:sec+48])
            sec += 80
    pos += cs

print(f"__text: {to:x} sz={ts}")
print(f"__sym: {ns} symbols", flush=True)

# Symbol table search
for s in range(ns):
    nl = so + s * 16
    n_strx = struct.unpack("<I", d[nl:nl+4])[0]
    n_val = struct.unpack("<Q", d[nl+8:nl+16])[0]
    try: name = d[st+n_strx:st+n_strx+256].split(b"\x00")[0].decode(errors="replace")
    except: name = "DECODE_ERROR"
    low = name.lower()
    if "numberofaccounts" in low:
        print(f"FOUND: {name} -> 0x{n_val:x}", flush=True)

# CMP #3 byte scan
text = d[to:to+min(ts, 10*1024*1024)]
cnt3 = 0
cnt4 = 0
for i in range(0, len(text) - 3, 4):
    if text[i+3] == 0xf1 and text[i+2] == 0x00:
        b1 = text[i+1]
        if 0x0c <= b1 <= 0x0f:
            cnt3 += 1
            if cnt3 <= 20:
                rn = (text[i] >> 5) & 7
                rn |= (b1 & 3) << 3
                print(f"CMP3 0x{to+i:x} X{rn} imm={3+4*(b1-12)}", flush=True)
        elif 0x10 <= b1 <= 0x13:
            cnt4 += 1
            if cnt4 <= 10:
                print(f"CMP4 0x{to+i:x} imm={4+4*(b1-16)}", flush=True)

print(f"TOTAL: CMP#3={cnt3} CMP#4={cnt4}", flush=True)
