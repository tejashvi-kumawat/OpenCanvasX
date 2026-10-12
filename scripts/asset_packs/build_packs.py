#!/usr/bin/env python3
"""Builds OpenCanvasX's bundled, openly licensed asset packs (P2.1.7).

Two steps, so downloads stay reviewable:

  python scripts/asset_packs/build_packs.py fetch  [--cache DIR] [--only ID ...]
  python scripts/asset_packs/build_packs.py curate [--cache DIR] [--only ID ...]

`fetch` downloads the pinned upstream archives listed in SOURCES into the
cache (default: .cache/asset_packs, git-ignored). `curate` reads only from
the cache and writes `packages/asset_packs/assets/packs/<id>/` (validated SVGs, LICENSE,
pack.json) and `packages/asset_packs/assets/fonts/<family>/` (TTF + OFL.txt + font.json), then
`assets/packs/index.json`.

Every item carries licence metadata (asset-architecture.md, P2.1.1). SVGs
are rejected if they contain scripts, event handlers, external references,
entities or foreign content (input-validation-policy.md).

Run with `python -I` when the cache holds untrusted downloads.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import re
import shutil
import sys
import tarfile
import unicodedata
import urllib.parse
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PACKS = ROOT / 'packages' / 'asset_packs' / 'assets' / 'packs'
FONTS = ROOT / 'packages' / 'asset_packs' / 'assets' / 'fonts'
MAX_SVG_BYTES = 256 * 1024

GF = 'https://raw.githubusercontent.com/google/fonts/main/ofl'

# (family dir, display name, files, category)
FONT_FAMILIES = [
    ('inter', 'Inter', ['Inter[opsz,wght].ttf'], 'sans'),
    ('roboto', 'Roboto', ['Roboto[wdth,wght].ttf'], 'sans'),
    ('montserrat', 'Montserrat', ['Montserrat[wght].ttf'], 'sans'),
    ('poppins', 'Poppins', ['Poppins-Regular.ttf', 'Poppins-Medium.ttf',
                            'Poppins-SemiBold.ttf', 'Poppins-Bold.ttf'], 'sans'),
    ('playfairdisplay', 'Playfair Display', ['PlayfairDisplay[wght].ttf'], 'serif'),
    ('lora', 'Lora', ['Lora[wght].ttf'], 'serif'),
    ('merriweather', 'Merriweather', ['Merriweather[opsz,wdth,wght].ttf'], 'serif'),
    ('oswald', 'Oswald', ['Oswald[wght].ttf'], 'display'),
    ('raleway', 'Raleway', ['Raleway[wght].ttf'], 'sans'),
    ('nunito', 'Nunito', ['Nunito[wght].ttf'], 'sans'),
    ('worksans', 'Work Sans', ['WorkSans[wght].ttf'], 'sans'),
    ('dmsans', 'DM Sans', ['DMSans[opsz,wght].ttf'], 'sans'),
    ('spacegrotesk', 'Space Grotesk', ['SpaceGrotesk[wght].ttf'], 'sans'),
    ('bebasneue', 'Bebas Neue', ['BebasNeue-Regular.ttf'], 'display'),
    ('pacifico', 'Pacifico', ['Pacifico-Regular.ttf'], 'handwriting'),
    ('caveat', 'Caveat', ['Caveat[wght].ttf'], 'handwriting'),
    ('lobster', 'Lobster', ['Lobster-Regular.ttf'], 'display'),
    ('sourceserif4', 'Source Serif 4', ['SourceSerif4[opsz,wght].ttf'], 'serif'),
    ('jetbrainsmono', 'JetBrains Mono', ['JetBrainsMono[wght].ttf'], 'mono'),
    ('notosans', 'Noto Sans', ['NotoSans[wdth,wght].ttf'], 'sans'),
]

SOURCES = {
    'lucide': {
        'url': 'https://github.com/lucide-icons/lucide/releases/download/1.55.0/lucide-icons-1.55.0.zip',
        'file': 'lucide-icons-1.55.0.zip',
    },
    'tabler': {
        'url': 'https://registry.npmjs.org/@tabler/icons/-/icons-3.49.0.tgz',
        'file': 'icons-3.49.0.tgz',
    },
    'phosphor': {
        'url': 'https://registry.npmjs.org/@phosphor-icons/core/-/core-2.1.1.tgz',
        'file': 'core-2.1.1.tgz',
    },
    'twemoji': {
        'url': 'https://registry.npmjs.org/@twemoji/svg/-/svg-15.0.0.tgz',
        'file': 'svg-15.0.0.tgz',
    },
    'fonts': {
        'files': [
            (f'{GF}/{d}/{urllib.parse.quote(f)}', f'fonts/{d}/{f}')
            for d, _, files, _ in FONT_FAMILIES for f in files
        ] + [(f'{GF}/{d}/OFL.txt', f'fonts/{d}/OFL.txt')
             for d, _, _, _ in FONT_FAMILIES],
    },
}

LUCIDE_LICENSE = """ISC License

