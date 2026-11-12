// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get atmosphereNone => 'कोई नहीं';

  @override
  String get atmosphereEmber => 'अंगारा';

  @override
  String get atmosphereDusk => 'साँझ';

  @override
  String get atmosphereMoss => 'काई';

  @override
  String get atmosphereRose => 'गुलाब';

  @override
  String get atmosphereDots => 'बिंदु';

  @override
  String get atmosphereGrid => 'जाली';

  @override
  String get atmosphereWaves => 'लहरें';

  @override
  String get atmosphereRain => 'बारिश';

  @override
  String get atmosphereLateNight => 'देर रात';

  @override
  String get atmosphereWarmAfternoon => 'गुनगुनी दोपहर';

  @override
  String get atmosphereSnow => 'बर्फ़';

  @override
  String get atmosphereDesert => 'रेगिस्तान';

  @override
  String get atmospherePaper => 'काग़ज़';

  @override
  String get accentYellow => 'पीला';

  @override
  String get accentGrey => 'स्लेटी';

  @override
  String get accentPurple => 'बैंगनी';

  @override
  String get accentLime => 'नींबू हरा';

  @override
  String get accentVelvet => 'मख़मली लाल';

  @override
  String get accentBlue => 'नीला';

  @override
  String get appearancePreview => 'इस रंग में आपकी चैट ऐसी दिखेंगी';

  @override
  String get appearanceSampleIn => 'आज रात का प्लान पक्का है?';

  @override
  String get appearanceSampleOut => 'हाँ। आठ बजे, वही जगह।';

  @override
  String get appearanceSampleButton => 'जवाब दें';

  @override
  String get appearanceAccentHint =>
      'बटन, आपके अपने मैसेज और लिंक इसी रंग में दिखते हैं। ऐप का आइकन पीला ही रहता है।';

  @override
  String get appearanceChatWallpaper => 'चैट वॉलपेपर';

  @override
  String get appearanceEveryChat => 'हर चैट';

  @override
  String get appearanceWallpaperHint =>
      'किसी चैट के मेन्यू से उसका अपना वॉलपेपर लगाया हो, तो वही पहले आता है। फ़ोटो इसी फ़ोन पर रहती हैं, आपकी चैट के साथ एन्क्रिप्ट होकर।';

  @override
  String get appearanceWallpaperHintDesk =>
      'किसी चैट के मेन्यू से उसका अपना वॉलपेपर लगाया हो, तो वही पहले आता है। फ़ोटो इसी कंप्यूटर पर रहती हैं, आपकी चैट के साथ एन्क्रिप्ट होकर।';

  @override
  String get backupThatPassphraseDoesNot =>
      'यह पासफ़्रेज़ इस फ़ाइल को नहीं खोलता';

  @override
  String get backupThatFileIsNot => 'यह फ़ाइल Kryfo बैकअप नहीं है';

  @override
  String get backupThisBackupIsFrom =>
      'यह बैकअप Kryfo के नए वर्शन का है। ऐप अपडेट करें, फिर दोबारा कोशिश करें';

  @override
  String get backupThisFileIsDamaged =>
      'यह फ़ाइल ख़राब है और पढ़ी नहीं जा सकती';

  @override
  String get backupTheRestoreStoppedPartway => 'रीस्टोर बीच में ही रुक गया';

  @override
  String get backupCouldNotMakeThe => 'कुंजी नहीं बन पाई';

  @override
  String get contactCardMessageMeOn => 'मुझे यहाँ मैसेज करें';

  @override
  String get contactCardScanToAdd =>
      'मुझे जोड़ने के लिए इसे Kryfo से स्कैन करें।\nइसके सिवा यह कार्ड आपके बारे में कुछ नहीं जानता।';

  @override
  String contactCardMessageMeOnKryfo(Object haloId) {
    return 'Kryfo पर मुझे मैसेज करें · $haloId';
  }

  @override
  String get contactStatusBlocked => 'ब्लॉक किया गया';

  @override
  String get contactStatusKeysVerifiedInPerson =>
      'कुंजियाँ आमने-सामने जाँची गईं';

  @override
  String get contactStatusWaitingInRequests => 'अनुरोधों में इंतज़ार में';

  @override
  String get deliveryModeAlwaysOn => 'हमेशा चालू';

  @override
  String get deliveryModeCheckIns => 'समय-समय पर जाँच';

  @override
  String get deliveryModeThroughAHelperApp => 'सहायक ऐप से';

  @override
  String get deliveryModeNotYet => 'अभी नहीं';

  @override
  String get deliveryModeJustNow => 'अभी-अभी';

  @override
  String deliveryModeMinAgo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString मिनट पहले',
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
      other: '$countString घंटे पहले',
      one: '$countString घंटा पहले',
    );
    return '$_temp0';
  }

  @override
  String get deliveryModeYesterday => 'कल';

  @override
  String deliveryModeDaysAgo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString दिन पहले',
      one: '$countString दिन पहले',
    );
    return '$_temp0';
  }

  @override
  String get deliveryModeConnected => 'जुड़ा हुआ';

  @override
  String get deliveryModeConnecting => 'जुड़ रहा है';

  @override
  String get deliveryModeNotConnected => 'जुड़ा नहीं';

  @override
  String get deliveryModeCheckingNow => 'अभी जाँच हो रही है';

  @override
  String deliveryModeLastCheckIn(Object agoLine) {
    return 'पिछली जाँच $agoLine';
  }

  @override
  String get deliveryModeNoCheckInYet => 'अभी तक कोई जाँच नहीं';

  @override
  String deliveryModeConnectedNow(Object last) {
    return 'अभी जुड़ा है · $last';
  }

  @override
  String deliveryModeConnecting2(Object last) {
    return 'जुड़ रहा है · $last';
  }

  @override
  String get deliveryModeNoCheckInYet2 => 'अभी तक कोई जाँच नहीं';

  @override
  String deliveryModeLastChecked(Object agoLine) {
    return 'पिछली जाँच $agoLine';
  }

  @override
  String get deliveryModeAHelperApp => 'एक सहायक ऐप';

  @override
  String deliveryModeWokenByNoWake(Object who) {
    return '$who जगाता है · अभी तक नहीं जगाया';
  }

  @override
  String deliveryModeWokenByLastWake(Object who, Object agoLine) {
    return '$who जगाता है · पिछली बार जगाया $agoLine';
  }

  @override
  String get introBudgetTomorrow => 'कल';

  @override
  String introBudgetInDays(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString दिन में',
      one: '$countString दिन में',
    );
    return '$_temp0';
  }

  @override
  String get introBudgetInAnHour => 'एक घंटे में';

  @override
  String introBudgetInHours(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString घंटे में',
      one: '$countString घंटे में',
    );
    return '$_temp0';
  }

  @override
  String get introBudgetInAFewMinutes => 'कुछ मिनट में';

  @override
  String get lockStateUnlockKryfo => 'Kryfo अनलॉक करें';

  @override
  String get appInvalidUri => 'अमान्य uri';

  @override
  String appBundleError(Object e) {
    return 'बंडल में गड़बड़ी: $e';
  }

  @override
  String appAlreadySaved(Object parsed) {
    return 'पहले से सेव है: $parsed';
  }

  @override
  String appLongWindow(Object line) {
    return '$line लंबी अवधि';
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
      other: '$pString पेज',
      one: '$pString पेज',
    );
    String _temp1 = intl.Intl.pluralLogic(
      e,
      locale: localeName,
      other: '$eString इवेंट',
      one: '$eString इवेंट',
    );
    return '$line ($subsString में से $heldString, कनेक्ट $c सेकंड, $_temp0, $_temp1)';
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
      other: '$pString पेज',
      one: '$pString पेज',
    );
    String _temp1 = intl.Intl.pluralLogic(
      e,
      locale: localeName,
      other: '$eString इवेंट',
      one: '$eString इवेंट',
    );
    return '$line (कनेक्ट $c सेकंड, $_temp0, $_temp1)';
  }

  @override
  String appSDropped(Object host, Object secs) {
    return '$host $secs सेकंड, छूट गया';
  }

  @override
  String appS(Object host, Object secs) {
    return '$host $secs सेकंड';
  }

  @override
  String get appTorWouldNotWake => 'Tor नहीं जागा';

  @override
  String get appCheckStarted => 'शुरू हुआ';

  @override
  String get appTorNotReadyIn => '75 सेकंड में Tor तैयार नहीं हुआ';

  @override
  String get appOk => 'ठीक है';

  @override
  String get appOkNoRelayBegan => 'ठीक, पर कोई रिले शुरू नहीं हुआ';

  @override
  String get appNoRelayReached => 'कोई रिले नहीं मिला';

  @override
  String get appOkCapped => 'ठीक, समय पर रोका';

  @override
  String appSBy(Object how, int secs, String why) {
    final intl.NumberFormat secsNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String secsString = secsNumberFormat.format(secs);

    String _temp0 = intl.Intl.selectLogic(why, {
      'push': '$how, $secsString सेकंड, पुश से',
      'other': '$how, $secsString सेकंड, जॉब से',
    });
    return '$_temp0';
  }

  @override
  String get appAnAttachmentCouldNot =>
      'एक अटैचमेंट इस फ़ोन पर सेव नहीं हो पाया';

  @override
  String get appAnAttachmentCouldNotDesk =>
      'एक अटैचमेंट इस कंप्यूटर पर सेव नहीं हो पाया';

  @override
  String get appGroup2 => 'ग्रुप';

  @override
  String get appVoiceMessage => 'वॉइस मैसेज';

  @override
  String get appPhoto => 'फ़ोटो';

  @override
  String get appNewRequest => 'नया अनुरोध';

  @override
  String get appSomeoneYouHaveNot =>
      'किसी ऐसे व्यक्ति ने आपको लिखा है जिसे आपने नहीं जोड़ा';

  @override
  String get appSettingUpYourKeys => 'आपकी कुंजियाँ तैयार हो रही हैं';

  @override
  String get appOpeningYourChats => 'आपकी चैट खुल रही हैं';

  @override
  String get appStartingTor => 'Tor शुरू हो रहा है';

  @override
  String get appTimedMessagesAreNot =>
      'मिटने वाले मैसेज साफ़ नहीं हो रहे। Kryfo दोबारा शुरू करें';

  @override
  String get appVoiceMessage2 => 'वॉइस मैसेज';

  @override
  String appYou(Object body) {
    return 'आप: $body';
  }

  @override
  String get appThisRoomHasAlready => 'इस रूम का समय पहले ही ख़त्म हो चुका है';

  @override
  String get appYouAreAlreadyIn => 'आप पहले से इस रूम में हैं';

  @override
  String get appCouldNotMakeA => 'रूम की कुंजी नहीं बन पाई';

  @override
  String appJoined(Object linkName) {
    return '$linkName में शामिल हुए';
  }

  @override
  String get roomJoinWaitingToJoin => 'शामिल होने का इंतज़ार';

  @override
  String get roomJoinNotAnswering => 'जवाब नहीं दे रहा';

  @override
  String roomJoinWaitingFor(Object room) {
    return '$room में आने की अनुमति का इंतज़ार…';
  }

  @override
  String get roomJoinWaitingLine => 'अंदर आने के बाद आप यहाँ लिख सकेंगे।';

  @override
  String get roomJoinNoAnswer => 'यह रूम जवाब नहीं दे रहा।';

  @override
  String get roomJoinMayHaveEnded => 'शायद यह ख़त्म हो चुका है।';

  @override
  String get roomJoinFullShort => 'रूम भरा है';

  @override
  String get roomJoinFull => 'यह रूम भरा हुआ है।';

  @override
  String get roomJoinFullLine =>
      'अभी कोई जगह ख़ाली नहीं है। बाद में फिर कोशिश करें, या जिसने लिंक भेजा उससे पूछें।';

  @override
  String get appBooting => 'शुरू हो रहा है...';

  @override
  String get appSettingUpYourIdentity => 'आपकी पहचान तैयार हो रही है...';

  @override
  String get appAddSomeone => 'किसी को जोड़ें';

  @override
  String get appScanTheirCodeOr =>
      'उनका कोड स्कैन करें, या जो उन्होंने दिया वह पेस्ट करें: लिंक, @यूज़रनेम या रूम लिंक।';

  @override
  String get appScanTheirCodeOrDesk =>
      'जो उन्होंने दिया वह पेस्ट करें: लिंक, @यूज़रनेम या रूम लिंक।';

  @override
  String get appScanTheirCode => 'उनका कोड स्कैन करें';

  @override
  String get appAKryfoLinkA => 'Kryfo लिंक, रूम लिंक या @name';

  @override
  String get appAddThem => 'जोड़ें';

  @override
  String get appEveryWayToAdd => 'किसी को जोड़ने के सभी तरीक़े';

  @override
  String get appShowYourCodeSend => 'अपना कोड दिखाएँ, लिंक भेजें, यूज़रनेम लें';

  @override
  String get appHelloFromTheOther => 'दूसरी तरफ़ से नमस्ते';

  @override
  String get appIdentityRestored => 'पहचान वापस आ गई';

  @override
  String get appIdentityCreated => 'पहचान बन गई';

  @override
  String get appStartingTor30s => 'Tor शुरू हो रहा है (~30 सेकंड)...';

  @override
  String get appScanOrImportA => 'पहले किसी साथी को स्कैन या इम्पोर्ट करें';

  @override
  String get appEncryptingSending30s =>
      'एन्क्रिप्ट करके भेजा जा रहा है (~30 सेकंड)...';

  @override
  String get appTapStartListeningFirst => 'पहले “सुनना शुरू करें” दबाएँ';

  @override
  String get appYourKryfo => 'आपका Kryfo';

  @override
  String get appUriCopied => 'uri कॉपी हो गया';

  @override
  String get appCopyUri => 'uri कॉपी करें';

  @override
  String get appAddAKryfo => 'एक Kryfo जोड़ें';

  @override
  String get appScanQr => 'QR स्कैन करें';

  @override
  String get appPairingCode => 'जोड़ने का कोड';

  @override
  String get appOrPaste => '- या पेस्ट करें -';

  @override
  String get commonCancel => 'रद्द करें';

  @override
  String get appImport => 'इम्पोर्ट करें';

  @override
  String get appDev => 'डेवलपर';

  @override
  String get appYourKryfo2 => 'आपका Kryfo:';

  @override
  String get appRestoredFromDisk => 'डिस्क से वापस लाया गया';

  @override
  String get appStartListening => 'सुनना शुरू करें';

  @override
  String get appListening => 'सुन रहा है';

  @override
  String get appShowMyQr => 'मेरा QR दिखाएँ';

  @override
  String get appImportPeer => 'साथी इम्पोर्ट करें';

  @override
  String get appPeer => 'साथी:';

  @override
  String get appMessageWillBeEncrypted => 'मैसेज (एन्क्रिप्ट होगा)';

  @override
  String get appEncryptSend => 'एन्क्रिप्ट करके भेजें';

  @override
  String appStatus(Object status) {
    return 'स्थिति: $status';
  }

  @override
  String get appSpeedPrivacy => 'रफ़्तार और प्राइवेसी →';

  @override
  String get appDisableAppLock => 'ऐप लॉक बंद करें?';

  @override
  String get appThePinWillBe =>
      'PIN हटा दिया जाएगा। आपका फ़ोन जिसके भी हाथ में होगा, वह Kryfo खोलते ही उसे देख लेगा।';

  @override
  String get appDisable => 'बंद करें';

  @override
  String get appAppLockOn => 'ऐप लॉक · चालू →';

  @override
  String get appAppLockOff => 'ऐप लॉक · बंद →';

  @override
  String get appTorIsOff => 'Tor बंद है';

  @override
  String get appConnectedRoutedThrough3 => 'जुड़ा हुआ · 3 रिले से होकर';

  @override
  String get appReadyToChatAddressFinishing =>
      'चैट के लिए तैयार · पता पूरा हो रहा है';

  @override
  String get appTor => 'Tor';

  @override
  String get appTorIsOffTurn =>
      'Tor बंद है। निजी तरीक़े से जुड़ने के लिए इसे चालू करें।';

  @override
  String get appTheFirstConnectionTakes =>
      'पहली बार जुड़ने में एक-दो मिनट लगते हैं, जब तक Tor एक निजी रास्ता बनाता है। उसके बाद वह याद रहता है, इसलिए बाद में Kryfo बहुत जल्दी खुलता है।';

  @override
  String get appTorNoRelayYet =>
      'Tor चालू है, पर अभी तक कोई रिले जवाब नहीं दे रहा। Kryfo कोशिश करता रहता है, और तब तक मैसेज यहीं इंतज़ार करते हैं।';

  @override
  String get appRelayAndFastModes =>
      'तेज़ Tor को छोड़ देता है और जल्दी है। यह सेटिंग्स में रफ़्तार और प्राइवेसी के नीचे है, और बताता है कि इसकी क्या क़ीमत है।';

  @override
  String get appOffline => 'ऑफ़लाइन';

  @override
  String get appTorOff => 'Tor बंद';

  @override
  String get appTorReady => 'Tor तैयार';

  @override
  String get appConnecting2 => 'जुड़ रहा है';

  @override
  String get appWaitingForARelay => 'रिले का इंतज़ार';

  @override
  String appStartingTorPct(Object pct) {
    return 'Tor शुरू · $pct';
  }

  @override
  String get appGettingNewMessages => 'नए संदेश आ रहे हैं';

  @override
  String mediaProgressSendingKeepTheApp(Object v) {
    return 'भेजा जा रहा है · $v · ऐप खुला रखें';
  }

  @override
  String mediaProgressPausedOfWaitingFor(Object count, Object count2) {
    return 'रुका हुआ · $count2 में से $count · बाक़ी का इंतज़ार';
  }

  @override
  String mediaProgressReceivingMedia(Object v) {
    return 'मीडिया आ रहा है · $v';
  }

  @override
  String get mediaProgressCancelSending => 'भेजना रद्द करें';

  @override
  String get metaReaderEndsBeforeItShould => 'समय से पहले ख़त्म हो जाती है';

  @override
  String get metaReaderCouldNotBeRead => 'पढ़ी नहीं जा सकी';

  @override
  String get metaReaderExifThatCannotBe => 'ऐसा EXIF जो पढ़ा नहीं जा सकता';

  @override
  String get metaReaderSamsungTrailer => 'Samsung का अतिरिक्त हिस्सा';

  @override
  String metaReaderChunk(Object type) {
    return 'हिस्सा $type';
  }

  @override
  String get metaReaderExifFlagSet => 'EXIF फ़्लैग लगा है';

  @override
  String get metaReaderXmpFlagSet => 'XMP फ़्लैग लगा है';

  @override
  String metaReaderAppBlock(Object id) {
    return 'ऐप ब्लॉक $id';
  }

  @override
  String get metaReaderUuidBox => 'uuid बॉक्स';

  @override
  String metaReaderBox(Object printable) {
    return '$printable बॉक्स';
  }

  @override
  String get metaReaderAttachedData => 'जुड़ा हुआ डेटा';

  @override
  String metaReaderItem(Object printable) {
    return '$printable आइटम';
  }

  @override
  String get miuiAutostartAlreadyAllowedToRun =>
      'बैकग्राउंड में चलने की अनुमति पहले से है';

  @override
  String get miuiAutostartLetKryfoRunIn => 'Kryfo को बैकग्राउंड में चलने दें';

  @override
  String get miuiAutostartYourPhonePausesApps =>
      'बैटरी बचाने के लिए आपका फ़ोन ऐप रोक देता है। छूट न मिले, तो Kryfo बंद रहने पर मैसेज नहीं पा सकता।';

  @override
  String get commonAllow => 'अनुमति दें';

  @override
  String get commonSkip => 'छोड़ें';

  @override
  String get miuiAutostartOpenSettings => 'सेटिंग खोलें';

  @override
  String get miuiAutostartCouldnTOpenIt =>
      'नहीं खुल पाया। फ़ोन की सेटिंग में autostart ढूँढें';

  @override
  String get batteryGuideHuawei =>
      'Huawei और Honor उन ऐप को बंद कर देते हैं जिन्हें वे ख़ुद संभालते हैं। अगली स्क्रीन पर Kryfo ढूँढें, Manage automatically बंद करें, और Auto-launch, Secondary launch और Run in background चालू रहने दें।';

  @override
  String get batteryGuideOppo =>
      'Oppo और Realme बैकग्राउंड में ऐप रोक देते हैं। अगली स्क्रीन पर Kryfo ढूँढें और Auto launch की अनुमति दें। Battery में भी इसके लिए बैकग्राउंड गतिविधि की अनुमति दें।';

  @override
  String get batteryGuideVivo =>
      'Vivo बैकग्राउंड में ऐप रोक देता है। अगली स्क्रीन पर Kryfo ढूँढें और उसे बैकग्राउंड में शुरू होने की अनुमति दें। Battery में भी इसके लिए ज़्यादा बैकग्राउंड बिजली खर्च की अनुमति दें।';

  @override
  String get batteryGuideSamsung =>
      'Samsung उन ऐप को सुला देता है जिन्हें वह इस्तेमाल न होते समझता है। अगली स्क्रीन पर Background usage limits खोलें और Kryfo को Never sleeping apps में जोड़ें।';

  @override
  String get batteryGuideOnePlus =>
      'OnePlus बैकग्राउंड में ऐप रोक देता है। अगली स्क्रीन पर Kryfo ढूँढें और Auto launch की अनुमति दें। Battery में इसे Don\'t optimize पर रखें।';

  @override
  String get batteryGuideXiaomiTitle => 'Kryfo को चालू रखें';

  @override
  String get batteryGuideXiaomi =>
      'Xiaomi बैकग्राउंड में ऐप रोक देता है, autostart चालू होने पर भी। मैसेज आते रहें, इसके लिए:';

  @override
  String get batteryGuideXiaomiStep1 =>
      'Autostart: Kryfo के लिए इसे चालू करें।';

  @override
  String get batteryGuideXiaomiStep2 =>
      'Battery saver: Kryfo को No restrictions पर रखें।';

  @override
  String get batteryGuideXiaomiStep3 =>
      'हाल के ऐप: Kryfo को दबाकर रखें और ताले पर टैप करें, ताकि Clear all और फ़ोन की सफ़ाई उसे चलता छोड़ दें।';

  @override
  String get batteryGuideXiaomiAfter =>
      'अगर फिर भी आपका फ़ोन Kryfo को रोक दे, तो जब तक आप उसे दोबारा नहीं खोलते, कुछ नहीं आएगा।';

  @override
  String get notificationsNewEncryptedMessagesFrom =>
      'आपके संपर्कों से नए एन्क्रिप्टेड मैसेज';

  @override
  String get notificationsNewMessage => 'नया मैसेज';

  @override
  String get notificationsNewEncryptedMessagesFromYourContacts =>
      'आपके संपर्कों से नए एन्क्रिप्टेड मैसेज';

  @override
  String get notificationsNewMessage2 => 'नया मैसेज';

  @override
  String get notificationsSomeone => 'कोई';

  @override
  String get notificationsEncrypted => 'एन्क्रिप्टेड';

  @override
  String get rooms24h => '24 घं';

  @override
  String roomsD(Object inDays) {
    return '$inDays दिन';
  }

  @override
  String roomsH(Object inHours) {
    return '$inHours घं';
  }

  @override
  String get rooms24Hours => '24 घंटे';

  @override
  String roomsDays(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString दिन',
      one: '$countString दिन',
    );
    return '$_temp0';
  }

  @override
  String get roomsAnHour => 'एक घंटा';

  @override
  String get roomsAboutAnHour => 'लगभग एक घंटा';

  @override
  String roomsHours(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString घंटे',
      one: '$countString घंटा',
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
      other: 'लगभग $countString घंटे',
      one: 'लगभग $countString घंटा',
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
      other: '$countString मिनट',
      one: '$countString मिनट',
    );
    return '$_temp0';
  }

  @override
  String get roomsAMinute => 'एक मिनट';

  @override
  String get roomsExpired => 'समय ख़त्म';

  @override
  String roomsDH(Object inDays, Object h) {
    return '$inDays दिन $h घं';
  }

  @override
  String roomsHM(Object inHours, Object m) {
    return '$inHours घं $m मि';
  }

  @override
  String roomsM(Object inMinutes) {
    return '$inMinutes मि';
  }

  @override
  String scamShieldGivesUsedName(Object shown) {
    return 'ख़ुद को $shown बताता है, यह नाम यहाँ पहले से किसी का है';
  }

  @override
  String scamShieldWarning(Object noticed) {
    return '$noticed। जिनसे आप कभी मिले नहीं, उन्हें पैसे या कोड न भेजें।';
  }

  @override
  String get scamShieldAsksForSecret => 'कोड, PIN या रिकवरी शब्द माँगता है';

  @override
  String get scamShieldAsksForMoneyFast => 'जल्दी में पैसे माँगता है';

  @override
  String get scamShieldPromisesProfit => 'आसान मुनाफ़े का वादा करता है';

  @override
  String get scamShieldClaimsSupport =>
      'ख़ुद को Kryfo या किसी सपोर्ट टीम से बताता है';

  @override
  String get scamShieldDismiss => 'हटाएँ';

  @override
  String scamShieldNameMatchesYourContact(Object shown) {
    return 'नाम आपके संपर्क $shown से मिलता है';
  }

  @override
  String get scamShieldLinksToALookalike =>
      'किसी जानी-मानी साइट जैसी दिखने वाली नक़ली साइट का लिंक';

  @override
  String get commonBack => 'वापस';

  @override
  String get archivedArchived => 'आर्काइव';

  @override
  String get archivedCount0 => 'कोई नहीं';

  @override
  String get archivedCount1 => 'एक';

  @override
  String get archivedCount2 => 'दो';

  @override
  String get archivedCount3 => 'तीन';

  @override
  String get archivedCount4 => 'चार';

  @override
  String get archivedCount5 => 'पाँच';

  @override
  String get archivedCount6 => 'छह';

  @override
  String get archivedCount7 => 'सात';

  @override
  String get archivedCount8 => 'आठ';

  @override
  String get archivedCount9 => 'नौ';

  @override
  String get archivedCount10 => 'दस';

  @override
  String get archivedChatRestingHereIt =>
      'चैट यहाँ आराम कर रही है। जब तक वे न लिखें, यह चुप रहती है, फिर सबसे ऊपर लौट आती है।';

  @override
  String get archivedChatsRestingHere =>
      'चैट यहाँ आराम कर रही हैं। जब तक कोई न लिखे, ये चुप रहती हैं, फिर सबसे ऊपर लौट आती हैं।';

  @override
  String get archivedNothingArchived => 'कुछ भी आर्काइव नहीं है';

  @override
  String get archivedArchivedChatsAreStill =>
      'आर्काइव की गई चैट भी एंड-टू-एंड एन्क्रिप्टेड रहती हैं';

  @override
  String get archivedUnarchive => 'आर्काइव से निकालें';

  @override
  String get avatarPickerThePeopleYouMessage =>
      'जिन्हें आप मैसेज करते हैं, वे भी इसे देखते हैं';

  @override
  String get avatarPickerBackToYourInitial => 'वापस अपने नाम के अक्षर पर';

  @override
  String get avatarPickerThatOneIsYours => 'यह आपका है';

  @override
  String get avatarPickerPickAFace => 'एक चेहरा चुनें';

  @override
  String get commonSave => 'सेव करें';

  @override
  String get backupPassphraseMustBeAt =>
      'पासफ़्रेज़ कम से कम 12 अक्षरों का होना चाहिए';

  @override
  String get backupPassphrasesDonTMatch => 'दोनों पासफ़्रेज़ मेल नहीं खाते';

  @override
  String get backupBackupSavedKeepThe =>
      'बैकअप सेव हो गया · पासफ़्रेज़ संभालकर रखें';

  @override
  String get backupKryfoBackup => 'Kryfo बैकअप';

  @override
  String get backupYourEncryptedKryfoBackup =>
      'आपका एन्क्रिप्टेड Kryfo बैकअप। यह फ़ाइल और अपना पासफ़्रेज़ संभालकर रखें। रीस्टोर करने के लिए दोनों चाहिए।';

  @override
  String get backupBackUpKryfo => 'Kryfo का बैकअप लें';

  @override
  String get backupBackUp => 'बैकअप लें';

  @override
  String get backupACopyToKeep =>
      'रखने के लिए एक कॉपी। यह फ़ोन जैसा है वैसा चलता रहेगा।';

  @override
  String get backupACopyToKeepDesk =>
      'रखने के लिए एक कॉपी। यह कंप्यूटर जैसा है वैसा चलता रहेगा।';

  @override
  String get backupMoveToAnotherDevice => 'दूसरे डिवाइस पर ले जाएँ';

  @override
  String get backupTheFileTakesThis =>
      'फ़ाइल यह पहचान अपने साथ ले जाती है। फ़ाइल बनते ही यह फ़ोन रुक जाता है: यहाँ कुछ नया नहीं आएगा, और यहाँ से भेजा कुछ भी किसी तक नहीं पहुँचेगा।';

  @override
  String get backupTheFileTakesThisDesk =>
      'फ़ाइल यह पहचान अपने साथ ले जाती है। फ़ाइल बनते ही यह कंप्यूटर रुक जाता है: यहाँ कुछ नया नहीं आएगा, और यहाँ से भेजा कुछ भी किसी तक नहीं पहुँचेगा।';

  @override
  String get backupOneEncryptedFileYour =>
      'एक एन्क्रिप्टेड फ़ाइल: आपकी पहचान, आपके संपर्क, हर मैसेज, और हर फ़ोटो, वॉइस नोट और फ़ाइल। इसे दूसरे डिवाइस पर पासफ़्रेज़ के साथ इम्पोर्ट करें। जब तक आप ऐसा नहीं करते, आप अपना मन बदलकर इसी फ़ोन पर रह सकते हैं।';

  @override
  String get backupOneEncryptedFileYourIdentityYour =>
      'एक एन्क्रिप्टेड फ़ाइल: आपकी पहचान, आपके संपर्क, हर मैसेज, और इस फ़ोन पर अभी मौजूद हर फ़ोटो, वॉइस नोट और फ़ाइल। आज के बाद की बातें इसमें नहीं होंगी, इसलिए ज़रूरत हो तो नया बैकअप बनाएँ। रीस्टोर करने के लिए फ़ाइल और पासफ़्रेज़, दोनों चाहिए।';

  @override
  String get backupOneEncryptedFileYourIdentityYourDesk =>
      'एक एन्क्रिप्टेड फ़ाइल: आपकी पहचान, आपके संपर्क, हर मैसेज, और इस कंप्यूटर पर अभी मौजूद हर फ़ोटो, वॉइस नोट और फ़ाइल। आज के बाद की बातें इसमें नहीं होंगी, इसलिए ज़रूरत हो तो नया बैकअप बनाएँ। रीस्टोर करने के लिए फ़ाइल और पासफ़्रेज़, दोनों चाहिए।';

  @override
  String get backupPassphrase => 'पासफ़्रेज़';

  @override
  String get backupConfirmPassphrase => 'पासफ़्रेज़ दोबारा लिखें';

  @override
  String backupWriting(Object progress) {
    return 'लिखा जा रहा है… $progress';
  }

  @override
  String get backupSaveComesAfter =>
      'तैयार होने पर आप चुनेंगे कि इसे कहाँ सेव करना है।';

  @override
  String get backupSaving => 'सेव हो रहा है…';

  @override
  String backupSavedIn(String place) {
    return 'बैकअप $place में सेव हुआ · पासफ़्रेज़ संभालकर रखें';
  }

  @override
  String get backupNotSaved => 'बैकअप सेव नहीं हुआ। फ़ाइल अभी भी यहीं है।';

  @override
  String get backupNotSavedNoSpace =>
      'जहाँ आपने सेव करना चुना, वहाँ पर्याप्त जगह नहीं थी। फ़ाइल अभी भी यहीं है, इसलिए कोई दूसरी जगह चुनें या जगह ख़ाली करें।';

  @override
  String get backupShareInstead => 'इसके बजाय शेयर करें';

  @override
  String get backupSavedUnchecked =>
      'बैकअप सेव हो गया, पर Kryfo कॉपी की जाँच नहीं कर पाया';

  @override
  String get backupHandedOver =>
      'बैकअप आपके चुने ऐप को दे दिया गया · जाँच लें कि वह पहुँचा';

  @override
  String get backupMoveReachedTitle => 'क्या फ़ाइल आपके नए फ़ोन तक पहुँच गई?';

  @override
  String get backupMoveReachedTitleDesk =>
      'क्या फ़ाइल आपके नए डिवाइस तक पहुँच गई?';

  @override
  String get backupMoveReachedLine =>
      'जब तक आप उसे वहाँ खोल न लें, यह फ़ोन अपने पास रखें।';

  @override
  String get backupMoveReachedLineDesk =>
      'जब तक आप उसे वहाँ खोल न लें, यह कंप्यूटर अपने पास रखें।';

  @override
  String get backupFinishTheMove => 'ले जाना पूरा करें';

  @override
  String get backupNotYet => 'अभी नहीं';

  @override
  String get backupCreating => 'बन रहा है…';

  @override
  String get backupMakeTheFileAnd => 'फ़ाइल बनाएँ और ले जाएँ';

  @override
  String get backupCreateBackup => 'बैकअप बनाएँ';

  @override
  String get backupNotMade => 'बैकअप नहीं बन पाया। दोबारा कोशिश करें।';

  @override
  String get backupNoSpace =>
      'बैकअप बनाने के लिए इस फ़ोन पर पर्याप्त ख़ाली जगह नहीं है। थोड़ी जगह ख़ाली करें और दोबारा कोशिश करें।';

  @override
  String get backupNoSpaceDesk =>
      'बैकअप बनाने के लिए इस कंप्यूटर पर पर्याप्त ख़ाली जगह नहीं है। थोड़ी जगह ख़ाली करें और दोबारा कोशिश करें।';

  @override
  String get backupHiddenNotIn => 'छिपी चैट इसमें नहीं हैं।';

  @override
  String get backupHiddenIncluded => 'आपकी छिपी चैट भी इसमें हैं।';

  @override
  String get backupMoveHiddenStay =>
      'छिपी चैट इसी फ़ोन पर रहती हैं और इसके साथ ही मिटा दी जाती हैं।';

  @override
  String get backupMoveHiddenStayDesk =>
      'छिपी चैट इसी कंप्यूटर पर रहती हैं और इसके साथ ही मिटा दी जाती हैं।';

  @override
  String get backupHiddenGone =>
      'Kryfo लॉक होते ही आपकी छिपी चैट बंद हो गईं। उन्हें उनके PIN से खोलें और वहीं से बैकअप लें।';

  @override
  String get blockedBlocked => 'ब्लॉक किए गए';

  @override
  String get blockedNoOneIsBlocked => 'कोई ब्लॉक नहीं है';

  @override
  String get commonUnblock => 'अनब्लॉक करें';

  @override
  String get bridgesConnected => 'जुड़ा हुआ';

  @override
  String get bridgesFromTheTorProject => 'Tor Project से';

  @override
  String get bridgesPasteFromClipboard => 'क्लिपबोर्ड से पेस्ट करें';

  @override
  String bridges1LineSaved(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString लाइनें सेव हुईं',
      one: '$countString लाइन सेव हुई',
    );
    return '$_temp0';
  }

  @override
  String get bridgesWhenYouAskFor =>
      'जब आप ब्रिज माँगते हैं, तो Tor Project आपका पता देखता है। यह सामान्य है: Tor Browser और हर Tor ऐप ब्रिज ऐसे ही पाते हैं, और इससे उन्हें बस इतना पता चलता है कि किसी ने ब्रिज माँगे। आपकी चैट के बारे में कुछ नहीं।';

  @override
  String get cameraNoCameraOnThis => 'इस फ़ोन में कैमरा नहीं है';

  @override
  String get cameraCameraNotAvailable => 'कैमरा उपलब्ध नहीं है';

  @override
  String get cameraCameraPermissionIsOff => 'कैमरे की अनुमति बंद है';

  @override
  String get cameraOpenSettings => 'सेटिंग खोलें';

  @override
  String get cameraCouldNotStripThat =>
      'उस फ़ोटो से जानकारी नहीं हटा पाए, इसलिए उसे छोड़ दिया';

  @override
  String get cameraNoPhotoCameOut => 'कोई फ़ोटो नहीं बनी';

  @override
  String get cameraCouldNotStartRecording => 'रिकॉर्डिंग शुरू नहीं हो पाई';

  @override
  String get cameraTheRecordingWasLost => 'रिकॉर्डिंग खो गई';

  @override
  String get cameraACopyIsIn => 'एक कॉपी आपकी फ़ोटो में है';

  @override
  String get cameraCouldNotSaveA => 'इस फ़ोन पर कॉपी सेव नहीं हो पाई';

  @override
  String get cameraTooLongForA => 'मैसेज के लिए बहुत लंबा · अधिकतम 50 MB';

  @override
  String get cameraNeverSavedToYour => 'आपकी फ़ोटो में कभी सेव नहीं होती';

  @override
  String get cameraNoExifNeverSaved =>
      'कोई EXIF नहीं, आपकी फ़ोटो में कभी सेव नहीं होती';

  @override
  String get cameraRec => 'रिकॉर्ड';

  @override
  String get cameraSwitchCamera => 'कैमरा बदलें';

  @override
  String get cameraStopRecording => 'रिकॉर्डिंग रोकें';

  @override
  String get cameraStartRecording => 'रिकॉर्डिंग शुरू करें';

  @override
  String get cameraTakeAPhoto => 'फ़ोटो लें';

  @override
  String get cameraKeepACopy => 'एक कॉपी रखें';

  @override
  String get cameraUseThis => 'यही इस्तेमाल करें';

  @override
  String get chatYouAreOfflineThis =>
      'आप ऑफ़लाइन हैं · दोबारा जुड़ते ही यह अपने-आप चला जाएगा';

  @override
  String get chatStillConnectingToTor =>
      'अभी Tor से जुड़ रहा है · यह अपने-आप चला जाएगा';

  @override
  String chatS(Object seconds) {
    return '$seconds से';
  }

  @override
  String chatM(Object seconds) {
    return '$seconds मि';
  }

  @override
  String chatH(Object seconds) {
    return '$seconds घं';
  }

  @override
  String chatD(Object seconds) {
    return '$seconds दिन';
  }

  @override
  String get chat0s => '0 से';

  @override
  String chatHM(Object h, Object m) {
    return '$h घं $m मि';
  }

  @override
  String chatMS(Object m, Object s) {
    return '$m मि $s से';
  }

  @override
  String chatS2(Object s) {
    return '$s से';
  }

  @override
  String get chatNewMessages => 'नए मैसेज';

  @override
  String chatEarlierMessagesArrived(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString पुराने मैसेज आए',
      one: '$countString पुराना मैसेज आया',
    );
    return '$_temp0';
  }

  @override
  String get chatUnsave => 'सेव से हटाएँ';

  @override
  String get chatForward => 'फ़ॉरवर्ड करें';

  @override
  String get commonShare => 'शेयर करें';

  @override
  String get commonCopied => 'कॉपी हो गया';

  @override
  String get commonCopy => 'कॉपी करें';

  @override
  String get chatUnpin => 'अनपिन करें';

  @override
  String get chatPin => 'पिन करें';

  @override
  String get chatStopSending => 'भेजना रोकें';

  @override
  String get chatUnsend => 'वापस लें';

  @override
  String get commonEdit => 'बदलें';

  @override
  String get chatYou => 'आप';

  @override
  String get chatUnsendMessage => 'मैसेज वापस लें';

  @override
  String get chatItDisappearsWithNo =>
      'यह दोनों फ़ोन से हट जाएगा, अगर पहले ही सेव न किया गया हो। इसे पलटा नहीं जा सकता।';

  @override
  String get chatItDisappearsWithNoDesk =>
      'यह दोनों डिवाइस से हट जाएगा, अगर पहले ही सेव न किया गया हो। इसे पलटा नहीं जा सकता।';

  @override
  String chatThisChatHasPins(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'इस चैट में पहले से $countString पिन हैं',
      one: 'इस चैट में पहले से $countString पिन है',
    );
    return '$_temp0';
  }

  @override
  String get chatUnpinThisMessage => 'इस मैसेज को अनपिन करें?';

  @override
  String get chatPinThisMessage => 'इस मैसेज को पिन करें?';

  @override
  String get chatItLeavesThePinned =>
      'यह आप दोनों के लिए पिन की सूची से हट जाएगा।';

  @override
  String get chatItGoesUnderThe =>
      'यह चैट में सबसे ऊपर पिन के नीचे जाएगा, आप दोनों के लिए।';

  @override
  String get chatPinIt => 'पिन करें';

  @override
  String get chatNotNow => 'अभी नहीं';

  @override
  String get chatEditMessage => 'मैसेज बदलें';

  @override
  String get chat30Seconds => '30 सेकंड';

  @override
  String get chat1Minute => '1 मिनट';

  @override
  String get chat5Minutes => '5 मिनट';

  @override
  String get chat1Hour => '1 घंटा';

  @override
  String get chat24Hours => '24 घंटे';

  @override
  String get chatGhostTimer => 'मिटने वाले मैसेज';

  @override
  String get chatHowLongAfterReading =>
      'पढ़े जाने के कितनी देर बाद मैसेज मिट जाएँ? आपके अपने मैसेज भेजने के समय से गिने जाते हैं।';

  @override
  String get chatCamera => 'कैमरा';

  @override
  String get chatNoExifNeverSaved =>
      'कोई EXIF नहीं, आपकी फ़ोटो में कभी सेव नहीं होती';

  @override
  String get chatGallery => 'गैलरी';

  @override
  String get chatVideo => 'वीडियो';

  @override
  String get chatGifFromPhone => 'फ़ोन से GIF';

  @override
  String get chatGifFromPhoneDesk => 'कंप्यूटर से GIF';

  @override
  String get chatFile2 => 'फ़ाइल';

  @override
  String get chatAFewSeconds => 'कुछ सेकंड';

  @override
  String get chatUnderAMinute => 'एक मिनट से कम';

  @override
  String chatRoughlyMin(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'लगभग $countString मिनट',
    );
    return '$_temp0';
  }

  @override
  String chatB2(Object b) {
    return '$b b';
  }

  @override
  String chatKb2(Object b) {
    return '$b kb';
  }

  @override
  String chatMb2(Object b) {
    return '$b mb';
  }

  @override
  String get chatSendThis => 'यह फ़ाइल भेजें?';

  @override
  String chatOverTor(Object humanBytes, Object wireEstimate) {
    return '$humanBytes · Tor पर $wireEstimate';
  }

  @override
  String get chatBigFilesGoOut =>
      'बड़ी फ़ाइलें छोटे एन्क्रिप्टेड टुकड़ों में जाती हैं, इसलिए थोड़ा समय लगता है। ऐप खुला रखें, भेजना चलता रहेगा।';

  @override
  String get chatSendIt => 'भेजें';

  @override
  String get chatCouldNotReadThat => 'वह फ़ाइल पढ़ी नहीं जा सकी';

  @override
  String get chatCouldNotCleanThat => 'उस वीडियो को साफ़ नहीं कर पाए';

  @override
  String get chatGifTooBig8 => 'GIF बहुत बड़ा है · अधिकतम 8 MB';

  @override
  String get chatCouldNotCleanThatGif => 'उस GIF को साफ़ नहीं कर पाए';

  @override
  String get chatTorIsNotUp => 'Tor अभी जुड़ा नहीं है · लिंक प्रीव्यू नहीं';

  @override
  String get chatCouldnTReachIt => 'पेज तक नहीं पहुँच पाए · लिंक प्रीव्यू नहीं';

  @override
  String get chatNoTitleCameBack =>
      'इस पेज का कोई शीर्षक नहीं है · लिंक प्रीव्यू नहीं';

  @override
  String get chatCouldnTFetchIt => 'प्रीव्यू लोड नहीं हो पाया';

  @override
  String get chatNoSignalSessionRe => 'कोई Signal सत्र नहीं: दोबारा जोड़ें';

  @override
  String get chatMessageUnavailable => 'मैसेज उपलब्ध नहीं';

  @override
  String get chatYou2 => 'आप';

  @override
  String get chatThem => 'वे';

  @override
  String get chatVoiceMessage => 'वॉइस मैसेज';

  @override
  String get chatQuotedPhoto => 'फ़ोटो';

  @override
  String get chatViewContact => 'संपर्क देखें';

  @override
  String get chatUnmuteNotifications => 'सूचनाएँ फिर चालू करें';

  @override
  String get chatMuteNotifications => 'सूचनाएँ बंद करें';

  @override
  String get chatArchiveChat => 'चैट आर्काइव करें';

  @override
  String get chatWallpaper => 'वॉलपेपर';

  @override
  String get chatClearConversation => 'बातचीत साफ़ करें';

  @override
  String get chatNoteOnThisContact => 'इस संपर्क पर नोट';

  @override
  String get chatPinToTop => 'सबसे ऊपर पिन करें';

  @override
  String get chatBlockContact => 'संपर्क ब्लॉक करें';

  @override
  String get chatUnpinned => 'अनपिन हो गया';

  @override
  String get chatPinnedToTop => 'सबसे ऊपर पिन हुआ';

  @override
  String get chatJustForYouNever =>
      'सिर्फ़ आपके लिए। कभी भेजा नहीं जाता, कभी इस फ़ोन से बाहर नहीं जाता।';

  @override
  String get chatJustForYouNeverDesk =>
      'सिर्फ़ आपके लिए। कभी भेजा नहीं जाता, कभी इस कंप्यूटर से बाहर नहीं जाता।';

  @override
  String get chatAQuietReminder => 'एक छोटी-सी याद…';

  @override
  String get chatNoteSaved => 'नोट सेव हुआ';

  @override
  String get chatClearThisConversation => 'यह बातचीत साफ़ करें?';

  @override
  String get chatEveryMessageHereIs =>
      'यहाँ का हर मैसेज इस फ़ोन से मिट जाएगा। इससे सिर्फ़ आपकी कॉपी साफ़ होती है। उनके डिवाइस पर कोई असर नहीं पड़ता।';

  @override
  String get chatEveryMessageHereIsDesk =>
      'यहाँ का हर मैसेज इस कंप्यूटर से मिट जाएगा। इससे सिर्फ़ आपकी कॉपी साफ़ होती है। उनके डिवाइस पर कोई असर नहीं पड़ता।';

  @override
  String get chatClear => 'साफ़ करें';

  @override
  String get chatBlockThisContact => 'इस संपर्क को ब्लॉक करें?';

  @override
  String get chatTheirMessagesStopArriving =>
      'उनके मैसेज आना बंद हो जाते हैं और वे आपकी चैट से हट जाते हैं। उन्हें कभी बताया नहीं जाता। आप सेटिंग से कभी भी अनब्लॉक कर सकते हैं।';

  @override
  String get commonBlock => 'ब्लॉक करें';

  @override
  String get chatSaved => 'सेव हुआ';

  @override
  String get chatRemovedFromSaved => 'सेव से हटाया गया';

  @override
  String get chatForwardTo => 'किसे फ़ॉरवर्ड करें';

  @override
  String get chatNoContactsToForward => 'फ़ॉरवर्ड करने के लिए कोई संपर्क नहीं';

  @override
  String get chatToday => 'आज';

  @override
  String get chatYesterday => 'कल';

  @override
  String get chatThisMessageCanT => 'यह मैसेज दिखाया नहीं जा सकता';

  @override
  String get chatJumpToTheNewest => 'सबसे नए पर जाएँ';

  @override
  String get chatBuildingAPrivateRoute =>
      'एक निजी रास्ता बन रहा है · पहली बार जुड़ने में देर लगती है, बाद में जल्दी होता है। अभी जो भी भेजेंगे, वह क़तार में रहेगा और अपने-आप पहुँच जाएगा।';

  @override
  String get chatTheNextPhotoYou =>
      'आपकी भेजी अगली फ़ोटो सुरक्षित खुलेगी · Kryfo उसके स्क्रीनशॉट रोकता है';

  @override
  String get chatPhotoProtectionOff => 'फ़ोटो सुरक्षा बंद';

  @override
  String get chatAcceptToReplyThey =>
      'जवाब देने के लिए स्वीकार करें। तब तक वे एक और मैसेज भेज सकते हैं।';

  @override
  String chatIntroducedYouAcceptTo(Object introducer) {
    return '$introducer ने आपको मिलवाया। जवाब देने के लिए स्वीकार करें।';
  }

  @override
  String chatIntroducedYouSayHello(Object vouchNames) {
    return '$vouchNames ने आपको मिलवाया। नमस्ते कहें। उन्हें भी आपका कार्ड मिल गया है।';
  }

  @override
  String get chatIntroduceTo => 'किससे मिलवाएँ...';

  @override
  String get chatAcceptThemFirst => 'पहले उन्हें स्वीकार करें';

  @override
  String get chatMessageRequest => 'मैसेज अनुरोध';

  @override
  String get chatTheyNeedToAccept =>
      'बातचीत जारी रखने से पहले उन्हें स्वीकार करना होगा।';

  @override
  String get chatWaitingForThemTo =>
      'आपके अनुरोध को उनके स्वीकार करने का इंतज़ार';

  @override
  String get chatWaitsToSend => 'भेजने के इंतज़ार में';

  @override
  String get chatTheyMayNotKnow =>
      'हो सकता है उन्हें पता न हो कि आपने स्वीकार कर लिया';

  @override
  String get chatYouBlockedThisContact => 'आपने इस संपर्क को ब्लॉक किया है';

  @override
  String get chatSupporter => 'समर्थक';

  @override
  String get chatEncryptedDirect => 'एन्क्रिप्टेड · सीधे';

  @override
  String get chatEncryptedOverTor => 'एन्क्रिप्टेड · Tor से';

  @override
  String get chatSearchThisChat => 'इस चैट में खोजें';

  @override
  String get chatContactOptions => 'संपर्क के विकल्प';

  @override
  String get commonClose => 'बंद करें';

  @override
  String get chatFindInConversation => 'बातचीत में ढूँढें';

  @override
  String get chatNoMatches => 'कुछ नहीं मिला';

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
      other: '$countString में से *$posString*',
      one: '$countString में से *$posString*',
    );
    return '$_temp0';
  }

  @override
  String get chatPreviousMatch => 'पिछला नतीजा';

  @override
  String get chatNextMatch => 'अगला नतीजा';

  @override
  String get chatPhotoUnavailable => 'फ़ोटो उपलब्ध नहीं';

  @override
  String get chatDelivered => 'पहुँच गया';

  @override
  String get chatEdited => 'बदला गया';

  @override
  String get chatFailedTapToRetry => 'नहीं गया · फिर भेजने को टैप करें';

  @override
  String get chatReplyingTo => 'उन्हें जवाब';

  @override
  String get chatReplyingToYourself => 'ख़ुद को जवाब';

  @override
  String get chatReply => 'जवाब दें';

  @override
  String get chatSayHi => 'नमस्ते कहें।';

  @override
  String get chatJustTheTwoOf => 'सिर्फ़ आप दोनों, एंड-टू-एंड एन्क्रिप्टेड।';

  @override
  String get chatSayHiSoThey => 'नमस्ते कहें ताकि वे आपको देख सकें';

  @override
  String get chatTheyWonTKnow =>
      'जब तक आपका पहला मैसेज नहीं पहुँचता, उन्हें पता नहीं चलेगा कि आपने उन्हें जोड़ा है।';

  @override
  String get chatWave => 'हाथ हिलाएँ';

  @override
  String get chatMicPermissionNeeded => 'माइक की अनुमति चाहिए';

  @override
  String get chatTheMicWouldNot => 'माइक शुरू नहीं हुआ। दोबारा कोशिश करें';

  @override
  String get chatReleaseToCancel => 'रद्द करने के लिए छोड़ दें';

  @override
  String get chatVoiceHiddenSlideTo =>
      'आवाज़ बदली हुई · रद्द करने के लिए खिसकाएँ';

  @override
  String get chatSlideToCancel => 'रद्द करने के लिए खिसकाएँ';

  @override
  String get chatGhostMode => 'मिटने वाले मैसेज';

  @override
  String chatMessagesBurnAfter(Object humanBurn) {
    return '$humanBurn बाद मिट जाते हैं';
  }

  @override
  String get chatTimedMessages => 'मिटने वाले मैसेज';

  @override
  String get chatOpenTheCamera => 'कैमरा खोलें';

  @override
  String get chatAttachAPhoto => 'फ़ोटो जोड़ें';

  @override
  String get chatMessage => 'मैसेज';

  @override
  String get commonSend => 'भेजें';

  @override
  String get chatHoldToRecord => 'वॉइस नोट रिकॉर्ड करने के लिए दबाकर रखें';

  @override
  String get chatSecurityCodeChanged => 'सुरक्षा कोड बदल गया';

  @override
  String get chatCompareTitle => 'सुरक्षा नंबर मिलाएँ';

  @override
  String chatCompareLine(Object peerName) {
    return 'तीन शब्दों की नक़ल की जा सकती है। यह पक्का करने के लिए कि यह चैट सच में $peerName से है, उनके साथ सुरक्षा नंबर मिलाएँ, आमने-सामने या कॉल पर।';
  }

  @override
  String get chatCompareLater => 'बाद में';

  @override
  String get chatCompareNow => 'मिलाएँ';

  @override
  String chatKeyHeldLine(Object peerName) {
    return 'आपने पहले $peerName की पुष्टि की थी। जब तक आप नया नंबर जाँच न लें या नई कुंजी स्वीकार न करें, कुछ भी नहीं भेजा जाएगा। उनके मैसेज फिर भी आते रहेंगे।';
  }

  @override
  String get chatCheckTheNumber => 'नंबर जाँचें';

  @override
  String get chatAcceptNewKey => 'नई कुंजी स्वीकार करें';

  @override
  String get chatAcceptNewKeyTitle => 'उनकी नई कुंजी स्वीकार करें?';

  @override
  String chatAcceptNewKeyLine(Object peerName) {
    return 'इसके बाद Kryfo बिना जाँच के नई कुंजी पर भेजेगा, और $peerName पुष्टि किए हुए नहीं दिखेंगे। आप कभी भी उनकी दोबारा पुष्टि कर सकते हैं।';
  }

  @override
  String chatMayHaveReinstalledOr(Object peerName) {
    return 'हो सकता है $peerName ने ऐप दोबारा इंस्टॉल किया हो, या कोई उनका रूप धरकर बात कर रहा हो। पक्का करने के लिए सुरक्षा नंबर मिलाएँ।';
  }

  @override
  String get chatOk => 'ठीक है';

  @override
  String get chatVerify => 'पुष्टि करें';

  @override
  String get cleanKryfoCanTClean =>
      'Kryfo अभी इस तरह की फ़ाइल साफ़ नहीं कर सकता।';

  @override
  String get cleanThisIsAMotion => 'यह मोशन फ़ोटो है।';

  @override
  String get cleanThisPictureIsToo =>
      'यह तस्वीर यहाँ साफ़ करने के लिए बहुत बड़ी है।';

  @override
  String get cleanThisFileIsDamaged => 'यह फ़ाइल ख़राब है या अधूरी है।';

  @override
  String get cleanKryfoCouldNotMake => 'Kryfo इसे साफ़ नहीं कर पाया।';

  @override
  String get cleanNotEnoughRoomOn => 'फ़ोन पर पर्याप्त जगह नहीं है।';

  @override
  String get cleanNotEnoughRoomOnDesk => 'कंप्यूटर पर पर्याप्त जगह नहीं है।';

  @override
  String get cleanKryfoCouldNotOpen => 'Kryfo वह फ़ाइल नहीं खोल पाया।';

  @override
  String get cleanItCleansJpegPng =>
      'यह JPEG, PNG, WebP, HEIC, AVIF, GIF, MP4 और MOV साफ़ करता है। कुछ भी नहीं बदला गया।';

  @override
  String get cleanItHoldsAShort =>
      'इसमें तस्वीर के साथ एक छोटा वीडियो है, और Kryfo अभी वह हिस्सा साफ़ नहीं कर सकता। अपने कैमरे में मोशन बंद करें, या इसका स्क्रीनशॉट भेजें।';

  @override
  String get cleanPicturesOver64Mb =>
      '64 MB से बड़ी तस्वीरें फ़ोन पर साफ़ नहीं की जातीं। कुछ भी नहीं बदला गया।';

  @override
  String get cleanPicturesOver64MbDesk =>
      '64 MB से बड़ी तस्वीरें कंप्यूटर पर साफ़ नहीं की जातीं। कुछ भी नहीं बदला गया।';

  @override
  String get cleanKryfoCouldNotRead =>
      'Kryfo इसे आख़िर तक पढ़ नहीं पाया, इसलिए इसे साफ़ नहीं कहेगा। कोई कॉपी नहीं बनी।';

  @override
  String get cleanSomethingInsideIsOf =>
      'अंदर कुछ ऐसा है जिसे हटाना उसे नहीं आता, इसलिए कोई कॉपी नहीं बनी।';

  @override
  String get cleanFreeSomeSpaceAnd =>
      'थोड़ी जगह ख़ाली करें और दोबारा कोशिश करें। कुछ भी नहीं बदला गया।';

  @override
  String get cleanTheAppThatShared =>
      'जिस ऐप ने इसे शेयर किया, शायद उसने इसे वापस ले लिया। फिर से शेयर करके देखें।';

  @override
  String get cleanTheAppThatSharedDesk =>
      'शायद यह कहीं और चली गई, या कोई दूसरा ऐप इसे खोले हुए है। इसे फिर से चुनकर देखें।';

  @override
  String get cleanNoAppOnThis => 'इस फ़ोन के किसी ऐप ने फ़ाइल नहीं ली।';

  @override
  String get cleanCouldNotSaveIt =>
      'सेव नहीं हो पाया। देखें कि फ़ोन में जगह है।';

  @override
  String get cleanCouldNotSaveItDesk =>
      'सेव नहीं हो पाया। देखें कि कंप्यूटर में जगह है।';

  @override
  String get cleanTheOriginalIsGone =>
      'मूल फ़ाइल हट गई। साफ़ कॉपी बनी रहती है।';

  @override
  String get cleanAndroidWouldNotDelete =>
      'Android ने इसे डिलीट नहीं किया। गैलरी से इसे ख़ुद हटाएँ।';

  @override
  String get cleanCleanCopy => 'साफ़ कॉपी';

  @override
  String get cleanShareCleanCopy => 'साफ़ कॉपी शेयर करें';

  @override
  String get cleanSaveToGallery => 'गैलरी में सेव करें';

  @override
  String get cleanSaveToGalleryDesk => 'साफ़ कॉपी सेव करें';

  @override
  String get commonStop => 'रोकें';

  @override
  String get cleanReadingTheFile => 'फ़ाइल पढ़ी जा रही है';

  @override
  String get cleanCleaning => 'साफ़ हो रही है';

  @override
  String cleanOf(Object prettySize, Object prettySize2) {
    return '$prettySize2 में से $prettySize';
  }

  @override
  String get cleanEverythingStaysOnThis => 'सब कुछ इसी फ़ोन पर रहता है।';

  @override
  String get cleanEverythingStaysOnThisDesk =>
      'सब कुछ इसी कंप्यूटर पर रहता है।';

  @override
  String get cleanAlreadyClean => 'पहले से साफ़ है।';

  @override
  String get cleanClean => 'साफ़।';

  @override
  String get cleanThereWasNothingTo => 'ढूँढने को कुछ नहीं था।';

  @override
  String get cleanNothingLeftToFind => 'अब ढूँढने को कुछ नहीं बचा।';

  @override
  String get cleanSameVideoSameQuality => 'वही वीडियो, वही क्वालिटी';

  @override
  String get cleanSamePictureSameQuality => 'वही तस्वीर, वही क्वालिटी';

  @override
  String get cleanSamePicture => 'वही तस्वीर';

  @override
  String cleanRemoved(Object label) {
    return '$label, हटाया गया';
  }

  @override
  String get cleanRemoved2 => 'हटाया गया';

  @override
  String get cleanWithTheLocationInside =>
      'और उसके अंदर लोकेशन है। जिसे भी वह मिलेगी, उसे आपकी गली पता चल जाएगी।';

  @override
  String get cleanWithEverythingItKnew =>
      'और जो कुछ उसे पता था, वह सब अभी भी उसके अंदर है।';

  @override
  String get cleanOriginal => 'मूल';

  @override
  String get cleanClean2 => 'साफ़';

  @override
  String get cleanSavedToYourGallery => 'आपकी गैलरी में सेव हो गया।';

  @override
  String get cleanSavedToYourGalleryDesk => 'आपकी चुनी जगह पर सेव हो गया।';

  @override
  String cleanTheOriginalIsStill(Object what) {
    return 'मूल फ़ाइल भी अभी वहीं है, $what';
  }

  @override
  String cleanTheOriginalIsStillWhereIt(Object what) {
    return 'मूल फ़ाइल अभी भी वहीं है जहाँ थी, $what Kryfo इसे यहाँ से नहीं हटा सकता, इसलिए जिस ऐप से यह आई, उसी में इसे डिलीट करें।';
  }

  @override
  String get cleanDeleteTheOriginal => 'मूल फ़ाइल डिलीट करें';

  @override
  String get cleanKeepBoth => 'दोनों रखें';

  @override
  String get commonDone => 'हो गया';

  @override
  String get cleanAndroidWillAskYou => 'ANDROID आपसे पुष्टि माँगेगा';

  @override
  String get contactYourNameForThem => 'उनके लिए आपका रखा नाम';

  @override
  String get contactStaysOnThisPhone =>
      'इसी फ़ोन पर रहता है। वे इसे कभी नहीं देखते।';

  @override
  String get contactStaysOnThisPhoneDesk =>
      'इसी कंप्यूटर पर रहता है। वे इसे कभी नहीं देखते।';

  @override
  String get contactClear => 'साफ़ करें';

  @override
  String get contactMessage => 'मैसेज';

  @override
  String get contactKeysVerified => 'कुंजियों की पुष्टि हुई';

  @override
  String get contactVerifyKeys => 'कुंजियों की पुष्टि करें';

  @override
  String get contactVouches => 'सिफ़ारिशें';

  @override
  String get contactUnmute => 'अनम्यूट करें';

  @override
  String get contactMute => 'म्यूट करें';

  @override
  String get contactUnpin => 'अनपिन करें';

  @override
  String get contactPinToTop => 'सबसे ऊपर पिन करें';

  @override
  String get contactArchive => 'आर्काइव करें';

  @override
  String get contactOutOfTheList => 'जब तक वे फिर न लिखें, सूची से बाहर';

  @override
  String contactBlock(Object name) {
    return '$name को ब्लॉक करें?';
  }

  @override
  String get contactTheirMessagesStopArriving =>
      'उनके मैसेज आना बंद हो जाते हैं। उन्हें बताया नहीं जाता।';

  @override
  String get contactDeleteChat => 'चैट डिलीट करें';

  @override
  String get contactMessagesAndContactGone =>
      'मैसेज और संपर्क, इस फ़ोन से हट जाएँगे';

  @override
  String get contactMessagesAndContactGoneDesk =>
      'मैसेज और संपर्क, इस कंप्यूटर से हट जाएँगे';

  @override
  String get contactDeleteThisChat => 'यह चैट डिलीट करें?';

  @override
  String get contactEveryMessageAndThe =>
      'हर मैसेज और संपर्क इस फ़ोन से हट जाएगा। उन्हें कुछ नहीं भेजा जाता।';

  @override
  String get contactEveryMessageAndTheDesk =>
      'हर मैसेज और संपर्क इस कंप्यूटर से हट जाएगा। उन्हें कुछ नहीं भेजा जाता।';

  @override
  String get commonDelete => 'डिलीट करें';

  @override
  String get contactDeleted => 'डिलीट हो गया';

  @override
  String get contactToday => 'आज';

  @override
  String contactD(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count दिन',
    );
    return '$_temp0';
  }

  @override
  String contactMo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count माह',
    );
    return '$_temp0';
  }

  @override
  String contactY(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count साल',
    );
    return '$_temp0';
  }

  @override
  String get contactVerified => 'पुष्टि हुई';

  @override
  String get contactChatting => 'बातचीत';

  @override
  String get contactNothingSharedYet => 'अभी कुछ शेयर नहीं हुआ';

  @override
  String contactSharedMedia(Object count) {
    return 'शेयर किया मीडिया · $count';
  }

  @override
  String get donateBitcoin => 'Bitcoin';

  @override
  String get donateText => '₿';

  @override
  String get donateBadgeUnlocks => 'बैज मिलता है';

  @override
  String get donateMonero => 'Monero';

  @override
  String get donateManualNoBadge => 'ख़ुद से · बैज नहीं';

  @override
  String get donateSolana => 'Solana';

  @override
  String get donateEthereum => 'Ethereum';

  @override
  String get donateText2 => 'Ξ';

  @override
  String donateYourEarlierBitcoinPayment(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter': 'आपका पिछला bitcoin भुगतान मिल गया · समर्थक बैज मिल गया',
      'patron': 'आपका पिछला bitcoin भुगतान मिल गया · संरक्षक बैज मिल गया',
      'guardian': 'आपका पिछला bitcoin भुगतान मिल गया · रक्षक बैज मिल गया',
      'other': 'आपका पिछला bitcoin भुगतान मिल गया · समर्थक बैज मिल गया',
    });
    return '$_temp0';
  }

  @override
  String get donateSupport => 'सहयोग दें';

  @override
  String get donateKeepKryfo => 'Kryfo को *आज़ाद* रखें';

  @override
  String get donateNoAdsNoInvestors =>
      'न विज्ञापन, न निवेशक, बेचने को कुछ नहीं। यह समर्थकों के दिए पैसों से चलता है।';

  @override
  String get donateBackItAnonymouslyBadge =>
      'गुमनाम रहकर सहयोग दें। बैज आपकी मर्ज़ी।\n*हर प्राइवेसी फ़ीचर मुफ़्त है।*';

  @override
  String get donateAuditTitle => 'सुरक्षा ऑडिट के ख़र्च में मदद करें';

  @override
  String get donateAuditLine =>
      'यहाँ दिया दान एक स्वतंत्र ऑडिट के लिए जुड़ता है। पूरी रिपोर्ट सार्वजनिक होगी।';

  @override
  String get donateCard => 'कार्ड';

  @override
  String get donateCardOneTime =>
      'आपके ब्राउज़र में एक बार का दान। रक़म आप चुनते हैं।';

  @override
  String get donateCardMarios =>
      'जब तक हमारा वित्तीय होस्ट तय नहीं होता, कार्ड से भुगतान सीधे Marios को जाता है।';

  @override
  String get donateCardSeesName =>
      'भुगतान कंपनी आपका नाम देखती है। निजी तरीक़ा क्रिप्टो है।';

  @override
  String get donateCardPay => 'कार्ड से भुगतान करें';

  @override
  String get donateNoBitcoinCard => 'bitcoin नहीं है? कार्ड से भुगतान करें';

  @override
  String get donateCardNoBadge => 'कार्ड से दान पर बैज नहीं मिलता।';

  @override
  String donateAddressCheckItAgainst(Object coinName) {
    return '$coinName पता · अपने वॉलेट से मिलाकर देखें';
  }

  @override
  String get donateAddressCopiedClearsIn =>
      'पता कॉपी हुआ · 60 सेकंड में मिट जाएगा';

  @override
  String get donateCopyAddress => 'पता कॉपी करें';

  @override
  String get donateBitcoinIsVerifiedBy =>
      'Bitcoin की पुष्टि हमारा अपना नोड करता है, इसलिए भुगतान पहुँचते ही आपका बैज अपने-आप मिल जाता है।';

  @override
  String get donateWeCanTVerify =>
      'इस चेन की पुष्टि हम किसी बाहरी सेवा से आपके बारे में पूछे बिना नहीं कर सकते, इसलिए हम नहीं करते। चाहें तो भेजें। इससे बैज नहीं मिलेगा।';

  @override
  String get donateBitcoinBadgesNeedOnion =>
      'Bitcoin बैज के लिए onion मोड चाहिए';

  @override
  String get donateSwitchToOnion => 'onion पर जाएँ';

  @override
  String get donatePayWithBitcoin => 'bitcoin से भुगतान करें  →';

  @override
  String get donateBadgesStartAt20 => 'बैज \$20 से शुरू होते हैं';

  @override
  String get donateShowTheAddress => 'पता दिखाएँ';

  @override
  String donateReviewAmount(String amount) {
    return 'bitcoin में $amount';
  }

  @override
  String get donateWhatTheBadgeGives => 'बैज से क्या मिलता है';

  @override
  String get donateGivesMark =>
      'आपके नाम के पास एक निशान। इसे कौन देखे, या कोई न देखे, यह आप तय करते हैं।';

  @override
  String get donateGivesReceipt =>
      'इस फ़ोन पर रखी एक हस्ताक्षरित रसीद। यह बिना किसी खाते के बैज को साबित करती है।';

  @override
  String get donateGivesReceiptDesk =>
      'इस कंप्यूटर पर रखी एक हस्ताक्षरित रसीद। यह बिना किसी खाते के बैज को साबित करती है।';

  @override
  String get donateGivesFree =>
      'बैज हो या न हो, निजता की हर सुविधा मुफ़्त रहती है।';

  @override
  String get donateAddressOnTap =>
      'पता तभी बनता है जब आप नीचे टैप करते हैं। यह एक घंटे तक आपका रहता है, इसलिए लौटने पर आपको वही पता मिलता है।';

  @override
  String get donateBitcoinBusy =>
      'Bitcoin अभी व्यस्त है। बाद में फिर कोशिश करें या कार्ड से भुगतान करें।';

  @override
  String get donateBusyPlainAddress =>
      'आप अब भी नीचे दिए पते पर bitcoin भेज सकते हैं। इससे बैज नहीं मिलता।';

  @override
  String get donateSameAddressAgain =>
      'यह वही पता है जो आपने पहले खोला था। अगर आप भेज चुके हैं, तो यहीं प्रतीक्षा करें।';

  @override
  String get donateReachingThePaymentService =>
      'Tor से भुगतान सेवा तक पहुँच रहे हैं…';

  @override
  String get donateThisCanTakeUp => 'इसमें एक-दो मिनट लग सकते हैं';

  @override
  String donateSThisCanTake(Object waited) {
    return '$waited सेकंड · इसमें एक-दो मिनट लग सकते हैं';
  }

  @override
  String get donateUseTheAddressInstead => 'इसके बजाय पता इस्तेमाल करें';

  @override
  String get donateThePaymentServiceIs =>
      'भुगतान सेवा एक onion है, और सिर्फ़ onion मोड ही उस तक पहुँच सकता है। कुछ नहीं भेजा गया।';

  @override
  String get donateTorWasSlowTo =>
      'Tor भुगतान सेवा तक पहुँचने में धीमा रहा। आप नीचे दिए पते पर दान कर सकते हैं, पर आपका बैज अपने-आप नहीं मिलेगा। बैज के लिए बाद में फिर कोशिश करें।';

  @override
  String get donateThePaymentServiceIsHavingTrouble =>
      'भुगतान सेवा में अभी दिक़्क़त है। आप फिर भी नीचे दिए पते पर दान कर सकते हैं, पर आपका बैज अपने-आप नहीं मिलेगा। बैज के लिए बाद में फिर कोशिश करें।';

  @override
  String get commonTryAgain => 'दोबारा कोशिश करें';

  @override
  String donateBtc(Object btc) {
    return '$btc BTC';
  }

  @override
  String donateSendExactlyThisAmount(Object fmtLeft) {
    return 'ठीक इतनी ही रक़म भेजें · $fmtLeft में ख़त्म होगा';
  }

  @override
  String get donateOpenWallet => 'वॉलेट खोलें';

  @override
  String get donateThisScreenUpdatesItself =>
      'आपका भुगतान दिखते ही यह स्क्रीन अपने-आप बदल जाती है।\nइसे खुला रखें। कुछ भी सेव नहीं होता और कुछ भी आपकी पहचान नहीं बताता।';

  @override
  String get donateWatchingTheChainFor => 'चेन पर आपके भुगतान का इंतज़ार';

  @override
  String get donateThisInvoiceExpired => 'इस इनवॉइस का समय ख़त्म हो गया';

  @override
  String get donateInvoicesTimeOutIf =>
      'इनवॉइस का समय ख़त्म हो जाता है। अगर आपने भुगतान भेज दिया है, तो इसे खुला रखें: हम कुछ देर तक हर मिनट सेवा से फिर पूछते हैं, और अगली बार जब आप सहयोग वाला पेज खोलेंगे तब भी। जब चाहें, नया इनवॉइस शुरू करें।';

  @override
  String get donateNewInvoice => 'नया इनवॉइस';

  @override
  String get donateIPaidCheckAgain => 'मैंने भुगतान किया, फिर जाँचें';

  @override
  String get donateNoWallet =>
      'यहाँ कोई वॉलेट ऐप bitcoin लिंक नहीं खोलता। इसके बजाय पता कॉपी करें।';

  @override
  String get donateChecking => 'जाँच हो रही है…';

  @override
  String get donateNotSeenYet =>
      'अभी नहीं दिखा। भुगतान दिखने में कुछ मिनट लग सकते हैं।';

  @override
  String get donatePaymentConfirmed => 'भुगतान की पुष्टि हुई';

  @override
  String get donateThankYouForKeeping => 'Kryfo को आज़ाद रखने के लिए धन्यवाद।';

  @override
  String donateVerifiedOnChainYou(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter':
          'चेन पर पुष्टि हो गई। अब आप समर्थक हैं। यह आपसे कोई नहीं छीन सकता।',
      'patron':
          'चेन पर पुष्टि हो गई। अब आप संरक्षक हैं। यह आपसे कोई नहीं छीन सकता।',
      'guardian':
          'चेन पर पुष्टि हो गई। अब आप रक्षक हैं। यह आपसे कोई नहीं छीन सकता।',
      'other':
          'चेन पर पुष्टि हो गई। अब आप समर्थक हैं। यह आपसे कोई नहीं छीन सकता।',
    });
    return '$_temp0';
  }

  @override
  String donateVerifiedBadgeStays(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter':
          'चेन पर पुष्टि हो गई। फिर से सहयोग के लिए धन्यवाद। आपका समर्थक बैज आपके पास ही रहता है।',
      'patron':
          'चेन पर पुष्टि हो गई। फिर से सहयोग के लिए धन्यवाद। आपका संरक्षक बैज आपके पास ही रहता है।',
      'guardian':
          'चेन पर पुष्टि हो गई। फिर से सहयोग के लिए धन्यवाद। आपका रक्षक बैज आपके पास ही रहता है।',
      'other':
          'चेन पर पुष्टि हो गई। फिर से सहयोग के लिए धन्यवाद। आपका समर्थक बैज आपके पास ही रहता है।',
    });
    return '$_temp0';
  }

  @override
  String get donateWearMyBadge => 'मेरा बैज दिखाएँ';

  @override
  String get donateJustGladToHelp => 'बस मदद करके ख़ुश हूँ';

  @override
  String get gettingMessagesAlwaysOn => 'हमेशा चालू';

  @override
  String get gettingMessagesMostPrivate => 'सबसे निजी';

  @override
  String get gettingMessagesMessagesArriveInstantlyNothing =>
      'बैटरी सबसे ज़्यादा लगती है।\nतुरंत, और कुछ भी Tor से बाहर नहीं जाता।';

  @override
  String get gettingMessagesArriveInstantlyFast =>
      'बैटरी सबसे ज़्यादा लगती है।\nतेज़ पर तुरंत।';

  @override
  String get gettingMessagesCheckIns => 'समय-समय पर जाँच';

  @override
  String get gettingMessagesLightest => 'सबसे हल्का';

  @override
  String get gettingMessagesKryfoLooksForMessages =>
      'Kryfo हर 15 मिनट में देखता है, इसलिए मैसेज देर से आ सकते हैं।\nबैटरी कम लगती है।';

  @override
  String get gettingMessagesAGenericAlertWith =>
      'एक आम सूचना, जिसमें न भेजने वाले का नाम होता है, न मैसेज';

  @override
  String get gettingMessagesShowsMessageTextIn =>
      'सूचनाओं में मैसेज दिखाता है, Kryfo लॉक होने पर भी।';

  @override
  String get gettingMessagesWhenThePhoneSits =>
      'जब फ़ोन पड़ा रहता है, Android जाँचों के बीच का समय बढ़ा देता है। ऊपर की लाइन असली पिछली जाँच दिखाती है। Kryfo खुला रहने तक जुड़ा रहता है।';

  @override
  String get groupChatJumpToTheNewest => 'सबसे नए पर जाएँ';

  @override
  String get groupChatYou => 'आप';

  @override
  String get groupChatVoiceMessage => 'वॉइस मैसेज';

  @override
  String get groupChatQuotedPhoto => 'फ़ोटो';

  @override
  String get groupChatMessageUnavailable => 'मैसेज उपलब्ध नहीं';

  @override
  String get groupChatTorIsNotUp =>
      'Tor अभी जुड़ा नहीं है · लिंक प्रीव्यू नहीं';

  @override
  String get groupChatCouldnTReachIt =>
      'पेज तक नहीं पहुँच पाए · लिंक प्रीव्यू नहीं';

  @override
  String get groupChatNoTitleCameBack =>
      'इस पेज का कोई शीर्षक नहीं है · लिंक प्रीव्यू नहीं';

  @override
  String get groupChatCouldnTFetchIt => 'प्रीव्यू लोड नहीं हो पाया';

  @override
  String get groupChatCamera => 'कैमरा';

  @override
  String get groupChatGallery => 'गैलरी';

  @override
  String get groupChatVideo => 'वीडियो';

  @override
  String get groupChatGifFromPhone => 'फ़ोन से GIF';

  @override
  String get groupChatGifFromPhoneDesk => 'कंप्यूटर से GIF';

  @override
  String get groupChatCouldNotReadThat => 'वह फ़ाइल पढ़ी नहीं जा सकी';

  @override
  String get groupChatGifTooBig8 => 'GIF बहुत बड़ा है · अधिकतम 8 MB';

  @override
  String get groupChatCouldNotCleanThat => 'उस GIF को साफ़ नहीं कर पाए';

  @override
  String get groupChatCouldNotCleanThatVideo => 'उस वीडियो को साफ़ नहीं कर पाए';

  @override
  String get groupChatToday => 'आज';

  @override
  String get groupChatYesterday => 'कल';

  @override
  String get groupChatYou2 => 'आप';

  @override
  String groupChatThisChatHasPins(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'इस चैट में पहले से $countString पिन हैं',
      one: 'इस चैट में पहले से $countString पिन है',
    );
    return '$_temp0';
  }

  @override
  String get groupChatUnpinThisMessage => 'इस मैसेज को अनपिन करें?';

  @override
  String get groupChatPinThisMessage => 'इस मैसेज को पिन करें?';

  @override
  String get groupChatItLeavesThePinned =>
      'यह यहाँ सभी के लिए पिन की सूची से हट जाएगा।';

  @override
  String get groupChatItGoesUnderThe =>
      'यह चैट में सबसे ऊपर पिन के नीचे जाएगा, यहाँ सभी के लिए।';

  @override
  String get groupChatUnpin => 'अनपिन करें';

  @override
  String get groupChatPinIt => 'पिन करें';

  @override
  String get groupChatNotNow => 'अभी नहीं';

  @override
  String get groupChatSaved => 'सेव हुआ';

  @override
  String get groupChatRemovedFromSaved => 'सेव से हटाया गया';

  @override
  String get groupChatForwardTo => 'किसे फ़ॉरवर्ड करें';

  @override
  String get groupChatNoContactsToForward =>
      'फ़ॉरवर्ड करने के लिए कोई संपर्क नहीं';

  @override
  String get groupChatEditMessage => 'मैसेज बदलें';

  @override
  String get groupChatUnsendMessage => 'मैसेज वापस लें';

  @override
  String get groupChatItDisappearsWithNo =>
      'यह सबके फ़ोन से हट जाएगा, अगर पहले ही सेव न किया गया हो। इसे पलटा नहीं जा सकता।';

  @override
  String get groupChatItDisappearsWithNoDesk =>
      'यह सबके डिवाइस से हट जाएगा, अगर पहले ही सेव न किया गया हो। इसे पलटा नहीं जा सकता।';

  @override
  String get groupChatUnsend => 'वापस लें';

  @override
  String groupChatThisRoomAndEverything(Object expiryWords) {
    return 'यह रूम और इसमें मौजूद सब कुछ $expiryWords में मिट जाएगा';
  }

  @override
  String groupChatGhostModeOnBurns(Object fmtBurn) {
    return 'मिटने वाले मैसेज · $fmtBurn बाद मिट जाते हैं';
  }

  @override
  String get groupChatGroupCreatedSayHi => 'ग्रुप बन गया। नमस्ते कहें।';

  @override
  String get groupChatNoMessagesYet => 'अभी कोई मैसेज नहीं।';

  @override
  String get groupChatEveryoneHereReads =>
      'यहाँ हर कोई पढ़ता है जो आप लिखते हैं।';

  @override
  String get groupChatNobodyHereYet => 'अभी यहाँ कोई नहीं है।';

  @override
  String get groupChatShareTheRoomLink =>
      'रूम का लिंक शेयर करें। जो भी जुड़ेगा, वह तब से लिखा गया सब पढ़ेगा।';

  @override
  String get groupChatNobodyToReadIt => 'इसे पढ़ने के लिए यहाँ और कोई नहीं है।';

  @override
  String get groupChatThisMessageCanT => 'यह मैसेज दिखाया नहीं जा सकता';

  @override
  String groupChatS(Object s) {
    return '$s से';
  }

  @override
  String groupChatM(Object s) {
    return '$s मि';
  }

  @override
  String groupChatH(Object s) {
    return '$s घं';
  }

  @override
  String groupChatD(Object s) {
    return '$s दिन';
  }

  @override
  String groupChatHere(int count, Object time) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$time · $countString यहाँ',
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
      other: '$countString सदस्य',
      one: '$countString सदस्य',
    );
    return '$_temp0';
  }

  @override
  String get groupChatSearchThisChat => 'इस चैट में खोजें';

  @override
  String groupChatReplyingTo(Object name) {
    return '$name को जवाब';
  }

  @override
  String get groupChatReplyingToYou => 'आपको जवाब';

  @override
  String get groupChatTimedMessages => 'मिटने वाले मैसेज';

  @override
  String get groupChatOpenTheCamera => 'कैमरा खोलें';

  @override
  String get groupChatAttachAPhoto => 'फ़ोटो जोड़ें';

  @override
  String get groupChatMessage => 'मैसेज';

  @override
  String get groupChatSupporter => 'समर्थक';

  @override
  String get groupChatEdited => 'बदला गया';

  @override
  String get groupChatTapToRetry => '! फिर भेजने को टैप करें';

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
      other: 'भेजा गया · $countString में से $haveString के पास पहुँचा',
      one: 'भेजा गया · $countString में से $haveString के पास पहुँचा',
      zero: 'भेजा गया · रास्ते में',
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
      other: 'भेजा गया · $countString को नहीं मिला',
      one: 'भेजा गया · $countString को नहीं मिला',
    );
    return '$_temp0';
  }

  @override
  String get groupChatReply => 'जवाब दें';

  @override
  String get groupChatPin => 'पिन करें';

  @override
  String get groupChatUnsave => 'सेव से हटाएँ';

  @override
  String get groupChatForward => 'फ़ॉरवर्ड करें';

  @override
  String get groupInfoGroup => 'ग्रुप';

  @override
  String get groupInfoRenameGroup => 'ग्रुप का नाम बदलें';

  @override
  String get groupInfoRename => 'नाम बदलें';

  @override
  String get groupInfoNoContactsToAdd => 'जोड़ने के लिए कोई संपर्क नहीं';

  @override
  String get groupInfoCouldNotAdd => 'जोड़ नहीं पाए';

  @override
  String groupInfoRemove(Object haloId) {
    return '$haloId को हटाएँ?';
  }

  @override
  String get groupInfoTheyWillStopReceiving =>
      'उन्हें इस ग्रुप के मैसेज मिलना बंद हो जाएगा।';

  @override
  String get groupInfoResetLink => 'लिंक रीसेट करें';

  @override
  String get groupInfoResetTheRoomLink => 'रूम का लिंक रीसेट करें?';

  @override
  String get groupInfoResetLinkLine =>
      'पुराना लिंक काम करना बंद कर देगा। रूम के लोग बने रहेंगे और उन्हें नया लिंक मिल जाएगा।';

  @override
  String get groupInfoRemoveRoomLine =>
      'वे रूम लिंक से फिर जुड़ सकते हैं। उन्हें बाहर रखने के लिए लिंक रीसेट करें। जो लोग अभी रूम में हैं, उन्हें नया लिंक मिल जाएगा।';

  @override
  String get groupInfoRemoveAndResetLink => 'हटाएँ और लिंक रीसेट करें';

  @override
  String get groupInfoCouldNotResetLink => 'लिंक रीसेट नहीं हो पाया';

  @override
  String get roomLinkNewLinkTheOld => 'नया लिंक। पुराना अब काम नहीं करता।';

  @override
  String appGroupHoldsUpTo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'एक ग्रुप में ज़्यादा से ज़्यादा $countString लोग हो सकते हैं',
      one: 'एक ग्रुप में ज़्यादा से ज़्यादा $countString व्यक्ति हो सकता है',
    );
    return '$_temp0';
  }

  @override
  String get commonRemove => 'हटाएँ';

  @override
  String get groupInfoClearThisConversation => 'यह बातचीत साफ़ करें?';

  @override
  String get groupInfoEveryMessageHereIs =>
      'यहाँ का हर मैसेज इस फ़ोन से मिट जाएगा। इससे सिर्फ़ आपकी कॉपी साफ़ होती है, बाक़ी सदस्यों की कॉपी उनके पास रहती है।';

  @override
  String get groupInfoEveryMessageHereIsDesk =>
      'यहाँ का हर मैसेज इस कंप्यूटर से मिट जाएगा। इससे सिर्फ़ आपकी कॉपी साफ़ होती है, बाक़ी सदस्यों की कॉपी उनके पास रहती है।';

  @override
  String get groupInfoClear => 'साफ़ करें';

  @override
  String get groupInfoConversationCleared => 'बातचीत साफ़ हो गई';

  @override
  String get groupInfoLeaveRoom => 'रूम छोड़ें?';

  @override
  String get groupInfoLeaveGroup => 'ग्रुप छोड़ें?';

  @override
  String get groupInfoEverythingInItIs =>
      'इसमें जो कुछ है, वह अभी इस फ़ोन से मिटा दिया जाएगा, और यहाँ इस्तेमाल हुई कुंजी हमेशा के लिए चली जाएगी।';

  @override
  String get groupInfoEverythingInItIsDesk =>
      'इसमें जो कुछ है, वह अभी इस कंप्यूटर से मिटा दिया जाएगा, और यहाँ इस्तेमाल हुई कुंजी हमेशा के लिए चली जाएगी।';

  @override
  String groupChatYouWereRemovedFrom(Object name) {
    return 'आपको $name से हटा दिया गया';
  }

  @override
  String get groupInfoLeaveGroupLine =>
      'आपको इसके मैसेज मिलना बंद हो जाएगा, और इसमें जो कुछ है वह इस फ़ोन से मिटा दिया जाएगा।';

  @override
  String get groupInfoLeaveGroupLineDesk =>
      'आपको इसके मैसेज मिलना बंद हो जाएगा, और इसमें जो कुछ है वह इस कंप्यूटर से मिटा दिया जाएगा।';

  @override
  String get groupInfoLeaveGroupAdmin =>
      'आपको इसके मैसेज मिलना बंद हो जाएगा, और इसमें जो कुछ है वह इस फ़ोन से मिटा दिया जाएगा। आप इसके एडमिन हैं, इसलिए आपके जाने के बाद कोई इसके सदस्य नहीं बदल पाएगा, न इसका नाम।';

  @override
  String get groupInfoLeaveGroupAdminDesk =>
      'आपको इसके मैसेज मिलना बंद हो जाएगा, और इसमें जो कुछ है वह इस कंप्यूटर से मिटा दिया जाएगा। आप इसके एडमिन हैं, इसलिए आपके जाने के बाद कोई इसके सदस्य नहीं बदल पाएगा, न इसका नाम।';

  @override
  String get groupInfoLeaveRoomMaker =>
      'इसमें जो कुछ है, वह अभी इस फ़ोन से मिटा दिया जाएगा, और यहाँ इस्तेमाल हुई कुंजी हमेशा के लिए चली जाएगी। यह रूम आपने बनाया था, इसलिए इसका लिंक अब किसी को अंदर नहीं आने देगा।';

  @override
  String get groupInfoLeaveRoomMakerDesk =>
      'इसमें जो कुछ है, वह अभी इस कंप्यूटर से मिटा दिया जाएगा, और यहाँ इस्तेमाल हुई कुंजी हमेशा के लिए चली जाएगी। यह रूम आपने बनाया था, इसलिए इसका लिंक अब किसी को अंदर नहीं आने देगा।';

  @override
  String get groupInfoLeave => 'छोड़ें';

  @override
  String get groupInfoGroupInfo => 'ग्रुप की जानकारी';

  @override
  String groupInfo1Member(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString सदस्य',
      one: '$countString सदस्य',
    );
    return '$_temp0';
  }

  @override
  String get groupInfoAdmin => 'एडमिन';

  @override
  String get groupInfoMembers2 => 'सदस्य';

  @override
  String get groupInfoInvite => 'आमंत्रित करें';

  @override
  String get commonAdd => 'जोड़ें';

  @override
  String get groupInfoYou => 'आप';

  @override
  String get groupInfoRemoveFromGroup => 'ग्रुप से हटाएँ';

  @override
  String get groupInfoWallpaper => 'वॉलपेपर';

  @override
  String get groupInfoSharedMedia => 'शेयर किया मीडिया';

  @override
  String get groupInfoClearConversation => 'बातचीत साफ़ करें';

  @override
  String get groupInfoLeaveRoom2 => 'रूम छोड़ें';

  @override
  String get groupInfoLeaveGroup2 => 'ग्रुप छोड़ें';

  @override
  String get groupInfoAddMembers => 'सदस्य जोड़ें';

  @override
  String groupInfoAdd(Object pickedLength) {
    return '$pickedLength जोड़ें';
  }

  @override
  String handleYouAre(Object h) {
    return 'आप @$h हैं';
  }

  @override
  String get handleHandleDeletedThePage => 'यूज़रनेम डिलीट हुआ · पेज हट गया';

  @override
  String get handlePublicHandle => 'सार्वजनिक यूज़रनेम';

  @override
  String get handleOptionalYourThreeWords =>
      'ज़रूरी नहीं। आपके तीन शब्द हर हाल में काम करते रहेंगे।';

  @override
  String get handleHintName => 'name';

  @override
  String get handleALineAboutYou => 'आपके बारे में एक लाइन · ज़रूरी नहीं';

  @override
  String get handleClaiming => 'ले रहे हैं…';

  @override
  String get handleClaimThisHandle => 'यह यूज़रनेम लें';

  @override
  String get handleAnyoneWithThisLink =>
      'जिसके पास भी यह लिंक है, वह आपसे निजी चैट शुरू कर सकता है। इसमें सिर्फ़ आपका आमंत्रण है, और कुछ नहीं।';

  @override
  String get handleLinkCopied => 'लिंक कॉपी हुआ';

  @override
  String get handleDeleteThisHandle => 'यह यूज़रनेम डिलीट करें';

  @override
  String handleDeleteTitle(Object handle) {
    return '@$handle डिलीट करें?';
  }

  @override
  String get handleDeleteLine =>
      'आपका सार्वजनिक पेज हट जाएगा और कोई भी यह नाम ले सकेगा। आपकी मौजूदा चैट जैसी हैं वैसी रहेंगी।';

  @override
  String get handleDeleteYes => 'यूज़रनेम डिलीट करें';

  @override
  String get handleDeleting => 'डिलीट हो रहा है…';

  @override
  String get handleChecking => 'जाँच हो रही है…';

  @override
  String get handleAvailable => 'उपलब्ध';

  @override
  String get handleAlreadyTaken => 'पहले से लिया हुआ';

  @override
  String get handleNameRule => '3 से 20 अक्षर: a-z, 0-9 या _';

  @override
  String get handleWhatAHandleDoes => 'यूज़रनेम क्या करता है';

  @override
  String get handleAnyoneWhoKnowsIt =>
      'जो भी इसे जानता है, वह आपको मैसेज करने का अनुरोध भेज सकता है। पेज पर सिर्फ़ आपका आमंत्रण और आपकी लिखी लाइन होती है, और कुछ नहीं, और यह कोई रिकॉर्ड नहीं रखता कि इसे किसने पढ़ा। आप जब चाहें इसे डिलीट कर सकते हैं।';

  @override
  String handleIsNotYoursOn(Object handle) {
    return 'इस फ़ोन पर @$handle आपका नहीं है';
  }

  @override
  String handleIsNotYoursOnDesk(Object handle) {
    return 'इस कंप्यूटर पर @$handle आपका नहीं है';
  }

  @override
  String handleTheRegistryHoldsIt(Object handle) {
    return 'रजिस्ट्री में यह किसी दूसरी कुंजी के नाम है, शायद वह पहचान जो रीस्टोर से पहले इस फ़ोन पर थी। जो लोग @$handle जोड़ते हैं, वे आप तक नहीं पहुँच रहे। इसे यहाँ से न छोड़ा जा सकता है, न बदला। कोई दूसरा नाम चुनें।';
  }

  @override
  String handleTheRegistryHoldsItDesk(Object handle) {
    return 'रजिस्ट्री में यह किसी दूसरी कुंजी के नाम है, शायद वह पहचान जो रीस्टोर से पहले इस कंप्यूटर पर थी। जो लोग @$handle जोड़ते हैं, वे आप तक नहीं पहुँच रहे। इसे यहाँ से न छोड़ा जा सकता है, न बदला। कोई दूसरा नाम चुनें।';
  }

  @override
  String get handleForgetItOnThis => 'इस फ़ोन पर इसे भूल जाएँ';

  @override
  String get handleForgetItOnThisDesk => 'इस कंप्यूटर पर इसे भूल जाएँ';

  @override
  String get homeAddAContact => 'संपर्क जोड़ें';

  @override
  String get commonSettings => 'सेटिंग';

  @override
  String get homeYourKryfo => 'आपका Kryfo';

  @override
  String homeDateWeekday(Object weekday) {
    return '$weekday,';
  }

  @override
  String get homeAnHour => 'एक घंटा';

  @override
  String homeHours(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString घंटे',
      one: '$countString घंटा',
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
      other: '$countString मिनट',
      one: '$countString मिनट',
    );
    return '$_temp0';
  }

  @override
  String get homeKryfoIsOffline => 'Kryfo ऑफ़लाइन है';

  @override
  String homeTorHasNotBeen(Object howLong) {
    return 'Tor $howLong से नहीं जुड़ पाया है। जब तक यह नहीं जुड़ता, न कुछ आ सकता है, न जा सकता है।';
  }

  @override
  String get homeReconnecting => 'दोबारा जुड़ रहा है';

  @override
  String get homeReconnect => 'दोबारा जोड़ें';

  @override
  String get homeWhatIsWrong => 'क्या गड़बड़ है';

  @override
  String get homeKryfoWillCheckIn => 'Kryfo हर 15 मिनट में जाँच करेगा';

  @override
  String get homeYourPhoneKeepsStopping =>
      'आपका फ़ोन बार-बार Kryfo को रोक रहा है';

  @override
  String get homeItHasClosedKryfo =>
      'आज इसने Kryfo को तीन बार बंद किया, इसलिए मैसेज देर से आए या रुके रहे। समय-समय पर जाँच पर इसका असर नहीं पड़ता: Kryfo जुड़ा रहने के बजाय हर 15 मिनट में जागता है।';

  @override
  String get homeSwitchToCheckIns => 'समय-समय पर जाँच पर जाएँ';

  @override
  String get homeNotNow => 'अभी नहीं';

  @override
  String get homeNotificationsAreOff => 'सूचनाएँ बंद हैं';

  @override
  String get homeAndroidIsBlockingThem =>
      'Android इन्हें रोक रहा है, इसलिए Kryfo बंद रहने पर आप तक कुछ नहीं पहुँचता। ऐप खोलने पर मैसेज फिर भी आ जाते हैं।';

  @override
  String get homeCouldnTOpenIt =>
      'नहीं खुल पाया। फ़ोन की सेटिंग में Kryfo ढूँढें';

  @override
  String get homeTurnThemOn => 'चालू करें';

  @override
  String get homeLeaveThemOff => 'बंद रहने दें';

  @override
  String get homeKeepWaiting => 'इंतज़ार करते रहें';

  @override
  String get homeOffline => 'ऑफ़लाइन';

  @override
  String get homeWaiting => 'इंतज़ार में';

  @override
  String get homeNothingWaitingToSend => 'भेजने के लिए कुछ बाक़ी नहीं';

  @override
  String homeWaitingSendsWhenYou(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString इंतज़ार में · आपके लौटते ही जाएँगे',
    );
    return '$_temp0';
  }

  @override
  String get homeNoKryfosYet => 'अभी कोई Kryfo नहीं।';

  @override
  String get homeScanTheirCodeSend =>
      'उनका कोड स्कैन करें, उन्हें लिंक भेजें, या उनका दिया @यूज़रनेम लिखें।';

  @override
  String get homeScanTheirCodeSendDesk =>
      'उन्हें लिंक भेजें, या उनका दिया @यूज़रनेम लिखें।';

  @override
  String get homeAddSomeone => 'किसी को जोड़ें';

  @override
  String get homeArchived => 'आर्काइव';

  @override
  String home1Chat(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString चैट',
      one: '$countString चैट',
    );
    return '$_temp0';
  }

  @override
  String get homeGroups => 'ग्रुप';

  @override
  String get homeRoom => 'रूम';

  @override
  String get homeNew => 'नया';

  @override
  String homeRoomExpired(Object expiredRoomName) {
    return '$expiredRoomName · रूम का समय ख़त्म';
  }

  @override
  String get homeMentionedYou => 'आपका ज़िक्र किया';

  @override
  String homeMembers(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString सदस्य',
      one: '$countString सदस्य',
    );
    return '$_temp0';
  }

  @override
  String get homeSupporter => 'समर्थक';

  @override
  String get homeUnmute => 'अनम्यूट करें';

  @override
  String get homeMute => 'म्यूट करें';

  @override
  String get homeArchive => 'आर्काइव करें';

  @override
  String get homeDeleteChat => 'चैट डिलीट करें';

  @override
  String get homeMessagesAndContactGone =>
      'मैसेज और संपर्क, इस फ़ोन से हट जाएँगे';

  @override
  String get homeMessagesAndContactGoneDesk =>
      'मैसेज और संपर्क, इस कंप्यूटर से हट जाएँगे';

  @override
  String get homeDeleteThisChat => 'यह चैट डिलीट करें?';

  @override
  String homeEveryMessageWithGoes(Object c) {
    return '$c के साथ का हर मैसेज हट जाएगा, और वे संपर्क नहीं रहेंगे। यह सिर्फ़ इस फ़ोन को साफ़ करता है। उनकी कॉपी उनके पास रहती है। अगर वे फिर मैसेज करें, तो वह अनुरोधों में आएगा।';
  }

  @override
  String homeEveryMessageWithGoesDesk(Object c) {
    return '$c के साथ का हर मैसेज हट जाएगा, और वे संपर्क नहीं रहेंगे। यह सिर्फ़ इस कंप्यूटर को साफ़ करता है। उनकी कॉपी उनके पास रहती है। अगर वे फिर मैसेज करें, तो वह अनुरोधों में आएगा।';
  }

  @override
  String get homeQueued => 'क़तार में';

  @override
  String get homeBlocked => 'ब्लॉक किया गया';

  @override
  String get homeRoomInvite => 'रूम का आमंत्रण';

  @override
  String get homeNow => 'अभी';

  @override
  String homeM(Object inMinutes) {
    return '$inMinutes मि';
  }

  @override
  String homeH(Object inHours) {
    return '$inHours घं';
  }

  @override
  String get homeYesterday => 'कल';

  @override
  String homeD(Object inDays) {
    return '$inDays दिन';
  }

  @override
  String get homeNoteToSelf => 'अपने लिए नोट';

  @override
  String get homeOnlyOnThisPhone => 'सिर्फ़ इसी फ़ोन पर';

  @override
  String get homeOnlyOnThisPhoneDesk => 'सिर्फ़ इसी कंप्यूटर पर';

  @override
  String get homeSaved => 'सेव किए गए';

  @override
  String get homeKeptFromEveryChat => 'हर चैट से रखे हुए';

  @override
  String get homeRequests => 'अनुरोध';

  @override
  String home1PersonWantsTo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString लोग आपसे जुड़ना चाहते हैं',
      one: '$countString व्यक्ति आपसे जुड़ना चाहता है',
    );
    return '$_temp0';
  }

  @override
  String introduceGotItButCould(Object b, Object c) {
    return '$b को मिल गया, पर $c तक नहीं पहुँच पाए';
  }

  @override
  String introduceGotItButCouldNotBe(Object c, Object b) {
    return '$c को मिल गया, पर $b तक नहीं पहुँच पाए';
  }

  @override
  String introduceIntroduced(Object b, Object c) {
    return 'अब $b और $c के पास एक-दूसरे का कार्ड है';
  }

  @override
  String get introduceCouldNotReachEither =>
      'दोनों में से किसी तक नहीं पहुँच पाए। बाद में फिर कोशिश करें';

  @override
  String introduceIntroduceTo(Object peerName) {
    return '$peerName को किससे मिलवाएँ...';
  }

  @override
  String get introduceBothOfThemGet =>
      'दोनों को एक-दूसरे का कार्ड मिलता है। कोई भी नहीं देखता कि आपने दूसरे का क्या नाम रखा है।';

  @override
  String get introduceNoOneElseTo =>
      'अभी मिलवाने के लिए कोई और नहीं है। पहले एक और संपर्क जोड़ें।';

  @override
  String get introduceANoteLikeMy =>
      'एक नोट, जैसे “मेरा चचेरा भाई” (ज़रूरी नहीं)';

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
      other: 'इस हफ़्ते $maxString में से $leftString परिचय बाक़ी',
      one: 'इस हफ़्ते $maxString में से $leftString परिचय बाक़ी',
    );
    return '$_temp0';
  }

  @override
  String introduceNoIntroductionsLeftNext(Object refillPhrase) {
    return 'कोई परिचय बाक़ी नहीं। अगला $refillPhrase मिलेगा';
  }

  @override
  String get introduceIntroduce => 'मिलवाएँ';

  @override
  String get keyVerificationSafetyNumber => 'सुरक्षा नंबर';

  @override
  String get keyVerificationNewNumber =>
      'यह खुला था तभी उनका सुरक्षा कोड बदल गया। यह नया नंबर है: इसे फिर से मिलाएँ।';

  @override
  String get keyVerificationKeyMoved =>
      'उनका सुरक्षा कोड अभी-अभी बदला है। नया नंबर मिलाएँ।';

  @override
  String keyVerificationNoKeyYet(Object peerName) {
    return 'अभी $peerName की कोई कुंजी नहीं। उनके आपको लिखने के बाद उनका नंबर यहाँ दिखेगा।';
  }

  @override
  String keyVerificationWith(Object peerName) {
    return '$peerName के साथ';
  }

  @override
  String keyVerificationCompareAll(Object peerName) {
    return 'सभी 12 समूह $peerName के साथ मिलाएँ, आमने-सामने या किसी भरोसेमंद कॉल पर। अगर हर समूह मेल खाता है, तो बीच में कोई नहीं है और आपके मैसेज सिर्फ़ आप दोनों के लिए हैं।';
  }

  @override
  String get keyVerificationVerified => 'पुष्टि हुई';

  @override
  String get keyVerificationMarkAsVerified => 'पुष्टि हुई मानें';

  @override
  String get lockFileThatPasswordDoesNot => 'यह पासवर्ड इसे नहीं खोलता।';

  @override
  String get lockFileThisFileIsDamaged => 'यह फ़ाइल ख़राब है।';

  @override
  String get lockFileThisFileWasLocked =>
      'यह फ़ाइल पासवर्ड से नहीं, एक कुंजी से लॉक की गई थी।';

  @override
  String get lockFileThisIsNotA => 'यह लॉक की हुई फ़ाइल नहीं है।';

  @override
  String get lockFileNotEnoughFreeMemory =>
      'अभी पर्याप्त ख़ाली मेमोरी नहीं है।';

  @override
  String get lockFileStopped => 'रुक गया।';

  @override
  String get lockFileItNeedsAPassword => 'इसके लिए पासवर्ड चाहिए।';

  @override
  String get lockFileKryfoCouldNotRead =>
      'Kryfo फ़ाइल को पढ़ या लिख नहीं पाया।';

  @override
  String get lockFileCheckCapitalsAndSpaces =>
      'बड़े-छोटे अक्षर और स्पेस जाँचें। इसे कोई रीसेट नहीं कर सकता।';

  @override
  String get lockFileItMayHaveBeen =>
      'शायद यह रास्ते में अधूरी रह गई। इसे फिर से भेजने को कहें। कुछ भी सेव नहीं हुआ।';

  @override
  String get lockFileItOpensWithThe =>
      'यह उस व्यक्ति की कुंजी फ़ाइल से खुलती है जिसके लिए बनाई गई थी, कंप्यूटर पर age टूल में। Kryfo पासवर्ड वाली फ़ाइलें खोलता है।';

  @override
  String get lockFileKryfoOpensFilesLocked =>
      'Kryfo age से लॉक की गई फ़ाइलें खोलता है। उनके नाम आमतौर पर .age पर ख़त्म होते हैं।';

  @override
  String get lockFileCloseAFewApps =>
      'कुछ ऐप बंद करें और दोबारा कोशिश करें। पासवर्ड जाँचने के लिए थोड़ी देर कुछ सौ मेगाबाइट चाहिए।';

  @override
  String get lockFileNothingWasSaved => 'कुछ भी सेव नहीं हुआ।';

  @override
  String get lockFileTypeOneOrLet =>
      'ख़ुद लिखें, या Kryfo को चार शब्द सुझाने दें।';

  @override
  String get lockFileTheAppThatHolds =>
      'जिस ऐप में यह है, शायद उसने इसे वापस ले लिया। फिर से चुनें।';

  @override
  String get lockFileHidePassword => 'पासवर्ड छिपाएँ';

  @override
  String get lockFileShowPassword => 'पासवर्ड दिखाएँ';

  @override
  String get lockFileChangeFile => 'फ़ाइल बदलें';

  @override
  String get lockFileChange => 'बदलें';

  @override
  String lockFileOf(Object prettySize, Object prettySize2) {
    return '$prettySize2 में से $prettySize';
  }

  @override
  String get lockFileEverythingStaysOnThis => 'सब कुछ इसी फ़ोन पर रहता है।';

  @override
  String get lockFileEverythingStaysOnThisDesk =>
      'सब कुछ इसी कंप्यूटर पर रहता है।';

  @override
  String get lockFileCouldNotMakeOne => 'नहीं बना पाए। अपना ख़ुद लिखें।';

  @override
  String get lockFileWriteItDownBefore => 'फ़ाइल लॉक करने से पहले इसे लिख लें';

  @override
  String get lockFileNoAppOnThis => 'इस फ़ोन के किसी ऐप ने फ़ाइल नहीं ली।';

  @override
  String get linkNoAppOpens => 'इस फ़ोन पर कोई ऐप यह लिंक नहीं खोलता।';

  @override
  String get linkNoAppOpensDesk => 'इस कंप्यूटर पर कोई ऐप यह लिंक नहीं खोलता।';

  @override
  String get placeStubLocation => 'लोकेशन';

  @override
  String get lockFileSaved => 'सेव हो गया';

  @override
  String get lockFileCouldNotSaveIt =>
      'वहाँ सेव नहीं हो पाया। कोई दूसरा फ़ोल्डर चुनें।';

  @override
  String get lockFileLocked => 'लॉक हो गया';

  @override
  String get lockFileLockAFile => 'फ़ाइल लॉक करें';

  @override
  String get lockFileMixingThePassword => 'पासवर्ड को मथा जा रहा है';

  @override
  String get lockFileLocking => 'लॉक हो रहा है';

  @override
  String get lockFileSaveToFiles => 'Files में सेव करें';

  @override
  String get lockFileSaveToFilesDesk => 'फ़ाइल सेव करें';

  @override
  String get lockFileLockFile => 'फ़ाइल लॉक करें';

  @override
  String get lockFileOnePassword => 'एक पासवर्ड।';

  @override
  String get lockFileNothingElseOpensIt => 'और कुछ इसे नहीं खोलता।';

  @override
  String get lockFileFile => 'फ़ाइल';

  @override
  String lockFileFromFiles(Object prettySize) {
    return '$prettySize · Files से';
  }

  @override
  String get lockFileFromFiles2 => 'Files से';

  @override
  String get lockFilePassword => 'पासवर्ड';

  @override
  String get lockFileSuggestFourWords => 'चार शब्द सुझाएँ';

  @override
  String get lockFileTypeItAgain => 'फिर से लिखें';

  @override
  String get lockFileTheTwoDoNot => 'दोनों अभी मेल नहीं खाते।';

  @override
  String get lockFileHideTheFileName => 'फ़ाइल का नाम छिपाएँ';

  @override
  String lockFileItWillBeCalled(Object name) {
    return 'इसका नाम “$name” होगा। उन्हें बता दें कि यह किस तरह की फ़ाइल है।';
  }

  @override
  String get lockFileTheNameAloneCan =>
      'सिर्फ़ नाम से ही पता चल सकता है कि अंदर क्या है।';

  @override
  String get lockFileAnyoneWithThePassword =>
      'जिसके पास पासवर्ड है, वह इसे खोल सकता है, Kryfo में या मुफ़्त age टूल वाले किसी भी कंप्यूटर पर। पासवर्ड भूल गए तो फ़ाइल हमेशा के लिए गई। इसे कोई रीसेट नहीं कर सकता।';

  @override
  String get lockFileLocked2 => 'लॉक हो गया।';

  @override
  String get lockFileOnlyThePasswordOpens => 'इसे सिर्फ़ पासवर्ड खोलता है।';

  @override
  String lockFileSafeToEmailOr(Object prettySize) {
    return '$prettySize · ईमेल करने या USB स्टिक पर रखने के लिए सुरक्षित';
  }

  @override
  String get lockFileNoKryfoOnThe => 'दूसरी तरफ़ Kryfo नहीं है? कंप्यूटर पर:';

  @override
  String get lockFileItAsksForThe =>
      'यह पासवर्ड माँगता है। age मुफ़्त में age-encryption.org पर है';

  @override
  String lockTooManyTriesS(Object lockState) {
    return 'बहुत ज़्यादा कोशिशें · $lockState सेकंड';
  }

  @override
  String get lockNotIt => 'यह नहीं';

  @override
  String get lockYourPin => 'आपका PIN';

  @override
  String get lockUseFingerprint => 'फ़िंगरप्रिंट इस्तेमाल करें';

  @override
  String get lockSetupUnlockWithFingerprint => 'फ़िंगरप्रिंट से अनलॉक करें?';

  @override
  String get lockSetupThePinStillWorks =>
      'PIN जब चाहें तब काम करता रहेगा। यह बस ज़्यादा तेज़ है।';

  @override
  String get lockSetupUseFingerprint => 'फ़िंगरप्रिंट इस्तेमाल करें';

  @override
  String get lockSetupTurningOn => 'चालू हो रहा है…';

  @override
  String get lockSetupPinOnly => 'सिर्फ़ PIN';

  @override
  String get lockSetupOnceMore => 'एक बार और';

  @override
  String get lockSetupSetAPin => 'PIN सेट करें';

  @override
  String get lockSetupThoseWereDifferentFrom =>
      'दोनों अलग थे। फिर से शुरू करें।';

  @override
  String get lockSetupTheSameFourDigits => 'वही अंक दोबारा';

  @override
  String get lockSetupFourDigitsAnythingYou =>
      'चार या ज़्यादा अंक, जो भी आपको याद रहे';

  @override
  String get modesFast => 'तेज़';

  @override
  String get modesNotChanged => 'मोड नहीं बदला। दोबारा कोशिश करें।';

  @override
  String get modesSwitching => 'बदल रहा है…';

  @override
  String get modesSpeed => 'रफ़्तार';

  @override
  String get modesPrivacy => 'और प्राइवेसी';

  @override
  String get movedWipeThisPhone => 'इस फ़ोन से Kryfo पूरी तरह मिटाएँ?';

  @override
  String get movedWipeThisPhoneDesk => 'इस कंप्यूटर से Kryfo पूरी तरह मिटाएँ?';

  @override
  String get movedEverythingKryfoHoldsHere =>
      'Kryfo का यहाँ रखा सब कुछ मिट जाएगा: मैसेज, संपर्क, कुंजियाँ। दूसरे डिवाइस पर यह सब रहेगा। इसे पलटा नहीं जा सकता।';

  @override
  String get movedWipeIt => 'मिटाएँ';

  @override
  String get movedNotMovingAfterAll => 'आख़िर में नहीं जा रहे?';

  @override
  String get movedOnlyDoThisIf =>
      'यह सिर्फ़ तभी करें जब बैकअप कहीं इम्पोर्ट न हुआ हो। अगर हुआ है, तो अब दो डिवाइस पर एक ही पहचान है, और दोनों पर मैसेज ग़ायब होने लगेंगे।';

  @override
  String get movedIMStayingHere => 'मुझे यहीं रहना है';

  @override
  String get movedStayingHere => 'यहीं रह रहे हैं';

  @override
  String movedKryfoWillCloseNow(Object myId) {
    return 'Kryfo अब बंद होगा। $myId के रूप में फिर खोलने के लिए आइकन पर टैप करें।';
  }

  @override
  String movedKryfoWillCloseNowDesk(Object myId) {
    return 'Kryfo अब बंद होगा। $myId के रूप में खोलने के लिए इसे फिर से चालू करें।';
  }

  @override
  String get movedReopenKryfo => 'Kryfo फिर खोलें';

  @override
  String get movedThisKryfoHasMoved => 'यह Kryfo कहीं और चला गया है';

  @override
  String movedIsNowOnAnother(Object myId) {
    return '$myId अब दूसरे डिवाइस पर है। यह फ़ोन अब भी दिखा सकता है कि यहाँ क्या था, पर इस पर कुछ नया नहीं आएगा, और यहाँ से भेजा कुछ भी किसी तक नहीं पहुँचेगा।';
  }

  @override
  String movedIsNowOnAnotherDesk(Object myId) {
    return '$myId अब दूसरे डिवाइस पर है। यह कंप्यूटर अब भी दिखा सकता है कि यहाँ क्या था, पर इस पर कुछ नया नहीं आएगा, और यहाँ से भेजा कुछ भी किसी तक नहीं पहुँचेगा।';
  }

  @override
  String get movedKeepItToRead => 'पढ़ने के लिए रखें';

  @override
  String get movedWipeThisPhone2 => 'इस फ़ोन से Kryfo पूरी तरह मिटाएँ';

  @override
  String get movedWipeThisPhone2Desk => 'इस कंप्यूटर से Kryfo पूरी तरह मिटाएँ';

  @override
  String get movedIMNotMoving => 'मुझे आख़िर में नहीं जाना';

  @override
  String get myKryfoAHandleIs3 =>
      'यूज़रनेम 3 से 20 अक्षरों, अंकों या _ का होता है';

  @override
  String get myKryfoInviteCopiedClearsIn =>
      'आमंत्रण कॉपी हुआ · 60 सेकंड में मिट जाएगा';

  @override
  String get myKryfoAddMeOnKryfo2 => 'मुझे Kryfo पर जोड़ें';

  @override
  String get myKryfoAddSomeone => 'किसी को जोड़ें';

  @override
  String get myKryfoKryfoDoesnTScan =>
      'Kryfo आपके संपर्क स्कैन नहीं करता, यही तो बात है।';

  @override
  String get myKryfoIfThisLinkEnds =>
      'अगर यह लिंक कहीं ऐसी जगह पहुँच जाए जहाँ आप नहीं चाहते थे, तो सेटिंग में इसे रीसेट करें। तब जिसके पास भी यह है, उसे नया लिंक चाहिए होगा।';

  @override
  String get myKryfoAlreadyShareAFriend =>
      'Kryfo पर कोई साझा दोस्त है? वे अपनी चैट से आप दोनों को मिलवा सकते हैं, और अनुरोध की ज़रूरत नहीं पड़ती।';

  @override
  String get myKryfoHandleCopied => 'यूज़रनेम कॉपी हुआ';

  @override
  String get myKryfoTheyReHereWith => 'वे मेरे पास हैं';

  @override
  String get myKryfoPointYourPhonesAt =>
      'अपने फ़ोन एक-दूसरे की ओर करें। कुछ भी किसी सर्वर से होकर नहीं जाता।';

  @override
  String get myKryfoPointYourPhonesAtDesk =>
      'सामने वाला यह कोड अपने फ़ोन से स्कैन करे। कुछ भी किसी सर्वर से होकर नहीं जाता।';

  @override
  String get myKryfoScanTheirsInstead => 'इसके बजाय उनका स्कैन करें';

  @override
  String get myKryfoTheyReadYouA => 'वे आपको एक कोड पढ़कर सुनाते हैं';

  @override
  String get myKryfoTheyReSomewhereElse => 'वे कहीं और हैं';

  @override
  String get myKryfoSendThemALink =>
      'उन्हें लिंक भेजें। यह सीधे जोड़ने वाली स्क्रीन में खुलता है।';

  @override
  String get myKryfoYourLinkAppearsOnce => 'जुड़ने के बाद आपका लिंक दिखेगा';

  @override
  String get myKryfoTheLinkCarriesYour =>
      'लिंक में आपके तीन शब्द, आपका पता और चैट शुरू करने की कुंजियाँ होती हैं। जब तक आप सेटिंग में इसे रीसेट न करें, यह काम करता है।';

  @override
  String get myKryfoSendTheLink => 'लिंक भेजें';

  @override
  String get myKryfoAsACard => 'कार्ड के रूप में';

  @override
  String get myKryfoAnImageWithThe => 'QR वाली एक तस्वीर';

  @override
  String get myKryfoAsAFile => 'फ़ाइल के रूप में';

  @override
  String get myKryfoContactFile => 'संपर्क फ़ाइल';

  @override
  String get myKryfoIKnowTheirHandle => 'मुझे उनका यूज़रनेम पता है';

  @override
  String get myKryfoTypeTheNameThey =>
      'उनका दिया @name लिखें। अगर उन्होंने कोई लिया है, तो काम करेगा।';

  @override
  String get myKryfoTheLookupAsksFor =>
      'खोज सिर्फ़ वही एक नाम भेजती है, आपके बारे में कुछ नहीं। उन्हें आपका पहला मैसेज फिर भी अनुरोध की तरह पहुँचता है।';

  @override
  String get myKryfoLooking => 'ढूँढ रहे हैं…';

  @override
  String get myKryfoFindThem => 'उन्हें ढूँढें';

  @override
  String get myKryfoYourAddressAppearsOnce => 'जुड़ने के बाद आपका पता दिखेगा';

  @override
  String get myKryfoAPublicHandle => 'एक सार्वजनिक यूज़रनेम';

  @override
  String get myKryfoPutItInA =>
      'इसे अपने बायो में लिखें। जो भी इसे जानता है, आपको ढूँढ सकता है।';

  @override
  String get myKryfoANamePeopleCan =>
      'एक नाम जिससे लोग आपको ढूँढ सकें। जब तक आप कोई न लें, बंद है।';

  @override
  String get newGroupCouldNotCreate => 'नहीं बना पाए';

  @override
  String get newGroupNewGroup => 'नया ग्रुप';

  @override
  String get newGroupCreating => 'बन रहा है…';

  @override
  String get newGroupCreate => 'बनाएँ';

  @override
  String get newGroupGroupName => 'ग्रुप का नाम';

  @override
  String get newGroupMembers => 'सदस्य';

  @override
  String get newGroupPickAtLeastOne => 'कम से कम एक चुनें';

  @override
  String newGroupSelected(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString चुने गए',
    );
    return '$_temp0';
  }

  @override
  String get newGroupAddAtLeastOne =>
      'ग्रुप बनाने से पहले कम से कम एक संपर्क जोड़ें।';

  @override
  String get newGroupNeedsContacts => 'ग्रुप आपके संपर्कों से बनते हैं';

  @override
  String get newGroupAddSomeoneFirst =>
      'पहले किसी को जोड़ें। रूम के लिए संपर्क नहीं चाहिए: जिसके पास भी उसका लिंक है, वह जुड़ सकता है।';

  @override
  String get notesDeleteThisNote => 'यह नोट डिलीट करें?';

  @override
  String get notesHoldHint => 'कॉपी या डिलीट करने के लिए नोट को दबाकर रखें।';

  @override
  String get notesMenu => 'नोट्स मेन्यू';

  @override
  String get notesDeleteAll => 'सभी नोट्स डिलीट करें';

  @override
  String get notesDeleteAllTitle => 'सभी नोट्स डिलीट करें?';

  @override
  String get notesDeleteAllLine => 'इस फ़ोन का हर नोट हमेशा के लिए हट जाएगा।';

  @override
  String get notesDeleteAllLineDesk =>
      'इस कंप्यूटर का हर नोट हमेशा के लिए हट जाएगा।';

  @override
  String get notesDeleteAllYes => 'सब डिलीट करें';

  @override
  String get notesThisWeek => 'इस हफ़्ते';

  @override
  String get notesShowMore => 'और दिखाएँ';

  @override
  String get notesShowLess => 'कम दिखाएँ';

  @override
  String get notesGoneFromThisPhone => 'यह इस फ़ोन से हमेशा के लिए हट जाता है।';

  @override
  String get notesGoneFromThisPhoneDesk =>
      'यह इस कंप्यूटर से हमेशा के लिए हट जाता है।';

  @override
  String get notesNoteToSelf => 'अपने लिए नोट';

  @override
  String get notesOnlyOnThisPhone => 'सिर्फ़ इसी फ़ोन पर';

  @override
  String get notesOnlyOnThisPhoneDesk => 'सिर्फ़ इसी कंप्यूटर पर';

  @override
  String get notesAQuietPlace => 'एक शांत जगह';

  @override
  String get notesJotAnythingDownIt =>
      'कुछ भी लिख लें। यह इसी फ़ोन पर रहता है और कभी बाहर नहीं जाता।';

  @override
  String get notesJotAnythingDownItDesk =>
      'कुछ भी लिख लें। यह इसी कंप्यूटर पर रहता है और कभी बाहर नहीं जाता।';

  @override
  String get notesJotSomethingDown => 'कुछ लिख लें…';

  @override
  String get notesExportNotes => 'नोट्स एक्सपोर्ट करें';

  @override
  String get notesExport => 'एक्सपोर्ट करें';

  @override
  String get notesExportWorking => 'एक्सपोर्ट हो रहा है…';

  @override
  String notesExportCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString नोट्स, सबसे पुराना पहले।',
      one: '$countString नोट, सबसे पुराना पहले।',
    );
    return '$_temp0';
  }

  @override
  String get notesExportZip =>
      'फ़ोटो और वॉइस नोट उनके साथ एक zip में जाते हैं।';

  @override
  String get notesExportText => 'सादा टेक्स्ट';

  @override
  String get notesExportTextLine => 'एक .txt फ़ाइल जो कहीं भी खुलती है';

  @override
  String get notesExportMarkdown => 'Markdown';

  @override
  String get notesExportMarkdownLine =>
      'शीर्षकों वाली एक .md फ़ाइल, नोट्स ऐप के लिए';

  @override
  String get notesExportLock => 'पासफ़्रेज़ से लॉक करें';

  @override
  String get notesExportLockLine =>
      'इसे टूल में “लॉक की हुई फ़ाइल खोलें” से खोलें, या कंप्यूटर पर age से';

  @override
  String get notesExportPlainTitle => 'बिना पासफ़्रेज़ के एक्सपोर्ट करें?';

  @override
  String get notesExportPlainLine =>
      'जिसे भी यह फ़ाइल मिलेगी, वह इसे पढ़ सकता है।';

  @override
  String get notesExportPlainYes => 'बिना पासफ़्रेज़ के एक्सपोर्ट करें';

  @override
  String get notesExportKeepLock => 'पासफ़्रेज़ रहने दें';

  @override
  String get notesExportNotSaved => 'नोट्स सेव नहीं हुए। फ़ाइल अभी भी यहीं है।';

  @override
  String get notesExportGone =>
      'Kryfo लॉक होते ही फ़ाइल साफ़ कर दी गई। नई फ़ाइल बनाने के लिए फिर से एक्सपोर्ट करें।';

  @override
  String get notesExportHoldsInstaller =>
      'इस एक्सपोर्ट में एक ऐप इंस्टॉलर है, इसलिए इसे शेयर नहीं किया जा सकता। इसके बजाय इसे अपने फ़ोन में सेव करें।';

  @override
  String get notesExportHoldsInstallerDesk =>
      'इस एक्सपोर्ट में एक ऐप इंस्टॉलर है, इसलिए इसे शेयर नहीं किया जा सकता। इसके बजाय इसे इस कंप्यूटर में सेव करें।';

  @override
  String get notesExportSaved => 'नोट्स सेव हुए';

  @override
  String notesExportSavedIn(String place) {
    return 'नोट्स $place में सेव हुए';
  }

  @override
  String get notesExportSavedUnchecked =>
      'नोट्स सेव हो गए, पर Kryfo कॉपी की जाँच नहीं कर पाया';

  @override
  String get notesExportFailed =>
      'नोट्स एक्सपोर्ट नहीं हो पाए। कुछ भी सेव नहीं हुआ।';

  @override
  String get notesExportTooLarge =>
      'एक्सपोर्ट के लिए बहुत बड़ा। फ़ोटो और वॉइस नोट मिलाकर 4 GB या ज़्यादा हैं।';

  @override
  String get notesExportSubject => 'Kryfo नोट्स';

  @override
  String get onboardingPrivateByDefault => 'शुरू से ही निजी';

  @override
  String get onboardingPrivateMessaging => 'निजी बातचीत,\n*बिना किसी शर्त के*।';

  @override
  String get onboardingYourNameIsThree =>
      '*आपका नाम तीन शब्द है।*\nन फ़ोन नंबर, न ईमेल, न एड्रेस बुक।';

  @override
  String get onboardingNobodyGetsInUnless =>
      '*आपकी मर्ज़ी के बिना कोई अंदर नहीं आता।*\nसार्वजनिक @नाम के बिना कोई आपको खोज नहीं सकता।\nअनजान लोग सिर्फ़ दस्तक दे सकते हैं।';

  @override
  String get onboardingTheFirstConnectionTakes =>
      '*पहली बार जुड़ने में एक मिनट लगता है।*\nKryfo पहले एक निजी रास्ता बनाता है। उसके बाद जल्दी।';

  @override
  String get onboardingBegin => 'शुरू करें';

  @override
  String get onboardingHaveABackupRestore => 'बैकअप है? रीस्टोर करें →';

  @override
  String get onboardingKryfoIsOpenSource => 'Kryfo ओपन सोर्स है';

  @override
  String get onboardingYourKryfoId => 'आपका नाम';

  @override
  String get onboardingGeneratedFromAKey =>
      'एक कुंजी से बना, जो सिर्फ़ इसी फ़ोन पर रहती है।\n*ये शब्द किसी और के पास नहीं हैं।*';

  @override
  String get onboardingGeneratedFromAKeyDesk =>
      'एक कुंजी से बना, जो सिर्फ़ इसी कंप्यूटर पर रहती है।\n*ये शब्द किसी और के पास नहीं हैं।*';

  @override
  String get onboardingTryAnother => 'दूसरा देखें';

  @override
  String get onboardingUseThisName => 'यही नाम रखें →';

  @override
  String get onboardingThreeWords => 'तीन शब्द। *सिर्फ़ आपके।*';

  @override
  String get onboardingContinue => 'आगे बढ़ें →';

  @override
  String get onboardingKryfoBuildsAPrivateRouteBefore =>
      'कुछ भी भेजने से पहले Kryfo एक निजी रास्ता बनाता है। जब आप ऑफ़लाइन हों, मैसेज इंतज़ार करते हैं और आपके लौटने पर पहुँच जाते हैं।';

  @override
  String get onboardingYourIdentityLivesOn =>
      'आपकी पहचान इसी फ़ोन पर रहती है।\nजब तैयार हों, सेटिंग में इसका बैकअप लें।';

  @override
  String get onboardingYourIdentityLivesOnDesk =>
      'आपकी पहचान इसी कंप्यूटर पर रहती है।\nजब तैयार हों, सेटिंग में इसका बैकअप लें।';

  @override
  String get onboardingSilentAndAtThe => 'बिना आवाज़, सूचनाओं में सबसे नीचे';

  @override
  String get onboardingItNeverBuzzesTurn =>
      'यह कभी वाइब्रेट नहीं करती।\nइसे बंद करें, तो मैसेज तब तक रुके रहेंगे जब तक आप Kryfo न खोलें।';

  @override
  String get onboardingGotIt => 'ठीक है →';

  @override
  String get onboardingEveryWayToAdd => 'किसी को जोड़ने के सभी तरीक़े';

  @override
  String get onboardingShowYourCodeSend =>
      'अपना कोड दिखाएँ, लिंक शेयर करें, या उनका @नाम लिखें।';

  @override
  String get onboardingScanTheirs => 'उनका स्कैन करें';

  @override
  String get onboardingPointTheCameraAt => 'कैमरा उनके कोड की ओर करें';

  @override
  String get onboardingNotNowAddPeople => 'अभी नहीं · लोगों को बाद में जोड़ें';

  @override
  String get openLockedOpened => 'खुल गया';

  @override
  String get openLockedOpenALockedFile => 'लॉक की हुई फ़ाइल खोलें';

  @override
  String get openLockedCheckingThePassword => 'पासवर्ड जाँचा जा रहा है';

  @override
  String get openLockedOpening => 'खुल रहा है';

  @override
  String get openLockedFile => 'फ़ाइल';

  @override
  String get openLockedOpenFile => 'फ़ाइल खोलें';

  @override
  String get openLockedTypeThePassword => 'पासवर्ड लिखें।';

  @override
  String get openLockedItOpensOnThis => 'यह इसी फ़ोन पर खुलती है।';

  @override
  String get openLockedItOpensOnThisDesk => 'यह इसी कंप्यूटर पर खुलती है।';

  @override
  String get openLockedLockedFile => 'लॉक की हुई फ़ाइल';

  @override
  String openLockedFromFiles(Object prettySize) {
    return '$prettySize · Files से';
  }

  @override
  String get openLockedFromFiles2 => 'Files से';

  @override
  String get openLockedPassword => 'पासवर्ड';

  @override
  String get openLockedThePasswordIsChecked =>
      'पहले पासवर्ड जाँचा जाता है। उसके बाद ही Kryfo पूछता है कि खुली फ़ाइल कहाँ रखनी है, और वह सीधे वहीं जाती है।';

  @override
  String get openLockedOpened2 => 'खुल गया।';

  @override
  String get openLockedSavedWhereYouChose => 'आपकी चुनी जगह पर सेव हुआ।';

  @override
  String get pairCodePairingCode => 'जोड़ने का कोड';

  @override
  String get pairCodeShowACode => 'कोड दिखाएँ';

  @override
  String get pairCodeEnterOne => 'कोड डालें';

  @override
  String get pairCodeLooking => 'ढूँढ रहे हैं…';

  @override
  String get pairCodeNothingThereYetTrying =>
      'अभी वहाँ कुछ नहीं · फिर कोशिश कर रहे हैं';

  @override
  String get pairCodeNothingAtThatCode =>
      'उस कोड पर कुछ नहीं है। शायद उसका समय ख़त्म हो गया, या उन्होंने अभी शेयर नहीं किया।';

  @override
  String get pairCodeUnreached =>
      'रिले तक नहीं पहुँच पाए। थोड़ी देर में फिर कोशिश करें।';

  @override
  String get fastRoomsWaitForTor =>
      'रूम, जोड़ने के कोड और पहला संपर्क हमेशा Tor से होकर जाते हैं, तेज़ पर भी। Tor जुड़ते ही ये काम करते हैं।';

  @override
  String get pairCodeFailed => 'यह नहीं हुआ। दोबारा कोशिश करें।';

  @override
  String get pairCodeAddThem => 'जोड़ें';

  @override
  String get pairCodeKeyNumber => 'कुंजी नंबर';

  @override
  String get pairCodeNotAdded => 'नहीं जोड़ा गया। उनसे नया कोड माँगें।';

  @override
  String get pairCodeEightDigits => 'आठ अंक';

  @override
  String get pairCodeTypeTheEightDigits =>
      'वे जो आठ अंक पढ़कर सुनाएँ, वे लिखें।';

  @override
  String get pairCodeOldCode =>
      'यह कोड पुराने Kryfo का है। दोनों फ़ोन पर Kryfo 0.6 या नया चाहिए।';

  @override
  String get pairCodeOldCodeDesk =>
      'यह कोड पुराने Kryfo का है। दोनों डिवाइस पर Kryfo 0.6 या नया चाहिए।';

  @override
  String get pairCodeBothNeed06 => 'दोनों फ़ोन पर Kryfo 0.6 या नया चाहिए।';

  @override
  String get pairCodeBothNeed06Desk =>
      'दोनों डिवाइस पर Kryfo 0.6 या नया चाहिए।';

  @override
  String get pairCodeWaitingForThem => 'उनका इंतज़ार है…';

  @override
  String get pairCodeStillWaiting =>
      'अभी भी इंतज़ार है। अगर उनकी स्क्रीन पर ग़लत कोड लिखे जाने की बात दिखे, तो अंक साथ मिलकर जाँचें।';

  @override
  String get pairCodeUnanswered =>
      'कोई जवाब नहीं आया। उनके साथ कोड जाँचें और फिर से लिखें।';

  @override
  String get pairCodeTooManyTries =>
      'यह कोड तीन बार आज़माया गया। उनसे नया कोड माँगें।';

  @override
  String get pairCodeRanOut =>
      'उस कोड का समय ख़त्म हो गया। उनसे नया कोड माँगें।';

  @override
  String get pairCodeMatched => 'कोड मिल गया। एक-दूसरे को जोड़ें?';

  @override
  String get pairCodeNotThem => 'ये वो नहीं हैं';

  @override
  String get pairCodePanelReadEightDigitsOut =>
      'आठ अंक ज़ोर से पढ़ें और आप एक-दूसरे को जोड़ लेंगे। और कुछ लेने-देने की ज़रूरत नहीं।';

  @override
  String get pairCodePanelOrMakeACode => 'या पढ़कर सुनाने के लिए एक कोड बनाएँ';

  @override
  String get pairCodePanelTheyOpenKryfoEight =>
      'वे Kryfo खोलें, जोड़ें पर टैप करें, जोड़ने का कोड चुनें और ये आठ अंक लिखें। अगले व्यक्ति के लिए नया कोड बनाएँ।';

  @override
  String get pairCodePanelWrongTyped =>
      'ग़लत कोड लिखा गया। इसे फिर से धीरे-धीरे पढ़ें।';

  @override
  String get pairCodePanelThreeWrong =>
      'तीन बार ग़लत कोड लिखा गया, इसलिए यह कोड रुक गया। नया बनाएँ।';

  @override
  String get pairCodePanelNotAdded =>
      'नहीं जोड़ा गया। जब वे तैयार हों, नया कोड बनाएँ।';

  @override
  String get panicSetupThoseWereDifferentFrom =>
      'दोनों अलग थे। फिर से शुरू करें।';

  @override
  String get panicSetupOnceMore => 'एक बार और';

  @override
  String get panicSetupTheSameFourDigits => 'वही अंक दोबारा';

  @override
  String get photoKnowsEverythingInside => 'अंदर का सब कुछ';

  @override
  String get photoKnowsVideo => 'वीडियो';

  @override
  String get photoKnowsPhoto => 'फ़ोटो';

  @override
  String get photoKnowsVideoCleaner => 'वीडियो क्लीनर';

  @override
  String get photoKnowsPhotoCleaner => 'फ़ोटो क्लीनर';

  @override
  String get photoKnowsRemoveAllOfIt => 'सब हटाएँ';

  @override
  String get photoKnowsKeepItAsIt => 'जैसा है वैसा रखें';

  @override
  String get photoKnowsReadingTheFile => 'फ़ाइल पढ़ी जा रही है';

  @override
  String photoKnowsOf(Object prettySize, Object prettySize2) {
    return '$prettySize2 में से $prettySize';
  }

  @override
  String get photoKnowsEverythingStaysOnThis => 'सब कुछ इसी फ़ोन पर रहता है।';

  @override
  String get photoKnowsEverythingStaysOnThisDesk =>
      'सब कुछ इसी कंप्यूटर पर रहता है।';

  @override
  String photoKnowsMapWithAPin(Object place) {
    return 'पिन वाला नक्शा। $place';
  }

  @override
  String get photoKnowsDrawnOffline => 'ऑफ़लाइन बनाया गया';

  @override
  String photoKnowsShowEverything(Object title) {
    return '$title। सब दिखाएँ';
  }

  @override
  String get pinsAppLock => 'ऐप लॉक';

  @override
  String get pinsYourPin => 'आपका PIN';

  @override
  String get commonOn => 'चालू';

  @override
  String get commonOff => 'बंद';

  @override
  String get pinsOpensKryfoFourDigits =>
      'Kryfo खोलता है। जब भी ऐप सामने आता है, माँगा जाता है।';

  @override
  String get pinsChangePin => 'PIN बदलें';

  @override
  String get pinsSetAPin => 'PIN सेट करें';

  @override
  String get pinsTurnOff => 'बंद करें';

  @override
  String get pinsTurnOffTheApp => 'ऐप लॉक बंद करें?';

  @override
  String get pinsThePinGoesAnd =>
      'PIN हट जाएगा, और उसके साथ मिटाने वाला PIN और सारी छिपी चैट भी। आपका फ़ोन जिसके हाथ में होगा, वह Kryfo को आपकी तरह खोल लेगा।';

  @override
  String get pinsThePinGoesAndDesk =>
      'PIN हट जाएगा, और उसके साथ मिटाने वाला PIN और सारी छिपी चैट भी। आपके कंप्यूटर पर जो भी बैठेगा, वह Kryfo को आपकी तरह खोल लेगा।';

  @override
  String get pinsUnlockWithFingerprint => 'फ़िंगरप्रिंट से अनलॉक करें';

  @override
  String get pinsFingerOpensDecoy =>
      'नकली PIN सेट रहने तक बंद: उंगली सिर्फ़ नकली Kryfo खोलती है।';

  @override
  String get pinsWipePin => 'मिटाने वाला PIN';

  @override
  String get pinsNeedsAPinFirst => 'पहले PIN चाहिए';

  @override
  String get pinsSet => 'सेट करें';

  @override
  String get pinsChangeWipePin => 'मिटाने वाला PIN बदलें';

  @override
  String get pinsRemove => 'हटाएँ';

  @override
  String get pinsRemoveTheWipePin => 'मिटाने वाला PIN हटाएँ?';

  @override
  String get pinsTheLockScreenKeeps =>
      'लॉक स्क्रीन पर आपका PIN बना रहेगा। मिटाने वाला PIN अब कुछ नहीं करेगा।';

  @override
  String profileCopied(Object what) {
    return '$what कॉपी हुआ';
  }

  @override
  String get profileProfile => 'प्रोफ़ाइल';

  @override
  String get profileKryfoId => 'आपका नाम';

  @override
  String get profileOnionAddress => 'Onion पता';

  @override
  String get profileSupporterBadge => 'समर्थक बैज';

  @override
  String profileYouAreAThank(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter': 'आप समर्थक हैं। धन्यवाद।',
      'patron': 'आप संरक्षक हैं। धन्यवाद।',
      'guardian': 'आप रक्षक हैं। धन्यवाद।',
      'other': 'आप समर्थक हैं। धन्यवाद।',
    });
    return '$_temp0';
  }

  @override
  String get profileShowMyBadge => 'मेरा बैज दिखाएँ';

  @override
  String get profileOnMyOwnScreens => 'मेरी अपनी स्क्रीन पर';

  @override
  String get profileLetContactsSeeIt => 'संपर्कों को दिखने दें';

  @override
  String get profileOffByDefault => 'पहले से बंद';

  @override
  String get profileShareConnect => 'शेयर करें और जुड़ें';

  @override
  String get profileMyKryfoCode => 'मेरा Kryfo कोड';

  @override
  String get profileAddContact => 'संपर्क जोड़ें';

  @override
  String get profileGiveAgain => 'फिर से दें';

  @override
  String get profileSupportKryfo => 'Kryfo को सहयोग दें';

  @override
  String get profileKryfoRunsOnWhat => 'Kryfo लोगों के सहयोग से चलता है';

  @override
  String get profileKeepKryfoIndependent => 'Kryfo को आज़ाद रखें';

  @override
  String get qrLink => 'लिंक';

  @override
  String get qrYourLinkAsTyped =>
      'आपका लिंक जैसा लिखा · कोई ट्रैकिंग रीडायरेक्ट नहीं';

  @override
  String get qrText => 'टेक्स्ट';

  @override
  String get qrStaysInTheCode => 'कोड में ही रहता है · कोई सर्वर इसे नहीं रखता';

  @override
  String get qrWiFi => 'Wi-Fi';

  @override
  String get qrMadeOnThisPhone =>
      'इसी फ़ोन पर बना · किसी वेबसाइट ने पासवर्ड नहीं देखा';

  @override
  String get qrMadeOnThisPhoneDesk =>
      'इसी कंप्यूटर पर बना · किसी वेबसाइट ने पासवर्ड नहीं देखा';

  @override
  String get qrNetworkName => 'नेटवर्क का नाम';

  @override
  String get qrPassword => 'पासवर्ड';

  @override
  String get qrContact => 'संपर्क';

  @override
  String get qrOnlyWhatYouType =>
      'सिर्फ़ जो आप लिखें · आपके संपर्कों से कुछ नहीं';

  @override
  String get qrName => 'नाम';

  @override
  String get qrPhone => 'फ़ोन';

  @override
  String get qrEmail => 'ईमेल';

  @override
  String get qrOpensTheirMailApp =>
      'उनका मेल ऐप खोलता है · यहाँ से कुछ नहीं भेजा जाता';

  @override
  String get qrTo => 'किसे';

  @override
  String get qrSubject => 'विषय';

  @override
  String get qrANumberNothingElse => 'एक नंबर · और कुछ नहीं';

  @override
  String get qrNumber => 'नंबर';

  @override
  String get qrSms => 'SMS';

  @override
  String get qrOpensTheirMessagesApp =>
      'उनका मैसेज ऐप खोलता है · यहाँ से कुछ नहीं भेजा जाता';

  @override
  String get qrMessage => 'मैसेज';

  @override
  String get qrLocation => 'लोकेशन';

  @override
  String get qrCoordinatesOnlyNoMap =>
      'सिर्फ़ निर्देशांक · किसी मैप सेवा से नहीं पूछा';

  @override
  String get qrLatitude => 'अक्षांश';

  @override
  String get qrLongitude => 'देशांतर';

  @override
  String get qrBitcoin => 'Bitcoin';

  @override
  String get qrAddressAndAmountNo =>
      'पता और रक़म · बीच में कोई भुगतान साइट नहीं';

  @override
  String get qrAddress => 'पता';

  @override
  String get qrAmountInBtc => 'BTC में रक़म';

  @override
  String get qrInk => 'स्याही';

  @override
  String get qrAmber => 'अंबर';

  @override
  String get qrViolet => 'बैंगनी';

  @override
  String get qrCouldNotDrawThe => 'तस्वीर नहीं बन पाई।';

  @override
  String get qrSavedToYourGallery => 'आपकी गैलरी में सेव हुआ';

  @override
  String get qrCouldNotSaveIt => 'सेव नहीं हो पाया। देखें कि फ़ोन में जगह है।';

  @override
  String get qrCouldNotSaveItDesk =>
      'सेव नहीं हो पाया। देखें कि कंप्यूटर में जगह है।';

  @override
  String get qrNoAppOnThis => 'इस फ़ोन के किसी ऐप ने तस्वीर नहीं ली।';

  @override
  String get qrTooMuchForOne => 'एक कोड के लिए बहुत ज़्यादा। इसे छोटा करें।';

  @override
  String get qrThisIsALot =>
      'एक कोड के लिए यह काफ़ी ज़्यादा है। पुराने कैमरे शायद इसे न पढ़ पाएँ।';

  @override
  String get qrPrivateQrCode => 'निजी QR कोड';

  @override
  String get qrColour => 'रंग';

  @override
  String get qrCopiedItLeavesThe =>
      'कॉपी हुआ। एक मिनट में क्लिपबोर्ड से हट जाएगा';

  @override
  String get qrSecurity => 'सुरक्षा';

  @override
  String get qrNone => 'कोई नहीं';

  @override
  String get qrSaveImage => 'तस्वीर सेव करें';

  @override
  String qrColour2(Object name) {
    return '$name रंग';
  }

  @override
  String get qrTypeBelowAndThe => 'नीचे लिखें और\nकोड अपने-आप बन जाएगा';

  @override
  String get qrQrCode => 'QR कोड';

  @override
  String get qrHidePassword => 'पासवर्ड छिपाएँ';

  @override
  String get qrShowPassword => 'पासवर्ड दिखाएँ';

  @override
  String get qrCopyPassword => 'पासवर्ड कॉपी करें';

  @override
  String get requestsSentAnAttachment => 'एक अटैचमेंट भेजा';

  @override
  String get requestsWantsToConnect => 'जुड़ना चाहते हैं';

  @override
  String get requestsAccepted => 'स्वीकार किया';

  @override
  String requestsBlock(Object id) {
    return '$id को ब्लॉक करें?';
  }

  @override
  String get requestsNothingMoreFromThem =>
      'उनसे आगे कुछ भी आप तक नहीं पहुँचेगा। उनका अनुरोध और उसके मैसेज हट जाएँगे।';

  @override
  String get requestsRequests => 'अनुरोध';

  @override
  String get requestsNoRequests => 'कोई अनुरोध नहीं';

  @override
  String get requestsMessagesFromPeopleYou =>
      'जिन लोगों को आपने नहीं जोड़ा, उनके मैसेज पहले यहाँ आते हैं।';

  @override
  String get commonAccept => 'स्वीकार करें';

  @override
  String get requestsDecline => 'मना करें';

  @override
  String get restoreThatFileIsNot => 'यह फ़ाइल Kryfo बैकअप नहीं है';

  @override
  String get restoreThisFileIsDamaged =>
      'यह फ़ाइल ख़राब है और पढ़ी नहीं जा सकती';

  @override
  String get restoreTypeThePassphraseThe =>
      'वह पासफ़्रेज़ लिखें जिससे फ़ाइल बनाई गई थी';

  @override
  String get restoreReplaceTheAccountOn => 'इस फ़ोन का अकाउंट बदल दें?';

  @override
  String get restoreReplaceTheAccountOnDesk => 'इस कंप्यूटर का अकाउंट बदल दें?';

  @override
  String get restoreWhatIsHereNow =>
      'अभी यहाँ जो है, उसकी पहचान, संपर्क और मैसेज, सब हट जाएगा। उसकी जगह फ़ाइल आ जाएगी। इसे पलटा नहीं जा सकता।';

  @override
  String get restoreReplaceIt => 'बदल दें';

  @override
  String restoreCouldNotBeReleased(Object mine) {
    return '@$mine छोड़ा नहीं जा सका';
  }

  @override
  String restoreTheRegistryDidNot(Object mine) {
    return 'रजिस्ट्री ने जवाब नहीं दिया। अगर आप आगे बढ़ते हैं, तो @$mine उसी पहचान से जुड़ा रहेगा जो यह फ़ोन अभी खोने वाला है। जो भी इसे जोड़ेगा, वह किसी को नहीं लिख रहा होगा, और यह नाम दोबारा नहीं लिया जा सकेगा। बेहतर है कि ऑनलाइन होकर एक बार फिर कोशिश करें।';
  }

  @override
  String restoreTheRegistryDidNotDesk(Object mine) {
    return 'रजिस्ट्री ने जवाब नहीं दिया। अगर आप आगे बढ़ते हैं, तो @$mine उसी पहचान से जुड़ा रहेगा जो यह कंप्यूटर अभी खोने वाला है। जो भी इसे जोड़ेगा, वह किसी को नहीं लिख रहा होगा, और यह नाम दोबारा नहीं लिया जा सकेगा। बेहतर है कि ऑनलाइन होकर एक बार फिर कोशिश करें।';
  }

  @override
  String get restoreRestoreAnyway => 'फिर भी रीस्टोर करें';

  @override
  String get restoreNotYet => 'अभी नहीं';

  @override
  String get restoreRestored => 'रीस्टोर हो गया';

  @override
  String restoreKryfoWillCloseNow(Object haloId) {
    return 'Kryfo अब बंद होगा। $haloId के रूप में फिर खोलने के लिए आइकन पर टैप करें।';
  }

  @override
  String restoreKryfoWillCloseNowDesk(Object haloId) {
    return 'Kryfo अब बंद होगा। $haloId के रूप में खोलने के लिए इसे फिर से चालू करें।';
  }

  @override
  String get restorePrivacyKept =>
      'आपकी प्राइवेसी सेटिंग इसके साथ वापस आती हैं। PIN कभी साथ नहीं जाते: सेटिंग में उन्हें फिर से सेट करें।';

  @override
  String get restoreCheckProtections =>
      'सेटिंग बैकअप में नहीं रखी जातीं। Kryfo फिर खुलने पर सेटिंग में आपकी सुरक्षा जाँच लें।';

  @override
  String get restoreReopenKryfo => 'Kryfo फिर खोलें';

  @override
  String get restoreTheRestoreDidNot =>
      'रीस्टोर पूरा नहीं हुआ। कुछ भी नहीं बदला';

  @override
  String get restoreKryfoClosesRestoreAgain =>
      'यहाँ का कुछ हिस्सा पहले ही बदल चुका है। Kryfo अब बंद होगा। इसे फिर खोलें और फ़ाइल को एक बार और रीस्टोर करें।';

  @override
  String get restoreThisIdentity => 'इस पहचान';

  @override
  String get restoreMoveYourKryfoHere => 'अपना Kryfo यहाँ लाएँ';

  @override
  String restoreThisBackupIsRestoring(Object name) {
    return 'यह बैकअप $name का है। इसे रीस्टोर करने से वह पहचान इस डिवाइस पर आ जाएगी।';
  }

  @override
  String restoreThisBackupMadeOn(Object name, Object date, Object time) {
    return 'यह बैकअप $name का है, $date को $time बजे बना। इसे रीस्टोर करने से वह पहचान इस डिवाइस पर आ जाएगी।';
  }

  @override
  String restoreItHoldsOfPhotos(Object mb) {
    return 'इसमें $mb की फ़ोटो, वॉइस नोट और फ़ाइलें हैं। इसमें कुछ मिनट लग सकते हैं। ऐप खुला रखें।';
  }

  @override
  String get restoreWhatFollows => 'क्या साथ आता है';

  @override
  String get restoreYourNameYourCode => 'आपका नाम, आपका कोड, और हर संपर्क।';

  @override
  String get restoreEveryConversationBackTo => 'हर बातचीत, शुरू से।';

  @override
  String get restoreYourPhotosVoiceNotes => 'आपकी फ़ोटो, वॉइस नोट और फ़ाइलें।';

  @override
  String restoreYourPhotosVoiceNotesCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'आपकी फ़ोटो, वॉइस नोट और फ़ाइलें · $countString।',
    );
    return '$_temp0';
  }

  @override
  String get restoreYourOnionAddressSo =>
      'आपका onion पता, ताकि जो लोग आप तक सीधे पहुँचते हैं, वे पहुँचते रहें।';

  @override
  String get restoreAnythingSentToYou =>
      'पुराना फ़ोन बंद रहने के दौरान आपको भेजा गया सब कुछ, भेजे जाने के चौदह दिन तक।';

  @override
  String get restoreAnythingSentToYouDesk =>
      'पुराना डिवाइस बंद रहने के दौरान आपको भेजा गया सब कुछ, भेजे जाने के चौदह दिन तक।';

  @override
  String get restoreYourSupporterBadgeIf => 'आपका समर्थक बैज, अगर है।';

  @override
  String get restoreWhatDoesnT => 'क्या नहीं आता';

  @override
  String get restoreTheOldPhoneStops =>
      'जैसे ही आप यहाँ से कुछ भेजते हैं, पुराने फ़ोन पर मैसेज आना बंद हो जाता है। इस डिवाइस से भेजा आपका पहला मैसेज आख़िरी है जिसे पुराना फ़ोन समझ सकता है, और उसके बाद वहाँ पहुँचा कुछ भी वहाँ पढ़ा नहीं जा सकता, और यहाँ भी आपका इंतज़ार नहीं कर रहा होता।';

  @override
  String get restoreTheOldPhoneStopsDesk =>
      'जैसे ही आप यहाँ से कुछ भेजते हैं, पुराने डिवाइस पर मैसेज आना बंद हो जाता है। इस कंप्यूटर से भेजा आपका पहला मैसेज आख़िरी है जिसे पुराना डिवाइस समझ सकता है, और उसके बाद वहाँ पहुँचा कुछ भी वहाँ पढ़ा नहीं जा सकता, और यहाँ भी आपका इंतज़ार नहीं कर रहा होता।';

  @override
  String get restoreIfThePhoneThis =>
      'जिस फ़ोन से यह फ़ाइल आई, अगर वह अभी भी इस्तेमाल में है, तो आगे बढ़ने से पहले उस पर Kryfo इस्तेमाल करना बंद करें। एक Kryfo पर दो फ़ोन हों, तो दोनों पर मैसेज खो जाते हैं।';

  @override
  String get restoreIfThePhoneThisDesk =>
      'जिस डिवाइस से यह फ़ाइल आई, अगर वह अभी भी इस्तेमाल में है, तो आगे बढ़ने से पहले उस पर Kryfo इस्तेमाल करना बंद करें। एक Kryfo पर दो डिवाइस हों, तो दोनों पर मैसेज खो जाते हैं।';

  @override
  String get restoreNotificationsNeedSettingUp =>
      'इस डिवाइस पर सूचनाएँ फिर से सेट करनी होंगी।';

  @override
  String get restoreDeletedComeBack =>
      'इस बैकअप के बनने के बाद आपने जो चैट मिटाईं, वे इसके साथ लौट आती हैं, और उन संपर्कों को दिख सकता है कि आपने Kryfo फिर से सेट किया।';

  @override
  String get restoreRoomsMayShow =>
      'अस्थायी रूम कुछ दिनों तक वे मैसेज दिखा सकते हैं जो हटा दिए गए थे.';

  @override
  String get restoreMoveItHere => 'इसे यहाँ लाएँ';

  @override
  String get restoreNotNow => 'अभी नहीं';

  @override
  String get restoreRestore => 'रीस्टोर करें';

  @override
  String get restoreFromABackupFile => 'बैकअप फ़ाइल से';

  @override
  String get restoreABackupBringsBack =>
      'बैकअप आपकी पहचान और आपके संपर्क वापस लाता है, और वे मैसेज जो फ़ाइल बनते समय फ़ोन पर थे। उसके बाद की बातें इसमें नहीं हैं।';

  @override
  String get restoreABackupBringsBackDesk =>
      'बैकअप आपकी पहचान और आपके संपर्क वापस लाता है, और वे मैसेज जो फ़ाइल बनते समय डिवाइस पर थे। उसके बाद की बातें इसमें नहीं हैं।';

  @override
  String get restoreTheFile => 'फ़ाइल';

  @override
  String get restorePickTheBackupFile => 'बैकअप फ़ाइल चुनें';

  @override
  String get restoreThePassphrase => 'पासफ़्रेज़';

  @override
  String get restoreTheOneTheFile => 'वही जिससे फ़ाइल बनाई गई थी';

  @override
  String get restoreWhatComesBack => 'क्या वापस आता है';

  @override
  String get restoreChecking => 'जाँच हो रही है…';

  @override
  String get restoreCheckTheFile => 'फ़ाइल जाँचें';

  @override
  String get restoreReleasingYourHandle => 'आपका यूज़रनेम छोड़ा जा रहा है…';

  @override
  String restoreMoving(Object progress) {
    return 'ला रहे हैं… $progress';
  }

  @override
  String get restoreRestoring => 'रीस्टोर हो रहा है…';

  @override
  String get restoreNotThisOne => 'यह वाला नहीं';

  @override
  String get restoreStopRestore => 'रीस्टोर रोकें';

  @override
  String get restoreDateUnknown => 'तारीख़ पता नहीं';

  @override
  String get restoreAnIdentity => 'एक पहचान';

  @override
  String get restoreMessagesSentOrReceived =>
      'उस तारीख़ के बाद भेजे या पाए गए मैसेज इस फ़ाइल में नहीं हैं।';

  @override
  String restoreGb(Object bytes) {
    return '$bytes GB';
  }

  @override
  String restoreMb(Object bytes) {
    return '$bytes MB';
  }

  @override
  String get roomCreateCouldNotCreateThe => 'रूम नहीं बन पाया';

  @override
  String get roomCreateBurnerRoom => 'अस्थायी रूम';

  @override
  String get roomCreateARoomThatEnds =>
      'एक रूम जो ख़त्म हो जाता है। हर कोई इसके लिए बनी कुंजी से जुड़ता है, और ख़त्म होने पर किसी भी फ़ोन पर कुछ नहीं बचता।';

  @override
  String get roomCreateARoomThatEndsDesk =>
      'एक रूम जो ख़त्म हो जाता है। हर कोई इसके लिए बनी कुंजी से जुड़ता है, और ख़त्म होने पर किसी भी डिवाइस पर कुछ नहीं बचता।';

  @override
  String get roomCreateRoomName => 'रूम का नाम';

  @override
  String get roomCreateEndsAfter => 'कितनी देर बाद ख़त्म हो';

  @override
  String get roomCreateMemberCap => 'सदस्यों की सीमा';

  @override
  String roomCreateNoOnePastThe(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'पहले $countString के बाद कोई नहीं',
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
      other: 'बंद। लिंक वाला कोई भी, $countString तक',
    );
    return '$_temp0';
  }

  @override
  String roomCreateThisRoomAndEverything(Object expiryWords) {
    return 'यह रूम और इसमें मौजूद सब कुछ $expiryWords में मिट जाएगा';
  }

  @override
  String get roomCreateCreating => 'बन रहा है...';

  @override
  String get roomCreateCreateRoom => 'रूम बनाएँ';

  @override
  String get roomLinkSendTheRoomTo => 'रूम किसे भेजें';

  @override
  String get roomLinkTheyWillKnowThis =>
      'उन्हें पता चलेगा कि यह रूम आपकी तरफ़ से आया। अंदर वे बाक़ी सबकी तरह बस एक कुंजी हैं।';

  @override
  String get roomLinkNoContactsYet => 'अभी कोई संपर्क नहीं';

  @override
  String roomLinkEndsIn(Object time) {
    return '$time में ख़त्म होगा';
  }

  @override
  String get roomLinkAnyoneWithThisCan =>
      'जिसके पास भी यह है, वह रूम ख़त्म होने तक जुड़ सकता है। वे इस रूम के लिए बनी कुंजी से आते हैं, और उनके आने से पहले भेजा कुछ नहीं देखते।';

  @override
  String get roomLinkRoomLinkCopied => 'रूम लिंक कॉपी हुआ';

  @override
  String get roomLinkSendToAContact => 'किसी संपर्क को भेजें';

  @override
  String get roomLinkCopyRoomLink => 'रूम लिंक कॉपी करें';

  @override
  String get savedVoiceNote => 'वॉइस नोट';

  @override
  String get savedPhoto => 'फ़ोटो';

  @override
  String get savedSaved => 'सेव किए गए';

  @override
  String get savedNothingSavedYet => 'अभी कुछ सेव नहीं हुआ';

  @override
  String get savedChatGone => 'वह चैट अब इस फ़ोन पर नहीं है';

  @override
  String get savedChatGoneDesk => 'वह चैट अब इस कंप्यूटर पर नहीं है';

  @override
  String get savedLongPressAnyMessage =>
      'किसी भी मैसेज को दबाकर रखें और उसे यहाँ रखने के लिए सेव पर टैप करें।';

  @override
  String get savedViewInChat => 'चैट में देखें';

  @override
  String get savedPhoto2 => 'फ़ोटो';

  @override
  String get scanThatSNotA => 'यह Kryfo QR नहीं है · कैमरा उसकी ओर रखें';

  @override
  String get scanScanAKryfoQr => 'Kryfo QR स्कैन करें';

  @override
  String get scanFlash => 'फ़्लैश';

  @override
  String get scanPointAtAKryfo =>
      'Kryfo QR की ओर करें · कुछ भी आपके फ़ोन से बाहर नहीं जाता';

  @override
  String get seenWhatWeCanSee => 'हम क्या देख सकते हैं';

  @override
  String get seenEveryMessengerClaimsPrivacy =>
      'यह पूरी सूची है, हर रास्ते के हिसाब से, कमज़ोरियों के साथ। वजह जानने के लिए किसी लाइन पर टैप करें।';

  @override
  String get seenHonestAboutTheLast =>
      'आख़िरी लाइनें वे हैं जिनके लिए ऐप लॉक, मिटाने वाला PIN और एन्क्रिप्टेड स्टोरेज हैं, और कोई भी टूल आपको उस व्यक्ति से नहीं बचाता जिसके हाथ में आपका खुला फ़ोन है। पूरा ख़तरा मॉडल रिपॉज़िटरी में THREAT_MODEL.md में है, LINDDUN के आधार पर लिखा। कोड खुला है, इसलिए आप यह सब ख़ुद जाँच सकते हैं।';

  @override
  String get seenHonestAboutTheLastDesk =>
      'आख़िरी लाइनें वे हैं जिनके लिए ऐप लॉक, मिटाने वाला PIN और एन्क्रिप्टेड स्टोरेज हैं, और कोई भी टूल आपको उस व्यक्ति से नहीं बचाता जो आपके खुले कंप्यूटर पर बैठा है। पूरा ख़तरा मॉडल रिपॉज़िटरी में THREAT_MODEL.md में है, LINDDUN के आधार पर लिखा। कोड खुला है, इसलिए आप यह सब ख़ुद जाँच सकते हैं।';

  @override
  String get seenHidden => 'छिपा';

  @override
  String get seenNever => 'कभी नहीं';

  @override
  String get seenOnDevice => 'डिवाइस पर';

  @override
  String get seenYours => 'आपका';

  @override
  String get seenUnaudited => 'ऑडिट नहीं हुआ';

  @override
  String get seenWhoYouTalkTo => 'आप किससे बात करते हैं';

  @override
  String get seenEachConversationGetsIts =>
      'हर बातचीत का अपना पता होता है, जो दोनों कुंजियों से बनता है। रिले को अलग-अलग, आपस में बेमेल डिब्बे दिखते हैं, दो लोगों की जोड़ी नहीं। तेज़ पर हमारे सर्वर आपके इस्तेमाल वाले डिब्बों पर आपका IP पता देखते हैं, और अगर बातचीत के दोनों लोग तेज़ पर हों, तो यह भी कि दो IP पते एक डिब्बा साझा करते हैं।';

  @override
  String get seenWhatYouSay => 'आप क्या कहते हैं';

  @override
  String get seenEndToEndEncrypted =>
      'Signal डबल रैचेट से एंड-टू-एंड एन्क्रिप्टेड, फिर एक gift wrap के अंदर दोबारा बंद। हम इसे नहीं पढ़ सकते।';

  @override
  String get seenYourIpAddress => 'आपका IP पता';

  @override
  String get seenYourContactGraph => 'आपके संपर्कों का जाल';

  @override
  String get seenKryfoDoesNotScan =>
      'Kryfo आपके संपर्क स्कैन नहीं करता। यहाँ कोई फ़ोन नंबर है ही नहीं जो लीक हो। तेज़ पर हमारे सर्वर यह देखकर इसका कुछ हिस्सा जोड़ सकते हैं कि कौन-से IP पते डिब्बे साझा करते हैं। वे इसका कोई रिकॉर्ड नहीं रखते।';

  @override
  String get seenIntroducer => 'मिलवाने वाला';

  @override
  String get seenWhenAContactIntroduces =>
      'जब कोई संपर्क आपको किसी से मिलवाता है, तो उस संपर्क को पता चल जाता है कि अब आप दोनों जुड़े हैं। और किसी को नहीं। रिले को सिर्फ़ एन्क्रिप्टेड डेटा दिखता है, और कोई सर्वर कभी यह जाल नहीं देखता।';

  @override
  String get seenTheScamShield => 'धोखाधड़ी से बचाव';

  @override
  String get seenScamShieldRequestsOnly =>
      'आपके फ़ोन पर चलता है, ऐप में आए नियमों से। न नेटवर्क, न कोई सूची डाउनलोड। यह सिर्फ़ अजनबियों के मैसेज अनुरोध पढ़ता है, कभी वह नहीं जो कोई संपर्क या ग्रुप आपको भेजता है।';

  @override
  String get seenScamShieldRequestsOnlyDesk =>
      'आपके कंप्यूटर पर चलता है, ऐप में आए नियमों से। न नेटवर्क, न कोई सूची डाउनलोड। यह सिर्फ़ अजनबियों के मैसेज अनुरोध पढ़ता है, कभी वह नहीं जो कोई संपर्क या ग्रुप आपको भेजता है।';

  @override
  String get seenBurnerRooms => 'अस्थायी रूम';

  @override
  String get seenRoomKeys => 'रूम की कुंजियाँ';

  @override
  String get seenYouJoinARoom =>
      'आप किसी रूम में उसी के लिए बनी कुंजी से जुड़ते हैं, इसलिए अंदर के लोगों को ऐसा कुछ पता नहीं चलता जो कहीं और काम आए। देर से जुड़ने वालों को पुरानी बातें नहीं मिलतीं। समय ख़त्म होने पर कुंजियाँ, मैसेज और मीडिया नष्ट हो जाते हैं।';

  @override
  String get seenLinkPreviews => 'लिंक प्रीव्यू';

  @override
  String get seenOverTor => 'Tor से';

  @override
  String get seenAPreviewIsFetched =>
      'प्रीव्यू भेजने वाला Tor से लाता है, और वह एन्क्रिप्टेड मैसेज के अंदर जाता है। पाने वाला फ़ोन कोई अनुरोध नहीं करता। वेबसाइट को बस इतना पता चलता है कि Tor इस्तेमाल करने वाले किसी व्यक्ति ने एक पेज माँगा, और कुछ नहीं। कोई तस्वीर कभी लोड नहीं होती, और किसी अजनबी का लिंक सादा टेक्स्ट ही रहता है।';

  @override
  String get seenAPreviewIsFetchedDesk =>
      'प्रीव्यू भेजने वाला Tor से लाता है, और वह एन्क्रिप्टेड मैसेज के अंदर जाता है। पाने वाला डिवाइस कोई अनुरोध नहीं करता। वेबसाइट को बस इतना पता चलता है कि Tor इस्तेमाल करने वाले किसी व्यक्ति ने एक पेज माँगा, और कुछ नहीं। कोई तस्वीर कभी लोड नहीं होती, और किसी अजनबी का लिंक सादा टेक्स्ट ही रहता है।';

  @override
  String get seenASeizedUnlockedPhone => 'छीना गया, खुला फ़ोन';

  @override
  String get seenASeizedUnlockedPhoneDesk => 'छीना गया, खुला कंप्यूटर';

  @override
  String get seenIfSomeoneHoldsYour =>
      'अगर किसी के हाथ में आपका खुला फ़ोन है, तो वह आपके मैसेज पढ़ लेगा। ऐप लॉक, मिटाने वाला PIN और एन्क्रिप्टेड स्टोरेज उससे पहले मदद करते हैं, उसके बाद नहीं।';

  @override
  String get seenIfSomeoneHoldsYourDesk =>
      'अगर कोई आपके खुले कंप्यूटर पर बैठ जाए, तो वह आपके मैसेज पढ़ लेगा। ऐप लॉक, मिटाने वाला PIN और एन्क्रिप्टेड स्टोरेज उससे पहले मदद करते हैं, उसके बाद नहीं।';

  @override
  String get seenTheCryptoItself => 'ख़ुद क्रिप्टोग्राफ़ी';

  @override
  String get seenTheRatchetAndStorage =>
      'रैचेट और स्टोरेज की परतें मानक हैं। उन्हें जोड़ने वाली परत हमारी है और किसी स्वतंत्र व्यक्ति ने उसकी समीक्षा नहीं की है। यह अल्फ़ा सॉफ़्टवेयर है।';

  @override
  String get seenFast => 'तेज़';

  @override
  String get settingsWipeKryfo => 'Kryfo पूरी तरह मिटाएँ?';

  @override
  String get settingsIdentityMessagesContactsAnd =>
      'इस फ़ोन पर पहचान, मैसेज, संपर्क और सेटिंग। बैकअप न हो, तो हमेशा के लिए चले जाएँगे।';

  @override
  String get settingsIdentityMessagesContactsAndDesk =>
      'इस कंप्यूटर पर पहचान, मैसेज, संपर्क और सेटिंग। बैकअप न हो, तो हमेशा के लिए चले जाएँगे।';

  @override
  String get commonContinue => 'आगे बढ़ें';

  @override
  String settingsTypeWipeToConfirm(Object word) {
    return 'पुष्टि के लिए \'$word\' लिखें';
  }

  @override
  String get settingsTheLastStepNothing =>
      'आख़िरी क़दम। इसके बाद कुछ नहीं बचता।';

  @override
  String get settingsWipeWord => 'मिटाएँ';

  @override
  String get settingsWipeKryfo2 => 'Kryfo पूरी तरह मिटाएँ';

  @override
  String get settingsYourProtections => 'आपकी सुरक्षा';

  @override
  String get settingsTorRouting => 'Tor रूटिंग';

  @override
  String get settingsOffFastMode => 'बंद · तेज़ मोड';

  @override
  String get settingsAppLock => 'ऐप लॉक';

  @override
  String get settingsBlockedByAndroid => 'Android ने रोका है';

  @override
  String get settingsSpeedPrivacy => 'रफ़्तार और प्राइवेसी';

  @override
  String get settingsFast => 'तेज़';

  @override
  String get settingsOnion3Hops => 'Onion · 3 पड़ाव';

  @override
  String settingsPreviewHidden(Object deliveryModeName) {
    return '$deliveryModeName · प्रीव्यू छिपा';
  }

  @override
  String settingsPreviewShown(Object deliveryModeName) {
    return '$deliveryModeName · प्रीव्यू दिखता है';
  }

  @override
  String get settingsRunInBackground => 'बैकग्राउंड में चलाएँ';

  @override
  String get settingsSoMessagesArrive => 'ताकि मैसेज आते रहें';

  @override
  String get settingsTransport => 'ट्रांसपोर्ट';

  @override
  String get settingsWhatTheNetworkIs => 'नेटवर्क क्या कर रहा है';

  @override
  String get settingsBlocked => 'ब्लॉक किए गए';

  @override
  String get settingsAcceptIntroductions => 'परिचय स्वीकार करें';

  @override
  String get settingsFriendsCanIntroduceYou =>
      'दोस्त आपको अपने दोस्तों से मिलवा सकते हैं';

  @override
  String get settingsScamShield => 'धोखाधड़ी से बचाव';

  @override
  String get settingsScamShieldHint =>
      'सिर्फ़ आपके फ़ोन पर जाँचा जाता है, कुछ भी बाहर नहीं जाता';

  @override
  String get settingsScamShieldHintDesk =>
      'सिर्फ़ आपके कंप्यूटर पर जाँचा जाता है, कुछ भी बाहर नहीं जाता';

  @override
  String get typingNow => 'टाइप कर रहे हैं';

  @override
  String get settingsTypingIndicator => 'टाइपिंग संकेत';

  @override
  String get settingsTypingIndicatorHint =>
      'आप दोनों देखते हैं कि दूसरा कब टाइप कर रहा है। यह Tor से सीधे उन तक जाता है, कभी किसी रिले से नहीं।';

  @override
  String get settingsTypingOnionOnly => 'Onion रूट पर उपलब्ध';

  @override
  String get settingsTypingBridgesOff =>
      'ब्रिज इस्तेमाल होने तक बंद: आपके कनेक्शन पर नज़र रखने वाला कोई टाइपिंग संकेतों को मिला सकता है। ब्रिज बंद होते ही यह अपने आप वापस आ जाता है।';

  @override
  String get settingsLightTheme => 'हल्की थीम';

  @override
  String get settingsSameProtectionBrighter => 'वही सुरक्षा, ज़्यादा रोशनी';

  @override
  String get settingsAppearance => 'रूप-रंग';

  @override
  String get settingsAccentColour => 'मुख्य रंग';

  @override
  String get settingsColoursAndWallpaper => 'रंग और वॉलपेपर';

  @override
  String get settingsAppLock2 => 'ऐप लॉक';

  @override
  String get settingsYourPinAndA => 'आपका PIN और अतिरिक्त सुरक्षा';

  @override
  String get settingsPinWipePin => 'PIN · मिटाने वाला PIN';

  @override
  String get settingsBackUpIdentity => 'पहचान का बैकअप लें';

  @override
  String get settingsEncryptedFile => 'एन्क्रिप्टेड फ़ाइल';

  @override
  String get settingsRestoreFromBackup => 'बैकअप से रीस्टोर करें';

  @override
  String get settingsReplaceCurrent => 'मौजूदा की जगह';

  @override
  String get settingsWhyKryfo => 'Kryfo क्यों';

  @override
  String get settingsHowItProtectsYou => 'यह आपकी कैसे रक्षा करता है';

  @override
  String get settingsResetMyInviteLink => 'मेरा आमंत्रण लिंक रीसेट करें';

  @override
  String get settingsOldLinksAndCodes =>
      'पुराने लिंक और कोड सबके लिए काम करना बंद कर देंगे';

  @override
  String get settingsResetInviteLink => 'आमंत्रण लिंक रीसेट करें?';

  @override
  String get settingsAnyoneWithAnOld =>
      'जिसके पास भी पुराना कोड या लिंक है, वह किसी भी रास्ते से आप तक नहीं पहुँच पाएगा। जिनके पास यह है पर कभी इस्तेमाल नहीं किया, उन्हें आपसे नया लेना होगा। संपर्क, चैट और पुरानी बातें बनी रहती हैं।';

  @override
  String get settingsReset => 'रीसेट करें';

  @override
  String get settingsInviteResetShareThe =>
      'आमंत्रण रीसेट हुआ · नया कोड शेयर करें';

  @override
  String get settingsWhatWeCanSee => 'हम क्या देख सकते हैं';

  @override
  String get settingsTheHonestList => 'ईमानदार सूची';

  @override
  String get settingsVersion => 'वर्शन';

  @override
  String get settingsReportAnIssue => 'समस्या बताएँ';

  @override
  String get settingsReportInKryfo => 'Kryfo में लिखें';

  @override
  String get settingsReportInKryfoSub =>
      'Marios के साथ चैट। आप गुमनाम रहकर लिख सकते हैं।';

  @override
  String get settingsReportByEmail => 'ईमेल भेजें';

  @override
  String get settingsReportByEmailSub => 'gnosiworks@proton.me, आपके मेल ऐप से';

  @override
  String get settingsBugOrSecurityFlaw => 'बग या सुरक्षा में ख़ामी';

  @override
  String get settingsOpenSource => 'ओपन सोर्स';

  @override
  String get settingsLinkCopied => 'लिंक कॉपी हुआ';

  @override
  String get settingsTheOfflineMapIn =>
      'टूल का ऑफ़लाइन नक्शा Natural Earth (पब्लिक डोमेन) से बना है। शहरों के नाम GeoNames, geonames.org से हैं, CC BY 4.0 के तहत।';

  @override
  String get settingsNotIndependentlyAuditedPre =>
      'स्वतंत्र रूप से ऑडिट नहीं हुआ। अल्फ़ा: जाँचने-परखने के लिए ठीक, बड़े जोखिम वाले इस्तेमाल के लिए अभी नहीं।';

  @override
  String get settingsFollowTitle => 'GnosiWorks (डेवलपर) को फ़ॉलो करें';

  @override
  String get settingsFollowBrowserNote =>
      'आपके ब्राउज़र में खुलता है, Kryfo के बाहर।';

  @override
  String get settingsFollowOpen => 'खोलें';

  @override
  String settingsFollowOn(Object name) {
    return '$name पर फ़ॉलो करें, Kryfo के बाहर';
  }

  @override
  String get settingsDangerZone => 'ख़तरे का क्षेत्र';

  @override
  String get settingsWipeKryfoFromThis => 'इस फ़ोन से Kryfo पूरी तरह मिटाएँ';

  @override
  String get settingsWipeKryfoFromThisDesk =>
      'इस कंप्यूटर से Kryfo पूरी तरह मिटाएँ';

  @override
  String get toolsMoreTools => 'और टूल';

  @override
  String get toolsMakeAPrivateQr => 'निजी QR कोड बनाएँ';

  @override
  String get toolsLinksWiFiContacts =>
      'लिंक, Wi-Fi, संपर्क और भी बहुत कुछ। ऑफ़लाइन बना';

  @override
  String get toolsLockAFile => 'फ़ाइल लॉक करें';

  @override
  String get toolsWithAPasswordOpens =>
      'पासवर्ड के साथ। age से कहीं भी खुलती है';

  @override
  String get toolsOpenALockedFile => 'लॉक की हुई फ़ाइल खोलें';

  @override
  String get toolsAnyAgeFileSomeone => 'किसी की भेजी कोई भी .age फ़ाइल';

  @override
  String get toolsWorksOfflineNoContacts =>
      'ऑफ़लाइन काम करता है · संपर्कों की ज़रूरत नहीं';

  @override
  String get toolsUsefulFrom => 'पहले ही मिनट से';

  @override
  String get toolsTheFirstMinute => 'काम का।';

  @override
  String get toolsEverythingHereHappensOn =>
      'यहाँ सब कुछ इसी फ़ोन पर होता है। कुछ भी अपलोड नहीं होता, और किसी और का Kryfo पर होना ज़रूरी नहीं।';

  @override
  String get toolsEverythingHereHappensOnDesk =>
      'यहाँ सब कुछ इसी कंप्यूटर पर होता है। कुछ भी अपलोड नहीं होता, और किसी और का Kryfo पर होना ज़रूरी नहीं।';

  @override
  String get toolsPhotoCleaner => 'फ़ोटो क्लीनर';

  @override
  String get toolsRemovesHiddenInfo =>
      'छिपी जानकारी (मेटाडेटा) हटाता है, जैसे जगह, समय और फ़ोन का मॉडल';

  @override
  String get toolsPickAPhotoAnd =>
      'कोई फ़ोटो या वीडियो चुनें और देखें कि वह क्या बता देता है, फिर एक टैप में सब हटा दें। आप अपनी गैलरी से भी Kryfo में शेयर कर सकते हैं।';

  @override
  String get toolsPickAPhotoAndDesk =>
      'कोई फ़ोटो या वीडियो चुनें और देखें कि वह क्या बता देता है, फिर एक क्लिक में सब हटा दें। आप इसे यहाँ छोड़ या चिपका भी सकते हैं।';

  @override
  String get toolsPickAPhoto => 'फ़ोटो चुनें';

  @override
  String get toolsVideo => 'वीडियो';

  @override
  String get transportTransport => 'ट्रांसपोर्ट';

  @override
  String get transportNothingHereLeavesThe =>
      'यहाँ का कुछ भी फ़ोन से बाहर नहीं जाता। यह वही स्थिति है जिससे इंजन तय करता है कि क्या करना है।';

  @override
  String get transportNothingHereLeavesTheDesk =>
      'यहाँ का कुछ भी कंप्यूटर से बाहर नहीं जाता। यह वही स्थिति है जिससे इंजन तय करता है कि क्या करना है।';

  @override
  String get transportStayingAlive => 'चालू बना हुआ';

  @override
  String get transportCanSend => 'भेज सकता है';

  @override
  String get commonYes => 'हाँ';

  @override
  String get transportNotYet => 'अभी नहीं';

  @override
  String get transportOnline => 'ऑनलाइन';

  @override
  String get transportOffline => 'ऑफ़लाइन';

  @override
  String get transportQueuedToSend => 'भेजने की क़तार में';

  @override
  String get transportOnionPublished => 'Onion प्रकाशित';

  @override
  String transportYes(Object uploads) {
    return 'हाँ ($uploads)';
  }

  @override
  String transportTryingS(Object pubFor) {
    return '$pubFor सेकंड से कोशिश';
  }

  @override
  String transportBenchedS(Object r) {
    return '$r सेकंड के लिए रोका';
  }

  @override
  String transportFails(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString विफल',
      one: '$countString विफल',
    );
    return '$_temp0';
  }

  @override
  String get transportOk => 'ठीक';

  @override
  String get transportRelaySubscriptions => 'रिले सब्सक्रिप्शन';

  @override
  String get transportLastSent => 'पिछली बार भेजा';

  @override
  String get transportNever => 'कभी नहीं';

  @override
  String transportSAgo(Object sx) {
    return '$sx सेकंड पहले';
  }

  @override
  String get transportLastReceived => 'पिछली बार मिला';

  @override
  String transportSAgo2(Object rx) {
    return '$rx सेकंड पहले';
  }

  @override
  String get transportWithNoContactsThe =>
      'कोई संपर्क न हो, तो ऐप किसी रिले पते को सब्सक्राइब नहीं करता, इसलिए कोई मैसेज आप तक नहीं पहुँच सकता। ठीक करने के लिए किसी को स्कैन करें।';

  @override
  String get transportWithNoContactsTheDesk =>
      'कोई संपर्क न हो, तो ऐप किसी रिले पते को सब्सक्राइब नहीं करता, इसलिए कोई मैसेज आप तक नहीं पहुँच सकता। ठीक करने के लिए किसी को जोड़ें।';

  @override
  String get transportSendAnythingWaitingNow => 'जो भी रुका है, अभी भेजें';

  @override
  String get transportSending => 'भेजा जा रहा है…';

  @override
  String get transportNothingLeftWaiting => 'कुछ भी रुका नहीं';

  @override
  String transportStillWaiting(Object count) {
    return 'अभी भी रुके हुए: $count';
  }

  @override
  String get transportOff => 'बंद';

  @override
  String get transportStarting => 'शुरू हो रहा है';

  @override
  String get transportBootstrapped => 'तैयार';

  @override
  String get transportPublishingAddress => 'पता प्रकाशित हो रहा है';

  @override
  String get transportReachable => 'पहुँच में';

  @override
  String get transportOurRelayOnion => 'हमारा रिले (onion)';

  @override
  String get transportNever2 => 'कभी नहीं';

  @override
  String get transportJustNow => 'अभी-अभी';

  @override
  String transportMAgo(Object inMinutes) {
    return '$inMinutes मि पहले';
  }

  @override
  String transportHAgo(Object inHours) {
    return '$inHours घं पहले';
  }

  @override
  String transportDAgo(Object inDays) {
    return '$inDays दिन पहले';
  }

  @override
  String transportM(Object inMinutes) {
    return '$inMinutes मि';
  }

  @override
  String transportHM(Object inHours, Object d) {
    return '$inHours घं $d मि';
  }

  @override
  String transportD(Object inDays) {
    return '$inDays दिन';
  }

  @override
  String transportMb(Object b) {
    return '$b MB';
  }

  @override
  String get transportYesCheckedJustNow => 'हाँ · अभी-अभी जाँचा';

  @override
  String transportNoLast(Object ago) {
    return 'नहीं · पिछली बार $ago';
  }

  @override
  String get transportLastMessageIn => 'पिछला आया मैसेज';

  @override
  String get transportBatteryExemption => 'बैटरी से छूट';

  @override
  String get transportUnknown => 'पता नहीं';

  @override
  String get transportExempt => 'छूट मिली है';

  @override
  String get transportNotExemptTapTo => 'छूट नहीं · ठीक करने के लिए टैप करें';

  @override
  String get transportProcessUp => 'प्रोसेस कब से चालू';

  @override
  String get transportLastStop => 'पिछली बार रुकना';

  @override
  String get transportStopKilled => 'सिस्टम ने बंद किया';

  @override
  String get transportStopLowMemory => 'मेमोरी कम';

  @override
  String get transportStopCrashed => 'क्रैश हुआ';

  @override
  String get transportStopNotResponding => 'जवाब नहीं दे रहा था';

  @override
  String get transportStopByYou => 'आपने रोका';

  @override
  String get transportStopByPhone => 'फ़ोन ने रोका';

  @override
  String get transportStopBySecurityApp => 'सुरक्षा ऐप ने रोका';

  @override
  String get transportStopUpdated => 'अपडेट हुआ';

  @override
  String get transportStopBySystem => 'सिस्टम ने रोका';

  @override
  String get transportStopTooMuch => 'ज़रूरत से ज़्यादा इस्तेमाल';

  @override
  String get transportStopPermission => 'अनुमति बदली';

  @override
  String get transportStopClosedItself => 'ख़ुद बंद हुआ';

  @override
  String get transportStopOther => 'रुक गया';

  @override
  String transportEngine(Object mb, Object mb2) {
    return '$mb · इंजन $mb2';
  }

  @override
  String get transportLastRelayArrival => 'रिले से पिछली आमद';

  @override
  String get transportLastCheckIn => 'पिछली जाँच';

  @override
  String get transportNoneYet => 'अभी कोई नहीं';

  @override
  String get transportLastTorReconnect => 'Tor से पिछली बार दोबारा जुड़ना';

  @override
  String get transportCatchUpByRelay => 'रिले से छूटे मैसेज लेना';

  @override
  String get transportControlPort => 'कंट्रोल पोर्ट';

  @override
  String get transportReconnects => 'दोबारा जुड़ना';

  @override
  String get transportWhyNetwork => 'नेटवर्क बदला';

  @override
  String get transportWhyHand => 'हाथ से';

  @override
  String get transportWhyRelays => 'किसी रिले ने जवाब नहीं दिया';

  @override
  String get transportWhyStall => 'शुरुआत अटक गई';

  @override
  String get transportWhyTorOff => 'Tor बंद था';

  @override
  String get transportWhyDialer => '3 मिनट तक कोई रिले नहीं';

  @override
  String get transportWhyOnion => 'फिर से onion पर';

  @override
  String get transportWhyBridges => 'ब्रिज बदला';

  @override
  String get transportWhyAuto => 'अपने-आप';

  @override
  String get transportWhyOffline => 'कोई नेटवर्क नहीं';

  @override
  String get transportWhyCircuits => 'नए सर्किट';

  @override
  String get transportWhyOther => 'दूसरा कारण';

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
      other: '$dialsString कोशिशें',
      one: '$dialsString कोशिश',
    );
    String _temp1 = intl.Intl.pluralLogic(
      timeouts,
      locale: localeName,
      other: '$timeoutsString टाइमआउट',
      one: '$timeoutsString टाइमआउट',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get transportJobRuns => 'जॉब कितनी बार चला';

  @override
  String transportLast(Object jobRuns, Object ago) {
    return '$jobRuns · पिछली बार $ago';
  }

  @override
  String get transportQuietStretches => 'चुप्पी के दौर';

  @override
  String get transportNone => 'कोई नहीं';

  @override
  String get transportClearThisRecord => 'यह रिकॉर्ड साफ़ करें';

  @override
  String get transportNothingYetThisProcess => 'इस प्रोसेस में अभी कुछ नहीं';

  @override
  String transportM2(Object mins) {
    return '$mins मि';
  }

  @override
  String transportHM2(Object mins, Object mins2) {
    return '$mins घं $mins2 मि';
  }

  @override
  String transportTo(Object t, Object t2) {
    return '$t से $t2';
  }

  @override
  String vouchersVouchedBy(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString ने सिफ़ारिश की',
      one: 'इन्होंने सिफ़ारिश की',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperAtmosphere => 'माहौल';

  @override
  String get wallpaperJustForYouThey =>
      'सिर्फ़ आपके लिए। वे अपना वाला देखते हैं।';

  @override
  String get wallpaperYourPhoto => 'आपकी फ़ोटो';

  @override
  String get wallpaperDefault => 'डिफ़ॉल्ट';

  @override
  String get wallpaperDim => 'वॉलपेपर मद्धम करें';

  @override
  String get wallpaperNotSet => 'वॉलपेपर नहीं लगा। दोबारा कोशिश करें।';

  @override
  String get wallpaperFromYourPhotos => 'आपकी फ़ोटो से';

  @override
  String get wallpaperKeepIt => 'यही रखें';

  @override
  String get whyKryfoWhyKryfo => 'Kryfo क्यों';

  @override
  String get whyKryfoKryfoKreeFoGreek =>
      'Kryfo · क्री-फ़ो · ग्रीक में “छिपा हुआ”।\nबात करने की एक शांत जगह, ऐसी बनी कि कोई देख न रहा हो।';

  @override
  String get whyKryfoRoutedThroughTor => 'Tor से होकर';

  @override
  String get whyKryfoByDefaultEveryMessage =>
      'पहले से ही हर मैसेज Tor से होकर जाता है, जो रिले की एक कड़ी है। कोई भी, न हम और न आपका नेटवर्क, यह नहीं देख सकता कि आप किससे बात करते हैं या कहाँ हैं।';

  @override
  String get whyKryfoEndToEndEncrypted => 'एंड-टू-एंड एन्क्रिप्टेड';

  @override
  String get whyKryfoMessagesAreSealedWith =>
      'मैसेज ऐसी कुंजियों से बंद होते हैं जो सिर्फ़ आपके और आपसे बात करने वाले के पास हैं। हम उन्हें नहीं पढ़ सकते।';

  @override
  String get whyKryfoNoServersHoldingYour => 'कोई सर्वर आपकी ज़िंदगी नहीं रखता';

  @override
  String get whyKryfoNoAccountNoPhone =>
      'न अकाउंट, न फ़ोन नंबर, न कोई केंद्रीय सर्वर जो आपकी चैट रखे। वे इसी फ़ोन पर रहती हैं, एन्क्रिप्ट होकर।';

  @override
  String get whyKryfoNoAccountNoPhoneDesk =>
      'न अकाउंट, न फ़ोन नंबर, न कोई केंद्रीय सर्वर जो आपकी चैट रखे। वे इसी कंप्यूटर पर रहती हैं, एन्क्रिप्ट होकर।';

  @override
  String get whyKryfoNothingLeaks => 'कुछ भी लीक नहीं होता';

  @override
  String get whyKryfoNoReceiptsTyping =>
      'न पढ़ने की रसीदें, न संपर्क सूची अपलोड। टाइपिंग सिर्फ़ उसी व्यक्ति को दिखती है जिसे आप लिख रहे हैं, सीधे Tor से, कभी किसी सर्वर से नहीं। ज़्यादातर ऐप मेटाडेटा लीक करते हैं। Kryfo ऐसा न करने के लिए बना है।';

  @override
  String get whyKryfoVerifyItIsReally => 'पक्का करें कि सच में वही हैं';

  @override
  String get whyKryfoCompareASafetyNumber =>
      'आमने-सामने या किसी भरोसेमंद ज़रिए से सुरक्षा नंबर मिलाएँ, ताकि आपको पता रहे कि कोई आपके संपर्क का रूप धरकर बात नहीं कर रहा।';

  @override
  String get whyKryfoTheHonestPart => 'ईमानदार हिस्सा';

  @override
  String get whyKryfoKryfoIsPreAlpha =>
      'Kryfo अल्फ़ा में है और इसका ऑडिट नहीं हुआ है। क्रिप्टोग्राफ़ी असली है, पर अभी किसी बाहरी विशेषज्ञ ने इसे नहीं जाँचा, इसलिए जहाँ आपकी सुरक्षा इस पर टिकी हो, वहाँ अभी इस पर भरोसा न करें।';

  @override
  String get cleanerLocation => 'लोकेशन';

  @override
  String get cleanerAlreadyBlankedByAndroid => 'Android पहले ही हटा चुका है';

  @override
  String get cleanerPhoneModel => 'फ़ोन का मॉडल';

  @override
  String get cleanerTimeTaken => 'खींचने का समय';

  @override
  String get cleanerSerialNumber => 'सीरियल नंबर';

  @override
  String get cleanerOwnerName => 'मालिक का नाम';

  @override
  String get cleanerHiddenThumbnail => 'छिपी छोटी तस्वीर';

  @override
  String get cleanerContentCredentials => 'कंटेंट क्रेडेंशियल';

  @override
  String get cleanerHdrLayer => 'HDR परत';

  @override
  String get cleanerDataAfterThePicture => 'तस्वीर के बाद का डेटा';

  @override
  String cleaner1OtherField(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString और फ़ील्ड',
      one: '$countString और फ़ील्ड',
    );
    return '$_temp0';
  }

  @override
  String get lockWordsFourRandomWordsBeat =>
      'चार बेतरतीब शब्द एक चालाक शब्द से बेहतर हैं।';

  @override
  String lockWordsTooShortAtLeast(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'बहुत छोटा। कम से कम $countString अक्षर।',
      one: 'बहुत छोटा। कम से कम $countString अक्षर।',
    );
    return '$_temp0';
  }

  @override
  String get lockWordsWeakWhoeverGetsThe =>
      'कमज़ोर। जिसे फ़ाइल मिलेगी, वह जितनी तेज़ी से चाहे अंदाज़ा लगा सकता है।';

  @override
  String get lockWordsFairLongerIsStronger =>
      'ठीक-ठाक। जितना लंबा, उतना मज़बूत।';

  @override
  String get lockWordsStrongFourRandomWords =>
      'मज़बूत। चार बेतरतीब शब्द एक चालाक शब्द से बेहतर हैं।';

  @override
  String photoStoryKm(Object m) {
    return '$m किमी';
  }

  @override
  String photoStory1Metre(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString मीटर',
      one: '$countString मीटर',
    );
    return '$_temp0';
  }

  @override
  String get photoStoryFarFromAnyTown => 'किसी भी शहर से दूर';

  @override
  String photoStoryNear(Object where) {
    return '$where के पास';
  }

  @override
  String photoStoryAboutKmFrom(Object near, Object where) {
    return '$where से लगभग $near किमी';
  }

  @override
  String photoStoryS(Object s) {
    return '$s सेकंड';
  }

  @override
  String photoStory1S(Object s) {
    return '1/$s सेकंड';
  }

  @override
  String get photoStoryNotAKindKryfo => 'ऐसी फ़ाइल नहीं जिसे Kryfo पढ़ सके।';

  @override
  String get photoStorySoItWillNot => 'इसलिए यह अंदाज़ा नहीं लगाएगा।';

  @override
  String get photoStoryThisFileIsDamaged => 'यह फ़ाइल ख़राब है या अधूरी है।';

  @override
  String get photoStoryKryfoCouldNotRead => 'Kryfo इसे आख़िर तक नहीं पढ़ पाया।';

  @override
  String get photoStoryWhereItWasRecorded => 'कहाँ रिकॉर्ड हुआ';

  @override
  String get photoStoryWhereItWasTaken => 'कहाँ खींची गई';

  @override
  String photoStoryLocation(Object coordsLine) {
    return 'लोकेशन: $coordsLine';
  }

  @override
  String photoStoryHeightAboveTheSea(Object fix) {
    return 'समुद्र तल से ऊँचाई: $fix मी';
  }

  @override
  String get photoStoryLocationHiddenByAndroid => 'Android ने लोकेशन छिपाई';

  @override
  String get photoStoryAndroidBlanksItWhen =>
      'इस तरह फ़ोटो चुनने पर Android इसे हटा देता है। गैलरी से Kryfo में शेयर करने पर अक्सर यह बनी रहती है। आपकी गैलरी वाली फ़ोटो में यह अभी भी हो सकती है।';

  @override
  String get photoStoryLocationBlankedByAndroid =>
      'लोकेशन: Kryfo के देखने से पहले Android ने हटा दी';

  @override
  String photoStoryF(Object r) {
    return 'f/$r';
  }

  @override
  String get photoStoryWhatTookIt => 'किससे खींची गई';

  @override
  String photoStoryPhoneOrCamera(Object phone) {
    return 'फ़ोन या कैमरा: $phone';
  }

  @override
  String get photoStoryWhenItWasRecorded => 'कब रिकॉर्ड हुआ';

  @override
  String get photoStoryToTheSecondWith => 'सेकंड तक, टाइम ज़ोन के साथ';

  @override
  String get photoStoryToTheSecond => 'सेकंड तक';

  @override
  String photoStoryTime(Object dateFormat) {
    return 'समय: $dateFormat';
  }

  @override
  String get photoStoryLens => 'लेंस';

  @override
  String photoStoryLens2(Object lens) {
    return 'लेंस: $lens';
  }

  @override
  String get photoStorySoftware => 'सॉफ़्टवेयर';

  @override
  String photoStorySoftware2(Object software) {
    return 'सॉफ़्टवेयर: $software';
  }

  @override
  String get photoStorySerialNumber => 'सीरियल नंबर';

  @override
  String photoStorySerialNumber2(Object serial) {
    return 'सीरियल नंबर: $serial';
  }

  @override
  String get photoStoryOwnerName => 'मालिक का नाम';

  @override
  String photoStoryOwner(Object r) {
    return 'मालिक: $r';
  }

  @override
  String get photoStoryHiddenThumbnail => 'छिपी छोटी तस्वीर';

  @override
  String get photoStoryASmallCopyOf =>
      'फ़ाइल के अंदर तस्वीर की एक छोटी कॉपी। इससे वह दिख सकता है जो काट-छाँट में हटाया गया था';

  @override
  String get photoStoryMakerNotes => 'कंपनी के नोट';

  @override
  String get photoStoryMakerNotesABlock =>
      'कंपनी के नोट: एक हिस्सा जिसे सिर्फ़ बनाने वाली कंपनी पढ़ सकती है';

  @override
  String get photoStoryEditingHistory => 'एडिटिंग का इतिहास';

  @override
  String get photoStoryXmpEditingHistoryAnd => 'XMP: एडिटिंग का इतिहास और टैग';

  @override
  String get photoStoryCaptions => 'कैप्शन';

  @override
  String get photoStoryIptcCaptionsAndCredits => 'IPTC: कैप्शन और क्रेडिट';

  @override
  String get photoStoryComment => 'टिप्पणी';

  @override
  String get photoStoryAWrittenComment => 'एक लिखी हुई टिप्पणी';

  @override
  String get photoStoryContentCredentials => 'कंटेंट क्रेडेंशियल';

  @override
  String get photoStorySecondPicture => 'दूसरी तस्वीर';

  @override
  String get photoStoryASecondPictureInside => 'फ़ाइल के अंदर एक दूसरी तस्वीर';

  @override
  String get photoStoryMotionVideo => 'मोशन वीडियो';

  @override
  String get photoStoryAShortVideoInside => 'फ़ाइल के अंदर एक छोटा वीडियो';

  @override
  String get photoStorySaveTime => 'सेव का समय';

  @override
  String get photoStoryTheTimeItWas => 'पिछली बार सेव होने का समय';

  @override
  String get photoStoryTimeStamps => 'टाइम स्टैम्प';

  @override
  String get photoStoryCreationTimeStamps => 'बनने के टाइम स्टैम्प';

  @override
  String get photoStoryDataAfterThePicture => 'तस्वीर के बाद का डेटा';

  @override
  String photoStoryDataAfterTheEnd(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'तस्वीर ख़त्म होने के बाद का डेटा: $countString बाइट',
      one: 'तस्वीर ख़त्म होने के बाद का डेटा: $countString बाइट',
    );
    return '$_temp0';
  }

  @override
  String photoStoryTextField(Object k) {
    return 'टेक्स्ट फ़ील्ड: $k';
  }

  @override
  String photoStoryVideoTag(Object k) {
    return 'वीडियो टैग: $k';
  }

  @override
  String photoStoryAlso(Object k) {
    return 'और: $k';
  }

  @override
  String photoStoryCameraSettingsFlashFocus(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString कैमरा सेटिंग (फ़्लैश, फ़ोकस, एक्सपोज़र)',
      one: '$countString कैमरा सेटिंग (फ़्लैश, फ़ोकस, एक्सपोज़र)',
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
      other: '$countString और फ़ील्ड',
      one: '$countString और फ़ील्ड',
    );
    return '$_temp0';
  }

  @override
  String get photoStoryCameraSettings => 'कैमरा सेटिंग';

  @override
  String photoStoryAccurateToAbout(Object metres) {
    return 'लगभग $metres तक सटीक।';
  }

  @override
  String get photoStoryEnoughToFindThe => 'दरवाज़ा ढूँढने के लिए काफ़ी।';

  @override
  String get photoStoryEnoughToFindTheStreet => 'गली ढूँढने के लिए काफ़ी।';

  @override
  String get photoStoryEnoughToFindTheArea => 'इलाक़ा ढूँढने के लिए काफ़ी।';

  @override
  String get photoStoryItKnowsWhereYou => 'इसे पता है कि आप कहाँ थे।';

  @override
  String get photoStoryDownToTheBuilding => 'इमारत तक।';

  @override
  String get photoStoryAndroidHidTheLocation => 'Android ने लोकेशन छिपा दी।';

  @override
  String get photoStoryTheOriginalMayStill =>
      'मूल फ़ाइल में यह अभी भी हो सकती है।';

  @override
  String get photoStoryNoLocationInThis => 'इसमें कोई लोकेशन नहीं।';

  @override
  String get photoStoryItStillSaysPlenty => 'फिर भी यह काफ़ी कुछ बताती है।';

  @override
  String get photoStoryThisOneKnowsNothing => 'इसे कुछ नहीं पता।';

  @override
  String get photoStoryNothingToRemove => 'हटाने को कुछ नहीं।';

  @override
  String get qrPayloadOpensALink => 'लिंक खोलता है';

  @override
  String qrPayloadOpens(Object host) {
    return '$host खोलता है';
  }

  @override
  String get qrPayloadShowsANote => 'एक नोट दिखाता है';

  @override
  String get qrPayloadScanToJoin => 'जुड़ने के लिए स्कैन करें';

  @override
  String qrPayloadScanToJoin2(Object oneLine) {
    return 'जुड़ने के लिए स्कैन करें · $oneLine';
  }

  @override
  String get qrPayloadANetworkNameIs =>
      'नेटवर्क का नाम ज़्यादा से ज़्यादा 32 अक्षरों का होता है।';

  @override
  String get qrPayloadAWiFiPassword =>
      'Wi-Fi पासवर्ड में कम से कम 8 अक्षर होते हैं।';

  @override
  String get qrPayloadSavesAContact => 'संपर्क सेव करता है';

  @override
  String get qrPayloadWritesAnEmail => 'ईमेल लिखता है';

  @override
  String get qrPayloadThatDoesNotLook => 'यह ईमेल पते जैसा नहीं लगता।';

  @override
  String get qrPayloadCallsANumber => 'नंबर पर कॉल करता है';

  @override
  String get qrPayloadWritesAText => 'SMS लिखता है';

  @override
  String get qrPayloadOpensAMap => 'नक्शा खोलता है';

  @override
  String get qrPayloadLatitudeRunsFrom90 =>
      'अक्षांश -90 से 90 तक होता है, देशांतर -180 से 180 तक।';

  @override
  String get qrPayloadPayThisAddress => 'इस पते पर भुगतान करें';

  @override
  String get qrPayloadABitcoinAddressIs =>
      'bitcoin पते में सिर्फ़ अक्षर और अंक होते हैं।';

  @override
  String get qrPayloadTheAmountIsIn =>
      'रक़म BTC में है, दशमलव के बाद ज़्यादा से ज़्यादा 8 अंक।';

  @override
  String vouchTextAnd(Object names, Object names2) {
    return '$names और $names2';
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
      other: 'आपके जानने वाले $restString और लोग',
      one: 'आपके जानने वाला $restString और व्यक्ति',
    );
    return '$names, $names2 और $_temp0';
  }

  @override
  String vouchTextVouchedBy(Object vouchNames) {
    return '$vouchNames ने सिफ़ारिश की';
  }

  @override
  String vouchTextIntroducedBy(Object vouchNames) {
    return '$vouchNames ने मिलवाया';
  }

  @override
  String vouchTextThisSharesSAddress(Object a, Object b) {
    return 'इससे $a का पता $b के साथ शेयर होता है';
  }

  @override
  String get bootFailedKryfoCouldNotStart => 'Kryfo शुरू नहीं हो पाया';

  @override
  String get bootFailedThisIsAFault =>
      'यह इस डिवाइस की गड़बड़ी है, नेटवर्क की नहीं। इसमें Tor का कोई हाथ नहीं।';

  @override
  String get bootFailedKeysDidNotAnswer =>
      'आपके फ़ोन के कुंजी स्टोरेज ने जवाब देना बंद कर दिया। Kryfo बंद करके फिर खोलने से आमतौर पर यह ठीक हो जाता है।';

  @override
  String get bootFailedKeysDidNotAnswerDesk =>
      'इस कंप्यूटर के कुंजी स्टोरेज ने जवाब देना बंद कर दिया। Kryfo बंद करके फिर खोलने से आमतौर पर यह ठीक हो जाता है।';

  @override
  String get bootFailedCloseAndReopen => 'Kryfo बंद करके फिर खोलें';

  @override
  String get bootFailedStillStuck => 'अगर दोबारा कोशिश करने से मदद न मिले';

  @override
  String get bootFailedRestoreBackup => 'बैकअप रीस्टोर करें';

  @override
  String get bootFailedStartFresh => 'नए सिरे से शुरू करें';

  @override
  String get bootFailedStartFreshTitle => 'नए सिरे से शुरू करें?';

  @override
  String get bootFailedStartFreshLine =>
      'इससे Kryfo का इस फ़ोन पर रखा सब कुछ डिलीट हो जाएगा: चैट, संपर्क, मीडिया, छिपी चैट और आपके तीन शब्द। कहीं और सेव की गई बैकअप फ़ाइल पर कोई असर नहीं पड़ता।';

  @override
  String get bootFailedStartFreshLineDesk =>
      'इससे Kryfo का इस कंप्यूटर पर रखा सब कुछ डिलीट हो जाएगा: चैट, संपर्क, मीडिया, छिपी चैट और आपके तीन शब्द। कहीं और सेव की गई बैकअप फ़ाइल पर कोई असर नहीं पड़ता।';

  @override
  String get bootFailedStartFreshNext => 'आगे बढ़ें';

  @override
  String get bootFailedStartFreshSure => 'इस फ़ोन पर सब कुछ डिलीट करें?';

  @override
  String get bootFailedStartFreshSureDesk =>
      'इस कंप्यूटर पर सब कुछ डिलीट करें?';

  @override
  String get bootFailedStartFreshSureLine =>
      'इसे पलटा नहीं जा सकता। Kryfo बंद होकर एक नए इंस्टॉल की तरह फिर खुलेगा।';

  @override
  String get bootFailedStartFreshYes => 'डिलीट करें और नए सिरे से शुरू करें';

  @override
  String get kryfoLinkTextThatLinkIsNot =>
      'यह लिंक ऐसा नहीं जिसे Kryfo पढ़ सके';

  @override
  String kryfoLinkTextAdd(Object who) {
    return '$who को जोड़ें?';
  }

  @override
  String kryfoLinkTextThisIsAnInvite(Object who) {
    return 'यह $who से बात करने का आमंत्रण है। उन्हें तभी जोड़ें जब आपको पता हो कि लिंक कहाँ से आया।';
  }

  @override
  String get kryfoLinkTextAddThem => 'जोड़ें';

  @override
  String get kryfoLinkTextNotNow => 'अभी नहीं';

  @override
  String kryfoLinkTextYouAlreadyHave(Object who) {
    return '$who पहले से आपके पास हैं';
  }

  @override
  String kryfoLinkTextSomeoneElse(Object who) {
    return 'आपकी चैट में आप किसी को $who कहते हैं। यह लिंक किसी और का है। इन्हें तभी जोड़ें जब आपको पता हो कि यह कहाँ से आया।';
  }

  @override
  String kryfoLinkTextJoin(Object roomName) {
    return '$roomName में शामिल हों';
  }

  @override
  String get kryfoLinkTextKryfoLink => 'Kryfo लिंक';

  @override
  String kryfoLinkTextAdd2(Object who) {
    return '$who को जोड़ें';
  }

  @override
  String get kryfoLinkTextBurnerRoom => 'अस्थायी रूम';

  @override
  String get kryfoLinkTextThisRoomHasClosed => 'यह रूम बंद हो चुका है';

  @override
  String kryfoLinkTextClosesIn(Object time) {
    return '$time में बंद होगा';
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
      other: '$time में बंद होगा · ज़्यादा से ज़्यादा $capString',
    );
    return '$_temp0';
  }

  @override
  String get kryfoLinkTextJoin2 => 'शामिल हों';

  @override
  String get kryfoLinkTextYouJoinUnderA =>
      'आप इस रूम के लिए बनी कुंजी से जुड़ते हैं। इसमें कोई भी आपके तीन शब्द नहीं देखता।';

  @override
  String get linkStubFetchedOverTorBy => 'Tor से लाया गया · आपके डिवाइस ने';

  @override
  String get linkStubFetchedOverTorByTheirDevice =>
      'Tor से लाया गया · उनके डिवाइस ने';

  @override
  String mediaBubblesB(Object bytes) {
    return '$bytes b';
  }

  @override
  String mediaBubblesKb(Object bytes) {
    return '$bytes kb';
  }

  @override
  String mediaBubblesMb(Object bytes) {
    return '$bytes mb';
  }

  @override
  String get mediaBubblesFile => 'फ़ाइल';

  @override
  String get mediaBubblesAudioUnavailable => 'ऑडियो उपलब्ध नहीं';

  @override
  String get mediaBubblesHidden => 'छिपा';

  @override
  String get mediaBubblesPlaying => 'चल रहा है';

  @override
  String get mediaBubblesSendPhoto => 'फ़ोटो भेजें';

  @override
  String get mediaBubblesAddACaption => 'कैप्शन जोड़ें…';

  @override
  String get motionStandby => 'रुका हुआ';

  @override
  String get motionConnecting => 'जुड़ रहा है';

  @override
  String get motionBuilding => 'बन रहा है';

  @override
  String get motionPublishing => 'प्रकाशित हो रहा है';

  @override
  String get motionReady => 'तैयार';

  @override
  String get motionPreparingToConnect => 'जुड़ने की तैयारी';

  @override
  String get motionFindingAPrivatePath => 'एक निजी रास्ता ढूँढ रहे हैं';

  @override
  String get motionCarvingThePath => 'रास्ता बना रहे हैं';

  @override
  String get motionAnnouncingYourArrival => 'आपके आने की ख़बर दे रहे हैं';

  @override
  String get motionYouReAnonymous => 'आप गुमनाम हैं';

  @override
  String get motionReadyToChat => 'चैट के लिए तैयार';

  @override
  String get motionTorIsStartingIn =>
      'Tor बैकग्राउंड में शुरू हो रहा है। कनेक्शन बनते-बनते यह चित्र जगमगा उठता है।';

  @override
  String get motionMakingAFreshRoute =>
      'गुमनाम रिले से होकर एक नया रास्ता बना रहे हैं।';

  @override
  String get motionBouncingThroughRelaysSo =>
      'रिले से होकर गुज़र रहे हैं, ताकि कोई इसे आप तक न खोज सके।';

  @override
  String get motionTellingTheNetworkYou =>
      'नेटवर्क को बता रहे हैं कि आप ऑनलाइन हैं, यह बताए बिना कि कहाँ।';

  @override
  String get motionYourIpIsHidden =>
      'आपका IP छिपा है। सिर्फ़ आपके Kryfo वाले लोग आप तक पहुँच सकते हैं।';

  @override
  String get motionAddressFinishing =>
      'मैसेज अभी से Tor के ज़रिए जा रहे हैं। आपका निजी पता बैकग्राउंड में पूरा हो रहा है।';

  @override
  String get motionBuilding2 => 'बन रहा है';

  @override
  String get motionOpen => 'खुला';

  @override
  String get motionLive => 'चालू';

  @override
  String motionCircuit(Object circuit) {
    return 'सर्किट · *$circuit*';
  }

  @override
  String get motionDelivered => 'पहुँच गया';

  @override
  String get motionSent => 'भेजा गया';

  @override
  String get motion1Hop => '1 पड़ाव';

  @override
  String get motion3Hops => '3 पड़ाव';

  @override
  String get movedStripThisKryfoHasMoved =>
      'यह Kryfo दूसरे डिवाइस पर चला गया है। यहाँ से भेजा कुछ भी किसी तक नहीं पहुँचता।';

  @override
  String get navBarChats => 'चैट';

  @override
  String get navBarTools => 'टूल';

  @override
  String get navBarSupport => 'सहयोग';

  @override
  String get navBarMe => 'मैं';

  @override
  String get pairCodePanelPuttingYourInviteIn =>
      'आपका आमंत्रण तैयार किया जा रहा है';

  @override
  String get pairCodePanelYourInviteIsNot => 'आपका आमंत्रण अभी तैयार नहीं है';

  @override
  String get pairCodePanelWorking => 'काम चल रहा है';

  @override
  String get pairCodePanelBurned =>
      'उस कोड का समय ख़त्म हो गया। जब वे तैयार हों, नया बनाएँ।';

  @override
  String get pairCodePanelCodeCopied => 'कोड कॉपी हुआ';

  @override
  String pairCodePanelBurnsIn(Object mm, Object ss) {
    return '$mm:$ss में ख़त्म होगा';
  }

  @override
  String get pairCodePanelTheyTapAddChoose =>
      'वे जोड़ें पर टैप करें, कोड चुनें, और ये लिखें।';

  @override
  String pinsPinnedMessages(Object count) {
    return 'पिन किए मैसेज · $count';
  }

  @override
  String get pinsPinnedMessages2 => 'पिन किए मैसेज';

  @override
  String get pinsPhoto => 'फ़ोटो';

  @override
  String get pinsVoiceMessage => 'वॉइस मैसेज';

  @override
  String get pinsMessage => 'मैसेज';

  @override
  String pinsToday(Object hm) {
    return 'आज · $hm';
  }

  @override
  String get pinsPinned => 'पिन किया';

  @override
  String pinsOf(Object pinsLength, Object kMaxPins) {
    return '$kMaxPins में से $pinsLength';
  }

  @override
  String get pinsNothingPinnedHereYet =>
      'यहाँ अभी कुछ पिन नहीं है। किसी मैसेज को दबाकर रखें और पिन करें चुनें, वह यहाँ चैट के सभी लोगों के लिए रहेगा।';

  @override
  String get pinsJump => 'वहाँ जाएँ';

  @override
  String get pinsUnpin => 'अनपिन करें';

  @override
  String previewStripFetchedOverTor(Object domainOf) {
    return '$domainOf · Tor से लाया गया';
  }

  @override
  String get previewStripDropThePreview => 'प्रीव्यू हटाएँ';

  @override
  String get previewStripAddPreview => 'प्रीव्यू जोड़ें';

  @override
  String get previewStripFetchingOverTor => 'Tor से ला रहे हैं…';

  @override
  String toolPartsB(Object bytes) {
    return '$bytes B';
  }

  @override
  String toolPartsKb(Object bytes) {
    return '$bytes KB';
  }

  @override
  String toolPartsMb(Object mb) {
    return '$mb MB';
  }

  @override
  String get torBootSplashNoShortcutsNoTraces => 'न शॉर्टकट, न निशान';

  @override
  String get torBootSplashTheNetworkThatKeeps =>
      'आपको निजी रखने वाला नेटवर्क तैयार हो रहा है';

  @override
  String get torBootSplashMadeOnThisPhone =>
      'इसी फ़ोन पर बना। कुछ भी कहीं नहीं भेजा जाता।';

  @override
  String get torBootSplashMadeOnThisPhoneDesk =>
      'इसी कंप्यूटर पर बना। कुछ भी कहीं नहीं भेजा जाता।';

  @override
  String get torBootSplashFirstLaunchTakesA =>
      'पहली बार खुलने में थोड़ा समय लगता है · सिर्फ़ शुरुआत में';

  @override
  String get torBootSplashTakingLonger =>
      'इसमें सामान्य से ज़्यादा समय लग रहा है';

  @override
  String get torBootSplashHopEntry => 'प्रवेश';

  @override
  String get torBootSplashHopMiddle => 'बीच';

  @override
  String get torBootSplashHopExit => 'निकास';

  @override
  String get videoBubbleNothingHereOpensThat =>
      'यहाँ कुछ भी इसे नहीं खोलता · इसके बजाय शेयर कर रहे हैं';

  @override
  String videoBubbleMb(Object b) {
    return '$b MB';
  }

  @override
  String videoBubbleKb(Object b) {
    return '$b KB';
  }

  @override
  String get videoBubbleVideo => 'वीडियो';

  @override
  String get notificationsChannelName => 'मैसेज';

  @override
  String get cameraClose => 'बंद करें';

  @override
  String get cameraFlash => 'फ़्लैश';

  @override
  String get cameraPhoto => 'फ़ोटो';

  @override
  String get cameraVideo => 'वीडियो';

  @override
  String get cameraRetake => 'फिर से लें';

  @override
  String get seenIntroductions => 'परिचय';

  @override
  String get donateAddress => 'पता';

  @override
  String get donateCopy => 'कॉपी करें';

  @override
  String get donateDone => 'हो गया';

  @override
  String get donateTierSupporter => 'समर्थक';

  @override
  String get donateTierPatron => 'संरक्षक';

  @override
  String get donateTierGuardian => 'रक्षक';

  @override
  String get chatBlock => 'ब्लॉक करें';

  @override
  String get chatDecline => 'मना करें';

  @override
  String get chatAccept => 'स्वीकार करें';

  @override
  String get bridgesConnecting => 'जुड़ रहा है';

  @override
  String get restoreMade => 'बना';

  @override
  String get restoreContacts => 'संपर्क';

  @override
  String get restoreMessages => 'मैसेज';

  @override
  String get restoreAttachments => 'अटैचमेंट';

  @override
  String get restoreHiddenChats => 'छिपी चैट';

  @override
  String get restoreHiddenFollow =>
      'आपकी छिपी चैट, एक नए छिपी चैट PIN के साथ जो आप आख़िर में चुनेंगे।';

  @override
  String get restoreChooseHiddenPin =>
      'इस बैकअप में छिपी चैट हैं। उनके लिए एक छिपी चैट PIN चुनें।';

  @override
  String get restoreHiddenLockFirst =>
      'छिपी चैट के लिए ऐप लॉक चाहिए, इसलिए पहले Kryfo का अपना PIN बनेगा।';

  @override
  String get profileIdentity => 'पहचान';

  @override
  String get avatarPickerShape => 'आकार';

  @override
  String get avatarPickerColour => 'रंग';

  @override
  String get avatarPickerTurn => 'घुमाव';

  @override
  String avatarPickerOption(String what, int n, int count) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$what, $countString में से $nString';
  }

  @override
  String get avatarPickerYourInitial => 'आपके नाम का अक्षर';

  @override
  String get transportStatus => 'स्थिति';

  @override
  String get transportBootstrap => 'शुरुआत';

  @override
  String get transportNetwork => 'नेटवर्क';

  @override
  String get transportConnectivity => 'कनेक्शन';

  @override
  String get transportRelays => 'रिले';

  @override
  String get transportTraffic => 'ट्रैफ़िक';

  @override
  String get transportContacts => 'संपर्क';

  @override
  String get transportKnown => 'जाने-पहचाने';

  @override
  String get transportListening => 'सुन रहा है';

  @override
  String get transportMemory => 'मेमोरी';

  @override
  String get settingsConnected => 'जुड़ा हुआ';

  @override
  String get settingsOn => 'चालू';

  @override
  String get settingsOff => 'बंद';

  @override
  String get settingsNotifications => 'सूचनाएँ';

  @override
  String get settingsPrivacy => 'प्राइवेसी';

  @override
  String get settingsSecurity => 'सुरक्षा';

  @override
  String get settingsBackup => 'बैकअप';

  @override
  String get settingsProtectBackup => 'बैकअप';

  @override
  String get settingsBackupNotYet => 'अभी नहीं';

  @override
  String get settingsBackupToday => 'आज';

  @override
  String get settingsBackupYesterday => 'कल';

  @override
  String settingsBackupDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count दिन पहले',
      one: '$count दिन पहले',
    );
    return '$_temp0';
  }

  @override
  String get settingsVoice => 'आवाज़';

  @override
  String get settingsAbout => 'जानकारी';

  @override
  String get wallpaperGradients => 'ग्रेडिएंट';

  @override
  String get wallpaperPatterns => 'पैटर्न';

  @override
  String get wallpaperMoods => 'मिज़ाज';

  @override
  String get confirmSheetKeep => 'रखें';

  @override
  String get confirmSheetSave => 'सेव करें';

  @override
  String get confirmSheetCancel => 'रद्द करें';

  @override
  String get bridgesFoundAVolunteer => 'एक स्वयंसेवक मिल गया, जुड़ रहे हैं';

  @override
  String get bridgesScanABridgeCode => 'ब्रिज कोड स्कैन करें';

  @override
  String get settingsBridgesForNetworksThat =>
      'ब्रिज, उन नेटवर्क के लिए जो Tor रोकते हैं';

  @override
  String get bridgesCouldNotReachTheTor => 'Tor Project तक नहीं पहुँच पाए';

  @override
  String get torBootSplashConnect => 'जोड़ें';

  @override
  String get bridgesOffline => 'ऑफ़लाइन';

  @override
  String get bridgesNothingGotThrough => 'कुछ भी नहीं पहुँचा';

  @override
  String get bridgesPasteABridge => 'ब्रिज पेस्ट करें';

  @override
  String get bridgesKryfoCanAskThe =>
      'इससे बचने के लिए Kryfo, Tor Project से ब्रिज माँग सकता है।';

  @override
  String get bridgesNotNeededRightNow => 'अभी ज़रूरत नहीं';

  @override
  String get bridgesBuiltInBridges => 'पहले से मौजूद ब्रिज';

  @override
  String get bridgesKryfoCanGetAround =>
      'अब Kryfo, Tor पर लगी रोक से बच सकता है';

  @override
  String get bridgesThatSNotABridge => 'यह ब्रिज लाइन नहीं है';

  @override
  String get transportBridgeError => 'पिछली गड़बड़ी';

  @override
  String get bridgesDirect => 'सीधे';

  @override
  String get bridgesAskingTheTorProject =>
      'Tor Project से पूछ रहे हैं कि यहाँ क्या काम करता है…';

  @override
  String get bridgesNoneOfTheseAre =>
      'इनमें से कोई भी ऐसी ब्रिज लाइन नहीं जिसे Kryfo समझता हो।';

  @override
  String get bridgesAutomatic => 'अपने-आप';

  @override
  String get bridgesStraightToTor => 'सीधे Tor से, ब्रिज की ज़रूरत नहीं';

  @override
  String get bridgesKryfoConnectsAsSoon =>
      'आपके ऑनलाइन होते ही Kryfo जुड़ जाएगा।';

  @override
  String get bridgesMore => 'और';

  @override
  String bridgesTryingAnotherWayOf(String attempt, String attempts) {
    return 'दूसरा तरीक़ा आज़मा रहे हैं… ($attempts में से $attempt)';
  }

  @override
  String get bridgesLookingForAVolunteer => 'स्वयंसेवक ढूँढ रहे हैं';

  @override
  String get bridgesFastestWhereTorIsnt =>
      'जहाँ Tor पर रोक नहीं, वहाँ सबसे तेज़। Kryfo कभी Tor के बाहर नहीं जुड़ता।';

  @override
  String get transportBridgePhase => 'चरण';

  @override
  String get bridgesAsleepBetweenCheckIns => 'जाँचों के बीच सोया हुआ';

  @override
  String get bridgesThroughABridge => 'ब्रिज से होकर';

  @override
  String get bridgesBuiltIn => 'पहले से मौजूद';

  @override
  String get bridgesPasteOrScanALineDesk =>
      'Tor Project से या किसी भरोसेमंद व्यक्ति से मिली लाइन पेस्ट करें।';

  @override
  String get bridgesDetails => 'विवरण';

  @override
  String get transportBridgeMode => 'ब्रिज';

  @override
  String get bridgesYourBridgeCouldNot => 'आपका ब्रिज शुरू नहीं हो पाया';

  @override
  String get bridgesKryfoStaysOfflineRather =>
      'इसके बिना जुड़ने के बजाय Kryfo ऑफ़लाइन रहता है।';

  @override
  String get bridgesSignInToThisWifi => 'इस Wi-Fi में साइन इन करें';

  @override
  String get bridgesThisNetworkWantsA =>
      'यह नेटवर्क पहले साइन इन माँगता है। साइन इन होते ही Kryfo जुड़ जाएगा।';

  @override
  String get bridgesThisNetworkWantsADesk =>
      'यह नेटवर्क पहले साइन इन माँगता है। अपने ब्राउज़र से साइन इन करें, या कंप्यूटर का नेटवर्क कनेक्शन जाँचें। साइन इन होते ही Kryfo जुड़ जाएगा।';

  @override
  String get bridgesWaitingForWifiSignIn => 'Wi-Fi साइन इन का इंतज़ार';

  @override
  String get bridgesOpenWifiSettings => 'Wi-Fi सेटिंग खोलें';

  @override
  String get bridgesUsingBuiltIn => 'पहले से मौजूद ब्रिज इस्तेमाल हो रहे हैं';

  @override
  String get bridgesUsingSnowflake => 'Snowflake इस्तेमाल हो रहा है';

  @override
  String get bridgesUsingTorProject =>
      'Tor Project के ब्रिज इस्तेमाल हो रहे हैं';

  @override
  String get bridgesBridgeRemoved => 'ब्रिज हटाया गया';

  @override
  String get bridgesUndo => 'वापस लें';

  @override
  String bridgesRemoveBridgeN(String n) {
    return 'ब्रिज $n हटाएँ';
  }

  @override
  String get bridgesTurnOnAutomatic => 'अपने-आप चालू करें';

  @override
  String get bridgesPasteABridgeLine => 'ब्रिज लाइन पेस्ट करें';

  @override
  String get bridgesInUse => 'इस्तेमाल में';

  @override
  String get bridgesPasteTheLineThey =>
      'ब्रिज लाइन पेस्ट करें, या उसका कोड स्कैन करें। लाइनें Tor Project से या जान-पहचान वालों से ही लें।';

  @override
  String get bridgesYouReOnAMode =>
      'आपका मोड Tor इस्तेमाल नहीं करता। ये विकल्प तब लागू होंगे जब आप वापस जाएँगे।';

  @override
  String get bridgesPasteOrScanALine =>
      'Tor Project से या किसी भरोसेमंद व्यक्ति से मिली लाइन पेस्ट या स्कैन करें।';

  @override
  String get bridgesNothingYet => 'अभी कुछ नहीं';

  @override
  String get torBootSplashIfTorIsBlocked =>
      'अगर आपकी जगह पर Tor पर रोक या नज़र है, तो Kryfo इसके बजाय ब्रिज से शुरू हो सकता है।';

  @override
  String get bridgesScanACode => 'कोड स्कैन करें';

  @override
  String get bridgesSwitchToAutomatic => 'अपने-आप पर जाएँ';

  @override
  String get torBootSplashTorIsBlockedHere => 'यहाँ Tor पर रोक या नज़र है';

  @override
  String get torBootSplashStartThroughABridge => 'ब्रिज से शुरू करें';

  @override
  String get torBootSplashNeverTriesTorPlainly =>
      'Kryfo यहाँ कभी सीधे Tor नहीं आज़माता। वह काम करने वाला ब्रिज ढूँढ लेता है, या अगली स्क्रीन पर आप अपना ख़ुद चुन सकते हैं।';

  @override
  String get bridgesTryingAnotherWay => 'दूसरा तरीक़ा आज़मा रहे हैं…';

  @override
  String get bridgesFindingAWayIn => 'अंदर जाने का रास्ता ढूँढ रहे हैं…';

  @override
  String get bridgesGoesThroughAVolunteer =>
      'किसी स्वयंसेवक के कंप्यूटर से होकर जाता है। रोकना मुश्किल, शुरू होने में धीमा।';

  @override
  String get bridgesTorSeemsBlocked => 'लगता है इस नेटवर्क पर Tor रुका हुआ है';

  @override
  String get bridgesTorIsBlockedOnThis => 'इस नेटवर्क पर Tor रुका हुआ है';

  @override
  String bridgesKryfoCouldNotRead(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Kryfo इनमें से $countString लाइनें नहीं पढ़ पाया',
      one: 'Kryfo इनमें से $countString लाइन नहीं पढ़ पाया',
    );
    return '$_temp0';
  }

  @override
  String get bridgesTorNoBridge => 'Tor, बिना ब्रिज';

  @override
  String get bridgesKryfoFindsAWay =>
      'Kryfo ऐसा तरीक़ा ढूँढता है जो आपकी जगह पर काम करे।';

  @override
  String get bridgesTorVpnLine =>
      'Orbot जैसे Tor VPN के अंदर, Kryfo ब्रिज से शुरू करता है।';

  @override
  String get bridgesThisBridgeIsnTGetting => 'यह ब्रिज पार नहीं हो पा रहा';

  @override
  String get bridgesBridgesTheTorProject =>
      'Tor Project के पहले दिए हुए ब्रिज।';

  @override
  String get bridgesConnectingDots => 'जुड़ रहा है…';

  @override
  String get bridgesNotNow => 'अभी नहीं';

  @override
  String get bridgesObfs4BridgesThatCome =>
      'Kryfo के साथ आने वाले ब्रिज (obfs4)। आज़माने में जल्दी, अक्सर रोके जाते हैं।';

  @override
  String get bridgesYourNetworkMayBe => 'हो सकता है आपका नेटवर्क सीमित हो';

  @override
  String get bridgesCheckingForMessages => 'मैसेज देख रहे हैं…';

  @override
  String get bridgesSavedLines => 'सेव की गई लाइनें';

  @override
  String get bridgesPasteTheLineTheyDesk =>
      'ब्रिज लाइन पेस्ट करें। लाइनें Tor Project से या जान-पहचान वालों से ही लें।';

  @override
  String get bridgesPastedLower => 'पेस्ट किया गया';

  @override
  String get bridgesAlmostThere => 'बस पहुँचने वाले हैं';

  @override
  String get bridgesUseThisBridge => 'यह ब्रिज इस्तेमाल करें';

  @override
  String bridgesUseTheseBridges(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ये $countString ब्रिज इस्तेमाल करें',
    );
    return '$_temp0';
  }

  @override
  String get transportBridgeMethod => 'तरीक़ा';

  @override
  String get bridgesPointAtTheBridge => 'ब्रिज के QR कोड की ओर करें';

  @override
  String get bridgesConnectingThroughYourBridge =>
      'आपके ब्रिज से जुड़ रहे हैं…';

  @override
  String get bridgesThisLineIsTooLong =>
      'यह लाइन Tor के इस्तेमाल के लिए बहुत लंबी है।';

  @override
  String get bridgesAutomaticFindsAWay =>
      'जब Tor पर रोक हो, “अपने-आप” ख़ुद ही रास्ता ढूँढ लेता है। ब्रिज ढूँढने के लिए Kryfo, आपकी सहमति हो तो, Tor Project से पूछ सकता है।';

  @override
  String get bridgesFromTheTorProjectLower => 'Tor Project से';

  @override
  String get bridgesBridgesGoDeadWithout =>
      'ब्रिज बिना बताए काम करना बंद कर सकते हैं। “अपने-आप” कोई दूसरा रास्ता ढूँढ सकता है।';

  @override
  String get bridgesWhenTorIsBlockedAutomatic =>
      'जब Tor पर रोक हो, “अपने-आप” Tor Project से पूछता है कि आपके देश में क्या काम करता है।';

  @override
  String get bridgesPlainAdvice =>
      'Kryfo अपने आप ब्रिज चुनता है। Snowflake और WebTunnel ज़्यादातर जगहों पर काम करते हैं। अगर कोई कनेक्ट न हो, तो दूसरा आज़माएँ, Tor Project से एक निजी ब्रिज लें, या किसी दोस्त से ब्रिज लाइन माँगें।';

  @override
  String get bridgesPrivateHint =>
      'अपने आप कनेक्ट नहीं हो रहा? Tor Project से एक निजी ब्रिज लें, फिर उसे नीचे पेस्ट करें।';

  @override
  String get bridgesPrivateWebsite => 'वेबसाइट';

  @override
  String get bridgesPrivateEmail => 'ईमेल';

  @override
  String get bridgesPrivateEmailFrom => 'Gmail या Riseup से भेजें';

  @override
  String bridgesPrivateCopy(Object what) {
    return '$what कॉपी करें';
  }

  @override
  String bridgesPrivateCopied(Object what) {
    return '$what कॉपी हुआ';
  }

  @override
  String bridgesPrivateOpen(Object what) {
    return '$what खोलें';
  }

  @override
  String get bridgesWatchedTitle => 'मेरे नेटवर्क पर नज़र रखी जाती है';

  @override
  String get bridgesWatchedLine => 'Kryfo कभी बिना ब्रिज के Tor नहीं आज़माता।';

  @override
  String get bridgesWatchedFastCost =>
      'आपका नेटवर्क देख सकता है कि आप Kryfo इस्तेमाल करते हैं।';

  @override
  String get bridgesWatchedDirectCost =>
      'आपका नेटवर्क देख सकता है कि आप Tor इस्तेमाल करते हैं।';

  @override
  String get bridgesWatchedNowAuto =>
      'अब अपने-आप पर है, इसलिए Tor हमेशा ब्रिज से शुरू होता है';

  @override
  String get bridgesAskTorProject => 'Tor Project से पूछें';

  @override
  String get bridgesTooLongForTor => 'Tor के लिए बहुत लंबी';

  @override
  String bridgesMethodFrom(String method, String from) {
    return '$method, $from';
  }

  @override
  String get bridgesKryfoCanTUseThis => 'Kryfo यह लाइन इस्तेमाल नहीं कर सकता';

  @override
  String get bridgesTryAutomatic => 'अपने-आप आज़माएँ';

  @override
  String get bridgesNoInternet => 'इंटरनेट नहीं';

  @override
  String get bridgesConnection => 'कनेक्शन';

  @override
  String get bridgesGetABridge => 'ब्रिज लें';

  @override
  String get languageTitle => 'भाषा';

  @override
  String get languageMatchPhone => 'फ़ोन जैसी';

  @override
  String get languageMatchPhoneDesk => 'सिस्टम जैसी';

  @override
  String languageMatchPhoneValue(Object language) {
    return 'फ़ोन जैसी ($language)';
  }

  @override
  String languageMatchPhoneValueDesk(Object language) {
    return 'सिस्टम जैसी ($language)';
  }

  @override
  String get languageRedrawLine =>
      'Kryfo नई भाषा में फिर से दिखेगा और आपकी चैट पर खुलेगा।';

  @override
  String languageButton(Object language) {
    return 'भाषा: $language';
  }

  @override
  String get androidServiceTitle => 'Kryfo चालू है';

  @override
  String get androidServiceText =>
      'आपकी एन्क्रिप्टेड लाइन खुली रहती है ताकि मैसेज आते रहें';

  @override
  String get androidChannelName => 'जुड़े रहना';

  @override
  String get androidChannelDescription =>
      'Kryfo को जोड़े रखता है ताकि उसके बंद रहने पर भी एन्क्रिप्टेड मैसेज आते रहें। इसे बंद करने से मैसेज आना रुक जाता है।';

  @override
  String get videoViewerPlay => 'चलाएँ';

  @override
  String get videoViewerPause => 'रोकें';

  @override
  String get videoViewerPlayAgain => 'फिर से चलाएँ';

  @override
  String get videoViewerCannotPlay => 'यह फ़ोन यह वीडियो यहाँ नहीं चला सकता।';

  @override
  String get videoViewerCannotPlayDesk =>
      'यह कंप्यूटर यह वीडियो यहाँ नहीं चला सकता।';

  @override
  String get videoViewerOpenElsewhere => 'दूसरे ऐप में खोलें';

  @override
  String get photoKnowsLookedFor => 'इन्हें ढूँढा';

  @override
  String get photoKnowsNotInIt => 'इसमें नहीं';

  @override
  String get languageNameEn => 'अंग्रेज़ी';

  @override
  String get languageNameDe => 'जर्मन';

  @override
  String get languageNameFr => 'फ़्रेंच';

  @override
  String get languageNameEs => 'स्पेनिश';

  @override
  String get languageNamePt => 'पुर्तगाली (ब्राज़ील)';

  @override
  String get languageNameIt => 'इतालवी';

  @override
  String get languageNameRu => 'रूसी';

  @override
  String get languageNameUk => 'यूक्रेनी';

  @override
  String get languageNameTr => 'तुर्की';

  @override
  String get languageNameZh => 'चीनी (सरल)';

  @override
  String get languageNameZhHant => 'चीनी (पारंपरिक)';

  @override
  String get languageNameVi => 'वियतनामी';

  @override
  String get languageNameId => 'इंडोनेशियाई';

  @override
  String get languageNameFa => 'फ़ारसी';

  @override
  String get languageNameAr => 'अरबी';

  @override
  String get languageNameHi => 'हिन्दी';

  @override
  String get languageNamePl => 'पोलिश';

  @override
  String get languageLaterLine => 'आप इसे कभी भी सेटिंग में बदल सकते हैं।';

  @override
  String get pollAttach => 'पोल';

  @override
  String get pollNewTitle => 'नया पोल';

  @override
  String get pollQuestionHint => 'ग्रुप से कुछ पूछें';

  @override
  String get pollOptionsLabel => 'विकल्प';

  @override
  String pollOptionHint(Object n) {
    return 'विकल्प $n';
  }

  @override
  String get pollAddOption => 'विकल्प जोड़ें';

  @override
  String get pollMaxLine => 'ज़्यादा से ज़्यादा बारह विकल्प।';

  @override
  String get pollMultiple => 'कई जवाब';

  @override
  String get pollMultipleLine => 'लोग एक से ज़्यादा चुन सकते हैं।';

  @override
  String get pollSend => 'पोल भेजें';

  @override
  String get pollKind => 'पोल';

  @override
  String get pollKindMulti => 'पोल · कई जवाब';

  @override
  String get pollKindClosed => 'आख़िरी नतीजा';

  @override
  String pollVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count वोट',
      one: '$count वोट',
      zero: 'अभी कोई वोट नहीं',
    );
    return '$_temp0';
  }

  @override
  String get pollVote => 'वोट करें';

  @override
  String get pollTakeBack => 'मेरा वोट वापस लें';

  @override
  String get pollClose => 'पोल बंद करें';

  @override
  String get pollCloseTitle => 'यह पोल बंद करें?';

  @override
  String get pollCloseLine =>
      'सबको आख़िरी नतीजा दिखेगा, और इसके बाद कोई वोट नहीं कर सकेगा।';

  @override
  String get pollCloseYes => 'बंद करें';

  @override
  String pollPreview(Object question) {
    return 'पोल: $question';
  }

  @override
  String get pollWhoVoted => 'किसने वोट किया';

  @override
  String get pollNobody => 'अभी कोई नहीं';

  @override
  String get pollYou => 'आप';

  @override
  String pollOptionA11y(Object option, Object share) {
    return '$option, $share';
  }

  @override
  String get pollPickOne => 'एक चुनें';

  @override
  String get pollPickSeveral => 'एक या ज़्यादा चुनें';

  @override
  String get searchHint => 'चैट और मैसेज खोजें';

  @override
  String get searchFilterAll => 'सब';

  @override
  String get searchFilterPhotos => 'फ़ोटो';

  @override
  String get searchFilterVideos => 'वीडियो';

  @override
  String get searchFilterFiles => 'फ़ाइलें';

  @override
  String get searchFilterLinks => 'लिंक';

  @override
  String get searchChats => 'चैट';

  @override
  String get searchMessages => 'मैसेज';

  @override
  String get searchIntroTitle => 'अपनी चैट खोजें';

  @override
  String get searchIntroLine =>
      'नाम, शब्द, फ़ोटो, फ़ाइलें और लिंक। खोज इसी फ़ोन पर चलती है और कहीं कुछ नहीं भेजती।';

  @override
  String get searchIntroLineDesk =>
      'नाम, शब्द, फ़ोटो, फ़ाइलें और लिंक। खोज इसी कंप्यूटर पर चलती है और कहीं कुछ नहीं भेजती।';

  @override
  String get searchNothing => 'कुछ नहीं मिला';

  @override
  String get searchNothingLine => 'कोई दूसरा शब्द या दूसरा फ़िल्टर आज़माएँ।';

  @override
  String searchMatches(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count नतीजे',
      one: '$count नतीजा',
    );
    return '$_temp0';
  }

  @override
  String searchMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count और',
      one: '$count और',
    );
    return '$_temp0';
  }

  @override
  String searchFilling(Object share) {
    return 'पुराने मैसेज जोड़े जा रहे हैं · $share';
  }

  @override
  String get searchClear => 'साफ़ करें';

  @override
  String get handleShowInSearch => 'मुझे खोज में दिखाएँ';

  @override
  String get handleShowInSearchLine =>
      'कोई भी यह यूज़रनेम ढूँढकर आपको मैसेज कर सकता है।';

  @override
  String handleShownAs(Object name) {
    return '$name के रूप में दिखता है';
  }

  @override
  String get handleNameInSearch => 'खोज में नाम';

  @override
  String get handleNameInSearchLine =>
      'ज़रूरी नहीं। कोई खोजे तो यह आपके यूज़रनेम के साथ दिखता है। कोई भी यह यूज़रनेम ढूँढकर आपको मैसेज कर सकता है।';

  @override
  String get handleNameHint => 'आपका नाम, या ख़ाली छोड़ें';

  @override
  String get handleShowMe => 'मुझे दिखाएँ';

  @override
  String get handleSearchOff => 'अब आप खोज में नहीं हैं';

  @override
  String handleSearchOn(Object handle) {
    return 'अब आप खोज में @$handle के रूप में हैं';
  }

  @override
  String get handleRegistryFailed =>
      'रजिस्ट्री तक नहीं पहुँच पाए।\nएक मिनट में फिर कोशिश करें।';

  @override
  String get handleStillReaching =>
      'अभी रजिस्ट्री तक पहुँच रहे हैं।\nTor पर इसमें कुछ समय लग सकता है।';

  @override
  String get handleSearchNeedsTor =>
      'यूज़रनेम खोजने के लिए Tor चाहिए। तब तक QR या लिंक से जोड़ें।';

  @override
  String get handleNeedsTor =>
      'यूज़रनेम Tor से होकर जाते हैं।\nTor जुड़ते ही ये काम करेंगे।';

  @override
  String get handleRegistryBusy =>
      'रजिस्ट्री अभी व्यस्त है।\nएक मिनट में फिर कोशिश करें।';

  @override
  String get handleRefusedFull => 'रजिस्ट्री ने मना किया: अभी यह भरी हुई है।';

  @override
  String get handleRefusedOlder =>
      'रजिस्ट्री ने मना किया: इसके पास नया बदलाव पहले से है।\nघड़ी जाँचें और फिर कोशिश करें।';

  @override
  String get handleRefusedBadInvite =>
      'रजिस्ट्री ने मना किया: यह आपका आमंत्रण नहीं पढ़ पाई।';

  @override
  String get handleRefusedNotYourInvite =>
      'रजिस्ट्री ने मना किया: यह आमंत्रण आपकी कुंजी का नहीं है।';

  @override
  String get handleRefusedUpdate =>
      'रजिस्ट्री ने मना किया: Kryfo का यह संस्करण बहुत पुराना है।\nयूज़रनेम के लिए Kryfo अपडेट करें।';

  @override
  String get handleRefused => 'रजिस्ट्री ने मना किया।';

  @override
  String get handleGetABridge => 'ब्रिज पाएँ';

  @override
  String get handleCheckClock =>
      'फ़ोन की तारीख़ और समय जाँचें, फिर दोबारा कोशिश करें।';

  @override
  String get handleCheckClockDesk =>
      'कंप्यूटर की तारीख़ और समय जाँचें, फिर दोबारा कोशिश करें।';

  @override
  String get searchPeople => 'लोग';

  @override
  String searchPeopleAsk(Object query) {
    return 'सार्वजनिक यूज़रनेम में “$query” ढूँढें';
  }

  @override
  String get searchPeopleLine =>
      'Tor से पूछा जाता है। रजिस्ट्री इसका कोई रिकॉर्ड नहीं रखती।';

  @override
  String get searchPeopleNone => 'कोई सार्वजनिक यूज़रनेम मेल नहीं खाता';

  @override
  String get searchPeopleOffline => 'Tor अभी तैयार नहीं है';

  @override
  String get searchPeopleBusy =>
      'अभी बहुत ज़्यादा खोजें हो रही हैं। थोड़ी देर में फिर कोशिश करें।';

  @override
  String get searchPeopleUnreachable => 'रजिस्ट्री तक नहीं पहुँच पाए';

  @override
  String get peopleVerified => 'पुष्टि किया हुआ यूज़रनेम';

  @override
  String get peopleAdd => 'जोड़ें';

  @override
  String peopleFingerprint(Object fp) {
    return 'कुंजी की पहचान · $fp';
  }

  @override
  String get peopleFingerprintLine =>
      'देखें कि यह वही है जो उन्हें अपने ऐप में दिखता है।';

  @override
  String get peopleAdding => 'जोड़ रहे हैं…';

  @override
  String handleNobodyHasClaimed(Object handle) {
    return 'किसी ने $handle नहीं लिया है';
  }

  @override
  String get handleThatHandleIsTaken => 'यह यूज़रनेम पहले से लिया हुआ है';

  @override
  String get pinPickDifferent => 'कोई दूसरा PIN चुनें';

  @override
  String get lockFingerAfterPin =>
      'फ़िंगरप्रिंट फिर से इस्तेमाल करने के लिए एक बार अपना PIN लिखें।';

  @override
  String get lockFingerLockedOut =>
      'फ़िंगरप्रिंट से बहुत ज़्यादा कोशिशें। अपना PIN इस्तेमाल करें, या फ़िंगरप्रिंट फिर से इस्तेमाल करने के लिए अपना फ़ोन एक बार उसके अपने स्क्रीन लॉक से खोलें।';

  @override
  String get lockFingerRefused =>
      'आपके फ़ोन ने Kryfo के लिए फ़िंगरप्रिंट अनलॉक नहीं रखा, इसलिए यह बंद है। आपका PIN अब भी काम करता है।';

  @override
  String get lockFingerTryAgain =>
      'उस वक़्त आपका फ़ोन व्यस्त था। फ़िंगरप्रिंट फिर आज़माएँ, या अपना PIN इस्तेमाल करें।';

  @override
  String get pinsFingerRefused =>
      'आपके फ़ोन ने Kryfo के लिए फ़िंगरप्रिंट अनलॉक चालू नहीं किया। आपका PIN अब भी काम करता है।';

  @override
  String get pinsAdvanced => 'अतिरिक्त सुरक्षा';

  @override
  String get pinsAdvancedLine =>
      'जब कोई आपसे ज़बरदस्ती फ़ोन खुलवाए, उस वक़्त के लिए।';

  @override
  String get pinsAdvancedLineDesk =>
      'जब कोई आपसे ज़बरदस्ती कंप्यूटर खुलवाए, उस वक़्त के लिए।';

  @override
  String get pinsWipeLine =>
      'लॉक स्क्रीन पर लिखने पर यह इस फ़ोन से Kryfo पूरी तरह मिटा देता है।';

  @override
  String get pinsWipeLineDesk =>
      'लॉक स्क्रीन पर लिखने पर यह इस कंप्यूटर से Kryfo पूरी तरह मिटा देता है।';

  @override
  String get pinsDecoyPin => 'नकली PIN';

  @override
  String get pinsDecoyLine =>
      'एक ख़ाली Kryfo खोलता है, जैसे अभी-अभी इंस्टॉल हुआ हो।';

  @override
  String get pinsChangeDecoyPin => 'नकली PIN बदलें';

  @override
  String get pinsRemoveTheDecoyPin => 'नकली PIN हटाएँ?';

  @override
  String get pinsTheDecoyGoes =>
      'इसके साथ वह ख़ाली Kryfo भी हट जाता है जो यह खोलता है।';

  @override
  String get pinsTurnOffWithDecoy =>
      'हर PIN हट जाएगा, नकली PIN और उसका Kryfo, और उनके साथ सारी छिपी चैट भी। आपका फ़ोन जिसके हाथ में होगा, वह Kryfo को आपकी तरह खोल लेगा।';

  @override
  String get pinsTurnOffWithDecoyDesk =>
      'हर PIN हट जाएगा, नकली PIN और उसका Kryfo, और उनके साथ सारी छिपी चैट भी। आपके कंप्यूटर पर जो भी बैठेगा, वह Kryfo को आपकी तरह खोल लेगा।';

  @override
  String get pinsHowThisWorks => 'यह कैसे काम करता है';

  @override
  String get flowEnterYourPin => 'अपना PIN लिखें';

  @override
  String get flowEnterYourPinLine => 'वही जो Kryfo खोलता है।';

  @override
  String get flowWipeTitle => 'मिटाने वाला PIN';

  @override
  String get flowWipe1 =>
      'लॉक स्क्रीन पर अपने PIN की जगह लिखने पर यह इस फ़ोन से Kryfo पूरी तरह मिटाकर उसे बंद कर देता है। जो भी देख रहा हो, उसे लगेगा कि ऐप बस रुक गया।';

  @override
  String get flowWipe1Desk =>
      'लॉक स्क्रीन पर अपने PIN की जगह लिखने पर यह इस कंप्यूटर से Kryfo पूरी तरह मिटाकर उसे बंद कर देता है। जो भी देख रहा हो, उसे लगेगा कि ऐप बस रुक गया।';

  @override
  String get flowWipe2 =>
      'यह हर चैट और आपकी पहचान को साथ ले जाता है, और नकली Kryfo को भी, अगर है।';

  @override
  String get flowWipeChoose => 'मिटाने वाला PIN चुनें';

  @override
  String get flowWipeDone => 'मिटाने वाला PIN सेट हो गया';

  @override
  String get flowWipeDoneLine =>
      'लॉक स्क्रीन पर कुछ भी नहीं दिखाता कि यह मौजूद है।';

  @override
  String get flowDecoyTitle => 'नकली PIN';

  @override
  String get flowDecoy1 =>
      'एक ख़ाली Kryfo खोलता है, जैसे अभी-अभी इंस्टॉल हुआ हो।';

  @override
  String get flowDecoyFinger =>
      'जब तक नकली PIN सेट है, यह ऐप सिर्फ़ आपके PIN से खुलता है। अगर नकली Kryfo में फ़िंगरप्रिंट चालू है, तो उंगली नकली Kryfo खोलती है, यह ऐप कभी नहीं।';

  @override
  String get flowDecoyDigits =>
      'अपने PIN जितने ही अंक रखें, क्योंकि देखने वाला कोई भी बिंदु गिन सकता है।';

  @override
  String get flowDecoyShade =>
      'जो सूचनाएँ पहले से दिख रही थीं, वे पहले ही देखी जा चुकी हैं। नकली Kryfo खुला रहने तक कोई नई सूचना नहीं दिखती।';

  @override
  String get flowDecoyShadeDesk =>
      'जो सूचनाएँ पहले से स्क्रीन पर थीं, वे पहले ही देखी जा चुकी हैं। नकली Kryfo खुला रहने तक कोई नई सूचना नहीं दिखती।';

  @override
  String get flowDecoyChoose => 'नकली PIN चुनें';

  @override
  String get flowDecoyDone => 'नकली PIN सेट हो गया';

  @override
  String get flowDecoyDoneLine =>
      'ख़ाली Kryfo खोलने के लिए इसे लॉक स्क्रीन पर लिखें। उससे निकलने के लिए किसी दूसरे ऐप पर जाएँ और अपना PIN लिखें।';

  @override
  String get flowLaw =>
      'कुछ देशों में फ़ोन अनलॉक करने से मना करना या अधिकारियों से डेटा छिपाना अपने-आप में अपराध है। जहाँ आप जाते हैं, वहाँ का क़ानून जानें।';

  @override
  String get flowLawDesk =>
      'कुछ देशों में किसी डिवाइस को अनलॉक करने से मना करना या अधिकारियों से डेटा छिपाना अपने-आप में अपराध है। जहाँ आप जाते हैं, वहाँ का क़ानून जानें।';

  @override
  String get howWipe =>
      'लॉक स्क्रीन पर लिखने पर मिटाने वाला PIN हर चैट, आपकी पहचान और नकली Kryfo, अगर है, सब मिटाकर Kryfo बंद कर देता है। ग़लत कोशिशों के बाद पैड रुका हो, तब भी यह काम करता है।';

  @override
  String get howDecoy =>
      'नकली PIN एक दूसरा, ख़ाली Kryfo खोलता है, जिसके अपने तीन शब्द होते हैं। आपके असली Kryfo के मैसेज नीचे चुपचाप आते रहते हैं। नकली Kryfo से निकलने के लिए किसी दूसरे ऐप पर जाएँ और अपना PIN लिखें।';

  @override
  String get flowNotSet => 'सेट नहीं हो पाया। दोबारा कोशिश करें।';

  @override
  String get pinsHiddenChats => 'छिपी चैट';

  @override
  String get pinsHiddenLine =>
      'चुनी हुई चैट तब तक नज़र से दूर रहती हैं जब तक आप छिपी चैट PIN न लिखें: न सूची में, न खोज में, न कोई सूचना।';

  @override
  String get pinsSetUp => 'सेट करें';

  @override
  String get pinsChangeHiddenPin => 'छिपी चैट PIN बदलें';

  @override
  String get pinsHideMoreChats => 'और चैट छिपाएँ';

  @override
  String get pinsRemoveHiddenChats => 'छिपी चैट हटाएँ';

  @override
  String get pinsRemoveHiddenTitle => 'छिपी चैट हटाएँ?';

  @override
  String get pinsRemoveHiddenLine =>
      'वे आपकी चैट सूची में लौट आएँगी, और छिपी चैट PIN अब कुछ नहीं खोलेगा।';

  @override
  String get pinsTurnOffHiddenFirst =>
      'छिपी चैट के लिए ऐप लॉक चाहिए। पहले उन्हें हटाएँ, वे आपकी चैट सूची में लौट आएँगी।';

  @override
  String get flowVaultTitle => 'छिपी चैट';

  @override
  String get flowVault1 =>
      'छिपाने के लिए चैट और ग्रुप चुनें। आपका PIN उनके बिना Kryfo खोलता है। छिपी चैट PIN सब कुछ खोलता है, छिपी चैट समेत।';

  @override
  String get flowVault2 =>
      'नज़र से दूर रहने के दौरान वे कभी सूचना या बैज नहीं दिखातीं। उनके मैसेज आते रहते हैं और एन्क्रिप्टेड रहकर आपके छिपी चैट PIN का इंतज़ार करते हैं।';

  @override
  String get flowVaultFinger =>
      'आपका फ़िंगरप्रिंट छिपी चैट के बिना Kryfo खोलता है।';

  @override
  String get flowVaultDigits =>
      'अपने PIN में भी छह या ज़्यादा अंक रखें, क्योंकि देखने वाला कोई भी बिंदु गिन सकता है।';

  @override
  String get flowVaultReplace =>
      'इससे वे सारी छिपी चैट बदल जाती हैं जो इस फ़ोन पर पहले से हैं।';

  @override
  String get flowVaultReplaceDesk =>
      'इससे वे सारी छिपी चैट बदल जाती हैं जो इस कंप्यूटर पर पहले से हैं।';

  @override
  String get flowVaultChoose => 'छिपी चैट PIN चुनें';

  @override
  String get flowVaultChooseLine => 'छह या ज़्यादा अंक।';

  @override
  String get flowEnterHiddenPinLine => 'वही जो आपकी छिपी चैट खोलता है।';

  @override
  String get flowVaultForgetTitle => 'यह PIN याद रखें';

  @override
  String get flowVaultForget =>
      'अगर आप यह PIN भूल गए, तो आपकी छिपी चैट हमेशा के लिए चली जाएँगी। कोई उन्हें वापस नहीं ला सकता।';

  @override
  String get flowVaultForgetOk => 'मुझे समझ आ गया';

  @override
  String get flowVaultPickTitle => 'छिपाने के लिए चैट चुनें';

  @override
  String get flowVaultPickLine =>
      'वे अभी आपकी चैट सूची से हट जाएँगी। आपका छिपी चैट PIN उन्हें फिर से सामने लाता है।';

  @override
  String flowVaultPickButton(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString चैट छिपाएँ',
      one: '$countString चैट छिपाएँ',
      zero: 'अभी कुछ न छिपाएँ',
    );
    return '$_temp0';
  }

  @override
  String get flowVaultPickEmpty => 'छिपाने के लिए अभी कोई चैट नहीं।';

  @override
  String get flowVaultBackupTitle => 'अभी बैकअप बनाएँ?';

  @override
  String get flowVaultBackupLine =>
      'अभी बना बैकअप आपकी छिपी चैट भी रखता है, अपने अलग पासफ़्रेज़ के साथ। अगर आप छिपी चैट PIN भूल जाएँ, तो उन तक लौटने का यही एक रास्ता है।';

  @override
  String get flowVaultBackupNow => 'बैकअप बनाएँ';

  @override
  String get flowVaultNotNow => 'अभी नहीं';

  @override
  String get flowVaultDone => 'छिपी चैट सेट हो गईं';

  @override
  String get flowVaultDoneLine =>
      'उन्हें देखने के लिए लॉक स्क्रीन पर अपना छिपी चैट PIN लिखें। किसी दूसरे ऐप पर जाते ही वे फिर नज़र से दूर हो जाती हैं।';

  @override
  String get flowVaultChanged => 'छिपी चैट PIN बदल गया';

  @override
  String get flowVaultChangedLine =>
      'आपकी छिपी चैट अब नए PIN से खुलती हैं। पुराना अब कुछ नहीं खोलता।';

  @override
  String get howVault =>
      'आपका छिपी चैट PIN आपकी छिपी चैट के साथ Kryfo खोलता है, आपका PIN और फ़िंगरप्रिंट उनके बिना। छिपी चैट फिर से सेट करने पर इस फ़ोन की मौजूदा छिपी चैट बदल जाती हैं। छिपी चैट PIN भूल गए, तो वे हमेशा के लिए चली जाती हैं।';

  @override
  String get howVaultDesk =>
      'आपका छिपी चैट PIN आपकी छिपी चैट के साथ Kryfo खोलता है, आपका PIN उनके बिना। छिपी चैट फिर से सेट करने पर इस कंप्यूटर की मौजूदा छिपी चैट बदल जाती हैं। छिपी चैट PIN भूल गए, तो वे हमेशा के लिए चली जाती हैं।';

  @override
  String get chatHide => 'चैट छिपाएँ';

  @override
  String get groupHide => 'ग्रुप छिपाएँ';

  @override
  String get chatHidden => 'छिपी हुई';

  @override
  String get chatHiddenToast => 'आपकी चैट सूची से छिपा दिया गया';

  @override
  String get chatShowInList => 'चैट सूची में दिखाएँ';

  @override
  String get stickerOpen => 'स्टिकर';

  @override
  String get stickerRecent => 'हाल के';

  @override
  String stickerA11y(String emoji) {
    return 'स्टिकर $emoji';
  }

  @override
  String get stickerRemoveRecent => 'हाल के से हटाएँ';

  @override
  String get stickerCouldNotLoad => 'स्टिकर लोड नहीं हो पाए';

  @override
  String get stickerLabel => 'स्टिकर';

  @override
  String get timedMessageLabel => 'मिटने वाला मैसेज';

  @override
  String get stickerNewer => 'Kryfo के नए वर्शन से';

  @override
  String get devLinkMismatch =>
      'यह लिंक कहता है कि यह Marios है, पर इसकी कुंजी मेल नहीं खाती। इसे जोड़ा नहीं गया।';

  @override
  String get devName => 'Marios';

  @override
  String get devRowTitle => 'Marios · Kryfo बनाया';

  @override
  String get devWelcome =>
      'नमस्ते, मैं Marios हूँ, मैं Kryfo बनाता हूँ। मुझे कुछ भी बताइए: बग, आइडिया, सवाल। मैं सब कुछ पढ़ता हूँ।';

  @override
  String get devPinned => 'Kryfo में पहले से तय';

  @override
  String get devAnonymous => 'गुमनाम';

  @override
  String get devAboutLine =>
      'Marios की कुंजी Kryfo के अंदर बनी हुई है। उनका हर मैसेज उससे जाँचा जाता है, इसलिए कोई और उनके नाम से नहीं लिख सकता।';

  @override
  String get devKeyLabel => 'उनकी कुंजी';

  @override
  String get devDeleteLine => 'हर मैसेज हट जाएगा, और चैट वापस नहीं आएगी।';

  @override
  String get devDeleteLineAnon =>
      'हर मैसेज और इस चैट के लिए बना नाम हट जाएगा, और चैट वापस नहीं आएगी।';

  @override
  String get devDeleteLineBack =>
      'हर मैसेज हट जाएगा, और चैट वापस नहीं आएगी। आपने जो भेजा, वह Marios के फ़ोन से भी वापस ले लिया जाएगा।';

  @override
  String get devDeleteLineAnonBack =>
      'हर मैसेज और इस चैट के लिए बना नाम हट जाएगा, और चैट वापस नहीं आएगी। आपने जो भेजा, वह Marios के फ़ोन से भी वापस ले लिया जाएगा।';

  @override
  String devDeleteNotTakenBack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count मैसेज Marios के फ़ोन से वापस नहीं लिए जा सके',
      one: '$count मैसेज Marios के फ़ोन से वापस नहीं लिया जा सका',
    );
    return '$_temp0';
  }

  @override
  String get devDeleteFailed => 'चैट डिलीट नहीं हो पाई। दोबारा कोशिश करें।';

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
  String get supportCopyDevCard => 'Copy my developer card';

  @override
  String get supportDevCardOff =>
      'This card does not match the pinned one. Nothing was copied.';

  @override
  String get settingsWriteToMarios => 'Marios को लिखें';

  @override
  String get settingsWriteToMariosHint => 'बग, आइडिया, सवाल';

  @override
  String get seenDevChat => 'Marios वाली चैट';

  @override
  String get seenDevChatCell => 'अगर आप लिखें';

  @override
  String get seenDevChatLine =>
      'जब तक आप न लिखें, कुछ नहीं। फिर जो आप भेजें, और आपके तीन शब्द, अगर आप गुमनाम होकर न लिखें।';

  @override
  String get devWriteAnonymously => 'गुमनाम होकर लिखें';

  @override
  String get devUseMyWords => 'मेरे तीन शब्द इस्तेमाल करें';

  @override
  String get devWhoSeesWhat => 'यह कैसे काम करता है';

  @override
  String get devWhoWords =>
      'आपके तीन शब्दों के साथ यह किसी भी दूसरी चैट जैसी है: Marios जवाब दे सकते हैं, और आपका चेहरा और समर्थक बैज आपके साथ रहते हैं।';

  @override
  String get devWhoAnon =>
      'गुमनाम होने पर Kryfo सिर्फ़ इस चैट के लिए एक नया नाम और कुंजियाँ बनाता है। वे इसी फ़ोन पर रहती हैं और कहीं और कभी इस्तेमाल नहीं होतीं।';

  @override
  String get devWhoAnonDesk =>
      'गुमनाम होने पर Kryfo सिर्फ़ इस चैट के लिए एक नया नाम और कुंजियाँ बनाता है। वे इसी कंप्यूटर पर रहती हैं और कहीं और कभी इस्तेमाल नहीं होतीं।';

  @override
  String get devWhoNothingYet =>
      'जब तक आप पहला मैसेज न भेजें, कुछ भी आपके फ़ोन से बाहर नहीं जाता।';

  @override
  String get devWhoNothingYetDesk =>
      'जब तक आप पहला मैसेज न भेजें, कुछ भी आपके कंप्यूटर से बाहर नहीं जाता।';

  @override
  String get devWhoChoiceStays => 'आपका चुनाव इस चैट के साथ रहता है।';

  @override
  String get devUpdateToWrite =>
      'Marios को संदेश भेजने के लिए Kryfo अपडेट करें।';

  @override
  String get devKeyCheckFailed =>
      'Marios की कुंजी जाँची नहीं जा सकी। कुछ नहीं भेजा गया।';

  @override
  String get devLockLine =>
      'Marios इन्हें पढ़ेंगे। उनका जवाब आने के बाद आप और लिख सकते हैं।';

  @override
  String get devNewKey => 'Marios की नई कुंजी है';

  @override
  String get devStartNewChat => 'नई चैट शुरू करें';

  @override
  String get devKeyRetired =>
      'यह कुंजी हटा दी गई है। यहाँ अब कुछ भेजा या पाया नहीं जा सकता।';

  @override
  String get devNamelessLine =>
      'इस चैट के लिए बना नाम उसी फ़ोन पर रहता है जिस पर बना था, इसलिए यहाँ इसे सिर्फ़ पढ़ा जा सकता है।';

  @override
  String get devNamelessLineDesk =>
      'इस चैट के लिए बना नाम उसी डिवाइस पर रहता है जिस पर बना था, इसलिए यहाँ इसे सिर्फ़ पढ़ा जा सकता है।';

  @override
  String get devStartNewLine =>
      'यहाँ का हर मैसेज हट जाएगा, और एक नई चैट खुलेगी।';

  @override
  String get devVoiceDisguised => 'इस चैट में आपकी आवाज़ बदली हुई है';

  @override
  String get devChatOptions => 'चैट के विकल्प';

  @override
  String get requestsSomeoneNew => 'कोई नया';

  @override
  String get nameTakenTitle => 'ये शब्द कोई और इस्तेमाल करता है';

  @override
  String get nameTakenLine =>
      'यहाँ किसी को ये शब्द किसी अनुरोध, परिचय या ग्रुप से मिले, एक अलग कुंजी के साथ, और किसी ने इन्हें जाँचा नहीं। शब्दों की नक़ल की जा सकती है। अगर यह लिंक उसी व्यक्ति से आया है जिसे आप जानते हैं, तो इसे इस्तेमाल करें, फिर उनके साथ सुरक्षा नंबर मिलाएँ।';

  @override
  String get nameTakenChatLine =>
      'इन शब्दों वाली आपकी चैट किसी अनुरोध, परिचय या ग्रुप से आई, एक अलग कुंजी के साथ, और किसी ने इसे जाँचा नहीं। शब्दों की नक़ल की जा सकती है। अगर यह लिंक उसी व्यक्ति से आया है जिसे आप जानते हैं, तो इसे इस्तेमाल करें: वह चैट डिलीट हो जाएगी, और आप नई चैट में सुरक्षा नंबर मिलाएँ। पक्का नहीं कि लिंक कहाँ से आया? जो है वही रखें।';

  @override
  String get nameTakenDeletedLine =>
      'आपने इन शब्दों वाली एक चैट डिलीट की थी, जो एक अलग कुंजी पर चलती थी। अगर यह लिंक उसी व्यक्ति से आया है जिसे आप जानते हैं, तो इसे इस्तेमाल करें, फिर उनके साथ सुरक्षा नंबर मिलाएँ।';

  @override
  String get nameTakenTombLine =>
      'आपने इन शब्दों वाले किसी व्यक्ति को इस फ़ोन से हटाया था, क्योंकि वे वह नहीं थे जो उन्होंने बताया। अगर यह लिंक उसी व्यक्ति से आया है जिसे आप जानते हैं, तो इसे इस्तेमाल करें, फिर उनके साथ सुरक्षा नंबर मिलाएँ।';

  @override
  String get nameTakenTombLineDesk =>
      'आपने इन शब्दों वाले किसी व्यक्ति को इस कंप्यूटर से हटाया था, क्योंकि वे वह नहीं थे जो उन्होंने बताया। अगर यह लिंक उसी व्यक्ति से आया है जिसे आप जानते हैं, तो इसे इस्तेमाल करें, फिर उनके साथ सुरक्षा नंबर मिलाएँ।';

  @override
  String get nameTakenUse => 'यह लिंक इस्तेमाल करें';

  @override
  String get nameTakenKeep => 'जो है वही रखें';

  @override
  String get appYourOwnInvite =>
      'यह आपका अपना आमंत्रण है। जुड़ने के लिए इसे किसी और के साथ शेयर करें।';

  @override
  String appLinkNeedsUpdate(Object id) {
    return 'एक-दूसरे को जोड़ने से पहले $id को Kryfo अपडेट करना होगा।';
  }

  @override
  String appLinkWordsTaken(Object id) {
    return 'यहाँ कोई पहले से $id नाम से है, एक अलग कुंजी के साथ। कौन कौन है, यह जानने के लिए उनके साथ सुरक्षा नंबर मिलाएँ। कुछ नहीं जोड़ा गया।';
  }

  @override
  String appLinkWordsVerified(Object id) {
    return 'आपने $id की पुष्टि एक अलग कुंजी से की थी। कुछ नहीं जोड़ा गया।';
  }

  @override
  String appTheyAreBlocked(Object id) {
    return 'आपने $id को ब्लॉक किया है। उन्हें फिर से जोड़ने के लिए सेटिंग में ब्लॉक किए गए में जाकर अनब्लॉक करें।';
  }

  @override
  String get notThemNumbersDiffer => 'नंबर अलग हैं';

  @override
  String get notThemLine =>
      'अगर नंबर सच में अलग हैं, तो हो सकता है कोई और उनका नाम इस्तेमाल कर रहा हो या आप दोनों के बीच बैठा हो।';

  @override
  String get notThemButton => 'यह वे नहीं हैं';

  @override
  String get notThemSheetTitle => 'यह संपर्क हटाएँ और इसकी कुंजी ब्लॉक करें?';

  @override
  String get notThemSheetLine =>
      'चैट, उसके मैसेज और उसकी फ़ाइलें इस फ़ोन से हट जाएँगी। उनके तीन शब्द फिर सिर्फ़ वही लिंक या कोड ले सकता है जो आप ख़ुद जोड़ें। जिसे भी जोड़ें, उसके साथ सुरक्षा नंबर मिलाएँ।';

  @override
  String get notThemSheetLineDesk =>
      'चैट, उसके मैसेज और उसकी फ़ाइलें इस कंप्यूटर से हट जाएँगी। उनके तीन शब्द फिर सिर्फ़ वही लिंक या कोड ले सकता है जो आप ख़ुद जोड़ें। जिसे भी जोड़ें, उसके साथ सुरक्षा नंबर मिलाएँ।';

  @override
  String get notThemRemove => 'हटाएँ और ब्लॉक करें';

  @override
  String get notThemDone => 'हटा दिया, और उनकी कुंजी ब्लॉक हो गई';

  @override
  String get groupAdminGoneLine =>
      'इसके एडमिन को इस फ़ोन से हटा दिया गया। ग्रुप के बदलाव अब आप तक नहीं पहुँचते।';

  @override
  String get groupAdminGoneLineDesk =>
      'इसके एडमिन को इस कंप्यूटर से हटा दिया गया। ग्रुप के बदलाव अब आप तक नहीं पहुँचते।';

  @override
  String get blockedKey => 'ब्लॉक की गई कुंजी';

  @override
  String get appKeyBlocked =>
      'आपने यह कुंजी ब्लॉक की है। इसे जोड़ने के लिए सेटिंग में ब्लॉक किए गए में जाकर अनब्लॉक करें।';

  @override
  String get devLinkGone =>
      'आपने Marios वाली चैट डिलीट कर दी। नई शुरू करने के लिए सेटिंग में Marios को लिखें पर टैप करें।';

  @override
  String lockTooManyTriesFor(Object left) {
    return 'बहुत ज़्यादा कोशिशें · $left';
  }

  @override
  String get gifBadge => 'GIF';

  @override
  String get gifPlay => 'GIF चलाएँ';

  @override
  String get gifSentInside => 'आपके मैसेज के अंदर भेजा जाता है';

  @override
  String get gifOptInTitle => 'GIF खोजें, निजी तरीक़े से';

  @override
  String get gifOptInLead =>
      'GIF खोज के लिए इंटरनेट चाहिए, इसलिए यह तब तक बंद रहती है जब तक आप न चाहें।';

  @override
  String get gifOptInOverTor => 'Tor से खोजा जाता है';

  @override
  String get gifOptInThroughKryfo => 'Kryfo के ज़रिए खोजा जाता है';

  @override
  String get gifOptInAsksForYou =>
      'Kryfo का सर्वर आपकी तरफ़ से GIF सेवा से पूछता है। सेवा आपको कभी नहीं देखती, और सर्वर कोई रिकॉर्ड नहीं रखता कि आपने क्या खोजा।';

  @override
  String get gifOptInAsksForYouFast =>
      'Kryfo का सर्वर आपकी तरफ़ से GIF सेवा से पूछता है, इसलिए सेवा आपको कभी नहीं देखती। तेज़ पर खोजते समय हमारा सर्वर आपका IP पता देखता है, और न उसका, न आपकी खोज का कोई रिकॉर्ड रखता है।';

  @override
  String get gifOptInLikeAPhoto =>
      'GIF फ़ोटो की तरह एन्क्रिप्टेड होकर जाता है। आपके दोस्त का फ़ोन कुछ भी नहीं लाता।';

  @override
  String get gifOptInOffWhenever => 'जब चाहें बंद करें';

  @override
  String get gifOptInWhereToTurnOff =>
      'सेटिंग, प्राइवेसी, GIF खोज। आपके फ़ोन पर मौजूद GIF इसके बिना भी हमेशा काम करते हैं।';

  @override
  String get gifOptInWhereToTurnOffDesk =>
      'सेटिंग, प्राइवेसी, GIF खोज। आपके कंप्यूटर पर मौजूद GIF इसके बिना भी हमेशा काम करते हैं।';

  @override
  String get gifTurnOn => 'GIF खोज चालू करें';

  @override
  String get gifNotNow => 'अभी नहीं';

  @override
  String gifAskOverTor(String brand) {
    return 'GIF खोज Tor से होकर Kryfo के सर्वर से जाती है। $brand आपको कभी नहीं देखता। चालू करें?';
  }

  @override
  String gifAskThroughKryfo(String brand) {
    return 'GIF खोज सीधे Kryfo के सर्वर तक जाती है, जो तेज़ पर आपका IP पता देखता है। $brand आपको कभी नहीं देखता। चालू करें?';
  }

  @override
  String get gifAskTurnOn => 'चालू करें';

  @override
  String get gifSearchOff => 'GIF खोज बंद है';

  @override
  String get gifSavedOnPhone => 'आपके फ़ोन पर सेव GIF *इस फ़ोन पर* में हैं।';

  @override
  String get gifSavedOnPhoneDesk =>
      'आपके कंप्यूटर पर सेव GIF *इस कंप्यूटर पर* में हैं।';

  @override
  String get gifTab => 'GIF';

  @override
  String get gifPhoneTab => 'इस फ़ोन पर';

  @override
  String get gifPhoneTabDesk => 'इस कंप्यूटर पर';

  @override
  String get gifSearchHint => 'GIF खोजें';

  @override
  String get gifClear => 'खोज साफ़ करें';

  @override
  String get gifServiceNeverSeesYou => 'GIF सेवा आपको कभी नहीं देखती';

  @override
  String get gifTrending => 'चर्चित';

  @override
  String get gifOffline => 'Tor अभी जुड़ रहा है। उसके चालू होते ही GIF आएँगे।';

  @override
  String get gifBusy =>
      'अभी बहुत ज़्यादा खोजें हो रही हैं। थोड़ी देर में फिर कोशिश करें।';

  @override
  String get gifUnreachable => 'Kryfo की GIF सेवा तक नहीं पहुँच पाए।';

  @override
  String get gifNothingFound => 'कोई GIF नहीं मिला। दूसरे शब्द आज़माएँ।';

  @override
  String get gifCouldNotLoadMore => 'और लोड नहीं हो पाए';

  @override
  String get gifLoading => 'GIF लोड हो रहे हैं';

  @override
  String get gifCouldNotGet => 'वह GIF नहीं मिल पाया। दोबारा कोशिश करें।';

  @override
  String gifPoweredBy(String brand) {
    return 'Powered by $brand';
  }

  @override
  String gifNeverSeesYou(String brand) {
    return 'Kryfo के ज़रिए खोजा गया, $brand आपको कभी नहीं देखता।';
  }

  @override
  String gifTileA11y(String number) {
    return 'GIF $number';
  }

  @override
  String get gifPhoneLine => 'इस फ़ोन पर सेव GIF। कुछ भी ऑनलाइन नहीं जाता।';

  @override
  String get gifPhoneLineDesk =>
      'इस कंप्यूटर पर सेव GIF। कुछ भी ऑनलाइन नहीं जाता।';

  @override
  String get gifPhoneChoose => 'GIF चुनें';

  @override
  String get settingsGifSearch => 'GIF खोज';

  @override
  String get settingsGifSearchHint =>
      'जब तक आप चालू न करें, बंद रहती है। Kryfo का सर्वर आपकी तरफ़ से खोजता है, इसलिए GIF सेवा आपको कभी नहीं देखती।';

  @override
  String get shareChooseChat => 'चैट चुनें';

  @override
  String get shareNoChats => 'अभी कोई चैट नहीं';

  @override
  String get shareNoOne => 'शेयर करने के लिए कोई नहीं';

  @override
  String get shareCheckPhoto => 'यह फ़ोटो जाँचें';

  @override
  String get shareCheckVideo => 'यह वीडियो जाँचें';

  @override
  String get shareSendCleanLine => 'इसकी छिपी जानकारी पहले हटती है';

  @override
  String get shareCheckLine => 'देखें इसमें क्या है, इसी फ़ोन पर';

  @override
  String shareFileOverLimit(String max) {
    return 'फ़ाइलें $max तक की हो सकती हैं। यह उससे बड़ी है।';
  }

  @override
  String shareSendFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ये $count फ़ाइलें भेजें?',
      one: 'यह फ़ाइल भेजें?',
    );
    return '$_temp0';
  }

  @override
  String sharePhotoTooBig(String size, String max) {
    return 'यह फ़ोटो $size की है। Kryfo $max तक की फ़ोटो तैयार करता है।';
  }

  @override
  String sharePhotoOverLimit(String size, String max) {
    return 'छोटी करने पर भी यह फ़ोटो $size की है। इस चैट में फ़ाइलें $max तक की हो सकती हैं।';
  }

  @override
  String get valveStillConnecting =>
      'अभी जुड़ रहा है… कनेक्शन लौटते ही आपके मैसेज चले जाएँगे।';

  @override
  String get valveCouldNotReconnect =>
      'Kryfo दोबारा नहीं जुड़ पाया। इसे फिर से शुरू करने से यह ठीक हो जाता है और आपके मैसेज बने रहते हैं।';

  @override
  String get valveRestartKryfo => 'Kryfo फिर से शुरू करें';

  @override
  String get updateAvailable => 'अपडेट उपलब्ध है';

  @override
  String updateReady(String version) {
    return 'Kryfo $version डाउनलोड के लिए तैयार है';
  }

  @override
  String get settingsCheckForUpdates => 'अपडेट देखें';

  @override
  String get settingsCheckForUpdatesHint =>
      'दिन में एक बार, Tor से। kryfo.app से सबसे नया वर्शन पूछता है और आपके बारे में कुछ नहीं भेजता।';

  @override
  String get settingsCheckNow => 'अभी जाँचें';

  @override
  String get settingsCheckNowBusy => 'जाँच हो रही है…';

  @override
  String get updateOpenPage => 'डाउनलोड पेज खोलें';

  @override
  String get updateNewest => 'आपके पास सबसे नया Kryfo है';

  @override
  String get updateCouldNotCheck => 'जाँच नहीं हो सकी। बाद में फिर कोशिश करें।';

  @override
  String get voiceDisguiseHere => 'यहाँ मेरी आवाज़ बदलें';

  @override
  String get chatBlockScreenshots => 'स्क्रीनशॉट रोकें';

  @override
  String get chatShotsWhenTheyUpdate =>
      'जब वे फ़ोन पर Kryfo का नया संस्करण इस्तेमाल करें, तब उपलब्ध';

  @override
  String get chatShotsWhenTheyUpdateDesk => 'Android के लिए Kryfo में उपलब्ध';

  @override
  String get chatShotsBothPhones =>
      'Kryfo दोनों फ़ोन पर इस चैट के स्क्रीनशॉट और स्क्रीन रिकॉर्डिंग रोकता है, और एक-दूसरे के मैसेज कॉपी, फ़ॉरवर्ड या सेव करना भी। यह उन ऐप को नहीं रोक सकता जिन्हें स्क्रीन पढ़ने की अनुमति है, न ही ऐसे फ़ोन या ऐप को जिसे इससे बचने के लिए बदला गया हो।';

  @override
  String get chatShotsBlocksBoth =>
      'दोनों फ़ोन पर स्क्रीनशॉट और स्क्रीन रिकॉर्डिंग रोकता है, और एक-दूसरे के मैसेज कॉपी, फ़ॉरवर्ड या सेव करना भी। यह उन ऐप को नहीं रोक सकता जिन्हें स्क्रीन पढ़ने की अनुमति है, न ही ऐसे फ़ोन या ऐप को जिसे इससे बचने के लिए बदला गया हो।';

  @override
  String get chatShotsBlockedHere => 'Kryfo इस चैट में स्क्रीनशॉट रोकता है';

  @override
  String get chatShotsMenuNote =>
      'इस चैट में उनके मैसेज कॉपी, फ़ॉरवर्ड और सेव करना बंद है';

  @override
  String get chatShotsKeptOpen =>
      'इस चैट में उनकी फ़ाइलें दूसरे ऐप में खोलना बंद है';

  @override
  String searchKeptMatches(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString नतीजे · देखने के लिए चैट खोलें',
      one: '$countString नतीजा · देखने के लिए चैट खोलें',
    );
    return '$_temp0';
  }

  @override
  String get savedKeptInChat =>
      'स्क्रीनशॉट रोकने वाली चैट से सेव किया गया · देखने के लिए चैट खोलें';

  @override
  String get roomShotsMenuNote =>
      'इस रूम में दूसरों के मैसेज कॉपी, फ़ॉरवर्ड और सेव करना बंद है';

  @override
  String get roomShotsKeptOpen =>
      'इस रूम में दूसरों की फ़ाइलें दूसरे ऐप में खोलना बंद है';

  @override
  String get chatShotsYouTurnedOn =>
      'आपने स्क्रीनशॉट रोकना चालू किया। एक-दूसरे के मैसेज कॉपी, फ़ॉरवर्ड और सेव करना भी बंद है।';

  @override
  String get chatShotsYouTurnedOff => 'आपने स्क्रीनशॉट रोकना बंद किया';

  @override
  String get chatNowPostQuantum =>
      'इस चैट के मैसेज अब पोस्ट-क्वांटम एन्क्रिप्शन से सुरक्षित हैं';

  @override
  String chatShotsTheyTurnedOn(String name) {
    return '$name ने स्क्रीनशॉट रोकना चालू किया। एक-दूसरे के मैसेज कॉपी, फ़ॉरवर्ड और सेव करना भी बंद है।';
  }

  @override
  String chatShotsTheyTurnedOff(String name) {
    return '$name ने स्क्रीनशॉट रोकना बंद किया';
  }

  @override
  String get roomShotsBlocked =>
      'Kryfo इस रूम के हर फ़ोन पर इसके स्क्रीनशॉट और स्क्रीन रिकॉर्डिंग रोकता है, और एक-दूसरे के मैसेज कॉपी, फ़ॉरवर्ड या सेव करना भी। यह उन ऐप को नहीं रोक सकता जिन्हें स्क्रीन पढ़ने की अनुमति है, न ही ऐसे फ़ोन या ऐप को जिसे इससे बचने के लिए बदला गया हो।';

  @override
  String get roomShotsBlockedDesk =>
      'इस रूम में एक-दूसरे के मैसेज कॉपी, फ़ॉरवर्ड और सेव करना बंद है। Android के लिए Kryfo स्क्रीनशॉट और स्क्रीन रिकॉर्डिंग भी रोकता है।';

  @override
  String get roomShotsAlwaysOn => 'रूम में हमेशा चालू, उसके हर फ़ोन पर';

  @override
  String get roomShotsAlwaysOnDesk =>
      'रूम में हमेशा चालू, Android के लिए Kryfo में';

  @override
  String get homeShotsPerChat => 'स्क्रीनशॉट रोकना अब हर चैट के लिए अलग है।';

  @override
  String get homeShotsTurnOnForAll => 'इसे अपनी सभी चैट के लिए चालू करें?';

  @override
  String get homeShotsTurnOn => 'सबके लिए चालू करें';

  @override
  String get homeShotsLeaveOff => 'बंद रहने दें';

  @override
  String get homeShotsTheySeeIt =>
      'Kryfo दूसरे फ़ोन पर भी इन्हें रोकता है, और एक-दूसरे के मैसेज कॉपी, फ़ॉरवर्ड और सेव करना बंद हो जाता है। उन्हें दिखेगा कि आपने इसे चालू किया।';

  @override
  String homeShotsTurnedOn(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Kryfo अब $countString चैट में स्क्रीनशॉट रोकता है',
      one: 'Kryfo अब $countString चैट में स्क्रीनशॉट रोकता है',
    );
    return '$_temp0';
  }

  @override
  String get voiceDisguisedHere => 'इस चैट में आपकी आवाज़ बदली हुई है';

  @override
  String get voiceSlideUpToLock => 'लॉक करने के लिए ऊपर खिसकाएँ';

  @override
  String get voiceStopRecording => 'रिकॉर्डिंग रोकें';

  @override
  String get voiceDeleteNote => 'वॉइस नोट डिलीट करें';

  @override
  String get voiceDisguised => 'बदली हुई';

  @override
  String get voiceYourVoice => 'आपकी आवाज़';

  @override
  String get voiceDisguiseThisNote => 'इस नोट की आवाज़ बदलें';

  @override
  String get voiceNotDisguised =>
      'इस नोट की आवाज़ नहीं बदली जा सकी, इसलिए इसे नहीं भेजा गया';

  @override
  String get voiceNoRoom =>
      'इस फ़ोन पर पर्याप्त ख़ाली जगह नहीं है। थोड़ी जगह ख़ाली करें और दोबारा कोशिश करें।';

  @override
  String get voiceNoRoomDesk =>
      'इस कंप्यूटर पर पर्याप्त ख़ाली जगह नहीं है। थोड़ी जगह ख़ाली करें और दोबारा कोशिश करें।';

  @override
  String get voiceNoRoomNotSent =>
      'इस नोट की आवाज़ बदलने के लिए पर्याप्त ख़ाली जगह नहीं थी, इसलिए इसे नहीं भेजा गया';

  @override
  String get voiceDisguising => 'आवाज़ बदल रहे हैं';

  @override
  String get voiceLockedNotSent =>
      'आपका वॉइस नोट जाने से पहले Kryfo लॉक हो गया, इसलिए वह नहीं भेजा गया';

  @override
  String get voiceNotSent => 'आपका वॉइस नोट नहीं भेजा गया';

  @override
  String get settingsDisguiseByDefault => 'मेरी आवाज़ पहले से ही बदलें';

  @override
  String get settingsDisguiseByDefaultHint =>
      'हर चैट अपने मेन्यू में इसे बदल सकती है';

  @override
  String get fileInstallerLine =>
      'यह एक ऐप इंस्टॉलर है। सिर्फ़ भरोसेमंद लोगों से मिले ऐप ही इंस्टॉल करें।';

  @override
  String get fileAppInstaller => 'ऐप इंस्टॉलर';

  @override
  String get fileSaveToDevice => 'डिवाइस में सेव करें';

  @override
  String get fileOpenHint => 'दूसरे ऐप में खुलता है';

  @override
  String get fileSaved => 'सेव हो गया';

  @override
  String fileSavedIn(String place) {
    return '$place में सेव हुआ';
  }

  @override
  String get fileSavedUnchecked =>
      'सेव हो गया, पर Kryfo कॉपी की जाँच नहीं कर पाया';

  @override
  String get fileNotSaved => 'फ़ाइल सेव नहीं हो पाई';

  @override
  String get fileNotSavedNoSpace => 'सेव नहीं हुआ: वहाँ पर्याप्त जगह नहीं है';

  @override
  String fileTooBig(String size, String max) {
    return 'यह फ़ाइल $size की है। फ़ाइलें ज़्यादा से ज़्यादा $max की हो सकती हैं।';
  }

  @override
  String get fileGoesAsItIs =>
      'यह फ़ाइल बिल्कुल जैसी है वैसी जाती है। Kryfo सिर्फ़ JPEG, PNG, WebP, HEIC, AVIF, GIF, MP4 और MOV साफ़ करता है।';

  @override
  String get voiceStoppedAtLimit =>
      'वॉइस नोट 30 मिनट पर रुक जाते हैं। इसे सुनें, फिर भेजें।';

  @override
  String get gettingMessagesHelperBody =>
      'इसका सर्वर आपका IP पता और मैसेज आने का समय देखता है।\nयह कभी नहीं कि उनमें क्या है। तुरंत और हल्का।';

  @override
  String get gettingMessagesHelperUseOnion => 'Onion पर जाएँ';

  @override
  String get gettingMessagesHelperSetUp => 'सेट करें';

  @override
  String get gettingMessagesHelperNote =>
      'इसमें झूठे जगाने के संकेत भी मिलाए जाते हैं, जिससे सहायक के सर्वर के लिए यह बताना मुश्किल होता है कि असली मैसेज कब आते हैं। आपका अपना सहायक सर्वर हमारे रिले को अपना पता बताता है। छिपी चैट, शुरुआती कुछ के बाद के रूम, और कभी-कभी कोई आम संपर्क, लगभग पाँच में से एक महीने, उस जाँच का इंतज़ार करते हैं जो Kryfo अब भी हर 15 मिनट में करता है।';

  @override
  String get gettingMessagesHelperOnionOnly => 'प्राइवेट रास्ता चाहिए';

  @override
  String get gettingMessagesHelperChecking => 'जाँच हो रही है…';

  @override
  String get gettingMessagesHelperRelayNotYet => 'हमारा रिले अभी यह नहीं देता';

  @override
  String get helperSheetNeedTitle => 'आपको एक सहायक ऐप चाहिए';

  @override
  String get helperSheetNeedLine =>
      'सहायक ऐप आपके सभी ऐप के लिए एक हल्का कनेक्शन रखता है और कुछ आने पर Kryfo को जगाता है। कोई भी UnifiedPush सहायक काम करता है, ntfy से शुरुआत अच्छी है।';

  @override
  String get helperSheetGetNtfy => 'ntfy लें';

  @override
  String get helperSheetOtherApps => 'दूसरे सहायक ऐप';

  @override
  String get helperSheetPickTitle => 'सहायक ऐप चुनें';

  @override
  String get helperSheetPickLine =>
      'Kryfo इससे सिर्फ़ ऐप जगाने को कहता है। आपके मैसेज कभी इससे होकर नहीं जाते।';

  @override
  String helperSheetSetUp(Object name) {
    return '$name सेट हो गया';
  }

  @override
  String helperSheetNoAnswer(Object name) {
    return '$name ने जवाब नहीं दिया। दोबारा कोशिश करें।';
  }

  @override
  String get homeHelperGoneTitle => 'आपका सहायक ऐप हट गया है';

  @override
  String get homeHelperGoneLine =>
      'जब तक आप कोई दूसरा तरीक़ा न चुनें, Kryfo हर 15 मिनट में जाँच करता है।';

  @override
  String get homeHelperGoneChoose => 'दूसरा तरीक़ा चुनें';

  @override
  String get homeHelperRelayTitle => 'रिले ने Kryfo को जगाना बंद कर दिया';

  @override
  String get gettingMessagesHelperRefused =>
      'हमारा रिले अभी इस फ़ोन के कुछ रजिस्ट्रेशन नहीं ले रहा। वे चैट हर 15 मिनट की जाँच के साथ आती हैं, और Kryfo कोशिश करता रहता है। कोई दूसरा सहायक ऐप या सर्वर चुनने से भी मदद मिल सकती है।';

  @override
  String albumLabel(Object count) {
    return 'एल्बम, $count आइटम';
  }

  @override
  String albumCounter(Object at, Object total) {
    return '$total में से $at';
  }

  @override
  String albumMore(Object count) {
    return '$count और';
  }

  @override
  String get albumOnItsWay => 'रास्ते में';

  @override
  String get albumQuoted => 'एल्बम';

  @override
  String get albumUnsendTitle => 'यह एल्बम वापस लें?';

  @override
  String get mediaSendAddMore => 'और जोड़ें';

  @override
  String get mediaSendRemove => 'हटाएँ';

  @override
  String get mediaSendProtect => 'स्क्रीनशॉट से बचाएँ';

  @override
  String get mediaSendProtectedOn => 'सुरक्षित · स्क्रीनशॉट रुके हुए हैं';

  @override
  String mediaSendUpTo(Object count) {
    return 'एक बार में अधिकतम $count';
  }

  @override
  String get mediaSendVideo => 'वीडियो भेजें';

  @override
  String get requestSenderMediaLater =>
      'उनके स्वीकार करने के बाद फ़ोटो और फ़ाइलें खुलती हैं, ताकि आप दोनों सुरक्षित रहें।';

  @override
  String get requestReceiverMediaLater =>
      'आपके स्वीकार करने के बाद फ़ोटो और फ़ाइलें खुलती हैं, ताकि आप सुरक्षित रहें।';

  @override
  String get groupEndedYou => 'आपने यह ग्रुप ख़त्म किया';

  @override
  String groupEndedBy(Object name) {
    return '$name ने यह ग्रुप ख़त्म किया';
  }

  @override
  String get groupEndedBar => 'यह ग्रुप ख़त्म हो गया है';

  @override
  String get groupInfoEndGroup => 'ग्रुप ख़त्म करें';

  @override
  String get groupInfoEndThisGroup => 'यह ग्रुप सबके लिए ख़त्म करें?';

  @override
  String get groupInfoEndGroupLine =>
      'यह सबके लिए डिलीट हो जाता है: इसके मैसेज और मीडिया हर अपडेट किए हुए सदस्य के फ़ोन से हट जाते हैं।';

  @override
  String get groupInfoEndGroupLineDesk =>
      'यह सबके लिए डिलीट हो जाता है: इसके मैसेज और मीडिया हर अपडेट किए हुए सदस्य के डिवाइस से हट जाते हैं।';

  @override
  String get groupInfoDeleteGroup => 'ग्रुप डिलीट करें';

  @override
  String get groupInfoDeleteThisGroup => 'यह ग्रुप डिलीट करें?';

  @override
  String get groupInfoDeleteGroupLine =>
      'ख़त्म हुआ ग्रुप आपकी चैट सूची से हट जाएगा।';

  @override
  String get groupEndedOldNotice =>
      'मैंने यह ग्रुप ख़त्म कर दिया है, इसलिए अब इसमें कोई मैसेज नहीं भेज सकता। इसे ख़त्म हुआ देखने के लिए Kryfo अपडेट करें।';

  @override
  String get groupInfoEndGroupDetail =>
      'Kryfo इसे हर उस सदस्य के फ़ोन से हटाता है जिसके पास अपडेट है।';

  @override
  String get groupInfoEndGroupDetailDesk =>
      'Kryfo इसे हर उस सदस्य के डिवाइस से हटाता है जिसके पास अपडेट है।';

  @override
  String get translateAction => 'अनुवाद करें';

  @override
  String get translateShowOriginal => 'मूल दिखाएँ';

  @override
  String translateBarTo(Object language) {
    return '$language में अनुवाद करें';
  }

  @override
  String get translateBarMore => 'अनुवाद के विकल्प';

  @override
  String translateBarNever(Object language) {
    return '$language के लिए कभी न सुझाएँ';
  }

  @override
  String get translateBarHide => 'इस चैट में छिपाएँ';

  @override
  String get translateWorking => 'अनुवाद हो रहा है…';

  @override
  String get translateFailed => 'अनुवाद नहीं हो पाया';

  @override
  String translateFrom(Object language) {
    return '$language से अनुवाद किया गया';
  }

  @override
  String get translateLangZh => 'चीनी';

  @override
  String translatePackTitle(Object language) {
    return '$language का अनुवाद इसी फ़ोन पर करें';
  }

  @override
  String translatePackTitleDesk(Object language) {
    return '$language का अनुवाद इसी कंप्यूटर पर करें';
  }

  @override
  String translatePackLine(Object language, Object size) {
    return 'मैसेज इसी फ़ोन पर अनुवाद होते हैं और कभी इससे बाहर नहीं जाते। इसके लिए $language भाषा पैक चाहिए, लगभग $size, जो एक बार Tor से डाउनलोड होता है।';
  }

  @override
  String translatePackLineDesk(Object language, Object size) {
    return 'मैसेज इसी कंप्यूटर पर अनुवाद होते हैं और कभी इससे बाहर नहीं जाते। इसके लिए $language भाषा पैक चाहिए, लगभग $size, जो एक बार Tor से डाउनलोड होता है।';
  }

  @override
  String get translatePackNoLib => 'इस फ़ोन पर अनुवाद काम नहीं करता।';

  @override
  String get translatePackNoLibDesk => 'इस कंप्यूटर पर अनुवाद काम नहीं करता।';

  @override
  String translateDownload(Object size) {
    return 'डाउनलोड करें · लगभग $size';
  }

  @override
  String get translateDownloadAnyway => 'फिर भी अभी डाउनलोड करें';

  @override
  String get translateResume => 'डाउनलोड फिर शुरू करें';

  @override
  String translateProgress(Object done, Object total) {
    return '$total में से $done';
  }

  @override
  String get translateFinishing => 'फ़ाइलें जाँची जा रही हैं…';

  @override
  String translateInstalled(Object size) {
    return 'इस फ़ोन पर · $size';
  }

  @override
  String translateInstalledDesk(Object size) {
    return 'इस कंप्यूटर पर · $size';
  }

  @override
  String get translateNeedsWifi =>
      'सिर्फ़ Wi-Fi चालू है, और यह फ़ोन Wi-Fi पर नहीं है।';

  @override
  String get translateNeedsWifiDesk =>
      'सिर्फ़ Wi-Fi चालू है, और यह कंप्यूटर Wi-Fi पर नहीं है।';

  @override
  String get translateFailNoTor =>
      'Tor अभी नहीं जुड़ा है। पैक सिर्फ़ Tor से डाउनलोड होते हैं, इसलिए उसके जुड़ने पर फिर कोशिश करें।';

  @override
  String get translateFailNetwork =>
      'डाउनलोड रुक गया। फिर कोशिश करें, यह वहीं से शुरू होगा जहाँ रुका था।';

  @override
  String get translateFailBadFile =>
      'एक फ़ाइल वैसी नहीं थी जैसी Kryfo को चाहिए, इसलिए उसे हटा दिया गया। दोबारा कोशिश करें।';

  @override
  String get translateFailNoEngine =>
      'इस फ़ोन पर भाषा पैक डाउनलोड नहीं हो सकते।';

  @override
  String get translateFailNoEngineDesk =>
      'इस कंप्यूटर पर भाषा पैक डाउनलोड नहीं हो सकते।';

  @override
  String translatePaused(Object size) {
    return 'रुका हुआ · अब तक $size';
  }

  @override
  String get translateSettingsTitle => 'अनुवाद';

  @override
  String get translateSettingsRow => 'मैसेज का अनुवाद करें';

  @override
  String get translateSettingsHint => 'इसी फ़ोन पर, कभी किसी सर्वर पर नहीं';

  @override
  String get translateSettingsHintDesk =>
      'इसी कंप्यूटर पर, कभी किसी सर्वर पर नहीं';

  @override
  String get translatePacksSection => 'भाषा पैक';

  @override
  String translateNotDownloaded(Object size) {
    return 'डाउनलोड नहीं हुआ · लगभग $size';
  }

  @override
  String get translateDownloading => 'Tor से डाउनलोड हो रहा है';

  @override
  String get translateLanguagesSection => 'भाषाएँ';

  @override
  String get translateMyLanguages => 'मुझे आने वाली भाषाएँ';

  @override
  String get translateMyLanguagesHint =>
      'इनमें आए मैसेज के अनुवाद का सुझाव नहीं दिया जाता। ऐप की भाषा हमेशा इनमें से एक होती है।';

  @override
  String get translateInto => 'किस भाषा में अनुवाद करें';

  @override
  String get translateAppLanguage => 'ऐप की भाषा';

  @override
  String get translateBehaviourSection => 'डाउनलोड और चैट';

  @override
  String get translateAutoDefault => 'चैट का अपने-आप अनुवाद करें';

  @override
  String get translateAutoDefaultHint =>
      'उन चैट के लिए जिन्हें आपने ख़ुद सेट नहीं किया। हर चैट इसे चालू या बंद कर सकती है।';

  @override
  String get translateWifiOnly => 'पैक सिर्फ़ Wi-Fi पर डाउनलोड करें';

  @override
  String get translatePrivacyTitle => 'क्या निजी रहता है';

  @override
  String get translatePrivacyNote =>
      'अनुवाद इसी फ़ोन पर होता है। अनुवाद के लिए कोई भी मैसेज कभी कहीं नहीं भेजा जाता। पैक डाउनलोड करने पर होस्ट को पता चलता है कि कौन सा पैक है। यह Tor से आता है, इसलिए होस्ट को यह पता नहीं चलता कि किसने माँगा।';

  @override
  String get translatePrivacyNoteDesk =>
      'अनुवाद इसी कंप्यूटर पर होता है। अनुवाद के लिए कोई भी मैसेज कभी कहीं नहीं भेजा जाता। पैक डाउनलोड करने पर होस्ट को पता चलता है कि कौन सा पैक है। यह Tor से आता है, इसलिए होस्ट को यह पता नहीं चलता कि किसने माँगा।';

  @override
  String get translateAutoInChat => 'अपने-आप अनुवाद करें';

  @override
  String get translateAutoInChatHint =>
      'दूसरी भाषाओं के मैसेज अनुवाद होकर दिखते हैं। मूल बस एक टैप दूर है।';

  @override
  String get translateAlwaysChat => 'इस चैट का हमेशा अनुवाद करें';

  @override
  String translateNeverDone(Object language) {
    return '$language के संदेश जैसे हैं वैसे ही रहेंगे';
  }

  @override
  String get translateUndo => 'वापस लें';

  @override
  String get translateNeverSection => 'कभी नहीं सुझाई जातीं';

  @override
  String get translateOfferAllAgain => 'सभी फिर से सुझाएँ';

  @override
  String get translateOfferAgain => 'फिर से सुझाएँ';

  @override
  String get translateOnHint =>
      'दूसरी भाषाओं के संदेशों के नीचे सुझाया जाता है';

  @override
  String get translatePrivacyKept =>
      'अनुवाद इस फ़ोन पर अपनी चैट के साथ एन्क्रिप्ट होकर रखे जाते हैं और उसी के साथ मिटते हैं।';

  @override
  String get translatePrivacyKeptDesk =>
      'अनुवाद इस कंप्यूटर पर अपनी चैट के साथ एन्क्रिप्ट होकर रखे जाते हैं और उसी के साथ मिटते हैं।';

  @override
  String get translateOffDeletes =>
      'इसे बंद करने पर सहेजे गए अनुवाद मिट जाते हैं।';

  @override
  String get bridgesNoneUntilOnion => 'onion चालू होने तक कोई नहीं';

  @override
  String get bridgesRelayThisNetworkSees =>
      'जहाँ Tor रुका हो, वहाँ भी तेज़ पहुँच जाता है, पर यह नेटवर्क देख सकता है कि आप Kryfo से जुड़ रहे हैं।';

  @override
  String get settingsLicences => 'लाइसेंस';

  @override
  String get settingsLicencesValue => 'Kryfo किन चीज़ों पर बना है';

  @override
  String get licencesKryfoLine =>
      'Kryfo मुफ़्त सॉफ़्टवेयर है, GNU General Public License, वर्शन 3 या उसके बाद के तहत। कोई भी इसका कोड पढ़, बदल और शेयर कर सकता है।';

  @override
  String get licencesSourceCode => 'सोर्स कोड';

  @override
  String get licencesSignalTitle => 'Signal प्रोटोकॉल';

  @override
  String licencesSignalLine(String version) {
    return 'Kryfo में Signal की बनाई libsignal $version है, GNU Affero General Public License, वर्शन 3 के तहत। इसका सोर्स कोड github.com/signalapp/libsignal पर और हर Kryfo रिलीज़ के साथ है।';
  }

  @override
  String get licencesAgplText => 'GNU AGPL 3.0, पूरा पाठ';

  @override
  String get licencesSignalSource => 'libsignal का सोर्स कोड';

  @override
  String get licencesParts => 'ओपन सोर्स हिस्से';

  @override
  String get licencesInSignal => 'Signal लाइब्रेरी में';

  @override
  String get licencesInApp => 'ऐप में';

  @override
  String licencesPartCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString हिस्से',
      one: '$countString हिस्सा',
    );
    return '$_temp0';
  }

  @override
  String get licencesGplText => 'GNU GPL 3.0, पूरा पाठ';

  @override
  String get licencesInEngine => 'नेटवर्क इंजन में';

  @override
  String get licencesLoadFailed => 'लोड नहीं हो पाया';

  @override
  String get licencesInVoice => 'आवाज़ से लिखित में';

  @override
  String get licencesInTranslation => 'मैसेज के अनुवाद में';

  @override
  String get settingsCopyLinkHint => 'लिंक कॉपी करें';

  @override
  String get motionNoRelayYet => 'अभी कोई रिले नहीं';

  @override
  String get motionTheRouteIsUp => 'रास्ता तैयार है';

  @override
  String get motionMessagesGoOnceARelay =>
      'इस रास्ते से कोई रिले जवाब देते ही मैसेज चले जाएँगे।';

  @override
  String get motionOffline => 'ऑफ़लाइन';

  @override
  String get motionNoNetwork => 'कोई नेटवर्क नहीं';

  @override
  String get motionTorPicksUpAgain =>
      'नेटवर्क के बिना कुछ नहीं जाता। नेटवर्क लौटते ही Tor फिर शुरू हो जाता है।';

  @override
  String deliveryModeStateLast(String state, Object last) {
    return '$state · $last';
  }

  @override
  String homeWaitingState(int count, String state) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count इंतज़ार में · $state',
    );
    return '$_temp0';
  }

  @override
  String get settingsIconAndNotifications => 'आइकन और सूचनाएँ';

  @override
  String iconSettingsValue(String icon) {
    return '$icon, सादी सूचनाएँ';
  }

  @override
  String get iconSectionTitle => 'ऐप आइकन';

  @override
  String get iconHint =>
      'आपकी होम स्क्रीन और ऐप सूची में Kryfo की जगह यह आइकन और नाम दिखता है।';

  @override
  String get iconHintKryfo =>
      'अपनी होम स्क्रीन और ऐप सूची के लिए कोई आम आइकन और नाम चुनें।';

  @override
  String get iconWhatChanges => 'इससे क्या बदलता है';

  @override
  String iconConfirmTitle(String name) {
    return 'आइकन बदलकर $name करें?';
  }

  @override
  String iconConfirmLine(String name) {
    return 'Kryfo बंद होकर फिर खुलेगा। अगर आइकन आपकी होम स्क्रीन से हट जाए, तो अपने ऐप में $name ढूँढकर फिर से रखें।';
  }

  @override
  String get iconConfirmButton => 'आइकन बदलें';

  @override
  String get iconNoPinLine =>
      'जो भी इस पर टैप करेगा, वह Kryfo देखेगा। ऐप PIN सेट करें, ताकि उन्हें इसके बजाय PIN पैड दिखे।';

  @override
  String get iconSetPin => 'PIN सेट करें';

  @override
  String iconChanged(String name) {
    return 'आइकन बदलकर $name हुआ';
  }

  @override
  String iconPreviewLabel(String name) {
    return 'आपकी होम स्क्रीन पर $name दिखेगा';
  }

  @override
  String iconButtonLabel(String name) {
    return '$name, ऐप आइकन';
  }

  @override
  String get notifShowAll => 'नाम और मैसेज';

  @override
  String get notifShowNew => 'सिर्फ़ “नया मैसेज”';

  @override
  String get notifShowPlain => 'सादा';

  @override
  String get notifPlainHint =>
      'न नाम, न मैसेज, न Kryfo के रंग। एक सामान्य आइकन और एक लाइन।';

  @override
  String get notifPlainLine => 'कुछ नया';

  @override
  String get notifPlainChannel => 'अलर्ट';

  @override
  String get notifHeaderLimit =>
      'हर सूचना के ऊपर अब भी Kryfo लिखा रहता है। Android किसी ऐप को इसे बदलने नहीं देता।';

  @override
  String get gettingMessagesWhatShows => 'सूचनाएँ क्या दिखाती हैं';

  @override
  String get iconSheetChangesTitle => 'क्या बदलता है';

  @override
  String get iconSheetChanges =>
      'आपकी होम स्क्रीन, ऐप सूची, शेयर मेन्यू और ऐप स्विचर में आइकन और नाम। सादा चुनने पर, सूचनाएँ क्या दिखाती हैं।';

  @override
  String get iconSheetStaysTitle => 'क्या Kryfo ही रहता है';

  @override
  String get iconSheetStays =>
      'हर सूचना की सबसे ऊपर वाली लाइन, आपके फ़ोन की सेटिंग और बैटरी वाले पेज, ऐप स्टोर, और ख़ुद Kryfo जब कोई उसे खोले।';

  @override
  String get iconSheetGlance =>
      'यह आपकी होम स्क्रीन पर एक सरसरी नज़र तक ही टिकता है। यह Kryfo को उस व्यक्ति से नहीं छिपाता जो आपके फ़ोन की सेटिंग खंगाले।';

  @override
  String get iconSheetPrivateSpace =>
      'आपके फ़ोन में ऐप छिपाने का अपना तरीक़ा हो सकता है: इसकी सेटिंग में private space।';

  @override
  String get iconSheetSecureFolder =>
      'आपके फ़ोन में ऐप छिपाने का अपना तरीक़ा हो सकता है: इसकी सेटिंग में Secure Folder।';

  @override
  String get iconSheetXiaomi =>
      'आपके फ़ोन में ऐप छिपाने का अपना तरीक़ा हो सकता है: इसकी सेटिंग में hidden apps।';

  @override
  String get androidIconNotes => 'नोट्स';

  @override
  String get androidIconWeather => 'मौसम';

  @override
  String get androidIconTasks => 'काम';

  @override
  String get androidIconNews => 'ख़बरें';

  @override
  String get androidServiceTitlePlain => 'सक्रिय';

  @override
  String get lockStateUnlockPlain => 'अनलॉक करें';

  @override
  String get iconSheetOthers =>
      'आपके फ़ोन के ऐप अब भी देख सकते हैं कि Kryfo इंस्टॉल है, और Android के अपने डायलॉग और संकेत इसका नाम दिखा सकते हैं।';

  @override
  String get iconSheetSaves =>
      'जब तक सादा आइकन चालू है, नई फ़ोटो, वीडियो और फ़ाइलें आम नामों से आपके फ़ोन के सामान्य फ़ोल्डरों में सेव होती हैं। पहले सेव हुई चीज़ें जहाँ हैं वहीं रहती हैं।';

  @override
  String get deliveryModeGooglePush => 'Google पुश';

  @override
  String get deliveryModeGoogle => 'Google';

  @override
  String get notificationsLead =>
      'नए मैसेज इस फ़ोन तक कैसे पहुँचते हैं, कैसी आवाज़ करते हैं और क्या दिखाते हैं। आप जब चाहें इसे बदल सकते हैं।';

  @override
  String get notificationsLeadDesk =>
      'नए मैसेज इस कंप्यूटर तक कैसे पहुँचते हैं, कैसी आवाज़ करते हैं और क्या दिखाते हैं। आप जब चाहें इसे बदल सकते हैं।';

  @override
  String get notificationsHowTheyReachYou => 'मैसेज आप तक कैसे पहुँचते हैं';

  @override
  String get notificationsRecommended => 'सुझाया गया';

  @override
  String get notificationsGoogleBody =>
      'Google देख सकता है कि आपका फ़ोन कब जागता है।\nयह कभी नहीं कि किसने लिखा या क्या कहा।\nतुरंत और बैटरी पर हल्का।';

  @override
  String get notificationsGoogleOnFast =>
      'तेज़ पर, आपका फ़ोन जगाते समय हमारे सर्वर आपका IP देखते हैं, पर हम उसे कभी नहीं रखते।';

  @override
  String get notificationsGoogleStarting => 'चालू हो रहा है…';

  @override
  String get notificationsGoogleNoStart =>
      'Google पुश शुरू नहीं हो पाया। कनेक्शन जाँचें और दोबारा कोशिश करें।';

  @override
  String get notificationsGoogleNote =>
      'इसमें झूठे जगाने के संकेत भी मिलाए जाते हैं, जिससे Google के लिए यह बताना मुश्किल होता है कि असली मैसेज कब आते हैं। हमारा रिले सिर्फ़ ऐसे पते रखता है जिन्हें वह आपस में जोड़ नहीं सकता। पुश सेवा हमारे दूसरे सर्वर पर चलती है। दोनों सर्वर मिलकर उन्हें जोड़ सकते हैं, और Google की मदद से आपके Google अकाउंट तक भी। किसी एक को ज़ब्त करना काफ़ी नहीं है, पर दोनों हम चलाते हैं, इसलिए हम ऐसा कर सकते हैं। अगर यह आपके लिए मायने रखता है, तो कोई दूसरा तरीक़ा चुनें। छिपी चैट, शुरुआती कुछ के बाद के रूम, और कभी-कभी कोई आम संपर्क, लगभग पाँच में से एक महीने, उस जाँच का इंतज़ार करते हैं जो Kryfo अब भी हर 15 मिनट में करता है।';

  @override
  String get notificationsGoogleRefused =>
      'हमारा रिले अभी इस फ़ोन के कुछ रजिस्ट्रेशन नहीं ले रहा। वे चैट हर 15 मिनट की जाँच के साथ आती हैं, और Kryfo कोशिश करता रहता है।';

  @override
  String get notificationsSoundAndVibration => 'आवाज़ और वाइब्रेशन';

  @override
  String get notificationsSoundHint => 'Android की अपनी सेटिंग में सेट करें';

  @override
  String get notificationsEachShows => 'हर सूचना दिखाती है';

  @override
  String get notificationsBatteryTips => 'बैटरी के सुझाव';

  @override
  String get notificationsBatteryAllowed => 'अनुमति है';

  @override
  String get notificationsBatteryNotYet => 'अनुमति नहीं';

  @override
  String get notificationsMakerSwitch => 'आपके फ़ोन बनाने वाली कंपनी का स्विच';

  @override
  String get onboardingHowYourMessages => 'आपके मैसेज कैसे *सफ़र* करते हैं।';

  @override
  String get onboardingRouteLead => 'आप इसे कभी भी सेटिंग में बदल सकते हैं।';

  @override
  String get onboardingRoutePrivateCost =>
      'Tor के ज़रिए। एक मैसेज में कुछ सेकंड लगते हैं।';

  @override
  String get onboardingRoutePrivateGain =>
      'आपका IP पता कोई नहीं जान पाता, हमारे सर्वर भी नहीं।';

  @override
  String get onboardingRouteFastCost =>
      'जब आप जुड़े होते हैं, हमारे सर्वर आपका IP पता देखते हैं।\nआपका नेटवर्क देख सकता है कि आप Kryfo इस्तेमाल करते हैं।';

  @override
  String get onboardingRouteFastGain =>
      'Tor को छोड़ देता है: तेज़ और बैटरी पर हल्का।';

  @override
  String get onboardingRouteBlockedLead =>
      'Kryfo Tor पर ही रहता है, ज़रूरत हो तो ब्रिज के ज़रिए।\nतेज़ आपको सेटिंग में मिलेगा, अगर चाहिए।';

  @override
  String get onboardingRouteBlockedGain =>
      'रोक के आसपास रास्ता ख़ुद ढूँढ लेता है।';

  @override
  String get onboardingDeliveryHeadline => 'मैसेज कब *पहुँचते* हैं।';

  @override
  String get onboardingDeliveryLead =>
      'आप इसे कभी भी सूचनाएँ में बदल सकते हैं।';

  @override
  String get homeGoogleTitle => 'Google पुश आ गया है';

  @override
  String get homeGoogleLine =>
      'तुरंत, और बैटरी पर हल्का। Google देख सकता है कि आपका फ़ोन कब जगाया गया, यह कभी नहीं कि किसने लिखा या क्या कहा।';

  @override
  String get homeGoogleUse => 'इस्तेमाल करें';

  @override
  String get homeGoogleOn => 'Google पुश चालू है';

  @override
  String get homeGoogleGoneTitle => 'Google पुश उपलब्ध नहीं है';

  @override
  String get appNotificationsLink => 'सूचनाएँ →';

  @override
  String devGooglePushes(int got, int low) {
    return 'Google पुश $got · घटाए गए $low';
  }

  @override
  String get passFieldLabel => 'पासफ़्रेज़';

  @override
  String get padUseLetters => 'अक्षर इस्तेमाल करें';

  @override
  String get padUseDigits => 'अंक इस्तेमाल करें';

  @override
  String get passWeak => 'कमज़ोर';

  @override
  String get passFair => 'ठीक-ठाक';

  @override
  String get passStrong => 'मज़बूत';

  @override
  String passStrengthIs(Object level) {
    return 'मज़बूती: $level';
  }

  @override
  String get lockKeyBusy =>
      'फ़ोन की सुरक्षा चिप व्यस्त है। थोड़ी देर में फिर कोशिश करें।';

  @override
  String get lockKeyLocked =>
      'अपना फ़ोन एक बार उसके अपने PIN से अनलॉक करें, फिर दोबारा कोशिश करें।';

  @override
  String get lockKeyWaiting => 'अभी फ़ोन की सुरक्षा चिप से जाँच हो रही है';

  @override
  String get lockKeyLost =>
      'इस फ़ोन ने वह कुंजी खो दी जो आपके PIN जाँचती है, इसलिए हो सकता है कुछ PIN न खुलें। Kryfo को रीसेट करके बैकअप रीस्टोर किया जा सकता है।';

  @override
  String get lockKeyReset => 'Kryfo रीसेट करें';

  @override
  String get lockKeyResetTitle => 'Kryfo रीसेट करें?';

  @override
  String get lockKeyResetLine =>
      'इस फ़ोन पर Kryfo का सब कुछ डिलीट हो जाएगा और Kryfo बंद हो जाएगा। फिर आप बैकअप रीस्टोर कर सकते हैं। छिपी चैट सिर्फ़ उसी बैकअप से वापस आती हैं जो उनके खुले रहते बनाया गया हो।';

  @override
  String get lockKeyResetSureTitle => 'इसे पलटा नहीं जा सकता';

  @override
  String get lockKeyResetSureLine =>
      'इस फ़ोन पर Kryfo की सारी चैट, कुंजियाँ और सेटिंग अभी हट जाएँगी।';

  @override
  String get lockKeyResetSure => 'सब कुछ डिलीट करें';

  @override
  String get flowVaultPassLine =>
      'कम से कम 12 अक्षर। आप जो लिखते हैं, वह फ़ोन का कीबोर्ड देखता है, इसलिए ऐसा कीबोर्ड इस्तेमाल करें जो शब्द न सीखे और न सिंक करे।';

  @override
  String get flowVaultPassLineDesk =>
      'कम से कम 12 अक्षर। ऐसा इस्तेमाल करें जो आप कहीं और इस्तेमाल नहीं करते।';

  @override
  String get flowVaultPassAgain => 'वही पासफ़्रेज़ दोबारा';

  @override
  String get cardTitle => 'सुरक्षा अपडेट पूरा करें';

  @override
  String get cardLine =>
      'अगर आप दूसरे PIN इस्तेमाल करते हैं, तो उन्हें यहाँ एक बार लिखें।';

  @override
  String get cardType => 'PIN लिखें';

  @override
  String get cardAnswer =>
      'हो गया। एक और लिखें, या ख़त्म होने पर हो गया पर टैप करें।';

  @override
  String get keyLine =>
      'आपके PIN सिर्फ़ इसी फ़ोन पर काम करते हैं। अगर फ़ोन कभी वह कुंजी खो दे जो उन्हें जाँचती है, तो आपको Kryfo रीसेट करके बैकअप रीस्टोर करना होगा। छिपी चैट सिर्फ़ उसी बैकअप से वापस आती हैं जो उनके खुले रहते बनाया गया हो।';

  @override
  String get keyLineUnlocked =>
      'आपके PIN सिर्फ़ इसी फ़ोन पर काम करते हैं, और सिर्फ़ तब जब यह अनलॉक हो। अगर फ़ोन कभी वह कुंजी खो दे जो उन्हें जाँचती है, तो आपको Kryfo रीसेट करके बैकअप रीस्टोर करना होगा। छिपी चैट सिर्फ़ उसी बैकअप से वापस आती हैं जो उनके खुले रहते बनाया गया हो।';

  @override
  String get keyLineScreenLock =>
      'अपने फ़ोन पर स्क्रीन लॉक सेट करें, ताकि फ़ोन लॉक होने पर भी यह सुरक्षा बनी रहे।';

  @override
  String get fileServerTryLater =>
      'फ़ाइल सर्वर अभी भरा हुआ है। थोड़ी देर बाद फिर से कोशिश करें।';

  @override
  String fileTooBigUntilUpdate(String size, String max) {
    return 'यह फ़ाइल $size की है। जब तक इस चैट में सभी Kryfo अपडेट नहीं करते, यहाँ $max तक की फ़ाइलें जा सकती हैं।';
  }

  @override
  String get fileDayLimit =>
      'आज आपने बहुत सारी बड़ी फ़ाइलें भेज दी हैं। कल फिर से कोशिश करें।';

  @override
  String get mediaProgressPreparing => 'तैयार हो रहा है · ऐप खुला रखें';

  @override
  String get groupShotsBlocksAll =>
      'इस ग्रुप के हर फ़ोन पर स्क्रीनशॉट और स्क्रीन रिकॉर्डिंग रोकता है, और एक-दूसरे के मैसेज कॉपी, फ़ॉरवर्ड या सेव करना भी। यह उन ऐप को नहीं रोक सकता जिन्हें स्क्रीन पढ़ने की अनुमति है, न ही ऐसे फ़ोन या ऐप को जिसे इससे बचने के लिए बदला गया हो।';

  @override
  String get groupShotsBlocksAllDesk =>
      'यहाँ एक-दूसरे के मैसेज कॉपी, फ़ॉरवर्ड और सेव करना बंद करता है। Android के लिए Kryfo स्क्रीनशॉट और स्क्रीन रिकॉर्डिंग भी रोकता है।';

  @override
  String get groupShotsStartsWhenAll =>
      'इंतज़ार है कि यहाँ सब अपने डिवाइस पर स्क्रीनशॉट रोक सकें';

  @override
  String get groupShotsOnForAll => 'यहाँ सबके लिए चालू';

  @override
  String get groupShotsOnForAllDesk => 'Android के लिए Kryfo में चालू';

  @override
  String get groupShotsOffAdminOnly => 'बंद। इसे सिर्फ़ एडमिन बदल सकते हैं';

  @override
  String get groupShotsWaitAdminOnly =>
      'इंतज़ार है कि यहाँ सब अपने डिवाइस पर स्क्रीनशॉट रोक सकें। इसे सिर्फ़ एडमिन बदल सकते हैं';

  @override
  String get groupShotsOnAdminOnly =>
      'यहाँ सबके लिए चालू। इसे सिर्फ़ एडमिन बदल सकते हैं';

  @override
  String get groupShotsOnAdminOnlyDesk =>
      'Android के लिए Kryfo में चालू। इसे सिर्फ़ एडमिन बदल सकते हैं';

  @override
  String groupShotsWaitingFor(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString लोगों का इंतज़ार',
      one: '$countString व्यक्ति का इंतज़ार',
    );
    return '$_temp0';
  }

  @override
  String get groupShotsWaitingTitle => 'अभी शामिल नहीं';

  @override
  String get groupShotsWaitingHint =>
      'जब इन लोगों के डिवाइस स्क्रीनशॉट रोक पाएँगे, तब स्क्रीनशॉट रोकना सब पर लागू होगा। किसी को ग्रुप से हटाने के लिए उस पर टैप करें।';

  @override
  String get groupShotsNeedsUpdate =>
      'अपने डिवाइस पर अभी स्क्रीनशॉट नहीं रोक सकते, या तब से ऑनलाइन नहीं आए';

  @override
  String get groupShotsBlockedByYou => 'आपने ब्लॉक किया है';

  @override
  String get groupShotsYouTurnedOnWait =>
      'आपने स्क्रीनशॉट रोकना चालू किया। जब यहाँ सब अपने डिवाइस पर स्क्रीनशॉट रोक सकेंगे, तब यह सब पर लागू होगा।';

  @override
  String groupShotsTheyTurnedOnWait(String name) {
    return '$name ने स्क्रीनशॉट रोकना चालू किया। जब यहाँ सब अपने डिवाइस पर स्क्रीनशॉट रोक सकेंगे, तब यह सब पर लागू होगा।';
  }

  @override
  String get groupShotsStarted =>
      'यहाँ सबके लिए स्क्रीनशॉट रोकना चालू है। एक-दूसरे के मैसेज कॉपी, फ़ॉरवर्ड और सेव करना भी बंद है।';

  @override
  String get groupShotsStartedDesk =>
      'Android के लिए Kryfo में स्क्रीनशॉट रोकना चालू है। एक-दूसरे के मैसेज कॉपी, फ़ॉरवर्ड और सेव करना भी बंद है।';

  @override
  String get groupShotsPaused =>
      'यहाँ कोई अभी अपने डिवाइस पर स्क्रीनशॉट नहीं रोक सकता। जब वे रोक सकेंगे, यह फिर सब पर लागू होगा।';

  @override
  String get groupShotsCantYet => 'अभी स्क्रीनशॉट नहीं रोक सकते';

  @override
  String get groupShotsAddTitle => 'फिर भी जोड़ें?';

  @override
  String get groupShotsAddPauses =>
      'जब तक ये लोग अपने डिवाइस पर स्क्रीनशॉट नहीं रोक सकते, तब तक स्क्रीनशॉट रोकना यहाँ सब पर लागू नहीं होगा।';

  @override
  String get groupShotsLeaveStays => 'स्क्रीनशॉट रोकना जैसा है वैसा ही रहेगा।';

  @override
  String get groupShotsBlockedHere => 'Kryfo इस ग्रुप में स्क्रीनशॉट रोकता है';

  @override
  String get groupShotsBlockedHereDesk =>
      'इस ग्रुप में कॉपी, फ़ॉरवर्ड और सेव करना बंद है';

  @override
  String get groupShotsMenuNote =>
      'इस ग्रुप में दूसरों के मैसेज कॉपी, फ़ॉरवर्ड और सेव करना बंद है';

  @override
  String get groupShotsKeptOpen =>
      'इस ग्रुप में दूसरों की फ़ाइलें दूसरे ऐप में खोलना बंद है';

  @override
  String get groupShotsOldNotice =>
      'मैंने इस ग्रुप में स्क्रीनशॉट रोकना चालू किया है। आपका Kryfo अभी ऐसा नहीं कर सकता, इसलिए कृपया अपडेट करें।';

  @override
  String get captureShotTaken =>
      'स्क्रीनशॉट लिया गया। किसी और को नहीं बताया गया।';

  @override
  String get captureRecording =>
      'यह स्क्रीन रिकॉर्ड हो रही है। किसी और को नहीं बताया गया।';

  @override
  String get settingsDevices => 'डिवाइस';

  @override
  String get devicesLinkedDevices => 'जुड़े हुए डिवाइस';

  @override
  String get devicesThisPhoneOnly => 'सिर्फ़ यह फ़ोन';

  @override
  String get devicesThisPhoneOnlyDesk => 'सिर्फ़ यह कंप्यूटर';

  @override
  String get devicesNameSeparator => ', ';

  @override
  String get devicesThisPhone => 'यह फ़ोन';

  @override
  String get devicesThisPhoneDesk => 'यह कंप्यूटर';

  @override
  String get devicesOnlyThisPhone =>
      'सिर्फ़ यही फ़ोन डिवाइस जोड़ या हटा सकता है';

  @override
  String get devicesOnlyThisPhoneDesk =>
      'सिर्फ़ यही कंप्यूटर डिवाइस जोड़ या हटा सकता है';

  @override
  String devicesLinkedOn(Object date) {
    return '$date को जोड़ा गया';
  }

  @override
  String get devicesUsedToday => 'आज इस्तेमाल हुआ';

  @override
  String get devicesUsedThisWeek => 'इस हफ़्ते इस्तेमाल हुआ';

  @override
  String get devicesUsedThisMonth => 'इस महीने इस्तेमाल हुआ';

  @override
  String get devicesNotUsedYet => 'अभी तक इस्तेमाल नहीं हुआ';

  @override
  String devicesUnlinksSoon(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'न खोलने पर $daysString दिन में अलग हो जाएगा',
      one: 'न खोलने पर कल अलग हो जाएगा',
      zero: 'न खोलने पर आज अलग हो जाएगा',
    );
    return '$_temp0';
  }

  @override
  String get devicesEmptyTitle => 'आपके कंप्यूटर पर Kryfo';

  @override
  String get devicesEmptyLine =>
      'कंप्यूटर जोड़ें और वहीं से अपने मैसेज पढ़ें और भेजें।';

  @override
  String get devicesContactsSeeNothing =>
      'आपके संपर्कों के ऐप में आपके डिवाइस नहीं दिखते।';

  @override
  String get devicesUnusedRule =>
      'जिस डिवाइस को आप 30 दिन तक नहीं खोलते, वह खुद अलग हो जाता है और अपने ऊपर से आपकी चैट मिटा देता है।';

  @override
  String get devicesFull =>
      'आपके डिवाइस की सभी जगहें भर गई हैं। दूसरा जोड़ने के लिए एक हटाएँ।';

  @override
  String get devicesLinkADevice => 'डिवाइस जोड़ें';

  @override
  String get devicesRemoveAll => 'बाकी सभी डिवाइस हटाएँ';

  @override
  String get devicesRemoveAllTitle => 'बाकी सभी डिवाइस हटाएँ?';

  @override
  String get devicesRemoveAllLine =>
      'जब आपके संपर्कों के ऐप तक यह बदलाव पहुँच जाएगा, तब उन्हें नए मैसेज नहीं मिलेंगे और वे आपके नाम से नहीं भेज पाएँगे। इस फ़ोन पर सब कुछ रहेगा।';

  @override
  String get devicesRemoveAllYes => 'सभी हटाएँ';

  @override
  String get devicesRemovedAll => 'अब सिर्फ़ यह फ़ोन';

  @override
  String devicesRemoveTitle(Object name) {
    return '$name हटाएँ?';
  }

  @override
  String get devicesRemoveLine =>
      'जब आपके संपर्कों के ऐप तक यह बदलाव पहुँच जाएगा, तब इसे नए मैसेज नहीं मिलेंगे और यह आपके नाम से नहीं भेज पाएगा। अगली बार ऑनलाइन होने पर यह अपने ऊपर से आपकी चैट मिटा देगा। जिस डिवाइस से किसी ने छेड़छाड़ की हो, वह पहले से मौजूद चीज़ें अपने पास रख सकता है।';

  @override
  String get devicesRemove => 'हटाएँ';

  @override
  String devicesRemoved(Object name) {
    return '$name हटाया गया';
  }

  @override
  String get devicesRename => 'नाम बदलें';

  @override
  String devicesRenameTitle(Object name) {
    return '$name का नाम बदलें';
  }

  @override
  String get devicesRenameLine =>
      'यह नाम सिर्फ़ आपको दिखता है। आपके संपर्कों को कभी नहीं।';

  @override
  String get devicesNameComputer => 'कंप्यूटर';

  @override
  String get devicesDeviceCode => 'डिवाइस कोड';

  @override
  String get devicesDeviceCodeLine =>
      'यही कोड उस डिवाइस पर भी, सेटिंग में, दिखता है।';

  @override
  String get devicesLinkStep1 =>
      'अपने कंप्यूटर पर Kryfo खोलें। उस पर एक कोड दिखेगा।';

  @override
  String get devicesLinkStep2 => 'इस फ़ोन से वह कोड स्कैन करें।';

  @override
  String get devicesLinkStep3 =>
      'देखें कि दोनों स्क्रीन पर वही छह अंक दिख रहे हैं।';

  @override
  String get devicesHistory => 'पुरानी चैट';

  @override
  String get devicesHistoryCopy => 'मेरी चैट कॉपी करें';

  @override
  String get devicesHistoryCopyHint =>
      'आपके मैसेज, पिछले 30 दिन की फ़ोटो, वीडियो और वॉइस नोट के साथ।';

  @override
  String get devicesHistoryNone => 'सिर्फ़ संपर्क और ग्रुप';

  @override
  String get devicesHistoryNoneHint => 'वे बिना किसी मैसेज के आते हैं।';

  @override
  String get devicesSkipMedia => 'फ़ोटो और वीडियो छोड़ दें';

  @override
  String get devicesSkipMediaHint =>
      'सिर्फ़ टेक्स्ट आएगा। जल्दी होगा, और डिवाइस पर कम जगह लगेगी।';

  @override
  String get devicesHiddenStay =>
      'छिपी चैट और नकली Kryfo इसी फ़ोन पर रहते हैं।';

  @override
  String get devicesHiddenStayDesk =>
      'छिपी चैट और नकली Kryfo इसी कंप्यूटर पर रहते हैं।';

  @override
  String get devicesScanCode => 'कोड स्कैन करें';

  @override
  String get devicesLinkReaching => 'डिवाइस से जुड़ रहे हैं';

  @override
  String get devicesLinkReachingLine =>
      'दोनों पर Kryfo खुला रखें। Tor से इसमें एक मिनट लग सकता है।';

  @override
  String get devicesLinkCompare => 'क्या अंक मिलते हैं?';

  @override
  String get devicesLinkCompareLine =>
      'नया डिवाइस भी छह अंक दिखाता है। वही अंक हों तभी जोड़ें।';

  @override
  String get devicesLinkMatch => 'मिलते हैं';

  @override
  String get devicesLinkNoMatch => 'नहीं मिलते';

  @override
  String get devicesLinkLinking => 'जोड़ रहे हैं';

  @override
  String get devicesLinkLinkingLine =>
      'नया डिवाइस तैयार हो रहा है। दोनों खुले रखें।';

  @override
  String get devicesLinkDone => 'डिवाइस जुड़ गया';

  @override
  String get devicesLinkDoneLine =>
      'यह जुड़े हुए डिवाइस में दिखता है, जहाँ आप इसका नाम बदल सकते हैं या इसे हटा सकते हैं।';

  @override
  String get devicesLinkUnreached => 'डिवाइस तक नहीं पहुँच पाए';

  @override
  String get devicesLinkUnreachedLine =>
      'देखें कि नए डिवाइस पर Kryfo खुला है और उसका कोड दिख रहा है, फिर दोबारा कोशिश करें।';

  @override
  String get devicesLinkStopped => 'कुछ नहीं जुड़ा';

  @override
  String get devicesLinkStoppedLine =>
      'अंक मिलने चाहिए। नए कोड के साथ फिर से शुरू करें।';

  @override
  String get devicesLinkInterruptedLine =>
      'जोड़ना बीच में रुक गया। नए कोड के साथ फिर से शुरू करें।';

  @override
  String get devicesLinkAlreadyLine =>
      'यह कंप्यूटर पहले से जुड़ा है। जुड़े हुए डिवाइस में इसे हटाएँ, फिर दोबारा जोड़ें।';

  @override
  String get scanLinkTitle => 'डिवाइस का कोड स्कैन करें';

  @override
  String get scanLinkPoint => 'नए डिवाइस पर दिख रहे कोड की ओर कैमरा रखें';

  @override
  String get scanLinkNotOne => 'यह जोड़ने वाला कोड नहीं है';

  @override
  String get onboardingLinkToMyPhone => 'मेरे फ़ोन से जोड़ें';

  @override
  String get joinTitle => 'अपने फ़ोन से जोड़ें';

  @override
  String get joinStep1 => 'अपने फ़ोन पर Kryfo खोलें।';

  @override
  String get joinStep2 =>
      'सेटिंग्स में जाएँ, फिर जुड़े हुए डिवाइस, फिर डिवाइस जोड़ें।';

  @override
  String get joinStep3 => 'यह कोड अपने फ़ोन से स्कैन करें।';

  @override
  String get joinWaiting => 'आपके फ़ोन का इंतज़ार है';

  @override
  String get joinPreparing => 'आपका कोड तैयार हो रहा है';

  @override
  String get joinPreparingLine =>
      'Kryfo जुड़ रहा है। जैसे ही यह कंप्यूटर ऑनलाइन होगा, आपका कोड दिखेगा।';

  @override
  String get joinPreparingSlow =>
      'पहली बार शुरू होने में एक-दो मिनट लग सकते हैं, जब तक Tor जुड़ता है।';

  @override
  String get homeLinkedChatsComing => 'आपकी चैट अभी भी आपके फ़ोन से आ रही हैं।';

  @override
  String get joinCodeLife => 'यह कोड दस मिनट तक चलता है।';

  @override
  String get joinCompareLine =>
      'आपका फ़ोन भी छह अंक दिखाता है। वही अंक हों तभी आगे बढ़ें।';

  @override
  String get joinLinking => 'आपके फ़ोन से जोड़ रहे हैं';

  @override
  String get joinLinkingLine => 'यह पूरा होने तक अपने फ़ोन पर Kryfo खुला रखें।';

  @override
  String get joinDone => 'आपके फ़ोन से जुड़ गया';

  @override
  String get joinDoneLine =>
      'नए मैसेज अब इस डिवाइस पर भी आते हैं। आपके खाते का कुंजी नंबर:';

  @override
  String get joinOpen => 'Kryfo खोलें';

  @override
  String get joinUnreached => 'आपके फ़ोन तक नहीं पहुँच पाए';

  @override
  String get joinUnreachedLine =>
      'देखें कि आपका फ़ोन ऑनलाइन है और Kryfo खुला है, फिर नया कोड आज़माएँ।';

  @override
  String get devicesNewNotice => 'नया डिवाइस जुड़ा';

  @override
  String devicesNewNoticeLine(Object name, Object date) {
    return '$name $date को आपके खाते से जुड़ा। देखने के लिए जुड़े हुए डिवाइस खोलें।';
  }

  @override
  String get devicesNewNoticeMany => 'नए डिवाइस जुड़े';

  @override
  String devicesNewNoticeManyLine(Object names) {
    return '$names आपके खाते से जुड़े। देखने के लिए जुड़े हुए डिवाइस खोलें।';
  }

  @override
  String get devicesNewNoticeOpen => 'खोलें';

  @override
  String get settingsLinkedToLine =>
      'आपके फ़ोन से जुड़ा है। बैकअप और न्योते फ़ोन पर ही रहते हैं।';

  @override
  String get devicesYourPhone => 'आपका फ़ोन';

  @override
  String get desktopLockTitle => 'Kryfo लॉक है';

  @override
  String get desktopLockBody => 'इस कंप्यूटर का पासफ़्रेज़ लिखें।';

  @override
  String get desktopLockNewTitle => 'इस कंप्यूटर पर Kryfo लॉक करें';

  @override
  String get desktopLockNewBody =>
      'Kryfo हर बार शुरू होने पर यह पासफ़्रेज़ पूछेगा। यह इस कंप्यूटर पर आपके संदेश, फ़ोटो, वॉइस नोट, फ़ाइलें, संपर्क और कुंजियाँ लॉक रखता है।';

  @override
  String get desktopLockHonest =>
      'जो कोई Kryfo का फ़ोल्डर कॉपी कर ले, वह अपने कंप्यूटर पर उतनी तेज़ी से पासफ़्रेज़ आज़मा सकता है जितना उसका कंप्यूटर चल सके। चार या ज़्यादा बेतरतीब शब्द टिकते हैं। छोटा पासफ़्रेज़ नहीं टिकता।';

  @override
  String get desktopLockForgot =>
      'पासफ़्रेज़ के बिना यहाँ आपका कोई संदेश, फ़ाइल या कुंजी नहीं खुल सकती, हमसे भी नहीं।';

  @override
  String get desktopLockField => 'पासफ़्रेज़';

  @override
  String get desktopLockRepeat => 'वही पासफ़्रेज़ फिर से';

  @override
  String get desktopLockSet => 'इस पासफ़्रेज़ से लॉक करें';

  @override
  String get desktopLockOpen => 'Kryfo खोलें';

  @override
  String desktopLockShort(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'कम से कम $countString अक्षर';
  }

  @override
  String get desktopLockMismatch => 'दोनों पासफ़्रेज़ मेल नहीं खाते';

  @override
  String get desktopLockWrong => 'यह सही पासफ़्रेज़ नहीं है';

  @override
  String get desktopLockFailed =>
      'Kryfo यहाँ अपना लॉक नहीं खोल पाया। इसे फिर से शुरू करके देखें।';

  @override
  String get desktopTrayQuit => 'Kryfo बंद करें';

  @override
  String get desktopTrayTip => 'Kryfo चल रहा है और संदेश ले रहा है';

  @override
  String get desktopTrayLockedTip => 'संदेश पाना शुरू करने के लिए Kryfo खोलें';

  @override
  String get desktopTrayStillRunning =>
      'Kryfo सिस्टम ट्रे में चलता रहता है। बंद करने के लिए ट्रे में उसका आइकन इस्तेमाल करें।';

  @override
  String get desktopRunSection => 'इस कंप्यूटर पर';

  @override
  String get desktopTrayRow => 'सिस्टम ट्रे में चलता रहे';

  @override
  String get desktopTrayHint => 'विंडो बंद होने पर भी मैसेज आते रहते हैं।';

  @override
  String get desktopTrayOffLine =>
      'विंडो बंद करने पर Kryfo बंद हो जाता है।\nदोबारा खोलने पर मैसेज आ जाते हैं।';

  @override
  String get desktopTrayNoneLine =>
      'इस डेस्कटॉप में ट्रे आइकन नहीं है।\nविंडो बंद करने पर Kryfo बंद हो जाता है।';

  @override
  String get desktopStartRow => 'कंप्यूटर के साथ शुरू हो';

  @override
  String get desktopStartHint =>
      'इस कंप्यूटर में साइन इन करते ही Kryfo सिस्टम ट्रे में शुरू हो जाता है।';

  @override
  String get desktopStartRefused =>
      'इस कंप्यूटर ने Kryfo को अपने साथ शुरू होने नहीं दिया।\nजब आप ख़ुद शुरू करें, Kryfo खुल जाता है।';

  @override
  String get desktopStartHeldOff =>
      'Windows ने स्टार्टअप ऐप्स में Kryfo बंद कर रखा है।\nइसे Windows सेटिंग, ऐप्स, स्टार्टअप में चालू करें।';

  @override
  String get desktopMicBlocked =>
      'जब Windows डेस्कटॉप ऐप्स को माइक्रोफ़ोन इस्तेमाल करने देगा, Kryfo रिकॉर्ड कर सकेगा: सेटिंग्स, गोपनीयता और सुरक्षा, माइक्रोफ़ोन।';

  @override
  String get desktopMicNone =>
      'वॉइस नोट रिकॉर्ड करने के लिए माइक्रोफ़ोन जोड़ें।';

  @override
  String get desktopNoCamera =>
      'Kryfo अभी इस कंप्यूटर पर कैमरा इस्तेमाल नहीं कर सकता। इसके बजाय लिंक या कोड इस्तेमाल करें।';

  @override
  String get desktopAlreadyOpen => 'Kryfo इस कंप्यूटर पर पहले से खुला है।';

  @override
  String get desktopFolderNotYours =>
      'Kryfo का फ़ोल्डर इस कंप्यूटर के किसी दूसरे खाते का है, इसलिए Kryfo उसे नहीं खोलेगा।';

  @override
  String get desktopFolderNotPrivate =>
      'Kryfo अपना फ़ोल्डर सिर्फ़ आपके लिए निजी नहीं बना पाया, इसलिए यह नहीं खुलेगा।';

  @override
  String get desktopLockOtherVersion =>
      'यह लॉक Kryfo के किसी दूसरे संस्करण ने बनाया है, जिसे यह संस्करण नहीं पढ़ सकता।';

  @override
  String get desktopNoMemoryFolder =>
      'चलते समय Kryfo को मेमोरी में एक निजी फ़ोल्डर चाहिए, और यह कंप्यूटर ऐसा कोई फ़ोल्डर नहीं देता, इसलिए यह नहीं खुलेगा।';

  @override
  String get inviteNotYet =>
      'यह न्योता अभी मान्य नहीं है। अपने फ़ोन का समय जाँचें।';

  @override
  String get inviteNotYetDesk =>
      'यह न्योता अभी मान्य नहीं है। अपने कंप्यूटर का समय जाँचें।';

  @override
  String get inviteExpired => 'यह न्योता समाप्त हो गया है। नया माँगें।';

  @override
  String get inviteDamaged => 'यह न्योता खराब है। नया माँगें।';

  @override
  String get helloSent => 'अनुरोध भेजा गया। ऑनलाइन होने पर वे इसे देखेंगे।';

  @override
  String get inviteNeeds06 => 'Kryfo 0.6 या नया चाहिए।';

  @override
  String get helloSentOld =>
      'अनुरोध भेजा गया। अगर वे Kryfo का पुराना संस्करण इस्तेमाल करते हैं, तो उन्हें पहले अपडेट करना होगा।';

  @override
  String get modesPickHow =>
      'चुनें कि आपके संदेश कैसे जाएँ। आप इसे कभी भी बदल सकते हैं।';

  @override
  String get modesPrivate => 'प्राइवेट';

  @override
  String get modesPrivateTag => 'Tor · ज़रूरत पर ब्रिज';

  @override
  String get modesPrivateLine =>
      'आपका IP पता या आप कौन हैं, यह कोई नहीं जान पाता, हमारे सर्वर भी नहीं। रोक के आसपास रास्ता खुद ढूँढ लेता है।';

  @override
  String get modesDefault => 'डिफ़ॉल्ट';

  @override
  String get modesFastTag => 'सीधे हमारे सर्वर तक';

  @override
  String get modesFastLine =>
      'Tor को छोड़ देता है, इसलिए संदेश जल्दी पहुँचते हैं और बैटरी कम लगती है। हमारे सर्वर आपका IP पता सिर्फ़ तब देखते हैं जब आप जुड़े हों, और उसे कभी दर्ज नहीं करते, न रखते हैं। आपके संपर्क इसे कभी नहीं देखते। आपका नेटवर्क देख सकता है कि आप Kryfo से जुड़ रहे हैं।';

  @override
  String get modesFastConnected => 'तेज़ · जुड़ा है';

  @override
  String get modesFastConnecting => 'तेज़ · जुड़ रहा है';

  @override
  String get modesFastDown => 'तेज़ · हमारे सर्वर जवाब नहीं दे रहे';

  @override
  String get modesBackupReady =>
      'एक बैकअप हमेशा तैयार रहता है, इसलिए एक बंद हो जाए तब भी आप जुड़े रहते हैं।';

  @override
  String get modesDetails => 'विवरण';

  @override
  String get modesBothLine =>
      'दोनों हर संदेश को एंड-टू-एंड एन्क्रिप्टेड रखते हैं। बस यह बदलता है कि आपका IP पता कौन देख सकता है।';

  @override
  String get modesConnectionBridges => 'कनेक्शन और ब्रिज';

  @override
  String get modesWhatServersSee => 'हमारे सर्वर क्या देख सकते हैं';

  @override
  String get serversTitle => 'तेज़ के सर्वर';

  @override
  String get serversLine =>
      'हर संदेश एक साथ दोनों सर्वर पर जाता है। जो पहले जवाब दे, वही उसे पहुँचाता है, और एक रुक जाए तो दूसरा संभाल लेता है।';

  @override
  String get serversOne => 'सर्वर 1';

  @override
  String get serversTwo => 'सर्वर 2 · दूसरी कंपनी';

  @override
  String get serversConnected => 'जुड़ा है';

  @override
  String get serversConnecting => 'जुड़ रहा है';

  @override
  String get serversNotAnswering => 'जवाब नहीं दे रहा';

  @override
  String serversMs(int ms) {
    return '$ms ms';
  }

  @override
  String get serversQuicker => 'ज़्यादा तेज़';

  @override
  String get serversBackups => 'सार्वजनिक रिले';

  @override
  String get serversBackupsLine =>
      'जब तक सर्वर 1 बंद है, तब तक इस्तेमाल होते हैं, और सिर्फ़ Tor से, इसलिए ये आपका IP पता कभी नहीं देखते।';

  @override
  String get serversStandingBy => 'तैयार खड़े';

  @override
  String get serversInUse => 'इस्तेमाल में';

  @override
  String get homeMergedTitle => 'रिले और तेज़ अब एक हैं';

  @override
  String get homeMergedLine =>
      'आप तेज़ पर हैं। एक बैकअप सर्वर हमेशा तैयार रहता है, इसलिए एक बंद हो जाए तब भी आप जुड़े रहते हैं। हमारे सर्वर आपका IP पता देखते हैं, आप क्या कहते हैं यह कभी नहीं।';

  @override
  String get homeMergedGotIt => 'समझ गया';

  @override
  String get homeMergedUsePrivate => 'इसकी जगह प्राइवेट चुनें';

  @override
  String get homeOursDownTitle => 'हमारे सर्वर जवाब नहीं दे रहे';

  @override
  String get homeOursDownLine =>
      'कुछ मिनट बाद, जब Tor जुड़ जाए, संदेश सार्वजनिक रिले से भी जाते हैं, और जैसे ही हमारा कोई सर्वर जवाब दे, फिर उसी से।';

  @override
  String get homeUsePrivate => 'प्राइवेट चुनें';

  @override
  String get homeSwitchedToPrivate => 'प्राइवेट पर आ गए';

  @override
  String get homeUseFast => 'तेज़ चुनें';

  @override
  String get homeSwitchedToFastRoute => 'तेज़ पर आ गए';

  @override
  String get bridgesBridgeFirstFastSeen =>
      'Kryfo को ऐसा ब्रिज ढूँढने दें जो पहुँच जाए। तेज़ भी चलता है, पर यह नेटवर्क देख सकता है कि आप Kryfo से जुड़ रहे हैं।';

  @override
  String get appServersNotAnswering => 'सर्वर चुप हैं';

  @override
  String get settingsPrivateTor => 'प्राइवेट · Tor';

  @override
  String get seenOurServers => 'हमारे सर्वर';

  @override
  String get seenOurServersCould => 'हमारे सर्वर जान सकते हैं';

  @override
  String get seenIpWhy =>
      'प्राइवेट पर सब कुछ Tor से निकलता है और हमारे सर्वर एक एग्ज़िट नोड देखते हैं, आपको कभी नहीं। तेज़ पर कनेक्शन सीधे हमारे दो सर्वर तक जाता है: जब तक आप जुड़े हैं वे आपका IP पता देखते हैं और उसका कोई रिकॉर्ड नहीं रखते। जब पहला बंद हो, तेज़ सार्वजनिक रिले भी इस्तेमाल करता है, सिर्फ़ Tor से।';

  @override
  String get chatAlbumItDisappearsWithNo =>
      'यह एल्बम दोनों फ़ोन से हट जाएगा, अगर पहले ही सेव न किया गया हो। इसे पलटा नहीं जा सकता।';

  @override
  String get chatAlbumItDisappearsWithNoDesk =>
      'यह एल्बम दोनों डिवाइस से हट जाएगा, अगर पहले ही सेव न किया गया हो। इसे पलटा नहीं जा सकता।';

  @override
  String get groupChatAlbumItDisappearsWithNo =>
      'यह एल्बम सबके फ़ोन से हट जाएगा, अगर पहले ही सेव न किया गया हो। इसे पलटा नहीं जा सकता।';

  @override
  String get groupChatAlbumItDisappearsWithNoDesk =>
      'यह एल्बम सबके डिवाइस से हट जाएगा, अगर पहले ही सेव न किया गया हो। इसे पलटा नहीं जा सकता।';

  @override
  String get homeInviteSomeone => 'किसी को बुलाएँ';

  @override
  String get onboardingNameHeadline => 'चाहें तो एक सार्वजनिक *@नाम*।';

  @override
  String get onboardingNameLine =>
      'सार्वजनिक @नाम से लोग आपको ढूँढ सकते हैं।\nइसे छोड़ने से आप ज़्यादा निजी रहते हैं।\nआप इसे बाद में जोड़ सकते हैं।';

  @override
  String get onboardingNameSkip => 'अभी छोड़ें →';

  @override
  String onboardingNameClaim(Object handle) {
    return '@$handle लें →';
  }

  @override
  String get onboardingInviteHeadline => 'अब, *किसी को बुलाएँ*।';

  @override
  String get onboardingInviteLead =>
      'किसी भी मैसेंजर में एक लिंक भेजें।\nवह Kryfo खोलता है, या दिखाता है कि उसे कहाँ से पाएँ।';

  @override
  String get onboardingInviteSomeone => 'किसी को बुलाएँ →';

  @override
  String get onboardingInviteGettingReady => 'आपका लिंक तैयार हो रहा है…';

  @override
  String inviteShareText(Object myId, Object link, Object download) {
    return 'मुझे Kryfo पर जोड़ें। वहाँ मेरा नाम $myId है\n\nमुझे जोड़ने के लिए टैप करें:\n$link\n\nअभी Kryfo नहीं है? यहाँ से पाएँ:\n$download\n\nKryfo एक निजी मैसेंजर है। न फ़ोन नंबर, न ईमेल।';
  }

  @override
  String get inviteNotReady =>
      'आपका लिंक लगभग तैयार है। थोड़ी देर में फिर कोशिश करें।';

  @override
  String get photoCropTitle => 'खिसकाएँ और आकार बदलें';

  @override
  String get photoCropUse => 'फ़ोटो इस्तेमाल करें';

  @override
  String get photoCropLabel =>
      'गोले में आपकी फ़ोटो। ज़ूम के लिए उँगलियाँ फैलाएँ, खिसकाने के लिए खींचें';

  @override
  String get photoCouldNotUse =>
      'कोई दूसरी फ़ोटो आज़माएँ। यह फ़ोटो पढ़ी नहीं जा सकी।';

  @override
  String get photoTake => 'फ़ोटो लें';

  @override
  String get photoChoose => 'गैलरी से चुनें';

  @override
  String get photoPickFace => 'चेहरा चुनें';

  @override
  String get photoView => 'फ़ोटो देखें';

  @override
  String get photoRemove => 'फ़ोटो हटाएँ';

  @override
  String get photoYourPhoto => 'आपकी फ़ोटो';

  @override
  String get photoYourPhotoLine =>
      'इसे सिर्फ़ आपके संपर्क देखते हैं, एंड-टू-एंड एन्क्रिप्टेड।';

  @override
  String get photoSetTheirs => 'फ़ोटो लगाएँ';

  @override
  String get photoChangeTheirs => 'फ़ोटो बदलें';

  @override
  String get photoOnlyHere => 'सिर्फ़ इसी फ़ोन पर';

  @override
  String get photoOnlyHereDesk => 'सिर्फ़ इसी कंप्यूटर पर';

  @override
  String photoForThem(Object name) {
    return '$name के लिए फ़ोटो';
  }

  @override
  String get photoOnlyHereLine =>
      'इसे सिर्फ़ आप देखते हैं। यह इसी फ़ोन पर रहती है।';

  @override
  String get photoOnlyHereLineDesk =>
      'इसे सिर्फ़ आप देखते हैं। यह इसी कंप्यूटर पर रहती है।';

  @override
  String photoOf(Object name) {
    return '$name की फ़ोटो';
  }

  @override
  String get historyChatStaysShots =>
      'यह चैट आपके फ़ोन पर ही रहती है, क्योंकि इसमें स्क्रीनशॉट रोके गए हैं।';

  @override
  String chatDeviceOlderKryfo(String name) {
    return '$name Kryfo का पुराना संस्करण इस्तेमाल करते हैं। उनके अपडेट करने तक अपने फ़ोन से जवाब दें।';
  }

  @override
  String chatDeviceNotYet(String name) {
    return '$name अभी इस कंप्यूटर से मैसेज नहीं पा सकते। अपने फ़ोन से जवाब दें।';
  }

  @override
  String chatDeviceWaitingForApp(String name) {
    return '$name के ऐप के इस कंप्यूटर को पहचानने का इंतज़ार है। अभी के लिए अपने फ़ोन से जवाब दें।';
  }

  @override
  String chatDeviceQuietAWhile(String name) {
    return '$name ने काफ़ी समय से कुछ नहीं लिखा। अभी के लिए अपने फ़ोन से जवाब दें।';
  }

  @override
  String get linkedClearHereOnly =>
      'यहाँ का हर मैसेज सिर्फ़ इस कंप्यूटर से मिटेगा। आपका फ़ोन उन्हें रखता है।';

  @override
  String get linkedDeleteHereOnly =>
      'हर मैसेज और संपर्क सिर्फ़ इस कंप्यूटर से हटेंगे। आपका फ़ोन चैट रखता है।';

  @override
  String get linkedBlockHereOnly =>
      'उनके मैसेज इस कंप्यूटर पर आना बंद हो जाते हैं। उन्हें बताया नहीं जाता। फ़ोन पर भी रोकने के लिए उन्हें अपने फ़ोन पर ब्लॉक करें।';

  @override
  String get historyCopyTitle => 'चैट हिस्ट्री';

  @override
  String get historyCopyMaking => 'आपकी चैट तैयार हो रही हैं';

  @override
  String get historyCopyMakingLine =>
      'आपका फ़ोन कॉपी होने वाली चीज़ें इकट्ठा कर रहा है। बस शुरू होने वाला है।';

  @override
  String get historyCopyGoing => 'आपकी चैट कॉपी हो रही हैं';

  @override
  String get historyCopyGoingLine => 'पूरा होने तक दोनों डिवाइस ऑनलाइन रखें।';

  @override
  String historyCopySize(Object size) {
    return 'कुल $size';
  }

  @override
  String get historyCopyWaiting => 'दूसरे डिवाइस का इंतज़ार';

  @override
  String get historyCopyWaitingLine =>
      'दोनों डिवाइस ऑनलाइन होते ही कॉपी अपने-आप आगे बढ़ती है।';

  @override
  String get historyCopyPaused => 'कॉपी थोड़ी देर रुकी है';

  @override
  String get historyCopyPausedLine => 'एक मिनट में फिर चलेगी।';

  @override
  String get historyCopyWhole => 'सभी मैसेज और फ़ाइलें आ गईं';

  @override
  String get historyCopyWholeLine => 'कुछ भी छूटा नहीं।';

  @override
  String get historyCopyRows => 'आपके संपर्क और ग्रुप आ गए';

  @override
  String get historyCopyRowsLine =>
      'वे बिना किसी मैसेज के आए। नए मैसेज अब से डिवाइस पर दिखते हैं।';

  @override
  String get historyCopyGaps => 'आपकी ज़्यादातर चैट आ गईं';

  @override
  String get historyCopyGapsLine =>
      'इन चैट में नए डिवाइस पर आपके फ़ोन से कम है।';

  @override
  String historyCopyGapMessages(Object got, Object want) {
    return 'मैसेज: $want में से $got';
  }

  @override
  String historyCopyGapFiles(Object got, Object want) {
    return 'फ़ाइलें: $want में से $got';
  }

  @override
  String historyCopyLeft(num count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString चीज़ें आपके फ़ोन पर रह गईं',
      one: '1 चीज़ आपके फ़ोन पर रह गई',
    );
    return '$_temp0';
  }

  @override
  String get historyCopyLeftWhy =>
      'कॉपी करने के लिए बहुत बड़ी या पढ़ने लायक नहीं।';

  @override
  String historyCopyLeftChats(num count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString चैट आपके फ़ोन पर रह गईं',
      one: '1 चैट आपके फ़ोन पर रह गई',
    );
    return '$_temp0';
  }

  @override
  String get historyCopyEnded => 'कॉपी रुक गई';

  @override
  String get historyCopyEndedLine =>
      'अब और कुछ नहीं आएगा। नई कॉपी के लिए डिवाइस दोबारा लिंक करें।';

  @override
  String get historyCopyFailed => 'कॉपी पूरी नहीं हो सकी';

  @override
  String get historyCopyFailedLine => 'नई कॉपी के लिए डिवाइस दोबारा लिंक करें।';

  @override
  String get historyCopyStays => 'आपके फ़ोन पर रह गया';

  @override
  String get historyCopySee => 'कॉपी देखें';

  @override
  String a11yPinDigits(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString अंक',
      one: '1 अंक',
      zero: 'कोई अंक नहीं',
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
      other: '$countString अक्षर',
      one: '1 अक्षर',
      zero: 'कोई अक्षर नहीं',
    );
    return '$_temp0';
  }

  @override
  String get a11yBackupProgress => 'बैकअप की प्रगति';

  @override
  String get a11yRestoreProgress => 'रीस्टोर की प्रगति';

  @override
  String get a11yExportProgress => 'एक्सपोर्ट की प्रगति';

  @override
  String get a11yLockFileProgress => 'लॉक करने की प्रगति';

  @override
  String get a11yCleanProgress => 'सफ़ाई की प्रगति';

  @override
  String get a11yMessageActions => 'मैसेज के विकल्प';

  @override
  String get a11yRecordVoiceNote => 'वॉइस नोट रिकॉर्ड करें';

  @override
  String get a11yRecording => 'रिकॉर्ड हो रहा है';

  @override
  String a11yPhotoOn(String date) {
    return 'फ़ोटो, $date';
  }

  @override
  String a11yPhotoFrom(String name, String date) {
    return '$name से आई फ़ोटो, $date';
  }

  @override
  String a11yVideoOn(String date) {
    return 'वीडियो, $date';
  }

  @override
  String a11yVideoFrom(String name, String date) {
    return '$name से आया वीडियो, $date';
  }

  @override
  String a11yNewMessages(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString नए मैसेज',
      one: 'नया मैसेज',
    );
    return '$_temp0';
  }

  @override
  String get wideSelectChat => 'कोई चैट चुनें';

  @override
  String get wideSelectChatLine =>
      'लिखना शुरू करने के लिए सूची से कोई चैट चुनें।';

  @override
  String get wideListWidth => 'चैट सूची की चौड़ाई';

  @override
  String transferDoneOf(String done, String total) {
    return '$total में से $done';
  }

  @override
  String transferDoneLeft(String done, String left) {
    return '$done · $left';
  }

  @override
  String get transferLeftSoon => 'एक मिनट से कम बाकी';

  @override
  String transferLeftMinutes(String n) {
    return 'लगभग $n मिनट बाकी';
  }

  @override
  String transferLeftHours(String n) {
    return 'लगभग $n घंटे बाकी';
  }

  @override
  String transferSending(String detail) {
    return 'भेजा जा रहा है · $detail';
  }

  @override
  String transferReceiving(String detail) {
    return 'आ रहा है · $detail';
  }

  @override
  String transferBoth(String detail) {
    return 'भेजा और पाया जा रहा है · $detail';
  }

  @override
  String get transferPause => 'रोकें';

  @override
  String get transferPauseDownload => 'डाउनलोड रोकें';

  @override
  String get transferDownload => 'डाउनलोड करें';

  @override
  String get transferResume => 'फिर शुरू करें';

  @override
  String get transferOnWifi => 'Wi-Fi पर डाउनलोड होगा';

  @override
  String transferPausedAt(String detail) {
    return 'रुका हुआ · $detail';
  }

  @override
  String get transferTapToDownload => 'पाने के लिए टैप करें';

  @override
  String transferSizeLine(String size, String state) {
    return '$size · $state';
  }

  @override
  String get transferNoteTitle => 'फ़ाइल ट्रांसफ़र';

  @override
  String get transferChannel => 'फ़ाइल ट्रांसफ़र';

  @override
  String get transferChannelLine =>
      'फ़ाइलें भेजते या डाउनलोड होते समय दिखता है। कभी किसी चैट या फ़ाइल का नाम नहीं बताता।';

  @override
  String get autoGetTitle => 'अपने आप डाउनलोड';

  @override
  String get autoGetLine =>
      'फ़ाइलें यहाँ की सेटिंग के हिसाब से बिना टैप के आती हैं। इंतज़ार वाली फ़ाइल आपके लिए फ़ाइल सर्वर पर रहती है, ज़्यादा से ज़्यादा एक हफ़्ता।';

  @override
  String get autoGetPhotos => 'फ़ोटो';

  @override
  String get autoGetVideos => 'वीडियो';

  @override
  String get autoGetFiles => 'फ़ाइलें';

  @override
  String get autoGetAlways => 'Wi-Fi और मोबाइल डेटा पर';

  @override
  String get autoGetWifi => 'सिर्फ़ Wi-Fi पर';

  @override
  String get autoGetNever => 'कभी नहीं, मैं टैप करके डाउनलोड करूँगा';

  @override
  String get autoGetVoice => 'वॉइस मैसेज हमेशा डाउनलोड होते हैं।';

  @override
  String get settingsFiles => 'फ़ाइलें';

  @override
  String get desktopLockAccountBody =>
      'Kryfo इस कंप्यूटर पर जो कुछ रखता है, सब एन्क्रिप्टेड है। यह आपके यूज़र अकाउंट से खुलता है।';

  @override
  String get desktopLockAddPassphrase => 'पासफ़्रेज़ जोड़ें';

  @override
  String get desktopLockWithoutPassphrase =>
      'इसके बिना, आपके यूज़र अकाउंट का इस्तेमाल करने वाला कोई भी Kryfo खोल सकता है।';

  @override
  String get desktopLockKeyringRefused =>
      'Kryfo अपनी कुंजी इस कंप्यूटर की कीरिंग में नहीं रख पाया। इसकी जगह पासफ़्रेज़ जोड़ें।';

  @override
  String get desktopKeyMissing =>
      'इस यूज़र अकाउंट के पास Kryfo के डेटा की कुंजी नहीं है। Kryfo बैकअप सब कुछ वापस ले आता है। अगर आपने Kryfo का फ़ोल्डर कहीं और रखा है, तो जिस यूज़र अकाउंट से वह आया है उस पर पासफ़्रेज़ जोड़ें, फिर उसे दोबारा कॉपी करें।';

  @override
  String get desktopKeyUnreachable =>
      'Kryfo अभी इस कंप्यूटर पर अपनी कुंजी तक नहीं पहुँच पा रहा। कंप्यूटर पूछे तो अपनी कीरिंग अनलॉक करें, फिर दोबारा कोशिश करें।';

  @override
  String get desktopPassRow => 'इस कंप्यूटर पर पासफ़्रेज़';

  @override
  String get desktopPassWindowsAccount => 'आपके Windows अकाउंट से लॉक है';

  @override
  String get desktopPassKeyring => 'आपकी कीरिंग से लॉक है';

  @override
  String get desktopPassOffBody => 'Kryfo आपके यूज़र अकाउंट से खुलता है।';

  @override
  String get desktopPassOnBody =>
      'Kryfo हर बार शुरू होने पर यह पासफ़्रेज़ पूछता है।';

  @override
  String get desktopPassChange => 'पासफ़्रेज़ बदलें';

  @override
  String get desktopPassRemove => 'पासफ़्रेज़ हटाएँ';

  @override
  String get desktopPassCurrent => 'मौजूदा पासफ़्रेज़';

  @override
  String get desktopPassNew => 'नया पासफ़्रेज़';

  @override
  String get desktopPassStays =>
      'इस कंप्यूटर पर ऐसी कोई कीरिंग नहीं है जिसे Kryfo इस्तेमाल कर सके, इसलिए पासफ़्रेज़ बना रहेगा।';

  @override
  String get desktopPassAdded => 'पासफ़्रेज़ जोड़ा गया';

  @override
  String get desktopPassRemoved => 'पासफ़्रेज़ हटाया गया';

  @override
  String get desktopPassChanged => 'पासफ़्रेज़ बदला गया';

  @override
  String get desktopPassRemoveBody =>
      'हटाने के लिए अपना पासफ़्रेज़ लिखें। इसके बाद Kryfo आपके यूज़र अकाउंट से खुलेगा।';

  @override
  String get desktopKeyUnreachableWindows =>
      'Kryfo अभी इस कंप्यूटर की सुरक्षा चिप में अपनी कुंजी तक नहीं पहुँच पा रहा। थोड़ी देर में दोबारा कोशिश करें।';

  @override
  String get desktopLockAccountRefused =>
      'Kryfo अपनी कुंजी आपके Windows अकाउंट के साथ नहीं रख पाया। इसकी जगह पासफ़्रेज़ जोड़ें।';

  @override
  String get desktopPassStaysWindows =>
      'Kryfo अपनी कुंजी आपके Windows अकाउंट के साथ नहीं रख पाया, इसलिए पासफ़्रेज़ बना रहेगा।';

  @override
  String get desktopBackupCardTitle => 'Kryfo बैकअप रखें';

  @override
  String get desktopBackupCardLine =>
      'इस कंप्यूटर पर आपका Windows अकाउंट Kryfo की कुंजी रखता है। अगर कभी कंप्यूटर या अकाउंट रीसेट हो, तो Kryfo बैकअप सब कुछ वापस ले आता है।';

  @override
  String get desktopBackupHint =>
      'अगर कभी यह कंप्यूटर रीसेट हो, तो सब कुछ वापस ले आता है।';

  @override
  String chatHealRestored(Object name) {
    return '$name ने Kryfo फिर से सेट किया';
  }

  @override
  String chatHealNewSession(Object name) {
    return '$name के डिवाइस ने एक नया सुरक्षित सेशन शुरू किया';
  }

  @override
  String chatHealHeldLine(Object name) {
    return 'आपने पहले $name की पुष्टि की थी। जब तक आप नंबर जाँच न लें या बातचीत जारी न रखें, कुछ भी नहीं भेजा जाएगा। उनके मैसेज फिर भी आते रहेंगे।';
  }

  @override
  String get chatKeepChatting => 'बातचीत जारी रखें';

  @override
  String chatNeedsUpdateToChat(Object name) {
    return 'बातचीत जारी रखने के लिए $name को Kryfo अपडेट करना होगा';
  }

  @override
  String get restoreOlderTitle => 'कुछ चैट रुक जाएँगी';

  @override
  String restoreOlderOne(Object name) {
    return '$name Kryfo का पुराना संस्करण इस्तेमाल करते हैं। उनके अपडेट करने तक आपकी चैट रुकी रहेगी।';
  }

  @override
  String restoreOlderTwo(Object first, Object second) {
    return '$first और $second Kryfo का पुराना संस्करण इस्तेमाल करते हैं। उनके अपडेट करने तक उनसे आपकी चैट रुकी रहेंगी।';
  }

  @override
  String restoreOlderMany(Object first, Object second, int count) {
    return '$first, $second और $count अन्य Kryfo का पुराना संस्करण इस्तेमाल करते हैं। उनके अपडेट करने तक उनसे आपकी चैट रुकी रहेंगी।';
  }

  @override
  String settingsVersionAlpha(String version) {
    return '$version · अल्फ़ा';
  }

  @override
  String get settingsDeskInTray => 'सिस्टम ट्रे में चल रहा है';

  @override
  String get settingsDeskWhileOpen => 'जब तक Kryfo खुला है';

  @override
  String get onboardingDeskRunTitle => 'Kryfo *चलता* रहता है।';

  @override
  String get onboardingDeskRunLead =>
      'विंडो बंद करें, Kryfo सिस्टम ट्रे में इंतज़ार करेगा।\nमैसेज आते रहेंगे।\nदोनों को सेटिंग, सूचनाएँ में बदल सकते हैं।';

  @override
  String get savedLongPressAnyMessageDesk =>
      'किसी भी मैसेज पर राइट-क्लिक करें और उसे यहाँ रखने के लिए सेव चुनें।';

  @override
  String get chatFailedTapToRetryDesk => 'नहीं गया · फिर भेजने को क्लिक करें';

  @override
  String get groupChatTapToRetryDesk => '! फिर भेजने को क्लिक करें';

  @override
  String get chatDropHereToSend => 'भेजने के लिए यहाँ छोड़ें';

  @override
  String get chatDropHereToAdd => 'जोड़ने के लिए यहाँ छोड़ें';

  @override
  String trayRemove(String name) {
    return '$name हटाएँ';
  }

  @override
  String trayReadyToSend(Object count) {
    return 'भेजने के लिए तैयार: $count';
  }

  @override
  String get trayPastedPicture => 'चिपकाई गई तस्वीर';

  @override
  String get voiceSeeTranscription => 'लिखित रूप देखें';

  @override
  String get voiceTranscribing => 'लिखा जा रहा है…';

  @override
  String get voiceHideTranscription => 'छिपाएँ';

  @override
  String get voiceShowOriginalOnly => 'सिर्फ़ मूल दिखाएँ';

  @override
  String get voiceCouldNotTranscribe => 'शब्द समझ नहीं आए';

  @override
  String get voiceNoSpeech => 'इस संदेश में कोई बोल नहीं रहा';

  @override
  String get voiceTxNoMemory => 'अभी पर्याप्त खाली मेमोरी नहीं है';

  @override
  String get voiceTranscriptLabel => 'लिखित रूप';

  @override
  String get voiceSettingsTitle => 'आवाज़ से लिखित';

  @override
  String get voiceOnRow => 'वॉइस मैसेज को लिखित में बदलें';

  @override
  String get voiceOnHint => 'हर वॉइस मैसेज के नीचे सुझाया जाता है';

  @override
  String get voiceOffDeletes =>
      'इसे बंद करने पर सहेजे गए लिखित रूप मिट जाते हैं।';

  @override
  String get voiceModelTitle => 'स्पीच मॉडल';

  @override
  String voiceModelLine(Object size) {
    return 'लगभग $size का एक डाउनलोड, सभी भाषाओं के लिए।';
  }

  @override
  String get voiceModelPrivacy =>
      'Tor से डाउनलोड होकर इसी फ़ोन पर रहता है। आपके वॉइस मैसेज इससे बाहर कभी नहीं जाते।';

  @override
  String get voiceModelPrivacyDesk =>
      'Tor से डाउनलोड होकर इसी कंप्यूटर पर रहता है। आपके वॉइस मैसेज इससे बाहर कभी नहीं जाते।';

  @override
  String get voiceModelFailNoTor =>
      'Tor अभी नहीं जुड़ा है। मॉडल सिर्फ़ Tor से डाउनलोड होता है, इसलिए उसके जुड़ने पर फिर कोशिश करें।';

  @override
  String get voiceModelRemoveTitle => 'स्पीच मॉडल हटाएँ?';

  @override
  String get voiceModelRemoveLine =>
      'बन चुके लिखित रूप बने रहते हैं। नए के लिए मॉडल फिर चाहिए।';

  @override
  String get voiceKeptNote =>
      'लिखित रूप इस फ़ोन पर अपनी चैट के साथ एन्क्रिप्ट होकर रखे जाते हैं और उसी के साथ मिटते हैं।';

  @override
  String get voiceKeptNoteDesk =>
      'लिखित रूप इस कंप्यूटर पर अपनी चैट के साथ एन्क्रिप्ट होकर रखे जाते हैं और उसी के साथ मिटते हैं।';

  @override
  String get voiceNotNow => 'अभी नहीं';

  @override
  String get unlinkedTitle => 'यह डिवाइस अलग हो गया है';

  @override
  String get unlinkedRemovedLine =>
      'आपके फ़ोन ने इसे आपके खाते से हटा दिया, इसलिए Kryfo ने यहाँ रखा सब कुछ मिटा दिया।';

  @override
  String get unlinkedUnusedLine =>
      'इसे 30 दिन तक नहीं खोला गया, इसलिए Kryfo ने यहाँ रखा सब कुछ मिटा दिया।';

  @override
  String get unlinkedSilentLine =>
      'इसे 30 दिन तक आपके फ़ोन से कुछ नहीं मिला, इसलिए Kryfo ने यहाँ रखा सब कुछ मिटा दिया।';

  @override
  String get unlinkedClockLine =>
      'इसकी घड़ी पीछे कर दी गई, इसलिए आपकी चैट सुरक्षित रखने के लिए Kryfo ने यहाँ रखा सब कुछ मिटा दिया।';

  @override
  String get unlinkedBrokenLine =>
      'Kryfo यह नहीं जान सका कि इसे आख़िरी बार कब खोला गया, इसलिए आपकी चैट सुरक्षित रखने के लिए उसने यहाँ रखा सब कुछ मिटा दिया।';

  @override
  String get unlinkedSelfLine =>
      'आपने इसे अलग किया, इसलिए Kryfo ने यहाँ रखा सब कुछ मिटा दिया।';

  @override
  String get unlinkedAgainLine =>
      'आपकी चैट आपके फ़ोन पर रहती हैं। यहाँ फिर से Kryfo इस्तेमाल करने के लिए इस डिवाइस को अपने फ़ोन से जोड़ें।';

  @override
  String get unlinkedClose => 'Kryfo बंद करें';

  @override
  String get devicesLeave => 'यह डिवाइस अलग करें';

  @override
  String get devicesLeaveTitle => 'यह डिवाइस अलग करें?';

  @override
  String get devicesLeaveLine =>
      'Kryfo आपके फ़ोन को बताएगा और यहाँ रखा सब कुछ मिटा देगा। आपकी चैट आपके फ़ोन पर रहेंगी।';

  @override
  String get devicesLeaveYes => 'अलग करें और मिटाएँ';

  @override
  String get devicesGoneNotice => 'डिवाइस हटाया गया';

  @override
  String devicesGoneRemovedLine(Object name, Object date) {
    return '$name $date को आपके खाते से हटाया गया।';
  }

  @override
  String devicesGoneUnusedLine(Object name, Object date) {
    return '$name 30 दिन तक इस्तेमाल नहीं हुआ, इसलिए $date को इसे आपके खाते से हटाया गया।';
  }

  @override
  String devicesGoneItselfLine(Object name, Object date) {
    return '$name $date को खुद अलग हो गया और उसने जो रखा था वह मिटा दिया।';
  }

  @override
  String get devicesChangedNotice => 'आपके डिवाइस बदल गए';

  @override
  String get devicesChangedLine =>
      'क्या बदला, यह देखने के लिए जुड़े हुए डिवाइस खोलें।';

  @override
  String get devicesUnknownNotice => 'कहीं और से जोड़ा गया डिवाइस';

  @override
  String get devicesUnknownLine =>
      'Kryfo की किसी दूसरी कॉपी ने आपके खाते से एक डिवाइस जोड़ा। इस फ़ोन ने उसे आपकी सूची से हटा दिया।';

  @override
  String get albumPrevious => 'पिछला';

  @override
  String get albumNext => 'अगला';

  @override
  String get notesHoldHintDesk =>
      'कॉपी या डिलीट करने के लिए नोट पर राइट-क्लिक करें।';

  @override
  String get pinsNothingPinnedHereYetDesk =>
      'यहाँ अभी कुछ पिन नहीं है। किसी मैसेज पर राइट-क्लिक करें और पिन करें चुनें, वह यहाँ चैट के सभी लोगों के लिए रहेगा।';

  @override
  String get chatGalleryDesk => 'तस्वीरें';

  @override
  String get groupChatGalleryDesk => 'तस्वीरें';

  @override
  String get photoChooseDesk => 'तस्वीर की फ़ाइल चुनें';

  @override
  String get wallpaperFromYourPhotosDesk => 'तस्वीर की फ़ाइल से';

  @override
  String get notificationsSoundAndVibrationDesk => 'आवाज़';

  @override
  String get notificationsPlaySound => 'आवाज़ चलाएँ';

  @override
  String get notificationsPlaySoundHint => 'इस कंप्यूटर पर हर सूचना के साथ';

  @override
  String bridgesShareBridgeN(String n) {
    return 'ब्रिज $n शेयर करें';
  }

  @override
  String get bridgesShareThisBridge => 'यह ब्रिज शेयर करें';

  @override
  String get bridgesShareItPrivately =>
      'इसे निजी तौर पर, भरोसे के लोगों के साथ शेयर करें। जो ब्रिज सार्वजनिक पन्नों से दूर रहता है, वह ज़्यादा समय तक चलता है।';

  @override
  String get bridgesCopyBridge => 'ब्रिज कॉपी करें';

  @override
  String get bridgesBridgeCopied => 'ब्रिज कॉपी हुआ';

  @override
  String get bridgesSendBridgeTo => 'ब्रिज भेजें';

  @override
  String get linkedAddOnPhone =>
      'लोगों को अपने फ़ोन पर जोड़ें। वे यहाँ भी दिखेंगे।';

  @override
  String get linkedLinkOnPhone => 'यह लिंक अपने फ़ोन पर खोलें।';

  @override
  String get linkedDoOnPhone => 'यह अपने फ़ोन पर करें।';

  @override
  String get tipsTitle => 'Kryfo का सहयोग करें';

  @override
  String get tipsHeadline => 'Kryfo को *सबके लिए मुफ़्त* रखें';

  @override
  String get tipsLine =>
      'न विज्ञापन, न निवेशक, न अकाउंट। टिप से सर्वरों और Kryfo पर होने वाले काम का खर्च चलता है।';

  @override
  String get tipsLeave => 'टिप दें';

  @override
  String get tipsYours => 'आपका';

  @override
  String get tipsAsking => 'Google Play से कीमतें पूछी जा रही हैं';

  @override
  String get tipsBadgeOnly =>
      'टिप से आपको एक समर्थक बैज मिलता है, और कुछ नहीं। Kryfo में सब कुछ सबके लिए मुफ़्त रहता है, टिप दें या न दें।';

  @override
  String get tipsThroughPlay =>
      'भुगतान Google Play से होता है। हम आपके कार्ड की जानकारी या आपका नाम कभी नहीं देखते।';

  @override
  String get tipsBadgeStays =>
      'बैज इसी फ़ोन पर रहता है। मैं में आप चुनते हैं कि वह दिखे या नहीं, और आपके संपर्क उसे देखें या नहीं।';

  @override
  String get tipsRestore => 'मेरा बैज वापस लाएँ';

  @override
  String get tipsRestoreLine =>
      'पहले टिप दी थी? उसी Google अकाउंट से साइन इन किए किसी भी फ़ोन पर आपका बैज वापस आ जाता है।';

  @override
  String tipsRestored(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter': 'आपका समर्थक बैज वापस आ गया',
      'patron': 'आपका संरक्षक बैज वापस आ गया',
      'guardian': 'आपका रक्षक बैज वापस आ गया',
      'other': 'आपका समर्थक बैज वापस आ गया',
    });
    return '$_temp0';
  }

  @override
  String get tipsNothingToRestore =>
      'इस Google अकाउंट से अभी तक कोई टिप नहीं दी गई';

  @override
  String get tipsUnavailable =>
      'टिप Google Play से दी जाती है। इस फ़ोन पर Google Play चलते ही टिप यहाँ दिखेगी।';

  @override
  String get tipsSoon => 'टिप जल्द ही यहाँ शुरू होगी।';

  @override
  String get tipsPending =>
      'Google Play अभी आपका भुगतान पूरा कर रहा है। भुगतान होते ही आपका बैज आ जाएगा।';

  @override
  String get tipsFailed =>
      'Google Play ने भुगतान पूरा नहीं किया। थोड़ी देर में फिर कोशिश करें।';

  @override
  String get tipsThanks => 'धन्यवाद';

  @override
  String tipsGranted(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter':
          'अब आपके पास समर्थक बैज है। इससे और कुछ नहीं खुलता: Kryfo में सब कुछ सबके लिए मुफ़्त रहता है।',
      'patron':
          'अब आपके पास संरक्षक बैज है। इससे और कुछ नहीं खुलता: Kryfo में सब कुछ सबके लिए मुफ़्त रहता है।',
      'guardian':
          'अब आपके पास रक्षक बैज है। इससे और कुछ नहीं खुलता: Kryfo में सब कुछ सबके लिए मुफ़्त रहता है।',
      'other':
          'अब आपके पास समर्थक बैज है। इससे और कुछ नहीं खुलता: Kryfo में सब कुछ सबके लिए मुफ़्त रहता है।',
    });
    return '$_temp0';
  }

  @override
  String tipsKept(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter':
          'टिप के लिए धन्यवाद। आपका समर्थक बैज बना रहता है, वह ऊँचा है।',
      'patron': 'टिप के लिए धन्यवाद। आपका संरक्षक बैज बना रहता है, वह ऊँचा है।',
      'guardian': 'टिप के लिए धन्यवाद। आपका रक्षक बैज बना रहता है, वह ऊँचा है।',
      'other': 'टिप के लिए धन्यवाद। आपका समर्थक बैज बना रहता है, वह ऊँचा है।',
    });
    return '$_temp0';
  }

  @override
  String get tipsProfileCard => 'Kryfo को स्वतंत्र रखने के लिए टिप दें';

  @override
  String chatDeviceLinked(Object name) {
    return '$name ने एक नया डिवाइस जोड़ा';
  }

  @override
  String chatDeviceRemoved(Object name) {
    return '$name ने एक डिवाइस हटाया';
  }

  @override
  String chatDeviceListUnchecked(Object name) {
    return '$name की डिवाइस सूची जाँची नहीं जा सकी';
  }

  @override
  String get notesDropToKeep => 'रखने के लिए यहाँ छोड़ें';

  @override
  String get notesOnAllDevices => 'आपके सभी डिवाइस पर';

  @override
  String get notesKeepAnything =>
      'शब्द, फ़ोटो और फ़ाइलें यहाँ रखें। ये आपके सभी डिवाइस पर दिखते हैं।';

  @override
  String get notesGoneEverywhere =>
      'यह आपके सभी डिवाइस से हमेशा के लिए हट जाता है।';

  @override
  String get notesDeleteAllEverywhere =>
      'हर नोट आपके सभी डिवाइस से हमेशा के लिए हट जाएगा।';

  @override
  String get notesDeleteAllHereOnly =>
      'हर नोट सिर्फ़ इसी डिवाइस से हटेगा। आपका फ़ोन उन्हें रखता है।';

  @override
  String get notesAddItem => 'फ़ोटो या फ़ाइल जोड़ें';

  @override
  String get notesVoiceNotKept => 'आपका वॉइस नोट नहीं रखा गया';

  @override
  String get handleOlderKryfo =>
      'वे Kryfo का पुराना संस्करण इस्तेमाल करते हैं। उनसे अपडेट करने को कहें, फिर उन्हें जोड़ें।';

  @override
  String groupMemberNeedsUpdate(Object name) {
    return '$name Kryfo का पुराना संस्करण इस्तेमाल करते हैं। यहाँ संदेश पाने के लिए उन्हें अपडेट करना होगा।';
  }

  @override
  String get groupMembersNeedUpdate =>
      'कुछ सदस्य Kryfo का पुराना संस्करण इस्तेमाल करते हैं। यहाँ संदेश पाने के लिए उन्हें अपडेट करना होगा।';

  @override
  String get onboardingAlwaysOnNotice =>
      'Kryfo बंद होने पर भी संदेश आएँ, इसके लिए Android को एक बिना आवाज़ वाली स्थायी सूचना चाहिए।';

  @override
  String get toolsSendToAChat => 'किसी चैट में भेजें';

  @override
  String get toolsOneFileAtATime => 'एक बार में एक फ़ाइल';

  @override
  String get toolsLockThisFile => 'यह फ़ाइल लॉक करें';

  @override
  String get toolsLockThisFileLine =>
      'Kryfo इसे पासवर्ड से लॉक कर सकता है, ताकि सिर्फ़ उसे जानने वाला ही इसे खोल सके।';

  @override
  String get toolsDropHere => 'किसी टूल में खोलने के लिए फ़ाइल यहाँ छोड़ें';

  @override
  String get toolsCopyPicture => 'तस्वीर कॉपी करें';

  @override
  String get toolsPictureCopied => 'तस्वीर कॉपी हो गई';

  @override
  String get toolsCouldNotCopy => 'तस्वीर कॉपी नहीं हो पाई';

  @override
  String get cleanNotYetHere => 'यह तस्वीर अभी यहाँ साफ़ नहीं हो सकती';

  @override
  String get cleanNotYetHereLine =>
      'आने वाला अपडेट ऐसी तस्वीरें कंप्यूटर पर भी साफ़ करेगा। आपकी तस्वीर बिल्कुल वैसी ही है जैसी थी।';

  @override
  String get deskLinkRowHint => 'अपने फ़ोन का Kryfo यहाँ इस्तेमाल करें';

  @override
  String get deskLinkHead => 'अपने फ़ोन का Kryfo यहाँ इस्तेमाल करें';

  @override
  String get deskLinkLine =>
      'इसके बाद यह कंप्यूटर आपके फ़ोन की चैट और संपर्क दिखाएगा और आपकी ओर से भेजेगा।';

  @override
  String get deskLinkGoesTitle => 'पहले यह कंप्यूटर मिटाया जाएगा';

  @override
  String get deskLinkGoesLine =>
      'इस कंप्यूटर पर इसकी अपनी पहचान, इसकी चैट और इसके संपर्क हटा दिए जाएँगे। छिपी चैट, नकली Kryfo और अपने लिए नोट भी चले जाएँगे। आपके अपने फ़ोल्डरों में सहेजी फ़ाइलें रहेंगी।';

  @override
  String get deskLinkBackupRow => 'पहले बैकअप लें';

  @override
  String get deskLinkBackupHint =>
      'इस कंप्यूटर की चैट एक फ़ाइल में रखता है, 12 या अधिक अक्षरों के पासफ़्रेज़ के साथ';

  @override
  String get deskLinkConfirmLine =>
      'इस कंप्यूटर की पहचान और चैट मिटा दी जाएँगी। फिर Kryfo स्कैन करने के कोड के साथ फिर से खुलेगा।';

  @override
  String get deskLinkConfirmYes => 'मिटाएँ और जोड़ें';

  @override
  String get deskLinkReplace => 'इस कंप्यूटर की पहचान बदलें';

  @override
  String get deskLinkErasing => 'यह कंप्यूटर मिटाया जा रहा है';

  @override
  String get deskLinkErasingLine =>
      'Kryfo थोड़ी देर में स्कैन करने के कोड के साथ फिर से खुलेगा।';

  @override
  String get deskLinkNotStarted =>
      'जोड़ना शुरू नहीं हो सका। बाद में फिर कोशिश करें।';

  @override
  String get settingsLinkedToYourPhone => 'आपके फ़ोन से जुड़ा है';

  @override
  String get settingsLinkedPhoneHint => 'बैकअप और न्योते फ़ोन पर ही रहते हैं';

  @override
  String get settingsUnlinkComputer => 'इस कंप्यूटर को अलग करें';

  @override
  String get settingsUnlinkComputerTitle => 'इस कंप्यूटर को अलग करें?';

  @override
  String get settingsUnlinkComputerLine =>
      'इस कंप्यूटर की चैट हटा दी जाएँगी। आपका फ़ोन सब कुछ रखता है।';

  @override
  String get metaReaderColourProfileName => 'कलर प्रोफ़ाइल का नाम';

  @override
  String get cleanPixelMarksStay =>
      'पिक्सल में ही छिपे निशान, जैसे इमेज बनाने वाले टूल के छिपे वॉटरमार्क, और तस्वीर में दिखने वाली हर चीज़ वैसी ही रहती है।';

  @override
  String translateOfferDownload(Object language, Object size) {
    return '$language डाउनलोड करें ($size)?';
  }

  @override
  String translateLineDownloading(Object language) {
    return '$language डाउनलोड हो रही है…';
  }

  @override
  String translateLineWaitsWifi(Object language) {
    return '$language डाउनलोड करने के लिए Wi-Fi का इंतज़ार';
  }

  @override
  String get translateWaitsWifi =>
      'Wi-Fi का इंतज़ार है। यह फ़ोन Wi-Fi पर आते ही डाउनलोड अपने आप शुरू हो जाएगा।';

  @override
  String get translateWaitsWifiDesk =>
      'Wi-Fi का इंतज़ार है। यह कंप्यूटर Wi-Fi पर आते ही डाउनलोड अपने आप शुरू हो जाएगा।';

  @override
  String get translateWaitsWifiShort => 'Wi-Fi का इंतज़ार';

  @override
  String translatePackLineTwo(Object language, Object other, Object size) {
    return 'मैसेज का अनुवाद इसी फ़ोन पर होता है और वे इससे कभी बाहर नहीं जाते। इसके लिए $language और $other भाषा पैक चाहिए, कुल लगभग $size, Tor से एक बार डाउनलोड होते हैं।';
  }

  @override
  String translatePackLineTwoDesk(Object language, Object other, Object size) {
    return 'मैसेज का अनुवाद इसी कंप्यूटर पर होता है और वे इससे कभी बाहर नहीं जाते। इसके लिए $language और $other भाषा पैक चाहिए, कुल लगभग $size, Tor से एक बार डाउनलोड होते हैं।';
  }

  @override
  String get translateLanguagesHint =>
      'हर भाषा एक बार डाउनलोड होती है, फिर इसी फ़ोन पर अनुवाद करती है';

  @override
  String get translateLanguagesHintDesk =>
      'हर भाषा एक बार डाउनलोड होती है, फिर इसी कंप्यूटर पर अनुवाद करती है';

  @override
  String get translateSuggested => 'सुझाई गई';

  @override
  String get translateMoreLanguages => 'और भाषाएँ';

  @override
  String get translateWaysBoth => 'अंग्रेज़ी से और अंग्रेज़ी में';

  @override
  String get translateWaysInto => 'सिर्फ़ अंग्रेज़ी में अनुवाद करती है';

  @override
  String get translateWaysFrom => 'सिर्फ़ अंग्रेज़ी से अनुवाद करती है';

  @override
  String get translateGet => 'डाउनलोड करें';

  @override
  String get translateRemove => 'हटाएँ';

  @override
  String translateRemoveTitle(Object language) {
    return '$language हटाएँ?';
  }

  @override
  String translateRemoveLine(Object size) {
    return 'इससे $size जगह खाली होगी। इससे सेव किए गए अनुवाद भी डिलीट हो जाएँगे। आप इसे कभी भी फिर से डाउनलोड कर सकते हैं।';
  }

  @override
  String get translateResumeShort => 'जारी रखें';

  @override
  String get translateTagApp => 'ऐप की भाषा';

  @override
  String get translateTagRead => 'आप इसे पढ़ते हैं';

  @override
  String get chatInboxAnswerFromPhone => 'इस चैट का जवाब अपने फ़ोन से दें।';

  @override
  String get chatInboxSendsWhenPhoneOnline => 'आपका फ़ोन ऑनलाइन होते ही जाएगा।';

  @override
  String get chatInboxFilesFromPhone => 'फ़ाइलें अपने फ़ोन से भेजें।';

  @override
  String get devicesManyAnswersNotice => 'अपना कंप्यूटर जाँचें';

  @override
  String devicesManyAnswersLine(String name, String count) {
    return '$name ने एक घंटे में $count से ज़्यादा जवाब भेजने की कोशिश की। अगर यह आप नहीं थे, तो इसे हटा दें।';
  }

  @override
  String get fileViewInKryfo => 'Kryfo में देखें';

  @override
  String get fileOpenWith => 'इससे खोलें…';

  @override
  String get fileOpenWithNote =>
      'दूसरा ऐप यह फ़ाइल देख सकता है. तब तक Kryfo इसे एन्क्रिप्ट करके रखता है.';

  @override
  String get fileOtherAppKeepsCopy => 'दूसरा ऐप इसकी एक कॉपी रखता है.';

  @override
  String fileFrom(String name) {
    return '$name से';
  }

  @override
  String fileLines(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n पंक्तियाँ',
      one: '$n पंक्ति',
    );
    return '$_temp0';
  }

  @override
  String get fileNotWords =>
      'यह फ़ाइल टेक्स्ट नहीं है. आप इसे सेव कर सकते हैं या दूसरे ऐप से खोल सकते हैं.';

  @override
  String fileShowsFirst(String size) {
    return 'यहाँ पहले $size दिख रहे हैं. पूरी फ़ाइल पढ़ने के लिए उसे सेव करें.';
  }

  @override
  String filePages(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n पेज',
      one: '$n पेज',
    );
    return '$_temp0';
  }

  @override
  String filePageOf(String page, String total) {
    return '$page / $total';
  }

  @override
  String filePage(String page) {
    return 'पेज $page';
  }

  @override
  String get fileSearchIn => 'फ़ाइल में खोजें';

  @override
  String get fileSearchHint => 'इस PDF में शब्द खोजें';

  @override
  String get fileZoomIn => 'ज़ूम इन';

  @override
  String get fileZoomOut => 'ज़ूम आउट';

  @override
  String get filePdfLocked =>
      'इस PDF पर पासवर्ड है. पढ़ने के लिए इसे दूसरे ऐप से खोलें.';

  @override
  String get filePdfUnreadable =>
      'Kryfo यह PDF नहीं दिखा सकता. आप इसे सेव कर सकते हैं या दूसरे ऐप से खोल सकते हैं.';

  @override
  String get soundOpenPlayer => 'प्लेयर खोलता है';

  @override
  String get soundSpeed => 'प्लेबैक स्पीड';

  @override
  String get soundClosePlayer => 'प्लेयर बंद करें';

  @override
  String get soundPlayingInKryfo => 'Kryfo में चल रहा है';

  @override
  String get soundBack15 => '15 सेकंड पीछे';

  @override
  String get soundForward15 => '15 सेकंड आगे';

  @override
  String get soundRepeat => 'दोहराएँ';

  @override
  String get soundUpNext => 'आगे';

  @override
  String soundVoiceFrom(String name) {
    return '$name का वॉइस मैसेज';
  }

  @override
  String get sendSheetTo => 'इन्हें भेजें:';

  @override
  String get sendSheetCleaned => 'भेजने से पहले साफ़ किया जाता है';

  @override
  String get sendSheetFiles => 'फ़ाइलें';

  @override
  String get sendSheetRecent => 'हाल के';

  @override
  String get sendSheetChoosePhotos => 'फ़ोटो और वीडियो चुनें';

  @override
  String get sendSheetBrowseFiles => 'इस फ़ोन की सभी फ़ाइलें देखें';

  @override
  String get sendSheetNoRecent =>
      'आपकी चैट में भेजी और मिली फ़ाइलें यहाँ दिखती हैं.';

  @override
  String sendSheetChosen(String n) {
    return 'चुना गया, क्रम $n';
  }

  @override
  String get sendSheetAsFile => 'फ़ाइल के रूप में भेजें';

  @override
  String get sendSheetAsFileLine => 'मूल क्वालिटी, बिना कंप्रेशन';

  @override
  String sendSheetSend(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n भेजें',
    );
    return '$_temp0';
  }

  @override
  String sharedWith(String name) {
    return '$name के साथ शेयर किया';
  }

  @override
  String sharedIn(String name) {
    return '$name में शेयर किया';
  }

  @override
  String get sharedTabMedia => 'मीडिया';

  @override
  String get sharedTabFiles => 'फ़ाइलें';

  @override
  String get sharedTabVoice => 'वॉइस';

  @override
  String get sharedTabLinks => 'लिंक';

  @override
  String get sharedNoPhotos => 'इस चैट में भेजी गई फ़ोटो यहाँ दिखती हैं.';

  @override
  String get sharedNoFiles => 'इस चैट में भेजी गई फ़ाइलें यहाँ दिखती हैं.';

  @override
  String get sharedNoVoice => 'इस चैट के वॉइस मैसेज यहाँ दिखते हैं.';

  @override
  String get sharedNoLinks => 'इस चैट में भेजे गए लिंक यहाँ दिखते हैं.';

  @override
  String get sharedYourVoice => 'आपका वॉइस मैसेज';

  @override
  String get sharedOpensLink => 'लिंक को दूसरे ऐप में खोलता है';

  @override
  String voiceSpeedLabel(String speed) {
    return '${speed}x';
  }

  @override
  String voiceSpeedA11y(String speed) {
    return 'चलाने की गति $speed';
  }

  @override
  String voiceSeekValue(String at, String total) {
    return '$total में से $at';
  }

  @override
  String get chatReactHeart => 'दिल से प्रतिक्रिया दें';

  @override
  String get homeDraftLabel => 'ड्राफ़्ट:';

  @override
  String homeDraftA11y(String text) {
    return 'ड्राफ़्ट: $text';
  }

  @override
  String handleSuggestFree(String handle) {
    return '@$handle उपलब्ध है, इसे चुनें';
  }

  @override
  String get notifRequestsChannel => 'संदेश अनुरोध';

  @override
  String get notifRequestsChannelLine =>
      'उन लोगों के पहले संदेश जिन्हें आपने अभी नहीं जोड़ा';

  @override
  String get notifRequestPopups => 'संदेश अनुरोधों के लिए पॉप-अप';

  @override
  String get notifRequestPopupsHint =>
      'चालू होने पर नया अनुरोध आवाज़ के साथ दिखता है। बंद होने पर वह चुपचाप आपकी सूचनाओं में रहता है।';

  @override
  String homeGroupLine(String name, String preview) {
    return '$name: $preview';
  }

  @override
  String get bannerOpen => 'चैट खोलें';

  @override
  String bannerOpenWith(String name) {
    return '$name के साथ चैट खोलें';
  }

  @override
  String bannerNewMessages(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString नए संदेश',
      one: '$countString नया संदेश',
    );
    return '$_temp0';
  }

  @override
  String get composerSendSilent => 'बिना आवाज़ के भेजें';

  @override
  String get composerSendHoldHint => 'और विकल्पों के लिए दबाकर रखें';

  @override
  String get homeGroupShotsLine => 'संदेश';

  @override
  String get settingsShareMenu => 'शेयर मेन्यू में चैट दिखाएँ';

  @override
  String get settingsShareMenuHint =>
      'किसी दूसरे ऐप से शेयर करते समय आपकी हाल की चैट नाम से दिखती हैं।';

  @override
  String get settingsShareMenuHintLocked =>
      'आपकी हाल की चैट दूसरे ऐप के शेयर मेन्यू में नाम से तभी दिखती हैं जब Kryfo अनलॉक हो।';

  @override
  String get settingsShareMenuDisguised =>
      'जब तक Kryfo दूसरा आइकन पहने है, आपकी चैट शेयर मेन्यू से बाहर रहती हैं।';

  @override
  String get connCheckTitle => 'मेरा कनेक्शन जांचें';

  @override
  String get connCheckLine =>
      'बस यही साझा होगा: Tor यहां से कैसे बाहर निकलता है, इसमें कितना समय लगा और क्या नहीं हो पाया। कोई IP पता नहीं, कोई लोकेशन नहीं, कोई ब्रिज लाइन नहीं, डिवाइस की कोई पहचान नहीं। जब तक आप इसे कॉपी या भेजते नहीं, कुछ भी बाहर नहीं जाता।';

  @override
  String get connCheckEnglish =>
      'यह जांच अंग्रेज़ी में है, ताकि हर जगह एक जैसी पढ़ी जाए।';

  @override
  String get connCheckAgain => 'फिर से जांचें';

  @override
  String get connCheckSend => 'Marios को भेजें';

  @override
  String get storyRow => 'अपनी कहानी बताएं';

  @override
  String get storyHint =>
      'आप Kryfo क्यों इस्तेमाल करते हैं, अपने शब्दों में। कहानियां सिर्फ़ आपकी सहमति से साझा होती हैं।';

  @override
  String get storyHintAnon =>
      'आप Kryfo क्यों इस्तेमाल करते हैं, अपने शब्दों में। आप गुमनाम रहकर लिख सकते हैं, और कहानियां सिर्फ़ आपकी सहमति से साझा होती हैं।';

  @override
  String get storyTemplate =>
      'मैं Kryfo क्यों इस्तेमाल करता/करती हूं:\n\nजहां मैं रहता/रहती हूं, वहां क्या ब्लॉक है:\n\nक्षेत्र (वैकल्पिक):\n';

  @override
  String get chatFindingMessage => 'मैसेज ढूँढ रहे हैं';

  @override
  String get chatMessageGone => 'वह मैसेज अब नहीं है।';

  @override
  String get gifFavTab => 'पसंदीदा';

  @override
  String get gifFavAdd => 'पसंदीदा में जोड़ें';

  @override
  String get gifFavAdded => 'पसंदीदा में जोड़ा गया';

  @override
  String get gifFavCouldNotAdd =>
      'पसंदीदा में नहीं जुड़ सका। फिर से कोशिश करें।';

  @override
  String get gifFavRemove => 'पसंदीदा से हटाएँ';

  @override
  String get gifFavRemoved => 'पसंदीदा से हटाया गया';

  @override
  String get gifFavEdit => 'पसंदीदा बदलें';

  @override
  String get gifFavEditTitle => 'आपके *पसंदीदा*';

  @override
  String get gifFavEditHint =>
      'क्रम बदलने के लिए दबाकर खींचें। हटाने के लिए क्रॉस पर टैप करें।';

  @override
  String get gifFavKept =>
      'इस फ़ोन पर एन्क्रिप्ट करके रखे गए। GIF खोज बंद होने पर भी चलता है।';

  @override
  String get gifFavKeptDesk =>
      'इस कंप्यूटर पर एन्क्रिप्ट करके रखे गए। GIF खोज बंद होने पर भी चलता है।';

  @override
  String get gifFavEmptyTitle => 'अभी कोई पसंदीदा नहीं';

  @override
  String get gifFavEmptyLine =>
      'यहाँ जोड़ने के लिए किसी चैट में या GIF में किसी GIF को दबाकर रखें।';

  @override
  String get gifFavMoveEarlier => 'पहले ले जाएँ';

  @override
  String get gifFavMoveLater => 'बाद में ले जाएँ';

  @override
  String gifFavTileA11y(String number) {
    return 'पसंदीदा GIF $number';
  }
}
