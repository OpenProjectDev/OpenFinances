"""Builds the Play Store images from raw 1440x3120 screenshots: a 2160x3840 image
per screen with one caption, and a 1024x500 feature graphic, per language. The
screens are exported at 2160x3840, Play's largest, so each keeps its pixels 1:1.

    python tool/make_store_images.py [--raw build/store_real] [--out store]

Composed in headless Chrome, so Persian shapes correctly and right-to-left works.
Google's limits are checked on what comes out. Edit captions here; a caption's
<em> is its accent color. No ranking, award, price or call to action: Play
doesn't allow them.
"""

import argparse
import html
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
CHROME = [
    r'C:\Program Files\Google\Chrome\Application\chrome.exe',
    '/usr/bin/google-chrome',
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
]

# Output name, raw screen, caption per language.
SLIDES = [
    ('01-overview', '01-history',
     'Your money <em>at a glance</em>', 'دخل و خرج شما <em>در یک نگاه</em>'),
    ('02-privacy', 'first',
     '<em>No account</em>, no internet permission', '<em>بدون حساب کاربری</em> و بدون دسترسی به اینترنت'),
    ('03-categories', '03-ring',
     'See where your <em>money goes</em>', 'ببینید پولتان <em>کجا می‌رود</em>'),
    ('04-add', '04-add',
     'Add an expense <em>in seconds</em>', 'ثبت هزینه <em>در چند ثانیه</em>'),
    ('05-daily', '05-daily',
     'Spot your <em>expensive days</em>', '<em>روزهای پرخرج</em> را ببینید'),
    ('06-budget', '06-budget',
     "See what's <em>left to spend</em>", 'ببینید از بودجه <em>چقدر مانده</em>'),
    ('07-due', '07-due',
     'Never <em>miss a payment</em>', 'هیچ پرداختی <em>از یادتان نرود</em>'),
    ('08-debts', '08-debts',
     'Keep track of <em>who owes what</em>', 'بدهی و طلب، <em>همه یک‌جا</em>'),
]
TAGLINE = {'en': 'Personal finance that stays on your phone',
           'fa': 'مدیریت مالی شخصی که روی گوشی خودتان می‌ماند'}

STYLE = """
@font-face { font-family: Cap; src: url('%(manrope)s'); }
@font-face { font-family: CapFa; src: url('%(shabnam)s'); }
* { margin: 0; padding: 0; box-sizing: border-box; }
html, body { width: %(w)dpx; height: %(h)dpx; overflow: hidden; background: #0C1B2E; }
body { position: relative; color: #fff; font-family: Cap, CapFa;
  background: radial-gradient(1100px 760px at 50%% -6%%, #1B4F86 0%%, rgba(27,79,134,0) 72%%),
              linear-gradient(172deg, #123050 0%%, #0C1B2E 58%%, #0A1523 100%%); }
em { font-style: normal; color: #5CB8FF; }
"""


def page(path, width, height, body, lang):
    fonts = {
        'manrope': (ROOT / 'assets/fonts/manrope/Manrope-700.ttf').as_uri(),
        'shabnam': (ROOT / 'assets/fonts/shabnam/Shabnam-Bold.ttf').as_uri(),
        'w': width, 'h': height,
    }
    direction = 'rtl' if lang == 'fa' else 'ltr'
    path.write_text(
        f'<!doctype html><html lang="{lang}" dir="{direction}"><meta charset="utf-8">'
        f'<style>{STYLE % fonts}</style><body>{body}</body></html>',
        encoding='utf-8',
    )


def render(chrome, source, target, width, height, scale, profile):
    subprocess.run(
        [chrome, '--headless=new', '--disable-gpu', '--hide-scrollbars',
         f'--force-device-scale-factor={scale}', '--allow-file-access-from-files',
         f'--user-data-dir={profile}', f'--window-size={width},{height}',
         f'--screenshot={target}', '--virtual-time-budget=4000', source.as_uri()],
        check=True, capture_output=True, timeout=120,
    )
    # 24-bit, no alpha, as Play asks.
    Image.open(target).convert('RGB').save(target, optimize=True)


