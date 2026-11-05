# OpenFinances: licenses

Copyright (C) 2026 Hosein Sadeqi

OpenFinances is free software: you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the Free
Software Foundation, either version 3 of the License, or (at your option)
any later version. See [LICENSE](LICENSE).

It is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
details.

## Not covered by the GPL

These files are third-party work the app uses under their own licenses.
The GPL does not apply to them, and they may not be taken out and reused
except as their own licenses allow:

- `assets/icons/`, `assets/nav/`: icons from Flaticon (flaticon.com). The
  source repository doesn't include them: [ICONS.md](ICONS.md) lists each
  one with its artist. Their artists are credited in the app
  (Settings > About > Icons).
- The icon outlines drawn in `lib/app/home_nav_icon.dart` and
  `lib/app/nav_icons.dart`: also from Flaticon, credited in ICONS.md.
- `assets/fonts/uicons/`: UIcons by Flaticon, under the license in that
  folder. The source repository doesn't include the font files:
  `tool/gen_uicons.py` downloads them.
- `assets/fonts/shabnam/`, `assets/fonts/manrope/`, `assets/fonts/digits/`:
  Shabnam, Manrope and Vazirmatn (and the digit fonts made from them),
  under the SIL Open Font License 1.1 (Shabnam's Latin from Roboto, Apache
  License 2.0), with their license files beside them.

## The name and logos

The GPL doesn't cover the OpenFinances name and logo (`lib/app/brand_mark.dart`,
`assets/icon/`, the launcher icons under `android/`) or the OpenProject and
OpenDesign marks (`lib/app/family_marks.dart`). They identify this project, and
aren't offered for reuse: a fork uses its own name and logo. They are built on
Flaticon icons, credited in ICONS.md.
