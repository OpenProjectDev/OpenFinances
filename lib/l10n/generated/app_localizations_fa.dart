// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Persian (`fa`).
class AppLocalizationsFa extends AppLocalizations {
  AppLocalizationsFa([String locale = 'fa']) : super(locale);

  @override
  String get expensesTitle => 'هزینه‌ها';

  @override
  String get addExpenseTitle => 'افزودن هزینه';

  @override
  String get editExpenseTitle => 'ویرایش هزینه';

  @override
  String get titleLabel => 'عنوان';

  @override
  String get titleHint => 'مثلاً: ناهار';

  @override
  String get amountLabel => 'مبلغ';

  @override
  String get amountHintNumbersOnly => 'هزینه';

  @override
  String get futureDateWarning => 'این تاریخ در آینده است';

  @override
  String get pastDateWarning => 'این تاریخ گذشته است';

  @override
  String get dateOrderDefault => 'پیش‌فرض';

  @override
  String get dateOrderDmy => 'روز/ماه/سال';

  @override
  String get dateOrderMdy => 'ماه/روز/سال';

  @override
  String get dateOrderYmd => 'سال/ماه/روز';

  @override
  String get pickDate => 'انتخاب تاریخ';

  @override
  String get noteLabel => 'یادداشت';

  @override
  String get optionalFieldHint => 'این بخش اختیاری است';

  @override
  String get saveChanges => 'ذخیره تغییرات';

  @override
  String get delete => 'حذف';

  @override
  String get edit => 'ویرایش';

  @override
  String get deleteExpenseTitle => 'حذف هزینه';

  @override
  String get deleteExpenseConfirm => 'آیا از حذف این هزینه مطمئن هستید؟';

  @override
  String get close => 'بستن';

  @override
  String get selectRange => 'انتخاب بازه';

  @override
  String get prevPeriod => 'دوره قبل';

  @override
  String get nextPeriod => 'دوره بعد';

  @override
  String get totalExpenses => 'مجموع هزینه‌ها';

  @override
  String get noExpensesThisRange => 'برای این بازه هزینه‌ای ثبت نشده';

  @override
  String get today => 'امروز';

  @override
  String get manageCategories => 'مدیریت';

  @override
  String get currencyToman => 'تومان';

  @override
  String get currencyRial => 'ریال';

  @override
  String get save => 'ذخیره';

  @override
  String get cancel => 'انصراف';

  @override
  String get settings => 'تنظیمات';

  @override
  String get language => 'زبان';

  @override
  String get persian => 'فارسی';

  @override
  String get english => 'انگلیسی';

  @override
  String get appearance => 'ظاهر';

  @override
  String get themeMode => 'حالت نمایش';

  @override
  String get system => 'سیستم';

  @override
  String get light => 'روشن';

  @override
  String get dark => 'تیره';

  @override
  String get themeColors => 'رنگ‌های تم';

  @override
  String get tapToPickColor => 'برای انتخاب رنگ بزنید';

  @override
  String get data => 'داده‌ها';

  @override
  String get backup => 'پشتیبان';

  @override
  String get restore => 'بازیابی';

  @override
  String backupSavedIn(String folder) {
    return 'پشتیبان در $folder ذخیره شد';
  }

  @override
  String get backupFolderReset => 'ذخیره در دانلود';

  @override
  String get backupNameReset => 'نام پیش‌فرض';

  @override
  String get share => 'اشتراک';

  @override
  String get backupSubject => 'پشتیبان OpenFinances';

  @override
  String backupError(String error) {
    return 'خطا در پشتیبان‌گیری: $error';
  }

  @override
  String get pickBackupFile => 'انتخاب فایل پشتیبان';

  @override
  String get invalidFile => 'فایل نامعتبر';

  @override
  String get invalidBackupFormat => 'فرمت پشتیبان نامعتبر است';

  @override
  String get restoreDone => 'بازیابی شد';

  @override
  String get restoreChoiceMessage =>
      'برنامه از قبل داده دارد. با داده‌های فعلی چه کنیم؟';

  @override
  String get restoreDeleteCurrent => 'حذف داده فعلی';

