// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Persian (`fa`).
class AppLocalizationsFa extends AppLocalizations {
  AppLocalizationsFa([String locale = 'fa']) : super(locale);

  @override
  String get atmosphereNone => 'هیچ';

  @override
  String get atmosphereEmber => 'اخگر';

  @override
  String get atmosphereDusk => 'غروب';

  @override
  String get atmosphereMoss => 'خزه';

  @override
  String get atmosphereRose => 'رز';

  @override
  String get atmosphereDots => 'نقطه‌ها';

  @override
  String get atmosphereGrid => 'شبکه';

  @override
  String get atmosphereWaves => 'موج‌ها';

  @override
  String get atmosphereRain => 'باران';

  @override
  String get atmosphereLateNight => 'نیمه‌شب';

  @override
  String get atmosphereWarmAfternoon => 'عصر گرم';

  @override
  String get atmosphereSnow => 'برف';

  @override
  String get atmosphereDesert => 'کویر';

  @override
  String get atmospherePaper => 'کاغذ';

  @override
  String get accentYellow => 'زرد';

  @override
  String get accentGrey => 'خاکستری';

  @override
  String get accentPurple => 'بنفش';

  @override
  String get accentLime => 'لیمویی';

  @override
  String get accentVelvet => 'مخملی';

  @override
  String get accentBlue => 'آبی';

  @override
  String get appearancePreview => 'پیش‌نمایش گفتگوهای شما با این رنگ';

  @override
  String get appearanceSampleIn => 'امشب هنوز سر قرار هستیم؟';

  @override
  String get appearanceSampleOut => 'بله. ساعت هشت، همان جای همیشگی.';

  @override
  String get appearanceSampleButton => 'پاسخ';

  @override
  String get appearanceAccentHint =>
      'دکمه‌ها، پیام‌های خودتان و پیوندها این رنگ را می‌گیرند. نماد برنامه زرد می‌ماند.';

  @override
  String get appearanceChatWallpaper => 'تصویر زمینه گفتگو';

  @override
  String get appearanceEveryChat => 'همه گفتگوها';

  @override
  String get appearanceWallpaperHint =>
      'تصویر زمینه‌ای که از منوی خود گفتگو انتخاب شود، اولویت دارد. عکس‌ها روی همین گوشی، رمزگذاری‌شده همراه گفتگوهای شما، می‌مانند.';

  @override
  String get backupThatPassphraseDoesNot =>
      'این عبارت عبور این فایل را باز نمی‌کند';

  @override
  String get backupThatFileIsNot => 'این فایل نسخه‌ی پشتیبان Kryfo نیست';

  @override
  String get backupThisBackupIsFrom =>
      'این نسخه‌ی پشتیبان را Kryfo جدیدتری ساخته است. برنامه را به‌روز کنید و دوباره امتحان کنید';

  @override
  String get backupThisFileIsDamaged =>
      'این فایل آسیب دیده است و خوانده نمی‌شود';

  @override
  String get backupTheRestoreStoppedPartway => 'بازیابی نیمه‌کاره ماند';

  @override
  String get backupCouldNotMakeThe => 'کلید ساخته نشد';

  @override
  String get contactCardMessageMeOn => 'به من پیام دهید در';

  @override
  String get contactCardScanToAdd =>
      'آن را با Kryfo اسکن کنید تا مرا اضافه کنید.\nاین کارت جز این، چیزی درباره‌ی شما نمی‌داند.';

  @override
  String contactCardMessageMeOnKryfo(Object haloId) {
    return 'در Kryfo به من پیام دهید · ⁨$haloId⁩';
  }

  @override
  String get contactStatusBlocked => 'مسدود';

  @override
  String get contactStatusKeysVerifiedInPerson => 'کلیدها حضوری تأیید شده';

  @override
  String get contactStatusWaitingInRequests => 'در صف درخواست‌ها';

  @override
  String get contactStatusAddedByHand => 'دستی اضافه شده';

  @override
  String get deliveryModeAlwaysOn => 'همیشه روشن';

  @override
  String get deliveryModeCheckIns => 'سرکشی دوره‌ای';

  @override
  String get deliveryModeThroughAHelperApp => 'با برنامه‌ی کمکی';

  @override
  String get deliveryModeNotYet => 'هنوز نه';

  @override
  String get deliveryModeJustNow => 'همین الان';

