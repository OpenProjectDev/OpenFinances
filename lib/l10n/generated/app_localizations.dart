import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fa.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fa'),
  ];

  /// No description provided for @expensesTitle.
  ///
  /// In fa, this message translates to:
  /// **'هزینه‌ها'**
  String get expensesTitle;

  /// No description provided for @addExpenseTitle.
  ///
  /// In fa, this message translates to:
  /// **'افزودن هزینه'**
  String get addExpenseTitle;

  /// No description provided for @editExpenseTitle.
  ///
  /// In fa, this message translates to:
  /// **'ویرایش هزینه'**
  String get editExpenseTitle;

  /// No description provided for @titleLabel.
  ///
  /// In fa, this message translates to:
  /// **'عنوان'**
  String get titleLabel;

  /// No description provided for @titleHint.
  ///
  /// In fa, this message translates to:
  /// **'مثلاً: ناهار'**
  String get titleHint;

  /// No description provided for @amountLabel.
  ///
  /// In fa, this message translates to:
  /// **'مبلغ'**
  String get amountLabel;

  /// No description provided for @amountHintNumbersOnly.
  ///
  /// In fa, this message translates to:
  /// **'هزینه'**
  String get amountHintNumbersOnly;

  /// No description provided for @futureDateWarning.
  ///
  /// In fa, this message translates to:
  /// **'این تاریخ در آینده است'**
  String get futureDateWarning;

  /// No description provided for @pastDateWarning.
  ///
  /// In fa, this message translates to:
  /// **'این تاریخ گذشته است'**
  String get pastDateWarning;

  /// No description provided for @dateOrderDefault.
  ///
  /// In fa, this message translates to:
  /// **'پیش‌فرض'**
  String get dateOrderDefault;

  /// No description provided for @dateOrderDmy.
  ///
  /// In fa, this message translates to:
  /// **'روز/ماه/سال'**
  String get dateOrderDmy;

  /// No description provided for @dateOrderMdy.
  ///
  /// In fa, this message translates to:
  /// **'ماه/روز/سال'**
  String get dateOrderMdy;

  /// No description provided for @dateOrderYmd.
  ///
  /// In fa, this message translates to:
  /// **'سال/ماه/روز'**
  String get dateOrderYmd;

  /// No description provided for @pickDate.
  ///
  /// In fa, this message translates to:
  /// **'انتخاب تاریخ'**
  String get pickDate;

  /// No description provided for @noteLabel.
  ///
  /// In fa, this message translates to:
  /// **'یادداشت'**
  String get noteLabel;

  /// No description provided for @optionalFieldHint.
  ///
  /// In fa, this message translates to:
  /// **'این بخش اختیاری است'**
  String get optionalFieldHint;

  /// No description provided for @saveChanges.
  ///
  /// In fa, this message translates to:
  /// **'ذخیره تغییرات'**
  String get saveChanges;

  /// No description provided for @delete.
  ///
  /// In fa, this message translates to:
  /// **'حذف'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In fa, this message translates to:
  /// **'ویرایش'**
  String get edit;

  /// No description provided for @deleteExpenseTitle.
  ///
  /// In fa, this message translates to:
  /// **'حذف هزینه'**
  String get deleteExpenseTitle;

  /// No description provided for @deleteExpenseConfirm.
  ///
  /// In fa, this message translates to:
  /// **'آیا از حذف این هزینه مطمئن هستید؟'**
  String get deleteExpenseConfirm;

  /// No description provided for @close.
  ///
  /// In fa, this message translates to:
  /// **'بستن'**
  String get close;

  /// No description provided for @selectRange.
  ///
  /// In fa, this message translates to:
  /// **'انتخاب بازه'**
  String get selectRange;

  /// No description provided for @prevPeriod.
  ///
  /// In fa, this message translates to:
  /// **'دوره قبل'**
  String get prevPeriod;

  /// No description provided for @nextPeriod.
  ///
  /// In fa, this message translates to:
  /// **'دوره بعد'**
  String get nextPeriod;

  /// No description provided for @totalExpenses.
  ///
  /// In fa, this message translates to:
  /// **'مجموع هزینه‌ها'**
  String get totalExpenses;

  /// No description provided for @noExpensesThisRange.
  ///
  /// In fa, this message translates to:
  /// **'برای این بازه هزینه‌ای ثبت نشده'**
  String get noExpensesThisRange;

  /// No description provided for @today.
  ///
  /// In fa, this message translates to:
  /// **'امروز'**
  String get today;

  /// No description provided for @manageCategories.
  ///
  /// In fa, this message translates to:
  /// **'مدیریت'**
  String get manageCategories;

  /// No description provided for @currencyToman.
  ///
  /// In fa, this message translates to:
  /// **'تومان'**
  String get currencyToman;

  /// No description provided for @currencyRial.
  ///
  /// In fa, this message translates to:
  /// **'ریال'**
  String get currencyRial;

  /// No description provided for @save.
  ///
  /// In fa, this message translates to:
  /// **'ذخیره'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In fa, this message translates to:
  /// **'انصراف'**
  String get cancel;

  /// No description provided for @settings.
  ///
  /// In fa, this message translates to:
  /// **'تنظیمات'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In fa, this message translates to:
  /// **'زبان'**
  String get language;

  /// No description provided for @persian.
  ///
  /// In fa, this message translates to:
  /// **'فارسی'**
  String get persian;

  /// No description provided for @english.
  ///
  /// In fa, this message translates to:
  /// **'انگلیسی'**
  String get english;

  /// No description provided for @appearance.
  ///
  /// In fa, this message translates to:
  /// **'ظاهر'**
  String get appearance;

  /// No description provided for @themeMode.
  ///
  /// In fa, this message translates to:
  /// **'حالت نمایش'**
  String get themeMode;

  /// No description provided for @system.
  ///
  /// In fa, this message translates to:
  /// **'سیستم'**
  String get system;

  /// No description provided for @light.
  ///
  /// In fa, this message translates to:
  /// **'روشن'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In fa, this message translates to:
  /// **'تیره'**
  String get dark;

  /// No description provided for @themeColors.
  ///
  /// In fa, this message translates to:
  /// **'رنگ‌های تم'**
  String get themeColors;

  /// No description provided for @tapToPickColor.
  ///
  /// In fa, this message translates to:
  /// **'برای انتخاب رنگ بزنید'**
  String get tapToPickColor;

  /// No description provided for @data.
  ///
  /// In fa, this message translates to:
  /// **'داده‌ها'**
  String get data;

  /// No description provided for @backup.
  ///
  /// In fa, this message translates to:
  /// **'پشتیبان'**
  String get backup;

  /// No description provided for @restore.
  ///
  /// In fa, this message translates to:
  /// **'بازیابی'**
  String get restore;

  /// No description provided for @backupSavedIn.
  ///
  /// In fa, this message translates to:
  /// **'پشتیبان در {folder} ذخیره شد'**
  String backupSavedIn(String folder);

  /// No description provided for @backupFolderReset.
  ///
  /// In fa, this message translates to:
  /// **'ذخیره در دانلود'**
  String get backupFolderReset;

  /// No description provided for @backupNameReset.
  ///
  /// In fa, this message translates to:
  /// **'نام پیش‌فرض'**
  String get backupNameReset;

  /// No description provided for @share.
  ///
  /// In fa, this message translates to:
  /// **'اشتراک'**
  String get share;

  /// No description provided for @backupSubject.
  ///
  /// In fa, this message translates to:
  /// **'پشتیبان OpenFinances'**
  String get backupSubject;

  /// No description provided for @backupError.
  ///
  /// In fa, this message translates to:
  /// **'خطا در پشتیبان‌گیری: {error}'**
  String backupError(String error);

  /// No description provided for @pickBackupFile.
  ///
  /// In fa, this message translates to:
  /// **'انتخاب فایل پشتیبان'**
  String get pickBackupFile;

  /// No description provided for @invalidFile.
  ///
  /// In fa, this message translates to:
  /// **'فایل نامعتبر'**
  String get invalidFile;

  /// No description provided for @invalidBackupFormat.
  ///
  /// In fa, this message translates to:
  /// **'فرمت پشتیبان نامعتبر است'**
  String get invalidBackupFormat;

  /// No description provided for @restoreDone.
  ///
  /// In fa, this message translates to:
  /// **'بازیابی شد'**
  String get restoreDone;

  /// No description provided for @restoreChoiceMessage.
  ///
  /// In fa, this message translates to:
  /// **'برنامه از قبل داده دارد. با داده‌های فعلی چه کنیم؟'**
  String get restoreChoiceMessage;

  /// No description provided for @restoreDeleteCurrent.
  ///
  /// In fa, this message translates to:
  /// **'حذف داده فعلی'**
  String get restoreDeleteCurrent;

  /// No description provided for @restoreBackUpThenDelete.
  ///
  /// In fa, this message translates to:
  /// **'پشتیبان و حذف'**
  String get restoreBackUpThenDelete;

  /// No description provided for @restoreMerge.
  ///
  /// In fa, this message translates to:
  /// **'ادغام داده‌ها'**
  String get restoreMerge;

  /// No description provided for @restoreSkipped.
  ///
  /// In fa, this message translates to:
  /// **'بازیابی شد؛ {count} ردیف خوانا نبود و کنار گذاشته شد'**
  String restoreSkipped(String count);

  /// No description provided for @restoreSkippedOne.
  ///
  /// In fa, this message translates to:
  /// **'بازیابی شد؛ {count} ردیف خوانا نبود و کنار گذاشته شد'**
  String restoreSkippedOne(String count);

  /// No description provided for @restoreError.
  ///
  /// In fa, this message translates to:
  /// **'خطا در بازیابی: {error}'**
  String restoreError(String error);

  /// No description provided for @dateAndRanges.
  ///
  /// In fa, this message translates to:
  /// **'تاریخ و بازه‌ها'**
  String get dateAndRanges;

  /// No description provided for @monthStartDay.
  ///
  /// In fa, this message translates to:
  /// **'روز شروع ماه'**
  String get monthStartDay;

  /// No description provided for @decrease.
  ///
  /// In fa, this message translates to:
  /// **'کاهش'**
  String get decrease;

  /// No description provided for @increase.
  ///
  /// In fa, this message translates to:
  /// **'افزایش'**
  String get increase;

  /// No description provided for @accountAndSecurity.
  ///
  /// In fa, this message translates to:
  /// **'حساب و امنیت'**
  String get accountAndSecurity;

  /// No description provided for @biometricLock.
  ///
  /// In fa, this message translates to:
  /// **'قفل بیومتریک'**
  String get biometricLock;

  /// No description provided for @deviceNoBiometry.
  ///
  /// In fa, this message translates to:
  /// **'این دستگاه از احراز هویت پشتیبانی نمی‌کند'**
  String get deviceNoBiometry;

  /// No description provided for @biometricEnableReason.
  ///
  /// In fa, this message translates to:
  /// **'برای فعال‌سازی قفل برنامه، احراز هویت کنید'**
  String get biometricEnableReason;

  /// No description provided for @biometricDisableReason.
  ///
  /// In fa, this message translates to:
  /// **'برای غیرفعال‌سازی قفل برنامه، احراز هویت کنید'**
  String get biometricDisableReason;

  /// No description provided for @authFailed.
  ///
  /// In fa, this message translates to:
  /// **'احراز هویت ناموفق بود'**
  String get authFailed;

  /// No description provided for @biomNotAvailable.
  ///
  /// In fa, this message translates to:
  /// **'سنسور در دسترس نیست'**
  String get biomNotAvailable;

  /// No description provided for @biomNotEnrolled.
  ///
  /// In fa, this message translates to:
  /// **'هیچ اثر انگشتی/چهره‌ای ثبت نشده است'**
  String get biomNotEnrolled;

  /// No description provided for @passcodeNotSet.
  ///
  /// In fa, this message translates to:
  /// **'قفل صفحه (PIN/Pattern) تنظیم نشده است'**
  String get passcodeNotSet;

  /// No description provided for @lockedOut.
  ///
  /// In fa, this message translates to:
  /// **'تلاش‌های ناموفق زیاد؛ بعداً دوباره امتحان کنید'**
  String get lockedOut;

  /// No description provided for @permanentlyLockedOut.
  ///
  /// In fa, this message translates to:
  /// **'قفل دائمی؛ از PIN/Pattern استفاده کنید'**
  String get permanentlyLockedOut;

  /// No description provided for @authUnavailable.
  ///
  /// In fa, this message translates to:
  /// **'احراز هویت در دسترس نیست'**
  String get authUnavailable;

  /// No description provided for @currencyUnit.
  ///
  /// In fa, this message translates to:
  /// **'واحد پول'**
  String get currencyUnit;

  /// No description provided for @currency.
  ///
  /// In fa, this message translates to:
  /// **'ارز'**
  String get currency;

  /// No description provided for @statistics.
  ///
  /// In fa, this message translates to:
  /// **'آمار'**
  String get statistics;

  /// No description provided for @totalThisPeriod.
  ///
  /// In fa, this message translates to:
  /// **'مجموع این بازه'**
  String get totalThisPeriod;

  /// No description provided for @statsAtAGlance.
  ///
  /// In fa, this message translates to:
  /// **'در یک نگاه'**
  String get statsAtAGlance;

  /// No description provided for @statsVsLastMonth.
  ///
  /// In fa, this message translates to:
  /// **'نسبت به ماه قبل'**
  String get statsVsLastMonth;

  /// No description provided for @statsVsAverage.
  ///
  /// In fa, this message translates to:
  /// **'نسبت به میانگین ماهانه'**
  String get statsVsAverage;

  /// No description provided for @statsMoreThanLastMonth.
  ///
  /// In fa, this message translates to:
  /// **'بیشتر از ماه قبل'**
  String get statsMoreThanLastMonth;

  /// No description provided for @statsLessThanLastMonth.
  ///
  /// In fa, this message translates to:
  /// **'کمتر از ماه قبل'**
  String get statsLessThanLastMonth;

  /// No description provided for @statsSameAsLastMonth.
  ///
  /// In fa, this message translates to:
  /// **'هم‌اندازه با ماه قبل'**
  String get statsSameAsLastMonth;

  /// No description provided for @statsMoreThanAverage.
  ///
  /// In fa, this message translates to:
  /// **'بیشتر از میانگین ماهانه'**
  String get statsMoreThanAverage;

  /// No description provided for @statsLessThanAverage.
  ///
  /// In fa, this message translates to:
  /// **'کمتر از میانگین ماهانه'**
  String get statsLessThanAverage;

  /// No description provided for @statsSameAsAverage.
  ///
  /// In fa, this message translates to:
  /// **'هم‌اندازه با میانگین ماهانه'**
  String get statsSameAsAverage;

  /// No description provided for @statsNotEnoughData.
  ///
  /// In fa, this message translates to:
  /// **'داده کافی نیست'**
  String get statsNotEnoughData;

  /// No description provided for @statsDailyAverage.
  ///
  /// In fa, this message translates to:
  /// **'میانگین روزانه'**
  String get statsDailyAverage;

  /// No description provided for @sameDayAverage.
  ///
  /// In fa, this message translates to:
  /// **'میانگین همین روز'**
  String get sameDayAverage;

  /// No description provided for @spendingPace.
  ///
  /// In fa, this message translates to:
  /// **'روند هزینه'**
  String get spendingPace;

  /// No description provided for @chartKeepOne.
  ///
  /// In fa, this message translates to:
  /// **'یکی از این‌ها باید روشن بماند'**
  String get chartKeepOne;

  /// No description provided for @dailySpending.
  ///
  /// In fa, this message translates to:
  /// **'هزینه روزانه'**
  String get dailySpending;

  /// No description provided for @thisPeriodLine.
  ///
  /// In fa, this message translates to:
  /// **'این بازه'**
  String get thisPeriodLine;

  /// No description provided for @lastPeriodLine.
  ///
  /// In fa, this message translates to:
  /// **'بازه قبل'**
  String get lastPeriodLine;

  /// No description provided for @statsByCategory.
  ///
  /// In fa, this message translates to:
  /// **'سهم دسته‌ها'**
  String get statsByCategory;

  /// No description provided for @noData.
  ///
  /// In fa, this message translates to:
  /// **'بدون داده'**
  String get noData;

  /// No description provided for @tapToSee.
  ///
  /// In fa, this message translates to:
  /// **'برای مشاهده\nبزنید'**
  String get tapToSee;

  /// No description provided for @heatmapCalendar.
  ///
  /// In fa, this message translates to:
  /// **'تقویم حرارتی'**
  String get heatmapCalendar;

  /// No description provided for @dayPreviewHint.
  ///
  /// In fa, this message translates to:
  /// **'روزی را انتخاب کنید تا هزینه‌هایش را ببینید'**
  String get dayPreviewHint;

  /// No description provided for @dayTotal.
  ///
  /// In fa, this message translates to:
  /// **'مجموع روز'**
  String get dayTotal;

  /// No description provided for @toSep.
  ///
  /// In fa, this message translates to:
  /// **'تا'**
  String get toSep;

  /// No description provided for @costFor.
  ///
  /// In fa, this message translates to:
  /// **'هزینه'**
  String get costFor;

  /// No description provided for @overviewAllPeriods.
  ///
  /// In fa, this message translates to:
  /// **'نمای کلی همه بازه‌ها'**
  String get overviewAllPeriods;

  /// No description provided for @noDataToShow.
  ///
  /// In fa, this message translates to:
  /// **'داده‌ای برای نمایش وجود ندارد'**
  String get noDataToShow;

  /// یادداشت پایین کارت که واحد نمایش مبالغ را می‌گوید.
  ///
  /// In fa, this message translates to:
  /// **'مبالغ به {currency} نمایش داده می‌شود'**
  String amountsShownInCurrency(String currency);

  /// No description provided for @currencyUSD.
  ///
  /// In fa, this message translates to:
  /// **'\$'**
  String get currencyUSD;

  /// No description provided for @currencyEUR.
  ///
  /// In fa, this message translates to:
  /// **'€'**
  String get currencyEUR;

  /// برچسب تب پایین برای فهرست هزینه‌ها
  ///
  /// In fa, this message translates to:
  /// **'هزینه‌ها'**
  String get expenses;

  /// برچسب تب پایین برای صفحه حمایت/کمک
  ///
  /// In fa, this message translates to:
  /// **'حمایت'**
  String get support;

  /// No description provided for @categories.
  ///
  /// In fa, this message translates to:
  /// **'دسته‌بندی‌ها'**
  String get categories;

  /// No description provided for @newCategory.
  ///
  /// In fa, this message translates to:
  /// **'دسته‌بندی جدید'**
  String get newCategory;

  /// No description provided for @noCategoriesYet.
  ///
  /// In fa, this message translates to:
  /// **'هنوز دسته‌ای ساخته نشده'**
  String get noCategoriesYet;

  /// No description provided for @deleteCategory.
  ///
  /// In fa, this message translates to:
  /// **'حذف دسته‌بندی'**
  String get deleteCategory;

  /// No description provided for @lastCategoryCantDelete.
  ///
  /// In fa, this message translates to:
  /// **'دست‌کم یک دسته‌بندی باید بماند'**
  String get lastCategoryCantDelete;

  /// No description provided for @enterCategoryName.
  ///
  /// In fa, this message translates to:
  /// **'نام دسته‌بندی را وارد کنید'**
  String get enterCategoryName;

  /// No description provided for @categoryNameLabel.
  ///
  /// In fa, this message translates to:
  /// **'نام دسته‌بندی'**
  String get categoryNameLabel;

  /// No description provided for @pickIcon.
  ///
  /// In fa, this message translates to:
  /// **'انتخاب آیکن'**
  String get pickIcon;

  /// No description provided for @pickColor.
  ///
  /// In fa, this message translates to:
  /// **'انتخاب رنگ'**
  String get pickColor;

  /// No description provided for @pickIconTitle.
  ///
  /// In fa, this message translates to:
  /// **'انتخاب آیکن'**
  String get pickIconTitle;

  /// No description provided for @searchIcons.
  ///
  /// In fa, this message translates to:
  /// **'جستجو (نام انگلیسی آیکن یا نام گروه)'**
  String get searchIcons;

  /// No description provided for @iconGroupShopping.
  ///
  /// In fa, this message translates to:
  /// **'خرید'**
  String get iconGroupShopping;

  /// No description provided for @iconGroupMoney.
  ///
  /// In fa, this message translates to:
  /// **'پول و بانک'**
  String get iconGroupMoney;

  /// No description provided for @iconGroupFood.
  ///
  /// In fa, this message translates to:
  /// **'خوراکی'**
  String get iconGroupFood;

  /// No description provided for @iconGroupTransport.
  ///
  /// In fa, this message translates to:
  /// **'حمل‌ونقل'**
  String get iconGroupTransport;

  /// No description provided for @iconGroupHome.
  ///
  /// In fa, this message translates to:
  /// **'خانه'**
  String get iconGroupHome;

  /// No description provided for @iconGroupBills.
  ///
  /// In fa, this message translates to:
  /// **'قبض‌ها'**
  String get iconGroupBills;

  /// No description provided for @iconGroupTech.
  ///
  /// In fa, this message translates to:
  /// **'دیجیتال'**
  String get iconGroupTech;

  /// No description provided for @iconGroupHealth.
  ///
  /// In fa, this message translates to:
  /// **'سلامت'**
  String get iconGroupHealth;

  /// No description provided for @iconGroupPersonal.
  ///
  /// In fa, this message translates to:
  /// **'شخصی'**
  String get iconGroupPersonal;

  /// No description provided for @iconGroupWork.
  ///
  /// In fa, this message translates to:
  /// **'کار و آموزش'**
  String get iconGroupWork;

  /// No description provided for @iconGroupLeisure.
  ///
  /// In fa, this message translates to:
  /// **'تفریح و سفر'**
  String get iconGroupLeisure;

  /// No description provided for @iconGroupOther.
  ///
  /// In fa, this message translates to:
  /// **'سایر'**
  String get iconGroupOther;

  /// No description provided for @editCategory.
  ///
  /// In fa, this message translates to:
  /// **'ویرایش دسته‌بندی'**
  String get editCategory;

  /// No description provided for @colorPickerTitle.
  ///
  /// In fa, this message translates to:
  /// **'انتخاب رنگ'**
  String get colorPickerTitle;

  /// No description provided for @colorPickerTabMain.
  ///
  /// In fa, this message translates to:
  /// **'اصلی'**
  String get colorPickerTabMain;

  /// No description provided for @colorPickerTabCustom.
  ///
  /// In fa, this message translates to:
  /// **'دلخواه'**
  String get colorPickerTabCustom;

  /// No description provided for @select.
  ///
  /// In fa, this message translates to:
  /// **'انتخاب'**
  String get select;

  /// No description provided for @hexLabelExample.
  ///
  /// In fa, this message translates to:
  /// **'HEX (مثلاً #1ABC9C)'**
  String get hexLabelExample;

  /// No description provided for @invalidHexCode.
  ///
  /// In fa, this message translates to:
  /// **'کد HEX نامعتبر است'**
  String get invalidHexCode;

  /// No description provided for @calendarSystem.
  ///
  /// In fa, this message translates to:
  /// **'تقویم'**
  String get calendarSystem;

  /// No description provided for @calendarJalali.
  ///
  /// In fa, this message translates to:
  /// **'شمسی'**
  String get calendarJalali;

  /// No description provided for @calendarGregorian.
  ///
  /// In fa, this message translates to:
  /// **'میلادی'**
  String get calendarGregorian;

  /// برچسب تب پایین برای فهرست درآمدها
  ///
  /// In fa, this message translates to:
  /// **'درآمد'**
  String get income;

  /// No description provided for @incomeTitle.
  ///
  /// In fa, this message translates to:
  /// **'درآمد'**
  String get incomeTitle;

  /// No description provided for @addIncomeTitle.
  ///
  /// In fa, this message translates to:
  /// **'افزودن درآمد'**
  String get addIncomeTitle;

  /// No description provided for @editIncomeTitle.
  ///
  /// In fa, this message translates to:
  /// **'ویرایش درآمد'**
  String get editIncomeTitle;

  /// No description provided for @incomeTitleHint.
  ///
  /// In fa, this message translates to:
  /// **'مثلاً: حقوق'**
  String get incomeTitleHint;

  /// No description provided for @amountHintIncomeOnly.
  ///
  /// In fa, this message translates to:
  /// **'درآمد'**
  String get amountHintIncomeOnly;

  /// No description provided for @totalIncome.
  ///
  /// In fa, this message translates to:
  /// **'مجموع درآمد'**
  String get totalIncome;

  /// No description provided for @seeLastEntry.
  ///
  /// In fa, this message translates to:
  /// **'رفتن به آخرین ثبت'**
  String get seeLastEntry;

  /// No description provided for @noIncomeThisRange.
  ///
  /// In fa, this message translates to:
  /// **'برای این بازه درآمدی ثبت نشده'**
  String get noIncomeThisRange;

  /// No description provided for @deleteIncomeTitle.
  ///
  /// In fa, this message translates to:
  /// **'حذف درآمد'**
  String get deleteIncomeTitle;

  /// No description provided for @deleteIncomeConfirm.
  ///
  /// In fa, this message translates to:
  /// **'آیا از حذف این مورد درآمد مطمئن هستید؟'**
  String get deleteIncomeConfirm;

  /// No description provided for @incomeCategories.
  ///
  /// In fa, this message translates to:
  /// **'دسته‌بندی‌های درآمد'**
  String get incomeCategories;

  /// No description provided for @upcomingTitle.
  ///
  /// In fa, this message translates to:
  /// **'پرداخت‌های پیش‌رو'**
  String get upcomingTitle;

  /// No description provided for @upcomingTotal.
  ///
  /// In fa, this message translates to:
  /// **'پیش‌رو'**
  String get upcomingTotal;

  /// No description provided for @addUpcomingTitle.
  ///
  /// In fa, this message translates to:
  /// **'افزودن پرداخت پیش‌رو'**
  String get addUpcomingTitle;

  /// No description provided for @editUpcomingTitle.
  ///
  /// In fa, this message translates to:
  /// **'ویرایش پرداخت پیش‌رو'**
  String get editUpcomingTitle;

  /// No description provided for @rescheduleUpcomingTitle.
  ///
  /// In fa, this message translates to:
  /// **'زمان‌بندی پرداخت بعدی'**
  String get rescheduleUpcomingTitle;

  /// No description provided for @upcomingEmpty.
  ///
  /// In fa, this message translates to:
  /// **'پرداختی در پیش نیست'**
  String get upcomingEmpty;

  /// No description provided for @upcomingDueSection.
  ///
  /// In fa, this message translates to:
  /// **'پرداخت‌نشده'**
  String get upcomingDueSection;

  /// No description provided for @upcomingPaidSection.
  ///
  /// In fa, this message translates to:
  /// **'پرداخت‌شده'**
  String get upcomingPaidSection;

  /// No description provided for @upcomingNothingPaid.
  ///
  /// In fa, this message translates to:
  /// **'هنوز چیزی پرداخت نشده'**
  String get upcomingNothingPaid;

  /// No description provided for @upcomingTitleHint.
  ///
  /// In fa, this message translates to:
  /// **'مثلاً قبض اینترنت'**
  String get upcomingTitleHint;

  /// No description provided for @dueDateLabel.
  ///
  /// In fa, this message translates to:
  /// **'سررسید'**
  String get dueDateLabel;

  /// No description provided for @dueDatePick.
  ///
  /// In fa, this message translates to:
  /// **'تاریخ سررسید'**
  String get dueDatePick;

  /// No description provided for @dueOn.
  ///
  /// In fa, this message translates to:
  /// **'سررسید {date}'**
  String dueOn(String date);

  /// No description provided for @markPaid.
  ///
  /// In fa, this message translates to:
  /// **'پرداخت شد'**
  String get markPaid;

  /// No description provided for @upcomingPaidOn.
  ///
  /// In fa, this message translates to:
  /// **'پرداخت {date}'**
  String upcomingPaidOn(String date);

  /// No description provided for @payAndReschedule.
  ///
  /// In fa, this message translates to:
  /// **'پرداخت و تمدید'**
  String get payAndReschedule;

  /// No description provided for @dueToday.
  ///
  /// In fa, this message translates to:
  /// **'امروز'**
  String get dueToday;

  /// No description provided for @dueTomorrow.
  ///
  /// In fa, this message translates to:
  /// **'فردا'**
  String get dueTomorrow;

  /// No description provided for @dueInDays.
  ///
  /// In fa, this message translates to:
  /// **'{days} روز مانده'**
  String dueInDays(String days);

  /// No description provided for @dueInOneDay.
  ///
  /// In fa, this message translates to:
  /// **'{days} روز مانده'**
  String dueInOneDay(String days);

  /// No description provided for @overdueDays.
  ///
  /// In fa, this message translates to:
  /// **'{days} روز گذشته'**
  String overdueDays(String days);

  /// No description provided for @overdueOneDay.
  ///
  /// In fa, this message translates to:
  /// **'{days} روز گذشته'**
  String overdueOneDay(String days);

  /// No description provided for @deleteUpcomingTitle.
  ///
  /// In fa, this message translates to:
  /// **'حذف پرداخت پیش‌رو'**
  String get deleteUpcomingTitle;

  /// No description provided for @deleteUpcomingConfirm.
  ///
  /// In fa, this message translates to:
  /// **'این مورد از پرداخت‌های پیش‌رو حذف شود؟ هزینه‌ای ثبت نمی‌شود'**
  String get deleteUpcomingConfirm;

  /// No description provided for @removeFromHistory.
  ///
  /// In fa, this message translates to:
  /// **'حذف از تاریخچه'**
  String get removeFromHistory;

  /// No description provided for @addUpcomingButton.
  ///
  /// In fa, this message translates to:
  /// **'افزودن پرداخت'**
  String get addUpcomingButton;

  /// No description provided for @expenseShort.
  ///
  /// In fa, this message translates to:
  /// **'هزینه'**
  String get expenseShort;

  /// Expense in a row of four pills (shorter in English)
  ///
  /// In fa, this message translates to:
  /// **'هزینه'**
  String get spentShort;

  /// No description provided for @historyTab.
  ///
  /// In fa, this message translates to:
  /// **'تاریخچه'**
  String get historyTab;

  /// No description provided for @incomingTab.
  ///
  /// In fa, this message translates to:
  /// **'پیش‌رو'**
  String get incomingTab;

  /// No description provided for @allShort.
  ///
  /// In fa, this message translates to:
  /// **'همه'**
  String get allShort;

  /// Shown in a suggestion row when nothing matches what was typed.
  ///
  /// In fa, this message translates to:
  /// **'موردی پیدا نشد'**
  String get noMatch;

  /// No description provided for @budget.
  ///
  /// In fa, this message translates to:
  /// **'بودجه'**
  String get budget;

  /// No description provided for @editBudget.
  ///
  /// In fa, this message translates to:
  /// **'ویرایش بودجه'**
  String get editBudget;

  /// No description provided for @addBudget.
  ///
  /// In fa, this message translates to:
  /// **'افزودن بودجه'**
  String get addBudget;

  /// No description provided for @categoryBudget.
  ///
  /// In fa, this message translates to:
  /// **'بودجه دسته'**
  String get categoryBudget;

  /// No description provided for @sortCustom.
  ///
  /// In fa, this message translates to:
  /// **'سفارشی'**
  String get sortCustom;

  /// No description provided for @assignBudgetFirst.
  ///
  /// In fa, this message translates to:
  /// **'ابتدا بودجه تعیین کنید'**
  String get assignBudgetFirst;

  /// No description provided for @fullData.
  ///
  /// In fa, this message translates to:
  /// **'داده کامل'**
  String get fullData;

  /// No description provided for @expensesOnly.
  ///
  /// In fa, this message translates to:
  /// **'فقط هزینه‌ها'**
  String get expensesOnly;

  /// No description provided for @dateLabel.
  ///
  /// In fa, this message translates to:
  /// **'تاریخ'**
  String get dateLabel;

  /// No description provided for @calendarJump.
  ///
  /// In fa, this message translates to:
  /// **'رفتن به یک روز'**
  String get calendarJump;

  /// No description provided for @calendarFull.
  ///
  /// In fa, this message translates to:
  /// **'کل دوره'**
  String get calendarFull;

  /// No description provided for @calendarWeek.
  ///
  /// In fa, this message translates to:
  /// **'یک هفته'**
  String get calendarWeek;

  /// No description provided for @todayWithDate.
  ///
  /// In fa, this message translates to:
  /// **'امروز {date}'**
  String todayWithDate(String date);

  /// No description provided for @categorySpendPerPeriod.
  ///
  /// In fa, this message translates to:
  /// **'هزینه‌های دسته در هر بازه'**
  String get categorySpendPerPeriod;

  /// No description provided for @calculator.
  ///
  /// In fa, this message translates to:
  /// **'ماشین حساب'**
  String get calculator;

  /// No description provided for @done.
  ///
  /// In fa, this message translates to:
  /// **'تأیید'**
  String get done;

  /// No description provided for @failedToSaveSettings.
  ///
  /// In fa, this message translates to:
  /// **'خطا در ذخیره تنظیمات'**
  String get failedToSaveSettings;

  /// No description provided for @unlockReason.
  ///
  /// In fa, this message translates to:
  /// **'برای باز کردن برنامه احراز هویت کنید'**
  String get unlockReason;

  /// No description provided for @bankBlu.
  ///
  /// In fa, this message translates to:
  /// **'بلو'**
  String get bankBlu;

  /// No description provided for @bankPasargad.
  ///
  /// In fa, this message translates to:
  /// **'پاسارگاد'**
  String get bankPasargad;

  /// Name of the default category created on first run.
  ///
  /// In fa, this message translates to:
  /// **'عمومی'**
  String get generalCategory;

  /// No description provided for @debtsTab.
  ///
  /// In fa, this message translates to:
  /// **'بدهی'**
  String get debtsTab;

  /// No description provided for @smsTab.
  ///
  /// In fa, this message translates to:
  /// **'پیامک'**
  String get smsTab;

  /// No description provided for @debtIOwe.
  ///
  /// In fa, this message translates to:
  /// **'بدهی من'**
  String get debtIOwe;

  /// No description provided for @debtOwedToMe.
  ///
  /// In fa, this message translates to:
  /// **'طلب من'**
  String get debtOwedToMe;

  /// No description provided for @debtsEmpty.
  ///
  /// In fa, this message translates to:
  /// **'بدهی یا طلبی ثبت نشده'**
  String get debtsEmpty;

  /// No description provided for @addDebtButton.
  ///
  /// In fa, this message translates to:
  /// **'افزودن بدهی یا طلب'**
  String get addDebtButton;

  /// No description provided for @debtPersonHint.
  ///
  /// In fa, this message translates to:
  /// **'نام شخص'**
  String get debtPersonHint;

  /// No description provided for @debtStartLabel.
  ///
  /// In fa, this message translates to:
  /// **'شروع'**
  String get debtStartLabel;

  /// No description provided for @debtSettled.
  ///
  /// In fa, this message translates to:
  /// **'تسویه شد'**
  String get debtSettled;

  /// No description provided for @deleteDebtTitle.
  ///
  /// In fa, this message translates to:
  /// **'حذف بدهی'**
  String get deleteDebtTitle;

  /// No description provided for @deleteDebtConfirm.
  ///
  /// In fa, this message translates to:
  /// **'این مورد و پرداخت‌هایش حذف شوند؟ هزینه‌ها و درآمدهایی که ثبت شده‌اند می‌مانند'**
  String get deleteDebtConfirm;

  /// No description provided for @debtLedgerTitleOwe.
  ///
  /// In fa, this message translates to:
  /// **'بازپرداخت به {person}'**
  String debtLedgerTitleOwe(String person);

  /// No description provided for @debtLedgerTitleOwed.
  ///
  /// In fa, this message translates to:
  /// **'دریافت از {person}'**
  String debtLedgerTitleOwed(String person);

  /// No description provided for @smsTabExplain.
  ///
  /// In fa, this message translates to:
  /// **'برای فهرست شدن پیامک‌های بانکی در اینجا، اجازه خواندن اعلان‌ها را بدهید. فقط پیامک‌های بانکی نگه داشته می‌شوند و چیزی از گوشی خارج نمی‌شود'**
  String get smsTabExplain;

  /// No description provided for @smsTabEmpty.
  ///
  /// In fa, this message translates to:
  /// **'پیامک‌های بانکی از این به بعد، با رسیدن، اینجا می‌آیند'**
  String get smsTabEmpty;

  /// No description provided for @smsAdded.
  ///
  /// In fa, this message translates to:
  /// **'ثبت شد'**
  String get smsAdded;

  /// No description provided for @smsOpen.
  ///
  /// In fa, this message translates to:
  /// **'باز کردن'**
  String get smsOpen;

  /// No description provided for @smsNewSection.
  ///
  /// In fa, this message translates to:
  /// **'تازه'**
  String get smsNewSection;

  /// No description provided for @smsSeenSection.
  ///
  /// In fa, this message translates to:
  /// **'دیده‌شده'**
  String get smsSeenSection;

  /// No description provided for @smsNothingNew.
  ///
  /// In fa, this message translates to:
  /// **'پیام تازه‌ای نیست'**
  String get smsNothingNew;

  /// No description provided for @smsNothingSeen.
  ///
  /// In fa, this message translates to:
  /// **'هنوز پیامی دیده نشده'**
  String get smsNothingSeen;

  /// No description provided for @smsMarkSeen.
  ///
  /// In fa, this message translates to:
  /// **'دیده شد'**
  String get smsMarkSeen;

  /// No description provided for @smsMarkUnseen.
  ///
  /// In fa, this message translates to:
  /// **'دیده نشده'**
  String get smsMarkUnseen;

  /// No description provided for @allowNotificationAccess.
  ///
  /// In fa, this message translates to:
  /// **'اجازه خواندن اعلان‌ها'**
  String get allowNotificationAccess;

  /// No description provided for @readBankNotifications.
  ///
  /// In fa, this message translates to:
  /// **'خواندن اعلان‌ها'**
  String get readBankNotifications;

  /// No description provided for @bankMessageFallback.
  ///
  /// In fa, this message translates to:
  /// **'پیامک بانکی'**
  String get bankMessageFallback;

  /// No description provided for @addAction.
  ///
  /// In fa, this message translates to:
  /// **'ثبت'**
  String get addAction;

  /// No description provided for @notifyBankMessages.
  ///
  /// In fa, this message translates to:
  /// **'نمایش اعلان‌ها'**
  String get notifyBankMessages;

  /// No description provided for @ignoredTitles.
  ///
  /// In fa, this message translates to:
  /// **'نادیده‌ها'**
  String get ignoredTitles;

  /// No description provided for @ignoredTitlesEmpty.
  ///
  /// In fa, this message translates to:
  /// **'عنوانی نادیده گرفته نشده. برای نادیده گرفتن، روی پیشنهاد عنوان انگشت نگه دارید'**
  String get ignoredTitlesEmpty;

  /// No description provided for @titleIgnored.
  ///
  /// In fa, this message translates to:
  /// **'«{title}» دیگر پیشنهاد نمی‌شود'**
  String titleIgnored(String title);

  /// No description provided for @undo.
  ///
  /// In fa, this message translates to:
  /// **'بازگردانی'**
  String get undo;

  /// No description provided for @suggestTitlesFromCategory.
  ///
  /// In fa, this message translates to:
  /// **'پیشنهاد عنوان‌ها'**
  String get suggestTitlesFromCategory;

  /// No description provided for @peopleTab.
  ///
  /// In fa, this message translates to:
  /// **'اشخاص'**
  String get peopleTab;

  /// No description provided for @debtShort.
  ///
  /// In fa, this message translates to:
  /// **'بدهی'**
  String get debtShort;

  /// No description provided for @creditShort.
  ///
  /// In fa, this message translates to:
  /// **'طلب'**
  String get creditShort;

  /// No description provided for @titlesTab.
  ///
  /// In fa, this message translates to:
  /// **'عناوین'**
  String get titlesTab;

  /// No description provided for @payOnly.
  ///
  /// In fa, this message translates to:
  /// **'پرداخت'**
  String get payOnly;

  /// No description provided for @payAndRecord.
  ///
  /// In fa, this message translates to:
  /// **'پرداخت و ثبت'**
  String get payAndRecord;

  /// No description provided for @recordPaid.
  ///
  /// In fa, this message translates to:
  /// **'ثبت'**
  String get recordPaid;

  /// No description provided for @receiveOnly.
  ///
  /// In fa, this message translates to:
  /// **'دریافت'**
  String get receiveOnly;

  /// No description provided for @receiveAndRecord.
  ///
  /// In fa, this message translates to:
  /// **'دریافت و ثبت'**
  String get receiveAndRecord;

  /// No description provided for @debtRecordPaid.
  ///
  /// In fa, this message translates to:
  /// **'ثبت'**
  String get debtRecordPaid;

  /// No description provided for @nextDue.
  ///
  /// In fa, this message translates to:
  /// **'سررسید بعدی: {when}'**
  String nextDue(String when);

  /// No description provided for @overdueCount.
  ///
  /// In fa, this message translates to:
  /// **'{count} مورد عقب‌افتاده'**
  String overdueCount(String count);

  /// No description provided for @nothingDue.
  ///
  /// In fa, this message translates to:
  /// **'سررسیدی نمانده'**
  String get nothingDue;

  /// No description provided for @notifReadMissing.
  ///
  /// In fa, this message translates to:
  /// **'این قابلیت بدون اجازه خواندن اعلان‌ها کار نمی‌کند'**
  String get notifReadMissing;

  /// No description provided for @needsPermission.
  ///
  /// In fa, this message translates to:
  /// **'بدون اجازه نمی‌شود این را روشن کرد'**
  String get needsPermission;

  /// No description provided for @noTitlesToIgnore.
  ///
  /// In fa, this message translates to:
  /// **'عنوانی برای نادیده گرفتن نیست'**
  String get noTitlesToIgnore;

  /// No description provided for @noPeopleToIgnore.
  ///
  /// In fa, this message translates to:
  /// **'شخصی برای نادیده گرفتن نیست'**
  String get noPeopleToIgnore;

  /// No description provided for @sortBudget.
  ///
  /// In fa, this message translates to:
  /// **'بودجه'**
  String get sortBudget;

  /// No description provided for @sortSpent.
  ///
  /// In fa, this message translates to:
  /// **'هزینه'**
  String get sortSpent;

  /// No description provided for @sortRemaining.
  ///
  /// In fa, this message translates to:
  /// **'مانده'**
  String get sortRemaining;

  /// No description provided for @sortAscending.
  ///
  /// In fa, this message translates to:
  /// **'صعودی'**
  String get sortAscending;

  /// No description provided for @sortDescending.
  ///
  /// In fa, this message translates to:
  /// **'نزولی'**
  String get sortDescending;

  /// No description provided for @budgetsSection.
  ///
  /// In fa, this message translates to:
  /// **'به تفکیک دسته'**
  String get budgetsSection;

  /// No description provided for @noBudgetGroup.
  ///
  /// In fa, this message translates to:
  /// **'بدون بودجه'**
  String get noBudgetGroup;

  /// No description provided for @formatUnknown.
  ///
  /// In fa, this message translates to:
  /// **'قالب ناشناخته'**
  String get formatUnknown;

  /// No description provided for @defineFormat.
  ///
  /// In fa, this message translates to:
  /// **'تعریف قالب'**
  String get defineFormat;

  /// No description provided for @ignoreFormat.
  ///
  /// In fa, this message translates to:
  /// **'نادیده گرفتن قالب'**
  String get ignoreFormat;

  /// No description provided for @ignoreSender.
  ///
  /// In fa, this message translates to:
  /// **'نادیده گرفتن فرستنده'**
  String get ignoreSender;

  /// No description provided for @pickAmountHint.
  ///
  /// In fa, this message translates to:
  /// **'عدد مبلغ را در پیامک انتخاب کنید'**
  String get pickAmountHint;

  /// No description provided for @saveFormat.
  ///
  /// In fa, this message translates to:
  /// **'ثبت قالب'**
  String get saveFormat;

  /// No description provided for @senderIgnored.
  ///
  /// In fa, this message translates to:
  /// **'پیامک‌های «{sender}» دیگر خوانده نمی‌شوند'**
  String senderIgnored(String sender);

  /// No description provided for @sectionPersonalization.
  ///
  /// In fa, this message translates to:
  /// **'شخصی‌سازی'**
  String get sectionPersonalization;

  /// No description provided for @sectionTabsAccess.
  ///
  /// In fa, this message translates to:
  /// **'تب‌ها و دسترسی'**
  String get sectionTabsAccess;

  /// No description provided for @sectionData.
  ///
  /// In fa, this message translates to:
  /// **'داده‌ها'**
  String get sectionData;

  /// No description provided for @historyAlwaysOn.
  ///
  /// In fa, this message translates to:
  /// **'تاریخچه همیشه روشن است'**
  String get historyAlwaysOn;

  /// No description provided for @smsFormats.
  ///
  /// In fa, this message translates to:
  /// **'قالب‌های پیامک'**
  String get smsFormats;

  /// No description provided for @formatsEmpty.
  ///
  /// In fa, this message translates to:
  /// **'هنوز قالبی تعریف نشده'**
  String get formatsEmpty;

  /// No description provided for @formatBySign.
  ///
  /// In fa, this message translates to:
  /// **'از روی علامت'**
  String get formatBySign;

  /// No description provided for @formatNoExample.
  ///
  /// In fa, this message translates to:
  /// **'بدون نمونه'**
  String get formatNoExample;

  /// No description provided for @deleteFormatTitle.
  ///
  /// In fa, this message translates to:
  /// **'حذف قالب'**
  String get deleteFormatTitle;

  /// No description provided for @deleteFormatConfirm.
  ///
  /// In fa, this message translates to:
  /// **'پیامک‌های این قالب دوباره ناشناخته می‌شوند'**
  String get deleteFormatConfirm;

  /// No description provided for @stopIgnoring.
  ///
  /// In fa, this message translates to:
  /// **'بازگرداندن'**
  String get stopIgnoring;

  /// No description provided for @smsNoneHere.
  ///
  /// In fa, this message translates to:
  /// **'پیامکی اینجا نیست'**
  String get smsNoneHere;

  /// No description provided for @ignoredOne.
  ///
  /// In fa, this message translates to:
  /// **'نادیده'**
  String get ignoredOne;

  /// No description provided for @smsFirst.
  ///
  /// In fa, this message translates to:
  /// **'اول تب پیامک را روشن کنید'**
  String get smsFirst;

  /// No description provided for @appMotto.
  ///
  /// In fa, this message translates to:
  /// **'مشکلی که شناسایی نشود هرگز حل نمی‌شود'**
  String get appMotto;

  /// No description provided for @notifyOffWarning.
  ///
  /// In fa, this message translates to:
  /// **'برای بهترین استفاده از این قابلیت، اعلان‌ها را روشن کنید'**
  String get notifyOffWarning;

  /// No description provided for @sectionHistory.
  ///
  /// In fa, this message translates to:
  /// **'تاریخچه'**
  String get sectionHistory;

  /// No description provided for @keepFolds.
  ///
  /// In fa, this message translates to:
  /// **'حفظ بازوبسته'**
  String get keepFolds;

  /// No description provided for @keepPlace.
  ///
  /// In fa, this message translates to:
  /// **'حفظ جایگاه'**
  String get keepPlace;

  /// No description provided for @keepEntries.
  ///
  /// In fa, this message translates to:
  /// **'حفظ ورودی‌ها'**
  String get keepEntries;

  /// No description provided for @couldNotOpen.
  ///
  /// In fa, this message translates to:
  /// **'باز نشد'**
  String get couldNotOpen;

  /// No description provided for @showSuggestions.
  ///
  /// In fa, this message translates to:
  /// **'نمایش پیشنهادها'**
  String get showSuggestions;

  /// No description provided for @backAgainToExit.
  ///
  /// In fa, this message translates to:
  /// **'برای خروج دوباره بازگشت را بزنید'**
  String get backAgainToExit;

  /// No description provided for @formatName.
  ///
  /// In fa, this message translates to:
  /// **'نام قالب'**
  String get formatName;

  /// No description provided for @showTips.
  ///
  /// In fa, this message translates to:
  /// **'آموزش'**
  String get showTips;

  /// No description provided for @neverWarn.
  ///
  /// In fa, this message translates to:
  /// **'هشدار نده'**
  String get neverWarn;

  /// No description provided for @tipWelcome.
  ///
  /// In fa, this message translates to:
  /// **'به OpenFinances خوش آمدید! این صفحه اصلی شماست. در تنظیمات می‌توانید زبانه‌های بیشتری اضافه کنید یا آموزش را خاموش کنید'**
  String get tipWelcome;

  /// No description provided for @tipPeriod.
  ///
  /// In fa, this message translates to:
  /// **'داده‌ها برای هر ماه نمایش داده می‌شوند. برای تغییر ماه، این کادر یا فلش‌های کنارش را بزنید'**
  String get tipPeriod;

  /// No description provided for @tipCards.
  ///
  /// In fa, this message translates to:
  /// **'یک کارت را بزنید تا فقط همان نوع نشان داده شود'**
  String get tipCards;

  /// No description provided for @tipAdd.
  ///
  /// In fa, this message translates to:
  /// **'با این دکمه یک مورد اضافه کنید. آنچه اضافه می‌کنید به صفحه‌ای که در آن هستید بستگی دارد'**
  String get tipAdd;

  /// No description provided for @tipTiles.
  ///
  /// In fa, this message translates to:
  /// **'یک ردیف را بزنید یا بکشید تا با آن کار کنید'**
  String get tipTiles;

  /// No description provided for @tipChips.
  ///
  /// In fa, this message translates to:
  /// **'یک دسته را بزنید تا فقط ردیف‌های همان را ببینید'**
  String get tipChips;

  /// No description provided for @tipBudget.
  ///
  /// In fa, this message translates to:
  /// **'برای دسته‌هایتان بودجه بگذارید تا حسابشان را داشته باشید'**
  String get tipBudget;

  /// No description provided for @tipSections.
  ///
  /// In fa, this message translates to:
  /// **'عنوان بخش را بزنید تا جمع شود، دوباره بزنید تا باز شود'**
  String get tipSections;

  /// No description provided for @setupMore.
  ///
  /// In fa, this message translates to:
  /// **'گزینه‌های بیشتر'**
  String get setupMore;

  /// No description provided for @setupContinue.
  ///
  /// In fa, this message translates to:
  /// **'ادامه'**
  String get setupContinue;

  /// No description provided for @privacyRead.
  ///
  /// In fa, this message translates to:
  /// **'{policy} را خوانده‌ام'**
  String privacyRead(String policy);

  /// No description provided for @privacyPolicy.
  ///
  /// In fa, this message translates to:
  /// **'حریم خصوصی'**
  String get privacyPolicy;

  /// No description provided for @privacyTitle.
  ///
  /// In fa, this message translates to:
  /// **'حریم خصوصی'**
  String get privacyTitle;

  /// No description provided for @privacyOfflineTitle.
  ///
  /// In fa, this message translates to:
  /// **'چیزی از گوشی شما بیرون نمی‌رود'**
  String get privacyOfflineTitle;

  /// No description provided for @privacyOffline.
  ///
  /// In fa, this message translates to:
  /// **'OpenFinances حساب کاربری، سرور، تبلیغات و آمارگیری ندارد. حتی اجازه دسترسی به اینترنت ندارد؛ پس اندروید نمی‌گذارد آنلاین شود'**
  String get privacyOffline;

  /// No description provided for @privacyDataTitle.
  ///
  /// In fa, this message translates to:
  /// **'داده‌های شما'**
  String get privacyDataTitle;

  /// No description provided for @privacyData.
  ///
  /// In fa, this message translates to:
  /// **'خرج‌ها، درآمدها، بودجه‌ها، بدهی‌ها و تنظیمات شما فقط در حافظه برنامه روی همین گوشی می‌مانند، مگر اینکه پشتیبان اندروید را روشن کنید. با حذف برنامه پاک می‌شوند'**
  String get privacyData;

  /// No description provided for @privacyBackupsTitle.
  ///
  /// In fa, this message translates to:
  /// **'پشتیبان'**
  String get privacyBackupsTitle;

  /// No description provided for @privacyBackups.
  ///
  /// In fa, this message translates to:
  /// **'پشتیبان فقط وقتی ساخته می‌شود که خودتان بخواهید: فایلی که هر جا بخواهید ذخیره می‌شود. اینکه از آنجا به کجا برود با خودتان است. پشتیبان خود اندروید در حساب گوگل شما خاموش است، مگر اینکه «اندروید از داده‌هایم پشتیبان بگیرد» را در بخش داده‌های تنظیمات تیک بزنید. تیک خورده باشد، اندروید داده‌های برنامه را فقط وقتی کپی می‌کند که آن را با قفل صفحه شما رمز کند، طوری که گوگل نتواند بخواندش. تیک نخورده باشد، انتقال گوشی به گوشی خود اندروید هم داده‌ها را نمی‌برد، هرچند ابزار انتقال بعضی سازنده‌های گوشی ممکن است باز هم کپی‌شان کنند'**
  String get privacyBackups;

  /// No description provided for @privacyBankTitle.
  ///
  /// In fa, this message translates to:
  /// **'پیامک‌های بانکی و دسترسی به اعلان‌ها'**
  String get privacyBankTitle;

  /// No description provided for @privacyBank.
  ///
  /// In fa, this message translates to:
  /// **'تا خودتان روشنش نکنید خاموش است. با روشن کردنش، اندروید از شما اجازه دسترسی به اعلان‌ها را می‌خواهد تا برنامه اعلان‌هایی را که برنامه پیامک برای پیامک‌های تازه نشان می‌دهد بخواند و ثبت تراکنش‌های بانکی را پیشنهاد کند. فقط پیامک‌هایی نگه داشته می‌شوند که تراکنش بانکی شناخته شوند؛ بقیه اعلان‌ها نادیده گرفته می‌شوند. هیچ چیز به جایی فرستاده نمی‌شود'**
  String get privacyBank;

  /// No description provided for @privacyUpdatesTitle.
  ///
  /// In fa, this message translates to:
  /// **'بررسی به‌روزرسانی'**
  String get privacyUpdatesTitle;

  /// No description provided for @privacyUpdates.
  ///
  /// In fa, this message translates to:
  /// **'فقط وقتی در بخش درباره «بررسی به‌روزرسانی» را بزنید، گوگل پلی (نه این برنامه) نسخه تازه‌تر را پیدا می‌کند؛ گوگل نسخه برنامه و مشخصات دستگاه را دریافت می‌کند'**
  String get privacyUpdates;

  /// No description provided for @privacyLockTitle.
  ///
  /// In fa, this message translates to:
  /// **'قفل اثر انگشت'**
  String get privacyLockTitle;

  /// No description provided for @privacyLock.
  ///
  /// In fa, this message translates to:
  /// **'اثر انگشت را خود اندروید بررسی می‌کند؛ برنامه هرگز آن را نمی‌بیند'**
  String get privacyLock;

  /// No description provided for @privacyRatingTitle.
  ///
  /// In fa, this message translates to:
  /// **'امتیاز دادن به برنامه'**
  String get privacyRatingTitle;

  /// No description provided for @privacyRating.
  ///
  /// In fa, this message translates to:
  /// **'گاهی پس از ثبت چند مورد، گوگل پلی ممکن است از شما بخواهد به برنامه امتیاز دهید. برنامه فقط تعداد ثبت‌ها را روی همین گوشی می‌شمارد. امتیاز شما به گوگل پلی می‌رود، نه به برنامه'**
  String get privacyRating;

  /// No description provided for @androidBackup.
  ///
  /// In fa, this message translates to:
  /// **'اندروید از داده‌هایم پشتیبان بگیرد'**
  String get androidBackup;

  /// No description provided for @androidBackupAbout.
  ///
  /// In fa, this message translates to:
  /// **'درباره پشتیبان اندروید'**
  String get androidBackupAbout;

  /// No description provided for @androidBackupInfo.
  ///
  /// In fa, this message translates to:
  /// **'داده‌هایتان با قفل صفحه شما رمزشده می‌ماند و گوگل نمی‌تواند آن را بخواند. گوشی اندرویدی تازه را با همان حساب گوگل و قفل صفحه گوشی قبلی راه‌اندازی کنید تا داده‌هایتان آنجا بازگردانده شود'**
  String get androidBackupInfo;

  /// No description provided for @privacyOk.
  ///
  /// In fa, this message translates to:
  /// **'متوجه شدم'**
  String get privacyOk;

  /// No description provided for @payHint.
  ///
  /// In fa, this message translates to:
  /// **'بازپرداخت'**
  String get payHint;

  /// No description provided for @payRemainingLabel.
  ///
  /// In fa, this message translates to:
  /// **'باقی‌مانده'**
  String get payRemainingLabel;

  /// No description provided for @repayments.
  ///
  /// In fa, this message translates to:
  /// **'بازپرداخت‌ها'**
  String get repayments;

  /// No description provided for @debtBelowPaid.
  ///
  /// In fa, this message translates to:
  /// **'تا الان {amount} بازپرداخت شده؛ بدهی نمی‌تواند کمتر از آن باشد. برای کمتر کردنش اول بازپرداخت‌ها را حذف کنید'**
  String debtBelowPaid(String amount);

  /// No description provided for @debtStartAfterRepayment.
  ///
  /// In fa, this message translates to:
  /// **'یک بازپرداخت در {date} ثبت شده؛ شروع بدهی نمی‌تواند بعد از آن باشد'**
  String debtStartAfterRepayment(String date);

  /// No description provided for @debtSideLocked.
  ///
  /// In fa, this message translates to:
  /// **'این بدهی بازپرداخت دارد؛ طرفش را نمی‌شود عوض کرد'**
  String get debtSideLocked;

  /// No description provided for @deleteRepaymentTitle.
  ///
  /// In fa, this message translates to:
  /// **'حذف بازپرداخت'**
  String get deleteRepaymentTitle;

  /// No description provided for @deleteRepaymentConfirm.
  ///
  /// In fa, this message translates to:
  /// **'این بازپرداخت و ثبتی که در تاریخچه گذاشته حذف می‌شوند'**
  String get deleteRepaymentConfirm;

  /// No description provided for @repaymentDeleted.
  ///
  /// In fa, this message translates to:
  /// **'بازپرداخت حذف شد'**
  String get repaymentDeleted;

  /// No description provided for @debtsOngoingSection.
  ///
  /// In fa, this message translates to:
  /// **'در جریان'**
  String get debtsOngoingSection;

  /// No description provided for @debtsPaidSection.
  ///
  /// In fa, this message translates to:
  /// **'تسویه‌شده'**
  String get debtsPaidSection;

  /// No description provided for @debtsNothingOngoing.
  ///
  /// In fa, this message translates to:
  /// **'چیزی در جریان نیست'**
  String get debtsNothingOngoing;

  /// No description provided for @debtsNothingPaid.
  ///
  /// In fa, this message translates to:
  /// **'هنوز چیزی تسویه نشده'**
  String get debtsNothingPaid;

  /// No description provided for @repaymentLabel.
  ///
  /// In fa, this message translates to:
  /// **'بازپرداخت'**
  String get repaymentLabel;

  /// No description provided for @deleteCategoryMoveTo.
  ///
  /// In fa, this message translates to:
  /// **'این دسته‌بندی حذف می‌شود و ثبت‌هایش به دسته‌بندی‌ای که پایین انتخاب کنید منتقل می‌شوند'**
  String get deleteCategoryMoveTo;

  /// No description provided for @quickZeros.
  ///
  /// In fa, this message translates to:
  /// **'دکمه 000'**
  String get quickZeros;

  /// No description provided for @haptics.
  ///
  /// In fa, this message translates to:
  /// **'لرزش'**
  String get haptics;

  /// No description provided for @debtPaidLabel.
  ///
  /// In fa, this message translates to:
  /// **'پرداخت‌شده'**
  String get debtPaidLabel;

  /// No description provided for @debtDueBy.
  ///
  /// In fa, this message translates to:
  /// **'تا {date}'**
  String debtDueBy(String date);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fa'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fa':
      return AppLocalizationsFa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
