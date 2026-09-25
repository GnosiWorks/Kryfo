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
  String get backupThatPassphraseDoesNot =>
      'عبارة المرور هذه لا تفتح هذا الملف';

  @override
  String get backupThatFileIsNot => 'هذا الملف ليس نسخة احتياطية من kryfo';

  @override
  String get backupThisBackupIsFrom =>
      'هذه النسخة الاحتياطية من إصدار أحدث من kryfo. حدّث التطبيق ثم أعد المحاولة';

  @override
  String get backupThisFileIsDamaged => 'هذا الملف تالف ولا يمكن قراءته';

  @override
  String get backupCouldNotMakeThe => 'تعذّر إنشاء المفتاح';

  @override
  String get contactCardMessageMeOn => 'راسلني على';

  @override
  String get contactCardScanItOrType =>
      'اقرأ رمزها بالكاميرا، أو اكتب الكلمات الثلاث في kryfo.\nلا تعرف هذه البطاقة عنك شيئًا سوى ذلك.';

  @override
  String contactCardMessageMeOnKryfo(Object haloId) {
    return 'راسلني على kryfo · ⁨$haloId⁩';
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
  String get lockStateUnlockKryfo => 'فتح قفل kryfo';

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
  String appAddedYouCanMessage(Object parsed) {
    return 'تمت إضافة ⁨$parsed⁩ · يمكنك مراسلته الآن';
  }

  @override
  String appPeerImportedV1(Object parsed) {
    return 'تم استيراد النظير (v1): ⁨$parsed⁩';
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
  String get appTorWouldNotWake => 'لم يستيقظ tor';

  @override
  String get appCheckStarted => 'بدأ';

  @override
  String get appTorNotReadyIn => 'لم يجهز tor خلال ٧٥ ث';

  @override
  String get appOk => 'تم';

  @override
  String get appOkNoRelayBegan => 'تم، لم يبدأ أي مُرحِّل';

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
  String get appStartingTor => 'جارٍ تشغيل tor';

  @override
  String get appTimedMessagesAreNot =>
      'الرسائل المؤقتة لا تختفي. أعد تشغيل kryfo';

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
  String appJoinedButYourHello(Object linkName) {
    return 'انضممت إلى ⁨$linkName⁩، لكن تحيتك لا تزال معلّقة';
  }

  @override
  String appJoined(Object linkName) {
    return 'انضممت إلى ⁨$linkName⁩';
  }

  @override
  String appJoinedButTheCreator(Object linkName) {
    return 'انضممت إلى ⁨$linkName⁩، لكن تعذّر الوصول إلى منشئها حتى الآن';
  }

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
  String get appScanTheirCode => 'اقرأ رمزه';

  @override
  String get appAKryfoLinkA => 'رابط kryfo أو رابط غرفة أو ‎@wren';

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
  String get appStartingTor30s => 'جارٍ تشغيل tor (نحو ٣٠ ث)...';

  @override
  String get appScanOrImportA => 'اقرأ رمز نظير أو استورده أولًا';

  @override
  String get appEncryptingSending30s => 'جارٍ التشفير + الإرسال (نحو ٣٠ ث)...';

  @override
  String get appTapStartListeningFirst => 'اضغط «بدء الاستماع» أولًا';

  @override
  String get appYourKryfo => 'kryfo الخاص بك';

  @override
  String get appUriCopied => 'تم نسخ الرابط';

  @override
  String get appCopyUri => 'نسخ الرابط';

  @override
  String get appAddAKryfo => 'إضافة kryfo';

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
  String get appYourKryfo2 => 'kryfo الخاص بك:';

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
  String get appGettingMessages => 'استلام الرسائل ←';

  @override
  String get appDisableAppLock => 'تعطيل قفل التطبيق؟';

  @override
  String get appThePinWillBe =>
      'سيُزال رمز PIN. كل من يمسك هاتفك سيرى kryfo عندما يفتحه.';

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
  String get appReadyToSendPublishing => 'جاهز للإرسال · جارٍ نشر عنوانك';

  @override
  String get appReadyToSendFinishing => 'جاهز للإرسال · جارٍ إنهاء الإعداد';

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
      'يستغرق الاتصال الأول دقيقة أو دقيقتين ريثما يبني tor مسارًا خاصًا. بعد ذلك يُحفظ مؤقتًا، فيصبح فتح kryfo لاحقًا أسرع بكثير.';

  @override
  String get appRelayAndFastModes =>
      'وضعا المُرحِّل والسريع يتجاوزان tor وهما أسرع. تجدهما في الإعدادات، ضمن «السرعة والخصوصية»، وكلٌّ منهما يوضّح ما يكلّفه.';

  @override
  String get appViaRelay => 'عبر مُرحِّل';

  @override
  String get appOffline => 'غير متصل';

  @override
  String get appFast => 'سريع';

  @override
  String get appTorOff => 'Tor متوقف';

  @override
  String get appTorReady => 'Tor جاهز';

  @override
  String get appConnecting2 => 'جارٍ الاتصال';

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
  String get miuiAutostartLetKryfoRunIn => 'اسمح لـ kryfo بالعمل في الخلفية';

  @override
  String get miuiAutostartYourPhonePausesApps =>
      'يوقف هاتفك التطبيقات مؤقتًا لتوفير البطارية. ودون استثناء، لا يستطيع kryfo استلام الرسائل وهو مغلق.';

  @override
  String get commonAllow => 'السماح';

  @override
  String get commonSkip => 'تخطي';

  @override
  String get miuiAutostartXiaomiTurnsOffBackground =>
      'توقف شاومي تطبيقات الخلفية افتراضيًا. ودون التشغيل التلقائي، لا يستطيع kryfo إيصال الرسائل حين يكون التطبيق مغلقًا. في الشاشة التالية، ابحث عن kryfo في القائمة وفعّل المفتاح.';

  @override
  String get miuiAutostartOpenSettings => 'فتح الإعدادات';

  @override
  String get miuiAutostartCouldnTOpenIt =>
      'تعذّر فتحها. ابحث عن التشغيل التلقائي في إعدادات الهاتف';

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
  String get scamShieldLooksLikeAScam => 'يبدو احتيالًا';

  @override
  String scamShieldThisNameMatches(Object shown) {
    return 'هذا الاسم يطابق ⁨$shown⁩';
  }

  @override
  String scamShieldNameMatchesYourContact(Object shown) {
    return 'الاسم يطابق جهة اتصالك ⁨$shown⁩';
  }

  @override
  String scamShieldSameFaceAsYour(Object shown) {
    return 'نفس وجه جهة اتصالك ⁨$shown⁩';
  }

  @override
  String get scamShieldContainsACryptoAddress => 'يحتوي على عنوان عملة رقمية';

  @override
  String get scamShieldMentionsMoneyAndUrgency => 'يذكر المال والاستعجال معًا';

  @override
  String get scamShieldAsksYouToMove => 'يطلب منك الانتقال إلى تطبيق آخر';

  @override
  String get scamShieldLinksToALookalike => 'يحيل إلى موقع يشبه موقعًا معروفًا';

  @override
  String get scamShieldALongOpenerFrom =>
      'رسالة أولى طويلة من شخص بلا سجل سابق';

  @override
  String get scamShieldAsksForACode =>
      'يطلب رمزًا أو عبارة استرداد أو ملف استعادة';

  @override
  String scamShieldAlso(Object shown) {
    return 'أيضًا: الاسم يطابق جهة اتصالك ⁨$shown⁩';
  }

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
  String get backupPassphraseMustBeAt => 'يجب ألا تقل عبارة المرور عن ٦ أحرف';

  @override
  String get backupPassphrasesDonTMatch => 'عبارتا المرور غير متطابقتين';

  @override
  String get backupBackupSavedKeepThe =>
      'حُفظت النسخة الاحتياطية · احفظ عبارة المرور في مكان آمن';

  @override
  String get backupKryfoBackup => 'نسخة kryfo الاحتياطية';

  @override
  String get backupYourEncryptedKryfoBackup =>
      'نسخة kryfo الاحتياطية المشفّرة. احفظ هذا الملف وعبارة المرور معًا في مكان آمن - فالاستعادة تحتاج إليهما كليهما.';

  @override
  String get backupBackUpKryfo => 'نسخ kryfo احتياطيًا';

  @override
  String get backupBackUp => 'نسخ احتياطي';

  @override
  String get backupACopyToKeep => 'نسخة تحتفظ بها. ويبقى هذا الهاتف كما هو.';

  @override
  String get backupMoveToAnotherDevice => 'الانتقال إلى جهاز آخر';

  @override
  String get backupTheFileTakesThis =>
      'يأخذ الملف هذه الهوية معه. وبمجرد إنشائه يتوقف هذا الهاتف: لا يصل إليه شيء جديد، ولا يصل أي شيء يُرسل منه إلى أحد.';

  @override
  String get backupOneEncryptedFileYour =>
      'ملف واحد مشفّر: هويتك، وجهات اتصالك، وكل رسالة، وكل صورة ورسالة صوتية وملف. استورده على الجهاز الآخر بعبارة المرور. وإلى أن تفعل، يمكنك أن تغيّر رأيك وتبقى على هذا الهاتف.';

  @override
  String get backupOneEncryptedFileYourIdentityYour =>
      'ملف واحد مشفّر: هويتك، وجهات اتصالك، وكل رسالة، وكل صورة ورسالة صوتية وملف على هذا الهاتف الآن. ما يُقال بعد اليوم ليس فيه، فأنشئ نسخة أخرى حين يهمّك ذلك. للاستعادة تحتاج إلى الملف وعبارة المرور، كليهما.';

  @override
  String get backupPassphrase => 'عبارة المرور';

  @override
  String get backupConfirmPassphrase => 'تأكيد عبارة المرور';

  @override
  String backupWriting(Object progress) {
    return 'جارٍ الكتابة… ⁨$progress⁩';
  }

  @override
  String get backupCreating => 'جارٍ الإنشاء…';

  @override
  String get backupMakeTheFileAnd => 'إنشاء الملف والانتقال';

  @override
  String get backupCreateBackup => 'إنشاء نسخة احتياطية';

  @override
  String get blockedBlocked => 'المحظورون';

  @override
  String get blockedNoOneIsBlocked => 'لا أحد محظور';

  @override
  String get commonUnblock => 'إلغاء الحظر';

  @override
  String get bridgesThatWasNotIt => 'ليست هذه الإجابة. إليك لغزًا آخر.';

  @override
  String get bridgesGotBridgesSaveTo => 'وصلت الجسور · احفظها لاستخدامها';

  @override
  String get bridgesConnected => 'متصل';

  @override
  String get bridgesNotThroughYetTor => 'لم يعبر بعد. يواصل tor المحاولة';

  @override
  String get bridgesBridges => 'الجسور';

  @override
  String get bridgesTorIsBlockedWhere => 'هل tor محجوب حيث أنت؟';

  @override
  String get bridgesBridgesDisguiseYourConnection =>
      'تُموّه الجسور اتصالك ليتمكن من العبور. اختر طريقة دخول واحدة، واحفظ، فيعيد tor الاتصال عبرها.';

  @override
  String get bridgesBridgesOnlyChangeHow =>
      'الجسور لا تغيّر إلا طريقة اتصال tor، وأنت لست في وضع Onion الآن. ما تضبطه هنا يُحفظ، لكنه لا يفعل شيئًا حتى تعود إليه.';

  @override
  String get bridgesFromTheTorProject => 'من مشروع tor';

  @override
  String get bridgesNoise => 'ضجيج';

  @override
  String get bridgesGood => 'جيدة';

  @override
  String get bridgesMakesTorTrafficLook =>
      'يجعل حركة tor لا تشبه شيئًا بعينه. الخيار الافتراضي الأفضل لمعظم الشبكات المحجوبة. حُلّ اختبار تحقق، فتحصل على بضعة أسطر.';

  @override
  String get bridgesPrivateBridge => 'جسر خاص';

  @override
  String get bridgesALineFromA => 'سطر من صديق';

  @override
  String get bridgesWhateverTheLineSays => 'حسب ما في السطر';

  @override
  String get bridgesDepends => 'يتفاوت';

  @override
  String get bridgesGotABridgeLine =>
      'هل لديك سطر جسر من شخص تثق به، أو من bridges.torproject.org؟ الصقه هنا. أسطر obfs4 فقط، فـ kryfo لا يفهم غيرها بعد.';

  @override
  String get bridgesPasteFromClipboard => 'لصق من الحافظة';

  @override
  String get bridgesUseBridges => 'استخدام الجسور';

  @override
  String get bridgesNoLinesYet => 'لا أسطر بعد';

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
  String get bridgesRestartingTor => 'جارٍ إعادة تشغيل tor…';

  @override
  String bridgesFindingABridgeS(Object elapsed) {
    return 'جارٍ البحث عن جسر… ⁨$elapsed⁩ ث';
  }

  @override
  String bridgesStillTryingS(Object elapsed) {
    return 'ما زال يحاول… ⁨$elapsed⁩ ث';
  }

  @override
  String get bridgesApplying => 'جارٍ التطبيق…';

  @override
  String get bridgesSaveAndReconnect => 'حفظ وإعادة الاتصال';

  @override
  String get bridgesWhatABridgeIs => 'ما هو الجسر';

  @override
  String get bridgesATorEntryPoint =>
      'نقطة دخول إلى tor لم ينشرها أحد، يُوصل إليها عبر غلاف كي لا يبدو الاتصال كأنه tor. بقية المسار هي القفزات الثلاث المعتادة.';

  @override
  String get bridgesLooksLike => 'يشبه';

  @override
  String get bridgesSpeed => 'السرعة';

  @override
  String get bridgesGetBridges => 'الحصول على جسور';

  @override
  String get bridgesAskTheTorProject =>
      'اطلبها من مشروع tor مباشرة. تحلّ لغزًا كي لا تستنزف الروبوتات المخزون.';

  @override
  String get bridgesTypeWhatYouSee =>
      'اكتب ما تراه. الأحرف الصغيرة لا بأس بها.';

  @override
  String get bridgesThisOneRequestDoes =>
      'هذا الطلب وحده لا يمر عبر tor - ولا يمكنه ذلك، فـ tor هو ما لا يعمل. سيرى من يدير شبكتك أنك تتصل بمشروع tor. إن كان ذلك وحده مشكلة حيث أنت، فاحصل على الجسور من مكان آخر والصقها أدناه.';

  @override
  String get bridgesCouldNotDrawThe => 'تعذّر رسم اللغز';

  @override
  String get bridgesAnswer => 'الإجابة';

  @override
  String get bridgesAsking => 'جارٍ الطلب…';

  @override
  String get bridgesRequestBridges => 'طلب جسور';

  @override
  String get bridgesDifferentPuzzle => 'لغز آخر';

  @override
  String get cameraNoCameraOnThis => 'لا كاميرا في هذا الهاتف';

  @override
  String get cameraCameraNotAvailable => 'الكاميرا غير متاحة';

  @override
  String get cameraCameraPermissionIsOff =>
      'إذن الكاميرا معطّل · اضغط لإعادة المحاولة';

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
  String get cameraTooLongForA => 'أطول من أن يُرسل · ٨ م.ب كحد أقصى';

  @override
  String get cameraNeverSavedToYour => 'لا يُحفظ أبدًا في صورك';

  @override
  String get cameraNoExifNeverSaved => 'بلا EXIF، ولا يُحفظ أبدًا في صورك';

  @override
  String get cameraRec => 'تسجيل';

  @override
  String get cameraSwitchCamera => 'تبديل الكاميرا';

  @override
  String cameraClipSMb(Object secs, Object mb) {
    return 'مقطع · ⁨$secs⁩ ث · ⁨$mb⁩ م.ب';
  }

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
  String chatB(Object bytes) {
    return '⁨$bytes⁩ بايت';
  }

  @override
  String chatKb(Object bytes) {
    return '⁨$bytes⁩ ك.ب';
  }

  @override
  String chatMb(Object bytes) {
    return '⁨$bytes⁩ م.ب';
  }

  @override
  String get chatFile => 'ملف';

  @override
  String get chatYouAreOfflineThis =>
      'أنت غير متصل · ستُرسل تلقائيًا عند عودة الاتصال';

  @override
  String get chatStillConnectingToTor =>
      'ما زال الاتصال بـ tor جاريًا · ستُرسل من تلقاء نفسها';

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
      'ستختفي دون أثر. لا يمكن التراجع عن هذا.';

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
  String get chatHowLongBeforeSent => 'بعد كم من الوقت تختفي الرسائل المُرسلة؟';

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
    return '⁨$humanBytes⁩ · ⁨$wireEstimate⁩ عبر tor';
  }

  @override
  String get chatBigFilesGoOut =>
      'تُرسل الملفات الكبيرة على قطع صغيرة مشفّرة، لذا تستغرق بعض الوقت. أبقِ التطبيق مفتوحًا ويستمر الإرسال.';

  @override
  String get chatSendIt => 'إرساله';

  @override
  String get chatCouldNotReadThat => 'تعذّرت قراءة ذلك الملف';

  @override
  String get chatFileTooBig8 => 'الملف كبير جدًا · ٨ م.ب كحد أقصى';

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
  String get chatTorIsNotUp => 'لم يعمل tor بعد · سيُرسل دون معاينة';

  @override
  String get chatCouldnTReachIt => 'تعذّر الوصول إليه · سيُرسل دون معاينة';

  @override
  String get chatNoTitleCameBack => 'لم يُرجع عنوانًا · سيُرسل دون معاينة';

  @override
  String get chatCouldnTFetchIt => 'تعذّر جلبه · سيُرسل دون معاينة';

  @override
  String get chatNoSignalSessionRe => 'لا توجد جلسة Signal - أعد الاقتران';

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
  String get chatAQuietReminder => 'تذكير هادئ…';

  @override
  String get chatNoteSaved => 'حُفظت الملاحظة';

  @override
  String get chatClearThisConversation => 'إفراغ هذه المحادثة؟';

  @override
  String get chatEveryMessageHereIs =>
      'تُمسح كل رسالة هنا من هذا الهاتف. هذا يُفرغ نسختك فقط - ولا يمسّ جهازه.';

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
  String get chatLooksSafeNothingSuspicious =>
      'تبدو آمنة · لا شيء مريب في رسالته الأولى';

  @override
  String get chatTheNextPhotoYou =>
      'الصورة التالية التي ترسلها تُفتح محمية · لا يمكنه التقاط لقطة شاشة لها';

  @override
  String get chatPhotoProtectionOff => 'حماية الصور معطّلة';

  @override
  String get chatAcceptToReplyThey =>
      'اقبل لترد - يمكنه إرسال رسالة واحدة أخرى حتى تقبل.';

  @override
  String chatIntroducedYouAcceptTo(Object introducer) {
    return 'عرّفكما ⁨$introducer⁩ على بعضكما. اقبل لترد.';
  }

  @override
  String chatIntroducedYouSayHello(Object vouchNames) {
    return 'عرّفكما ⁨$vouchNames⁩ على بعضكما. قل مرحبًا - فقد وصلته بطاقتك أيضًا.';
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
  String get chatYouBlockedThisContact => 'لقد حظرت جهة الاتصال هذه';

  @override
  String get chatSupporter => 'داعم';

  @override
  String get chatEncryptedViaRelay => 'مشفّرة · عبر مُرحِّل';

  @override
  String get chatEncryptedDirect => 'مشفّرة · مباشرة';

  @override
  String get chatEncryptedOverTor => 'مشفّرة · عبر tor';

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
  String get chatWaitingForThemToComeOnline => 'بانتظار أن يتصل أو يضيفك بدوره';

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
  String get chatDisguiseVoice => 'تمويه الصوت';

  @override
  String get commonSend => 'إرسال';

  @override
  String get chatNoPhotosInThis => 'لا صور في هذه المحادثة بعد';

  @override
  String get chatSendPhoto => 'إرسال الصورة';

  @override
  String get chatAddACaption => 'أضف تعليقًا…';

  @override
  String get chatSecurityCodeChanged => 'تغيّر رمز الأمان';

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
      'لا يستطيع kryfo تنظيف هذا النوع من الملفات بعد.';

  @override
  String get cleanThisIsAMotion => 'هذه صورة متحركة.';

  @override
  String get cleanThisPictureIsToo => 'هذه الصورة أكبر من أن تُنظَّف هنا.';

  @override
  String get cleanThisFileIsDamaged => 'هذا الملف تالف أو مبتور.';

  @override
  String get cleanKryfoCouldNotMake => 'لم يستطع kryfo تنظيف هذا الملف.';

  @override
  String get cleanNotEnoughRoomOn => 'لا توجد مساحة كافية على الهاتف.';

  @override
  String get cleanKryfoCouldNotOpen => 'لم يستطع kryfo فتح ذلك الملف.';

  @override
  String get cleanItCleansJpegPng =>
      'يُنظّف ملفات JPEG وPNG وWebP وHEIC وAVIF وGIF وMP4 وMOV. لم يتغيّر شيء.';

  @override
  String get cleanItHoldsAShort =>
      'تحمل مقطع فيديو قصيرًا بجانب الصورة، ولا يستطيع kryfo تنظيف هذا الجزء بعد. أوقف خاصية الحركة في الكاميرا، أو أرسل لقطة شاشة لها.';

  @override
  String get cleanPicturesOver64Mb =>
      'الصور التي تتجاوز ٦٤ م.ب لا تُنظَّف على الهاتف. لم يتغيّر شيء.';

  @override
  String get cleanKryfoCouldNotRead =>
      'لم يستطع kryfo قراءته حتى النهاية، لذا لن يعدّه نظيفًا. لم تُنشأ أي نسخة.';

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
    return 'الأصل ما زال في مكانه، ⁨$what⁩ لا يستطيع kryfo إزالته من هنا، فاحذفه من التطبيق الذي جاء منه.';
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
  String get contactDeleteThisChat => 'حذف هذه المحادثة؟';

  @override
  String get contactEveryMessageAndThe =>
      'كل رسالة وجهة الاتصال نفسها، تُحذف من هذا الهاتف. ولا يُرسل إليه أي شيء.';

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
  String get donateKeepKryfo => 'أبقِ kryfo *مستقلًا*';

  @override
  String get donateNoAdsNoInvestors =>
      'لا إعلانات، ولا مستثمرون، ولا شيء للبيع. يعيش على ما يقدّمه الداعمون.';

  @override
  String get donateBackItAnonymouslyBadge =>
      'ادعمه دون أن تكشف هويتك. الشارة اختيارية.\n*الخصوصية لن تكون أبدًا خلف جدار دفع.*';

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
  String get donateReachingThePaymentService =>
      'جارٍ الوصول إلى خدمة الدفع عبر tor…';

  @override
  String get donateThisCanTakeUp => 'قد يستغرق هذا حتى دقيقة';

  @override
  String donateSThisCanTake(Object waited) {
    return '⁨$waited⁩ ث · قد يستغرق هذا حتى دقيقة';
  }

  @override
  String get donateUseTheAddressInstead => 'استخدام العنوان بدلًا من ذلك';

  @override
  String get donateThePaymentServiceIs =>
      'خدمة الدفع عنوان onion، ولا يصل إليها إلا وضع Onion. لم يُرسل شيء.';

  @override
  String get donateTorWasSlowTo =>
      'تأخر tor في الوصول إلى خدمة الدفع. يمكنك التبرع إلى العنوان أدناه - لكن شارتك لن تُفتح تلقائيًا. أعد المحاولة لاحقًا للحصول على الشارة.';

  @override
  String get donateThePaymentServiceIsHavingTrouble =>
      'تواجه خدمة الدفع مشكلة الآن. ما زال بإمكانك التبرع إلى العنوان أدناه - لكن شارتك لن تُفتح تلقائيًا. أعد المحاولة لاحقًا للحصول على الشارة.';

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
      'تتحدّث هذه الشاشة تلقائيًا لحظة رصد دفعتك.\nأبقِها مفتوحة - لا يُخزَّن شيء، ولا شيء يكشف هويتك.';

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
  String get donatePaymentConfirmed => 'تأكّدت الدفعة';

  @override
  String get donateThankYouForKeeping => 'شكرًا لأنك تُبقي kryfo مستقلًا.';

  @override
  String donateVerifiedOnChainYou(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter':
          'تم التحقق على السلسلة - أنت الآن داعم. لا أحد يستطيع أن ينزع ذلك منك.',
      'patron':
          'تم التحقق على السلسلة - أنت الآن راعٍ. لا أحد يستطيع أن ينزع ذلك منك.',
      'guardian':
          'تم التحقق على السلسلة - أنت الآن حارس. لا أحد يستطيع أن ينزع ذلك منك.',
      'other':
          'تم التحقق على السلسلة - أنت الآن داعم. لا أحد يستطيع أن ينزع ذلك منك.',
    });
    return '$_temp0';
  }

  @override
  String get donateWearMyBadge => 'إظهار شارتي';

  @override
  String get donateJustGladToHelp => 'يكفيني أني ساعدت';

  @override
  String get gettingMessagesGettingMessages => 'استلام الرسائل';

  @override
  String get gettingMessagesHowNewMessagesReach =>
      'كيف تصل الرسائل الجديدة إلى هذا الهاتف. يمكنك تغيير ذلك متى شئت.';

  @override
  String get gettingMessagesAlwaysOn => 'متصل دائمًا';

  @override
  String get gettingMessagesMostPrivate => 'الأكثر خصوصية';

  @override
  String get gettingMessagesMessagesArriveInstantlyNothing =>
      'تصل الرسائل فورًا. لا شيء يمر خارج tor. يستهلك البطارية أكثر من غيره.';

  @override
  String get gettingMessagesCheckIns => 'تفقّد دوري';

  @override
  String get gettingMessagesLightest => 'الأخف';

  @override
  String get gettingMessagesKryfoLooksForMessages =>
      'يبحث kryfo عن الرسائل كل ١٥ دقيقة. خفيف على البطارية، لكن قد تتأخر الرسائل.';

  @override
  String get gettingMessagesOnTheLockScreen => 'على شاشة القفل';

  @override
  String get gettingMessagesHideMessagePreview => 'إخفاء معاينة الرسائل';

  @override
  String get gettingMessagesAGenericAlertWith =>
      'تنبيه عام، بلا مرسِل ولا نص رسالة';

  @override
  String get gettingMessagesShowsMessageTextIn =>
      'يُظهر نص الرسائل في الإشعارات، حتى عندما يكون kryfo مقفلًا.';

  @override
  String get gettingMessagesWhenThePhoneSits =>
      'حين يبقى الهاتف ساكنًا، يباعد أندرويد بين مرات التفقّد. يُظهر السطر أعلاه آخر تفقّد فعلي. وما دام kryfo مفتوحًا يبقى متصلًا.';

  @override
  String get groupChatJumpToTheNewest => 'الانتقال إلى الأحدث';

  @override
  String get groupChatBlockedEverywhere => 'محظور في كل مكان';

  @override
  String get groupChatYou => 'أنت';

  @override
  String get groupChatVoiceMessage => 'رسالة صوتية';

  @override
  String get groupChatQuotedPhoto => 'صورة';

  @override
  String get groupChatMessageUnavailable => 'الرسالة غير متاحة';

  @override
  String get groupChatTorIsNotUp => 'لم يعمل tor بعد · سيُرسل دون معاينة';

  @override
  String get groupChatCouldnTReachIt => 'تعذّر الوصول إليه · سيُرسل دون معاينة';

  @override
  String get groupChatNoTitleCameBack => 'لم يُرجع عنوانًا · سيُرسل دون معاينة';

  @override
  String get groupChatCouldnTFetchIt => 'تعذّر جلبه · سيُرسل دون معاينة';

  @override
  String get groupChatCamera => 'الكاميرا';

  @override
  String get groupChatGallery => 'المعرض';

  @override
  String get groupChatVideo => 'فيديو';

  @override
  String get groupChatGifFromPhone => 'صورة GIF من الهاتف';

  @override
  String get groupChatFile => 'ملف';

  @override
  String get groupChatCouldNotReadThat => 'تعذّرت قراءة ذلك الملف';

  @override
  String get groupChatGifTooBig8 => 'ملف GIF كبير جدًا · ٨ م.ب كحد أقصى';

  @override
  String get groupChatCouldNotCleanThat => 'تعذّر تنظيف ملف GIF هذا';

  @override
  String get groupChatFileTooBig8 => 'الملف كبير جدًا · ٨ م.ب كحد أقصى';

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
  String get groupChatNewMessagesDisappearAfter =>
      'تختفي الرسائل الجديدة بعد هذه المدة';

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
      'ستختفي دون أثر. لا يمكن التراجع عن هذا.';

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
  String get groupChatDisguiseVoice => 'تمويه الصوت';

  @override
  String get groupChatSupporter => 'داعم';

  @override
  String get groupChatEdited => 'معدّلة';

  @override
  String get groupChatTapToRetry => '! اضغط لإعادة المحاولة';

  @override
  String get groupChat0s => '٠ ث';

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
  String get commonRemove => 'إزالة';

  @override
  String get groupInfoClearThisConversation => 'إفراغ هذه المحادثة؟';

  @override
  String get groupInfoEveryMessageHereIs =>
      'تُمسح كل رسالة هنا من هذا الهاتف. هذا يُفرغ نسختك فقط، ويحتفظ الأعضاء الآخرون بنسخهم.';

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
  String get groupInfoYouWillStopReceiving =>
      'ستتوقف عن تلقي الرسائل وسيرى الأعضاء الآخرون أنك غادرت.';

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
  String get handleWren => 'wren';

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
  String get handleChecking => 'جارٍ التحقق…';

  @override
  String get handleAvailable => '✓ متاح';

  @override
  String get handleAlreadyTaken => 'محجوز بالفعل';

  @override
  String get handleWhatAHandleDoes => 'ما فائدة اسم المستخدم';

  @override
  String get handleAnyoneWhoKnowsIt =>
      'يمكن لأي شخص يعرفه أن يطلب مراسلتك، وهذا هو الغرض منه. تحمل الصفحة دعوتك والسطر الذي كتبته، لا شيء غير ذلك، ولا تحتفظ بأي سجل لمن يقرؤها. يمكنك حذفه متى شئت.';

  @override
  String handleIsNotYoursOn(Object handle) {
    return '⁦@$handle⁩ ليس لك على هذا الهاتف';
  }

  @override
  String handleTheRegistryHoldsIt(Object handle) {
    return 'يحتفظ به السجل تحت مفتاح مختلف، والأرجح أنه هوية كانت على هذا الهاتف قبل استعادة. من يضيف ⁦@$handle⁩ لا يصل إليك. لا يمكن تحريره أو تحديثه من هنا. اختر اسمًا آخر.';
  }

  @override
  String get handleForgetItOnThis => 'انسَه على هذا الهاتف';

  @override
  String get homeAddAContact => 'إضافة جهة اتصال';

  @override
  String get commonSettings => 'الإعدادات';

  @override
  String get homeYourKryfo => 'kryfo الخاص بك';

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
    return 'لم يتمكن tor من الاتصال منذ ⁨$howLong⁩. لا شيء يمكنه الوصول أو المغادرة حتى يتصل.';
  }

  @override
  String get homeReconnecting => 'جارٍ إعادة الاتصال';

  @override
  String get homeReconnect => 'إعادة الاتصال';

  @override
  String get homeWhatIsWrong => 'ما المشكلة';

  @override
  String get homeKryfoWillCheckIn => 'سيتفقّد kryfo الرسائل كل ١٥ دقيقة';

  @override
  String get homeYourPhoneKeepsStopping => 'هاتفك يوقف kryfo مرارًا';

  @override
  String get homeItHasClosedKryfo =>
      'أغلق kryfo ثلاث مرات اليوم، فتأخرت الرسائل أو انتظرت. التفقّد الدوري يصمد أمام ذلك: يستيقظ kryfo كل ١٥ دقيقة بدلًا من البقاء متصلًا.';

  @override
  String get homeSwitchToCheckIns => 'التبديل إلى التفقّد الدوري';

  @override
  String get homeNotNow => 'ليس الآن';

  @override
  String get homeNotificationsAreOff => 'الإشعارات معطّلة';

  @override
  String get homeAndroidIsBlockingThem =>
      'أندرويد يحجبها، فلا يصلك شيء ما دام kryfo مغلقًا. ولا تزال الرسائل تصل عندما تفتحه.';

  @override
  String get homeCouldnTOpenIt =>
      'تعذّر فتحها. ابحث عن kryfo في إعدادات الهاتف';

  @override
  String get homeTurnThemOn => 'تفعيلها';

  @override
  String get homeLeaveThemOff => 'إبقاؤها معطّلة';

  @override
  String get homeOurRelayIsQuiet => 'مُرحِّلنا صامت';

  @override
  String get homeRelayModeUsesOnly =>
      'وضع المُرحِّل يستخدم مُرحِّلنا وحده، وهو لا يستجيب الآن. الوضع السريع يضيف مُرحِّلات عامة إلى جانبه، فتصل الرسائل رغم ذلك. ويبقى كل شيء مختومًا في الحالتين.';

  @override
  String get homeSwitchedToFast => 'الوضع السريع مفعّل';

  @override
  String get homeUseFastMode => 'استخدام الوضع السريع';

  @override
  String get homeKeepWaiting => 'مواصلة الانتظار';

  @override
  String get homeNotConnecting => 'لا يتصل';

  @override
  String get homeBridgesAreOnAnd =>
      'الجسور مفعّلة وما زال tor لم يعبر. الجسور أبطأ، وبعضها يتوقف دون إنذار. إن لم تكن شبكتك تحجب tor، فالاتصال المباشر أسرع وأكثر موثوقية.';

  @override
  String get homeGoingDirectReconnecting => 'اتصال مباشر · جارٍ إعادة الاتصال';

  @override
  String get homeTurnBridgesOff => 'إيقاف الجسور';

  @override
  String get homeStillTrying => 'ما زال يحاول';

  @override
  String get homeTorIsNotGetting =>
      'لا يستطيع tor العبور. بعض الشبكات تحجبه عمدًا. مُرحِّلنا الخاص اتصال عادي واحد وغالبًا ما يعمل رغم ذلك - أو الجسور، وإعدادها يستغرق وقتًا أطول.';

  @override
  String get homeSwitchedToRelay => 'وضع المُرحِّل مفعّل';

  @override
  String get homeUseOurRelay => 'استخدام مُرحِّلنا';

  @override
  String get homeBridges => 'الجسور';

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
  String homeWaitingTorIsStill(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$countString⁩ في الانتظار · ما زال tor يتصل',
    );
    return '$_temp0';
  }

  @override
  String homeWaitingForThemTo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$countString⁩ في الانتظار · حتى يُعيدوا إضافتك',
    );
    return '$_temp0';
  }

  @override
  String homeWaitingForThemToAddYou(int count, int parked) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);
    final intl.NumberFormat parkedNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String parkedString = parkedNumberFormat.format(parked);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '⁨$countString⁩ في الانتظار · ⁨$parkedString⁩ منها حتى يُعيدوا إضافتك',
    );
    return '$_temp0';
  }

  @override
  String homeWaitingSendingNow(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$countString⁩ في الانتظار · جارٍ الإرسال الآن',
    );
    return '$_temp0';
  }

  @override
  String get commonRetry => 'أعد المحاولة';

  @override
  String get homeNoKryfosYet => 'لا جهات اتصال بعد.';

  @override
  String get homeScanTheirCodeSend =>
      'اقرأ رمزه بالكاميرا، أو أرسل له رابطًا، أو اكتب اسم المستخدم الذي أعطاك إياه.';

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
  String get homeArchivedChats => 'المحادثات المؤرشفة';

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
  String get homeDeleteThisChat => 'حذف هذه المحادثة؟';

  @override
  String homeEveryMessageWithGoes(Object c) {
    return 'تُحذف كل رسالة مع ⁨$c⁩، ولا يعود جهة اتصال. هذا يُفرغ هذا الهاتف فقط - تبقى نسخته لديه. وإن راسلك مجددًا فستصل رسالته إلى الطلبات.';
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
  String get introduceANoteLikeMy => 'ملاحظة، مثل «ابن عمي» - اختيارية';

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
  String keyVerificationWith(Object peerName) {
    return 'مع ⁨$peerName⁩';
  }

  @override
  String keyVerificationIfSeesTheSame(Object peerName) {
    return 'إن رأى ⁨$peerName⁩ الرقم نفسه، فرسائلكما خاصة بكما وحدكما. المقارنة وجهًا لوجه أو عبر مكالمة تثق بها هي أضمن طريقة للتأكد - لكنها اختيارية، وليست شرطًا للمراسلة أبدًا.';
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
      'لم يستطع kryfo قراءة الملف أو الكتابة فيه.';

  @override
  String get lockFileCheckCapitalsAndSpaces =>
      'تحقّق من الأحرف الكبيرة والمسافات. لا أحد يستطيع إعادة تعيينها، ولا نحن.';

  @override
  String get lockFileItMayHaveBeen =>
      'ربما انقطع في الطريق. اطلب إرساله مجددًا. لم يُحفظ شيء.';

  @override
  String get lockFileItOpensWithThe =>
      'يُفتح بملف مفتاح الشخص الذي صُنع له، بأداة age على حاسوب. أما kryfo فيفتح النوع المحمي بكلمة مرور.';

  @override
  String get lockFileKryfoOpensFilesLocked =>
      'يفتح kryfo الملفات المقفلة بـ age، وعادةً ما تنتهي أسماؤها بـ ‎.age';

  @override
  String get lockFileCloseAFewApps =>
      'أغلق بعض التطبيقات ثم أعد المحاولة. يحتاج فحص كلمة المرور إلى بضع مئات من الميغابايتات للحظة.';

  @override
  String get lockFileNothingWasSaved => 'لم يُحفظ شيء.';

  @override
  String get lockFileTypeOneOrLet =>
      'اكتب واحدة، أو دع kryfo يقترح أربع كلمات.';

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
      'يمكن لأي شخص يملك كلمة المرور فتحه، في kryfo أو على أي حاسوب بأداة age المجانية. إن نسيتها ضاع الملف إلى الأبد. لا أحد يستطيع إعادة تعيينها، ولا نحن.';

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
      'لا يوجد kryfo لدى الطرف الآخر؟ على حاسوب:';

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
  String get lockSetupThatIsYourWipe => 'هذا رمز PIN للمسح. اختر غيره.';

  @override
  String get lockSetupUnlockWithFingerprint => 'فتح القفل بالبصمة؟';

  @override
  String get lockSetupThePinStillWorks =>
      'يبقى رمز PIN صالحًا متى أردته. هذا أسرع فقط.';

  @override
  String get lockSetupUseFingerprint => 'استخدام البصمة';

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
  String get modesOnion => 'Onion';

  @override
  String get modesFullOnionRoutingThree =>
      'توجيه onion كامل، ثلاث قفزات. تستغرق الرسالة من ثانيتين إلى خمس ثوانٍ. لا أحد يرى مع من تتحدث.';

  @override
  String get modesSlower => 'أبطأ';

  @override
  String get modesRelay => 'مُرحِّل';

  @override
  String get modesOneSealedConnectionTo =>
      'اتصال واحد مختوم بمُرحِّل kryfo الخاص، مثل VPN لا يملك ما يسجّله. تصل الرسائل في نحو ثانية، ويعمل حيث يُحجب tor.';

  @override
  String get modesQuick => 'سريع';

  @override
  String get modesRelayOnly => 'المُرحِّل فقط';

  @override
  String get modesFast => 'سريع';

  @override
  String get modesPlainConnectionsToEvery =>
      'اتصالات عادية بكل المُرحِّلات. شبه فوري، والأقل خصوصية بين الثلاثة.';

  @override
  String get modesInstant => 'فوري';

  @override
  String get modesEveryRelayYouUse =>
      'كل مُرحِّل تستخدمه يعرف العنوان الذي تتصل منه، لا مُرحِّلنا وحده. تبقى الرسائل مختومة، لكن حقيقة أنك أرسلت رسالة ليست كذلك. معطّل افتراضيًا، ويعود معطّلًا بعد إعادة التثبيت.';

  @override
  String get modesSpeed => 'السرعة';

  @override
  String get modesPrivacy => 'والخصوصية';

  @override
  String get modesChangeGloballyOrPer => 'غيّره للكل، أو لكل محادثة';

  @override
  String get modesSoon => 'قريبًا';

  @override
  String get modesActive => 'مفعّل';

  @override
  String get modesSpeed2 => 'السرعة';

  @override
  String get modesHops => 'القفزات';

  @override
  String get modesIp => 'IP';

  @override
  String get modesVisible => 'ظاهر';

  @override
  String get modesHidden => 'مخفي';

  @override
  String modesHeadsUp(Object warning) {
    return '*تنبيه:* ⁨$warning⁩';
  }

  @override
  String get modesOnionIsTheDefault =>
      'وضع Onion هو الافتراضي ويبقى كذلك ما لم تغيّره. يسري التبديل من الرسالة التالية.';

  @override
  String get modesFastMode => 'الوضع السريع';

  @override
  String get modesPlainConnectionsToEveryRelayQuicker =>
      'اتصالات عادية بكل المُرحِّلات. أسرع، والمُرحِّلات تستطيع رؤية عنوان IP الخاص بك. تبقى الرسائل مشفّرة بين الطرفين في الحالتين.';

  @override
  String get modesTurnOnFastMode => 'تفعيل الوضع السريع';

  @override
  String get modesKeepItOff => 'إبقاؤه معطّلًا';

  @override
  String get movedWipeThisPhone => 'مسح Kryfo من هذا الهاتف؟';

  @override
  String get movedEverythingKryfoHoldsHere =>
      'يزول كل ما يحمله kryfo هنا: الرسائل، وجهات الاتصال، والمفاتيح. ويحتفظ الجهاز الآخر بكل ذلك. لا يمكن التراجع عن هذا.';

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
    return 'سيُغلق kryfo الآن. اضغط الأيقونة لإعادة فتحه باسم ⁨$myId⁩.';
  }

  @override
  String get movedReopenKryfo => 'إعادة فتح kryfo';

  @override
  String get movedThisKryfoHasMoved => 'انتقل kryfo هذا';

  @override
  String movedIsNowOnAnother(Object myId) {
    return 'أصبح ⁨$myId⁩ على جهاز آخر. ما زال بإمكان هذا الهاتف عرض ما كان هنا، لكن لن يصل إليه شيء جديد، وما ترسله من هنا لن يصل إلى أحد.';
  }

  @override
  String get movedKeepItToRead => 'الإبقاء عليه للقراءة';

  @override
  String get movedWipeThisPhone2 => 'مسح Kryfo من هذا الهاتف';

  @override
  String get movedIMNotMoving => 'عدلت عن الانتقال';

  @override
  String get myKryfoAHandleIs3 =>
      'اسم المستخدم من ٣ إلى ٢٠ حرفًا أو رقمًا أو _';

  @override
  String get myKryfoInviteCopiedClearsIn =>
      'نُسخت الدعوة · تُزال من الحافظة بعد ٦٠ ث';

  @override
  String myKryfoAddMeOnKryfo(Object myId, Object uri) {
    return 'أضفني على kryfo. معرّفي هو ⁨$myId⁩\n\nاضغط لإضافتي:\n⁨$uri⁩\n\nتطبيق kryfo للمراسلة الخاصة. بلا رقم هاتف، وبلا بريد إلكتروني.';
  }

  @override
  String get myKryfoAddMeOnKryfo2 => 'أضفني على kryfo';

  @override
  String get myKryfoAddSomeone => 'إضافة شخص';

  @override
  String get myKryfoKryfoDoesnTScan =>
      'لا يفحص kryfo جهات اتصالك، وهذا هو المقصود.';

  @override
  String get myKryfoIfThisLinkEnds =>
      'إن وصل هذا الرابط إلى مكان لم تقصده، فأعد تعيينه من الإعدادات. وعندها سيحتاج كل من لديه إلى رابط جديد.';

  @override
  String get myKryfoAlreadyShareAFriend =>
      'لديكما صديق مشترك على kryfo؟ يمكنه أن يعرّفكما على بعضكما من محادثته، فتتخطيان الطلب.';

  @override
  String get myKryfoHandleCopied => 'نُسخ اسم المستخدم';

  @override
  String get myKryfoTheyReHereWith => 'معي هنا';

  @override
  String get myKryfoPointYourPhonesAt =>
      'وجّه الهاتفين أحدهما نحو الآخر. لا يمر شيء عبر أي خادم.';

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
      'يحمل الرابط معرّفك وعنوانك والمفاتيح اللازمة لبدء محادثة. يبقى صالحًا حتى تعيد تعيينه من الإعدادات.';

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
  String get myKryfoWren => 'Wren';

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
  String get notesToday => 'اليوم';

  @override
  String get notesYesterday => 'أمس';

  @override
  String get notesNoteToSelf => 'ملاحظة لنفسي';

  @override
  String get notesOnlyOnThisPhone => 'على هذا الهاتف فقط';

  @override
  String get notesAQuietPlace => 'مكان هادئ';

  @override
  String get notesJotAnythingDownIt =>
      'دوّن أي شيء. يبقى على هذا الهاتف ولا يغادره أبدًا.';

  @override
  String get notesJotSomethingDown => 'دوّن شيئًا…';

  @override
  String get onboardingPrivateByDefault => 'خاص افتراضيًا';

  @override
  String get onboardingPrivateMessaging => 'مراسلة خاصة،\n*بلا ثمن خفي*.';

  @override
  String get onboardingYourNameIsThree =>
      '*اسمك ثلاث كلمات.* بلا هاتف، ولا بريد إلكتروني، ولا دفتر عناوين.';

  @override
  String get onboardingNobodyGetsInUnless =>
      '*لا يدخل أحد إلا إن سمحت له.* لا يوجد بحث. يُضاف الناس يدويًا، من الطرفين.';

  @override
  String get onboardingTheFirstConnectionTakes =>
      '*الاتصال الأول يستغرق دقيقة.* يبني kryfo مسارًا خاصًا قبل أن يرسل. ثم يصبح سريعًا.';

  @override
  String get onboardingBegin => 'ابدأ';

  @override
  String get onboardingHaveABackupRestore => 'لديك نسخة احتياطية؟ استعدها ←';

  @override
  String get onboardingKryfoIsOpenSource => 'Kryfo مفتوح المصدر';

  @override
  String get onboardingYourKryfoId => 'معرّف KRYFO الخاص بك';

  @override
  String get onboardingGeneratedFromAKey =>
      'مولَّد من مفتاح لا يوجد إلا على هذا الهاتف. *سهل التذكّر، فريد، لك وحدك.* لا أحد غيرك يملكه.';

  @override
  String get onboardingTryAnother => 'جرّب غيره';

  @override
  String get onboardingUseThisName => 'استخدم هذا الاسم ←';

  @override
  String get onboardingThreeWords => 'ثلاث كلمات. *لك وحدك.*';

  @override
  String get onboardingPickA => 'اختر *وجهًا*.';

  @override
  String get onboardingDrawnOnThisPhone =>
      'يُرسم على هذا الهاتف من رقم، ولا يُرفع أبدًا. غيّره متى شئت.';

  @override
  String get onboardingThePeopleYouMessage => 'يراه أيضًا من تراسلهم';

  @override
  String get onboardingKeepMyInitial => 'الإبقاء على حرفي الأول';

  @override
  String get onboardingThatOne => 'هذا ←';

  @override
  String get onboardingContinue => 'متابعة ←';

  @override
  String get onboardingHowYourMessages => 'كيف *تنتقل* رسائلك.';

  @override
  String get onboardingYouCanChangeThis =>
      'يمكنك تغيير هذا في أي وقت من الإعدادات، للجميع أو لمحادثة واحدة.';

  @override
  String get onboardingOnion => 'Onion';

  @override
  String get onboardingSlowerAMessageTakes =>
      'أبطأ. تستغرق الرسالة من ثانيتين إلى خمس ثوانٍ.';

  @override
  String get onboardingHidesYourAddressFrom =>
      'يُخفي عنوانك عن الجميع، بما في ذلك مُرحِّلنا.';

  @override
  String get onboardingRelay => 'مُرحِّل';

  @override
  String get onboardingOurRelaySeesYour =>
      'يرى مُرحِّلنا عنوانك. ولا أحد غيره.';

  @override
  String get onboardingAboutASecondWorks => 'نحو ثانية. يعمل حيث يُحجب tor.';

  @override
  String get onboardingFast => 'سريع';

  @override
  String get onboardingEveryRelayYouUse =>
      'كل مُرحِّل تستخدمه يرى عنوانك. الأقل خصوصية بين الثلاثة.';

  @override
  String get onboardingNearInstant => 'شبه فوري.';

  @override
  String get onboardingKeepOnion => 'الإبقاء على Onion ←';

  @override
  String get onboardingUseThis => 'استخدام هذا ←';

  @override
  String get onboardingSkipOnionIsA => 'تخطي · Onion خيار افتراضي جيد';

  @override
  String get onboardingThreeThingsThen => 'ثلاثة أشياء،\nثم *تدخل*.';

  @override
  String get onboardingEverythingElseTheApp =>
      'وكل ما عدا ذلك سيخبرك به التطبيق حين يهمّ.';

  @override
  String get onboardingYourNameIsThreeWords => 'اسمك ثلاث كلمات';

  @override
  String get onboardingThatIsTheWhole =>
      'هذه هي الهوية كلها. لا رقم يتسرّب، ولا بريد يُصطاد، ولا شيء يُبحث عنه. من تتحدث معهم يرون هذه الكلمات والوجه الذي اخترته.';

  @override
  String get onboardingNobodyCanReachYou =>
      'لا أحد يستطيع الوصول إليك حتى تسمح له بالدخول';

  @override
  String get onboardingAStrangerWithYour =>
      'الغريب الذي يعرف كلماتك لا يستطيع إلا أن يطرق الباب. تنتظر رسالته الأولى في الطلبات حتى توافق، ويمكنك الرفض دون أن يعلم أبدًا.';

  @override
  String get onboardingTheFirstConnectionTakesAMinute =>
      'الاتصال الأول يستغرق دقيقة';

  @override
  String get onboardingKryfoBuildsAPrivateRouteBefore =>
      'يبني kryfo مسارًا خاصًا قبل أن يرسل أي شيء. وحين تكون غير متصل، تنتظر الرسائل وتصل عند عودتك.';

  @override
  String get onboardingYourIdentityLivesOn =>
      'هويتك موجودة على هذا الهاتف. انسخها احتياطيًا من الإعدادات حين تكون مستعدًا.';

  @override
  String get onboardingIUnderstand => 'فهمت ←';

  @override
  String get onboardingOneQuiet => '*إشعار* واحد هادئ.';

  @override
  String get onboardingAndroidNeedsAVisible =>
      'يحتاج أندرويد إلى إشعار ظاهر ما دام تطبيق ما يستمع في الخلفية. بهذا تصلك الرسائل حين يكون kryfo مغلقًا.';

  @override
  String get onboardingSilentAndAtThe => 'صامت، وفي أسفل لوحة الإشعارات';

  @override
  String get onboardingItNeverBuzzesTurn =>
      'لا يهتز أبدًا. إن أوقفته، تنتظر الرسائل حتى تفتح التطبيق مجددًا.';

  @override
  String get onboardingGotIt => 'حسنًا ←';

  @override
  String get onboardingNow => 'والآن، *أضف شخصًا*.';

  @override
  String get onboardingTheAppIsReady =>
      'التطبيق جاهز. لا أحد يستطيع مراسلتك حتى تضيفه أو تسمح له بالدخول.';

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
  String get onboardingTheAppIsReadyWhenYou => 'التطبيق جاهز حين تكون مستعدًا.';

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
      'يُتحقق من كلمة المرور أولًا. وبعدها فقط يسأل kryfo أين يضع الملف المفتوح، فيذهب إلى هناك مباشرة.';

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
  String get pairCodeSixDigits => 'ستة أرقام';

  @override
  String get pairCodeLooking => 'جارٍ البحث…';

  @override
  String get pairCodeNothingThereYetTrying =>
      'لا شيء بعد · جارٍ إعادة المحاولة';

  @override
  String get pairCodeNothingAtThatCode =>
      'لا شيء عند هذا الرمز. ربما اختفى، أو لم يشاركه بعد.';

  @override
  String get pairCodeTypeTheSixDigits => 'اكتب الأرقام الستة التي قرأها عليك.';

  @override
  String get pairCodeAddThem => 'أضِفه';

  @override
  String get panicSetupThoseWereDifferentFrom => 'لم يتطابقا. من البداية.';

  @override
  String get panicSetupThatIsYourReal => 'هذا رمز PIN الحقيقي. اختر غيره.';

  @override
  String get panicSetupOnceMore => 'مرة أخرى';

  @override
  String get panicSetupSetAWipePin => 'تعيين رمز PIN للمسح';

  @override
  String get panicSetupTheSameFourDigits => 'الأرقام نفسها مرة أخرى';

  @override
  String get panicSetupTheSecondPinWipes => 'رمز PIN الثاني يمسح كل شيء.';

  @override
  String get photoKnowsEverythingInside => 'كل ما في داخله';

  @override
  String get photoKnowsVideo => 'فيديو';

  @override
  String get photoKnowsPhoto => 'صورة';

  @override
  String get photoKnowsWhatThisVideoKnows => 'ما يعرفه هذا الفيديو';

  @override
  String get photoKnowsWhatThisPhotoKnows => 'ما تعرفه هذه الصورة';

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
  String get pinsTwoPins => 'رمزا PIN';

  @override
  String get pinsYourPin => 'رمز PIN';

  @override
  String get commonOn => 'مفعّل';

  @override
  String get commonOff => 'معطّل';

  @override
  String get pinsOpensKryfoFourDigits =>
      'يفتح kryfo. يُطلب حين يعود التطبيق إلى الواجهة.';

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
      'يُزال رمز PIN، ومعه رمز PIN للمسح. وكل من يمسك هاتفك يفتح kryfo باسمك.';

  @override
  String get pinsUnlockWithFingerprint => 'فتح القفل بالبصمة';

  @override
  String get pinsWipePin => 'رمز PIN للمسح';

  @override
  String get pinsNeedsAPinFirst => 'يلزم رمز PIN أولًا';

  @override
  String get pinsSet => 'تعيين';

  @override
  String get pinsTheSecondPinWipes => 'رمز PIN الثاني يمسح كل شيء.';

  @override
  String get pinsChangeWipePin => 'تغيير رمز PIN للمسح';

  @override
  String get pinsSetAWipePin => 'تعيين رمز PIN للمسح';

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
  String get profileChangeYourFace => 'تغيير وجهك';

  @override
  String get profileKryfoId => 'معرّف kryfo';

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
  String get profileMyKryfoCode => 'رمزي في kryfo';

  @override
  String get profileAddContact => 'إضافة جهة اتصال';

  @override
  String get profileGiveAgain => 'التبرع مجددًا';

  @override
  String get profileSupportKryfo => 'ادعم kryfo';

  @override
  String get profileKryfoRunsOnWhat => 'يعيش kryfo على ما يقدّمه الناس';

  @override
  String get profileKeepKryfoIndependent => 'أبقِ kryfo مستقلًا';

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
  String get requestsBlocked => 'محظور';

  @override
  String get requestsDeleted => 'محذوف';

  @override
  String get requestsRequests => 'الطلبات';

  @override
  String get requestsNoRequests => 'لا طلبات';

  @override
  String get requestsMessagesFromPeopleYou =>
      'تظهر هنا أولًا رسائل من لم تُضِفهم.';

  @override
  String get requestsLooksSafeNothingSuspicious =>
      'تبدو آمنة · لا شيء مريب في رسالته الأولى';

  @override
  String get commonAccept => 'قبول';

  @override
  String get requestsDecline => 'رفض';

  @override
  String get restoreThatFileIsNot => 'هذا الملف ليس نسخة احتياطية من kryfo';

  @override
  String get restoreThisFileIsDamaged => 'هذا الملف تالف ولا يمكن قراءته';

  @override
  String get restoreTypeThePassphraseThe =>
      'اكتب عبارة المرور التي أُنشئ بها الملف';

  @override
  String get restoreReplaceTheAccountOn => 'استبدال الحساب على هذا الهاتف؟';

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
  String get restoreRestoreAnyway => 'الاستعادة على أي حال';

  @override
  String get restoreNotYet => 'ليس بعد';

  @override
  String get restoreRestored => 'تمت الاستعادة';

  @override
  String restoreKryfoWillCloseNow(Object haloId) {
    return 'سيُغلق kryfo الآن. اضغط الأيقونة لإعادة فتحه باسم ⁨$haloId⁩.';
  }

  @override
  String get restoreReopenKryfo => 'إعادة فتح kryfo';

  @override
  String get restoreTheRestoreDidNot => 'لم تكتمل الاستعادة. لم يتغيّر شيء';

  @override
  String get restoreThisIdentity => 'هذه الهوية';

  @override
  String get restoreMoveYourKryfoHere => 'انقل kryfo الخاص بك إلى هنا';

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
  String get restoreYourSupporterBadgeIf => 'شارة الداعم، إن كانت لديك.';

  @override
  String get restoreWhatDoesnT => 'ما لا ينتقل';

  @override
  String get restoreTheOldPhoneStops =>
      'يتوقف الهاتف القديم عن الاستلام لحظة ترسل أي شيء من هنا. لا تدريجيًا. أول رسالة ترسلها من هذا الجهاز هي آخر ما يستطيع الهاتف القديم متابعته، وكل ما يصله بعد ذلك لا يمكن قراءته هناك، ولا ينتظرك هنا أيضًا.';

  @override
  String get restoreIfThePhoneThis =>
      'إن كان الهاتف الذي جاء منه هذا الملف ما زال مستخدمًا، فتوقف عن استخدام kryfo عليه قبل أن تتابع. هاتفان على kryfo واحد يفقدان الرسائل كلاهما.';

  @override
  String get restoreNotificationsNeedSettingUp =>
      'يجب إعداد الإشعارات من جديد على هذا الجهاز.';

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
  String get roomCreateOffAnyoneWithThe => 'معطّل. أي شخص لديه الرابط';

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
  String get savedLongPressAnyMessage =>
      'اضغط مطولًا على أي رسالة ثم اختر «حفظ» لتبقى هنا.';

  @override
  String get savedViewInChat => 'عرض في المحادثة';

  @override
  String get savedPhoto2 => 'صورة';

  @override
  String get scanThatSNotA => 'هذا ليس رمز QR من kryfo · واصل التوجيه';

  @override
  String get scanScanAKryfoQr => 'قراءة رمز QR من kryfo';

  @override
  String get scanFlash => 'الفلاش';

  @override
  String get scanPointAtAKryfo =>
      'وجّه نحو رمز QR من kryfo · لا شيء يغادر هاتفك';

  @override
  String get seenWhatWeCanSee => 'ما يمكننا رؤيته';

  @override
  String get seenEveryMessengerClaimsPrivacy =>
      'كل تطبيق مراسلة يدّعي الخصوصية. هذه هي القائمة المحددة، حسب المسار، بما فيها الأجزاء التي لا تُجمّلنا. اضغط على صف لتعرف السبب.';

  @override
  String get seenHonestAboutTheLast =>
      'بصراحة عن الصفوف الأخيرة: لهذا وُجد قفل التطبيق ورمز PIN للمسح والتخزين المشفّر، ولا أداة تحميك من شخص يمسك هاتفك وهو مفتوح. نموذج التهديدات الكامل موجود في THREAT_MODEL.md في المستودع، مكتوبًا وفق LINDDUN. الشيفرة مفتوحة، فلا شيء من هذا يحتاج إلى أن يؤخذ على الثقة.';

  @override
  String get seenHidden => 'مخفي';

  @override
  String get seenNever => 'أبدًا';

  @override
  String get seenOnDevice => 'على الجهاز';

  @override
  String get seenTiming => 'التوقيت';

  @override
  String get seenYours => 'مسؤوليتك';

  @override
  String get seenUnaudited => 'غير مُدقَّق';

  @override
  String get seenWhoYouTalkTo => 'مع من تتحدث';

  @override
  String get seenEachConversationGetsIts =>
      'لكل محادثة عنوانها الخاص، مشتق من المفتاحين. يرى المُرحِّل صناديق إيداع لا صلة بينها، لا شخصين.';

  @override
  String get seenWhatYouSay => 'ما تقوله';

  @override
  String get seenEndToEndEncrypted =>
      'مشفّر بين الطرفين بخوارزمية Double Ratchet من Signal، ثم مختوم مرة أخرى داخل غلاف هدية (gift wrap). لن نستطيع قراءته حتى لو حاولنا.';

  @override
  String get seenYourIpAddress => 'عنوان IP الخاص بك';

  @override
  String get seenOurRelay => 'مُرحِّلنا';

  @override
  String get seenEveryRelay => 'كل المُرحِّلات';

  @override
  String get seenOnOnionEverythingLeaves =>
      'في وضع Onion يخرج كل شيء عبر tor ولا يرى المُرحِّل إلا عقدة خروج، لا أنت أبدًا. في وضع المُرحِّل يذهب الاتصال مباشرة إلى مُرحِّلنا الخاص: لا شيء يمرّر عنوانك ولا شيء يُدوَّن، لكن ذلك الاتصال الواحد نراه نحن. في الوضع السريع يعرف كل مُرحِّل عام أنك اتصلت، لكن لا يعرف بمن ولا ماذا قلت.';

  @override
  String get seenYourContactGraph => 'شبكة معارفك';

  @override
  String get seenKryfoDoesNotScan =>
      'لا يفحص kryfo جهات اتصالك. وهذا هو المقصود. لا يوجد هنا رقم هاتف ليتسرّب.';

  @override
  String get seenIntroducer => 'من عرّفكما';

  @override
  String get seenWhenAContactIntroduces =>
      'حين تعرّفك جهة اتصال على شخص ما، تعرف تلك الجهة أنكما صرتما على اتصال. ولا أحد غيرها. يرى المُرحِّل نصًا مشفّرًا، ولا يرى أي خادم شبكة المعارف أبدًا.';

  @override
  String get seenTheScamShield => 'درع مكافحة الاحتيال';

  @override
  String get seenRunsOnYourPhone =>
      'يعمل على هاتفك بقواعد مضمّنة في التطبيق. بلا شبكة، ولا تنزيل قوائم. لا يقرأ إلا الرسالة الأولى من غريب، ولا يستطيع رؤية أي شيء ترسله إليك جهة اتصال.';

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
  String get seenOverTor => 'عبر tor';

  @override
  String get seenAPreviewIsFetched =>
      'يجلب المُرسِل المعاينة عبر tor، وتنتقل داخل الرسالة المشفّرة. الهاتف المستقبِل لا يرسل أي طلب. يعرف الموقع أن شخصًا يستخدم tor طلب صفحة، ولا شيء آخر. لا تُحمَّل أي صورة أبدًا، ويبقى رابط الغريب نصًا عاديًا.';

  @override
  String get seenThatADeviceFetched => 'أن جهازًا ما جلب بريده';

  @override
  String get seenARelayCanTell =>
      'يستطيع المُرحِّل معرفة أن عنوانًا ما قد فُحص، ومتى. ولا يستطيع معرفة لمن، أو من أين.';

  @override
  String get seenASeizedUnlockedPhone => 'هاتف مُصادَر غير مقفل';

  @override
  String get seenIfSomeoneHoldsYour =>
      'إن أمسك أحدٌ هاتفك وهو مفتوح، فسيقرأ رسائلك. قفل التطبيق ورمز PIN للمسح والتخزين المشفّر تساعد قبل تلك اللحظة، لا بعدها.';

  @override
  String get seenTheCryptoItself => 'التشفير نفسه';

  @override
  String get seenTheRatchetAndStorage =>
      'طبقتا ratchet والتخزين معياريتان. أما الطبقة التي تربطهما فمن صنعنا ولم يراجعها أي طرف مستقل. تعامل مع هذا كإصدار ألفا، لأنه كذلك.';

  @override
  String get seenOnion => 'Onion';

  @override
  String get seenRelay => 'مُرحِّل';

  @override
  String get seenFast => 'سريع';

  @override
  String get settingsWipeKryfo => 'مسح kryfo؟';

  @override
  String get settingsIdentityMessagesContactsAnd =>
      'الهوية والرسائل وجهات الاتصال والإعدادات على هذا الهاتف. تزول إلى الأبد ما لم تكن لديك نسخة احتياطية.';

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
  String get settingsWipeKryfo2 => 'مسح kryfo';

  @override
  String get settingsYourProtections => 'وسائل حمايتك';

  @override
  String get settingsTorRouting => 'التوجيه عبر tor';

  @override
  String get settingsConnecting => 'جارٍ الاتصال';

  @override
  String get settingsOffMode => 'معطّل · وضع المُرحِّل';

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
  String get settingsRelay1Hop => 'مُرحِّل · قفزة واحدة';

  @override
  String get settingsOnion3Hops => 'Onion · ثلاث قفزات';

  @override
  String get settingsBridges => 'الجسور';

  @override
  String get settingsForNetworksThatBlock => 'للشبكات التي تحجب tor';

  @override
  String get settingsGettingMessages => 'استلام الرسائل';

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
  String get settingsChecksStrangersOnYour =>
      'يفحص الغرباء على هاتفك. لا شيء يغادره';

  @override
  String get settingsBlockScreenshots => 'منع لقطات الشاشة';

  @override
  String get settingsWholeAppHiddenFrom =>
      'التطبيق كله مخفي من التطبيقات الأخيرة ولقطات الشاشة · يسري بعد التشغيل التالي';

  @override
  String get settingsWholeAppHiddenFromRecentsAnd =>
      'التطبيق كله مخفي من التطبيقات الأخيرة ولقطات الشاشة';

  @override
  String get settingsOnNextStart => 'مفعّل · التشغيل التالي';

  @override
  String get settingsOffNextStart => 'معطّل · التشغيل التالي';

  @override
  String get settingsLightTheme => 'المظهر الفاتح';

  @override
  String get settingsSameProtectionBrighter => 'الحماية نفسها، بإضاءة أكثر';

  @override
  String get settingsAppLock2 => 'قفل التطبيق';

  @override
  String get settingsYourPinAndA => 'رمز PIN، ورمز PIN للمسح';

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
  String get settingsDisguiseVoice => 'تمويه الصوت';

  @override
  String get settingsShiftsYourPitchBefore =>
      'يغيّر طبقة صوتك قبل أن تغادر الرسالة الصوتية';

  @override
  String get settingsWhyKryfo => 'لماذا kryfo';

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
  String get settings030Alpha => '0.4.0 · ألفا';

  @override
  String get settingsReportAnIssue => 'الإبلاغ عن مشكلة';

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
      'لم يخضع لتدقيق مستقل. إصدار ما قبل ألفا - صالح للتجربة، لا للاستخدام في المواقف عالية المخاطر بعد.';

  @override
  String get settingsDangerZone => 'منطقة الخطر';

  @override
  String get settingsWipeKryfoFromThis => 'مسح kryfo من هذا الهاتف';

  @override
  String get shieldCheckedOnThisPhone =>
      'فُحص على هذا الهاتف. لم يُرسل شيء إلى أي مكان.';

  @override
  String get toolsMoreTools => 'أدوات أخرى';

  @override
  String get toolsCleanAPhotoOr => 'تنظيف صورة أو فيديو';

  @override
  String get toolsOrShareOneTo => 'أو شاركها مع kryfo من معرضك';

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
      'كل شيء هنا يحدث على هذا الهاتف. لا يُرفع شيء، ولا يحتاج أحد غيرك إلى أن يكون على kryfo.';

  @override
  String get toolsWhatDoesThisPhoto => 'ماذا تعرف هذه الصورة؟';

  @override
  String get toolsPlacePhoneTime => 'المكان · الهاتف · الوقت';

  @override
  String get toolsPickAPhotoAnd =>
      'اختر صورة وانظر ما تكشفه. ثم احتفظ بنسخة نظيفة.';

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
  String get transportSendAnythingWaitingNow => 'إرسال كل ما ينتظر، الآن';

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
  String get transportLastTorReconnect => 'آخر إعادة اتصال لـ tor';

  @override
  String get transportCatchUpByRelay => 'اللحاق عبر مُرحِّل';

  @override
  String get transportControlPort => 'منفذ التحكم';

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
  String get wallpaperFromYourPhotos => 'من صورك';

  @override
  String get wallpaperKeepIt => 'إبقاؤها';

  @override
  String get whyKryfoWhyKryfo => 'لماذا kryfo';

  @override
  String get whyKryfoKryfoKreeFoGreek =>
      'Kryfo · كري-فو · تعني «مخفي» باليونانية.\nمكان هادئ للحديث، بُني كي لا يراقبك أحد.';

  @override
  String get whyKryfoRoutedThroughTor => 'يمر عبر tor';

  @override
  String get whyKryfoByDefaultEveryMessage =>
      'افتراضيًا، تنتقل كل رسالة عبر tor - سلسلة من المُرحِّلات. لا أحد، لا نحن ولا شبكتك، يستطيع أن يرى مع من تتحدث أو أين أنت.';

  @override
  String get whyKryfoEndToEndEncrypted => 'مشفّر بين الطرفين';

  @override
  String get whyKryfoMessagesAreSealedWith =>
      'الرسائل مختومة بمفاتيح لا يملكها إلا أنت ومن تتحدث معه. لن نستطيع قراءتها حتى لو حاولنا.';

  @override
  String get whyKryfoNoServersHoldingYour => 'لا خوادم تحتفظ بحياتك';

  @override
  String get whyKryfoNoAccountNoPhone =>
      'لا حساب، ولا رقم هاتف، ولا خادم مركزي يخزّن محادثاتك. إنها تعيش على هذا الهاتف، مشفّرة وهي مخزّنة.';

  @override
  String get whyKryfoNothingLeaks => 'لا شيء يتسرّب';

  @override
  String get whyKryfoNoReadReceiptsOr =>
      'لا إشعارات قراءة ولا مؤشرات كتابة تُسلَّم لأحد، ولا قائمة جهات اتصال تُرفع. البيانات الوصفية هي ما تسرّبه معظم التطبيقات - أما kryfo فمبني كي لا يفعل.';

  @override
  String get whyKryfoVerifyItIsReally => 'تحقّق من أنه هو فعلًا';

  @override
  String get whyKryfoCompareASafetyNumber =>
      'قارن رقم الأمان وجهًا لوجه أو عبر قناة تثق بها، لتعرف أن لا أحد ينتحل شخصية جهة اتصالك.';

  @override
  String get whyKryfoTheHonestPart => 'الجزء الصريح';

  @override
  String get whyKryfoKryfoIsPreAlpha =>
      'ما زال kryfo في مرحلة ما قبل ألفا ولم يخضع لتدقيق. التشفير حقيقي لكن لم يفحصه أي خبير خارجي بعد، فتعامل معه كعمل قيد التطوير، لا كشيء تأتمنه على حياتك بعد.';

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
  String get photoStoryNotAKindKryfo => 'ليس نوعًا يستطيع kryfo قراءته.';

  @override
  String get photoStorySoItWillNot => 'لذا لن يخمّن.';

  @override
  String get photoStoryThisFileIsDamaged => 'هذا الملف تالف أو مبتور.';

  @override
  String get photoStoryKryfoCouldNotRead =>
      'لم يستطع kryfo قراءته حتى النهاية.';

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
      'يُفرغه أندرويد حين تُختار الصورة بهذه الطريقة. ومشاركتها مع kryfo من معرضك غالبًا ما تُبقيه. وقد تظل الصورة التي في معرضك تحمله.';

  @override
  String get photoStoryLocationBlankedByAndroid =>
      'الموقع: أفرغه أندرويد قبل أن يراه kryfo';

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
  String get bootFailedKryfoCouldNotStart => 'تعذّر تشغيل kryfo';

  @override
  String get bootFailedThisIsAFault =>
      'هذا عطل في هذا الجهاز، لا في الشبكة. لا علاقة لـ tor بذلك.';

  @override
  String get kryfoLinkTextThatLinkIsNot => 'لا يستطيع kryfo قراءة هذا الرابط';

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
  String kryfoLinkTextJoin(Object roomName) {
    return 'الانضمام إلى ⁨$roomName⁩';
  }

  @override
  String get kryfoLinkTextKryfoLink => 'رابط kryfo';

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
      'تنضم بمفتاح صُنع لهذه الغرفة. لا أحد فيها يرى معرّف kryfo الخاص بك.';

  @override
  String get linkStubFetchedOverTorBy => 'جُلبت عبر tor · بواسطة جهازك';

  @override
  String get linkStubFetchedOverTorByTheirDevice =>
      'جُلبت عبر tor · بواسطة جهازه';

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
  String get mediaBubblesMicPermissionNeeded => 'يلزم إذن الميكروفون';

  @override
  String get mediaBubblesReleaseToCancel => 'أفلت للإلغاء';

  @override
  String get mediaBubblesVoiceHiddenSlideTo => 'الصوت مموّه · اسحب للإلغاء';

  @override
  String get mediaBubblesSlideToCancel => 'اسحب للإلغاء';

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
  String get motionTorIsStartingIn =>
      'يبدأ tor في الخلفية. يضيء هذا الرسم مع تشكّل الاتصال.';

  @override
  String get motionMakingAFreshRoute =>
      'جارٍ إنشاء مسار جديد عبر مُرحِّلات مجهولة.';

  @override
  String get motionBouncingThroughRelaysSo =>
      'يتنقّل بين المُرحِّلات كي لا يستطيع أحد تتبّع هذا إليك.';

  @override
  String get motionTellingTheNetworkYou =>
      'جارٍ إبلاغ الشبكة أنك متصل - دون كشف مكانك.';

  @override
  String get motionYourIpIsHidden =>
      'عنوان IP الخاص بك مخفي. لا يصل إليك إلا من لديه kryfo الخاص بك.';

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
      'انتقل kryfo هذا إلى جهاز آخر. لا يصل أي شيء يُرسل من هنا إلى أحد.';

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
  String get pairCodePanelReadSixDigitsOut =>
      'اقرأ ستة أرقام بصوت عالٍ فيستطيع إضافتك. لا حاجة إلى تبادل أي شيء آخر.';

  @override
  String get pairCodePanelWorking => 'جارٍ العمل';

  @override
  String get pairCodePanelOrMakeASix => 'أو أنشئ رمزًا من ستة أرقام لتقرأه';

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
  String get pairCodePanelTheyOpenKryfoTap =>
      'يفتح kryfo، ويضغط «إضافة»، ويختار «رمز الاقتران» ثم يكتب هذه الأرقام الستة. أنشئ رمزًا جديدًا للشخص التالي.';

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
  String powNoteFirstMessageToSomeone(int secs) {
    final intl.NumberFormat secsNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String secsString = secsNumberFormat.format(secs);

    return 'أول رسالة لشخص جديد · جارٍ إثبات أنها حقيقية · ⁨$secsString⁩ ث';
  }

  @override
  String powNoteFirstMessageSlow(int secs) {
    final intl.NumberFormat secsNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String secsString = secsNumberFormat.format(secs);

    return 'أول رسالة لشخص جديد · جارٍ إثبات أنها حقيقية · ⁨$secsString⁩ ث · حتى دقيقة على هاتف بطيء';
  }

  @override
  String previewStripFetchedOverTor(Object domainOf) {
    return '⁨$domainOf⁩ · جُلبت عبر tor';
  }

  @override
  String get previewStripDropThePreview => 'إزالة المعاينة';

  @override
  String get previewStripAddPreview => 'إضافة معاينة';

  @override
  String get previewStripFetchingOverTor => 'جارٍ الجلب عبر tor…';

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
  String get torBootSplashFirstLaunchTakesA =>
      'التشغيل الأول يستغرق لحظة · عند البدء فقط';

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
  String get shieldBlock => 'حظر';

  @override
  String get shieldDelete => 'حذف';

  @override
  String get shieldIgnore => 'تجاهل';

  @override
  String get profileIdentity => 'الهوية';

  @override
  String get avatarPickerShape => 'الشكل';

  @override
  String get avatarPickerColour => 'اللون';

  @override
  String get avatarPickerTurn => 'تدوير';

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
  String get settingsAllowed => 'مسموحة';

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
  String get confirmSheetKeep => 'إبقاء';

  @override
  String get confirmSheetSave => 'حفظ';

  @override
  String get confirmSheetCancel => 'إلغاء';

  @override
  String bridgesSaved(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$countString⁩ جسر',
      many: '⁨$countString⁩ جسرًا',
      few: '⁨$countString⁩ جسور',
      two: 'جسران',
      one: 'جسر واحد',
      zero: '⁨$countString⁩ جسر',
    );
    return '$_temp0';
  }

  @override
  String bridgesSavedSomeBad(int good, int bad) {
    final intl.NumberFormat goodNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String goodString = goodNumberFormat.format(good);
    final intl.NumberFormat badNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String badString = badNumberFormat.format(bad);

    return 'قُبل ⁨$goodString⁩، ولم يُفهم ⁨$badString⁩';
  }

  @override
  String get languageTitle => 'اللغة';

  @override
  String get languageMatchPhone => 'لغة الهاتف';

  @override
  String languageMatchPhoneValue(Object language) {
    return 'لغة الهاتف (⁨$language⁩)';
  }

  @override
  String get languageRedrawLine =>
      'يُعاد رسم kryfo باللغة الجديدة ويفتح على محادثاتك.';

  @override
  String languageButton(Object language) {
    return 'اللغة: ⁨$language⁩';
  }

  @override
  String get androidServiceTitle => 'يعمل kryfo';

  @override
  String get androidServiceText => 'يبقى خطّك المشفّر مفتوحًا لتصل الرسائل';

  @override
  String get androidChannelName => 'البقاء متصلًا';

  @override
  String get androidChannelDescription =>
      'يُبقي kryfo متصلًا لتصل الرسائل المشفّرة وهو مغلق. إيقاف هذا يوقف التوصيل.';

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
  String get searchOpen => 'بحث';

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
}