  @override
  String deliveryModeMinAgo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$countString⁩ دقیقه پیش',
    );
    return '$_temp0';
  }

  @override
  String deliveryMode1HourAgo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$countString⁩ ساعت پیش',
      one: '⁨$countString⁩ ساعت پیش',
    );
    return '$_temp0';
  }

  @override
  String get deliveryModeYesterday => 'دیروز';

  @override
  String deliveryModeDaysAgo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$countString⁩ روز پیش',
      one: '⁨$countString⁩ روز پیش',
    );
    return '$_temp0';
  }

  @override
  String get deliveryModeConnected => 'متصل';

  @override
  String get deliveryModeConnecting => 'در حال اتصال';

  @override
  String get deliveryModeNotConnected => 'متصل نیست';

  @override
  String get deliveryModeCheckingNow => 'در حال سرکشی';

  @override
  String deliveryModeLastCheckIn(Object agoLine) {
    return 'آخرین سرکشی ⁨$agoLine⁩';
  }

  @override
  String get deliveryModeNoCheckInYet => 'هنوز سرکشی نشده';

  @override
  String deliveryModeConnectedNow(Object last) {
    return 'اکنون متصل · ⁨$last⁩';
  }

  @override
  String deliveryModeConnecting2(Object last) {
    return 'در حال اتصال · ⁨$last⁩';
  }

  @override
  String get deliveryModeNoCheckInYet2 => 'هنوز سرکشی نشده';

  @override
  String deliveryModeLastChecked(Object agoLine) {
    return 'آخرین سرکشی ⁨$agoLine⁩';
  }

  @override
  String get deliveryModeAHelperApp => 'یک برنامه‌ی کمکی';

  @override
  String deliveryModeWokenByNoWake(Object who) {
    return 'با ⁨$who⁩ بیدار می‌شود · هنوز بیدار نشده';
  }

  @override
  String deliveryModeWokenByLastWake(Object who, Object agoLine) {
    return 'با ⁨$who⁩ بیدار می‌شود · آخرین بیداری ⁨$agoLine⁩';
  }

  @override
  String get introBudgetTomorrow => 'فردا';

  @override
  String introBudgetInDays(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$countString⁩ روز دیگر',
      one: '⁨$countString⁩ روز دیگر',
    );
    return '$_temp0';
  }

  @override
  String get introBudgetInAnHour => 'یک ساعت دیگر';

  @override
  String introBudgetInHours(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$countString⁩ ساعت دیگر',
      one: '⁨$countString⁩ ساعت دیگر',
    );
    return '$_temp0';
  }

  @override
  String get introBudgetInAFewMinutes => 'چند دقیقه‌ی دیگر';

  @override
  String get lockStateUnlockKryfo => 'باز کردن قفل Kryfo';

  @override
  String get appInvalidUri => 'نشانی نامعتبر';

  @override
  String appBundleError(Object e) {
    return 'خطای بسته: ⁨$e⁩';
  }

  @override
  String appAlreadySaved(Object parsed) {
    return 'از قبل ذخیره شده: ⁨$parsed⁩';
  }

  @override
  String appLongWindow(Object line) {
    return '⁨$line⁩، بازه‌ی طولانی';
  }

  @override
  String appOf(Object line, int held, int subs, Object c, int p, int e) {
    final intl.NumberFormat heldNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String heldString = heldNumberFormat.format(held);
    final intl.NumberFormat subsNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String subsString = subsNumberFormat.format(subs);
    final intl.NumberFormat pNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String pString = pNumberFormat.format(p);
    final intl.NumberFormat eNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String eString = eNumberFormat.format(e);

    String _temp0 = intl.Intl.pluralLogic(
      p,
      locale: localeName,
      other: '⁨$pString⁩ صفحه',
      one: '⁨$pString⁩ صفحه',
    );
    String _temp1 = intl.Intl.pluralLogic(
      e,
      locale: localeName,
      other: '⁨$eString⁩ رویداد',
      one: '⁨$eString⁩ رویداد',
    );
    return '⁨$line⁩ (⁨$heldString⁩ از ⁨$subsString⁩، اتصال ⁨$c⁩ ثانیه، $_temp0، $_temp1)';
  }

  @override
  String appConnectSPagesEvents(Object line, Object c, int p, int e) {
    final intl.NumberFormat pNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String pString = pNumberFormat.format(p);
    final intl.NumberFormat eNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String eString = eNumberFormat.format(e);

    String _temp0 = intl.Intl.pluralLogic(
      p,
      locale: localeName,
      other: '⁨$pString⁩ صفحه',
      one: '⁨$pString⁩ صفحه',
    );
    String _temp1 = intl.Intl.pluralLogic(
      e,
      locale: localeName,
      other: '⁨$eString⁩ رویداد',
      one: '⁨$eString⁩ رویداد',
    );
    return '⁨$line⁩ (اتصال ⁨$c⁩ ثانیه، $_temp0، $_temp1)';
  }

  @override
  String appSDropped(Object host, Object secs) {
    return '⁨$host⁩ پس از ⁨$secs⁩ ثانیه قطع شد';
  }

  @override
  String appS(Object host, Object secs) {
    return '⁨$host⁩ در ⁨$secs⁩ ثانیه';
  }

  @override
  String get appTorWouldNotWake => 'Tor بیدار نشد';

  @override
  String get appCheckStarted => 'فقط شروع شد';

  @override
  String get appTorNotReadyIn => 'Tor در ۷۵ ثانیه آماده نشد';

  @override
  String get appOk => 'موفق';

  @override
  String get appOkNoRelayBegan => 'موفق، هیچ رله‌ای پاسخ نداد';

  @override
  String get appNoRelayReached => 'به هیچ رله‌ای وصل نشد';

  @override
  String get appOkCapped => 'موفق، سقف زمان';

  @override
  String appSBy(Object how, int secs, String why) {
    final intl.NumberFormat secsNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String secsString = secsNumberFormat.format(secs);

    String _temp0 = intl.Intl.selectLogic(why, {
      'push': '⁨$how⁩، ⁨$secsString⁩ ثانیه، با پوش',
      'other': '⁨$how⁩، ⁨$secsString⁩ ثانیه، با کار پس‌زمینه',
    });
    return '$_temp0';
  }

  @override
  String get appAnAttachmentCouldNot => 'یک پیوست روی این گوشی ذخیره نشد';

  @override
  String get appGroup2 => 'گروه';

  @override
  String get appVoiceMessage => 'پیام صوتی';

  @override
  String get appPhoto => 'عکس';

  @override
  String get appNewRequest => 'درخواست جدید';

  @override
  String get appSomeoneYouHaveNot =>
      'کسی که اضافه‌اش نکرده‌اید به شما پیام داده است';

  @override
  String get appSettingUpYourKeys => 'آماده‌سازی کلیدهای شما';

  @override
  String get appOpeningYourChats => 'باز کردن گفت‌وگوهای شما';

  @override
  String get appStartingTor => 'راه‌اندازی Tor';

  @override
  String get appTimedMessagesAreNot =>
      'پیام‌های زمان‌دار محو نمی‌شوند. Kryfo را دوباره راه‌اندازی کنید';

  @override
  String get appVoiceMessage2 => 'پیام صوتی';

  @override
  String appYou(Object body) {
    return 'شما: ⁨$body⁩';
  }

  @override
  String get appThisRoomHasAlready => 'این اتاق منقضی شده است';

  @override
  String get appYouAreAlreadyIn => 'شما از قبل در این اتاق هستید';

  @override
  String get appCouldNotMakeA => 'کلید اتاق ساخته نشد';

  @override
  String appJoined(Object linkName) {
    return 'به ⁨$linkName⁩ پیوستید';
  }

  @override
  String get roomJoinWaitingToJoin => 'در انتظار پیوستن';

  @override
  String get roomJoinNotAnswering => 'پاسخی نمی‌دهد';

  @override
  String roomJoinWaitingFor(Object room) {
    return 'منتظر اجازهٔ ورود به ⁨$room⁩…';
  }

  @override
  String get roomJoinWaitingLine => 'وقتی وارد شدید، می‌توانید اینجا بنویسید.';

  @override
  String get roomJoinNoAnswer => 'این اتاق پاسخی نمی‌دهد.';

  @override
  String get roomJoinMayHaveEnded => 'شاید به پایان رسیده باشد.';

  @override
  String get roomJoinFullShort => 'اتاق پر است';

  @override
  String get roomJoinFull => 'این اتاق پر است.';

  @override
  String get roomJoinFullLine =>
      'فعلاً جای خالی نیست. بعداً دوباره امتحان کنید، یا از کسی که پیوند را فرستاد بپرسید.';

  @override
  String get appBooting => 'راه‌اندازی...';

  @override
  String get appSettingUpYourIdentity => 'در حال آماده‌سازی هویت شما...';

  @override
  String get appAddSomeone => 'افزودن یک نفر';

  @override
  String get appScanTheirCodeOr =>
      'کد او را اسکن کنید، یا چیزی را که به شما داده جای‌گذاری کنید: یک پیوند، یک نام کاربری یا پیوند یک اتاق.';

  @override
  String get appScanTheirCode => 'اسکن کد او';

  @override
  String get appAKryfoLinkA => 'پیوند Kryfo، پیوند اتاق یا ‎@bolbol';

  @override
  String get appAddThem => 'افزودن';

  @override
  String get appEveryWayToAdd => 'همه‌ی راه‌های افزودن';

  @override
  String get appShowYourCodeSend =>
      'کدتان را نشان دهید، پیوند بفرستید، نام کاربری بگیرید';

  @override
  String get appHelloFromTheOther => 'سلام از آن سو';

  @override
  String get appIdentityRestored => 'هویت بازیابی شد';

  @override
  String get appIdentityCreated => 'هویت ساخته شد';

  @override
  String get appStartingTor30s => 'راه‌اندازی Tor (حدود ۳۰ ثانیه)...';

  @override
  String get appScanOrImportA => 'اول یک همتا را اسکن یا وارد کنید';

  @override
  String get appEncryptingSending30s => 'رمزگذاری + ارسال (حدود ۳۰ ثانیه)...';

  @override
  String get appTapStartListeningFirst => 'اول «شروع شنود» را بزنید';

  @override
  String get appYourKryfo => 'Kryfo شما';

  @override
  String get appUriCopied => 'نشانی کپی شد';

  @override
  String get appCopyUri => 'کپی نشانی';

  @override
  String get appAddAKryfo => 'افزودن یک Kryfo';

  @override
  String get appScanQr => 'اسکن QR';

  @override
  String get appPairingCode => 'کد جفت‌سازی';

  @override
  String get appOrPaste => '- یا جای‌گذاری -';

  @override
  String get commonCancel => 'لغو';

  @override
  String get appImport => 'وارد کردن';

  @override
  String get appDev => 'توسعه';

  @override
  String get appYourKryfo2 => 'Kryfo شما:';

  @override
  String get appRestoredFromDisk => 'از حافظه بازیابی شد';

  @override
  String get appStartListening => 'شروع شنود';

  @override
  String get appListening => 'در حال شنود';

  @override
  String get appShowMyQr => 'نمایش QR من';

  @override
  String get appImportPeer => 'وارد کردن همتا';

  @override
  String get appPeer => 'همتا:';

  @override
  String get appMessageWillBeEncrypted => 'پیام (رمزگذاری خواهد شد)';

  @override
  String get appEncryptSend => 'رمزگذاری + ارسال';

  @override
  String appStatus(Object status) {
    return 'وضعیت: ⁨$status⁩';
  }

  @override
  String get appSpeedPrivacy => 'سرعت و حریم خصوصی ←';

  @override
  String get appGettingMessages => 'دریافت پیام‌ها ←';

  @override
  String get appDisableAppLock => 'قفل برنامه غیرفعال شود؟';

  @override
  String get appThePinWillBe =>
      'PIN حذف می‌شود. هر کس گوشی شما دستش باشد، با باز کردن Kryfo آن را می‌بیند.';

  @override
  String get appDisable => 'غیرفعال کردن';

  @override
  String get appAppLockOn => 'قفل برنامه · روشن ←';

  @override
  String get appAppLockOff => 'قفل برنامه · خاموش ←';

  @override
  String get appTorIsOff => 'Tor خاموش است';

  @override
  String get appConnectedRoutedThrough3 => 'متصل · عبور از ۳ رله';

  @override
  String get appReadyToSendPublishing =>
      'آماده‌ی ارسال · در حال انتشار نشانی شما';

  @override
  String get appReadyToSendFinishing =>
      'آماده‌ی ارسال · در حال تکمیل راه‌اندازی';

  @override
  String appConnecting(Object pct) {
    return 'در حال اتصال · ⁨$pct⁩';
  }

  @override
  String get appTor => 'Tor';

  @override
  String get appTorIsOffTurn => 'Tor خاموش است. برای اتصال خصوصی، روشنش کنید.';

  @override
  String get appTheFirstConnectionTakes =>
      'اولین اتصال یکی دو دقیقه طول می‌کشد تا Tor مسیری خصوصی بسازد. پس از آن مسیر در حافظه می‌ماند، پس Kryfo دفعه‌های بعد خیلی سریع‌تر باز می‌شود.';

  @override
  String get appTorNoRelayYet =>
      'اتصال Tor برقرار است، اما هنوز هیچ رله‌ای پاسخ نمی‌دهد. Kryfo همچنان تلاش می‌کند و پیام‌ها همین‌جا می‌مانند تا یکی پاسخ دهد.';

  @override
  String get appRelayAndFastModes =>
      'حالت‌های رله و سریع Tor را دور می‌زنند و سریع‌ترند. این حالت‌ها در تنظیمات، زیر «سرعت و حریم خصوصی» هستند و هر کدام می‌گوید چه بهایی دارد.';

  @override
  String get appViaRelay => 'از راه رله';

  @override
  String get appOffline => 'آفلاین';

  @override
  String get appFast => 'سریع';

  @override
  String get appTorOff => 'Tor خاموش';

  @override
  String get appTorReady => 'Tor آماده';

  @override
  String get appConnecting2 => 'در حال اتصال';

  @override
  String get appWaitingForARelay => 'در انتظار رله';

  @override
  String mediaProgressSendingKeepTheApp(Object v) {
    return 'در حال ارسال · ⁨$v⁩ · برنامه را باز نگه دارید';
  }

  @override
  String mediaProgressPausedOfWaitingFor(Object count, Object count2) {
    return 'متوقف · ⁨$count⁩ از ⁨$count2⁩ · در انتظار بقیه';
  }

  @override
  String mediaProgressReceivingMedia(Object v) {
    return 'دریافت رسانه · ⁨$v⁩';
  }

  @override
  String get mediaProgressCancelSending => 'لغو ارسال';

  @override
  String get metaReaderEndsBeforeItShould => 'زودتر از انتظار تمام می‌شود';

  @override
  String get metaReaderCouldNotBeRead => 'خوانده نشد';

  @override
  String get metaReaderExifThatCannotBe => 'EXIF ناخوانا';

  @override
  String get metaReaderSamsungTrailer => 'دنباله‌ی سامسونگ';

  @override
  String metaReaderChunk(Object type) {
    return 'تکه‌ی ⁨$type⁩';
  }

  @override
  String get metaReaderExifFlagSet => 'پرچم EXIF روشن';

  @override
  String get metaReaderXmpFlagSet => 'پرچم XMP روشن';

  @override
  String metaReaderAppBlock(Object id) {
    return 'بلوک برنامه ⁨$id⁩';
  }

  @override
  String get metaReaderUuidBox => 'جعبه‌ی uuid';

  @override
  String metaReaderBox(Object printable) {
    return 'جعبه‌ی ⁨$printable⁩';
  }

  @override
  String get metaReaderAttachedData => 'داده‌ی پیوست‌شده';

  @override
  String metaReaderItem(Object printable) {
    return 'مورد ⁨$printable⁩';
  }

  @override
  String get miuiAutostartAlreadyAllowedToRun =>
      'از قبل اجازه‌ی اجرا در پس‌زمینه را دارد';

  @override
  String get miuiAutostartLetKryfoRunIn => 'بگذارید Kryfo در پس‌زمینه اجرا شود';

  @override
  String get miuiAutostartYourPhonePausesApps =>
      'گوشی شما برای صرفه‌جویی در باتری، برنامه‌ها را متوقف می‌کند. بدون استثنا، Kryfo وقتی بسته است نمی‌تواند پیام دریافت کند.';

  @override
  String get commonAllow => 'اجازه دادن';

  @override
  String get commonSkip => 'رد شدن';

  @override
  String get miuiAutostartOpenSettings => 'باز کردن تنظیمات';

  @override
  String get miuiAutostartCouldnTOpenIt =>
      'باز نشد. در تنظیمات گوشی دنبال «شروع خودکار» بگردید';

  @override
  String get batteryGuideHuawei =>
      'هواوی و آنر برنامه‌هایی را که خودشان مدیریت می‌کنند می‌بندند. در صفحه‌ی بعد، Kryfo را پیدا کنید، «مدیریت خودکار» را خاموش کنید و «اجرای خودکار»، «اجرای ثانویه» و «اجرا در پس‌زمینه» را روشن بگذارید.';

  @override
  String get batteryGuideOppo =>
      'اوپو و ریلمی برنامه‌ها را در پس‌زمینه متوقف می‌کنند. در صفحه‌ی بعد، Kryfo را پیدا کنید و «اجرای خودکار» را مجاز کنید. در بخش باتری هم فعالیت در پس‌زمینه را برایش مجاز کنید.';

  @override
  String get batteryGuideVivo =>
      'ویوو برنامه‌ها را در پس‌زمینه متوقف می‌کند. در صفحه‌ی بعد، Kryfo را پیدا کنید و اجازه دهید در پس‌زمینه شروع شود. در بخش باتری هم مصرف بالای انرژی در پس‌زمینه را برایش مجاز کنید.';

  @override
  String get batteryGuideSamsung =>
      'سامسونگ برنامه‌هایی را که فکر می‌کند استفاده نمی‌شوند به خواب می‌برد. در صفحه‌ی بعد، «محدودیت‌های استفاده در پس‌زمینه» را باز کنید و Kryfo را به «برنامه‌هایی که هرگز به خواب نمی‌روند» اضافه کنید.';

  @override
  String get batteryGuideOnePlus =>
      'وان‌پلاس برنامه‌ها را در پس‌زمینه متوقف می‌کند. در صفحه‌ی بعد، Kryfo را پیدا کنید و «اجرای خودکار» را مجاز کنید. در بخش باتری، «بهینه نکن» را برایش انتخاب کنید.';

  @override
  String get batteryGuideXiaomiTitle => 'Kryfo را در حال اجرا نگه دارید';

  @override
  String get batteryGuideXiaomi =>
      'شیائومی برنامه‌ها را در پس‌زمینه متوقف می‌کند، حتی وقتی «شروع خودکار» روشن است. برای اینکه پیام‌ها همچنان برسند:';

  @override
  String get batteryGuideXiaomiStep1 =>
      'شروع خودکار: آن را برای Kryfo روشن کنید.';

  @override
  String get batteryGuideXiaomiStep2 =>
      'صرفه‌جویی باتری: Kryfo را روی «بدون محدودیت» بگذارید.';

  @override
  String get batteryGuideXiaomiStep3 =>
      'برنامه‌های اخیر: Kryfo را لمس کنید و نگه دارید و روی قفل بزنید، تا «پاک کردن همه» و پاک‌سازی گوشی آن را نبندند.';

  @override
  String get batteryGuideXiaomiAfter =>
      'اگر گوشی باز هم Kryfo را متوقف کند، تا وقتی دوباره بازش نکنید چیزی نمی‌رسد.';

  @override
  String get notificationsNewEncryptedMessagesFrom =>
      'پیام‌های رمزگذاری‌شده‌ی جدید از مخاطبان شما';

  @override
  String get notificationsNewMessage => 'پیام جدید';

  @override
  String get notificationsNewEncryptedMessagesFromYourContacts =>
      'پیام‌های رمزگذاری‌شده‌ی جدید از مخاطبان شما';

  @override
  String get notificationsNewMessage2 => 'پیام جدید';

  @override
  String get notificationsSomeone => 'یک نفر';

  @override
  String get notificationsEncrypted => 'رمزگذاری‌شده';

  @override
  String get rooms24h => '۲۴ ساعت';

  @override
  String roomsD(Object inDays) {
    return '⁨$inDays⁩ روز';
  }

  @override
  String roomsH(Object inHours) {
    return '⁨$inHours⁩ ساعت';
  }

  @override
  String get rooms24Hours => '۲۴ ساعت';

  @override
  String roomsDays(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$countString⁩ روز',
      one: '⁨$countString⁩ روز',
    );
    return '$_temp0';
  }

  @override
  String get roomsAnHour => 'یک ساعت';

  @override
  String get roomsAboutAnHour => 'حدود یک ساعت';

  @override
  String roomsHours(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$countString⁩ ساعت',
      one: '⁨$countString⁩ ساعت',
    );
    return '$_temp0';
  }

  @override
  String roomsAboutHours(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'حدود ⁨$countString⁩ ساعت',
      one: 'حدود ⁨$countString⁩ ساعت',
    );
    return '$_temp0';
  }

  @override
  String roomsMinutes(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$countString⁩ دقیقه',
      one: '⁨$countString⁩ دقیقه',
    );
    return '$_temp0';
  }

  @override
  String get roomsAMinute => 'یک دقیقه';

  @override
  String get roomsExpired => 'منقضی شده';

  @override
  String roomsDH(Object inDays, Object h) {
    return '⁨$inDays⁩ روز ⁨$h⁩ ساعت';
  }

  @override
  String roomsHM(Object inHours, Object m) {
    return '⁨$inHours⁩ ساعت ⁨$m⁩ دقیقه';
  }

  @override
  String roomsM(Object inMinutes) {
    return '⁨$inMinutes⁩ دقیقه';
  }

  @override
  String scamShieldGivesUsedName(Object shown) {
    return 'خود را ⁨$shown⁩ معرفی می‌کند، نامی که کس دیگری اینجا دارد';
  }

  @override
  String scamShieldWarning(Object noticed) {
    return '$noticed. به کسی که او را ندیده‌اید پول یا کد نفرستید.';
  }

  @override
  String get scamShieldAsksForSecret => 'کد، PIN یا کلمات بازیابی می‌خواهد';

  @override
  String get scamShieldAsksForMoneyFast => 'با عجله پول می‌خواهد';

  @override
  String get scamShieldPromisesProfit => 'وعده‌ی سود آسان می‌دهد';

  @override
  String get scamShieldClaimsSupport =>
      'ادعا می‌کند از Kryfo یا یک تیم پشتیبانی است';

  @override
  String get scamShieldDismiss => 'پنهان کردن';

  @override
  String scamShieldNameMatchesYourContact(Object shown) {
    return 'نامش با مخاطبتان ⁨$shown⁩ یکی است';
  }

  @override
  String get scamShieldLinksToALookalike =>
      'به بدلی از یک سایت شناخته‌شده پیوند می‌دهد';

  @override
  String get commonBack => 'بازگشت';

  @override
  String get archivedArchived => 'بایگانی';

  @override
  String get archivedCount0 => 'هیچ';

  @override
  String get archivedCount1 => 'یک';

  @override
  String get archivedCount2 => 'دو';

  @override
  String get archivedCount3 => 'سه';

  @override
  String get archivedCount4 => 'چهار';

  @override
  String get archivedCount5 => 'پنج';

  @override
  String get archivedCount6 => 'شش';

  @override
  String get archivedCount7 => 'هفت';

  @override
  String get archivedCount8 => 'هشت';

  @override
  String get archivedCount9 => 'نه';

  @override
  String get archivedCount10 => 'ده';

  @override
  String get archivedChatRestingHereIt =>
      'گفت‌وگو این‌جا آرام گرفته است. تا او چیزی ننویسد بی‌صدا می‌ماند، بعد به بالای فهرست برمی‌گردد.';

  @override
  String get archivedChatsRestingHere =>
      'گفت‌وگو این‌جا آرام گرفته‌اند. تا کسی چیزی ننویسد بی‌صدا می‌مانند، بعد به بالای فهرست برمی‌گردند.';

  @override
  String get archivedNothingArchived => 'چیزی بایگانی نشده';

  @override
  String get archivedArchivedChatsAreStill =>
      'گفت‌وگوهای بایگانی‌شده همچنان سرتاسری رمزگذاری‌شده‌اند';

  @override
  String get archivedUnarchive => 'خروج از بایگانی';

  @override
  String get avatarPickerThePeopleYouMessage =>
      'کسانی که به آن‌ها پیام می‌دهید هم این را می‌بینند';

  @override
  String get avatarPickerBackToYourInitial => 'برگشت به حرف اول نامتان';

  @override
  String get avatarPickerThatOneIsYours => 'این مال شماست';

  @override
  String get avatarPickerPickAFace => 'انتخاب چهره';

  @override
  String get commonSave => 'ذخیره';

  @override
  String get backupPassphraseMustBeAt =>
      'عبارت عبور باید دست‌کم ۱۲ کاراکتر باشد';

  @override
  String get backupPassphrasesDonTMatch => 'عبارت‌های عبور یکی نیستند';

  @override
  String get backupBackupSavedKeepThe =>
      'نسخه‌ی پشتیبان ذخیره شد · عبارت عبور را امن نگه دارید';

  @override
  String get backupKryfoBackup => 'نسخه‌ی پشتیبان Kryfo';

  @override
  String get backupYourEncryptedKryfoBackup =>
      'نسخه‌ی پشتیبان رمزگذاری‌شده‌ی Kryfo شما. هم این فایل و هم عبارت عبورتان را امن نگه دارید؛ برای بازیابی به هر دو نیاز دارید.';

  @override
  String get backupBackUpKryfo => 'پشتیبان‌گیری از Kryfo';

  @override
  String get backupBackUp => 'پشتیبان‌گیری';

  @override
  String get backupACopyToKeep =>
      'یک نسخه برای نگه داشتن. این گوشی همان‌طور که هست ادامه می‌دهد.';

  @override
  String get backupMoveToAnotherDevice => 'انتقال به دستگاه دیگر';

  @override
  String get backupTheFileTakesThis =>
      'فایل این هویت را با خود می‌برد. همین که ساخته شود، این گوشی از کار می‌ایستد: دیگر چیز تازه‌ای این‌جا نمی‌رسد و هر چه از این‌جا فرستاده شود به دست کسی نمی‌رسد.';

  @override
  String get backupOneEncryptedFileYour =>
      'یک فایل رمزگذاری‌شده: هویت شما، مخاطبانتان، همه‌ی پیام‌ها، و همه‌ی عکس‌ها، پیام‌های صوتی و فایل‌ها. آن را با عبارت عبور در دستگاه دیگر وارد کنید. تا آن موقع هنوز می‌توانید نظرتان را عوض کنید و روی همین گوشی بمانید.';

  @override
  String get backupOneEncryptedFileYourIdentityYour =>
      'یک فایل رمزگذاری‌شده: هویت شما، مخاطبانتان، همه‌ی پیام‌ها، و همه‌ی عکس‌ها، پیام‌های صوتی و فایل‌هایی که همین حالا روی این گوشی است. هر چه بعد از امروز گفته شود در آن نیست، پس هر وقت مهم بود یکی دیگر بسازید. برای بازیابی، هم فایل را لازم دارید و هم عبارت عبور را.';

  @override
  String get backupPassphrase => 'عبارت عبور';

  @override
  String get backupConfirmPassphrase => 'تکرار عبارت عبور';

  @override
  String backupWriting(Object progress) {
    return 'در حال نوشتن… ⁨$progress⁩';
  }

  @override
  String get backupSaveComesAfter =>
      'وقتی فایل آماده شد، انتخاب می‌کنید کجا ذخیره‌اش کنید.';

  @override
  String get backupSaving => 'در حال ذخیره…';

  @override
  String backupSavedIn(String place) {
    return 'نسخه‌ی پشتیبان در ⁨$place⁩ ذخیره شد · عبارت عبور را امن نگه دارید';
  }

  @override
  String get backupNotSaved => 'نسخه‌ی پشتیبان ذخیره نشد. فایل هنوز اینجاست.';

  @override
  String get backupShareInstead => 'هم‌رسانی به‌جای آن';

  @override
  String get backupSavedUnchecked =>
      'نسخه‌ی پشتیبان ذخیره شد، ولی Kryfo نتوانست آن را بررسی کند';

  @override
  String get backupMoveReachedTitle => 'فایل به گوشی جدیدتان رسید؟';

  @override
  String get backupMoveReachedLine =>
      'این گوشی را نگه دارید تا فایل را آنجا باز کنید.';

  @override
  String get backupFinishTheMove => 'پایان انتقال';

  @override
  String get backupNotYet => 'هنوز نه';

  @override
  String get backupCreating => 'در حال ساختن…';

  @override
  String get backupMakeTheFileAnd => 'ساختن فایل و انتقال';

  @override
  String get backupCreateBackup => 'ساختن نسخه‌ی پشتیبان';

  @override
  String get backupNotMade => 'نسخه‌ی پشتیبان ساخته نشد. دوباره امتحان کنید.';

  @override
  String get backupHiddenNotIn => 'گفت‌وگوهای پنهان در آن نیستند.';

  @override
  String get backupHiddenIncluded => 'گفت‌وگوهای پنهان شما هم در آن هستند.';

  @override
  String get backupMoveHiddenStay =>
      'گفت‌وگوهای پنهان روی همین گوشی می‌مانند و همراه آن پاک می‌شوند.';

  @override
  String get backupHiddenGone =>
      'گفت‌وگوهای پنهان شما وقتی Kryfo قفل شد بسته شدند. آن‌ها را با PIN گفت‌وگوهای پنهان باز کنید و از همان‌جا نسخه‌ی پشتیبان بگیرید.';

  @override
  String get blockedBlocked => 'مسدودشده‌ها';

  @override
  String get blockedNoOneIsBlocked => 'کسی مسدود نشده';

  @override
  String get commonUnblock => 'رفع مسدودیت';

  @override
  String get bridgesConnected => 'متصل';

  @override
  String get bridgesFromTheTorProject => 'از پروژه‌ی Tor';

  @override
  String get bridgesPasteFromClipboard => 'جای‌گذاری از بریده‌دان';

  @override
  String bridges1LineSaved(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$countString⁩ خط ذخیره شد',
      one: '⁨$countString⁩ خط ذخیره شد',
    );
    return '$_temp0';
  }

  @override
  String get bridgesWhenYouAskFor =>
      'وقتی پل درخواست می‌کنید، پروژه‌ی Tor نشانی IP شما را می‌بیند. این عادی است: Tor Browser و همه‌ی برنامه‌های Tor همین‌طور پل می‌گیرند، و تنها چیزی که از این می‌فهمند این است که کسی پل خواسته است. چیزی درباره‌ی گفت‌وگوهای شما نمی‌فهمند.';

  @override
  String get bridgesAsking => 'در حال درخواست…';

  @override
  String get cameraNoCameraOnThis => 'این گوشی دوربین ندارد';

  @override
  String get cameraCameraNotAvailable => 'دوربین در دسترس نیست';

  @override
  String get cameraCameraPermissionIsOff => 'اجازه‌ی دوربین خاموش است';

  @override
  String get cameraOpenSettings => 'باز کردن تنظیمات';

  @override
  String get cameraCouldNotStripThat =>
      'حذف فراداده‌ی آن عکس ممکن نشد، کنار گذاشته شد';

  @override
  String get cameraNoPhotoCameOut => 'عکسی گرفته نشد';

  @override
  String get cameraCouldNotStartRecording => 'ضبط شروع نشد';

  @override
  String get cameraTheRecordingWasLost => 'ضبط از دست رفت';

  @override
  String get cameraACopyIsIn => 'یک نسخه در عکس‌هایتان هست';

  @override
  String get cameraCouldNotSaveA => 'ذخیره‌ی یک نسخه روی این گوشی ممکن نشد';

  @override
  String get cameraTooLongForA =>
      'برای یک پیام زیادی طولانی است · حداکثر ۱۵ مگابایت';

  @override
  String get cameraNeverSavedToYour => 'هرگز در عکس‌هایتان ذخیره نمی‌شود';

  @override
  String get cameraNoExifNeverSaved =>
      'بدون EXIF، هرگز در عکس‌هایتان ذخیره نمی‌شود';

  @override
  String get cameraRec => 'ضبط';

  @override
  String get cameraSwitchCamera => 'تعویض دوربین';

  @override
  String cameraClipSMb(Object secs, Object mb) {
    return 'کلیپ · ⁨$secs⁩ ثانیه · ⁨$mb⁩ مگابایت';
  }

  @override
  String get cameraStopRecording => 'توقف ضبط';

  @override
  String get cameraStartRecording => 'شروع ضبط';

  @override
  String get cameraTakeAPhoto => 'گرفتن عکس';

  @override
  String get cameraKeepACopy => 'نگه داشتن یک نسخه';

  @override
  String get cameraUseThis => 'استفاده از این';

  @override
  String get chatYouAreOfflineThis =>
      'آفلاین هستید · وقتی دوباره وصل شوید، خودش فرستاده می‌شود';

  @override
  String get chatStillConnectingToTor =>
      'هنوز در حال اتصال به Tor · خودش فرستاده می‌شود';

  @override
  String chatS(Object seconds) {
    return '⁨$seconds⁩ ثانیه';
  }

  @override
  String chatM(Object seconds) {
    return '⁨$seconds⁩ دقیقه';
  }

  @override
  String chatH(Object seconds) {
    return '⁨$seconds⁩ ساعت';
  }

  @override
  String chatD(Object seconds) {
    return '⁨$seconds⁩ روز';
  }

  @override
  String get chat0s => '۰ ثانیه';

  @override
  String chatHM(Object h, Object m) {
    return '⁨$h⁩:⁨$m⁩ ساعت';
  }

  @override
  String chatMS(Object m, Object s) {
    return '⁨$m⁩:⁨$s⁩ دقیقه';
  }

  @override
  String chatS2(Object s) {
    return '⁨$s⁩ ثانیه';
  }

  @override
  String get chatNewMessages => 'پیام‌های جدید';

  @override
  String chatEarlierMessagesArrived(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$countString⁩ پیام قبلی رسید',
      one: '⁨$countString⁩ پیام قبلی رسید',
    );
    return '$_temp0';
  }

  @override
  String get chatUnsave => 'لغو ذخیره';

  @override
  String get chatForward => 'بازارسال';

  @override
  String get commonShare => 'هم‌رسانی';

  @override
  String get commonCopied => 'کپی شد';

  @override
  String get commonCopy => 'کپی';

  @override
  String get chatUnpin => 'برداشتن سنجاق';

  @override
  String get chatPin => 'سنجاق';

  @override
  String get chatStopSending => 'توقف ارسال';

  @override
  String get chatUnsend => 'پس گرفتن';

  @override
  String get commonEdit => 'ویرایش';

  @override
  String get chatYou => 'شما';

  @override
  String get chatUnsendMessage => 'پس گرفتن پیام';

  @override
  String get chatItDisappearsWithNo =>
      'بدون هیچ ردی ناپدید می‌شود. این کار برگشت ندارد.';

  @override
  String chatThisChatHasPins(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'این گفت‌وگو از قبل ⁨$countString⁩ سنجاق دارد',
      one: 'این گفت‌وگو از قبل ⁨$countString⁩ سنجاق دارد',
    );
    return '$_temp0';
  }

  @override
  String get chatUnpinThisMessage => 'سنجاق این پیام برداشته شود؟';

  @override
  String get chatPinThisMessage => 'این پیام سنجاق شود؟';

  @override
  String get chatItLeavesThePinned =>
      'برای هر دوی شما از فهرست سنجاق‌شده‌ها بیرون می‌رود.';

  @override
  String get chatItGoesUnderThe =>
      'برای هر دوی شما، زیر سنجاق بالای گفت‌وگو قرار می‌گیرد.';

  @override
  String get chatPinIt => 'سنجاق کردن';

  @override
  String get chatNotNow => 'فعلاً نه';

  @override
  String get chatEditMessage => 'ویرایش پیام';

  @override
  String get chat30Seconds => '۳۰ ثانیه';

  @override
  String get chat1Minute => '۱ دقیقه';

  @override
  String get chat5Minutes => '۵ دقیقه';

  @override
  String get chat1Hour => '۱ ساعت';

  @override
  String get chat24Hours => '۲۴ ساعت';

  @override
  String get chatGhostTimer => 'پیام‌های زمان‌دار';

  @override
  String get chatHowLongAfterReading =>
      'پیام‌ها چه مدت پس از خوانده شدن محو شوند؟ پیام‌های شما از لحظه‌ی فرستادن حساب می‌شوند.';

  @override
  String get chatCamera => 'دوربین';

  @override
  String get chatNoExifNeverSaved =>
      'بدون EXIF، هرگز در عکس‌هایتان ذخیره نمی‌شود';

  @override
  String get chatGallery => 'گالری';

  @override
  String get chatVideo => 'ویدیو';

  @override
  String get chatGifFromPhone => 'گیف از گوشی';

  @override
  String get chatFile2 => 'فایل';

  @override
  String get chatAFewSeconds => 'چند ثانیه';

  @override
  String get chatUnderAMinute => 'کمتر از یک دقیقه';

  @override
  String chatRoughlyMin(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'حدود ⁨$countString⁩ دقیقه',
    );
    return '$_temp0';
  }

  @override
  String chatB2(Object b) {
    return '⁨$b⁩ بایت';
  }

  @override
  String chatKb2(Object b) {
    return '⁨$b⁩ کیلوبایت';
  }

  @override
  String chatMb2(Object b) {
    return '⁨$b⁩ مگابایت';
  }

  @override
  String get chatSendThis => 'این فایل فرستاده شود؟';

  @override
  String chatOverTor(Object humanBytes, Object wireEstimate) {
    return '⁨$humanBytes⁩ · ⁨$wireEstimate⁩ از راه Tor';
  }

  @override
  String get chatBigFilesGoOut =>
      'فایل‌های بزرگ در تکه‌های کوچک رمزگذاری‌شده فرستاده می‌شوند، برای همین کمی طول می‌کشد. برنامه را باز نگه دارید تا ارسال ادامه پیدا کند.';

  @override
  String get chatSendIt => 'ارسال';

  @override
  String get chatCouldNotReadThat => 'آن فایل خوانده نشد';

  @override
  String get chatCouldNotCleanThat => 'تمیز کردن آن ویدیو ممکن نشد';

  @override
  String get chatCouldNotCleanThatPictureSend =>
      'تمیز کردن آن تصویر ممکن نشد · آن را به‌صورت عکس بفرستید';

  @override
  String get chatGifTooBig8 => 'گیف بزرگ است · حداکثر ۸ مگابایت';

  @override
  String get chatCouldNotCleanThatGif => 'تمیز کردن آن گیف ممکن نشد';

  @override
  String get chatTorIsNotUp =>
      'Tor هنوز آماده نیست · بدون پیش‌نمایش فرستاده می‌شود';

  @override
  String get chatCouldnTReachIt =>
      'به آن دسترسی نشد · بدون پیش‌نمایش فرستاده می‌شود';

  @override
  String get chatNoTitleCameBack =>
      'عنوانی برنگشت · بدون پیش‌نمایش فرستاده می‌شود';

  @override
  String get chatCouldnTFetchIt =>
      'دریافتش ممکن نشد · بدون پیش‌نمایش فرستاده می‌شود';

  @override
  String get chatNoSignalSessionRe => 'نشست Signal نیست. دوباره جفت کنید';

  @override
  String get chatMessageUnavailable => 'پیام در دسترس نیست';

  @override
  String get chatYou2 => 'شما';

  @override
  String get chatThem => 'او';

  @override
  String get chatVoiceMessage => 'پیام صوتی';

  @override
  String get chatQuotedPhoto => 'عکس';

  @override
  String get chatViewContact => 'دیدن مخاطب';

  @override
  String get chatSharedPhotos => 'عکس‌های مشترک';

  @override
  String chatSharedPhotoCount(int count, Object title) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$countString⁩ عکس',
      one: '⁨$countString⁩ عکس',
    );
    return '$_temp0 · ⁨$title⁩';
  }

  @override
  String get chatUnmuteNotifications => 'باصدا کردن اعلان‌ها';

  @override
  String get chatMuteNotifications => 'بی‌صدا کردن اعلان‌ها';

  @override
  String get chatArchiveChat => 'بایگانی گفت‌وگو';

  @override
  String get chatWallpaper => 'تصویر زمینه';

  @override
  String get chatClearConversation => 'خالی کردن گفت‌وگو';

  @override
  String get chatNoteOnThisContact => 'یادداشت درباره‌ی این مخاطب';

  @override
  String get chatPinToTop => 'سنجاق به بالا';

  @override
  String get chatBlockContact => 'مسدود کردن مخاطب';

  @override
  String get chatUnpinned => 'سنجاق برداشته شد';

  @override
  String get chatPinnedToTop => 'به بالا سنجاق شد';

  @override
  String get chatJustForYouNever =>
      'فقط برای شما. هرگز فرستاده نمی‌شود و هرگز از این گوشی بیرون نمی‌رود.';

  @override
  String get chatAQuietReminder => 'یک یادآوری آرام…';

  @override
  String get chatNoteSaved => 'یادداشت ذخیره شد';

  @override
  String get chatClearThisConversation => 'این گفت‌وگو خالی شود؟';

  @override
  String get chatEveryMessageHereIs =>
      'همه‌ی پیام‌های این‌جا از این گوشی حذف می‌شوند. این کار فقط نسخه‌ی شما را خالی می‌کند و به دستگاه او دست نمی‌زند.';

  @override
  String get chatClear => 'خالی کردن';

  @override
  String get chatBlockThisContact => 'این مخاطب مسدود شود؟';

  @override
  String get chatTheirMessagesStopArriving =>
      'دیگر پیامی از او نمی‌رسد و از گفت‌وگوهایتان ناپدید می‌شود. هرگز به او گفته نمی‌شود. هر وقت خواستید، می‌توانید از تنظیمات رفع مسدودیت کنید.';

  @override
  String get commonBlock => 'مسدود کردن';

  @override
  String get chatSaved => 'ذخیره شد';

  @override
  String get chatRemovedFromSaved => 'از ذخیره‌شده‌ها برداشته شد';

  @override
  String get chatForwardTo => 'بازارسال به';

  @override
  String get chatNoContactsToForward => 'مخاطبی برای بازارسال نیست';

  @override
  String get chatToday => 'امروز';

  @override
  String get chatYesterday => 'دیروز';

  @override
  String get chatThisMessageCanT => 'این پیام را نمی‌توان نشان داد';

  @override
  String get chatJumpToTheNewest => 'رفتن به تازه‌ترین';

  @override
  String get chatBuildingAPrivateRoute =>
      'در حال ساختن مسیری خصوصی · اولین اتصال کند است، بعدی‌ها سریع‌اند. هر چه الان بفرستید در صف می‌ماند و خودش می‌رسد.';

  @override
  String get chatTheNextPhotoYou =>
      'عکس بعدی که می‌فرستید محافظت‌شده باز می‌شود · Kryfo جلوی اسکرین‌شات از آن را می‌گیرد';

  @override
  String get chatPhotoProtectionOff => 'محافظت عکس خاموش';

  @override
  String get chatAcceptToReplyThey =>
      'برای پاسخ دادن بپذیرید. تا وقتی نپذیرفته‌اید، او فقط یک پیام دیگر می‌تواند بفرستد.';

  @override
  String chatIntroducedYouAcceptTo(Object introducer) {
    return 'معرفی از طرف ⁨$introducer⁩. برای پاسخ دادن بپذیرید.';
  }

  @override
  String chatIntroducedYouSayHello(Object vouchNames) {
    return 'معرفی از طرف ⁨$vouchNames⁩. سلام کنید؛ کارت شما هم به دست او رسیده.';
  }

  @override
  String get chatIntroduceTo => 'معرفی به...';

  @override
  String get chatAcceptThemFirst => 'اول او را بپذیرید';

  @override
  String get chatMessageRequest => 'درخواست پیام';

  @override
  String get chatTheyNeedToAccept =>
      'او باید بپذیرد تا بتوانید به گفت‌وگو ادامه دهید.';

  @override
  String get chatWaitingForThemTo => 'در انتظار اینکه درخواستتان را بپذیرد';

  @override
  String get chatTheyMayNotKnow => 'شاید نداند که پذیرفته‌اید';

  @override
  String get chatYouBlockedThisContact => 'این مخاطب را مسدود کرده‌اید';

  @override
  String get chatSupporter => 'هوادار';

  @override
  String get chatEncryptedViaRelay => 'رمزگذاری‌شده · از راه رله';

  @override
  String get chatEncryptedDirect => 'رمزگذاری‌شده · مستقیم';

  @override
  String get chatEncryptedOverTor => 'رمزگذاری‌شده · از راه Tor';

  @override
  String get chatSearchThisChat => 'جست‌وجو در این گفت‌وگو';

  @override
  String get chatContactOptions => 'گزینه‌های مخاطب';

  @override
  String get commonClose => 'بستن';

  @override
  String get chatFindInConversation => 'یافتن در گفت‌وگو';

  @override
  String get chatNoMatches => 'موردی پیدا نشد';

  @override
  String chatOf(int count, int pos) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);
    final intl.NumberFormat posNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String posString = posNumberFormat.format(pos);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '*⁨$posString⁩* از ⁨$countString⁩ مورد',
      one: '*⁨$posString⁩* از ⁨$countString⁩ مورد',
    );
    return '$_temp0';
  }

  @override
  String get chatPreviousMatch => 'مورد قبلی';

  @override
  String get chatNextMatch => 'مورد بعدی';

  @override
  String get chatPhotoUnavailable => 'عکس در دسترس نیست';

  @override
  String get chatDelivered => 'رسید';

  @override
  String get chatEdited => 'ویرایش‌شده';

  @override
  String get chatFailedTapToRetry => 'ناموفق · برای تلاش دوباره بزنید';

  @override
  String get chatReplyingTo => 'پاسخ به او';

  @override
  String get chatReplyingToYourself => 'پاسخ به خودتان';

  @override
  String get chatReply => 'پاسخ';

  @override
  String get chatSayHi => 'سلام کنید.';

  @override
  String get chatJustTheTwoOf => 'فقط شما دو نفر، با رمزگذاری سرتاسری.';

  @override
  String get chatSayHiSoThey => 'سلام کنید تا شما را ببیند';

  @override
  String get chatTheyWonTKnow =>
      'تا اولین پیامتان به دستش نرسد، نمی‌داند که او را اضافه کرده‌اید.';

  @override
  String get chatWave => 'دست تکان دهید';

  @override
  String get chatMicPermissionNeeded => 'اجازه‌ی میکروفون لازم است';

  @override
  String get chatTheMicWouldNot => 'میکروفون روشن نشد. دوباره امتحان کنید';

  @override
  String get chatReleaseToCancel => 'برای لغو رها کنید';

  @override
  String get chatVoiceHiddenSlideTo => 'صدا تغییر کرده · برای لغو بکشید';

  @override
  String get chatSlideToCancel => 'برای لغو بکشید';

  @override
  String get chatGhostMode => 'پیام‌های زمان‌دار';

  @override
  String chatMessagesBurnAfter(Object humanBurn) {
    return 'پس از ⁨$humanBurn⁩ محو می‌شوند';
  }

  @override
  String get chatTimedMessages => 'پیام‌های زمان‌دار';

  @override
  String get chatOpenTheCamera => 'باز کردن دوربین';

  @override
  String get chatAttachAPhoto => 'پیوست عکس';

  @override
  String get chatMessage => 'پیام';

  @override
  String get commonSend => 'ارسال';

  @override
  String get chatNoPhotosInThis => 'هنوز عکسی در این گفت‌وگو نیست';

  @override
  String get chatHoldToRecord => 'برای ضبط پیام صوتی نگه دارید';

  @override
  String get chatSecurityCodeChanged => 'کد امنیتی تغییر کرد';

  @override
  String get chatCompareTitle => 'شماره‌ی امنیتی را مقایسه کنید';

  @override
  String chatCompareLine(Object peerName) {
    return 'سه واژه را می‌شود کپی کرد. برای اینکه بدانید این گفت‌وگو واقعاً با ⁨$peerName⁩ است، شماره‌ی امنیتی را با او مقایسه کنید، حضوری یا در یک تماس.';
  }

  @override
  String get chatCompareLater => 'بعداً';

  @override
  String get chatCompareFolded => 'شماره‌ی امنیتی هنوز مقایسه نشده';

  @override
  String get chatCompareNow => 'مقایسه';

  @override
  String get chatCompareDismiss => 'پنهان کردن';

  @override
  String chatKeyHeldLine(Object peerName) {
    return 'شما پیش‌تر ⁨$peerName⁩ را تأیید کرده بودید. تا وقتی شماره‌ی تازه را بررسی نکنید یا کلید تازه را نپذیرید، چیزی فرستاده نمی‌شود. پیام‌های او همچنان می‌رسد.';
  }

  @override
  String get chatCheckTheNumber => 'بررسی شماره';

  @override
  String get chatAcceptNewKey => 'پذیرفتن کلید تازه';

  @override
  String get chatAcceptNewKeyTitle => 'کلید تازه‌اش را بپذیرید؟';

  @override
  String chatAcceptNewKeyLine(Object peerName) {
    return 'در این صورت Kryfo بدون بررسی به کلید تازه می‌فرستد و ⁨$peerName⁩ دیگر تأییدشده نشان داده نمی‌شود. هر وقت بخواهید می‌توانید دوباره تأییدش کنید.';
  }

  @override
  String chatMayHaveReinstalledOr(Object peerName) {
    return 'شاید ⁨$peerName⁩ برنامه را دوباره نصب کرده باشد، یا ممکن است کسی خودش را جای او جا بزند. برای اطمینان، شماره‌های امنیتی را مقایسه کنید.';
  }

  @override
  String get chatOk => 'باشه';

  @override
  String get chatVerify => 'تأیید';

  @override
  String get cleanKryfoCanTClean =>
      'Kryfo هنوز نمی‌تواند این نوع فایل را تمیز کند.';

  @override
  String get cleanThisIsAMotion => 'این یک عکس متحرک است.';

  @override
  String get cleanThisPictureIsToo =>
      'این تصویر برای تمیز کردن در این‌جا خیلی بزرگ است.';

  @override
  String get cleanThisFileIsDamaged => 'این فایل آسیب دیده یا ناقص است.';

  @override
  String get cleanKryfoCouldNotMake => 'Kryfo نتوانست این یکی را تمیز کند.';

  @override
  String get cleanNotEnoughRoomOn => 'فضای کافی روی گوشی نیست.';

  @override
  String get cleanKryfoCouldNotOpen => 'Kryfo نتوانست آن فایل را باز کند.';

  @override
  String get cleanItCleansJpegPng =>
      'فایل‌های JPEG، PNG، WebP، HEIC، AVIF، GIF، MP4 و MOV را تمیز می‌کند. چیزی تغییر نکرد.';

  @override
  String get cleanItHoldsAShort =>
      'کنار تصویر یک ویدیوی کوتاه دارد، و Kryfo هنوز نمی‌تواند آن بخش را تمیز کند. حالت متحرک را در دوربینتان خاموش کنید، یا از آن اسکرین‌شات بفرستید.';

  @override
  String get cleanPicturesOver64Mb =>
      'تصویرهای بزرگ‌تر از ۶۴ مگابایت روی گوشی تمیز نمی‌شوند. چیزی تغییر نکرد.';

  @override
  String get cleanKryfoCouldNotRead =>
      'Kryfo نتوانست آن را تا آخر بخواند، پس آن را تمیز نمی‌نامد. نسخه‌ای ساخته نشد.';

  @override
  String get cleanSomethingInsideIsOf =>
      'چیزی در آن هست که Kryfo نمی‌داند چطور حذفش کند، پس نسخه‌ای ساخته نشد.';

  @override
  String get cleanFreeSomeSpaceAnd =>
      'کمی فضا خالی کنید و دوباره امتحان کنید. چیزی تغییر نکرد.';

  @override
  String get cleanTheAppThatShared =>
      'شاید برنامه‌ای که آن را هم‌رسانی کرده، پسش گرفته باشد. دوباره هم‌رسانی‌اش کنید.';

  @override
  String get cleanNoAppOnThis => 'هیچ برنامه‌ای روی این گوشی فایل را نگرفت.';

  @override
  String get cleanCouldNotSaveIt => 'ذخیره نشد. ببینید گوشی جا دارد یا نه.';

  @override
  String get cleanTheOriginalIsGone =>
      'نسخه‌ی اصلی حذف شد. نسخه‌ی تمیز می‌ماند.';

  @override
  String get cleanAndroidWouldNotDelete =>
      'اندروید آن را حذف نکرد. خودتان آن را از گالری حذف کنید.';

  @override
  String get cleanCleanCopy => 'نسخه‌ی تمیز';

  @override
  String get cleanShareCleanCopy => 'هم‌رسانی نسخه‌ی تمیز';

  @override
  String get cleanSaveToGallery => 'ذخیره در گالری';

  @override
  String get commonStop => 'توقف';

  @override
  String get cleanReadingTheFile => 'خواندن فایل';

  @override
  String get cleanCleaning => 'در حال تمیز کردن';

  @override
  String cleanOf(Object prettySize, Object prettySize2) {
    return '⁨$prettySize⁩ از ⁨$prettySize2⁩';
  }

  @override
  String get cleanEverythingStaysOnThis => 'همه‌چیز روی این گوشی می‌ماند.';

  @override
  String get cleanAlreadyClean => 'از قبل تمیز است.';

  @override
  String get cleanClean => 'تمیز شد.';

  @override
  String get cleanThereWasNothingTo => 'چیزی برای یافتن نبود.';

  @override
  String get cleanNothingLeftToFind => 'دیگر چیزی برای یافتن نمانده.';

  @override
  String get cleanSameVideoSameQuality => 'همان ویدیو، همان کیفیت';

  @override
  String get cleanSamePictureSameQuality => 'همان تصویر، همان کیفیت';

  @override
  String cleanRemoved(Object label) {
    return '⁨$label⁩، حذف شد';
  }

  @override
  String get cleanRemoved2 => 'حذف شد';

  @override
  String get cleanWithTheLocationInside =>
      'با موقعیت مکانی درونش. هر کس آن را به دست بیاورد، خیابانتان را هم دارد.';

  @override
  String get cleanWithEverythingItKnew => 'با هر آنچه می‌دانست، هنوز درونش.';

  @override
  String get cleanOriginal => 'اصلی';

  @override
  String get cleanClean2 => 'تمیز';

  @override
  String get cleanSavedToYourGallery => 'در گالری‌تان ذخیره شد.';

  @override
  String cleanTheOriginalIsStill(Object what) {
    return 'نسخه‌ی اصلی هم هنوز آن‌جاست، ⁨$what⁩';
  }

  @override
  String cleanTheOriginalIsStillWhereIt(Object what) {
    return 'نسخه‌ی اصلی هنوز همان‌جایی است که بود، ⁨$what⁩ Kryfo نمی‌تواند از این‌جا حذفش کند، پس آن را در برنامه‌ای که از آن آمده حذف کنید.';
  }

  @override
  String get cleanDeleteTheOriginal => 'حذف نسخه‌ی اصلی';

  @override
  String get cleanKeepBoth => 'نگه داشتن هر دو';

  @override
  String get commonDone => 'تمام';

  @override
  String get cleanAndroidWillAskYou => 'اندروید از شما تأیید می‌خواهد';

  @override
  String get contactYourNameForThem => 'نام مستعار';

  @override
  String get contactStaysOnThisPhone =>
      'روی این گوشی می‌ماند. او هرگز آن را نمی‌بیند.';

  @override
  String get contactClear => 'حذف';

  @override
  String get contactMessage => 'پیام';

  @override
  String get contactKeysVerified => 'کلیدها تأییدشده';

  @override
  String get contactVerifyKeys => 'تأیید کلیدها';

  @override
  String get contactVouches => 'توصیه‌ها';

  @override
  String get contactUnmute => 'باصدا کردن';

  @override
  String get contactMute => 'بی‌صدا کردن';

  @override
  String get contactUnpin => 'برداشتن سنجاق';

  @override
  String get contactPinToTop => 'سنجاق به بالا';

  @override
  String get contactArchive => 'بایگانی';

  @override
  String get contactOutOfTheList => 'از فهرست بیرون می‌رود تا دوباره بنویسد';

  @override
  String contactBlock(Object name) {
    return '⁨$name⁩ مسدود شود؟';
  }

  @override
  String get contactTheirMessagesStopArriving =>
      'دیگر پیامی از او نمی‌رسد. به او گفته نمی‌شود.';

  @override
  String get contactDeleteChat => 'حذف گفت‌وگو';

  @override
  String get contactMessagesAndContactGone =>
      'پیام‌ها و مخاطب از این گوشی حذف می‌شوند';

  @override
  String get contactDeleteThisChat => 'این گفت‌وگو حذف شود؟';

  @override
  String get contactEveryMessageAndThe =>
      'همه‌ی پیام‌ها و خود مخاطب از این گوشی حذف می‌شوند. چیزی برای او فرستاده نمی‌شود.';

  @override
  String get commonDelete => 'حذف';

  @override
  String get contactDeleted => 'حذف شد';

  @override
  String get contactToday => 'امروز';

  @override
  String contactD(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$count⁩ روز',
    );
    return '$_temp0';
  }

  @override
  String contactMo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$count⁩ ماه',
    );
    return '$_temp0';
  }

  @override
  String contactY(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$count⁩ سال',
    );
    return '$_temp0';
  }

  @override
  String get contactVerified => 'تأییدشده';

  @override
  String get contactChatting => 'سابقه‌ی گفت‌وگو';

  @override
  String get contactNothingSharedYet => 'هنوز چیزی هم‌رسانی نشده';

  @override
  String contactSharedMedia(Object count) {
    return 'رسانه‌های مشترک · ⁨$count⁩';
  }

  @override
  String get donateBitcoin => 'Bitcoin';

  @override
  String get donateText => '₿';

  @override
  String get donateBadgeUnlocks => 'نشان باز می‌شود';

  @override
  String get donateMonero => 'Monero';

  @override
  String get donateManualNoBadge => 'دستی · بدون نشان';

  @override
  String get donateSolana => 'Solana';

  @override
  String get donateEthereum => 'Ethereum';

  @override
  String get donateText2 => 'Ξ';

  @override
  String donateYourEarlierBitcoinPayment(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter': 'پرداخت bitcoin قبلی شما دیده شد · نشان هوادار باز شد',
      'patron': 'پرداخت bitcoin قبلی شما دیده شد · نشان حامی باز شد',
      'guardian': 'پرداخت bitcoin قبلی شما دیده شد · نشان نگهبان باز شد',
      'other': 'پرداخت bitcoin قبلی شما دیده شد · نشان هوادار باز شد',
    });
    return '$_temp0';
  }

  @override
  String get donateSupport => 'حمایت';

  @override
  String get donateKeepKryfo => 'Kryfo را *مستقل* نگه دارید';

  @override
  String get donateNoAdsNoInvestors =>
      'نه تبلیغ، نه سرمایه‌گذار، نه چیزی برای فروش. با کمک دوستدارانش می‌چرخد.';

  @override
  String get donateBackItAnonymouslyBadge =>
      'ناشناس حمایت کنید. نشان اختیاری است.\n*همه‌ی امکانات حریم خصوصی رایگان است.*';

  @override
  String get donateAuditTitle => 'به تأمین هزینهٔ یک ممیزی امنیتی کمک کنید';

  @override
  String get donateAuditLine =>
      'کمک‌های مالی اینجا صرف یک ممیزی مستقل می‌شود. گزارش کامل آن عمومی خواهد شد.';

  @override
  String donateAddressCheckItAgainst(Object coinName) {
    return 'نشانی ⁨$coinName⁩ · آن را با کیف پولتان تطبیق دهید';
  }

  @override
  String get donateAddressCopiedClearsIn =>
      'نشانی کپی شد · ۶۰ ثانیه‌ی دیگر از بریده‌دان حذف می‌شود';

  @override
  String get donateCopyAddress => 'کپی نشانی';

  @override
  String get donateBitcoinIsVerifiedBy =>
      'Bitcoin با گره خودمان تأیید می‌شود، پس به محض رسیدن پرداخت، نشانتان خودش باز می‌شود.';

  @override
  String get donateWeCanTVerify =>
      'نمی‌توانیم این زنجیره را بدون پرسیدن درباره‌ی شما از یک سرویس بیرونی تأیید کنیم، پس این کار را نمی‌کنیم. اگر خواستید بفرستید. با این کار نشان باز نمی‌شود.';

  @override
  String get donateBitcoinBadgesNeedOnion =>
      'نشان‌های bitcoin حالت onion لازم دارند';

  @override
  String get donateSwitchToOnion => 'رفتن به onion';

  @override
  String get donatePayWithBitcoin => 'پرداخت با bitcoin  ←';

  @override
  String get donateBadgesStartAt20 => 'نشان‌ها از ۲۰ دلار';

  @override
  String get donateReachingThePaymentService =>
      'در حال رسیدن به سرویس پرداخت از راه Tor…';

  @override
  String get donateThisCanTakeUp => 'ممکن است تا یک دقیقه طول بکشد';

  @override
  String donateSThisCanTake(Object waited) {
    return '⁨$waited⁩ ثانیه · ممکن است تا یک دقیقه طول بکشد';
  }

  @override
  String get donateUseTheAddressInstead => 'به‌جایش از نشانی استفاده کنید';

  @override
  String get donateThePaymentServiceIs =>
      'سرویس پرداخت یک onion است و فقط حالت onion به آن می‌رسد. چیزی فرستاده نشد.';

  @override
  String get donateTorWasSlowTo =>
      'Tor برای رسیدن به سرویس پرداخت کند بود. می‌توانید به نشانی پایین کمک مالی کنید، فقط نشانتان خودکار باز نمی‌شود. برای نشان، بعداً دوباره امتحان کنید.';

  @override
  String get donateThePaymentServiceIsHavingTrouble =>
      'سرویس پرداخت الان به مشکل خورده. باز هم می‌توانید به نشانی پایین کمک مالی کنید، فقط نشانتان خودکار باز نمی‌شود. برای نشان، بعداً دوباره امتحان کنید.';

  @override
  String get commonTryAgain => 'تلاش دوباره';

  @override
  String donateBtc(Object btc) {
    return '⁨$btc⁩ BTC';
  }

  @override
  String donateSendExactlyThisAmount(Object fmtLeft) {
    return 'دقیقاً همین مقدار را بفرستید · ⁨$fmtLeft⁩ دیگر منقضی می‌شود';
  }

  @override
  String get donateOpenWallet => 'باز کردن کیف پول';

  @override
  String get donateThisScreenUpdatesItself =>
      'به محض دیده شدن پرداختتان، این صفحه خودش به‌روز می‌شود.\nبازش نگه دارید. چیزی ذخیره نمی‌شود، چیزی شما را شناسایی نمی‌کند.';

  @override
  String get donateWatchingTheChainFor =>
      'در حال پاییدن زنجیره برای پرداخت شما';

  @override
  String get donateThisInvoiceExpired => 'این صورت‌حساب منقضی شد';

  @override
  String get donateInvoicesTimeOutIf =>
      'صورت‌حساب‌ها مهلت دارند. اگر پرداخت را فرستاده‌اید، این صفحه را باز نگه دارید: تا مدتی هر دقیقه دوباره از سرویس می‌پرسیم، و دفعه‌ی بعد هم که بخش حمایت را باز کنید. هر وقت خواستید یکی تازه بسازید.';

  @override
  String get donateNewInvoice => 'صورت‌حساب تازه';

  @override
  String get donateIPaidCheckAgain => 'پرداخت کردم، دوباره بررسی شود';

  @override
  String get donateNoWallet =>
      'هیچ برنامه‌ای روی این گوشی پیوندهای bitcoin را باز نمی‌کند. به‌جایش نشانی را کپی کنید.';

  @override
  String get donateChecking => 'در حال بررسی…';

  @override
  String get donateNotSeenYet =>
      'هنوز دیده نشده. ممکن است چند دقیقه طول بکشد تا پرداخت نشان داده شود.';

  @override
  String get donatePaymentConfirmed => 'پرداخت تأیید شد';

  @override
  String get donateThankYouForKeeping =>
      'ممنون که Kryfo را مستقل نگه می‌دارید.';

  @override
  String donateVerifiedOnChainYou(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter':
          'روی زنجیره تأیید شد. حالا شما هوادار هستید. هیچ‌کس نمی‌تواند این را از شما بگیرد.',
      'patron':
          'روی زنجیره تأیید شد. حالا شما حامی هستید. هیچ‌کس نمی‌تواند این را از شما بگیرد.',
      'guardian':
          'روی زنجیره تأیید شد. حالا شما نگهبان هستید. هیچ‌کس نمی‌تواند این را از شما بگیرد.',
      'other':
          'روی زنجیره تأیید شد. حالا شما هوادار هستید. هیچ‌کس نمی‌تواند این را از شما بگیرد.',
    });
    return '$_temp0';
  }

  @override
  String get donateWearMyBadge => 'نمایش نشانم';

  @override
  String get donateJustGladToHelp => 'فقط خوشحالم که کمک کردم';

  @override
  String get gettingMessagesGettingMessages => 'دریافت پیام‌ها';

  @override
  String get gettingMessagesHowNewMessagesReach =>
      'پیام‌های تازه چطور به این گوشی می‌رسند. هر وقت خواستید می‌توانید عوضش کنید.';

  @override
  String get gettingMessagesAlwaysOn => 'همیشه روشن';

  @override
  String get gettingMessagesMostPrivate => 'خصوصی‌ترین';

  @override
  String get gettingMessagesMessagesArriveInstantlyNothing =>
      'پیام‌ها فوراً می‌رسند. هیچ چیز از Tor بیرون نمی‌رود. بیشترین مصرف باتری.';

  @override
  String get gettingMessagesCheckIns => 'سرکشی دوره‌ای';

  @override
  String get gettingMessagesLightest => 'سبک‌ترین';

  @override
  String get gettingMessagesKryfoLooksForMessages =>
      'Kryfo هر ۱۵ دقیقه دنبال پیام می‌گردد. باتری کمتری مصرف می‌کند، اما پیام‌ها ممکن است دیر برسند.';

  @override
  String get gettingMessagesOnTheLockScreen => 'روی صفحه‌ی قفل';

  @override
  String get gettingMessagesHideMessagePreview => 'پنهان کردن پیش‌نمایش پیام';

  @override
  String get gettingMessagesAGenericAlertWith =>
      'یک اعلان کلی، بدون فرستنده و بدون متن پیام';

  @override
  String get gettingMessagesShowsMessageTextIn =>
      'متن پیام را در اعلان‌ها نشان می‌دهد، حتی وقتی Kryfo قفل است.';

  @override
  String get gettingMessagesWhenThePhoneSits =>
      'وقتی گوشی بی‌حرکت می‌ماند، اندروید فاصله‌ی سرکشی‌ها را بیشتر می‌کند. خط بالا آخرین سرکشی واقعی را نشان می‌دهد. تا وقتی Kryfo باز است، متصل می‌ماند.';

  @override
  String get groupChatJumpToTheNewest => 'رفتن به تازه‌ترین';

  @override
  String get groupChatYou => 'شما';

  @override
  String get groupChatVoiceMessage => 'پیام صوتی';

  @override
  String get groupChatQuotedPhoto => 'عکس';

  @override
  String get groupChatMessageUnavailable => 'پیام در دسترس نیست';

  @override
  String get groupChatTorIsNotUp =>
      'Tor هنوز آماده نیست · بدون پیش‌نمایش فرستاده می‌شود';

  @override
  String get groupChatCouldnTReachIt =>
      'به آن دسترسی نشد · بدون پیش‌نمایش فرستاده می‌شود';

  @override
  String get groupChatNoTitleCameBack =>
      'عنوانی برنگشت · بدون پیش‌نمایش فرستاده می‌شود';

  @override
  String get groupChatCouldnTFetchIt =>
      'دریافتش ممکن نشد · بدون پیش‌نمایش فرستاده می‌شود';

  @override
  String get groupChatCamera => 'دوربین';

  @override
  String get groupChatGallery => 'گالری';

  @override
  String get groupChatVideo => 'ویدیو';

  @override
  String get groupChatGifFromPhone => 'گیف از گوشی';

  @override
  String get groupChatFile => 'فایل';

  @override
  String get groupChatCouldNotReadThat => 'آن فایل خوانده نشد';

  @override
  String get groupChatGifTooBig8 => 'گیف بزرگ است · حداکثر ۸ مگابایت';

  @override
  String get groupChatCouldNotCleanThat => 'تمیز کردن آن گیف ممکن نشد';

  @override
  String get groupChatCouldNotCleanThatVideo => 'تمیز کردن آن ویدیو ممکن نشد';

  @override
  String get groupChatCouldNotCleanThatPictureSend =>
      'تمیز کردن آن تصویر ممکن نشد · آن را به‌صورت عکس بفرستید';

  @override
  String get groupChat30Seconds => '۳۰ ثانیه';

  @override
  String get groupChat1Minute => '۱ دقیقه';

  @override
  String get groupChat5Minutes => '۵ دقیقه';

  @override
  String get groupChat1Hour => '۱ ساعت';

  @override
  String get groupChat24Hours => '۲۴ ساعت';

  @override
  String get groupChatBurnTimer => 'پیام‌های زمان‌دار';

  @override
  String get groupChatNewMessagesDisappearOnceRead =>
      'پیام‌های جدید این مدت پس از خوانده شدن محو می‌شوند. پیام‌های شما از لحظه‌ی فرستادن حساب می‌شوند.';

  @override
  String get groupChatToday => 'امروز';

  @override
  String get groupChatYesterday => 'دیروز';

  @override
  String get groupChatYou2 => 'شما';

  @override
  String groupChatThisChatHasPins(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'این گفت‌وگو از قبل ⁨$countString⁩ سنجاق دارد',
      one: 'این گفت‌وگو از قبل ⁨$countString⁩ سنجاق دارد',
    );
    return '$_temp0';
  }

  @override
  String get groupChatUnpinThisMessage => 'سنجاق این پیام برداشته شود؟';

  @override
  String get groupChatPinThisMessage => 'این پیام سنجاق شود؟';

  @override
  String get groupChatItLeavesThePinned =>
      'برای همه‌ی اعضا از فهرست سنجاق‌شده‌ها بیرون می‌رود.';

  @override
  String get groupChatItGoesUnderThe =>
      'برای همه‌ی اعضا، زیر سنجاق بالای گفت‌وگو قرار می‌گیرد.';

  @override
  String get groupChatUnpin => 'برداشتن سنجاق';

  @override
  String get groupChatPinIt => 'سنجاق کردن';

  @override
  String get groupChatNotNow => 'فعلاً نه';

  @override
  String get groupChatSaved => 'ذخیره شد';

  @override
  String get groupChatRemovedFromSaved => 'از ذخیره‌شده‌ها برداشته شد';

  @override
  String get groupChatForwardTo => 'بازارسال به';

  @override
  String get groupChatNoContactsToForward => 'مخاطبی برای بازارسال نیست';

  @override
  String get groupChatEditMessage => 'ویرایش پیام';

  @override
  String get groupChatUnsendMessage => 'پس گرفتن پیام';

  @override
  String get groupChatItDisappearsWithNo =>
      'بدون هیچ ردی ناپدید می‌شود. این کار برگشت ندارد.';

  @override
  String get groupChatUnsend => 'پس گرفتن';

  @override
  String groupChatThisRoomAndEverything(Object expiryWords) {
    return 'این اتاق و هر چه در آن است، ⁨$expiryWords⁩ دیگر ناپدید می‌شود';
  }

  @override
  String groupChatGhostModeOnBurns(Object fmtBurn) {
    return 'پیام‌های زمان‌دار · پس از ⁨$fmtBurn⁩ محو می‌شوند';
  }

  @override
  String get groupChatGroupCreatedSayHi => 'گروه ساخته شد. سلام کنید.';

  @override
  String get groupChatNoMessagesYet => 'هنوز پیامی نیست.';

  @override
  String get groupChatEveryoneHereReads =>
      'همه‌ی کسانی که اینجا هستند نوشته‌هایت را می‌خوانند.';

  @override
  String get groupChatNobodyHereYet => 'هنوز کسی اینجا نیست.';

  @override
  String get groupChatShareTheRoomLink =>
      'پیوند اتاق را به اشتراک بگذار. هر کس بپیوندد، از آن به بعد نوشته‌ها را می‌خواند.';

  @override
  String get groupChatNobodyToReadIt => 'کس دیگری اینجا نیست که آن را بخواند.';

  @override
  String get groupChatThisMessageCanT => 'این پیام را نمی‌توان نشان داد';

  @override
  String groupChatS(Object s) {
    return '⁨$s⁩ ثانیه';
  }

  @override
  String groupChatM(Object s) {
    return '⁨$s⁩ دقیقه';
  }

  @override
  String groupChatH(Object s) {
    return '⁨$s⁩ ساعت';
  }

  @override
  String groupChatD(Object s) {
    return '⁨$s⁩ روز';
  }

  @override
  String groupChatHere(int count, Object time) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$time⁩ · ⁨$countString⁩ نفر حاضر',
    );
    return '$_temp0';
  }

  @override
  String groupChatMembers(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$countString⁩ عضو',
      one: '⁨$countString⁩ عضو',
    );
    return '$_temp0';
  }

  @override
  String get groupChatSearchThisChat => 'جست‌وجو در این گفت‌وگو';

  @override
  String groupChatReplyingTo(Object name) {
    return 'پاسخ به ⁨$name⁩';
  }

  @override
  String get groupChatReplyingToYou => 'پاسخ به شما';

  @override
  String get groupChatTimedMessages => 'پیام‌های زمان‌دار';

  @override
  String get groupChatOpenTheCamera => 'باز کردن دوربین';

  @override
  String get groupChatAttachAPhoto => 'پیوست عکس';

  @override
  String get groupChatMessage => 'پیام';

  @override
  String get groupChatSupporter => 'هوادار';

  @override
  String get groupChatEdited => 'ویرایش‌شده';

  @override
  String get groupChatTapToRetry => '! برای تکرار بزنید';

  @override
  String groupChatFileReach(int have, int count) {
    final intl.NumberFormat haveNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String haveString = haveNumberFormat.format(have);
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      have,
      locale: localeName,
      other: 'فرستاده شد · ⁨$haveString⁩ از ⁨$countString⁩ نفر دریافت کرده‌اند',
      one: 'فرستاده شد · ⁨$haveString⁩ از ⁨$countString⁩ نفر دریافت کرده',
      zero: 'فرستاده شد · در راه',
    );
    return '$_temp0';
  }

  @override
  String groupChatFileGaveUp(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'فرستاده شد · ⁨$countString⁩ نفر دریافت نکردند',
      one: 'فرستاده شد · ⁨$countString⁩ نفر دریافت نکرد',
    );
    return '$_temp0';
  }

  @override
  String get groupChatReply => 'پاسخ';

  @override
  String get groupChatPin => 'سنجاق';

  @override
  String get groupChatUnsave => 'لغو ذخیره';

  @override
  String get groupChatForward => 'بازارسال';

  @override
  String get groupInfoGroup => 'گروه';

  @override
  String get groupInfoRenameGroup => 'تغییر نام گروه';

  @override
  String get groupInfoRename => 'تغییر نام';

  @override
  String get groupInfoNoContactsToAdd => 'مخاطبی برای افزودن نیست';

  @override
  String get groupInfoCouldNotAdd => 'افزودن ممکن نشد';

  @override
  String groupInfoRemove(Object haloId) {
    return '⁨$haloId⁩ از گروه حذف شود؟';
  }

  @override
  String get groupInfoTheyWillStopReceiving =>
      'دیگر پیامی از این گروه دریافت نمی‌کند.';

  @override
  String get groupInfoResetLink => 'بازنشانی پیوند';

  @override
  String get groupInfoResetTheRoomLink => 'پیوند اتاق بازنشانی شود؟';

  @override
  String get groupInfoResetLinkLine =>
      'پیوند قبلی دیگر کار نمی‌کند. کسانی که در اتاق هستند می‌مانند و پیوند تازه را می‌گیرند.';

  @override
  String get groupInfoRemoveRoomLine =>
      'او می‌تواند با پیوند اتاق دوباره بپیوندد. پیوند را بازنشانی کنید تا بیرون بماند. کسانی که هنوز در اتاق هستند پیوند تازه را می‌گیرند.';

  @override
  String get groupInfoRemoveAndResetLink => 'حذف و بازنشانی پیوند';

  @override
  String get groupInfoCouldNotResetLink => 'پیوند بازنشانی نشد';

  @override
  String get roomLinkNewLinkTheOld =>
      'پیوند تازه. پیوند قبلی دیگر کار نمی‌کند.';

  @override
  String appGroupHoldsUpTo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'هر گروه حداکثر ⁨$countString⁩ نفر جا دارد',
      one: 'هر گروه حداکثر ⁨$countString⁩ نفر جا دارد',
    );
    return '$_temp0';
  }

  @override
  String get commonRemove => 'حذف';

  @override
  String get groupInfoClearThisConversation => 'این گفت‌وگو خالی شود؟';

  @override
  String get groupInfoEveryMessageHereIs =>
      'همه‌ی پیام‌های این‌جا از این گوشی حذف می‌شوند. این کار فقط نسخه‌ی شما را خالی می‌کند، بقیه‌ی اعضا نسخه‌ی خودشان را نگه می‌دارند.';

  @override
  String get groupInfoClear => 'خالی کردن';

  @override
  String get groupInfoConversationCleared => 'گفت‌وگو خالی شد';

  @override
  String get groupInfoLeaveRoom => 'ترک اتاق؟';

  @override
  String get groupInfoLeaveGroup => 'ترک گروه؟';

  @override
  String get groupInfoEverythingInItIs =>
      'همه‌چیزِ آن همین حالا از این گوشی پاک می‌شود، و کلیدی که این‌جا به کار بردید برای همیشه از بین می‌رود.';

  @override
  String groupChatYouWereRemovedFrom(Object name) {
    return 'شما از ⁨$name⁩ حذف شدید';
  }

  @override
  String get groupInfoLeaveGroupLine =>
      'دیگر پیام‌هایش را دریافت نمی‌کنید و همه‌چیزِ آن از این گوشی پاک می‌شود.';

  @override
  String get groupInfoLeaveGroupAdmin =>
      'دیگر پیام‌هایش را دریافت نمی‌کنید و همه‌چیزِ آن از این گوشی پاک می‌شود. شما مدیر آن هستید، پس بعد از رفتن شما هیچ‌کس نمی‌تواند اعضا را تغییر دهد یا نامش را عوض کند.';

  @override
  String get groupInfoLeaveRoomMaker =>
      'همه‌چیزِ آن همین حالا از این گوشی پاک می‌شود، و کلیدی که این‌جا به کار بردید برای همیشه از بین می‌رود. این اتاق را شما ساختید، پس پیوندش دیگر کسی را راه نمی‌دهد.';

  @override
  String get groupInfoLeave => 'ترک کردن';

  @override
  String get groupInfoGroupInfo => 'اطلاعات گروه';

  @override
  String groupInfo1Member(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$countString⁩ عضو',
      one: '⁨$countString⁩ عضو',
    );
    return '$_temp0';
  }

  @override
  String get groupInfoAdmin => 'مدیر';

  @override
  String get groupInfoMembers2 => 'اعضا';

  @override
  String get groupInfoInvite => 'دعوت';

  @override
  String get commonAdd => 'افزودن';

  @override
  String get groupInfoYou => 'شما';

  @override
  String get groupInfoRemoveFromGroup => 'حذف از گروه';

  @override
  String get groupInfoWallpaper => 'تصویر زمینه';

  @override
  String get groupInfoSharedMedia => 'رسانه‌های مشترک';

  @override
  String get groupInfoClearConversation => 'خالی کردن گفت‌وگو';

  @override
  String get groupInfoLeaveRoom2 => 'ترک اتاق';

  @override
  String get groupInfoLeaveGroup2 => 'ترک گروه';

  @override
  String get groupInfoAddMembers => 'افزودن اعضا';

  @override
  String groupInfoAdd(Object pickedLength) {
    return 'افزودن ⁨$pickedLength⁩';
  }

  @override
  String handleYouAre(Object h) {
    return 'شما ⁦@$h⁩ هستید';
  }

  @override
  String get handleHandleDeletedThePage =>
      'نام کاربری حذف شد · صفحه دیگر وجود ندارد';

  @override
  String get handlePublicHandle => 'نام کاربری عمومی';

  @override
  String get handleOptionalYourThreeWords =>
      'اختیاری است. سه واژه‌ی شما در هر حال کار می‌کند.';

  @override
  String get handleWren => 'bolbol';

  @override
  String get handleALineAboutYou => 'یک خط درباره‌ی شما · اختیاری';

  @override
  String get handleClaiming => 'در حال ثبت…';

  @override
  String get handleClaimThisHandle => 'ثبت این نام کاربری';

  @override
  String get handleAnyoneWithThisLink =>
      'هر کس این پیوند را داشته باشد می‌تواند با شما گفت‌وگوی خصوصی شروع کند. این پیوند دعوت شما را با خود دارد و هیچ چیز دیگری را.';

  @override
  String get handleLinkCopied => 'پیوند کپی شد';

  @override
  String get handleDeleteThisHandle => 'حذف این نام کاربری';

  @override
  String handleDeleteTitle(Object handle) {
    return '⁦@$handle⁩ حذف شود؟';
  }

  @override
  String get handleDeleteLine =>
      'صفحه‌ی عمومی شما حذف می‌شود و هر کسی می‌تواند این نام را بگیرد. گفت‌وگوهایی که دارید همان‌طور می‌مانند.';

  @override
  String get handleDeleteYes => 'حذف نام کاربری';

  @override
  String get handleDeleting => 'در حال حذف…';

  @override
  String get handleChecking => 'در حال بررسی…';

  @override
  String get handleAvailable => '✓ آزاد';

  @override
  String get handleAlreadyTaken => 'قبلاً گرفته شده';

  @override
  String get handleNameRule => '۳ تا ۲۰ نویسه: حروف کوچک لاتین، رقم یا _';

  @override
  String get handleWhatAHandleDoes => 'نام کاربری چه می‌کند';

  @override
  String get handleAnyoneWhoKnowsIt =>
      'هر کس آن را بداند می‌تواند بخواهد به شما پیام دهد. صفحه فقط دعوت شما و خطی را که نوشته‌اید نگه می‌دارد، نه چیز دیگری، و هیچ سابقه‌ای از اینکه چه کسی آن را می‌خواند نگه نمی‌دارد. هر وقت خواستید می‌توانید حذفش کنید.';

  @override
  String handleIsNotYoursOn(Object handle) {
    return '⁦@$handle⁩ روی این گوشی مال شما نیست';
  }

  @override
  String handleTheRegistryHoldsIt(Object handle) {
    return 'دفتر ثبت آن را زیر کلید دیگری نگه داشته، به احتمال زیاد هویتی که این گوشی پیش از یک بازیابی داشته. کسانی که ⁦@$handle⁩ را اضافه می‌کنند به شما نمی‌رسند. از این‌جا نمی‌توان آن را آزاد یا به‌روز کرد. نام دیگری انتخاب کنید.';
  }

  @override
  String get handleForgetItOnThis => 'فراموش کردنش روی این گوشی';

  @override
  String get homeAddAContact => 'افزودن مخاطب';

  @override
  String get commonSettings => 'تنظیمات';

  @override
  String get homeYourKryfo => 'Kryfo شما';

  @override
  String homeDateWeekday(Object weekday) {
    return '⁨$weekday⁩،';
  }

  @override
  String get homeAnHour => 'یک ساعت';

  @override
  String homeHours(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$countString⁩ ساعت',
      one: '⁨$countString⁩ ساعت',
    );
    return '$_temp0';
  }

  @override
  String homeMinutes(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$countString⁩ دقیقه',
      one: '⁨$countString⁩ دقیقه',
    );
    return '$_temp0';
  }

  @override
  String get homeKryfoIsOffline => 'Kryfo آفلاین است';

  @override
  String homeTorHasNotBeen(Object howLong) {
    return 'Tor در ⁨$howLong⁩ گذشته نتوانسته وصل شود. تا وقتی وصل نشود، هیچ چیز نمی‌تواند برسد یا بیرون برود.';
  }

  @override
  String get homeReconnecting => 'در حال اتصال دوباره';

  @override
  String get homeReconnect => 'اتصال دوباره';

  @override
  String get homeWhatIsWrong => 'مشکل چیست';

  @override
  String get homeKryfoWillCheckIn => 'Kryfo هر ۱۵ دقیقه سرکشی می‌کند';

  @override
  String get homeYourPhoneKeepsStopping =>
      'گوشی شما مدام Kryfo را متوقف می‌کند';

  @override
  String get homeItHasClosedKryfo =>
      'امروز سه بار Kryfo را بسته است، برای همین پیام‌ها دیر رسیدند یا منتظر ماندند. سرکشی دوره‌ای از پس این برمی‌آید: Kryfo به‌جای متصل ماندن، هر ۱۵ دقیقه بیدار می‌شود.';

  @override
  String get homeSwitchToCheckIns => 'رفتن به سرکشی دوره‌ای';

  @override
  String get homeNotNow => 'فعلاً نه';

  @override
  String get homeNotificationsAreOff => 'اعلان‌ها خاموش‌اند';

  @override
  String get homeAndroidIsBlockingThem =>
      'اندروید جلوی آن‌ها را گرفته، پس تا وقتی Kryfo بسته است هیچ چیز به شما نمی‌رسد. وقتی بازش کنید، پیام‌ها همچنان می‌رسند.';

  @override
  String get homeCouldnTOpenIt => 'باز نشد. در تنظیمات گوشی دنبال Kryfo بگردید';

  @override
  String get homeTurnThemOn => 'روشن کردن';

  @override
  String get homeLeaveThemOff => 'خاموش بماند';

  @override
  String get homeOurRelayIsQuiet => 'رله‌ی ما ساکت است';

  @override
  String get homeRelayModeUsesOnly =>
      'حالت رله فقط از رله‌ی خود ما استفاده می‌کند، و آن الان پاسخ نمی‌دهد. حالت سریع رله‌های عمومی را هم کنارش اضافه می‌کند، پس پیام‌ها باز هم می‌رسند. در هر دو حالت همه‌چیز مهروموم‌شده می‌ماند.';

  @override
  String get homeSwitchedToFast => 'حالت سریع فعال شد';

  @override
  String get homeUseFastMode => 'استفاده از حالت سریع';

  @override
  String get homeKeepWaiting => 'منتظر ماندن';

  @override
  String get homeSwitchedToRelay => 'حالت رله فعال شد';

  @override
  String get homeUseOurRelay => 'استفاده از رله‌ی ما';

  @override
  String get homeOffline => 'آفلاین';

  @override
  String get homeWaiting => 'در انتظار';

  @override
  String get homeNothingWaitingToSend => 'چیزی در انتظار ارسال نیست';

  @override
  String homeWaitingSendsWhenYou(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$countString⁩ در انتظار · وقتی آنلاین شوید فرستاده می‌شود',
    );
    return '$_temp0';
  }

  @override
  String homeWaitingTorIsStill(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$countString⁩ در انتظار · Tor هنوز در حال اتصال است',
    );
    return '$_temp0';
  }

  @override
  String get homeNoKryfosYet => 'هنوز هیچ مخاطبی نیست.';

  @override
  String get homeScanTheirCodeSend =>
      'کد او را اسکن کنید، برایش پیوند بفرستید، یا نام کاربری‌ای را که به شما داده وارد کنید.';

  @override
  String get homeAddSomeone => 'افزودن یک نفر';

  @override
  String get homeArchived => 'بایگانی';

  @override
  String home1Chat(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$countString⁩ گفت‌وگو',
      one: '⁨$countString⁩ گفت‌وگو',
    );
    return '$_temp0';
  }

  @override
  String get homeGroups => 'گروه‌ها';

  @override
  String get homeRoom => 'اتاق';

  @override
  String get homeNew => 'جدید';

  @override
  String homeRoomExpired(Object expiredRoomName) {
    return '⁨$expiredRoomName⁩ · اتاق منقضی شد';
  }

  @override
  String get homeMentionedYou => 'از شما نام برد';

  @override
  String homeMembers(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$countString⁩ عضو',
      one: '⁨$countString⁩ عضو',
    );
    return '$_temp0';
  }

  @override
  String get homeSupporter => 'هوادار';

  @override
  String get homeUnmute => 'باصدا کردن';

  @override
  String get homeMute => 'بی‌صدا کردن';

  @override
  String get homeArchive => 'بایگانی';

  @override
  String get homeDeleteChat => 'حذف گفت‌وگو';

  @override
  String get homeMessagesAndContactGone =>
      'پیام‌ها و مخاطب از این گوشی حذف می‌شوند';

  @override
  String get homeDeleteThisChat => 'این گفت‌وگو حذف شود؟';

  @override
  String homeEveryMessageWithGoes(Object c) {
    return 'همه‌ی پیام‌های شما با ⁨$c⁩ حذف می‌شود و دیگر مخاطب شما نیست. این کار فقط روی این گوشی است. نسخه‌ی او پیش خودش می‌ماند. اگر دوباره پیام دهد، به درخواست‌ها می‌رود.';
  }

  @override
  String get homeQueued => 'در صف';

  @override
  String get homeBlocked => 'مسدود';

  @override
  String get homeRoomInvite => 'دعوت به اتاق';

  @override
  String get homeNow => 'الان';

  @override
  String homeM(Object inMinutes) {
    return '⁨$inMinutes⁩ دقیقه';
  }

  @override
  String homeH(Object inHours) {
    return '⁨$inHours⁩ ساعت';
  }

  @override
  String get homeYesterday => 'دیروز';

  @override
  String homeD(Object inDays) {
    return '⁨$inDays⁩ روز';
  }

  @override
  String get homeNoteToSelf => 'یادداشت برای خود';

  @override
  String get homeOnlyOnThisPhone => 'فقط روی این گوشی';

  @override
  String get homeSaved => 'ذخیره‌شده‌ها';

  @override
  String get homeKeptFromEveryChat => 'از همه‌ی گفت‌وگوها';

  @override
  String get homeRequests => 'درخواست‌ها';

  @override
  String home1PersonWantsTo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$countString⁩ نفر می‌خواهند به شما پیام دهند',
      one: '⁨$countString⁩ نفر می‌خواهد به شما پیام دهد',
    );
    return '$_temp0';
  }

  @override
  String introduceGotItButCould(Object b, Object c) {
    return '⁨$b⁩ آن را گرفت، اما ⁨$c⁩ در دسترس نبود';
  }

  @override
  String introduceGotItButCouldNotBe(Object c, Object b) {
    return '⁨$c⁩ آن را گرفت، اما ⁨$b⁩ در دسترس نبود';
  }

  @override
  String introduceIntroduced(Object b, Object c) {
    return '⁨$b⁩ و ⁨$c⁩ حالا کارت همدیگر را دارند';
  }

  @override
  String get introduceCouldNotReachEither =>
      'به هیچ‌کدامشان دسترسی نشد. بعداً دوباره امتحان کنید';

  @override
  String introduceIntroduceTo(Object peerName) {
    return 'معرفی ⁨$peerName⁩ به...';
  }

  @override
  String get introduceBothOfThemGet =>
      'هر دو کارت دیگری را می‌گیرند. هیچ‌کدام نامی را که شما برای دیگری گذاشته‌اید نمی‌بیند.';

  @override
  String get introduceNoOneElseTo =>
      'هنوز کس دیگری برای معرفی نیست. اول یک مخاطب دیگر اضافه کنید.';

  @override
  String get introduceANoteLikeMy => 'یک یادداشت، مثل «همکارم» (اختیاری)';

  @override
  String introduceOfIntroductionsLeftThis(int max, int left) {
    final intl.NumberFormat maxNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String maxString = maxNumberFormat.format(max);
    final intl.NumberFormat leftNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String leftString = leftNumberFormat.format(left);

    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '⁨$leftString⁩ از ⁨$maxString⁩ معرفی این هفته باقی مانده',
      one: '⁨$leftString⁩ از ⁨$maxString⁩ معرفی این هفته باقی مانده',
    );
    return '$_temp0';
  }

  @override
  String introduceNoIntroductionsLeftNext(Object refillPhrase) {
    return 'معرفی‌ای باقی نمانده. بعدی ⁨$refillPhrase⁩ آزاد می‌شود';
  }

  @override
  String get introduceIntroduce => 'معرفی';

  @override
  String get keyVerificationSafetyNumber => 'شماره‌ی امنیتی';

  @override
  String get keyVerificationNewNumber =>
      'کد امنیتی در حالی که این صفحه باز بود تغییر کرد. این شماره‌ی تازه است، دوباره مقایسه‌اش کنید.';

  @override
  String get keyVerificationKeyMoved =>
      'کد امنیتی همین حالا تغییر کرد. شماره‌ی تازه را مقایسه کنید.';

  @override
  String keyVerificationNoKeyYet(Object peerName) {
    return 'هنوز کلیدی از ⁨$peerName⁩ نیست. وقتی به شما پیام بدهد، شماره این‌جا نشان داده می‌شود.';
  }

  @override
  String keyVerificationWith(Object peerName) {
    return 'با ⁨$peerName⁩';
  }

  @override
  String keyVerificationCompareAll(Object peerName) {
    return 'هر ۱۲ گروه را با ⁨$peerName⁩ مقایسه کنید، حضوری یا در تماسی که به آن اعتماد دارید. اگر همه‌ی گروه‌ها یکی باشند، کسی در میان نیست و پیام‌های شما فقط برای شما دو نفر است.';
  }

  @override
  String get keyVerificationVerified => 'تأییدشده';

  @override
  String get keyVerificationMarkAsVerified => 'ثبت به‌عنوان تأییدشده';

  @override
  String get lockFileThatPasswordDoesNot => 'این گذرواژه آن را باز نمی‌کند.';

  @override
  String get lockFileThisFileIsDamaged => 'این فایل آسیب دیده است.';

  @override
  String get lockFileThisFileWasLocked =>
      'این فایل با یک کلید قفل شده، نه با گذرواژه.';

  @override
  String get lockFileThisIsNotA => 'این یک فایل قفل‌شده نیست.';

  @override
  String get lockFileNotEnoughFreeMemory => 'الان حافظه‌ی آزاد کافی نیست.';

  @override
  String get lockFileStopped => 'متوقف شد.';

  @override
  String get lockFileItNeedsAPassword => 'گذرواژه لازم دارد.';

  @override
  String get lockFileKryfoCouldNotRead =>
      'Kryfo نتوانست فایل را بخواند یا بنویسد.';

  @override
  String get lockFileCheckCapitalsAndSpaces =>
      'حروف بزرگ و فاصله‌ها را بررسی کنید. هیچ‌کس نمی‌تواند آن را بازنشانی کند.';

  @override
  String get lockFileItMayHaveBeen =>
      'شاید در راه ناقص شده باشد. بخواهید دوباره فرستاده شود. چیزی ذخیره نشد.';

  @override
  String get lockFileItOpensWithThe =>
      'با فایل کلید کسی که برایش ساخته شده، در ابزار age روی رایانه باز می‌شود. Kryfo نوع گذرواژه‌دار را باز می‌کند.';

  @override
  String get lockFileKryfoOpensFilesLocked =>
      'Kryfo فایل‌هایی را که با age قفل شده‌اند باز می‌کند. پسوند این فایل‌ها معمولاً age است.';

  @override
  String get lockFileCloseAFewApps =>
      'چند برنامه را ببندید و دوباره امتحان کنید. بررسی گذرواژه برای لحظه‌ای چند صد مگابایت حافظه لازم دارد.';

  @override
  String get lockFileNothingWasSaved => 'چیزی ذخیره نشد.';

  @override
  String get lockFileTypeOneOrLet =>
      'یکی تایپ کنید، یا بگذارید Kryfo چهار واژه پیشنهاد دهد.';

  @override
  String get lockFileTheAppThatHolds =>
      'شاید برنامه‌ای که آن را نگه می‌دارد، پسش گرفته باشد. دوباره انتخابش کنید.';

  @override
  String get lockFileHidePassword => 'پنهان کردن گذرواژه';

  @override
  String get lockFileShowPassword => 'نمایش گذرواژه';

  @override
  String get lockFileChangeFile => 'تغییر فایل';

  @override
  String get lockFileChange => 'تغییر';

  @override
  String lockFileOf(Object prettySize, Object prettySize2) {
    return '⁨$prettySize⁩ از ⁨$prettySize2⁩';
  }

  @override
  String get lockFileEverythingStaysOnThis => 'همه‌چیز روی این گوشی می‌ماند.';

  @override
  String get lockFileCouldNotMakeOne =>
      'ساختنش ممکن نشد. خودتان یکی تایپ کنید.';

  @override
  String get lockFileWriteItDownBefore =>
      'پیش از قفل کردن فایل، آن را یادداشت کنید';

  @override
  String get lockFileNoAppOnThis => 'هیچ برنامه‌ای روی این گوشی فایل را نگرفت.';

  @override
  String get linkNoAppOpens =>
      'هیچ برنامه‌ای روی این گوشی این پیوند را باز نمی‌کند.';

  @override
  String get placeStubLocation => 'موقعیت';

  @override
  String get lockFileSaved => 'ذخیره شد';

  @override
  String get lockFileCouldNotSaveIt =>
      'آن‌جا ذخیره نشد. پوشه‌ی دیگری را امتحان کنید.';

  @override
  String get lockFileLocked => 'قفل شد';

  @override
  String get lockFileLockAFile => 'قفل کردن یک فایل';

  @override
  String get lockFileMixingThePassword => 'در هم آمیختن گذرواژه';

  @override
  String get lockFileLocking => 'در حال قفل کردن';

  @override
  String get lockFileSaveToFiles => 'ذخیره در فایل‌ها';

  @override
  String get lockFileLockFile => 'قفل کردن فایل';

  @override
  String get lockFileOnePassword => 'یک گذرواژه.';

  @override
  String get lockFileNothingElseOpensIt => 'هیچ چیز دیگری بازش نمی‌کند.';

  @override
  String get lockFileFile => 'فایل';

  @override
  String lockFileFromFiles(Object prettySize) {
    return '⁨$prettySize⁩ · از فایل‌ها';
  }

  @override
  String get lockFileFromFiles2 => 'از فایل‌ها';

  @override
  String get lockFilePassword => 'گذرواژه';

  @override
  String get lockFileSuggestFourWords => 'پیشنهاد چهار واژه';

  @override
  String get lockFileTypeItAgain => 'دوباره تایپ کنید';

  @override
  String get lockFileTheTwoDoNot => 'این دو هنوز یکی نیستند.';

  @override
  String get lockFileHideTheFileName => 'پنهان کردن نام فایل';

  @override
  String lockFileItWillBeCalled(Object name) {
    return 'نامش «⁨$name⁩» خواهد بود. به او بگویید چه نوع فایلی است.';
  }

  @override
  String get lockFileTheNameAloneCan =>
      'خود نام به‌تنهایی می‌تواند بگوید درونش چیست.';

  @override
  String get lockFileAnyoneWithThePassword =>
      'هر کس گذرواژه را داشته باشد می‌تواند آن را باز کند، در Kryfo یا روی هر رایانه‌ای با ابزار رایگان age. اگر فراموشش کنید، فایل برای همیشه از دست می‌رود. هیچ‌کس نمی‌تواند آن را بازنشانی کند.';

  @override
  String get lockFileLocked2 => 'قفل شد.';

  @override
  String get lockFileOnlyThePasswordOpens => 'فقط گذرواژه آن را باز می‌کند.';

  @override
  String lockFileSafeToEmailOr(Object prettySize) {
    return '⁨$prettySize⁩ · می‌شود با خیال راحت ایمیلش کرد یا روی فلش USB گذاشت';
  }

  @override
  String get lockFileNoKryfoOnThe => 'طرف مقابل Kryfo ندارد؟ روی رایانه:';

  @override
  String get lockFileItAsksForThe =>
      'گذرواژه را می‌پرسد. age در age-encryption.org رایگان است';

  @override
  String lockTooManyTriesS(Object lockState) {
    return 'تلاش بیش از حد · ⁨$lockState⁩ ثانیه';
  }

  @override
  String get lockNotIt => 'درست نیست';

  @override
  String get lockYourPin => 'PIN شما';

  @override
  String get lockUseFingerprint => 'استفاده از اثر انگشت';

  @override
  String get lockSetupUnlockWithFingerprint => 'باز کردن قفل با اثر انگشت؟';

  @override
  String get lockSetupThePinStillWorks =>
      'PIN هر وقت بخواهید همچنان کار می‌کند. این فقط سریع‌تر است.';

  @override
  String get lockSetupUseFingerprint => 'استفاده از اثر انگشت';

  @override
  String get lockSetupTurningOn => 'در حال روشن کردن…';

  @override
  String get lockSetupPinOnly => 'فقط PIN';

  @override
  String get lockSetupOnceMore => 'یک بار دیگر';

  @override
  String get lockSetupSetAPin => 'تعیین PIN';

  @override
  String get lockSetupThoseWereDifferentFrom => 'یکی نبودند. از اول.';

  @override
  String get lockSetupTheSameFourDigits => 'همان رقم‌ها را دوباره';

  @override
  String get lockSetupFourDigitsAnythingYou =>
      'چهار رقم یا بیشتر، هر چه یادتان بماند';

  @override
  String get modesOnion => 'Onion';

  @override
  String get modesFullOnionRoutingThree =>
      'مسیریابی کامل onion، سه گام. هر پیام دو تا پنج ثانیه طول می‌کشد. هیچ‌کس نمی‌بیند با چه کسی حرف می‌زنید.';

  @override
  String get modesSlower => 'کندتر';

  @override
  String get modesRelay => 'رله';

  @override
  String get modesOneSealedConnectionTo =>
      'یک اتصال مهروموم‌شده به رله‌ی خود Kryfo، مثل یک VPN که چیزی برای ثبت ندارد. ارسال‌ها در حدود یک ثانیه می‌رسند، و جایی که Tor مسدود است هم کار می‌کند.';

  @override
  String get modesQuick => 'چابک';

  @override
  String get modesRelayOnly => 'فقط رله';

  @override
  String get modesFast => 'سریع';

  @override
  String get modesPlainConnectionsToEvery =>
      'اتصال‌های ساده به همه‌ی رله‌ها. تقریباً آنی، و کمترین حریم خصوصی را در میان این سه دارد.';

  @override
  String get modesInstant => 'آنی';

  @override
  String get modesEveryRelayYouUse =>
      'هر رله‌ای که استفاده می‌کنید نشانی‌ای را که از آن وصل می‌شوید می‌داند، نه فقط رله‌ی ما. پیام‌ها همچنان مهروموم‌شده‌اند، اما اینکه پیامی فرستاده‌اید، نه. به‌طور پیش‌فرض خاموش است و بعد از نصب دوباره هم خاموش می‌شود.';

  @override
  String get modesNotChanged => 'حالت تغییر نکرد. دوباره امتحان کنید.';

  @override
  String get modesSwitching => 'در حال تغییر…';

  @override
  String get modesSpeed => 'سرعت';

  @override
  String get modesPrivacy => 'و حریم خصوصی';

  @override
  String get modesChangeGloballyOrPer =>
      'برای همه تغییر دهید، یا برای هر گفت‌وگو جدا';

  @override
  String get modesSoon => 'به‌زودی';

  @override
  String get modesActive => 'فعال';

  @override
  String get modesSpeed2 => 'سرعت';

  @override
  String get modesHops => 'گام‌ها';

  @override
  String get modesIp => 'IP';

  @override
  String get modesVisible => 'آشکار';

  @override
  String get modesHidden => 'پنهان';

  @override
  String modesHeadsUp(Object warning) {
    return '*حواستان باشد:* ⁨$warning⁩';
  }

  @override
  String get modesOnionIsTheDefault =>
      'Onion پیش‌فرض است و همین‌طور می‌ماند، مگر اینکه خودتان عوضش کنید. تغییر از پیام بعدی اعمال می‌شود.';

  @override
  String get modesFastMode => 'حالت سریع';

  @override
  String get modesPlainConnectionsToEveryRelayQuicker =>
      'اتصال‌های ساده به همه‌ی رله‌ها. سریع‌تر است، و رله‌ها می‌توانند نشانی IP شما را ببینند. پیام‌ها در هر حال سرتاسری رمزگذاری‌شده می‌مانند.';

  @override
  String get modesTurnOnFastMode => 'روشن کردن حالت سریع';

  @override
  String get modesKeepItOff => 'خاموش بماند';

  @override
  String get movedWipeThisPhone => 'Kryfo از این گوشی پاک شود؟';

  @override
  String get movedEverythingKryfoHoldsHere =>
      'هر چه Kryfo این‌جا دارد پاک می‌شود: پیام‌ها، مخاطبان، کلیدها. دستگاه دیگر همه‌اش را نگه می‌دارد. این کار برگشت ندارد.';

  @override
  String get movedWipeIt => 'پاک کردن';

  @override
  String get movedNotMovingAfterAll => 'از انتقال منصرف شدید؟';

  @override
  String get movedOnlyDoThisIf =>
      'این کار را فقط وقتی بکنید که نسخه‌ی پشتیبان هیچ‌جا وارد نشده باشد. اگر شده، حالا دو دستگاه یک هویت دارند و پیام‌ها روی هر دو کم‌کم گم می‌شوند.';

  @override
  String get movedIMStayingHere => 'همین‌جا می‌مانم';

  @override
  String get movedStayingHere => 'ماندن در همین‌جا';

  @override
  String movedKryfoWillCloseNow(Object myId) {
    return 'Kryfo حالا بسته می‌شود. نماد را بزنید تا دوباره به‌عنوان ⁨$myId⁩ باز شود.';
  }

  @override
  String get movedReopenKryfo => 'بازگشایی Kryfo';

  @override
  String get movedThisKryfoHasMoved => 'این Kryfo منتقل شده';

  @override
  String movedIsNowOnAnother(Object myId) {
    return '⁨$myId⁩ حالا روی دستگاه دیگری است. این گوشی هنوز می‌تواند آنچه این‌جا بود را نشان دهد، اما دیگر چیز تازه‌ای رویش نمی‌رسد، و هر چه از این‌جا بفرستید به دست کسی نمی‌رسد.';
  }

  @override
  String get movedKeepItToRead => 'نگه داشتن برای خواندن';

  @override
  String get movedWipeThisPhone2 => 'پاک‌سازی Kryfo از این گوشی';

  @override
  String get movedIMNotMoving => 'منصرف شدم، منتقل نمی‌شوم';

  @override
  String get myKryfoAHandleIs3 =>
      'نام کاربری ۳ تا ۲۰ حرف انگلیسی، رقم یا _ است';

  @override
  String get myKryfoInviteCopiedClearsIn =>
      'دعوت کپی شد · ۶۰ ثانیه‌ی دیگر از بریده‌دان حذف می‌شود';

  @override
  String myKryfoAddMeOnKryfo(Object myId, Object uri) {
    return 'مرا در Kryfo اضافه کنید. شناسه‌ی من ⁨$myId⁩ است\n\nبرای افزودن من بزنید:\n⁨$uri⁩\n\nبرنامه‌ی Kryfo یک پیام‌رسان خصوصی است. بدون شماره تلفن، بدون ایمیل.';
  }

  @override
  String get myKryfoAddMeOnKryfo2 => 'مرا در Kryfo اضافه کنید';

  @override
  String get myKryfoAddSomeone => 'افزودن یک نفر';

  @override
  String get myKryfoKryfoDoesnTScan =>
      'Kryfo مخاطبان شما را اسکن نمی‌کند، نکته همین است.';

  @override
  String get myKryfoIfThisLinkEnds =>
      'اگر این پیوند جایی رفت که نمی‌خواستید، در تنظیمات بازنشانی‌اش کنید. آن وقت هر کس آن را دارد به پیوندی تازه نیاز دارد.';

  @override
  String get myKryfoAlreadyShareAFriend =>
      'دوست مشترکی در Kryfo دارید؟ او می‌تواند از گفت‌وگوی خودش شما دو نفر را به هم معرفی کند، و دیگر درخواست لازم نیست.';

  @override
  String get myKryfoHandleCopied => 'نام کاربری کپی شد';

  @override
  String get myKryfoTheyReHereWith => 'کنار من است';

  @override
  String get myKryfoPointYourPhonesAt =>
      'گوشی‌هایتان را رو به هم بگیرید. هیچ چیز از سروری عبور نمی‌کند.';

  @override
  String get myKryfoScanTheirsInstead => 'به‌جایش کد او را اسکن کنید';

  @override
  String get myKryfoTheyReadYouA => 'او یک کد برایتان می‌خواند';

  @override
  String get myKryfoTheyReSomewhereElse => 'جای دیگری است';

  @override
  String get myKryfoSendThemALink =>
      'برایش پیوند بفرستید. مستقیم در صفحه‌ی افزودن باز می‌شود.';

  @override
  String get myKryfoYourLinkAppearsOnce =>
      'پیوند شما وقتی وصل شوید نمایش داده می‌شود';

  @override
  String get myKryfoTheLinkCarriesYour =>
      'این پیوند شناسه، نشانی و کلیدهای شروع گفت‌وگو را با خود دارد. تا وقتی آن را در تنظیمات بازنشانی نکنید کار می‌کند.';

  @override
  String get myKryfoSendTheLink => 'ارسال پیوند';

  @override
  String get myKryfoAsACard => 'به‌صورت کارت';

  @override
  String get myKryfoAnImageWithThe => 'تصویری با QR';

  @override
  String get myKryfoAsAFile => 'به‌صورت فایل';

  @override
  String get myKryfoContactFile => 'فایل مخاطب';

  @override
  String get myKryfoIKnowTheirHandle => 'نام کاربری‌اش را می‌دانم';

  @override
  String get myKryfoTypeTheNameThey =>
      'نام کاربری‌ای را که به شما داده تایپ کنید. اگر یکی ثبت کرده باشد، کار می‌کند.';

  @override
  String get myKryfoTheLookupAsksFor =>
      'جست‌وجو فقط همان یک نام را می‌فرستد و هیچ چیزی درباره‌ی شما نمی‌فرستد. اولین پیام شما همچنان به‌صورت درخواست به دستش می‌رسد.';

  @override
  String get myKryfoLooking => 'در حال جست‌وجو…';

  @override
  String get myKryfoFindThem => 'پیدا کردن';

  @override
  String get myKryfoYourAddressAppearsOnce =>
      'نشانی شما وقتی وصل شوید نمایش داده می‌شود';

  @override
  String get myKryfoAPublicHandle => 'یک نام کاربری عمومی';

  @override
  String get myKryfoPutItInA =>
      'آن را در بیو بگذارید. هر کس آن را بداند می‌تواند پیدایتان کند.';

  @override
  String get myKryfoANamePeopleCan =>
      'نامی که دیگران می‌توانند با آن پیدایتان کنند. تا وقتی یکی ثبت نکنید، خاموش است.';

  @override
  String get newGroupCouldNotCreate => 'ساختن ممکن نشد';

  @override
  String get newGroupNewGroup => 'گروه جدید';

  @override
  String get newGroupCreating => 'در حال ساختن…';

  @override
  String get newGroupCreate => 'ساختن';

  @override
  String get newGroupGroupName => 'نام گروه';

  @override
  String get newGroupMembers => 'اعضا';

  @override
  String get newGroupPickAtLeastOne => 'دست‌کم یکی انتخاب کنید';

  @override
  String newGroupSelected(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$countString⁩ انتخاب‌شده',
    );
    return '$_temp0';
  }

  @override
  String get newGroupAddAtLeastOne =>
      'پیش از ساختن گروه، دست‌کم یک مخاطب اضافه کنید.';

  @override
  String get notesDeleteThisNote => 'این یادداشت حذف شود؟';

  @override
  String get notesHoldHint => 'برای کپی یا حذف، روی یادداشت نگه دارید.';

  @override
  String get notesMenu => 'منوی یادداشت‌ها';

  @override
  String get notesDeleteAll => 'حذف همه‌ی یادداشت‌ها';

  @override
  String get notesDeleteAllTitle => 'همه‌ی یادداشت‌ها حذف شوند؟';

  @override
  String get notesDeleteAllLine =>
      'همه‌ی یادداشت‌های این گوشی برای همیشه پاک می‌شوند.';

  @override
  String get notesDeleteAllYes => 'حذف همه';

  @override
  String get notesThisWeek => 'این هفته';

  @override
  String get notesShowMore => 'نمایش بیشتر';

  @override
  String get notesShowLess => 'نمایش کمتر';

  @override
  String get notesGoneFromThisPhone => 'برای همیشه از این گوشی پاک می‌شود.';

  @override
  String get notesNoteToSelf => 'یادداشت برای خود';

  @override
  String get notesOnlyOnThisPhone => 'فقط روی این گوشی';

  @override
  String get notesAQuietPlace => 'جایی آرام';

  @override
  String get notesJotAnythingDownIt =>
      'هر چیزی را یادداشت کنید. روی این گوشی می‌ماند و هرگز بیرون نمی‌رود.';

  @override
  String get notesJotSomethingDown => 'چیزی بنویسید…';

  @override
  String get notesExportNotes => 'برون‌بری یادداشت‌ها';

  @override
  String get notesExport => 'برون‌بری';

  @override
  String get notesExportWorking => 'در حال برون‌بری…';

  @override
  String notesExportCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$countString⁩ یادداشت، از قدیمی‌ترین.',
      one: '⁨$countString⁩ یادداشت، از قدیمی‌ترین.',
    );
    return '$_temp0';
  }

  @override
  String get notesExportZip =>
      'عکس‌ها و پیام‌های صوتی همراهشان در یک فایل zip می‌روند.';

  @override
  String get notesExportText => 'متن ساده';

  @override
  String get notesExportTextLine => 'فایل ‎.txt که همه‌جا باز می‌شود';

  @override
  String get notesExportMarkdown => 'Markdown';

  @override
  String get notesExportMarkdownLine =>
      'فایل ‎.md با سرعنوان، برای برنامه‌های یادداشت';

  @override
  String get notesExportLock => 'قفل با عبارت عبور';

  @override
  String get notesExportLockLine =>
      'از ابزارها با «باز کردن فایل قفل‌شده» بازش کنید، یا با age روی رایانه';

  @override
  String get notesExportPlainTitle => 'بدون عبارت عبور برون‌بری شود؟';

  @override
  String get notesExportPlainLine =>
      'هر کس این فایل به دستش برسد می‌تواند آن را بخواند.';

  @override
  String get notesExportPlainYes => 'برون‌بری بدون آن';

  @override
  String get notesExportKeepLock => 'عبارت عبور بماند';

  @override
  String get notesExportNotSaved =>
      'یادداشت‌ها ذخیره نشدند. فایل هنوز اینجاست.';

  @override
  String get notesExportGone =>
      'فایل وقتی Kryfo قفل شد پاک شد. برای ساختن فایلی تازه دوباره برون‌بری کنید.';

  @override
  String get notesExportHoldsInstaller =>
      'این برون‌بری فایلِ نصبِ یک برنامه را دارد، پس نمی‌شود هم‌رسانی‌اش کرد. به‌جایش آن را در گوشی‌تان ذخیره کنید.';

  @override
  String get notesExportSaved => 'یادداشت‌ها ذخیره شدند';

  @override
  String notesExportSavedIn(String place) {
    return 'یادداشت‌ها در ⁨$place⁩ ذخیره شدند';
  }

  @override
  String get notesExportSavedUnchecked =>
      'یادداشت‌ها ذخیره شدند، ولی Kryfo نتوانست نسخه را بررسی کند';

  @override
  String get notesExportFailed =>
      'برون‌بری یادداشت‌ها ممکن نشد. چیزی ذخیره نشد.';

  @override
  String get notesExportTooLarge =>
      'برای برون‌بری بیش از حد بزرگ است. عکس‌ها و پیام‌های صوتی ۴ گیگابایت یا بیشتر می‌شوند.';

  @override
  String get notesExportSubject => 'یادداشت‌های Kryfo';

  @override
  String get onboardingPrivateByDefault => 'به‌طور پیش‌فرض خصوصی';

  @override
  String get onboardingPrivateMessaging => 'پیام‌رسانی خصوصی،\n*بی قید و شرط*.';

  @override
  String get onboardingYourNameIsThree =>
      '*نام شما سه واژه است.* نه تلفن، نه ایمیل، نه دفترچه‌ی تلفن.';

  @override
  String get onboardingNobodyGetsInUnless =>
      '*هیچ‌کس وارد نمی‌شود مگر اینکه شما بگذارید.* فقط اگر یک نام کاربری عمومی ثبت کنید، دیگران می‌توانند پیدایتان کنند. آدم‌ها دستی اضافه می‌شوند، از هر دو طرف.';

  @override
  String get onboardingTheFirstConnectionTakes =>
      '*اولین اتصال یک دقیقه طول می‌کشد.* Kryfo پیش از ارسال یک مسیر خصوصی می‌سازد. بعدش سریع است.';

  @override
  String get onboardingBegin => 'شروع';

  @override
  String get onboardingHaveABackupRestore => 'نسخه‌ی پشتیبان دارید؟ بازیابی ←';

  @override
  String get onboardingKryfoIsOpenSource => 'Kryfo متن‌باز است';

  @override
  String get onboardingYourKryfoId => 'شناسه‌ی KRYFO شما';

  @override
  String get onboardingGeneratedFromAKey =>
      'از کلیدی ساخته شده که فقط روی این گوشی زندگی می‌کند. *هیچ‌کس دیگری این واژه‌ها را ندارد.*';

  @override
  String get onboardingTryAnother => 'یکی دیگر';

  @override
  String get onboardingUseThisName => 'استفاده از این نام ←';

  @override
  String get onboardingThreeWords => 'سه واژه. *فقط مال شما.*';

  @override
  String get onboardingPickA => 'یک *چهره* انتخاب کنید.';

  @override
  String get onboardingDrawnOnThisPhone =>
      'روی همین گوشی از یک عدد کشیده می‌شود و هرگز بارگذاری نمی‌شود. هر وقت خواستید عوضش کنید.';

  @override
  String get onboardingThePeopleYouMessage =>
      'کسانی که به آن‌ها پیام می‌دهید هم این را می‌بینند';

  @override
  String get onboardingKeepMyInitial => 'حرف اولم بماند';

  @override
  String get onboardingThatOne => 'همین ←';

  @override
  String get onboardingContinue => 'ادامه ←';

  @override
  String get onboardingHowYourMessages => 'پیام‌هایتان چطور *سفر می‌کنند*.';

  @override
  String get onboardingYouCanChangeThis =>
      'هر وقت خواستید می‌توانید این را در تنظیمات تغییر دهید، برای همه یا برای یک گفت‌وگو.';

  @override
  String get onboardingOnion => 'Onion';

  @override
  String get onboardingSlowerAMessageTakes =>
      'کندتر. هر پیام دو تا پنج ثانیه طول می‌کشد.';

  @override
  String get onboardingHidesYourAddressFrom =>
      'نشانی شما را از همه پنهان می‌کند، حتی از رله‌ی ما.';

  @override
  String get onboardingRelay => 'رله';

  @override
  String get onboardingOurRelaySeesYour =>
      'رله‌ی ما نشانی شما را می‌بیند. هیچ‌کس دیگری نه.';

  @override
  String get onboardingAboutASecondWorks =>
      'حدود یک ثانیه. جایی که Tor مسدود است هم کار می‌کند.';

  @override
  String get onboardingAutoFindsAWay =>
      '«خودکار» خودش راهی برای دور زدن مسدودسازی پیدا می‌کند.';

  @override
  String get onboardingFast => 'سریع';

  @override
  String get onboardingEveryRelayYouUse =>
      'هر رله‌ای که استفاده می‌کنید نشانی شما را می‌بیند. کمترین حریم خصوصی در میان این سه.';

  @override
  String get onboardingNearInstant => 'تقریباً آنی.';

  @override
  String get onboardingKeepOnion => 'همان onion ←';

  @override
  String get onboardingUseThis => 'استفاده از این ←';

  @override
  String get onboardingSkipOnionIsA => 'رد شدن · onion پیش‌فرض خوبی است';

  @override
  String get onboardingThreeThingsThen => 'سه نکته،\nبعد *وارد می‌شوید*.';

  @override
  String get onboardingEverythingElseTheApp =>
      'بقیه‌ی چیزها را برنامه هر وقت لازم شد می‌گوید.';

  @override
  String get onboardingYourNameIsThreeWords => 'نام شما سه واژه است';

  @override
  String get onboardingThatIsTheWhole =>
      'کل هویت همین است. هیچ شماره یا ایمیلی نیست که لو برود یا جست‌وجو شود. کسانی که با آن‌ها حرف می‌زنید این واژه‌ها و چهره‌ای را که انتخاب کرده‌اید می‌بینند.';

  @override
  String get onboardingNobodyCanReachYou =>
      'هیچ‌کس نمی‌تواند به شما برسد، مگر اینکه راهش بدهید';

  @override
  String get onboardingAStrangerWithYour =>
      'غریبه‌ای که واژه‌های شما را دارد فقط می‌تواند در بزند. پیام اولش در درخواست‌ها منتظر می‌ماند تا شما بله بگویید، و می‌توانید نه بگویید بی‌آنکه او هرگز بفهمد.';

  @override
  String get onboardingTheFirstConnectionTakesAMinute =>
      'اولین اتصال یک دقیقه طول می‌کشد';

  @override
  String get onboardingKryfoBuildsAPrivateRouteBefore =>
      'Kryfo پیش از ارسال هر چیزی یک مسیر خصوصی می‌سازد. وقتی آفلاین هستید، پیام‌ها منتظر می‌مانند و وقتی برگردید می‌رسند.';

  @override
  String get onboardingYourIdentityLivesOn =>
      'هویت شما روی این گوشی زندگی می‌کند. هر وقت آماده بودید، از تنظیمات از آن پشتیبان بگیرید.';

  @override
  String get onboardingIUnderstand => 'متوجه شدم ←';

  @override
  String get onboardingOneQuiet => 'یک *اعلان* بی‌صدا.';

  @override
  String get onboardingAndroidNeedsAVisible =>
      'اندروید وقتی برنامه‌ای در پس‌زمینه گوش می‌دهد، یک اعلان پیدا لازم دارد. پیام‌ها وقتی Kryfo بسته است از همین راه به شما می‌رسند.';

  @override
  String get onboardingSilentAndAtThe => 'بی‌صدا، و پایین فهرست اعلان‌ها';

  @override
  String get onboardingItNeverBuzzesTurn =>
      'هرگز نمی‌لرزد. اگر خاموشش کنید، پیام‌ها تا وقتی دوباره برنامه را باز کنید منتظر می‌مانند.';

  @override
  String get onboardingGotIt => 'فهمیدم ←';

  @override
  String get onboardingNow => 'حالا *یک نفر را اضافه کنید*.';

  @override
  String get onboardingTheAppIsReady =>
      'برنامه آماده است. هیچ‌کس نمی‌تواند به شما پیام دهد تا وقتی او را اضافه کنید یا راهش بدهید.';

  @override
  String get onboardingEveryWayToAdd => 'همه‌ی راه‌های افزودن';

  @override
  String get onboardingShowYourCodeSend =>
      'کدتان را نشان دهید، برایش پیوند بفرستید، یا نام کاربری‌ای را که به شما داده وارد کنید.';

  @override
  String get onboardingScanTheirs => 'اسکن کد او';

  @override
  String get onboardingPointTheCameraAt => 'دوربین را رو به کد او بگیرید';

  @override
  String get onboardingTheAppIsReadyWhenYou =>
      'هر وقت شما آماده باشید، برنامه آماده است.';

  @override
  String get onboardingNotNowAddPeople =>
      'فعلاً نه · بعداً آدم‌ها را اضافه کنید';

  @override
  String get openLockedOpened => 'باز شد';

  @override
  String get openLockedOpenALockedFile => 'باز کردن فایل قفل‌شده';

  @override
  String get openLockedCheckingThePassword => 'بررسی گذرواژه';

  @override
  String get openLockedOpening => 'در حال باز کردن';

  @override
  String get openLockedFile => 'فایل';

  @override
  String get openLockedOpenFile => 'باز کردن فایل';

  @override
  String get openLockedTypeThePassword => 'گذرواژه را تایپ کنید.';

  @override
  String get openLockedItOpensOnThis => 'روی همین گوشی باز می‌شود.';

  @override
  String get openLockedLockedFile => 'فایل قفل‌شده';

  @override
  String openLockedFromFiles(Object prettySize) {
    return '⁨$prettySize⁩ · از فایل‌ها';
  }

  @override
  String get openLockedFromFiles2 => 'از فایل‌ها';

  @override
  String get openLockedPassword => 'گذرواژه';

  @override
  String get openLockedThePasswordIsChecked =>
      'اول گذرواژه بررسی می‌شود. فقط بعد از آن Kryfo می‌پرسد فایل بازشده کجا برود، و مستقیم همان‌جا می‌رود.';

  @override
  String get openLockedOpened2 => 'باز شد.';

  @override
  String get openLockedSavedWhereYouChose =>
      'همان‌جا که انتخاب کردید ذخیره شد.';

  @override
  String get pairCodePairingCode => 'کد جفت‌سازی';

  @override
  String get pairCodeShowACode => 'نمایش کد';

  @override
  String get pairCodeEnterOne => 'وارد کردن کد';

  @override
  String get pairCodeSixDigits => 'شش رقم';

  @override
  String get pairCodeLooking => 'در حال جست‌وجو…';

  @override
  String get pairCodeNothingThereYetTrying =>
      'هنوز چیزی نیست · دوباره تلاش می‌کنیم';

  @override
  String get pairCodeNothingAtThatCode =>
      'زیر این کد چیزی نیست. شاید محو شده باشد، یا او هنوز آن را هم‌رسانی نکرده.';

  @override
  String get pairCodeUnreached =>
      'به رله‌ها دسترسی نشد. کمی بعد دوباره امتحان کنید.';

  @override
  String get pairCodeFailed => 'انجام نشد. دوباره امتحان کنید.';

  @override
  String get pairCodeTypeTheSixDigits => 'شش رقمی را که او می‌خواند تایپ کنید.';

  @override
  String get pairCodeAddThem => 'افزودن';

  @override
  String get pairCodeUsedTwice =>
      'این کد دو بار استفاده شده. یک کد تازه بخواهید.';

  @override
  String get pairCodeKeyNumber => 'شماره‌ی کلید';

  @override
  String get pairCodeNumberMatches =>
      'بررسی کنید هر چهار گروه روی هر دو گوشی یکی باشند';

  @override
  String get pairCodeNumberDiffers => 'شماره فرق دارد';

  @override
  String get pairCodeNoNumberThere =>
      'روی صفحه‌ی او شماره‌ای نیست؟ او را اضافه کنید، بعد شماره‌ی امنیتی را در گفت‌وگو مقایسه کنید.';

  @override
  String get pairCodeNotAdded => 'افزوده نشد. یک کد تازه بخواهید.';

  @override
  String get panicSetupThoseWereDifferentFrom => 'یکی نبودند. از اول.';

  @override
  String get panicSetupOnceMore => 'یک بار دیگر';

  @override
  String get panicSetupTheSameFourDigits => 'همان رقم‌ها را دوباره';

  @override
  String get photoKnowsEverythingInside => 'همه‌چیزِ درونش';

  @override
  String get photoKnowsVideo => 'ویدیو';

  @override
  String get photoKnowsPhoto => 'عکس';

  @override
  String get photoKnowsWhatThisVideoKnows => 'این ویدیو چه می‌داند';

  @override
  String get photoKnowsWhatThisPhotoKnows => 'این عکس چه می‌داند';

  @override
  String get photoKnowsRemoveAllOfIt => 'حذف همه‌اش';

  @override
  String get photoKnowsKeepItAsIt => 'همین‌طور بماند';

  @override
  String get photoKnowsReadOnThisPhone =>
      'روی همین گوشی خوانده شد · ویدیو جایی نرفت';

  @override
  String get photoKnowsReadOnThisPhoneThePhoto =>
      'روی همین گوشی خوانده شد · عکس جایی نرفت';

  @override
  String get photoKnowsReadingTheFile => 'خواندن فایل';

  @override
  String photoKnowsOf(Object prettySize, Object prettySize2) {
    return '⁨$prettySize⁩ از ⁨$prettySize2⁩';
  }

  @override
  String get photoKnowsEverythingStaysOnThis => 'همه‌چیز روی این گوشی می‌ماند.';

  @override
  String photoKnowsMapWithAPin(Object place) {
    return 'نقشه با یک نشانگر. ⁨$place⁩';
  }

  @override
  String get photoKnowsDrawnOffline => 'آفلاین کشیده شده';

  @override
  String photoKnowsShowEverything(Object title) {
    return '⁨$title⁩. نمایش همه';
  }

  @override
  String get pinsAppLock => 'قفل برنامه';

  @override
  String get pinsYourPin => 'PIN شما';

  @override
  String get commonOn => 'روشن';

  @override
  String get commonOff => 'خاموش';

  @override
  String get pinsOpensKryfoFourDigits =>
      'Kryfo را باز می‌کند. هر بار Kryfo به جلو می‌آید پرسیده می‌شود.';

  @override
  String get pinsChangePin => 'تغییر PIN';

  @override
  String get pinsSetAPin => 'تعیین PIN';

  @override
  String get pinsTurnOff => 'خاموش کردن';

  @override
  String get pinsTurnOffTheApp => 'قفل برنامه خاموش شود؟';

  @override
  String get pinsThePinGoesAnd =>
      'PIN حذف می‌شود، و PIN پاک‌سازی و هر گفت‌وگوی پنهانی هم با آن. هر کس گوشی شما را در دست داشته باشد، Kryfo را به‌عنوان شما باز می‌کند.';

  @override
  String get pinsUnlockWithFingerprint => 'باز کردن قفل با اثر انگشت';

  @override
  String get pinsWipePin => 'PIN پاک‌سازی';

  @override
  String get pinsNeedsAPinFirst => 'اول یک PIN لازم است';

  @override
  String get pinsSet => 'تعیین‌شده';

  @override
  String get pinsChangeWipePin => 'تغییر PIN پاک‌سازی';

  @override
  String get pinsRemove => 'حذف';

  @override
  String get pinsRemoveTheWipePin => 'PIN پاک‌سازی حذف شود؟';

  @override
  String get pinsTheLockScreenKeeps =>
      'صفحه‌ی قفل PIN شما را نگه می‌دارد. PIN پاک‌سازی دیگر کاری نمی‌کند.';

  @override
  String profileCopied(Object what) {
    return '⁨$what⁩ کپی شد';
  }

  @override
  String get profileProfile => 'نمایه';

  @override
  String get profileChangeYourFace => 'تغییر چهره';

  @override
  String get profileKryfoId => 'شناسه‌ی Kryfo';

  @override
  String get profileOnionAddress => 'نشانی onion';

  @override
  String get profileSupporterBadge => 'نشان هوادار';

  @override
  String profileYouAreAThank(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter': 'شما هوادار هستید. ممنونیم.',
      'patron': 'شما حامی هستید. ممنونیم.',
      'guardian': 'شما نگهبان هستید. ممنونیم.',
      'other': 'شما هوادار هستید. ممنونیم.',
    });
    return '$_temp0';
  }

  @override
  String get profileShowMyBadge => 'نمایش نشانم';

  @override
  String get profileOnMyOwnScreens => 'روی صفحه‌های خودم';

  @override
  String get profileLetContactsSeeIt => 'مخاطبان هم ببینند';

  @override
  String get profileOffByDefault => 'به‌طور پیش‌فرض خاموش';

  @override
  String get profileShareConnect => 'هم‌رسانی و ارتباط';

  @override
  String get profileMyKryfoCode => 'کد Kryfo من';

  @override
  String get profileAddContact => 'افزودن مخاطب';

  @override
  String get profileGiveAgain => 'کمک دوباره';

  @override
  String get profileSupportKryfo => 'حمایت از Kryfo';

  @override
  String get profileKryfoRunsOnWhat => 'Kryfo با کمک مردم می‌چرخد';

  @override
  String get profileKeepKryfoIndependent => 'Kryfo را مستقل نگه دارید';

  @override
  String get qrLink => 'پیوند';

  @override
  String get qrYourLinkAsTyped =>
      'پیوند شما همان‌طور که تایپ شده · بدون تغییر مسیر برای ردیابی';

  @override
  String get qrText => 'متن';

  @override
  String get qrStaysInTheCode => 'در خود کد می‌ماند · هیچ سروری نگهش نمی‌دارد';

  @override
  String get qrWiFi => 'Wi-Fi';

  @override
  String get qrMadeOnThisPhone =>
      'روی همین گوشی ساخته شد · هیچ وب‌سایتی گذرواژه را ندید';

  @override
  String get qrNetworkName => 'نام شبکه';

  @override
  String get qrPassword => 'گذرواژه';

  @override
  String get qrContact => 'مخاطب';

  @override
  String get qrOnlyWhatYouType =>
      'فقط آنچه تایپ می‌کنید · هیچ چیز از مخاطبانتان';

  @override
  String get qrName => 'نام';

  @override
  String get qrPhone => 'تلفن';

  @override
  String get qrEmail => 'ایمیل';

  @override
  String get qrOpensTheirMailApp =>
      'برنامه‌ی ایمیل او را باز می‌کند · چیزی از این‌جا فرستاده نمی‌شود';

  @override
  String get qrTo => 'گیرنده';

  @override
  String get qrSubject => 'موضوع';

  @override
  String get qrANumberNothingElse => 'یک شماره · نه چیز دیگر';

  @override
  String get qrNumber => 'شماره';

  @override
  String get qrSms => 'SMS';

  @override
  String get qrOpensTheirMessagesApp =>
      'برنامه‌ی پیامک او را باز می‌کند · چیزی از این‌جا فرستاده نمی‌شود';

  @override
  String get qrMessage => 'پیام';

  @override
  String get qrLocation => 'مکان';

  @override
  String get qrCoordinatesOnlyNoMap =>
      'فقط مختصات · از هیچ سرویس نقشه‌ای پرسیده نشد';

  @override
  String get qrLatitude => 'عرض جغرافیایی';

  @override
  String get qrLongitude => 'طول جغرافیایی';

  @override
  String get qrBitcoin => 'Bitcoin';

  @override
  String get qrAddressAndAmountNo =>
      'نشانی و مبلغ · بدون هیچ سایت پرداختی در میان';

  @override
  String get qrAddress => 'نشانی';

  @override
  String get qrAmountInBtc => 'مبلغ به BTC';

  @override
  String get qrInk => 'جوهری';

  @override
  String get qrAmber => 'کهربایی';

  @override
  String get qrViolet => 'بنفش';

  @override
  String get qrCouldNotDrawThe => 'تصویر کشیده نشد.';

  @override
  String get qrSavedToYourGallery => 'در گالری‌تان ذخیره شد';

  @override
  String get qrCouldNotSaveIt => 'ذخیره نشد. ببینید گوشی جا دارد یا نه.';

  @override
  String get qrNoAppOnThis => 'هیچ برنامه‌ای روی این گوشی تصویر را نگرفت.';

  @override
  String get qrTooMuchForOne => 'برای یک کد زیادی است. کوتاه‌ترش کنید.';

  @override
  String get qrThisIsALot =>
      'این برای یک کد زیاد است. دوربین‌های قدیمی‌تر شاید نتوانند بخوانندش.';

  @override
  String get qrPrivateQrCode => 'کد QR خصوصی';

  @override
  String get qrColour => 'رنگ';

  @override
  String get qrCopiedItLeavesThe =>
      'کپی شد. تا یک دقیقه‌ی دیگر از بریده‌دان حذف می‌شود';

  @override
  String get qrSecurity => 'امنیت';

  @override
  String get qrNone => 'هیچ';

  @override
  String get qrSaveImage => 'ذخیره‌ی تصویر';

  @override
  String qrColour2(Object name) {
    return 'رنگ ⁨$name⁩';
  }

  @override
  String get qrTypeBelowAndThe => 'پایین تایپ کنید و\nکد خودش کشیده می‌شود';

  @override
  String get qrQrCode => 'کد QR';

  @override
  String get qrHidePassword => 'پنهان کردن گذرواژه';

  @override
  String get qrShowPassword => 'نمایش گذرواژه';

  @override
  String get qrCopyPassword => 'کپی گذرواژه';

  @override
  String get requestsSentAnAttachment => 'یک پیوست فرستاد';

  @override
  String get requestsWantsToConnect => 'می‌خواهد در ارتباط باشد';

  @override
  String get requestsAccepted => 'پذیرفته شد';

  @override
  String requestsBlock(Object id) {
    return '⁨$id⁩ مسدود شود؟';
  }

  @override
  String get requestsNothingMoreFromThem =>
      'دیگر هیچ چیزی از او به شما نمی‌رسد. درخواستش و پیام‌هایش حذف می‌شوند.';

  @override
  String get requestsRequests => 'درخواست‌ها';

  @override
  String get requestsNoRequests => 'درخواستی نیست';

  @override
  String get requestsMessagesFromPeopleYou =>
      'پیام‌های کسانی که اضافه‌شان نکرده‌اید، اول این‌جا نشان داده می‌شوند.';

  @override
  String get commonAccept => 'پذیرفتن';

  @override
  String get requestsDecline => 'رد کردن';

  @override
  String get restoreThatFileIsNot => 'این فایل نسخه‌ی پشتیبان Kryfo نیست';

  @override
  String get restoreThisFileIsDamaged =>
      'این فایل آسیب دیده است و خوانده نمی‌شود';

  @override
  String get restoreTypeThePassphraseThe =>
      'عبارت عبوری را که فایل با آن ساخته شده تایپ کنید';

  @override
  String get restoreReplaceTheAccountOn => 'حساب روی این گوشی جایگزین شود؟';

  @override
  String get restoreWhatIsHereNow =>
      'آنچه الان این‌جاست، یعنی هویت، مخاطبان و پیام‌هایش، از بین می‌رود. فایل جای آن را می‌گیرد. این کار برگشت ندارد.';

  @override
  String get restoreReplaceIt => 'جایگزین کردن';

  @override
  String restoreCouldNotBeReleased(Object mine) {
    return '⁦@$mine⁩ آزاد نشد';
  }

  @override
  String restoreTheRegistryDidNot(Object mine) {
    return 'دفتر ثبت پاسخ نداد. اگر ادامه دهید، ⁦@$mine⁩ همچنان به هویتی اشاره می‌کند که این گوشی در آستانه‌ی از دست دادنش است. هر کس آن را اضافه کند برای هیچ‌کس می‌نویسد، و دیگر نمی‌شود آن نام را ثبت کرد. بهتر است آنلاین شوید و یک بار دیگر امتحان کنید.';
  }

  @override
  String get restoreRestoreAnyway => 'به هر حال بازیابی';

  @override
  String get restoreNotYet => 'هنوز نه';

  @override
  String get restoreRestored => 'بازیابی شد';

  @override
  String restoreKryfoWillCloseNow(Object haloId) {
    return 'Kryfo حالا بسته می‌شود. نماد را بزنید تا دوباره به‌عنوان ⁨$haloId⁩ باز شود.';
  }

  @override
  String get restorePrivacyKept =>
      'تنظیمات حریم خصوصی شما همراه پشتیبان برمی‌گردد. PINها هرگز منتقل نمی‌شوند: آن‌ها را دوباره در تنظیمات تعیین کنید.';

  @override
  String get restoreCheckProtections =>
      'تنظیمات در پشتیبان نیست. وقتی Kryfo دوباره باز شد، «محافظت‌های شما» را در تنظیمات بررسی کنید.';

  @override
  String get restoreReopenKryfo => 'بازگشایی Kryfo';

  @override
  String get restoreTheRestoreDidNot => 'بازیابی تمام نشد. چیزی تغییر نکرد';

  @override
  String get restoreKryfoClosesRestoreAgain =>
      'بخشی از آنچه اینجا بود جایگزین شده است. Kryfo حالا بسته می‌شود. دوباره بازش کنید و فایل را یک بار دیگر بازیابی کنید.';

  @override
  String get restoreThisIdentity => 'این هویت';

  @override
  String get restoreMoveYourKryfoHere => 'Kryfo خود را به این‌جا بیاورید';

  @override
  String restoreThisBackupIsRestoring(Object name) {
    return 'این نسخه‌ی پشتیبانِ ⁨$name⁩ است. با بازیابی‌اش، آن هویت به این دستگاه منتقل می‌شود.';
  }

  @override
  String restoreThisBackupMadeOn(Object name, Object date, Object time) {
    return 'این نسخه‌ی پشتیبانِ ⁨$name⁩ است، ساخته‌شده در ⁨$date⁩ ساعت ⁨$time⁩. با بازیابی‌اش، آن هویت به این دستگاه منتقل می‌شود.';
  }

  @override
  String restoreItHoldsOfPhotos(Object mb) {
    return 'شامل ⁨$mb⁩ عکس، پیام صوتی و فایل است. ممکن است چند دقیقه طول بکشد. برنامه را باز نگه دارید.';
  }

  @override
  String get restoreWhatFollows => 'آنچه می‌آید';

  @override
  String get restoreYourNameYourCode => 'نام شما، کد شما، و همه‌ی مخاطبان.';

  @override
  String get restoreEveryConversationBackTo =>
      'همه‌ی گفت‌وگوها، از همان ابتدا.';

  @override
  String get restoreYourPhotosVoiceNotes =>
      'عکس‌ها، پیام‌های صوتی و فایل‌هایتان.';

  @override
  String restoreYourPhotosVoiceNotesCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'عکس‌ها، پیام‌های صوتی و فایل‌هایتان · ⁨$countString⁩.',
    );
    return '$_temp0';
  }

  @override
  String get restoreYourOnionAddressSo =>
      'نشانی onion شما، تا کسانی که مستقیم به شما می‌رسند همچنان برسند.';

  @override
  String get restoreAnythingSentToYou =>
      'هر چه وقتی گوشی قبلی خاموش بود برایتان فرستاده شده، تا چهارده روز پس از ارسال.';

  @override
  String get restoreYourSupporterBadgeIf => 'نشان هوادار شما، اگر داشته باشید.';

  @override
  String get restoreWhatDoesnT => 'آنچه نمی‌آید';

  @override
  String get restoreTheOldPhoneStops =>
      'گوشی قبلی از همان لحظه‌ای که از این‌جا چیزی بفرستید، دیگر چیزی دریافت نمی‌کند. اولین پیامی که از این دستگاه بفرستید آخرین پیامی است که گوشی قبلی می‌تواند دنبال کند، و هر چه بعد از آن به آن برسد، آن‌جا خوانده نمی‌شود و این‌جا هم منتظر شما نیست.';

  @override
  String get restoreIfThePhoneThis =>
      'اگر گوشی‌ای که این فایل از آن آمده هنوز استفاده می‌شود، پیش از ادامه، استفاده از Kryfo را روی آن کنار بگذارید. دو گوشی روی یک Kryfo، روی هر دو پیام گم می‌کنند.';

  @override
  String get restoreNotificationsNeedSettingUp =>
      'اعلان‌ها باید روی این دستگاه دوباره تنظیم شوند.';

  @override
  String get restoreMoveItHere => 'انتقال به این‌جا';

  @override
  String get restoreNotNow => 'فعلاً نه';

  @override
  String get restoreRestore => 'بازیابی';

  @override
  String get restoreFromABackupFile => 'از فایل پشتیبان';

  @override
  String get restoreABackupBringsBack =>
      'نسخه‌ی پشتیبان هویت و مخاطبان شما را برمی‌گرداند، و پیام‌هایی را که هنگام ساختن فایل روی گوشی بودند. هر چه بعد از آن گفته شده در آن نیست.';

  @override
  String get restoreTheFile => 'فایل';

  @override
  String get restorePickTheBackupFile => 'انتخاب فایل پشتیبان';

  @override
  String get restoreThePassphrase => 'عبارت عبور';

  @override
  String get restoreTheOneTheFile => 'همانی که فایل با آن ساخته شد';

  @override
  String get restoreWhatComesBack => 'آنچه برمی‌گردد';

  @override
  String get restoreChecking => 'در حال بررسی…';

  @override
  String get restoreCheckTheFile => 'بررسی فایل';

  @override
  String get restoreReleasingYourHandle => 'در حال آزاد کردن نام کاربری‌تان…';

  @override
  String restoreMoving(Object progress) {
    return 'در حال انتقال… ⁨$progress⁩';
  }

  @override
  String get restoreRestoring => 'در حال بازیابی…';

  @override
  String get restoreNotThisOne => 'این یکی نه';

  @override
  String get restoreStopRestore => 'توقف بازیابی';

  @override
  String get restoreDateUnknown => 'تاریخ نامعلوم';

  @override
  String get restoreAnIdentity => 'یک هویت';

  @override
  String get restoreMessagesSentOrReceived =>
      'پیام‌هایی که پس از آن تاریخ فرستاده یا دریافت شده‌اند در این فایل نیستند.';

  @override
  String restoreGb(Object bytes) {
    return '⁨$bytes⁩ گیگابایت';
  }

  @override
  String restoreMb(Object bytes) {
    return '⁨$bytes⁩ مگابایت';
  }

  @override
  String get roomCreateCouldNotCreateThe => 'اتاق ساخته نشد';

  @override
  String get roomCreateBurnerRoom => 'اتاق یک‌بارمصرف';

  @override
  String get roomCreateARoomThatEnds =>
      'اتاقی که تمام می‌شود. همه با کلیدی که برای آن ساخته شده وارد می‌شوند، و وقتی تمام شود چیزی روی هیچ گوشی‌ای باقی نمی‌ماند.';

  @override
  String get roomCreateRoomName => 'نام اتاق';

  @override
  String get roomCreateEndsAfter => 'پایان پس از';

  @override
  String get roomCreateMemberCap => 'سقف اعضا';

  @override
  String roomCreateNoOnePastThe(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'هیچ‌کس بعد از ⁨$countString⁩ نفر اول',
    );
    return '$_temp0';
  }

  @override
  String roomCreateOffUpTo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'خاموش. هر کس پیوند را داشته باشد، تا ⁨$countString⁩ نفر',
    );
    return '$_temp0';
  }

  @override
  String roomCreateThisRoomAndEverything(Object expiryWords) {
    return 'این اتاق و هر چه در آن است، ⁨$expiryWords⁩ دیگر ناپدید می‌شود';
  }

  @override
  String get roomCreateCreating => 'در حال ساختن...';

  @override
  String get roomCreateCreateRoom => 'ساختن اتاق';

  @override
  String get roomLinkSendTheRoomTo => 'فرستادن اتاق برای';

  @override
  String get roomLinkTheyWillKnowThis =>
      'او می‌فهمد این اتاق از طرف شما آمده. درون آن، او هم مثل بقیه یک کلید است.';

  @override
  String get roomLinkNoContactsYet => 'هنوز مخاطبی نیست';

  @override
  String roomLinkEndsIn(Object time) {
    return 'تا پایان: ⁨$time⁩';
  }

  @override
  String get roomLinkAnyoneWithThisCan =>
      'هر کس این را داشته باشد می‌تواند تا پایان اتاق به آن بپیوندد. با کلیدی که برای همین اتاق ساخته شده وارد می‌شود، و هیچ چیزی را که پیش از آمدنش فرستاده شده نمی‌بیند.';

  @override
  String get roomLinkRoomLinkCopied => 'پیوند اتاق کپی شد';

  @override
  String get roomLinkSendToAContact => 'فرستادن برای یک مخاطب';

  @override
  String get roomLinkCopyRoomLink => 'کپی پیوند اتاق';

  @override
  String get savedVoiceNote => 'پیام صوتی';

  @override
  String get savedPhoto => 'عکس';

  @override
  String get savedSaved => 'ذخیره‌شده‌ها';

  @override
  String get savedNothingSavedYet => 'هنوز چیزی ذخیره نشده';

  @override
  String get savedChatGone => 'آن گفت‌وگو دیگر روی این گوشی نیست';

  @override
  String get savedLongPressAnyMessage =>
      'روی هر پیامی انگشت نگه دارید و «ذخیره» را بزنید تا این‌جا بماند.';

  @override
  String get savedViewInChat => 'دیدن در گفت‌وگو';

  @override
  String get savedPhoto2 => 'عکس';

  @override
  String get scanThatSNotA => 'این کد مال Kryfo نیست · همچنان رو به کد بگیرید';

  @override
  String get scanScanAKryfoQr => 'اسکن کد Kryfo';

  @override
  String get scanFlash => 'فلاش';

  @override
  String get scanPointAtAKryfo =>
      'رو به یک کد Kryfo بگیرید · چیزی از گوشی‌تان بیرون نمی‌رود';

  @override
  String get seenWhatWeCanSee => 'آنچه ما می‌بینیم';

  @override
  String get seenEveryMessengerClaimsPrivacy =>
      'این فهرست است، به تفکیک مسیر، همراه با نقاط ضعف. برای دلیلش روی هر ردیف بزنید.';

  @override
  String get seenHonestAboutTheLast =>
      'قفل برنامه، PIN پاک‌سازی و ذخیره‌سازی رمزگذاری‌شده برای ردیف‌های آخرند، و هیچ ابزاری شما را از کسی که گوشی باز شما را در دست دارد نجات نمی‌دهد. مدل کامل تهدید در THREAT_MODEL.md در مخزن است، که بر پایه‌ی LINDDUN نوشته شده. کد باز است، پس می‌توانید همه‌ی این‌ها را خودتان بررسی کنید.';

  @override
  String get seenHidden => 'پنهان';

  @override
  String get seenNever => 'هرگز';

  @override
  String get seenOnDevice => 'روی گوشی';

  @override
  String get seenYours => 'مال شما';

  @override
  String get seenUnaudited => 'ممیزی‌نشده';

  @override
  String get seenWhoYouTalkTo => 'با چه کسی حرف می‌زنید';

  @override
  String get seenEachConversationGetsIts =>
      'هر گفت‌وگو نشانی خودش را دارد که از هر دو کلید به دست می‌آید. رله صندوق‌های امانت بی‌ربط می‌بیند، نه یک جفت آدم.';

  @override
  String get seenWhatYouSay => 'آنچه می‌گویید';

  @override
  String get seenEndToEndEncrypted =>
      'سرتاسری رمزگذاری‌شده با الگوریتم Double Ratchet پروتکل Signal، و بعد دوباره درون یک بسته‌ی کادوپیچ مهروموم‌شده. ما نمی‌توانیم آن را بخوانیم.';

  @override
  String get seenYourIpAddress => 'نشانی IP شما';

  @override
  String get seenOurRelay => 'رله‌ی ما';

  @override
  String get seenEveryRelay => 'همه‌ی رله‌ها';

  @override
  String get seenOnOnionEverythingLeaves =>
      'در حالت onion همه‌چیز از راه Tor بیرون می‌رود و رله یک گره خروجی می‌بیند، هرگز شما را. در حالت رله، اتصال مستقیم به رله‌ی خود ما می‌رود: هیچ چیز نشانی شما را به جای دیگری نمی‌فرستد و هیچ چیز ثبت نمی‌شود، اما همان یک اتصال را ما می‌بینیم. در حالت سریع، هر رله‌ی عمومی می‌فهمد که شما وصل شده‌اید، هرچند نه به چه کسی و نه اینکه چه گفتید.';

  @override
  String get seenYourContactGraph => 'شبکه‌ی مخاطبان شما';

  @override
  String get seenKryfoDoesNotScan =>
      'Kryfo مخاطبان شما را اسکن نمی‌کند. این‌جا هیچ شماره تلفنی وجود ندارد که لو برود.';

  @override
  String get seenIntroducer => 'معرف';

  @override
  String get seenWhenAContactIntroduces =>
      'وقتی مخاطبی شما را به کسی معرفی می‌کند، همان مخاطب می‌فهمد که حالا شما دو نفر با هم در ارتباطید. هیچ‌کس دیگری نه. رله متن رمزشده می‌بیند، و هیچ سروری هرگز این شبکه را نمی‌بیند.';

  @override
  String get seenTheScamShield => 'سپر ضدکلاهبرداری';

  @override
  String get seenScamShieldRequestsOnly =>
      'روی گوشی شما با قواعدی اجرا می‌شود که همراه برنامه می‌آیند. بدون شبکه، بدون دانلود فهرست. فقط درخواست‌های پیام از غریبه‌ها را می‌خواند، هرگز آنچه یک مخاطب یا گروه برایتان می‌فرستد را نمی‌خواند.';

  @override
  String get seenBurnerRooms => 'اتاق‌های یک‌بارمصرف';

  @override
  String get seenRoomKeys => 'کلیدهای اتاق';

  @override
  String get seenYouJoinARoom =>
      'با کلیدی که برای همان اتاق ساخته شده به آن می‌پیوندید، پس کسانی که درون آن هستند چیزی نمی‌فهمند که جای دیگری به کار بیاید. کسانی که دیر می‌پیوندند تاریخچه‌ای نمی‌گیرند. با پایان مهلت، کلیدها، پیام‌ها و رسانه‌ها نابود می‌شوند.';

  @override
  String get seenLinkPreviews => 'پیش‌نمایش پیوند';

  @override
  String get seenOverTor => 'از راه Tor';

  @override
  String get seenAPreviewIsFetched =>
      'پیش‌نمایش را فرستنده، از راه Tor، می‌گیرد و درون پیام رمزگذاری‌شده سفر می‌کند. گوشی گیرنده هیچ درخواستی نمی‌فرستد. وب‌سایت فقط می‌فهمد کسی با Tor صفحه‌ای خواسته، نه چیز دیگری. هیچ تصویری هرگز بارگذاری نمی‌شود، و پیوند یک غریبه متن ساده می‌ماند.';

  @override
  String get seenASeizedUnlockedPhone => 'گوشی توقیف‌شده با قفل باز';

  @override
  String get seenIfSomeoneHoldsYour =>
      'اگر کسی گوشی باز شما را در دست داشته باشد، پیام‌هایتان را می‌خواند. قفل برنامه، PIN پاک‌سازی و ذخیره‌سازی رمزگذاری‌شده پیش از آن لحظه کمک می‌کنند، نه بعد از آن.';

  @override
  String get seenTheCryptoItself => 'خود رمزنگاری';

  @override
  String get seenTheRatchetAndStorage =>
      'لایه‌های ratchet و ذخیره‌سازی استاندارد هستند. لایه‌ای که آن‌ها را به هم وصل می‌کند مال ماست و هیچ‌کس مستقلی آن را بازبینی نکرده. این نرم‌افزار در مرحله‌ی آلفا است.';

  @override
  String get seenOnion => 'Onion';

  @override
  String get seenRelay => 'رله';

  @override
  String get seenFast => 'سریع';

  @override
  String get settingsWipeKryfo => 'Kryfo پاک شود؟';

  @override
  String get settingsIdentityMessagesContactsAnd =>
      'هویت، پیام‌ها، مخاطبان و تنظیمات روی این گوشی. برای همیشه از بین می‌روند، مگر نسخه‌ی پشتیبان داشته باشید.';

  @override
  String get commonContinue => 'ادامه';

  @override
  String settingsTypeWipeToConfirm(Object word) {
    return 'برای تأیید، «⁨$word⁩» را تایپ کنید';
  }

  @override
  String get settingsTheLastStepNothing =>
      'آخرین مرحله. هیچ چیز از آن جان سالم به در نمی‌برد.';

  @override
  String get settingsWipeWord => 'پاک';

  @override
  String get settingsWipeKryfo2 => 'پاک کردن Kryfo';

  @override
  String get settingsYourProtections => 'محافظت‌های شما';

  @override
  String get settingsTorRouting => 'مسیریابی Tor';

  @override
  String get settingsConnecting => 'در حال اتصال';

  @override
  String get settingsOffMode => 'خاموش · حالت رله';

  @override
  String get settingsOffFastMode => 'خاموش · حالت سریع';

  @override
  String get settingsAppLock => 'قفل برنامه';

  @override
  String get settingsBlockedByAndroid => 'مسدود از سوی اندروید';

  @override
  String get settingsSpeedPrivacy => 'سرعت و حریم خصوصی';

  @override
  String get settingsFast => 'سریع';

  @override
  String get settingsRelay1Hop => 'رله · یک گام';

  @override
  String get settingsOnion3Hops => 'Onion · سه گام';

  @override
  String get settingsGettingMessages => 'دریافت پیام‌ها';

  @override
  String settingsPreviewHidden(Object deliveryModeName) {
    return '⁨$deliveryModeName⁩ · پیش‌نمایش پنهان';
  }

  @override
  String settingsPreviewShown(Object deliveryModeName) {
    return '⁨$deliveryModeName⁩ · پیش‌نمایش نمایان';
  }

  @override
  String get settingsRunInBackground => 'اجرا در پس‌زمینه';

  @override
  String get settingsSoMessagesArrive => 'تا پیام‌ها برسند';

  @override
  String get settingsTransport => 'انتقال';

  @override
  String get settingsWhatTheNetworkIs => 'شبکه چه می‌کند';

  @override
  String get settingsBlocked => 'مسدودشده‌ها';

  @override
  String get settingsAcceptIntroductions => 'پذیرفتن معرفی‌ها';

  @override
  String get settingsFriendsCanIntroduceYou =>
      'دوستان می‌توانند شما را به دوستانشان معرفی کنند';

  @override
  String get settingsScamShield => 'سپر ضدکلاهبرداری';

  @override
  String get settingsScamShieldHint =>
      'فقط روی گوشی شما بررسی می‌شود، چیزی از آن بیرون نمی‌رود';

  @override
  String get settingsLightTheme => 'پوسته‌ی روشن';

  @override
  String get settingsSameProtectionBrighter => 'همان محافظت، روشن‌تر';

  @override
  String get settingsAppearance => 'ظاهر';

  @override
  String get settingsAccentColour => 'رنگ تأکیدی';

  @override
  String get settingsColoursAndWallpaper => 'رنگ‌ها و تصویر زمینه';

  @override
  String get settingsAppLock2 => 'قفل برنامه';

  @override
  String get settingsYourPinAndA => 'PIN شما و حفاظت پیشرفته';

  @override
  String get settingsPinWipePin => 'PIN · PIN پاک‌سازی';

  @override
  String get settingsBackUpIdentity => 'پشتیبان‌گیری از هویت';

  @override
  String get settingsEncryptedFile => 'فایل رمزگذاری‌شده';

  @override
  String get settingsRestoreFromBackup => 'بازیابی از نسخه‌ی پشتیبان';

  @override
  String get settingsReplaceCurrent => 'جایگزینی حساب فعلی';

  @override
  String get settingsWhyKryfo => 'چرا Kryfo';

  @override
  String get settingsHowItProtectsYou => 'چطور از شما محافظت می‌کند';

  @override
  String get settingsResetMyInviteLink => 'بازنشانی پیوند دعوتم';

  @override
  String get settingsOldLinksAndCodes =>
      'پیوندها و کدهای قدیمی برای همه از کار می‌افتند';

  @override
  String get settingsResetInviteLink => 'پیوند دعوت بازنشانی شود؟';

  @override
  String get settingsAnyoneWithAnOld =>
      'هر کس کد یا پیوند قدیمی دارد، دیگر از هیچ مسیری نمی‌تواند به شما برسد. کسانی که آن را دارند ولی هرگز استفاده نکرده‌اند، باید از شما یکی تازه بگیرند. مخاطبان، گفت‌وگوها و تاریخچه می‌مانند.';

  @override
  String get settingsReset => 'بازنشانی';

  @override
  String get settingsInviteResetShareThe =>
      'دعوت بازنشانی شد · کد تازه را هم‌رسانی کنید';

  @override
  String get settingsWhatWeCanSee => 'آنچه ما می‌بینیم';

  @override
  String get settingsTheHonestList => 'فهرست صادقانه';

  @override
  String get settingsVersion => 'نسخه';

  @override
  String get settings030Alpha => '0.5.2 · آلفا';

  @override
  String get settingsReportAnIssue => 'گزارش مشکل';

  @override
  String get settingsReportInKryfo => 'نوشتن در Kryfo';

  @override
  String get settingsReportInKryfoSub =>
      'گفت‌وگو با Marios. می‌توانید ناشناس بنویسید.';

  @override
  String get settingsReportByEmail => 'فرستادن ایمیل';

  @override
  String get settingsReportByEmailSub =>
      'gnosiworks@proton.me، از برنامه‌ی ایمیل شما';

  @override
  String get settingsBugOrSecurityFlaw => 'باگ یا نقص امنیتی';

  @override
  String get settingsOpenSource => 'متن‌باز';

  @override
  String get settingsLinkCopied => 'پیوند کپی شد';

  @override
  String get settingsTheOfflineMapIn =>
      'نقشه‌ی آفلاین در ابزارها از Natural Earth (مالکیت عمومی) کشیده شده است. نام شهرها از GeoNames، geonames.org، تحت مجوز CC BY 4.0 است.';

  @override
  String get settingsNotIndependentlyAuditedPre =>
      'به‌طور مستقل ممیزی نشده. آلفا: برای آزمایش خوب است، هنوز نه برای استفاده‌های پرمخاطره.';

  @override
  String get settingsFollowTitle => 'دنبال کردن GnosiWorks (سازنده)';

  @override
  String get settingsFollowBrowserNote =>
      'در مرورگر شما، بیرون از Kryfo باز می‌شود.';

  @override
  String get settingsFollowOpen => 'باز کردن';

  @override
  String settingsFollowOn(Object name) {
    return 'دنبال کردن در ⁨$name⁩، بیرون از Kryfo';
  }

  @override
  String get settingsDangerZone => 'منطقه‌ی خطر';

  @override
  String get settingsWipeKryfoFromThis => 'پاک‌سازی کامل Kryfo از این گوشی';

  @override
  String get toolsMoreTools => 'ابزارهای بیشتر';

  @override
  String get toolsMakeAPrivateQr => 'ساختن کد QR خصوصی';

  @override
  String get toolsLinksWiFiContacts =>
      'پیوندها، Wi-Fi، مخاطبان و بیشتر. آفلاین ساخته می‌شود';

  @override
  String get toolsLockAFile => 'قفل کردن یک فایل';

  @override
  String get toolsWithAPasswordOpens => 'با گذرواژه. با age همه‌جا باز می‌شود';

  @override
  String get toolsOpenALockedFile => 'باز کردن فایل قفل‌شده';

  @override
  String get toolsAnyAgeFileSomeone => 'هر فایل age که کسی برایتان فرستاده';

  @override
  String get toolsWorksOfflineNoContacts =>
      'آفلاین کار می‌کند · مخاطب لازم نیست';

  @override
  String get toolsUsefulFrom => 'کاربردی از';

  @override
  String get toolsTheFirstMinute => 'همان دقیقه‌ی اول.';

  @override
  String get toolsEverythingHereHappensOn =>
      'همه‌چیز این‌جا روی همین گوشی انجام می‌شود. هیچ چیز بارگذاری نمی‌شود، و لازم نیست کس دیگری Kryfo داشته باشد.';

  @override
  String get toolsWhatDoesThisPhoto => 'این عکس چه می‌داند؟';

  @override
  String get toolsPlacePhoneTime => 'مکان · گوشی · زمان';

  @override
  String get toolsPickAPhotoAnd =>
      'یک عکس یا ویدیو انتخاب کنید تا ببینید چه چیزهایی را لو می‌دهد، بعد همه‌اش را با یک ضربه پاک کنید. می‌توانید آن را از گالری هم با Kryfo هم‌رسانی کنید.';

  @override
  String get toolsPickAPhoto => 'انتخاب عکس';

  @override
  String get toolsVideo => 'ویدیو';

  @override
  String get transportTransport => 'انتقال';

  @override
  String get transportNothingHereLeavesThe =>
      'هیچ چیز این‌جا از گوشی بیرون نمی‌رود. همان وضعیتی است که موتور برای تصمیم‌گیری به کار می‌برد.';

  @override
  String get transportStayingAlive => 'زنده می‌ماند';

  @override
  String get transportCanSend => 'امکان ارسال';

  @override
  String get commonYes => 'بله';

  @override
  String get transportNotYet => 'هنوز نه';

  @override
  String get transportOnline => 'آنلاین';

  @override
  String get transportOffline => 'آفلاین';

  @override
  String get transportQueuedToSend => 'در صف ارسال';

  @override
  String get transportOnionPublished => 'Onion منتشر شد';

  @override
  String transportYes(Object uploads) {
    return 'بله (⁨$uploads⁩)';
  }

  @override
  String transportTryingS(Object pubFor) {
    return '⁨$pubFor⁩ ثانیه در تلاش';
  }

  @override
  String transportBenchedS(Object r) {
    return '⁨$r⁩ ثانیه در مکث';
  }

  @override
  String transportFails(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$countString⁩ شکست',
      one: '⁨$countString⁩ شکست',
    );
    return '$_temp0';
  }

  @override
  String get transportOk => 'سالم';

  @override
  String get transportRelaySubscriptions => 'اشتراک‌های رله';

  @override
  String get transportLastSent => 'آخرین ارسال';

  @override
  String get transportNever => 'هرگز';

  @override
  String transportSAgo(Object sx) {
    return '⁨$sx⁩ ثانیه پیش';
  }

  @override
  String get transportLastReceived => 'آخرین دریافت';

  @override
  String transportSAgo2(Object rx) {
    return '⁨$rx⁩ ثانیه پیش';
  }

  @override
  String get transportWithNoContactsThe =>
      'بدون مخاطب، برنامه در هیچ نشانی رله‌ای مشترک نمی‌شود، پس هیچ پیامی نمی‌تواند به شما برسد. برای رفعش، کد کسی را اسکن کنید.';

  @override
  String get transportSendAnythingWaitingNow => 'ارسال فوری موارد در انتظار';

  @override
  String get transportSending => 'در حال ارسال…';

  @override
  String get transportNothingLeftWaiting => 'چیزی در انتظار نمانده';

  @override
  String transportStillWaiting(Object count) {
    return 'هنوز در انتظار: $count';
  }

  @override
  String get transportOff => 'خاموش';

  @override
  String get transportStarting => 'در حال شروع';

  @override
  String get transportBootstrapped => 'راه‌اندازی شد';

  @override
  String get transportPublishingAddress => 'انتشار نشانی';

  @override
  String get transportReachable => 'در دسترس';

  @override
  String get transportOurRelayOnion => 'رله‌ی ما (onion)';

  @override
  String get transportNever2 => 'هرگز';

  @override
  String get transportJustNow => 'همین الان';

  @override
  String transportMAgo(Object inMinutes) {
    return '⁨$inMinutes⁩ دقیقه پیش';
  }

  @override
  String transportHAgo(Object inHours) {
    return '⁨$inHours⁩ ساعت پیش';
  }

  @override
  String transportDAgo(Object inDays) {
    return '⁨$inDays⁩ روز پیش';
  }

  @override
  String transportM(Object inMinutes) {
    return '⁨$inMinutes⁩ دقیقه';
  }

  @override
  String transportHM(Object inHours, Object d) {
    return '⁨$inHours⁩ ساعت ⁨$d⁩ دقیقه';
  }

  @override
  String transportD(Object inDays) {
    return '⁨$inDays⁩ روز';
  }

  @override
  String transportMb(Object b) {
    return '⁨$b⁩ مگابایت';
  }

  @override
  String get transportYesCheckedJustNow => 'بله · همین الان بررسی شد';

  @override
  String transportNoLast(Object ago) {
    return 'نه · آخرین بار ⁨$ago⁩';
  }

  @override
  String get transportLastMessageIn => 'آخرین پیام دریافتی';

  @override
  String get transportBatteryExemption => 'استثنای باتری';

  @override
  String get transportUnknown => 'نامعلوم';

  @override
  String get transportExempt => 'مستثنا';

  @override
  String get transportNotExemptTapTo => 'مستثنا نیست · برای رفع بزنید';

  @override
  String get transportProcessUp => 'پردازه روشن';

  @override
  String get transportLastStop => 'آخرین توقف';

  @override
  String get transportStopKilled => 'سیستم به‌اجبار بستش';

  @override
  String get transportStopLowMemory => 'حافظه کم';

  @override
  String get transportStopCrashed => 'از کار افتاد';

  @override
  String get transportStopNotResponding => 'پاسخ نمی‌داد';

  @override
  String get transportStopByYou => 'شما متوقفش کردید';

  @override
  String get transportStopByPhone => 'گوشی متوقفش کرد';

  @override
  String get transportStopBySecurityApp => 'برنامهٔ امنیتی متوقفش کرد';

  @override
  String get transportStopUpdated => 'به‌روز شد';

  @override
  String get transportStopBySystem => 'سیستم متوقفش کرد';

  @override
  String get transportStopTooMuch => 'بیش از حد مصرف کرد';

  @override
  String get transportStopPermission => 'مجوز تغییر کرد';

  @override
  String get transportStopClosedItself => 'خودش بسته شد';

  @override
  String get transportStopOther => 'متوقف شد';

  @override
  String transportEngine(Object mb, Object mb2) {
    return '⁨$mb⁩ · موتور ⁨$mb2⁩';
  }

  @override
  String get transportLastRelayArrival => 'آخرین دریافت از رله';

  @override
  String get transportLastCheckIn => 'آخرین سرکشی';

  @override
  String get transportNoneYet => 'هنوز هیچ';

  @override
  String get transportLastTorReconnect => 'آخرین اتصال دوباره‌ی Tor';

  @override
  String get transportCatchUpByRelay => 'همگام‌سازی هر رله';

  @override
  String get transportControlPort => 'درگاه کنترل';

  @override
  String transportDialsTimeouts(int dials, int timeouts) {
    final intl.NumberFormat dialsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String dialsString = dialsNumberFormat.format(dials);
    final intl.NumberFormat timeoutsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String timeoutsString = timeoutsNumberFormat.format(timeouts);

    String _temp0 = intl.Intl.pluralLogic(
      dials,
      locale: localeName,
      other: '⁨$dialsString⁩ تلاش اتصال',
      one: '⁨$dialsString⁩ تلاش اتصال',
    );
    String _temp1 = intl.Intl.pluralLogic(
      timeouts,
      locale: localeName,
      other: '⁨$timeoutsString⁩ اتمام مهلت',
      one: '⁨$timeoutsString⁩ اتمام مهلت',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get transportJobRuns => 'اجراهای کار';

  @override
  String transportLast(Object jobRuns, Object ago) {
    return '⁨$jobRuns⁩ · آخرین ⁨$ago⁩';
  }

  @override
  String get transportQuietStretches => 'بازه‌های سکوت';

  @override
  String get transportNone => 'هیچ';

  @override
  String get transportClearThisRecord => 'حذف این سابقه';

  @override
  String get transportNothingYetThisProcess => 'در این پردازه هنوز چیزی نیست';

  @override
  String transportM2(Object mins) {
    return '⁨$mins⁩ دقیقه';
  }

  @override
  String transportHM2(Object mins, Object mins2) {
    return '⁨$mins⁩ ساعت ⁨$mins2⁩ دقیقه';
  }

  @override
  String transportTo(Object t, Object t2) {
    return '⁨$t⁩ تا ⁨$t2⁩';
  }

  @override
  String vouchersVouchedBy(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'توصیه‌شده توسط ⁨$countString⁩ نفر',
      one: 'توصیه‌شده توسط ⁨$countString⁩ نفر',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperAtmosphere => 'حال‌وهوا';

  @override
  String get wallpaperJustForYouThey => 'فقط برای شما. او مال خودش را می‌بیند.';

  @override
  String get wallpaperYourPhoto => 'عکس شما';

  @override
  String get wallpaperDefault => 'پیش‌فرض';

  @override
  String get wallpaperNotSet => 'تصویر زمینه تنظیم نشد. دوباره امتحان کنید.';

  @override
  String get wallpaperFromYourPhotos => 'از عکس‌هایتان';

  @override
  String get wallpaperKeepIt => 'همین بماند';

  @override
  String get whyKryfoWhyKryfo => 'چرا Kryfo';

  @override
  String get whyKryfoKryfoKreeFoGreek =>
      'Kryfo · کری‌فو · در یونانی یعنی پنهان.\nجایی آرام برای حرف زدن، ساخته‌شده طوری که هیچ‌کس تماشا نکند.';

  @override
  String get whyKryfoRoutedThroughTor => 'مسیریابی از راه Tor';

  @override
  String get whyKryfoByDefaultEveryMessage =>
      'به‌طور پیش‌فرض هر پیام از راه Tor سفر می‌کند، زنجیره‌ای از رله‌ها. هیچ‌کس، نه ما و نه شبکه‌ی شما، نمی‌تواند ببیند با چه کسی حرف می‌زنید یا کجا هستید.';

  @override
  String get whyKryfoEndToEndEncrypted => 'رمزگذاری سرتاسری';

  @override
  String get whyKryfoMessagesAreSealedWith =>
      'پیام‌ها با کلیدهایی مهروموم می‌شوند که فقط شما و کسی که با او حرف می‌زنید دارید. ما نمی‌توانیم آن‌ها را بخوانیم.';

  @override
  String get whyKryfoNoServersHoldingYour =>
      'هیچ سروری زندگی شما را نگه نمی‌دارد';

  @override
  String get whyKryfoNoAccountNoPhone =>
      'نه حساب کاربری، نه شماره تلفن، نه سرور مرکزی‌ای که گفت‌وگوهایتان را ذخیره کند. آن‌ها روی همین گوشی زندگی می‌کنند و در حافظه رمزگذاری‌شده‌اند.';

  @override
  String get whyKryfoNothingLeaks => 'هیچ چیز نشت نمی‌کند';

  @override
  String get whyKryfoNoReadReceiptsOr =>
      'نه رسید خواندن و نه نشانه‌ی «در حال نوشتن» به کسی داده نمی‌شود، و هیچ فهرست مخاطبی بارگذاری نمی‌شود. فراداده همان چیزی است که بیشتر برنامه‌ها نشت می‌دهند. Kryfo طوری ساخته شده که ندهد.';

  @override
  String get whyKryfoVerifyItIsReally => 'مطمئن شوید واقعاً خودش است';

  @override
  String get whyKryfoCompareASafetyNumber =>
      'شماره‌ی امنیتی را حضوری یا از راهی که به آن اعتماد دارید مقایسه کنید، تا بدانید کسی خودش را جای مخاطبتان جا نزده.';

  @override
  String get whyKryfoTheHonestPart => 'بخش صادقانه';

  @override
  String get whyKryfoKryfoIsPreAlpha =>
      'Kryfo در مرحلهٔ آلفا است و ممیزی نشده. رمزنگاری واقعی است، اما هنوز هیچ متخصص بیرونی آن را بررسی نکرده، پس فعلاً جایی که امنیتتان به آن بستگی دارد به آن تکیه نکنید.';

  @override
  String get cleanerLocation => 'مکان';

  @override
  String get cleanerAlreadyBlankedByAndroid => 'اندروید از قبل خالی‌اش کرده';

  @override
  String get cleanerPhoneModel => 'مدل گوشی';

  @override
  String get cleanerTimeTaken => 'زمان عکاسی';

  @override
  String get cleanerSerialNumber => 'شماره‌ی سریال';

  @override
  String get cleanerOwnerName => 'نام مالک';

  @override
  String get cleanerHiddenThumbnail => 'تصویر کوچک پنهان';

  @override
  String get cleanerContentCredentials => 'اعتبارنامه‌ی محتوا';

  @override
  String get cleanerDataAfterThePicture => 'داده‌ی بعد از تصویر';

  @override
  String cleaner1OtherField(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$countString⁩ فیلد دیگر',
      one: '⁨$countString⁩ فیلد دیگر',
    );
    return '$_temp0';
  }

  @override
  String get lockWordsFourRandomWordsBeat =>
      'چهار واژه‌ی تصادفی از یک واژه‌ی زیرکانه بهتر است.';

  @override
  String lockWordsTooShortAtLeast(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'خیلی کوتاه است. دست‌کم ⁨$countString⁩ کاراکتر.',
      one: 'خیلی کوتاه است. دست‌کم ⁨$countString⁩ کاراکتر.',
    );
    return '$_temp0';
  }

  @override
  String get lockWordsWeakWhoeverGetsThe =>
      'ضعیف. هر کس فایل را به دست بیاورد، می‌تواند هر قدر سریع که بخواهد حدس بزند.';

  @override
  String get lockWordsFairLongerIsStronger => 'متوسط. بلندتر، قوی‌تر.';

  @override
  String get lockWordsStrongFourRandomWords =>
      'قوی. چهار واژه‌ی تصادفی از یک واژه‌ی زیرکانه بهتر است.';

  @override
  String photoStoryKm(Object m) {
    return '⁨$m⁩ کیلومتر';
  }

  @override
  String photoStory1Metre(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$countString⁩ متر',
      one: '⁨$countString⁩ متر',
    );
    return '$_temp0';
  }

  @override
  String get photoStoryFarFromAnyTown => 'دور از هر شهری';

  @override
  String photoStoryNear(Object where) {
    return 'نزدیک ⁨$where⁩';
  }

  @override
  String photoStoryAboutKmFrom(Object near, Object where) {
    return 'حدود ⁨$near⁩ کیلومتری ⁨$where⁩';
  }

  @override
  String photoStoryS(Object s) {
    return '⁨$s⁩ ثانیه';
  }

  @override
  String photoStory1S(Object s) {
    return '۱/⁨$s⁩ ثانیه';
  }

  @override
  String get photoStoryNotAKindKryfo => 'نوعی نیست که Kryfo بتواند بخواند.';

  @override
  String get photoStorySoItWillNot => 'پس حدس نمی‌زند.';

  @override
  String get photoStoryThisFileIsDamaged => 'این فایل آسیب دیده یا ناقص است.';

  @override
  String get photoStoryKryfoCouldNotRead =>
      'Kryfo نتوانست آن را تا آخر بخواند.';

  @override
  String get photoStoryWhereItWasRecorded => 'کجا ضبط شده';

  @override
  String get photoStoryWhereItWasTaken => 'کجا گرفته شده';

  @override
  String photoStoryLocation(Object coordsLine) {
    return 'مکان: ⁦$coordsLine⁩';
  }

  @override
  String photoStoryHeightAboveTheSea(Object fix) {
    return 'ارتفاع از سطح دریا: ⁨$fix⁩ متر';
  }

  @override
  String get photoStoryLocationHiddenByAndroid => 'مکان را اندروید پنهان کرده';

  @override
  String get photoStoryAndroidBlanksItWhen =>
      'وقتی عکسی این‌طور انتخاب شود، اندروید آن را خالی می‌کند. هم‌رسانی عکس به Kryfo از گالری معمولاً آن را نگه می‌دارد. نسخه‌ی داخل گالری‌تان شاید هنوز آن را داشته باشد.';

  @override
  String get photoStoryLocationBlankedByAndroid =>
      'مکان: پیش از آنکه Kryfo آن را ببیند، اندروید خالی‌اش کرده بود';

  @override
  String photoStoryF(Object r) {
    return 'f/⁨$r⁩';
  }

  @override
  String get photoStoryWhatTookIt => 'با چه گرفته شده';

  @override
  String photoStoryPhoneOrCamera(Object phone) {
    return 'گوشی یا دوربین: ⁨$phone⁩';
  }

  @override
  String get photoStoryWhenItWasRecorded => 'کی ضبط شده';

  @override
  String get photoStoryToTheSecondWith => 'دقیق تا ثانیه، با منطقه‌ی زمانی';

  @override
  String get photoStoryToTheSecond => 'دقیق تا ثانیه';

  @override
  String photoStoryTime(Object dateFormat) {
    return 'زمان: ⁨$dateFormat⁩';
  }

  @override
  String get photoStoryLens => 'لنز';

  @override
  String photoStoryLens2(Object lens) {
    return 'لنز: ⁨$lens⁩';
  }

  @override
  String get photoStorySoftware => 'نرم‌افزار';

  @override
  String photoStorySoftware2(Object software) {
    return 'نرم‌افزار: ⁨$software⁩';
  }

  @override
  String get photoStorySerialNumber => 'شماره‌ی سریال';

  @override
  String photoStorySerialNumber2(Object serial) {
    return 'شماره‌ی سریال: ⁨$serial⁩';
  }

  @override
  String get photoStoryOwnerName => 'نام مالک';

  @override
  String photoStoryOwner(Object r) {
    return 'مالک: ⁨$r⁩';
  }

  @override
  String get photoStoryHiddenThumbnail => 'تصویر کوچک پنهان';

  @override
  String get photoStoryASmallCopyOf =>
      'نسخه‌ای کوچک از تصویر، درون فایل. می‌تواند نشان دهد برش چه چیزی را حذف کرده';

  @override
  String get photoStoryMakerNotes => 'یادداشت‌های سازنده';

  @override
  String get photoStoryMakerNotesABlock =>
      'یادداشت‌های سازنده: بلوکی که فقط سازنده می‌تواند بخواند';

  @override
  String get photoStoryEditingHistory => 'تاریخچه‌ی ویرایش';

  @override
  String get photoStoryXmpEditingHistoryAnd =>
      'XMP: تاریخچه‌ی ویرایش و برچسب‌ها';

  @override
  String get photoStoryCaptions => 'شرح‌ها';

  @override
  String get photoStoryIptcCaptionsAndCredits =>
      'IPTC: شرح‌ها و نام پدیدآورندگان';

  @override
  String get photoStoryComment => 'توضیح';

  @override
  String get photoStoryAWrittenComment => 'یک توضیح نوشته‌شده';

  @override
  String get photoStoryContentCredentials => 'اعتبارنامه‌ی محتوا';

  @override
  String get photoStorySecondPicture => 'تصویر دوم';

  @override
  String get photoStoryASecondPictureInside => 'تصویر دومی درون فایل';

  @override
  String get photoStoryMotionVideo => 'ویدیوی متحرک';

  @override
  String get photoStoryAShortVideoInside => 'یک ویدیوی کوتاه درون فایل';

  @override
  String get photoStorySaveTime => 'زمان ذخیره';

  @override
  String get photoStoryTheTimeItWas => 'آخرین باری که ذخیره شده';

  @override
  String get photoStoryTimeStamps => 'برچسب‌های زمانی';

  @override
  String get photoStoryCreationTimeStamps => 'برچسب‌های زمان ساخت';

  @override
  String get photoStoryDataAfterThePicture => 'داده‌ی بعد از تصویر';

  @override
  String photoStoryDataAfterTheEnd(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'داده بعد از پایان تصویر: ⁨$countString⁩ بایت',
      one: 'داده بعد از پایان تصویر: ⁨$countString⁩ بایت',
    );
    return '$_temp0';
  }

  @override
  String photoStoryTextField(Object k) {
    return 'فیلد متنی: ⁨$k⁩';
  }

  @override
  String photoStoryVideoTag(Object k) {
    return 'برچسب ویدیو: ⁨$k⁩';
  }

  @override
  String photoStoryAlso(Object k) {
    return 'همچنین: ⁨$k⁩';
  }

  @override
  String photoStoryCameraSettingsFlashFocus(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$countString⁩ تنظیم دوربین (فلاش، فوکوس، نوردهی)',
      one: '⁨$countString⁩ تنظیم دوربین (فلاش، فوکوس، نوردهی)',
    );
    return '$_temp0';
  }

  @override
  String photoStory1MoreField(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$countString⁩ فیلد دیگر',
      one: '⁨$countString⁩ فیلد دیگر',
    );
    return '$_temp0';
  }

  @override
  String get photoStoryCameraSettings => 'تنظیمات دوربین';

  @override
  String photoStoryAccurateToAbout(Object metres) {
    return 'دقیق تا حدود ⁨$metres⁩.';
  }

  @override
  String get photoStoryEnoughToFindThe => 'برای پیدا کردن در خانه کافی است.';

  @override
  String get photoStoryEnoughToFindTheStreet =>
      'برای پیدا کردن خیابان کافی است.';

  @override
  String get photoStoryEnoughToFindTheArea => 'برای پیدا کردن محله کافی است.';

  @override
  String get photoStoryItKnowsWhereYou => 'می‌داند کجا بودید.';

  @override
  String get photoStoryDownToTheBuilding => 'تا حد ساختمان.';

  @override
  String get photoStoryAndroidHidTheLocation => 'اندروید مکان را پنهان کرد.';

  @override
  String get photoStoryTheOriginalMayStill =>
      'شاید نسخه‌ی اصلی هنوز آن را داشته باشد.';

  @override
  String get photoStoryNoLocationInThis => 'در این یکی مکانی نیست.';

  @override
  String get photoStoryItStillSaysPlenty => 'باز هم چیزهای زیادی می‌گوید.';

  @override
  String get photoStoryThisOneKnowsNothing => 'این یکی چیزی نمی‌داند.';

  @override
  String get photoStoryNothingToRemove => 'چیزی برای حذف نیست.';

  @override
  String get qrPayloadOpensALink => 'پیوندی را باز می‌کند';

  @override
  String qrPayloadOpens(Object host) {
    return '⁨$host⁩ را باز می‌کند';
  }

  @override
  String get qrPayloadShowsANote => 'یادداشتی نشان می‌دهد';

  @override
  String get qrPayloadScanToJoin => 'برای اتصال اسکن کنید';

  @override
  String qrPayloadScanToJoin2(Object oneLine) {
    return 'برای اتصال اسکن کنید · ⁨$oneLine⁩';
  }

  @override
  String get qrPayloadANetworkNameIs => 'نام شبکه حداکثر ۳۲ کاراکتر است.';

  @override
  String get qrPayloadAWiFiPassword => 'گذرواژه‌ی Wi-Fi دست‌کم ۸ کاراکتر دارد.';

  @override
  String get qrPayloadSavesAContact => 'مخاطبی را ذخیره می‌کند';

  @override
  String get qrPayloadWritesAnEmail => 'ایمیلی می‌نویسد';

  @override
  String get qrPayloadThatDoesNotLook => 'این شبیه نشانی ایمیل نیست.';

  @override
  String get qrPayloadCallsANumber => 'شماره‌ای را می‌گیرد';

  @override
  String get qrPayloadWritesAText => 'پیامکی می‌نویسد';

  @override
  String get qrPayloadOpensAMap => 'نقشه باز می‌کند';

  @override
  String get qrPayloadLatitudeRunsFrom90 =>
      'عرض جغرافیایی از منفی ۹۰ تا ۹۰ است، و طول جغرافیایی از منفی ۱۸۰ تا ۱۸۰.';

  @override
  String get qrPayloadPayThisAddress => 'به این نشانی پرداخت کنید';

  @override
  String get qrPayloadABitcoinAddressIs =>
      'نشانی bitcoin فقط از حروف و رقم تشکیل می‌شود.';

  @override
  String get qrPayloadTheAmountIsIn =>
      'مبلغ به BTC است، با حداکثر ۸ رقم اعشار.';

  @override
  String vouchTextAnd(Object names, Object names2) {
    return '⁨$names⁩ و ⁨$names2⁩';
  }

  @override
  String vouchTextAndOtherYouKnow(Object names, Object names2, int rest) {
    final intl.NumberFormat restNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String restString = restNumberFormat.format(rest);

    String _temp0 = intl.Intl.pluralLogic(
      rest,
      locale: localeName,
      other: '⁨$restString⁩ نفر دیگر',
      one: '⁨$restString⁩ نفر دیگر',
    );
    return '⁨$names⁩، ⁨$names2⁩ و $_temp0 که می‌شناسید';
  }

  @override
  String vouchTextVouchedBy(Object vouchNames) {
    return 'توصیه‌شده توسط ⁨$vouchNames⁩';
  }

  @override
  String vouchTextIntroducedBy(Object vouchNames) {
    return 'معرفی‌شده توسط ⁨$vouchNames⁩';
  }

  @override
  String vouchTextThisSharesSAddress(Object a, Object b) {
    return 'این کار نشانی ⁨$a⁩ را با ⁨$b⁩ هم‌رسانی می‌کند';
  }

  @override
  String get bootFailedKryfoCouldNotStart => 'Kryfo راه‌اندازی نشد';

  @override
  String get bootFailedThisIsAFault =>
      'این خطایی روی همین دستگاه است، نه در شبکه. Tor در آن نقشی ندارد.';

  @override
  String get bootFailedKeysDidNotAnswer =>
      'فضای نگهداری کلیدهای گوشی پاسخ نمی‌دهد. بستن و باز کردن دوبارهٔ Kryfo معمولاً مشکل را حل می‌کند.';

  @override
  String get bootFailedCloseAndReopen => 'بستن و باز کردن دوبارهٔ Kryfo';

  @override
  String get kryfoLinkTextThatLinkIsNot =>
      'این پیوندی نیست که Kryfo بتواند بخواند';

  @override
  String kryfoLinkTextAdd(Object who) {
    return '⁨$who⁩ اضافه شود؟';
  }

  @override
  String kryfoLinkTextThisIsAnInvite(Object who) {
    return 'این دعوتی برای گفت‌وگو با ⁨$who⁩ است. فقط وقتی اضافه‌اش کنید که بدانید پیوند از کجا آمده.';
  }

  @override
  String get kryfoLinkTextAddThem => 'افزودن';

  @override
  String get kryfoLinkTextNotNow => 'فعلاً نه';

  @override
  String kryfoLinkTextYouAlreadyHave(Object who) {
    return '⁨$who⁩ را از قبل دارید';
  }

  @override
  String kryfoLinkTextSomeoneElse(Object who) {
    return 'شما کسی را در گفت‌وگوهایتان ⁨$who⁩ نامیده‌اید. این پیوند از کس دیگری است. فقط وقتی اضافه‌اش کنید که بدانید از کجا آمده.';
  }

  @override
  String kryfoLinkTextJoin(Object roomName) {
    return 'پیوستن به ⁨$roomName⁩';
  }

  @override
  String get kryfoLinkTextKryfoLink => 'پیوند Kryfo';

  @override
  String kryfoLinkTextAdd2(Object who) {
    return 'افزودن ⁨$who⁩';
  }

  @override
  String get kryfoLinkTextBurnerRoom => 'اتاق یک‌بارمصرف';

  @override
  String get kryfoLinkTextThisRoomHasClosed => 'این اتاق بسته شده';

  @override
  String kryfoLinkTextClosesIn(Object time) {
    return 'تا بسته شدن: ⁨$time⁩';
  }

  @override
  String kryfoLinkTextClosesInUpTo(int cap, Object time) {
    final intl.NumberFormat capNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String capString = capNumberFormat.format(cap);

    String _temp0 = intl.Intl.pluralLogic(
      cap,
      locale: localeName,
      other: 'تا بسته شدن: ⁨$time⁩ · حداکثر ⁨$capString⁩ نفر',
    );
    return '$_temp0';
  }

  @override
  String get kryfoLinkTextJoin2 => 'پیوستن';

  @override
  String get kryfoLinkTextYouJoinUnderA =>
      'با کلیدی که برای این اتاق ساخته شده می‌پیوندید. هیچ‌کس در آن شناسه‌ی Kryfo شما را نمی‌بیند.';

  @override
  String get linkStubFetchedOverTorBy => 'از راه Tor گرفته شد · با دستگاه شما';

  @override
  String get linkStubFetchedOverTorByTheirDevice =>
      'از راه Tor گرفته شد · با دستگاه او';

  @override
  String mediaBubblesB(Object bytes) {
    return '⁨$bytes⁩ بایت';
  }

  @override
  String mediaBubblesKb(Object bytes) {
    return '⁨$bytes⁩ کیلوبایت';
  }

  @override
  String mediaBubblesMb(Object bytes) {
    return '⁨$bytes⁩ مگابایت';
  }

  @override
  String get mediaBubblesFile => 'فایل';

  @override
  String get mediaBubblesAudioUnavailable => 'صدا در دسترس نیست';

  @override
  String get mediaBubblesHidden => 'تغییر صدا';

  @override
  String get mediaBubblesPlaying => 'در حال پخش';

  @override
  String get mediaBubblesSendPhoto => 'ارسال عکس';

  @override
  String get mediaBubblesAddACaption => 'افزودن توضیح…';

  @override
  String get motionStandby => 'آماده‌باش';

  @override
  String get motionConnecting => 'در حال اتصال';

  @override
  String get motionBuilding => 'در حال ساخت';

  @override
  String get motionPublishing => 'در حال انتشار';

  @override
  String get motionReady => 'آماده';

  @override
  String get motionPreparingToConnect => 'آماده شدن برای اتصال';

  @override
  String get motionFindingAPrivatePath => 'یافتن مسیری خصوصی';

  @override
  String get motionCarvingThePath => 'هموار کردن مسیر';

  @override
  String get motionAnnouncingYourArrival => 'اعلام رسیدن شما';

  @override
  String get motionYouReAnonymous => 'ناشناس هستید';

  @override
  String get motionTorIsStartingIn =>
      'Tor در پس‌زمینه راه می‌افتد. این نمودار با شکل گرفتن اتصال روشن می‌شود.';

  @override
  String get motionMakingAFreshRoute =>
      'ساختن مسیری تازه از میان رله‌های ناشناس.';

  @override
  String get motionBouncingThroughRelaysSo =>
      'جهیدن از رله‌ای به رله‌ی دیگر تا هیچ‌کس نتواند این را تا شما ردیابی کند.';

  @override
  String get motionTellingTheNetworkYou =>
      'به شبکه می‌گوید آنلاین هستید، بی‌آنکه فاش کند کجا.';

  @override
  String get motionYourIpIsHidden =>
      'IP شما پنهان است. فقط کسانی که Kryfo شما را دارند می‌توانند به شما برسند.';

  @override
  String get motionBuilding2 => 'در حال ساخت';

  @override
  String get motionOpen => 'باز';

  @override
  String get motionLive => 'فعال';

  @override
  String motionCircuit(Object circuit) {
    return 'مدار · *⁨$circuit⁩*';
  }

  @override
  String get motionDelivered => 'رسید';

  @override
  String get motionSent => 'فرستاده شد';

  @override
  String get motion1Hop => 'یک گام';

  @override
  String get motion3Hops => 'سه گام';

  @override
  String get movedStripThisKryfoHasMoved =>
      'این Kryfo به دستگاه دیگری منتقل شده. هیچ چیزی که از این‌جا فرستاده شود به دست کسی نمی‌رسد.';

  @override
  String get navBarChats => 'گفت‌وگوها';

  @override
  String get navBarTools => 'ابزارها';

  @override
  String get navBarSupport => 'حمایت';

  @override
  String get navBarMe => 'من';

  @override
  String get pairCodePanelPuttingYourInviteIn => 'در حال آماده کردن دعوت شما';

  @override
  String get pairCodePanelYourInviteIsNot => 'دعوت شما هنوز آماده نیست';

  @override
  String get pairCodePanelReadSixDigitsOut =>
      'شش رقم را بلند بخوانید تا او بتواند شما را اضافه کند. هیچ چیز دیگری لازم نیست دست‌به‌دست شود.';

  @override
  String get pairCodePanelWorking => 'در حال کار';

  @override
  String get pairCodePanelOrMakeASix =>
      'یا یک کد شش‌رقمی بسازید تا بلند بخوانید';

  @override
  String get pairCodePanelBurned =>
      'این کد محو شد. وقتی طرف مقابل آماده بود، کد تازه‌ای بسازید.';

  @override
  String get pairCodePanelCodeCopied => 'کد کپی شد';

  @override
  String pairCodePanelBurnsIn(Object mm, Object ss) {
    return 'تا محو شدن: ⁨$mm⁩:⁨$ss⁩';
  }

  @override
  String get pairCodePanelTheyTapAddChoose =>
      'او «افزودن» را می‌زند، «کد» را انتخاب می‌کند و این‌ها را تایپ می‌کند.';

  @override
  String get pairCodePanelTheyOpenKryfoTap =>
      'او Kryfo را باز می‌کند، «افزودن» را می‌زند، «کد جفت‌سازی» را انتخاب می‌کند و این شش رقم را تایپ می‌کند. برای نفر بعدی یک کد تازه بسازید.';

  @override
  String get pairCodePanelYourWords => 'سه واژه‌ی شما';

  @override
  String get pairCodePanelAcceptOnce =>
      'درخواست او پس از اینکه شما را اضافه کند می‌رسد. فقط وقتی بپذیرید که بگوید هر چهار گروه یکی بودند.';

  @override
  String pinsPinnedMessages(Object count) {
    return 'پیام‌های سنجاق‌شده · ⁨$count⁩';
  }

  @override
  String get pinsPinnedMessages2 => 'پیام‌های سنجاق‌شده';

  @override
  String get pinsPhoto => 'عکس';

  @override
  String get pinsVoiceMessage => 'پیام صوتی';

  @override
  String get pinsMessage => 'پیام';

  @override
  String pinsToday(Object hm) {
    return 'امروز · ⁨$hm⁩';
  }

  @override
  String get pinsPinned => 'سنجاق‌شده';

  @override
  String pinsOf(Object pinsLength, Object kMaxPins) {
    return '⁨$pinsLength⁩ از ⁨$kMaxPins⁩';
  }

  @override
  String get pinsNothingPinnedHereYet =>
      'هنوز چیزی این‌جا سنجاق نشده. پیامی را نگه دارید و «سنجاق» را انتخاب کنید تا این‌جا برای همه‌ی اعضای گفت‌وگو بماند.';

  @override
  String get pinsJump => 'رفتن';

  @override
  String get pinsUnpin => 'برداشتن سنجاق';

  @override
  String previewStripFetchedOverTor(Object domainOf) {
    return '⁨$domainOf⁩ · از راه Tor گرفته شد';
  }

  @override
  String get previewStripDropThePreview => 'حذف پیش‌نمایش';

  @override
  String get previewStripAddPreview => 'افزودن پیش‌نمایش';

  @override
  String get previewStripFetchingOverTor => 'در حال گرفتن از راه Tor…';

  @override
  String toolPartsB(Object bytes) {
    return '⁨$bytes⁩ بایت';
  }

  @override
  String toolPartsKb(Object bytes) {
    return '⁨$bytes⁩ کیلوبایت';
  }

  @override
  String toolPartsMb(Object mb) {
    return '⁨$mb⁩ مگابایت';
  }

  @override
  String get torBootSplashNoShortcutsNoTraces => 'نه میان‌بری، نه ردی';

  @override
  String get torBootSplashTheNetworkThatKeeps =>
      'شبکه‌ای که حریم خصوصی شما را نگه می‌دارد در حال گرم شدن است';

  @override
  String get torBootSplashMadeOnThisPhone =>
      'روی همین گوشی ساخته شد. هیچ چیز به جایی فرستاده نمی‌شود.';

  @override
  String get torBootSplashFirstLaunchTakesA =>
      'اولین اجرا کمی طول می‌کشد · فقط هنگام شروع';

  @override
  String get torBootSplashTakingLonger => 'این بیشتر از معمول طول می‌کشد';

  @override
  String get torBootSplashHopEntry => 'ورودی';

  @override
  String get torBootSplashHopMiddle => 'میانی';

  @override
  String get torBootSplashHopExit => 'خروجی';

  @override
  String get videoBubbleNothingHereOpensThat =>
      'این‌جا چیزی آن را باز نمی‌کند · به‌جایش هم‌رسانی می‌شود';

  @override
  String videoBubbleMb(Object b) {
    return '⁨$b⁩ مگابایت';
  }

  @override
  String videoBubbleKb(Object b) {
    return '⁨$b⁩ کیلوبایت';
  }

  @override
  String get videoBubbleVideo => 'ویدیو';

  @override
  String get notificationsChannelName => 'پیام‌ها';

  @override
  String get cameraClose => 'بستن';

  @override
  String get cameraFlash => 'فلاش';

  @override
  String get cameraPhoto => 'عکس';

  @override
  String get cameraVideo => 'ویدیو';

  @override
  String get cameraRetake => 'گرفتن دوباره';

  @override
  String get seenIntroductions => 'معرفی‌ها';

  @override
  String get donateAddress => 'نشانی';

  @override
  String get donateCopy => 'کپی';

  @override
  String get donateDone => 'تمام';

  @override
  String get donateTierSupporter => 'هوادار';

  @override
  String get donateTierPatron => 'حامی';

  @override
  String get donateTierGuardian => 'نگهبان';

  @override
  String get chatBlock => 'مسدود کردن';

  @override
  String get chatDecline => 'رد کردن';

  @override
  String get chatAccept => 'پذیرفتن';

  @override
  String get bridgesConnecting => 'در حال اتصال';

  @override
  String get restoreMade => 'ساخته‌شده';

  @override
  String get restoreContacts => 'مخاطبان';

  @override
  String get restoreMessages => 'پیام‌ها';

  @override
  String get restoreAttachments => 'پیوست‌ها';

  @override
  String get restoreHiddenChats => 'گفت‌وگوهای پنهان';

  @override
  String get restoreHiddenFollow =>
      'گفت‌وگوهای پنهان شما، با یک PIN تازه‌ی گفت‌وگوهای پنهان که در پایان انتخاب می‌کنید.';

  @override
  String get restoreChooseHiddenPin =>
      'این نسخه‌ی پشتیبان گفت‌وگوهای پنهان دارد. برایشان یک PIN گفت‌وگوهای پنهان انتخاب کنید.';

  @override
  String get restoreHiddenLockFirst =>
      'گفت‌وگوهای پنهان به قفل برنامه نیاز دارند، پس اول Kryfo یک PIN مخصوص خودش می‌گیرد.';

  @override
  String get profileIdentity => 'هویت';

  @override
  String get avatarPickerShape => 'شکل';

  @override
  String get avatarPickerColour => 'رنگ';

  @override
  String get avatarPickerTurn => 'چرخش';

  @override
  String avatarPickerOption(String what, int n, int count) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$what، $nString از $countString';
  }

  @override
  String get avatarPickerYourInitial => 'حرف اول نامتان';

  @override
  String get transportStatus => 'وضعیت';

  @override
  String get transportBootstrap => 'راه‌اندازی';

  @override
  String get transportNetwork => 'شبکه';

  @override
  String get transportConnectivity => 'اتصال‌پذیری';

  @override
  String get transportRelays => 'رله‌ها';

  @override
  String get transportTraffic => 'ترافیک';

  @override
  String get transportContacts => 'مخاطبان';

  @override
  String get transportKnown => 'شناخته‌شده';

  @override
  String get transportListening => 'در حال شنود';

  @override
  String get transportMemory => 'حافظه';

  @override
  String get settingsConnected => 'متصل';

  @override
  String get settingsScreenshots => 'اسکرین‌شات‌ها';

  @override
  String get settingsBlocked2 => 'مسدود';

  @override
  String get settingsOn => 'روشن';

  @override
  String get settingsOff => 'خاموش';

  @override
  String get settingsNotifications => 'اعلان‌ها';

  @override
  String get settingsPrivacy => 'حریم خصوصی';

  @override
  String get settingsSecurity => 'امنیت';

  @override
  String get settingsBackup => 'نسخه‌ی پشتیبان';

  @override
  String get settingsVoice => 'صدا';

  @override
  String get settingsAbout => 'درباره';

  @override
  String get wallpaperGradients => 'گرادیان‌ها';

  @override
  String get wallpaperPatterns => 'طرح‌ها';

  @override
  String get wallpaperMoods => 'حس‌وحال‌ها';

  @override
  String get confirmSheetKeep => 'نگه داشتن';

  @override
  String get confirmSheetSave => 'ذخیره';

  @override
  String get confirmSheetCancel => 'لغو';

  @override
  String get bridgesFoundAVolunteer => 'داوطلبی پیدا شد، در حال اتصال';

  @override
  String get bridgesScanABridgeCode => 'اسکن کد پل';

  @override
  String get settingsBridgesForNetworksThat =>
      'پل‌ها، برای شبکه‌هایی که Tor را مسدود می‌کنند';

  @override
  String get bridgesCouldNotReachTheTor => 'دسترسی به پروژه‌ی Tor ممکن نشد';

  @override
  String get torBootSplashConnect => 'اتصال';

  @override
  String get bridgesOffline => 'آفلاین';

  @override
  String get bridgesNothingGotThrough => 'هیچ راهی جواب نداد';

  @override
  String get bridgesBridgeFromAFriend => 'پل از یک دوست';

  @override
  String get bridgesKryfoCanAskThe =>
      'Kryfo می‌تواند از پروژه‌ی Tor پلی بخواهد تا این سد را دور بزند.';

  @override
  String get bridgesNotNeededRightNow => 'فعلاً لازم نیست';

  @override
  String get bridgesBuiltInBridges => 'پل‌های داخلی';

  @override
  String get bridgesKryfoCanGetAround =>
      'Kryfo حالا می‌تواند مسدودسازی Tor را دور بزند';

  @override
  String get bridgesThatSNotABridge => 'این خط پل نیست';

  @override
  String get transportBridgeError => 'آخرین خطا';

  @override
  String get bridgesDirect => 'مستقیم';

  @override
  String get bridgesAskingTheTorProject =>
      'در حال پرسیدن از پروژه‌ی Tor که این‌جا چه جواب می‌دهد…';

  @override
  String get bridgesNoneOfTheseAre =>
      'هیچ‌کدام از این‌ها خط پلی نیست که Kryfo بفهمد.';

  @override
  String get bridgesAutomatic => 'خودکار';

  @override
  String get bridgesStraightToTor => 'مستقیم به Tor، بدون نیاز به پل';

  @override
  String get bridgesKryfoConnectsAsSoon =>
      'Kryfo به محض این‌که دوباره آنلاین شوید وصل می‌شود.';

  @override
  String get bridgesMore => 'بیشتر';

  @override
  String bridgesTryingAnotherWayOf(String attempt, String attempts) {
    return 'در حال امتحان راهی دیگر… (⁨$attempt⁩ از ⁨$attempts⁩)';
  }

  @override
  String get bridgesLookingForAVolunteer => 'در جست‌وجوی یک داوطلب';

  @override
  String get bridgesFastestWhereTorIsnt =>
      'سریع‌ترین راه، جایی که Tor مسدود نیست. Kryfo هرگز بیرون از Tor وصل نمی‌شود.';

  @override
  String get transportBridgePhase => 'مرحله';

  @override
  String get bridgesAsleepBetweenCheckIns => 'در خواب، بین سرکشی‌ها';

  @override
  String get bridgesThroughABridge => 'از راه یک پل';

  @override
  String get bridgesBuiltIn => 'داخلی';

  @override
  String get bridgesDetails => 'جزئیات';

  @override
  String get transportBridgeMode => 'پل‌ها';

  @override
  String get bridgesEgypt => 'مصر';

  @override
  String get bridgesYourBridgeCouldNot => 'پل شما راه‌اندازی نشد';

  @override
  String get bridgesKryfoStaysOfflineRather =>
      'Kryfo آفلاین می‌ماند تا بدون آن وصل نشود.';

  @override
  String get bridgesSignInToThisWifi => 'به این Wi-Fi وارد شوید';

  @override
  String get bridgesThisNetworkWantsA =>
      'این شبکه اول ورود می‌خواهد. وقتی وارد شدید، Kryfo وصل می‌شود.';

  @override
  String get bridgesWaitingForWifiSignIn => 'در انتظار ورود به Wi-Fi';

  @override
  String get bridgesOpenWifiSettings => 'باز کردن تنظیمات Wi-Fi';

  @override
  String get bridgesUsingBuiltIn => 'از راه پل‌های داخلی';

  @override
  String get bridgesUsingSnowflake => 'از راه Snowflake';

  @override
  String get bridgesUsingTorProject => 'از راه پل‌های پروژه‌ی Tor';

  @override
  String get bridgesKryfoTriesAgainOnItsOwn =>
      'Kryfo هر از گاهی خودش دوباره تلاش می‌کند.';

  @override
  String get bridgesTheTorProjectCanSuggest =>
      'پروژه‌ی Tor می‌تواند پلی پیشنهاد کند که این‌جا کار کند.';

  @override
  String get bridgesBridgeRemoved => 'پل حذف شد';

  @override
  String get bridgesUndo => 'واگرد';

  @override
  String bridgesRemoveBridgeN(String n) {
    return 'حذف پل ⁨$n⁩';
  }

  @override
  String get bridgesIran => 'ایران';

  @override
  String get bridgesTurnOnAutomatic => 'روشن کردن حالت خودکار';

  @override
  String get bridgesPasteABridgeLine => 'یک خط پل جای‌گذاری کنید';

  @override
  String get bridgesInUse => 'در حال استفاده';

  @override
  String get bridgesPasteTheLineThey =>
      'خطی را که برایتان فرستاده جای‌گذاری کنید، یا کدش را اسکن کنید. خط‌های پل را از کسانی بگیرید که می‌شناسید.';

  @override
  String get bridgesYouReOnAMode =>
      'حالت فعلی شما از Tor استفاده نمی‌کند. این انتخاب‌ها وقتی برگردید اعمال می‌شوند.';

  @override
  String get bridgesPasteOrScanALine =>
      'خطی را که کسی مورد اعتمادتان به شما داده جای‌گذاری یا اسکن کنید.';

  @override
  String get bridgesNothingYet => 'هنوز هیچ';

  @override
  String get torBootSplashIfTorIsBlocked =>
      'اگر جایی که هستید Tor مسدود یا زیر نظر است، Kryfo می‌تواند به‌جایش از راه یک پل شروع کند.';

  @override
  String get bridgesScanACode => 'اسکن کد';

  @override
  String get bridgesMyanmar => 'میانمار';

  @override
  String get bridgesSwitchToAutomatic => 'رفتن به حالت خودکار';

  @override
  String get torBootSplashTorIsBlockedHere => 'Tor این‌جا مسدود یا زیر نظر است';

  @override
  String get torBootSplashStartThroughABridge => 'شروع از راه یک پل';

  @override
  String get torBootSplashNeverTriesTorPlainly =>
      'این‌جا Kryfo هرگز Tor را مستقیم امتحان نمی‌کند. خودش پلی پیدا می‌کند که کار کند، یا می‌توانید در گام بعد پل خودتان را انتخاب کنید.';

  @override
  String get bridgesTryingAnotherWay => 'در حال امتحان راهی دیگر…';

  @override
  String get bridgesFindingAWayIn => 'در حال پیدا کردن راهی برای اتصال…';

  @override
  String get bridgesGoesThroughAVolunteer =>
      'از رایانه‌ی یک داوطلب می‌گذرد. مسدود کردنش سخت است و شروعش کند.';

  @override
  String get bridgesLetTheTorProject => 'بگذارید پروژه‌ی Tor حدس بزند';

  @override
  String get bridgesTorSeemsBlocked =>
      'به نظر می‌رسد Tor در این شبکه مسدود است';

  @override
  String get bridgesTorIsBlockedOnThis => 'Tor در این شبکه مسدود است';

  @override
  String bridgesKryfoCouldNotRead(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Kryfo نتوانست ⁨$countString⁩ مورد از این خط‌ها را بخواند',
      one: 'Kryfo نتوانست ⁨$countString⁩ مورد از این خط‌ها را بخواند',
    );
    return '$_temp0';
  }

  @override
  String get bridgesTorNoBridge => 'Tor، بدون پل';

  @override
  String get bridgesKryfoFindsAWay =>
      'Kryfo راهی پیدا می‌کند که جایی که هستید جواب بدهد.';

  @override
  String get bridgesTheTorProjectKnows =>
      'پروژه‌ی Tor برای این کشورها توصیه‌های خودش را دارد.';

  @override
  String get bridgesThisBridgeIsnTGetting => 'این پل راه پیدا نمی‌کند';

  @override
  String get bridgesBridgesTheTorProject =>
      'پل‌هایی که پروژه‌ی Tor قبلاً به شما داده.';

  @override
  String get bridgesConnectingDots => 'در حال اتصال…';

  @override
  String get bridgesNotNow => 'فعلاً نه';

  @override
  String get bridgesRussia => 'روسیه';

  @override
  String get bridgesObfs4BridgesThatCome =>
      'پل‌هایی که همراه Kryfo می‌آیند (obfs4). امتحانشان سریع است، ولی اغلب مسدودند.';

  @override
  String get bridgesYourNetworkMayBe => 'ممکن است شبکه‌ی شما محدود باشد';

  @override
  String get bridgesCheckingForMessages => 'در حال بررسی پیام‌ها…';

  @override
  String get bridgesSavedLines => 'خط‌های ذخیره‌شده';

  @override
  String get bridgesFromAFriendLower => 'از یک دوست';

  @override
  String get bridgesAlmostThere => 'چیزی نمانده';

  @override
  String get bridgesTheTorProjectSGuess => 'حدس پروژه‌ی Tor';

  @override
  String get bridgesOurRelayUsuallyGets =>
      'رله‌ی ما یک اتصال ساده است و معمولاً راه پیدا می‌کند. یا بگذارید Kryfo خودش راهی پیدا کند.';

  @override
  String get bridgesUseThisBridge => 'استفاده از این پل';

  @override
  String bridgesUseTheseBridges(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'استفاده از این ⁨$countString⁩ پل',
    );
    return '$_temp0';
  }

  @override
  String get bridgesTurkmenistan => 'ترکمنستان';

  @override
  String get transportBridgeMethod => 'روش';

  @override
  String get bridgesPointAtTheBridge => 'دوربین را رو به کد QR پل بگیرید';

  @override
  String get bridgesConnectingThroughYourBridge =>
      'در حال اتصال از راه پل شما…';

  @override
  String get bridgesThisLineIsTooLong => 'این خط برای Tor بیش از حد بلند است.';

  @override
  String get bridgesAutomaticFindsAWay =>
      'وقتی Tor مسدود است، «خودکار» خودش راهی پیدا می‌کند. برای پیدا کردن پل، اگر موافق باشید، ممکن است Kryfo از پروژه‌ی Tor بپرسد.';

  @override
  String get bridgesFromTheTorProjectLower => 'از پروژه‌ی Tor';

  @override
  String get bridgesBridgesGoDeadWithout =>
      'پل‌ها ممکن است بی‌خبر از کار بیفتند. «خودکار» می‌تواند راه دیگری پیدا کند.';

  @override
  String get bridgesHongKong => 'هنگ کنگ';

  @override
  String get bridgesWhenTorIsBlockedAutomatic =>
      'وقتی Tor مسدود است، «خودکار» از پروژه‌ی Tor می‌پرسد در کشور شما چه جواب می‌دهد.';

  @override
  String get bridgesAskTorProject => 'پرسیدن از پروژه‌ی Tor';

  @override
  String get bridgesTooLongForTor => 'برای Tor بیش از حد بلند است';

  @override
  String get bridgesCountry => 'کشور';

  @override
  String bridgesMethodFrom(String method, String from) {
    return '⁨$method⁩، ⁨$from⁩';
  }

  @override
  String get bridgesChina => 'چین';

  @override
  String get bridgesBelarus => 'بلاروس';

  @override
  String get bridgesKryfoCanTUseThis => 'Kryfo نمی‌تواند از این خط استفاده کند';

  @override
  String get bridgesTryAutomatic => 'امتحان حالت خودکار';

  @override
  String get bridgesNoInternet => 'بدون اینترنت';

  @override
  String get bridgesConnection => 'اتصال';

  @override
  String get bridgesGetABridge => 'گرفتن پل';

  @override
  String get languageTitle => 'زبان';

  @override
  String get languageMatchPhone => 'هماهنگ با گوشی';

  @override
  String languageMatchPhoneValue(Object language) {
    return 'هماهنگ با گوشی (⁨$language⁩)';
  }

  @override
  String get languageRedrawLine =>
      'Kryfo با زبان تازه از نو کشیده می‌شود و روی گفت‌وگوهایتان باز می‌شود.';

  @override
  String languageButton(Object language) {
    return 'زبان: ⁨$language⁩';
  }

  @override
  String get androidServiceTitle => 'Kryfo روشن است';

  @override
  String get androidServiceText =>
      'خط رمزگذاری‌شده‌ی شما باز می‌ماند تا پیام‌ها برسند';

  @override
  String get androidChannelName => 'متصل ماندن';

  @override
  String get androidChannelDescription =>
      'Kryfo را متصل نگه می‌دارد تا پیام‌های رمزگذاری‌شده وقتی بسته است هم برسند. خاموش کردنش، رسیدن پیام‌ها را متوقف می‌کند.';

  @override
  String get videoViewerPlay => 'پخش';

  @override
  String get videoViewerPause => 'مکث';

  @override
  String get videoViewerPlayAgain => 'پخش دوباره';

  @override
  String get videoViewerCannotPlay =>
      'این گوشی نمی‌تواند این ویدیو را این‌جا پخش کند.';

  @override
  String get videoViewerOpenElsewhere => 'باز کردن در برنامه‌ی دیگر';

  @override
  String get photoKnowsLookedFor => 'دنبالشان گشتیم';

  @override
  String get photoKnowsNotInIt => 'در آن نیست';

  @override
  String get languageNameEn => 'انگلیسی';

  @override
  String get languageNameDe => 'آلمانی';

  @override
  String get languageNameFr => 'فرانسوی';

  @override
  String get languageNameEs => 'اسپانیایی';

  @override
  String get languageNamePt => 'پرتغالی (برزیل)';

  @override
  String get languageNameIt => 'ایتالیایی';

  @override
  String get languageNameRu => 'روسی';

  @override
  String get languageNameUk => 'اوکراینی';

  @override
  String get languageNameTr => 'ترکی';

  @override
  String get languageNameZh => 'چینی (ساده‌شده)';

  @override
  String get languageNameZhHant => 'چینی (سنتی)';

  @override
  String get languageNameVi => 'ویتنامی';

  @override
  String get languageNameId => 'اندونزیایی';

  @override
  String get languageNameFa => 'فارسی';

  @override
  String get languageNameAr => 'عربی';

  @override
  String get languageLaterLine =>
      'هر وقت خواستید می‌توانید این را در تنظیمات تغییر دهید.';

  @override
  String get pollAttach => 'نظرسنجی';

  @override
  String get pollNewTitle => 'نظرسنجی تازه';

  @override
  String get pollQuestionHint => 'از گروه چیزی بپرسید';

  @override
  String get pollOptionsLabel => 'گزینه‌ها';

  @override
  String pollOptionHint(Object n) {
    return 'گزینهٔ ⁨$n⁩';
  }

  @override
  String get pollAddOption => 'افزودن گزینه';

  @override
  String get pollMaxLine => 'حداکثر دوازده گزینه.';

  @override
  String get pollMultiple => 'چند پاسخ';

  @override
  String get pollMultipleLine => 'می‌شود بیش از یکی را انتخاب کرد.';

  @override
  String get pollSend => 'فرستادن نظرسنجی';

  @override
  String get pollKind => 'نظرسنجی';

  @override
  String get pollKindMulti => 'نظرسنجی · چند پاسخ';

  @override
  String get pollKindClosed => 'نتیجهٔ نهایی';

  @override
  String pollVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$count⁩ رأی',
      one: '⁨$count⁩ رأی',
      zero: 'هنوز رأیی نیست',
    );
    return '$_temp0';
  }

  @override
  String get pollVote => 'رأی دادن';

  @override
  String get pollTakeBack => 'پس گرفتن رأی من';

  @override
  String get pollClose => 'بستن نظرسنجی';

  @override
  String get pollCloseTitle => 'این نظرسنجی بسته شود؟';

  @override
  String get pollCloseLine =>
      'همه نتیجهٔ نهایی را می‌بینند و پس از این کسی نمی‌تواند رأی بدهد.';

  @override
  String get pollCloseYes => 'بستن';

  @override
  String pollPreview(Object question) {
    return 'نظرسنجی: ⁨$question⁩';
  }

  @override
  String get pollWhoVoted => 'چه کسانی رأی دادند';

  @override
  String get pollNobody => 'هنوز کسی نه';

  @override
  String get pollYou => 'شما';

  @override
  String pollOptionA11y(Object option, Object share) {
    return '⁨$option⁩، ⁨$share⁩';
  }

  @override
  String get pollPickOne => 'یکی را انتخاب کنید';

  @override
  String get pollPickSeveral => 'یک یا چند گزینه را انتخاب کنید';

  @override
  String get searchHint => 'جست‌وجو در گفت‌وگوها و پیام‌ها';

  @override
  String get searchFilterAll => 'همه';

  @override
  String get searchFilterPhotos => 'عکس‌ها';

  @override
  String get searchFilterVideos => 'ویدیوها';

  @override
  String get searchFilterFiles => 'فایل‌ها';

  @override
  String get searchFilterLinks => 'پیوندها';

  @override
  String get searchChats => 'گفت‌وگوها';

  @override
  String get searchMessages => 'پیام‌ها';

  @override
  String get searchIntroTitle => 'در گفت‌وگوهایتان جست‌وجو کنید';

  @override
  String get searchIntroLine =>
      'نام‌ها، واژه‌ها، عکس‌ها، فایل‌ها و پیوندها. جست‌وجو روی همین گوشی انجام می‌شود و چیزی به جایی نمی‌فرستد.';

  @override
  String get searchNothing => 'چیزی پیدا نشد';

  @override
  String get searchNothingLine => 'واژه یا فیلتر دیگری را امتحان کنید.';

  @override
  String searchMatches(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$count⁩ نتیجه',
      one: '⁨$count⁩ نتیجه',
    );
    return '$_temp0';
  }

  @override
  String searchMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$count⁩ مورد دیگر',
      one: '⁨$count⁩ مورد دیگر',
    );
    return '$_temp0';
  }

  @override
  String searchFilling(Object share) {
    return 'در حال افزودن پیام‌های قدیمی‌تر · ⁨$share⁩';
  }

  @override
  String get searchClear => 'پاک کردن';

  @override
  String get handleShowInSearch => 'نمایش من در جست‌وجو';

  @override
  String get handleShowInSearchLine =>
      'هر کسی می‌تواند این نام کاربری را پیدا کند و به شما پیام بدهد.';

  @override
  String handleShownAs(Object name) {
    return 'نمایش با نام ⁨$name⁩';
  }

  @override
  String get handleNameInSearch => 'نام در جست‌وجو';

  @override
  String get handleNameInSearchLine =>
      'اختیاری. وقتی کسی جست‌وجو می‌کند، کنار نام کاربری شما دیده می‌شود. هر کسی می‌تواند این نام کاربری را پیدا کند و به شما پیام بدهد.';

  @override
  String get handleNameHint => 'نام شما، یا خالی بگذارید';

  @override
  String get handleShowMe => 'نمایش من';

  @override
  String get handleSearchOff => 'دیگر در جست‌وجو نیستید';

  @override
  String handleSearchOn(Object handle) {
    return 'در جست‌وجو با ⁦@$handle⁩ دیده می‌شوید';
  }

  @override
  String get handleRegistryFailed =>
      'دفتر ثبت پاسخ نداد. یک دقیقهٔ دیگر دوباره امتحان کنید.';

  @override
  String get handleStillReaching =>
      'هنوز در حال رسیدن به دفتر ثبت است. از طریق Tor ممکن است تا یک دقیقه طول بکشد.';

  @override
  String get handleSearchNeedsTor =>
      'جست‌وجوی نام کاربری به Tor نیاز دارد. تا آن موقع، با QR یا پیوند اضافه کنید.';

  @override
  String get handleCheckClock =>
      'تاریخ و ساعت گوشی را بررسی کنید و دوباره امتحان کنید.';

  @override
  String get searchPeople => 'افراد';

  @override
  String searchPeopleAsk(Object query) {
    return 'جست‌وجوی «$query» میان نام‌های کاربری عمومی';
  }

  @override
  String get searchPeopleLine =>
      'از راه Tor پرسیده می‌شود. دفتر ثبت هیچ سابقه‌ای از آن نگه نمی‌دارد.';

  @override
  String get searchPeopleNone => 'هیچ نام کاربری عمومی‌ای مطابقت ندارد';

  @override
  String get searchPeopleOffline => 'Tor هنوز آماده نیست';

  @override
  String get searchPeopleBusy =>
      'الان جست‌وجوها زیاد است. کمی بعد دوباره امتحان کنید.';

  @override
  String get searchPeopleUnreachable => 'دفتر ثبت پاسخ نداد';

  @override
  String get peopleVerified => 'نام کاربری تأییدشده';

  @override
  String get peopleAdd => 'افزودن';

  @override
  String peopleFingerprint(Object fp) {
    return 'اثر انگشت کلید · ⁨$fp⁩';
  }

  @override
  String get peopleFingerprintLine =>
      'بررسی کنید با آنچه طرف مقابل در برنامه‌اش می‌بیند یکی باشد.';

  @override
  String get peopleAdding => 'در حال افزودن…';

  @override
  String handleNobodyHasClaimed(Object handle) {
    return 'هیچ‌کس ⁦$handle⁩ را ثبت نکرده است';
  }

  @override
  String get handleThatHandleIsTaken => 'این نام کاربری قبلاً گرفته شده';

  @override
  String get pinPickDifferent => 'PIN دیگری انتخاب کنید';

  @override
  String get lockFingerAfterPin =>
      'یک بار PIN خود را وارد کنید تا دوباره بتوانید از اثر انگشت استفاده کنید.';

  @override
  String get pinsAdvanced => 'حفاظت پیشرفته';

  @override
  String get pinsAdvancedLine =>
      'برای وقتی که کسی شما را وادار می‌کند قفل گوشی‌تان را باز کنید.';

  @override
  String get pinsWipeLine =>
      'اگر در صفحه‌ی قفل وارد شود، Kryfo را از این گوشی پاک می‌کند.';

  @override
  String get pinsDecoyPin => 'PIN فریب';

  @override
  String get pinsDecoyLine => 'یک Kryfo خالی باز می‌کند، انگار تازه نصب شده.';

  @override
  String get pinsChangeDecoyPin => 'تغییر PIN فریب';

  @override
  String get pinsRemoveTheDecoyPin => 'PIN فریب حذف شود؟';

  @override
  String get pinsTheDecoyGoes => 'Kryfo خالی‌ای که باز می‌کند هم با آن می‌رود.';

  @override
  String get pinsTurnOffWithDecoy =>
      'همه‌ی PINها حذف می‌شوند، PIN فریب و Kryfo آن و هر گفت‌وگوی پنهانی هم با آن‌ها. هر کس گوشی شما را در دست داشته باشد، Kryfo را به‌عنوان شما باز می‌کند.';

  @override
  String get pinsHowThisWorks => 'این چطور کار می‌کند';

  @override
  String get flowEnterYourPin => 'PIN خود را وارد کنید';

  @override
  String get flowEnterYourPinLine => 'همان که Kryfo را باز می‌کند.';

  @override
  String get flowWipeTitle => 'یک PIN پاک‌سازی';

  @override
  String get flowWipe1 =>
      'اگر در صفحه‌ی قفل به‌جای PIN شما وارد شود، Kryfo را از این گوشی پاک می‌کند و می‌بندد. از نگاه کسی که تماشا می‌کند، برنامه فقط از کار افتاد.';

  @override
  String get flowWipe2 =>
      'همه‌ی گفتگوها و هویت شما را با خود می‌برد، و اگر فریبی دارید آن را هم.';

  @override
  String get flowWipeChoose => 'یک PIN پاک‌سازی انتخاب کنید';

  @override
  String get flowWipeDone => 'PIN پاک‌سازی تعیین شد';

  @override
  String get flowWipeDoneLine =>
      'هیچ چیز در صفحه‌ی قفل نشان نمی‌دهد که وجود دارد.';

  @override
  String get flowDecoyTitle => 'یک PIN فریب';

  @override
  String get flowDecoy1 => 'یک Kryfo خالی باز می‌کند، انگار تازه نصب شده.';

  @override
  String get flowDecoyFinger =>
      'تا وقتی PIN فریب تنظیم شده، این برنامه فقط با PIN شما باز می‌شود. اگر اثر انگشت در فریب روشن باشد، انگشت فریب را باز می‌کند، هرگز این برنامه را.';

  @override
  String get flowDecoyDigits =>
      'همان تعداد رقمِ PIN خود را به کار ببرید، چون هر کسی که نگاه می‌کند می‌تواند نقطه‌ها را بشمارد.';

  @override
  String get flowDecoyShade =>
      'اعلان‌هایی که از قبل در فهرست اعلان‌ها هستند، دیده شده‌اند. تا وقتی فریب باز است، اعلان تازه‌ای نشان داده نمی‌شود.';

  @override
  String get flowDecoyChoose => 'یک PIN فریب انتخاب کنید';

  @override
  String get flowDecoyDone => 'PIN فریب تعیین شد';

  @override
  String get flowDecoyDoneLine =>
      'آن را در صفحه‌ی قفل وارد کنید تا Kryfo خالی باز شود. برای بیرون آمدن، به برنامه‌ی دیگری بروید و PIN خود را وارد کنید.';

  @override
  String get flowLaw =>
      'در برخی کشورها، خودداری از باز کردن قفل گوشی یا پنهان کردن داده‌ها از مأموران به‌خودی‌خود جرم است. قانون جایی را که به آن سفر می‌کنید بشناسید.';

  @override
  String get howWipe =>
      'اگر PIN پاک‌سازی در صفحه‌ی قفل وارد شود، همه‌ی گفتگوها، هویت شما و هر فریبی را پاک می‌کند و سپس Kryfo را می‌بندد. حتی وقتی صفحه‌کلید پس از تلاش‌های نادرست متوقف شده، کار می‌کند.';

  @override
  String get howDecoy =>
      'PIN فریب یک Kryfo دوم و خالی با سه واژه‌ی خودش باز می‌کند. پیام‌ها به Kryfo واقعی شما در زیر آن بی‌صدا می‌رسند. برای بیرون آمدن از فریب، به برنامه‌ی دیگری بروید و PIN خود را وارد کنید.';

  @override
  String get flowNotSet => 'تعیین نشد. دوباره امتحان کنید.';

  @override
  String get pinsHiddenChats => 'گفت‌وگوهای پنهان';

  @override
  String get pinsHiddenLine =>
      'گفت‌وگوهای انتخاب‌شده تا وقتی PIN گفت‌وگوهای پنهان را وارد نکنید، دور از چشم می‌مانند: نه در فهرست، نه در جست‌وجو، بدون اعلان.';

  @override
  String get pinsSetUp => 'راه‌اندازی';

  @override
  String get pinsChangeHiddenPin => 'تغییر PIN گفت‌وگوهای پنهان';

  @override
  String get pinsHideMoreChats => 'پنهان کردن گفت‌وگوهای بیشتر';

  @override
  String get pinsRemoveHiddenChats => 'خاموش کردن گفت‌وگوهای پنهان';

  @override
  String get pinsRemoveHiddenTitle => 'گفت‌وگوهای پنهان خاموش شود؟';

  @override
  String get pinsRemoveHiddenLine =>
      'به فهرست گفت‌وگوهای شما برمی‌گردند و PIN گفت‌وگوهای پنهان دیگر چیزی را باز نمی‌کند.';

  @override
  String get pinsTurnOffHiddenFirst =>
      'گفت‌وگوهای پنهان به قفل برنامه نیاز دارند. اول آن‌ها را خاموش کنید تا به فهرست گفت‌وگوهای شما برگردند.';

  @override
  String get flowVaultTitle => 'گفت‌وگوهای پنهان';

  @override
  String get flowVault1 =>
      'گفت‌وگوها و گروه‌هایی را که می‌خواهید پنهان شوند انتخاب کنید. PIN شما Kryfo را بدون آن‌ها باز می‌کند. PIN گفت‌وگوهای پنهان همه‌چیز را باز می‌کند، گفت‌وگوهای پنهان را هم.';

  @override
  String get flowVault2 =>
      'تا وقتی دور از چشم‌اند، هیچ اعلان یا شمارنده‌ای نشان نمی‌دهند. پیام‌هایشان همچنان می‌رسند و مهروموم‌شده منتظر PIN گفت‌وگوهای پنهان می‌مانند.';

  @override
  String get flowVaultFinger =>
      'اثر انگشت شما Kryfo را بدون گفت‌وگوهای پنهان باز می‌کند.';

  @override
  String get flowVaultDigits =>
      'PIN خود را هم شش رقمی یا بیشتر کنید، چون هر کسی که نگاه می‌کند می‌تواند نقطه‌ها را بشمارد.';

  @override
  String get flowVaultReplace =>
      'این کار جای هر گفت‌وگوی پنهانی را که این گوشی از قبل دارد می‌گیرد.';

  @override
  String get flowVaultChoose => 'یک PIN گفت‌وگوهای پنهان انتخاب کنید';

  @override
  String get flowVaultChooseLine => 'شش رقم یا بیشتر.';

  @override
  String get flowEnterHiddenPinLine =>
      'همان که گفت‌وگوهای پنهان شما را باز می‌کند.';

  @override
  String get flowVaultForgetTitle => 'این PIN را به خاطر بسپارید';

  @override
  String get flowVaultForget =>
      'اگر این PIN را فراموش کنید، گفت‌وگوهای پنهان شما برای همیشه از دست می‌روند. هیچ‌کس نمی‌تواند آن‌ها را برگرداند.';

  @override
  String get flowVaultForgetOk => 'متوجه شدم';

  @override
  String get flowVaultPickTitle => 'گفت‌وگوهایی را برای پنهان کردن انتخاب کنید';

  @override
  String get flowVaultPickLine =>
      'همین حالا از فهرست گفت‌وگوهای شما بیرون می‌روند. PIN گفت‌وگوهای پنهان آن‌ها را دوباره نشان می‌دهد.';

  @override
  String flowVaultPickButton(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'پنهان کردن ⁨$countString⁩ گفت‌وگو',
      one: 'پنهان کردن ⁨$countString⁩ گفت‌وگو',
      zero: 'فعلاً چیزی پنهان نشود',
    );
    return '$_temp0';
  }

  @override
  String get flowVaultPickEmpty => 'هنوز گفت‌وگویی برای پنهان کردن نیست.';

  @override
  String get flowVaultBackupTitle => 'نسخه‌ی پشتیبان همین حالا گرفته شود؟';

  @override
  String get flowVaultBackupLine =>
      'نسخه‌ی پشتیبانی که حالا گرفته شود، گفت‌وگوهای پنهان شما را هم با عبارت عبور خودش در بر دارد. اگر PIN گفت‌وگوهای پنهان را فراموش کنید، تنها راه بازگشت به آن‌هاست.';

  @override
  String get flowVaultBackupNow => 'گرفتن نسخه‌ی پشتیبان';

  @override
  String get flowVaultNotNow => 'فعلاً نه';

  @override
  String get flowVaultDone => 'گفت‌وگوهای پنهان راه‌اندازی شد';

  @override
  String get flowVaultDoneLine =>
      'برای دیدنشان، PIN گفت‌وگوهای پنهان را در صفحه‌ی قفل وارد کنید. با رفتن به برنامه‌ای دیگر، دوباره دور از چشم می‌شوند.';

  @override
  String get flowVaultChanged => 'PIN گفت‌وگوهای پنهان تغییر کرد';

  @override
  String get flowVaultChangedLine =>
      'گفت‌وگوهای پنهان شما حالا با PIN تازه باز می‌شوند. PIN قبلی دیگر چیزی را باز نمی‌کند.';

  @override
  String get howVault =>
      'PIN گفت‌وگوهای پنهان، Kryfo را همراه گفت‌وگوهای پنهان شما باز می‌کند؛ PIN شما و اثر انگشتتان بدون آن‌ها. راه‌اندازی دوباره‌ی گفت‌وگوهای پنهان جای آن‌هایی را که این گوشی دارد می‌گیرد. اگر PIN گفت‌وگوهای پنهان را فراموش کنید، برای همیشه از دست می‌روند.';

  @override
  String get chatHide => 'پنهان کردن گفت‌وگو';

  @override
  String get groupHide => 'پنهان کردن گروه';

  @override
  String get chatHidden => 'پنهان';

  @override
  String get chatHiddenToast => 'از فهرست گفت‌وگوهای شما پنهان شد';

  @override
  String get chatShowInList => 'نمایش در فهرست گفت‌وگوها';

  @override
  String get stickerOpen => 'استیکرها';

  @override
  String get stickerRecent => 'اخیر';

  @override
  String stickerA11y(String emoji) {
    return 'استیکر $emoji';
  }

  @override
  String get stickerRemoveRecent => 'حذف از اخیر';

  @override
  String get stickerCouldNotLoad => 'استیکرها بارگیری نشدند';

  @override
  String get stickerLabel => 'استیکر';

  @override
  String get timedMessageLabel => 'پیام زمان‌دار';

  @override
  String get stickerNewer => 'از نسخه‌ی جدیدتر Kryfo';

  @override
  String get devLinkMismatch =>
      'این پیوند خود را Marios معرفی می‌کند، اما کلیدش مطابقت ندارد. چیزی افزوده نشد.';

  @override
  String get devName => 'Marios';

  @override
  String get devRowTitle => 'Marios · سازنده‌ی Kryfo';

  @override
  String get devWelcome =>
      'سلام، من Marios هستم و Kryfo را می‌سازم. هر چه می‌خواهید بگویید: باگ، ایده، سؤال. همه را می‌خوانم.';

  @override
  String get devPinned => 'در Kryfo تعبیه‌شده';

  @override
  String get devAnonymous => 'ناشناس';

  @override
  String get devAboutLine =>
      'کلید Marios درون Kryfo تعبیه شده است. هر پیامی که از او می‌رسد با آن سنجیده می‌شود، پس هیچ‌کس دیگری نمی‌تواند به جای او بنویسد.';

  @override
  String get devKeyLabel => 'کلید او';

  @override
  String get devDeleteLine =>
      'همه‌ی پیام‌ها حذف می‌شوند و این گفت‌وگو دیگر برنمی‌گردد.';

  @override
  String get devDeleteLineAnon =>
      'همه‌ی پیام‌ها و نامی که برای این گفت‌وگو ساخته شد حذف می‌شوند و این گفت‌وگو دیگر برنمی‌گردد.';

  @override
  String get devDeleteLineBack =>
      'همه‌ی پیام‌ها حذف می‌شوند و این گفت‌وگو دیگر برنمی‌گردد. آنچه فرستاده‌اید از گوشی Marios هم پس گرفته می‌شود.';

  @override
  String get devDeleteLineAnonBack =>
      'همه‌ی پیام‌ها و نامی که برای این گفت‌وگو ساخته شد حذف می‌شوند و این گفت‌وگو دیگر برنمی‌گردد. آنچه فرستاده‌اید از گوشی Marios هم پس گرفته می‌شود.';

  @override
  String devDeleteNotTakenBack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count پیام از گوشی Marios پس گرفته نشد',
      one: '$count پیام از گوشی Marios پس گرفته نشد',
    );
    return '$_temp0';
  }

  @override
  String get devDeleteFailed => 'گفت‌وگو حذف نشد. دوباره امتحان کنید.';

  @override
  String get supportTitle => 'Inbox';

  @override
  String supportWaiting(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString waiting',
      one: '$countString waiting',
      zero: 'No one waiting',
    );
    return '$_temp0';
  }

  @override
  String get supportSectionWaiting => 'Waiting';

  @override
  String get supportSectionAnswered => 'Answered';

  @override
  String get supportSectionDone => 'Done';

  @override
  String get supportEmpty => 'No one has written yet';

  @override
  String get supportEmptyLine =>
      'Chats people start from the Marios row land here, not in requests.';

  @override
  String get supportMarkDone => 'Done';

  @override
  String get supportReopen => 'Reopen';

  @override
  String get supportMarkAllDone => 'Mark all waiting as done';

  @override
  String get supportMenu => 'Inbox options';

  @override
  String get supportDeleteLine =>
      'Every message in this chat goes from this phone. If they write again, it comes back here.';

  @override
  String supportNotifNewChats(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString new chats',
      one: '$countString new chat',
    );
    return '$_temp0';
  }

  @override
  String supportNotifNewMessages(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString new messages',
      one: '$countString new message',
    );
    return '$_temp0';
  }

  @override
  String get supportChannelName => 'Inbox';

  @override
  String get supportChannelLine => 'Chats people start from the Marios row';

  @override
  String get supportResetPinned =>
      'This identity is pinned in Kryfo. A new link would cut off every chat with it.';

  @override
  String get supportViaDev => 'Via developer chat';

  @override
  String get supportMoveAsk => 'Move your inbox chat with them into this chat?';

  @override
  String get supportMoveLine =>
      'It leaves the inbox and shows in Chats. Keep apart leaves both as they are.';

  @override
  String get supportMove => 'Move';

  @override
  String get supportKeepApart => 'Keep apart';

  @override
  String get supportMoveToChats => 'Move to Chats';

  @override
  String get supportMovedToChats => 'Moved to Chats';

  @override
  String get supportMoveToInbox => 'Move to inbox';

  @override
  String get supportMovedToInbox => 'Moved to inbox';

  @override
  String get settingsWriteToMarios => 'پیام به Marios';

  @override
  String get settingsWriteToMariosHint => 'باگ، ایده، سؤال';

  @override
  String get seenDevChat => 'گفت‌وگو با Marios';

  @override
  String get seenDevChatCell => 'اگر بنویسید';

  @override
  String get seenDevChatLine =>
      'تا وقتی ننویسید، هیچ. بعد آنچه می‌فرستید، و سه واژه‌ی شما، مگر اینکه ناشناس بنویسید.';

  @override
  String get devWriteAnonymously => 'ناشناس بنویسید';

  @override
  String get devUseMyWords => 'استفاده از سه واژه‌ی خودم';

  @override
  String get devWhoSeesWhat => 'این چطور کار می‌کند';

  @override
  String get devWhoWords =>
      'با سه واژه‌ی شما، این گفت‌وگویی مثل بقیه است: Marios می‌تواند پاسخ دهد و چهره و نشان هوادار شما پیش خودتان می‌ماند.';

  @override
  String get devWhoAnon =>
      'اگر ناشناس بنویسید، Kryfo نام و کلیدهای تازه‌ای فقط برای این گفت‌وگو می‌سازد. این‌ها روی همین گوشی می‌مانند و هرگز جای دیگری به کار نمی‌روند.';

  @override
  String get devWhoNothingYet =>
      'تا وقتی نخستین پیامتان را نفرستید، هیچ چیزی از گوشی شما بیرون نمی‌رود.';

  @override
  String get devWhoChoiceStays => 'انتخاب شما با این گفت‌وگو می‌ماند.';

  @override
  String get devKeyCheckFailed =>
      'بررسی کلید Marios ممکن نشد. چیزی فرستاده نشد.';

  @override
  String get devLockLine =>
      'Marios این‌ها را می‌خواند. وقتی پاسخ داد، می‌توانید بیشتر بنویسید.';

  @override
  String get devNewKey => 'Marios کلید تازه‌ای دارد';

  @override
  String get devStartNewChat => 'شروع گفت‌وگوی تازه';

  @override
  String get devKeyRetired =>
      'این کلید کنار گذاشته شده است. دیگر این‌جا چیزی فرستاده یا دریافت نمی‌شود.';

  @override
  String get devNamelessLine =>
      'نامی که برای این گفت‌وگو ساخته شد روی همان گوشی‌ای می‌ماند که در آن ساخته شده، پس این‌جا این گفت‌وگو فقط خواندنی است.';

  @override
  String get devStartNewLine =>
      'همه‌ی پیام‌های این‌جا حذف می‌شوند و گفت‌وگوی تازه‌ای باز می‌شود.';

  @override
  String get devVoiceDisguised => 'صدای شما در این گفت‌وگو تغییر داده می‌شود';

  @override
  String get devChatOptions => 'گزینه‌های گفت‌وگو';

  @override
  String get requestsSomeoneNew => 'فردی تازه';

  @override
  String get nameTakenTitle => 'کس دیگری از این واژه‌ها استفاده می‌کند';

  @override
  String get nameTakenLine =>
      'کسی اینجا این واژه‌ها را از یک درخواست، یک معرفی یا یک گروه گرفته، با کلیدی دیگر، و کسی آن‌ها را بررسی نکرده است. واژه‌ها را می‌شود کپی کرد. اگر این پیوند از کسی آمده که می‌شناسید، از آن استفاده کنید و بعد شماره‌ی امنیتی را با او مقایسه کنید.';

  @override
  String get nameTakenChatLine =>
      'گفت‌وگوی شما با این واژه‌ها از یک درخواست، یک معرفی یا یک گروه آمده، با کلیدی دیگر، و کسی آن را بررسی نکرده است. واژه‌ها را می‌شود کپی کرد. اگر این پیوند از کسی آمده که می‌شناسید، از آن استفاده کنید: آن گفت‌وگو پاک می‌شود و شماره‌ی امنیتی را در گفت‌وگوی تازه مقایسه می‌کنید. مطمئن نیستید پیوند از کجا آمده؟ همان قبلی را نگه دارید.';

  @override
  String get nameTakenDeletedLine =>
      'گفت‌وگویی با این واژه‌ها را پاک کرده‌اید که با کلید دیگری بود. اگر این پیوند از کسی آمده که می‌شناسید، از آن استفاده کنید و بعد شماره‌ی امنیتی را با او مقایسه کنید.';

  @override
  String get nameTakenTombLine =>
      'کسی را با این واژه‌ها از این گوشی حذف کردید، چون آن کسی نبود که ادعا می‌کرد. اگر این پیوند از کسی آمده که می‌شناسید، از آن استفاده کنید و بعد شماره‌ی امنیتی را با او مقایسه کنید.';

  @override
  String get nameTakenUse => 'استفاده از این پیوند';

  @override
  String get nameTakenKeep => 'همان قبلی بماند';

  @override
  String get appYourOwnInvite =>
      'این دعوت خودتان است. برای ارتباط، آن را با کس دیگری هم‌رسانی کنید.';

  @override
  String appLinkWordsTaken(Object id) {
    return 'کسی از قبل با نام ⁨$id⁩ اینجاست، با کلیدی دیگر. شماره‌ی امنیتی را با او مقایسه کنید تا بدانید چه کسی کیست. چیزی افزوده نشد.';
  }

  @override
  String appLinkWordsVerified(Object id) {
    return 'شما ⁨$id⁩ را با کلیدی دیگر تأیید کرده‌اید. چیزی افزوده نشد.';
  }

  @override
  String appTheyAreBlocked(Object id) {
    return '⁨$id⁩ را مسدود کرده‌اید. برای افزودن دوباره، از «مسدودشده‌ها» در تنظیمات رفع مسدودیت کنید.';
  }

  @override
  String get notThemNumbersDiffer => 'شماره‌ها فرق دارند';

  @override
  String get notThemLine =>
      'اگر شماره‌ها واقعاً فرق دارند، شاید کس دیگری از نام او استفاده می‌کند یا میان شما نشسته است.';

  @override
  String get notThemButton => 'این او نیست';

  @override
  String get notThemSheetTitle => 'این مخاطب حذف و کلیدش مسدود شود؟';

  @override
  String get notThemSheetLine =>
      'گفت‌وگو، پیام‌ها و فایل‌هایش از این گوشی حذف می‌شوند. فقط پیوند یا کدی که خودتان بیفزایید سه واژه‌ی او را دوباره می‌گیرد. شماره‌ی امنیتی را با هر کسی که می‌افزایید مقایسه کنید.';

  @override
  String get notThemRemove => 'حذف و مسدود کردن';

  @override
  String get notThemDone => 'حذف شد و کلیدش مسدود است';

  @override
  String get groupAdminGoneLine =>
      'مدیر آن از این گوشی حذف شد. تغییرات گروه دیگر به شما نمی‌رسد.';

  @override
  String get blockedKey => 'کلید مسدودشده';

  @override
  String get appKeyBlocked =>
      'این کلید را مسدود کرده‌اید. برای افزودنش، از «مسدودشده‌ها» در تنظیمات رفع مسدودیت کنید.';

  @override
  String get devLinkGone =>
      'گفتگو با Marios را حذف کرده‌اید. برای شروع گفتگوی تازه، در تنظیمات روی «پیام به Marios» بزنید.';

  @override
  String lockTooManyTriesFor(Object left) {
    return 'تلاش بیش از حد · ⁨$left⁩';
  }

  @override
  String get gifBadge => 'GIF';

  @override
  String get gifPlay => 'پخش گیف';

  @override
  String get gifSentInside => 'داخل پیام شما فرستاده شد';

  @override
  String get gifOptInTitle => 'جست‌وجوی خصوصی گیف';

  @override
  String get gifOptInLead =>
      'جست‌وجوی گیف به اینترنت نیاز دارد، برای همین تا وقتی نخواهید خاموش می‌ماند.';

  @override
  String get gifOptInOverTor => 'جست‌وجو از راه Tor';

  @override
  String get gifOptInThroughKryfo => 'جست‌وجو از راه Kryfo';

  @override
  String get gifOptInAsksForYou =>
      'سرور Kryfo به جای شما از سرویس گیف می‌پرسد. سرویس هرگز شما را نمی‌بیند و سرور هیچ سابقه‌ای از جست‌وجوهای شما نگه نمی‌دارد.';

  @override
  String get gifOptInLikeAPhoto =>
      'گیف مثل یک عکس، رمزگذاری‌شده می‌رود. گوشی دوستتان چیزی دانلود نمی‌کند.';

  @override
  String get gifOptInOffWhenever => 'هر وقت خواستید خاموشش کنید';

  @override
  String get gifOptInWhereToTurnOff =>
      'تنظیمات، حریم خصوصی، جست‌وجوی گیف. گیف‌های روی گوشی شما بدون آن هم همیشه کار می‌کنند.';

  @override
  String get gifTurnOn => 'روشن کردن جست‌وجوی گیف';

  @override
  String get gifNotNow => 'حالا نه';

  @override
  String gifAskOverTor(String brand) {
    return 'جست‌وجوی گیف از راه Tor و از طریق سرور Kryfo انجام می‌شود. ⁨$brand⁩ هرگز شما را نمی‌بیند. روشنش کنیم؟';
  }

  @override
  String gifAskThroughKryfo(String brand) {
    return 'جست‌وجوی گیف از طریق سرور Kryfo انجام می‌شود. ⁨$brand⁩ هرگز شما را نمی‌بیند. روشنش کنیم؟';
  }

  @override
  String get gifAskTurnOn => 'روشن کردن';

  @override
  String get gifSearchOff => 'جست‌وجوی گیف خاموش است';

  @override
  String get gifSavedOnPhone =>
      'گیف‌های ذخیره‌شده روی گوشی شما در *روی این گوشی* هستند.';

  @override
  String get gifTab => 'گیف‌ها';

  @override
  String get gifPhoneTab => 'روی این گوشی';

  @override
  String get gifSearchHint => 'جست‌وجوی گیف';

  @override
  String get gifClear => 'پاک کردن جست‌وجو';

  @override
  String get gifServiceNeverSeesYou => 'سرویس گیف هرگز شما را نمی‌بیند';

  @override
  String get gifTrending => 'پرطرفدار';

  @override
  String get gifOffline =>
      'Tor هنوز در حال اتصال است. گیف‌ها به محض آماده شدن آن می‌آیند.';

  @override
  String get gifBusy => 'الان جست‌وجوها زیاد است. کمی بعد دوباره امتحان کنید.';

  @override
  String get gifUnreachable => 'سرویس گیف Kryfo پاسخ نداد.';

  @override
  String get gifNothingFound => 'گیفی پیدا نشد. کلمه‌های دیگری امتحان کنید.';

  @override
  String get gifCouldNotLoadMore => 'بیشتر بارگیری نشد';

  @override
  String get gifLoading => 'در حال بارگیری گیف‌ها';

  @override
  String get gifCouldNotGet => 'این گیف دریافت نشد. دوباره امتحان کنید.';

  @override
  String gifPoweredBy(String brand) {
    return 'Powered by $brand';
  }

  @override
  String gifNeverSeesYou(String brand) {
    return 'از راه Kryfo جست‌وجو شد، ⁨$brand⁩ هرگز شما را نمی‌بیند.';
  }

  @override
  String gifTileA11y(String number) {
    return 'گیف ⁨$number⁩';
  }

  @override
  String get gifPhoneLine =>
      'گیف‌های ذخیره‌شده روی این گوشی. چیزی آنلاین نمی‌شود.';

  @override
  String get gifPhoneChoose => 'انتخاب گیف';

  @override
  String get settingsGifSearch => 'جست‌وجوی گیف';

  @override
  String get settingsGifSearchHint =>
      'تا وقتی روشنش نکنید خاموش است. سرور Kryfo برای شما جست‌وجو می‌کند، پس سرویس گیف هرگز شما را نمی‌بیند.';

  @override
  String get shareChooseChat => 'انتخاب گفت‌وگو';

  @override
  String get shareNoChats => 'هنوز گفت‌وگویی نیست';

  @override
  String get shareNoOne => 'کسی برای هم‌رسانی نیست';

  @override
  String get valveStillConnecting =>
      'هنوز در حال اتصال… پیام‌های شما به محض برگشتن اتصال فرستاده می‌شوند.';

  @override
  String get valveCouldNotReconnect =>
      'Kryfo نتوانست دوباره وصل شود. راه‌اندازی دوباره این را درست می‌کند و پیام‌هایتان می‌مانند.';

  @override
  String get valveRestartKryfo => 'راه‌اندازی دوبارهٔ Kryfo';

  @override
  String get updateAvailable => 'به‌روزرسانی موجود است';

  @override
  String updateReady(String version) {
    return 'Kryfo $version آماده‌ی دانلود است';
  }

  @override
  String get settingsCheckForUpdates => 'بررسی به‌روزرسانی';

  @override
  String get settingsCheckForUpdatesHint =>
      'روزی یک بار از راه Tor. فقط تازه‌ترین نسخه را از kryfo.app می‌پرسد و چیزی درباره‌ی شما نمی‌فرستد.';

  @override
  String get voiceDisguiseHere => 'تغییر صدای من در اینجا';

  @override
  String get chatBlockScreenshots => 'جلوگیری از اسکرین‌شات';

  @override
  String get chatShotsWhenTheyUpdate =>
      'وقتی برنامه‌اش را به‌روز کند در دسترس است';

  @override
  String get chatShotsBothPhones =>
      'Kryfo اسکرین‌شات و ضبط صفحه‌ی این گفت‌وگو را در هر دو گوشی مسدود می‌کند، و کپی، بازارسال یا ذخیره‌ی پیام‌های یکدیگر را هم. جلوی برنامه‌هایی که اجازه‌ی خواندن صفحه را دارند، یا گوشی و برنامه‌ای را که برای دور زدنش تغییر داده شده نمی‌گیرد.';

  @override
  String get chatShotsBlocksBoth =>
      'جلوی اسکرین‌شات و ضبط صفحه را در هر دو گوشی می‌گیرد، و کپی، بازارسال یا ذخیره‌ی پیام‌های یکدیگر را هم. جلوی برنامه‌هایی که اجازه‌ی خواندن صفحه را دارند، یا گوشی و برنامه‌ای را که برای دور زدنش تغییر داده شده نمی‌گیرد.';

  @override
  String get chatShotsBlockedHere =>
      'Kryfo در این گفت‌وگو جلوی اسکرین‌شات را می‌گیرد';

  @override
  String get chatShotsMenuNote =>
      'کپی، بازارسال و ذخیره‌ی پیام‌های او در این گفت‌وگو خاموش است';

  @override
  String get chatShotsKeptOpen =>
      'باز کردن فایل‌های او در برنامه‌های دیگر در این گفت‌وگو خاموش است';

  @override
  String searchKeptMatches(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$countString⁩ نتیجه · برای دیدن، گفت‌وگو را باز کنید',
      one: '⁨$countString⁩ نتیجه · برای دیدن، گفت‌وگو را باز کنید',
    );
    return '$_temp0';
  }

  @override
  String get savedKeptInChat =>
      'ذخیره‌شده از گفت‌وگویی که جلوی اسکرین‌شات را می‌گیرد · برای دیدن، گفت‌وگو را باز کنید';

  @override
  String get roomShotsMenuNote =>
      'کپی، بازارسال و ذخیره‌ی پیام‌های دیگران در این اتاق خاموش است';

  @override
  String get roomShotsKeptOpen =>
      'باز کردن فایل‌های دیگران در برنامه‌های دیگر در این اتاق خاموش است';

  @override
  String get chatShotsYouTurnedOn =>
      'شما جلوگیری از اسکرین‌شات را روشن کردید. کپی، بازارسال و ذخیره‌ی پیام‌های یکدیگر هم خاموش است.';

  @override
  String get chatShotsYouTurnedOff =>
      'شما جلوگیری از اسکرین‌شات را خاموش کردید';

  @override
  String chatShotsTheyTurnedOn(String name) {
    return '⁨$name⁩ جلوگیری از اسکرین‌شات را روشن کرد. کپی، بازارسال و ذخیره‌ی پیام‌های یکدیگر هم خاموش است.';
  }

  @override
  String chatShotsTheyTurnedOff(String name) {
    return '⁨$name⁩ جلوگیری از اسکرین‌شات را خاموش کرد';
  }

  @override
  String get roomShotsBlocked =>
      'Kryfo اسکرین‌شات و ضبط صفحه‌ی این اتاق را در همه‌ی گوشی‌های آن مسدود می‌کند، و کپی، بازارسال یا ذخیره‌ی پیام‌های دیگران را هم. جلوی برنامه‌هایی که اجازه‌ی خواندن صفحه را دارند، یا گوشی و برنامه‌ای را که برای دور زدنش تغییر داده شده نمی‌گیرد.';

  @override
  String get roomShotsAlwaysOn =>
      'در اتاق همیشه روشن است، روی همه‌ی گوشی‌های آن';

  @override
  String get settingsPerChat => 'برای هر گفت‌وگو';

  @override
  String get homeShotsPerChat =>
      'جلوگیری از اسکرین‌شات حالا برای هر گفت‌وگو جداست.';

  @override
  String get homeShotsTurnOnForAll => 'برای همه‌ی گفت‌وگوهایتان روشن شود؟';

  @override
  String get homeShotsTurnOn => 'روشن برای همه';

  @override
  String get homeShotsLeaveOff => 'خاموش بماند';

  @override
  String get homeShotsTheySeeIt =>
      'Kryfo روی گوشی طرف مقابل هم جلوی آن را می‌گیرد و کپی، بازارسال و ذخیره‌ی پیام‌های یکدیگر خاموش می‌شود. او می‌بیند که شما آن را روشن کرده‌اید.';

  @override
  String homeShotsTurnedOn(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Kryfo حالا در ⁨$countString⁩ گفت‌وگو جلوی اسکرین‌شات را می‌گیرد',
      one: 'Kryfo حالا در ⁨$countString⁩ گفت‌وگو جلوی اسکرین‌شات را می‌گیرد',
    );
    return '$_temp0';
  }

  @override
  String get voiceDisguisedHere => 'صدای شما در این گفت‌وگو تغییر داده می‌شود';

  @override
  String get voiceSlideUpToLock => 'برای قفل کردن به بالا بکشید';

  @override
  String get voiceStopRecording => 'توقف ضبط';

  @override
  String get voiceDeleteNote => 'حذف پیام صوتی';

  @override
  String get voiceDisguised => 'تغییریافته';

  @override
  String get voiceYourVoice => 'صدای شما';

  @override
  String get voiceDisguiseThisNote => 'تغییر صدای این پیام';

  @override
  String get voiceNotDisguised => 'صدای این پیام تغییر داده نشد، پس ارسال نشد';

  @override
  String get voiceNoRoom =>
      'فضای خالی کافی روی این گوشی نیست. کمی فضا آزاد کنید و دوباره امتحان کنید.';

  @override
  String get voiceNoRoomNotSent =>
      'فضای کافی برای تغییر صدای این پیام نبود، پس ارسال نشد';

  @override
  String get voiceDisguising => 'در حال تغییر صدا';

  @override
  String get voiceLockedNotSent =>
      'پیش از ارسال پیام صوتی شما Kryfo قفل شد، پس ارسال نشد';

  @override
  String get voiceNotSent => 'پیام صوتی شما ارسال نشد';

  @override
  String get settingsDisguiseByDefault => 'تغییر صدای من به‌طور پیش‌فرض';

  @override
  String get settingsDisguiseByDefaultHint =>
      'هر گفت‌وگو می‌تواند آن را از منوی خودش تغییر دهد';

  @override
  String get fileInstallerLine =>
      'این فایلِ نصبِ یک برنامه است. برنامه‌ها را فقط از کسانی نصب کنید که به آن‌ها اعتماد دارید.';

  @override
  String get fileAppInstaller => 'فایل نصب برنامه';

  @override
  String get fileSaveToDevice => 'ذخیره در دستگاه';

  @override
  String get fileOpenHint => 'در برنامه‌ی دیگری باز می‌شود';

  @override
  String get fileSaved => 'ذخیره شد';

  @override
  String fileSavedIn(String place) {
    return 'در ⁨$place⁩ ذخیره شد';
  }

  @override
  String get fileSavedUnchecked =>
      'ذخیره شد، ولی Kryfo نتوانست نسخه را بررسی کند';

  @override
  String get fileNotSaved => 'فایل ذخیره نشد';

  @override
  String fileTooBig(String size, String max) {
    return 'حجم این فایل ⁨$size⁩ است. فایل‌ها حداکثر می‌توانند ⁨$max⁩ باشند.';
  }

  @override
  String get fileGoesAsItIs =>
      'این فایل همان‌طور که هست فرستاده می‌شود. Kryfo فقط فایل‌های JPEG، PNG، WebP، HEIC، AVIF، GIF، MP4 و MOV را تمیز می‌کند.';

  @override
  String get fileRawPictureTitle => 'این تصویر همان‌طور که هست فرستاده شود؟';

  @override
  String get fileRawPictureLine =>
      'این تصویر را نمی‌شود تمیز کرد. جزئیاتی مثل جای گرفتنش همراهش می‌رود. برای تمیز شدن، آن را به‌صورت عکس بفرستید.';

  @override
  String get voiceStoppedAtLimit =>
      'پیام‌های صوتی در ۳۰ دقیقه متوقف می‌شوند. گوش کنید و بعد بفرستید.';

  @override
  String get gettingMessagesHelperBody =>
      'فوری و سبک. سرورش IP شما و زمان رسیدن پیام‌ها را می‌بیند، هرگز محتوایشان را نه.';

  @override
  String get gettingMessagesHelperUseOnion => 'رفتن به Onion';

  @override
  String get gettingMessagesHelperSetUp => 'راه‌اندازی';

  @override
  String get gettingMessagesHelperNote =>
      'بیداری‌های جعلی هم قاطی می‌شوند و این کار را برای سرور برنامه‌ی کمکی سخت‌تر می‌کند که بفهمد پیام‌های واقعی کِی می‌رسند. سرور کمکی شخصی‌تان نشانی‌اش را به رله‌ی ما می‌گوید. گفتگوهای پنهان، اتاق‌های بعد از چند تای اول، و گاهی یک مخاطب معمولی، حدوداً یک ماه از هر پنج ماه، منتظر سرکشی‌ای می‌مانند که Kryfo همچنان هر ۱۵ دقیقه انجام می‌دهد.';

  @override
  String get gettingMessagesHelperOnionOnly => 'در مسیر Onion در دسترس است';

  @override
  String get gettingMessagesHelperChecking => 'در حال بررسی…';

  @override
  String get gettingMessagesHelperRelayNotYet =>
      'رله‌ی ما هنوز این را ارائه نمی‌دهد';

  @override
  String get helperSheetNeedTitle => 'به یک برنامه‌ی کمکی نیاز دارید';

  @override
  String get helperSheetNeedLine =>
      'برنامه‌ی کمکی یک اتصال سبک برای همه‌ی برنامه‌هایتان نگه می‌دارد و وقتی چیزی برسد Kryfo را بیدار می‌کند. هر برنامه‌ی UnifiedPush کار می‌کند، ntfy شروع خوبی است.';

  @override
  String get helperSheetGetNtfy => 'دریافت ntfy';

  @override
  String get helperSheetOtherApps => 'برنامه‌های کمکی دیگر';

  @override
  String get helperSheetPickTitle => 'یک برنامه‌ی کمکی انتخاب کنید';

  @override
  String get helperSheetPickLine =>
      'Kryfo فقط از آن می‌خواهد برنامه را بیدار کند. پیام‌هایتان هرگز از آن رد نمی‌شوند.';

  @override
  String helperSheetSetUp(Object name) {
    return '⁨$name⁩ آماده است';
  }

  @override
  String helperSheetNoAnswer(Object name) {
    return '⁨$name⁩ جواب نداد. دوباره امتحان کنید.';
  }

  @override
  String get homeHelperGoneTitle => 'برنامه‌ی کمکی شما دیگر نیست';

  @override
  String get homeHelperGoneLine =>
      'تا وقتی راه دیگری انتخاب کنید، Kryfo هر ۱۵ دقیقه سرکشی می‌کند.';

  @override
  String get homeHelperGoneChoose => 'انتخاب راه دیگر';

  @override
  String get homeHelperRelayTitle => 'رله دیگر Kryfo را بیدار نمی‌کند';

  @override
  String get gettingMessagesHelperRefused =>
      'رله‌ی ما فعلاً بعضی از ثبت‌های این گوشی را نمی‌پذیرد. آن گفتگوها با سرکشی هر ۱۵ دقیقه می‌رسند و Kryfo همچنان تلاش می‌کند. انتخاب یک برنامه‌ی کمکی یا سرور دیگر هم می‌تواند کمک کند.';

  @override
  String albumLabel(Object count) {
    return 'آلبوم · ⁨$count⁩ مورد';
  }

  @override
  String albumCounter(Object at, Object total) {
    return '⁨$at⁩ از ⁨$total⁩';
  }

  @override
  String albumMore(Object count) {
    return '⁨$count⁩ مورد دیگر';
  }

  @override
  String get albumOnItsWay => 'در راه';

  @override
  String get albumQuoted => 'آلبوم';

  @override
  String get albumUnsendTitle => 'این آلبوم پس گرفته شود؟';

  @override
  String get mediaSendAddMore => 'افزودن بیشتر';

  @override
  String get mediaSendRemove => 'حذف';

  @override
  String get mediaSendProtect => 'محافظت در برابر اسکرین‌شات';

  @override
  String get mediaSendProtectedOn => 'محافظت‌شده · اسکرین‌شات مسدود است';

  @override
  String mediaSendUpTo(Object count) {
    return 'حداکثر ⁨$count⁩ مورد در هر بار';
  }

  @override
  String get mediaSendVideo => 'ارسال ویدیو';

  @override
  String mediaSendUntilAccepted(Object count) {
    return 'تا وقتی قبول نکند، ⁨$count⁩ مورد می‌تواند برود';
  }

  @override
  String get groupEndedYou => 'شما این گروه را پایان دادید';

  @override
  String groupEndedBy(Object name) {
    return '⁨$name⁩ این گروه را پایان داد';
  }

  @override
  String get groupEndedBar => 'این گروه پایان یافته';

  @override
  String get groupInfoEndGroup => 'پایان دادن به گروه';

  @override
  String get groupInfoEndThisGroup => 'این گروه برای همه پایان یابد؟';

  @override
  String get groupInfoEndGroupLine =>
      'برای همه حذف می‌شود: پیام‌ها و رسانه‌هایش از گوشی هر عضوی که به‌روزرسانی کرده پاک می‌شود.';

  @override
  String get groupInfoDeleteGroup => 'حذف گروه';

  @override
  String get groupInfoDeleteThisGroup => 'این گروه حذف شود؟';

  @override
  String get groupInfoDeleteGroupLine =>
      'گروهِ پایان‌یافته از فهرست گفت‌وگوهای شما حذف می‌شود.';

  @override
  String get groupEndedOldNotice =>
      'این گروه را پایان دادم، پس دیگر هیچ‌کس نمی‌تواند در آن پیام بفرستد. Kryfo را به‌روز کنید تا آن را پایان‌یافته ببینید.';

  @override
  String get groupInfoEndGroupDetail =>
      'Kryfo آن را از گوشی هر عضوی که به‌روزرسانی را دارد پاک می‌کند.';
}
