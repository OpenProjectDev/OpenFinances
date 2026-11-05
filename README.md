# OpenFinances

A personal finance app for Android that stays on your phone. It has no internet permission, no account and no server, so it can't send your data anywhere.

- Expenses and income, budgets, statistics
- Upcoming payments and debts
- Reads bank messages from notifications, only if you allow it
- Your data moves between phones as JSON or Excel backups that you keep
- Persian and English, with Jalali and Gregorian calendars

## We're looking for testers

OpenFinances is in closed testing on Google Play, and it needs testers before it can launch. If you have an Android phone and a Google account, you can help:

1. Sign in to Google, then join the testers group: [groups.google.com/g/openfinances](https://groups.google.com/g/openfinances)
2. Opt in to the test, using the same Google account: [play.google.com/apps/testing/com.openproject.openfinances](https://play.google.com/apps/testing/com.openproject.openfinances)
3. [Install OpenFinances from Google Play](https://play.google.com/store/apps/details?id=com.openproject.openfinances), and stay opted in.

Using the app normally is all it takes. Bugs and ideas are welcome in [Issues](https://github.com/OpenProjectDev/OpenFinances/issues).

## Building it

You need Flutter, Python and `fonttools` (`pip install fonttools`).

```
flutter pub get
python tool/gen_uicons.py
flutter build apk --debug
```

`tool/gen_uicons.py` downloads the UIcons font from Flaticon's npm package. This repository doesn't include the icon files, because their license doesn't allow offering them for download. [ICONS.md](ICONS.md) lists each one with its artist, so you can get them yourself. The app builds without them, with blanks where they would be.

## License

GPLv3 or later, except for the third-party files listed in [NOTICE.md](NOTICE.md).
