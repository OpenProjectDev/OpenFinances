"""Makes the app's English font files: static cuts of Manrope (SIL Open Font
License 1.1) at its own weights: each Flutter weight gets the Manrope weight
of the same number (the owner, 2026-10-24: "use the default weight"; an
earlier mapping matched the old Ubuntu Sans cuts' stems, 350 / 500 / 675 /
800, and read thick).

    python tool/make_manrope.py

Downloads Manrope (the variable font, wght 200-800, from google/fonts) and
writes assets/fonts/manrope/Manrope-<weight>.ttf and OFL.txt.
"""
import io
import os
import urllib.request

from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

BASE = 'https://raw.githubusercontent.com/google/fonts/main/ofl/manrope/'
URL = BASE + 'Manrope%5Bwght%5D.ttf'
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'fonts', 'manrope')
# Manrope's weights, one per Flutter weight (w900 uses 800, its heaviest).
CUTS = (300, 400, 500, 600, 700, 800)


def main():
    os.makedirs(OUT, exist_ok=True)
    data = urllib.request.urlopen(URL).read()
    for w in CUTS:
        font = TTFont(io.BytesIO(data))
        cut = instancer.instantiateVariableFont(
            font, {'wght': w}, updateFontNames=False)
        path = os.path.join(OUT, f'Manrope-{w}.ttf')
        cut.save(path)
        print('wrote', os.path.normpath(path))
    lic = urllib.request.urlopen(BASE + 'OFL.txt').read()
    with open(os.path.join(OUT, 'OFL.txt'), 'wb') as f:
        f.write(lic)


if __name__ == '__main__':
    main()
