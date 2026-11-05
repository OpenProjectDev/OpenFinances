"""Bundles Flaticon's UIcons (free with credit: "Uicons by Flaticon", shown in
Settings > About) and generates lib/shared/ui/uicons.g.dart.

    python tool/gen_uicons.py            # download, convert, generate
    python tool/gen_uicons.py --check    # only report unknown icon names
    python tool/gen_uicons.py --center   # only re-center the bundled fonts

Writes:
- assets/fonts/uicons/uicons-{solid-rounded,bold-rounded,brands}.ttf (the npm
  package ships web fonts; Flutter needs TTF), every glyph's ink centered
  vertically in its box (so an icon lines up with text and other icons
  wherever it's centered), Solid Rounded's across too, each drawn where its
  outline is (the package's bearings put narrow ones, e.g. the lipstick, at
  the box's left edge: off center in every circle and chip), and
  LICENSE.txt;
- lib/shared/ui/uicons.g.dart: every Solid Rounded icon by name (the category
  icon picker and its search), the picker's groups, the app's own UI glyphs
  ([UIcons]), and the old Material category icons mapped to UIcons (categories
  saved before the switch keep a matching icon; nothing stored is rewritten).

Icon names are checked against the package: a typo fails the run.
"""
import io
import os
import re
import shutil
import subprocess
import sys
import tarfile
import urllib.request

from fontTools.ttLib import TTFont

VERSION = '3.3.1'
TARBALL = f'https://registry.npmjs.org/@flaticon/flaticon-uicons/-/flaticon-uicons-{VERSION}.tgz'
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
MATERIAL = os.path.join(os.path.dirname(os.path.realpath(shutil.which('flutter'))), '..',
                        'packages/flutter/lib/src/material/icons.dart')

# style -> (css path in the package, css prefix, font family in the app)
STYLES = {
    'solid-rounded': ('css/solid/rounded.css', 'fi-sr', 'UIconsSR'),
    'bold-rounded': ('css/bold/rounded.css', 'fi-br', 'UIconsBR'),
    'brands': ('css/brands/all.css', 'fi-brands', 'UIconsBrands'),
}

# The interface's glyphs: Dart name, style, icon, mirrors in RTL.
# Line glyphs come from Bold Rounded (Solid Rounded draws them hairline thin).
UI = [
    ('sort', 'bold-rounded', 'bars-sort', False),
    ('arrowUp', 'bold-rounded', 'arrow-small-up', False),
    ('arrowDown', 'bold-rounded', 'arrow-small-down', False),
    ('back', 'bold-rounded', 'arrow-left', True),
    ('check', 'bold-rounded', 'check', False),
    ('drag', 'bold-rounded', 'grip-lines', False),
    ('email', 'solid-rounded', 'envelope', False),
    ('backspace', 'solid-rounded', 'delete', False),
]

# The category icon picker's tabs after "All" (key = ARB suffix: iconGroup<Key>).
GROUPS = [
    ('Shopping', 'shopping-cart shopping-bag shopping-basket store-alt shop tags gift '
                 'receipt barcode-read box-open-full truck-side shirt-long-sleeve '
                 'shoe-prints glasses ring diamond watch-smart'),
    ('Money', 'wallet coins money-bill-wave money credit-card piggy-bank bank sack-dollar '
              'hand-holding-usd chart-line-up chart-pie percentage calculator money-check '
              'donate dollar euro hand-holding-heart chart-histogram'),
    ('Food', 'utensils burger-alt pizza-slice ice-cream cake-birthday coffee mug-hot '
             'bread-slice croissant fish egg apple-whole carrot glass-cheers glass-champagne '
             'cheese drumstick-bite salad popcorn candy-cane cookie lemon '
             'restaurant hotdog french-fries sandwich'),
    ('Transport', 'car-side taxi bus train-side subway plane-alt ship motorcycle '
                  'bicycle-journey gas-pump charging-station parking road car-wash '
                  'truck-moving scooter helicopter-side car-mechanic tire'),
    ('Home', 'home couch bed bulb plug flame raindrops broom washer key lock door-open '
             'temperature-high garage tools hammer paint-roller building chair-office '
             'lamp-floor fan toilet-paper-blank shower trash'),
    ('Bills', 'bolt wifi phone-call mobile-notch tv-retro faucet fire-flame-curved '
              'receipt file-invoice-dollar envelope-open-dollar calendar-clock '
              'router signal-alt-2 cloud satellite-dish'),
    ('Tech', 'laptop computer mobile-notch headphones gamepad camera print keyboard mouse '
             'tablet desktop-wallpaper microchip usb-pendrive watch-smart speaker '
             'cloud-download-alt code-simple'),
    ('Health', 'medicine heart-rate dumbbell-fitness spa tooth syringe stethoscope '
               'hospital capsules band-aid eye brain lungs dna '
               'running meditation'),
    ('Personal', 'baby baby-carriage paw user users scissors lipstick gift ring '
                 'shirt-running heart hand-holding-heart hair-clipper dog cat makeup-brush '
                 'spray-can-sparkles'),
    ('Work', 'briefcase graduation-cap book-alt document pencil calendar flask globe '
             'id-badge school backpack chalkboard-user laptop-code presentation '
             'stamp handshake'),
    ('Leisure', 'film music ticket theater-masks football basketball gamepad dice palette '
                'camera-retro tree umbrella-beach mountains hiking skiing map-marker '
                'suitcase-alt hotel swimmer guitar book-open-reader bowling-ball'),
    ('Other', 'apps star heart flag label rocket-lunch sparkles puzzle-alt sun moon '
              'shield-check bell interrogation marker time-fast menu-dots infinity '
              'lightbulb-on trophy crown'),
]

