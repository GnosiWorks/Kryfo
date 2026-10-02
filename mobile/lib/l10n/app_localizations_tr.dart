// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get atmosphereNone => 'Yok';

  @override
  String get atmosphereEmber => 'Kor';

  @override
  String get atmosphereDusk => 'Akşam';

  @override
  String get atmosphereMoss => 'Yosun';

  @override
  String get atmosphereRose => 'Gül';

  @override
  String get atmosphereDots => 'Noktalar';

  @override
  String get atmosphereGrid => 'Izgara';

  @override
  String get atmosphereWaves => 'Dalgalar';

  @override
  String get atmosphereRain => 'Yağmur';

  @override
  String get atmosphereLateNight => 'Gece yarısı';

  @override
  String get atmosphereWarmAfternoon => 'Sıcak ikindi';

  @override
  String get atmosphereSnow => 'Kar';

  @override
  String get atmosphereDesert => 'Çöl';

  @override
  String get atmospherePaper => 'Kağıt';

  @override
  String get backupThatPassphraseDoesNot =>
      'Bu parola ifadesi bu dosyayı açmıyor';

  @override
  String get backupThatFileIsNot => 'Bu dosya bir Kryfo yedeği değil';

  @override
  String get backupThisBackupIsFrom =>
      'Bu yedek daha yeni bir Kryfo sürümünden. Uygulamayı güncelle, sonra tekrar dene';

  @override
  String get backupThisFileIsDamaged => 'Bu dosya hasarlı ve okunamıyor';

  @override
  String get backupCouldNotMakeThe => 'Anahtar oluşturulamadı';

  @override
  String get contactCardMessageMeOn => 'Bana şuradan yaz';

  @override
  String get contactCardScanItOrType =>
      'Kodu tara ya da üç kelimeyi Kryfo’ya yaz.\nBu kart senin hakkında bundan başka bir şey bilmiyor.';

  @override
  String contactCardMessageMeOnKryfo(Object haloId) {
    return 'Bana Kryfo’dan yaz · $haloId';
  }

  @override
  String get contactStatusBlocked => 'Engellendi';

  @override
  String get contactStatusKeysVerifiedInPerson =>
      'Anahtarlar yüz yüze doğrulandı';

  @override
  String get contactStatusWaitingInRequests => 'İsteklerde bekliyor';

  @override
  String get contactStatusAddedByHand => 'Elle eklendi';

  @override
  String get deliveryModeAlwaysOn => 'Hep açık';

  @override
  String get deliveryModeCheckIns => 'Kontroller';

  @override
  String get deliveryModeThroughAHelperApp => 'Yardımcı uygulama ile';

  @override
  String get deliveryModeNotYet => 'henüz yok';

  @override
  String get deliveryModeJustNow => 'az önce';

  @override
  String deliveryModeMinAgo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString dk önce',
      one: '$countString dk önce',
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
      other: '$countString saat önce',
      one: '$countString saat önce',
    );
    return '$_temp0';
  }

  @override
  String get deliveryModeYesterday => 'dün';

  @override
  String deliveryModeDaysAgo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString gün önce',
      one: '$countString gün önce',
    );
    return '$_temp0';
  }

  @override
  String get deliveryModeConnected => 'Bağlı';

  @override
  String get deliveryModeConnecting => 'Bağlanıyor';

  @override
  String get deliveryModeNotConnected => 'Bağlı değil';

  @override
  String get deliveryModeCheckingNow => 'Kontrol ediliyor';

  @override
  String deliveryModeLastCheckIn(Object agoLine) {
    return 'son kontrol $agoLine';
  }

  @override
  String get deliveryModeNoCheckInYet => 'henüz kontrol yok';

  @override
  String deliveryModeConnectedNow(Object last) {
    return 'Şu an bağlı · $last';
  }

  @override
  String deliveryModeConnecting2(Object last) {
    return 'Bağlanıyor · $last';
  }

  @override
  String get deliveryModeNoCheckInYet2 => 'Henüz kontrol yok';

  @override
  String deliveryModeLastChecked(Object agoLine) {
    return 'Son kontrol $agoLine';
  }

  @override
  String get deliveryModeAHelperApp => 'yardımcı uygulama';

  @override
  String deliveryModeWokenByNoWake(Object who) {
    return 'Uyandıran: $who · henüz uyandırma yok';
  }

  @override
  String deliveryModeWokenByLastWake(Object who, Object agoLine) {
    return 'Uyandıran: $who · son uyandırma $agoLine';
  }

  @override
  String get introBudgetTomorrow => 'yarın';

  @override
  String introBudgetInDays(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString gün sonra',
      one: '$countString gün sonra',
    );
    return '$_temp0';
  }

  @override
  String get introBudgetInAnHour => 'bir saat sonra';

  @override
  String introBudgetInHours(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString saat sonra',
      one: '$countString saat sonra',
    );
    return '$_temp0';
  }

  @override
  String get introBudgetInAFewMinutes => 'birkaç dakika sonra';

  @override
  String get lockStateUnlockKryfo => 'Kryfo kilidini aç';

  @override
  String get appInvalidUri => 'Geçersiz uri';

  @override
  String appBundleError(Object e) {
    return 'Paket hatası: $e';
  }

  @override
  String appAlreadySaved(Object parsed) {
    return 'Zaten kayıtlı: $parsed';
  }

  @override
  String appAddedYouCanMessage(Object parsed) {
    return '$parsed eklendi · artık ona yazabilirsin';
  }

  @override
  String appPeerImportedV1(Object parsed) {
    return 'Eş içe aktarıldı (v1): $parsed';
  }

  @override
  String appLongWindow(Object line) {
    return '$line uzun aralık';
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
      other: '$pString sayfa',
      one: '$pString sayfa',
    );
    String _temp1 = intl.Intl.pluralLogic(
      e,
      locale: localeName,
      other: '$eString olay',
      one: '$eString olay',
    );
    return '$line ($heldString/$subsString, bağlanma $c sn, $_temp0, $_temp1)';
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
      other: '$pString sayfa',
      one: '$pString sayfa',
    );
    String _temp1 = intl.Intl.pluralLogic(
      e,
      locale: localeName,
      other: '$eString olay',
      one: '$eString olay',
    );
    return '$line (bağlanma $c sn, $_temp0, $_temp1)';
  }

  @override
  String appSDropped(Object host, Object secs) {
    return '$host $secs sn koptu';
  }

  @override
  String appS(Object host, Object secs) {
    return '$host $secs sn';
  }

  @override
  String get appTorWouldNotWake => 'Tor uyanmadı';

  @override
  String get appCheckStarted => 'Başladı';

  @override
  String get appTorNotReadyIn => 'Tor 75 sn içinde hazır olmadı';

  @override
  String get appOk => 'Tamam';

  @override
  String get appOkNoRelayBegan => 'Tamam, aktarıcı başlamadı';

  @override
  String get appOkCapped => 'Tamam, kesildi';

  @override
  String appSBy(Object how, int secs, String why) {
    final intl.NumberFormat secsNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String secsString = secsNumberFormat.format(secs);

    String _temp0 = intl.Intl.selectLogic(why, {
      'push': '$how, $secsString sn, yardımcı ile',
      'other': '$how, $secsString sn, görev ile',
    });
    return '$_temp0';
  }

  @override
  String get appAnAttachmentCouldNot => 'Bir ek bu telefona kaydedilemedi';

  @override
  String get appGroup2 => 'Grup';

  @override
  String get appVoiceMessage => 'Sesli mesaj';

  @override
  String get appPhoto => 'Fotoğraf';

  @override
  String get appNewRequest => 'Yeni istek';

  @override
  String get appSomeoneYouHaveNot => 'Eklemediğin biri sana yazdı';

  @override
  String get appSettingUpYourKeys => 'Anahtarların hazırlanıyor';

  @override
  String get appOpeningYourChats => 'Sohbetlerin açılıyor';

  @override
  String get appStartingTor => 'Tor başlatılıyor';

  @override
  String get appTimedMessagesAreNot =>
      'Süreli mesajlar silinmiyor. Kryfo’yu yeniden başlat';

  @override
  String get appVoiceMessage2 => 'Sesli mesaj';

  @override
  String appYou(Object body) {
    return 'Sen: $body';
  }

  @override
  String get appThisRoomHasAlready => 'Bu odanın süresi zaten doldu';

  @override
  String get appYouAreAlreadyIn => 'Zaten bu odadasın';

  @override
  String get appCouldNotMakeA => 'Oda anahtarı oluşturulamadı';

  @override
  String appJoinedButYourHello(Object linkName) {
    return 'Katıldın: $linkName, ama merhaban bekletildi';
  }

  @override
  String appJoined(Object linkName) {
    return 'Katıldın: $linkName';
  }

  @override
  String appJoinedButTheCreator(Object linkName) {
    return 'Katıldın: $linkName, ama odayı kurana henüz ulaşılamadı';
  }

  @override
  String get appBooting => 'Açılıyor...';

  @override
  String get appSettingUpYourIdentity => 'Kimliğin hazırlanıyor...';

  @override
  String get appAddSomeone => 'Birini ekle';

  @override
  String get appScanTheirCodeOr =>
      'Onun kodunu tara ya da sana verdiğini yapıştır: bir bağlantı, bir @kullanıcı adı ya da bir oda bağlantısı.';

  @override
  String get appScanTheirCode => 'Onun kodunu tara';

  @override
  String get appAKryfoLinkA =>
      'Bir Kryfo bağlantısı, oda bağlantısı ya da @wren';

  @override
  String get appAddThem => 'Ekle';

  @override
  String get appEveryWayToAdd => 'Birini eklemenin her yolu';

  @override
  String get appShowYourCodeSend =>
      'Kodunu göster, bağlantı gönder, kullanıcı adı al';

  @override
  String get appHelloFromTheOther => 'Öbür taraftan merhaba';

  @override
  String get appIdentityRestored => 'Kimlik geri yüklendi';

  @override
  String get appIdentityCreated => 'Kimlik oluşturuldu';

  @override
  String get appStartingTor30s => 'Tor başlatılıyor (~30 sn)...';

  @override
  String get appScanOrImportA => 'Önce bir eş tara ya da içe aktar';

  @override
  String get appEncryptingSending30s =>
      'Şifreleniyor + gönderiliyor (~30 sn)...';

  @override
  String get appTapStartListeningFirst =>
      'Önce “Dinlemeye başla” düğmesine dokun';

  @override
  String get appYourKryfo => 'Senin Kryfo’n';

  @override
  String get appUriCopied => 'Uri kopyalandı';

  @override
  String get appCopyUri => 'Uri’yi kopyala';

  @override
  String get appAddAKryfo => 'Bir Kryfo ekle';

  @override
  String get appScanQr => 'QR tara';

  @override
  String get appPairingCode => 'Eşleştirme kodu';

  @override
  String get appOrPaste => '- Ya da yapıştır -';

  @override
  String get commonCancel => 'İptal';

  @override
  String get appImport => 'İçe aktar';

  @override
  String get appDev => 'Geliştirici';

  @override
  String get appYourKryfo2 => 'Senin Kryfo’n:';

  @override
  String get appRestoredFromDisk => 'Diskten geri yüklendi';

  @override
  String get appStartListening => 'Dinlemeye başla';

  @override
  String get appListening => 'Dinleniyor';

  @override
  String get appShowMyQr => 'QR kodumu göster';

  @override
  String get appImportPeer => 'Eşi içe aktar';

  @override
  String get appPeer => 'Eş:';

  @override
  String get appMessageWillBeEncrypted => 'Mesaj (şifrelenecek)';

  @override
  String get appEncryptSend => 'Şifrele + gönder';

  @override
  String appStatus(Object status) {
    return 'Durum: $status';
  }

  @override
  String get appSpeedPrivacy => 'Hız ve gizlilik →';

  @override
  String get appGettingMessages => 'Mesaj alma →';

  @override
  String get appDisableAppLock => 'Uygulama kilidi kapatılsın mı?';

  @override
  String get appThePinWillBe =>
      'PIN kaldırılacak. Telefonun kimin elindeyse Kryfo’yu açtığında içini görecek.';

  @override
  String get appDisable => 'Kapat';

  @override
  String get appAppLockOn => 'Kilit · açık →';

  @override
  String get appAppLockOff => 'Kilit · kapalı →';

  @override
  String get appTorIsOff => 'Tor kapalı';

  @override
  String get appConnectedRoutedThrough3 =>
      'Bağlı · 3 aktarıcı üzerinden yönlendiriliyor';

  @override
  String get appReadyToSendPublishing =>
      'Göndermeye hazır · adresin yayımlanıyor';

  @override
  String get appReadyToSendFinishing => 'Göndermeye hazır · kurulum bitiyor';

  @override
  String appConnecting(Object pct) {
    return 'Bağlanıyor · $pct';
  }

  @override
  String get appTor => 'Tor';

  @override
  String get appTorIsOffTurn => 'Tor kapalı. Gizli bağlanmak için aç.';

  @override
  String get appTheFirstConnectionTakes =>
      'İlk bağlantı, tor gizli bir rota kurarken bir iki dakika sürer. Sonra önbelleğe alınır, bu yüzden Kryfo’yu sonradan açmak çok daha hızlıdır.';

  @override
  String get appRelayAndFastModes =>
      'Aktarıcı ve Hızlı modları tor’u atlar ve daha hızlıdır. Ayarlarda, hız ve gizlilik bölümündeler; her biri bedelini söyler.';

  @override
  String get appViaRelay => 'Aktarıcı ile';

  @override
  String get appOffline => 'Çevrimdışı';

  @override
  String get appFast => 'Hızlı';

  @override
  String get appTorOff => 'Tor kapalı';

  @override
  String get appTorReady => 'Tor hazır';

  @override
  String get appConnecting2 => 'Bağlanıyor';

  @override
  String mediaProgressSendingKeepTheApp(Object v) {
    return 'Gönderiliyor · $v · uygulamayı açık tut';
  }

  @override
  String mediaProgressPausedOfWaitingFor(Object count, Object count2) {
    return 'Duraklatıldı · $count/$count2 · kalanı bekleniyor';
  }

  @override
  String mediaProgressReceivingMedia(Object v) {
    return 'Medya alınıyor · $v';
  }

  @override
  String get mediaProgressCancelSending => 'Gönderimi iptal et';

  @override
  String get metaReaderEndsBeforeItShould => 'erken bitiyor';

  @override
  String get metaReaderCouldNotBeRead => 'okunamadı';

  @override
  String get metaReaderExifThatCannotBe => 'okunamayan exif';

  @override
  String get metaReaderSamsungTrailer => 'samsung eki';

  @override
  String metaReaderChunk(Object type) {
    return '$type parçası';
  }

  @override
  String get metaReaderExifFlagSet => 'exif bayrağı açık';

  @override
  String get metaReaderXmpFlagSet => 'xmp bayrağı açık';

  @override
  String metaReaderAppBlock(Object id) {
    return 'uygulama bloğu $id';
  }

  @override
  String get metaReaderUuidBox => 'uuid kutusu';

  @override
  String metaReaderBox(Object printable) {
    return '$printable kutusu';
  }

  @override
  String get metaReaderAttachedData => 'ekli veri';

  @override
  String metaReaderItem(Object printable) {
    return '$printable öğesi';
  }

  @override
  String get miuiAutostartAlreadyAllowedToRun =>
      'Arka planda çalışmasına zaten izin var';

  @override
  String get miuiAutostartLetKryfoRunIn => 'Kryfo arka planda çalışsın';

  @override
  String get miuiAutostartYourPhonePausesApps =>
      'Telefonun pil tasarrufu için uygulamaları duraklatır. Bir istisna olmadan Kryfo kapalıyken mesaj alamaz.';

  @override
  String get commonAllow => 'İzin ver';

  @override
  String get commonSkip => 'Atla';

  @override
  String get miuiAutostartXiaomiTurnsOffBackground =>
      'Xiaomi arka plandaki uygulamaları varsayılan olarak kapatır. Otomatik başlatma olmadan Kryfo, uygulama kapalıyken mesajları iletemez. Sonraki ekranda listede Kryfo’yu bul ve yanındaki düğmeyi aç.';

  @override
  String get miuiAutostartOpenSettings => 'Ayarları aç';

  @override
  String get miuiAutostartCouldnTOpenIt =>
      'Açılamadı. Telefon ayarlarında otomatik başlatmayı ara';

  @override
  String get notificationsNewEncryptedMessagesFrom =>
      'Kişilerinden yeni şifreli mesajlar';

  @override
  String get notificationsNewMessage => 'Yeni mesaj';

  @override
  String get notificationsNewEncryptedMessagesFromYourContacts =>
      'Kişilerinden yeni şifreli mesajlar';

  @override
  String get notificationsNewMessage2 => 'Yeni mesaj';

  @override
  String get notificationsEncrypted => 'Şifreli';

  @override
  String get rooms24h => '24 sa';

  @override
  String roomsD(Object inDays) {
    return '$inDays g';
  }

  @override
  String roomsH(Object inHours) {
    return '$inHours sa';
  }

  @override
  String get rooms24Hours => '24 saat';

  @override
  String roomsDays(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString gün',
      one: '$countString gün',
    );
    return '$_temp0';
  }

  @override
  String get roomsAnHour => 'bir saat';

  @override
  String get roomsAboutAnHour => 'yaklaşık bir saat';

  @override
  String roomsHours(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString saat',
      one: '$countString saat',
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
      other: 'yaklaşık $countString saat',
      one: 'yaklaşık $countString saat',
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
      other: '$countString dakika',
      one: '$countString dakika',
    );
    return '$_temp0';
  }

  @override
  String get roomsAMinute => 'bir dakika';

  @override
  String get roomsExpired => 'Süresi doldu';

  @override
  String roomsDH(Object inDays, Object h) {
    return '$inDays g $h sa';
  }

  @override
  String roomsHM(Object inHours, Object m) {
    return '$inHours sa $m dk';
  }

  @override
  String roomsM(Object inMinutes) {
    return '$inMinutes dk';
  }

  @override
  String get scamShieldLooksLikeAScam => 'Dolandırıcılığa benziyor';

  @override
  String scamShieldThisNameMatches(Object shown) {
    return 'Bu ad $shown ile aynı';
  }

  @override
  String scamShieldNameMatchesYourContact(Object shown) {
    return 'Ad, kişin $shown ile aynı';
  }

  @override
  String scamShieldSameFaceAsYour(Object shown) {
    return 'Kişin $shown ile aynı yüz';
  }

  @override
  String get scamShieldContainsACryptoAddress =>
      'Bir kripto para adresi içeriyor';

  @override
  String get scamShieldMentionsMoneyAndUrgency =>
      'Hem paradan hem aciliyetten söz ediyor';

  @override
  String get scamShieldAsksYouToMove => 'Başka bir uygulamaya geçmeni istiyor';

  @override
  String get scamShieldLinksToALookalike =>
      'Tanınmış bir sitenin taklidine bağlantı veriyor';

  @override
  String get scamShieldALongOpenerFrom =>
      'Geçmişi olmayan birinden uzun bir ilk mesaj';

  @override
  String get scamShieldAsksForACode =>
      'Kod, cüzdan kurtarma ifadesi ya da kurtarma dosyası istiyor';

  @override
  String scamShieldAlso(Object shown) {
    return 'Ayrıca: ad, kişin $shown ile aynı';
  }

  @override
  String get commonBack => 'Geri';

  @override
  String get archivedArchived => 'Arşiv';

  @override
  String get archivedCount0 => 'Hiç';

  @override
  String get archivedCount1 => 'Bir';

  @override
  String get archivedCount2 => 'İki';

  @override
  String get archivedCount3 => 'Üç';

  @override
  String get archivedCount4 => 'Dört';

  @override
  String get archivedCount5 => 'Beş';

  @override
  String get archivedCount6 => 'Altı';

  @override
  String get archivedCount7 => 'Yedi';

  @override
  String get archivedCount8 => 'Sekiz';

  @override
  String get archivedCount9 => 'Dokuz';

  @override
  String get archivedCount10 => 'On';

  @override
  String get archivedChatRestingHereIt =>
      'Sohbet burada dinleniyor. O kişi yazana kadar sessiz kalır, sonra en üste döner.';

  @override
  String get archivedChatsRestingHere =>
      'Sohbet burada dinleniyor. Biri yazana kadar sessiz kalırlar, sonra en üste dönerler.';

  @override
  String get archivedNothingArchived => 'Arşiv boş';

  @override
  String get archivedArchivedChatsAreStill =>
      'Arşivdeki sohbetler hâlâ uçtan uca şifreli';

  @override
  String get archivedUnarchive => 'Arşivden çıkar';

  @override
  String get avatarPickerThePeopleYouMessage =>
      'Yazıştığın kişiler de bunu görür';

  @override
  String get avatarPickerBackToYourInitial => 'Baş harfine dön';

  @override
  String get avatarPickerThatOneIsYours => 'Bu senin';

  @override
  String get avatarPickerPickAFace => 'Bir yüz seç';

  @override
  String get commonSave => 'Kaydet';

  @override
  String get backupPassphraseMustBeAt =>
      'Parola ifadesi en az 6 karakter olmalı';

  @override
  String get backupPassphrasesDonTMatch => 'Parola ifadeleri eşleşmiyor';

  @override
  String get backupBackupSavedKeepThe =>
      'Yedek kaydedildi · parola ifadesini güvende tut';

  @override
  String get backupKryfoBackup => 'Kryfo yedeği';

  @override
  String get backupYourEncryptedKryfoBackup =>
      'Şifreli Kryfo yedeğin. Hem bu dosyayı HEM DE parola ifadeni güvende tut - geri yüklemek için ikisi de gerekir.';

  @override
  String get backupBackUpKryfo => 'Kryfo’yu yedekle';

  @override
  String get backupBackUp => 'Yedekle';

  @override
  String get backupACopyToKeep =>
      'Saklanacak bir kopya. Bu telefon olduğu gibi çalışmaya devam eder.';

  @override
  String get backupMoveToAnotherDevice => 'Başka cihaza taşı';

  @override
  String get backupTheFileTakesThis =>
      'Dosya bu kimliği yanında götürür. Oluşturulduğu anda bu telefon durur: buraya yeni hiçbir şey gelmez, buradan gönderilen hiçbir şey de kimseye ulaşmaz.';

  @override
  String get backupOneEncryptedFileYour =>
      'Tek bir şifreli dosya: kimliğin, kişilerin, her mesaj ve her fotoğraf, sesli not ve dosya. Diğer cihazda parola ifadesiyle içe aktar. O zamana kadar fikrini değiştirip bu telefonda kalabilirsin.';

  @override
  String get backupOneEncryptedFileYourIdentityYour =>
      'Tek bir şifreli dosya: kimliğin, kişilerin, her mesaj ve şu an bu telefonda olan her fotoğraf, sesli not ve dosya. Bugünden sonra söylenenler içinde olmaz, önemli olduğunda yenisini yap. Geri yüklemek için dosya ve parola ifadesi, ikisi de gerekir.';

  @override
  String get backupPassphrase => 'Parola ifadesi';

  @override
  String get backupConfirmPassphrase => 'Parola ifadesini doğrula';

  @override
  String backupWriting(Object progress) {
    return 'Yazılıyor… $progress';
  }

  @override
  String get backupCreating => 'Oluşturuluyor…';

  @override
  String get backupMakeTheFileAnd => 'Dosyayı oluştur ve taşı';

  @override
  String get backupCreateBackup => 'Yedek oluştur';

  @override
  String get backupNotMade => 'Yedek oluşturulamadı. Tekrar dene.';

  @override
  String get backupHiddenNotIn => 'Gizli sohbetler bu dosyada yok.';

  @override
  String get backupHiddenIncluded => 'Gizli sohbetlerin de bu dosyada.';

  @override
  String get backupMoveHiddenStay =>
      'Gizli sohbetler bu telefonda kalır ve onunla birlikte silinir.';

  @override
  String get backupHiddenGone =>
      'Kryfo kilitlenince gizli sohbetlerin kapandı. Onları gizli sohbet PIN’inle aç ve yedeği oradan al.';

  @override
  String get blockedBlocked => 'Engellenenler';

  @override
  String get blockedNoOneIsBlocked => 'Engellenen kimse yok';

  @override
  String get commonUnblock => 'Engeli kaldır';

  @override
  String get bridgesThatWasNotIt => 'Olmadı. İşte bir tane daha.';

  @override
  String get bridgesMoatFailed =>
      'tor projesine ulaşılamadı. Bir dakika sonra tekrar dene ya da aşağıya bir köprü satırı yapıştır.';

  @override
  String get bridgesGotBridgesSaveTo =>
      'Köprüler alındı · kullanmak için kaydet';

  @override
  String get bridgesConnected => 'Bağlı';

  @override
  String get bridgesNotThroughYetTor =>
      'Henüz geçemedi. Tor denemeye devam ediyor';

  @override
  String get bridgesBridges => 'Köprüler';

  @override
  String get bridgesTorIsBlockedWhere => 'Bulunduğun yerde tor engelli mi?';

  @override
  String get bridgesBridgesDisguiseYourConnection =>
      'Köprüler bağlantını kamufle eder, böylece dışarı çıkabilir. Bir giriş yolu seç, kaydet; tor onun üzerinden yeniden bağlanır.';

  @override
  String get bridgesBridgesOnlyChangeHow =>
      'Köprüler yalnızca tor’un nasıl bağlandığını değiştirir ve şu an Onion modunda değilsin. Burada ayarladığın kaydedilir, sadece geri geçene kadar bir işe yaramaz.';

  @override
  String get bridgesFromTheTorProject => 'Tor projesinden';

  @override
  String get bridgesNoise => 'Gürültü';

  @override
  String get bridgesGood => 'İyi';

  @override
  String get bridgesMakesTorTrafficLook =>
      'Tor trafiğini belirli hiçbir şeye benzemeyecek hale getirir. Engellenen çoğu ağ için en iyi varsayılan. Bir captcha çözersin, ardından sana birkaç satır verilir.';

  @override
  String get bridgesPrivateBridge => 'Özel köprü';

  @override
  String get bridgesALineFromA => 'Bir arkadaştan gelen satır';

  @override
  String get bridgesWhateverTheLineSays => 'Satır ne diyorsa';

  @override
  String get bridgesDepends => 'Duruma göre';

  @override
  String get bridgesGotABridgeLine =>
      'Güvendiğin birinden ya da bridges.torproject.org sitesinden bir köprü satırı mı aldın? Buraya yapıştır. Yalnızca obfs4 satırları; Kryfo diğerlerini henüz desteklemiyor.';

  @override
  String get bridgesPasteFromClipboard => 'Panodan yapıştır';

  @override
  String get bridgesUseBridges => 'Köprü kullan';

  @override
  String get bridgesNoLinesYet => 'Henüz satır yok';

  @override
  String bridges1LineSaved(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString satır kaydedildi',
      one: '$countString satır kaydedildi',
    );
    return '$_temp0';
  }

  @override
  String get bridgesRestartingTor => 'Tor yeniden başlıyor…';

  @override
  String bridgesFindingABridgeS(Object elapsed) {
    return 'Köprü aranıyor… $elapsed sn';
  }

  @override
  String bridgesStillTryingS(Object elapsed) {
    return 'Hâlâ deneniyor… $elapsed sn';
  }

  @override
  String get bridgesApplying => 'Uygulanıyor…';

  @override
  String get bridgesSaveAndReconnect => 'Kaydet ve yeniden bağlan';

  @override
  String get bridgesWhatABridgeIs => 'Köprü nedir';

  @override
  String get bridgesATorEntryPoint =>
      'Kimsenin yayımlamadığı bir tor giriş noktası; bağlantı tor’a benzemesin diye bir sarmalayıcı üzerinden ulaşılır. Rotanın geri kalanı her zamanki üç atlamadır.';

  @override
  String get bridgesLooksLike => 'Görünüşü';

  @override
  String get bridgesSpeed => 'Hız';

  @override
  String get bridgesGetBridges => 'Köprü al';

  @override
  String get bridgesAskTheTorProject =>
      'Doğrudan tor projesinden iste. Botlar stoku tüketemesin diye bir bulmaca çözersin.';

  @override
  String get bridgesTypeWhatYouSee => 'Gördüğünü yaz. Küçük harf de olur.';

  @override
  String get bridgesThisOneRequestDoes =>
      'Bu tek istek tor üzerinden gitmez - gidemez, çünkü çalışmayan zaten tor. Ağını kim işletiyorsa tor projesiyle bağlantı kurduğunu görecek. Bulunduğun yerde tek başına bu bile sorunsa, köprüleri başka bir yerden al ve aşağıya yapıştır.';

  @override
  String get bridgesCouldNotDrawThe => 'Bulmaca çizilemedi';

  @override
  String get bridgesAnswer => 'Cevap';

  @override
  String get bridgesAsking => 'İsteniyor…';

  @override
  String get bridgesRequestBridges => 'Köprü iste';

  @override
  String get bridgesDifferentPuzzle => 'Başka bulmaca';

  @override
  String get cameraNoCameraOnThis => 'Bu telefonda kamera yok';

  @override
  String get cameraCameraNotAvailable => 'Kamera kullanılamıyor';

  @override
  String get cameraCameraPermissionIsOff => 'Kamera izni kapalı';

  @override
  String get cameraOpenSettings => 'Ayarları aç';

  @override
  String get cameraCouldNotStripThat => 'Bu fotoğraf temizlenemedi, atıldı';

  @override
  String get cameraNoPhotoCameOut => 'Fotoğraf çıkmadı';

  @override
  String get cameraCouldNotStartRecording => 'Kayıt başlatılamadı';

  @override
  String get cameraTheRecordingWasLost => 'Kayıt kayboldu';

  @override
  String get cameraACopyIsIn => 'Fotoğraflarında bir kopyası var';

  @override
  String get cameraCouldNotSaveA => 'Bu telefona kopya kaydedilemedi';

  @override
  String get cameraTooLongForA => 'Mesaj için çok uzun · en fazla 8 MB';

  @override
  String get cameraNeverSavedToYour => 'Fotoğraflarına asla kaydedilmez';

  @override
  String get cameraNoExifNeverSaved =>
      'EXIF yok, fotoğraflarına asla kaydedilmez';

  @override
  String get cameraRec => 'Kayıt';

  @override
  String get cameraSwitchCamera => 'Kamerayı değiştir';

  @override
  String cameraClipSMb(Object secs, Object mb) {
    return 'Klip · $secs sn · $mb MB';
  }

  @override
  String get cameraStopRecording => 'Kaydı durdur';

  @override
  String get cameraStartRecording => 'Kaydı başlat';

  @override
  String get cameraTakeAPhoto => 'Fotoğraf çek';

  @override
  String get cameraKeepACopy => 'Kopya sakla';

  @override
  String get cameraUseThis => 'Bunu kullan';

  @override
  String chatB(Object bytes) {
    return '$bytes b';
  }

  @override
  String chatKb(Object bytes) {
    return '$bytes kb';
  }

  @override
  String chatMb(Object bytes) {
    return '$bytes mb';
  }

  @override
  String get chatFile => 'DOSYA';

  @override
  String get chatYouAreOfflineThis =>
      'Çevrimdışısın · yeniden bağlanınca kendiliğinden gider';

  @override
  String get chatStillConnectingToTor =>
      'Hâlâ Tor’a bağlanıyor · kendiliğinden gidecek';

  @override
  String chatS(Object seconds) {
    return '$seconds sn';
  }

  @override
  String chatM(Object seconds) {
    return '$seconds dk';
  }

  @override
  String chatH(Object seconds) {
    return '$seconds sa';
  }

  @override
  String chatD(Object seconds) {
    return '$seconds g';
  }

  @override
  String get chat0s => '0 sn';

  @override
  String chatHM(Object h, Object m) {
    return '$h sa $m dk';
  }

  @override
  String chatMS(Object m, Object s) {
    return '$m dk $s sn';
  }

  @override
  String chatS2(Object s) {
    return '$s sn';
  }

  @override
  String get chatNewMessages => 'Yeni mesajlar';

  @override
  String get chatUnsave => 'Kaydı kaldır';

  @override
  String get chatForward => 'İlet';

  @override
  String get commonShare => 'Paylaş';

  @override
  String get commonCopied => 'Kopyalandı';

  @override
  String get commonCopy => 'Kopyala';

  @override
  String get chatUnpin => 'Sabitlemeyi kaldır';

  @override
  String get chatPin => 'Sabitle';

  @override
  String get chatStopSending => 'Göndermeyi durdur';

  @override
  String get chatUnsend => 'Geri çek';

  @override
  String get commonEdit => 'Düzenle';

  @override
  String get chatYou => 'Sen';

  @override
  String get chatUnsendMessage => 'Mesajı geri çek';

  @override
  String get chatItDisappearsWithNo =>
      'İz bırakmadan kaybolur. Bu geri alınamaz.';

  @override
  String chatThisChatHasPins(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Bu sohbette zaten $countString sabitlenmiş mesaj var',
      one: 'Bu sohbette zaten $countString sabitlenmiş mesaj var',
    );
    return '$_temp0';
  }

  @override
  String get chatUnpinThisMessage => 'Sabitleme kaldırılsın mı?';

  @override
  String get chatPinThisMessage => 'Bu mesaj sabitlensin mi?';

  @override
  String get chatItLeavesThePinned =>
      'İkiniz için de sabitlenenler listesinden çıkar.';

  @override
  String get chatItGoesUnderThe =>
      'Sohbetin en üstündeki raptiyenin altına girer, ikiniz için de.';

  @override
  String get chatPinIt => 'Sabitle';

  @override
  String get chatNotNow => 'Şimdi değil';

  @override
  String get chatEditMessage => 'Mesajı düzenle';

  @override
  String get chat30Seconds => '30 saniye';

  @override
  String get chat1Minute => '1 dakika';

  @override
  String get chat5Minutes => '5 dakika';

  @override
  String get chat1Hour => '1 saat';

  @override
  String get chat24Hours => '24 saat';

  @override
  String get chatGhostTimer => 'Süreli mesajlar';

  @override
  String get chatHowLongBeforeSent =>
      'Gönderilen mesajlar ne kadar sonra silinsin?';

  @override
  String get chatCamera => 'Kamera';

  @override
  String get chatNoExifNeverSaved =>
      'Exif yok, fotoğraflarına asla kaydedilmez';

  @override
  String get chatGallery => 'Galeri';

  @override
  String get chatVideo => 'Video';

  @override
  String get chatGifFromPhone => 'Telefondan gif';

  @override
  String get chatFile2 => 'Dosya';

  @override
  String get chatAFewSeconds => 'Birkaç saniye';

  @override
  String get chatUnderAMinute => 'Bir dakikadan az';

  @override
  String chatRoughlyMin(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Yaklaşık $countString dk',
      one: 'Yaklaşık $countString dk',
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
  String get chatSendThis => 'Bu dosya gönderilsin mi?';

  @override
  String chatOverTor(Object humanBytes, Object wireEstimate) {
    return '$humanBytes · $wireEstimate, tor üzerinden';
  }

  @override
  String get chatBigFilesGoOut =>
      'Büyük dosyalar küçük şifreli parçalar halinde gider, bu yüzden biraz sürer. Uygulamayı açık tutarsan devam eder.';

  @override
  String get chatSendIt => 'Gönder';

  @override
  String get chatCouldNotReadThat => 'Bu dosya okunamadı';

  @override
  String get chatFileTooBig8 => 'Dosya çok büyük · en fazla 8 mb';

  @override
  String get chatCouldNotCleanThat => 'Bu video temizlenemedi';

  @override
  String get chatCouldNotCleanThatPictureSend =>
      'Bu resim temizlenemedi · fotoğraf olarak gönder';

  @override
  String get chatGifTooBig8 => 'Gif çok büyük · en fazla 8 mb';

  @override
  String get chatCouldNotCleanThatGif => 'Bu gif temizlenemedi';

  @override
  String get chatTorIsNotUp =>
      'Tor henüz hazır değil · önizlemesiz gönderiliyor';

  @override
  String get chatCouldnTReachIt => 'Ulaşılamadı · önizlemesiz gönderiliyor';

  @override
  String get chatNoTitleCameBack => 'Başlık gelmedi · önizlemesiz gönderiliyor';

  @override
  String get chatCouldnTFetchIt => 'Alınamadı · önizlemesiz gönderiliyor';

  @override
  String get chatNoSignalSessionRe => 'Signal oturumu yok - yeniden eşleştir';

  @override
  String get chatMessageUnavailable => 'Mesaj kullanılamıyor';

  @override
  String get chatYou2 => 'Sen';

  @override
  String get chatThem => 'O';

  @override
  String get chatVoiceMessage => 'Sesli mesaj';

  @override
  String get chatQuotedPhoto => 'Fotoğraf';

  @override
  String get chatViewContact => 'Kişiyi gör';

  @override
  String get chatSharedPhotos => 'Paylaşılan fotoğraflar';

  @override
  String chatSharedPhotoCount(int count, Object title) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString fotoğraf',
      one: '$countString fotoğraf',
    );
    return '$_temp0 · $title';
  }

  @override
  String get chatUnmuteNotifications => 'Bildirimleri sessizden çıkar';

  @override
  String get chatMuteNotifications => 'Bildirimleri sessize al';

  @override
  String get chatArchiveChat => 'Sohbeti arşivle';

  @override
  String get chatWallpaper => 'Duvar kağıdı';

  @override
  String get chatClearConversation => 'Sohbeti temizle';

  @override
  String get chatNoteOnThisContact => 'Bu kişi hakkında not';

  @override
  String get chatPinToTop => 'En üste sabitle';

  @override
  String get chatBlockContact => 'Kişiyi engelle';

  @override
  String get chatUnpinned => 'Sabitleme kaldırıldı';

  @override
  String get chatPinnedToTop => 'En üste sabitlendi';

  @override
  String get chatJustForYouNever =>
      'Sadece senin için. Asla gönderilmez, bu telefondan hiç çıkmaz.';

  @override
  String get chatAQuietReminder => 'Sessiz bir hatırlatma…';

  @override
  String get chatNoteSaved => 'Not kaydedildi';

  @override
  String get chatClearThisConversation => 'Bu sohbet temizlensin mi?';

  @override
  String get chatEveryMessageHereIs =>
      'Buradaki her mesaj bu telefondan silinir. Bu yalnızca senin kopyanı temizler - onun cihazına dokunmaz.';

  @override
  String get chatClear => 'Temizle';

  @override
  String get chatBlockThisContact => 'Bu kişi engellensin mi?';

  @override
  String get chatTheirMessagesStopArriving =>
      'Mesajları artık gelmez ve sohbetlerinden kaybolur. Ona asla haber verilmez. Engeli istediğin zaman ayarlardan kaldırabilirsin.';

  @override
  String get commonBlock => 'Engelle';

  @override
  String get chatSaved => 'Kaydedildi';

  @override
  String get chatRemovedFromSaved => 'Kaydedilenlerden çıkarıldı';

  @override
  String get chatForwardTo => 'Kime iletilsin';

  @override
  String get chatNoContactsToForward => 'İletilecek kişi yok';

  @override
  String get chatToday => 'Bugün';

  @override
  String get chatYesterday => 'Dün';

  @override
  String get chatThisMessageCanT => 'Bu mesaj gösterilemiyor';

  @override
  String get chatJumpToTheNewest => 'En yeniye git';

  @override
  String get chatBuildingAPrivateRoute =>
      'Gizli bir rota kuruluyor · ilk bağlantı yavaştır, sonrakiler hızlı. Şimdi gönderdiğin her şey sıraya girer ve kendiliğinden iletilir.';

  @override
  String get chatLooksSafeNothingSuspicious =>
      'Güvenli görünüyor · ilk mesajında şüpheli bir şey yok';

  @override
  String get chatTheNextPhotoYou =>
      'Göndereceğin sonraki fotoğraf korumalı açılır · ekran görüntüsünü alamaz';

  @override
  String get chatPhotoProtectionOff => 'Fotoğraf koruması kapalı';

  @override
  String get chatAcceptToReplyThey =>
      'Yanıt vermek için kabul et - sen kabul edene kadar bir mesaj daha gönderebilir.';

  @override
  String chatIntroducedYouAcceptTo(Object introducer) {
    return '$introducer sizi tanıştırdı. Yanıt vermek için kabul et.';
  }

  @override
  String chatIntroducedYouSayHello(Object vouchNames) {
    return '$vouchNames sizi tanıştırdı. Merhaba de - senin kartını da aldı.';
  }

  @override
  String get chatIntroduceTo => 'Tanıştır...';

  @override
  String get chatAcceptThemFirst => 'Önce onu kabul et';

  @override
  String get chatMessageRequest => 'Mesaj isteği';

  @override
  String get chatTheyNeedToAccept =>
      'Sohbete devam edebilmen için önce onun kabul etmesi gerekiyor.';

  @override
  String get chatWaitingForThemTo => 'İsteğini kabul etmesi bekleniyor';

  @override
  String get chatYouBlockedThisContact => 'Bu kişiyi engelledin';

  @override
  String get chatSupporter => 'Destekçi';

  @override
  String get chatEncryptedViaRelay => 'Şifreli · aktarıcı ile';

  @override
  String get chatEncryptedDirect => 'Şifreli · doğrudan';

  @override
  String get chatEncryptedOverTor => 'Şifreli · tor üzerinden';

  @override
  String get chatSearchThisChat => 'Bu sohbette ara';

  @override
  String get chatContactOptions => 'Kişi seçenekleri';

  @override
  String get commonClose => 'Kapat';

  @override
  String get chatFindInConversation => 'Sohbette bul';

  @override
  String get chatNoMatches => 'Eşleşme yok';

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
      other: '*$posString* / $countString eşleşme',
      one: '*$posString* / $countString eşleşme',
    );
    return '$_temp0';
  }

  @override
  String get chatPreviousMatch => 'Önceki eşleşme';

  @override
  String get chatNextMatch => 'Sonraki eşleşme';

  @override
  String get chatPhotoUnavailable => 'Fotoğraf kullanılamıyor';

  @override
  String get chatDelivered => 'İletildi';

  @override
  String get chatEdited => 'Düzenlendi';

  @override
  String get chatWaitingForThemToComeOnline =>
      'Çevrimiçi olması ya da seni geri eklemesi bekleniyor';

  @override
  String get chatFailedTapToRetry => 'Başarısız · tekrar için dokun';

  @override
  String get chatReplyingTo => 'Ona yanıt veriyorsun';

  @override
  String get chatReplyingToYourself => 'Kendine yanıt veriyorsun';

  @override
  String get chatReply => 'Yanıtla';

  @override
  String get chatSayHi => 'Selam ver.';

  @override
  String get chatJustTheTwoOf => 'Yalnızca ikiniz, uçtan uca şifreli.';

  @override
  String get chatMicPermissionNeeded => 'Mikrofon izni gerekli';

  @override
  String get chatTheMicWouldNot => 'Mikrofon başlamadı. Tekrar dene';

  @override
  String get chatReleaseToCancel => 'İptal için bırak';

  @override
  String get chatVoiceHiddenSlideTo => 'Ses gizli · iptal için kaydır';

  @override
  String get chatSlideToCancel => 'İptal için kaydır';

  @override
  String get chatGhostMode => 'Süreli mesajlar';

  @override
  String chatMessagesBurnAfter(Object humanBurn) {
    return '$humanBurn sonra silinir';
  }

  @override
  String get chatTimedMessages => 'Süreli mesajlar';

  @override
  String get chatOpenTheCamera => 'Kamerayı aç';

  @override
  String get chatAttachAPhoto => 'Fotoğraf ekle';

  @override
  String get chatMessage => 'Mesaj';

  @override
  String get chatDisguiseVoice => 'Sesi gizle';

  @override
  String get commonSend => 'Gönder';

  @override
  String get chatNoPhotosInThis => 'Bu sohbette henüz fotoğraf yok';

  @override
  String get chatHoldToRecord => 'Sesli mesaj kaydetmek için basılı tut';

  @override
  String get chatSendPhoto => 'Fotoğraf gönder';

  @override
  String get chatAddACaption => 'Açıklama ekle…';

  @override
  String get chatSecurityCodeChanged => 'Güvenlik kodu değişti';

  @override
  String chatMayHaveReinstalledOr(Object peerName) {
    return '$peerName uygulamayı yeniden kurmuş olabilir ya da biri onu taklit ediyor olabilir. Emin olmak için güvenlik numaralarını karşılaştır.';
  }

  @override
  String get chatOk => 'Tamam';

  @override
  String get chatVerify => 'Doğrula';

  @override
  String get cleanKryfoCanTClean =>
      'Kryfo bu tür dosyaları henüz temizleyemiyor.';

  @override
  String get cleanThisIsAMotion => 'Bu bir hareketli fotoğraf.';

  @override
  String get cleanThisPictureIsToo =>
      'Bu resim burada temizlenemeyecek kadar büyük.';

  @override
  String get cleanThisFileIsDamaged => 'Bu dosya hasarlı ya da yarım kalmış.';

  @override
  String get cleanKryfoCouldNotMake => 'Kryfo bunu temizleyemedi.';

  @override
  String get cleanNotEnoughRoomOn => 'Telefonda yeterli yer yok.';

  @override
  String get cleanKryfoCouldNotOpen => 'Kryfo bu dosyayı açamadı.';

  @override
  String get cleanItCleansJpegPng =>
      'JPEG, PNG, WebP, HEIC, AVIF, GIF, MP4 ve MOV dosyalarını temizler. Hiçbir şey değiştirilmedi.';

  @override
  String get cleanItHoldsAShort =>
      'Resmin yanında kısa bir video da taşır ve Kryfo o kısmı henüz temizleyemiyor. Kamerada hareketli fotoğrafı kapat ya da ekran görüntüsünü gönder.';

  @override
  String get cleanPicturesOver64Mb =>
      '64 MB üzerindeki resimler telefonda temizlenmez. Hiçbir şey değiştirilmedi.';

  @override
  String get cleanKryfoCouldNotRead =>
      'Kryfo dosyayı sonuna kadar okuyamadı, bu yüzden ona temiz demeyecek. Kopya oluşturulmadı.';

  @override
  String get cleanSomethingInsideIsOf =>
      'İçinde nasıl kaldıracağını bilmediği türden bir şey var, bu yüzden kopya oluşturulmadı.';

  @override
  String get cleanFreeSomeSpaceAnd =>
      'Biraz yer aç ve tekrar dene. Hiçbir şey değiştirilmedi.';

  @override
  String get cleanTheAppThatShared =>
      'Paylaşan uygulama dosyayı geri almış olabilir. Yeniden paylaşmayı dene.';

  @override
  String get cleanNoAppOnThis =>
      'Bu telefondaki hiçbir uygulama dosyayı almadı.';

  @override
  String get cleanCouldNotSaveIt =>
      'Kaydedilemedi. Telefonda yer olup olmadığına bak.';

  @override
  String get cleanTheOriginalIsGone => 'Orijinal gitti. Temiz kopya kalıyor.';

  @override
  String get cleanAndroidWouldNotDelete =>
      'Android onu silmedi. Galeriden elle kaldır.';

  @override
  String get cleanCleanCopy => 'Temiz kopya';

  @override
  String get cleanShareCleanCopy => 'Temiz kopyayı paylaş';

  @override
  String get cleanSaveToGallery => 'Galeriye kaydet';

  @override
  String get commonStop => 'Durdur';

  @override
  String get cleanReadingTheFile => 'Dosya okunuyor';

  @override
  String get cleanCleaning => 'Temizleniyor';

  @override
  String cleanOf(Object prettySize, Object prettySize2) {
    return '$prettySize / $prettySize2';
  }

  @override
  String get cleanEverythingStaysOnThis => 'Her şey bu telefonda kalır.';

  @override
  String get cleanAlreadyClean => 'Zaten temiz.';

  @override
  String get cleanClean => 'Temiz.';

  @override
  String get cleanThereWasNothingTo => 'Bulunacak bir şey yoktu.';

  @override
  String get cleanNothingLeftToFind => 'Bulunacak bir şey kalmadı.';

  @override
  String get cleanSameVideoSameQuality => 'Aynı video, aynı kalite';

  @override
  String get cleanSamePictureSameQuality => 'Aynı resim, aynı kalite';

  @override
  String cleanRemoved(Object label) {
    return '$label, kaldırıldı';
  }

  @override
  String get cleanRemoved2 => 'KALDIRILDI';

  @override
  String get cleanWithTheLocationInside =>
      'konum hâlâ içinde. O dosyayı alan herkes sokağını öğrenir.';

  @override
  String get cleanWithEverythingItKnew => 'bildiği her şey hâlâ içinde.';

  @override
  String get cleanOriginal => 'ORİJİNAL';

  @override
  String get cleanClean2 => 'TEMİZ';

  @override
  String get cleanSavedToYourGallery => 'Galerine kaydedildi.';

  @override
  String cleanTheOriginalIsStill(Object what) {
    return 'Orijinal de hâlâ orada, $what';
  }

  @override
  String cleanTheOriginalIsStillWhereIt(Object what) {
    return 'Orijinal hâlâ yerinde, $what Kryfo onu buradan silemez, o yüzden geldiği uygulamadan sil.';
  }

  @override
  String get cleanDeleteTheOriginal => 'Orijinali sil';

  @override
  String get cleanKeepBoth => 'İkisini de tut';

  @override
  String get commonDone => 'Bitti';

  @override
  String get cleanAndroidWillAskYou => 'ANDROID ONAYLAMANI İSTEYECEK';

  @override
  String get contactYourNameForThem => 'Ona verdiğin takma ad';

  @override
  String get contactStaysOnThisPhone => 'Bu telefonda kalır. O asla görmez.';

  @override
  String get contactClear => 'Temizle';

  @override
  String get contactMessage => 'Mesaj';

  @override
  String get contactKeysVerified => 'Anahtarlar doğrulandı';

  @override
  String get contactVerifyKeys => 'Anahtarları doğrula';

  @override
  String get contactVouches => 'Referanslar';

  @override
  String get contactUnmute => 'Sesi aç';

  @override
  String get contactMute => 'Sessize al';

  @override
  String get contactUnpin => 'Sabitlemeyi kaldır';

  @override
  String get contactPinToTop => 'En üste sabitle';

  @override
  String get contactArchive => 'Arşivle';

  @override
  String get contactOutOfTheList => 'Tekrar yazana kadar listeden çıkar';

  @override
  String contactBlock(Object name) {
    return '$name engellensin mi?';
  }

  @override
  String get contactTheirMessagesStopArriving =>
      'Mesajları artık gelmez. Ona haber verilmez.';

  @override
  String get contactDeleteChat => 'Sohbeti sil';

  @override
  String get contactMessagesAndContactGone =>
      'Mesajlar ve kişi bu telefondan silinir';

  @override
  String get contactDeleteThisChat => 'Bu sohbet silinsin mi?';

  @override
  String get contactEveryMessageAndThe =>
      'Her mesaj ve kişi bu telefondan silinir. Ona hiçbir şey gönderilmez.';

  @override
  String get commonDelete => 'Sil';

  @override
  String get contactDeleted => 'Silindi';

  @override
  String get contactToday => 'Bugün';

  @override
  String contactD(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gün',
    );
    return '$_temp0';
  }

  @override
  String contactMo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ay',
    );
    return '$_temp0';
  }

  @override
  String contactY(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count yıl',
    );
    return '$_temp0';
  }

  @override
  String get contactVerified => 'Doğrulandı';

  @override
  String get contactChatting => 'Yazışıyorsunuz';

  @override
  String get contactNothingSharedYet => 'Henüz paylaşılan bir şey yok';

  @override
  String contactSharedMedia(Object count) {
    return 'Paylaşılan medya · $count';
  }

  @override
  String get donateBitcoin => 'Bitcoin';

  @override
  String get donateText => '₿';

  @override
  String get donateBadgeUnlocks => 'Rozet açılır';

  @override
  String get donateMonero => 'Monero';

  @override
  String get donateManualNoBadge => 'Elle · rozet yok';

  @override
  String get donateSolana => 'Solana';

  @override
  String get donateEthereum => 'Ethereum';

  @override
  String get donateText2 => 'Ξ';

  @override
  String donateYourEarlierBitcoinPayment(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter': 'Önceki bitcoin ödemen görüldü · destekçi rozeti açıldı',
      'patron': 'Önceki bitcoin ödemen görüldü · hami rozeti açıldı',
      'guardian': 'Önceki bitcoin ödemen görüldü · koruyucu rozeti açıldı',
      'other': 'Önceki bitcoin ödemen görüldü · destekçi rozeti açıldı',
    });
    return '$_temp0';
  }

  @override
  String get donateSupport => 'Destekle';

  @override
  String get donateKeepKryfo => 'Kryfo *bağımsız* kalsın';

  @override
  String get donateNoAdsNoInvestors =>
      'Reklam yok, yatırımcı yok, satılacak bir şey yok. Bağışçıların verdikleriyle ayakta duruyor.';

  @override
  String get donateBackItAnonymouslyBadge =>
      'Anonim olarak destekle. Rozet isteğe bağlı.\n*Gizlilik hiçbir zaman ücretli olmaz.*';

  @override
  String donateAddressCheckItAgainst(Object coinName) {
    return '$coinName adresi · cüzdanındakiyle karşılaştır';
  }

  @override
  String get donateAddressCopiedClearsIn =>
      'Adres kopyalandı · 60 sn içinde silinir';

  @override
  String get donateCopyAddress => 'Adresi kopyala';

  @override
  String get donateBitcoinIsVerifiedBy =>
      'Bitcoin ödemeleri kendi düğümümüzde doğrulanır, bu yüzden ödeme ulaşınca rozetin kendiliğinden açılır.';

  @override
  String get donateWeCanTVerify =>
      'Bu zinciri, senin hakkında dışarıdaki bir servise sormadan doğrulayamayız, o yüzden doğrulamıyoruz. İstersen gönder. Rozet açmaz.';

  @override
  String get donateBitcoinBadgesNeedOnion =>
      'Bitcoin rozetleri için Onion modu gerekir';

  @override
  String get donateSwitchToOnion => 'Onion moduna geç';

  @override
  String get donatePayWithBitcoin => 'Bitcoin ile öde  →';

  @override
  String get donateBadgesStartAt20 => 'Rozet için en az 20 \$';

  @override
  String get donateReachingThePaymentService =>
      'Ödeme servisine tor üzerinden ulaşılıyor…';

  @override
  String get donateThisCanTakeUp => 'Bu bir dakikayı bulabilir';

  @override
  String donateSThisCanTake(Object waited) {
    return '$waited sn · bu bir dakikayı bulabilir';
  }

  @override
  String get donateUseTheAddressInstead => 'Onun yerine adresi kullan';

  @override
  String get donateThePaymentServiceIs =>
      'Ödeme servisi bir onion adresi ve ona yalnızca Onion modu ulaşabilir. Hiçbir şey gönderilmedi.';

  @override
  String get donateTorWasSlowTo =>
      'Tor ödeme servisine ulaşmakta yavaş kaldı. Aşağıdaki adrese bağış yapabilirsin - sadece rozetin otomatik açılmaz. Rozet için daha sonra tekrar dene.';

  @override
  String get donateThePaymentServiceIsHavingTrouble =>
      'Ödeme servisinde şu an sorun var. Yine de aşağıdaki adrese bağış yapabilirsin - sadece rozetin otomatik açılmaz. Rozet için daha sonra tekrar dene.';

  @override
  String get commonTryAgain => 'Tekrar dene';

  @override
  String donateBtc(Object btc) {
    return '$btc BTC';
  }

  @override
  String donateSendExactlyThisAmount(Object fmtLeft) {
    return 'Tam olarak bu tutarı gönder · kalan süre $fmtLeft';
  }

  @override
  String get donateOpenWallet => 'Cüzdanı aç';

  @override
  String get donateThisScreenUpdatesItself =>
      'Ödemen görüldüğü anda bu ekran kendini günceller.\nAçık tut - hiçbir şey saklanmaz, hiçbir şey seni tanımlamaz.';

  @override
  String get donateWatchingTheChainFor => 'Ödemen için zincir izleniyor';

  @override
  String get donateThisInvoiceExpired => 'Bu faturanın süresi doldu';

  @override
  String get donateInvoicesTimeOutIf =>
      'Faturaların süresi dolar. Ödemeyi zaten gönderdiysen bunu açık tut: bir süre her dakika servise yeniden soruyoruz, destek ekranını bir sonraki açışında da. İstediğin zaman yenisini başlat.';

  @override
  String get donateNewInvoice => 'Yeni fatura';

  @override
  String get donateIPaidCheckAgain => 'Ödedim, tekrar bak';

  @override
  String get donateNoWallet =>
      'Bu telefonda bitcoin bağlantılarını açan bir uygulama yok. Bunun yerine adresi kopyala.';

  @override
  String get donateChecking => 'Kontrol ediliyor…';

  @override
  String get donateNotSeenYet =>
      'Henüz görünmüyor. Bir ödemenin görünmesi birkaç dakika sürebilir.';

  @override
  String get donatePaymentConfirmed => 'Ödeme onaylandı';

  @override
  String get donateThankYouForKeeping =>
      'Kryfo’yu bağımsız tuttuğun için teşekkürler.';

  @override
  String donateVerifiedOnChainYou(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter':
          'Zincirde doğrulandı - artık bir destekçisin. Bunu kimse elinden alamaz.',
      'patron':
          'Zincirde doğrulandı - artık bir hamisin. Bunu kimse elinden alamaz.',
      'guardian':
          'Zincirde doğrulandı - artık bir koruyucusun. Bunu kimse elinden alamaz.',
      'other':
          'Zincirde doğrulandı - artık bir destekçisin. Bunu kimse elinden alamaz.',
    });
    return '$_temp0';
  }

  @override
  String get donateWearMyBadge => 'Rozetimi tak';

  @override
  String get donateJustGladToHelp => 'Yardım etmek yeter';

  @override
  String get gettingMessagesGettingMessages => 'Mesaj alma';

  @override
  String get gettingMessagesHowNewMessagesReach =>
      'Yeni mesajların bu telefona nasıl ulaştığı. İstediğin zaman değiştirebilirsin.';

  @override
  String get gettingMessagesAlwaysOn => 'Hep açık';

  @override
  String get gettingMessagesMostPrivate => 'En gizli';

  @override
  String get gettingMessagesMessagesArriveInstantlyNothing =>
      'Mesajlar anında gelir. Hiçbir şey tor’un dışına çıkmaz. En çok pili bu harcar.';

  @override
  String get gettingMessagesCheckIns => 'Kontroller';

  @override
  String get gettingMessagesLightest => 'En hafif';

  @override
  String get gettingMessagesKryfoLooksForMessages =>
      'Kryfo 15 dakikada bir mesajlara bakar. Pili yormaz ama mesajlar gecikebilir.';

  @override
  String get gettingMessagesOnTheLockScreen => 'Kilit ekranında';

  @override
  String get gettingMessagesHideMessagePreview => 'Mesaj önizlemesini gizle';

  @override
  String get gettingMessagesAGenericAlertWith =>
      'Gönderen ve mesaj metni olmadan genel bir uyarı';

  @override
  String get gettingMessagesShowsMessageTextIn =>
      'Kryfo kilitliyken bile mesaj metnini bildirimlerde gösterir.';

  @override
  String get gettingMessagesWhenThePhoneSits =>
      'Telefon hareketsiz durduğunda Android kontrollerin arasını açar. Yukarıdaki satır gerçek son kontrolü gösterir. Kryfo açıkken bağlı kalır.';

  @override
  String get groupChatJumpToTheNewest => 'En yeniye git';

  @override
  String get groupChatBlockedEverywhere => 'Her yerde engelli';

  @override
  String get groupChatYou => 'Sen';

  @override
  String get groupChatVoiceMessage => 'Sesli mesaj';

  @override
  String get groupChatQuotedPhoto => 'Fotoğraf';

  @override
  String get groupChatMessageUnavailable => 'Mesaj kullanılamıyor';

  @override
  String get groupChatTorIsNotUp =>
      'Tor henüz hazır değil · önizlemesiz gönderiliyor';

  @override
  String get groupChatCouldnTReachIt =>
      'Ulaşılamadı · önizlemesiz gönderiliyor';

  @override
  String get groupChatNoTitleCameBack =>
      'Başlık gelmedi · önizlemesiz gönderiliyor';

  @override
  String get groupChatCouldnTFetchIt => 'Alınamadı · önizlemesiz gönderiliyor';

  @override
  String get groupChatCamera => 'Kamera';

  @override
  String get groupChatGallery => 'Galeri';

  @override
  String get groupChatVideo => 'Video';

  @override
  String get groupChatGifFromPhone => 'Telefondan gif';

  @override
  String get groupChatFile => 'Dosya';

  @override
  String get groupChatCouldNotReadThat => 'Bu dosya okunamadı';

  @override
  String get groupChatGifTooBig8 => 'Gif çok büyük · en fazla 8 mb';

  @override
  String get groupChatCouldNotCleanThat => 'Bu gif temizlenemedi';

  @override
  String get groupChatFileTooBig8 => 'Dosya çok büyük · en fazla 8 mb';

  @override
  String get groupChatCouldNotCleanThatVideo => 'Bu video temizlenemedi';

  @override
  String get groupChatCouldNotCleanThatPictureSend =>
      'Bu resim temizlenemedi · fotoğraf olarak gönder';

  @override
  String get groupChat30Seconds => '30 saniye';

  @override
  String get groupChat1Minute => '1 dakika';

  @override
  String get groupChat5Minutes => '5 dakika';

  @override
  String get groupChat1Hour => '1 saat';

  @override
  String get groupChat24Hours => '24 saat';

  @override
  String get groupChatBurnTimer => 'Süreli mesajlar';

  @override
  String get groupChatNewMessagesDisappearAfter =>
      'Yeni mesajlar bu süreden sonra kaybolur';

  @override
  String get groupChatToday => 'Bugün';

  @override
  String get groupChatYesterday => 'Dün';

  @override
  String get groupChatYou2 => 'Sen';

  @override
  String groupChatThisChatHasPins(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Bu sohbette zaten $countString sabitlenmiş mesaj var',
      one: 'Bu sohbette zaten $countString sabitlenmiş mesaj var',
    );
    return '$_temp0';
  }

  @override
  String get groupChatUnpinThisMessage => 'Sabitleme kaldırılsın mı?';

  @override
  String get groupChatPinThisMessage => 'Bu mesaj sabitlensin mi?';

  @override
  String get groupChatItLeavesThePinned =>
      'Buradaki herkes için sabitlenenler listesinden çıkar.';

  @override
  String get groupChatItGoesUnderThe =>
      'Sohbetin en üstündeki raptiyenin altına girer, buradaki herkes için.';

  @override
  String get groupChatUnpin => 'Sabitlemeyi kaldır';

  @override
  String get groupChatPinIt => 'Sabitle';

  @override
  String get groupChatNotNow => 'Şimdi değil';

  @override
  String get groupChatSaved => 'Kaydedildi';

  @override
  String get groupChatRemovedFromSaved => 'Kaydedilenlerden çıkarıldı';

  @override
  String get groupChatForwardTo => 'Kime iletilsin';

  @override
  String get groupChatNoContactsToForward => 'İletilecek kişi yok';

  @override
  String get groupChatEditMessage => 'Mesajı düzenle';

  @override
  String get groupChatUnsendMessage => 'Mesajı geri çek';

  @override
  String get groupChatItDisappearsWithNo =>
      'İz bırakmadan kaybolur. Bu geri alınamaz.';

  @override
  String get groupChatUnsend => 'Geri çek';

  @override
  String groupChatThisRoomAndEverything(Object expiryWords) {
    return 'Bu oda ve içindeki her şey $expiryWords sonra kaybolur';
  }

  @override
  String groupChatGhostModeOnBurns(Object fmtBurn) {
    return 'Süreli mesajlar · $fmtBurn sonra silinir';
  }

  @override
  String get groupChatGroupCreatedSayHi => 'Grup kuruldu. Selam ver.';

  @override
  String get groupChatNoMessagesYet => 'Henüz mesaj yok.';

  @override
  String get groupChatEveryoneHereReads => 'Buradaki herkes yazdıklarını okur.';

  @override
  String get groupChatNobodyHereYet => 'Henüz burada kimse yok.';

  @override
  String get groupChatShareTheRoomLink =>
      'Oda bağlantısını paylaş. Katılan herkes o andan itibaren yazılanları okur.';

  @override
  String get groupChatNobodyToReadIt => 'Burada bunu okuyacak başka kimse yok.';

  @override
  String get groupChatThisMessageCanT => 'Bu mesaj gösterilemiyor';

  @override
  String groupChatS(Object s) {
    return '$s sn';
  }

  @override
  String groupChatM(Object s) {
    return '$s dk';
  }

  @override
  String groupChatH(Object s) {
    return '$s sa';
  }

  @override
  String groupChatD(Object s) {
    return '$s g';
  }

  @override
  String groupChatHere(int count, Object time) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$time · $countString kişi burada',
      one: '$time · $countString kişi burada',
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
      other: '$countString üye',
      one: '$countString üye',
    );
    return '$_temp0';
  }

  @override
  String get groupChatSearchThisChat => 'Bu sohbette ara';

  @override
  String groupChatReplyingTo(Object name) {
    return 'Yanıtlanan: $name';
  }

  @override
  String get groupChatReplyingToYou => 'Kendine yanıt veriyorsun';

  @override
  String get groupChatTimedMessages => 'Süreli mesajlar';

  @override
  String get groupChatOpenTheCamera => 'Kamerayı aç';

  @override
  String get groupChatAttachAPhoto => 'Fotoğraf ekle';

  @override
  String get groupChatMessage => 'Mesaj';

  @override
  String get groupChatDisguiseVoice => 'Sesi gizle';

  @override
  String get groupChatSupporter => 'Destekçi';

  @override
  String get groupChatEdited => 'Düzenlendi';

  @override
  String get groupChatTapToRetry => '! Tekrar için dokun';

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
      other: 'Gönderildi · $countString kişiden $haveString kişiye ulaştı',
      one: 'Gönderildi · $countString kişiden $haveString kişiye ulaştı',
      zero: 'Gönderildi · yolda',
    );
    return '$_temp0';
  }

  @override
  String get groupChat0s => '0 sn';

  @override
  String get groupChatReply => 'Yanıtla';

  @override
  String get groupChatPin => 'Sabitle';

  @override
  String get groupChatUnsave => 'Kaydı kaldır';

  @override
  String get groupChatForward => 'İlet';

  @override
  String get groupInfoGroup => 'Grup';

  @override
  String get groupInfoRenameGroup => 'Grup adını değiştir';

  @override
  String get groupInfoRename => 'Adı değiştir';

  @override
  String get groupInfoNoContactsToAdd => 'Eklenecek kişi yok';

  @override
  String get groupInfoCouldNotAdd => 'Eklenemedi';

  @override
  String groupInfoRemove(Object haloId) {
    return '$haloId çıkarılsın mı?';
  }

  @override
  String get groupInfoTheyWillStopReceiving =>
      'Artık bu gruptan mesaj almayacak.';

  @override
  String appGroupHoldsUpTo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Bir grupta en fazla $countString kişi olabilir',
      one: 'Bir grupta en fazla $countString kişi olabilir',
    );
    return '$_temp0';
  }

  @override
  String get commonRemove => 'Kaldır';

  @override
  String get groupInfoClearThisConversation => 'Bu sohbet temizlensin mi?';

  @override
  String get groupInfoEveryMessageHereIs =>
      'Buradaki her mesaj bu telefondan silinir. Bu yalnızca senin kopyanı temizler, diğer üyeler kendi kopyalarını tutar.';

  @override
  String get groupInfoClear => 'Temizle';

  @override
  String get groupInfoConversationCleared => 'Sohbet temizlendi';

  @override
  String get groupInfoLeaveRoom => 'Odadan çıkılsın mı?';

  @override
  String get groupInfoLeaveGroup => 'Gruptan çıkılsın mı?';

  @override
  String get groupInfoEverythingInItIs =>
      'İçindeki her şey şimdi bu telefondan silinir ve burada kullandığın anahtar sonsuza dek kaybolur.';

  @override
  String groupChatYouWereRemovedFrom(Object name) {
    return 'Çıkarıldın: $name';
  }

  @override
  String get groupInfoLeaveGroupLine =>
      'Artık mesajlarını almayacaksın ve içindeki her şey bu telefondan silinir.';

  @override
  String get groupInfoLeaveGroupAdmin =>
      'Artık mesajlarını almayacaksın ve içindeki her şey bu telefondan silinir. Yöneticisi sensin, bu yüzden sen ayrıldıktan sonra kimse üyeleri ya da adını değiştiremez.';

  @override
  String get groupInfoLeaveRoomMaker =>
      'İçindeki her şey şimdi bu telefondan silinir ve burada kullandığın anahtar sonsuza dek kaybolur. Bu odayı sen kurdun, bu yüzden bağlantısıyla artık kimse giremez.';

  @override
  String get groupInfoLeave => 'Çık';

  @override
  String get groupInfoGroupInfo => 'Grup bilgisi';

  @override
  String groupInfo1Member(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString üye',
      one: '$countString üye',
    );
    return '$_temp0';
  }

  @override
  String get groupInfoAdmin => 'Yönetici';

  @override
  String get groupInfoMembers2 => 'Üyeler';

  @override
  String get groupInfoInvite => 'Davet et';

  @override
  String get commonAdd => 'Ekle';

  @override
  String get groupInfoYou => 'Sen';

  @override
  String get groupInfoRemoveFromGroup => 'Gruptan çıkar';

  @override
  String get groupInfoWallpaper => 'Duvar kağıdı';

  @override
  String get groupInfoSharedMedia => 'Paylaşılan medya';

  @override
  String get groupInfoClearConversation => 'Sohbeti temizle';

  @override
  String get groupInfoLeaveRoom2 => 'Odadan çık';

  @override
  String get groupInfoLeaveGroup2 => 'Gruptan çık';

  @override
  String get groupInfoAddMembers => 'Üye ekle';

  @override
  String groupInfoAdd(Object pickedLength) {
    return '$pickedLength kişiyi ekle';
  }

  @override
  String handleYouAre(Object h) {
    return 'Kullanıcı adın: @$h';
  }

  @override
  String get handleHandleDeletedThePage =>
      'Kullanıcı adı silindi · sayfa kaldırıldı';

  @override
  String get handlePublicHandle => 'Genel kullanıcı adı';

  @override
  String get handleOptionalYourThreeWords =>
      'İsteğe bağlı. Üç kelimen her durumda çalışmaya devam eder.';

  @override
  String get handleWren => 'wren';

  @override
  String get handleALineAboutYou => 'Hakkında bir satır · isteğe bağlı';

  @override
  String get handleClaiming => 'Alınıyor…';

  @override
  String get handleClaimThisHandle => 'Bu kullanıcı adını al';

  @override
  String get handleAnyoneWithThisLink =>
      'Bu bağlantıya sahip herkes seninle özel bir sohbet başlatabilir. İçinde davetin var, başka hiçbir şey yok.';

  @override
  String get handleLinkCopied => 'Bağlantı kopyalandı';

  @override
  String get handleDeleteThisHandle => 'Bu kullanıcı adını sil';

  @override
  String handleDeleteTitle(Object handle) {
    return '@$handle silinsin mi?';
  }

  @override
  String get handleDeleteLine =>
      'Herkese açık sayfan kalkar ve adı herkes alabilir. Mevcut sohbetlerin olduğu gibi kalır.';

  @override
  String get handleDeleteYes => 'Kullanıcı adını sil';

  @override
  String get handleDeleting => 'Siliniyor…';

  @override
  String get handleChecking => 'Kontrol ediliyor…';

  @override
  String get handleAvailable => '✓ Uygun';

  @override
  String get handleAlreadyTaken => 'Zaten alınmış';

  @override
  String get handleNameRule => '3 ile 20 karakter: a-z, 0-9 veya _';

  @override
  String get handleWhatAHandleDoes => 'Kullanıcı adı ne işe yarar';

  @override
  String get handleAnyoneWhoKnowsIt =>
      'Onu bilen herkes sana mesaj atmak için istek gönderebilir; zaten amacı da bu. Sayfada davetin ve yazdığın satır var, başka hiçbir şey yok; kimin okuduğunun kaydını da tutmaz. İstediğin zaman silebilirsin.';

  @override
  String handleIsNotYoursOn(Object handle) {
    return '@$handle bu telefonda sana ait değil';
  }

  @override
  String handleTheRegistryHoldsIt(Object handle) {
    return 'Kayıt defteri onu farklı bir anahtarla tutuyor; büyük ihtimalle bu telefonun bir geri yüklemeden önceki kimliği. @$handle kullanıcı adını ekleyenler sana ulaşmıyor. Buradan bırakılamaz ya da güncellenemez. Başka bir ad seç.';
  }

  @override
  String get handleForgetItOnThis => 'Bu telefonda unut';

  @override
  String get homeAddAContact => 'Kişi ekle';

  @override
  String get commonSettings => 'Ayarlar';

  @override
  String get homeYourKryfo => 'Senin Kryfo’n';

  @override
  String homeDateWeekday(Object weekday) {
    return '$weekday,';
  }

  @override
  String get homeAnHour => 'bir saat';

  @override
  String homeHours(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString saat',
      one: '$countString saat',
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
      other: '$countString dakika',
      one: '$countString dakika',
    );
    return '$_temp0';
  }

  @override
  String get homeKryfoIsOffline => 'Kryfo çevrimdışı';

  @override
  String homeTorHasNotBeen(Object howLong) {
    return 'Tor $howLong süredir bağlanamıyor. Bağlanana kadar hiçbir şey gelemez ya da gidemez.';
  }

  @override
  String get homeReconnecting => 'Yeniden bağlanıyor';

  @override
  String get homeReconnect => 'Yeniden bağlan';

  @override
  String get homeWhatIsWrong => 'Sorun ne';

  @override
  String get homeKryfoWillCheckIn => 'Kryfo 15 dakikada bir kontrol edecek';

  @override
  String get homeYourPhoneKeepsStopping =>
      'Telefonun Kryfo’yu durdurup duruyor';

  @override
  String get homeItHasClosedKryfo =>
      'Bugün Kryfo’yu üç kez kapattı, bu yüzden mesajlar geç geldi ya da bekledi. Kontroller bundan etkilenmez: Kryfo bağlı kalmak yerine 15 dakikada bir uyanır.';

  @override
  String get homeSwitchToCheckIns => 'Kontrollere geç';

  @override
  String get homeNotNow => 'Şimdi değil';

  @override
  String get homeNotificationsAreOff => 'Bildirimler kapalı';

  @override
  String get homeAndroidIsBlockingThem =>
      'Android onları engelliyor, bu yüzden Kryfo kapalıyken sana hiçbir şey ulaşmaz. Açtığında mesajlar yine de gelir.';

  @override
  String get homeCouldnTOpenIt => 'Açılamadı. Telefon ayarlarında Kryfo’yu ara';

  @override
  String get homeTurnThemOn => 'Bildirimleri aç';

  @override
  String get homeLeaveThemOff => 'Kapalı kalsın';

  @override
  String get homeOurRelayIsQuiet => 'Aktarıcımız sessiz';

  @override
  String get homeRelayModeUsesOnly =>
      'Aktarıcı modu yalnızca kendi aktarıcımızı kullanır ve o şu an yanıt vermiyor. Hızlı mod yanına herkese açık aktarıcılar ekler, böylece mesajlar yine ulaşır. Her iki durumda da her şey mühürlü kalır.';

  @override
  String get homeSwitchedToFast => 'Hızlı moda geçildi';

  @override
  String get homeUseFastMode => 'Hızlı modu kullan';

  @override
  String get homeKeepWaiting => 'Beklemeye devam et';

  @override
  String get homeNotConnecting => 'Bağlanamıyor';

  @override
  String get homeBridgesAreOnAnd =>
      'Köprüler açık ama tor hâlâ geçemedi. Köprüler daha yavaştır ve bazıları haber vermeden ölür. Ağın tor’u engellemiyorsa doğrudan bağlanmak daha hızlı ve daha güvenilirdir.';

  @override
  String get homeGoingDirectReconnecting => 'Köprüsüz · yeniden bağlanıyor';

  @override
  String get homeTurnBridgesOff => 'Köprüleri kapat';

  @override
  String get homeStillTrying => 'Hâlâ deneniyor';

  @override
  String get homeTorIsNotGetting =>
      'Tor geçemiyor. Bazı ağlar onu bilerek engeller. Kendi aktarıcımız tek ve sıradan bir bağlantıdır, genelde yine de çalışır - ya da köprüler, ama onları kurmak daha uzun sürer.';

  @override
  String get homeSwitchedToRelay => 'Aktarıcıya geçildi';

  @override
  String get homeUseOurRelay => 'Aktarıcımızı kullan';

  @override
  String get homeBridges => 'Köprüler';

  @override
  String get homeOffline => 'Çevrimdışı';

  @override
  String get homeWaiting => 'Bekliyor';

  @override
  String get homeNothingWaitingToSend => 'Bekleyen mesaj yok';

  @override
  String homeWaitingSendsWhenYou(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString bekliyor · bağlanınca gider',
      one: '$countString bekliyor · bağlanınca gider',
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
      other: '$countString bekliyor · tor hâlâ bağlanıyor',
      one: '$countString bekliyor · tor hâlâ bağlanıyor',
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
      other: '$countString bekliyor · seni geri eklemeleri gerek',
      one: '$countString bekliyor · seni geri eklemeleri gerek',
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
          '$countString bekliyor · $parkedString tanesi seni geri eklemelerini bekliyor',
      one:
          '$countString bekliyor · $parkedString tanesi seni geri eklemelerini bekliyor',
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
      other: '$countString bekliyor · şimdi gönderiliyor',
      one: '$countString bekliyor · şimdi gönderiliyor',
    );
    return '$_temp0';
  }

  @override
  String get commonRetry => 'Yeniden dene';

  @override
  String get homeNoKryfosYet => 'Henüz Kryfo yok.';

  @override
  String get homeScanTheirCodeSend =>
      'Onun kodunu tara, ona bir bağlantı gönder ya da sana verdiği @kullanıcı adını yaz.';

  @override
  String get homeAddSomeone => 'Birini ekle';

  @override
  String get homeArchived => 'Arşiv';

  @override
  String home1Chat(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString sohbet',
      one: '$countString sohbet',
    );
    return '$_temp0';
  }

  @override
  String get homeGroups => 'Gruplar';

  @override
  String get homeRoom => 'Oda';

  @override
  String get homeNew => 'Yeni';

  @override
  String homeRoomExpired(Object expiredRoomName) {
    return '$expiredRoomName · odanın süresi doldu';
  }

  @override
  String get homeMentionedYou => 'Senden bahsetti';

  @override
  String homeMembers(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString üye',
      one: '$countString üye',
    );
    return '$_temp0';
  }

  @override
  String get homeSupporter => 'Destekçi';

  @override
  String get homeArchivedChats => 'Arşivlenen sohbetler';

  @override
  String get homeUnmute => 'Sesi aç';

  @override
  String get homeMute => 'Sessize al';

  @override
  String get homeArchive => 'Arşivle';

  @override
  String get homeDeleteChat => 'Sohbeti sil';

  @override
  String get homeMessagesAndContactGone =>
      'Mesajlar ve kişi bu telefondan silinir';

  @override
  String get homeDeleteThisChat => 'Bu sohbet silinsin mi?';

  @override
  String homeEveryMessageWithGoes(Object c) {
    return '$c ile olan her mesaj gider ve artık kişilerinde olmaz. Yalnızca bu telefonu temizler - onun kopyası onda kalır. Yeniden yazarsa istekler arasına düşer.';
  }

  @override
  String get homeQueued => 'Sırada';

  @override
  String get homeBlocked => 'Engellendi';

  @override
  String get homeRoomInvite => 'Oda daveti';

  @override
  String get homeNow => 'Şimdi';

  @override
  String homeM(Object inMinutes) {
    return '$inMinutes dk';
  }

  @override
  String homeH(Object inHours) {
    return '$inHours sa';
  }

  @override
  String get homeYesterday => 'Dün';

  @override
  String homeD(Object inDays) {
    return '$inDays g';
  }

  @override
  String get homeNoteToSelf => 'Kendime not';

  @override
  String get homeOnlyOnThisPhone => 'Yalnızca bu telefonda';

  @override
  String get homeSaved => 'Kaydedilenler';

  @override
  String get homeKeptFromEveryChat => 'Tüm sohbetlerden saklananlar';

  @override
  String get homeRequests => 'İstekler';

  @override
  String home1PersonWantsTo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString kişi sana ulaşmak istiyor',
      one: '$countString kişi sana ulaşmak istiyor',
    );
    return '$_temp0';
  }

  @override
  String introduceGotItButCould(Object b, Object c) {
    return '$b aldı ama $c ulaşılamaz durumdaydı';
  }

  @override
  String introduceGotItButCouldNotBe(Object c, Object b) {
    return '$c aldı ama $b ulaşılamaz durumdaydı';
  }

  @override
  String introduceIntroduced(Object b, Object c) {
    return '$b ve $c artık birbirinin kartına sahip';
  }

  @override
  String get introduceCouldNotReachEither =>
      'İkisine de ulaşılamadı. Daha sonra tekrar dene';

  @override
  String introduceIntroduceTo(Object peerName) {
    return 'Tanıştır: $peerName ve...';
  }

  @override
  String get introduceBothOfThemGet =>
      'İkisi de diğerinin kartını alır. Hiçbiri, diğerine verdiğin takma adı görmez.';

  @override
  String get introduceNoOneElseTo =>
      'Henüz tanıştıracak başka kimse yok. Önce başka bir kişi ekle.';

  @override
  String get introduceANoteLikeMy =>
      'Bir not, örneğin “kuzenim” - isteğe bağlı';

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
      other: 'Bu hafta $leftString/$maxString tanıştırma hakkın kaldı',
      one: 'Bu hafta $leftString/$maxString tanıştırma hakkın kaldı',
    );
    return '$_temp0';
  }

  @override
  String introduceNoIntroductionsLeftNext(Object refillPhrase) {
    return 'Tanıştırma hakkın kalmadı. Sonraki $refillPhrase açılır';
  }

  @override
  String get introduceIntroduce => 'Tanıştır';

  @override
  String get keyVerificationSafetyNumber => 'Güvenlik numarası';

  @override
  String keyVerificationWith(Object peerName) {
    return '$peerName ile';
  }

  @override
  String keyVerificationIfSeesTheSame(Object peerName) {
    return '$peerName de aynı numarayı görüyorsa mesajların yalnızca ikinize özeldir. Yüz yüze ya da güvendiğin bir aramada karşılaştırmak emin olmanın en sağlam yoludur - ama isteğe bağlıdır, sohbet etmek için asla gerekmez.';
  }

  @override
  String get keyVerificationVerified => 'Doğrulandı';

  @override
  String get keyVerificationMarkAsVerified => 'Doğrulanmış işaretle';

  @override
  String get lockFileThatPasswordDoesNot => 'Bu şifre onu açmıyor.';

  @override
  String get lockFileThisFileIsDamaged => 'Bu dosya hasarlı.';

  @override
  String get lockFileThisFileWasLocked =>
      'Bu dosya şifreyle değil, bir anahtarla kilitlenmiş.';

  @override
  String get lockFileThisIsNotA => 'Bu kilitli bir dosya değil.';

  @override
  String get lockFileNotEnoughFreeMemory => 'Şu an yeterli boş bellek yok.';

  @override
  String get lockFileStopped => 'Durduruldu.';

  @override
  String get lockFileItNeedsAPassword => 'Şifre gerekiyor.';

  @override
  String get lockFileKryfoCouldNotRead =>
      'Kryfo dosyayı okuyamadı ya da yazamadı.';

  @override
  String get lockFileCheckCapitalsAndSpaces =>
      'Büyük harflere ve boşluklara bak. Onu kimse sıfırlayamaz, biz de dahil.';

  @override
  String get lockFileItMayHaveBeen =>
      'Yolda yarım kalmış olabilir. Yeniden gönderilmesini iste. Hiçbir şey kaydedilmedi.';

  @override
  String get lockFileItOpensWithThe =>
      'Kimin için yapıldıysa onun anahtar dosyasıyla, bilgisayardaki age aracında açılır. Kryfo şifreyle kilitlenen türü açar.';

  @override
  String get lockFileKryfoOpensFilesLocked =>
      'Kryfo, age ile kilitlenmiş dosyaları açar. Bunlar genelde .age ile biter.';

  @override
  String get lockFileCloseAFewApps =>
      'Birkaç uygulamayı kapatıp tekrar dene. Şifre kontrolü kısa bir süre için birkaç yüz megabayt ister.';

  @override
  String get lockFileNothingWasSaved => 'Hiçbir şey kaydedilmedi.';

  @override
  String get lockFileTypeOneOrLet =>
      'Bir tane yaz ya da Kryfo dört kelime önersin.';

  @override
  String get lockFileTheAppThatHolds =>
      'Dosyayı tutan uygulama onu geri almış olabilir. Yeniden seç.';

  @override
  String get lockFileHidePassword => 'Şifreyi gizle';

  @override
  String get lockFileShowPassword => 'Şifreyi göster';

  @override
  String get lockFileChangeFile => 'Dosyayı değiştir';

  @override
  String get lockFileChange => 'Değiştir';

  @override
  String lockFileOf(Object prettySize, Object prettySize2) {
    return '$prettySize / $prettySize2';
  }

  @override
  String get lockFileEverythingStaysOnThis => 'Her şey bu telefonda kalır.';

  @override
  String get lockFileCouldNotMakeOne => 'Oluşturulamadı. Kendin yaz.';

  @override
  String get lockFileWriteItDownBefore =>
      'Dosyayı kilitlemeden önce şifreyi bir yere yaz';

  @override
  String get lockFileNoAppOnThis =>
      'Bu telefondaki hiçbir uygulama dosyayı almadı.';

  @override
  String get lockFileSaved => 'Kaydedildi';

  @override
  String get lockFileCouldNotSaveIt =>
      'Oraya kaydedilemedi. Başka bir klasör dene.';

  @override
  String get lockFileLocked => 'Kilitlendi';

  @override
  String get lockFileLockAFile => 'Dosya kilitle';

  @override
  String get lockFileMixingThePassword => 'Şifre karıştırılıyor';

  @override
  String get lockFileLocking => 'Kilitleniyor';

  @override
  String get lockFileSaveToFiles => 'Dosyalar’a kaydet';

  @override
  String get lockFileLockFile => 'Dosyayı kilitle';

  @override
  String get lockFileOnePassword => 'Tek şifre.';

  @override
  String get lockFileNothingElseOpensIt => 'Başka hiçbir şey onu açmaz.';

  @override
  String get lockFileFile => 'Dosya';

  @override
  String lockFileFromFiles(Object prettySize) {
    return '$prettySize · Dosyalar’dan';
  }

  @override
  String get lockFileFromFiles2 => 'Dosyalar’dan';

  @override
  String get lockFilePassword => 'Şifre';

  @override
  String get lockFileSuggestFourWords => 'Dört kelime öner';

  @override
  String get lockFileTypeItAgain => 'Tekrar yaz';

  @override
  String get lockFileTheTwoDoNot => 'İkisi henüz eşleşmiyor.';

  @override
  String get lockFileHideTheFileName => 'Dosya adını gizle';

  @override
  String lockFileItWillBeCalled(Object name) {
    return 'Adı “$name” olacak. Karşı tarafa bunun ne tür bir dosya olduğunu söyle.';
  }

  @override
  String get lockFileTheNameAloneCan =>
      'Ad tek başına içinde ne olduğunu söyleyebilir.';

  @override
  String get lockFileAnyoneWithThePassword =>
      'Şifreye sahip olan herkes onu açabilir; Kryfo’da ya da ücretsiz age aracının olduğu herhangi bir bilgisayarda. Şifreyi unutursan dosya sonsuza dek kaybolur. Onu kimse sıfırlayamaz, biz de dahil.';

  @override
  String get lockFileLocked2 => 'Kilitlendi.';

  @override
  String get lockFileOnlyThePasswordOpens => 'Onu yalnızca şifre açar.';

  @override
  String lockFileSafeToEmailOr(Object prettySize) {
    return '$prettySize · e-postayla göndermek ya da USB belleğe koymak güvenli';
  }

  @override
  String get lockFileNoKryfoOnThe =>
      'Karşı tarafta Kryfo yok mu? Bilgisayarda:';

  @override
  String get lockFileItAsksForThe =>
      'Şifreyi sorar. age ücretsizdir: age-encryption.org';

  @override
  String lockTooManyTriesS(Object lockState) {
    return 'Çok fazla deneme · $lockState sn';
  }

  @override
  String get lockNotIt => 'Bu değil';

  @override
  String get lockYourPin => 'PIN kodun';

  @override
  String get lockUseFingerprint => 'Parmak izi kullan';

  @override
  String get lockSetupUnlockWithFingerprint =>
      'Parmak iziyle kilit açılsın mı?';

  @override
  String get lockSetupThePinStillWorks =>
      'PIN istediğin zaman yine çalışır. Bu sadece daha hızlı.';

  @override
  String get lockSetupUseFingerprint => 'Parmak izi kullan';

  @override
  String get lockSetupPinOnly => 'Yalnızca PIN';

  @override
  String get lockSetupOnceMore => 'Bir kez daha';

  @override
  String get lockSetupSetAPin => 'PIN belirle';

  @override
  String get lockSetupThoseWereDifferentFrom =>
      'İkisi farklıydı. Baştan alalım.';

  @override
  String get lockSetupTheSameFourDigits => 'Aynı rakamları bir kez daha';

  @override
  String get lockSetupFourDigitsAnythingYou =>
      'Dört rakam veya daha fazlası, hatırlayacağın herhangi bir şey';

  @override
  String get modesOnion => 'Onion';

  @override
  String get modesFullOnionRoutingThree =>
      'Tam onion yönlendirme, üç atlama. Bir mesaj iki ila beş saniye sürer. Kiminle konuştuğunu kimse görmez.';

  @override
  String get modesSlower => 'Daha yavaş';

  @override
  String get modesRelay => 'Aktarıcı';

  @override
  String get modesOneSealedConnectionTo =>
      'Kryfo’nun kendi aktarıcısına tek bir mühürlü bağlantı; kayıt tutacak hiçbir şeyi olmayan bir vpn gibi. Gönderilenler yaklaşık bir saniyede ulaşır ve tor’un engellendiği yerlerde de çalışır.';

  @override
  String get modesQuick => 'Hızlı';

  @override
  String get modesRelayOnly => 'Yalnızca aktarıcı';

  @override
  String get modesFast => 'Hızlı';

  @override
  String get modesPlainConnectionsToEvery =>
      'Her aktarıcıya düz bağlantılar. Neredeyse anında ve üçü içinde en az gizli olanı.';

  @override
  String get modesInstant => 'Anında';

  @override
  String get modesEveryRelayYouUse =>
      'Kullandığın her aktarıcı, yalnızca bizimki değil, bağlandığın adresi bilir. Mesajlar yine mühürlüdür, ama mesaj gönderdiğin gerçeği değil. Varsayılan olarak kapalı, yeniden kurulumdan sonra da yine kapalı.';

  @override
  String get modesSpeed => 'Hız';

  @override
  String get modesPrivacy => 've gizlilik';

  @override
  String get modesChangeGloballyOrPer =>
      'Genel olarak ya da sohbet başına değiştir';

  @override
  String get modesSoon => 'Yakında';

  @override
  String get modesActive => 'Etkin';

  @override
  String get modesSpeed2 => 'HIZ';

  @override
  String get modesHops => 'ATLAMA';

  @override
  String get modesIp => 'IP';

  @override
  String get modesVisible => 'Görünür';

  @override
  String get modesHidden => 'Gizli';

  @override
  String modesHeadsUp(Object warning) {
    return '*Dikkat:* $warning';
  }

  @override
  String get modesOnionIsTheDefault =>
      'Varsayılan mod Onion; sen değiştirmedikçe öyle kalır. Geçiş bir sonraki mesajda etkili olur.';

  @override
  String get modesFastMode => 'Hızlı mod';

  @override
  String get modesPlainConnectionsToEveryRelayQuicker =>
      'Her aktarıcıya düz bağlantılar. Daha hızlıdır ve aktarıcılar IP adresini görebilir. Mesajlar her durumda uçtan uca şifreli kalır.';

  @override
  String get modesTurnOnFastMode => 'Hızlı modu aç';

  @override
  String get modesKeepItOff => 'Kapalı kalsın';

  @override
  String get movedWipeThisPhone => 'Kryfo bu telefondan silinsin mi?';

  @override
  String get movedEverythingKryfoHoldsHere =>
      'Kryfo’nun burada tuttuğu her şey gider: mesajlar, kişiler, anahtarlar. Diğer cihaz hepsini korur. Bu geri alınamaz.';

  @override
  String get movedWipeIt => 'Sil';

  @override
  String get movedNotMovingAfterAll => 'Taşınmaktan vaz mı geçtin?';

  @override
  String get movedOnlyDoThisIf =>
      'Bunu yalnızca yedek hiçbir yere içe aktarılmadıysa yap. Aktarıldıysa artık iki cihaz tek bir kimliği taşıyor ve iki cihazda da mesajlar kaybolmaya başlayacak.';

  @override
  String get movedIMStayingHere => 'Burada kalıyorum';

  @override
  String get movedStayingHere => 'Burada kalıyorsun';

  @override
  String movedKryfoWillCloseNow(Object myId) {
    return 'Kryfo şimdi kapanacak. $myId olarak yeniden açmak için simgeye dokun.';
  }

  @override
  String get movedReopenKryfo => 'Kryfo’yu yeniden aç';

  @override
  String get movedThisKryfoHasMoved => 'Bu Kryfo taşındı';

  @override
  String movedIsNowOnAnother(Object myId) {
    return '$myId artık başka bir cihazda. Bu telefon burada olanı hâlâ gösterebilir ama buraya yeni hiçbir şey gelmeyecek, buradan gönderdiğin hiçbir şey de kimseye ulaşmayacak.';
  }

  @override
  String get movedKeepItToRead => 'Okumak için tut';

  @override
  String get movedWipeThisPhone2 => 'Kryfo’yu bu telefondan sil';

  @override
  String get movedIMNotMoving => 'Taşınmaktan vazgeçtim';

  @override
  String get myKryfoAHandleIs3 =>
      'Kullanıcı adı 3 ile 20 arası harf, rakam ya da _ olur';

  @override
  String get myKryfoInviteCopiedClearsIn =>
      'Davet kopyalandı · 60 sn içinde silinir';

  @override
  String myKryfoAddMeOnKryfo(Object myId, Object uri) {
    return 'Beni Kryfo’da ekle. Kimliğim: $myId\n\nBeni eklemek için dokun:\n$uri\n\nKryfo gizli bir mesajlaşma uygulaması. Telefon numarası yok, e-posta yok.';
  }

  @override
  String get myKryfoAddMeOnKryfo2 => 'Beni Kryfo’da ekle';

  @override
  String get myKryfoAddSomeone => 'Birini ekle';

  @override
  String get myKryfoKryfoDoesnTScan =>
      'Kryfo rehberini taramaz, bütün mesele bu.';

  @override
  String get myKryfoIfThisLinkEnds =>
      'Bu bağlantı istemediğin bir yere düşerse ayarlardan sıfırla. O zaman ona sahip herkesin yenisine ihtiyacı olur.';

  @override
  String get myKryfoAlreadyShareAFriend =>
      'Kryfo’da ortak bir arkadaşınız mı var? O, kendi sohbetinden ikinizi tanıştırabilir, siz de istek adımını atlarsınız.';

  @override
  String get myKryfoHandleCopied => 'Kullanıcı adı kopyalandı';

  @override
  String get myKryfoTheyReHereWith => 'O şu an yanımda';

  @override
  String get myKryfoPointYourPhonesAt =>
      'Telefonlarınızı birbirine doğrult. Hiçbir şey bir sunucudan geçmez.';

  @override
  String get myKryfoScanTheirsInstead => 'Onunkini tara';

  @override
  String get myKryfoTheyReadYouA => 'Sana bir kod okuyor';

  @override
  String get myKryfoTheyReSomewhereElse => 'Başka bir yerde';

  @override
  String get myKryfoSendThemALink =>
      'Ona bir bağlantı gönder. Doğrudan ekleme ekranında açılır.';

  @override
  String get myKryfoYourLinkAppearsOnce =>
      'Çevrimiçi olunca bağlantın burada görünür';

  @override
  String get myKryfoTheLinkCarriesYour =>
      'Bağlantı kimliğini, adresini ve sohbet başlatmak için gereken anahtarları taşır. Ayarlardan sıfırlayana kadar çalışır.';

  @override
  String get myKryfoSendTheLink => 'Bağlantıyı gönder';

  @override
  String get myKryfoAsACard => 'Kart olarak';

  @override
  String get myKryfoAnImageWithThe => 'QR kodlu bir resim';

  @override
  String get myKryfoAsAFile => 'Dosya olarak';

  @override
  String get myKryfoContactFile => 'Kişi dosyası';

  @override
  String get myKryfoIKnowTheirHandle => 'Kullanıcı adını biliyorum';

  @override
  String get myKryfoTypeTheNameThey =>
      'Sana verdiği @adı yaz. Bir tane aldıysa çalışır.';

  @override
  String get myKryfoTheLookupAsksFor =>
      'Arama yalnızca o adı gönderir, senin hakkında hiçbir şey göndermez. İlk mesajın yine de ona istek olarak ulaşır.';

  @override
  String get myKryfoLooking => 'Aranıyor…';

  @override
  String get myKryfoFindThem => 'Bul';

  @override
  String get myKryfoYourAddressAppearsOnce =>
      'Çevrimiçi olunca adresin burada görünür';

  @override
  String get myKryfoAPublicHandle => 'Genel kullanıcı adı';

  @override
  String get myKryfoPutItInA =>
      'Profil açıklamana koy. Onu bilen herkes seni bulabilir.';

  @override
  String get myKryfoANamePeopleCan =>
      'İnsanların seni bulabileceği bir ad. Bir tane alana kadar kapalı.';

  @override
  String get newGroupCouldNotCreate => 'Oluşturulamadı';

  @override
  String get newGroupNewGroup => 'Yeni grup';

  @override
  String get newGroupCreating => 'Oluşturuluyor…';

  @override
  String get newGroupCreate => 'Oluştur';

  @override
  String get newGroupGroupName => 'Grup adı';

  @override
  String get newGroupMembers => 'Üyeler';

  @override
  String get newGroupPickAtLeastOne => 'En az birini seç';

  @override
  String newGroupSelected(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString seçildi',
      one: '$countString seçildi',
    );
    return '$_temp0';
  }

  @override
  String get newGroupAddAtLeastOne =>
      'Grup oluşturmadan önce en az bir kişi ekle.';

  @override
  String get notesDeleteThisNote => 'Bu not silinsin mi?';

  @override
  String get notesGoneFromThisPhone => 'Bu telefondan kalıcı olarak silinir.';

  @override
  String get notesNoteToSelf => 'Kendime not';

  @override
  String get notesOnlyOnThisPhone => 'Yalnızca bu telefonda';

  @override
  String get notesAQuietPlace => 'Sessiz bir köşe';

  @override
  String get notesJotAnythingDownIt =>
      'Aklına geleni not al. Bu telefonda kalır, hiç dışarı çıkmaz.';

  @override
  String get notesJotSomethingDown => 'Bir şey not al…';

  @override
  String get onboardingPrivateByDefault => 'VARSAYILAN OLARAK GİZLİ';

  @override
  String get onboardingPrivateMessaging =>
      'Gizli mesajlaşma,\n*bit yeniği olmadan*.';

  @override
  String get onboardingYourNameIsThree =>
      '*Adın üç kelime.* Telefon yok, e-posta yok, rehber yok.';

  @override
  String get onboardingNobodyGetsInUnless =>
      '*Sen izin vermedikçe kimse giremez.* Arama yok. İnsanlar elle, iki taraftan da eklenir.';

  @override
  String get onboardingTheFirstConnectionTakes =>
      '*İlk bağlantı bir dakika sürer.* Kryfo göndermeden önce gizli bir rota kurar. Sonrası hızlı.';

  @override
  String get onboardingBegin => 'Başla';

  @override
  String get onboardingHaveABackupRestore => 'Yedeğin mi var? Geri yükle →';

  @override
  String get onboardingKryfoIsOpenSource => 'Kryfo açık kaynaklı';

  @override
  String get onboardingYourKryfoId => 'KRYFO KİMLİĞİN';

  @override
  String get onboardingGeneratedFromAKey =>
      'Yalnızca bu telefonda duran bir anahtardan üretildi. *Akılda kalıcı, eşsiz, yalnızca senin.* Bu başka kimsede yok.';

  @override
  String get onboardingTryAnother => 'Başka dene';

  @override
  String get onboardingUseThisName => 'Bu adı kullan →';

  @override
  String get onboardingThreeWords => 'Üç kelime. *Yalnızca senin.*';

  @override
  String get onboardingPickA => 'Bir *yüz* seç.';

  @override
  String get onboardingDrawnOnThisPhone =>
      'Bir sayıdan bu telefonda çizildi, hiçbir yere yüklenmez. İstediğin zaman değiştir.';

  @override
  String get onboardingThePeopleYouMessage =>
      'Yazıştığın kişiler de bunu görür';

  @override
  String get onboardingKeepMyInitial => 'Baş harfim kalsın';

  @override
  String get onboardingThatOne => 'Bu olsun →';

  @override
  String get onboardingContinue => 'Devam →';

  @override
  String get onboardingHowYourMessages => 'Mesajların nasıl *yol alır*.';

  @override
  String get onboardingYouCanChangeThis =>
      'Bunu istediğin zaman ayarlardan değiştirebilirsin, herkes için ya da tek bir sohbet için.';

  @override
  String get onboardingOnion => 'Onion';

  @override
  String get onboardingSlowerAMessageTakes =>
      'Daha yavaş. Bir mesaj iki ila beş saniye sürer.';

  @override
  String get onboardingHidesYourAddressFrom =>
      'Adresini herkesten gizler, bizim aktarıcımız dahil.';

  @override
  String get onboardingRelay => 'Aktarıcı';

  @override
  String get onboardingOurRelaySeesYour =>
      'Aktarıcımız adresini görür. Başka kimse görmez.';

  @override
  String get onboardingAboutASecondWorks =>
      'Yaklaşık bir saniye. Tor’un engellendiği yerde çalışır.';

  @override
  String get onboardingFast => 'Hızlı';

  @override
  String get onboardingEveryRelayYouUse =>
      'Kullandığın her aktarıcı adresini görür. Üçü içinde en az gizli olanı.';

  @override
  String get onboardingNearInstant => 'Neredeyse anında.';

  @override
  String get onboardingKeepOnion => 'Onion kalsın →';

  @override
  String get onboardingUseThis => 'Bunu kullan →';

  @override
  String get onboardingSkipOnionIsA => 'Atla · Onion iyi bir varsayılan';

  @override
  String get onboardingThreeThingsThen => 'Üç şey,\nsonra *içeridesin*.';

  @override
  String get onboardingEverythingElseTheApp =>
      'Gerisini uygulama, gerektiğinde sana söyleyecek.';

  @override
  String get onboardingYourNameIsThreeWords => 'Adın üç kelime';

  @override
  String get onboardingThatIsTheWhole =>
      'Kimliğin bundan ibaret. Sızacak numara yok, oltalanacak e-posta yok, aranıp bulunacak hiçbir şey yok. Konuştuğun kişiler bu kelimeleri ve seçtiğin yüzü görür.';

  @override
  String get onboardingNobodyCanReachYou =>
      'Sen içeri almadıkça kimse sana ulaşamaz';

  @override
  String get onboardingAStrangerWithYour =>
      'Kelimelerini bilen bir yabancı yalnızca kapıyı çalabilir. İlk mesajı sen evet diyene kadar isteklerde bekler ve hayır dersen bunu hiçbir zaman öğrenmez.';

  @override
  String get onboardingTheFirstConnectionTakesAMinute =>
      'İlk bağlantı bir dakika sürer';

  @override
  String get onboardingKryfoBuildsAPrivateRouteBefore =>
      'Kryfo bir şey göndermeden önce gizli bir rota kurar. Sen çevrimdışıyken mesajlar bekler, döndüğünde gelir.';

  @override
  String get onboardingYourIdentityLivesOn =>
      'Kimliğin bu telefonda yaşar. Hazır olduğunda ayarlardan yedekle.';

  @override
  String get onboardingIUnderstand => 'Anladım →';

  @override
  String get onboardingOneQuiet => 'Tek bir sessiz *bildirim*.';

  @override
  String get onboardingAndroidNeedsAVisible =>
      'Bir uygulama arka planda dinlerken Android görünür bir bildirim ister. Kryfo kapalıyken mesajlar sana bu sayede ulaşır.';

  @override
  String get onboardingSilentAndAtThe =>
      'Sessiz ve bildirim panelinin en altında';

  @override
  String get onboardingItNeverBuzzesTurn =>
      'Asla titremez. Kapatırsan mesajlar uygulamayı yeniden açana kadar bekler.';

  @override
  String get onboardingGotIt => 'Anladım →';

  @override
  String get onboardingNow => 'Şimdi *birini ekle*.';

  @override
  String get onboardingTheAppIsReady =>
      'Uygulama hazır. Sen ekleyene ya da içeri alana kadar kimse sana mesaj atamaz.';

  @override
  String get onboardingEveryWayToAdd => 'Birini eklemenin her yolu';

  @override
  String get onboardingShowYourCodeSend =>
      'Kodunu göster, ona bir bağlantı gönder ya da sana verdiği @kullanıcı adını yaz.';

  @override
  String get onboardingScanTheirs => 'Onunkini tara';

  @override
  String get onboardingPointTheCameraAt => 'Kamerayı onun koduna tut';

  @override
  String get onboardingTheAppIsReadyWhenYou =>
      'Sen hazır olduğunda uygulama da hazır.';

  @override
  String get onboardingNotNowAddPeople => 'Şimdi değil · kişileri sonra ekle';

  @override
  String get openLockedOpened => 'Açıldı';

  @override
  String get openLockedOpenALockedFile => 'Kilitli dosya aç';

  @override
  String get openLockedCheckingThePassword => 'Şifre kontrol ediliyor';

  @override
  String get openLockedOpening => 'Açılıyor';

  @override
  String get openLockedFile => 'Dosya';

  @override
  String get openLockedOpenFile => 'Dosyayı aç';

  @override
  String get openLockedTypeThePassword => 'Şifreyi yaz.';

  @override
  String get openLockedItOpensOnThis => 'Bu telefonda açılır.';

  @override
  String get openLockedLockedFile => 'Kilitli dosya';

  @override
  String openLockedFromFiles(Object prettySize) {
    return '$prettySize · Dosyalar’dan';
  }

  @override
  String get openLockedFromFiles2 => 'Dosyalar’dan';

  @override
  String get openLockedPassword => 'Şifre';

  @override
  String get openLockedThePasswordIsChecked =>
      'Önce şifre kontrol edilir. Ancak ondan sonra Kryfo açılan dosyanın nereye konacağını sorar ve dosya doğrudan oraya gider.';

  @override
  String get openLockedOpened2 => 'Açıldı.';

  @override
  String get openLockedSavedWhereYouChose => 'Seçtiğin yere kaydedildi.';

  @override
  String get pairCodePairingCode => 'Eşleştirme kodu';

  @override
  String get pairCodeShowACode => 'Kod göster';

  @override
  String get pairCodeEnterOne => 'Kod gir';

  @override
  String get pairCodeSixDigits => 'Altı rakam';

  @override
  String get pairCodeLooking => 'Aranıyor…';

  @override
  String get pairCodeNothingThereYetTrying =>
      'Henüz bir şey yok · tekrar deneniyor';

  @override
  String get pairCodeNothingAtThatCode =>
      'Bu kodda bir şey yok. Silinmiş olabilir ya da henüz paylaşmamış olabilir.';

  @override
  String get pairCodeUnreached =>
      'Aktarıcılara ulaşılamadı. Birazdan yeniden dene.';

  @override
  String get pairCodeFailed => 'Olmadı. Yeniden dene.';

  @override
  String get pairCodeTypeTheSixDigits => 'Sana okuduğu altı rakamı yaz.';

  @override
  String get pairCodeAddThem => 'Ekle';

  @override
  String get pairCodeUsedTwice => 'Bu kod iki kez kullanıldı. Yenisini iste.';

  @override
  String get pairCodeIsThisThem => 'Bu o kişi mi?';

  @override
  String get pairCodeCheckMatches =>
      'Karşındakinin ekranıyla aynı mı, kontrol et';

  @override
  String get pairCodeNotThem => 'O kişi değil';

  @override
  String get pairCodeNotAdded => 'Eklenmedi. Yeni bir kod iste.';

  @override
  String get panicSetupThoseWereDifferentFrom =>
      'İkisi farklıydı. Baştan alalım.';

  @override
  String get panicSetupOnceMore => 'Bir kez daha';

  @override
  String get panicSetupTheSameFourDigits => 'Aynı rakamları bir kez daha';

  @override
  String get photoKnowsEverythingInside => 'İçindeki her şey';

  @override
  String get photoKnowsVideo => 'Video';

  @override
  String get photoKnowsPhoto => 'Fotoğraf';

  @override
  String get photoKnowsWhatThisVideoKnows => 'Bu video neler biliyor';

  @override
  String get photoKnowsWhatThisPhotoKnows => 'Bu fotoğraf neler biliyor';

  @override
  String get photoKnowsRemoveAllOfIt => 'Hepsini kaldır';

  @override
  String get photoKnowsKeepItAsIt => 'Olduğu gibi kalsın';

  @override
  String get photoKnowsReadOnThisPhone =>
      'BU TELEFONDA OKUNDU · VİDEO HİÇBİR YERE GİTMEDİ';

  @override
  String get photoKnowsReadOnThisPhoneThePhoto =>
      'BU TELEFONDA OKUNDU · FOTOĞRAF HİÇBİR YERE GİTMEDİ';

  @override
  String get photoKnowsReadingTheFile => 'Dosya okunuyor';

  @override
  String photoKnowsOf(Object prettySize, Object prettySize2) {
    return '$prettySize / $prettySize2';
  }

  @override
  String get photoKnowsEverythingStaysOnThis => 'Her şey bu telefonda kalır.';

  @override
  String photoKnowsMapWithAPin(Object place) {
    return 'İşaretli harita. $place';
  }

  @override
  String get photoKnowsDrawnOffline => 'ÇEVRİMDIŞI ÇİZİLDİ';

  @override
  String photoKnowsShowEverything(Object title) {
    return '$title. Hepsini göster';
  }

  @override
  String get pinsAppLock => 'Uygulama kilidi';

  @override
  String get pinsYourPin => 'PIN kodun';

  @override
  String get commonOn => 'Açık';

  @override
  String get commonOff => 'Kapalı';

  @override
  String get pinsOpensKryfoFourDigits =>
      'Kryfo’yu açar. Uygulama öne geldiğinde sorulur.';

  @override
  String get pinsChangePin => 'PIN’i değiştir';

  @override
  String get pinsSetAPin => 'PIN belirle';

  @override
  String get pinsTurnOff => 'Kapat';

  @override
  String get pinsTurnOffTheApp => 'Uygulama kilidi kapatılsın mı?';

  @override
  String get pinsThePinGoesAnd =>
      'PIN kaldırılır, silme PIN’i ve varsa gizli sohbetler de onunla birlikte. Telefonun kimin elindeyse Kryfo’yu senmiş gibi açar.';

  @override
  String get pinsUnlockWithFingerprint => 'Parmak iziyle kilidi aç';

  @override
  String get pinsWipePin => 'Silme PIN’i';

  @override
  String get pinsNeedsAPinFirst => 'Önce PIN gerekir';

  @override
  String get pinsSet => 'Belirlendi';

  @override
  String get pinsChangeWipePin => 'Silme PIN’ini değiştir';

  @override
  String get pinsSetAWipePin => 'Silme PIN’i belirle';

  @override
  String get pinsRemove => 'Kaldır';

  @override
  String get pinsRemoveTheWipePin => 'Silme PIN’i kaldırılsın mı?';

  @override
  String get pinsTheLockScreenKeeps =>
      'Kilit ekranı PIN’ini korur. Silme PIN’i artık hiçbir şey yapmaz.';

  @override
  String profileCopied(Object what) {
    return '$what kopyalandı';
  }

  @override
  String get profileProfile => 'Profil';

  @override
  String get profileChangeYourFace => 'Yüzünü değiştir';

  @override
  String get profileKryfoId => 'Kryfo kimliği';

  @override
  String get profileOnionAddress => 'Onion adresi';

  @override
  String get profileSupporterBadge => 'Destekçi rozeti';

  @override
  String profileYouAreAThank(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter': 'Bir destekçisin. Teşekkürler.',
      'patron': 'Bir hamisin. Teşekkürler.',
      'guardian': 'Bir koruyucusun. Teşekkürler.',
      'other': 'Bir destekçisin. Teşekkürler.',
    });
    return '$_temp0';
  }

  @override
  String get profileShowMyBadge => 'Rozetimi göster';

  @override
  String get profileOnMyOwnScreens => 'Kendi ekranlarımda';

  @override
  String get profileLetContactsSeeIt => 'Kişiler görebilsin';

  @override
  String get profileOffByDefault => 'Varsayılan: kapalı';

  @override
  String get profileShareConnect => 'Paylaş ve bağlan';

  @override
  String get profileMyKryfoCode => 'Kryfo kodum';

  @override
  String get profileAddContact => 'Kişi ekle';

  @override
  String get profileGiveAgain => 'Yeniden bağış yap';

  @override
  String get profileSupportKryfo => 'Kryfo’yu destekle';

  @override
  String get profileKryfoRunsOnWhat =>
      'Kryfo insanların verdikleriyle ayakta duruyor';

  @override
  String get profileKeepKryfoIndependent => 'Kryfo bağımsız kalsın';

  @override
  String get qrLink => 'Bağlantı';

  @override
  String get qrYourLinkAsTyped =>
      'BAĞLANTIN YAZDIĞIN GİBİ · İZLEYEN YÖNLENDİRME YOK';

  @override
  String get qrText => 'Metin';

  @override
  String get qrStaysInTheCode => 'KODUN İÇİNDE KALIR · HİÇBİR SUNUCU TUTMAZ';

  @override
  String get qrWiFi => 'Wi-Fi';

  @override
  String get qrMadeOnThisPhone =>
      'BU TELEFONDA YAPILDI · ŞİFREYİ HİÇBİR SİTE GÖRMEDİ';

  @override
  String get qrNetworkName => 'Ağ adı';

  @override
  String get qrPassword => 'Şifre';

  @override
  String get qrContact => 'Kişi';

  @override
  String get qrOnlyWhatYouType => 'YALNIZCA YAZDIĞIN · KİŞİLERİNDEN HİÇBİR ŞEY';

  @override
  String get qrName => 'Ad';

  @override
  String get qrPhone => 'Telefon';

  @override
  String get qrEmail => 'E-posta';

  @override
  String get qrOpensTheirMailApp =>
      'KARŞI TARAFIN E-POSTA UYGULAMASINI AÇAR · BURADAN HİÇBİR ŞEY GİTMEZ';

  @override
  String get qrTo => 'Kime';

  @override
  String get qrSubject => 'Konu';

  @override
  String get qrANumberNothingElse => 'BİR NUMARA · BAŞKA HİÇBİR ŞEY';

  @override
  String get qrNumber => 'Numara';

  @override
  String get qrSms => 'SMS';

  @override
  String get qrOpensTheirMessagesApp =>
      'KARŞI TARAFIN MESAJ UYGULAMASINI AÇAR · BURADAN HİÇBİR ŞEY GİTMEZ';

  @override
  String get qrMessage => 'Mesaj';

  @override
  String get qrLocation => 'Konum';

  @override
  String get qrCoordinatesOnlyNoMap =>
      'YALNIZCA KOORDİNAT · HİÇBİR HARİTA SERVİSİNE SORULMADI';

  @override
  String get qrLatitude => 'Enlem';

  @override
  String get qrLongitude => 'Boylam';

  @override
  String get qrBitcoin => 'Bitcoin';

  @override
  String get qrAddressAndAmountNo => 'ADRES VE TUTAR · ARADA ÖDEME SİTESİ YOK';

  @override
  String get qrAddress => 'Adres';

  @override
  String get qrAmountInBtc => 'BTC cinsinden tutar';

  @override
  String get qrInk => 'Mürekkep';

  @override
  String get qrAmber => 'Kehribar';

  @override
  String get qrViolet => 'Mor';

  @override
  String get qrCouldNotDrawThe => 'Resim çizilemedi.';

  @override
  String get qrSavedToYourGallery => 'Galerine kaydedildi';

  @override
  String get qrCouldNotSaveIt =>
      'Kaydedilemedi. Telefonda yer olup olmadığına bak.';

  @override
  String get qrNoAppOnThis => 'Bu telefondaki hiçbir uygulama resmi almadı.';

  @override
  String get qrTooMuchForOne => 'Tek bir kod için çok fazla. Kısalt.';

  @override
  String get qrThisIsALot =>
      'Bu, tek bir kod için epey fazla. Eski kameralar okuyamayabilir.';

  @override
  String get qrPrivateQrCode => 'Gizli QR kodu';

  @override
  String get qrColour => 'Renk';

  @override
  String get qrCopiedItLeavesThe =>
      'Kopyalandı. Bir dakika içinde panodan silinir';

  @override
  String get qrSecurity => 'Güvenlik';

  @override
  String get qrNone => 'Yok';

  @override
  String get qrSaveImage => 'Resmi kaydet';

  @override
  String qrColour2(Object name) {
    return 'Renk: $name';
  }

  @override
  String get qrTypeBelowAndThe => 'Aşağıya yaz,\nkod kendini çizsin';

  @override
  String get qrQrCode => 'QR kodu';

  @override
  String get qrHidePassword => 'Şifreyi gizle';

  @override
  String get qrShowPassword => 'Şifreyi göster';

  @override
  String get qrCopyPassword => 'Şifreyi kopyala';

  @override
  String get requestsSentAnAttachment => 'Bir ek gönderdi';

  @override
  String get requestsWantsToConnect => 'Bağlanmak istiyor';

  @override
  String get requestsAccepted => 'Kabul edildi';

  @override
  String requestsBlock(Object id) {
    return '$id engellensin mi?';
  }

  @override
  String get requestsNothingMoreFromThem =>
      'Ondan artık hiçbir şey sana ulaşmaz. İsteği ve mesajları silinir.';

  @override
  String get requestsBlocked => 'Engellendi';

  @override
  String get requestsDeleted => 'Silindi';

  @override
  String get requestsRequests => 'İstekler';

  @override
  String get requestsNoRequests => 'İstek yok';

  @override
  String get requestsMessagesFromPeopleYou =>
      'Eklemediğin kişilerden gelen mesajlar önce burada görünür.';

  @override
  String get requestsLooksSafeNothingSuspicious =>
      'Güvenli görünüyor · ilk mesajında şüpheli bir şey yok';

  @override
  String get commonAccept => 'Kabul et';

  @override
  String get requestsDecline => 'Reddet';

  @override
  String get restoreThatFileIsNot => 'Bu dosya bir Kryfo yedeği değil';

  @override
  String get restoreThisFileIsDamaged => 'Bu dosya hasarlı ve okunamıyor';

  @override
  String get restoreTypeThePassphraseThe =>
      'Dosya oluşturulurken kullanılan parola ifadesini yaz';

  @override
  String get restoreReplaceTheAccountOn =>
      'Bu telefondaki hesap değiştirilsin mi?';

  @override
  String get restoreWhatIsHereNow =>
      'Şu an burada olan her şey, kimliği, kişileri ve mesajlarıyla gider. Yerini dosya alır. Bu geri alınamaz.';

  @override
  String get restoreReplaceIt => 'Değiştir';

  @override
  String restoreCouldNotBeReleased(Object mine) {
    return '@$mine bırakılamadı';
  }

  @override
  String restoreTheRegistryDidNot(Object mine) {
    return 'Kayıt defteri yanıt vermedi. Devam edersen @$mine, bu telefonun birazdan kaybedeceği kimliği göstermeye devam eder. Onu ekleyen herkes aslında hiç kimseye yazıyor olacak ve bu ad bir daha alınamaz. En iyisi çevrimiçi olup bir kez daha denemek.';
  }

  @override
  String get restoreRestoreAnyway => 'Yine de geri yükle';

  @override
  String get restoreNotYet => 'Henüz değil';

  @override
  String get restoreRestored => 'Geri yüklendi';

  @override
  String restoreKryfoWillCloseNow(Object haloId) {
    return 'Kryfo şimdi kapanacak. $haloId olarak yeniden açmak için simgeye dokun.';
  }

  @override
  String get restoreReopenKryfo => 'Kryfo’yu yeniden aç';

  @override
  String get restoreTheRestoreDidNot =>
      'Geri yükleme tamamlanmadı. Hiçbir şey değiştirilmedi';

  @override
  String get restoreThisIdentity => 'bu kimlik';

  @override
  String get restoreMoveYourKryfoHere => 'Kryfo’nu buraya taşı';

  @override
  String restoreThisBackupIsRestoring(Object name) {
    return 'Bu yedek: $name. Geri yüklemek o kimliği bu cihaza taşır.';
  }

  @override
  String restoreThisBackupMadeOn(Object name, Object date, Object time) {
    return 'Bu yedek: $name, oluşturulma zamanı $date $time. Geri yüklemek o kimliği bu cihaza taşır.';
  }

  @override
  String restoreItHoldsOfPhotos(Object mb) {
    return 'İçinde $mb boyutunda fotoğraf, sesli not ve dosya var. Bu birkaç dakika sürebilir. Uygulamayı açık tut.';
  }

  @override
  String get restoreWhatFollows => 'Neler gelir';

  @override
  String get restoreYourNameYourCode => 'Adın, kodun ve her kişi.';

  @override
  String get restoreEveryConversationBackTo =>
      'Her sohbet, en başından itibaren.';

  @override
  String get restoreYourPhotosVoiceNotes =>
      'Fotoğrafların, sesli notların ve dosyaların.';

  @override
  String restoreYourPhotosVoiceNotesCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Fotoğrafların, sesli notların ve dosyaların · $countString.',
      one: 'Fotoğrafların, sesli notların ve dosyaların · $countString.',
    );
    return '$_temp0';
  }

  @override
  String get restoreYourOnionAddressSo =>
      'Onion adresin; böylece sana doğrudan ulaşanlar ulaşmaya devam eder.';

  @override
  String get restoreAnythingSentToYou =>
      'Eski telefon kapalıyken sana gönderilen her şey, gönderildikten sonraki on dört gün boyunca.';

  @override
  String get restoreYourSupporterBadgeIf => 'Varsa destekçi rozetin.';

  @override
  String get restoreWhatDoesnT => 'Neler gelmez';

  @override
  String get restoreTheOldPhoneStops =>
      'Buradan bir şey gönderdiğin anda eski telefon mesaj almayı bırakır. Yavaş yavaş değil. Bu cihazdan gönderdiğin ilk mesaj, eski telefonun takip edebileceği son mesajdır; ondan sonra ona ulaşan her şey orada okunamaz ve burada da seni beklemiyor olur.';

  @override
  String get restoreIfThePhoneThis =>
      'Bu dosyanın geldiği telefon hâlâ kullanılıyorsa devam etmeden önce orada Kryfo’yu kullanmayı bırak. Tek bir Kryfo’yu kullanan iki telefonda da mesajlar kaybolur.';

  @override
  String get restoreNotificationsNeedSettingUp =>
      'Bildirimlerin bu cihazda yeniden ayarlanması gerekir.';

  @override
  String get restoreMoveItHere => 'Buraya taşı';

  @override
  String get restoreNotNow => 'Şimdi değil';

  @override
  String get restoreRestore => 'Geri yükle';

  @override
  String get restoreFromABackupFile => 'Bir yedek dosyasından';

  @override
  String get restoreABackupBringsBack =>
      'Yedek; kimliğini, kişilerini ve dosya oluşturulduğunda telefonda olan mesajları geri getirir. O zamandan beri söylenenler içinde yok.';

  @override
  String get restoreTheFile => 'Dosya';

  @override
  String get restorePickTheBackupFile => 'Yedek dosyasını seç';

  @override
  String get restoreThePassphrase => 'Parola ifadesi';

  @override
  String get restoreTheOneTheFile => 'Dosya oluşturulurken kullanılan';

  @override
  String get restoreWhatComesBack => 'Neler geri gelir';

  @override
  String get restoreChecking => 'Kontrol ediliyor…';

  @override
  String get restoreCheckTheFile => 'Dosyayı kontrol et';

  @override
  String get restoreReleasingYourHandle => 'Kullanıcı adın bırakılıyor…';

  @override
  String restoreMoving(Object progress) {
    return 'Taşınıyor… $progress';
  }

  @override
  String get restoreRestoring => 'Geri yükleniyor…';

  @override
  String get restoreNotThisOne => 'Bu değil';

  @override
  String get restoreDateUnknown => 'Tarih bilinmiyor';

  @override
  String get restoreAnIdentity => 'Bir kimlik';

  @override
  String get restoreMessagesSentOrReceived =>
      'O tarihten sonra gönderilen ya da alınan mesajlar bu dosyada yok.';

  @override
  String restoreGb(Object bytes) {
    return '$bytes GB';
  }

  @override
  String restoreMb(Object bytes) {
    return '$bytes MB';
  }

  @override
  String get roomCreateCouldNotCreateThe => 'Oda oluşturulamadı';

  @override
  String get roomCreateBurnerRoom => 'Geçici oda';

  @override
  String get roomCreateARoomThatEnds =>
      'Sona eren bir oda. Herkes ona özel üretilmiş bir anahtarla katılır ve oda bitince hiçbir telefonda hiçbir şey kalmaz.';

  @override
  String get roomCreateRoomName => 'Oda adı';

  @override
  String get roomCreateEndsAfter => 'Bitiş süresi';

  @override
  String get roomCreateMemberCap => 'Üye sınırı';

  @override
  String roomCreateNoOnePastThe(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'İlk $countString kişiden sonra kimse giremez',
      one: 'İlk $countString kişiden sonra kimse giremez',
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
      other: 'Kapalı. Bağlantıya sahip herkes, en fazla $countString kişi',
    );
    return '$_temp0';
  }

  @override
  String roomCreateThisRoomAndEverything(Object expiryWords) {
    return 'Bu oda ve içindeki her şey $expiryWords sonra kaybolur';
  }

  @override
  String get roomCreateCreating => 'Oluşturuluyor...';

  @override
  String get roomCreateCreateRoom => 'Oda oluştur';

  @override
  String get roomLinkSendTheRoomTo => 'Oda kime gönderilsin';

  @override
  String get roomLinkTheyWillKnowThis =>
      'Bu odanın senden geldiğini bilecek. İçeride o da herkes gibi bir anahtardır.';

  @override
  String get roomLinkNoContactsYet => 'Henüz kişi yok';

  @override
  String roomLinkEndsIn(Object time) {
    return '$time sonra biter';
  }

  @override
  String get roomLinkAnyoneWithThisCan =>
      'Buna sahip herkes oda bitene kadar katılabilir. Bu oda için üretilmiş bir anahtarla girerler ve gelmeden önce gönderilen hiçbir şeyi görmezler.';

  @override
  String get roomLinkRoomLinkCopied => 'Oda bağlantısı kopyalandı';

  @override
  String get roomLinkSendToAContact => 'Bir kişiye gönder';

  @override
  String get roomLinkCopyRoomLink => 'Bağlantıyı kopyala';

  @override
  String get savedVoiceNote => 'Sesli not';

  @override
  String get savedPhoto => 'Fotoğraf';

  @override
  String get savedSaved => 'Kaydedilenler';

  @override
  String get savedNothingSavedYet => 'Henüz kaydedilen yok';

  @override
  String get savedChatGone => 'O sohbet artık bu telefonda değil';

  @override
  String get savedLongPressAnyMessage =>
      'Herhangi bir mesaja uzun bas ve burada tutmak için kaydet.';

  @override
  String get savedViewInChat => 'Sohbette gör';

  @override
  String get savedPhoto2 => 'Fotoğraf';

  @override
  String get scanThatSNotA => 'Bu bir Kryfo QR kodu değil · tutmaya devam et';

  @override
  String get scanScanAKryfoQr => 'Kryfo QR kodu tara';

  @override
  String get scanFlash => 'Flaş';

  @override
  String get scanPointAtAKryfo =>
      'Bir Kryfo QR koduna tut · hiçbir şey telefonundan çıkmaz';

  @override
  String get seenWhatWeCanSee => 'Neleri görebiliyoruz';

  @override
  String get seenEveryMessengerClaimsPrivacy =>
      'Her mesajlaşma uygulaması gizlilik iddia eder. Bu, rota rota, bizi pek iyi göstermeyen kısımlar dahil net liste. Nedenini görmek için bir satıra dokun.';

  @override
  String get seenHonestAboutTheLast =>
      'Son satırlar konusunda dürüst olalım: uygulama kilidi, silme PIN’i ve şifreli depolama bunun için var ve hiçbir araç seni, açık telefonunu elinde tutan birinden kurtarmaz. Tehdit modelinin tamamı depodaki THREAT_MODEL.md dosyasında, LINDDUN çerçevesine göre yazıldı. Kod açık, yani bunların hiçbirine sırf sözümüze güvenip inanman gerekmiyor.';

  @override
  String get seenHidden => 'Gizli';

  @override
  String get seenNever => 'Asla';

  @override
  String get seenOnDevice => 'Cihazda';

  @override
  String get seenYours => 'Senin';

  @override
  String get seenUnaudited => 'Denetimsiz';

  @override
  String get seenWhoYouTalkTo => 'Kiminle konuştuğun';

  @override
  String get seenEachConversationGetsIts =>
      'Her sohbet, iki anahtardan türetilen kendi adresini alır. Aktarıcı bir çift insan değil, birbiriyle ilgisiz bırakma noktaları görür.';

  @override
  String get seenWhatYouSay => 'Ne söylediğin';

  @override
  String get seenEndToEndEncrypted =>
      'Signal double ratchet ile uçtan uca şifrelenir, sonra bir “hediye paketi” (gift wrap) içinde yeniden mühürlenir. Denesek bile okuyamayız.';

  @override
  String get seenYourIpAddress => 'IP adresin';

  @override
  String get seenOurRelay => 'Bizim aktarıcı';

  @override
  String get seenEveryRelay => 'Her aktarıcı';

  @override
  String get seenOnOnionEverythingLeaves =>
      'Onion modunda her şey tor üzerinden çıkar ve aktarıcı asla seni değil, bir çıkış düğümünü görür. Aktarıcı modunda bağlantı doğrudan kendi aktarıcımıza gider: adresini hiçbir şey iletmez ve hiçbir şey kaydedilmez, ama o tek bağlantıyı biz görürüz. Hızlı modda herkese açık her aktarıcı bağlandığını öğrenir, ama kime bağlandığını ya da ne söylediğini öğrenmez.';

  @override
  String get seenYourContactGraph => 'Kişi ağın';

  @override
  String get seenKryfoDoesNotScan =>
      'Kryfo rehberini taramaz. Bütün mesele bu. Burada sızacak bir telefon numarası yok.';

  @override
  String get seenIntroducer => 'Tanıştıran';

  @override
  String get seenWhenAContactIntroduces =>
      'Bir kişi seni biriyle tanıştırdığında, o kişi artık ikinizin bağlantılı olduğunu öğrenir. Başka kimse öğrenmez. Aktarıcı şifreli metin görür ve hiçbir sunucu bu ağı hiçbir zaman görmez.';

  @override
  String get seenTheScamShield => 'Dolandırıcılık kalkanı';

  @override
  String get seenRunsOnYourPhone =>
      'Uygulamayla gelen kurallarla telefonunda çalışır. Ağ yok, liste indirme yok. Yalnızca bir yabancıdan gelen ilk mesajı okur ve bir kişinin sana gönderdiği hiçbir şeyi göremez.';

  @override
  String get seenBurnerRooms => 'Geçici odalar';

  @override
  String get seenRoomKeys => 'Oda anahtarı';

  @override
  String get seenYouJoinARoom =>
      'Bir odaya ona özel üretilmiş bir anahtarla katılırsın, böylece içerideki insanlar başka yerde işe yarayacak hiçbir şey öğrenmez. Geç katılanlar geçmişi almaz. Süre dolduğunda anahtarlar, mesajlar ve medya yok edilir.';

  @override
  String get seenLinkPreviews => 'Bağlantı önizlemeleri';

  @override
  String get seenOverTor => 'Tor üzerinden';

  @override
  String get seenAPreviewIsFetched =>
      'Önizlemeyi gönderen, tor üzerinden alır ve önizleme şifreli mesajın içinde gider. Alan telefon hiçbir istek yapmaz. Web sitesi yalnızca tor kullanan birinin bir sayfa istediğini öğrenir, başka hiçbir şey öğrenmez. Hiçbir resim asla yüklenmez ve bir yabancının bağlantısı düz metin olarak kalır.';

  @override
  String get seenASeizedUnlockedPhone => 'El konulmuş, kilidi açık telefon';

  @override
  String get seenIfSomeoneHoldsYour =>
      'Biri telefonunu açık haldeyken elinde tutarsa mesajlarını okur. Uygulama kilidi, silme PIN’i ve şifreli depolama o noktadan önce işe yarar, sonra değil.';

  @override
  String get seenTheCryptoItself => 'Kriptografinin kendisi';

  @override
  String get seenTheRatchetAndStorage =>
      'Ratchet ve depolama katmanları standarttır. Onları birleştiren katman bizim ve bağımsız hiç kimse onu incelemedi. Bunu alfa sürüm say, çünkü öyle.';

  @override
  String get seenOnion => 'Onion';

  @override
  String get seenRelay => 'Aktarıcı';

  @override
  String get seenFast => 'Hızlı';

  @override
  String get settingsWipeKryfo => 'Kryfo silinsin mi?';

  @override
  String get settingsIdentityMessagesContactsAnd =>
      'Bu telefondaki kimlik, mesajlar, kişiler ve ayarlar. Yedeğin yoksa sonsuza dek kaybolur.';

  @override
  String get commonContinue => 'Devam';

  @override
  String settingsTypeWipeToConfirm(Object word) {
    return 'Onaylamak için “$word” yaz';
  }

  @override
  String get settingsTheLastStepNothing =>
      'Son adım. Ondan sonra hiçbir şey kalmaz.';

  @override
  String get settingsWipeWord => 'sil';

  @override
  String get settingsWipeKryfo2 => 'Kryfo’yu sil';

  @override
  String get settingsYourProtections => 'Korumaların';

  @override
  String get settingsTorRouting => 'Tor yönlendirme';

  @override
  String get settingsConnecting => 'Bağlanıyor';

  @override
  String get settingsOffMode => 'Kapalı · aktarıcı modu';

  @override
  String get settingsOffFastMode => 'Kapalı · hızlı mod';

  @override
  String get settingsAppLock => 'Uygulama kilidi';

  @override
  String get settingsBlockedByAndroid => 'Android engelliyor';

  @override
  String get settingsSpeedPrivacy => 'Hız ve gizlilik';

  @override
  String get settingsFast => 'Hızlı';

  @override
  String get settingsRelay1Hop => 'Aktarıcı · 1 atlama';

  @override
  String get settingsOnion3Hops => 'Onion · 3 atlama';

  @override
  String get settingsBridges => 'Köprüler';

  @override
  String get settingsForNetworksThatBlock => 'Tor’u engelleyen ağlar için';

  @override
  String get settingsGettingMessages => 'Mesaj alma';

  @override
  String settingsPreviewHidden(Object deliveryModeName) {
    return '$deliveryModeName · önizleme gizli';
  }

  @override
  String settingsPreviewShown(Object deliveryModeName) {
    return '$deliveryModeName · önizleme açık';
  }

  @override
  String get settingsRunInBackground => 'Arka planda çalış';

  @override
  String get settingsSoMessagesArrive => 'Mesajlar gelsin diye';

  @override
  String get settingsTransport => 'Aktarım';

  @override
  String get settingsWhatTheNetworkIs => 'Ağın ne yaptığı';

  @override
  String get settingsBlocked => 'Engellenenler';

  @override
  String get settingsAcceptIntroductions => 'Tanıştırmaları kabul et';

  @override
  String get settingsFriendsCanIntroduceYou =>
      'Arkadaşların seni kendi arkadaşlarıyla tanıştırabilir';

  @override
  String get settingsScamShield => 'Dolandırıcılık kalkanı';

  @override
  String get settingsChecksStrangersOnYour =>
      'Yabancıları telefonunda kontrol eder. Hiçbir şey dışarı çıkmaz';

  @override
  String get settingsBlockScreenshots => 'Ekran görüntüsünü engelle';

  @override
  String get settingsWholeAppHiddenFrom =>
      'Tüm uygulama son uygulamalardan ve ekran görüntülerinden gizlenir · bir sonraki açılışta etkili olur';

  @override
  String get settingsWholeAppHiddenFromRecentsAnd =>
      'Tüm uygulama son uygulamalardan ve ekran görüntülerinden gizlenir';

  @override
  String get settingsOnNextStart => 'Açık · sonraki açılışta';

  @override
  String get settingsOffNextStart => 'Kapalı · sonraki açılışta';

  @override
  String get settingsLightTheme => 'Açık tema';

  @override
  String get settingsSameProtectionBrighter => 'Aynı koruma, daha aydınlık';

  @override
  String get settingsAppLock2 => 'Uygulama kilidi';

  @override
  String get settingsYourPinAndA => 'PIN kodun ve gelişmiş koruma';

  @override
  String get settingsPinWipePin => 'PIN · silme PIN’i';

  @override
  String get settingsBackUpIdentity => 'Kimliği yedekle';

  @override
  String get settingsEncryptedFile => 'Şifreli dosya';

  @override
  String get settingsRestoreFromBackup => 'Yedekten geri yükle';

  @override
  String get settingsReplaceCurrent => 'Mevcudun yerine geçer';

  @override
  String get settingsDisguiseVoice => 'Sesi gizle';

  @override
  String get settingsShiftsYourPitchBefore =>
      'Sesli not gönderilmeden önce ses tonunu değiştirir';

  @override
  String get settingsWhyKryfo => 'Neden Kryfo';

  @override
  String get settingsHowItProtectsYou => 'Seni nasıl korur';

  @override
  String get settingsResetMyInviteLink => 'Davet bağlantımı sıfırla';

  @override
  String get settingsOldLinksAndCodes =>
      'Eski bağlantılar ve kodlar herkes için çalışmaz olur';

  @override
  String get settingsResetInviteLink => 'Davet sıfırlansın mı?';

  @override
  String get settingsAnyoneWithAnOld =>
      'Eski bir kod ya da bağlantıya sahip olan herkes, hiçbir rotadan sana ulaşamaz olur. Ona sahip olup hiç kullanmamış olanların senden yenisini alması gerekecek. Kişiler, sohbetler ve geçmiş kalır.';

  @override
  String get settingsReset => 'Sıfırla';

  @override
  String get settingsInviteResetShareThe =>
      'Davet sıfırlandı · yeni kodu paylaş';

  @override
  String get settingsWhatWeCanSee => 'Neleri görebiliyoruz';

  @override
  String get settingsTheHonestList => 'Dürüst liste';

  @override
  String get settingsVersion => 'Sürüm';

  @override
  String get settings030Alpha => '0.5.0 · alfa';

  @override
  String get settingsReportAnIssue => 'Sorun bildir';

  @override
  String get settingsBugOrSecurityFlaw => 'Hata ya da güvenlik açığı';

  @override
  String get settingsOpenSource => 'Açık kaynak';

  @override
  String get settingsLinkCopied => 'Bağlantı kopyalandı';

  @override
  String get settingsTheOfflineMapIn =>
      'Araçlar sekmesindeki çevrimdışı harita Natural Earth (kamu malı) verisinden çizilir. Yer adları GeoNames (geonames.org) kaynağından, CC BY 4.0 lisansıyla alınmıştır.';

  @override
  String get settingsNotIndependentlyAuditedPre =>
      'Bağımsız bir denetimden geçmedi. Alfa: test için iyi, ama henüz yüksek riskli kullanım için değil.';

  @override
  String get settingsDangerZone => 'Tehlikeli bölge';

  @override
  String get settingsWipeKryfoFromThis => 'Kryfo’yu bu telefondan sil';

  @override
  String get shieldCheckedOnThisPhone =>
      'Bu telefonda kontrol edildi. Hiçbir yere hiçbir şey gönderilmedi.';

  @override
  String get toolsMoreTools => 'Diğer araçlar';

  @override
  String get toolsCleanAPhotoOr => 'Fotoğraf ya da video temizle';

  @override
  String get toolsOrShareOneTo => 'Ya da galerinden Kryfo’ya paylaş';

  @override
  String get toolsMakeAPrivateQr => 'Gizli bir QR kodu oluştur';

  @override
  String get toolsLinksWiFiContacts =>
      'Bağlantılar, Wi-Fi, kişiler ve dahası. Çevrimdışı yapılır';

  @override
  String get toolsLockAFile => 'Dosya kilitle';

  @override
  String get toolsWithAPasswordOpens => 'Şifreyle. age olan her yerde açılır';

  @override
  String get toolsOpenALockedFile => 'Kilitli dosya aç';

  @override
  String get toolsAnyAgeFileSomeone =>
      'Birinin sana gönderdiği herhangi bir .age dosyası';

  @override
  String get toolsWorksOfflineNoContacts =>
      'Çevrimdışı çalışır · kişi gerekmez';

  @override
  String get toolsUsefulFrom => 'İşe yarar,';

  @override
  String get toolsTheFirstMinute => 'ilk dakikadan.';

  @override
  String get toolsEverythingHereHappensOn =>
      'Buradaki her şey bu telefonda olur. Hiçbir şey yüklenmez ve başka kimsenin Kryfo kullanması gerekmez.';

  @override
  String get toolsWhatDoesThisPhoto => 'Bu fotoğraf neler biliyor?';

  @override
  String get toolsPlacePhoneTime => 'Yer · telefon · zaman';

  @override
  String get toolsPickAPhotoAnd =>
      'Bir fotoğraf seç ve neleri ele verdiğini gör. Sonra temiz bir kopyasını sakla.';

  @override
  String get toolsPickAPhoto => 'Fotoğraf seç';

  @override
  String get toolsVideo => 'Video';

  @override
  String get transportTransport => 'Aktarım';

  @override
  String get transportNothingHereLeavesThe =>
      'Buradaki hiçbir şey telefondan çıkmaz. Motorun ne yapacağına karar verirken kullandığı durumun aynısı.';

  @override
  String get transportStayingAlive => 'Canlı kalma';

  @override
  String get transportCanSend => 'Gönderebilir';

  @override
  String get commonYes => 'Evet';

  @override
  String get transportNotYet => 'Henüz değil';

  @override
  String get transportOnline => 'Çevrimiçi';

  @override
  String get transportOffline => 'Çevrimdışı';

  @override
  String get transportQueuedToSend => 'Gönderim sırasında';

  @override
  String get transportOnionPublished => 'Onion yayımlandı';

  @override
  String transportYes(Object uploads) {
    return 'Evet ($uploads)';
  }

  @override
  String transportTryingS(Object pubFor) {
    return 'Deneniyor $pubFor sn';
  }

  @override
  String transportBenchedS(Object r) {
    return 'Beklemede $r sn';
  }

  @override
  String transportFails(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString hata',
      one: '$countString hata',
    );
    return '$_temp0';
  }

  @override
  String get transportOk => 'Tamam';

  @override
  String get transportRelaySubscriptions => 'Aktarıcı abonelikleri';

  @override
  String get transportLastSent => 'Son gönderim';

  @override
  String get transportNever => 'Hiç';

  @override
  String transportSAgo(Object sx) {
    return '$sx sn önce';
  }

  @override
  String get transportLastReceived => 'Son alım';

  @override
  String transportSAgo2(Object rx) {
    return '$rx sn önce';
  }

  @override
  String get transportWithNoContactsThe =>
      'Hiç kişi yokken uygulama hiçbir aktarıcı adresine abone olmaz, bu yüzden sana hiçbir mesaj ulaşamaz. Düzeltmek için birinin kodunu tara.';

  @override
  String get transportSendAnythingWaitingNow =>
      'Bekleyen her şeyi şimdi gönder';

  @override
  String get transportSending => 'Gönderiliyor…';

  @override
  String get transportNothingLeftWaiting => 'Bekleyen bir şey kalmadı';

  @override
  String transportStillWaiting(Object count) {
    return 'Hâlâ bekleyen: $count';
  }

  @override
  String get transportOff => 'Kapalı';

  @override
  String get transportStarting => 'Başlıyor';

  @override
  String get transportBootstrapped => 'Önyüklendi';

  @override
  String get transportPublishingAddress => 'Adres yayımlanıyor';

  @override
  String get transportReachable => 'Ulaşılabilir';

  @override
  String get transportOurRelayOnion => 'Aktarıcımız (onion)';

  @override
  String get transportNever2 => 'hiç';

  @override
  String get transportJustNow => 'Az önce';

  @override
  String transportMAgo(Object inMinutes) {
    return '$inMinutes dk önce';
  }

  @override
  String transportHAgo(Object inHours) {
    return '$inHours sa önce';
  }

  @override
  String transportDAgo(Object inDays) {
    return '$inDays g önce';
  }

  @override
  String transportM(Object inMinutes) {
    return '$inMinutes dk';
  }

  @override
  String transportHM(Object inHours, Object d) {
    return '$inHours sa $d dk';
  }

  @override
  String transportD(Object inDays) {
    return '$inDays g';
  }

  @override
  String transportMb(Object b) {
    return '$b MB';
  }

  @override
  String get transportYesCheckedJustNow => 'Evet · az önce kontrol edildi';

  @override
  String transportNoLast(Object ago) {
    return 'Hayır · son $ago';
  }

  @override
  String get transportLastMessageIn => 'Son gelen mesaj';

  @override
  String get transportBatteryExemption => 'Pil muafiyeti';

  @override
  String get transportUnknown => 'Bilinmiyor';

  @override
  String get transportExempt => 'Muaf';

  @override
  String get transportNotExemptTapTo => 'Muaf değil · düzeltmek için dokun';

  @override
  String get transportProcessUp => 'Süreç ayakta';

  @override
  String get transportLastStop => 'Son duruş';

  @override
  String transportEngine(Object mb, Object mb2) {
    return '$mb · motor $mb2';
  }

  @override
  String get transportLastRelayArrival => 'Aktarıcıdan son gelen';

  @override
  String get transportLastCheckIn => 'Son kontrol';

  @override
  String get transportNoneYet => 'Henüz yok';

  @override
  String get transportLastTorReconnect => 'Son Tor yeniden bağlanması';

  @override
  String get transportCatchUpByRelay => 'Aktarıcı bazında telafi';

  @override
  String get transportControlPort => 'Kontrol portu';

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
      other: '$dialsString deneme',
      one: '$dialsString deneme',
    );
    String _temp1 = intl.Intl.pluralLogic(
      timeouts,
      locale: localeName,
      other: '$timeoutsString zaman aşımı',
      one: '$timeoutsString zaman aşımı',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get transportJobRuns => 'Görev turları';

  @override
  String transportLast(Object jobRuns, Object ago) {
    return '$jobRuns · son $ago';
  }

  @override
  String get transportQuietStretches => 'Sessiz aralıklar';

  @override
  String get transportNone => 'Yok';

  @override
  String get transportClearThisRecord => 'Bu kaydı temizle';

  @override
  String get transportNothingYetThisProcess => 'Bu süreçte henüz bir şey yok';

  @override
  String transportM2(Object mins) {
    return '$mins dk';
  }

  @override
  String transportHM2(Object mins, Object mins2) {
    return '$mins sa $mins2 dk';
  }

  @override
  String transportTo(Object t, Object t2) {
    return '$t - $t2';
  }

  @override
  String vouchersVouchedBy(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Referans veren $countString kişi',
      one: 'Referans veren',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperAtmosphere => 'Atmosfer';

  @override
  String get wallpaperJustForYouThey =>
      'Yalnızca senin için. O kendi seçtiğini görür.';

  @override
  String get wallpaperYourPhoto => 'Fotoğrafın';

  @override
  String get wallpaperFromYourPhotos => 'Fotoğraflarından';

  @override
  String get wallpaperKeepIt => 'Böyle kalsın';

  @override
  String get whyKryfoWhyKryfo => 'Neden Kryfo';

  @override
  String get whyKryfoKryfoKreeFoGreek =>
      'Kryfo · KRİ-fo · Yunanca “gizli”.\nKonuşmak için sessiz bir yer; kimse izlemesin diye yapıldı.';

  @override
  String get whyKryfoRoutedThroughTor => 'Tor üzerinden yönlendirilir';

  @override
  String get whyKryfoByDefaultEveryMessage =>
      'Varsayılan olarak her mesaj tor üzerinden, yani bir aktarıcı zinciri boyunca gider. Kimse, ne biz ne de ağın, kiminle konuştuğunu ya da nerede olduğunu göremez.';

  @override
  String get whyKryfoEndToEndEncrypted => 'Uçtan uca şifreli';

  @override
  String get whyKryfoMessagesAreSealedWith =>
      'Mesajlar yalnızca senin ve konuştuğun kişinin elindeki anahtarlarla mühürlenir. Denesek bile okuyamayız.';

  @override
  String get whyKryfoNoServersHoldingYour => 'Hayatını tutan sunucular yok';

  @override
  String get whyKryfoNoAccountNoPhone =>
      'Hesap yok, telefon numarası yok, sohbetlerini saklayan merkezi bir sunucu yok. Sohbetlerin bu telefonda, depolamada şifreli olarak durur.';

  @override
  String get whyKryfoNothingLeaks => 'Hiçbir şey sızmaz';

  @override
  String get whyKryfoNoReadReceiptsOr =>
      'Okundu bilgisi ya da yazıyor işareti kimseye verilmez, kişi listesi yüklenmez. Çoğu uygulamanın sızdırdığı şey meta veridir - Kryfo sızdırmayacak şekilde yapıldı.';

  @override
  String get whyKryfoVerifyItIsReally => 'Gerçekten o olduğunu doğrula';

  @override
  String get whyKryfoCompareASafetyNumber =>
      'Güvenlik numarasını yüz yüze ya da güvendiğin bir kanaldan karşılaştır, böylece kimsenin kişini taklit etmediğini bilirsin.';

  @override
  String get whyKryfoTheHonestPart => 'Dürüst kısım';

  @override
  String get whyKryfoKryfoIsPreAlpha =>
      'Kryfo alfa aşamasında ve denetlenmedi. Kriptografi gerçek ama henüz dışarıdan hiçbir uzman kontrol etmedi; bu yüzden onu yapım aşamasında bir iş olarak gör, henüz hayatını emanet edeceğin bir şey olarak değil.';

  @override
  String get cleanerLocation => 'Konum';

  @override
  String get cleanerAlreadyBlankedByAndroid =>
      'Android tarafından zaten silinmiş';

  @override
  String get cleanerPhoneModel => 'Telefon modeli';

  @override
  String get cleanerTimeTaken => 'Çekim zamanı';

  @override
  String get cleanerSerialNumber => 'Seri numarası';

  @override
  String get cleanerOwnerName => 'Sahibinin adı';

  @override
  String get cleanerHiddenThumbnail => 'Gizli küçük resim';

  @override
  String get cleanerContentCredentials => 'İçerik kimlik bilgileri';

  @override
  String get cleanerDataAfterThePicture => 'Resimden sonraki veri';

  @override
  String cleaner1OtherField(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString diğer alan',
      one: '$countString diğer alan',
    );
    return '$_temp0';
  }

  @override
  String get lockWordsFourRandomWordsBeat =>
      'Dört rastgele kelime, tek bir zekice kelimeden iyidir.';

  @override
  String lockWordsTooShortAtLeast(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Çok kısa. En az $countString karakter.',
      one: 'Çok kısa. En az $countString karakter.',
    );
    return '$_temp0';
  }

  @override
  String get lockWordsWeakWhoeverGetsThe =>
      'Zayıf. Dosyayı ele geçiren istediği hızda tahmin edebilir.';

  @override
  String get lockWordsFairLongerIsStronger =>
      'İdare eder. Daha uzun, daha güçlü.';

  @override
  String get lockWordsStrongFourRandomWords =>
      'Güçlü. Dört rastgele kelime, tek bir zekice kelimeden iyidir.';

  @override
  String photoStoryKm(Object m) {
    return '$m km';
  }

  @override
  String photoStory1Metre(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString metre',
      one: '$countString metre',
    );
    return '$_temp0';
  }

  @override
  String get photoStoryFarFromAnyTown => 'Hiçbir kasabaya yakın değil';

  @override
  String photoStoryNear(Object where) {
    return '$where yakınında';
  }

  @override
  String photoStoryAboutKmFrom(Object near, Object where) {
    return '$where ile arası yaklaşık $near km';
  }

  @override
  String photoStoryS(Object s) {
    return '$s sn';
  }

  @override
  String photoStory1S(Object s) {
    return '1/$s sn';
  }

  @override
  String get photoStoryNotAKindKryfo => 'Kryfo’nun okuyabildiği bir tür değil.';

  @override
  String get photoStorySoItWillNot => 'O yüzden tahmin yürütmeyecek.';

  @override
  String get photoStoryThisFileIsDamaged =>
      'Bu dosya hasarlı ya da yarım kalmış.';

  @override
  String get photoStoryKryfoCouldNotRead =>
      'Kryfo dosyayı sonuna kadar okuyamadı.';

  @override
  String get photoStoryWhereItWasRecorded => 'Nerede kaydedildiği';

  @override
  String get photoStoryWhereItWasTaken => 'Nerede çekildiği';

  @override
  String photoStoryLocation(Object coordsLine) {
    return 'Konum: $coordsLine';
  }

  @override
  String photoStoryHeightAboveTheSea(Object fix) {
    return 'Deniz seviyesinden yükseklik: $fix m';
  }

  @override
  String get photoStoryLocationHiddenByAndroid =>
      'Konum Android tarafından gizlendi';

  @override
  String get photoStoryAndroidBlanksItWhen =>
      'Fotoğraf bu yolla seçildiğinde Android konumu siler. Galerinden Kryfo’ya paylaşmak çoğu zaman konumu korur. Galerindeki fotoğrafta hâlâ olabilir.';

  @override
  String get photoStoryLocationBlankedByAndroid =>
      'Konum: Kryfo görmeden önce Android tarafından silindi';

  @override
  String photoStoryF(Object r) {
    return 'f/$r';
  }

  @override
  String get photoStoryWhatTookIt => 'Neyle çekildi';

  @override
  String photoStoryPhoneOrCamera(Object phone) {
    return 'Telefon ya da kamera: $phone';
  }

  @override
  String get photoStoryWhenItWasRecorded => 'Ne zaman kaydedildiği';

  @override
  String get photoStoryToTheSecondWith => 'Saniyesine kadar, saat dilimiyle';

  @override
  String get photoStoryToTheSecond => 'Saniyesine kadar';

  @override
  String photoStoryTime(Object dateFormat) {
    return 'Zaman: $dateFormat';
  }

  @override
  String get photoStoryLens => 'Objektif';

  @override
  String photoStoryLens2(Object lens) {
    return 'Objektif: $lens';
  }

  @override
  String get photoStorySoftware => 'Yazılım';

  @override
  String photoStorySoftware2(Object software) {
    return 'Yazılım: $software';
  }

  @override
  String get photoStorySerialNumber => 'Seri numarası';

  @override
  String photoStorySerialNumber2(Object serial) {
    return 'Seri numarası: $serial';
  }

  @override
  String get photoStoryOwnerName => 'Sahibinin adı';

  @override
  String photoStoryOwner(Object r) {
    return 'Sahibi: $r';
  }

  @override
  String get photoStoryHiddenThumbnail => 'Gizli küçük resim';

  @override
  String get photoStoryASmallCopyOf =>
      'Dosyanın içinde resmin küçük bir kopyası. Kırpmanın kestiği yeri gösterebilir';

  @override
  String get photoStoryMakerNotes => 'Üretici notları';

  @override
  String get photoStoryMakerNotesABlock =>
      'Üretici notları: yalnızca üreticinin okuyabildiği bir blok';

  @override
  String get photoStoryEditingHistory => 'Düzenleme geçmişi';

  @override
  String get photoStoryXmpEditingHistoryAnd =>
      'XMP: düzenleme geçmişi ve etiketler';

  @override
  String get photoStoryCaptions => 'Açıklamalar';

  @override
  String get photoStoryIptcCaptionsAndCredits => 'IPTC: açıklamalar ve künye';

  @override
  String get photoStoryComment => 'Yorum';

  @override
  String get photoStoryAWrittenComment => 'Yazılı bir yorum';

  @override
  String get photoStoryContentCredentials => 'İçerik kimlik bilgileri';

  @override
  String get photoStorySecondPicture => 'İkinci resim';

  @override
  String get photoStoryASecondPictureInside =>
      'Dosyanın içinde ikinci bir resim';

  @override
  String get photoStoryMotionVideo => 'Hareketli video';

  @override
  String get photoStoryAShortVideoInside => 'Dosyanın içinde kısa bir video';

  @override
  String get photoStorySaveTime => 'Kayıt zamanı';

  @override
  String get photoStoryTheTimeItWas => 'Son kaydedildiği zaman';

  @override
  String get photoStoryTimeStamps => 'Zaman damgaları';

  @override
  String get photoStoryCreationTimeStamps => 'Oluşturma zaman damgaları';

  @override
  String get photoStoryDataAfterThePicture => 'Resimden sonraki veri';

  @override
  String photoStoryDataAfterTheEnd(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Resmin bitişinden sonraki veri: $countString bayt',
      one: 'Resmin bitişinden sonraki veri: $countString bayt',
    );
    return '$_temp0';
  }

  @override
  String photoStoryTextField(Object k) {
    return 'Metin alanı: $k';
  }

  @override
  String photoStoryVideoTag(Object k) {
    return 'Video etiketi: $k';
  }

  @override
  String photoStoryAlso(Object k) {
    return 'Ayrıca: $k';
  }

  @override
  String photoStoryCameraSettingsFlashFocus(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString kamera ayarı (flaş, odak, pozlama)',
      one: '$countString kamera ayarı (flaş, odak, pozlama)',
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
      other: '$countString alan daha',
      one: '$countString alan daha',
    );
    return '$_temp0';
  }

  @override
  String get photoStoryCameraSettings => 'Kamera ayarları';

  @override
  String photoStoryAccurateToAbout(Object metres) {
    return 'Yaklaşık $metres hassasiyetle.';
  }

  @override
  String get photoStoryEnoughToFindThe => 'Kapıyı bulmaya yeter.';

  @override
  String get photoStoryEnoughToFindTheStreet => 'Sokağı bulmaya yeter.';

  @override
  String get photoStoryEnoughToFindTheArea => 'Bölgeyi bulmaya yeter.';

  @override
  String get photoStoryItKnowsWhereYou => 'Nerede olduğunu biliyor.';

  @override
  String get photoStoryDownToTheBuilding => 'Binasına kadar.';

  @override
  String get photoStoryAndroidHidTheLocation => 'Android konumu gizledi.';

  @override
  String get photoStoryTheOriginalMayStill => 'Orijinalinde hâlâ olabilir.';

  @override
  String get photoStoryNoLocationInThis => 'Bunda konum yok.';

  @override
  String get photoStoryItStillSaysPlenty => 'Yine de çok şey söylüyor.';

  @override
  String get photoStoryThisOneKnowsNothing => 'Bu hiçbir şey bilmiyor.';

  @override
  String get photoStoryNothingToRemove => 'Kaldırılacak bir şey yok.';

  @override
  String get qrPayloadOpensALink => 'BİR BAĞLANTI AÇAR';

  @override
  String qrPayloadOpens(Object host) {
    return 'AÇAR: $host';
  }

  @override
  String get qrPayloadShowsANote => 'BİR NOT GÖSTERİR';

  @override
  String get qrPayloadScanToJoin => 'KATILMAK İÇİN TARA';

  @override
  String qrPayloadScanToJoin2(Object oneLine) {
    return 'KATILMAK İÇİN TARA · $oneLine';
  }

  @override
  String get qrPayloadANetworkNameIs => 'Ağ adı en fazla 32 karakter olabilir.';

  @override
  String get qrPayloadAWiFiPassword => 'Wi-Fi şifresi en az 8 karakterdir.';

  @override
  String get qrPayloadSavesAContact => 'BİR KİŞİ KAYDEDER';

  @override
  String get qrPayloadWritesAnEmail => 'E-POSTA YAZAR';

  @override
  String get qrPayloadThatDoesNotLook => 'Bu bir e-posta adresine benzemiyor.';

  @override
  String get qrPayloadCallsANumber => 'BİR NUMARAYI ARAR';

  @override
  String get qrPayloadWritesAText => 'MESAJ YAZAR';

  @override
  String get qrPayloadOpensAMap => 'HARİTA AÇAR';

  @override
  String get qrPayloadLatitudeRunsFrom90 =>
      'Enlem -90 ile 90, boylam -180 ile 180 arasındadır.';

  @override
  String get qrPayloadPayThisAddress => 'BU ADRESE ÖDE';

  @override
  String get qrPayloadABitcoinAddressIs =>
      'Bitcoin adresi yalnızca harf ve rakamdan oluşur.';

  @override
  String get qrPayloadTheAmountIsIn =>
      'Tutar BTC cinsindendir, en fazla 8 ondalık basamakla.';

  @override
  String vouchTextAnd(Object names, Object names2) {
    return '$names ve $names2';
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
      other: '$restString kişi daha',
      one: '$restString kişi daha',
    );
    return '$names, $names2 ve tanıdığın $_temp0';
  }

  @override
  String vouchTextVouchedBy(Object vouchNames) {
    return 'Referans veren: $vouchNames';
  }

  @override
  String vouchTextIntroducedBy(Object vouchNames) {
    return 'Tanıştıran: $vouchNames';
  }

  @override
  String vouchTextThisSharesSAddress(Object a, Object b) {
    return 'Bu, $a adlı kişinin adresini $b ile paylaşır';
  }

  @override
  String get bootFailedKryfoCouldNotStart => 'Kryfo başlatılamadı';

  @override
  String get bootFailedThisIsAFault =>
      'Bu, ağdaki değil bu cihazdaki bir arıza. Tor’un bununla ilgisi yok.';

  @override
  String get kryfoLinkTextThatLinkIsNot =>
      'Bu bağlantı Kryfo’nun okuyabileceği bir bağlantı değil';

  @override
  String kryfoLinkTextAdd(Object who) {
    return '$who eklensin mi?';
  }

  @override
  String kryfoLinkTextThisIsAnInvite(Object who) {
    return 'Bu, $who ile konuşmak için bir davet. Yalnızca bağlantının nereden geldiğini biliyorsan ekle.';
  }

  @override
  String get kryfoLinkTextAddThem => 'Ekle';

  @override
  String get kryfoLinkTextNotNow => 'Şimdi değil';

  @override
  String kryfoLinkTextJoin(Object roomName) {
    return 'Katıl: $roomName';
  }

  @override
  String get kryfoLinkTextKryfoLink => 'Kryfo bağlantısı';

  @override
  String kryfoLinkTextAdd2(Object who) {
    return 'Ekle: $who';
  }

  @override
  String get kryfoLinkTextBurnerRoom => 'GEÇİCİ ODA';

  @override
  String get kryfoLinkTextThisRoomHasClosed => 'Bu oda kapandı';

  @override
  String kryfoLinkTextClosesIn(Object time) {
    return '$time sonra kapanır';
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
      other: '$time sonra kapanır · en fazla $capString kişi',
      one: '$time sonra kapanır · en fazla $capString kişi',
    );
    return '$_temp0';
  }

  @override
  String get kryfoLinkTextJoin2 => 'Katıl';

  @override
  String get kryfoLinkTextYouJoinUnderA =>
      'Bu oda için üretilmiş bir anahtarla katılırsın. İçerideki hiç kimse Kryfo kimliğini görmez.';

  @override
  String get linkStubFetchedOverTorBy =>
      'Tor üzerinden alındı · senin cihazın tarafından';

  @override
  String get linkStubFetchedOverTorByTheirDevice =>
      'Tor üzerinden alındı · onun cihazı tarafından';

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
  String get mediaBubblesFile => 'DOSYA';

  @override
  String get mediaBubblesAudioUnavailable => 'Ses kullanılamıyor';

  @override
  String get mediaBubblesHidden => 'Gizli';

  @override
  String get mediaBubblesMicPermissionNeeded => 'Mikrofon izni gerekli';

  @override
  String get mediaBubblesReleaseToCancel => 'İptal için bırak';

  @override
  String get mediaBubblesVoiceHiddenSlideTo => 'Ses gizli · iptal için kaydır';

  @override
  String get mediaBubblesSlideToCancel => 'İptal için kaydır';

  @override
  String get mediaBubblesSendPhoto => 'Fotoğraf gönder';

  @override
  String get mediaBubblesAddACaption => 'Açıklama ekle…';

  @override
  String get motionStandby => 'BEKLEMEDE';

  @override
  String get motionConnecting => 'BAĞLANIYOR';

  @override
  String get motionBuilding => 'KURULUYOR';

  @override
  String get motionPublishing => 'YAYIMLANIYOR';

  @override
  String get motionReady => 'HAZIR';

  @override
  String get motionPreparingToConnect => 'Bağlanmaya hazırlanıyor';

  @override
  String get motionFindingAPrivatePath => 'Gizli bir yol aranıyor';

  @override
  String get motionCarvingThePath => 'Yol açılıyor';

  @override
  String get motionAnnouncingYourArrival => 'Gelişin duyuruluyor';

  @override
  String get motionYouReAnonymous => 'Anonimsin';

  @override
  String get motionTorIsStartingIn =>
      'Tor arka planda başlıyor. Bağlantı kuruldukça bu grafik yanar.';

  @override
  String get motionMakingAFreshRoute =>
      'Anonim aktarıcılar üzerinden yeni bir rota kuruluyor.';

  @override
  String get motionBouncingThroughRelaysSo =>
      'Kimse bunu sana kadar izleyemesin diye aktarıcılar arasında sekiyor.';

  @override
  String get motionTellingTheNetworkYou =>
      'Ağa çevrimiçi olduğun söyleniyor — nerede olduğun açığa çıkmadan.';

  @override
  String get motionYourIpIsHidden =>
      'IP adresin gizli. Sana yalnızca Kryfo’nu bilenler ulaşabilir.';

  @override
  String get motionBuilding2 => 'kuruluyor';

  @override
  String get motionOpen => 'açık';

  @override
  String get motionLive => 'canlı';

  @override
  String motionCircuit(Object circuit) {
    return 'Devre · *$circuit*';
  }

  @override
  String get motionDelivered => 'İletildi';

  @override
  String get motionSent => 'Gönderildi';

  @override
  String get motion1Hop => '1 atlama';

  @override
  String get motion3Hops => '3 atlama';

  @override
  String get movedStripThisKryfoHasMoved =>
      'Bu Kryfo başka bir cihaza taşındı. Buradan gönderilen hiçbir şey kimseye ulaşmaz.';

  @override
  String get navBarChats => 'Sohbetler';

  @override
  String get navBarTools => 'Araçlar';

  @override
  String get navBarSupport => 'Destekle';

  @override
  String get navBarMe => 'Ben';

  @override
  String get pairCodePanelPuttingYourInviteIn => 'Davetin hazırlanıyor';

  @override
  String get pairCodePanelYourInviteIsNot => 'Davetin henüz hazır değil';

  @override
  String get pairCodePanelReadSixDigitsOut =>
      'Altı rakamı yüksek sesle oku, seni ekleyebilsin. Başka hiçbir şeyin el değiştirmesi gerekmez.';

  @override
  String get pairCodePanelWorking => 'Hazırlanıyor';

  @override
  String get pairCodePanelOrMakeASix =>
      'Ya da okumak için altı haneli bir kod oluştur';

  @override
  String get pairCodePanelCodeCopied => 'Kod kopyalandı';

  @override
  String pairCodePanelBurnsIn(Object mm, Object ss) {
    return '$mm:$ss sonra silinir';
  }

  @override
  String get pairCodePanelTheyTapAddChoose =>
      'Karşındaki ekleme ekranını açar, kodu seçer ve bunları yazar.';

  @override
  String get pairCodePanelTheyOpenKryfoTap =>
      'Karşındaki Kryfo’yu açar, ekleme ekranında eşleştirme kodunu seçer ve bu altı rakamı yazar. Sonraki kişi için yenisini oluştur.';

  @override
  String get pairCodePanelYourWords => 'Üç kelimen';

  @override
  String pinsPinnedMessages(Object count) {
    return 'Sabitlenen mesajlar · $count';
  }

  @override
  String get pinsPinnedMessages2 => 'Sabitlenen mesajlar';

  @override
  String get pinsPhoto => 'Fotoğraf';

  @override
  String get pinsVoiceMessage => 'Sesli mesaj';

  @override
  String get pinsMessage => 'Mesaj';

  @override
  String pinsToday(Object hm) {
    return 'Bugün · $hm';
  }

  @override
  String get pinsPinned => 'Sabitlendi';

  @override
  String pinsOf(Object pinsLength, Object kMaxPins) {
    return '$pinsLength/$kMaxPins';
  }

  @override
  String get pinsNothingPinnedHereYet =>
      'Henüz sabitlenen bir şey yok. Bir mesaja basılı tut ve Sabitle’yi seç; sohbetteki herkes için burada durur.';

  @override
  String get pinsJump => 'Git';

  @override
  String get pinsUnpin => 'Kaldır';

  @override
  String powNoteFirstMessageToSomeone(int secs) {
    final intl.NumberFormat secsNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String secsString = secsNumberFormat.format(secs);

    return 'Yeni birine ilk mesaj · gerçek olduğu kanıtlanıyor · $secsString sn';
  }

  @override
  String powNoteFirstMessageSlow(int secs) {
    final intl.NumberFormat secsNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String secsString = secsNumberFormat.format(secs);

    return 'Yeni birine ilk mesaj · gerçek olduğu kanıtlanıyor · $secsString sn · yavaş bir telefonda bir dakikayı bulabilir';
  }

  @override
  String previewStripFetchedOverTor(Object domainOf) {
    return '$domainOf · tor üzerinden alındı';
  }

  @override
  String get previewStripDropThePreview => 'Önizlemeyi kaldır';

  @override
  String get previewStripAddPreview => 'Önizleme ekle';

  @override
  String get previewStripFetchingOverTor => 'Tor üzerinden alınıyor…';

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
  String get torBootSplashNoShortcutsNoTraces => 'Kestirme yok, iz yok';

  @override
  String get torBootSplashTheNetworkThatKeeps => 'Seni gizli tutan ağ ısınıyor';

  @override
  String get torBootSplashMadeOnThisPhone =>
      'Bu telefonda yapıldı. Hiçbir yere hiçbir şey gönderilmez.';

  @override
  String get torBootSplashFirstLaunchTakesA =>
      'İlk açılış biraz sürer · yalnızca başlangıçta';

  @override
  String get videoBubbleNothingHereOpensThat =>
      'Burada bunu açan bir şey yok · onun yerine paylaşılıyor';

  @override
  String videoBubbleMb(Object b) {
    return '$b MB';
  }

  @override
  String videoBubbleKb(Object b) {
    return '$b KB';
  }

  @override
  String get videoBubbleVideo => 'Video';

  @override
  String get notificationsChannelName => 'Mesajlar';

  @override
  String get cameraClose => 'Kapat';

  @override
  String get cameraFlash => 'Flaş';

  @override
  String get cameraPhoto => 'Fotoğraf';

  @override
  String get cameraVideo => 'Video';

  @override
  String get cameraRetake => 'Yeniden çek';

  @override
  String get seenIntroductions => 'Tanıştırmalar';

  @override
  String get donateAddress => 'Adres';

  @override
  String get donateCopy => 'Kopyala';

  @override
  String get donateDone => 'Bitti';

  @override
  String get donateTierSupporter => 'Destekçi';

  @override
  String get donateTierPatron => 'Hami';

  @override
  String get donateTierGuardian => 'Koruyucu';

  @override
  String get chatBlock => 'Engelle';

  @override
  String get chatDecline => 'Reddet';

  @override
  String get chatAccept => 'Kabul et';

  @override
  String get bridgesConnecting => 'Bağlanıyor';

  @override
  String get bridgesSavedTag => 'Kaydedildi';

  @override
  String get restoreMade => 'Oluşturuldu';

  @override
  String get restoreContacts => 'Kişiler';

  @override
  String get restoreMessages => 'Mesajlar';

  @override
  String get restoreAttachments => 'Ekler';

  @override
  String get restoreHiddenChats => 'Gizli sohbetler';

  @override
  String get restoreHiddenFollow =>
      'Gizli sohbetlerin, sonda seçeceğin yeni bir gizli sohbet PIN’iyle.';

  @override
  String get restoreChooseHiddenPin =>
      'Bu yedekte gizli sohbetler var. Onlar için bir gizli sohbet PIN’i seç.';

  @override
  String get restoreHiddenLockFirst =>
      'Gizli sohbetler uygulama kilidine ihtiyaç duyar, bu yüzden önce Kryfo’ya kendi PIN’i verilir.';

  @override
  String get shieldBlock => 'Engelle';

  @override
  String get shieldDelete => 'Sil';

  @override
  String get shieldIgnore => 'Yok say';

  @override
  String get profileIdentity => 'Kimlik';

  @override
  String get avatarPickerShape => 'Şekil';

  @override
  String get avatarPickerColour => 'Renk';

  @override
  String get avatarPickerTurn => 'Döndür';

  @override
  String get transportStatus => 'Durum';

  @override
  String get transportBootstrap => 'Önyükleme';

  @override
  String get transportNetwork => 'Ağ';

  @override
  String get transportConnectivity => 'Bağlantı';

  @override
  String get transportRelays => 'Aktarıcılar';

  @override
  String get transportTraffic => 'Trafik';

  @override
  String get transportContacts => 'Kişiler';

  @override
  String get transportKnown => 'Bilinen';

  @override
  String get transportListening => 'Dinleniyor';

  @override
  String get transportMemory => 'Bellek';

  @override
  String get settingsConnected => 'Bağlı';

  @override
  String get settingsScreenshots => 'Ekran görüntüleri';

  @override
  String get settingsBlocked2 => 'Engelli';

  @override
  String get settingsAllowed => 'İzinli';

  @override
  String get settingsOn => 'Açık';

  @override
  String get settingsOff => 'Kapalı';

  @override
  String get settingsNotifications => 'Bildirimler';

  @override
  String get settingsPrivacy => 'Gizlilik';

  @override
  String get settingsSecurity => 'Güvenlik';

  @override
  String get settingsBackup => 'Yedek';

  @override
  String get settingsVoice => 'Ses';

  @override
  String get settingsAbout => 'Hakkında';

  @override
  String get wallpaperGradients => 'Geçişler';

  @override
  String get wallpaperPatterns => 'Desenler';

  @override
  String get wallpaperMoods => 'Ruh halleri';

  @override
  String get confirmSheetKeep => 'Kalsın';

  @override
  String get confirmSheetSave => 'Kaydet';

  @override
  String get confirmSheetCancel => 'İptal';

  @override
  String bridgesSaved(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString köprü',
      one: '$countString köprü',
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

    return '$goodString kabul edildi, $badString anlaşılmadı';
  }

  @override
  String get bridgesNoneUsable =>
      'Bu satırların hiçbiri kullanılabilir bir köprü değil, bu yüzden köprüler kapalı kalıyor';

  @override
  String get bridgesCouldNotApply =>
      'Köprüler uygulanamadı. Yeniden kaydetmeyi dene.';

  @override
  String get languageTitle => 'Dil';

  @override
  String get languageMatchPhone => 'Telefonla aynı';

  @override
  String languageMatchPhoneValue(Object language) {
    return 'Telefonla aynı ($language)';
  }

  @override
  String get languageRedrawLine =>
      'Kryfo yeni dilde yeniden çizilir ve sohbetlerinde açılır.';

  @override
  String languageButton(Object language) {
    return 'Dil: $language';
  }

  @override
  String get androidServiceTitle => 'Kryfo açık';

  @override
  String get androidServiceText =>
      'Mesajlar gelsin diye şifreli hattın açık kalıyor';

  @override
  String get androidChannelName => 'Bağlı kalma';

  @override
  String get androidChannelDescription =>
      'Kryfo kapalıyken şifreli mesajlar gelsin diye onu bağlı tutar. Bunu kapatmak teslimatı durdurur.';

  @override
  String get videoViewerPlay => 'Oynat';

  @override
  String get videoViewerPause => 'Duraklat';

  @override
  String get videoViewerPlayAgain => 'Tekrar oynat';

  @override
  String get videoViewerCannotPlay =>
      'Bu telefon bu videoyu burada oynatamıyor.';

  @override
  String get videoViewerOpenElsewhere => 'Başka uygulamada aç';

  @override
  String get photoKnowsLookedFor => 'Aranan';

  @override
  String get photoKnowsNotInIt => 'Yok';

  @override
  String get languageNameEn => 'İngilizce';

  @override
  String get languageNameDe => 'Almanca';

  @override
  String get languageNameFr => 'Fransızca';

  @override
  String get languageNameEs => 'İspanyolca';

  @override
  String get languageNamePt => 'Portekizce (Brezilya)';

  @override
  String get languageNameIt => 'İtalyanca';

  @override
  String get languageNameRu => 'Rusça';

  @override
  String get languageNameUk => 'Ukraynaca';

  @override
  String get languageNameTr => 'Türkçe';

  @override
  String get languageNameZh => 'Çince (Basitleştirilmiş)';

  @override
  String get languageNameZhHant => 'Çince (Geleneksel)';

  @override
  String get languageNameVi => 'Vietnamca';

  @override
  String get languageNameId => 'Endonezce';

  @override
  String get languageNameFa => 'Farsça';

  @override
  String get languageNameAr => 'Arapça';

  @override
  String get languageLaterLine =>
      'Bunu istediğin zaman ayarlardan değiştirebilirsin.';

  @override
  String get pollAttach => 'Anket';

  @override
  String get pollNewTitle => 'Yeni anket';

  @override
  String get pollQuestionHint => 'Gruba bir şey sor';

  @override
  String get pollOptionsLabel => 'Seçenekler';

  @override
  String pollOptionHint(Object n) {
    return 'Seçenek $n';
  }

  @override
  String get pollAddOption => 'Seçenek ekle';

  @override
  String get pollMaxLine => 'En fazla on iki seçenek.';

  @override
  String get pollMultiple => 'Birden fazla yanıt';

  @override
  String get pollMultipleLine => 'Birden fazlası seçilebilir.';

  @override
  String get pollSend => 'Anketi gönder';

  @override
  String get pollKind => 'Anket';

  @override
  String get pollKindMulti => 'Anket · birden fazla yanıt';

  @override
  String get pollKindClosed => 'Sonuç';

  @override
  String pollVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count oy',
      one: '$count oy',
      zero: 'Henüz oy yok',
    );
    return '$_temp0';
  }

  @override
  String get pollVote => 'Oy ver';

  @override
  String get pollTakeBack => 'Oyumu geri al';

  @override
  String get pollClose => 'Anketi kapat';

  @override
  String get pollCloseTitle => 'Bu anket kapatılsın mı?';

  @override
  String get pollCloseLine =>
      'Herkes nihai sonucu görür ve bundan sonra kimse oy veremez.';

  @override
  String get pollCloseYes => 'Kapat';

  @override
  String pollPreview(Object question) {
    return 'Anket: $question';
  }

  @override
  String get pollWhoVoted => 'Kimler oy verdi';

  @override
  String get pollNobody => 'Henüz kimse yok';

  @override
  String get pollYou => 'Sen';

  @override
  String pollOptionA11y(Object option, Object share) {
    return '$option, $share';
  }

  @override
  String get pollPickOne => 'Birini seç';

  @override
  String get pollPickSeveral => 'Bir veya daha fazlasını seç';

  @override
  String get searchOpen => 'Ara';

  @override
  String get searchHint => 'Sohbetlerde ve mesajlarda ara';

  @override
  String get searchFilterAll => 'Tümü';

  @override
  String get searchFilterPhotos => 'Fotoğraflar';

  @override
  String get searchFilterVideos => 'Videolar';

  @override
  String get searchFilterFiles => 'Dosyalar';

  @override
  String get searchFilterLinks => 'Bağlantılar';

  @override
  String get searchChats => 'Sohbetler';

  @override
  String get searchMessages => 'Mesajlar';

  @override
  String get searchIntroTitle => 'Sohbetlerinde ara';

  @override
  String get searchIntroLine =>
      'İsimler, kelimeler, fotoğraflar, dosyalar ve bağlantılar. Arama bu telefonda yapılır ve hiçbir yere bir şey göndermez.';

  @override
  String get searchNothing => 'Hiçbir şey bulunamadı';

  @override
  String get searchNothingLine =>
      'Başka bir kelime ya da başka bir filtre dene.';

  @override
  String searchMatches(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count eşleşme',
      one: '$count eşleşme',
    );
    return '$_temp0';
  }

  @override
  String searchMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tane daha',
      one: '$count tane daha',
    );
    return '$_temp0';
  }

  @override
  String searchFilling(Object share) {
    return 'Eski mesajlar ekleniyor · $share';
  }

  @override
  String get searchClear => 'Temizle';

  @override
  String get handleShowInSearch => 'Beni aramada göster';

  @override
  String get handleShowInSearchLine =>
      'Herkes bu kullanıcı adını bulup sana yazabilir.';

  @override
  String handleShownAs(Object name) {
    return '$name olarak görünüyor';
  }

  @override
  String get handleNameInSearch => 'Aramadaki ad';

  @override
  String get handleNameInSearchLine =>
      'İsteğe bağlı. Biri arama yaptığında kullanıcı adının yanında görünür. Herkes bu kullanıcı adını bulup sana yazabilir.';

  @override
  String get handleNameHint => 'Adın ya da boş bırak';

  @override
  String get handleShowMe => 'Göster';

  @override
  String get handleSearchOff => 'Artık aramada değilsin';

  @override
  String handleSearchOn(Object handle) {
    return 'Aramada @$handle olarak görünüyorsun';
  }

  @override
  String get handleRegistryFailed =>
      'Kayıt defterine ulaşılamadı. Bir dakika sonra yeniden dene.';

  @override
  String get handleCheckClock =>
      'Telefonun tarih ve saatini kontrol et, sonra yeniden dene.';

  @override
  String get searchPeople => 'Kişiler';

  @override
  String searchPeopleAsk(Object query) {
    return 'Herkese açık kullanıcı adlarında “$query” ara';
  }

  @override
  String get searchPeopleLine =>
      'Tor üzerinden soruluyor. Kayıt defteri bunun kaydını tutmaz.';

  @override
  String get searchPeopleNone => 'Eşleşen herkese açık kullanıcı adı yok';

  @override
  String get searchPeopleOffline => 'Tor henüz hazır değil';

  @override
  String get searchPeopleBusy =>
      'Şu an çok fazla arama var. Birazdan yeniden dene.';

  @override
  String get searchPeopleUnreachable => 'Kayıt defterine ulaşılamadı';

  @override
  String get peopleVerified => 'Doğrulanmış kullanıcı adı';

  @override
  String get peopleAdd => 'Ekle';

  @override
  String peopleFingerprint(Object fp) {
    return 'Anahtar parmak izi · $fp';
  }

  @override
  String get peopleFingerprintLine =>
      'Karşı tarafın uygulamasında gördüğüyle aynı olduğunu kontrol et.';

  @override
  String get peopleAdding => 'Ekleniyor…';

  @override
  String handleNobodyHasClaimed(Object handle) {
    return '$handle adını kimse almamış';
  }

  @override
  String get handleThatHandleIsTaken => 'Bu kullanıcı adı zaten alınmış';

  @override
  String get pinPickDifferent => 'Başka bir PIN seç';

  @override
  String get settingsKeptOnWhileLock =>
      'Uygulama kilidi açık olduğu sürece açık kalır.';

  @override
  String get lockFingerAfterPin =>
      'Parmak izini yeniden kullanmak için PIN\'ini bir kez gir.';

  @override
  String get pinsAdvanced => 'Gelişmiş koruma';

  @override
  String get pinsAdvancedLine =>
      'Biri seni telefonunun kilidini açmaya zorladığında.';

  @override
  String get pinsWipeLine =>
      'Kilit ekranında girildiğinde Kryfo’yu bu telefondan siler.';

  @override
  String get pinsDecoyPin => 'Yem PIN’i';

  @override
  String get pinsDecoyLine => 'Yeni kurulmuş gibi boş bir Kryfo açar.';

  @override
  String get pinsSetADecoyPin => 'Yem PIN’i belirle';

  @override
  String get pinsChangeDecoyPin => 'Yem PIN’ini değiştir';

  @override
  String get pinsRemoveTheDecoyPin => 'Yem PIN’i kaldırılsın mı?';

  @override
  String get pinsTheDecoyGoes => 'Açtığı boş Kryfo da onunla birlikte gider.';

  @override
  String get pinsTurnOffWithDecoy =>
      'Bütün PIN’ler kaldırılır, yem, onun Kryfo’su ve varsa gizli sohbetler de onlarla birlikte. Telefonun kimin elindeyse Kryfo’yu senmiş gibi açar.';

  @override
  String get pinsHowThisWorks => 'Nasıl çalışır';

  @override
  String get flowEnterYourPin => 'PIN’ini gir';

  @override
  String get flowEnterYourPinLine => 'Kryfo’yu açan PIN.';

  @override
  String get flowWipeTitle => 'Bir silme PIN’i';

  @override
  String get flowWipe1 =>
      'Kilit ekranında PIN’inin yerine girildiğinde Kryfo’yu bu telefondan siler ve kapatır. İzleyen kişiye göre uygulama sadece durdu.';

  @override
  String get flowWipe2 =>
      'Her sohbeti ve kimliğini, varsa yemi de beraberinde götürür.';

  @override
  String get flowWipeChoose => 'Bir silme PIN’i seç';

  @override
  String get flowWipeDone => 'Silme PIN’i belirlendi';

  @override
  String get flowWipeDoneLine =>
      'Kilit ekranında varlığını belli eden hiçbir şey yok.';

  @override
  String get flowDecoyTitle => 'Bir yem PIN’i';

  @override
  String get flowDecoy1 => 'Yeni kurulmuş gibi boş bir Kryfo açar.';

  @override
  String get flowDecoyFinger =>
      'Parmak izin gerçek Kryfo’nu açar. Biri seni onu kullanmaya zorlayabilecekse parmak izini kapat.';

  @override
  String get flowDecoyDigits =>
      'PIN’indeki kadar rakam kullan, çünkü izleyen biri noktaları sayabilir.';

  @override
  String get flowDecoyShade =>
      'Bildirim panelinde zaten olan bildirimler zaten görüldü. Yem açıkken yeni bildirim gelmez.';

  @override
  String get flowDecoyChoose => 'Bir yem PIN’i seç';

  @override
  String get flowDecoyDone => 'Yem PIN’i belirlendi';

  @override
  String get flowDecoyDoneLine =>
      'Boş Kryfo’yu açmak için kilit ekranında gir. Çıkmak için başka bir uygulamaya geç ve PIN’ini gir.';

  @override
  String get flowLaw =>
      'Bazı ülkelerde bir telefonun kilidini açmayı reddetmek ya da verileri yetkililerden gizlemek başlı başına suçtur. Seyahat ettiğin yerlerin yasalarını bil.';

  @override
  String get howWipe =>
      'Kilit ekranında girildiğinde silme PIN’i her sohbeti, kimliğini ve varsa yemi siler, sonra Kryfo’yu kapatır. Yanlış denemelerden sonra tuş takımı beklemedeyken bile çalışır.';

  @override
  String get howDecoy =>
      'Yem PIN’i, kendi üç kelimesi olan ikinci ve boş bir Kryfo açar. Gerçek Kryfo’na gelen mesajlar altta sessizce gelmeye devam eder. Yemden çıkmak için başka bir uygulamaya geç ve PIN’ini gir.';

  @override
  String get flowNotSet => 'Belirlenemedi. Tekrar dene.';

  @override
  String get pinsHiddenChats => 'Gizli sohbetler';

  @override
  String get pinsHiddenLine =>
      'Seçtiğin sohbetler, gizli sohbet PIN’ini girene kadar gözden uzak kalır: listede yok, aramada yok, bildirim yok.';

  @override
  String get pinsSetUp => 'Kur';

  @override
  String get pinsChangeHiddenPin => 'Gizli sohbet PIN’ini değiştir';

  @override
  String get pinsHideMoreChats => 'Daha fazla sohbet gizle';

  @override
  String get pinsRemoveHiddenChats => 'Gizli sohbetleri kaldır';

  @override
  String get pinsRemoveHiddenTitle => 'Gizli sohbetler kaldırılsın mı?';

  @override
  String get pinsRemoveHiddenLine =>
      'Sohbet listene geri dönerler ve gizli sohbet PIN’i artık hiçbir şey açmaz.';

  @override
  String get pinsTurnOffHiddenFirst =>
      'Gizli sohbetler uygulama kilidine ihtiyaç duyar. Önce onları kaldır, sohbet listene geri dönerler.';

  @override
  String get flowVaultTitle => 'Gizli sohbetler';

  @override
  String get flowVault1 =>
      'Gizlenecek sohbetleri ve grupları seç. PIN’in Kryfo’yu onlar olmadan açar. Gizli sohbet PIN’i ise gizli sohbetler dahil her şeyi açar.';

  @override
  String get flowVault2 =>
      'Gözden uzakken asla bildirim göndermez, sayaç da göstermezler. Mesajları gelmeye devam eder ve mühürlü olarak gizli sohbet PIN’ini bekler.';

  @override
  String get flowVaultFinger =>
      'Parmak izin Kryfo’yu gizli sohbetler olmadan açar.';

  @override
  String get flowVaultDigits =>
      'PIN’ine de altı ya da daha fazla rakam ver, çünkü izleyen biri noktaları sayabilir.';

  @override
  String get flowVaultReplace =>
      'Bu işlem, bu telefonda zaten olan tüm gizli sohbetlerin yerini alır.';

  @override
  String get flowVaultChoose => 'Bir gizli sohbet PIN’i seç';

  @override
  String get flowVaultChooseLine => 'Altı rakam ya da daha fazlası.';

  @override
  String get flowEnterHiddenPinLine => 'Gizli sohbetlerini açan PIN.';

  @override
  String get flowVaultForgetTitle => 'Bu PIN’i unutma';

  @override
  String get flowVaultForget =>
      'Bu PIN’i unutursan gizli sohbetlerin sonsuza dek gider. Kimse onları geri getiremez, biz bile.';

  @override
  String get flowVaultForgetOk => 'Anladım';

  @override
  String get flowVaultPickTitle => 'Gizlenecek sohbetleri seç';

  @override
  String get flowVaultPickLine =>
      'Şimdi sohbet listenden çıkarlar. Gizli sohbet PIN’in onları yeniden gösterir.';

  @override
  String flowVaultPickButton(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString sohbeti gizle',
      one: '$countString sohbeti gizle',
      zero: 'Şimdilik hiçbir şey gizleme',
    );
    return '$_temp0';
  }

  @override
  String get flowVaultPickEmpty => 'Henüz gizlenecek sohbet yok.';

  @override
  String get flowVaultBackupTitle => 'Şimdi yedek alınsın mı?';

  @override
  String get flowVaultBackupLine =>
      'Şimdi alınan bir yedek, kendi parola ifadesiyle gizli sohbetlerini de içerir. Gizli sohbet PIN’ini unutursan onlara dönmenin tek yolu budur.';

  @override
  String get flowVaultBackupNow => 'Yedek al';

  @override
  String get flowVaultNotNow => 'Şimdi değil';

  @override
  String get flowVaultDone => 'Gizli sohbetler kuruldu';

  @override
  String get flowVaultDoneLine =>
      'Görmek için gizli sohbet PIN’ini kilit ekranında gir. Başka bir uygulamaya geçince yine gözden uzak olurlar.';

  @override
  String get flowVaultChanged => 'Gizli sohbet PIN’i değişti';

  @override
  String get flowVaultChangedLine =>
      'Gizli sohbetlerin artık yenisiyle açılır. Eskisi artık hiçbir şey açmaz.';

  @override
  String get howVault =>
      'Gizli sohbet PIN’in Kryfo’yu gizli sohbetlerinle açar; PIN’in ve parmak izin ise onlar olmadan. Gizli sohbetleri yeniden kurmak, bu telefondakilerin yerini alır. Gizli sohbet PIN’ini unutursan sonsuza dek giderler.';

  @override
  String get chatHide => 'Sohbeti gizle';

  @override
  String get groupHide => 'Grubu gizle';

  @override
  String get chatHidden => 'Gizli';

  @override
  String get chatHiddenToast => 'Sohbet listenden gizlendi';

  @override
  String get chatShowInList => 'Sohbet listesinde göster';

  @override
  String get stickerOpen => 'Çıkartmalar';

  @override
  String get stickerRecent => 'Son kullanılanlar';

  @override
  String stickerA11y(String emoji) {
    return 'Çıkartma $emoji';
  }

  @override
  String get stickerRemoveRecent => 'Son kullanılanlardan kaldır';

  @override
  String get stickerCouldNotLoad => 'Çıkartmalar yüklenemedi';

  @override
  String get stickerLabel => 'Çıkartma';

  @override
  String get stickerNewer => 'Daha yeni bir Kryfo’dan';

  @override
  String get devLinkMismatch =>
      'Bu bağlantı Marios olduğunu söylüyor ama anahtarı eşleşmiyor. Eklenmedi.';

  @override
  String get devName => 'Marios';

  @override
  String get devRowTitle => 'Marios · Kryfo’yu yaptı';

  @override
  String get devWelcome =>
      'Merhaba, ben Marios, Kryfo’yu ben yapıyorum. Bana ne istersen yaz: hatalar, fikirler, sorular. Hepsini okurum.';

  @override
  String get devPinned => 'Kryfo’ya gömülü';

  @override
  String get devAnonymous => 'Anonim';

  @override
  String get devAboutLine =>
      'Marios’un anahtarı Kryfo’ya gömülü. Ondan gelen her mesaj bu anahtarla kontrol edilir, yani başka kimse onun adına yazamaz.';

  @override
  String get devKeyLabel => 'Onun anahtarı';

  @override
  String get devDeleteLine => 'Her mesaj gider ve sohbet geri gelmez.';

  @override
  String get devDeleteLineAnon =>
      'Her mesaj ve bu sohbet için oluşturulan ad gider, sohbet de geri gelmez.';

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
      one: '1 waiting',
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
      one: '1 new chat',
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
      one: '1 new message',
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
  String get settingsWriteToMarios => 'Marios’a yaz';

  @override
  String get settingsWriteToMariosHint => 'Hatalar, fikirler, sorular';

  @override
  String get seenDevChat => 'Marios sohbeti';

  @override
  String get seenDevChatCell => 'Yazarsan';

  @override
  String get seenDevChatLine =>
      'Sen yazana kadar hiçbir şey. Sonra gönderdiklerin ve anonim yazmadıkça üç kelimen.';

  @override
  String get devWriteAnonymously => 'Anonim yaz';

  @override
  String get devUseMyWords => 'Üç kelimemi kullan';

  @override
  String get devWhoSeesWhat => 'Nasıl çalışır';

  @override
  String get devWhoWords =>
      'Üç kelimenle bu, diğerleri gibi bir sohbet: Marios sana yanıt verebilir, yüzün ve destekçi rozetin sende kalır.';

  @override
  String get devWhoAnon =>
      'Anonim yazarsan Kryfo yalnızca bu sohbet için yeni bir ad ve anahtarlar oluşturur. Bunlar bu telefonda kalır ve başka hiçbir yerde kullanılmaz.';

  @override
  String get devWhoNothingYet =>
      'İlk mesajını gönderene kadar telefonundan hiçbir şey çıkmaz.';

  @override
  String get devWhoChoiceStays => 'Seçimin bu sohbette kalır.';

  @override
  String get devKeyCheckFailed =>
      'Marios’un anahtarı kontrol edilemedi. Hiçbir şey gönderilmedi.';

  @override
  String get devLockLine =>
      'Marios bunları okuyacak. O yanıt verince daha fazla yazabilirsin.';

  @override
  String get devNewKey => 'Marios’un yeni bir anahtarı var';

  @override
  String get devStartNewChat => 'Yeni bir sohbet başlat';

  @override
  String get devKeyRetired =>
      'Bu anahtar kullanımdan kaldırıldı. Burada artık hiçbir şey gönderilemez veya alınamaz.';

  @override
  String get devNamelessLine =>
      'Bu sohbet için oluşturulan ad, oluşturulduğu telefonda kalır; bu yüzden sohbet burada yalnızca okunabilir.';

  @override
  String get devStartNewLine =>
      'Buradaki her mesaj gider ve yeni bir sohbet açılır.';

  @override
  String get devVoiceDisguised => 'Bu sohbette sesin gizleniyor';

  @override
  String get devChatOptions => 'Sohbet seçenekleri';

  @override
  String appLinkOtherKey(Object id) {
    return 'Bu bağlantı $id olduğunu söylüyor ama anahtarı eşleşmiyor. Eklenmedi.';
  }

  @override
  String scamShieldSaysItIs(Object shown) {
    return '$shown olduğunu söylüyor ama anahtarı eşleşmiyor';
  }

  @override
  String get requestsSomeoneNew => 'Yeni biri';

  @override
  String get appYourOwnInvite =>
      'Bu senin kendi davetin. Bağlanmak için başka biriyle paylaş.';

  @override
  String appTheyAreBlocked(Object id) {
    return '$id engellendi. Yeniden eklemek için Ayarlar’daki “Engellenenler”den engelini kaldır.';
  }

  @override
  String get devLinkGone =>
      'Marios ile sohbeti sildin. Yenisini başlatmak için Ayarlar’da “Marios’a yaz”a dokun.';

  @override
  String lockTooManyTriesFor(Object left) {
    return 'Çok fazla deneme · $left';
  }
}
