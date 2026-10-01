// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class AppLocalizationsUk extends AppLocalizations {
  AppLocalizationsUk([String locale = 'uk']) : super(locale);

  @override
  String get atmosphereNone => 'Немає';

  @override
  String get atmosphereEmber => 'Жар';

  @override
  String get atmosphereDusk => 'Сутінки';

  @override
  String get atmosphereMoss => 'Мох';

  @override
  String get atmosphereRose => 'Троянда';

  @override
  String get atmosphereDots => 'Крапки';

  @override
  String get atmosphereGrid => 'Сітка';

  @override
  String get atmosphereWaves => 'Хвилі';

  @override
  String get atmosphereRain => 'Дощ';

  @override
  String get atmosphereLateNight => 'Пізня ніч';

  @override
  String get atmosphereWarmAfternoon => 'Тепле пообіддя';

  @override
  String get atmosphereSnow => 'Сніг';

  @override
  String get atmosphereDesert => 'Пустеля';

  @override
  String get atmospherePaper => 'Папір';

  @override
  String get backupThatPassphraseDoesNot =>
      'Ця парольна фраза не відкриває цей файл';

  @override
  String get backupThatFileIsNot => 'Цей файл не є резервною копією Kryfo';

  @override
  String get backupThisBackupIsFrom =>
      'Ця резервна копія з новішої версії Kryfo. Онови застосунок і спробуй ще раз';

  @override
  String get backupThisFileIsDamaged =>
      'Цей файл пошкоджений, і його неможливо прочитати';

  @override
  String get backupCouldNotMakeThe => 'Не вдалося створити ключ';

  @override
  String get contactCardMessageMeOn => 'Напиши мені в';

  @override
  String get contactCardScanItOrType =>
      'Відскануй або введи ці три слова в Kryfo.\nНічого іншого про тебе ця картка не знає.';

  @override
  String contactCardMessageMeOnKryfo(Object haloId) {
    return 'Напиши мені в Kryfo · $haloId';
  }

  @override
  String get contactStatusBlocked => 'Заблоковано';

  @override
  String get contactStatusKeysVerifiedInPerson => 'Ключі звірено особисто';

  @override
  String get contactStatusWaitingInRequests => 'Чекає в запитах';

  @override
  String get contactStatusAddedByHand => 'Додано вручну';

  @override
  String get deliveryModeAlwaysOn => 'Завжди на зв’язку';

  @override
  String get deliveryModeCheckIns => 'Перевірки';

  @override
  String get deliveryModeThroughAHelperApp => 'Через застосунок-помічник';

  @override
  String get deliveryModeNotYet => 'ще ні';

  @override
  String get deliveryModeJustNow => 'щойно';

  @override
  String deliveryModeMinAgo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString хв тому',
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
      other: '$countString години тому',
      many: '$countString годин тому',
      few: '$countString години тому',
      one: '$countString годину тому',
    );
    return '$_temp0';
  }

  @override
  String get deliveryModeYesterday => 'учора';

  @override
  String deliveryModeDaysAgo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString дня тому',
      many: '$countString днів тому',
      few: '$countString дні тому',
      one: '$countString день тому',
    );
    return '$_temp0';
  }

  @override
  String get deliveryModeConnected => 'Підключено';

  @override
  String get deliveryModeConnecting => 'Підключення';

  @override
  String get deliveryModeNotConnected => 'Не підключено';

  @override
  String get deliveryModeCheckingNow => 'Іде перевірка';

  @override
  String deliveryModeLastCheckIn(Object agoLine) {
    return 'остання перевірка $agoLine';
  }

  @override
  String get deliveryModeNoCheckInYet => 'ще жодної перевірки';

  @override
  String deliveryModeConnectedNow(Object last) {
    return 'Зараз підключено · $last';
  }

  @override
  String deliveryModeConnecting2(Object last) {
    return 'Підключення · $last';
  }

  @override
  String get deliveryModeNoCheckInYet2 => 'Ще жодної перевірки';

  @override
  String deliveryModeLastChecked(Object agoLine) {
    return 'Остання перевірка $agoLine';
  }

  @override
  String get deliveryModeAHelperApp => 'застосунок-помічник';

  @override
  String deliveryModeWokenByNoWake(Object who) {
    return 'Будить $who · пробуджень ще не було';
  }

  @override
  String deliveryModeWokenByLastWake(Object who, Object agoLine) {
    return 'Будить $who · востаннє $agoLine';
  }

  @override
  String get introBudgetTomorrow => 'завтра';

  @override
  String introBudgetInDays(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'через $countString дня',
      many: 'через $countString днів',
      few: 'через $countString дні',
      one: 'через $countString день',
    );
    return '$_temp0';
  }

  @override
  String get introBudgetInAnHour => 'через годину';

  @override
  String introBudgetInHours(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'через $countString години',
      many: 'через $countString годин',
      few: 'через $countString години',
      one: 'через $countString годину',
    );
    return '$_temp0';
  }

  @override
  String get introBudgetInAFewMinutes => 'через кілька хвилин';

  @override
  String get lockStateUnlockKryfo => 'Розблокувати Kryfo';

  @override
  String get appInvalidUri => 'Недійсний uri';

  @override
  String appBundleError(Object e) {
    return 'Помилка пакета: $e';
  }

  @override
  String appAlreadySaved(Object parsed) {
    return 'Уже збережено: $parsed';
  }

  @override
  String appAddedYouCanMessage(Object parsed) {
    return 'Додано $parsed · тепер можна писати';
  }

  @override
  String appPeerImportedV1(Object parsed) {
    return 'Контакт імпортовано (v1): $parsed';
  }

  @override
  String appLongWindow(Object line) {
    return '$line довге вікно';
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
      other: '$pString сторінки',
      many: '$pString сторінок',
      few: '$pString сторінки',
      one: '$pString сторінка',
    );
    String _temp1 = intl.Intl.pluralLogic(
      e,
      locale: localeName,
      other: '$eString події',
      many: '$eString подій',
      few: '$eString події',
      one: '$eString подія',
    );
    return '$line ($heldString з $subsString, підключення $c с, $_temp0, $_temp1)';
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
      other: '$pString сторінки',
      many: '$pString сторінок',
      few: '$pString сторінки',
      one: '$pString сторінка',
    );
    String _temp1 = intl.Intl.pluralLogic(
      e,
      locale: localeName,
      other: '$eString події',
      many: '$eString подій',
      few: '$eString події',
      one: '$eString подія',
    );
    return '$line (підключення $c с, $_temp0, $_temp1)';
  }

  @override
  String appSDropped(Object host, Object secs) {
    return '$host $secs с, обірвано';
  }

  @override
  String appS(Object host, Object secs) {
    return '$host $secs с';
  }

  @override
  String get appTorWouldNotWake => 'Tor не прокинувся';

  @override
  String get appCheckStarted => 'Почалася';

  @override
  String get appTorNotReadyIn => 'Tor не готовий за 75 с';

  @override
  String get appOk => 'ОК';

  @override
  String get appOkNoRelayBegan => 'ОК, ретранслятори мовчать';

  @override
  String get appOkCapped => 'ОК, перервано';

  @override
  String appSBy(Object how, int secs, String why) {
    final intl.NumberFormat secsNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String secsString = secsNumberFormat.format(secs);

    String _temp0 = intl.Intl.selectLogic(why, {
      'push': '$how, $secsString с, через push',
      'other': '$how, $secsString с, фонове завдання',
    });
    return '$_temp0';
  }

  @override
  String get appAnAttachmentCouldNot =>
      'Не вдалося зберегти вкладення на цьому телефоні';

  @override
  String get appGroup2 => 'Група';

  @override
  String get appVoiceMessage => 'Голосове повідомлення';

  @override
  String get appPhoto => 'Фото';

  @override
  String get appNewRequest => 'Новий запит';

  @override
  String get appSomeoneYouHaveNot => 'Тобі написав хтось не з твоїх контактів';

  @override
  String get appSettingUpYourKeys => 'Готуємо твої ключі';

  @override
  String get appOpeningYourChats => 'Відкриваємо твої чати';

  @override
  String get appStartingTor => 'Запускаємо Tor';

  @override
  String get appTimedMessagesAreNot =>
      'Зникаючі повідомлення не видаляються. Перезапусти Kryfo';

  @override
  String get appVoiceMessage2 => 'Голосове повідомлення';

  @override
  String appYou(Object body) {
    return 'Ти: $body';
  }

  @override
  String get appThisRoomHasAlready => 'Час цієї кімнати вже минув';

  @override
  String get appYouAreAlreadyIn => 'Ти вже в цій кімнаті';

  @override
  String get appCouldNotMakeA => 'Не вдалося створити ключ кімнати';

  @override
  String appJoinedButYourHello(Object linkName) {
    return 'Ти в кімнаті «$linkName», але твоє привітання поки затримано';
  }

  @override
  String appJoined(Object linkName) {
    return 'Ти в кімнаті «$linkName»';
  }

  @override
  String appJoinedButTheCreator(Object linkName) {
    return 'Ти в кімнаті «$linkName», але її творець поки недоступний';
  }

  @override
  String get appBooting => 'Запуск...';

  @override
  String get appSettingUpYourIdentity => 'Готуємо твою ідентичність...';

  @override
  String get appAddSomeone => 'Додати когось';

  @override
  String get appScanTheirCodeOr =>
      'Відскануй код або встав те, що тобі дали: посилання, @ім’я користувача чи посилання на кімнату.';

  @override
  String get appScanTheirCode => 'Відсканувати код';

  @override
  String get appAKryfoLinkA =>
      'Посилання Kryfo, посилання на кімнату або @sova';

  @override
  String get appAddThem => 'Додати';

  @override
  String get appEveryWayToAdd => 'Усі способи додати когось';

  @override
  String get appShowYourCodeSend =>
      'Покажи свій код, надішли посилання, займи ім’я користувача';

  @override
  String get appHelloFromTheOther => 'Привіт з іншого боку';

  @override
  String get appIdentityRestored => 'Ідентичність відновлено';

  @override
  String get appIdentityCreated => 'Ідентичність створено';

  @override
  String get appStartingTor30s => 'Запуск tor (~30 с)...';

  @override
  String get appScanOrImportA => 'Спершу відскануй або імпортуй контакт';

  @override
  String get appEncryptingSending30s => 'Шифрування + надсилання (~30 с)...';

  @override
  String get appTapStartListeningFirst => 'Спершу натисни «Почати слухати»';

  @override
  String get appYourKryfo => 'Твій Kryfo';

  @override
  String get appUriCopied => 'Uri скопійовано';

  @override
  String get appCopyUri => 'Копіювати uri';

  @override
  String get appAddAKryfo => 'Додати Kryfo';

  @override
  String get appScanQr => 'Сканувати QR';

  @override
  String get appPairingCode => 'Код з’єднання';

  @override
  String get appOrPaste => '- Або встав -';

  @override
  String get commonCancel => 'Скасувати';

  @override
  String get appImport => 'Імпортувати';

  @override
  String get appDev => 'Розробка';

  @override
  String get appYourKryfo2 => 'Твій Kryfo:';

  @override
  String get appRestoredFromDisk => 'Відновлено з диска';

  @override
  String get appStartListening => 'Почати слухати';

  @override
  String get appListening => 'Слухає';

  @override
  String get appShowMyQr => 'Показати мій QR';

  @override
  String get appImportPeer => 'Імпортувати контакт';

  @override
  String get appPeer => 'Контакт:';

  @override
  String get appMessageWillBeEncrypted => 'Повідомлення (буде зашифровано)';

  @override
  String get appEncryptSend => 'Шифрувати + надіслати';

  @override
  String appStatus(Object status) {
    return 'Стан: $status';
  }

  @override
  String get appSpeedPrivacy => 'Швидкість і приватність →';

  @override
  String get appGettingMessages => 'Отримання повідомлень →';

  @override
  String get appDisableAppLock => 'Вимкнути блокування Kryfo?';

  @override
  String get appThePinWillBe =>
      'PIN-код буде видалено. Будь-хто, у кого опиниться твій телефон, побачить Kryfo, щойно відкриє його.';

  @override
  String get appDisable => 'Вимкнути';

  @override
  String get appAppLockOn => 'Блокування · увімкнено →';

  @override
  String get appAppLockOff => 'Блокування · вимкнено →';

  @override
  String get appTorIsOff => 'Tor вимкнено';

  @override
  String get appConnectedRoutedThrough3 =>
      'Підключено · маршрут через 3 ретранслятори';

  @override
  String get appReadyToSendPublishing =>
      'Готово до надсилання · публікуємо твою адресу';

  @override
  String get appReadyToSendFinishing =>
      'Готово до надсилання · завершуємо налаштування';

  @override
  String appConnecting(Object pct) {
    return 'Підключення · $pct';
  }

  @override
  String get appTor => 'Tor';

  @override
  String get appTorIsOffTurn =>
      'Tor вимкнено. Увімкни його, щоб підключатися приватно.';

  @override
  String get appTheFirstConnectionTakes =>
      'Перше підключення триває хвилину-дві, поки tor будує приватний маршрут. Потім це зберігається в кеші, тож надалі Kryfo відкривається набагато швидше.';

  @override
  String get appRelayAndFastModes =>
      'Режим ретранслятора і швидкий режим обходять tor і працюють швидше. Вони в налаштуваннях, у розділі «Швидкість і приватність», і кожен каже, чим за це платиш.';

  @override
  String get appViaRelay => 'Ретранслятор';

  @override
  String get appOffline => 'Офлайн';

  @override
  String get appFast => 'Швидкий';

  @override
  String get appTorOff => 'Tor вимкнено';

  @override
  String get appTorReady => 'Tor готовий';

  @override
  String get appConnecting2 => 'Підключення';

  @override
  String mediaProgressSendingKeepTheApp(Object v) {
    return 'Надсилання · $v · не закривай застосунок';
  }

  @override
  String mediaProgressPausedOfWaitingFor(Object count, Object count2) {
    return 'Пауза · $count з $count2 · чекаємо решту';
  }

  @override
  String mediaProgressReceivingMedia(Object v) {
    return 'Отримання медіа · $v';
  }

  @override
  String get mediaProgressCancelSending => 'Скасувати надсилання';

  @override
  String get metaReaderEndsBeforeItShould => 'обривається передчасно';

  @override
  String get metaReaderCouldNotBeRead => 'не вдалося прочитати';

  @override
  String get metaReaderExifThatCannotBe => 'exif, який неможливо прочитати';

  @override
  String get metaReaderSamsungTrailer => 'хвіст samsung';

  @override
  String metaReaderChunk(Object type) {
    return 'блок $type';
  }

  @override
  String get metaReaderExifFlagSet => 'є прапорець exif';

  @override
  String get metaReaderXmpFlagSet => 'є прапорець xmp';

  @override
  String metaReaderAppBlock(Object id) {
    return 'блок app $id';
  }

  @override
  String get metaReaderUuidBox => 'контейнер uuid';

  @override
  String metaReaderBox(Object printable) {
    return 'контейнер $printable';
  }

  @override
  String get metaReaderAttachedData => 'долучені дані';

  @override
  String metaReaderItem(Object printable) {
    return 'елемент $printable';
  }

  @override
  String get miuiAutostartAlreadyAllowedToRun => 'Уже може працювати у фоні';

  @override
  String get miuiAutostartLetKryfoRunIn => 'Дозволь Kryfo працювати у фоні';

  @override
  String get miuiAutostartYourPhonePausesApps =>
      'Твій телефон призупиняє застосунки, щоб заощадити батарею. Без винятку Kryfo не може отримувати повідомлення, поки він закритий.';

  @override
  String get commonAllow => 'Дозволити';

  @override
  String get commonSkip => 'Пропустити';

  @override
  String get miuiAutostartXiaomiTurnsOffBackground =>
      'Xiaomi за замовчуванням вимикає фонові застосунки. Без автозапуску Kryfo не може доставляти повідомлення, коли застосунок закритий. На наступному екрані знайди Kryfo у списку й увімкни перемикач.';

  @override
  String get miuiAutostartOpenSettings => 'Відкрити налаштування';

  @override
  String get miuiAutostartCouldnTOpenIt =>
      'Не вдалося відкрити. Пошукай автозапуск у налаштуваннях телефону';

  @override
  String get notificationsNewEncryptedMessagesFrom =>
      'Нові зашифровані повідомлення від твоїх контактів';

  @override
  String get notificationsNewMessage => 'Нове повідомлення';

  @override
  String get notificationsNewEncryptedMessagesFromYourContacts =>
      'Нові зашифровані повідомлення від твоїх контактів';

  @override
  String get notificationsNewMessage2 => 'Нове повідомлення';

  @override
  String get notificationsEncrypted => 'Зашифровано';

  @override
  String get rooms24h => '24 год';

  @override
  String roomsD(Object inDays) {
    return '$inDays дн';
  }

  @override
  String roomsH(Object inHours) {
    return '$inHours год';
  }

  @override
  String get rooms24Hours => 'через 24 години';

  @override
  String roomsDays(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'через $countString дня',
      many: 'через $countString днів',
      few: 'через $countString дні',
      one: 'через $countString день',
    );
    return '$_temp0';
  }

  @override
  String get roomsAnHour => 'через годину';

  @override
  String get roomsAboutAnHour => 'десь через годину';

  @override
  String roomsHours(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'через $countString години',
      many: 'через $countString годин',
      few: 'через $countString години',
      one: 'через $countString годину',
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
      other: 'десь через $countString години',
      many: 'десь через $countString годин',
      few: 'десь через $countString години',
      one: 'десь через $countString годину',
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
      other: 'через $countString хвилини',
      many: 'через $countString хвилин',
      few: 'через $countString хвилини',
      one: 'через $countString хвилину',
    );
    return '$_temp0';
  }

  @override
  String get roomsAMinute => 'через хвилину';

  @override
  String get roomsExpired => 'Час вийшов';

  @override
  String roomsDH(Object inDays, Object h) {
    return '$inDays дн $h год';
  }

  @override
  String roomsHM(Object inHours, Object m) {
    return '$inHours год $m хв';
  }

  @override
  String roomsM(Object inMinutes) {
    return '$inMinutes хв';
  }

  @override
  String get scamShieldLooksLikeAScam => 'Схоже на шахрайство';

  @override
  String scamShieldThisNameMatches(Object shown) {
    return 'Це ім’я збігається з контактом $shown';
  }

  @override
  String scamShieldNameMatchesYourContact(Object shown) {
    return 'Ім’я збігається з твоїм контактом $shown';
  }

  @override
  String scamShieldSameFaceAsYour(Object shown) {
    return 'Таке саме обличчя, як у твого контакту $shown';
  }

  @override
  String get scamShieldContainsACryptoAddress => 'Містить криптоадресу';

  @override
  String get scamShieldMentionsMoneyAndUrgency =>
      'Згадує гроші й поспіх водночас';

  @override
  String get scamShieldAsksYouToMove => 'Просить перейти в інший застосунок';

  @override
  String get scamShieldLinksToALookalike => 'Веде на двійника відомого сайту';

  @override
  String get scamShieldALongOpenerFrom =>
      'Довге перше повідомлення від когось без історії';

  @override
  String get scamShieldAsksForACode =>
      'Просить код, сид-фразу або файл відновлення';

  @override
  String scamShieldAlso(Object shown) {
    return 'Також: ім’я збігається з твоїм контактом $shown';
  }

  @override
  String get commonBack => 'Назад';

  @override
  String get archivedArchived => 'Архів';

  @override
  String get archivedCount0 => 'Жодного';

  @override
  String get archivedCount1 => 'Один';

  @override
  String get archivedCount2 => 'Два';

  @override
  String get archivedCount3 => 'Три';

  @override
  String get archivedCount4 => 'Чотири';

  @override
  String get archivedCount5 => 'П’ять';

  @override
  String get archivedCount6 => 'Шість';

  @override
  String get archivedCount7 => 'Сім';

  @override
  String get archivedCount8 => 'Вісім';

  @override
  String get archivedCount9 => 'Дев’ять';

  @override
  String get archivedCount10 => 'Десять';

  @override
  String get archivedChatRestingHereIt =>
      'Чат тут дрімає. Він мовчить, доки тобі не напишуть, а тоді знову спливає нагору.';

  @override
  String get archivedChatsRestingHere =>
      'Чати тут дрімають. Вони мовчать, доки хтось не напише, а тоді знову спливають нагору.';

  @override
  String get archivedNothingArchived => 'В архіві порожньо';

  @override
  String get archivedArchivedChatsAreStill =>
      'Чати в архіві й далі наскрізно зашифровані';

  @override
  String get archivedUnarchive => 'Розархівувати';

  @override
  String get avatarPickerThePeopleYouMessage =>
      'Люди, яким ти пишеш, теж це бачать';

  @override
  String get avatarPickerBackToYourInitial => 'Повернути ініціал';

  @override
  String get avatarPickerThatOneIsYours => 'Це твоє';

  @override
  String get avatarPickerPickAFace => 'Обери обличчя';

  @override
  String get commonSave => 'Зберегти';

  @override
  String get backupPassphraseMustBeAt =>
      'У парольній фразі має бути щонайменше 6 символів';

  @override
  String get backupPassphrasesDonTMatch => 'Парольні фрази не збігаються';

  @override
  String get backupBackupSavedKeepThe =>
      'Резервну копію збережено · бережи парольну фразу';

  @override
  String get backupKryfoBackup => 'Резервна копія Kryfo';

  @override
  String get backupYourEncryptedKryfoBackup =>
      'Твоя зашифрована резервна копія Kryfo. Бережи І цей файл, І парольну фразу - для відновлення потрібне і те, і те.';

  @override
  String get backupBackUpKryfo => 'Резервна копія Kryfo';

  @override
  String get backupBackUp => 'Резервна копія';

  @override
  String get backupACopyToKeep =>
      'Копія про запас. Цей телефон працює далі, як і раніше.';

  @override
  String get backupMoveToAnotherDevice => 'Перенести на інший пристрій';

  @override
  String get backupTheFileTakesThis =>
      'Файл забирає цю ідентичність із собою. Щойно його створено, цей телефон зупиняється: нічого нового сюди не надходить, і ніщо, надіслане звідси, ні до кого не доходить.';

  @override
  String get backupOneEncryptedFileYour =>
      'Один зашифрований файл: твоя ідентичність, твої контакти, кожне повідомлення і кожне фото, голосове та файл. Імпортуй його на іншому пристрої з парольною фразою. Доти ще можна передумати й лишитися на цьому телефоні.';

  @override
  String get backupOneEncryptedFileYourIdentityYour =>
      'Один зашифрований файл: твоя ідентичність, твої контакти, кожне повідомлення і кожне фото, голосове та файл, які є на цьому телефоні зараз. Усього, що буде сказано після сьогодні, у ньому немає, тож роби нову копію, коли це важливо. Для відновлення потрібні і файл, і парольна фраза.';

  @override
  String get backupPassphrase => 'Парольна фраза';

  @override
  String get backupConfirmPassphrase => 'Повтори парольну фразу';

  @override
  String backupWriting(Object progress) {
    return 'Запис… $progress';
  }

  @override
  String get backupCreating => 'Створення…';

  @override
  String get backupMakeTheFileAnd => 'Створити файл і переїхати';

  @override
  String get backupCreateBackup => 'Створити копію';

  @override
  String get backupNotMade =>
      'Не вдалося створити резервну копію. Спробуй ще раз.';

  @override
  String get backupHiddenNotIn => 'Прихованих чатів у ньому немає.';

  @override
  String get backupHiddenIncluded => 'Приховані чати в ньому теж є.';

  @override
  String get backupMoveHiddenStay =>
      'Приховані чати лишаються на цьому телефоні й стираються разом із ним.';

  @override
  String get backupHiddenGone =>
      'Приховані чати закрилися, коли Kryfo заблокувався. Відкрий їх PIN-кодом прихованих чатів і зроби копію звідти.';

  @override
  String get blockedBlocked => 'Заблоковані';

  @override
  String get blockedNoOneIsBlocked => 'Нікого не заблоковано';

  @override
  String get commonUnblock => 'Розблокувати';

  @override
  String get bridgesThatWasNotIt => 'Не те. Ось інша.';

  @override
  String get bridgesMoatFailed =>
      'Не вдалося зв’язатися з проєктом tor. Спробуй за хвилину або встав рядок моста нижче.';

  @override
  String get bridgesGotBridgesSaveTo =>
      'Мости отримано · збережи, щоб ними користуватися';

  @override
  String get bridgesConnected => 'Підключено';

  @override
  String get bridgesNotThroughYetTor => 'Поки не вдалося. Tor пробує далі';

  @override
  String get bridgesBridges => 'Мости';

  @override
  String get bridgesTorIsBlockedWhere => 'Tor заблокований там, де ти є?';

  @override
  String get bridgesBridgesDisguiseYourConnection =>
      'Мости маскують твоє підключення, щоб воно могло вибратися назовні. Обери один спосіб входу, збережи, і tor перепідключиться через нього.';

  @override
  String get bridgesBridgesOnlyChangeHow =>
      'Мости змінюють лише те, як підключається tor, а ти зараз не в режимі Onion. Налаштоване тут збережеться, просто нічого не робитиме, доки ти не повернешся до цього режиму.';

  @override
  String get bridgesFromTheTorProject => 'Від проєкту tor';

  @override
  String get bridgesNoise => 'Шум';

  @override
  String get bridgesGood => 'Добра';

  @override
  String get bridgesMakesTorTrafficLook =>
      'Робить трафік tor ні на що конкретне не схожим. Найкращий вибір для більшості заблокованих мереж. Розв’язуєш капчу, і тобі видають кілька рядків.';

  @override
  String get bridgesPrivateBridge => 'Приватний міст';

  @override
  String get bridgesALineFromA => 'Рядок від друга';

  @override
  String get bridgesWhateverTheLineSays => 'Як указано в рядку';

  @override
  String get bridgesDepends => 'Залежить';

  @override
  String get bridgesGotABridgeLine =>
      'Маєш рядок моста від того, кому довіряєш, або з bridges.torproject.org? Встав його сюди. Лише рядки obfs4, інших Kryfo поки не розуміє.';

  @override
  String get bridgesPasteFromClipboard => 'Вставити з буфера';

  @override
  String get bridgesUseBridges => 'Увімкнути мости';

  @override
  String get bridgesNoLinesYet => 'Ще немає рядків';

  @override
  String bridges1LineSaved(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString рядка збережено',
      many: '$countString рядків збережено',
      few: '$countString рядки збережено',
      one: '$countString рядок збережено',
    );
    return '$_temp0';
  }

  @override
  String get bridgesRestartingTor => 'Перезапуск tor…';

  @override
  String bridgesFindingABridgeS(Object elapsed) {
    return 'Шукаємо міст… $elapsed с';
  }

  @override
  String bridgesStillTryingS(Object elapsed) {
    return 'Ще пробуємо… $elapsed с';
  }

  @override
  String get bridgesApplying => 'Застосовуємо…';

  @override
  String get bridgesSaveAndReconnect => 'Зберегти й перепідключитися';

  @override
  String get bridgesWhatABridgeIs => 'Що таке міст';

  @override
  String get bridgesATorEntryPoint =>
      'Точка входу в tor, яку ніхто не публікував, куди підключаєшся через обгортку, щоб з’єднання не було схоже на tor. Решта маршруту - звичайні три вузли.';

  @override
  String get bridgesLooksLike => 'Схоже на';

  @override
  String get bridgesSpeed => 'Швидкість';

  @override
  String get bridgesGetBridges => 'Отримати мости';

  @override
  String get bridgesAskTheTorProject =>
      'Попроси їх напряму в проєкту tor. Ти розв’язуєш головоломку, щоб боти не могли вичерпати запас.';

  @override
  String get bridgesTypeWhatYouSee =>
      'Введи те, що бачиш. Малі літери теж підійдуть.';

  @override
  String get bridgesThisOneRequestDoes =>
      'Цей один запит іде не через tor - і не може, бо не працює саме tor. Той, хто керує твоєю мережею, побачить, що ти звертаєшся до проєкту tor. Якщо там, де ти є, це вже саме по собі проблема, дістань мости деінде і встав їх нижче.';

  @override
  String get bridgesCouldNotDrawThe => 'Не вдалося показати головоломку';

  @override
  String get bridgesAnswer => 'Відповідь';

  @override
  String get bridgesAsking => 'Запитуємо…';

  @override
  String get bridgesRequestBridges => 'Запросити мости';

  @override
  String get bridgesDifferentPuzzle => 'Інша головоломка';

  @override
  String get cameraNoCameraOnThis => 'На цьому телефоні немає камери';

  @override
  String get cameraCameraNotAvailable => 'Камера недоступна';

  @override
  String get cameraCameraPermissionIsOff =>
      'Немає дозволу на камеру · натисни, щоб спробувати ще раз';

  @override
  String get cameraCouldNotStripThat =>
      'Не вдалося очистити це фото, його відкинуто';

  @override
  String get cameraNoPhotoCameOut => 'Фото не вийшло';

  @override
  String get cameraCouldNotStartRecording => 'Не вдалося почати запис';

  @override
  String get cameraTheRecordingWasLost => 'Запис втрачено';

  @override
  String get cameraACopyIsIn => 'Копія є у твоїх фото';

  @override
  String get cameraCouldNotSaveA =>
      'Не вдалося зберегти копію на цьому телефоні';

  @override
  String get cameraTooLongForA => 'Задовге для повідомлення · макс. 8 МБ';

  @override
  String get cameraNeverSavedToYour => 'Ніколи не зберігається у твоїх фото';

  @override
  String get cameraNoExifNeverSaved =>
      'Без exif, ніколи не зберігається у твоїх фото';

  @override
  String get cameraRec => 'Запис';

  @override
  String get cameraSwitchCamera => 'Змінити камеру';

  @override
  String cameraClipSMb(Object secs, Object mb) {
    return 'Кліп · $secs с · $mb МБ';
  }

  @override
  String get cameraStopRecording => 'Зупинити запис';

  @override
  String get cameraStartRecording => 'Почати запис';

  @override
  String get cameraTakeAPhoto => 'Зробити фото';

  @override
  String get cameraKeepACopy => 'Зберегти копію';

  @override
  String get cameraUseThis => 'Використати';

  @override
  String chatB(Object bytes) {
    return '$bytes Б';
  }

  @override
  String chatKb(Object bytes) {
    return '$bytes КБ';
  }

  @override
  String chatMb(Object bytes) {
    return '$bytes МБ';
  }

  @override
  String get chatFile => 'ФАЙЛ';

  @override
  String get chatYouAreOfflineThis =>
      'Ти офлайн · надішлеться само, щойно знову підключишся';

  @override
  String get chatStillConnectingToTor => 'Ще підключаємося до Tor · піде само';

  @override
  String chatS(Object seconds) {
    return '$seconds с';
  }

  @override
  String chatM(Object seconds) {
    return '$seconds хв';
  }

  @override
  String chatH(Object seconds) {
    return '$seconds год';
  }

  @override
  String chatD(Object seconds) {
    return '$seconds дн';
  }

  @override
  String get chat0s => '0 с';

  @override
  String chatHM(Object h, Object m) {
    return '$h год $m хв';
  }

  @override
  String chatMS(Object m, Object s) {
    return '$m хв $s с';
  }

  @override
  String chatS2(Object s) {
    return '$s с';
  }

  @override
  String get chatNewMessages => 'Нові повідомлення';

  @override
  String get chatUnsave => 'Не зберігати';

  @override
  String get chatForward => 'Переслати';

  @override
  String get commonShare => 'Поділитися';

  @override
  String get commonCopied => 'Скопійовано';

  @override
  String get commonCopy => 'Копіювати';

  @override
  String get chatUnpin => 'Відкріпити';

  @override
  String get chatPin => 'Закріпити';

  @override
  String get chatStopSending => 'Зупинити надсилання';

  @override
  String get chatUnsend => 'Відкликати';

  @override
  String get commonEdit => 'Редагувати';

  @override
  String get chatYou => 'Ти';

  @override
  String get chatUnsendMessage => 'Відкликати повідомлення';

  @override
  String get chatItDisappearsWithNo =>
      'Воно зникне без сліду. Цю дію не можна скасувати.';

  @override
  String chatThisChatHasPins(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'У цьому чаті вже $countString закріпленого повідомлення',
      many: 'У цьому чаті вже $countString закріплених повідомлень',
      few: 'У цьому чаті вже $countString закріплені повідомлення',
      one: 'У цьому чаті вже $countString закріплене повідомлення',
    );
    return '$_temp0';
  }

  @override
  String get chatUnpinThisMessage => 'Відкріпити повідомлення?';

  @override
  String get chatPinThisMessage => 'Закріпити повідомлення?';

  @override
  String get chatItLeavesThePinned =>
      'Воно зникне зі списку закріплених для вас обох.';

  @override
  String get chatItGoesUnderThe =>
      'Воно з’явиться серед закріплених угорі чату, для вас обох.';

  @override
  String get chatPinIt => 'Закріпити';

  @override
  String get chatNotNow => 'Не зараз';

  @override
  String get chatEditMessage => 'Редагування';

  @override
  String get chat30Seconds => '30 секунд';

  @override
  String get chat1Minute => '1 хвилина';

  @override
  String get chat5Minutes => '5 хвилин';

  @override
  String get chat1Hour => '1 година';

  @override
  String get chat24Hours => '24 години';

  @override
  String get chatGhostTimer => 'Зникаючі повідомлення';

  @override
  String get chatHowLongBeforeSent =>
      'Через скільки надіслані повідомлення зникатимуть?';

  @override
  String get chatCamera => 'Камера';

  @override
  String get chatNoExifNeverSaved =>
      'Без exif, ніколи не зберігається у твоїх фото';

  @override
  String get chatGallery => 'Галерея';

  @override
  String get chatVideo => 'Відео';

  @override
  String get chatGifFromPhone => 'GIF з телефону';

  @override
  String get chatFile2 => 'Файл';

  @override
  String get chatAFewSeconds => 'Кілька секунд';

  @override
  String get chatUnderAMinute => 'Менше хвилини';

  @override
  String chatRoughlyMin(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Приблизно $countString хв',
    );
    return '$_temp0';
  }

  @override
  String chatB2(Object b) {
    return '$b Б';
  }

  @override
  String chatKb2(Object b) {
    return '$b КБ';
  }

  @override
  String chatMb2(Object b) {
    return '$b МБ';
  }

  @override
  String get chatSendThis => 'Надіслати файл?';

  @override
  String chatOverTor(Object humanBytes, Object wireEstimate) {
    return '$humanBytes · $wireEstimate через tor';
  }

  @override
  String get chatBigFilesGoOut =>
      'Великі файли йдуть малими зашифрованими частинами, тож це займає час. Не закривай застосунок, і надсилання триватиме.';

  @override
  String get chatSendIt => 'Надіслати';

  @override
  String get chatCouldNotReadThat => 'Не вдалося прочитати файл';

  @override
  String get chatFileTooBig8 => 'Файл завеликий · макс. 8 МБ';

  @override
  String get chatCouldNotCleanThat => 'Не вдалося очистити це відео';

  @override
  String get chatCouldNotCleanThatPictureSend =>
      'Не вдалося очистити це зображення · надішли його як фото';

  @override
  String get chatGifTooBig8 => 'GIF завеликий · макс. 8 МБ';

  @override
  String get chatCouldNotCleanThatGif => 'Не вдалося очистити цей GIF';

  @override
  String get chatTorIsNotUp => 'Tor ще не запущено · піде без прев’ю';

  @override
  String get chatCouldnTReachIt => 'Сайт не відповідає · піде без прев’ю';

  @override
  String get chatNoTitleCameBack => 'Заголовка немає · піде без прев’ю';

  @override
  String get chatCouldnTFetchIt => 'Не вдалося завантажити · піде без прев’ю';

  @override
  String get chatNoSignalSessionRe => 'Немає сесії Signal - з’єднайся заново';

  @override
  String get chatMessageUnavailable => 'Повідомлення недоступне';

  @override
  String get chatYou2 => 'Ти';

  @override
  String get chatThem => 'Співрозмовник';

  @override
  String get chatVoiceMessage => 'Голосове повідомлення';

  @override
  String get chatQuotedPhoto => 'Фото';

  @override
  String get chatViewContact => 'Переглянути контакт';

  @override
  String get chatSharedPhotos => 'Спільні фото';

  @override
  String chatSharedPhotoCount(int count, Object title) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString фото',
      many: '$countString фото',
      few: '$countString фото',
      one: '$countString фото',
    );
    return '$_temp0 · $title';
  }

  @override
  String get chatUnmuteNotifications => 'Увімкнути сповіщення';

  @override
  String get chatMuteNotifications => 'Вимкнути сповіщення';

  @override
  String get chatArchiveChat => 'Архівувати чат';

  @override
  String get chatWallpaper => 'Фон';

  @override
  String get chatClearConversation => 'Очистити розмову';

  @override
  String get chatNoteOnThisContact => 'Нотатка про контакт';

  @override
  String get chatPinToTop => 'Закріпити вгорі';

  @override
  String get chatBlockContact => 'Заблокувати контакт';

  @override
  String get chatUnpinned => 'Відкріплено';

  @override
  String get chatPinnedToTop => 'Закріплено вгорі';

  @override
  String get chatJustForYouNever =>
      'Лише для тебе. Ніколи не надсилається і ніколи не залишає цей телефон.';

  @override
  String get chatAQuietReminder => 'Тихе нагадування…';

  @override
  String get chatNoteSaved => 'Нотатку збережено';

  @override
  String get chatClearThisConversation => 'Очистити цю розмову?';

  @override
  String get chatEveryMessageHereIs =>
      'Кожне повідомлення тут буде стерто з цього телефону. Це очищає лише твою копію - пристрою співрозмовника це не торкається.';

  @override
  String get chatClear => 'Очистити';

  @override
  String get chatBlockThisContact => 'Заблокувати цей контакт?';

  @override
  String get chatTheirMessagesStopArriving =>
      'Повідомлення від цього контакту перестануть надходити, а сам він зникне з твоїх чатів. Йому про це ніколи не скажуть. Розблокувати можна будь-коли в налаштуваннях.';

  @override
  String get commonBlock => 'Заблокувати';

  @override
  String get chatSaved => 'Збережено';

  @override
  String get chatRemovedFromSaved => 'Прибрано зі збережених';

  @override
  String get chatForwardTo => 'Кому переслати';

  @override
  String get chatNoContactsToForward => 'Немає контактів, кому переслати';

  @override
  String get chatToday => 'Сьогодні';

  @override
  String get chatYesterday => 'Учора';

  @override
  String get chatThisMessageCanT => 'Це повідомлення неможливо показати';

  @override
  String get chatJumpToTheNewest => 'До найновіших';

  @override
  String get chatBuildingAPrivateRoute =>
      'Будуємо приватний маршрут · перше підключення найдовше, наступні швидкі. Усе, що надішлеш зараз, стане в чергу й доставиться само.';

  @override
  String get chatLooksSafeNothingSuspicious =>
      'Схоже, безпечно · у першому повідомленні нічого підозрілого';

  @override
  String get chatTheNextPhotoYou =>
      'Наступне фото, яке ти надішлеш, відкриється захищеним · співрозмовник не зможе зробити знімок екрана';

  @override
  String get chatPhotoProtectionOff => 'Захист фото вимкнено';

  @override
  String get chatAcceptToReplyThey =>
      'Прийми, щоб відповісти - доти співрозмовник може надіслати ще одне повідомлення.';

  @override
  String chatIntroducedYouAcceptTo(Object introducer) {
    return 'Вас познайомили через $introducer. Прийми, щоб відповісти.';
  }

  @override
  String chatIntroducedYouSayHello(Object vouchNames) {
    return 'Вас познайомили через $vouchNames. Привітайся - співрозмовник теж отримав твою картку.';
  }

  @override
  String get chatIntroduceTo => 'Познайомити з...';

  @override
  String get chatAcceptThemFirst => 'Спершу прийми запит';

  @override
  String get chatMessageRequest => 'Запит на листування';

  @override
  String get chatTheyNeedToAccept =>
      'Співрозмовник має прийняти запит, щоб ви могли спілкуватися далі.';

  @override
  String get chatWaitingForThemTo =>
      'Чекаємо, поки співрозмовник прийме твій запит';

  @override
  String get chatYouBlockedThisContact => 'Цей контакт заблоковано';

  @override
  String get chatSupporter => 'Прихильник';

  @override
  String get chatEncryptedViaRelay => 'Зашифровано · через ретранслятор';

  @override
  String get chatEncryptedDirect => 'Зашифровано · напряму';

  @override
  String get chatEncryptedOverTor => 'Зашифровано · через tor';

  @override
  String get chatSearchThisChat => 'Пошук у цьому чаті';

  @override
  String get chatContactOptions => 'Параметри контакту';

  @override
  String get commonClose => 'Закрити';

  @override
  String get chatFindInConversation => 'Пошук у розмові';

  @override
  String get chatNoMatches => 'Нічого не знайдено';

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
      other: '*$posString* з $countString збігу',
      many: '*$posString* з $countString збігів',
      few: '*$posString* з $countString збігів',
      one: '*$posString* з $countString збігу',
    );
    return '$_temp0';
  }

  @override
  String get chatPreviousMatch => 'Попередній збіг';

  @override
  String get chatNextMatch => 'Наступний збіг';

  @override
  String get chatPhotoUnavailable => 'Фото недоступне';

  @override
  String get chatDelivered => 'Доставлено';

  @override
  String get chatEdited => 'Змінено';

  @override
  String get chatWaitingForThemToComeOnline =>
      'Чекаємо, поки співрозмовник з’явиться в мережі або додасть тебе у відповідь';

  @override
  String get chatFailedTapToRetry => 'Помилка · натисни ще раз';

  @override
  String get chatReplyingTo => 'Відповідь співрозмовнику';

  @override
  String get chatReplyingToYourself => 'Відповідь собі';

  @override
  String get chatReply => 'Відповісти';

  @override
  String get chatSayHi => 'Привітайся.';

  @override
  String get chatJustTheTwoOf => 'Лише ви двоє, з наскрізним шифруванням.';

  @override
  String get chatMicPermissionNeeded => 'Потрібен дозвіл на мікрофон';

  @override
  String get chatTheMicWouldNot => 'Мікрофон не запустився. Спробуй ще раз';

  @override
  String get chatReleaseToCancel => 'Відпусти, щоб скасувати';

  @override
  String get chatVoiceHiddenSlideTo =>
      'Голос приховано · проведи, щоб скасувати';

  @override
  String get chatSlideToCancel => 'Проведи, щоб скасувати';

  @override
  String get chatGhostMode => 'Зникаючі повідомлення';

  @override
  String chatMessagesBurnAfter(Object humanBurn) {
    return 'зникають через $humanBurn';
  }

  @override
  String get chatTimedMessages => 'Зникаючі повідомлення';

  @override
  String get chatOpenTheCamera => 'Відкрити камеру';

  @override
  String get chatAttachAPhoto => 'Прикріпити фото';

  @override
  String get chatMessage => 'Повідомлення';

  @override
  String get chatDisguiseVoice => 'Змінити голос';

  @override
  String get commonSend => 'Надіслати';

  @override
  String get chatNoPhotosInThis => 'У цьому чаті ще немає фото';

  @override
  String get chatHoldToRecord => 'Утримуй, щоб записати голосове повідомлення';

  @override
  String get chatSendPhoto => 'Надіслати фото';

  @override
  String get chatAddACaption => 'Додай підпис…';

  @override
  String get chatSecurityCodeChanged => 'Код безпеки змінився';

  @override
  String chatMayHaveReinstalledOr(Object peerName) {
    return '$peerName: можливо, застосунок перевстановили, а можливо, хтось видає себе за цю людину. Щоб переконатися, звір номери безпеки.';
  }

  @override
  String get chatOk => 'Гаразд';

  @override
  String get chatVerify => 'Звірити';

  @override
  String get cleanKryfoCanTClean => 'Kryfo поки не вміє очищати такі файли.';

  @override
  String get cleanThisIsAMotion => 'Це рухоме фото.';

  @override
  String get cleanThisPictureIsToo =>
      'Це зображення завелике, щоб очистити його тут.';

  @override
  String get cleanThisFileIsDamaged => 'Цей файл пошкоджений або обрізаний.';

  @override
  String get cleanKryfoCouldNotMake => 'Kryfo не вдалося очистити цей файл.';

  @override
  String get cleanNotEnoughRoomOn => 'На телефоні замало місця.';

  @override
  String get cleanKryfoCouldNotOpen => 'Kryfo не вдалося відкрити цей файл.';

  @override
  String get cleanItCleansJpegPng =>
      'Kryfo очищає JPEG, PNG, WebP, HEIC, AVIF, GIF, MP4 і MOV. Нічого не змінено.';

  @override
  String get cleanItHoldsAShort =>
      'Поруч із зображенням у ньому є коротке відео, а цю частину Kryfo поки не вміє очищати. Вимкни рухомі фото в камері або надішли знімок екрана.';

  @override
  String get cleanPicturesOver64Mb =>
      'Зображення понад 64 МБ на телефоні не очищаються. Нічого не змінено.';

  @override
  String get cleanKryfoCouldNotRead =>
      'Kryfo не зміг дочитати файл до кінця, тож не називатиме його чистим. Копію не створено.';

  @override
  String get cleanSomethingInsideIsOf =>
      'Усередині є щось такого типу, що Kryfo не вміє прибирати, тож копію не створено.';

  @override
  String get cleanFreeSomeSpaceAnd =>
      'Звільни місце і спробуй ще раз. Нічого не змінено.';

  @override
  String get cleanTheAppThatShared =>
      'Можливо, застосунок, з якого ним поділилися, забрав його назад. Спробуй поділитися ще раз.';

  @override
  String get cleanNoAppOnThis =>
      'Жоден застосунок на цьому телефоні не прийняв файл.';

  @override
  String get cleanCouldNotSaveIt =>
      'Не вдалося зберегти. Перевір, чи є місце на телефоні.';

  @override
  String get cleanTheOriginalIsGone =>
      'Оригіналу більше немає. Чиста копія залишається.';

  @override
  String get cleanAndroidWouldNotDelete =>
      'Android не дав його видалити. Прибери його з галереї вручну.';

  @override
  String get cleanCleanCopy => 'Чиста копія';

  @override
  String get cleanShareCleanCopy => 'Поділитися чистою копією';

  @override
  String get cleanSaveToGallery => 'Зберегти в галерею';

  @override
  String get commonStop => 'Зупинити';

  @override
  String get cleanReadingTheFile => 'Читаємо файл';

  @override
  String get cleanCleaning => 'Очищаємо';

  @override
  String cleanOf(Object prettySize, Object prettySize2) {
    return '$prettySize з $prettySize2';
  }

  @override
  String get cleanEverythingStaysOnThis => 'Усе залишається на цьому телефоні.';

  @override
  String get cleanAlreadyClean => 'Уже чисто.';

  @override
  String get cleanClean => 'Чисто.';

  @override
  String get cleanThereWasNothingTo => 'Нічого не знайшлося.';

  @override
  String get cleanNothingLeftToFind => 'Більше нічого не знайти.';

  @override
  String get cleanSameVideoSameQuality => 'Те саме відео, та сама якість';

  @override
  String get cleanSamePictureSameQuality =>
      'Те саме зображення, та сама якість';

  @override
  String cleanRemoved(Object label) {
    return '$label, видалено';
  }

  @override
  String get cleanRemoved2 => 'ВИДАЛЕНО';

  @override
  String get cleanWithTheLocationInside =>
      'з місцезнаходженням усередині. Будь-хто, хто його отримає, дізнається твою вулицю.';

  @override
  String get cleanWithEverythingItKnew => 'з усім, що він знав, усередині.';

  @override
  String get cleanOriginal => 'ОРИГІНАЛ';

  @override
  String get cleanClean2 => 'ЧИСТИЙ';

  @override
  String get cleanSavedToYourGallery => 'Збережено в галерею.';

  @override
  String cleanTheOriginalIsStill(Object what) {
    return 'Оригінал теж досі там, $what';
  }

  @override
  String cleanTheOriginalIsStillWhereIt(Object what) {
    return 'Оригінал досі там, де був, $what Kryfo не може прибрати його звідси, тож видали його в застосунку, з якого він прийшов.';
  }

  @override
  String get cleanDeleteTheOriginal => 'Видалити оригінал';

  @override
  String get cleanKeepBoth => 'Залишити обидва';

  @override
  String get commonDone => 'Готово';

  @override
  String get cleanAndroidWillAskYou => 'ANDROID ПОПРОСИТЬ ПІДТВЕРДИТИ';

  @override
  String get contactYourNameForThem => 'Ім’я контакту';

  @override
  String get contactStaysOnThisPhone =>
      'Залишається на цьому телефоні. Контакт його ніколи не бачить.';

  @override
  String get contactClear => 'Очистити';

  @override
  String get contactMessage => 'Написати';

  @override
  String get contactKeysVerified => 'Ключі звірено';

  @override
  String get contactVerifyKeys => 'Звірити ключі';

  @override
  String get contactVouches => 'Рекомендації';

  @override
  String get contactUnmute => 'Увімкнути звук';

  @override
  String get contactMute => 'Без звуку';

  @override
  String get contactUnpin => 'Відкріпити';

  @override
  String get contactPinToTop => 'Закріпити вгорі';

  @override
  String get contactArchive => 'Архівувати';

  @override
  String get contactOutOfTheList =>
      'Зникне зі списку, доки контакт не напише знову';

  @override
  String contactBlock(Object name) {
    return 'Заблокувати $name?';
  }

  @override
  String get contactTheirMessagesStopArriving =>
      'Повідомлення від контакту перестануть надходити. Йому про це не скажуть.';

  @override
  String get contactDeleteChat => 'Видалити чат';

  @override
  String get contactMessagesAndContactGone =>
      'Повідомлення й контакт зникнуть із цього телефону';

  @override
  String get contactDeleteThisChat => 'Видалити цей чат?';

  @override
  String get contactEveryMessageAndThe =>
      'Усі повідомлення й сам контакт зникнуть із цього телефону. Контакту нічого не надсилається.';

  @override
  String get commonDelete => 'Видалити';

  @override
  String get contactDeleted => 'Видалено';

  @override
  String get contactToday => 'Сьогодні';

  @override
  String contactD(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дня',
      many: '$count днів',
      few: '$count дні',
      one: '$count день',
    );
    return '$_temp0';
  }

  @override
  String contactMo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count міс',
      many: '$count міс',
      few: '$count міс',
      one: '$count міс',
    );
    return '$_temp0';
  }

  @override
  String contactY(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count року',
      many: '$count років',
      few: '$count роки',
      one: '$count рік',
    );
    return '$_temp0';
  }

  @override
  String get contactVerified => 'Звірено';

  @override
  String get contactChatting => 'Спілкуєтеся';

  @override
  String get contactNothingSharedYet => 'Спільних медіа ще немає';

  @override
  String contactSharedMedia(Object count) {
    return 'Спільні медіа · $count';
  }

  @override
  String get donateBitcoin => 'Bitcoin';

  @override
  String get donateText => '₿';

  @override
  String get donateBadgeUnlocks => 'Відкриває значок';

  @override
  String get donateMonero => 'Monero';

  @override
  String get donateManualNoBadge => 'Вручну · без значка';

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
          'Твій попередній платіж у bitcoin помічено · значок прихильника відкрито',
      'patron':
          'Твій попередній платіж у bitcoin помічено · значок мецената відкрито',
      'guardian':
          'Твій попередній платіж у bitcoin помічено · значок хранителя відкрито',
      'other':
          'Твій попередній платіж у bitcoin помічено · значок прихильника відкрито',
    });
    return '$_temp0';
  }

  @override
  String get donateSupport => 'Підтримати';

  @override
  String get donateKeepKryfo => 'Збережи Kryfo *незалежним*';

  @override
  String get donateNoAdsNoInvestors =>
      'Без реклами, без інвесторів, нічого на продаж. Kryfo живе на внески тих, хто його підтримує.';

  @override
  String get donateBackItAnonymouslyBadge =>
      'Підтримай анонімно. Значок - за бажанням.\n*За приватність ніколи не треба платити.*';

  @override
  String donateAddressCheckItAgainst(Object coinName) {
    return 'Адреса $coinName · звір її з гаманцем';
  }

  @override
  String get donateAddressCopiedClearsIn =>
      'Адресу скопійовано · зникне з буфера через 60 с';

  @override
  String get donateCopyAddress => 'Копіювати адресу';

  @override
  String get donateBitcoinIsVerifiedBy =>
      'Bitcoin перевіряє наш власний вузол, тож значок відкриється сам, щойно надійде платіж.';

  @override
  String get donateWeCanTVerify =>
      'Ми не можемо перевірити цей блокчейн, не розпитуючи про тебе сторонній сервіс, тож і не перевіряємо. Надсилай, якщо хочеш. Значка це не відкриє.';

  @override
  String get donateBitcoinBadgesNeedOnion =>
      'Для значків за bitcoin потрібен режим Onion';

  @override
  String get donateSwitchToOnion => 'Перейти на Onion';

  @override
  String get donatePayWithBitcoin => 'Оплатити в bitcoin  →';

  @override
  String get donateBadgesStartAt20 => 'Значки від \$20';

  @override
  String get donateReachingThePaymentService =>
      'Звертаємося до платіжного сервісу через tor…';

  @override
  String get donateThisCanTakeUp => 'Це може тривати до хвилини';

  @override
  String donateSThisCanTake(Object waited) {
    return '$waited с · це може тривати до хвилини';
  }

  @override
  String get donateUseTheAddressInstead => 'Використати адресу';

  @override
  String get donateThePaymentServiceIs =>
      'Платіжний сервіс - це onion-адреса, і дістатися до нього можна лише в режимі Onion. Нічого не надіслано.';

  @override
  String get donateTorWasSlowTo =>
      'Tor надто довго добирався до платіжного сервісу. Можна зробити внесок на адресу нижче - просто значок не відкриється автоматично. Щоб отримати значок, спробуй пізніше.';

  @override
  String get donateThePaymentServiceIsHavingTrouble =>
      'У платіжного сервісу зараз проблеми. Ти все одно можеш зробити внесок на адресу нижче - просто значок не відкриється автоматично. Щоб отримати значок, спробуй пізніше.';

  @override
  String get commonTryAgain => 'Спробувати ще раз';

  @override
  String donateBtc(Object btc) {
    return '$btc BTC';
  }

  @override
  String donateSendExactlyThisAmount(Object fmtLeft) {
    return 'Надішли рівно цю суму · діє ще $fmtLeft';
  }

  @override
  String get donateOpenWallet => 'Відкрити гаманець';

  @override
  String get donateThisScreenUpdatesItself =>
      'Цей екран оновиться сам, щойно платіж буде помічено.\nНе закривай його - нічого не зберігається, ніщо тебе не ідентифікує.';

  @override
  String get donateWatchingTheChainFor =>
      'Стежимо за блокчейном, чекаємо на твій платіж';

  @override
  String get donateThisInvoiceExpired => 'Термін рахунку минув';

  @override
  String get donateInvoicesTimeOutIf =>
      'Рахунки діють обмежений час. Якщо платіж уже надіслано, не закривай екран: ми ще якийсь час щохвилини перепитуємо сервіс, а також наступного разу, коли ти відкриєш «Підтримати». Новий рахунок можна створити будь-коли.';

  @override
  String get donateNewInvoice => 'Новий рахунок';

  @override
  String get donateIPaidCheckAgain => 'Оплачено, перевір ще раз';

  @override
  String get donateNoWallet =>
      'На цьому телефоні немає застосунку, що відкриває посилання bitcoin. Скопіюй адресу.';

  @override
  String get donateChecking => 'Перевіряємо…';

  @override
  String get donateNotSeenYet =>
      'Поки не видно. Платіж може з’явитися за кілька хвилин.';

  @override
  String get donatePaymentConfirmed => 'Платіж підтверджено';

  @override
  String get donateThankYouForKeeping =>
      'Дякуємо, що допомагаєш Kryfo лишатися незалежним.';

  @override
  String donateVerifiedOnChainYou(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter':
          'Перевірено в блокчейні - тепер у тебе статус прихильника. Ніхто не може цього в тебе забрати.',
      'patron':
          'Перевірено в блокчейні - тепер у тебе статус мецената. Ніхто не може цього в тебе забрати.',
      'guardian':
          'Перевірено в блокчейні - тепер у тебе статус хранителя. Ніхто не може цього в тебе забрати.',
      'other':
          'Перевірено в блокчейні - тепер у тебе статус прихильника. Ніхто не може цього в тебе забрати.',
    });
    return '$_temp0';
  }

  @override
  String get donateWearMyBadge => 'Носити значок';

  @override
  String get donateJustGladToHelp => 'Просто хочу допомогти';

  @override
  String get gettingMessagesGettingMessages => 'Отримання повідомлень';

  @override
  String get gettingMessagesHowNewMessagesReach =>
      'Як нові повідомлення потрапляють на цей телефон. Змінити можна будь-коли.';

  @override
  String get gettingMessagesAlwaysOn => 'Завжди на зв’язку';

  @override
  String get gettingMessagesMostPrivate => 'Найприватніше';

  @override
  String get gettingMessagesMessagesArriveInstantlyNothing =>
      'Повідомлення приходять одразу. Ніщо не виходить за межі tor. Витрачає найбільше заряду.';

  @override
  String get gettingMessagesCheckIns => 'Перевірки';

  @override
  String get gettingMessagesLightest => 'Найощадливіше';

  @override
  String get gettingMessagesKryfoLooksForMessages =>
      'Kryfo перевіряє повідомлення кожні 15 хвилин. Батарею майже не витрачає, але повідомлення можуть запізнюватися.';

  @override
  String get gettingMessagesOnTheLockScreen => 'На заблокованому екрані';

  @override
  String get gettingMessagesHideMessagePreview => 'Приховати текст повідомлень';

  @override
  String get gettingMessagesAGenericAlertWith =>
      'Загальне сповіщення, без відправника й тексту повідомлення';

  @override
  String get gettingMessagesShowsMessageTextIn =>
      'Показує текст повідомлень у сповіщеннях, навіть коли Kryfo заблоковано.';

  @override
  String get gettingMessagesWhenThePhoneSits =>
      'Коли телефон лежить нерухомо, Android робить перевірки рідше. Рядок вище показує, коли насправді була остання. Поки Kryfo відкритий, він лишається на зв’язку.';

  @override
  String get groupChatJumpToTheNewest => 'До найновіших';

  @override
  String get groupChatBlockedEverywhere => 'Заблоковано всюди';

  @override
  String get groupChatYou => 'Ти';

  @override
  String get groupChatVoiceMessage => 'Голосове повідомлення';

  @override
  String get groupChatQuotedPhoto => 'Фото';

  @override
  String get groupChatMessageUnavailable => 'Повідомлення недоступне';

  @override
  String get groupChatTorIsNotUp => 'Tor ще не запущено · піде без прев’ю';

  @override
  String get groupChatCouldnTReachIt => 'Сайт не відповідає · піде без прев’ю';

  @override
  String get groupChatNoTitleCameBack => 'Заголовка немає · піде без прев’ю';

  @override
  String get groupChatCouldnTFetchIt =>
      'Не вдалося завантажити · піде без прев’ю';

  @override
  String get groupChatCamera => 'Камера';

  @override
  String get groupChatGallery => 'Галерея';

  @override
  String get groupChatVideo => 'Відео';

  @override
  String get groupChatGifFromPhone => 'GIF з телефону';

  @override
  String get groupChatFile => 'Файл';

  @override
  String get groupChatCouldNotReadThat => 'Не вдалося прочитати файл';

  @override
  String get groupChatGifTooBig8 => 'GIF завеликий · макс. 8 МБ';

  @override
  String get groupChatCouldNotCleanThat => 'Не вдалося очистити цей GIF';

  @override
  String get groupChatFileTooBig8 => 'Файл завеликий · макс. 8 МБ';

  @override
  String get groupChatCouldNotCleanThatVideo => 'Не вдалося очистити це відео';

  @override
  String get groupChatCouldNotCleanThatPictureSend =>
      'Не вдалося очистити це зображення · надішли його як фото';

  @override
  String get groupChat30Seconds => '30 секунд';

  @override
  String get groupChat1Minute => '1 хвилина';

  @override
  String get groupChat5Minutes => '5 хвилин';

  @override
  String get groupChat1Hour => '1 година';

  @override
  String get groupChat24Hours => '24 години';

  @override
  String get groupChatBurnTimer => 'Зникаючі повідомлення';

  @override
  String get groupChatNewMessagesDisappearAfter =>
      'Нові повідомлення зникатимуть через цей час';

  @override
  String get groupChatToday => 'Сьогодні';

  @override
  String get groupChatYesterday => 'Учора';

  @override
  String get groupChatYou2 => 'Ти';

  @override
  String groupChatThisChatHasPins(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'У цьому чаті вже $countString закріпленого повідомлення',
      many: 'У цьому чаті вже $countString закріплених повідомлень',
      few: 'У цьому чаті вже $countString закріплені повідомлення',
      one: 'У цьому чаті вже $countString закріплене повідомлення',
    );
    return '$_temp0';
  }

  @override
  String get groupChatUnpinThisMessage => 'Відкріпити повідомлення?';

  @override
  String get groupChatPinThisMessage => 'Закріпити повідомлення?';

  @override
  String get groupChatItLeavesThePinned =>
      'Воно зникне зі списку закріплених для всіх тут.';

  @override
  String get groupChatItGoesUnderThe =>
      'Воно з’явиться серед закріплених угорі чату, для всіх тут.';

  @override
  String get groupChatUnpin => 'Відкріпити';

  @override
  String get groupChatPinIt => 'Закріпити';

  @override
  String get groupChatNotNow => 'Не зараз';

  @override
  String get groupChatSaved => 'Збережено';

  @override
  String get groupChatRemovedFromSaved => 'Прибрано зі збережених';

  @override
  String get groupChatForwardTo => 'Кому переслати';

  @override
  String get groupChatNoContactsToForward => 'Немає контактів, кому переслати';

  @override
  String get groupChatEditMessage => 'Редагування';

  @override
  String get groupChatUnsendMessage => 'Відкликати повідомлення';

  @override
  String get groupChatItDisappearsWithNo =>
      'Воно зникне без сліду. Цю дію не можна скасувати.';

  @override
  String get groupChatUnsend => 'Відкликати';

  @override
  String groupChatThisRoomAndEverything(Object expiryWords) {
    return 'Ця кімната і все, що в ній, зникне $expiryWords';
  }

  @override
  String groupChatGhostModeOnBurns(Object fmtBurn) {
    return 'Зникаючі повідомлення · зникають через $fmtBurn';
  }

  @override
  String get groupChatGroupCreatedSayHi => 'Групу створено. Привітайся.';

  @override
  String get groupChatNoMessagesYet => 'Ще немає повідомлень.';

  @override
  String get groupChatEveryoneHereReads => 'Усі тут читають те, що ти пишеш.';

  @override
  String get groupChatThisMessageCanT => 'Це повідомлення неможливо показати';

  @override
  String groupChatS(Object s) {
    return '$s с';
  }

  @override
  String groupChatM(Object s) {
    return '$s хв';
  }

  @override
  String groupChatH(Object s) {
    return '$s год';
  }

  @override
  String groupChatD(Object s) {
    return '$s дн';
  }

  @override
  String groupChatHere(int count, Object time) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$time · тут $countString',
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
      other: '$countString учасника',
      many: '$countString учасників',
      few: '$countString учасники',
      one: '$countString учасник',
    );
    return '$_temp0';
  }

  @override
  String get groupChatSearchThisChat => 'Пошук у цьому чаті';

  @override
  String groupChatReplyingTo(Object name) {
    return 'Відповідь для $name';
  }

  @override
  String get groupChatReplyingToYou => 'Відповідь собі';

  @override
  String get groupChatTimedMessages => 'Зникаючі повідомлення';

  @override
  String get groupChatOpenTheCamera => 'Відкрити камеру';

  @override
  String get groupChatAttachAPhoto => 'Прикріпити фото';

  @override
  String get groupChatMessage => 'Повідомлення';

  @override
  String get groupChatDisguiseVoice => 'Змінити голос';

  @override
  String get groupChatSupporter => 'Прихильник';

  @override
  String get groupChatEdited => 'Змінено';

  @override
  String get groupChatTapToRetry => '! Натисни ще раз';

  @override
  String get groupChat0s => '0 с';

  @override
  String get groupChatReply => 'Відповісти';

  @override
  String get groupChatPin => 'Закріпити';

  @override
  String get groupChatUnsave => 'Не зберігати';

  @override
  String get groupChatForward => 'Переслати';

  @override
  String get groupInfoGroup => 'Група';

  @override
  String get groupInfoRenameGroup => 'Перейменувати групу';

  @override
  String get groupInfoRename => 'Перейменувати';

  @override
  String get groupInfoNoContactsToAdd => 'Немає кого додати';

  @override
  String get groupInfoCouldNotAdd => 'Не вдалося додати';

  @override
  String groupInfoRemove(Object haloId) {
    return 'Прибрати $haloId з групи?';
  }

  @override
  String get groupInfoTheyWillStopReceiving =>
      'Цей учасник більше не отримуватиме повідомлень із цієї групи.';

  @override
  String appGroupHoldsUpTo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'У групі може бути не більше $countString учасника',
      many: 'У групі може бути не більше $countString учасників',
      few: 'У групі може бути не більше $countString учасників',
      one: 'У групі може бути не більше $countString учасника',
    );
    return '$_temp0';
  }

  @override
  String get commonRemove => 'Прибрати';

  @override
  String get groupInfoClearThisConversation => 'Очистити цю розмову?';

  @override
  String get groupInfoEveryMessageHereIs =>
      'Кожне повідомлення тут буде стерто з цього телефону. Це очищає лише твою копію, інші учасники зберігають свої.';

  @override
  String get groupInfoClear => 'Очистити';

  @override
  String get groupInfoConversationCleared => 'Розмову очищено';

  @override
  String get groupInfoLeaveRoom => 'Вийти з кімнати?';

  @override
  String get groupInfoLeaveGroup => 'Вийти з групи?';

  @override
  String get groupInfoEverythingInItIs =>
      'Усе, що в ній є, одразу буде стерто з цього телефону, а твій ключ від неї зникне назавжди.';

  @override
  String groupChatYouWereRemovedFrom(Object name) {
    return 'Тебе видалили з «$name»';
  }

  @override
  String get groupInfoLeaveGroupLine =>
      'Ти перестанеш отримувати її повідомлення, а все, що в ній є, буде стерто з цього телефону.';

  @override
  String get groupInfoLeaveGroupAdmin =>
      'Ти перестанеш отримувати її повідомлення, а все, що в ній є, буде стерто з цього телефону. Ти її адмін, тож після твого виходу ніхто не зможе змінювати склад групи чи перейменувати її.';

  @override
  String get groupInfoLeaveRoomMaker =>
      'Усе, що в ній є, одразу буде стерто з цього телефону, а твій ключ від неї зникне назавжди. Це твоя кімната, тож за її посиланням більше ніхто не ввійде.';

  @override
  String get groupInfoLeave => 'Вийти';

  @override
  String get groupInfoGroupInfo => 'Про групу';

  @override
  String groupInfo1Member(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString учасника',
      many: '$countString учасників',
      few: '$countString учасники',
      one: '$countString учасник',
    );
    return '$_temp0';
  }

  @override
  String get groupInfoAdmin => 'Адмін';

  @override
  String get groupInfoMembers2 => 'Учасники';

  @override
  String get groupInfoInvite => 'Запросити';

  @override
  String get commonAdd => 'Додати';

  @override
  String get groupInfoYou => 'Ти';

  @override
  String get groupInfoRemoveFromGroup => 'Прибрати з групи';

  @override
  String get groupInfoWallpaper => 'Фон';

  @override
  String get groupInfoSharedMedia => 'Спільні медіа';

  @override
  String get groupInfoClearConversation => 'Очистити розмову';

  @override
  String get groupInfoLeaveRoom2 => 'Вийти з кімнати';

  @override
  String get groupInfoLeaveGroup2 => 'Вийти з групи';

  @override
  String get groupInfoAddMembers => 'Додати учасників';

  @override
  String groupInfoAdd(Object pickedLength) {
    return 'Додати $pickedLength';
  }

  @override
  String handleYouAre(Object h) {
    return 'Ти - @$h';
  }

  @override
  String get handleHandleDeletedThePage =>
      'Ім’я користувача видалено · сторінки більше немає';

  @override
  String get handlePublicHandle => 'Публічне ім’я користувача';

  @override
  String get handleOptionalYourThreeWords =>
      'Необов’язково. Твої три слова працюють у будь-якому разі.';

  @override
  String get handleWren => 'sova';

  @override
  String get handleALineAboutYou => 'Рядок про тебе · необов’язково';

  @override
  String get handleClaiming => 'Займаємо…';

  @override
  String get handleClaimThisHandle => 'Зайняти ім’я користувача';

  @override
  String get handleAnyoneWithThisLink =>
      'Будь-хто з цим посиланням може почати з тобою приватний чат. У ньому лише твоє запрошення і нічого більше.';

  @override
  String get handleLinkCopied => 'Посилання скопійовано';

  @override
  String get handleDeleteThisHandle => 'Видалити ім’я користувача';

  @override
  String handleDeleteTitle(Object handle) {
    return 'Видалити @$handle?';
  }

  @override
  String get handleDeleteLine =>
      'Твоя публічна сторінка зникне, і ім’я зможе зайняти будь-хто. Твої чати залишаться як є.';

  @override
  String get handleDeleteYes => 'Видалити ім’я користувача';

  @override
  String get handleDeleting => 'Видаляємо…';

  @override
  String get handleChecking => 'Перевіряємо…';

  @override
  String get handleAvailable => '✓ Вільне';

  @override
  String get handleAlreadyTaken => 'Уже зайняте';

  @override
  String get handleNameRule => 'Від 3 до 20 символів: a-z, 0-9 або _';

  @override
  String get handleWhatAHandleDoes => 'Що дає ім’я користувача';

  @override
  String get handleAnyoneWhoKnowsIt =>
      'Будь-хто, хто його знає, може попросити дозволу тобі написати - для цього воно й існує. На сторінці лише твоє запрошення і твій рядок, більше нічого, і вона не записує, хто її читає. Видалити його можна будь-коли.';

  @override
  String handleIsNotYoursOn(Object handle) {
    return '@$handle не належить тобі на цьому телефоні';
  }

  @override
  String handleTheRegistryHoldsIt(Object handle) {
    return 'Реєстр тримає його під іншим ключем - найімовірніше, під ідентичністю, яка була на цьому телефоні до відновлення. Ті, хто додає @$handle, потрапляють не до тебе. Звільнити чи оновити його звідси неможливо. Обери інше ім’я.';
  }

  @override
  String get handleForgetItOnThis => 'Забути на цьому телефоні';

  @override
  String get homeAddAContact => 'Додати контакт';

  @override
  String get commonSettings => 'Налаштування';

  @override
  String get homeYourKryfo => 'Твій Kryfo';

  @override
  String homeDateWeekday(Object weekday) {
    return '$weekday,';
  }

  @override
  String get homeAnHour => 'годину';

  @override
  String homeHours(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString години',
      many: '$countString годин',
      few: '$countString години',
      one: '$countString годину',
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
      other: '$countString хвилини',
      many: '$countString хвилин',
      few: '$countString хвилини',
      one: '$countString хвилину',
    );
    return '$_temp0';
  }

  @override
  String get homeKryfoIsOffline => 'Kryfo офлайн';

  @override
  String homeTorHasNotBeen(Object howLong) {
    return 'Tor не може підключитися вже $howLong. Доки це не станеться, нічого не прийде й не піде.';
  }

  @override
  String get homeReconnecting => 'Перепідключення';

  @override
  String get homeReconnect => 'Перепідключити';

  @override
  String get homeWhatIsWrong => 'Що не так';

  @override
  String get homeKryfoWillCheckIn =>
      'Kryfo перевірятиме повідомлення кожні 15 хвилин';

  @override
  String get homeYourPhoneKeepsStopping =>
      'Твій телефон раз у раз зупиняє Kryfo';

  @override
  String get homeItHasClosedKryfo =>
      'Сьогодні він уже тричі закривав Kryfo, тож повідомлення запізнювалися або чекали. Перевірки це витримують: Kryfo прокидається кожні 15 хвилин замість того, щоб постійно бути на зв’язку.';

  @override
  String get homeSwitchToCheckIns => 'Перейти на перевірки';

  @override
  String get homeNotNow => 'Не зараз';

  @override
  String get homeNotificationsAreOff => 'Сповіщення вимкнено';

  @override
  String get homeAndroidIsBlockingThem =>
      'Android їх блокує, тож поки Kryfo закритий, до тебе нічого не доходить. Повідомлення все одно прийдуть, коли ти його відкриєш.';

  @override
  String get homeCouldnTOpenIt =>
      'Не вдалося відкрити. Пошукай Kryfo в налаштуваннях телефону';

  @override
  String get homeTurnThemOn => 'Увімкнути';

  @override
  String get homeLeaveThemOff => 'Залишити вимкненими';

  @override
  String get homeOurRelayIsQuiet => 'Наш ретранслятор мовчить';

  @override
  String get homeRelayModeUsesOnly =>
      'Режим ретранслятора використовує лише наш власний ретранслятор, а він зараз не відповідає. Швидкий режим додає до нього публічні ретранслятори, тож повідомлення все одно доходять. У будь-якому разі все лишається запечатаним.';

  @override
  String get homeSwitchedToFast => 'Тепер швидкий режим';

  @override
  String get homeUseFastMode => 'Перейти на швидкий';

  @override
  String get homeKeepWaiting => 'Чекати далі';

  @override
  String get homeNotConnecting => 'Не підключається';

  @override
  String get homeBridgesAreOnAnd =>
      'Мости ввімкнено, а tor досі не пробився. Мости повільніші, а деякі перестають працювати без попередження. Якщо твоя мережа не блокує tor, напряму швидше й надійніше.';

  @override
  String get homeGoingDirectReconnecting => 'Напряму · перепідключення';

  @override
  String get homeTurnBridgesOff => 'Вимкнути мости';

  @override
  String get homeStillTrying => 'Ще пробуємо';

  @override
  String get homeTorIsNotGetting =>
      'Tor не пробивається. Деякі мережі навмисно його блокують. Наш власний ретранслятор - це одне звичайне з’єднання, і зазвичай він працює й так. Або мости, але їх довше налаштовувати.';

  @override
  String get homeSwitchedToRelay => 'Тепер через ретранслятор';

  @override
  String get homeUseOurRelay => 'Ретранслятор';

  @override
  String get homeBridges => 'Мости';

  @override
  String get homeOffline => 'Офлайн';

  @override
  String get homeWaiting => 'Очікування';

  @override
  String get homeNothingWaitingToSend => 'Черга порожня';

  @override
  String homeWaitingSendsWhenYou(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString в черзі · надішлемо, коли будеш онлайн',
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
      other: '$countString в черзі · tor ще підключається',
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
      other: '$countString в черзі · чекаємо, поки тебе додадуть у відповідь',
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
          '$countString в черзі · чекають, поки тебе додадуть у відповідь: $parkedString',
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
      other: '$countString в черзі · надсилаємо',
    );
    return '$_temp0';
  }

  @override
  String get commonRetry => 'Повторити';

  @override
  String get homeNoKryfosYet => 'Ще жодного Kryfo.';

  @override
  String get homeScanTheirCodeSend =>
      'Відскануй код, надішли посилання або введи @ім’я користувача, яке тобі дали.';

  @override
  String get homeAddSomeone => 'Додати когось';

  @override
  String get homeArchived => 'Архів';

  @override
  String home1Chat(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString чату',
      many: '$countString чатів',
      few: '$countString чати',
      one: '$countString чат',
    );
    return '$_temp0';
  }

  @override
  String get homeGroups => 'Групи';

  @override
  String get homeRoom => 'Кімната';

  @override
  String get homeNew => 'Нова';

  @override
  String homeRoomExpired(Object expiredRoomName) {
    return '$expiredRoomName · час кімнати минув';
  }

  @override
  String get homeMentionedYou => 'Тебе згадали';

  @override
  String homeMembers(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString учасника',
      many: '$countString учасників',
      few: '$countString учасники',
      one: '$countString учасник',
    );
    return '$_temp0';
  }

  @override
  String get homeSupporter => 'Прихильник';

  @override
  String get homeArchivedChats => 'Архівовані чати';

  @override
  String get homeUnmute => 'Увімкнути звук';

  @override
  String get homeMute => 'Без звуку';

  @override
  String get homeArchive => 'Архівувати';

  @override
  String get homeDeleteChat => 'Видалити чат';

  @override
  String get homeMessagesAndContactGone =>
      'Повідомлення й контакт зникнуть із цього телефону';

  @override
  String get homeDeleteThisChat => 'Видалити цей чат?';

  @override
  String homeEveryMessageWithGoes(Object c) {
    return '$c: усе листування зникне, а контакт буде видалено. Це очищає лише цей телефон - у співрозмовника його копія залишиться. Якщо тобі знову напишуть, повідомлення потрапить у запити.';
  }

  @override
  String get homeQueued => 'У черзі';

  @override
  String get homeBlocked => 'Заблоковано';

  @override
  String get homeRoomInvite => 'Запрошення в кімнату';

  @override
  String get homeNow => 'Зараз';

  @override
  String homeM(Object inMinutes) {
    return '$inMinutes хв';
  }

  @override
  String homeH(Object inHours) {
    return '$inHours год';
  }

  @override
  String get homeYesterday => 'Учора';

  @override
  String homeD(Object inDays) {
    return '$inDays дн';
  }

  @override
  String get homeNoteToSelf => 'Нотатки для себе';

  @override
  String get homeOnlyOnThisPhone => 'Лише на цьому телефоні';

  @override
  String get homeSaved => 'Збережені';

  @override
  String get homeKeptFromEveryChat => 'Збережене з усіх чатів';

  @override
  String get homeRequests => 'Запити';

  @override
  String home1PersonWantsTo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString людини хочуть з тобою зв’язатися',
      many: '$countString людей хочуть з тобою зв’язатися',
      few: '$countString людини хочуть з тобою зв’язатися',
      one: '$countString людина хоче з тобою зв’язатися',
    );
    return '$_temp0';
  }

  @override
  String introduceGotItButCould(Object b, Object c) {
    return '$b - доставлено, $c - не вдалося зв’язатися';
  }

  @override
  String introduceGotItButCouldNotBe(Object c, Object b) {
    return '$c - доставлено, $b - не вдалося зв’язатися';
  }

  @override
  String introduceIntroduced(Object b, Object c) {
    return '$b і $c отримали картки одне одного';
  }

  @override
  String get introduceCouldNotReachEither =>
      'Не вдалося зв’язатися з жодним із них. Спробуй пізніше';

  @override
  String introduceIntroduceTo(Object peerName) {
    return 'Познайомити $peerName з...';
  }

  @override
  String get introduceBothOfThemGet =>
      'Кожен отримає картку іншого. Ніхто з них не побачить, як ти називаєш іншого.';

  @override
  String get introduceNoOneElseTo =>
      'Поки нема кого знайомити. Спершу додай ще один контакт.';

  @override
  String get introduceANoteLikeMy =>
      'Примітка, як-от «мій двоюрідний брат» - необов’язково';

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
      other: 'Цього тижня лишилося $leftString з $maxString знайомства',
      many: 'Цього тижня лишилося $leftString з $maxString знайомств',
      few: 'Цього тижня лишилося $leftString з $maxString знайомств',
      one: 'Цього тижня лишилося $leftString з $maxString знайомства',
    );
    return '$_temp0';
  }

  @override
  String introduceNoIntroductionsLeftNext(Object refillPhrase) {
    return 'Знайомства закінчилися. Наступне буде доступне $refillPhrase';
  }

  @override
  String get introduceIntroduce => 'Познайомити';

  @override
  String get keyVerificationSafetyNumber => 'Номер безпеки';

  @override
  String keyVerificationWith(Object peerName) {
    return 'Контакт: $peerName';
  }

  @override
  String keyVerificationIfSeesTheSame(Object peerName) {
    return 'Якщо $peerName бачить той самий номер, ваші повідомлення бачите лише ви двоє. Звірити особисто або під час дзвінка, якому ти довіряєш, - найнадійніший спосіб переконатися, але це необов’язково і для спілкування ніколи не потрібно.';
  }

  @override
  String get keyVerificationVerified => 'Звірено';

  @override
  String get keyVerificationMarkAsVerified => 'Позначити як звірений';

  @override
  String get lockFileThatPasswordDoesNot => 'Цей пароль його не відкриває.';

  @override
  String get lockFileThisFileIsDamaged => 'Цей файл пошкоджений.';

  @override
  String get lockFileThisFileWasLocked =>
      'Цей файл замкнено ключем, а не паролем.';

  @override
  String get lockFileThisIsNotA => 'Це не замкнений файл.';

  @override
  String get lockFileNotEnoughFreeMemory => 'Зараз замало вільної пам’яті.';

  @override
  String get lockFileStopped => 'Зупинено.';

  @override
  String get lockFileItNeedsAPassword => 'Потрібен пароль.';

  @override
  String get lockFileKryfoCouldNotRead =>
      'Kryfo не зміг прочитати або записати файл.';

  @override
  String get lockFileCheckCapitalsAndSpaces =>
      'Перевір великі літери й пробіли. Ніхто не може його скинути, навіть ми.';

  @override
  String get lockFileItMayHaveBeen =>
      'Можливо, він обрізався дорогою. Попроси надіслати його ще раз. Нічого не збережено.';

  @override
  String get lockFileItOpensWithThe =>
      'Він відкривається файлом ключа людини, для якої його створено, в інструменті age на комп’ютері. Kryfo відкриває ті, що з паролем.';

  @override
  String get lockFileKryfoOpensFilesLocked =>
      'Kryfo відкриває файли, замкнені за допомогою age. Зазвичай їхні назви закінчуються на .age.';

  @override
  String get lockFileCloseAFewApps =>
      'Закрий кілька застосунків і спробуй ще раз. Перевірці пароля ненадовго потрібно кілька сотень мегабайтів.';

  @override
  String get lockFileNothingWasSaved => 'Нічого не збережено.';

  @override
  String get lockFileTypeOneOrLet =>
      'Введи свій або дозволь Kryfo запропонувати чотири слова.';

  @override
  String get lockFileTheAppThatHolds =>
      'Можливо, застосунок, де він зберігається, забрав його назад. Вибери його ще раз.';

  @override
  String get lockFileHidePassword => 'Сховати пароль';

  @override
  String get lockFileShowPassword => 'Показати пароль';

  @override
  String get lockFileChangeFile => 'Змінити файл';

  @override
  String get lockFileChange => 'Змінити';

  @override
  String lockFileOf(Object prettySize, Object prettySize2) {
    return '$prettySize з $prettySize2';
  }

  @override
  String get lockFileEverythingStaysOnThis =>
      'Усе залишається на цьому телефоні.';

  @override
  String get lockFileCouldNotMakeOne => 'Не вдалося створити. Введи свій.';

  @override
  String get lockFileWriteItDownBefore => 'Запиши його, перш ніж замкнути файл';

  @override
  String get lockFileNoAppOnThis =>
      'Жоден застосунок на цьому телефоні не прийняв файл.';

  @override
  String get lockFileSaved => 'Збережено';

  @override
  String get lockFileCouldNotSaveIt =>
      'Не вдалося зберегти туди. Спробуй іншу папку.';

  @override
  String get lockFileLocked => 'Замкнено';

  @override
  String get lockFileLockAFile => 'Замкнути файл';

  @override
  String get lockFileMixingThePassword => 'Перемішуємо пароль';

  @override
  String get lockFileLocking => 'Замикаємо';

  @override
  String get lockFileSaveToFiles => 'Зберегти у Файли';

  @override
  String get lockFileLockFile => 'Замкнути файл';

  @override
  String get lockFileOnePassword => 'Один пароль.';

  @override
  String get lockFileNothingElseOpensIt => 'Більше ніщо його не відкриє.';

  @override
  String get lockFileFile => 'Файл';

  @override
  String lockFileFromFiles(Object prettySize) {
    return '$prettySize · з Файлів';
  }

  @override
  String get lockFileFromFiles2 => 'З Файлів';

  @override
  String get lockFilePassword => 'Пароль';

  @override
  String get lockFileSuggestFourWords => 'Запропонувати чотири слова';

  @override
  String get lockFileTypeItAgain => 'Введи ще раз';

  @override
  String get lockFileTheTwoDoNot => 'Паролі поки не збігаються.';

  @override
  String get lockFileHideTheFileName => 'Приховати назву файлу';

  @override
  String lockFileItWillBeCalled(Object name) {
    return 'Він називатиметься «$name». Скажи отримувачу, що це за файл.';
  }

  @override
  String get lockFileTheNameAloneCan => 'Сама назва може видати, що всередині.';

  @override
  String get lockFileAnyoneWithThePassword =>
      'Будь-хто з паролем може його відкрити - у Kryfo або на будь-якому комп’ютері з безкоштовним інструментом age. Забудеш пароль - і файл утрачено назавжди. Ніхто не може його скинути, навіть ми.';

  @override
  String get lockFileLocked2 => 'Замкнено.';

  @override
  String get lockFileOnlyThePasswordOpens => 'Відкрити його може лише пароль.';

  @override
  String lockFileSafeToEmailOr(Object prettySize) {
    return '$prettySize · можна безпечно надіслати поштою чи записати на флешку';
  }

  @override
  String get lockFileNoKryfoOnThe => 'В отримувача немає Kryfo? На комп’ютері:';

  @override
  String get lockFileItAsksForThe =>
      'Він попросить пароль. age безкоштовний на age-encryption.org';

  @override
  String lockTooManyTriesS(Object lockState) {
    return 'Забагато спроб · $lockState с';
  }

  @override
  String get lockNotIt => 'Не той';

  @override
  String get lockYourPin => 'Твій PIN-код';

  @override
  String get lockUseFingerprint => 'Використати відбиток';

  @override
  String get lockSetupUnlockWithFingerprint => 'Розблоковувати відбитком?';

  @override
  String get lockSetupThePinStillWorks =>
      'PIN-код і далі працюватиме, коли захочеш. Так просто швидше.';

  @override
  String get lockSetupUseFingerprint => 'Використати відбиток';

  @override
  String get lockSetupPinOnly => 'Лише PIN-код';

  @override
  String get lockSetupOnceMore => 'Ще раз';

  @override
  String get lockSetupSetAPin => 'Задати PIN-код';

  @override
  String get lockSetupThoseWereDifferentFrom => 'Коди не збіглися. Спочатку.';

  @override
  String get lockSetupTheSameFourDigits => 'Ті самі цифри ще раз';

  @override
  String get lockSetupFourDigitsAnythingYou =>
      'Чотири цифри або більше, які ти запам’ятаєш';

  @override
  String get modesOnion => 'Onion';

  @override
  String get modesFullOnionRoutingThree =>
      'Повна onion-маршрутизація, три вузли. Повідомлення йде від двох до п’яти секунд. Ніхто не бачить, з ким ти спілкуєшся.';

  @override
  String get modesSlower => 'Повільніше';

  @override
  String get modesRelay => 'Ретранслятор';

  @override
  String get modesOneSealedConnectionTo =>
      'Одне запечатане з’єднання з власним ретранслятором Kryfo, як VPN, якому нічого записувати в журнал. Повідомлення доходять приблизно за секунду, і це працює там, де tor заблоковано.';

  @override
  String get modesQuick => 'Швидко';

  @override
  String get modesRelayOnly => 'Лише ретранслятор';

  @override
  String get modesFast => 'Швидкий';

  @override
  String get modesPlainConnectionsToEvery =>
      'Звичайні з’єднання з кожним ретранслятором. Майже миттєво, і найменш приватно з трьох.';

  @override
  String get modesInstant => 'Миттєво';

  @override
  String get modesEveryRelayYouUse =>
      'Кожен ретранслятор, яким ти користуєшся, а не лише наш, знає адресу, з якої ти підключаєшся. Повідомлення й далі запечатані, але сам факт надсилання - ні. За замовчуванням вимкнено і знову вимикається після перевстановлення.';

  @override
  String get modesSpeed => 'Швидкість';

  @override
  String get modesPrivacy => 'і приватність';

  @override
  String get modesChangeGloballyOrPer =>
      'Змінюй для всіх чатів або для кожного окремо';

  @override
  String get modesSoon => 'Скоро';

  @override
  String get modesActive => 'Активний';

  @override
  String get modesSpeed2 => 'ШВИДКІСТЬ';

  @override
  String get modesHops => 'ВУЗЛИ';

  @override
  String get modesIp => 'IP';

  @override
  String get modesVisible => 'Видима';

  @override
  String get modesHidden => 'Прихована';

  @override
  String modesHeadsUp(Object warning) {
    return '*Увага:* $warning';
  }

  @override
  String get modesOnionIsTheDefault =>
      'Onion - режим за замовчуванням, і так буде, доки ти його не зміниш. Зміна діє з наступного повідомлення.';

  @override
  String get modesFastMode => 'Швидкий режим';

  @override
  String get modesPlainConnectionsToEveryRelayQuicker =>
      'Звичайні з’єднання з кожним ретранслятором. Швидше, і ретранслятори можуть бачити твою IP-адресу. Повідомлення в будь-якому разі лишаються наскрізно зашифрованими.';

  @override
  String get modesTurnOnFastMode => 'Увімкнути швидкий режим';

  @override
  String get modesKeepItOff => 'Не вмикати';

  @override
  String get movedWipeThisPhone => 'Стерти Kryfo з цього телефона?';

  @override
  String get movedEverythingKryfoHoldsHere =>
      'Усе, що Kryfo зберігає тут, зникне: повідомлення, контакти, ключі. На іншому пристрої все це залишиться. Цю дію не можна скасувати.';

  @override
  String get movedWipeIt => 'Стерти';

  @override
  String get movedNotMovingAfterAll => 'Усе-таки не переїжджаєш?';

  @override
  String get movedOnlyDoThisIf =>
      'Роби це, лише якщо резервну копію ніколи й ніде не імпортували. Якщо імпортували, то тепер одна ідентичність є на двох пристроях, і повідомлення почнуть губитися на обох.';

  @override
  String get movedIMStayingHere => 'Я лишаюся тут';

  @override
  String get movedStayingHere => 'Лишаєшся тут';

  @override
  String movedKryfoWillCloseNow(Object myId) {
    return 'Kryfo зараз закриється. Натисни іконку, щоб знову відкрити його як $myId.';
  }

  @override
  String get movedReopenKryfo => 'Відкрити Kryfo знову';

  @override
  String get movedThisKryfoHasMoved => 'Цей Kryfo переїхав';

  @override
  String movedIsNowOnAnother(Object myId) {
    return '$myId тепер на іншому пристрої. Цей телефон ще може показати те, що тут було, але нічого нового сюди не прийде, а все, що ти надішлеш звідси, ні до кого не дійде.';
  }

  @override
  String get movedKeepItToRead => 'Лишити для читання';

  @override
  String get movedWipeThisPhone2 => 'Стерти Kryfo з цього телефона';

  @override
  String get movedIMNotMoving => 'Я все-таки не переїжджаю';

  @override
  String get myKryfoAHandleIs3 =>
      'Ім’я користувача - це від 3 до 20 літер, цифр або _';

  @override
  String get myKryfoInviteCopiedClearsIn =>
      'Запрошення скопійовано · зникне з буфера через 60 с';

  @override
  String myKryfoAddMeOnKryfo(Object myId, Object uri) {
    return 'Додай мене в Kryfo. Мій Kryfo ID: $myId\n\nНатисни, щоб додати мене:\n$uri\n\nKryfo - приватний месенджер. Без номера телефону, без пошти.';
  }

  @override
  String get myKryfoAddMeOnKryfo2 => 'Додай мене в Kryfo';

  @override
  String get myKryfoAddSomeone => 'Додати когось';

  @override
  String get myKryfoKryfoDoesnTScan =>
      'Kryfo не сканує твої контакти, у цьому й суть.';

  @override
  String get myKryfoIfThisLinkEnds =>
      'Якщо це посилання опиниться не там, де треба, скинь його в налаштуваннях. Тоді всім, у кого воно є, знадобиться нове.';

  @override
  String get myKryfoAlreadyShareAFriend =>
      'Є спільний друг у Kryfo? Нехай познайомить вас у своєму чаті - і запит не знадобиться.';

  @override
  String get myKryfoHandleCopied => 'Ім’я скопійовано';

  @override
  String get myKryfoTheyReHereWith => 'Людина поруч зі мною';

  @override
  String get myKryfoPointYourPhonesAt =>
      'Наведіть телефони один на одного. Ніщо не йде через сервер.';

  @override
  String get myKryfoScanTheirsInstead => 'Або відскануй код';

  @override
  String get myKryfoTheyReadYouA => 'Тобі диктують код';

  @override
  String get myKryfoTheyReSomewhereElse => 'Людина деінде';

  @override
  String get myKryfoSendThemALink =>
      'Надішли посилання. Воно відкриється одразу на додаванні.';

  @override
  String get myKryfoYourLinkAppearsOnce =>
      'Твоє посилання з’явиться, щойно ти підключишся';

  @override
  String get myKryfoTheLinkCarriesYour =>
      'У посиланні твій ID, твоя адреса і ключі, щоб почати чат. Воно діє, доки ти не скинеш його в налаштуваннях.';

  @override
  String get myKryfoSendTheLink => 'Надіслати посилання';

  @override
  String get myKryfoAsACard => 'Як картку';

  @override
  String get myKryfoAnImageWithThe => 'Зображення з QR';

  @override
  String get myKryfoAsAFile => 'Як файл';

  @override
  String get myKryfoContactFile => 'Файл контакту';

  @override
  String get myKryfoIKnowTheirHandle => 'Я знаю ім’я користувача';

  @override
  String get myKryfoTypeTheNameThey =>
      'Введи @ім’я, яке тобі дали. Спрацює, якщо в людини воно є.';

  @override
  String get myKryfoTheLookupAsksFor =>
      'Пошук надсилає лише це одне ім’я і нічого про тебе. Твоє перше повідомлення все одно надійде як запит.';

  @override
  String get myKryfoLooking => 'Шукаємо…';

  @override
  String get myKryfoFindThem => 'Знайти';

  @override
  String get myKryfoYourAddressAppearsOnce =>
      'Твоя адреса з’явиться, щойно ти підключишся';

  @override
  String get myKryfoAPublicHandle => 'Публічне ім’я користувача';

  @override
  String get myKryfoPutItInA =>
      'Додай його в біо. Будь-хто, хто його знає, може тебе знайти.';

  @override
  String get myKryfoANamePeopleCan =>
      'Ім’я, за яким тебе можна знайти. Вимкнено, доки ти його не займеш.';

  @override
  String get newGroupCouldNotCreate => 'Не вдалося створити';

  @override
  String get newGroupNewGroup => 'Нова група';

  @override
  String get newGroupCreating => 'Створення…';

  @override
  String get newGroupCreate => 'Створити';

  @override
  String get newGroupGroupName => 'Назва групи';

  @override
  String get newGroupMembers => 'Учасники';

  @override
  String get newGroupPickAtLeastOne => 'Обери хоча б одного';

  @override
  String newGroupSelected(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString вибрано',
    );
    return '$_temp0';
  }

  @override
  String get newGroupAddAtLeastOne =>
      'Щоб створити групу, спершу додай хоча б один контакт.';

  @override
  String get notesDeleteThisNote => 'Видалити цю нотатку?';

  @override
  String get notesGoneFromThisPhone =>
      'Її буде стерто з цього телефону назавжди.';

  @override
  String get notesNoteToSelf => 'Нотатки для себе';

  @override
  String get notesOnlyOnThisPhone => 'Лише на цьому телефоні';

  @override
  String get notesAQuietPlace => 'Тихе місце';

  @override
  String get notesJotAnythingDownIt =>
      'Записуй будь-що. Усе залишається на цьому телефоні й ніколи його не покидає.';

  @override
  String get notesJotSomethingDown => 'Запиши щось…';

  @override
  String get onboardingPrivateByDefault => 'ПРИВАТНО ЗА ЗАМОВЧУВАННЯМ';

  @override
  String get onboardingPrivateMessaging =>
      'Приватне листування,\n*без підступу*.';

  @override
  String get onboardingYourNameIsThree =>
      '*Твоє ім’я - три слова.* Без телефону, без пошти, без адресної книги.';

  @override
  String get onboardingNobodyGetsInUnless =>
      '*Ніхто не ввійде без твого дозволу.* Пошуку немає. Людей додають вручну, з обох боків.';

  @override
  String get onboardingTheFirstConnectionTakes =>
      '*Перше підключення триває хвилину.* Kryfo будує приватний маршрут, перш ніж щось надіслати. Далі швидко.';

  @override
  String get onboardingBegin => 'Почати';

  @override
  String get onboardingHaveABackupRestore => 'Є резервна копія? Відновити →';

  @override
  String get onboardingKryfoIsOpenSource => 'Kryfo має відкритий код';

  @override
  String get onboardingYourKryfoId => 'ТВІЙ KRYFO ID';

  @override
  String get onboardingGeneratedFromAKey =>
      'Створено з ключа, який є лише на цьому телефоні. *Легко запам’ятати, унікальне, лише твоє.* Більше ні в кого такого немає.';

  @override
  String get onboardingTryAnother => 'Спробувати інше';

  @override
  String get onboardingUseThisName => 'Обрати це ім’я →';

  @override
  String get onboardingThreeWords => 'Три слова. *Лише твої.*';

  @override
  String get onboardingPickA => 'Обери *обличчя*.';

  @override
  String get onboardingDrawnOnThisPhone =>
      'Намальоване на цьому телефоні з числа, ніколи не вивантажується. Змінити можна будь-коли.';

  @override
  String get onboardingThePeopleYouMessage =>
      'Люди, яким ти пишеш, теж це бачать';

  @override
  String get onboardingKeepMyInitial => 'Лишити мій ініціал';

  @override
  String get onboardingThatOne => 'Оце →';

  @override
  String get onboardingContinue => 'Далі →';

  @override
  String get onboardingHowYourMessages => 'Як *подорожують* твої повідомлення.';

  @override
  String get onboardingYouCanChangeThis =>
      'Це можна будь-коли змінити в налаштуваннях - для всіх чатів або для одного.';

  @override
  String get onboardingOnion => 'Onion';

  @override
  String get onboardingSlowerAMessageTakes =>
      'Повільніше. Повідомлення йде від двох до п’яти секунд.';

  @override
  String get onboardingHidesYourAddressFrom =>
      'Приховує твою адресу від усіх, зокрема від нашого ретранслятора.';

  @override
  String get onboardingRelay => 'Ретранслятор';

  @override
  String get onboardingOurRelaySeesYour =>
      'Наш ретранслятор бачить твою адресу. Більше ніхто.';

  @override
  String get onboardingAboutASecondWorks =>
      'Близько секунди. Працює там, де tor заблоковано.';

  @override
  String get onboardingFast => 'Швидкий';

  @override
  String get onboardingEveryRelayYouUse =>
      'Кожен ретранслятор, яким ти користуєшся, бачить твою адресу. Найменш приватний з трьох.';

  @override
  String get onboardingNearInstant => 'Майже миттєво.';

  @override
  String get onboardingKeepOnion => 'Лишити Onion →';

  @override
  String get onboardingUseThis => 'Обрати цей →';

  @override
  String get onboardingSkipOnionIsA =>
      'Пропустити · Onion - добрий вибір за замовчуванням';

  @override
  String get onboardingThreeThingsThen => 'Три речі,\nі *можна починати*.';

  @override
  String get onboardingEverythingElseTheApp =>
      'Про все інше застосунок скаже тоді, коли це буде важливо.';

  @override
  String get onboardingYourNameIsThreeWords => 'Твоє ім’я - три слова';

  @override
  String get onboardingThatIsTheWhole =>
      'Це вся твоя ідентичність. Жодного номера, який може витекти, жодної пошти для фішингу, нічого, що можна знайти в пошуку. Ті, з ким ти спілкуєшся, бачать ці слова й вибране тобою обличчя.';

  @override
  String get onboardingNobodyCanReachYou =>
      'Ніхто не достукається до тебе, доки ти не впустиш';

  @override
  String get onboardingAStrangerWithYour =>
      'Незнайомець, який знає твої слова, може лише постукати. Його перше повідомлення чекає в запитах, доки ти не скажеш «так», а відмовити можна так, що він про це ніколи не дізнається.';

  @override
  String get onboardingTheFirstConnectionTakesAMinute =>
      'Перше підключення триває хвилину';

  @override
  String get onboardingKryfoBuildsAPrivateRouteBefore =>
      'Kryfo будує приватний маршрут, перш ніж щось надіслати. Поки ти офлайн, повідомлення чекають і приходять, коли ти повертаєшся.';

  @override
  String get onboardingYourIdentityLivesOn =>
      'Твоя ідентичність живе на цьому телефоні. Зроби резервну копію в налаштуваннях, коли захочеш.';

  @override
  String get onboardingIUnderstand => 'Зрозуміло →';

  @override
  String get onboardingOneQuiet => 'Одне тихе *сповіщення*.';

  @override
  String get onboardingAndroidNeedsAVisible =>
      'Android вимагає видимого сповіщення, поки застосунок слухає у фоні. Так повідомлення доходять до тебе, коли Kryfo закритий.';

  @override
  String get onboardingSilentAndAtThe => 'Беззвучне, у самому низу шторки';

  @override
  String get onboardingItNeverBuzzesTurn =>
      'Воно ніколи не вібрує. Вимкнеш його - і повідомлення чекатимуть, доки ти знову не відкриєш застосунок.';

  @override
  String get onboardingGotIt => 'Ясно →';

  @override
  String get onboardingNow => 'Тепер *додай когось*.';

  @override
  String get onboardingTheAppIsReady =>
      'Застосунок готовий. Ніхто не може тобі написати, доки ти не додаси людину чи не впустиш її.';

  @override
  String get onboardingEveryWayToAdd => 'Усі способи додати когось';

  @override
  String get onboardingShowYourCodeSend =>
      'Покажи свій код, надішли посилання або введи @ім’я користувача, яке тобі дали.';

  @override
  String get onboardingScanTheirs => 'Відсканувати код';

  @override
  String get onboardingPointTheCameraAt => 'Наведи камеру на код';

  @override
  String get onboardingTheAppIsReadyWhenYou =>
      'Застосунок готовий - коли захочеш.';

  @override
  String get onboardingNotNowAddPeople => 'Не зараз · додам людей пізніше';

  @override
  String get openLockedOpened => 'Відкрито';

  @override
  String get openLockedOpenALockedFile => 'Відкрити замкнений файл';

  @override
  String get openLockedCheckingThePassword => 'Перевіряємо пароль';

  @override
  String get openLockedOpening => 'Відкриваємо';

  @override
  String get openLockedFile => 'Файл';

  @override
  String get openLockedOpenFile => 'Відкрити файл';

  @override
  String get openLockedTypeThePassword => 'Введи пароль.';

  @override
  String get openLockedItOpensOnThis => 'Він відкриється на цьому телефоні.';

  @override
  String get openLockedLockedFile => 'Замкнений файл';

  @override
  String openLockedFromFiles(Object prettySize) {
    return '$prettySize · з Файлів';
  }

  @override
  String get openLockedFromFiles2 => 'З Файлів';

  @override
  String get openLockedPassword => 'Пароль';

  @override
  String get openLockedThePasswordIsChecked =>
      'Спершу перевіряється пароль. Лише тоді Kryfo запитає, куди покласти відкритий файл, і він піде одразу туди.';

  @override
  String get openLockedOpened2 => 'Відкрито.';

  @override
  String get openLockedSavedWhereYouChose => 'Збережено у вибраному місці.';

  @override
  String get pairCodePairingCode => 'Код з’єднання';

  @override
  String get pairCodeShowACode => 'Показати код';

  @override
  String get pairCodeEnterOne => 'Ввести код';

  @override
  String get pairCodeSixDigits => 'Шість цифр';

  @override
  String get pairCodeLooking => 'Шукаємо…';

  @override
  String get pairCodeNothingThereYetTrying => 'Поки нічого · пробуємо ще раз';

  @override
  String get pairCodeNothingAtThatCode =>
      'За цим кодом нічого немає. Можливо, він уже зник або ним ще не поділилися.';

  @override
  String get pairCodeUnreached =>
      'Ретранслятори не відповіли. Спробуй трохи згодом.';

  @override
  String get pairCodeFailed => 'Не вийшло. Спробуй ще раз.';

  @override
  String get pairCodeTypeTheSixDigits =>
      'Введи шість цифр, які тобі продиктували.';

  @override
  String get pairCodeAddThem => 'Додати';

  @override
  String get pairCodeUsedTwice => 'Цей код використали двічі. Попроси новий.';

  @override
  String get pairCodeIsThisThem => 'Це та людина?';

  @override
  String get pairCodeCheckMatches => 'Звір з екраном співрозмовника';

  @override
  String get pairCodeNotThem => 'Не та людина';

  @override
  String get pairCodeNotAdded => 'Не додано. Попроси новий код.';

  @override
  String get panicSetupThoseWereDifferentFrom => 'Коди не збіглися. Спочатку.';

  @override
  String get panicSetupOnceMore => 'Ще раз';

  @override
  String get panicSetupTheSameFourDigits => 'Ті самі цифри ще раз';

  @override
  String get photoKnowsEverythingInside => 'Усе, що всередині';

  @override
  String get photoKnowsVideo => 'Відео';

  @override
  String get photoKnowsPhoto => 'Фото';

  @override
  String get photoKnowsWhatThisVideoKnows => 'Що знає це відео';

  @override
  String get photoKnowsWhatThisPhotoKnows => 'Що знає це фото';

  @override
  String get photoKnowsRemoveAllOfIt => 'Прибрати все';

  @override
  String get photoKnowsKeepItAsIt => 'Лишити як є';

  @override
  String get photoKnowsReadOnThisPhone =>
      'ПРОЧИТАНО НА ЦЬОМУ ТЕЛЕФОНІ · ВІДЕО НІКУДИ НЕ НАДСИЛАЛОСЯ';

  @override
  String get photoKnowsReadOnThisPhoneThePhoto =>
      'ПРОЧИТАНО НА ЦЬОМУ ТЕЛЕФОНІ · ФОТО НІКУДИ НЕ НАДСИЛАЛОСЯ';

  @override
  String get photoKnowsReadingTheFile => 'Читаємо файл';

  @override
  String photoKnowsOf(Object prettySize, Object prettySize2) {
    return '$prettySize з $prettySize2';
  }

  @override
  String get photoKnowsEverythingStaysOnThis =>
      'Усе залишається на цьому телефоні.';

  @override
  String photoKnowsMapWithAPin(Object place) {
    return 'Мапа з позначкою. $place';
  }

  @override
  String get photoKnowsDrawnOffline => 'НАМАЛЬОВАНО ОФЛАЙН';

  @override
  String photoKnowsShowEverything(Object title) {
    return '$title. Показати все';
  }

  @override
  String get pinsAppLock => 'Блокування Kryfo';

  @override
  String get pinsYourPin => 'Твій PIN-код';

  @override
  String get commonOn => 'Увімкнено';

  @override
  String get commonOff => 'Вимкнено';

  @override
  String get pinsOpensKryfoFourDigits =>
      'Відкриває Kryfo. Kryfo просить його щоразу, коли виходить на передній план.';

  @override
  String get pinsChangePin => 'Змінити PIN-код';

  @override
  String get pinsSetAPin => 'Задати PIN-код';

  @override
  String get pinsTurnOff => 'Вимкнути';

  @override
  String get pinsTurnOffTheApp => 'Вимкнути блокування Kryfo?';

  @override
  String get pinsThePinGoesAnd =>
      'PIN-код зникне, а разом із ним і PIN для стирання та всі приховані чати. Будь-хто з твоїм телефоном у руках відкриє Kryfo від твого імені.';

  @override
  String get pinsUnlockWithFingerprint => 'Розблокування відбитком';

  @override
  String get pinsWipePin => 'PIN для стирання';

  @override
  String get pinsNeedsAPinFirst => 'Спершу потрібен PIN-код';

  @override
  String get pinsSet => 'Задано';

  @override
  String get pinsChangeWipePin => 'Змінити PIN для стирання';

  @override
  String get pinsSetAWipePin => 'Задати PIN для стирання';

  @override
  String get pinsRemove => 'Прибрати';

  @override
  String get pinsRemoveTheWipePin => 'Прибрати PIN для стирання?';

  @override
  String get pinsTheLockScreenKeeps =>
      'Екран блокування залишає твій PIN-код. PIN для стирання більше нічого не робитиме.';

  @override
  String profileCopied(Object what) {
    return '$what: скопійовано';
  }

  @override
  String get profileProfile => 'Профіль';

  @override
  String get profileChangeYourFace => 'Змінити обличчя';

  @override
  String get profileKryfoId => 'Kryfo ID';

  @override
  String get profileOnionAddress => 'Onion-адреса';

  @override
  String get profileSupporterBadge => 'Значок прихильника';

  @override
  String profileYouAreAThank(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter': 'У тебе статус прихильника. Дякуємо.',
      'patron': 'У тебе статус мецената. Дякуємо.',
      'guardian': 'У тебе статус хранителя. Дякуємо.',
      'other': 'У тебе статус прихильника. Дякуємо.',
    });
    return '$_temp0';
  }

  @override
  String get profileShowMyBadge => 'Показувати мій значок';

  @override
  String get profileOnMyOwnScreens => 'На моїх екранах';

  @override
  String get profileLetContactsSeeIt => 'Показувати контактам';

  @override
  String get profileOffByDefault => 'Типово вимкнено';

  @override
  String get profileShareConnect => 'Обмін і зв’язок';

  @override
  String get profileMyKryfoCode => 'Мій код Kryfo';

  @override
  String get profileAddContact => 'Додати контакт';

  @override
  String get profileGiveAgain => 'Підтримати ще раз';

  @override
  String get profileSupportKryfo => 'Підтримати Kryfo';

  @override
  String get profileKryfoRunsOnWhat => 'Kryfo живе на внески людей';

  @override
  String get profileKeepKryfoIndependent => 'Збережи Kryfo незалежним';

  @override
  String get qrLink => 'Посилання';

  @override
  String get qrYourLinkAsTyped =>
      'ПОСИЛАННЯ ЯК Є · ЖОДНИХ ПЕРЕНАПРАВЛЕНЬ ДЛЯ СТЕЖЕННЯ';

  @override
  String get qrText => 'Текст';

  @override
  String get qrStaysInTheCode =>
      'ЛИШАЄТЬСЯ В КОДІ · ЖОДЕН СЕРВЕР ЙОГО НЕ ЗБЕРІГАЄ';

  @override
  String get qrWiFi => 'Wi-Fi';

  @override
  String get qrMadeOnThisPhone =>
      'СТВОРЕНО НА ЦЬОМУ ТЕЛЕФОНІ · ЖОДЕН САЙТ НЕ БАЧИВ ПАРОЛЯ';

  @override
  String get qrNetworkName => 'Назва мережі';

  @override
  String get qrPassword => 'Пароль';

  @override
  String get qrContact => 'Контакт';

  @override
  String get qrOnlyWhatYouType =>
      'ЛИШЕ ТЕ, ЩО ТИ ВВЕДЕШ · НІЧОГО З ТВОЇХ КОНТАКТІВ';

  @override
  String get qrName => 'Ім’я';

  @override
  String get qrPhone => 'Телефон';

  @override
  String get qrEmail => 'Ел. пошта';

  @override
  String get qrOpensTheirMailApp =>
      'ВІДКРИВАЄ ПОШТУ ТОГО, ХТО СКАНУЄ · ЗВІДСИ НІЧОГО НЕ НАДСИЛАЄТЬСЯ';

  @override
  String get qrTo => 'Кому';

  @override
  String get qrSubject => 'Тема';

  @override
  String get qrANumberNothingElse => 'НОМЕР · БІЛЬШЕ НІЧОГО';

  @override
  String get qrNumber => 'Номер';

  @override
  String get qrSms => 'SMS';

  @override
  String get qrOpensTheirMessagesApp =>
      'ВІДКРИВАЄ ПОВІДОМЛЕННЯ ТОГО, ХТО СКАНУЄ · ЗВІДСИ НІЧОГО НЕ НАДСИЛАЄТЬСЯ';

  @override
  String get qrMessage => 'Повідомлення';

  @override
  String get qrLocation => 'Місцезнаходження';

  @override
  String get qrCoordinatesOnlyNoMap =>
      'ЛИШЕ КООРДИНАТИ · БЕЗ ЗАПИТІВ ДО СЕРВІСІВ МАП';

  @override
  String get qrLatitude => 'Широта';

  @override
  String get qrLongitude => 'Довгота';

  @override
  String get qrBitcoin => 'Bitcoin';

  @override
  String get qrAddressAndAmountNo =>
      'АДРЕСА Й СУМА · БЕЗ ПЛАТІЖНИХ САЙТІВ ПОСЕРЕДИНІ';

  @override
  String get qrAddress => 'Адреса';

  @override
  String get qrAmountInBtc => 'Сума в BTC';

  @override
  String get qrInk => 'Чорнило';

  @override
  String get qrAmber => 'Бурштин';

  @override
  String get qrViolet => 'Фіалка';

  @override
  String get qrCouldNotDrawThe => 'Не вдалося намалювати зображення.';

  @override
  String get qrSavedToYourGallery => 'Збережено в галерею';

  @override
  String get qrCouldNotSaveIt =>
      'Не вдалося зберегти. Перевір, чи є місце на телефоні.';

  @override
  String get qrNoAppOnThis =>
      'Жоден застосунок на цьому телефоні не прийняв зображення.';

  @override
  String get qrTooMuchForOne => 'Забагато для одного коду. Скороти.';

  @override
  String get qrThisIsALot =>
      'Це багато для одного коду. Старі камери можуть його не прочитати.';

  @override
  String get qrPrivateQrCode => 'Приватний QR-код';

  @override
  String get qrColour => 'Колір';

  @override
  String get qrCopiedItLeavesThe =>
      'Скопійовано. Через хвилину зникне з буфера';

  @override
  String get qrSecurity => 'Захист';

  @override
  String get qrNone => 'Немає';

  @override
  String get qrSaveImage => 'Зберегти картинку';

  @override
  String qrColour2(Object name) {
    return 'Колір: $name';
  }

  @override
  String get qrTypeBelowAndThe => 'Введи текст нижче,\nі код намалюється сам';

  @override
  String get qrQrCode => 'QR-код';

  @override
  String get qrHidePassword => 'Сховати пароль';

  @override
  String get qrShowPassword => 'Показати пароль';

  @override
  String get qrCopyPassword => 'Копіювати пароль';

  @override
  String get requestsSentAnAttachment => 'Надіслано вкладення';

  @override
  String get requestsWantsToConnect => 'Хоче зв’язатися';

  @override
  String get requestsAccepted => 'Прийнято';

  @override
  String requestsBlock(Object id) {
    return 'Заблокувати $id?';
  }

  @override
  String get requestsNothingMoreFromThem =>
      'Від цієї людини до тебе більше нічого не дійде. Її запит і повідомлення зникнуть.';

  @override
  String get requestsBlocked => 'Заблоковано';

  @override
  String get requestsDeleted => 'Видалено';

  @override
  String get requestsRequests => 'Запити';

  @override
  String get requestsNoRequests => 'Немає запитів';

  @override
  String get requestsMessagesFromPeopleYou =>
      'Повідомлення від людей не з твоїх контактів спершу з’являються тут.';

  @override
  String get requestsLooksSafeNothingSuspicious =>
      'Схоже, безпечно · у першому повідомленні нічого підозрілого';

  @override
  String get commonAccept => 'Прийняти';

  @override
  String get requestsDecline => 'Відхилити';

  @override
  String get restoreThatFileIsNot => 'Цей файл не є резервною копією Kryfo';

  @override
  String get restoreThisFileIsDamaged =>
      'Цей файл пошкоджений, і його неможливо прочитати';

  @override
  String get restoreTypeThePassphraseThe =>
      'Введи парольну фразу, з якою створено файл';

  @override
  String get restoreReplaceTheAccountOn =>
      'Замінити обліковий запис на цьому телефоні?';

  @override
  String get restoreWhatIsHereNow =>
      'Те, що тут є зараз, - ідентичність, контакти й повідомлення - зникне. Його місце займе файл. Цю дію не можна скасувати.';

  @override
  String get restoreReplaceIt => 'Замінити';

  @override
  String restoreCouldNotBeReleased(Object mine) {
    return 'Не вдалося звільнити @$mine';
  }

  @override
  String restoreTheRegistryDidNot(Object mine) {
    return 'Реєстр не відповів. Якщо продовжиш, @$mine і далі вказуватиме на ідентичність, яку цей телефон ось-ось утратить. Хто додасть це ім’я, писатиме нікому, а саме ім’я вже не можна буде зайняти знову. Краще вийди в мережу і спробуй ще раз.';
  }

  @override
  String get restoreRestoreAnyway => 'Усе одно відновити';

  @override
  String get restoreNotYet => 'Ще ні';

  @override
  String get restoreRestored => 'Відновлено';

  @override
  String restoreKryfoWillCloseNow(Object haloId) {
    return 'Kryfo зараз закриється. Натисни іконку, щоб знову відкрити його як $haloId.';
  }

  @override
  String get restoreReopenKryfo => 'Відкрити Kryfo знову';

  @override
  String get restoreTheRestoreDidNot =>
      'Відновлення не завершилося. Нічого не змінено';

  @override
  String get restoreThisIdentity => 'ідентичність із файлу';

  @override
  String get restoreMoveYourKryfoHere => 'Перенести Kryfo сюди';

  @override
  String restoreThisBackupIsRestoring(Object name) {
    return 'Резервна копія: $name. Відновлення перенесе цю ідентичність на цей пристрій.';
  }

  @override
  String restoreThisBackupMadeOn(Object name, Object date, Object time) {
    return 'Резервна копія: $name, створена $date о $time. Відновлення перенесе цю ідентичність на цей пристрій.';
  }

  @override
  String restoreItHoldsOfPhotos(Object mb) {
    return 'У ній $mb фото, голосових і файлів. Це може тривати кілька хвилин. Не закривай застосунок.';
  }

  @override
  String get restoreWhatFollows => 'Що перенесеться';

  @override
  String get restoreYourNameYourCode => 'Твоє ім’я, твій код і всі контакти.';

  @override
  String get restoreEveryConversationBackTo =>
      'Усі розмови, від самого початку.';

  @override
  String get restoreYourPhotosVoiceNotes => 'Твої фото, голосові та файли.';

  @override
  String restoreYourPhotosVoiceNotesCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Твої фото, голосові та файли · $countString.',
    );
    return '$_temp0';
  }

  @override
  String get restoreYourOnionAddressSo =>
      'Твоя onion-адреса, щоб ті, хто зв’язується з тобою напряму, і далі могли до тебе достукатися.';

  @override
  String get restoreAnythingSentToYou =>
      'Усе, що тобі надіслали, поки старий телефон був вимкнений, - протягом чотирнадцяти днів після надсилання.';

  @override
  String get restoreYourSupporterBadgeIf =>
      'Твій значок прихильника, якщо він є.';

  @override
  String get restoreWhatDoesnT => 'Що не перенесеться';

  @override
  String get restoreTheOldPhoneStops =>
      'Старий телефон перестає отримувати повідомлення, щойно ти щось надішлеш звідси. Не поступово. Перше повідомлення, яке ти надішлеш з цього пристрою, - останнє, яке старий телефон ще зможе розібрати, а все, що дійде до нього після цього, там не прочитати, і тут воно на тебе теж не чекатиме.';

  @override
  String get restoreIfThePhoneThis =>
      'Якщо телефон, з якого цей файл, ще використовується, перестань користуватися на ньому Kryfo, перш ніж продовжити. Два телефони на одному Kryfo гублять повідомлення на обох.';

  @override
  String get restoreNotificationsNeedSettingUp =>
      'Сповіщення на цьому пристрої треба налаштувати заново.';

  @override
  String get restoreMoveItHere => 'Перенести сюди';

  @override
  String get restoreNotNow => 'Не зараз';

  @override
  String get restoreRestore => 'Відновити';

  @override
  String get restoreFromABackupFile => 'З резервної копії';

  @override
  String get restoreABackupBringsBack =>
      'Резервна копія повертає твою ідентичність, контакти й повідомлення, які були на телефоні, коли створювали файл. Усього, що було сказано після цього, у ній немає.';

  @override
  String get restoreTheFile => 'Файл';

  @override
  String get restorePickTheBackupFile => 'Вибрати файл копії';

  @override
  String get restoreThePassphrase => 'Парольна фраза';

  @override
  String get restoreTheOneTheFile => 'Та, з якою створено файл';

  @override
  String get restoreWhatComesBack => 'Що повернеться';

  @override
  String get restoreChecking => 'Перевіряємо…';

  @override
  String get restoreCheckTheFile => 'Перевірити файл';

  @override
  String get restoreReleasingYourHandle => 'Звільняємо ім’я користувача…';

  @override
  String restoreMoving(Object progress) {
    return 'Переносимо… $progress';
  }

  @override
  String get restoreRestoring => 'Відновлюємо…';

  @override
  String get restoreNotThisOne => 'Не цей';

  @override
  String get restoreDateUnknown => 'Дата невідома';

  @override
  String get restoreAnIdentity => 'Ідентичність';

  @override
  String get restoreMessagesSentOrReceived =>
      'Повідомлень, надісланих чи отриманих після цієї дати, у файлі немає.';

  @override
  String restoreGb(Object bytes) {
    return '$bytes ГБ';
  }

  @override
  String restoreMb(Object bytes) {
    return '$bytes МБ';
  }

  @override
  String get roomCreateCouldNotCreateThe => 'Не вдалося створити кімнату';

  @override
  String get roomCreateBurnerRoom => 'Одноразова кімната';

  @override
  String get roomCreateARoomThatEnds =>
      'Кімната, яка закінчується. Кожен заходить під ключем, створеним саме для неї, а коли вона закінчиться, ні на жодному телефоні нічого не лишиться.';

  @override
  String get roomCreateRoomName => 'Назва кімнати';

  @override
  String get roomCreateEndsAfter => 'Закінчиться через';

  @override
  String get roomCreateMemberCap => 'Ліміт учасників';

  @override
  String roomCreateNoOnePastThe(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Не більше $countString учасника',
      many: 'Не більше $countString учасників',
      few: 'Не більше $countString учасників',
      one: 'Не більше $countString учасника',
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
      other: 'Вимкнено. Будь-хто з посиланням, максимум $countString',
    );
    return '$_temp0';
  }

  @override
  String roomCreateThisRoomAndEverything(Object expiryWords) {
    return 'Ця кімната і все, що в ній, зникне $expiryWords';
  }

  @override
  String get roomCreateCreating => 'Створення...';

  @override
  String get roomCreateCreateRoom => 'Створити кімнату';

  @override
  String get roomLinkSendTheRoomTo => 'Кому надіслати кімнату';

  @override
  String get roomLinkTheyWillKnowThis =>
      'Отримувач знатиме, що кімната від тебе. Усередині він - такий самий ключ, як усі інші.';

  @override
  String get roomLinkNoContactsYet => 'Ще немає контактів';

  @override
  String roomLinkEndsIn(Object time) {
    return 'Кінець через $time';
  }

  @override
  String get roomLinkAnyoneWithThisCan =>
      'Будь-хто з цим посиланням може приєднатися, доки кімната не закінчиться. Люди заходять під ключем, створеним для цієї кімнати, і не бачать нічого, що було надіслано до їхнього приходу.';

  @override
  String get roomLinkRoomLinkCopied => 'Посилання скопійовано';

  @override
  String get roomLinkSendToAContact => 'Надіслати контакту';

  @override
  String get roomLinkCopyRoomLink => 'Копіювати посилання';

  @override
  String get savedVoiceNote => 'Голосове';

  @override
  String get savedPhoto => 'Фото';

  @override
  String get savedSaved => 'Збережені';

  @override
  String get savedNothingSavedYet => 'Ще нічого не збережено';

  @override
  String get savedChatGone => 'Цього чату більше немає на цьому телефоні';

  @override
  String get savedLongPressAnyMessage =>
      'Затисни будь-яке повідомлення й натисни «Зберегти», щоб воно було тут.';

  @override
  String get savedViewInChat => 'Показати в чаті';

  @override
  String get savedPhoto2 => 'Фото';

  @override
  String get scanThatSNotA => 'Це не QR Kryfo · наводь далі';

  @override
  String get scanScanAKryfoQr => 'Сканувати QR Kryfo';

  @override
  String get scanFlash => 'Спалах';

  @override
  String get scanPointAtAKryfo =>
      'Наведи на QR Kryfo · ніщо не залишає твій телефон';

  @override
  String get seenWhatWeCanSee => 'Що ми можемо бачити';

  @override
  String get seenEveryMessengerClaimsPrivacy =>
      'Кожен месенджер обіцяє приватність. Ось конкретний список, за маршрутами, зокрема й те, що нас не прикрашає. Натисни рядок, щоб дізнатися чому.';

  @override
  String get seenHonestAboutTheLast =>
      'Чесно про останні рядки: саме для цього є блокування Kryfo, PIN для стирання та зашифроване сховище, і жоден інструмент не врятує від того, хто тримає в руках твій розблокований телефон. Повна модель загроз - у THREAT_MODEL.md у репозиторії, складена за LINDDUN. Код відкритий, тож нічого з цього не треба приймати на віру.';

  @override
  String get seenHidden => 'Приховано';

  @override
  String get seenNever => 'Ніколи';

  @override
  String get seenOnDevice => 'На пристрої';

  @override
  String get seenYours => 'Твій ризик';

  @override
  String get seenUnaudited => 'Без аудиту';

  @override
  String get seenWhoYouTalkTo => 'З ким ти говориш';

  @override
  String get seenEachConversationGetsIts =>
      'Кожна розмова має власну адресу, виведену з обох ключів. Ретранслятор бачить не пов’язані між собою схованки, а не пару людей.';

  @override
  String get seenWhatYouSay => 'Що ти кажеш';

  @override
  String get seenEndToEndEncrypted =>
      'Наскрізно зашифровано алгоритмом double ratchet від Signal, а потім ще раз запечатано в «подарункову обгортку» (gift wrap). Ми не змогли б це прочитати, навіть якби спробували.';

  @override
  String get seenYourIpAddress => 'Твоя IP-адреса';

  @override
  String get seenOurRelay => 'Наш ретран-слятор';

  @override
  String get seenEveryRelay => 'Усі ретран-слятори';

  @override
  String get seenOnOnionEverythingLeaves =>
      'В Onion усе виходить через tor, і ретранслятор бачить вихідний вузол, ніколи не тебе. У режимі ретранслятора з’єднання йде прямо на наш власний ретранслятор: ніщо не пересилає твою адресу далі й ніщо не записується, але саме це з’єднання бачимо ми. У швидкому режимі кожен публічний ретранслятор дізнається про твоє підключення, але не те, з ким ти говориш і що кажеш.';

  @override
  String get seenYourContactGraph => 'Твій граф контактів';

  @override
  String get seenKryfoDoesNotScan =>
      'Kryfo не сканує твої контакти. У цьому й суть. Тут немає номера телефону, який міг би витекти.';

  @override
  String get seenIntroducer => 'Посередник';

  @override
  String get seenWhenAContactIntroduces =>
      'Коли контакт знайомить тебе з кимось, він дізнається, що ви тепер на зв’язку. Більше ніхто. Ретранслятор бачить шифротекст, і жоден сервер ніколи не бачить графа.';

  @override
  String get seenTheScamShield => 'Захист від шахраїв';

  @override
  String get seenRunsOnYourPhone =>
      'Працює на твоєму телефоні за правилами, вбудованими в застосунок. Без мережі, без завантаження списків. Він читає лише перше повідомлення від незнайомця і не може бачити нічого, що тобі надсилає контакт.';

  @override
  String get seenBurnerRooms => 'Одноразові кімнати';

  @override
  String get seenRoomKeys => 'Ключі кімнати';

  @override
  String get seenYouJoinARoom =>
      'Ти заходиш у кімнату під ключем, створеним для неї, тож люди всередині не дізнаються нічого, що працювало б деінде. Ті, хто приєднався пізніше, не отримують історії. Коли час спливає, ключі, повідомлення й медіа знищуються.';

  @override
  String get seenLinkPreviews => 'Прев’ю посилань';

  @override
  String get seenOverTor => 'Через Tor';

  @override
  String get seenAPreviewIsFetched =>
      'Прев’ю завантажує відправник, через tor, і воно їде всередині зашифрованого повідомлення. Телефон отримувача не робить жодного запиту. Сайт дізнається лише, що хтось через tor запросив сторінку, і більше нічого. Жодне зображення ніколи не завантажується, а посилання від незнайомця лишається звичайним текстом.';

  @override
  String get seenASeizedUnlockedPhone => 'Вилучений розблокований телефон';

  @override
  String get seenIfSomeoneHoldsYour =>
      'Якщо хтось тримає твій телефон розблокованим, він читає твої повідомлення. Блокування Kryfo, PIN для стирання і зашифроване сховище допомагають до цього моменту, а не після.';

  @override
  String get seenTheCryptoItself => 'Сама криптографія';

  @override
  String get seenTheRatchetAndStorage =>
      'Шар ratchet-шифрування і шар сховища стандартні. Шар, що їх поєднує, - наш, і ніхто незалежний його не перевіряв. Вважай це альфа-версією, бо так воно і є.';

  @override
  String get seenOnion => 'Onion';

  @override
  String get seenRelay => 'Ретрансл.';

  @override
  String get seenFast => 'Швидкий';

  @override
  String get settingsWipeKryfo => 'Стерти Kryfo?';

  @override
  String get settingsIdentityMessagesContactsAnd =>
      'Ідентичність, повідомлення, контакти й налаштування на цьому телефоні. Зникнуть назавжди, якщо в тебе немає резервної копії.';

  @override
  String get commonContinue => 'Продовжити';

  @override
  String settingsTypeWipeToConfirm(Object word) {
    return 'Введи «$word», щоб підтвердити';
  }

  @override
  String get settingsTheLastStepNothing =>
      'Останній крок. Після нього нічого не лишиться.';

  @override
  String get settingsWipeWord => 'стерти';

  @override
  String get settingsWipeKryfo2 => 'Стерти Kryfo';

  @override
  String get settingsYourProtections => 'Твій захист';

  @override
  String get settingsTorRouting => 'Маршрутизація tor';

  @override
  String get settingsConnecting => 'Підключення';

  @override
  String get settingsOffMode => 'Вимкнено · ретранслятор';

  @override
  String get settingsOffFastMode => 'Вимкнено · швидкий режим';

  @override
  String get settingsAppLock => 'Блокування Kryfo';

  @override
  String get settingsBlockedByAndroid => 'Блокує Android';

  @override
  String get settingsSpeedPrivacy => 'Швидкість і приватність';

  @override
  String get settingsFast => 'Швидкий';

  @override
  String get settingsRelay1Hop => 'Ретранслятор · 1 вузол';

  @override
  String get settingsOnion3Hops => 'Onion · 3 вузли';

  @override
  String get settingsBridges => 'Мости';

  @override
  String get settingsForNetworksThatBlock => 'Для мереж, що блокують tor';

  @override
  String get settingsGettingMessages => 'Отримання повідомлень';

  @override
  String settingsPreviewHidden(Object deliveryModeName) {
    return '$deliveryModeName · текст приховано';
  }

  @override
  String settingsPreviewShown(Object deliveryModeName) {
    return '$deliveryModeName · текст видно';
  }

  @override
  String get settingsRunInBackground => 'Робота у фоні';

  @override
  String get settingsSoMessagesArrive => 'Щоб повідомлення приходили';

  @override
  String get settingsTransport => 'Транспорт';

  @override
  String get settingsWhatTheNetworkIs => 'Що відбувається з мережею';

  @override
  String get settingsBlocked => 'Заблоковані';

  @override
  String get settingsAcceptIntroductions => 'Приймати знайомства';

  @override
  String get settingsFriendsCanIntroduceYou =>
      'Друзі можуть знайомити тебе зі своїми';

  @override
  String get settingsScamShield => 'Захист від шахраїв';

  @override
  String get settingsChecksStrangersOnYour =>
      'Перевіряє незнайомців на твоєму телефоні. Нічого не залишає телефон';

  @override
  String get settingsBlockScreenshots => 'Блокувати знімки екрана';

  @override
  String get settingsWholeAppHiddenFrom =>
      'Увесь застосунок прихований у недавніх і на знімках екрана · діє після наступного запуску';

  @override
  String get settingsWholeAppHiddenFromRecentsAnd =>
      'Увесь застосунок прихований у недавніх і на знімках екрана';

  @override
  String get settingsOnNextStart => 'Увімкнеться при запуску';

  @override
  String get settingsOffNextStart => 'Вимкнеться при запуску';

  @override
  String get settingsLightTheme => 'Світла тема';

  @override
  String get settingsSameProtectionBrighter => 'Той самий захист, але світліше';

  @override
  String get settingsAppLock2 => 'Блокування Kryfo';

  @override
  String get settingsYourPinAndA => 'Твій PIN-код і додатковий захист';

  @override
  String get settingsPinWipePin => 'PIN · PIN для стирання';

  @override
  String get settingsBackUpIdentity => 'Копія ідентичності';

  @override
  String get settingsEncryptedFile => 'Зашифрований файл';

  @override
  String get settingsRestoreFromBackup => 'Відновити з копії';

  @override
  String get settingsReplaceCurrent => 'Замінює поточну';

  @override
  String get settingsDisguiseVoice => 'Змінити голос';

  @override
  String get settingsShiftsYourPitchBefore =>
      'Змінює висоту голосу, перш ніж голосове буде надіслано';

  @override
  String get settingsWhyKryfo => 'Чому Kryfo';

  @override
  String get settingsHowItProtectsYou => 'Як він тебе захищає';

  @override
  String get settingsResetMyInviteLink => 'Скинути моє посилання';

  @override
  String get settingsOldLinksAndCodes =>
      'Старі посилання й коди перестануть працювати для всіх';

  @override
  String get settingsResetInviteLink => 'Скинути посилання?';

  @override
  String get settingsAnyoneWithAnOld =>
      'Будь-хто зі старим кодом чи посиланням більше не зможе з тобою зв’язатися жодним маршрутом. Тим, у кого воно є, але хто ним ніколи не користувався, знадобиться від тебе нове. Контакти, чати й історія залишаються.';

  @override
  String get settingsReset => 'Скинути';

  @override
  String get settingsInviteResetShareThe =>
      'Запрошення скинуто · поділися новим кодом';

  @override
  String get settingsWhatWeCanSee => 'Що ми можемо бачити';

  @override
  String get settingsTheHonestList => 'Чесний список';

  @override
  String get settingsVersion => 'Версія';

  @override
  String get settings030Alpha => '0.5.0 · альфа';

  @override
  String get settingsReportAnIssue => 'Повідомити про проблему';

  @override
  String get settingsBugOrSecurityFlaw => 'Помилка чи вразливість';

  @override
  String get settingsOpenSource => 'Відкритий код';

  @override
  String get settingsLinkCopied => 'Посилання скопійовано';

  @override
  String get settingsTheOfflineMapIn =>
      'Офлайн-мапу в «Інструментах» намальовано за даними Natural Earth (суспільне надбання). Назви міст - з GeoNames, geonames.org, за ліцензією CC BY 4.0.';

  @override
  String get settingsNotIndependentlyAuditedPre =>
      'Незалежного аудиту не було. Альфа-версія — добре для тестування, але ще не для випадків, коли на кону багато.';

  @override
  String get settingsDangerZone => 'Небезпечна зона';

  @override
  String get settingsWipeKryfoFromThis => 'Стерти Kryfo з цього телефону';

  @override
  String get shieldCheckedOnThisPhone =>
      'Перевірено на цьому телефоні. Нічого нікуди не надсилалося.';

  @override
  String get toolsMoreTools => 'Ще інструменти';

  @override
  String get toolsCleanAPhotoOr => 'Очистити фото чи відео';

  @override
  String get toolsOrShareOneTo => 'Або поділися ним із Kryfo з галереї';

  @override
  String get toolsMakeAPrivateQr => 'Створити приватний QR-код';

  @override
  String get toolsLinksWiFiContacts =>
      'Посилання, Wi-Fi, контакти та інше. Створюється офлайн';

  @override
  String get toolsLockAFile => 'Замкнути файл';

  @override
  String get toolsWithAPasswordOpens =>
      'Паролем. Відкривається будь-де за допомогою age';

  @override
  String get toolsOpenALockedFile => 'Відкрити замкнений файл';

  @override
  String get toolsAnyAgeFileSomeone =>
      'Будь-який файл .age, який тобі надіслали';

  @override
  String get toolsWorksOfflineNoContacts =>
      'Працює офлайн · контакти не потрібні';

  @override
  String get toolsUsefulFrom => 'Корисні з';

  @override
  String get toolsTheFirstMinute => 'першої хвилини.';

  @override
  String get toolsEverythingHereHappensOn =>
      'Усе тут відбувається на цьому телефоні. Нічого не вивантажується, і нікому іншому не треба мати Kryfo.';

  @override
  String get toolsWhatDoesThisPhoto => 'Що знає це фото?';

  @override
  String get toolsPlacePhoneTime => 'Місце · телефон · час';

  @override
  String get toolsPickAPhotoAnd =>
      'Вибери фото й подивися, що воно видає. А тоді збережи чисту копію.';

  @override
  String get toolsPickAPhoto => 'Вибрати фото';

  @override
  String get toolsVideo => 'Відео';

  @override
  String get transportTransport => 'Транспорт';

  @override
  String get transportNothingHereLeavesThe =>
      'Ніщо звідси не залишає телефон. Це той самий стан, за яким рушій вирішує, що робити.';

  @override
  String get transportStayingAlive => 'Підтримка зв’язку';

  @override
  String get transportCanSend => 'Може надсилати';

  @override
  String get commonYes => 'Так';

  @override
  String get transportNotYet => 'Ще ні';

  @override
  String get transportOnline => 'Онлайн';

  @override
  String get transportOffline => 'Офлайн';

  @override
  String get transportQueuedToSend => 'У черзі на надсилання';

  @override
  String get transportOnionPublished => 'Onion опубліковано';

  @override
  String transportYes(Object uploads) {
    return 'Так ($uploads)';
  }

  @override
  String transportTryingS(Object pubFor) {
    return 'Спроба $pubFor с';
  }

  @override
  String transportBenchedS(Object r) {
    return 'На паузі $r с';
  }

  @override
  String transportFails(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString збою',
      many: '$countString збоїв',
      few: '$countString збої',
      one: '$countString збій',
    );
    return '$_temp0';
  }

  @override
  String get transportOk => 'ОК';

  @override
  String get transportRelaySubscriptions => 'Підписки на ретранслятори';

  @override
  String get transportLastSent => 'Надіслано';

  @override
  String get transportNever => 'Ніколи';

  @override
  String transportSAgo(Object sx) {
    return '$sx с тому';
  }

  @override
  String get transportLastReceived => 'Отримано';

  @override
  String transportSAgo2(Object rx) {
    return '$rx с тому';
  }

  @override
  String get transportWithNoContactsThe =>
      'Без контактів застосунок не підписується на жодну адресу ретранслятора, тож жодне повідомлення не може до тебе дійти. Відскануй когось, щоб це виправити.';

  @override
  String get transportSendAnythingWaitingNow => 'Надіслати все з черги зараз';

  @override
  String get transportSending => 'Надсилаємо…';

  @override
  String get transportNothingLeftWaiting => 'Більше нічого не чекає';

  @override
  String transportStillWaiting(Object count) {
    return 'Ще чекає: $count';
  }

  @override
  String get transportOff => 'Вимкнено';

  @override
  String get transportStarting => 'Запускається';

  @override
  String get transportBootstrapped => 'Запущено';

  @override
  String get transportPublishingAddress => 'Публікуємо адресу';

  @override
  String get transportReachable => 'Досяжний';

  @override
  String get transportOurRelayOnion => 'Наш ретранслятор (onion)';

  @override
  String get transportNever2 => 'ніколи';

  @override
  String get transportJustNow => 'Щойно';

  @override
  String transportMAgo(Object inMinutes) {
    return '$inMinutes хв тому';
  }

  @override
  String transportHAgo(Object inHours) {
    return '$inHours год тому';
  }

  @override
  String transportDAgo(Object inDays) {
    return '$inDays дн тому';
  }

  @override
  String transportM(Object inMinutes) {
    return '$inMinutes хв';
  }

  @override
  String transportHM(Object inHours, Object d) {
    return '$inHours год $d хв';
  }

  @override
  String transportD(Object inDays) {
    return '$inDays дн';
  }

  @override
  String transportMb(Object b) {
    return '$b МБ';
  }

  @override
  String get transportYesCheckedJustNow => 'Так · перевірено щойно';

  @override
  String transportNoLast(Object ago) {
    return 'Ні · востаннє $ago';
  }

  @override
  String get transportLastMessageIn => 'Останнє вхідне';

  @override
  String get transportBatteryExemption => 'Виняток для батареї';

  @override
  String get transportUnknown => 'Невідомо';

  @override
  String get transportExempt => 'Є виняток';

  @override
  String get transportNotExemptTapTo => 'Без винятку · виправити';

  @override
  String get transportProcessUp => 'Процес працює';

  @override
  String get transportLastStop => 'Остання зупинка';

  @override
  String transportEngine(Object mb, Object mb2) {
    return '$mb · рушій $mb2';
  }

  @override
  String get transportLastRelayArrival => 'Останнє від ретранслятора';

  @override
  String get transportLastCheckIn => 'Остання перевірка';

  @override
  String get transportNoneYet => 'Ще жодної';

  @override
  String get transportLastTorReconnect => 'Останнє перепідключення Tor';

  @override
  String get transportCatchUpByRelay => 'Наздоганяння';

  @override
  String get transportControlPort => 'Порт керування';

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
      other: '$dialsString спроби',
      many: '$dialsString спроб',
      few: '$dialsString спроби',
      one: '$dialsString спроба',
    );
    String _temp1 = intl.Intl.pluralLogic(
      timeouts,
      locale: localeName,
      other: '$timeoutsString тайм-ауту',
      many: '$timeoutsString тайм-аутів',
      few: '$timeoutsString тайм-аути',
      one: '$timeoutsString тайм-аут',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get transportJobRuns => 'Запуски завдання';

  @override
  String transportLast(Object jobRuns, Object ago) {
    return '$jobRuns · востаннє $ago';
  }

  @override
  String get transportQuietStretches => 'Періоди тиші';

  @override
  String get transportNone => 'Немає';

  @override
  String get transportClearThisRecord => 'Очистити цей запис';

  @override
  String get transportNothingYetThisProcess => 'Поки нічого в цьому процесі';

  @override
  String transportM2(Object mins) {
    return '$mins хв';
  }

  @override
  String transportHM2(Object mins, Object mins2) {
    return '$mins год $mins2 хв';
  }

  @override
  String transportTo(Object t, Object t2) {
    return 'з $t до $t2';
  }

  @override
  String vouchersVouchedBy(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString рекомендують',
      many: '$countString рекомендують',
      few: '$countString рекомендують',
      one: '$countString рекомендує',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperAtmosphere => 'Атмосфера';

  @override
  String get wallpaperJustForYouThey =>
      'Лише для тебе. Співрозмовник бачить свій.';

  @override
  String get wallpaperYourPhoto => 'Твоє фото';

  @override
  String get wallpaperFromYourPhotos => 'З твоїх фото';

  @override
  String get wallpaperKeepIt => 'Залишити';

  @override
  String get whyKryfoWhyKryfo => 'Чому Kryfo';

  @override
  String get whyKryfoKryfoKreeFoGreek =>
      'Kryfo · КРІ-фо · грецькою «прихований».\nТихе місце для розмов, створене так, щоб ніхто не стежив.';

  @override
  String get whyKryfoRoutedThroughTor => 'Маршрут через tor';

  @override
  String get whyKryfoByDefaultEveryMessage =>
      'За замовчуванням кожне повідомлення йде через tor - ланцюжок ретрансляторів. Ніхто, ні ми, ні твоя мережа, не може бачити, з ким ти говориш і де ти.';

  @override
  String get whyKryfoEndToEndEncrypted => 'Наскрізне шифрування';

  @override
  String get whyKryfoMessagesAreSealedWith =>
      'Повідомлення запечатані ключами, які є лише в тебе і в того, з ким ти говориш. Ми не змогли б їх прочитати, навіть якби спробували.';

  @override
  String get whyKryfoNoServersHoldingYour =>
      'Жодних серверів, що тримають твоє життя';

  @override
  String get whyKryfoNoAccountNoPhone =>
      'Без облікового запису, без номера телефону, без центрального сервера, що зберігає твої чати. Вони живуть на цьому телефоні, зашифровані у сховищі.';

  @override
  String get whyKryfoNothingLeaks => 'Нічого не витікає';

  @override
  String get whyKryfoNoReadReceiptsOr =>
      'Жодних звітів про прочитання чи індикаторів набору, які хтось отримує, жодного вивантаженого списку контактів. Метадані - це те, що витікає з більшості застосунків, а Kryfo створено так, щоб цього не було.';

  @override
  String get whyKryfoVerifyItIsReally => 'Перевір, що це справді та людина';

  @override
  String get whyKryfoCompareASafetyNumber =>
      'Звір номер безпеки особисто або каналом, якому довіряєш, щоб знати, що ніхто не видає себе за твій контакт.';

  @override
  String get whyKryfoTheHonestPart => 'Чесно кажучи';

  @override
  String get whyKryfoKryfoIsPreAlpha =>
      'Kryfo — альфа-версія, і аудиту ще не було. Криптографія справжня, але жоден сторонній експерт її ще не перевіряв, тож вважай це роботою в процесі, а не тим, чому вже можна довірити своє життя.';

  @override
  String get cleanerLocation => 'Місцезнаходження';

  @override
  String get cleanerAlreadyBlankedByAndroid => 'уже очищено самим Android';

  @override
  String get cleanerPhoneModel => 'Модель телефону';

  @override
  String get cleanerTimeTaken => 'Час зйомки';

  @override
  String get cleanerSerialNumber => 'Серійний номер';

  @override
  String get cleanerOwnerName => 'Ім’я власника';

  @override
  String get cleanerHiddenThumbnail => 'Прихована мініатюра';

  @override
  String get cleanerContentCredentials => 'Дані про походження';

  @override
  String get cleanerDataAfterThePicture => 'Дані після зображення';

  @override
  String cleaner1OtherField(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ще $countString поля',
      many: 'ще $countString полів',
      few: 'ще $countString поля',
      one: 'ще $countString поле',
    );
    return '$_temp0';
  }

  @override
  String get lockWordsFourRandomWordsBeat =>
      'Чотири випадкові слова кращі за одне хитре.';

  @override
  String lockWordsTooShortAtLeast(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Закороткий. Щонайменше $countString символу.',
      many: 'Закороткий. Щонайменше $countString символів.',
      few: 'Закороткий. Щонайменше $countString символи.',
      one: 'Закороткий. Щонайменше $countString символ.',
    );
    return '$_temp0';
  }

  @override
  String get lockWordsWeakWhoeverGetsThe =>
      'Слабкий. Той, хто отримає файл, може вгадувати так швидко, як захоче.';

  @override
  String get lockWordsFairLongerIsStronger => 'Непоганий. Довший - надійніший.';

  @override
  String get lockWordsStrongFourRandomWords =>
      'Надійний. Чотири випадкові слова кращі за одне хитре.';

  @override
  String photoStoryKm(Object m) {
    return '$m км';
  }

  @override
  String photoStory1Metre(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString метра',
      many: '$countString метрів',
      few: '$countString метрів',
      one: '$countString метра',
    );
    return '$_temp0';
  }

  @override
  String get photoStoryFarFromAnyTown => 'Далеко від будь-якого міста';

  @override
  String photoStoryNear(Object where) {
    return 'Поблизу $where';
  }

  @override
  String photoStoryAboutKmFrom(Object near, Object where) {
    return 'Приблизно $near км від $where';
  }

  @override
  String photoStoryS(Object s) {
    return '$s с';
  }

  @override
  String photoStory1S(Object s) {
    return '1/$s с';
  }

  @override
  String get photoStoryNotAKindKryfo =>
      'Kryfo не вміє читати файли такого типу.';

  @override
  String get photoStorySoItWillNot => 'Тож вгадувати не буде.';

  @override
  String get photoStoryThisFileIsDamaged =>
      'Цей файл пошкоджений або обрізаний.';

  @override
  String get photoStoryKryfoCouldNotRead =>
      'Kryfo не зміг дочитати його до кінця.';

  @override
  String get photoStoryWhereItWasRecorded => 'Де записано';

  @override
  String get photoStoryWhereItWasTaken => 'Де знято';

  @override
  String photoStoryLocation(Object coordsLine) {
    return 'Місцезнаходження: $coordsLine';
  }

  @override
  String photoStoryHeightAboveTheSea(Object fix) {
    return 'Висота над рівнем моря: $fix м';
  }

  @override
  String get photoStoryLocationHiddenByAndroid =>
      'Місцезнаходження приховав Android';

  @override
  String get photoStoryAndroidBlanksItWhen =>
      'Android очищає його, коли фото вибирають у такий спосіб. Якщо поділитися ним із Kryfo з галереї, воно часто зберігається. У фото в галереї воно може досі бути.';

  @override
  String get photoStoryLocationBlankedByAndroid =>
      'Місцезнаходження: Android очистив його ще до Kryfo';

  @override
  String photoStoryF(Object r) {
    return 'f/$r';
  }

  @override
  String get photoStoryWhatTookIt => 'Чим знято';

  @override
  String photoStoryPhoneOrCamera(Object phone) {
    return 'Телефон чи камера: $phone';
  }

  @override
  String get photoStoryWhenItWasRecorded => 'Коли записано';

  @override
  String get photoStoryToTheSecondWith => 'До секунди, з часовим поясом';

  @override
  String get photoStoryToTheSecond => 'До секунди';

  @override
  String photoStoryTime(Object dateFormat) {
    return 'Час: $dateFormat';
  }

  @override
  String get photoStoryLens => 'Об’єктив';

  @override
  String photoStoryLens2(Object lens) {
    return 'Об’єктив: $lens';
  }

  @override
  String get photoStorySoftware => 'Програма';

  @override
  String photoStorySoftware2(Object software) {
    return 'Програма: $software';
  }

  @override
  String get photoStorySerialNumber => 'Серійний номер';

  @override
  String photoStorySerialNumber2(Object serial) {
    return 'Серійний номер: $serial';
  }

  @override
  String get photoStoryOwnerName => 'Ім’я власника';

  @override
  String photoStoryOwner(Object r) {
    return 'Власник: $r';
  }

  @override
  String get photoStoryHiddenThumbnail => 'Прихована мініатюра';

  @override
  String get photoStoryASmallCopyOf =>
      'Маленька копія зображення всередині файлу. Вона може показати те, що прибрало кадрування';

  @override
  String get photoStoryMakerNotes => 'Нотатки виробника';

  @override
  String get photoStoryMakerNotesABlock =>
      'Нотатки виробника: блок, який може прочитати лише виробник';

  @override
  String get photoStoryEditingHistory => 'Історія редагування';

  @override
  String get photoStoryXmpEditingHistoryAnd =>
      'XMP: історія редагування й теги';

  @override
  String get photoStoryCaptions => 'Підписи';

  @override
  String get photoStoryIptcCaptionsAndCredits => 'IPTC: підписи й авторство';

  @override
  String get photoStoryComment => 'Коментар';

  @override
  String get photoStoryAWrittenComment => 'Текстовий коментар';

  @override
  String get photoStoryContentCredentials => 'Дані про походження';

  @override
  String get photoStorySecondPicture => 'Друге зображення';

  @override
  String get photoStoryASecondPictureInside =>
      'Друге зображення всередині файлу';

  @override
  String get photoStoryMotionVideo => 'Відео руху';

  @override
  String get photoStoryAShortVideoInside => 'Коротке відео всередині файлу';

  @override
  String get photoStorySaveTime => 'Час збереження';

  @override
  String get photoStoryTheTimeItWas => 'Коли його востаннє зберігали';

  @override
  String get photoStoryTimeStamps => 'Мітки часу';

  @override
  String get photoStoryCreationTimeStamps => 'Мітки часу створення';

  @override
  String get photoStoryDataAfterThePicture => 'Дані після зображення';

  @override
  String photoStoryDataAfterTheEnd(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Дані після кінця зображення: $countString байта',
      many: 'Дані після кінця зображення: $countString байтів',
      few: 'Дані після кінця зображення: $countString байти',
      one: 'Дані після кінця зображення: $countString байт',
    );
    return '$_temp0';
  }

  @override
  String photoStoryTextField(Object k) {
    return 'Текстове поле: $k';
  }

  @override
  String photoStoryVideoTag(Object k) {
    return 'Тег відео: $k';
  }

  @override
  String photoStoryAlso(Object k) {
    return 'Також: $k';
  }

  @override
  String photoStoryCameraSettingsFlashFocus(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString налаштування камери (спалах, фокус, експозиція)',
      many: '$countString налаштувань камери (спалах, фокус, експозиція)',
      few: '$countString налаштування камери (спалах, фокус, експозиція)',
      one: '$countString налаштування камери (спалах, фокус, експозиція)',
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
      other: 'ще $countString поля',
      many: 'ще $countString полів',
      few: 'ще $countString поля',
      one: 'ще $countString поле',
    );
    return '$_temp0';
  }

  @override
  String get photoStoryCameraSettings => 'Налаштування камери';

  @override
  String photoStoryAccurateToAbout(Object metres) {
    return 'З точністю приблизно до $metres.';
  }

  @override
  String get photoStoryEnoughToFindThe => 'Досить, щоб знайти двері.';

  @override
  String get photoStoryEnoughToFindTheStreet => 'Досить, щоб знайти вулицю.';

  @override
  String get photoStoryEnoughToFindTheArea => 'Досить, щоб знайти район.';

  @override
  String get photoStoryItKnowsWhereYou => 'Воно знає, де це знято.';

  @override
  String get photoStoryDownToTheBuilding => 'Аж до будинку.';

  @override
  String get photoStoryAndroidHidTheLocation =>
      'Android приховав місцезнаходження.';

  @override
  String get photoStoryTheOriginalMayStill => 'В оригіналі воно ще може бути.';

  @override
  String get photoStoryNoLocationInThis => 'Тут немає місцезнаходження.';

  @override
  String get photoStoryItStillSaysPlenty => 'Та все одно каже чимало.';

  @override
  String get photoStoryThisOneKnowsNothing => 'Це фото нічого не знає.';

  @override
  String get photoStoryNothingToRemove => 'Нічого прибирати.';

  @override
  String get qrPayloadOpensALink => 'ВІДКРИВАЄ ПОСИЛАННЯ';

  @override
  String qrPayloadOpens(Object host) {
    return 'ВІДКРИВАЄ $host';
  }

  @override
  String get qrPayloadShowsANote => 'ПОКАЗУЄ НОТАТКУ';

  @override
  String get qrPayloadScanToJoin => 'СКАНУЙ І ПІДКЛЮЧАЙСЯ';

  @override
  String qrPayloadScanToJoin2(Object oneLine) {
    return 'СКАНУЙ І ПІДКЛЮЧАЙСЯ · $oneLine';
  }

  @override
  String get qrPayloadANetworkNameIs =>
      'Назва мережі - щонайбільше 32 символи.';

  @override
  String get qrPayloadAWiFiPassword =>
      'Пароль Wi-Fi має щонайменше 8 символів.';

  @override
  String get qrPayloadSavesAContact => 'ЗБЕРІГАЄ КОНТАКТ';

  @override
  String get qrPayloadWritesAnEmail => 'ПИШЕ ЛИСТ';

  @override
  String get qrPayloadThatDoesNotLook => 'Це не схоже на адресу ел. пошти.';

  @override
  String get qrPayloadCallsANumber => 'ТЕЛЕФОНУЄ НА НОМЕР';

  @override
  String get qrPayloadWritesAText => 'ПИШЕ SMS';

  @override
  String get qrPayloadOpensAMap => 'ВІДКРИВАЄ МАПУ';

  @override
  String get qrPayloadLatitudeRunsFrom90 =>
      'Широта - від -90 до 90, довгота - від -180 до 180.';

  @override
  String get qrPayloadPayThisAddress => 'ОПЛАТА НА ЦЮ АДРЕСУ';

  @override
  String get qrPayloadABitcoinAddressIs =>
      'Адреса bitcoin містить лише літери й цифри.';

  @override
  String get qrPayloadTheAmountIsIn => 'Сума - в BTC, до 8 знаків після коми.';

  @override
  String vouchTextAnd(Object names, Object names2) {
    return '$names і $names2';
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
      other: '$restString твого знайомого',
      many: '$restString твоїх знайомих',
      few: '$restString твої знайомі',
      one: '$restString твій знайомий',
    );
    return '$names, $names2 і ще $_temp0';
  }

  @override
  String vouchTextVouchedBy(Object vouchNames) {
    return 'Рекомендації: $vouchNames';
  }

  @override
  String vouchTextIntroducedBy(Object vouchNames) {
    return 'Познайомили через $vouchNames';
  }

  @override
  String vouchTextThisSharesSAddress(Object a, Object b) {
    return 'Контакт $b отримає адресу контакту $a';
  }

  @override
  String get bootFailedKryfoCouldNotStart => 'Kryfo не зміг запуститися';

  @override
  String get bootFailedThisIsAFault =>
      'Це збій на цьому пристрої, а не в мережі. Tor тут ні до чого.';

  @override
  String get kryfoLinkTextThatLinkIsNot =>
      'Це посилання Kryfo не може прочитати';

  @override
  String kryfoLinkTextAdd(Object who) {
    return 'Додати $who?';
  }

  @override
  String kryfoLinkTextThisIsAnInvite(Object who) {
    return 'Це запрошення до розмови: $who. Додавай, лише якщо знаєш, звідки взялося посилання.';
  }

  @override
  String get kryfoLinkTextAddThem => 'Додати';

  @override
  String get kryfoLinkTextNotNow => 'Не зараз';

  @override
  String kryfoLinkTextJoin(Object roomName) {
    return 'Увійти в «$roomName»';
  }

  @override
  String get kryfoLinkTextKryfoLink => 'Посилання Kryfo';

  @override
  String kryfoLinkTextAdd2(Object who) {
    return 'Додати $who';
  }

  @override
  String get kryfoLinkTextBurnerRoom => 'ОДНОРАЗОВА КІМНАТА';

  @override
  String get kryfoLinkTextThisRoomHasClosed => 'Цю кімнату закрито';

  @override
  String kryfoLinkTextClosesIn(Object time) {
    return 'Закриється через $time';
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
      other: 'Закриється через $time · до $capString учасника',
      many: 'Закриється через $time · до $capString учасників',
      few: 'Закриється через $time · до $capString учасників',
      one: 'Закриється через $time · до $capString учасника',
    );
    return '$_temp0';
  }

  @override
  String get kryfoLinkTextJoin2 => 'Увійти';

  @override
  String get kryfoLinkTextYouJoinUnderA =>
      'Ти входиш під ключем, створеним для цієї кімнати. Ніхто в ній не бачить твій Kryfo ID.';

  @override
  String get linkStubFetchedOverTorBy =>
      'Завантажено через tor · твоїм пристроєм';

  @override
  String get linkStubFetchedOverTorByTheirDevice =>
      'Завантажено через tor · пристроєм співрозмовника';

  @override
  String mediaBubblesB(Object bytes) {
    return '$bytes Б';
  }

  @override
  String mediaBubblesKb(Object bytes) {
    return '$bytes КБ';
  }

  @override
  String mediaBubblesMb(Object bytes) {
    return '$bytes МБ';
  }

  @override
  String get mediaBubblesFile => 'ФАЙЛ';

  @override
  String get mediaBubblesAudioUnavailable => 'Аудіо недоступне';

  @override
  String get mediaBubblesHidden => 'Приховано';

  @override
  String get mediaBubblesMicPermissionNeeded => 'Потрібен дозвіл на мікрофон';

  @override
  String get mediaBubblesReleaseToCancel => 'Відпусти, щоб скасувати';

  @override
  String get mediaBubblesVoiceHiddenSlideTo =>
      'Голос приховано · проведи, щоб скасувати';

  @override
  String get mediaBubblesSlideToCancel => 'Проведи, щоб скасувати';

  @override
  String get mediaBubblesSendPhoto => 'Надіслати фото';

  @override
  String get mediaBubblesAddACaption => 'Додай підпис…';

  @override
  String get motionStandby => 'ОЧІКУВАННЯ';

  @override
  String get motionConnecting => 'ПІДКЛЮЧЕННЯ';

  @override
  String get motionBuilding => 'ПОБУДОВА';

  @override
  String get motionPublishing => 'ПУБЛІКАЦІЯ';

  @override
  String get motionReady => 'ГОТОВО';

  @override
  String get motionPreparingToConnect => 'Готуємося до підключення';

  @override
  String get motionFindingAPrivatePath => 'Шукаємо приватний шлях';

  @override
  String get motionCarvingThePath => 'Прокладаємо шлях';

  @override
  String get motionAnnouncingYourArrival => 'Повідомляємо про твою появу';

  @override
  String get motionYouReAnonymous => 'Анонімно';

  @override
  String get motionTorIsStartingIn =>
      'Tor запускається у фоні. Цей граф засвічується, поки формується з’єднання.';

  @override
  String get motionMakingAFreshRoute =>
      'Прокладаємо новий маршрут через анонімні ретранслятори.';

  @override
  String get motionBouncingThroughRelaysSo =>
      'Стрибаємо між ретрансляторами, щоб ніхто не міг вистежити це до тебе.';

  @override
  String get motionTellingTheNetworkYou =>
      'Повідомляємо мережі, що ти онлайн, - не розкриваючи, де ти.';

  @override
  String get motionYourIpIsHidden =>
      'Твою IP-адресу приховано. Зв’язатися з тобою можуть лише ті, хто має твій Kryfo.';

  @override
  String get motionBuilding2 => 'будується';

  @override
  String get motionOpen => 'відкритий';

  @override
  String get motionLive => 'активний';

  @override
  String motionCircuit(Object circuit) {
    return 'Ланцюжок · *$circuit*';
  }

  @override
  String get motionDelivered => 'Доставлено';

  @override
  String get motionSent => 'Надіслано';

  @override
  String get motion1Hop => '1 вузол';

  @override
  String get motion3Hops => '3 вузли';

  @override
  String get movedStripThisKryfoHasMoved =>
      'Цей Kryfo переїхав на інший пристрій. Ніщо, надіслане звідси, ні до кого не дійде.';

  @override
  String get navBarChats => 'Чати';

  @override
  String get navBarTools => 'Інструменти';

  @override
  String get navBarSupport => 'Підтримати';

  @override
  String get navBarMe => 'Я';

  @override
  String get pairCodePanelPuttingYourInviteIn => 'Готуємо твоє запрошення';

  @override
  String get pairCodePanelYourInviteIsNot => 'Твоє запрошення ще не готове';

  @override
  String get pairCodePanelReadSixDigitsOut =>
      'Продиктуй шість цифр - і тебе зможуть додати. Більше нічим обмінюватися не треба.';

  @override
  String get pairCodePanelWorking => 'Працюємо';

  @override
  String get pairCodePanelOrMakeASix =>
      'Або створи шестизначний код, щоб продиктувати';

  @override
  String get pairCodePanelCodeCopied => 'Код скопійовано';

  @override
  String pairCodePanelBurnsIn(Object mm, Object ss) {
    return 'Зникне через $mm:$ss';
  }

  @override
  String get pairCodePanelTheyTapAddChoose =>
      'Хай натиснуть «Додати», оберуть код і введуть ці цифри.';

  @override
  String get pairCodePanelTheyOpenKryfoTap =>
      'Хай відкриють Kryfo, натиснуть «Додати», оберуть «Код з’єднання» і введуть ці шість цифр. Для наступної людини створи новий.';

  @override
  String get pairCodePanelYourWords => 'Твої три слова';

  @override
  String pinsPinnedMessages(Object count) {
    return 'Закріплені повідомлення · $count';
  }

  @override
  String get pinsPinnedMessages2 => 'Закріплені повідомлення';

  @override
  String get pinsPhoto => 'Фото';

  @override
  String get pinsVoiceMessage => 'Голосове повідомлення';

  @override
  String get pinsMessage => 'Повідомлення';

  @override
  String pinsToday(Object hm) {
    return 'Сьогодні · $hm';
  }

  @override
  String get pinsPinned => 'Закріплено';

  @override
  String pinsOf(Object pinsLength, Object kMaxPins) {
    return '$pinsLength з $kMaxPins';
  }

  @override
  String get pinsNothingPinnedHereYet =>
      'Тут ще нічого не закріплено. Затисни повідомлення й вибери «Закріпити» - і воно чекатиме тут для всіх у чаті.';

  @override
  String get pinsJump => 'Перейти';

  @override
  String get pinsUnpin => 'Відкріпити';

  @override
  String powNoteFirstMessageToSomeone(int secs) {
    final intl.NumberFormat secsNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String secsString = secsNumberFormat.format(secs);

    return 'Перше повідомлення новій людині · доводимо, що воно справжнє · $secsString с';
  }

  @override
  String powNoteFirstMessageSlow(int secs) {
    final intl.NumberFormat secsNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String secsString = secsNumberFormat.format(secs);

    return 'Перше повідомлення новій людині · доводимо, що воно справжнє · $secsString с · на повільному телефоні до хвилини';
  }

  @override
  String previewStripFetchedOverTor(Object domainOf) {
    return '$domainOf · завантажено через tor';
  }

  @override
  String get previewStripDropThePreview => 'Прибрати прев’ю';

  @override
  String get previewStripAddPreview => 'Додати прев’ю';

  @override
  String get previewStripFetchingOverTor => 'Завантажуємо через tor…';

  @override
  String toolPartsB(Object bytes) {
    return '$bytes Б';
  }

  @override
  String toolPartsKb(Object bytes) {
    return '$bytes КБ';
  }

  @override
  String toolPartsMb(Object mb) {
    return '$mb МБ';
  }

  @override
  String get torBootSplashNoShortcutsNoTraces =>
      'Без коротких шляхів, без слідів';

  @override
  String get torBootSplashTheNetworkThatKeeps =>
      'Мережа, що береже твою приватність, розігрівається';

  @override
  String get torBootSplashMadeOnThisPhone =>
      'Створено на цьому телефоні. Нічого нікуди не надсилається.';

  @override
  String get torBootSplashFirstLaunchTakesA =>
      'Перший запуск триває трохи довше · лише під час старту';

  @override
  String get videoBubbleNothingHereOpensThat =>
      'Тут це нема чим відкрити · пропонуємо поділитися';

  @override
  String videoBubbleMb(Object b) {
    return '$b МБ';
  }

  @override
  String videoBubbleKb(Object b) {
    return '$b КБ';
  }

  @override
  String get videoBubbleVideo => 'Відео';

  @override
  String get notificationsChannelName => 'Повідомлення';

  @override
  String get cameraClose => 'Закрити';

  @override
  String get cameraFlash => 'Спалах';

  @override
  String get cameraPhoto => 'Фото';

  @override
  String get cameraVideo => 'Відео';

  @override
  String get cameraRetake => 'Перезняти';

  @override
  String get seenIntroductions => 'Знайомства';

  @override
  String get donateAddress => 'Адреса';

  @override
  String get donateCopy => 'Копіювати';

  @override
  String get donateDone => 'Готово';

  @override
  String get donateTierSupporter => 'Прихильник';

  @override
  String get donateTierPatron => 'Меценат';

  @override
  String get donateTierGuardian => 'Хранитель';

  @override
  String get chatBlock => 'Заблокувати';

  @override
  String get chatDecline => 'Відхилити';

  @override
  String get chatAccept => 'Прийняти';

  @override
  String get bridgesConnecting => 'Підключення';

  @override
  String get bridgesSavedTag => 'Збережено';

  @override
  String get restoreMade => 'Створено';

  @override
  String get restoreContacts => 'Контакти';

  @override
  String get restoreMessages => 'Повідомлення';

  @override
  String get restoreAttachments => 'Вкладення';

  @override
  String get restoreHiddenChats => 'Приховані чати';

  @override
  String get restoreHiddenFollow =>
      'Приховані чати, з новим PIN-кодом прихованих чатів, який ти вибереш наприкінці.';

  @override
  String get restoreChooseHiddenPin =>
      'У цій копії є приховані чати. Вибери для них PIN-код прихованих чатів.';

  @override
  String get restoreHiddenLockFirst =>
      'Прихованим чатам потрібне блокування, тому спершу Kryfo отримає власний PIN-код.';

  @override
  String get shieldBlock => 'Заблокувати';

  @override
  String get shieldDelete => 'Видалити';

  @override
  String get shieldIgnore => 'Ігнорувати';

  @override
  String get profileIdentity => 'Ідентичність';

  @override
  String get avatarPickerShape => 'Форма';

  @override
  String get avatarPickerColour => 'Колір';

  @override
  String get avatarPickerTurn => 'Поворот';

  @override
  String get transportStatus => 'Стан';

  @override
  String get transportBootstrap => 'Запуск';

  @override
  String get transportNetwork => 'Мережа';

  @override
  String get transportConnectivity => 'Зв’язок';

  @override
  String get transportRelays => 'Ретранслятори';

  @override
  String get transportTraffic => 'Трафік';

  @override
  String get transportContacts => 'Контакти';

  @override
  String get transportKnown => 'Відомі';

  @override
  String get transportListening => 'Слухає';

  @override
  String get transportMemory => 'Пам’ять';

  @override
  String get settingsConnected => 'Підключено';

  @override
  String get settingsScreenshots => 'Знімки екрана';

  @override
  String get settingsBlocked2 => 'Заблоковано';

  @override
  String get settingsAllowed => 'Дозволено';

  @override
  String get settingsOn => 'Увімкнено';

  @override
  String get settingsOff => 'Вимкнено';

  @override
  String get settingsNotifications => 'Сповіщення';

  @override
  String get settingsPrivacy => 'Приватність';

  @override
  String get settingsSecurity => 'Безпека';

  @override
  String get settingsBackup => 'Резервна копія';

  @override
  String get settingsVoice => 'Голос';

  @override
  String get settingsAbout => 'Про Kryfo';

  @override
  String get wallpaperGradients => 'Градієнти';

  @override
  String get wallpaperPatterns => 'Візерунки';

  @override
  String get wallpaperMoods => 'Настрої';

  @override
  String get confirmSheetKeep => 'Залишити';

  @override
  String get confirmSheetSave => 'Зберегти';

  @override
  String get confirmSheetCancel => 'Скасувати';

  @override
  String bridgesSaved(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString моста',
      many: '$countString мостів',
      few: '$countString мости',
      one: '$countString міст',
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

    return 'Прийнято: $goodString, не розпізнано: $badString';
  }

  @override
  String get bridgesNoneUsable =>
      'Жоден із цих рядків не підходить як міст, тому мости лишаються вимкненими';

  @override
  String get bridgesCouldNotApply =>
      'Не вдалося застосувати мости. Спробуй зберегти ще раз.';

  @override
  String get languageTitle => 'Мова';

  @override
  String get languageMatchPhone => 'Як на телефоні';

  @override
  String languageMatchPhoneValue(Object language) {
    return 'Як на телефоні ($language)';
  }

  @override
  String get languageRedrawLine =>
      'Kryfo перемалюється новою мовою і відкриється на твоїх чатах.';

  @override
  String languageButton(Object language) {
    return 'Мова: $language';
  }

  @override
  String get androidServiceTitle => 'Kryfo увімкнено';

  @override
  String get androidServiceText =>
      'Твоя зашифрована лінія лишається відкритою, щоб повідомлення надходили';

  @override
  String get androidChannelName => 'На зв’язку';

  @override
  String get androidChannelDescription =>
      'Тримає Kryfo на зв’язку, щоб зашифровані повідомлення надходили, навіть коли він закритий. Якщо це вимкнути, доставка зупиниться.';

  @override
  String get videoViewerPlay => 'Відтворити';

  @override
  String get videoViewerPause => 'Пауза';

  @override
  String get videoViewerPlayAgain => 'Переглянути ще раз';

  @override
  String get videoViewerCannotPlay =>
      'Цей телефон не може відтворити це відео тут.';

  @override
  String get videoViewerOpenElsewhere => 'Відкрити в іншому застосунку';

  @override
  String get photoKnowsLookedFor => 'Що шукали';

  @override
  String get photoKnowsNotInIt => 'Немає';

  @override
  String get languageNameEn => 'Англійська';

  @override
  String get languageNameDe => 'Німецька';

  @override
  String get languageNameFr => 'Французька';

  @override
  String get languageNameEs => 'Іспанська';

  @override
  String get languageNamePt => 'Португальська (Бразилія)';

  @override
  String get languageNameIt => 'Італійська';

  @override
  String get languageNameRu => 'Російська';

  @override
  String get languageNameUk => 'Українська';

  @override
  String get languageNameTr => 'Турецька';

  @override
  String get languageNameZh => 'Китайська (спрощена)';

  @override
  String get languageNameZhHant => 'Китайська (традиційна)';

  @override
  String get languageNameVi => 'В’єтнамська';

  @override
  String get languageNameId => 'Індонезійська';

  @override
  String get languageNameFa => 'Перська';

  @override
  String get languageNameAr => 'Арабська';

  @override
  String get languageLaterLine =>
      'Мову можна будь-коли змінити в налаштуваннях.';

  @override
  String get pollAttach => 'Опитування';

  @override
  String get pollNewTitle => 'Нове опитування';

  @override
  String get pollQuestionHint => 'Запитай щось у групи';

  @override
  String get pollOptionsLabel => 'Варіанти';

  @override
  String pollOptionHint(Object n) {
    return 'Варіант $n';
  }

  @override
  String get pollAddOption => 'Додати варіант';

  @override
  String get pollMaxLine => 'Не більше дванадцяти варіантів.';

  @override
  String get pollMultiple => 'Кілька відповідей';

  @override
  String get pollMultipleLine => 'Можна вибрати більше одного.';

  @override
  String get pollSend => 'Надіслати опитування';

  @override
  String get pollKind => 'Опитування';

  @override
  String get pollKindMulti => 'Опитування · кілька відповідей';

  @override
  String get pollKindClosed => 'Підсумки';

  @override
  String pollVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count голосу',
      many: '$count голосів',
      few: '$count голоси',
      one: '$count голос',
      zero: 'Ще ніхто не голосував',
    );
    return '$_temp0';
  }

  @override
  String get pollVote => 'Проголосувати';

  @override
  String get pollTakeBack => 'Відкликати мій голос';

  @override
  String get pollClose => 'Завершити опитування';

  @override
  String get pollCloseTitle => 'Завершити це опитування?';

  @override
  String get pollCloseLine =>
      'Усі побачать підсумки, і голосувати більше буде не можна.';

  @override
  String get pollCloseYes => 'Завершити';

  @override
  String pollPreview(Object question) {
    return 'Опитування: $question';
  }

  @override
  String get pollWhoVoted => 'Хто голосував';

  @override
  String get pollNobody => 'Поки нікого';

  @override
  String get pollYou => 'Ти';

  @override
  String pollOptionA11y(Object option, Object share) {
    return '$option, $share';
  }

  @override
  String get pollPickOne => 'Вибери один';

  @override
  String get pollPickSeveral => 'Вибери один або кілька';

  @override
  String get searchOpen => 'Пошук';

  @override
  String get searchHint => 'Шукати в чатах і повідомленнях';

  @override
  String get searchFilterAll => 'Усе';

  @override
  String get searchFilterPhotos => 'Фото';

  @override
  String get searchFilterVideos => 'Відео';

  @override
  String get searchFilterFiles => 'Файли';

  @override
  String get searchFilterLinks => 'Посилання';

  @override
  String get searchChats => 'Чати';

  @override
  String get searchMessages => 'Повідомлення';

  @override
  String get searchIntroTitle => 'Шукай у своїх чатах';

  @override
  String get searchIntroLine =>
      'Імена, слова, фото, файли й посилання. Пошук відбувається на цьому телефоні й нічого нікуди не надсилає.';

  @override
  String get searchNothing => 'Нічого не знайдено';

  @override
  String get searchNothingLine => 'Спробуй інше слово або інший фільтр.';

  @override
  String searchMatches(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count збігу',
      many: '$count збігів',
      few: '$count збіги',
      one: '$count збіг',
    );
    return '$_temp0';
  }

  @override
  String searchMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ще $count',
      many: 'ще $count',
      few: 'ще $count',
      one: 'ще $count',
    );
    return '$_temp0';
  }

  @override
  String searchFilling(Object share) {
    return 'Додаю старіші повідомлення · $share';
  }

  @override
  String get searchClear => 'Очистити';

  @override
  String get handleShowInSearch => 'Показувати мене в пошуку';

  @override
  String get handleShowInSearchLine =>
      'Будь-хто зможе знайти це ім’я користувача й написати тобі.';

  @override
  String handleShownAs(Object name) {
    return 'Показується як $name';
  }

  @override
  String get handleNameInSearch => 'Ім’я в пошуку';

  @override
  String get handleNameInSearchLine =>
      'Необов’язково. Воно видно поруч з іменем користувача, коли хтось шукає. Будь-хто зможе знайти це ім’я користувача й написати тобі.';

  @override
  String get handleNameHint => 'Твоє ім’я, або залиш порожнім';

  @override
  String get handleShowMe => 'Показувати';

  @override
  String get handleSearchOff => 'Тебе більше немає в пошуку';

  @override
  String handleSearchOn(Object handle) {
    return 'Ти в пошуку як @$handle';
  }

  @override
  String get handleRegistryFailed => 'Реєстр не відповів. Спробуй за хвилину.';

  @override
  String get handleCheckClock =>
      'Перевір дату й час на телефоні та спробуй ще раз.';

  @override
  String get searchPeople => 'Люди';

  @override
  String searchPeopleAsk(Object query) {
    return 'Шукати «$query» серед публічних імен користувачів';
  }

  @override
  String get searchPeopleLine =>
      'Запит іде через Tor. Реєстр нічого про нього не зберігає.';

  @override
  String get searchPeopleNone => 'Жодне публічне ім’я не підходить';

  @override
  String get searchPeopleOffline => 'Tor ще не готовий';

  @override
  String get searchPeopleBusy =>
      'Зараз забагато запитів. Спробуй трохи згодом.';

  @override
  String get searchPeopleUnreachable => 'Реєстр не відповів';

  @override
  String get peopleVerified => 'Підтверджене ім’я користувача';

  @override
  String get peopleAdd => 'Додати';

  @override
  String peopleFingerprint(Object fp) {
    return 'Відбиток ключа · $fp';
  }

  @override
  String get peopleFingerprintLine =>
      'Перевір, що він збігається з тим, що бачить співрозмовник у своєму застосунку.';

  @override
  String get peopleAdding => 'Додаю…';

  @override
  String handleNobodyHasClaimed(Object handle) {
    return 'Ніхто не зайняв $handle';
  }

  @override
  String get handleThatHandleIsTaken => 'Це ім’я користувача вже зайняте';

  @override
  String get pinPickDifferent => 'Вибери інший PIN-код';

  @override
  String get settingsKeptOnWhileLock =>
      'Лишається увімкненим, доки увімкнене блокування Kryfo.';

  @override
  String get lockFingerAfterPin =>
      'Введи PIN-код один раз, щоб знову входити за відбитком.';

  @override
  String get pinsAdvanced => 'Додатковий захист';

  @override
  String get pinsAdvancedLine =>
      'На випадок, якщо тебе змусять розблокувати телефон.';

  @override
  String get pinsWipeLine =>
      'Якщо ввести його на екрані блокування, він зітре Kryfo з цього телефона.';

  @override
  String get pinsDecoyPin => 'PIN-приманка';

  @override
  String get pinsDecoyLine =>
      'Відкриває порожній Kryfo, наче його щойно встановили.';

  @override
  String get pinsSetADecoyPin => 'Задати PIN-приманку';

  @override
  String get pinsChangeDecoyPin => 'Змінити PIN-приманку';

  @override
  String get pinsRemoveTheDecoyPin => 'Видалити PIN-приманку?';

  @override
  String get pinsTheDecoyGoes =>
      'Порожній Kryfo, який вона відкриває, зникне разом із нею.';

  @override
  String get pinsTurnOffWithDecoy =>
      'Усі PIN-коди зникнуть, а разом із ними приманка, її Kryfo та всі приховані чати. Будь-хто з твоїм телефоном у руках відкриє Kryfo від твого імені.';

  @override
  String get pinsHowThisWorks => 'Як це працює';

  @override
  String get flowEnterYourPin => 'Введи свій PIN-код';

  @override
  String get flowEnterYourPinLine => 'Той, яким відкривається Kryfo.';

  @override
  String get flowWipeTitle => 'PIN для стирання';

  @override
  String get flowWipe1 =>
      'Якщо ввести його на екрані блокування замість твого PIN-коду, він зітре Kryfo з цього телефона й закриє його. Для того, хто дивиться, застосунок просто зупинився.';

  @override
  String get flowWipe2 =>
      'Разом із ним зникнуть усі чати й твоя особа, а якщо є приманка, то й вона.';

  @override
  String get flowWipeChoose => 'Вибери PIN для стирання';

  @override
  String get flowWipeDone => 'PIN для стирання задано';

  @override
  String get flowWipeDoneLine =>
      'На екрані блокування ніщо не видає, що він є.';

  @override
  String get flowDecoyTitle => 'PIN-приманка';

  @override
  String get flowDecoy1 =>
      'Відкриває порожній Kryfo, наче його щойно встановили.';

  @override
  String get flowDecoyFinger =>
      'Твій відбиток відкриває справжній Kryfo. Якщо тебе можуть змусити прикласти палець, вимкни вхід відбитком.';

  @override
  String get flowDecoyDigits =>
      'Візьми стільки ж цифр, скільки у твоєму PIN-коді: будь-хто, хто дивиться, може порахувати крапки.';

  @override
  String get flowDecoyShade =>
      'Сповіщення, що вже є в шторці, вже бачили. Поки відкрита приманка, нові не з’являються.';

  @override
  String get flowDecoyChoose => 'Вибери PIN-приманку';

  @override
  String get flowDecoyDone => 'PIN-приманку задано';

  @override
  String get flowDecoyDoneLine =>
      'Введи її на екрані блокування, щоб відкрити порожній Kryfo. Щоб вийти, перемкнися на інший застосунок і введи свій PIN-код.';

  @override
  String get flowLaw =>
      'У деяких країнах відмова розблокувати телефон або приховування даних від влади вже саме собою правопорушення. Знай закони тих місць, куди їдеш.';

  @override
  String get howWipe =>
      'Якщо ввести PIN для стирання на екрані блокування, він зітре всі чати, твою особу й будь-яку приманку, а потім закриє Kryfo. Він працює, навіть коли клавіатуру заблоковано після хибних спроб.';

  @override
  String get howDecoy =>
      'PIN-приманка відкриває другий, порожній Kryfo з власними трьома словами. Повідомлення для справжнього Kryfo далі тихо надходять під ним. Щоб вийти з приманки, перемкнися на інший застосунок і введи свій PIN-код.';

  @override
  String get flowNotSet => 'Не вдалося задати. Спробуй ще раз.';

  @override
  String get pinsHiddenChats => 'Приховані чати';

  @override
  String get pinsHiddenLine =>
      'Вибрані чати сховані від очей, доки ти не введеш PIN-код прихованих чатів: їх немає ні в списку, ні в пошуку, і сповіщень теж немає.';

  @override
  String get pinsSetUp => 'Налаштувати';

  @override
  String get pinsChangeHiddenPin => 'Змінити PIN-код прихованих чатів';

  @override
  String get pinsHideMoreChats => 'Приховати ще чати';

  @override
  String get pinsRemoveHiddenChats => 'Вимкнути приховані чати';

  @override
  String get pinsRemoveHiddenTitle => 'Вимкнути приховані чати?';

  @override
  String get pinsRemoveHiddenLine =>
      'Вони повернуться до списку чатів, а PIN-код прихованих чатів більше нічого не відкриватиме.';

  @override
  String get pinsTurnOffHiddenFirst =>
      'Прихованим чатам потрібне блокування. Спершу вимкни їх, і вони повернуться до списку чатів.';

  @override
  String get flowVaultTitle => 'Приховані чати';

  @override
  String get flowVault1 =>
      'Вибери чати й групи, які треба приховати. Твій PIN-код відкриває Kryfo без них. PIN-код прихованих чатів відкриває все, разом із прихованими чатами.';

  @override
  String get flowVault2 =>
      'Поки вони приховані, від них немає сповіщень і лічильників. Їхні повідомлення далі надходять і чекають, запечатані, на твій PIN-код прихованих чатів.';

  @override
  String get flowVaultFinger =>
      'Твій відбиток відкриває Kryfo без прихованих чатів.';

  @override
  String get flowVaultDigits =>
      'Зроби й свій PIN-код не коротшим за шість цифр: будь-хто, хто дивиться, може порахувати крапки.';

  @override
  String get flowVaultReplace =>
      'Це замінить усі приховані чати, що вже є на цьому телефоні.';

  @override
  String get flowVaultChoose => 'Вибери PIN-код прихованих чатів';

  @override
  String get flowVaultChooseLine => 'Шість цифр або більше.';

  @override
  String get flowEnterHiddenPinLine =>
      'Той, яким відкриваються приховані чати.';

  @override
  String get flowVaultForgetTitle => 'Запам’ятай цей PIN-код';

  @override
  String get flowVaultForget =>
      'Якщо ти забудеш цей PIN-код, приховані чати зникнуть назавжди. Ніхто не зможе їх повернути, навіть ми.';

  @override
  String get flowVaultForgetOk => 'Зрозуміло';

  @override
  String get flowVaultPickTitle => 'Вибери, які чати приховати';

  @override
  String get flowVaultPickLine =>
      'Вони зараз підуть зі списку чатів. PIN-код прихованих чатів знову їх покаже.';

  @override
  String flowVaultPickButton(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Приховати $countString чату',
      many: 'Приховати $countString чатів',
      few: 'Приховати $countString чати',
      one: 'Приховати $countString чат',
      zero: 'Поки нічого не приховувати',
    );
    return '$_temp0';
  }

  @override
  String get flowVaultPickEmpty => 'Поки немає чатів, які можна приховати.';

  @override
  String get flowVaultBackupTitle => 'Зробити резервну копію зараз?';

  @override
  String get flowVaultBackupLine =>
      'Резервна копія, зроблена зараз, збереже й приховані чати, під власною парольною фразою. Якщо ти забудеш PIN-код прихованих чатів, це єдиний шлях до них.';

  @override
  String get flowVaultBackupNow => 'Зробити копію';

  @override
  String get flowVaultNotNow => 'Не зараз';

  @override
  String get flowVaultDone => 'Приховані чати налаштовано';

  @override
  String get flowVaultDoneLine =>
      'Введи PIN-код прихованих чатів на екрані блокування, щоб їх побачити. Перемкнися на інший застосунок, і вони знову будуть приховані.';

  @override
  String get flowVaultChanged => 'PIN-код прихованих чатів змінено';

  @override
  String get flowVaultChangedLine =>
      'Приховані чати тепер відкриваються новим. Старий більше нічого не відкриває.';

  @override
  String get howVault =>
      'PIN-код прихованих чатів відкриває Kryfo з прихованими чатами, а твій PIN-код і відбиток відкривають його без них. Якщо налаштувати приховані чати заново, вони замінять ті, що є на цьому телефоні. Забудеш PIN-код прихованих чатів, і вони зникнуть назавжди.';

  @override
  String get chatHide => 'Приховати чат';

  @override
  String get groupHide => 'Приховати групу';

  @override
  String get chatHidden => 'Приховано';

  @override
  String get chatHiddenToast => 'Приховано зі списку чатів';

  @override
  String get chatShowInList => 'Показати в списку чатів';

  @override
  String get stickerOpen => 'Стікери';

  @override
  String get stickerRecent => 'Нещодавні';

  @override
  String stickerA11y(String emoji) {
    return 'Стікер $emoji';
  }

  @override
  String get stickerRemoveRecent => 'Прибрати з нещодавніх';

  @override
  String get stickerCouldNotLoad => 'Не вдалося завантажити стікери';

  @override
  String get stickerLabel => 'Стікер';

  @override
  String get stickerNewer => 'З новішої версії Kryfo';

  @override
  String get devLinkMismatch =>
      'У цьому посиланні вказано Marios, але його ключ не збігається. Нічого не додано.';

  @override
  String get devName => 'Marios';

  @override
  String get devRowTitle => 'Marios · створив Kryfo';

  @override
  String get devWelcome =>
      'Привіт, я Marios, я роблю Kryfo. Пиши мені про що завгодно: помилки, ідеї, питання. Я читаю все.';

  @override
  String get devPinned => 'Вбудовано в Kryfo';

  @override
  String get devAnonymous => 'Анонімно';

  @override
  String get devAboutLine =>
      'Ключ Marios вбудовано в Kryfo. Кожне його повідомлення перевіряється за цим ключем, тож ніхто інший не може писати від його імені.';

  @override
  String get devKeyLabel => 'Його ключ';

  @override
  String get devDeleteLine =>
      'Усі повідомлення зникнуть, і чат більше не повернеться.';

  @override
  String get devDeleteLineAnon =>
      'Усі повідомлення та ім’я, створене для цього чату, зникнуть, і чат більше не повернеться.';

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
  String get settingsWriteToMarios => 'Написати Marios';

  @override
  String get settingsWriteToMariosHint => 'Помилки, ідеї, питання';

  @override
  String get seenDevChat => 'Чат із Marios';

  @override
  String get seenDevChatCell => 'Якщо напишеш';

  @override
  String get seenDevChatLine =>
      'Нічого, доки ти не напишеш. Потім те, що ти надсилаєш, і твої три слова, якщо тільки ти не пишеш анонімно.';

  @override
  String get devWriteAnonymously => 'Написати анонімно';

  @override
  String get devUseMyWords => 'Використати мої три слова';

  @override
  String get devWhoSeesWhat => 'Як це працює';

  @override
  String get devWhoWords =>
      'З твоїми трьома словами це звичайний чат: Marios може відповісти тобі, а твоє обличчя й значок прихильника залишаються в тебе.';

  @override
  String get devWhoAnon =>
      'Якщо писати анонімно, Kryfo створює нове ім’я та ключі лише для цього чату. Вони залишаються на цьому телефоні й ніде більше не використовуються.';

  @override
  String get devWhoNothingYet =>
      'Ніщо не залишає твій телефон, доки ти не надішлеш перше повідомлення.';

  @override
  String get devWhoChoiceStays => 'Твій вибір збережеться для цього чату.';

  @override
  String get devKeyCheckFailed =>
      'Не вдалося перевірити ключ Marios. Нічого не надіслано.';

  @override
  String get devLockLine =>
      'Marios їх прочитає. Ти зможеш написати ще, щойно він відповість.';

  @override
  String get devNewKey => 'У Marios новий ключ';

  @override
  String get devStartNewChat => 'Почати новий чат';

  @override
  String get devKeyRetired =>
      'Цей ключ більше не використовується. Тут уже нічого не можна надіслати чи отримати.';

  @override
  String get devNamelessLine =>
      'Ім’я, створене для цього чату, залишається на телефоні, де його створили, тож тут чат можна лише читати.';

  @override
  String get devStartNewLine =>
      'Усі повідомлення тут зникнуть, і відкриється новий чат.';

  @override
  String get devVoiceDisguised => 'Твій голос у цьому чаті змінено';

  @override
  String get devChatOptions => 'Налаштування чату';

  @override
  String appLinkOtherKey(Object id) {
    return 'Це посилання видає себе за $id, але його ключ не збігається. Нічого не додано.';
  }

  @override
  String scamShieldSaysItIs(Object shown) {
    return 'Представляється як $shown, але ключ не збігається';
  }

  @override
  String get requestsSomeoneNew => 'Хтось новий';

  @override
  String get appYourOwnInvite =>
      'Це твоє власне запрошення. Поділися ним з кимось, щоб зв’язатися.';

  @override
  String appTheyAreBlocked(Object id) {
    return '$id у списку заблокованих. Розблокуй у налаштуваннях, у розділі «Заблоковані», щоб додати знову.';
  }

  @override
  String get devLinkGone =>
      'Чат із Marios видалено. Щоб почати новий, натисни «Написати Marios» у налаштуваннях.';

  @override
  String lockTooManyTriesFor(Object left) {
    return 'Забагато спроб · $left';
  }
}