# Old category icons (Material, by name) -> the closest UIcon. Categories saved
# before the switch show these; picking again stores the UIcon itself.
FROM_MATERIAL = {
    'shopping_cart': 'shopping-cart', 'shopping_bag': 'shopping-bag',
    'local_mall_outlined': 'shopping-bag', 'storefront': 'store-alt', 'receipt_long': 'receipt',
    'paid_outlined': 'money-bill-wave', 'attach_money': 'dollar', 'point_of_sale': 'cash-register',
    'account_balance_wallet_outlined': 'wallet', 'request_quote_outlined': 'file-invoice-dollar',
    'credit_card': 'credit-card', 'credit_score': 'credit-card', 'savings_outlined': 'piggy-bank',
    'account_balance': 'bank', 'trending_up': 'chart-line-up', 'price_change': 'percentage',
    'local_offer_outlined': 'tags',
    'restaurant': 'utensils', 'local_cafe': 'coffee', 'fastfood': 'burger-alt',
    'local_pizza': 'pizza-slice', 'icecream': 'ice-cream', 'cake_outlined': 'cake-birthday',
    'local_bar': 'glass-cheers', 'local_dining': 'utensils', 'emoji_food_beverage': 'mug-hot',
    'ramen_dining': 'restaurant', 'kebab_dining': 'drumstick-bite', 'set_meal': 'fish',
    'breakfast_dining': 'croissant', 'lunch_dining': 'sandwich', 'dinner_dining': 'utensils',
    'no_food': 'utensils', 'local_drink': 'glass-cheers', 'egg_alt': 'egg',
    'bakery_dining': 'bread-slice',
    'directions_car': 'car-side', 'two_wheeler': 'motorcycle', 'directions_bus': 'bus',
    'local_taxi': 'taxi', 'train': 'train-side', 'flight': 'plane-alt',
    'luggage': 'suitcase-alt', 'directions_boat': 'ship', 'electric_car': 'charging-station',
    'ev_station': 'charging-station', 'local_gas_station': 'gas-pump',
    'pedal_bike': 'bicycle-journey', 'subway': 'subway', 'tram': 'subway',
    'sailing': 'ship', 'airport_shuttle': 'bus', 'commute': 'bus', 'toll': 'road',
    'directions_railway': 'train-side',
    'home_outlined': 'home', 'weekend': 'couch', 'chair_alt': 'chair-office',
    'apartment': 'building', 'lightbulb_outline': 'bulb', 'bolt': 'bolt',
    'electrical_services': 'plug', 'water_drop_outlined': 'raindrops',
    'local_fire_department': 'flame', 'construction': 'hammer',
    'cleaning_services': 'broom', 'inventory_2': 'box-open-full', 'wash': 'washer',
    'iron': 'shirt-long-sleeve', 'shower': 'shower', 'key': 'key', 'lock_outline': 'lock',
    'sensor_door': 'door-open', 'thermostat': 'temperature-high', 'garage_outlined': 'garage',
    'phone_iphone': 'mobile-notch', 'laptop_mac': 'laptop', 'headphones': 'headphones',
    'tv': 'tv-retro', 'sports_esports': 'gamepad', 'movie_outlined': 'film',
    'music_note': 'music', 'videogame_asset_outlined': 'gamepad', 'cast': 'tv-retro',
    'camera_alt_outlined': 'camera', 'photo_outlined': 'picture', 'wifi_tethering': 'wifi',
    'tablet_mac': 'tablet', 'desktop_windows': 'computer', 'router': 'router',
    'speaker': 'speaker', 'memory': 'microchip', 'print': 'print', 'keyboard': 'keyboard',
    'mouse': 'mouse',
    'work_outline': 'briefcase', 'business_center': 'briefcase', 'book_outlined': 'book-alt',
    'school': 'graduation-cap', 'description_outlined': 'document', 'draw_outlined': 'pencil',
    'event_note': 'calendar', 'science_outlined': 'flask', 'handyman_outlined': 'tools',
    'language': 'globe', 'computer': 'computer', 'badge_outlined': 'id-badge',
    'task_alt': 'checkbox', 'checklist': 'list', 'calendar_month': 'calendar',
    'sticky_note_2_outlined': 'document', 'auto_stories': 'book-open-reader',
    'class_': 'book-alt', 'workspace_premium_outlined': 'trophy',
    'local_pharmacy': 'medicine', 'medical_services': 'stethoscope', 'healing': 'band-aid',
    'psychology_alt_outlined': 'brain', 'spa': 'spa', 'fitness_center': 'dumbbell-fitness',
    'health_and_safety': 'shield-check', 'masks': 'mask-face', 'bedtime': 'moon',
    'brush_outlined': 'makeup-brush', 'face_retouching_natural': 'lipstick',
    'sanitizer': 'hand-holding-heart', 'vaccines': 'syringe', 'monitor_weight': 'heart-rate',
    'self_improvement': 'meditation', 'stroller': 'baby-carriage', 'child_care': 'baby',
    'pets': 'paw', 'emoji_people': 'user',
    'park': 'tree', 'beach_access': 'umbrella-beach', 'travel_explore': 'globe',
    'card_travel': 'suitcase-alt', 'map_outlined': 'map', 'explore_outlined': 'map-marker',
    'hiking': 'hiking', 'snowboarding': 'skiing', 'sports_soccer': 'football',
    'theaters': 'theater-masks', 'palette_outlined': 'palette', 'style': 'tags',
    'attractions': 'ticket', 'museum': 'building', 'festival': 'ticket',
    'local_activity': 'ticket', 'local_play': 'ticket', 'casino': 'dice',
    'local_see': 'camera-retro', 'landscape': 'mountains',
    'star_border': 'star', 'favorite_border': 'heart', 'flag_outlined': 'flag',
    'label_outline': 'label', 'rocket_launch_outlined': 'rocket-lunch',
    'auto_awesome': 'sparkles', 'extension_outlined': 'puzzle-alt', 'light_mode_outlined': 'sun',
    'nightlight_outlined': 'moon', 'shield_outlined': 'shield-check',
    'emoji_objects_outlined': 'bulb', 'notifications_none': 'bell', 'security': 'shield-check',
    'public': 'globe', 'support': 'interrogation', 'help_outline': 'interrogation',
    'pin_drop_outlined': 'marker', 'timer_outlined': 'time-fast', 'more_horiz': 'menu-dots',
}


