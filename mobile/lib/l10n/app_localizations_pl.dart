// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Polish (`pl`).
class AppLocalizationsPl extends AppLocalizations {
  AppLocalizationsPl([String locale = 'pl']) : super(locale);

  @override
  String get atmosphereNone => 'Brak';

  @override
  String get atmosphereEmber => 'Żar';

  @override
  String get atmosphereDusk => 'Zmierzch';

  @override
  String get atmosphereMoss => 'Mech';

  @override
  String get atmosphereRose => 'Róża';

  @override
  String get atmosphereDots => 'Kropki';

  @override
  String get atmosphereGrid => 'Kratka';

  @override
  String get atmosphereWaves => 'Fale';

  @override
  String get atmosphereRain => 'Deszcz';

  @override
  String get atmosphereLateNight => 'Późna noc';

  @override
  String get atmosphereWarmAfternoon => 'Ciepłe popołudnie';

  @override
  String get atmosphereSnow => 'Śnieg';

  @override
  String get atmosphereDesert => 'Pustynia';

  @override
  String get atmospherePaper => 'Papier';

  @override
  String get accentYellow => 'Żółty';

  @override
  String get accentGrey => 'Szary';

  @override
  String get accentPurple => 'Fioletowy';

  @override
  String get accentLime => 'Limonkowy';

  @override
  String get accentVelvet => 'Aksamitny';

  @override
  String get accentBlue => 'Niebieski';

  @override
  String get appearancePreview => 'Podgląd twoich czatów w tym kolorze';

  @override
  String get appearanceSampleIn => 'Aktualne na dziś wieczór?';

  @override
  String get appearanceSampleOut => 'Tak. O ósmej, tam gdzie zwykle.';

  @override
  String get appearanceSampleButton => 'Odpowiedz';

  @override
  String get appearanceAccentHint =>
      'Ten kolor mają przyciski, twoje wiadomości i linki. Ikona aplikacji zostaje żółta.';

  @override
  String get appearanceChatWallpaper => 'Tapeta czatu';

  @override
  String get appearanceEveryChat => 'Każdy czat';

  @override
  String get appearanceWallpaperHint =>
      'Własna tapeta czatu, ustawiona w jego menu, ma pierwszeństwo. Zdjęcia zostają na tym telefonie, zaszyfrowane razem z czatami.';

  @override
  String get appearanceWallpaperHintDesk =>
      'Własna tapeta czatu, ustawiona w jego menu, ma pierwszeństwo. Zdjęcia zostają na tym komputerze, zaszyfrowane razem z czatami.';

  @override
  String get backupThatPassphraseDoesNot => 'To hasło nie otwiera tego pliku';

  @override
  String get backupThatFileIsNot => 'Ten plik nie jest kopią zapasową Kryfo';

  @override
  String get backupThisBackupIsFrom =>
      'Ta kopia zapasowa pochodzi z nowszego Kryfo. Zaktualizuj aplikację i spróbuj ponownie';

  @override
  String get backupThisFileIsDamaged =>
      'Ten plik jest uszkodzony i nie da się go odczytać';

  @override
  String get backupTheRestoreStoppedPartway =>
      'Przywracanie zatrzymało się w połowie';

  @override
  String get backupCouldNotMakeThe => 'Nie udało się utworzyć klucza';

  @override
  String get contactCardMessageMeOn => 'Napisz do mnie na';

  @override
  String get contactCardScanToAdd =>
      'Zeskanuj go w Kryfo, żeby mnie dodać.\nTa wizytówka nie wie o tobie nic więcej.';

  @override
  String contactCardMessageMeOnKryfo(Object haloId) {
    return 'Napisz do mnie na Kryfo · $haloId';
  }

  @override
  String get contactStatusBlocked => 'Zablokowany';

  @override
  String get contactStatusKeysVerifiedInPerson => 'Klucze sprawdzone osobiście';

  @override
  String get contactStatusWaitingInRequests => 'Czeka w prośbach';

  @override
  String get deliveryModeAlwaysOn => 'Zawsze włączone';

  @override
  String get deliveryModeCheckIns => 'Sprawdzenia';

  @override
  String get deliveryModeThroughAHelperApp => 'Przez aplikację pomocniczą';

  @override
  String get deliveryModeNotYet => 'jeszcze nie';

  @override
  String get deliveryModeJustNow => 'przed chwilą';

  @override
  String deliveryModeMinAgo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString min temu',
      many: '$countString min temu',
      few: '$countString min temu',
      one: '$countString min temu',
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
      other: '$countString godz temu',
      many: '$countString godz temu',
      few: '$countString godz temu',
      one: '$countString godz temu',
    );
    return '$_temp0';
  }

  @override
  String get deliveryModeYesterday => 'wczoraj';

  @override
  String deliveryModeDaysAgo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString dnia temu',
      many: '$countString dni temu',
      few: '$countString dni temu',
      one: '$countString dzień temu',
    );
    return '$_temp0';
  }

  @override
  String get deliveryModeConnected => 'Połączono';

  @override
  String get deliveryModeConnecting => 'Łączenie';

  @override
  String get deliveryModeNotConnected => 'Brak połączenia';

  @override
  String get deliveryModeCheckingNow => 'Sprawdzam teraz';

  @override
  String deliveryModeLastCheckIn(Object agoLine) {
    return 'ostatnie sprawdzenie $agoLine';
  }

  @override
  String get deliveryModeNoCheckInYet => 'jeszcze bez sprawdzenia';

  @override
  String deliveryModeConnectedNow(Object last) {
    return 'Połączono teraz · $last';
  }

  @override
  String deliveryModeConnecting2(Object last) {
    return 'Łączenie · $last';
  }

  @override
  String get deliveryModeNoCheckInYet2 => 'Jeszcze bez sprawdzenia';

  @override
  String deliveryModeLastChecked(Object agoLine) {
    return 'Ostatnio sprawdzono $agoLine';
  }

  @override
  String get deliveryModeAHelperApp => 'aplikacja pomocnicza';

  @override
  String deliveryModeWokenByNoWake(Object who) {
    return 'Budzi: $who · jeszcze nieobudzony';
  }

  @override
  String deliveryModeWokenByLastWake(Object who, Object agoLine) {
    return 'Budzi: $who · ostatnia pobudka $agoLine';
  }

  @override
  String get introBudgetTomorrow => 'jutro';

  @override
  String introBudgetInDays(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'za $countString dnia',
      many: 'za $countString dni',
      few: 'za $countString dni',
      one: 'za $countString dzień',
    );
    return '$_temp0';
  }

  @override
  String get introBudgetInAnHour => 'za godzinę';

  @override
  String introBudgetInHours(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'za $countString godz',
      many: 'za $countString godz',
      few: 'za $countString godz',
      one: 'za $countString godz',
    );
    return '$_temp0';
  }

  @override
  String get introBudgetInAFewMinutes => 'za kilka minut';

  @override
  String get lockStateUnlockKryfo => 'Odblokuj Kryfo';

  @override
  String get appInvalidUri => 'Nieprawidłowy adres';

  @override
  String appBundleError(Object e) {
    return 'Błąd pakietu: $e';
  }

  @override
  String appAlreadySaved(Object parsed) {
    return 'Już zapisano: $parsed';
  }

  @override
  String appLongWindow(Object line) {
    return '$line długie okno czasowe';
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
      other: '$pString strony',
      many: '$pString stron',
      few: '$pString strony',
      one: '$pString strona',
    );
    String _temp1 = intl.Intl.pluralLogic(
      e,
      locale: localeName,
      other: '$eString zdarzenia',
      many: '$eString zdarzeń',
      few: '$eString zdarzenia',
      one: '$eString zdarzenie',
    );
    return '$line ($heldString z $subsString, połączenie $c s, $_temp0, $_temp1)';
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
      other: '$pString strony',
      many: '$pString stron',
      few: '$pString strony',
      one: '$pString strona',
    );
    String _temp1 = intl.Intl.pluralLogic(
      e,
      locale: localeName,
      other: '$eString zdarzenia',
      many: '$eString zdarzeń',
      few: '$eString zdarzenia',
      one: '$eString zdarzenie',
    );
    return '$line (połączenie $c s, $_temp0, $_temp1)';
  }

  @override
  String appSDropped(Object host, Object secs) {
    return '$host $secs s, zerwane';
  }

  @override
  String appS(Object host, Object secs) {
    return '$host $secs s';
  }

  @override
  String get appTorWouldNotWake => 'Tor się nie obudził';

  @override
  String get appCheckStarted => 'Rozpoczęte';

  @override
  String get appTorNotReadyIn => 'Tor nie był gotowy w 75 s';

  @override
  String get appOk => 'OK';

  @override
  String get appOkNoRelayBegan => 'OK, żaden przekaźnik nie zaczął';

  @override
  String get appNoRelayReached => 'Nie dotarto do żadnego przekaźnika';

  @override
  String get appOkCapped => 'OK, przerwane po czasie';

  @override
  String appSBy(Object how, int secs, String why) {
    final intl.NumberFormat secsNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String secsString = secsNumberFormat.format(secs);

    String _temp0 = intl.Intl.selectLogic(why, {
      'push': '$how, $secsString s, przez push',
      'other': '$how, $secsString s, przez zadanie w tle',
    });
    return '$_temp0';
  }

  @override
  String get appAnAttachmentCouldNot =>
      'Nie udało się zapisać załącznika na tym telefonie';

  @override
  String get appAnAttachmentCouldNotDesk =>
      'Nie udało się zapisać załącznika na tym komputerze';

  @override
  String get appGroup2 => 'Grupa';

  @override
  String get appVoiceMessage => 'Wiadomość głosowa';

  @override
  String get appPhoto => 'Zdjęcie';

  @override
  String get appNewRequest => 'Nowa prośba';

  @override
  String get appSomeoneYouHaveNot =>
      'Nowa wiadomość od kogoś spoza twoich kontaktów';

  @override
  String get appSettingUpYourKeys => 'Przygotowuję twoje klucze';

  @override
  String get appOpeningYourChats => 'Otwieram twoje czaty';

  @override
  String get appStartingTor => 'Uruchamiam Tor';

  @override
  String get appTimedMessagesAreNot =>
      'Wiadomości czasowe się nie usuwają. Uruchom ponownie Kryfo';

  @override
  String get appVoiceMessage2 => 'Wiadomość głosowa';

  @override
  String appYou(Object body) {
    return 'Ty: $body';
  }

  @override
  String get appThisRoomHasAlready => 'Ten pokój już wygasł';

  @override
  String get appYouAreAlreadyIn => 'Już jesteś w tym pokoju';

  @override
  String get appCouldNotMakeA => 'Nie udało się utworzyć klucza pokoju';

  @override
  String appJoined(Object linkName) {
    return 'Dołączono do $linkName';
  }

  @override
  String get roomJoinWaitingToJoin => 'Czekam na wejście';

  @override
  String get roomJoinNotAnswering => 'Nie odpowiada';

  @override
  String roomJoinWaitingFor(Object room) {
    return 'Czekam, aż $room cię wpuści…';
  }

  @override
  String get roomJoinWaitingLine => 'Możesz tu pisać dopiero po wejściu.';

  @override
  String get roomJoinNoAnswer => 'Ten pokój nie odpowiada.';

  @override
  String get roomJoinMayHaveEnded => 'Możliwe, że już się skończył.';

  @override
  String get roomJoinFullShort => 'Pokój pełny';

  @override
  String get roomJoinFull => 'Ten pokój jest pełny.';

  @override
  String get roomJoinFullLine =>
      'Teraz nie ma wolnego miejsca. Spróbuj później albo zapytaj osobę, która udostępniła link.';

  @override
  String get appBooting => 'Uruchamianie...';

  @override
  String get appSettingUpYourIdentity => 'Przygotowuję twoją tożsamość...';

  @override
  String get appAddSomeone => 'Dodaj kogoś';

  @override
  String get appScanTheirCodeOr =>
      'Zeskanuj kod tej osoby albo wklej to, co od niej masz: link, @nazwę lub link do pokoju.';

  @override
  String get appScanTheirCodeOrDesk =>
      'Wklej to, co ci dano: link, @nazwę lub link do pokoju.';

  @override
  String get appScanTheirCode => 'Zeskanuj kod';

  @override
  String get appAKryfoLinkA => 'Link Kryfo, link do pokoju albo @name';

  @override
  String get appAddThem => 'Dodaj go';

  @override
  String get appEveryWayToAdd => 'Wszystkie sposoby dodawania';

  @override
  String get appShowYourCodeSend =>
      'Pokaż swój kod, wyślij link, zajmij nazwę użytkownika';

  @override
  String get appHelloFromTheOther => 'Pozdrowienia z drugiej strony';

  @override
  String get appIdentityRestored => 'Tożsamość przywrócona';

  @override
  String get appIdentityCreated => 'Tożsamość utworzona';

  @override
  String get appStartingTor30s => 'Uruchamiam Tor (~30 s)...';

  @override
  String get appScanOrImportA => 'Najpierw zeskanuj albo zaimportuj kontakt';

  @override
  String get appEncryptingSending30s => 'Szyfruję i wysyłam (~30 s)...';

  @override
  String get appTapStartListeningFirst => 'Najpierw stuknij „Zacznij nasłuch”';

  @override
  String get appYourKryfo => 'Twoje Kryfo';

  @override
  String get appUriCopied => 'Adres skopiowany';

  @override
  String get appCopyUri => 'Kopiuj adres';

  @override
  String get appAddAKryfo => 'Dodaj Kryfo';

  @override
  String get appScanQr => 'Skanuj QR';

  @override
  String get appPairingCode => 'Kod parowania';

  @override
  String get appOrPaste => '- albo wklej -';

  @override
  String get commonCancel => 'Anuluj';

  @override
  String get appImport => 'Importuj';

  @override
  String get appDev => 'Dev';

  @override
  String get appYourKryfo2 => 'Twoje Kryfo:';

  @override
  String get appRestoredFromDisk => 'Przywrócono z dysku';

  @override
  String get appStartListening => 'Zacznij nasłuch';

  @override
  String get appListening => 'Nasłuchuję';

  @override
  String get appShowMyQr => 'Pokaż mój QR';

  @override
  String get appImportPeer => 'Importuj kontakt';

  @override
  String get appPeer => 'Kontakt:';

  @override
  String get appMessageWillBeEncrypted => 'Wiadomość (zostanie zaszyfrowana)';

  @override
  String get appEncryptSend => 'Zaszyfruj i wyślij';

  @override
  String appStatus(Object status) {
    return 'Stan: $status';
  }

  @override
  String get appSpeedPrivacy => 'Szybkość i prywatność →';

  @override
  String get appDisableAppLock => 'Wyłączyć blokadę aplikacji?';

  @override
  String get appThePinWillBe =>
      'PIN zostanie usunięty. Każdy, kto ma twój telefon, zobaczy Kryfo po otwarciu.';

  @override
  String get appDisable => 'Wyłącz';

  @override
  String get appAppLockOn => 'Blokada aplikacji · wł. →';

  @override
  String get appAppLockOff => 'Blokada aplikacji · wył. →';

  @override
  String get appTorIsOff => 'Tor jest wyłączony';

  @override
  String get appConnectedRoutedThrough3 => 'Połączono · przez 3 przekaźniki';

  @override
  String get appReadyToChatAddressFinishing =>
      'Gotowe do czatu · adres się kończy';

  @override
  String get appTor => 'Tor';

  @override
  String get appTorIsOffTurn =>
      'Tor jest wyłączony. Włącz go, żeby łączyć się prywatnie.';

  @override
  String get appTheFirstConnectionTakes =>
      'Pierwsze połączenie trwa minutę lub dwie, ponieważ Tor buduje prywatną trasę. Potem jest zapamiętana, więc kolejne otwarcie Kryfo jest dużo szybsze.';

  @override
  String get appTorNoRelayYet =>
      'Tor działa, ale żaden przekaźnik jeszcze nie odpowiada. Kryfo próbuje dalej, a wiadomości czekają tutaj, aż któryś odpowie.';

  @override
  String get appRelayAndFastModes =>
      'Tryb szybki omija sieć Tor i działa szybciej. Znajdziesz go w Ustawieniach w sekcji „Szybkość i prywatność” wraz z informacją o jego kosztach.';

  @override
  String get appOffline => 'Offline';

  @override
  String get appTorOff => 'Tor wył.';

  @override
  String get appTorReady => 'Tor gotowy';

  @override
  String get appConnecting2 => 'Łączenie';

  @override
  String get appWaitingForARelay => 'Czekam na przekaźnik';

  @override
  String appStartingTorPct(Object pct) {
    return 'Uruchamiam Tor · $pct';
  }

  @override
  String get appGettingNewMessages => 'Pobieram nowe wiadomości';

  @override
  String mediaProgressSendingKeepTheApp(Object v) {
    return 'Wysyłanie · $v · nie zamykaj aplikacji';
  }

  @override
  String mediaProgressPausedOfWaitingFor(Object count, Object count2) {
    return 'Wstrzymano · $count z $count2 · czekam na resztę';
  }

  @override
  String mediaProgressReceivingMedia(Object v) {
    return 'Odbieranie multimediów · $v';
  }

  @override
  String get mediaProgressCancelSending => 'Anuluj wysyłanie';

  @override
  String get metaReaderEndsBeforeItShould => 'kończy się za wcześnie';

  @override
  String get metaReaderCouldNotBeRead => 'nie da się odczytać';

  @override
  String get metaReaderExifThatCannotBe => 'nieczytelne exif';

  @override
  String get metaReaderSamsungTrailer => 'dane końcowe samsunga';

  @override
  String metaReaderChunk(Object type) {
    return 'blok $type';
  }

  @override
  String get metaReaderExifFlagSet => 'ustawiona flaga exif';

  @override
  String get metaReaderXmpFlagSet => 'ustawiona flaga xmp';

  @override
  String metaReaderAppBlock(Object id) {
    return 'blokada aplikacji $id';
  }

  @override
  String get metaReaderUuidBox => 'pole uuid';

  @override
  String metaReaderBox(Object printable) {
    return 'pole $printable';
  }

  @override
  String get metaReaderAttachedData => 'dołączone dane';

  @override
  String metaReaderItem(Object printable) {
    return 'element $printable';
  }

  @override
  String get miuiAutostartAlreadyAllowedToRun => 'Już może działać w tle';

  @override
  String get miuiAutostartLetKryfoRunIn => 'Pozwól Kryfo działać w tle';

  @override
  String get miuiAutostartYourPhonePausesApps =>
      'Twój telefon wstrzymuje aplikacje, żeby oszczędzać baterię. Bez wyjątku Kryfo nie odbierze wiadomości, gdy jest zamknięte.';

  @override
  String get commonAllow => 'Zezwól';

  @override
  String get commonSkip => 'Pomiń';

  @override
  String get miuiAutostartOpenSettings => 'Otwórz ustawienia';

  @override
  String get miuiAutostartCouldnTOpenIt =>
      'Nie udało się otworzyć. Poszukaj autostartu w ustawieniach telefonu';

  @override
  String get batteryGuideHuawei =>
      'Huawei i Honor same zamykają aplikacje, którymi zarządzają. Na następnym ekranie znajdź Kryfo, wyłącz Zarządzaj automatycznie i zostaw włączone Autouruchamianie, Uruchamianie pośrednie i Działanie w tle.';

  @override
  String get batteryGuideOppo =>
      'Oppo i Realme zatrzymują aplikacje w tle. Na następnym ekranie znajdź Kryfo i zezwól na Autouruchamianie. W sekcji Bateria zezwól mu też na działanie w tle.';

  @override
  String get batteryGuideVivo =>
      'Vivo zatrzymuje aplikacje w tle. Na następnym ekranie znajdź Kryfo i zezwól mu na uruchamianie w tle. W sekcji Bateria zezwól mu też na wysokie zużycie energii w tle.';

  @override
  String get batteryGuideSamsung =>
      'Samsung usypia aplikacje, które uważa za nieużywane. Na następnym ekranie otwórz Limity użycia w tle i dodaj Kryfo do Aplikacji nigdy nieusypianych.';

  @override
  String get batteryGuideOnePlus =>
      'OnePlus zatrzymuje aplikacje w tle. Na następnym ekranie znajdź Kryfo i zezwól na Autouruchamianie. W sekcji Bateria ustaw Nie optymalizuj.';

  @override
  String get batteryGuideXiaomiTitle => 'Niech Kryfo działa';

  @override
  String get batteryGuideXiaomi =>
      'Xiaomi zatrzymuje aplikacje w tle, nawet z włączonym autostartem. Żeby wiadomości dalej docierały:';

  @override
  String get batteryGuideXiaomiStep1 => 'Autostart: włącz go dla Kryfo.';

  @override
  String get batteryGuideXiaomiStep2 =>
      'Oszczędzanie baterii: ustaw dla Kryfo Bez ograniczeń.';

  @override
  String get batteryGuideXiaomiStep3 =>
      'Ostatnie aplikacje: przytrzymaj Kryfo i stuknij kłódkę, żeby Wyczyść wszystko i porządki telefonu go nie zamykały.';

  @override
  String get batteryGuideXiaomiAfter =>
      'Jeśli telefon i tak zatrzyma Kryfo, nic nie dotrze, dopóki go znów nie otworzysz.';

  @override
  String get notificationsNewEncryptedMessagesFrom =>
      'Nowe zaszyfrowane wiadomości od twoich kontaktów';

  @override
  String get notificationsNewMessage => 'Nowa wiadomość';

  @override
  String get notificationsNewEncryptedMessagesFromYourContacts =>
      'Nowe zaszyfrowane wiadomości od twoich kontaktów';

  @override
  String get notificationsNewMessage2 => 'Nowa wiadomość';

  @override
  String get notificationsSomeone => 'Ktoś';

  @override
  String get notificationsEncrypted => 'Zaszyfrowane';

  @override
  String get rooms24h => '24 godz.';

  @override
  String roomsD(Object inDays) {
    return '$inDays d';
  }

  @override
  String roomsH(Object inHours) {
    return '$inHours godz.';
  }

  @override
  String get rooms24Hours => '24 godziny';

  @override
  String roomsDays(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString dnia',
      many: '$countString dni',
      few: '$countString dni',
      one: '$countString dzień',
    );
    return '$_temp0';
  }

  @override
  String get roomsAnHour => 'godzina';

  @override
  String get roomsAboutAnHour => 'około godziny';

  @override
  String roomsHours(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString godz',
      many: '$countString godz',
      few: '$countString godz',
      one: '$countString godz',
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
      other: 'około $countString godziny',
      many: 'około $countString godzin',
      few: 'około $countString godzin',
      one: 'około $countString godziny',
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
      other: '$countString min',
      many: '$countString min',
      few: '$countString min',
      one: '$countString min',
    );
    return '$_temp0';
  }

  @override
  String get roomsAMinute => 'minuta';

  @override
  String get roomsExpired => 'Wygasł';

  @override
  String roomsDH(Object inDays, Object h) {
    return '$inDays d $h godz.';
  }

  @override
  String roomsHM(Object inHours, Object m) {
    return '$inHours godz. $m min';
  }

  @override
  String roomsM(Object inMinutes) {
    return '$inMinutes min';
  }

  @override
  String scamShieldGivesUsedName(Object shown) {
    return 'Przedstawia się jako $shown – tej nazwy używa już inna osoba';
  }

  @override
  String scamShieldWarning(Object noticed) {
    return '$noticed. Nie wysyłaj pieniędzy ani kodów osobom, których nie znasz osobiście.';
  }

  @override
  String get scamShieldAsksForSecret =>
      'Prosi o kod, PIN lub słowa odzyskiwania';

  @override
  String get scamShieldAsksForMoneyFast => 'Pilnie prosi o pieniądze';

  @override
  String get scamShieldPromisesProfit => 'Obiecuje łatwy zysk';

  @override
  String get scamShieldClaimsSupport =>
      'Podaje się za Kryfo lub zespół wsparcia';

  @override
  String get scamShieldDismiss => 'Zamknij';

  @override
  String scamShieldNameMatchesYourContact(Object shown) {
    return 'Nazwa pasuje do twojego kontaktu $shown';
  }

  @override
  String get scamShieldLinksToALookalike => 'Linkuje do podróbki znanej strony';

  @override
  String get commonBack => 'Wstecz';

  @override
  String get archivedArchived => 'Archiwum';

  @override
  String get archivedCount0 => 'Zero';

  @override
  String get archivedCount1 => 'Jeden';

  @override
  String get archivedCount2 => 'Dwa';

  @override
  String get archivedCount3 => 'Trzy';

  @override
  String get archivedCount4 => 'Cztery';

  @override
  String get archivedCount5 => 'Pięć';

  @override
  String get archivedCount6 => 'Sześć';

  @override
  String get archivedCount7 => 'Siedem';

  @override
  String get archivedCount8 => 'Osiem';

  @override
  String get archivedCount9 => 'Dziewięć';

  @override
  String get archivedCount10 => 'Dziesięć';

  @override
  String get archivedChatRestingHereIt =>
      'Odłożony czat. Będzie nieaktywny do momentu otrzymania nowej wiadomości, po czym powróci na górę.';

  @override
  String get archivedChatsRestingHere =>
      'Odłożone czaty. Będą nieaktywne do momentu otrzymania nowej wiadomości, po czym powrócą na górę.';

  @override
  String get archivedNothingArchived => 'Nic w archiwum';

  @override
  String get archivedArchivedChatsAreStill =>
      'Zarchiwizowane czaty nadal są szyfrowane end-to-end';

  @override
  String get archivedUnarchive => 'Przywróć z archiwum';

  @override
  String get avatarPickerThePeopleYouMessage =>
      'Osoby, do których piszesz, też to widzą';

  @override
  String get avatarPickerBackToYourInitial => 'Wróć do swojej litery';

  @override
  String get avatarPickerThatOneIsYours => 'Ta jest twoja';

  @override
  String get avatarPickerPickAFace => 'Wybierz twarz';

  @override
  String get commonSave => 'Zapisz';

  @override
  String get backupPassphraseMustBeAt =>
      'Hasło musi mieć co najmniej 12 znaków';

  @override
  String get backupPassphrasesDonTMatch => 'Hasła się nie zgadzają';

  @override
  String get backupBackupSavedKeepThe => 'Kopia zapisana · chroń hasło';

  @override
  String get backupKryfoBackup => 'Kopia zapasowa Kryfo';

  @override
  String get backupYourEncryptedKryfoBackup =>
      'Twoja zaszyfrowana kopia zapasowa Kryfo. Chroń ten plik i hasło. Do przywrócenia potrzebujesz obu.';

  @override
  String get backupBackUpKryfo => 'Kopia zapasowa Kryfo';

  @override
  String get backupBackUp => 'Utwórz kopię';

  @override
  String get backupACopyToKeep =>
      'Kopia na przechowanie. Ten telefon działa dalej jak dotąd.';

  @override
  String get backupACopyToKeepDesk =>
      'Kopia na przechowanie. Ten komputer działa dalej jak dotąd.';

  @override
  String get backupMoveToAnotherDevice => 'Przenieś na inne urządzenie';

  @override
  String get backupTheFileTakesThis =>
      'Plik zabiera tę tożsamość ze sobą. Gdy zostanie utworzony, ten telefon przestaje działać: nic nowego tu nie dotrze, a nic wysłanego stąd nie dotrze do nikogo.';

  @override
  String get backupTheFileTakesThisDesk =>
      'Plik zabiera tę tożsamość ze sobą. Gdy zostanie utworzony, ten komputer przestaje działać: nic nowego tu nie dotrze, a nic wysłanego stąd nie dotrze do nikogo.';

  @override
  String get backupOneEncryptedFileYour =>
      'Jeden zaszyfrowany plik: twoja tożsamość, kontakty, każda wiadomość i każde zdjęcie, wiadomość głosowa i plik. Zaimportuj go na drugim urządzeniu z hasłem. Dopóki tego nie zrobisz, możesz zmienić zdanie i zostać na tym telefonie.';

  @override
  String get backupOneEncryptedFileYourIdentityYour =>
      'Jeden zaszyfrowany plik: twoja tożsamość, kontakty, każda wiadomość i każde zdjęcie, wiadomość głosowa i plik, które są teraz na tym telefonie. To, co powiesz po dzisiejszym dniu, w nim nie będzie, więc gdy to ważne, zrób kolejną. Do przywrócenia potrzebujesz pliku i hasła, obu.';

  @override
  String get backupOneEncryptedFileYourIdentityYourDesk =>
      'Jeden zaszyfrowany plik: twoja tożsamość, kontakty, każda wiadomość i każde zdjęcie, wiadomość głosowa i plik, które są teraz na tym komputerze. To, co powiesz po dzisiejszym dniu, w nim nie będzie, więc gdy to ważne, zrób kolejną. Do przywrócenia potrzebujesz pliku i hasła, obu.';

  @override
  String get backupPassphrase => 'Hasło';

  @override
  String get backupConfirmPassphrase => 'Potwierdź hasło';

  @override
  String backupWriting(Object progress) {
    return 'Zapisywanie… $progress';
  }

  @override
  String get backupSaveComesAfter =>
      'Gdy będzie gotowe, wybierzesz, gdzie to zapisać.';

  @override
  String get backupSaving => 'Zapisywanie…';

  @override
  String backupSavedIn(String place) {
    return 'Kopia zapasowa zapisana w $place · chroń hasło';
  }

  @override
  String get backupNotSaved =>
      'Kopia zapasowa nie została zapisana. Plik nadal tu jest.';

  @override
  String get backupNotSavedNoSpace =>
      'W wybranym miejscu zabrakło miejsca. Plik nadal tu jest, więc wybierz inne miejsce albo zwolnij trochę pamięci.';

  @override
  String get backupShareInstead => 'Udostępnij zamiast tego';

  @override
  String get backupSavedUnchecked =>
      'Kopia zapasowa zapisana, ale Kryfo nie mogło sprawdzić pliku';

  @override
  String get backupHandedOver =>
      'Kopia zapasowa przekazana do wybranej aplikacji · sprawdź, czy dotarła';

  @override
  String get backupMoveReachedTitle => 'Czy plik dotarł na nowy telefon?';

  @override
  String get backupMoveReachedTitleDesk =>
      'Czy plik dotarł na nowe urządzenie?';

  @override
  String get backupMoveReachedLine =>
      'Zatrzymaj ten telefon, dopóki nie otworzysz tam pliku.';

  @override
  String get backupMoveReachedLineDesk =>
      'Zatrzymaj ten komputer, dopóki nie otworzysz tam pliku.';

  @override
  String get backupFinishTheMove => 'Dokończ przenosiny';

  @override
  String get backupNotYet => 'Jeszcze nie';

  @override
  String get backupCreating => 'Tworzenie…';

  @override
  String get backupMakeTheFileAnd => 'Utwórz plik i przenieś';

  @override
  String get backupCreateBackup => 'Utwórz kopię zapasową';

  @override
  String get backupNotMade => 'Nie udało się utworzyć kopii. Spróbuj ponownie.';

  @override
  String get backupNoSpace =>
      'Na tym telefonie brakuje wolnego miejsca na kopię zapasową. Zwolnij trochę pamięci i spróbuj ponownie.';

  @override
  String get backupNoSpaceDesk =>
      'Na tym komputerze brakuje wolnego miejsca na kopię zapasową. Zwolnij trochę miejsca i spróbuj ponownie.';

  @override
  String get backupHiddenNotIn => 'Brak ukrytych czatów w tym miejscu.';

  @override
  String get backupHiddenIncluded => 'Twoje ukryte czaty też w niej są.';

  @override
  String get backupMoveHiddenStay =>
      'Ukryte czaty zostają na tym telefonie i znikną razem z nim.';

  @override
  String get backupMoveHiddenStayDesk =>
      'Ukryte czaty zostają na tym komputerze i znikną razem z nim.';

  @override
  String get backupHiddenGone =>
      'Twoje ukryte czaty zamknęły się, gdy Kryfo zostało zablokowane. Otwórz je ich PIN-em i zrób kopię stamtąd.';

  @override
  String get blockedBlocked => 'Zablokowani';

  @override
  String get blockedNoOneIsBlocked => 'Nikt nie jest zablokowany';

  @override
  String get commonUnblock => 'Odblokuj';

  @override
  String get bridgesConnected => 'Połączono';

  @override
  String get bridgesFromTheTorProject => 'Od Tor Project';

  @override
  String get bridgesPasteFromClipboard => 'Wklej ze schowka';

  @override
  String bridges1LineSaved(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Zapisano $countString linii',
      many: 'Zapisano $countString linii',
      few: 'Zapisano $countString linie',
      one: 'Zapisano $countString linię',
    );
    return '$_temp0';
  }

  @override
  String get bridgesWhenYouAskFor =>
      'Gdy prosisz o mostki, Tor Project widzi twój adres. To normalne: tak Tor Browser i każda aplikacja Tor dostają mostki, a jedyne, czego się dowiadują, to że poproszono o mostki. Nic o twoich czatach.';

  @override
  String get cameraNoCameraOnThis => 'Ten telefon nie ma aparatu';

  @override
  String get cameraCameraNotAvailable => 'Aparat niedostępny';

  @override
  String get cameraCameraPermissionIsOff => 'Brak uprawnienia do aparatu';

  @override
  String get cameraOpenSettings => 'Otwórz ustawienia';

  @override
  String get cameraCouldNotStripThat =>
      'Nie udało się wyczyścić tego zdjęcia, odrzucono je';

  @override
  String get cameraNoPhotoCameOut => 'Zdjęcie się nie zrobiło';

  @override
  String get cameraCouldNotStartRecording => 'Nie udało się zacząć nagrywania';

  @override
  String get cameraTheRecordingWasLost => 'Nagranie przepadło';

  @override
  String get cameraACopyIsIn => 'Kopia jest w twoich zdjęciach';

  @override
  String get cameraCouldNotSaveA =>
      'Nie udało się zapisać kopii na tym telefonie';

  @override
  String get cameraTooLongForA => 'Za długie na wiadomość · maks. 50 MB';

  @override
  String get cameraNeverSavedToYour => 'Nigdy nie zapisano w Zdjęciach';

  @override
  String get cameraNoExifNeverSaved =>
      'Bez EXIF, nigdy nie trafia do twoich zdjęć';

  @override
  String get cameraRec => 'Nagr.';

  @override
  String get cameraSwitchCamera => 'Zmień aparat';

  @override
  String get cameraStopRecording => 'Zatrzymaj nagrywanie';

  @override
  String get cameraStartRecording => 'Zacznij nagrywanie';

  @override
  String get cameraTakeAPhoto => 'Zrób zdjęcie';

  @override
  String get cameraKeepACopy => 'Zachowaj kopię';

  @override
  String get cameraUseThis => 'Użyj tego';

  @override
  String get chatYouAreOfflineThis =>
      'Jesteś offline · zostanie wysłane po połączeniu';

  @override
  String get chatStillConnectingToTor =>
      'Łączenie z siecią Tor · wyśle się automatycznie';

  @override
  String chatS(Object seconds) {
    return '$seconds s';
  }

  @override
  String chatM(Object seconds) {
    return '$seconds min';
  }

  @override
  String chatH(Object seconds) {
    return '$seconds godz.';
  }

  @override
  String chatD(Object seconds) {
    return '$seconds d';
  }

  @override
  String get chat0s => '0 s';

  @override
  String chatHM(Object h, Object m) {
    return '$h godz. $m min';
  }

  @override
  String chatMS(Object m, Object s) {
    return '$m min $s s';
  }

  @override
  String chatS2(Object s) {
    return '$s s';
  }

  @override
  String get chatNewMessages => 'Nowe wiadomości';

  @override
  String chatEarlierMessagesArrived(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Dotarło $countString wcześniejszej wiadomości',
      many: 'Dotarło $countString wcześniejszych wiadomości',
      few: 'Dotarły $countString wcześniejsze wiadomości',
      one: 'Dotarła $countString wcześniejsza wiadomość',
    );
    return '$_temp0';
  }

  @override
  String get chatUnsave => 'Usuń z zapisanych';

  @override
  String get chatForward => 'Przekaż dalej';

  @override
  String get commonShare => 'Udostępnij';

  @override
  String get commonCopied => 'Skopiowano';

  @override
  String get commonCopy => 'Kopiuj';

  @override
  String get chatUnpin => 'Odepnij';

  @override
  String get chatPin => 'Przypnij';

  @override
  String get chatStopSending => 'Przestań wysyłać';

  @override
  String get chatUnsend => 'Cofnij wysłanie';

  @override
  String get commonEdit => 'Edytuj';

  @override
  String get chatYou => 'Ty';

  @override
  String get chatUnsendMessage => 'Cofnij wysłanie wiadomości';

  @override
  String get chatItDisappearsWithNo =>
      'Zostanie usunięta z obu telefonów, chyba że już ją zapisano. Tego nie da się cofnąć.';

  @override
  String get chatItDisappearsWithNoDesk =>
      'Zostanie usunięta z obu urządzeń, chyba że już ją zapisano. Tego nie da się cofnąć.';

  @override
  String chatThisChatHasPins(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ten czat ma już $countString przypiętej',
      many: 'Ten czat ma już $countString przypiętych',
      few: 'Ten czat ma już $countString przypięte',
      one: 'Ten czat ma już $countString przypiętą',
    );
    return '$_temp0';
  }

  @override
  String get chatUnpinThisMessage => 'Odpiąć tę wiadomość?';

  @override
  String get chatPinThisMessage => 'Przypiąć tę wiadomość?';

  @override
  String get chatItLeavesThePinned => 'Zniknie z przypiętych dla was obojga.';

  @override
  String get chatItGoesUnderThe =>
      'Trafi pod przypięte u góry czatu, dla was obojga.';

  @override
  String get chatPinIt => 'Przypnij';

  @override
  String get chatNotNow => 'Nie teraz';

  @override
  String get chatEditMessage => 'Edytuj wiadomość';

  @override
  String get chat30Seconds => '30 sekund';

  @override
  String get chat1Minute => '1 minuta';

  @override
  String get chat5Minutes => '5 minut';

  @override
  String get chat1Hour => '1 godzina';

  @override
  String get chat24Hours => '24 godziny';

  @override
  String get chatGhostTimer => 'Wiadomości czasowe';

  @override
  String get chatHowLongAfterReading =>
      'Po jakim czasie od przeczytania, wiadomości mają znikać? Czas twoich wiadomości liczony jest od momentu ich wysłania.';

  @override
  String get chatCamera => 'Aparat';

  @override
  String get chatNoExifNeverSaved =>
      'Bez exif, nigdy nie trafia do twoich zdjęć';

  @override
  String get chatGallery => 'Galeria';

  @override
  String get chatVideo => 'Wideo';

  @override
  String get chatGifFromPhone => 'GIF z telefonu';

  @override
  String get chatGifFromPhoneDesk => 'GIF z komputera';

  @override
  String get chatFile2 => 'Plik';

  @override
  String get chatAFewSeconds => 'Kilka sekund';

  @override
  String get chatUnderAMinute => 'Mniej niż minuta';

  @override
  String chatRoughlyMin(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Około $countString min',
      many: 'Około $countString min',
      few: 'Około $countString min',
      one: 'Około $countString min',
    );
    return '$_temp0';
  }

  @override
  String chatB2(Object b) {
    return '$b B';
  }

  @override
  String chatKb2(Object b) {
    return '$b kB';
  }

  @override
  String chatMb2(Object b) {
    return '$b MB';
  }

  @override
  String get chatSendThis => 'Wysłać ten plik?';

  @override
  String chatOverTor(Object humanBytes, Object wireEstimate) {
    return '$humanBytes · $wireEstimate przez Tor';
  }

  @override
  String get chatBigFilesGoOut =>
      'Duże pliki idą w małych zaszyfrowanych kawałkach, więc to trochę trwa. Nie zamykaj aplikacji, a wysyłanie będzie trwać.';

  @override
  String get chatSendIt => 'Wyślij';

  @override
  String get chatCouldNotReadThat => 'Nie udało się odczytać tego pliku';

  @override
  String get chatCouldNotCleanThat => 'Nie udało się wyczyścić tego wideo';

  @override
  String get chatGifTooBig8 => 'GIF za duży · maks. 8 MB';

  @override
  String get chatCouldNotCleanThatGif => 'Nie udało się wyczyścić tego GIF-a';

  @override
  String get chatTorIsNotUp => 'Tor jeszcze nie połączony · bez podglądu linku';

  @override
  String get chatCouldnTReachIt =>
      'Nie udało się połączyć ze stroną · bez podglądu linku';

  @override
  String get chatNoTitleCameBack =>
      'Ta strona nie ma tytułu · bez podglądu linku';

  @override
  String get chatCouldnTFetchIt => 'Nie udało się wczytać podglądu';

  @override
  String get chatNoSignalSessionRe => 'Brak sesji Signal: sparuj ponownie';

  @override
  String get chatMessageUnavailable => 'Wiadomość niedostępna';

  @override
  String get chatYou2 => 'Ty';

  @override
  String get chatThem => 'Ta osoba';

  @override
  String get chatVoiceMessage => 'Wiadomość głosowa';

  @override
  String get chatQuotedPhoto => 'Zdjęcie';

  @override
  String get chatViewContact => 'Zobacz kontakt';

  @override
  String get chatUnmuteNotifications => 'Włącz powiadomienia';

  @override
  String get chatMuteNotifications => 'Wycisz powiadomienia';

  @override
  String get chatArchiveChat => 'Archiwizuj czat';

  @override
  String get chatWallpaper => 'Tapeta';

  @override
  String get chatClearConversation => 'Wyczyść rozmowę';

  @override
  String get chatNoteOnThisContact => 'Notatka o tym kontakcie';

  @override
  String get chatPinToTop => 'Przypnij na górze';

  @override
  String get chatBlockContact => 'Zablokuj kontakt';

  @override
  String get chatUnpinned => 'Odpięto';

  @override
  String get chatPinnedToTop => 'Przypięto na górze';

  @override
  String get chatJustForYouNever =>
      'Tylko dla ciebie. Nigdy nie wysyłana, nie opuszcza tego telefonu.';

  @override
  String get chatJustForYouNeverDesk =>
      'Tylko dla ciebie. Nigdy nie wysyłana, nie opuszcza tego komputera.';

  @override
  String get chatAQuietReminder => 'Ciche przypomnienie…';

  @override
  String get chatNoteSaved => 'Notatka zapisana';

  @override
  String get chatClearThisConversation => 'Wyczyścić tę rozmowę?';

  @override
  String get chatEveryMessageHereIs =>
      'Każda wiadomość stąd zostanie usunięta z tego telefonu. To czyści tylko twoją kopię. Nie dotyka urządzenia drugiej osoby.';

  @override
  String get chatEveryMessageHereIsDesk =>
      'Każda wiadomość stąd zostanie usunięta z tego komputera. To czyści tylko twoją kopię. Nie dotyka urządzenia drugiej osoby.';

  @override
  String get chatClear => 'Wyczyść';

  @override
  String get chatBlockThisContact => 'Zablokować ten kontakt?';

  @override
  String get chatTheirMessagesStopArriving =>
      'Wiadomości od tej osoby przestaną docierać, a czat zniknie z listy. Ta osoba nigdy się o tym nie dowie. Odblokować możesz w każdej chwili w ustawieniach.';

  @override
  String get commonBlock => 'Zablokuj';

  @override
  String get chatSaved => 'Zapisano';

  @override
  String get chatRemovedFromSaved => 'Usunięto z zapisanych';

  @override
  String get chatForwardTo => 'Przekaż do';

  @override
  String get chatNoContactsToForward =>
      'Brak kontaktów, do których można przekazać';

  @override
  String get chatToday => 'Dzisiaj';

  @override
  String get chatYesterday => 'Wczoraj';

  @override
  String get chatThisMessageCanT => 'Tej wiadomości nie da się wyświetlić';

  @override
  String get chatJumpToTheNewest => 'Przejdź do najnowszych';

  @override
  String get chatBuildingAPrivateRoute =>
      'Buduję prywatną trasę · pierwsze połączenie trwa najdłużej, kolejne są szybkie. Wszystko, co teraz wyślesz, czeka w kolejce i zostanie wysłane automatycznie.';

  @override
  String get chatTheNextPhotoYou =>
      'Następne wysłane zdjęcie otworzy się chronione · Kryfo blokuje jego zrzuty ekranu';

  @override
  String get chatPhotoProtectionOff => 'Ochrona zdjęć wyłączona';

  @override
  String get chatAcceptToReplyThey =>
      'Zaakceptuj, żeby odpowiedzieć. Do tego czasu ta osoba może wysłać jeszcze jedną wiadomość.';

  @override
  String chatIntroducedYouAcceptTo(Object introducer) {
    return '$introducer was przedstawia. Zaakceptuj, żeby odpowiedzieć.';
  }

  @override
  String chatIntroducedYouSayHello(Object vouchNames) {
    return '$vouchNames was przedstawia. Przywitaj się. Ta osoba też dostała twoją wizytówkę.';
  }

  @override
  String get chatIntroduceTo => 'Przedstaw…';

  @override
  String get chatAcceptThemFirst => 'Najpierw zaakceptuj';

  @override
  String get chatMessageRequest => 'Prośba o rozmowę';

  @override
  String get chatTheyNeedToAccept =>
      'Ta osoba musi zaakceptować, zanim będzie można pisać dalej.';

  @override
  String get chatWaitingForThemTo =>
      'Oczekiwanie, aż ta osoba zaakceptuje twoją prośbę';

  @override
  String get chatWaitsToSend => 'Czeka na wysłanie';

  @override
  String get chatTheyMayNotKnow =>
      'Ta osoba może nie wiedzieć, że ją zaakceptowano';

  @override
  String get chatYouBlockedThisContact => 'Zablokowano ten kontakt';

  @override
  String get chatSupporter => 'Wspierający';

  @override
  String get chatEncryptedDirect => 'Szyfrowane · bezpośrednio';

  @override
  String get chatEncryptedOverTor => 'Szyfrowane · przez Tor';

  @override
  String get chatSearchThisChat => 'Szukaj w tym czacie';

  @override
  String get chatContactOptions => 'Opcje kontaktu';

  @override
  String get commonClose => 'Zamknij';

  @override
  String get chatFindInConversation => 'Znajdź w rozmowie';

  @override
  String get chatNoMatches => 'Brak wyników';

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
      other: '*$posString* z $countString wyniku',
      many: '*$posString* z $countString wyników',
      few: '*$posString* z $countString wyników',
      one: '*$posString* z $countString wyniku',
    );
    return '$_temp0';
  }

  @override
  String get chatPreviousMatch => 'Poprzedni wynik';

  @override
  String get chatNextMatch => 'Następny wynik';

  @override
  String get chatPhotoUnavailable => 'Zdjęcie niedostępne';

  @override
  String get chatDelivered => 'Dostarczono';

  @override
  String get chatEdited => 'Edytowano';

  @override
  String get chatFailedTapToRetry => 'Nie wysłano · stuknij, by ponowić';

  @override
  String get chatReplyingTo => 'Odpowiadasz tej osobie';

  @override
  String get chatReplyingToYourself => 'Odpowiadasz sobie';

  @override
  String get chatReply => 'Odpowiedz';

  @override
  String get chatSayHi => 'Przywitaj się.';

  @override
  String get chatJustTheTwoOf => 'Tylko wy dwoje, szyfrowane end-to-end.';

  @override
  String get chatSayHiSoThey => 'Przywitaj się, żeby cię zobaczono';

  @override
  String get chatTheyWonTKnow =>
      'Ta osoba nie dowie się, że ją dodano, dopóki nie dotrze twoja pierwsza wiadomość.';

  @override
  String get chatWave => 'Pomachaj';

  @override
  String get chatMicPermissionNeeded => 'Potrzebne uprawnienie do mikrofonu';

  @override
  String get chatTheMicWouldNot => 'Mikrofon nie włączył się. Spróbuj ponownie';

  @override
  String get chatReleaseToCancel => 'Puść, żeby anulować';

  @override
  String get chatVoiceHiddenSlideTo => 'Głos ukryty · przesuń, żeby anulować';

  @override
  String get chatSlideToCancel => 'Przesuń, żeby anulować';

  @override
  String get chatGhostMode => 'Wiadomości czasowe';

  @override
  String chatMessagesBurnAfter(Object humanBurn) {
    return 'płoną po $humanBurn';
  }

  @override
  String get chatTimedMessages => 'Wiadomości czasowe';

  @override
  String get chatOpenTheCamera => 'Otwórz aparat';

  @override
  String get chatAttachAPhoto => 'Dołącz zdjęcie';

  @override
  String get chatMessage => 'Wiadomość';

  @override
  String get commonSend => 'Wyślij';

  @override
  String get chatHoldToRecord => 'Przytrzymaj, żeby nagrać wiadomość głosową';

  @override
  String get chatSecurityCodeChanged => 'Kod bezpieczeństwa się zmienił';

  @override
  String get chatCompareTitle => 'Porównaj numer bezpieczeństwa';

  @override
  String chatCompareLine(Object peerName) {
    return 'Trzy słowa można skopiować. Żeby wiedzieć, że ten czat naprawdę jest z $peerName, porównajcie numer bezpieczeństwa, osobiście albo w rozmowie.';
  }

  @override
  String get chatCompareLater => 'Później';

  @override
  String get chatCompareNow => 'Porównaj';

  @override
  String chatKeyHeldLine(Object peerName) {
    return 'Wcześniej zweryfikowano $peerName. Nic nie zostanie wysłane, dopóki nie sprawdzisz nowego numeru albo nie zaakceptujesz nowego klucza. Wiadomości od tej osoby nadal docierają.';
  }

  @override
  String get chatCheckTheNumber => 'Sprawdź numer';

  @override
  String get chatAcceptNewKey => 'Zaakceptuj nowy klucz';

  @override
  String get chatAcceptNewKeyTitle => 'Zaakceptować nowy klucz?';

  @override
  String chatAcceptNewKeyLine(Object peerName) {
    return 'Kryfo będzie wtedy wysyłać na nowy klucz bez sprawdzenia, a $peerName nie będzie już oznaczony jako zweryfikowany. Możesz zweryfikować ponownie w każdej chwili.';
  }

  @override
  String chatMayHaveReinstalledOr(Object peerName) {
    return 'Możliwe, że aplikację zainstalowano ponownie albo ktoś podszywa się pod $peerName. Porównajcie numery bezpieczeństwa, żeby mieć pewność.';
  }

  @override
  String get chatOk => 'OK';

  @override
  String get chatVerify => 'Zweryfikuj';

  @override
  String get cleanKryfoCanTClean =>
      'Kryfo nie umie jeszcze czyścić takich plików.';

  @override
  String get cleanThisIsAMotion => 'To jest zdjęcie ruchome.';

  @override
  String get cleanThisPictureIsToo =>
      'To zdjęcie jest za duże, żeby wyczyścić je tutaj.';

  @override
  String get cleanThisFileIsDamaged => 'Ten plik jest uszkodzony albo ucięty.';

  @override
  String get cleanKryfoCouldNotMake =>
      'Kryfo nie dało rady wyczyścić tego pliku.';

  @override
  String get cleanNotEnoughRoomOn => 'Za mało miejsca na telefonie.';

  @override
  String get cleanNotEnoughRoomOnDesk => 'Za mało miejsca na komputerze.';

  @override
  String get cleanKryfoCouldNotOpen => 'Kryfo nie mogło otworzyć tego pliku.';

  @override
  String get cleanItCleansJpegPng =>
      'Czyści JPEG, PNG, WebP, HEIC, AVIF, GIF, MP4 i MOV. Nic nie zostało zmienione.';

  @override
  String get cleanItHoldsAShort =>
      'Zawiera krótkie wideo obok zdjęcia, a tej części Kryfo nie umie jeszcze wyczyścić. Wyłącz ruch w aparacie albo wyślij zrzut ekranu.';

  @override
  String get cleanPicturesOver64Mb =>
      'Zdjęcia powyżej 64 MB nie są czyszczone na telefonie. Nic nie zostało zmienione.';

  @override
  String get cleanPicturesOver64MbDesk =>
      'Zdjęcia powyżej 64 MB nie są czyszczone na komputerze. Nic nie zostało zmienione.';

  @override
  String get cleanKryfoCouldNotRead =>
      'Kryfo nie mogło odczytać go do końca, więc nie nazwie go czystym. Nie powstała żadna kopia.';

  @override
  String get cleanSomethingInsideIsOf =>
      'W środku jest coś, czego nie można usunąć, więc nie powstała żadna kopia.';

  @override
  String get cleanFreeSomeSpaceAnd =>
      'Zwolnij trochę miejsca i spróbuj ponownie. Nic nie zostało zmienione.';

  @override
  String get cleanTheAppThatShared =>
      'Aplikacja, która to udostępniła, mogła to cofnąć. Spróbuj udostępnić ponownie.';

  @override
  String get cleanTheAppThatSharedDesk =>
      'Mógł zostać przeniesiony albo inna aplikacja trzyma go otwartego. Spróbuj wybrać go ponownie.';

  @override
  String get cleanNoAppOnThis =>
      'Żadna aplikacja na tym telefonie nie przyjęła pliku.';

  @override
  String get cleanCouldNotSaveIt =>
      'Nie udało się zapisać. Sprawdź, czy telefon ma miejsce.';

  @override
  String get cleanCouldNotSaveItDesk =>
      'Nie udało się zapisać. Sprawdź, czy komputer ma miejsce.';

  @override
  String get cleanTheOriginalIsGone =>
      'Oryginał został usunięty. Czysta kopia zostaje.';

  @override
  String get cleanAndroidWouldNotDelete =>
      'Android nie pozwolił go usunąć. Usuń go z galerii ręcznie.';

  @override
  String get cleanCleanCopy => 'Czysta kopia';

  @override
  String get cleanShareCleanCopy => 'Udostępnij czystą kopię';

  @override
  String get cleanSaveToGallery => 'Zapisz w galerii';

  @override
  String get cleanSaveToGalleryDesk => 'Zapisz czystą kopię';

  @override
  String get commonStop => 'Zatrzymaj';

  @override
  String get cleanReadingTheFile => 'Czytam plik';

  @override
  String get cleanCleaning => 'Czyszczę';

  @override
  String cleanOf(Object prettySize, Object prettySize2) {
    return '$prettySize z $prettySize2';
  }

  @override
  String get cleanEverythingStaysOnThis => 'Wszystko zostaje na tym telefonie.';

  @override
  String get cleanEverythingStaysOnThisDesk =>
      'Wszystko zostaje na tym komputerze.';

  @override
  String get cleanAlreadyClean => 'Już czyste.';

  @override
  String get cleanClean => 'Czyste.';

  @override
  String get cleanThereWasNothingTo => 'Nie było czego szukać.';

  @override
  String get cleanNothingLeftToFind => 'Nic już nie zostało.';

  @override
  String get cleanSameVideoSameQuality => 'To samo wideo, ta sama jakość';

  @override
  String get cleanSamePictureSameQuality => 'To samo zdjęcie, ta sama jakość';

  @override
  String get cleanSamePicture => 'Ten sam obraz';

  @override
  String cleanRemoved(Object label) {
    return '$label, usunięto';
  }

  @override
  String get cleanRemoved2 => 'USUNIĘTO';

  @override
  String get cleanWithTheLocationInside =>
      'z lokalizacją w środku. Kto je dostanie, zna twoją ulicę.';

  @override
  String get cleanWithEverythingItKnew =>
      'ze wszystkim, co wiedziało, nadal w środku.';

  @override
  String get cleanOriginal => 'ORYGINAŁ';

  @override
  String get cleanClean2 => 'CZYSTE';

  @override
  String get cleanSavedToYourGallery => 'Zapisano w galerii.';

  @override
  String get cleanSavedToYourGalleryDesk => 'Zapisano tam, gdzie wybrano.';

  @override
  String cleanTheOriginalIsStill(Object what) {
    return 'Oryginał jest tam nadal, $what';
  }

  @override
  String cleanTheOriginalIsStillWhereIt(Object what) {
    return 'Oryginał nadal jest tam, gdzie był, $what Kryfo nie może go stąd usunąć, więc usuń go w aplikacji, z której pochodzi.';
  }

  @override
  String get cleanDeleteTheOriginal => 'Usuń oryginał';

  @override
  String get cleanKeepBoth => 'Zachowaj oba';

  @override
  String get commonDone => 'Gotowe';

  @override
  String get cleanAndroidWillAskYou => 'ANDROID ZAPYTA CIĘ O POTWIERDZENIE';

  @override
  String get contactYourNameForThem => 'Twój pseudonim dla tej osoby';

  @override
  String get contactStaysOnThisPhone =>
      'Zostaje na tym telefonie. Ta osoba nigdy go nie zobaczy.';

  @override
  String get contactStaysOnThisPhoneDesk =>
      'Zostaje na tym komputerze. Ta osoba nigdy go nie zobaczy.';

  @override
  String get contactClear => 'Wyczyść';

  @override
  String get contactMessage => 'Napisz';

  @override
  String get contactKeysVerified => 'Klucze zweryfikowane';

  @override
  String get contactVerifyKeys => 'Zweryfikuj klucze';

  @override
  String get contactVouches => 'Polecenia';

  @override
  String get contactUnmute => 'Wyłącz wyciszenie';

  @override
  String get contactMute => 'Wycisz';

  @override
  String get contactUnpin => 'Odepnij';

  @override
  String get contactPinToTop => 'Przypnij na górze';

  @override
  String get contactArchive => 'Archiwizuj';

  @override
  String get contactOutOfTheList => 'Poza listą, dopóki znów nie napisze';

  @override
  String contactBlock(Object name) {
    return 'Zablokować $name?';
  }

  @override
  String get contactTheirMessagesStopArriving =>
      'Wiadomości od tej osoby przestają docierać. Nie jest o tym informowana.';

  @override
  String get contactDeleteChat => 'Usuń czat';

  @override
  String get contactMessagesAndContactGone =>
      'Wiadomości i kontakt znikną z tego telefonu';

  @override
  String get contactMessagesAndContactGoneDesk =>
      'Wiadomości i kontakt znikną z tego komputera';

  @override
  String get contactDeleteThisChat => 'Usunąć ten czat?';

  @override
  String get contactEveryMessageAndThe =>
      'Każda wiadomość i kontakt znikną z tego telefonu. Nic nie zostanie wysłane do tej osoby.';

  @override
  String get contactEveryMessageAndTheDesk =>
      'Każda wiadomość i kontakt znikną z tego komputera. Nic nie zostanie wysłane do tej osoby.';

  @override
  String get commonDelete => 'Usuń';

  @override
  String get contactDeleted => 'Usunięto';

  @override
  String get contactToday => 'Dzisiaj';

  @override
  String contactD(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count d',
      many: '$count d',
      few: '$count d',
      one: '$count d',
    );
    return '$_temp0';
  }

  @override
  String contactMo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mies.',
      many: '$count mies.',
      few: '$count mies.',
      one: '$count mies.',
    );
    return '$_temp0';
  }

  @override
  String contactY(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count r.',
      many: '$count l.',
      few: '$count l.',
      one: '$count r.',
    );
    return '$_temp0';
  }

  @override
  String get contactVerified => 'Zweryfikowano';

  @override
  String get contactChatting => 'Rozmawiacie';

  @override
  String get contactNothingSharedYet => 'Nic jeszcze nie udostępniono';

  @override
  String contactSharedMedia(Object count) {
    return 'Udostępnione multimedia · $count';
  }

  @override
  String get donateBitcoin => 'Bitcoin';

  @override
  String get donateText => '₿';

  @override
  String get donateBadgeUnlocks => 'Odblokowuje odznakę';

  @override
  String get donateMonero => 'Monero';

  @override
  String get donateManualNoBadge => 'Ręcznie · bez odznaki';

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
          'Twoja wcześniejsza płatność w bitcoinach została zauważona · odznaka wspierającego odblokowana',
      'patron':
          'Twoja wcześniejsza płatność w bitcoinach została zauważona · odznaka mecenasa odblokowana',
      'guardian':
          'Twoja wcześniejsza płatność w bitcoinach została zauważona · odznaka strażnika odblokowana',
      'other':
          'Twoja wcześniejsza płatność w bitcoinach została zauważona · odznaka wspierającego odblokowana',
    });
    return '$_temp0';
  }

  @override
  String get donateSupport => 'Wesprzyj';

  @override
  String get donateKeepKryfo => 'Niech Kryfo pozostanie *niezależne*';

  @override
  String get donateNoAdsNoInvestors =>
      'Bez reklam, bez inwestorów, nic na sprzedaż. Działa dzięki temu, co dają wspierający.';

  @override
  String get donateBackItAnonymouslyBadge =>
      'Wspieraj anonimowo. Odznaka tylko, jeśli chcesz.\n*Każda funkcja prywatności jest darmowa.*';

  @override
  String get donateAuditTitle => 'Pomóż sfinansować audyt bezpieczeństwa';

  @override
  String get donateAuditLine =>
      'Darowizny tutaj idą na niezależny audyt. Pełny raport będzie publiczny.';

  @override
  String get donateCard => 'Karta';

  @override
  String get donateCardOneTime =>
      'Jednorazowa darowizna w przeglądarce. Kwotę wybierasz ty.';

  @override
  String get donateCardMarios =>
      'Płatności kartą trafiają bezpośrednio do Mariosa, dopóki nie powstanie nasz opiekun fiskalny.';

  @override
  String get donateCardSeesName =>
      'Firma płatnicza widzi twoje imię i nazwisko. Kryptowaluty to prywatna droga.';

  @override
  String get donateCardPay => 'Zapłać kartą';

  @override
  String get donateNoBitcoinCard => 'Bez bitcoina? Zapłać kartą';

  @override
  String get donateCardNoBadge => 'Darowizny kartą nie odblokowują odznaki.';

  @override
  String donateAddressCheckItAgainst(Object coinName) {
    return 'Adres $coinName · sprawdź go w swoim portfelu';
  }

  @override
  String get donateAddressCopiedClearsIn =>
      'Adres skopiowany · zniknie ze schowka za 60 s';

  @override
  String get donateCopyAddress => 'Kopiuj adres';

  @override
  String get donateBitcoinIsVerifiedBy =>
      'Bitcoina sprawdza nasz własny węzeł, więc odznaka odblokuje się sama, gdy płatność dotrze.';

  @override
  String get donateWeCanTVerify =>
      'Nie możemy sprawdzić tego łańcucha bez pytania zewnętrznej usługi o ciebie, więc tego nie robimy. Wyślij, jeśli chcesz. Nie odblokuje to odznaki.';

  @override
  String get donateBitcoinBadgesNeedOnion =>
      'Odznaki za bitcoina wymagają trybu onion';

  @override
  String get donateSwitchToOnion => 'Przełącz na onion';

  @override
  String get donatePayWithBitcoin => 'Zapłać bitcoinem  →';

  @override
  String get donateBadgesStartAt20 => 'Odznaki od 20 \$';

  @override
  String get donateShowTheAddress => 'Pokaż adres';

  @override
  String donateReviewAmount(String amount) {
    return '$amount w bitcoinach';
  }

  @override
  String get donateWhatTheBadgeGives => 'Co daje odznaka';

  @override
  String get donateGivesMark =>
      'Znak przy twoim imieniu. Ty wybierasz, kto go widzi, jeśli w ogóle ktoś.';

  @override
  String get donateGivesReceipt =>
      'Podpisane potwierdzenie zapisane na tym telefonie. Potwierdza odznakę bez żadnego konta.';

  @override
  String get donateGivesReceiptDesk =>
      'Podpisane potwierdzenie zapisane na tym komputerze. Potwierdza odznakę bez żadnego konta.';

  @override
  String get donateGivesFree =>
      'Każda funkcja prywatności zostaje darmowa, z odznaką czy bez.';

  @override
  String get donateAddressOnTap =>
      'Adres powstaje, gdy stukniesz poniżej. Zostaje twój przez godzinę, więc po powrocie dostaniesz ten sam.';

  @override
  String get donateBitcoinBusy =>
      'Bitcoin jest teraz przeciążony. Spróbuj później albo zapłać kartą.';

  @override
  String get donateBusyPlainAddress =>
      'Nadal możesz wysłać bitcoiny na adres poniżej. Nie daje to odznaki.';

  @override
  String get donateSameAddressAgain =>
      'To ten sam adres, który był otwarty wcześniej. Jeśli płatność została już wysłana, zaczekaj tutaj.';

  @override
  String get donateReachingThePaymentService =>
      'Łączę z usługą płatności przez Tor…';

  @override
  String get donateThisCanTakeUp => 'To może potrwać minutę lub dwie';

  @override
  String donateSThisCanTake(Object waited) {
    return '$waited s · to może potrwać minutę lub dwie';
  }

  @override
  String get donateUseTheAddressInstead => 'Użyj adresu zamiast tego';

  @override
  String get donateThePaymentServiceIs =>
      'Usługa płatności to adres onion i dociera do niej tylko tryb onion. Nic nie zostało wysłane.';

  @override
  String get donateTorWasSlowTo =>
      'Tor zbyt wolno łączył się z usługą płatności. Możesz wpłacić na adres poniżej, tylko odznaka nie odblokuje się sama. Spróbuj później, jeśli chcesz odznakę.';

  @override
  String get donateThePaymentServiceIsHavingTrouble =>
      'Występują problemy z usługą płatności. Nadal możesz wpłacić na adres poniżej, tylko odznaka nie odblokuje się sama. Spróbuj później, jeśli chcesz odznakę.';

  @override
  String get commonTryAgain => 'Spróbuj ponownie';

  @override
  String donateBtc(Object btc) {
    return '$btc BTC';
  }

  @override
  String donateSendExactlyThisAmount(Object fmtLeft) {
    return 'Wyślij dokładnie tę kwotę · wygasa za $fmtLeft';
  }

  @override
  String get donateOpenWallet => 'Otwórz portfel';

  @override
  String get donateThisScreenUpdatesItself =>
      'Ten ekran sam się odświeży, gdy tylko płatność zostanie zauważona.\nNie zamykaj go. Nic nie jest zapisywane i nic cię nie identyfikuje.';

  @override
  String get donateWatchingTheChainFor =>
      'Wypatruję twojej płatności w łańcuchu';

  @override
  String get donateThisInvoiceExpired => 'Ta faktura wygasła';

  @override
  String get donateInvoicesTimeOutIf =>
      'Faktury wygasają. Jeśli płatność już wyszła, nie zamykaj tego ekranu: przez jakiś czas co minutę pytamy usługę ponownie, a także przy następnym otwarciu wsparcia. Nową możesz zacząć, kiedy chcesz.';

  @override
  String get donateNewInvoice => 'Nowa faktura';

  @override
  String get donateIPaidCheckAgain => 'Zapłacono, sprawdź ponownie';

  @override
  String get donateNoWallet =>
      'Żadna aplikacja portfela tutaj nie otwiera linków bitcoin. Skopiuj adres.';

  @override
  String get donateChecking => 'Sprawdzam…';

  @override
  String get donateNotSeenYet =>
      'Jeszcze nie widać. Płatność może pojawić się dopiero po kilku minutach.';

  @override
  String get donatePaymentConfirmed => 'Płatność potwierdzona';

  @override
  String get donateThankYouForKeeping =>
      'Dziękuję, że Kryfo może pozostać niezależne.';

  @override
  String donateVerifiedOnChainYou(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter':
          'Potwierdzone w łańcuchu. Teraz wspierasz Kryfo. Nikt ci tego nie odbierze.',
      'patron':
          'Potwierdzone w łańcuchu. Teraz masz odznakę mecenasa. Nikt ci tego nie odbierze.',
      'guardian':
          'Potwierdzone w łańcuchu. Teraz masz odznakę strażnika. Nikt ci tego nie odbierze.',
      'other':
          'Potwierdzone w łańcuchu. Teraz wspierasz Kryfo. Nikt ci tego nie odbierze.',
    });
    return '$_temp0';
  }

  @override
  String donateVerifiedBadgeStays(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter':
          'Potwierdzone w łańcuchu. Dziękujemy za kolejne wsparcie. Zachowujesz odznakę wspierającego.',
      'patron':
          'Potwierdzone w łańcuchu. Dziękujemy za kolejne wsparcie. Zachowujesz odznakę mecenasa.',
      'guardian':
          'Potwierdzone w łańcuchu. Dziękujemy za kolejne wsparcie. Zachowujesz odznakę strażnika.',
      'other':
          'Potwierdzone w łańcuchu. Dziękujemy za kolejne wsparcie. Zachowujesz odznakę wspierającego.',
    });
    return '$_temp0';
  }

  @override
  String get donateWearMyBadge => 'Noś moją odznakę';

  @override
  String get donateJustGladToHelp => 'Po prostu chcę pomóc';

  @override
  String get gettingMessagesAlwaysOn => 'Zawsze włączone';

  @override
  String get gettingMessagesMostPrivate => 'Najbardziej prywatne';

  @override
  String get gettingMessagesMessagesArriveInstantlyNothing =>
      'Zużywa najwięcej baterii.\nOd razu, i nic nie wychodzi poza Tor.';

  @override
  String get gettingMessagesArriveInstantlyFast =>
      'Zużywa najwięcej baterii.\nOd razu w trybie Szybki.';

  @override
  String get gettingMessagesCheckIns => 'Sprawdzenia';

  @override
  String get gettingMessagesLightest => 'Najlżejsze';

  @override
  String get gettingMessagesKryfoLooksForMessages =>
      'Kryfo sprawdza co 15 minut, więc wiadomości mogą się spóźniać.\nOszczędza baterię.';

  @override
  String get gettingMessagesAGenericAlertWith =>
      'Ogólne powiadomienie, bez nadawcy i bez treści';

  @override
  String get gettingMessagesShowsMessageTextIn =>
      'Pokazuje treść wiadomości w powiadomieniach, nawet gdy Kryfo jest zablokowane.';

  @override
  String get gettingMessagesWhenThePhoneSits =>
      'Gdy telefon leży bez ruchu, Android rzadziej robi sprawdzenia. Linia powyżej pokazuje ostatnią prawdziwą. Gdy Kryfo jest otwarte, połączenie trwa.';

  @override
  String get groupChatJumpToTheNewest => 'Przejdź do najnowszych';

  @override
  String get groupChatYou => 'Ty';

  @override
  String get groupChatVoiceMessage => 'Wiadomość głosowa';

  @override
  String get groupChatQuotedPhoto => 'Zdjęcie';

  @override
  String get groupChatMessageUnavailable => 'Wiadomość niedostępna';

  @override
  String get groupChatTorIsNotUp =>
      'Tor jeszcze nie połączony · bez podglądu linku';

  @override
  String get groupChatCouldnTReachIt =>
      'Nie udało się połączyć ze stroną · bez podglądu linku';

  @override
  String get groupChatNoTitleCameBack =>
      'Ta strona nie ma tytułu · bez podglądu linku';

  @override
  String get groupChatCouldnTFetchIt => 'Nie udało się wczytać podglądu';

  @override
  String get groupChatCamera => 'Aparat';

  @override
  String get groupChatGallery => 'Galeria';

  @override
  String get groupChatVideo => 'Wideo';

  @override
  String get groupChatGifFromPhone => 'GIF z telefonu';

  @override
  String get groupChatGifFromPhoneDesk => 'GIF z komputera';

  @override
  String get groupChatCouldNotReadThat => 'Nie udało się odczytać tego pliku';

  @override
  String get groupChatGifTooBig8 => 'GIF za duży · maks. 8 MB';

  @override
  String get groupChatCouldNotCleanThat => 'Nie udało się wyczyścić tego GIF-a';

  @override
  String get groupChatCouldNotCleanThatVideo =>
      'Nie udało się wyczyścić tego wideo';

  @override
  String get groupChatToday => 'Dzisiaj';

  @override
  String get groupChatYesterday => 'Wczoraj';

  @override
  String get groupChatYou2 => 'Ty';

  @override
  String groupChatThisChatHasPins(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ten czat ma już $countString przypiętej',
      many: 'Ten czat ma już $countString przypiętych',
      few: 'Ten czat ma już $countString przypięte',
      one: 'Ten czat ma już $countString przypiętą',
    );
    return '$_temp0';
  }

  @override
  String get groupChatUnpinThisMessage => 'Odpiąć tę wiadomość?';

  @override
  String get groupChatPinThisMessage => 'Przypiąć tę wiadomość?';

  @override
  String get groupChatItLeavesThePinned =>
      'Zniknie z przypiętych dla wszystkich tutaj.';

  @override
  String get groupChatItGoesUnderThe =>
      'Trafi pod przypięte u góry czatu, dla wszystkich tutaj.';

  @override
  String get groupChatUnpin => 'Odepnij';

  @override
  String get groupChatPinIt => 'Przypnij';

  @override
  String get groupChatNotNow => 'Nie teraz';

  @override
  String get groupChatSaved => 'Zapisano';

  @override
  String get groupChatRemovedFromSaved => 'Usunięto z zapisanych';

  @override
  String get groupChatForwardTo => 'Przekaż do';

  @override
  String get groupChatNoContactsToForward =>
      'Brak kontaktów, do których można przekazać';

  @override
  String get groupChatEditMessage => 'Edytuj wiadomość';

  @override
  String get groupChatUnsendMessage => 'Cofnąć wysłanie?';

  @override
  String get groupChatItDisappearsWithNo =>
      'Zostanie usunięta z telefonów wszystkich osób, chyba że już ją zapisano. Tego nie da się cofnąć.';

  @override
  String get groupChatItDisappearsWithNoDesk =>
      'Zostanie usunięta z urządzeń wszystkich osób, chyba że już ją zapisano. Tego nie da się cofnąć.';

  @override
  String get groupChatUnsend => 'Cofnij wysłanie';

  @override
  String groupChatThisRoomAndEverything(Object expiryWords) {
    return 'Ten pokój i wszystko w nim zniknie za $expiryWords';
  }

  @override
  String groupChatGhostModeOnBurns(Object fmtBurn) {
    return 'Wiadomości czasowe · płoną po $fmtBurn';
  }

  @override
  String get groupChatGroupCreatedSayHi => 'Grupa utworzona. Przywitaj się.';

  @override
  String get groupChatNoMessagesYet => 'Jeszcze brak wiadomości.';

  @override
  String get groupChatEveryoneHereReads => 'Wszyscy tutaj czytają, co piszesz.';

  @override
  String get groupChatNobodyHereYet => 'Jeszcze nikogo tu nie ma.';

  @override
  String get groupChatShareTheRoomLink =>
      'Udostępnij link do pokoju. Kto dołączy, od tego momentu czyta to, co zostanie napisane.';

  @override
  String get groupChatNobodyToReadIt =>
      'Nikogo więcej tu nie ma, żeby to przeczytać.';

  @override
  String get groupChatThisMessageCanT => 'Tej wiadomości nie da się wyświetlić';

  @override
  String groupChatS(Object s) {
    return '$s s';
  }

  @override
  String groupChatM(Object s) {
    return '$s min';
  }

  @override
  String groupChatH(Object s) {
    return '$s godz.';
  }

  @override
  String groupChatD(Object s) {
    return '$s d';
  }

  @override
  String groupChatHere(int count, Object time) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$time · $countString tutaj',
      many: '$time · $countString tutaj',
      few: '$time · $countString tutaj',
      one: '$time · $countString tutaj',
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
      other: '$countString członka',
      many: '$countString członków',
      few: '$countString członków',
      one: '$countString członek',
    );
    return '$_temp0';
  }

  @override
  String get groupChatSearchThisChat => 'Szukaj w tym czacie';

  @override
  String groupChatReplyingTo(Object name) {
    return 'Odpowiadasz: $name';
  }

  @override
  String get groupChatReplyingToYou => 'Odpowiedź do ciebie';

  @override
  String get groupChatTimedMessages => 'Wiadomości czasowe';

  @override
  String get groupChatOpenTheCamera => 'Otwórz aparat';

  @override
  String get groupChatAttachAPhoto => 'Dołącz zdjęcie';

  @override
  String get groupChatMessage => 'Wiadomość';

  @override
  String get groupChatSupporter => 'Wspierający';

  @override
  String get groupChatEdited => 'Edytowano';

  @override
  String get groupChatTapToRetry => '! Stuknij, by ponowić';

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
      other: 'Wysłano · ma $haveString z $countString',
      many: 'Wysłano · ma $haveString z $countString',
      few: 'Wysłano · mają $haveString z $countString',
      one: 'Wysłano · ma $haveString z $countString',
      zero: 'Wysłano · w drodze',
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
      other: 'Wysłano · $countString osoby nie dostało',
      many: 'Wysłano · $countString osób nie dostało',
      few: 'Wysłano · $countString osoby nie dostały',
      one: 'Wysłano · $countString osoba nie dostała',
    );
    return '$_temp0';
  }

  @override
  String get groupChatReply => 'Odpowiedz';

  @override
  String get groupChatPin => 'Przypnij';

  @override
  String get groupChatUnsave => 'Usuń z zapisanych';

  @override
  String get groupChatForward => 'Przekaż dalej';

  @override
  String get groupInfoGroup => 'Grupa';

  @override
  String get groupInfoRenameGroup => 'Zmień nazwę grupy';

  @override
  String get groupInfoRename => 'Zmień nazwę';

  @override
  String get groupInfoNoContactsToAdd => 'Brak kontaktów do dodania';

  @override
  String get groupInfoCouldNotAdd => 'Nie udało się dodać';

  @override
  String groupInfoRemove(Object haloId) {
    return 'Usunąć $haloId?';
  }

  @override
  String get groupInfoTheyWillStopReceiving =>
      'Ta osoba przestanie dostawać wiadomości z tej grupy.';

  @override
  String get groupInfoResetLink => 'Zresetuj link';

  @override
  String get groupInfoResetTheRoomLink => 'Zresetować link do pokoju?';

  @override
  String get groupInfoResetLinkLine =>
      'Stary link przestanie działać. Osoby w pokoju zostają i dostają nowy link.';

  @override
  String get groupInfoRemoveRoomLine =>
      'Ta osoba może wrócić przez link do pokoju. Zresetuj link, żeby jej nie wpuścić. Osoby, które zostają w pokoju, dostaną nowy.';

  @override
  String get groupInfoRemoveAndResetLink => 'Usuń i zresetuj link';

  @override
  String get groupInfoCouldNotResetLink => 'Nie udało się zresetować linku';

  @override
  String get roomLinkNewLinkTheOld => 'Nowy link. Stary już nie działa.';

  @override
  String appGroupHoldsUpTo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Grupa mieści do $countString osoby',
      many: 'Grupa mieści do $countString osób',
      few: 'Grupa mieści do $countString osób',
      one: 'Grupa mieści do $countString osoby',
    );
    return '$_temp0';
  }

  @override
  String get commonRemove => 'Usuń';

  @override
  String get groupInfoClearThisConversation => 'Wyczyścić tę rozmowę?';

  @override
  String get groupInfoEveryMessageHereIs =>
      'Każda wiadomość stąd zostanie usunięta z tego telefonu. To czyści tylko twoją kopię, inni członkowie zachowują swoje.';

  @override
  String get groupInfoEveryMessageHereIsDesk =>
      'Każda wiadomość stąd zostanie usunięta z tego komputera. To czyści tylko twoją kopię, inni członkowie zachowują swoje.';

  @override
  String get groupInfoClear => 'Wyczyść';

  @override
  String get groupInfoConversationCleared => 'Rozmowa wyczyszczona';

  @override
  String get groupInfoLeaveRoom => 'Opuścić pokój?';

  @override
  String get groupInfoLeaveGroup => 'Opuścić grupę?';

  @override
  String get groupInfoEverythingInItIs =>
      'Wszystko w nim zostanie teraz wymazane z tego telefonu, a klucz, którego tu używano, zniknie na zawsze.';

  @override
  String get groupInfoEverythingInItIsDesk =>
      'Wszystko w nim zostanie teraz wymazane z tego komputera, a klucz, którego tu używano, zniknie na zawsze.';

  @override
  String groupChatYouWereRemovedFrom(Object name) {
    return 'Usunięto cię z $name';
  }

  @override
  String get groupInfoLeaveGroupLine =>
      'Przestaniesz otrzymywać wiadomości, a cała historia czatu zostanie usunięta z tego telefonu.';

  @override
  String get groupInfoLeaveGroupLineDesk =>
      'Przestaniesz otrzymywać wiadomości, a cała historia czatu zostanie usunięta z tego komputera.';

  @override
  String get groupInfoLeaveGroupAdmin =>
      'Przestaniesz otrzymywać wiadomości z tej grupy, a wszystkie dane zostaną wyczyszczone z tego telefonu. Zarządzasz tą grupą, więc po twoim odejściu nikt nie zarządzi członkami ani nie zmieni nazwy.';

  @override
  String get groupInfoLeaveGroupAdminDesk =>
      'Przestaniesz otrzymywać wiadomości z tej grupy, a wszystkie dane zostaną wyczyszczone z tego komputera. Zarządzasz tą grupą, więc po twoim odejściu nikt nie zarządzi członkami ani nie zmieni nazwy.';

  @override
  String get groupInfoLeaveRoomMaker =>
      'Zawartość zostanie usunięta z telefonu, a klucz przepadnie na zawsze. Link do stworzonego przez ciebie pokoju przestanie działać dla wszystkich.';

  @override
  String get groupInfoLeaveRoomMakerDesk =>
      'Zawartość zostanie usunięta z komputera, a klucz przepadnie na zawsze. Link do stworzonego przez ciebie pokoju przestanie działać dla wszystkich.';

  @override
  String get groupInfoLeave => 'Opuść';

  @override
  String get groupInfoGroupInfo => 'Informacje o grupie';

  @override
  String groupInfo1Member(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString członka',
      many: '$countString członków',
      few: '$countString członków',
      one: '$countString członek',
    );
    return '$_temp0';
  }

  @override
  String get groupInfoAdmin => 'Administrator';

  @override
  String get groupInfoMembers2 => 'Członkowie';

  @override
  String get groupInfoInvite => 'Zaproś';

  @override
  String get commonAdd => 'Dodaj';

  @override
  String get groupInfoYou => 'Ty';

  @override
  String get groupInfoRemoveFromGroup => 'Usuń z grupy';

  @override
  String get groupInfoWallpaper => 'Tapeta';

  @override
  String get groupInfoSharedMedia => 'Udostępnione multimedia';

  @override
  String get groupInfoClearConversation => 'Wyczyść rozmowę';

  @override
  String get groupInfoLeaveRoom2 => 'Opuść pokój';

  @override
  String get groupInfoLeaveGroup2 => 'Opuść grupę';

  @override
  String get groupInfoAddMembers => 'Dodaj członków';

  @override
  String groupInfoAdd(Object pickedLength) {
    return 'Dodaj $pickedLength';
  }

  @override
  String handleYouAre(Object h) {
    return 'Jesteś @$h';
  }

  @override
  String get handleHandleDeletedThePage =>
      'Profil usunięty · strona niedostępna';

  @override
  String get handlePublicHandle => 'Publiczna nazwa użytkownika';

  @override
  String get handleOptionalYourThreeWords =>
      'Opcjonalnie. Twoje trzy słowa działają tak czy inaczej.';

  @override
  String get handleHintName => 'name';

  @override
  String get handleALineAboutYou => 'Linijka o tobie · opcjonalnie';

  @override
  String get handleClaiming => 'Zajmuję…';

  @override
  String get handleClaimThisHandle => 'Zajmij tę nazwę';

  @override
  String get handleAnyoneWithThisLink =>
      'Każdy z tym linkiem może zacząć z tobą prywatny czat. Zawiera twoje zaproszenie i nic więcej.';

  @override
  String get handleLinkCopied => 'Link skopiowany';

  @override
  String get handleDeleteThisHandle => 'Usuń tę nazwę użytkownika';

  @override
  String handleDeleteTitle(Object handle) {
    return 'Usunąć @$handle?';
  }

  @override
  String get handleDeleteLine =>
      'Twoja publiczna strona zniknie, a nazwa będzie wolna dla każdego. Czaty, które już masz, zostają bez zmian.';

  @override
  String get handleDeleteYes => 'Usuń nazwę';

  @override
  String get handleDeleting => 'Usuwam…';

  @override
  String get handleChecking => 'Sprawdzam…';

  @override
  String get handleAvailable => 'Dostępna';

  @override
  String get handleAlreadyTaken => 'Już zajęta';

  @override
  String get handleNameRule => 'Od 3 do 20 znaków: a-z, 0-9 lub _';

  @override
  String get handleWhatAHandleDoes => 'Do czego służy nazwa użytkownika';

  @override
  String get handleAnyoneWhoKnowsIt =>
      'Każdy, kto ją zna, może poprosić o rozmowę z tobą. Strona zawiera twoje zaproszenie i linijkę, którą napiszesz, nic więcej, i nie zapisuje, kto ją czyta. Możesz ją usunąć, kiedy chcesz.';

  @override
  String handleIsNotYoursOn(Object handle) {
    return '@$handle nie jest twoja na tym telefonie';
  }

  @override
  String handleIsNotYoursOnDesk(Object handle) {
    return '@$handle nie jest twoja na tym komputerze';
  }

  @override
  String handleTheRegistryHoldsIt(Object handle) {
    return 'Rejestr trzyma ją pod innym kluczem, najpewniej tożsamością, którą ten telefon miał przed przywróceniem. Osoby, które dodają @$handle, nie trafiają do ciebie. Nie da się jej stąd zwolnić ani zmienić. Wybierz inną nazwę.';
  }

  @override
  String handleTheRegistryHoldsItDesk(Object handle) {
    return 'Rejestr trzyma ją pod innym kluczem, najpewniej tożsamością, którą ten komputer miał przed przywróceniem. Osoby, które dodają @$handle, nie trafiają do ciebie. Nie da się jej stąd zwolnić ani zmienić. Wybierz inną nazwę.';
  }

  @override
  String get handleForgetItOnThis => 'Zapomnij ją na tym telefonie';

  @override
  String get handleForgetItOnThisDesk => 'Zapomnij ją na tym komputerze';

  @override
  String get homeAddAContact => 'Dodaj kontakt';

  @override
  String get commonSettings => 'Ustawienia';

  @override
  String get homeYourKryfo => 'Twoje Kryfo';

  @override
  String homeDateWeekday(Object weekday) {
    return '$weekday,';
  }

  @override
  String get homeAnHour => 'godzina';

  @override
  String homeHours(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString godziny',
      many: '$countString godzin',
      few: '$countString godziny',
      one: '$countString godzina',
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
      other: '$countString minuty',
      many: '$countString minut',
      few: '$countString minuty',
      one: '$countString minuta',
    );
    return '$_temp0';
  }

  @override
  String get homeKryfoIsOffline => 'Kryfo jest offline';

  @override
  String homeTorHasNotBeen(Object howLong) {
    return 'Tor nie może się połączyć od $howLong. Dopóki się nie połączy, nic nie dotrze ani nie wyjdzie.';
  }

  @override
  String get homeReconnecting => 'Łączę ponownie';

  @override
  String get homeReconnect => 'Połącz ponownie';

  @override
  String get homeWhatIsWrong => 'Co jest nie tak';

  @override
  String get homeKryfoWillCheckIn => 'Kryfo będzie sprawdzać co 15 minut';

  @override
  String get homeYourPhoneKeepsStopping =>
      'Twój telefon ciągle zatrzymuje Kryfo';

  @override
  String get homeItHasClosedKryfo =>
      'Dziś zamknął Kryfo już trzy razy, więc wiadomości się spóźniały albo czekały. Sprawdzenia to przetrwają: Kryfo budzi się co 15 minut, zamiast być stale połączone.';

  @override
  String get homeSwitchToCheckIns => 'Przełącz na sprawdzenia';

  @override
  String get homeNotNow => 'Nie teraz';

  @override
  String get homeNotificationsAreOff => 'Powiadomienia są wyłączone';

  @override
  String get homeAndroidIsBlockingThem =>
      'Android je blokuje, więc nic do ciebie nie dociera, gdy Kryfo jest zamknięte. Wiadomości i tak przyjdą, gdy je otworzysz.';

  @override
  String get homeCouldnTOpenIt =>
      'Nie udało się otworzyć. Poszukaj Kryfo w ustawieniach telefonu';

  @override
  String get homeTurnThemOn => 'Włącz je';

  @override
  String get homeLeaveThemOff => 'Zostaw wyłączone';

  @override
  String get homeKeepWaiting => 'Czekaj dalej';

  @override
  String get homeOffline => 'Offline';

  @override
  String get homeWaiting => 'Czeka';

  @override
  String get homeNothingWaitingToSend => 'Nic nie czeka na wysłanie';

  @override
  String homeWaitingSendsWhenYou(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString czeka · wyślą się, gdy wrócisz',
      many: '$countString czeka · wyślą się, gdy wrócisz',
      few: '$countString czekają · wyślą się, gdy wrócisz',
      one: '$countString czeka · wyśle się, gdy wrócisz',
    );
    return '$_temp0';
  }

  @override
  String get homeNoKryfosYet => 'Jeszcze nikogo w Kryfo.';

  @override
  String get homeScanTheirCodeSend =>
      'Zeskanuj czyjś kod, wyślij link albo wpisz @nazwę, którą ci podano.';

  @override
  String get homeScanTheirCodeSendDesk =>
      'Wyślij link albo wpisz @nazwę, którą ci podano.';

  @override
  String get homeAddSomeone => 'Dodaj kogoś';

  @override
  String get homeArchived => 'Archiwum';

  @override
  String home1Chat(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString czatu',
      many: '$countString czatów',
      few: '$countString czaty',
      one: '$countString czat',
    );
    return '$_temp0';
  }

  @override
  String get homeGroups => 'Grupy';

  @override
  String get homeRoom => 'Pokój';

  @override
  String get homeNew => 'Nowa';

  @override
  String homeRoomExpired(Object expiredRoomName) {
    return '$expiredRoomName · pokój wygasł';
  }

  @override
  String get homeMentionedYou => 'Wspomniano cię';

  @override
  String homeMembers(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString członka',
      many: '$countString członków',
      few: '$countString członków',
      one: '$countString członek',
    );
    return '$_temp0';
  }

  @override
  String get homeSupporter => 'Wspierający';

  @override
  String get homeUnmute => 'Wyłącz wyciszenie';

  @override
  String get homeMute => 'Wycisz';

  @override
  String get homeArchive => 'Archiwizuj';

  @override
  String get homeDeleteChat => 'Usuń czat';

  @override
  String get homeMessagesAndContactGone =>
      'Wiadomości i kontakt znikną z tego telefonu';

  @override
  String get homeMessagesAndContactGoneDesk =>
      'Wiadomości i kontakt znikną z tego komputera';

  @override
  String get homeDeleteThisChat => 'Usunąć ten czat?';

  @override
  String homeEveryMessageWithGoes(Object c) {
    return 'Każda wiadomość z $c zniknie, a ta osoba przestanie być kontaktem. To czyści tylko ten telefon. Jej kopia zostaje u niej. Jeśli znów napisze, trafi do próśb.';
  }

  @override
  String homeEveryMessageWithGoesDesk(Object c) {
    return 'Każda wiadomość z $c zniknie, a ta osoba przestanie być kontaktem. To czyści tylko ten komputer. Jej kopia zostaje u niej. Jeśli znów napisze, trafi do próśb.';
  }

  @override
  String get homeQueued => 'W kolejce';

  @override
  String get homeBlocked => 'Zablokowany';

  @override
  String get homeRoomInvite => 'Zaproszenie do pokoju';

  @override
  String get homeNow => 'Teraz';

  @override
  String homeM(Object inMinutes) {
    return '$inMinutes min';
  }

  @override
  String homeH(Object inHours) {
    return '$inHours godz.';
  }

  @override
  String get homeYesterday => 'Wczoraj';

  @override
  String homeD(Object inDays) {
    return '$inDays d';
  }

  @override
  String get homeNoteToSelf => 'Notatka dla siebie';

  @override
  String get homeOnlyOnThisPhone => 'Tylko na tym telefonie';

  @override
  String get homeOnlyOnThisPhoneDesk => 'Tylko na tym komputerze';

  @override
  String get homeSaved => 'Zapisane';

  @override
  String get homeKeptFromEveryChat => 'Zachowane ze wszystkich czatów';

  @override
  String get homeRequests => 'Prośby';

  @override
  String home1PersonWantsTo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString osoby chce się z tobą skontaktować',
      many: '$countString osób chce się z tobą skontaktować',
      few: '$countString osoby chcą się z tobą skontaktować',
      one: '$countString osoba chce się z tobą skontaktować',
    );
    return '$_temp0';
  }

  @override
  String introduceGotItButCould(Object b, Object c) {
    return 'Dotarło do $b, ale nie udało się dotrzeć do $c';
  }

  @override
  String introduceGotItButCouldNotBe(Object c, Object b) {
    return 'Dotarło do $c, ale nie udało się dotrzeć do $b';
  }

  @override
  String introduceIntroduced(Object b, Object c) {
    return '$b i $c mają teraz swoje wizytówki';
  }

  @override
  String get introduceCouldNotReachEither =>
      'Nie udało się dotrzeć do żadnej z tych osób. Spróbuj później';

  @override
  String introduceIntroduceTo(Object peerName) {
    return 'Przedstaw $peerName…';
  }

  @override
  String get introduceBothOfThemGet =>
      'Obie osoby dostaną wizytówkę drugiej. Żadna nie zobaczy, jak nazywasz tę drugą.';

  @override
  String get introduceNoOneElseTo =>
      'Nie ma jeszcze kogo przedstawić. Najpierw dodaj kolejny kontakt.';

  @override
  String get introduceANoteLikeMy => 'Notatka, np. „mój kuzyn” (opcjonalnie)';

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
      other: 'W tym tygodniu zostało $leftString z $maxString przedstawienia',
      many: 'W tym tygodniu zostało $leftString z $maxString przedstawień',
      few: 'W tym tygodniu zostało $leftString z $maxString przedstawień',
      one: 'W tym tygodniu zostało $leftString z $maxString przedstawienia',
    );
    return '$_temp0';
  }

  @override
  String introduceNoIntroductionsLeftNext(Object refillPhrase) {
    return 'Brak przedstawień. Następne zwolni się $refillPhrase';
  }

  @override
  String get introduceIntroduce => 'Przedstaw';

  @override
  String get keyVerificationSafetyNumber => 'Numer bezpieczeństwa';

  @override
  String get keyVerificationNewNumber =>
      'Kod bezpieczeństwa tej osoby zmienił się, gdy to było otwarte. To jest nowy numer: porównajcie go ponownie.';

  @override
  String get keyVerificationKeyMoved =>
      'Kod bezpieczeństwa tej osoby właśnie się zmienił. Porównajcie nowy numer.';

  @override
  String keyVerificationNoKeyYet(Object peerName) {
    return 'Jeszcze brak klucza od $peerName. Numer pojawi się tutaj, gdy ta osoba do ciebie napisze.';
  }

  @override
  String keyVerificationWith(Object peerName) {
    return 'Z $peerName';
  }

  @override
  String keyVerificationCompareAll(Object peerName) {
    return 'Porównaj wszystkie 12 grup z $peerName osobiście lub podczas zaufanej rozmowy. Jeśli każda grupa się zgadza, nikt nie znajduje się pośrodku, a twoje wiadomości są przeznaczone tylko dla was dwojga.';
  }

  @override
  String get keyVerificationVerified => 'Zweryfikowano';

  @override
  String get keyVerificationMarkAsVerified => 'Oznacz jako zweryfikowane';

  @override
  String get lockFileThatPasswordDoesNot => 'To hasło go nie otwiera.';

  @override
  String get lockFileThisFileIsDamaged => 'Ten plik jest uszkodzony.';

  @override
  String get lockFileThisFileWasLocked =>
      'Ten plik zablokowano kluczem, nie hasłem.';

  @override
  String get lockFileThisIsNotA => 'To nie jest zablokowany plik.';

  @override
  String get lockFileNotEnoughFreeMemory =>
      'Za mało wolnej pamięci w tej chwili.';

  @override
  String get lockFileStopped => 'Zatrzymano.';

  @override
  String get lockFileItNeedsAPassword => 'Potrzebne jest hasło.';

  @override
  String get lockFileKryfoCouldNotRead =>
      'Kryfo nie mogło odczytać ani zapisać pliku.';

  @override
  String get lockFileCheckCapitalsAndSpaces =>
      'Sprawdź wielkość liter i spacje. Nikt nie może go zresetować.';

  @override
  String get lockFileItMayHaveBeen =>
      'Mógł zostać ucięty po drodze. Poproś o ponowne wysłanie. Nic nie zostało zapisane.';

  @override
  String get lockFileItOpensWithThe =>
      'Otwiera się plikiem klucza osoby, dla której go zrobiono, w narzędziu age na komputerze. Kryfo otwiera rodzaj z hasłem.';

  @override
  String get lockFileKryfoOpensFilesLocked =>
      'Kryfo otwiera pliki zablokowane przez age. Zwykle kończą się na .age.';

  @override
  String get lockFileCloseAFewApps =>
      'Zamknij kilka aplikacji i spróbuj ponownie. Sprawdzenie hasła potrzebuje na chwilę kilkuset megabajtów.';

  @override
  String get lockFileNothingWasSaved => 'Nic nie zostało zapisane.';

  @override
  String get lockFileTypeOneOrLet =>
      'Wpisz je albo pozwól Kryfo zaproponować cztery słowa.';

  @override
  String get lockFileTheAppThatHolds =>
      'Aplikacja, w której jest plik, mogła go cofnąć. Wybierz go ponownie.';

  @override
  String get lockFileHidePassword => 'Ukryj hasło';

  @override
  String get lockFileShowPassword => 'Pokaż hasło';

  @override
  String get lockFileChangeFile => 'Zmień plik';

  @override
  String get lockFileChange => 'Zmień';

  @override
  String lockFileOf(Object prettySize, Object prettySize2) {
    return '$prettySize z $prettySize2';
  }

  @override
  String get lockFileEverythingStaysOnThis =>
      'Wszystko zostaje na tym telefonie.';

  @override
  String get lockFileEverythingStaysOnThisDesk =>
      'Wszystko zostaje na tym komputerze.';

  @override
  String get lockFileCouldNotMakeOne => 'Nie udało się utworzyć. Wpisz własne.';

  @override
  String get lockFileWriteItDownBefore => 'Zapisz je, zanim zablokujesz plik';

  @override
  String get lockFileNoAppOnThis =>
      'Żadna aplikacja na tym telefonie nie przyjęła pliku.';

  @override
  String get linkNoAppOpens =>
      'Żadna aplikacja na tym telefonie nie otwiera tego linku.';

  @override
  String get linkNoAppOpensDesk =>
      'Żadna aplikacja na tym komputerze nie otwiera tego linku.';

  @override
  String get placeStubLocation => 'Lokalizacja';

  @override
  String get lockFileSaved => 'Zapisano';

  @override
  String get lockFileCouldNotSaveIt =>
      'Nie udało się zapisać tutaj. Spróbuj w innym folderze.';

  @override
  String get lockFileLocked => 'Zablokowany';

  @override
  String get lockFileLockAFile => 'Zablokuj plik';

  @override
  String get lockFileMixingThePassword => 'Mieszam hasło';

  @override
  String get lockFileLocking => 'Blokuję';

  @override
  String get lockFileSaveToFiles => 'Zapisz w Plikach';

  @override
  String get lockFileSaveToFilesDesk => 'Zapisz plik';

  @override
  String get lockFileLockFile => 'Zablokuj plik';

  @override
  String get lockFileOnePassword => 'Jedno hasło.';

  @override
  String get lockFileNothingElseOpensIt => 'Nic innego go nie otworzy.';

  @override
  String get lockFileFile => 'Plik';

  @override
  String lockFileFromFiles(Object prettySize) {
    return '$prettySize · z Plików';
  }

  @override
  String get lockFileFromFiles2 => 'Z Plików';

  @override
  String get lockFilePassword => 'Hasło';

  @override
  String get lockFileSuggestFourWords => 'Zaproponuj cztery słowa';

  @override
  String get lockFileTypeItAgain => 'Wpisz je ponownie';

  @override
  String get lockFileTheTwoDoNot => 'Te dwa jeszcze się nie zgadzają.';

  @override
  String get lockFileHideTheFileName => 'Ukryj nazwę pliku';

  @override
  String lockFileItWillBeCalled(Object name) {
    return 'Będzie się nazywał „$name”. Powiedz odbiorcy, jaki to rodzaj pliku.';
  }

  @override
  String get lockFileTheNameAloneCan =>
      'Sama nazwa może zdradzić, co jest w środku.';

  @override
  String get lockFileAnyoneWithThePassword =>
      'Każdy z hasłem może go otworzyć, w Kryfo albo na dowolnym komputerze z darmowym narzędziem age. Zapomnisz hasło, a plik przepadnie na zawsze. Nikt nie może go zresetować.';

  @override
  String get lockFileLocked2 => 'Zablokowany.';

  @override
  String get lockFileOnlyThePasswordOpens => 'Otwiera go tylko hasło.';

  @override
  String lockFileSafeToEmailOr(Object prettySize) {
    return '$prettySize · można bezpiecznie wysłać mailem albo wrzucić na pendrive';
  }

  @override
  String get lockFileNoKryfoOnThe =>
      'Druga strona nie ma Kryfo? Na komputerze:';

  @override
  String get lockFileItAsksForThe =>
      'Zapyta o hasło. age jest darmowe na age-encryption.org';

  @override
  String lockTooManyTriesS(Object lockState) {
    return 'Za dużo prób · $lockState s';
  }

  @override
  String get lockNotIt => 'To nie to';

  @override
  String get lockYourPin => 'Twój PIN';

  @override
  String get lockUseFingerprint => 'Użyj odcisku palca';

  @override
  String get lockSetupUnlockWithFingerprint => 'Odblokowywać odciskiem palca?';

  @override
  String get lockSetupThePinStillWorks =>
      'PIN nadal działa, kiedy tylko chcesz. To po prostu szybsze.';

  @override
  String get lockSetupUseFingerprint => 'Użyj odcisku palca';

  @override
  String get lockSetupTurningOn => 'Włączam…';

  @override
  String get lockSetupPinOnly => 'Tylko PIN';

  @override
  String get lockSetupOnceMore => 'Jeszcze raz';

  @override
  String get lockSetupSetAPin => 'Ustaw PIN';

  @override
  String get lockSetupThoseWereDifferentFrom => 'Były różne. Od nowa.';

  @override
  String get lockSetupTheSameFourDigits => 'Te same cyfry jeszcze raz';

  @override
  String get lockSetupFourDigitsAnythingYou =>
      'Co najmniej cztery cyfry, które zapamiętasz';

  @override
  String get modesFast => 'Szybki';

  @override
  String get modesNotChanged => 'Tryb się nie zmienił. Spróbuj ponownie.';

  @override
  String get modesSwitching => 'Przełączam…';

  @override
  String get modesSpeed => 'Szybkość';

  @override
  String get modesPrivacy => 'i prywatność';

  @override
  String get movedWipeThisPhone => 'Wymazać Kryfo z tego telefonu?';

  @override
  String get movedWipeThisPhoneDesk => 'Wymazać Kryfo z tego komputera?';

  @override
  String get movedEverythingKryfoHoldsHere =>
      'Zniknie wszystko, co Kryfo tu trzyma: wiadomości, kontakty, klucze. Drugie urządzenie zachowuje to wszystko. Tego nie da się cofnąć.';

  @override
  String get movedWipeIt => 'Wymaż';

  @override
  String get movedNotMovingAfterAll => 'Jednak bez przenosin?';

  @override
  String get movedOnlyDoThisIf =>
      'Zrób to tylko wtedy, gdy kopia nigdzie nie została zaimportowana. Jeśli została, dwa urządzenia mają teraz jedną tożsamość i na obu zaczną ginąć wiadomości.';

  @override
  String get movedIMStayingHere => 'Zostaję tutaj';

  @override
  String get movedStayingHere => 'Zostajesz tutaj';

  @override
  String movedKryfoWillCloseNow(Object myId) {
    return 'Kryfo się teraz zamknie. Stuknij ikonę, żeby otworzyć je ponownie jako $myId.';
  }

  @override
  String movedKryfoWillCloseNowDesk(Object myId) {
    return 'Kryfo się teraz zamknie. Uruchom je ponownie, żeby otworzyć jako $myId.';
  }

  @override
  String get movedReopenKryfo => 'Otwórz Kryfo ponownie';

  @override
  String get movedThisKryfoHasMoved => 'To Kryfo zostało przeniesione';

  @override
  String movedIsNowOnAnother(Object myId) {
    return '$myId jest teraz na innym urządzeniu. Ten telefon nadal pokaże to, co tu było, ale nic nowego tu nie dotrze, a nic wysłanego stąd do nikogo nie trafi.';
  }

  @override
  String movedIsNowOnAnotherDesk(Object myId) {
    return '$myId jest teraz na innym urządzeniu. Ten komputer nadal pokaże to, co tu było, ale nic nowego tu nie dotrze, a nic wysłanego stąd do nikogo nie trafi.';
  }

  @override
  String get movedKeepItToRead => 'Zachowaj do czytania';

  @override
  String get movedWipeThisPhone2 => 'Wymaż Kryfo z tego telefonu';

  @override
  String get movedWipeThisPhone2Desk => 'Wymaż Kryfo z tego komputera';

  @override
  String get movedIMNotMoving => 'Jednak się nie przenoszę';

  @override
  String get myKryfoAHandleIs3 =>
      'Nazwa użytkownika to od 3 do 20 liter, cyfr lub _';

  @override
  String get myKryfoInviteCopiedClearsIn =>
      'Zaproszenie skopiowane · zniknie ze schowka za 60 s';

  @override
  String get myKryfoAddMeOnKryfo2 => 'Dodaj mnie w Kryfo';

  @override
  String get myKryfoAddSomeone => 'Dodaj kogoś';

  @override
  String get myKryfoKryfoDoesnTScan =>
      'Kryfo nie przeszukuje twoich kontaktów i właśnie o to chodzi.';

  @override
  String get myKryfoIfThisLinkEnds =>
      'Jeśli ten link trafi gdzieś, gdzie nie chcesz, zresetuj go w ustawieniach. Każdy, kto go ma, będzie wtedy potrzebować nowego.';

  @override
  String get myKryfoAlreadyShareAFriend =>
      'Macie już wspólnego znajomego w Kryfo? Może was przedstawić ze swojego czatu, a wtedy pomijacie prośbę.';

  @override
  String get myKryfoHandleCopied => 'Nazwa użytkownika skopiowana';

  @override
  String get myKryfoTheyReHereWith => 'Ta osoba jest obok mnie';

  @override
  String get myKryfoPointYourPhonesAt =>
      'Skierujcie telefony na siebie. Nic nie przechodzi przez serwer.';

  @override
  String get myKryfoPointYourPhonesAtDesk =>
      'Druga osoba skanuje ten kod telefonem. Nic nie przechodzi przez serwer.';

  @override
  String get myKryfoScanTheirsInstead => 'Zeskanuj jej kod';

  @override
  String get myKryfoTheyReadYouA => 'Ta osoba czyta ci kod';

  @override
  String get myKryfoTheyReSomewhereElse => 'Ta osoba jest gdzie indziej';

  @override
  String get myKryfoSendThemALink =>
      'Wyślij link. Otwiera się prosto w dodawaniu.';

  @override
  String get myKryfoYourLinkAppearsOnce => 'Twój link pojawi się po połączeniu';

  @override
  String get myKryfoTheLinkCarriesYour =>
      'Link zawiera twoje trzy słowa, adres i klucze do rozpoczęcia czatu. Działa, dopóki nie zresetujesz go w ustawieniach.';

  @override
  String get myKryfoSendTheLink => 'Wyślij link';

  @override
  String get myKryfoAsACard => 'Jako wizytówkę';

  @override
  String get myKryfoAnImageWithThe => 'Obrazek z kodem QR';

  @override
  String get myKryfoAsAFile => 'Jako plik';

  @override
  String get myKryfoContactFile => 'Plik kontaktu';

  @override
  String get myKryfoIKnowTheirHandle => 'Znam nazwę użytkownika';

  @override
  String get myKryfoTypeTheNameThey =>
      'Wpisz @nazwę, którą ci podano. Działa, jeśli ta osoba ją zajęła.';

  @override
  String get myKryfoTheLookupAsksFor =>
      'Wyszukiwanie wysyła tylko tę jedną nazwę i nic o tobie. Twoja pierwsza wiadomość i tak dotrze jako prośba.';

  @override
  String get myKryfoLooking => 'Szukam…';

  @override
  String get myKryfoFindThem => 'Znajdź';

  @override
  String get myKryfoYourAddressAppearsOnce =>
      'Twój adres pojawi się po połączeniu';

  @override
  String get myKryfoAPublicHandle => 'Publiczna nazwa użytkownika';

  @override
  String get myKryfoPutItInA =>
      'Wstaw ją do bio. Każdy, kto ją zna, może cię znaleźć.';

  @override
  String get myKryfoANamePeopleCan =>
      'Nazwa, po której można cię znaleźć. Wyłączona, dopóki jej nie zajmiesz.';

  @override
  String get newGroupCouldNotCreate => 'Nie udało się utworzyć';

  @override
  String get newGroupNewGroup => 'Nowa grupa';

  @override
  String get newGroupCreating => 'Tworzę…';

  @override
  String get newGroupCreate => 'Utwórz';

  @override
  String get newGroupGroupName => 'Nazwa grupy';

  @override
  String get newGroupMembers => 'Członkowie';

  @override
  String get newGroupPickAtLeastOne => 'Wybierz co najmniej jedną osobę';

  @override
  String newGroupSelected(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Wybrano $countString',
      many: 'Wybrano $countString',
      few: 'Wybrano $countString',
      one: 'Wybrano $countString',
    );
    return '$_temp0';
  }

  @override
  String get newGroupAddAtLeastOne =>
      'Zanim utworzysz grupę, dodaj co najmniej jeden kontakt.';

  @override
  String get newGroupNeedsContacts => 'Grupy tworzy się z kontaktami';

  @override
  String get newGroupAddSomeoneFirst =>
      'Najpierw kogoś dodaj. Pokój nie potrzebuje kontaktów: każdy z jego linkiem może dołączyć.';

  @override
  String get notesDeleteThisNote => 'Usunąć tę notatkę?';

  @override
  String get notesHoldHint =>
      'Przytrzymaj notatkę, żeby ją skopiować albo usunąć.';

  @override
  String get notesMenu => 'Menu notatek';

  @override
  String get notesDeleteAll => 'Usuń wszystkie notatki';

  @override
  String get notesDeleteAllTitle => 'Usunąć wszystkie notatki?';

  @override
  String get notesDeleteAllLine =>
      'Każda notatka na tym telefonie zniknie na dobre.';

  @override
  String get notesDeleteAllLineDesk =>
      'Każda notatka na tym komputerze zniknie na dobre.';

  @override
  String get notesDeleteAllYes => 'Usuń wszystkie';

  @override
  String get notesThisWeek => 'W tym tygodniu';

  @override
  String get notesShowMore => 'Pokaż więcej';

  @override
  String get notesShowLess => 'Pokaż mniej';

  @override
  String get notesGoneFromThisPhone => 'Zniknie z tego telefonu na dobre.';

  @override
  String get notesGoneFromThisPhoneDesk => 'Zniknie z tego komputera na dobre.';

  @override
  String get notesNoteToSelf => 'Notatka dla siebie';

  @override
  String get notesOnlyOnThisPhone => 'Tylko na tym telefonie';

  @override
  String get notesOnlyOnThisPhoneDesk => 'Tylko na tym komputerze';

  @override
  String get notesAQuietPlace => 'Spokojne miejsce';

  @override
  String get notesJotAnythingDownIt =>
      'Zanotuj cokolwiek. Zostaje na tym telefonie i nigdy go nie opuszcza.';

  @override
  String get notesJotAnythingDownItDesk =>
      'Zanotuj cokolwiek. Zostaje na tym komputerze i nigdy go nie opuszcza.';

  @override
  String get notesJotSomethingDown => 'Zanotuj coś…';

  @override
  String get notesExportNotes => 'Eksportuj notatki';

  @override
  String get notesExport => 'Eksportuj';

  @override
  String get notesExportWorking => 'Eksportuję…';

  @override
  String notesExportCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString notatki, od najstarszej.',
      many: '$countString notatek, od najstarszej.',
      few: '$countString notatki, od najstarszej.',
      one: 'Jedna notatka, od najstarszej.',
    );
    return '$_temp0';
  }

  @override
  String get notesExportZip =>
      'Zdjęcia i wiadomości głosowe trafią razem z nimi do pliku zip.';

  @override
  String get notesExportText => 'Zwykły tekst';

  @override
  String get notesExportTextLine => 'Plik .txt, który otworzy się wszędzie';

  @override
  String get notesExportMarkdown => 'Markdown';

  @override
  String get notesExportMarkdownLine =>
      'Plik .md z nagłówkami, do aplikacji z notatkami';

  @override
  String get notesExportLock => 'Zablokuj hasłem';

  @override
  String get notesExportLockLine =>
      'Otwórz go w Narzędziach przez „Otwórz zablokowany plik” albo programem age na komputerze';

  @override
  String get notesExportPlainTitle => 'Eksportować bez hasła?';

  @override
  String get notesExportPlainLine =>
      'Każdy, kto dostanie ten plik, może go przeczytać.';

  @override
  String get notesExportPlainYes => 'Eksportuj bez hasła';

  @override
  String get notesExportKeepLock => 'Zostaw hasło';

  @override
  String get notesExportNotSaved =>
      'Notatki nie zostały zapisane. Plik nadal tu jest.';

  @override
  String get notesExportGone =>
      'Plik został usunięty, gdy Kryfo zostało zablokowane. Wyeksportuj ponownie, żeby utworzyć nowy.';

  @override
  String get notesExportHoldsInstaller =>
      'Ten eksport zawiera instalator aplikacji, więc nie można go udostępnić. Zapisz go zamiast tego na telefonie.';

  @override
  String get notesExportHoldsInstallerDesk =>
      'Ten eksport zawiera instalator aplikacji, więc nie można go udostępnić. Zapisz go zamiast tego na tym komputerze.';

  @override
  String get notesExportSaved => 'Notatki zapisane';

  @override
  String notesExportSavedIn(String place) {
    return 'Notatki zapisane w $place';
  }

  @override
  String get notesExportSavedUnchecked =>
      'Notatki zapisane, ale Kryfo nie mogło sprawdzić pliku';

  @override
  String get notesExportFailed =>
      'Nie udało się wyeksportować notatek. Nic nie zostało zapisane.';

  @override
  String get notesExportTooLarge =>
      'Za duże do eksportu. Zdjęcia i wiadomości głosowe zajmują 4 GB lub więcej.';

  @override
  String get notesExportSubject => 'Notatki Kryfo';

  @override
  String get onboardingPrivateByDefault => 'Prywatnie od początku';

  @override
  String get onboardingPrivateMessaging =>
      'Prywatne wiadomości,\n*bez haczyka*.';

  @override
  String get onboardingYourNameIsThree =>
      '*Twoje imię to trzy słowa.*\nBez telefonu, bez maila, bez książki adresowej.';

  @override
  String get onboardingNobodyGetsInUnless =>
      '*Nikt nie wejdzie bez twojej zgody.*\nBez publicznej @nazwy nikt cię nie wyszuka.\nObcy mogą tylko zapukać.';

  @override
  String get onboardingTheFirstConnectionTakes =>
      '*Pierwsze połączenie trwa minutę.*\nKryfo najpierw buduje prywatną trasę. Potem jest szybko.';

  @override
  String get onboardingBegin => 'Zaczynamy';

  @override
  String get onboardingHaveABackupRestore => 'Masz kopię zapasową? Przywróć →';

  @override
  String get onboardingKryfoIsOpenSource => 'Kryfo ma otwarty kod źródłowy';

  @override
  String get onboardingYourKryfoId => 'Twoje imię';

  @override
  String get onboardingGeneratedFromAKey =>
      'Utworzone z klucza, który istnieje tylko na tym telefonie.\n*Nikt inny nie ma tych słów.*';

  @override
  String get onboardingGeneratedFromAKeyDesk =>
      'Utworzone z klucza, który istnieje tylko na tym komputerze.\n*Nikt inny nie ma tych słów.*';

  @override
  String get onboardingTryAnother => 'Spróbuj innego';

  @override
  String get onboardingUseThisName => 'Użyj tej nazwy →';

  @override
  String get onboardingThreeWords => 'Trzy słowa. *Tylko twoje.*';

  @override
  String get onboardingContinue => 'Dalej →';

  @override
  String get onboardingKryfoBuildsAPrivateRouteBefore =>
      'Kryfo buduje prywatną trasę, zanim cokolwiek wyśle. Gdy jesteś offline, wiadomości czekają i dotrą, gdy wrócisz.';

  @override
  String get onboardingYourIdentityLivesOn =>
      'Twoja tożsamość żyje na tym telefonie.\nZrób kopię zapasową w Ustawieniach, kiedy zechcesz.';

  @override
  String get onboardingYourIdentityLivesOnDesk =>
      'Twoja tożsamość żyje na tym komputerze.\nZrób kopię zapasową w Ustawieniach, kiedy zechcesz.';

  @override
  String get onboardingSilentAndAtThe =>
      'Ciche, na samym dole listy powiadomień';

  @override
  String get onboardingItNeverBuzzesTurn =>
      'Nigdy nie wibruje.\nWyłączysz je, a wiadomości poczekają, aż otworzysz Kryfo.';

  @override
  String get onboardingGotIt => 'Jasne →';

  @override
  String get onboardingEveryWayToAdd => 'Wszystkie sposoby dodawania';

  @override
  String get onboardingShowYourCodeSend =>
      'Pokaż swój kod, udostępnij link albo wpisz @nazwę tej osoby.';

  @override
  String get onboardingScanTheirs => 'Zeskanuj czyjś kod';

  @override
  String get onboardingPointTheCameraAt => 'Skieruj aparat na kod tej osoby';

  @override
  String get onboardingNotNowAddPeople => 'Nie teraz · dodam ludzi później';

  @override
  String get openLockedOpened => 'Otwarty';

  @override
  String get openLockedOpenALockedFile => 'Otwórz zablokowany plik';

  @override
  String get openLockedCheckingThePassword => 'Sprawdzam hasło';

  @override
  String get openLockedOpening => 'Otwieram';

  @override
  String get openLockedFile => 'Plik';

  @override
  String get openLockedOpenFile => 'Otwórz plik';

  @override
  String get openLockedTypeThePassword => 'Wpisz hasło.';

  @override
  String get openLockedItOpensOnThis => 'Otwiera się na tym telefonie.';

  @override
  String get openLockedItOpensOnThisDesk => 'Otwiera się na tym komputerze.';

  @override
  String get openLockedLockedFile => 'Zablokowany plik';

  @override
  String openLockedFromFiles(Object prettySize) {
    return '$prettySize · z Plików';
  }

  @override
  String get openLockedFromFiles2 => 'Z Plików';

  @override
  String get openLockedPassword => 'Hasło';

  @override
  String get openLockedThePasswordIsChecked =>
      'Najpierw sprawdzane jest hasło. Dopiero potem Kryfo pyta, gdzie zapisać otwarty plik, a następnie trafia on bezpośrednio w tamto miejsce.';

  @override
  String get openLockedOpened2 => 'Otwarty.';

  @override
  String get openLockedSavedWhereYouChose => 'Zapisano tam, gdzie wybrano.';

  @override
  String get pairCodePairingCode => 'Kod parowania';

  @override
  String get pairCodeShowACode => 'Pokaż kod';

  @override
  String get pairCodeEnterOne => 'Wpisz kod';

  @override
  String get pairCodeLooking => 'Szukam…';

  @override
  String get pairCodeNothingThereYetTrying => 'Jeszcze nic · próbuję ponownie';

  @override
  String get pairCodeNothingAtThatCode =>
      'Pod tym kodem nic nie ma. Mógł już spłonąć albo ta osoba jeszcze go nie udostępniła.';

  @override
  String get pairCodeUnreached =>
      'Nie udało się dotrzeć do przekaźników. Spróbuj za chwilę.';

  @override
  String get fastRoomsWaitForTor =>
      'Pokoje, kody parowania i pierwsze kontakty zawsze idą przez Tor, także w trybie Szybki. Działają, gdy tylko Tor się połączy.';

  @override
  String get pairCodeFailed => 'Nie zadziałało. Spróbuj ponownie.';

  @override
  String get pairCodeAddThem => 'Dodaj';

  @override
  String get pairCodeKeyNumber => 'Numer klucza';

  @override
  String get pairCodeNotAdded => 'Nie dodano. Poproś o nowy kod.';

  @override
  String get pairCodeEightDigits => 'Osiem cyfr';

  @override
  String get pairCodeTypeTheEightDigits =>
      'Wpisz osiem cyfr, które ta osoba ci przeczytała.';

  @override
  String get pairCodeOldCode =>
      'Ten kod pochodzi ze starszego Kryfo. Oba telefony potrzebują Kryfo 0.6 lub nowszego.';

  @override
  String get pairCodeOldCodeDesk =>
      'Ten kod pochodzi ze starszego Kryfo. Oba urządzenia potrzebują Kryfo 0.6 lub nowszego.';

  @override
  String get pairCodeBothNeed06 =>
      'Oba telefony potrzebują Kryfo 0.6 lub nowszego.';

  @override
  String get pairCodeBothNeed06Desk =>
      'Oba urządzenia potrzebują Kryfo 0.6 lub nowszego.';

  @override
  String get pairCodeWaitingForThem => 'Czekam na tę osobę…';

  @override
  String get pairCodeStillWaiting =>
      'Wciąż czekam. Jeśli ekran tej osoby pokazuje, że wpisano zły kod, sprawdźcie razem cyfry.';

  @override
  String get pairCodeUnanswered =>
      'Nie przyszła odpowiedź. Sprawdź kod razem z tą osobą i wpisz go ponownie.';

  @override
  String get pairCodeTooManyTries =>
      'Ten kod wypróbowano trzy razy. Poproś o nowy.';

  @override
  String get pairCodeRanOut => 'Ten kod wygasł. Poproś o nowy.';

  @override
  String get pairCodeMatched => 'Kod się zgadza. Dodać się nawzajem?';

  @override
  String get pairCodeNotThem => 'To nie ta osoba';

  @override
  String get pairCodePanelReadEightDigitsOut =>
      'Przeczytaj na głos osiem cyfr, a dodacie się nawzajem. Nic więcej nie musi przechodzić z rąk do rąk.';

  @override
  String get pairCodePanelOrMakeACode => 'Albo zrób kod do przeczytania';

  @override
  String get pairCodePanelTheyOpenKryfoEight =>
      'Ta osoba otwiera Kryfo, stuka Dodaj, wybiera kod parowania i wpisuje te osiem cyfr. Dla następnej osoby zrób nowy.';

  @override
  String get pairCodePanelWrongTyped =>
      'Wpisano zły kod. Przeczytaj go jeszcze raz, powoli.';

  @override
  String get pairCodePanelThreeWrong =>
      'Zły kod wpisano trzy razy, więc ten kod przestał działać. Zrób nowy.';

  @override
  String get pairCodePanelNotAdded =>
      'Nie dodano. Zrób nowy kod, gdy ta osoba będzie gotowa.';

  @override
  String get panicSetupThoseWereDifferentFrom => 'Były różne. Od nowa.';

  @override
  String get panicSetupOnceMore => 'Jeszcze raz';

  @override
  String get panicSetupTheSameFourDigits => 'Te same cyfry jeszcze raz';

  @override
  String get photoKnowsEverythingInside => 'Wszystko w środku';

  @override
  String get photoKnowsVideo => 'Wideo';

  @override
  String get photoKnowsPhoto => 'Zdjęcie';

  @override
  String get photoKnowsVideoCleaner => 'Czyszczenie filmów';

  @override
  String get photoKnowsPhotoCleaner => 'Czyszczenie zdjęć';

  @override
  String get photoKnowsRemoveAllOfIt => 'Usuń to wszystko';

  @override
  String get photoKnowsKeepItAsIt => 'Zostaw bez zmian';

  @override
  String get photoKnowsReadingTheFile => 'Czytam plik';

  @override
  String photoKnowsOf(Object prettySize, Object prettySize2) {
    return '$prettySize z $prettySize2';
  }

  @override
  String get photoKnowsEverythingStaysOnThis =>
      'Wszystko zostaje na tym telefonie.';

  @override
  String get photoKnowsEverythingStaysOnThisDesk =>
      'Wszystko zostaje na tym komputerze.';

  @override
  String photoKnowsMapWithAPin(Object place) {
    return 'Mapa z pinezką. $place';
  }

  @override
  String get photoKnowsDrawnOffline => 'NARYSOWANE OFFLINE';

  @override
  String photoKnowsShowEverything(Object title) {
    return '$title. Pokaż wszystko';
  }

  @override
  String get pinsAppLock => 'Blokada aplikacji';

  @override
  String get pinsYourPin => 'Twój PIN';

  @override
  String get commonOn => 'Wł.';

  @override
  String get commonOff => 'Wył.';

  @override
  String get pinsOpensKryfoFourDigits =>
      'Otwiera Kryfo. Pyta o niego, gdy aplikacja wraca na wierzch.';

  @override
  String get pinsChangePin => 'Zmień PIN';

  @override
  String get pinsSetAPin => 'Ustaw PIN';

  @override
  String get pinsTurnOff => 'Wyłącz';

  @override
  String get pinsTurnOffTheApp => 'Wyłączyć blokadę aplikacji?';

  @override
  String get pinsThePinGoesAnd =>
      'PIN zniknie, a razem z nim PIN wymazania i wszystkie ukryte czaty. Każdy, kto ma twój telefon, otworzy Kryfo jako ty.';

  @override
  String get pinsThePinGoesAndDesk =>
      'PIN zniknie, a razem z nim PIN wymazania i wszystkie ukryte czaty. Każdy przy twoim komputerze otworzy Kryfo jako ty.';

  @override
  String get pinsUnlockWithFingerprint => 'Odblokowuj odciskiem palca';

  @override
  String get pinsFingerOpensDecoy =>
      'Wyłączone, gdy ustawiony jest PIN przynęty: palec otwiera tylko przynętę.';

  @override
  String get pinsWipePin => 'PIN wymazania';

  @override
  String get pinsNeedsAPinFirst => 'Najpierw potrzebny jest PIN';

  @override
  String get pinsSet => 'Ustaw';

  @override
  String get pinsChangeWipePin => 'Zmień PIN wymazania';

  @override
  String get pinsRemove => 'Usuń';

  @override
  String get pinsRemoveTheWipePin => 'Usunąć PIN wymazania?';

  @override
  String get pinsTheLockScreenKeeps =>
      'Ekran blokady zachowuje twój PIN. PIN wymazania przestaje cokolwiek robić.';

  @override
  String profileCopied(Object what) {
    return 'Skopiowano: $what';
  }

  @override
  String get profileProfile => 'Profil';

  @override
  String get profileKryfoId => 'Twoje imię';

  @override
  String get profileOnionAddress => 'Adres onion';

  @override
  String get profileSupporterBadge => 'Odznaka wspierającego';

  @override
  String profileYouAreAThank(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter': 'Wspierasz Kryfo. Dziękuję.',
      'patron': 'Masz odznakę mecenasa. Dziękuję.',
      'guardian': 'Masz odznakę strażnika. Dziękuję.',
      'other': 'Wspierasz Kryfo. Dziękuję.',
    });
    return '$_temp0';
  }

  @override
  String get profileShowMyBadge => 'Pokaż moją odznakę';

  @override
  String get profileOnMyOwnScreens => 'Na moich ekranach';

  @override
  String get profileLetContactsSeeIt => 'Pozwól kontaktom ją widzieć';

  @override
  String get profileOffByDefault => 'Domyślnie wyłączone';

  @override
  String get profileShareConnect => 'Udostępnij i połącz';

  @override
  String get profileMyKryfoCode => 'Mój kod Kryfo';

  @override
  String get profileAddContact => 'Dodaj kontakt';

  @override
  String get profileGiveAgain => 'Wesprzyj ponownie';

  @override
  String get profileSupportKryfo => 'Wesprzyj Kryfo';

  @override
  String get profileKryfoRunsOnWhat =>
      'Kryfo działa dzięki temu, co dają ludzie';

  @override
  String get profileKeepKryfoIndependent => 'Niech Kryfo pozostanie niezależne';

  @override
  String get qrLink => 'Link';

  @override
  String get qrYourLinkAsTyped =>
      'Twój link tak, jak go wpisano · bez śledzącego przekierowania';

  @override
  String get qrText => 'Tekst';

  @override
  String get qrStaysInTheCode =>
      'Zostaje w kodzie · żaden serwer go nie trzyma';

  @override
  String get qrWiFi => 'Wi-Fi';

  @override
  String get qrMadeOnThisPhone =>
      'Zrobione na tym telefonie · żadna strona nie widziała hasła';

  @override
  String get qrMadeOnThisPhoneDesk =>
      'Zrobione na tym komputerze · żadna strona nie widziała hasła';

  @override
  String get qrNetworkName => 'Nazwa sieci';

  @override
  String get qrPassword => 'Hasło';

  @override
  String get qrContact => 'Kontakt';

  @override
  String get qrOnlyWhatYouType =>
      'Tylko to, co wpiszesz · nic z twoich kontaktów';

  @override
  String get qrName => 'Imię';

  @override
  String get qrPhone => 'Telefon';

  @override
  String get qrEmail => 'E-mail';

  @override
  String get qrOpensTheirMailApp =>
      'Otwiera aplikację pocztową odbiorcy · nic nie jest stąd wysyłane';

  @override
  String get qrTo => 'Do';

  @override
  String get qrSubject => 'Temat';

  @override
  String get qrANumberNothingElse => 'Numer · nic więcej';

  @override
  String get qrNumber => 'Numer';

  @override
  String get qrSms => 'SMS';

  @override
  String get qrOpensTheirMessagesApp =>
      'Otwiera aplikację wiadomości odbiorcy · nic nie jest stąd wysyłane';

  @override
  String get qrMessage => 'Wiadomość';

  @override
  String get qrLocation => 'Lokalizacja';

  @override
  String get qrCoordinatesOnlyNoMap =>
      'Tylko współrzędne · bez pytania żadnej usługi map';

  @override
  String get qrLatitude => 'Szerokość geograficzna';

  @override
  String get qrLongitude => 'Długość geograficzna';

  @override
  String get qrBitcoin => 'Bitcoin';

  @override
  String get qrAddressAndAmountNo =>
      'Adres i kwota · bez pośredniczącej strony płatności';

  @override
  String get qrAddress => 'Adres';

  @override
  String get qrAmountInBtc => 'Kwota w BTC';

  @override
  String get qrInk => 'Atrament';

  @override
  String get qrAmber => 'Bursztyn';

  @override
  String get qrViolet => 'Fiolet';

  @override
  String get qrCouldNotDrawThe => 'Nie udało się narysować obrazka.';

  @override
  String get qrSavedToYourGallery => 'Zapisano w galerii';

  @override
  String get qrCouldNotSaveIt =>
      'Nie udało się zapisać. Sprawdź, czy telefon ma miejsce.';

  @override
  String get qrCouldNotSaveItDesk =>
      'Nie udało się zapisać. Sprawdź, czy komputer ma miejsce.';

  @override
  String get qrNoAppOnThis =>
      'Żadna aplikacja na tym telefonie nie przyjęła obrazka.';

  @override
  String get qrTooMuchForOne => 'Za dużo na jeden kod. Skróć to.';

  @override
  String get qrThisIsALot =>
      'To dużo jak na jeden kod. Starsze aparaty mogą go nie odczytać.';

  @override
  String get qrPrivateQrCode => 'Prywatny kod QR';

  @override
  String get qrColour => 'Kolor';

  @override
  String get qrCopiedItLeavesThe => 'Skopiowano. Zniknie ze schowka za minutę';

  @override
  String get qrSecurity => 'Zabezpieczenie';

  @override
  String get qrNone => 'Brak';

  @override
  String get qrSaveImage => 'Zapisz obrazek';

  @override
  String qrColour2(Object name) {
    return 'Kolor $name';
  }

  @override
  String get qrTypeBelowAndThe => 'Pisz poniżej, a\nkod narysuje się sam';

  @override
  String get qrQrCode => 'Kod QR';

  @override
  String get qrHidePassword => 'Ukryj hasło';

  @override
  String get qrShowPassword => 'Pokaż hasło';

  @override
  String get qrCopyPassword => 'Kopiuj hasło';

  @override
  String get requestsSentAnAttachment => 'Wysłano załącznik';

  @override
  String get requestsWantsToConnect => 'Chce się połączyć';

  @override
  String get requestsAccepted => 'Zaakceptowano';

  @override
  String requestsBlock(Object id) {
    return 'Zablokować $id?';
  }

  @override
  String get requestsNothingMoreFromThem =>
      'Nic więcej od tej osoby do ciebie nie dotrze. Prośba i jej wiadomości znikną.';

  @override
  String get requestsRequests => 'Prośby';

  @override
  String get requestsNoRequests => 'Brak próśb';

  @override
  String get requestsMessagesFromPeopleYou =>
      'Wiadomości od osób, których nie masz w kontaktach, najpierw trafiają tutaj.';

  @override
  String get commonAccept => 'Akceptuj';

  @override
  String get requestsDecline => 'Odrzuć';

  @override
  String get restoreThatFileIsNot => 'Ten plik nie jest kopią zapasową Kryfo';

  @override
  String get restoreThisFileIsDamaged =>
      'Ten plik jest uszkodzony i nie da się go odczytać';

  @override
  String get restoreTypeThePassphraseThe =>
      'Wpisz hasło, z którym utworzono plik';

  @override
  String get restoreReplaceTheAccountOn => 'Zastąpić konto na tym telefonie?';

  @override
  String get restoreReplaceTheAccountOnDesk =>
      'Zastąpić konto na tym komputerze?';

  @override
  String get restoreWhatIsHereNow =>
      'To, co jest tu teraz, czyli tożsamość, kontakty i wiadomości, zniknie. Plik zajmie ich miejsce. Tego nie da się cofnąć.';

  @override
  String get restoreReplaceIt => 'Zastąp';

  @override
  String restoreCouldNotBeReleased(Object mine) {
    return 'Nie udało się zwolnić @$mine';
  }

  @override
  String restoreTheRegistryDidNot(Object mine) {
    return 'Rejestr nie odpowiedział. Jeśli przejdziesz dalej, @$mine będzie wskazywać tożsamość, którą ten telefon zaraz straci. Każdy, kto ją doda, będzie pisać do nikogo, a nazwy nie da się zająć ponownie. Lepiej połącz się z siecią i spróbuj jeszcze raz.';
  }

  @override
  String restoreTheRegistryDidNotDesk(Object mine) {
    return 'Rejestr nie odpowiedział. Jeśli przejdziesz dalej, @$mine będzie wskazywać tożsamość, którą ten komputer zaraz straci. Każdy, kto ją doda, będzie pisać do nikogo, a nazwy nie da się zająć ponownie. Lepiej połącz się z siecią i spróbuj jeszcze raz.';
  }

  @override
  String get restoreRestoreAnyway => 'Przywróć mimo to';

  @override
  String get restoreNotYet => 'Jeszcze nie';

  @override
  String get restoreRestored => 'Przywrócono';

  @override
  String restoreKryfoWillCloseNow(Object haloId) {
    return 'Kryfo się teraz zamknie. Stuknij ikonę, żeby otworzyć je ponownie jako $haloId.';
  }

  @override
  String restoreKryfoWillCloseNowDesk(Object haloId) {
    return 'Kryfo się teraz zamknie. Uruchom je ponownie, żeby otworzyć jako $haloId.';
  }

  @override
  String get restorePrivacyKept =>
      'Twoje ustawienia prywatności wracają razem z kopią. PIN-y nigdy nie podróżują: ustaw je ponownie w Ustawieniach.';

  @override
  String get restoreCheckProtections =>
      'Ustawienia nie są zapisywane w kopii. Gdy Kryfo się otworzy, sprawdź twoje zabezpieczenia w Ustawieniach.';

  @override
  String get restoreReopenKryfo => 'Otwórz Kryfo ponownie';

  @override
  String get restoreTheRestoreDidNot =>
      'Przywracanie się nie zakończyło. Nic nie zostało zmienione';

  @override
  String get restoreKryfoClosesRestoreAgain =>
      'Część tego, co tu było, została już zastąpiona. Kryfo się teraz zamknie. Otwórz je ponownie i przywróć plik jeszcze raz.';

  @override
  String get restoreThisIdentity => 'ta tożsamość';

  @override
  String get restoreMoveYourKryfoHere => 'Przenieś tu swoje Kryfo';

  @override
  String restoreThisBackupIsRestoring(Object name) {
    return 'Ta kopia to $name. Przywrócenie przeniesie tę tożsamość na to urządzenie.';
  }

  @override
  String restoreThisBackupMadeOn(Object name, Object date, Object time) {
    return 'Ta kopia to $name, utworzona $date o $time. Przywrócenie przeniesie tę tożsamość na to urządzenie.';
  }

  @override
  String restoreItHoldsOfPhotos(Object mb) {
    return 'Zawiera $mb zdjęć, wiadomości głosowych i plików. To może potrwać kilka minut. Nie zamykaj aplikacji.';
  }

  @override
  String get restoreWhatFollows => 'Co przejdzie';

  @override
  String get restoreYourNameYourCode => 'Twoje imię, kod i każdy kontakt.';

  @override
  String get restoreEveryConversationBackTo =>
      'Każda rozmowa, od samego początku.';

  @override
  String get restoreYourPhotosVoiceNotes =>
      'Twoje zdjęcia, wiadomości głosowe i pliki.';

  @override
  String restoreYourPhotosVoiceNotesCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Twoje zdjęcia, wiadomości głosowe i pliki · $countString.',
      many: 'Twoje zdjęcia, wiadomości głosowe i pliki · $countString.',
      few: 'Twoje zdjęcia, wiadomości głosowe i pliki · $countString.',
      one: 'Twoje zdjęcie, wiadomość głosowa i plik · $countString.',
    );
    return '$_temp0';
  }

  @override
  String get restoreYourOnionAddressSo =>
      'Twój adres onion, żeby osoby, które łączą się z tobą bezpośrednio, nadal cię znajdowały.';

  @override
  String get restoreAnythingSentToYou =>
      'Wszystko, co wysłano do ciebie, gdy stary telefon był wyłączony, przez czternaście dni od wysłania.';

  @override
  String get restoreAnythingSentToYouDesk =>
      'Wszystko, co wysłano do ciebie, gdy stare urządzenie było wyłączone, przez czternaście dni od wysłania.';

  @override
  String get restoreYourSupporterBadgeIf =>
      'Twoja odznaka wspierającego, jeśli ją masz.';

  @override
  String get restoreWhatDoesnT => 'Co nie przejdzie';

  @override
  String get restoreTheOldPhoneStops =>
      'Stary telefon przestaje odbierać w chwili, gdy wyślesz cokolwiek stąd. Pierwsza wiadomość wysłana z tego urządzenia to ostatnia, którą stary telefon może śledzić, a wszystko, co dotrze do niego później, będzie tam nieczytelne i nie będzie też czekać tutaj.';

  @override
  String get restoreTheOldPhoneStopsDesk =>
      'Stare urządzenie przestaje odbierać w chwili, gdy wyślesz cokolwiek stąd. Pierwsza wiadomość wysłana z tego komputera to ostatnia, którą stare urządzenie może śledzić, a wszystko, co dotrze do niego później, będzie tam nieczytelne i nie będzie też czekać tutaj.';

  @override
  String get restoreIfThePhoneThis =>
      'Jeśli telefon, z którego pochodzi ten plik, jest nadal używany, przestań używać na nim Kryfo, zanim przejdziesz dalej. Dwa telefony na jednym Kryfo gubią wiadomości na obu.';

  @override
  String get restoreIfThePhoneThisDesk =>
      'Jeśli urządzenie, z którego pochodzi ten plik, jest nadal używane, przestań używać na nim Kryfo, zanim przejdziesz dalej. Dwa urządzenia na jednym Kryfo gubią wiadomości na obu.';

  @override
  String get restoreNotificationsNeedSettingUp =>
      'Powiadomienia trzeba ponownie ustawić na tym urządzeniu.';

  @override
  String get restoreDeletedComeBack =>
      'Czaty usunięte po zrobieniu tej kopii wrócą razem z nią, a te kontakty mogą zobaczyć, że Kryfo zostało u ciebie skonfigurowane od nowa.';

  @override
  String get restoreMoveItHere => 'Przenieś tutaj';

  @override
  String get restoreNotNow => 'Nie teraz';

  @override
  String get restoreRestore => 'Przywróć';

  @override
  String get restoreFromABackupFile => 'Z pliku kopii zapasowej';

  @override
  String get restoreABackupBringsBack =>
      'Kopia zapasowa przywraca twoją tożsamość, kontakty i wiadomości, które były na telefonie w chwili utworzenia pliku. Tego, co powiedziano później, w niej nie ma.';

  @override
  String get restoreABackupBringsBackDesk =>
      'Kopia zapasowa przywraca twoją tożsamość, kontakty i wiadomości, które były na urządzeniu w chwili utworzenia pliku. Tego, co powiedziano później, w niej nie ma.';

  @override
  String get restoreTheFile => 'Plik';

  @override
  String get restorePickTheBackupFile => 'Wybierz plik kopii zapasowej';

  @override
  String get restoreThePassphrase => 'Hasło';

  @override
  String get restoreTheOneTheFile => 'To, z którym utworzono plik';

  @override
  String get restoreWhatComesBack => 'Co wróci';

  @override
  String get restoreChecking => 'Sprawdzam…';

  @override
  String get restoreCheckTheFile => 'Sprawdź plik';

  @override
  String get restoreReleasingYourHandle => 'Zwalniam twoją nazwę użytkownika…';

  @override
  String restoreMoving(Object progress) {
    return 'Przenoszę… $progress';
  }

  @override
  String get restoreRestoring => 'Przywracam…';

  @override
  String get restoreNotThisOne => 'Nie ten';

  @override
  String get restoreStopRestore => 'Przerwij przywracanie';

  @override
  String get restoreDateUnknown => 'Data nieznana';

  @override
  String get restoreAnIdentity => 'Tożsamość';

  @override
  String get restoreMessagesSentOrReceived =>
      'Wiadomości wysłanych lub odebranych po tej dacie nie ma w tym pliku.';

  @override
  String restoreGb(Object bytes) {
    return '$bytes GB';
  }

  @override
  String restoreMb(Object bytes) {
    return '$bytes MB';
  }

  @override
  String get roomCreateCouldNotCreateThe => 'Nie udało się utworzyć pokoju';

  @override
  String get roomCreateBurnerRoom => 'Pokój jednorazowy';

  @override
  String get roomCreateARoomThatEnds =>
      'Pokój, który się kończy. Każdy dołącza z kluczem zrobionym dla niego, a gdy pokój się kończy, na żadnym telefonie nic nie zostaje.';

  @override
  String get roomCreateARoomThatEndsDesk =>
      'Pokój, który się kończy. Każdy dołącza z kluczem zrobionym dla niego, a gdy pokój się kończy, na żadnym urządzeniu nic nie zostaje.';

  @override
  String get roomCreateRoomName => 'Nazwa pokoju';

  @override
  String get roomCreateEndsAfter => 'Kończy się po';

  @override
  String get roomCreateMemberCap => 'Limit osób';

  @override
  String roomCreateNoOnePastThe(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Nikt poza pierwszymi $countString osobami',
      many: 'Nikt poza pierwszymi $countString osobami',
      few: 'Nikt poza pierwszymi $countString osobami',
      one: 'Nikt poza pierwszą $countString osobą',
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
      other: 'Wył. Każdy z linkiem, do $countString osoby',
      many: 'Wył. Każdy z linkiem, do $countString osób',
      few: 'Wył. Każdy z linkiem, do $countString osób',
      one: 'Wył. Każdy z linkiem, do $countString osoby',
    );
    return '$_temp0';
  }

  @override
  String roomCreateThisRoomAndEverything(Object expiryWords) {
    return 'Ten pokój i wszystko w nim zniknie za $expiryWords';
  }

  @override
  String get roomCreateCreating => 'Tworzę...';

  @override
  String get roomCreateCreateRoom => 'Utwórz pokój';

  @override
  String get roomLinkSendTheRoomTo => 'Wyślij pokój do';

  @override
  String get roomLinkTheyWillKnowThis =>
      'Będą wiedzieć, że ten pokój pochodzi od ciebie. W środku każdy ma taki sam klucz jak inni.';

  @override
  String get roomLinkNoContactsYet => 'Jeszcze brak kontaktów';

  @override
  String roomLinkEndsIn(Object time) {
    return 'Kończy się za $time';
  }

  @override
  String get roomLinkAnyoneWithThisCan =>
      'Każdy, kto to ma, może dołączyć, dopóki pokój trwa. Wchodzi z kluczem zrobionym dla tego pokoju i nie widzi niczego, co wysłano przed jego wejściem.';

  @override
  String get roomLinkRoomLinkCopied => 'Link do pokoju skopiowany';

  @override
  String get roomLinkSendToAContact => 'Wyślij do kontaktu';

  @override
  String get roomLinkCopyRoomLink => 'Kopiuj link do pokoju';

  @override
  String get savedVoiceNote => 'Wiadomość głosowa';

  @override
  String get savedPhoto => 'Zdjęcie';

  @override
  String get savedSaved => 'Zapisane';

  @override
  String get savedNothingSavedYet => 'Nic jeszcze nie zapisano';

  @override
  String get savedChatGone => 'Tego czatu nie ma już na tym telefonie';

  @override
  String get savedChatGoneDesk => 'Tego czatu nie ma już na tym komputerze';

  @override
  String get savedLongPressAnyMessage =>
      'Przytrzymaj dowolną wiadomość i stuknij Zapisz, żeby ją tu zachować.';

  @override
  String get savedViewInChat => 'Zobacz w czacie';

  @override
  String get savedPhoto2 => 'Zdjęcie';

  @override
  String get scanThatSNotA => 'To nie jest kod QR Kryfo · celuj dalej';

  @override
  String get scanScanAKryfoQr => 'Zeskanuj kod QR Kryfo';

  @override
  String get scanFlash => 'Latarka';

  @override
  String get scanPointAtAKryfo =>
      'Skieruj na kod QR Kryfo · nic nie opuszcza twojego telefonu';

  @override
  String get seenWhatWeCanSee => 'Co możemy zobaczyć';

  @override
  String get seenEveryMessengerClaimsPrivacy =>
      'Oto lista według trasy, łącznie ze słabymi punktami. Stuknij wiersz, żeby zobaczyć dlaczego.';

  @override
  String get seenHonestAboutTheLast =>
      'Do tego, co w ostatnich wierszach, służą blokada aplikacji, PIN wymazania i szyfrowane przechowywanie, a żadne narzędzie nie ochroni cię przed kimś, kto trzyma twój odblokowany telefon. Pełny model zagrożeń jest w THREAT_MODEL.md w repozytorium, napisany według LINDDUN. Kod jest otwarty, więc wszystko to możesz sprawdzić.';

  @override
  String get seenHonestAboutTheLastDesk =>
      'Do tego, co w ostatnich wierszach, służą blokada aplikacji, PIN wymazania i szyfrowane przechowywanie, a żadne narzędzie nie ochroni cię przed kimś, kto siedzi przy twoim odblokowanym komputerze. Pełny model zagrożeń jest w THREAT_MODEL.md w repozytorium, napisany według LINDDUN. Kod jest otwarty, więc wszystko to możesz sprawdzić.';

  @override
  String get seenHidden => 'Ukryte';

  @override
  String get seenNever => 'Nigdy';

  @override
  String get seenOnDevice => 'Na urządzeniu';

  @override
  String get seenYours => 'Twoje';

  @override
  String get seenUnaudited => 'Bez audytu';

  @override
  String get seenWhoYouTalkTo => 'Z kim rozmawiasz';

  @override
  String get seenEachConversationGetsIts =>
      'Każda rozmowa ma własny adres, wyliczony z obu kluczy. Przekaźnik widzi niepowiązane skrytki, a nie parę ludzi. W trybie Szybki nasze serwery widzą twój adres IP przy skrytkach, których używasz, a gdy obie osoby w czacie używają trybu Szybki, widzą też, że dwa adresy IP dzielą jedną skrytkę.';

  @override
  String get seenWhatYouSay => 'Co mówisz';

  @override
  String get seenEndToEndEncrypted =>
      'Szyfrowane end-to-end przez double ratchet z Signal, a potem zapieczętowane ponownie w gift wrap. Nie możemy tego przeczytać.';

  @override
  String get seenYourIpAddress => 'Twój adres IP';

  @override
  String get seenYourContactGraph => 'Twoja sieć kontaktów';

  @override
  String get seenKryfoDoesNotScan =>
      'Kryfo nie przeszukuje twoich kontaktów. Nie ma tu numeru telefonu, który mógłby wyciec. W trybie Szybki nasze serwery mogłyby częściowo to odtworzyć z tego, które adresy IP dzielą skrytki. Nie zapisują tego.';

  @override
  String get seenIntroducer => 'Osoba przedstawiająca';

  @override
  String get seenWhenAContactIntroduces =>
      'Gdy kontakt przedstawia cię komuś, ten kontakt wie o waszym nowym połączeniu. Nikt inny. Przekaźnik widzi zaszyfrowane dane, a żaden serwer nigdy nie widzi sieci kontaktów.';

  @override
  String get seenTheScamShield => 'Ochrona przed oszustwami';

  @override
  String get seenScamShieldRequestsOnly =>
      'Działa na twoim telefonie według reguł wbudowanych w aplikację. Bez sieci, bez pobierania list. Czyta tylko prośby o wiadomość od obcych, nigdy tego, co wysyła ci kontakt lub grupa.';

  @override
  String get seenScamShieldRequestsOnlyDesk =>
      'Działa na twoim komputerze według reguł wbudowanych w aplikację. Bez sieci, bez pobierania list. Czyta tylko prośby o wiadomość od obcych, nigdy tego, co wysyła ci kontakt lub grupa.';

  @override
  String get seenBurnerRooms => 'Pokoje jednorazowe';

  @override
  String get seenRoomKeys => 'Klucze pokoju';

  @override
  String get seenYouJoinARoom =>
      'Do pokoju dołączasz z kluczem zrobionym dla niego, więc osoby w środku nie dowiadują się niczego, co działałoby gdzie indziej. Spóźnieni nie dostają historii. Gdy pokój wygasa, klucze, wiadomości i multimedia są niszczone.';

  @override
  String get seenLinkPreviews => 'Podglądy linków';

  @override
  String get seenOverTor => 'Przez Tor';

  @override
  String get seenAPreviewIsFetched =>
      'Podgląd pobiera nadawca, przez Tor, i trafia on do zaszyfrowanej wiadomości. Telefon odbiorcy nie wysyła żadnego zapytania. Strona dowiaduje się tylko, że przez Tor poproszono o stronę. Żaden obrazek nie jest ładowany, a link od obcego zostaje zwykłym tekstem.';

  @override
  String get seenAPreviewIsFetchedDesk =>
      'Podgląd pobiera nadawca, przez Tor, i trafia on do zaszyfrowanej wiadomości. Urządzenie odbiorcy nie wysyła żadnego zapytania. Strona dowiaduje się tylko, że przez Tor poproszono o stronę. Żaden obrazek nie jest ładowany, a link od obcego zostaje zwykłym tekstem.';

  @override
  String get seenASeizedUnlockedPhone => 'Zabrany odblokowany telefon';

  @override
  String get seenASeizedUnlockedPhoneDesk => 'Zabrany odblokowany komputer';

  @override
  String get seenIfSomeoneHoldsYour =>
      'Jeśli ktoś trzyma twój odblokowany telefon, czyta twoje wiadomości. Blokada aplikacji, PIN wymazania i szyfrowane przechowywanie pomagają przed tym momentem, nie po nim.';

  @override
  String get seenIfSomeoneHoldsYourDesk =>
      'Jeśli ktoś siedzi przy twoim odblokowanym komputerze, czyta twoje wiadomości. Blokada aplikacji, PIN wymazania i szyfrowane przechowywanie pomagają przed tym momentem, nie po nim.';

  @override
  String get seenTheCryptoItself => 'Sama kryptografia';

  @override
  String get seenTheRatchetAndStorage =>
      'Warstwy ratchet i przechowywania są standardowe. Warstwa, która je łączy, jest nasza i nie przeszła jeszcze niezależnej kontroli. To oprogramowanie w wersji alfa.';

  @override
  String get seenFast => 'Szybki';

  @override
  String get settingsWipeKryfo => 'Wymazać Kryfo?';

  @override
  String get settingsIdentityMessagesContactsAnd =>
      'Tożsamość, wiadomości, kontakty i ustawienia na tym telefonie. Znikną na zawsze, chyba że masz kopię zapasową.';

  @override
  String get settingsIdentityMessagesContactsAndDesk =>
      'Tożsamość, wiadomości, kontakty i ustawienia na tym komputerze. Znikną na zawsze, chyba że masz kopię zapasową.';

  @override
  String get commonContinue => 'Dalej';

  @override
  String settingsTypeWipeToConfirm(Object word) {
    return 'Wpisz „$word”, żeby potwierdzić';
  }

  @override
  String get settingsTheLastStepNothing =>
      'Ostatni krok. Nic tego nie przetrwa.';

  @override
  String get settingsWipeWord => 'wymaż';

  @override
  String get settingsWipeKryfo2 => 'Wymaż Kryfo';

  @override
  String get settingsYourProtections => 'Twoje zabezpieczenia';

  @override
  String get settingsTorRouting => 'Routing przez Tor';

  @override
  String get settingsOffFastMode => 'Wył. · tryb szybki';

  @override
  String get settingsAppLock => 'Blokada aplikacji';

  @override
  String get settingsBlockedByAndroid => 'Zablokowane przez Androida';

  @override
  String get settingsSpeedPrivacy => 'Szybkość i prywatność';

  @override
  String get settingsFast => 'Szybki';

  @override
  String get settingsOnion3Hops => 'Onion · 3 przeskoki';

  @override
  String settingsPreviewHidden(Object deliveryModeName) {
    return '$deliveryModeName · podgląd ukryty';
  }

  @override
  String settingsPreviewShown(Object deliveryModeName) {
    return '$deliveryModeName · podgląd widoczny';
  }

  @override
  String get settingsRunInBackground => 'Działanie w tle';

  @override
  String get settingsSoMessagesArrive => 'Żeby wiadomości docierały';

  @override
  String get settingsTransport => 'Transport';

  @override
  String get settingsWhatTheNetworkIs => 'Co robi sieć';

  @override
  String get settingsBlocked => 'Zablokowani';

  @override
  String get settingsAcceptIntroductions => 'Przyjmuj przedstawienia';

  @override
  String get settingsFriendsCanIntroduceYou =>
      'Znajomi mogą przedstawić cię swoim';

  @override
  String get settingsScamShield => 'Ochrona przed oszustwami';

  @override
  String get settingsScamShieldHint =>
      'Sprawdzane tylko na twoim telefonie, nic go nie opuszcza';

  @override
  String get settingsScamShieldHintDesk =>
      'Sprawdzane tylko na twoim komputerze, nic go nie opuszcza';

  @override
  String get typingNow => 'Pisze';

  @override
  String get settingsTypingIndicator => 'Wskaźnik pisania';

  @override
  String get settingsTypingIndicatorHint =>
      'Oboje widzicie, kiedy druga osoba pisze. Trafia to prosto do niej przez Tor, nigdy przez przekaźnik.';

  @override
  String get settingsTypingOnionOnly => 'Dostępne na trasie Onion';

  @override
  String get settingsTypingBridgesOff =>
      'Wyłączone, gdy używasz mostków: osoba obserwująca twoje połączenie mogłaby dopasować sygnały pisania. Wraca samo, gdy mostki są wyłączone.';

  @override
  String get settingsLightTheme => 'Jasny motyw';

  @override
  String get settingsSameProtectionBrighter => 'Ta sama ochrona, jaśniej';

  @override
  String get settingsAppearance => 'Wygląd';

  @override
  String get settingsAccentColour => 'Kolor akcentu';

  @override
  String get settingsColoursAndWallpaper => 'Kolory i tapeta';

  @override
  String get settingsAppLock2 => 'Blokada aplikacji';

  @override
  String get settingsYourPinAndA => 'Twój PIN i ochrona zaawansowana';

  @override
  String get settingsPinWipePin => 'PIN · PIN wymazania';

  @override
  String get settingsBackUpIdentity => 'Kopia zapasowa tożsamości';

  @override
  String get settingsEncryptedFile => 'Zaszyfrowany plik';

  @override
  String get settingsRestoreFromBackup => 'Przywróć z kopii';

  @override
  String get settingsReplaceCurrent => 'Zastępuje obecne';

  @override
  String get settingsWhyKryfo => 'Dlaczego Kryfo';

  @override
  String get settingsHowItProtectsYou => 'Jak cię chroni';

  @override
  String get settingsResetMyInviteLink => 'Zresetuj mój link z zaproszeniem';

  @override
  String get settingsOldLinksAndCodes =>
      'Stare linki i kody przestaną działać, dla wszystkich';

  @override
  String get settingsResetInviteLink => 'Zresetować link z zaproszeniem?';

  @override
  String get settingsAnyoneWithAnOld =>
      'Każdy ze starym kodem lub linkiem przestanie móc się z tobą skontaktować, każdą drogą. Osoby, które go mają, ale nigdy nie użyły, będą potrzebować od ciebie nowego. Kontakty, czaty i historia zostają.';

  @override
  String get settingsReset => 'Zresetuj';

  @override
  String get settingsInviteResetShareThe =>
      'Zaproszenie zresetowane · udostępnij nowy kod';

  @override
  String get settingsWhatWeCanSee => 'Co możemy zobaczyć';

  @override
  String get settingsTheHonestList => 'Szczera lista';

  @override
  String get settingsVersion => 'Wersja';

  @override
  String get settingsReportAnIssue => 'Zgłoś problem';

  @override
  String get settingsReportInKryfo => 'Napisz w Kryfo';

  @override
  String get settingsReportInKryfoSub =>
      'Czat z Marios. Możesz pisać anonimowo.';

  @override
  String get settingsReportByEmail => 'Wyślij e-mail';

  @override
  String get settingsReportByEmailSub =>
      'gnosiworks@proton.me, z twojej aplikacji pocztowej';

  @override
  String get settingsBugOrSecurityFlaw => 'Błąd albo luka bezpieczeństwa';

  @override
  String get settingsOpenSource => 'Otwarty kod';

  @override
  String get settingsLinkCopied => 'Link skopiowany';

  @override
  String get settingsTheOfflineMapIn =>
      'Mapa offline w Narzędziach pochodzi z Natural Earth (domena publiczna). Nazwy miejscowości pochodzą z GeoNames, geonames.org, na licencji CC BY 4.0.';

  @override
  String get settingsNotIndependentlyAuditedPre =>
      'Bez niezależnego audytu. Wersja alfa: dobra do testów, jeszcze nie do spraw wysokiej wagi.';

  @override
  String get settingsFollowTitle => 'Obserwuj GnosiWorks (twórca)';

  @override
  String get settingsFollowBrowserNote =>
      'Otwiera się w przeglądarce, poza Kryfo.';

  @override
  String get settingsFollowOpen => 'Otwórz';

  @override
  String settingsFollowOn(Object name) {
    return 'Obserwuj na $name, poza Kryfo';
  }

  @override
  String get settingsDangerZone => 'Strefa ryzyka';

  @override
  String get settingsWipeKryfoFromThis => 'Wymaż Kryfo z tego telefonu';

  @override
  String get settingsWipeKryfoFromThisDesk => 'Wymaż Kryfo z tego komputera';

  @override
  String get toolsMoreTools => 'Więcej narzędzi';

  @override
  String get toolsMakeAPrivateQr => 'Zrób prywatny kod QR';

  @override
  String get toolsLinksWiFiContacts =>
      'Linki, Wi-Fi, kontakty i więcej. Robione offline';

  @override
  String get toolsLockAFile => 'Zablokuj plik';

  @override
  String get toolsWithAPasswordOpens =>
      'Hasłem. Otwiera się wszędzie przez age';

  @override
  String get toolsOpenALockedFile => 'Otwórz zablokowany plik';

  @override
  String get toolsAnyAgeFileSomeone => 'Dowolny otrzymany plik .age';

  @override
  String get toolsWorksOfflineNoContacts =>
      'Działa offline · nie trzeba kontaktów';

  @override
  String get toolsUsefulFrom => 'Przydatne od';

  @override
  String get toolsTheFirstMinute => 'pierwszej minuty.';

  @override
  String get toolsEverythingHereHappensOn =>
      'Wszystko tutaj dzieje się na tym telefonie. Nic nie jest wysyłane, a nikt inny nie musi mieć Kryfo.';

  @override
  String get toolsEverythingHereHappensOnDesk =>
      'Wszystko tutaj dzieje się na tym komputerze. Nic nie jest wysyłane, a nikt inny nie musi mieć Kryfo.';

  @override
  String get toolsPhotoCleaner => 'Czyszczenie zdjęć';

  @override
  String get toolsRemovesHiddenInfo =>
      'Usuwa ukryte informacje (metadane), takie jak miejsce, czas i model telefonu';

  @override
  String get toolsPickAPhotoAnd =>
      'Wybierz zdjęcie lub film, żeby zobaczyć, co zdradza, a potem usuń to wszystko jednym stuknięciem. Możesz też udostępnić je do Kryfo z galerii.';

  @override
  String get toolsPickAPhotoAndDesk =>
      'Wybierz zdjęcie lub film, żeby zobaczyć, co zdradza, a potem usuń to wszystko jednym kliknięciem. Możesz też upuścić go tutaj albo wkleić.';

  @override
  String get toolsPickAPhoto => 'Wybierz zdjęcie';

  @override
  String get toolsVideo => 'Wideo';

  @override
  String get transportTransport => 'Transport';

  @override
  String get transportNothingHereLeavesThe =>
      'Nic stąd nie opuszcza telefonu. To ten sam stan, którym silnik się kieruje.';

  @override
  String get transportNothingHereLeavesTheDesk =>
      'Nic stąd nie opuszcza komputera. To ten sam stan, którym silnik się kieruje.';

  @override
  String get transportStayingAlive => 'Utrzymanie przy życiu';

  @override
  String get transportCanSend => 'Może wysyłać';

  @override
  String get commonYes => 'Tak';

  @override
  String get transportNotYet => 'Jeszcze nie';

  @override
  String get transportOnline => 'Online';

  @override
  String get transportOffline => 'Offline';

  @override
  String get transportQueuedToSend => 'W kolejce do wysłania';

  @override
  String get transportOnionPublished => 'Onion opublikowany';

  @override
  String transportYes(Object uploads) {
    return 'Tak ($uploads)';
  }

  @override
  String transportTryingS(Object pubFor) {
    return 'Próbuję $pubFor s';
  }

  @override
  String transportBenchedS(Object r) {
    return 'Odstawiony $r s';
  }

  @override
  String transportFails(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString błędu',
      many: '$countString błędów',
      few: '$countString błędy',
      one: '$countString błąd',
    );
    return '$_temp0';
  }

  @override
  String get transportOk => 'OK';

  @override
  String get transportRelaySubscriptions => 'Subskrypcje przekaźników';

  @override
  String get transportLastSent => 'Ostatnio wysłano';

  @override
  String get transportNever => 'Nigdy';

  @override
  String transportSAgo(Object sx) {
    return '$sx s temu';
  }

  @override
  String get transportLastReceived => 'Ostatnio odebrano';

  @override
  String transportSAgo2(Object rx) {
    return '$rx s temu';
  }

  @override
  String get transportWithNoContactsThe =>
      'Bez kontaktów aplikacja nie subskrybuje żadnych adresów przekaźników, więc żadna wiadomość do ciebie nie dotrze. Zeskanuj kogoś, żeby to naprawić.';

  @override
  String get transportWithNoContactsTheDesk =>
      'Bez kontaktów aplikacja nie subskrybuje żadnych adresów przekaźników, więc żadna wiadomość do ciebie nie dotrze. Dodaj kogoś, żeby to naprawić.';

  @override
  String get transportSendAnythingWaitingNow =>
      'Wyślij wszystko, co czeka, teraz';

  @override
  String get transportSending => 'Wysyłam…';

  @override
  String get transportNothingLeftWaiting => 'Nic już nie czeka';

  @override
  String transportStillWaiting(Object count) {
    return 'Nadal czeka: $count';
  }

  @override
  String get transportOff => 'Wył.';

  @override
  String get transportStarting => 'Uruchamianie';

  @override
  String get transportBootstrapped => 'Uruchomiony';

  @override
  String get transportPublishingAddress => 'Publikuję adres';

  @override
  String get transportReachable => 'Osiągalny';

  @override
  String get transportOurRelayOnion => 'Nasz przekaźnik (onion)';

  @override
  String get transportNever2 => 'nigdy';

  @override
  String get transportJustNow => 'Przed chwilą';

  @override
  String transportMAgo(Object inMinutes) {
    return '$inMinutes min temu';
  }

  @override
  String transportHAgo(Object inHours) {
    return '$inHours godz. temu';
  }

  @override
  String transportDAgo(Object inDays) {
    return '$inDays d temu';
  }

  @override
  String transportM(Object inMinutes) {
    return '$inMinutes min';
  }

  @override
  String transportHM(Object inHours, Object d) {
    return '$inHours godz. $d min';
  }

  @override
  String transportD(Object inDays) {
    return '$inDays d';
  }

  @override
  String transportMb(Object b) {
    return '$b MB';
  }

  @override
  String get transportYesCheckedJustNow => 'Tak · sprawdzono przed chwilą';

  @override
  String transportNoLast(Object ago) {
    return 'Nie · ostatnio $ago';
  }

  @override
  String get transportLastMessageIn => 'Ostatnia przychodząca wiadomość';

  @override
  String get transportBatteryExemption => 'Wyjątek baterii';

  @override
  String get transportUnknown => 'Nieznany';

  @override
  String get transportExempt => 'Wyłączony z oszczędzania';

  @override
  String get transportNotExemptTapTo => 'Bez wyjątku · stuknij, by naprawić';

  @override
  String get transportProcessUp => 'Proces działa od';

  @override
  String get transportLastStop => 'Ostatnie zatrzymanie';

  @override
  String get transportStopKilled => 'Zabite przez system';

  @override
  String get transportStopLowMemory => 'Mało pamięci';

  @override
  String get transportStopCrashed => 'Awaria';

  @override
  String get transportStopNotResponding => 'Nie odpowiada';

  @override
  String get transportStopByYou => 'Zatrzymane przez ciebie';

  @override
  String get transportStopByPhone => 'Zatrzymane przez telefon';

  @override
  String get transportStopBySecurityApp =>
      'Zatrzymane przez aplikację zabezpieczającą';

  @override
  String get transportStopUpdated => 'Zaktualizowane';

  @override
  String get transportStopBySystem => 'Zatrzymane przez system';

  @override
  String get transportStopTooMuch => 'Zbyt duże zużycie';

  @override
  String get transportStopPermission => 'Zmiana uprawnień';

  @override
  String get transportStopClosedItself => 'Zamknęło się samo';

  @override
  String get transportStopOther => 'Zatrzymane';

  @override
  String transportEngine(Object mb, Object mb2) {
    return '$mb · silnik $mb2';
  }

  @override
  String get transportLastRelayArrival => 'Ostatnie dotarcie z przekaźnika';

  @override
  String get transportLastCheckIn => 'Ostatnie sprawdzenie';

  @override
  String get transportNoneYet => 'Jeszcze żadne';

  @override
  String get transportLastTorReconnect => 'Ostatnie ponowne połączenie Tor';

  @override
  String get transportCatchUpByRelay => 'Nadrabianie przez przekaźnik';

  @override
  String get transportControlPort => 'Port kontrolny';

  @override
  String get transportReconnects => 'Ponowne połączenia';

  @override
  String get transportWhyNetwork => 'Zmiana sieci';

  @override
  String get transportWhyHand => 'Ręcznie';

  @override
  String get transportWhyRelays => 'Żaden przekaźnik nie odpowiedział';

  @override
  String get transportWhyStall => 'Start się zatrzymał';

  @override
  String get transportWhyTorOff => 'Tor był wyłączony';

  @override
  String get transportWhyDialer => 'Brak przekaźnika przez 3 minuty';

  @override
  String get transportWhyOnion => 'Znów na onion';

  @override
  String get transportWhyBridges => 'Zmiana mostka';

  @override
  String get transportWhyAuto => 'Automatycznie';

  @override
  String get transportWhyOffline => 'Brak sieci';

  @override
  String get transportWhyCircuits => 'Nowe obwody';

  @override
  String get transportWhyOther => 'Inne';

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
      other: '$dialsString połączenia',
      many: '$dialsString połączeń',
      few: '$dialsString połączenia',
      one: '$dialsString połączenie',
    );
    String _temp1 = intl.Intl.pluralLogic(
      timeouts,
      locale: localeName,
      other: '$timeoutsString przekroczenia czasu',
      many: '$timeoutsString przekroczeń czasu',
      few: '$timeoutsString przekroczenia czasu',
      one: '$timeoutsString przekroczenie czasu',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get transportJobRuns => 'Uruchomienia zadania';

  @override
  String transportLast(Object jobRuns, Object ago) {
    return '$jobRuns · ostatnio $ago';
  }

  @override
  String get transportQuietStretches => 'Ciche okresy';

  @override
  String get transportNone => 'Brak';

  @override
  String get transportClearThisRecord => 'Wyczyść ten zapis';

  @override
  String get transportNothingYetThisProcess => 'Jeszcze nic w tym procesie';

  @override
  String transportM2(Object mins) {
    return '$mins min';
  }

  @override
  String transportHM2(Object mins, Object mins2) {
    return '$mins godz. $mins2 min';
  }

  @override
  String transportTo(Object t, Object t2) {
    return '$t do $t2';
  }

  @override
  String vouchersVouchedBy(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Poleca $countString osoby',
      many: 'Poleca $countString osób',
      few: 'Poleca $countString osoby',
      one: 'Poleca:',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperAtmosphere => 'Nastrój';

  @override
  String get wallpaperJustForYouThey =>
      'Tylko dla ciebie. Druga osoba widzi swoją.';

  @override
  String get wallpaperYourPhoto => 'Twoje zdjęcie';

  @override
  String get wallpaperDefault => 'Domyślna';

  @override
  String get wallpaperDim => 'Przyciemnij tapetę';

  @override
  String get wallpaperNotSet =>
      'Nie udało się ustawić tapety. Spróbuj ponownie.';

  @override
  String get wallpaperFromYourPhotos => 'Z twoich zdjęć';

  @override
  String get wallpaperKeepIt => 'Zostaw';

  @override
  String get whyKryfoWhyKryfo => 'Dlaczego Kryfo';

  @override
  String get whyKryfoKryfoKreeFoGreek =>
      'Kryfo · KRI-fo · po grecku ukryte.\nSpokojne miejsce do rozmowy, zbudowane z dala od cudzych oczu.';

  @override
  String get whyKryfoRoutedThroughTor => 'Przez Tor';

  @override
  String get whyKryfoByDefaultEveryMessage =>
      'Domyślnie każda wiadomość idzie przez Tor, czyli łańcuch przekaźników. Nikt, ani my, ani twoja sieć, nie widzi, z kim rozmawiasz ani gdzie jesteś.';

  @override
  String get whyKryfoEndToEndEncrypted => 'Szyfrowanie end-to-end';

  @override
  String get whyKryfoMessagesAreSealedWith =>
      'Wiadomości są zapieczętowane kluczami, które macie tylko ty i osoba, z którą rozmawiasz. Nie możemy ich przeczytać.';

  @override
  String get whyKryfoNoServersHoldingYour => 'Żadnych serwerów z twoim życiem';

  @override
  String get whyKryfoNoAccountNoPhone =>
      'Bez konta, bez numeru telefonu, bez centralnego serwera z twoimi czatami. Żyją na tym telefonie, zaszyfrowane.';

  @override
  String get whyKryfoNoAccountNoPhoneDesk =>
      'Bez konta, bez numeru telefonu, bez centralnego serwera z twoimi czatami. Żyją na tym komputerze, zaszyfrowane.';

  @override
  String get whyKryfoNothingLeaks => 'Nic nie wycieka';

  @override
  String get whyKryfoNoReceiptsTyping =>
      'Bez potwierdzeń odczytu, bez wysyłania listy kontaktów. Pisanie widzi tylko osoba, do której piszesz, prosto przez Tor, nigdy przez serwer. Większość aplikacji zdradza metadane. Kryfo jest zbudowane tak, żeby tego nie robić.';

  @override
  String get whyKryfoVerifyItIsReally => 'Sprawdź, czy to naprawdę ta osoba';

  @override
  String get whyKryfoCompareASafetyNumber =>
      'Porównajcie numer bezpieczeństwa osobiście albo kanałem, któremu ufasz, żeby wiedzieć, że nikt nie podszywa się pod twój kontakt.';

  @override
  String get whyKryfoTheHonestPart => 'Szczera część';

  @override
  String get whyKryfoKryfoIsPreAlpha =>
      'Kryfo jest w wersji alfa i nie przeszło audytu. Kryptografia jest prawdziwa, ale nie przeszła jeszcze zewnętrznej kontroli, więc nie polegaj na nim jeszcze tam, gdzie zależy od tego twoje bezpieczeństwo.';

  @override
  String get cleanerLocation => 'Lokalizacja';

  @override
  String get cleanerAlreadyBlankedByAndroid =>
      'już wyczyszczone przez Androida';

  @override
  String get cleanerPhoneModel => 'Model telefonu';

  @override
  String get cleanerTimeTaken => 'Czas zrobienia';

  @override
  String get cleanerSerialNumber => 'Numer seryjny';

  @override
  String get cleanerOwnerName => 'Właściciel';

  @override
  String get cleanerHiddenThumbnail => 'Ukryta miniatura';

  @override
  String get cleanerContentCredentials => 'Poświadczenia treści';

  @override
  String get cleanerHdrLayer => 'Warstwa HDR';

  @override
  String get cleanerDataAfterThePicture => 'Dane za obrazem';

  @override
  String cleaner1OtherField(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString innego pola',
      many: '$countString innych pól',
      few: '$countString inne pola',
      one: '$countString inne pole',
    );
    return '$_temp0';
  }

  @override
  String get lockWordsFourRandomWordsBeat =>
      'Cztery losowe słowa są lepsze niż jedno sprytne.';

  @override
  String lockWordsTooShortAtLeast(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Za krótkie. Co najmniej $countString znaku.',
      many: 'Za krótkie. Co najmniej $countString znaków.',
      few: 'Za krótkie. Co najmniej $countString znaki.',
      one: 'Za krótkie. Co najmniej $countString znak.',
    );
    return '$_temp0';
  }

  @override
  String get lockWordsWeakWhoeverGetsThe =>
      'Słabe. Kto dostanie plik, może zgadywać, jak szybko chce.';

  @override
  String get lockWordsFairLongerIsStronger =>
      'Niezłe. Dłuższe znaczy silniejsze.';

  @override
  String get lockWordsStrongFourRandomWords =>
      'Silne. Cztery losowe słowa są lepsze niż jedno sprytne.';

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
      other: '$countString metra',
      many: '$countString metrów',
      few: '$countString metry',
      one: '$countString metr',
    );
    return '$_temp0';
  }

  @override
  String get photoStoryFarFromAnyTown => 'Daleko od miejscowości';

  @override
  String photoStoryNear(Object where) {
    return 'Blisko $where';
  }

  @override
  String photoStoryAboutKmFrom(Object near, Object where) {
    return 'Około $near km od $where';
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
  String get photoStoryNotAKindKryfo => 'Kryfo nie umie odczytać tego rodzaju.';

  @override
  String get photoStorySoItWillNot => 'Więc nie będzie zgadywać.';

  @override
  String get photoStoryThisFileIsDamaged =>
      'Ten plik jest uszkodzony albo ucięty.';

  @override
  String get photoStoryKryfoCouldNotRead =>
      'Kryfo nie mogło odczytać go do końca.';

  @override
  String get photoStoryWhereItWasRecorded => 'Gdzie nagrano';

  @override
  String get photoStoryWhereItWasTaken => 'Gdzie zrobiono';

  @override
  String photoStoryLocation(Object coordsLine) {
    return 'Lokalizacja: $coordsLine';
  }

  @override
  String photoStoryHeightAboveTheSea(Object fix) {
    return 'Wysokość nad poziomem morza: $fix m';
  }

  @override
  String get photoStoryLocationHiddenByAndroid =>
      'Lokalizacja ukryta przez Androida';

  @override
  String get photoStoryAndroidBlanksItWhen =>
      'Android ją czyści, gdy zdjęcie wybiera się w ten sposób. Udostępnienie go do Kryfo z galerii często ją zachowuje. To w galerii może ją nadal mieć.';

  @override
  String get photoStoryLocationBlankedByAndroid =>
      'Lokalizacja: wyczyszczona przez Androida, zanim Kryfo ją zobaczyło';

  @override
  String photoStoryF(Object r) {
    return 'f/$r';
  }

  @override
  String get photoStoryWhatTookIt => 'Czym je zrobiono';

  @override
  String photoStoryPhoneOrCamera(Object phone) {
    return 'Telefon lub aparat: $phone';
  }

  @override
  String get photoStoryWhenItWasRecorded => 'Kiedy nagrano';

  @override
  String get photoStoryToTheSecondWith => 'Co do sekundy, ze strefą czasową';

  @override
  String get photoStoryToTheSecond => 'Co do sekundy';

  @override
  String photoStoryTime(Object dateFormat) {
    return 'Czas: $dateFormat';
  }

  @override
  String get photoStoryLens => 'Obiektyw';

  @override
  String photoStoryLens2(Object lens) {
    return 'Obiektyw: $lens';
  }

  @override
  String get photoStorySoftware => 'Oprogramowanie';

  @override
  String photoStorySoftware2(Object software) {
    return 'Oprogramowanie: $software';
  }

  @override
  String get photoStorySerialNumber => 'Numer seryjny';

  @override
  String photoStorySerialNumber2(Object serial) {
    return 'Numer seryjny: $serial';
  }

  @override
  String get photoStoryOwnerName => 'Właściciel';

  @override
  String photoStoryOwner(Object r) {
    return 'Właściciel: $r';
  }

  @override
  String get photoStoryHiddenThumbnail => 'Ukryta miniatura';

  @override
  String get photoStoryASmallCopyOf =>
      'Mała kopia obrazu w pliku. Może pokazać to, co usunęło przycięcie';

  @override
  String get photoStoryMakerNotes => 'Notatki producenta';

  @override
  String get photoStoryMakerNotesABlock =>
      'Notatki producenta: blok, który odczyta tylko producent';

  @override
  String get photoStoryEditingHistory => 'Historia edycji';

  @override
  String get photoStoryXmpEditingHistoryAnd => 'XMP: historia edycji i tagi';

  @override
  String get photoStoryCaptions => 'Podpisy';

  @override
  String get photoStoryIptcCaptionsAndCredits => 'IPTC: podpisy i autorstwo';

  @override
  String get photoStoryComment => 'Komentarz';

  @override
  String get photoStoryAWrittenComment => 'Wpisany komentarz';

  @override
  String get photoStoryContentCredentials => 'Poświadczenia treści';

  @override
  String get photoStorySecondPicture => 'Drugi obraz';

  @override
  String get photoStoryASecondPictureInside => 'Drugi obraz w pliku';

  @override
  String get photoStoryMotionVideo => 'Wideo ruchome';

  @override
  String get photoStoryAShortVideoInside => 'Krótkie wideo w pliku';

  @override
  String get photoStorySaveTime => 'Czas zapisu';

  @override
  String get photoStoryTheTimeItWas => 'Kiedy ostatnio zapisano';

  @override
  String get photoStoryTimeStamps => 'Znaczniki czasu';

  @override
  String get photoStoryCreationTimeStamps => 'Znaczniki czasu utworzenia';

  @override
  String get photoStoryDataAfterThePicture => 'Dane za obrazem';

  @override
  String photoStoryDataAfterTheEnd(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Dane za końcem obrazu: $countString bajta',
      many: 'Dane za końcem obrazu: $countString bajtów',
      few: 'Dane za końcem obrazu: $countString bajty',
      one: 'Dane za końcem obrazu: $countString bajt',
    );
    return '$_temp0';
  }

  @override
  String photoStoryTextField(Object k) {
    return 'Pole tekstowe: $k';
  }

  @override
  String photoStoryVideoTag(Object k) {
    return 'Znacznik wideo: $k';
  }

  @override
  String photoStoryAlso(Object k) {
    return 'Poza tym: $k';
  }

  @override
  String photoStoryCameraSettingsFlashFocus(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString ustawienia aparatu (lampa, ostrość, ekspozycja)',
      many: '$countString ustawień aparatu (lampa, ostrość, ekspozycja)',
      few: '$countString ustawienia aparatu (lampa, ostrość, ekspozycja)',
      one: '$countString ustawienie aparatu (lampa, ostrość, ekspozycja)',
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
      other: '$countString pola więcej',
      many: '$countString pól więcej',
      few: '$countString pola więcej',
      one: '$countString pole więcej',
    );
    return '$_temp0';
  }

  @override
  String get photoStoryCameraSettings => 'Ustawienia aparatu';

  @override
  String photoStoryAccurateToAbout(Object metres) {
    return 'Z dokładnością do około $metres.';
  }

  @override
  String get photoStoryEnoughToFindThe => 'Wystarczy, żeby znaleźć drzwi.';

  @override
  String get photoStoryEnoughToFindTheStreet =>
      'Wystarczy, żeby znaleźć ulicę.';

  @override
  String get photoStoryEnoughToFindTheArea =>
      'Wystarczy, żeby znaleźć okolicę.';

  @override
  String get photoStoryItKnowsWhereYou => 'Wie, gdzie zrobiono zdjęcie.';

  @override
  String get photoStoryDownToTheBuilding => 'Z dokładnością do budynku.';

  @override
  String get photoStoryAndroidHidTheLocation => 'Android ukrył lokalizację.';

  @override
  String get photoStoryTheOriginalMayStill => 'Oryginał może ją nadal mieć.';

  @override
  String get photoStoryNoLocationInThis => 'To nie ma lokalizacji.';

  @override
  String get photoStoryItStillSaysPlenty => 'I tak mówi sporo.';

  @override
  String get photoStoryThisOneKnowsNothing => 'To nic nie wie.';

  @override
  String get photoStoryNothingToRemove => 'Nie ma czego usuwać.';

  @override
  String get qrPayloadOpensALink => 'OTWIERA LINK';

  @override
  String qrPayloadOpens(Object host) {
    return 'OTWIERA $host';
  }

  @override
  String get qrPayloadShowsANote => 'POKAZUJE NOTATKĘ';

  @override
  String get qrPayloadScanToJoin => 'ZESKANUJ, ŻEBY DOŁĄCZYĆ';

  @override
  String qrPayloadScanToJoin2(Object oneLine) {
    return 'ZESKANUJ, ŻEBY DOŁĄCZYĆ · $oneLine';
  }

  @override
  String get qrPayloadANetworkNameIs => 'Nazwa sieci ma najwyżej 32 znaki.';

  @override
  String get qrPayloadAWiFiPassword => 'Hasło Wi-Fi ma co najmniej 8 znaków.';

  @override
  String get qrPayloadSavesAContact => 'ZAPISUJE KONTAKT';

  @override
  String get qrPayloadWritesAnEmail => 'PISZE E-MAIL';

  @override
  String get qrPayloadThatDoesNotLook => 'To nie wygląda na adres e-mail.';

  @override
  String get qrPayloadCallsANumber => 'DZWONI POD NUMER';

  @override
  String get qrPayloadWritesAText => 'PISZE SMS';

  @override
  String get qrPayloadOpensAMap => 'OTWIERA MAPĘ';

  @override
  String get qrPayloadLatitudeRunsFrom90 =>
      'Szerokość to od -90 do 90, długość od -180 do 180.';

  @override
  String get qrPayloadPayThisAddress => 'ZAPŁAĆ NA TEN ADRES';

  @override
  String get qrPayloadABitcoinAddressIs =>
      'Adres bitcoin to tylko litery i cyfry.';

  @override
  String get qrPayloadTheAmountIsIn =>
      'Kwota jest w BTC, do 8 miejsc po przecinku.';

  @override
  String vouchTextAnd(Object names, Object names2) {
    return '$names i $names2';
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
      other: '$restString innej znanej ci osoby',
      many: '$restString innych znanych ci osób',
      few: '$restString inne znane ci osoby',
      one: '$restString inna znana ci osoba',
    );
    return '$names, $names2 i $_temp0';
  }

  @override
  String vouchTextVouchedBy(Object vouchNames) {
    return 'Poleca: $vouchNames';
  }

  @override
  String vouchTextIntroducedBy(Object vouchNames) {
    return 'Przedstawia: $vouchNames';
  }

  @override
  String vouchTextThisSharesSAddress(Object a, Object b) {
    return 'To udostępnia adres $a osobie $b';
  }

  @override
  String get bootFailedKryfoCouldNotStart => 'Kryfo nie mogło się uruchomić';

  @override
  String get bootFailedThisIsAFault =>
      'To usterka tego urządzenia, nie sieci. Tor nie ma z tym nic wspólnego.';

  @override
  String get bootFailedKeysDidNotAnswer =>
      'Magazyn kluczy w twoim telefonie przestał odpowiadać. Zamknięcie i ponowne otwarcie Kryfo zwykle to naprawia.';

  @override
  String get bootFailedKeysDidNotAnswerDesk =>
      'Magazyn kluczy tego komputera przestał odpowiadać. Zamknięcie i ponowne otwarcie Kryfo zwykle to naprawia.';

  @override
  String get bootFailedCloseAndReopen => 'Zamknij i otwórz Kryfo ponownie';

  @override
  String get bootFailedStillStuck => 'Jeśli ponowna próba nie pomaga';

  @override
  String get bootFailedRestoreBackup => 'Przywróć kopię zapasową';

  @override
  String get bootFailedStartFresh => 'Zacznij od nowa';

  @override
  String get bootFailedStartFreshTitle => 'Zacząć od nowa?';

  @override
  String get bootFailedStartFreshLine =>
      'To usuwa wszystko, co Kryfo trzyma na tym telefonie: czaty, kontakty, multimedia, ukryte czaty i twoje trzy słowa. Plik kopii zapasowej zapisany gdzie indziej pozostaje nietknięty.';

  @override
  String get bootFailedStartFreshLineDesk =>
      'To usuwa wszystko, co Kryfo trzyma na tym komputerze: czaty, kontakty, multimedia, ukryte czaty i twoje trzy słowa. Plik kopii zapasowej zapisany gdzie indziej pozostaje nietknięty.';

  @override
  String get bootFailedStartFreshNext => 'Dalej';

  @override
  String get bootFailedStartFreshSure => 'Usunąć wszystko z tego telefonu?';

  @override
  String get bootFailedStartFreshSureDesk =>
      'Usunąć wszystko z tego komputera?';

  @override
  String get bootFailedStartFreshSureLine =>
      'Tego nie da się cofnąć. Kryfo się zamknie i otworzy jak nowa instalacja.';

  @override
  String get bootFailedStartFreshYes => 'Usuń i zacznij od nowa';

  @override
  String get kryfoLinkTextThatLinkIsNot => 'Kryfo nie umie odczytać tego linku';

  @override
  String kryfoLinkTextAdd(Object who) {
    return 'Dodać $who?';
  }

  @override
  String kryfoLinkTextThisIsAnInvite(Object who) {
    return 'To zaproszenie do rozmowy z $who. Dodaj tylko, jeśli wiesz, skąd jest ten link.';
  }

  @override
  String get kryfoLinkTextAddThem => 'Dodaj';

  @override
  String get kryfoLinkTextNotNow => 'Nie teraz';

  @override
  String kryfoLinkTextYouAlreadyHave(Object who) {
    return 'Masz już $who';
  }

  @override
  String kryfoLinkTextSomeoneElse(Object who) {
    return 'Tak nazywasz kogoś w swoich czatach: $who. Ten link jest od kogoś innego. Dodaj tylko, jeśli wiesz, skąd jest.';
  }

  @override
  String kryfoLinkTextJoin(Object roomName) {
    return 'Dołącz do $roomName';
  }

  @override
  String get kryfoLinkTextKryfoLink => 'Link Kryfo';

  @override
  String kryfoLinkTextAdd2(Object who) {
    return 'Dodaj $who';
  }

  @override
  String get kryfoLinkTextBurnerRoom => 'Pokój jednorazowy';

  @override
  String get kryfoLinkTextThisRoomHasClosed => 'Ten pokój jest już zamknięty';

  @override
  String kryfoLinkTextClosesIn(Object time) {
    return 'Zamyka się za $time';
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
      other: 'Zamyka się za $time · do $capString osoby',
      many: 'Zamyka się za $time · do $capString osób',
      few: 'Zamyka się za $time · do $capString osób',
      one: 'Zamyka się za $time · do $capString osoby',
    );
    return '$_temp0';
  }

  @override
  String get kryfoLinkTextJoin2 => 'Dołącz';

  @override
  String get kryfoLinkTextYouJoinUnderA =>
      'Dołączasz z kluczem zrobionym dla tego pokoju. Nikt w nim nie widzi twoich trzech słów.';

  @override
  String get linkStubFetchedOverTorBy =>
      'Pobrane przez Tor · przez twoje urządzenie';

  @override
  String get linkStubFetchedOverTorByTheirDevice =>
      'Pobrane przez Tor · przez urządzenie drugiej osoby';

  @override
  String mediaBubblesB(Object bytes) {
    return '$bytes B';
  }

  @override
  String mediaBubblesKb(Object bytes) {
    return '$bytes kB';
  }

  @override
  String mediaBubblesMb(Object bytes) {
    return '$bytes MB';
  }

  @override
  String get mediaBubblesFile => 'PLIK';

  @override
  String get mediaBubblesAudioUnavailable => 'Dźwięk niedostępny';

  @override
  String get mediaBubblesHidden => 'Ukryte';

  @override
  String get mediaBubblesPlaying => 'Odtwarzanie';

  @override
  String get mediaBubblesSendPhoto => 'Wyślij zdjęcie';

  @override
  String get mediaBubblesAddACaption => 'Dodaj podpis…';

  @override
  String get motionStandby => 'GOTOWOŚĆ';

  @override
  String get motionConnecting => 'ŁĄCZENIE';

  @override
  String get motionBuilding => 'BUDOWANIE';

  @override
  String get motionPublishing => 'PUBLIKOWANIE';

  @override
  String get motionReady => 'GOTOWE';

  @override
  String get motionPreparingToConnect => 'Przygotowanie do połączenia';

  @override
  String get motionFindingAPrivatePath => 'Szukam prywatnej ścieżki';

  @override
  String get motionCarvingThePath => 'Wytyczam ścieżkę';

  @override
  String get motionAnnouncingYourArrival => 'Ogłaszam twoje przybycie';

  @override
  String get motionYouReAnonymous => 'Zachowujesz anonimowość';

  @override
  String get motionReadyToChat => 'Gotowe do czatu';

  @override
  String get motionTorIsStartingIn =>
      'Tor uruchamia się w tle. Ten wykres rozświetla się, gdy powstaje połączenie.';

  @override
  String get motionMakingAFreshRoute =>
      'Tworzę nową trasę przez anonimowe przekaźniki.';

  @override
  String get motionBouncingThroughRelaysSo =>
      'Przeskakiwanie między przekaźnikami, aby nie dało się powiązać tego z tobą.';

  @override
  String get motionTellingTheNetworkYou =>
      'Mówię sieci, że jesteś online, nie zdradzając gdzie.';

  @override
  String get motionYourIpIsHidden =>
      'Twój adres IP jest ukryty. Dotrą do ciebie tylko osoby z twoim Kryfo.';

  @override
  String get motionAddressFinishing =>
      'Wiadomości już wychodzą przez Tor. Twój prywatny adres kończy się tworzyć w tle.';

  @override
  String get motionBuilding2 => 'budowanie';

  @override
  String get motionOpen => 'otwarte';

  @override
  String get motionLive => 'działa';

  @override
  String motionCircuit(Object circuit) {
    return 'Obwód · *$circuit*';
  }

  @override
  String get motionDelivered => 'Dostarczono';

  @override
  String get motionSent => 'Wysłano';

  @override
  String get motion1Hop => '1 przeskok';

  @override
  String get motion3Hops => '3 przeskoki';

  @override
  String get movedStripThisKryfoHasMoved =>
      'Kryfo przeniesiono na inne urządzenie. Wiadomości wysyłane stąd nie docierają do nikogo.';

  @override
  String get navBarChats => 'Czaty';

  @override
  String get navBarTools => 'Narzędzia';

  @override
  String get navBarSupport => 'Wesprzyj';

  @override
  String get navBarMe => 'Ja';

  @override
  String get pairCodePanelPuttingYourInviteIn =>
      'Przygotowuję twoje zaproszenie';

  @override
  String get pairCodePanelYourInviteIsNot =>
      'Twoje zaproszenie nie jest jeszcze gotowe';

  @override
  String get pairCodePanelWorking => 'Pracuję';

  @override
  String get pairCodePanelBurned =>
      'Ten kod spłonął. Zrób nowy, gdy ta osoba będzie gotowa.';

  @override
  String get pairCodePanelCodeCopied => 'Kod skopiowany';

  @override
  String pairCodePanelBurnsIn(Object mm, Object ss) {
    return 'Spłonie za $mm:$ss';
  }

  @override
  String get pairCodePanelTheyTapAddChoose =>
      'Ta osoba stuka Dodaj, wybiera kod i wpisuje te cyfry.';

  @override
  String pinsPinnedMessages(Object count) {
    return 'Przypięte wiadomości · $count';
  }

  @override
  String get pinsPinnedMessages2 => 'Przypięte wiadomości';

  @override
  String get pinsPhoto => 'Zdjęcie';

  @override
  String get pinsVoiceMessage => 'Wiadomość głosowa';

  @override
  String get pinsMessage => 'Wiadomość';

  @override
  String pinsToday(Object hm) {
    return 'Dzisiaj · $hm';
  }

  @override
  String get pinsPinned => 'Przypięte';

  @override
  String pinsOf(Object pinsLength, Object kMaxPins) {
    return '$pinsLength z $kMaxPins';
  }

  @override
  String get pinsNothingPinnedHereYet =>
      'Nic tu jeszcze nie przypięto. Przytrzymaj wiadomość i wybierz Przypnij, a będzie tu czekać na wszystkich w czacie.';

  @override
  String get pinsJump => 'Przejdź';

  @override
  String get pinsUnpin => 'Odepnij';

  @override
  String previewStripFetchedOverTor(Object domainOf) {
    return '$domainOf · pobrane przez Tor';
  }

  @override
  String get previewStripDropThePreview => 'Usuń podgląd';

  @override
  String get previewStripAddPreview => 'Dodaj podgląd';

  @override
  String get previewStripFetchingOverTor => 'Pobieram przez Tor…';

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
  String get torBootSplashNoShortcutsNoTraces => 'Bez skrótów, bez śladów';

  @override
  String get torBootSplashTheNetworkThatKeeps =>
      'Sieć, która dba o twoją prywatność, się rozgrzewa';

  @override
  String get torBootSplashMadeOnThisPhone =>
      'Zrobione na tym telefonie. Nic nie jest nigdzie wysyłane.';

  @override
  String get torBootSplashMadeOnThisPhoneDesk =>
      'Zrobione na tym komputerze. Nic nie jest nigdzie wysyłane.';

  @override
  String get torBootSplashFirstLaunchTakesA =>
      'Pierwsze uruchomienie chwilę trwa · tylko przy starcie';

  @override
  String get torBootSplashTakingLonger => 'To trwa dłużej niż zwykle';

  @override
  String get torBootSplashHopEntry => 'Wejście';

  @override
  String get torBootSplashHopMiddle => 'Środek';

  @override
  String get torBootSplashHopExit => 'Wyjście';

  @override
  String get videoBubbleNothingHereOpensThat =>
      'Nic tutaj tego nie otwiera · udostępniam';

  @override
  String videoBubbleMb(Object b) {
    return '$b MB';
  }

  @override
  String videoBubbleKb(Object b) {
    return '$b KB';
  }

  @override
  String get videoBubbleVideo => 'Wideo';

  @override
  String get notificationsChannelName => 'Wiadomości';

  @override
  String get cameraClose => 'Zamknij';

  @override
  String get cameraFlash => 'Lampa';

  @override
  String get cameraPhoto => 'Zdjęcie';

  @override
  String get cameraVideo => 'Wideo';

  @override
  String get cameraRetake => 'Powtórz';

  @override
  String get seenIntroductions => 'Przedstawienia';

  @override
  String get donateAddress => 'Adres';

  @override
  String get donateCopy => 'Kopiuj';

  @override
  String get donateDone => 'Gotowe';

  @override
  String get donateTierSupporter => 'Wspierający';

  @override
  String get donateTierPatron => 'Mecenas';

  @override
  String get donateTierGuardian => 'Strażnik';

  @override
  String get chatBlock => 'Zablokuj';

  @override
  String get chatDecline => 'Odrzuć';

  @override
  String get chatAccept => 'Akceptuj';

  @override
  String get bridgesConnecting => 'Łączenie';

  @override
  String get restoreMade => 'Utworzono';

  @override
  String get restoreContacts => 'Kontakty';

  @override
  String get restoreMessages => 'Wiadomości';

  @override
  String get restoreAttachments => 'Załączniki';

  @override
  String get restoreHiddenChats => 'Ukryte czaty';

  @override
  String get restoreHiddenFollow =>
      'Twoje ukryte czaty, pod nowym PIN-em ukrytych czatów, który wybierzesz na końcu.';

  @override
  String get restoreChooseHiddenPin =>
      'Ta kopia zawiera ukryte czaty. Wybierz dla nich PIN ukrytych czatów.';

  @override
  String get restoreHiddenLockFirst =>
      'Ukryte czaty wymagają blokady aplikacji, więc najpierw Kryfo dostaje własny PIN.';

  @override
  String get profileIdentity => 'Tożsamość';

  @override
  String get avatarPickerShape => 'Kształt';

  @override
  String get avatarPickerColour => 'Kolor';

  @override
  String get avatarPickerTurn => 'Obrót';

  @override
  String avatarPickerOption(String what, int n, int count) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$what, $nString z $countString';
  }

  @override
  String get avatarPickerYourInitial => 'Twoja litera';

  @override
  String get transportStatus => 'Stan';

  @override
  String get transportBootstrap => 'Uruchamianie';

  @override
  String get transportNetwork => 'Sieć';

  @override
  String get transportConnectivity => 'Łączność';

  @override
  String get transportRelays => 'Przekaźniki';

  @override
  String get transportTraffic => 'Ruch';

  @override
  String get transportContacts => 'Kontakty';

  @override
  String get transportKnown => 'Znane';

  @override
  String get transportListening => 'Nasłuch';

  @override
  String get transportMemory => 'Pamięć';

  @override
  String get settingsConnected => 'Połączono';

  @override
  String get settingsOn => 'Wł.';

  @override
  String get settingsOff => 'Wył.';

  @override
  String get settingsNotifications => 'Powiadomienia';

  @override
  String get settingsPrivacy => 'Prywatność';

  @override
  String get settingsSecurity => 'Bezpieczeństwo';

  @override
  String get settingsBackup => 'Kopia zapasowa';

  @override
  String get settingsProtectBackup => 'Kopia zapasowa';

  @override
  String get settingsBackupNotYet => 'Jeszcze nie';

  @override
  String get settingsBackupToday => 'Dzisiaj';

  @override
  String get settingsBackupYesterday => 'Wczoraj';

  @override
  String settingsBackupDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dnia temu',
      many: '$count dni temu',
      few: '$count dni temu',
      one: '$count dzień temu',
    );
    return '$_temp0';
  }

  @override
  String get settingsVoice => 'Głos';

  @override
  String get settingsAbout => 'O aplikacji';

  @override
  String get wallpaperGradients => 'Gradienty';

  @override
  String get wallpaperPatterns => 'Wzory';

  @override
  String get wallpaperMoods => 'Nastroje';

  @override
  String get confirmSheetKeep => 'Zostaw';

  @override
  String get confirmSheetSave => 'Zapisz';

  @override
  String get confirmSheetCancel => 'Anuluj';

  @override
  String get bridgesFoundAVolunteer => 'Znaleziono wolontariusza, łączę';

  @override
  String get bridgesScanABridgeCode => 'Zeskanuj kod mostka';

  @override
  String get settingsBridgesForNetworksThat =>
      'Mostki, dla sieci, które blokują Tor';

  @override
  String get bridgesCouldNotReachTheTor =>
      'Nie udało się połączyć z Tor Project';

  @override
  String get torBootSplashConnect => 'Połącz';

  @override
  String get bridgesOffline => 'Offline';

  @override
  String get bridgesNothingGotThrough => 'Nic się nie przebiło';

  @override
  String get bridgesPasteABridge => 'Wklej mostek';

  @override
  String get bridgesKryfoCanAskThe =>
      'Kryfo może poprosić Tor Project o mostek, żeby to obejść.';

  @override
  String get bridgesNotNeededRightNow => 'Teraz niepotrzebne';

  @override
  String get bridgesBuiltInBridges => 'Wbudowane mostki';

  @override
  String get bridgesKryfoCanGetAround =>
      'Kryfo umie teraz obchodzić blokady Tor';

  @override
  String get bridgesThatSNotABridge => 'To nie jest linia mostka';

  @override
  String get transportBridgeError => 'Ostatni błąd';

  @override
  String get bridgesDirect => 'Bezpośrednio';

  @override
  String get bridgesAskingTheTorProject => 'Pytam Tor Project, co tu działa…';

  @override
  String get bridgesNoneOfTheseAre =>
      'Żadna z tych linii nie jest mostkiem, który Kryfo rozumie.';

  @override
  String get bridgesAutomatic => 'Automatycznie';

  @override
  String get bridgesStraightToTor => 'Prosto do Tor, bez mostka';

  @override
  String get bridgesKryfoConnectsAsSoon =>
      'Kryfo połączy się, gdy tylko wrócisz do sieci.';

  @override
  String get bridgesMore => 'Więcej';

  @override
  String bridgesTryingAnotherWayOf(String attempt, String attempts) {
    return 'Próbuję inaczej… ($attempt z $attempts)';
  }

  @override
  String get bridgesLookingForAVolunteer => 'Szukam wolontariusza';

  @override
  String get bridgesFastestWhereTorIsnt =>
      'Najszybsze tam, gdzie Tor nie jest blokowany. Kryfo nigdy nie łączy się poza Tor.';

  @override
  String get transportBridgePhase => 'Faza';

  @override
  String get bridgesAsleepBetweenCheckIns => 'Śpi między sprawdzeniami';

  @override
  String get bridgesThroughABridge => 'Przez mostek';

  @override
  String get bridgesBuiltIn => 'wbudowany';

  @override
  String get bridgesPasteOrScanALineDesk =>
      'Wklej linię od Tor Project albo od kogoś, komu ufasz.';

  @override
  String get bridgesDetails => 'Szczegóły';

  @override
  String get transportBridgeMode => 'Mostki';

  @override
  String get bridgesYourBridgeCouldNot => 'Twój mostek nie mógł się uruchomić';

  @override
  String get bridgesKryfoStaysOfflineRather =>
      'Kryfo zostaje offline, zamiast łączyć się bez niego.';

  @override
  String get bridgesSignInToThisWifi => 'Zaloguj się do tego Wi-Fi';

  @override
  String get bridgesThisNetworkWantsA =>
      'Ta sieć najpierw wymaga logowania. Gdy się zalogujesz, Kryfo się połączy.';

  @override
  String get bridgesThisNetworkWantsADesk =>
      'Ta sieć najpierw wymaga logowania. Zaloguj się w przeglądarce albo sprawdź połączenie sieciowe komputera. Gdy się zalogujesz, Kryfo się połączy.';

  @override
  String get bridgesWaitingForWifiSignIn => 'Czekam na logowanie do Wi-Fi';

  @override
  String get bridgesOpenWifiSettings => 'Otwórz ustawienia Wi-Fi';

  @override
  String get bridgesUsingBuiltIn => 'Używam wbudowanych mostków';

  @override
  String get bridgesUsingSnowflake => 'Używam Snowflake';

  @override
  String get bridgesUsingTorProject => 'Używam mostków od Tor Project';

  @override
  String get bridgesBridgeRemoved => 'Mostek usunięty';

  @override
  String get bridgesUndo => 'Cofnij';

  @override
  String bridgesRemoveBridgeN(String n) {
    return 'Usuń mostek $n';
  }

  @override
  String get bridgesTurnOnAutomatic => 'Włącz tryb automatyczny';

  @override
  String get bridgesPasteABridgeLine => 'Wklej linię mostka';

  @override
  String get bridgesInUse => 'W użyciu';

  @override
  String get bridgesPasteTheLineThey =>
      'Wklej linię mostka albo zeskanuj jej kod. Bierz linie od Tor Project albo od osób, które znasz.';

  @override
  String get bridgesYouReOnAMode =>
      'Twój tryb nie używa Tor. Te wybory zadziałają, gdy wrócisz.';

  @override
  String get bridgesPasteOrScanALine =>
      'Wklej lub zeskanuj linię od Tor Project albo od kogoś, komu ufasz.';

  @override
  String get bridgesNothingYet => 'Jeszcze nic';

  @override
  String get torBootSplashIfTorIsBlocked =>
      'Jeśli Tor jest u ciebie zablokowany lub obserwowany, Kryfo może zacząć przez mostek.';

  @override
  String get bridgesScanACode => 'Zeskanuj kod';

  @override
  String get bridgesSwitchToAutomatic => 'Przełącz na automatyczny';

  @override
  String get torBootSplashTorIsBlockedHere =>
      'Tor jest tu zablokowany lub obserwowany';

  @override
  String get torBootSplashStartThroughABridge => 'Zacznij przez mostek';

  @override
  String get torBootSplashNeverTriesTorPlainly =>
      'Kryfo nigdy nie próbuje tu zwykłego połączenia z Tor. Znajduje działający mostek, albo za chwilę możesz wybrać własny.';

  @override
  String get bridgesTryingAnotherWay => 'Próbuję inaczej…';

  @override
  String get bridgesFindingAWayIn => 'Szukam drogi…';

  @override
  String get bridgesGoesThroughAVolunteer =>
      'Idzie przez komputer wolontariusza. Trudno zablokować, powoli startuje.';

  @override
  String get bridgesTorSeemsBlocked => 'Tor wygląda na zablokowany w tej sieci';

  @override
  String get bridgesTorIsBlockedOnThis => 'Tor jest zablokowany w tej sieci';

  @override
  String bridgesKryfoCouldNotRead(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Kryfo nie umie odczytać $countString z tych linii',
      many: 'Kryfo nie umie odczytać $countString z tych linii',
      few: 'Kryfo nie umie odczytać $countString z tych linii',
      one: 'Kryfo nie umie odczytać $countString z tych linii',
    );
    return '$_temp0';
  }

  @override
  String get bridgesTorNoBridge => 'Tor, bez mostka';

  @override
  String get bridgesKryfoFindsAWay =>
      'Kryfo znajdzie drogę, która u ciebie działa.';

  @override
  String get bridgesTorVpnLine =>
      'W VPN-ie Tor, takim jak Orbot, Kryfo zaczyna od mostka.';

  @override
  String get bridgesThisBridgeIsnTGetting => 'Ten mostek się nie przebija';

  @override
  String get bridgesBridgesTheTorProject =>
      'Mostki, które dał ci wcześniej Tor Project.';

  @override
  String get bridgesConnectingDots => 'Łączenie…';

  @override
  String get bridgesNotNow => 'Nie teraz';

  @override
  String get bridgesObfs4BridgesThatCome =>
      'Mostki dołączone do Kryfo (obfs4). Szybko je wypróbować, często są blokowane.';

  @override
  String get bridgesYourNetworkMayBe => 'Twoja sieć może być ograniczona';

  @override
  String get bridgesCheckingForMessages => 'Sprawdzam wiadomości…';

  @override
  String get bridgesSavedLines => 'Zapisane linie';

  @override
  String get bridgesPasteTheLineTheyDesk =>
      'Wklej linię mostka. Bierz linie od Tor Project albo od osób, które znasz.';

  @override
  String get bridgesPastedLower => 'wklejony';

  @override
  String get bridgesAlmostThere => 'Prawie gotowe';

  @override
  String get bridgesUseThisBridge => 'Użyj tego mostka';

  @override
  String bridgesUseTheseBridges(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Użyj tych $countString mostka',
      many: 'Użyj tych $countString mostków',
      few: 'Użyj tych $countString mostków',
      one: 'Użyj tego $countString mostka',
    );
    return '$_temp0';
  }

  @override
  String get transportBridgeMethod => 'Metoda';

  @override
  String get bridgesPointAtTheBridge => 'Skieruj na kod QR mostka';

  @override
  String get bridgesConnectingThroughYourBridge => 'Łączę przez twój mostek…';

  @override
  String get bridgesThisLineIsTooLong => 'Ta linia jest za długa dla Tor.';

  @override
  String get bridgesAutomaticFindsAWay =>
      'Tryb automatyczny sam znajduje drogę, gdy Tor jest zablokowany. Żeby znaleźć mostek, Kryfo może zapytać Tor Project, jeśli się zgodzisz.';

  @override
  String get bridgesFromTheTorProjectLower => 'od Tor Project';

  @override
  String get bridgesBridgesGoDeadWithout =>
      'Mostki mogą przestać działać bez ostrzeżenia. Tryb automatyczny znajdzie inną drogę.';

  @override
  String get bridgesWhenTorIsBlockedAutomatic =>
      'Gdy Tor jest zablokowany, tryb automatyczny pyta Tor Project, co działa w twoim kraju.';

  @override
  String get bridgesPlainAdvice =>
      'Kryfo wybiera mostki automatycznie. Snowflake i WebTunnel działają w większości miejsc. Jeśli jeden się nie łączy, spróbuj innego, weź prywatny mostek od Tor Project albo poproś znajomego o linię mostka.';

  @override
  String get bridgesPrivateHint =>
      'Nie łączy się automatycznie? Weź prywatny mostek od Tor Project i wklej go poniżej.';

  @override
  String get bridgesPrivateWebsite => 'Strona';

  @override
  String get bridgesPrivateEmail => 'E-mail';

  @override
  String get bridgesPrivateEmailFrom => 'Wyślij z Gmaila albo Riseup';

  @override
  String bridgesPrivateCopy(Object what) {
    return 'Kopiuj $what';
  }

  @override
  String bridgesPrivateCopied(Object what) {
    return 'Skopiowano $what';
  }

  @override
  String bridgesPrivateOpen(Object what) {
    return 'Otwórz $what';
  }

  @override
  String get bridgesWatchedTitle => 'Moja sieć jest obserwowana';

  @override
  String get bridgesWatchedLine => 'Kryfo nigdy nie próbuje Tora bez mostka.';

  @override
  String get bridgesWatchedFastCost => 'Twoja sieć widzi, że używasz Kryfo.';

  @override
  String get bridgesWatchedDirectCost => 'Twoja sieć widzi, że używasz Tora.';

  @override
  String get bridgesWatchedNowAuto =>
      'Teraz Automatycznie, więc Tor zawsze startuje przez mostek';

  @override
  String get bridgesAskTorProject => 'Zapytaj Tor Project';

  @override
  String get bridgesTooLongForTor => 'Za długie dla Tor';

  @override
  String bridgesMethodFrom(String method, String from) {
    return '$method, $from';
  }

  @override
  String get bridgesKryfoCanTUseThis => 'Kryfo nie może użyć tej linii';

  @override
  String get bridgesTryAutomatic => 'Spróbuj automatycznie';

  @override
  String get bridgesNoInternet => 'Brak internetu';

  @override
  String get bridgesConnection => 'Połączenie';

  @override
  String get bridgesGetABridge => 'Zdobądź mostek';

  @override
  String get languageTitle => 'Język';

  @override
  String get languageMatchPhone => 'Jak w telefonie';

  @override
  String get languageMatchPhoneDesk => 'Jak w systemie';

  @override
  String languageMatchPhoneValue(Object language) {
    return 'Jak w telefonie ($language)';
  }

  @override
  String languageMatchPhoneValueDesk(Object language) {
    return 'Jak w systemie ($language)';
  }

  @override
  String get languageRedrawLine =>
      'Kryfo przerysuje się w nowym języku i otworzy twoje czaty.';

  @override
  String languageButton(Object language) {
    return 'Język: $language';
  }

  @override
  String get androidServiceTitle => 'Kryfo działa';

  @override
  String get androidServiceText =>
      'Twoje szyfrowane połączenie jest otwarte, więc wiadomości docierają';

  @override
  String get androidChannelName => 'Stałe połączenie';

  @override
  String get androidChannelDescription =>
      'Utrzymuje połączenie Kryfo, żeby zaszyfrowane wiadomości docierały, gdy aplikacja jest zamknięta. Wyłączenie zatrzymuje dostarczanie.';

  @override
  String get videoViewerPlay => 'Odtwórz';

  @override
  String get videoViewerPause => 'Wstrzymaj';

  @override
  String get videoViewerPlayAgain => 'Odtwórz ponownie';

  @override
  String get videoViewerCannotPlay =>
      'Ten telefon nie może tu odtworzyć tego wideo.';

  @override
  String get videoViewerCannotPlayDesk =>
      'Ten komputer nie może tu odtworzyć tego wideo.';

  @override
  String get videoViewerOpenElsewhere => 'Otwórz w innej aplikacji';

  @override
  String get photoKnowsLookedFor => 'Szukano';

  @override
  String get photoKnowsNotInIt => 'Brak';

  @override
  String get languageNameEn => 'Angielski';

  @override
  String get languageNameDe => 'Niemiecki';

  @override
  String get languageNameFr => 'Francuski';

  @override
  String get languageNameEs => 'Hiszpański';

  @override
  String get languageNamePt => 'Portugalski (Brazylia)';

  @override
  String get languageNameIt => 'Włoski';

  @override
  String get languageNameRu => 'Rosyjski';

  @override
  String get languageNameUk => 'Ukraiński';

  @override
  String get languageNameTr => 'Turecki';

  @override
  String get languageNameZh => 'Chiński (uproszczony)';

  @override
  String get languageNameZhHant => 'Chiński (tradycyjny)';

  @override
  String get languageNameVi => 'Wietnamski';

  @override
  String get languageNameId => 'Indonezyjski';

  @override
  String get languageNameFa => 'Perski';

  @override
  String get languageNameAr => 'Arabski';

  @override
  String get languageNameHi => 'Hindi';

  @override
  String get languageNamePl => 'Polski';

  @override
  String get languageLaterLine =>
      'Możesz to zmienić w każdej chwili w ustawieniach.';

  @override
  String get pollAttach => 'Ankieta';

  @override
  String get pollNewTitle => 'Nowa ankieta';

  @override
  String get pollQuestionHint => 'Zapytaj o coś grupę';

  @override
  String get pollOptionsLabel => 'Odpowiedzi';

  @override
  String pollOptionHint(Object n) {
    return 'Odpowiedź $n';
  }

  @override
  String get pollAddOption => 'Dodaj odpowiedź';

  @override
  String get pollMaxLine => 'Najwyżej dwanaście odpowiedzi.';

  @override
  String get pollMultiple => 'Kilka odpowiedzi';

  @override
  String get pollMultipleLine => 'Można wybrać więcej niż jedną.';

  @override
  String get pollSend => 'Wyślij ankietę';

  @override
  String get pollKind => 'Ankieta';

  @override
  String get pollKindMulti => 'Ankieta · kilka odpowiedzi';

  @override
  String get pollKindClosed => 'Wynik końcowy';

  @override
  String pollVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count głosu',
      many: '$count głosów',
      few: '$count głosy',
      one: '$count głos',
      zero: 'Jeszcze bez głosów',
    );
    return '$_temp0';
  }

  @override
  String get pollVote => 'Głosuj';

  @override
  String get pollTakeBack => 'Cofnij mój głos';

  @override
  String get pollClose => 'Zamknij ankietę';

  @override
  String get pollCloseTitle => 'Zamknąć tę ankietę?';

  @override
  String get pollCloseLine =>
      'Wszyscy zobaczą wynik końcowy i nikt nie zagłosuje już po tym.';

  @override
  String get pollCloseYes => 'Zamknij';

  @override
  String pollPreview(Object question) {
    return 'Ankieta: $question';
  }

  @override
  String get pollWhoVoted => 'Kto zagłosował';

  @override
  String get pollNobody => 'Jeszcze nikt';

  @override
  String get pollYou => 'Ty';

  @override
  String pollOptionA11y(Object option, Object share) {
    return '$option, $share';
  }

  @override
  String get pollPickOne => 'Wybierz jedną';

  @override
  String get pollPickSeveral => 'Wybierz jedną lub więcej';

  @override
  String get searchHint => 'Szukaj czatów i wiadomości';

  @override
  String get searchFilterAll => 'Wszystko';

  @override
  String get searchFilterPhotos => 'Zdjęcia';

  @override
  String get searchFilterVideos => 'Wideo';

  @override
  String get searchFilterFiles => 'Pliki';

  @override
  String get searchFilterLinks => 'Linki';

  @override
  String get searchChats => 'Czaty';

  @override
  String get searchMessages => 'Wiadomości';

  @override
  String get searchIntroTitle => 'Przeszukaj swoje czaty';

  @override
  String get searchIntroLine =>
      'Imiona, słowa, zdjęcia, pliki i linki. Wyszukiwanie działa na tym telefonie i nic nigdzie nie wysyła.';

  @override
  String get searchIntroLineDesk =>
      'Imiona, słowa, zdjęcia, pliki i linki. Wyszukiwanie działa na tym komputerze i nic nigdzie nie wysyła.';

  @override
  String get searchNothing => 'Nic nie znaleziono';

  @override
  String get searchNothingLine => 'Spróbuj innego słowa albo innego filtra.';

  @override
  String searchMatches(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count wyniku',
      many: '$count wyników',
      few: '$count wyniki',
      one: '$count wynik',
    );
    return '$_temp0';
  }

  @override
  String searchMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'jeszcze $count',
      many: 'jeszcze $count',
      few: 'jeszcze $count',
      one: 'jeszcze $count',
    );
    return '$_temp0';
  }

  @override
  String searchFilling(Object share) {
    return 'Dodaję starsze wiadomości · $share';
  }

  @override
  String get searchClear => 'Wyczyść';

  @override
  String get handleShowInSearch => 'Pokazuj mnie w wyszukiwaniu';

  @override
  String get handleShowInSearchLine =>
      'Każdy może znaleźć tę nazwę użytkownika i do ciebie napisać.';

  @override
  String handleShownAs(Object name) {
    return 'Widoczne jako $name';
  }

  @override
  String get handleNameInSearch => 'Nazwa w wyszukiwaniu';

  @override
  String get handleNameInSearchLine =>
      'Opcjonalnie. Pojawia się obok twojej nazwy użytkownika, gdy ktoś szuka. Każdy może znaleźć tę nazwę i do ciebie napisać.';

  @override
  String get handleNameHint => 'Twoje imię albo zostaw puste';

  @override
  String get handleShowMe => 'Pokaż mnie';

  @override
  String get handleSearchOff => 'Nie ma cię już w wyszukiwaniu';

  @override
  String handleSearchOn(Object handle) {
    return 'Jesteś w wyszukiwaniu jako @$handle';
  }

  @override
  String get handleRegistryFailed =>
      'Nie udało się połączyć z rejestrem.\nSpróbuj za minutę.';

  @override
  String get handleStillReaching =>
      'Wciąż łączę z rejestrem.\nPrzez Tor może to chwilę potrwać.';

  @override
  String get handleSearchNeedsTor =>
      'Wyszukiwanie nazw wymaga Tor. W międzyczasie dodawaj przez QR albo link.';

  @override
  String get handleCheckClock =>
      'Sprawdź datę i godzinę w telefonie i spróbuj ponownie.';

  @override
  String get handleCheckClockDesk =>
      'Sprawdź datę i godzinę w komputerze i spróbuj ponownie.';

  @override
  String get searchPeople => 'Ludzie';

  @override
  String searchPeopleAsk(Object query) {
    return 'Szukaj „$query” wśród publicznych nazw';
  }

  @override
  String get searchPeopleLine =>
      'Pytanie idzie przez Tor. Rejestr niczego nie zapisuje.';

  @override
  String get searchPeopleNone => 'Żadna publiczna nazwa nie pasuje';

  @override
  String get searchPeopleOffline => 'Tor nie jest jeszcze gotowy';

  @override
  String get searchPeopleBusy =>
      'Za dużo wyszukiwań w tej chwili. Spróbuj za moment.';

  @override
  String get searchPeopleUnreachable => 'Nie udało się połączyć z rejestrem';

  @override
  String get peopleVerified => 'Zweryfikowana nazwa';

  @override
  String get peopleAdd => 'Dodaj';

  @override
  String peopleFingerprint(Object fp) {
    return 'Odcisk klucza · $fp';
  }

  @override
  String get peopleFingerprintLine =>
      'Sprawdź, czy zgadza się z tym, co ta osoba widzi u siebie.';

  @override
  String get peopleAdding => 'Dodaję…';

  @override
  String handleNobodyHasClaimed(Object handle) {
    return 'Nazwa $handle jest wolna';
  }

  @override
  String get handleThatHandleIsTaken => 'Ta nazwa użytkownika jest zajęta';

  @override
  String get pinPickDifferent => 'Wybierz inny PIN';

  @override
  String get lockFingerAfterPin =>
      'Wpisz PIN raz, żeby znów używać odcisku palca.';

  @override
  String get lockFingerLockedOut =>
      'Za dużo prób odciskiem palca. Użyj PIN-u albo odblokuj raz telefon jego własną blokadą ekranu, żeby znów użyć odcisku.';

  @override
  String get lockFingerRefused =>
      'Twój telefon nie zachował odblokowania odciskiem palca dla Kryfo, więc jest wyłączone. Twój PIN nadal działa.';

  @override
  String get lockFingerTryAgain =>
      'Telefon był akurat zajęty. Spróbuj jeszcze raz odciskiem palca albo użyj PIN-u.';

  @override
  String get pinsFingerRefused =>
      'Twój telefon nie włączył odblokowania odciskiem palca dla Kryfo. Twój PIN nadal działa.';

  @override
  String get pinsAdvanced => 'Ochrona zaawansowana';

  @override
  String get pinsAdvancedLine =>
      'Na wypadek, gdy ktoś zmusza cię do odblokowania telefonu.';

  @override
  String get pinsAdvancedLineDesk =>
      'Na wypadek, gdy ktoś zmusza cię do odblokowania komputera.';

  @override
  String get pinsWipeLine =>
      'Wpisany na ekranie blokady wymazuje Kryfo z tego telefonu.';

  @override
  String get pinsWipeLineDesk =>
      'Wpisany na ekranie blokady wymazuje Kryfo z tego komputera.';

  @override
  String get pinsDecoyPin => 'PIN przynęty';

  @override
  String get pinsDecoyLine =>
      'Otwiera puste Kryfo, jakby dopiero zainstalowane.';

  @override
  String get pinsChangeDecoyPin => 'Zmień PIN przynęty';

  @override
  String get pinsRemoveTheDecoyPin => 'Usunąć PIN przynęty?';

  @override
  String get pinsTheDecoyGoes =>
      'Puste Kryfo, które otwiera, zniknie razem z nim.';

  @override
  String get pinsTurnOffWithDecoy =>
      'Znikną wszystkie PIN-y, przynęta i jej Kryfo oraz wszystkie ukryte czaty. Każdy, kto ma twój telefon, otworzy Kryfo jako ty.';

  @override
  String get pinsTurnOffWithDecoyDesk =>
      'Znikną wszystkie PIN-y, przynęta i jej Kryfo oraz wszystkie ukryte czaty. Każdy przy twoim komputerze otworzy Kryfo jako ty.';

  @override
  String get pinsHowThisWorks => 'Jak to działa';

  @override
  String get flowEnterYourPin => 'Wpisz swój PIN';

  @override
  String get flowEnterYourPinLine => 'Ten, który otwiera Kryfo.';

  @override
  String get flowWipeTitle => 'PIN wymazania';

  @override
  String get flowWipe1 =>
      'Wpisany na ekranie blokady zamiast twojego PIN-u wymazuje Kryfo z tego telefonu i je zamyka. Dla kogoś, kto patrzy, aplikacja po prostu się zamknęła.';

  @override
  String get flowWipe1Desk =>
      'Wpisany na ekranie blokady zamiast twojego PIN-u wymazuje Kryfo z tego komputera i je zamyka. Dla kogoś, kto patrzy, aplikacja po prostu się zamknęła.';

  @override
  String get flowWipe2 =>
      'Zabiera ze sobą każdy czat i twoją tożsamość, a także przynętę, jeśli ją masz.';

  @override
  String get flowWipeChoose => 'Wybierz PIN wymazania';

  @override
  String get flowWipeDone => 'PIN wymazania ustawiony';

  @override
  String get flowWipeDoneLine =>
      'Nic na ekranie blokady nie zdradza, że istnieje.';

  @override
  String get flowDecoyTitle => 'PIN przynęty';

  @override
  String get flowDecoy1 => 'Otwiera puste Kryfo, jakby dopiero zainstalowane.';

  @override
  String get flowDecoyFinger =>
      'Gdy ustawiony jest PIN przynęty, ta aplikacja otwiera się tylko twoim PIN-em. Jeśli w przynęcie włączony jest odcisk palca, palec otwiera przynętę, nigdy tę aplikację.';

  @override
  String get flowDecoyDigits =>
      'Użyj tylu cyfr, ile ma twój PIN, bo każdy, kto patrzy, może policzyć kropki.';

  @override
  String get flowDecoyShade =>
      'Powiadomienia, które już są na liście, już zostały zobaczone. Gdy przynęta jest otwarta, nowe się nie pokazują.';

  @override
  String get flowDecoyShadeDesk =>
      'Powiadomienia, które już są na ekranie, już zostały zobaczone. Gdy przynęta jest otwarta, nowe się nie pokazują.';

  @override
  String get flowDecoyChoose => 'Wybierz PIN przynęty';

  @override
  String get flowDecoyDone => 'PIN przynęty ustawiony';

  @override
  String get flowDecoyDoneLine =>
      'Wpisz go na ekranie blokady, żeby otworzyć puste Kryfo. Żeby z niego wyjść, przełącz się na coś innego i wpisz swój PIN.';

  @override
  String get flowLaw =>
      'W niektórych krajach odmowa odblokowania telefonu albo ukrywanie danych przed urzędnikami jest przestępstwem samo w sobie. Poznaj prawo tam, dokąd jedziesz.';

  @override
  String get flowLawDesk =>
      'W niektórych krajach odmowa odblokowania urządzenia albo ukrywanie danych przed urzędnikami jest przestępstwem samo w sobie. Poznaj prawo tam, dokąd jedziesz.';

  @override
  String get howWipe =>
      'Wpisany na ekranie blokady PIN wymazania usuwa każdy czat, twoją tożsamość i przynętę, a potem zamyka Kryfo. Działa nawet wtedy, gdy klawiatura jest wstrzymana po błędnych próbach.';

  @override
  String get howDecoy =>
      'PIN przynęty otwiera drugie, puste Kryfo z własnymi trzema słowami. Wiadomości do twojego prawdziwego Kryfo nadal po cichu docierają pod spodem. Żeby wyjść z przynęty, przełącz się na coś innego i wpisz swój PIN.';

  @override
  String get flowNotSet => 'Nie udało się ustawić. Spróbuj ponownie.';

  @override
  String get pinsHiddenChats => 'Ukryte czaty';

  @override
  String get pinsHiddenLine =>
      'Wybrane czaty pozostają niewidoczne, dopóki nie wpiszesz PIN-u ukrytych czatów: nie ma ich na liście, w wyszukiwaniu ani w powiadomieniach.';

  @override
  String get pinsSetUp => 'Ustaw';

  @override
  String get pinsChangeHiddenPin => 'Zmień PIN ukrytych czatów';

  @override
  String get pinsHideMoreChats => 'Ukryj więcej czatów';

  @override
  String get pinsRemoveHiddenChats => 'Usuń ukryte czaty';

  @override
  String get pinsRemoveHiddenTitle => 'Usunąć ukryte czaty?';

  @override
  String get pinsRemoveHiddenLine =>
      'Wrócą na twoją listę czatów, a PIN ukrytych czatów przestanie cokolwiek otwierać.';

  @override
  String get pinsTurnOffHiddenFirst =>
      'Ukryte czaty wymagają blokady aplikacji. Najpierw je usuń, a wrócą na twoją listę czatów.';

  @override
  String get flowVaultTitle => 'Ukryte czaty';

  @override
  String get flowVault1 =>
      'Wybierz czaty i grupy do ukrycia. Twój PIN otwiera Kryfo bez nich. PIN ukrytych czatów otwiera wszystko, łącznie z ukrytymi czatami.';

  @override
  String get flowVault2 =>
      'Gdy są niewidoczne, nigdy nie powiadamiają ani nie pokazują plakietki. Ich wiadomości nadal docierają i czekają, zapieczętowane, na PIN ukrytych czatów.';

  @override
  String get flowVaultFinger =>
      'Twój odcisk palca otwiera Kryfo bez ukrytych czatów.';

  @override
  String get flowVaultDigits =>
      'Daj też swojemu PIN-owi sześć cyfr albo więcej, bo każdy, kto patrzy, może policzyć kropki.';

  @override
  String get flowVaultReplace =>
      'To zastępuje ukryte czaty, które ten telefon już ma.';

  @override
  String get flowVaultReplaceDesk =>
      'To zastępuje ukryte czaty, które ten komputer już ma.';

  @override
  String get flowVaultChoose => 'Wybierz PIN ukrytych czatów';

  @override
  String get flowVaultChooseLine => 'Sześć cyfr albo więcej.';

  @override
  String get flowEnterHiddenPinLine => 'Ten, który otwiera twoje ukryte czaty.';

  @override
  String get flowVaultForgetTitle => 'Zapamiętaj ten PIN';

  @override
  String get flowVaultForget =>
      'Jeśli zapomnisz ten PIN, twoje ukryte czaty przepadną na zawsze. Nikt ich nie odzyska.';

  @override
  String get flowVaultForgetOk => 'Rozumiem';

  @override
  String get flowVaultPickTitle => 'Wybierz czaty do ukrycia';

  @override
  String get flowVaultPickLine =>
      'Znikną teraz z twojej listy czatów. PIN ukrytych czatów przywraca je do widoku.';

  @override
  String flowVaultPickButton(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ukryj $countString czatu',
      many: 'Ukryj $countString czatów',
      few: 'Ukryj $countString czaty',
      one: 'Ukryj $countString czat',
      zero: 'Na razie nic nie ukrywaj',
    );
    return '$_temp0';
  }

  @override
  String get flowVaultPickEmpty => 'Nie ma jeszcze czatów do ukrycia.';

  @override
  String get flowVaultBackupTitle => 'Zrobić teraz kopię zapasową?';

  @override
  String get flowVaultBackupLine =>
      'Kopia zrobiona teraz zawiera też ukryte czaty, pod własnym hasłem. Jeśli zapomnisz PIN ukrytych czatów, to jedyna droga, żeby je odzyskać.';

  @override
  String get flowVaultBackupNow => 'Zrób kopię zapasową';

  @override
  String get flowVaultNotNow => 'Nie teraz';

  @override
  String get flowVaultDone => 'Ukryte czaty ustawione';

  @override
  String get flowVaultDoneLine =>
      'Wpisz PIN ukrytych czatów na ekranie blokady, żeby je zobaczyć. Przełącz się na coś innego, a znów znikną z widoku.';

  @override
  String get flowVaultChanged => 'PIN ukrytych czatów zmieniony';

  @override
  String get flowVaultChangedLine =>
      'Ukryte czaty otwierają się teraz przy użyciu nowego PIN-u. Stary kod nie daje już dostępu do niczego.';

  @override
  String get howVault =>
      'Twój PIN do ukrytych czatów uruchamia Kryfo w trybie poufnym; zwykły PIN i biometria otwierają wersję bez nich. Ponowne skonfigurowanie ukrytych czatów nadpisze dotychczasowe dane na telefonie. Zapomnienie tego PIN-u oznacza ich trwałą utratę.';

  @override
  String get howVaultDesk =>
      'Twój PIN do ukrytych czatów uruchamia Kryfo w trybie poufnym; zwykły PIN otwiera wersję bez nich. Ponowne skonfigurowanie ukrytych czatów nadpisze dotychczasowe dane na komputerze. Zapomnienie tego PIN-u oznacza ich trwałą utratę.';

  @override
  String get chatHide => 'Ukryj czat';

  @override
  String get groupHide => 'Ukryj grupę';

  @override
  String get chatHidden => 'Ukryty';

  @override
  String get chatHiddenToast => 'Ukryto na liście czatów';

  @override
  String get chatShowInList => 'Pokaż na liście czatów';

  @override
  String get stickerOpen => 'Naklejki';

  @override
  String get stickerRecent => 'Ostatnie';

  @override
  String stickerA11y(String emoji) {
    return 'Naklejka $emoji';
  }

  @override
  String get stickerRemoveRecent => 'Usuń z ostatnich';

  @override
  String get stickerCouldNotLoad => 'Nie udało się wczytać naklejek';

  @override
  String get stickerLabel => 'Naklejka';

  @override
  String get timedMessageLabel => 'Wiadomość czasowa';

  @override
  String get stickerNewer => 'Z nowszego Kryfo';

  @override
  String get devLinkMismatch =>
      'Ten link podaje się za Marios, ale jego klucz się nie zgadza. Nie dodano go.';

  @override
  String get devName => 'Marios';

  @override
  String get devRowTitle => 'Marios · twórca Kryfo';

  @override
  String get devWelcome =>
      'Cześć, jestem Marios, tworzę Kryfo. Pisz o wszystkim: błędy, pomysły, pytania. Czytam wszystko.';

  @override
  String get devPinned => 'Przypięty w Kryfo';

  @override
  String get devAnonymous => 'Anonimowo';

  @override
  String get devAboutLine =>
      'Klucz Mariosa jest wbudowany w Kryfo. Każda wiadomość od niego jest z nim sprawdzana, więc nikt inny nie może pisać jako on.';

  @override
  String get devKeyLabel => 'Jego klucz';

  @override
  String get devDeleteLine => 'Każda wiadomość zniknie, a czat nie wróci.';

  @override
  String get devDeleteLineAnon =>
      'Każda wiadomość i nazwa zrobiona dla tego czatu znikną, a czat nie wróci.';

  @override
  String get devDeleteLineBack =>
      'Każda wiadomość zniknie, a czat nie wróci. To, co wysłano, zostanie też cofnięte z telefonu Mariosa.';

  @override
  String get devDeleteLineAnonBack =>
      'Każda wiadomość i nazwa zrobiona dla tego czatu znikną, a czat nie wróci. To, co wysłano, zostanie też cofnięte z telefonu Mariosa.';

  @override
  String devDeleteNotTakenBack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Nie udało się cofnąć $count wiadomości z telefonu Mariosa',
      many: 'Nie udało się cofnąć $count wiadomości z telefonu Mariosa',
      few: 'Nie udało się cofnąć $count wiadomości z telefonu Mariosa',
      one: 'Nie udało się cofnąć $count wiadomości z telefonu Mariosa',
    );
    return '$_temp0';
  }

  @override
  String get devDeleteFailed => 'Nie udało się usunąć czatu. Spróbuj ponownie.';

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
  String get settingsWriteToMarios => 'Napisz do Mariosa';

  @override
  String get settingsWriteToMariosHint => 'Błędy, pomysły, pytania';

  @override
  String get seenDevChat => 'Czat z Mariosem';

  @override
  String get seenDevChatCell => 'Jeśli napiszesz';

  @override
  String get seenDevChatLine =>
      'Nic, dopóki nie napiszesz. Potem to, co wyślesz, i twoje trzy słowa, chyba że piszesz anonimowo.';

  @override
  String get devWriteAnonymously => 'Pisz anonimowo';

  @override
  String get devUseMyWords => 'Użyj moich trzech słów';

  @override
  String get devWhoSeesWhat => 'Jak to działa';

  @override
  String get devWhoWords =>
      'Z twoimi trzema słowami to czat jak każdy inny: Marios może odpisać, a twoja twarz i odznaka wspierającego zostają przy tobie.';

  @override
  String get devWhoAnon =>
      'Anonimowo Kryfo tworzy nową nazwę i klucze tylko dla tego czatu. Zostają na tym telefonie i nigdy nie są używane nigdzie indziej.';

  @override
  String get devWhoAnonDesk =>
      'Anonimowo Kryfo tworzy nową nazwę i klucze tylko dla tego czatu. Zostają na tym komputerze i nigdy nie są używane nigdzie indziej.';

  @override
  String get devWhoNothingYet =>
      'Nic nie opuszcza twojego telefonu, dopóki nie wyślesz pierwszej wiadomości.';

  @override
  String get devWhoNothingYetDesk =>
      'Nic nie opuszcza twojego komputera, dopóki nie wyślesz pierwszej wiadomości.';

  @override
  String get devWhoChoiceStays => 'Twój wybór zostaje przy tym czacie.';

  @override
  String get devUpdateToWrite => 'Zaktualizuj Kryfo, żeby napisać do Mariosa.';

  @override
  String get devKeyCheckFailed =>
      'Nie udało się sprawdzić klucza Mariosa. Nic nie zostało wysłane.';

  @override
  String get devLockLine =>
      'Marios to przeczyta. Więcej napiszesz, gdy odpowie.';

  @override
  String get devNewKey => 'Marios ma nowy klucz';

  @override
  String get devStartNewChat => 'Zacznij nowy czat';

  @override
  String get devKeyRetired =>
      'Ten klucz wycofano. Tu nie da się już nic wysłać ani odebrać.';

  @override
  String get devNamelessLine =>
      'Nazwa zrobiona dla tego czatu zostaje na telefonie, na którym powstała, więc tutaj można go tylko czytać.';

  @override
  String get devNamelessLineDesk =>
      'Nazwa zrobiona dla tego czatu zostaje na urządzeniu, na którym powstała, więc tutaj można go tylko czytać.';

  @override
  String get devStartNewLine =>
      'Każda wiadomość stąd zniknie i otworzy się nowy czat.';

  @override
  String get devVoiceDisguised => 'W tym czacie twój głos jest zmieniany';

  @override
  String get devChatOptions => 'Opcje czatu';

  @override
  String get requestsSomeoneNew => 'Ktoś nowy';

  @override
  String get nameTakenTitle => 'Ktoś inny używa tych słów';

  @override
  String get nameTakenLine =>
      'Ktoś tutaj dostał te słowa z prośby, przedstawienia albo grupy, z innym kluczem, i nie zostały sprawdzone. Słowa można skopiować. Jeśli ten link jest od osoby, którą znasz, użyj go, a potem porównajcie numer bezpieczeństwa.';

  @override
  String get nameTakenChatLine =>
      'Twój czat pod tymi słowami pochodzi z prośby, przedstawienia albo grupy, z innym kluczem, i nie został sprawdzony. Słowa można skopiować. Jeśli ten link jest od osoby, którą znasz, użyj go: tamten czat zostanie usunięty, a numer bezpieczeństwa porównacie w nowym. Nie wiesz, skąd jest link? Zostaw ten, który masz.';

  @override
  String get nameTakenDeletedLine =>
      'Usunięto tu czat pod tymi słowami, który działał na innym kluczu. Jeśli ten link jest od osoby, którą znasz, użyj go, a potem porównajcie numer bezpieczeństwa.';

  @override
  String get nameTakenTombLine =>
      'Usunięto z tego telefonu kogoś pod tymi słowami, bo ta osoba podszywała się pod kogoś innego. Jeśli ten link jest od osoby, którą znasz, użyj go, a potem porównajcie numer bezpieczeństwa.';

  @override
  String get nameTakenTombLineDesk =>
      'Usunięto z tego komputera kogoś pod tymi słowami, bo ta osoba podszywała się pod kogoś innego. Jeśli ten link jest od osoby, którą znasz, użyj go, a potem porównajcie numer bezpieczeństwa.';

  @override
  String get nameTakenUse => 'Użyj tego linku';

  @override
  String get nameTakenKeep => 'Zostaw ten, który mam';

  @override
  String get appYourOwnInvite =>
      'To twoje własne zaproszenie. Udostępnij je komuś innemu, żeby się połączyć.';

  @override
  String appLinkNeedsUpdate(Object id) {
    return '$id musi zaktualizować Kryfo, zanim dodacie się nawzajem.';
  }

  @override
  String appLinkWordsTaken(Object id) {
    return 'Ktoś tutaj już nazywa się $id, z innym kluczem. Porównajcie numer bezpieczeństwa, żeby wiedzieć, kto jest kim. Nic nie zostało dodane.';
  }

  @override
  String appLinkWordsVerified(Object id) {
    return 'Zweryfikowano $id z innym kluczem. Nic nie zostało dodane.';
  }

  @override
  String appTheyAreBlocked(Object id) {
    return '$id jest zablokowany. Odblokuj w Zablokowanych w Ustawieniach, żeby dodać ponownie.';
  }

  @override
  String get notThemNumbersDiffer => 'Numery są różne';

  @override
  String get notThemLine =>
      'Jeśli numery naprawdę się różnią, ktoś inny może używać tej nazwy albo być pomiędzy wami.';

  @override
  String get notThemButton => 'To nie ta osoba';

  @override
  String get notThemSheetTitle => 'Usunąć ten kontakt i zablokować jego klucz?';

  @override
  String get notThemSheetLine =>
      'Czat, jego wiadomości i pliki znikną z tego telefonu. Te trzy słowa wrócą tylko z linku lub kodu, który dodasz samodzielnie. Porównaj numer bezpieczeństwa z każdym, kogo dodajesz.';

  @override
  String get notThemSheetLineDesk =>
      'Czat, jego wiadomości i pliki znikną z tego komputera. Te trzy słowa wrócą tylko z linku lub kodu, który dodasz samodzielnie. Porównaj numer bezpieczeństwa z każdym, kogo dodajesz.';

  @override
  String get notThemRemove => 'Usuń i zablokuj';

  @override
  String get notThemDone => 'Usunięto, a klucz jest zablokowany';

  @override
  String get groupAdminGoneLine =>
      'Administrator tej grupy został usunięty z tego telefonu. Zmiany w grupie już do ciebie nie docierają.';

  @override
  String get groupAdminGoneLineDesk =>
      'Administrator tej grupy został usunięty z tego komputera. Zmiany w grupie już do ciebie nie docierają.';

  @override
  String get blockedKey => 'Zablokowany klucz';

  @override
  String get appKeyBlocked =>
      'Ten klucz jest zablokowany. Odblokuj go w Ustawieniach, w sekcji Zablokowane, żeby go dodać.';

  @override
  String get devLinkGone =>
      'Usunięto czat z Mariosem. Żeby zacząć nowy, stuknij Napisz do Mariosa w Ustawieniach.';

  @override
  String lockTooManyTriesFor(Object left) {
    return 'Za dużo prób · $left';
  }

  @override
  String get gifBadge => 'GIF';

  @override
  String get gifPlay => 'Odtwórz GIF';

  @override
  String get gifSentInside => 'Wysłany wewnątrz twojej wiadomości';

  @override
  String get gifOptInTitle => 'Szukaj GIF-ów prywatnie';

  @override
  String get gifOptInLead =>
      'Wyszukiwanie GIF-ów wymaga internetu, więc jest wyłączone, dopóki go nie zechcesz.';

  @override
  String get gifOptInOverTor => 'Wyszukiwane przez Tor';

  @override
  String get gifOptInThroughKryfo => 'Wyszukiwane przez Kryfo';

  @override
  String get gifOptInAsksForYou =>
      'Serwer Kryfo pyta usługę GIF za ciebie. Usługa nigdy cię nie widzi, a serwer nie zapisuje, czego szukano.';

  @override
  String get gifOptInAsksForYouFast =>
      'Serwer Kryfo pyta usługę GIF za ciebie, więc usługa nigdy cię nie widzi. W trybie Szybki nasz serwer widzi twój adres IP podczas wyszukiwania i nie zapisuje ani jego, ani tego, czego szukano.';

  @override
  String get gifOptInLikeAPhoto =>
      'GIF jest wysyłany zaszyfrowany, jak zdjęcie. Telefon znajomego niczego nie pobiera.';

  @override
  String get gifOptInOffWhenever => 'Wyłączysz, kiedy chcesz';

  @override
  String get gifOptInWhereToTurnOff =>
      'Ustawienia, Prywatność, Wyszukiwanie GIF. GIF-y z twojego telefonu zawsze działają bez tego.';

  @override
  String get gifOptInWhereToTurnOffDesk =>
      'Ustawienia, Prywatność, Wyszukiwanie GIF. GIF-y z twojego komputera zawsze działają bez tego.';

  @override
  String get gifTurnOn => 'Włącz wyszukiwanie GIF';

  @override
  String get gifNotNow => 'Nie teraz';

  @override
  String gifAskOverTor(String brand) {
    return 'Wyszukiwanie GIF idzie przez serwer Kryfo i Tor. $brand nigdy cię nie widzi. Włączyć?';
  }

  @override
  String gifAskThroughKryfo(String brand) {
    return 'Wyszukiwanie GIF idzie prosto do serwera Kryfo, który w trybie Szybki widzi twój adres IP. $brand nigdy cię nie widzi. Włączyć?';
  }

  @override
  String get gifAskTurnOn => 'Włącz';

  @override
  String get gifSearchOff => 'Wyszukiwanie GIF jest wyłączone';

  @override
  String get gifSavedOnPhone =>
      'GIF-y zapisane na telefonie są w karcie *Na tym telefonie*.';

  @override
  String get gifSavedOnPhoneDesk =>
      'GIF-y zapisane na komputerze są w karcie *Na tym komputerze*.';

  @override
  String get gifTab => 'GIF-y';

  @override
  String get gifPhoneTab => 'Na tym telefonie';

  @override
  String get gifPhoneTabDesk => 'Na tym komputerze';

  @override
  String get gifSearchHint => 'Szukaj GIF-ów';

  @override
  String get gifClear => 'Wyczyść wyszukiwanie';

  @override
  String get gifServiceNeverSeesYou => 'Usługa GIF nigdy cię nie widzi';

  @override
  String get gifTrending => 'Popularne';

  @override
  String get gifOffline =>
      'Tor wciąż się łączy. GIF-y pojawią się, gdy zadziała.';

  @override
  String get gifBusy =>
      'Zbyt wiele wyszukiwań w tej chwili. Spróbuj ponownie za chwilę.';

  @override
  String get gifUnreachable => 'Nie udało się połączyć z usługą GIF Kryfo.';

  @override
  String get gifNothingFound => 'Nie znaleziono GIF-ów. Spróbuj innych słów.';

  @override
  String get gifCouldNotLoadMore => 'Nie udało się wczytać więcej';

  @override
  String get gifLoading => 'Wczytuję GIF-y';

  @override
  String get gifCouldNotGet =>
      'Nie udało się pobrać tego GIF-a. Spróbuj ponownie.';

  @override
  String gifPoweredBy(String brand) {
    return 'Obsługiwane przez $brand';
  }

  @override
  String gifNeverSeesYou(String brand) {
    return 'Wyszukiwane przez Kryfo, $brand nigdy cię nie widzi.';
  }

  @override
  String gifTileA11y(String number) {
    return 'GIF $number';
  }

  @override
  String get gifPhoneLine =>
      'GIF-y zapisane na tym telefonie. Nic nie idzie do internetu.';

  @override
  String get gifPhoneLineDesk =>
      'GIF-y zapisane na tym komputerze. Nic nie idzie do internetu.';

  @override
  String get gifPhoneChoose => 'Wybierz GIF';

  @override
  String get settingsGifSearch => 'Wyszukiwanie GIF';

  @override
  String get settingsGifSearchHint =>
      'Wyłączone, dopóki go nie włączysz. Serwer Kryfo szuka za ciebie, więc usługa GIF nigdy cię nie widzi.';

  @override
  String get shareChooseChat => 'Wybierz czat';

  @override
  String get shareNoChats => 'Jeszcze brak czatów';

  @override
  String get shareNoOne => 'Nie ma komu udostępnić';

  @override
  String get shareCheckPhoto => 'Sprawdź to zdjęcie';

  @override
  String get shareCheckVideo => 'Sprawdź ten film';

  @override
  String get shareSendCleanLine => 'Ukryte dane znikają przed wysłaniem';

  @override
  String get shareCheckLine => 'Zobacz, co zawiera, na tym telefonie';

  @override
  String shareFileOverLimit(String max) {
    return 'Pliki mogą mieć do $max. Ten jest większy.';
  }

  @override
  String shareSendFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Wysłać te $count plików?',
      few: 'Wysłać te $count pliki?',
      one: 'Wysłać ten plik?',
    );
    return '$_temp0';
  }

  @override
  String sharePhotoTooBig(String size, String max) {
    return 'To zdjęcie ma $size. Kryfo przygotowuje zdjęcia do $max.';
  }

  @override
  String sharePhotoOverLimit(String size, String max) {
    return 'Po zmniejszeniu to zdjęcie ma nadal $size. Pliki w tym czacie mogą mieć do $max.';
  }

  @override
  String get valveStillConnecting =>
      'Wciąż łączę… Twoje wiadomości wyjdą, gdy tylko połączenie wróci.';

  @override
  String get valveCouldNotReconnect =>
      'Kryfo nie mogło połączyć się ponownie. Ponowne uruchomienie to naprawi i zachowa twoje wiadomości.';

  @override
  String get valveRestartKryfo => 'Uruchom Kryfo ponownie';

  @override
  String get updateAvailable => 'Dostępna aktualizacja';

  @override
  String updateReady(String version) {
    return 'Kryfo $version jest gotowe do pobrania';
  }

  @override
  String get settingsCheckForUpdates => 'Sprawdzaj aktualizacje';

  @override
  String get settingsCheckForUpdatesHint =>
      'Raz dziennie przez Tor. Pyta kryfo.app o najnowszą wersję i nie wysyła nic o tobie.';

  @override
  String get settingsCheckNow => 'Sprawdź teraz';

  @override
  String get settingsCheckNowBusy => 'Sprawdzam…';

  @override
  String get updateOpenPage => 'Otwórz stronę pobierania';

  @override
  String get updateNewest => 'Masz najnowsze Kryfo';

  @override
  String get updateCouldNotCheck => 'Nie udało się sprawdzić. Spróbuj później.';

  @override
  String get voiceDisguiseHere => 'Zmieniaj tu mój głos';

  @override
  String get chatBlockScreenshots => 'Blokuj zrzuty ekranu';

  @override
  String get chatShotsWhenTheyUpdate =>
      'Dostępne, gdy ta osoba używa najnowszego Kryfo na telefonie';

  @override
  String get chatShotsWhenTheyUpdateDesk => 'Dostępne w Kryfo na Androida';

  @override
  String get chatShotsBothPhones =>
      'Kryfo blokuje zrzuty i nagrywanie ekranu tego czatu na obu telefonach oraz kopiowanie, przekazywanie i zapisywanie waszych wiadomości. Nie powstrzyma aplikacji, które mają dostęp do ekranu, ani telefonu czy aplikacji zmienionych, żeby to obejść.';

  @override
  String get chatShotsBlocksBoth =>
      'Blokuje zrzuty i nagrywanie ekranu na obu telefonach oraz kopiowanie, przekazywanie i zapisywanie waszych wiadomości. Nie powstrzyma aplikacji, które mają dostęp do ekranu, ani telefonu czy aplikacji zmienionych, żeby to obejść.';

  @override
  String get chatShotsBlockedHere => 'Kryfo blokuje zrzuty ekranu w tym czacie';

  @override
  String get chatShotsMenuNote =>
      'Kopiowanie, przekazywanie i zapisywanie wiadomości tej osoby jest w tym czacie wyłączone';

  @override
  String get chatShotsKeptOpen =>
      'Otwieranie plików tej osoby w innych aplikacjach jest w tym czacie wyłączone';

  @override
  String searchKeptMatches(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString wyniku · otwórz czat, żeby je zobaczyć',
      many: '$countString wyników · otwórz czat, żeby je zobaczyć',
      few: '$countString wyniki · otwórz czat, żeby je zobaczyć',
      one: '$countString wynik · otwórz czat, żeby go zobaczyć',
    );
    return '$_temp0';
  }

  @override
  String get savedKeptInChat =>
      'Zapisane z czatu, który blokuje zrzuty ekranu · otwórz czat, żeby to zobaczyć';

  @override
  String get roomShotsMenuNote =>
      'Kopiowanie, przekazywanie i zapisywanie cudzych wiadomości jest w tym pokoju wyłączone';

  @override
  String get roomShotsKeptOpen =>
      'Otwieranie cudzych plików w innych aplikacjach jest w tym pokoju wyłączone';

  @override
  String get chatShotsYouTurnedOn =>
      'Włączono blokadę zrzutów ekranu. Kopiowanie, przekazywanie i zapisywanie waszych wiadomości też jest wyłączone.';

  @override
  String get chatShotsYouTurnedOff => 'Wyłączono blokadę zrzutów ekranu';

  @override
  String get chatNowPostQuantum =>
      'Wiadomości w tym czacie używają teraz szyfrowania postkwantowego';

  @override
  String chatShotsTheyTurnedOn(String name) {
    return '$name włącza blokadę zrzutów ekranu. Kopiowanie, przekazywanie i zapisywanie waszych wiadomości też jest wyłączone.';
  }

  @override
  String chatShotsTheyTurnedOff(String name) {
    return '$name wyłącza blokadę zrzutów ekranu';
  }

  @override
  String get roomShotsBlocked =>
      'Kryfo blokuje zrzuty i nagrywanie ekranu tego pokoju na każdym telefonie w nim oraz kopiowanie, przekazywanie i zapisywanie wiadomości innych. Nie powstrzyma aplikacji, które mają dostęp do ekranu, ani telefonu czy aplikacji zmienionych, żeby to obejść.';

  @override
  String get roomShotsBlockedDesk =>
      'Kopiowanie, przekazywanie i zapisywanie wiadomości innych jest w tym pokoju wyłączone. Kryfo na Androida blokuje też zrzuty i nagrywanie ekranu.';

  @override
  String get roomShotsAlwaysOn =>
      'W pokoju zawsze włączone, na każdym telefonie w nim';

  @override
  String get roomShotsAlwaysOnDesk =>
      'W pokoju zawsze włączone, w Kryfo na Androida';

  @override
  String get homeShotsPerChat =>
      'Blokada zrzutów ekranu działa teraz osobno dla każdego czatu.';

  @override
  String get homeShotsTurnOnForAll => 'Włączyć ją we wszystkich czatach?';

  @override
  String get homeShotsTurnOn => 'Włącz we wszystkich';

  @override
  String get homeShotsLeaveOff => 'Zostaw wyłączone';

  @override
  String get homeShotsTheySeeIt =>
      'Kryfo blokuje je też na drugim telefonie, a kopiowanie, przekazywanie i zapisywanie waszych wiadomości się wyłącza. Druga osoba zobaczy, że to włączono.';

  @override
  String homeShotsTurnedOn(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Kryfo blokuje teraz zrzuty ekranu w $countString czatu',
      many: 'Kryfo blokuje teraz zrzuty ekranu w $countString czatach',
      few: 'Kryfo blokuje teraz zrzuty ekranu w $countString czatach',
      one: 'Kryfo blokuje teraz zrzuty ekranu w $countString czacie',
    );
    return '$_temp0';
  }

  @override
  String get voiceDisguisedHere => 'W tym czacie twój głos jest zmieniany';

  @override
  String get voiceSlideUpToLock => 'Przesuń w górę, żeby zablokować';

  @override
  String get voiceStopRecording => 'Zatrzymaj nagrywanie';

  @override
  String get voiceDeleteNote => 'Usuń wiadomość głosową';

  @override
  String get voiceDisguised => 'Zmieniony';

  @override
  String get voiceYourVoice => 'Twój głos';

  @override
  String get voiceDisguiseThisNote => 'Zmień głos w tej wiadomości';

  @override
  String get voiceNotDisguised =>
      'Nie udało się zmienić głosu w tej wiadomości, więc jej nie wysłano';

  @override
  String get voiceNoRoom =>
      'Za mało wolnego miejsca na tym telefonie. Zwolnij trochę pamięci i spróbuj ponownie.';

  @override
  String get voiceNoRoomDesk =>
      'Za mało wolnego miejsca na tym komputerze. Zwolnij trochę miejsca i spróbuj ponownie.';

  @override
  String get voiceNoRoomNotSent =>
      'Zabrakło wolnego miejsca, żeby zmienić głos w tej wiadomości, więc nie została wysłana';

  @override
  String get voiceDisguising => 'Zmieniam głos';

  @override
  String get voiceLockedNotSent =>
      'Kryfo zablokowało się, zanim wiadomość głosowa wyszła, więc nie została wysłana';

  @override
  String get voiceNotSent => 'Twoja wiadomość głosowa nie została wysłana';

  @override
  String get settingsDisguiseByDefault => 'Domyślnie zmieniaj mój głos';

  @override
  String get settingsDisguiseByDefaultHint =>
      'Każdy czat może to zmienić w swoim menu';

  @override
  String get fileInstallerLine =>
      'To instalator aplikacji. Instaluj aplikacje tylko od osób, którym ufasz.';

  @override
  String get fileAppInstaller => 'Instalator aplikacji';

  @override
  String get fileSaveToDevice => 'Zapisz na urządzeniu';

  @override
  String get fileOpenHint => 'Otwiera się w innej aplikacji';

  @override
  String get fileSaved => 'Zapisano';

  @override
  String fileSavedIn(String place) {
    return 'Zapisano w $place';
  }

  @override
  String get fileSavedUnchecked =>
      'Zapisano, ale Kryfo nie mogło sprawdzić pliku';

  @override
  String get fileNotSaved => 'Nie udało się zapisać pliku';

  @override
  String get fileNotSavedNoSpace => 'Nie zapisano: brakuje tam miejsca';

  @override
  String fileTooBig(String size, String max) {
    return 'Ten plik ma $size. Pliki mogą mieć do $max.';
  }

  @override
  String get fileGoesAsItIs =>
      'Ten plik pójdzie dokładnie taki, jaki jest. Kryfo czyści tylko JPEG, PNG, WebP, HEIC, AVIF, GIF, MP4 i MOV.';

  @override
  String get voiceStoppedAtLimit =>
      'Wiadomości głosowe kończą się po 30 minutach. Odsłuchaj ją, a potem wyślij.';

  @override
  String get gettingMessagesHelperBody =>
      'Jego serwer widzi twój adres IP i to, kiedy przychodzą wiadomości.\nNigdy ich treści. Od razu i lekko.';

  @override
  String get gettingMessagesHelperUseOnion => 'Przełącz na Onion';

  @override
  String get gettingMessagesHelperSetUp => 'Skonfiguruj';

  @override
  String get gettingMessagesHelperNote =>
      'Dorzucane są fałszywe pobudki, przez co serwerowi pomocnika trudniej ustalić, kiedy przychodzą prawdziwe wiadomości. Własny serwer pomocnika podaje naszemu przekaźnikowi swój adres. Ukryte czaty, pokoje poza kilkoma pierwszymi, a czasem też zwykły kontakt, mniej więcej przez jeden miesiąc na pięć, czekają na sprawdzenie, które Kryfo nadal robi co 15 minut.';

  @override
  String get gettingMessagesHelperOnionOnly => 'Wymaga trasy Prywatny';

  @override
  String get gettingMessagesHelperChecking => 'Sprawdzam…';

  @override
  String get gettingMessagesHelperRelayNotYet =>
      'Nasz przekaźnik jeszcze tego nie oferuje';

  @override
  String get helperSheetNeedTitle => 'Potrzebujesz aplikacji pomocniczej';

  @override
  String get helperSheetNeedLine =>
      'Aplikacja pomocnicza utrzymuje jedno lekkie połączenie dla wszystkich twoich aplikacji i budzi Kryfo, gdy coś przyjdzie. Działa każdy pomocnik UnifiedPush, ntfy to dobry początek.';

  @override
  String get helperSheetGetNtfy => 'Pobierz ntfy';

  @override
  String get helperSheetOtherApps => 'Inne aplikacje pomocnicze';

  @override
  String get helperSheetPickTitle => 'Wybierz aplikację pomocniczą';

  @override
  String get helperSheetPickLine =>
      'Kryfo prosi ją tylko o obudzenie aplikacji. Twoje wiadomości nigdy przez nią nie przechodzą.';

  @override
  String helperSheetSetUp(Object name) {
    return '$name jest skonfigurowany';
  }

  @override
  String helperSheetNoAnswer(Object name) {
    return '$name nie odpowiada. Spróbuj ponownie.';
  }

  @override
  String get homeHelperGoneTitle => 'Twojej aplikacji pomocniczej już nie ma';

  @override
  String get homeHelperGoneLine =>
      'Kryfo sprawdza co 15 minut, dopóki nie wybierzesz innego sposobu.';

  @override
  String get homeHelperGoneChoose => 'Wybierz inny sposób';

  @override
  String get homeHelperRelayTitle => 'Przekaźnik przestał budzić Kryfo';

  @override
  String get gettingMessagesHelperRefused =>
      'Nasz przekaźnik nie przyjmuje teraz części rejestracji z tego telefonu. Te czaty docierają przy sprawdzeniu co 15 minut, a Kryfo próbuje dalej. Może też pomóc wybór innej aplikacji pomocniczej lub serwera.';

  @override
  String albumLabel(Object count) {
    return 'Album, elementy: $count';
  }

  @override
  String albumCounter(Object at, Object total) {
    return '$at z $total';
  }

  @override
  String albumMore(Object count) {
    return 'jeszcze $count';
  }

  @override
  String get albumOnItsWay => 'W drodze';

  @override
  String get albumQuoted => 'Album';

  @override
  String get albumUnsendTitle => 'Cofnąć wysłanie tego albumu?';

  @override
  String get mediaSendAddMore => 'Dodaj więcej';

  @override
  String get mediaSendRemove => 'Usuń';

  @override
  String get mediaSendProtect => 'Chroń przed zrzutami ekranu';

  @override
  String get mediaSendProtectedOn => 'Chronione · zrzuty ekranu są zablokowane';

  @override
  String mediaSendUpTo(Object count) {
    return 'Do $count naraz';
  }

  @override
  String get mediaSendVideo => 'Wyślij film';

  @override
  String get requestSenderMediaLater =>
      'Zdjęcia i pliki odblokują się, gdy ta osoba cię zaakceptuje, dla bezpieczeństwa was obojga.';

  @override
  String get requestReceiverMediaLater =>
      'Zdjęcia i pliki odblokują się, gdy zaakceptujesz tę osobę, dla twojego bezpieczeństwa.';

  @override
  String get groupEndedYou => 'Zakończono tę grupę';

  @override
  String groupEndedBy(Object name) {
    return '$name kończy tę grupę';
  }

  @override
  String get groupEndedBar => 'Ta grupa została zakończona';

  @override
  String get groupInfoEndGroup => 'Zakończ grupę';

  @override
  String get groupInfoEndThisGroup => 'Zakończyć tę grupę dla wszystkich?';

  @override
  String get groupInfoEndGroupLine =>
      'Zostanie usunięta dla wszystkich: jej wiadomości i multimedia znikną z telefonu każdego zaktualizowanego członka.';

  @override
  String get groupInfoEndGroupLineDesk =>
      'Zostanie usunięta dla wszystkich: jej wiadomości i multimedia znikną z urządzenia każdego zaktualizowanego członka.';

  @override
  String get groupInfoDeleteGroup => 'Usuń grupę';

  @override
  String get groupInfoDeleteThisGroup => 'Usunąć tę grupę?';

  @override
  String get groupInfoDeleteGroupLine =>
      'Zakończona grupa zniknie z listy czatów.';

  @override
  String get groupEndedOldNotice =>
      'Zakończono tę grupę, więc nikt nie może już w niej pisać. Zaktualizuj Kryfo, żeby widzieć ją jako zakończoną.';

  @override
  String get groupInfoEndGroupDetail =>
      'Kryfo usuwa ją z telefonu każdego członka, który ma aktualizację.';

  @override
  String get groupInfoEndGroupDetailDesk =>
      'Kryfo usuwa ją z urządzenia każdego członka, który ma aktualizację.';

  @override
  String get translateAction => 'Przetłumacz';

  @override
  String get translateShowOriginal => 'Pokaż oryginał';

  @override
  String translateBarTo(Object language) {
    return 'Przetłumacz na $language';
  }

  @override
  String get translateBarMore => 'Opcje tłumaczenia';

  @override
  String translateBarNever(Object language) {
    return 'Nigdy nie proponuj dla: $language';
  }

  @override
  String get translateBarHide => 'Ukryj w tym czacie';

  @override
  String get translateWorking => 'Tłumaczę…';

  @override
  String get translateFailed => 'Nie udało się przetłumaczyć';

  @override
  String translateFrom(Object language) {
    return 'Przetłumaczono z: $language';
  }

  @override
  String get translateLangZh => 'chiński';

  @override
  String translatePackTitle(Object language) {
    return 'Tłumacz $language na tym telefonie';
  }

  @override
  String translatePackTitleDesk(Object language) {
    return 'Tłumacz $language na tym komputerze';
  }

  @override
  String translatePackLine(Object language, Object size) {
    return 'Wiadomości są tłumaczone na tym telefonie i nigdy go nie opuszczają. Potrzebny jest pakiet językowy $language, około $size, pobierany raz przez Tor.';
  }

  @override
  String translatePackLineDesk(Object language, Object size) {
    return 'Wiadomości są tłumaczone na tym komputerze i nigdy go nie opuszczają. Potrzebny jest pakiet językowy $language, około $size, pobierany raz przez Tor.';
  }

  @override
  String get translatePackNoLib => 'Tłumaczenie nie działa na tym telefonie.';

  @override
  String get translatePackNoLibDesk =>
      'Tłumaczenie nie działa na tym komputerze.';

  @override
  String translateDownload(Object size) {
    return 'Pobierz · około $size';
  }

  @override
  String get translateDownloadAnyway => 'Pobierz teraz mimo to';

  @override
  String get translateResume => 'Wznów pobieranie';

  @override
  String translateProgress(Object done, Object total) {
    return '$done z $total';
  }

  @override
  String get translateFinishing => 'Sprawdzam pliki…';

  @override
  String translateInstalled(Object size) {
    return 'Na tym telefonie · $size';
  }

  @override
  String translateInstalledDesk(Object size) {
    return 'Na tym komputerze · $size';
  }

  @override
  String get translateNeedsWifi =>
      'Włączone jest Tylko Wi-Fi, a ten telefon nie jest połączony z Wi-Fi.';

  @override
  String get translateNeedsWifiDesk =>
      'Włączone jest Tylko Wi-Fi, a ten komputer nie jest połączony z Wi-Fi.';

  @override
  String get translateFailNoTor =>
      'Tor nie jest jeszcze połączony. Pakiety pobierają się tylko przez Tor, więc spróbuj ponownie, gdy będzie.';

  @override
  String get translateFailNetwork =>
      'Pobieranie się zatrzymało. Spróbuj ponownie, a zacznie od miejsca, w którym przerwało.';

  @override
  String get translateFailBadFile =>
      'Plik nie zgadzał się z tym, czego oczekuje Kryfo, więc został odrzucony. Spróbuj ponownie.';

  @override
  String get translateFailNoEngine =>
      'Na tym telefonie nie można pobierać pakietów językowych.';

  @override
  String get translateFailNoEngineDesk =>
      'Na tym komputerze nie można pobierać pakietów językowych.';

  @override
  String translatePaused(Object size) {
    return 'Wstrzymane · na razie $size';
  }

  @override
  String get translateSettingsTitle => 'Tłumaczenie';

  @override
  String get translateSettingsRow => 'Tłumacz wiadomości';

  @override
  String get translateSettingsHint => 'Na tym telefonie, nigdy na serwerze';

  @override
  String get translateSettingsHintDesk =>
      'Na tym komputerze, nigdy na serwerze';

  @override
  String get translatePacksSection => 'Pakiety językowe';

  @override
  String translateNotDownloaded(Object size) {
    return 'Nie pobrano · około $size';
  }

  @override
  String get translateDownloading => 'Pobieram przez Tor';

  @override
  String get translateLanguagesSection => 'Języki';

  @override
  String get translateMyLanguages => 'Języki, które czytam';

  @override
  String get translateMyLanguagesHint =>
      'Wiadomości w tych językach nie są proponowane do tłumaczenia. Język aplikacji zawsze jest jednym z nich.';

  @override
  String get translateInto => 'Tłumacz na';

  @override
  String get translateAppLanguage => 'Język aplikacji';

  @override
  String get translateBehaviourSection => 'Pobieranie i czaty';

  @override
  String get translateAutoDefault => 'Tłumacz czaty automatycznie';

  @override
  String get translateAutoDefaultHint =>
      'Dla czatów, których nie ustawiono samodzielnie. Każdy czat może to włączyć lub wyłączyć.';

  @override
  String get translateWifiOnly => 'Pobieraj pakiety tylko przez Wi-Fi';

  @override
  String get translatePrivacyTitle => 'Co zostaje prywatne';

  @override
  String get translatePrivacyNote =>
      'Tłumaczenie odbywa się na tym telefonie. Żadna wiadomość nigdy nie jest nigdzie wysyłana do tłumaczenia. Pobranie pakietu mówi serwerowi, który to pakiet. Przychodzi przez Tor, więc serwer nie wie, kto o niego prosił.';

  @override
  String get translatePrivacyNoteDesk =>
      'Tłumaczenie odbywa się na tym komputerze. Żadna wiadomość nigdy nie jest nigdzie wysyłana do tłumaczenia. Pobranie pakietu mówi serwerowi, który to pakiet. Przychodzi przez Tor, więc serwer nie wie, kto o niego prosił.';

  @override
  String get translateAutoInChat => 'Tłumacz automatycznie';

  @override
  String get translateAutoInChatHint =>
      'Wiadomości w innych językach pokazują się przetłumaczone. Oryginał jest o jedno stuknięcie.';

  @override
  String get translateAlwaysChat => 'Zawsze tłumacz ten czat';

  @override
  String translateNeverDone(Object language) {
    return 'Wiadomości w języku $language zostają bez zmian';
  }

  @override
  String get translateUndo => 'Cofnij';

  @override
  String get translateNeverSection => 'Nigdy nie proponowane';

  @override
  String get translateOfferAllAgain => 'Proponuj znowu wszystkie';

  @override
  String get translateOfferAgain => 'Proponuj znowu';

  @override
  String get translateOnHint =>
      'Proponowane pod wiadomościami w innych językach';

  @override
  String get translatePrivacyKept =>
      'Tłumaczenia są przechowywane razem z czatem, zaszyfrowane na tym telefonie, i usuwane razem z nim.';

  @override
  String get translatePrivacyKeptDesk =>
      'Tłumaczenia są przechowywane razem z czatem, zaszyfrowane na tym komputerze, i usuwane razem z nim.';

  @override
  String get translateOffDeletes =>
      'Wyłączenie tego usuwa zapisane tłumaczenia.';

  @override
  String get bridgesNoneUntilOnion => 'Brak, dopóki nie włączysz Onion';

  @override
  String get bridgesRelayThisNetworkSees =>
      'Tryb szybki przechodzi tam, gdzie Tor jest zablokowany, ale ta sieć widzi, że łączysz się z Kryfo.';

  @override
  String get settingsLicences => 'Licencje';

  @override
  String get settingsLicencesValue => 'Na czym zbudowano Kryfo';

  @override
  String get licencesKryfoLine =>
      'Kryfo to wolne oprogramowanie na licencji GNU General Public License w wersji 3 lub nowszej. Każdy może czytać, zmieniać i udostępniać jego kod.';

  @override
  String get licencesSourceCode => 'Kod źródłowy';

  @override
  String get licencesSignalTitle => 'Protokół Signal';

  @override
  String licencesSignalLine(String version) {
    return 'Kryfo zawiera libsignal $version, stworzone przez Signal, na licencji GNU Affero General Public License w wersji 3. Kod źródłowy jest na github.com/signalapp/libsignal i obok każdego wydania Kryfo.';
  }

  @override
  String get licencesAgplText => 'GNU AGPL 3.0, pełny tekst';

  @override
  String get licencesSignalSource => 'Kod źródłowy libsignal';

  @override
  String get licencesParts => 'Części open source';

  @override
  String get licencesInSignal => 'W bibliotece Signal';

  @override
  String get licencesInApp => 'W aplikacji';

  @override
  String licencesPartCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString części',
      many: '$countString części',
      few: '$countString części',
      one: '$countString część',
    );
    return '$_temp0';
  }

  @override
  String get licencesGplText => 'GNU GPL 3.0, pełny tekst';

  @override
  String get licencesInEngine => 'W silniku sieciowym';

  @override
  String get licencesLoadFailed => 'Nie udało się wczytać';

  @override
  String get licencesInVoice => 'W transkrypcji głosu';

  @override
  String get licencesInTranslation => 'W tłumaczeniu wiadomości';

  @override
  String get settingsCopyLinkHint => 'Kopiuj link';

  @override
  String get motionNoRelayYet => 'JESZCZE BEZ PRZEKAŹNIKA';

  @override
  String get motionTheRouteIsUp => 'Trasa działa';

  @override
  String get motionMessagesGoOnceARelay =>
      'Wiadomości wyjdą, gdy tylko przekaźnik odpowie przez tę trasę.';

  @override
  String get motionOffline => 'OFFLINE';

  @override
  String get motionNoNetwork => 'Brak sieci';

  @override
  String get motionTorPicksUpAgain =>
      'Bez sieci nic nie wychodzi. Tor podejmie pracę, gdy sieć wróci.';

  @override
  String deliveryModeStateLast(String state, Object last) {
    return '$state · $last';
  }

  @override
  String homeWaitingState(int count, String state) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count czeka · $state',
      many: '$count czeka · $state',
      few: '$count czekają · $state',
      one: '$count czeka · $state',
    );
    return '$_temp0';
  }

  @override
  String get settingsIconAndNotifications => 'Ikona i powiadomienia';

  @override
  String iconSettingsValue(String icon) {
    return '$icon, zwykłe powiadomienia';
  }

  @override
  String get iconSectionTitle => 'Ikona aplikacji';

  @override
  String get iconHint =>
      'Ekran główny i lista aplikacji pokazują tę ikonę i nazwę zamiast Kryfo.';

  @override
  String get iconHintKryfo =>
      'Wybierz zwyczajną ikonę i nazwę na ekran główny i listę aplikacji.';

  @override
  String get iconWhatChanges => 'Co to zmienia';

  @override
  String iconConfirmTitle(String name) {
    return 'Zmienić ikonę na $name?';
  }

  @override
  String iconConfirmLine(String name) {
    return 'Kryfo się zamknie i otworzy ponownie. Jeśli ikona zniknie z ekranu głównego, znajdź $name w aplikacjach i umieść ją z powrotem.';
  }

  @override
  String get iconConfirmButton => 'Zmień ikonę';

  @override
  String get iconNoPinLine =>
      'Każdy, kto ją stuknie, zobaczy Kryfo. Ustaw PIN aplikacji, żeby zamiast tego pokazywała się klawiatura PIN.';

  @override
  String get iconSetPin => 'Ustaw PIN';

  @override
  String iconChanged(String name) {
    return 'Ikona zmieniona na $name';
  }

  @override
  String iconPreviewLabel(String name) {
    return 'Ekran główny pokaże $name';
  }

  @override
  String iconButtonLabel(String name) {
    return '$name, ikona aplikacji';
  }

  @override
  String get notifShowAll => 'Nadawca i wiadomość';

  @override
  String get notifShowNew => 'Tylko „Nowa wiadomość”';

  @override
  String get notifShowPlain => 'Zwykłe';

  @override
  String get notifPlainHint =>
      'Bez nadawcy, bez wiadomości, bez kolorów Kryfo. Neutralna ikona i jedna linijka.';

  @override
  String get notifPlainLine => 'Coś nowego';

  @override
  String get notifPlainChannel => 'Alerty';

  @override
  String get notifHeaderLimit =>
      'Górna linia każdego powiadomienia nadal mówi Kryfo. Android nie pozwala aplikacji tego zmienić.';

  @override
  String get gettingMessagesWhatShows => 'Co pokazują powiadomienia';

  @override
  String get iconSheetChangesTitle => 'Co się zmienia';

  @override
  String get iconSheetChanges =>
      'Ikona i nazwa na ekranie głównym, na liście aplikacji, w menu udostępniania i w przełączniku aplikacji. Przy opcji Zwykłe także to, co pokazują powiadomienia.';

  @override
  String get iconSheetStaysTitle => 'Co zostaje jako Kryfo';

  @override
  String get iconSheetStays =>
      'Górna linia każdego powiadomienia, strony ustawień i baterii w telefonie, sklep z aplikacjami i samo Kryfo, gdy ktoś je otworzy.';

  @override
  String get iconSheetGlance =>
      'Wystarczy na rzut oka na ekran główny. Nie ukrywa Kryfo przed kimś, kto przegląda ustawienia twojego telefonu.';

  @override
  String get iconSheetPrivateSpace =>
      'Twój telefon może mieć własny sposób na ukrywanie aplikacji: przestrzeń prywatną w ustawieniach.';

  @override
  String get iconSheetSecureFolder =>
      'Twój telefon może mieć własny sposób na ukrywanie aplikacji: Folder Bezpieczny w ustawieniach.';

  @override
  String get iconSheetXiaomi =>
      'Twój telefon może mieć własny sposób na ukrywanie aplikacji: ukryte aplikacje w ustawieniach.';

  @override
  String get androidIconNotes => 'Notatki';

  @override
  String get androidIconWeather => 'Pogoda';

  @override
  String get androidIconTasks => 'Zadania';

  @override
  String get androidIconNews => 'Aktualności';

  @override
  String get androidServiceTitlePlain => 'Aktywne';

  @override
  String get lockStateUnlockPlain => 'Odblokuj';

  @override
  String get iconSheetOthers =>
      'Aplikacje na telefonie nadal widzą, że Kryfo jest zainstalowane, a okna i monity samego Androida mogą pokazywać jego nazwę.';

  @override
  String get iconSheetSaves =>
      'Gdy włączona jest zwyczajna ikona, nowe zdjęcia, filmy i pliki są zapisywane pod zwykłymi nazwami w typowych folderach telefonu. To, co zapisano wcześniej, zostaje na miejscu.';

  @override
  String get deliveryModeGooglePush => 'Powiadomienia Google';

  @override
  String get deliveryModeGoogle => 'Google';

  @override
  String get notificationsLead =>
      'Jak nowe wiadomości docierają na ten telefon, jak brzmią i co pokazują. Możesz to zmienić, kiedy chcesz.';

  @override
  String get notificationsLeadDesk =>
      'Jak nowe wiadomości docierają na ten komputer, jak brzmią i co pokazują. Możesz to zmienić, kiedy chcesz.';

  @override
  String get notificationsHowTheyReachYou =>
      'Jak docierają do ciebie wiadomości';

  @override
  String get notificationsRecommended => 'Zalecane';

  @override
  String get notificationsGoogleBody =>
      'Google widzi, kiedy twój telefon się budzi.\nNigdy, kto pisał ani co napisał.\nOd razu i lekko dla baterii.';

  @override
  String get notificationsGoogleOnFast =>
      'W trybie Szybki nasze serwery widzą twój IP, gdy budzą telefon, ale nigdy go nie zachowujemy.';

  @override
  String get notificationsGoogleStarting => 'Włączam…';

  @override
  String get notificationsGoogleNoStart =>
      'Nie udało się włączyć powiadomień Google. Sprawdź połączenie i spróbuj ponownie.';

  @override
  String get notificationsGoogleNote =>
      'Dorzucane są fałszywe pobudki, przez co Google trudniej ustalić, kiedy przychodzą prawdziwe wiadomości. Nasz przekaźnik przechowuje tylko adresy, których nie może ze sobą powiązać. Usługa powiadomień działa na naszym drugim serwerze. Oba serwery razem mogłyby je powiązać, a z pomocą Google także z twoim kontem Google. Przejęcie jednego nie wystarczy, ale prowadzimy oba, więc my moglibyśmy. Jeśli to dla ciebie ważne, wybierz inny sposób. Ukryte czaty, pokoje poza kilkoma pierwszymi, a czasem też zwykły kontakt, mniej więcej przez jeden miesiąc na pięć, czekają na sprawdzenie, które Kryfo nadal robi co 15 minut.';

  @override
  String get notificationsGoogleRefused =>
      'Nasz przekaźnik nie przyjmuje teraz części rejestracji z tego telefonu. Te czaty docierają przy sprawdzeniu co 15 minut, a Kryfo próbuje dalej.';

  @override
  String get notificationsSoundAndVibration => 'Dźwięk i wibracje';

  @override
  String get notificationsSoundHint => 'Ustawiane w ustawieniach Androida';

  @override
  String get notificationsEachShows => 'Każde powiadomienie pokazuje';

  @override
  String get notificationsBatteryTips => 'Wskazówki dotyczące baterii';

  @override
  String get notificationsBatteryAllowed => 'Dozwolone';

  @override
  String get notificationsBatteryNotYet => 'Niedozwolone';

  @override
  String get notificationsMakerSwitch => 'Przełącznik producenta telefonu';

  @override
  String get onboardingHowYourMessages => 'Jak *podróżują* twoje wiadomości.';

  @override
  String get onboardingRouteLead =>
      'Możesz to zmienić w każdej chwili w Ustawieniach.';

  @override
  String get onboardingRoutePrivateCost =>
      'Przez Tor. Wysłanie wiadomości trwa kilka sekund.';

  @override
  String get onboardingRoutePrivateGain =>
      'Nikt nie pozna twojego adresu IP, nawet nasze serwery.';

  @override
  String get onboardingRouteFastCost =>
      'Nasze serwery widzą twój adres IP, gdy jesteś połączony.\nTwoja sieć może widzieć, że używasz Kryfo.';

  @override
  String get onboardingRouteFastGain =>
      'Pomija Tor: szybciej i oszczędniej dla baterii.';

  @override
  String get onboardingRouteBlockedLead =>
      'Kryfo zostaje w sieci Tor, w razie potrzeby przez most.\nSzybki jest w Ustawieniach, jeśli go potrzebujesz.';

  @override
  String get onboardingRouteBlockedGain =>
      'Sam znajduje sposób na obejście blokad.';

  @override
  String get onboardingDeliveryHeadline => 'Kiedy *docierają* wiadomości.';

  @override
  String get onboardingDeliveryLead =>
      'Możesz to zmienić w każdej chwili w Powiadomieniach.';

  @override
  String get homeGoogleTitle => 'Są już powiadomienia Google';

  @override
  String get homeGoogleLine =>
      'Natychmiastowe i oszczędne dla baterii. Google widzi, kiedy telefon jest budzony, nigdy, od kogo jest wiadomość ani co w niej jest.';

  @override
  String get homeGoogleUse => 'Użyj';

  @override
  String get homeGoogleOn => 'Powiadomienia Google są włączone';

  @override
  String get homeGoogleGoneTitle => 'Powiadomienia Google są niedostępne';

  @override
  String get appNotificationsLink => 'Powiadomienia →';

  @override
  String devGooglePushes(int got, int low) {
    return 'Powiadomienia Google: $got · obniżone: $low';
  }

  @override
  String get passFieldLabel => 'Hasło';

  @override
  String get padUseLetters => 'Użyj liter';

  @override
  String get padUseDigits => 'Użyj cyfr';

  @override
  String get passWeak => 'Słabe';

  @override
  String get passFair => 'Przeciętne';

  @override
  String get passStrong => 'Mocne';

  @override
  String passStrengthIs(Object level) {
    return 'Siła: $level';
  }

  @override
  String get lockKeyBusy =>
      'Układ zabezpieczeń telefonu jest zajęty. Spróbuj za chwilę.';

  @override
  String get lockKeyLocked =>
      'Odblokuj raz telefon jego własnym PIN-em, a potem spróbuj ponownie.';

  @override
  String get lockKeyWaiting =>
      'Wciąż sprawdzam z układem zabezpieczeń telefonu';

  @override
  String get lockKeyLost =>
      'Ten telefon stracił klucz, który sprawdza twoje PIN-y, więc niektóre PIN-y mogą nie działać. Kryfo można zresetować i przywrócić kopię zapasową.';

  @override
  String get lockKeyReset => 'Zresetuj Kryfo';

  @override
  String get lockKeyResetTitle => 'Zresetować Kryfo?';

  @override
  String get lockKeyResetLine =>
      'Wszystko w Kryfo na tym telefonie zostanie usunięte, a Kryfo się zamknie. Potem możesz przywrócić kopię zapasową. Ukryte czaty wracają tylko z kopii zrobionej, gdy były otwarte.';

  @override
  String get lockKeyResetSureTitle => 'Tego nie da się cofnąć';

  @override
  String get lockKeyResetSureLine =>
      'Wszystkie czaty, klucze i ustawienia Kryfo na tym telefonie znikną teraz.';

  @override
  String get lockKeyResetSure => 'Usuń wszystko';

  @override
  String get flowVaultPassLine =>
      'Co najmniej 12 znaków. Klawiatura telefonu widzi, co wpisujesz, więc użyj takiej, która nie uczy się ani nie synchronizuje słów.';

  @override
  String get flowVaultPassLineDesk =>
      'Co najmniej 12 znaków. Wybierz hasło, którego nie używasz nigdzie indziej.';

  @override
  String get flowVaultPassAgain => 'To samo hasło jeszcze raz';

  @override
  String get cardTitle => 'Dokończ aktualizację zabezpieczeń';

  @override
  String get cardLine => 'Jeśli używasz innych PIN-ów, wpisz je tu raz.';

  @override
  String get cardType => 'Wpisz PIN';

  @override
  String get cardAnswer =>
      'Gotowe. Wpisz kolejny albo stuknij Gotowe, gdy skończysz.';

  @override
  String get keyLine =>
      'Twoje PIN-y działają tylko na tym telefonie. Jeśli telefon kiedyś straci klucz, który je sprawdza, trzeba będzie zresetować Kryfo i przywrócić kopię zapasową. Ukryte czaty wracają tylko z kopii zrobionej, gdy były otwarte.';

  @override
  String get keyLineUnlocked =>
      'Twoje PIN-y działają tylko na tym telefonie i tylko wtedy, gdy jest odblokowany. Jeśli telefon kiedyś straci klucz, który je sprawdza, trzeba będzie zresetować Kryfo i przywrócić kopię zapasową. Ukryte czaty wracają tylko z kopii zrobionej, gdy były otwarte.';

  @override
  String get keyLineScreenLock =>
      'Ustaw blokadę ekranu w telefonie, żeby ta ochrona działała, gdy jest zablokowany.';

  @override
  String get fileServerTryLater =>
      'Serwer plików jest teraz pełny. Spróbuj trochę później.';

  @override
  String fileTooBigUntilUpdate(String size, String max) {
    return 'Ten plik ma $size. Ten czat przyjmuje pliki do $max, dopóki wszyscy w nim nie zaktualizują Kryfo.';
  }

  @override
  String get fileDayLimit =>
      'Wysłano dziś dużo dużych plików. Spróbuj ponownie jutro.';

  @override
  String get mediaProgressPreparing => 'Przygotowuję · nie zamykaj aplikacji';

  @override
  String get groupShotsBlocksAll =>
      'Blokuje zrzuty i nagrywanie ekranu na każdym telefonie w tej grupie oraz kopiowanie, przekazywanie i zapisywanie wiadomości innych. Nie powstrzyma aplikacji, które mają dostęp do ekranu, ani telefonu czy aplikacji zmienionych, żeby to obejść.';

  @override
  String get groupShotsBlocksAllDesk =>
      'Wyłącza tutaj kopiowanie, przekazywanie i zapisywanie wiadomości innych. Kryfo na Androida blokuje też zrzuty i nagrywanie ekranu.';

  @override
  String get groupShotsStartsWhenAll =>
      'Czekam, aż wszystkie urządzenia tutaj będą mogły blokować zrzuty ekranu';

  @override
  String get groupShotsOnForAll => 'Włączone dla wszystkich tutaj';

  @override
  String get groupShotsOnForAllDesk => 'Włączone w Kryfo na Androida';

  @override
  String get groupShotsOffAdminOnly =>
      'Wyłączone. Może to zmienić tylko administrator';

  @override
  String get groupShotsWaitAdminOnly =>
      'Czekam, aż wszystkie urządzenia tutaj będą mogły blokować zrzuty ekranu. Może to zmienić tylko administrator';

  @override
  String get groupShotsOnAdminOnly =>
      'Włączone dla wszystkich tutaj. Może to zmienić tylko administrator';

  @override
  String get groupShotsOnAdminOnlyDesk =>
      'Włączone w Kryfo na Androida. Może to zmienić tylko administrator';

  @override
  String groupShotsWaitingFor(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Czekam na $countString osoby',
      many: 'Czekam na $countString osób',
      few: 'Czekam na $countString osoby',
      one: 'Czekam na $countString osobę',
    );
    return '$_temp0';
  }

  @override
  String get groupShotsWaitingTitle => 'Jeszcze nieobjęci';

  @override
  String get groupShotsWaitingHint =>
      'Blokada zrzutów ekranu obejmie wszystkich, gdy urządzenia tych osób będą mogły blokować zrzuty ekranu. Stuknij kogoś, żeby usunąć tę osobę z grupy.';

  @override
  String get groupShotsNeedsUpdate =>
      'Nie może jeszcze blokować zrzutów ekranu na swoim urządzeniu albo od tamtej pory nie pojawia się online';

  @override
  String get groupShotsBlockedByYou => 'Zablokowane przez ciebie';

  @override
  String get groupShotsYouTurnedOnWait =>
      'Włączono blokadę zrzutów ekranu. Obejmie wszystkich, gdy wszystkie urządzenia tutaj będą mogły blokować zrzuty ekranu.';

  @override
  String groupShotsTheyTurnedOnWait(String name) {
    return '$name włącza blokadę zrzutów ekranu. Obejmie wszystkich, gdy wszystkie urządzenia tutaj będą mogły blokować zrzuty ekranu.';
  }

  @override
  String get groupShotsStarted =>
      'Blokada zrzutów ekranu jest włączona dla wszystkich tutaj. Kopiowanie, przekazywanie i zapisywanie wiadomości innych też jest wyłączone.';

  @override
  String get groupShotsStartedDesk =>
      'Blokada zrzutów ekranu jest włączona w Kryfo na Androida. Kopiowanie, przekazywanie i zapisywanie wiadomości innych też jest wyłączone.';

  @override
  String get groupShotsPaused =>
      'Ktoś tutaj nie może jeszcze blokować zrzutów ekranu na swoim urządzeniu. Blokada obejmie znów wszystkich, gdy będzie to możliwe.';

  @override
  String get groupShotsCantYet => 'Nie może jeszcze blokować zrzutów ekranu';

  @override
  String get groupShotsAddTitle => 'Dodać mimo to?';

  @override
  String get groupShotsAddPauses =>
      'Blokada zrzutów ekranu nie obejmie wszystkich tutaj, dopóki ta osoba nie będzie mogła blokować zrzutów ekranu na swoim urządzeniu.';

  @override
  String get groupShotsLeaveStays =>
      'Blokada zrzutów ekranu zostaje bez zmian.';

  @override
  String get groupShotsBlockedHere =>
      'Kryfo blokuje zrzuty ekranu w tej grupie';

  @override
  String get groupShotsBlockedHereDesk =>
      'Kopiowanie, przekazywanie i zapisywanie jest w tej grupie wyłączone';

  @override
  String get groupShotsMenuNote =>
      'Kopiowanie, przekazywanie i zapisywanie cudzych wiadomości jest w tej grupie wyłączone';

  @override
  String get groupShotsKeptOpen =>
      'Otwieranie cudzych plików w innych aplikacjach jest w tej grupie wyłączone';

  @override
  String get groupShotsOldNotice =>
      'W tej grupie włączono blokadę zrzutów ekranu. Twoje Kryfo jeszcze tego nie potrafi, więc zaktualizuj je.';

  @override
  String get captureShotTaken =>
      'Zrobiono zrzut ekranu. Nikt inny nie został o tym powiadomiony.';

  @override
  String get captureRecording =>
      'Ten ekran jest nagrywany. Nikt inny nie został o tym powiadomiony.';

  @override
  String get settingsDevices => 'Urządzenia';

  @override
  String get devicesLinkedDevices => 'Połączone urządzenia';

  @override
  String get devicesThisPhoneOnly => 'Tylko ten telefon';

  @override
  String get devicesThisPhoneOnlyDesk => 'Tylko ten komputer';

  @override
  String get devicesNameSeparator => ', ';

  @override
  String get devicesThisPhone => 'Ten telefon';

  @override
  String get devicesThisPhoneDesk => 'Ten komputer';

  @override
  String get devicesOnlyThisPhone =>
      'Tylko ten telefon może łączyć lub usuwać urządzenia';

  @override
  String get devicesOnlyThisPhoneDesk =>
      'Tylko ten komputer może łączyć lub usuwać urządzenia';

  @override
  String devicesLinkedOn(Object date) {
    return 'Połączono $date';
  }

  @override
  String get devicesUsedToday => 'Używane dzisiaj';

  @override
  String get devicesUsedThisWeek => 'Używane w tym tygodniu';

  @override
  String get devicesUsedThisMonth => 'Używane w tym miesiącu';

  @override
  String get devicesNotUsedYet => 'Jeszcze nieużywane';

  @override
  String devicesUnlinksSoon(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Rozłączy się za $daysString dnia, jeśli go nie otworzysz',
      many: 'Rozłączy się za $daysString dni, jeśli go nie otworzysz',
      few: 'Rozłączy się za $daysString dni, jeśli go nie otworzysz',
      one: 'Rozłączy się jutro, jeśli go nie otworzysz',
      zero: 'Rozłączy się dzisiaj, jeśli go nie otworzysz',
    );
    return '$_temp0';
  }

  @override
  String get devicesEmptyTitle => 'Kryfo na twoim komputerze';

  @override
  String get devicesEmptyLine =>
      'Połącz komputer, żeby czytać i wysyłać tam wiadomości.';

  @override
  String get devicesContactsSeeNothing =>
      'Aplikacje twoich kontaktów nie pokazują twoich urządzeń.';

  @override
  String get devicesUnusedRule =>
      'Urządzenie, którego nie otworzysz przez 30 dni, samo się rozłącza i wymazuje z siebie twoje czaty.';

  @override
  String get devicesFull =>
      'Wszystkie miejsca na urządzenia są zajęte. Usuń jedno, żeby połączyć kolejne.';

  @override
  String get devicesLinkADevice => 'Połącz urządzenie';

  @override
  String get devicesRemoveAll => 'Usuń wszystkie inne urządzenia';

  @override
  String get devicesRemoveAllTitle => 'Usunąć wszystkie inne urządzenia?';

  @override
  String get devicesRemoveAllLine =>
      'Gdy aplikacje twoich kontaktów dostaną zmianę, te urządzenia przestaną dostawać nowe wiadomości i nie będą mogły wysyłać jako ty. Ten telefon zachowuje wszystko.';

  @override
  String get devicesRemoveAllYes => 'Usuń wszystkie';

  @override
  String get devicesRemovedAll => 'Teraz tylko ten telefon';

  @override
  String devicesRemoveTitle(Object name) {
    return 'Usunąć $name?';
  }

  @override
  String get devicesRemoveLine =>
      'Gdy aplikacje twoich kontaktów dostaną zmianę, to urządzenie przestanie dostawać nowe wiadomości i nie będzie mogło wysyłać jako ty. Przy następnym połączeniu wymaże z siebie twoje czaty. Urządzenie, przy którym ktoś majstrował, może zachować to, co już ma.';

  @override
  String get devicesRemove => 'Usuń';

  @override
  String devicesRemoved(Object name) {
    return 'Usunięto $name';
  }

  @override
  String get devicesRename => 'Zmień nazwę';

  @override
  String devicesRenameTitle(Object name) {
    return 'Zmień nazwę: $name';
  }

  @override
  String get devicesRenameLine =>
      'Tę nazwę widzisz tylko ty. Twoje kontakty nigdy.';

  @override
  String get devicesNameComputer => 'Komputer';

  @override
  String get devicesDeviceCode => 'Kod urządzenia';

  @override
  String get devicesDeviceCodeLine =>
      'Ten sam kod widać na samym urządzeniu, w Ustawieniach.';

  @override
  String get devicesLinkStep1 => 'Otwórz Kryfo na komputerze. Pokaże kod.';

  @override
  String get devicesLinkStep2 => 'Zeskanuj kod tym telefonem.';

  @override
  String get devicesLinkStep3 =>
      'Sprawdź, czy oba ekrany pokazują te same sześć cyfr.';

  @override
  String get devicesHistory => 'Historia';

  @override
  String get devicesHistoryCopy => 'Skopiuj moje czaty';

  @override
  String get devicesHistoryCopyHint =>
      'Twoje wiadomości, ze zdjęciami, filmami i nagraniami głosowymi z ostatnich 30 dni.';

  @override
  String get devicesHistoryNone => 'Tylko kontakty i grupy';

  @override
  String get devicesHistoryNoneHint => 'Przejdą bez żadnych wiadomości.';

  @override
  String get devicesSkipMedia => 'Pomiń zdjęcia i filmy';

  @override
  String get devicesSkipMediaHint =>
      'Przenoszony jest tylko tekst. Szybciej i mniej do trzymania na urządzeniu.';

  @override
  String get devicesHiddenStay =>
      'Ukryte czaty i przynęta zostają na tym telefonie.';

  @override
  String get devicesHiddenStayDesk =>
      'Ukryte czaty i przynęta zostają na tym komputerze.';

  @override
  String get devicesScanCode => 'Zeskanuj kod';

  @override
  String get devicesLinkReaching => 'Nawiązuję kontakt z urządzeniem';

  @override
  String get devicesLinkReachingLine =>
      'Trzymaj Kryfo otwarte na obu. Przez Tor może to potrwać minutę.';

  @override
  String get devicesLinkCompare => 'Czy cyfry się zgadzają?';

  @override
  String get devicesLinkCompareLine =>
      'Nowe urządzenie też pokazuje sześć cyfr. Połącz je tylko wtedy, gdy są takie same.';

  @override
  String get devicesLinkMatch => 'Zgadzają się';

  @override
  String get devicesLinkNoMatch => 'Nie zgadzają się';

  @override
  String get devicesLinkLinking => 'Łączenie';

  @override
  String get devicesLinkLinkingLine =>
      'Konfiguruję nowe urządzenie. Trzymaj oba otwarte.';

  @override
  String get devicesLinkDone => 'Urządzenie połączone';

  @override
  String get devicesLinkDoneLine =>
      'Widać je w Połączonych urządzeniach, gdzie możesz zmienić jego nazwę albo je usunąć.';

  @override
  String get devicesLinkUnreached =>
      'Nie udało się nawiązać kontaktu z urządzeniem';

  @override
  String get devicesLinkUnreachedLine =>
      'Sprawdź, czy Kryfo jest otwarte na nowym urządzeniu i pokazuje swój kod, a potem spróbuj ponownie.';

  @override
  String get devicesLinkStopped => 'Nic nie zostało połączone';

  @override
  String get devicesLinkStoppedLine =>
      'Cyfry muszą się zgadzać. Zacznij od nowa z nowym kodem.';

  @override
  String get devicesLinkInterruptedLine =>
      'Coś przerwało łączenie. Zacznij od nowa z nowym kodem.';

  @override
  String get devicesLinkAlreadyLine =>
      'Ten komputer jest już połączony. Usuń go w Połączonych urządzeniach, a potem połącz ponownie.';

  @override
  String get scanLinkTitle => 'Zeskanuj kod urządzenia';

  @override
  String get scanLinkPoint => 'Skieruj aparat na kod na nowym urządzeniu';

  @override
  String get scanLinkNotOne => 'To nie jest kod łączenia';

  @override
  String get onboardingLinkToMyPhone => 'Połącz z moim telefonem';

  @override
  String get joinTitle => 'Połącz ze swoim telefonem';

  @override
  String get joinStep1 => 'Otwórz Kryfo na telefonie.';

  @override
  String get joinStep2 =>
      'Wejdź w Ustawienia, potem Połączone urządzenia, potem Połącz urządzenie.';

  @override
  String get joinStep3 => 'Zeskanuj ten kod telefonem.';

  @override
  String get joinWaiting => 'Czekam na twój telefon';

  @override
  String get joinPreparing => 'Przygotowuję twój kod';

  @override
  String get joinPreparingLine =>
      'Kryfo się łączy. Kod pojawi się, gdy tylko ten komputer będzie online.';

  @override
  String get joinPreparingSlow =>
      'Pierwsze uruchomienie może potrwać minutę lub dwie, aż Tor się połączy.';

  @override
  String get homeLinkedChatsComing =>
      'Twoje czaty wciąż przychodzą z telefonu.';

  @override
  String get joinCodeLife => 'Kod działa przez dziesięć minut.';

  @override
  String get joinCompareLine =>
      'Twój telefon też pokazuje sześć cyfr. Przejdź dalej tylko wtedy, gdy są takie same.';

  @override
  String get joinLinking => 'Łączę z twoim telefonem';

  @override
  String get joinLinkingLine =>
      'Trzymaj Kryfo otwarte na telefonie, dopóki to się nie skończy.';

  @override
  String get joinDone => 'Połączono z twoim telefonem';

  @override
  String get joinDoneLine =>
      'Nowe wiadomości docierają teraz też na to urządzenie. Numer klucza twojego konta:';

  @override
  String get joinOpen => 'Otwórz Kryfo';

  @override
  String get joinUnreached => 'Nie udało się nawiązać kontaktu z telefonem';

  @override
  String get joinUnreachedLine =>
      'Sprawdź, czy telefon jest online i ma otwarte Kryfo, a potem spróbuj z nowym kodem.';

  @override
  String get devicesNewNotice => 'Połączono nowe urządzenie';

  @override
  String devicesNewNoticeLine(Object name, Object date) {
    return 'Urządzenie $name połączono z twoim kontem $date. Otwórz Połączone urządzenia, żeby je zobaczyć.';
  }

  @override
  String get devicesNewNoticeMany => 'Połączono nowe urządzenia';

  @override
  String devicesNewNoticeManyLine(Object names) {
    return 'Urządzenia $names połączono z twoim kontem. Otwórz Połączone urządzenia, żeby je zobaczyć.';
  }

  @override
  String get devicesNewNoticeOpen => 'Otwórz';

  @override
  String get settingsLinkedToLine =>
      'Połączono z twoim telefonem. Kopie zapasowe i zaproszenia zostają na telefonie.';

  @override
  String get devicesYourPhone => 'Twój telefon';

  @override
  String get desktopLockTitle => 'Kryfo jest zablokowane';

  @override
  String get desktopLockBody => 'Wpisz hasło do tego komputera.';

  @override
  String get desktopLockNewTitle => 'Zablokuj Kryfo na tym komputerze';

  @override
  String get desktopLockNewBody =>
      'Kryfo prosi o to hasło przy każdym uruchomieniu. Blokuje nim twoje wiadomości, zdjęcia, wiadomości głosowe, pliki, kontakty i klucze na tym komputerze.';

  @override
  String get desktopLockHonest =>
      'Ktoś, kto skopiuje folder Kryfo, może próbować haseł na własnym komputerze tak szybko, jak ten pozwala. Cztery lub więcej losowych słów wytrzymają. Krótkie hasło nie.';

  @override
  String get desktopLockForgot =>
      'Bez hasła żadnych twoich wiadomości, plików ani kluczy tutaj nie da się otworzyć, nawet nam.';

  @override
  String get desktopLockField => 'Hasło';

  @override
  String get desktopLockRepeat => 'To samo hasło jeszcze raz';

  @override
  String get desktopLockSet => 'Zablokuj tym hasłem';

  @override
  String get desktopLockOpen => 'Otwórz Kryfo';

  @override
  String desktopLockShort(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Co najmniej $countString znaku',
      many: 'Co najmniej $countString znaków',
      few: 'Co najmniej $countString znaki',
      one: 'Co najmniej $countString znak',
    );
    return '$_temp0';
  }

  @override
  String get desktopLockMismatch => 'Te dwa hasła nie są takie same';

  @override
  String get desktopLockWrong => 'To nie jest to hasło';

  @override
  String get desktopLockFailed =>
      'Kryfo nie mogło tu otworzyć swojej blokady. Spróbuj uruchomić je ponownie.';

  @override
  String get desktopTrayQuit => 'Zamknij Kryfo';

  @override
  String get desktopTrayTip => 'Kryfo działa i odbiera wiadomości';

  @override
  String get desktopTrayLockedTip =>
      'Otwórz Kryfo, żeby zacząć odbierać wiadomości';

  @override
  String get desktopTrayStillRunning =>
      'Kryfo nadal działa w zasobniku. Zamknij je ikoną w zasobniku.';

  @override
  String get desktopRunSection => 'Na tym komputerze';

  @override
  String get desktopTrayRow => 'Działaj dalej w zasobniku';

  @override
  String get desktopTrayHint =>
      'Wiadomości docierają też przy zamkniętym oknie.';

  @override
  String get desktopTrayOffLine =>
      'Zamknięcie okna zamyka Kryfo.\nWiadomości przyjdą, gdy otworzysz je ponownie.';

  @override
  String get desktopTrayNoneLine =>
      'Ten pulpit nie ma ikony w zasobniku.\nZamknięcie okna zamyka Kryfo.';

  @override
  String get desktopStartRow => 'Uruchamiaj razem z komputerem';

  @override
  String get desktopStartHint =>
      'Kryfo uruchamia się w zasobniku, gdy logujesz się na tym komputerze.';

  @override
  String get desktopStartRefused =>
      'Ten komputer nie pozwolił Kryfo uruchamiać się razem z nim.\nKryfo otworzy się, gdy je uruchomisz.';

  @override
  String get desktopStartHeldOff =>
      'Windows ma Kryfo wyłączone w aplikacjach autostartu.\nWłącz je w Ustawieniach Windows, Aplikacje, Uruchamianie.';

  @override
  String get desktopMicBlocked =>
      'Kryfo może nagrywać, gdy Windows pozwoli aplikacjom klasycznym używać mikrofonu: Ustawienia, Prywatność i zabezpieczenia, Mikrofon.';

  @override
  String get desktopMicNone =>
      'Podłącz mikrofon, aby nagrać wiadomość głosową.';

  @override
  String get desktopNoCamera =>
      'Kryfo nie może jeszcze używać kamery na tym komputerze. Użyj zamiast tego linku albo kodu.';

  @override
  String get desktopAlreadyOpen => 'Kryfo jest już otwarte na tym komputerze.';

  @override
  String get desktopFolderNotYours =>
      'Folder Kryfo należy do innego konta na tym komputerze, więc Kryfo go nie otworzy.';

  @override
  String get desktopFolderNotPrivate =>
      'Kryfo nie mogło ustawić swojego folderu jako prywatnego dla ciebie, więc się nie otworzy.';

  @override
  String get desktopLockOtherVersion =>
      'Tę blokadę zrobiła inna wersja Kryfo, której ta nie potrafi odczytać.';

  @override
  String get desktopNoMemoryFolder =>
      'Kryfo potrzebuje podczas działania prywatnego folderu w pamięci, a ten komputer go nie oferuje, więc się nie otworzy.';

  @override
  String get inviteNotYet =>
      'To zaproszenie nie jest jeszcze ważne. Sprawdź godzinę w telefonie.';

  @override
  String get inviteNotYetDesk =>
      'To zaproszenie nie jest jeszcze ważne. Sprawdź godzinę w komputerze.';

  @override
  String get inviteExpired => 'To zaproszenie wygasło. Poproś o nowe.';

  @override
  String get inviteDamaged => 'To zaproszenie jest uszkodzone. Poproś o nowe.';

  @override
  String get helloSent =>
      'Prośba wysłana. Ta osoba zobaczy ją, gdy będzie online.';

  @override
  String get inviteNeeds06 => 'Wymaga Kryfo 0.6 lub nowszego.';

  @override
  String get helloSentOld =>
      'Prośba wysłana. Jeśli ta osoba używa starszego Kryfo, musi je najpierw zaktualizować.';

  @override
  String get modesPickHow =>
      'Wybierz, jak podróżują twoje wiadomości. Możesz to zmienić w każdej chwili.';

  @override
  String get modesPrivate => 'Prywatny';

  @override
  String get modesPrivateTag => 'Tor · mostki, gdy trzeba';

  @override
  String get modesPrivateLine =>
      'Nikt nie pozna twojego adresu IP ani tego, kim jesteś, nawet nasze serwery. Sam znajduje sposób na obejście blokad.';

  @override
  String get modesDefault => 'Domyślny';

  @override
  String get modesFastTag => 'Prosto do naszych serwerów';

  @override
  String get modesFastLine =>
      'Pomija Tor, więc wiadomości docierają szybciej i zużywają mniej baterii. Nasze serwery widzą twój adres IP tylko podczas połączenia i nigdy go nie zapisują ani nie przechowują. Twoje kontakty nigdy go nie widzą. Twoja sieć widzi, że łączysz się z Kryfo.';

  @override
  String get modesFastConnected => 'Szybki · połączono';

  @override
  String get modesFastConnecting => 'Szybki · łączę';

  @override
  String get modesFastDown => 'Szybki · nasze serwery nie odpowiadają';

  @override
  String get modesBackupReady =>
      'Zapas jest zawsze gotowy, więc zostajesz w kontakcie, nawet gdy jeden serwer padnie.';

  @override
  String get modesDetails => 'Szczegóły';

  @override
  String get modesBothLine =>
      'Oba szyfrują każdą wiadomość end-to-end. Zmienia się tylko to, kto widzi twój adres IP.';

  @override
  String get modesConnectionBridges => 'Połączenie i mostki';

  @override
  String get modesWhatServersSee => 'Co widzą nasze serwery';

  @override
  String get serversTitle => 'Serwery trybu szybkiego';

  @override
  String get serversLine =>
      'Każda wiadomość idzie naraz do obu serwerów. Niesie ją ten, który odpowie pierwszy, a drugi przejmuje, gdy jeden przestanie działać.';

  @override
  String get serversOne => 'Serwer 1';

  @override
  String get serversTwo => 'Serwer 2 · drugi dostawca';

  @override
  String get serversConnected => 'Połączono';

  @override
  String get serversConnecting => 'Łączę';

  @override
  String get serversNotAnswering => 'Nie odpowiada';

  @override
  String serversMs(int ms) {
    return '$ms ms';
  }

  @override
  String get serversQuicker => 'Szybszy';

  @override
  String get serversBackups => 'Publiczne przekaźniki';

  @override
  String get serversBackupsLine =>
      'Używane, gdy Serwer 1 nie działa, i tylko przez Tor, więc nigdy nie widzą twojego adresu IP.';

  @override
  String get serversStandingBy => 'W gotowości';

  @override
  String get serversInUse => 'W użyciu';

  @override
  String get homeMergedTitle => 'Przekaźnik i Szybki to teraz jedno';

  @override
  String get homeMergedLine =>
      'Używasz trybu Szybki. Zapasowy serwer jest zawsze gotowy, więc zostajesz w kontakcie, nawet gdy jeden padnie. Nasze serwery widzą twój adres IP, nigdy tego, co piszesz.';

  @override
  String get homeMergedGotIt => 'Jasne';

  @override
  String get homeMergedUsePrivate => 'Użyj trybu Prywatny';

  @override
  String get homeOursDownTitle => 'Nasze serwery nie odpowiadają';

  @override
  String get homeOursDownLine =>
      'Po kilku minutach, gdy Tor się przebije, wiadomości pójdą też przez publiczne przekaźniki, a z powrotem przez nasze serwery, gdy tylko któryś odpowie.';

  @override
  String get homeUsePrivate => 'Użyj trybu Prywatny';

  @override
  String get homeSwitchedToPrivate => 'Przełączono na Prywatny';

  @override
  String get homeUseFast => 'Użyj trybu Szybki';

  @override
  String get homeSwitchedToFastRoute => 'Przełączono na Szybki';

  @override
  String get bridgesBridgeFirstFastSeen =>
      'Pozwól Kryfo znaleźć mostek, który się przebije. Tryb Szybki też działa, ale ta sieć widzi, że łączysz się z Kryfo.';

  @override
  String get appServersNotAnswering => 'Serwery nie odpowiadają';

  @override
  String get settingsPrivateTor => 'Prywatny · Tor';

  @override
  String get seenOurServers => 'Nasze serwery';

  @override
  String get seenOurServersCould => 'Nasze serwery mogłyby';

  @override
  String get seenIpWhy =>
      'W trybie Prywatny wszystko wychodzi przez Tor, a nasze serwery widzą węzeł wyjściowy, nigdy ciebie. W trybie Szybki połączenie idzie prosto do naszych dwóch serwerów: widzą twój adres IP podczas połączenia i nie zapisują go. Gdy pierwszy nie działa, tryb Szybki używa też publicznych przekaźników, tylko przez Tor.';

  @override
  String get chatAlbumItDisappearsWithNo =>
      'Ten album zostanie usunięty z obu telefonów, chyba że już go zapisano. Tego nie da się cofnąć.';

  @override
  String get chatAlbumItDisappearsWithNoDesk =>
      'Ten album zostanie usunięty z obu urządzeń, chyba że już go zapisano. Tego nie da się cofnąć.';

  @override
  String get groupChatAlbumItDisappearsWithNo =>
      'Ten album zostanie usunięty z telefonów wszystkich osób, chyba że już go zapisano. Tego nie da się cofnąć.';

  @override
  String get groupChatAlbumItDisappearsWithNoDesk =>
      'Ten album zostanie usunięty z urządzeń wszystkich osób, chyba że już go zapisano. Tego nie da się cofnąć.';

  @override
  String get homeInviteSomeone => 'Zaproś kogoś';

  @override
  String get onboardingNameHeadline => 'Publiczna *@nazwa*, jeśli chcesz.';

  @override
  String get onboardingNameLine =>
      'Publiczna @nazwa pozwala ludziom cię znaleźć.\nPominięcie daje więcej prywatności.\nNazwę możesz dodać później.';

  @override
  String get onboardingNameSkip => 'Na razie pomiń →';

  @override
  String onboardingNameClaim(Object handle) {
    return 'Zajmij @$handle →';
  }

  @override
  String get onboardingInviteHeadline => 'Teraz *zaproś kogoś*.';

  @override
  String get onboardingInviteLead =>
      'Wyślij link w dowolnym komunikatorze.\nOtworzy Kryfo albo pokaże, skąd je pobrać.';

  @override
  String get onboardingInviteSomeone => 'Zaproś kogoś →';

  @override
  String get onboardingInviteGettingReady => 'Przygotowuję twój link…';

  @override
  String inviteShareText(Object myId, Object link, Object download) {
    return 'Dodaj mnie w Kryfo. Moje imię tam to $myId\n\nStuknij, żeby mnie dodać:\n$link\n\nNie masz jeszcze Kryfo? Pobierz je tutaj:\n$download\n\nKryfo to prywatny komunikator. Bez numeru telefonu, bez maila.';
  }

  @override
  String get inviteNotReady =>
      'Twój link jest prawie gotowy. Spróbuj za chwilę.';

  @override
  String get photoCropTitle => 'Przesuń i przeskaluj';

  @override
  String get photoCropUse => 'Użyj zdjęcia';

  @override
  String get photoCropLabel =>
      'Twoje zdjęcie w kółku. Zsuń palce, żeby powiększyć, przeciągnij, żeby przesunąć';

  @override
  String get photoCouldNotUse =>
      'Spróbuj innego zdjęcia. Tego nie udało się odczytać.';

  @override
  String get photoTake => 'Zrób zdjęcie';

  @override
  String get photoChoose => 'Wybierz z galerii';

  @override
  String get photoPickFace => 'Wybierz twarz';

  @override
  String get photoView => 'Pokaż zdjęcie';

  @override
  String get photoRemove => 'Usuń zdjęcie';

  @override
  String get photoYourPhoto => 'Twoje zdjęcie';

  @override
  String get photoYourPhotoLine =>
      'Widzą je tylko twoje kontakty, szyfrowane end-to-end.';

  @override
  String get photoSetTheirs => 'Ustaw zdjęcie';

  @override
  String get photoChangeTheirs => 'Zmień zdjęcie';

  @override
  String get photoOnlyHere => 'Tylko na tym telefonie';

  @override
  String get photoOnlyHereDesk => 'Tylko na tym komputerze';

  @override
  String photoForThem(Object name) {
    return 'Zdjęcie dla: $name';
  }

  @override
  String get photoOnlyHereLine =>
      'Widzisz je tylko ty. Zostaje na tym telefonie.';

  @override
  String get photoOnlyHereLineDesk =>
      'Widzisz je tylko ty. Zostaje na tym komputerze.';

  @override
  String photoOf(Object name) {
    return 'Zdjęcie: $name';
  }

  @override
  String get historyChatStaysShots =>
      'Ten czat zostaje na twoim telefonie, bo zrzuty ekranu są w nim zablokowane.';

  @override
  String chatDeviceOlderKryfo(String name) {
    return '$name używa starszej wersji Kryfo. Odpowiadaj z telefonu, dopóki nie zaktualizuje.';
  }

  @override
  String chatDeviceNotYet(String name) {
    return '$name nie może jeszcze odbierać wiadomości z tego komputera. Odpowiedz z telefonu.';
  }

  @override
  String chatDeviceWaitingForApp(String name) {
    return 'Czekamy, aż Kryfo u $name rozpozna ten komputer. Na razie odpowiadaj z telefonu.';
  }

  @override
  String chatDeviceQuietAWhile(String name) {
    return '$name od jakiegoś czasu nic nie pisze. Na razie odpowiadaj z telefonu.';
  }

  @override
  String get linkedClearHereOnly =>
      'Każda wiadomość stąd zostanie usunięta tylko z tego komputera. Twój telefon je zachowa.';

  @override
  String get linkedDeleteHereOnly =>
      'Wszystkie wiadomości i kontakt znikną tylko z tego komputera. Twój telefon zachowa czat.';

  @override
  String get linkedBlockHereOnly =>
      'Wiadomości od tej osoby przestają docierać na ten komputer. Nie jest o tym informowana. Zablokuj ją na telefonie, aby przestały docierać także tam.';

  @override
  String get historyCopyTitle => 'Historia czatów';

  @override
  String get historyCopyMaking => 'Przygotowanie twoich czatów';

  @override
  String get historyCopyMakingLine =>
      'Telefon zbiera to, co zostanie skopiowane. Za chwilę start.';

  @override
  String get historyCopyGoing => 'Kopiowanie twoich czatów';

  @override
  String get historyCopyGoingLine =>
      'Trzymaj oba urządzenia online, aż się skończy.';

  @override
  String historyCopySize(Object size) {
    return 'Razem $size';
  }

  @override
  String get historyCopyWaiting => 'Czekanie na drugie urządzenie';

  @override
  String get historyCopyWaitingLine =>
      'Kopiowanie wznowi się samo, gdy oba urządzenia będą online.';

  @override
  String get historyCopyPaused => 'Kopiowanie robi krótką przerwę';

  @override
  String get historyCopyPausedLine => 'Wznowi się za minutę.';

  @override
  String get historyCopyWhole => 'Dotarły wszystkie wiadomości i pliki';

  @override
  String get historyCopyWholeLine => 'Niczego nie brakuje.';

  @override
  String get historyCopyRows => 'Dotarły twoje kontakty i grupy';

  @override
  String get historyCopyRowsLine =>
      'Dotarły bez żadnych wiadomości. Nowe wiadomości pojawiają się na urządzeniu od teraz.';

  @override
  String get historyCopyGaps => 'Dotarła większość twoich czatów';

  @override
  String get historyCopyGapsLine =>
      'Te czaty mają na nowym urządzeniu mniej niż na telefonie.';

  @override
  String historyCopyGapMessages(Object got, Object want) {
    return 'Wiadomości: $got z $want';
  }

  @override
  String historyCopyGapFiles(Object got, Object want) {
    return 'Pliki: $got z $want';
  }

  @override
  String historyCopyLeft(num count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString elementu zostało na telefonie',
      many: '$countString elementów zostało na telefonie',
      few: '$countString elementy zostały na telefonie',
      one: '1 element został na telefonie',
    );
    return '$_temp0';
  }

  @override
  String get historyCopyLeftWhy => 'Za duże lub nieczytelne do skopiowania.';

  @override
  String historyCopyLeftChats(num count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString czatu zostało na telefonie',
      many: '$countString czatów zostało na telefonie',
      few: '$countString czaty zostały na telefonie',
      one: '1 czat został na telefonie',
    );
    return '$_temp0';
  }

  @override
  String get historyCopyEnded => 'Kopiowanie się zatrzymało';

  @override
  String get historyCopyEndedLine =>
      'Nic więcej nie dotrze. Połącz urządzenie ponownie, aby zrobić nową kopię.';

  @override
  String get historyCopyFailed => 'Kopiowanie nie mogło się zakończyć';

  @override
  String get historyCopyFailedLine =>
      'Połącz urządzenie ponownie, aby zrobić nową kopię.';

  @override
  String get historyCopyStays => 'Zostało na telefonie';

  @override
  String get historyCopySee => 'Zobacz kopię';

  @override
  String a11yPinDigits(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString cyfry',
      many: '$countString cyfr',
      few: '$countString cyfry',
      one: '1 cyfra',
      zero: 'Brak cyfr',
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
      other: '$countString znaku',
      many: '$countString znaków',
      few: '$countString znaki',
      one: '1 znak',
      zero: 'Brak znaków',
    );
    return '$_temp0';
  }

  @override
  String get a11yBackupProgress => 'Postęp kopii zapasowej';

  @override
  String get a11yRestoreProgress => 'Postęp przywracania';

  @override
  String get a11yExportProgress => 'Postęp eksportu';

  @override
  String get a11yLockFileProgress => 'Postęp blokowania';

  @override
  String get a11yCleanProgress => 'Postęp czyszczenia';

  @override
  String get a11yMessageActions => 'Działania na wiadomości';

  @override
  String get a11yRecordVoiceNote => 'Nagraj wiadomość głosową';

  @override
  String get a11yRecording => 'Nagrywanie';

  @override
  String a11yPhotoOn(String date) {
    return 'Zdjęcie, $date';
  }

  @override
  String a11yPhotoFrom(String name, String date) {
    return 'Zdjęcie od: $name, $date';
  }

  @override
  String a11yVideoOn(String date) {
    return 'Film, $date';
  }

  @override
  String a11yVideoFrom(String name, String date) {
    return 'Film od: $name, $date';
  }

  @override
  String a11yNewMessages(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString nowej wiadomości',
      many: '$countString nowych wiadomości',
      few: '$countString nowe wiadomości',
      one: 'Nowa wiadomość',
    );
    return '$_temp0';
  }

  @override
  String get wideSelectChat => 'Wybierz czat';

  @override
  String get wideSelectChatLine => 'Wybierz czat z listy, żeby zacząć pisać.';

  @override
  String get wideListWidth => 'Szerokość listy czatów';

  @override
  String transferDoneOf(String done, String total) {
    return '$done z $total';
  }

  @override
  String transferDoneLeft(String done, String left) {
    return '$done · $left';
  }

  @override
  String get transferLeftSoon => 'zostało mniej niż minutę';

  @override
  String transferLeftMinutes(String n) {
    return 'zostało ok. $n min';
  }

  @override
  String transferLeftHours(String n) {
    return 'zostało ok. $n godz.';
  }

  @override
  String transferSending(String detail) {
    return 'Wysyłanie · $detail';
  }

  @override
  String transferReceiving(String detail) {
    return 'Odbieranie · $detail';
  }

  @override
  String transferBoth(String detail) {
    return 'Wysyłanie i odbieranie · $detail';
  }

  @override
  String get transferPause => 'Wstrzymaj';

  @override
  String get transferPauseDownload => 'Wstrzymaj pobieranie';

  @override
  String get transferDownload => 'Pobierz';

  @override
  String get transferResume => 'Wznów';

  @override
  String get transferOnWifi => 'Pobierze się przez Wi-Fi';

  @override
  String transferPausedAt(String detail) {
    return 'Wstrzymane · $detail';
  }

  @override
  String get transferTapToDownload => 'Stuknij, żeby pobrać';

  @override
  String transferSizeLine(String size, String state) {
    return '$size · $state';
  }

  @override
  String get transferNoteTitle => 'Przesyłanie pliku';

  @override
  String get transferChannel => 'Przesyłanie plików';

  @override
  String get transferChannelLine =>
      'Widoczne, gdy pliki się wysyłają lub pobierają. Nigdy nie podaje nazwy czatu ani pliku.';

  @override
  String get autoGetTitle => 'Automatyczne pobieranie';

  @override
  String get autoGetLine =>
      'Pliki przychodzą bez stuknięcia, tak jak tu ustawisz. Plik, który czeka, zostaje dla ciebie na serwerze plików najwyżej tydzień.';

  @override
  String get autoGetPhotos => 'Zdjęcia';

  @override
  String get autoGetVideos => 'Filmy';

  @override
  String get autoGetFiles => 'Pliki';

  @override
  String get autoGetAlways => 'Przez Wi-Fi i dane komórkowe';

  @override
  String get autoGetWifi => 'Tylko przez Wi-Fi';

  @override
  String get autoGetNever => 'Nigdy, pobieram stuknięciem';

  @override
  String get autoGetVoice => 'Wiadomości głosowe pobierają się zawsze.';

  @override
  String get settingsFiles => 'Pliki';

  @override
  String get desktopLockAccountBody =>
      'Wszystko, co Kryfo trzyma na tym komputerze, jest zaszyfrowane. Otwiera się z twoim kontem na komputerze.';

  @override
  String get desktopLockAddPassphrase => 'Dodaj hasło';

  @override
  String get desktopLockWithoutPassphrase =>
      'Bez niego każdy, kto używa twojego konta na komputerze, może otworzyć Kryfo.';

  @override
  String get desktopLockKeyringRefused =>
      'Kryfo nie mogło zapisać klucza w pęku kluczy tego komputera. Dodaj zamiast tego hasło.';

  @override
  String get desktopKeyMissing =>
      'To konto na komputerze nie ma klucza do danych Kryfo. Kopia zapasowa Kryfo przywróci wszystko. Jeśli przeniesiono folder Kryfo, dodaj hasło na koncie, z którego pochodzi, a potem skopiuj go ponownie.';

  @override
  String get desktopKeyUnreachable =>
      'Kryfo nie może teraz dostać się do swojego klucza na tym komputerze. Odblokuj pęk kluczy, jeśli komputer o to poprosi, i spróbuj ponownie.';

  @override
  String get desktopPassRow => 'Hasło na tym komputerze';

  @override
  String get desktopPassWindowsAccount => 'Zabezpieczone twoim kontem Windows';

  @override
  String get desktopPassKeyring => 'Zabezpieczone twoim pękiem kluczy';

  @override
  String get desktopPassOffBody =>
      'Kryfo otwiera się z twoim kontem na komputerze.';

  @override
  String get desktopPassOnBody =>
      'Kryfo prosi o to hasło przy każdym uruchomieniu.';

  @override
  String get desktopPassChange => 'Zmień hasło';

  @override
  String get desktopPassRemove => 'Usuń hasło';

  @override
  String get desktopPassCurrent => 'Obecne hasło';

  @override
  String get desktopPassNew => 'Nowe hasło';

  @override
  String get desktopPassStays =>
      'Ten komputer nie ma pęku kluczy, którego Kryfo może użyć, więc hasło zostaje.';

  @override
  String get desktopPassAdded => 'Hasło dodane';

  @override
  String get desktopPassRemoved => 'Hasło usunięte';

  @override
  String get desktopPassChanged => 'Hasło zmienione';

  @override
  String get desktopPassRemoveBody =>
      'Wpisz hasło, żeby je usunąć. Kryfo będzie się wtedy otwierać z twoim kontem na komputerze.';

  @override
  String get desktopKeyUnreachableWindows =>
      'Kryfo nie może teraz dostać się do swojego klucza w układzie zabezpieczeń tego komputera. Spróbuj za chwilę.';

  @override
  String get desktopLockAccountRefused =>
      'Kryfo nie mogło zapisać klucza na twoim koncie Windows. Dodaj zamiast tego hasło.';

  @override
  String get desktopPassStaysWindows =>
      'Kryfo nie mogło zapisać klucza na twoim koncie Windows, więc hasło zostaje.';

  @override
  String get desktopBackupCardTitle => 'Miej kopię zapasową Kryfo';

  @override
  String get desktopBackupCardLine =>
      'Klucz Kryfo trzyma twoje konto Windows na tym komputerze. Kopia zapasowa Kryfo przywróci wszystko, jeśli komputer albo konto zostaną kiedyś zresetowane.';

  @override
  String get desktopBackupHint =>
      'Przywraca wszystko, jeśli ten komputer zostanie kiedyś zresetowany.';

  @override
  String chatHealRestored(Object name) {
    return '$name konfiguruje Kryfo od nowa';
  }

  @override
  String chatHealNewSession(Object name) {
    return 'Urządzenie kontaktu $name zaczyna nową bezpieczną sesję';
  }

  @override
  String chatHealHeldLine(Object name) {
    return 'Wcześniej zweryfikowano $name. Nic nie zostanie wysłane, dopóki nie sprawdzisz numeru albo nie wybierzesz Pisz dalej. Wiadomości od tej osoby nadal docierają.';
  }

  @override
  String get chatKeepChatting => 'Pisz dalej';

  @override
  String chatNeedsUpdateToChat(Object name) {
    return '$name musi zaktualizować Kryfo, żeby dało się dalej pisać';
  }

  @override
  String get restoreOlderTitle => 'Niektóre czaty się wstrzymają';

  @override
  String restoreOlderOne(Object name) {
    return '$name używa starszego Kryfo. Twój czat z tą osobą wstrzyma się, dopóki nie zaktualizuje aplikacji.';
  }

  @override
  String restoreOlderTwo(Object first, Object second) {
    return '$first i $second używają starszego Kryfo. Twoje czaty z nimi wstrzymają się, dopóki nie zaktualizują aplikacji.';
  }

  @override
  String restoreOlderMany(Object first, Object second, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'jeszcze $count osoby',
      many: 'jeszcze $count osób',
      few: 'jeszcze $count osoby',
      one: 'jeszcze 1 osoba',
    );
    return '$first, $second i $_temp0 używają starszego Kryfo. Twoje czaty z nimi wstrzymają się, dopóki nie zaktualizują aplikacji.';
  }

  @override
  String settingsVersionAlpha(String version) {
    return '$version · alfa';
  }

  @override
  String get settingsDeskInTray => 'Działa w zasobniku';

  @override
  String get settingsDeskWhileOpen => 'Gdy Kryfo jest otwarte';

  @override
  String get onboardingDeskRunTitle => 'Kryfo *działa dalej*.';

  @override
  String get onboardingDeskRunLead =>
      'Zamknij okno, a Kryfo poczeka w zasobniku.\nWiadomości dalej docierają.\nOba ustawienia zmienisz w Ustawieniach, Powiadomienia.';

  @override
  String get savedLongPressAnyMessageDesk =>
      'Kliknij prawym przyciskiem dowolną wiadomość i wybierz Zapisz, żeby ją tu zachować.';

  @override
  String get chatFailedTapToRetryDesk => 'Nie wysłano · kliknij, by ponowić';

  @override
  String get groupChatTapToRetryDesk => '! Kliknij, by ponowić';

  @override
  String get chatDropHereToSend => 'Upuść tutaj, by wysłać';

  @override
  String get chatDropHereToAdd => 'Upuść tutaj, aby dodać';

  @override
  String trayRemove(String name) {
    return 'Usuń $name';
  }

  @override
  String trayReadyToSend(Object count) {
    return 'Gotowe do wysłania: $count';
  }

  @override
  String get trayPastedPicture => 'Wklejony obraz';

  @override
  String get voiceSeeTranscription => 'Pokaż transkrypcję';

  @override
  String get voiceTranscribing => 'Transkrybuję…';

  @override
  String get voiceHideTranscription => 'Ukryj';

  @override
  String get voiceShowOriginalOnly => 'Pokaż tylko oryginał';

  @override
  String get voiceCouldNotTranscribe => 'Nie udało się rozpoznać słów';

  @override
  String get voiceNoSpeech => 'W tej wiadomości nikt nie mówi';

  @override
  String get voiceTxNoMemory => 'Za mało wolnej pamięci w tej chwili';

  @override
  String get voiceTranscriptLabel => 'Transkrypcja';

  @override
  String get voiceSettingsTitle => 'Transkrypcja głosu';

  @override
  String get voiceOnRow => 'Transkrybuj wiadomości głosowe';

  @override
  String get voiceOnHint => 'Dostępna pod każdą wiadomością głosową';

  @override
  String get voiceOffDeletes => 'Wyłączenie usuwa zapisane transkrypcje.';

  @override
  String get voiceModelTitle => 'Model mowy';

  @override
  String voiceModelLine(Object size) {
    return 'Jedno pobranie, około $size, dla wszystkich języków.';
  }

  @override
  String get voiceModelPrivacy =>
      'Pobierany przez Tor i przechowywany na tym telefonie. Twoje wiadomości głosowe nigdy go nie opuszczają.';

  @override
  String get voiceModelPrivacyDesk =>
      'Pobierany przez Tor i przechowywany na tym komputerze. Twoje wiadomości głosowe nigdy go nie opuszczają.';

  @override
  String get voiceModelFailNoTor =>
      'Tor nie jest jeszcze połączony. Model pobiera się tylko przez Tor, więc spróbuj ponownie, gdy się połączy.';

  @override
  String get voiceModelRemoveTitle => 'Usunąć model mowy?';

  @override
  String get voiceModelRemoveLine =>
      'Gotowe transkrypcje zostają. Nowe znów będą potrzebować modelu.';

  @override
  String get voiceKeptNote =>
      'Transkrypcje są przechowywane przy swoim czacie, zaszyfrowane na tym telefonie, i usuwane razem z nim.';

  @override
  String get voiceKeptNoteDesk =>
      'Transkrypcje są przechowywane przy swoim czacie, zaszyfrowane na tym komputerze, i usuwane razem z nim.';

  @override
  String get voiceNotNow => 'Nie teraz';

  @override
  String get unlinkedTitle => 'To urządzenie jest rozłączone';

  @override
  String get unlinkedRemovedLine =>
      'Twój telefon usunął je z konta, więc Kryfo wymazał wszystko, co tu przechowywał.';

  @override
  String get unlinkedUnusedLine =>
      'Nie było otwierane przez 30 dni, więc Kryfo wymazał wszystko, co tu przechowywał.';

  @override
  String get unlinkedSilentLine =>
      'Przez 30 dni nie dostało nic od twojego telefonu, więc Kryfo wymazał wszystko, co tu przechowywał.';

  @override
  String get unlinkedClockLine =>
      'Jego zegar cofnięto, więc Kryfo wymazał wszystko, co tu przechowywał, żeby chronić twoje czaty.';

  @override
  String get unlinkedBrokenLine =>
      'Kryfo nie mógł ustalić, kiedy było ostatnio otwierane, więc wymazał wszystko, co tu przechowywał, żeby chronić twoje czaty.';

  @override
  String get unlinkedSelfLine =>
      'Rozłączono je, więc Kryfo wymazał wszystko, co tu przechowywał.';

  @override
  String get unlinkedAgainLine =>
      'Twój telefon zachowuje czaty. Żeby znów używać tu Kryfo, połącz to urządzenie z telefonem.';

  @override
  String get unlinkedClose => 'Zamknij Kryfo';

  @override
  String get devicesLeave => 'Rozłącz to urządzenie';

  @override
  String get devicesLeaveTitle => 'Rozłączyć to urządzenie?';

  @override
  String get devicesLeaveLine =>
      'Kryfo powiadomi telefon i wymaże wszystko, co tu przechowuje. Twój telefon zachowa czaty.';

  @override
  String get devicesLeaveYes => 'Rozłącz i wymaż';

  @override
  String get devicesGoneNotice => 'Urządzenie usunięte';

  @override
  String devicesGoneRemovedLine(Object name, Object date) {
    return 'Urządzenie $name usunięto z twojego konta $date.';
  }

  @override
  String devicesGoneUnusedLine(Object name, Object date) {
    return 'Urządzenie $name nie było używane przez 30 dni, więc usunięto je z twojego konta $date.';
  }

  @override
  String devicesGoneItselfLine(Object name, Object date) {
    return 'Urządzenie $name samo się rozłączyło $date i wymazało to, co przechowywało.';
  }

  @override
  String get devicesChangedNotice => 'Twoje urządzenia się zmieniły';

  @override
  String get devicesChangedLine =>
      'Otwórz Połączone urządzenia, żeby zobaczyć, co się zmieniło.';

  @override
  String get devicesUnknownNotice => 'Urządzenie połączone gdzie indziej';

  @override
  String get devicesUnknownLine =>
      'Inna kopia Kryfo połączyła urządzenie z twoim kontem. Ten telefon zdjął je z twojej listy.';

  @override
  String get albumPrevious => 'Poprzednie';

  @override
  String get albumNext => 'Następne';

  @override
  String get notesHoldHintDesk =>
      'Kliknij notatkę prawym przyciskiem, żeby ją skopiować albo usunąć.';

  @override
  String get pinsNothingPinnedHereYetDesk =>
      'Nic tu jeszcze nie przypięto. Kliknij wiadomość prawym przyciskiem i wybierz Przypnij, a będzie tu czekać na wszystkich w czacie.';

  @override
  String get chatGalleryDesk => 'Obrazy';

  @override
  String get groupChatGalleryDesk => 'Obrazy';

  @override
  String get photoChooseDesk => 'Wybierz plik obrazu';

  @override
  String get wallpaperFromYourPhotosDesk => 'Z pliku obrazu';

  @override
  String get notificationsSoundAndVibrationDesk => 'Dźwięk';

  @override
  String get notificationsPlaySound => 'Odtwarzaj dźwięk';

  @override
  String get notificationsPlaySoundHint =>
      'Przy każdym powiadomieniu na tym komputerze';

  @override
  String bridgesShareBridgeN(String n) {
    return 'Udostępnij mostek $n';
  }

  @override
  String get bridgesShareThisBridge => 'Udostępnij ten mostek';

  @override
  String get bridgesShareItPrivately =>
      'Udostępnij go prywatnie, osobom, którym ufasz. Mostek, którego nie ma na publicznych stronach, działa dłużej.';

  @override
  String get bridgesCopyBridge => 'Kopiuj mostek';

  @override
  String get bridgesBridgeCopied => 'Mostek skopiowany';

  @override
  String get bridgesSendBridgeTo => 'Wyślij mostek do';

  @override
  String get linkedAddOnPhone =>
      'Dodawaj osoby na telefonie. Pojawią się też tutaj.';

  @override
  String get linkedLinkOnPhone => 'Otwórz ten link na telefonie.';

  @override
  String get linkedDoOnPhone => 'Zrób to na telefonie.';

  @override
  String get tipsTitle => 'Wesprzyj Kryfo';

  @override
  String get tipsHeadline => 'Niech Kryfo zostanie *darmowe dla wszystkich*';

  @override
  String get tipsLine =>
      'Bez reklam, bez inwestorów, bez kont. Napiwek pomaga opłacić serwery i pracę nad Kryfo.';

  @override
  String get tipsLeave => 'Zostaw napiwek';

  @override
  String get tipsYours => 'Twoje';

  @override
  String get tipsAsking => 'Pytamy Google Play o ceny';

  @override
  String get tipsBadgeOnly =>
      'Napiwek daje ci odznakę wspierającego i nic więcej. Wszystko w Kryfo zostaje darmowe dla wszystkich, z napiwkiem czy bez.';

  @override
  String get tipsThroughPlay =>
      'Płatność idzie przez Google Play. Nigdy nie widzimy danych twojej karty ani twojego imienia.';

  @override
  String get tipsBadgeStays =>
      'Odznaka jest na tym telefonie. W zakładce Ja wybierasz, czy ją widać i czy widzą ją twoje kontakty.';

  @override
  String get tipsRestore => 'Przywróć moją odznakę';

  @override
  String get tipsRestoreLine =>
      'Zostawiałeś już napiwek? Odznaka wraca na każdym telefonie z tym samym kontem Google.';

  @override
  String tipsRestored(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter': 'Twoja odznaka wspierającego wróciła',
      'patron': 'Twoja odznaka mecenasa wróciła',
      'guardian': 'Twoja odznaka strażnika wróciła',
      'other': 'Twoja odznaka wspierającego wróciła',
    });
    return '$_temp0';
  }

  @override
  String get tipsNothingToRestore =>
      'Z tego konta Google nie było jeszcze napiwku';

  @override
  String get tipsUnavailable =>
      'Napiwki idą przez Google Play. Pojawią się tutaj, gdy tylko Google Play zadziała na tym telefonie.';

  @override
  String get tipsSoon => 'Napiwki już wkrótce tutaj.';

  @override
  String get tipsPending =>
      'Google Play jeszcze kończy twoją płatność. Odznaka przyjdzie, gdy tylko płatność przejdzie.';

  @override
  String get tipsFailed =>
      'Google Play nie dokończył płatności. Spróbuj ponownie za chwilę.';

  @override
  String get tipsThanks => 'Dziękujemy';

  @override
  String tipsGranted(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter':
          'Masz teraz odznakę wspierającego. Nie odblokowuje niczego więcej: wszystko w Kryfo zostaje darmowe dla wszystkich.',
      'patron':
          'Masz teraz odznakę mecenasa. Nie odblokowuje niczego więcej: wszystko w Kryfo zostaje darmowe dla wszystkich.',
      'guardian':
          'Masz teraz odznakę strażnika. Nie odblokowuje niczego więcej: wszystko w Kryfo zostaje darmowe dla wszystkich.',
      'other':
          'Masz teraz odznakę wspierającego. Nie odblokowuje niczego więcej: wszystko w Kryfo zostaje darmowe dla wszystkich.',
    });
    return '$_temp0';
  }

  @override
  String tipsKept(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter':
          'Dziękujemy za napiwek. Zostaje twoja odznaka wspierającego, ta wyższa.',
      'patron':
          'Dziękujemy za napiwek. Zostaje twoja odznaka mecenasa, ta wyższa.',
      'guardian':
          'Dziękujemy za napiwek. Zostaje twoja odznaka strażnika, ta wyższa.',
      'other':
          'Dziękujemy za napiwek. Zostaje twoja odznaka wspierającego, ta wyższa.',
    });
    return '$_temp0';
  }

  @override
  String get tipsProfileCard => 'Zostaw napiwek, żeby Kryfo zostało niezależne';

  @override
  String chatDeviceLinked(Object name) {
    return '$name łączy nowe urządzenie';
  }

  @override
  String chatDeviceRemoved(Object name) {
    return '$name usuwa urządzenie';
  }

  @override
  String chatDeviceListUnchecked(Object name) {
    return 'Nie udało się sprawdzić listy urządzeń kontaktu $name';
  }

  @override
  String get notesDropToKeep => 'Upuść tutaj, by zachować';

  @override
  String get notesOnAllDevices => 'Na wszystkich twoich urządzeniach';

  @override
  String get notesKeepAnything =>
      'Trzymaj tu tekst, zdjęcia i pliki. Pojawiają się na wszystkich twoich urządzeniach.';

  @override
  String get notesGoneEverywhere =>
      'Zniknie ze wszystkich twoich urządzeń na dobre.';

  @override
  String get notesDeleteAllEverywhere =>
      'Każda notatka zniknie ze wszystkich twoich urządzeń na dobre.';

  @override
  String get notesDeleteAllHereOnly =>
      'Każda notatka zniknie tylko z tego urządzenia. Twój telefon je zachowa.';

  @override
  String get notesAddItem => 'Dodaj zdjęcie lub plik';

  @override
  String get notesVoiceNotKept =>
      'Twoja wiadomość głosowa nie została zachowana';

  @override
  String get handleOlderKryfo =>
      'Ta osoba używa starszego Kryfo. Poproś ją o aktualizację, a potem dodaj ją.';

  @override
  String groupMemberNeedsUpdate(Object name) {
    return '$name używa starszego Kryfo. Musi je zaktualizować, żeby dostawać tu wiadomości.';
  }

  @override
  String get groupMembersNeedUpdate =>
      'Niektórzy członkowie używają starszego Kryfo. Muszą je zaktualizować, żeby dostawać tu wiadomości.';

  @override
  String get onboardingAlwaysOnNotice =>
      'Android wymaga jednego cichego, stałego powiadomienia, aby wiadomości docierały, gdy Kryfo jest zamknięte.';

  @override
  String get toolsSendToAChat => 'Wyślij do czatu';

  @override
  String get toolsOneFileAtATime => 'Jeden plik naraz';

  @override
  String get toolsLockThisFile => 'Zablokuj ten plik';

  @override
  String get toolsLockThisFileLine =>
      'Kryfo może zablokować go hasłem, tak by otworzyć go mógł tylko ktoś, kto je zna.';

  @override
  String get toolsDropHere => 'Upuść tu plik, by otworzyć go w narzędziu';

  @override
  String get toolsCopyPicture => 'Kopiuj obraz';

  @override
  String get toolsPictureCopied => 'Skopiowano obraz';

  @override
  String get toolsCouldNotCopy => 'Nie udało się skopiować obrazu';

  @override
  String get cleanNotYetHere => 'Tego obrazu nie da się tu jeszcze wyczyścić';

  @override
  String get cleanNotYetHereLine =>
      'Nadchodząca aktualizacja czyści takie obrazy także na komputerze. Twój obraz jest dokładnie taki jak był.';

  @override
  String get deskLinkRowHint => 'Używaj tu Kryfo ze swojego telefonu';

  @override
  String get deskLinkHead => 'Używaj tu Kryfo ze swojego telefonu';

  @override
  String get deskLinkLine =>
      'Ten komputer pokaże wtedy czaty i kontakty z twojego telefonu i będzie wysyłać jako ty.';

  @override
  String get deskLinkGoesTitle => 'Najpierw ten komputer zostanie wymazany';

  @override
  String get deskLinkGoesLine =>
      'Jego własna tożsamość, czaty i kontakty na tym komputerze zostaną usunięte. Ukryte czaty, przynęta i Notatka dla siebie też znikną. Pliki zapisane w twoich własnych folderach zostaną.';

  @override
  String get deskLinkBackupRow => 'Najpierw kopia zapasowa';

  @override
  String get deskLinkBackupHint =>
      'Zachowuje czaty z tego komputera w pliku, pod hasłem z co najmniej 12 znaków';

  @override
  String get deskLinkConfirmLine =>
      'Tożsamość i czaty tego komputera zostaną wymazane. Potem Kryfo otworzy się znowu z kodem do zeskanowania.';

  @override
  String get deskLinkConfirmYes => 'Wymaż i połącz';

  @override
  String get deskLinkReplace => 'Zastąp tożsamość tego komputera';

  @override
  String get deskLinkErasing => 'Wymazywanie tego komputera';

  @override
  String get deskLinkErasingLine =>
      'Kryfo za chwilę otworzy się znowu z kodem do zeskanowania.';

  @override
  String get deskLinkNotStarted =>
      'Nie udało się rozpocząć łączenia. Spróbuj później.';

  @override
  String get settingsLinkedToYourPhone => 'Połączono z twoim telefonem';

  @override
  String get settingsLinkedPhoneHint =>
      'Kopie zapasowe i zaproszenia zostają na telefonie';

  @override
  String get settingsUnlinkComputer => 'Rozłącz ten komputer';

  @override
  String get settingsUnlinkComputerTitle => 'Rozłączyć ten komputer?';

  @override
  String get settingsUnlinkComputerLine =>
      'Czaty na tym komputerze zostaną usunięte. Telefon zachowa wszystko.';

  @override
  String get metaReaderColourProfileName => 'nazwa profilu kolorów';

  @override
  String get cleanPixelMarksStay =>
      'Znaki ukryte w samych pikselach, jak ukryte znaki wodne generatorów obrazów, i wszystko, co widać na obrazie, zostają bez zmian.';

  @override
  String translateOfferDownload(Object language, Object size) {
    return 'Pobrać język: $language ($size)?';
  }

  @override
  String translateLineDownloading(Object language) {
    return 'Pobieranie języka: $language…';
  }

  @override
  String translateLineWaitsWifi(Object language) {
    return 'Czeka na Wi-Fi, by pobrać język: $language';
  }

  @override
  String get translateWaitsWifi =>
      'Czeka na Wi-Fi. Pobieranie ruszy samo, gdy tylko ten telefon połączy się z Wi-Fi.';

  @override
  String get translateWaitsWifiDesk =>
      'Czeka na Wi-Fi. Pobieranie ruszy samo, gdy tylko ten komputer połączy się z Wi-Fi.';

  @override
  String get translateWaitsWifiShort => 'Czeka na Wi-Fi';

  @override
  String translatePackLineTwo(Object language, Object other, Object size) {
    return 'Wiadomości są tłumaczone na tym telefonie i nigdy go nie opuszczają. Potrzebne są do tego pakiety językowe $language i $other, razem około $size, pobierane raz przez Tor.';
  }

  @override
  String translatePackLineTwoDesk(Object language, Object other, Object size) {
    return 'Wiadomości są tłumaczone na tym komputerze i nigdy go nie opuszczają. Potrzebne są do tego pakiety językowe $language i $other, razem około $size, pobierane raz przez Tor.';
  }

  @override
  String get translateLanguagesHint =>
      'Każdy pobiera się raz, a potem tłumaczy na tym telefonie';

  @override
  String get translateLanguagesHintDesk =>
      'Każdy pobiera się raz, a potem tłumaczy na tym komputerze';

  @override
  String get translateSuggested => 'Proponowane';

  @override
  String get translateMoreLanguages => 'Więcej języków';

  @override
  String get translateWaysBoth => 'Z angielskiego i na angielski';

  @override
  String get translateWaysInto => 'Tłumaczy tylko na angielski';

  @override
  String get translateWaysFrom => 'Tłumaczy tylko z angielskiego';

  @override
  String get translateGet => 'Pobierz';

  @override
  String get translateRemove => 'Usuń';

  @override
  String translateRemoveTitle(Object language) {
    return 'Usunąć język: $language?';
  }

  @override
  String translateRemoveLine(Object size) {
    return 'Zwolni to $size. Zapisane z nim tłumaczenia też zostaną usunięte. Możesz pobrać go ponownie w każdej chwili.';
  }

  @override
  String get translateResumeShort => 'Wznów';

  @override
  String get translateTagApp => 'Język aplikacji';

  @override
  String get translateTagRead => 'Czytasz w nim';

  @override
  String get chatInboxAnswerFromPhone => 'Odpowiedz na ten czat z telefonu.';

  @override
  String get chatInboxSendsWhenPhoneOnline =>
      'Wyśle się, gdy telefon będzie online.';

  @override
  String get chatInboxFilesFromPhone => 'Pliki wysyłaj z telefonu.';

  @override
  String get devicesManyAnswersNotice => 'Sprawdź swój komputer';

  @override
  String devicesManyAnswersLine(String name, String count) {
    return '$name próbował wysłać ponad $count odpowiedzi w godzinę. Jeśli to nie ty, usuń to urządzenie.';
  }

  @override
  String get fileViewInKryfo => 'Zobacz w Kryfo';

  @override
  String get fileOpenWith => 'Otwórz w…';

  @override
  String get fileOpenWithNote =>
      'Inna aplikacja zobaczy ten plik. Do tego czasu Kryfo trzyma go zaszyfrowany.';

  @override
  String fileFrom(String name) {
    return 'Od $name';
  }

  @override
  String fileLines(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n wiersza',
      many: '$n wierszy',
      few: '$n wiersze',
      one: '$n wiersz',
    );
    return '$_temp0';
  }

  @override
  String get fileNotWords =>
      'Ten plik nie jest tekstem. Możesz go zapisać albo otworzyć w innej aplikacji.';

  @override
  String fileShowsFirst(String size) {
    return 'Tu widać pierwsze $size. Zapisz plik, żeby przeczytać całość.';
  }

  @override
  String filePages(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n strony',
      many: '$n stron',
      few: '$n strony',
      one: '$n strona',
    );
    return '$_temp0';
  }

  @override
  String filePageOf(String page, String total) {
    return '$page / $total';
  }

  @override
  String filePage(String page) {
    return 'Strona $page';
  }

  @override
  String get fileSearchIn => 'Szukaj w pliku';

  @override
  String get fileSearchHint => 'Znajdź słowa w tym PDF';

  @override
  String get fileZoomIn => 'Powiększ';

  @override
  String get fileZoomOut => 'Pomniejsz';

  @override
  String get filePdfLocked =>
      'Ten PDF ma hasło. Otwórz go w innej aplikacji, żeby przeczytać.';

  @override
  String get filePdfUnreadable =>
      'Kryfo nie może wyświetlić tego PDF. Możesz go zapisać albo otworzyć w innej aplikacji.';

  @override
  String get soundOpenPlayer => 'Otwiera odtwarzacz';

  @override
  String get soundSpeed => 'Szybkość odtwarzania';

  @override
  String get soundClosePlayer => 'Zamknij odtwarzacz';

  @override
  String get soundPlayingInKryfo => 'Odtwarzane w Kryfo';

  @override
  String get soundBack15 => '15 sekund wstecz';

  @override
  String get soundForward15 => '15 sekund do przodu';

  @override
  String get soundRepeat => 'Powtarzaj';

  @override
  String get soundUpNext => 'Następne';

  @override
  String soundVoiceFrom(String name) {
    return 'Wiadomość głosowa od $name';
  }

  @override
  String get sendSheetTo => 'Wyślij do';

  @override
  String get sendSheetCleaned => 'Czyszczone przed wysłaniem';

  @override
  String get sendSheetFiles => 'Pliki';

  @override
  String get sendSheetRecent => 'Ostatnie';

  @override
  String get sendSheetChoosePhotos => 'Wybierz zdjęcia i filmy';

  @override
  String get sendSheetBrowseFiles =>
      'Przeglądaj wszystkie pliki na tym telefonie';

  @override
  String get sendSheetNoRecent =>
      'Tu pojawiają się pliki wysyłane i odbierane w czatach.';

  @override
  String sendSheetChosen(String n) {
    return 'Wybrane, numer $n';
  }

  @override
  String get sendSheetAsFile => 'Wyślij jako plik';

  @override
  String get sendSheetAsFileLine => 'Oryginalna jakość, bez kompresji';

  @override
  String sendSheetSend(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Wyślij $n',
    );
    return '$_temp0';
  }

  @override
  String sharedWith(String name) {
    return 'Udostępnione z $name';
  }

  @override
  String sharedIn(String name) {
    return 'Udostępnione w $name';
  }

  @override
  String get sharedTabMedia => 'Multimedia';

  @override
  String get sharedTabFiles => 'Pliki';

  @override
  String get sharedTabVoice => 'Głosowe';

  @override
  String get sharedTabLinks => 'Linki';

  @override
  String get sharedNoPhotos => 'Tu pojawiają się zdjęcia wysłane w tym czacie.';

  @override
  String get sharedNoFiles => 'Tu pojawiają się pliki wysłane w tym czacie.';

  @override
  String get sharedNoVoice =>
      'Tu pojawiają się wiadomości głosowe z tego czatu.';

  @override
  String get sharedNoLinks => 'Tu pojawiają się linki wysłane w tym czacie.';

  @override
  String get sharedYourVoice => 'Twoja wiadomość głosowa';

  @override
  String get sharedOpensLink => 'Otwiera link w innej aplikacji';

  @override
  String voiceSpeedLabel(String speed) {
    return '${speed}x';
  }

  @override
  String voiceSpeedA11y(String speed) {
    return 'Prędkość odtwarzania $speed';
  }

  @override
  String voiceSeekValue(String at, String total) {
    return '$at z $total';
  }

  @override
  String get chatReactHeart => 'Zareaguj sercem';

  @override
  String get homeDraftLabel => 'Szkic:';

  @override
  String homeDraftA11y(String text) {
    return 'Szkic: $text';
  }

  @override
  String handleSuggestFree(String handle) {
    return '@$handle jest wolne, użyj go';
  }

  @override
  String get notifRequestsChannel => 'Prośby o wiadomość';

  @override
  String get notifRequestsChannelLine =>
      'Pierwsze wiadomości od osób, których jeszcze nie dodano';

  @override
  String get notifRequestPopups => 'Wyskakujące powiadomienia o prośbach';

  @override
  String get notifRequestPopupsHint =>
      'Włączone: nowa prośba pojawia się z dźwiękiem. Wyłączone: czeka cicho w powiadomieniach.';

  @override
  String homeGroupLine(String name, String preview) {
    return '$name: $preview';
  }

  @override
  String get bannerOpen => 'Otwórz czat';

  @override
  String bannerOpenWith(String name) {
    return 'Otwórz czat z $name';
  }

  @override
  String bannerNewMessages(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString nowej wiadomości',
      many: '$countString nowych wiadomości',
      few: '$countString nowe wiadomości',
      one: '$countString nowa wiadomość',
    );
    return '$_temp0';
  }

  @override
  String get composerSendSilent => 'Wyślij bez dźwięku';

  @override
  String get composerSendHoldHint => 'Przytrzymaj, aby zobaczyć więcej opcji';

  @override
  String get homeGroupShotsLine => 'Wiadomość';
}
