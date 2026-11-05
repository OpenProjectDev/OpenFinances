"""Makes the app's Persian font files and its two digit fonts (the owner's
design agent, 2026-10-28; all four fonts SIL Open Font License 1.1):

  Persian letters   Shabnam, Light (300)       assets/fonts/shabnam/
  English letters   Manrope, Light (300)       assets/fonts/manrope/ (make_manrope.py)
  English digits    Manrope, ExtraLight (200), tabular      assets/fonts/digits/ManropeNum-<w>.ttf
  Persian digits    Vazirmatn, ExtraLight (200), tabular    assets/fonts/digits/VazirNum-<w>.ttf

    python tool/make_fonts.py

The digit fonts hold ONLY digits and the separators next to them (, . % : /
and Persian ٫ ٬ ٪), so putting one first in a text's font list makes numbers
come from it and everything else from the next font. Tabular figures are
BAKED IN (the cmap points the digits at their `tnum` glyphs), so no
font-feature has to be asked for. Each cut is one step lighter than the
letters beside it: a Flutter weight W's digits are at W - 100 (the default,
W 400, shows Light letters and ExtraLight digits).

Downloads Shabnam (rastikerdar/shabnam-font), Vazirmatn (rastikerdar/vazirmatn)
and Manrope (google/fonts).
"""
import io
import os
import urllib.request

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

ROOT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'fonts')
SHABNAM = 'https://raw.githubusercontent.com/rastikerdar/shabnam-font/master/'
VAZIR = 'https://raw.githubusercontent.com/rastikerdar/vazirmatn/master/'
MANROPE = 'https://raw.githubusercontent.com/google/fonts/main/ofl/manrope/'

# The digit fonts' weights (the letters' weights minus 100).
DIGIT_WEIGHTS = (200, 300, 400, 500, 600, 700)

SEPARATORS = ',.%:/'
LATIN_DIGITS = '0123456789'
PERSIAN_DIGITS = '۰۱۲۳۴۵۶۷۸۹'
PERSIAN_SEPARATORS = '٫٬٪'
# Spaces too: a digit font that lacks them splits a Persian line into runs at
# every space and zero-width character, and the letters stop joining ("س ازی";
# the owner, 2026-10-28). Manrope has these; Shabnam's letters then come as one run.
SPACES = '  ⁠'


def get(url):
    return urllib.request.urlopen(url).read()


def tnum_map(font):
    """Glyph -> its tabular glyph, from the font's `tnum` feature."""
    gsub = font['GSUB'].table
    lookups = set()
    for rec in gsub.FeatureList.FeatureRecord:
        if rec.FeatureTag == 'tnum':
            lookups.update(rec.Feature.LookupListIndex)
    out = {}
    for i in lookups:
        for st in gsub.LookupList.Lookup[i].SubTable:
            st = getattr(st, 'ExtSubTable', st)
            out.update(getattr(st, 'mapping', {}))
    return out


def digit_cut(data, weight, chars, digits, name):
    font = TTFont(io.BytesIO(data))
    font = instancer.instantiateVariableFont(
        font, {'wght': weight}, updateFontNames=False)
    tnum = tnum_map(font)
    assert tnum, 'no tnum feature in ' + name
    # The digits come out tabular: their cmap entries point at the tnum glyphs.
    swapped = 0
    for table in font['cmap'].tables:
        for ch in digits:
            g = table.cmap.get(ord(ch))
            if g in tnum:
                table.cmap[ord(ch)] = tnum[g]
                swapped += 1
    assert swapped, 'no digit swapped in ' + name
    opts = subset.Options()
    opts.layout_features = []
    opts.name_IDs = [1, 2, 3, 4, 6]
    opts.notdef_outline = True
    opts.glyph_names = False
    sub = subset.Subsetter(opts)
    sub.populate(unicodes=[ord(c) for c in chars])
    sub.subset(font)
    path = os.path.join(ROOT, 'digits', f'{name}-{weight}.ttf')
    os.makedirs(os.path.dirname(path), exist_ok=True)
    font.save(path)
    print('wrote', os.path.normpath(path), os.path.getsize(path))


def main():
    # Shabnam: the cuts the app uses (Light is the default weight).
    out = os.path.join(ROOT, 'shabnam')
    os.makedirs(out, exist_ok=True)
    for cut in ('Light', 'Medium', 'Bold'):
        path = os.path.join(out, f'Shabnam-{cut}.ttf')
        with open(path, 'wb') as f:
            f.write(get(SHABNAM + f'dist/Shabnam-{cut}.ttf'))
        print('wrote', os.path.normpath(path))
    with open(os.path.join(out, 'LICENSE.txt'), 'wb') as f:
        f.write(get(SHABNAM + 'LICENSE'))

    manrope = get(MANROPE + 'Manrope%5Bwght%5D.ttf')
    vazir = get(VAZIR + 'fonts/variable/Vazirmatn%5Bwght%5D.ttf')
    for w in DIGIT_WEIGHTS:
        digit_cut(manrope, w, LATIN_DIGITS + SEPARATORS + SPACES, LATIN_DIGITS,
                  'ManropeNum')
        digit_cut(vazir, w, PERSIAN_DIGITS + PERSIAN_SEPARATORS + SEPARATORS + SPACES,
                  PERSIAN_DIGITS, 'VazirNum')
    with open(os.path.join(ROOT, 'digits', 'Vazirmatn-OFL.txt'), 'wb') as f:
        f.write(get(VAZIR + 'OFL.txt'))


if __name__ == '__main__':
    main()