  @override
  String get restoreBackUpThenDelete => 'پشتیبان و حذف';

  @override
  String get restoreMerge => 'ادغام داده‌ها';

  @override
  String restoreSkipped(String count) {
    return 'بازیابی شد؛ $count ردیف خوانا نبود و کنار گذاشته شد';
  }

  @override
  String restoreSkippedOne(String count) {
    return 'بازیابی شد؛ $count ردیف خوانا نبود و کنار گذاشته شد';
  }

  @override
  String restoreError(String error) {
    return 'خطا در بازیابی: $error';
  }

  @override
  String get dateAndRanges => 'تاریخ و بازه‌ها';

  @override
  String get monthStartDay => 'روز شروع ماه';

  @override
  String get decrease => 'کاهش';

  @override
  String get increase => 'افزایش';

  @override
  String get accountAndSecurity => 'حساب و امنیت';

  @override
  String get biometricLock => 'قفل بیومتریک';

  @override
  String get deviceNoBiometry => 'این دستگاه از احراز هویت پشتیبانی نمی‌کند';

  @override
  String get biometricEnableReason =>
      'برای فعال‌سازی قفل برنامه، احراز هویت کنید';

  @override
  String get biometricDisableReason =>
      'برای غیرفعال‌سازی قفل برنامه، احراز هویت کنید';

  @override
  String get authFailed => 'احراز هویت ناموفق بود';

  @override
  String get biomNotAvailable => 'سنسور در دسترس نیست';

  @override
  String get biomNotEnrolled => 'هیچ اثر انگشتی/چهره‌ای ثبت نشده است';

  @override
  String get passcodeNotSet => 'قفل صفحه (PIN/Pattern) تنظیم نشده است';

  @override
  String get lockedOut => 'تلاش‌های ناموفق زیاد؛ بعداً دوباره امتحان کنید';

  @override
  String get permanentlyLockedOut => 'قفل دائمی؛ از PIN/Pattern استفاده کنید';

  @override
  String get authUnavailable => 'احراز هویت در دسترس نیست';

  @override
  String get currencyUnit => 'واحد پول';

  @override
  String get currency => 'ارز';

  @override
  String get statistics => 'آمار';

  @override
  String get totalThisPeriod => 'مجموع این بازه';

  @override
  String get statsAtAGlance => 'در یک نگاه';

  @override
  String get statsVsLastMonth => 'نسبت به ماه قبل';

  @override
  String get statsVsAverage => 'نسبت به میانگین ماهانه';

  @override
  String get statsMoreThanLastMonth => 'بیشتر از ماه قبل';

  @override
  String get statsLessThanLastMonth => 'کمتر از ماه قبل';

  @override
  String get statsSameAsLastMonth => 'هم‌اندازه با ماه قبل';

  @override
  String get statsMoreThanAverage => 'بیشتر از میانگین ماهانه';

  @override
  String get statsLessThanAverage => 'کمتر از میانگین ماهانه';

  @override
  String get statsSameAsAverage => 'هم‌اندازه با میانگین ماهانه';

  @override
  String get statsNotEnoughData => 'داده کافی نیست';

  @override
  String get statsDailyAverage => 'میانگین روزانه';

  @override
  String get sameDayAverage => 'میانگین همین روز';

  @override
  String get spendingPace => 'روند هزینه';

  @override
  String get chartKeepOne => 'یکی از این‌ها باید روشن بماند';

  @override
  String get dailySpending => 'هزینه روزانه';

  @override
  String get thisPeriodLine => 'این بازه';

  @override
  String get lastPeriodLine => 'بازه قبل';

  @override
  String get statsByCategory => 'سهم دسته‌ها';

  @override
  String get noData => 'بدون داده';

  @override
  String get tapToSee => 'برای مشاهده\nبزنید';

  @override
  String get heatmapCalendar => 'تقویم حرارتی';

  @override
  String get dayPreviewHint => 'روزی را انتخاب کنید تا هزینه‌هایش را ببینید';

  @override
  String get dayTotal => 'مجموع روز';

  @override
  String get toSep => 'تا';

  @override
  String get costFor => 'هزینه';

