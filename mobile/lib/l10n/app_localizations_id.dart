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
  String get backupCouldNotMakeThe => 'Gagal membuat kunci';

  @override
  String get contactCardMessageMeOn => 'Kirimi aku pesan di';

  @override
  String get contactCardScanItOrType =>
      'Pindai, atau ketik tiga katanya di Kryfo.\nKartu ini tidak tahu apa pun tentangmu selain itu.';

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
  String get contactStatusAddedByHand => 'Ditambahkan manual';

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
  String appAddedYouCanMessage(Object parsed) {
    return '$parsed ditambahkan · sekarang kamu bisa mengiriminya pesan';
  }

  @override
  String appPeerImportedV1(Object parsed) {
    return 'Rekan diimpor (v1): $parsed';
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
  String appJoinedButYourHello(Object linkName) {
    return 'Bergabung ke $linkName, tapi salammu tertahan';
  }

  @override
  String appJoined(Object linkName) {
    return 'Bergabung ke $linkName';
  }

  @override
  String appJoinedButTheCreator(Object linkName) {
    return 'Bergabung ke $linkName, tapi pembuatnya belum bisa dihubungi';
  }

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
  String get appScanTheirCode => 'Pindai kodenya';

  @override
  String get appAKryfoLinkA => 'Tautan Kryfo, tautan ruang, atau @wren';

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
  String get appStartingTor30s => 'Memulai tor (~30 dtk)...';

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
  String get appGettingMessages => 'Menerima pesan →';

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
  String get appReadyToSendPublishing => 'Siap mengirim · menerbitkan alamatmu';

  @override
  String get appReadyToSendFinishing =>
      'Siap mengirim · menyelesaikan penyiapan';

  @override
  String appConnecting(Object pct) {
    return 'Menghubungkan · $pct';
  }

  @override
  String get appTor => 'Tor';

  @override
  String get appTorIsOffTurn =>
      'Tor mati. Nyalakan untuk terhubung secara privat.';

  @override
  String get appTheFirstConnectionTakes =>
      'Koneksi pertama butuh satu atau dua menit selagi tor membangun rute privat. Setelah itu tersimpan di cache, jadi membuka Kryfo berikutnya jauh lebih cepat.';

  @override
  String get appRelayAndFastModes =>
      'Mode relay dan cepat tidak memakai tor dan lebih cepat. Keduanya ada di pengaturan, di bagian kecepatan & privasi, dan masing-masing menjelaskan apa yang dikorbankan.';

  @override
  String get appViaRelay => 'Lewat relay';

  @override
  String get appOffline => 'Offline';

  @override
  String get appFast => 'Cepat';

  @override
  String get appTorOff => 'Tor mati';

  @override
  String get appTorReady => 'Tor siap';

  @override
  String get appConnecting2 => 'Menghubungkan';

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
  String get miuiAutostartXiaomiTurnsOffBackground =>
      'Xiaomi mematikan aplikasi latar belakang secara bawaan. Tanpa mulai otomatis, Kryfo tidak bisa mengantarkan pesan saat aplikasinya ditutup. Di layar berikutnya, cari Kryfo di daftar lalu nyalakan tombolnya.';

  @override
  String get miuiAutostartOpenSettings => 'Buka pengaturan';

  @override
  String get miuiAutostartCouldnTOpenIt =>
      'Tidak bisa dibuka. Cari mulai otomatis di pengaturan ponsel';

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
  String get scamShieldLooksLikeAScam => 'Sepertinya penipuan';

  @override
  String scamShieldThisNameMatches(Object shown) {
    return 'Nama ini sama dengan $shown';
  }

  @override
  String scamShieldNameMatchesYourContact(Object shown) {
    return 'Namanya sama dengan kontakmu $shown';
  }

  @override
  String scamShieldSameFaceAsYour(Object shown) {
    return 'Wajahnya sama dengan kontakmu $shown';
  }

  @override
  String get scamShieldContainsACryptoAddress => 'Berisi alamat kripto';

  @override
  String get scamShieldMentionsMoneyAndUrgency =>
      'Menyebut uang sambil mendesak';

  @override
  String get scamShieldAsksYouToMove => 'Mengajakmu pindah ke aplikasi lain';

  @override
  String get scamShieldLinksToALookalike =>
      'Menautkan ke tiruan situs terkenal';

  @override
  String get scamShieldALongOpenerFrom =>
      'Pesan pembuka panjang dari orang tanpa riwayat';

  @override
  String get scamShieldAsksForACode =>
      'Meminta kode, seed phrase, atau file pemulihan';

  @override
  String scamShieldAlso(Object shown) {
    return 'Juga: namanya sama dengan kontakmu $shown';
  }

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
  String get backupPassphraseMustBeAt => 'Frasa sandi minimal 6 karakter';

  @override
  String get backupPassphrasesDonTMatch => 'Frasa sandi tidak cocok';

  @override
  String get backupBackupSavedKeepThe =>
      'Cadangan tersimpan · simpan frasa sandinya dengan aman';

  @override
  String get backupKryfoBackup => 'Cadangan Kryfo';

  @override
  String get backupYourEncryptedKryfoBackup =>
      'Cadangan Kryfo-mu yang terenkripsi. Simpan file ini DAN frasa sandimu dengan aman - kamu butuh keduanya untuk memulihkan.';

  @override
  String get backupBackUpKryfo => 'Cadangkan Kryfo';

  @override
  String get backupBackUp => 'Cadangkan';

  @override
  String get backupACopyToKeep =>
      'Salinan untuk disimpan. Ponsel ini tetap berjalan seperti biasa.';

  @override
  String get backupMoveToAnotherDevice => 'Pindah ke perangkat lain';

  @override
  String get backupTheFileTakesThis =>
      'File ini membawa serta identitas ini. Begitu dibuat, ponsel ini berhenti: tidak ada yang baru masuk ke sini, dan tidak ada kiriman dari sini yang sampai ke siapa pun.';

  @override
  String get backupOneEncryptedFileYour =>
      'Satu file terenkripsi: identitasmu, kontakmu, setiap pesan, dan setiap foto, pesan suara, dan file. Impor di perangkat lain dengan frasa sandinya. Sampai saat itu, kamu masih bisa berubah pikiran dan tetap di ponsel ini.';

  @override
  String get backupOneEncryptedFileYourIdentityYour =>
      'Satu file terenkripsi: identitasmu, kontakmu, setiap pesan, dan setiap foto, pesan suara, dan file yang ada di ponsel ini sekarang. Apa pun yang dikirim setelah hari ini tidak ikut di dalamnya, jadi buat lagi saat perlu. Untuk memulihkan, kamu butuh file dan frasa sandinya, dua-duanya.';

  @override
  String get backupPassphrase => 'Frasa sandi';

  @override
  String get backupConfirmPassphrase => 'Konfirmasi frasa sandi';

  @override
  String backupWriting(Object progress) {
    return 'Menulis… $progress';
  }

  @override
  String get backupCreating => 'Membuat…';

  @override
  String get backupMakeTheFileAnd => 'Buat file dan pindah';

  @override
  String get backupCreateBackup => 'Buat cadangan';

  @override
  String get backupHiddenNotIn => 'Obrolan tersembunyi tidak ada di dalamnya.';

  @override
  String get backupHiddenIncluded =>
      'Obrolan tersembunyimu juga ada di dalamnya.';

  @override
  String get backupMoveHiddenStay =>
      'Obrolan tersembunyi tetap di ponsel ini dan terhapus bersamanya.';

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
  String get bridgesThatWasNotIt => 'Bukan itu. Ini yang lain.';

  @override
  String get bridgesGotBridgesSaveTo =>
      'Dapat jembatan · simpan untuk memakainya';

  @override
  String get bridgesConnected => 'Terhubung';

  @override
  String get bridgesNotThroughYetTor => 'Belum tembus. Tor terus mencoba';

  @override
  String get bridgesBridges => 'Jembatan';

  @override
  String get bridgesTorIsBlockedWhere => 'Tor diblokir di tempatmu?';

  @override
  String get bridgesBridgesDisguiseYourConnection =>
      'Jembatan menyamarkan koneksimu agar bisa lolos keluar. Pilih satu jalan masuk, simpan, lalu tor tersambung ulang lewat jalan itu.';

  @override
  String get bridgesBridgesOnlyChangeHow =>
      'Jembatan hanya mengubah cara tor terhubung, dan saat ini kamu tidak di mode onion. Pengaturan di sini tetap disimpan, hanya saja tidak berpengaruh sampai kamu kembali ke mode itu.';

  @override
  String get bridgesFromTheTorProject => 'Dari tor project';

  @override
  String get bridgesNoise => 'Derau';

  @override
  String get bridgesGood => 'Bagus';

  @override
  String get bridgesMakesTorTrafficLook =>
      'Membuat lalu lintas tor tidak tampak seperti apa pun. Pilihan bawaan terbaik untuk kebanyakan jaringan yang diblokir. Jawab captcha, lalu kamu dapat beberapa baris.';

  @override
  String get bridgesPrivateBridge => 'Jembatan pribadi';

  @override
  String get bridgesALineFromA => 'Baris dari teman';

  @override
  String get bridgesWhateverTheLineSays => 'Sesuai isi barisnya';

  @override
  String get bridgesDepends => 'Tergantung';

  @override
  String get bridgesGotABridgeLine =>
      'Punya baris jembatan dari orang yang kamu percaya, atau dari bridges.torproject.org? Tempel di sini. Hanya baris obfs4, Kryfo belum mendukung yang lain.';

  @override
  String get bridgesPasteFromClipboard => 'Tempel dari papan klip';

  @override
  String get bridgesUseBridges => 'Pakai jembatan';

  @override
  String get bridgesNoLinesYet => 'Belum ada baris';

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
  String get bridgesRestartingTor => 'Memulai ulang tor…';

  @override
  String bridgesFindingABridgeS(Object elapsed) {
    return 'Mencari jembatan… $elapsed dtk';
  }

  @override
  String bridgesStillTryingS(Object elapsed) {
    return 'Masih mencoba… $elapsed dtk';
  }

  @override
  String get bridgesApplying => 'Menerapkan…';

  @override
  String get bridgesSaveAndReconnect => 'Simpan dan sambung ulang';

  @override
  String get bridgesWhatABridgeIs => 'Apa itu jembatan';

  @override
  String get bridgesATorEntryPoint =>
      'Pintu masuk tor yang tidak dipublikasikan siapa pun, dicapai lewat pembungkus agar koneksinya tidak tampak seperti tor. Sisa rutenya tetap tiga lompatan seperti biasa.';

  @override
  String get bridgesLooksLike => 'Terlihat seperti';

  @override
  String get bridgesSpeed => 'Kecepatan';

  @override
  String get bridgesGetBridges => 'Dapatkan jembatan';

  @override
  String get bridgesAskTheTorProject =>
      'Minta langsung ke tor project. Kamu memecahkan teka-teki agar bot tidak bisa menghabiskan persediaannya.';

  @override
  String get bridgesTypeWhatYouSee =>
      'Ketik yang kamu lihat. Huruf kecil tidak masalah.';

  @override
  String get bridgesThisOneRequestDoes =>
      'Permintaan yang satu ini tidak lewat tor - memang tidak bisa, karena tor-lah yang sedang tidak jalan. Siapa pun yang mengelola jaringanmu akan melihat kamu menghubungi tor project. Kalau itu saja sudah jadi masalah di tempatmu, cari jembatan di tempat lain dan tempel di bawah.';

  @override
  String get bridgesCouldNotDrawThe => 'Gagal menampilkan teka-teki';

  @override
  String get bridgesAnswer => 'Jawab';

  @override
  String get bridgesAsking => 'Meminta…';

  @override
  String get bridgesRequestBridges => 'Minta jembatan';

  @override
  String get bridgesDifferentPuzzle => 'Teka-teki lain';

  @override
  String get cameraNoCameraOnThis => 'Tidak ada kamera di ponsel ini';

  @override
  String get cameraCameraNotAvailable => 'Kamera tidak tersedia';

  @override
  String get cameraCameraPermissionIsOff =>
      'Izin kamera mati · ketuk untuk coba lagi';

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
  String get cameraTooLongForA => 'Terlalu panjang untuk pesan · maks 8 mb';

  @override
  String get cameraNeverSavedToYour => 'Tidak pernah disimpan ke galerimu';

  @override
  String get cameraNoExifNeverSaved =>
      'Tanpa exif, tidak pernah disimpan ke galerimu';

  @override
  String get cameraRec => 'Rekam';

  @override
  String get cameraSwitchCamera => 'Ganti kamera';

  @override
  String cameraClipSMb(Object secs, Object mb) {
    return 'Klip · $secs dtk · $mb mb';
  }

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
  String get chatFile => 'FILE';

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
      'Pesan ini hilang tanpa jejak. Ini tidak bisa dibatalkan.';

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
  String get chatHowLongBeforeSent =>
      'Berapa lama sampai pesan terkirim hilang?';

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
    return '$humanBytes · $wireEstimate lewat tor';
  }

  @override
  String get chatBigFilesGoOut =>
      'File besar dikirim dalam potongan kecil terenkripsi, jadi butuh waktu. Biarkan aplikasi terbuka dan pengiriman terus berjalan.';

  @override
  String get chatSendIt => 'Kirim';

  @override
  String get chatCouldNotReadThat => 'Gagal membaca file itu';

  @override
  String get chatFileTooBig8 => 'File terlalu besar · maks 8 mb';

  @override
  String get chatCouldNotCleanThat => 'Gagal membersihkan video itu';

  @override
  String get chatCouldNotCleanThatPictureSend =>
      'Gagal membersihkan gambar itu · kirim sebagai foto';

  @override
  String get chatGifTooBig8 => 'Gif terlalu besar · maks 8 mb';

  @override
  String get chatCouldNotCleanThatGif => 'Gagal membersihkan gif itu';

  @override
  String get chatTorIsNotUp => 'Tor belum aktif · dikirim tanpa pratinjau';

  @override
  String get chatCouldnTReachIt =>
      'Situsnya tak terjangkau · dikirim tanpa pratinjau';

  @override
  String get chatNoTitleCameBack => 'Tidak ada judul · dikirim tanpa pratinjau';

  @override
  String get chatCouldnTFetchIt =>
      'Gagal mengambilnya · dikirim tanpa pratinjau';

  @override
  String get chatNoSignalSessionRe => 'Tidak ada sesi Signal - tautkan ulang';

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
  String get chatSharedPhotos => 'Foto yang dibagikan';

  @override
  String chatSharedPhotoCount(int count, Object title) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString foto',
    );
    return '$_temp0 · $title';
  }

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
  String get chatAQuietReminder => 'Pengingat kecil…';

  @override
  String get chatNoteSaved => 'Catatan disimpan';

  @override
  String get chatClearThisConversation => 'Bersihkan obrolan ini?';

  @override
  String get chatEveryMessageHereIs =>
      'Semua pesan di sini dihapus dari ponsel ini. Ini hanya membersihkan salinanmu - tidak menyentuh perangkatnya.';

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
  String get chatLooksSafeNothingSuspicious =>
      'Tampak aman · tidak ada yang mencurigakan di pesan pertamanya';

  @override
  String get chatTheNextPhotoYou =>
      'Foto berikutnya yang kamu kirim dibuka dalam mode terlindung · dia tidak bisa mengambil tangkapan layarnya';

  @override
  String get chatPhotoProtectionOff => 'Perlindungan foto mati';

  @override
  String get chatAcceptToReplyThey =>
      'Terima untuk membalas - dia bisa mengirim satu pesan lagi sampai kamu menerimanya.';

  @override
  String chatIntroducedYouAcceptTo(Object introducer) {
    return '$introducer memperkenalkan kalian. Terima untuk membalas.';
  }

  @override
  String chatIntroducedYouSayHello(Object vouchNames) {
    return '$vouchNames memperkenalkan kalian. Sapa dia - dia juga sudah menerima kartumu.';
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
  String get chatYouBlockedThisContact => 'Kamu memblokir kontak ini';

  @override
  String get chatSupporter => 'Pendukung';

  @override
  String get chatEncryptedViaRelay => 'Terenkripsi · lewat relay';

  @override
  String get chatEncryptedDirect => 'Terenkripsi · langsung';

  @override
  String get chatEncryptedOverTor => 'Terenkripsi · lewat tor';

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
  String get chatWaitingForThemToComeOnline =>
      'Menunggu dia online atau menambahkanmu balik';

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
  String get chatDisguiseVoice => 'Samarkan suara';

  @override
  String get commonSend => 'Kirim';

  @override
  String get chatNoPhotosInThis => 'Belum ada foto di obrolan ini';

  @override
  String get chatSendPhoto => 'Kirim foto';

  @override
  String get chatAddACaption => 'Tambah keterangan…';

  @override
  String get chatSecurityCodeChanged => 'Kode keamanan berubah';

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
  String get cleanNoAppOnThis =>
      'Tidak ada aplikasi di ponsel ini yang menerima file itu.';

  @override
  String get cleanCouldNotSaveIt =>
      'Gagal menyimpannya. Pastikan ponsel masih punya ruang.';

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
  String get contactDeleteThisChat => 'Hapus obrolan ini?';

  @override
  String get contactEveryMessageAndThe =>
      'Semua pesan dan kontaknya terhapus dari ponsel ini. Tidak ada yang dikirim ke dia.';

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
      'Dukung secara anonim. Lencana opsional.\n*Privasi tidak pernah berbayar.*';

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
  String get donateReachingThePaymentService =>
      'Menghubungi layanan pembayaran lewat tor…';

  @override
  String get donateThisCanTakeUp => 'Ini bisa makan waktu sampai satu menit';

  @override
  String donateSThisCanTake(Object waited) {
    return '$waited dtk · ini bisa makan waktu sampai satu menit';
  }

  @override
  String get donateUseTheAddressInstead => 'Pakai alamat saja';

  @override
  String get donateThePaymentServiceIs =>
      'Layanan pembayaran ini berupa onion, dan hanya mode onion yang bisa menjangkaunya. Tidak ada yang dikirim.';

  @override
  String get donateTorWasSlowTo =>
      'Tor lambat menjangkau layanan pembayaran. Kamu bisa berdonasi ke alamat di bawah - hanya saja lencanamu tidak akan terbuka otomatis. Coba lagi nanti untuk lencananya.';

  @override
  String get donateThePaymentServiceIsHavingTrouble =>
      'Layanan pembayaran sedang bermasalah. Kamu tetap bisa berdonasi ke alamat di bawah - hanya saja lencanamu tidak akan terbuka otomatis. Coba lagi nanti untuk lencananya.';

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
      'Layar ini langsung diperbarui begitu pembayaranmu terdeteksi.\nBiarkan terbuka - tidak ada yang disimpan, tidak ada yang mengidentifikasi dirimu.';

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
  String get donatePaymentConfirmed => 'Pembayaran dikonfirmasi';

  @override
  String get donateThankYouForKeeping =>
      'Terima kasih sudah menjaga Kryfo tetap mandiri.';

  @override
  String donateVerifiedOnChainYou(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter':
          'Terverifikasi on-chain - sekarang kamu pendukung. Tidak ada yang bisa mencabutnya darimu.',
      'patron':
          'Terverifikasi on-chain - sekarang kamu patron. Tidak ada yang bisa mencabutnya darimu.',
      'guardian':
          'Terverifikasi on-chain - sekarang kamu penjaga. Tidak ada yang bisa mencabutnya darimu.',
      'other':
          'Terverifikasi on-chain - sekarang kamu pendukung. Tidak ada yang bisa mencabutnya darimu.',
    });
    return '$_temp0';
  }

  @override
  String get donateWearMyBadge => 'Pakai lencanaku';

  @override
  String get donateJustGladToHelp => 'Senang bisa membantu';

  @override
  String get gettingMessagesGettingMessages => 'Menerima pesan';

  @override
  String get gettingMessagesHowNewMessagesReach =>
      'Cara pesan baru sampai ke ponsel ini. Kamu bisa mengubahnya kapan saja.';

  @override
  String get gettingMessagesAlwaysOn => 'Selalu aktif';

  @override
  String get gettingMessagesMostPrivate => 'Paling privat';

  @override
  String get gettingMessagesMessagesArriveInstantlyNothing =>
      'Pesan masuk seketika. Tidak ada yang keluar dari Tor. Paling boros baterai.';

  @override
  String get gettingMessagesCheckIns => 'Cek berkala';

  @override
  String get gettingMessagesLightest => 'Paling ringan';

  @override
  String get gettingMessagesKryfoLooksForMessages =>
      'Kryfo mencari pesan setiap 15 menit. Hemat baterai, tapi pesan bisa terlambat.';

  @override
  String get gettingMessagesOnTheLockScreen => 'Di layar kunci';

  @override
  String get gettingMessagesHideMessagePreview => 'Sembunyikan pratinjau pesan';

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
  String get groupChatBlockedEverywhere => 'Diblokir di mana-mana';

  @override
  String get groupChatYou => 'Kamu';

  @override
  String get groupChatVoiceMessage => 'Pesan suara';

  @override
  String get groupChatQuotedPhoto => 'Foto';

  @override
  String get groupChatMessageUnavailable => 'Pesan tidak tersedia';

  @override
  String get groupChatTorIsNotUp => 'Tor belum aktif · dikirim tanpa pratinjau';

  @override
  String get groupChatCouldnTReachIt =>
      'Situsnya tak terjangkau · dikirim tanpa pratinjau';

  @override
  String get groupChatNoTitleCameBack =>
      'Tidak ada judul · dikirim tanpa pratinjau';

  @override
  String get groupChatCouldnTFetchIt =>
      'Gagal mengambilnya · dikirim tanpa pratinjau';

  @override
  String get groupChatCamera => 'Kamera';

  @override
  String get groupChatGallery => 'Galeri';

  @override
  String get groupChatVideo => 'Video';

  @override
  String get groupChatGifFromPhone => 'Gif dari ponsel';

  @override
  String get groupChatFile => 'File';

  @override
  String get groupChatCouldNotReadThat => 'Gagal membaca file itu';

  @override
  String get groupChatGifTooBig8 => 'Gif terlalu besar · maks 8 mb';

  @override
  String get groupChatCouldNotCleanThat => 'Gagal membersihkan gif itu';

  @override
  String get groupChatFileTooBig8 => 'File terlalu besar · maks 8 mb';

  @override
  String get groupChatCouldNotCleanThatVideo => 'Gagal membersihkan video itu';

  @override
  String get groupChatCouldNotCleanThatPictureSend =>
      'Gagal membersihkan gambar itu · kirim sebagai foto';

  @override
  String get groupChat30Seconds => '30 detik';

  @override
  String get groupChat1Minute => '1 menit';

  @override
  String get groupChat5Minutes => '5 menit';

  @override
  String get groupChat1Hour => '1 jam';

  @override
  String get groupChat24Hours => '24 jam';

  @override
  String get groupChatBurnTimer => 'Pesan berwaktu';

  @override
  String get groupChatNewMessagesDisappearAfter =>
      'Pesan baru hilang setelah waktu ini';

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
      'Pesan ini hilang tanpa jejak. Ini tidak bisa dibatalkan.';

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
  String get groupChatDisguiseVoice => 'Samarkan suara';

  @override
  String get groupChatSupporter => 'Pendukung';

  @override
  String get groupChatEdited => 'Diubah';

  @override
  String get groupChatTapToRetry => '! Ketuk untuk ulangi';

  @override
  String get groupChat0s => '0 dtk';

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
  String get commonRemove => 'Hapus';

  @override
  String get groupInfoClearThisConversation => 'Bersihkan obrolan ini?';

  @override
  String get groupInfoEveryMessageHereIs =>
      'Semua pesan di sini dihapus dari ponsel ini. Ini hanya membersihkan salinanmu, anggota lain tetap menyimpan salinan mereka.';

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
  String get groupInfoYouWillStopReceiving =>
      'Kamu tidak akan lagi menerima pesan, dan anggota lain akan melihat kamu keluar.';

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
  String get handleWren => 'wren';

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
  String get handleChecking => 'Mengecek…';

  @override
  String get handleAvailable => '✓ Tersedia';

  @override
  String get handleAlreadyTaken => 'Sudah dipakai';

  @override
  String get handleWhatAHandleDoes => 'Guna nama pengguna';

  @override
  String get handleAnyoneWhoKnowsIt =>
      'Siapa pun yang tahu nama ini bisa meminta untuk mengirimimu pesan, dan memang itulah gunanya. Halamannya hanya berisi undanganmu dan baris yang kamu tulis, tidak ada yang lain, dan tidak mencatat siapa yang membacanya. Kamu bisa menghapusnya kapan saja.';

  @override
  String handleIsNotYoursOn(Object handle) {
    return '@$handle bukan milikmu di ponsel ini';
  }

  @override
  String handleTheRegistryHoldsIt(Object handle) {
    return 'Registri menyimpannya dengan kunci lain, kemungkinan besar identitas yang dimiliki ponsel ini sebelum dipulihkan. Orang yang menambahkan @$handle tidak sampai ke kamu. Nama ini tidak bisa dilepas atau diperbarui dari sini. Pilih nama lain.';
  }

  @override
  String get handleForgetItOnThis => 'Lupakan di ponsel ini';

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
    return 'Tor belum bisa terhubung selama $howLong. Tidak ada yang bisa masuk atau keluar sampai tor terhubung.';
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
  String get homeOurRelayIsQuiet => 'Relay kami sedang diam';

  @override
  String get homeRelayModeUsesOnly =>
      'Mode relay hanya memakai relay milik kami, dan saat ini relay itu tidak menjawab. Mode cepat menambahkan relay publik di sampingnya, jadi pesan tetap sampai. Apa pun modenya, semuanya tetap tersegel.';

  @override
  String get homeSwitchedToFast => 'Beralih ke cepat';

  @override
  String get homeUseFastMode => 'Pakai mode cepat';

  @override
  String get homeKeepWaiting => 'Tunggu lagi';

  @override
  String get homeNotConnecting => 'Belum tersambung';

  @override
  String get homeBridgesAreOnAnd =>
      'Jembatan aktif dan tor masih belum tembus. Jembatan lebih lambat, dan sebagian bisa mati tanpa peringatan. Kalau jaringanmu tidak memblokir tor, terhubung langsung lebih cepat dan lebih andal.';

  @override
  String get homeGoingDirectReconnecting => 'Langsung · menyambung ulang';

  @override
  String get homeTurnBridgesOff => 'Matikan jembatan';

  @override
  String get homeStillTrying => 'Masih mencoba';

  @override
  String get homeTorIsNotGetting =>
      'Tor belum juga tembus. Sebagian jaringan sengaja memblokirnya. Relay milik kami cukup satu koneksi biasa dan biasanya tetap berhasil - atau pakai jembatan, yang lebih lama disiapkan.';

  @override
  String get homeSwitchedToRelay => 'Beralih ke relay';

  @override
  String get homeUseOurRelay => 'Pakai relay kami';

  @override
  String get homeBridges => 'Jembatan';

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
  String homeWaitingTorIsStill(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString menunggu · tor masih menghubungkan',
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
      other: '$countString menunggu · sampai kamu ditambahkan balik',
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
          '$countString menunggu · $parkedString sampai kamu ditambahkan balik',
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
      other: '$countString menunggu · sedang dikirim',
    );
    return '$_temp0';
  }

  @override
  String get commonRetry => 'Coba lagi';

  @override
  String get homeNoKryfosYet => 'Belum ada Kryfo.';

  @override
  String get homeScanTheirCodeSend =>
      'Pindai kodenya, kirimi dia tautan, atau ketik @nama pengguna yang dia berikan.';

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
  String get homeArchivedChats => 'Obrolan diarsipkan';

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
  String get homeDeleteThisChat => 'Hapus obrolan ini?';

  @override
  String homeEveryMessageWithGoes(Object c) {
    return 'Semua pesan dengan $c terhapus, dan dia tidak lagi jadi kontak. Ini hanya membersihkan ponsel ini - salinannya tetap ada padanya. Kalau dia mengirim pesan lagi, pesannya masuk ke permintaan.';
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
  String get introduceANoteLikeMy => 'Catatan, misalnya “sepupuku” - opsional';

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
  String keyVerificationWith(Object peerName) {
    return 'Dengan $peerName';
  }

  @override
  String keyVerificationIfSeesTheSame(Object peerName) {
    return 'Kalau $peerName melihat nomor yang sama, pesan kalian hanya untuk kalian berdua. Membandingkan secara tatap muka atau lewat panggilan yang kamu percaya adalah cara paling pasti - tapi ini opsional, tidak pernah wajib untuk mengobrol.';
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
      'Periksa huruf besar dan spasi. Tidak ada yang bisa meresetnya, termasuk kami.';

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
  String get lockFileCouldNotMakeOne => 'Gagal membuatnya. Ketik sendiri.';

  @override
  String get lockFileWriteItDownBefore =>
      'Catat dulu sebelum kamu mengunci file';

  @override
  String get lockFileNoAppOnThis =>
      'Tidak ada aplikasi di ponsel ini yang menerima file itu.';

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
      'Siapa pun yang tahu kata sandinya bisa membukanya, di Kryfo atau di komputer mana pun dengan alat gratis age. Lupa kata sandinya, file ini hilang selamanya. Tidak ada yang bisa meresetnya, termasuk kami.';

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
  String get modesOnion => 'Onion';

  @override
  String get modesFullOnionRoutingThree =>
      'Perutean onion penuh, tiga lompatan. Satu pesan butuh dua sampai lima detik. Tidak ada yang melihat dengan siapa kamu bicara.';

  @override
  String get modesSlower => 'Lebih lambat';

  @override
  String get modesRelay => 'Relay';

  @override
  String get modesOneSealedConnectionTo =>
      'Satu koneksi tersegel ke relay milik Kryfo, seperti vpn yang tidak punya apa-apa untuk dicatat. Kiriman sampai dalam sekitar satu detik, dan tetap jalan di tempat tor diblokir.';

  @override
  String get modesQuick => 'Cepat';

  @override
  String get modesRelayOnly => 'Hanya relay';

  @override
  String get modesFast => 'Cepat';

  @override
  String get modesPlainConnectionsToEvery =>
      'Koneksi biasa ke setiap relay. Hampir seketika, dan paling tidak privat di antara ketiganya.';

  @override
  String get modesInstant => 'Seketika';

  @override
  String get modesEveryRelayYouUse =>
      'Setiap relay yang kamu pakai tahu alamat asal koneksimu, bukan hanya relay kami. Pesan tetap tersegel, tapi fakta bahwa kamu mengirimnya tidak. Mati secara bawaan, dan mati lagi setelah instal ulang.';

  @override
  String get modesSpeed => 'Kecepatan';

  @override
  String get modesPrivacy => '& privasi';

  @override
  String get modesChangeGloballyOrPer => 'Ubah untuk semua, atau per obrolan';

  @override
  String get modesSoon => 'Segera';

  @override
  String get modesActive => 'Aktif';

  @override
  String get modesSpeed2 => 'KECEPATAN';

  @override
  String get modesHops => 'LOMPATAN';

  @override
  String get modesIp => 'IP';

  @override
  String get modesVisible => 'Terlihat';

  @override
  String get modesHidden => 'Tersembunyi';

  @override
  String modesHeadsUp(Object warning) {
    return '*Perhatian:* $warning';
  }

  @override
  String get modesOnionIsTheDefault =>
      'Onion adalah bawaan dan tetap begitu kecuali kamu mengubahnya. Perubahan berlaku mulai pesan berikutnya.';

  @override
  String get modesFastMode => 'Mode cepat';

  @override
  String get modesPlainConnectionsToEveryRelayQuicker =>
      'Koneksi biasa ke setiap relay. Lebih cepat, dan relay-relay itu bisa melihat alamat IP-mu. Apa pun modenya, pesan tetap terenkripsi ujung ke ujung.';

  @override
  String get modesTurnOnFastMode => 'Nyalakan mode cepat';

  @override
  String get modesKeepItOff => 'Biarkan mati';

  @override
  String get movedWipeThisPhone => 'Hapus total Kryfo dari ponsel ini?';

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
  String get movedReopenKryfo => 'Buka lagi Kryfo';

  @override
  String get movedThisKryfoHasMoved => 'Kryfo ini sudah pindah';

  @override
  String movedIsNowOnAnother(Object myId) {
    return '$myId sekarang ada di perangkat lain. Ponsel ini masih bisa menampilkan isinya, tapi tidak ada yang baru akan masuk, dan apa pun yang kamu kirim dari sini tidak akan sampai ke siapa pun.';
  }

  @override
  String get movedKeepItToRead => 'Simpan untuk dibaca';

  @override
  String get movedWipeThisPhone2 => 'Hapus total Kryfo dari ponsel ini';

  @override
  String get movedIMNotMoving => 'Aku tidak jadi pindah';

  @override
  String get myKryfoAHandleIs3 =>
      'Nama pengguna berisi 3 sampai 20 huruf, angka, atau _';

  @override
  String get myKryfoInviteCopiedClearsIn =>
      'Undangan disalin · dihapus dalam 60 dtk';

  @override
  String myKryfoAddMeOnKryfo(Object myId, Object uri) {
    return 'Tambahkan aku di Kryfo. ID-ku $myId\n\nKetuk untuk menambahkanku:\n$uri\n\nKryfo adalah aplikasi pesan privat. Tanpa nomor telepon, tanpa email.';
  }

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
      'Tautan ini berisi ID-mu, alamatmu, dan kunci untuk memulai obrolan. Tautan ini berlaku sampai kamu meresetnya di pengaturan.';

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
  String get myKryfoWren => 'Wren';

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
  String get notesToday => 'HARI INI';

  @override
  String get notesYesterday => 'KEMARIN';

  @override
  String get notesNoteToSelf => 'Catatan pribadi';

  @override
  String get notesOnlyOnThisPhone => 'Hanya di ponsel ini';

  @override
  String get notesAQuietPlace => 'Tempat yang tenang';

  @override
  String get notesJotAnythingDownIt =>
      'Tulis apa saja. Semuanya tetap di ponsel ini dan tidak pernah keluar.';

  @override
  String get notesJotSomethingDown => 'Tulis sesuatu…';

  @override
  String get onboardingPrivateByDefault => 'PRIVAT SEJAK AWAL';

  @override
  String get onboardingPrivateMessaging => 'Pesan privat,\n*tanpa jebakan*.';

  @override
  String get onboardingYourNameIsThree =>
      '*Namamu tiga kata.* Tanpa nomor ponsel, tanpa email, tanpa buku alamat.';

  @override
  String get onboardingNobodyGetsInUnless =>
      '*Tak ada yang masuk tanpa izinmu.* Tidak ada pencarian. Orang ditambahkan secara manual, dari dua arah.';

  @override
  String get onboardingTheFirstConnectionTakes =>
      '*Koneksi pertama butuh satu menit.* Kryfo membangun rute privat sebelum mengirim. Setelahnya cepat.';

  @override
  String get onboardingBegin => 'Mulai';

  @override
  String get onboardingHaveABackupRestore => 'Punya cadangan? Pulihkan →';

  @override
  String get onboardingKryfoIsOpenSource => 'Kryfo bersumber terbuka';

  @override
  String get onboardingYourKryfoId => 'ID KRYFO-MU';

  @override
  String get onboardingGeneratedFromAKey =>
      'Dibuat dari kunci yang hanya ada di ponsel ini. *Mudah diingat, unik, hanya milikmu.* Tidak ada orang lain yang memilikinya.';

  @override
  String get onboardingTryAnother => 'Coba yang lain';

  @override
  String get onboardingUseThisName => 'Pakai nama ini →';

  @override
  String get onboardingThreeWords => 'Tiga kata. *Hanya milikmu.*';

  @override
  String get onboardingPickA => 'Pilih *wajah*.';

  @override
  String get onboardingDrawnOnThisPhone =>
      'Digambar di ponsel ini dari sebuah angka, tidak pernah diunggah. Ganti kapan saja kamu mau.';

  @override
  String get onboardingThePeopleYouMessage =>
      'Orang yang kamu kirimi pesan juga melihat ini';

  @override
  String get onboardingKeepMyInitial => 'Tetap pakai inisialku';

  @override
  String get onboardingThatOne => 'Yang itu →';

  @override
  String get onboardingContinue => 'Lanjut →';

  @override
  String get onboardingHowYourMessages => 'Cara pesanmu *berjalan*.';

  @override
  String get onboardingYouCanChangeThis =>
      'Kamu bisa mengubahnya kapan saja di pengaturan, untuk semua atau untuk satu obrolan.';

  @override
  String get onboardingOnion => 'Onion';

  @override
  String get onboardingSlowerAMessageTakes =>
      'Lebih lambat. Satu pesan butuh dua sampai lima detik.';

  @override
  String get onboardingHidesYourAddressFrom =>
      'Menyembunyikan alamatmu dari semua orang, termasuk relay kami.';

  @override
  String get onboardingRelay => 'Relay';

  @override
  String get onboardingOurRelaySeesYour =>
      'Relay kami melihat alamatmu. Tidak ada pihak lain yang melihatnya.';

  @override
  String get onboardingAboutASecondWorks =>
      'Sekitar satu detik. Tetap jalan di tempat tor diblokir.';

  @override
  String get onboardingFast => 'Cepat';

  @override
  String get onboardingEveryRelayYouUse =>
      'Setiap relay yang kamu pakai melihat alamatmu. Paling tidak privat di antara ketiganya.';

  @override
  String get onboardingNearInstant => 'Hampir seketika.';

  @override
  String get onboardingKeepOnion => 'Tetap onion →';

  @override
  String get onboardingUseThis => 'Pakai ini →';

  @override
  String get onboardingSkipOnionIsA =>
      'Lewati · onion sudah pilihan bawaan yang baik';

  @override
  String get onboardingThreeThingsThen => 'Tiga hal,\nlalu *kamu masuk*.';

  @override
  String get onboardingEverythingElseTheApp =>
      'Hal lain akan diberi tahu aplikasi saat dibutuhkan.';

  @override
  String get onboardingYourNameIsThreeWords => 'Namamu tiga kata';

  @override
  String get onboardingThatIsTheWhole =>
      'Itulah seluruh identitasmu. Tidak ada nomor yang bisa bocor, tidak ada email untuk di-phishing, tidak ada yang bisa dicari. Orang yang kamu ajak bicara melihat kata-kata ini dan wajah yang kamu pilih.';

  @override
  String get onboardingNobodyCanReachYou =>
      'Tidak ada yang bisa menghubungimu sampai kamu mengizinkannya masuk';

  @override
  String get onboardingAStrangerWithYour =>
      'Orang asing yang tahu kata-katamu hanya bisa mengetuk. Pesan pertamanya menunggu di permintaan sampai kamu bilang ya, dan kamu bisa menolak tanpa dia pernah tahu.';

  @override
  String get onboardingTheFirstConnectionTakesAMinute =>
      'Koneksi pertama butuh satu menit';

  @override
  String get onboardingKryfoBuildsAPrivateRouteBefore =>
      'Kryfo membangun rute privat sebelum mengirim apa pun. Saat kamu offline, pesan menunggu dan sampai saat kamu kembali.';

  @override
  String get onboardingYourIdentityLivesOn =>
      'Identitasmu tinggal di ponsel ini. Cadangkan dari pengaturan saat kamu siap.';

  @override
  String get onboardingIUnderstand => 'Aku mengerti →';

  @override
  String get onboardingOneQuiet => 'Satu *notifikasi* senyap.';

  @override
  String get onboardingAndroidNeedsAVisible =>
      'Android butuh notifikasi yang terlihat selama aplikasi mendengarkan di latar belakang. Dengan cara itulah pesan sampai ke kamu saat Kryfo ditutup.';

  @override
  String get onboardingSilentAndAtThe =>
      'Senyap, dan ada di bagian bawah panel notifikasi';

  @override
  String get onboardingItNeverBuzzesTurn =>
      'Tidak pernah bergetar. Kalau dimatikan, pesan menunggu sampai kamu membuka aplikasi lagi.';

  @override
  String get onboardingGotIt => 'Mengerti →';

  @override
  String get onboardingNow => 'Sekarang, *tambah orang*.';

  @override
  String get onboardingTheAppIsReady =>
      'Aplikasi sudah siap. Tidak ada yang bisa mengirimimu pesan sampai kamu menambahkan atau mengizinkannya masuk.';

  @override
  String get onboardingEveryWayToAdd => 'Semua cara menambah orang';

  @override
  String get onboardingShowYourCodeSend =>
      'Tunjukkan kodemu, kirimi dia tautan, atau ketik @nama pengguna yang dia berikan.';

  @override
  String get onboardingScanTheirs => 'Pindai kodenya';

  @override
  String get onboardingPointTheCameraAt => 'Arahkan kamera ke kodenya';

  @override
  String get onboardingTheAppIsReadyWhenYou =>
      'Aplikasi siap kapan pun kamu siap.';

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
  String get pairCodeSixDigits => 'Enam angka';

  @override
  String get pairCodeLooking => 'Mencari…';

  @override
  String get pairCodeNothingThereYetTrying =>
      'Belum ada apa-apa · mencoba lagi';

  @override
  String get pairCodeNothingAtThatCode =>
      'Tidak ada apa pun di kode itu. Mungkin sudah hilang, atau dia belum membagikannya.';

  @override
  String get pairCodeTypeTheSixDigits => 'Ketik enam angka yang dia bacakan.';

  @override
  String get pairCodeAddThem => 'Tambahkan';

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
  String get photoKnowsWhatThisVideoKnows => 'Yang diketahui video ini';

  @override
  String get photoKnowsWhatThisPhotoKnows => 'Yang diketahui foto ini';

  @override
  String get photoKnowsRemoveAllOfIt => 'Hapus semuanya';

  @override
  String get photoKnowsKeepItAsIt => 'Biarkan apa adanya';

  @override
  String get photoKnowsReadOnThisPhone =>
      'DIBACA DI PONSEL INI · VIDEONYA TIDAK DIKIRIM KE MANA PUN';

  @override
  String get photoKnowsReadOnThisPhoneThePhoto =>
      'DIBACA DI PONSEL INI · FOTONYA TIDAK DIKIRIM KE MANA PUN';

  @override
  String get photoKnowsReadingTheFile => 'Membaca file';

  @override
  String photoKnowsOf(Object prettySize, Object prettySize2) {
    return '$prettySize dari $prettySize2';
  }

  @override
  String get photoKnowsEverythingStaysOnThis => 'Semuanya tetap di ponsel ini.';

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
  String get pinsUnlockWithFingerprint => 'Buka kunci dengan sidik jari';

  @override
  String get pinsWipePin => 'PIN penghapus';

  @override
  String get pinsNeedsAPinFirst => 'Perlu PIN dulu';

  @override
  String get pinsSet => 'Aktif';

  @override
  String get pinsChangeWipePin => 'Ganti PIN penghapus';

  @override
  String get pinsSetAWipePin => 'Buat PIN penghapus';

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
  String get profileChangeYourFace => 'Ganti wajahmu';

  @override
  String get profileKryfoId => 'ID Kryfo';

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
      'TAUTANMU APA ADANYA · TANPA PENGALIHAN PELACAK';

  @override
  String get qrText => 'Teks';

  @override
  String get qrStaysInTheCode =>
      'TETAP DI DALAM KODE · TIDAK ADA SERVER YANG MENYIMPANNYA';

  @override
  String get qrWiFi => 'Wi-Fi';

  @override
  String get qrMadeOnThisPhone =>
      'DIBUAT DI PONSEL INI · TIDAK ADA SITUS YANG MELIHAT KATA SANDINYA';

  @override
  String get qrNetworkName => 'Nama jaringan';

  @override
  String get qrPassword => 'Kata sandi';

  @override
  String get qrContact => 'Kontak';

  @override
  String get qrOnlyWhatYouType =>
      'HANYA YANG KAMU KETIK · TIDAK ADA DARI KONTAKMU';

  @override
  String get qrName => 'Nama';

  @override
  String get qrPhone => 'Telepon';

  @override
  String get qrEmail => 'Email';

  @override
  String get qrOpensTheirMailApp =>
      'MEMBUKA APLIKASI EMAIL-NYA · TIDAK ADA YANG DIKIRIM DARI SINI';

  @override
  String get qrTo => 'Kepada';

  @override
  String get qrSubject => 'Subjek';

  @override
  String get qrANumberNothingElse => 'SEBUAH NOMOR · TIDAK LEBIH';

  @override
  String get qrNumber => 'Nomor';

  @override
  String get qrSms => 'SMS';

  @override
  String get qrOpensTheirMessagesApp =>
      'MEMBUKA APLIKASI PESANNYA · TIDAK ADA YANG DIKIRIM DARI SINI';

  @override
  String get qrMessage => 'Pesan';

  @override
  String get qrLocation => 'Lokasi';

  @override
  String get qrCoordinatesOnlyNoMap =>
      'HANYA KOORDINAT · TANPA BERTANYA KE LAYANAN PETA';

  @override
  String get qrLatitude => 'Lintang';

  @override
  String get qrLongitude => 'Bujur';

  @override
  String get qrBitcoin => 'Bitcoin';

  @override
  String get qrAddressAndAmountNo =>
      'ALAMAT DAN JUMLAH · TANPA SITUS PEMBAYARAN DI TENGAH';

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
  String get requestsBlocked => 'Diblokir';

  @override
  String get requestsDeleted => 'Dihapus';

  @override
  String get requestsRequests => 'Permintaan';

  @override
  String get requestsNoRequests => 'Tak ada permintaan';

  @override
  String get requestsMessagesFromPeopleYou =>
      'Pesan dari orang yang belum kamu tambahkan muncul di sini dulu.';

  @override
  String get requestsLooksSafeNothingSuspicious =>
      'Tampak aman · tidak ada yang mencurigakan di pesan pertamanya';

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
  String get restoreReopenKryfo => 'Buka lagi Kryfo';

  @override
  String get restoreTheRestoreDidNot =>
      'Pemulihan tidak selesai. Tidak ada yang diubah';

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
  String get restoreYourSupporterBadgeIf =>
      'Lencana pendukungmu, kalau kamu punya.';

  @override
  String get restoreWhatDoesnT => 'Yang tidak ikut';

  @override
  String get restoreTheOldPhoneStops =>
      'Ponsel lama berhenti menerima begitu kamu mengirim apa pun dari sini. Tidak bertahap. Pesan pertama yang kamu kirim dari perangkat ini adalah pesan terakhir yang bisa diikuti ponsel lama, dan apa pun yang sampai ke sana setelah itu tidak bisa dibaca di sana dan juga tidak menunggumu di sini.';

  @override
  String get restoreIfThePhoneThis =>
      'Kalau ponsel asal file ini masih dipakai, berhenti memakai Kryfo di sana sebelum kamu lanjut. Dua ponsel dengan satu Kryfo kehilangan pesan di keduanya.';

  @override
  String get restoreNotificationsNeedSettingUp =>
      'Notifikasi perlu diatur ulang di perangkat ini.';

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
  String get roomCreateOffAnyoneWithThe =>
      'Mati. Siapa pun yang punya tautannya';

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
      'Setiap aplikasi pesan mengaku privat. Ini daftar rinciannya, per jalur, termasuk bagian yang tidak menguntungkan kami. Ketuk baris untuk tahu alasannya.';

  @override
  String get seenHonestAboutTheLast =>
      'Jujur soal baris terakhir: itulah gunanya kunci aplikasi, PIN penghapus, dan penyimpanan terenkripsi, dan tidak ada alat yang bisa menyelamatkanmu dari orang yang memegang ponselmu dalam keadaan terbuka. Model ancaman lengkapnya ada di THREAT_MODEL.md di repo, disusun berdasarkan LINDDUN. Kodenya terbuka, jadi semua ini tidak perlu dipercaya begitu saja.';

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
      'Setiap obrolan punya alamatnya sendiri, diturunkan dari kedua kunci. Relay hanya melihat kotak titipan yang tidak saling terkait, bukan sepasang orang.';

  @override
  String get seenWhatYouSay => 'Isi pesanmu';

  @override
  String get seenEndToEndEncrypted =>
      'Terenkripsi ujung ke ujung dengan double ratchet Signal, lalu disegel lagi di dalam gift wrap. Kami tidak bisa membacanya meskipun kami mencoba.';

  @override
  String get seenYourIpAddress => 'Alamat IP-mu';

  @override
  String get seenOurRelay => 'Relay kami';

  @override
  String get seenEveryRelay => 'Setiap relay';

  @override
  String get seenOnOnionEverythingLeaves =>
      'Di mode onion semuanya keluar lewat tor dan relay hanya melihat exit node, tidak pernah kamu. Di mode relay koneksinya langsung ke relay milik kami: tidak ada yang meneruskan alamatmu dan tidak ada yang dicatat, tapi koneksi yang satu itu bisa kami lihat. Di mode cepat setiap relay publik tahu bahwa kamu terhubung, tapi tidak tahu ke siapa atau apa yang kamu katakan.';

  @override
  String get seenYourContactGraph => 'Jaringan kontakmu';

  @override
  String get seenKryfoDoesNotScan =>
      'Kryfo tidak memindai kontakmu. Memang itu intinya. Tidak ada nomor telepon di sini yang bisa bocor.';

  @override
  String get seenIntroducer => 'Perantara';

  @override
  String get seenWhenAContactIntroduces =>
      'Saat kontak memperkenalkanmu ke seseorang, kontak itu tahu kalian berdua sekarang terhubung. Tidak ada orang lain yang tahu. Relay hanya melihat teks terenkripsi, dan tidak ada server yang pernah melihat jaringan kontaknya.';

  @override
  String get seenTheScamShield => 'Perisai penipuan';

  @override
  String get seenRunsOnYourPhone =>
      'Berjalan di ponselmu dengan aturan bawaan aplikasi. Tanpa jaringan, tanpa mengunduh daftar. Perisai ini hanya membaca pesan pertama dari orang asing dan tidak bisa melihat apa pun yang dikirim kontakmu.';

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
      'Pratinjau diambil oleh pengirim, lewat tor, dan ikut di dalam pesan terenkripsi. Ponsel penerima tidak membuat permintaan apa pun. Situsnya hanya tahu bahwa seseorang yang memakai tor meminta sebuah halaman, tidak lebih. Tidak ada gambar yang pernah dimuat, dan tautan dari orang asing tetap berupa teks biasa.';

  @override
  String get seenASeizedUnlockedPhone => 'Ponsel tak terkunci yang disita';

  @override
  String get seenIfSomeoneHoldsYour =>
      'Kalau seseorang memegang ponselmu dalam keadaan terbuka, dia membaca pesanmu. Kunci aplikasi, PIN penghapus, dan penyimpanan terenkripsi membantu sebelum itu terjadi, bukan sesudahnya.';

  @override
  String get seenTheCryptoItself => 'Kriptografinya sendiri';

  @override
  String get seenTheRatchetAndStorage =>
      'Lapisan ratchet dan penyimpanan memakai standar. Lapisan yang menyatukannya buatan kami dan belum ada pihak independen yang memeriksanya. Anggap ini versi alfa, karena memang begitu.';

  @override
  String get seenOnion => 'Onion';

  @override
  String get seenRelay => 'Relay';

  @override
  String get seenFast => 'Cepat';

  @override
  String get settingsWipeKryfo => 'Hapus total Kryfo?';

  @override
  String get settingsIdentityMessagesContactsAnd =>
      'Identitas, pesan, kontak, dan pengaturan di ponsel ini. Hilang selamanya kecuali kamu punya cadangan.';

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
  String get settingsConnecting => 'Menghubungkan';

  @override
  String get settingsOffMode => 'Mati · mode relay';

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
  String get settingsRelay1Hop => 'Relay · 1 lompatan';

  @override
  String get settingsOnion3Hops => 'Onion · 3 lompatan';

  @override
  String get settingsBridges => 'Jembatan';

  @override
  String get settingsForNetworksThatBlock =>
      'Untuk jaringan yang memblokir tor';

  @override
  String get settingsGettingMessages => 'Menerima pesan';

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
  String get settingsChecksStrangersOnYour =>
      'Memeriksa orang asing di ponselmu. Tidak ada yang keluar darinya';

  @override
  String get settingsBlockScreenshots => 'Blokir tangkapan layar';

  @override
  String get settingsWholeAppHiddenFrom =>
      'Seluruh aplikasi disembunyikan dari aplikasi terbaru dan tangkapan layar · berlaku setelah mulai ulang berikutnya';

  @override
  String get settingsWholeAppHiddenFromRecentsAnd =>
      'Seluruh aplikasi disembunyikan dari aplikasi terbaru dan tangkapan layar';

  @override
  String get settingsOnNextStart => 'Aktif · mulai berikutnya';

  @override
  String get settingsOffNextStart => 'Mati · mulai berikutnya';

  @override
  String get settingsLightTheme => 'Tema terang';

  @override
  String get settingsSameProtectionBrighter =>
      'Perlindungan sama, lebih terang';

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
  String get settingsDisguiseVoice => 'Samarkan suara';

  @override
  String get settingsShiftsYourPitchBefore =>
      'Mengubah nada suaramu sebelum pesan suara dikirim';

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
  String get settings030Alpha => '0.4.1 · alfa';

  @override
  String get settingsReportAnIssue => 'Laporkan masalah';

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
      'Belum diaudit secara independen. Pra-alfa - cocok untuk uji coba, belum untuk penggunaan berisiko tinggi.';

  @override
  String get settingsDangerZone => 'Zona bahaya';

  @override
  String get settingsWipeKryfoFromThis => 'Hapus total Kryfo dari ponsel ini';

  @override
  String get shieldCheckedOnThisPhone =>
      'Dicek di ponsel ini. Tidak ada yang dikirim ke mana pun.';

  @override
  String get toolsMoreTools => 'Alat lainnya';

  @override
  String get toolsCleanAPhotoOr => 'Bersihkan foto atau video';

  @override
  String get toolsOrShareOneTo => 'Atau bagikan ke Kryfo dari galerimu';

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
  String get toolsWhatDoesThisPhoto => 'Apa yang diketahui foto ini?';

  @override
  String get toolsPlacePhoneTime => 'Tempat · ponsel · waktu';

  @override
  String get toolsPickAPhotoAnd =>
      'Pilih foto dan lihat apa yang dibocorkannya. Lalu simpan salinan bersihnya.';

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
  String get transportSendAnythingWaitingNow =>
      'Kirim semua yang menunggu, sekarang';

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
  String get wallpaperFromYourPhotos => 'Dari galerimu';

  @override
  String get wallpaperKeepIt => 'Simpan';

  @override
  String get whyKryfoWhyKryfo => 'Kenapa Kryfo';

  @override
  String get whyKryfoKryfoKreeFoGreek =>
      'Kryfo · KRI-fo · bahasa Yunani untuk tersembunyi.\nTempat tenang untuk bicara, dibuat agar tidak ada yang mengawasi.';

  @override
  String get whyKryfoRoutedThroughTor => 'Dirutekan lewat tor';

  @override
  String get whyKryfoByDefaultEveryMessage =>
      'Secara bawaan setiap pesan berjalan lewat tor - rangkaian relay. Tidak ada yang bisa melihat dengan siapa kamu bicara atau di mana kamu berada, baik kami maupun jaringanmu.';

  @override
  String get whyKryfoEndToEndEncrypted => 'Terenkripsi ujung ke ujung';

  @override
  String get whyKryfoMessagesAreSealedWith =>
      'Pesan disegel dengan kunci yang hanya dipegang kamu dan lawan bicaramu. Kami tidak bisa membacanya meskipun kami mencoba.';

  @override
  String get whyKryfoNoServersHoldingYour =>
      'Tidak ada server yang menyimpan hidupmu';

  @override
  String get whyKryfoNoAccountNoPhone =>
      'Tanpa akun, tanpa nomor telepon, tanpa server pusat yang menyimpan obrolanmu. Semuanya tinggal di ponsel ini, terenkripsi saat tersimpan.';

  @override
  String get whyKryfoNothingLeaks => 'Tidak ada yang bocor';

  @override
  String get whyKryfoNoReadReceiptsOr =>
      'Tidak ada tanda dibaca atau tanda mengetik yang diserahkan ke siapa pun, tidak ada daftar kontak yang diunggah. Metadata adalah hal yang dibocorkan kebanyakan aplikasi - Kryfo dibuat agar tidak membocorkannya.';

  @override
  String get whyKryfoVerifyItIsReally => 'Pastikan itu benar-benar dia';

  @override
  String get whyKryfoCompareASafetyNumber =>
      'Bandingkan nomor keamanan secara tatap muka atau lewat saluran yang kamu percaya, agar kamu tahu tidak ada yang menyamar sebagai kontakmu.';

  @override
  String get whyKryfoTheHonestPart => 'Bagian jujurnya';

  @override
  String get whyKryfoKryfoIsPreAlpha =>
      'Kryfo masih pra-alfa dan belum diaudit. Kriptografinya sungguhan, tapi belum ada pakar luar yang memeriksanya, jadi anggap ini masih dalam pengerjaan, belum sesuatu yang bisa kamu percayakan nyawamu.';

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
  String get kryfoLinkTextBurnerRoom => 'RUANG SEKALI PAKAI';

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
      'Kamu bergabung dengan kunci yang dibuat khusus untuk ruang ini. Tidak ada seorang pun di dalamnya yang melihat ID Kryfo-mu.';

  @override
  String get linkStubFetchedOverTorBy => 'Diambil lewat tor · oleh perangkatmu';

  @override
  String get linkStubFetchedOverTorByTheirDevice =>
      'Diambil lewat tor · oleh perangkatnya';

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
  String get mediaBubblesMicPermissionNeeded => 'Perlu izin mikrofon';

  @override
  String get mediaBubblesReleaseToCancel => 'Lepas untuk batal';

  @override
  String get mediaBubblesVoiceHiddenSlideTo =>
      'Suara disamarkan · geser untuk batal';

  @override
  String get mediaBubblesSlideToCancel => 'Geser untuk batal';

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
  String get motionTorIsStartingIn =>
      'Tor sedang dimulai di latar belakang. Grafik ini menyala seiring koneksi terbentuk.';

  @override
  String get motionMakingAFreshRoute => 'Membuat rute baru lewat relay anonim.';

  @override
  String get motionBouncingThroughRelaysSo =>
      'Memantul lewat relay-relay agar tidak ada yang bisa melacaknya kembali ke kamu.';

  @override
  String get motionTellingTheNetworkYou =>
      'Memberi tahu jaringan bahwa kamu online — tanpa mengungkap di mana.';

  @override
  String get motionYourIpIsHidden =>
      'IP-mu tersembunyi. Hanya orang yang punya Kryfo-mu yang bisa menghubungimu.';

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
  String get pairCodePanelReadSixDigitsOut =>
      'Bacakan enam angka dengan keras dan dia bisa menambahkanmu. Tidak ada hal lain yang perlu dipertukarkan.';

  @override
  String get pairCodePanelWorking => 'Memproses';

  @override
  String get pairCodePanelOrMakeASix =>
      'Atau buat kode enam angka untuk dibacakan';

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
  String get pairCodePanelTheyOpenKryfoTap =>
      'Dia membuka Kryfo, mengetuk tambah, memilih kode penautan, lalu mengetik enam angka ini. Buat yang baru untuk orang berikutnya.';

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
  String powNoteFirstMessageToSomeone(int secs) {
    final intl.NumberFormat secsNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String secsString = secsNumberFormat.format(secs);

    return 'Pesan pertama ke orang baru · membuktikan ini asli · $secsString dtk';
  }

  @override
  String powNoteFirstMessageSlow(int secs) {
    final intl.NumberFormat secsNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String secsString = secsNumberFormat.format(secs);

    return 'Pesan pertama ke orang baru · membuktikan ini asli · $secsString dtk · bisa sampai semenit di ponsel lambat';
  }

  @override
  String previewStripFetchedOverTor(Object domainOf) {
    return '$domainOf · diambil lewat tor';
  }

  @override
  String get previewStripDropThePreview => 'Buang pratinjau';

  @override
  String get previewStripAddPreview => 'Tambah pratinjau';

  @override
  String get previewStripFetchingOverTor => 'Mengambil lewat tor…';

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
  String get torBootSplashFirstLaunchTakesA =>
      'Pembukaan pertama butuh sebentar · hanya saat mulai';

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
  String get bridgesSavedTag => 'Tersimpan';

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
  String get shieldBlock => 'Blokir';

  @override
  String get shieldDelete => 'Hapus';

  @override
  String get shieldIgnore => 'Abaikan';

  @override
  String get profileIdentity => 'Identitas';

  @override
  String get avatarPickerShape => 'Bentuk';

  @override
  String get avatarPickerColour => 'Warna';

  @override
  String get avatarPickerTurn => 'Putar';

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
  String get settingsScreenshots => 'Tangkapan layar';

  @override
  String get settingsBlocked2 => 'Diblokir';

  @override
  String get settingsAllowed => 'Diizinkan';

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
  String bridgesSaved(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString jembatan',
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

    return '$goodString diterima, $badString tidak dikenali';
  }

  @override
  String get languageTitle => 'Bahasa';

  @override
  String get languageMatchPhone => 'Ikuti ponsel';

  @override
  String languageMatchPhoneValue(Object language) {
    return 'Ikuti ponsel ($language)';
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
  String get searchOpen => 'Cari';

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
      'Tidak bisa menghubungi registri. Coba lagi semenit lagi.';

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
  String get settingsKeptOnWhileLock =>
      'Tetap aktif selama kunci aplikasi aktif.';

  @override
  String get lockFingerAfterPin =>
      'Ketik PIN sekali untuk memakai sidik jari lagi.';

  @override
  String get pinsAdvanced => 'Perlindungan lanjutan';

  @override
  String get pinsAdvancedLine =>
      'Untuk saat seseorang memaksamu membuka kunci ponsel.';

  @override
  String get pinsWipeLine =>
      'Jika diketik di layar kunci, PIN ini menghapus Kryfo dari ponsel ini.';

  @override
  String get pinsDecoyPin => 'PIN umpan';

  @override
  String get pinsDecoyLine => 'Membuka Kryfo kosong, seperti baru dipasang.';

  @override
  String get pinsSetADecoyPin => 'Buat PIN umpan';

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
      'Sidik jarimu membuka Kryfo-mu yang asli. Jika seseorang bisa memaksamu memakainya, matikan sidik jari.';

  @override
  String get flowDecoyDigits =>
      'Pakai jumlah angka yang sama dengan PIN-mu, karena siapa pun yang melihat bisa menghitung titiknya.';

  @override
  String get flowDecoyShade =>
      'Notifikasi yang sudah ada di panel sudah terlihat. Selama umpan terbuka, tidak ada notifikasi baru yang muncul.';

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
      'Kalau kamu lupa PIN ini, obrolan tersembunyimu hilang untuk selamanya. Tidak ada yang bisa memulihkannya, bahkan kami.';

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
      'Kunci Marios tertanam di Kryfo. Setiap pesan di obrolan ini dicocokkan dengan kunci itu, jadi tidak ada orang lain yang bisa menulis atas namanya.';

  @override
  String get devKeyLabel => 'Kuncinya';

  @override
  String get devDeleteLine =>
      'Semua pesan terhapus, dan obrolan ini tidak akan kembali.';

  @override
  String get devDeleteLineAnon =>
      'Semua pesan dan nama yang dibuat untuk obrolan ini terhapus, dan obrolan ini tidak akan kembali.';

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
  String get devWhoSeesWhat => 'Siapa melihat apa';

  @override
  String get devWhoWords =>
      'Dengan tiga katamu, ini obrolan seperti yang lain: Marios bisa membalas, dan wajah serta lencana pendukungmu tetap bersamamu.';

  @override
  String get devWhoAnon =>
      'Secara anonim, Kryfo membuat nama dan kunci baru khusus untuk obrolan ini. Semuanya tetap di ponsel ini dan tidak pernah dipakai di tempat lain.';

  @override
  String get devWhoNothingYet =>
      'Tidak ada yang keluar dari ponselmu sampai kamu mengirim pesan pertamamu.';

  @override
  String get devWhoChoiceStays => 'Pilihanmu melekat pada obrolan ini.';

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
      'Kunci ini sudah dipensiunkan. Tidak ada lagi yang bisa dikirim atau diterima di sini.';

  @override
  String get devNamelessLine =>
      'Nama yang dibuat untuk obrolan ini tetap di ponsel tempat nama itu dibuat, jadi di sini obrolan ini hanya bisa dibaca.';

  @override
  String get devStartNewLine =>
      'Semua pesan di sini terhapus, dan obrolan baru terbuka.';

  @override
  String get devVoiceDisguised => 'Suaramu disamarkan di obrolan ini';

  @override
  String get devChatOptions => 'Opsi obrolan';
}
