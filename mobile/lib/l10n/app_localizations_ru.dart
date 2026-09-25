// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get atmosphereNone => 'нет';

  @override
  String get atmosphereEmber => 'угли';

  @override
  String get atmosphereDusk => 'сумерки';

  @override
  String get atmosphereMoss => 'мох';

  @override
  String get atmosphereRose => 'роза';

  @override
  String get atmosphereDots => 'точки';

  @override
  String get atmosphereGrid => 'сетка';

  @override
  String get atmosphereWaves => 'волны';

  @override
  String get atmosphereRain => 'дождь';

  @override
  String get atmosphereLateNight => 'Глубокая ночь';

  @override
  String get atmosphereWarmAfternoon => 'Тёплый день';

  @override
  String get atmosphereSnow => 'снег';

  @override
  String get atmosphereDesert => 'пустыня';

  @override
  String get atmospherePaper => 'бумага';

  @override
  String get backupThatPassphraseDoesNot =>
      'Эта парольная фраза не открывает этот файл';

  @override
  String get backupThatFileIsNot => 'Этот файл — не резервная копия kryfo';

  @override
  String get backupThisBackupIsFrom =>
      'Эта резервная копия из более новой версии kryfo. Обнови приложение и попробуй снова';

  @override
  String get backupThisFileIsDamaged =>
      'Этот файл повреждён, прочитать его нельзя';

  @override
  String get backupCouldNotMakeThe => 'не удалось создать ключ';

  @override
  String get contactCardMessageMeOn => 'Пиши мне в';

  @override
  String get contactCardScanItOrType =>
      'Отсканируй или введи три слова в kryfo.\nБольше эта карточка ничего о тебе не знает.';

  @override
  String contactCardMessageMeOnKryfo(Object haloId) {
    return 'Пиши мне в kryfo · $haloId';
  }

  @override
  String get contactStatusBlocked => 'заблокирован';

  @override
  String get contactStatusKeysVerifiedInPerson => 'Ключи проверены лично';

  @override
  String get contactStatusWaitingInRequests => 'Ждёт в запросах';

  @override
  String get contactStatusAddedByHand => 'Добавлен вручную';

  @override
  String get deliveryModeAlwaysOn => 'Всегда на связи';

  @override
  String get deliveryModeCheckIns => 'Проверки';

  @override
  String get deliveryModeThroughAHelperApp => 'Через приложение-помощник';

  @override
  String get deliveryModeNotYet => 'пока нет';

  @override
  String get deliveryModeJustNow => 'только что';

  @override
  String deliveryModeMinAgo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString мин назад',
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
      other: '$countString часа назад',
      many: '$countString часов назад',
      few: '$countString часа назад',
      one: '$countString час назад',
    );
    return '$_temp0';
  }

  @override
  String get deliveryModeYesterday => 'вчера';

  @override
  String deliveryModeDaysAgo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString дня назад',
      many: '$countString дней назад',
      few: '$countString дня назад',
      one: '$countString день назад',
    );
    return '$_temp0';
  }

  @override
  String get deliveryModeConnected => 'Подключено';

  @override
  String get deliveryModeConnecting => 'Подключение';

  @override
  String get deliveryModeNotConnected => 'Не подключено';

  @override
  String get deliveryModeCheckingNow => 'Идёт проверка';

  @override
  String deliveryModeLastCheckIn(Object agoLine) {
    return 'последняя проверка $agoLine';
  }

  @override
  String get deliveryModeNoCheckInYet => 'проверок пока не было';

  @override
  String deliveryModeConnectedNow(Object last) {
    return 'Подключено сейчас · $last';
  }

  @override
  String deliveryModeConnecting2(Object last) {
    return 'Подключение · $last';
  }

  @override
  String get deliveryModeNoCheckInYet2 => 'Проверок пока не было';

  @override
  String deliveryModeLastChecked(Object agoLine) {
    return 'Последняя проверка $agoLine';
  }

  @override
  String get deliveryModeAHelperApp => 'приложение-помощник';

  @override
  String deliveryModeWokenByNoWake(Object who) {
    return 'Будит: $who · пробуждений пока не было';
  }

  @override
  String deliveryModeWokenByLastWake(Object who, Object agoLine) {
    return 'Будит: $who · последнее пробуждение $agoLine';
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
      many: 'через $countString дней',
      few: 'через $countString дня',
      one: 'через $countString день',
    );
    return '$_temp0';
  }

  @override
  String get introBudgetInAnHour => 'через час';

  @override
  String introBudgetInHours(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'через $countString часа',
      many: 'через $countString часов',
      few: 'через $countString часа',
      one: 'через $countString час',
    );
    return '$_temp0';
  }

  @override
  String get introBudgetInAFewMinutes => 'через несколько минут';

  @override
  String get lockStateUnlockKryfo => 'Разблокировать kryfo';

  @override
  String get appInvalidUri => 'неверный uri';

  @override
  String appBundleError(Object e) {
    return 'Ошибка пакета: $e';
  }

  @override
  String appAlreadySaved(Object parsed) {
    return 'Уже сохранено: $parsed';
  }

  @override
  String appAddedYouCanMessage(Object parsed) {
    return 'Добавлено: $parsed · теперь можно писать';
  }

  @override
  String appPeerImportedV1(Object parsed) {
    return 'Собеседник импортирован (v1): $parsed';
  }

  @override
  String appLongWindow(Object line) {
    return '$line длинное окно';
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
      other: '$pString страницы',
      many: '$pString страниц',
      few: '$pString страницы',
      one: '$pString страница',
    );
    String _temp1 = intl.Intl.pluralLogic(
      e,
      locale: localeName,
      other: '$eString события',
      many: '$eString событий',
      few: '$eString события',
      one: '$eString событие',
    );
    return '$line ($heldString из $subsString, подключение $c с, $_temp0, $_temp1)';
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
      other: '$pString страницы',
      many: '$pString страниц',
      few: '$pString страницы',
      one: '$pString страница',
    );
    String _temp1 = intl.Intl.pluralLogic(
      e,
      locale: localeName,
      other: '$eString события',
      many: '$eString событий',
      few: '$eString события',
      one: '$eString событие',
    );
    return '$line (подключение $c с, $_temp0, $_temp1)';
  }

  @override
  String appSDropped(Object host, Object secs) {
    return '$host $secs с, обрыв';
  }

  @override
  String appS(Object host, Object secs) {
    return '$host $secs с';
  }

  @override
  String get appTorWouldNotWake => 'tor не просыпается';

  @override
  String get appCheckStarted => 'начата';

  @override
  String get appTorNotReadyIn => 'tor не готов за 75 с';

  @override
  String get appOk => 'ок';

  @override
  String get appOkNoRelayBegan => 'ок, ретрансляторы молчат';

  @override
  String get appOkCapped => 'ок, прервано';

  @override
  String appSBy(Object how, int secs, String why) {
    final intl.NumberFormat secsNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String secsString = secsNumberFormat.format(secs);

    String _temp0 = intl.Intl.selectLogic(why, {
      'push': '$how, $secsString с, по push',
      'other': '$how, $secsString с, по расписанию',
    });
    return '$_temp0';
  }

  @override
  String get appAnAttachmentCouldNot =>
      'Не удалось сохранить вложение на этом телефоне';

  @override
  String get appGroup2 => 'группа';

  @override
  String get appVoiceMessage => 'Голосовое сообщение';

  @override
  String get appPhoto => 'фото';

  @override
  String get appNewRequest => 'Новый запрос';

  @override
  String get appSomeoneYouHaveNot =>
      'Тебе написал кто-то, кого нет в твоих контактах';

  @override
  String get appSettingUpYourKeys => 'Готовим твои ключи';

  @override
  String get appOpeningYourChats => 'Открываем твои чаты';

  @override
  String get appStartingTor => 'запуск Tor';

  @override
  String get appTimedMessagesAreNot =>
      'Исчезающие сообщения не удаляются. Перезапусти kryfo';

  @override
  String get appVoiceMessage2 => 'голосовое сообщение';

  @override
  String appYou(Object body) {
    return 'ты: $body';
  }

  @override
  String get appThisRoomHasAlready => 'Срок этой комнаты уже истёк';

  @override
  String get appYouAreAlreadyIn => 'Ты уже в этой комнате';

  @override
  String get appCouldNotMakeA => 'не удалось создать ключ комнаты';

  @override
  String appJoinedButYourHello(Object linkName) {
    return 'Ты в «$linkName», но твоё приветствие задержано';
  }

  @override
  String appJoined(Object linkName) {
    return 'Ты в «$linkName»';
  }

  @override
  String appJoinedButTheCreator(Object linkName) {
    return 'Ты в «$linkName», но создатель пока недоступен';
  }

  @override
  String get appBooting => 'запуск...';

  @override
  String get appSettingUpYourIdentity => 'Создаём твой профиль...';

  @override
  String get appAddSomeone => 'Добавить человека';

  @override
  String get appScanTheirCodeOr =>
      'Отсканируй код или вставь то, что тебе дали: ссылку, @имя пользователя или ссылку на комнату.';

  @override
  String get appScanTheirCode => 'Сканировать код';

  @override
  String get appAKryfoLinkA => 'Ссылка kryfo, ссылка на комнату или @wren';

  @override
  String get appAddThem => 'Добавить';

  @override
  String get appEveryWayToAdd => 'Все способы добавить человека';

  @override
  String get appShowYourCodeSend =>
      'Покажи свой код, отправь ссылку, займи имя пользователя';

  @override
  String get appHelloFromTheOther => 'Привет с той стороны';

  @override
  String get appIdentityRestored => 'Профиль восстановлен';

  @override
  String get appIdentityCreated => 'Профиль создан';

  @override
  String get appStartingTor30s => 'Запуск tor (~30 с)...';

  @override
  String get appScanOrImportA =>
      'сначала отсканируй или импортируй собеседника';

  @override
  String get appEncryptingSending30s => 'Шифрование + отправка (~30 с)...';

  @override
  String get appTapStartListeningFirst => 'Сначала нажми «Начать приём»';

  @override
  String get appYourKryfo => 'Твой kryfo';

  @override
  String get appUriCopied => 'Uri скопирован';

  @override
  String get appCopyUri => 'Копировать uri';

  @override
  String get appAddAKryfo => 'Добавить kryfo';

  @override
  String get appScanQr => 'Сканировать QR';

  @override
  String get appPairingCode => 'Код связи';

  @override
  String get appOrPaste => '- или вставь -';

  @override
  String get commonCancel => 'Отмена';

  @override
  String get appImport => 'Импорт';

  @override
  String get appDev => 'Отладка';

  @override
  String get appYourKryfo2 => 'Твой kryfo:';

  @override
  String get appRestoredFromDisk => 'Восстановлено с диска';

  @override
  String get appStartListening => 'Начать приём';

  @override
  String get appListening => 'приём';

  @override
  String get appShowMyQr => 'Показать мой QR';

  @override
  String get appImportPeer => 'Импорт собеседника';

  @override
  String get appPeer => 'собеседник:';

  @override
  String get appMessageWillBeEncrypted => 'Сообщение (будет зашифровано)';

  @override
  String get appEncryptSend => 'Шифровать + отправить';

  @override
  String appStatus(Object status) {
    return 'статус: $status';
  }

  @override
  String get appSpeedPrivacy => 'Скорость и приватность →';

  @override
  String get appGettingMessages => 'Получение сообщений →';

  @override
  String get appDisableAppLock => 'Отключить блокировку?';

  @override
  String get appThePinWillBe =>
      'PIN-код будет удалён. Любой, у кого окажется твой телефон, увидит kryfo, открыв его.';

  @override
  String get appDisable => 'Отключить';

  @override
  String get appAppLockOn => 'Блокировка · вкл →';

  @override
  String get appAppLockOff => 'Блокировка · выкл →';

  @override
  String get appTorIsOff => 'Tor выключен';

  @override
  String get appConnectedRoutedThrough3 => 'Подключено · через 3 ретранслятора';

  @override
  String get appReadyToSendPublishing =>
      'Можно отправлять · публикуем твой адрес';

  @override
  String get appReadyToSendFinishing =>
      'Можно отправлять · завершаем настройку';

  @override
  String appConnecting(Object pct) {
    return 'Подключение · $pct';
  }

  @override
  String get appTor => 'Tor';

  @override
  String get appTorIsOffTurn =>
      'Tor выключен. Включи его, чтобы подключаться приватно.';

  @override
  String get appTheFirstConnectionTakes =>
      'Первое подключение занимает минуту-две: tor строит приватный маршрут. Потом маршрут кэшируется, поэтому в следующий раз kryfo откроется гораздо быстрее.';

  @override
  String get appRelayAndFastModes =>
      'Режимы «Ретранслятор» и «Быстрый» обходят tor и работают быстрее. Они в настройках, в разделе «Скорость и приватность», и у каждого указано, чем за это платишь.';

  @override
  String get appViaRelay => 'Ретранслятор';

  @override
  String get appOffline => 'не в сети';

  @override
  String get appFast => 'Быстрый';

  @override
  String get appTorOff => 'Tor выкл.';

  @override
  String get appTorReady => 'Tor готов';

  @override
  String get appConnecting2 => 'подключение';

  @override
  String mediaProgressSendingKeepTheApp(Object v) {
    return 'Отправка · $v · не закрывай приложение';
  }

  @override
  String mediaProgressPausedOfWaitingFor(Object count, Object count2) {
    return 'Пауза · $count из $count2 · ждём остальное';
  }

  @override
  String mediaProgressReceivingMedia(Object v) {
    return 'Получение медиа · $v';
  }

  @override
  String get mediaProgressCancelSending => 'Отменить отправку';

  @override
  String get metaReaderEndsBeforeItShould => 'обрывается раньше времени';

  @override
  String get metaReaderCouldNotBeRead => 'не читается';

  @override
  String get metaReaderExifThatCannotBe => 'нечитаемый exif';

  @override
  String get metaReaderSamsungTrailer => 'хвост samsung';

  @override
  String metaReaderChunk(Object type) {
    return 'блок $type';
  }

  @override
  String get metaReaderExifFlagSet => 'стоит флаг exif';

  @override
  String get metaReaderXmpFlagSet => 'стоит флаг xmp';

  @override
  String metaReaderAppBlock(Object id) {
    return 'блок приложения $id';
  }

  @override
  String get metaReaderUuidBox => 'блок uuid';

  @override
  String metaReaderBox(Object printable) {
    return 'блок $printable';
  }

  @override
  String get metaReaderAttachedData => 'дописанные данные';

  @override
  String metaReaderItem(Object printable) {
    return 'элемент $printable';
  }

  @override
  String get miuiAutostartAlreadyAllowedToRun => 'Работа в фоне уже разрешена';

  @override
  String get miuiAutostartLetKryfoRunIn => 'Разреши kryfo работать в фоне';

  @override
  String get miuiAutostartYourPhonePausesApps =>
      'Телефон приостанавливает приложения, чтобы беречь батарею. Без исключения kryfo не может получать сообщения, пока он закрыт.';

  @override
  String get commonAllow => 'Разрешить';

  @override
  String get commonSkip => 'Пропустить';

  @override
  String get miuiAutostartXiaomiTurnsOffBackground =>
      'Xiaomi по умолчанию отключает фоновые приложения. Без автозапуска kryfo не может доставлять сообщения, когда приложение закрыто. На следующем экране найди kryfo в списке и включи переключатель.';

  @override
  String get miuiAutostartOpenSettings => 'Открыть настройки';

  @override
  String get miuiAutostartCouldnTOpenIt =>
      'не открылось. поищи автозапуск в настройках телефона';

  @override
  String get notificationsNewEncryptedMessagesFrom =>
      'Новые зашифрованные сообщения от твоих контактов';

  @override
  String get notificationsNewMessage => 'новое сообщение';

  @override
  String get notificationsNewEncryptedMessagesFromYourContacts =>
      'новые зашифрованные сообщения от твоих контактов';

  @override
  String get notificationsNewMessage2 => 'Новое сообщение';

  @override
  String get notificationsEncrypted => 'зашифровано';

  @override
  String get rooms24h => '24 ч';

  @override
  String roomsD(Object inDays) {
    return '$inDays д';
  }

  @override
  String roomsH(Object inHours) {
    return '$inHours ч';
  }

  @override
  String get rooms24Hours => 'через 24 часа';

  @override
  String roomsDays(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'через $countString дня',
      many: 'через $countString дней',
      few: 'через $countString дня',
      one: 'через $countString день',
    );
    return '$_temp0';
  }

  @override
  String get roomsAnHour => 'через час';

  @override
  String get roomsAboutAnHour => 'примерно через час';

  @override
  String roomsHours(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'через $countString часа',
      many: 'через $countString часов',
      few: 'через $countString часа',
      one: 'через $countString час',
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
      other: 'примерно через $countString часа',
      many: 'примерно через $countString часов',
      few: 'примерно через $countString часа',
      one: 'примерно через $countString час',
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
      other: 'через $countString минуты',
      many: 'через $countString минут',
      few: 'через $countString минуты',
      one: 'через $countString минуту',
    );
    return '$_temp0';
  }

  @override
  String get roomsAMinute => 'через минуту';

  @override
  String get roomsExpired => 'истекла';

  @override
  String roomsDH(Object inDays, Object h) {
    return '$inDays д $h ч';
  }

  @override
  String roomsHM(Object inHours, Object m) {
    return '$inHours ч $m мин';
  }

  @override
  String roomsM(Object inMinutes) {
    return '$inMinutes мин';
  }

  @override
  String get scamShieldLooksLikeAScam => 'Похоже на мошенничество';

  @override
  String scamShieldThisNameMatches(Object shown) {
    return 'Это имя как у контакта $shown';
  }

  @override
  String scamShieldNameMatchesYourContact(Object shown) {
    return 'Имя совпадает с твоим контактом $shown';
  }

  @override
  String scamShieldSameFaceAsYour(Object shown) {
    return 'то же лицо, что у твоего контакта $shown';
  }

  @override
  String get scamShieldContainsACryptoAddress =>
      'Содержит адрес криптокошелька';

  @override
  String get scamShieldMentionsMoneyAndUrgency => 'Говорит о деньгах и торопит';

  @override
  String get scamShieldAsksYouToMove => 'Просит перейти в другое приложение';

  @override
  String get scamShieldLinksToALookalike =>
      'Ссылка на сайт, похожий на известный';

  @override
  String get scamShieldALongOpenerFrom =>
      'Длинное первое сообщение от человека без истории';

  @override
  String get scamShieldAsksForACode =>
      'Просит код, сид-фразу или файл восстановления';

  @override
  String scamShieldAlso(Object shown) {
    return 'И ещё: имя совпадает с твоим контактом $shown';
  }

  @override
  String get commonBack => 'Назад';

  @override
  String get archivedArchived => 'Архив';

  @override
  String get archivedCount0 => 'ноль';

  @override
  String get archivedCount1 => 'один';

  @override
  String get archivedCount2 => 'два';

  @override
  String get archivedCount3 => 'три';

  @override
  String get archivedCount4 => 'четыре';

  @override
  String get archivedCount5 => 'пять';

  @override
  String get archivedCount6 => 'шесть';

  @override
  String get archivedCount7 => 'семь';

  @override
  String get archivedCount8 => 'восемь';

  @override
  String get archivedCount9 => 'девять';

  @override
  String get archivedCount10 => 'десять';

  @override
  String get archivedChatRestingHereIt =>
      'Чат отдыхает здесь. Молчит, пока не напишут, а потом возвращается наверх.';

  @override
  String get archivedChatsRestingHere =>
      'Чаты отдыхают здесь. Молчат, пока кто-нибудь не напишет, а потом возвращаются наверх.';

  @override
  String get archivedNothingArchived => 'Архив пуст';

  @override
  String get archivedArchivedChatsAreStill =>
      'Чаты в архиве по-прежнему под сквозным шифрованием';

  @override
  String get archivedUnarchive => 'Вернуть из архива';

  @override
  String get avatarPickerThePeopleYouMessage =>
      'Те, с кем ты переписываешься, тоже это видят';

  @override
  String get avatarPickerBackToYourInitial => 'вернуть инициал';

  @override
  String get avatarPickerThatOneIsYours => 'это твоё';

  @override
  String get avatarPickerPickAFace => 'Выбери лицо';

  @override
  String get commonSave => 'Сохранить';

  @override
  String get backupPassphraseMustBeAt =>
      'парольная фраза должна быть не короче 6 символов';

  @override
  String get backupPassphrasesDonTMatch => 'парольные фразы не совпадают';

  @override
  String get backupBackupSavedKeepThe =>
      'Резервная копия сохранена · береги парольную фразу';

  @override
  String get backupKryfoBackup => 'Резервная копия kryfo';

  @override
  String get backupYourEncryptedKryfoBackup =>
      'Твоя зашифрованная резервная копия kryfo. Береги и этот файл, И свою парольную фразу — для восстановления нужны оба.';

  @override
  String get backupBackUpKryfo => 'Резервная копия kryfo';

  @override
  String get backupBackUp => 'Создать копию';

  @override
  String get backupACopyToKeep =>
      'Копия на всякий случай. Этот телефон работает как прежде.';

  @override
  String get backupMoveToAnotherDevice => 'Перенос на другое устройство';

  @override
  String get backupTheFileTakesThis =>
      'Файл забирает этот профиль с собой. Как только он создан, этот телефон перестаёт работать: сюда больше ничего не приходит, и ничто отправленное отсюда ни до кого не доходит.';

  @override
  String get backupOneEncryptedFileYour =>
      'Один зашифрованный файл: твой профиль, контакты, все сообщения, все фото, голосовые и файлы. Импортируй его на другом устройстве с парольной фразой. До тех пор ещё можно передумать и остаться на этом телефоне.';

  @override
  String get backupOneEncryptedFileYourIdentityYour =>
      'Один зашифрованный файл: твой профиль, контакты, все сообщения, все фото, голосовые и файлы, которые сейчас есть на этом телефоне. Всего, что будет написано после сегодняшнего дня, в нём нет, так что делай новую копию, когда это важно. Для восстановления нужны и файл, и парольная фраза.';

  @override
  String get backupPassphrase => 'Парольная фраза';

  @override
  String get backupConfirmPassphrase => 'Повтори парольную фразу';

  @override
  String backupWriting(Object progress) {
    return 'запись… $progress';
  }

  @override
  String get backupCreating => 'создание…';

  @override
  String get backupMakeTheFileAnd => 'Создать файл и перенести';

  @override
  String get backupCreateBackup => 'Создать копию';

  @override
  String get blockedBlocked => 'Заблокированные';

  @override
  String get blockedNoOneIsBlocked => 'Никто не заблокирован';

  @override
  String get commonUnblock => 'Разблокировать';

  @override
  String get bridgesThatWasNotIt => 'Не то. Вот новая.';

  @override
  String get bridgesGotBridgesSaveTo =>
      'Мосты получены · сохрани, чтобы использовать';

  @override
  String get bridgesConnected => 'Подключено';

  @override
  String get bridgesNotThroughYetTor =>
      'Пока не пробились. Tor продолжает попытки';

  @override
  String get bridgesBridges => 'Мосты';

  @override
  String get bridgesTorIsBlockedWhere => 'Tor заблокирован там, где ты?';

  @override
  String get bridgesBridgesDisguiseYourConnection =>
      'Мосты маскируют твоё подключение, чтобы оно могло пробиться наружу. Выбери способ входа, сохрани — и tor переподключится через него.';

  @override
  String get bridgesBridgesOnlyChangeHow =>
      'Мосты меняют только то, как подключается tor, а ты сейчас не в режиме Onion. Всё, что ты здесь настроишь, сохранится, просто ничего не будет делать, пока ты не вернёшься в этот режим.';

  @override
  String get bridgesFromTheTorProject => 'От проекта tor';

  @override
  String get bridgesNoise => 'шум';

  @override
  String get bridgesGood => 'хорошая';

  @override
  String get bridgesMakesTorTrafficLook =>
      'Делает трафик tor ни на что конкретное не похожим. Лучший выбор для большинства заблокированных сетей. Решаешь капчу — получаешь несколько строк.';

  @override
  String get bridgesPrivateBridge => 'Частный мост';

  @override
  String get bridgesALineFromA => 'Строка от друга';

  @override
  String get bridgesWhateverTheLineSays => 'Как указано в строке';

  @override
  String get bridgesDepends => 'по-разному';

  @override
  String get bridgesGotABridgeLine =>
      'Есть строка моста от того, кому доверяешь, или с bridges.torproject.org? Вставь её сюда. Только строки obfs4: другие kryfo пока не понимает.';

  @override
  String get bridgesPasteFromClipboard => 'Вставить из буфера';

  @override
  String get bridgesUseBridges => 'Использовать мосты';

  @override
  String get bridgesNoLinesYet => 'Строк пока нет';

  @override
  String bridges1LineSaved(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString строки сохранено',
      many: '$countString строк сохранено',
      few: '$countString строки сохранены',
      one: '$countString строка сохранена',
    );
    return '$_temp0';
  }

  @override
  String get bridgesRestartingTor => 'Перезапуск tor…';

  @override
  String bridgesFindingABridgeS(Object elapsed) {
    return 'Ищем мост… $elapsed с';
  }

  @override
  String bridgesStillTryingS(Object elapsed) {
    return 'Всё ещё пробуем… $elapsed с';
  }

  @override
  String get bridgesApplying => 'Применяем…';

  @override
  String get bridgesSaveAndReconnect => 'Сохранить и переподключить';

  @override
  String get bridgesWhatABridgeIs => 'Что такое мост';

  @override
  String get bridgesATorEntryPoint =>
      'Точка входа в tor, которую никто не публиковал. К ней подключаются через обёртку, чтобы соединение не было похоже на tor. Дальше маршрут — обычные три узла.';

  @override
  String get bridgesLooksLike => 'Похоже на';

  @override
  String get bridgesSpeed => 'скорость';

  @override
  String get bridgesGetBridges => 'Получить мосты';

  @override
  String get bridgesAskTheTorProject =>
      'Запроси мосты прямо у проекта tor. Нужно решить головоломку, чтобы боты не выгребли весь запас.';

  @override
  String get bridgesTypeWhatYouSee => 'введи то, что видишь. можно строчными.';

  @override
  String get bridgesThisOneRequestDoes =>
      'Этот единственный запрос идёт не через tor — иначе никак, ведь не работает как раз tor. Тот, кто управляет твоей сетью, увидит, что ты обращаешься к проекту tor. Если там, где ты, уже одно это — проблема, возьми мосты в другом месте и вставь их ниже.';

  @override
  String get bridgesCouldNotDrawThe => 'Не удалось показать головоломку';

  @override
  String get bridgesAnswer => 'Ответ';

  @override
  String get bridgesAsking => 'Запрашиваем…';

  @override
  String get bridgesRequestBridges => 'Запросить мосты';

  @override
  String get bridgesDifferentPuzzle => 'Другая головоломка';

  @override
  String get cameraNoCameraOnThis => 'На этом телефоне нет камеры';

  @override
  String get cameraCameraNotAvailable => 'Камера недоступна';

  @override
  String get cameraCameraPermissionIsOff =>
      'Нет доступа к камере · нажми, чтобы попробовать снова';

  @override
  String get cameraCouldNotStripThat =>
      'Не удалось очистить фото, оно отброшено';

  @override
  String get cameraNoPhotoCameOut => 'Фото не получилось';

  @override
  String get cameraCouldNotStartRecording => 'Не удалось начать запись';

  @override
  String get cameraTheRecordingWasLost => 'Запись потеряна';

  @override
  String get cameraACopyIsIn => 'Копия есть в галерее';

  @override
  String get cameraCouldNotSaveA =>
      'Не удалось сохранить копию на этом телефоне';

  @override
  String get cameraTooLongForA =>
      'Слишком длинно для сообщения · максимум 8 МБ';

  @override
  String get cameraNeverSavedToYour => 'Никогда не сохраняется в галерею';

  @override
  String get cameraNoExifNeverSaved =>
      'Без exif, никогда не сохраняется в галерею';

  @override
  String get cameraRec => 'Запись';

  @override
  String get cameraSwitchCamera => 'сменить камеру';

  @override
  String cameraClipSMb(Object secs, Object mb) {
    return 'Клип · $secs с · $mb МБ';
  }

  @override
  String get cameraStopRecording => 'Остановить запись';

  @override
  String get cameraStartRecording => 'Начать запись';

  @override
  String get cameraTakeAPhoto => 'Сделать фото';

  @override
  String get cameraKeepACopy => 'сохранить копию';

  @override
  String get cameraUseThis => 'Использовать';

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
      'ты не в сети · отправится само, когда подключишься';

  @override
  String get chatStillConnectingToTor =>
      'ещё подключаемся к tor · отправится само';

  @override
  String chatS(Object seconds) {
    return '$seconds с';
  }

  @override
  String chatM(Object seconds) {
    return '$seconds мин';
  }

  @override
  String chatH(Object seconds) {
    return '$seconds ч';
  }

  @override
  String chatD(Object seconds) {
    return '$seconds д';
  }

  @override
  String get chat0s => '0 с';

  @override
  String chatHM(Object h, Object m) {
    return '$h ч $m мин';
  }

  @override
  String chatMS(Object m, Object s) {
    return '$m мин $s с';
  }

  @override
  String chatS2(Object s) {
    return '$s с';
  }

  @override
  String get chatNewMessages => 'Новые сообщения';

  @override
  String get chatUnsave => 'Убрать из сохранённых';

  @override
  String get chatForward => 'Переслать';

  @override
  String get commonShare => 'Поделиться';

  @override
  String get commonCopied => 'Скопировано';

  @override
  String get commonCopy => 'Копировать';

  @override
  String get chatUnpin => 'Открепить';

  @override
  String get chatPin => 'Закрепить';

  @override
  String get chatStopSending => 'Остановить отправку';

  @override
  String get chatUnsend => 'Отозвать';

  @override
  String get commonEdit => 'Изменить';

  @override
  String get chatYou => 'Ты';

  @override
  String get chatUnsendMessage => 'Отозвать сообщение';

  @override
  String get chatItDisappearsWithNo =>
      'Оно исчезнет без следа. Это нельзя отменить.';

  @override
  String chatThisChatHasPins(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'В этом чате уже $countString закреплённого сообщения',
      many: 'В этом чате уже $countString закреплённых сообщений',
      few: 'В этом чате уже $countString закреплённых сообщения',
      one: 'В этом чате уже $countString закреплённое сообщение',
    );
    return '$_temp0';
  }

  @override
  String get chatUnpinThisMessage => 'Открепить это сообщение?';

  @override
  String get chatPinThisMessage => 'Закрепить это сообщение?';

  @override
  String get chatItLeavesThePinned => 'Оно уйдёт из закреплённых у вас обоих.';

  @override
  String get chatItGoesUnderThe =>
      'Оно появится среди закреплённых вверху чата — у вас обоих.';

  @override
  String get chatPinIt => 'Закрепить';

  @override
  String get chatNotNow => 'Не сейчас';

  @override
  String get chatEditMessage => 'Изменить сообщение';

  @override
  String get chat30Seconds => '30 секунд';

  @override
  String get chat1Minute => '1 минута';

  @override
  String get chat5Minutes => '5 минут';

  @override
  String get chat1Hour => '1 час';

  @override
  String get chat24Hours => '24 часа';

  @override
  String get chatGhostTimer => 'Исчезающие сообщения';

  @override
  String get chatHowLongBeforeSent =>
      'Через сколько отправленные сообщения исчезнут?';

  @override
  String get chatCamera => 'Камера';

  @override
  String get chatNoExifNeverSaved =>
      'Без exif, никогда не сохраняется в галерею';

  @override
  String get chatGallery => 'Галерея';

  @override
  String get chatVideo => 'Видео';

  @override
  String get chatGifFromPhone => 'GIF с телефона';

  @override
  String get chatFile2 => 'Файл';

  @override
  String get chatAFewSeconds => 'Несколько секунд';

  @override
  String get chatUnderAMinute => 'Меньше минуты';

  @override
  String chatRoughlyMin(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Примерно $countString мин',
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
  String get chatSendThis => 'Отправить файл?';

  @override
  String chatOverTor(Object humanBytes, Object wireEstimate) {
    return '$humanBytes · $wireEstimate через tor';
  }

  @override
  String get chatBigFilesGoOut =>
      'Большие файлы уходят маленькими зашифрованными частями, поэтому это небыстро. Не закрывай приложение, и отправка продолжится.';

  @override
  String get chatSendIt => 'Отправить';

  @override
  String get chatCouldNotReadThat => 'Не удалось прочитать файл';

  @override
  String get chatFileTooBig8 => 'Файл слишком большой · максимум 8 МБ';

  @override
  String get chatCouldNotCleanThat => 'Не удалось очистить видео';

  @override
  String get chatCouldNotCleanThatPictureSend =>
      'Не удалось очистить картинку · отправь её как фото';

  @override
  String get chatGifTooBig8 => 'GIF слишком большой · максимум 8 МБ';

  @override
  String get chatCouldNotCleanThatGif => 'Не удалось очистить GIF';

  @override
  String get chatTorIsNotUp => 'Tor ещё не запущен · отправляем без превью';

  @override
  String get chatCouldnTReachIt =>
      'Не удалось достучаться · отправляем без превью';

  @override
  String get chatNoTitleCameBack =>
      'Заголовок не пришёл · отправляем без превью';

  @override
  String get chatCouldnTFetchIt =>
      'Не удалось загрузить · отправляем без превью';

  @override
  String get chatNoSignalSessionRe => 'Нет сессии Signal — свяжись заново';

  @override
  String get chatMessageUnavailable => 'Сообщение недоступно';

  @override
  String get chatYou2 => 'ты';

  @override
  String get chatThem => 'собеседник';

  @override
  String get chatVoiceMessage => 'голосовое сообщение';

  @override
  String get chatQuotedPhoto => 'фото';

  @override
  String get chatViewContact => 'Открыть контакт';

  @override
  String get chatSharedPhotos => 'Общие фото';

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
  String get chatUnmuteNotifications => 'Включить уведомления';

  @override
  String get chatMuteNotifications => 'Отключить уведомления';

  @override
  String get chatArchiveChat => 'Архивировать чат';

  @override
  String get chatWallpaper => 'Обои';

  @override
  String get chatClearConversation => 'Очистить переписку';

  @override
  String get chatNoteOnThisContact => 'Заметка о контакте';

  @override
  String get chatPinToTop => 'Закрепить наверху';

  @override
  String get chatBlockContact => 'Заблокировать контакт';

  @override
  String get chatUnpinned => 'Откреплено';

  @override
  String get chatPinnedToTop => 'Закреплено наверху';

  @override
  String get chatJustForYouNever =>
      'Только для тебя. Никуда не отправляется и никогда не покидает этот телефон.';

  @override
  String get chatAQuietReminder => 'Тихое напоминание…';

  @override
  String get chatNoteSaved => 'Заметка сохранена';

  @override
  String get chatClearThisConversation => 'Очистить эту переписку?';

  @override
  String get chatEveryMessageHereIs =>
      'Все сообщения здесь будут стёрты с этого телефона. Очищается только твоя копия — устройство собеседника это не затрагивает.';

  @override
  String get chatClear => 'Очистить';

  @override
  String get chatBlockThisContact => 'Заблокировать этот контакт?';

  @override
  String get chatTheirMessagesStopArriving =>
      'Сообщения этого контакта перестанут приходить, и он пропадёт из твоих чатов. Ему об этом никогда не сообщат. Разблокировать можно в любой момент в настройках.';

  @override
  String get commonBlock => 'Заблокировать';

  @override
  String get chatSaved => 'Сохранено';

  @override
  String get chatRemovedFromSaved => 'Убрано из сохранённых';

  @override
  String get chatForwardTo => 'Кому переслать';

  @override
  String get chatNoContactsToForward => 'Некому пересылать';

  @override
  String get chatToday => 'сегодня';

  @override
  String get chatYesterday => 'вчера';

  @override
  String get chatThisMessageCanT => 'Это сообщение нельзя показать';

  @override
  String get chatJumpToTheNewest => 'К новым сообщениям';

  @override
  String get chatBuildingAPrivateRoute =>
      'Строим приватный маршрут · первое подключение самое долгое, потом будет быстро. Всё, что ты отправишь сейчас, встанет в очередь и доставится само.';

  @override
  String get chatLooksSafeNothingSuspicious =>
      'Выглядит безопасно · в первом сообщении ничего подозрительного';

  @override
  String get chatTheNextPhotoYou =>
      'Следующее фото, которое ты отправишь, откроется защищённым · собеседник не сможет сделать скриншот';

  @override
  String get chatPhotoProtectionOff => 'Защита фото выключена';

  @override
  String get chatAcceptToReplyThey =>
      'Прими, чтобы ответить, — до этого собеседник может прислать ещё только одно сообщение.';

  @override
  String chatIntroducedYouAcceptTo(Object introducer) {
    return 'Вас познакомили: $introducer. Прими, чтобы ответить.';
  }

  @override
  String chatIntroducedYouSayHello(Object vouchNames) {
    return 'Вас познакомили: $vouchNames. Поздоровайся — у собеседника тоже есть твоя карточка.';
  }

  @override
  String get chatIntroduceTo => 'Познакомить с...';

  @override
  String get chatAcceptThemFirst => 'Сначала прими запрос';

  @override
  String get chatMessageRequest => 'Запрос на переписку';

  @override
  String get chatTheyNeedToAccept =>
      'Собеседник должен принять запрос, чтобы вы могли продолжить общение.';

  @override
  String get chatWaitingForThemTo =>
      'Ждём, когда собеседник примет твой запрос';

  @override
  String get chatYouBlockedThisContact => 'Этот контакт заблокирован';

  @override
  String get chatSupporter => 'Сторонник';

  @override
  String get chatEncryptedViaRelay => 'Зашифровано · через ретранслятор';

  @override
  String get chatEncryptedDirect => 'Зашифровано · напрямую';

  @override
  String get chatEncryptedOverTor => 'Зашифровано · через tor';

  @override
  String get chatSearchThisChat => 'Поиск по чату';

  @override
  String get chatContactOptions => 'Действия с контактом';

  @override
  String get commonClose => 'Закрыть';

  @override
  String get chatFindInConversation => 'Найти в переписке';

  @override
  String get chatNoMatches => 'Ничего не найдено';

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
      other: '*$posString* из $countString совпадения',
      many: '*$posString* из $countString совпадений',
      few: '*$posString* из $countString совпадений',
      one: '*$posString* из $countString совпадения',
    );
    return '$_temp0';
  }

  @override
  String get chatPreviousMatch => 'Предыдущее';

  @override
  String get chatNextMatch => 'Следующее';

  @override
  String get chatPhotoUnavailable => 'Фото недоступно';

  @override
  String get chatDelivered => 'Доставлено';

  @override
  String get chatEdited => 'Изменено';

  @override
  String get chatWaitingForThemToComeOnline =>
      'Ждём, когда собеседник появится в сети или добавит тебя в ответ';

  @override
  String get chatFailedTapToRetry => 'Ошибка · нажми, чтобы повторить';

  @override
  String get chatReplyingTo => 'Ответ собеседнику';

  @override
  String get chatReplyingToYourself => 'Ответ себе';

  @override
  String get chatReply => 'Ответить';

  @override
  String get chatSayHi => 'Поздоровайся.';

  @override
  String get chatJustTheTwoOf => 'Только вы двое, со сквозным шифрованием.';

  @override
  String get chatMicPermissionNeeded => 'Нужен доступ к микрофону';

  @override
  String get chatTheMicWouldNot => 'Микрофон не включился. Попробуй снова';

  @override
  String get chatReleaseToCancel => 'Отпусти, чтобы отменить';

  @override
  String get chatVoiceHiddenSlideTo => 'Голос скрыт · смахни для отмены';

  @override
  String get chatSlideToCancel => 'Смахни для отмены';

  @override
  String get chatGhostMode => 'Исчезающие сообщения';

  @override
  String chatMessagesBurnAfter(Object humanBurn) {
    return 'исчезают через $humanBurn';
  }

  @override
  String get chatTimedMessages => 'Исчезающие сообщения';

  @override
  String get chatOpenTheCamera => 'Открыть камеру';

  @override
  String get chatAttachAPhoto => 'Прикрепить фото';

  @override
  String get chatMessage => 'Сообщение';

  @override
  String get chatDisguiseVoice => 'Изменить голос';

  @override
  String get commonSend => 'Отправить';

  @override
  String get chatNoPhotosInThis => 'В этом чате пока нет фото';

  @override
  String get chatSendPhoto => 'Отправить фото';

  @override
  String get chatAddACaption => 'Добавь подпись…';

  @override
  String get chatSecurityCodeChanged => 'Код безопасности изменился';

  @override
  String chatMayHaveReinstalledOr(Object peerName) {
    return 'Контакт $peerName мог переустановить приложение — или кто-то выдаёт себя за него. Сверь коды безопасности, чтобы убедиться.';
  }

  @override
  String get chatOk => 'Ок';

  @override
  String get chatVerify => 'Проверить';

  @override
  String get cleanKryfoCanTClean => 'Kryfo пока не умеет очищать такие файлы.';

  @override
  String get cleanThisIsAMotion => 'Это фото с движением.';

  @override
  String get cleanThisPictureIsToo =>
      'Эта картинка слишком большая, чтобы очистить её здесь.';

  @override
  String get cleanThisFileIsDamaged => 'Этот файл повреждён или обрезан.';

  @override
  String get cleanKryfoCouldNotMake => 'Kryfo не удалось очистить этот файл.';

  @override
  String get cleanNotEnoughRoomOn => 'На телефоне не хватает места.';

  @override
  String get cleanKryfoCouldNotOpen => 'Kryfo не удалось открыть этот файл.';

  @override
  String get cleanItCleansJpegPng =>
      'Очищаются JPEG, PNG, WebP, HEIC, AVIF, GIF, MP4 и MOV. Ничего не изменено.';

  @override
  String get cleanItHoldsAShort =>
      'Рядом с картинкой в нём хранится короткое видео, а эту часть kryfo пока очищать не умеет. Выключи движение в камере или отправь скриншот.';

  @override
  String get cleanPicturesOver64Mb =>
      'Картинки больше 64 МБ на телефоне не очищаются. Ничего не изменено.';

  @override
  String get cleanKryfoCouldNotRead =>
      'Kryfo не удалось дочитать файл до конца, так что чистым его не назвать. Копия не создана.';

  @override
  String get cleanSomethingInsideIsOf =>
      'Внутри есть данные, которые kryfo не умеет удалять, поэтому копия не создана.';

  @override
  String get cleanFreeSomeSpaceAnd =>
      'Освободи место и попробуй снова. Ничего не изменено.';

  @override
  String get cleanTheAppThatShared =>
      'Возможно, приложение, которое передало файл, забрало его обратно. Попробуй поделиться им ещё раз.';

  @override
  String get cleanNoAppOnThis =>
      'Ни одно приложение на этом телефоне не приняло файл.';

  @override
  String get cleanCouldNotSaveIt =>
      'Не удалось сохранить. Проверь, есть ли место на телефоне.';

  @override
  String get cleanTheOriginalIsGone =>
      'Оригинал удалён. Чистая копия осталась.';

  @override
  String get cleanAndroidWouldNotDelete =>
      'Android не дал удалить оригинал. Удали его из галереи вручную.';

  @override
  String get cleanCleanCopy => 'Чистая копия';

  @override
  String get cleanShareCleanCopy => 'Поделиться чистой копией';

  @override
  String get cleanSaveToGallery => 'Сохранить в галерею';

  @override
  String get commonStop => 'Остановить';

  @override
  String get cleanReadingTheFile => 'Читаем файл';

  @override
  String get cleanCleaning => 'Очищаем';

  @override
  String cleanOf(Object prettySize, Object prettySize2) {
    return '$prettySize из $prettySize2';
  }

  @override
  String get cleanEverythingStaysOnThis => 'Всё остаётся на этом телефоне.';

  @override
  String get cleanAlreadyClean => 'Уже чисто.';

  @override
  String get cleanClean => 'Чисто.';

  @override
  String get cleanThereWasNothingTo => 'Искать было нечего.';

  @override
  String get cleanNothingLeftToFind => 'Больше нечего искать.';

  @override
  String get cleanSameVideoSameQuality => 'То же видео, то же качество';

  @override
  String get cleanSamePictureSameQuality => 'Та же картинка, то же качество';

  @override
  String cleanRemoved(Object label) {
    return '$label: удалено';
  }

  @override
  String get cleanRemoved2 => 'УДАЛЕНО';

  @override
  String get cleanWithTheLocationInside =>
      'и в нём есть местоположение. Любой, к кому он попадёт, узнает твою улицу.';

  @override
  String get cleanWithEverythingItKnew =>
      'и в нём по-прежнему всё, что он знал.';

  @override
  String get cleanOriginal => 'ОРИГИНАЛ';

  @override
  String get cleanClean2 => 'ЧИСТАЯ';

  @override
  String get cleanSavedToYourGallery => 'Сохранено в галерею.';

  @override
  String cleanTheOriginalIsStill(Object what) {
    return 'Оригинал тоже никуда не делся, $what';
  }

  @override
  String cleanTheOriginalIsStillWhereIt(Object what) {
    return 'Оригинал по-прежнему на месте, $what Отсюда kryfo не может его удалить, так что удали его в приложении, откуда он пришёл.';
  }

  @override
  String get cleanDeleteTheOriginal => 'Удалить оригинал';

  @override
  String get cleanKeepBoth => 'Оставить оба';

  @override
  String get commonDone => 'Готово';

  @override
  String get cleanAndroidWillAskYou => 'ANDROID ПОПРОСИТ ПОДТВЕРДИТЬ';

  @override
  String get contactYourNameForThem => 'Имя контакта';

  @override
  String get contactStaysOnThisPhone =>
      'Остаётся на этом телефоне. Собеседник его никогда не увидит.';

  @override
  String get contactClear => 'Очистить';

  @override
  String get contactMessage => 'Написать';

  @override
  String get contactKeysVerified => 'Ключи проверены';

  @override
  String get contactVerifyKeys => 'Проверить ключи';

  @override
  String get contactVouches => 'Рекомендации';

  @override
  String get contactUnmute => 'Включить звук';

  @override
  String get contactMute => 'Без звука';

  @override
  String get contactUnpin => 'Открепить';

  @override
  String get contactPinToTop => 'Закрепить наверху';

  @override
  String get contactArchive => 'Архивировать';

  @override
  String get contactOutOfTheList =>
      'Скрыт из списка, пока собеседник не напишет снова';

  @override
  String contactBlock(Object name) {
    return 'Заблокировать контакт $name?';
  }

  @override
  String get contactTheirMessagesStopArriving =>
      'Сообщения перестанут приходить. Собеседнику об этом не сообщат.';

  @override
  String get contactDeleteChat => 'Удалить чат';

  @override
  String get contactMessagesAndContactGone =>
      'Сообщения и контакт удаляются с этого телефона';

  @override
  String get contactDeleteThisChat => 'Удалить этот чат?';

  @override
  String get contactEveryMessageAndThe =>
      'Все сообщения и контакт удаляются с этого телефона. Собеседнику ничего не отправляется.';

  @override
  String get commonDelete => 'Удалить';

  @override
  String get contactDeleted => 'Удалено';

  @override
  String get contactToday => 'сегодня';

  @override
  String contactD(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дня',
      many: '$count дней',
      few: '$count дня',
      one: '$count день',
    );
    return '$_temp0';
  }

  @override
  String contactMo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count мес',
      many: '$count мес',
      few: '$count мес',
      one: '$count мес',
    );
    return '$_temp0';
  }

  @override
  String contactY(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count года',
      many: '$count лет',
      few: '$count года',
      one: '$count год',
    );
    return '$_temp0';
  }

  @override
  String get contactVerified => 'Проверен';

  @override
  String get contactChatting => 'Общаетесь';

  @override
  String get contactNothingSharedYet => 'общих медиа пока нет';

  @override
  String contactSharedMedia(Object count) {
    return 'общие медиа · $count';
  }

  @override
  String get donateBitcoin => 'Bitcoin';

  @override
  String get donateText => '₿';

  @override
  String get donateBadgeUnlocks => 'даёт значок';

  @override
  String get donateMonero => 'Monero';

  @override
  String get donateManualNoBadge => 'вручную · без значка';

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
          'Твой прежний платёж в bitcoin найден · значок сторонника открыт',
      'patron': 'Твой прежний платёж в bitcoin найден · значок мецената открыт',
      'guardian':
          'Твой прежний платёж в bitcoin найден · значок хранителя открыт',
      'other':
          'Твой прежний платёж в bitcoin найден · значок сторонника открыт',
    });
    return '$_temp0';
  }

  @override
  String get donateSupport => 'Поддержать';

  @override
  String get donateKeepKryfo => 'Сохрани kryfo *независимым*';

  @override
  String get donateNoAdsNoInvestors =>
      'Без рекламы, без инвесторов, ничего не продаём. Живёт на то, что дают сторонники.';

  @override
  String get donateBackItAnonymouslyBadge =>
      'Поддержи анонимно. Значок — по желанию.\n*Приватность никогда не бывает платной.*';

  @override
  String donateAddressCheckItAgainst(Object coinName) {
    return 'Адрес $coinName · сверь его с кошельком';
  }

  @override
  String get donateAddressCopiedClearsIn =>
      'Адрес скопирован · очистится через 60 с';

  @override
  String get donateCopyAddress => 'Копировать адрес';

  @override
  String get donateBitcoinIsVerifiedBy =>
      'Платежи в bitcoin проверяет наш собственный узел, поэтому значок откроется сам, как только платёж придёт.';

  @override
  String get donateWeCanTVerify =>
      'мы не можем проверить эту сеть, не спрашивая о тебе сторонний сервис, поэтому не проверяем. отправляй, если хочешь. значок это не откроет.';

  @override
  String get donateBitcoinBadgesNeedOnion =>
      'Для значков за bitcoin нужен режим Onion';

  @override
  String get donateSwitchToOnion => 'Перейти на Onion';

  @override
  String get donatePayWithBitcoin => 'Оплатить bitcoin  →';

  @override
  String get donateBadgesStartAt20 => 'Значки — от \$20';

  @override
  String get donateReachingThePaymentService =>
      'Связываемся с платёжным сервисом через tor…';

  @override
  String get donateThisCanTakeUp => 'Это может занять до минуты';

  @override
  String donateSThisCanTake(Object waited) {
    return '$waited с · это может занять до минуты';
  }

  @override
  String get donateUseTheAddressInstead => 'Использовать адрес';

  @override
  String get donateThePaymentServiceIs =>
      'Платёжный сервис — это onion-адрес, и достучаться до него можно только в режиме Onion. Ничего не отправлено.';

  @override
  String get donateTorWasSlowTo =>
      'Tor слишком долго добирался до платёжного сервиса. Можно отправить пожертвование на адрес ниже — просто значок не откроется автоматически. Чтобы получить значок, попробуй позже.';

  @override
  String get donateThePaymentServiceIsHavingTrouble =>
      'У платёжного сервиса сейчас проблемы. Можно всё равно отправить пожертвование на адрес ниже — просто значок не откроется автоматически. Чтобы получить значок, попробуй позже.';

  @override
  String get commonTryAgain => 'Повторить';

  @override
  String donateBtc(Object btc) {
    return '$btc BTC';
  }

  @override
  String donateSendExactlyThisAmount(Object fmtLeft) {
    return 'Отправь ровно эту сумму · истекает через $fmtLeft';
  }

  @override
  String get donateOpenWallet => 'открыть кошелёк';

  @override
  String get donateThisScreenUpdatesItself =>
      'Экран обновится сам, как только платёж будет замечен.\nНе закрывай его — ничего не сохраняется, ничто тебя не идентифицирует.';

  @override
  String get donateWatchingTheChainFor =>
      'Следим за блокчейном, ждём твой платёж';

  @override
  String get donateThisInvoiceExpired => 'Срок счёта истёк';

  @override
  String get donateInvoicesTimeOutIf =>
      'У счетов есть срок. Если платёж уже отправлен, не закрывай экран: какое-то время мы будем раз в минуту заново спрашивать сервис, и ещё раз — когда ты в следующий раз откроешь «Поддержать». Новый счёт можно создать в любой момент.';

  @override
  String get donateNewInvoice => 'Новый счёт';

  @override
  String get donateIPaidCheckAgain => 'Оплачено, проверить снова';

  @override
  String get donatePaymentConfirmed => 'Платёж подтверждён';

  @override
  String get donateThankYouForKeeping =>
      'Спасибо, что помогаешь kryfo оставаться независимым.';

  @override
  String donateVerifiedOnChainYou(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter':
          'проверено в блокчейне — теперь ты сторонник. Этого у тебя никто не отнимет.',
      'patron':
          'проверено в блокчейне — теперь ты меценат. Этого у тебя никто не отнимет.',
      'guardian':
          'проверено в блокчейне — теперь ты хранитель. Этого у тебя никто не отнимет.',
      'other':
          'проверено в блокчейне — теперь ты сторонник. Этого у тебя никто не отнимет.',
    });
    return '$_temp0';
  }

  @override
  String get donateWearMyBadge => 'носить мой значок';

  @override
  String get donateJustGladToHelp => 'Просто помогаю';

  @override
  String get gettingMessagesGettingMessages => 'Получение сообщений';

  @override
  String get gettingMessagesHowNewMessagesReach =>
      'Как новые сообщения попадают на этот телефон. Можно поменять в любой момент.';

  @override
  String get gettingMessagesAlwaysOn => 'Всегда на связи';

  @override
  String get gettingMessagesMostPrivate => 'самый приватный';

  @override
  String get gettingMessagesMessagesArriveInstantlyNothing =>
      'Сообщения приходят сразу. Ничто не выходит за пределы Tor. Батарею расходует сильнее всего.';

  @override
  String get gettingMessagesCheckIns => 'Проверки';

  @override
  String get gettingMessagesLightest => 'самый лёгкий';

  @override
  String get gettingMessagesKryfoLooksForMessages =>
      'Kryfo проверяет сообщения каждые 15 минут. Бережёт батарею, но сообщения могут опаздывать.';

  @override
  String get gettingMessagesOnTheLockScreen => 'На экране блокировки';

  @override
  String get gettingMessagesHideMessagePreview => 'Скрыть превью сообщений';

  @override
  String get gettingMessagesAGenericAlertWith =>
      'Обычное уведомление без отправителя и текста сообщения';

  @override
  String get gettingMessagesShowsMessageTextIn =>
      'Текст сообщений виден в уведомлениях, даже когда kryfo заблокирован.';

  @override
  String get gettingMessagesWhenThePhoneSits =>
      'Когда телефон долго лежит без движения, Android делает проверки реже. Строка выше показывает реальную последнюю. Пока kryfo открыт, он остаётся на связи.';

  @override
  String get groupChatJumpToTheNewest => 'К новым сообщениям';

  @override
  String get groupChatBlockedEverywhere => 'Заблокирован везде';

  @override
  String get groupChatYou => 'ты';

  @override
  String get groupChatVoiceMessage => 'голосовое сообщение';

  @override
  String get groupChatQuotedPhoto => 'фото';

  @override
  String get groupChatMessageUnavailable => 'Сообщение недоступно';

  @override
  String get groupChatTorIsNotUp =>
      'Tor ещё не запущен · отправляем без превью';

  @override
  String get groupChatCouldnTReachIt =>
      'не удалось достучаться · отправляем без превью';

  @override
  String get groupChatNoTitleCameBack =>
      'Заголовок не пришёл · отправляем без превью';

  @override
  String get groupChatCouldnTFetchIt =>
      'не удалось загрузить · отправляем без превью';

  @override
  String get groupChatCamera => 'Камера';

  @override
  String get groupChatGallery => 'Галерея';

  @override
  String get groupChatVideo => 'Видео';

  @override
  String get groupChatGifFromPhone => 'GIF с телефона';

  @override
  String get groupChatFile => 'Файл';

  @override
  String get groupChatCouldNotReadThat => 'Не удалось прочитать файл';

  @override
  String get groupChatGifTooBig8 => 'GIF слишком большой · максимум 8 МБ';

  @override
  String get groupChatCouldNotCleanThat => 'Не удалось очистить GIF';

  @override
  String get groupChatFileTooBig8 => 'Файл слишком большой · максимум 8 МБ';

  @override
  String get groupChatCouldNotCleanThatVideo => 'Не удалось очистить видео';

  @override
  String get groupChatCouldNotCleanThatPictureSend =>
      'Не удалось очистить картинку · отправь её как фото';

  @override
  String get groupChat30Seconds => '30 секунд';

  @override
  String get groupChat1Minute => '1 минута';

  @override
  String get groupChat5Minutes => '5 минут';

  @override
  String get groupChat1Hour => '1 час';

  @override
  String get groupChat24Hours => '24 часа';

  @override
  String get groupChatBurnTimer => 'Исчезающие сообщения';

  @override
  String get groupChatNewMessagesDisappearAfter =>
      'Новые сообщения исчезнут через это время';

  @override
  String get groupChatToday => 'сегодня';

  @override
  String get groupChatYesterday => 'вчера';

  @override
  String get groupChatYou2 => 'Ты';

  @override
  String groupChatThisChatHasPins(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'В этом чате уже $countString закреплённого сообщения',
      many: 'В этом чате уже $countString закреплённых сообщений',
      few: 'В этом чате уже $countString закреплённых сообщения',
      one: 'В этом чате уже $countString закреплённое сообщение',
    );
    return '$_temp0';
  }

  @override
  String get groupChatUnpinThisMessage => 'Открепить это сообщение?';

  @override
  String get groupChatPinThisMessage => 'Закрепить это сообщение?';

  @override
  String get groupChatItLeavesThePinned =>
      'Оно уйдёт из закреплённых у всех здесь.';

  @override
  String get groupChatItGoesUnderThe =>
      'Оно появится среди закреплённых вверху чата — у всех здесь.';

  @override
  String get groupChatUnpin => 'Открепить';

  @override
  String get groupChatPinIt => 'Закрепить';

  @override
  String get groupChatNotNow => 'Не сейчас';

  @override
  String get groupChatSaved => 'Сохранено';

  @override
  String get groupChatRemovedFromSaved => 'Убрано из сохранённых';

  @override
  String get groupChatForwardTo => 'Кому переслать';

  @override
  String get groupChatNoContactsToForward => 'Некому пересылать';

  @override
  String get groupChatEditMessage => 'Изменить сообщение';

  @override
  String get groupChatUnsendMessage => 'Отозвать сообщение';

  @override
  String get groupChatItDisappearsWithNo =>
      'Оно исчезнет без следа. Это нельзя отменить.';

  @override
  String get groupChatUnsend => 'Отозвать';

  @override
  String groupChatThisRoomAndEverything(Object expiryWords) {
    return 'Эта комната и всё в ней исчезнут $expiryWords';
  }

  @override
  String groupChatGhostModeOnBurns(Object fmtBurn) {
    return 'Исчезающие сообщения · исчезают через $fmtBurn';
  }

  @override
  String get groupChatGroupCreatedSayHi => 'Группа создана. Поздоровайся.';

  @override
  String get groupChatNoMessagesYet => 'Сообщений пока нет.';

  @override
  String get groupChatThisMessageCanT => 'Это сообщение нельзя показать';

  @override
  String groupChatS(Object s) {
    return '$s с';
  }

  @override
  String groupChatM(Object s) {
    return '$s мин';
  }

  @override
  String groupChatH(Object s) {
    return '$s ч';
  }

  @override
  String groupChatD(Object s) {
    return '$s д';
  }

  @override
  String groupChatHere(int count, Object time) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$time · здесь $countString человека',
      many: '$time · здесь $countString человек',
      few: '$time · здесь $countString человека',
      one: '$time · здесь $countString человек',
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
      other: '$countString участника',
      many: '$countString участников',
      few: '$countString участника',
      one: '$countString участник',
    );
    return '$_temp0';
  }

  @override
  String get groupChatSearchThisChat => 'Поиск по чату';

  @override
  String groupChatReplyingTo(Object name) {
    return 'Ответ: $name';
  }

  @override
  String get groupChatReplyingToYou => 'Ответ себе';

  @override
  String get groupChatTimedMessages => 'Исчезающие сообщения';

  @override
  String get groupChatOpenTheCamera => 'Открыть камеру';

  @override
  String get groupChatAttachAPhoto => 'Прикрепить фото';

  @override
  String get groupChatMessage => 'Сообщение';

  @override
  String get groupChatDisguiseVoice => 'Изменить голос';

  @override
  String get groupChatSupporter => 'Сторонник';

  @override
  String get groupChatEdited => 'Изменено';

  @override
  String get groupChatTapToRetry => '! нажми для повтора';

  @override
  String get groupChat0s => '0 с';

  @override
  String get groupChatReply => 'Ответить';

  @override
  String get groupChatPin => 'Закрепить';

  @override
  String get groupChatUnsave => 'Убрать из сохранённых';

  @override
  String get groupChatForward => 'Переслать';

  @override
  String get groupInfoGroup => 'группа';

  @override
  String get groupInfoRenameGroup => 'Переименовать группу';

  @override
  String get groupInfoRename => 'Переименовать';

  @override
  String get groupInfoNoContactsToAdd => 'Некого добавить';

  @override
  String get groupInfoCouldNotAdd => 'Не удалось добавить';

  @override
  String groupInfoRemove(Object haloId) {
    return 'Удалить $haloId?';
  }

  @override
  String get groupInfoTheyWillStopReceiving =>
      'Участник перестанет получать сообщения из этой группы.';

  @override
  String get commonRemove => 'Удалить';

  @override
  String get groupInfoClearThisConversation => 'Очистить эту переписку?';

  @override
  String get groupInfoEveryMessageHereIs =>
      'Все сообщения здесь будут стёрты с этого телефона. Очищается только твоя копия, у остальных участников их копии останутся.';

  @override
  String get groupInfoClear => 'Очистить';

  @override
  String get groupInfoConversationCleared => 'Переписка очищена';

  @override
  String get groupInfoLeaveRoom => 'Выйти из комнаты?';

  @override
  String get groupInfoLeaveGroup => 'Выйти из группы?';

  @override
  String get groupInfoEverythingInItIs =>
      'Всё, что в ней есть, сейчас будет стёрто с этого телефона, а твой ключ от неё пропадёт навсегда.';

  @override
  String get groupInfoYouWillStopReceiving =>
      'Ты перестанешь получать сообщения, а остальные участники увидят твой выход.';

  @override
  String get groupInfoLeave => 'Выйти';

  @override
  String get groupInfoGroupInfo => 'О группе';

  @override
  String groupInfo1Member(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString участника',
      many: '$countString участников',
      few: '$countString участника',
      one: '$countString участник',
    );
    return '$_temp0';
  }

  @override
  String get groupInfoAdmin => 'Админ';

  @override
  String get groupInfoMembers2 => 'Участники';

  @override
  String get groupInfoInvite => 'Пригласить';

  @override
  String get commonAdd => 'Добавить';

  @override
  String get groupInfoYou => 'Ты';

  @override
  String get groupInfoRemoveFromGroup => 'Удалить из группы';

  @override
  String get groupInfoWallpaper => 'Обои';

  @override
  String get groupInfoSharedMedia => 'Общие медиа';

  @override
  String get groupInfoClearConversation => 'Очистить переписку';

  @override
  String get groupInfoLeaveRoom2 => 'Выйти из комнаты';

  @override
  String get groupInfoLeaveGroup2 => 'Выйти из группы';

  @override
  String get groupInfoAddMembers => 'Добавить участников';

  @override
  String groupInfoAdd(Object pickedLength) {
    return 'Добавить $pickedLength';
  }

  @override
  String handleYouAre(Object h) {
    return 'Ты — @$h';
  }

  @override
  String get handleHandleDeletedThePage =>
      'Имя пользователя удалено · страницы больше нет';

  @override
  String get handlePublicHandle => 'Публичное имя пользователя';

  @override
  String get handleOptionalYourThreeWords =>
      'Необязательно. Твои три слова работают в любом случае.';

  @override
  String get handleWren => 'wren';

  @override
  String get handleALineAboutYou => 'Пара слов о себе · необязательно';

  @override
  String get handleClaiming => 'Занимаем…';

  @override
  String get handleClaimThisHandle => 'Занять имя пользователя';

  @override
  String get handleAnyoneWithThisLink =>
      'Любой, у кого есть эта ссылка, может начать с тобой приватный чат. В ней только твоё приглашение и больше ничего.';

  @override
  String get handleLinkCopied => 'Ссылка скопирована';

  @override
  String get handleDeleteThisHandle => 'Удалить имя пользователя';

  @override
  String get handleChecking => 'Проверяем…';

  @override
  String get handleAvailable => '✓ свободно';

  @override
  String get handleAlreadyTaken => 'уже занято';

  @override
  String get handleWhatAHandleDoes => 'Зачем нужно имя пользователя';

  @override
  String get handleAnyoneWhoKnowsIt =>
      'Любой, кто его знает, может попросить разрешения написать тебе — в этом и смысл. Страница хранит только твоё приглашение и строку о себе, больше ничего, и не записывает, кто её читает. Удалить её можно в любой момент.';

  @override
  String handleIsNotYoursOn(Object handle) {
    return '@$handle — не твоё имя на этом телефоне';
  }

  @override
  String handleTheRegistryHoldsIt(Object handle) {
    return 'Реестр хранит его под другим ключом — скорее всего, это профиль, который был на этом телефоне до восстановления. Те, кто добавляет @$handle, попадают не к тебе. Отсюда его нельзя ни освободить, ни обновить. Выбери другое имя.';
  }

  @override
  String get handleForgetItOnThis => 'Забыть на этом телефоне';

  @override
  String get homeAddAContact => 'Добавить контакт';

  @override
  String get commonSettings => 'Настройки';

  @override
  String get homeYourKryfo => 'Твой kryfo';

  @override
  String homeDateWeekday(Object weekday) {
    return '$weekday,';
  }

  @override
  String get homeAnHour => 'час';

  @override
  String homeHours(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString часа',
      many: '$countString часов',
      few: '$countString часа',
      one: '$countString час',
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
      other: '$countString минуты',
      many: '$countString минут',
      few: '$countString минуты',
      one: '$countString минуту',
    );
    return '$_temp0';
  }

  @override
  String get homeKryfoIsOffline => 'Kryfo не в сети';

  @override
  String homeTorHasNotBeen(Object howLong) {
    return 'Tor не может подключиться уже $howLong. Пока он не подключится, ничего не придёт и не уйдёт.';
  }

  @override
  String get homeReconnecting => 'Переподключение';

  @override
  String get homeReconnect => 'Переподключить';

  @override
  String get homeWhatIsWrong => 'Что не так';

  @override
  String get homeKryfoWillCheckIn =>
      'Kryfo будет проверять сообщения каждые 15 минут';

  @override
  String get homeYourPhoneKeepsStopping =>
      'Телефон то и дело останавливает kryfo';

  @override
  String get homeItHasClosedKryfo =>
      'Сегодня он закрыл kryfo уже три раза, поэтому сообщения опаздывали или ждали. Проверкам это не мешает: kryfo просыпается каждые 15 минут, а не держит подключение постоянно.';

  @override
  String get homeSwitchToCheckIns => 'Перейти на проверки';

  @override
  String get homeNotNow => 'Не сейчас';

  @override
  String get homeNotificationsAreOff => 'Уведомления выключены';

  @override
  String get homeAndroidIsBlockingThem =>
      'Android их блокирует, поэтому, пока kryfo закрыт, до тебя ничего не доходит. Сообщения всё равно придут, когда ты его откроешь.';

  @override
  String get homeCouldnTOpenIt =>
      'Не открылось. Найди kryfo в настройках телефона';

  @override
  String get homeTurnThemOn => 'Включить';

  @override
  String get homeLeaveThemOff => 'Оставить выключенными';

  @override
  String get homeOurRelayIsQuiet => 'Наш ретранслятор молчит';

  @override
  String get homeRelayModeUsesOnly =>
      'Режим «Ретранслятор» использует только наш собственный ретранслятор, а он сейчас не отвечает. Режим «Быстрый» добавляет к нему публичные ретрансляторы, так что сообщения всё равно дойдут. В любом случае всё остаётся зашифрованным.';

  @override
  String get homeSwitchedToFast => 'Включён режим «Быстрый»';

  @override
  String get homeUseFastMode => 'Включить «Быстрый»';

  @override
  String get homeKeepWaiting => 'Подождать ещё';

  @override
  String get homeNotConnecting => 'Не подключается';

  @override
  String get homeBridgesAreOnAnd =>
      'Мосты включены, а tor всё ещё не может пробиться. Через мосты медленнее, и некоторые из них перестают работать без предупреждения. Если твоя сеть не блокирует tor, напрямую быстрее и надёжнее.';

  @override
  String get homeGoingDirectReconnecting => 'Напрямую · переподключаемся';

  @override
  String get homeTurnBridgesOff => 'Выключить мосты';

  @override
  String get homeStillTrying => 'Всё ещё пробуем';

  @override
  String get homeTorIsNotGetting =>
      'Tor не может пробиться. Некоторые сети блокируют его намеренно. Наш собственный ретранслятор — это одно простое подключение, и обычно он работает и так. Или мосты, но их дольше настраивать.';

  @override
  String get homeSwitchedToRelay => 'Теперь через ретранслятор';

  @override
  String get homeUseOurRelay => 'Наш ретранслятор';

  @override
  String get homeBridges => 'Мосты';

  @override
  String get homeOffline => 'Не в сети';

  @override
  String get homeWaiting => 'В очереди';

  @override
  String get homeNothingWaitingToSend => 'Ничего не ждёт отправки';

  @override
  String homeWaitingSendsWhenYou(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString в очереди · отправка, когда снова будешь в сети',
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
      other: '$countString в очереди · tor ещё подключается',
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
      other: '$countString в очереди · ждём, когда тебя добавят в ответ',
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
          '$countString в очереди · $parkedString — пока тебя не добавят в ответ',
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
      other: '$countString в очереди · отправляем',
    );
    return '$_temp0';
  }

  @override
  String get commonRetry => 'Повторить';

  @override
  String get homeNoKryfosYet => 'Пока ни одного kryfo.';

  @override
  String get homeScanTheirCodeSend =>
      'Отсканируй код, отправь ссылку или введи @имя пользователя, которое тебе дали.';

  @override
  String get homeAddSomeone => 'Добавить человека';

  @override
  String get homeArchived => 'Архив';

  @override
  String home1Chat(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString чата',
      many: '$countString чатов',
      few: '$countString чата',
      one: '$countString чат',
    );
    return '$_temp0';
  }

  @override
  String get homeGroups => 'Группы';

  @override
  String get homeRoom => 'Комната';

  @override
  String get homeNew => 'Создать';

  @override
  String homeRoomExpired(Object expiredRoomName) {
    return '$expiredRoomName · срок комнаты истёк';
  }

  @override
  String get homeMentionedYou => 'Тебя упомянули';

  @override
  String homeMembers(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString участника',
      many: '$countString участников',
      few: '$countString участника',
      one: '$countString участник',
    );
    return '$_temp0';
  }

  @override
  String get homeSupporter => 'Сторонник';

  @override
  String get homeArchivedChats => 'Чаты в архиве';

  @override
  String get homeUnmute => 'Включить звук';

  @override
  String get homeMute => 'Без звука';

  @override
  String get homeArchive => 'Архивировать';

  @override
  String get homeDeleteChat => 'Удалить чат';

  @override
  String get homeMessagesAndContactGone =>
      'Сообщения и контакт удаляются с этого телефона';

  @override
  String get homeDeleteThisChat => 'Удалить этот чат?';

  @override
  String homeEveryMessageWithGoes(Object c) {
    return 'Все сообщения с контактом $c удаляются, и он перестаёт быть твоим контактом. Очищается только этот телефон — у собеседника его копия остаётся. Если он напишет снова, сообщение попадёт в запросы.';
  }

  @override
  String get homeQueued => 'В очереди';

  @override
  String get homeBlocked => 'заблокирован';

  @override
  String get homeRoomInvite => 'Приглашение';

  @override
  String get homeNow => 'сейчас';

  @override
  String homeM(Object inMinutes) {
    return '$inMinutes мин';
  }

  @override
  String homeH(Object inHours) {
    return '$inHours ч';
  }

  @override
  String get homeYesterday => 'вчера';

  @override
  String homeD(Object inDays) {
    return '$inDays д';
  }

  @override
  String get homeNoteToSelf => 'Заметки';

  @override
  String get homeOnlyOnThisPhone => 'Только на этом телефоне';

  @override
  String get homeSaved => 'Сохранённые';

  @override
  String get homeKeptFromEveryChat => 'Из всех чатов';

  @override
  String get homeRequests => 'Запросы';

  @override
  String home1PersonWantsTo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString человека хотят с тобой связаться',
      many: '$countString человек хотят с тобой связаться',
      few: '$countString человека хотят с тобой связаться',
      one: '$countString человек хочет с тобой связаться',
    );
    return '$_temp0';
  }

  @override
  String introduceGotItButCould(Object b, Object c) {
    return '$b — получено, $c — не удалось связаться';
  }

  @override
  String introduceGotItButCouldNotBe(Object c, Object b) {
    return '$c — получено, $b — не удалось связаться';
  }

  @override
  String get introduceCouldNotReachEither =>
      'Не удалось связаться ни с одним из них. Попробуй позже';

  @override
  String introduceIntroduceTo(Object peerName) {
    return 'Познакомить: $peerName и...';
  }

  @override
  String get introduceBothOfThemGet =>
      'Оба получат карточки друг друга. Твои имена контактов никто из них не увидит.';

  @override
  String get introduceNoOneElseTo =>
      'Пока не с кем знакомить. Сначала добавь ещё один контакт.';

  @override
  String get introduceANoteLikeMy =>
      'Заметка, например «мой кузен» — необязательно';

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
      other: 'На этой неделе осталось знакомств: $leftString из $maxString',
      many: 'На этой неделе осталось знакомств: $leftString из $maxString',
      few: 'На этой неделе осталось знакомств: $leftString из $maxString',
      one: 'На этой неделе осталось знакомств: $leftString из $maxString',
    );
    return '$_temp0';
  }

  @override
  String introduceNoIntroductionsLeftNext(Object refillPhrase) {
    return 'Знакомств не осталось. Следующее освободится $refillPhrase';
  }

  @override
  String get introduceIntroduce => 'Познакомить';

  @override
  String get keyVerificationSafetyNumber => 'Код безопасности';

  @override
  String keyVerificationWith(Object peerName) {
    return 'Собеседник: $peerName';
  }

  @override
  String keyVerificationIfSeesTheSame(Object peerName) {
    return 'Если $peerName видит тот же код, ваши сообщения видны только вам двоим. Сверить его лично или по звонку, которому ты доверяешь, — самый надёжный способ убедиться. Но это необязательно: для переписки это никогда не требуется.';
  }

  @override
  String get keyVerificationVerified => 'Проверено';

  @override
  String get keyVerificationMarkAsVerified => 'Отметить как проверенный';

  @override
  String get lockFileThatPasswordDoesNot => 'Этот пароль его не открывает.';

  @override
  String get lockFileThisFileIsDamaged => 'Этот файл повреждён.';

  @override
  String get lockFileThisFileWasLocked =>
      'Этот файл заперт на ключ, а не на пароль.';

  @override
  String get lockFileThisIsNotA => 'Это не запертый файл.';

  @override
  String get lockFileNotEnoughFreeMemory =>
      'Сейчас не хватает свободной памяти.';

  @override
  String get lockFileStopped => 'Остановлено.';

  @override
  String get lockFileItNeedsAPassword => 'Нужен пароль.';

  @override
  String get lockFileKryfoCouldNotRead =>
      'Kryfo не удалось прочитать или записать файл.';

  @override
  String get lockFileCheckCapitalsAndSpaces =>
      'Проверь заглавные буквы и пробелы. Сбросить его не может никто, даже мы.';

  @override
  String get lockFileItMayHaveBeen =>
      'Возможно, он оборвался по дороге. Попроси отправить его ещё раз. Ничего не сохранено.';

  @override
  String get lockFileItOpensWithThe =>
      'Он открывается файлом ключа того, для кого его сделали, в программе age на компьютере. Kryfo открывает те, что заперты паролем.';

  @override
  String get lockFileKryfoOpensFilesLocked =>
      'Kryfo открывает файлы, запертые с помощью age. Обычно их имя заканчивается на .age.';

  @override
  String get lockFileCloseAFewApps =>
      'Закрой несколько приложений и попробуй снова. Для проверки пароля ненадолго нужно несколько сотен мегабайт.';

  @override
  String get lockFileNothingWasSaved => 'Ничего не сохранено.';

  @override
  String get lockFileTypeOneOrLet =>
      'Введи свой или пусть kryfo предложит четыре слова.';

  @override
  String get lockFileTheAppThatHolds =>
      'Возможно, приложение, где он хранится, забрало его обратно. Выбери его снова.';

  @override
  String get lockFileHidePassword => 'Скрыть пароль';

  @override
  String get lockFileShowPassword => 'Показать пароль';

  @override
  String get lockFileChangeFile => 'Другой файл';

  @override
  String get lockFileChange => 'Сменить';

  @override
  String lockFileOf(Object prettySize, Object prettySize2) {
    return '$prettySize из $prettySize2';
  }

  @override
  String get lockFileEverythingStaysOnThis => 'Всё остаётся на этом телефоне.';

  @override
  String get lockFileCouldNotMakeOne => 'Не удалось придумать. Введи свой.';

  @override
  String get lockFileWriteItDownBefore =>
      'Запиши его, прежде чем запирать файл';

  @override
  String get lockFileNoAppOnThis =>
      'Ни одно приложение на этом телефоне не приняло файл.';

  @override
  String get lockFileSaved => 'Сохранено';

  @override
  String get lockFileCouldNotSaveIt =>
      'Не удалось сохранить туда. Попробуй другую папку.';

  @override
  String get lockFileLocked => 'Заперт';

  @override
  String get lockFileLockAFile => 'Запереть файл';

  @override
  String get lockFileMixingThePassword => 'Перемешиваем пароль';

  @override
  String get lockFileLocking => 'Запираем';

  @override
  String get lockFileSaveToFiles => 'Сохранить в «Файлы»';

  @override
  String get lockFileLockFile => 'Запереть файл';

  @override
  String get lockFileOnePassword => 'Один пароль.';

  @override
  String get lockFileNothingElseOpensIt => 'Больше его ничто не откроет.';

  @override
  String get lockFileFile => 'Файл';

  @override
  String lockFileFromFiles(Object prettySize) {
    return '$prettySize · из «Файлов»';
  }

  @override
  String get lockFileFromFiles2 => 'Из «Файлов»';

  @override
  String get lockFilePassword => 'Пароль';

  @override
  String get lockFileSuggestFourWords => 'Предложить четыре слова';

  @override
  String get lockFileTypeItAgain => 'Введи ещё раз';

  @override
  String get lockFileTheTwoDoNot => 'Пароли пока не совпадают.';

  @override
  String get lockFileHideTheFileName => 'Скрыть имя файла';

  @override
  String lockFileItWillBeCalled(Object name) {
    return 'Он будет называться «$name». Скажи получателю, что это за файл.';
  }

  @override
  String get lockFileTheNameAloneCan =>
      'Одно только имя может выдать, что внутри.';

  @override
  String get lockFileAnyoneWithThePassword =>
      'Любой, у кого есть пароль, может открыть его — в kryfo или на любом компьютере с бесплатной программой age. Забудешь пароль — файл пропадёт навсегда. Сбросить его не может никто, даже мы.';

  @override
  String get lockFileLocked2 => 'Заперт.';

  @override
  String get lockFileOnlyThePasswordOpens => 'Открыть его может только пароль.';

  @override
  String lockFileSafeToEmailOr(Object prettySize) {
    return '$prettySize · можно без опаски отправить по почте или записать на флешку';
  }

  @override
  String get lockFileNoKryfoOnThe => 'У получателя нет kryfo? На компьютере:';

  @override
  String get lockFileItAsksForThe =>
      'Программа спросит пароль. age бесплатна: age-encryption.org';

  @override
  String lockTooManyTriesS(Object lockState) {
    return 'Слишком много попыток · $lockState с';
  }

  @override
  String get lockNotIt => 'Неверно';

  @override
  String get lockYourPin => 'Твой PIN-код';

  @override
  String get lockUseFingerprint => 'По отпечатку';

  @override
  String get lockSetupThatIsYourWipe =>
      'Это твой PIN для стирания. Выбери другой.';

  @override
  String get lockSetupUnlockWithFingerprint => 'Разблокировать отпечатком?';

  @override
  String get lockSetupThePinStillWorks =>
      'PIN-код работает всегда, когда захочешь. Так просто быстрее.';

  @override
  String get lockSetupUseFingerprint => 'По отпечатку';

  @override
  String get lockSetupPinOnly => 'Только PIN-код';

  @override
  String get lockSetupOnceMore => 'Ещё раз';

  @override
  String get lockSetupSetAPin => 'Задай PIN-код';

  @override
  String get lockSetupThoseWereDifferentFrom => 'Не совпало. Давай сначала.';

  @override
  String get lockSetupTheSameFourDigits => 'Те же четыре цифры';

  @override
  String get lockSetupFourDigitsAnythingYou =>
      'Четыре цифры — любые, которые запомнишь';

  @override
  String get modesOnion => 'Onion';

  @override
  String get modesFullOnionRoutingThree =>
      'Полная onion-маршрутизация, три узла. Сообщение идёт от двух до пяти секунд. Никто не видит, с кем ты общаешься.';

  @override
  String get modesSlower => 'медленнее';

  @override
  String get modesRelay => 'Ретранслятор';

  @override
  String get modesOneSealedConnectionTo =>
      'Одно зашифрованное подключение к собственному ретранслятору kryfo — как VPN, которому нечего записывать в логи. Сообщения доходят примерно за секунду, и это работает там, где tor заблокирован.';

  @override
  String get modesQuick => 'быстро';

  @override
  String get modesRelayOnly => 'только ретранслятору';

  @override
  String get modesFast => 'Быстрый';

  @override
  String get modesPlainConnectionsToEvery =>
      'Обычные подключения к каждому ретранслятору. Почти мгновенно, но это наименее приватный из трёх режимов.';

  @override
  String get modesInstant => 'мгновенно';

  @override
  String get modesEveryRelayYouUse =>
      'Каждый ретранслятор, которым ты пользуешься, знает адрес, с которого ты подключаешься, — не только наш. Сообщения по-прежнему зашифрованы, а вот сам факт отправки — нет. По умолчанию выключено и снова выключается после переустановки.';

  @override
  String get modesSpeed => 'Скорость';

  @override
  String get modesPrivacy => 'и приватность';

  @override
  String get modesChangeGloballyOrPer =>
      'Можно сменить для всех чатов или для одного';

  @override
  String get modesSoon => 'Скоро';

  @override
  String get modesActive => 'Активен';

  @override
  String get modesSpeed2 => 'СКОРОСТЬ';

  @override
  String get modesHops => 'УЗЛЫ';

  @override
  String get modesIp => 'IP';

  @override
  String get modesVisible => 'Виден';

  @override
  String get modesHidden => 'скрыт';

  @override
  String modesHeadsUp(Object warning) {
    return '*Внимание:* $warning';
  }

  @override
  String get modesOnionIsTheDefault =>
      'Onion включён по умолчанию и остаётся таким, пока ты его не сменишь. Переключение срабатывает со следующего сообщения.';

  @override
  String get modesFastMode => 'Режим «Быстрый»';

  @override
  String get modesPlainConnectionsToEveryRelayQuicker =>
      'Обычные подключения к каждому ретранслятору. Быстрее, и ретрансляторы могут видеть твой IP-адрес. Сообщения в любом случае остаются под сквозным шифрованием.';

  @override
  String get modesTurnOnFastMode => 'Включить «Быстрый»';

  @override
  String get modesKeepItOff => 'Не включать';

  @override
  String get movedWipeThisPhone => 'Стереть Kryfo с этого телефона?';

  @override
  String get movedEverythingKryfoHoldsHere =>
      'Всё, что kryfo хранит здесь, исчезнет: сообщения, контакты, ключи. На другом устройстве всё это останется. Это нельзя отменить.';

  @override
  String get movedWipeIt => 'Стереть';

  @override
  String get movedNotMovingAfterAll => 'Всё-таки не переезжаешь?';

  @override
  String get movedOnlyDoThisIf =>
      'Делай это, только если резервную копию нигде не импортировали. Если импортировали, теперь один профиль живёт на двух устройствах, и на обоих начнут пропадать сообщения.';

  @override
  String get movedIMStayingHere => 'Остаюсь здесь';

  @override
  String get movedStayingHere => 'Остаёмся здесь';

  @override
  String movedKryfoWillCloseNow(Object myId) {
    return 'Сейчас kryfo закроется. Нажми на иконку, чтобы снова открыть его как $myId.';
  }

  @override
  String get movedReopenKryfo => 'Открыть kryfo снова';

  @override
  String get movedThisKryfoHasMoved => 'Этот kryfo переехал';

  @override
  String movedIsNowOnAnother(Object myId) {
    return '$myId теперь на другом устройстве. Этот телефон ещё может показать то, что здесь было, но ничего нового сюда не придёт, а всё, что ты отправишь отсюда, ни до кого не дойдёт.';
  }

  @override
  String get movedKeepItToRead => 'Оставить для чтения';

  @override
  String get movedWipeThisPhone2 => 'Стереть Kryfo с этого телефона';

  @override
  String get movedIMNotMoving => 'Я всё-таки не переезжаю';

  @override
  String get myKryfoAHandleIs3 =>
      'Имя пользователя — от 3 до 20 букв, цифр или _';

  @override
  String get myKryfoInviteCopiedClearsIn =>
      'Приглашение скопировано · очистится через 60 с';

  @override
  String myKryfoAddMeOnKryfo(Object myId, Object uri) {
    return 'добавь меня в kryfo. мой id — $myId\n\nнажми, чтобы добавить:\n$uri\n\nkryfo — приватный мессенджер. без номера телефона и без почты.';
  }

  @override
  String get myKryfoAddMeOnKryfo2 => 'Добавь меня в kryfo';

  @override
  String get myKryfoAddSomeone => 'Добавить человека';

  @override
  String get myKryfoKryfoDoesnTScan =>
      'kryfo не сканирует твои контакты — в этом весь смысл.';

  @override
  String get myKryfoIfThisLinkEnds =>
      'Если ссылка попала не туда, сбрось её в настройках. Тогда всем, у кого она есть, понадобится новая.';

  @override
  String get myKryfoAlreadyShareAFriend =>
      'Есть общий друг в kryfo? Он может познакомить вас прямо из своего чата — и запрос не понадобится.';

  @override
  String get myKryfoHandleCopied => 'Имя пользователя скопировано';

  @override
  String get myKryfoTheyReHereWith => 'мы рядом';

  @override
  String get myKryfoPointYourPhonesAt =>
      'Наведите телефоны друг на друга. Ничего не идёт через сервер.';

  @override
  String get myKryfoScanTheirsInstead => 'Сканировать код собеседника';

  @override
  String get myKryfoTheyReadYouA => 'Мне продиктовали код';

  @override
  String get myKryfoTheyReSomewhereElse => 'мы не рядом';

  @override
  String get myKryfoSendThemALink =>
      'Отправь ссылку. Она сразу открывает добавление.';

  @override
  String get myKryfoYourLinkAppearsOnce =>
      'Ссылка появится, когда ты подключишься';

  @override
  String get myKryfoTheLinkCarriesYour =>
      'В ссылке — твой ID, твой адрес и ключи, чтобы начать чат. Она работает, пока ты не сбросишь её в настройках.';

  @override
  String get myKryfoSendTheLink => 'Отправить ссылку';

  @override
  String get myKryfoAsACard => 'Как карточку';

  @override
  String get myKryfoAnImageWithThe => 'Картинка с QR-кодом';

  @override
  String get myKryfoAsAFile => 'Как файл';

  @override
  String get myKryfoContactFile => 'Файл контакта';

  @override
  String get myKryfoIKnowTheirHandle => 'Я знаю имя пользователя';

  @override
  String get myKryfoTypeTheNameThey =>
      'Введи @имя, которое тебе дали. Сработает, если человек его занял.';

  @override
  String get myKryfoWren => 'Wren';

  @override
  String get myKryfoTheLookupAsksFor =>
      'Поиск отправляет только это имя и ничего о тебе. Твоё первое сообщение всё равно придёт как запрос.';

  @override
  String get myKryfoLooking => 'Ищем…';

  @override
  String get myKryfoFindThem => 'Найти';

  @override
  String get myKryfoYourAddressAppearsOnce =>
      'Адрес появится, когда ты подключишься';

  @override
  String get myKryfoAPublicHandle => 'Публичное имя пользователя';

  @override
  String get myKryfoPutItInA =>
      'Укажи его в описании профиля. Любой, кто его знает, сможет тебя найти.';

  @override
  String get myKryfoANamePeopleCan =>
      'Имя, по которому тебя можно найти. Выключено, пока ты его не займёшь.';

  @override
  String get newGroupCouldNotCreate => 'Не удалось создать';

  @override
  String get newGroupNewGroup => 'Новая группа';

  @override
  String get newGroupCreating => 'Создаём…';

  @override
  String get newGroupCreate => 'Создать';

  @override
  String get newGroupGroupName => 'Название группы';

  @override
  String get newGroupMembers => 'Участники';

  @override
  String get newGroupPickAtLeastOne => 'Выбери хотя бы одного';

  @override
  String newGroupSelected(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Выбрано: $countString',
    );
    return '$_temp0';
  }

  @override
  String get newGroupAddAtLeastOne =>
      'Чтобы создать группу, сначала добавь хотя бы один контакт.';

  @override
  String get notesToday => 'СЕГОДНЯ';

  @override
  String get notesYesterday => 'ВЧЕРА';

  @override
  String get notesNoteToSelf => 'Заметки';

  @override
  String get notesOnlyOnThisPhone => 'Только на этом телефоне';

  @override
  String get notesAQuietPlace => 'Тихое место';

  @override
  String get notesJotAnythingDownIt =>
      'Записывай что угодно. Всё остаётся на этом телефоне и никогда его не покидает.';

  @override
  String get notesJotSomethingDown => 'Запиши что-нибудь…';

  @override
  String get onboardingPrivateByDefault => 'ПРИВАТНО ПО УМОЛЧАНИЮ';

  @override
  String get onboardingPrivateMessaging =>
      'Приватная переписка —\n*без подвоха*.';

  @override
  String get onboardingYourNameIsThree =>
      '*Твоё имя — три слова.* Без телефона, без почты, без адресной книги.';

  @override
  String get onboardingNobodyGetsInUnless =>
      '*Никто не войдёт, пока ты не впустишь.* Поиска нет. Люди добавляют друг друга вручную, с обеих сторон.';

  @override
  String get onboardingTheFirstConnectionTakes =>
      '*Первое подключение занимает минуту.* Kryfo строит приватный маршрут, прежде чем отправлять. Потом всё быстро.';

  @override
  String get onboardingBegin => 'Начать';

  @override
  String get onboardingHaveABackupRestore =>
      'Есть резервная копия? Восстановить →';

  @override
  String get onboardingKryfoIsOpenSource => 'Код kryfo открыт';

  @override
  String get onboardingYourKryfoId => 'ТВОЙ KRYFO ID';

  @override
  String get onboardingGeneratedFromAKey =>
      'Создан из ключа, который есть только на этом телефоне. *Запоминающийся, уникальный, только твой.* Больше ни у кого такого нет.';

  @override
  String get onboardingTryAnother => 'Другой вариант';

  @override
  String get onboardingUseThisName => 'Беру это имя →';

  @override
  String get onboardingThreeWords => 'Три слова. *Только твои.*';

  @override
  String get onboardingPickA => 'Выбери *лицо*.';

  @override
  String get onboardingDrawnOnThisPhone =>
      'Нарисовано на этом телефоне из числа и никогда никуда не загружается. Меняй когда захочешь.';

  @override
  String get onboardingThePeopleYouMessage =>
      'Те, с кем ты переписываешься, тоже это видят';

  @override
  String get onboardingKeepMyInitial => 'Оставить инициал';

  @override
  String get onboardingThatOne => 'Вот это →';

  @override
  String get onboardingContinue => 'Дальше →';

  @override
  String get onboardingHowYourMessages => 'Как *путешествуют* твои сообщения.';

  @override
  String get onboardingYouCanChangeThis =>
      'Это можно поменять в настройках в любой момент — для всех чатов или для одного.';

  @override
  String get onboardingOnion => 'Onion';

  @override
  String get onboardingSlowerAMessageTakes =>
      'Медленнее. Сообщение идёт от двух до пяти секунд.';

  @override
  String get onboardingHidesYourAddressFrom =>
      'Скрывает твой адрес от всех, включая наш ретранслятор.';

  @override
  String get onboardingRelay => 'Ретранслятор';

  @override
  String get onboardingOurRelaySeesYour =>
      'Наш ретранслятор видит твой адрес. Больше никто.';

  @override
  String get onboardingAboutASecondWorks =>
      'Около секунды. Работает там, где tor заблокирован.';

  @override
  String get onboardingFast => 'Быстрый';

  @override
  String get onboardingEveryRelayYouUse =>
      'Каждый ретранслятор, которым ты пользуешься, видит твой адрес. Наименее приватный из трёх.';

  @override
  String get onboardingNearInstant => 'Почти мгновенно.';

  @override
  String get onboardingKeepOnion => 'Оставить Onion →';

  @override
  String get onboardingUseThis => 'Выбрать →';

  @override
  String get onboardingSkipOnionIsA =>
      'Пропустить · Onion — хороший выбор по умолчанию';

  @override
  String get onboardingThreeThingsThen => 'Три вещи —\nи *ты внутри*.';

  @override
  String get onboardingEverythingElseTheApp =>
      'Обо всём остальном приложение расскажет, когда это будет важно.';

  @override
  String get onboardingYourNameIsThreeWords => 'Твоё имя — три слова';

  @override
  String get onboardingThatIsTheWhole =>
      'Это и есть весь профиль. Нет номера, который может утечь, нет почты для фишинга, нечего искать. Собеседники видят эти слова и выбранное тобой лицо.';

  @override
  String get onboardingNobodyCanReachYou =>
      'Никто не сможет с тобой связаться, пока ты его не впустишь';

  @override
  String get onboardingAStrangerWithYour =>
      'Незнакомец, знающий твои слова, может только постучаться. Его первое сообщение ждёт в запросах, пока ты не скажешь «да», а сказать «нет» можно так, что он об этом никогда не узнает.';

  @override
  String get onboardingTheFirstConnectionTakesAMinute =>
      'Первое подключение занимает минуту';

  @override
  String get onboardingKryfoBuildsAPrivateRouteBefore =>
      'Kryfo строит приватный маршрут, прежде чем что-либо отправить. Пока ты не в сети, сообщения ждут и придут, когда ты вернёшься.';

  @override
  String get onboardingYourIdentityLivesOn =>
      'Твой профиль живёт на этом телефоне. Сделай резервную копию в настройках, когда будет удобно.';

  @override
  String get onboardingIUnderstand => 'Понятно →';

  @override
  String get onboardingOneQuiet => 'Одно тихое *уведомление*.';

  @override
  String get onboardingAndroidNeedsAVisible =>
      'Android требует видимое уведомление, пока приложение слушает в фоне. Так сообщения доходят до тебя, когда kryfo закрыт.';

  @override
  String get onboardingSilentAndAtThe => 'Беззвучное, в самом низу шторки';

  @override
  String get onboardingItNeverBuzzesTurn =>
      'Оно никогда не вибрирует. Выключишь его — сообщения будут ждать, пока ты снова не откроешь приложение.';

  @override
  String get onboardingGotIt => 'Ясно →';

  @override
  String get onboardingNow => 'Теперь *добавь кого-нибудь*.';

  @override
  String get onboardingTheAppIsReady =>
      'Приложение готово. Никто не сможет тебе написать, пока ты его не добавишь или не впустишь.';

  @override
  String get onboardingEveryWayToAdd => 'Все способы добавить человека';

  @override
  String get onboardingShowYourCodeSend =>
      'Покажи свой код, отправь ссылку или введи @имя пользователя, которое тебе дали.';

  @override
  String get onboardingScanTheirs => 'Сканировать код';

  @override
  String get onboardingPointTheCameraAt => 'Наведи камеру на код собеседника';

  @override
  String get onboardingTheAppIsReadyWhenYou =>
      'Приложение готово — начинай, когда захочешь.';

  @override
  String get onboardingNotNowAddPeople => 'Не сейчас · добавлю людей позже';

  @override
  String get openLockedOpened => 'Открыт';

  @override
  String get openLockedOpenALockedFile => 'Открыть запертый файл';

  @override
  String get openLockedCheckingThePassword => 'Проверяем пароль';

  @override
  String get openLockedOpening => 'Открываем';

  @override
  String get openLockedFile => 'Файл';

  @override
  String get openLockedOpenFile => 'Открыть файл';

  @override
  String get openLockedTypeThePassword => 'Введи пароль.';

  @override
  String get openLockedItOpensOnThis => 'Он откроется на этом телефоне.';

  @override
  String get openLockedLockedFile => 'Запертый файл';

  @override
  String openLockedFromFiles(Object prettySize) {
    return '$prettySize · из «Файлов»';
  }

  @override
  String get openLockedFromFiles2 => 'Из «Файлов»';

  @override
  String get openLockedPassword => 'Пароль';

  @override
  String get openLockedThePasswordIsChecked =>
      'Сначала проверяется пароль. Только потом kryfo спросит, куда положить открытый файл, и он сразу попадёт туда.';

  @override
  String get openLockedOpened2 => 'Открыт.';

  @override
  String get openLockedSavedWhereYouChose => 'Сохранено в выбранное место.';

  @override
  String get pairCodePairingCode => 'Код связи';

  @override
  String get pairCodeShowACode => 'Показать код';

  @override
  String get pairCodeEnterOne => 'Ввести код';

  @override
  String get pairCodeSixDigits => 'Шесть цифр';

  @override
  String get pairCodeLooking => 'Ищем…';

  @override
  String get pairCodeNothingThereYetTrying => 'Пока ничего · пробуем снова';

  @override
  String get pairCodeNothingAtThatCode =>
      'По этому коду ничего нет. Возможно, он уже сгорел или им ещё не поделились.';

  @override
  String get pairCodeTypeTheSixDigits =>
      'Введи шесть цифр, которые тебе продиктовали.';

  @override
  String get pairCodeAddThem => 'Добавить';

  @override
  String get panicSetupThoseWereDifferentFrom => 'Не совпало. Давай сначала.';

  @override
  String get panicSetupThatIsYourReal =>
      'Это твой настоящий PIN-код. Выбери другой.';

  @override
  String get panicSetupOnceMore => 'Ещё раз';

  @override
  String get panicSetupSetAWipePin => 'Задай PIN для стирания';

  @override
  String get panicSetupTheSameFourDigits => 'Те же четыре цифры';

  @override
  String get panicSetupTheSecondPinWipes => 'Второй PIN-код стирает всё.';

  @override
  String get photoKnowsEverythingInside => 'Всё, что внутри';

  @override
  String get photoKnowsVideo => 'Видео';

  @override
  String get photoKnowsPhoto => 'Фото';

  @override
  String get photoKnowsWhatThisVideoKnows => 'Что знает это видео';

  @override
  String get photoKnowsWhatThisPhotoKnows => 'Что знает это фото';

  @override
  String get photoKnowsRemoveAllOfIt => 'Удалить всё';

  @override
  String get photoKnowsKeepItAsIt => 'Оставить как есть';

  @override
  String get photoKnowsReadOnThisPhone =>
      'ПРОЧИТАНО НА ЭТОМ ТЕЛЕФОНЕ · ВИДЕО НИКУДА НЕ УХОДИЛО';

  @override
  String get photoKnowsReadOnThisPhoneThePhoto =>
      'ПРОЧИТАНО НА ЭТОМ ТЕЛЕФОНЕ · ФОТО НИКУДА НЕ УХОДИЛО';

  @override
  String get photoKnowsReadingTheFile => 'Читаем файл';

  @override
  String photoKnowsOf(Object prettySize, Object prettySize2) {
    return '$prettySize из $prettySize2';
  }

  @override
  String get photoKnowsEverythingStaysOnThis =>
      'Всё остаётся на этом телефоне.';

  @override
  String photoKnowsMapWithAPin(Object place) {
    return 'Карта с меткой. $place';
  }

  @override
  String get photoKnowsDrawnOffline => 'НАРИСОВАНО ОФЛАЙН';

  @override
  String photoKnowsShowEverything(Object title) {
    return '$title. Показать всё';
  }

  @override
  String get pinsAppLock => 'Блокировка';

  @override
  String get pinsTwoPins => 'Два PIN-кода';

  @override
  String get pinsYourPin => 'Твой PIN-код';

  @override
  String get commonOn => 'Вкл.';

  @override
  String get commonOff => 'Выкл.';

  @override
  String get pinsOpensKryfoFourDigits =>
      'Открывает kryfo. Четыре цифры — их спрашивают, когда приложение выходит на передний план.';

  @override
  String get pinsChangePin => 'Сменить PIN-код';

  @override
  String get pinsSetAPin => 'Задать PIN-код';

  @override
  String get pinsTurnOff => 'Выключить';

  @override
  String get pinsTurnOffTheApp => 'Выключить блокировку?';

  @override
  String get pinsThePinGoesAnd =>
      'PIN-код удаляется, а вместе с ним и PIN для стирания. Любой, у кого в руках твой телефон, откроет kryfo от твоего имени.';

  @override
  String get pinsUnlockWithFingerprint => 'Разблокировка отпечатком';

  @override
  String get pinsWipePin => 'PIN для стирания';

  @override
  String get pinsNeedsAPinFirst => 'Сначала нужен PIN-код';

  @override
  String get pinsSet => 'Задать';

  @override
  String get pinsTheSecondPinWipes => 'Второй PIN-код стирает всё.';

  @override
  String get pinsChangeWipePin => 'Сменить PIN для стирания';

  @override
  String get pinsSetAWipePin => 'Задать PIN для стирания';

  @override
  String get pinsRemove => 'удалить';

  @override
  String get pinsRemoveTheWipePin => 'Удалить PIN для стирания?';

  @override
  String get pinsTheLockScreenKeeps =>
      'Экран блокировки сохраняет твой PIN-код. PIN для стирания больше ничего не делает.';

  @override
  String profileCopied(Object what) {
    return 'Скопировано: $what';
  }

  @override
  String get profileProfile => 'Профиль';

  @override
  String get profileChangeYourFace => 'Сменить лицо';

  @override
  String get profileKryfoId => 'kryfo ID';

  @override
  String get profileOnionAddress => 'onion-адрес';

  @override
  String get profileSupporterBadge => 'Значок сторонника';

  @override
  String profileYouAreAThank(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter': 'Ты сторонник. спасибо.',
      'patron': 'Ты меценат. спасибо.',
      'guardian': 'Ты хранитель. спасибо.',
      'other': 'Ты сторонник. спасибо.',
    });
    return '$_temp0';
  }

  @override
  String get profileShowMyBadge => 'показывать мой значок';

  @override
  String get profileOnMyOwnScreens => 'На моих экранах';

  @override
  String get profileLetContactsSeeIt => 'Показывать контактам';

  @override
  String get profileOffByDefault => 'по умолчанию выключено';

  @override
  String get profileShareConnect => 'поделиться и связаться';

  @override
  String get profileMyKryfoCode => 'Мой код kryfo';

  @override
  String get profileAddContact => 'Добавить контакт';

  @override
  String get profileGiveAgain => 'Поддержать снова';

  @override
  String get profileSupportKryfo => 'Поддержать kryfo';

  @override
  String get profileKryfoRunsOnWhat => 'Kryfo живёт на то, что дают люди';

  @override
  String get profileKeepKryfoIndependent => 'Сохрани kryfo независимым';

  @override
  String get qrLink => 'Ссылка';

  @override
  String get qrYourLinkAsTyped =>
      'ТВОЯ ССЫЛКА КАК ЕСТЬ · БЕЗ СЛЕДЯЩЕЙ ПЕРЕАДРЕСАЦИИ';

  @override
  String get qrText => 'Текст';

  @override
  String get qrStaysInTheCode =>
      'ОСТАЁТСЯ В КОДЕ · НИКАКОЙ СЕРВЕР ЕГО НЕ ХРАНИТ';

  @override
  String get qrWiFi => 'Wi-Fi';

  @override
  String get qrMadeOnThisPhone =>
      'СДЕЛАНО НА ЭТОМ ТЕЛЕФОНЕ · НИ ОДИН САЙТ НЕ ВИДЕЛ ПАРОЛЬ';

  @override
  String get qrNetworkName => 'Имя сети';

  @override
  String get qrPassword => 'Пароль';

  @override
  String get qrContact => 'Контакт';

  @override
  String get qrOnlyWhatYouType =>
      'ТОЛЬКО ТО, ЧТО ТЫ ВВОДИШЬ · НИЧЕГО ИЗ ТВОИХ КОНТАКТОВ';

  @override
  String get qrName => 'Имя';

  @override
  String get qrPhone => 'Телефон';

  @override
  String get qrEmail => 'Почта';

  @override
  String get qrOpensTheirMailApp =>
      'ОТКРЫВАЕТ ПОЧТОВОЕ ПРИЛОЖЕНИЕ · ОТСЮДА НИЧЕГО НЕ ОТПРАВЛЯЕТСЯ';

  @override
  String get qrTo => 'Кому';

  @override
  String get qrSubject => 'Тема';

  @override
  String get qrANumberNothingElse => 'НОМЕР · И НИЧЕГО БОЛЬШЕ';

  @override
  String get qrNumber => 'Номер';

  @override
  String get qrSms => 'SMS';

  @override
  String get qrOpensTheirMessagesApp =>
      'ОТКРЫВАЕТ ПРИЛОЖЕНИЕ СООБЩЕНИЙ · ОТСЮДА НИЧЕГО НЕ ОТПРАВЛЯЕТСЯ';

  @override
  String get qrMessage => 'Сообщение';

  @override
  String get qrLocation => 'Местоположение';

  @override
  String get qrCoordinatesOnlyNoMap =>
      'ТОЛЬКО КООРДИНАТЫ · КАРТОГРАФИЧЕСКИЕ СЕРВИСЫ НЕ ЗАПРАШИВАЮТСЯ';

  @override
  String get qrLatitude => 'Широта';

  @override
  String get qrLongitude => 'Долгота';

  @override
  String get qrBitcoin => 'Bitcoin';

  @override
  String get qrAddressAndAmountNo =>
      'АДРЕС И СУММА · БЕЗ ПЛАТЁЖНЫХ САЙТОВ ПОСЕРЕДИНЕ';

  @override
  String get qrAddress => 'Адрес';

  @override
  String get qrAmountInBtc => 'Сумма в BTC';

  @override
  String get qrInk => 'Чернила';

  @override
  String get qrAmber => 'Янтарь';

  @override
  String get qrViolet => 'Фиалка';

  @override
  String get qrCouldNotDrawThe => 'Не удалось нарисовать картинку.';

  @override
  String get qrSavedToYourGallery => 'Сохранено в галерею';

  @override
  String get qrCouldNotSaveIt =>
      'Не удалось сохранить. Проверь, есть ли место на телефоне.';

  @override
  String get qrNoAppOnThis =>
      'Ни одно приложение на этом телефоне не приняло картинку.';

  @override
  String get qrTooMuchForOne => 'Слишком много для одного кода. Сократи.';

  @override
  String get qrThisIsALot =>
      'Для одного кода это многовато. Старые камеры могут его не прочитать.';

  @override
  String get qrPrivateQrCode => 'Приватный QR-код';

  @override
  String get qrColour => 'Цвет';

  @override
  String get qrCopiedItLeavesThe =>
      'Скопировано. Через минуту исчезнет из буфера обмена';

  @override
  String get qrSecurity => 'Защита';

  @override
  String get qrNone => 'Нет';

  @override
  String get qrSaveImage => 'Сохранить картинку';

  @override
  String qrColour2(Object name) {
    return 'Цвет: $name';
  }

  @override
  String get qrTypeBelowAndThe => 'Введи текст ниже —\nкод нарисуется сам';

  @override
  String get qrQrCode => 'QR-код';

  @override
  String get qrHidePassword => 'Скрыть пароль';

  @override
  String get qrShowPassword => 'Показать пароль';

  @override
  String get qrCopyPassword => 'Копировать пароль';

  @override
  String get requestsSentAnAttachment => 'Прислано вложение';

  @override
  String get requestsWantsToConnect => 'Хочет связаться';

  @override
  String get requestsAccepted => 'Принято';

  @override
  String requestsBlock(Object id) {
    return 'Заблокировать $id?';
  }

  @override
  String get requestsNothingMoreFromThem =>
      'От этого человека к тебе больше ничего не дойдёт. Его запрос и сообщения удаляются.';

  @override
  String get requestsBlocked => 'заблокирован';

  @override
  String get requestsDeleted => 'удалён';

  @override
  String get requestsRequests => 'Запросы';

  @override
  String get requestsNoRequests => 'Запросов нет';

  @override
  String get requestsMessagesFromPeopleYou =>
      'Сообщения от людей не из твоих контактов сначала появляются здесь.';

  @override
  String get requestsLooksSafeNothingSuspicious =>
      'Выглядит безопасно · в первом сообщении ничего подозрительного';

  @override
  String get commonAccept => 'Принять';

  @override
  String get requestsDecline => 'Отклонить';

  @override
  String get restoreThatFileIsNot => 'Этот файл — не резервная копия kryfo';

  @override
  String get restoreThisFileIsDamaged =>
      'Этот файл повреждён, прочитать его нельзя';

  @override
  String get restoreTypeThePassphraseThe =>
      'Введи парольную фразу, с которой создан файл';

  @override
  String get restoreReplaceTheAccountOn => 'Заменить аккаунт на этом телефоне?';

  @override
  String get restoreWhatIsHereNow =>
      'Всё, что здесь сейчас есть — профиль, контакты и сообщения, — исчезнет. Его место займёт файл. Это нельзя отменить.';

  @override
  String get restoreReplaceIt => 'Заменить';

  @override
  String restoreCouldNotBeReleased(Object mine) {
    return 'Не удалось освободить @$mine';
  }

  @override
  String restoreTheRegistryDidNot(Object mine) {
    return 'Реестр не ответил. Если продолжишь, @$mine так и будет указывать на профиль, который этот телефон вот-вот потеряет. Все, кто добавит это имя, будут писать в никуда, а занять его снова будет нельзя. Лучше выйти в сеть и попробовать ещё раз.';
  }

  @override
  String get restoreRestoreAnyway => 'Всё равно восстановить';

  @override
  String get restoreNotYet => 'Пока нет';

  @override
  String get restoreRestored => 'Восстановлено';

  @override
  String restoreKryfoWillCloseNow(Object haloId) {
    return 'Сейчас kryfo закроется. Нажми на иконку, чтобы снова открыть его как $haloId.';
  }

  @override
  String get restoreReopenKryfo => 'Открыть kryfo снова';

  @override
  String get restoreTheRestoreDidNot =>
      'Восстановление не завершилось. Ничего не изменено';

  @override
  String get restoreThisIdentity => 'профиль kryfo';

  @override
  String get restoreMoveYourKryfoHere => 'Перенести kryfo сюда';

  @override
  String restoreThisBackupIsRestoring(Object name) {
    return 'В этой резервной копии: $name. Восстановление перенесёт этот профиль на это устройство.';
  }

  @override
  String restoreThisBackupMadeOn(Object name, Object date, Object time) {
    return 'Резервная копия от $date, $time. В ней: $name. Восстановление перенесёт этот профиль на это устройство.';
  }

  @override
  String restoreItHoldsOfPhotos(Object mb) {
    return 'Фото, голосовые и файлы в ней весят $mb. Это может занять несколько минут. Не закрывай приложение.';
  }

  @override
  String get restoreWhatFollows => 'Что переносится';

  @override
  String get restoreYourNameYourCode => 'Твоё имя, твой код и все контакты.';

  @override
  String get restoreEveryConversationBackTo =>
      'Вся переписка, с самого начала.';

  @override
  String get restoreYourPhotosVoiceNotes => 'Твои фото, голосовые и файлы.';

  @override
  String restoreYourPhotosVoiceNotesCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Твои фото, голосовые и файлы · $countString.',
    );
    return '$_temp0';
  }

  @override
  String get restoreYourOnionAddressSo =>
      'Твой onion-адрес — чтобы те, кто связывается с тобой напрямую, и дальше могли до тебя достучаться.';

  @override
  String get restoreAnythingSentToYou =>
      'Всё, что тебе отправили, пока старый телефон был выключен, — в течение четырнадцати дней после отправки.';

  @override
  String get restoreYourSupporterBadgeIf =>
      'Твой значок сторонника, если он есть.';

  @override
  String get restoreWhatDoesnT => 'Что не переносится';

  @override
  String get restoreTheOldPhoneStops =>
      'Старый телефон перестаёт получать сообщения в тот момент, когда ты что-нибудь отправишь отсюда. Не постепенно. Первое сообщение, отправленное с этого устройства, — последнее, что старый телефон ещё может отследить, а всё, что придёт на него после этого, там не прочитать, и здесь оно тебя тоже не ждёт.';

  @override
  String get restoreIfThePhoneThis =>
      'Если телефон, с которого этот файл, ещё используется, перестань пользоваться на нём kryfo, прежде чем продолжить. Два телефона на одном kryfo теряют сообщения на обоих.';

  @override
  String get restoreNotificationsNeedSettingUp =>
      'Уведомления на этом устройстве нужно будет настроить заново.';

  @override
  String get restoreMoveItHere => 'Перенести сюда';

  @override
  String get restoreNotNow => 'Не сейчас';

  @override
  String get restoreRestore => 'Восстановить';

  @override
  String get restoreFromABackupFile => 'Из файла резервной копии';

  @override
  String get restoreABackupBringsBack =>
      'Резервная копия возвращает твой профиль, контакты и сообщения, которые были на телефоне, когда создавался файл. Того, что написано после, в ней нет.';

  @override
  String get restoreTheFile => 'Файл';

  @override
  String get restorePickTheBackupFile => 'Выбери файл резервной копии';

  @override
  String get restoreThePassphrase => 'Парольная фраза';

  @override
  String get restoreTheOneTheFile => 'Та, с которой создан файл';

  @override
  String get restoreWhatComesBack => 'Что вернётся';

  @override
  String get restoreChecking => 'Проверяем…';

  @override
  String get restoreCheckTheFile => 'Проверить файл';

  @override
  String get restoreReleasingYourHandle => 'Освобождаем имя пользователя…';

  @override
  String restoreMoving(Object progress) {
    return 'Переносим… $progress';
  }

  @override
  String get restoreRestoring => 'Восстанавливаем…';

  @override
  String get restoreNotThisOne => 'Не этот';

  @override
  String get restoreDateUnknown => 'Дата неизвестна';

  @override
  String get restoreAnIdentity => 'Профиль';

  @override
  String get restoreMessagesSentOrReceived =>
      'Сообщений, отправленных или полученных после этой даты, в файле нет.';

  @override
  String restoreGb(Object bytes) {
    return '$bytes ГБ';
  }

  @override
  String restoreMb(Object bytes) {
    return '$bytes МБ';
  }

  @override
  String get roomCreateCouldNotCreateThe => 'Не удалось создать комнату';

  @override
  String get roomCreateBurnerRoom => 'Одноразовая комната';

  @override
  String get roomCreateARoomThatEnds =>
      'Комната, у которой есть конец. Все входят под ключом, созданным специально для неё, а когда она заканчивается, ни на одном телефоне ничего не остаётся.';

  @override
  String get roomCreateRoomName => 'Название комнаты';

  @override
  String get roomCreateEndsAfter => 'Закончится через';

  @override
  String get roomCreateMemberCap => 'Лимит участников';

  @override
  String roomCreateNoOnePastThe(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Максимум $countString участника',
      many: 'Максимум $countString участников',
      few: 'Максимум $countString участника',
      one: 'Максимум $countString участник',
    );
    return '$_temp0';
  }

  @override
  String get roomCreateOffAnyoneWithThe => 'выкл. Любой, у кого есть ссылка';

  @override
  String roomCreateThisRoomAndEverything(Object expiryWords) {
    return 'Эта комната и всё в ней исчезнут $expiryWords';
  }

  @override
  String get roomCreateCreating => 'создаём...';

  @override
  String get roomCreateCreateRoom => 'Создать комнату';

  @override
  String get roomLinkSendTheRoomTo => 'Кому отправить комнату';

  @override
  String get roomLinkTheyWillKnowThis =>
      'Получатель узнает, что комната от тебя. Внутри он — просто ключ, как и все остальные.';

  @override
  String get roomLinkNoContactsYet => 'Контактов пока нет';

  @override
  String roomLinkEndsIn(Object time) {
    return 'Закончится через $time';
  }

  @override
  String get roomLinkAnyoneWithThisCan =>
      'Любой, у кого есть эта ссылка, может войти, пока комната не закончится. Он входит под ключом, созданным для этой комнаты, и не видит ничего, что было отправлено до его прихода.';

  @override
  String get roomLinkRoomLinkCopied => 'Ссылка скопирована';

  @override
  String get roomLinkSendToAContact => 'Отправить контакту';

  @override
  String get roomLinkCopyRoomLink => 'Копировать ссылку';

  @override
  String get savedVoiceNote => 'голосовое';

  @override
  String get savedPhoto => 'фото';

  @override
  String get savedSaved => 'Сохранённые';

  @override
  String get savedNothingSavedYet => 'Пока ничего не сохранено';

  @override
  String get savedLongPressAnyMessage =>
      'зажми любое сообщение и нажми «Сохранить», чтобы оно осталось здесь.';

  @override
  String get savedViewInChat => 'Показать в чате';

  @override
  String get savedPhoto2 => 'Фото';

  @override
  String get scanThatSNotA => 'это не QR kryfo · продолжай наводить';

  @override
  String get scanScanAKryfoQr => 'Сканировать QR kryfo';

  @override
  String get scanFlash => 'Вспышка';

  @override
  String get scanPointAtAKryfo =>
      'Наведи на QR kryfo · ничего не покидает твой телефон';

  @override
  String get seenWhatWeCanSee => 'Что мы можем видеть';

  @override
  String get seenEveryMessengerClaimsPrivacy =>
      'Каждый мессенджер обещает приватность. Вот конкретный список, по каждому маршруту, включая то, что нас не красит. Нажми на строку, чтобы узнать почему.';

  @override
  String get seenHonestAboutTheLast =>
      'Честно о последних строках: для этого и нужны блокировка приложения, PIN для стирания и зашифрованное хранилище, и никакой инструмент не спасёт, если кто-то держит в руках твой разблокированный телефон. Полная модель угроз — в файле THREAT_MODEL.md в репозитории, составлена по LINDDUN. Код открыт, так что ничему из этого не нужно верить на слово.';

  @override
  String get seenHidden => 'скрыто';

  @override
  String get seenNever => 'никогда';

  @override
  String get seenOnDevice => 'на устройстве';

  @override
  String get seenTiming => 'время';

  @override
  String get seenYours => 'твой риск';

  @override
  String get seenUnaudited => 'без аудита';

  @override
  String get seenWhoYouTalkTo => 'С кем ты общаешься';

  @override
  String get seenEachConversationGetsIts =>
      'У каждого разговора свой адрес, выведенный из обоих ключей. Ретранслятор видит не связанные между собой тайники, а не пару людей.';

  @override
  String get seenWhatYouSay => 'что ты говоришь';

  @override
  String get seenEndToEndEncrypted =>
      'Сквозное шифрование на двойном храповике Signal, а поверх — ещё одна упаковка в gift wrap. Мы не смогли бы это прочитать, даже если бы попытались.';

  @override
  String get seenYourIpAddress => 'Твой IP-адрес';

  @override
  String get seenOurRelay => 'наш ретранслятор';

  @override
  String get seenEveryRelay => 'все ретрансляторы';

  @override
  String get seenOnOnionEverythingLeaves =>
      'В режиме Onion всё уходит через tor, и ретранслятор видит выходной узел, но никогда не тебя. В режиме «Ретранслятор» подключение идёт прямо к нашему собственному ретранслятору: твой адрес никуда не передаётся и нигде не записывается, но это одно подключение видим мы. В режиме «Быстрый» каждый публичный ретранслятор узнаёт о твоём подключении, но не о том, с кем ты общаешься и что говоришь.';

  @override
  String get seenYourContactGraph => 'Твой граф контактов';

  @override
  String get seenKryfoDoesNotScan =>
      'Kryfo не сканирует твои контакты. В этом и смысл. Здесь нет номера телефона, который мог бы утечь.';

  @override
  String get seenIntroducer => 'посредник';

  @override
  String get seenWhenAContactIntroduces =>
      'Когда контакт знакомит тебя с кем-то, он узнаёт, что вы теперь связаны. Больше никто. Ретранслятор видит шифротекст, а граф не видит ни один сервер.';

  @override
  String get seenTheScamShield => 'Защита от мошенников';

  @override
  String get seenRunsOnYourPhone =>
      'Работает на твоём телефоне по правилам, встроенным в приложение. Без сети, без загрузки списков. Читает только первое сообщение от незнакомца и не может видеть ничего, что тебе присылают контакты.';

  @override
  String get seenBurnerRooms => 'одноразовые комнаты';

  @override
  String get seenRoomKeys => 'ключи комнаты';

  @override
  String get seenYouJoinARoom =>
      'Ты входишь в комнату под ключом, созданным для неё, так что люди внутри не узнают ничего, что пригодилось бы где-то ещё. Кто пришёл позже, не получает историю. Когда срок истекает, ключи, сообщения и медиа уничтожаются.';

  @override
  String get seenLinkPreviews => 'превью ссылок';

  @override
  String get seenOverTor => 'через tor';

  @override
  String get seenAPreviewIsFetched =>
      'Превью загружает отправитель, через tor, и оно идёт внутри зашифрованного сообщения. Телефон получателя ничего не запрашивает. Сайт узнаёт лишь то, что кто-то через tor запросил страницу, и больше ничего. Картинки никогда не загружаются, а ссылка от незнакомца остаётся простым текстом.';

  @override
  String get seenThatADeviceFetched => 'Что устройство проверяло почту';

  @override
  String get seenARelayCanTell =>
      'Ретранслятор может понять, что какой-то адрес проверяли и когда. Но не может понять, чей он и откуда.';

  @override
  String get seenASeizedUnlockedPhone => 'Изъятый разблокированный телефон';

  @override
  String get seenIfSomeoneHoldsYour =>
      'Если кто-то держит в руках твой разблокированный телефон, он прочитает твои сообщения. Блокировка приложения, PIN для стирания и зашифрованное хранилище помогают до этого момента, а не после.';

  @override
  String get seenTheCryptoItself => 'Сама криптография';

  @override
  String get seenTheRatchetAndStorage =>
      'Храповик и слой хранения — стандартные. Слой, который их соединяет, — наш, и никто независимый его не проверял. Считай это альфа-версией — так оно и есть.';

  @override
  String get seenOnion => 'Onion';

  @override
  String get seenRelay => 'Ретранслятор';

  @override
  String get seenFast => 'Быстрый';

  @override
  String get settingsWipeKryfo => 'Стереть kryfo?';

  @override
  String get settingsIdentityMessagesContactsAnd =>
      'Профиль, сообщения, контакты и настройки на этом телефоне. Исчезнут навсегда, если у тебя нет резервной копии.';

  @override
  String get commonContinue => 'Продолжить';

  @override
  String settingsTypeWipeToConfirm(Object word) {
    return 'введи «$word» для подтверждения';
  }

  @override
  String get settingsTheLastStepNothing =>
      'Последний шаг. После него не останется ничего.';

  @override
  String get settingsWipeWord => 'стереть';

  @override
  String get settingsWipeKryfo2 => 'Стереть kryfo';

  @override
  String get settingsYourProtections => 'Твоя защита';

  @override
  String get settingsTorRouting => 'Маршрутизация tor';

  @override
  String get settingsConnecting => 'Подключение';

  @override
  String get settingsOffMode => 'Выкл. · ретранслятор';

  @override
  String get settingsOffFastMode => 'Выкл. · быстрый режим';

  @override
  String get settingsAppLock => 'Блокировка';

  @override
  String get settingsBlockedByAndroid => 'Заблокировано Android';

  @override
  String get settingsSpeedPrivacy => 'Скорость и приватность';

  @override
  String get settingsFast => 'Быстрый';

  @override
  String get settingsRelay1Hop => 'Ретранслятор · 1 узел';

  @override
  String get settingsOnion3Hops => 'Onion · 3 узла';

  @override
  String get settingsBridges => 'Мосты';

  @override
  String get settingsForNetworksThatBlock => 'Для сетей, где tor заблокирован';

  @override
  String get settingsGettingMessages => 'Получение сообщений';

  @override
  String settingsPreviewHidden(Object deliveryModeName) {
    return '$deliveryModeName · превью скрыто';
  }

  @override
  String settingsPreviewShown(Object deliveryModeName) {
    return '$deliveryModeName · превью видно';
  }

  @override
  String get settingsRunInBackground => 'Работа в фоне';

  @override
  String get settingsSoMessagesArrive => 'Чтобы сообщения доходили';

  @override
  String get settingsTransport => 'Транспорт';

  @override
  String get settingsWhatTheNetworkIs => 'Что происходит в сети';

  @override
  String get settingsBlocked => 'Заблокированные';

  @override
  String get settingsAcceptIntroductions => 'Принимать знакомства';

  @override
  String get settingsFriendsCanIntroduceYou =>
      'Друзья могут знакомить тебя со своими друзьями';

  @override
  String get settingsScamShield => 'Защита от мошенников';

  @override
  String get settingsChecksStrangersOnYour =>
      'Проверяет незнакомцев на твоём телефоне. Ничего не покидает его';

  @override
  String get settingsBlockScreenshots => 'Запретить скриншоты';

  @override
  String get settingsWholeAppHiddenFrom =>
      'Приложение целиком скрыто из недавних и скриншотов · сработает после следующего запуска';

  @override
  String get settingsWholeAppHiddenFromRecentsAnd =>
      'Приложение целиком скрыто из недавних и скриншотов';

  @override
  String get settingsOnNextStart => 'Вкл. · после перезапуска';

  @override
  String get settingsOffNextStart => 'Выкл. · после перезапуска';

  @override
  String get settingsLightTheme => 'Светлая тема';

  @override
  String get settingsSameProtectionBrighter => 'Та же защита, только светлее';

  @override
  String get settingsAppLock2 => 'Блокировка';

  @override
  String get settingsYourPinAndA => 'Твой PIN-код и PIN для стирания';

  @override
  String get settingsPinWipePin => 'PIN · PIN для стирания';

  @override
  String get settingsBackUpIdentity => 'Резервная копия профиля';

  @override
  String get settingsEncryptedFile => 'Зашифрованный файл';

  @override
  String get settingsRestoreFromBackup => 'Восстановить из копии';

  @override
  String get settingsReplaceCurrent => 'Заменит текущий';

  @override
  String get settingsDisguiseVoice => 'Изменить голос';

  @override
  String get settingsShiftsYourPitchBefore =>
      'Меняет высоту голоса, прежде чем голосовое уйдёт';

  @override
  String get settingsWhyKryfo => 'Почему kryfo';

  @override
  String get settingsHowItProtectsYou => 'Как он тебя защищает';

  @override
  String get settingsResetMyInviteLink => 'Сбросить мою ссылку-приглашение';

  @override
  String get settingsOldLinksAndCodes =>
      'Старые ссылки и коды перестанут работать — для всех';

  @override
  String get settingsResetInviteLink => 'Сбросить ссылку-приглашение?';

  @override
  String get settingsAnyoneWithAnOld =>
      'Любой, у кого старый код или ссылка, больше не сможет с тобой связаться — ни по одному маршруту. Тем, у кого они есть, но кто ими ещё не воспользовался, понадобится новый от тебя. Контакты, чаты и история останутся.';

  @override
  String get settingsReset => 'Сбросить';

  @override
  String get settingsInviteResetShareThe =>
      'Приглашение сброшено · поделись новым кодом';

  @override
  String get settingsWhatWeCanSee => 'Что мы можем видеть';

  @override
  String get settingsTheHonestList => 'Честный список';

  @override
  String get settingsVersion => 'Версия';

  @override
  String get settings030Alpha => '0.4.0 · альфа';

  @override
  String get settingsReportAnIssue => 'Сообщить о проблеме';

  @override
  String get settingsBugOrSecurityFlaw => 'Ошибка или уязвимость';

  @override
  String get settingsOpenSource => 'Открытый код';

  @override
  String get settingsLinkCopied => 'Ссылка скопирована';

  @override
  String get settingsTheOfflineMapIn =>
      'Офлайн-карта в «Инструментах» нарисована по данным Natural Earth (общественное достояние). Названия городов — из GeoNames, geonames.org, по лицензии CC BY 4.0.';

  @override
  String get settingsNotIndependentlyAuditedPre =>
      'Независимого аудита не было. Пре-альфа — годится для тестов, но пока не для случаев, когда на кону многое.';

  @override
  String get settingsDangerZone => 'Опасная зона';

  @override
  String get settingsWipeKryfoFromThis => 'Стереть kryfo с этого телефона';

  @override
  String get shieldCheckedOnThisPhone =>
      'Проверено на этом телефоне. Ничего никуда не отправлялось.';

  @override
  String get toolsMoreTools => 'Ещё инструменты';

  @override
  String get toolsCleanAPhotoOr => 'Очистить фото или видео';

  @override
  String get toolsOrShareOneTo => 'Или поделись им с kryfo из галереи';

  @override
  String get toolsMakeAPrivateQr => 'Сделать приватный QR-код';

  @override
  String get toolsLinksWiFiContacts =>
      'Ссылки, Wi-Fi, контакты и не только. Без интернета';

  @override
  String get toolsLockAFile => 'Запереть файл';

  @override
  String get toolsWithAPasswordOpens =>
      'Паролем. Открывается где угодно через age';

  @override
  String get toolsOpenALockedFile => 'Открыть запертый файл';

  @override
  String get toolsAnyAgeFileSomeone => 'Любой файл .age, который тебе прислали';

  @override
  String get toolsWorksOfflineNoContacts =>
      'Работает офлайн · контакты не нужны';

  @override
  String get toolsUsefulFrom => 'Полезно';

  @override
  String get toolsTheFirstMinute => 'с первой минуты.';

  @override
  String get toolsEverythingHereHappensOn =>
      'Всё здесь происходит на этом телефоне. Ничего не загружается, и никому больше не нужно быть в kryfo.';

  @override
  String get toolsWhatDoesThisPhoto => 'Что знает это фото?';

  @override
  String get toolsPlacePhoneTime => 'Место · телефон · время';

  @override
  String get toolsPickAPhotoAnd =>
      'Выбери фото и посмотри, что оно выдаёт. Потом сохрани чистую копию.';

  @override
  String get toolsPickAPhoto => 'Выбрать фото';

  @override
  String get toolsVideo => 'Видео';

  @override
  String get transportTransport => 'Транспорт';

  @override
  String get transportNothingHereLeavesThe =>
      'Ничто отсюда не покидает телефон. Это то же состояние, по которому движок решает, что делать.';

  @override
  String get transportStayingAlive => 'держит связь';

  @override
  String get transportCanSend => 'может отправлять';

  @override
  String get commonYes => 'Да';

  @override
  String get transportNotYet => 'Пока нет';

  @override
  String get transportOnline => 'В сети';

  @override
  String get transportOffline => 'Не в сети';

  @override
  String get transportQueuedToSend => 'в очереди на отправку';

  @override
  String get transportOnionPublished => 'Onion опубликован';

  @override
  String transportYes(Object uploads) {
    return 'Да ($uploads)';
  }

  @override
  String transportTryingS(Object pubFor) {
    return 'Пробуем $pubFor с';
  }

  @override
  String transportBenchedS(Object r) {
    return 'На паузе $r с';
  }

  @override
  String transportFails(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString сбоя',
      many: '$countString сбоев',
      few: '$countString сбоя',
      one: '$countString сбой',
    );
    return '$_temp0';
  }

  @override
  String get transportOk => 'ок';

  @override
  String get transportRelaySubscriptions => 'Подписки на ретрансляторах';

  @override
  String get transportLastSent => 'последняя отправка';

  @override
  String get transportNever => 'Никогда';

  @override
  String transportSAgo(Object sx) {
    return '$sx с назад';
  }

  @override
  String get transportLastReceived => 'последнее получение';

  @override
  String transportSAgo2(Object rx) {
    return '$rx с назад';
  }

  @override
  String get transportWithNoContactsThe =>
      'Без контактов приложение не подписывается ни на один адрес ретранслятора, поэтому до тебя не дойдёт ни одно сообщение. Отсканируй кого-нибудь, чтобы это исправить.';

  @override
  String get transportSendAnythingWaitingNow =>
      'Отправить всё, что ждёт, сейчас';

  @override
  String get transportOff => 'выкл.';

  @override
  String get transportStarting => 'запуск';

  @override
  String get transportBootstrapped => 'загрузился';

  @override
  String get transportPublishingAddress => 'Публикуем адрес';

  @override
  String get transportReachable => 'доступен';

  @override
  String get transportOurRelayOnion => 'наш ретранслятор (onion)';

  @override
  String get transportNever2 => 'никогда';

  @override
  String get transportJustNow => 'Только что';

  @override
  String transportMAgo(Object inMinutes) {
    return '$inMinutes мин назад';
  }

  @override
  String transportHAgo(Object inHours) {
    return '$inHours ч назад';
  }

  @override
  String transportDAgo(Object inDays) {
    return '$inDays д назад';
  }

  @override
  String transportM(Object inMinutes) {
    return '$inMinutes мин';
  }

  @override
  String transportHM(Object inHours, Object d) {
    return '$inHours ч $d мин';
  }

  @override
  String transportD(Object inDays) {
    return '$inDays д';
  }

  @override
  String transportMb(Object b) {
    return '$b МБ';
  }

  @override
  String get transportYesCheckedJustNow => 'Да · проверено только что';

  @override
  String transportNoLast(Object ago) {
    return 'Нет · посл. $ago';
  }

  @override
  String get transportLastMessageIn => 'Последнее входящее';

  @override
  String get transportBatteryExemption => 'Исключение для батареи';

  @override
  String get transportUnknown => 'неизвестно';

  @override
  String get transportExempt => 'в исключениях';

  @override
  String get transportNotExemptTapTo => 'Нет исключения · исправить';

  @override
  String get transportProcessUp => 'процесс работает';

  @override
  String get transportLastStop => 'последняя остановка';

  @override
  String transportEngine(Object mb, Object mb2) {
    return '$mb · движок $mb2';
  }

  @override
  String get transportLastRelayArrival => 'Последнее с ретранслятора';

  @override
  String get transportLastCheckIn => 'последняя проверка';

  @override
  String get transportNoneYet => 'Пока нет';

  @override
  String get transportLastTorReconnect => 'последнее переподключение tor';

  @override
  String get transportCatchUpByRelay => 'догрузка через ретранслятор';

  @override
  String get transportControlPort => 'порт управления';

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
      other: '$dialsString попытки',
      many: '$dialsString попыток',
      few: '$dialsString попытки',
      one: '$dialsString попытка',
    );
    String _temp1 = intl.Intl.pluralLogic(
      timeouts,
      locale: localeName,
      other: '$timeoutsString тайм-аута',
      many: '$timeoutsString тайм-аутов',
      few: '$timeoutsString тайм-аута',
      one: '$timeoutsString тайм-аут',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get transportJobRuns => 'запуски задачи';

  @override
  String transportLast(Object jobRuns, Object ago) {
    return '$jobRuns · последний $ago';
  }

  @override
  String get transportQuietStretches => 'Периоды тишины';

  @override
  String get transportNone => 'Нет';

  @override
  String get transportClearThisRecord => 'Очистить эту запись';

  @override
  String get transportNothingYetThisProcess => 'Пока ничего в этом процессе';

  @override
  String transportM2(Object mins) {
    return '$mins мин';
  }

  @override
  String transportHM2(Object mins, Object mins2) {
    return '$mins ч $mins2 мин';
  }

  @override
  String transportTo(Object t, Object t2) {
    return 'с $t до $t2';
  }

  @override
  String vouchersVouchedBy(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString рекомендации',
      many: '$countString рекомендаций',
      few: '$countString рекомендации',
      one: '$countString рекомендация',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperAtmosphere => 'Атмосфера';

  @override
  String get wallpaperJustForYouThey =>
      'Только для тебя. Собеседник видит свои.';

  @override
  String get wallpaperYourPhoto => 'твоё фото';

  @override
  String get wallpaperFromYourPhotos => 'Из галереи';

  @override
  String get wallpaperKeepIt => 'Оставить';

  @override
  String get whyKryfoWhyKryfo => 'Почему kryfo';

  @override
  String get whyKryfoKryfoKreeFoGreek =>
      'Kryfo · КРИ-фо · по-гречески «скрытый».\nТихое место для разговоров, устроенное так, чтобы никто не подглядывал.';

  @override
  String get whyKryfoRoutedThroughTor => 'Маршрут через tor';

  @override
  String get whyKryfoByDefaultEveryMessage =>
      'По умолчанию каждое сообщение идёт через tor — цепочку ретрансляторов. Никто — ни мы, ни твоя сеть — не может видеть, с кем ты общаешься и где находишься.';

  @override
  String get whyKryfoEndToEndEncrypted => 'сквозное шифрование';

  @override
  String get whyKryfoMessagesAreSealedWith =>
      'Сообщения зашифрованы ключами, которые есть только у тебя и твоего собеседника. Мы не смогли бы их прочитать, даже если бы попытались.';

  @override
  String get whyKryfoNoServersHoldingYour => 'Никаких серверов с твоей жизнью';

  @override
  String get whyKryfoNoAccountNoPhone =>
      'Ни аккаунта, ни номера телефона, ни центрального сервера, хранящего твои чаты. Они живут на этом телефоне, в зашифрованном виде.';

  @override
  String get whyKryfoNothingLeaks => 'ничего не утекает';

  @override
  String get whyKryfoNoReadReceiptsOr =>
      'Никому не передаются отметки о прочтении или наборе текста, список контактов никуда не загружается. Большинство приложений сливают метаданные — kryfo сделан так, чтобы этого не делать.';

  @override
  String get whyKryfoVerifyItIsReally => 'Убедись, что это тот самый человек';

  @override
  String get whyKryfoCompareASafetyNumber =>
      'сверь код безопасности лично или по каналу, которому доверяешь, — так ты будешь знать, что никто не выдаёт себя за твой контакт.';

  @override
  String get whyKryfoTheHonestPart => 'Если честно';

  @override
  String get whyKryfoKryfoIsPreAlpha =>
      'Kryfo — пре-альфа, и аудита ещё не было. Криптография настоящая, но ни один внешний эксперт её пока не проверял, так что считай это работой в процессе, а не тем, чему можно доверить свою жизнь.';

  @override
  String get cleanerLocation => 'Местоположение';

  @override
  String get cleanerAlreadyBlankedByAndroid => 'уже стёрто Android';

  @override
  String get cleanerPhoneModel => 'Модель телефона';

  @override
  String get cleanerTimeTaken => 'Время съёмки';

  @override
  String get cleanerSerialNumber => 'Серийный номер';

  @override
  String get cleanerOwnerName => 'Имя владельца';

  @override
  String get cleanerHiddenThumbnail => 'Скрытая миниатюра';

  @override
  String get cleanerContentCredentials => 'Учётные данные контента';

  @override
  String get cleanerDataAfterThePicture => 'Данные после картинки';

  @override
  String cleaner1OtherField(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ещё $countString поля',
      many: 'Ещё $countString полей',
      few: 'Ещё $countString поля',
      one: 'Ещё $countString поле',
    );
    return '$_temp0';
  }

  @override
  String get lockWordsFourRandomWordsBeat =>
      'Четыре случайных слова лучше одного хитрого.';

  @override
  String lockWordsTooShortAtLeast(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Слишком коротко. Минимум $countString символа.',
      many: 'Слишком коротко. Минимум $countString символов.',
      few: 'Слишком коротко. Минимум $countString символа.',
      one: 'Слишком коротко. Минимум $countString символ.',
    );
    return '$_temp0';
  }

  @override
  String get lockWordsWeakWhoeverGetsThe =>
      'Слабый. Тот, к кому попадёт файл, может подбирать пароль с любой скоростью.';

  @override
  String get lockWordsFairLongerIsStronger =>
      'Средний. Чем длиннее, тем надёжнее.';

  @override
  String get lockWordsStrongFourRandomWords =>
      'Надёжный. Четыре случайных слова лучше одного хитрого.';

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
      many: '$countString метров',
      few: '$countString метра',
      one: '$countString метр',
    );
    return '$_temp0';
  }

  @override
  String get photoStoryFarFromAnyTown => 'Далеко от городов';

  @override
  String photoStoryNear(Object where) {
    return 'Рядом: $where';
  }

  @override
  String photoStoryAboutKmFrom(Object near, Object where) {
    return '$where, примерно в $near км';
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
  String get photoStoryNotAKindKryfo => 'Kryfo не умеет читать такие файлы.';

  @override
  String get photoStorySoItWillNot => 'Поэтому гадать не будет.';

  @override
  String get photoStoryThisFileIsDamaged => 'Этот файл повреждён или обрезан.';

  @override
  String get photoStoryKryfoCouldNotRead =>
      'Kryfo не удалось дочитать его до конца.';

  @override
  String get photoStoryWhereItWasRecorded => 'Где сделана запись';

  @override
  String get photoStoryWhereItWasTaken => 'Где сделано фото';

  @override
  String photoStoryLocation(Object coordsLine) {
    return 'Местоположение: $coordsLine';
  }

  @override
  String photoStoryHeightAboveTheSea(Object fix) {
    return 'Высота над уровнем моря: $fix м';
  }

  @override
  String get photoStoryLocationHiddenByAndroid =>
      'Местоположение скрыто Android';

  @override
  String get photoStoryAndroidBlanksItWhen =>
      'Android стирает его, когда фото выбирают таким способом. Если поделиться фото с kryfo из галереи, оно часто сохраняется. В фото в галерее оно ещё может быть.';

  @override
  String get photoStoryLocationBlankedByAndroid =>
      'Местоположение: стёрто Android до того, как kryfo его увидел';

  @override
  String photoStoryF(Object r) {
    return 'f/$r';
  }

  @override
  String get photoStoryWhatTookIt => 'Чем снято';

  @override
  String photoStoryPhoneOrCamera(Object phone) {
    return 'Телефон или камера: $phone';
  }

  @override
  String get photoStoryWhenItWasRecorded => 'Когда сделана запись';

  @override
  String get photoStoryToTheSecondWith => 'До секунды, с часовым поясом';

  @override
  String get photoStoryToTheSecond => 'До секунды';

  @override
  String photoStoryTime(Object dateFormat) {
    return 'Время: $dateFormat';
  }

  @override
  String get photoStoryLens => 'Объектив';

  @override
  String photoStoryLens2(Object lens) {
    return 'Объектив: $lens';
  }

  @override
  String get photoStorySoftware => 'Программа';

  @override
  String photoStorySoftware2(Object software) {
    return 'Программа: $software';
  }

  @override
  String get photoStorySerialNumber => 'Серийный номер';

  @override
  String photoStorySerialNumber2(Object serial) {
    return 'Серийный номер: $serial';
  }

  @override
  String get photoStoryOwnerName => 'Имя владельца';

  @override
  String photoStoryOwner(Object r) {
    return 'Владелец: $r';
  }

  @override
  String get photoStoryHiddenThumbnail => 'Скрытая миниатюра';

  @override
  String get photoStoryASmallCopyOf =>
      'Маленькая копия картинки внутри файла. По ней видно, что было обрезано';

  @override
  String get photoStoryMakerNotes => 'Заметки производителя';

  @override
  String get photoStoryMakerNotesABlock =>
      'Заметки производителя: блок, который может прочитать только производитель';

  @override
  String get photoStoryEditingHistory => 'История правок';

  @override
  String get photoStoryXmpEditingHistoryAnd => 'XMP: история правок и теги';

  @override
  String get photoStoryCaptions => 'Подписи';

  @override
  String get photoStoryIptcCaptionsAndCredits => 'IPTC: подписи и авторство';

  @override
  String get photoStoryComment => 'Комментарий';

  @override
  String get photoStoryAWrittenComment => 'Текстовый комментарий';

  @override
  String get photoStoryContentCredentials => 'Учётные данные контента';

  @override
  String get photoStorySecondPicture => 'Вторая картинка';

  @override
  String get photoStoryASecondPictureInside => 'Вторая картинка внутри файла';

  @override
  String get photoStoryMotionVideo => 'Видео движения';

  @override
  String get photoStoryAShortVideoInside => 'Короткое видео внутри файла';

  @override
  String get photoStorySaveTime => 'Время сохранения';

  @override
  String get photoStoryTheTimeItWas => 'Когда файл сохранили в последний раз';

  @override
  String get photoStoryTimeStamps => 'Метки времени';

  @override
  String get photoStoryCreationTimeStamps => 'Метки времени создания';

  @override
  String get photoStoryDataAfterThePicture => 'Данные после картинки';

  @override
  String photoStoryDataAfterTheEnd(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Данные после конца картинки: $countString байта',
      many: 'Данные после конца картинки: $countString байт',
      few: 'Данные после конца картинки: $countString байта',
      one: 'Данные после конца картинки: $countString байт',
    );
    return '$_temp0';
  }

  @override
  String photoStoryTextField(Object k) {
    return 'Текстовое поле: $k';
  }

  @override
  String photoStoryVideoTag(Object k) {
    return 'Тег видео: $k';
  }

  @override
  String photoStoryAlso(Object k) {
    return 'Ещё: $k';
  }

  @override
  String photoStoryCameraSettingsFlashFocus(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString настройки камеры (вспышка, фокус, экспозиция)',
      many: '$countString настроек камеры (вспышка, фокус, экспозиция)',
      few: '$countString настройки камеры (вспышка, фокус, экспозиция)',
      one: '$countString настройка камеры (вспышка, фокус, экспозиция)',
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
      other: 'Ещё $countString поля',
      many: 'Ещё $countString полей',
      few: 'Ещё $countString поля',
      one: 'Ещё $countString поле',
    );
    return '$_temp0';
  }

  @override
  String get photoStoryCameraSettings => 'Настройки камеры';

  @override
  String photoStoryAccurateToAbout(Object metres) {
    return 'Точность: примерно $metres.';
  }

  @override
  String get photoStoryEnoughToFindThe => 'Хватит, чтобы найти дверь.';

  @override
  String get photoStoryEnoughToFindTheStreet => 'Хватит, чтобы найти улицу.';

  @override
  String get photoStoryEnoughToFindTheArea => 'Хватит, чтобы найти район.';

  @override
  String get photoStoryItKnowsWhereYou => 'Оно знает твоё местоположение.';

  @override
  String get photoStoryDownToTheBuilding => 'С точностью до здания.';

  @override
  String get photoStoryAndroidHidTheLocation => 'Android скрыл местоположение.';

  @override
  String get photoStoryTheOriginalMayStill => 'В оригинале оно ещё может быть.';

  @override
  String get photoStoryNoLocationInThis => 'Местоположения здесь нет.';

  @override
  String get photoStoryItStillSaysPlenty => 'Но и так говорит немало.';

  @override
  String get photoStoryThisOneKnowsNothing => 'Это фото ничего не знает.';

  @override
  String get photoStoryNothingToRemove => 'Удалять нечего.';

  @override
  String get qrPayloadOpensALink => 'ОТКРЫВАЕТ ССЫЛКУ';

  @override
  String qrPayloadOpens(Object host) {
    return 'ОТКРЫВАЕТ $host';
  }

  @override
  String get qrPayloadShowsANote => 'ПОКАЗЫВАЕТ ЗАМЕТКУ';

  @override
  String get qrPayloadScanToJoin => 'ПОДКЛЮЧАЕТ К СЕТИ';

  @override
  String qrPayloadScanToJoin2(Object oneLine) {
    return 'ПОДКЛЮЧАЕТ К СЕТИ · $oneLine';
  }

  @override
  String get qrPayloadANetworkNameIs => 'Имя сети — не больше 32 символов.';

  @override
  String get qrPayloadAWiFiPassword => 'Пароль Wi-Fi — не меньше 8 символов.';

  @override
  String get qrPayloadSavesAContact => 'СОХРАНЯЕТ КОНТАКТ';

  @override
  String get qrPayloadWritesAnEmail => 'ПИШЕТ ПИСЬМО';

  @override
  String get qrPayloadThatDoesNotLook => 'Это не похоже на адрес почты.';

  @override
  String get qrPayloadCallsANumber => 'ЗВОНИТ НА НОМЕР';

  @override
  String get qrPayloadWritesAText => 'ПИШЕТ SMS';

  @override
  String get qrPayloadOpensAMap => 'ОТКРЫВАЕТ КАРТУ';

  @override
  String get qrPayloadLatitudeRunsFrom90 =>
      'Широта — от -90 до 90, долгота — от -180 до 180.';

  @override
  String get qrPayloadPayThisAddress => 'ОПЛАТА НА ЭТОТ АДРЕС';

  @override
  String get qrPayloadABitcoinAddressIs =>
      'Адрес bitcoin состоит только из букв и цифр.';

  @override
  String get qrPayloadTheAmountIsIn =>
      'Сумма в BTC, не больше 8 знаков после запятой.';

  @override
  String vouchTextAnd(Object names, Object names2) {
    return '$names и $names2';
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
      other: '$restString знакомого',
      many: '$restString знакомых',
      few: '$restString знакомых',
      one: '$restString знакомый',
    );
    return '$names, $names2 и ещё $_temp0';
  }

  @override
  String vouchTextVouchedBy(Object vouchNames) {
    return 'Рекомендовали: $vouchNames';
  }

  @override
  String vouchTextIntroducedBy(Object vouchNames) {
    return 'Вас познакомили: $vouchNames';
  }

  @override
  String vouchTextThisSharesSAddress(Object a, Object b) {
    return 'Это передаст адрес контакта $a контакту $b';
  }

  @override
  String get bootFailedKryfoCouldNotStart => 'Kryfo не запустился';

  @override
  String get bootFailedThisIsAFault =>
      'Это сбой на этом устройстве, а не в сети. Tor тут ни при чём.';

  @override
  String get kryfoLinkTextThatLinkIsNot =>
      'Эту ссылку kryfo прочитать не может';

  @override
  String kryfoLinkTextAdd(Object who) {
    return 'Добавить контакт $who?';
  }

  @override
  String kryfoLinkTextThisIsAnInvite(Object who) {
    return 'Это приглашение пообщаться от пользователя $who. Добавляй, только если знаешь, откуда эта ссылка.';
  }

  @override
  String get kryfoLinkTextAddThem => 'Добавить';

  @override
  String get kryfoLinkTextNotNow => 'Не сейчас';

  @override
  String kryfoLinkTextJoin(Object roomName) {
    return 'Войти в «$roomName»';
  }

  @override
  String get kryfoLinkTextKryfoLink => 'ссылка kryfo';

  @override
  String kryfoLinkTextAdd2(Object who) {
    return 'Добавить: $who';
  }

  @override
  String get kryfoLinkTextBurnerRoom => 'ОДНОРАЗОВАЯ КОМНАТА';

  @override
  String get kryfoLinkTextThisRoomHasClosed => 'Эта комната закрыта';

  @override
  String kryfoLinkTextClosesIn(Object time) {
    return 'Закроется через $time';
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
      other: 'Закроется через $time · до $capString человека',
      many: 'Закроется через $time · до $capString человек',
      few: 'Закроется через $time · до $capString человек',
      one: 'Закроется через $time · до $capString человека',
    );
    return '$_temp0';
  }

  @override
  String get kryfoLinkTextJoin2 => 'Войти';

  @override
  String get kryfoLinkTextYouJoinUnderA =>
      'Ты входишь под ключом, созданным для этой комнаты. Никто в ней не видит твой kryfo ID.';

  @override
  String get linkStubFetchedOverTorBy =>
      'Загружено через tor · твоим устройством';

  @override
  String get linkStubFetchedOverTorByTheirDevice =>
      'Загружено через tor · устройством собеседника';

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
  String get mediaBubblesAudioUnavailable => 'Аудио недоступно';

  @override
  String get mediaBubblesHidden => 'Скрыто';

  @override
  String get mediaBubblesMicPermissionNeeded => 'Нужен доступ к микрофону';

  @override
  String get mediaBubblesReleaseToCancel => 'Отпусти, чтобы отменить';

  @override
  String get mediaBubblesVoiceHiddenSlideTo =>
      'Голос скрыт · смахни для отмены';

  @override
  String get mediaBubblesSlideToCancel => 'Смахни для отмены';

  @override
  String get mediaBubblesSendPhoto => 'Отправить фото';

  @override
  String get mediaBubblesAddACaption => 'Добавь подпись…';

  @override
  String get motionStandby => 'ОЖИДАНИЕ';

  @override
  String get motionConnecting => 'ПОДКЛЮЧЕНИЕ';

  @override
  String get motionBuilding => 'ПОСТРОЕНИЕ';

  @override
  String get motionPublishing => 'ПУБЛИКАЦИЯ';

  @override
  String get motionReady => 'ГОТОВО';

  @override
  String get motionPreparingToConnect => 'Готовимся к подключению';

  @override
  String get motionFindingAPrivatePath => 'Ищем приватный путь';

  @override
  String get motionCarvingThePath => 'Прокладываем путь';

  @override
  String get motionAnnouncingYourArrival => 'Сообщаем о твоём появлении';

  @override
  String get motionYouReAnonymous => 'ты инкогнито';

  @override
  String get motionTorIsStartingIn =>
      'Tor запускается в фоне. Этот граф загорается по мере того, как складывается подключение.';

  @override
  String get motionMakingAFreshRoute =>
      'Строим новый маршрут через анонимные ретрансляторы.';

  @override
  String get motionBouncingThroughRelaysSo =>
      'Прыгаем по ретрансляторам, чтобы никто не смог отследить это до тебя.';

  @override
  String get motionTellingTheNetworkYou =>
      'сообщаем сети, что ты онлайн, — не раскрывая, где ты.';

  @override
  String get motionYourIpIsHidden =>
      'Твой IP скрыт. Связаться с тобой могут только те, у кого есть твой kryfo.';

  @override
  String get motionBuilding2 => 'строится';

  @override
  String get motionOpen => 'открыта';

  @override
  String get motionLive => 'активна';

  @override
  String motionCircuit(Object circuit) {
    return 'Цепочка · *$circuit*';
  }

  @override
  String get motionDelivered => 'доставлено';

  @override
  String get motionSent => 'отправлено';

  @override
  String get motion1Hop => '1 узел';

  @override
  String get motion3Hops => '3 узла';

  @override
  String get movedStripThisKryfoHasMoved =>
      'Этот kryfo переехал на другое устройство. Ничто отправленное отсюда ни до кого не доходит.';

  @override
  String get navBarChats => 'Чаты';

  @override
  String get navBarTools => 'Инструменты';

  @override
  String get navBarSupport => 'Поддержать';

  @override
  String get navBarMe => 'Я';

  @override
  String get pairCodePanelPuttingYourInviteIn => 'Готовим твоё приглашение';

  @override
  String get pairCodePanelYourInviteIsNot => 'Твоё приглашение ещё не готово';

  @override
  String get pairCodePanelReadSixDigitsOut =>
      'Продиктуй шесть цифр — и тебя смогут добавить. Больше ничего передавать не нужно.';

  @override
  String get pairCodePanelWorking => 'Работаем';

  @override
  String get pairCodePanelOrMakeASix =>
      'Или создай шестизначный код, чтобы продиктовать';

  @override
  String get pairCodePanelCodeCopied => 'Код скопирован';

  @override
  String pairCodePanelBurnsIn(Object mm, Object ss) {
    return 'Сгорит через $mm:$ss';
  }

  @override
  String get pairCodePanelTheyTapAddChoose =>
      'Собеседник нажимает «Добавить», выбирает код и вводит эти цифры.';

  @override
  String get pairCodePanelTheyOpenKryfoTap =>
      'Собеседник открывает kryfo, нажимает «Добавить», выбирает «Код связи» и вводит эти шесть цифр. Для следующего человека создай новый.';

  @override
  String pinsPinnedMessages(Object count) {
    return 'Закреплённые сообщения · $count';
  }

  @override
  String get pinsPinnedMessages2 => 'Закреплённые сообщения';

  @override
  String get pinsPhoto => 'Фото';

  @override
  String get pinsVoiceMessage => 'Голосовое сообщение';

  @override
  String get pinsMessage => 'Сообщение';

  @override
  String pinsToday(Object hm) {
    return 'Сегодня · $hm';
  }

  @override
  String get pinsPinned => 'Закреплено';

  @override
  String pinsOf(Object pinsLength, Object kMaxPins) {
    return '$pinsLength из $kMaxPins';
  }

  @override
  String get pinsNothingPinnedHereYet =>
      'Здесь пока ничего не закреплено. Удерживай сообщение и выбери «Закрепить» — и оно будет ждать здесь всех в чате.';

  @override
  String get pinsJump => 'Перейти';

  @override
  String get pinsUnpin => 'Открепить';

  @override
  String powNoteFirstMessageToSomeone(int secs) {
    final intl.NumberFormat secsNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String secsString = secsNumberFormat.format(secs);

    return 'Первое сообщение новому человеку · доказываем, что оно настоящее · $secsString с';
  }

  @override
  String powNoteFirstMessageSlow(int secs) {
    final intl.NumberFormat secsNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String secsString = secsNumberFormat.format(secs);

    return 'Первое сообщение новому человеку · доказываем, что оно настоящее · $secsString с · на медленном телефоне до минуты';
  }

  @override
  String previewStripFetchedOverTor(Object domainOf) {
    return '$domainOf · загружено через tor';
  }

  @override
  String get previewStripDropThePreview => 'Убрать превью';

  @override
  String get previewStripAddPreview => 'Добавить превью';

  @override
  String get previewStripFetchingOverTor => 'Загружаем через tor…';

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
  String get torBootSplashNoShortcutsNoTraces => 'Без компромиссов, без следов';

  @override
  String get torBootSplashTheNetworkThatKeeps =>
      'Сеть, которая хранит твою приватность, разогревается';

  @override
  String get torBootSplashMadeOnThisPhone =>
      'Создано на этом телефоне. Ничего никуда не отправляется.';

  @override
  String get torBootSplashFirstLaunchTakesA =>
      'Первый запуск занимает немного времени · только при старте';

  @override
  String get videoBubbleNothingHereOpensThat =>
      'Здесь это не открыть · открываем «Поделиться»';

  @override
  String videoBubbleMb(Object b) {
    return '$b МБ';
  }

  @override
  String videoBubbleKb(Object b) {
    return '$b КБ';
  }

  @override
  String get videoBubbleVideo => 'Видео';

  @override
  String get notificationsChannelName => 'сообщения';

  @override
  String get cameraClose => 'Закрыть';

  @override
  String get cameraFlash => 'вспышка';

  @override
  String get cameraPhoto => 'фото';

  @override
  String get cameraVideo => 'видео';

  @override
  String get cameraRetake => 'переснять';

  @override
  String get seenIntroductions => 'знакомства';

  @override
  String get donateAddress => 'адрес';

  @override
  String get donateCopy => 'копировать';

  @override
  String get donateDone => 'Готово';

  @override
  String get donateTierSupporter => 'сторонник';

  @override
  String get donateTierPatron => 'меценат';

  @override
  String get donateTierGuardian => 'хранитель';

  @override
  String get chatBlock => 'заблокировать';

  @override
  String get chatDecline => 'отклонить';

  @override
  String get chatAccept => 'принять';

  @override
  String get bridgesConnecting => 'подключение';

  @override
  String get restoreMade => 'создана';

  @override
  String get restoreContacts => 'контакты';

  @override
  String get restoreMessages => 'сообщения';

  @override
  String get restoreAttachments => 'вложения';

  @override
  String get shieldBlock => 'заблокировать';

  @override
  String get shieldDelete => 'Удалить';

  @override
  String get shieldIgnore => 'игнорировать';

  @override
  String get profileIdentity => 'профиль';

  @override
  String get avatarPickerShape => 'Форма';

  @override
  String get avatarPickerColour => 'Цвет';

  @override
  String get avatarPickerTurn => 'Поворот';

  @override
  String get transportStatus => 'статус';

  @override
  String get transportBootstrap => 'загрузка';

  @override
  String get transportNetwork => 'сеть';

  @override
  String get transportConnectivity => 'связность';

  @override
  String get transportRelays => 'ретрансляторы';

  @override
  String get transportTraffic => 'трафик';

  @override
  String get transportContacts => 'контакты';

  @override
  String get transportKnown => 'известно';

  @override
  String get transportListening => 'слушает';

  @override
  String get transportMemory => 'память';

  @override
  String get settingsConnected => 'Подключено';

  @override
  String get settingsScreenshots => 'Скриншоты';

  @override
  String get settingsBlocked2 => 'Запрещены';

  @override
  String get settingsAllowed => 'Разрешены';

  @override
  String get settingsOn => 'Вкл.';

  @override
  String get settingsOff => 'Выкл.';

  @override
  String get settingsNotifications => 'Уведомления';

  @override
  String get settingsPrivacy => 'Приватность';

  @override
  String get settingsSecurity => 'Безопасность';

  @override
  String get settingsBackup => 'Резервная копия';

  @override
  String get settingsVoice => 'Голос';

  @override
  String get settingsAbout => 'О приложении';

  @override
  String get wallpaperGradients => 'градиенты';

  @override
  String get wallpaperPatterns => 'узоры';

  @override
  String get confirmSheetKeep => 'Оставить';

  @override
  String get confirmSheetSave => 'Сохранить';

  @override
  String get confirmSheetCancel => 'Отмена';

  @override
  String bridgesSaved(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString моста',
      many: '$countString мостов',
      few: '$countString моста',
      one: '$countString мост',
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

    return 'Принято: $goodString, не распознано: $badString';
  }

  @override
  String get languageTitle => 'Язык';

  @override
  String get languageMatchPhone => 'Как на телефоне';

  @override
  String languageMatchPhoneValue(Object language) {
    return 'Как на телефоне ($language)';
  }

  @override
  String get languageRedrawLine =>
      'Kryfo перерисуется на новом языке и откроет твои чаты.';

  @override
  String languageButton(Object language) {
    return 'Язык: $language';
  }

  @override
  String get androidServiceTitle => 'kryfo включён';

  @override
  String get androidServiceText =>
      'твоё зашифрованное соединение остаётся открытым, чтобы сообщения доходили';

  @override
  String get androidChannelName => 'постоянная связь';

  @override
  String get androidChannelDescription =>
      'держит kryfo на связи, чтобы зашифрованные сообщения приходили, пока он закрыт. если выключить, доставка прекратится.';

  @override
  String get videoViewerPlay => 'Воспроизвести';

  @override
  String get videoViewerPause => 'Пауза';

  @override
  String get videoViewerPlayAgain => 'Смотреть снова';

  @override
  String get videoViewerCannotPlay =>
      'Этот телефон не может воспроизвести это видео здесь.';

  @override
  String get videoViewerOpenElsewhere => 'Открыть в другом приложении';

  @override
  String get photoKnowsLookedFor => 'Что искали';

  @override
  String get photoKnowsNotInIt => 'нет';

  @override
  String get languageNameEn => 'Английский';

  @override
  String get languageNameDe => 'Немецкий';

  @override
  String get languageNameFr => 'Французский';

  @override
  String get languageNameEs => 'Испанский';

  @override
  String get languageNamePt => 'Португальский (Бразилия)';

  @override
  String get languageNameIt => 'Итальянский';

  @override
  String get languageNameRu => 'Русский';

  @override
  String get languageNameUk => 'Украинский';

  @override
  String get languageNameTr => 'Турецкий';

  @override
  String get languageNameZh => 'Китайский (упрощённый)';

  @override
  String get languageNameZhHant => 'Китайский (традиционный)';

  @override
  String get languageNameVi => 'Вьетнамский';

  @override
  String get languageNameId => 'Индонезийский';

  @override
  String get languageNameFa => 'Персидский';

  @override
  String get languageNameAr => 'Арабский';

  @override
  String get languageLaterLine =>
      'Язык можно поменять в настройках в любой момент.';

  @override
  String get pollAttach => 'Опрос';

  @override
  String get pollNewTitle => 'Новый опрос';

  @override
  String get pollQuestionHint => 'Спроси что-нибудь у группы';

  @override
  String get pollOptionsLabel => 'Варианты';

  @override
  String pollOptionHint(Object n) {
    return 'Вариант $n';
  }

  @override
  String get pollAddOption => 'Добавить вариант';

  @override
  String get pollMaxLine => 'Не больше двенадцати вариантов.';

  @override
  String get pollMultiple => 'Несколько ответов';

  @override
  String get pollMultipleLine => 'Можно выбрать больше одного.';

  @override
  String get pollSend => 'Отправить опрос';

  @override
  String get pollKind => 'Опрос';

  @override
  String get pollKindMulti => 'Опрос · несколько ответов';

  @override
  String get pollKindClosed => 'Итоги';

  @override
  String pollVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count голоса',
      many: '$count голосов',
      few: '$count голоса',
      one: '$count голос',
      zero: 'Пока никто не голосовал',
    );
    return '$_temp0';
  }

  @override
  String get pollVote => 'Голосовать';

  @override
  String get pollTakeBack => 'Отозвать мой голос';

  @override
  String get pollClose => 'Завершить опрос';

  @override
  String get pollCloseTitle => 'Завершить этот опрос?';

  @override
  String get pollCloseLine =>
      'Все увидят итоги, и голосовать больше будет нельзя.';

  @override
  String get pollCloseYes => 'Завершить';

  @override
  String pollPreview(Object question) {
    return 'Опрос: $question';
  }

  @override
  String get pollWhoVoted => 'Кто голосовал';

  @override
  String get pollNobody => 'Пока никого';

  @override
  String get pollYou => 'Ты';

  @override
  String pollOptionA11y(Object option, Object share) {
    return '$option, $share';
  }

  @override
  String get pollPickOne => 'Выбери один';

  @override
  String get pollPickSeveral => 'Выбери один или несколько';

  @override
  String get searchOpen => 'Поиск';

  @override
  String get searchHint => 'Искать в чатах и сообщениях';

  @override
  String get searchFilterAll => 'Всё';

  @override
  String get searchFilterPhotos => 'Фото';

  @override
  String get searchFilterVideos => 'Видео';

  @override
  String get searchFilterFiles => 'Файлы';

  @override
  String get searchFilterLinks => 'Ссылки';

  @override
  String get searchChats => 'Чаты';

  @override
  String get searchMessages => 'Сообщения';

  @override
  String get searchIntroTitle => 'Ищи по своим чатам';

  @override
  String get searchIntroLine =>
      'Имена, слова, фото, файлы и ссылки. Поиск идёт на этом телефоне и ничего никуда не отправляет.';

  @override
  String get searchNothing => 'Ничего не найдено';

  @override
  String get searchNothingLine => 'Попробуй другое слово или другой фильтр.';

  @override
  String searchMatches(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count совпадения',
      many: '$count совпадений',
      few: '$count совпадения',
      one: '$count совпадение',
    );
    return '$_temp0';
  }

  @override
  String searchMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ещё $count',
      many: 'ещё $count',
      few: 'ещё $count',
      one: 'ещё $count',
    );
    return '$_temp0';
  }

  @override
  String searchFilling(Object share) {
    return 'Добавляю старые сообщения · $share';
  }

  @override
  String get searchClear => 'Очистить';

  @override
  String get handleShowInSearch => 'Показывать меня в поиске';

  @override
  String get handleShowInSearchLine =>
      'Кто угодно сможет найти это имя пользователя и написать тебе.';

  @override
  String handleShownAs(Object name) {
    return 'Показывается как $name';
  }

  @override
  String get handleNameInSearch => 'Имя в поиске';

  @override
  String get handleNameInSearchLine =>
      'Необязательно. Оно видно рядом с именем пользователя, когда кто-то ищет. Кто угодно сможет найти это имя пользователя и написать тебе.';

  @override
  String get handleNameHint => 'Твоё имя, или оставь пустым';

  @override
  String get handleShowMe => 'Показывать';

  @override
  String get handleSearchOff => 'Тебя больше нет в поиске';

  @override
  String handleSearchOn(Object handle) {
    return 'Ты в поиске как @$handle';
  }

  @override
  String get handleRegistryFailed =>
      'Реестр не ответил. Попробуй через минуту.';

  @override
  String get searchPeople => 'Люди';

  @override
  String searchPeopleAsk(Object query) {
    return 'Искать «$query» среди публичных имён пользователей';
  }

  @override
  String get searchPeopleLine =>
      'Запрос идёт через Tor. Реестр ничего о нём не хранит.';

  @override
  String get searchPeopleNone => 'Ни одно публичное имя не подходит';

  @override
  String get searchPeopleOffline => 'Tor ещё не готов';

  @override
  String get searchPeopleBusy =>
      'Сейчас слишком много запросов. Попробуй чуть позже.';

  @override
  String get searchPeopleUnreachable => 'Реестр не ответил';

  @override
  String get peopleVerified => 'Подтверждённое имя пользователя';

  @override
  String get peopleAdd => 'Добавить';

  @override
  String peopleFingerprint(Object fp) {
    return 'Отпечаток ключа · $fp';
  }

  @override
  String get peopleFingerprintLine =>
      'Сверь его с тем, что видно у собеседника в приложении.';

  @override
  String get peopleAdding => 'Добавляю…';

  @override
  String handleNobodyHasClaimed(Object handle) {
    return 'Никто не занял $handle';
  }

  @override
  String get handleThatHandleIsTaken => 'Это имя пользователя уже занято';
}
