"""Builds every brand image from the app's own drawing code (BrandMark,
BrandLockup in lib/app), so the launcher icon, the splash and the app's
branding screen are one picture:

    python tool/make_brand_icons.py

1. renders build/brand/{mark,foreground,playstore,splash}.png with
   tool/brand/render_brand_test.dart (flutter test --update-goldens);
2. sizes them into the Android mipmaps (legacy + round 48 dp, adaptive
   foreground 108 dp), the Play Store icon, the web icons, and
   assets/icon/{icon,splash}.png;
3. sets the adaptive icon background to the plate's color and regenerates
   the native splash (flutter_native_splash, config in pubspec.yaml).

Colors live in lib/app/theme.dart (kBrandBlue, kAppBg) and
lib/app/brand_mark.dart (kBrandPlate); the leaf's outline is from
OpenDesign (brand/OpenFinances/final/leaf-path.txt).
"""
import os
import re
import subprocess

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
RES = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res')
SHELL = os.name == 'nt'


def run(*cmd):
    subprocess.run(list(cmd), cwd=ROOT, check=True, shell=SHELL)


def img(name):
    return Image.open(os.path.join(ROOT, 'build', 'brand', name + '.png')).convert('RGBA')


def save(im, px, *path):
    out = os.path.join(ROOT, *path)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    (im if im.size == (px, px) else im.resize((px, px), Image.LANCZOS)).save(out, optimize=True)


def main():
    run('flutter', 'test', 'tool/brand/render_brand_test.dart', '--update-goldens')
    mark, fg, store, splash = img('mark'), img('foreground'), img('playstore'), img('splash')
    for density, scale in {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}.items():
        folder = os.path.join(RES, f'mipmap-{density}')
        save(mark, int(48 * scale), folder, 'ic_launcher.png')
        save(mark, int(48 * scale), folder, 'ic_launcher_round.png')
        save(fg, int(108 * scale), folder, 'ic_launcher_foreground.png')
    save(store, 512, RES, 'playstore-icon.png')
    save(mark, 192, ROOT, 'web', 'icons', 'Icon-192.png')
    save(mark, 512, ROOT, 'web', 'icons', 'Icon-512.png')
    save(store, 192, ROOT, 'web', 'icons', 'Icon-maskable-192.png')
    save(store, 512, ROOT, 'web', 'icons', 'Icon-maskable-512.png')
    save(mark, 64, ROOT, 'web', 'favicon.png')
    save(mark, 1024, ROOT, 'assets', 'icon', 'icon.png')
    save(splash, 1152, ROOT, 'assets', 'icon', 'splash.png')

    plate = re.search(r'kBrandPlate = Color\(0xFF([0-9A-Fa-f]{6})\)',
                      open(os.path.join(ROOT, 'lib', 'app', 'brand_mark.dart'), encoding='utf-8').read()).group(1)
    path = os.path.join(RES, 'values', 'ic_launcher_background.xml')
    xml = open(path, encoding='utf-8').read()
    open(path, 'w', encoding='utf-8', newline='\n').write(
        re.sub(r'(<color name="ic_launcher_background">)#[0-9A-Fa-f]+(</color>)', rf'\1#{plate}\2', xml))
    run('dart', 'run', 'flutter_native_splash:create')
    print('brand images built')


if __name__ == '__main__':
    main()