  @override
  String get overviewAllPeriods => 'نمای کلی همه بازه‌ها';

  @override
  String get noDataToShow => 'داده‌ای برای نمایش وجود ندارد';

  @override
  String amountsShownInCurrency(String currency) {
    return 'مبالغ به $currency نمایش داده می‌شود';
  }

  @override
  String get currencyUSD => '\$';

  @override
  String get currencyEUR => '€';

  @override
  String get expenses => 'هزینه‌ها';

  @override
  String get support => 'حمایت';

  @override
  String get categories => 'دسته‌بندی‌ها';

  @override
  String get newCategory => 'دسته‌بندی جدید';

  @override
  String get noCategoriesYet => 'هنوز دسته‌ای ساخته نشده';

  @override
  String get deleteCategory => 'حذف دسته‌بندی';

  @override
  String get lastCategoryCantDelete => 'دست‌کم یک دسته‌بندی باید بماند';

  @override
  String get enterCategoryName => 'نام دسته‌بندی را وارد کنید';

  @override
  String get categoryNameLabel => 'نام دسته‌بندی';

  @override
  String get pickIcon => 'انتخاب آیکن';

  @override
  String get pickColor => 'انتخاب رنگ';

  @override
  String get pickIconTitle => 'انتخاب آیکن';

  @override
  String get searchIcons => 'جستجو (نام انگلیسی آیکن یا نام گروه)';

  @override
  String get iconGroupShopping => 'خرید';

  @override
  String get iconGroupMoney => 'پول و بانک';

  @override
  String get iconGroupFood => 'خوراکی';

  @override
  String get iconGroupTransport => 'حمل‌ونقل';

  @override
  String get iconGroupHome => 'خانه';

  @override
  String get iconGroupBills => 'قبض‌ها';

  @override
  String get iconGroupTech => 'دیجیتال';

  @override
  String get iconGroupHealth => 'سلامت';

  @override
  String get iconGroupPersonal => 'شخصی';

  @override
  String get iconGroupWork => 'کار و آموزش';

  @override
  String get iconGroupLeisure => 'تفریح و سفر';

  @override
  String get iconGroupOther => 'سایر';

  @override
  String get editCategory => 'ویرایش دسته‌بندی';

  @override
  String get colorPickerTitle => 'انتخاب رنگ';

  @override
  String get colorPickerTabMain => 'اصلی';

  @override
  String get colorPickerTabCustom => 'دلخواه';

  @override
  String get select => 'انتخاب';

  @override
  String get hexLabelExample => 'HEX (مثلاً #1ABC9C)';

  @override
  String get invalidHexCode => 'کد HEX نامعتبر است';

  @override
  String get calendarSystem => 'تقویم';

  @override
  String get calendarJalali => 'شمسی';

  @override
  String get calendarGregorian => 'میلادی';

  @override
  String get income => 'درآمد';

  @override
  String get incomeTitle => 'درآمد';

  @override
  String get addIncomeTitle => 'افزودن درآمد';

  @override
  String get editIncomeTitle => 'ویرایش درآمد';

  @override
  String get incomeTitleHint => 'مثلاً: حقوق';

  @override
  String get amountHintIncomeOnly => 'درآمد';

  @override
  String get totalIncome => 'مجموع درآمد';

  @override
  String get seeLastEntry => 'رفتن به آخرین ثبت';

  @override
  String get noIncomeThisRange => 'برای این بازه درآمدی ثبت نشده';

  @override
  String get deleteIncomeTitle => 'حذف درآمد';

  @override
  String get deleteIncomeConfirm => 'آیا از حذف این مورد درآمد مطمئن هستید؟';

  @override
  String get incomeCategories => 'دسته‌بندی‌های درآمد';

  @override
  String get upcomingTitle => 'پرداخت‌های پیش‌رو';

  @override
  String get upcomingTotal => 'پیش‌رو';

  @override
  String get addUpcomingTitle => 'افزودن پرداخت پیش‌رو';

  @override
  String get editUpcomingTitle => 'ویرایش پرداخت پیش‌رو';

  @override
  String get rescheduleUpcomingTitle => 'زمان‌بندی پرداخت بعدی';