def center_glyphs(font, across=False):
    """Moves every glyph up or down so its ink is centered in the line box
    (the box Flutter's Icon centers): most already are, a few sit off.
    [across]: also left or right, to the middle of its advance (the category
    icons). And every glyph's left side bearing is set to its outline's left
    edge: the package's fonts say 0 for most (e.g. the lipstick: outline at
    62..238 of 300), and FreeType draws a glyph from its bearing, so narrow
    ones sat at the box's left edge (the owner, 2026-10-26)."""
    hhea = font['hhea']
    middle = (hhea.ascent + hhea.descent) / 2  # descent is negative
    glyf = font['glyf']
    hmtx = font['hmtx']
    for name in glyf.keys():
        g = glyf[name]
        if g.isComposite() or g.numberOfContours <= 0:
            continue
        g.recalcBounds(glyf)
        dy = round(middle - (g.yMin + g.yMax) / 2)
        advance = hmtx[name][0]
        dx = round(advance / 2 - (g.xMin + g.xMax) / 2) if across else 0
        if dx or dy:
            g.coordinates.translate((dx, dy))
            g.recalcBounds(glyf)
        hmtx[name] = (advance, g.xMin)


def center_bundled():
    out = os.path.join(ROOT, 'assets', 'fonts', 'uicons')
    for style in STYLES:
        path = os.path.join(out, f'uicons-{style}.ttf')
        font = TTFont(path)
        center_glyphs(font, across=style == 'solid-rounded')
        font.save(path)
    print('centered')


def css_names(css, prefix):
    return {m.group(1): int(m.group(2), 16)
            for m in re.finditer(r'\.' + prefix + r'-([a-z0-9-]+):before\{content:"\\([0-9a-f]+)"', css)}


