// lib/features/settings/change_log.dart
// What each released version changed, newest first, for Settings > About >
// Version (English, as the rest of About). Add a version's entry when building
// its release, with the words of its Play notes.

typedef ChangeLogEntry = ({String version, String date, List<String> changes});

const List<ChangeLogEntry> kChangeLog = [
  (
    version: '1.0.17+21',
    date: '2026-11-11',
    changes: [
      'Text sits right in the middle of buttons, chips and tabs, Persian '
          'most of all',
      'Typing in a long form with the keyboard up no longer makes it jump',
    ],
  ),
  (
    version: '1.0.16+20',
    date: '2026-11-10',
    changes: [
      'Settings: Android backup is a checkbox, Allow Android to back up my '
          'data, with an info button that explains it',
      'The 000 button is on by default for toman and rial, off for dollars '
          'and euros',
    ],
  ),
  (
    version: '1.0.15+19',
    date: '2026-11-08',
    changes: [
      'Android backup to your Google account is now off unless you turn on '
          'Encrypted Android backup in Settings, under Data',
      'The privacy text explains Android backup and the Play rating prompt',
      'New website address',
    ],
  ),
  (
    version: '1.0.14+18',
    date: '2026-11-06',
    changes: [
      'Fingerprint lock: leaving the app while it asks, then coming back, '
          'asks again by itself',
      'Picking a suggested title moves on to the amount',
      'Debts: the due date button reads better in Persian',
    ],
  ),
  (
    version: '1.0.13+17',
    date: '2026-11-05',
    changes: ['A smaller download, with everything working as before'],
  ),
  (
    version: '1.0.12+16',
    date: '2026-11-04',
    changes: [
      'Settings: choose the order dates are written in',
      'Date picker: a clearer warning for dates on the unexpected side, past '
          'or future, that you can turn off; true square day boxes',
      'Add sheets are shorter: the note opens from a small chip by the amount, '
          'and a debt\'s two dates share a row',
      'Date fields: reset to today or erase right from the field',
      'New, lighter tips that point at where to tap',
      'Budget: a plus on categories with no budget yet',
      'Backups remember the folder you picked',
    ],
  ),
  (
    version: '1.0.11+15',
    date: '2026-11-03',
    changes: [
      'Fixed a freeze in the Daily spending chart over days with nothing '
          'spent, and its lag when moving back to them',
      'Statistics: the daily and pace charts start from your first entry',
      'Clearer chart numbers: 1.5k and 2k, no longer 2k twice',
      'Debts: the amount in a simple chip',
      'Settings: Persian font and digit options show only in Persian',
      'About: new icons, and an even licenses page',
      'The app stays vertical',
    ],
  ),
  (
    version: '1.0.10+14',
    date: '2026-11-02',
    changes: [
      'A new date picker: year, month and Today chips, and a warning for '
          'future dates where none is expected',
      'Statistics: the daily chart in solid colors, what is behind shown as '
          'a fine dotted line; Spending pace as thin lines fitted to your data',
      'Budget: simpler, the leeway removed; percentages turn red when over '
          'budget',
      'Debts: the due date on the row, start and due dates on the sheet, '
          'repayments in their own section',
      'History: tap a category chip to filter by it; the home icon also '
          'folds and closes the calendar',
      'Upcoming: paid-only categories stay in the row, greyed',
      'About: check for updates, what is new in each version, report a bug; '
          'all in English',
      'Smoother scrolling, and Statistics and Budget keep your place when '
          'the period changes',
    ],
  ),
  (
    version: '1.0.9+13',
    date: '2026-11-01',
    changes: [
      'Statistics: a new Daily spending chart and a Spending pace chart '
          'against last period; tap their chips to show or hide each line',
      'Budget: a leeway on top of your budgets',
      'Debts: due date and days left right on the row; repayments in their '
          'own section',
      'Upcoming: the amount has its own row',
      'Vibration on key actions (Settings)',
      'Smoother scrolling; Statistics and Budget keep your place when the '
          'period changes',
    ],
  ),
  (
    version: '1.0.8+12',
    date: '2026-10-31',
    changes: [
      'History: a calendar from the today chip; tap a day to jump to it, and '
          'the calendar follows as you scroll',
      'Statistics: tap a heatmap day to see its expenses and total; tap one '
          'to open it in History',
      'Upcoming: Unpaid and Paid sections, cleaner rows; tap the days chip '
          'for days left or late',
      'Smoother scrolling and faster pages, especially after adding or '
          'paying something',
      'Lists that scroll show it with a short nudge',
    ],
  ),
  (
    version: '1.0.7+11',
    date: '2026-10-30',
    changes: [
      'A new first page: languages, more options, the privacy policy, and '
          'restoring a backup right there',
      'No internet permission at all; the privacy policy is in Settings',
      'Statistics: At a glance, a new ring by category, and bar charts that '
          'scroll on whole bars',
      'Debts: Ongoing and Paid sections, a repayments log with undo, and due '
          'dates with days left',
      'Budget: rounded bar segments and clearer category rows',
      'The calculator: a 000 key, and a long expression wraps',
      'New fonts, and texts are never cut or shrunk',
    ],
  ),
];
