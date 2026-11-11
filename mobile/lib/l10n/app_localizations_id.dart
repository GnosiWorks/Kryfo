// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get atmosphereNone => 'Tidak ada';

  @override
  String get atmosphereEmber => 'Bara';

  @override
  String get atmosphereDusk => 'Senja';

  @override
  String get atmosphereMoss => 'Lumut';

  @override
  String get atmosphereRose => 'Mawar';

  @override
  String get atmosphereDots => 'Titik';

  @override
  String get atmosphereGrid => 'Kisi';

  @override
  String get atmosphereWaves => 'Ombak';

  @override
  String get atmosphereRain => 'Hujan';

  @override
  String get atmosphereLateNight => 'Larut malam';

  @override
  String get atmosphereWarmAfternoon => 'Sore hangat';

  @override
  String get atmosphereSnow => 'Salju';

  @override
  String get atmosphereDesert => 'Gurun';

  @override
  String get atmospherePaper => 'Kertas';

  @override
  String get accentYellow => 'Kuning';

  @override
  String get accentGrey => 'Abu-abu';

  @override
  String get accentPurple => 'Ungu';

  @override
  String get accentLime => 'Limau';

  @override
  String get accentVelvet => 'Beludru';

  @override
  String get accentBlue => 'Biru';

  @override
  String get appearancePreview => 'Pratinjau obrolanmu dengan warna ini';

  @override
  String get appearanceSampleIn => 'Nanti malam jadi?';

  @override
  String get appearanceSampleOut => 'Jadi. Jam delapan, di tempat biasa.';

  @override
  String get appearanceSampleButton => 'Balas';

  @override
  String get appearanceAccentHint =>
      'Tombol, pesanmu sendiri, dan tautan memakai warna ini. Ikon aplikasi tetap kuning.';

  @override
  String get appearanceChatWallpaper => 'Latar belakang obrolan';

  @override
  String get appearanceEveryChat => 'Semua obrolan';

  @override
  String get appearanceWallpaperHint =>
      'Latar belakang milik obrolan sendiri, dipilih dari menunya, didahulukan. Foto tetap di ponsel ini, terenkripsi bersama obrolanmu.';

  @override
  String get appearanceWallpaperHintDesk =>
      'Latar belakang milik obrolan sendiri, dipilih dari menunya, didahulukan. Foto tetap di komputer ini, terenkripsi bersama obrolanmu.';

  @override
  String get backupThatPassphraseDoesNot =>
      'Frasa sandi itu tidak bisa membuka file ini';

  @override
  String get backupThatFileIsNot => 'File itu bukan cadangan Kryfo';

  @override
  String get backupThisBackupIsFrom =>
      'Cadangan ini dari Kryfo versi lebih baru. Perbarui aplikasinya, lalu coba lagi';

  @override
  String get backupThisFileIsDamaged => 'File ini rusak dan tidak bisa dibaca';

  @override
  String get backupTheRestoreStoppedPartway =>
      'Pemulihan berhenti di tengah jalan';

  @override
  String get backupCouldNotMakeThe => 'Gagal membuat kunci';

  @override
  String get contactCardMessageMeOn => 'Kirimi aku pesan di';

  @override
  String get contactCardScanToAdd =>
      'Pindai dengan Kryfo untuk menambahkanku.\nKartu ini tidak tahu apa pun tentangmu selain itu.';

  @override
  String contactCardMessageMeOnKryfo(Object haloId) {
    return 'Kirimi aku pesan di Kryfo · $haloId';
  }

  @override
  String get contactStatusBlocked => 'Diblokir';

  @override
  String get contactStatusKeysVerifiedInPerson =>
      'Kunci diverifikasi tatap muka';

  @override
  String get contactStatusWaitingInRequests => 'Menunggu di permintaan';

  @override
  String get deliveryModeAlwaysOn => 'Selalu aktif';

  @override
  String get deliveryModeCheckIns => 'Cek berkala';

  @override
  String get deliveryModeThroughAHelperApp => 'Lewat aplikasi pembantu';

  @override
  String get deliveryModeNotYet => 'belum';

  @override
  String get deliveryModeJustNow => 'baru saja';

  @override
  String deliveryModeMinAgo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString mnt lalu',
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
      other: '$countString jam lalu',
    );
    return '$_temp0';
  }

  @override
  String get deliveryModeYesterday => 'kemarin';

  @override
  String deliveryModeDaysAgo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString hari lalu',
    );
    return '$_temp0';
  }

  @override
  String get deliveryModeConnected => 'Terhubung';

  @override
  String get deliveryModeConnecting => 'Menghubungkan';

  @override
  String get deliveryModeNotConnected => 'Tidak terhubung';

  @override
  String get deliveryModeCheckingNow => 'Sedang mengecek';

  @override
  String deliveryModeLastCheckIn(Object agoLine) {
    return 'pengecekan terakhir $agoLine';
  }

  @override
  String get deliveryModeNoCheckInYet => 'belum ada pengecekan';

  @override
  String deliveryModeConnectedNow(Object last) {
    return 'Terhubung sekarang · $last';
  }

  @override
  String deliveryModeConnecting2(Object last) {
    return 'Menghubungkan · $last';
  }

  @override
  String get deliveryModeNoCheckInYet2 => 'Belum ada pengecekan';

  @override
  String deliveryModeLastChecked(Object agoLine) {
    return 'Terakhir dicek $agoLine';
  }

  @override
  String get deliveryModeAHelperApp => 'aplikasi pembantu';

  @override
  String deliveryModeWokenByNoWake(Object who) {
    return 'Dibangunkan oleh $who · belum pernah';
  }

  @override
  String deliveryModeWokenByLastWake(Object who, Object agoLine) {
    return 'Dibangunkan oleh $who · terakhir $agoLine';
  }

  @override
  String get introBudgetTomorrow => 'besok';

  @override
  String introBudgetInDays(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString hari lagi',
    );
    return '$_temp0';
  }

  @override
  String get introBudgetInAnHour => 'sejam lagi';

  @override
  String introBudgetInHours(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString jam lagi',
    );
    return '$_temp0';
  }

  @override
  String get introBudgetInAFewMinutes => 'beberapa menit lagi';

  @override
  String get lockStateUnlockKryfo => 'Buka kunci Kryfo';

  @override
  String get appInvalidUri => 'Uri tidak valid';

  @override
  String appBundleError(Object e) {
    return 'Kesalahan bundel: $e';
  }

  @override
  String appAlreadySaved(Object parsed) {
    return 'Sudah tersimpan: $parsed';
  }

  @override
  String appLongWindow(Object line) {
    return '$line rentang panjang';
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
      other: '$pString halaman',
    );
    String _temp1 = intl.Intl.pluralLogic(
      e,
      locale: localeName,
      other: '$eString event',
    );
    return '$line ($heldString dari $subsString, sambung $c dtk, $_temp0, $_temp1)';
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
      other: '$pString halaman',
    );
    String _temp1 = intl.Intl.pluralLogic(
      e,
      locale: localeName,
      other: '$eString event',
    );
    return '$line (sambung $c dtk, $_temp0, $_temp1)';
  }

  @override
  String appSDropped(Object host, Object secs) {
    return '$host $secs dtk terputus';
  }

  @override
  String appS(Object host, Object secs) {
    return '$host $secs dtk';
  }

  @override
  String get appTorWouldNotWake => 'Tor tidak mau bangun';

  @override
  String get appCheckStarted => 'Dimulai';

  @override
  String get appTorNotReadyIn => 'Tor belum siap dalam 75 dtk';

  @override
  String get appOk => 'OK';

  @override
  String get appOkNoRelayBegan => 'OK, tak ada relay mulai';

  @override
  String get appNoRelayReached => 'Tak ada relay terjangkau';

  @override
  String get appOkCapped => 'OK, dibatasi';

  @override
  String appSBy(Object how, int secs, String why) {
    final intl.NumberFormat secsNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String secsString = secsNumberFormat.format(secs);

    String _temp0 = intl.Intl.selectLogic(why, {
      'push': '$how, $secsString dtk, lewat push',
      'other': '$how, $secsString dtk, lewat tugas latar',
    });
    return '$_temp0';
  }

  @override
  String get appAnAttachmentCouldNot =>
      'Ada lampiran yang tidak bisa disimpan di ponsel ini';

  @override
  String get appAnAttachmentCouldNotDesk =>
      'Ada lampiran yang tidak bisa disimpan di komputer ini';

  @override
  String get appGroup2 => 'Grup';

  @override
  String get appVoiceMessage => 'Pesan suara';

  @override
  String get appPhoto => 'Foto';

  @override
  String get appNewRequest => 'Permintaan baru';

  @override
  String get appSomeoneYouHaveNot =>
      'Seseorang yang belum kamu tambahkan mengirimimu pesan';

  @override
  String get appSettingUpYourKeys => 'Menyiapkan kuncimu';

  @override
  String get appOpeningYourChats => 'Membuka obrolanmu';

  @override
  String get appStartingTor => 'Memulai Tor';

  @override
  String get appTimedMessagesAreNot =>
      'Pesan berwaktu tidak menghilang. Mulai ulang Kryfo';

  @override
  String get appVoiceMessage2 => 'Pesan suara';

  @override
  String appYou(Object body) {
    return 'Kamu: $body';
  }

  @override
  String get appThisRoomHasAlready => 'Ruang ini sudah kedaluwarsa';

  @override
  String get appYouAreAlreadyIn => 'Kamu sudah ada di ruang ini';

  @override
  String get appCouldNotMakeA => 'Gagal membuat kunci ruang';

  @override
  String appJoined(Object linkName) {
    return 'Bergabung ke $linkName';
  }

  @override
  String get roomJoinWaitingToJoin => 'Menunggu bergabung';

  @override
  String get roomJoinNotAnswering => 'Tidak menjawab';

  @override
  String roomJoinWaitingFor(Object room) {
    return 'Menunggu $room mengizinkanmu masuk…';
  }

  @override
  String get roomJoinWaitingLine => 'Kamu bisa menulis di sini setelah masuk.';

  @override
  String get roomJoinNoAnswer => 'Ruang ini tidak menjawab.';

  @override
  String get roomJoinMayHaveEnded => 'Mungkin sudah berakhir.';

  @override
  String get roomJoinFullShort => 'Ruang penuh';

  @override
  String get roomJoinFull => 'Ruang ini penuh.';

  @override
  String get roomJoinFullLine =>
      'Belum ada tempat kosong. Coba lagi nanti, atau tanya orang yang membagikan tautannya.';

  @override
  String get appBooting => 'Memulai...';

  @override
  String get appSettingUpYourIdentity => 'Menyiapkan identitasmu...';

  @override
  String get appAddSomeone => 'Tambah orang';

  @override
  String get appScanTheirCodeOr =>
      'Pindai kodenya, atau tempel yang dia berikan: tautan, @nama pengguna, atau tautan ruang.';

  @override
  String get appScanTheirCodeOrDesk =>
      'Tempel yang dia berikan: tautan, @nama pengguna, atau tautan ruang.';

  @override
  String get appScanTheirCode => 'Pindai kodenya';

  @override
  String get appAKryfoLinkA => 'Tautan Kryfo, tautan ruang, atau @name';

  @override
  String get appAddThem => 'Tambahkan';

  @override
  String get appEveryWayToAdd => 'Semua cara menambah orang';

  @override
  String get appShowYourCodeSend =>
      'Tunjukkan kodemu, kirim tautan, klaim nama pengguna';

  @override
  String get appHelloFromTheOther => 'Halo dari seberang';

  @override
  String get appIdentityRestored => 'Identitas dipulihkan';

  @override
  String get appIdentityCreated => 'Identitas dibuat';

  @override
  String get appStartingTor30s => 'Memulai Tor (~30 dtk)...';

  @override
  String get appScanOrImportA => 'Pindai atau impor rekan dulu';

  @override
  String get appEncryptingSending30s => 'Mengenkripsi + mengirim (~30 dtk)...';

  @override
  String get appTapStartListeningFirst => 'Ketuk mulai mendengarkan dulu';

  @override
  String get appYourKryfo => 'Kryfo-mu';

  @override
  String get appUriCopied => 'Uri disalin';

  @override
  String get appCopyUri => 'Salin uri';

  @override
  String get appAddAKryfo => 'Tambah Kryfo';

  @override
  String get appScanQr => 'Pindai QR';

  @override
  String get appPairingCode => 'Kode penautan';

  @override
  String get appOrPaste => '- Atau tempel -';

  @override
  String get commonCancel => 'Batal';

  @override
  String get appImport => 'Impor';

  @override
  String get appDev => 'Pengembang';

  @override
  String get appYourKryfo2 => 'Kryfo-mu:';

  @override
  String get appRestoredFromDisk => 'Dipulihkan dari disk';

  @override
  String get appStartListening => 'Mulai mendengarkan';

  @override
  String get appListening => 'Mendengarkan';

  @override
  String get appShowMyQr => 'Tampilkan QR-ku';

  @override
  String get appImportPeer => 'Impor rekan';

  @override
  String get appPeer => 'Rekan:';

  @override
  String get appMessageWillBeEncrypted => 'Pesan (akan dienkripsi)';

  @override
  String get appEncryptSend => 'Enkripsi + kirim';

  @override
  String appStatus(Object status) {
    return 'Status: $status';
  }

  @override
  String get appSpeedPrivacy => 'Kecepatan & privasi →';

  @override
  String get appDisableAppLock => 'Matikan kunci aplikasi?';

  @override
  String get appThePinWillBe =>
      'PIN akan dihapus. Siapa pun yang memegang ponselmu akan melihat Kryfo saat membukanya.';

  @override
  String get appDisable => 'Matikan';

  @override
  String get appAppLockOn => 'Kunci aplikasi · aktif →';

  @override
  String get appAppLockOff => 'Kunci aplikasi · mati →';

  @override
  String get appTorIsOff => 'Tor mati';

  @override
  String get appConnectedRoutedThrough3 => 'Terhubung · lewat 3 relay';

  @override
  String get appReadyToChatAddressFinishing =>
      'Siap mengobrol · alamat sedang disiapkan';

  @override
  String get appTor => 'Tor';

  @override
  String get appTorIsOffTurn =>
      'Tor mati. Nyalakan untuk terhubung secara privat.';

  @override
  String get appTheFirstConnectionTakes =>
      'Koneksi pertama butuh satu atau dua menit selagi Tor membangun rute privat. Setelah itu tersimpan di cache, jadi membuka Kryfo berikutnya jauh lebih cepat.';

  @override
  String get appTorNoRelayYet =>
      'Tor sudah aktif, tapi belum ada relay yang menjawab. Kryfo terus mencoba, dan pesan menunggu di sini sampai ada yang menjawab.';

  @override
  String get appRelayAndFastModes =>
      'Cepat melewati Tor dan lebih gesit. Ada di pengaturan, di bawah kecepatan & privasi, dan menjelaskan apa harganya.';

  @override
  String get appOffline => 'Offline';

  @override
  String get appTorOff => 'Tor mati';

  @override
  String get appTorReady => 'Tor siap';

  @override
  String get appConnecting2 => 'Menghubungkan';

  @override
  String get appWaitingForARelay => 'Menunggu relay';

  @override
  String appStartingTorPct(Object pct) {
    return 'Memulai Tor · $pct';
  }

  @override
  String get appGettingNewMessages => 'Mengambil pesan baru';

  @override
  String mediaProgressSendingKeepTheApp(Object v) {
    return 'Mengirim · $v · biarkan aplikasi terbuka';
  }

  @override
  String mediaProgressPausedOfWaitingFor(Object count, Object count2) {
    return 'Dijeda · $count dari $count2 · menunggu sisanya';
  }

  @override
  String mediaProgressReceivingMedia(Object v) {
    return 'Menerima media · $v';
  }

  @override
  String get mediaProgressCancelSending => 'Batalkan pengiriman';

  @override
  String get metaReaderEndsBeforeItShould => 'berakhir terlalu awal';

  @override
  String get metaReaderCouldNotBeRead => 'tidak bisa dibaca';

  @override
  String get metaReaderExifThatCannotBe => 'exif yang tak bisa dibaca';

  @override
  String get metaReaderSamsungTrailer => 'trailer samsung';

  @override
  String metaReaderChunk(Object type) {
    return 'bagian $type';
  }

  @override
  String get metaReaderExifFlagSet => 'penanda exif aktif';

  @override
  String get metaReaderXmpFlagSet => 'penanda xmp aktif';

  @override
  String metaReaderAppBlock(Object id) {
    return 'blok app $id';
  }

  @override
  String get metaReaderUuidBox => 'kotak uuid';

  @override
  String metaReaderBox(Object printable) {
    return 'kotak $printable';
  }

  @override
  String get metaReaderAttachedData => 'data terlampir';

  @override
  String metaReaderItem(Object printable) {
    return 'item $printable';
  }

  @override
  String get miuiAutostartAlreadyAllowedToRun =>
      'Sudah diizinkan berjalan di latar belakang';

  @override
  String get miuiAutostartLetKryfoRunIn =>
      'Izinkan Kryfo berjalan di latar belakang';

  @override
  String get miuiAutostartYourPhonePausesApps =>
      'Ponselmu menjeda aplikasi untuk menghemat baterai. Tanpa pengecualian, Kryfo tidak bisa menerima pesan saat ditutup.';

  @override
  String get commonAllow => 'Izinkan';

  @override
  String get commonSkip => 'Lewati';

  @override
  String get miuiAutostartOpenSettings => 'Buka pengaturan';

  @override
  String get miuiAutostartCouldnTOpenIt =>
      'Tidak bisa dibuka. Cari mulai otomatis di pengaturan ponsel';

  @override
  String get batteryGuideHuawei =>
      'Huawei dan Honor menutup aplikasi yang mereka kelola sendiri. Di layar berikutnya, cari Kryfo, matikan Kelola otomatis, lalu biarkan Luncurkan otomatis, Peluncuran sekunder, dan Jalankan di latar belakang tetap menyala.';

  @override
  String get batteryGuideOppo =>
      'Oppo dan Realme menghentikan aplikasi di latar belakang. Di layar berikutnya, cari Kryfo dan izinkan Luncurkan otomatis. Di Baterai, izinkan juga aktivitas latar belakangnya.';

  @override
  String get batteryGuideVivo =>
      'Vivo menghentikan aplikasi di latar belakang. Di layar berikutnya, cari Kryfo dan izinkan ia mulai di latar belakang. Di Baterai, izinkan juga penggunaan daya tinggi di latar belakang.';

  @override
  String get batteryGuideSamsung =>
      'Samsung menidurkan aplikasi yang dianggapnya tidak dipakai. Di layar berikutnya, buka Batas penggunaan latar belakang lalu tambahkan Kryfo ke Aplikasi yang tidak pernah tidur.';

  @override
  String get batteryGuideOnePlus =>
      'OnePlus menghentikan aplikasi di latar belakang. Di layar berikutnya, cari Kryfo dan izinkan Luncurkan otomatis. Di Baterai, atur ke Jangan optimalkan.';

  @override
  String get batteryGuideXiaomiTitle => 'Biarkan Kryfo tetap berjalan';

  @override
  String get batteryGuideXiaomi =>
      'Xiaomi menghentikan aplikasi di latar belakang, bahkan saat mulai otomatis menyala. Agar pesan tetap masuk:';

  @override
  String get batteryGuideXiaomiStep1 => 'Mulai otomatis: nyalakan untuk Kryfo.';

  @override
  String get batteryGuideXiaomiStep2 =>
      'Penghemat baterai: atur Kryfo ke Tidak ada batasan.';

  @override
  String get batteryGuideXiaomiStep3 =>
      'Aplikasi terbaru: tekan lama Kryfo lalu ketuk gemboknya, supaya Hapus semua dan pembersihan ponsel tetap membiarkannya berjalan.';

  @override
  String get batteryGuideXiaomiAfter =>
      'Kalau ponselmu tetap menghentikan Kryfo, tidak ada yang masuk sampai kamu membukanya lagi.';

  @override
  String get notificationsNewEncryptedMessagesFrom =>
      'Pesan terenkripsi baru dari kontakmu';

  @override
  String get notificationsNewMessage => 'Pesan baru';

  @override
  String get notificationsNewEncryptedMessagesFromYourContacts =>
      'Pesan terenkripsi baru dari kontakmu';

  @override
  String get notificationsNewMessage2 => 'Pesan baru';

  @override
  String get notificationsSomeone => 'Seseorang';

  @override
  String get notificationsEncrypted => 'Terenkripsi';

  @override
  String get rooms24h => '24 j';

  @override
  String roomsD(Object inDays) {
    return '$inDays hr';
  }

  @override
  String roomsH(Object inHours) {
    return '$inHours j';
  }

  @override
  String get rooms24Hours => '24 jam';

  @override
  String roomsDays(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString hari',
    );
    return '$_temp0';
  }

  @override
  String get roomsAnHour => 'satu jam';

  @override
  String get roomsAboutAnHour => 'sekitar satu jam';

  @override
  String roomsHours(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString jam',
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
      other: 'sekitar $countString jam',
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
      other: '$countString menit',
    );
    return '$_temp0';
  }

  @override
  String get roomsAMinute => 'satu menit';

  @override
  String get roomsExpired => 'Kedaluwarsa';

  @override
  String roomsDH(Object inDays, Object h) {
    return '$inDays hr $h j';
  }

  @override
  String roomsHM(Object inHours, Object m) {
    return '$inHours j $m mnt';
  }

  @override
  String roomsM(Object inMinutes) {
    return '$inMinutes mnt';
  }

  @override
  String scamShieldGivesUsedName(Object shown) {
    return 'Mengaku sebagai $shown, nama yang sudah dipakai orang lain di sini';
  }

  @override
  String scamShieldWarning(Object noticed) {
    return '$noticed. Jangan kirim uang atau kode ke orang yang belum pernah kamu temui.';
  }

  @override
  String get scamShieldAsksForSecret =>
      'Meminta kode, PIN, atau kata pemulihan';

  @override
  String get scamShieldAsksForMoneyFast => 'Meminta uang sambil mendesak';

  @override
  String get scamShieldPromisesProfit => 'Menjanjikan untung mudah';

  @override
  String get scamShieldClaimsSupport => 'Mengaku dari Kryfo atau tim dukungan';

  @override
  String get scamShieldDismiss => 'Sembunyikan';

  @override
  String scamShieldNameMatchesYourContact(Object shown) {
    return 'Namanya sama dengan kontakmu $shown';
  }

  @override
  String get scamShieldLinksToALookalike =>
      'Menautkan ke tiruan situs terkenal';

  @override
  String get commonBack => 'Kembali';

  @override
  String get archivedArchived => 'Arsip';

  @override
  String get archivedCount0 => 'Nol';

  @override
  String get archivedCount1 => 'Satu';

  @override
  String get archivedCount2 => 'Dua';

  @override
  String get archivedCount3 => 'Tiga';

  @override
  String get archivedCount4 => 'Empat';

  @override
  String get archivedCount5 => 'Lima';

  @override
  String get archivedCount6 => 'Enam';

  @override
  String get archivedCount7 => 'Tujuh';

  @override
  String get archivedCount8 => 'Delapan';

  @override
  String get archivedCount9 => 'Sembilan';

  @override
  String get archivedCount10 => 'Sepuluh';

  @override
  String get archivedChatRestingHereIt =>
      'Obrolan beristirahat di sini. Tetap senyap sampai ada yang menulis, lalu naik lagi ke atas.';

  @override
  String get archivedChatsRestingHere =>
      'Obrolan beristirahat di sini. Tetap senyap sampai ada yang menulis, lalu naik lagi ke atas.';

  @override
  String get archivedNothingArchived => 'Tidak ada arsip';

  @override
  String get archivedArchivedChatsAreStill =>
      'Obrolan yang diarsipkan tetap terenkripsi ujung ke ujung';

  @override
  String get archivedUnarchive => 'Batalkan arsip';

  @override
  String get avatarPickerThePeopleYouMessage =>
      'Orang yang kamu kirimi pesan juga melihat ini';

  @override
  String get avatarPickerBackToYourInitial => 'Kembali ke inisialmu';

  @override
  String get avatarPickerThatOneIsYours => 'Itu milikmu';

  @override
  String get avatarPickerPickAFace => 'Pilih wajah';

  @override
  String get commonSave => 'Simpan';

  @override
  String get backupPassphraseMustBeAt => 'Frasa sandi minimal 12 karakter';

  @override
  String get backupPassphrasesDonTMatch => 'Frasa sandi tidak cocok';

  @override
  String get backupBackupSavedKeepThe =>
      'Cadangan tersimpan · simpan frasa sandinya dengan aman';

  @override
  String get backupKryfoBackup => 'Cadangan Kryfo';

  @override
  String get backupYourEncryptedKryfoBackup =>
      'Cadangan Kryfo-mu yang terenkripsi. Simpan file ini dan frasa sandimu dengan aman. Kamu butuh keduanya untuk memulihkan.';

  @override
  String get backupBackUpKryfo => 'Cadangkan Kryfo';

  @override
  String get backupBackUp => 'Cadangkan';

  @override
  String get backupACopyToKeep =>
      'Salinan untuk disimpan. Ponsel ini tetap berjalan seperti biasa.';

  @override
  String get backupACopyToKeepDesk =>
      'Salinan untuk disimpan. Komputer ini tetap berjalan seperti biasa.';

  @override
  String get backupMoveToAnotherDevice => 'Pindah ke perangkat lain';

  @override
  String get backupTheFileTakesThis =>
      'File ini membawa serta identitas ini. Begitu dibuat, ponsel ini berhenti: tidak ada yang baru masuk ke sini, dan tidak ada kiriman dari sini yang sampai ke siapa pun.';

  @override
  String get backupTheFileTakesThisDesk =>
      'File ini membawa serta identitas ini. Begitu dibuat, komputer ini berhenti: tidak ada yang baru masuk ke sini, dan tidak ada kiriman dari sini yang sampai ke siapa pun.';

  @override
  String get backupOneEncryptedFileYour =>
      'Satu file terenkripsi: identitasmu, kontakmu, setiap pesan, dan setiap foto, pesan suara, dan file. Impor di perangkat lain dengan frasa sandinya. Sampai saat itu, kamu masih bisa berubah pikiran dan tetap di ponsel ini.';

  @override
  String get backupOneEncryptedFileYourIdentityYour =>
      'Satu file terenkripsi: identitasmu, kontakmu, setiap pesan, dan setiap foto, pesan suara, dan file yang ada di ponsel ini sekarang. Apa pun yang dikirim setelah hari ini tidak ikut di dalamnya, jadi buat lagi saat perlu. Untuk memulihkan, kamu butuh file dan frasa sandinya, dua-duanya.';

  @override
  String get backupOneEncryptedFileYourIdentityYourDesk =>
      'Satu file terenkripsi: identitasmu, kontakmu, setiap pesan, dan setiap foto, pesan suara, dan file yang ada di komputer ini sekarang. Apa pun yang dikirim setelah hari ini tidak ikut di dalamnya, jadi buat lagi saat perlu. Untuk memulihkan, kamu butuh file dan frasa sandinya, dua-duanya.';

  @override
  String get backupPassphrase => 'Frasa sandi';

  @override
  String get backupConfirmPassphrase => 'Konfirmasi frasa sandi';

  @override
  String backupWriting(Object progress) {
    return 'Menulis… $progress';
  }

  @override
  String get backupSaveComesAfter =>
      'Setelah file siap, kamu akan memilih tempat menyimpannya.';

  @override
  String get backupSaving => 'Menyimpan…';

  @override
  String backupSavedIn(String place) {
    return 'Cadangan tersimpan di $place · simpan frasa sandinya dengan aman';
  }

  @override
  String get backupNotSaved => 'Cadangan tidak tersimpan. File-nya masih ada.';

  @override
  String get backupNotSavedNoSpace =>
      'Tempat yang kamu pilih tidak punya cukup ruang. File-nya masih ada, jadi pilih tempat lain atau kosongkan ruang.';

  @override
  String get backupShareInstead => 'Bagikan saja';

  @override
  String get backupSavedUnchecked =>
      'Cadangan tersimpan, tapi Kryfo tidak bisa memeriksa salinannya';

  @override
  String get backupHandedOver =>
      'Cadangan sudah diserahkan ke aplikasi yang kamu pilih · pastikan sudah sampai';

  @override
  String get backupMoveReachedTitle =>
      'Apakah file-nya sudah sampai di ponsel barumu?';

  @override
  String get backupMoveReachedTitleDesk =>
      'Apakah file-nya sudah sampai di perangkat barumu?';

  @override
  String get backupMoveReachedLine =>
      'Simpan ponsel ini sampai kamu sudah membukanya di sana.';

  @override
  String get backupMoveReachedLineDesk =>
      'Simpan komputer ini sampai kamu sudah membukanya di sana.';

  @override
  String get backupFinishTheMove => 'Selesaikan pindah';

  @override
  String get backupNotYet => 'Belum';

  @override
  String get backupCreating => 'Membuat…';

  @override
  String get backupMakeTheFileAnd => 'Buat file dan pindah';

  @override
  String get backupCreateBackup => 'Buat cadangan';

  @override
  String get backupNotMade => 'Cadangan tidak bisa dibuat. Coba lagi.';

  @override
  String get backupNoSpace =>
      'Ruang kosong di ponsel ini tidak cukup untuk membuat cadangan. Kosongkan sedikit ruang lalu coba lagi.';

  @override
  String get backupNoSpaceDesk =>
      'Ruang kosong di komputer ini tidak cukup untuk membuat cadangan. Kosongkan sedikit ruang lalu coba lagi.';

  @override
  String get backupHiddenNotIn => 'Obrolan tersembunyi tidak ada di dalamnya.';

  @override
  String get backupHiddenIncluded =>
      'Obrolan tersembunyimu juga ada di dalamnya.';

  @override
  String get backupMoveHiddenStay =>
      'Obrolan tersembunyi tetap di ponsel ini dan terhapus bersamanya.';

  @override
  String get backupMoveHiddenStayDesk =>
      'Obrolan tersembunyi tetap di komputer ini dan terhapus bersamanya.';

  @override
  String get backupHiddenGone =>
      'Obrolan tersembunyimu tertutup saat Kryfo terkunci. Buka dengan PIN obrolan tersembunyi, lalu buat cadangan dari sana.';

  @override
  String get blockedBlocked => 'Diblokir';

  @override
  String get blockedNoOneIsBlocked => 'Tidak ada yang diblokir';

  @override
  String get commonUnblock => 'Buka blokir';

  @override
  String get bridgesConnected => 'Terhubung';

  @override
  String get bridgesFromTheTorProject => 'Dari Tor Project';

  @override
  String get bridgesPasteFromClipboard => 'Tempel dari papan klip';

  @override
  String bridges1LineSaved(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString baris disimpan',
    );
    return '$_temp0';
  }

  @override
  String get bridgesWhenYouAskFor =>
      'Saat kamu meminta jembatan, Tor Project melihat alamat IP-mu. Itu wajar: begitulah Tor Browser dan semua aplikasi Tor mendapatkan jembatan, dan yang mereka ketahui hanyalah ada seseorang yang meminta jembatan. Tidak ada apa pun tentang obrolanmu.';

  @override
  String get cameraNoCameraOnThis => 'Tidak ada kamera di ponsel ini';

  @override
  String get cameraCameraNotAvailable => 'Kamera tidak tersedia';

  @override
  String get cameraCameraPermissionIsOff => 'Izin kamera mati';

  @override
  String get cameraOpenSettings => 'Buka pengaturan';

  @override
  String get cameraCouldNotStripThat =>
      'Gagal membersihkan foto itu, jadi dibuang';

  @override
  String get cameraNoPhotoCameOut => 'Tidak ada foto yang jadi';

  @override
  String get cameraCouldNotStartRecording => 'Gagal mulai merekam';

  @override
  String get cameraTheRecordingWasLost => 'Rekamannya hilang';

  @override
  String get cameraACopyIsIn => 'Salinannya ada di galerimu';

  @override
  String get cameraCouldNotSaveA => 'Gagal menyimpan salinan di ponsel ini';

  @override
  String get cameraTooLongForA => 'Terlalu panjang untuk pesan · maks 50 MB';

  @override
  String get cameraNeverSavedToYour => 'Tidak pernah disimpan ke galerimu';

  @override
  String get cameraNoExifNeverSaved =>
      'Tanpa EXIF, tidak pernah disimpan ke galerimu';

  @override
  String get cameraRec => 'Rekam';

  @override
  String get cameraSwitchCamera => 'Ganti kamera';

  @override
  String get cameraStopRecording => 'Berhenti merekam';

  @override
  String get cameraStartRecording => 'Mulai merekam';

  @override
  String get cameraTakeAPhoto => 'Ambil foto';

  @override
  String get cameraKeepACopy => 'Simpan salinan';

  @override
  String get cameraUseThis => 'Pakai ini';

  @override
  String get chatYouAreOfflineThis =>
      'Kamu sedang offline · pesan ini terkirim sendiri saat kamu tersambung lagi';

  @override
  String get chatStillConnectingToTor =>
      'Masih menghubungkan ke Tor · nanti terkirim sendiri';

  @override
  String chatS(Object seconds) {
    return '$seconds dtk';
  }

  @override
  String chatM(Object seconds) {
    return '$seconds mnt';
  }

  @override
  String chatH(Object seconds) {
    return '$seconds j';
  }

  @override
  String chatD(Object seconds) {
    return '$seconds hr';
  }

  @override
  String get chat0s => '0 dtk';

  @override
  String chatHM(Object h, Object m) {
    return '$h j $m mnt';
  }

  @override
  String chatMS(Object m, Object s) {
    return '$m mnt $s dtk';
  }

  @override
  String chatS2(Object s) {
    return '$s dtk';
  }

  @override
  String get chatNewMessages => 'Pesan baru';

  @override
  String chatEarlierMessagesArrived(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString pesan sebelumnya masuk',
    );
    return '$_temp0';
  }

  @override
  String get chatUnsave => 'Batal simpan';

  @override
  String get chatForward => 'Teruskan';

  @override
  String get commonShare => 'Bagikan';

  @override
  String get commonCopied => 'Disalin';

  @override
  String get commonCopy => 'Salin';

  @override
  String get chatUnpin => 'Lepas sematan';

  @override
  String get chatPin => 'Sematkan';

  @override
  String get chatStopSending => 'Berhenti mengirim';

  @override
  String get chatUnsend => 'Tarik pesan';

  @override
  String get commonEdit => 'Ubah';

  @override
  String get chatYou => 'Kamu';

  @override
  String get chatUnsendMessage => 'Tarik pesan';

  @override
  String get chatItDisappearsWithNo =>
      'Pesan ini akan dihapus dari kedua ponsel, kecuali sudah disimpan. Ini tidak bisa dibatalkan.';

  @override
  String get chatItDisappearsWithNoDesk =>
      'Pesan ini akan dihapus dari kedua perangkat, kecuali sudah disimpan. Ini tidak bisa dibatalkan.';

  @override
  String chatThisChatHasPins(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Obrolan ini sudah punya $countString sematan',
    );
    return '$_temp0';
  }

  @override
  String get chatUnpinThisMessage => 'Lepas sematan pesan ini?';

  @override
  String get chatPinThisMessage => 'Sematkan pesan ini?';

  @override
  String get chatItLeavesThePinned =>
      'Pesan ini keluar dari daftar sematan untuk kalian berdua.';

  @override
  String get chatItGoesUnderThe =>
      'Pesan ini masuk ke sematan di atas obrolan, untuk kalian berdua.';

  @override
  String get chatPinIt => 'Sematkan';

  @override
  String get chatNotNow => 'Nanti saja';

  @override
  String get chatEditMessage => 'Ubah pesan';

  @override
  String get chat30Seconds => '30 detik';

  @override
  String get chat1Minute => '1 menit';

  @override
  String get chat5Minutes => '5 menit';

  @override
  String get chat1Hour => '1 jam';

  @override
  String get chat24Hours => '24 jam';

  @override
  String get chatGhostTimer => 'Pesan berwaktu';

  @override
  String get chatHowLongAfterReading =>
      'Berapa lama setelah dibaca pesan hilang? Pesanmu dihitung sejak kamu mengirimnya.';

  @override
  String get chatCamera => 'Kamera';

  @override
  String get chatNoExifNeverSaved =>
      'Tanpa exif, tidak pernah disimpan ke galerimu';

  @override
  String get chatGallery => 'Galeri';

  @override
  String get chatVideo => 'Video';

  @override
  String get chatGifFromPhone => 'Gif dari ponsel';

  @override
  String get chatGifFromPhoneDesk => 'Gif dari komputer';

  @override
  String get chatFile2 => 'File';

  @override
  String get chatAFewSeconds => 'Beberapa detik';

  @override
  String get chatUnderAMinute => 'Kurang dari semenit';

  @override
  String chatRoughlyMin(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sekitar $countString menit',
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
  String get chatSendThis => 'Kirim file ini?';

  @override
  String chatOverTor(Object humanBytes, Object wireEstimate) {
    return '$humanBytes · $wireEstimate lewat Tor';
  }

  @override
  String get chatBigFilesGoOut =>
      'File besar dikirim dalam potongan kecil terenkripsi, jadi butuh waktu. Biarkan aplikasi terbuka dan pengiriman terus berjalan.';

  @override
  String get chatSendIt => 'Kirim';

  @override
  String get chatCouldNotReadThat => 'Gagal membaca file itu';

  @override
  String get chatCouldNotCleanThat => 'Gagal membersihkan video itu';

  @override
  String get chatGifTooBig8 => 'Gif terlalu besar · maks 8 mb';

  @override
  String get chatCouldNotCleanThatGif => 'Gagal membersihkan gif itu';

  @override
  String get chatTorIsNotUp => 'Tor belum terhubung · tanpa pratinjau tautan';

  @override
  String get chatCouldnTReachIt =>
      'Halamannya tak terjangkau · tanpa pratinjau tautan';

  @override
  String get chatNoTitleCameBack =>
      'Halaman itu tidak punya judul · tanpa pratinjau tautan';

  @override
  String get chatCouldnTFetchIt => 'Gagal memuat pratinjau';

  @override
  String get chatNoSignalSessionRe => 'Tidak ada sesi Signal. Tautkan ulang';

  @override
  String get chatMessageUnavailable => 'Pesan tidak tersedia';

  @override
  String get chatYou2 => 'Kamu';

  @override
  String get chatThem => 'Dia';

  @override
  String get chatVoiceMessage => 'Pesan suara';

  @override
  String get chatQuotedPhoto => 'Foto';

  @override
  String get chatViewContact => 'Lihat kontak';

  @override
  String get chatUnmuteNotifications => 'Bunyikan notifikasi';

  @override
  String get chatMuteNotifications => 'Bisukan notifikasi';

  @override
  String get chatArchiveChat => 'Arsipkan obrolan';

  @override
  String get chatWallpaper => 'Latar belakang';

  @override
  String get chatClearConversation => 'Bersihkan obrolan';

  @override
  String get chatNoteOnThisContact => 'Catatan tentang kontak ini';

  @override
  String get chatPinToTop => 'Sematkan di atas';

  @override
  String get chatBlockContact => 'Blokir kontak';

  @override
  String get chatUnpinned => 'Sematan dilepas';

  @override
  String get chatPinnedToTop => 'Disematkan di atas';

  @override
  String get chatJustForYouNever =>
      'Hanya untukmu. Tidak pernah dikirim, tidak pernah keluar dari ponsel ini.';

  @override
  String get chatJustForYouNeverDesk =>
      'Hanya untukmu. Tidak pernah dikirim, tidak pernah keluar dari komputer ini.';

  @override
  String get chatAQuietReminder => 'Pengingat kecil…';

  @override
  String get chatNoteSaved => 'Catatan disimpan';

  @override
  String get chatClearThisConversation => 'Bersihkan obrolan ini?';

  @override
  String get chatEveryMessageHereIs =>
      'Semua pesan di sini dihapus dari ponsel ini. Ini hanya membersihkan salinanmu. Tidak menyentuh perangkatnya.';

  @override
  String get chatEveryMessageHereIsDesk =>
      'Semua pesan di sini dihapus dari komputer ini. Ini hanya membersihkan salinanmu. Tidak menyentuh perangkatnya.';

  @override
  String get chatClear => 'Bersihkan';

  @override
  String get chatBlockThisContact => 'Blokir kontak ini?';

  @override
  String get chatTheirMessagesStopArriving =>
      'Pesannya berhenti masuk dan dia hilang dari obrolanmu. Dia tidak pernah diberi tahu. Kamu bisa membuka blokir kapan saja dari pengaturan.';

  @override
  String get commonBlock => 'Blokir';

  @override
  String get chatSaved => 'Tersimpan';

  @override
  String get chatRemovedFromSaved => 'Dihapus dari Tersimpan';

  @override
  String get chatForwardTo => 'Teruskan ke';

  @override
  String get chatNoContactsToForward => 'Tidak ada kontak untuk diteruskan';

  @override
  String get chatToday => 'Hari ini';

  @override
  String get chatYesterday => 'Kemarin';

  @override
  String get chatThisMessageCanT => 'Pesan ini tidak bisa ditampilkan';

  @override
  String get chatJumpToTheNewest => 'Ke pesan terbaru';

  @override
  String get chatBuildingAPrivateRoute =>
      'Membangun rute privat · koneksi pertama memang lambat, berikutnya cepat. Apa pun yang kamu kirim sekarang masuk antrean dan terkirim sendiri.';

  @override
  String get chatTheNextPhotoYou =>
      'Foto berikutnya yang kamu kirim dibuka dalam mode terlindung · Kryfo memblokir tangkapan layarnya';

  @override
  String get chatPhotoProtectionOff => 'Perlindungan foto mati';

  @override
  String get chatAcceptToReplyThey =>
      'Terima untuk membalas. Dia bisa mengirim satu pesan lagi sampai kamu menerimanya.';

  @override
  String chatIntroducedYouAcceptTo(Object introducer) {
    return '$introducer memperkenalkan kalian. Terima untuk membalas.';
  }

  @override
  String chatIntroducedYouSayHello(Object vouchNames) {
    return '$vouchNames memperkenalkan kalian. Sapa dia. Dia juga sudah menerima kartumu.';
  }

  @override
  String get chatIntroduceTo => 'Perkenalkan ke...';

  @override
  String get chatAcceptThemFirst => 'Terima dia dulu';

  @override
  String get chatMessageRequest => 'Permintaan pesan';

  @override
  String get chatTheyNeedToAccept =>
      'Dia perlu menerima dulu sebelum kalian bisa lanjut mengobrol.';

  @override
  String get chatWaitingForThemTo => 'Menunggu dia menerima permintaanmu';

  @override
  String get chatWaitsToSend => 'Menunggu dikirim';

  @override
  String get chatTheyMayNotKnow => 'Dia mungkin belum tahu kamu sudah menerima';

  @override
  String get chatYouBlockedThisContact => 'Kamu memblokir kontak ini';

  @override
  String get chatSupporter => 'Pendukung';

  @override
  String get chatEncryptedDirect => 'Terenkripsi · langsung';

  @override
  String get chatEncryptedOverTor => 'Terenkripsi · lewat Tor';

  @override
  String get chatSearchThisChat => 'Cari di obrolan ini';

  @override
  String get chatContactOptions => 'Opsi kontak';

  @override
  String get commonClose => 'Tutup';

  @override
  String get chatFindInConversation => 'Cari di obrolan';

  @override
  String get chatNoMatches => 'Tidak ada hasil';

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
      other: '*$posString* dari $countString hasil',
      one: '*$posString* dari $countString hasil',
    );
    return '$_temp0';
  }

  @override
  String get chatPreviousMatch => 'Hasil sebelumnya';

  @override
  String get chatNextMatch => 'Hasil berikutnya';

  @override
  String get chatPhotoUnavailable => 'Foto tidak tersedia';

  @override
  String get chatDelivered => 'Diterima';

  @override
  String get chatEdited => 'Diubah';

  @override
  String get chatFailedTapToRetry => 'Gagal · ketuk untuk coba lagi';

  @override
  String get chatReplyingTo => 'Membalas dia';

  @override
  String get chatReplyingToYourself => 'Membalas dirimu sendiri';

  @override
  String get chatReply => 'Balas';

  @override
  String get chatSayHi => 'Sapa dia.';

  @override
  String get chatJustTheTwoOf =>
      'Hanya kalian berdua, terenkripsi ujung ke ujung.';

  @override
  String get chatSayHiSoThey => 'Sapa dulu biar dia tahu kamu ada';

  @override
  String get chatTheyWonTKnow =>
      'Dia tidak akan tahu kamu menambahkannya sampai pesan pertamamu sampai.';

  @override
  String get chatWave => 'Melambai';

  @override
  String get chatMicPermissionNeeded => 'Perlu izin mikrofon';

  @override
  String get chatTheMicWouldNot => 'Mikrofon tidak mau menyala. Coba lagi';

  @override
  String get chatReleaseToCancel => 'Lepas untuk batal';

  @override
  String get chatVoiceHiddenSlideTo => 'Suara disamarkan · geser untuk batal';

  @override
  String get chatSlideToCancel => 'Geser untuk batal';

  @override
  String get chatGhostMode => 'Pesan berwaktu';

  @override
  String chatMessagesBurnAfter(Object humanBurn) {
    return 'hilang setelah $humanBurn';
  }

  @override
  String get chatTimedMessages => 'Pesan berwaktu';

  @override
  String get chatOpenTheCamera => 'Buka kamera';

  @override
  String get chatAttachAPhoto => 'Lampirkan foto';

  @override
  String get chatMessage => 'Pesan';

  @override
  String get commonSend => 'Kirim';

  @override
  String get chatHoldToRecord => 'Tahan untuk merekam pesan suara';

  @override
  String get chatSecurityCodeChanged => 'Kode keamanan berubah';

  @override
  String get chatCompareTitle => 'Bandingkan nomor keamanan';

  @override
  String chatCompareLine(Object peerName) {
    return 'Tiga kata bisa disalin. Untuk tahu obrolan ini benar dengan $peerName, bandingkan nomor keamanan dengannya, secara tatap muka atau lewat panggilan.';
  }

  @override
  String get chatCompareLater => 'Nanti';

  @override
  String get chatCompareNow => 'Bandingkan';

  @override
  String chatKeyHeldLine(Object peerName) {
    return 'Kamu sudah memverifikasi $peerName sebelumnya. Tidak ada yang terkirim sampai kamu memeriksa nomor yang baru atau menerima kunci yang baru. Pesan darinya tetap masuk.';
  }

  @override
  String get chatCheckTheNumber => 'Periksa nomornya';

  @override
  String get chatAcceptNewKey => 'Terima kunci baru';

  @override
  String get chatAcceptNewKeyTitle => 'Terima kunci barunya?';

  @override
  String chatAcceptNewKeyLine(Object peerName) {
    return 'Kryfo lalu mengirim ke kunci baru tanpa pemeriksaan, dan $peerName tidak lagi ditandai terverifikasi. Kamu bisa memverifikasinya lagi kapan saja.';
  }

  @override
  String chatMayHaveReinstalledOr(Object peerName) {
    return '$peerName mungkin memasang ulang aplikasinya, atau mungkin ada yang menyamar sebagai dia. Bandingkan nomor keamanan untuk memastikan.';
  }

  @override
  String get chatOk => 'Oke';

  @override
  String get chatVerify => 'Verifikasi';

  @override
  String get cleanKryfoCanTClean =>
      'Kryfo belum bisa membersihkan jenis file ini.';

  @override
  String get cleanThisIsAMotion => 'Ini foto bergerak.';

  @override
  String get cleanThisPictureIsToo =>
      'Gambar ini terlalu besar untuk dibersihkan di sini.';

  @override
  String get cleanThisFileIsDamaged => 'File ini rusak atau terpotong.';

  @override
  String get cleanKryfoCouldNotMake =>
      'Kryfo tidak bisa membersihkan yang ini.';

  @override
  String get cleanNotEnoughRoomOn => 'Ruang di ponsel tidak cukup.';

  @override
  String get cleanNotEnoughRoomOnDesk => 'Ruang di komputer tidak cukup.';

  @override
  String get cleanKryfoCouldNotOpen => 'Kryfo tidak bisa membuka file itu.';

  @override
  String get cleanItCleansJpegPng =>
      'Kryfo bisa membersihkan JPEG, PNG, WebP, HEIC, AVIF, GIF, MP4, dan MOV. Tidak ada yang diubah.';

  @override
  String get cleanItHoldsAShort =>
      'Di dalamnya ada video pendek di samping gambar, dan Kryfo belum bisa membersihkan bagian itu. Matikan foto bergerak di kameramu, atau kirim tangkapan layarnya.';

  @override
  String get cleanPicturesOver64Mb =>
      'Gambar di atas 64 MB tidak dibersihkan di ponsel. Tidak ada yang diubah.';

  @override
  String get cleanPicturesOver64MbDesk =>
      'Gambar di atas 64 MB tidak dibersihkan di komputer. Tidak ada yang diubah.';

  @override
  String get cleanKryfoCouldNotRead =>
      'Kryfo tidak bisa membacanya sampai habis, jadi tidak akan menyebutnya bersih. Tidak ada salinan yang dibuat.';

  @override
  String get cleanSomethingInsideIsOf =>
      'Ada sesuatu di dalamnya yang Kryfo tidak tahu cara menghapusnya, jadi tidak ada salinan yang dibuat.';

  @override
  String get cleanFreeSomeSpaceAnd =>
      'Kosongkan sedikit ruang lalu coba lagi. Tidak ada yang diubah.';

  @override
  String get cleanTheAppThatShared =>
      'Aplikasi yang membagikannya mungkin sudah menariknya kembali. Coba bagikan lagi.';

  @override
  String get cleanTheAppThatSharedDesk =>
      'Mungkin sudah dipindah, atau aplikasi lain sedang membukanya. Coba pilih lagi.';

  @override
  String get cleanNoAppOnThis =>
      'Tidak ada aplikasi di ponsel ini yang menerima file itu.';

  @override
  String get cleanCouldNotSaveIt =>
      'Gagal menyimpannya. Pastikan ponsel masih punya ruang.';

  @override
  String get cleanCouldNotSaveItDesk =>
      'Gagal menyimpannya. Pastikan komputer masih punya ruang.';

  @override
  String get cleanTheOriginalIsGone =>
      'Aslinya sudah terhapus. Salinan bersihnya tetap ada.';

  @override
  String get cleanAndroidWouldNotDelete =>
      'Android tidak mau menghapusnya. Hapus dari galeri secara manual.';

  @override
  String get cleanCleanCopy => 'Salinan bersih';

  @override
  String get cleanShareCleanCopy => 'Bagikan salinan bersih';

  @override
  String get cleanSaveToGallery => 'Simpan ke galeri';

  @override
  String get cleanSaveToGalleryDesk => 'Simpan salinan bersih';

  @override
  String get commonStop => 'Hentikan';

  @override
  String get cleanReadingTheFile => 'Membaca file';

  @override
  String get cleanCleaning => 'Membersihkan';

  @override
  String cleanOf(Object prettySize, Object prettySize2) {
    return '$prettySize dari $prettySize2';
  }

  @override
  String get cleanEverythingStaysOnThis => 'Semuanya tetap di ponsel ini.';

  @override
  String get cleanEverythingStaysOnThisDesk =>
      'Semuanya tetap di komputer ini.';

  @override
  String get cleanAlreadyClean => 'Sudah bersih.';

  @override
  String get cleanClean => 'Bersih.';

  @override
  String get cleanThereWasNothingTo => 'Memang tidak ada apa-apa.';

  @override
  String get cleanNothingLeftToFind => 'Tidak ada lagi yang tersisa.';

  @override
  String get cleanSameVideoSameQuality => 'Video sama, kualitas sama';

  @override
  String get cleanSamePictureSameQuality => 'Gambar sama, kualitas sama';

  @override
  String get cleanSamePicture => 'Gambar sama';

  @override
  String cleanRemoved(Object label) {
    return '$label, dihapus';
  }

  @override
  String get cleanRemoved2 => 'DIHAPUS';

  @override
  String get cleanWithTheLocationInside =>
      'dengan lokasi di dalamnya. Siapa pun yang mendapatkannya tahu nama jalanmu.';

  @override
  String get cleanWithEverythingItKnew =>
      'dengan semua yang diketahuinya masih di dalamnya.';

  @override
  String get cleanOriginal => 'ASLI';

  @override
  String get cleanClean2 => 'BERSIH';

  @override
  String get cleanSavedToYourGallery => 'Disimpan ke galerimu.';

  @override
  String get cleanSavedToYourGalleryDesk =>
      'Disimpan di tempat yang kamu pilih.';

  @override
  String cleanTheOriginalIsStill(Object what) {
    return 'Aslinya juga masih ada, $what';
  }

  @override
  String cleanTheOriginalIsStillWhereIt(Object what) {
    return 'Aslinya masih di tempatnya, $what Kryfo tidak bisa menghapusnya dari sini, jadi hapus di aplikasi asalnya.';
  }

  @override
  String get cleanDeleteTheOriginal => 'Hapus aslinya';

  @override
  String get cleanKeepBoth => 'Simpan keduanya';

  @override
  String get commonDone => 'Selesai';

  @override
  String get cleanAndroidWillAskYou => 'ANDROID AKAN MEMINTA KONFIRMASI';

  @override
  String get contactYourNameForThem => 'Nama panggilan untuknya';

  @override
  String get contactStaysOnThisPhone =>
      'Tetap di ponsel ini. Dia tidak pernah melihatnya.';

  @override
  String get contactStaysOnThisPhoneDesk =>
      'Tetap di komputer ini. Dia tidak pernah melihatnya.';

  @override
  String get contactClear => 'Kosongkan';

  @override
  String get contactMessage => 'Kirim pesan';

  @override
  String get contactKeysVerified => 'Kunci terverifikasi';

  @override
  String get contactVerifyKeys => 'Verifikasi kunci';

  @override
  String get contactVouches => 'Jaminan';

  @override
  String get contactUnmute => 'Bunyikan';

  @override
  String get contactMute => 'Bisukan';

  @override
  String get contactUnpin => 'Lepas sematan';

  @override
  String get contactPinToTop => 'Sematkan di atas';

  @override
  String get contactArchive => 'Arsipkan';

  @override
  String get contactOutOfTheList =>
      'Keluar dari daftar sampai dia menulis lagi';

  @override
  String contactBlock(Object name) {
    return 'Blokir $name?';
  }

  @override
  String get contactTheirMessagesStopArriving =>
      'Pesannya berhenti masuk. Dia tidak diberi tahu.';

  @override
  String get contactDeleteChat => 'Hapus obrolan';

  @override
  String get contactMessagesAndContactGone =>
      'Pesan dan kontak terhapus dari ponsel ini';

  @override
  String get contactMessagesAndContactGoneDesk =>
      'Pesan dan kontak terhapus dari komputer ini';

  @override
  String get contactDeleteThisChat => 'Hapus obrolan ini?';

  @override
  String get contactEveryMessageAndThe =>
      'Semua pesan dan kontaknya terhapus dari ponsel ini. Tidak ada yang dikirim ke dia.';

  @override
  String get contactEveryMessageAndTheDesk =>
      'Semua pesan dan kontaknya terhapus dari komputer ini. Tidak ada yang dikirim ke dia.';

  @override
  String get commonDelete => 'Hapus';

  @override
  String get contactDeleted => 'Dihapus';

  @override
  String get contactToday => 'Hari ini';

  @override
  String contactD(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hari',
    );
    return '$_temp0';
  }

  @override
  String contactMo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bulan',
    );
    return '$_temp0';
  }

  @override
  String contactY(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tahun',
    );
    return '$_temp0';
  }

  @override
  String get contactVerified => 'Terverifikasi';

  @override
  String get contactChatting => 'Mengobrol';

  @override
  String get contactNothingSharedYet => 'Belum ada yang dibagikan';

  @override
  String contactSharedMedia(Object count) {
    return 'Media dibagikan · $count';
  }

  @override
  String get donateBitcoin => 'Bitcoin';

  @override
  String get donateText => '₿';

  @override
  String get donateBadgeUnlocks => 'Lencana terbuka';

  @override
  String get donateMonero => 'Monero';

  @override
  String get donateManualNoBadge => 'Manual · tanpa lencana';

  @override
  String get donateSolana => 'Solana';

  @override
  String get donateEthereum => 'Ethereum';

  @override
  String get donateText2 => 'Ξ';

  @override
  String donateYourEarlierBitcoinPayment(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter':
          'Pembayaran bitcoin-mu sebelumnya terdeteksi · lencana pendukung terbuka',
      'patron':
          'Pembayaran bitcoin-mu sebelumnya terdeteksi · lencana patron terbuka',
      'guardian':
          'Pembayaran bitcoin-mu sebelumnya terdeteksi · lencana penjaga terbuka',
      'other':
          'Pembayaran bitcoin-mu sebelumnya terdeteksi · lencana pendukung terbuka',
    });
    return '$_temp0';
  }

  @override
  String get donateSupport => 'Dukung';

  @override
  String get donateKeepKryfo => 'Jaga Kryfo tetap *mandiri*';

  @override
  String get donateNoAdsNoInvestors =>
      'Tanpa iklan, tanpa investor, tidak ada yang dijual. Kryfo hidup dari pemberian para penyokong.';

  @override
  String get donateBackItAnonymouslyBadge =>
      'Dukung secara anonim. Lencana opsional.\n*Semua fitur privasi gratis.*';

  @override
  String get donateAuditTitle => 'Bantu danai audit keamanan';

  @override
  String get donateAuditLine =>
      'Donasi di sini dihitung untuk audit independen. Laporan lengkapnya akan dibuka untuk publik.';

  @override
  String get donateCard => 'Kartu';

  @override
  String get donateCardOneTime =>
      'Donasi sekali saja lewat browser-mu. Jumlahnya kamu yang pilih.';

  @override
  String get donateCardMarios =>
      'Sampai fiscal host kami siap, pembayaran kartu langsung masuk ke Marios.';

  @override
  String get donateCardSeesName =>
      'Perusahaan pembayaran melihat namamu. Kripto adalah pilihan yang privat.';

  @override
  String get donateCardPay => 'Bayar dengan kartu';

  @override
  String get donateNoBitcoinCard => 'Tidak punya bitcoin? Bayar dengan kartu';

  @override
  String get donateCardNoBadge => 'Donasi dengan kartu tidak membuka lencana.';

  @override
  String donateAddressCheckItAgainst(Object coinName) {
    return 'Alamat $coinName · cocokkan dengan dompetmu';
  }

  @override
  String get donateAddressCopiedClearsIn =>
      'Alamat disalin · dihapus dalam 60 dtk';

  @override
  String get donateCopyAddress => 'Salin alamat';

  @override
  String get donateBitcoinIsVerifiedBy =>
      'Bitcoin diverifikasi oleh node kami sendiri, jadi lencanamu terbuka sendiri begitu pembayaran masuk.';

  @override
  String get donateWeCanTVerify =>
      'Kami tidak bisa memverifikasi blockchain ini tanpa bertanya tentang kamu ke layanan luar, jadi kami tidak melakukannya. Kirim saja kalau mau. Ini tidak akan membuka lencana.';

  @override
  String get donateBitcoinBadgesNeedOnion => 'Lencana bitcoin butuh mode onion';

  @override
  String get donateSwitchToOnion => 'Beralih ke onion';

  @override
  String get donatePayWithBitcoin => 'Bayar pakai bitcoin  →';

  @override
  String get donateBadgesStartAt20 => 'Lencana mulai dari \$20';

  @override
  String get donateShowTheAddress => 'Tampilkan alamat';

  @override
  String donateReviewAmount(String amount) {
    return '$amount dalam bitcoin';
  }

  @override
  String get donateWhatTheBadgeGives => 'Yang kamu dapat dari lencana';

  @override
  String get donateGivesMark =>
      'Tanda di samping namamu. Kamu yang memilih siapa yang melihatnya, atau tidak ada sama sekali.';

  @override
  String get donateGivesReceipt =>
      'Tanda terima bertanda tangan yang tersimpan di ponsel ini. Ini membuktikan lencana tanpa akun apa pun.';

  @override
  String get donateGivesReceiptDesk =>
      'Tanda terima bertanda tangan yang tersimpan di komputer ini. Ini membuktikan lencana tanpa akun apa pun.';

  @override
  String get donateGivesFree =>
      'Semua fitur privasi tetap gratis, dengan atau tanpa lencana.';

  @override
  String get donateAddressOnTap =>
      'Alamat baru dibuat saat kamu mengetuk di bawah. Alamat itu milikmu selama satu jam, jadi saat kembali kamu mendapat yang sama.';

  @override
  String get donateBitcoinBusy =>
      'Bitcoin sedang sibuk. Coba lagi nanti atau bayar dengan kartu.';

  @override
  String get donateBusyPlainAddress =>
      'Kamu tetap bisa mengirim bitcoin ke alamat di bawah. Alamat ini tidak memberi lencana.';

  @override
  String get donateSameAddressAgain =>
      'Ini alamat yang kamu buka tadi. Kalau sudah mengirim, tunggu di sini.';

  @override
  String get donateReachingThePaymentService =>
      'Menghubungi layanan pembayaran lewat Tor…';

  @override
  String get donateThisCanTakeUp => 'Ini bisa makan waktu satu atau dua menit';

  @override
  String donateSThisCanTake(Object waited) {
    return '$waited dtk · ini bisa makan waktu satu atau dua menit';
  }

  @override
  String get donateUseTheAddressInstead => 'Pakai alamat saja';

  @override
  String get donateThePaymentServiceIs =>
      'Layanan pembayaran ini berupa onion, dan hanya mode onion yang bisa menjangkaunya. Tidak ada yang dikirim.';

  @override
  String get donateTorWasSlowTo =>
      'Tor lambat menjangkau layanan pembayaran. Kamu bisa berdonasi ke alamat di bawah, hanya saja lencanamu tidak akan terbuka otomatis. Coba lagi nanti untuk lencananya.';

  @override
  String get donateThePaymentServiceIsHavingTrouble =>
      'Layanan pembayaran sedang bermasalah. Kamu tetap bisa berdonasi ke alamat di bawah, hanya saja lencanamu tidak akan terbuka otomatis. Coba lagi nanti untuk lencananya.';

  @override
  String get commonTryAgain => 'Coba lagi';

  @override
  String donateBtc(Object btc) {
    return '$btc BTC';
  }

  @override
  String donateSendExactlyThisAmount(Object fmtLeft) {
    return 'Kirim tepat sejumlah ini · berakhir dalam $fmtLeft';
  }

  @override
  String get donateOpenWallet => 'Buka dompet';

  @override
  String get donateThisScreenUpdatesItself =>
      'Layar ini langsung diperbarui begitu pembayaranmu terdeteksi.\nBiarkan terbuka. Tidak ada yang disimpan, tidak ada yang mengidentifikasi dirimu.';

  @override
  String get donateWatchingTheChainFor =>
      'Memantau blockchain untuk pembayaranmu';

  @override
  String get donateThisInvoiceExpired => 'Tagihan ini kedaluwarsa';

  @override
  String get donateInvoicesTimeOutIf =>
      'Tagihan punya batas waktu. Kalau kamu sudah mengirim pembayaran, biarkan layar ini terbuka: kami bertanya lagi ke layanan setiap menit untuk sementara, dan lagi saat kamu membuka Dukung berikutnya. Buat tagihan baru kapan saja kamu mau.';

  @override
  String get donateNewInvoice => 'Tagihan baru';

  @override
  String get donateIPaidCheckAgain => 'Sudah bayar, cek lagi';

  @override
  String get donateNoWallet =>
      'Tidak ada aplikasi di ponsel ini yang bisa membuka tautan bitcoin. Salin alamatnya saja.';

  @override
  String get donateChecking => 'Mengecek…';

  @override
  String get donateNotSeenYet =>
      'Belum terlihat. Pembayaran bisa butuh beberapa menit untuk muncul.';

  @override
  String get donatePaymentConfirmed => 'Pembayaran dikonfirmasi';

  @override
  String get donateThankYouForKeeping =>
      'Terima kasih sudah menjaga Kryfo tetap mandiri.';

  @override
  String donateVerifiedOnChainYou(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter':
          'Terverifikasi on-chain. Sekarang kamu pendukung. Tidak ada yang bisa mencabutnya darimu.',
      'patron':
          'Terverifikasi on-chain. Sekarang kamu patron. Tidak ada yang bisa mencabutnya darimu.',
      'guardian':
          'Terverifikasi on-chain. Sekarang kamu penjaga. Tidak ada yang bisa mencabutnya darimu.',
      'other':
          'Terverifikasi on-chain. Sekarang kamu pendukung. Tidak ada yang bisa mencabutnya darimu.',
    });
    return '$_temp0';
  }

  @override
  String donateVerifiedBadgeStays(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter':
          'Terverifikasi on-chain. Terima kasih sudah memberi lagi. Lencana pendukung kamu tetap milikmu.',
      'patron':
          'Terverifikasi on-chain. Terima kasih sudah memberi lagi. Lencana patron kamu tetap milikmu.',
      'guardian':
          'Terverifikasi on-chain. Terima kasih sudah memberi lagi. Lencana penjaga kamu tetap milikmu.',
      'other':
          'Terverifikasi on-chain. Terima kasih sudah memberi lagi. Lencana pendukung kamu tetap milikmu.',
    });
    return '$_temp0';
  }

  @override
  String get donateWearMyBadge => 'Pakai lencanaku';

  @override
  String get donateJustGladToHelp => 'Senang bisa membantu';

  @override
  String get gettingMessagesAlwaysOn => 'Selalu aktif';

  @override
  String get gettingMessagesMostPrivate => 'Paling privat';

  @override
  String get gettingMessagesMessagesArriveInstantlyNothing =>
      'Paling boros baterai.\nSeketika, dan tidak ada yang keluar dari Tor.';

  @override
  String get gettingMessagesArriveInstantlyFast =>
      'Paling boros baterai.\nSeketika di Cepat.';

  @override
  String get gettingMessagesCheckIns => 'Cek berkala';

  @override
  String get gettingMessagesLightest => 'Paling ringan';

  @override
  String get gettingMessagesKryfoLooksForMessages =>
      'Kryfo mengecek setiap 15 menit, jadi pesan bisa terlambat.\nHemat baterai.';

  @override
  String get gettingMessagesAGenericAlertWith =>
      'Pemberitahuan umum, tanpa pengirim dan tanpa isi pesan';

  @override
  String get gettingMessagesShowsMessageTextIn =>
      'Menampilkan isi pesan di notifikasi, bahkan saat Kryfo terkunci.';

  @override
  String get gettingMessagesWhenThePhoneSits =>
      'Saat ponsel diam, Android menjarangkan pengecekan. Baris di atas menunjukkan pengecekan terakhir yang sebenarnya. Selama Kryfo terbuka, ia tetap terhubung.';

  @override
  String get groupChatJumpToTheNewest => 'Ke pesan terbaru';

  @override
  String get groupChatYou => 'Kamu';

  @override
  String get groupChatVoiceMessage => 'Pesan suara';

  @override
  String get groupChatQuotedPhoto => 'Foto';

  @override
  String get groupChatMessageUnavailable => 'Pesan tidak tersedia';

  @override
  String get groupChatTorIsNotUp =>
      'Tor belum terhubung · tanpa pratinjau tautan';

  @override
  String get groupChatCouldnTReachIt =>
      'Halamannya tak terjangkau · tanpa pratinjau tautan';

  @override
  String get groupChatNoTitleCameBack =>
      'Halaman itu tidak punya judul · tanpa pratinjau tautan';

  @override
  String get groupChatCouldnTFetchIt => 'Gagal memuat pratinjau';

  @override
  String get groupChatCamera => 'Kamera';

  @override
  String get groupChatGallery => 'Galeri';

  @override
  String get groupChatVideo => 'Video';

  @override
  String get groupChatGifFromPhone => 'Gif dari ponsel';

  @override
  String get groupChatGifFromPhoneDesk => 'Gif dari komputer';

  @override
  String get groupChatCouldNotReadThat => 'Gagal membaca file itu';

  @override
  String get groupChatGifTooBig8 => 'Gif terlalu besar · maks 8 mb';

  @override
  String get groupChatCouldNotCleanThat => 'Gagal membersihkan gif itu';

  @override
  String get groupChatCouldNotCleanThatVideo => 'Gagal membersihkan video itu';

  @override
  String get groupChatToday => 'Hari ini';

  @override
  String get groupChatYesterday => 'Kemarin';

  @override
  String get groupChatYou2 => 'Kamu';

  @override
  String groupChatThisChatHasPins(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Obrolan ini sudah punya $countString sematan',
    );
    return '$_temp0';
  }

  @override
  String get groupChatUnpinThisMessage => 'Lepas sematan pesan ini?';

  @override
  String get groupChatPinThisMessage => 'Sematkan pesan ini?';

  @override
  String get groupChatItLeavesThePinned =>
      'Pesan ini keluar dari daftar sematan untuk semua orang di sini.';

  @override
  String get groupChatItGoesUnderThe =>
      'Pesan ini masuk ke sematan di atas obrolan, untuk semua orang di sini.';

  @override
  String get groupChatUnpin => 'Lepas sematan';

  @override
  String get groupChatPinIt => 'Sematkan';

  @override
  String get groupChatNotNow => 'Nanti saja';

  @override
  String get groupChatSaved => 'Tersimpan';

  @override
  String get groupChatRemovedFromSaved => 'Dihapus dari Tersimpan';

  @override
  String get groupChatForwardTo => 'Teruskan ke';

  @override
  String get groupChatNoContactsToForward =>
      'Tidak ada kontak untuk diteruskan';

  @override
  String get groupChatEditMessage => 'Ubah pesan';

  @override
  String get groupChatUnsendMessage => 'Tarik pesan';

  @override
  String get groupChatItDisappearsWithNo =>
      'Pesan ini akan dihapus dari ponsel semua orang, kecuali sudah disimpan. Ini tidak bisa dibatalkan.';

  @override
  String get groupChatItDisappearsWithNoDesk =>
      'Pesan ini akan dihapus dari perangkat semua orang, kecuali sudah disimpan. Ini tidak bisa dibatalkan.';

  @override
  String get groupChatUnsend => 'Tarik pesan';

  @override
  String groupChatThisRoomAndEverything(Object expiryWords) {
    return 'Ruang ini dan semua isinya hilang dalam $expiryWords';
  }

  @override
  String groupChatGhostModeOnBurns(Object fmtBurn) {
    return 'Pesan berwaktu · hilang setelah $fmtBurn';
  }

  @override
  String get groupChatGroupCreatedSayHi => 'Grup dibuat. Sapa mereka.';

  @override
  String get groupChatNoMessagesYet => 'Belum ada pesan.';

  @override
  String get groupChatEveryoneHereReads =>
      'Semua orang di sini membaca apa yang kamu tulis.';

  @override
  String get groupChatNobodyHereYet => 'Belum ada siapa pun di sini.';

  @override
  String get groupChatShareTheRoomLink =>
      'Bagikan tautan ruang. Siapa pun yang bergabung membaca apa yang ditulis sejak saat itu.';

  @override
  String get groupChatNobodyToReadIt =>
      'Tidak ada orang lain di sini yang bisa membacanya.';

  @override
  String get groupChatThisMessageCanT => 'Pesan ini tidak bisa ditampilkan';

  @override
  String groupChatS(Object s) {
    return '$s dtk';
  }

  @override
  String groupChatM(Object s) {
    return '$s mnt';
  }

  @override
  String groupChatH(Object s) {
    return '$s j';
  }

  @override
  String groupChatD(Object s) {
    return '$s hr';
  }

  @override
  String groupChatHere(int count, Object time) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$time · $countString di sini',
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
      other: '$countString anggota',
    );
    return '$_temp0';
  }

  @override
  String get groupChatSearchThisChat => 'Cari di obrolan ini';

  @override
  String groupChatReplyingTo(Object name) {
    return 'Membalas $name';
  }

  @override
  String get groupChatReplyingToYou => 'Membalas kamu';

  @override
  String get groupChatTimedMessages => 'Pesan berwaktu';

  @override
  String get groupChatOpenTheCamera => 'Buka kamera';

  @override
  String get groupChatAttachAPhoto => 'Lampirkan foto';

  @override
  String get groupChatMessage => 'Pesan';

  @override
  String get groupChatSupporter => 'Pendukung';

  @override
  String get groupChatEdited => 'Diubah';

  @override
  String get groupChatTapToRetry => '! Ketuk untuk ulangi';

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
      other: 'Terkirim · $haveString dari $countString sudah menerima',
      zero: 'Terkirim · dalam perjalanan',
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
      other: 'Terkirim · $countString orang tidak menerimanya',
    );
    return '$_temp0';
  }

  @override
  String get groupChatReply => 'Balas';

  @override
  String get groupChatPin => 'Sematkan';

  @override
  String get groupChatUnsave => 'Batal simpan';

  @override
  String get groupChatForward => 'Teruskan';

  @override
  String get groupInfoGroup => 'Grup';

  @override
  String get groupInfoRenameGroup => 'Ganti nama grup';

  @override
  String get groupInfoRename => 'Ganti nama';

  @override
  String get groupInfoNoContactsToAdd => 'Tidak ada kontak lain';

  @override
  String get groupInfoCouldNotAdd => 'Gagal menambahkan';

  @override
  String groupInfoRemove(Object haloId) {
    return 'Keluarkan $haloId?';
  }

  @override
  String get groupInfoTheyWillStopReceiving =>
      'Dia tidak akan lagi menerima pesan dari grup ini.';

  @override
  String get groupInfoResetLink => 'Atur ulang tautan';

  @override
  String get groupInfoResetTheRoomLink => 'Atur ulang tautan ruang?';

  @override
  String get groupInfoResetLinkLine =>
      'Tautan lama tidak berfungsi lagi. Orang di ruang tetap tinggal dan dapat tautan baru.';

  @override
  String get groupInfoRemoveRoomLine =>
      'Dia bisa masuk lagi lewat tautan ruang. Atur ulang tautannya agar dia tetap di luar. Yang masih di ruang akan dapat tautan baru.';

  @override
  String get groupInfoRemoveAndResetLink => 'Keluarkan dan atur ulang tautan';

  @override
  String get groupInfoCouldNotResetLink => 'Tautan tidak bisa diatur ulang';

  @override
  String get roomLinkNewLinkTheOld =>
      'Tautan baru. Yang lama sudah tidak berfungsi.';

  @override
  String appGroupHoldsUpTo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Satu grup paling banyak $countString orang',
    );
    return '$_temp0';
  }

  @override
  String get commonRemove => 'Hapus';

  @override
  String get groupInfoClearThisConversation => 'Bersihkan obrolan ini?';

  @override
  String get groupInfoEveryMessageHereIs =>
      'Semua pesan di sini dihapus dari ponsel ini. Ini hanya membersihkan salinanmu, anggota lain tetap menyimpan salinan mereka.';

  @override
  String get groupInfoEveryMessageHereIsDesk =>
      'Semua pesan di sini dihapus dari komputer ini. Ini hanya membersihkan salinanmu, anggota lain tetap menyimpan salinan mereka.';

  @override
  String get groupInfoClear => 'Bersihkan';

  @override
  String get groupInfoConversationCleared => 'Obrolan dibersihkan';

  @override
  String get groupInfoLeaveRoom => 'Keluar dari ruang?';

  @override
  String get groupInfoLeaveGroup => 'Keluar dari grup?';

  @override
  String get groupInfoEverythingInItIs =>
      'Semua isinya langsung dihapus total dari ponsel ini, dan kunci yang kamu pakai di sini hilang selamanya.';

  @override
  String get groupInfoEverythingInItIsDesk =>
      'Semua isinya langsung dihapus total dari komputer ini, dan kunci yang kamu pakai di sini hilang selamanya.';

  @override
  String groupChatYouWereRemovedFrom(Object name) {
    return 'Kamu dikeluarkan dari $name';
  }

  @override
  String get groupInfoLeaveGroupLine =>
      'Kamu tidak akan lagi menerima pesannya, dan semua isinya dihapus dari ponsel ini.';

  @override
  String get groupInfoLeaveGroupLineDesk =>
      'Kamu tidak akan lagi menerima pesannya, dan semua isinya dihapus dari komputer ini.';

  @override
  String get groupInfoLeaveGroupAdmin =>
      'Kamu tidak akan lagi menerima pesannya, dan semua isinya dihapus dari ponsel ini. Kamu adminnya, jadi setelah kamu keluar tidak ada yang bisa mengubah anggota atau mengganti namanya.';

  @override
  String get groupInfoLeaveGroupAdminDesk =>
      'Kamu tidak akan lagi menerima pesannya, dan semua isinya dihapus dari komputer ini. Kamu adminnya, jadi setelah kamu keluar tidak ada yang bisa mengubah anggota atau mengganti namanya.';

  @override
  String get groupInfoLeaveRoomMaker =>
      'Semua isinya langsung dihapus total dari ponsel ini, dan kunci yang kamu pakai di sini hilang selamanya. Kamu yang membuat ruang ini, jadi tautannya tidak bisa lagi dipakai untuk masuk.';

  @override
  String get groupInfoLeaveRoomMakerDesk =>
      'Semua isinya langsung dihapus total dari komputer ini, dan kunci yang kamu pakai di sini hilang selamanya. Kamu yang membuat ruang ini, jadi tautannya tidak bisa lagi dipakai untuk masuk.';

  @override
  String get groupInfoLeave => 'Keluar';

  @override
  String get groupInfoGroupInfo => 'Info grup';

  @override
  String groupInfo1Member(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString anggota',
    );
    return '$_temp0';
  }

  @override
  String get groupInfoAdmin => 'Admin';

  @override
  String get groupInfoMembers2 => 'Anggota';

  @override
  String get groupInfoInvite => 'Undang';

  @override
  String get commonAdd => 'Tambah';

  @override
  String get groupInfoYou => 'Kamu';

  @override
  String get groupInfoRemoveFromGroup => 'Keluarkan dari grup';

  @override
  String get groupInfoWallpaper => 'Latar belakang';

  @override
  String get groupInfoSharedMedia => 'Media yang dibagikan';

  @override
  String get groupInfoClearConversation => 'Bersihkan obrolan';

  @override
  String get groupInfoLeaveRoom2 => 'Keluar dari ruang';

  @override
  String get groupInfoLeaveGroup2 => 'Keluar dari grup';

  @override
  String get groupInfoAddMembers => 'Tambah anggota';

  @override
  String groupInfoAdd(Object pickedLength) {
    return 'Tambah $pickedLength';
  }

  @override
  String handleYouAre(Object h) {
    return 'Kamu adalah @$h';
  }

  @override
  String get handleHandleDeletedThePage =>
      'Nama pengguna dihapus · halamannya sudah hilang';

  @override
  String get handlePublicHandle => 'Nama pengguna publik';

  @override
  String get handleOptionalYourThreeWords =>
      'Opsional. Tiga katamu tetap berfungsi apa pun pilihanmu.';

  @override
  String get handleHintName => 'name';

  @override
  String get handleALineAboutYou => 'Satu baris tentangmu · opsional';

  @override
  String get handleClaiming => 'Mengklaim…';

  @override
  String get handleClaimThisHandle => 'Klaim nama pengguna ini';

  @override
  String get handleAnyoneWithThisLink =>
      'Siapa pun yang punya tautan ini bisa memulai obrolan privat denganmu. Isinya undanganmu dan tidak ada yang lain.';

  @override
  String get handleLinkCopied => 'Tautan disalin';

  @override
  String get handleDeleteThisHandle => 'Hapus nama pengguna ini';

  @override
  String handleDeleteTitle(Object handle) {
    return 'Hapus @$handle?';
  }

  @override
  String get handleDeleteLine =>
      'Halaman publikmu hilang dan siapa pun bisa mengambil nama itu. Obrolan yang sudah ada tetap seperti biasa.';

  @override
  String get handleDeleteYes => 'Hapus nama pengguna';

  @override
  String get handleDeleting => 'Menghapus…';

  @override
  String get handleChecking => 'Mengecek…';

  @override
  String get handleAvailable => 'Tersedia';

  @override
  String get handleAlreadyTaken => 'Sudah dipakai';

  @override
  String get handleNameRule => '3 sampai 20 karakter: a-z, 0-9 atau _';

  @override
  String get handleWhatAHandleDoes => 'Guna nama pengguna';

  @override
  String get handleAnyoneWhoKnowsIt =>
      'Siapa pun yang tahu nama ini bisa meminta untuk mengirimimu pesan. Halamannya hanya berisi undanganmu dan baris yang kamu tulis, tidak ada yang lain, dan tidak mencatat siapa yang membacanya. Kamu bisa menghapusnya kapan saja.';

  @override
  String handleIsNotYoursOn(Object handle) {
    return '@$handle bukan milikmu di ponsel ini';
  }

  @override
  String handleIsNotYoursOnDesk(Object handle) {
    return '@$handle bukan milikmu di komputer ini';
  }

  @override
  String handleTheRegistryHoldsIt(Object handle) {
    return 'Registri menyimpannya dengan kunci lain, kemungkinan besar identitas yang dimiliki ponsel ini sebelum dipulihkan. Orang yang menambahkan @$handle tidak sampai ke kamu. Nama ini tidak bisa dilepas atau diperbarui dari sini. Pilih nama lain.';
  }

  @override
  String handleTheRegistryHoldsItDesk(Object handle) {
    return 'Registri menyimpannya dengan kunci lain, kemungkinan besar identitas yang dimiliki komputer ini sebelum dipulihkan. Orang yang menambahkan @$handle tidak sampai ke kamu. Nama ini tidak bisa dilepas atau diperbarui dari sini. Pilih nama lain.';
  }

  @override
  String get handleForgetItOnThis => 'Lupakan di ponsel ini';

  @override
  String get handleForgetItOnThisDesk => 'Lupakan di komputer ini';

  @override
  String get homeAddAContact => 'Tambah kontak';

  @override
  String get commonSettings => 'Pengaturan';

  @override
  String get homeYourKryfo => 'Kryfo-mu';

  @override
  String homeDateWeekday(Object weekday) {
    return '$weekday,';
  }

  @override
  String get homeAnHour => 'satu jam';

  @override
  String homeHours(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString jam',
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
      other: '$countString menit',
    );
    return '$_temp0';
  }

  @override
  String get homeKryfoIsOffline => 'Kryfo sedang offline';

  @override
  String homeTorHasNotBeen(Object howLong) {
    return 'Tor belum bisa terhubung selama $howLong. Tidak ada yang bisa masuk atau keluar sampai Tor terhubung.';
  }

  @override
  String get homeReconnecting => 'Menyambung ulang';

  @override
  String get homeReconnect => 'Sambung ulang';

  @override
  String get homeWhatIsWrong => 'Apa masalahnya';

  @override
  String get homeKryfoWillCheckIn => 'Kryfo akan mengecek setiap 15 menit';

  @override
  String get homeYourPhoneKeepsStopping => 'Ponselmu terus menghentikan Kryfo';

  @override
  String get homeItHasClosedKryfo =>
      'Ponselmu sudah menutup Kryfo tiga kali hari ini, jadi pesan terlambat atau tertahan. Cek berkala tetap jalan meski begitu: Kryfo bangun setiap 15 menit alih-alih terus terhubung.';

  @override
  String get homeSwitchToCheckIns => 'Beralih ke cek berkala';

  @override
  String get homeNotNow => 'Nanti saja';

  @override
  String get homeNotificationsAreOff => 'Notifikasi mati';

  @override
  String get homeAndroidIsBlockingThem =>
      'Android memblokirnya, jadi tidak ada yang sampai ke kamu saat Kryfo ditutup. Pesan tetap masuk saat kamu membukanya.';

  @override
  String get homeCouldnTOpenIt =>
      'Tidak bisa dibuka. Cari Kryfo di pengaturan ponsel';

  @override
  String get homeTurnThemOn => 'Nyalakan';

  @override
  String get homeLeaveThemOff => 'Biarkan mati';

  @override
  String get homeKeepWaiting => 'Tunggu lagi';

  @override
  String get homeOffline => 'Offline';

  @override
  String get homeWaiting => 'Menunggu';

  @override
  String get homeNothingWaitingToSend => 'Tidak ada yang menunggu dikirim';

  @override
  String homeWaitingSendsWhenYou(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString menunggu · terkirim saat kamu online lagi',
    );
    return '$_temp0';
  }

  @override
  String get homeNoKryfosYet => 'Belum ada Kryfo.';

  @override
  String get homeScanTheirCodeSend =>
      'Pindai kodenya, kirimi dia tautan, atau ketik @nama pengguna yang dia berikan.';

  @override
  String get homeScanTheirCodeSendDesk =>
      'Kirimi dia tautan, atau ketik @nama pengguna yang dia berikan.';

  @override
  String get homeAddSomeone => 'Tambah orang';

  @override
  String get homeArchived => 'Arsip';

  @override
  String home1Chat(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString obrolan',
    );
    return '$_temp0';
  }

  @override
  String get homeGroups => 'Grup';

  @override
  String get homeRoom => 'Ruang';

  @override
  String get homeNew => 'Baru';

  @override
  String homeRoomExpired(Object expiredRoomName) {
    return '$expiredRoomName · ruang kedaluwarsa';
  }

  @override
  String get homeMentionedYou => 'Menyebutmu';

  @override
  String homeMembers(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString anggota',
    );
    return '$_temp0';
  }

  @override
  String get homeSupporter => 'Pendukung';

  @override
  String get homeUnmute => 'Bunyikan';

  @override
  String get homeMute => 'Bisukan';

  @override
  String get homeArchive => 'Arsipkan';

  @override
  String get homeDeleteChat => 'Hapus obrolan';

  @override
  String get homeMessagesAndContactGone =>
      'Pesan dan kontak terhapus dari ponsel ini';

  @override
  String get homeMessagesAndContactGoneDesk =>
      'Pesan dan kontak terhapus dari komputer ini';

  @override
  String get homeDeleteThisChat => 'Hapus obrolan ini?';

  @override
  String homeEveryMessageWithGoes(Object c) {
    return 'Semua pesan dengan $c terhapus, dan dia tidak lagi jadi kontak. Ini hanya membersihkan ponsel ini. Salinannya tetap ada padanya. Kalau dia mengirim pesan lagi, pesannya masuk ke permintaan.';
  }

  @override
  String homeEveryMessageWithGoesDesk(Object c) {
    return 'Semua pesan dengan $c terhapus, dan dia tidak lagi jadi kontak. Ini hanya membersihkan komputer ini. Salinannya tetap ada padanya. Kalau dia mengirim pesan lagi, pesannya masuk ke permintaan.';
  }

  @override
  String get homeQueued => 'Dalam antrean';

  @override
  String get homeBlocked => 'Diblokir';

  @override
  String get homeRoomInvite => 'Undangan ruang';

  @override
  String get homeNow => 'Sekarang';

  @override
  String homeM(Object inMinutes) {
    return '$inMinutes mnt';
  }

  @override
  String homeH(Object inHours) {
    return '$inHours j';
  }

  @override
  String get homeYesterday => 'Kemarin';

  @override
  String homeD(Object inDays) {
    return '$inDays hr';
  }

  @override
  String get homeNoteToSelf => 'Catatan pribadi';

  @override
  String get homeOnlyOnThisPhone => 'Hanya di ponsel ini';

  @override
  String get homeOnlyOnThisPhoneDesk => 'Hanya di komputer ini';

  @override
  String get homeSaved => 'Tersimpan';

  @override
  String get homeKeptFromEveryChat => 'Disimpan dari semua obrolan';

  @override
  String get homeRequests => 'Permintaan';

  @override
  String home1PersonWantsTo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString orang ingin menghubungimu',
    );
    return '$_temp0';
  }

  @override
  String introduceGotItButCould(Object b, Object c) {
    return '$b sudah menerimanya, tapi $c tidak bisa dihubungi';
  }

  @override
  String introduceGotItButCouldNotBe(Object c, Object b) {
    return '$c sudah menerimanya, tapi $b tidak bisa dihubungi';
  }

  @override
  String introduceIntroduced(Object b, Object c) {
    return '$b dan $c sekarang punya kartu satu sama lain';
  }

  @override
  String get introduceCouldNotReachEither =>
      'Keduanya tidak bisa dihubungi. Coba lagi nanti';

  @override
  String introduceIntroduceTo(Object peerName) {
    return 'Perkenalkan $peerName ke...';
  }

  @override
  String get introduceBothOfThemGet =>
      'Keduanya menerima kartu satu sama lain. Tidak ada yang melihat nama panggilanmu untuk yang lain.';

  @override
  String get introduceNoOneElseTo =>
      'Belum ada orang lain untuk diperkenalkan. Tambahkan kontak lain dulu.';

  @override
  String get introduceANoteLikeMy => 'Catatan, misalnya “sepupuku” (opsional)';

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
      other: '$leftString dari $maxString perkenalan tersisa minggu ini',
    );
    return '$_temp0';
  }

  @override
  String introduceNoIntroductionsLeftNext(Object refillPhrase) {
    return 'Jatah perkenalan habis. Berikutnya tersedia $refillPhrase';
  }

  @override
  String get introduceIntroduce => 'Perkenalkan';

  @override
  String get keyVerificationSafetyNumber => 'Nomor keamanan';

  @override
  String get keyVerificationNewNumber =>
      'Kode keamanan berubah saat halaman ini terbuka. Ini nomor yang baru, bandingkan sekali lagi.';

  @override
  String get keyVerificationKeyMoved =>
      'Kode keamanan baru saja berubah. Bandingkan nomor yang baru.';

  @override
  String keyVerificationNoKeyYet(Object peerName) {
    return 'Belum ada kunci dari $peerName. Nomornya muncul di sini setelah dia mengirim pesan kepadamu.';
  }

  @override
  String keyVerificationWith(Object peerName) {
    return 'Dengan $peerName';
  }

  @override
  String keyVerificationCompareAll(Object peerName) {
    return 'Bandingkan ke-12 kelompok dengan $peerName, secara tatap muka atau lewat panggilan yang kamu percaya. Kalau semua kelompok sama, tidak ada orang di tengah dan pesan kalian hanya untuk kalian berdua.';
  }

  @override
  String get keyVerificationVerified => 'Terverifikasi';

  @override
  String get keyVerificationMarkAsVerified => 'Tandai terverifikasi';

  @override
  String get lockFileThatPasswordDoesNot =>
      'Kata sandi itu tidak bisa membukanya.';

  @override
  String get lockFileThisFileIsDamaged => 'File ini rusak.';

  @override
  String get lockFileThisFileWasLocked =>
      'File ini dikunci dengan kunci, bukan dengan kata sandi.';

  @override
  String get lockFileThisIsNotA => 'Ini bukan file terkunci.';

  @override
  String get lockFileNotEnoughFreeMemory => 'Memori sedang tidak cukup.';

  @override
  String get lockFileStopped => 'Dihentikan.';

  @override
  String get lockFileItNeedsAPassword => 'Perlu kata sandi.';

  @override
  String get lockFileKryfoCouldNotRead =>
      'Kryfo tidak bisa membaca atau menulis file ini.';

  @override
  String get lockFileCheckCapitalsAndSpaces =>
      'Periksa huruf besar dan spasi. Tidak ada yang bisa meresetnya.';

  @override
  String get lockFileItMayHaveBeen =>
      'Mungkin terpotong di jalan. Minta dikirim ulang. Tidak ada yang disimpan.';

  @override
  String get lockFileItOpensWithThe =>
      'File ini dibuka dengan file kunci milik orang yang dituju, lewat alat age di komputer. Kryfo membuka jenis yang memakai kata sandi.';

  @override
  String get lockFileKryfoOpensFilesLocked =>
      'Kryfo membuka file yang dikunci dengan age. Biasanya berakhiran .age.';

  @override
  String get lockFileCloseAFewApps =>
      'Tutup beberapa aplikasi lalu coba lagi. Pengecekan kata sandi sebentar butuh beberapa ratus megabyte.';

  @override
  String get lockFileNothingWasSaved => 'Tidak ada yang disimpan.';

  @override
  String get lockFileTypeOneOrLet =>
      'Ketik sendiri, atau biarkan Kryfo menyarankan empat kata.';

  @override
  String get lockFileTheAppThatHolds =>
      'Aplikasi yang menyimpannya mungkin sudah menariknya kembali. Pilih lagi.';

  @override
  String get lockFileHidePassword => 'Sembunyikan kata sandi';

  @override
  String get lockFileShowPassword => 'Tampilkan kata sandi';

  @override
  String get lockFileChangeFile => 'Ganti file';

  @override
  String get lockFileChange => 'Ganti';

  @override
  String lockFileOf(Object prettySize, Object prettySize2) {
    return '$prettySize dari $prettySize2';
  }

  @override
  String get lockFileEverythingStaysOnThis => 'Semuanya tetap di ponsel ini.';

  @override
  String get lockFileEverythingStaysOnThisDesk =>
      'Semuanya tetap di komputer ini.';

  @override
  String get lockFileCouldNotMakeOne => 'Gagal membuatnya. Ketik sendiri.';

  @override
  String get lockFileWriteItDownBefore =>
      'Catat dulu sebelum kamu mengunci file';

  @override
  String get lockFileNoAppOnThis =>
      'Tidak ada aplikasi di ponsel ini yang menerima file itu.';

  @override
  String get linkNoAppOpens =>
      'Tidak ada aplikasi di ponsel ini yang bisa membuka tautan ini.';

  @override
  String get linkNoAppOpensDesk =>
      'Tidak ada aplikasi di komputer ini yang bisa membuka tautan ini.';

  @override
  String get placeStubLocation => 'Lokasi';

  @override
  String get lockFileSaved => 'Disimpan';

  @override
  String get lockFileCouldNotSaveIt =>
      'Gagal menyimpannya di sana. Coba folder lain.';

  @override
  String get lockFileLocked => 'Terkunci';

  @override
  String get lockFileLockAFile => 'Kunci file';

  @override
  String get lockFileMixingThePassword => 'Mengolah kata sandi';

  @override
  String get lockFileLocking => 'Mengunci';

  @override
  String get lockFileSaveToFiles => 'Simpan ke File';

  @override
  String get lockFileSaveToFilesDesk => 'Simpan file';

  @override
  String get lockFileLockFile => 'Kunci file';

  @override
  String get lockFileOnePassword => 'Satu kata sandi.';

  @override
  String get lockFileNothingElseOpensIt => 'Tak ada cara lain membukanya.';

  @override
  String get lockFileFile => 'File';

  @override
  String lockFileFromFiles(Object prettySize) {
    return '$prettySize · dari File';
  }

  @override
  String get lockFileFromFiles2 => 'Dari File';

  @override
  String get lockFilePassword => 'Kata sandi';

  @override
  String get lockFileSuggestFourWords => 'Sarankan empat kata';

  @override
  String get lockFileTypeItAgain => 'Ketik lagi';

  @override
  String get lockFileTheTwoDoNot => 'Keduanya belum cocok.';

  @override
  String get lockFileHideTheFileName => 'Sembunyikan nama file';

  @override
  String lockFileItWillBeCalled(Object name) {
    return 'Namanya akan jadi “$name”. Beri tahu penerimanya jenis file apa ini.';
  }

  @override
  String get lockFileTheNameAloneCan => 'Namanya saja bisa menunjukkan isinya.';

  @override
  String get lockFileAnyoneWithThePassword =>
      'Siapa pun yang tahu kata sandinya bisa membukanya, di Kryfo atau di komputer mana pun dengan alat gratis age. Lupa kata sandinya, file ini hilang selamanya. Tidak ada yang bisa meresetnya.';

  @override
  String get lockFileLocked2 => 'Terkunci.';

  @override
  String get lockFileOnlyThePasswordOpens =>
      'Hanya kata sandinya yang bisa membukanya.';

  @override
  String lockFileSafeToEmailOr(Object prettySize) {
    return '$prettySize · aman dikirim lewat email atau disimpan di flashdisk';
  }

  @override
  String get lockFileNoKryfoOnThe => 'Penerima tidak punya Kryfo? Di komputer:';

  @override
  String get lockFileItAsksForThe =>
      'Nanti diminta kata sandinya. age gratis di age-encryption.org';

  @override
  String lockTooManyTriesS(Object lockState) {
    return 'Terlalu banyak percobaan · $lockState dtk';
  }

  @override
  String get lockNotIt => 'Salah';

  @override
  String get lockYourPin => 'PIN-mu';

  @override
  String get lockUseFingerprint => 'Pakai sidik jari';

  @override
  String get lockSetupUnlockWithFingerprint => 'Buka kunci dengan sidik jari?';

  @override
  String get lockSetupThePinStillWorks =>
      'PIN tetap bisa dipakai kapan pun kamu mau. Ini hanya lebih cepat.';

  @override
  String get lockSetupUseFingerprint => 'Pakai sidik jari';

  @override
  String get lockSetupTurningOn => 'Menyalakan…';

  @override
  String get lockSetupPinOnly => 'PIN saja';

  @override
  String get lockSetupOnceMore => 'Sekali lagi';

  @override
  String get lockSetupSetAPin => 'Buat PIN';

  @override
  String get lockSetupThoseWereDifferentFrom =>
      'Tadi berbeda. Ulangi dari awal.';

  @override
  String get lockSetupTheSameFourDigits => 'Angka yang sama sekali lagi';

  @override
  String get lockSetupFourDigitsAnythingYou =>
      'Empat angka atau lebih, apa saja yang bisa kamu ingat';

  @override
  String get modesFast => 'Cepat';

  @override
  String get modesNotChanged => 'Mode tidak berubah. Coba lagi.';

  @override
  String get modesSwitching => 'Mengganti…';

  @override
  String get modesSpeed => 'Kecepatan';

  @override
  String get modesPrivacy => '& privasi';

  @override
  String get movedWipeThisPhone => 'Hapus total Kryfo dari ponsel ini?';

  @override
  String get movedWipeThisPhoneDesk => 'Hapus total Kryfo dari komputer ini?';

  @override
  String get movedEverythingKryfoHoldsHere =>
      'Semua yang disimpan Kryfo di sini hilang: pesan, kontak, kunci. Perangkat lain tetap menyimpan semuanya. Ini tidak bisa dibatalkan.';

  @override
  String get movedWipeIt => 'Hapus total';

  @override
  String get movedNotMovingAfterAll => 'Tidak jadi pindah?';

  @override
  String get movedOnlyDoThisIf =>
      'Lakukan ini hanya kalau cadangannya belum pernah diimpor di mana pun. Kalau sudah, sekarang ada dua perangkat dengan satu identitas, dan pesan akan mulai hilang di keduanya.';

  @override
  String get movedIMStayingHere => 'Aku tetap di sini';

  @override
  String get movedStayingHere => 'Tetap di sini';

  @override
  String movedKryfoWillCloseNow(Object myId) {
    return 'Kryfo akan ditutup sekarang. Ketuk ikonnya untuk membuka lagi sebagai $myId.';
  }

  @override
  String movedKryfoWillCloseNowDesk(Object myId) {
    return 'Kryfo akan ditutup sekarang. Jalankan lagi untuk membukanya sebagai $myId.';
  }

  @override
  String get movedReopenKryfo => 'Buka lagi Kryfo';

  @override
  String get movedThisKryfoHasMoved => 'Kryfo ini sudah pindah';

  @override
  String movedIsNowOnAnother(Object myId) {
    return '$myId sekarang ada di perangkat lain. Ponsel ini masih bisa menampilkan isinya, tapi tidak ada yang baru akan masuk, dan apa pun yang kamu kirim dari sini tidak akan sampai ke siapa pun.';
  }

  @override
  String movedIsNowOnAnotherDesk(Object myId) {
    return '$myId sekarang ada di perangkat lain. Komputer ini masih bisa menampilkan isinya, tapi tidak ada yang baru akan masuk, dan apa pun yang kamu kirim dari sini tidak akan sampai ke siapa pun.';
  }

  @override
  String get movedKeepItToRead => 'Simpan untuk dibaca';

  @override
  String get movedWipeThisPhone2 => 'Hapus total Kryfo dari ponsel ini';

  @override
  String get movedWipeThisPhone2Desk => 'Hapus total Kryfo dari komputer ini';

  @override
  String get movedIMNotMoving => 'Aku tidak jadi pindah';

  @override
  String get myKryfoAHandleIs3 =>
      'Nama pengguna berisi 3 sampai 20 huruf, angka, atau _';

  @override
  String get myKryfoInviteCopiedClearsIn =>
      'Undangan disalin · dihapus dalam 60 dtk';

  @override
  String get myKryfoAddMeOnKryfo2 => 'Tambahkan aku di Kryfo';

  @override
  String get myKryfoAddSomeone => 'Tambah orang';

  @override
  String get myKryfoKryfoDoesnTScan =>
      'Kryfo tidak memindai kontakmu, memang itu intinya.';

  @override
  String get myKryfoIfThisLinkEnds =>
      'Kalau tautan ini sampai ke tempat yang tidak kamu maksud, reset di pengaturan. Setelah itu, semua yang memilikinya butuh tautan baru.';

  @override
  String get myKryfoAlreadyShareAFriend =>
      'Punya teman yang sama di Kryfo? Dia bisa memperkenalkan kalian dari obrolannya, dan kalian tidak perlu lewat permintaan.';

  @override
  String get myKryfoHandleCopied => 'Nama pengguna disalin';

  @override
  String get myKryfoTheyReHereWith => 'Dia ada di sini bersamaku';

  @override
  String get myKryfoPointYourPhonesAt =>
      'Arahkan ponsel kalian satu sama lain. Tidak ada yang lewat server.';

  @override
  String get myKryfoPointYourPhonesAtDesk =>
      'Mereka memindai kode ini dengan ponselnya. Tidak ada yang lewat server.';

  @override
  String get myKryfoScanTheirsInstead => 'Pindai kodenya saja';

  @override
  String get myKryfoTheyReadYouA => 'Dia membacakan kode';

  @override
  String get myKryfoTheyReSomewhereElse => 'Dia ada di tempat lain';

  @override
  String get myKryfoSendThemALink =>
      'Kirimi dia tautan. Tautannya langsung membuka layar tambah.';

  @override
  String get myKryfoYourLinkAppearsOnce =>
      'Tautanmu muncul setelah kamu terhubung';

  @override
  String get myKryfoTheLinkCarriesYour =>
      'Tautan ini berisi tiga katamu, alamatmu, dan kunci untuk memulai obrolan. Tautan ini berlaku sampai kamu meresetnya di pengaturan.';

  @override
  String get myKryfoSendTheLink => 'Kirim tautan';

  @override
  String get myKryfoAsACard => 'Sebagai kartu';

  @override
  String get myKryfoAnImageWithThe => 'Gambar dengan QR';

  @override
  String get myKryfoAsAFile => 'Sebagai file';

  @override
  String get myKryfoContactFile => 'File kontak';

  @override
  String get myKryfoIKnowTheirHandle => 'Aku tahu nama penggunanya';

  @override
  String get myKryfoTypeTheNameThey =>
      'Ketik @nama yang dia berikan. Bisa kalau dia sudah mengklaimnya.';

  @override
  String get myKryfoTheLookupAsksFor =>
      'Pencarian hanya mengirim nama itu dan tidak ada apa pun tentang kamu. Pesan pertamamu tetap sampai sebagai permintaan.';

  @override
  String get myKryfoLooking => 'Mencari…';

  @override
  String get myKryfoFindThem => 'Cari dia';

  @override
  String get myKryfoYourAddressAppearsOnce =>
      'Alamatmu muncul setelah kamu terhubung';

  @override
  String get myKryfoAPublicHandle => 'Nama pengguna publik';

  @override
  String get myKryfoPutItInA =>
      'Taruh di bio. Siapa pun yang tahu bisa menemukanmu.';

  @override
  String get myKryfoANamePeopleCan =>
      'Nama untuk orang menemukanmu. Mati sampai kamu mengklaimnya.';

  @override
  String get newGroupCouldNotCreate => 'Gagal membuat';

  @override
  String get newGroupNewGroup => 'Grup baru';

  @override
  String get newGroupCreating => 'Membuat…';

  @override
  String get newGroupCreate => 'Buat';

  @override
  String get newGroupGroupName => 'Nama grup';

  @override
  String get newGroupMembers => 'Anggota';

  @override
  String get newGroupPickAtLeastOne => 'Pilih minimal satu';

  @override
  String newGroupSelected(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString dipilih',
    );
    return '$_temp0';
  }

  @override
  String get newGroupAddAtLeastOne =>
      'Tambahkan minimal satu kontak dulu sebelum membuat grup.';

  @override
  String get newGroupNeedsContacts => 'Grup dibuat bersama kontakmu';

  @override
  String get newGroupAddSomeoneFirst =>
      'Tambahkan seseorang dulu. Ruang tidak butuh kontak: siapa pun yang punya tautannya bisa bergabung.';

  @override
  String get notesDeleteThisNote => 'Hapus catatan ini?';

  @override
  String get notesHoldHint =>
      'Tahan sebuah catatan untuk menyalin atau menghapusnya.';

  @override
  String get notesMenu => 'Menu catatan';

  @override
  String get notesDeleteAll => 'Hapus semua catatan';

  @override
  String get notesDeleteAllTitle => 'Hapus semua catatan?';

  @override
  String get notesDeleteAllLine =>
      'Semua catatan di ponsel ini hilang untuk selamanya.';

  @override
  String get notesDeleteAllLineDesk =>
      'Semua catatan di komputer ini hilang untuk selamanya.';

  @override
  String get notesDeleteAllYes => 'Hapus semua';

  @override
  String get notesThisWeek => 'Minggu ini';

  @override
  String get notesShowMore => 'Lihat selengkapnya';

  @override
  String get notesShowLess => 'Lihat lebih sedikit';

  @override
  String get notesGoneFromThisPhone =>
      'Catatan ini terhapus dari ponsel ini untuk selamanya.';

  @override
  String get notesGoneFromThisPhoneDesk =>
      'Catatan ini terhapus dari komputer ini untuk selamanya.';

  @override
  String get notesNoteToSelf => 'Catatan pribadi';

  @override
  String get notesOnlyOnThisPhone => 'Hanya di ponsel ini';

  @override
  String get notesOnlyOnThisPhoneDesk => 'Hanya di komputer ini';

  @override
  String get notesAQuietPlace => 'Tempat yang tenang';

  @override
  String get notesJotAnythingDownIt =>
      'Tulis apa saja. Semuanya tetap di ponsel ini dan tidak pernah keluar.';

  @override
  String get notesJotAnythingDownItDesk =>
      'Tulis apa saja. Semuanya tetap di komputer ini dan tidak pernah keluar.';

  @override
  String get notesJotSomethingDown => 'Tulis sesuatu…';

  @override
  String get notesExportNotes => 'Ekspor catatan';

  @override
  String get notesExport => 'Ekspor';

  @override
  String get notesExportWorking => 'Mengekspor…';

  @override
  String notesExportCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString catatan, dari yang paling lama.',
    );
    return '$_temp0';
  }

  @override
  String get notesExportZip => 'Foto dan pesan suara ikut di dalam zip.';

  @override
  String get notesExportText => 'Teks biasa';

  @override
  String get notesExportTextLine => 'File .txt yang bisa dibuka di mana saja';

  @override
  String get notesExportMarkdown => 'Markdown';

  @override
  String get notesExportMarkdownLine =>
      'File .md dengan judul, untuk aplikasi catatan';

  @override
  String get notesExportLock => 'Kunci dengan frasa sandi';

  @override
  String get notesExportLockLine =>
      'Buka di Alat dengan “Buka file terkunci”, atau dengan age di komputer';

  @override
  String get notesExportPlainTitle => 'Ekspor tanpa frasa sandi?';

  @override
  String get notesExportPlainLine =>
      'Siapa pun yang mendapat file ini bisa membacanya.';

  @override
  String get notesExportPlainYes => 'Ekspor tanpa sandi';

  @override
  String get notesExportKeepLock => 'Tetap pakai frasa sandi';

  @override
  String get notesExportNotSaved =>
      'Catatan tidak tersimpan. File-nya masih ada.';

  @override
  String get notesExportGone =>
      'File-nya dihapus saat Kryfo terkunci. Ekspor lagi untuk membuat yang baru.';

  @override
  String get notesExportHoldsInstaller =>
      'Ekspor ini berisi file penginstal aplikasi, jadi tidak bisa dibagikan. Simpan saja ke ponselmu.';

  @override
  String get notesExportHoldsInstallerDesk =>
      'Ekspor ini berisi file penginstal aplikasi, jadi tidak bisa dibagikan. Simpan saja ke komputer ini.';

  @override
  String get notesExportSaved => 'Catatan tersimpan';

  @override
  String notesExportSavedIn(String place) {
    return 'Catatan tersimpan di $place';
  }

  @override
  String get notesExportSavedUnchecked =>
      'Catatan tersimpan, tapi Kryfo tidak bisa memeriksa salinannya';

  @override
  String get notesExportFailed =>
      'Catatan tidak bisa diekspor. Tidak ada yang disimpan.';

  @override
  String get notesExportTooLarge =>
      'Terlalu besar untuk diekspor. Foto dan pesan suaranya mencapai 4 GB atau lebih.';

  @override
  String get notesExportSubject => 'Catatan Kryfo';

  @override
  String get onboardingPrivateByDefault => 'Privat sejak awal';

  @override
  String get onboardingPrivateMessaging => 'Pesan privat,\n*tanpa jebakan*.';

  @override
  String get onboardingYourNameIsThree =>
      '*Namamu tiga kata.*\nTanpa nomor ponsel, tanpa email, tanpa buku alamat.';

  @override
  String get onboardingNobodyGetsInUnless =>
      '*Tak ada yang masuk tanpa izinmu.*\nTanpa @nama publik, tak ada yang bisa mencarimu.\nOrang asing hanya bisa mengetuk.';

  @override
  String get onboardingTheFirstConnectionTakes =>
      '*Koneksi pertama butuh satu menit.*\nKryfo membangun rute privat dulu. Setelahnya cepat.';

  @override
  String get onboardingBegin => 'Mulai';

  @override
  String get onboardingHaveABackupRestore => 'Punya cadangan? Pulihkan →';

  @override
  String get onboardingKryfoIsOpenSource => 'Kryfo bersumber terbuka';

  @override
  String get onboardingYourKryfoId => 'Namamu';

  @override
  String get onboardingGeneratedFromAKey =>
      'Dibuat dari kunci yang hanya ada di ponsel ini.\n*Tak ada orang lain yang punya kata-kata ini.*';

  @override
  String get onboardingGeneratedFromAKeyDesk =>
      'Dibuat dari kunci yang hanya ada di komputer ini.\n*Tak ada orang lain yang punya kata-kata ini.*';

  @override
  String get onboardingTryAnother => 'Coba yang lain';

  @override
  String get onboardingUseThisName => 'Pakai nama ini →';

  @override
  String get onboardingThreeWords => 'Tiga kata. *Hanya milikmu.*';

  @override
  String get onboardingContinue => 'Lanjut →';

  @override
  String get onboardingKryfoBuildsAPrivateRouteBefore =>
      'Kryfo membangun rute privat sebelum mengirim apa pun. Saat kamu offline, pesan menunggu dan sampai saat kamu kembali.';

  @override
  String get onboardingYourIdentityLivesOn =>
      'Identitasmu tinggal di ponsel ini.\nCadangkan di Pengaturan saat kamu siap.';

  @override
  String get onboardingYourIdentityLivesOnDesk =>
      'Identitasmu tinggal di komputer ini.\nCadangkan di Pengaturan saat kamu siap.';

  @override
  String get onboardingSilentAndAtThe =>
      'Senyap, di bagian bawah panel notifikasi';

  @override
  String get onboardingItNeverBuzzesTurn =>
      'Tidak pernah bergetar.\nKalau dimatikan, pesan menunggu sampai kamu membuka Kryfo.';

  @override
  String get onboardingGotIt => 'Mengerti →';

  @override
  String get onboardingEveryWayToAdd => 'Semua cara menambah orang';

  @override
  String get onboardingShowYourCodeSend =>
      'Tunjukkan kodemu, bagikan tautan, atau ketik @nama mereka.';

  @override
  String get onboardingScanTheirs => 'Pindai kodenya';

  @override
  String get onboardingPointTheCameraAt => 'Arahkan kamera ke kodenya';

  @override
  String get onboardingNotNowAddPeople =>
      'Nanti saja · tambah orang belakangan';

  @override
  String get openLockedOpened => 'Terbuka';

  @override
  String get openLockedOpenALockedFile => 'Buka file terkunci';

  @override
  String get openLockedCheckingThePassword => 'Mengecek kata sandi';

  @override
  String get openLockedOpening => 'Membuka';

  @override
  String get openLockedFile => 'File';

  @override
  String get openLockedOpenFile => 'Buka file';

  @override
  String get openLockedTypeThePassword => 'Ketik kata sandinya.';

  @override
  String get openLockedItOpensOnThis => 'File ini dibuka di ponsel ini.';

  @override
  String get openLockedItOpensOnThisDesk => 'File ini dibuka di komputer ini.';

  @override
  String get openLockedLockedFile => 'File terkunci';

  @override
  String openLockedFromFiles(Object prettySize) {
    return '$prettySize · dari File';
  }

  @override
  String get openLockedFromFiles2 => 'Dari File';

  @override
  String get openLockedPassword => 'Kata sandi';

  @override
  String get openLockedThePasswordIsChecked =>
      'Kata sandi dicek lebih dulu. Baru setelah itu Kryfo menanyakan di mana file yang dibuka akan disimpan, dan file langsung masuk ke sana.';

  @override
  String get openLockedOpened2 => 'Terbuka.';

  @override
  String get openLockedSavedWhereYouChose => 'Disimpan di tempat pilihanmu.';

  @override
  String get pairCodePairingCode => 'Kode penautan';

  @override
  String get pairCodeShowACode => 'Tunjukkan kode';

  @override
  String get pairCodeEnterOne => 'Masukkan kode';

  @override
  String get pairCodeLooking => 'Mencari…';

  @override
  String get pairCodeNothingThereYetTrying =>
      'Belum ada apa-apa · mencoba lagi';

  @override
  String get pairCodeNothingAtThatCode =>
      'Tidak ada apa pun di kode itu. Mungkin sudah hilang, atau dia belum membagikannya.';

  @override
  String get pairCodeUnreached =>
      'Tidak bisa menghubungi relay. Coba lagi sebentar lagi.';

  @override
  String get fastRoomsWaitForTor =>
      'Ruang, kode penautan, dan kontak pertama selalu lewat Tor, juga di Cepat. Semuanya langsung jalan begitu Tor terhubung.';

  @override
  String get pairCodeFailed => 'Tidak berhasil. Coba lagi.';

  @override
  String get pairCodeAddThem => 'Tambahkan';

  @override
  String get pairCodeKeyNumber => 'Nomor kunci';

  @override
  String get pairCodeNotAdded => 'Tidak ditambahkan. Minta kode baru.';

  @override
  String get pairCodeEightDigits => 'Delapan angka';

  @override
  String get pairCodeTypeTheEightDigits =>
      'Ketik delapan angka yang dia bacakan.';

  @override
  String get pairCodeOldCode =>
      'Kode itu dari Kryfo versi lama. Kedua ponsel perlu Kryfo 0.6 atau yang lebih baru.';

  @override
  String get pairCodeOldCodeDesk =>
      'Kode itu dari Kryfo versi lama. Kedua perangkat perlu Kryfo 0.6 atau yang lebih baru.';

  @override
  String get pairCodeBothNeed06 =>
      'Kedua ponsel perlu Kryfo 0.6 atau yang lebih baru.';

  @override
  String get pairCodeBothNeed06Desk =>
      'Kedua perangkat perlu Kryfo 0.6 atau yang lebih baru.';

  @override
  String get pairCodeWaitingForThem => 'Menunggu dia…';

  @override
  String get pairCodeStillWaiting =>
      'Masih menunggu. Jika layarnya bilang kode yang salah diketik, periksa angkanya bersama.';

  @override
  String get pairCodeUnanswered =>
      'Tidak ada jawaban. Periksa kodenya bersama dia, lalu ketik lagi.';

  @override
  String get pairCodeTooManyTries =>
      'Kode ini sudah dicoba tiga kali. Minta kode baru.';

  @override
  String get pairCodeRanOut => 'Waktu kode itu sudah habis. Minta kode baru.';

  @override
  String get pairCodeMatched => 'Kodenya cocok. Saling menambahkan?';

  @override
  String get pairCodeNotThem => 'Bukan dia';

  @override
  String get pairCodePanelReadEightDigitsOut =>
      'Bacakan delapan angka dengan keras dan kalian saling menambahkan. Tidak ada hal lain yang perlu dipertukarkan.';

  @override
  String get pairCodePanelOrMakeACode => 'Atau buat kode untuk dibacakan';

  @override
  String get pairCodePanelTheyOpenKryfoEight =>
      'Dia membuka Kryfo, mengetuk tambah, memilih kode penautan, lalu mengetik delapan angka ini. Buat yang baru untuk orang berikutnya.';

  @override
  String get pairCodePanelWrongTyped =>
      'Kode yang salah diketik. Bacakan lagi pelan-pelan.';

  @override
  String get pairCodePanelThreeWrong =>
      'Kode yang salah diketik tiga kali, jadi kode ini berhenti. Buat yang baru.';

  @override
  String get pairCodePanelNotAdded =>
      'Tidak ditambahkan. Buat kode baru saat mereka siap.';

  @override
  String get panicSetupThoseWereDifferentFrom =>
      'Tadi berbeda. Ulangi dari awal.';

  @override
  String get panicSetupOnceMore => 'Sekali lagi';

  @override
  String get panicSetupTheSameFourDigits => 'Angka yang sama sekali lagi';

  @override
  String get photoKnowsEverythingInside => 'Semua isinya';

  @override
  String get photoKnowsVideo => 'Video';

  @override
  String get photoKnowsPhoto => 'Foto';

  @override
  String get photoKnowsVideoCleaner => 'Pembersih video';

  @override
  String get photoKnowsPhotoCleaner => 'Pembersih foto';

  @override
  String get photoKnowsRemoveAllOfIt => 'Hapus semuanya';

  @override
  String get photoKnowsKeepItAsIt => 'Biarkan apa adanya';

  @override
  String get photoKnowsReadingTheFile => 'Membaca file';

  @override
  String photoKnowsOf(Object prettySize, Object prettySize2) {
    return '$prettySize dari $prettySize2';
  }

  @override
  String get photoKnowsEverythingStaysOnThis => 'Semuanya tetap di ponsel ini.';

  @override
  String get photoKnowsEverythingStaysOnThisDesk =>
      'Semuanya tetap di komputer ini.';

  @override
  String photoKnowsMapWithAPin(Object place) {
    return 'Peta dengan penanda. $place';
  }

  @override
  String get photoKnowsDrawnOffline => 'DIGAMBAR OFFLINE';

  @override
  String photoKnowsShowEverything(Object title) {
    return '$title. Tampilkan semua';
  }

  @override
  String get pinsAppLock => 'Kunci aplikasi';

  @override
  String get pinsYourPin => 'PIN-mu';

  @override
  String get commonOn => 'Aktif';

  @override
  String get commonOff => 'Mati';

  @override
  String get pinsOpensKryfoFourDigits =>
      'Membuka Kryfo. Diminta setiap Kryfo kembali ke depan.';

  @override
  String get pinsChangePin => 'Ganti PIN';

  @override
  String get pinsSetAPin => 'Buat PIN';

  @override
  String get pinsTurnOff => 'Matikan';

  @override
  String get pinsTurnOffTheApp => 'Matikan kunci aplikasi?';

  @override
  String get pinsThePinGoesAnd =>
      'PIN dihapus, begitu juga PIN penghapus dan obrolan tersembunyi yang ada. Siapa pun yang memegang ponselmu langsung masuk ke Kryfo sebagai dirimu.';

  @override
  String get pinsThePinGoesAndDesk =>
      'PIN dihapus, begitu juga PIN penghapus dan obrolan tersembunyi yang ada. Siapa pun yang memakai komputermu langsung masuk ke Kryfo sebagai dirimu.';

  @override
  String get pinsUnlockWithFingerprint => 'Buka kunci dengan sidik jari';

  @override
  String get pinsFingerOpensDecoy =>
      'Mati selama PIN umpan dipasang: jari hanya membuka umpan.';

  @override
  String get pinsWipePin => 'PIN penghapus';

  @override
  String get pinsNeedsAPinFirst => 'Perlu PIN dulu';

  @override
  String get pinsSet => 'Aktif';

  @override
  String get pinsChangeWipePin => 'Ganti PIN penghapus';

  @override
  String get pinsRemove => 'Hapus';

  @override
  String get pinsRemoveTheWipePin => 'Hapus PIN penghapus?';

  @override
  String get pinsTheLockScreenKeeps =>
      'Layar kunci tetap memakai PIN-mu. PIN penghapus tidak lagi berfungsi.';

  @override
  String profileCopied(Object what) {
    return '$what disalin';
  }

  @override
  String get profileProfile => 'Profil';

  @override
  String get profileKryfoId => 'Namamu';

  @override
  String get profileOnionAddress => 'Alamat onion';

  @override
  String get profileSupporterBadge => 'Lencana pendukung';

  @override
  String profileYouAreAThank(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter': 'Kamu pendukung. Terima kasih.',
      'patron': 'Kamu patron. Terima kasih.',
      'guardian': 'Kamu penjaga. Terima kasih.',
      'other': 'Kamu pendukung. Terima kasih.',
    });
    return '$_temp0';
  }

  @override
  String get profileShowMyBadge => 'Tampilkan lencanaku';

  @override
  String get profileOnMyOwnScreens => 'Di layarku sendiri';

  @override
  String get profileLetContactsSeeIt => 'Biarkan kontak melihatnya';

  @override
  String get profileOffByDefault => 'Mati secara bawaan';

  @override
  String get profileShareConnect => 'Bagikan & terhubung';

  @override
  String get profileMyKryfoCode => 'Kode Kryfo-ku';

  @override
  String get profileAddContact => 'Tambah kontak';

  @override
  String get profileGiveAgain => 'Beri lagi';

  @override
  String get profileSupportKryfo => 'Dukung Kryfo';

  @override
  String get profileKryfoRunsOnWhat => 'Kryfo hidup dari pemberian orang';

  @override
  String get profileKeepKryfoIndependent => 'Jaga Kryfo tetap mandiri';

  @override
  String get qrLink => 'Tautan';

  @override
  String get qrYourLinkAsTyped =>
      'Tautanmu apa adanya · tanpa pengalihan pelacak';

  @override
  String get qrText => 'Teks';

  @override
  String get qrStaysInTheCode =>
      'Tetap di dalam kode · tidak ada server yang menyimpannya';

  @override
  String get qrWiFi => 'Wi-Fi';

  @override
  String get qrMadeOnThisPhone =>
      'Dibuat di ponsel ini · tidak ada situs yang melihat kata sandinya';

  @override
  String get qrMadeOnThisPhoneDesk =>
      'Dibuat di komputer ini · tidak ada situs yang melihat kata sandinya';

  @override
  String get qrNetworkName => 'Nama jaringan';

  @override
  String get qrPassword => 'Kata sandi';

  @override
  String get qrContact => 'Kontak';

  @override
  String get qrOnlyWhatYouType =>
      'Hanya yang kamu ketik · tidak ada dari kontakmu';

  @override
  String get qrName => 'Nama';

  @override
  String get qrPhone => 'Telepon';

  @override
  String get qrEmail => 'Email';

  @override
  String get qrOpensTheirMailApp =>
      'Membuka aplikasi email-nya · tidak ada yang dikirim dari sini';

  @override
  String get qrTo => 'Kepada';

  @override
  String get qrSubject => 'Subjek';

  @override
  String get qrANumberNothingElse => 'Sebuah nomor · tidak lebih';

  @override
  String get qrNumber => 'Nomor';

  @override
  String get qrSms => 'SMS';

  @override
  String get qrOpensTheirMessagesApp =>
      'Membuka aplikasi pesannya · tidak ada yang dikirim dari sini';

  @override
  String get qrMessage => 'Pesan';

  @override
  String get qrLocation => 'Lokasi';

  @override
  String get qrCoordinatesOnlyNoMap =>
      'Hanya koordinat · tanpa bertanya ke layanan peta';

  @override
  String get qrLatitude => 'Lintang';

  @override
  String get qrLongitude => 'Bujur';

  @override
  String get qrBitcoin => 'Bitcoin';

  @override
  String get qrAddressAndAmountNo =>
      'Alamat dan jumlah · tanpa situs pembayaran di tengah';

  @override
  String get qrAddress => 'Alamat';

  @override
  String get qrAmountInBtc => 'Jumlah dalam BTC';

  @override
  String get qrInk => 'Tinta';

  @override
  String get qrAmber => 'Ambar';

  @override
  String get qrViolet => 'Ungu';

  @override
  String get qrCouldNotDrawThe => 'Gagal membuat gambarnya.';

  @override
  String get qrSavedToYourGallery => 'Disimpan ke galerimu';

  @override
  String get qrCouldNotSaveIt =>
      'Gagal menyimpannya. Pastikan ponsel masih punya ruang.';

  @override
  String get qrCouldNotSaveItDesk =>
      'Gagal menyimpannya. Pastikan komputer masih punya ruang.';

  @override
  String get qrNoAppOnThis =>
      'Tidak ada aplikasi di ponsel ini yang menerima gambar itu.';

  @override
  String get qrTooMuchForOne =>
      'Terlalu banyak untuk satu kode. Buat lebih pendek.';

  @override
  String get qrThisIsALot =>
      'Ini cukup banyak untuk satu kode. Kamera lama mungkin tidak bisa membacanya.';

  @override
  String get qrPrivateQrCode => 'Kode QR privat';

  @override
  String get qrColour => 'Warna';

  @override
  String get qrCopiedItLeavesThe =>
      'Disalin. Akan hilang dari papan klip dalam semenit';

  @override
  String get qrSecurity => 'Keamanan';

  @override
  String get qrNone => 'Tidak ada';

  @override
  String get qrSaveImage => 'Simpan gambar';

  @override
  String qrColour2(Object name) {
    return 'Warna $name';
  }

  @override
  String get qrTypeBelowAndThe =>
      'Ketik di bawah dan\nkodenya tergambar sendiri';

  @override
  String get qrQrCode => 'Kode QR';

  @override
  String get qrHidePassword => 'Sembunyikan kata sandi';

  @override
  String get qrShowPassword => 'Tampilkan kata sandi';

  @override
  String get qrCopyPassword => 'Salin kata sandi';

  @override
  String get requestsSentAnAttachment => 'Mengirim lampiran';

  @override
  String get requestsWantsToConnect => 'Ingin terhubung';

  @override
  String get requestsAccepted => 'Diterima';

  @override
  String requestsBlock(Object id) {
    return 'Blokir $id?';
  }

  @override
  String get requestsNothingMoreFromThem =>
      'Tidak ada lagi darinya yang sampai ke kamu. Permintaan dan pesan-pesannya dihapus.';

  @override
  String get requestsRequests => 'Permintaan';

  @override
  String get requestsNoRequests => 'Tak ada permintaan';

  @override
  String get requestsMessagesFromPeopleYou =>
      'Pesan dari orang yang belum kamu tambahkan muncul di sini dulu.';

  @override
  String get commonAccept => 'Terima';

  @override
  String get requestsDecline => 'Tolak';

  @override
  String get restoreThatFileIsNot => 'File itu bukan cadangan Kryfo';

  @override
  String get restoreThisFileIsDamaged => 'File ini rusak dan tidak bisa dibaca';

  @override
  String get restoreTypeThePassphraseThe =>
      'Ketik frasa sandi yang dipakai saat file ini dibuat';

  @override
  String get restoreReplaceTheAccountOn => 'Ganti akun di ponsel ini?';

  @override
  String get restoreReplaceTheAccountOnDesk => 'Ganti akun di komputer ini?';

  @override
  String get restoreWhatIsHereNow =>
      'Yang ada di sini sekarang, identitas, kontak, dan pesannya, akan hilang. File ini menggantikannya. Ini tidak bisa dibatalkan.';

  @override
  String get restoreReplaceIt => 'Ganti';

  @override
  String restoreCouldNotBeReleased(Object mine) {
    return '@$mine tidak bisa dilepas';
  }

  @override
  String restoreTheRegistryDidNot(Object mine) {
    return 'Registri tidak menjawab. Kalau kamu lanjut, @$mine tetap mengarah ke identitas yang akan hilang dari ponsel ini. Siapa pun yang menambahkannya akan mengirim pesan ke tak seorang pun, dan nama itu tidak bisa diklaim lagi. Lebih baik sambungkan ke internet dan coba sekali lagi.';
  }

  @override
  String restoreTheRegistryDidNotDesk(Object mine) {
    return 'Registri tidak menjawab. Kalau kamu lanjut, @$mine tetap mengarah ke identitas yang akan hilang dari komputer ini. Siapa pun yang menambahkannya akan mengirim pesan ke tak seorang pun, dan nama itu tidak bisa diklaim lagi. Lebih baik sambungkan ke internet dan coba sekali lagi.';
  }

  @override
  String get restoreRestoreAnyway => 'Tetap pulihkan';

  @override
  String get restoreNotYet => 'Belum';

  @override
  String get restoreRestored => 'Dipulihkan';

  @override
  String restoreKryfoWillCloseNow(Object haloId) {
    return 'Kryfo akan ditutup sekarang. Ketuk ikonnya untuk membuka lagi sebagai $haloId.';
  }

  @override
  String restoreKryfoWillCloseNowDesk(Object haloId) {
    return 'Kryfo akan ditutup sekarang. Jalankan lagi untuk membukanya sebagai $haloId.';
  }

  @override
  String get restorePrivacyKept =>
      'Pengaturan privasimu ikut kembali bersama cadangan. PIN tidak pernah ikut pindah: atur lagi di Pengaturan.';

  @override
  String get restoreCheckProtections =>
      'Pengaturan tidak ikut dalam cadangan. Setelah Kryfo terbuka lagi, periksa Perlindunganmu di Pengaturan.';

  @override
  String get restoreReopenKryfo => 'Buka lagi Kryfo';

  @override
  String get restoreTheRestoreDidNot =>
      'Pemulihan tidak selesai. Tidak ada yang diubah';

  @override
  String get restoreKryfoClosesRestoreAgain =>
      'Sebagian data di sini sudah diganti. Kryfo akan ditutup sekarang. Buka lagi dan pulihkan file itu sekali lagi.';

  @override
  String get restoreThisIdentity => 'identitas ini';

  @override
  String get restoreMoveYourKryfoHere => 'Pindahkan Kryfo-mu ke sini';

  @override
  String restoreThisBackupIsRestoring(Object name) {
    return 'Cadangan ini berisi $name. Memulihkannya memindahkan identitas itu ke perangkat ini.';
  }

  @override
  String restoreThisBackupMadeOn(Object name, Object date, Object time) {
    return 'Cadangan ini berisi $name, dibuat pada $date pukul $time. Memulihkannya memindahkan identitas itu ke perangkat ini.';
  }

  @override
  String restoreItHoldsOfPhotos(Object mb) {
    return 'Isinya $mb foto, pesan suara, dan file. Ini mungkin butuh beberapa menit. Biarkan aplikasi terbuka.';
  }

  @override
  String get restoreWhatFollows => 'Yang ikut';

  @override
  String get restoreYourNameYourCode => 'Namamu, kodemu, dan semua kontak.';

  @override
  String get restoreEveryConversationBackTo =>
      'Semua obrolan, sampai yang paling awal.';

  @override
  String get restoreYourPhotosVoiceNotes => 'Foto, pesan suara, dan file-mu.';

  @override
  String restoreYourPhotosVoiceNotesCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Foto, pesan suara, dan file-mu · $countString.',
    );
    return '$_temp0';
  }

  @override
  String get restoreYourOnionAddressSo =>
      'Alamat onion-mu, jadi orang yang menghubungimu secara langsung tetap bisa menghubungimu.';

  @override
  String get restoreAnythingSentToYou =>
      'Apa pun yang dikirim ke kamu saat ponsel lama mati, selama empat belas hari setelah dikirim.';

  @override
  String get restoreAnythingSentToYouDesk =>
      'Apa pun yang dikirim ke kamu saat perangkat lama mati, selama empat belas hari setelah dikirim.';

  @override
  String get restoreYourSupporterBadgeIf =>
      'Lencana pendukungmu, kalau kamu punya.';

  @override
  String get restoreWhatDoesnT => 'Yang tidak ikut';

  @override
  String get restoreTheOldPhoneStops =>
      'Ponsel lama berhenti menerima begitu kamu mengirim apa pun dari sini. Pesan pertama yang kamu kirim dari perangkat ini adalah pesan terakhir yang bisa diikuti ponsel lama, dan apa pun yang sampai ke sana setelah itu tidak bisa dibaca di sana dan juga tidak menunggumu di sini.';

  @override
  String get restoreTheOldPhoneStopsDesk =>
      'Perangkat lama berhenti menerima begitu kamu mengirim apa pun dari sini. Pesan pertama yang kamu kirim dari komputer ini adalah pesan terakhir yang bisa diikuti perangkat lama, dan apa pun yang sampai ke sana setelah itu tidak bisa dibaca di sana dan juga tidak menunggumu di sini.';

  @override
  String get restoreIfThePhoneThis =>
      'Kalau ponsel asal file ini masih dipakai, berhenti memakai Kryfo di sana sebelum kamu lanjut. Dua ponsel dengan satu Kryfo kehilangan pesan di keduanya.';

  @override
  String get restoreIfThePhoneThisDesk =>
      'Kalau perangkat asal file ini masih dipakai, berhenti memakai Kryfo di sana sebelum kamu lanjut. Dua perangkat dengan satu Kryfo kehilangan pesan di keduanya.';

  @override
  String get restoreNotificationsNeedSettingUp =>
      'Notifikasi perlu diatur ulang di perangkat ini.';

  @override
  String get restoreDeletedComeBack =>
      'Obrolan yang kamu hapus setelah cadangan ini dibuat kembali bersamanya, dan kontak itu mungkin melihat bahwa kamu memasang Kryfo lagi.';

  @override
  String get restoreMoveItHere => 'Pindahkan ke sini';

  @override
  String get restoreNotNow => 'Nanti saja';

  @override
  String get restoreRestore => 'Pulihkan';

  @override
  String get restoreFromABackupFile => 'Dari file cadangan';

  @override
  String get restoreABackupBringsBack =>
      'Cadangan mengembalikan identitas dan kontakmu, serta pesan yang ada di ponsel saat file dibuat. Apa pun yang dikirim setelahnya tidak ada di dalamnya.';

  @override
  String get restoreABackupBringsBackDesk =>
      'Cadangan mengembalikan identitas dan kontakmu, serta pesan yang ada di perangkat saat file dibuat. Apa pun yang dikirim setelahnya tidak ada di dalamnya.';

  @override
  String get restoreTheFile => 'File-nya';

  @override
  String get restorePickTheBackupFile => 'Pilih file cadangan';

  @override
  String get restoreThePassphrase => 'Frasa sandinya';

  @override
  String get restoreTheOneTheFile => 'Yang dipakai saat file dibuat';

  @override
  String get restoreWhatComesBack => 'Yang kembali';

  @override
  String get restoreChecking => 'Mengecek…';

  @override
  String get restoreCheckTheFile => 'Cek file';

  @override
  String get restoreReleasingYourHandle => 'Melepas nama penggunamu…';

  @override
  String restoreMoving(Object progress) {
    return 'Memindahkan… $progress';
  }

  @override
  String get restoreRestoring => 'Memulihkan…';

  @override
  String get restoreNotThisOne => 'Bukan yang ini';

  @override
  String get restoreStopRestore => 'Hentikan pemulihan';

  @override
  String get restoreDateUnknown => 'Tanggal tak dikenal';

  @override
  String get restoreAnIdentity => 'Sebuah identitas';

  @override
  String get restoreMessagesSentOrReceived =>
      'Pesan yang dikirim atau diterima setelah tanggal itu tidak ada di file ini.';

  @override
  String restoreGb(Object bytes) {
    return '$bytes GB';
  }

  @override
  String restoreMb(Object bytes) {
    return '$bytes MB';
  }

  @override
  String get roomCreateCouldNotCreateThe => 'Gagal membuat ruang';

  @override
  String get roomCreateBurnerRoom => 'Ruang sekali pakai';

  @override
  String get roomCreateARoomThatEnds =>
      'Ruang yang punya akhir. Semua orang bergabung dengan kunci yang dibuat khusus untuknya, dan saat berakhir tidak ada yang tersisa di ponsel mana pun.';

  @override
  String get roomCreateARoomThatEndsDesk =>
      'Ruang yang punya akhir. Semua orang bergabung dengan kunci yang dibuat khusus untuknya, dan saat berakhir tidak ada yang tersisa di perangkat mana pun.';

  @override
  String get roomCreateRoomName => 'Nama ruang';

  @override
  String get roomCreateEndsAfter => 'Berakhir setelah';

  @override
  String get roomCreateMemberCap => 'Batas anggota';

  @override
  String roomCreateNoOnePastThe(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tidak ada yang masuk setelah $countString orang pertama',
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
      other: 'Mati. Siapa pun yang punya tautannya, paling banyak $countString',
    );
    return '$_temp0';
  }

  @override
  String roomCreateThisRoomAndEverything(Object expiryWords) {
    return 'Ruang ini dan semua isinya hilang dalam $expiryWords';
  }

  @override
  String get roomCreateCreating => 'Membuat...';

  @override
  String get roomCreateCreateRoom => 'Buat ruang';

  @override
  String get roomLinkSendTheRoomTo => 'Kirim ruang ke';

  @override
  String get roomLinkTheyWillKnowThis =>
      'Dia akan tahu ruang ini darimu. Di dalamnya, dia hanya sebuah kunci seperti yang lain.';

  @override
  String get roomLinkNoContactsYet => 'Belum ada kontak';

  @override
  String roomLinkEndsIn(Object time) {
    return 'Berakhir dalam $time';
  }

  @override
  String get roomLinkAnyoneWithThisCan =>
      'Siapa pun yang punya ini bisa bergabung sampai ruang berakhir. Mereka masuk dengan kunci yang dibuat khusus untuk ruang ini, dan tidak melihat apa pun yang dikirim sebelum mereka datang.';

  @override
  String get roomLinkRoomLinkCopied => 'Tautan ruang disalin';

  @override
  String get roomLinkSendToAContact => 'Kirim ke kontak';

  @override
  String get roomLinkCopyRoomLink => 'Salin tautan ruang';

  @override
  String get savedVoiceNote => 'Pesan suara';

  @override
  String get savedPhoto => 'Foto';

  @override
  String get savedSaved => 'Tersimpan';

  @override
  String get savedNothingSavedYet => 'Belum ada yang disimpan';

  @override
  String get savedChatGone => 'Obrolan itu sudah tidak ada di ponsel ini';

  @override
  String get savedChatGoneDesk => 'Obrolan itu sudah tidak ada di komputer ini';

  @override
  String get savedLongPressAnyMessage =>
      'Tekan lama pesan mana pun lalu ketuk simpan untuk menyimpannya di sini.';

  @override
  String get savedViewInChat => 'Lihat di obrolan';

  @override
  String get savedPhoto2 => 'Foto';

  @override
  String get scanThatSNotA => 'Itu bukan QR Kryfo · terus arahkan';

  @override
  String get scanScanAKryfoQr => 'Pindai QR Kryfo';

  @override
  String get scanFlash => 'Lampu kilat';

  @override
  String get scanPointAtAKryfo =>
      'Arahkan ke QR Kryfo · tidak ada yang keluar dari ponselmu';

  @override
  String get seenWhatWeCanSee => 'Apa yang bisa kami lihat';

  @override
  String get seenEveryMessengerClaimsPrivacy =>
      'Ini daftarnya, per jalur, termasuk titik lemahnya. Ketuk baris untuk tahu alasannya.';

  @override
  String get seenHonestAboutTheLast =>
      'Untuk baris terakhir itulah ada kunci aplikasi, PIN penghapus, dan penyimpanan terenkripsi, dan tidak ada alat yang bisa menyelamatkanmu dari orang yang memegang ponselmu dalam keadaan terbuka. Model ancaman lengkapnya ada di THREAT_MODEL.md di repo, disusun berdasarkan LINDDUN. Kodenya terbuka, jadi kamu bisa memeriksa semua ini sendiri.';

  @override
  String get seenHonestAboutTheLastDesk =>
      'Untuk baris terakhir itulah ada kunci aplikasi, PIN penghapus, dan penyimpanan terenkripsi, dan tidak ada alat yang bisa menyelamatkanmu dari orang yang duduk di depan komputermu yang tidak terkunci. Model ancaman lengkapnya ada di THREAT_MODEL.md di repo, disusun berdasarkan LINDDUN. Kodenya terbuka, jadi kamu bisa memeriksa semua ini sendiri.';

  @override
  String get seenHidden => 'Tak tampak';

  @override
  String get seenNever => 'Tak pernah';

  @override
  String get seenOnDevice => 'Di perangkat';

  @override
  String get seenYours => 'Milikmu';

  @override
  String get seenUnaudited => 'Belum diaudit';

  @override
  String get seenWhoYouTalkTo => 'Dengan siapa kamu bicara';

  @override
  String get seenEachConversationGetsIts =>
      'Setiap obrolan punya alamatnya sendiri, diturunkan dari kedua kunci. Relay hanya melihat kotak titipan yang tidak saling terkait, bukan sepasang orang. Di Cepat, server kami melihat alamat IP-mu pada kotak titipan yang kamu pakai, dan jika kedua orang dalam obrolan memakai Cepat, bahwa dua alamat IP berbagi satu kotak.';

  @override
  String get seenWhatYouSay => 'Isi pesanmu';

  @override
  String get seenEndToEndEncrypted =>
      'Terenkripsi ujung ke ujung dengan double ratchet Signal, lalu disegel lagi di dalam gift wrap. Kami tidak bisa membacanya.';

  @override
  String get seenYourIpAddress => 'Alamat IP-mu';

  @override
  String get seenYourContactGraph => 'Jaringan kontakmu';

  @override
  String get seenKryfoDoesNotScan =>
      'Kryfo tidak memindai kontakmu. Tidak ada nomor telepon di sini yang bisa bocor. Di Cepat, server kami bisa menyusun sebagian darinya dari alamat IP mana yang berbagi kotak titipan. Server kami tidak menyimpan catatannya.';

  @override
  String get seenIntroducer => 'Perantara';

  @override
  String get seenWhenAContactIntroduces =>
      'Saat kontak memperkenalkanmu ke seseorang, kontak itu tahu kalian berdua sekarang terhubung. Tidak ada orang lain yang tahu. Relay hanya melihat teks terenkripsi, dan tidak ada server yang pernah melihat jaringan kontaknya.';

  @override
  String get seenTheScamShield => 'Perisai penipuan';

  @override
  String get seenScamShieldRequestsOnly =>
      'Berjalan di ponselmu dengan aturan bawaan aplikasi. Tanpa jaringan, tanpa mengunduh daftar. Perisai ini hanya membaca permintaan pesan dari orang asing, tidak pernah yang dikirim kontak atau grup kepadamu.';

  @override
  String get seenScamShieldRequestsOnlyDesk =>
      'Berjalan di komputermu dengan aturan bawaan aplikasi. Tanpa jaringan, tanpa mengunduh daftar. Perisai ini hanya membaca permintaan pesan dari orang asing, tidak pernah yang dikirim kontak atau grup kepadamu.';

  @override
  String get seenBurnerRooms => 'Ruang sekali pakai';

  @override
  String get seenRoomKeys => 'Kunci ruang';

  @override
  String get seenYouJoinARoom =>
      'Kamu bergabung ke ruang dengan kunci yang dibuat khusus untuknya, jadi orang di dalamnya tidak mendapat apa pun yang berguna di tempat lain. Yang bergabung belakangan tidak mendapat riwayat. Saat kedaluwarsa, kunci, pesan, dan medianya dimusnahkan.';

  @override
  String get seenLinkPreviews => 'Pratinjau tautan';

  @override
  String get seenOverTor => 'Lewat Tor';

  @override
  String get seenAPreviewIsFetched =>
      'Pratinjau diambil oleh pengirim, lewat Tor, dan ikut di dalam pesan terenkripsi. Ponsel penerima tidak membuat permintaan apa pun. Situsnya hanya tahu bahwa seseorang yang memakai Tor meminta sebuah halaman, tidak lebih. Tidak ada gambar yang pernah dimuat, dan tautan dari orang asing tetap berupa teks biasa.';

  @override
  String get seenAPreviewIsFetchedDesk =>
      'Pratinjau diambil oleh pengirim, lewat Tor, dan ikut di dalam pesan terenkripsi. Perangkat penerima tidak membuat permintaan apa pun. Situsnya hanya tahu bahwa seseorang yang memakai Tor meminta sebuah halaman, tidak lebih. Tidak ada gambar yang pernah dimuat, dan tautan dari orang asing tetap berupa teks biasa.';

  @override
  String get seenASeizedUnlockedPhone => 'Ponsel tak terkunci yang disita';

  @override
  String get seenASeizedUnlockedPhoneDesk =>
      'Komputer tak terkunci yang disita';

  @override
  String get seenIfSomeoneHoldsYour =>
      'Kalau seseorang memegang ponselmu dalam keadaan terbuka, dia membaca pesanmu. Kunci aplikasi, PIN penghapus, dan penyimpanan terenkripsi membantu sebelum itu terjadi, bukan sesudahnya.';

  @override
  String get seenIfSomeoneHoldsYourDesk =>
      'Kalau seseorang duduk di depan komputermu yang tidak terkunci, dia membaca pesanmu. Kunci aplikasi, PIN penghapus, dan penyimpanan terenkripsi membantu sebelum itu terjadi, bukan sesudahnya.';

  @override
  String get seenTheCryptoItself => 'Kriptografinya sendiri';

  @override
  String get seenTheRatchetAndStorage =>
      'Lapisan ratchet dan penyimpanan memakai standar. Lapisan yang menyatukannya buatan kami dan belum ada pihak independen yang memeriksanya. Ini perangkat lunak versi alfa.';

  @override
  String get seenFast => 'Cepat';

  @override
  String get settingsWipeKryfo => 'Hapus total Kryfo?';

  @override
  String get settingsIdentityMessagesContactsAnd =>
      'Identitas, pesan, kontak, dan pengaturan di ponsel ini. Hilang selamanya kecuali kamu punya cadangan.';

  @override
  String get settingsIdentityMessagesContactsAndDesk =>
      'Identitas, pesan, kontak, dan pengaturan di komputer ini. Hilang selamanya kecuali kamu punya cadangan.';

  @override
  String get commonContinue => 'Lanjut';

  @override
  String settingsTypeWipeToConfirm(Object word) {
    return 'Ketik “$word” untuk konfirmasi';
  }

  @override
  String get settingsTheLastStepNothing =>
      'Langkah terakhir. Tidak ada yang tersisa setelahnya.';

  @override
  String get settingsWipeWord => 'hapus';

  @override
  String get settingsWipeKryfo2 => 'Hapus total Kryfo';

  @override
  String get settingsYourProtections => 'Perlindunganmu';

  @override
  String get settingsTorRouting => 'Perutean Tor';

  @override
  String get settingsOffFastMode => 'Mati · mode cepat';

  @override
  String get settingsAppLock => 'Kunci aplikasi';

  @override
  String get settingsBlockedByAndroid => 'Diblokir Android';

  @override
  String get settingsSpeedPrivacy => 'Kecepatan & privasi';

  @override
  String get settingsFast => 'Cepat';

  @override
  String get settingsOnion3Hops => 'Onion · 3 lompatan';

  @override
  String settingsPreviewHidden(Object deliveryModeName) {
    return '$deliveryModeName · pratinjau disembunyikan';
  }

  @override
  String settingsPreviewShown(Object deliveryModeName) {
    return '$deliveryModeName · pratinjau ditampilkan';
  }

  @override
  String get settingsRunInBackground => 'Jalan di latar belakang';

  @override
  String get settingsSoMessagesArrive => 'Agar pesan tetap masuk';

  @override
  String get settingsTransport => 'Transport';

  @override
  String get settingsWhatTheNetworkIs => 'Apa yang sedang dilakukan jaringan';

  @override
  String get settingsBlocked => 'Diblokir';

  @override
  String get settingsAcceptIntroductions => 'Terima perkenalan';

  @override
  String get settingsFriendsCanIntroduceYou =>
      'Teman bisa memperkenalkanmu ke teman mereka';

  @override
  String get settingsScamShield => 'Perisai penipuan';

  @override
  String get settingsScamShieldHint =>
      'Diperiksa hanya di ponselmu, tidak ada yang keluar darinya';

  @override
  String get settingsScamShieldHintDesk =>
      'Diperiksa hanya di komputermu, tidak ada yang keluar darinya';

  @override
  String get typingNow => 'Mengetik';

  @override
  String get settingsTypingIndicator => 'Indikator mengetik';

  @override
  String get settingsTypingIndicatorHint =>
      'Kalian berdua melihat saat yang lain sedang mengetik. Sinyalnya langsung ke dia lewat Tor, tidak pernah melalui relay.';

  @override
  String get settingsTypingOnionOnly => 'Tersedia di rute Onion';

  @override
  String get settingsTypingBridgesOff =>
      'Mati selama jembatan dipakai: orang yang mengawasi koneksimu bisa mencocokkan sinyal mengetik. Menyala lagi sendiri saat jembatan dimatikan.';

  @override
  String get settingsLightTheme => 'Tema terang';

  @override
  String get settingsSameProtectionBrighter =>
      'Perlindungan sama, lebih terang';

  @override
  String get settingsAppearance => 'Tampilan';

  @override
  String get settingsAccentColour => 'Warna aksen';

  @override
  String get settingsColoursAndWallpaper => 'Warna dan latar belakang';

  @override
  String get settingsAppLock2 => 'Kunci aplikasi';

  @override
  String get settingsYourPinAndA => 'PIN-mu dan perlindungan lanjutan';

  @override
  String get settingsPinWipePin => 'PIN · PIN penghapus';

  @override
  String get settingsBackUpIdentity => 'Cadangkan identitas';

  @override
  String get settingsEncryptedFile => 'File terenkripsi';

  @override
  String get settingsRestoreFromBackup => 'Pulihkan dari cadangan';

  @override
  String get settingsReplaceCurrent => 'Ganti yang sekarang';

  @override
  String get settingsWhyKryfo => 'Kenapa Kryfo';

  @override
  String get settingsHowItProtectsYou => 'Cara Kryfo melindungimu';

  @override
  String get settingsResetMyInviteLink => 'Reset tautan undanganku';

  @override
  String get settingsOldLinksAndCodes =>
      'Tautan dan kode lama tidak berlaku lagi, untuk semua orang';

  @override
  String get settingsResetInviteLink => 'Reset tautan undangan?';

  @override
  String get settingsAnyoneWithAnOld =>
      'Siapa pun yang punya kode atau tautan lama tidak bisa lagi menghubungimu, lewat jalur mana pun. Orang yang punya tapi belum pernah memakainya akan butuh yang baru darimu. Kontak, obrolan, dan riwayat tetap ada.';

  @override
  String get settingsReset => 'Reset';

  @override
  String get settingsInviteResetShareThe =>
      'Undangan direset · bagikan kode baru';

  @override
  String get settingsWhatWeCanSee => 'Apa yang bisa kami lihat';

  @override
  String get settingsTheHonestList => 'Daftar yang jujur';

  @override
  String get settingsVersion => 'Versi';

  @override
  String get settingsReportAnIssue => 'Laporkan masalah';

  @override
  String get settingsReportInKryfo => 'Tulis di Kryfo';

  @override
  String get settingsReportInKryfoSub =>
      'Obrolan dengan Marios. Kamu bisa menulis secara anonim.';

  @override
  String get settingsReportByEmail => 'Kirim email';

  @override
  String get settingsReportByEmailSub =>
      'gnosiworks@proton.me, dari aplikasi email-mu';

  @override
  String get settingsBugOrSecurityFlaw => 'Bug atau celah keamanan';

  @override
  String get settingsOpenSource => 'Sumber terbuka';

  @override
  String get settingsLinkCopied => 'Tautan disalin';

  @override
  String get settingsTheOfflineMapIn =>
      'Peta offline di Alat digambar dari Natural Earth (domain publik). Nama kota dari GeoNames, geonames.org, dengan lisensi CC BY 4.0.';

  @override
  String get settingsNotIndependentlyAuditedPre =>
      'Belum diaudit secara independen. Alfa: cocok untuk uji coba, belum untuk penggunaan berisiko tinggi.';

  @override
  String get settingsFollowTitle => 'Ikuti GnosiWorks (pengembang)';

  @override
  String get settingsFollowBrowserNote =>
      'Terbuka di browser-mu, di luar Kryfo.';

  @override
  String get settingsFollowOpen => 'Buka';

  @override
  String settingsFollowOn(Object name) {
    return 'Ikuti di $name, di luar Kryfo';
  }

  @override
  String get settingsDangerZone => 'Zona bahaya';

  @override
  String get settingsWipeKryfoFromThis => 'Hapus total Kryfo dari ponsel ini';

  @override
  String get settingsWipeKryfoFromThisDesk =>
      'Hapus total Kryfo dari komputer ini';

  @override
  String get toolsMoreTools => 'Alat lainnya';

  @override
  String get toolsMakeAPrivateQr => 'Buat kode QR privat';

  @override
  String get toolsLinksWiFiContacts =>
      'Tautan, Wi-Fi, kontak, dan lainnya. Dibuat offline';

  @override
  String get toolsLockAFile => 'Kunci file';

  @override
  String get toolsWithAPasswordOpens =>
      'Dengan kata sandi. Bisa dibuka di mana saja dengan age';

  @override
  String get toolsOpenALockedFile => 'Buka file terkunci';

  @override
  String get toolsAnyAgeFileSomeone =>
      'File .age apa pun yang dikirim kepadamu';

  @override
  String get toolsWorksOfflineNoContacts =>
      'Jalan offline · tanpa perlu kontak';

  @override
  String get toolsUsefulFrom => 'Berguna sejak';

  @override
  String get toolsTheFirstMinute => 'menit pertama.';

  @override
  String get toolsEverythingHereHappensOn =>
      'Semua di sini terjadi di ponsel ini. Tidak ada yang diunggah, dan orang lain tidak perlu memakai Kryfo.';

  @override
  String get toolsEverythingHereHappensOnDesk =>
      'Semua di sini terjadi di komputer ini. Tidak ada yang diunggah, dan orang lain tidak perlu memakai Kryfo.';

  @override
  String get toolsPhotoCleaner => 'Pembersih foto';

  @override
  String get toolsRemovesHiddenInfo =>
      'Menghapus info tersembunyi (metadata) seperti tempat, waktu, dan model ponsel';

  @override
  String get toolsPickAPhotoAnd =>
      'Pilih foto atau video untuk melihat apa yang dibocorkannya, lalu hapus semuanya dengan satu ketukan. Kamu juga bisa membagikannya ke Kryfo dari galeri.';

  @override
  String get toolsPickAPhotoAndDesk =>
      'Pilih foto atau video untuk melihat apa yang dibocorkannya, lalu hapus semuanya dengan satu klik. Kamu juga bisa melepasnya di sini atau menempelkannya.';

  @override
  String get toolsPickAPhoto => 'Pilih foto';

  @override
  String get toolsVideo => 'Video';

  @override
  String get transportTransport => 'Transport';

  @override
  String get transportNothingHereLeavesThe =>
      'Tidak ada yang di sini keluar dari ponsel. Ini keadaan yang sama yang dipakai mesin untuk memutuskan apa yang harus dilakukan.';

  @override
  String get transportNothingHereLeavesTheDesk =>
      'Tidak ada yang di sini keluar dari komputer. Ini keadaan yang sama yang dipakai mesin untuk memutuskan apa yang harus dilakukan.';

  @override
  String get transportStayingAlive => 'Tetap hidup';

  @override
  String get transportCanSend => 'Bisa mengirim';

  @override
  String get commonYes => 'Ya';

  @override
  String get transportNotYet => 'Belum';

  @override
  String get transportOnline => 'Online';

  @override
  String get transportOffline => 'Offline';

  @override
  String get transportQueuedToSend => 'Antre untuk dikirim';

  @override
  String get transportOnionPublished => 'Onion diterbitkan';

  @override
  String transportYes(Object uploads) {
    return 'Ya ($uploads)';
  }

  @override
  String transportTryingS(Object pubFor) {
    return 'Mencoba $pubFor dtk';
  }

  @override
  String transportBenchedS(Object r) {
    return 'Rehat $r dtk';
  }

  @override
  String transportFails(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString gagal',
    );
    return '$_temp0';
  }

  @override
  String get transportOk => 'OK';

  @override
  String get transportRelaySubscriptions => 'Langganan relay';

  @override
  String get transportLastSent => 'Terakhir kirim';

  @override
  String get transportNever => 'Tidak pernah';

  @override
  String transportSAgo(Object sx) {
    return '$sx dtk lalu';
  }

  @override
  String get transportLastReceived => 'Terakhir terima';

  @override
  String transportSAgo2(Object rx) {
    return '$rx dtk lalu';
  }

  @override
  String get transportWithNoContactsThe =>
      'Tanpa kontak, aplikasi tidak berlangganan alamat relay apa pun, jadi tidak ada pesan yang bisa sampai ke kamu. Pindai seseorang untuk memperbaikinya.';

  @override
  String get transportWithNoContactsTheDesk =>
      'Tanpa kontak, aplikasi tidak berlangganan alamat relay apa pun, jadi tidak ada pesan yang bisa sampai ke kamu. Tambahkan seseorang untuk memperbaikinya.';

  @override
  String get transportSendAnythingWaitingNow =>
      'Kirim semua yang menunggu, sekarang';

  @override
  String get transportSending => 'Mengirim…';

  @override
  String get transportNothingLeftWaiting => 'Tidak ada lagi yang menunggu';

  @override
  String transportStillWaiting(Object count) {
    return 'Masih menunggu: $count';
  }

  @override
  String get transportOff => 'Mati';

  @override
  String get transportStarting => 'Memulai';

  @override
  String get transportBootstrapped => 'Bootstrap selesai';

  @override
  String get transportPublishingAddress => 'Menerbitkan alamat';

  @override
  String get transportReachable => 'Terjangkau';

  @override
  String get transportOurRelayOnion => 'Relay kami (onion)';

  @override
  String get transportNever2 => 'tidak pernah';

  @override
  String get transportJustNow => 'Baru saja';

  @override
  String transportMAgo(Object inMinutes) {
    return '$inMinutes mnt lalu';
  }

  @override
  String transportHAgo(Object inHours) {
    return '$inHours j lalu';
  }

  @override
  String transportDAgo(Object inDays) {
    return '$inDays hr lalu';
  }

  @override
  String transportM(Object inMinutes) {
    return '$inMinutes mnt';
  }

  @override
  String transportHM(Object inHours, Object d) {
    return '$inHours j $d mnt';
  }

  @override
  String transportD(Object inDays) {
    return '$inDays hr';
  }

  @override
  String transportMb(Object b) {
    return '$b MB';
  }

  @override
  String get transportYesCheckedJustNow => 'Ya · baru saja dicek';

  @override
  String transportNoLast(Object ago) {
    return 'Tidak · terakhir $ago';
  }

  @override
  String get transportLastMessageIn => 'Pesan masuk terakhir';

  @override
  String get transportBatteryExemption => 'Pengecualian baterai';

  @override
  String get transportUnknown => 'Tidak diketahui';

  @override
  String get transportExempt => 'Dikecualikan';

  @override
  String get transportNotExemptTapTo => 'Tak dikecualikan · ketuk perbaiki';

  @override
  String get transportProcessUp => 'Proses hidup';

  @override
  String get transportLastStop => 'Berhenti terakhir';

  @override
  String get transportStopKilled => 'Dihentikan paksa oleh sistem';

  @override
  String get transportStopLowMemory => 'Memori rendah';

  @override
  String get transportStopCrashed => 'Mogok';

  @override
  String get transportStopNotResponding => 'Tidak merespons';

  @override
  String get transportStopByYou => 'Dihentikan olehmu';

  @override
  String get transportStopByPhone => 'Dihentikan oleh ponsel';

  @override
  String get transportStopBySecurityApp => 'Dihentikan oleh aplikasi keamanan';

  @override
  String get transportStopUpdated => 'Diperbarui';

  @override
  String get transportStopBySystem => 'Dihentikan oleh sistem';

  @override
  String get transportStopTooMuch => 'Memakai terlalu banyak';

  @override
  String get transportStopPermission => 'Izin berubah';

  @override
  String get transportStopClosedItself => 'Tertutup sendiri';

  @override
  String get transportStopOther => 'Berhenti';

  @override
  String transportEngine(Object mb, Object mb2) {
    return '$mb · mesin $mb2';
  }

  @override
  String get transportLastRelayArrival => 'Terakhir masuk dari relay';

  @override
  String get transportLastCheckIn => 'Pengecekan terakhir';

  @override
  String get transportNoneYet => 'Belum ada';

  @override
  String get transportLastTorReconnect => 'Sambung ulang Tor terakhir';

  @override
  String get transportCatchUpByRelay => 'Susulan lewat relay';

  @override
  String get transportControlPort => 'Port kontrol';

  @override
  String get transportReconnects => 'Sambung ulang';

  @override
  String get transportWhyNetwork => 'Jaringan berganti';

  @override
  String get transportWhyHand => 'Manual';

  @override
  String get transportWhyRelays => 'Tidak ada relay yang menjawab';

  @override
  String get transportWhyStall => 'Awal macet';

  @override
  String get transportWhyTorOff => 'Tor mati';

  @override
  String get transportWhyDialer => 'Tidak ada relay selama 3 menit';

  @override
  String get transportWhyOnion => 'Kembali ke Onion';

  @override
  String get transportWhyBridges => 'Jembatan diganti';

  @override
  String get transportWhyAuto => 'Otomatis';

  @override
  String get transportWhyOffline => 'Tidak ada jaringan';

  @override
  String get transportWhyCircuits => 'Sirkuit baru';

  @override
  String get transportWhyOther => 'Lainnya';

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
      other: '$dialsString sambung',
    );
    String _temp1 = intl.Intl.pluralLogic(
      timeouts,
      locale: localeName,
      other: '$timeoutsString habis waktu',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get transportJobRuns => 'Tugas berjalan';

  @override
  String transportLast(Object jobRuns, Object ago) {
    return '$jobRuns · terakhir $ago';
  }

  @override
  String get transportQuietStretches => 'Periode sepi';

  @override
  String get transportNone => 'Tidak ada';

  @override
  String get transportClearThisRecord => 'Hapus catatan ini';

  @override
  String get transportNothingYetThisProcess => 'Belum ada di proses ini';

  @override
  String transportM2(Object mins) {
    return '$mins mnt';
  }

  @override
  String transportHM2(Object mins, Object mins2) {
    return '$mins j $mins2 mnt';
  }

  @override
  String transportTo(Object t, Object t2) {
    return '$t sampai $t2';
  }

  @override
  String vouchersVouchedBy(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Dijamin oleh $countString',
      one: 'Dijamin oleh',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperAtmosphere => 'Suasana';

  @override
  String get wallpaperJustForYouThey =>
      'Hanya untukmu. Dia melihat miliknya sendiri.';

  @override
  String get wallpaperYourPhoto => 'Fotomu';

  @override
  String get wallpaperDefault => 'Bawaan';

  @override
  String get wallpaperDim => 'Redupkan latar belakang';

  @override
  String get wallpaperNotSet => 'Latar belakang belum terpasang. Coba lagi.';

  @override
  String get wallpaperFromYourPhotos => 'Dari galerimu';

  @override
  String get wallpaperKeepIt => 'Simpan';

  @override
  String get whyKryfoWhyKryfo => 'Kenapa Kryfo';

  @override
  String get whyKryfoKryfoKreeFoGreek =>
      'Kryfo · KRI-fo · bahasa Yunani untuk tersembunyi.\nTempat tenang untuk bicara, dibuat agar tidak ada yang mengawasi.';

  @override
  String get whyKryfoRoutedThroughTor => 'Dirutekan lewat Tor';

  @override
  String get whyKryfoByDefaultEveryMessage =>
      'Secara bawaan setiap pesan berjalan lewat Tor, rangkaian relay. Tidak ada yang bisa melihat dengan siapa kamu bicara atau di mana kamu berada, baik kami maupun jaringanmu.';

  @override
  String get whyKryfoEndToEndEncrypted => 'Terenkripsi ujung ke ujung';

  @override
  String get whyKryfoMessagesAreSealedWith =>
      'Pesan disegel dengan kunci yang hanya dipegang kamu dan lawan bicaramu. Kami tidak bisa membacanya.';

  @override
  String get whyKryfoNoServersHoldingYour =>
      'Tidak ada server yang menyimpan hidupmu';

  @override
  String get whyKryfoNoAccountNoPhone =>
      'Tanpa akun, tanpa nomor telepon, tanpa server pusat yang menyimpan obrolanmu. Semuanya tinggal di ponsel ini, terenkripsi saat tersimpan.';

  @override
  String get whyKryfoNoAccountNoPhoneDesk =>
      'Tanpa akun, tanpa nomor telepon, tanpa server pusat yang menyimpan obrolanmu. Semuanya tinggal di komputer ini, terenkripsi saat tersimpan.';

  @override
  String get whyKryfoNothingLeaks => 'Tidak ada yang bocor';

  @override
  String get whyKryfoNoReceiptsTyping =>
      'Tanpa tanda dibaca, tanpa mengunggah daftar kontak. Bahwa kamu sedang mengetik hanya terlihat oleh orang yang kamu ajak bicara, langsung lewat Tor, tidak pernah melalui server. Kebanyakan aplikasi membocorkan metadata. Kryfo dibuat agar tidak begitu.';

  @override
  String get whyKryfoVerifyItIsReally => 'Pastikan itu benar-benar dia';

  @override
  String get whyKryfoCompareASafetyNumber =>
      'Bandingkan nomor keamanan secara tatap muka atau lewat saluran yang kamu percaya, agar kamu tahu tidak ada yang menyamar sebagai kontakmu.';

  @override
  String get whyKryfoTheHonestPart => 'Bagian jujurnya';

  @override
  String get whyKryfoKryfoIsPreAlpha =>
      'Kryfo masih alfa dan belum diaudit. Kriptografinya sungguhan, tapi belum ada pakar luar yang memeriksanya, jadi jangan dulu mengandalkannya jika keselamatanmu bergantung padanya.';

  @override
  String get cleanerLocation => 'Lokasi';

  @override
  String get cleanerAlreadyBlankedByAndroid => 'sudah dikosongkan oleh Android';

  @override
  String get cleanerPhoneModel => 'Model ponsel';

  @override
  String get cleanerTimeTaken => 'Waktu pengambilan';

  @override
  String get cleanerSerialNumber => 'Nomor seri';

  @override
  String get cleanerOwnerName => 'Nama pemilik';

  @override
  String get cleanerHiddenThumbnail => 'Miniatur tersembunyi';

  @override
  String get cleanerContentCredentials => 'Kredensial konten';

  @override
  String get cleanerHdrLayer => 'Lapisan HDR';

  @override
  String get cleanerDataAfterThePicture => 'Data setelah gambar';

  @override
  String cleaner1OtherField(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString kolom lain',
    );
    return '$_temp0';
  }

  @override
  String get lockWordsFourRandomWordsBeat =>
      'Empat kata acak lebih kuat daripada satu kata yang cerdik.';

  @override
  String lockWordsTooShortAtLeast(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Terlalu pendek. Minimal $countString karakter.',
    );
    return '$_temp0';
  }

  @override
  String get lockWordsWeakWhoeverGetsThe =>
      'Lemah. Siapa pun yang mendapat file ini bisa menebak secepat yang dia mau.';

  @override
  String get lockWordsFairLongerIsStronger =>
      'Lumayan. Makin panjang makin kuat.';

  @override
  String get lockWordsStrongFourRandomWords =>
      'Kuat. Empat kata acak lebih kuat daripada satu kata yang cerdik.';

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
      other: '$countString meter',
    );
    return '$_temp0';
  }

  @override
  String get photoStoryFarFromAnyTown => 'Jauh dari kota mana pun';

  @override
  String photoStoryNear(Object where) {
    return 'Dekat $where';
  }

  @override
  String photoStoryAboutKmFrom(Object near, Object where) {
    return 'Sekitar $near km dari $where';
  }

  @override
  String photoStoryS(Object s) {
    return '$s s';
  }

  @override
  String photoStory1S(Object s) {
    return '1/$s s';
  }

  @override
  String get photoStoryNotAKindKryfo => 'Bukan jenis yang bisa dibaca Kryfo.';

  @override
  String get photoStorySoItWillNot => 'Jadi Kryfo tidak akan menebak.';

  @override
  String get photoStoryThisFileIsDamaged => 'File ini rusak atau terpotong.';

  @override
  String get photoStoryKryfoCouldNotRead =>
      'Kryfo tidak bisa membacanya sampai habis.';

  @override
  String get photoStoryWhereItWasRecorded => 'Tempat direkam';

  @override
  String get photoStoryWhereItWasTaken => 'Tempat diambil';

  @override
  String photoStoryLocation(Object coordsLine) {
    return 'Lokasi: $coordsLine';
  }

  @override
  String photoStoryHeightAboveTheSea(Object fix) {
    return 'Ketinggian di atas laut: $fix m';
  }

  @override
  String get photoStoryLocationHiddenByAndroid =>
      'Lokasi disembunyikan oleh Android';

  @override
  String get photoStoryAndroidBlanksItWhen =>
      'Android mengosongkannya saat foto dipilih dengan cara ini. Membagikannya ke Kryfo dari galeri sering kali mempertahankannya. Foto yang ada di galerimu mungkin masih menyimpannya.';

  @override
  String get photoStoryLocationBlankedByAndroid =>
      'Lokasi: dikosongkan oleh Android sebelum Kryfo melihatnya';

  @override
  String photoStoryF(Object r) {
    return 'f/$r';
  }

  @override
  String get photoStoryWhatTookIt => 'Diambil dengan';

  @override
  String photoStoryPhoneOrCamera(Object phone) {
    return 'Ponsel atau kamera: $phone';
  }

  @override
  String get photoStoryWhenItWasRecorded => 'Waktu direkam';

  @override
  String get photoStoryToTheSecondWith =>
      'Sampai hitungan detik, dengan zona waktu';

  @override
  String get photoStoryToTheSecond => 'Sampai hitungan detik';

  @override
  String photoStoryTime(Object dateFormat) {
    return 'Waktu: $dateFormat';
  }

  @override
  String get photoStoryLens => 'Lensa';

  @override
  String photoStoryLens2(Object lens) {
    return 'Lensa: $lens';
  }

  @override
  String get photoStorySoftware => 'Perangkat lunak';

  @override
  String photoStorySoftware2(Object software) {
    return 'Perangkat lunak: $software';
  }

  @override
  String get photoStorySerialNumber => 'Nomor seri';

  @override
  String photoStorySerialNumber2(Object serial) {
    return 'Nomor seri: $serial';
  }

  @override
  String get photoStoryOwnerName => 'Nama pemilik';

  @override
  String photoStoryOwner(Object r) {
    return 'Pemilik: $r';
  }

  @override
  String get photoStoryHiddenThumbnail => 'Miniatur tersembunyi';

  @override
  String get photoStoryASmallCopyOf =>
      'Salinan kecil gambar di dalam file. Bisa menunjukkan bagian yang sudah dipotong';

  @override
  String get photoStoryMakerNotes => 'Catatan produsen';

  @override
  String get photoStoryMakerNotesABlock =>
      'Catatan produsen: blok yang hanya bisa dibaca produsennya';

  @override
  String get photoStoryEditingHistory => 'Riwayat edit';

  @override
  String get photoStoryXmpEditingHistoryAnd => 'XMP: riwayat edit dan tag';

  @override
  String get photoStoryCaptions => 'Keterangan';

  @override
  String get photoStoryIptcCaptionsAndCredits => 'IPTC: keterangan dan kredit';

  @override
  String get photoStoryComment => 'Komentar';

  @override
  String get photoStoryAWrittenComment => 'Komentar tertulis';

  @override
  String get photoStoryContentCredentials => 'Kredensial konten';

  @override
  String get photoStorySecondPicture => 'Gambar kedua';

  @override
  String get photoStoryASecondPictureInside => 'Gambar kedua di dalam file';

  @override
  String get photoStoryMotionVideo => 'Video gerak';

  @override
  String get photoStoryAShortVideoInside => 'Video pendek di dalam file';

  @override
  String get photoStorySaveTime => 'Waktu simpan';

  @override
  String get photoStoryTheTimeItWas => 'Waktu terakhir disimpan';

  @override
  String get photoStoryTimeStamps => 'Stempel waktu';

  @override
  String get photoStoryCreationTimeStamps => 'Stempel waktu pembuatan';

  @override
  String get photoStoryDataAfterThePicture => 'Data setelah gambar';

  @override
  String photoStoryDataAfterTheEnd(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Data setelah akhir gambar: $countString byte',
    );
    return '$_temp0';
  }

  @override
  String photoStoryTextField(Object k) {
    return 'Kolom teks: $k';
  }

  @override
  String photoStoryVideoTag(Object k) {
    return 'Tag video: $k';
  }

  @override
  String photoStoryAlso(Object k) {
    return 'Juga: $k';
  }

  @override
  String photoStoryCameraSettingsFlashFocus(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString pengaturan kamera (lampu kilat, fokus, eksposur)',
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
      other: '$countString kolom lagi',
    );
    return '$_temp0';
  }

  @override
  String get photoStoryCameraSettings => 'Pengaturan kamera';

  @override
  String photoStoryAccurateToAbout(Object metres) {
    return 'Akurat sampai sekitar $metres.';
  }

  @override
  String get photoStoryEnoughToFindThe => 'Cukup untuk menemukan pintunya.';

  @override
  String get photoStoryEnoughToFindTheStreet =>
      'Cukup untuk menemukan jalannya.';

  @override
  String get photoStoryEnoughToFindTheArea =>
      'Cukup untuk menemukan daerahnya.';

  @override
  String get photoStoryItKnowsWhereYou => 'Ia tahu di mana kamu berada.';

  @override
  String get photoStoryDownToTheBuilding => 'Sampai ke gedungnya.';

  @override
  String get photoStoryAndroidHidTheLocation =>
      'Android menyembunyikan lokasinya.';

  @override
  String get photoStoryTheOriginalMayStill =>
      'Aslinya mungkin masih menyimpannya.';

  @override
  String get photoStoryNoLocationInThis => 'Tidak ada lokasi di yang ini.';

  @override
  String get photoStoryItStillSaysPlenty => 'Masih banyak yang diungkapkannya.';

  @override
  String get photoStoryThisOneKnowsNothing => 'Yang ini tidak tahu apa-apa.';

  @override
  String get photoStoryNothingToRemove => 'Tak ada yang perlu dihapus.';

  @override
  String get qrPayloadOpensALink => 'MEMBUKA TAUTAN';

  @override
  String qrPayloadOpens(Object host) {
    return 'MEMBUKA $host';
  }

  @override
  String get qrPayloadShowsANote => 'MENAMPILKAN CATATAN';

  @override
  String get qrPayloadScanToJoin => 'PINDAI UNTUK GABUNG';

  @override
  String qrPayloadScanToJoin2(Object oneLine) {
    return 'PINDAI UNTUK GABUNG · $oneLine';
  }

  @override
  String get qrPayloadANetworkNameIs => 'Nama jaringan maksimal 32 karakter.';

  @override
  String get qrPayloadAWiFiPassword => 'Kata sandi Wi-Fi minimal 8 karakter.';

  @override
  String get qrPayloadSavesAContact => 'MENYIMPAN KONTAK';

  @override
  String get qrPayloadWritesAnEmail => 'MENULIS EMAIL';

  @override
  String get qrPayloadThatDoesNotLook =>
      'Itu tidak tampak seperti alamat email.';

  @override
  String get qrPayloadCallsANumber => 'MENELEPON NOMOR';

  @override
  String get qrPayloadWritesAText => 'MENULIS SMS';

  @override
  String get qrPayloadOpensAMap => 'MEMBUKA PETA';

  @override
  String get qrPayloadLatitudeRunsFrom90 =>
      'Lintang dari -90 sampai 90, bujur dari -180 sampai 180.';

  @override
  String get qrPayloadPayThisAddress => 'BAYAR KE ALAMAT INI';

  @override
  String get qrPayloadABitcoinAddressIs =>
      'Alamat bitcoin hanya berisi huruf dan angka.';

  @override
  String get qrPayloadTheAmountIsIn =>
      'Jumlahnya dalam BTC, maksimal 8 desimal.';

  @override
  String vouchTextAnd(Object names, Object names2) {
    return '$names dan $names2';
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
      other: '$restString orang lain',
    );
    return '$names, $names2, dan $_temp0 yang kamu kenal';
  }

  @override
  String vouchTextVouchedBy(Object vouchNames) {
    return 'Dijamin oleh $vouchNames';
  }

  @override
  String vouchTextIntroducedBy(Object vouchNames) {
    return 'Diperkenalkan oleh $vouchNames';
  }

  @override
  String vouchTextThisSharesSAddress(Object a, Object b) {
    return 'Ini membagikan alamat $a ke $b';
  }

  @override
  String get bootFailedKryfoCouldNotStart => 'Kryfo gagal dimulai';

  @override
  String get bootFailedThisIsAFault =>
      'Ini kesalahan di perangkat ini, bukan jaringan. Tor tidak terlibat.';

  @override
  String get bootFailedKeysDidNotAnswer =>
      'Penyimpanan kunci di ponselmu berhenti merespons. Menutup lalu membuka lagi Kryfo biasanya menyelesaikannya.';

  @override
  String get bootFailedKeysDidNotAnswerDesk =>
      'Penyimpanan kunci di komputer ini berhenti merespons. Menutup lalu membuka lagi Kryfo biasanya menyelesaikannya.';

  @override
  String get bootFailedCloseAndReopen => 'Tutup dan buka lagi Kryfo';

  @override
  String get bootFailedStillStuck => 'Jika mencoba lagi tidak membantu';

  @override
  String get bootFailedRestoreBackup => 'Pulihkan cadangan';

  @override
  String get bootFailedStartFresh => 'Mulai dari awal';

  @override
  String get bootFailedStartFreshTitle => 'Mulai dari awal?';

  @override
  String get bootFailedStartFreshLine =>
      'Ini menghapus total semua yang disimpan Kryfo di ponsel ini: obrolan, kontak, media, obrolan tersembunyi, dan tiga katamu. File cadangan yang disimpan di tempat lain tidak tersentuh.';

  @override
  String get bootFailedStartFreshLineDesk =>
      'Ini menghapus total semua yang disimpan Kryfo di komputer ini: obrolan, kontak, media, obrolan tersembunyi, dan tiga katamu. File cadangan yang disimpan di tempat lain tidak tersentuh.';

  @override
  String get bootFailedStartFreshNext => 'Lanjut';

  @override
  String get bootFailedStartFreshSure => 'Hapus total semua di ponsel ini?';

  @override
  String get bootFailedStartFreshSureDesk =>
      'Hapus total semua di komputer ini?';

  @override
  String get bootFailedStartFreshSureLine =>
      'Ini tidak bisa dibatalkan. Kryfo tertutup dan terbuka lagi seperti baru dipasang.';

  @override
  String get bootFailedStartFreshYes => 'Hapus total dan mulai dari awal';

  @override
  String get kryfoLinkTextThatLinkIsNot => 'Tautan itu tidak bisa dibaca Kryfo';

  @override
  String kryfoLinkTextAdd(Object who) {
    return 'Tambahkan $who?';
  }

  @override
  String kryfoLinkTextThisIsAnInvite(Object who) {
    return 'Ini undangan untuk mengobrol dengan $who. Tambahkan hanya kalau kamu tahu dari mana tautan ini berasal.';
  }

  @override
  String get kryfoLinkTextAddThem => 'Tambahkan';

  @override
  String get kryfoLinkTextNotNow => 'Nanti saja';

  @override
  String kryfoLinkTextYouAlreadyHave(Object who) {
    return 'Kamu sudah punya $who';
  }

  @override
  String kryfoLinkTextSomeoneElse(Object who) {
    return 'Kamu menyebut seseorang di obrolanmu $who. Tautan ini dari orang lain. Tambahkan hanya kalau kamu tahu dari mana asalnya.';
  }

  @override
  String kryfoLinkTextJoin(Object roomName) {
    return 'Gabung ke $roomName';
  }

  @override
  String get kryfoLinkTextKryfoLink => 'Tautan Kryfo';

  @override
  String kryfoLinkTextAdd2(Object who) {
    return 'Tambahkan $who';
  }

  @override
  String get kryfoLinkTextBurnerRoom => 'Ruang sekali pakai';

  @override
  String get kryfoLinkTextThisRoomHasClosed => 'Ruang ini sudah ditutup';

  @override
  String kryfoLinkTextClosesIn(Object time) {
    return 'Ditutup dalam $time';
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
      other: 'Ditutup dalam $time · maks $capString orang',
    );
    return '$_temp0';
  }

  @override
  String get kryfoLinkTextJoin2 => 'Gabung';

  @override
  String get kryfoLinkTextYouJoinUnderA =>
      'Kamu bergabung dengan kunci yang dibuat khusus untuk ruang ini. Tidak ada seorang pun di dalamnya yang melihat tiga katamu.';

  @override
  String get linkStubFetchedOverTorBy => 'Diambil lewat Tor · oleh perangkatmu';

  @override
  String get linkStubFetchedOverTorByTheirDevice =>
      'Diambil lewat Tor · oleh perangkatnya';

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
  String get mediaBubblesFile => 'FILE';

  @override
  String get mediaBubblesAudioUnavailable => 'Audio tidak tersedia';

  @override
  String get mediaBubblesHidden => 'Disamarkan';

  @override
  String get mediaBubblesPlaying => 'Sedang diputar';

  @override
  String get mediaBubblesSendPhoto => 'Kirim foto';

  @override
  String get mediaBubblesAddACaption => 'Tambah keterangan…';

  @override
  String get motionStandby => 'SIAGA';

  @override
  String get motionConnecting => 'MENGHUBUNGKAN';

  @override
  String get motionBuilding => 'MEMBANGUN';

  @override
  String get motionPublishing => 'MENERBITKAN';

  @override
  String get motionReady => 'SIAP';

  @override
  String get motionPreparingToConnect => 'Bersiap terhubung';

  @override
  String get motionFindingAPrivatePath => 'Mencari jalur privat';

  @override
  String get motionCarvingThePath => 'Merintis jalur';

  @override
  String get motionAnnouncingYourArrival => 'Mengumumkan kedatanganmu';

  @override
  String get motionYouReAnonymous => 'Kamu anonim';

  @override
  String get motionReadyToChat => 'Siap mengobrol';

  @override
  String get motionTorIsStartingIn =>
      'Tor sedang dimulai di latar belakang. Grafik ini menyala seiring koneksi terbentuk.';

  @override
  String get motionMakingAFreshRoute => 'Membuat rute baru lewat relay anonim.';

  @override
  String get motionBouncingThroughRelaysSo =>
      'Memantul lewat relay-relay agar tidak ada yang bisa melacaknya kembali ke kamu.';

  @override
  String get motionTellingTheNetworkYou =>
      'Memberi tahu jaringan bahwa kamu online, tanpa mengungkap di mana.';

  @override
  String get motionYourIpIsHidden =>
      'IP-mu tersembunyi. Hanya orang yang punya Kryfo-mu yang bisa menghubungimu.';

  @override
  String get motionAddressFinishing =>
      'Pesan sudah bisa dikirim lewat Tor. Alamat pribadimu disiapkan di latar belakang.';

  @override
  String get motionBuilding2 => 'membangun';

  @override
  String get motionOpen => 'terbuka';

  @override
  String get motionLive => 'aktif';

  @override
  String motionCircuit(Object circuit) {
    return 'Sirkuit · *$circuit*';
  }

  @override
  String get motionDelivered => 'Diterima';

  @override
  String get motionSent => 'Terkirim';

  @override
  String get motion1Hop => '1 lompatan';

  @override
  String get motion3Hops => '3 lompatan';

  @override
  String get movedStripThisKryfoHasMoved =>
      'Kryfo ini sudah pindah ke perangkat lain. Tidak ada kiriman dari sini yang sampai ke siapa pun.';

  @override
  String get navBarChats => 'Obrolan';

  @override
  String get navBarTools => 'Alat';

  @override
  String get navBarSupport => 'Dukung';

  @override
  String get navBarMe => 'Aku';

  @override
  String get pairCodePanelPuttingYourInviteIn => 'Menyiapkan undanganmu';

  @override
  String get pairCodePanelYourInviteIsNot => 'Undanganmu belum siap';

  @override
  String get pairCodePanelWorking => 'Memproses';

  @override
  String get pairCodePanelBurned =>
      'Kode itu sudah hilang. Buat yang baru saat mereka siap.';

  @override
  String get pairCodePanelCodeCopied => 'Kode disalin';

  @override
  String pairCodePanelBurnsIn(Object mm, Object ss) {
    return 'Hilang dalam $mm:$ss';
  }

  @override
  String get pairCodePanelTheyTapAddChoose =>
      'Dia mengetuk tambah, memilih kode, lalu mengetik angka ini.';

  @override
  String pinsPinnedMessages(Object count) {
    return 'Pesan tersemat · $count';
  }

  @override
  String get pinsPinnedMessages2 => 'Pesan tersemat';

  @override
  String get pinsPhoto => 'Foto';

  @override
  String get pinsVoiceMessage => 'Pesan suara';

  @override
  String get pinsMessage => 'Pesan';

  @override
  String pinsToday(Object hm) {
    return 'Hari ini · $hm';
  }

  @override
  String get pinsPinned => 'Disematkan';

  @override
  String pinsOf(Object pinsLength, Object kMaxPins) {
    return '$pinsLength dari $kMaxPins';
  }

  @override
  String get pinsNothingPinnedHereYet =>
      'Belum ada yang disematkan di sini. Tahan sebuah pesan lalu pilih Sematkan, dan pesan itu menunggu di sini untuk semua orang di obrolan.';

  @override
  String get pinsJump => 'Lihat';

  @override
  String get pinsUnpin => 'Lepas sematan';

  @override
  String previewStripFetchedOverTor(Object domainOf) {
    return '$domainOf · diambil lewat Tor';
  }

  @override
  String get previewStripDropThePreview => 'Buang pratinjau';

  @override
  String get previewStripAddPreview => 'Tambah pratinjau';

  @override
  String get previewStripFetchingOverTor => 'Mengambil lewat Tor…';

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
  String get torBootSplashNoShortcutsNoTraces =>
      'Tanpa jalan pintas, tanpa jejak';

  @override
  String get torBootSplashTheNetworkThatKeeps =>
      'Jaringan yang menjaga privasimu sedang bersiap';

  @override
  String get torBootSplashMadeOnThisPhone =>
      'Dibuat di ponsel ini. Tidak ada yang dikirim ke mana pun.';

  @override
  String get torBootSplashMadeOnThisPhoneDesk =>
      'Dibuat di komputer ini. Tidak ada yang dikirim ke mana pun.';

  @override
  String get torBootSplashFirstLaunchTakesA =>
      'Pembukaan pertama butuh sebentar · hanya saat mulai';

  @override
  String get torBootSplashTakingLonger => 'Ini lebih lama dari biasanya';

  @override
  String get torBootSplashHopEntry => 'Masuk';

  @override
  String get torBootSplashHopMiddle => 'Tengah';

  @override
  String get torBootSplashHopExit => 'Keluar';

  @override
  String get videoBubbleNothingHereOpensThat =>
      'Tidak ada yang bisa membukanya di sini · dibagikan saja';

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
  String get notificationsChannelName => 'Pesan';

  @override
  String get cameraClose => 'Tutup';

  @override
  String get cameraFlash => 'Lampu kilat';

  @override
  String get cameraPhoto => 'Foto';

  @override
  String get cameraVideo => 'Video';

  @override
  String get cameraRetake => 'Ulangi';

  @override
  String get seenIntroductions => 'Perkenalan';

  @override
  String get donateAddress => 'Alamat';

  @override
  String get donateCopy => 'Salin';

  @override
  String get donateDone => 'Selesai';

  @override
  String get donateTierSupporter => 'Pendukung';

  @override
  String get donateTierPatron => 'Patron';

  @override
  String get donateTierGuardian => 'Penjaga';

  @override
  String get chatBlock => 'Blokir';

  @override
  String get chatDecline => 'Tolak';

  @override
  String get chatAccept => 'Terima';

  @override
  String get bridgesConnecting => 'Menghubungkan';

  @override
  String get restoreMade => 'Dibuat';

  @override
  String get restoreContacts => 'Kontak';

  @override
  String get restoreMessages => 'Pesan';

  @override
  String get restoreAttachments => 'Lampiran';

  @override
  String get restoreHiddenChats => 'Obrolan tersembunyi';

  @override
  String get restoreHiddenFollow =>
      'Obrolan tersembunyimu, dengan PIN obrolan tersembunyi baru yang akan kamu pilih di akhir.';

  @override
  String get restoreChooseHiddenPin =>
      'Cadangan ini memuat obrolan tersembunyi. Pilih PIN obrolan tersembunyi untuknya.';

  @override
  String get restoreHiddenLockFirst =>
      'Obrolan tersembunyi butuh kunci aplikasi, jadi Kryfo mendapat PIN sendiri lebih dulu.';

  @override
  String get profileIdentity => 'Identitas';

  @override
  String get avatarPickerShape => 'Bentuk';

  @override
  String get avatarPickerColour => 'Warna';

  @override
  String get avatarPickerTurn => 'Putar';

  @override
  String avatarPickerOption(String what, int n, int count) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$what, $nString dari $countString';
  }

  @override
  String get avatarPickerYourInitial => 'Inisialmu';

  @override
  String get transportStatus => 'Status';

  @override
  String get transportBootstrap => 'Bootstrap';

  @override
  String get transportNetwork => 'Jaringan';

  @override
  String get transportConnectivity => 'Konektivitas';

  @override
  String get transportRelays => 'Relay';

  @override
  String get transportTraffic => 'Lalu lintas';

  @override
  String get transportContacts => 'Kontak';

  @override
  String get transportKnown => 'Dikenal';

  @override
  String get transportListening => 'Mendengarkan';

  @override
  String get transportMemory => 'Memori';

  @override
  String get settingsConnected => 'Terhubung';

  @override
  String get settingsOn => 'Aktif';

  @override
  String get settingsOff => 'Mati';

  @override
  String get settingsNotifications => 'Notifikasi';

  @override
  String get settingsPrivacy => 'Privasi';

  @override
  String get settingsSecurity => 'Keamanan';

  @override
  String get settingsBackup => 'Cadangan';

  @override
  String get settingsProtectBackup => 'Cadangan';

  @override
  String get settingsBackupNotYet => 'Belum';

  @override
  String get settingsBackupToday => 'Hari ini';

  @override
  String get settingsBackupYesterday => 'Kemarin';

  @override
  String settingsBackupDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hari lalu',
    );
    return '$_temp0';
  }

  @override
  String get settingsVoice => 'Suara';

  @override
  String get settingsAbout => 'Tentang';

  @override
  String get wallpaperGradients => 'Gradasi';

  @override
  String get wallpaperPatterns => 'Pola';

  @override
  String get wallpaperMoods => 'Nuansa';

  @override
  String get confirmSheetKeep => 'Biarkan';

  @override
  String get confirmSheetSave => 'Simpan';

  @override
  String get confirmSheetCancel => 'Batal';

  @override
  String get bridgesFoundAVolunteer => 'Relawan ditemukan, menghubungkan';

  @override
  String get bridgesScanABridgeCode => 'Pindai kode jembatan';

  @override
  String get settingsBridgesForNetworksThat =>
      'Jembatan, untuk jaringan yang memblokir Tor';

  @override
  String get bridgesCouldNotReachTheTor => 'Tidak bisa menghubungi Tor Project';

  @override
  String get torBootSplashConnect => 'Hubungkan';

  @override
  String get bridgesOffline => 'Offline';

  @override
  String get bridgesNothingGotThrough => 'Tidak ada yang tembus';

  @override
  String get bridgesBridgeFromAFriend => 'Jembatan dari teman';

  @override
  String get bridgesKryfoCanAskThe =>
      'Kryfo bisa meminta jembatan ke Tor Project untuk menembus blokir itu.';

  @override
  String get bridgesNotNeededRightNow => 'Tidak perlu sekarang';

  @override
  String get bridgesBuiltInBridges => 'Jembatan bawaan';

  @override
  String get bridgesKryfoCanGetAround => 'Kryfo kini bisa menembus blokir Tor';

  @override
  String get bridgesThatSNotABridge => 'Itu bukan baris jembatan';

  @override
  String get transportBridgeError => 'Error terakhir';

  @override
  String get bridgesDirect => 'Langsung';

  @override
  String get bridgesAskingTheTorProject =>
      'Menanyakan ke Tor Project apa yang berhasil di sini…';

  @override
  String get bridgesNoneOfTheseAre =>
      'Tidak ada satu pun baris jembatan yang dimengerti Kryfo.';

  @override
  String get bridgesAutomatic => 'Otomatis';

  @override
  String get bridgesStraightToTor => 'Langsung ke Tor, tanpa perlu jembatan';

  @override
  String get bridgesKryfoConnectsAsSoon =>
      'Kryfo langsung terhubung begitu kamu online lagi.';

  @override
  String get bridgesMore => 'Selengkapnya';

  @override
  String bridgesTryingAnotherWayOf(String attempt, String attempts) {
    return 'Mencoba cara lain… ($attempt dari $attempts)';
  }

  @override
  String get bridgesLookingForAVolunteer => 'Mencari relawan';

  @override
  String get bridgesFastestWhereTorIsnt =>
      'Paling cepat kalau Tor tidak diblokir. Kryfo tidak pernah terhubung di luar Tor.';

  @override
  String get transportBridgePhase => 'Fase';

  @override
  String get bridgesAsleepBetweenCheckIns => 'Tidur di antara pengecekan';

  @override
  String get bridgesThroughABridge => 'Lewat jembatan';

  @override
  String get bridgesBuiltIn => 'bawaan';

  @override
  String get bridgesPasteOrScanALineDesk =>
      'Tempel baris dari Tor Project atau dari orang yang kamu percaya.';

  @override
  String get bridgesDetails => 'Detail';

  @override
  String get transportBridgeMode => 'Jembatan';

  @override
  String get bridgesYourBridgeCouldNot => 'Jembatanmu tidak bisa dimulai';

  @override
  String get bridgesKryfoStaysOfflineRather =>
      'Kryfo tetap offline daripada terhubung tanpanya.';

  @override
  String get bridgesSignInToThisWifi => 'Masuk ke Wi-Fi ini';

  @override
  String get bridgesThisNetworkWantsA =>
      'Jaringan ini minta kamu masuk dulu. Setelah kamu masuk, Kryfo akan terhubung.';

  @override
  String get bridgesThisNetworkWantsADesk =>
      'Jaringan ini minta kamu masuk dulu. Masuk lewat browser-mu, atau periksa koneksi jaringan komputer. Setelah kamu masuk, Kryfo akan terhubung.';

  @override
  String get bridgesWaitingForWifiSignIn => 'Menunggu masuk ke Wi-Fi';

  @override
  String get bridgesOpenWifiSettings => 'Buka setelan Wi-Fi';

  @override
  String get bridgesUsingBuiltIn => 'Memakai jembatan bawaan';

  @override
  String get bridgesUsingSnowflake => 'Memakai Snowflake';

  @override
  String get bridgesUsingTorProject => 'Memakai jembatan dari Tor Project';

  @override
  String get bridgesBridgeRemoved => 'Jembatan dihapus';

  @override
  String get bridgesUndo => 'Urungkan';

  @override
  String bridgesRemoveBridgeN(String n) {
    return 'Hapus jembatan $n';
  }

  @override
  String get bridgesTurnOnAutomatic => 'Aktifkan otomatis';

  @override
  String get bridgesPasteABridgeLine => 'Tempel baris jembatan';

  @override
  String get bridgesInUse => 'Dipakai';

  @override
  String get bridgesPasteTheLineThey =>
      'Tempel baris jembatan, atau pindai kodenya. Ambil baris dari Tor Project atau dari orang yang kamu kenal.';

  @override
  String get bridgesYouReOnAMode =>
      'Modemu tidak memakai Tor. Pilihan ini berlaku saat kamu kembali ke mode itu.';

  @override
  String get bridgesPasteOrScanALine =>
      'Tempel atau pindai baris dari Tor Project atau dari orang yang kamu percaya.';

  @override
  String get bridgesNothingYet => 'Belum ada';

  @override
  String get torBootSplashIfTorIsBlocked =>
      'Kalau Tor diblokir atau diawasi di tempatmu, Kryfo bisa mulai lewat jembatan.';

  @override
  String get bridgesScanACode => 'Pindai kode';

  @override
  String get bridgesSwitchToAutomatic => 'Ganti ke otomatis';

  @override
  String get torBootSplashTorIsBlockedHere =>
      'Tor diblokir atau diawasi di sini';

  @override
  String get torBootSplashStartThroughABridge => 'Mulai lewat jembatan';

  @override
  String get torBootSplashNeverTriesTorPlainly =>
      'Di sini Kryfo tidak pernah mencoba Tor secara langsung. Kryfo mencari jembatan yang berfungsi, atau kamu bisa memilih sendiri setelah ini.';

  @override
  String get bridgesTryingAnotherWay => 'Mencoba cara lain…';

  @override
  String get bridgesFindingAWayIn => 'Mencari jalan masuk…';

  @override
  String get bridgesGoesThroughAVolunteer =>
      'Lewat komputer relawan. Sulit diblokir, lambat di awal.';

  @override
  String get bridgesTorSeemsBlocked =>
      'Tor sepertinya diblokir di jaringan ini';

  @override
  String get bridgesTorIsBlockedOnThis => 'Tor diblokir di jaringan ini';

  @override
  String bridgesKryfoCouldNotRead(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Kryfo tidak bisa membaca $countString baris di antaranya',
    );
    return '$_temp0';
  }

  @override
  String get bridgesTorNoBridge => 'Tor, tanpa jembatan';

  @override
  String get bridgesKryfoFindsAWay =>
      'Kryfo mencari cara yang berhasil di tempatmu.';

  @override
  String get bridgesTorVpnLine =>
      'Di dalam VPN Tor seperti Orbot, Kryfo mulai lewat jembatan.';

  @override
  String get bridgesThisBridgeIsnTGetting => 'Jembatan ini tidak tembus';

  @override
  String get bridgesBridgesTheTorProject =>
      'Jembatan yang sebelumnya kamu dapat dari Tor Project.';

  @override
  String get bridgesConnectingDots => 'Menghubungkan…';

  @override
  String get bridgesNotNow => 'Nanti saja';

  @override
  String get bridgesObfs4BridgesThatCome =>
      'Jembatan bawaan Kryfo (obfs4). Cepat dicoba, sering diblokir.';

  @override
  String get bridgesYourNetworkMayBe => 'Jaringanmu mungkin dibatasi';

  @override
  String get bridgesCheckingForMessages => 'Memeriksa pesan…';

  @override
  String get bridgesSavedLines => 'Baris tersimpan';

  @override
  String get bridgesPasteTheLineTheyDesk =>
      'Tempel baris jembatan. Ambil baris dari Tor Project atau dari orang yang kamu kenal.';

  @override
  String get bridgesFromAFriendLower => 'dari teman';

  @override
  String get bridgesAlmostThere => 'Sebentar lagi';

  @override
  String get bridgesUseThisBridge => 'Pakai jembatan ini';

  @override
  String bridgesUseTheseBridges(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Pakai $countString jembatan ini',
    );
    return '$_temp0';
  }

  @override
  String get transportBridgeMethod => 'Metode';

  @override
  String get bridgesPointAtTheBridge => 'Arahkan ke kode QR jembatan';

  @override
  String get bridgesConnectingThroughYourBridge =>
      'Menghubungkan lewat jembatanmu…';

  @override
  String get bridgesThisLineIsTooLong => 'Baris ini terlalu panjang untuk Tor.';

  @override
  String get bridgesAutomaticFindsAWay =>
      'Otomatis mencari cara sendiri saat Tor diblokir. Untuk menemukan jembatan, Kryfo mungkin bertanya ke Tor Project, jika kamu setuju.';

  @override
  String get bridgesFromTheTorProjectLower => 'dari Tor Project';

  @override
  String get bridgesBridgesGoDeadWithout =>
      'Jembatan bisa berhenti bekerja tanpa peringatan. Otomatis bisa mencari cara lain.';

  @override
  String get bridgesWhenTorIsBlockedAutomatic =>
      'Saat Tor diblokir, Otomatis menanyakan ke Tor Project apa yang berhasil di negaramu.';

  @override
  String get bridgesPlainAdvice =>
      'Kryfo memilih jembatan secara otomatis. Snowflake dan WebTunnel berfungsi di sebagian besar tempat. Kalau salah satunya tidak tersambung, coba yang lain, minta jembatan pribadi dari Tor Project, atau minta baris jembatan dari teman.';

  @override
  String get bridgesPrivateHint =>
      'Tidak bisa tersambung otomatis? Minta jembatan pribadi dari Tor Project, lalu tempel di bawah.';

  @override
  String get bridgesPrivateWebsite => 'Situs web';

  @override
  String get bridgesPrivateEmail => 'Surel';

  @override
  String get bridgesPrivateEmailFrom => 'Kirim dari Gmail atau Riseup';

  @override
  String bridgesPrivateCopy(Object what) {
    return 'Salin $what';
  }

  @override
  String bridgesPrivateCopied(Object what) {
    return '$what disalin';
  }

  @override
  String bridgesPrivateOpen(Object what) {
    return 'Buka $what';
  }

  @override
  String get bridgesWatchedTitle => 'Jaringanku diawasi';

  @override
  String get bridgesWatchedLine =>
      'Kryfo tidak pernah mencoba Tor tanpa jembatan.';

  @override
  String get bridgesWatchedFastCost =>
      'Jaringanmu bisa melihat kamu memakai Kryfo.';

  @override
  String get bridgesWatchedDirectCost =>
      'Jaringanmu bisa melihat kamu memakai Tor.';

  @override
  String get bridgesWatchedNowAuto =>
      'Sekarang Otomatis, jadi Tor selalu mulai lewat jembatan';

  @override
  String get bridgesAskTorProject => 'Tanya Tor Project';

  @override
  String get bridgesTooLongForTor => 'Terlalu panjang untuk Tor';

  @override
  String bridgesMethodFrom(String method, String from) {
    return '$method, $from';
  }

  @override
  String get bridgesKryfoCanTUseThis => 'Kryfo tidak bisa memakai baris ini';

  @override
  String get bridgesTryAutomatic => 'Coba otomatis';

  @override
  String get bridgesNoInternet => 'Tidak ada internet';

  @override
  String get bridgesConnection => 'Koneksi';

  @override
  String get bridgesGetABridge => 'Dapatkan jembatan';

  @override
  String get languageTitle => 'Bahasa';

  @override
  String get languageMatchPhone => 'Ikuti ponsel';

  @override
  String get languageMatchPhoneDesk => 'Ikuti sistem';

  @override
  String languageMatchPhoneValue(Object language) {
    return 'Ikuti ponsel ($language)';
  }

  @override
  String languageMatchPhoneValueDesk(Object language) {
    return 'Ikuti sistem ($language)';
  }

  @override
  String get languageRedrawLine =>
      'Kryfo digambar ulang dalam bahasa baru dan terbuka di obrolanmu.';

  @override
  String languageButton(Object language) {
    return 'Bahasa: $language';
  }

  @override
  String get androidServiceTitle => 'Kryfo aktif';

  @override
  String get androidServiceText =>
      'Jalur terenkripsimu tetap terbuka agar pesan bisa masuk';

  @override
  String get androidChannelName => 'Tetap terhubung';

  @override
  String get androidChannelDescription =>
      'Menjaga Kryfo tetap terhubung agar pesan terenkripsi masuk saat aplikasi ditutup. Mematikan ini menghentikan pengiriman.';

  @override
  String get videoViewerPlay => 'Putar';

  @override
  String get videoViewerPause => 'Jeda';

  @override
  String get videoViewerPlayAgain => 'Putar lagi';

  @override
  String get videoViewerCannotPlay =>
      'Ponsel ini tidak bisa memutar video ini di sini.';

  @override
  String get videoViewerCannotPlayDesk =>
      'Komputer ini tidak bisa memutar video ini di sini.';

  @override
  String get videoViewerOpenElsewhere => 'Buka di aplikasi lain';

  @override
  String get photoKnowsLookedFor => 'Yang dicari';

  @override
  String get photoKnowsNotInIt => 'Tidak ada';

  @override
  String get languageNameEn => 'Inggris';

  @override
  String get languageNameDe => 'Jerman';

  @override
  String get languageNameFr => 'Prancis';

  @override
  String get languageNameEs => 'Spanyol';

  @override
  String get languageNamePt => 'Portugis (Brasil)';

  @override
  String get languageNameIt => 'Italia';

  @override
  String get languageNameRu => 'Rusia';

  @override
  String get languageNameUk => 'Ukraina';

  @override
  String get languageNameTr => 'Turki';

  @override
  String get languageNameZh => 'Tionghoa (Sederhana)';

  @override
  String get languageNameZhHant => 'Tionghoa (Tradisional)';

  @override
  String get languageNameVi => 'Vietnam';

  @override
  String get languageNameId => 'Indonesia';

  @override
  String get languageNameFa => 'Persia';

  @override
  String get languageNameAr => 'Arab';

  @override
  String get languageNameHi => 'Bahasa Hindi';

  @override
  String get languageNamePl => 'Bahasa Polandia';

  @override
  String get languageLaterLine =>
      'Kamu bisa mengubahnya kapan saja di pengaturan.';

  @override
  String get pollAttach => 'Polling';

  @override
  String get pollNewTitle => 'Polling baru';

  @override
  String get pollQuestionHint => 'Tanyakan sesuatu ke grup';

  @override
  String get pollOptionsLabel => 'Pilihan';

  @override
  String pollOptionHint(Object n) {
    return 'Pilihan $n';
  }

  @override
  String get pollAddOption => 'Tambah pilihan';

  @override
  String get pollMaxLine => 'Paling banyak dua belas pilihan.';

  @override
  String get pollMultiple => 'Beberapa jawaban';

  @override
  String get pollMultipleLine => 'Orang bisa memilih lebih dari satu.';

  @override
  String get pollSend => 'Kirim polling';

  @override
  String get pollKind => 'Polling';

  @override
  String get pollKindMulti => 'Polling · beberapa jawaban';

  @override
  String get pollKindClosed => 'Hasil akhir';

  @override
  String pollVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count suara',
      zero: 'Belum ada suara',
    );
    return '$_temp0';
  }

  @override
  String get pollVote => 'Beri suara';

  @override
  String get pollTakeBack => 'Tarik suaraku';

  @override
  String get pollClose => 'Tutup polling';

  @override
  String get pollCloseTitle => 'Tutup polling ini?';

  @override
  String get pollCloseLine =>
      'Semua orang melihat hasil akhirnya, dan tidak ada yang bisa memilih lagi setelah ini.';

  @override
  String get pollCloseYes => 'Tutup';

  @override
  String pollPreview(Object question) {
    return 'Polling: $question';
  }

  @override
  String get pollWhoVoted => 'Yang memberi suara';

  @override
  String get pollNobody => 'Belum ada';

  @override
  String get pollYou => 'Kamu';

  @override
  String pollOptionA11y(Object option, Object share) {
    return '$option, $share';
  }

  @override
  String get pollPickOne => 'Pilih satu';

  @override
  String get pollPickSeveral => 'Pilih satu atau lebih';

  @override
  String get searchHint => 'Cari di obrolan dan pesan';

  @override
  String get searchFilterAll => 'Semua';

  @override
  String get searchFilterPhotos => 'Foto';

  @override
  String get searchFilterVideos => 'Video';

  @override
  String get searchFilterFiles => 'File';

  @override
  String get searchFilterLinks => 'Tautan';

  @override
  String get searchChats => 'Obrolan';

  @override
  String get searchMessages => 'Pesan';

  @override
  String get searchIntroTitle => 'Cari di obrolanmu';

  @override
  String get searchIntroLine =>
      'Nama, kata, foto, file, dan tautan. Pencarian berjalan di ponsel ini dan tidak mengirim apa pun ke mana pun.';

  @override
  String get searchIntroLineDesk =>
      'Nama, kata, foto, file, dan tautan. Pencarian berjalan di komputer ini dan tidak mengirim apa pun ke mana pun.';

  @override
  String get searchNothing => 'Tidak ada hasil';

  @override
  String get searchNothingLine => 'Coba kata lain atau filter lain.';

  @override
  String searchMatches(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hasil',
    );
    return '$_temp0';
  }

  @override
  String searchMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lagi',
    );
    return '$_temp0';
  }

  @override
  String searchFilling(Object share) {
    return 'Menambahkan pesan lama · $share';
  }

  @override
  String get searchClear => 'Hapus';

  @override
  String get handleShowInSearch => 'Tampilkan aku di pencarian';

  @override
  String get handleShowInSearchLine =>
      'Siapa pun bisa menemukan nama pengguna ini dan mengirimimu pesan.';

  @override
  String handleShownAs(Object name) {
    return 'Tampil sebagai $name';
  }

  @override
  String get handleNameInSearch => 'Nama di pencarian';

  @override
  String get handleNameInSearchLine =>
      'Opsional. Nama ini muncul di samping nama penggunamu saat ada yang mencari. Siapa pun bisa menemukan nama pengguna ini dan mengirimimu pesan.';

  @override
  String get handleNameHint => 'Namamu, atau biarkan kosong';

  @override
  String get handleShowMe => 'Tampilkan aku';

  @override
  String get handleSearchOff => 'Kamu sudah keluar dari pencarian';

  @override
  String handleSearchOn(Object handle) {
    return 'Kamu ada di pencarian sebagai @$handle';
  }

  @override
  String get handleRegistryFailed =>
      'Tidak bisa menghubungi registri.\nCoba lagi semenit lagi.';

  @override
  String get handleStillReaching =>
      'Masih menghubungi registri.\nLewat Tor ini bisa makan waktu.';

  @override
  String get handleSearchNeedsTor =>
      'Pencarian nama pengguna memerlukan Tor. Sementara itu, tambahkan lewat QR atau tautan.';

  @override
  String get handleCheckClock =>
      'Periksa tanggal dan jam di ponsel, lalu coba lagi.';

  @override
  String get handleCheckClockDesk =>
      'Periksa tanggal dan jam di komputer, lalu coba lagi.';

  @override
  String get searchPeople => 'Orang';

  @override
  String searchPeopleAsk(Object query) {
    return 'Cari “$query” di antara nama pengguna publik';
  }

  @override
  String get searchPeopleLine =>
      'Ditanyakan lewat Tor. Registri tidak menyimpan catatannya.';

  @override
  String get searchPeopleNone => 'Tidak ada nama pengguna publik yang cocok';

  @override
  String get searchPeopleOffline => 'Tor belum siap';

  @override
  String get searchPeopleBusy =>
      'Terlalu banyak pencarian saat ini. Coba lagi sebentar lagi.';

  @override
  String get searchPeopleUnreachable => 'Tidak bisa menghubungi registri';

  @override
  String get peopleVerified => 'Nama pengguna terverifikasi';

  @override
  String get peopleAdd => 'Tambah';

  @override
  String peopleFingerprint(Object fp) {
    return 'Sidik jari kunci · $fp';
  }

  @override
  String get peopleFingerprintLine =>
      'Periksa apakah cocok dengan yang mereka lihat di aplikasinya.';

  @override
  String get peopleAdding => 'Menambahkan…';

  @override
  String handleNobodyHasClaimed(Object handle) {
    return 'Belum ada yang mengklaim $handle';
  }

  @override
  String get handleThatHandleIsTaken => 'Nama pengguna itu sudah dipakai';

  @override
  String get pinPickDifferent => 'Pilih PIN lain';

  @override
  String get lockFingerAfterPin =>
      'Ketik PIN sekali untuk memakai sidik jari lagi.';

  @override
  String get lockFingerLockedOut =>
      'Terlalu banyak percobaan dengan sidik jari. Pakai PIN, atau buka kunci ponselmu sekali dengan kunci layarnya sendiri agar sidik jari bisa dipakai lagi.';

  @override
  String get lockFingerRefused =>
      'Ponselmu tidak mau menyimpan buka kunci dengan sidik jari untuk Kryfo, jadi fitur ini mati. PIN tetap berfungsi.';

  @override
  String get lockFingerTryAgain =>
      'Ponselmu sedang sibuk tadi. Coba lagi dengan sidik jari, atau pakai PIN.';

  @override
  String get pinsFingerRefused =>
      'Ponselmu tidak mau menyalakan buka kunci dengan sidik jari untuk Kryfo. PIN tetap berfungsi.';

  @override
  String get pinsAdvanced => 'Perlindungan lanjutan';

  @override
  String get pinsAdvancedLine =>
      'Untuk saat seseorang memaksamu membuka kunci ponsel.';

  @override
  String get pinsAdvancedLineDesk =>
      'Untuk saat seseorang memaksamu membuka kunci komputer.';

  @override
  String get pinsWipeLine =>
      'Jika diketik di layar kunci, PIN ini menghapus Kryfo dari ponsel ini.';

  @override
  String get pinsWipeLineDesk =>
      'Jika diketik di layar kunci, PIN ini menghapus Kryfo dari komputer ini.';

  @override
  String get pinsDecoyPin => 'PIN umpan';

  @override
  String get pinsDecoyLine => 'Membuka Kryfo kosong, seperti baru dipasang.';

  @override
  String get pinsChangeDecoyPin => 'Ganti PIN umpan';

  @override
  String get pinsRemoveTheDecoyPin => 'Hapus PIN umpan?';

  @override
  String get pinsTheDecoyGoes => 'Kryfo kosong yang dibukanya ikut hilang.';

  @override
  String get pinsTurnOffWithDecoy =>
      'Semua PIN hilang, termasuk umpan, Kryfo-nya, dan obrolan tersembunyi yang ada. Siapa pun yang memegang ponselmu langsung masuk ke Kryfo sebagai dirimu.';

  @override
  String get pinsTurnOffWithDecoyDesk =>
      'Semua PIN hilang, termasuk umpan, Kryfo-nya, dan obrolan tersembunyi yang ada. Siapa pun yang memakai komputermu langsung masuk ke Kryfo sebagai dirimu.';

  @override
  String get pinsHowThisWorks => 'Cara kerjanya';

  @override
  String get flowEnterYourPin => 'Masukkan PIN-mu';

  @override
  String get flowEnterYourPinLine => 'PIN yang membuka Kryfo.';

  @override
  String get flowWipeTitle => 'PIN penghapus';

  @override
  String get flowWipe1 =>
      'Jika diketik di layar kunci sebagai ganti PIN-mu, PIN ini menghapus Kryfo dari ponsel ini lalu menutupnya. Bagi yang melihat, aplikasinya seperti berhenti begitu saja.';

  @override
  String get flowWipe1Desk =>
      'Jika diketik di layar kunci sebagai ganti PIN-mu, PIN ini menghapus Kryfo dari komputer ini lalu menutupnya. Bagi yang melihat, aplikasinya seperti berhenti begitu saja.';

  @override
  String get flowWipe2 =>
      'Semua chat dan identitasmu ikut terhapus, begitu juga umpan jika kamu punya.';

  @override
  String get flowWipeChoose => 'Pilih PIN penghapus';

  @override
  String get flowWipeDone => 'PIN penghapus sudah dibuat';

  @override
  String get flowWipeDoneLine =>
      'Tak ada apa pun di layar kunci yang menunjukkan PIN ini ada.';

  @override
  String get flowDecoyTitle => 'PIN umpan';

  @override
  String get flowDecoy1 => 'Membuka Kryfo kosong, seperti baru dipasang.';

  @override
  String get flowDecoyFinger =>
      'Selama PIN umpan dipasang, aplikasi ini hanya terbuka dengan PIN-mu. Jika sidik jari aktif di umpan, jari membuka umpan, tidak pernah aplikasi ini.';

  @override
  String get flowDecoyDigits =>
      'Pakai jumlah angka yang sama dengan PIN-mu, karena siapa pun yang melihat bisa menghitung titiknya.';

  @override
  String get flowDecoyShade =>
      'Notifikasi yang sudah ada di panel sudah terlihat. Selama umpan terbuka, tidak ada notifikasi baru yang muncul.';

  @override
  String get flowDecoyShadeDesk =>
      'Notifikasi yang sudah ada di layar sudah terlihat. Selama umpan terbuka, tidak ada notifikasi baru yang muncul.';

  @override
  String get flowDecoyChoose => 'Pilih PIN umpan';

  @override
  String get flowDecoyDone => 'PIN umpan sudah dibuat';

  @override
  String get flowDecoyDoneLine =>
      'Ketik di layar kunci untuk membuka Kryfo kosong. Untuk keluar, beralih ke aplikasi lain lalu masukkan PIN-mu.';

  @override
  String get flowLaw =>
      'Di beberapa negara, menolak membuka kunci ponsel atau menyembunyikan data dari petugas sudah merupakan pelanggaran hukum. Kenali hukum di tempat tujuanmu.';

  @override
  String get flowLawDesk =>
      'Di beberapa negara, menolak membuka kunci perangkat atau menyembunyikan data dari petugas sudah merupakan pelanggaran hukum. Kenali hukum di tempat tujuanmu.';

  @override
  String get howWipe =>
      'Jika diketik di layar kunci, PIN penghapus menghapus semua chat, identitasmu, dan umpan mana pun, lalu menutup Kryfo. PIN ini tetap bekerja meski papan angka sedang ditahan setelah salah coba.';

  @override
  String get howDecoy =>
      'PIN umpan membuka Kryfo kedua yang kosong dengan tiga kata sendiri. Pesan ke Kryfo-mu yang asli tetap masuk di bawahnya tanpa suara. Untuk keluar dari umpan, beralih ke aplikasi lain lalu masukkan PIN-mu.';

  @override
  String get flowNotSet => 'Gagal dibuat. Coba lagi.';

  @override
  String get pinsHiddenChats => 'Obrolan tersembunyi';

  @override
  String get pinsHiddenLine =>
      'Obrolan pilihanmu tetap tersembunyi sampai kamu memasukkan PIN obrolan tersembunyi: tidak ada di daftar, tidak ada di pencarian, tanpa notifikasi.';

  @override
  String get pinsSetUp => 'Atur';

  @override
  String get pinsChangeHiddenPin => 'Ganti PIN obrolan tersembunyi';

  @override
  String get pinsHideMoreChats => 'Sembunyikan obrolan lain';

  @override
  String get pinsRemoveHiddenChats => 'Matikan obrolan tersembunyi';

  @override
  String get pinsRemoveHiddenTitle => 'Matikan obrolan tersembunyi?';

  @override
  String get pinsRemoveHiddenLine =>
      'Obrolan itu kembali ke daftar obrolanmu, dan PIN obrolan tersembunyi tidak membuka apa pun lagi.';

  @override
  String get pinsTurnOffHiddenFirst =>
      'Obrolan tersembunyi butuh kunci aplikasi. Matikan dulu, dan obrolan itu kembali ke daftar obrolanmu.';

  @override
  String get flowVaultTitle => 'Obrolan tersembunyi';

  @override
  String get flowVault1 =>
      'Pilih obrolan dan grup yang mau disembunyikan. PIN-mu membuka Kryfo tanpa semua itu. PIN obrolan tersembunyi membuka semuanya, termasuk obrolan tersembunyi.';

  @override
  String get flowVault2 =>
      'Selama tersembunyi, obrolan itu tidak pernah memberi notifikasi atau menampilkan angka. Pesannya tetap masuk dan menunggu, tersegel, sampai kamu memasukkan PIN obrolan tersembunyi.';

  @override
  String get flowVaultFinger =>
      'Sidik jarimu membuka Kryfo tanpa obrolan tersembunyi.';

  @override
  String get flowVaultDigits =>
      'Buat PIN-mu juga enam angka atau lebih, karena siapa pun yang melihat bisa menghitung titiknya.';

  @override
  String get flowVaultReplace =>
      'Ini menggantikan obrolan tersembunyi yang sudah ada di ponsel ini.';

  @override
  String get flowVaultReplaceDesk =>
      'Ini menggantikan obrolan tersembunyi yang sudah ada di komputer ini.';

  @override
  String get flowVaultChoose => 'Pilih PIN obrolan tersembunyi';

  @override
  String get flowVaultChooseLine => 'Enam angka atau lebih.';

  @override
  String get flowEnterHiddenPinLine =>
      'PIN yang membuka obrolan tersembunyimu.';

  @override
  String get flowVaultForgetTitle => 'Ingat PIN ini';

  @override
  String get flowVaultForget =>
      'Kalau kamu lupa PIN ini, obrolan tersembunyimu hilang untuk selamanya. Tidak ada yang bisa memulihkannya.';

  @override
  String get flowVaultForgetOk => 'Aku mengerti';

  @override
  String get flowVaultPickTitle => 'Sembunyikan obrolan mana?';

  @override
  String get flowVaultPickLine =>
      'Obrolan itu keluar dari daftar obrolanmu sekarang. PIN obrolan tersembunyi menampilkannya lagi.';

  @override
  String flowVaultPickButton(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sembunyikan $countString obrolan',
      zero: 'Lewati dulu',
    );
    return '$_temp0';
  }

  @override
  String get flowVaultPickEmpty => 'Belum ada obrolan untuk disembunyikan.';

  @override
  String get flowVaultBackupTitle => 'Buat cadangan sekarang?';

  @override
  String get flowVaultBackupLine =>
      'Cadangan yang dibuat sekarang juga memuat obrolan tersembunyimu, dengan frasa sandi sendiri. Kalau kamu lupa PIN obrolan tersembunyi, hanya itu jalan untuk mendapatkannya kembali.';

  @override
  String get flowVaultBackupNow => 'Buat cadangan';

  @override
  String get flowVaultNotNow => 'Nanti saja';

  @override
  String get flowVaultDone => 'Obrolan tersembunyi siap';

  @override
  String get flowVaultDoneLine =>
      'Ketik PIN obrolan tersembunyi di layar kunci untuk melihatnya. Beralih ke aplikasi lain, dan obrolan itu tersembunyi lagi.';

  @override
  String get flowVaultChanged => 'PIN obrolan tersembunyi diganti';

  @override
  String get flowVaultChangedLine =>
      'Obrolan tersembunyimu sekarang terbuka dengan yang baru. Yang lama tidak membuka apa pun lagi.';

  @override
  String get howVault =>
      'PIN obrolan tersembunyi membuka Kryfo beserta obrolan tersembunyimu; PIN-mu dan sidik jarimu membukanya tanpa obrolan itu. Mengatur obrolan tersembunyi lagi menggantikan yang ada di ponsel ini. Kalau PIN obrolan tersembunyi terlupa, obrolan itu hilang untuk selamanya.';

  @override
  String get howVaultDesk =>
      'PIN obrolan tersembunyi membuka Kryfo beserta obrolan tersembunyimu; PIN-mu membukanya tanpa obrolan itu. Mengatur obrolan tersembunyi lagi menggantikan yang ada di komputer ini. Kalau PIN obrolan tersembunyi terlupa, obrolan itu hilang untuk selamanya.';

  @override
  String get chatHide => 'Sembunyikan obrolan';

  @override
  String get groupHide => 'Sembunyikan grup';

  @override
  String get chatHidden => 'Tersembunyi';

  @override
  String get chatHiddenToast => 'Disembunyikan dari daftar obrolanmu';

  @override
  String get chatShowInList => 'Tampilkan di daftar obrolan';

  @override
  String get stickerOpen => 'Stiker';

  @override
  String get stickerRecent => 'Terbaru';

  @override
  String stickerA11y(String emoji) {
    return 'Stiker $emoji';
  }

  @override
  String get stickerRemoveRecent => 'Hapus dari terbaru';

  @override
  String get stickerCouldNotLoad => 'Stiker tidak dapat dimuat';

  @override
  String get stickerLabel => 'Stiker';

  @override
  String get timedMessageLabel => 'Pesan berwaktu';

  @override
  String get stickerNewer => 'Dari Kryfo versi lebih baru';

  @override
  String get devLinkMismatch =>
      'Tautan ini mengaku sebagai Marios, tapi kuncinya tidak cocok. Tidak ada yang ditambahkan.';

  @override
  String get devName => 'Marios';

  @override
  String get devRowTitle => 'Marios · pembuat Kryfo';

  @override
  String get devWelcome =>
      'Hai, aku Marios, aku yang membuat Kryfo. Ceritakan apa saja: bug, ide, pertanyaan. Aku membaca semuanya.';

  @override
  String get devPinned => 'Tertanam di Kryfo';

  @override
  String get devAnonymous => 'Anonim';

  @override
  String get devAboutLine =>
      'Kunci Marios tertanam di Kryfo. Setiap pesan darinya dicocokkan dengan kunci itu, jadi tidak ada orang lain yang bisa menulis atas namanya.';

  @override
  String get devKeyLabel => 'Kuncinya';

  @override
  String get devDeleteLine =>
      'Semua pesan terhapus, dan obrolan ini tidak akan kembali.';

  @override
  String get devDeleteLineAnon =>
      'Semua pesan dan nama yang dibuat untuk obrolan ini terhapus, dan obrolan ini tidak akan kembali.';

  @override
  String get devDeleteLineBack =>
      'Semua pesan terhapus, dan obrolan ini tidak akan kembali. Pesan yang kamu kirim juga ditarik dari ponsel Marios.';

  @override
  String get devDeleteLineAnonBack =>
      'Semua pesan dan nama yang dibuat untuk obrolan ini terhapus, dan obrolan ini tidak akan kembali. Pesan yang kamu kirim juga ditarik dari ponsel Marios.';

  @override
  String devDeleteNotTakenBack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pesan tidak bisa ditarik dari ponsel Marios',
    );
    return '$_temp0';
  }

  @override
  String get devDeleteFailed => 'Obrolan tidak bisa dihapus. Coba lagi.';

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
  String get settingsWriteToMarios => 'Kirim pesan ke Marios';

  @override
  String get settingsWriteToMariosHint => 'Bug, ide, pertanyaan';

  @override
  String get seenDevChat => 'Obrolan dengan Marios';

  @override
  String get seenDevChatCell => 'Jika kamu menulis';

  @override
  String get seenDevChatLine =>
      'Tidak ada apa-apa sampai kamu menulis. Setelah itu, apa yang kamu kirim, dan tiga katamu, kecuali kamu menulis secara anonim.';

  @override
  String get devWriteAnonymously => 'Tulis secara anonim';

  @override
  String get devUseMyWords => 'Pakai tiga kataku';

  @override
  String get devWhoSeesWhat => 'Cara kerjanya';

  @override
  String get devWhoWords =>
      'Dengan tiga katamu, ini obrolan seperti yang lain: Marios bisa membalas, dan wajah serta lencana pendukungmu tetap bersamamu.';

  @override
  String get devWhoAnon =>
      'Jika kamu menulis secara anonim, Kryfo membuat nama dan kunci baru khusus untuk obrolan ini. Semuanya tetap di ponsel ini dan tidak pernah dipakai di tempat lain.';

  @override
  String get devWhoAnonDesk =>
      'Jika kamu menulis secara anonim, Kryfo membuat nama dan kunci baru khusus untuk obrolan ini. Semuanya tetap di komputer ini dan tidak pernah dipakai di tempat lain.';

  @override
  String get devWhoNothingYet =>
      'Tidak ada yang keluar dari ponselmu sampai kamu mengirim pesan pertamamu.';

  @override
  String get devWhoNothingYetDesk =>
      'Tidak ada yang keluar dari komputermu sampai kamu mengirim pesan pertamamu.';

  @override
  String get devWhoChoiceStays => 'Pilihanmu melekat pada obrolan ini.';

  @override
  String get devUpdateToWrite =>
      'Perbarui Kryfo untuk mengirim pesan ke Marios.';

  @override
  String get devKeyCheckFailed =>
      'Tidak bisa memeriksa kunci Marios. Tidak ada yang terkirim.';

  @override
  String get devLockLine =>
      'Marios akan membaca pesan-pesan ini. Kamu bisa menulis lagi setelah dia membalas.';

  @override
  String get devNewKey => 'Marios punya kunci baru';

  @override
  String get devStartNewChat => 'Mulai obrolan baru';

  @override
  String get devKeyRetired =>
      'Kunci ini sudah tidak dipakai lagi. Tidak ada lagi yang bisa dikirim atau diterima di sini.';

  @override
  String get devNamelessLine =>
      'Nama yang dibuat untuk obrolan ini tetap di ponsel tempat nama itu dibuat, jadi di sini obrolan ini hanya bisa dibaca.';

  @override
  String get devNamelessLineDesk =>
      'Nama yang dibuat untuk obrolan ini tetap di perangkat tempat nama itu dibuat, jadi di sini obrolan ini hanya bisa dibaca.';

  @override
  String get devStartNewLine =>
      'Semua pesan di sini terhapus, dan obrolan baru terbuka.';

  @override
  String get devVoiceDisguised => 'Suaramu disamarkan di obrolan ini';

  @override
  String get devChatOptions => 'Opsi obrolan';

  @override
  String get requestsSomeoneNew => 'Orang baru';

  @override
  String get nameTakenTitle => 'Orang lain memakai kata-kata ini';

  @override
  String get nameTakenLine =>
      'Seseorang di sini mendapat kata-kata ini dari permintaan, perkenalan, atau grup, dengan kunci lain, dan belum ada yang mengeceknya. Kata-kata bisa disalin. Kalau tautan ini dari orang yang kamu kenal, pakai saja, lalu bandingkan nomor keamanan dengannya.';

  @override
  String get nameTakenChatLine =>
      'Obrolanmu dengan kata-kata ini datang dari permintaan, perkenalan, atau grup, dengan kunci lain, dan belum ada yang mengeceknya. Kata-kata bisa disalin. Kalau tautan ini dari orang yang kamu kenal, pakai saja: obrolan itu dihapus, dan kamu membandingkan nomor keamanan di obrolan yang baru. Tidak yakin dari mana tautan ini? Tetap pakai yang sudah ada.';

  @override
  String get nameTakenDeletedLine =>
      'Kamu sudah menghapus obrolan dengan kata-kata ini, yang memakai kunci lain. Kalau tautan ini dari orang yang kamu kenal, pakai saja, lalu bandingkan nomor keamanan dengannya.';

  @override
  String get nameTakenTombLine =>
      'Kamu sudah menghapus seseorang dengan kata-kata ini dari ponsel ini karena dia bukan orang yang dia akui. Kalau tautan ini dari orang yang kamu kenal, pakai saja, lalu bandingkan nomor keamanan dengannya.';

  @override
  String get nameTakenTombLineDesk =>
      'Kamu sudah menghapus seseorang dengan kata-kata ini dari komputer ini karena dia bukan orang yang dia akui. Kalau tautan ini dari orang yang kamu kenal, pakai saja, lalu bandingkan nomor keamanan dengannya.';

  @override
  String get nameTakenUse => 'Pakai tautan ini';

  @override
  String get nameTakenKeep => 'Tetap yang sudah ada';

  @override
  String get appYourOwnInvite =>
      'Ini undanganmu sendiri. Bagikan ke orang lain untuk terhubung.';

  @override
  String appLinkNeedsUpdate(Object id) {
    return '$id perlu memperbarui Kryfo sebelum kalian bisa saling menambahkan.';
  }

  @override
  String appLinkWordsTaken(Object id) {
    return 'Sudah ada seseorang di sini sebagai $id, dengan kunci lain. Bandingkan nomor keamanan dengannya untuk tahu siapa yang mana. Tidak ada yang ditambahkan.';
  }

  @override
  String appLinkWordsVerified(Object id) {
    return 'Kamu sudah memverifikasi $id dengan kunci lain. Tidak ada yang ditambahkan.';
  }

  @override
  String appTheyAreBlocked(Object id) {
    return 'Kamu memblokir $id. Buka blokirnya di “Diblokir” pada Pengaturan untuk menambahkannya lagi.';
  }

  @override
  String get notThemNumbersDiffer => 'Nomor-nomornya berbeda';

  @override
  String get notThemLine =>
      'Kalau nomornya memang berbeda, mungkin ada orang lain yang memakai namanya atau berada di antara kalian.';

  @override
  String get notThemButton => 'Ini bukan dia';

  @override
  String get notThemSheetTitle => 'Hapus kontak ini dan blokir kuncinya?';

  @override
  String get notThemSheetLine =>
      'Obrolan, pesan, dan filenya terhapus dari ponsel ini. Hanya tautan atau kode yang kamu tambahkan yang bisa memakai tiga katanya lagi. Bandingkan nomor keamanan dengan siapa pun yang kamu tambahkan.';

  @override
  String get notThemSheetLineDesk =>
      'Obrolan, pesan, dan filenya terhapus dari komputer ini. Hanya tautan atau kode yang kamu tambahkan yang bisa memakai tiga katanya lagi. Bandingkan nomor keamanan dengan siapa pun yang kamu tambahkan.';

  @override
  String get notThemRemove => 'Hapus dan blokir';

  @override
  String get notThemDone => 'Dihapus, dan kuncinya diblokir';

  @override
  String get groupAdminGoneLine =>
      'Admin grup ini sudah dihapus dari ponsel ini. Perubahan grup tidak lagi sampai ke kamu.';

  @override
  String get groupAdminGoneLineDesk =>
      'Admin grup ini sudah dihapus dari komputer ini. Perubahan grup tidak lagi sampai ke kamu.';

  @override
  String get blockedKey => 'Kunci diblokir';

  @override
  String get appKeyBlocked =>
      'Kamu memblokir kunci ini. Buka blokirnya di “Diblokir” pada Pengaturan untuk menambahkannya.';

  @override
  String get devLinkGone =>
      'Kamu sudah menghapus chat dengan Marios. Untuk memulai yang baru, ketuk “Kirim pesan ke Marios” di Pengaturan.';

  @override
  String lockTooManyTriesFor(Object left) {
    return 'Terlalu banyak percobaan · $left';
  }

  @override
  String get gifBadge => 'GIF';

  @override
  String get gifPlay => 'Putar GIF';

  @override
  String get gifSentInside => 'Dikirim di dalam pesanmu';

  @override
  String get gifOptInTitle => 'Cari GIF secara privat';

  @override
  String get gifOptInLead =>
      'Pencarian GIF butuh internet, jadi tetap mati sampai kamu mau.';

  @override
  String get gifOptInOverTor => 'Dicari lewat Tor';

  @override
  String get gifOptInThroughKryfo => 'Dicari lewat Kryfo';

  @override
  String get gifOptInAsksForYou =>
      'Server Kryfo bertanya ke layanan GIF untukmu. Layanan itu tidak pernah melihatmu, dan server tidak menyimpan catatan apa yang kamu cari.';

  @override
  String get gifOptInAsksForYouFast =>
      'Server Kryfo bertanya ke layanan GIF untukmu, jadi layanan itu tidak pernah melihatmu. Di Cepat, server kami melihat alamat IP-mu selama kamu mencari, dan tidak menyimpan catatan alamat itu atau apa yang kamu cari.';

  @override
  String get gifOptInLikeAPhoto =>
      'GIF dikirim terenkripsi, seperti foto. Ponsel temanmu tidak mengunduh apa pun.';

  @override
  String get gifOptInOffWhenever => 'Matikan kapan saja';

  @override
  String get gifOptInWhereToTurnOff =>
      'Pengaturan, Privasi, Pencarian GIF. GIF di ponselmu selalu bisa dipakai tanpa itu.';

  @override
  String get gifOptInWhereToTurnOffDesk =>
      'Pengaturan, Privasi, Pencarian GIF. GIF di komputermu selalu bisa dipakai tanpa itu.';

  @override
  String get gifTurnOn => 'Nyalakan pencarian GIF';

  @override
  String get gifNotNow => 'Nanti saja';

  @override
  String gifAskOverTor(String brand) {
    return 'Pencarian GIF lewat server Kryfo melalui Tor. $brand tidak pernah melihatmu. Nyalakan?';
  }

  @override
  String gifAskThroughKryfo(String brand) {
    return 'Pencarian GIF langsung ke server Kryfo, yang melihat alamat IP-mu di Cepat. $brand tidak pernah melihatmu. Nyalakan?';
  }

  @override
  String get gifAskTurnOn => 'Nyalakan';

  @override
  String get gifSearchOff => 'Pencarian GIF mati';

  @override
  String get gifSavedOnPhone =>
      'GIF yang tersimpan di ponselmu ada di *Di ponsel ini*.';

  @override
  String get gifSavedOnPhoneDesk =>
      'GIF yang tersimpan di komputermu ada di *Di komputer ini*.';

  @override
  String get gifTab => 'GIF';

  @override
  String get gifPhoneTab => 'Di ponsel ini';

  @override
  String get gifPhoneTabDesk => 'Di komputer ini';

  @override
  String get gifSearchHint => 'Cari GIF';

  @override
  String get gifClear => 'Hapus pencarian';

  @override
  String get gifServiceNeverSeesYou => 'Layanan GIF tidak pernah melihatmu';

  @override
  String get gifTrending => 'Sedang tren';

  @override
  String get gifOffline => 'Tor masih menyambung. GIF muncul begitu Tor siap.';

  @override
  String get gifBusy =>
      'Terlalu banyak pencarian saat ini. Coba lagi sebentar lagi.';

  @override
  String get gifUnreachable => 'Tidak bisa menghubungi layanan GIF Kryfo.';

  @override
  String get gifNothingFound => 'Tidak ada GIF. Coba kata lain.';

  @override
  String get gifCouldNotLoadMore => 'Tidak bisa memuat lagi';

  @override
  String get gifLoading => 'Memuat GIF';

  @override
  String get gifCouldNotGet => 'Tidak bisa mengambil GIF itu. Coba lagi.';

  @override
  String gifPoweredBy(String brand) {
    return 'Powered by $brand';
  }

  @override
  String gifNeverSeesYou(String brand) {
    return 'Dicari lewat Kryfo, $brand tidak pernah melihatmu.';
  }

  @override
  String gifTileA11y(String number) {
    return 'GIF $number';
  }

  @override
  String get gifPhoneLine =>
      'GIF yang tersimpan di ponsel ini. Tidak ada yang online.';

  @override
  String get gifPhoneLineDesk =>
      'GIF yang tersimpan di komputer ini. Tidak ada yang online.';

  @override
  String get gifPhoneChoose => 'Pilih GIF';

  @override
  String get settingsGifSearch => 'Pencarian GIF';

  @override
  String get settingsGifSearchHint =>
      'Mati sampai kamu menyalakannya. Server Kryfo mencarikan untukmu, jadi layanan GIF tidak pernah melihatmu.';

  @override
  String get shareChooseChat => 'Pilih obrolan';

  @override
  String get shareNoChats => 'Belum ada obrolan';

  @override
  String get shareNoOne => 'Tidak ada yang bisa diajak berbagi';

  @override
  String get shareCheckPhoto => 'Periksa foto ini';

  @override
  String get shareCheckVideo => 'Periksa video ini';

  @override
  String get shareSendCleanLine => 'Detail tersembunyinya dihapus dulu';

  @override
  String get shareCheckLine => 'Lihat isinya, langsung di ponsel ini';

  @override
  String shareFileOverLimit(String max) {
    return 'File bisa sampai $max. Yang ini lebih besar.';
  }

  @override
  String shareSendFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Kirim $count file ini?',
      one: 'Kirim file ini?',
    );
    return '$_temp0';
  }

  @override
  String sharePhotoTooBig(String size, String max) {
    return 'Foto ini $size. Kryfo menyiapkan foto hingga $max.';
  }

  @override
  String sharePhotoOverLimit(String size, String max) {
    return 'Setelah diperkecil, foto ini masih $size. File di chat ini bisa sampai $max.';
  }

  @override
  String get valveStillConnecting =>
      'Masih menyambung… Pesanmu akan terkirim begitu koneksi kembali.';

  @override
  String get valveCouldNotReconnect =>
      'Kryfo tidak bisa menyambung ulang. Memulai ulang akan memperbaikinya dan pesanmu tetap tersimpan.';

  @override
  String get valveRestartKryfo => 'Mulai ulang Kryfo';

  @override
  String get updateAvailable => 'Pembaruan tersedia';

  @override
  String updateReady(String version) {
    return 'Kryfo $version siap diunduh';
  }

  @override
  String get settingsCheckForUpdates => 'Periksa pembaruan';

  @override
  String get settingsCheckForUpdatesHint =>
      'Sekali sehari lewat Tor. Hanya menanyakan versi terbaru ke kryfo.app dan tidak mengirim apa pun tentang kamu.';

  @override
  String get settingsCheckNow => 'Periksa sekarang';

  @override
  String get settingsCheckNowBusy => 'Mengecek…';

  @override
  String get updateOpenPage => 'Buka halaman unduhan';

  @override
  String get updateNewest => 'Kamu sudah memakai Kryfo terbaru';

  @override
  String get updateCouldNotCheck => 'Tidak bisa memeriksa. Coba lagi nanti.';

  @override
  String get voiceDisguiseHere => 'Samarkan suaraku di sini';

  @override
  String get chatBlockScreenshots => 'Blokir tangkapan layar';

  @override
  String get chatShotsWhenTheyUpdate =>
      'Tersedia setelah dia memakai Kryfo terbaru di ponsel';

  @override
  String get chatShotsWhenTheyUpdateDesk => 'Tersedia di Kryfo untuk Android';

  @override
  String get chatShotsBothPhones =>
      'Kryfo memblokir tangkapan layar dan rekaman layar obrolan ini di kedua ponsel, juga menyalin, meneruskan, atau menyimpan pesan satu sama lain. Ini tidak bisa mencegah aplikasi yang diizinkan membaca layar, atau ponsel maupun aplikasi yang diubah untuk mengakalinya.';

  @override
  String get chatShotsBlocksBoth =>
      'Memblokir tangkapan layar dan rekaman layar di kedua ponsel, juga menyalin, meneruskan, atau menyimpan pesan satu sama lain. Ini tidak bisa mencegah aplikasi yang diizinkan membaca layar, atau ponsel maupun aplikasi yang diubah untuk mengakalinya.';

  @override
  String get chatShotsBlockedHere =>
      'Kryfo memblokir tangkapan layar di obrolan ini';

  @override
  String get chatShotsMenuNote =>
      'Menyalin, meneruskan, dan menyimpan pesannya mati di obrolan ini';

  @override
  String get chatShotsKeptOpen =>
      'Membuka filenya di aplikasi lain mati di obrolan ini';

  @override
  String searchKeptMatches(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString hasil · buka obrolan untuk melihatnya',
    );
    return '$_temp0';
  }

  @override
  String get savedKeptInChat =>
      'Disimpan dari obrolan yang memblokir tangkapan layar · buka obrolan untuk melihatnya';

  @override
  String get roomShotsMenuNote =>
      'Menyalin, meneruskan, dan menyimpan pesan orang lain mati di ruang ini';

  @override
  String get roomShotsKeptOpen =>
      'Membuka file orang lain di aplikasi lain mati di ruang ini';

  @override
  String get chatShotsYouTurnedOn =>
      'Kamu menyalakan blokir tangkapan layar. Menyalin, meneruskan, dan menyimpan pesan satu sama lain juga mati.';

  @override
  String get chatShotsYouTurnedOff => 'Kamu mematikan blokir tangkapan layar';

  @override
  String get chatNowPostQuantum =>
      'Pesan di obrolan ini sekarang memakai enkripsi pascakuantum';

  @override
  String chatShotsTheyTurnedOn(String name) {
    return '$name menyalakan blokir tangkapan layar. Menyalin, meneruskan, dan menyimpan pesan satu sama lain juga mati.';
  }

  @override
  String chatShotsTheyTurnedOff(String name) {
    return '$name mematikan blokir tangkapan layar';
  }

  @override
  String get roomShotsBlocked =>
      'Kryfo memblokir tangkapan layar dan rekaman layar ruang ini di setiap ponsel di dalamnya, juga menyalin, meneruskan, atau menyimpan pesan orang lain. Ini tidak bisa mencegah aplikasi yang diizinkan membaca layar, atau ponsel maupun aplikasi yang diubah untuk mengakalinya.';

  @override
  String get roomShotsBlockedDesk =>
      'Menyalin, meneruskan, dan menyimpan pesan satu sama lain mati di ruang ini. Kryfo untuk Android juga memblokir tangkapan layar dan rekaman layar.';

  @override
  String get roomShotsAlwaysOn =>
      'Selalu menyala di ruang, di setiap ponsel di dalamnya';

  @override
  String get roomShotsAlwaysOnDesk =>
      'Selalu menyala di ruang, di Kryfo untuk Android';

  @override
  String get homeShotsPerChat =>
      'Blokir tangkapan layar sekarang diatur per obrolan.';

  @override
  String get homeShotsTurnOnForAll => 'Nyalakan untuk semua obrolanmu?';

  @override
  String get homeShotsTurnOn => 'Nyalakan untuk semua';

  @override
  String get homeShotsLeaveOff => 'Biarkan mati';

  @override
  String get homeShotsTheySeeIt =>
      'Kryfo juga memblokirnya di ponsel lawan, dan menyalin, meneruskan, serta menyimpan pesan satu sama lain jadi mati. Dia akan melihat bahwa kamu menyalakannya.';

  @override
  String homeShotsTurnedOn(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Kryfo kini memblokir tangkapan layar di $countString obrolan',
    );
    return '$_temp0';
  }

  @override
  String get voiceDisguisedHere => 'Suaramu disamarkan di obrolan ini';

  @override
  String get voiceSlideUpToLock => 'Geser ke atas untuk mengunci';

  @override
  String get voiceStopRecording => 'Hentikan rekaman';

  @override
  String get voiceDeleteNote => 'Hapus pesan suara';

  @override
  String get voiceDisguised => 'Disamarkan';

  @override
  String get voiceYourVoice => 'Suaramu';

  @override
  String get voiceDisguiseThisNote => 'Samarkan pesan ini';

  @override
  String get voiceNotDisguised =>
      'Pesan ini tidak bisa disamarkan, jadi tidak dikirim';

  @override
  String get voiceNoRoom =>
      'Ruang kosong di ponsel ini tidak cukup. Kosongkan sedikit ruang, lalu coba lagi.';

  @override
  String get voiceNoRoomDesk =>
      'Ruang kosong di komputer ini tidak cukup. Kosongkan sedikit ruang, lalu coba lagi.';

  @override
  String get voiceNoRoomNotSent =>
      'Ruang kosong tidak cukup untuk menyamarkan pesan ini, jadi tidak dikirim';

  @override
  String get voiceDisguising => 'Sedang disamarkan';

  @override
  String get voiceLockedNotSent =>
      'Kryfo terkunci sebelum pesan suaramu terkirim, jadi pesan itu tidak dikirim';

  @override
  String get voiceNotSent => 'Pesan suaramu tidak dikirim';

  @override
  String get settingsDisguiseByDefault => 'Samarkan suaraku secara bawaan';

  @override
  String get settingsDisguiseByDefaultHint =>
      'Setiap obrolan bisa mengubahnya di menunya';

  @override
  String get fileInstallerLine =>
      'Ini file penginstal aplikasi. Instal aplikasi hanya dari orang yang kamu percaya.';

  @override
  String get fileAppInstaller => 'Penginstal aplikasi';

  @override
  String get fileSaveToDevice => 'Simpan ke perangkat';

  @override
  String get fileOpenHint => 'Dibuka di aplikasi lain';

  @override
  String get fileSaved => 'Tersimpan';

  @override
  String fileSavedIn(String place) {
    return 'Tersimpan di $place';
  }

  @override
  String get fileSavedUnchecked =>
      'Tersimpan, tapi Kryfo tidak bisa memeriksa salinannya';

  @override
  String get fileNotSaved => 'Gagal menyimpan file';

  @override
  String get fileNotSavedNoSpace =>
      'Tidak tersimpan: ruang di sana tidak cukup';

  @override
  String fileTooBig(String size, String max) {
    return 'File ini berukuran $size. Ukuran file maksimal $max.';
  }

  @override
  String get fileGoesAsItIs =>
      'File ini dikirim apa adanya. Kryfo hanya membersihkan JPEG, PNG, WebP, HEIC, AVIF, GIF, MP4, dan MOV.';

  @override
  String get voiceStoppedAtLimit =>
      'Pesan suara berhenti di 30 menit. Dengarkan dulu, lalu kirim.';

  @override
  String get gettingMessagesHelperBody =>
      'Servernya melihat alamat IP-mu dan kapan pesan datang.\nTidak pernah isinya. Seketika dan ringan.';

  @override
  String get gettingMessagesHelperUseOnion => 'Beralih ke Onion';

  @override
  String get gettingMessagesHelperSetUp => 'Siapkan';

  @override
  String get gettingMessagesHelperNote =>
      'Ada juga panggilan bangun palsu, jadi server aplikasi pembantu lebih sulit tahu kapan pesan asli masuk. Server pembantu milikmu sendiri memberi tahu relay kami alamatnya. Obrolan tersembunyi, ruang setelah beberapa ruang pertama, dan sesekali kontak biasa, kira-kira satu dari lima bulan, menunggu cek yang tetap dilakukan Kryfo setiap 15 menit.';

  @override
  String get gettingMessagesHelperOnionOnly => 'Butuh rute Privat';

  @override
  String get gettingMessagesHelperChecking => 'Mengecek…';

  @override
  String get gettingMessagesHelperRelayNotYet =>
      'Relay kami belum menyediakan ini';

  @override
  String get helperSheetNeedTitle => 'Kamu perlu aplikasi pembantu';

  @override
  String get helperSheetNeedLine =>
      'Aplikasi pembantu menjaga satu koneksi ringan untuk semua aplikasimu dan membangunkan Kryfo saat ada yang masuk. Aplikasi UnifiedPush apa pun bisa dipakai, ntfy pilihan yang baik untuk mulai.';

  @override
  String get helperSheetGetNtfy => 'Pasang ntfy';

  @override
  String get helperSheetOtherApps => 'Aplikasi pembantu lain';

  @override
  String get helperSheetPickTitle => 'Pilih aplikasi pembantu';

  @override
  String get helperSheetPickLine =>
      'Kryfo hanya memintanya membangunkan aplikasi. Pesanmu tidak pernah melewatinya.';

  @override
  String helperSheetSetUp(Object name) {
    return '$name sudah siap';
  }

  @override
  String helperSheetNoAnswer(Object name) {
    return '$name tidak menjawab. Coba lagi.';
  }

  @override
  String get homeHelperGoneTitle => 'Aplikasi pembantumu sudah tidak ada';

  @override
  String get homeHelperGoneLine =>
      'Kryfo mengecek setiap 15 menit sampai kamu memilih cara lain.';

  @override
  String get homeHelperGoneChoose => 'Pilih cara lain';

  @override
  String get homeHelperRelayTitle => 'Relay tidak lagi membangunkan Kryfo';

  @override
  String get gettingMessagesHelperRefused =>
      'Relay kami sedang tidak menerima sebagian pendaftaran dari ponsel ini. Obrolan itu datang bersama cek setiap 15 menit, dan Kryfo terus mencoba. Memilih aplikasi pembantu atau server lain juga bisa membantu.';

  @override
  String albumLabel(Object count) {
    return 'Album, $count item';
  }

  @override
  String albumCounter(Object at, Object total) {
    return '$at dari $total';
  }

  @override
  String albumMore(Object count) {
    return '$count lagi';
  }

  @override
  String get albumOnItsWay => 'Sedang dikirim';

  @override
  String get albumQuoted => 'Album';

  @override
  String get albumUnsendTitle => 'Tarik album ini?';

  @override
  String get mediaSendAddMore => 'Tambah lagi';

  @override
  String get mediaSendRemove => 'Hapus';

  @override
  String get mediaSendProtect => 'Lindungi dari tangkapan layar';

  @override
  String get mediaSendProtectedOn => 'Terlindung · tangkapan layar diblokir';

  @override
  String mediaSendUpTo(Object count) {
    return 'Maksimal $count sekaligus';
  }

  @override
  String get mediaSendVideo => 'Kirim video';

  @override
  String get requestSenderMediaLater =>
      'Foto dan file terbuka setelah dia menerimamu, supaya kalian berdua aman.';

  @override
  String get requestReceiverMediaLater =>
      'Foto dan file terbuka setelah kamu menerimanya, supaya kamu tetap aman.';

  @override
  String get groupEndedYou => 'Kamu mengakhiri grup ini';

  @override
  String groupEndedBy(Object name) {
    return '$name mengakhiri grup ini';
  }

  @override
  String get groupEndedBar => 'Grup ini sudah berakhir';

  @override
  String get groupInfoEndGroup => 'Akhiri grup';

  @override
  String get groupInfoEndThisGroup => 'Akhiri grup ini untuk semua?';

  @override
  String get groupInfoEndGroupLine =>
      'Grup ini dihapus untuk semua: pesan dan medianya dihapus dari ponsel setiap anggota yang sudah memperbarui aplikasinya.';

  @override
  String get groupInfoEndGroupLineDesk =>
      'Grup ini dihapus untuk semua: pesan dan medianya dihapus dari perangkat setiap anggota yang sudah memperbarui aplikasinya.';

  @override
  String get groupInfoDeleteGroup => 'Hapus grup';

  @override
  String get groupInfoDeleteThisGroup => 'Hapus grup ini?';

  @override
  String get groupInfoDeleteGroupLine =>
      'Grup yang sudah berakhir hilang dari daftar obrolanmu.';

  @override
  String get groupEndedOldNotice =>
      'Aku mengakhiri grup ini, jadi tidak ada yang bisa mengirim pesan di sini lagi. Perbarui Kryfo untuk melihatnya sudah berakhir.';

  @override
  String get groupInfoEndGroupDetail =>
      'Kryfo menghapusnya dari ponsel setiap anggota yang sudah memperbarui aplikasinya.';

  @override
  String get groupInfoEndGroupDetailDesk =>
      'Kryfo menghapusnya dari perangkat setiap anggota yang sudah memperbarui aplikasinya.';

  @override
  String get translateAction => 'Terjemahkan';

  @override
  String get translateShowOriginal => 'Lihat aslinya';

  @override
  String translateBarTo(Object language) {
    return 'Terjemahkan ke $language';
  }

  @override
  String get translateBarMore => 'Opsi terjemahan';

  @override
  String translateBarNever(Object language) {
    return 'Jangan tawarkan untuk $language';
  }

  @override
  String get translateBarHide => 'Sembunyikan di chat ini';

  @override
  String get translateWorking => 'Menerjemahkan…';

  @override
  String get translateFailed => 'Tidak bisa diterjemahkan';

  @override
  String translateFrom(Object language) {
    return 'Diterjemahkan dari $language';
  }

  @override
  String get translateLangZh => 'Tionghoa';

  @override
  String translatePackTitle(Object language) {
    return 'Terjemahan di ponsel ini: $language';
  }

  @override
  String translatePackTitleDesk(Object language) {
    return 'Terjemahan di komputer ini: $language';
  }

  @override
  String translatePackLine(Object language, Object size) {
    return 'Pesan diterjemahkan di ponsel ini dan tidak pernah keluar darinya. Untuk itu perlu paket bahasa $language, sekitar $size, diunduh sekali lewat Tor.';
  }

  @override
  String translatePackLineDesk(Object language, Object size) {
    return 'Pesan diterjemahkan di komputer ini dan tidak pernah keluar darinya. Untuk itu perlu paket bahasa $language, sekitar $size, diunduh sekali lewat Tor.';
  }

  @override
  String get translatePackNoLib => 'Terjemahan tidak berfungsi di ponsel ini.';

  @override
  String get translatePackNoLibDesk =>
      'Terjemahan tidak berfungsi di komputer ini.';

  @override
  String translateDownload(Object size) {
    return 'Unduh · sekitar $size';
  }

  @override
  String get translateDownloadAnyway => 'Tetap unduh sekarang';

  @override
  String get translateResume => 'Lanjutkan unduhan';

  @override
  String translateProgress(Object done, Object total) {
    return '$done dari $total';
  }

  @override
  String get translateFinishing => 'Memeriksa file…';

  @override
  String translateInstalled(Object size) {
    return 'Di ponsel ini · $size';
  }

  @override
  String translateInstalledDesk(Object size) {
    return 'Di komputer ini · $size';
  }

  @override
  String get translateNeedsWifi =>
      '“Hanya Wi-Fi” aktif, dan ponsel ini tidak tersambung ke Wi-Fi.';

  @override
  String get translateNeedsWifiDesk =>
      '“Hanya Wi-Fi” aktif, dan komputer ini tidak tersambung ke Wi-Fi.';

  @override
  String get translateFailNoTor =>
      'Tor belum tersambung. Paket hanya diunduh lewat Tor, jadi coba lagi setelah tersambung.';

  @override
  String get translateFailNetwork =>
      'Unduhan berhenti. Coba lagi dan unduhan lanjut dari titik terakhir.';

  @override
  String get translateFailBadFile =>
      'Ada file yang tidak cocok dengan yang diharapkan Kryfo, jadi file itu dibuang. Coba lagi.';

  @override
  String get translateFailNoEngine =>
      'Paket bahasa tidak bisa diunduh di ponsel ini.';

  @override
  String get translateFailNoEngineDesk =>
      'Paket bahasa tidak bisa diunduh di komputer ini.';

  @override
  String translatePaused(Object size) {
    return 'Dijeda · $size sejauh ini';
  }

  @override
  String get translateSettingsTitle => 'Terjemahan';

  @override
  String get translateSettingsRow => 'Terjemahkan pesan';

  @override
  String get translateSettingsHint => 'Di ponsel ini, tidak pernah di server';

  @override
  String get translateSettingsHintDesk =>
      'Di komputer ini, tidak pernah di server';

  @override
  String get translatePacksSection => 'Paket bahasa';

  @override
  String translateNotDownloaded(Object size) {
    return 'Belum diunduh · sekitar $size';
  }

  @override
  String get translateDownloading => 'Mengunduh lewat Tor';

  @override
  String get translateLanguagesSection => 'Bahasa';

  @override
  String get translateMyLanguages => 'Bahasa yang kubaca';

  @override
  String get translateMyLanguagesHint =>
      'Pesan dalam bahasa ini tidak ditawarkan untuk diterjemahkan. Bahasa aplikasi selalu termasuk.';

  @override
  String get translateInto => 'Terjemahkan ke';

  @override
  String get translateAppLanguage => 'Bahasa aplikasi';

  @override
  String get translateBehaviourSection => 'Unduhan dan obrolan';

  @override
  String get translateAutoDefault => 'Terjemahkan obrolan otomatis';

  @override
  String get translateAutoDefaultHint =>
      'Untuk obrolan yang belum kamu atur sendiri. Setiap obrolan bisa menyalakan atau mematikannya.';

  @override
  String get translateWifiOnly => 'Unduh paket hanya lewat Wi-Fi';

  @override
  String get translatePrivacyTitle => 'Yang tetap privat';

  @override
  String get translatePrivacyNote =>
      'Terjemahan terjadi di ponsel ini. Tidak ada pesan yang dikirim ke mana pun untuk diterjemahkan. Mengunduh paket memberi tahu server paket mana itu. Unduhannya lewat Tor, jadi server tidak tahu siapa yang meminta.';

  @override
  String get translatePrivacyNoteDesk =>
      'Terjemahan terjadi di komputer ini. Tidak ada pesan yang dikirim ke mana pun untuk diterjemahkan. Mengunduh paket memberi tahu server paket mana itu. Unduhannya lewat Tor, jadi server tidak tahu siapa yang meminta.';

  @override
  String get translateAutoInChat => 'Terjemahkan otomatis';

  @override
  String get translateAutoInChatHint =>
      'Pesan dalam bahasa lain tampil terjemahannya. Aslinya tinggal satu ketukan.';

  @override
  String get translateAlwaysChat => 'Selalu terjemahkan chat ini';

  @override
  String translateNeverDone(Object language) {
    return 'Pesan dalam $language tetap seperti aslinya';
  }

  @override
  String get translateUndo => 'Urungkan';

  @override
  String get translateNeverSection => 'Tidak pernah ditawarkan';

  @override
  String get translateOfferAllAgain => 'Tawarkan semua lagi';

  @override
  String get translateOfferAgain => 'Tawarkan lagi';

  @override
  String get translateOnHint => 'Ditawarkan di bawah pesan dalam bahasa lain';

  @override
  String get translatePrivacyKept =>
      'Terjemahan disimpan terenkripsi bersama chatnya di ponsel ini dan dihapus bersamanya.';

  @override
  String get translatePrivacyKeptDesk =>
      'Terjemahan disimpan terenkripsi bersama chatnya di komputer ini dan dihapus bersamanya.';

  @override
  String get translateOffDeletes =>
      'Mematikan ini menghapus terjemahan yang tersimpan.';

  @override
  String get bridgesNoneUntilOnion => 'Tidak ada sampai Onion aktif';

  @override
  String get bridgesRelayThisNetworkSees =>
      'Cepat bisa tembus di tempat Tor diblokir, tapi jaringan ini bisa melihat kamu terhubung ke Kryfo.';

  @override
  String get settingsLicences => 'Lisensi';

  @override
  String get settingsLicencesValue => 'Bahan pembuat Kryfo';

  @override
  String get licencesKryfoLine =>
      'Kryfo adalah perangkat lunak bebas di bawah GNU General Public License, versi 3 atau yang lebih baru. Siapa pun boleh membaca, mengubah, dan membagikan kodenya.';

  @override
  String get licencesSourceCode => 'Kode sumber';

  @override
  String get licencesSignalTitle => 'Protokol Signal';

  @override
  String licencesSignalLine(String version) {
    return 'Kryfo memuat libsignal $version buatan Signal, di bawah GNU Affero General Public License, versi 3. Kode sumbernya ada di github.com/signalapp/libsignal dan di samping setiap rilis Kryfo.';
  }

  @override
  String get licencesAgplText => 'GNU AGPL 3.0, teks lengkap';

  @override
  String get licencesSignalSource => 'Kode sumber libsignal';

  @override
  String get licencesParts => 'Komponen sumber terbuka';

  @override
  String get licencesInSignal => 'Di pustaka Signal';

  @override
  String get licencesInApp => 'Di aplikasi';

  @override
  String licencesPartCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString komponen',
    );
    return '$_temp0';
  }

  @override
  String get licencesGplText => 'GNU GPL 3.0, teks lengkap';

  @override
  String get licencesInEngine => 'Di mesin jaringan';

  @override
  String get licencesLoadFailed => 'Tidak dapat dimuat';

  @override
  String get licencesInVoice => 'Di transkrip suara';

  @override
  String get licencesInTranslation => 'Di terjemahan pesan';

  @override
  String get settingsCopyLinkHint => 'Salin tautan';

  @override
  String get motionNoRelayYet => 'BELUM ADA RELAY';

  @override
  String get motionTheRouteIsUp => 'Rute sudah terbentuk';

  @override
  String get motionMessagesGoOnceARelay =>
      'Pesan terkirim begitu ada relay yang menjawab lewat rute ini.';

  @override
  String get motionOffline => 'OFFLINE';

  @override
  String get motionNoNetwork => 'Tidak ada jaringan';

  @override
  String get motionTorPicksUpAgain =>
      'Tanpa jaringan tidak ada yang terkirim. Tor lanjut lagi begitu jaringan kembali.';

  @override
  String deliveryModeStateLast(String state, Object last) {
    return '$state · $last';
  }

  @override
  String homeWaitingState(int count, String state) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count menunggu · $state',
    );
    return '$_temp0';
  }

  @override
  String get settingsIconAndNotifications => 'Ikon dan notifikasi';

  @override
  String iconSettingsValue(String icon) {
    return '$icon, notifikasi polos';
  }

  @override
  String get iconSectionTitle => 'Ikon aplikasi';

  @override
  String get iconHint =>
      'Layar utama dan daftar aplikasimu menampilkan ikon dan nama ini, bukan Kryfo.';

  @override
  String get iconHintKryfo =>
      'Pilih ikon dan nama yang biasa saja untuk layar utama dan daftar aplikasimu.';

  @override
  String get iconWhatChanges => 'Apa yang berubah';

  @override
  String iconConfirmTitle(String name) {
    return 'Ganti ikon menjadi $name?';
  }

  @override
  String iconConfirmLine(String name) {
    return 'Kryfo tertutup lalu terbuka lagi. Kalau ikonnya hilang dari layar utama, cari $name di aplikasimu dan taruh lagi.';
  }

  @override
  String get iconConfirmButton => 'Ganti ikon';

  @override
  String get iconNoPinLine =>
      'Siapa pun yang mengetuknya akan melihat Kryfo. Pasang PIN aplikasi agar yang terlihat papan PIN.';

  @override
  String get iconSetPin => 'Buat PIN';

  @override
  String iconChanged(String name) {
    return 'Ikon diganti menjadi $name';
  }

  @override
  String iconPreviewLabel(String name) {
    return 'Layar utamamu akan menampilkan $name';
  }

  @override
  String iconButtonLabel(String name) {
    return '$name, ikon aplikasi';
  }

  @override
  String get notifShowAll => 'Nama dan pesan';

  @override
  String get notifShowNew => 'Hanya “Pesan baru”';

  @override
  String get notifShowPlain => 'Polos';

  @override
  String get notifPlainHint =>
      'Tanpa nama, tanpa pesan, tanpa warna Kryfo. Ikon netral dan satu baris.';

  @override
  String get notifPlainLine => 'Ada yang baru';

  @override
  String get notifPlainChannel => 'Pemberitahuan';

  @override
  String get notifHeaderLimit =>
      'Bagian atas setiap notifikasi tetap bertuliskan Kryfo. Android tidak mengizinkan aplikasi mengubahnya.';

  @override
  String get gettingMessagesWhatShows => 'Yang ditampilkan notifikasi';

  @override
  String get iconSheetChangesTitle => 'Yang berubah';

  @override
  String get iconSheetChanges =>
      'Ikon dan nama di layar utama dan daftar aplikasimu, menu bagikan, dan tampilan aplikasi terbuka. Dengan Polos, juga isi notifikasi.';

  @override
  String get iconSheetStaysTitle => 'Yang tetap Kryfo';

  @override
  String get iconSheetStays =>
      'Baris atas setiap notifikasi, halaman setelan dan baterai ponselmu, toko aplikasi, dan Kryfo sendiri saat seseorang membukanya.';

  @override
  String get iconSheetGlance =>
      'Ini cukup untuk sekilas pandang ke layar utama. Ini tidak menyembunyikan Kryfo dari orang yang memeriksa setelan ponselmu.';

  @override
  String get iconSheetPrivateSpace =>
      'Ponselmu mungkin punya cara sendiri untuk menyembunyikan aplikasi: ruang pribadi, di setelannya.';

  @override
  String get iconSheetSecureFolder =>
      'Ponselmu mungkin punya cara sendiri untuk menyembunyikan aplikasi: Folder Aman, di setelannya.';

  @override
  String get iconSheetXiaomi =>
      'Ponselmu mungkin punya cara sendiri untuk menyembunyikan aplikasi: aplikasi tersembunyi, di setelannya.';

  @override
  String get androidIconNotes => 'Catatan';

  @override
  String get androidIconWeather => 'Cuaca';

  @override
  String get androidIconTasks => 'Tugas';

  @override
  String get androidIconNews => 'Berita';

  @override
  String get androidServiceTitlePlain => 'Aktif';

  @override
  String get lockStateUnlockPlain => 'Buka kunci';

  @override
  String get iconSheetOthers =>
      'Aplikasi di ponselmu tetap bisa melihat bahwa Kryfo terpasang, dan dialog serta permintaan Android sendiri bisa menampilkan namanya.';

  @override
  String get iconSheetSaves =>
      'Selama ikon polos aktif, foto, video, dan file baru disimpan dengan nama biasa di folder ponselmu yang biasa. Yang sudah tersimpan tetap di tempatnya.';

  @override
  String get deliveryModeGooglePush => 'Push Google';

  @override
  String get deliveryModeGoogle => 'Google';

  @override
  String get notificationsLead =>
      'Bagaimana pesan baru sampai ke ponsel ini, bunyinya, dan apa yang ditampilkan. Kamu bisa mengubahnya kapan saja.';

  @override
  String get notificationsLeadDesk =>
      'Bagaimana pesan baru sampai ke komputer ini, bunyinya, dan apa yang ditampilkan. Kamu bisa mengubahnya kapan saja.';

  @override
  String get notificationsHowTheyReachYou => 'Cara pesan sampai padamu';

  @override
  String get notificationsRecommended => 'Disarankan';

  @override
  String get notificationsGoogleBody =>
      'Google melihat kapan ponselmu bangun.\nTidak pernah siapa yang menulis atau apa isinya.\nSeketika dan hemat baterai.';

  @override
  String get notificationsGoogleOnFast =>
      'Di Cepat, server kami melihat IP-mu saat membangunkan ponselmu, tapi kami tidak pernah menyimpannya.';

  @override
  String get notificationsGoogleStarting => 'Menyalakan…';

  @override
  String get notificationsGoogleNoStart =>
      'Push Google tidak bisa dimulai. Periksa koneksi lalu coba lagi.';

  @override
  String get notificationsGoogleNote =>
      'Ada juga panggilan bangun palsu, jadi Google lebih sulit tahu kapan pesan asli masuk. Relay kami hanya menyimpan alamat yang tidak bisa ia hubungkan satu sama lain. Layanan push berjalan di server kedua kami. Kedua server itu bersama-sama bisa menghubungkannya, dan dengan bantuan Google ke akun Google-mu. Menyita satu saja tidak cukup, tapi kami menjalankan keduanya, jadi kami bisa. Kalau itu penting bagimu, pilih cara lain. Obrolan tersembunyi, ruang setelah beberapa ruang pertama, dan sesekali kontak biasa, kira-kira satu dari lima bulan, menunggu cek yang tetap dilakukan Kryfo setiap 15 menit.';

  @override
  String get notificationsGoogleRefused =>
      'Relay kami sedang tidak menerima sebagian pendaftaran dari ponsel ini. Obrolan itu datang dengan cek setiap 15 menit, dan Kryfo terus mencoba.';

  @override
  String get notificationsSoundAndVibration => 'Suara dan getar';

  @override
  String get notificationsSoundHint => 'Di pengaturan Android sendiri';

  @override
  String get notificationsEachShows => 'Setiap notifikasi menampilkan';

  @override
  String get notificationsBatteryTips => 'Tips baterai';

  @override
  String get notificationsBatteryAllowed => 'Diizinkan';

  @override
  String get notificationsBatteryNotYet => 'Tidak diizinkan';

  @override
  String get notificationsMakerSwitch => 'Tombol dari pembuat ponselmu';

  @override
  String get onboardingHowYourMessages => 'Cara pesanmu *berjalan*.';

  @override
  String get onboardingRouteLead =>
      'Kamu bisa mengubahnya kapan saja di Pengaturan.';

  @override
  String get onboardingRoutePrivateCost =>
      'Lewat Tor. Satu pesan butuh beberapa detik.';

  @override
  String get onboardingRoutePrivateGain =>
      'Tak ada yang tahu alamat IP-mu, bahkan server kami.';

  @override
  String get onboardingRouteFastCost =>
      'Server kami melihat alamat IP-mu selama kamu terhubung.\nJaringanmu bisa melihat kamu memakai Kryfo.';

  @override
  String get onboardingRouteFastGain =>
      'Melewati Tor: lebih cepat dan lebih hemat baterai.';

  @override
  String get onboardingRouteBlockedLead =>
      'Kryfo tetap di Tor, lewat jembatan bila perlu.\nCepat ada di Pengaturan kalau kamu butuh.';

  @override
  String get onboardingRouteBlockedGain =>
      'Mencari jalan sendiri melewati blokir.';

  @override
  String get onboardingDeliveryHeadline => 'Kapan pesan *sampai*.';

  @override
  String get onboardingDeliveryLead =>
      'Kamu bisa mengubahnya kapan saja di Notifikasi.';

  @override
  String get homeGoogleTitle => 'Push Google sudah ada';

  @override
  String get homeGoogleLine =>
      'Seketika dan hemat baterai. Google bisa melihat kapan ponselmu dibangunkan, tidak pernah siapa yang menulis atau apa isinya.';

  @override
  String get homeGoogleUse => 'Pakai';

  @override
  String get homeGoogleOn => 'Push Google menyala';

  @override
  String get homeGoogleGoneTitle => 'Push Google tidak tersedia';

  @override
  String get appNotificationsLink => 'Notifikasi →';

  @override
  String devGooglePushes(int got, int low) {
    return 'Push Google $got · diturunkan $low';
  }

  @override
  String get passFieldLabel => 'Frasa sandi';

  @override
  String get padUseLetters => 'Pakai huruf';

  @override
  String get padUseDigits => 'Pakai angka';

  @override
  String get passWeak => 'Lemah';

  @override
  String get passFair => 'Cukup';

  @override
  String get passStrong => 'Kuat';

  @override
  String passStrengthIs(Object level) {
    return 'Kekuatan: $level';
  }

  @override
  String get lockKeyBusy =>
      'Chip keamanan ponsel sedang sibuk. Coba lagi sebentar lagi.';

  @override
  String get lockKeyLocked =>
      'Buka kunci ponselmu sekali dengan PIN ponsel itu sendiri, lalu coba lagi.';

  @override
  String get lockKeyWaiting => 'Chip keamanan ponsel masih memeriksa';

  @override
  String get lockKeyLost =>
      'Ponsel ini kehilangan kunci yang memeriksa PIN-mu, jadi beberapa PIN mungkin tidak bisa membuka. Kryfo bisa diatur ulang lalu cadangan dipulihkan.';

  @override
  String get lockKeyReset => 'Atur ulang Kryfo';

  @override
  String get lockKeyResetTitle => 'Atur ulang Kryfo?';

  @override
  String get lockKeyResetLine =>
      'Semua isi Kryfo di ponsel ini dihapus dan Kryfo ditutup. Setelah itu kamu bisa memulihkan cadangan. Obrolan tersembunyi hanya kembali dari cadangan yang dibuat saat obrolan itu terbuka.';

  @override
  String get lockKeyResetSureTitle => 'Ini tidak bisa dibatalkan';

  @override
  String get lockKeyResetSureLine =>
      'Semua obrolan, kunci, dan pengaturan Kryfo di ponsel ini hilang sekarang.';

  @override
  String get lockKeyResetSure => 'Hapus semuanya';

  @override
  String get flowVaultPassLine =>
      'Minimal 12 karakter. Keyboard ponsel melihat apa yang kamu ketik, jadi pakai keyboard yang tidak mempelajari atau menyinkronkan kata.';

  @override
  String get flowVaultPassLineDesk =>
      'Minimal 12 karakter. Pakai yang tidak kamu pakai di tempat lain.';

  @override
  String get flowVaultPassAgain => 'Frasa sandi yang sama sekali lagi';

  @override
  String get cardTitle => 'Selesaikan pembaruan keamanan';

  @override
  String get cardLine =>
      'Kalau kamu memakai PIN lain, ketik masing-masing sekali di sini.';

  @override
  String get cardType => 'Ketik PIN';

  @override
  String get cardAnswer =>
      'Sudah. Ketik yang lain, atau ketuk Selesai kalau sudah.';

  @override
  String get keyLine =>
      'PIN-mu hanya berfungsi di ponsel ini. Kalau suatu saat ponsel kehilangan kunci yang memeriksanya, kamu harus mengatur ulang Kryfo dan memulihkan cadangan. Obrolan tersembunyi hanya kembali dari cadangan yang dibuat saat obrolan itu terbuka.';

  @override
  String get keyLineUnlocked =>
      'PIN-mu hanya berfungsi di ponsel ini, dan hanya saat ponsel tidak terkunci. Kalau suatu saat ponsel kehilangan kunci yang memeriksanya, kamu harus mengatur ulang Kryfo dan memulihkan cadangan. Obrolan tersembunyi hanya kembali dari cadangan yang dibuat saat obrolan itu terbuka.';

  @override
  String get keyLineScreenLock =>
      'Pasang kunci layar di ponselmu supaya perlindungan ini tetap berlaku saat ponsel terkunci.';

  @override
  String get fileServerTryLater =>
      'Server file sedang penuh. Coba lagi sebentar lagi.';

  @override
  String fileTooBigUntilUpdate(String size, String max) {
    return 'File ini berukuran $size. Di chat ini ukuran file maksimal $max sampai semua orang memperbarui Kryfo.';
  }

  @override
  String get fileDayLimit =>
      'Hari ini kamu sudah mengirim banyak file besar. Coba lagi besok.';

  @override
  String get mediaProgressPreparing => 'Menyiapkan · biarkan aplikasi terbuka';

  @override
  String get groupShotsBlocksAll =>
      'Memblokir tangkapan layar dan rekaman layar di setiap ponsel dalam grup ini, juga menyalin, meneruskan, atau menyimpan pesan satu sama lain. Ini tidak bisa mencegah aplikasi yang diizinkan membaca layar, atau ponsel maupun aplikasi yang diubah untuk mengakalinya.';

  @override
  String get groupShotsBlocksAllDesk =>
      'Mematikan menyalin, meneruskan, dan menyimpan pesan satu sama lain di sini. Kryfo untuk Android juga memblokir tangkapan layar dan rekaman layar.';

  @override
  String get groupShotsStartsWhenAll =>
      'Menunggu semua orang di sini bisa memblokir tangkapan layar di perangkatnya';

  @override
  String get groupShotsOnForAll => 'Menyala untuk semua orang di sini';

  @override
  String get groupShotsOnForAllDesk => 'Menyala di Kryfo untuk Android';

  @override
  String get groupShotsOffAdminOnly =>
      'Mati. Hanya admin yang bisa mengubahnya';

  @override
  String get groupShotsWaitAdminOnly =>
      'Menunggu semua orang di sini bisa memblokir tangkapan layar di perangkatnya. Hanya admin yang bisa mengubahnya';

  @override
  String get groupShotsOnAdminOnly =>
      'Menyala untuk semua orang di sini. Hanya admin yang bisa mengubahnya';

  @override
  String get groupShotsOnAdminOnlyDesk =>
      'Menyala di Kryfo untuk Android. Hanya admin yang bisa mengubahnya';

  @override
  String groupShotsWaitingFor(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Menunggu $countString orang',
    );
    return '$_temp0';
  }

  @override
  String get groupShotsWaitingTitle => 'Belum tercakup';

  @override
  String get groupShotsWaitingHint =>
      'Blokir tangkapan layar berlaku untuk semua orang setelah perangkat orang-orang ini bisa memblokir tangkapan layar. Ketuk seseorang untuk mengeluarkannya dari grup.';

  @override
  String get groupShotsNeedsUpdate =>
      'Belum bisa memblokir tangkapan layar di perangkatnya, atau belum online sejak itu';

  @override
  String get groupShotsBlockedByYou => 'Kamu blokir';

  @override
  String get groupShotsYouTurnedOnWait =>
      'Kamu menyalakan blokir tangkapan layar. Ini berlaku untuk semua orang setelah semua di sini bisa memblokir tangkapan layar di perangkatnya.';

  @override
  String groupShotsTheyTurnedOnWait(String name) {
    return '$name menyalakan blokir tangkapan layar. Ini berlaku untuk semua orang setelah semua di sini bisa memblokir tangkapan layar di perangkatnya.';
  }

  @override
  String get groupShotsStarted =>
      'Blokir tangkapan layar menyala untuk semua orang di sini. Menyalin, meneruskan, dan menyimpan pesan satu sama lain juga mati.';

  @override
  String get groupShotsStartedDesk =>
      'Blokir tangkapan layar menyala di Kryfo untuk Android. Menyalin, meneruskan, dan menyimpan pesan satu sama lain juga mati.';

  @override
  String get groupShotsPaused =>
      'Seseorang di sini belum bisa memblokir tangkapan layar di perangkatnya. Ini berlaku lagi untuk semua orang setelah dia bisa.';

  @override
  String get groupShotsCantYet => 'Belum bisa memblokir tangkapan layar';

  @override
  String get groupShotsAddTitle => 'Tetap tambahkan?';

  @override
  String get groupShotsAddPauses =>
      'Blokir tangkapan layar belum berlaku untuk semua orang di sini sampai mereka bisa memblokirnya di perangkatnya.';

  @override
  String get groupShotsLeaveStays =>
      'Blokir tangkapan layar tetap seperti sekarang.';

  @override
  String get groupShotsBlockedHere =>
      'Kryfo memblokir tangkapan layar di grup ini';

  @override
  String get groupShotsBlockedHereDesk =>
      'Menyalin, meneruskan, dan menyimpan mati di grup ini';

  @override
  String get groupShotsMenuNote =>
      'Menyalin, meneruskan, dan menyimpan pesan orang lain mati di grup ini';

  @override
  String get groupShotsKeptOpen =>
      'Membuka file orang lain di aplikasi lain mati di grup ini';

  @override
  String get groupShotsOldNotice =>
      'Aku menyalakan blokir tangkapan layar di grup ini. Kryfo-mu belum bisa melakukannya, jadi tolong perbarui.';

  @override
  String get captureShotTaken =>
      'Tangkapan layar diambil. Tidak ada orang lain yang diberi tahu.';

  @override
  String get captureRecording =>
      'Layar ini sedang direkam. Tidak ada orang lain yang diberi tahu.';

  @override
  String get settingsDevices => 'Perangkat';

  @override
  String get devicesLinkedDevices => 'Perangkat tertaut';

  @override
  String get devicesThisPhoneOnly => 'Hanya ponsel ini';

  @override
  String get devicesThisPhoneOnlyDesk => 'Hanya komputer ini';

  @override
  String get devicesNameSeparator => ', ';

  @override
  String get devicesThisPhone => 'Ponsel ini';

  @override
  String get devicesThisPhoneDesk => 'Komputer ini';

  @override
  String get devicesOnlyThisPhone =>
      'Hanya ponsel ini yang bisa menautkan atau menghapus perangkat';

  @override
  String get devicesOnlyThisPhoneDesk =>
      'Hanya komputer ini yang bisa menautkan atau menghapus perangkat';

  @override
  String devicesLinkedOn(Object date) {
    return 'Ditautkan $date';
  }

  @override
  String get devicesUsedToday => 'Dipakai hari ini';

  @override
  String get devicesUsedThisWeek => 'Dipakai minggu ini';

  @override
  String get devicesUsedThisMonth => 'Dipakai bulan ini';

  @override
  String get devicesNotUsedYet => 'Belum dipakai';

  @override
  String devicesUnlinksSoon(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Terlepas dalam $daysString hari jika tidak kamu buka',
      one: 'Terlepas besok jika tidak kamu buka',
      zero: 'Terlepas hari ini jika tidak kamu buka',
    );
    return '$_temp0';
  }

  @override
  String get devicesEmptyTitle => 'Kryfo di komputermu';

  @override
  String get devicesEmptyLine =>
      'Tautkan komputer untuk membaca dan mengirim pesanmu dari sana.';

  @override
  String get devicesContactsSeeNothing =>
      'Aplikasi kontakmu tidak menampilkan perangkatmu.';

  @override
  String get devicesUnusedRule =>
      'Perangkat yang tidak kamu buka selama 30 hari akan terlepas sendiri dan menghapus obrolanmu darinya.';

  @override
  String get devicesFull =>
      'Semua tempat perangkatmu sudah terpakai. Hapus satu untuk menautkan yang lain.';

  @override
  String get devicesLinkADevice => 'Tautkan perangkat';

  @override
  String get devicesRemoveAll => 'Hapus semua perangkat lain';

  @override
  String get devicesRemoveAllTitle => 'Hapus semua perangkat lain?';

  @override
  String get devicesRemoveAllLine =>
      'Begitu aplikasi kontakmu menerima perubahannya, perangkat itu berhenti menerima pesan baru dan tidak bisa mengirim atas namamu. Ponsel ini menyimpan semuanya.';

  @override
  String get devicesRemoveAllYes => 'Hapus semua';

  @override
  String get devicesRemovedAll => 'Sekarang hanya ponsel ini';

  @override
  String devicesRemoveTitle(Object name) {
    return 'Hapus $name?';
  }

  @override
  String get devicesRemoveLine =>
      'Begitu aplikasi kontakmu menerima perubahannya, perangkat itu berhenti menerima pesan baru dan tidak bisa mengirim atas namamu. Obrolanmu terhapus darinya saat ia online lagi. Perangkat yang sudah diutak-atik orang bisa menyimpan apa yang sudah ada di dalamnya.';

  @override
  String get devicesRemove => 'Hapus';

  @override
  String devicesRemoved(Object name) {
    return '$name dihapus';
  }

  @override
  String get devicesRename => 'Ganti nama';

  @override
  String devicesRenameTitle(Object name) {
    return 'Ganti nama $name';
  }

  @override
  String get devicesRenameLine =>
      'Hanya kamu yang melihat nama ini. Kontakmu tidak pernah melihatnya.';

  @override
  String get devicesNameComputer => 'Komputer';

  @override
  String get devicesDeviceCode => 'Kode perangkat';

  @override
  String get devicesDeviceCodeLine =>
      'Kode yang sama muncul di perangkat itu sendiri, di Pengaturan.';

  @override
  String get devicesLinkStep1 =>
      'Buka Kryfo di komputermu. Kryfo akan menampilkan kode.';

  @override
  String get devicesLinkStep2 => 'Pindai kodenya dengan ponsel ini.';

  @override
  String get devicesLinkStep3 =>
      'Pastikan kedua layar menampilkan enam angka yang sama.';

  @override
  String get devicesHistory => 'Riwayat';

  @override
  String get devicesHistoryCopy => 'Salin obrolanku';

  @override
  String get devicesHistoryCopyHint =>
      'Pesanmu, dengan foto, video, dan pesan suara dari 30 hari terakhir.';

  @override
  String get devicesHistoryNone => 'Hanya kontak dan grup';

  @override
  String get devicesHistoryNoneHint => 'Semuanya pindah tanpa pesan apa pun.';

  @override
  String get devicesSkipMedia => 'Lewati foto dan video';

  @override
  String get devicesSkipMediaHint =>
      'Hanya teksnya yang disalin. Lebih cepat, dan lebih sedikit yang disimpan di perangkat.';

  @override
  String get devicesHiddenStay =>
      'Obrolan tersembunyi dan umpan tetap di ponsel ini.';

  @override
  String get devicesHiddenStayDesk =>
      'Obrolan tersembunyi dan umpan tetap di komputer ini.';

  @override
  String get devicesScanCode => 'Pindai kode';

  @override
  String get devicesLinkReaching => 'Menghubungi perangkat';

  @override
  String get devicesLinkReachingLine =>
      'Biarkan Kryfo terbuka di keduanya. Lewat Tor ini bisa makan waktu semenit.';

  @override
  String get devicesLinkCompare => 'Apakah angkanya sama?';

  @override
  String get devicesLinkCompareLine =>
      'Perangkat baru juga menampilkan enam angka. Tautkan hanya jika angkanya sama.';

  @override
  String get devicesLinkMatch => 'Sama';

  @override
  String get devicesLinkNoMatch => 'Tidak sama';

  @override
  String get devicesLinkLinking => 'Menautkan';

  @override
  String get devicesLinkLinkingLine =>
      'Menyiapkan perangkat baru. Biarkan keduanya terbuka.';

  @override
  String get devicesLinkDone => 'Perangkat tertaut';

  @override
  String get devicesLinkDoneLine =>
      'Perangkat ini ada di Perangkat tertaut. Di sana kamu bisa mengganti nama atau menghapusnya.';

  @override
  String get devicesLinkUnreached => 'Tidak bisa menghubungi perangkat';

  @override
  String get devicesLinkUnreachedLine =>
      'Pastikan Kryfo terbuka di perangkat baru dan menampilkan kodenya, lalu coba lagi.';

  @override
  String get devicesLinkStopped => 'Tidak ada yang tertaut';

  @override
  String get devicesLinkStoppedLine =>
      'Angkanya harus sama. Mulai lagi dengan kode baru.';

  @override
  String get devicesLinkInterruptedLine =>
      'Penautan terputus. Mulai lagi dengan kode baru.';

  @override
  String get devicesLinkAlreadyLine =>
      'Komputer ini sudah tertaut. Hapus di Perangkat tertaut, lalu tautkan lagi.';

  @override
  String get scanLinkTitle => 'Pindai kode perangkat';

  @override
  String get scanLinkPoint => 'Arahkan ke kode di perangkat baru';

  @override
  String get scanLinkNotOne => 'Itu bukan kode tautan';

  @override
  String get onboardingLinkToMyPhone => 'Tautkan ke ponselku';

  @override
  String get joinTitle => 'Tautkan ke ponselmu';

  @override
  String get joinStep1 => 'Buka Kryfo di ponselmu.';

  @override
  String get joinStep2 =>
      'Buka Setelan, lalu Perangkat tertaut, lalu Tautkan perangkat.';

  @override
  String get joinStep3 => 'Pindai kode ini dengan ponselmu.';

  @override
  String get joinWaiting => 'Menunggu ponselmu';

  @override
  String get joinPreparing => 'Menyiapkan kodemu';

  @override
  String get joinPreparingLine =>
      'Kryfo sedang terhubung. Kodemu muncul begitu komputer ini online.';

  @override
  String get joinPreparingSlow =>
      'Mulai pertama kali bisa makan waktu satu atau dua menit selagi Tor terhubung.';

  @override
  String get homeLinkedChatsComing =>
      'Obrolanmu masih berdatangan dari ponselmu.';

  @override
  String get joinCodeLife => 'Kode berlaku sepuluh menit.';

  @override
  String get joinCompareLine =>
      'Ponselmu juga menampilkan enam angka. Lanjutkan hanya jika angkanya sama.';

  @override
  String get joinLinking => 'Menautkan ke ponselmu';

  @override
  String get joinLinkingLine =>
      'Biarkan Kryfo terbuka di ponselmu sampai selesai.';

  @override
  String get joinDone => 'Tertaut ke ponselmu';

  @override
  String get joinDoneLine =>
      'Pesan baru kini juga sampai ke perangkat ini. Nomor kunci akunmu:';

  @override
  String get joinOpen => 'Buka Kryfo';

  @override
  String get joinUnreached => 'Tidak bisa menghubungi ponselmu';

  @override
  String get joinUnreachedLine =>
      'Pastikan ponselmu online dan Kryfo terbuka, lalu coba kode baru.';

  @override
  String get devicesNewNotice => 'Perangkat baru tertaut';

  @override
  String devicesNewNoticeLine(Object name, Object date) {
    return '$name ditautkan ke akunmu pada $date. Buka Perangkat tertaut untuk melihatnya.';
  }

  @override
  String get devicesNewNoticeMany => 'Perangkat baru tertaut';

  @override
  String devicesNewNoticeManyLine(Object names) {
    return '$names ditautkan ke akunmu. Buka Perangkat tertaut untuk melihatnya.';
  }

  @override
  String get devicesNewNoticeOpen => 'Buka';

  @override
  String get settingsLinkedToLine =>
      'Tertaut ke ponselmu. Cadangan dan undangan tetap di ponsel.';

  @override
  String get devicesYourPhone => 'Ponselmu';

  @override
  String get desktopLockTitle => 'Kryfo terkunci';

  @override
  String get desktopLockBody => 'Ketik frasa sandi untuk komputer ini.';

  @override
  String get desktopLockNewTitle => 'Kunci Kryfo di komputer ini';

  @override
  String get desktopLockNewBody =>
      'Kryfo akan meminta frasa sandi ini setiap kali dibuka. Frasa ini mengunci pesan, foto, pesan suara, file, kontak, dan kuncimu di komputer ini.';

  @override
  String get desktopLockHonest =>
      'Siapa pun yang menyalin folder Kryfo bisa mencoba frasa sandi di komputernya sendiri, secepat komputer itu mampu. Empat kata acak atau lebih akan bertahan. Frasa sandi yang pendek tidak.';

  @override
  String get desktopLockForgot =>
      'Tanpa frasa sandi, tidak ada pesan, file, atau kuncimu di sini yang bisa dibuka, bahkan oleh kami.';

  @override
  String get desktopLockField => 'Frasa sandi';

  @override
  String get desktopLockRepeat => 'Frasa sandi yang sama sekali lagi';

  @override
  String get desktopLockSet => 'Kunci dengan frasa sandi ini';

  @override
  String get desktopLockOpen => 'Buka Kryfo';

  @override
  String desktopLockShort(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Minimal $countString karakter';
  }

  @override
  String get desktopLockMismatch => 'Kedua frasa sandi tidak sama';

  @override
  String get desktopLockWrong => 'Itu bukan frasa sandinya';

  @override
  String get desktopLockFailed =>
      'Kryfo tidak bisa membuka kuncinya di sini. Coba buka lagi.';

  @override
  String get desktopTrayQuit => 'Keluar dari Kryfo';

  @override
  String get desktopTrayTip => 'Kryfo berjalan dan menerima pesan';

  @override
  String get desktopTrayLockedTip => 'Buka Kryfo untuk mulai menerima pesan';

  @override
  String get desktopTrayStillRunning =>
      'Kryfo tetap berjalan di area notifikasi. Untuk keluar, gunakan ikonnya di area notifikasi.';

  @override
  String get desktopRunSection => 'Di komputer ini';

  @override
  String get desktopTrayRow => 'Tetap berjalan di area notifikasi';

  @override
  String get desktopTrayHint => 'Pesan terus masuk meski jendela ditutup.';

  @override
  String get desktopTrayOffLine =>
      'Menutup jendela akan menutup Kryfo.\nPesan masuk saat kamu membukanya lagi.';

  @override
  String get desktopTrayNoneLine =>
      'Desktop ini tidak punya ikon di area notifikasi.\nMenutup jendela akan menutup Kryfo.';

  @override
  String get desktopStartRow => 'Mulai bersama komputer';

  @override
  String get desktopStartHint =>
      'Kryfo mulai di area notifikasi saat kamu masuk ke komputer ini.';

  @override
  String get desktopStartRefused =>
      'Komputer ini tidak mengizinkan Kryfo ikut mulai.\nKryfo terbuka saat kamu sendiri membukanya.';

  @override
  String get desktopStartHeldOff =>
      'Windows mematikan Kryfo di aplikasi startup-nya.\nNyalakan di Pengaturan Windows, Aplikasi, Startup.';

  @override
  String get desktopMicBlocked =>
      'Kryfo bisa merekam setelah Windows mengizinkan aplikasi desktop memakai mikrofon, di Pengaturan, Privasi & keamanan, Mikrofon.';

  @override
  String get desktopMicNone => 'Sambungkan mikrofon untuk merekam pesan suara.';

  @override
  String get desktopNoCamera =>
      'Kryfo belum bisa memakai kamera di komputer ini. Pakai tautan atau kodenya saja.';

  @override
  String get desktopAlreadyOpen => 'Kryfo sudah terbuka di komputer ini.';

  @override
  String get desktopFolderNotYours =>
      'Folder Kryfo milik akun lain di komputer ini, jadi Kryfo tidak akan membukanya.';

  @override
  String get desktopFolderNotPrivate =>
      'Kryfo tidak bisa membuat foldernya hanya untukmu, jadi tidak akan dibuka.';

  @override
  String get desktopLockOtherVersion =>
      'Kunci ini dibuat oleh versi Kryfo lain yang tidak bisa dibaca versi ini.';

  @override
  String get desktopNoMemoryFolder =>
      'Kryfo butuh folder pribadi di memori selama berjalan, dan komputer ini tidak menyediakannya, jadi Kryfo tidak akan dibuka.';

  @override
  String get inviteNotYet =>
      'Undangan ini belum berlaku. Periksa jam di ponselmu.';

  @override
  String get inviteNotYetDesk =>
      'Undangan ini belum berlaku. Periksa jam di komputermu.';

  @override
  String get inviteExpired =>
      'Undangan ini sudah kedaluwarsa. Minta yang baru.';

  @override
  String get inviteDamaged => 'Undangan ini rusak. Minta yang baru.';

  @override
  String get helloSent =>
      'Permintaan terkirim. Mereka akan melihatnya saat online.';

  @override
  String get inviteNeeds06 => 'Perlu Kryfo 0.6 atau yang lebih baru.';

  @override
  String get helloSentOld =>
      'Permintaan terkirim. Jika mereka memakai Kryfo versi lama, mereka perlu memperbarui dulu.';

  @override
  String get modesPickHow =>
      'Pilih cara pesanmu dikirim. Kamu bisa mengubahnya kapan saja.';

  @override
  String get modesPrivate => 'Privat';

  @override
  String get modesPrivateTag => 'Tor · bridge bila perlu';

  @override
  String get modesPrivateLine =>
      'Tak ada yang tahu alamat IP-mu atau siapa kamu, bahkan server kami. Mencari jalan sendiri melewati blokir.';

  @override
  String get modesDefault => 'Bawaan';

  @override
  String get modesFastTag => 'Langsung ke server kami';

  @override
  String get modesFastLine =>
      'Melewati Tor, jadi pesan sampai lebih cepat dan lebih hemat baterai. Server kami melihat alamat IP-mu hanya selama kamu terhubung, dan tidak pernah mencatat atau menyimpannya. Kontakmu tidak pernah melihatnya. Jaringanmu bisa melihat kamu terhubung ke Kryfo.';

  @override
  String get modesFastConnected => 'Cepat · terhubung';

  @override
  String get modesFastConnecting => 'Cepat · menghubungkan';

  @override
  String get modesFastDown => 'Cepat · server kami tidak menjawab';

  @override
  String get modesBackupReady =>
      'Cadangan selalu siap, jadi kamu tetap terhubung walau satu mati.';

  @override
  String get modesDetails => 'Detail';

  @override
  String get modesBothLine =>
      'Keduanya mengenkripsi setiap pesan secara end-to-end. Yang berbeda hanya siapa yang bisa melihat alamat IP-mu.';

  @override
  String get modesConnectionBridges => 'Koneksi dan bridge';

  @override
  String get modesWhatServersSee => 'Apa yang bisa dilihat server kami';

  @override
  String get serversTitle => 'Server Cepat';

  @override
  String get serversLine =>
      'Setiap pesan dikirim ke kedua server sekaligus. Yang menjawab duluan membawanya, dan yang lain mengambil alih jika satu berhenti.';

  @override
  String get serversOne => 'Server 1';

  @override
  String get serversTwo => 'Server 2 · penyedia kedua';

  @override
  String get serversConnected => 'Terhubung';

  @override
  String get serversConnecting => 'Menghubungkan';

  @override
  String get serversNotAnswering => 'Tidak menjawab';

  @override
  String serversMs(int ms) {
    return '$ms md';
  }

  @override
  String get serversQuicker => 'Lebih cepat';

  @override
  String get serversBackups => 'Relay publik';

  @override
  String get serversBackupsLine =>
      'Dipakai selama Server 1 mati, dan hanya lewat Tor, jadi mereka tidak pernah melihat alamat IP-mu.';

  @override
  String get serversStandingBy => 'Siaga';

  @override
  String get serversInUse => 'Dipakai';

  @override
  String get homeMergedTitle => 'Relay dan Cepat kini jadi satu';

  @override
  String get homeMergedLine =>
      'Kamu memakai Cepat. Server cadangan selalu siap, jadi kamu tetap terhubung walau satu mati. Server kami melihat alamat IP-mu, tidak pernah isi pesanmu.';

  @override
  String get homeMergedGotIt => 'Mengerti';

  @override
  String get homeMergedUsePrivate => 'Pakai Privat saja';

  @override
  String get homeOursDownTitle => 'Server kami tidak menjawab';

  @override
  String get homeOursDownLine =>
      'Setelah beberapa menit, saat Tor tembus, pesan juga lewat relay publik, dan kembali lewat server kami begitu salah satunya menjawab.';

  @override
  String get homeUsePrivate => 'Pakai Privat';

  @override
  String get homeSwitchedToPrivate => 'Pindah ke Privat';

  @override
  String get homeUseFast => 'Pakai Cepat';

  @override
  String get homeSwitchedToFastRoute => 'Pindah ke Cepat';

  @override
  String get bridgesBridgeFirstFastSeen =>
      'Biarkan Kryfo mencari jembatan yang tembus. Cepat juga bisa, tapi jaringan ini bisa melihat kamu terhubung ke Kryfo.';

  @override
  String get appServersNotAnswering => 'Server tidak menjawab';

  @override
  String get settingsPrivateTor => 'Privat · Tor';

  @override
  String get seenOurServers => 'Server kami';

  @override
  String get seenOurServersCould => 'Server kami bisa';

  @override
  String get seenIpWhy =>
      'Di Privat semuanya keluar lewat Tor dan server kami melihat node keluar, bukan kamu. Di Cepat koneksi langsung ke dua server kami: mereka melihat alamat IP-mu selama terhubung dan tidak menyimpan catatannya. Selama server pertama mati, Cepat juga memakai relay publik, hanya lewat Tor.';

  @override
  String get chatAlbumItDisappearsWithNo =>
      'Album ini akan dihapus dari kedua ponsel, kecuali sudah disimpan. Ini tidak bisa dibatalkan.';

  @override
  String get chatAlbumItDisappearsWithNoDesk =>
      'Album ini akan dihapus dari kedua perangkat, kecuali sudah disimpan. Ini tidak bisa dibatalkan.';

  @override
  String get groupChatAlbumItDisappearsWithNo =>
      'Album ini akan dihapus dari ponsel semua orang, kecuali sudah disimpan. Ini tidak bisa dibatalkan.';

  @override
  String get groupChatAlbumItDisappearsWithNoDesk =>
      'Album ini akan dihapus dari perangkat semua orang, kecuali sudah disimpan. Ini tidak bisa dibatalkan.';

  @override
  String get homeInviteSomeone => 'Undang seseorang';

  @override
  String get onboardingNameHeadline => 'Sebuah *@nama* publik, kalau mau.';

  @override
  String get onboardingNameLine =>
      'Dengan @nama publik, orang bisa menemukanmu.\nMelewatinya membuatmu lebih privat.\nKamu bisa menambahkannya nanti.';

  @override
  String get onboardingNameSkip => 'Lewati dulu →';

  @override
  String onboardingNameClaim(Object handle) {
    return 'Ambil @$handle →';
  }

  @override
  String get onboardingInviteHeadline => 'Sekarang, *undang seseorang*.';

  @override
  String get onboardingInviteLead =>
      'Kirim tautan lewat aplikasi pesan apa pun.\nTautan itu membuka Kryfo, atau menunjukkan tempat mengunduhnya.';

  @override
  String get onboardingInviteSomeone => 'Undang seseorang →';

  @override
  String get onboardingInviteGettingReady => 'Menyiapkan tautanmu…';

  @override
  String inviteShareText(Object myId, Object link, Object download) {
    return 'Tambahkan aku di Kryfo. Namaku di sana $myId\n\nKetuk untuk menambahkanku:\n$link\n\nBelum punya Kryfo? Unduh di sini:\n$download\n\nKryfo adalah aplikasi pesan privat. Tanpa nomor telepon, tanpa email.';
  }

  @override
  String get inviteNotReady => 'Tautanmu hampir siap. Coba lagi sebentar lagi.';

  @override
  String get photoCropTitle => 'Geser dan atur ukuran';

  @override
  String get photoCropUse => 'Pakai foto';

  @override
  String get photoCropLabel =>
      'Fotomu di dalam lingkaran. Cubit untuk memperbesar, seret untuk menggeser';

  @override
  String get photoCouldNotUse => 'Coba foto lain. Foto ini tidak bisa dibaca.';

  @override
  String get photoTake => 'Ambil foto';

  @override
  String get photoChoose => 'Pilih dari galeri';

  @override
  String get photoPickFace => 'Pilih wajah';

  @override
  String get photoView => 'Lihat foto';

  @override
  String get photoRemove => 'Hapus foto';

  @override
  String get photoYourPhoto => 'Fotomu';

  @override
  String get photoYourPhotoLine =>
      'Hanya kontakmu yang melihatnya, terenkripsi ujung ke ujung.';

  @override
  String get photoSetTheirs => 'Pasang foto';

  @override
  String get photoChangeTheirs => 'Ganti foto';

  @override
  String get photoOnlyHere => 'Hanya di ponsel ini';

  @override
  String get photoOnlyHereDesk => 'Hanya di komputer ini';

  @override
  String photoForThem(Object name) {
    return 'Foto untuk $name';
  }

  @override
  String get photoOnlyHereLine =>
      'Hanya kamu yang melihatnya. Tetap di ponsel ini.';

  @override
  String get photoOnlyHereLineDesk =>
      'Hanya kamu yang melihatnya. Tetap di komputer ini.';

  @override
  String photoOf(Object name) {
    return 'Foto $name';
  }

  @override
  String get historyChatStaysShots =>
      'Obrolan ini tetap di ponselmu karena tangkapan layar diblokir di sini.';

  @override
  String chatDeviceOlderKryfo(String name) {
    return '$name memakai Kryfo versi lama. Balas dari ponselmu sampai mereka memperbarui.';
  }

  @override
  String chatDeviceNotYet(String name) {
    return '$name belum bisa menerima pesan dari komputer ini. Balas dari ponselmu.';
  }

  @override
  String chatDeviceWaitingForApp(String name) {
    return 'Menunggu aplikasi $name mengenali komputer ini. Untuk sekarang, balas dari ponselmu.';
  }

  @override
  String chatDeviceQuietAWhile(String name) {
    return '$name sudah lama tidak menulis. Untuk sekarang, balas dari ponselmu.';
  }

  @override
  String get linkedClearHereOnly =>
      'Semua pesan di sini dihapus hanya dari komputer ini. Ponselmu tetap menyimpannya.';

  @override
  String get linkedDeleteHereOnly =>
      'Semua pesan dan kontak ini hilang hanya dari komputer ini. Ponselmu tetap menyimpan chatnya.';

  @override
  String get linkedBlockHereOnly =>
      'Pesannya berhenti masuk ke komputer ini. Dia tidak diberi tahu. Blokir dia di ponselmu agar di sana juga berhenti.';

  @override
  String get historyCopyTitle => 'Riwayat chat';

  @override
  String get historyCopyMaking => 'Menyiapkan chat kamu';

  @override
  String get historyCopyMakingLine =>
      'Ponselmu mengumpulkan yang akan disalin. Sebentar lagi dimulai.';

  @override
  String get historyCopyGoing => 'Menyalin chat kamu';

  @override
  String get historyCopyGoingLine =>
      'Biarkan kedua perangkat tetap online sampai selesai.';

  @override
  String historyCopySize(Object size) {
    return 'Total $size';
  }

  @override
  String get historyCopyWaiting => 'Menunggu perangkat lain';

  @override
  String get historyCopyWaitingLine =>
      'Penyalinan berlanjut sendiri saat kedua perangkat online.';

  @override
  String get historyCopyPaused => 'Penyalinan rehat sebentar';

  @override
  String get historyCopyPausedLine => 'Berlanjut dalam semenit.';

  @override
  String get historyCopyWhole => 'Semua pesan dan file sudah sampai';

  @override
  String get historyCopyWholeLine => 'Tidak ada yang hilang.';

  @override
  String get historyCopyRows => 'Kontak dan grupmu sudah sampai';

  @override
  String get historyCopyRowsLine =>
      'Semuanya sampai tanpa pesan apa pun. Pesan baru muncul di perangkat mulai sekarang.';

  @override
  String get historyCopyGaps => 'Sebagian besar chatmu sudah sampai';

  @override
  String get historyCopyGapsLine =>
      'Chat ini berisi lebih sedikit di perangkat baru daripada di ponselmu.';

  @override
  String historyCopyGapMessages(Object got, Object want) {
    return 'Pesan: $got dari $want';
  }

  @override
  String historyCopyGapFiles(Object got, Object want) {
    return 'File: $got dari $want';
  }

  @override
  String historyCopyLeft(num count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString item tetap di ponselmu',
    );
    return '$_temp0';
  }

  @override
  String get historyCopyLeftWhy =>
      'Terlalu besar atau tidak terbaca untuk disalin.';

  @override
  String historyCopyLeftChats(num count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString chat tetap di ponselmu',
    );
    return '$_temp0';
  }

  @override
  String get historyCopyEnded => 'Penyalinan berhenti';

  @override
  String get historyCopyEndedLine =>
      'Tidak ada lagi yang datang. Tautkan perangkat lagi untuk salinan baru.';

  @override
  String get historyCopyFailed => 'Penyalinan tidak bisa selesai';

  @override
  String get historyCopyFailedLine =>
      'Tautkan perangkat lagi untuk salinan baru.';

  @override
  String get historyCopyStays => 'Tetap di ponselmu';

  @override
  String get historyCopySee => 'Lihat salinan';

  @override
  String a11yPinDigits(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString angka',
      zero: 'Belum ada angka',
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
      other: '$countString karakter',
      zero: 'Belum ada karakter',
    );
    return '$_temp0';
  }

  @override
  String get a11yBackupProgress => 'Progres cadangan';

  @override
  String get a11yRestoreProgress => 'Progres pemulihan';

  @override
  String get a11yExportProgress => 'Progres ekspor';

  @override
  String get a11yLockFileProgress => 'Progres penguncian';

  @override
  String get a11yCleanProgress => 'Progres pembersihan';

  @override
  String get a11yMessageActions => 'Tindakan pesan';

  @override
  String get a11yRecordVoiceNote => 'Rekam pesan suara';

  @override
  String get a11yRecording => 'Merekam';

  @override
  String a11yPhotoOn(String date) {
    return 'Foto, $date';
  }

  @override
  String a11yPhotoFrom(String name, String date) {
    return 'Foto dari $name, $date';
  }

  @override
  String a11yVideoOn(String date) {
    return 'Video, $date';
  }

  @override
  String a11yVideoFrom(String name, String date) {
    return 'Video dari $name, $date';
  }

  @override
  String a11yNewMessages(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString pesan baru',
      one: 'Pesan baru',
    );
    return '$_temp0';
  }

  @override
  String get wideSelectChat => 'Pilih obrolan';

  @override
  String get wideSelectChatLine =>
      'Pilih obrolan dari daftar untuk mulai menulis.';

  @override
  String get wideListWidth => 'Lebar daftar obrolan';

  @override
  String transferDoneOf(String done, String total) {
    return '$done dari $total';
  }

  @override
  String transferDoneLeft(String done, String left) {
    return '$done · $left';
  }

  @override
  String get transferLeftSoon => 'kurang dari semenit lagi';

  @override
  String transferLeftMinutes(String n) {
    return 'sekitar $n mnt lagi';
  }

  @override
  String transferLeftHours(String n) {
    return 'sekitar $n jam lagi';
  }

  @override
  String transferSending(String detail) {
    return 'Mengirim · $detail';
  }

  @override
  String transferReceiving(String detail) {
    return 'Menerima · $detail';
  }

  @override
  String transferBoth(String detail) {
    return 'Mengirim dan menerima · $detail';
  }

  @override
  String get transferPause => 'Jeda';

  @override
  String get transferPauseDownload => 'Jeda unduhan';

  @override
  String get transferDownload => 'Unduh';

  @override
  String get transferResume => 'Lanjutkan';

  @override
  String get transferOnWifi => 'Diunduh lewat Wi-Fi';

  @override
  String transferPausedAt(String detail) {
    return 'Dijeda · $detail';
  }

  @override
  String get transferTapToDownload => 'Ketuk untuk mengambilnya';

  @override
  String transferSizeLine(String size, String state) {
    return '$size · $state';
  }

  @override
  String get transferNoteTitle => 'Transfer file';

  @override
  String get transferChannel => 'Transfer file';

  @override
  String get transferChannelLine =>
      'Muncul selama file dikirim atau diunduh. Tidak pernah menyebut chat atau file.';

  @override
  String get autoGetTitle => 'Unduh otomatis';

  @override
  String get autoGetLine =>
      'File datang tanpa diketuk sesuai pilihanmu di sini. File yang menunggu tetap ada di server file untukmu, paling lama seminggu.';

  @override
  String get autoGetPhotos => 'Foto';

  @override
  String get autoGetVideos => 'Video';

  @override
  String get autoGetFiles => 'File';

  @override
  String get autoGetAlways => 'Lewat Wi-Fi dan data seluler';

  @override
  String get autoGetWifi => 'Hanya lewat Wi-Fi';

  @override
  String get autoGetNever => 'Tidak pernah, aku ketuk untuk mengunduh';

  @override
  String get autoGetVoice => 'Pesan suara selalu diunduh.';

  @override
  String get settingsFiles => 'File';

  @override
  String get desktopLockAccountBody =>
      'Semua yang disimpan Kryfo di komputer ini terenkripsi. Kryfo terbuka dengan akun penggunamu.';

  @override
  String get desktopLockAddPassphrase => 'Tambahkan frasa sandi';

  @override
  String get desktopLockWithoutPassphrase =>
      'Tanpanya, siapa pun yang memakai akun penggunamu bisa membuka Kryfo.';

  @override
  String get desktopLockKeyringRefused =>
      'Kryfo tidak bisa menyimpan kuncinya di ring kunci komputer ini. Tambahkan frasa sandi sebagai gantinya.';

  @override
  String get desktopKeyMissing =>
      'Akun pengguna ini tidak punya kunci data Kryfo. Cadangan Kryfo mengembalikan semuanya. Kalau kamu memindahkan folder Kryfo, tambahkan frasa sandi di akun pengguna asalnya, lalu salin lagi.';

  @override
  String get desktopKeyUnreachable =>
      'Kryfo belum bisa menjangkau kuncinya di komputer ini. Buka kunci ring kuncimu kalau komputer memintanya, lalu coba lagi.';

  @override
  String get desktopPassRow => 'Frasa sandi di komputer ini';

  @override
  String get desktopPassWindowsAccount => 'Dikunci dengan akun Windows-mu';

  @override
  String get desktopPassKeyring => 'Dikunci dengan ring kuncimu';

  @override
  String get desktopPassOffBody => 'Kryfo terbuka dengan akun penggunamu.';

  @override
  String get desktopPassOnBody =>
      'Kryfo meminta frasa sandi ini setiap kali dibuka.';

  @override
  String get desktopPassChange => 'Ganti frasa sandi';

  @override
  String get desktopPassRemove => 'Hapus frasa sandi';

  @override
  String get desktopPassCurrent => 'Frasa sandi saat ini';

  @override
  String get desktopPassNew => 'Frasa sandi baru';

  @override
  String get desktopPassStays =>
      'Komputer ini tidak punya ring kunci yang bisa dipakai Kryfo, jadi frasa sandinya tetap.';

  @override
  String get desktopPassAdded => 'Frasa sandi ditambahkan';

  @override
  String get desktopPassRemoved => 'Frasa sandi dihapus';

  @override
  String get desktopPassChanged => 'Frasa sandi diganti';

  @override
  String get desktopPassRemoveBody =>
      'Ketik frasa sandimu untuk menghapusnya. Setelah itu Kryfo terbuka dengan akun penggunamu.';

  @override
  String get desktopKeyUnreachableWindows =>
      'Kryfo belum bisa menjangkau kuncinya di chip keamanan komputer ini. Coba lagi sebentar lagi.';

  @override
  String get desktopLockAccountRefused =>
      'Kryfo tidak bisa menyimpan kuncinya dengan akun Windows-mu. Tambahkan frasa sandi sebagai gantinya.';

  @override
  String get desktopPassStaysWindows =>
      'Kryfo tidak bisa menyimpan kuncinya dengan akun Windows-mu, jadi frasa sandinya tetap.';

  @override
  String get desktopBackupCardTitle => 'Simpan cadangan Kryfo';

  @override
  String get desktopBackupCardLine =>
      'Akun Windows-mu di komputer ini menyimpan kunci Kryfo. Cadangan Kryfo mengembalikan semuanya kalau suatu saat komputer atau akunnya direset.';

  @override
  String get desktopBackupHint =>
      'Mengembalikan semuanya kalau suatu saat komputer ini direset.';

  @override
  String chatHealRestored(Object name) {
    return '$name memasang Kryfo lagi';
  }

  @override
  String chatHealNewSession(Object name) {
    return 'Perangkat $name memulai sesi aman yang baru';
  }

  @override
  String chatHealHeldLine(Object name) {
    return 'Kamu sudah memverifikasi $name sebelumnya. Tidak ada yang terkirim sampai kamu memeriksa nomornya atau lanjut mengobrol. Pesan darinya tetap masuk.';
  }

  @override
  String get chatKeepChatting => 'Lanjut mengobrol';

  @override
  String chatNeedsUpdateToChat(Object name) {
    return '$name perlu memperbarui Kryfo agar bisa lanjut mengobrol';
  }

  @override
  String get restoreOlderTitle => 'Beberapa obrolan akan dijeda';

  @override
  String restoreOlderOne(Object name) {
    return '$name memakai Kryfo versi lama. Obrolan kalian dijeda sampai dia memperbaruinya.';
  }

  @override
  String restoreOlderTwo(Object first, Object second) {
    return '$first dan $second memakai Kryfo versi lama. Obrolanmu dengan mereka dijeda sampai mereka memperbaruinya.';
  }

  @override
  String restoreOlderMany(Object first, Object second, int count) {
    return '$first, $second, dan $count orang lainnya memakai Kryfo versi lama. Obrolanmu dengan mereka dijeda sampai mereka memperbaruinya.';
  }

  @override
  String settingsVersionAlpha(String version) {
    return '$version · alfa';
  }

  @override
  String get settingsDeskInTray => 'Berjalan di area notifikasi';

  @override
  String get settingsDeskWhileOpen => 'Selama Kryfo terbuka';

  @override
  String get onboardingDeskRunTitle => 'Kryfo tetap *berjalan*.';

  @override
  String get onboardingDeskRunLead =>
      'Tutup jendela dan Kryfo menunggu di area notifikasi.\nPesan terus masuk.\nKeduanya bisa kamu ubah di Pengaturan, Notifikasi.';

  @override
  String get savedLongPressAnyMessageDesk =>
      'Klik kanan pesan mana pun lalu pilih simpan untuk menyimpannya di sini.';

  @override
  String get chatFailedTapToRetryDesk => 'Gagal · klik untuk coba lagi';

  @override
  String get groupChatTapToRetryDesk => '! Klik untuk ulangi';

  @override
  String get chatDropHereToSend => 'Lepaskan di sini untuk mengirim';

  @override
  String get chatDropHereToAdd => 'Lepas di sini untuk menambah';

  @override
  String trayRemove(String name) {
    return 'Hapus $name';
  }

  @override
  String trayReadyToSend(Object count) {
    return 'Siap dikirim: $count';
  }

  @override
  String get trayPastedPicture => 'Gambar yang ditempel';

  @override
  String get voiceSeeTranscription => 'Lihat transkrip';

  @override
  String get voiceTranscribing => 'Mentranskrip…';

  @override
  String get voiceHideTranscription => 'Sembunyikan';

  @override
  String get voiceShowOriginalOnly => 'Lihat aslinya saja';

  @override
  String get voiceCouldNotTranscribe => 'Kata-katanya tidak terdengar jelas';

  @override
  String get voiceNoSpeech => 'Tidak ada suara bicara di pesan ini';

  @override
  String get voiceTxNoMemory => 'Memori yang tersedia tidak cukup saat ini';

  @override
  String get voiceTranscriptLabel => 'Transkrip';

  @override
  String get voiceSettingsTitle => 'Transkrip suara';

  @override
  String get voiceOnRow => 'Transkrip pesan suara';

  @override
  String get voiceOnHint => 'Ditawarkan di bawah setiap pesan suara';

  @override
  String get voiceOffDeletes =>
      'Mematikan ini menghapus transkrip yang tersimpan.';

  @override
  String get voiceModelTitle => 'Model suara';

  @override
  String voiceModelLine(Object size) {
    return 'Satu unduhan sekitar $size, untuk semua bahasa.';
  }

  @override
  String get voiceModelPrivacy =>
      'Diunduh lewat Tor dan disimpan di ponsel ini. Pesan suaramu tidak pernah keluar darinya.';

  @override
  String get voiceModelPrivacyDesk =>
      'Diunduh lewat Tor dan disimpan di komputer ini. Pesan suaramu tidak pernah keluar darinya.';

  @override
  String get voiceModelFailNoTor =>
      'Tor belum tersambung. Model hanya diunduh lewat Tor, jadi coba lagi setelah tersambung.';

  @override
  String get voiceModelRemoveTitle => 'Hapus model suara?';

  @override
  String get voiceModelRemoveLine =>
      'Transkrip yang sudah dibuat tetap ada. Yang baru perlu modelnya lagi.';

  @override
  String get voiceKeptNote =>
      'Transkrip disimpan terenkripsi bersama chatnya di ponsel ini dan dihapus bersamanya.';

  @override
  String get voiceKeptNoteDesk =>
      'Transkrip disimpan terenkripsi bersama chatnya di komputer ini dan dihapus bersamanya.';

  @override
  String get voiceNotNow => 'Nanti saja';

  @override
  String get unlinkedTitle => 'Perangkat ini sudah terlepas';

  @override
  String get unlinkedRemovedLine =>
      'Ponselmu menghapusnya dari akunmu, jadi Kryfo menghapus semua yang disimpannya di sini.';

  @override
  String get unlinkedUnusedLine =>
      'Perangkat ini tidak dibuka selama 30 hari, jadi Kryfo menghapus semua yang disimpannya di sini.';

  @override
  String get unlinkedSilentLine =>
      'Perangkat ini tidak mendapat kabar dari ponselmu selama 30 hari, jadi Kryfo menghapus semua yang disimpannya di sini.';

  @override
  String get unlinkedClockLine =>
      'Jamnya dimundurkan, jadi Kryfo menghapus semua yang disimpannya di sini agar obrolanmu tetap aman.';

  @override
  String get unlinkedBrokenLine =>
      'Kryfo tidak bisa tahu kapan perangkat ini terakhir dibuka, jadi Kryfo menghapus semua yang disimpannya di sini agar obrolanmu tetap aman.';

  @override
  String get unlinkedSelfLine =>
      'Kamu melepasnya, jadi Kryfo menghapus semua yang disimpannya di sini.';

  @override
  String get unlinkedAgainLine =>
      'Ponselmu tetap menyimpan obrolanmu. Untuk memakai Kryfo di sini lagi, tautkan perangkat ini ke ponselmu.';

  @override
  String get unlinkedClose => 'Tutup Kryfo';

  @override
  String get devicesLeave => 'Lepaskan perangkat ini';

  @override
  String get devicesLeaveTitle => 'Lepaskan perangkat ini?';

  @override
  String get devicesLeaveLine =>
      'Kryfo memberi tahu ponselmu dan menghapus semua yang disimpannya di sini. Ponselmu tetap menyimpan obrolanmu.';

  @override
  String get devicesLeaveYes => 'Lepaskan dan hapus';

  @override
  String get devicesGoneNotice => 'Perangkat dihapus';

  @override
  String devicesGoneRemovedLine(Object name, Object date) {
    return '$name dihapus dari akunmu pada $date.';
  }

  @override
  String devicesGoneUnusedLine(Object name, Object date) {
    return '$name tidak dipakai selama 30 hari, jadi dihapus dari akunmu pada $date.';
  }

  @override
  String devicesGoneItselfLine(Object name, Object date) {
    return '$name terlepas sendiri pada $date dan menghapus yang disimpannya.';
  }

  @override
  String get devicesChangedNotice => 'Perangkatmu berubah';

  @override
  String get devicesChangedLine =>
      'Buka Perangkat tertaut untuk melihat apa yang berubah.';

  @override
  String get devicesUnknownNotice => 'Perangkat ditautkan dari tempat lain';

  @override
  String get devicesUnknownLine =>
      'Salinan Kryfo lain menautkan perangkat ke akunmu. Ponsel ini mengeluarkannya dari daftarmu.';

  @override
  String get albumPrevious => 'Sebelumnya';

  @override
  String get albumNext => 'Berikutnya';

  @override
  String get notesHoldHintDesk =>
      'Klik kanan sebuah catatan untuk menyalin atau menghapusnya.';

  @override
  String get pinsNothingPinnedHereYetDesk =>
      'Belum ada yang disematkan di sini. Klik kanan sebuah pesan lalu pilih Sematkan, dan pesan itu menunggu di sini untuk semua orang di obrolan.';

  @override
  String get chatGalleryDesk => 'Gambar';

  @override
  String get groupChatGalleryDesk => 'Gambar';

  @override
  String get photoChooseDesk => 'Pilih file gambar';

  @override
  String get wallpaperFromYourPhotosDesk => 'Dari file gambar';

  @override
  String get notificationsSoundAndVibrationDesk => 'Suara';

  @override
  String get notificationsPlaySound => 'Putar suara';

  @override
  String get notificationsPlaySoundHint =>
      'Di setiap notifikasi di komputer ini';

  @override
  String bridgesShareBridgeN(String n) {
    return 'Bagikan jembatan $n';
  }

  @override
  String get bridgesShareThisBridge => 'Bagikan jembatan ini';

  @override
  String get bridgesShareItPrivately =>
      'Bagikan secara pribadi, kepada orang yang kamu percaya. Jembatan yang tidak dipasang di halaman publik bekerja lebih lama.';

  @override
  String get bridgesCopyBridge => 'Salin jembatan';

  @override
  String get bridgesBridgeCopied => 'Jembatan disalin';

  @override
  String get bridgesSendBridgeTo => 'Kirim jembatan ke';

  @override
  String get linkedAddOnPhone =>
      'Tambahkan orang di ponselmu. Mereka juga muncul di sini.';

  @override
  String get linkedLinkOnPhone => 'Buka tautan ini di ponselmu.';

  @override
  String get linkedDoOnPhone => 'Lakukan ini di ponselmu.';

  @override
  String get tipsTitle => 'Dukung Kryfo';

  @override
  String get tipsHeadline => 'Jaga Kryfo tetap *gratis untuk semua*';

  @override
  String get tipsLine =>
      'Tanpa iklan, tanpa investor, tanpa akun. Tip membantu membayar server dan pekerjaan di Kryfo.';

  @override
  String get tipsLeave => 'Beri tip';

  @override
  String get tipsYours => 'Milikmu';

  @override
  String get tipsAsking => 'Menanyakan harga ke Google Play';

  @override
  String get tipsBadgeOnly =>
      'Tip memberimu lencana pendukung dan tidak ada yang lain. Semua yang ada di Kryfo tetap gratis untuk semua orang, dengan atau tanpa tip.';

  @override
  String get tipsThroughPlay =>
      'Pembayaran lewat Google Play. Kami tidak pernah melihat data kartumu atau namamu.';

  @override
  String get tipsBadgeStays =>
      'Lencana tersimpan di ponsel ini. Di Aku, kamu memilih apakah lencana ditampilkan dan apakah kontakmu melihatnya.';

  @override
  String get tipsRestore => 'Pulihkan lencanaku';

  @override
  String get tipsRestoreLine =>
      'Pernah memberi tip? Lencanamu kembali di ponsel mana pun yang masuk dengan akun Google yang sama.';

  @override
  String tipsRestored(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter': 'Lencana pendukungmu sudah kembali',
      'patron': 'Lencana patronmu sudah kembali',
      'guardian': 'Lencana penjagamu sudah kembali',
      'other': 'Lencana pendukungmu sudah kembali',
    });
    return '$_temp0';
  }

  @override
  String get tipsNothingToRestore => 'Belum ada tip dari akun Google ini';

  @override
  String get tipsUnavailable =>
      'Tip berjalan lewat Google Play. Tip muncul di sini begitu Google Play berjalan di ponsel ini.';

  @override
  String get tipsSoon => 'Tip segera hadir di sini.';

  @override
  String get tipsPending =>
      'Google Play masih menyelesaikan pembayaranmu. Lencanamu datang begitu pembayarannya berhasil.';

  @override
  String get tipsFailed =>
      'Google Play tidak menyelesaikan pembayaran. Coba lagi sebentar lagi.';

  @override
  String get tipsThanks => 'Terima kasih';

  @override
  String tipsGranted(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter':
          'Sekarang kamu punya lencana pendukung. Lencana ini tidak membuka apa pun lagi: semua yang ada di Kryfo tetap gratis untuk semua orang.',
      'patron':
          'Sekarang kamu punya lencana patron. Lencana ini tidak membuka apa pun lagi: semua yang ada di Kryfo tetap gratis untuk semua orang.',
      'guardian':
          'Sekarang kamu punya lencana penjaga. Lencana ini tidak membuka apa pun lagi: semua yang ada di Kryfo tetap gratis untuk semua orang.',
      'other':
          'Sekarang kamu punya lencana pendukung. Lencana ini tidak membuka apa pun lagi: semua yang ada di Kryfo tetap gratis untuk semua orang.',
    });
    return '$_temp0';
  }

  @override
  String tipsKept(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter':
          'Terima kasih atas tipnya. Lencana pendukungmu tetap, yang lebih tinggi.',
      'patron':
          'Terima kasih atas tipnya. Lencana patronmu tetap, yang lebih tinggi.',
      'guardian':
          'Terima kasih atas tipnya. Lencana penjagamu tetap, yang lebih tinggi.',
      'other':
          'Terima kasih atas tipnya. Lencana pendukungmu tetap, yang lebih tinggi.',
    });
    return '$_temp0';
  }

  @override
  String get tipsProfileCard => 'Beri tip agar Kryfo tetap mandiri';

  @override
  String chatDeviceLinked(Object name) {
    return '$name menautkan perangkat baru';
  }

  @override
  String chatDeviceRemoved(Object name) {
    return '$name menghapus sebuah perangkat';
  }

  @override
  String chatDeviceListUnchecked(Object name) {
    return 'Daftar perangkat $name tidak dapat diperiksa';
  }

  @override
  String get notesDropToKeep => 'Lepaskan di sini untuk menyimpannya';

  @override
  String get notesOnAllDevices => 'Di semua perangkatmu';

  @override
  String get notesKeepAnything =>
      'Simpan tulisan, foto, dan file di sini. Semuanya muncul di semua perangkatmu.';

  @override
  String get notesGoneEverywhere =>
      'Catatan ini terhapus dari semua perangkatmu untuk selamanya.';

  @override
  String get notesDeleteAllEverywhere =>
      'Semua catatan terhapus dari semua perangkatmu untuk selamanya.';

  @override
  String get notesDeleteAllHereOnly =>
      'Semua catatan hanya terhapus dari perangkat ini. Ponselmu tetap menyimpannya.';

  @override
  String get notesAddItem => 'Tambah foto atau file';

  @override
  String get notesVoiceNotKept => 'Pesan suaramu tidak disimpan';

  @override
  String get handleOlderKryfo =>
      'Mereka memakai Kryfo versi lama. Minta mereka memperbarui, lalu tambahkan mereka.';

  @override
  String groupMemberNeedsUpdate(Object name) {
    return '$name memakai Kryfo versi lama. Mereka perlu memperbarui untuk menerima pesan di sini.';
  }

  @override
  String get groupMembersNeedUpdate =>
      'Beberapa anggota memakai Kryfo versi lama. Mereka perlu memperbarui untuk menerima pesan di sini.';

  @override
  String get onboardingAlwaysOnNotice =>
      'Android butuh satu notifikasi senyap yang tetap ada agar pesan tetap masuk saat Kryfo ditutup.';

  @override
  String get toolsSendToAChat => 'Kirim ke obrolan';

  @override
  String get toolsOneFileAtATime => 'Satu file sekali jalan';

  @override
  String get toolsLockThisFile => 'Kunci file ini';

  @override
  String get toolsLockThisFileLine =>
      'Kryfo bisa menguncinya dengan kata sandi, jadi hanya orang yang tahu kata sandinya yang bisa membukanya.';

  @override
  String get toolsDropHere => 'Lepas file di sini untuk membukanya di alat';

  @override
  String get toolsCopyPicture => 'Salin gambar';

  @override
  String get toolsPictureCopied => 'Gambar disalin';

  @override
  String get toolsCouldNotCopy => 'Gagal menyalin gambar';

  @override
  String get cleanNotYetHere => 'Gambar ini belum bisa dibersihkan di sini';

  @override
  String get cleanNotYetHereLine =>
      'Pembaruan berikutnya membersihkan gambar seperti ini di komputer. Gambarmu tetap seperti semula.';

  @override
  String get deskLinkRowHint => 'Pakai Kryfo di ponselmu di sini';

  @override
  String get deskLinkHead => 'Pakai Kryfo di ponselmu di sini';

  @override
  String get deskLinkLine =>
      'Komputer ini lalu menampilkan obrolan dan kontak di ponselmu dan mengirim sebagai kamu.';

  @override
  String get deskLinkGoesTitle => 'Pertama, komputer ini dihapus';

  @override
  String get deskLinkGoesLine =>
      'Identitasnya sendiri, obrolannya, dan kontaknya di komputer ini dihapus. Obrolan tersembunyi, umpan, dan Catatan pribadi juga ikut terhapus. File yang kamu simpan di foldermu sendiri tetap ada.';

  @override
  String get deskLinkBackupRow => 'Cadangkan dulu';

  @override
  String get deskLinkBackupHint =>
      'Menyimpan obrolan komputer ini dalam file, dengan frasa sandi 12 karakter atau lebih';

  @override
  String get deskLinkConfirmLine =>
      'Identitas dan obrolan komputer ini dihapus. Lalu Kryfo terbuka lagi dengan kode untuk dipindai.';

  @override
  String get deskLinkConfirmYes => 'Hapus dan tautkan';

  @override
  String get deskLinkReplace => 'Ganti identitas komputer ini';

  @override
  String get deskLinkErasing => 'Menghapus komputer ini';

  @override
  String get deskLinkErasingLine =>
      'Sebentar lagi Kryfo terbuka lagi dengan kode untuk dipindai.';

  @override
  String get deskLinkNotStarted =>
      'Tautan tidak bisa dimulai. Coba lagi nanti.';

  @override
  String get settingsLinkedToYourPhone => 'Tertaut ke ponselmu';

  @override
  String get settingsLinkedPhoneHint => 'Cadangan dan undangan tetap di ponsel';

  @override
  String get settingsUnlinkComputer => 'Lepaskan komputer ini';

  @override
  String get settingsUnlinkComputerTitle => 'Lepaskan komputer ini?';

  @override
  String get settingsUnlinkComputerLine =>
      'Obrolan di komputer ini dihapus. Ponselmu tetap menyimpan semuanya.';

  @override
  String get metaReaderColourProfileName => 'nama profil warna';

  @override
  String get cleanPixelMarksStay =>
      'Tanda yang tersembunyi di dalam piksel itu sendiri, seperti watermark tersembunyi dari pembuat gambar, dan apa pun yang tampak di gambar tetap seperti semula.';

  @override
  String translateOfferDownload(Object language, Object size) {
    return 'Unduh $language ($size)?';
  }

  @override
  String translateLineDownloading(Object language) {
    return 'Mengunduh $language…';
  }

  @override
  String translateLineWaitsWifi(Object language) {
    return 'Menunggu Wi-Fi untuk mengunduh $language';
  }

  @override
  String get translateWaitsWifi =>
      'Menunggu Wi-Fi. Unduhan mulai sendiri begitu ponsel ini tersambung ke Wi-Fi.';

  @override
  String get translateWaitsWifiDesk =>
      'Menunggu Wi-Fi. Unduhan mulai sendiri begitu komputer ini tersambung ke Wi-Fi.';

  @override
  String get translateWaitsWifiShort => 'Menunggu Wi-Fi';

  @override
  String translatePackLineTwo(Object language, Object other, Object size) {
    return 'Pesan diterjemahkan di ponsel ini dan tidak pernah keluar darinya. Untuk itu perlu paket bahasa $language dan $other, total sekitar $size, diunduh sekali lewat Tor.';
  }

  @override
  String translatePackLineTwoDesk(Object language, Object other, Object size) {
    return 'Pesan diterjemahkan di komputer ini dan tidak pernah keluar darinya. Untuk itu perlu paket bahasa $language dan $other, total sekitar $size, diunduh sekali lewat Tor.';
  }

  @override
  String get translateLanguagesHint =>
      'Masing-masing diunduh sekali, lalu menerjemahkan di ponsel ini';

  @override
  String get translateLanguagesHintDesk =>
      'Masing-masing diunduh sekali, lalu menerjemahkan di komputer ini';

  @override
  String get translateSuggested => 'Disarankan';

  @override
  String get translateMoreLanguages => 'Bahasa lainnya';

  @override
  String get translateWaysBoth => 'Dari dan ke bahasa Inggris';

  @override
  String get translateWaysInto => 'Hanya menerjemahkan ke bahasa Inggris';

  @override
  String get translateWaysFrom => 'Hanya menerjemahkan dari bahasa Inggris';

  @override
  String get translateGet => 'Unduh';

  @override
  String get translateRemove => 'Hapus';

  @override
  String translateRemoveTitle(Object language) {
    return 'Hapus $language?';
  }

  @override
  String translateRemoveLine(Object size) {
    return 'Ini mengosongkan $size. Terjemahan yang disimpan dengannya juga dihapus. Kamu bisa mengunduhnya lagi kapan saja.';
  }

  @override
  String get translateResumeShort => 'Lanjutkan';

  @override
  String get translateTagApp => 'Bahasa aplikasi';

  @override
  String get translateTagRead => 'Kamu membacanya';

  @override
  String get chatInboxAnswerFromPhone => 'Balas obrolan ini dari ponselmu.';

  @override
  String get chatInboxSendsWhenPhoneOnline => 'Terkirim saat ponselmu online.';

  @override
  String get chatInboxFilesFromPhone => 'Kirim file dari ponselmu.';

  @override
  String get devicesManyAnswersNotice => 'Periksa komputermu';

  @override
  String devicesManyAnswersLine(String name, String count) {
    return '$name mencoba mengirim lebih dari $count balasan dalam satu jam. Kalau itu bukan kamu, hapus perangkat itu.';
  }

  @override
  String get fileViewInKryfo => 'Lihat di Kryfo';

  @override
  String get fileOpenWith => 'Buka dengan…';

  @override
  String get fileOpenWithNote =>
      'Aplikasi lain bisa melihat file ini. Sampai saat itu Kryfo menyimpannya terenkripsi.';

  @override
  String fileFrom(String name) {
    return 'Dari $name';
  }

  @override
  String fileLines(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n baris',
    );
    return '$_temp0';
  }

  @override
  String get fileNotWords =>
      'File ini bukan teks. Kamu bisa menyimpannya atau membukanya dengan aplikasi lain.';

  @override
  String fileShowsFirst(String size) {
    return 'Ini menampilkan $size pertama. Simpan file untuk membaca semuanya.';
  }

  @override
  String filePages(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n halaman',
    );
    return '$_temp0';
  }

  @override
  String filePageOf(String page, String total) {
    return '$page / $total';
  }

  @override
  String filePage(String page) {
    return 'Halaman $page';
  }

  @override
  String get fileSearchIn => 'Cari di file';

  @override
  String get fileSearchHint => 'Cari kata di PDF ini';

  @override
  String get fileZoomIn => 'Perbesar';

  @override
  String get fileZoomOut => 'Perkecil';

  @override
  String get filePdfLocked =>
      'PDF ini memakai kata sandi. Buka dengan aplikasi lain untuk membacanya.';

  @override
  String get filePdfUnreadable =>
      'Kryfo tidak bisa menampilkan PDF ini. Kamu bisa menyimpannya atau membukanya dengan aplikasi lain.';

  @override
  String get soundOpenPlayer => 'Membuka pemutar';

  @override
  String get soundSpeed => 'Kecepatan putar';

  @override
  String get soundClosePlayer => 'Tutup pemutar';

  @override
  String get soundPlayingInKryfo => 'Diputar di Kryfo';

  @override
  String get soundBack15 => 'Mundur 15 detik';

  @override
  String get soundForward15 => 'Maju 15 detik';

  @override
  String get soundRepeat => 'Ulangi';

  @override
  String get soundUpNext => 'Berikutnya';

  @override
  String soundVoiceFrom(String name) {
    return 'Pesan suara dari $name';
  }

  @override
  String get sendSheetTo => 'Kirim ke';

  @override
  String get sendSheetCleaned => 'Dibersihkan sebelum dikirim';

  @override
  String get sendSheetFiles => 'File';

  @override
  String get sendSheetRecent => 'Terbaru';

  @override
  String get sendSheetChoosePhotos => 'Pilih foto dan video';

  @override
  String get sendSheetBrowseFiles => 'Jelajahi semua file di ponsel ini';

  @override
  String get sendSheetNoRecent =>
      'File yang kamu kirim dan terima di chat muncul di sini.';

  @override
  String sendSheetChosen(String n) {
    return 'Dipilih, nomor $n';
  }

  @override
  String get sendSheetAsFile => 'Kirim sebagai file';

  @override
  String get sendSheetAsFileLine => 'Kualitas asli, tanpa kompresi';

  @override
  String sendSheetSend(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Kirim $n',
    );
    return '$_temp0';
  }

  @override
  String sharedWith(String name) {
    return 'Dibagikan dengan $name';
  }

  @override
  String sharedIn(String name) {
    return 'Dibagikan di $name';
  }

  @override
  String get sharedTabMedia => 'Media';

  @override
  String get sharedTabFiles => 'File';

  @override
  String get sharedTabVoice => 'Suara';

  @override
  String get sharedTabLinks => 'Tautan';

  @override
  String get sharedNoPhotos => 'Foto yang dikirim di chat ini muncul di sini.';

  @override
  String get sharedNoFiles => 'File yang dikirim di chat ini muncul di sini.';

  @override
  String get sharedNoVoice => 'Pesan suara di chat ini muncul di sini.';

  @override
  String get sharedNoLinks => 'Tautan yang dikirim di chat ini muncul di sini.';

  @override
  String get sharedYourVoice => 'Pesan suaramu';

  @override
  String get sharedOpensLink => 'Membuka tautan di aplikasi lain';

  @override
  String voiceSpeedLabel(String speed) {
    return '${speed}x';
  }

  @override
  String voiceSpeedA11y(String speed) {
    return 'Kecepatan putar $speed';
  }

  @override
  String voiceSeekValue(String at, String total) {
    return '$at dari $total';
  }

  @override
  String get chatReactHeart => 'Beri reaksi hati';

  @override
  String get homeDraftLabel => 'Draf:';

  @override
  String homeDraftA11y(String text) {
    return 'Draf: $text';
  }

  @override
  String handleSuggestFree(String handle) {
    return '@$handle tersedia, pakai ini';
  }

  @override
  String get notifRequestsChannel => 'Permintaan pesan';

  @override
  String get notifRequestsChannelLine =>
      'Pesan pertama dari orang yang belum kamu tambahkan';

  @override
  String get notifRequestPopups => 'Pop-up untuk permintaan pesan';

  @override
  String get notifRequestPopupsHint =>
      'Aktif, permintaan baru muncul dengan suara. Nonaktif, permintaan menunggu tanpa suara di notifikasimu.';
}