  @override
  String get upcomingEmpty => 'پرداختی در پیش نیست';

  @override
  String get upcomingDueSection => 'پرداخت‌نشده';

  @override
  String get upcomingPaidSection => 'پرداخت‌شده';

  @override
  String get upcomingNothingPaid => 'هنوز چیزی پرداخت نشده';

  @override
  String get upcomingTitleHint => 'مثلاً قبض اینترنت';

  @override
  String get dueDateLabel => 'سررسید';

  @override
  String dueOn(String date) {
    return 'سررسید $date';
  }

  @override
  String get markPaid => 'پرداخت شد';

  @override
  String upcomingPaidOn(String date) {
    return 'پرداخت $date';
  }

  @override
  String get payAndReschedule => 'پرداخت و تمدید';

  @override
  String get dueToday => 'امروز';

  @override
  String get dueTomorrow => 'فردا';

  @override
  String dueInDays(String days) {
    return '$days روز مانده';
  }

  @override
  String dueInOneDay(String days) {
    return '$days روز مانده';
  }

  @override
  String overdueDays(String days) {
    return '$days روز گذشته';
  }

  @override
  String overdueOneDay(String days) {
    return '$days روز گذشته';
  }

  @override
  String get deleteUpcomingTitle => 'حذف پرداخت پیش‌رو';

  @override
  String get deleteUpcomingConfirm =>
      'این مورد از پرداخت‌های پیش‌رو حذف شود؟ هزینه‌ای ثبت نمی‌شود';

  @override
  String get removeFromHistory => 'حذف از تاریخچه';

  @override
  String get addUpcomingButton => 'افزودن پرداخت';

  @override
  String get expenseShort => 'هزینه';

  @override
  String get spentShort => 'هزینه';

  @override
  String get historyTab => 'تاریخچه';

  @override
  String get incomingTab => 'پیش‌رو';

  @override
  String get allShort => 'همه';

  @override
  String get noMatch => 'موردی پیدا نشد';

  @override
  String get budget => 'بودجه';

  @override
  String get editBudget => 'ویرایش بودجه';

  @override
  String get addBudget => 'افزودن بودجه';

  @override
  String get categoryBudget => 'بودجه دسته';

  @override
  String get sortCustom => 'سفارشی';

  @override
  String get assignBudgetFirst => 'ابتدا بودجه تعیین کنید';

  @override
  String get fullData => 'داده کامل';

  @override
  String get expensesOnly => 'فقط هزینه‌ها';

  @override
  String get dateLabel => 'تاریخ';

  @override
  String get calendarJump => 'رفتن به یک روز';

  @override
  String get calendarFull => 'کل دوره';

  @override
  String get calendarWeek => 'یک هفته';

  @override
  String todayWithDate(String date) {
    return 'امروز $date';
  }

  @override
  String get categorySpendPerPeriod => 'هزینه‌های دسته در هر بازه';

  @override
  String get calculator => 'ماشین حساب';

  @override
  String get done => 'تأیید';

  @override
  String get failedToSaveSettings => 'خطا در ذخیره تنظیمات';

  @override
  String get unlockReason => 'برای باز کردن برنامه احراز هویت کنید';

  @override
  String get bankBlu => 'بلو';

  @override
  String get bankPasargad => 'پاسارگاد';

  @override
  String get generalCategory => 'عمومی';

  @override
  String get debtsTab => 'بدهی';

  @override
  String get smsTab => 'پیامک';

  @override
  String get debtIOwe => 'بدهی من';

  @override
  String get debtOwedToMe => 'طلب من';

  @override
  String get debtsEmpty => 'بدهی یا طلبی ثبت نشده';

  @override
  String get addDebtButton => 'افزودن بدهی یا طلب';

  @override
  String get debtPersonHint => 'نام شخص';

  @override
  String get debtStartLabel => 'شروع';

  @override
  String get debtSettled => 'تسویه شد';

  @override
  String get deleteDebtTitle => 'حذف بدهی';

  @override
  String get deleteDebtConfirm =>
      'این مورد و پرداخت‌هایش حذف شوند؟ هزینه‌ها و درآمدهایی که ثبت شده‌اند می‌مانند';