Copyright (c) for portions of Lucide are held by Cole Bemis 2013-2022 as part
of Feather (MIT). All other copyright (c) for Lucide are held by Lucide
Contributors 2022.

Permission to use, copy, modify, and/or distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION
OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN
CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

---

The MIT License (MIT) (for portions derived from Feather)

Copyright (c) 2013-2022 Cole Bemis

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
"""

TWEMOJI_GRAPHICS_LICENSE = """Twemoji graphics

Copyright 2019 Twitter, Inc and other contributors; maintained by jdecked
and contributors (https://github.com/jdecked/twemoji).

The graphics are licensed under CC-BY 4.0:
https://creativecommons.org/licenses/by/4.0/

Attribution required: "Twemoji by Twitter, Inc and other contributors,
licensed under CC-BY 4.0". OpenCanvasX shows this credit in the asset panel
and in About. Code in the upstream package (not bundled) is MIT:

"""

UNSAFE = re.compile(
    r'<script|<foreignObject|<!ENTITY|<!DOCTYPE|<iframe|<embed|<object|'
    r'\son[a-z]+\s*=|javascript:|data:text/html|'
    r'(?:xlink:)?href\s*=\s*["\'](?!#)|url\(\s*["\']?(?!#)',
    re.IGNORECASE,
)


def safe_svg(data: bytes) -> bytes | None:
    """The SVG if it passes validation, else None."""
    if len(data) > MAX_SVG_BYTES:
        return None
    try:
        text = data.decode('utf-8')
    except UnicodeDecodeError:
        return None
    if '<svg' not in text or UNSAFE.search(text):
        return None
    # Drop presentation-only classes; keep geometry and colours.
    text = re.sub(r'\sclass="[^"]*"', '', text)
    return text.strip().encode('utf-8') + b'\n'


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def title(name: str) -> str:
    return name.replace('-', ' ').replace('_', ' ').strip().capitalize()


def write_pack(pack: dict, files: dict[str, bytes], license_text: str) -> None:
    out = PACKS / pack['id']
    if out.exists():
        shutil.rmtree(out)
    (out / 'svg').mkdir(parents=True)
    for rel, data in files.items():
        (out / rel).write_bytes(data)
    (out / 'LICENSE').write_text(license_text, encoding='utf-8')
    (out / 'pack.json').write_text(
        json.dumps(pack, indent=1, ensure_ascii=False) + '\n', encoding='utf-8')
    print(f"  {pack['id']}: {len(pack['items'])} items, "
          f"{sum(len(d) for d in files.values()) / 1e6:.1f} MB")


def item(pack_id: str, name: str, rel: str, data: bytes, *, tags, category,
         style=None) -> dict:
    entry = {
        'id': f'{pack_id}/{Path(rel).stem}',
        'name': title(name),
        'file': rel,
        'sha256': sha(data),
        'mime': 'image/svg+xml',
        'tags': sorted({t for t in tags if t}),
        'category': category,
    }
    if style:
        entry['style'] = style
    return entry


def pack_header(pid, name, kind, version, spdx, url, author, source, *,
                attribution_required=False, attribution=None, recolorable):
    return {
        'id': pid, 'name': name, 'kind': kind, 'version': version,
        'license': spdx, 'license_url': url, 'author': author,
        'source': source, 'attribution_required': attribution_required,
        'attribution': attribution, 'recolorable': recolorable,
        'redistribution': True, 'modification': True, 'items': [],
    }


# ------------------------------------------------------------------ packs

def curate_lucide(cache: Path) -> None:
    src = SOURCES['lucide']
    with zipfile.ZipFile(cache / 'lucide' / src['file']) as z:
        names = set(z.namelist())
        pack = pack_header(
            'lucide', 'Lucide', 'icon', '1.55.0', 'ISC',
            'https://lucide.dev/license', 'Lucide Contributors', src['url'],
            recolorable=True)
        files, rejected = {}, 0
        for n in sorted(names):
            if not (n.startswith('icons/') and n.endswith('.svg')):
                continue
            stem = Path(n).stem
            data = safe_svg(z.read(n))
            if data is None:
                rejected += 1
                continue
            meta = {}
            if f'icons/{stem}.json' in names:
                meta = json.loads(z.read(f'icons/{stem}.json'))
            rel = f'svg/{stem}.svg'
            files[rel] = data
            cats = meta.get('categories') or ['other']
            pack['items'].append(item(
                'lucide', stem, rel, data,
                tags=stem.split('-') + list(meta.get('tags', [])),
                category=cats[0]))
    write_pack(pack, files, LUCIDE_LICENSE)
    if rejected:
        print(f'  lucide: rejected {rejected}')


def curate_tabler(cache: Path) -> None:
    src = SOURCES['tabler']
    with tarfile.open(cache / 'tabler' / src['file'], 'r:gz') as t:
        members = {m.name: m for m in t.getmembers() if m.isfile()}
        category = {}
        for name in members:
            parts = name.split('/')
            if len(parts) == 5 and parts[1] == 'categories' and parts[2] == 'outline':
                category[Path(parts[4]).stem] = parts[3].lower()
        pack = pack_header(
            'tabler', 'Tabler Icons', 'icon', '3.49.0', 'MIT',
            'https://github.com/tabler/tabler-icons/blob/main/LICENSE',
            'Paweł Kuna', src['url'], recolorable=True)
        files, rejected = {}, 0
        for name in sorted(members):
            parts = name.split('/')
            if len(parts) != 4 or parts[1] != 'icons' or not name.endswith('.svg'):
                continue
            style, stem = parts[2], Path(parts[3]).stem
            data = safe_svg(t.extractfile(members[name]).read())
            if data is None:
                rejected += 1
                continue
            rel = f'svg/{stem}{"" if style == "outline" else "-" + style}.svg'
            files[rel] = data
            pack['items'].append(item(
                'tabler', stem, rel, data, tags=stem.split('-'),
                category=category.get(stem, 'other'), style=style))
        license_text = t.extractfile(members['package/LICENSE']).read().decode()
    write_pack(pack, files, license_text)
    if rejected:
        print(f'  tabler: rejected {rejected}')


def curate_phosphor(cache: Path) -> None:
    src = SOURCES['phosphor']
    keep = ('regular', 'fill', 'duotone')
    with tarfile.open(cache / 'phosphor' / src['file'], 'r:gz') as t:
        members = {m.name: m for m in t.getmembers() if m.isfile()}
        pack = pack_header(
            'phosphor', 'Phosphor Icons', 'icon', '2.1.1', 'MIT',
            'https://github.com/phosphor-icons/core/blob/main/LICENSE',
            'Phosphor Icons (Helena Zhang, Tobias Fried)', src['url'],
            recolorable=True)
        files, rejected = {}, 0
        for name in sorted(members):
            parts = name.split('/')
            if (len(parts) != 4 or parts[1] != 'assets' or parts[2] not in keep
                    or not name.endswith('.svg')):
                continue
            style, stem = parts[2], Path(parts[3]).stem
            data = safe_svg(t.extractfile(members[name]).read())
            if data is None:
                rejected += 1
                continue
            base = re.sub(r'-(fill|duotone)$', '', stem)
            rel = f'svg/{stem}.svg'
            files[rel] = data
            pack['items'].append(item(
                'phosphor', base, rel, data, tags=base.split('-'),
                category='other', style=style))
        license_text = t.extractfile(members['package/LICENSE']).read().decode()
    write_pack(pack, files, license_text)
    if rejected:
        print(f'  phosphor: rejected {rejected}')


EMOJI_GROUPS = [
    ('Flags', ('REGIONAL INDICATOR', 'FLAG', 'TAG LATIN')),
    ('Faces', ('FACE', 'SMILING', 'GRINNING', 'WINKING', 'POUTING')),
    ('Hands', ('HAND', 'FINGER', 'THUMBS', 'FIST', 'PALM', 'CLAPPING')),
    ('People', ('MAN', 'WOMAN', 'PERSON', 'BOY', 'GIRL', 'BABY', 'PEOPLE',
                'FAMILY', 'COUPLE', 'KISS', 'GUARD', 'DANCER', 'PRINCE',
                'SANTA', 'MERMAID', 'ELF', 'GENIE', 'ZOMBIE', 'SKIN TONE')),
    ('Animals & nature', ('CAT', 'DOG', 'BIRD', 'FISH', 'HORSE', 'COW', 'PIG',
                          'MONKEY', 'BEAR', 'TIGER', 'LION', 'RABBIT', 'MOUSE',
                          'SNAKE', 'TURTLE', 'BUG', 'BEE', 'ANT', 'SPIDER',
                          'TREE', 'FLOWER', 'LEAF', 'BLOSSOM', 'ROSE', 'CACTUS',
                          'PLANT', 'MUSHROOM', 'WHALE', 'DOLPHIN', 'OCTOPUS',
                          'CRAB', 'DRAGON', 'UNICORN', 'PAW', 'FROG', 'OWL',
                          'DUCK', 'PENGUIN', 'CHICKEN', 'SHEEP', 'GOAT',
                          'ELEPHANT', 'SUN', 'MOON', 'STAR', 'CLOUD', 'RAIN',
                          'SNOW', 'FIRE', 'WATER WAVE', 'RAINBOW', 'EARTH')),
    ('Food & drink', ('FOOD', 'APPLE', 'PEAR', 'BANANA', 'GRAPES', 'MELON',
                      'CHERRIES', 'STRAWBERRY', 'PEACH', 'LEMON', 'TOMATO',
                      'PIZZA', 'BURGER', 'HAMBURGER', 'FRIES', 'BREAD', 'CHEESE',
                      'CAKE', 'COOKIE', 'CANDY', 'CHOCOLATE', 'COFFEE', 'TEA',
                      'BEER', 'WINE', 'COCKTAIL', 'BOTTLE', 'CUP', 'RICE',
                      'NOODLE', 'SUSHI', 'TACO', 'BURRITO', 'EGG', 'MEAT',
                      'POULTRY', 'ICE CREAM', 'DOUGHNUT', 'POPCORN', 'CARROT',
                      'CORN', 'PEPPER', 'AVOCADO', 'COCONUT', 'KIWI', 'MANGO',
                      'PINEAPPLE', 'POTATO', 'ONION', 'GARLIC', 'SALAD')),
    ('Travel & places', ('CAR', 'TRAIN', 'BUS', 'AIRPLANE', 'SHIP', 'BOAT',
                         'ROCKET', 'BICYCLE', 'MOTOR', 'TAXI', 'TRUCK',
                         'HOUSE', 'BUILDING', 'OFFICE', 'HOSPITAL', 'SCHOOL',
                         'CASTLE', 'TOWER', 'BRIDGE', 'MOUNTAIN', 'VOLCANO',
                         'BEACH', 'DESERT', 'ISLAND', 'STADIUM', 'TENT',
                         'STATION', 'MAP', 'GLOBE', 'HELICOPTER', 'TRAM')),
    ('Activities', ('BALL', 'SPORT', 'TROPHY', 'MEDAL', 'GAME', 'DICE',
                    'SKI', 'GOLF', 'TENNIS', 'BOWLING', 'FISHING', 'SURF',
                    'SWIM', 'PARTY', 'BALLOON', 'GIFT', 'TICKET', 'GUITAR',
                    'PIANO', 'DRUM', 'MICROPHONE', 'ARTIST', 'CONFETTI',
                    'FIREWORK', 'SPARKLER', 'CHRISTMAS', 'JACK-O-LANTERN')),
    ('Symbols', ('ARROW', 'SIGN', 'SYMBOL', 'SQUARED', 'KEYCAP', 'CIRCLED',
                 'DIGIT', 'HEART', 'MARK', 'BUTTON', 'CIRCLE', 'SQUARE',
                 'TRIANGLE', 'DIAMOND', 'ZODIAC', 'ARIES', 'TAURUS', 'GEMINI',
                 'CANCER', 'LEO', 'VIRGO', 'LIBRA', 'SCORPIUS', 'SAGITTARIUS',
                 'CAPRICORN', 'AQUARIUS', 'PISCES', 'OPHIUCHUS', 'NUMBER',
                 'LATIN', 'CJK', 'IDEOGRAPH')),
]
SKIP_CP = {0x200D, 0xFE0F, 0xFE0E, 0x20E3}


def emoji_name(stem: str) -> tuple[str, str]:
    cps = [int(p, 16) for p in stem.split('-')]
    words = []
    for cp in cps:
        if cp in SKIP_CP or 0xE0020 <= cp <= 0xE007F:
            continue
        try:
            words.append(unicodedata.name(chr(cp)))
        except ValueError:
            words.append(f'U+{cp:04X}')
    upper = ' '.join(words)
    group = 'Objects'
    if all(0x1F1E6 <= cp <= 0x1F1FF for cp in cps):
        group = 'Flags'
    else:
        for g, keys in EMOJI_GROUPS:
            if any(k in upper for k in keys):
                group = g
                break
    name = ' '.join(w.lower() for w in words) or stem
    return name, group


def curate_twemoji(cache: Path) -> None:
    src = SOURCES['twemoji']
    with tarfile.open(cache / 'twemoji' / src['file'], 'r:gz') as t:
        members = {m.name: m for m in t.getmembers() if m.isfile()}
        pack = pack_header(
            'twemoji', 'Twemoji', 'sticker', '15.0.0', 'CC-BY-4.0',
            'https://creativecommons.org/licenses/by/4.0/',
            'Twitter, Inc and other contributors (jdecked/twemoji)', src['url'],
            attribution_required=True,
            attribution='Twemoji by Twitter, Inc and other contributors, '
                        'licensed under CC-BY 4.0',
            recolorable=False)
        files, rejected = {}, 0
        for name in sorted(members):
            if not name.endswith('.svg') or name.count('/') != 1:
                continue
            stem = Path(name).stem
            if not re.fullmatch(r'[0-9a-f]+(-[0-9a-f]+)*', stem):
                continue
            data = safe_svg(t.extractfile(members[name]).read())
            if data is None:
                rejected += 1
                continue
            label, group = emoji_name(stem)
            rel = f'svg/{stem}.svg'
            files[rel] = data
            entry = item('twemoji', label, rel, data,
                         tags=re.split(r'[\s-]+', label), category=group)
            entry['name'] = label.capitalize()
            pack['items'].append(entry)
        code_license = t.extractfile(members['package/license']).read().decode()
    write_pack(pack, files, TWEMOJI_GRAPHICS_LICENSE + code_license)
    if rejected:
        print(f'  twemoji: rejected {rejected}')


def curate_fonts(cache: Path) -> None:
    base = cache / 'fonts'
    if not base.exists():
        print('  fonts: not fetched, skipped')
        return
    FONTS.mkdir(parents=True, exist_ok=True)
    families = []
    for d, display, files, category in FONT_FAMILIES:
        src = base / d
        if not all((src / f).exists() for f in files) or not (src / 'OFL.txt').exists():
            print(f'  fonts: {display} incomplete, skipped')
            continue
        out = FONTS / d
        if out.exists():
            shutil.rmtree(out)
        out.mkdir(parents=True)
        entries = []
        for f in files:
            data = (src / f).read_bytes()
            if data[:4] not in (b'\x00\x01\x00\x00', b'true', b'OTTO'):
                print(f'  fonts: {f} is not a font, skipped')
                continue
            safe = f.replace('[', '_').replace(']', '').replace(',', '_')
            (out / safe).write_bytes(data)
            entries.append({'file': safe, 'sha256': sha(data)})
        shutil.copyfile(src / 'OFL.txt', out / 'OFL.txt')
        meta = {
            'family': display, 'category': category, 'license': 'OFL-1.1',
            'license_url': 'https://openfontlicense.org',
            'source': f'https://github.com/google/fonts/tree/main/ofl/{d}',
            'files': entries,
        }
        (out / 'font.json').write_text(json.dumps(meta, indent=1) + '\n',
                                       encoding='utf-8')
        families.append({'dir': d, 'family': display, 'category': category})
    (FONTS / 'index.json').write_text(
        json.dumps({'families': families}, indent=1) + '\n', encoding='utf-8')
    print(f'  fonts: {len(families)} families')


CURATORS = {
    'lucide': curate_lucide,
    'tabler': curate_tabler,
    'phosphor': curate_phosphor,
    'twemoji': curate_twemoji,
    'fonts': curate_fonts,
}


def write_index() -> None:
    packs = []
    for p in sorted(PACKS.glob('*/pack.json')):
        meta = json.loads(p.read_text(encoding='utf-8'))
        packs.append({k: meta[k] for k in (
            'id', 'name', 'kind', 'version', 'license', 'attribution_required',
            'attribution', 'recolorable')} | {'count': len(meta['items'])})
    (PACKS / 'index.json').write_text(
        json.dumps({'packs': packs}, indent=1, ensure_ascii=False) + '\n',
        encoding='utf-8')


def fetch(cache: Path, only: list[str]) -> None:
    for pid, src in SOURCES.items():
        if only and pid not in only:
            continue
        targets = src.get('files') or [(src['url'], f"{pid}/{src['file']}")]
        for url, rel in targets:
            dest = cache / rel
            if dest.exists():
                continue
            dest.parent.mkdir(parents=True, exist_ok=True)
            print(f'  GET {url}')
            with urllib.request.urlopen(url, timeout=60) as r:
                dest.write_bytes(r.read())


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('step', choices=['fetch', 'curate'])
    parser.add_argument('--cache', type=Path, default=ROOT / '.cache' / 'asset_packs')
    parser.add_argument('--only', nargs='*', default=[])
    args = parser.parse_args()
    if args.step == 'fetch':
        fetch(args.cache, args.only)
        return 0
    PACKS.mkdir(parents=True, exist_ok=True)
    for pid, curate in CURATORS.items():
        if args.only and pid not in args.only:
            continue
        if pid != 'fonts' and not (args.cache / pid).exists():
            print(f'  {pid}: not fetched, skipped')
            continue
        curate(args.cache)
    write_index()
    return 0


if __name__ == '__main__':
    sys.exit(main())