def main():
    if '--center' in sys.argv:
        center_bundled()
        return
    check_only = '--check' in sys.argv
    tgz = urllib.request.urlopen(TARBALL).read()
    tar = tarfile.open(fileobj=io.BytesIO(tgz))
    files = {m.name: m for m in tar.getmembers()}

    def read(path):
        return tar.extractfile(files['package/' + path]).read()

    names = {}
    for style, (css, prefix, family) in STYLES.items():
        names[style] = css_names(read(css).decode('utf-8'), prefix)

    material = {m.group(1): int(m.group(2), 16) for m in re.finditer(
        r"static const IconData (\w+) = IconData\(\s*0x([0-9a-f]+),\s*fontFamily: 'MaterialIcons'",
        open(MATERIAL, encoding='utf-8').read())}

    bad = []
    for dart, style, icon, _ in UI:
        if icon not in names[style]:
            bad.append(f'UI {dart}: {style}/{icon}')
    for key, icons in GROUPS:
        for i in icons.split():
            if i not in names['solid-rounded']:
                bad.append(f'group {key}: {i}')
    for m, u in FROM_MATERIAL.items():
        if m not in material:
            bad.append(f'material: {m}')
        if u not in names['solid-rounded']:
            bad.append(f'from material {m}: {u}')
    if bad:
        sr = names['solid-rounded']
        for b in bad:
            word = b.split(': ')[-1].split('/')[-1].split('-')[0]
            print('UNKNOWN', b, '| try:', ' '.join(sorted(k for k in sr if k.startswith(word))[:8]))
        sys.exit(1)
    print('all names known')
    if check_only:
        return

    out = os.path.join(ROOT, 'assets', 'fonts', 'uicons')
    os.makedirs(out, exist_ok=True)
    for style in STYLES:
        woff = next(n for n in files if re.match(rf'package/css/uicons-{style}-[A-Z0-9]+\.woff$', n))
        font = TTFont(io.BytesIO(read(woff[len('package/'):])))
        font.flavor = None
        center_glyphs(font, across=style == 'solid-rounded')
        font.save(os.path.join(out, f'uicons-{style}.ttf'))
    open(os.path.join(out, 'LICENSE.txt'), 'wb').write(read('LICENSE'))

    def icon(style, name, mirror=False):
        family = STYLES[style][2]
        extra = ', matchTextDirection: true' if mirror else ''
        return f"IconData(0x{names[style][name]:x}, fontFamily: '{family}'{extra})"

    lines = [
        '// GENERATED by tool/gen_uicons.py from @flaticon/flaticon-uicons '
        f'{VERSION}. Do not edit.',
        '// Uicons by Flaticon (https://www.flaticon.com/uicons): free with credit,',
        '// given in Settings > About.',
        '// ignore_for_file: constant_identifier_names',
        '',
        "import 'package:flutter/widgets.dart';",
        '',
        "/// The app's own UI glyphs (line ones from Bold Rounded, filled ones from",
        '/// Solid Rounded).',
        'abstract final class UIcons {',
    ]
    for dart, style, name, mirror in UI:
        lines.append(f'  static const {dart} = {icon(style, name, mirror)};')
    lines += ['}', '',
              '/// Every Solid Rounded icon by name (the category icon picker; its',
              '/// search matches these names).',
              'const Map<String, IconData> kUIconsSolid = {']
    for n in sorted(names['solid-rounded']):
        lines.append(f"  '{n}': {icon('solid-rounded', n)},")
    lines += ['};', '',
              "/// The picker's tabs after \"All\": ARB key suffix (`iconGroup<Key>`) and",
              '/// icon names (all in [kUIconsSolid]).',
              'const List<(String, List<String>)> kUIconGroups = [']
    for key, icons in GROUPS:
        lines.append(f"  ('{key}', [")
        for i in icons.split():
            lines.append(f"    '{i}',")
        lines.append('  ]),')
    lines += ['];', '',
              '/// Old (Material) category icon code points -> the closest UIcon name.',
              'const Map<int, String> kUIconForMaterial = {']
    for m, u in FROM_MATERIAL.items():
        lines.append(f"  0x{material[m]:x}: '{u}', // {m}")
    lines += ['};', '']
    path = os.path.join(ROOT, 'lib', 'shared', 'ui', 'uicons.g.dart')
    open(path, 'w', encoding='utf-8', newline='\n').write('\n'.join(lines))
    # Formatted like the rest of lib (so a rerun leaves no diff).
    subprocess.run(['dart', 'format', path], check=True, shell=os.name == 'nt')
    print('wrote', os.path.normpath(path), len(names['solid-rounded']), 'icons')


if __name__ == '__main__':
    main()
