#!/usr/bin/env python3
"""Regenerate cross-<tuple>/ from ::gentoo: dereference the crossdev links, keep the newest
release per slot (+ live ebuilds of those slots), and the files/ they reference.
usage: regen-cross.py <crossdev-overlay> <gentoo-repo> <dest>"""
import os, re, shutil, sys
ov, gentoo, dest = sys.argv[1:4]
def vkey(v):
    return [int(x) if x.isdigit() else x for x in re.split(r'[._-]|(?<=\d)(?=[a-z])', v)]
KEEP = {  # package -> function(list of (filename, version)) -> kept names
}
def pick(pkg, ebs):
    names = [e[:-7] for e in ebs]
    live = [n for n in names if n.endswith('9999')]
    rel = [n for n in names if not n.endswith('9999')]
    pv = lambda n: n[len(pkg)+1:]
    def newest(c): return max(c, key=lambda n: vkey(pv(n))) if c else None
    if pkg == 'gcc':  # SLOT = major
        slots = {}
        for n in rel: slots.setdefault(pv(n).split('.')[0], []).append(n)
        keep = []
        for s, c in slots.items():
            if int(s) in (13, 14, 15, 16):
                keep.append(newest(c))
                keep += [n for n in live if pv(n).split('.')[0] == s]
        return keep
    return [newest(rel)] + live[-1:] if pkg in ('binutils',) else [newest(rel)] + live
os.makedirs(dest, exist_ok=True)
for cat in sorted(d for d in os.listdir(ov) if d.startswith('cross-')):
    for pkg in sorted(os.listdir(f'{ov}/{cat}')):
        src = os.path.realpath(f'{ov}/{cat}/{pkg}')
        ebs = [f for f in os.listdir(src) if f.endswith('.ebuild')]
        keep = pick(pkg, ebs)
        d = f'{dest}/{cat}/{pkg}'
        shutil.rmtree(d, ignore_errors=True); os.makedirs(d)
        text = ''
        for n in keep:
            shutil.copy(f'{src}/{n}.ebuild', d); text += open(f'{src}/{n}.ebuild').read()
        for x in ('metadata.xml',):
            if os.path.exists(f'{src}/{x}'): shutil.copy(f'{src}/{x}', d)
        if os.path.isdir(f'{src}/files'):
            os.makedirs(f'{d}/files')
            def used(f):
                if f in text: return True
                for n in keep:
                    pv = re.sub(r'-r\d+$', '', n[len(pkg)+1:])
                    p = f'{pkg}-{pv}'
                    g = f.replace(p, '${P}').replace(pv, '${PV}').replace(pkg, '${PN}')
                    if g in text or f.replace(pv, '${PV}') in text or f.replace(pkg, '${PN}') in text:
                        return True
                return False
            for f in os.listdir(f'{src}/files'):
                if used(f):
                    shutil.copy(f'{src}/files/{f}', f'{d}/files/{f}')
            if not os.listdir(f'{d}/files'): os.rmdir(f'{d}/files')
        mx = f'{d}/metadata.xml'
        if os.path.exists(mx):  # <flag restrict=> may only name this package
            t = open(mx).read(); t = t.replace('restrict="&gt;=sys-devel/gcc-', f'restrict="&gt;={cat}/gcc-')
            open(mx, 'w').write(t)
        print(cat, pkg, keep)
# afterwards: add `thin-manifests = true` to the crossdev overlay layout.conf (remove crossdev's
# 'managed by' header first), run `ebuild X manifest` per ebuild, then `crossdev -oO <ov> -t <tuple>` to prove it.