  @override
  String debtLedgerTitleOwe(String person) {
    return 'بازپرداخت به $person';
  }

  @override
  String debtLedgerTitleOwed(String person) {
    return 'دریافت از $person';
  }

  @override
  String get smsTabExplain =>
      'برای فهرست شدن پیامک‌های بانکی در اینجا، اجازه خواندن اعلان‌ها را بدهید. فقط پیامک‌های بانکی نگه داشته می‌شوند و چیزی از گوشی خارج نمی‌شود';

  @override
  String get smsTabEmpty =>
      'پیامک‌های بانکی از این به بعد، با رسیدن، اینجا می‌آیند';

  @override
  String get smsAdded => 'ثبت شد';

  @override
  String get smsOpen => 'باز کردن';

  @override
  String get smsNewSection => 'تازه';

  @override
  String get smsSeenSection => 'دیده‌شده';

  @override
  String get smsNothingNew => 'پیام تازه‌ای نیست';

  @override
  String get smsNothingSeen => 'هنوز پیامی دیده نشده';

  @override
  String get smsMarkSeen => 'دیده شد';

  @override
  String get smsMarkUnseen => 'دیده نشده';

  @override
  String get allowNotificationAccess => 'اجازه خواندن اعلان‌ها';

  @override
  String get readBankNotifications => 'خواندن اعلان‌ها';

  @override
  String get bankMessageFallback => 'پیامک بانکی';

  @override
  String get addAction => 'ثبت';

  @override
  String get notifyBankMessages => 'نمایش اعلان‌ها';

  @override
  String get ignoredTitles => 'نادیده‌ها';

  @override
  String get ignoredTitlesEmpty =>
      'عنوانی نادیده گرفته نشده. برای نادیده گرفتن، روی پیشنهاد عنوان انگشت نگه دارید';

  @override
  String titleIgnored(String title) {
    return '«$title» دیگر پیشنهاد نمی‌شود';
  }

  @override
  String get undo => 'بازگردانی';

  @override
  String get suggestTitlesFromCategory => 'پیشنهاد عنوان‌ها';

  @override
  String get peopleTab => 'اشخاص';

  @override
  String get debtShort => 'بدهی';

  @override
  String get creditShort => 'طلب';

  @override
  String get titlesTab => 'عناوین';

  @override
  String get payOnly => 'پرداخت';

  @override
  String get payAndRecord => 'پرداخت و ثبت';

  @override
  String get recordPaid => 'ثبت';

  @override
  String get receiveOnly => 'دریافت';

  @override
  String get receiveAndRecord => 'دریافت و ثبت';

  @override
  String get debtRecordPaid => 'ثبت';

  @override
  String nextDue(String when) {
    return 'سررسید بعدی: $when';
  }

  @override
  String overdueCount(String count) {
    return '$count مورد عقب‌افتاده';
  }

  @override
  String get nothingDue => 'سررسیدی نمانده';

  @override
  String get notifReadMissing =>
      'این قابلیت بدون اجازه خواندن اعلان‌ها کار نمی‌کند';

  @override
  String get needsPermission => 'بدون اجازه نمی‌شود این را روشن کرد';

  @override
  String get noTitlesToIgnore => 'عنوانی برای نادیده گرفتن نیست';

  @override
  String get noPeopleToIgnore => 'شخصی برای نادیده گرفتن نیست';

  @override
  String get sortBudget => 'بودجه';

  @override
  String get sortSpent => 'هزینه';

  @override
  String get sortRemaining => 'مانده';

  @override
  String get sortAscending => 'صعودی';

  @override
  String get sortDescending => 'نزولی';

  @override
  String get budgetsSection => 'به تفکیک دسته';

  @override
  String get noBudgetGroup => 'بدون بودجه';

  @override
  String get formatUnknown => 'قالب ناشناخته';

  @override
  String get defineFormat => 'تعریف قالب';

  @override
  String get ignoreFormat => 'نادیده گرفتن قالب';

  @override
  String get ignoreSender => 'نادیده گرفتن فرستنده';

