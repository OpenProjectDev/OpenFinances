// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get expensesTitle => 'Expenses';

  @override
  String get addExpenseTitle => 'Add expense';

  @override
  String get editExpenseTitle => 'Edit expense';

  @override
  String get titleLabel => 'Title';

  @override
  String get titleHint => 'e.g., Lunch';

  @override
  String get amountLabel => 'Amount';

  @override
  String get amountHintNumbersOnly => 'Expense';

  @override
  String get futureDateWarning => 'This date is in the future';

  @override
  String get pastDateWarning => 'This date is in the past';

  @override
  String get dateOrderDefault => 'Default';

  @override
  String get dateOrderDmy => 'D/M/Y';

  @override
  String get dateOrderMdy => 'M/D/Y';

  @override
  String get dateOrderYmd => 'Y/M/D';

  @override
  String get pickDate => 'Pick a date';

  @override
  String get noteLabel => 'Note';

  @override
  String get optionalFieldHint => 'This field is optional';

  @override
  String get saveChanges => 'Save changes';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get deleteExpenseTitle => 'Delete expense';

  @override
  String get deleteExpenseConfirm =>
      'Are you sure you want to delete this expense?';

  @override
  String get close => 'Close';

  @override
  String get selectRange => 'Select period';

  @override
  String get prevPeriod => 'Previous period';

  @override
  String get nextPeriod => 'Next period';

  @override
  String get totalExpenses => 'Total expenses';

  @override
  String get noExpensesThisRange => 'No expenses recorded for this range';

  @override
  String get today => 'Today';

  @override
  String get manageCategories => 'Manage';

  @override
  String get currencyToman => 'Toman';

  @override
  String get currencyRial => 'Rial';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get persian => 'Persian';

  @override
  String get english => 'English';

  @override
  String get appearance => 'Appearance';

  @override
  String get themeMode => 'Theme mode';

  @override
  String get system => 'System';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get themeColors => 'Theme colors';

  @override
  String get tapToPickColor => 'Tap to pick a color';

  @override
  String get data => 'Data';

  @override
  String get backup => 'Backup';

  @override
  String get restore => 'Restore';

  @override
  String backupSavedIn(String folder) {
    return 'Backup saved in $folder';
  }

  @override
  String get backupFolderReset => 'Save to Download';

  @override
  String get backupNameReset => 'Default name';

  @override
  String get share => 'Share';

  @override
  String get backupSubject => 'OpenFinances backup';

  @override
  String backupError(String error) {
    return 'Backup failed: $error';
  }

  @override
  String get pickBackupFile => 'Pick backup file';

  @override
  String get invalidFile => 'Invalid file';

  @override
  String get invalidBackupFormat => 'Invalid backup format';

  @override
  String get restoreDone => 'Restored';

  @override
  String get restoreChoiceMessage =>
      'The app already has data. What should happen to it?';

  @override
  String get restoreDeleteCurrent => 'Delete current';

  @override
  String get restoreBackUpThenDelete => 'Back up, then delete';

  @override
  String get restoreMerge => 'Merge data';

  @override
  String restoreSkipped(String count) {
    return 'Restored; $count unreadable rows were left out';
  }

  @override
  String restoreSkippedOne(String count) {
    return 'Restored; $count unreadable row was left out';
  }

  @override
  String restoreError(String error) {
    return 'Restore failed: $error';
  }

  @override
  String get dateAndRanges => 'Date & ranges';

  @override
  String get monthStartDay => 'Month start day';

  @override
  String get decrease => 'Decrease';

  @override
  String get increase => 'Increase';

  @override
  String get accountAndSecurity => 'Account & security';

  @override
  String get biometricLock => 'Biometric lock';

  @override
  String get deviceNoBiometry => 'This device doesn\'t support biometrics';

  @override
  String get biometricEnableReason => 'Authenticate to enable the app lock';

  @override
  String get biometricDisableReason => 'Authenticate to disable the app lock';

  @override
  String get authFailed => 'Authentication failed';

  @override
  String get biomNotAvailable => 'Sensor not available';

  @override
  String get biomNotEnrolled => 'No fingerprint/face enrolled';

  @override
  String get passcodeNotSet => 'Device lock (PIN/Pattern) not set';

  @override
  String get lockedOut => 'Too many failed attempts; try again later';

  @override
  String get permanentlyLockedOut => 'Permanently locked; use PIN/Pattern';

  @override
  String get authUnavailable => 'Authentication unavailable';

  @override
  String get currencyUnit => 'Currency';

  @override
  String get currency => 'Currency';

  @override
  String get statistics => 'Statistics';

  @override
  String get totalThisPeriod => 'Total this period';

  @override
  String get statsAtAGlance => 'At a glance';

  @override
  String get statsVsLastMonth => 'Compared to last month';

  @override
  String get statsVsAverage => 'Against monthly average';

  @override
  String get statsMoreThanLastMonth => 'more than last month';

  @override
  String get statsLessThanLastMonth => 'less than last month';

  @override
  String get statsSameAsLastMonth => 'same as last month';

  @override
  String get statsMoreThanAverage => 'more than the monthly average';

  @override
  String get statsLessThanAverage => 'less than the monthly average';

  @override
  String get statsSameAsAverage => 'same as the monthly average';

  @override
  String get statsNotEnoughData => 'Not enough data';

  @override
  String get statsDailyAverage => 'Daily average';

  @override
  String get sameDayAverage => 'Same-day average';

  @override
  String get spendingPace => 'Spending pace';

  @override
  String get chartKeepOne => 'One of these has to stay on';

  @override
  String get dailySpending => 'Daily spending';

  @override
  String get thisPeriodLine => 'This period';

  @override
  String get lastPeriodLine => 'Last period';

  @override
  String get statsByCategory => 'By category';

  @override
  String get noData => 'No data';

  @override
  String get tapToSee => 'Tap to view';

  @override
  String get heatmapCalendar => 'Heatmap calendar';

  @override
  String get dayPreviewHint => 'Pick a day to see its expenses';

  @override
  String get dayTotal => 'Day\'s total';

  @override
  String get toSep => 'to';

  @override
  String get costFor => 'Cost for';

  @override
  String get overviewAllPeriods => 'Overview of all periods';

  @override
  String get noDataToShow => 'No data to show';

  @override
  String amountsShownInCurrency(String currency) {
    return 'Amounts are shown in $currency';
  }

  @override
  String get currencyUSD => '\$';

  @override
  String get currencyEUR => '€';

  @override
  String get expenses => 'Expenses';

  @override
  String get support => 'Support';

  @override
  String get categories => 'Categories';

  @override
  String get newCategory => 'New category';

  @override
  String get noCategoriesYet => 'No categories yet';

  @override
  String get deleteCategory => 'Delete category';

  @override
  String get lastCategoryCantDelete => 'At least one category has to stay';

  @override
  String get enterCategoryName => 'Enter category name';

  @override
  String get categoryNameLabel => 'Category name';

  @override
  String get pickIcon => 'Pick icon';

  @override
  String get pickColor => 'Pick color';

  @override
  String get pickIconTitle => 'Pick an icon';

  @override
  String get searchIcons => 'Search icons or groups';

  @override
  String get iconGroupShopping => 'Shopping';

  @override
  String get iconGroupMoney => 'Money';

  @override
  String get iconGroupFood => 'Food';

  @override
  String get iconGroupTransport => 'Transport';

  @override
  String get iconGroupHome => 'Home';

  @override
  String get iconGroupBills => 'Bills';

  @override
  String get iconGroupTech => 'Tech';

  @override
  String get iconGroupHealth => 'Health';

  @override
  String get iconGroupPersonal => 'Personal';

  @override
  String get iconGroupWork => 'Work & study';

  @override
  String get iconGroupLeisure => 'Leisure & travel';

  @override
  String get iconGroupOther => 'Other';

  @override
  String get editCategory => 'Edit category';

  @override
  String get colorPickerTitle => 'Color picker';

  @override
  String get colorPickerTabMain => 'Main';

  @override
  String get colorPickerTabCustom => 'Custom';

  @override
  String get select => 'Select';

  @override
  String get hexLabelExample => 'HEX (e.g. #1ABC9C)';

  @override
  String get invalidHexCode => 'Invalid HEX code';

  @override
  String get calendarSystem => 'Calendar';

  @override
  String get calendarJalali => 'Shamsi';

  @override
  String get calendarGregorian => 'Gregorian';

  @override
  String get income => 'Income';

  @override
  String get incomeTitle => 'Income';

  @override
  String get addIncomeTitle => 'Add income';

  @override
  String get editIncomeTitle => 'Edit income';

  @override
  String get incomeTitleHint => 'e.g., Salary';

  @override
  String get amountHintIncomeOnly => 'Income';

  @override
  String get totalIncome => 'Total income';

  @override
  String get seeLastEntry => 'See last entry';

  @override
  String get noIncomeThisRange => 'No income recorded for this range';

  @override
  String get deleteIncomeTitle => 'Delete income';

  @override
  String get deleteIncomeConfirm =>
      'Are you sure you want to delete this income entry?';

  @override
  String get incomeCategories => 'Income categories';

  @override
  String get upcomingTitle => 'Upcoming payments';

  @override
  String get upcomingTotal => 'Upcoming';

  @override
  String get addUpcomingTitle => 'Add upcoming payment';

  @override
  String get editUpcomingTitle => 'Edit upcoming payment';

  @override
  String get rescheduleUpcomingTitle => 'Schedule the next one';

  @override
  String get upcomingEmpty => 'No upcoming payments';

  @override
  String get upcomingDueSection => 'Unpaid';

  @override
  String get upcomingPaidSection => 'Paid';

  @override
  String get upcomingNothingPaid => 'Nothing paid yet';

  @override
  String get upcomingTitleHint => 'e.g., Internet bill';

  @override
  String get dueDateLabel => 'Due date';

  @override
  String get dueDatePick => 'Due date';

  @override
  String dueOn(String date) {
    return 'Due $date';
  }

  @override
  String get markPaid => 'Paid';

  @override
  String upcomingPaidOn(String date) {
    return 'Paid $date';
  }

  @override
  String get payAndReschedule => 'Pay & reschedule';

  @override
  String get dueToday => 'Due today';

  @override
  String get dueTomorrow => 'Tomorrow';

  @override
  String dueInDays(String days) {
    return '$days days left';
  }

  @override
  String dueInOneDay(String days) {
    return '$days day left';
  }

  @override
  String overdueDays(String days) {
    return '$days days late';
  }

  @override
  String overdueOneDay(String days) {
    return '$days day late';
  }

  @override
  String get deleteUpcomingTitle => 'Delete upcoming payment';

  @override
  String get deleteUpcomingConfirm =>
      'Remove this from your upcoming payments? No expense will be recorded';

  @override
  String get removeFromHistory => 'Remove from history';

  @override
  String get addUpcomingButton => 'Add payment';

  @override
  String get expenseShort => 'Expense';

  @override
  String get spentShort => 'Spent';

  @override
  String get historyTab => 'History';

  @override
  String get incomingTab => 'Due';

  @override
  String get allShort => 'All';

  @override
  String get noMatch => 'No match';

  @override
  String get budget => 'Budget';

  @override
  String get editBudget => 'Edit budget';

  @override
  String get addBudget => 'Add budget';

  @override
  String get categoryBudget => 'Category budget';

  @override
  String get sortCustom => 'Custom';

  @override
  String get assignBudgetFirst => 'Set a budget first';

  @override
  String get fullData => 'Full data';

  @override
  String get expensesOnly => 'Expenses only';

  @override
  String get dateLabel => 'Date';

  @override
  String get calendarJump => 'Go to a day';

  @override
  String get calendarFull => 'Whole period';

  @override
  String get calendarWeek => 'One week';

  @override
  String todayWithDate(String date) {
    return 'Today $date';
  }

  @override
  String get categorySpendPerPeriod => 'Category spending per period';

  @override
  String get calculator => 'Calculator';

  @override
  String get done => 'Done';

  @override
  String get failedToSaveSettings => 'Failed to save settings';

  @override
  String get unlockReason => 'Authenticate to open the app';

  @override
  String get bankBlu => 'Blu';

  @override
  String get bankPasargad => 'Pasargad';

  @override
  String get generalCategory => 'General';

  @override
  String get debtsTab => 'Debt';

  @override
  String get smsTab => 'SMS';

  @override
  String get debtIOwe => 'I owe';

  @override
  String get debtOwedToMe => 'Owed to me';

  @override
  String get debtsEmpty => 'No debts';

  @override
  String get addDebtButton => 'Add a debt';

  @override
  String get debtPersonHint => 'Person\'s name';

  @override
  String get debtStartLabel => 'Started';

  @override
  String get debtSettled => 'Settled';

  @override
  String get deleteDebtTitle => 'Delete debt';

  @override
  String get deleteDebtConfirm =>
      'Delete this and its payments? Entries already added to History stay';

  @override
  String debtLedgerTitleOwe(String person) {
    return 'Paid back $person';
  }

  @override
  String debtLedgerTitleOwed(String person) {
    return 'Received from $person';
  }

  @override
  String get smsTabExplain =>
      'To list bank messages here, allow notification access. Only bank messages are kept, and nothing leaves the phone';

  @override
  String get smsTabEmpty => 'Bank messages will show up here as they arrive';

  @override
  String get smsAdded => 'Added';

  @override
  String get smsOpen => 'Open';

  @override
  String get smsNewSection => 'New';

  @override
  String get smsSeenSection => 'Seen';

  @override
  String get smsNothingNew => 'Nothing new';

  @override
  String get smsNothingSeen => 'Nothing seen yet';

  @override
  String get smsMarkSeen => 'Seen';

  @override
  String get smsMarkUnseen => 'Not seen';

  @override
  String get allowNotificationAccess => 'Allow notification access';

  @override
  String get readBankNotifications => 'Read alerts';

  @override
  String get bankMessageFallback => 'Bank message';

  @override
  String get addAction => 'Add';

  @override
  String get notifyBankMessages => 'Show alerts';

  @override
  String get ignoredTitles => 'Ignored';

  @override
  String get ignoredTitlesEmpty =>
      'No ignored titles. Long-press a title suggestion to ignore it';

  @override
  String titleIgnored(String title) {
    return '\"$title\" won\'t be suggested';
  }

  @override
  String get undo => 'Undo';

  @override
  String get suggestTitlesFromCategory => 'Suggest titles';

  @override
  String get peopleTab => 'People';

  @override
  String get debtShort => 'Debt';

  @override
  String get creditShort => 'Owed';

  @override
  String get titlesTab => 'Titles';

  @override
  String get payOnly => 'Pay';

  @override
  String get payAndRecord => 'Pay & add';

  @override
  String get recordPaid => 'Record';

  @override
  String get receiveOnly => 'Receive';

  @override
  String get receiveAndRecord => 'Receive & add';

  @override
  String get debtRecordPaid => 'Save';

  @override
  String nextDue(String when) {
    return 'Next due: $when';
  }

  @override
  String overdueCount(String count) {
    return '$count overdue';
  }

  @override
  String get nothingDue => 'Nothing due';

  @override
  String get notifReadMissing =>
      'This feature can\'t work without permission to read notifications';

  @override
  String get needsPermission => 'Can\'t turn this on without permission';

  @override
  String get noTitlesToIgnore => 'No titles to ignore';

  @override
  String get noPeopleToIgnore => 'No people to ignore';

  @override
  String get sortBudget => 'Budget';

  @override
  String get sortSpent => 'Spent';

  @override
  String get sortRemaining => 'Left';

  @override
  String get sortAscending => 'Asc';

  @override
  String get sortDescending => 'Desc';

  @override
  String get budgetsSection => 'Per category';

  @override
  String get noBudgetGroup => 'No budget';

  @override
  String get formatUnknown => 'Unknown format';

  @override
  String get defineFormat => 'Define format';

  @override
  String get ignoreFormat => 'Ignore format';

  @override
  String get ignoreSender => 'Ignore sender';

  @override
  String get pickAmountHint => 'Tap the amount in the message';

  @override
  String get saveFormat => 'Save format';

  @override
  String senderIgnored(String sender) {
    return 'Messages from \"$sender\" won\'t be read';
  }

  @override
  String get sectionPersonalization => 'Personalization';

  @override
  String get sectionTabsAccess => 'Tabs & access';

  @override
  String get sectionData => 'Data';

  @override
  String get historyAlwaysOn => 'History is always on';

  @override
  String get smsFormats => 'SMS formats';

  @override
  String get formatsEmpty => 'No formats defined yet';

  @override
  String get formatBySign => 'By sign';

  @override
  String get formatNoExample => 'No example';

  @override
  String get deleteFormatTitle => 'Delete format';

  @override
  String get deleteFormatConfirm =>
      'Messages in this format become unknown again';

  @override
  String get stopIgnoring => 'Stop ignoring';

  @override
  String get smsNoneHere => 'No messages here';

  @override
  String get ignoredOne => 'Ignored';

  @override
  String get smsFirst => 'Turn on the SMS tab first';

  @override
  String get appMotto => 'An unidentified problem can never be solved';

  @override
  String get notifyOffWarning =>
      'For the best use of this feature, turn on notifications';

  @override
  String get sectionHistory => 'History';

  @override
  String get keepFolds => 'Keep folds';

  @override
  String get keepPlace => 'Keep place';

  @override
  String get keepEntries => 'Keep drafts';

  @override
  String get couldNotOpen => 'Couldn\'t open it';

  @override
  String get showSuggestions => 'Show suggestions';

  @override
  String get backAgainToExit => 'Press back again to exit';

  @override
  String get formatName => 'Format name';

  @override
  String get showTips => 'Tips';

  @override
  String get neverWarn => 'Never warn';

  @override
  String get tipWelcome =>
      'Welcome to OpenFinances! This is your main page. You can add more tabs or turn off the tips in Settings';

  @override
  String get tipPeriod =>
      'Data is shown for each month. Tap this tile or its arrows to change the month';

  @override
  String get tipCards => 'Tap a card to filter by that type';

  @override
  String get tipAdd =>
      'Tap this button to add an entry. What you add changes based on what page you\'re on';

  @override
  String get tipTiles => 'Tap or swipe a tile to act on it';

  @override
  String get tipChips => 'Tap a category chip to see only its entries';

  @override
  String get tipBudget =>
      'Add budgets to your categories to keep track of them';

  @override
  String get tipSections =>
      'Tap a section header to collapse it, tap again to expand';

  @override
  String get setupMore => 'More options';

  @override
  String get setupContinue => 'Continue';

  @override
  String privacyRead(String policy) {
    return 'I\'ve read the $policy';
  }

  @override
  String get privacyPolicy => 'privacy policy';

  @override
  String get privacyTitle => 'Privacy';

  @override
  String get privacyOfflineTitle => 'Nothing leaves your phone';

  @override
  String get privacyOffline =>
      'OpenFinances has no account, no servers, no ads and no analytics. It doesn\'t even have permission to use the internet, so Android won\'t let it go online';

  @override
  String get privacyDataTitle => 'Your data';

  @override
  String get privacyData =>
      'Your expenses, income, budgets, debts and settings stay only in the app\'s storage on this phone, unless you turn on Android backup. Uninstalling the app deletes them';

  @override
  String get privacyBackupsTitle => 'Backups';

  @override
  String get privacyBackups =>
      'A backup is made only when you ask for one: a file saved where you choose. Where it goes from there is up to you. Android\'s own backup to your Google account is off unless you tick Allow Android to back up my data in Settings, under Data. Ticked, Android copies the app\'s data only when it encrypts it with your screen lock, so Google can\'t read it. Unticked, Android\'s own phone-to-phone transfer leaves the data out too, though some phone makers\' transfer tools may still copy it';

  @override
  String get privacyBankTitle => 'Bank messages and notification access';

  @override
  String get privacyBank =>
      'Off unless you turn it on. Then Android asks you to allow notification access, so the app can read the notifications your messaging app shows for new texts and suggest entries for bank transactions. Only messages recognized as bank transactions are kept; every other notification is ignored. Nothing is sent anywhere';

  @override
  String get privacyUpdatesTitle => 'Update check';

  @override
  String get privacyUpdates =>
      'Only when you tap Check for updates in About, Google Play (not this app) looks for a newer version; Google receives the app\'s version and device details';

  @override
  String get privacyLockTitle => 'Fingerprint lock';

  @override
  String get privacyLock =>
      'Your fingerprint is checked by Android itself; the app never sees it';

  @override
  String get privacyRatingTitle => 'Rating the app';

  @override
  String get privacyRating =>
      'Now and then, after you save entries, Google Play may ask you to rate the app. The app only counts saves on this phone. A rating goes to Google Play, never to the app';

  @override
  String get androidBackup => 'Allow Android to back up my data';

  @override
  String get androidBackupAbout => 'About Android backup';

  @override
  String get androidBackupInfo =>
      'Your data remains encrypted with your screen lock, so Google can\'t read it. Set up a new Android phone with the same Google account and your old screen lock, and your data can be restored there';

  @override
  String get privacyOk => 'Got it';

  @override
  String get payHint => 'Repayment';

  @override
  String get payRemainingLabel => 'Remaining';

  @override
  String get repayments => 'Repayments';

  @override
  String debtBelowPaid(String amount) {
    return '$amount has been repaid already: the debt can\'t be less. To lower it, remove repayments first';
  }

  @override
  String debtStartAfterRepayment(String date) {
    return 'A repayment is dated $date: the debt can\'t start after it';
  }

  @override
  String get debtSideLocked =>
      'This debt has repayments: its side can\'t change';

  @override
  String get deleteRepaymentTitle => 'Delete repayment';

  @override
  String get deleteRepaymentConfirm =>
      'This repayment and the entry it added to History will be deleted';

  @override
  String get repaymentDeleted => 'Repayment deleted';

  @override
  String get debtsOngoingSection => 'Ongoing';

  @override
  String get debtsPaidSection => 'Paid';

  @override
  String get debtsNothingOngoing => 'Nothing ongoing';

  @override
  String get debtsNothingPaid => 'Nothing paid yet';

  @override
  String get repaymentLabel => 'Repayment';

  @override
  String get deleteCategoryMoveTo =>
      'This category will be deleted, and its entries will move to the category you choose below';

  @override
  String get quickZeros => '000 button';

  @override
  String get haptics => 'Vibration';

  @override
  String get debtPaidLabel => 'Paid';

  @override
  String debtDueBy(String date) {
    return 'By $date';
  }
}
