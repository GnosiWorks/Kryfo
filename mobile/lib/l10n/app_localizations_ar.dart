// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get atmosphereNone => 'بلا';

  @override
  String get atmosphereEmber => 'جمر';

  @override
  String get atmosphereDusk => 'غسق';

  @override
  String get atmosphereMoss => 'طحلب';

  @override
  String get atmosphereRose => 'ورد';

  @override
  String get atmosphereDots => 'نقاط';

  @override
  String get atmosphereGrid => 'شبكة';

  @override
  String get atmosphereWaves => 'أمواج';

  @override
  String get atmosphereRain => 'مطر';

  @override
  String get atmosphereLateNight => 'آخر الليل';

  @override
  String get atmosphereWarmAfternoon => 'عصر دافئ';

  @override
  String get atmosphereSnow => 'ثلج';

  @override
  String get atmosphereDesert => 'صحراء';

  @override
  String get atmospherePaper => 'ورق';

  @override
  String get accentYellow => 'أصفر';

  @override
  String get accentGrey => 'رمادي';

  @override
  String get accentPurple => 'بنفسجي';

  @override
  String get accentLime => 'ليموني';

  @override
  String get accentVelvet => 'مخملي';

  @override
  String get accentBlue => 'أزرق';

  @override
  String get appearancePreview => 'معاينة محادثاتك بهذا اللون';

  @override
  String get appearanceSampleIn => 'هل ما زال موعد الليلة قائمًا؟';

  @override
  String get appearanceSampleOut => 'نعم. الساعة الثامنة، في المكان المعتاد.';

  @override
  String get appearanceSampleButton => 'رد';

  @override
  String get appearanceAccentHint =>
      'تأخذ الأزرار ورسائلك والروابط هذا اللون. تبقى أيقونة التطبيق صفراء.';

  @override
  String get appearanceChatWallpaper => 'خلفية المحادثات';

  @override
  String get appearanceEveryChat => 'كل المحادثات';

  @override
  String get appearanceWallpaperHint =>
      'خلفية المحادثة الخاصة، المختارة من قائمتها، تأتي أولًا. تبقى الصور على هذا الهاتف، مشفرة مع محادثاتك.';

  @override
  String get appearanceWallpaperHintDesk =>
      'خلفية المحادثة الخاصة، المختارة من قائمتها، تأتي أولًا. تبقى الصور على هذا الحاسوب، مشفرة مع محادثاتك.';

  @override
  String get backupThatPassphraseDoesNot =>
      'عبارة المرور هذه لا تفتح هذا الملف';

  @override
  String get backupThatFileIsNot => 'هذا الملف ليس نسخة احتياطية من Kryfo';

  @override
  String get backupThisBackupIsFrom =>
      'هذه النسخة الاحتياطية من إصدار أحدث من Kryfo. حدّث التطبيق ثم أعد المحاولة';

  @override
  String get backupThisFileIsDamaged => 'هذا الملف تالف ولا يمكن قراءته';

  @override
  String get backupTheRestoreStoppedPartway => 'توقفت الاستعادة في منتصفها';

  @override
  String get backupCouldNotMakeThe => 'تعذّر إنشاء المفتاح';

  @override
  String get contactCardMessageMeOn => 'راسلني على';

  @override
  String get contactCardScanToAdd =>
      'امسح الرمز في Kryfo لإضافتي.\nلا تعرف هذه البطاقة عنك شيئًا سوى ذلك.';

  @override
  String contactCardMessageMeOnKryfo(Object haloId) {
    return 'راسلني على Kryfo · ⁨$haloId⁩';
  }

  @override
  String get contactStatusBlocked => 'محظور';

  @override
  String get contactStatusKeysVerifiedInPerson =>
      'تم التحقق من المفاتيح وجهًا لوجه';

  @override
  String get contactStatusWaitingInRequests => 'ينتظر في الطلبات';

  @override
  String get contactStatusAddedByHand => 'أُضيف يدويًا';

  @override
  String get deliveryModeAlwaysOn => 'متصل دائمًا';

  @override
  String get deliveryModeCheckIns => 'تفقّد دوري';

  @override
  String get deliveryModeThroughAHelperApp => 'عبر تطبيق مساعد';

  @override
  String get deliveryModeNotYet => 'ليس بعد';

  @override
  String get deliveryModeJustNow => 'الآن';

  @override
  String deliveryModeMinAgo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'قبل ⁨$countString⁩ د',
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
      other: 'قبل ⁨$countString⁩ ساعة',
      many: 'قبل ⁨$countString⁩ ساعة',
      few: 'قبل ⁨$countString⁩ ساعات',
      two: 'قبل ساعتين',
      one: 'قبل ساعة',
      zero: 'قبل ⁨$countString⁩ ساعة',
    );
    return '$_temp0';
  }

  @override
  String get deliveryModeYesterday => 'أمس';

  @override
  String deliveryModeDaysAgo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'قبل ⁨$countString⁩ يوم',
      many: 'قبل ⁨$countString⁩ يومًا',
      few: 'قبل ⁨$countString⁩ أيام',
      two: 'قبل يومين',
      one: 'قبل يوم',
      zero: 'قبل ⁨$countString⁩ يوم',
    );
    return '$_temp0';
  }

  @override
  String get deliveryModeConnected => 'متصل';

  @override
  String get deliveryModeConnecting => 'جارٍ الاتصال';

  @override
  String get deliveryModeNotConnected => 'غير متصل';

  @override
  String get deliveryModeCheckingNow => 'جارٍ التفقّد الآن';

  @override
  String deliveryModeLastCheckIn(Object agoLine) {
    return 'آخر تفقّد ⁨$agoLine⁩';
  }

  @override
  String get deliveryModeNoCheckInYet => 'لا تفقّد بعد';

  @override
  String deliveryModeConnectedNow(Object last) {
    return 'متصل الآن · ⁨$last⁩';
  }

  @override
  String deliveryModeConnecting2(Object last) {
    return 'جارٍ الاتصال · ⁨$last⁩';
  }

  @override
  String get deliveryModeNoCheckInYet2 => 'لا تفقّد بعد';

  @override
  String deliveryModeLastChecked(Object agoLine) {
    return 'آخر تفقّد ⁨$agoLine⁩';
  }

  @override
  String get deliveryModeAHelperApp => 'تطبيق مساعد';

  @override
  String deliveryModeWokenByNoWake(Object who) {
    return 'الإيقاظ عبر ⁨$who⁩ · لا إيقاظ بعد';
  }

  @override
  String deliveryModeWokenByLastWake(Object who, Object agoLine) {
    return 'الإيقاظ عبر ⁨$who⁩ · آخر إيقاظ ⁨$agoLine⁩';
  }

  @override
  String get introBudgetTomorrow => 'غدًا';

  @override
  String introBudgetInDays(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'بعد ⁨$countString⁩ يوم',
      many: 'بعد ⁨$countString⁩ يومًا',
      few: 'بعد ⁨$countString⁩ أيام',
      two: 'بعد يومين',
      one: 'بعد يوم',
      zero: 'بعد ⁨$countString⁩ يوم',
    );
    return '$_temp0';
  }

  @override
  String get introBudgetInAnHour => 'بعد ساعة';

  @override
  String introBudgetInHours(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'بعد ⁨$countString⁩ ساعة',
      many: 'بعد ⁨$countString⁩ ساعة',
      few: 'بعد ⁨$countString⁩ ساعات',
      two: 'بعد ساعتين',
      one: 'بعد ساعة',
      zero: 'بعد ⁨$countString⁩ ساعة',
    );
    return '$_temp0';
  }

  @override
  String get introBudgetInAFewMinutes => 'بعد دقائق';

  @override
  String get lockStateUnlockKryfo => 'فتح قفل Kryfo';

  @override
  String get appInvalidUri => 'رابط غير صالح';

  @override
  String appBundleError(Object e) {
    return 'خطأ في الحزمة: ⁨$e⁩';
  }

  @override
  String appAlreadySaved(Object parsed) {
    return 'محفوظ مسبقًا: ⁨$parsed⁩';
  }

  @override
  String appLongWindow(Object line) {
    return '⁨$line⁩ (فترة طويلة)';
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
      other: '⁨$pString⁩ صفحة',
      many: '⁨$pString⁩ صفحة',
      few: '⁨$pString⁩ صفحات',
      two: 'صفحتان',
      one: 'صفحة واحدة',
      zero: '⁨$pString⁩ صفحة',
    );
    String _temp1 = intl.Intl.pluralLogic(
      e,
      locale: localeName,
      other: '⁨$eString⁩ حدث',
      many: '⁨$eString⁩ حدثًا',
      few: '⁨$eString⁩ أحداث',
      two: 'حدثان',
      one: 'حدث واحد',
      zero: '⁨$eString⁩ حدث',
    );
    return '⁨$line⁩ (⁨$heldString⁩ من ⁨$subsString⁩، اتصال ⁨$c⁩ ث، $_temp0، $_temp1)';
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
      other: '⁨$pString⁩ صفحة',
      many: '⁨$pString⁩ صفحة',
      few: '⁨$pString⁩ صفحات',
      two: 'صفحتان',
      one: 'صفحة واحدة',
      zero: '⁨$pString⁩ صفحة',
    );
    String _temp1 = intl.Intl.pluralLogic(
      e,
      locale: localeName,
      other: '⁨$eString⁩ حدث',
      many: '⁨$eString⁩ حدثًا',
      few: '⁨$eString⁩ أحداث',
      two: 'حدثان',
      one: 'حدث واحد',
      zero: '⁨$eString⁩ حدث',
    );
    return '⁨$line⁩ (اتصال ⁨$c⁩ ث، $_temp0، $_temp1)';
  }

  @override
  String appSDropped(Object host, Object secs) {
    return '⁨$host⁩: انقطع بعد ⁨$secs⁩ ث';
  }

  @override
  String appS(Object host, Object secs) {
    return '⁨$host⁩: خلال ⁨$secs⁩ ث';
  }

  @override
  String get appTorWouldNotWake => 'لم يستيقظ Tor';

  @override
  String get appCheckStarted => 'بدأ';

  @override
  String get appTorNotReadyIn => 'لم يجهز Tor خلال ٧٥ ث';

  @override
  String get appOk => 'تم';

  @override
  String get appOkNoRelayBegan => 'تم، لم يبدأ أي مُرحِّل';

  @override
  String get appNoRelayReached => 'تعذّر الوصول إلى أي مُرحِّل';

  @override
  String get appOkCapped => 'تم، قُطع عند الحد';

  @override
  String appSBy(Object how, int secs, String why) {
    final intl.NumberFormat secsNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String secsString = secsNumberFormat.format(secs);

    String _temp0 = intl.Intl.selectLogic(why, {
      'push': '⁨$how⁩، ⁨$secsString⁩ ث، عبر الدفع',
      'other': '⁨$how⁩، ⁨$secsString⁩ ث، عبر المهمة الدورية',
    });
    return '$_temp0';
  }

  @override
  String get appAnAttachmentCouldNot => 'تعذّر حفظ مرفق على هذا الهاتف';

  @override
  String get appAnAttachmentCouldNotDesk => 'تعذّر حفظ مرفق على هذا الحاسوب';

  @override
  String get appGroup2 => 'مجموعة';

  @override
  String get appVoiceMessage => 'رسالة صوتية';

  @override
  String get appPhoto => 'صورة';

  @override
  String get appNewRequest => 'طلب جديد';

  @override
  String get appSomeoneYouHaveNot => 'راسلك شخص لم تُضِفه';

  @override
  String get appSettingUpYourKeys => 'جارٍ إعداد مفاتيحك';

  @override
  String get appOpeningYourChats => 'جارٍ فتح محادثاتك';

  @override
  String get appStartingTor => 'جارٍ تشغيل Tor';

  @override
  String get appTimedMessagesAreNot =>
      'الرسائل المؤقتة لا تختفي. أعد تشغيل Kryfo';

  @override
  String get appVoiceMessage2 => 'رسالة صوتية';

  @override
  String appYou(Object body) {
    return 'أنت: ⁨$body⁩';
  }

  @override
  String get appThisRoomHasAlready => 'انتهت صلاحية هذه الغرفة بالفعل';

  @override
  String get appYouAreAlreadyIn => 'أنت في هذه الغرفة بالفعل';

  @override
  String get appCouldNotMakeA => 'تعذّر إنشاء مفتاح للغرفة';

  @override
  String appJoined(Object linkName) {
    return 'انضممت إلى ⁨$linkName⁩';
  }

  @override
  String get roomJoinWaitingToJoin => 'بانتظار الانضمام';

  @override
  String get roomJoinNotAnswering => 'لا تستجيب';

  @override
  String roomJoinWaitingFor(Object room) {
    return 'بانتظار السماح لك بدخول ⁨$room⁩…';
  }

  @override
  String get roomJoinWaitingLine => 'يمكنك الكتابة هنا بمجرد دخولك.';

  @override
  String get roomJoinNoAnswer => 'هذه الغرفة لا تستجيب.';

  @override
  String get roomJoinMayHaveEnded => 'ربما انتهت.';

  @override
  String get roomJoinFullShort => 'الغرفة ممتلئة';

  @override
  String get roomJoinFull => 'هذه الغرفة ممتلئة.';

  @override
  String get roomJoinFullLine =>
      'لا يوجد مكان شاغر الآن. حاول لاحقًا، أو اسأل من شارك الرابط.';

  @override
  String get appBooting => 'جارٍ الإقلاع...';

  @override
  String get appSettingUpYourIdentity => 'جارٍ إعداد هويتك...';

  @override
  String get appAddSomeone => 'إضافة شخص';

  @override
  String get appScanTheirCodeOr =>
      'اقرأ رمزه بالكاميرا، أو الصق ما أعطاك: رابطًا أو @اسم مستخدم أو رابط غرفة.';

  @override
  String get appScanTheirCodeOrDesk =>
      'الصق ما أعطاك: رابطًا أو @اسم مستخدم أو رابط غرفة.';

  @override
  String get appScanTheirCode => 'اقرأ رمزه';

  @override
  String get appAKryfoLinkA => 'رابط Kryfo أو رابط غرفة أو ‎@name';

  @override
  String get appAddThem => 'أضِفه';

  @override
  String get appEveryWayToAdd => 'كل طرق إضافة شخص';

  @override
  String get appShowYourCodeSend => 'اعرض رمزك، أرسل رابطًا، احجز اسم مستخدم';

  @override
  String get appHelloFromTheOther => 'مرحبًا من الطرف الآخر';

  @override
  String get appIdentityRestored => 'تمت استعادة الهوية';

  @override
  String get appIdentityCreated => 'تم إنشاء الهوية';

  @override
  String get appStartingTor30s => 'جارٍ تشغيل Tor (نحو ٣٠ ث)...';

  @override
  String get appScanOrImportA => 'اقرأ رمز نظير أو استورده أولًا';

  @override
  String get appEncryptingSending30s => 'جارٍ التشفير + الإرسال (نحو ٣٠ ث)...';

  @override
  String get appTapStartListeningFirst => 'اضغط «بدء الاستماع» أولًا';

  @override
  String get appYourKryfo => 'Kryfo الخاص بك';

  @override
  String get appUriCopied => 'تم نسخ الرابط';

  @override
  String get appCopyUri => 'نسخ الرابط';

  @override
  String get appAddAKryfo => 'إضافة Kryfo';

  @override
  String get appScanQr => 'قراءة QR';

  @override
  String get appPairingCode => 'رمز الاقتران';

  @override
  String get appOrPaste => '- أو الصق -';

  @override
  String get commonCancel => 'إلغاء';

  @override
  String get appImport => 'استيراد';

  @override
  String get appDev => 'المطوّر';

  @override
  String get appYourKryfo2 => 'Kryfo الخاص بك:';

  @override
  String get appRestoredFromDisk => 'تمت الاستعادة من القرص';

  @override
  String get appStartListening => 'بدء الاستماع';

  @override
  String get appListening => 'جارٍ الاستماع';

  @override
  String get appShowMyQr => 'عرض رمز QR';

  @override
  String get appImportPeer => 'استيراد نظير';

  @override
  String get appPeer => 'النظير:';

  @override
  String get appMessageWillBeEncrypted => 'الرسالة (ستُشفَّر)';

  @override
  String get appEncryptSend => 'تشفير + إرسال';

  @override
  String appStatus(Object status) {
    return 'الحالة: ⁨$status⁩';
  }

  @override
  String get appSpeedPrivacy => 'السرعة والخصوصية ←';

  @override
  String get appDisableAppLock => 'تعطيل قفل التطبيق؟';

  @override
  String get appThePinWillBe =>
      'سيُزال رمز PIN. كل من يمسك هاتفك سيرى Kryfo عندما يفتحه.';

  @override
  String get appDisable => 'تعطيل';

  @override
  String get appAppLockOn => 'قفل التطبيق · مفعّل ←';

  @override
  String get appAppLockOff => 'قفل التطبيق · معطّل ←';

  @override
  String get appTorIsOff => 'Tor متوقف';

  @override
  String get appConnectedRoutedThrough3 => 'متصل · يمر عبر ٣ مُرحِّلات';

  @override
  String get appReadyToChatAddressFinishing =>
      'جاهز للدردشة · العنوان على وشك الاكتمال';

  @override
  String appConnecting(Object pct) {
    return 'جارٍ الاتصال · ⁨$pct⁩';
  }

  @override
  String get appTor => 'Tor';

  @override
  String get appTorIsOffTurn => 'Tor متوقف. شغّله لتتصل بخصوصية.';

  @override
  String get appTheFirstConnectionTakes =>
      'يستغرق الاتصال الأول دقيقة أو دقيقتين ريثما يبني Tor مسارًا خاصًا. بعد ذلك يُحفظ مؤقتًا، فيصبح فتح Kryfo لاحقًا أسرع بكثير.';

  @override
  String get appTorNoRelayYet =>
      'شبكة Tor تعمل، لكن لم يستجب أي مُرحِّل بعد. يواصل Kryfo المحاولة، وتبقى الرسائل هنا إلى أن يستجيب أحدها.';

  @override
  String get appRelayAndFastModes =>
      'الوضع السريع يتخطى Tor وهو أسرع. تجده في الإعدادات ضمن السرعة والخصوصية، ويقول ما الذي يكلفه.';

  @override
  String get appOffline => 'غير متصل';

  @override
  String get appTorOff => 'Tor متوقف';

  @override
  String get appTorReady => 'Tor جاهز';

  @override
  String get appConnecting2 => 'جارٍ الاتصال';

  @override
  String get appWaitingForARelay => 'بانتظار مُرحِّل';

  @override
  String mediaProgressSendingKeepTheApp(Object v) {
    return 'جارٍ الإرسال · ⁨$v⁩ · أبقِ التطبيق مفتوحًا';
  }

  @override
  String mediaProgressPausedOfWaitingFor(Object count, Object count2) {
    return 'متوقف مؤقتًا · ⁨$count⁩ من ⁨$count2⁩ · بانتظار البقية';
  }

  @override
  String mediaProgressReceivingMedia(Object v) {
    return 'جارٍ استلام الوسائط · ⁨$v⁩';
  }

  @override
  String get mediaProgressCancelSending => 'إلغاء الإرسال';

  @override
  String get metaReaderEndsBeforeItShould => 'ينتهي قبل أوانه';

  @override
  String get metaReaderCouldNotBeRead => 'تعذّرت قراءته';

  @override
  String get metaReaderExifThatCannotBe => 'بيانات EXIF لا يمكن قراءتها';

  @override
  String get metaReaderSamsungTrailer => 'ذيل سامسونج';

  @override
  String metaReaderChunk(Object type) {
    return 'مقطع ⁨$type⁩';
  }

  @override
  String get metaReaderExifFlagSet => 'علامة EXIF مفعّلة';

  @override
  String get metaReaderXmpFlagSet => 'علامة XMP مفعّلة';

  @override
  String metaReaderAppBlock(Object id) {
    return 'كتلة تطبيق ⁨$id⁩';
  }

  @override
  String get metaReaderUuidBox => 'صندوق UUID';

  @override
  String metaReaderBox(Object printable) {
    return 'صندوق ⁨$printable⁩';
  }

  @override
  String get metaReaderAttachedData => 'بيانات مُرفقة';

  @override
  String metaReaderItem(Object printable) {
    return 'عنصر ⁨$printable⁩';
  }

  @override
  String get miuiAutostartAlreadyAllowedToRun =>
      'مسموح له بالعمل في الخلفية بالفعل';

  @override
  String get miuiAutostartLetKryfoRunIn => 'اسمح لـ Kryfo بالعمل في الخلفية';

  @override
  String get miuiAutostartYourPhonePausesApps =>
      'يوقف هاتفك التطبيقات مؤقتًا لتوفير البطارية. ودون استثناء، لا يستطيع Kryfo استلام الرسائل وهو مغلق.';

  @override
  String get commonAllow => 'السماح';

  @override
  String get commonSkip => 'تخطي';

  @override
  String get miuiAutostartOpenSettings => 'فتح الإعدادات';

  @override
  String get miuiAutostartCouldnTOpenIt =>
      'تعذّر فتحها. ابحث عن التشغيل التلقائي في إعدادات الهاتف';

  @override
  String get batteryGuideHuawei =>
      'تغلق هواوي وهونر التطبيقات التي تديرها بنفسها. في الشاشة التالية، ابحث عن Kryfo وأوقف «الإدارة التلقائية»، واترك «التشغيل التلقائي» و«التشغيل الثانوي» و«التشغيل في الخلفية» مفعّلة.';

  @override
  String get batteryGuideOppo =>
      'توقف أوبو وريلمي التطبيقات في الخلفية. في الشاشة التالية، ابحث عن Kryfo واسمح له بالتشغيل التلقائي. ومن إعدادات البطارية، اسمح له بالنشاط في الخلفية أيضًا.';

  @override
  String get batteryGuideVivo =>
      'توقف فيفو التطبيقات في الخلفية. في الشاشة التالية، ابحث عن Kryfo واسمح له بالبدء في الخلفية. ومن إعدادات البطارية، اسمح له أيضًا باستهلاك طاقة عالٍ في الخلفية.';

  @override
  String get batteryGuideSamsung =>
      'تضع سامسونج التطبيقات التي تظنها غير مستخدمة في وضع السكون. في الشاشة التالية، افتح «حدود الاستخدام في الخلفية» وأضف Kryfo إلى «التطبيقات التي لا تدخل السكون أبدًا».';

  @override
  String get batteryGuideOnePlus =>
      'توقف ون بلس التطبيقات في الخلفية. في الشاشة التالية، ابحث عن Kryfo واسمح له بالتشغيل التلقائي. ومن إعدادات البطارية، اختر له «عدم التحسين».';

  @override
  String get batteryGuideXiaomiTitle => 'أبقِ Kryfo قيد التشغيل';

  @override
  String get batteryGuideXiaomi =>
      'توقف شاومي التطبيقات في الخلفية، حتى مع تفعيل التشغيل التلقائي. لتستمر الرسائل في الوصول:';

  @override
  String get batteryGuideXiaomiStep1 => 'التشغيل التلقائي: فعّله لـ Kryfo.';

  @override
  String get batteryGuideXiaomiStep2 =>
      'توفير البطارية: اضبط Kryfo على «بلا قيود».';

  @override
  String get batteryGuideXiaomiStep3 =>
      'التطبيقات الأخيرة: اضغط مطولًا على Kryfo ثم انقر على القفل، حتى لا يغلقه «مسح الكل» ولا تنظيف الهاتف.';

  @override
  String get batteryGuideXiaomiAfter =>
      'إذا أوقف الهاتف Kryfo رغم ذلك، فلن يصل شيء حتى تفتحه من جديد.';

  @override
  String get notificationsNewEncryptedMessagesFrom =>
      'رسائل مشفّرة جديدة من جهات اتصالك';

  @override
  String get notificationsNewMessage => 'رسالة جديدة';

  @override
  String get notificationsNewEncryptedMessagesFromYourContacts =>
      'رسائل مشفّرة جديدة من جهات اتصالك';

  @override
  String get notificationsNewMessage2 => 'رسالة جديدة';

  @override
  String get notificationsSomeone => 'شخص ما';

  @override
  String get notificationsEncrypted => 'مشفّرة';

  @override
  String get rooms24h => '٢٤ س';

  @override
  String roomsD(Object inDays) {
    return '⁨$inDays⁩ ي';
  }

  @override
  String roomsH(Object inHours) {
    return '⁨$inHours⁩ س';
  }

  @override
  String get rooms24Hours => '٢٤ ساعة';

  @override
  String roomsDays(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$countString⁩ يوم',
      many: '⁨$countString⁩ يومًا',
      few: '⁨$countString⁩ أيام',
      two: 'يومين',
      one: 'يوم',
      zero: '⁨$countString⁩ يوم',
    );
    return '$_temp0';
  }

  @override
  String get roomsAnHour => 'ساعة';

  @override
  String get roomsAboutAnHour => 'نحو ساعة';

  @override
  String roomsHours(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$countString⁩ ساعة',
      many: '⁨$countString⁩ ساعة',
      few: '⁨$countString⁩ ساعات',
      two: 'ساعتين',
      one: 'ساعة',
      zero: '⁨$countString⁩ ساعة',
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
      other: 'نحو ⁨$countString⁩ ساعة',
      many: 'نحو ⁨$countString⁩ ساعة',
      few: 'نحو ⁨$countString⁩ ساعات',
      two: 'نحو ساعتين',
      one: 'نحو ساعة',
      zero: 'نحو ⁨$countString⁩ ساعة',
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
      other: '⁨$countString⁩ دقيقة',
      many: '⁨$countString⁩ دقيقة',
      few: '⁨$countString⁩ دقائق',
      two: 'دقيقتين',
      one: 'دقيقة',
      zero: '⁨$countString⁩ دقيقة',
    );
    return '$_temp0';
  }

  @override
  String get roomsAMinute => 'دقيقة';

  @override
  String get roomsExpired => 'انتهت';

  @override
  String roomsDH(Object inDays, Object h) {
    return '⁨$inDays⁩ ي ⁨$h⁩ س';
  }

  @override
  String roomsHM(Object inHours, Object m) {
    return '⁨$inHours⁩ س ⁨$m⁩ د';
  }

  @override
  String roomsM(Object inMinutes) {
    return '⁨$inMinutes⁩ د';
  }

  @override
  String scamShieldGivesUsedName(Object shown) {
    return 'يقول إنه ⁨$shown⁩، وهو اسم يحمله شخص آخر هنا';
  }

  @override
  String scamShieldWarning(Object noticed) {
    return '$noticed. لا ترسل مالًا أو رموزًا لأشخاص لم تلتقِ بهم.';
  }

  @override
  String get scamShieldAsksForSecret =>
      'يطلب رمزًا أو رمز PIN أو كلمات الاسترداد';

  @override
  String get scamShieldAsksForMoneyFast => 'يطلب المال على عجل';

  @override
  String get scamShieldPromisesProfit => 'يعد بربح سهل';

  @override
  String get scamShieldClaimsSupport => 'يدّعي أنه من Kryfo أو من فريق دعم';

  @override
  String get scamShieldDismiss => 'إخفاء';

  @override
  String scamShieldNameMatchesYourContact(Object shown) {
    return 'الاسم يطابق جهة اتصالك ⁨$shown⁩';
  }

  @override
  String get scamShieldLinksToALookalike => 'يحيل إلى موقع يشبه موقعًا معروفًا';

  @override
  String get commonBack => 'رجوع';

  @override
  String get archivedArchived => 'الأرشيف';

  @override
  String get archivedCount0 => 'لا شيء';

  @override
  String get archivedCount1 => 'واحدة';

  @override
  String get archivedCount2 => 'اثنتان';

  @override
  String get archivedCount3 => 'ثلاث';

  @override
  String get archivedCount4 => 'أربع';

  @override
  String get archivedCount5 => 'خمس';

  @override
  String get archivedCount6 => 'ست';

  @override
  String get archivedCount7 => 'سبع';

  @override
  String get archivedCount8 => 'ثماني';

  @override
  String get archivedCount9 => 'تسع';

  @override
  String get archivedCount10 => 'عشر';

  @override
  String get archivedChatRestingHereIt =>
      'تستريح هنا. تبقى صامتة حتى يكتب صاحبها، ثم تعود إلى الأعلى.';

  @override
  String get archivedChatsRestingHere =>
      'تستريح هنا. تبقى صامتة حتى يكتب أحد، ثم تعود إلى الأعلى.';

  @override
  String get archivedNothingArchived => 'لا شيء في الأرشيف';

  @override
  String get archivedArchivedChatsAreStill =>
      'المحادثات المؤرشفة تبقى مشفّرة بين الطرفين';

  @override
  String get archivedUnarchive => 'إلغاء الأرشفة';

  @override
  String get avatarPickerThePeopleYouMessage => 'يراه أيضًا من تراسلهم';

  @override
  String get avatarPickerBackToYourInitial => 'العودة إلى حرفك الأول';

  @override
  String get avatarPickerThatOneIsYours => 'هذا وجهك';

  @override
  String get avatarPickerPickAFace => 'اختر وجهًا';

  @override
  String get commonSave => 'حفظ';

  @override
  String get backupPassphraseMustBeAt => 'يجب ألا تقل عبارة المرور عن ١٢ حرفًا';

  @override
  String get backupPassphrasesDonTMatch => 'عبارتا المرور غير متطابقتين';

  @override
  String get backupBackupSavedKeepThe =>
      'حُفظت النسخة الاحتياطية · احفظ عبارة المرور في مكان آمن';

  @override
  String get backupKryfoBackup => 'نسخة Kryfo الاحتياطية';

  @override
  String get backupYourEncryptedKryfoBackup =>
      'نسخة Kryfo الاحتياطية المشفّرة. احفظ هذا الملف وعبارة المرور معًا في مكان آمن، فالاستعادة تحتاج إليهما كليهما.';

  @override
  String get backupBackUpKryfo => 'نسخ Kryfo احتياطيًا';

  @override
  String get backupBackUp => 'نسخ احتياطي';

  @override
  String get backupACopyToKeep => 'نسخة تحتفظ بها. ويبقى هذا الهاتف كما هو.';

  @override
  String get backupACopyToKeepDesk =>
      'نسخة تحتفظ بها. ويبقى هذا الحاسوب كما هو.';

  @override
  String get backupMoveToAnotherDevice => 'الانتقال إلى جهاز آخر';

  @override
  String get backupTheFileTakesThis =>
      'يأخذ الملف هذه الهوية معه. وبمجرد إنشائه يتوقف هذا الهاتف: لا يصل إليه شيء جديد، ولا يصل أي شيء يُرسل منه إلى أحد.';

  @override
  String get backupTheFileTakesThisDesk =>
      'يأخذ الملف هذه الهوية معه. وبمجرد إنشائه يتوقف هذا الحاسوب: لا يصل إليه شيء جديد، ولا يصل أي شيء يُرسل منه إلى أحد.';

  @override
  String get backupOneEncryptedFileYour =>
      'ملف واحد مشفّر: هويتك، وجهات اتصالك، وكل رسالة، وكل صورة ورسالة صوتية وملف. استورده على الجهاز الآخر بعبارة المرور. وإلى أن تفعل، يمكنك أن تغيّر رأيك وتبقى على هذا الهاتف.';

  @override
  String get backupOneEncryptedFileYourIdentityYour =>
      'ملف واحد مشفّر: هويتك، وجهات اتصالك، وكل رسالة، وكل صورة ورسالة صوتية وملف على هذا الهاتف الآن. ما يُقال بعد اليوم ليس فيه، فأنشئ نسخة أخرى حين يهمّك ذلك. للاستعادة تحتاج إلى الملف وعبارة المرور، كليهما.';

  @override
  String get backupOneEncryptedFileYourIdentityYourDesk =>
      'ملف واحد مشفّر: هويتك، وجهات اتصالك، وكل رسالة، وكل صورة ورسالة صوتية وملف على هذا الحاسوب الآن. ما يُقال بعد اليوم ليس فيه، فأنشئ نسخة أخرى حين يهمّك ذلك. للاستعادة تحتاج إلى الملف وعبارة المرور، كليهما.';

  @override
  String get backupPassphrase => 'عبارة المرور';

  @override
  String get backupConfirmPassphrase => 'تأكيد عبارة المرور';

  @override
  String backupWriting(Object progress) {
    return 'جارٍ الكتابة… ⁨$progress⁩';
  }

  @override
  String get backupSaveComesAfter =>
      'عندما يصبح الملف جاهزًا، ستختار أين تحفظه.';

  @override
  String get backupSaving => 'جارٍ الحفظ…';

  @override
  String backupSavedIn(String place) {
    return 'حُفظت النسخة الاحتياطية في ⁨$place⁩ · احفظ عبارة المرور في مكان آمن';
  }

  @override
  String get backupNotSaved => 'لم تُحفظ النسخة الاحتياطية. الملف ما زال هنا.';

  @override
  String get backupNotSavedNoSpace =>
      'لم تكن هناك مساحة كافية في المكان الذي اخترته للحفظ. الملف ما زال هنا، فاختر مكانًا آخر أو أفرغ بعض المساحة.';

  @override
  String get backupShareInstead => 'المشاركة بدلًا من ذلك';

  @override
  String get backupSavedUnchecked =>
      'حُفظت النسخة الاحتياطية، لكن Kryfo لم يتمكن من التحقق منها';

  @override
  String get backupHandedOver =>
      'سُلّمت النسخة الاحتياطية إلى التطبيق الذي اخترته · تحقّق من وصولها';

  @override
  String get backupMoveReachedTitle => 'هل وصل الملف إلى هاتفك الجديد؟';

  @override
  String get backupMoveReachedTitleDesk => 'هل وصل الملف إلى جهازك الجديد؟';

  @override
  String get backupMoveReachedLine => 'احتفظ بهذا الهاتف حتى تفتح الملف هناك.';

  @override
  String get backupMoveReachedLineDesk =>
      'احتفظ بهذا الحاسوب حتى تفتح الملف هناك.';

  @override
  String get backupFinishTheMove => 'إنهاء الانتقال';

  @override
  String get backupNotYet => 'ليس بعد';

  @override
  String get backupCreating => 'جارٍ الإنشاء…';

  @override
  String get backupMakeTheFileAnd => 'إنشاء الملف والانتقال';

  @override
  String get backupCreateBackup => 'إنشاء نسخة احتياطية';

  @override
  String get backupNotMade => 'تعذّر إنشاء النسخة الاحتياطية. حاول مجددًا.';

  @override
  String get backupNoSpace =>
      'لا توجد مساحة فارغة كافية على هذا الهاتف لإنشاء النسخة الاحتياطية. أفرغ بعض المساحة وحاول مجددًا.';

  @override
  String get backupNoSpaceDesk =>
      'لا توجد مساحة فارغة كافية على هذا الحاسوب لإنشاء النسخة الاحتياطية. أفرغ بعض المساحة وحاول مجددًا.';

  @override
  String get backupHiddenNotIn => 'المحادثات المخفية ليست فيه.';

  @override
  String get backupHiddenIncluded => 'محادثاتك المخفية فيه أيضًا.';

  @override
  String get backupMoveHiddenStay =>
      'تبقى المحادثات المخفية على هذا الهاتف وتُمسح معه.';

  @override
  String get backupMoveHiddenStayDesk =>
      'تبقى المحادثات المخفية على هذا الحاسوب وتُمسح معه.';

  @override
  String get backupHiddenGone =>
      'أُغلقت محادثاتك المخفية حين قُفل Kryfo. افتحها برمز PIN للمحادثات المخفية وأنشئ النسخة الاحتياطية من هناك.';

  @override
  String get blockedBlocked => 'المحظورون';

  @override
  String get blockedNoOneIsBlocked => 'لا أحد محظور';

  @override
  String get commonUnblock => 'إلغاء الحظر';

  @override
  String get bridgesConnected => 'متصل';

  @override
  String get bridgesFromTheTorProject => 'من مشروع Tor';

  @override
  String get bridgesPasteFromClipboard => 'لصق من الحافظة';

  @override
  String bridges1LineSaved(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$countString⁩ سطر محفوظ',
      many: '⁨$countString⁩ سطرًا محفوظًا',
      few: '⁨$countString⁩ أسطر محفوظة',
      two: 'سطران محفوظان',
      one: 'سطر واحد محفوظ',
      zero: 'لا أسطر محفوظة',
    );
    return '$_temp0';
  }

  @override
  String get bridgesWhenYouAskFor =>
      'عندما تطلب جسورًا، يرى مشروع Tor عنوان IP الخاص بك. هذا أمر عادي: هكذا يحصل Tor Browser وكل تطبيقات Tor على الجسور، وكل ما يعرفونه من ذلك أن أحدًا طلب جسورًا. لا شيء عن محادثاتك.';

  @override
  String get bridgesAsking => 'جارٍ الطلب…';

  @override
  String get cameraNoCameraOnThis => 'لا كاميرا في هذا الهاتف';

  @override
  String get cameraCameraNotAvailable => 'الكاميرا غير متاحة';

  @override
  String get cameraCameraPermissionIsOff => 'إذن الكاميرا معطّل';

  @override
  String get cameraOpenSettings => 'فتح الإعدادات';

  @override
  String get cameraCouldNotStripThat => 'تعذّر تنظيف تلك الصورة، فاستُبعدت';

  @override
  String get cameraNoPhotoCameOut => 'لم تُلتقط أي صورة';

  @override
  String get cameraCouldNotStartRecording => 'تعذّر بدء التسجيل';

  @override
  String get cameraTheRecordingWasLost => 'ضاع التسجيل';

  @override
  String get cameraACopyIsIn => 'توجد نسخة في صورك';

  @override
  String get cameraCouldNotSaveA => 'تعذّر حفظ نسخة على هذا الهاتف';

  @override
  String get cameraTooLongForA => 'أطول من أن يُرسل · ٥٠ م.ب كحد أقصى';

  @override
  String get cameraNeverSavedToYour => 'لا يُحفظ أبدًا في صورك';

  @override
  String get cameraNoExifNeverSaved => 'بلا EXIF، ولا يُحفظ أبدًا في صورك';

  @override
  String get cameraRec => 'تسجيل';

  @override
  String get cameraSwitchCamera => 'تبديل الكاميرا';

  @override
  String get cameraStopRecording => 'إيقاف التسجيل';

  @override
  String get cameraStartRecording => 'بدء التسجيل';

  @override
  String get cameraTakeAPhoto => 'التقاط صورة';

  @override
  String get cameraKeepACopy => 'الاحتفاظ بنسخة';

  @override
  String get cameraUseThis => 'استخدام هذه';

  @override
  String get chatYouAreOfflineThis =>
      'أنت غير متصل · ستُرسل تلقائيًا عند عودة الاتصال';

  @override
  String get chatStillConnectingToTor =>
      'ما زال الاتصال بـ Tor جاريًا · ستُرسل من تلقاء نفسها';

  @override
  String chatS(Object seconds) {
    return '⁨$seconds⁩ ث';
  }

  @override
  String chatM(Object seconds) {
    return '⁨$seconds⁩ د';
  }

  @override
  String chatH(Object seconds) {
    return '⁨$seconds⁩ س';
  }

  @override
  String chatD(Object seconds) {
    return '⁨$seconds⁩ ي';
  }

  @override
  String get chat0s => '٠ ث';

  @override
  String chatHM(Object h, Object m) {
    return '⁨$h⁩ س ⁨$m⁩ د';
  }

  @override
  String chatMS(Object m, Object s) {
    return '⁨$m⁩ د ⁨$s⁩ ث';
  }

  @override
  String chatS2(Object s) {
    return '⁨$s⁩ ث';
  }

  @override
  String get chatNewMessages => 'رسائل جديدة';

  @override
  String chatEarlierMessagesArrived(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'وصلت ⁨$countString⁩ رسالة سابقة',
      many: 'وصلت ⁨$countString⁩ رسالة سابقة',
      few: 'وصلت ⁨$countString⁩ رسائل سابقة',
      two: 'وصلت رسالتان سابقتان',
      one: 'وصلت رسالة سابقة',
      zero: 'وصلت ⁨$countString⁩ رسالة سابقة',
    );
    return '$_temp0';
  }

  @override
  String get chatUnsave => 'إلغاء الحفظ';

  @override
  String get chatForward => 'إعادة توجيه';

  @override
  String get commonShare => 'مشاركة';

  @override
  String get commonCopied => 'تم النسخ';

  @override
  String get commonCopy => 'نسخ';

  @override
  String get chatUnpin => 'إلغاء التثبيت';

  @override
  String get chatPin => 'تثبيت';

  @override
  String get chatStopSending => 'إيقاف الإرسال';

  @override
  String get chatUnsend => 'سحب';

  @override
  String get commonEdit => 'تعديل';

  @override
  String get chatYou => 'أنت';

  @override
  String get chatUnsendMessage => 'سحب الرسالة';

  @override
  String get chatItDisappearsWithNo =>
      'ستُحذف من الهاتفين، إلا إذا كانت قد حُفظت. لا يمكن التراجع عن هذا.';

  @override
  String get chatItDisappearsWithNoDesk =>
      'ستُحذف من الجهازين، إلا إذا كانت قد حُفظت. لا يمكن التراجع عن هذا.';

  @override
  String chatThisChatHasPins(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'في هذه المحادثة ⁨$countString⁩ رسالة مثبّتة بالفعل',
      many: 'في هذه المحادثة ⁨$countString⁩ رسالة مثبّتة بالفعل',
      few: 'في هذه المحادثة ⁨$countString⁩ رسائل مثبّتة بالفعل',
      two: 'في هذه المحادثة رسالتان مثبّتتان بالفعل',
      one: 'في هذه المحادثة رسالة مثبّتة بالفعل',
      zero: 'في هذه المحادثة ⁨$countString⁩ رسالة مثبّتة بالفعل',
    );
    return '$_temp0';
  }

  @override
  String get chatUnpinThisMessage => 'إلغاء تثبيت هذه الرسالة؟';

  @override
  String get chatPinThisMessage => 'تثبيت هذه الرسالة؟';

  @override
  String get chatItLeavesThePinned =>
      'ستُزال من قائمة الرسائل المثبّتة لدى كليكما.';

  @override
  String get chatItGoesUnderThe =>
      'ستظهر في شريط التثبيت أعلى المحادثة، لدى كليكما.';

  @override
  String get chatPinIt => 'تثبيتها';

  @override
  String get chatNotNow => 'ليس الآن';

  @override
  String get chatEditMessage => 'تعديل الرسالة';

  @override
  String get chat30Seconds => '٣٠ ثانية';

  @override
  String get chat1Minute => 'دقيقة واحدة';

  @override
  String get chat5Minutes => '٥ دقائق';

  @override
  String get chat1Hour => 'ساعة واحدة';

  @override
  String get chat24Hours => '٢٤ ساعة';

  @override
  String get chatGhostTimer => 'الرسائل المؤقتة';

  @override
  String get chatHowLongAfterReading =>
      'بعد كم من الوقت من قراءتها تختفي الرسائل؟ رسائلك تُحسب من لحظة إرسالها.';

  @override
  String get chatCamera => 'الكاميرا';

  @override
  String get chatNoExifNeverSaved => 'بلا EXIF، ولا يُحفظ أبدًا في صورك';

  @override
  String get chatGallery => 'المعرض';

  @override
  String get chatVideo => 'فيديو';

  @override
  String get chatGifFromPhone => 'صورة GIF من الهاتف';

  @override
  String get chatGifFromPhoneDesk => 'صورة GIF من الحاسوب';

  @override
  String get chatFile2 => 'ملف';

  @override
  String get chatAFewSeconds => 'بضع ثوانٍ';

  @override
  String get chatUnderAMinute => 'أقل من دقيقة';

  @override
  String chatRoughlyMin(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'نحو ⁨$countString⁩ د',
    );
    return '$_temp0';
  }

  @override
  String chatB2(Object b) {
    return '⁨$b⁩ بايت';
  }

  @override
  String chatKb2(Object b) {
    return '⁨$b⁩ ك.ب';
  }

  @override
  String chatMb2(Object b) {
    return '⁨$b⁩ م.ب';
  }

  @override
  String get chatSendThis => 'إرسال هذا الملف؟';

  @override
  String chatOverTor(Object humanBytes, Object wireEstimate) {
    return '⁨$humanBytes⁩ · ⁨$wireEstimate⁩ عبر Tor';
  }

  @override
  String get chatBigFilesGoOut =>
      'تُرسل الملفات الكبيرة على قطع صغيرة مشفّرة، لذا تستغرق بعض الوقت. أبقِ التطبيق مفتوحًا ويستمر الإرسال.';

  @override
  String get chatSendIt => 'إرساله';

  @override
  String get chatCouldNotReadThat => 'تعذّرت قراءة ذلك الملف';

  @override
  String get chatCouldNotCleanThat => 'تعذّر تنظيف ذلك الفيديو';

  @override
  String get chatCouldNotCleanThatPictureSend =>
      'تعذّر تنظيف تلك الصورة · أرسلها كصورة عادية';

  @override
  String get chatGifTooBig8 => 'ملف GIF كبير جدًا · ٨ م.ب كحد أقصى';

  @override
  String get chatCouldNotCleanThatGif => 'تعذّر تنظيف ملف GIF هذا';

  @override
  String get chatTorIsNotUp => 'Tor غير متصل بعد · بلا معاينة للرابط';

  @override
  String get chatCouldnTReachIt =>
      'تعذّر الوصول إلى الصفحة · بلا معاينة للرابط';

  @override
  String get chatNoTitleCameBack => 'هذه الصفحة بلا عنوان · بلا معاينة للرابط';

  @override
  String get chatCouldnTFetchIt => 'تعذّر تحميل المعاينة';

  @override
  String get chatNoSignalSessionRe => 'لا توجد جلسة Signal. أعد الاقتران';

  @override
  String get chatMessageUnavailable => 'الرسالة غير متاحة';

  @override
  String get chatYou2 => 'أنت';

  @override
  String get chatThem => 'الطرف الآخر';

  @override
  String get chatVoiceMessage => 'رسالة صوتية';

  @override
  String get chatQuotedPhoto => 'صورة';

  @override
  String get chatViewContact => 'عرض جهة الاتصال';

  @override
  String get chatSharedPhotos => 'الصور المشتركة';

  @override
  String chatSharedPhotoCount(int count, Object title) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$countString⁩ صورة',
      many: '⁨$countString⁩ صورة',
      few: '⁨$countString⁩ صور',
      two: 'صورتان',
      one: 'صورة واحدة',
      zero: '⁨$countString⁩ صورة',
    );
    return '$_temp0 · ⁨$title⁩';
  }

  @override
  String get chatUnmuteNotifications => 'إلغاء كتم الإشعارات';

  @override
  String get chatMuteNotifications => 'كتم الإشعارات';

  @override
  String get chatArchiveChat => 'أرشفة المحادثة';

  @override
  String get chatWallpaper => 'الخلفية';

  @override
  String get chatClearConversation => 'إفراغ المحادثة';

  @override
  String get chatNoteOnThisContact => 'ملاحظة عن جهة الاتصال هذه';

  @override
  String get chatPinToTop => 'تثبيت في الأعلى';

  @override
  String get chatBlockContact => 'حظر جهة الاتصال';

  @override
  String get chatUnpinned => 'أُلغي التثبيت';

  @override
  String get chatPinnedToTop => 'ثُبّتت في الأعلى';

  @override
  String get chatJustForYouNever =>
      'لك وحدك. لا تُرسل أبدًا، ولا تغادر هذا الهاتف أبدًا.';

  @override
  String get chatJustForYouNeverDesk =>
      'لك وحدك. لا تُرسل أبدًا، ولا تغادر هذا الحاسوب أبدًا.';

  @override
  String get chatAQuietReminder => 'تذكير هادئ…';

  @override
  String get chatNoteSaved => 'حُفظت الملاحظة';

  @override
  String get chatClearThisConversation => 'إفراغ هذه المحادثة؟';

  @override
  String get chatEveryMessageHereIs =>
      'تُمسح كل رسالة هنا من هذا الهاتف. هذا يُفرغ نسختك فقط، ولا يمسّ جهازه.';

  @override
  String get chatEveryMessageHereIsDesk =>
      'تُمسح كل رسالة هنا من هذا الحاسوب. هذا يُفرغ نسختك فقط، ولا يمسّ جهازه.';

  @override
  String get chatClear => 'إفراغ';

  @override
  String get chatBlockThisContact => 'حظر جهة الاتصال هذه؟';

  @override
  String get chatTheirMessagesStopArriving =>
      'تتوقف رسائله عن الوصول ويختفي من محادثاتك. لن يُبلَّغ بذلك أبدًا. يمكنك إلغاء الحظر في أي وقت من الإعدادات.';

  @override
  String get commonBlock => 'حظر';

  @override
  String get chatSaved => 'حُفظت الرسالة';

  @override
  String get chatRemovedFromSaved => 'أُزيلت من المحفوظات';

  @override
  String get chatForwardTo => 'إعادة توجيه إلى';

  @override
  String get chatNoContactsToForward => 'لا جهات اتصال لإعادة التوجيه إليها';

  @override
  String get chatToday => 'اليوم';

  @override
  String get chatYesterday => 'أمس';

  @override
  String get chatThisMessageCanT => 'لا يمكن عرض هذه الرسالة';

  @override
  String get chatJumpToTheNewest => 'الانتقال إلى الأحدث';

  @override
  String get chatBuildingAPrivateRoute =>
      'جارٍ بناء مسار خاص · الاتصال الأول هو البطيء، وما بعده سريع. كل ما ترسله الآن ينتظر في الطابور ويُسلَّم تلقائيًا.';

  @override
  String get chatTheNextPhotoYou =>
      'الصورة التالية التي ترسلها تُفتح محمية · يمنع Kryfo لقطات الشاشة لها';

  @override
  String get chatPhotoProtectionOff => 'حماية الصور معطّلة';

  @override
  String get chatAcceptToReplyThey =>
      'اقبل لترد. يمكنه إرسال رسالة واحدة أخرى حتى تقبل.';

  @override
  String chatIntroducedYouAcceptTo(Object introducer) {
    return 'عرّفكما ⁨$introducer⁩ على بعضكما. اقبل لترد.';
  }

  @override
  String chatIntroducedYouSayHello(Object vouchNames) {
    return 'عرّفكما ⁨$vouchNames⁩ على بعضكما. قل مرحبًا، فقد وصلته بطاقتك أيضًا.';
  }

  @override
  String get chatIntroduceTo => 'تعريفه على...';

  @override
  String get chatAcceptThemFirst => 'اقبله أولًا';

  @override
  String get chatMessageRequest => 'طلب مراسلة';

  @override
  String get chatTheyNeedToAccept =>
      'يجب أن يقبل قبل أن تتمكن من مواصلة المحادثة.';

  @override
  String get chatWaitingForThemTo => 'بانتظار قبوله لطلبك';

  @override
  String get chatTheyMayNotKnow => 'ربما لا يعرف أنك قبلت';

  @override
  String get chatYouBlockedThisContact => 'لقد حظرت جهة الاتصال هذه';

  @override
  String get chatSupporter => 'داعم';

  @override
  String get chatEncryptedDirect => 'مشفّرة · مباشرة';

  @override
  String get chatEncryptedOverTor => 'مشفّرة · عبر Tor';

  @override
  String get chatSearchThisChat => 'البحث في هذه المحادثة';

  @override
  String get chatContactOptions => 'خيارات جهة الاتصال';

  @override
  String get commonClose => 'إغلاق';

  @override
  String get chatFindInConversation => 'البحث في المحادثة';

  @override
  String get chatNoMatches => 'لا نتائج';

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
      other: '*⁨$posString⁩* من ⁨$countString⁩ نتيجة',
      many: '*⁨$posString⁩* من ⁨$countString⁩ نتيجة',
      few: '*⁨$posString⁩* من ⁨$countString⁩ نتائج',
      two: '*⁨$posString⁩* من نتيجتين',
      one: '*⁨$posString⁩* من نتيجة واحدة',
      zero: '*⁨$posString⁩* من ⁨$countString⁩ نتيجة',
    );
    return '$_temp0';
  }

  @override
  String get chatPreviousMatch => 'النتيجة السابقة';

  @override
  String get chatNextMatch => 'النتيجة التالية';

  @override
  String get chatPhotoUnavailable => 'الصورة غير متاحة';

  @override
  String get chatDelivered => 'وصلت';

  @override
  String get chatEdited => 'معدّلة';

  @override
  String get chatFailedTapToRetry => 'فشل · اضغط لإعادة المحاولة';

  @override
  String get chatReplyingTo => 'ردًا عليه';

  @override
  String get chatReplyingToYourself => 'ردًا على نفسك';

  @override
  String get chatReply => 'رد';

  @override
  String get chatSayHi => 'قل مرحبًا.';

  @override
  String get chatJustTheTwoOf => 'أنتما فقط، والمحادثة مشفّرة بين الطرفين.';

  @override
  String get chatSayHiSoThey => 'قل مرحبًا حتى يراك';

  @override
  String get chatTheyWonTKnow => 'لن يعرف أنك أضفته حتى تصله رسالتك الأولى.';

  @override
  String get chatWave => 'لوّح';

  @override
  String get chatMicPermissionNeeded => 'يلزم إذن الميكروفون';

  @override
  String get chatTheMicWouldNot => 'تعذّر تشغيل الميكروفون. أعد المحاولة';

  @override
  String get chatReleaseToCancel => 'أفلت للإلغاء';

  @override
  String get chatVoiceHiddenSlideTo => 'الصوت مموّه · اسحب للإلغاء';

  @override
  String get chatSlideToCancel => 'اسحب للإلغاء';

  @override
  String get chatGhostMode => 'الرسائل المؤقتة';

  @override
  String chatMessagesBurnAfter(Object humanBurn) {
    return 'تختفي بعد ⁨$humanBurn⁩';
  }

  @override
  String get chatTimedMessages => 'الرسائل المؤقتة';

  @override
  String get chatOpenTheCamera => 'فتح الكاميرا';

  @override
  String get chatAttachAPhoto => 'إرفاق صورة';

  @override
  String get chatMessage => 'رسالة';

  @override
  String get commonSend => 'إرسال';

  @override
  String get chatNoPhotosInThis => 'لا صور في هذه المحادثة بعد';

  @override
  String get chatHoldToRecord => 'اضغط مطولًا لتسجيل رسالة صوتية';

  @override
  String get chatSecurityCodeChanged => 'تغيّر رمز الأمان';

  @override
  String get chatCompareTitle => 'قارن رقم الأمان';

  @override
  String chatCompareLine(Object peerName) {
    return 'يمكن نسخ الكلمات الثلاث. لتتأكد أن هذه المحادثة مع ⁨$peerName⁩ فعلًا، قارن رقم الأمان معه، وجهًا لوجه أو في مكالمة.';
  }

  @override
  String get chatCompareLater => 'لاحقًا';

  @override
  String get chatCompareFolded => 'لم يُقارَن رقم الأمان بعد';

  @override
  String get chatCompareNow => 'قارن';

  @override
  String get chatCompareDismiss => 'إخفاء';

  @override
  String chatKeyHeldLine(Object peerName) {
    return 'سبق أن تحققت من ⁨$peerName⁩. لن يُرسل شيء حتى تتحقق من الرقم الجديد أو تقبل المفتاح الجديد. رسائله ما زالت تصل.';
  }

  @override
  String get chatCheckTheNumber => 'تحقق من الرقم';

  @override
  String get chatAcceptNewKey => 'قبول المفتاح الجديد';

  @override
  String get chatAcceptNewKeyTitle => 'أتقبل مفتاحه الجديد؟';

  @override
  String chatAcceptNewKeyLine(Object peerName) {
    return 'سيرسل Kryfo بعدها إلى المفتاح الجديد دون تحقق، ولن يظهر ⁨$peerName⁩ بعد الآن كجهة متحقَّق منها. يمكنك التحقق منه مجددًا في أي وقت.';
  }

  @override
  String chatMayHaveReinstalledOr(Object peerName) {
    return 'ربما أعاد ⁨$peerName⁩ تثبيت التطبيق، أو ربما ينتحل أحدٌ شخصيته. قارن أرقام الأمان لتتأكد.';
  }

  @override
  String get chatOk => 'حسنًا';

  @override
  String get chatVerify => 'تحقّق';

  @override
  String get cleanKryfoCanTClean =>
      'لا يستطيع Kryfo تنظيف هذا النوع من الملفات بعد.';

  @override
  String get cleanThisIsAMotion => 'هذه صورة متحركة.';

  @override
  String get cleanThisPictureIsToo => 'هذه الصورة أكبر من أن تُنظَّف هنا.';

  @override
  String get cleanThisFileIsDamaged => 'هذا الملف تالف أو مبتور.';

  @override
  String get cleanKryfoCouldNotMake => 'لم يستطع Kryfo تنظيف هذا الملف.';

  @override
  String get cleanNotEnoughRoomOn => 'لا توجد مساحة كافية على الهاتف.';

  @override
  String get cleanKryfoCouldNotOpen => 'لم يستطع Kryfo فتح ذلك الملف.';

  @override
  String get cleanItCleansJpegPng =>
      'يُنظّف ملفات JPEG وPNG وWebP وHEIC وAVIF وGIF وMP4 وMOV. لم يتغيّر شيء.';

  @override
  String get cleanItHoldsAShort =>
      'تحمل مقطع فيديو قصيرًا بجانب الصورة، ولا يستطيع Kryfo تنظيف هذا الجزء بعد. أوقف خاصية الحركة في الكاميرا، أو أرسل لقطة شاشة لها.';

  @override
  String get cleanPicturesOver64Mb =>
      'الصور التي تتجاوز ٦٤ م.ب لا تُنظَّف على الهاتف. لم يتغيّر شيء.';

  @override
  String get cleanKryfoCouldNotRead =>
      'لم يستطع Kryfo قراءته حتى النهاية، لذا لن يعدّه نظيفًا. لم تُنشأ أي نسخة.';

  @override
  String get cleanSomethingInsideIsOf =>
      'بداخله شيء من نوع لا يعرف كيف يزيله، لذا لم تُنشأ أي نسخة.';

  @override
  String get cleanFreeSomeSpaceAnd =>
      'حرّر بعض المساحة ثم أعد المحاولة. لم يتغيّر شيء.';

  @override
  String get cleanTheAppThatShared =>
      'ربما استعاده التطبيق الذي شاركه. جرّب مشاركته مجددًا.';

  @override
  String get cleanNoAppOnThis => 'لم يستلم أي تطبيق على هذا الهاتف الملف.';

  @override
  String get cleanCouldNotSaveIt =>
      'تعذّر حفظه. تأكد من وجود مساحة على الهاتف.';

  @override
  String get cleanTheOriginalIsGone => 'حُذف الأصل. وتبقى النسخة النظيفة.';

  @override
  String get cleanAndroidWouldNotDelete =>
      'رفض أندرويد حذفه. احذفه من المعرض يدويًا.';

  @override
  String get cleanCleanCopy => 'نسخة نظيفة';

  @override
  String get cleanShareCleanCopy => 'مشاركة النسخة النظيفة';

  @override
  String get cleanSaveToGallery => 'حفظ في المعرض';

  @override
  String get commonStop => 'إيقاف';

  @override
  String get cleanReadingTheFile => 'جارٍ قراءة الملف';

  @override
  String get cleanCleaning => 'جارٍ التنظيف';

  @override
  String cleanOf(Object prettySize, Object prettySize2) {
    return '⁨$prettySize⁩ من ⁨$prettySize2⁩';
  }

  @override
  String get cleanEverythingStaysOnThis => 'يبقى كل شيء على هذا الهاتف.';

  @override
  String get cleanAlreadyClean => 'نظيف أصلًا.';

  @override
  String get cleanClean => 'نظيف.';

  @override
  String get cleanThereWasNothingTo => 'لم يكن فيه ما يُعثر عليه.';

  @override
  String get cleanNothingLeftToFind => 'لم يبقَ ما يُعثر عليه.';

  @override
  String get cleanSameVideoSameQuality => 'الفيديو نفسه، بالجودة نفسها';

  @override
  String get cleanSamePictureSameQuality => 'الصورة نفسها، بالجودة نفسها';

  @override
  String get cleanSamePicture => 'الصورة نفسها';

  @override
  String cleanRemoved(Object label) {
    return '⁨$label⁩، أُزيل';
  }

  @override
  String get cleanRemoved2 => 'أُزيل';

  @override
  String get cleanWithTheLocationInside =>
      'وفيه الموقع. كل من يحصل عليه يعرف شارعك.';

  @override
  String get cleanWithEverythingItKnew => 'وفيه كل ما كان يعرفه.';

  @override
  String get cleanOriginal => 'الأصل';

  @override
  String get cleanClean2 => 'نظيف';

  @override
  String get cleanSavedToYourGallery => 'حُفظ في معرضك.';

  @override
  String cleanTheOriginalIsStill(Object what) {
    return 'الأصل ما زال موجودًا أيضًا، ⁨$what⁩';
  }

  @override
  String cleanTheOriginalIsStillWhereIt(Object what) {
    return 'الأصل ما زال في مكانه، ⁨$what⁩ لا يستطيع Kryfo إزالته من هنا، فاحذفه من التطبيق الذي جاء منه.';
  }

  @override
  String get cleanDeleteTheOriginal => 'حذف الأصل';

  @override
  String get cleanKeepBoth => 'إبقاء الاثنين';

  @override
  String get commonDone => 'تم';

  @override
  String get cleanAndroidWillAskYou => 'سيطلب منك أندرويد التأكيد';

  @override
  String get contactYourNameForThem => 'اسم مستعار له';

  @override
  String get contactStaysOnThisPhone => 'يبقى على هذا الهاتف. لا يراه أبدًا.';

  @override
  String get contactStaysOnThisPhoneDesk =>
      'يبقى على هذا الحاسوب. لا يراه أبدًا.';

  @override
  String get contactClear => 'إزالة';

  @override
  String get contactMessage => 'مراسلة';

  @override
  String get contactKeysVerified => 'تم التحقق من المفاتيح';

  @override
  String get contactVerifyKeys => 'التحقق من المفاتيح';

  @override
  String get contactVouches => 'التزكيات';

  @override
  String get contactUnmute => 'إلغاء الكتم';

  @override
  String get contactMute => 'كتم';

  @override
  String get contactUnpin => 'إلغاء التثبيت';

  @override
  String get contactPinToTop => 'تثبيت في الأعلى';

  @override
  String get contactArchive => 'أرشفة';

  @override
  String get contactOutOfTheList => 'خارج القائمة حتى يكتب مجددًا';

  @override
  String contactBlock(Object name) {
    return 'حظر ⁨$name⁩؟';
  }

  @override
  String get contactTheirMessagesStopArriving =>
      'تتوقف رسائله عن الوصول. ولا يُبلَّغ بذلك.';

  @override
  String get contactDeleteChat => 'حذف المحادثة';

  @override
  String get contactMessagesAndContactGone =>
      'الرسائل وجهة الاتصال، تُحذف من هذا الهاتف';

  @override
  String get contactMessagesAndContactGoneDesk =>
      'الرسائل وجهة الاتصال، تُحذف من هذا الحاسوب';

  @override
  String get contactDeleteThisChat => 'حذف هذه المحادثة؟';

  @override
  String get contactEveryMessageAndThe =>
      'كل رسالة وجهة الاتصال نفسها، تُحذف من هذا الهاتف. ولا يُرسل إليه أي شيء.';

  @override
  String get contactEveryMessageAndTheDesk =>
      'كل رسالة وجهة الاتصال نفسها، تُحذف من هذا الحاسوب. ولا يُرسل إليه أي شيء.';

  @override
  String get commonDelete => 'حذف';

  @override
  String get contactDeleted => 'حُذفت';

  @override
  String get contactToday => 'اليوم';

  @override
  String contactD(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$count⁩ يوم',
      many: '⁨$count⁩ يومًا',
      few: '⁨$count⁩ أيام',
      two: 'يومان',
      one: 'يوم',
      zero: '⁨$count⁩ يوم',
    );
    return '$_temp0';
  }

  @override
  String contactMo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$count⁩ شهر',
      many: '⁨$count⁩ شهرًا',
      few: '⁨$count⁩ أشهر',
      two: 'شهران',
      one: 'شهر',
      zero: '⁨$count⁩ شهر',
    );
    return '$_temp0';
  }

  @override
  String contactY(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$count⁩ سنة',
      many: '⁨$count⁩ سنة',
      few: '⁨$count⁩ سنوات',
      two: 'سنتان',
      one: 'سنة',
      zero: '⁨$count⁩ سنة',
    );
    return '$_temp0';
  }

  @override
  String get contactVerified => 'تم التحقق';

  @override
  String get contactChatting => 'تتراسلان منذ';

  @override
  String get contactNothingSharedYet => 'لا شيء مشترك بعد';

  @override
  String contactSharedMedia(Object count) {
    return 'الوسائط المشتركة · ⁨$count⁩';
  }

  @override
  String get donateBitcoin => 'Bitcoin';

  @override
  String get donateText => '₿';

  @override
  String get donateBadgeUnlocks => 'تُفتح شارة';

  @override
  String get donateMonero => 'Monero';

  @override
  String get donateManualNoBadge => 'يدوي · بلا شارة';

  @override
  String get donateSolana => 'Solana';

  @override
  String get donateEthereum => 'Ethereum';

  @override
  String get donateText2 => 'Ξ';

  @override
  String donateYourEarlierBitcoinPayment(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter': 'رُصدت دفعتك السابقة بـ bitcoin · فُتحت شارة الداعم',
      'patron': 'رُصدت دفعتك السابقة بـ bitcoin · فُتحت شارة الراعي',
      'guardian': 'رُصدت دفعتك السابقة بـ bitcoin · فُتحت شارة الحارس',
      'other': 'رُصدت دفعتك السابقة بـ bitcoin · فُتحت شارة الداعم',
    });
    return '$_temp0';
  }

  @override
  String get donateSupport => 'ادعم';

  @override
  String get donateKeepKryfo => 'أبقِ Kryfo *مستقلًا*';

  @override
  String get donateNoAdsNoInvestors =>
      'لا إعلانات، ولا مستثمرون، ولا شيء للبيع. يعيش على ما يقدّمه الداعمون.';

  @override
  String get donateBackItAnonymouslyBadge =>
      'ادعمه دون أن تكشف هويتك. الشارة اختيارية.\n*كل ميزات الخصوصية مجانية.*';

  @override
  String get donateAuditTitle => 'ساعد في تمويل تدقيق أمني';

  @override
  String get donateAuditLine =>
      'التبرعات هنا تُحسب ضمن تمويل تدقيق مستقل. سيُنشر التقرير الكامل للجميع.';

  @override
  String get donateCard => 'بطاقة';

  @override
  String get donateCardOneTime =>
      'تبرع لمرة واحدة من متصفحك. أنت تختار المبلغ.';

  @override
  String get donateCardMarios =>
      'إلى أن يجهز مضيفنا المالي، تذهب مدفوعات البطاقات مباشرةً إلى Marios.';

  @override
  String get donateCardSeesName =>
      'شركة الدفع ترى اسمك. العملات المشفرة هي الخيار الخاص.';

  @override
  String get donateCardPay => 'ادفع بالبطاقة';

  @override
  String get donateNoBitcoinCard => 'ليس لديك Bitcoin؟ ادفع بالبطاقة';

  @override
  String get donateCardNoBadge => 'التبرع بالبطاقة لا يفتح شارة.';

  @override
  String donateAddressCheckItAgainst(Object coinName) {
    return 'عنوان ⁨$coinName⁩ · طابقه مع محفظتك';
  }

  @override
  String get donateAddressCopiedClearsIn =>
      'نُسخ العنوان · يُزال من الحافظة بعد ٦٠ ث';

  @override
  String get donateCopyAddress => 'نسخ العنوان';

  @override
  String get donateBitcoinIsVerifiedBy =>
      'نتحقق من bitcoin عبر عقدتنا الخاصة، لذا تُفتح شارتك تلقائيًا فور وصول الدفعة.';

  @override
  String get donateWeCanTVerify =>
      'لا يمكننا التحقق من هذه السلسلة دون سؤال خدمة خارجية عنك، لذا لا نفعل. أرسل إن شئت. لن تُفتح بها شارة.';

  @override
  String get donateBitcoinBadgesNeedOnion =>
      'شارات bitcoin تحتاج إلى وضع Onion';

  @override
  String get donateSwitchToOnion => 'التبديل إلى Onion';

  @override
  String get donatePayWithBitcoin => 'ادفع بـ bitcoin  ←';

  @override
  String get donateBadgesStartAt20 => 'تبدأ الشارات من ٢٠ دولارًا';

  @override
  String get donateShowTheAddress => 'أظهر العنوان';

  @override
  String donateReviewAmount(String amount) {
    return '$amount بـ bitcoin';
  }

  @override
  String get donateWhatTheBadgeGives => 'ما تمنحك إياه الشارة';

  @override
  String get donateGivesMark =>
      'علامة بجانب اسمك. أنت تختار من يراها، أو لا أحد.';

  @override
  String get donateGivesReceipt =>
      'إيصال موقَّع محفوظ على هذا الهاتف. يثبت الشارة دون أي حساب.';

  @override
  String get donateGivesReceiptDesk =>
      'إيصال موقَّع محفوظ على هذا الحاسوب. يثبت الشارة دون أي حساب.';

  @override
  String get donateGivesFree =>
      'تبقى كل ميزات الخصوصية مجانية، بشارة أو بدونها.';

  @override
  String get donateAddressOnTap =>
      'لا يُنشأ العنوان إلا حين تنقر في الأسفل. يبقى لك لمدة ساعة، فإن عدت تحصل على العنوان نفسه.';

  @override
  String get donateBitcoinBusy =>
      'Bitcoin مشغول الآن. حاول لاحقًا أو ادفع بالبطاقة.';

  @override
  String get donateBusyPlainAddress =>
      'لا يزال بإمكانك إرسال bitcoin إلى العنوان أدناه. لا يمنح شارة.';

  @override
  String get donateSameAddressAgain =>
      'هذا هو العنوان الذي فتحته من قبل. إن كنت قد أرسلت، فانتظر هنا.';

  @override
  String get donateReachingThePaymentService =>
      'جارٍ الوصول إلى خدمة الدفع عبر Tor…';

  @override
  String get donateThisCanTakeUp => 'قد يستغرق هذا دقيقة أو دقيقتين';

  @override
  String donateSThisCanTake(Object waited) {
    return '⁨$waited⁩ ث · قد يستغرق هذا دقيقة أو دقيقتين';
  }

  @override
  String get donateUseTheAddressInstead => 'استخدام العنوان بدلًا من ذلك';

  @override
  String get donateThePaymentServiceIs =>
      'خدمة الدفع عنوان onion، ولا يصل إليها إلا وضع Onion. لم يُرسل شيء.';

  @override
  String get donateTorWasSlowTo =>
      'تأخر Tor في الوصول إلى خدمة الدفع. يمكنك التبرع إلى العنوان أدناه، لكن شارتك لن تُفتح تلقائيًا. أعد المحاولة لاحقًا للحصول على الشارة.';

  @override
  String get donateThePaymentServiceIsHavingTrouble =>
      'تواجه خدمة الدفع مشكلة الآن. ما زال بإمكانك التبرع إلى العنوان أدناه، لكن شارتك لن تُفتح تلقائيًا. أعد المحاولة لاحقًا للحصول على الشارة.';

  @override
  String get commonTryAgain => 'إعادة المحاولة';

  @override
  String donateBtc(Object btc) {
    return '⁨$btc⁩ BTC';
  }

  @override
  String donateSendExactlyThisAmount(Object fmtLeft) {
    return 'أرسل هذا المبلغ بالضبط · ينتهي خلال ⁨$fmtLeft⁩';
  }

  @override
  String get donateOpenWallet => 'فتح المحفظة';

  @override
  String get donateThisScreenUpdatesItself =>
      'تتحدّث هذه الشاشة تلقائيًا لحظة رصد دفعتك.\nأبقِها مفتوحة. لا يُخزَّن شيء، ولا شيء يكشف هويتك.';

  @override
  String get donateWatchingTheChainFor => 'نراقب السلسلة بحثًا عن دفعتك';

  @override
  String get donateThisInvoiceExpired => 'انتهت صلاحية هذه الفاتورة';

  @override
  String get donateInvoicesTimeOutIf =>
      'للفواتير مهلة. إن كنت أرسلت الدفعة بالفعل، فأبقِ هذه الشاشة مفتوحة: نسأل الخدمة مجددًا كل دقيقة لبعض الوقت، ثم في المرة القادمة التي تفتح فيها «ادعم». ابدأ فاتورة جديدة متى شئت.';

  @override
  String get donateNewInvoice => 'فاتورة جديدة';

  @override
  String get donateIPaidCheckAgain => 'دفعت، تحقّق مجددًا';

  @override
  String get donateNoWallet =>
      'لا يوجد تطبيق على هذا الهاتف يفتح روابط bitcoin. انسخ العنوان بدلًا من ذلك.';

  @override
  String get donateChecking => 'جارٍ التحقق…';

  @override
  String get donateNotSeenYet =>
      'لم يظهر بعد. قد يستغرق ظهور الدفعة بضع دقائق.';

  @override
  String get donatePaymentConfirmed => 'تأكّدت الدفعة';

  @override
  String get donateThankYouForKeeping => 'شكرًا لأنك تُبقي Kryfo مستقلًا.';

  @override
  String donateVerifiedOnChainYou(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter':
          'تم التحقق على السلسلة. أنت الآن داعم. لا أحد يستطيع أن ينزع ذلك منك.',
      'patron':
          'تم التحقق على السلسلة. أنت الآن راعٍ. لا أحد يستطيع أن ينزع ذلك منك.',
      'guardian':
          'تم التحقق على السلسلة. أنت الآن حارس. لا أحد يستطيع أن ينزع ذلك منك.',
      'other':
          'تم التحقق على السلسلة. أنت الآن داعم. لا أحد يستطيع أن ينزع ذلك منك.',
    });
    return '$_temp0';
  }

  @override
  String donateVerifiedBadgeStays(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter':
          'تم التحقق على السلسلة. شكرًا لعطائك مرة أخرى. تبقى لك شارة الداعم.',
      'patron':
          'تم التحقق على السلسلة. شكرًا لعطائك مرة أخرى. تبقى لك شارة الراعي.',
      'guardian':
          'تم التحقق على السلسلة. شكرًا لعطائك مرة أخرى. تبقى لك شارة الحارس.',
      'other':
          'تم التحقق على السلسلة. شكرًا لعطائك مرة أخرى. تبقى لك شارة الداعم.',
    });
    return '$_temp0';
  }

  @override
  String get donateWearMyBadge => 'إظهار شارتي';

  @override
  String get donateJustGladToHelp => 'يكفيني أني ساعدت';

  @override
  String get gettingMessagesAlwaysOn => 'متصل دائمًا';

  @override
  String get gettingMessagesMostPrivate => 'الأكثر خصوصية';

  @override
  String get gettingMessagesMessagesArriveInstantlyNothing =>
      'تصل الرسائل فورًا. لا شيء يمر خارج Tor. يستهلك البطارية أكثر من غيره.';

  @override
  String get gettingMessagesArriveInstantlyFast =>
      'تصل الرسائل فورًا على الوضع السريع. يستهلك البطارية أكثر من غيره.';

  @override
  String get gettingMessagesCheckIns => 'تفقّد دوري';

  @override
  String get gettingMessagesLightest => 'الأخف';

  @override
  String get gettingMessagesKryfoLooksForMessages =>
      'يبحث Kryfo عن الرسائل كل ١٥ دقيقة. خفيف على البطارية، لكن قد تتأخر الرسائل.';

  @override
  String get gettingMessagesAGenericAlertWith =>
      'تنبيه عام، بلا مرسِل ولا نص رسالة';

  @override
  String get gettingMessagesShowsMessageTextIn =>
      'يُظهر نص الرسائل في الإشعارات، حتى عندما يكون Kryfo مقفلًا.';

  @override
  String get gettingMessagesWhenThePhoneSits =>
      'حين يبقى الهاتف ساكنًا، يباعد أندرويد بين مرات التفقّد. يُظهر السطر أعلاه آخر تفقّد فعلي. وما دام Kryfo مفتوحًا يبقى متصلًا.';

  @override
  String get groupChatJumpToTheNewest => 'الانتقال إلى الأحدث';

  @override
  String get groupChatYou => 'أنت';

  @override
  String get groupChatVoiceMessage => 'رسالة صوتية';

  @override
  String get groupChatQuotedPhoto => 'صورة';

  @override
  String get groupChatMessageUnavailable => 'الرسالة غير متاحة';

  @override
  String get groupChatTorIsNotUp => 'Tor غير متصل بعد · بلا معاينة للرابط';

  @override
  String get groupChatCouldnTReachIt =>
      'تعذّر الوصول إلى الصفحة · بلا معاينة للرابط';

  @override
  String get groupChatNoTitleCameBack =>
      'هذه الصفحة بلا عنوان · بلا معاينة للرابط';

  @override
  String get groupChatCouldnTFetchIt => 'تعذّر تحميل المعاينة';

  @override
  String get groupChatCamera => 'الكاميرا';

  @override
  String get groupChatGallery => 'المعرض';

  @override
  String get groupChatVideo => 'فيديو';

  @override
  String get groupChatGifFromPhone => 'صورة GIF من الهاتف';

  @override
  String get groupChatGifFromPhoneDesk => 'صورة GIF من الحاسوب';

  @override
  String get groupChatFile => 'ملف';

  @override
  String get groupChatCouldNotReadThat => 'تعذّرت قراءة ذلك الملف';

  @override
  String get groupChatGifTooBig8 => 'ملف GIF كبير جدًا · ٨ م.ب كحد أقصى';

  @override
  String get groupChatCouldNotCleanThat => 'تعذّر تنظيف ملف GIF هذا';

  @override
  String get groupChatCouldNotCleanThatVideo => 'تعذّر تنظيف ذلك الفيديو';

  @override
  String get groupChatCouldNotCleanThatPictureSend =>
      'تعذّر تنظيف تلك الصورة · أرسلها كصورة عادية';

  @override
  String get groupChat30Seconds => '٣٠ ثانية';

  @override
  String get groupChat1Minute => 'دقيقة واحدة';

  @override
  String get groupChat5Minutes => '٥ دقائق';

  @override
  String get groupChat1Hour => 'ساعة واحدة';

  @override
  String get groupChat24Hours => '٢٤ ساعة';

  @override
  String get groupChatBurnTimer => 'الرسائل المؤقتة';

  @override
  String get groupChatNewMessagesDisappearOnceRead =>
      'تختفي الرسائل الجديدة بعد هذه المدة من قراءتها. رسائلك تُحسب من لحظة إرسالها.';

  @override
  String get groupChatToday => 'اليوم';

  @override
  String get groupChatYesterday => 'أمس';

  @override
  String get groupChatYou2 => 'أنت';

  @override
  String groupChatThisChatHasPins(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'في هذه المحادثة ⁨$countString⁩ رسالة مثبّتة بالفعل',
      many: 'في هذه المحادثة ⁨$countString⁩ رسالة مثبّتة بالفعل',
      few: 'في هذه المحادثة ⁨$countString⁩ رسائل مثبّتة بالفعل',
      two: 'في هذه المحادثة رسالتان مثبّتتان بالفعل',
      one: 'في هذه المحادثة رسالة مثبّتة بالفعل',
      zero: 'في هذه المحادثة ⁨$countString⁩ رسالة مثبّتة بالفعل',
    );
    return '$_temp0';
  }

  @override
  String get groupChatUnpinThisMessage => 'إلغاء تثبيت هذه الرسالة؟';

  @override
  String get groupChatPinThisMessage => 'تثبيت هذه الرسالة؟';

  @override
  String get groupChatItLeavesThePinned =>
      'ستُزال من قائمة الرسائل المثبّتة لدى الجميع هنا.';

  @override
  String get groupChatItGoesUnderThe =>
      'ستظهر في شريط التثبيت أعلى المحادثة، لدى الجميع هنا.';

  @override
  String get groupChatUnpin => 'إلغاء التثبيت';

  @override
  String get groupChatPinIt => 'تثبيتها';

  @override
  String get groupChatNotNow => 'ليس الآن';

  @override
  String get groupChatSaved => 'حُفظت الرسالة';

  @override
  String get groupChatRemovedFromSaved => 'أُزيلت من المحفوظات';

  @override
  String get groupChatForwardTo => 'إعادة توجيه إلى';

  @override
  String get groupChatNoContactsToForward =>
      'لا جهات اتصال لإعادة التوجيه إليها';

  @override
  String get groupChatEditMessage => 'تعديل الرسالة';

  @override
  String get groupChatUnsendMessage => 'سحب الرسالة';

  @override
  String get groupChatItDisappearsWithNo =>
      'ستُحذف من هواتف الجميع، إلا إذا كانت قد حُفظت. لا يمكن التراجع عن هذا.';

  @override
  String get groupChatItDisappearsWithNoDesk =>
      'ستُحذف من أجهزة الجميع، إلا إذا كانت قد حُفظت. لا يمكن التراجع عن هذا.';

  @override
  String get groupChatUnsend => 'سحب';

  @override
  String groupChatThisRoomAndEverything(Object expiryWords) {
    return 'تختفي هذه الغرفة وكل ما فيها بعد ⁨$expiryWords⁩';
  }

  @override
  String groupChatGhostModeOnBurns(Object fmtBurn) {
    return 'الرسائل المؤقتة · تختفي بعد ⁨$fmtBurn⁩';
  }

  @override
  String get groupChatGroupCreatedSayHi => 'أُنشئت المجموعة. قل مرحبًا.';

  @override
  String get groupChatNoMessagesYet => 'لا رسائل بعد.';

  @override
  String get groupChatEveryoneHereReads => 'كل من هنا يقرأ ما تكتبه.';

  @override
  String get groupChatNobodyHereYet => 'لا أحد هنا بعد.';

  @override
  String get groupChatShareTheRoomLink =>
      'شارك رابط الغرفة. من ينضم يقرأ ما يُكتب من تلك اللحظة فصاعدًا.';

  @override
  String get groupChatNobodyToReadIt => 'لا أحد غيرك هنا ليقرأه.';

  @override
  String get groupChatThisMessageCanT => 'لا يمكن عرض هذه الرسالة';

  @override
  String groupChatS(Object s) {
    return '⁨$s⁩ ث';
  }

  @override
  String groupChatM(Object s) {
    return '⁨$s⁩ د';
  }

  @override
  String groupChatH(Object s) {
    return '⁨$s⁩ س';
  }

  @override
  String groupChatD(Object s) {
    return '⁨$s⁩ ي';
  }

  @override
  String groupChatHere(int count, Object time) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$time⁩ · ⁨$countString⁩ هنا',
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
      many: '⁨$countString⁩ عضوًا',
      few: '⁨$countString⁩ أعضاء',
      two: 'عضوان',
      one: 'عضو واحد',
      zero: '⁨$countString⁩ عضو',
    );
    return '$_temp0';
  }

  @override
  String get groupChatSearchThisChat => 'البحث في هذه المحادثة';

  @override
  String groupChatReplyingTo(Object name) {
    return 'ردًا على ⁨$name⁩';
  }

  @override
  String get groupChatReplyingToYou => 'ردًا عليك';

  @override
  String get groupChatTimedMessages => 'الرسائل المؤقتة';

  @override
  String get groupChatOpenTheCamera => 'فتح الكاميرا';

  @override
  String get groupChatAttachAPhoto => 'إرفاق صورة';

  @override
  String get groupChatMessage => 'رسالة';

  @override
  String get groupChatSupporter => 'داعم';

  @override
  String get groupChatEdited => 'معدّلة';

  @override
  String get groupChatTapToRetry => '! اضغط لإعادة المحاولة';

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
      other: 'أُرسلت · وصلت إلى ⁨$haveString⁩ من ⁨$countString⁩',
      many: 'أُرسلت · وصلت إلى ⁨$haveString⁩ من ⁨$countString⁩',
      few: 'أُرسلت · وصلت إلى ⁨$haveString⁩ من ⁨$countString⁩',
      two: 'أُرسلت · وصلت إلى ⁨$haveString⁩ من ⁨$countString⁩',
      one: 'أُرسلت · وصلت إلى ⁨$haveString⁩ من ⁨$countString⁩',
      zero: 'أُرسلت · في الطريق',
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
      other: 'أُرسلت · لم تصل إلى ⁨$countString⁩',
      many: 'أُرسلت · لم تصل إلى ⁨$countString⁩',
      few: 'أُرسلت · لم تصل إلى ⁨$countString⁩',
      two: 'أُرسلت · لم تصل إلى ⁨$countString⁩',
      one: 'أُرسلت · لم تصل إلى ⁨$countString⁩',
      zero: 'أُرسلت · لم تصل إلى ⁨$countString⁩',
    );
    return '$_temp0';
  }

  @override
  String get groupChatReply => 'رد';

  @override
  String get groupChatPin => 'تثبيت';

  @override
  String get groupChatUnsave => 'إلغاء الحفظ';

  @override
  String get groupChatForward => 'إعادة توجيه';

  @override
  String get groupInfoGroup => 'مجموعة';

  @override
  String get groupInfoRenameGroup => 'إعادة تسمية المجموعة';

  @override
  String get groupInfoRename => 'إعادة تسمية';

  @override
  String get groupInfoNoContactsToAdd => 'لا جهات اتصال لإضافتها';

  @override
  String get groupInfoCouldNotAdd => 'تعذّرت الإضافة';

  @override
  String groupInfoRemove(Object haloId) {
    return 'إزالة ⁨$haloId⁩؟';
  }

  @override
  String get groupInfoTheyWillStopReceiving =>
      'سيتوقف عن تلقي رسائل هذه المجموعة.';

  @override
  String get groupInfoResetLink => 'إعادة تعيين الرابط';

  @override
  String get groupInfoResetTheRoomLink => 'إعادة تعيين رابط الغرفة؟';

  @override
  String get groupInfoResetLinkLine =>
      'سيتوقف الرابط القديم عن العمل. يبقى من في الغرفة ويصلهم الرابط الجديد.';

  @override
  String get groupInfoRemoveRoomLine =>
      'يمكنه الانضمام مجددًا عبر رابط الغرفة. أعد تعيين الرابط لإبقائه خارجها. من بقي في الغرفة يصله الرابط الجديد.';

  @override
  String get groupInfoRemoveAndResetLink => 'إزالة وإعادة تعيين الرابط';

  @override
  String get groupInfoCouldNotResetLink => 'تعذّرت إعادة تعيين الرابط';

  @override
  String get roomLinkNewLinkTheOld => 'رابط جديد. الرابط القديم لم يعد يعمل.';

  @override
  String appGroupHoldsUpTo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تتسع المجموعة لـ ⁨$countString⁩ شخص كحد أقصى',
      many: 'تتسع المجموعة لـ ⁨$countString⁩ شخصًا كحد أقصى',
      few: 'تتسع المجموعة لـ ⁨$countString⁩ أشخاص كحد أقصى',
      two: 'تتسع المجموعة لشخصين كحد أقصى',
      one: 'تتسع المجموعة لشخص واحد كحد أقصى',
      zero: 'تتسع المجموعة لـ ⁨$countString⁩ شخص كحد أقصى',
    );
    return '$_temp0';
  }

  @override
  String get commonRemove => 'إزالة';

  @override
  String get groupInfoClearThisConversation => 'إفراغ هذه المحادثة؟';

  @override
  String get groupInfoEveryMessageHereIs =>
      'تُمسح كل رسالة هنا من هذا الهاتف. هذا يُفرغ نسختك فقط، ويحتفظ الأعضاء الآخرون بنسخهم.';

  @override
  String get groupInfoEveryMessageHereIsDesk =>
      'تُمسح كل رسالة هنا من هذا الحاسوب. هذا يُفرغ نسختك فقط، ويحتفظ الأعضاء الآخرون بنسخهم.';

  @override
  String get groupInfoClear => 'إفراغ';

  @override
  String get groupInfoConversationCleared => 'أُفرغت المحادثة';

  @override
  String get groupInfoLeaveRoom => 'مغادرة الغرفة؟';

  @override
  String get groupInfoLeaveGroup => 'مغادرة المجموعة؟';

  @override
  String get groupInfoEverythingInItIs =>
      'يُمسح كل ما فيها من هذا الهاتف الآن، ويزول المفتاح الذي استخدمته هنا إلى الأبد.';

  @override
  String get groupInfoEverythingInItIsDesk =>
      'يُمسح كل ما فيها من هذا الحاسوب الآن، ويزول المفتاح الذي استخدمته هنا إلى الأبد.';

  @override
  String groupChatYouWereRemovedFrom(Object name) {
    return 'تمت إزالتك من ⁨$name⁩';
  }

  @override
  String get groupInfoLeaveGroupLine =>
      'ستتوقف عن تلقي رسائلها، ويُمسح كل ما فيها من هذا الهاتف.';

  @override
  String get groupInfoLeaveGroupLineDesk =>
      'ستتوقف عن تلقي رسائلها، ويُمسح كل ما فيها من هذا الحاسوب.';

  @override
  String get groupInfoLeaveGroupAdmin =>
      'ستتوقف عن تلقي رسائلها، ويُمسح كل ما فيها من هذا الهاتف. أنت مشرفها، فبعد مغادرتك لن يستطيع أحد تغيير أعضائها أو إعادة تسميتها.';

  @override
  String get groupInfoLeaveGroupAdminDesk =>
      'ستتوقف عن تلقي رسائلها، ويُمسح كل ما فيها من هذا الحاسوب. أنت مشرفها، فبعد مغادرتك لن يستطيع أحد تغيير أعضائها أو إعادة تسميتها.';

  @override
  String get groupInfoLeaveRoomMaker =>
      'يُمسح كل ما فيها من هذا الهاتف الآن، ويزول المفتاح الذي استخدمته هنا إلى الأبد. أنت من أنشأ هذه الغرفة، لذا لن يُدخل رابطها أحدًا بعد الآن.';

  @override
  String get groupInfoLeaveRoomMakerDesk =>
      'يُمسح كل ما فيها من هذا الحاسوب الآن، ويزول المفتاح الذي استخدمته هنا إلى الأبد. أنت من أنشأ هذه الغرفة، لذا لن يُدخل رابطها أحدًا بعد الآن.';

  @override
  String get groupInfoLeave => 'مغادرة';

  @override
  String get groupInfoGroupInfo => 'معلومات المجموعة';

  @override
  String groupInfo1Member(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$countString⁩ عضو',
      many: '⁨$countString⁩ عضوًا',
      few: '⁨$countString⁩ أعضاء',
      two: 'عضوان',
      one: 'عضو واحد',
      zero: '⁨$countString⁩ عضو',
    );
    return '$_temp0';
  }

  @override
  String get groupInfoAdmin => 'مشرف';

  @override
  String get groupInfoMembers2 => 'الأعضاء';

  @override
  String get groupInfoInvite => 'دعوة';

  @override
  String get commonAdd => 'إضافة';

  @override
  String get groupInfoYou => 'أنت';

  @override
  String get groupInfoRemoveFromGroup => 'إزالة من المجموعة';

  @override
  String get groupInfoWallpaper => 'الخلفية';

  @override
  String get groupInfoSharedMedia => 'الوسائط المشتركة';

  @override
  String get groupInfoClearConversation => 'إفراغ المحادثة';

  @override
  String get groupInfoLeaveRoom2 => 'مغادرة الغرفة';

  @override
  String get groupInfoLeaveGroup2 => 'مغادرة المجموعة';

  @override
  String get groupInfoAddMembers => 'إضافة أعضاء';

  @override
  String groupInfoAdd(Object pickedLength) {
    return 'إضافة ⁨$pickedLength⁩';
  }

  @override
  String handleYouAre(Object h) {
    return 'أنت ⁦@$h⁩';
  }

  @override
  String get handleHandleDeletedThePage => 'حُذف اسم المستخدم · زالت الصفحة';

  @override
  String get handlePublicHandle => 'اسم المستخدم العام';

  @override
  String get handleOptionalYourThreeWords =>
      'اختياري. كلماتك الثلاث تبقى صالحة في كل الأحوال.';

  @override
  String get handleHintName => 'name';

  @override
  String get handleALineAboutYou => 'سطر عنك · اختياري';

  @override
  String get handleClaiming => 'جارٍ الحجز…';

  @override
  String get handleClaimThisHandle => 'حجز اسم المستخدم هذا';

  @override
  String get handleAnyoneWithThisLink =>
      'يمكن لأي شخص لديه هذا الرابط أن يبدأ محادثة خاصة معك. يحمل الرابط دعوتك ولا شيء غيرها.';

  @override
  String get handleLinkCopied => 'نُسخ الرابط';

  @override
  String get handleDeleteThisHandle => 'حذف اسم المستخدم هذا';

  @override
  String handleDeleteTitle(Object handle) {
    return 'حذف ⁦@$handle⁩؟';
  }

  @override
  String get handleDeleteLine =>
      'ستزول صفحتك العامة ويمكن لأي شخص أن يحجز الاسم. تبقى محادثاتك الحالية كما هي.';

  @override
  String get handleDeleteYes => 'حذف اسم المستخدم';

  @override
  String get handleDeleting => 'جارٍ الحذف…';

  @override
  String get handleChecking => 'جارٍ التحقق…';

  @override
  String get handleAvailable => '✓ متاح';

  @override
  String get handleAlreadyTaken => 'محجوز بالفعل';

  @override
  String get handleNameRule =>
      'من ٣ إلى ٢٠ حرفًا: أحرف لاتينية صغيرة أو أرقام أو _';

  @override
  String get handleWhatAHandleDoes => 'ما فائدة اسم المستخدم';

  @override
  String get handleAnyoneWhoKnowsIt =>
      'يمكن لأي شخص يعرفه أن يطلب مراسلتك. تحمل الصفحة دعوتك والسطر الذي كتبته، لا شيء غير ذلك، ولا تحتفظ بأي سجل لمن يقرؤها. يمكنك حذفه متى شئت.';

  @override
  String handleIsNotYoursOn(Object handle) {
    return '⁦@$handle⁩ ليس لك على هذا الهاتف';
  }

  @override
  String handleIsNotYoursOnDesk(Object handle) {
    return '⁦@$handle⁩ ليس لك على هذا الحاسوب';
  }

  @override
  String handleTheRegistryHoldsIt(Object handle) {
    return 'يحتفظ به السجل تحت مفتاح مختلف، والأرجح أنه هوية كانت على هذا الهاتف قبل استعادة. من يضيف ⁦@$handle⁩ لا يصل إليك. لا يمكن تحريره أو تحديثه من هنا. اختر اسمًا آخر.';
  }

  @override
  String handleTheRegistryHoldsItDesk(Object handle) {
    return 'يحتفظ به السجل تحت مفتاح مختلف، والأرجح أنه هوية كانت على هذا الحاسوب قبل استعادة. من يضيف ⁦@$handle⁩ لا يصل إليك. لا يمكن تحريره أو تحديثه من هنا. اختر اسمًا آخر.';
  }

  @override
  String get handleForgetItOnThis => 'انسَه على هذا الهاتف';

  @override
  String get handleForgetItOnThisDesk => 'انسَه على هذا الحاسوب';

  @override
  String get homeAddAContact => 'إضافة جهة اتصال';

  @override
  String get commonSettings => 'الإعدادات';

  @override
  String get homeYourKryfo => 'Kryfo الخاص بك';

  @override
  String homeDateWeekday(Object weekday) {
    return '⁨$weekday⁩،';
  }

  @override
  String get homeAnHour => 'ساعة';

  @override
  String homeHours(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$countString⁩ ساعة',
      many: '⁨$countString⁩ ساعة',
      few: '⁨$countString⁩ ساعات',
      two: 'ساعتين',
      one: 'ساعة',
      zero: '⁨$countString⁩ ساعة',
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
      other: '⁨$countString⁩ دقيقة',
      many: '⁨$countString⁩ دقيقة',
      few: '⁨$countString⁩ دقائق',
      two: 'دقيقتين',
      one: 'دقيقة',
      zero: '⁨$countString⁩ دقيقة',
    );
    return '$_temp0';
  }

  @override
  String get homeKryfoIsOffline => 'Kryfo غير متصل';

  @override
  String homeTorHasNotBeen(Object howLong) {
    return 'لم يتمكن Tor من الاتصال منذ ⁨$howLong⁩. لا شيء يمكنه الوصول أو المغادرة حتى يتصل.';
  }

  @override
  String get homeReconnecting => 'جارٍ إعادة الاتصال';

  @override
  String get homeReconnect => 'إعادة الاتصال';

  @override
  String get homeWhatIsWrong => 'ما المشكلة';

  @override
  String get homeKryfoWillCheckIn => 'سيتفقّد Kryfo الرسائل كل ١٥ دقيقة';

  @override
  String get homeYourPhoneKeepsStopping => 'هاتفك يوقف Kryfo مرارًا';

  @override
  String get homeItHasClosedKryfo =>
      'أغلق Kryfo ثلاث مرات اليوم، فتأخرت الرسائل أو انتظرت. التفقّد الدوري يصمد أمام ذلك: يستيقظ Kryfo كل ١٥ دقيقة بدلًا من البقاء متصلًا.';

  @override
  String get homeSwitchToCheckIns => 'التبديل إلى التفقّد الدوري';

  @override
  String get homeNotNow => 'ليس الآن';

  @override
  String get homeNotificationsAreOff => 'الإشعارات معطّلة';

  @override
  String get homeAndroidIsBlockingThem =>
      'أندرويد يحجبها، فلا يصلك شيء ما دام Kryfo مغلقًا. ولا تزال الرسائل تصل عندما تفتحه.';

  @override
  String get homeCouldnTOpenIt =>
      'تعذّر فتحها. ابحث عن Kryfo في إعدادات الهاتف';

  @override
  String get homeTurnThemOn => 'تفعيلها';

  @override
  String get homeLeaveThemOff => 'إبقاؤها معطّلة';

  @override
  String get homeKeepWaiting => 'مواصلة الانتظار';

  @override
  String get homeOffline => 'غير متصل';

  @override
  String get homeWaiting => 'في الانتظار';

  @override
  String get homeNothingWaitingToSend => 'لا شيء ينتظر الإرسال';

  @override
  String homeWaitingSendsWhenYou(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$countString⁩ في الانتظار · تُرسل عند عودتك',
    );
    return '$_temp0';
  }

  @override
  String get homeNoKryfosYet => 'لا جهات اتصال بعد.';

  @override
  String get homeScanTheirCodeSend =>
      'اقرأ رمزه بالكاميرا، أو أرسل له رابطًا، أو اكتب اسم المستخدم الذي أعطاك إياه.';

  @override
  String get homeScanTheirCodeSendDesk =>
      'أرسل له رابطًا، أو اكتب اسم المستخدم الذي أعطاك إياه.';

  @override
  String get homeAddSomeone => 'إضافة شخص';

  @override
  String get homeArchived => 'الأرشيف';

  @override
  String home1Chat(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$countString⁩ محادثة',
      many: '⁨$countString⁩ محادثة',
      few: '⁨$countString⁩ محادثات',
      two: 'محادثتان',
      one: 'محادثة واحدة',
      zero: '⁨$countString⁩ محادثة',
    );
    return '$_temp0';
  }

  @override
  String get homeGroups => 'المجموعات';

  @override
  String get homeRoom => 'غرفة';

  @override
  String get homeNew => 'جديد';

  @override
  String homeRoomExpired(Object expiredRoomName) {
    return '⁨$expiredRoomName⁩ · انتهت الغرفة';
  }

  @override
  String get homeMentionedYou => 'ذكرك';

  @override
  String homeMembers(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$countString⁩ عضو',
      many: '⁨$countString⁩ عضوًا',
      few: '⁨$countString⁩ أعضاء',
      two: 'عضوان',
      one: 'عضو واحد',
      zero: '⁨$countString⁩ عضو',
    );
    return '$_temp0';
  }

  @override
  String get homeSupporter => 'داعم';

  @override
  String get homeUnmute => 'إلغاء الكتم';

  @override
  String get homeMute => 'كتم';

  @override
  String get homeArchive => 'أرشفة';

  @override
  String get homeDeleteChat => 'حذف المحادثة';

  @override
  String get homeMessagesAndContactGone =>
      'الرسائل وجهة الاتصال، تُحذف من هذا الهاتف';

  @override
  String get homeMessagesAndContactGoneDesk =>
      'الرسائل وجهة الاتصال، تُحذف من هذا الحاسوب';

  @override
  String get homeDeleteThisChat => 'حذف هذه المحادثة؟';

  @override
  String homeEveryMessageWithGoes(Object c) {
    return 'تُحذف كل رسالة مع ⁨$c⁩، ولا يعود جهة اتصال. هذا يُفرغ هذا الهاتف فقط. تبقى نسخته لديه. وإن راسلك مجددًا فستصل رسالته إلى الطلبات.';
  }

  @override
  String homeEveryMessageWithGoesDesk(Object c) {
    return 'تُحذف كل رسالة مع ⁨$c⁩، ولا يعود جهة اتصال. هذا يُفرغ هذا الحاسوب فقط. تبقى نسخته لديه. وإن راسلك مجددًا فستصل رسالته إلى الطلبات.';
  }

  @override
  String get homeQueued => 'في الانتظار';

  @override
  String get homeBlocked => 'محظور';

  @override
  String get homeRoomInvite => 'دعوة إلى غرفة';

  @override
  String get homeNow => 'الآن';

  @override
  String homeM(Object inMinutes) {
    return '⁨$inMinutes⁩ د';
  }

  @override
  String homeH(Object inHours) {
    return '⁨$inHours⁩ س';
  }

  @override
  String get homeYesterday => 'أمس';

  @override
  String homeD(Object inDays) {
    return '⁨$inDays⁩ ي';
  }

  @override
  String get homeNoteToSelf => 'ملاحظة لنفسي';

  @override
  String get homeOnlyOnThisPhone => 'على هذا الهاتف فقط';

  @override
  String get homeOnlyOnThisPhoneDesk => 'على هذا الحاسوب فقط';

  @override
  String get homeSaved => 'المحفوظات';

  @override
  String get homeKeptFromEveryChat => 'محفوظة من كل المحادثات';

  @override
  String get homeRequests => 'الطلبات';

  @override
  String home1PersonWantsTo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$countString⁩ شخص يريدون التواصل معك',
      many: '⁨$countString⁩ شخصًا يريدون التواصل معك',
      few: '⁨$countString⁩ أشخاص يريدون التواصل معك',
      two: 'شخصان يريدان التواصل معك',
      one: 'شخص واحد يريد التواصل معك',
      zero: 'لا أحد يريد التواصل معك',
    );
    return '$_temp0';
  }

  @override
  String introduceGotItButCould(Object b, Object c) {
    return 'وصل التعريف إلى ⁨$b⁩، لكن تعذّر الوصول إلى ⁨$c⁩';
  }

  @override
  String introduceGotItButCouldNotBe(Object c, Object b) {
    return 'وصل التعريف إلى ⁨$c⁩، لكن تعذّر الوصول إلى ⁨$b⁩';
  }

  @override
  String introduceIntroduced(Object b, Object c) {
    return 'حصل كلٌّ من ⁨$b⁩ و⁨$c⁩ على بطاقة الآخر';
  }

  @override
  String get introduceCouldNotReachEither =>
      'تعذّر الوصول إلى أيٍّ منهما. أعد المحاولة لاحقًا';

  @override
  String introduceIntroduceTo(Object peerName) {
    return 'تعريف ⁨$peerName⁩ على...';
  }

  @override
  String get introduceBothOfThemGet =>
      'يحصل كلٌّ منهما على بطاقة الآخر. ولا يرى أيٌّ منهما الاسم الذي تسمّي به الآخر.';

  @override
  String get introduceNoOneElseTo =>
      'لا أحد آخر للتعريف به بعد. أضف جهة اتصال أخرى أولًا.';

  @override
  String get introduceANoteLikeMy => 'ملاحظة، مثل «ابن عمي» (اختيارية)';

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
      other: 'بقي ⁨$leftString⁩ من ⁨$maxString⁩ تعريف هذا الأسبوع',
      many: 'بقي ⁨$leftString⁩ من ⁨$maxString⁩ تعريفًا هذا الأسبوع',
      few: 'بقي ⁨$leftString⁩ من ⁨$maxString⁩ تعريفات هذا الأسبوع',
      two: 'بقي ⁨$leftString⁩ من تعريفين هذا الأسبوع',
      one: 'بقي ⁨$leftString⁩ من تعريف واحد هذا الأسبوع',
      zero: 'بقي ⁨$leftString⁩ من ⁨$maxString⁩ تعريف هذا الأسبوع',
    );
    return '$_temp0';
  }

  @override
  String introduceNoIntroductionsLeftNext(Object refillPhrase) {
    return 'لم تبقَ تعريفات. يتاح التالي ⁨$refillPhrase⁩';
  }

  @override
  String get introduceIntroduce => 'تعريف';

  @override
  String get keyVerificationSafetyNumber => 'رقم الأمان';

  @override
  String get keyVerificationNewNumber =>
      'تغيّر رمز الأمان بينما كانت هذه الصفحة مفتوحة. هذا هو الرقم الجديد، قارنه مرة أخرى.';

  @override
  String get keyVerificationKeyMoved =>
      'تغيّر رمز الأمان للتو. قارن الرقم الجديد.';

  @override
  String keyVerificationNoKeyYet(Object peerName) {
    return 'لا يوجد مفتاح من ⁨$peerName⁩ بعد. يظهر الرقم هنا حين يراسلك.';
  }

  @override
  String keyVerificationWith(Object peerName) {
    return 'مع ⁨$peerName⁩';
  }

  @override
  String keyVerificationCompareAll(Object peerName) {
    return 'قارن المجموعات الاثنتي عشرة كلها مع ⁨$peerName⁩، وجهًا لوجه أو عبر مكالمة تثق بها. إن تطابقت كل مجموعة، فلا أحد بينكما ورسائلكما لكما وحدكما.';
  }

  @override
  String get keyVerificationVerified => 'تم التحقق';

  @override
  String get keyVerificationMarkAsVerified => 'وضع علامة التحقق';

  @override
  String get lockFileThatPasswordDoesNot => 'كلمة المرور هذه لا تفتحه.';

  @override
  String get lockFileThisFileIsDamaged => 'هذا الملف تالف.';

  @override
  String get lockFileThisFileWasLocked =>
      'قُفل هذا الملف بمفتاح، لا بكلمة مرور.';

  @override
  String get lockFileThisIsNotA => 'هذا ليس ملفًا مقفلًا.';

  @override
  String get lockFileNotEnoughFreeMemory => 'لا توجد ذاكرة فارغة كافية الآن.';

  @override
  String get lockFileStopped => 'توقف.';

  @override
  String get lockFileItNeedsAPassword => 'يحتاج إلى كلمة مرور.';

  @override
  String get lockFileKryfoCouldNotRead =>
      'لم يستطع Kryfo قراءة الملف أو الكتابة فيه.';

  @override
  String get lockFileCheckCapitalsAndSpaces =>
      'تحقّق من الأحرف الكبيرة والمسافات. لا أحد يستطيع إعادة تعيينها.';

  @override
  String get lockFileItMayHaveBeen =>
      'ربما انقطع في الطريق. اطلب إرساله مجددًا. لم يُحفظ شيء.';

  @override
  String get lockFileItOpensWithThe =>
      'يُفتح بملف مفتاح الشخص الذي صُنع له، بأداة age على حاسوب. أما Kryfo فيفتح النوع المحمي بكلمة مرور.';

  @override
  String get lockFileKryfoOpensFilesLocked =>
      'يفتح Kryfo الملفات المقفلة بـ age، وعادةً ما تنتهي أسماؤها بـ ‎.age';

  @override
  String get lockFileCloseAFewApps =>
      'أغلق بعض التطبيقات ثم أعد المحاولة. يحتاج فحص كلمة المرور إلى بضع مئات من الميغابايتات للحظة.';

  @override
  String get lockFileNothingWasSaved => 'لم يُحفظ شيء.';

  @override
  String get lockFileTypeOneOrLet =>
      'اكتب واحدة، أو دع Kryfo يقترح أربع كلمات.';

  @override
  String get lockFileTheAppThatHolds =>
      'ربما استعاده التطبيق الذي يحتفظ به. اختره مجددًا.';

  @override
  String get lockFileHidePassword => 'إخفاء كلمة المرور';

  @override
  String get lockFileShowPassword => 'إظهار كلمة المرور';

  @override
  String get lockFileChangeFile => 'تغيير الملف';

  @override
  String get lockFileChange => 'تغيير';

  @override
  String lockFileOf(Object prettySize, Object prettySize2) {
    return '⁨$prettySize⁩ من ⁨$prettySize2⁩';
  }

  @override
  String get lockFileEverythingStaysOnThis => 'يبقى كل شيء على هذا الهاتف.';

  @override
  String get lockFileCouldNotMakeOne => 'تعذّر إنشاء واحدة. اكتب واحدة بنفسك.';

  @override
  String get lockFileWriteItDownBefore => 'دوّنها قبل أن تقفل الملف';

  @override
  String get lockFileNoAppOnThis => 'لم يستلم أي تطبيق على هذا الهاتف الملف.';

  @override
  String get linkNoAppOpens => 'لا يوجد تطبيق على هذا الهاتف يفتح هذا الرابط.';

  @override
  String get linkNoAppOpensDesk =>
      'لا يوجد تطبيق على هذا الحاسوب يفتح هذا الرابط.';

  @override
  String get placeStubLocation => 'الموقع';

  @override
  String get lockFileSaved => 'حُفظ';

  @override
  String get lockFileCouldNotSaveIt => 'تعذّر حفظه هناك. جرّب مجلدًا آخر.';

  @override
  String get lockFileLocked => 'مقفل';

  @override
  String get lockFileLockAFile => 'قفل ملف';

  @override
  String get lockFileMixingThePassword => 'جارٍ خلط كلمة المرور';

  @override
  String get lockFileLocking => 'جارٍ القفل';

  @override
  String get lockFileSaveToFiles => 'حفظ في الملفات';

  @override
  String get lockFileLockFile => 'قفل الملف';

  @override
  String get lockFileOnePassword => 'كلمة مرور واحدة.';

  @override
  String get lockFileNothingElseOpensIt => 'لا شيء غيرها يفتحه.';

  @override
  String get lockFileFile => 'الملف';

  @override
  String lockFileFromFiles(Object prettySize) {
    return '⁨$prettySize⁩ · من الملفات';
  }

  @override
  String get lockFileFromFiles2 => 'من الملفات';

  @override
  String get lockFilePassword => 'كلمة المرور';

  @override
  String get lockFileSuggestFourWords => 'اقتراح أربع كلمات';

  @override
  String get lockFileTypeItAgain => 'اكتبها مجددًا';

  @override
  String get lockFileTheTwoDoNot => 'الاثنتان غير متطابقتين بعد.';

  @override
  String get lockFileHideTheFileName => 'إخفاء اسم الملف';

  @override
  String lockFileItWillBeCalled(Object name) {
    return 'سيكون اسمه «⁨$name⁩». أخبر المستلم بنوع الملف.';
  }

  @override
  String get lockFileTheNameAloneCan => 'قد يكشف الاسم وحده ما في داخله.';

  @override
  String get lockFileAnyoneWithThePassword =>
      'يمكن لأي شخص يملك كلمة المرور فتحه، في Kryfo أو على أي حاسوب بأداة age المجانية. إن نسيتها ضاع الملف إلى الأبد. لا أحد يستطيع إعادة تعيينها.';

  @override
  String get lockFileLocked2 => 'قُفل.';

  @override
  String get lockFileOnlyThePasswordOpens => 'لا تفتحه إلا كلمة المرور.';

  @override
  String lockFileSafeToEmailOr(Object prettySize) {
    return '⁨$prettySize⁩ · آمن لإرساله بالبريد أو وضعه على ذاكرة USB';
  }

  @override
  String get lockFileNoKryfoOnThe =>
      'لا يوجد Kryfo لدى الطرف الآخر؟ على حاسوب:';

  @override
  String get lockFileItAsksForThe =>
      'ستطلب كلمة المرور. أداة age مجانية على age-encryption.org';

  @override
  String lockTooManyTriesS(Object lockState) {
    return 'محاولات كثيرة جدًا · ⁨$lockState⁩ ث';
  }

  @override
  String get lockNotIt => 'غير صحيح';

  @override
  String get lockYourPin => 'رمز PIN';

  @override
  String get lockUseFingerprint => 'استخدام البصمة';

  @override
  String get lockSetupUnlockWithFingerprint => 'فتح القفل بالبصمة؟';

  @override
  String get lockSetupThePinStillWorks =>
      'يبقى رمز PIN صالحًا متى أردته. هذا أسرع فقط.';

  @override
  String get lockSetupUseFingerprint => 'استخدام البصمة';

  @override
  String get lockSetupTurningOn => 'جارٍ التفعيل…';

  @override
  String get lockSetupPinOnly => 'رمز PIN فقط';

  @override
  String get lockSetupOnceMore => 'مرة أخرى';

  @override
  String get lockSetupSetAPin => 'تعيين رمز PIN';

  @override
  String get lockSetupThoseWereDifferentFrom => 'لم يتطابقا. من البداية.';

  @override
  String get lockSetupTheSameFourDigits => 'الأرقام نفسها مرة أخرى';

  @override
  String get lockSetupFourDigitsAnythingYou =>
      'أربعة أرقام أو أكثر، أي شيء ستتذكره';

  @override
  String get modesFast => 'سريع';

  @override
  String get modesNotChanged => 'لم يتغيّر الوضع. حاول مجددًا.';

  @override
  String get modesSwitching => 'جارٍ التبديل…';

  @override
  String get modesSpeed => 'السرعة';

  @override
  String get modesPrivacy => 'والخصوصية';

  @override
  String get movedWipeThisPhone => 'مسح Kryfo من هذا الهاتف؟';

  @override
  String get movedWipeThisPhoneDesk => 'مسح Kryfo من هذا الحاسوب؟';

  @override
  String get movedEverythingKryfoHoldsHere =>
      'يزول كل ما يحمله Kryfo هنا: الرسائل، وجهات الاتصال، والمفاتيح. ويحتفظ الجهاز الآخر بكل ذلك. لا يمكن التراجع عن هذا.';

  @override
  String get movedWipeIt => 'امسحه';

  @override
  String get movedNotMovingAfterAll => 'عدلت عن الانتقال؟';

  @override
  String get movedOnlyDoThisIf =>
      'لا تفعل هذا إلا إن لم تُستورد النسخة الاحتياطية في أي مكان قط. وإن استُوردت، فهناك الآن جهازان يحملان هوية واحدة، وستبدأ الرسائل بالضياع على كليهما.';

  @override
  String get movedIMStayingHere => 'سأبقى هنا';

  @override
  String get movedStayingHere => 'البقاء هنا';

  @override
  String movedKryfoWillCloseNow(Object myId) {
    return 'سيُغلق Kryfo الآن. اضغط الأيقونة لإعادة فتحه باسم ⁨$myId⁩.';
  }

  @override
  String movedKryfoWillCloseNowDesk(Object myId) {
    return 'سيُغلق Kryfo الآن. شغّله مرة أخرى لفتحه باسم ⁨$myId⁩.';
  }

  @override
  String get movedReopenKryfo => 'إعادة فتح Kryfo';

  @override
  String get movedThisKryfoHasMoved => 'انتقل Kryfo هذا';

  @override
  String movedIsNowOnAnother(Object myId) {
    return 'أصبح ⁨$myId⁩ على جهاز آخر. ما زال بإمكان هذا الهاتف عرض ما كان هنا، لكن لن يصل إليه شيء جديد، وما ترسله من هنا لن يصل إلى أحد.';
  }

  @override
  String movedIsNowOnAnotherDesk(Object myId) {
    return 'أصبح ⁨$myId⁩ على جهاز آخر. ما زال بإمكان هذا الحاسوب عرض ما كان هنا، لكن لن يصل إليه شيء جديد، وما ترسله من هنا لن يصل إلى أحد.';
  }

  @override
  String get movedKeepItToRead => 'الإبقاء عليه للقراءة';

  @override
  String get movedWipeThisPhone2 => 'مسح Kryfo من هذا الهاتف';

  @override
  String get movedWipeThisPhone2Desk => 'مسح Kryfo من هذا الحاسوب';

  @override
  String get movedIMNotMoving => 'عدلت عن الانتقال';

  @override
  String get myKryfoAHandleIs3 =>
      'اسم المستخدم من ٣ إلى ٢٠ حرفًا أو رقمًا أو _';

  @override
  String get myKryfoInviteCopiedClearsIn =>
      'نُسخت الدعوة · تُزال من الحافظة بعد ٦٠ ث';

  @override
  String get myKryfoAddMeOnKryfo2 => 'أضفني على Kryfo';

  @override
  String get myKryfoAddSomeone => 'إضافة شخص';

  @override
  String get myKryfoKryfoDoesnTScan =>
      'لا يفحص Kryfo جهات اتصالك، وهذا هو المقصود.';

  @override
  String get myKryfoIfThisLinkEnds =>
      'إن وصل هذا الرابط إلى مكان لم تقصده، فأعد تعيينه من الإعدادات. وعندها سيحتاج كل من لديه إلى رابط جديد.';

  @override
  String get myKryfoAlreadyShareAFriend =>
      'لديكما صديق مشترك على Kryfo؟ يمكنه أن يعرّفكما على بعضكما من محادثته، فتتخطيان الطلب.';

  @override
  String get myKryfoHandleCopied => 'نُسخ اسم المستخدم';

  @override
  String get myKryfoTheyReHereWith => 'معي هنا';

  @override
  String get myKryfoPointYourPhonesAt =>
      'وجّه الهاتفين أحدهما نحو الآخر. لا يمر شيء عبر أي خادم.';

  @override
  String get myKryfoPointYourPhonesAtDesk =>
      'يمسح الطرف الآخر هذا الرمز بهاتفه. لا يمر شيء عبر أي خادم.';

  @override
  String get myKryfoScanTheirsInstead => 'اقرأ رمزه بدلًا من ذلك';

  @override
  String get myKryfoTheyReadYouA => 'يقرأ عليك رمزًا';

  @override
  String get myKryfoTheyReSomewhereElse => 'في مكان آخر';

  @override
  String get myKryfoSendThemALink =>
      'أرسل له رابطًا. يفتح مباشرة على شاشة الإضافة.';

  @override
  String get myKryfoYourLinkAppearsOnce => 'يظهر رابطك بمجرد اتصالك';

  @override
  String get myKryfoTheLinkCarriesYour =>
      'يحمل الرابط كلماتك الثلاث وعنوانك والمفاتيح اللازمة لبدء محادثة. يبقى صالحًا حتى تعيد تعيينه من الإعدادات.';

  @override
  String get myKryfoSendTheLink => 'إرسال الرابط';

  @override
  String get myKryfoAsACard => 'كبطاقة';

  @override
  String get myKryfoAnImageWithThe => 'صورة فيها رمز QR';

  @override
  String get myKryfoAsAFile => 'كملف';

  @override
  String get myKryfoContactFile => 'ملف جهة اتصال';

  @override
  String get myKryfoIKnowTheirHandle => 'أعرف اسم مستخدمه';

  @override
  String get myKryfoTypeTheNameThey =>
      'اكتب @الاسم الذي أعطاك إياه. يعمل إن كان قد حجز اسمًا.';

  @override
  String get myKryfoTheLookupAsksFor =>
      'يرسل البحث ذلك الاسم وحده ولا شيء عنك. وتصله رسالتك الأولى كطلب.';

  @override
  String get myKryfoLooking => 'جارٍ البحث…';

  @override
  String get myKryfoFindThem => 'البحث عنه';

  @override
  String get myKryfoYourAddressAppearsOnce => 'يظهر عنوانك بمجرد اتصالك';

  @override
  String get myKryfoAPublicHandle => 'اسم مستخدم عام';

  @override
  String get myKryfoPutItInA =>
      'ضعه في نبذتك التعريفية. يمكن لأي شخص يعرفه أن يجدك.';

  @override
  String get myKryfoANamePeopleCan =>
      'اسم يمكن للناس أن يجدوك به. معطّل حتى تحجز واحدًا.';

  @override
  String get newGroupCouldNotCreate => 'تعذّر الإنشاء';

  @override
  String get newGroupNewGroup => 'مجموعة جديدة';

  @override
  String get newGroupCreating => 'جارٍ الإنشاء…';

  @override
  String get newGroupCreate => 'إنشاء';

  @override
  String get newGroupGroupName => 'اسم المجموعة';

  @override
  String get newGroupMembers => 'الأعضاء';

  @override
  String get newGroupPickAtLeastOne => 'اختر واحدًا على الأقل';

  @override
  String newGroupSelected(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم تحديد ⁨$countString⁩',
    );
    return '$_temp0';
  }

  @override
  String get newGroupAddAtLeastOne =>
      'أضف جهة اتصال واحدة على الأقل قبل إنشاء مجموعة.';

  @override
  String get newGroupNeedsContacts => 'تُنشأ المجموعات مع جهات اتصالك';

  @override
  String get newGroupAddSomeoneFirst =>
      'أضف شخصًا أولًا. لا تحتاج الغرفة إلى جهات اتصال: يمكن لأي شخص لديه رابطها الانضمام.';

  @override
  String get notesDeleteThisNote => 'حذف هذه الملاحظة؟';

  @override
  String get notesHoldHint => 'اضغط مطولًا على ملاحظة لنسخها أو حذفها.';

  @override
  String get notesMenu => 'قائمة الملاحظات';

  @override
  String get notesDeleteAll => 'حذف كل الملاحظات';

  @override
  String get notesDeleteAllTitle => 'أتحذف كل الملاحظات؟';

  @override
  String get notesDeleteAllLine => 'تُحذف كل الملاحظات على هذا الهاتف نهائيًا.';

  @override
  String get notesDeleteAllLineDesk =>
      'تُحذف كل الملاحظات على هذا الحاسوب نهائيًا.';

  @override
  String get notesDeleteAllYes => 'حذف الكل';

  @override
  String get notesThisWeek => 'هذا الأسبوع';

  @override
  String get notesShowMore => 'عرض المزيد';

  @override
  String get notesShowLess => 'عرض أقل';

  @override
  String get notesGoneFromThisPhone => 'ستُمحى من هذا الهاتف نهائيًا.';

  @override
  String get notesGoneFromThisPhoneDesk => 'ستُمحى من هذا الحاسوب نهائيًا.';

  @override
  String get notesNoteToSelf => 'ملاحظة لنفسي';

  @override
  String get notesOnlyOnThisPhone => 'على هذا الهاتف فقط';

  @override
  String get notesOnlyOnThisPhoneDesk => 'على هذا الحاسوب فقط';

  @override
  String get notesAQuietPlace => 'مكان هادئ';

  @override
  String get notesJotAnythingDownIt =>
      'دوّن أي شيء. يبقى على هذا الهاتف ولا يغادره أبدًا.';

  @override
  String get notesJotAnythingDownItDesk =>
      'دوّن أي شيء. يبقى على هذا الحاسوب ولا يغادره أبدًا.';

  @override
  String get notesJotSomethingDown => 'دوّن شيئًا…';

  @override
  String get notesExportNotes => 'تصدير الملاحظات';

  @override
  String get notesExport => 'تصدير';

  @override
  String get notesExportWorking => 'جارٍ التصدير…';

  @override
  String notesExportCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$countString⁩ ملاحظة، الأقدم أولًا.',
      many: '⁨$countString⁩ ملاحظة، الأقدم أولًا.',
      few: '⁨$countString⁩ ملاحظات، الأقدم أولًا.',
      two: 'ملاحظتان، الأقدم أولًا.',
      one: 'ملاحظة واحدة، الأقدم أولًا.',
      zero: 'لا ملاحظات.',
    );
    return '$_temp0';
  }

  @override
  String get notesExportZip => 'الصور والرسائل الصوتية تذهب معها في ملف zip.';

  @override
  String get notesExportText => 'نص عادي';

  @override
  String get notesExportTextLine => 'ملف ‎.txt يُفتح في أي مكان';

  @override
  String get notesExportMarkdown => 'Markdown';

  @override
  String get notesExportMarkdownLine => 'ملف ‎.md بعناوين، لتطبيقات الملاحظات';

  @override
  String get notesExportLock => 'القفل بعبارة مرور';

  @override
  String get notesExportLockLine =>
      'افتحه من الأدوات عبر «فتح ملف مقفل»، أو بأداة age على حاسوب';

  @override
  String get notesExportPlainTitle => 'التصدير بلا عبارة مرور؟';

  @override
  String get notesExportPlainLine => 'أي شخص يحصل على هذا الملف يستطيع قراءته.';

  @override
  String get notesExportPlainYes => 'التصدير بدونها';

  @override
  String get notesExportKeepLock => 'إبقاء عبارة المرور';

  @override
  String get notesExportNotSaved => 'لم تُحفظ الملاحظات. الملف ما زال هنا.';

  @override
  String get notesExportGone =>
      'مُسح الملف حين قُفل Kryfo. صدّر مرة أخرى لإنشاء ملف جديد.';

  @override
  String get notesExportHoldsInstaller =>
      'يحتوي هذا التصدير على ملف لتثبيت تطبيق، لذا لا يمكن مشاركته. احفظه على هاتفك بدلًا من ذلك.';

  @override
  String get notesExportHoldsInstallerDesk =>
      'يحتوي هذا التصدير على ملف لتثبيت تطبيق، لذا لا يمكن مشاركته. احفظه على هذا الحاسوب بدلًا من ذلك.';

  @override
  String get notesExportSaved => 'حُفظت الملاحظات';

  @override
  String notesExportSavedIn(String place) {
    return 'حُفظت الملاحظات في ⁨$place⁩';
  }

  @override
  String get notesExportSavedUnchecked =>
      'حُفظت الملاحظات، لكن Kryfo لم يتمكن من التحقق من النسخة';

  @override
  String get notesExportFailed => 'تعذّر تصدير الملاحظات. لم يُحفظ شيء.';

  @override
  String get notesExportTooLarge =>
      'أكبر من أن يُصدَّر. الصور والرسائل الصوتية تبلغ ٤ غ.ب أو أكثر.';

  @override
  String get notesExportSubject => 'ملاحظات Kryfo';

  @override
  String get onboardingPrivateByDefault => 'خاص افتراضيًا';

  @override
  String get onboardingPrivateMessaging => 'مراسلة خاصة،\n*بلا ثمن خفي*.';

  @override
  String get onboardingYourNameIsThree =>
      '*اسمك ثلاث كلمات.* بلا هاتف، ولا بريد إلكتروني، ولا دفتر عناوين.';

  @override
  String get onboardingNobodyGetsInUnless =>
      '*لا يدخل أحد إلا إن سمحت له.* لن يجدك أحد ما لم تحجز اسم مستخدم عامًا. يُضاف الناس يدويًا، من الطرفين.';

  @override
  String get onboardingTheFirstConnectionTakes =>
      '*الاتصال الأول يستغرق دقيقة.* يبني Kryfo مسارًا خاصًا قبل أن يرسل. ثم يصبح سريعًا.';

  @override
  String get onboardingBegin => 'ابدأ';

  @override
  String get onboardingHaveABackupRestore => 'لديك نسخة احتياطية؟ استعدها ←';

  @override
  String get onboardingKryfoIsOpenSource => 'Kryfo مفتوح المصدر';

  @override
  String get onboardingYourKryfoId => 'اسمك';

  @override
  String get onboardingGeneratedFromAKey =>
      'مولَّد من مفتاح لا يوجد إلا على هذا الهاتف. *لا أحد غيرك يملك هذه الكلمات.*';

  @override
  String get onboardingGeneratedFromAKeyDesk =>
      'مولَّد من مفتاح لا يوجد إلا على هذا الحاسوب. *لا أحد غيرك يملك هذه الكلمات.*';

  @override
  String get onboardingTryAnother => 'جرّب غيره';

  @override
  String get onboardingUseThisName => 'استخدم هذا الاسم ←';

  @override
  String get onboardingThreeWords => 'ثلاث كلمات. *لك وحدك.*';

  @override
  String get onboardingContinue => 'متابعة ←';

  @override
  String get onboardingKryfoBuildsAPrivateRouteBefore =>
      'يبني Kryfo مسارًا خاصًا قبل أن يرسل أي شيء. وحين تكون غير متصل، تنتظر الرسائل وتصل عند عودتك.';

  @override
  String get onboardingYourIdentityLivesOn =>
      'هويتك موجودة على هذا الهاتف. انسخها احتياطيًا من الإعدادات حين تكون مستعدًا.';

  @override
  String get onboardingYourIdentityLivesOnDesk =>
      'هويتك موجودة على هذا الحاسوب. انسخها احتياطيًا من الإعدادات حين تكون مستعدًا.';

  @override
  String get onboardingOneQuiet => '*إشعار* واحد هادئ.';

  @override
  String get onboardingAndroidNeedsAVisible =>
      'يحتاج أندرويد إلى إشعار ظاهر ما دام تطبيق ما يستمع في الخلفية. بهذا تصلك الرسائل حين يكون Kryfo مغلقًا.';

  @override
  String get onboardingSilentAndAtThe => 'صامت، وفي أسفل لوحة الإشعارات';

  @override
  String get onboardingItNeverBuzzesTurn =>
      'لا يهتز أبدًا. إن أوقفته، تنتظر الرسائل حتى تفتح التطبيق مجددًا.';

  @override
  String get onboardingGotIt => 'حسنًا ←';

  @override
  String get onboardingEveryWayToAdd => 'كل طرق إضافة شخص';

  @override
  String get onboardingShowYourCodeSend =>
      'اعرض رمزك، أو أرسل له رابطًا، أو اكتب اسم المستخدم الذي أعطاك إياه.';

  @override
  String get onboardingScanTheirs => 'اقرأ رمزه';

  @override
  String get onboardingPointTheCameraAt => 'وجّه الكاميرا نحو رمزه';

  @override
  String get onboardingNotNowAddPeople => 'ليس الآن · أضف الناس لاحقًا';

  @override
  String get openLockedOpened => 'فُتح';

  @override
  String get openLockedOpenALockedFile => 'فتح ملف مقفل';

  @override
  String get openLockedCheckingThePassword => 'جارٍ التحقق من كلمة المرور';

  @override
  String get openLockedOpening => 'جارٍ الفتح';

  @override
  String get openLockedFile => 'الملف';

  @override
  String get openLockedOpenFile => 'فتح الملف';

  @override
  String get openLockedTypeThePassword => 'اكتب كلمة المرور.';

  @override
  String get openLockedItOpensOnThis => 'يُفتح على هذا الهاتف.';

  @override
  String get openLockedLockedFile => 'ملف مقفل';

  @override
  String openLockedFromFiles(Object prettySize) {
    return '⁨$prettySize⁩ · من الملفات';
  }

  @override
  String get openLockedFromFiles2 => 'من الملفات';

  @override
  String get openLockedPassword => 'كلمة المرور';

  @override
  String get openLockedThePasswordIsChecked =>
      'يُتحقق من كلمة المرور أولًا. وبعدها فقط يسأل Kryfo أين يضع الملف المفتوح، فيذهب إلى هناك مباشرة.';

  @override
  String get openLockedOpened2 => 'فُتح.';

  @override
  String get openLockedSavedWhereYouChose => 'حُفظ حيث اخترت.';

  @override
  String get pairCodePairingCode => 'رمز الاقتران';

  @override
  String get pairCodeShowACode => 'عرض رمز';

  @override
  String get pairCodeEnterOne => 'إدخال رمز';

  @override
  String get pairCodeLooking => 'جارٍ البحث…';

  @override
  String get pairCodeNothingThereYetTrying =>
      'لا شيء بعد · جارٍ إعادة المحاولة';

  @override
  String get pairCodeNothingAtThatCode =>
      'لا شيء عند هذا الرمز. ربما اختفى، أو لم يشاركه بعد.';

  @override
  String get pairCodeUnreached =>
      'تعذّر الوصول إلى المُرحِّلات. حاول مجددًا بعد قليل.';

  @override
  String get fastRoomsWaitForTor =>
      'تمر الغرف ورموز الاقتران وأول تواصل مع شخص جديد دائمًا عبر Tor، حتى على الوضع السريع. تعمل فور اتصال Tor.';

  @override
  String get pairCodeFailed => 'لم ينجح ذلك. حاول مجددًا.';

  @override
  String get pairCodeAddThem => 'أضِفه';

  @override
  String get pairCodeKeyNumber => 'رقم المفتاح';

  @override
  String get pairCodeNotAdded => 'لم تتم الإضافة. اطلب رمزًا جديدًا.';

  @override
  String get pairCodeEightDigits => 'ثمانية أرقام';

  @override
  String get pairCodeTypeTheEightDigits =>
      'اكتب الأرقام الثمانية التي قرأها عليك.';

  @override
  String get pairCodeOldCode =>
      'هذا الرمز من إصدار أقدم من Kryfo. يحتاج الهاتفان إلى Kryfo 0.6 أو أحدث.';

  @override
  String get pairCodeOldCodeDesk =>
      'هذا الرمز من إصدار أقدم من Kryfo. يحتاج الجهازان إلى Kryfo 0.6 أو أحدث.';

  @override
  String get pairCodeBothNeed06 => 'يحتاج الهاتفان إلى Kryfo 0.6 أو أحدث.';

  @override
  String get pairCodeBothNeed06Desk => 'يحتاج الجهازان إلى Kryfo 0.6 أو أحدث.';

  @override
  String get pairCodeWaitingForThem => 'بانتظار الطرف الآخر…';

  @override
  String get pairCodeStillWaiting =>
      'ما زلنا ننتظر. إذا ظهر على شاشته أن رمزًا خاطئًا كُتب، فراجعا الأرقام معًا.';

  @override
  String get pairCodeUnanswered =>
      'لم يصل أي رد. راجع الرمز معه واكتبه مرة أخرى.';

  @override
  String get pairCodeTooManyTries =>
      'جُرّب هذا الرمز ثلاث مرات. اطلب رمزًا جديدًا.';

  @override
  String get pairCodeRanOut => 'انتهت مدة هذا الرمز. اطلب رمزًا جديدًا.';

  @override
  String get pairCodeMatched => 'تطابق الرمز. هل تضيفان بعضكما؟';

  @override
  String get pairCodeNotThem => 'ليس هو';

  @override
  String get pairCodePanelReadEightDigitsOut =>
      'اقرأ ثمانية أرقام بصوت عالٍ فيضيف كلٌّ منكما الآخر. لا حاجة إلى تبادل أي شيء آخر.';

  @override
  String get pairCodePanelOrMakeACode => 'أو أنشئ رمزًا لتقرأه';

  @override
  String get pairCodePanelTheyOpenKryfoEight =>
      'يفتح Kryfo، ويضغط «إضافة»، ويختار «رمز الاقتران» ثم يكتب هذه الأرقام الثمانية. أنشئ رمزًا جديدًا للشخص التالي.';

  @override
  String get pairCodePanelWrongTyped => 'كُتب رمز خاطئ. اقرأه مرة أخرى ببطء.';

  @override
  String get pairCodePanelThreeWrong =>
      'كُتب رمز خاطئ ثلاث مرات، فتوقف هذا الرمز. أنشئ رمزًا جديدًا.';

  @override
  String get pairCodePanelNotAdded =>
      'لم تتم الإضافة. أنشئ رمزًا جديدًا عندما يكون الطرف الآخر جاهزًا.';

  @override
  String get panicSetupThoseWereDifferentFrom => 'لم يتطابقا. من البداية.';

  @override
  String get panicSetupOnceMore => 'مرة أخرى';

  @override
  String get panicSetupTheSameFourDigits => 'الأرقام نفسها مرة أخرى';

  @override
  String get photoKnowsEverythingInside => 'كل ما في داخله';

  @override
  String get photoKnowsVideo => 'فيديو';

  @override
  String get photoKnowsPhoto => 'صورة';

  @override
  String get photoKnowsVideoCleaner => 'منظّف الفيديو';

  @override
  String get photoKnowsPhotoCleaner => 'منظّف الصور';

  @override
  String get photoKnowsRemoveAllOfIt => 'إزالة كل ذلك';

  @override
  String get photoKnowsKeepItAsIt => 'إبقاؤه كما هو';

  @override
  String get photoKnowsReadOnThisPhone =>
      'قُرئ على هذا الهاتف · لم يذهب الفيديو إلى أي مكان';

  @override
  String get photoKnowsReadOnThisPhoneThePhoto =>
      'قُرئت على هذا الهاتف · لم تذهب الصورة إلى أي مكان';

  @override
  String get photoKnowsReadingTheFile => 'جارٍ قراءة الملف';

  @override
  String photoKnowsOf(Object prettySize, Object prettySize2) {
    return '⁨$prettySize⁩ من ⁨$prettySize2⁩';
  }

  @override
  String get photoKnowsEverythingStaysOnThis => 'يبقى كل شيء على هذا الهاتف.';

  @override
  String photoKnowsMapWithAPin(Object place) {
    return 'خريطة عليها دبوس. ⁨$place⁩';
  }

  @override
  String get photoKnowsDrawnOffline => 'مرسومة دون اتصال';

  @override
  String photoKnowsShowEverything(Object title) {
    return '⁨$title⁩. عرض كل شيء';
  }

  @override
  String get pinsAppLock => 'قفل التطبيق';

  @override
  String get pinsYourPin => 'رمز PIN';

  @override
  String get commonOn => 'مفعّل';

  @override
  String get commonOff => 'معطّل';

  @override
  String get pinsOpensKryfoFourDigits =>
      'يفتح Kryfo. يُطلب حين يعود التطبيق إلى الواجهة.';

  @override
  String get pinsChangePin => 'تغيير رمز PIN';

  @override
  String get pinsSetAPin => 'تعيين رمز PIN';

  @override
  String get pinsTurnOff => 'إيقاف';

  @override
  String get pinsTurnOffTheApp => 'إيقاف قفل التطبيق؟';

  @override
  String get pinsThePinGoesAnd =>
      'يُزال رمز PIN، ومعه رمز PIN للمسح وأي محادثات مخفية. وكل من يمسك هاتفك يفتح Kryfo باسمك.';

  @override
  String get pinsThePinGoesAndDesk =>
      'يُزال رمز PIN، ومعه رمز PIN للمسح وأي محادثات مخفية. وكل من يجلس إلى حاسوبك يفتح Kryfo باسمك.';

  @override
  String get pinsUnlockWithFingerprint => 'فتح القفل بالبصمة';

  @override
  String get pinsFingerOpensDecoy =>
      'متوقف ما دام رمز PIN للتمويه مضبوطًا: الإصبع يفتح التمويه فقط.';

  @override
  String get pinsWipePin => 'رمز PIN للمسح';

  @override
  String get pinsNeedsAPinFirst => 'يلزم رمز PIN أولًا';

  @override
  String get pinsSet => 'تم التعيين';

  @override
  String get pinsChangeWipePin => 'تغيير رمز PIN للمسح';

  @override
  String get pinsRemove => 'إزالة';

  @override
  String get pinsRemoveTheWipePin => 'إزالة رمز PIN للمسح؟';

  @override
  String get pinsTheLockScreenKeeps =>
      'تحتفظ شاشة القفل برمز PIN الخاص بك. ولا يعود لرمز PIN للمسح أي مفعول.';

  @override
  String profileCopied(Object what) {
    return 'نُسخ ⁨$what⁩';
  }

  @override
  String get profileProfile => 'الملف الشخصي';

  @override
  String get profileKryfoId => 'اسمك';

  @override
  String get profileOnionAddress => 'عنوان onion';

  @override
  String get profileSupporterBadge => 'شارة الداعم';

  @override
  String profileYouAreAThank(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter': 'أنت داعم. شكرًا لك.',
      'patron': 'أنت راعٍ. شكرًا لك.',
      'guardian': 'أنت حارس. شكرًا لك.',
      'other': 'أنت داعم. شكرًا لك.',
    });
    return '$_temp0';
  }

  @override
  String get profileShowMyBadge => 'إظهار شارتي';

  @override
  String get profileOnMyOwnScreens => 'على شاشاتي';

  @override
  String get profileLetContactsSeeIt => 'السماح لجهات الاتصال برؤيتها';

  @override
  String get profileOffByDefault => 'معطّل افتراضيًا';

  @override
  String get profileShareConnect => 'المشاركة والتواصل';

  @override
  String get profileMyKryfoCode => 'رمزي في Kryfo';

  @override
  String get profileAddContact => 'إضافة جهة اتصال';

  @override
  String get profileGiveAgain => 'التبرع مجددًا';

  @override
  String get profileSupportKryfo => 'ادعم Kryfo';

  @override
  String get profileKryfoRunsOnWhat => 'يعيش Kryfo على ما يقدّمه الناس';

  @override
  String get profileKeepKryfoIndependent => 'أبقِ Kryfo مستقلًا';

  @override
  String get qrLink => 'رابط';

  @override
  String get qrYourLinkAsTyped => 'رابطك كما كتبته · بلا إعادة توجيه للتتبع';

  @override
  String get qrText => 'نص';

  @override
  String get qrStaysInTheCode => 'يبقى داخل الرمز · لا يحتفظ به أي خادم';

  @override
  String get qrWiFi => 'Wi-Fi';

  @override
  String get qrMadeOnThisPhone =>
      'صُنع على هذا الهاتف · لم يرَ أي موقع كلمة المرور';

  @override
  String get qrNetworkName => 'اسم الشبكة';

  @override
  String get qrPassword => 'كلمة المرور';

  @override
  String get qrContact => 'جهة اتصال';

  @override
  String get qrOnlyWhatYouType => 'ما تكتبه فقط · لا شيء من جهات اتصالك';

  @override
  String get qrName => 'الاسم';

  @override
  String get qrPhone => 'الهاتف';

  @override
  String get qrEmail => 'البريد';

  @override
  String get qrOpensTheirMailApp =>
      'يفتح تطبيق البريد لديه · لا يُرسل شيء من هنا';

  @override
  String get qrTo => 'إلى';

  @override
  String get qrSubject => 'الموضوع';

  @override
  String get qrANumberNothingElse => 'رقم · لا شيء غيره';

  @override
  String get qrNumber => 'الرقم';

  @override
  String get qrSms => 'SMS';

  @override
  String get qrOpensTheirMessagesApp =>
      'يفتح تطبيق الرسائل لديه · لا يُرسل شيء من هنا';

  @override
  String get qrMessage => 'الرسالة';

  @override
  String get qrLocation => 'الموقع';

  @override
  String get qrCoordinatesOnlyNoMap => 'إحداثيات فقط · دون سؤال أي خدمة خرائط';

  @override
  String get qrLatitude => 'خط العرض';

  @override
  String get qrLongitude => 'خط الطول';

  @override
  String get qrBitcoin => 'Bitcoin';

  @override
  String get qrAddressAndAmountNo => 'العنوان والمبلغ · بلا موقع دفع وسيط';

  @override
  String get qrAddress => 'العنوان';

  @override
  String get qrAmountInBtc => 'المبلغ بـ BTC';

  @override
  String get qrInk => 'حبر';

  @override
  String get qrAmber => 'كهرماني';

  @override
  String get qrViolet => 'بنفسجي';

  @override
  String get qrCouldNotDrawThe => 'تعذّر رسم الصورة.';

  @override
  String get qrSavedToYourGallery => 'حُفظت في معرضك';

  @override
  String get qrCouldNotSaveIt => 'تعذّر حفظها. تأكد من وجود مساحة على الهاتف.';

  @override
  String get qrNoAppOnThis => 'لم يستلم أي تطبيق على هذا الهاتف الصورة.';

  @override
  String get qrTooMuchForOne => 'أكثر مما يتسع له رمز واحد. اختصره.';

  @override
  String get qrThisIsALot =>
      'هذا كثير على رمز واحد. قد لا تقرؤه الكاميرات القديمة.';

  @override
  String get qrPrivateQrCode => 'رمز QR خاص';

  @override
  String get qrColour => 'اللون';

  @override
  String get qrCopiedItLeavesThe => 'تم النسخ. سيُزال من الحافظة بعد دقيقة';

  @override
  String get qrSecurity => 'الأمان';

  @override
  String get qrNone => 'بلا';

  @override
  String get qrSaveImage => 'حفظ الصورة';

  @override
  String qrColour2(Object name) {
    return 'لون ⁨$name⁩';
  }

  @override
  String get qrTypeBelowAndThe => 'اكتب في الأسفل\nوسيرسم الرمز نفسه';

  @override
  String get qrQrCode => 'رمز QR';

  @override
  String get qrHidePassword => 'إخفاء كلمة المرور';

  @override
  String get qrShowPassword => 'إظهار كلمة المرور';

  @override
  String get qrCopyPassword => 'نسخ كلمة المرور';

  @override
  String get requestsSentAnAttachment => 'أرسل مرفقًا';

  @override
  String get requestsWantsToConnect => 'يريد التواصل';

  @override
  String get requestsAccepted => 'تم القبول';

  @override
  String requestsBlock(Object id) {
    return 'حظر ⁨$id⁩؟';
  }

  @override
  String get requestsNothingMoreFromThem =>
      'لن يصلك منه شيء بعد الآن. ويُحذف طلبه ورسائله.';

  @override
  String get requestsRequests => 'الطلبات';

  @override
  String get requestsNoRequests => 'لا طلبات';

  @override
  String get requestsMessagesFromPeopleYou =>
      'تظهر هنا أولًا رسائل من لم تُضِفهم.';

  @override
  String get commonAccept => 'قبول';

  @override
  String get requestsDecline => 'رفض';

  @override
  String get restoreThatFileIsNot => 'هذا الملف ليس نسخة احتياطية من Kryfo';

  @override
  String get restoreThisFileIsDamaged => 'هذا الملف تالف ولا يمكن قراءته';

  @override
  String get restoreTypeThePassphraseThe =>
      'اكتب عبارة المرور التي أُنشئ بها الملف';

  @override
  String get restoreReplaceTheAccountOn => 'استبدال الحساب على هذا الهاتف؟';

  @override
  String get restoreReplaceTheAccountOnDesk =>
      'استبدال الحساب على هذا الحاسوب؟';

  @override
  String get restoreWhatIsHereNow =>
      'يزول ما هو موجود هنا الآن، بهويته وجهات اتصاله ورسائله. ويحل الملف محله. لا يمكن التراجع عن هذا.';

  @override
  String get restoreReplaceIt => 'استبداله';

  @override
  String restoreCouldNotBeReleased(Object mine) {
    return 'تعذّر تحرير ⁦@$mine⁩';
  }

  @override
  String restoreTheRegistryDidNot(Object mine) {
    return 'لم يُجب السجل. إن تابعت، سيبقى ⁦@$mine⁩ مشيرًا إلى الهوية التي يوشك هذا الهاتف أن يفقدها. كل من يضيفه سيكتب إلى لا أحد، ولا يمكن حجز الاسم مجددًا. الأفضل أن تتصل بالإنترنت وتحاول مرة أخرى.';
  }

  @override
  String restoreTheRegistryDidNotDesk(Object mine) {
    return 'لم يُجب السجل. إن تابعت، سيبقى ⁦@$mine⁩ مشيرًا إلى الهوية التي يوشك هذا الحاسوب أن يفقدها. كل من يضيفه سيكتب إلى لا أحد، ولا يمكن حجز الاسم مجددًا. الأفضل أن تتصل بالإنترنت وتحاول مرة أخرى.';
  }

  @override
  String get restoreRestoreAnyway => 'الاستعادة على أي حال';

  @override
  String get restoreNotYet => 'ليس بعد';

  @override
  String get restoreRestored => 'تمت الاستعادة';

  @override
  String restoreKryfoWillCloseNow(Object haloId) {
    return 'سيُغلق Kryfo الآن. اضغط الأيقونة لإعادة فتحه باسم ⁨$haloId⁩.';
  }

  @override
  String restoreKryfoWillCloseNowDesk(Object haloId) {
    return 'سيُغلق Kryfo الآن. شغّله مرة أخرى لفتحه باسم ⁨$haloId⁩.';
  }

  @override
  String get restorePrivacyKept =>
      'تعود إعدادات الخصوصية مع النسخة الاحتياطية. رموز PIN لا تنتقل أبدًا: عيّنها من جديد في الإعدادات.';

  @override
  String get restoreCheckProtections =>
      'الإعدادات ليست ضمن النسخة الاحتياطية. بعد إعادة فتح Kryfo، راجع «وسائل حمايتك» في الإعدادات.';

  @override
  String get restoreReopenKryfo => 'إعادة فتح Kryfo';

  @override
  String get restoreTheRestoreDidNot => 'لم تكتمل الاستعادة. لم يتغيّر شيء';

  @override
  String get restoreKryfoClosesRestoreAgain =>
      'استُبدل جزء مما كان هنا. سيُغلق Kryfo الآن. افتحه من جديد واستعد الملف مرة أخرى.';

  @override
  String get restoreThisIdentity => 'هذه الهوية';

  @override
  String get restoreMoveYourKryfoHere => 'انقل Kryfo الخاص بك إلى هنا';

  @override
  String restoreThisBackupIsRestoring(Object name) {
    return 'هذه النسخة الاحتياطية تخص ⁨$name⁩. استعادتها تنقل تلك الهوية إلى هذا الجهاز.';
  }

  @override
  String restoreThisBackupMadeOn(Object name, Object date, Object time) {
    return 'هذه النسخة الاحتياطية تخص ⁨$name⁩، أُنشئت في ⁨$date⁩ الساعة ⁨$time⁩. استعادتها تنقل تلك الهوية إلى هذا الجهاز.';
  }

  @override
  String restoreItHoldsOfPhotos(Object mb) {
    return 'تحتوي على ⁨$mb⁩ من الصور والرسائل الصوتية والملفات. قد يستغرق هذا بضع دقائق. أبقِ التطبيق مفتوحًا.';
  }

  @override
  String get restoreWhatFollows => 'ما ينتقل معك';

  @override
  String get restoreYourNameYourCode => 'اسمك، ورمزك، وكل جهة اتصال.';

  @override
  String get restoreEveryConversationBackTo => 'كل محادثة، منذ بدايتها.';

  @override
  String get restoreYourPhotosVoiceNotes => 'صورك ورسائلك الصوتية وملفاتك.';

  @override
  String restoreYourPhotosVoiceNotesCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'صورك ورسائلك الصوتية وملفاتك · ⁨$countString⁩.',
    );
    return '$_temp0';
  }

  @override
  String get restoreYourOnionAddressSo =>
      'عنوان onion الخاص بك، ليظل من يصلون إليك مباشرةً قادرين على الوصول إليك.';

  @override
  String get restoreAnythingSentToYou =>
      'كل ما أُرسل إليك والهاتف القديم مطفأ، خلال أربعة عشر يومًا من إرساله.';

  @override
  String get restoreAnythingSentToYouDesk =>
      'كل ما أُرسل إليك والجهاز القديم مطفأ، خلال أربعة عشر يومًا من إرساله.';

  @override
  String get restoreYourSupporterBadgeIf => 'شارة الداعم، إن كانت لديك.';

  @override
  String get restoreWhatDoesnT => 'ما لا ينتقل';

  @override
  String get restoreTheOldPhoneStops =>
      'يتوقف الهاتف القديم عن الاستلام لحظة ترسل أي شيء من هنا. أول رسالة ترسلها من هذا الجهاز هي آخر ما يستطيع الهاتف القديم متابعته، وكل ما يصله بعد ذلك لا يمكن قراءته هناك، ولا ينتظرك هنا أيضًا.';

  @override
  String get restoreTheOldPhoneStopsDesk =>
      'يتوقف الجهاز القديم عن الاستلام لحظة ترسل أي شيء من هنا. أول رسالة ترسلها من هذا الحاسوب هي آخر ما يستطيع الجهاز القديم متابعته، وكل ما يصله بعد ذلك لا يمكن قراءته هناك، ولا ينتظرك هنا أيضًا.';

  @override
  String get restoreIfThePhoneThis =>
      'إن كان الهاتف الذي جاء منه هذا الملف ما زال مستخدمًا، فتوقف عن استخدام Kryfo عليه قبل أن تتابع. هاتفان على Kryfo واحد يفقدان الرسائل كلاهما.';

  @override
  String get restoreIfThePhoneThisDesk =>
      'إن كان الجهاز الذي جاء منه هذا الملف ما زال مستخدمًا، فتوقف عن استخدام Kryfo عليه قبل أن تتابع. جهازان على Kryfo واحد يفقدان الرسائل كلاهما.';

  @override
  String get restoreNotificationsNeedSettingUp =>
      'يجب إعداد الإشعارات من جديد على هذا الجهاز.';

  @override
  String get restoreDeletedComeBack =>
      'المحادثات التي حذفتها بعد إنشاء هذه النسخة الاحتياطية تعود معها، وقد يرى أصحابها أنك أعدت إعداد Kryfo.';

  @override
  String get restoreMoveItHere => 'نقله إلى هنا';

  @override
  String get restoreNotNow => 'ليس الآن';

  @override
  String get restoreRestore => 'استعادة';

  @override
  String get restoreFromABackupFile => 'من ملف نسخة احتياطية';

  @override
  String get restoreABackupBringsBack =>
      'تُعيد النسخة الاحتياطية هويتك وجهات اتصالك، والرسائل التي كانت على الهاتف حين أُنشئ الملف. وما قيل بعد ذلك ليس فيها.';

  @override
  String get restoreABackupBringsBackDesk =>
      'تُعيد النسخة الاحتياطية هويتك وجهات اتصالك، والرسائل التي كانت على الجهاز حين أُنشئ الملف. وما قيل بعد ذلك ليس فيها.';

  @override
  String get restoreTheFile => 'الملف';

  @override
  String get restorePickTheBackupFile => 'اختر ملف النسخة الاحتياطية';

  @override
  String get restoreThePassphrase => 'عبارة المرور';

  @override
  String get restoreTheOneTheFile => 'التي أُنشئ بها الملف';

  @override
  String get restoreWhatComesBack => 'ما يعود';

  @override
  String get restoreChecking => 'جارٍ التحقق…';

  @override
  String get restoreCheckTheFile => 'فحص الملف';

  @override
  String get restoreReleasingYourHandle => 'جارٍ تحرير اسم المستخدم…';

  @override
  String restoreMoving(Object progress) {
    return 'جارٍ النقل… ⁨$progress⁩';
  }

  @override
  String get restoreRestoring => 'جارٍ الاستعادة…';

  @override
  String get restoreNotThisOne => 'ليس هذا';

  @override
  String get restoreStopRestore => 'إيقاف الاستعادة';

  @override
  String get restoreDateUnknown => 'تاريخ غير معروف';

  @override
  String get restoreAnIdentity => 'هوية';

  @override
  String get restoreMessagesSentOrReceived =>
      'الرسائل المُرسلة أو المستلمة بعد ذلك التاريخ ليست في هذا الملف.';

  @override
  String restoreGb(Object bytes) {
    return '⁨$bytes⁩ غ.ب';
  }

  @override
  String restoreMb(Object bytes) {
    return '⁨$bytes⁩ م.ب';
  }

  @override
  String get roomCreateCouldNotCreateThe => 'تعذّر إنشاء الغرفة';

  @override
  String get roomCreateBurnerRoom => 'غرفة مؤقتة';

  @override
  String get roomCreateARoomThatEnds =>
      'غرفة تنتهي. ينضم الجميع بمفتاح صُنع لها، وحين تنتهي لا يبقى منها شيء على أي هاتف.';

  @override
  String get roomCreateARoomThatEndsDesk =>
      'غرفة تنتهي. ينضم الجميع بمفتاح صُنع لها، وحين تنتهي لا يبقى منها شيء على أي جهاز.';

  @override
  String get roomCreateRoomName => 'اسم الغرفة';

  @override
  String get roomCreateEndsAfter => 'تنتهي بعد';

  @override
  String get roomCreateMemberCap => 'حد الأعضاء';

  @override
  String roomCreateNoOnePastThe(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'لا يدخل أحد بعد أول ⁨$countString⁩',
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
      other: 'معطّل. أي شخص لديه الرابط، حتى ⁨$countString⁩',
    );
    return '$_temp0';
  }

  @override
  String roomCreateThisRoomAndEverything(Object expiryWords) {
    return 'تختفي هذه الغرفة وكل ما فيها بعد ⁨$expiryWords⁩';
  }

  @override
  String get roomCreateCreating => 'جارٍ الإنشاء...';

  @override
  String get roomCreateCreateRoom => 'إنشاء الغرفة';

  @override
  String get roomLinkSendTheRoomTo => 'إرسال الغرفة إلى';

  @override
  String get roomLinkTheyWillKnowThis =>
      'سيعرف أن هذه الغرفة جاءت منك. وفي داخلها هو مفتاح كأي شخص آخر.';

  @override
  String get roomLinkNoContactsYet => 'لا جهات اتصال بعد';

  @override
  String roomLinkEndsIn(Object time) {
    return 'تنتهي بعد ⁨$time⁩';
  }

  @override
  String get roomLinkAnyoneWithThisCan =>
      'يمكن لأي شخص لديه هذا الرابط الانضمام حتى تنتهي الغرفة. يدخل بمفتاح صُنع لهذه الغرفة، ولا يرى شيئًا أُرسل قبل وصوله.';

  @override
  String get roomLinkRoomLinkCopied => 'نُسخ رابط الغرفة';

  @override
  String get roomLinkSendToAContact => 'إرسال إلى جهة اتصال';

  @override
  String get roomLinkCopyRoomLink => 'نسخ رابط الغرفة';

  @override
  String get savedVoiceNote => 'رسالة صوتية';

  @override
  String get savedPhoto => 'صورة';

  @override
  String get savedSaved => 'المحفوظات';

  @override
  String get savedNothingSavedYet => 'لا محفوظات بعد';

  @override
  String get savedChatGone => 'تلك المحادثة لم تعد على هذا الهاتف';

  @override
  String get savedChatGoneDesk => 'تلك المحادثة لم تعد على هذا الحاسوب';

  @override
  String get savedLongPressAnyMessage =>
      'اضغط مطولًا على أي رسالة ثم اختر «حفظ» لتبقى هنا.';

  @override
  String get savedViewInChat => 'عرض في المحادثة';

  @override
  String get savedPhoto2 => 'صورة';

  @override
  String get scanThatSNotA => 'هذا ليس رمز QR من Kryfo · واصل التوجيه';

  @override
  String get scanScanAKryfoQr => 'قراءة رمز QR من Kryfo';

  @override
  String get scanFlash => 'الفلاش';

  @override
  String get scanPointAtAKryfo =>
      'وجّه نحو رمز QR من Kryfo · لا شيء يغادر هاتفك';

  @override
  String get seenWhatWeCanSee => 'ما يمكننا رؤيته';

  @override
  String get seenEveryMessengerClaimsPrivacy =>
      'هذه هي القائمة، حسب المسار، بما فيها نقاط الضعف. اضغط على صف لتعرف السبب.';

  @override
  String get seenHonestAboutTheLast =>
      'لهذه الصفوف الأخيرة وُجد قفل التطبيق ورمز PIN للمسح والتخزين المشفّر، ولا أداة تحميك من شخص يمسك هاتفك وهو مفتوح. نموذج التهديدات الكامل موجود في THREAT_MODEL.md في المستودع، مكتوبًا وفق LINDDUN. الشيفرة مفتوحة، فيمكنك التحقق من كل هذا بنفسك.';

  @override
  String get seenHonestAboutTheLastDesk =>
      'لهذه الصفوف الأخيرة وُجد قفل التطبيق ورمز PIN للمسح والتخزين المشفّر، ولا أداة تحميك من شخص يجلس أمام حاسوبك وهو غير مقفل. نموذج التهديدات الكامل موجود في THREAT_MODEL.md في المستودع، مكتوبًا وفق LINDDUN. الشيفرة مفتوحة، فيمكنك التحقق من كل هذا بنفسك.';

  @override
  String get seenHidden => 'مخفي';

  @override
  String get seenNever => 'أبدًا';

  @override
  String get seenOnDevice => 'على الجهاز';

  @override
  String get seenYours => 'مسؤوليتك';

  @override
  String get seenUnaudited => 'غير مُدقَّق';

  @override
  String get seenWhoYouTalkTo => 'مع من تتحدث';

  @override
  String get seenEachConversationGetsIts =>
      'لكل محادثة عنوانها الخاص، مشتق من المفتاحين. يرى المُرحِّل صناديق إيداع لا صلة بينها، لا شخصين. في السريع ترى خوادمنا عنوان IP الخاص بك على صناديق الإيداع التي تستخدمها، وإذا استخدم الطرفان في محادثة السريع، ترى أن عنوانَي IP يتشاركان صندوقًا واحدًا.';

  @override
  String get seenWhatYouSay => 'ما تقوله';

  @override
  String get seenEndToEndEncrypted =>
      'مشفّر بين الطرفين بخوارزمية Double Ratchet من Signal، ثم مختوم مرة أخرى داخل غلاف هدية (gift wrap). لا نستطيع قراءته.';

  @override
  String get seenYourIpAddress => 'عنوان IP الخاص بك';

  @override
  String get seenYourContactGraph => 'شبكة معارفك';

  @override
  String get seenKryfoDoesNotScan =>
      'لا يفحص Kryfo جهات اتصالك. لا يوجد هنا رقم هاتف ليتسرّب. في السريع قد تجمع خوادمنا جزءًا منها من عناوين IP التي تتشارك صناديق الإيداع. ولا تحتفظ بأي سجل لذلك.';

  @override
  String get seenIntroducer => 'من عرّفكما';

  @override
  String get seenWhenAContactIntroduces =>
      'حين تعرّفك جهة اتصال على شخص ما، تعرف تلك الجهة أنكما صرتما على اتصال. ولا أحد غيرها. يرى المُرحِّل نصًا مشفّرًا، ولا يرى أي خادم شبكة المعارف أبدًا.';

  @override
  String get seenTheScamShield => 'درع مكافحة الاحتيال';

  @override
  String get seenScamShieldRequestsOnly =>
      'يعمل على هاتفك بقواعد مضمّنة في التطبيق. بلا شبكة، ولا تنزيل قوائم. لا يقرأ إلا طلبات الرسائل من الغرباء، ولا يقرأ أبدًا ما ترسله إليك جهة اتصال أو مجموعة.';

  @override
  String get seenScamShieldRequestsOnlyDesk =>
      'يعمل على حاسوبك بقواعد مضمّنة في التطبيق. بلا شبكة، ولا تنزيل قوائم. لا يقرأ إلا طلبات الرسائل من الغرباء، ولا يقرأ أبدًا ما ترسله إليك جهة اتصال أو مجموعة.';

  @override
  String get seenBurnerRooms => 'الغرف المؤقتة';

  @override
  String get seenRoomKeys => 'مفاتيح الغرفة';

  @override
  String get seenYouJoinARoom =>
      'تنضم إلى الغرفة بمفتاح صُنع لها، فلا يعرف من فيها شيئًا يصلح في مكان آخر. من ينضم متأخرًا لا يحصل على السجل السابق. وعند انتهاء الغرفة تُتلف المفاتيح والرسائل والوسائط.';

  @override
  String get seenLinkPreviews => 'معاينات الروابط';

  @override
  String get seenOverTor => 'عبر Tor';

  @override
  String get seenAPreviewIsFetched =>
      'يجلب المُرسِل المعاينة عبر Tor، وتنتقل داخل الرسالة المشفّرة. الهاتف المستقبِل لا يرسل أي طلب. يعرف الموقع أن شخصًا يستخدم Tor طلب صفحة، ولا شيء آخر. لا تُحمَّل أي صورة أبدًا، ويبقى رابط الغريب نصًا عاديًا.';

  @override
  String get seenAPreviewIsFetchedDesk =>
      'يجلب المُرسِل المعاينة عبر Tor، وتنتقل داخل الرسالة المشفّرة. الجهاز المستقبِل لا يرسل أي طلب. يعرف الموقع أن شخصًا يستخدم Tor طلب صفحة، ولا شيء آخر. لا تُحمَّل أي صورة أبدًا، ويبقى رابط الغريب نصًا عاديًا.';

  @override
  String get seenASeizedUnlockedPhone => 'هاتف مُصادَر غير مقفل';

  @override
  String get seenASeizedUnlockedPhoneDesk => 'حاسوب مُصادَر غير مقفل';

  @override
  String get seenIfSomeoneHoldsYour =>
      'إن أمسك أحدٌ هاتفك وهو مفتوح، فسيقرأ رسائلك. قفل التطبيق ورمز PIN للمسح والتخزين المشفّر تساعد قبل تلك اللحظة، لا بعدها.';

  @override
  String get seenIfSomeoneHoldsYourDesk =>
      'إن جلس أحدٌ أمام حاسوبك وهو غير مقفل، فسيقرأ رسائلك. قفل التطبيق ورمز PIN للمسح والتخزين المشفّر تساعد قبل تلك اللحظة، لا بعدها.';

  @override
  String get seenTheCryptoItself => 'التشفير نفسه';

  @override
  String get seenTheRatchetAndStorage =>
      'طبقتا ratchet والتخزين معياريتان. أما الطبقة التي تربطهما فمن صنعنا ولم يراجعها أي طرف مستقل. إنه برنامج في مرحلة ألفا.';

  @override
  String get seenFast => 'سريع';

  @override
  String get settingsWipeKryfo => 'مسح Kryfo؟';

  @override
  String get settingsIdentityMessagesContactsAnd =>
      'الهوية والرسائل وجهات الاتصال والإعدادات على هذا الهاتف. تزول إلى الأبد ما لم تكن لديك نسخة احتياطية.';

  @override
  String get settingsIdentityMessagesContactsAndDesk =>
      'الهوية والرسائل وجهات الاتصال والإعدادات على هذا الحاسوب. تزول إلى الأبد ما لم تكن لديك نسخة احتياطية.';

  @override
  String get commonContinue => 'متابعة';

  @override
  String settingsTypeWipeToConfirm(Object word) {
    return 'اكتب «⁨$word⁩» للتأكيد';
  }

  @override
  String get settingsTheLastStepNothing => 'الخطوة الأخيرة. لا شيء ينجو منها.';

  @override
  String get settingsWipeWord => 'امسح';

  @override
  String get settingsWipeKryfo2 => 'مسح Kryfo';

  @override
  String get settingsYourProtections => 'وسائل حمايتك';

  @override
  String get settingsTorRouting => 'التوجيه عبر Tor';

  @override
  String get settingsOffFastMode => 'معطّل · الوضع السريع';

  @override
  String get settingsAppLock => 'قفل التطبيق';

  @override
  String get settingsBlockedByAndroid => 'يحجبها أندرويد';

  @override
  String get settingsSpeedPrivacy => 'السرعة والخصوصية';

  @override
  String get settingsFast => 'سريع';

  @override
  String get settingsOnion3Hops => 'Onion · ثلاث قفزات';

  @override
  String settingsPreviewHidden(Object deliveryModeName) {
    return '⁨$deliveryModeName⁩ · المعاينة مخفية';
  }

  @override
  String settingsPreviewShown(Object deliveryModeName) {
    return '⁨$deliveryModeName⁩ · المعاينة ظاهرة';
  }

  @override
  String get settingsRunInBackground => 'العمل في الخلفية';

  @override
  String get settingsSoMessagesArrive => 'لكي تصل الرسائل';

  @override
  String get settingsTransport => 'النقل';

  @override
  String get settingsWhatTheNetworkIs => 'ما تفعله الشبكة';

  @override
  String get settingsBlocked => 'المحظورون';

  @override
  String get settingsAcceptIntroductions => 'قبول التعريفات';

  @override
  String get settingsFriendsCanIntroduceYou =>
      'يمكن لأصدقائك تعريفك على أصدقائهم';

  @override
  String get settingsScamShield => 'درع مكافحة الاحتيال';

  @override
  String get settingsScamShieldHint => 'يُفحص على هاتفك فقط، ولا شيء يغادره';

  @override
  String get settingsScamShieldHintDesk =>
      'يُفحص على حاسوبك فقط، ولا شيء يغادره';

  @override
  String get typingNow => 'يكتب';

  @override
  String get settingsTypingIndicator => 'مؤشر الكتابة';

  @override
  String get settingsTypingIndicatorHint =>
      'يرى كلٌّ منكما متى يكتب الآخر. تصل الإشارة إليه مباشرةً عبر Tor، ولا تمرّ أبدًا عبر مُرحِّل.';

  @override
  String get settingsTypingOnionOnly => 'متاح على مسار Onion';

  @override
  String get settingsTypingBridgesOff =>
      'مُعطَّل ما دامت الجسور قيد الاستخدام: من يراقب اتصالك قد يطابق إشارات الكتابة. يعود من تلقاء نفسه عند إيقاف الجسور.';

  @override
  String get settingsLightTheme => 'المظهر الفاتح';

  @override
  String get settingsSameProtectionBrighter => 'الحماية نفسها، بإضاءة أكثر';

  @override
  String get settingsAppearance => 'المظهر';

  @override
  String get settingsAccentColour => 'لون التمييز';

  @override
  String get settingsColoursAndWallpaper => 'الألوان والخلفية';

  @override
  String get settingsAppLock2 => 'قفل التطبيق';

  @override
  String get settingsYourPinAndA => 'رمز PIN والحماية المتقدمة';

  @override
  String get settingsPinWipePin => 'PIN · PIN للمسح';

  @override
  String get settingsBackUpIdentity => 'نسخ الهوية احتياطيًا';

  @override
  String get settingsEncryptedFile => 'ملف مشفّر';

  @override
  String get settingsRestoreFromBackup => 'الاستعادة من نسخة احتياطية';

  @override
  String get settingsReplaceCurrent => 'استبدال الحالية';

  @override
  String get settingsWhyKryfo => 'لماذا Kryfo';

  @override
  String get settingsHowItProtectsYou => 'كيف يحميك';

  @override
  String get settingsResetMyInviteLink => 'إعادة تعيين رابط دعوتي';

  @override
  String get settingsOldLinksAndCodes =>
      'تتوقف الروابط والرموز القديمة عن العمل، للجميع';

  @override
  String get settingsResetInviteLink => 'إعادة تعيين رابط الدعوة؟';

  @override
  String get settingsAnyoneWithAnOld =>
      'كل من لديه رمز أو رابط قديم لن يستطيع الوصول إليك بعد الآن، عبر أي مسار. ومن لديه الرابط ولم يستخدمه قط سيحتاج إلى رابط جديد منك. وتبقى جهات الاتصال والمحادثات والسجل.';

  @override
  String get settingsReset => 'إعادة تعيين';

  @override
  String get settingsInviteResetShareThe =>
      'أُعيد تعيين الدعوة · شارك الرمز الجديد';

  @override
  String get settingsWhatWeCanSee => 'ما يمكننا رؤيته';

  @override
  String get settingsTheHonestList => 'القائمة الصادقة';

  @override
  String get settingsVersion => 'الإصدار';

  @override
  String get settingsReportAnIssue => 'الإبلاغ عن مشكلة';

  @override
  String get settingsReportInKryfo => 'الكتابة في Kryfo';

  @override
  String get settingsReportInKryfoSub =>
      'المحادثة مع Marios. يمكنك الكتابة دون الكشف عن هويتك.';

  @override
  String get settingsReportByEmail => 'إرسال بريد إلكتروني';

  @override
  String get settingsReportByEmailSub =>
      'gnosiworks@proton.me، من تطبيق البريد لديك';

  @override
  String get settingsBugOrSecurityFlaw => 'خلل أو ثغرة أمنية';

  @override
  String get settingsOpenSource => 'مفتوح المصدر';

  @override
  String get settingsLinkCopied => 'نُسخ الرابط';

  @override
  String get settingsTheOfflineMapIn =>
      'الخريطة غير المتصلة في «الأدوات» مرسومة من Natural Earth (ملكية عامة). أسماء المدن من GeoNames (geonames.org) بترخيص CC BY 4.0.';

  @override
  String get settingsNotIndependentlyAuditedPre =>
      'لم يخضع لتدقيق مستقل. إصدار ألفا: صالح للتجربة، لا للاستخدام في المواقف عالية المخاطر بعد.';

  @override
  String get settingsFollowTitle => 'متابعة GnosiWorks (المطوّر)';

  @override
  String get settingsFollowBrowserNote => 'يُفتح في متصفحك، خارج Kryfo.';

  @override
  String get settingsFollowOpen => 'فتح';

  @override
  String settingsFollowOn(Object name) {
    return 'المتابعة على ⁨$name⁩، خارج Kryfo';
  }

  @override
  String get settingsDangerZone => 'منطقة الخطر';

  @override
  String get settingsWipeKryfoFromThis => 'مسح Kryfo من هذا الهاتف';

  @override
  String get settingsWipeKryfoFromThisDesk => 'مسح Kryfo من هذا الحاسوب';

  @override
  String get toolsMoreTools => 'أدوات أخرى';

  @override
  String get toolsMakeAPrivateQr => 'إنشاء رمز QR خاص';

  @override
  String get toolsLinksWiFiContacts =>
      'روابط، وWi-Fi، وجهات اتصال، وغيرها. يُصنع دون اتصال';

  @override
  String get toolsLockAFile => 'قفل ملف';

  @override
  String get toolsWithAPasswordOpens => 'بكلمة مرور. يُفتح في أي مكان بـ age';

  @override
  String get toolsOpenALockedFile => 'فتح ملف مقفل';

  @override
  String get toolsAnyAgeFileSomeone => 'أي ملف ‎.age أرسله لك أحد';

  @override
  String get toolsWorksOfflineNoContacts =>
      'يعمل دون اتصال · لا حاجة إلى جهات اتصال';

  @override
  String get toolsUsefulFrom => 'مفيدة منذ';

  @override
  String get toolsTheFirstMinute => 'الدقيقة الأولى.';

  @override
  String get toolsEverythingHereHappensOn =>
      'كل شيء هنا يحدث على هذا الهاتف. لا يُرفع شيء، ولا يحتاج أحد غيرك إلى أن يكون على Kryfo.';

  @override
  String get toolsPhotoCleaner => 'منظّف الصور';

  @override
  String get toolsRemovesHiddenInfo =>
      'يزيل المعلومات المخفية (البيانات الوصفية) مثل المكان والوقت وطراز الهاتف';

  @override
  String get toolsPickAPhotoAnd =>
      'اختر صورة أو فيديو لترى ما يكشفه، ثم أزل كل ذلك بلمسة واحدة. يمكنك أيضًا مشاركة واحد مع Kryfo من معرض الصور.';

  @override
  String get toolsPickAPhoto => 'اختيار صورة';

  @override
  String get toolsVideo => 'فيديو';

  @override
  String get transportTransport => 'النقل';

  @override
  String get transportNothingHereLeavesThe =>
      'لا شيء هنا يغادر الهاتف. إنها الحالة نفسها التي يستخدمها المحرّك ليقرر ما يفعل.';

  @override
  String get transportNothingHereLeavesTheDesk =>
      'لا شيء هنا يغادر الحاسوب. إنها الحالة نفسها التي يستخدمها المحرّك ليقرر ما يفعل.';

  @override
  String get transportStayingAlive => 'يبقى نشطًا';

  @override
  String get transportCanSend => 'يمكنه الإرسال';

  @override
  String get commonYes => 'نعم';

  @override
  String get transportNotYet => 'ليس بعد';

  @override
  String get transportOnline => 'متصل';

  @override
  String get transportOffline => 'غير متصل';

  @override
  String get transportQueuedToSend => 'في طابور الإرسال';

  @override
  String get transportOnionPublished => 'عنوان onion منشور';

  @override
  String transportYes(Object uploads) {
    return 'نعم (⁨$uploads⁩)';
  }

  @override
  String transportTryingS(Object pubFor) {
    return 'يحاول منذ ⁨$pubFor⁩ ث';
  }

  @override
  String transportBenchedS(Object r) {
    return 'مُستبعد ⁨$r⁩ ث';
  }

  @override
  String transportFails(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$countString⁩ إخفاق',
      many: '⁨$countString⁩ إخفاقًا',
      few: '⁨$countString⁩ إخفاقات',
      two: 'إخفاقان',
      one: 'إخفاق واحد',
      zero: '⁨$countString⁩ إخفاق',
    );
    return '$_temp0';
  }

  @override
  String get transportOk => 'سليم';

  @override
  String get transportRelaySubscriptions => 'اشتراكات المُرحِّلات';

  @override
  String get transportLastSent => 'آخر إرسال';

  @override
  String get transportNever => 'أبدًا';

  @override
  String transportSAgo(Object sx) {
    return 'قبل ⁨$sx⁩ ث';
  }

  @override
  String get transportLastReceived => 'آخر استلام';

  @override
  String transportSAgo2(Object rx) {
    return 'قبل ⁨$rx⁩ ث';
  }

  @override
  String get transportWithNoContactsThe =>
      'من دون جهات اتصال لا يشترك التطبيق في أي عنوان على المُرحِّلات، فلا يمكن أن تصلك أي رسالة. اقرأ رمز شخص ما لإصلاح ذلك.';

  @override
  String get transportWithNoContactsTheDesk =>
      'من دون جهات اتصال لا يشترك التطبيق في أي عنوان على المُرحِّلات، فلا يمكن أن تصلك أي رسالة. أضف شخصًا ما لإصلاح ذلك.';

  @override
  String get transportSendAnythingWaitingNow => 'إرسال كل ما ينتظر، الآن';

  @override
  String get transportSending => 'جارٍ الإرسال…';

  @override
  String get transportNothingLeftWaiting => 'لم يبقَ شيء في الانتظار';

  @override
  String transportStillWaiting(Object count) {
    return 'ما زال في الانتظار: $count';
  }

  @override
  String get transportOff => 'متوقف';

  @override
  String get transportStarting => 'جارٍ البدء';

  @override
  String get transportBootstrapped => 'اكتمل الإقلاع';

  @override
  String get transportPublishingAddress => 'جارٍ نشر العنوان';

  @override
  String get transportReachable => 'يمكن الوصول إليه';

  @override
  String get transportOurRelayOnion => 'مُرحِّلنا (onion)';

  @override
  String get transportNever2 => 'أبدًا';

  @override
  String get transportJustNow => 'الآن';

  @override
  String transportMAgo(Object inMinutes) {
    return 'قبل ⁨$inMinutes⁩ د';
  }

  @override
  String transportHAgo(Object inHours) {
    return 'قبل ⁨$inHours⁩ س';
  }

  @override
  String transportDAgo(Object inDays) {
    return 'قبل ⁨$inDays⁩ ي';
  }

  @override
  String transportM(Object inMinutes) {
    return '⁨$inMinutes⁩ د';
  }

  @override
  String transportHM(Object inHours, Object d) {
    return '⁨$inHours⁩ س ⁨$d⁩ د';
  }

  @override
  String transportD(Object inDays) {
    return '⁨$inDays⁩ ي';
  }

  @override
  String transportMb(Object b) {
    return '⁨$b⁩ م.ب';
  }

  @override
  String get transportYesCheckedJustNow => 'نعم · فُحص الآن';

  @override
  String transportNoLast(Object ago) {
    return 'لا · آخر مرة ⁨$ago⁩';
  }

  @override
  String get transportLastMessageIn => 'آخر رسالة واردة';

  @override
  String get transportBatteryExemption => 'استثناء البطارية';

  @override
  String get transportUnknown => 'غير معروف';

  @override
  String get transportExempt => 'مُستثنى';

  @override
  String get transportNotExemptTapTo => 'غير مُستثنى · اضغط للإصلاح';

  @override
  String get transportProcessUp => 'العملية تعمل';

  @override
  String get transportLastStop => 'آخر توقف';

  @override
  String get transportStopKilled => 'أوقفه النظام قسرًا';

  @override
  String get transportStopLowMemory => 'الذاكرة منخفضة';

  @override
  String get transportStopCrashed => 'تعطّل';

  @override
  String get transportStopNotResponding => 'لم يستجب';

  @override
  String get transportStopByYou => 'أوقفته أنت';

  @override
  String get transportStopByPhone => 'أوقفه الهاتف';

  @override
  String get transportStopBySecurityApp => 'أوقفه تطبيق الأمان';

  @override
  String get transportStopUpdated => 'تم التحديث';

  @override
  String get transportStopBySystem => 'أوقفه النظام';

  @override
  String get transportStopTooMuch => 'استهلك أكثر من اللازم';

  @override
  String get transportStopPermission => 'تغيّر إذن';

  @override
  String get transportStopClosedItself => 'أُغلق من تلقاء نفسه';

  @override
  String get transportStopOther => 'توقّف';

  @override
  String transportEngine(Object mb, Object mb2) {
    return '⁨$mb⁩ · المحرّك ⁨$mb2⁩';
  }

  @override
  String get transportLastRelayArrival => 'آخر وصول عبر مُرحِّل';

  @override
  String get transportLastCheckIn => 'آخر تفقّد';

  @override
  String get transportNoneYet => 'لا شيء بعد';

  @override
  String get transportLastTorReconnect => 'آخر إعادة اتصال لـ Tor';

  @override
  String get transportCatchUpByRelay => 'اللحاق عبر مُرحِّل';

  @override
  String get transportControlPort => 'منفذ التحكم';

  @override
  String get transportReconnects => 'مرات إعادة الاتصال';

  @override
  String get transportWhyNetwork => 'تغيّرت الشبكة';

  @override
  String get transportWhyHand => 'يدويًا';

  @override
  String get transportWhyRelays => 'لم يردّ أي مُرحِّل';

  @override
  String get transportWhyStall => 'تعثّر البدء';

  @override
  String get transportWhyTorOff => 'كان Tor متوقفًا';

  @override
  String get transportWhyDialer => 'لا مُرحِّل منذ 3 دقائق';

  @override
  String get transportWhyOnion => 'العودة إلى Onion';

  @override
  String get transportWhyBridges => 'تغيّرت الجسور';

  @override
  String get transportWhyAuto => 'تلقائي';

  @override
  String get transportWhyOffline => 'لا توجد شبكة';

  @override
  String get transportWhyCircuits => 'دوائر جديدة';

  @override
  String get transportWhyOther => 'أخرى';

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
      other: '⁨$dialsString⁩ محاولة',
      many: '⁨$dialsString⁩ محاولة',
      few: '⁨$dialsString⁩ محاولات',
      two: 'محاولتان',
      one: 'محاولة واحدة',
      zero: '⁨$dialsString⁩ محاولة',
    );
    String _temp1 = intl.Intl.pluralLogic(
      timeouts,
      locale: localeName,
      other: '⁨$timeoutsString⁩ مهلة',
      many: '⁨$timeoutsString⁩ مهلة',
      few: '⁨$timeoutsString⁩ مهلات',
      two: 'مهلتان',
      one: 'مهلة واحدة',
      zero: '⁨$timeoutsString⁩ مهلة',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get transportJobRuns => 'تشغيلات المهمة';

  @override
  String transportLast(Object jobRuns, Object ago) {
    return '⁨$jobRuns⁩ · آخرها ⁨$ago⁩';
  }

  @override
  String get transportQuietStretches => 'فترات الصمت';

  @override
  String get transportNone => 'لا شيء';

  @override
  String get transportClearThisRecord => 'إفراغ هذا السجل';

  @override
  String get transportNothingYetThisProcess => 'لا شيء بعد في هذه العملية';

  @override
  String transportM2(Object mins) {
    return '⁨$mins⁩ د';
  }

  @override
  String transportHM2(Object mins, Object mins2) {
    return '⁨$mins⁩ س ⁨$mins2⁩ د';
  }

  @override
  String transportTo(Object t, Object t2) {
    return 'من ⁨$t⁩ إلى ⁨$t2⁩';
  }

  @override
  String vouchersVouchedBy(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'زكّاه ⁨$countString⁩',
      many: 'زكّاه ⁨$countString⁩',
      few: 'زكّاه ⁨$countString⁩',
      two: 'زكّاه اثنان',
      one: 'زكّاه',
      zero: 'لم يزكّه أحد',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperAtmosphere => 'الأجواء';

  @override
  String get wallpaperJustForYouThey => 'لك وحدك. هو يرى خلفيته الخاصة.';

  @override
  String get wallpaperYourPhoto => 'صورتك';

  @override
  String get wallpaperDefault => 'الافتراضي';

  @override
  String get wallpaperNotSet => 'لم تُضبط الخلفية. حاول مرة أخرى.';

  @override
  String get wallpaperFromYourPhotos => 'من صورك';

  @override
  String get wallpaperKeepIt => 'إبقاؤها';

  @override
  String get whyKryfoWhyKryfo => 'لماذا Kryfo';

  @override
  String get whyKryfoKryfoKreeFoGreek =>
      'Kryfo · كري-فو · تعني «مخفي» باليونانية.\nمكان هادئ للحديث، بُني كي لا يراقبك أحد.';

  @override
  String get whyKryfoRoutedThroughTor => 'يمر عبر Tor';

  @override
  String get whyKryfoByDefaultEveryMessage =>
      'افتراضيًا، تنتقل كل رسالة عبر Tor، سلسلة من المُرحِّلات. لا أحد، لا نحن ولا شبكتك، يستطيع أن يرى مع من تتحدث أو أين أنت.';

  @override
  String get whyKryfoEndToEndEncrypted => 'مشفّر بين الطرفين';

  @override
  String get whyKryfoMessagesAreSealedWith =>
      'الرسائل مختومة بمفاتيح لا يملكها إلا أنت ومن تتحدث معه. لا نستطيع قراءتها.';

  @override
  String get whyKryfoNoServersHoldingYour => 'لا خوادم تحتفظ بحياتك';

  @override
  String get whyKryfoNoAccountNoPhone =>
      'لا حساب، ولا رقم هاتف، ولا خادم مركزي يخزّن محادثاتك. إنها تعيش على هذا الهاتف، مشفّرة وهي مخزّنة.';

  @override
  String get whyKryfoNoAccountNoPhoneDesk =>
      'لا حساب، ولا رقم هاتف، ولا خادم مركزي يخزّن محادثاتك. إنها تعيش على هذا الحاسوب، مشفّرة وهي مخزّنة.';

  @override
  String get whyKryfoNothingLeaks => 'لا شيء يتسرّب';

  @override
  String get whyKryfoNoReceiptsTyping =>
      'لا إشعارات قراءة، ولا قائمة جهات اتصال تُرفع. لا يرى أنك تكتب إلا من تكتب إليه، مباشرةً عبر Tor، ولا يمرّ ذلك أبدًا عبر خادم. معظم التطبيقات تسرّب البيانات الوصفية. أما Kryfo فمبني كي لا يفعل.';

  @override
  String get whyKryfoVerifyItIsReally => 'تحقّق من أنه هو فعلًا';

  @override
  String get whyKryfoCompareASafetyNumber =>
      'قارن رقم الأمان وجهًا لوجه أو عبر قناة تثق بها، لتعرف أن لا أحد ينتحل شخصية جهة اتصالك.';

  @override
  String get whyKryfoTheHonestPart => 'الجزء الصريح';

  @override
  String get whyKryfoKryfoIsPreAlpha =>
      'ما زال Kryfo في مرحلة ألفا ولم يخضع لتدقيق. التشفير حقيقي لكن لم يفحصه أي خبير خارجي بعد، فلا تعتمد عليه بعدُ حيث تتوقف سلامتك عليه.';

  @override
  String get cleanerLocation => 'الموقع';

  @override
  String get cleanerAlreadyBlankedByAndroid => 'أفرغه أندرويد مسبقًا';

  @override
  String get cleanerPhoneModel => 'طراز الهاتف';

  @override
  String get cleanerTimeTaken => 'وقت الالتقاط';

  @override
  String get cleanerSerialNumber => 'الرقم التسلسلي';

  @override
  String get cleanerOwnerName => 'اسم المالك';

  @override
  String get cleanerHiddenThumbnail => 'صورة مصغّرة مخفية';

  @override
  String get cleanerContentCredentials => 'بيانات اعتماد المحتوى';

  @override
  String get cleanerHdrLayer => 'طبقة HDR';

  @override
  String get cleanerDataAfterThePicture => 'بيانات بعد الصورة';

  @override
  String cleaner1OtherField(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$countString⁩ حقل آخر',
      many: '⁨$countString⁩ حقلًا آخر',
      few: '⁨$countString⁩ حقول أخرى',
      two: 'حقلان آخران',
      one: 'حقل آخر واحد',
      zero: '⁨$countString⁩ حقل آخر',
    );
    return '$_temp0';
  }

  @override
  String get lockWordsFourRandomWordsBeat =>
      'أربع كلمات عشوائية أقوى من كلمة ذكية واحدة.';

  @override
  String lockWordsTooShortAtLeast(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'قصيرة جدًا. ⁨$countString⁩ حرف على الأقل.',
      many: 'قصيرة جدًا. ⁨$countString⁩ حرفًا على الأقل.',
      few: 'قصيرة جدًا. ⁨$countString⁩ أحرف على الأقل.',
      two: 'قصيرة جدًا. حرفان على الأقل.',
      one: 'قصيرة جدًا. حرف واحد على الأقل.',
      zero: 'قصيرة جدًا. ⁨$countString⁩ حرف على الأقل.',
    );
    return '$_temp0';
  }

  @override
  String get lockWordsWeakWhoeverGetsThe =>
      'ضعيفة. من يحصل على الملف يمكنه التخمين بالسرعة التي يريدها.';

  @override
  String get lockWordsFairLongerIsStronger => 'مقبولة. الأطول أقوى.';

  @override
  String get lockWordsStrongFourRandomWords =>
      'قوية. أربع كلمات عشوائية أقوى من كلمة ذكية واحدة.';

  @override
  String photoStoryKm(Object m) {
    return '⁨$m⁩ كم';
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
      many: '⁨$countString⁩ مترًا',
      few: '⁨$countString⁩ أمتار',
      two: 'مترين',
      one: 'متر واحد',
      zero: '⁨$countString⁩ متر',
    );
    return '$_temp0';
  }

  @override
  String get photoStoryFarFromAnyTown => 'بعيدًا عن أي بلدة';

  @override
  String photoStoryNear(Object where) {
    return 'قرب ⁨$where⁩';
  }

  @override
  String photoStoryAboutKmFrom(Object near, Object where) {
    return 'على بعد نحو ⁨$near⁩ كم من ⁨$where⁩';
  }

  @override
  String photoStoryS(Object s) {
    return '⁨$s⁩ ث';
  }

  @override
  String photoStory1S(Object s) {
    return '١/⁨$s⁩ ث';
  }

  @override
  String get photoStoryNotAKindKryfo => 'ليس نوعًا يستطيع Kryfo قراءته.';

  @override
  String get photoStorySoItWillNot => 'لذا لن يخمّن.';

  @override
  String get photoStoryThisFileIsDamaged => 'هذا الملف تالف أو مبتور.';

  @override
  String get photoStoryKryfoCouldNotRead =>
      'لم يستطع Kryfo قراءته حتى النهاية.';

  @override
  String get photoStoryWhereItWasRecorded => 'أين سُجّل';

  @override
  String get photoStoryWhereItWasTaken => 'أين التُقطت';

  @override
  String photoStoryLocation(Object coordsLine) {
    return 'الموقع: ⁦$coordsLine⁩';
  }

  @override
  String photoStoryHeightAboveTheSea(Object fix) {
    return 'الارتفاع عن سطح البحر: ⁨$fix⁩ م';
  }

  @override
  String get photoStoryLocationHiddenByAndroid => 'أخفى أندرويد الموقع';

  @override
  String get photoStoryAndroidBlanksItWhen =>
      'يُفرغه أندرويد حين تُختار الصورة بهذه الطريقة. ومشاركتها مع Kryfo من معرضك غالبًا ما تُبقيه. وقد تظل الصورة التي في معرضك تحمله.';

  @override
  String get photoStoryLocationBlankedByAndroid =>
      'الموقع: أفرغه أندرويد قبل أن يراه Kryfo';

  @override
  String photoStoryF(Object r) {
    return 'f/⁨$r⁩';
  }

  @override
  String get photoStoryWhatTookIt => 'ما الذي التقطها';

  @override
  String photoStoryPhoneOrCamera(Object phone) {
    return 'الهاتف أو الكاميرا: ⁨$phone⁩';
  }

  @override
  String get photoStoryWhenItWasRecorded => 'متى سُجّل';

  @override
  String get photoStoryToTheSecondWith => 'حتى الثانية، مع المنطقة الزمنية';

  @override
  String get photoStoryToTheSecond => 'حتى الثانية';

  @override
  String photoStoryTime(Object dateFormat) {
    return 'الوقت: ⁨$dateFormat⁩';
  }

  @override
  String get photoStoryLens => 'العدسة';

  @override
  String photoStoryLens2(Object lens) {
    return 'العدسة: ⁨$lens⁩';
  }

  @override
  String get photoStorySoftware => 'البرنامج';

  @override
  String photoStorySoftware2(Object software) {
    return 'البرنامج: ⁨$software⁩';
  }

  @override
  String get photoStorySerialNumber => 'الرقم التسلسلي';

  @override
  String photoStorySerialNumber2(Object serial) {
    return 'الرقم التسلسلي: ⁨$serial⁩';
  }

  @override
  String get photoStoryOwnerName => 'اسم المالك';

  @override
  String photoStoryOwner(Object r) {
    return 'المالك: ⁨$r⁩';
  }

  @override
  String get photoStoryHiddenThumbnail => 'صورة مصغّرة مخفية';

  @override
  String get photoStoryASmallCopyOf =>
      'نسخة صغيرة من الصورة داخل الملف. قد تُظهر ما أزاله القص';

  @override
  String get photoStoryMakerNotes => 'ملاحظات الصانع';

  @override
  String get photoStoryMakerNotesABlock =>
      'ملاحظات الصانع: كتلة لا يقرؤها إلا الصانع';

  @override
  String get photoStoryEditingHistory => 'سجل التعديل';

  @override
  String get photoStoryXmpEditingHistoryAnd => 'XMP: سجل التعديل والوسوم';

  @override
  String get photoStoryCaptions => 'الشروح';

  @override
  String get photoStoryIptcCaptionsAndCredits => 'IPTC: الشروح والإسنادات';

  @override
  String get photoStoryComment => 'تعليق';

  @override
  String get photoStoryAWrittenComment => 'تعليق مكتوب';

  @override
  String get photoStoryContentCredentials => 'بيانات اعتماد المحتوى';

  @override
  String get photoStorySecondPicture => 'صورة ثانية';

  @override
  String get photoStoryASecondPictureInside => 'صورة ثانية داخل الملف';

  @override
  String get photoStoryMotionVideo => 'فيديو الحركة';

  @override
  String get photoStoryAShortVideoInside => 'مقطع فيديو قصير داخل الملف';

  @override
  String get photoStorySaveTime => 'وقت الحفظ';

  @override
  String get photoStoryTheTimeItWas => 'وقت آخر حفظ له';

  @override
  String get photoStoryTimeStamps => 'الطوابع الزمنية';

  @override
  String get photoStoryCreationTimeStamps => 'طوابع وقت الإنشاء';

  @override
  String get photoStoryDataAfterThePicture => 'بيانات بعد الصورة';

  @override
  String photoStoryDataAfterTheEnd(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'بيانات بعد نهاية الصورة: ⁨$countString⁩ بايت',
      many: 'بيانات بعد نهاية الصورة: ⁨$countString⁩ بايت',
      few: 'بيانات بعد نهاية الصورة: ⁨$countString⁩ بايت',
      two: 'بيانات بعد نهاية الصورة: ⁨$countString⁩ بايت',
      one: 'بيانات بعد نهاية الصورة: ⁨$countString⁩ بايت',
      zero: 'بيانات بعد نهاية الصورة: ⁨$countString⁩ بايت',
    );
    return '$_temp0';
  }

  @override
  String photoStoryTextField(Object k) {
    return 'حقل نصي: ⁨$k⁩';
  }

  @override
  String photoStoryVideoTag(Object k) {
    return 'وسم فيديو: ⁨$k⁩';
  }

  @override
  String photoStoryAlso(Object k) {
    return 'أيضًا: ⁨$k⁩';
  }

  @override
  String photoStoryCameraSettingsFlashFocus(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$countString⁩ إعداد للكاميرا (الفلاش، التركيز، التعريض)',
      many: '⁨$countString⁩ إعدادًا للكاميرا (الفلاش، التركيز، التعريض)',
      few: '⁨$countString⁩ إعدادات للكاميرا (الفلاش، التركيز، التعريض)',
      two: 'إعدادان للكاميرا (الفلاش، التركيز، التعريض)',
      one: 'إعداد واحد للكاميرا (الفلاش، التركيز، التعريض)',
      zero: '⁨$countString⁩ إعداد للكاميرا (الفلاش، التركيز، التعريض)',
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
      other: '⁨$countString⁩ حقل إضافي',
      many: '⁨$countString⁩ حقلًا إضافيًا',
      few: '⁨$countString⁩ حقول إضافية',
      two: 'حقلان إضافيان',
      one: 'حقل إضافي واحد',
      zero: '⁨$countString⁩ حقل إضافي',
    );
    return '$_temp0';
  }

  @override
  String get photoStoryCameraSettings => 'إعدادات الكاميرا';

  @override
  String photoStoryAccurateToAbout(Object metres) {
    return 'بدقة في حدود ⁨$metres⁩.';
  }

  @override
  String get photoStoryEnoughToFindThe => 'يكفي للعثور على الباب.';

  @override
  String get photoStoryEnoughToFindTheStreet => 'يكفي للعثور على الشارع.';

  @override
  String get photoStoryEnoughToFindTheArea => 'يكفي للعثور على المنطقة.';

  @override
  String get photoStoryItKnowsWhereYou => 'إنها تعرف أين كنت.';

  @override
  String get photoStoryDownToTheBuilding => 'حتى المبنى نفسه.';

  @override
  String get photoStoryAndroidHidTheLocation => 'أخفى أندرويد الموقع.';

  @override
  String get photoStoryTheOriginalMayStill => 'قد يظل الأصل يحمله.';

  @override
  String get photoStoryNoLocationInThis => 'لا موقع في هذه الصورة.';

  @override
  String get photoStoryItStillSaysPlenty => 'ومع ذلك تقول الكثير.';

  @override
  String get photoStoryThisOneKnowsNothing => 'هذه لا تعرف شيئًا.';

  @override
  String get photoStoryNothingToRemove => 'لا شيء لإزالته.';

  @override
  String get qrPayloadOpensALink => 'يفتح رابطًا';

  @override
  String qrPayloadOpens(Object host) {
    return 'يفتح ⁨$host⁩';
  }

  @override
  String get qrPayloadShowsANote => 'يعرض ملاحظة';

  @override
  String get qrPayloadScanToJoin => 'اقرأ الرمز للانضمام';

  @override
  String qrPayloadScanToJoin2(Object oneLine) {
    return 'اقرأ الرمز للانضمام · ⁨$oneLine⁩';
  }

  @override
  String get qrPayloadANetworkNameIs => 'اسم الشبكة ٣٢ حرفًا على الأكثر.';

  @override
  String get qrPayloadAWiFiPassword => 'كلمة مرور Wi-Fi من ٨ أحرف على الأقل.';

  @override
  String get qrPayloadSavesAContact => 'يحفظ جهة اتصال';

  @override
  String get qrPayloadWritesAnEmail => 'يكتب بريدًا إلكترونيًا';

  @override
  String get qrPayloadThatDoesNotLook => 'هذا لا يبدو عنوان بريد إلكتروني.';

  @override
  String get qrPayloadCallsANumber => 'يتصل برقم';

  @override
  String get qrPayloadWritesAText => 'يكتب رسالة نصية';

  @override
  String get qrPayloadOpensAMap => 'يفتح خريطة';

  @override
  String get qrPayloadLatitudeRunsFrom90 =>
      'خط العرض من ‎-90 إلى ٩٠، وخط الطول من ‎-180 إلى ١٨٠.';

  @override
  String get qrPayloadPayThisAddress => 'ادفع لهذا العنوان';

  @override
  String get qrPayloadABitcoinAddressIs => 'عنوان bitcoin أحرف وأرقام فقط.';

  @override
  String get qrPayloadTheAmountIsIn =>
      'المبلغ بـ BTC، بما يصل إلى ٨ منازل عشرية.';

  @override
  String vouchTextAnd(Object names, Object names2) {
    return '⁨$names⁩ و⁨$names2⁩';
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
      other: '⁨$restString⁩ آخرون من معارفك',
      many: '⁨$restString⁩ آخرون من معارفك',
      few: '⁨$restString⁩ آخرون من معارفك',
      two: 'اثنان آخران من معارفك',
      one: 'واحد آخر من معارفك',
      zero: '⁨$restString⁩ آخرون من معارفك',
    );
    return '⁨$names⁩، ⁨$names2⁩ و$_temp0';
  }

  @override
  String vouchTextVouchedBy(Object vouchNames) {
    return 'زكّاه ⁨$vouchNames⁩';
  }

  @override
  String vouchTextIntroducedBy(Object vouchNames) {
    return 'عرّفكما ⁨$vouchNames⁩';
  }

  @override
  String vouchTextThisSharesSAddress(Object a, Object b) {
    return 'هذا يشارك عنوان ⁨$a⁩ مع ⁨$b⁩';
  }

  @override
  String get bootFailedKryfoCouldNotStart => 'تعذّر تشغيل Kryfo';

  @override
  String get bootFailedThisIsAFault =>
      'هذا عطل في هذا الجهاز، لا في الشبكة. لا علاقة لـ Tor بذلك.';

  @override
  String get bootFailedKeysDidNotAnswer =>
      'توقّف مخزن المفاتيح في هاتفك عن الاستجابة. إغلاق Kryfo وإعادة فتحه يحلّ المشكلة عادةً.';

  @override
  String get bootFailedKeysDidNotAnswerDesk =>
      'توقّف مخزن المفاتيح في هذا الحاسوب عن الاستجابة. إغلاق Kryfo وإعادة فتحه يحلّ المشكلة عادةً.';

  @override
  String get bootFailedCloseAndReopen => 'إغلاق Kryfo وإعادة فتحه';

  @override
  String get bootFailedStillStuck => 'إذا لم تنفع إعادة المحاولة';

  @override
  String get bootFailedRestoreBackup => 'استعادة نسخة احتياطية';

  @override
  String get bootFailedStartFresh => 'البدء من جديد';

  @override
  String get bootFailedStartFreshTitle => 'البدء من جديد؟';

  @override
  String get bootFailedStartFreshLine =>
      'سيمسح هذا كل ما يحفظه Kryfo على هذا الهاتف: المحادثات وجهات الاتصال والوسائط والمحادثات المخفية وكلماتك الثلاث. لن يُمسّ ملف النسخة الاحتياطية المحفوظ في مكان آخر.';

  @override
  String get bootFailedStartFreshLineDesk =>
      'سيمسح هذا كل ما يحفظه Kryfo على هذا الحاسوب: المحادثات وجهات الاتصال والوسائط والمحادثات المخفية وكلماتك الثلاث. لن يُمسّ ملف النسخة الاحتياطية المحفوظ في مكان آخر.';

  @override
  String get bootFailedStartFreshNext => 'متابعة';

  @override
  String get bootFailedStartFreshSure => 'مسح كل شيء على هذا الهاتف؟';

  @override
  String get bootFailedStartFreshSureDesk => 'مسح كل شيء على هذا الحاسوب؟';

  @override
  String get bootFailedStartFreshSureLine =>
      'لا يمكن التراجع عن هذا. سيُغلق Kryfo ثم يفتح من جديد كأنه مثبّت للتو.';

  @override
  String get bootFailedStartFreshYes => 'امسح وابدأ من جديد';

  @override
  String get kryfoLinkTextThatLinkIsNot => 'لا يستطيع Kryfo قراءة هذا الرابط';

  @override
  String kryfoLinkTextAdd(Object who) {
    return 'إضافة ⁨$who⁩؟';
  }

  @override
  String kryfoLinkTextThisIsAnInvite(Object who) {
    return 'هذه دعوة للتحدث مع ⁨$who⁩. لا تضفه إلا إن كنت تعرف مصدر الرابط.';
  }

  @override
  String get kryfoLinkTextAddThem => 'أضِفه';

  @override
  String get kryfoLinkTextNotNow => 'ليس الآن';

  @override
  String kryfoLinkTextYouAlreadyHave(Object who) {
    return 'لديك ⁨$who⁩ بالفعل';
  }

  @override
  String kryfoLinkTextSomeoneElse(Object who) {
    return 'تسمّي شخصًا في محادثاتك ⁨$who⁩. هذا الرابط من شخص آخر. لا تضفه إلا إن كنت تعرف مصدره.';
  }

  @override
  String kryfoLinkTextJoin(Object roomName) {
    return 'الانضمام إلى ⁨$roomName⁩';
  }

  @override
  String get kryfoLinkTextKryfoLink => 'رابط Kryfo';

  @override
  String kryfoLinkTextAdd2(Object who) {
    return 'إضافة ⁨$who⁩';
  }

  @override
  String get kryfoLinkTextBurnerRoom => 'غرفة مؤقتة';

  @override
  String get kryfoLinkTextThisRoomHasClosed => 'أُغلقت هذه الغرفة';

  @override
  String kryfoLinkTextClosesIn(Object time) {
    return 'تُغلق بعد ⁨$time⁩';
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
      other: 'تُغلق بعد ⁨$time⁩ · بحد أقصى ⁨$capString⁩',
    );
    return '$_temp0';
  }

  @override
  String get kryfoLinkTextJoin2 => 'انضمام';

  @override
  String get kryfoLinkTextYouJoinUnderA =>
      'تنضم بمفتاح صُنع لهذه الغرفة. لا أحد فيها يرى كلماتك الثلاث.';

  @override
  String get linkStubFetchedOverTorBy => 'جُلبت عبر Tor · بواسطة جهازك';

  @override
  String get linkStubFetchedOverTorByTheirDevice =>
      'جُلبت عبر Tor · بواسطة جهازه';

  @override
  String mediaBubblesB(Object bytes) {
    return '⁨$bytes⁩ بايت';
  }

  @override
  String mediaBubblesKb(Object bytes) {
    return '⁨$bytes⁩ ك.ب';
  }

  @override
  String mediaBubblesMb(Object bytes) {
    return '⁨$bytes⁩ م.ب';
  }

  @override
  String get mediaBubblesFile => 'ملف';

  @override
  String get mediaBubblesAudioUnavailable => 'الصوت غير متاح';

  @override
  String get mediaBubblesHidden => 'مموّه';

  @override
  String get mediaBubblesPlaying => 'قيد التشغيل';

  @override
  String get mediaBubblesSendPhoto => 'إرسال الصورة';

  @override
  String get mediaBubblesAddACaption => 'أضف تعليقًا…';

  @override
  String get motionStandby => 'استعداد';

  @override
  String get motionConnecting => 'جارٍ الاتصال';

  @override
  String get motionBuilding => 'جارٍ البناء';

  @override
  String get motionPublishing => 'جارٍ النشر';

  @override
  String get motionReady => 'جاهز';

  @override
  String get motionPreparingToConnect => 'جارٍ التحضير للاتصال';

  @override
  String get motionFindingAPrivatePath => 'جارٍ إيجاد مسار خاص';

  @override
  String get motionCarvingThePath => 'جارٍ شق المسار';

  @override
  String get motionAnnouncingYourArrival => 'جارٍ الإعلان عن وصولك';

  @override
  String get motionYouReAnonymous => 'أنت مجهول الهوية';

  @override
  String get motionReadyToChat => 'جاهز للدردشة';

  @override
  String get motionTorIsStartingIn =>
      'يبدأ Tor في الخلفية. يضيء هذا الرسم مع تشكّل الاتصال.';

  @override
  String get motionMakingAFreshRoute =>
      'جارٍ إنشاء مسار جديد عبر مُرحِّلات مجهولة.';

  @override
  String get motionBouncingThroughRelaysSo =>
      'يتنقّل بين المُرحِّلات كي لا يستطيع أحد تتبّع هذا إليك.';

  @override
  String get motionTellingTheNetworkYou =>
      'جارٍ إبلاغ الشبكة أنك متصل، دون كشف مكانك.';

  @override
  String get motionYourIpIsHidden =>
      'عنوان IP الخاص بك مخفي. لا يصل إليك إلا من لديه Kryfo الخاص بك.';

  @override
  String get motionAddressFinishing =>
      'الرسائل تُرسَل الآن عبر Tor. عنوانك الخاص يكتمل في الخلفية.';

  @override
  String get motionBuilding2 => 'جارٍ البناء';

  @override
  String get motionOpen => 'مفتوح';

  @override
  String get motionLive => 'نشط';

  @override
  String motionCircuit(Object circuit) {
    return 'الدائرة · *⁨$circuit⁩*';
  }

  @override
  String get motionDelivered => 'وصلت';

  @override
  String get motionSent => 'أُرسلت';

  @override
  String get motion1Hop => 'قفزة واحدة';

  @override
  String get motion3Hops => '٣ قفزات';

  @override
  String get movedStripThisKryfoHasMoved =>
      'انتقل Kryfo هذا إلى جهاز آخر. لا يصل أي شيء يُرسل من هنا إلى أحد.';

  @override
  String get navBarChats => 'المحادثات';

  @override
  String get navBarTools => 'الأدوات';

  @override
  String get navBarSupport => 'ادعم';

  @override
  String get navBarMe => 'أنا';

  @override
  String get pairCodePanelPuttingYourInviteIn => 'جارٍ تجهيز دعوتك';

  @override
  String get pairCodePanelYourInviteIsNot => 'دعوتك ليست جاهزة بعد';

  @override
  String get pairCodePanelWorking => 'جارٍ العمل';

  @override
  String get pairCodePanelBurned =>
      'اختفى هذا الرمز. أنشئ رمزًا جديدًا عندما يكون الطرف الآخر جاهزًا.';

  @override
  String get pairCodePanelCodeCopied => 'نُسخ الرمز';

  @override
  String pairCodePanelBurnsIn(Object mm, Object ss) {
    return 'يختفي بعد ⁨$mm⁩:⁨$ss⁩';
  }

  @override
  String get pairCodePanelTheyTapAddChoose =>
      'يضغط «إضافة»، ويختار «رمز»، ثم يكتب هذه الأرقام.';

  @override
  String pinsPinnedMessages(Object count) {
    return 'الرسائل المثبّتة · ⁨$count⁩';
  }

  @override
  String get pinsPinnedMessages2 => 'الرسائل المثبّتة';

  @override
  String get pinsPhoto => 'صورة';

  @override
  String get pinsVoiceMessage => 'رسالة صوتية';

  @override
  String get pinsMessage => 'رسالة';

  @override
  String pinsToday(Object hm) {
    return 'اليوم · ⁨$hm⁩';
  }

  @override
  String get pinsPinned => 'مثبّتة';

  @override
  String pinsOf(Object pinsLength, Object kMaxPins) {
    return '⁨$pinsLength⁩ من ⁨$kMaxPins⁩';
  }

  @override
  String get pinsNothingPinnedHereYet =>
      'لا شيء مثبّت هنا بعد. اضغط مطولًا على رسالة واختر «تثبيت»، فتنتظر هنا للجميع في المحادثة.';

  @override
  String get pinsJump => 'انتقال';

  @override
  String get pinsUnpin => 'إلغاء التثبيت';

  @override
  String previewStripFetchedOverTor(Object domainOf) {
    return '⁨$domainOf⁩ · جُلبت عبر Tor';
  }

  @override
  String get previewStripDropThePreview => 'إزالة المعاينة';

  @override
  String get previewStripAddPreview => 'إضافة معاينة';

  @override
  String get previewStripFetchingOverTor => 'جارٍ الجلب عبر Tor…';

  @override
  String toolPartsB(Object bytes) {
    return '⁨$bytes⁩ بايت';
  }

  @override
  String toolPartsKb(Object bytes) {
    return '⁨$bytes⁩ ك.ب';
  }

  @override
  String toolPartsMb(Object mb) {
    return '⁨$mb⁩ م.ب';
  }

  @override
  String get torBootSplashNoShortcutsNoTraces => 'لا طرق مختصرة، ولا آثار';

  @override
  String get torBootSplashTheNetworkThatKeeps =>
      'الشبكة التي تحمي خصوصيتك تستعد';

  @override
  String get torBootSplashMadeOnThisPhone =>
      'صُنع على هذا الهاتف. لا يُرسل شيء إلى أي مكان.';

  @override
  String get torBootSplashMadeOnThisPhoneDesk =>
      'صُنع على هذا الحاسوب. لا يُرسل شيء إلى أي مكان.';

  @override
  String get torBootSplashFirstLaunchTakesA =>
      'التشغيل الأول يستغرق لحظة · عند البدء فقط';

  @override
  String get torBootSplashTakingLonger => 'يستغرق هذا وقتًا أطول من المعتاد';

  @override
  String get torBootSplashHopEntry => 'الدخول';

  @override
  String get torBootSplashHopMiddle => 'الوسط';

  @override
  String get torBootSplashHopExit => 'الخروج';

  @override
  String get videoBubbleNothingHereOpensThat =>
      'لا شيء هنا يفتحه · ستتم مشاركته بدلًا من ذلك';

  @override
  String videoBubbleMb(Object b) {
    return '⁨$b⁩ م.ب';
  }

  @override
  String videoBubbleKb(Object b) {
    return '⁨$b⁩ ك.ب';
  }

  @override
  String get videoBubbleVideo => 'فيديو';

  @override
  String get notificationsChannelName => 'الرسائل';

  @override
  String get cameraClose => 'إغلاق';

  @override
  String get cameraFlash => 'الفلاش';

  @override
  String get cameraPhoto => 'صورة';

  @override
  String get cameraVideo => 'فيديو';

  @override
  String get cameraRetake => 'إعادة الالتقاط';

  @override
  String get seenIntroductions => 'التعريفات';

  @override
  String get donateAddress => 'العنوان';

  @override
  String get donateCopy => 'نسخ';

  @override
  String get donateDone => 'تم';

  @override
  String get donateTierSupporter => 'داعم';

  @override
  String get donateTierPatron => 'راعٍ';

  @override
  String get donateTierGuardian => 'حارس';

  @override
  String get chatBlock => 'حظر';

  @override
  String get chatDecline => 'رفض';

  @override
  String get chatAccept => 'قبول';

  @override
  String get bridgesConnecting => 'جارٍ الاتصال';

  @override
  String get restoreMade => 'أُنشئت';

  @override
  String get restoreContacts => 'جهات الاتصال';

  @override
  String get restoreMessages => 'الرسائل';

  @override
  String get restoreAttachments => 'المرفقات';

  @override
  String get restoreHiddenChats => 'المحادثات المخفية';

  @override
  String get restoreHiddenFollow =>
      'محادثاتك المخفية، برمز PIN جديد للمحادثات المخفية تختاره في النهاية.';

  @override
  String get restoreChooseHiddenPin =>
      'تضم هذه النسخة الاحتياطية محادثات مخفية. اختر لها رمز PIN للمحادثات المخفية.';

  @override
  String get restoreHiddenLockFirst =>
      'المحادثات المخفية تحتاج إلى قفل التطبيق، لذلك يحصل Kryfo أولًا على رمز PIN خاص به.';

  @override
  String get profileIdentity => 'الهوية';

  @override
  String get avatarPickerShape => 'الشكل';

  @override
  String get avatarPickerColour => 'اللون';

  @override
  String get avatarPickerTurn => 'تدوير';

  @override
  String avatarPickerOption(String what, int n, int count) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$what، $nString من $countString';
  }

  @override
  String get avatarPickerYourInitial => 'حرفك الأول';

  @override
  String get transportStatus => 'الحالة';

  @override
  String get transportBootstrap => 'الإقلاع';

  @override
  String get transportNetwork => 'الشبكة';

  @override
  String get transportConnectivity => 'الاتصال';

  @override
  String get transportRelays => 'المُرحِّلات';

  @override
  String get transportTraffic => 'الحركة';

  @override
  String get transportContacts => 'جهات الاتصال';

  @override
  String get transportKnown => 'معروف';

  @override
  String get transportListening => 'الاستماع';

  @override
  String get transportMemory => 'الذاكرة';

  @override
  String get settingsConnected => 'متصل';

  @override
  String get settingsScreenshots => 'لقطات الشاشة';

  @override
  String get settingsBlocked2 => 'ممنوعة';

  @override
  String get settingsOn => 'مفعّل';

  @override
  String get settingsOff => 'معطّل';

  @override
  String get settingsNotifications => 'الإشعارات';

  @override
  String get settingsPrivacy => 'الخصوصية';

  @override
  String get settingsSecurity => 'الأمان';

  @override
  String get settingsBackup => 'النسخ الاحتياطي';

  @override
  String get settingsVoice => 'الصوت';

  @override
  String get settingsAbout => 'حول';

  @override
  String get wallpaperGradients => 'تدرّجات';

  @override
  String get wallpaperPatterns => 'أنماط';

  @override
  String get wallpaperMoods => 'أمزجة';

  @override
  String get confirmSheetKeep => 'إبقاء';

  @override
  String get confirmSheetSave => 'حفظ';

  @override
  String get confirmSheetCancel => 'إلغاء';

  @override
  String get bridgesFoundAVolunteer => 'وُجد متطوع، جارٍ الاتصال';

  @override
  String get bridgesScanABridgeCode => 'قراءة رمز جسر';

  @override
  String get settingsBridgesForNetworksThat => 'الجسور، للشبكات التي تحجب Tor';

  @override
  String get bridgesCouldNotReachTheTor => 'تعذّر الوصول إلى مشروع Tor';

  @override
  String get torBootSplashConnect => 'اتصال';

  @override
  String get bridgesOffline => 'غير متصل';

  @override
  String get bridgesNothingGotThrough => 'لم تنجح أي طريقة';

  @override
  String get bridgesBridgeFromAFriend => 'جسر من صديق';

  @override
  String get bridgesKryfoCanAskThe =>
      'يستطيع Kryfo أن يطلب من مشروع Tor جسرًا لتجاوز الحجب.';

  @override
  String get bridgesNotNeededRightNow => 'غير مطلوب الآن';

  @override
  String get bridgesBuiltInBridges => 'جسور مدمجة';

  @override
  String get bridgesKryfoCanGetAround => 'صار Kryfo قادرًا على تجاوز حجب Tor';

  @override
  String get bridgesThatSNotABridge => 'هذا ليس سطر جسر';

  @override
  String get transportBridgeError => 'آخر خطأ';

  @override
  String get bridgesDirect => 'مباشر';

  @override
  String get bridgesAskingTheTorProject => 'جارٍ سؤال مشروع Tor عمّا يعمل هنا…';

  @override
  String get bridgesNoneOfTheseAre => 'ليس بين هذه الأسطر سطر جسر يفهمه Kryfo.';

  @override
  String get bridgesAutomatic => 'تلقائي';

  @override
  String get bridgesStraightToTor => 'مباشرة إلى Tor، دون حاجة إلى جسر';

  @override
  String get bridgesKryfoConnectsAsSoon => 'يتصل Kryfo فور عودتك إلى الإنترنت.';

  @override
  String get bridgesMore => 'المزيد';

  @override
  String bridgesTryingAnotherWayOf(String attempt, String attempts) {
    return 'جارٍ تجربة طريقة أخرى… (⁨$attempt⁩ من ⁨$attempts⁩)';
  }

  @override
  String get bridgesLookingForAVolunteer => 'جارٍ البحث عن متطوع';

  @override
  String get bridgesFastestWhereTorIsnt =>
      'الأسرع حيث لا يُحجب Tor. لا يتصل Kryfo أبدًا خارج Tor.';

  @override
  String get transportBridgePhase => 'المرحلة';

  @override
  String get bridgesAsleepBetweenCheckIns => 'نائم بين مرات التفقّد';

  @override
  String get bridgesThroughABridge => 'عبر جسر';

  @override
  String get bridgesBuiltIn => 'مدمج';

  @override
  String get bridgesPasteOrScanALineDesk => 'الصق سطرًا أعطاك إياه شخص تثق به.';

  @override
  String get bridgesDetails => 'التفاصيل';

  @override
  String get transportBridgeMode => 'الجسور';

  @override
  String get bridgesEgypt => 'مصر';

  @override
  String get bridgesYourBridgeCouldNot => 'تعذّر تشغيل الجسر';

  @override
  String get bridgesKryfoStaysOfflineRather =>
      'يبقى Kryfo غير متصل بدل أن يتصل من دونه.';

  @override
  String get bridgesSignInToThisWifi => 'سجّل الدخول إلى شبكة Wi-Fi هذه';

  @override
  String get bridgesThisNetworkWantsA =>
      'تطلب هذه الشبكة تسجيل الدخول أولًا. بعد دخولك، يتصل Kryfo.';

  @override
  String get bridgesThisNetworkWantsADesk =>
      'تطلب هذه الشبكة تسجيل الدخول أولًا. سجّل الدخول من متصفحك، أو تحقق من اتصال الحاسوب بالشبكة. بعد دخولك، يتصل Kryfo.';

  @override
  String get bridgesWaitingForWifiSignIn => 'بانتظار تسجيل الدخول إلى Wi-Fi';

  @override
  String get bridgesOpenWifiSettings => 'فتح إعدادات Wi-Fi';

  @override
  String get bridgesUsingBuiltIn => 'عبر الجسور المدمجة';

  @override
  String get bridgesUsingSnowflake => 'عبر Snowflake';

  @override
  String get bridgesUsingTorProject => 'عبر جسور من مشروع Tor';

  @override
  String get bridgesBridgeRemoved => 'أُزيل الجسر';

  @override
  String get bridgesUndo => 'تراجع';

  @override
  String bridgesRemoveBridgeN(String n) {
    return 'إزالة الجسر ⁨$n⁩';
  }

  @override
  String get bridgesIran => 'إيران';

  @override
  String get bridgesTurnOnAutomatic => 'تفعيل الوضع التلقائي';

  @override
  String get bridgesPasteABridgeLine => 'الصق سطر جسر';

  @override
  String get bridgesInUse => 'قيد الاستخدام';

  @override
  String get bridgesPasteTheLineThey =>
      'الصق السطر الذي أرسله إليك، أو اقرأ رمزه. خذ أسطر الجسور ممن تعرفهم.';

  @override
  String get bridgesYouReOnAMode =>
      'وضعك الحالي لا يستخدم Tor. تُطبَّق هذه الخيارات حين تعود إليه.';

  @override
  String get bridgesPasteOrScanALine =>
      'الصق سطرًا أعطاك إياه شخص تثق به، أو اقرأ رمزه.';

  @override
  String get bridgesNothingYet => 'لا شيء بعد';

  @override
  String get torBootSplashIfTorIsBlocked =>
      'إن كان Tor محجوبًا أو مراقَبًا حيث أنت، فيستطيع Kryfo أن يبدأ عبر جسر بدلًا من ذلك.';

  @override
  String get bridgesScanACode => 'قراءة رمز';

  @override
  String get bridgesMyanmar => 'ميانمار';

  @override
  String get bridgesSwitchToAutomatic => 'التبديل إلى الوضع التلقائي';

  @override
  String get torBootSplashTorIsBlockedHere => 'Tor محجوب أو مراقَب هنا';

  @override
  String get torBootSplashStartThroughABridge => 'ابدأ عبر جسر';

  @override
  String get torBootSplashNeverTriesTorPlainly =>
      'لن يحاول Kryfo الوصول إلى Tor مباشرةً هنا أبدًا. سيجد جسرًا يعمل بنفسه، أو يمكنك اختيار جسرك في الخطوة التالية.';

  @override
  String get bridgesTryingAnotherWay => 'جارٍ تجربة طريقة أخرى…';

  @override
  String get bridgesFindingAWayIn => 'جارٍ البحث عن طريقة للاتصال…';

  @override
  String get bridgesGoesThroughAVolunteer =>
      'يمر عبر حاسوب أحد المتطوعين. صعب الحجب، بطيء البدء.';

  @override
  String get bridgesLetTheTorProject => 'دع مشروع Tor يخمّن';

  @override
  String get bridgesTorSeemsBlocked => 'يبدو أن Tor محجوب على هذه الشبكة';

  @override
  String get bridgesTorIsBlockedOnThis => 'Tor محجوب على هذه الشبكة';

  @override
  String bridgesKryfoCouldNotRead(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تعذّر على Kryfo قراءة ⁨$countString⁩ من هذه الأسطر',
      many: 'تعذّر على Kryfo قراءة ⁨$countString⁩ من هذه الأسطر',
      few: 'تعذّر على Kryfo قراءة ⁨$countString⁩ من هذه الأسطر',
      two: 'تعذّر على Kryfo قراءة ⁨$countString⁩ من هذه الأسطر',
      one: 'تعذّر على Kryfo قراءة ⁨$countString⁩ من هذه الأسطر',
      zero: 'تعذّر على Kryfo قراءة ⁨$countString⁩ من هذه الأسطر',
    );
    return '$_temp0';
  }

  @override
  String get bridgesTorNoBridge => 'Tor، دون جسر';

  @override
  String get bridgesKryfoFindsAWay => 'يجد Kryfo طريقة تعمل حيث أنت.';

  @override
  String get bridgesTheTorProjectKnows =>
      'لدى مشروع Tor نصائح خاصة لهذه البلدان.';

  @override
  String get bridgesThisBridgeIsnTGetting => 'لا يستطيع هذا الجسر العبور';

  @override
  String get bridgesBridgesTheTorProject =>
      'جسور أعطاك إياها مشروع Tor سابقًا.';

  @override
  String get bridgesConnectingDots => 'جارٍ الاتصال…';

  @override
  String get bridgesNotNow => 'ليس الآن';

  @override
  String get bridgesRussia => 'روسيا';

  @override
  String get bridgesObfs4BridgesThatCome =>
      'جسور تأتي مع Kryfo (obfs4). سريعة التجربة، وكثيرًا ما تُحجب.';

  @override
  String get bridgesYourNetworkMayBe => 'قد تكون شبكتك مقيّدة';

  @override
  String get bridgesCheckingForMessages => 'جارٍ التحقق من الرسائل…';

  @override
  String get bridgesSavedLines => 'الأسطر المحفوظة';

  @override
  String get bridgesPasteTheLineTheyDesk =>
      'الصق السطر الذي أرسله إليك. خذ أسطر الجسور ممن تعرفهم.';

  @override
  String get bridgesFromAFriendLower => 'من صديق';

  @override
  String get bridgesAlmostThere => 'اقتربنا';

  @override
  String get bridgesTheTorProjectSGuess => 'تخمين مشروع Tor';

  @override
  String get bridgesUseThisBridge => 'استخدام هذا الجسر';

  @override
  String bridgesUseTheseBridges(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'استخدام هذه الجسور (⁨$countString⁩)',
      many: 'استخدام هذه الجسور (⁨$countString⁩)',
      few: 'استخدام هذه الجسور (⁨$countString⁩)',
      two: 'استخدام هذين الجسرين',
    );
    return '$_temp0';
  }

  @override
  String get bridgesTurkmenistan => 'تركمانستان';

  @override
  String get transportBridgeMethod => 'الطريقة';

  @override
  String get bridgesPointAtTheBridge => 'وجّه الكاميرا إلى رمز QR الخاص بالجسر';

  @override
  String get bridgesConnectingThroughYourBridge => 'جارٍ الاتصال عبر جسرك…';

  @override
  String get bridgesThisLineIsTooLong => 'هذا السطر أطول من أن يستخدمه Tor.';

  @override
  String get bridgesAutomaticFindsAWay =>
      'حين يُحجب Tor، يجد «تلقائي» طريقة بنفسه. وللعثور على جسر، قد يسأل Kryfo مشروع Tor إن وافقت.';

  @override
  String get bridgesFromTheTorProjectLower => 'من مشروع Tor';

  @override
  String get bridgesBridgesGoDeadWithout =>
      'قد تتوقف الجسور عن العمل دون إنذار. يستطيع «تلقائي» إيجاد طريقة أخرى.';

  @override
  String get bridgesHongKong => 'هونغ كونغ';

  @override
  String get bridgesWhenTorIsBlockedAutomatic =>
      'حين يُحجب Tor، يسأل «تلقائي» مشروع Tor عمّا يعمل في بلدك.';

  @override
  String get bridgesAskTorProject => 'اسأل مشروع Tor';

  @override
  String get bridgesTooLongForTor => 'أطول من أن يستخدمه Tor';

  @override
  String get bridgesCountry => 'البلد';

  @override
  String bridgesMethodFrom(String method, String from) {
    return '⁨$method⁩، ⁨$from⁩';
  }

  @override
  String get bridgesChina => 'الصين';

  @override
  String get bridgesBelarus => 'بيلاروس';

  @override
  String get bridgesKryfoCanTUseThis => 'لا يستطيع Kryfo استخدام هذا السطر';

  @override
  String get bridgesTryAutomatic => 'تجربة الوضع التلقائي';

  @override
  String get bridgesNoInternet => 'لا يوجد إنترنت';

  @override
  String get bridgesConnection => 'الاتصال';

  @override
  String get bridgesGetABridge => 'الحصول على جسر';

  @override
  String get languageTitle => 'اللغة';

  @override
  String get languageMatchPhone => 'لغة الهاتف';

  @override
  String get languageMatchPhoneDesk => 'لغة النظام';

  @override
  String languageMatchPhoneValue(Object language) {
    return 'لغة الهاتف (⁨$language⁩)';
  }

  @override
  String languageMatchPhoneValueDesk(Object language) {
    return 'لغة النظام (⁨$language⁩)';
  }

  @override
  String get languageRedrawLine =>
      'يُعاد رسم Kryfo باللغة الجديدة ويفتح على محادثاتك.';

  @override
  String languageButton(Object language) {
    return 'اللغة: ⁨$language⁩';
  }

  @override
  String get androidServiceTitle => 'يعمل Kryfo';

  @override
  String get androidServiceText => 'يبقى خطّك المشفّر مفتوحًا لتصل الرسائل';

  @override
  String get androidChannelName => 'البقاء متصلًا';

  @override
  String get androidChannelDescription =>
      'يُبقي Kryfo متصلًا لتصل الرسائل المشفّرة وهو مغلق. إيقاف هذا يوقف التوصيل.';

  @override
  String get videoViewerPlay => 'تشغيل';

  @override
  String get videoViewerPause => 'إيقاف مؤقت';

  @override
  String get videoViewerPlayAgain => 'إعادة التشغيل';

  @override
  String get videoViewerCannotPlay =>
      'لا يستطيع هذا الهاتف تشغيل هذا الفيديو هنا.';

  @override
  String get videoViewerCannotPlayDesk =>
      'لا يستطيع هذا الحاسوب تشغيل هذا الفيديو هنا.';

  @override
  String get videoViewerOpenElsewhere => 'فتح في تطبيق آخر';

  @override
  String get photoKnowsLookedFor => 'بحثنا عن';

  @override
  String get photoKnowsNotInIt => 'غير موجود';

  @override
  String get languageNameEn => 'الإنجليزية';

  @override
  String get languageNameDe => 'الألمانية';

  @override
  String get languageNameFr => 'الفرنسية';

  @override
  String get languageNameEs => 'الإسبانية';

  @override
  String get languageNamePt => 'البرتغالية (البرازيل)';

  @override
  String get languageNameIt => 'الإيطالية';

  @override
  String get languageNameRu => 'الروسية';

  @override
  String get languageNameUk => 'الأوكرانية';

  @override
  String get languageNameTr => 'التركية';

  @override
  String get languageNameZh => 'الصينية (المبسطة)';

  @override
  String get languageNameZhHant => 'الصينية (التقليدية)';

  @override
  String get languageNameVi => 'الفيتنامية';

  @override
  String get languageNameId => 'الإندونيسية';

  @override
  String get languageNameFa => 'الفارسية';

  @override
  String get languageNameAr => 'العربية';

  @override
  String get languageNameHi => 'الهندية';

  @override
  String get languageNamePl => 'البولندية';

  @override
  String get languageLaterLine => 'يمكنك تغيير هذا في أي وقت من الإعدادات.';

  @override
  String get pollAttach => 'استطلاع';

  @override
  String get pollNewTitle => 'استطلاع جديد';

  @override
  String get pollQuestionHint => 'اسأل المجموعة عن شيء';

  @override
  String get pollOptionsLabel => 'الخيارات';

  @override
  String pollOptionHint(Object n) {
    return 'الخيار ⁨$n⁩';
  }

  @override
  String get pollAddOption => 'إضافة خيار';

  @override
  String get pollMaxLine => 'اثنا عشر خيارًا على الأكثر.';

  @override
  String get pollMultiple => 'إجابات متعددة';

  @override
  String get pollMultipleLine => 'يمكن اختيار أكثر من إجابة.';

  @override
  String get pollSend => 'إرسال الاستطلاع';

  @override
  String get pollKind => 'استطلاع';

  @override
  String get pollKindMulti => 'استطلاع · إجابات متعددة';

  @override
  String get pollKindClosed => 'النتيجة النهائية';

  @override
  String pollVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$count⁩ صوت',
      many: '⁨$count⁩ صوتًا',
      few: '⁨$count⁩ أصوات',
      two: 'صوتان',
      one: 'صوت واحد',
      zero: 'لا أصوات بعد',
    );
    return '$_temp0';
  }

  @override
  String get pollVote => 'تصويت';

  @override
  String get pollTakeBack => 'سحب صوتي';

  @override
  String get pollClose => 'إغلاق الاستطلاع';

  @override
  String get pollCloseTitle => 'إغلاق هذا الاستطلاع؟';

  @override
  String get pollCloseLine =>
      'سيرى الجميع النتيجة النهائية، ولن يتمكن أحد من التصويت بعد ذلك.';

  @override
  String get pollCloseYes => 'إغلاقه';

  @override
  String pollPreview(Object question) {
    return 'استطلاع: ⁨$question⁩';
  }

  @override
  String get pollWhoVoted => 'من صوّت';

  @override
  String get pollNobody => 'لا أحد بعد';

  @override
  String get pollYou => 'أنت';

  @override
  String pollOptionA11y(Object option, Object share) {
    return '⁨$option⁩، ⁨$share⁩';
  }

  @override
  String get pollPickOne => 'اختر إجابة واحدة';

  @override
  String get pollPickSeveral => 'اختر إجابة أو أكثر';

  @override
  String get searchHint => 'ابحث في المحادثات والرسائل';

  @override
  String get searchFilterAll => 'الكل';

  @override
  String get searchFilterPhotos => 'الصور';

  @override
  String get searchFilterVideos => 'الفيديوهات';

  @override
  String get searchFilterFiles => 'الملفات';

  @override
  String get searchFilterLinks => 'الروابط';

  @override
  String get searchChats => 'المحادثات';

  @override
  String get searchMessages => 'الرسائل';

  @override
  String get searchIntroTitle => 'ابحث في محادثاتك';

  @override
  String get searchIntroLine =>
      'الأسماء والكلمات والصور والملفات والروابط. يجري البحث على هذا الهاتف ولا يرسل أي شيء إلى أي مكان.';

  @override
  String get searchIntroLineDesk =>
      'الأسماء والكلمات والصور والملفات والروابط. يجري البحث على هذا الحاسوب ولا يرسل أي شيء إلى أي مكان.';

  @override
  String get searchNothing => 'لم يُعثر على شيء';

  @override
  String get searchNothingLine => 'جرّب كلمة أخرى أو فلترًا آخر.';

  @override
  String searchMatches(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$count⁩ نتيجة',
      many: '⁨$count⁩ نتيجة',
      few: '⁨$count⁩ نتائج',
      two: 'نتيجتان',
      one: 'نتيجة واحدة',
      zero: 'لا نتائج',
    );
    return '$_temp0';
  }

  @override
  String searchMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$count⁩ أخرى',
      many: '⁨$count⁩ أخرى',
      few: '⁨$count⁩ أخرى',
      two: 'اثنتان أخريان',
      one: 'واحدة أخرى',
      zero: 'لا شيء آخر',
    );
    return '$_temp0';
  }

  @override
  String searchFilling(Object share) {
    return 'جارٍ إضافة الرسائل الأقدم · ⁨$share⁩';
  }

  @override
  String get searchClear => 'مسح';

  @override
  String get handleShowInSearch => 'أظهرني في البحث';

  @override
  String get handleShowInSearchLine =>
      'يمكن لأي شخص العثور على اسم المستخدم هذا ومراسلتك.';

  @override
  String handleShownAs(Object name) {
    return 'يظهر باسم ⁨$name⁩';
  }

  @override
  String get handleNameInSearch => 'الاسم في البحث';

  @override
  String get handleNameInSearchLine =>
      'اختياري. يظهر بجانب اسم المستخدم عندما يبحث أحد. يمكن لأي شخص العثور على اسم المستخدم هذا ومراسلتك.';

  @override
  String get handleNameHint => 'اسمك، أو اتركه فارغًا';

  @override
  String get handleShowMe => 'أظهرني';

  @override
  String get handleSearchOff => 'لم تعد في البحث';

  @override
  String handleSearchOn(Object handle) {
    return 'أنت في البحث باسم ⁦@$handle⁩';
  }

  @override
  String get handleRegistryFailed =>
      'تعذّر الوصول إلى السجل. حاول مجددًا بعد دقيقة.';

  @override
  String get handleStillReaching =>
      'ما زال الاتصال بالسجل جاريًا. عبر Tor قد يستغرق ذلك حتى دقيقة.';

  @override
  String get handleSearchNeedsTor =>
      'يحتاج البحث باسم المستخدم إلى Tor. إلى ذلك الحين، أضِف عبر رمز QR أو رابط.';

  @override
  String get handleCheckClock => 'تحقّق من تاريخ الهاتف ووقته، ثم حاول مجددًا.';

  @override
  String get handleCheckClockDesk =>
      'تحقّق من تاريخ الحاسوب ووقته، ثم حاول مجددًا.';

  @override
  String get searchPeople => 'أشخاص';

  @override
  String searchPeopleAsk(Object query) {
    return 'ابحث عن «$query» بين أسماء المستخدمين العامة';
  }

  @override
  String get searchPeopleLine => 'يُسأل عبر Tor. لا يحتفظ السجل بأي أثر له.';

  @override
  String get searchPeopleNone => 'لا يطابق أي اسم مستخدم عام';

  @override
  String get searchPeopleOffline => 'Tor ليس جاهزًا بعد';

  @override
  String get searchPeopleBusy => 'عمليات بحث كثيرة الآن. حاول مجددًا بعد قليل.';

  @override
  String get searchPeopleUnreachable => 'تعذّر الوصول إلى السجل';

  @override
  String get peopleVerified => 'اسم مستخدم موثّق';

  @override
  String get peopleAdd => 'إضافة';

  @override
  String peopleFingerprint(Object fp) {
    return 'بصمة المفتاح · ⁨$fp⁩';
  }

  @override
  String get peopleFingerprintLine =>
      'تأكد من تطابقها مع ما يراه الطرف الآخر في تطبيقه.';

  @override
  String get peopleAdding => 'جارٍ الإضافة…';

  @override
  String handleNobodyHasClaimed(Object handle) {
    return 'لم يحجز أحد ⁦$handle⁩';
  }

  @override
  String get handleThatHandleIsTaken => 'اسم المستخدم هذا محجوز بالفعل';

  @override
  String get pinPickDifferent => 'اختر رمز PIN آخر';

  @override
  String get lockFingerAfterPin =>
      'أدخل رمز PIN مرة واحدة لاستخدام بصمتك من جديد.';

  @override
  String get lockFingerLockedOut =>
      'محاولات كثيرة جدًا بالبصمة. استخدم رمز PIN، أو افتح قفل هاتفك مرة واحدة بقفل الشاشة الخاص به لتعود البصمة.';

  @override
  String get lockFingerRefused =>
      'لم يحتفظ هاتفك بفتح القفل بالبصمة لـ Kryfo، لذا أُوقف. رمز PIN لا يزال يعمل.';

  @override
  String get lockFingerTryAgain =>
      'كان هاتفك مشغولًا في تلك اللحظة. جرّب بصمتك مرة أخرى، أو استخدم رمز PIN.';

  @override
  String get pinsFingerRefused =>
      'لم يسمح هاتفك بتشغيل فتح القفل بالبصمة لـ Kryfo. رمز PIN لا يزال يعمل.';

  @override
  String get pinsAdvanced => 'حماية متقدمة';

  @override
  String get pinsAdvancedLine => 'لحين يجبرك أحد على فتح قفل هاتفك.';

  @override
  String get pinsAdvancedLineDesk => 'لحين يجبرك أحد على فتح قفل حاسوبك.';

  @override
  String get pinsWipeLine =>
      'إن كُتب على شاشة القفل، يمسح Kryfo من هذا الهاتف.';

  @override
  String get pinsWipeLineDesk =>
      'إن كُتب على شاشة القفل، يمسح Kryfo من هذا الحاسوب.';

  @override
  String get pinsDecoyPin => 'رمز PIN للتمويه';

  @override
  String get pinsDecoyLine => 'يفتح Kryfo فارغًا، كأنه مثبت للتو.';

  @override
  String get pinsChangeDecoyPin => 'تغيير رمز PIN للتمويه';

  @override
  String get pinsRemoveTheDecoyPin => 'إزالة رمز PIN للتمويه؟';

  @override
  String get pinsTheDecoyGoes => 'يزول معه Kryfo الفارغ الذي يفتحه.';

  @override
  String get pinsTurnOffWithDecoy =>
      'تُزال كل رموز PIN، ومعها رمز التمويه وما يفتحه من Kryfo وأي محادثات مخفية. وكل من يمسك هاتفك يفتح Kryfo باسمك.';

  @override
  String get pinsTurnOffWithDecoyDesk =>
      'تُزال كل رموز PIN، ومعها رمز التمويه وما يفتحه من Kryfo وأي محادثات مخفية. وكل من يجلس إلى حاسوبك يفتح Kryfo باسمك.';

  @override
  String get pinsHowThisWorks => 'كيف يعمل هذا';

  @override
  String get flowEnterYourPin => 'أدخل رمز PIN';

  @override
  String get flowEnterYourPinLine => 'الرمز الذي يفتح Kryfo.';

  @override
  String get flowWipeTitle => 'رمز PIN للمسح';

  @override
  String get flowWipe1 =>
      'إن كُتب على شاشة القفل بدل رمز PIN الخاص بك، يمسح Kryfo من هذا الهاتف ويغلقه. ولمن يراقب، يبدو أن التطبيق توقف فحسب.';

  @override
  String get flowWipe1Desk =>
      'إن كُتب على شاشة القفل بدل رمز PIN الخاص بك، يمسح Kryfo من هذا الحاسوب ويغلقه. ولمن يراقب، يبدو أن التطبيق توقف فحسب.';

  @override
  String get flowWipe2 =>
      'تذهب معه كل محادثة وهويتك، ومعهما التمويه إن كان لديك.';

  @override
  String get flowWipeChoose => 'اختر رمز PIN للمسح';

  @override
  String get flowWipeDone => 'تم تعيين رمز PIN للمسح';

  @override
  String get flowWipeDoneLine => 'لا شيء على شاشة القفل يدل على وجوده.';

  @override
  String get flowDecoyTitle => 'رمز PIN للتمويه';

  @override
  String get flowDecoy1 => 'يفتح Kryfo فارغًا، كأنه مثبت للتو.';

  @override
  String get flowDecoyFinger =>
      'ما دام رمز PIN للتمويه مضبوطًا، يُفتح هذا التطبيق برمز PIN فقط. وإذا كانت البصمة مفعّلة في التمويه، فالإصبع يفتح التمويه، ولا يفتح هذا التطبيق أبدًا.';

  @override
  String get flowDecoyDigits =>
      'استخدم عدد الأرقام نفسه الذي في رمز PIN الخاص بك، لأن أي شخص يراقب يمكنه عدّ النقاط.';

  @override
  String get flowDecoyShade =>
      'الإشعارات الموجودة في لوحة الإشعارات قد شوهدت بالفعل. وما دام التمويه مفتوحًا، لا يظهر أي إشعار جديد.';

  @override
  String get flowDecoyShadeDesk =>
      'الإشعارات الظاهرة على الشاشة قد شوهدت بالفعل. وما دام التمويه مفتوحًا، لا يظهر أي إشعار جديد.';

  @override
  String get flowDecoyChoose => 'اختر رمز PIN للتمويه';

  @override
  String get flowDecoyDone => 'تم تعيين رمز PIN للتمويه';

  @override
  String get flowDecoyDoneLine =>
      'اكتبه على شاشة القفل لفتح Kryfo الفارغ. وللخروج منه، انتقل إلى تطبيق آخر ثم أدخل رمز PIN الخاص بك.';

  @override
  String get flowLaw =>
      'في بعض الدول، يُعدّ رفض فتح قفل الهاتف أو إخفاء البيانات عن المسؤولين جريمة في حد ذاته. اعرف القانون حيث تسافر.';

  @override
  String get flowLawDesk =>
      'في بعض الدول، يُعدّ رفض فتح قفل جهاز أو إخفاء البيانات عن المسؤولين جريمة في حد ذاته. اعرف القانون حيث تسافر.';

  @override
  String get howWipe =>
      'إن كُتب رمز PIN للمسح على شاشة القفل، يمسح كل محادثة وهويتك وأي تمويه، ثم يغلق Kryfo. ويعمل حتى أثناء إيقاف لوحة الأرقام بعد محاولات خاطئة.';

  @override
  String get howDecoy =>
      'يفتح رمز PIN للتمويه نسخة ثانية فارغة من Kryfo بكلماتها الثلاث الخاصة. وتواصل الرسائل إلى Kryfo الحقيقي الوصول في الخلفية بصمت. وللخروج من التمويه، انتقل إلى تطبيق آخر ثم أدخل رمز PIN الخاص بك.';

  @override
  String get flowNotSet => 'تعذّر التعيين. حاول مرة أخرى.';

  @override
  String get pinsHiddenChats => 'المحادثات المخفية';

  @override
  String get pinsHiddenLine =>
      'تبقى المحادثات التي تختارها بعيدة عن الأنظار حتى تُدخل رمز PIN للمحادثات المخفية: لا في القائمة، ولا في البحث، ولا إشعارات.';

  @override
  String get pinsSetUp => 'إعداد';

  @override
  String get pinsChangeHiddenPin => 'تغيير رمز PIN للمحادثات المخفية';

  @override
  String get pinsHideMoreChats => 'إخفاء محادثات أخرى';

  @override
  String get pinsRemoveHiddenChats => 'إلغاء المحادثات المخفية';

  @override
  String get pinsRemoveHiddenTitle => 'إلغاء المحادثات المخفية؟';

  @override
  String get pinsRemoveHiddenLine =>
      'تعود إلى قائمة محادثاتك، ولا يعود رمز PIN للمحادثات المخفية يفتح شيئًا.';

  @override
  String get pinsTurnOffHiddenFirst =>
      'المحادثات المخفية تحتاج إلى قفل التطبيق. ألغِها أولًا، فتعود إلى قائمة محادثاتك.';

  @override
  String get flowVaultTitle => 'المحادثات المخفية';

  @override
  String get flowVault1 =>
      'اختر محادثات ومجموعات لإخفائها. رمز PIN الخاص بك يفتح Kryfo من دونها. ورمز PIN للمحادثات المخفية يفتح كل شيء، بما فيه المحادثات المخفية.';

  @override
  String get flowVault2 =>
      'ما دامت بعيدة عن الأنظار، لا تُظهر أي إشعار ولا عدّاد. وتواصل رسائلها الوصول وتنتظر، مختومة، رمز PIN للمحادثات المخفية.';

  @override
  String get flowVaultFinger => 'بصمتك تفتح Kryfo من دون المحادثات المخفية.';

  @override
  String get flowVaultDigits =>
      'اجعل رمز PIN الخاص بك أيضًا من ستة أرقام أو أكثر، لأن أي شخص يراقب يمكنه عدّ النقاط.';

  @override
  String get flowVaultReplace =>
      'هذا يستبدل أي محادثات مخفية موجودة على هذا الهاتف.';

  @override
  String get flowVaultReplaceDesk =>
      'هذا يستبدل أي محادثات مخفية موجودة على هذا الحاسوب.';

  @override
  String get flowVaultChoose => 'اختر رمز PIN للمحادثات المخفية';

  @override
  String get flowVaultChooseLine => 'ستة أرقام أو أكثر.';

  @override
  String get flowEnterHiddenPinLine => 'الرمز الذي يفتح محادثاتك المخفية.';

  @override
  String get flowVaultForgetTitle => 'تذكّر رمز PIN هذا';

  @override
  String get flowVaultForget =>
      'إن نسيت رمز PIN هذا، تضيع محادثاتك المخفية إلى الأبد. لا أحد يستطيع استعادتها.';

  @override
  String get flowVaultForgetOk => 'فهمت';

  @override
  String get flowVaultPickTitle => 'اختر محادثات لإخفائها';

  @override
  String get flowVaultPickLine =>
      'ستغادر قائمة محادثاتك الآن. ورمز PIN للمحادثات المخفية يعيدها إلى الظهور.';

  @override
  String flowVaultPickButton(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'إخفاء ⁨$countString⁩ محادثة',
      many: 'إخفاء ⁨$countString⁩ محادثة',
      few: 'إخفاء ⁨$countString⁩ محادثات',
      two: 'إخفاء محادثتين',
      one: 'إخفاء محادثة واحدة',
      zero: 'لا تُخفِ شيئًا الآن',
    );
    return '$_temp0';
  }

  @override
  String get flowVaultPickEmpty => 'لا توجد محادثات لإخفائها بعد.';

  @override
  String get flowVaultBackupTitle => 'إنشاء نسخة احتياطية الآن؟';

  @override
  String get flowVaultBackupLine =>
      'النسخة الاحتياطية التي تُنشأ الآن تضم محادثاتك المخفية أيضًا، بعبارة مرور خاصة بها. إن نسيت رمز PIN للمحادثات المخفية، فهي الطريق الوحيد إليها.';

  @override
  String get flowVaultBackupNow => 'إنشاء نسخة احتياطية';

  @override
  String get flowVaultNotNow => 'ليس الآن';

  @override
  String get flowVaultDone => 'تم إعداد المحادثات المخفية';

  @override
  String get flowVaultDoneLine =>
      'أدخل رمز PIN للمحادثات المخفية على شاشة القفل لتراها. انتقل إلى تطبيق آخر فتعود بعيدة عن الأنظار.';

  @override
  String get flowVaultChanged => 'تم تغيير رمز PIN للمحادثات المخفية';

  @override
  String get flowVaultChangedLine =>
      'تُفتح محادثاتك المخفية الآن بالرمز الجديد. والرمز القديم لم يعد يفتح شيئًا.';

  @override
  String get howVault =>
      'رمز PIN للمحادثات المخفية يفتح Kryfo مع محادثاتك المخفية، ورمز PIN الخاص بك وبصمتك يفتحانه من دونها. إعداد المحادثات المخفية من جديد يستبدل ما على هذا الهاتف منها. وإن نسيت رمز PIN للمحادثات المخفية، تضيع إلى الأبد.';

  @override
  String get howVaultDesk =>
      'رمز PIN للمحادثات المخفية يفتح Kryfo مع محادثاتك المخفية، ورمز PIN الخاص بك يفتحه من دونها. إعداد المحادثات المخفية من جديد يستبدل ما على هذا الحاسوب منها. وإن نسيت رمز PIN للمحادثات المخفية، تضيع إلى الأبد.';

  @override
  String get chatHide => 'إخفاء المحادثة';

  @override
  String get groupHide => 'إخفاء المجموعة';

  @override
  String get chatHidden => 'مخفية';

  @override
  String get chatHiddenToast => 'أُخفيت من قائمة محادثاتك';

  @override
  String get chatShowInList => 'إظهار في قائمة المحادثات';

  @override
  String get stickerOpen => 'الملصقات';

  @override
  String get stickerRecent => 'الأخيرة';

  @override
  String stickerA11y(String emoji) {
    return 'ملصق $emoji';
  }

  @override
  String get stickerRemoveRecent => 'إزالة من الأخيرة';

  @override
  String get stickerCouldNotLoad => 'تعذّر تحميل الملصقات';

  @override
  String get stickerLabel => 'ملصق';

  @override
  String get timedMessageLabel => 'رسالة مؤقتة';

  @override
  String get stickerNewer => 'من إصدار أحدث من Kryfo';

  @override
  String get devLinkMismatch =>
      'يقول هذا الرابط إنه Marios، لكن مفتاحه غير مطابق. لم تتم إضافة شيء.';

  @override
  String get devName => 'Marios';

  @override
  String get devRowTitle => 'Marios · صانع Kryfo';

  @override
  String get devWelcome =>
      'مرحبًا، أنا Marios، أطوّر Kryfo. أخبرني بأي شيء: أخطاء، أفكار، أسئلة. أقرأ كل شيء.';

  @override
  String get devPinned => 'مدمج في Kryfo';

  @override
  String get devAnonymous => 'مجهول الهوية';

  @override
  String get devAboutLine =>
      'مفتاح Marios مدمج في Kryfo. كل رسالة تصل منه تُطابَق مع هذا المفتاح، فلا يستطيع أحد غيره أن يكتب باسمه.';

  @override
  String get devKeyLabel => 'مفتاحه';

  @override
  String get devDeleteLine => 'تُحذف كل رسالة، ولن تعود هذه المحادثة.';

  @override
  String get devDeleteLineAnon =>
      'تُحذف كل رسالة والاسم الذي صُنع لهذه المحادثة، ولن تعود هذه المحادثة.';

  @override
  String get devDeleteLineBack =>
      'تُحذف كل رسالة، ولن تعود هذه المحادثة. وما أرسلته يُسحب من هاتف Marios أيضًا.';

  @override
  String get devDeleteLineAnonBack =>
      'تُحذف كل رسالة والاسم الذي صُنع لهذه المحادثة، ولن تعود هذه المحادثة. وما أرسلته يُسحب من هاتف Marios أيضًا.';

  @override
  String devDeleteNotTakenBack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تعذّر سحب ⁨$count⁩ رسالة من هاتف Marios',
      many: 'تعذّر سحب ⁨$count⁩ رسالة من هاتف Marios',
      few: 'تعذّر سحب ⁨$count⁩ رسائل من هاتف Marios',
      two: 'تعذّر سحب رسالتين من هاتف Marios',
      one: 'تعذّر سحب رسالة واحدة من هاتف Marios',
      zero: 'تعذّر سحب ⁨$count⁩ رسالة من هاتف Marios',
    );
    return '$_temp0';
  }

  @override
  String get devDeleteFailed => 'تعذّر حذف المحادثة. حاول مرة أخرى.';

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
  String get settingsWriteToMarios => 'مراسلة Marios';

  @override
  String get settingsWriteToMariosHint => 'أخطاء، أفكار، أسئلة';

  @override
  String get seenDevChat => 'المحادثة مع Marios';

  @override
  String get seenDevChatCell => 'إن كتبت';

  @override
  String get seenDevChatLine =>
      'لا شيء حتى تكتب. بعدها ما ترسله، وكلماتك الثلاث ما لم تكتب بهوية مجهولة.';

  @override
  String get devWriteAnonymously => 'اكتب بهوية مجهولة';

  @override
  String get devUseMyWords => 'استخدم كلماتي الثلاث';

  @override
  String get devWhoSeesWhat => 'كيف يعمل هذا';

  @override
  String get devWhoWords =>
      'بكلماتك الثلاث، هذه محادثة مثل أي محادثة أخرى: يستطيع Marios أن يرد عليك، ويبقى وجهك وشارة الداعم معك.';

  @override
  String get devWhoAnon =>
      'إن كتبت بهوية مجهولة، يصنع Kryfo اسمًا ومفاتيح جديدة لهذه المحادثة وحدها. تبقى على هذا الهاتف ولا تُستخدم في أي مكان آخر أبدًا.';

  @override
  String get devWhoAnonDesk =>
      'إن كتبت بهوية مجهولة، يصنع Kryfo اسمًا ومفاتيح جديدة لهذه المحادثة وحدها. تبقى على هذا الحاسوب ولا تُستخدم في أي مكان آخر أبدًا.';

  @override
  String get devWhoNothingYet => 'لا يخرج شيء من هاتفك حتى ترسل رسالتك الأولى.';

  @override
  String get devWhoNothingYetDesk =>
      'لا يخرج شيء من حاسوبك حتى ترسل رسالتك الأولى.';

  @override
  String get devWhoChoiceStays => 'يبقى اختيارك مع هذه المحادثة.';

  @override
  String get devUpdateToWrite => 'حدّث Kryfo لتراسل Marios.';

  @override
  String get devKeyCheckFailed => 'تعذّر التحقق من مفتاح Marios. لم يُرسل شيء.';

  @override
  String get devLockLine =>
      'سيقرأ Marios هذه الرسائل. يمكنك أن تكتب المزيد بعد أن يرد.';

  @override
  String get devNewKey => 'لدى Marios مفتاح جديد';

  @override
  String get devStartNewChat => 'ابدأ محادثة جديدة';

  @override
  String get devKeyRetired =>
      'أُوقف هذا المفتاح. لا يمكن إرسال أي شيء أو استلامه هنا بعد الآن.';

  @override
  String get devNamelessLine =>
      'يبقى الاسم الذي صُنع لهذه المحادثة على الهاتف الذي صُنع عليه، لذا يمكن هنا قراءتها فقط.';

  @override
  String get devNamelessLineDesk =>
      'يبقى الاسم الذي صُنع لهذه المحادثة على الجهاز الذي صُنع عليه، لذا يمكن هنا قراءتها فقط.';

  @override
  String get devStartNewLine => 'تُحذف كل رسالة هنا، وتُفتح محادثة جديدة.';

  @override
  String get devVoiceDisguised => 'صوتك مموّه في هذه المحادثة';

  @override
  String get devChatOptions => 'خيارات المحادثة';

  @override
  String get requestsSomeoneNew => 'شخص جديد';

  @override
  String get nameTakenTitle => 'شخص آخر يستخدم هذه الكلمات';

  @override
  String get nameTakenLine =>
      'شخص هنا حصل على هذه الكلمات من طلب أو تعريف أو مجموعة، بمفتاح مختلف، ولم يتحقّق منها أحد. يمكن نسخ الكلمات. إن جاءك هذا الرابط من الشخص الذي تعرفه، فاستخدمه، ثم قارن رقم الأمان معه.';

  @override
  String get nameTakenChatLine =>
      'محادثتك تحت هذه الكلمات جاءت من طلب أو تعريف أو مجموعة، بمفتاح مختلف، ولم يتحقّق منها أحد. يمكن نسخ الكلمات. إن جاءك هذا الرابط من الشخص الذي تعرفه، فاستخدمه: تُحذف تلك المحادثة، وتقارن رقم الأمان في المحادثة الجديدة. لست متأكدًا من مصدر الرابط؟ أبقِ على الموجود.';

  @override
  String get nameTakenDeletedLine =>
      'حذفت محادثة تحت هذه الكلمات، كانت بمفتاح مختلف. إن جاءك هذا الرابط من الشخص الذي تعرفه، فاستخدمه، ثم قارن رقم الأمان معه.';

  @override
  String get nameTakenTombLine =>
      'أزلت من هذا الهاتف شخصًا تحت هذه الكلمات لأنه لم يكن من ادّعى. إن جاءك هذا الرابط من الشخص الذي تعرفه، فاستخدمه، ثم قارن رقم الأمان معه.';

  @override
  String get nameTakenTombLineDesk =>
      'أزلت من هذا الحاسوب شخصًا تحت هذه الكلمات لأنه لم يكن من ادّعى. إن جاءك هذا الرابط من الشخص الذي تعرفه، فاستخدمه، ثم قارن رقم الأمان معه.';

  @override
  String get nameTakenUse => 'استخدم هذا الرابط';

  @override
  String get nameTakenKeep => 'أبقِ على الموجود';

  @override
  String get appYourOwnInvite => 'هذه دعوتك أنت. شاركها مع شخص آخر للتواصل.';

  @override
  String appLinkNeedsUpdate(Object id) {
    return 'يحتاج ⁨$id⁩ إلى تحديث Kryfo قبل أن تتمكنا من إضافة بعضكما.';
  }

  @override
  String appLinkWordsTaken(Object id) {
    return 'هناك من يحمل ⁨$id⁩ هنا بالفعل، بمفتاح مختلف. قارن رقم الأمان معه لتعرف من هو من. لم تتم إضافة شيء.';
  }

  @override
  String appLinkWordsVerified(Object id) {
    return 'لقد تحقّقت من ⁨$id⁩ بمفتاح مختلف. لم تتم إضافة شيء.';
  }

  @override
  String appTheyAreBlocked(Object id) {
    return 'لقد حظرت ⁨$id⁩. ألغِ الحظر من «المحظورون» في الإعدادات لتضيفه من جديد.';
  }

  @override
  String get notThemNumbersDiffer => 'الرقمان مختلفان';

  @override
  String get notThemLine =>
      'إن كان الرقمان مختلفين فعلًا، فربما يستخدم شخص آخر اسمه أو يقف بينكما.';

  @override
  String get notThemButton => 'هذا ليس هو';

  @override
  String get notThemSheetTitle => 'إزالة جهة الاتصال هذه وحظر مفتاحها؟';

  @override
  String get notThemSheetLine =>
      'تُحذف المحادثة ورسائلها وملفاتها من هذا الهاتف. لا يأخذ كلماته الثلاث من جديد إلا رابط أو رمز تضيفه أنت. قارن رقم الأمان مع من تضيفه.';

  @override
  String get notThemSheetLineDesk =>
      'تُحذف المحادثة ورسائلها وملفاتها من هذا الحاسوب. لا يأخذ كلماته الثلاث من جديد إلا رابط أو رمز تضيفه أنت. قارن رقم الأمان مع من تضيفه.';

  @override
  String get notThemRemove => 'إزالة وحظر';

  @override
  String get notThemDone => 'أُزيلت، وحُظر مفتاحها';

  @override
  String get groupAdminGoneLine =>
      'أُزيل مشرفها من هذا الهاتف. لم تعد تغييرات المجموعة تصل إليك.';

  @override
  String get groupAdminGoneLineDesk =>
      'أُزيل مشرفها من هذا الحاسوب. لم تعد تغييرات المجموعة تصل إليك.';

  @override
  String get blockedKey => 'مفتاح محظور';

  @override
  String get appKeyBlocked =>
      'لقد حظرت هذا المفتاح. ألغِ حظره من «المحظورون» في الإعدادات لتضيفه.';

  @override
  String get devLinkGone =>
      'لقد حذفت المحادثة مع Marios. لبدء محادثة جديدة، اضغط «مراسلة Marios» في الإعدادات.';

  @override
  String lockTooManyTriesFor(Object left) {
    return 'محاولات كثيرة جدًا · ⁨$left⁩';
  }

  @override
  String get gifBadge => 'GIF';

  @override
  String get gifPlay => 'تشغيل GIF';

  @override
  String get gifSentInside => 'أُرسلت داخل رسالتك';

  @override
  String get gifOptInTitle => 'ابحث عن صور GIF بخصوصية';

  @override
  String get gifOptInLead =>
      'البحث عن صور GIF يحتاج إلى الإنترنت، لذلك يبقى متوقفًا حتى تريده.';

  @override
  String get gifOptInOverTor => 'بحث عبر Tor';

  @override
  String get gifOptInThroughKryfo => 'بحث عبر Kryfo';

  @override
  String get gifOptInAsksForYou =>
      'خادم Kryfo يسأل خدمة GIF نيابة عنك. الخدمة لا تراك أبدًا، والخادم لا يحتفظ بأي سجل لما بحثت عنه.';

  @override
  String get gifOptInAsksForYouFast =>
      'خادم Kryfo يسأل خدمة GIF نيابة عنك، فلا تراك الخدمة أبدًا. على الوضع السريع يرى خادمنا عنوان IP الخاص بك أثناء البحث، ولا يحتفظ بأي سجل له أو لما بحثت عنه.';

  @override
  String get gifOptInLikeAPhoto =>
      'تنتقل صورة GIF مشفّرة، مثل الصورة. هاتف صديقك لا يجلب شيئًا.';

  @override
  String get gifOptInOffWhenever => 'أوقفه متى شئت';

  @override
  String get gifOptInWhereToTurnOff =>
      'الإعدادات، الخصوصية، البحث عن GIF. صور GIF على هاتفك تعمل دائمًا من دونه.';

  @override
  String get gifOptInWhereToTurnOffDesk =>
      'الإعدادات، الخصوصية، البحث عن GIF. صور GIF على حاسوبك تعمل دائمًا من دونه.';

  @override
  String get gifTurnOn => 'تشغيل البحث عن GIF';

  @override
  String get gifNotNow => 'ليس الآن';

  @override
  String gifAskOverTor(String brand) {
    return 'يمر البحث عن GIF عبر خادم Kryfo من خلال Tor. لا يراك ⁨$brand⁩ أبدًا. هل تريد تشغيله؟';
  }

  @override
  String gifAskThroughKryfo(String brand) {
    return 'يذهب البحث عن GIF مباشرة إلى خادم Kryfo، الذي يرى عنوان IP الخاص بك على الوضع السريع. لا يراك ⁨$brand⁩ أبدًا. هل تريد تشغيله؟';
  }

  @override
  String get gifAskTurnOn => 'تشغيل';

  @override
  String get gifSearchOff => 'البحث عن GIF متوقف';

  @override
  String get gifSavedOnPhone =>
      'صور GIF المحفوظة على هاتفك موجودة في *على هذا الهاتف*.';

  @override
  String get gifSavedOnPhoneDesk =>
      'صور GIF المحفوظة على حاسوبك موجودة في *على هذا الحاسوب*.';

  @override
  String get gifTab => 'صور GIF';

  @override
  String get gifPhoneTab => 'على هذا الهاتف';

  @override
  String get gifPhoneTabDesk => 'على هذا الحاسوب';

  @override
  String get gifSearchHint => 'ابحث عن GIF';

  @override
  String get gifClear => 'مسح البحث';

  @override
  String get gifServiceNeverSeesYou => 'خدمة GIF لا تراك أبدًا';

  @override
  String get gifTrending => 'الأكثر رواجًا';

  @override
  String get gifOffline => 'ما زال Tor يتصل. ستظهر صور GIF فور جاهزيته.';

  @override
  String get gifBusy => 'عمليات بحث كثيرة الآن. حاول مجددًا بعد قليل.';

  @override
  String get gifUnreachable => 'تعذّر الوصول إلى خدمة GIF في Kryfo.';

  @override
  String get gifNothingFound => 'لم يُعثر على صور GIF. جرّب كلمات أخرى.';

  @override
  String get gifCouldNotLoadMore => 'تعذّر تحميل المزيد';

  @override
  String get gifLoading => 'جارٍ تحميل صور GIF';

  @override
  String get gifCouldNotGet => 'تعذّر الحصول على صورة GIF هذه. حاول مجددًا.';

  @override
  String gifPoweredBy(String brand) {
    return 'Powered by $brand';
  }

  @override
  String gifNeverSeesYou(String brand) {
    return 'البحث عبر Kryfo، فلا يراك ⁨$brand⁩ أبدًا.';
  }

  @override
  String gifTileA11y(String number) {
    return 'GIF ⁨$number⁩';
  }

  @override
  String get gifPhoneLine =>
      'صور GIF المحفوظة على هذا الهاتف. لا شيء يتصل بالإنترنت.';

  @override
  String get gifPhoneLineDesk =>
      'صور GIF المحفوظة على هذا الحاسوب. لا شيء يتصل بالإنترنت.';

  @override
  String get gifPhoneChoose => 'اختر صورة GIF';

  @override
  String get settingsGifSearch => 'البحث عن GIF';

  @override
  String get settingsGifSearchHint =>
      'متوقف حتى تشغّله. خادم Kryfo يبحث نيابة عنك، فلا تراك خدمة GIF أبدًا.';

  @override
  String get shareChooseChat => 'اختر محادثة';

  @override
  String get shareNoChats => 'لا توجد محادثات بعد';

  @override
  String get shareNoOne => 'لا يوجد من تشارك معه';

  @override
  String get valveStillConnecting =>
      'ما زال الاتصال جاريًا… ستُرسَل رسائلك فور عودة الاتصال.';

  @override
  String get valveCouldNotReconnect =>
      'تعذّر على Kryfo إعادة الاتصال. إعادة تشغيله تحل المشكلة وتحتفظ برسائلك.';

  @override
  String get valveRestartKryfo => 'إعادة تشغيل Kryfo';

  @override
  String get updateAvailable => 'يتوفر تحديث';

  @override
  String updateReady(String version) {
    return 'Kryfo $version جاهز للتنزيل';
  }

  @override
  String get settingsCheckForUpdates => 'التحقق من التحديثات';

  @override
  String get settingsCheckForUpdatesHint =>
      'مرة واحدة يوميًا عبر Tor. يسأل kryfo.app عن أحدث إصدار ولا يرسل أي شيء عنك.';

  @override
  String get voiceDisguiseHere => 'تمويه صوتي هنا';

  @override
  String get chatBlockScreenshots => 'منع لقطات الشاشة';

  @override
  String get chatShotsWhenTheyUpdate =>
      'متاح عندما يستخدم أحدث إصدار من Kryfo على هاتف';

  @override
  String get chatShotsWhenTheyUpdateDesk => 'متاح في Kryfo لأندرويد';

  @override
  String get chatShotsBothPhones =>
      'يمنع Kryfo لقطات الشاشة وتسجيل الشاشة لهذه المحادثة على الهاتفين، ونسخ رسائل كل منكما أو إعادة توجيهها أو حفظها. لا يستطيع منع التطبيقات المسموح لها بقراءة الشاشة، ولا هاتفًا أو تطبيقًا عُدِّل للالتفاف عليه.';

  @override
  String get chatShotsBlocksBoth =>
      'يمنع لقطات الشاشة وتسجيل الشاشة على الهاتفين، ونسخ رسائل كل منكما أو إعادة توجيهها أو حفظها. لا يستطيع منع التطبيقات المسموح لها بقراءة الشاشة، ولا هاتفًا أو تطبيقًا عُدِّل للالتفاف عليه.';

  @override
  String get chatShotsBlockedHere => 'يمنع Kryfo لقطات الشاشة في هذه المحادثة';

  @override
  String get chatShotsMenuNote =>
      'نسخ رسائله وإعادة توجيهها وحفظها متوقف في هذه المحادثة';

  @override
  String get chatShotsKeptOpen =>
      'فتح ملفاته في تطبيقات أخرى متوقف في هذه المحادثة';

  @override
  String searchKeptMatches(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$countString⁩ نتيجة · افتح المحادثة لرؤيتها',
      many: '⁨$countString⁩ نتيجة · افتح المحادثة لرؤيتها',
      few: '⁨$countString⁩ نتائج · افتح المحادثة لرؤيتها',
      two: 'نتيجتان · افتح المحادثة لرؤيتهما',
      one: 'نتيجة واحدة · افتح المحادثة لرؤيتها',
      zero: '⁨$countString⁩ نتيجة · افتح المحادثة لرؤيتها',
    );
    return '$_temp0';
  }

  @override
  String get savedKeptInChat =>
      'محفوظة من محادثة تمنع لقطات الشاشة · افتح المحادثة لرؤيتها';

  @override
  String get roomShotsMenuNote =>
      'نسخ رسائل الآخرين وإعادة توجيهها وحفظها متوقف في هذه الغرفة';

  @override
  String get roomShotsKeptOpen =>
      'فتح ملفات الآخرين في تطبيقات أخرى متوقف في هذه الغرفة';

  @override
  String get chatShotsYouTurnedOn =>
      'فعّلت منع لقطات الشاشة. نسخ رسائل كل منكما وإعادة توجيهها وحفظها متوقف أيضًا.';

  @override
  String get chatShotsYouTurnedOff => 'أوقفت منع لقطات الشاشة';

  @override
  String get chatNowPostQuantum =>
      'الرسائل في هذه المحادثة تستخدم الآن تشفيرًا ما بعد الكم';

  @override
  String chatShotsTheyTurnedOn(String name) {
    return 'فعّل ⁨$name⁩ منع لقطات الشاشة. نسخ رسائل كل منكما وإعادة توجيهها وحفظها متوقف أيضًا.';
  }

  @override
  String chatShotsTheyTurnedOff(String name) {
    return 'أوقف ⁨$name⁩ منع لقطات الشاشة';
  }

  @override
  String get roomShotsBlocked =>
      'يمنع Kryfo لقطات الشاشة وتسجيل الشاشة لهذه الغرفة على كل هاتف فيها، ونسخ رسائل الآخرين أو إعادة توجيهها أو حفظها. لا يستطيع منع التطبيقات المسموح لها بقراءة الشاشة، ولا هاتفًا أو تطبيقًا عُدِّل للالتفاف عليه.';

  @override
  String get roomShotsBlockedDesk =>
      'نسخ رسائل بعضكم وإعادة توجيهها وحفظها متوقف في هذه الغرفة. ويمنع Kryfo لأندرويد أيضًا لقطات الشاشة وتسجيلها.';

  @override
  String get roomShotsAlwaysOn => 'مفعّل دائمًا في الغرفة، على كل هاتف فيها';

  @override
  String get roomShotsAlwaysOnDesk =>
      'مفعّل دائمًا في الغرفة، في Kryfo لأندرويد';

  @override
  String get settingsPerChat => 'حسب المحادثة';

  @override
  String get homeShotsPerChat => 'منع لقطات الشاشة صار لكل محادثة على حدة.';

  @override
  String get homeShotsTurnOnForAll => 'هل تريد تفعيله في كل محادثاتك؟';

  @override
  String get homeShotsTurnOn => 'تفعيل للكل';

  @override
  String get homeShotsLeaveOff => 'اتركه متوقفًا';

  @override
  String get homeShotsTheySeeIt =>
      'يمنعها Kryfo على الهاتف الآخر أيضًا، ويتوقف نسخ رسائل كل منكما وإعادة توجيهها وحفظها. سيرى الطرف الآخر أنك فعّلته.';

  @override
  String homeShotsTurnedOn(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'يمنع Kryfo الآن لقطات الشاشة في ⁨$countString⁩ محادثة',
      many: 'يمنع Kryfo الآن لقطات الشاشة في ⁨$countString⁩ محادثة',
      few: 'يمنع Kryfo الآن لقطات الشاشة في ⁨$countString⁩ محادثات',
      two: 'يمنع Kryfo الآن لقطات الشاشة في محادثتين',
      one: 'يمنع Kryfo الآن لقطات الشاشة في محادثة واحدة',
      zero: 'يمنع Kryfo الآن لقطات الشاشة في ⁨$countString⁩ محادثة',
    );
    return '$_temp0';
  }

  @override
  String get voiceDisguisedHere => 'صوتك مموّه في هذه المحادثة';

  @override
  String get voiceSlideUpToLock => 'اسحب لأعلى للقفل';

  @override
  String get voiceStopRecording => 'إيقاف التسجيل';

  @override
  String get voiceDeleteNote => 'حذف الرسالة الصوتية';

  @override
  String get voiceDisguised => 'مموّه';

  @override
  String get voiceYourVoice => 'صوتك';

  @override
  String get voiceDisguiseThisNote => 'تمويه هذه الرسالة';

  @override
  String get voiceNotDisguised => 'تعذّر تمويه هذه الرسالة، لذا لم تُرسل';

  @override
  String get voiceNoRoom =>
      'لا توجد مساحة فارغة كافية على هذا الهاتف. أفرغ بعض المساحة ثم حاول مجددًا.';

  @override
  String get voiceNoRoomDesk =>
      'لا توجد مساحة فارغة كافية على هذا الحاسوب. أفرغ بعض المساحة ثم حاول مجددًا.';

  @override
  String get voiceNoRoomNotSent =>
      'لم تكن هناك مساحة كافية لتمويه هذه الرسالة، لذا لم تُرسل';

  @override
  String get voiceDisguising => 'جارٍ التمويه';

  @override
  String get voiceLockedNotSent =>
      'قُفل Kryfo قبل أن تُرسل رسالتك الصوتية، لذا لم تُرسل';

  @override
  String get voiceNotSent => 'لم تُرسل رسالتك الصوتية';

  @override
  String get settingsDisguiseByDefault => 'تمويه صوتي افتراضيًا';

  @override
  String get settingsDisguiseByDefaultHint =>
      'يمكن لكل محادثة تغييره من قائمتها';

  @override
  String get fileInstallerLine =>
      'هذا ملف لتثبيت تطبيق. لا تثبّت التطبيقات إلا من أشخاص تثق بهم.';

  @override
  String get fileAppInstaller => 'ملف تثبيت تطبيق';

  @override
  String get fileSaveToDevice => 'حفظ على الجهاز';

  @override
  String get fileOpenHint => 'يُفتح في تطبيق آخر';

  @override
  String get fileSaved => 'حُفظ';

  @override
  String fileSavedIn(String place) {
    return 'حُفظ في ⁨$place⁩';
  }

  @override
  String get fileSavedUnchecked =>
      'حُفظ، لكن Kryfo لم يتمكن من التحقق من النسخة';

  @override
  String get fileNotSaved => 'تعذّر حفظ الملف';

  @override
  String get fileNotSavedNoSpace => 'لم يُحفظ: لا توجد مساحة كافية هناك';

  @override
  String fileTooBig(String size, String max) {
    return 'حجم هذا الملف ⁨$size⁩. الحد الأقصى للملفات ⁨$max⁩.';
  }

  @override
  String get fileGoesAsItIs =>
      'سيُرسل هذا الملف كما هو تمامًا. ينظّف Kryfo ملفات JPEG وPNG وWebP وHEIC وAVIF وGIF وMP4 وMOV فقط.';

  @override
  String get fileRawPictureTitle => 'إرسال هذه الصورة كما هي؟';

  @override
  String get fileRawPictureLine =>
      'لا يمكن تنظيف هذه الصورة. تُرسل معها تفاصيل مثل مكان التقاطها. أرسلها كصورة عادية لتنظيفها.';

  @override
  String get voiceStoppedAtLimit =>
      'تتوقف الرسائل الصوتية عند ٣٠ دقيقة. استمع إليها ثم أرسلها.';

  @override
  String get gettingMessagesHelperBody =>
      'فوري وخفيف. يرى خادمه عنوان IP الخاص بك ومتى تصل الرسائل، ولا يرى أبدًا ما فيها.';

  @override
  String get gettingMessagesHelperUseOnion => 'التبديل إلى Onion';

  @override
  String get gettingMessagesHelperSetUp => 'إعداد';

  @override
  String get gettingMessagesHelperNote =>
      'تُخلط إيقاظات زائفة بالحقيقية، فيصعب على خادم التطبيق المساعد معرفة متى تصل الرسائل الحقيقية. خادم مساعد خاص بك يُعلم مُرحِّلنا بعنوانه. المحادثات المخفية، والغرف بعد الأوائل منها، وأحيانًا جهة اتصال عادية، نحو شهر من كل خمسة، تنتظر التفقّد الذي يواصل Kryfo إجراءه كل ١٥ دقيقة.';

  @override
  String get gettingMessagesHelperOnionOnly => 'متاح على مسار Onion';

  @override
  String get gettingMessagesHelperChecking => 'جارٍ التحقق…';

  @override
  String get gettingMessagesHelperRelayNotYet => 'لا يقدّم مُرحِّلنا هذا بعد';

  @override
  String get helperSheetNeedTitle => 'تحتاج إلى تطبيق مساعد';

  @override
  String get helperSheetNeedLine =>
      'يحتفظ التطبيق المساعد باتصال خفيف واحد لكل تطبيقاتك ويوقظ Kryfo حين يصل شيء. يصلح أي تطبيق UnifiedPush، وntfy بداية جيدة.';

  @override
  String get helperSheetGetNtfy => 'احصل على ntfy';

  @override
  String get helperSheetOtherApps => 'تطبيقات مساعدة أخرى';

  @override
  String get helperSheetPickTitle => 'اختر تطبيقًا مساعدًا';

  @override
  String get helperSheetPickLine =>
      'لا يطلب Kryfo منه إلا إيقاظ التطبيق. لا تمر رسائلك عبره أبدًا.';

  @override
  String helperSheetSetUp(Object name) {
    return 'تم إعداد ⁨$name⁩';
  }

  @override
  String helperSheetNoAnswer(Object name) {
    return 'لم يستجب ⁨$name⁩. حاول مرة أخرى.';
  }

  @override
  String get homeHelperGoneTitle => 'تطبيقك المساعد لم يعد موجودًا';

  @override
  String get homeHelperGoneLine =>
      'يتفقّد Kryfo كل ١٥ دقيقة إلى أن تختار طريقة أخرى.';

  @override
  String get homeHelperGoneChoose => 'اختر طريقة أخرى';

  @override
  String get homeHelperRelayTitle => 'لم يعد المُرحِّل يوقظ Kryfo';

  @override
  String get gettingMessagesHelperRefused =>
      'لا يقبل مُرحِّلنا الآن بعض تسجيلات هذا الهاتف. تصل تلك المحادثات مع التفقّد كل ١٥ دقيقة، ويواصل Kryfo المحاولة. قد يفيد أيضًا اختيار تطبيق مساعد أو خادم آخر.';

  @override
  String albumLabel(Object count) {
    return 'ألبوم · العناصر: ⁨$count⁩';
  }

  @override
  String albumCounter(Object at, Object total) {
    return '⁨$at⁩ من ⁨$total⁩';
  }

  @override
  String albumMore(Object count) {
    return '⁨$count⁩ إضافية';
  }

  @override
  String get albumOnItsWay => 'في الطريق';

  @override
  String get albumQuoted => 'ألبوم';

  @override
  String get albumUnsendTitle => 'سحب هذا الألبوم؟';

  @override
  String get mediaSendAddMore => 'إضافة المزيد';

  @override
  String get mediaSendRemove => 'إزالة';

  @override
  String get mediaSendProtect => 'حماية من لقطات الشاشة';

  @override
  String get mediaSendProtectedOn => 'محمية · لقطات الشاشة محظورة';

  @override
  String mediaSendUpTo(Object count) {
    return 'حتى ⁨$count⁩ في المرة الواحدة';
  }

  @override
  String get mediaSendVideo => 'إرسال الفيديو';

  @override
  String mediaSendUntilAccepted(Object count) {
    return 'حتى يقبل، يمكن إرسال ⁨$count⁩';
  }

  @override
  String get groupEndedYou => 'أنهيت هذه المجموعة';

  @override
  String groupEndedBy(Object name) {
    return 'أنهى ⁨$name⁩ هذه المجموعة';
  }

  @override
  String get groupEndedBar => 'انتهت هذه المجموعة';

  @override
  String get groupInfoEndGroup => 'إنهاء المجموعة';

  @override
  String get groupInfoEndThisGroup => 'إنهاء هذه المجموعة للجميع؟';

  @override
  String get groupInfoEndGroupLine =>
      'تُحذف للجميع: تُزال رسائلها ووسائطها من هاتف كل عضو حدّث التطبيق.';

  @override
  String get groupInfoEndGroupLineDesk =>
      'تُحذف للجميع: تُزال رسائلها ووسائطها من جهاز كل عضو حدّث التطبيق.';

  @override
  String get groupInfoDeleteGroup => 'حذف المجموعة';

  @override
  String get groupInfoDeleteThisGroup => 'حذف هذه المجموعة؟';

  @override
  String get groupInfoDeleteGroupLine =>
      'تختفي المجموعة المنتهية من قائمة محادثاتك.';

  @override
  String get groupEndedOldNotice =>
      'أنهيت هذه المجموعة، فلم يعد أحد يستطيع الإرسال فيها. حدّث Kryfo لتراها منتهية.';

  @override
  String get groupInfoEndGroupDetail =>
      'يزيلها Kryfo من هاتف كل عضو لديه التحديث.';

  @override
  String get groupInfoEndGroupDetailDesk =>
      'يزيلها Kryfo من جهاز كل عضو لديه التحديث.';

  @override
  String get translateAction => 'ترجمة';

  @override
  String get translateShowOriginal => 'عرض الأصل';

  @override
  String translateBarTo(Object language) {
    return 'ترجمة إلى $language';
  }

  @override
  String get translateBarMore => 'خيارات الترجمة';

  @override
  String translateBarNever(Object language) {
    return 'عدم اقتراح الترجمة من $language';
  }

  @override
  String get translateBarHide => 'إخفاء في هذه المحادثة';

  @override
  String get translateWorking => 'جارٍ الترجمة…';

  @override
  String get translateFailed => 'تعذّرت الترجمة';

  @override
  String translateFrom(Object language) {
    return 'تُرجمت من $language';
  }

  @override
  String get translateLangZh => 'الصينية';

  @override
  String translatePackTitle(Object language) {
    return 'الترجمة على هذا الهاتف: $language';
  }

  @override
  String translatePackTitleDesk(Object language) {
    return 'الترجمة على هذا الحاسوب: $language';
  }

  @override
  String translatePackLine(Object language, Object size) {
    return 'تُترجم الرسائل على هذا الهاتف ولا تغادره أبدًا. يتطلب ذلك حزمة اللغة $language، بحجم $size تقريبًا، تُنزَّل مرة واحدة عبر Tor.';
  }

  @override
  String translatePackLineDesk(Object language, Object size) {
    return 'تُترجم الرسائل على هذا الحاسوب ولا تغادره أبدًا. يتطلب ذلك حزمة اللغة $language، بحجم $size تقريبًا، تُنزَّل مرة واحدة عبر Tor.';
  }

  @override
  String get translatePackNoLib => 'الترجمة لا تعمل على هذا الهاتف.';

  @override
  String get translatePackNoLibDesk => 'الترجمة لا تعمل على هذا الحاسوب.';

  @override
  String translateDownload(Object size) {
    return 'تنزيل · نحو $size';
  }

  @override
  String get translateDownloadAnyway => 'نزّلها الآن على أي حال';

  @override
  String get translateResume => 'متابعة التنزيل';

  @override
  String translateProgress(Object done, Object total) {
    return '$done من $total';
  }

  @override
  String get translateFinishing => 'جارٍ فحص الملفات…';

  @override
  String translateInstalled(Object size) {
    return 'على هذا الهاتف · $size';
  }

  @override
  String translateInstalledDesk(Object size) {
    return 'على هذا الحاسوب · $size';
  }

  @override
  String get translateNeedsWifi =>
      'خيار «عبر Wi-Fi فقط» مفعّل، وهذا الهاتف غير متصل بشبكة Wi-Fi.';

  @override
  String get translateNeedsWifiDesk =>
      'خيار «عبر Wi-Fi فقط» مفعّل، وهذا الحاسوب غير متصل بشبكة Wi-Fi.';

  @override
  String get translateFailNoTor =>
      'لم يتصل Tor بعد. تُنزَّل الحزم عبر Tor فقط، فحاول مجددًا بعد اتصاله.';

  @override
  String get translateFailNetwork =>
      'توقف التنزيل. حاول مجددًا وسيكمل من حيث توقف.';

  @override
  String get translateFailBadFile =>
      'لم يطابق أحد الملفات ما يتوقعه Kryfo فتم التخلص منه. حاول مجددًا.';

  @override
  String get translateFailNoEngine => 'لا يمكن تنزيل حزم اللغة على هذا الهاتف.';

  @override
  String get translateFailNoEngineDesk =>
      'لا يمكن تنزيل حزم اللغة على هذا الحاسوب.';

  @override
  String translatePaused(Object size) {
    return 'متوقف مؤقتًا · $size حتى الآن';
  }

  @override
  String get translateSettingsTitle => 'الترجمة';

  @override
  String get translateSettingsRow => 'ترجمة الرسائل';

  @override
  String get translateSettingsHint => 'على هذا الهاتف، لا على خادم أبدًا';

  @override
  String get translateSettingsHintDesk => 'على هذا الحاسوب، لا على خادم أبدًا';

  @override
  String get translatePacksSection => 'حزم اللغة';

  @override
  String translatePackPair(Object language) {
    return '$language والإنجليزية';
  }

  @override
  String translateNotDownloaded(Object size) {
    return 'غير مُنزَّلة · نحو $size';
  }

  @override
  String get translateDownloading => 'جارٍ التنزيل عبر Tor';

  @override
  String translateDeleteTitle(Object language) {
    return 'حذف حزمة $language؟';
  }

  @override
  String translateDeleteLine(Object language) {
    return 'لن تُترجم الرسائل باللغة $language حتى تُنزَّل الحزمة من جديد.';
  }

  @override
  String get translateLanguagesSection => 'اللغات';

  @override
  String get translateMyLanguages => 'لغات أقرؤها';

  @override
  String get translateMyLanguagesHint =>
      'لا تُعرض ترجمة الرسائل المكتوبة بهذه اللغات. لغة التطبيق دائمًا من بينها.';

  @override
  String get translateInto => 'الترجمة إلى';

  @override
  String get translateAppLanguage => 'لغة التطبيق';

  @override
  String get translateBehaviourSection => 'التنزيلات والمحادثات';

  @override
  String get translateAutoDefault => 'ترجمة المحادثات تلقائيًا';

  @override
  String get translateAutoDefaultHint =>
      'للمحادثات التي لم تضبطها بنفسك. يمكن لكل محادثة تشغيلها أو إيقافها.';

  @override
  String get translateWifiOnly => 'تنزيل الحزم عبر Wi-Fi فقط';

  @override
  String get translatePrivacyTitle => 'ما يبقى خاصًا';

  @override
  String get translatePrivacyNote =>
      'تتم الترجمة على هذا الهاتف. لا تُرسل أي رسالة إلى أي مكان لترجمتها. تنزيل حزمة يُخبر الخادم أي حزمة هي. يتم التنزيل عبر Tor، فلا يعرف الخادم من طلبها.';

  @override
  String get translatePrivacyNoteDesk =>
      'تتم الترجمة على هذا الحاسوب. لا تُرسل أي رسالة إلى أي مكان لترجمتها. تنزيل حزمة يُخبر الخادم أي حزمة هي. يتم التنزيل عبر Tor، فلا يعرف الخادم من طلبها.';

  @override
  String get translateAutoInChat => 'ترجمة تلقائية';

  @override
  String get translateAutoInChatHint =>
      'تظهر الرسائل المكتوبة بلغات أخرى مترجمة. الأصل على بُعد لمسة واحدة.';

  @override
  String get translateAlwaysChat => 'ترجمة هذه المحادثة دائمًا';

  @override
  String translateNeverDone(Object language) {
    return 'تبقى الرسائل كما هي · $language';
  }

  @override
  String get translateUndo => 'تراجع';

  @override
  String get translateNeverSection => 'لا تُقترح أبدًا';

  @override
  String get translateOfferAgain => 'الاقتراح مجددًا';

  @override
  String get translateOnHint => 'تُقترح أسفل الرسائل المكتوبة بلغات أخرى';

  @override
  String get translatePrivacyKept =>
      'تُحفظ الترجمات مشفّرة مع محادثتها على هذا الهاتف وتُحذف معها.';

  @override
  String get translatePrivacyKeptDesk =>
      'تُحفظ الترجمات مشفّرة مع محادثتها على هذا الحاسوب وتُحذف معها.';

  @override
  String get translateOffDeletes => 'إيقاف هذا يحذف الترجمات المحفوظة.';

  @override
  String get bridgesNoneUntilOnion => 'لا شيء حتى تشغيل Onion';

  @override
  String get bridgesRelayThisNetworkSees =>
      'يتجاوز الوضع السريع حجب Tor، لكن هذه الشبكة يمكنها أن ترى اتصالك بـ Kryfo.';

  @override
  String get settingsLicences => 'التراخيص';

  @override
  String get settingsLicencesValue => 'مما صُنع Kryfo';

  @override
  String get licencesKryfoLine =>
      'Kryfo برنامج حر بموجب رخصة جنو العمومية العامة، الإصدار 3 أو أحدث. يمكن لأي شخص قراءة شيفرته وتعديلها ومشاركتها.';

  @override
  String get licencesSourceCode => 'الشيفرة المصدرية';

  @override
  String get licencesSignalTitle => 'بروتوكول Signal';

  @override
  String licencesSignalLine(String version) {
    return 'يتضمن Kryfo مكتبة libsignal ⁨$version⁩ من صنع Signal، بموجب رخصة جنو أفيرو العمومية العامة، الإصدار 3. شيفرتها المصدرية على github.com/signalapp/libsignal وبجانب كل إصدار من Kryfo.';
  }

  @override
  String get licencesAgplText => 'النص الكامل لرخصة GNU AGPL 3.0';

  @override
  String get licencesSignalSource => 'الشيفرة المصدرية لمكتبة libsignal';

  @override
  String get licencesParts => 'مكوّنات مفتوحة المصدر';

  @override
  String get licencesInSignal => 'في مكتبة Signal';

  @override
  String get licencesInApp => 'في التطبيق';

  @override
  String licencesPartCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$countString⁩ مكوّن',
      many: '⁨$countString⁩ مكوّنًا',
      few: '⁨$countString⁩ مكوّنات',
      two: 'مكوّنان',
      one: 'مكوّن واحد',
      zero: 'لا مكوّنات',
    );
    return '$_temp0';
  }

  @override
  String get licencesGplText => 'النص الكامل لرخصة GNU GPL 3.0';

  @override
  String get licencesInEngine => 'في محرّك الشبكة';

  @override
  String get licencesLoadFailed => 'تعذّر التحميل';

  @override
  String get settingsCopyLinkHint => 'نسخ الرابط';

  @override
  String get motionNoRelayYet => 'لا مُرحِّل بعد';

  @override
  String get motionTheRouteIsUp => 'المسار قائم';

  @override
  String get motionMessagesGoOnceARelay =>
      'تُرسَل الرسائل حالما يستجيب مُرحِّل عبر هذا المسار.';

  @override
  String get motionOffline => 'غير متصل';

  @override
  String get motionNoNetwork => 'لا توجد شبكة';

  @override
  String get motionTorPicksUpAgain =>
      'لا يُرسَل شيء بلا شبكة. يواصل Tor حالما تعود.';

  @override
  String deliveryModeStateLast(String state, Object last) {
    return '⁨$state⁩ · ⁨$last⁩';
  }

  @override
  String homeWaitingState(int count, String state) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$count⁩ في الانتظار · ⁨$state⁩',
    );
    return '$_temp0';
  }

  @override
  String get settingsIconAndNotifications => 'الأيقونة والإشعارات';

  @override
  String iconSettingsValue(String icon) {
    return '$icon، إشعارات بسيطة';
  }

  @override
  String get iconSectionTitle => 'أيقونة التطبيق';

  @override
  String get iconHint =>
      'تعرض شاشتك الرئيسية وقائمة تطبيقاتك هذه الأيقونة وهذا الاسم بدل Kryfo.';

  @override
  String get iconHintKryfo =>
      'اختر أيقونة واسمًا عاديين لشاشتك الرئيسية وقائمة تطبيقاتك.';

  @override
  String get iconWhatChanges => 'ما الذي يغيّره هذا';

  @override
  String iconConfirmTitle(String name) {
    return 'تغيير الأيقونة إلى $name؟';
  }

  @override
  String iconConfirmLine(String name) {
    return 'يُغلق Kryfo ثم يفتح من جديد. إذا اختفت الأيقونة من شاشتك الرئيسية، فابحث عن $name بين تطبيقاتك وضعها في مكانها من جديد.';
  }

  @override
  String get iconConfirmButton => 'تغيير الأيقونة';

  @override
  String get iconNoPinLine =>
      'من ينقر عليها يرى Kryfo. عيّن رمز PIN للتطبيق ليرى لوحة الرمز بدلًا من ذلك.';

  @override
  String get iconSetPin => 'تعيين رمز PIN';

  @override
  String iconChanged(String name) {
    return 'تغيّرت الأيقونة إلى $name';
  }

  @override
  String iconPreviewLabel(String name) {
    return 'ستعرض شاشتك الرئيسية $name';
  }

  @override
  String iconButtonLabel(String name) {
    return '$name، أيقونة التطبيق';
  }

  @override
  String get notifShowAll => 'الاسم والرسالة';

  @override
  String get notifShowNew => 'فقط «رسالة جديدة»';

  @override
  String get notifShowPlain => 'بسيطة';

  @override
  String get notifPlainHint =>
      'بلا اسم، بلا رسالة، بلا ألوان Kryfo. أيقونة محايدة وسطر واحد.';

  @override
  String get notifPlainLine => 'شيء جديد';

  @override
  String get notifPlainChannel => 'تنبيهات';

  @override
  String get notifHeaderLimit =>
      'يبقى أعلى كل إشعار يقول Kryfo. لا يسمح Android لأي تطبيق بتغيير ذلك.';

  @override
  String get gettingMessagesWhatShows => 'ما تعرضه الإشعارات';

  @override
  String get iconSheetChangesTitle => 'ما الذي يتغيّر';

  @override
  String get iconSheetChanges =>
      'الأيقونة والاسم على شاشتك الرئيسية وفي قائمة تطبيقاتك، وقائمة المشاركة، وشاشة التطبيقات المفتوحة. ومع «بسيطة»، ما تعرضه الإشعارات.';

  @override
  String get iconSheetStaysTitle => 'ما يبقى Kryfo';

  @override
  String get iconSheetStays =>
      'السطر الأعلى من كل إشعار، وصفحات الإعدادات والبطارية في هاتفك، ومتجر التطبيقات، وKryfo نفسه حين يفتحه أحد.';

  @override
  String get iconSheetGlance =>
      'يصمد أمام نظرة سريعة إلى شاشتك الرئيسية. لا يخفي Kryfo عمّن يتصفح إعدادات هاتفك.';

  @override
  String get iconSheetPrivateSpace =>
      'قد تكون لهاتفك طريقته الخاصة لإخفاء التطبيقات: المساحة الخاصة، في إعداداته.';

  @override
  String get iconSheetSecureFolder =>
      'قد تكون لهاتفك طريقته الخاصة لإخفاء التطبيقات: المجلد الآمن، في إعداداته.';

  @override
  String get iconSheetXiaomi =>
      'قد تكون لهاتفك طريقته الخاصة لإخفاء التطبيقات: التطبيقات المخفية، في إعداداته.';

  @override
  String get androidIconNotes => 'ملاحظات';

  @override
  String get androidIconWeather => 'الطقس';

  @override
  String get androidIconTasks => 'مهام';

  @override
  String get androidIconNews => 'أخبار';

  @override
  String get androidServiceTitlePlain => 'نشط';

  @override
  String get lockStateUnlockPlain => 'فتح القفل';

  @override
  String get iconSheetOthers =>
      'لا تزال التطبيقات على هاتفك قادرة على معرفة أن Kryfo مثبّت، وقد تعرض نوافذ Android وطلباته الخاصة اسمه.';

  @override
  String get iconSheetSaves =>
      'ما دامت أيقونة بسيطة مفعّلة، تُحفظ الصور والفيديوهات والملفات الجديدة بأسماء عادية في مجلدات هاتفك المعتادة. وما حُفظ من قبل يبقى في مكانه.';

  @override
  String get deliveryModeGooglePush => 'إشعارات Google الفورية';

  @override
  String get deliveryModeGoogle => 'Google';

  @override
  String get notificationsLead =>
      'كيف تصل الرسائل الجديدة إلى هذا الهاتف، وما صوتها وما تعرضه. يمكنك تغيير ذلك متى شئت.';

  @override
  String get notificationsLeadDesk =>
      'كيف تصل الرسائل الجديدة إلى هذا الحاسوب، وما صوتها وما تعرضه. يمكنك تغيير ذلك متى شئت.';

  @override
  String get notificationsHowTheyReachYou => 'كيف تصلك الرسائل';

  @override
  String get notificationsRecommended => 'مُوصى به';

  @override
  String get notificationsGoogleBody =>
      'فوري وخفيف. يمكن لـ Google أن ترى متى يُوقَظ هاتفك، ولا ترى أبدًا من كتب أو ماذا قيل.';

  @override
  String get notificationsGoogleStarting => 'جارٍ التشغيل…';

  @override
  String get notificationsGoogleNoStart =>
      'تعذّر تشغيل إشعارات Google الفورية. تحقّق من الاتصال وحاول مرة أخرى.';

  @override
  String get notificationsGoogleNote =>
      'تُخلط إيقاظات زائفة بالحقيقية، فيصعب على Google معرفة متى تصل الرسائل الحقيقية. لا يخزّن مُرحِّلنا إلا عناوين لا يستطيع الربط بينها. تعمل خدمة الإشعارات الفورية على الخادم نفسه ويمكنها الربط بينها، وبمساعدة Google بحسابك على Google أيضًا، لذا يستطيع ذلك أيضًا من يدير خادمنا أو يصادره. إن كان هذا يهمّك، فاختر طريقة أخرى. المحادثات المخفية، والغرف بعد الأوائل منها، وأحيانًا جهة اتصال عادية، نحو شهر من كل خمسة، تنتظر التفقّد الذي يواصل Kryfo إجراءه كل ١٥ دقيقة.';

  @override
  String get notificationsGoogleRefused =>
      'لا يقبل مُرحِّلنا الآن بعض تسجيلات هذا الهاتف. تصل تلك المحادثات مع التفقّد كل ١٥ دقيقة، ويواصل Kryfo المحاولة.';

  @override
  String get notificationsSoundAndVibration => 'الصوت والاهتزاز';

  @override
  String get notificationsSoundHint => 'في إعدادات أندرويد نفسه';

  @override
  String get notificationsEachShows => 'يعرض كل إشعار';

  @override
  String get notificationsBatteryTips => 'نصائح للبطارية';

  @override
  String get notificationsBatteryAllowed => 'مسموح';

  @override
  String get notificationsBatteryNotYet => 'غير مسموح';

  @override
  String get notificationsMakerSwitch => 'مفتاح الشركة المصنّعة لهاتفك';

  @override
  String get onboardingDeliveryHeadline => 'كيف *تصلك* الرسائل.';

  @override
  String get onboardingDeliveryLead =>
      'يمكنك تغيير ذلك في أي وقت من «الإشعارات».';

  @override
  String get homeGoogleTitle => 'وصلت إشعارات Google الفورية';

  @override
  String get homeGoogleLine =>
      'فورية ورفيقة بالبطارية. يمكن لـ Google أن ترى متى يُوقَظ هاتفك، ولا ترى أبدًا من كتب أو ماذا قيل.';

  @override
  String get homeGoogleUse => 'استخدمها';

  @override
  String get homeGoogleOn => 'إشعارات Google الفورية مفعّلة';

  @override
  String get homeGoogleGoneTitle => 'إشعارات Google الفورية غير متاحة';

  @override
  String get appNotificationsLink => 'الإشعارات ←';

  @override
  String devGooglePushes(int got, int low) {
    return 'إشعارات Google ‏$got · خُفّضت $low';
  }

  @override
  String get passFieldLabel => 'عبارة المرور';

  @override
  String get padUseLetters => 'استخدام الحروف';

  @override
  String get padUseDigits => 'استخدام الأرقام';

  @override
  String get passWeak => 'ضعيفة';

  @override
  String get passFair => 'مقبولة';

  @override
  String get passStrong => 'قوية';

  @override
  String passStrengthIs(Object level) {
    return 'القوة: ⁨$level⁩';
  }

  @override
  String get lockKeyBusy =>
      'شريحة الأمان في هاتفك مشغولة الآن. حاول مرة أخرى بعد لحظة.';

  @override
  String get lockKeyLocked =>
      'افتح قفل هاتفك مرة واحدة برمز PIN الخاص به، ثم حاول مرة أخرى.';

  @override
  String get lockKeyWaiting => 'ما زالت شريحة الأمان في الهاتف تتحقق';

  @override
  String get lockKeyLost =>
      'فقد هذا الهاتف المفتاح الذي يتحقق من رموز PIN الخاصة بك، لذا قد لا تفتح بعض الرموز. يمكن إعادة ضبط Kryfo واستعادة نسخة احتياطية.';

  @override
  String get lockKeyReset => 'إعادة ضبط Kryfo';

  @override
  String get lockKeyResetTitle => 'إعادة ضبط Kryfo؟';

  @override
  String get lockKeyResetLine =>
      'يُحذف كل ما في Kryfo على هذا الهاتف ويُغلق Kryfo. بعد ذلك يمكنك استعادة نسخة احتياطية. لا تعود المحادثات المخفية إلا من نسخة احتياطية أُنشئت وهي مفتوحة.';

  @override
  String get lockKeyResetSureTitle => 'لا يمكن التراجع عن هذا';

  @override
  String get lockKeyResetSureLine =>
      'تُحذف الآن كل المحادثات والمفاتيح والإعدادات في Kryfo على هذا الهاتف.';

  @override
  String get lockKeyResetSure => 'حذف كل شيء';

  @override
  String get flowVaultPassLine =>
      '١٢ حرفًا على الأقل. لوحة مفاتيح الهاتف ترى ما تكتبه، لذا استخدم لوحة لا تتعلم الكلمات ولا تزامنها.';

  @override
  String get flowVaultPassLineDesk =>
      '١٢ حرفًا على الأقل. استخدم عبارة لا تستخدمها في أي مكان آخر.';

  @override
  String get flowVaultPassAgain => 'عبارة المرور نفسها مرة أخرى';

  @override
  String get cardTitle => 'أكمِل تحديث الأمان';

  @override
  String get cardLine =>
      'إن كنت تستخدم رموز PIN أخرى، فاكتب كل رمز منها هنا مرة واحدة.';

  @override
  String get cardType => 'اكتب رمز PIN';

  @override
  String get cardAnswer => 'تم. اكتب رمزًا آخر، أو اضغط تم عندما تنتهي.';

  @override
  String get keyLine =>
      'تعمل رموز PIN الخاصة بك على هذا الهاتف فقط. إن فقد الهاتف يومًا المفتاح الذي يتحقق منها، فسيلزمك إعادة ضبط Kryfo واستعادة نسخة احتياطية. لا تعود المحادثات المخفية إلا من نسخة احتياطية أُنشئت وهي مفتوحة.';

  @override
  String get keyLineUnlocked =>
      'تعمل رموز PIN الخاصة بك على هذا الهاتف فقط، وفقط ما دام قفله مفتوحًا. إن فقد الهاتف يومًا المفتاح الذي يتحقق منها، فسيلزمك إعادة ضبط Kryfo واستعادة نسخة احتياطية. لا تعود المحادثات المخفية إلا من نسخة احتياطية أُنشئت وهي مفتوحة.';

  @override
  String get keyLineScreenLock =>
      'اضبط قفل شاشة لهاتفك حتى تبقى هذه الحماية قائمة عندما يكون مقفلًا.';

  @override
  String get fileServerTryLater =>
      'خادم الملفات ممتلئ حاليًا. حاول مرة أخرى بعد قليل.';

  @override
  String fileTooBigUntilUpdate(String size, String max) {
    return 'حجم هذا الملف ⁨$size⁩. في هذه المحادثة يمكن إرسال ملفات حتى ⁨$max⁩ إلى أن يحدّث الجميع Kryfo.';
  }

  @override
  String get fileDayLimit =>
      'أرسلت اليوم ملفات كبيرة كثيرة. حاول مرة أخرى غدًا.';

  @override
  String get mediaProgressPreparing => 'جارٍ التحضير · أبقِ التطبيق مفتوحًا';

  @override
  String get groupShotsBlocksAll =>
      'يمنع لقطات الشاشة وتسجيل الشاشة على كل هاتف في هذه المجموعة، ونسخ رسائل بعضكم أو إعادة توجيهها أو حفظها. لا يستطيع منع التطبيقات المسموح لها بقراءة الشاشة، ولا هاتفًا أو تطبيقًا عُدِّل للالتفاف عليه.';

  @override
  String get groupShotsBlocksAllDesk =>
      'يوقف هنا نسخ رسائل بعضكم وإعادة توجيهها وحفظها. ويمنع Kryfo لأندرويد أيضًا لقطات الشاشة وتسجيلها.';

  @override
  String get groupShotsStartsWhenAll =>
      'بانتظار أن يستطيع الجميع هنا منع لقطات الشاشة على أجهزتهم';

  @override
  String get groupShotsOnForAll => 'مفعّل للجميع هنا';

  @override
  String get groupShotsOnForAllDesk => 'مفعّل في Kryfo لأندرويد';

  @override
  String get groupShotsOffAdminOnly => 'متوقف. المشرف وحده يستطيع تغيير هذا';

  @override
  String get groupShotsWaitAdminOnly =>
      'بانتظار أن يستطيع الجميع هنا منع لقطات الشاشة على أجهزتهم. المشرف وحده يستطيع تغيير هذا';

  @override
  String get groupShotsOnAdminOnly =>
      'مفعّل للجميع هنا. المشرف وحده يستطيع تغيير هذا';

  @override
  String get groupShotsOnAdminOnlyDesk =>
      'مفعّل في Kryfo لأندرويد. المشرف وحده يستطيع تغيير هذا';

  @override
  String groupShotsWaitingFor(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'بانتظار ⁨$countString⁩ شخص',
      many: 'بانتظار ⁨$countString⁩ شخصًا',
      few: 'بانتظار ⁨$countString⁩ أشخاص',
      two: 'بانتظار شخصين',
      one: 'بانتظار شخص واحد',
      zero: 'بانتظار ⁨$countString⁩ شخص',
    );
    return '$_temp0';
  }

  @override
  String get groupShotsWaitingTitle => 'لم يشملهم بعد';

  @override
  String get groupShotsWaitingHint =>
      'يشمل منع لقطات الشاشة الجميع عندما تستطيع أجهزة هؤلاء الأشخاص منع لقطات الشاشة. اضغط على شخص لإزالته من المجموعة.';

  @override
  String get groupShotsNeedsUpdate =>
      'لا يستطيع منع لقطات الشاشة على جهازه بعد، أو لم يتصل منذ ذلك الحين';

  @override
  String get groupShotsBlockedByYou => 'حظرته';

  @override
  String get groupShotsYouTurnedOnWait =>
      'فعّلت منع لقطات الشاشة. يشمل الجميع عندما يستطيع كل من هنا منع لقطات الشاشة على جهازه.';

  @override
  String groupShotsTheyTurnedOnWait(String name) {
    return 'فعّل $name منع لقطات الشاشة. يشمل الجميع عندما يستطيع كل من هنا منع لقطات الشاشة على جهازه.';
  }

  @override
  String get groupShotsStarted =>
      'منع لقطات الشاشة مفعّل للجميع هنا. نسخ رسائل بعضكم وإعادة توجيهها وحفظها متوقف أيضًا.';

  @override
  String get groupShotsStartedDesk =>
      'منع لقطات الشاشة مفعّل في Kryfo لأندرويد. نسخ رسائل بعضكم وإعادة توجيهها وحفظها متوقف أيضًا.';

  @override
  String get groupShotsPaused =>
      'أحد الموجودين هنا لا يستطيع منع لقطات الشاشة على جهازه بعد. سيشمل الجميع مجددًا عندما يستطيع ذلك.';

  @override
  String get groupShotsCantYet => 'لا يستطيع منع لقطات الشاشة بعد';

  @override
  String get groupShotsAddTitle => 'إضافة على أي حال؟';

  @override
  String get groupShotsAddPauses =>
      'لن يشمل منع لقطات الشاشة الجميع هنا حتى يستطيعوا منعها على أجهزتهم.';

  @override
  String get groupShotsLeaveStays => 'يبقى منع لقطات الشاشة كما هو.';

  @override
  String get groupShotsBlockedHere => 'يمنع Kryfo لقطات الشاشة في هذه المجموعة';

  @override
  String get groupShotsBlockedHereDesk =>
      'النسخ وإعادة التوجيه والحفظ متوقف في هذه المجموعة';

  @override
  String get groupShotsMenuNote =>
      'نسخ رسائل الآخرين وإعادة توجيهها وحفظها متوقف في هذه المجموعة';

  @override
  String get groupShotsKeptOpen =>
      'فتح ملفات الآخرين في تطبيقات أخرى متوقف في هذه المجموعة';

  @override
  String get groupShotsOldNotice =>
      'فعّلت منع لقطات الشاشة في هذه المجموعة. لا يستطيع Kryfo لديك فعل ذلك بعد، فحدّثه من فضلك.';

  @override
  String get captureShotTaken => 'التُقطت لقطة شاشة. لم يُبلَّغ أي شخص آخر.';

  @override
  String get captureRecording =>
      'يجري تسجيل هذه الشاشة. لم يُبلَّغ أي شخص آخر.';

  @override
  String get settingsDevices => 'الأجهزة';

  @override
  String get devicesLinkedDevices => 'الأجهزة المرتبطة';

  @override
  String get devicesThisPhoneOnly => 'هذا الهاتف فقط';

  @override
  String get devicesThisPhoneOnlyDesk => 'هذا الحاسوب فقط';

  @override
  String get devicesNameSeparator => '، ';

  @override
  String get devicesThisPhone => 'هذا الهاتف';

  @override
  String get devicesThisPhoneDesk => 'هذا الحاسوب';

  @override
  String get devicesOnlyThisPhone => 'هذا الهاتف وحده يربط الأجهزة أو يزيلها';

  @override
  String get devicesOnlyThisPhoneDesk =>
      'هذا الحاسوب وحده يربط الأجهزة أو يزيلها';

  @override
  String devicesLinkedOn(Object date) {
    return 'رُبط في ⁨$date⁩';
  }

  @override
  String get devicesUsedToday => 'استُخدم اليوم';

  @override
  String get devicesUsedThisWeek => 'استُخدم هذا الأسبوع';

  @override
  String get devicesUsedThisMonth => 'استُخدم هذا الشهر';

  @override
  String get devicesNotUsedYet => 'لم يُستخدم بعد';

  @override
  String devicesUnlinksSoon(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'يُفصل بعد ⁨$daysString⁩ يوم إن لم تفتحه',
      many: 'يُفصل بعد ⁨$daysString⁩ يومًا إن لم تفتحه',
      few: 'يُفصل بعد ⁨$daysString⁩ أيام إن لم تفتحه',
      two: 'يُفصل بعد يومين إن لم تفتحه',
      one: 'يُفصل غدًا إن لم تفتحه',
      zero: 'يُفصل اليوم إن لم تفتحه',
    );
    return '$_temp0';
  }

  @override
  String get devicesEmptyTitle => 'Kryfo على حاسوبك';

  @override
  String get devicesEmptyLine =>
      'اربط حاسوبًا لتقرأ رسائلك وترسلها منه. حتى خمسة أجهزة إضافةً إلى هذا الهاتف.';

  @override
  String get devicesContactsSeeNothing => 'تطبيقات جهات اتصالك لا تعرض أجهزتك.';

  @override
  String get devicesUnusedRule =>
      'الجهاز الذي لا تفتحه 30 يومًا يفصل نفسه ويمسح محادثاتك منه.';

  @override
  String get devicesFull => 'خمسة أجهزة مرتبطة. أزِل واحدًا لتربط غيره.';

  @override
  String get devicesLinkADevice => 'ربط جهاز';

  @override
  String get devicesRemoveAll => 'إزالة كل الأجهزة الأخرى';

  @override
  String get devicesRemoveAllTitle => 'أتزيل كل الأجهزة الأخرى؟';

  @override
  String get devicesRemoveAllLine =>
      'بعد أن تتلقى تطبيقات جهات اتصالك التغيير، تتوقف عن تلقي رسائل جديدة ولا يمكنها الإرسال باسمك. هذا الهاتف يحتفظ بكل شيء.';

  @override
  String get devicesRemoveAllYes => 'إزالة الكل';

  @override
  String get devicesRemovedAll => 'هذا الهاتف وحده الآن';

  @override
  String devicesRemoveTitle(Object name) {
    return 'أتزيل ⁨$name⁩؟';
  }

  @override
  String get devicesRemoveLine =>
      'بعد أن تتلقى تطبيقات جهات اتصالك التغيير، يتوقف عن تلقي رسائل جديدة ولا يمكنه الإرسال باسمك. يمسح محادثاتك من نفسه في المرة القادمة التي يتصل فيها. الجهاز الذي عبث به أحد قد يحتفظ بما لديه أصلًا.';

  @override
  String get devicesRemove => 'إزالة';

  @override
  String devicesRemoved(Object name) {
    return 'أُزيل ⁨$name⁩';
  }

  @override
  String get devicesRename => 'إعادة تسمية';

  @override
  String devicesRenameTitle(Object name) {
    return 'إعادة تسمية ⁨$name⁩';
  }

  @override
  String get devicesRenameLine =>
      'أنت وحدك ترى هذا الاسم. جهات اتصالك لا تراه أبدًا.';

  @override
  String get devicesNameComputer => 'حاسوب';

  @override
  String get devicesDeviceCode => 'رمز الجهاز';

  @override
  String get devicesDeviceCodeLine =>
      'يظهر الرمز نفسه على الجهاز ذاته، في الإعدادات.';

  @override
  String get devicesLinkStep1 => 'افتح Kryfo على حاسوبك. سيعرض رمزًا.';

  @override
  String get devicesLinkStep2 => 'اقرأ الرمز بكاميرا هذا الهاتف.';

  @override
  String get devicesLinkStep3 => 'تأكد أن الشاشتين تعرضان الأرقام الستة نفسها.';

  @override
  String get devicesHistory => 'السجل';

  @override
  String get devicesHistoryCopy => 'نسخ محادثاتي';

  @override
  String get devicesHistoryCopyHint =>
      'كل رسائلك، مع الصور والفيديوهات من آخر 30 يومًا.';

  @override
  String get devicesHistoryNone => 'جهات الاتصال والمجموعات فقط';

  @override
  String get devicesHistoryNoneHint => 'تصل دون أي رسائل.';

  @override
  String get devicesSkipMedia => 'تخطي الصور والفيديوهات';

  @override
  String get devicesSkipMediaHint =>
      'يُنقل النص فقط. أسرع، وأقل ما يُحفظ على الجهاز.';

  @override
  String get devicesHiddenStay =>
      'تبقى المحادثات المخفية والتمويه على هذا الهاتف.';

  @override
  String get devicesHiddenStayDesk =>
      'تبقى المحادثات المخفية والتمويه على هذا الحاسوب.';

  @override
  String get devicesScanCode => 'قراءة الرمز';

  @override
  String get devicesLinkReaching => 'جارٍ الوصول إلى الجهاز';

  @override
  String get devicesLinkReachingLine =>
      'أبقِ Kryfo مفتوحًا على الجهازين. قد يستغرق هذا دقيقة عبر Tor.';

  @override
  String get devicesLinkCompare => 'هل تتطابق الأرقام؟';

  @override
  String get devicesLinkCompareLine =>
      'يعرض الجهاز الجديد ستة أرقام أيضًا. اربطه فقط إن كانت هي نفسها.';

  @override
  String get devicesLinkMatch => 'تتطابق';

  @override
  String get devicesLinkNoMatch => 'لا تتطابق';

  @override
  String get devicesLinkLinking => 'جارٍ الربط';

  @override
  String get devicesLinkLinkingLine =>
      'جارٍ تجهيز الجهاز الجديد. أبقِ الجهازين مفتوحين.';

  @override
  String get devicesLinkDone => 'رُبط الجهاز';

  @override
  String get devicesLinkDoneLine =>
      'يظهر في الأجهزة المرتبطة، حيث يمكنك تغيير اسمه أو إزالته.';

  @override
  String get devicesLinkUnreached => 'تعذّر الوصول إلى الجهاز';

  @override
  String get devicesLinkUnreachedLine =>
      'تأكد أن Kryfo مفتوح على الجهاز الجديد ويعرض رمزه، ثم أعد المحاولة.';

  @override
  String get devicesLinkStopped => 'لم يُربط شيء';

  @override
  String get devicesLinkStoppedLine =>
      'يجب أن تتطابق الأرقام. ابدأ من جديد برمز جديد.';

  @override
  String get devicesLinkInterruptedLine =>
      'انقطع الربط. ابدأ من جديد برمز جديد.';

  @override
  String get scanLinkTitle => 'قراءة رمز الجهاز';

  @override
  String get scanLinkPoint => 'وجّه الكاميرا إلى الرمز على الجهاز الجديد';

  @override
  String get scanLinkNotOne => 'هذا ليس رمز ربط';

  @override
  String get onboardingLinkToMyPhone => 'الربط بهاتفي';

  @override
  String get joinTitle => 'الربط بهاتفك';

  @override
  String get joinStep1 => 'افتح Kryfo على هاتفك.';

  @override
  String get joinStep2 =>
      'اذهب إلى الإعدادات، ثم الأجهزة المرتبطة، ثم ربط جهاز.';

  @override
  String get joinStep3 => 'اقرأ هذا الرمز بهاتفك.';

  @override
  String get joinWaiting => 'في انتظار هاتفك';

  @override
  String get joinCodeLife => 'يعمل الرمز عشر دقائق.';

  @override
  String get joinCompareLine =>
      'يعرض هاتفك ستة أرقام أيضًا. تابع فقط إن كانت هي نفسها.';

  @override
  String get joinLinking => 'جارٍ الربط بهاتفك';

  @override
  String get joinLinkingLine => 'أبقِ Kryfo مفتوحًا على هاتفك حتى ينتهي هذا.';

  @override
  String get joinDone => 'رُبط بهاتفك';

  @override
  String get joinDoneLine =>
      'تصل الرسائل الجديدة إلى هذا الجهاز أيضًا. رقم مفتاح حسابك:';

  @override
  String get joinOpen => 'فتح Kryfo';

  @override
  String get joinUnreached => 'تعذّر الوصول إلى هاتفك';

  @override
  String get joinUnreachedLine =>
      'تأكد أن هاتفك متصل وأن Kryfo مفتوح عليه، ثم جرّب رمزًا جديدًا.';

  @override
  String get joinNewCode => 'رمز جديد';

  @override
  String get devicesNewNotice => 'رُبط جهاز جديد';

  @override
  String devicesNewNoticeLine(Object name, Object date) {
    return 'رُبط ⁨$name⁩ بحسابك في ⁨$date⁩. افتح الأجهزة المرتبطة لتراه.';
  }

  @override
  String get devicesNewNoticeMany => 'أجهزة جديدة مرتبطة';

  @override
  String devicesNewNoticeManyLine(Object names) {
    return 'رُبطت ⁨$names⁩ بحسابك. افتح الأجهزة المرتبطة لتراها.';
  }

  @override
  String get devicesNewNoticeOpen => 'فتح';

  @override
  String get settingsLinkedToLine =>
      'مرتبط بهاتفك. تبقى النسخ الاحتياطية والدعوات على الهاتف.';

  @override
  String get devicesYourPhone => 'هاتفك';

  @override
  String get desktopLockTitle => 'Kryfo مقفل';

  @override
  String get desktopLockBody => 'اكتب عبارة المرور الخاصة بهذا الحاسوب.';

  @override
  String get desktopLockNewTitle => 'اقفل Kryfo على هذا الحاسوب';

  @override
  String get desktopLockNewBody =>
      'سيطلب Kryfo عبارة المرور هذه في كل مرة يبدأ فيها. إنها تقفل رسائلك وصورك ورسائلك الصوتية وملفاتك وجهات اتصالك ومفاتيحك على هذا الحاسوب.';

  @override
  String get desktopLockHonest =>
      'من ينسخ مجلد Kryfo يستطيع تجربة عبارات المرور على حاسوبه بأقصى سرعة يسمح بها. أربع كلمات عشوائية أو أكثر تصمد. أما العبارة القصيرة فلا.';

  @override
  String get desktopLockForgot =>
      'من دون عبارة المرور لا يمكن فتح أي من رسائلك أو ملفاتك أو مفاتيحك هنا، ولا حتى من قبلنا.';

  @override
  String get desktopLockField => 'عبارة المرور';

  @override
  String get desktopLockRepeat => 'عبارة المرور نفسها مرة أخرى';

  @override
  String get desktopLockSet => 'اقفل بهذه العبارة';

  @override
  String get desktopLockOpen => 'افتح Kryfo';

  @override
  String desktopLockShort(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString حرفًا على الأقل';
  }

  @override
  String get desktopLockMismatch => 'عبارتا المرور غير متطابقتين';

  @override
  String get desktopLockWrong => 'هذه ليست عبارة المرور';

  @override
  String get desktopLockFailed =>
      'تعذّر على Kryfo فتح قفله هنا. جرّب تشغيله مرة أخرى.';

  @override
  String get desktopTrayQuit => 'أغلق Kryfo';

  @override
  String get desktopTrayTip => 'Kryfo يعمل ويستقبل الرسائل';

  @override
  String get desktopTrayLockedTip => 'افتح Kryfo لتبدأ في استقبال الرسائل';

  @override
  String get desktopTrayStillRunning =>
      'لا يزال Kryfo يعمل في علبة النظام. للخروج استخدم أيقونته في علبة النظام.';

  @override
  String get desktopRunSection => 'على هذا الحاسوب';

  @override
  String get desktopTrayRow => 'إبقاء التشغيل في علبة النظام';

  @override
  String get desktopTrayHint =>
      'إغلاق النافذة يُبقي Kryfo في علبة النظام، فتظل الرسائل تصل.';

  @override
  String get desktopTrayOffLine =>
      'إغلاق النافذة يُنهي Kryfo. تصل الرسائل عندما تفتحه من جديد.';

  @override
  String get desktopTrayNoneLine =>
      'سطح المكتب هذا لا يعرض أيقونات علبة النظام، لذا يُنهي إغلاق النافذة Kryfo.';

  @override
  String get desktopStartRow => 'التشغيل مع بدء الحاسوب';

  @override
  String get desktopStartHint =>
      'يبدأ Kryfo في علبة النظام عند تسجيل دخولك إلى هذا الحاسوب.';

  @override
  String get desktopStartRefused =>
      'لم يسمح هذا الحاسوب بتشغيل Kryfo معه. يفتح Kryfo متى شغّلته بنفسك.';

  @override
  String get desktopStartHeldOff =>
      'يضع Windows ‏Kryfo على وضع الإيقاف في تطبيقات بدء التشغيل. شغّله من هناك: الإعدادات، التطبيقات، بدء التشغيل.';

  @override
  String get desktopNoCamera =>
      'لا يستطيع Kryfo استخدام كاميرا على هذا الحاسوب بعد. استخدم الرابط أو الرمز بدلًا من ذلك.';

  @override
  String get desktopAlreadyOpen => 'Kryfo مفتوح بالفعل على هذا الحاسوب.';

  @override
  String get desktopFolderNotYours =>
      'مجلد Kryfo يخص حسابًا آخر على هذا الحاسوب، لذا لن يفتحه Kryfo.';

  @override
  String get desktopFolderNotPrivate =>
      'تعذّر على Kryfo جعل مجلده خاصًا بك، لذا لن يفتح.';

  @override
  String get desktopLockOtherVersion =>
      'صنع هذا القفل إصدار آخر من Kryfo لا يستطيع هذا الإصدار قراءته.';

  @override
  String get desktopNoMemoryFolder =>
      'يحتاج Kryfo إلى مجلد خاص في الذاكرة أثناء عمله، وهذا الحاسوب لا يوفّر واحدًا، لذا لن يفتح.';

  @override
  String get inviteNotYet =>
      'هذه الدعوة ليست صالحة بعد. تحقّق من الوقت على هاتفك.';

  @override
  String get inviteNotYetDesk =>
      'هذه الدعوة ليست صالحة بعد. تحقّق من الوقت على حاسوبك.';

  @override
  String get inviteExpired => 'انتهت صلاحية هذه الدعوة. اطلب دعوة جديدة.';

  @override
  String get inviteDamaged => 'هذه الدعوة تالفة. اطلب دعوة جديدة.';

  @override
  String get helloSent => 'أُرسل الطلب. سيرونه عندما يكونون متصلين.';

  @override
  String get inviteNeeds06 => 'يحتاج إلى Kryfo 0.6 أو أحدث.';

  @override
  String get helloSentOld =>
      'أُرسل الطلب. إذا كانوا يستخدمون إصدارًا أقدم من Kryfo، فعليهم التحديث أولًا.';

  @override
  String get modesPickHow =>
      'اختر كيف تنتقل رسائلك. يمكنك تغيير ذلك في أي وقت.';

  @override
  String get modesPrivate => 'خاص';

  @override
  String get modesPrivateTag => 'Tor · جسور عند الحاجة';

  @override
  String get modesPrivateLine =>
      'لا أحد يعرف عنوان IP الخاص بك أو من أنت، ولا حتى خوادمنا. يجد طريقًا حول الحجب بنفسه.';

  @override
  String get modesDefault => 'الافتراضي';

  @override
  String get modesFastTag => 'مباشرة إلى خوادمنا';

  @override
  String get modesFastLine =>
      'يتخطى Tor، فتصل الرسائل أسرع وتستهلك بطارية أقل. ترى خوادمنا عنوان IP الخاص بك فقط أثناء اتصالك، ولا تسجله أو تحتفظ به أبدًا. جهات اتصالك لا تراه أبدًا. يمكن لشبكتك أن ترى أنك تتصل بـ Kryfo.';

  @override
  String get modesFastConnected => 'سريع · متصل';

  @override
  String get modesFastConnecting => 'سريع · جارٍ الاتصال';

  @override
  String get modesFastDown => 'سريع · خوادمنا لا ترد';

  @override
  String get modesBackupReady =>
      'هناك احتياطي جاهز دائمًا، فتبقى متصلًا حتى لو توقف أحدها.';

  @override
  String get modesDetails => 'التفاصيل';

  @override
  String get modesBothLine =>
      'كلاهما يُبقي كل رسالة مشفرة من طرف إلى طرف. ما يتغير فقط هو من يمكنه رؤية عنوان IP الخاص بك.';

  @override
  String get modesConnectionBridges => 'الاتصال والجسور';

  @override
  String get modesWhatServersSee => 'ما يمكن لخوادمنا رؤيته';

  @override
  String get serversTitle => 'خوادم الوضع السريع';

  @override
  String get serversLine =>
      'تذهب كل رسالة إلى الخادمين معًا. الذي يرد أولًا يحملها، والآخر يتولى الأمر إذا توقف أحدهما.';

  @override
  String get serversOne => 'الخادم 1';

  @override
  String get serversTwo => 'الخادم 2 · مزوّد ثانٍ';

  @override
  String get serversConnected => 'متصل';

  @override
  String get serversConnecting => 'جارٍ الاتصال';

  @override
  String get serversNotAnswering => 'لا يرد';

  @override
  String serversMs(int ms) {
    return '$ms م.ث';
  }

  @override
  String get serversQuicker => 'الأسرع';

  @override
  String get serversBackups => 'مُرحِّلات عامة';

  @override
  String get serversBackupsLine =>
      'تُستخدم أثناء توقف الخادم 1، وعبر Tor فقط، فلا ترى عنوان IP الخاص بك أبدًا.';

  @override
  String get serversStandingBy => 'في وضع الاستعداد';

  @override
  String get serversInUse => 'قيد الاستخدام';

  @override
  String get homeMergedTitle => 'أصبح المُرحِّل والسريع واحدًا الآن';

  @override
  String get homeMergedLine =>
      'أنت على الوضع السريع. هناك خادم احتياطي جاهز دائمًا، فتبقى متصلًا حتى لو توقف أحدها. ترى خوادمنا عنوان IP الخاص بك، ولا ترى أبدًا ما تقوله.';

  @override
  String get homeMergedGotIt => 'فهمت';

  @override
  String get homeMergedUsePrivate => 'استخدم الخاص بدلًا من ذلك';

  @override
  String get homeOursDownTitle => 'خوادمنا لا ترد';

  @override
  String get homeOursDownLine =>
      'بعد دقائق قليلة، حين يتصل Tor، تمر الرسائل أيضًا عبر مُرحِّلات عامة، وتعود عبر خوادمنا حالما يرد أحدها.';

  @override
  String get homeUsePrivate => 'استخدم الخاص';

  @override
  String get homeSwitchedToPrivate => 'تم التبديل إلى الخاص';

  @override
  String get homeUseFast => 'استخدم السريع';

  @override
  String get homeSwitchedToFastRoute => 'تم التبديل إلى السريع';

  @override
  String get bridgesBridgeFirstFastSeen =>
      'دع Kryfo يجد جسرًا ينجح. السريع ينجح أيضًا، لكن هذه الشبكة يمكنها أن ترى اتصالك بـ Kryfo.';

  @override
  String get appServersNotAnswering => 'الخوادم لا ترد';

  @override
  String get settingsPrivateTor => 'خاص · Tor';

  @override
  String get seenOurServers => 'خوادمنا';

  @override
  String get seenOurServersCould => 'خوادمنا قد ترى';

  @override
  String get seenIpWhy =>
      'في الخاص يخرج كل شيء عبر Tor وترى خوادمنا عقدة خروج، لا أنت أبدًا. في السريع يذهب الاتصال مباشرة إلى خادمينا: يريان عنوان IP الخاص بك أثناء اتصالك ولا يحتفظان بأي سجل له. أثناء توقف الأول يستخدم السريع أيضًا مُرحِّلات عامة، عبر Tor فقط.';

  @override
  String get chatAlbumItDisappearsWithNo =>
      'سيُحذف الألبوم من الهاتفين، إلا إذا كان قد حُفظ. لا يمكن التراجع عن هذا.';

  @override
  String get chatAlbumItDisappearsWithNoDesk =>
      'سيُحذف الألبوم من الجهازين، إلا إذا كان قد حُفظ. لا يمكن التراجع عن هذا.';

  @override
  String get groupChatAlbumItDisappearsWithNo =>
      'سيُحذف الألبوم من هواتف الجميع، إلا إذا كان قد حُفظ. لا يمكن التراجع عن هذا.';

  @override
  String get groupChatAlbumItDisappearsWithNoDesk =>
      'سيُحذف الألبوم من أجهزة الجميع، إلا إذا كان قد حُفظ. لا يمكن التراجع عن هذا.';

  @override
  String get homeInviteSomeone => 'ادعُ شخصًا';

  @override
  String get onboardingNameHeadline => '*اسم عام*، إن أردت.';

  @override
  String get onboardingNameLine =>
      'يتيح الاسم العام للناس أن يجدوك. التخطي يبقيك أكثر خصوصية، ويمكنك دائمًا إضافة اسم لاحقًا.';

  @override
  String get onboardingNameSkip => 'التخطي الآن ←';

  @override
  String onboardingNameClaim(Object handle) {
    return 'احجز ⁦@$handle⁩ ←';
  }

  @override
  String get onboardingInviteHeadline => 'والآن، *ادعُ شخصًا*.';

  @override
  String get onboardingInviteLead =>
      'أرسل رابطًا عبر أي تطبيق مراسلة. يفتح Kryfo، أو يريهم من أين يحصلون عليه.';

  @override
  String get onboardingInviteSomeone => 'ادعُ شخصًا ←';

  @override
  String get onboardingInviteGettingReady => 'جارٍ تجهيز رابطك…';

  @override
  String inviteShareText(Object myId, Object link, Object download) {
    return 'أضفني على Kryfo. اسمي هناك ⁨$myId⁩\n\nاضغط لإضافتي:\n⁨$link⁩\n\nليس لديك Kryfo بعد؟ احصل عليه من هنا:\n⁨$download⁩\n\nتطبيق Kryfo للمراسلة الخاصة. بلا رقم هاتف، وبلا بريد إلكتروني.';
  }

  @override
  String get inviteNotReady => 'رابطك جاهز تقريبًا. حاول مجددًا بعد لحظة.';

  @override
  String get photoCropTitle => 'حرّك وغيّر الحجم';

  @override
  String get photoCropUse => 'استخدم الصورة';

  @override
  String get photoCropLabel =>
      'صورتك داخل الدائرة. باعد إصبعيك للتكبير واسحب للتحريك';

  @override
  String get photoCouldNotUse => 'جرّب صورة أخرى. تعذّرت قراءة هذه الصورة.';

  @override
  String get photoTake => 'التقط صورة';

  @override
  String get photoChoose => 'اختر من المعرض';

  @override
  String get photoPickFace => 'اختر وجهًا';

  @override
  String get photoView => 'عرض الصورة';

  @override
  String get photoRemove => 'إزالة الصورة';

  @override
  String get photoYourPhoto => 'صورتك';

  @override
  String get photoYourPhotoLine =>
      'لا يراها إلا جهات اتصالك، مشفّرة من طرف إلى طرف.';

  @override
  String get photoSetTheirs => 'ضع صورة';

  @override
  String get photoChangeTheirs => 'غيّر الصورة';

  @override
  String get photoOnlyHere => 'على هذا الهاتف فقط';

  @override
  String get photoOnlyHereDesk => 'على هذا الحاسوب فقط';

  @override
  String photoForThem(Object name) {
    return 'صورة لـ $name';
  }

  @override
  String get photoOnlyHereLine => 'لا يراها أحد غيرك. تبقى على هذا الهاتف.';

  @override
  String get photoOnlyHereLineDesk =>
      'لا يراها أحد غيرك. تبقى على هذا الحاسوب.';

  @override
  String photoOf(Object name) {
    return 'صورة $name';
  }

  @override
  String get historyChatStaysShots =>
      'تبقى هذه المحادثة على هاتفك لأن لقطات الشاشة محظورة فيها.';

  @override
  String chatDeviceReplyFromPhone(String name) {
    return '$name يستخدم إصدارًا أقدم من Kryfo. ردّ من هاتفك.';
  }

  @override
  String chatDeviceReplyFromPhoneForNow(String name) {
    return 'ردّ على $name من هاتفك في الوقت الحالي.';
  }

  @override
  String get linkedClearHereOnly =>
      'تُمسح كل رسالة هنا من هذا الحاسوب فقط. يحتفظ بها هاتفك.';

  @override
  String get linkedDeleteHereOnly =>
      'تزول كل الرسائل وجهة الاتصال من هذا الحاسوب فقط. يحتفظ هاتفك بالمحادثة.';

  @override
  String get linkedBlockHereOnly =>
      'تتوقف رسائله عن الوصول إلى هذا الحاسوب. ولا يُبلَّغ بذلك. احظره من هاتفك ليتوقف هناك أيضًا.';

  @override
  String get historyCopyTitle => 'سجل المحادثات';

  @override
  String get historyCopyMaking => 'جارٍ تجهيز محادثاتك';

  @override
  String get historyCopyMakingLine => 'يجمع هاتفك ما سيُنسخ. يبدأ بعد لحظة.';

  @override
  String get historyCopyGoing => 'جارٍ نسخ محادثاتك';

  @override
  String get historyCopyGoingLine => 'أبقِ الجهازين متصلين حتى ينتهي النسخ.';

  @override
  String historyCopySize(Object size) {
    return 'المجموع ⁨$size⁩';
  }

  @override
  String get historyCopyWaiting => 'بانتظار الجهاز الآخر';

  @override
  String get historyCopyWaitingLine =>
      'يتابع النسخ وحده حين يكون الجهازان متصلين.';

  @override
  String get historyCopyPaused => 'يأخذ النسخ استراحة قصيرة';

  @override
  String get historyCopyPausedLine => 'يتابع بعد دقيقة.';

  @override
  String get historyCopyWhole => 'وصلت كل الرسائل والملفات';

  @override
  String get historyCopyWholeLine => 'لا شيء ناقص.';

  @override
  String get historyCopyRows => 'وصلت جهات اتصالك ومجموعاتك';

  @override
  String get historyCopyRowsLine =>
      'وصلت دون أي رسائل. تظهر الرسائل الجديدة على الجهاز من الآن.';

  @override
  String get historyCopyGaps => 'وصلت معظم محادثاتك';

  @override
  String get historyCopyGapsLine =>
      'في هذه المحادثات محتوى أقل على الجهاز الجديد مما على هاتفك.';

  @override
  String historyCopyGapMessages(Object got, Object want) {
    return 'الرسائل: ⁨$got⁩ من ⁨$want⁩';
  }

  @override
  String historyCopyGapFiles(Object got, Object want) {
    return 'الملفات: ⁨$got⁩ من ⁨$want⁩';
  }

  @override
  String historyCopyLeft(num count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'بقي ⁨$countString⁩ عنصر على هاتفك',
      many: 'بقي ⁨$countString⁩ عنصرًا على هاتفك',
      few: 'بقيت ⁨$countString⁩ عناصر على هاتفك',
      two: 'بقي عنصران على هاتفك',
      one: 'بقي عنصر واحد على هاتفك',
    );
    return '$_temp0';
  }

  @override
  String get historyCopyLeftWhy => 'كبيرة جدًا أو غير مقروءة للنسخ.';

  @override
  String historyCopyLeftChats(num count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'بقيت ⁨$countString⁩ محادثة على هاتفك',
      many: 'بقيت ⁨$countString⁩ محادثة على هاتفك',
      few: 'بقيت ⁨$countString⁩ محادثات على هاتفك',
      two: 'بقيت محادثتان على هاتفك',
      one: 'بقيت محادثة واحدة على هاتفك',
    );
    return '$_temp0';
  }

  @override
  String get historyCopyEnded => 'توقف النسخ';

  @override
  String get historyCopyEndedLine =>
      'لن يصل شيء آخر. اربط الجهاز من جديد لنسخة جديدة.';

  @override
  String get historyCopyFailed => 'تعذّر إكمال النسخ';

  @override
  String get historyCopyFailedLine => 'اربط الجهاز من جديد لنسخة جديدة.';

  @override
  String get historyCopyStays => 'بقي على هاتفك';

  @override
  String get historyCopySee => 'عرض النسخ';

  @override
  String a11yPinDigits(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$countString⁩ رقم',
      many: '⁨$countString⁩ رقمًا',
      few: '⁨$countString⁩ أرقام',
      two: 'رقمان',
      one: 'رقم واحد',
      zero: 'لا أرقام',
    );
    return '$_temp0';
  }

  @override
  String a11yPassChars(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$countString⁩ حرف',
      many: '⁨$countString⁩ حرفًا',
      few: '⁨$countString⁩ أحرف',
      two: 'حرفان',
      one: 'حرف واحد',
      zero: 'لا أحرف',
    );
    return '$_temp0';
  }

  @override
  String get a11yBackupProgress => 'تقدّم النسخ الاحتياطي';

  @override
  String get a11yRestoreProgress => 'تقدّم الاستعادة';

  @override
  String get a11yExportProgress => 'تقدّم التصدير';

  @override
  String get a11yLockFileProgress => 'تقدّم القفل';

  @override
  String get a11yCleanProgress => 'تقدّم التنظيف';

  @override
  String get a11yMessageActions => 'إجراءات الرسالة';

  @override
  String get a11yRecordVoiceNote => 'سجّل رسالة صوتية';

  @override
  String get a11yRecording => 'جارٍ التسجيل';

  @override
  String a11yPhotoOn(String date) {
    return 'صورة، ⁨$date⁩';
  }

  @override
  String a11yPhotoFrom(String name, String date) {
    return 'صورة من ⁨$name⁩، ⁨$date⁩';
  }

  @override
  String a11yVideoOn(String date) {
    return 'فيديو، ⁨$date⁩';
  }

  @override
  String a11yVideoFrom(String name, String date) {
    return 'فيديو من ⁨$name⁩، ⁨$date⁩';
  }

  @override
  String a11yNewMessages(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$countString⁩ رسالة جديدة',
      many: '⁨$countString⁩ رسالة جديدة',
      few: '⁨$countString⁩ رسائل جديدة',
      two: 'رسالتان جديدتان',
      one: 'رسالة جديدة',
    );
    return '$_temp0';
  }

  @override
  String get wideSelectChat => 'اختر محادثة';

  @override
  String get wideSelectChatLine => 'اختر محادثة من القائمة لتبدأ الكتابة.';

  @override
  String get wideListWidth => 'عرض قائمة المحادثات';

  @override
  String transferDoneOf(String done, String total) {
    return '⁨$done⁩ من ⁨$total⁩';
  }

  @override
  String transferDoneLeft(String done, String left) {
    return '⁨$done⁩ · ⁨$left⁩';
  }

  @override
  String get transferLeftSoon => 'أقل من دقيقة متبقية';

  @override
  String transferLeftMinutes(String n) {
    return 'متبقٍ نحو ⁨$n⁩ د';
  }

  @override
  String transferLeftHours(String n) {
    return 'متبقٍ نحو ⁨$n⁩ س';
  }

  @override
  String transferSending(String detail) {
    return 'جارٍ الإرسال · ⁨$detail⁩';
  }

  @override
  String transferReceiving(String detail) {
    return 'جارٍ الاستلام · ⁨$detail⁩';
  }

  @override
  String transferBoth(String detail) {
    return 'جارٍ الإرسال والاستلام · ⁨$detail⁩';
  }

  @override
  String get transferPause => 'إيقاف مؤقت';

  @override
  String get transferPauseDownload => 'إيقاف التنزيل مؤقتًا';

  @override
  String get transferDownload => 'تنزيل';

  @override
  String get transferResume => 'استئناف';

  @override
  String get transferOnWifi => 'يُنزَّل عبر Wi-Fi';

  @override
  String transferPausedAt(String detail) {
    return 'متوقف مؤقتًا · ⁨$detail⁩';
  }

  @override
  String get transferTapToDownload => 'انقر للتنزيل';

  @override
  String transferSizeLine(String size, String state) {
    return '⁨$size⁩ · ⁨$state⁩';
  }

  @override
  String get transferNoteTitle => 'نقل الملفات';

  @override
  String get transferChannel => 'نقل الملفات';

  @override
  String get transferChannelLine =>
      'يظهر أثناء إرسال الملفات أو تنزيلها. لا يذكر أبدًا اسم محادثة أو ملف.';

  @override
  String get autoGetTitle => 'التنزيل التلقائي';

  @override
  String get autoGetLine =>
      'تصل الملفات دون نقر حسب ما تختاره هنا. الملف المنتظر يبقى لك على خادم الملفات، أسبوعًا على الأكثر.';

  @override
  String get autoGetPhotos => 'الصور';

  @override
  String get autoGetVideos => 'الفيديوهات';

  @override
  String get autoGetFiles => 'الملفات';

  @override
  String get autoGetAlways => 'عبر Wi-Fi وبيانات الجوال';

  @override
  String get autoGetWifi => 'عبر Wi-Fi فقط';

  @override
  String get autoGetNever => 'أبدًا، أنقر للتنزيل';

  @override
  String get autoGetVoice => 'الرسائل الصوتية تُنزَّل دائمًا.';

  @override
  String get settingsFiles => 'الملفات';

  @override
  String get fileSheetOpenWith => 'فتح بتطبيق آخر';

  @override
  String get desktopLockAccountBody =>
      'كل ما يحفظه Kryfo على هذا الحاسوب مشفّر. يُفتح بحساب المستخدم الخاص بك.';

  @override
  String get desktopLockAddPassphrase => 'أضف عبارة مرور';

  @override
  String get desktopLockWithoutPassphrase =>
      'من دونها، يستطيع أي شخص يستخدم حسابك على الحاسوب فتح Kryfo.';

  @override
  String get desktopLockKeyringRefused =>
      'تعذّر على Kryfo حفظ مفتاحه في حلقة المفاتيح على هذا الحاسوب. أضف عبارة مرور بدلًا من ذلك.';

  @override
  String get desktopKeyMissing =>
      'حساب المستخدم هذا لا يملك مفتاح بيانات Kryfo. نسخة Kryfo الاحتياطية تعيد كل شيء. إن نقلت مجلد Kryfo، فأضف عبارة مرور على حساب المستخدم الذي جاء منه، ثم انسخه من جديد.';

  @override
  String get desktopKeyUnreachable =>
      'لا يستطيع Kryfo الوصول إلى مفتاحه على هذا الحاسوب الآن. افتح قفل حلقة المفاتيح إن طلب الحاسوب ذلك، ثم أعد المحاولة.';

  @override
  String get desktopPassRow => 'عبارة المرور على هذا الحاسوب';

  @override
  String get desktopPassOffBody => 'يُفتح Kryfo بحساب المستخدم الخاص بك.';

  @override
  String get desktopPassOnBody =>
      'يطلب Kryfo عبارة المرور هذه في كل مرة يبدأ فيها.';

  @override
  String get desktopPassChange => 'غيّر عبارة المرور';

  @override
  String get desktopPassRemove => 'أزل عبارة المرور';

  @override
  String get desktopPassCurrent => 'عبارة المرور الحالية';

  @override
  String get desktopPassNew => 'عبارة مرور جديدة';

  @override
  String get desktopPassStays =>
      'لا توجد على هذا الحاسوب حلقة مفاتيح يستطيع Kryfo استخدامها، لذا تبقى عبارة المرور.';

  @override
  String get desktopPassAdded => 'أُضيفت عبارة المرور';

  @override
  String get desktopPassRemoved => 'أُزيلت عبارة المرور';

  @override
  String get desktopPassChanged => 'تغيّرت عبارة المرور';

  @override
  String get desktopPassRemoveBody =>
      'اكتب عبارة المرور لإزالتها. بعدها يُفتح Kryfo بحساب المستخدم الخاص بك.';

  @override
  String get desktopKeyUnreachableWindows =>
      'لا يستطيع Kryfo الوصول إلى مفتاحه في شريحة الأمان على هذا الحاسوب الآن. أعد المحاولة بعد لحظة.';

  @override
  String get desktopLockAccountRefused =>
      'تعذّر على Kryfo حفظ مفتاحه مع حسابك على Windows. أضف عبارة مرور بدلًا من ذلك.';

  @override
  String get desktopPassStaysWindows =>
      'تعذّر على Kryfo حفظ مفتاحه مع حسابك على Windows، لذا تبقى عبارة المرور.';

  @override
  String get desktopBackupCardTitle => 'احتفظ بنسخة Kryfo الاحتياطية';

  @override
  String get desktopBackupCardLine =>
      'حسابك على Windows في هذا الحاسوب يحفظ مفتاح Kryfo. نسخة Kryfo الاحتياطية تعيد كل شيء إن أُعيد ضبط الحاسوب أو الحساب يومًا.';

  @override
  String get desktopBackupHint => 'تعيد كل شيء إن أُعيد ضبط هذا الحاسوب يومًا.';

  @override
  String chatHealRestored(Object name) {
    return 'أعاد ⁨$name⁩ إعداد Kryfo';
  }

  @override
  String chatHealNewSession(Object name) {
    return 'بدأ جهاز ⁨$name⁩ جلسة آمنة جديدة';
  }

  @override
  String chatHealHeldLine(Object name) {
    return 'سبق أن تحققت من ⁨$name⁩. لن يُرسل شيء حتى تتحقق من الرقم أو تتابع المحادثة. رسائله ما زالت تصل.';
  }

  @override
  String get chatKeepChatting => 'متابعة المحادثة';

  @override
  String chatNeedsUpdateToChat(Object name) {
    return 'يحتاج ⁨$name⁩ إلى تحديث Kryfo لمتابعة المحادثة.';
  }

  @override
  String get restoreOlderTitle => 'ستتوقف بعض المحادثات مؤقتًا';

  @override
  String restoreOlderOne(Object name) {
    return 'يستخدم ⁨$name⁩ إصدارًا أقدم من Kryfo. ستتوقف محادثتكما مؤقتًا حتى يحدّثه.';
  }

  @override
  String restoreOlderTwo(Object first, Object second) {
    return 'يستخدم ⁨$first⁩ و⁨$second⁩ إصدارًا أقدم من Kryfo. ستتوقف محادثاتك معهما مؤقتًا حتى يحدّثا التطبيق.';
  }

  @override
  String restoreOlderMany(Object first, Object second, int count) {
    return 'يستخدم ⁨$first⁩ و⁨$second⁩ و$count آخرون إصدارًا أقدم من Kryfo. ستتوقف محادثاتك معهم مؤقتًا حتى يحدّثوا التطبيق.';
  }

  @override
  String settingsVersionAlpha(String version) {
    return '$version · ألفا';
  }

  @override
  String get settingsShotsNotHereYet => 'ليس على هذا الحاسوب بعد';

  @override
  String get settingsDeskInTray => 'يعمل في علبة النظام';

  @override
  String get settingsDeskWhileOpen => 'أثناء فتح Kryfo';

  @override
  String get onboardingDeskRunTitle => 'يبقى Kryfo *يعمل*.';

  @override
  String get onboardingDeskRunLead =>
      'أغلق النافذة وسيبقى Kryfo في علبة النظام، فتظل الرسائل تصل. يمكنك تغيير الخيارين لاحقًا من الإعدادات، ضمن الإشعارات.';

  @override
  String get savedLongPressAnyMessageDesk =>
      'انقر بزر الفأرة الأيمن على أي رسالة ثم اختر «حفظ» لتبقى هنا.';

  @override
  String get chatFailedTapToRetryDesk => 'فشل · انقر لإعادة المحاولة';

  @override
  String get groupChatTapToRetryDesk => '! انقر لإعادة المحاولة';

  @override
  String get chatDropHereToSend => 'أفلِت هنا للإرسال';

  @override
  String get notesDropKeepsWords =>
      'ملاحظة لنفسي تحفظ الكلمات. أرسل الملفات في محادثة.';

  @override
  String get voiceSeeTranscription => 'عرض النص';

  @override
  String get voiceTranscribing => 'جارٍ التحويل إلى نص…';

  @override
  String get voiceHideTranscription => 'إخفاء';

  @override
  String get voiceShowOriginalOnly => 'عرض الأصل فقط';

  @override
  String get voiceCouldNotTranscribe => 'تعذّر تمييز الكلمات';

  @override
  String get voiceTranscriptLabel => 'النص المكتوب';

  @override
  String get voiceSettingsTitle => 'تحويل الصوت إلى نص';

  @override
  String get voiceOnRow => 'تحويل الرسائل الصوتية إلى نص';

  @override
  String get voiceOnHint => 'يُقترح أسفل كل رسالة صوتية';

  @override
  String get voiceOffDeletes => 'إيقاف هذا يحذف النصوص المحفوظة.';

  @override
  String get voiceModelTitle => 'نموذج الكلام';

  @override
  String voiceModelLine(Object size) {
    return 'تنزيل واحد بحجم $size تقريبًا، لكل اللغات.';
  }

  @override
  String get voiceModelPrivacy =>
      'يُنزَّل عبر Tor ويبقى على هذا الهاتف. رسائلك الصوتية لا تغادره أبدًا.';

  @override
  String get voiceModelPrivacyDesk =>
      'يُنزَّل عبر Tor ويبقى على هذا الحاسوب. رسائلك الصوتية لا تغادره أبدًا.';

  @override
  String get voiceModelFailNoTor =>
      'لم يتصل Tor بعد. يُنزَّل النموذج عبر Tor فقط، فحاول مجددًا بعد اتصاله.';

  @override
  String get voiceModelRemoveTitle => 'إزالة نموذج الكلام؟';

  @override
  String get voiceModelRemoveLine =>
      'تبقى النصوص التي أُنشئت. النصوص الجديدة تحتاج إلى النموذج مجددًا.';

  @override
  String get voiceKeptNote =>
      'تُحفظ النصوص مشفّرة مع محادثتها على هذا الهاتف وتُحذف معها.';

  @override
  String get voiceKeptNoteDesk =>
      'تُحفظ النصوص مشفّرة مع محادثتها على هذا الحاسوب وتُحذف معها.';

  @override
  String get voiceNotNow => 'ليس الآن';

  @override
  String get unlinkedTitle => 'فُصل هذا الجهاز';

  @override
  String get unlinkedRemovedLine =>
      'أزاله هاتفك من حسابك، لذا مسح Kryfo كل ما كان يحفظه هنا.';

  @override
  String get unlinkedUnusedLine =>
      'لم يُفتح منذ 30 يومًا، لذا مسح Kryfo كل ما كان يحفظه هنا.';

  @override
  String get unlinkedClockLine =>
      'أُرجعت ساعته إلى الوراء، لذا مسح Kryfo كل ما كان يحفظه هنا ليحمي محادثاتك.';

  @override
  String get unlinkedBrokenLine =>
      'لم يتمكن Kryfo من معرفة متى فُتح آخر مرة، لذا مسح كل ما كان يحفظه هنا ليحمي محادثاتك.';

  @override
  String get unlinkedSelfLine =>
      'فصلته بنفسك، لذا مسح Kryfo كل ما كان يحفظه هنا.';

  @override
  String get unlinkedAgainLine =>
      'يحتفظ هاتفك بمحادثاتك. لتستخدم Kryfo هنا من جديد، اربط هذا الجهاز بهاتفك.';

  @override
  String get unlinkedClose => 'أغلق Kryfo';

  @override
  String get devicesLeave => 'افصل هذا الجهاز';

  @override
  String get devicesLeaveTitle => 'أتفصل هذا الجهاز؟';

  @override
  String get devicesLeaveLine =>
      'يُعلم Kryfo هاتفك ويمسح كل ما يحفظه هنا. يحتفظ هاتفك بمحادثاتك.';

  @override
  String get devicesLeaveYes => 'افصل وامسح';

  @override
  String get devicesGoneNotice => 'أُزيل جهاز';

  @override
  String devicesGoneRemovedLine(Object name, Object date) {
    return 'أُزيل ⁨$name⁩ من حسابك في ⁨$date⁩.';
  }

  @override
  String devicesGoneUnusedLine(Object name, Object date) {
    return 'لم يُستخدم ⁨$name⁩ منذ 30 يومًا، لذا أُزيل من حسابك في ⁨$date⁩.';
  }

  @override
  String devicesGoneItselfLine(Object name, Object date) {
    return 'فصل ⁨$name⁩ نفسه في ⁨$date⁩ ومسح ما كان يحفظه.';
  }

  @override
  String get devicesChangedNotice => 'تغيّرت أجهزتك';

  @override
  String get devicesChangedLine => 'افتح الأجهزة المرتبطة لترى ما تغيّر.';

  @override
  String get devicesUnknownNotice => 'جهاز رُبط من مكان آخر';

  @override
  String get devicesUnknownLine =>
      'ربطت نسخة أخرى من Kryfo جهازًا بحسابك. أزاله هذا الهاتف من قائمتك.';
}