  @override
  String get pickAmountHint => 'عدد مبلغ را در پیامک انتخاب کنید';

  @override
  String get saveFormat => 'ثبت قالب';

  @override
  String senderIgnored(String sender) {
    return 'پیامک‌های «$sender» دیگر خوانده نمی‌شوند';
  }

  @override
  String get sectionPersonalization => 'شخصی‌سازی';

  @override
  String get sectionTabsAccess => 'تب‌ها و دسترسی';

  @override
  String get sectionData => 'داده‌ها';

  @override
  String get historyAlwaysOn => 'تاریخچه همیشه روشن است';

  @override
  String get smsFormats => 'قالب‌های پیامک';

  @override
  String get formatsEmpty => 'هنوز قالبی تعریف نشده';

  @override
  String get formatBySign => 'از روی علامت';

  @override
  String get formatNoExample => 'بدون نمونه';

  @override
  String get deleteFormatTitle => 'حذف قالب';

  @override
  String get deleteFormatConfirm =>
      'پیامک‌های این قالب دوباره ناشناخته می‌شوند';

  @override
  String get stopIgnoring => 'بازگرداندن';

  @override
  String get smsNoneHere => 'پیامکی اینجا نیست';

  @override
  String get ignoredOne => 'نادیده';

  @override
  String get smsFirst => 'اول تب پیامک را روشن کنید';

  @override
  String get appMotto => 'مشکلی که شناسایی نشود هرگز حل نمی‌شود';

  @override
  String get notifyOffWarning =>
      'برای بهترین استفاده از این قابلیت، اعلان‌ها را روشن کنید';

  @override
  String get sectionHistory => 'تاریخچه';

  @override
  String get keepFolds => 'حفظ بازوبسته';

  @override
  String get keepPlace => 'حفظ جایگاه';

  @override
  String get keepEntries => 'حفظ ورودی‌ها';

  @override
  String get couldNotOpen => 'باز نشد';

  @override
  String get showSuggestions => 'نمایش پیشنهادها';

  @override
  String get backAgainToExit => 'برای خروج دوباره بازگشت را بزنید';

  @override
  String get formatName => 'نام قالب';

  @override
  String get showTips => 'آموزش';

  @override
  String get neverWarn => 'هشدار نده';

  @override
  String get tipWelcome =>
      'به OpenFinances خوش آمدید! این صفحه اصلی شماست. در تنظیمات می‌توانید زبانه‌های بیشتری اضافه کنید یا آموزش را خاموش کنید';

  @override
  String get tipPeriod =>
      'داده‌ها برای هر ماه نمایش داده می‌شوند. برای تغییر ماه، این کادر یا فلش‌های کنارش را بزنید';

  @override
  String get tipCards => 'یک کارت را بزنید تا فقط همان نوع نشان داده شود';

  @override
  String get tipAdd =>
      'با این دکمه یک مورد اضافه کنید. آنچه اضافه می‌کنید به صفحه‌ای که در آن هستید بستگی دارد';

  @override
  String get tipTiles => 'یک ردیف را بزنید یا بکشید تا با آن کار کنید';

  @override
  String get tipChips => 'یک دسته را بزنید تا فقط ردیف‌های همان را ببینید';

  @override
  String get tipBudget =>
      'برای دسته‌هایتان بودجه بگذارید تا حسابشان را داشته باشید';

  @override
  String get tipSections =>
      'عنوان بخش را بزنید تا جمع شود، دوباره بزنید تا باز شود';

  @override
  String get setupMore => 'گزینه‌های بیشتر';

  @override
  String get setupContinue => 'ادامه';

  @override
  String privacyRead(String policy) {
    return '$policy را خوانده‌ام';
  }

  @override
  String get privacyPolicy => 'حریم خصوصی';

  @override
  String get privacyTitle => 'حریم خصوصی';

  @override
  String get privacyOfflineTitle => 'چیزی از گوشی شما بیرون نمی‌رود';

  @override
  String get privacyOffline =>
      'OpenFinances حساب کاربری، سرور، تبلیغات و آمارگیری ندارد. حتی اجازه دسترسی به اینترنت ندارد؛ پس اندروید نمی‌گذارد آنلاین شود';