STATUS_BAR = 120  # source rows cut off the top of every screen


def slide(raw, name, caption, lang):
    """The whole screen but the status bar, under a centered caption. Laid out
    at half size and exported at twice that, so a screen's pixels stay 1:1."""
    shot = (raw / lang / f'{name}.png').as_uri()
    width, height = 720, (3120 - STATUS_BAR) // 2
    return f"""
<div style="position:absolute;top:64px;left:70px;right:70px;height:236px;display:flex;align-items:center;
  justify-content:center;text-align:center;font-size:72px;line-height:1.26;font-weight:700">
  <div style="text-wrap:balance">{caption}</div></div>
<div style="position:absolute;top:326px;left:{(1080 - width) // 2}px;width:{width}px;height:{height}px;overflow:hidden;
  border-radius:44px;box-shadow:0 26px 80px rgba(0,0,0,.55)">
  <img src="{shot}" style="position:absolute;left:0;top:{-STATUS_BAR // 2}px;width:{width}px"></div>
"""


def feature(raw, lang):
    """The name and a line beside the logo, as one group in the middle."""
    icon = (ROOT / 'assets/icon/icon.png').as_uri()
    fa = lang == 'fa'
    align = 'right' if fa else 'left'
    size = 30 if fa else 31
    return f"""
<div style="position:absolute;inset:0;display:flex;flex-direction:row;align-items:center;justify-content:center;gap:64px;padding:0 60px">
  <div style="width:520px;text-align:{align}">
    <div dir="ltr" style="font-family:Cap;font-size:66px;font-weight:700;letter-spacing:-.5px">Open<em>Finances</em></div>
    <div style="margin-top:22px;font-size:{size}px;line-height:1.4;color:#D6E4F3;text-wrap:balance">{html.escape(TAGLINE[lang])}</div>
  </div>
  <img src="{icon}" style="width:280px;height:280px;filter:drop-shadow(0 18px 40px rgba(0,0,0,.45))">
</div>
"""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--raw', default=str(ROOT / 'build' / 'store_real'))
    ap.add_argument('--out', default=str(ROOT / 'store'))
    a = ap.parse_args()
    raw, out = pathlib.Path(a.raw).resolve(), pathlib.Path(a.out).resolve()
    chrome = next((c for c in CHROME if os.path.exists(c)), None) or shutil.which('chrome')
    if not chrome:
        sys.exit('Chrome not found')
    problems = []
    with tempfile.TemporaryDirectory() as tmp:
        tmp = pathlib.Path(tmp)
        for i, lang in enumerate(('en', 'fa')):
            folder = out / lang
            folder.mkdir(parents=True, exist_ok=True)
            jobs = [(n, 1080, 1920, 2, slide(raw, s, (en, fa)[i], lang))
                    for n, s, en, fa in SLIDES]
            jobs.append(('feature-graphic', 1024, 500, 1, feature(raw, lang)))
            for name, width, height, scale, body in jobs:
                source = tmp / f'{lang}-{name}.html'
                page(source, width, height, body, lang)
                target = folder / f'{name}.png'
                render(chrome, source, target, width, height, scale, tmp / 'profile')
                im = Image.open(target)
                long, short = max(im.size), min(im.size)
                if (im.size != (width * scale, height * scale) or im.mode != 'RGB' or long > 3840
                        or target.stat().st_size > 8 << 20 or (name != 'feature-graphic' and long > 2 * short)):
                    problems.append(f'{target}: {im.size} {im.mode}')
            print(lang, len(jobs), 'images,', sum(f.stat().st_size for f in folder.glob('*.png')) // 1024, 'KB')
    if problems:
        sys.exit('\n'.join(problems))


if __name__ == '__main__':
    main()