  @override
  String get privacyDataTitle => 'داده‌های شما';

  @override
  String get privacyData =>
      'خرج‌ها، درآمدها، بودجه‌ها، بدهی‌ها و تنظیمات شما فقط در حافظه برنامه روی همین گوشی می‌مانند. با حذف برنامه پاک می‌شوند';

  @override
  String get privacyBackupsTitle => 'پشتیبان';

  @override
  String get privacyBackups =>
      'پشتیبان فقط وقتی ساخته می‌شود که خودتان بخواهید: فایلی که هر جا بخواهید ذخیره می‌شود. اینکه از آنجا به کجا برود با خودتان است';

  @override
  String get privacyBankTitle => 'پیامک‌های بانکی و دسترسی به اعلان‌ها';

  @override
  String get privacyBank =>
      'تا خودتان روشنش نکنید خاموش است. با روشن کردنش، اندروید از شما اجازه دسترسی به اعلان‌ها را می‌خواهد تا برنامه اعلان‌هایی را که برنامه پیامک برای پیامک‌های تازه نشان می‌دهد بخواند و ثبت تراکنش‌های بانکی را پیشنهاد کند. فقط پیامک‌هایی نگه داشته می‌شوند که تراکنش بانکی شناخته شوند؛ بقیه اعلان‌ها نادیده گرفته می‌شوند. هیچ چیز به جایی فرستاده نمی‌شود';

  @override
  String get privacyUpdatesTitle => 'بررسی به‌روزرسانی';

  @override
  String get privacyUpdates =>
      'فقط وقتی در بخش درباره «بررسی به‌روزرسانی» را بزنید، گوگل پلی (نه این برنامه) نسخه تازه‌تر را پیدا می‌کند؛ گوگل نسخه برنامه و مشخصات دستگاه را دریافت می‌کند';

  @override
  String get privacyLockTitle => 'قفل اثر انگشت';

  @override
  String get privacyLock =>
      'اثر انگشت را خود اندروید بررسی می‌کند؛ برنامه هرگز آن را نمی‌بیند';

  @override
  String get privacyOk => 'متوجه شدم';

  @override
  String get payHint => 'بازپرداخت';

  @override
  String get payRemainingLabel => 'باقی‌مانده';

  @override
  String get repayments => 'بازپرداخت‌ها';

  @override
  String debtBelowPaid(String amount) {
    return 'تا الان $amount بازپرداخت شده؛ بدهی نمی‌تواند کمتر از آن باشد. برای کمتر کردنش اول بازپرداخت‌ها را حذف کنید';
  }

  @override
  String debtStartAfterRepayment(String date) {
    return 'یک بازپرداخت در $date ثبت شده؛ شروع بدهی نمی‌تواند بعد از آن باشد';
  }

  @override
  String get debtSideLocked =>
      'این بدهی بازپرداخت دارد؛ طرفش را نمی‌شود عوض کرد';

  @override
  String get deleteRepaymentTitle => 'حذف بازپرداخت';

  @override
  String get deleteRepaymentConfirm =>
      'این بازپرداخت و ثبتی که در تاریخچه گذاشته حذف می‌شوند';

  @override
  String get repaymentDeleted => 'بازپرداخت حذف شد';

  @override
  String get debtsOngoingSection => 'در جریان';

  @override
  String get debtsPaidSection => 'تسویه‌شده';

  @override
  String get debtsNothingOngoing => 'چیزی در جریان نیست';

  @override
  String get debtsNothingPaid => 'هنوز چیزی تسویه نشده';

  @override
  String get repaymentLabel => 'بازپرداخت';

  @override
  String get deleteCategoryMoveTo =>
      'این دسته‌بندی حذف می‌شود و ثبت‌هایش به دسته‌بندی‌ای که پایین انتخاب کنید منتقل می‌شوند';

  @override
  String get quickZeros => 'دکمه 000';

  @override
  String get haptics => 'لرزش';

  @override
  String get debtPaidLabel => 'پرداخت‌شده';

  @override
  String debtDueBy(String date) {
    return 'تا $date';
  }
}
