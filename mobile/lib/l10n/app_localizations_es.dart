// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get atmosphereNone => 'Ninguna';

  @override
  String get atmosphereEmber => 'Brasa';

  @override
  String get atmosphereDusk => 'Ocaso';

  @override
  String get atmosphereMoss => 'Musgo';

  @override
  String get atmosphereRose => 'Rosa';

  @override
  String get atmosphereDots => 'Puntos';

  @override
  String get atmosphereGrid => 'Cuadrícula';

  @override
  String get atmosphereWaves => 'Olas';

  @override
  String get atmosphereRain => 'Lluvia';

  @override
  String get atmosphereLateNight => 'Madrugada';

  @override
  String get atmosphereWarmAfternoon => 'Tarde cálida';

  @override
  String get atmosphereSnow => 'Nieve';

  @override
  String get atmosphereDesert => 'Desierto';

  @override
  String get atmospherePaper => 'Papel';

  @override
  String get backupThatPassphraseDoesNot =>
      'Esa frase de contraseña no abre este archivo';

  @override
  String get backupThatFileIsNot =>
      'Ese archivo no es una copia de seguridad de Kryfo';

  @override
  String get backupThisBackupIsFrom =>
      'Esta copia de seguridad es de un Kryfo más nuevo. Actualiza la app y vuelve a intentarlo';

  @override
  String get backupThisFileIsDamaged =>
      'Este archivo está dañado y no se puede leer';

  @override
  String get backupCouldNotMakeThe => 'No se pudo crear la clave';

  @override
  String get contactCardMessageMeOn => 'Escríbeme en';

  @override
  String get contactCardScanItOrType =>
      'Escanéalo o escribe las tres palabras en Kryfo.\nEsta tarjeta no sabe nada más de ti.';

  @override
  String contactCardMessageMeOnKryfo(Object haloId) {
    return 'Escríbeme en Kryfo · $haloId';
  }

  @override
  String get contactStatusBlocked => 'Bloqueado';

  @override
  String get contactStatusKeysVerifiedInPerson =>
      'Claves verificadas en persona';

  @override
  String get contactStatusWaitingInRequests => 'Esperando en solicitudes';

  @override
  String get contactStatusAddedByHand => 'Añadido a mano';

  @override
  String get deliveryModeAlwaysOn => 'Siempre activo';

  @override
  String get deliveryModeCheckIns => 'Consultas';

  @override
  String get deliveryModeThroughAHelperApp => 'Con una app auxiliar';

  @override
  String get deliveryModeNotYet => 'aún no';

  @override
  String get deliveryModeJustNow => 'ahora mismo';

  @override
  String deliveryModeMinAgo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'hace $countString min',
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
      other: 'hace $countString horas',
      one: 'hace $countString hora',
    );
    return '$_temp0';
  }

  @override
  String get deliveryModeYesterday => 'ayer';

  @override
  String deliveryModeDaysAgo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'hace $countString días',
      one: 'hace $countString día',
    );
    return '$_temp0';
  }

  @override
  String get deliveryModeConnected => 'Conectado';

  @override
  String get deliveryModeConnecting => 'Conectando';

  @override
  String get deliveryModeNotConnected => 'Sin conexión';

  @override
  String get deliveryModeCheckingNow => 'Consultando ahora';

  @override
  String deliveryModeLastCheckIn(Object agoLine) {
    return 'última consulta $agoLine';
  }

  @override
  String get deliveryModeNoCheckInYet => 'ninguna consulta aún';

  @override
  String deliveryModeConnectedNow(Object last) {
    return 'Conectado ahora · $last';
  }

  @override
  String deliveryModeConnecting2(Object last) {
    return 'Conectando · $last';
  }

  @override
  String get deliveryModeNoCheckInYet2 => 'Ninguna consulta aún';

  @override
  String deliveryModeLastChecked(Object agoLine) {
    return 'Última consulta $agoLine';
  }

  @override
  String get deliveryModeAHelperApp => 'una app auxiliar';

  @override
  String deliveryModeWokenByNoWake(Object who) {
    return 'Activado por $who · aún sin activaciones';
  }

  @override
  String deliveryModeWokenByLastWake(Object who, Object agoLine) {
    return 'Activado por $who · última activación $agoLine';
  }

  @override
  String get introBudgetTomorrow => 'mañana';

  @override
  String introBudgetInDays(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'en $countString días',
      one: 'en $countString día',
    );
    return '$_temp0';
  }

  @override
  String get introBudgetInAnHour => 'en una hora';

  @override
  String introBudgetInHours(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'en $countString horas',
      one: 'en $countString hora',
    );
    return '$_temp0';
  }

  @override
  String get introBudgetInAFewMinutes => 'en unos minutos';

  @override
  String get lockStateUnlockKryfo => 'Desbloquear Kryfo';

  @override
  String get appInvalidUri => 'Uri no válida';

  @override
  String appBundleError(Object e) {
    return 'Error del paquete: $e';
  }

  @override
  String appAlreadySaved(Object parsed) {
    return 'Ya guardado: $parsed';
  }

  @override
  String appAddedYouCanMessage(Object parsed) {
    return '$parsed añadido · ya puedes escribirle';
  }

  @override
  String appPeerImportedV1(Object parsed) {
    return 'Contacto importado (v1): $parsed';
  }

  @override
  String appLongWindow(Object line) {
    return '$line ventana larga';
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
      other: '$pString páginas',
      one: '$pString página',
    );
    String _temp1 = intl.Intl.pluralLogic(
      e,
      locale: localeName,
      other: '$eString eventos',
      one: '$eString evento',
    );
    return '$line ($heldString de $subsString, conexión ${c}s, $_temp0, $_temp1)';
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
      other: '$pString páginas',
      one: '$pString página',
    );
    String _temp1 = intl.Intl.pluralLogic(
      e,
      locale: localeName,
      other: '$eString eventos',
      one: '$eString evento',
    );
    return '$line (conexión ${c}s, $_temp0, $_temp1)';
  }

  @override
  String appSDropped(Object host, Object secs) {
    return '$host ${secs}s cortado';
  }

  @override
  String appS(Object host, Object secs) {
    return '$host ${secs}s';
  }

  @override
  String get appTorWouldNotWake => 'Tor no arrancó';

  @override
  String get appCheckStarted => 'Iniciada';

  @override
  String get appTorNotReadyIn => 'Tor no estuvo listo en 75s';

  @override
  String get appOk => 'OK';

  @override
  String get appOkNoRelayBegan => 'OK, ningún repetidor empezó';

  @override
  String get appOkCapped => 'OK, al límite';

  @override
  String appSBy(Object how, int secs, String why) {
    final intl.NumberFormat secsNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String secsString = secsNumberFormat.format(secs);

    String _temp0 = intl.Intl.selectLogic(why, {
      'push': '$how, ${secsString}s, por push',
      'other': '$how, ${secsString}s, por tarea',
    });
    return '$_temp0';
  }

  @override
  String get appAnAttachmentCouldNot =>
      'No se pudo guardar un adjunto en este teléfono';

  @override
  String get appGroup2 => 'Grupo';

  @override
  String get appVoiceMessage => 'Mensaje de voz';

  @override
  String get appPhoto => 'Foto';

  @override
  String get appNewRequest => 'Nueva solicitud';

  @override
  String get appSomeoneYouHaveNot => 'Alguien que no has añadido te escribió';

  @override
  String get appSettingUpYourKeys => 'Preparando tus claves';

  @override
  String get appOpeningYourChats => 'Abriendo tus chats';

  @override
  String get appStartingTor => 'Iniciando Tor';

  @override
  String get appTimedMessagesAreNot =>
      'Los mensajes temporales no están desapareciendo. Reinicia Kryfo';

  @override
  String get appVoiceMessage2 => 'Mensaje de voz';

  @override
  String appYou(Object body) {
    return 'Tú: $body';
  }

  @override
  String get appThisRoomHasAlready => 'Esta sala ya expiró';

  @override
  String get appYouAreAlreadyIn => 'Ya estás en esta sala';

  @override
  String get appCouldNotMakeA => 'No se pudo crear una clave de sala';

  @override
  String appJoinedButYourHello(Object linkName) {
    return 'Te uniste a $linkName, pero tu saludo quedó retenido';
  }

  @override
  String appJoined(Object linkName) {
    return 'Te uniste a $linkName';
  }

  @override
  String appJoinedButTheCreator(Object linkName) {
    return 'Te uniste a $linkName, pero aún no se pudo contactar con quien la creó';
  }

  @override
  String get appBooting => 'Arrancando...';

  @override
  String get appSettingUpYourIdentity => 'Preparando tu identidad...';

  @override
  String get appAddSomeone => 'Añadir a alguien';

  @override
  String get appScanTheirCodeOr =>
      'Escanea su código o pega lo que te dio: un enlace, un nombre de usuario con @ o un enlace de sala.';

  @override
  String get appScanTheirCode => 'Escanear su código';

  @override
  String get appAKryfoLinkA => 'Un enlace de Kryfo, de sala o @wren';

  @override
  String get appAddThem => 'Añadir';

  @override
  String get appEveryWayToAdd => 'Todas las formas de añadir';

  @override
  String get appShowYourCodeSend =>
      'Muestra tu código, envía un enlace, reserva un nombre de usuario';

  @override
  String get appHelloFromTheOther => 'Hola desde el otro lado';

  @override
  String get appIdentityRestored => 'Identidad restaurada';

  @override
  String get appIdentityCreated => 'Identidad creada';

  @override
  String get appStartingTor30s => 'Iniciando tor (~30s)...';

  @override
  String get appScanOrImportA => 'Primero escanea o importa un contacto';

  @override
  String get appEncryptingSending30s => 'Cifrando + enviando (~30s)...';

  @override
  String get appTapStartListeningFirst => 'Primero toca «Empezar a escuchar»';

  @override
  String get appYourKryfo => 'Tu Kryfo';

  @override
  String get appUriCopied => 'Uri copiada';

  @override
  String get appCopyUri => 'Copiar uri';

  @override
  String get appAddAKryfo => 'Añadir un Kryfo';

  @override
  String get appScanQr => 'Escanear QR';

  @override
  String get appPairingCode => 'Código de emparejamiento';

  @override
  String get appOrPaste => '- O pega -';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get appImport => 'Importar';

  @override
  String get appDev => 'Dev';

  @override
  String get appYourKryfo2 => 'Tu Kryfo:';

  @override
  String get appRestoredFromDisk => 'Restaurado desde el disco';

  @override
  String get appStartListening => 'Empezar a escuchar';

  @override
  String get appListening => 'Escuchando';

  @override
  String get appShowMyQr => 'Mostrar mi QR';

  @override
  String get appImportPeer => 'Importar contacto';

  @override
  String get appPeer => 'Contacto:';

  @override
  String get appMessageWillBeEncrypted => 'Mensaje (se cifrará)';

  @override
  String get appEncryptSend => 'Cifrar + enviar';

  @override
  String appStatus(Object status) {
    return 'Estado: $status';
  }

  @override
  String get appSpeedPrivacy => 'Velocidad y privacidad →';

  @override
  String get appGettingMessages => 'Recibir mensajes →';

  @override
  String get appDisableAppLock => '¿Desactivar el bloqueo?';

  @override
  String get appThePinWillBe =>
      'Se quitará el PIN. Cualquiera que tenga tu teléfono verá Kryfo al abrirlo.';

  @override
  String get appDisable => 'Desactivar';

  @override
  String get appAppLockOn => 'Bloqueo · activado →';

  @override
  String get appAppLockOff => 'Bloqueo · desactivado →';

  @override
  String get appTorIsOff => 'Tor desactivado';

  @override
  String get appConnectedRoutedThrough3 =>
      'Conectado · a través de 3 repetidores';

  @override
  String get appReadyToSendPublishing =>
      'Listo para enviar · publicando tu dirección';

  @override
  String get appReadyToSendFinishing =>
      'Listo para enviar · terminando la configuración';

  @override
  String appConnecting(Object pct) {
    return 'Conectando · $pct';
  }

  @override
  String get appTor => 'Tor';

  @override
  String get appTorIsOffTurn =>
      'Tor está desactivado. Actívalo para conectarte en privado.';

  @override
  String get appTheFirstConnectionTakes =>
      'La primera conexión tarda un minuto o dos mientras tor construye una ruta privada. Después queda en caché, así que abrir Kryfo más tarde es mucho más rápido.';

  @override
  String get appRelayAndFastModes =>
      'Los modos Repetidor y Rápido se saltan tor y van más rápido. Están en ajustes, en velocidad y privacidad, y cada uno dice lo que cuesta.';

  @override
  String get appViaRelay => 'Vía repetidor';

  @override
  String get appOffline => 'Sin conexión';

  @override
  String get appFast => 'Rápido';

  @override
  String get appTorOff => 'Tor desactivado';

  @override
  String get appTorReady => 'Tor listo';

  @override
  String get appConnecting2 => 'Conectando';

  @override
  String mediaProgressSendingKeepTheApp(Object v) {
    return 'Enviando · $v · deja la app abierta';
  }

  @override
  String mediaProgressPausedOfWaitingFor(Object count, Object count2) {
    return 'En pausa · $count de $count2 · esperando el resto';
  }

  @override
  String mediaProgressReceivingMedia(Object v) {
    return 'Recibiendo multimedia · $v';
  }

  @override
  String get mediaProgressCancelSending => 'Cancelar envío';

  @override
  String get metaReaderEndsBeforeItShould => 'termina antes de tiempo';

  @override
  String get metaReaderCouldNotBeRead => 'no se pudo leer';

  @override
  String get metaReaderExifThatCannotBe => 'exif que no se puede leer';

  @override
  String get metaReaderSamsungTrailer => 'bloque final de samsung';

  @override
  String metaReaderChunk(Object type) {
    return 'fragmento $type';
  }

  @override
  String get metaReaderExifFlagSet => 'marca exif activada';

  @override
  String get metaReaderXmpFlagSet => 'marca xmp activada';

  @override
  String metaReaderAppBlock(Object id) {
    return 'bloque de app $id';
  }

  @override
  String get metaReaderUuidBox => 'caja uuid';

  @override
  String metaReaderBox(Object printable) {
    return 'caja $printable';
  }

  @override
  String get metaReaderAttachedData => 'datos adjuntos';

  @override
  String metaReaderItem(Object printable) {
    return 'elemento $printable';
  }

  @override
  String get miuiAutostartAlreadyAllowedToRun =>
      'Ya puede funcionar en segundo plano';

  @override
  String get miuiAutostartLetKryfoRunIn =>
      'Deja que Kryfo funcione en segundo plano';

  @override
  String get miuiAutostartYourPhonePausesApps =>
      'Tu teléfono pausa las apps para ahorrar batería. Sin una excepción, Kryfo no puede recibir mensajes mientras está cerrado.';

  @override
  String get commonAllow => 'Permitir';

  @override
  String get commonSkip => 'Omitir';

  @override
  String get miuiAutostartXiaomiTurnsOffBackground =>
      'Xiaomi apaga las apps en segundo plano de forma predeterminada. Sin inicio automático, Kryfo no puede entregar mensajes cuando la app está cerrada. En la siguiente pantalla, busca Kryfo en la lista y activa el interruptor.';

  @override
  String get miuiAutostartOpenSettings => 'Abrir ajustes';

  @override
  String get miuiAutostartCouldnTOpenIt =>
      'No se pudo abrir. Busca inicio automático en los ajustes del teléfono';

  @override
  String get notificationsNewEncryptedMessagesFrom =>
      'Nuevos mensajes cifrados de tus contactos';

  @override
  String get notificationsNewMessage => 'Nuevo mensaje';

  @override
  String get notificationsNewEncryptedMessagesFromYourContacts =>
      'Nuevos mensajes cifrados de tus contactos';

  @override
  String get notificationsNewMessage2 => 'Nuevo mensaje';

  @override
  String get notificationsEncrypted => 'Cifrado';

  @override
  String get rooms24h => '24h';

  @override
  String roomsD(Object inDays) {
    return '${inDays}d';
  }

  @override
  String roomsH(Object inHours) {
    return '${inHours}h';
  }

  @override
  String get rooms24Hours => '24 horas';

  @override
  String roomsDays(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString días',
      one: '$countString día',
    );
    return '$_temp0';
  }

  @override
  String get roomsAnHour => 'una hora';

  @override
  String get roomsAboutAnHour => 'una hora aprox.';

  @override
  String roomsHours(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString horas',
      one: '$countString hora',
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
      other: 'unas $countString horas',
      one: '$countString hora aprox.',
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
      other: '$countString minutos',
      one: '$countString minuto',
    );
    return '$_temp0';
  }

  @override
  String get roomsAMinute => 'un minuto';

  @override
  String get roomsExpired => 'Expirada';

  @override
  String roomsDH(Object inDays, Object h) {
    return '${inDays}d ${h}h';
  }

  @override
  String roomsHM(Object inHours, Object m) {
    return '${inHours}h ${m}m';
  }

  @override
  String roomsM(Object inMinutes) {
    return '${inMinutes}m';
  }

  @override
  String get scamShieldLooksLikeAScam => 'Parece una estafa';

  @override
  String scamShieldThisNameMatches(Object shown) {
    return 'Este nombre coincide con $shown';
  }

  @override
  String scamShieldNameMatchesYourContact(Object shown) {
    return 'El nombre coincide con tu contacto $shown';
  }

  @override
  String scamShieldSameFaceAsYour(Object shown) {
    return 'La misma cara que tu contacto $shown';
  }

  @override
  String get scamShieldContainsACryptoAddress =>
      'Contiene una dirección cripto';

  @override
  String get scamShieldMentionsMoneyAndUrgency =>
      'Habla de dinero y de urgencia a la vez';

  @override
  String get scamShieldAsksYouToMove => 'Te pide pasar a otra app';

  @override
  String get scamShieldLinksToALookalike =>
      'Enlaza a una imitación de un sitio conocido';

  @override
  String get scamShieldALongOpenerFrom =>
      'Un primer mensaje largo de alguien sin historial';

  @override
  String get scamShieldAsksForACode =>
      'Pide un código, una frase semilla o un archivo de recuperación';

  @override
  String scamShieldAlso(Object shown) {
    return 'Además: el nombre coincide con tu contacto $shown';
  }

  @override
  String get commonBack => 'Atrás';

  @override
  String get archivedArchived => 'Archivados';

  @override
  String get archivedCount0 => 'Ninguno';

  @override
  String get archivedCount1 => 'Uno';

  @override
  String get archivedCount2 => 'Dos';

  @override
  String get archivedCount3 => 'Tres';

  @override
  String get archivedCount4 => 'Cuatro';

  @override
  String get archivedCount5 => 'Cinco';

  @override
  String get archivedCount6 => 'Seis';

  @override
  String get archivedCount7 => 'Siete';

  @override
  String get archivedCount8 => 'Ocho';

  @override
  String get archivedCount9 => 'Nueve';

  @override
  String get archivedCount10 => 'Diez';

  @override
  String get archivedChatRestingHereIt =>
      'Chat en reposo. Queda en silencio hasta que te escriban y luego vuelve arriba.';

  @override
  String get archivedChatsRestingHere =>
      'Chats en reposo. Quedan en silencio hasta que alguien escriba y luego vuelven arriba.';

  @override
  String get archivedNothingArchived => 'Nada archivado';

  @override
  String get archivedArchivedChatsAreStill =>
      'Los chats archivados siguen cifrados de extremo a extremo';

  @override
  String get archivedUnarchive => 'Desarchivar';

  @override
  String get avatarPickerThePeopleYouMessage =>
      'Las personas a las que escribes también la ven';

  @override
  String get avatarPickerBackToYourInitial => 'Volver a tu inicial';

  @override
  String get avatarPickerThatOneIsYours => 'Esa es la tuya';

  @override
  String get avatarPickerPickAFace => 'Elige una cara';

  @override
  String get commonSave => 'Guardar';

  @override
  String get backupPassphraseMustBeAt =>
      'La frase de contraseña debe tener al menos 6 caracteres';

  @override
  String get backupPassphrasesDonTMatch => 'Las frases no coinciden';

  @override
  String get backupBackupSavedKeepThe =>
      'Copia de seguridad guardada · guarda bien la frase de contraseña';

  @override
  String get backupKryfoBackup => 'Copia de seguridad de Kryfo';

  @override
  String get backupYourEncryptedKryfoBackup =>
      'Tu copia de seguridad cifrada de Kryfo. Guarda bien este archivo Y tu frase de contraseña: necesitas los dos para restaurar.';

  @override
  String get backupBackUpKryfo => 'Copia de seguridad';

  @override
  String get backupBackUp => 'Hacer una copia';

  @override
  String get backupACopyToKeep =>
      'Una copia para guardar. Este teléfono sigue como está.';

  @override
  String get backupMoveToAnotherDevice => 'Mudarse a otro dispositivo';

  @override
  String get backupTheFileTakesThis =>
      'El archivo se lleva esta identidad. En cuanto se crea, este teléfono se detiene: aquí no llega nada nuevo y nada de lo que se envíe desde aquí le llega a nadie.';

  @override
  String get backupOneEncryptedFileYour =>
      'Un solo archivo cifrado: tu identidad, tus contactos, cada mensaje y cada foto, nota de voz y archivo. Impórtalo en el otro dispositivo con la frase de contraseña. Hasta entonces, aún puedes cambiar de idea y quedarte en este teléfono.';

  @override
  String get backupOneEncryptedFileYourIdentityYour =>
      'Un solo archivo cifrado: tu identidad, tus contactos, cada mensaje y cada foto, nota de voz y archivo que hay ahora mismo en este teléfono. Lo que se diga después de hoy no estará en él, así que haz otra cuando importe. Para restaurar necesitas las dos cosas: el archivo y la frase de contraseña.';

  @override
  String get backupPassphrase => 'Frase de contraseña';

  @override
  String get backupConfirmPassphrase => 'Repetir frase de contraseña';

  @override
  String backupWriting(Object progress) {
    return 'Escribiendo… $progress';
  }

  @override
  String get backupCreating => 'Creando…';

  @override
  String get backupMakeTheFileAnd => 'Crear archivo y mudarse';

  @override
  String get backupCreateBackup => 'Crear copia';

  @override
  String get backupHiddenNotIn => 'Los chats ocultos no están en él.';

  @override
  String get backupHiddenIncluded => 'Tus chats ocultos también están en él.';

  @override
  String get backupMoveHiddenStay =>
      'Los chats ocultos se quedan en este teléfono y se borran con él.';

  @override
  String get backupHiddenGone =>
      'Tus chats ocultos se cerraron cuando Kryfo se bloqueó. Ábrelos con su PIN y haz la copia desde ahí.';

  @override
  String get blockedBlocked => 'Bloqueados';

  @override
  String get blockedNoOneIsBlocked => 'No hay nadie bloqueado';

  @override
  String get commonUnblock => 'Desbloquear';

  @override
  String get bridgesThatWasNotIt => 'No era eso. Aquí tienes otro.';

  @override
  String get bridgesGotBridgesSaveTo =>
      'Puentes recibidos · guarda para usarlos';

  @override
  String get bridgesConnected => 'Conectado';

  @override
  String get bridgesNotThroughYetTor => 'Aún no pasa. Tor sigue intentándolo';

  @override
  String get bridgesBridges => 'Puentes';

  @override
  String get bridgesTorIsBlockedWhere => '¿Tor está bloqueado donde estás?';

  @override
  String get bridgesBridgesDisguiseYourConnection =>
      'Los puentes disfrazan tu conexión para que pueda salir. Elige una forma de entrar, guarda, y tor se reconecta a través de ella.';

  @override
  String get bridgesBridgesOnlyChangeHow =>
      'Los puentes solo cambian cómo se conecta tor, y ahora mismo no estás en modo Onion. Lo que configures aquí se guarda, pero no hace nada hasta que vuelvas a ese modo.';

  @override
  String get bridgesFromTheTorProject => 'Del proyecto tor';

  @override
  String get bridgesNoise => 'Ruido';

  @override
  String get bridgesGood => 'Buena';

  @override
  String get bridgesMakesTorTrafficLook =>
      'Hace que el tráfico de tor no parezca nada en concreto. La mejor opción para la mayoría de las redes bloqueadas. Resuelves un captcha y te da unas cuantas líneas.';

  @override
  String get bridgesPrivateBridge => 'Puente privado';

  @override
  String get bridgesALineFromA => 'Una línea de un amigo';

  @override
  String get bridgesWhateverTheLineSays => 'Lo que diga la línea';

  @override
  String get bridgesDepends => 'Depende';

  @override
  String get bridgesGotABridgeLine =>
      '¿Tienes una línea de puente de alguien de confianza o de bridges.torproject.org? Pégala aquí. Solo líneas obfs4: Kryfo aún no habla las demás.';

  @override
  String get bridgesPasteFromClipboard => 'Pegar del portapapeles';

  @override
  String get bridgesUseBridges => 'Usar puentes';

  @override
  String get bridgesNoLinesYet => 'Aún no hay líneas';

  @override
  String bridges1LineSaved(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString líneas guardadas',
      one: '$countString línea guardada',
    );
    return '$_temp0';
  }

  @override
  String get bridgesRestartingTor => 'Reiniciando tor…';

  @override
  String bridgesFindingABridgeS(Object elapsed) {
    return 'Buscando un puente… ${elapsed}s';
  }

  @override
  String bridgesStillTryingS(Object elapsed) {
    return 'Aún intentándolo… ${elapsed}s';
  }

  @override
  String get bridgesApplying => 'Aplicando…';

  @override
  String get bridgesSaveAndReconnect => 'Guardar y reconectar';

  @override
  String get bridgesWhatABridgeIs => 'Qué es un puente';

  @override
  String get bridgesATorEntryPoint =>
      'Una entrada a tor que nadie ha publicado, a la que se llega a través de un envoltorio para que la conexión no parezca tor. El resto de la ruta son los tres saltos de siempre.';

  @override
  String get bridgesLooksLike => 'Parece';

  @override
  String get bridgesSpeed => 'Velocidad';

  @override
  String get bridgesGetBridges => 'Conseguir puentes';

  @override
  String get bridgesAskTheTorProject =>
      'Pídelos directamente al proyecto tor. Resuelves un acertijo para que los bots no puedan agotar la reserva.';

  @override
  String get bridgesTypeWhatYouSee =>
      'Escribe lo que ves. Las minúsculas sirven.';

  @override
  String get bridgesThisOneRequestDoes =>
      'Esta petición no pasa por tor: no puede, porque tor es justo lo que no funciona. Quien gestione tu red verá que contactas con el proyecto tor. Si eso ya es un problema donde estás, consigue puentes en otro sitio y pégalos abajo.';

  @override
  String get bridgesCouldNotDrawThe => 'No se pudo mostrar el acertijo';

  @override
  String get bridgesAnswer => 'Responder';

  @override
  String get bridgesAsking => 'Pidiendo…';

  @override
  String get bridgesRequestBridges => 'Pedir puentes';

  @override
  String get bridgesDifferentPuzzle => 'Otro acertijo';

  @override
  String get cameraNoCameraOnThis => 'Este teléfono no tiene cámara';

  @override
  String get cameraCameraNotAvailable => 'Cámara no disponible';

  @override
  String get cameraCameraPermissionIsOff =>
      'El permiso de cámara está desactivado · toca para reintentar';

  @override
  String get cameraCouldNotStripThat =>
      'No se pudo limpiar esa foto, se descartó';

  @override
  String get cameraNoPhotoCameOut => 'No salió ninguna foto';

  @override
  String get cameraCouldNotStartRecording => 'No se pudo empezar a grabar';

  @override
  String get cameraTheRecordingWasLost => 'Se perdió la grabación';

  @override
  String get cameraACopyIsIn => 'Hay una copia en tus fotos';

  @override
  String get cameraCouldNotSaveA =>
      'No se pudo guardar una copia en este teléfono';

  @override
  String get cameraTooLongForA => 'Demasiado largo para un mensaje · máx. 8 mb';

  @override
  String get cameraNeverSavedToYour => 'Nunca se guarda en tus fotos';

  @override
  String get cameraNoExifNeverSaved => 'Sin exif, nunca se guarda en tus fotos';

  @override
  String get cameraRec => 'Grabar';

  @override
  String get cameraSwitchCamera => 'Cambiar cámara';

  @override
  String cameraClipSMb(Object secs, Object mb) {
    return 'Clip · ${secs}s · $mb mb';
  }

  @override
  String get cameraStopRecording => 'Detener grabación';

  @override
  String get cameraStartRecording => 'Empezar a grabar';

  @override
  String get cameraTakeAPhoto => 'Tomar una foto';

  @override
  String get cameraKeepACopy => 'Guardar una copia';

  @override
  String get cameraUseThis => 'Usar';

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
  String get chatFile => 'ARCHIVO';

  @override
  String get chatYouAreOfflineThis =>
      'No tienes conexión · se enviará solo cuando vuelvas a conectarte';

  @override
  String get chatStillConnectingToTor => 'Aún conectando a Tor · saldrá solo';

  @override
  String chatS(Object seconds) {
    return '${seconds}s';
  }

  @override
  String chatM(Object seconds) {
    return '${seconds}m';
  }

  @override
  String chatH(Object seconds) {
    return '${seconds}h';
  }

  @override
  String chatD(Object seconds) {
    return '${seconds}d';
  }

  @override
  String get chat0s => '0s';

  @override
  String chatHM(Object h, Object m) {
    return '${h}h ${m}m';
  }

  @override
  String chatMS(Object m, Object s) {
    return '${m}m ${s}s';
  }

  @override
  String chatS2(Object s) {
    return '${s}s';
  }

  @override
  String get chatNewMessages => 'Mensajes nuevos';

  @override
  String get chatUnsave => 'Quitar de guardados';

  @override
  String get chatForward => 'Reenviar';

  @override
  String get commonShare => 'Compartir';

  @override
  String get commonCopied => 'Copiado';

  @override
  String get commonCopy => 'Copiar';

  @override
  String get chatUnpin => 'Dejar de fijar';

  @override
  String get chatPin => 'Fijar';

  @override
  String get chatStopSending => 'Detener envío';

  @override
  String get chatUnsend => 'Anular envío';

  @override
  String get commonEdit => 'Editar';

  @override
  String get chatYou => 'Tú';

  @override
  String get chatUnsendMessage => 'Anular el envío';

  @override
  String get chatItDisappearsWithNo =>
      'Desaparece sin dejar rastro. No se puede deshacer.';

  @override
  String chatThisChatHasPins(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Este chat ya tiene $countString mensajes fijados',
      one: 'Este chat ya tiene $countString mensaje fijado',
    );
    return '$_temp0';
  }

  @override
  String get chatUnpinThisMessage => '¿Dejar de fijar este mensaje?';

  @override
  String get chatPinThisMessage => '¿Fijar este mensaje?';

  @override
  String get chatItLeavesThePinned =>
      'Sale de la lista de fijados para los dos.';

  @override
  String get chatItGoesUnderThe =>
      'Aparece arriba del chat, entre los fijados, para los dos.';

  @override
  String get chatPinIt => 'Fijar';

  @override
  String get chatNotNow => 'Ahora no';

  @override
  String get chatEditMessage => 'Editar mensaje';

  @override
  String get chat30Seconds => '30 segundos';

  @override
  String get chat1Minute => '1 minuto';

  @override
  String get chat5Minutes => '5 minutos';

  @override
  String get chat1Hour => '1 hora';

  @override
  String get chat24Hours => '24 horas';

  @override
  String get chatGhostTimer => 'Mensajes temporales';

  @override
  String get chatHowLongBeforeSent =>
      '¿Cuánto tardan en desaparecer los mensajes enviados?';

  @override
  String get chatCamera => 'Cámara';

  @override
  String get chatNoExifNeverSaved => 'Sin exif, nunca se guarda en tus fotos';

  @override
  String get chatGallery => 'Galería';

  @override
  String get chatVideo => 'Video';

  @override
  String get chatGifFromPhone => 'Gif del teléfono';

  @override
  String get chatFile2 => 'Archivo';

  @override
  String get chatAFewSeconds => 'Unos segundos';

  @override
  String get chatUnderAMinute => 'Menos de un minuto';

  @override
  String chatRoughlyMin(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Unos $countString min',
      one: 'Alrededor de $countString min',
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
  String get chatSendThis => '¿Enviar este archivo?';

  @override
  String chatOverTor(Object humanBytes, Object wireEstimate) {
    return '$humanBytes · $wireEstimate por tor';
  }

  @override
  String get chatBigFilesGoOut =>
      'Los archivos grandes salen en trozos pequeños cifrados, así que tardan un rato. Deja la app abierta y el envío sigue.';

  @override
  String get chatSendIt => 'Enviar';

  @override
  String get chatCouldNotReadThat => 'No se pudo leer ese archivo';

  @override
  String get chatFileTooBig8 => 'Archivo muy grande · máx. 8 mb';

  @override
  String get chatCouldNotCleanThat => 'No se pudo limpiar ese video';

  @override
  String get chatCouldNotCleanThatPictureSend =>
      'No se pudo limpiar esa imagen · envíala como foto';

  @override
  String get chatGifTooBig8 => 'Gif muy grande · máx. 8 mb';

  @override
  String get chatCouldNotCleanThatGif => 'No se pudo limpiar ese gif';

  @override
  String get chatTorIsNotUp =>
      'Tor aún no está listo · se envía sin vista previa';

  @override
  String get chatCouldnTReachIt =>
      'No se pudo acceder · se envía sin vista previa';

  @override
  String get chatNoTitleCameBack =>
      'No llegó ningún título · se envía sin vista previa';

  @override
  String get chatCouldnTFetchIt =>
      'No se pudo obtener · se envía sin vista previa';

  @override
  String get chatNoSignalSessionRe =>
      'Sin sesión de Signal - vuelve a emparejar';

  @override
  String get chatMessageUnavailable => 'Mensaje no disponible';

  @override
  String get chatYou2 => 'Tú';

  @override
  String get chatThem => 'Contacto';

  @override
  String get chatVoiceMessage => 'Mensaje de voz';

  @override
  String get chatQuotedPhoto => 'Foto';

  @override
  String get chatViewContact => 'Ver contacto';

  @override
  String get chatSharedPhotos => 'Fotos compartidas';

  @override
  String chatSharedPhotoCount(int count, Object title) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString fotos',
      one: '$countString foto',
    );
    return '$_temp0 · $title';
  }

  @override
  String get chatUnmuteNotifications => 'Activar notificaciones';

  @override
  String get chatMuteNotifications => 'Silenciar notificaciones';

  @override
  String get chatArchiveChat => 'Archivar chat';

  @override
  String get chatWallpaper => 'Fondo';

  @override
  String get chatClearConversation => 'Vaciar conversación';

  @override
  String get chatNoteOnThisContact => 'Nota sobre este contacto';

  @override
  String get chatPinToTop => 'Fijar arriba';

  @override
  String get chatBlockContact => 'Bloquear contacto';

  @override
  String get chatUnpinned => 'Ya no está fijado';

  @override
  String get chatPinnedToTop => 'Fijado arriba';

  @override
  String get chatJustForYouNever =>
      'Solo para ti. Nunca se envía, nunca sale de este teléfono.';

  @override
  String get chatAQuietReminder => 'Un recordatorio discreto…';

  @override
  String get chatNoteSaved => 'Nota guardada';

  @override
  String get chatClearThisConversation => '¿Vaciar esta conversación?';

  @override
  String get chatEveryMessageHereIs =>
      'Todos los mensajes de aquí se borran de este teléfono. Esto solo vacía tu copia: no toca su dispositivo.';

  @override
  String get chatClear => 'Vaciar';

  @override
  String get chatBlockThisContact => '¿Bloquear este contacto?';

  @override
  String get chatTheirMessagesStopArriving =>
      'Sus mensajes dejan de llegar y desaparece de tus chats. Nunca se le avisa. Puedes desbloquearlo cuando quieras desde ajustes.';

  @override
  String get commonBlock => 'Bloquear';

  @override
  String get chatSaved => 'Guardado';

  @override
  String get chatRemovedFromSaved => 'Quitado de guardados';

  @override
  String get chatForwardTo => 'Reenviar a';

  @override
  String get chatNoContactsToForward => 'No hay contactos a los que reenviar';

  @override
  String get chatToday => 'Hoy';

  @override
  String get chatYesterday => 'Ayer';

  @override
  String get chatThisMessageCanT => 'Este mensaje no se puede mostrar';

  @override
  String get chatJumpToTheNewest => 'Ir al más reciente';

  @override
  String get chatBuildingAPrivateRoute =>
      'Construyendo una ruta privada · la primera conexión es la lenta, las siguientes son rápidas. Lo que envíes ahora queda en cola y se entrega solo.';

  @override
  String get chatLooksSafeNothingSuspicious =>
      'Parece seguro · nada sospechoso en su primer mensaje';

  @override
  String get chatTheNextPhotoYou =>
      'La próxima foto que envíes se abre protegida · no podrá hacerle captura de pantalla';

  @override
  String get chatPhotoProtectionOff => 'Protección de fotos desactivada';

  @override
  String get chatAcceptToReplyThey =>
      'Acepta para responder: hasta que lo hagas, puede enviarte un mensaje más.';

  @override
  String chatIntroducedYouAcceptTo(Object introducer) {
    return 'Presentación de $introducer. Acepta para responder.';
  }

  @override
  String chatIntroducedYouSayHello(Object vouchNames) {
    return 'Presentación de $vouchNames. Saluda: también recibió tu tarjeta.';
  }

  @override
  String get chatIntroduceTo => 'Presentar a...';

  @override
  String get chatAcceptThemFirst => 'Primero acepta la solicitud';

  @override
  String get chatMessageRequest => 'Solicitud de mensaje';

  @override
  String get chatTheyNeedToAccept =>
      'Tiene que aceptar antes de que puedas seguir chateando.';

  @override
  String get chatWaitingForThemTo => 'Esperando a que acepte tu solicitud';

  @override
  String get chatYouBlockedThisContact => 'Bloqueaste a este contacto';

  @override
  String get chatSupporter => 'Colaborador';

  @override
  String get chatEncryptedViaRelay => 'Cifrado · vía repetidor';

  @override
  String get chatEncryptedDirect => 'Cifrado · directo';

  @override
  String get chatEncryptedOverTor => 'Cifrado · por tor';

  @override
  String get chatSearchThisChat => 'Buscar en este chat';

  @override
  String get chatContactOptions => 'Opciones del contacto';

  @override
  String get commonClose => 'Cerrar';

  @override
  String get chatFindInConversation => 'Buscar en la conversación';

  @override
  String get chatNoMatches => 'Sin resultados';

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
      other: '*$posString* de $countString resultados',
      one: '*$posString* de $countString resultado',
    );
    return '$_temp0';
  }

  @override
  String get chatPreviousMatch => 'Resultado anterior';

  @override
  String get chatNextMatch => 'Resultado siguiente';

  @override
  String get chatPhotoUnavailable => 'Foto no disponible';

  @override
  String get chatDelivered => 'Entregado';

  @override
  String get chatEdited => 'Editado';

  @override
  String get chatWaitingForThemToComeOnline =>
      'Esperando a que se conecte o te añada también';

  @override
  String get chatFailedTapToRetry => 'Falló · toca para reintentar';

  @override
  String get chatReplyingTo => 'Respondiendo a su mensaje';

  @override
  String get chatReplyingToYourself => 'Respondiendo a tu mensaje';

  @override
  String get chatReply => 'Responder';

  @override
  String get chatSayHi => 'Saluda.';

  @override
  String get chatJustTheTwoOf =>
      'Solo entre los dos, con cifrado de extremo a extremo.';

  @override
  String get chatMicPermissionNeeded => 'Se necesita permiso del micrófono';

  @override
  String get chatTheMicWouldNot =>
      'El micrófono no arrancó. Vuelve a intentarlo';

  @override
  String get chatReleaseToCancel => 'Suelta para cancelar';

  @override
  String get chatVoiceHiddenSlideTo => 'Voz oculta · desliza para cancelar';

  @override
  String get chatSlideToCancel => 'Desliza para cancelar';

  @override
  String get chatGhostMode => 'Mensajes temporales';

  @override
  String chatMessagesBurnAfter(Object humanBurn) {
    return 'desaparecen tras $humanBurn';
  }

  @override
  String get chatTimedMessages => 'Mensajes temporales';

  @override
  String get chatOpenTheCamera => 'Abrir la cámara';

  @override
  String get chatAttachAPhoto => 'Adjuntar una foto';

  @override
  String get chatMessage => 'Mensaje';

  @override
  String get chatDisguiseVoice => 'Disfrazar la voz';

  @override
  String get commonSend => 'Enviar';

  @override
  String get chatNoPhotosInThis => 'Aún no hay fotos en este chat';

  @override
  String get chatSendPhoto => 'Enviar foto';

  @override
  String get chatAddACaption => 'Añade un comentario…';

  @override
  String get chatSecurityCodeChanged => 'El código de seguridad cambió';

  @override
  String chatMayHaveReinstalledOr(Object peerName) {
    return 'Puede que $peerName haya reinstalado la app, o que alguien se esté haciendo pasar por esa persona. Compara los números de seguridad para asegurarte.';
  }

  @override
  String get chatOk => 'Aceptar';

  @override
  String get chatVerify => 'Verificar';

  @override
  String get cleanKryfoCanTClean =>
      'Kryfo aún no puede limpiar este tipo de archivo.';

  @override
  String get cleanThisIsAMotion => 'Es una foto con movimiento.';

  @override
  String get cleanThisPictureIsToo =>
      'Esta imagen es demasiado grande para limpiarla aquí.';

  @override
  String get cleanThisFileIsDamaged => 'Este archivo está dañado o incompleto.';

  @override
  String get cleanKryfoCouldNotMake =>
      'Kryfo no pudo dejar limpio este archivo.';

  @override
  String get cleanNotEnoughRoomOn =>
      'No hay espacio suficiente en el teléfono.';

  @override
  String get cleanKryfoCouldNotOpen => 'Kryfo no pudo abrir ese archivo.';

  @override
  String get cleanItCleansJpegPng =>
      'Limpia JPEG, PNG, WebP, HEIC, AVIF, GIF, MP4 y MOV. No se cambió nada.';

  @override
  String get cleanItHoldsAShort =>
      'Lleva un video corto junto a la imagen, y Kryfo aún no puede limpiar esa parte. Desactiva el movimiento en tu cámara o envía una captura de pantalla.';

  @override
  String get cleanPicturesOver64Mb =>
      'Las imágenes de más de 64 MB no se limpian en el teléfono. No se cambió nada.';

  @override
  String get cleanKryfoCouldNotRead =>
      'Kryfo no pudo leerlo hasta el final, así que no lo dará por limpio. No se hizo ninguna copia.';

  @override
  String get cleanSomethingInsideIsOf =>
      'Dentro hay algo de un tipo que no sabe quitar, así que no se hizo ninguna copia.';

  @override
  String get cleanFreeSomeSpaceAnd =>
      'Libera espacio y vuelve a intentarlo. No se cambió nada.';

  @override
  String get cleanTheAppThatShared =>
      'Puede que la app que lo compartió lo haya retirado. Intenta compartirlo otra vez.';

  @override
  String get cleanNoAppOnThis =>
      'Ninguna app de este teléfono aceptó el archivo.';

  @override
  String get cleanCouldNotSaveIt =>
      'No se pudo guardar. Comprueba que el teléfono tenga espacio.';

  @override
  String get cleanTheOriginalIsGone =>
      'El original ya no está. La copia limpia se queda.';

  @override
  String get cleanAndroidWouldNotDelete =>
      'Android no quiso eliminarlo. Quítalo de la galería a mano.';

  @override
  String get cleanCleanCopy => 'Copia limpia';

  @override
  String get cleanShareCleanCopy => 'Compartir copia limpia';

  @override
  String get cleanSaveToGallery => 'Guardar en la galería';

  @override
  String get commonStop => 'Detener';

  @override
  String get cleanReadingTheFile => 'Leyendo el archivo';

  @override
  String get cleanCleaning => 'Limpiando';

  @override
  String cleanOf(Object prettySize, Object prettySize2) {
    return '$prettySize de $prettySize2';
  }

  @override
  String get cleanEverythingStaysOnThis => 'Todo se queda en este teléfono.';

  @override
  String get cleanAlreadyClean => 'Ya está limpio.';

  @override
  String get cleanClean => 'Limpio.';

  @override
  String get cleanThereWasNothingTo => 'No había nada que encontrar.';

  @override
  String get cleanNothingLeftToFind => 'No queda nada que encontrar.';

  @override
  String get cleanSameVideoSameQuality => 'Mismo video, misma calidad';

  @override
  String get cleanSamePictureSameQuality => 'Misma imagen, misma calidad';

  @override
  String cleanRemoved(Object label) {
    return 'Se eliminó $label';
  }

  @override
  String get cleanRemoved2 => 'ELIMINADO';

  @override
  String get cleanWithTheLocationInside =>
      'con la ubicación dentro. Quien reciba ese archivo sabrá cuál es tu calle.';

  @override
  String get cleanWithEverythingItKnew => 'con todo lo que sabía aún dentro.';

  @override
  String get cleanOriginal => 'ORIGINAL';

  @override
  String get cleanClean2 => 'LIMPIA';

  @override
  String get cleanSavedToYourGallery => 'Se guardó en tu galería.';

  @override
  String cleanTheOriginalIsStill(Object what) {
    return 'El original también sigue ahí, $what';
  }

  @override
  String cleanTheOriginalIsStillWhereIt(Object what) {
    return 'El original sigue donde estaba, $what Kryfo no puede quitarlo desde aquí, así que elimínalo en la app de la que vino.';
  }

  @override
  String get cleanDeleteTheOriginal => 'Eliminar el original';

  @override
  String get cleanKeepBoth => 'Conservar los dos';

  @override
  String get commonDone => 'Listo';

  @override
  String get cleanAndroidWillAskYou => 'ANDROID TE PEDIRÁ CONFIRMAR';

  @override
  String get contactYourNameForThem => 'Tu apodo para este contacto';

  @override
  String get contactStaysOnThisPhone =>
      'Se queda en este teléfono. Tu contacto nunca lo ve.';

  @override
  String get contactClear => 'Quitar';

  @override
  String get contactMessage => 'Escribir';

  @override
  String get contactKeysVerified => 'Claves verificadas';

  @override
  String get contactVerifyKeys => 'Verificar claves';

  @override
  String get contactVouches => 'Avales';

  @override
  String get contactUnmute => 'Activar sonido';

  @override
  String get contactMute => 'Silenciar';

  @override
  String get contactUnpin => 'Dejar de fijar';

  @override
  String get contactPinToTop => 'Fijar arriba';

  @override
  String get contactArchive => 'Archivar';

  @override
  String get contactOutOfTheList =>
      'Fuera de la lista hasta que vuelva a escribir';

  @override
  String contactBlock(Object name) {
    return '¿Bloquear a $name?';
  }

  @override
  String get contactTheirMessagesStopArriving =>
      'Sus mensajes dejan de llegar. No se le avisa.';

  @override
  String get contactDeleteChat => 'Eliminar chat';

  @override
  String get contactMessagesAndContactGone =>
      'Mensajes y contacto, fuera de este teléfono';

  @override
  String get contactDeleteThisChat => '¿Eliminar este chat?';

  @override
  String get contactEveryMessageAndThe =>
      'Todos los mensajes y el contacto desaparecen de este teléfono. No se le envía nada.';

  @override
  String get commonDelete => 'Eliminar';

  @override
  String get contactDeleted => 'Eliminado';

  @override
  String get contactToday => 'Hoy';

  @override
  String contactD(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count días',
      one: '$count día',
    );
    return '$_temp0';
  }

  @override
  String contactMo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count meses',
      one: '$count mes',
    );
    return '$_temp0';
  }

  @override
  String contactY(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count años',
      one: '$count año',
    );
    return '$_temp0';
  }

  @override
  String get contactVerified => 'Verificado';

  @override
  String get contactChatting => 'Chateando';

  @override
  String get contactNothingSharedYet => 'Nada compartido aún';

  @override
  String contactSharedMedia(Object count) {
    return 'Archivos compartidos · $count';
  }

  @override
  String get donateBitcoin => 'Bitcoin';

  @override
  String get donateText => '₿';

  @override
  String get donateBadgeUnlocks => 'Insignia automática';

  @override
  String get donateMonero => 'Monero';

  @override
  String get donateManualNoBadge => 'Manual · sin insignia';

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
          'Se detectó tu pago anterior en bitcoin · insignia de colaborador desbloqueada',
      'patron':
          'Se detectó tu pago anterior en bitcoin · insignia de mecenas desbloqueada',
      'guardian':
          'Se detectó tu pago anterior en bitcoin · insignia de guardián desbloqueada',
      'other':
          'Se detectó tu pago anterior en bitcoin · insignia de colaborador desbloqueada',
    });
    return '$_temp0';
  }

  @override
  String get donateSupport => 'Apoyar';

  @override
  String get donateKeepKryfo => 'Mantén Kryfo *independiente*';

  @override
  String get donateNoAdsNoInvestors =>
      'Sin anuncios, sin inversores, nada que vender. Vive de lo que aportan quienes lo apoyan.';

  @override
  String get donateBackItAnonymouslyBadge =>
      'Apóyalo de forma anónima. La insignia es opcional.\n*La privacidad nunca va detrás de un muro de pago.*';

  @override
  String donateAddressCheckItAgainst(Object coinName) {
    return 'Dirección de $coinName · compruébala con tu billetera';
  }

  @override
  String get donateAddressCopiedClearsIn =>
      'Dirección copiada · se borra en 60s';

  @override
  String get donateCopyAddress => 'Copiar dirección';

  @override
  String get donateBitcoinIsVerifiedBy =>
      'Los pagos en bitcoin los verifica nuestro propio nodo, así que tu insignia se desbloquea sola en cuanto llega el pago.';

  @override
  String get donateWeCanTVerify =>
      'No podemos verificar esta cadena sin preguntar por ti a un servicio externo, así que no lo hacemos. Envíalo si quieres. No desbloqueará ninguna insignia.';

  @override
  String get donateBitcoinBadgesNeedOnion =>
      'Las insignias por bitcoin necesitan el modo Onion';

  @override
  String get donateSwitchToOnion => 'Cambiar a Onion';

  @override
  String get donatePayWithBitcoin => 'Pagar con bitcoin  →';

  @override
  String get donateBadgesStartAt20 => 'Insignias desde 20 USD';

  @override
  String get donateReachingThePaymentService =>
      'Contactando con el servicio de pago por tor…';

  @override
  String get donateThisCanTakeUp => 'Puede tardar hasta un minuto';

  @override
  String donateSThisCanTake(Object waited) {
    return '${waited}s · puede tardar hasta un minuto';
  }

  @override
  String get donateUseTheAddressInstead => 'Usar la dirección';

  @override
  String get donateThePaymentServiceIs =>
      'El servicio de pago es un servicio onion, y solo el modo Onion puede llegar a él. No se envió nada.';

  @override
  String get donateTorWasSlowTo =>
      'Tor tardó demasiado en llegar al servicio de pago. Puedes donar a la dirección de abajo: solo que tu insignia no se desbloqueará automáticamente. Vuelve a intentarlo más tarde para obtener la insignia.';

  @override
  String get donateThePaymentServiceIsHavingTrouble =>
      'El servicio de pago tiene problemas ahora mismo. Aun así puedes donar a la dirección de abajo: solo que tu insignia no se desbloqueará automáticamente. Vuelve a intentarlo más tarde para obtener la insignia.';

  @override
  String get commonTryAgain => 'Reintentar';

  @override
  String donateBtc(Object btc) {
    return '$btc BTC';
  }

  @override
  String donateSendExactlyThisAmount(Object fmtLeft) {
    return 'Envía exactamente esta cantidad · caduca en $fmtLeft';
  }

  @override
  String get donateOpenWallet => 'Abrir billetera';

  @override
  String get donateThisScreenUpdatesItself =>
      'Esta pantalla se actualiza sola en cuanto se detecta tu pago.\nDéjala abierta: no se guarda nada, nada te identifica.';

  @override
  String get donateWatchingTheChainFor =>
      'Vigilando la cadena en busca de tu pago';

  @override
  String get donateThisInvoiceExpired => 'Esta factura caducó';

  @override
  String get donateInvoicesTimeOutIf =>
      'Las facturas caducan. Si ya enviaste el pago, deja esto abierto: volvemos a preguntar al servicio cada minuto durante un rato, y otra vez la próxima vez que abras Apoyar. Crea una nueva cuando quieras.';

  @override
  String get donateNewInvoice => 'Nueva factura';

  @override
  String get donateIPaidCheckAgain => 'Ya pagué, comprobar de nuevo';

  @override
  String get donatePaymentConfirmed => 'Pago confirmado';

  @override
  String get donateThankYouForKeeping =>
      'Gracias por mantener Kryfo independiente.';

  @override
  String donateVerifiedOnChainYou(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter':
          'Verificado en la cadena: ahora eres colaborador. Nadie te lo puede quitar.',
      'patron':
          'Verificado en la cadena: ahora eres mecenas. Nadie te lo puede quitar.',
      'guardian':
          'Verificado en la cadena: ahora eres guardián. Nadie te lo puede quitar.',
      'other':
          'Verificado en la cadena: ahora eres colaborador. Nadie te lo puede quitar.',
    });
    return '$_temp0';
  }

  @override
  String get donateWearMyBadge => 'Llevar mi insignia';

  @override
  String get donateJustGladToHelp => 'Solo quiero ayudar';

  @override
  String get gettingMessagesGettingMessages => 'Recibir mensajes';

  @override
  String get gettingMessagesHowNewMessagesReach =>
      'Cómo llegan los mensajes nuevos a este teléfono. Puedes cambiarlo cuando quieras.';

  @override
  String get gettingMessagesAlwaysOn => 'Siempre activo';

  @override
  String get gettingMessagesMostPrivate => 'Más privado';

  @override
  String get gettingMessagesMessagesArriveInstantlyNothing =>
      'Los mensajes llegan al instante. Nada sale de tor. Es lo que más batería gasta.';

  @override
  String get gettingMessagesCheckIns => 'Consultas';

  @override
  String get gettingMessagesLightest => 'Más ligero';

  @override
  String get gettingMessagesKryfoLooksForMessages =>
      'Kryfo busca mensajes cada 15 minutos. Gasta poca batería, pero los mensajes pueden llegar tarde.';

  @override
  String get gettingMessagesOnTheLockScreen => 'En la pantalla de bloqueo';

  @override
  String get gettingMessagesHideMessagePreview => 'Ocultar vista previa';

  @override
  String get gettingMessagesAGenericAlertWith =>
      'Un aviso genérico, sin remitente ni texto del mensaje';

  @override
  String get gettingMessagesShowsMessageTextIn =>
      'Muestra el texto de los mensajes en las notificaciones, incluso con Kryfo bloqueado.';

  @override
  String get gettingMessagesWhenThePhoneSits =>
      'Cuando el teléfono está quieto, Android espacia más las consultas. La línea de arriba muestra la última real. Mientras Kryfo está abierto, sigue conectado.';

  @override
  String get groupChatJumpToTheNewest => 'Ir al más reciente';

  @override
  String get groupChatBlockedEverywhere => 'Bloqueado en todas partes';

  @override
  String get groupChatYou => 'Tú';

  @override
  String get groupChatVoiceMessage => 'Mensaje de voz';

  @override
  String get groupChatQuotedPhoto => 'Foto';

  @override
  String get groupChatMessageUnavailable => 'Mensaje no disponible';

  @override
  String get groupChatTorIsNotUp =>
      'Tor aún no está listo · se envía sin vista previa';

  @override
  String get groupChatCouldnTReachIt =>
      'No se pudo acceder · se envía sin vista previa';

  @override
  String get groupChatNoTitleCameBack =>
      'No llegó ningún título · se envía sin vista previa';

  @override
  String get groupChatCouldnTFetchIt =>
      'No se pudo obtener · se envía sin vista previa';

  @override
  String get groupChatCamera => 'Cámara';

  @override
  String get groupChatGallery => 'Galería';

  @override
  String get groupChatVideo => 'Video';

  @override
  String get groupChatGifFromPhone => 'Gif del teléfono';

  @override
  String get groupChatFile => 'Archivo';

  @override
  String get groupChatCouldNotReadThat => 'No se pudo leer ese archivo';

  @override
  String get groupChatGifTooBig8 => 'Gif muy grande · máx. 8 mb';

  @override
  String get groupChatCouldNotCleanThat => 'No se pudo limpiar ese gif';

  @override
  String get groupChatFileTooBig8 => 'Archivo muy grande · máx. 8 mb';

  @override
  String get groupChatCouldNotCleanThatVideo => 'No se pudo limpiar ese video';

  @override
  String get groupChatCouldNotCleanThatPictureSend =>
      'No se pudo limpiar esa imagen · envíala como foto';

  @override
  String get groupChat30Seconds => '30 segundos';

  @override
  String get groupChat1Minute => '1 minuto';

  @override
  String get groupChat5Minutes => '5 minutos';

  @override
  String get groupChat1Hour => '1 hora';

  @override
  String get groupChat24Hours => '24 horas';

  @override
  String get groupChatBurnTimer => 'Mensajes temporales';

  @override
  String get groupChatNewMessagesDisappearAfter =>
      'Los mensajes nuevos desaparecen pasado este tiempo';

  @override
  String get groupChatToday => 'Hoy';

  @override
  String get groupChatYesterday => 'Ayer';

  @override
  String get groupChatYou2 => 'Tú';

  @override
  String groupChatThisChatHasPins(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Este chat ya tiene $countString mensajes fijados',
      one: 'Este chat ya tiene $countString mensaje fijado',
    );
    return '$_temp0';
  }

  @override
  String get groupChatUnpinThisMessage => '¿Dejar de fijar este mensaje?';

  @override
  String get groupChatPinThisMessage => '¿Fijar este mensaje?';

  @override
  String get groupChatItLeavesThePinned =>
      'Sale de la lista de fijados para todos aquí.';

  @override
  String get groupChatItGoesUnderThe =>
      'Aparece arriba del chat, entre los fijados, para todos aquí.';

  @override
  String get groupChatUnpin => 'Dejar de fijar';

  @override
  String get groupChatPinIt => 'Fijar';

  @override
  String get groupChatNotNow => 'Ahora no';

  @override
  String get groupChatSaved => 'Guardado';

  @override
  String get groupChatRemovedFromSaved => 'Quitado de guardados';

  @override
  String get groupChatForwardTo => 'Reenviar a';

  @override
  String get groupChatNoContactsToForward =>
      'No hay contactos a los que reenviar';

  @override
  String get groupChatEditMessage => 'Editar mensaje';

  @override
  String get groupChatUnsendMessage => 'Anular el envío';

  @override
  String get groupChatItDisappearsWithNo =>
      'Desaparece sin dejar rastro. No se puede deshacer.';

  @override
  String get groupChatUnsend => 'Anular envío';

  @override
  String groupChatThisRoomAndEverything(Object expiryWords) {
    return 'Esta sala y todo lo que contiene desaparecen en $expiryWords';
  }

  @override
  String groupChatGhostModeOnBurns(Object fmtBurn) {
    return 'Mensajes temporales · desaparecen tras $fmtBurn';
  }

  @override
  String get groupChatGroupCreatedSayHi => 'Grupo creado. Saluda.';

  @override
  String get groupChatNoMessagesYet => 'Aún no hay mensajes.';

  @override
  String get groupChatThisMessageCanT => 'Este mensaje no se puede mostrar';

  @override
  String groupChatS(Object s) {
    return '${s}s';
  }

  @override
  String groupChatM(Object s) {
    return '${s}m';
  }

  @override
  String groupChatH(Object s) {
    return '${s}h';
  }

  @override
  String groupChatD(Object s) {
    return '${s}d';
  }

  @override
  String groupChatHere(int count, Object time) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$time · $countString aquí',
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
      other: '$countString miembros',
      one: '$countString miembro',
    );
    return '$_temp0';
  }

  @override
  String get groupChatSearchThisChat => 'Buscar en este chat';

  @override
  String groupChatReplyingTo(Object name) {
    return 'Respondiendo a $name';
  }

  @override
  String get groupChatReplyingToYou => 'Respondiendo a tu mensaje';

  @override
  String get groupChatTimedMessages => 'Mensajes temporales';

  @override
  String get groupChatOpenTheCamera => 'Abrir la cámara';

  @override
  String get groupChatAttachAPhoto => 'Adjuntar una foto';

  @override
  String get groupChatMessage => 'Mensaje';

  @override
  String get groupChatDisguiseVoice => 'Disfrazar la voz';

  @override
  String get groupChatSupporter => 'Colaborador';

  @override
  String get groupChatEdited => 'Editado';

  @override
  String get groupChatTapToRetry => '! Toca para reintentar';

  @override
  String get groupChat0s => '0s';

  @override
  String get groupChatReply => 'Responder';

  @override
  String get groupChatPin => 'Fijar';

  @override
  String get groupChatUnsave => 'Quitar de guardados';

  @override
  String get groupChatForward => 'Reenviar';

  @override
  String get groupInfoGroup => 'Grupo';

  @override
  String get groupInfoRenameGroup => 'Renombrar grupo';

  @override
  String get groupInfoRename => 'Renombrar';

  @override
  String get groupInfoNoContactsToAdd => 'No hay contactos que añadir';

  @override
  String get groupInfoCouldNotAdd => 'No se pudo añadir';

  @override
  String groupInfoRemove(Object haloId) {
    return '¿Quitar a $haloId?';
  }

  @override
  String get groupInfoTheyWillStopReceiving =>
      'Dejará de recibir mensajes de este grupo.';

  @override
  String get commonRemove => 'Quitar';

  @override
  String get groupInfoClearThisConversation => '¿Vaciar esta conversación?';

  @override
  String get groupInfoEveryMessageHereIs =>
      'Todos los mensajes de aquí se borran de este teléfono. Esto solo vacía tu copia; los demás miembros conservan la suya.';

  @override
  String get groupInfoClear => 'Vaciar';

  @override
  String get groupInfoConversationCleared => 'Conversación vaciada';

  @override
  String get groupInfoLeaveRoom => '¿Salir de la sala?';

  @override
  String get groupInfoLeaveGroup => '¿Salir del grupo?';

  @override
  String get groupInfoEverythingInItIs =>
      'Todo lo que contiene se borra ahora de este teléfono, y la clave que usaste aquí desaparece para siempre.';

  @override
  String get groupInfoYouWillStopReceiving =>
      'Dejarás de recibir mensajes y los demás miembros verán que te vas.';

  @override
  String get groupInfoLeave => 'Salir';

  @override
  String get groupInfoGroupInfo => 'Datos del grupo';

  @override
  String groupInfo1Member(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString miembros',
      one: '$countString miembro',
    );
    return '$_temp0';
  }

  @override
  String get groupInfoAdmin => 'Admin';

  @override
  String get groupInfoMembers2 => 'Miembros';

  @override
  String get groupInfoInvite => 'Invitar';

  @override
  String get commonAdd => 'Añadir';

  @override
  String get groupInfoYou => 'Tú';

  @override
  String get groupInfoRemoveFromGroup => 'Quitar del grupo';

  @override
  String get groupInfoWallpaper => 'Fondo';

  @override
  String get groupInfoSharedMedia => 'Archivos compartidos';

  @override
  String get groupInfoClearConversation => 'Vaciar conversación';

  @override
  String get groupInfoLeaveRoom2 => 'Salir de la sala';

  @override
  String get groupInfoLeaveGroup2 => 'Salir del grupo';

  @override
  String get groupInfoAddMembers => 'Añadir miembros';

  @override
  String groupInfoAdd(Object pickedLength) {
    return 'Añadir $pickedLength';
  }

  @override
  String handleYouAre(Object h) {
    return 'Eres @$h';
  }

  @override
  String get handleHandleDeletedThePage =>
      'Nombre de usuario eliminado · la página ya no existe';

  @override
  String get handlePublicHandle => 'Nombre de usuario público';

  @override
  String get handleOptionalYourThreeWords =>
      'Opcional. Tus tres palabras siguen funcionando igual.';

  @override
  String get handleWren => 'wren';

  @override
  String get handleALineAboutYou => 'Una línea sobre ti · opcional';

  @override
  String get handleClaiming => 'Reservando…';

  @override
  String get handleClaimThisHandle => 'Reservar nombre de usuario';

  @override
  String get handleAnyoneWithThisLink =>
      'Cualquiera con este enlace puede iniciar un chat privado contigo. Solo lleva tu invitación, nada más.';

  @override
  String get handleLinkCopied => 'Enlace copiado';

  @override
  String get handleDeleteThisHandle => 'Eliminar nombre de usuario';

  @override
  String get handleChecking => 'Comprobando…';

  @override
  String get handleAvailable => '✓ Disponible';

  @override
  String get handleAlreadyTaken => 'Ya está en uso';

  @override
  String get handleWhatAHandleDoes => 'Qué es un nombre de usuario';

  @override
  String get handleAnyoneWhoKnowsIt =>
      'Cualquiera que lo conozca puede pedir escribirte, que es justo para lo que sirve. La página guarda tu invitación y la línea que escribiste, nada más, y no registra quién la lee. Puedes eliminarlo cuando quieras.';

  @override
  String handleIsNotYoursOn(Object handle) {
    return '@$handle no es tuyo en este teléfono';
  }

  @override
  String handleTheRegistryHoldsIt(Object handle) {
    return 'El registro lo tiene con otra clave, seguramente una identidad que este teléfono tenía antes de una restauración. Quien añade a @$handle no te está llegando a ti. No se puede liberar ni actualizar desde aquí. Elige otro nombre.';
  }

  @override
  String get handleForgetItOnThis => 'Olvidarlo en este teléfono';

  @override
  String get homeAddAContact => 'Añadir un contacto';

  @override
  String get commonSettings => 'Ajustes';

  @override
  String get homeYourKryfo => 'Tu Kryfo';

  @override
  String homeDateWeekday(Object weekday) {
    return '$weekday,';
  }

  @override
  String get homeAnHour => 'una hora';

  @override
  String homeHours(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString horas',
      one: '$countString hora',
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
      other: '$countString minutos',
      one: '$countString minuto',
    );
    return '$_temp0';
  }

  @override
  String get homeKryfoIsOffline => 'Kryfo está sin conexión';

  @override
  String homeTorHasNotBeen(Object howLong) {
    return 'Tor lleva $howLong sin poder conectarse. No puede llegar ni salir nada hasta que lo consiga.';
  }

  @override
  String get homeReconnecting => 'Reconectando';

  @override
  String get homeReconnect => 'Reconectar';

  @override
  String get homeWhatIsWrong => 'Qué falla';

  @override
  String get homeKryfoWillCheckIn => 'Kryfo consultará cada 15 minutos';

  @override
  String get homeYourPhoneKeepsStopping =>
      'Tu teléfono no deja de cerrar Kryfo';

  @override
  String get homeItHasClosedKryfo =>
      'Hoy ha cerrado Kryfo tres veces, así que los mensajes llegaron tarde o se quedaron esperando. Las consultas aguantan eso: Kryfo se despierta cada 15 minutos en vez de seguir conectado.';

  @override
  String get homeSwitchToCheckIns => 'Cambiar a consultas';

  @override
  String get homeNotNow => 'Ahora no';

  @override
  String get homeNotificationsAreOff => 'Notificaciones desactivadas';

  @override
  String get homeAndroidIsBlockingThem =>
      'Android las está bloqueando, así que no te llega nada mientras Kryfo está cerrado. Los mensajes siguen llegando cuando lo abres.';

  @override
  String get homeCouldnTOpenIt =>
      'No se pudo abrir. Busca Kryfo en los ajustes del teléfono';

  @override
  String get homeTurnThemOn => 'Activarlas';

  @override
  String get homeLeaveThemOff => 'Dejarlas así';

  @override
  String get homeOurRelayIsQuiet => 'Nuestro repetidor no responde';

  @override
  String get homeRelayModeUsesOnly =>
      'El modo Repetidor usa solo nuestro propio repetidor, y ahora mismo no responde. El modo Rápido añade repetidores públicos junto a él, así que los mensajes siguen llegando. En ambos casos todo sigue sellado.';

  @override
  String get homeSwitchedToFast => 'Cambiado a Rápido';

  @override
  String get homeUseFastMode => 'Usar modo Rápido';

  @override
  String get homeKeepWaiting => 'Esperar';

  @override
  String get homeNotConnecting => 'No conecta';

  @override
  String get homeBridgesAreOnAnd =>
      'Los puentes están activados y tor sigue sin pasar. Los puentes son más lentos y algunos dejan de funcionar sin aviso. Si tu red no bloquea tor, conectarte directamente es más rápido y fiable.';

  @override
  String get homeGoingDirectReconnecting => 'Conexión directa · reconectando';

  @override
  String get homeTurnBridgesOff => 'Desactivar puentes';

  @override
  String get homeStillTrying => 'Aún intentándolo';

  @override
  String get homeTorIsNotGetting =>
      'Tor no consigue pasar. Algunas redes lo bloquean a propósito. Nuestro propio repetidor es una sola conexión simple y suele funcionar igualmente; o los puentes, que tardan más en configurarse.';

  @override
  String get homeSwitchedToRelay => 'Cambiado a Repetidor';

  @override
  String get homeUseOurRelay => 'Usar repetidor';

  @override
  String get homeBridges => 'Puentes';

  @override
  String get homeOffline => 'Sin conexión';

  @override
  String get homeWaiting => 'En espera';

  @override
  String get homeNothingWaitingToSend => 'Nada pendiente de enviar';

  @override
  String homeWaitingSendsWhenYou(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString en espera · se envían cuando vuelvas',
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
      other: '$countString en espera · tor sigue conectando',
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
      other: '$countString en espera · a que te añadan también',
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
      other: '$countString en espera · $parkedString a que te añadan también',
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
      other: '$countString en espera · enviando ahora',
    );
    return '$_temp0';
  }

  @override
  String get commonRetry => 'Reintentar';

  @override
  String get homeNoKryfosYet => 'Aún no hay Kryfos.';

  @override
  String get homeScanTheirCodeSend =>
      'Escanea su código, envíale un enlace o escribe el nombre de usuario con @ que te dio.';

  @override
  String get homeAddSomeone => 'Añadir a alguien';

  @override
  String get homeArchived => 'Archivados';

  @override
  String home1Chat(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString chats',
      one: '$countString chat',
    );
    return '$_temp0';
  }

  @override
  String get homeGroups => 'Grupos';

  @override
  String get homeRoom => 'Sala';

  @override
  String get homeNew => 'Nuevo';

  @override
  String homeRoomExpired(Object expiredRoomName) {
    return '$expiredRoomName · sala expirada';
  }

  @override
  String get homeMentionedYou => 'Te mencionó';

  @override
  String homeMembers(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString miembros',
      one: '$countString miembro',
    );
    return '$_temp0';
  }

  @override
  String get homeSupporter => 'Colaborador';

  @override
  String get homeArchivedChats => 'Chats archivados';

  @override
  String get homeUnmute => 'Activar sonido';

  @override
  String get homeMute => 'Silenciar';

  @override
  String get homeArchive => 'Archivar';

  @override
  String get homeDeleteChat => 'Eliminar chat';

  @override
  String get homeMessagesAndContactGone =>
      'Mensajes y contacto, fuera de este teléfono';

  @override
  String get homeDeleteThisChat => '¿Eliminar este chat?';

  @override
  String homeEveryMessageWithGoes(Object c) {
    return 'Se van todos los mensajes con $c y deja de ser tu contacto. Esto solo afecta a este teléfono: su copia sigue con esa persona. Si vuelve a escribirte, llegará a solicitudes.';
  }

  @override
  String get homeQueued => 'En cola';

  @override
  String get homeBlocked => 'Bloqueado';

  @override
  String get homeRoomInvite => 'Invitación a sala';

  @override
  String get homeNow => 'Ahora';

  @override
  String homeM(Object inMinutes) {
    return '${inMinutes}m';
  }

  @override
  String homeH(Object inHours) {
    return '${inHours}h';
  }

  @override
  String get homeYesterday => 'Ayer';

  @override
  String homeD(Object inDays) {
    return '${inDays}d';
  }

  @override
  String get homeNoteToSelf => 'Notas';

  @override
  String get homeOnlyOnThisPhone => 'Solo en este teléfono';

  @override
  String get homeSaved => 'Guardados';

  @override
  String get homeKeptFromEveryChat => 'Guardados de todos los chats';

  @override
  String get homeRequests => 'Solicitudes';

  @override
  String home1PersonWantsTo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString personas quieren contactarte',
      one: '$countString persona quiere contactarte',
    );
    return '$_temp0';
  }

  @override
  String introduceGotItButCould(Object b, Object c) {
    return '$b lo recibió, pero no se pudo contactar con $c';
  }

  @override
  String introduceGotItButCouldNotBe(Object c, Object b) {
    return '$c lo recibió, pero no se pudo contactar con $b';
  }

  @override
  String get introduceCouldNotReachEither =>
      'No se pudo contactar con ninguno de los dos. Vuelve a intentarlo más tarde';

  @override
  String introduceIntroduceTo(Object peerName) {
    return 'Presentar a $peerName a...';
  }

  @override
  String get introduceBothOfThemGet =>
      'Cada uno recibe la tarjeta del otro. Ninguno ve el apodo que le pusiste al otro.';

  @override
  String get introduceNoOneElseTo =>
      'Aún no hay nadie más a quien presentar. Primero añade otro contacto.';

  @override
  String get introduceANoteLikeMy => 'Una nota, como «mi prima» - opcional';

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
      other: '$leftString de $maxString presentaciones disponibles esta semana',
      one: '$leftString de $maxString presentación disponible esta semana',
    );
    return '$_temp0';
  }

  @override
  String introduceNoIntroductionsLeftNext(Object refillPhrase) {
    return 'No te quedan presentaciones. La próxima se libera $refillPhrase';
  }

  @override
  String get introduceIntroduce => 'Presentar';

  @override
  String get keyVerificationSafetyNumber => 'Número de seguridad';

  @override
  String keyVerificationWith(Object peerName) {
    return 'Con $peerName';
  }

  @override
  String keyVerificationIfSeesTheSame(Object peerName) {
    return 'Si $peerName ve el mismo número, tus mensajes son privados solo entre los dos. Compararlo en persona o en una llamada de confianza es la forma más segura de comprobarlo, pero es opcional: nunca hace falta para chatear.';
  }

  @override
  String get keyVerificationVerified => 'Verificado';

  @override
  String get keyVerificationMarkAsVerified => 'Marcar como verificado';

  @override
  String get lockFileThatPasswordDoesNot => 'Esa contraseña no lo abre.';

  @override
  String get lockFileThisFileIsDamaged => 'Este archivo está dañado.';

  @override
  String get lockFileThisFileWasLocked =>
      'Este archivo se bloqueó con una clave, no con una contraseña.';

  @override
  String get lockFileThisIsNotA => 'Esto no es un archivo bloqueado.';

  @override
  String get lockFileNotEnoughFreeMemory =>
      'Ahora mismo no hay suficiente memoria libre.';

  @override
  String get lockFileStopped => 'Detenido.';

  @override
  String get lockFileItNeedsAPassword => 'Necesita una contraseña.';

  @override
  String get lockFileKryfoCouldNotRead =>
      'Kryfo no pudo leer ni escribir el archivo.';

  @override
  String get lockFileCheckCapitalsAndSpaces =>
      'Revisa mayúsculas y espacios. Nadie puede restablecerla, ni siquiera nosotros.';

  @override
  String get lockFileItMayHaveBeen =>
      'Puede que se cortara por el camino. Pide que te lo vuelvan a enviar. No se guardó nada.';

  @override
  String get lockFileItOpensWithThe =>
      'Se abre con el archivo de clave de la persona para quien se hizo, con la herramienta age en una computadora. Kryfo abre los de contraseña.';

  @override
  String get lockFileKryfoOpensFilesLocked =>
      'Kryfo abre archivos bloqueados con age. Suelen terminar en .age.';

  @override
  String get lockFileCloseAFewApps =>
      'Cierra algunas apps y vuelve a intentarlo. La comprobación de la contraseña necesita unos cientos de megabytes durante un momento.';

  @override
  String get lockFileNothingWasSaved => 'No se guardó nada.';

  @override
  String get lockFileTypeOneOrLet =>
      'Escribe una o deja que Kryfo te sugiera cuatro palabras.';

  @override
  String get lockFileTheAppThatHolds =>
      'Puede que la app que lo tiene lo haya retirado. Vuelve a elegirlo.';

  @override
  String get lockFileHidePassword => 'Ocultar contraseña';

  @override
  String get lockFileShowPassword => 'Mostrar contraseña';

  @override
  String get lockFileChangeFile => 'Cambiar archivo';

  @override
  String get lockFileChange => 'Cambiar';

  @override
  String lockFileOf(Object prettySize, Object prettySize2) {
    return '$prettySize de $prettySize2';
  }

  @override
  String get lockFileEverythingStaysOnThis => 'Todo se queda en este teléfono.';

  @override
  String get lockFileCouldNotMakeOne =>
      'No se pudo crear una. Escribe la tuya.';

  @override
  String get lockFileWriteItDownBefore =>
      'Anótala antes de bloquear el archivo';

  @override
  String get lockFileNoAppOnThis =>
      'Ninguna app de este teléfono aceptó el archivo.';

  @override
  String get lockFileSaved => 'Guardado';

  @override
  String get lockFileCouldNotSaveIt =>
      'No se pudo guardar ahí. Prueba otra carpeta.';

  @override
  String get lockFileLocked => 'Bloqueado';

  @override
  String get lockFileLockAFile => 'Bloquear un archivo';

  @override
  String get lockFileMixingThePassword => 'Mezclando la contraseña';

  @override
  String get lockFileLocking => 'Bloqueando';

  @override
  String get lockFileSaveToFiles => 'Guardar en Archivos';

  @override
  String get lockFileLockFile => 'Bloquear archivo';

  @override
  String get lockFileOnePassword => 'Una contraseña.';

  @override
  String get lockFileNothingElseOpensIt => 'Nada más lo abre.';

  @override
  String get lockFileFile => 'Archivo';

  @override
  String lockFileFromFiles(Object prettySize) {
    return '$prettySize · de Archivos';
  }

  @override
  String get lockFileFromFiles2 => 'De Archivos';

  @override
  String get lockFilePassword => 'Contraseña';

  @override
  String get lockFileSuggestFourWords => 'Sugerir cuatro palabras';

  @override
  String get lockFileTypeItAgain => 'Escríbela otra vez';

  @override
  String get lockFileTheTwoDoNot => 'Aún no coinciden.';

  @override
  String get lockFileHideTheFileName => 'Ocultar el nombre del archivo';

  @override
  String lockFileItWillBeCalled(Object name) {
    return 'Se llamará «$name». Dile a la otra persona qué tipo de archivo es.';
  }

  @override
  String get lockFileTheNameAloneCan =>
      'El nombre por sí solo puede revelar lo que hay dentro.';

  @override
  String get lockFileAnyoneWithThePassword =>
      'Cualquiera con la contraseña puede abrirlo, en Kryfo o en cualquier computadora con la herramienta gratuita age. Si la olvidas, el archivo se pierde para siempre. Nadie puede restablecerla, ni siquiera nosotros.';

  @override
  String get lockFileLocked2 => 'Bloqueado.';

  @override
  String get lockFileOnlyThePasswordOpens => 'Solo la contraseña lo abre.';

  @override
  String lockFileSafeToEmailOr(Object prettySize) {
    return '$prettySize · seguro para enviar por correo o guardar en un USB';
  }

  @override
  String get lockFileNoKryfoOnThe =>
      '¿La otra persona no tiene Kryfo? En una computadora:';

  @override
  String get lockFileItAsksForThe =>
      'Te pedirá la contraseña. age es gratis en age-encryption.org';

  @override
  String lockTooManyTriesS(Object lockState) {
    return 'Demasiados intentos · ${lockState}s';
  }

  @override
  String get lockNotIt => 'No es ese';

  @override
  String get lockYourPin => 'Tu PIN';

  @override
  String get lockUseFingerprint => 'Usar huella';

  @override
  String get lockSetupUnlockWithFingerprint => '¿Desbloquear con huella?';

  @override
  String get lockSetupThePinStillWorks =>
      'El PIN sigue funcionando cuando quieras. Esto solo es más rápido.';

  @override
  String get lockSetupUseFingerprint => 'Usar huella';

  @override
  String get lockSetupPinOnly => 'Solo PIN';

  @override
  String get lockSetupOnceMore => 'Otra vez';

  @override
  String get lockSetupSetAPin => 'Elegir un PIN';

  @override
  String get lockSetupThoseWereDifferentFrom =>
      'No coinciden. Desde el principio.';

  @override
  String get lockSetupTheSameFourDigits => 'Los mismos dígitos otra vez';

  @override
  String get lockSetupFourDigitsAnythingYou =>
      'Cuatro dígitos o más que vayas a recordar';

  @override
  String get modesOnion => 'Onion';

  @override
  String get modesFullOnionRoutingThree =>
      'Enrutamiento onion completo, tres saltos. Un mensaje tarda de dos a cinco segundos. Nadie ve con quién hablas.';

  @override
  String get modesSlower => 'Más lento';

  @override
  String get modesRelay => 'Repetidor';

  @override
  String get modesOneSealedConnectionTo =>
      'Una sola conexión sellada al repetidor propio de Kryfo, como una vpn sin nada que registrar. Los envíos llegan en un segundo más o menos, y funciona donde tor está bloqueado.';

  @override
  String get modesQuick => 'Rápido';

  @override
  String get modesRelayOnly => 'Solo repetidor';

  @override
  String get modesFast => 'Rápido';

  @override
  String get modesPlainConnectionsToEvery =>
      'Conexiones normales a todos los repetidores. Casi instantáneo, y el menos privado de los tres.';

  @override
  String get modesInstant => 'Instantáneo';

  @override
  String get modesEveryRelayYouUse =>
      'Cada repetidor que usas conoce la dirección desde la que te conectas, no solo el nuestro. Los mensajes siguen sellados, pero el hecho de haber enviado uno no lo está. Desactivado por defecto, y desactivado de nuevo tras reinstalar.';

  @override
  String get modesSpeed => 'Velocidad';

  @override
  String get modesPrivacy => 'y privacidad';

  @override
  String get modesChangeGloballyOrPer => 'Cámbialo para todo o por chat';

  @override
  String get modesSoon => 'Pronto';

  @override
  String get modesActive => 'Activo';

  @override
  String get modesSpeed2 => 'VELOCIDAD';

  @override
  String get modesHops => 'SALTOS';

  @override
  String get modesIp => 'IP';

  @override
  String get modesVisible => 'Visible';

  @override
  String get modesHidden => 'Oculta';

  @override
  String modesHeadsUp(Object warning) {
    return '*Atención:* $warning';
  }

  @override
  String get modesOnionIsTheDefault =>
      'Onion es el modo predeterminado y seguirá así a menos que lo cambies. El cambio se aplica a partir del siguiente mensaje.';

  @override
  String get modesFastMode => 'Modo Rápido';

  @override
  String get modesPlainConnectionsToEveryRelayQuicker =>
      'Conexiones normales a todos los repetidores. Más rápido, y los repetidores pueden ver tu dirección IP. En ambos casos, los mensajes siguen cifrados de extremo a extremo.';

  @override
  String get modesTurnOnFastMode => 'Activar modo Rápido';

  @override
  String get modesKeepItOff => 'Dejarlo desactivado';

  @override
  String get movedWipeThisPhone => '¿Borrar Kryfo de este teléfono?';

  @override
  String get movedEverythingKryfoHoldsHere =>
      'Todo lo que Kryfo guarda aquí desaparece: los mensajes, los contactos, las claves. El otro dispositivo lo conserva todo. No se puede deshacer.';

  @override
  String get movedWipeIt => 'Borrar';

  @override
  String get movedNotMovingAfterAll => '¿Al final no te mudas?';

  @override
  String get movedOnlyDoThisIf =>
      'Hazlo solo si la copia de seguridad nunca se importó en ningún sitio. Si se importó, ahora hay dos dispositivos con una misma identidad, y empezarán a perderse mensajes en ambos.';

  @override
  String get movedIMStayingHere => 'Me quedo aquí';

  @override
  String get movedStayingHere => 'Te quedas aquí';

  @override
  String movedKryfoWillCloseNow(Object myId) {
    return 'Kryfo se cerrará ahora. Toca el icono para volver a abrirlo como $myId.';
  }

  @override
  String get movedReopenKryfo => 'Volver a abrir Kryfo';

  @override
  String get movedThisKryfoHasMoved => 'Este Kryfo se mudó';

  @override
  String movedIsNowOnAnother(Object myId) {
    return '$myId está ahora en otro dispositivo. Este teléfono aún puede mostrar lo que había aquí, pero no le llegará nada nuevo, y nada de lo que envíes desde aquí le llegará a nadie.';
  }

  @override
  String get movedKeepItToRead => 'Conservarlo para leer';

  @override
  String get movedWipeThisPhone2 => 'Borrar Kryfo de este teléfono';

  @override
  String get movedIMNotMoving => 'Al final no me mudo';

  @override
  String get myKryfoAHandleIs3 =>
      'Un nombre de usuario tiene de 3 a 20 letras, dígitos o _';

  @override
  String get myKryfoInviteCopiedClearsIn =>
      'Invitación copiada · se borra en 60s';

  @override
  String myKryfoAddMeOnKryfo(Object myId, Object uri) {
    return 'Añádeme en Kryfo. Mi ID es $myId\n\nToca para añadirme:\n$uri\n\nKryfo es una app de mensajería privada. Sin número de teléfono, sin correo.';
  }

  @override
  String get myKryfoAddMeOnKryfo2 => 'Añádeme en Kryfo';

  @override
  String get myKryfoAddSomeone => 'Añadir a alguien';

  @override
  String get myKryfoKryfoDoesnTScan =>
      'Kryfo no escanea tus contactos, de eso se trata.';

  @override
  String get myKryfoIfThisLinkEnds =>
      'Si este enlace acaba donde no querías, restablécelo en ajustes. Entonces todos los que lo tengan necesitarán uno nuevo.';

  @override
  String get myKryfoAlreadyShareAFriend =>
      '¿Ya tienes un amigo en común en Kryfo? Puede presentarte desde su chat y te saltas la solicitud.';

  @override
  String get myKryfoHandleCopied => 'Nombre de usuario copiado';

  @override
  String get myKryfoTheyReHereWith => 'Está aquí conmigo';

  @override
  String get myKryfoPointYourPhonesAt =>
      'Pon los teléfonos uno frente al otro. Nada pasa por un servidor.';

  @override
  String get myKryfoScanTheirsInstead => 'Escanear el suyo';

  @override
  String get myKryfoTheyReadYouA => 'Te dicta un código';

  @override
  String get myKryfoTheyReSomewhereElse => 'Está en otro sitio';

  @override
  String get myKryfoSendThemALink =>
      'Envíale un enlace. Se abre directamente en añadir.';

  @override
  String get myKryfoYourLinkAppearsOnce =>
      'Tu enlace aparece cuando estés conectado';

  @override
  String get myKryfoTheLinkCarriesYour =>
      'El enlace lleva tu ID, tu dirección y las claves para iniciar un chat. Funciona hasta que lo restablezcas en ajustes.';

  @override
  String get myKryfoSendTheLink => 'Enviar el enlace';

  @override
  String get myKryfoAsACard => 'Como tarjeta';

  @override
  String get myKryfoAnImageWithThe => 'Una imagen con el QR';

  @override
  String get myKryfoAsAFile => 'Como archivo';

  @override
  String get myKryfoContactFile => 'Archivo de contacto';

  @override
  String get myKryfoIKnowTheirHandle => 'Sé su nombre de usuario';

  @override
  String get myKryfoTypeTheNameThey =>
      'Escribe el @nombre que te dio. Funciona si reservó uno.';

  @override
  String get myKryfoWren => 'Wren';

  @override
  String get myKryfoTheLookupAsksFor =>
      'La búsqueda envía solo ese nombre y nada sobre ti. Tu primer mensaje le llega igualmente como solicitud.';

  @override
  String get myKryfoLooking => 'Buscando…';

  @override
  String get myKryfoFindThem => 'Buscar';

  @override
  String get myKryfoYourAddressAppearsOnce =>
      'Tu dirección aparece cuando estés conectado';

  @override
  String get myKryfoAPublicHandle => 'Un nombre de usuario público';

  @override
  String get myKryfoPutItInA =>
      'Ponlo en tu bio. Cualquiera que lo conozca puede encontrarte.';

  @override
  String get myKryfoANamePeopleCan =>
      'Un nombre con el que te pueden encontrar. Desactivado hasta que reserves uno.';

  @override
  String get newGroupCouldNotCreate => 'No se pudo crear';

  @override
  String get newGroupNewGroup => 'Nuevo grupo';

  @override
  String get newGroupCreating => 'Creando…';

  @override
  String get newGroupCreate => 'Crear';

  @override
  String get newGroupGroupName => 'Nombre del grupo';

  @override
  String get newGroupMembers => 'Miembros';

  @override
  String get newGroupPickAtLeastOne => 'Elige al menos uno';

  @override
  String newGroupSelected(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString seleccionados',
      one: '$countString seleccionado',
    );
    return '$_temp0';
  }

  @override
  String get newGroupAddAtLeastOne =>
      'Añade al menos un contacto antes de crear un grupo.';

  @override
  String get notesToday => 'HOY';

  @override
  String get notesYesterday => 'AYER';

  @override
  String get notesNoteToSelf => 'Notas';

  @override
  String get notesOnlyOnThisPhone => 'Solo en este teléfono';

  @override
  String get notesAQuietPlace => 'Un lugar tranquilo';

  @override
  String get notesJotAnythingDownIt =>
      'Apunta lo que quieras. Se queda en este teléfono y nunca sale de él.';

  @override
  String get notesJotSomethingDown => 'Apunta algo…';

  @override
  String get onboardingPrivateByDefault => 'PRIVADO POR DEFECTO';

  @override
  String get onboardingPrivateMessaging => 'Mensajería privada,\n*sin trampa*.';

  @override
  String get onboardingYourNameIsThree =>
      '*Tu nombre son tres palabras.* Sin teléfono, sin correo, sin agenda.';

  @override
  String get onboardingNobodyGetsInUnless =>
      '*Nadie entra a menos que tú lo permitas.* No hay búsqueda. Las personas se añaden a mano, en ambos sentidos.';

  @override
  String get onboardingTheFirstConnectionTakes =>
      '*La primera conexión tarda un minuto.* Kryfo construye una ruta privada antes de enviar. Después, es rápido.';

  @override
  String get onboardingBegin => 'Empezar';

  @override
  String get onboardingHaveABackupRestore => '¿Tienes una copia? Restaurar →';

  @override
  String get onboardingKryfoIsOpenSource => 'Kryfo es de código abierto';

  @override
  String get onboardingYourKryfoId => 'TU ID DE KRYFO';

  @override
  String get onboardingGeneratedFromAKey =>
      'Generado a partir de una clave que solo existe en este teléfono. *Fácil de recordar, único, solo tuyo.* Nadie más lo tiene.';

  @override
  String get onboardingTryAnother => 'Probar otro';

  @override
  String get onboardingUseThisName => 'Usar este nombre →';

  @override
  String get onboardingThreeWords => 'Tres palabras. *Solo tuyas.*';

  @override
  String get onboardingPickA => 'Elige una *cara*.';

  @override
  String get onboardingDrawnOnThisPhone =>
      'Dibujada en este teléfono a partir de un número, nunca se sube. Cámbiala cuando quieras.';

  @override
  String get onboardingThePeopleYouMessage =>
      'Las personas a las que escribes también la ven';

  @override
  String get onboardingKeepMyInitial => 'Mantener mi inicial';

  @override
  String get onboardingThatOne => 'Esa →';

  @override
  String get onboardingContinue => 'Continuar →';

  @override
  String get onboardingHowYourMessages => 'Cómo *viajan* tus mensajes.';

  @override
  String get onboardingYouCanChangeThis =>
      'Puedes cambiarlo cuando quieras en ajustes, para todos o para un chat.';

  @override
  String get onboardingOnion => 'Onion';

  @override
  String get onboardingSlowerAMessageTakes =>
      'Más lento. Un mensaje tarda de dos a cinco segundos.';

  @override
  String get onboardingHidesYourAddressFrom =>
      'Oculta tu dirección a todos, incluido nuestro repetidor.';

  @override
  String get onboardingRelay => 'Repetidor';

  @override
  String get onboardingOurRelaySeesYour =>
      'Nuestro repetidor ve tu dirección. Nadie más la ve.';

  @override
  String get onboardingAboutASecondWorks =>
      'Un segundo más o menos. Funciona donde tor está bloqueado.';

  @override
  String get onboardingFast => 'Rápido';

  @override
  String get onboardingEveryRelayYouUse =>
      'Cada repetidor que usas ve tu dirección. El menos privado de los tres.';

  @override
  String get onboardingNearInstant => 'Casi instantáneo.';

  @override
  String get onboardingKeepOnion => 'Mantener Onion →';

  @override
  String get onboardingUseThis => 'Usar este →';

  @override
  String get onboardingSkipOnionIsA =>
      'Omitir · Onion es una buena opción por defecto';

  @override
  String get onboardingThreeThingsThen => 'Tres cosas\ny *ya estás dentro*.';

  @override
  String get onboardingEverythingElseTheApp =>
      'Todo lo demás te lo dirá la app cuando importe.';

  @override
  String get onboardingYourNameIsThreeWords => 'Tu nombre son tres palabras';

  @override
  String get onboardingThatIsTheWhole =>
      'Esa es toda la identidad. Ningún número que filtrar, ningún correo para phishing, nada que buscar. Las personas con las que hablas ven estas palabras y la cara que elegiste.';

  @override
  String get onboardingNobodyCanReachYou =>
      'Nadie puede contactarte hasta que lo dejes entrar';

  @override
  String get onboardingAStrangerWithYour =>
      'Un desconocido con tus palabras solo puede llamar a la puerta. Su primer mensaje espera en solicitudes hasta que digas que sí, y puedes decir que no sin que se entere nunca.';

  @override
  String get onboardingTheFirstConnectionTakesAMinute =>
      'La primera conexión tarda un minuto';

  @override
  String get onboardingKryfoBuildsAPrivateRouteBefore =>
      'Kryfo construye una ruta privada antes de enviar nada. Mientras no tengas conexión, los mensajes esperan y llegan cuando vuelvas.';

  @override
  String get onboardingYourIdentityLivesOn =>
      'Tu identidad vive en este teléfono. Haz una copia de seguridad desde ajustes cuando quieras.';

  @override
  String get onboardingIUnderstand => 'Entendido →';

  @override
  String get onboardingOneQuiet => 'Una *notificación* discreta.';

  @override
  String get onboardingAndroidNeedsAVisible =>
      'Android necesita una notificación visible mientras una app escucha en segundo plano. Así te llegan los mensajes cuando Kryfo está cerrado.';

  @override
  String get onboardingSilentAndAtThe => 'Silenciosa y al final del panel';

  @override
  String get onboardingItNeverBuzzesTurn =>
      'Nunca vibra. Si la desactivas, los mensajes esperan hasta que vuelvas a abrir la app.';

  @override
  String get onboardingGotIt => 'Entendido →';

  @override
  String get onboardingNow => 'Ahora, *añade a alguien*.';

  @override
  String get onboardingTheAppIsReady =>
      'La app está lista. Nadie puede escribirte hasta que lo añadas o lo dejes entrar.';

  @override
  String get onboardingEveryWayToAdd => 'Todas las formas de añadir';

  @override
  String get onboardingShowYourCodeSend =>
      'Muestra tu código, envíale un enlace o escribe el nombre de usuario con @ que te dio.';

  @override
  String get onboardingScanTheirs => 'Escanear el suyo';

  @override
  String get onboardingPointTheCameraAt => 'Apunta la cámara a su código';

  @override
  String get onboardingTheAppIsReadyWhenYou =>
      'La app está lista cuando tú lo estés.';

  @override
  String get onboardingNotNowAddPeople =>
      'Ahora no · añadir personas más tarde';

  @override
  String get openLockedOpened => 'Abierto';

  @override
  String get openLockedOpenALockedFile => 'Abrir un archivo bloqueado';

  @override
  String get openLockedCheckingThePassword => 'Comprobando la contraseña';

  @override
  String get openLockedOpening => 'Abriendo';

  @override
  String get openLockedFile => 'Archivo';

  @override
  String get openLockedOpenFile => 'Abrir archivo';

  @override
  String get openLockedTypeThePassword => 'Escribe la contraseña.';

  @override
  String get openLockedItOpensOnThis => 'Se abre en este teléfono.';

  @override
  String get openLockedLockedFile => 'Archivo bloqueado';

  @override
  String openLockedFromFiles(Object prettySize) {
    return '$prettySize · de Archivos';
  }

  @override
  String get openLockedFromFiles2 => 'De Archivos';

  @override
  String get openLockedPassword => 'Contraseña';

  @override
  String get openLockedThePasswordIsChecked =>
      'Primero se comprueba la contraseña. Solo entonces Kryfo pregunta dónde poner el archivo abierto, y va directo allí.';

  @override
  String get openLockedOpened2 => 'Abierto.';

  @override
  String get openLockedSavedWhereYouChose => 'Guardado donde elegiste.';

  @override
  String get pairCodePairingCode => 'Código de emparejamiento';

  @override
  String get pairCodeShowACode => 'Mostrar un código';

  @override
  String get pairCodeEnterOne => 'Escribir uno';

  @override
  String get pairCodeSixDigits => 'Seis dígitos';

  @override
  String get pairCodeLooking => 'Buscando…';

  @override
  String get pairCodeNothingThereYetTrying => 'Aún no hay nada · reintentando';

  @override
  String get pairCodeNothingAtThatCode =>
      'No hay nada con ese código. Puede que ya haya desaparecido o que aún no lo haya compartido.';

  @override
  String get pairCodeTypeTheSixDigits =>
      'Escribe los seis dígitos que te dicte.';

  @override
  String get pairCodeAddThem => 'Añadir';

  @override
  String get panicSetupThoseWereDifferentFrom =>
      'No coinciden. Desde el principio.';

  @override
  String get panicSetupOnceMore => 'Otra vez';

  @override
  String get panicSetupTheSameFourDigits => 'Los mismos dígitos otra vez';

  @override
  String get photoKnowsEverythingInside => 'Todo lo que contiene';

  @override
  String get photoKnowsVideo => 'Video';

  @override
  String get photoKnowsPhoto => 'Foto';

  @override
  String get photoKnowsWhatThisVideoKnows => 'Lo que sabe este video';

  @override
  String get photoKnowsWhatThisPhotoKnows => 'Lo que sabe esta foto';

  @override
  String get photoKnowsRemoveAllOfIt => 'Quitarlo todo';

  @override
  String get photoKnowsKeepItAsIt => 'Dejarlo como está';

  @override
  String get photoKnowsReadOnThisPhone =>
      'LEÍDO EN ESTE TELÉFONO · EL VIDEO NO SALIÓ DE AQUÍ';

  @override
  String get photoKnowsReadOnThisPhoneThePhoto =>
      'LEÍDO EN ESTE TELÉFONO · LA FOTO NO SALIÓ DE AQUÍ';

  @override
  String get photoKnowsReadingTheFile => 'Leyendo el archivo';

  @override
  String photoKnowsOf(Object prettySize, Object prettySize2) {
    return '$prettySize de $prettySize2';
  }

  @override
  String get photoKnowsEverythingStaysOnThis =>
      'Todo se queda en este teléfono.';

  @override
  String photoKnowsMapWithAPin(Object place) {
    return 'Mapa con un marcador. $place';
  }

  @override
  String get photoKnowsDrawnOffline => 'DIBUJADO SIN CONEXIÓN';

  @override
  String photoKnowsShowEverything(Object title) {
    return '$title. Mostrar todo';
  }

  @override
  String get pinsAppLock => 'Bloqueo de la app';

  @override
  String get pinsYourPin => 'Tu PIN';

  @override
  String get commonOn => 'Activado';

  @override
  String get commonOff => 'Desactivado';

  @override
  String get pinsOpensKryfoFourDigits =>
      'Abre Kryfo. Se pide cada vez que vuelve a primer plano.';

  @override
  String get pinsChangePin => 'Cambiar PIN';

  @override
  String get pinsSetAPin => 'Elegir un PIN';

  @override
  String get pinsTurnOff => 'Desactivar';

  @override
  String get pinsTurnOffTheApp => '¿Desactivar el bloqueo de la app?';

  @override
  String get pinsThePinGoesAnd =>
      'El PIN desaparece, y con él el PIN de borrado y cualquier chat oculto. Cualquiera que tenga tu teléfono abrirá Kryfo como si fuera tú.';

  @override
  String get pinsUnlockWithFingerprint => 'Desbloquear con huella';

  @override
  String get pinsWipePin => 'PIN de borrado';

  @override
  String get pinsNeedsAPinFirst => 'Primero necesita un PIN';

  @override
  String get pinsSet => 'Definido';

  @override
  String get pinsChangeWipePin => 'Cambiar PIN de borrado';

  @override
  String get pinsSetAWipePin => 'Elegir un PIN de borrado';

  @override
  String get pinsRemove => 'Quitar';

  @override
  String get pinsRemoveTheWipePin => '¿Quitar el PIN de borrado?';

  @override
  String get pinsTheLockScreenKeeps =>
      'La pantalla de bloqueo mantiene tu PIN. El PIN de borrado deja de hacer nada.';

  @override
  String profileCopied(Object what) {
    return 'Copiado: $what';
  }

  @override
  String get profileProfile => 'Perfil';

  @override
  String get profileChangeYourFace => 'Cambiar tu cara';

  @override
  String get profileKryfoId => 'ID de Kryfo';

  @override
  String get profileOnionAddress => 'Dirección onion';

  @override
  String get profileSupporterBadge => 'Insignia de colaborador';

  @override
  String profileYouAreAThank(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter': 'Eres colaborador. Gracias.',
      'patron': 'Eres mecenas. Gracias.',
      'guardian': 'Eres guardián. Gracias.',
      'other': 'Eres colaborador. Gracias.',
    });
    return '$_temp0';
  }

  @override
  String get profileShowMyBadge => 'Mostrar mi insignia';

  @override
  String get profileOnMyOwnScreens => 'En mis propias pantallas';

  @override
  String get profileLetContactsSeeIt => 'Que la vean mis contactos';

  @override
  String get profileOffByDefault => 'Desactivado por defecto';

  @override
  String get profileShareConnect => 'Compartir y conectar';

  @override
  String get profileMyKryfoCode => 'Mi código de Kryfo';

  @override
  String get profileAddContact => 'Añadir contacto';

  @override
  String get profileGiveAgain => 'Volver a donar';

  @override
  String get profileSupportKryfo => 'Apoyar a Kryfo';

  @override
  String get profileKryfoRunsOnWhat => 'Kryfo vive de lo que aporta la gente';

  @override
  String get profileKeepKryfoIndependent => 'Mantén Kryfo independiente';

  @override
  String get qrLink => 'Enlace';

  @override
  String get qrYourLinkAsTyped =>
      'TU ENLACE TAL CUAL · SIN REDIRECCIÓN DE RASTREO';

  @override
  String get qrText => 'Texto';

  @override
  String get qrStaysInTheCode =>
      'SE QUEDA EN EL CÓDIGO · NINGÚN SERVIDOR LO GUARDA';

  @override
  String get qrWiFi => 'Wi-Fi';

  @override
  String get qrMadeOnThisPhone =>
      'HECHO EN ESTE TELÉFONO · NINGUNA WEB VIO LA CONTRASEÑA';

  @override
  String get qrNetworkName => 'Nombre de la red';

  @override
  String get qrPassword => 'Contraseña';

  @override
  String get qrContact => 'Contacto';

  @override
  String get qrOnlyWhatYouType =>
      'SOLO LO QUE ESCRIBES · NADA DE TUS CONTACTOS';

  @override
  String get qrName => 'Nombre';

  @override
  String get qrPhone => 'Teléfono';

  @override
  String get qrEmail => 'Correo';

  @override
  String get qrOpensTheirMailApp =>
      'ABRE SU APP DE CORREO · NO SE ENVÍA NADA DESDE AQUÍ';

  @override
  String get qrTo => 'Para';

  @override
  String get qrSubject => 'Asunto';

  @override
  String get qrANumberNothingElse => 'UN NÚMERO · NADA MÁS';

  @override
  String get qrNumber => 'Número';

  @override
  String get qrSms => 'SMS';

  @override
  String get qrOpensTheirMessagesApp =>
      'ABRE SU APP DE MENSAJES · NO SE ENVÍA NADA DESDE AQUÍ';

  @override
  String get qrMessage => 'Mensaje';

  @override
  String get qrLocation => 'Ubicación';

  @override
  String get qrCoordinatesOnlyNoMap => 'SOLO COORDENADAS · SIN CONSULTAR MAPAS';

  @override
  String get qrLatitude => 'Latitud';

  @override
  String get qrLongitude => 'Longitud';

  @override
  String get qrBitcoin => 'Bitcoin';

  @override
  String get qrAddressAndAmountNo =>
      'DIRECCIÓN Y CANTIDAD · SIN WEB DE PAGO DE POR MEDIO';

  @override
  String get qrAddress => 'Dirección';

  @override
  String get qrAmountInBtc => 'Cantidad en BTC';

  @override
  String get qrInk => 'Tinta';

  @override
  String get qrAmber => 'Ámbar';

  @override
  String get qrViolet => 'Violeta';

  @override
  String get qrCouldNotDrawThe => 'No se pudo dibujar la imagen.';

  @override
  String get qrSavedToYourGallery => 'Guardado en tu galería';

  @override
  String get qrCouldNotSaveIt =>
      'No se pudo guardar. Comprueba que el teléfono tenga espacio.';

  @override
  String get qrNoAppOnThis => 'Ninguna app de este teléfono aceptó la imagen.';

  @override
  String get qrTooMuchForOne => 'Demasiado para un solo código. Acórtalo.';

  @override
  String get qrThisIsALot =>
      'Es mucho para un solo código. Puede que las cámaras antiguas no lo lean.';

  @override
  String get qrPrivateQrCode => 'Código QR privado';

  @override
  String get qrColour => 'Color';

  @override
  String get qrCopiedItLeavesThe =>
      'Copiado. Se quita del portapapeles en un minuto';

  @override
  String get qrSecurity => 'Seguridad';

  @override
  String get qrNone => 'Ninguna';

  @override
  String get qrSaveImage => 'Guardar imagen';

  @override
  String qrColour2(Object name) {
    return 'Color $name';
  }

  @override
  String get qrTypeBelowAndThe => 'Escribe abajo y el\ncódigo se dibuja solo';

  @override
  String get qrQrCode => 'Código QR';

  @override
  String get qrHidePassword => 'Ocultar contraseña';

  @override
  String get qrShowPassword => 'Mostrar contraseña';

  @override
  String get qrCopyPassword => 'Copiar contraseña';

  @override
  String get requestsSentAnAttachment => 'Envió un adjunto';

  @override
  String get requestsWantsToConnect => 'Quiere conectar';

  @override
  String get requestsAccepted => 'Aceptado';

  @override
  String requestsBlock(Object id) {
    return '¿Bloquear a $id?';
  }

  @override
  String get requestsNothingMoreFromThem =>
      'No te llegará nada más de esa persona. Su solicitud y sus mensajes desaparecen.';

  @override
  String get requestsBlocked => 'Bloqueado';

  @override
  String get requestsDeleted => 'Eliminado';

  @override
  String get requestsRequests => 'Solicitudes';

  @override
  String get requestsNoRequests => 'Sin solicitudes';

  @override
  String get requestsMessagesFromPeopleYou =>
      'Los mensajes de personas que no has añadido aparecen primero aquí.';

  @override
  String get requestsLooksSafeNothingSuspicious =>
      'Parece seguro · nada sospechoso en su primer mensaje';

  @override
  String get commonAccept => 'Aceptar';

  @override
  String get requestsDecline => 'Rechazar';

  @override
  String get restoreThatFileIsNot =>
      'Ese archivo no es una copia de seguridad de Kryfo';

  @override
  String get restoreThisFileIsDamaged =>
      'Este archivo está dañado y no se puede leer';

  @override
  String get restoreTypeThePassphraseThe =>
      'Escribe la frase de contraseña con la que se creó el archivo';

  @override
  String get restoreReplaceTheAccountOn =>
      '¿Reemplazar la cuenta de este teléfono?';

  @override
  String get restoreWhatIsHereNow =>
      'Lo que hay ahora aquí, con su identidad, contactos y mensajes, desaparece. El archivo ocupa su lugar. No se puede deshacer.';

  @override
  String get restoreReplaceIt => 'Reemplazar';

  @override
  String restoreCouldNotBeReleased(Object mine) {
    return 'No se pudo liberar @$mine';
  }

  @override
  String restoreTheRegistryDidNot(Object mine) {
    return 'El registro no respondió. Si sigues, @$mine seguirá apuntando a la identidad que este teléfono está a punto de perder. Lo que escriba quien lo añada no le llegará a nadie, y el nombre no se podrá volver a reservar. Mejor conéctate y vuelve a intentarlo.';
  }

  @override
  String get restoreRestoreAnyway => 'Restaurar igualmente';

  @override
  String get restoreNotYet => 'Aún no';

  @override
  String get restoreRestored => 'Restaurado';

  @override
  String restoreKryfoWillCloseNow(Object haloId) {
    return 'Kryfo se cerrará ahora. Toca el icono para volver a abrirlo como $haloId.';
  }

  @override
  String get restoreReopenKryfo => 'Volver a abrir Kryfo';

  @override
  String get restoreTheRestoreDidNot =>
      'La restauración no terminó. No se cambió nada';

  @override
  String get restoreThisIdentity => 'esta identidad';

  @override
  String get restoreMoveYourKryfoHere => 'Trae tu Kryfo aquí';

  @override
  String restoreThisBackupIsRestoring(Object name) {
    return 'Esta copia de seguridad es de $name. Restaurarla trae esa identidad a este dispositivo.';
  }

  @override
  String restoreThisBackupMadeOn(Object name, Object date, Object time) {
    return 'Esta copia de seguridad es de $name, creada el $date a las $time. Restaurarla trae esa identidad a este dispositivo.';
  }

  @override
  String restoreItHoldsOfPhotos(Object mb) {
    return 'Contiene $mb de fotos, notas de voz y archivos. Puede tardar unos minutos. Deja la app abierta.';
  }

  @override
  String get restoreWhatFollows => 'Lo que viene';

  @override
  String get restoreYourNameYourCode =>
      'Tu nombre, tu código y todos tus contactos.';

  @override
  String get restoreEveryConversationBackTo =>
      'Todas las conversaciones, desde el principio.';

  @override
  String get restoreYourPhotosVoiceNotes =>
      'Tus fotos, notas de voz y archivos.';

  @override
  String restoreYourPhotosVoiceNotesCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tus fotos, notas de voz y archivos · $countString.',
    );
    return '$_temp0';
  }

  @override
  String get restoreYourOnionAddressSo =>
      'Tu dirección onion, para que quienes te contactan directamente sigan llegándote.';

  @override
  String get restoreAnythingSentToYou =>
      'Lo que te enviaron mientras el teléfono antiguo estaba apagado, hasta catorce días después del envío.';

  @override
  String get restoreYourSupporterBadgeIf =>
      'Tu insignia de colaborador, si tienes una.';

  @override
  String get restoreWhatDoesnT => 'Lo que no';

  @override
  String get restoreTheOldPhoneStops =>
      'El teléfono antiguo deja de recibir en cuanto envías algo desde aquí. No poco a poco. El primer mensaje que envíes desde este dispositivo es el último que el teléfono antiguo puede seguir, y lo que le llegue después no se podrá leer allí ni te estará esperando aquí.';

  @override
  String get restoreIfThePhoneThis =>
      'Si el teléfono del que viene este archivo sigue en uso, deja de usar Kryfo en él antes de continuar. Dos teléfonos con un mismo Kryfo pierden mensajes en ambos.';

  @override
  String get restoreNotificationsNeedSettingUp =>
      'Hay que volver a configurar las notificaciones en este dispositivo.';

  @override
  String get restoreMoveItHere => 'Traerlo aquí';

  @override
  String get restoreNotNow => 'Ahora no';

  @override
  String get restoreRestore => 'Restaurar';

  @override
  String get restoreFromABackupFile => 'Desde una copia de seguridad';

  @override
  String get restoreABackupBringsBack =>
      'Una copia de seguridad recupera tu identidad y tus contactos, y los mensajes que había en el teléfono cuando se creó el archivo. Lo que se haya dicho después no está incluido.';

  @override
  String get restoreTheFile => 'El archivo';

  @override
  String get restorePickTheBackupFile => 'Elige el archivo de la copia';

  @override
  String get restoreThePassphrase => 'La frase de contraseña';

  @override
  String get restoreTheOneTheFile => 'Con la que se creó el archivo';

  @override
  String get restoreWhatComesBack => 'Lo que se recupera';

  @override
  String get restoreChecking => 'Comprobando…';

  @override
  String get restoreCheckTheFile => 'Comprobar el archivo';

  @override
  String get restoreReleasingYourHandle => 'Liberando tu nombre de usuario…';

  @override
  String restoreMoving(Object progress) {
    return 'Trasladando… $progress';
  }

  @override
  String get restoreRestoring => 'Restaurando…';

  @override
  String get restoreNotThisOne => 'Este no';

  @override
  String get restoreDateUnknown => 'Fecha desconocida';

  @override
  String get restoreAnIdentity => 'Una identidad';

  @override
  String get restoreMessagesSentOrReceived =>
      'Los mensajes enviados o recibidos después de esa fecha no están en este archivo.';

  @override
  String restoreGb(Object bytes) {
    return '$bytes GB';
  }

  @override
  String restoreMb(Object bytes) {
    return '$bytes MB';
  }

  @override
  String get roomCreateCouldNotCreateThe => 'No se pudo crear la sala';

  @override
  String get roomCreateBurnerRoom => 'Sala efímera';

  @override
  String get roomCreateARoomThatEnds =>
      'Una sala que termina. Todos entran con una clave creada para ella, y cuando termina no queda nada en ningún teléfono.';

  @override
  String get roomCreateRoomName => 'Nombre de la sala';

  @override
  String get roomCreateEndsAfter => 'Termina tras';

  @override
  String get roomCreateMemberCap => 'Límite de miembros';

  @override
  String roomCreateNoOnePastThe(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Nadie después de los primeros $countString',
      one: 'Nadie después del primero',
    );
    return '$_temp0';
  }

  @override
  String get roomCreateOffAnyoneWithThe =>
      'Desactivado. Cualquiera con el enlace';

  @override
  String roomCreateThisRoomAndEverything(Object expiryWords) {
    return 'Esta sala y todo lo que contiene desaparecen en $expiryWords';
  }

  @override
  String get roomCreateCreating => 'Creando...';

  @override
  String get roomCreateCreateRoom => 'Crear sala';

  @override
  String get roomLinkSendTheRoomTo => 'Enviar la sala a';

  @override
  String get roomLinkTheyWillKnowThis =>
      'Sabrá que esta sala viene de ti. Dentro, será una clave más, como todos.';

  @override
  String get roomLinkNoContactsYet => 'Aún no hay contactos';

  @override
  String roomLinkEndsIn(Object time) {
    return 'Termina en $time';
  }

  @override
  String get roomLinkAnyoneWithThisCan =>
      'Cualquiera con esto puede unirse hasta que termine la sala. Entra con una clave creada para esta sala y no ve nada de lo enviado antes de su llegada.';

  @override
  String get roomLinkRoomLinkCopied => 'Enlace de la sala copiado';

  @override
  String get roomLinkSendToAContact => 'Enviar a un contacto';

  @override
  String get roomLinkCopyRoomLink => 'Copiar enlace de la sala';

  @override
  String get savedVoiceNote => 'Nota de voz';

  @override
  String get savedPhoto => 'Foto';

  @override
  String get savedSaved => 'Guardados';

  @override
  String get savedNothingSavedYet => 'Aún no hay nada guardado';

  @override
  String get savedLongPressAnyMessage =>
      'Mantén presionado cualquier mensaje y toca guardar para tenerlo aquí.';

  @override
  String get savedViewInChat => 'Ver en el chat';

  @override
  String get savedPhoto2 => 'Foto';

  @override
  String get scanThatSNotA => 'Eso no es un QR de Kryfo · sigue apuntando';

  @override
  String get scanScanAKryfoQr => 'Escanear un QR de Kryfo';

  @override
  String get scanFlash => 'Flash';

  @override
  String get scanPointAtAKryfo =>
      'Apunta a un QR de Kryfo · nada sale de tu teléfono';

  @override
  String get seenWhatWeCanSee => 'Lo que podemos ver';

  @override
  String get seenEveryMessengerClaimsPrivacy =>
      'Todas las apps de mensajería dicen ser privadas. Esta es la lista concreta, por ruta, incluidas las partes que no nos dejan bien. Toca una fila para ver el porqué.';

  @override
  String get seenHonestAboutTheLast =>
      'Con sinceridad sobre las últimas filas: para eso están el bloqueo de la app, el PIN de borrado y el almacenamiento cifrado, y ninguna herramienta te salva de alguien que tenga tu teléfono abierto. El modelo de amenazas completo está en THREAT_MODEL.md en el repositorio, redactado según LINDDUN. El código es abierto, así que nada de esto hay que creérselo sin más.';

  @override
  String get seenHidden => 'Oculto';

  @override
  String get seenNever => 'Nunca';

  @override
  String get seenOnDevice => 'En el teléfono';

  @override
  String get seenYours => 'Tuyo';

  @override
  String get seenUnaudited => 'Sin auditar';

  @override
  String get seenWhoYouTalkTo => 'Con quién hablas';

  @override
  String get seenEachConversationGetsIts =>
      'Cada conversación tiene su propia dirección, derivada de ambas claves. Un repetidor ve buzones sin relación entre sí, no una pareja de personas.';

  @override
  String get seenWhatYouSay => 'Lo que dices';

  @override
  String get seenEndToEndEncrypted =>
      'Cifrado de extremo a extremo con el doble ratchet de Signal y sellado otra vez dentro de un gift wrap. No podríamos leerlo aunque lo intentáramos.';

  @override
  String get seenYourIpAddress => 'Tu dirección IP';

  @override
  String get seenOurRelay => 'Nuestro repetidor';

  @override
  String get seenEveryRelay => 'Cada repetidor';

  @override
  String get seenOnOnionEverythingLeaves =>
      'En Onion todo sale por tor y el repetidor ve un nodo de salida, nunca a ti. En modo Repetidor la conexión va directa a nuestro propio repetidor: nada reenvía tu dirección y nada se anota, pero esa única conexión sí la podemos ver. En Rápido, cada repetidor público sabe que te conectaste, aunque no con quién ni qué dijiste.';

  @override
  String get seenYourContactGraph => 'Tu red de contactos';

  @override
  String get seenKryfoDoesNotScan =>
      'Kryfo no escanea tus contactos. De eso se trata. Aquí no existe ningún número de teléfono que se pueda filtrar.';

  @override
  String get seenIntroducer => 'Quien presenta';

  @override
  String get seenWhenAContactIntroduces =>
      'Cuando un contacto te presenta a alguien, ese contacto sabe que ahora tú y esa persona están conectados. Nadie más lo sabe. El repetidor ve texto cifrado, y ningún servidor ve nunca la red.';

  @override
  String get seenTheScamShield => 'El escudo antiestafas';

  @override
  String get seenRunsOnYourPhone =>
      'Funciona en tu teléfono con reglas que vienen en la app. Sin red, sin descargar listas. Solo lee el primer mensaje de un desconocido y no puede ver nada de lo que te envía un contacto.';

  @override
  String get seenBurnerRooms => 'Salas efímeras';

  @override
  String get seenRoomKeys => 'Claves de sala';

  @override
  String get seenYouJoinARoom =>
      'Entras en una sala con una clave creada para ella, así que quienes están dentro no obtienen nada que sirva en otra parte. Quien llega tarde no recibe el historial. Al expirar, se destruyen las claves, los mensajes y los archivos.';

  @override
  String get seenLinkPreviews => 'Vistas previas de enlaces';

  @override
  String get seenOverTor => 'Por Tor';

  @override
  String get seenAPreviewIsFetched =>
      'La vista previa la obtiene quien envía, por tor, y viaja dentro del mensaje cifrado. El teléfono que recibe no hace ninguna petición. La web solo sabe que alguien que usa tor pidió una página, nada más. Nunca se carga ninguna imagen, y el enlace de un desconocido se queda como texto plano.';

  @override
  String get seenASeizedUnlockedPhone => 'Un teléfono incautado y desbloqueado';

  @override
  String get seenIfSomeoneHoldsYour =>
      'Si alguien tiene tu teléfono abierto, lee tus mensajes. El bloqueo de la app, el PIN de borrado y el almacenamiento cifrado ayudan antes de ese momento, no después.';

  @override
  String get seenTheCryptoItself => 'La criptografía en sí';

  @override
  String get seenTheRatchetAndStorage =>
      'Las capas de ratchet y de almacenamiento son estándar. La capa que las une es nuestra y nadie independiente la ha revisado. Trátalo como una versión alfa, porque lo es.';

  @override
  String get seenOnion => 'Onion';

  @override
  String get seenRelay => 'Repetidor';

  @override
  String get seenFast => 'Rápido';

  @override
  String get settingsWipeKryfo => '¿Borrar Kryfo?';

  @override
  String get settingsIdentityMessagesContactsAnd =>
      'Identidad, mensajes, contactos y ajustes de este teléfono. Desaparecen para siempre salvo que tengas una copia de seguridad.';

  @override
  String get commonContinue => 'Continuar';

  @override
  String settingsTypeWipeToConfirm(Object word) {
    return 'Escribe «$word» para confirmar';
  }

  @override
  String get settingsTheLastStepNothing => 'El último paso. Nada sobrevive.';

  @override
  String get settingsWipeWord => 'borrar';

  @override
  String get settingsWipeKryfo2 => 'Borrar Kryfo';

  @override
  String get settingsYourProtections => 'Tus protecciones';

  @override
  String get settingsTorRouting => 'Enrutamiento tor';

  @override
  String get settingsConnecting => 'Conectando';

  @override
  String get settingsOffMode => 'Apagado · modo Repetidor';

  @override
  String get settingsOffFastMode => 'Apagado · modo Rápido';

  @override
  String get settingsAppLock => 'Bloqueo de la app';

  @override
  String get settingsBlockedByAndroid => 'Bloqueado por Android';

  @override
  String get settingsSpeedPrivacy => 'Velocidad y privacidad';

  @override
  String get settingsFast => 'Rápido';

  @override
  String get settingsRelay1Hop => 'Repetidor · 1 salto';

  @override
  String get settingsOnion3Hops => 'Onion · 3 saltos';

  @override
  String get settingsBridges => 'Puentes';

  @override
  String get settingsForNetworksThatBlock => 'Para redes que bloquean tor';

  @override
  String get settingsGettingMessages => 'Recibir mensajes';

  @override
  String settingsPreviewHidden(Object deliveryModeName) {
    return '$deliveryModeName · vista previa oculta';
  }

  @override
  String settingsPreviewShown(Object deliveryModeName) {
    return '$deliveryModeName · vista previa visible';
  }

  @override
  String get settingsRunInBackground => 'Funcionar en segundo plano';

  @override
  String get settingsSoMessagesArrive => 'Para que lleguen los mensajes';

  @override
  String get settingsTransport => 'Transporte';

  @override
  String get settingsWhatTheNetworkIs => 'Qué está haciendo la red';

  @override
  String get settingsBlocked => 'Bloqueados';

  @override
  String get settingsAcceptIntroductions => 'Aceptar presentaciones';

  @override
  String get settingsFriendsCanIntroduceYou =>
      'Tus amigos pueden presentarte a los suyos';

  @override
  String get settingsScamShield => 'Escudo antiestafas';

  @override
  String get settingsChecksStrangersOnYour =>
      'Revisa a los desconocidos en tu teléfono. Nada sale de él';

  @override
  String get settingsBlockScreenshots => 'Bloquear capturas';

  @override
  String get settingsWholeAppHiddenFrom =>
      'Toda la app oculta en recientes y capturas · se aplica tras el próximo inicio';

  @override
  String get settingsWholeAppHiddenFromRecentsAnd =>
      'Toda la app oculta en recientes y capturas';

  @override
  String get settingsOnNextStart => 'Activo · al reiniciar';

  @override
  String get settingsOffNextStart => 'Inactivo · al reiniciar';

  @override
  String get settingsLightTheme => 'Tema claro';

  @override
  String get settingsSameProtectionBrighter => 'La misma protección, más clara';

  @override
  String get settingsAppLock2 => 'Bloqueo de la app';

  @override
  String get settingsYourPinAndA => 'Tu PIN y protección avanzada';

  @override
  String get settingsPinWipePin => 'PIN · PIN de borrado';

  @override
  String get settingsBackUpIdentity => 'Hacer copia de seguridad';

  @override
  String get settingsEncryptedFile => 'Archivo cifrado';

  @override
  String get settingsRestoreFromBackup => 'Restaurar copia de seguridad';

  @override
  String get settingsReplaceCurrent => 'Reemplaza la actual';

  @override
  String get settingsDisguiseVoice => 'Disfrazar la voz';

  @override
  String get settingsShiftsYourPitchBefore =>
      'Cambia tu tono antes de que salga una nota de voz';

  @override
  String get settingsWhyKryfo => 'Por qué Kryfo';

  @override
  String get settingsHowItProtectsYou => 'Cómo te protege';

  @override
  String get settingsResetMyInviteLink => 'Restablecer enlace de invitación';

  @override
  String get settingsOldLinksAndCodes =>
      'Los enlaces y códigos antiguos dejan de funcionar, para todos';

  @override
  String get settingsResetInviteLink => '¿Restablecer el enlace de invitación?';

  @override
  String get settingsAnyoneWithAnOld =>
      'Quien tenga un código o enlace antiguo deja de poder contactarte, por cualquier ruta. Quien lo tenga pero nunca lo haya usado necesitará uno nuevo tuyo. Los contactos, chats e historial se mantienen.';

  @override
  String get settingsReset => 'Restablecer';

  @override
  String get settingsInviteResetShareThe =>
      'Invitación restablecida · comparte el nuevo código';

  @override
  String get settingsWhatWeCanSee => 'Lo que podemos ver';

  @override
  String get settingsTheHonestList => 'La lista honesta';

  @override
  String get settingsVersion => 'Versión';

  @override
  String get settings030Alpha => '0.4.1 · alfa';

  @override
  String get settingsReportAnIssue => 'Informar de un problema';

  @override
  String get settingsBugOrSecurityFlaw => 'Error o fallo de seguridad';

  @override
  String get settingsOpenSource => 'Código abierto';

  @override
  String get settingsLinkCopied => 'Enlace copiado';

  @override
  String get settingsTheOfflineMapIn =>
      'El mapa sin conexión de Herramientas se dibuja con datos de Natural Earth (dominio público). Los nombres de poblaciones son de GeoNames, geonames.org, bajo CC BY 4.0.';

  @override
  String get settingsNotIndependentlyAuditedPre =>
      'Sin auditoría independiente. Prealfa: sirve para probar, aún no para usos en los que haya mucho en juego.';

  @override
  String get settingsDangerZone => 'Zona de peligro';

  @override
  String get settingsWipeKryfoFromThis => 'Borrar Kryfo de este teléfono';

  @override
  String get shieldCheckedOnThisPhone =>
      'Revisado en este teléfono. No se envió nada a ningún sitio.';

  @override
  String get toolsMoreTools => 'Más herramientas';

  @override
  String get toolsCleanAPhotoOr => 'Limpiar una foto o un video';

  @override
  String get toolsOrShareOneTo => 'O compártelo con Kryfo desde tu galería';

  @override
  String get toolsMakeAPrivateQr => 'Crear un código QR privado';

  @override
  String get toolsLinksWiFiContacts =>
      'Enlaces, Wi-Fi, contactos y más. Hecho sin conexión';

  @override
  String get toolsLockAFile => 'Bloquear un archivo';

  @override
  String get toolsWithAPasswordOpens =>
      'Con una contraseña. Se abre en cualquier sitio con age';

  @override
  String get toolsOpenALockedFile => 'Abrir un archivo bloqueado';

  @override
  String get toolsAnyAgeFileSomeone =>
      'Cualquier archivo .age que te hayan enviado';

  @override
  String get toolsWorksOfflineNoContacts =>
      'Funciona sin conexión · no hacen falta contactos';

  @override
  String get toolsUsefulFrom => 'Útil desde';

  @override
  String get toolsTheFirstMinute => 'el primer minuto.';

  @override
  String get toolsEverythingHereHappensOn =>
      'Todo aquí ocurre en este teléfono. No se sube nada, y nadie más tiene que estar en Kryfo.';

  @override
  String get toolsWhatDoesThisPhoto => '¿Qué sabe esta foto?';

  @override
  String get toolsPlacePhoneTime => 'Lugar · teléfono · hora';

  @override
  String get toolsPickAPhotoAnd =>
      'Elige una foto y mira lo que revela. Luego guarda una copia limpia.';

  @override
  String get toolsPickAPhoto => 'Elegir una foto';

  @override
  String get toolsVideo => 'Video';

  @override
  String get transportTransport => 'Transporte';

  @override
  String get transportNothingHereLeavesThe =>
      'Nada de esto sale del teléfono. Es el mismo estado que usa el motor para decidir qué hacer.';

  @override
  String get transportStayingAlive => 'Manteniéndose activo';

  @override
  String get transportCanSend => 'Puede enviar';

  @override
  String get commonYes => 'Sí';

  @override
  String get transportNotYet => 'Aún no';

  @override
  String get transportOnline => 'En línea';

  @override
  String get transportOffline => 'Sin conexión';

  @override
  String get transportQueuedToSend => 'En cola para enviar';

  @override
  String get transportOnionPublished => 'Onion publicado';

  @override
  String transportYes(Object uploads) {
    return 'Sí ($uploads)';
  }

  @override
  String transportTryingS(Object pubFor) {
    return 'Intentando ${pubFor}s';
  }

  @override
  String transportBenchedS(Object r) {
    return 'En pausa ${r}s';
  }

  @override
  String transportFails(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString fallos',
      one: '$countString fallo',
    );
    return '$_temp0';
  }

  @override
  String get transportOk => 'OK';

  @override
  String get transportRelaySubscriptions => 'Suscripciones a repetidores';

  @override
  String get transportLastSent => 'Último envío';

  @override
  String get transportNever => 'Nunca';

  @override
  String transportSAgo(Object sx) {
    return 'hace ${sx}s';
  }

  @override
  String get transportLastReceived => 'Última recepción';

  @override
  String transportSAgo2(Object rx) {
    return 'hace ${rx}s';
  }

  @override
  String get transportWithNoContactsThe =>
      'Sin contactos, la app no se suscribe a ninguna dirección de repetidor, así que no te puede llegar ningún mensaje. Escanea a alguien para arreglarlo.';

  @override
  String get transportSendAnythingWaitingNow => 'Enviar ahora lo pendiente';

  @override
  String get transportOff => 'Desactivado';

  @override
  String get transportStarting => 'Iniciando';

  @override
  String get transportBootstrapped => 'Arrancado';

  @override
  String get transportPublishingAddress => 'Publicando dirección';

  @override
  String get transportReachable => 'Accesible';

  @override
  String get transportOurRelayOnion => 'Nuestro repetidor (onion)';

  @override
  String get transportNever2 => 'nunca';

  @override
  String get transportJustNow => 'Ahora mismo';

  @override
  String transportMAgo(Object inMinutes) {
    return 'hace ${inMinutes}m';
  }

  @override
  String transportHAgo(Object inHours) {
    return 'hace ${inHours}h';
  }

  @override
  String transportDAgo(Object inDays) {
    return 'hace ${inDays}d';
  }

  @override
  String transportM(Object inMinutes) {
    return '${inMinutes}m';
  }

  @override
  String transportHM(Object inHours, Object d) {
    return '${inHours}h ${d}m';
  }

  @override
  String transportD(Object inDays) {
    return '${inDays}d';
  }

  @override
  String transportMb(Object b) {
    return '$b MB';
  }

  @override
  String get transportYesCheckedJustNow => 'Sí · comprobado ahora mismo';

  @override
  String transportNoLast(Object ago) {
    return 'No · última vez $ago';
  }

  @override
  String get transportLastMessageIn => 'Último mensaje recibido';

  @override
  String get transportBatteryExemption => 'Exención de batería';

  @override
  String get transportUnknown => 'Desconocido';

  @override
  String get transportExempt => 'Exento';

  @override
  String get transportNotExemptTapTo => 'No exento · toca para arreglarlo';

  @override
  String get transportProcessUp => 'Proceso activo';

  @override
  String get transportLastStop => 'Última parada';

  @override
  String transportEngine(Object mb, Object mb2) {
    return '$mb · motor $mb2';
  }

  @override
  String get transportLastRelayArrival => 'Última llegada por repetidor';

  @override
  String get transportLastCheckIn => 'Última consulta';

  @override
  String get transportNoneYet => 'Ninguna aún';

  @override
  String get transportLastTorReconnect => 'Última reconexión de Tor';

  @override
  String get transportCatchUpByRelay => 'Puesta al día por repetidor';

  @override
  String get transportControlPort => 'Puerto de control';

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
      other: '$dialsString intentos',
      one: '$dialsString intento',
    );
    String _temp1 = intl.Intl.pluralLogic(
      timeouts,
      locale: localeName,
      other: '$timeoutsString sin respuesta',
      one: '$timeoutsString sin respuesta',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get transportJobRuns => 'Ejecuciones';

  @override
  String transportLast(Object jobRuns, Object ago) {
    return '$jobRuns · última $ago';
  }

  @override
  String get transportQuietStretches => 'Periodos de silencio';

  @override
  String get transportNone => 'Ninguno';

  @override
  String get transportClearThisRecord => 'Vaciar este registro';

  @override
  String get transportNothingYetThisProcess => 'Nada aún en este proceso';

  @override
  String transportM2(Object mins) {
    return '${mins}m';
  }

  @override
  String transportHM2(Object mins, Object mins2) {
    return '${mins}h ${mins2}m';
  }

  @override
  String transportTo(Object t, Object t2) {
    return '$t a $t2';
  }

  @override
  String vouchersVouchedBy(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Avalado por $countString',
      one: 'Avalado por',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperAtmosphere => 'Atmósfera';

  @override
  String get wallpaperJustForYouThey =>
      'Solo para ti. La otra persona ve la suya.';

  @override
  String get wallpaperYourPhoto => 'Tu foto';

  @override
  String get wallpaperFromYourPhotos => 'De tus fotos';

  @override
  String get wallpaperKeepIt => 'Conservar';

  @override
  String get whyKryfoWhyKryfo => 'Por qué Kryfo';

  @override
  String get whyKryfoKryfoKreeFoGreek =>
      'Kryfo · KRI-fo · «oculto» en griego.\nUn lugar tranquilo para hablar, hecho para que nadie esté mirando.';

  @override
  String get whyKryfoRoutedThroughTor => 'Enrutado por tor';

  @override
  String get whyKryfoByDefaultEveryMessage =>
      'Por defecto, cada mensaje viaja por tor, una cadena de repetidores. Nadie, ni nosotros ni tu red, puede ver con quién hablas ni dónde estás.';

  @override
  String get whyKryfoEndToEndEncrypted => 'Cifrado de extremo a extremo';

  @override
  String get whyKryfoMessagesAreSealedWith =>
      'Los mensajes se sellan con claves que solo tienen tú y la persona con la que hablas. No podríamos leerlos aunque lo intentáramos.';

  @override
  String get whyKryfoNoServersHoldingYour => 'Ningún servidor guarda tu vida';

  @override
  String get whyKryfoNoAccountNoPhone =>
      'Sin cuenta, sin número de teléfono, sin un servidor central que guarde tus chats. Viven en este teléfono, cifrados en reposo.';

  @override
  String get whyKryfoNothingLeaks => 'Nada se filtra';

  @override
  String get whyKryfoNoReadReceiptsOr =>
      'No se entregan a nadie confirmaciones de lectura ni avisos de escritura, y no se sube ninguna lista de contactos. Los metadatos son lo que filtran la mayoría de las apps; Kryfo está hecho para no filtrarlos.';

  @override
  String get whyKryfoVerifyItIsReally =>
      'Verifica que de verdad es esa persona';

  @override
  String get whyKryfoCompareASafetyNumber =>
      'Compara un número de seguridad en persona o por un canal de confianza, para saber que nadie se está haciendo pasar por tu contacto.';

  @override
  String get whyKryfoTheHonestPart => 'La parte honesta';

  @override
  String get whyKryfoKryfoIsPreAlpha =>
      'Kryfo es prealfa y no ha sido auditado. La criptografía es real, pero ningún experto externo la ha revisado todavía, así que trátalo como un trabajo en curso, no como algo a lo que confiarle tu vida todavía.';

  @override
  String get cleanerLocation => 'Ubicación';

  @override
  String get cleanerAlreadyBlankedByAndroid => 'ya vaciada por Android';

  @override
  String get cleanerPhoneModel => 'Modelo del teléfono';

  @override
  String get cleanerTimeTaken => 'Fecha y hora';

  @override
  String get cleanerSerialNumber => 'Número de serie';

  @override
  String get cleanerOwnerName => 'Propietario';

  @override
  String get cleanerHiddenThumbnail => 'Miniatura oculta';

  @override
  String get cleanerContentCredentials => 'Credenciales de contenido';

  @override
  String get cleanerDataAfterThePicture => 'Datos tras la imagen';

  @override
  String cleaner1OtherField(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString campos más',
      one: '$countString campo más',
    );
    return '$_temp0';
  }

  @override
  String get lockWordsFourRandomWordsBeat =>
      'Cuatro palabras al azar valen más que una ingeniosa.';

  @override
  String lockWordsTooShortAtLeast(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Demasiado corta. Al menos $countString caracteres.',
      one: 'Demasiado corta. Al menos $countString carácter.',
    );
    return '$_temp0';
  }

  @override
  String get lockWordsWeakWhoeverGetsThe =>
      'Débil. Quien consiga el archivo puede probar contraseñas tan rápido como quiera.';

  @override
  String get lockWordsFairLongerIsStronger =>
      'Aceptable. Cuanto más larga, más fuerte.';

  @override
  String get lockWordsStrongFourRandomWords =>
      'Fuerte. Cuatro palabras al azar valen más que una ingeniosa.';

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
      other: '$countString metros',
      one: '$countString metro',
    );
    return '$_temp0';
  }

  @override
  String get photoStoryFarFromAnyTown => 'Lejos de cualquier pueblo';

  @override
  String photoStoryNear(Object where) {
    return 'Cerca de $where';
  }

  @override
  String photoStoryAboutKmFrom(Object near, Object where) {
    return 'A unos $near km de $where';
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
  String get photoStoryNotAKindKryfo => 'Un tipo que Kryfo no sabe leer.';

  @override
  String get photoStorySoItWillNot => 'Así que no va a adivinar.';

  @override
  String get photoStoryThisFileIsDamaged =>
      'Este archivo está dañado o incompleto.';

  @override
  String get photoStoryKryfoCouldNotRead =>
      'Kryfo no pudo leerlo hasta el final.';

  @override
  String get photoStoryWhereItWasRecorded => 'Dónde se grabó';

  @override
  String get photoStoryWhereItWasTaken => 'Dónde se tomó';

  @override
  String photoStoryLocation(Object coordsLine) {
    return 'Ubicación: $coordsLine';
  }

  @override
  String photoStoryHeightAboveTheSea(Object fix) {
    return 'Altura sobre el nivel del mar: $fix m';
  }

  @override
  String get photoStoryLocationHiddenByAndroid =>
      'Ubicación ocultada por Android';

  @override
  String get photoStoryAndroidBlanksItWhen =>
      'Android la vacía cuando se elige una foto de esta forma. Si la compartes con Kryfo desde tu galería, a menudo se conserva. La de tu galería puede que aún la tenga.';

  @override
  String get photoStoryLocationBlankedByAndroid =>
      'Ubicación: Android la vació antes de que Kryfo la viera';

  @override
  String photoStoryF(Object r) {
    return 'f/$r';
  }

  @override
  String get photoStoryWhatTookIt => 'Con qué se tomó';

  @override
  String photoStoryPhoneOrCamera(Object phone) {
    return 'Teléfono o cámara: $phone';
  }

  @override
  String get photoStoryWhenItWasRecorded => 'Cuándo se grabó';

  @override
  String get photoStoryToTheSecondWith => 'Al segundo, con la zona horaria';

  @override
  String get photoStoryToTheSecond => 'Al segundo';

  @override
  String photoStoryTime(Object dateFormat) {
    return 'Hora: $dateFormat';
  }

  @override
  String get photoStoryLens => 'Objetivo';

  @override
  String photoStoryLens2(Object lens) {
    return 'Objetivo: $lens';
  }

  @override
  String get photoStorySoftware => 'Software';

  @override
  String photoStorySoftware2(Object software) {
    return 'Software: $software';
  }

  @override
  String get photoStorySerialNumber => 'Número de serie';

  @override
  String photoStorySerialNumber2(Object serial) {
    return 'Número de serie: $serial';
  }

  @override
  String get photoStoryOwnerName => 'Propietario';

  @override
  String photoStoryOwner(Object r) {
    return 'Propietario: $r';
  }

  @override
  String get photoStoryHiddenThumbnail => 'Miniatura oculta';

  @override
  String get photoStoryASmallCopyOf =>
      'Una copia pequeña de la imagen dentro del archivo. Puede mostrar lo que quitó un recorte';

  @override
  String get photoStoryMakerNotes => 'Notas del fabricante';

  @override
  String get photoStoryMakerNotesABlock =>
      'Notas del fabricante: un bloque que solo el fabricante puede leer';

  @override
  String get photoStoryEditingHistory => 'Historial de edición';

  @override
  String get photoStoryXmpEditingHistoryAnd =>
      'XMP: historial de edición y etiquetas';

  @override
  String get photoStoryCaptions => 'Pies de foto';

  @override
  String get photoStoryIptcCaptionsAndCredits =>
      'IPTC: pies de foto y créditos';

  @override
  String get photoStoryComment => 'Comentario';

  @override
  String get photoStoryAWrittenComment => 'Un comentario escrito';

  @override
  String get photoStoryContentCredentials => 'Credenciales de contenido';

  @override
  String get photoStorySecondPicture => 'Segunda imagen';

  @override
  String get photoStoryASecondPictureInside =>
      'Una segunda imagen dentro del archivo';

  @override
  String get photoStoryMotionVideo => 'Video integrado';

  @override
  String get photoStoryAShortVideoInside => 'Un video corto dentro del archivo';

  @override
  String get photoStorySaveTime => 'Hora de guardado';

  @override
  String get photoStoryTheTimeItWas => 'La última vez que se guardó';

  @override
  String get photoStoryTimeStamps => 'Marcas de tiempo';

  @override
  String get photoStoryCreationTimeStamps => 'Marcas de tiempo de creación';

  @override
  String get photoStoryDataAfterThePicture => 'Datos tras la imagen';

  @override
  String photoStoryDataAfterTheEnd(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Datos tras el final de la imagen: $countString bytes',
      one: 'Datos tras el final de la imagen: $countString byte',
    );
    return '$_temp0';
  }

  @override
  String photoStoryTextField(Object k) {
    return 'Campo de texto: $k';
  }

  @override
  String photoStoryVideoTag(Object k) {
    return 'Etiqueta de video: $k';
  }

  @override
  String photoStoryAlso(Object k) {
    return 'Además: $k';
  }

  @override
  String photoStoryCameraSettingsFlashFocus(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString ajustes de cámara (flash, enfoque, exposición)',
      one: '$countString ajuste de cámara (flash, enfoque, exposición)',
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
      other: '$countString campos más',
      one: '$countString campo más',
    );
    return '$_temp0';
  }

  @override
  String get photoStoryCameraSettings => 'Ajustes de cámara';

  @override
  String photoStoryAccurateToAbout(Object metres) {
    return 'Precisión de unos $metres.';
  }

  @override
  String get photoStoryEnoughToFindThe =>
      'Suficiente para encontrar la puerta.';

  @override
  String get photoStoryEnoughToFindTheStreet =>
      'Suficiente para encontrar la calle.';

  @override
  String get photoStoryEnoughToFindTheArea =>
      'Suficiente para encontrar la zona.';

  @override
  String get photoStoryItKnowsWhereYou => 'Sabe dónde estabas.';

  @override
  String get photoStoryDownToTheBuilding => 'Hasta el edificio.';

  @override
  String get photoStoryAndroidHidTheLocation => 'Android ocultó la ubicación.';

  @override
  String get photoStoryTheOriginalMayStill =>
      'Puede que el original aún la lleve.';

  @override
  String get photoStoryNoLocationInThis => 'Esta no tiene ubicación.';

  @override
  String get photoStoryItStillSaysPlenty => 'Aun así dice mucho.';

  @override
  String get photoStoryThisOneKnowsNothing => 'Esta no sabe nada.';

  @override
  String get photoStoryNothingToRemove => 'Nada que quitar.';

  @override
  String get qrPayloadOpensALink => 'ABRE UN ENLACE';

  @override
  String qrPayloadOpens(Object host) {
    return 'ABRE $host';
  }

  @override
  String get qrPayloadShowsANote => 'MUESTRA UNA NOTA';

  @override
  String get qrPayloadScanToJoin => 'ESCANEA PARA UNIRTE';

  @override
  String qrPayloadScanToJoin2(Object oneLine) {
    return 'ESCANEA PARA UNIRTE · $oneLine';
  }

  @override
  String get qrPayloadANetworkNameIs =>
      'Un nombre de red tiene 32 caracteres como máximo.';

  @override
  String get qrPayloadAWiFiPassword =>
      'Una contraseña de Wi-Fi tiene al menos 8 caracteres.';

  @override
  String get qrPayloadSavesAContact => 'GUARDA UN CONTACTO';

  @override
  String get qrPayloadWritesAnEmail => 'ESCRIBE UN CORREO';

  @override
  String get qrPayloadThatDoesNotLook =>
      'Eso no parece una dirección de correo.';

  @override
  String get qrPayloadCallsANumber => 'LLAMA A UN NÚMERO';

  @override
  String get qrPayloadWritesAText => 'ESCRIBE UN SMS';

  @override
  String get qrPayloadOpensAMap => 'ABRE UN MAPA';

  @override
  String get qrPayloadLatitudeRunsFrom90 =>
      'La latitud va de -90 a 90, y la longitud de -180 a 180.';

  @override
  String get qrPayloadPayThisAddress => 'PAGA A ESTA DIRECCIÓN';

  @override
  String get qrPayloadABitcoinAddressIs =>
      'Una dirección de bitcoin solo tiene letras y dígitos.';

  @override
  String get qrPayloadTheAmountIsIn =>
      'La cantidad va en BTC, con hasta 8 decimales.';

  @override
  String vouchTextAnd(Object names, Object names2) {
    return '$names y $names2';
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
      other: '$restString personas más que conoces',
      one: '$restString persona más que conoces',
    );
    return '$names, $names2 y $_temp0';
  }

  @override
  String vouchTextVouchedBy(Object vouchNames) {
    return 'Avalado por $vouchNames';
  }

  @override
  String vouchTextIntroducedBy(Object vouchNames) {
    return 'Presentado por $vouchNames';
  }

  @override
  String vouchTextThisSharesSAddress(Object a, Object b) {
    return 'Esto comparte la dirección de $a con $b';
  }

  @override
  String get bootFailedKryfoCouldNotStart => 'Kryfo no pudo iniciarse';

  @override
  String get bootFailedThisIsAFault =>
      'Es un fallo de este dispositivo, no de la red. Tor no tiene nada que ver.';

  @override
  String get kryfoLinkTextThatLinkIsNot => 'Kryfo no sabe leer ese enlace';

  @override
  String kryfoLinkTextAdd(Object who) {
    return '¿Añadir a $who?';
  }

  @override
  String kryfoLinkTextThisIsAnInvite(Object who) {
    return 'Es una invitación para hablar con $who. Añade a esta persona solo si sabes de dónde viene el enlace.';
  }

  @override
  String get kryfoLinkTextAddThem => 'Añadir';

  @override
  String get kryfoLinkTextNotNow => 'Ahora no';

  @override
  String kryfoLinkTextJoin(Object roomName) {
    return 'Unirse a $roomName';
  }

  @override
  String get kryfoLinkTextKryfoLink => 'Enlace de Kryfo';

  @override
  String kryfoLinkTextAdd2(Object who) {
    return 'Añadir a $who';
  }

  @override
  String get kryfoLinkTextBurnerRoom => 'SALA EFÍMERA';

  @override
  String get kryfoLinkTextThisRoomHasClosed => 'Esta sala se cerró';

  @override
  String kryfoLinkTextClosesIn(Object time) {
    return 'Se cierra en $time';
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
      other: 'Se cierra en $time · hasta $capString personas',
      one: 'Se cierra en $time · hasta $capString persona',
    );
    return '$_temp0';
  }

  @override
  String get kryfoLinkTextJoin2 => 'Unirse';

  @override
  String get kryfoLinkTextYouJoinUnderA =>
      'Entras con una clave creada para esta sala. Nadie dentro ve tu ID de Kryfo.';

  @override
  String get linkStubFetchedOverTorBy => 'Vía tor · lo obtuvo tu dispositivo';

  @override
  String get linkStubFetchedOverTorByTheirDevice =>
      'Vía tor · lo obtuvo su dispositivo';

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
  String get mediaBubblesFile => 'ARCHIVO';

  @override
  String get mediaBubblesAudioUnavailable => 'Audio no disponible';

  @override
  String get mediaBubblesHidden => 'Oculto';

  @override
  String get mediaBubblesMicPermissionNeeded =>
      'Se necesita permiso del micrófono';

  @override
  String get mediaBubblesReleaseToCancel => 'Suelta para cancelar';

  @override
  String get mediaBubblesVoiceHiddenSlideTo =>
      'Voz oculta · desliza para cancelar';

  @override
  String get mediaBubblesSlideToCancel => 'Desliza para cancelar';

  @override
  String get mediaBubblesSendPhoto => 'Enviar foto';

  @override
  String get mediaBubblesAddACaption => 'Añade un comentario…';

  @override
  String get motionStandby => 'EN ESPERA';

  @override
  String get motionConnecting => 'CONECTANDO';

  @override
  String get motionBuilding => 'CONSTRUYENDO';

  @override
  String get motionPublishing => 'PUBLICANDO';

  @override
  String get motionReady => 'LISTO';

  @override
  String get motionPreparingToConnect => 'Preparando la conexión';

  @override
  String get motionFindingAPrivatePath => 'Buscando un camino privado';

  @override
  String get motionCarvingThePath => 'Abriendo el camino';

  @override
  String get motionAnnouncingYourArrival => 'Anunciando tu llegada';

  @override
  String get motionYouReAnonymous => 'Estás en el anonimato';

  @override
  String get motionTorIsStartingIn =>
      'Tor se está iniciando en segundo plano. Este gráfico se ilumina a medida que se forma la conexión.';

  @override
  String get motionMakingAFreshRoute =>
      'Creando una ruta nueva a través de repetidores anónimos.';

  @override
  String get motionBouncingThroughRelaysSo =>
      'Saltando entre repetidores para que nadie pueda rastrearlo hasta ti.';

  @override
  String get motionTellingTheNetworkYou =>
      'Avisando a la red de que estás en línea — sin revelar dónde.';

  @override
  String get motionYourIpIsHidden =>
      'Tu IP está oculta. Solo quien tenga tu Kryfo puede contactarte.';

  @override
  String get motionBuilding2 => 'construyendo';

  @override
  String get motionOpen => 'abierto';

  @override
  String get motionLive => 'activo';

  @override
  String motionCircuit(Object circuit) {
    return 'Circuito · *$circuit*';
  }

  @override
  String get motionDelivered => 'Entregado';

  @override
  String get motionSent => 'Enviado';

  @override
  String get motion1Hop => '1 salto';

  @override
  String get motion3Hops => '3 saltos';

  @override
  String get movedStripThisKryfoHasMoved =>
      'Este Kryfo se mudó a otro dispositivo. Nada de lo que se envíe desde aquí le llega a nadie.';

  @override
  String get navBarChats => 'Chats';

  @override
  String get navBarTools => 'Herramientas';

  @override
  String get navBarSupport => 'Apoyar';

  @override
  String get navBarMe => 'Yo';

  @override
  String get pairCodePanelPuttingYourInviteIn => 'Preparando tu invitación';

  @override
  String get pairCodePanelYourInviteIsNot => 'Tu invitación aún no está lista';

  @override
  String get pairCodePanelReadSixDigitsOut =>
      'Lee seis dígitos en voz alta y podrá añadirte. No hace falta intercambiar nada más.';

  @override
  String get pairCodePanelWorking => 'Trabajando';

  @override
  String get pairCodePanelOrMakeASix =>
      'O crea un código de seis dígitos para leerlo en voz alta';

  @override
  String get pairCodePanelCodeCopied => 'Código copiado';

  @override
  String pairCodePanelBurnsIn(Object mm, Object ss) {
    return 'Desaparece en $mm:$ss';
  }

  @override
  String get pairCodePanelTheyTapAddChoose =>
      'La otra persona toca añadir, elige código y los escribe.';

  @override
  String get pairCodePanelTheyOpenKryfoTap =>
      'La otra persona abre Kryfo, toca añadir, elige código de emparejamiento y escribe estos seis dígitos. Crea uno nuevo para la siguiente persona.';

  @override
  String pinsPinnedMessages(Object count) {
    return 'Mensajes fijados · $count';
  }

  @override
  String get pinsPinnedMessages2 => 'Mensajes fijados';

  @override
  String get pinsPhoto => 'Foto';

  @override
  String get pinsVoiceMessage => 'Mensaje de voz';

  @override
  String get pinsMessage => 'Mensaje';

  @override
  String pinsToday(Object hm) {
    return 'Hoy · $hm';
  }

  @override
  String get pinsPinned => 'Fijado';

  @override
  String pinsOf(Object pinsLength, Object kMaxPins) {
    return '$pinsLength de $kMaxPins';
  }

  @override
  String get pinsNothingPinnedHereYet =>
      'Aún no hay nada fijado. Mantén presionado un mensaje y elige Fijar, y quedará aquí para todos en el chat.';

  @override
  String get pinsJump => 'Ir';

  @override
  String get pinsUnpin => 'Dejar de fijar';

  @override
  String powNoteFirstMessageToSomeone(int secs) {
    final intl.NumberFormat secsNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String secsString = secsNumberFormat.format(secs);

    return 'Primer mensaje a alguien nuevo · demostrando que es real · ${secsString}s';
  }

  @override
  String powNoteFirstMessageSlow(int secs) {
    final intl.NumberFormat secsNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String secsString = secsNumberFormat.format(secs);

    return 'Primer mensaje a alguien nuevo · demostrando que es real · ${secsString}s · hasta un minuto en un teléfono lento';
  }

  @override
  String previewStripFetchedOverTor(Object domainOf) {
    return '$domainOf · obtenido vía tor';
  }

  @override
  String get previewStripDropThePreview => 'Quitar la vista previa';

  @override
  String get previewStripAddPreview => 'Añadir vista previa';

  @override
  String get previewStripFetchingOverTor => 'Obteniendo vía tor…';

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
  String get torBootSplashNoShortcutsNoTraces => 'Sin atajos, sin rastros';

  @override
  String get torBootSplashTheNetworkThatKeeps =>
      'La red que protege tu privacidad se está preparando';

  @override
  String get torBootSplashMadeOnThisPhone =>
      'Hecho en este teléfono. No se envía nada a ningún sitio.';

  @override
  String get torBootSplashFirstLaunchTakesA =>
      'El primer arranque tarda un poco · solo al iniciar';

  @override
  String get videoBubbleNothingHereOpensThat =>
      'Nada aquí puede abrirlo · se comparte en su lugar';

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
  String get notificationsChannelName => 'Mensajes';

  @override
  String get cameraClose => 'Cerrar';

  @override
  String get cameraFlash => 'Flash';

  @override
  String get cameraPhoto => 'Foto';

  @override
  String get cameraVideo => 'Video';

  @override
  String get cameraRetake => 'Repetir';

  @override
  String get seenIntroductions => 'Presentaciones';

  @override
  String get donateAddress => 'Dirección';

  @override
  String get donateCopy => 'Copiar';

  @override
  String get donateDone => 'Listo';

  @override
  String get donateTierSupporter => 'Colaborador';

  @override
  String get donateTierPatron => 'Mecenas';

  @override
  String get donateTierGuardian => 'Guardián';

  @override
  String get chatBlock => 'Bloquear';

  @override
  String get chatDecline => 'Rechazar';

  @override
  String get chatAccept => 'Aceptar';

  @override
  String get bridgesConnecting => 'Conectando';

  @override
  String get bridgesSavedTag => 'Guardado';

  @override
  String get restoreMade => 'Creada';

  @override
  String get restoreContacts => 'Contactos';

  @override
  String get restoreMessages => 'Mensajes';

  @override
  String get restoreAttachments => 'Adjuntos';

  @override
  String get restoreHiddenChats => 'Chats ocultos';

  @override
  String get restoreHiddenFollow =>
      'Tus chats ocultos, con un nuevo PIN de chats ocultos que elegirás al final.';

  @override
  String get restoreChooseHiddenPin =>
      'Esta copia guarda chats ocultos. Elige un PIN de chats ocultos para ellos.';

  @override
  String get restoreHiddenLockFirst =>
      'Los chats ocultos necesitan el bloqueo de la app, así que primero Kryfo recibe un PIN propio.';

  @override
  String get shieldBlock => 'Bloquear';

  @override
  String get shieldDelete => 'Eliminar';

  @override
  String get shieldIgnore => 'Ignorar';

  @override
  String get profileIdentity => 'Identidad';

  @override
  String get avatarPickerShape => 'Forma';

  @override
  String get avatarPickerColour => 'Color';

  @override
  String get avatarPickerTurn => 'Girar';

  @override
  String get transportStatus => 'Estado';

  @override
  String get transportBootstrap => 'Arranque';

  @override
  String get transportNetwork => 'Red';

  @override
  String get transportConnectivity => 'Conectividad';

  @override
  String get transportRelays => 'Repetidores';

  @override
  String get transportTraffic => 'Tráfico';

  @override
  String get transportContacts => 'Contactos';

  @override
  String get transportKnown => 'Conocidos';

  @override
  String get transportListening => 'Escuchando';

  @override
  String get transportMemory => 'Memoria';

  @override
  String get settingsConnected => 'Conectado';

  @override
  String get settingsScreenshots => 'Capturas';

  @override
  String get settingsBlocked2 => 'Bloqueadas';

  @override
  String get settingsAllowed => 'Permitidas';

  @override
  String get settingsOn => 'Activado';

  @override
  String get settingsOff => 'Desactivado';

  @override
  String get settingsNotifications => 'Notificaciones';

  @override
  String get settingsPrivacy => 'Privacidad';

  @override
  String get settingsSecurity => 'Seguridad';

  @override
  String get settingsBackup => 'Copia de seguridad';

  @override
  String get settingsVoice => 'Voz';

  @override
  String get settingsAbout => 'Acerca de';

  @override
  String get wallpaperGradients => 'Degradados';

  @override
  String get wallpaperPatterns => 'Patrones';

  @override
  String get wallpaperMoods => 'Ambientes';

  @override
  String get confirmSheetKeep => 'Conservar';

  @override
  String get confirmSheetSave => 'Guardar';

  @override
  String get confirmSheetCancel => 'Cancelar';

  @override
  String bridgesSaved(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString puentes',
      one: '$countString puente',
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

    return 'Aceptadas: $goodString, no reconocidas: $badString';
  }

  @override
  String get languageTitle => 'Idioma';

  @override
  String get languageMatchPhone => 'Como el teléfono';

  @override
  String languageMatchPhoneValue(Object language) {
    return 'Como el teléfono ($language)';
  }

  @override
  String get languageRedrawLine =>
      'Kryfo se vuelve a dibujar en el nuevo idioma y se abre en tus chats.';

  @override
  String languageButton(Object language) {
    return 'Idioma: $language';
  }

  @override
  String get androidServiceTitle => 'Kryfo está activo';

  @override
  String get androidServiceText =>
      'Tu línea cifrada sigue abierta para que lleguen los mensajes';

  @override
  String get androidChannelName => 'Manteniendo la conexión';

  @override
  String get androidChannelDescription =>
      'Mantiene Kryfo conectado para que los mensajes cifrados lleguen mientras está cerrado. Desactivarlo detiene la entrega.';

  @override
  String get videoViewerPlay => 'Reproducir';

  @override
  String get videoViewerPause => 'Pausa';

  @override
  String get videoViewerPlayAgain => 'Volver a reproducir';

  @override
  String get videoViewerCannotPlay =>
      'Este teléfono no puede reproducir este video aquí.';

  @override
  String get videoViewerOpenElsewhere => 'Abrir en otra app';

  @override
  String get photoKnowsLookedFor => 'Buscamos';

  @override
  String get photoKnowsNotInIt => 'No está';

  @override
  String get languageNameEn => 'Inglés';

  @override
  String get languageNameDe => 'Alemán';

  @override
  String get languageNameFr => 'Francés';

  @override
  String get languageNameEs => 'Español';

  @override
  String get languageNamePt => 'Portugués (Brasil)';

  @override
  String get languageNameIt => 'Italiano';

  @override
  String get languageNameRu => 'Ruso';

  @override
  String get languageNameUk => 'Ucraniano';

  @override
  String get languageNameTr => 'Turco';

  @override
  String get languageNameZh => 'Chino (simplificado)';

  @override
  String get languageNameZhHant => 'Chino (tradicional)';

  @override
  String get languageNameVi => 'Vietnamita';

  @override
  String get languageNameId => 'Indonesio';

  @override
  String get languageNameFa => 'Persa';

  @override
  String get languageNameAr => 'Árabe';

  @override
  String get languageLaterLine => 'Puedes cambiarlo cuando quieras en ajustes.';

  @override
  String get pollAttach => 'Encuesta';

  @override
  String get pollNewTitle => 'Nueva encuesta';

  @override
  String get pollQuestionHint => 'Pregunta algo al grupo';

  @override
  String get pollOptionsLabel => 'Opciones';

  @override
  String pollOptionHint(Object n) {
    return 'Opción $n';
  }

  @override
  String get pollAddOption => 'Añadir una opción';

  @override
  String get pollMaxLine => 'Doce opciones como máximo.';

  @override
  String get pollMultiple => 'Varias respuestas';

  @override
  String get pollMultipleLine => 'Se puede elegir más de una.';

  @override
  String get pollSend => 'Enviar encuesta';

  @override
  String get pollKind => 'Encuesta';

  @override
  String get pollKindMulti => 'Encuesta · varias respuestas';

  @override
  String get pollKindClosed => 'Resultado final';

  @override
  String pollVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count votos',
      one: '$count voto',
      zero: 'Aún no hay votos',
    );
    return '$_temp0';
  }

  @override
  String get pollVote => 'Votar';

  @override
  String get pollTakeBack => 'Retirar mi voto';

  @override
  String get pollClose => 'Cerrar encuesta';

  @override
  String get pollCloseTitle => '¿Cerrar esta encuesta?';

  @override
  String get pollCloseLine =>
      'Todos verán el resultado final y nadie podrá votar después.';

  @override
  String get pollCloseYes => 'Cerrarla';

  @override
  String pollPreview(Object question) {
    return 'Encuesta: $question';
  }

  @override
  String get pollWhoVoted => 'Quién votó';

  @override
  String get pollNobody => 'Nadie todavía';

  @override
  String get pollYou => 'Tú';

  @override
  String pollOptionA11y(Object option, Object share) {
    return '$option, $share';
  }

  @override
  String get pollPickOne => 'Elige una';

  @override
  String get pollPickSeveral => 'Elige una o más';

  @override
  String get searchOpen => 'Buscar';

  @override
  String get searchHint => 'Buscar en chats y mensajes';

  @override
  String get searchFilterAll => 'Todo';

  @override
  String get searchFilterPhotos => 'Fotos';

  @override
  String get searchFilterVideos => 'Vídeos';

  @override
  String get searchFilterFiles => 'Archivos';

  @override
  String get searchFilterLinks => 'Enlaces';

  @override
  String get searchChats => 'Chats';

  @override
  String get searchMessages => 'Mensajes';

  @override
  String get searchIntroTitle => 'Busca en tus chats';

  @override
  String get searchIntroLine =>
      'Nombres, palabras, fotos, archivos y enlaces. La búsqueda ocurre en este teléfono y no envía nada a ningún sitio.';

  @override
  String get searchNothing => 'No se encontró nada';

  @override
  String get searchNothingLine => 'Prueba con otra palabra u otro filtro.';

  @override
  String searchMatches(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count resultados',
      one: '$count resultado',
    );
    return '$_temp0';
  }

  @override
  String searchMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count más',
      one: '$count más',
    );
    return '$_temp0';
  }

  @override
  String searchFilling(Object share) {
    return 'Añadiendo mensajes antiguos · $share';
  }

  @override
  String get searchClear => 'Borrar';

  @override
  String get handleShowInSearch => 'Mostrarme en la búsqueda';

  @override
  String get handleShowInSearchLine =>
      'Cualquiera puede encontrar este nombre de usuario y escribirte.';

  @override
  String handleShownAs(Object name) {
    return 'Se muestra como $name';
  }

  @override
  String get handleNameInSearch => 'Nombre en la búsqueda';

  @override
  String get handleNameInSearchLine =>
      'Opcional. Aparece junto a tu nombre de usuario cuando alguien busca. Cualquiera puede encontrar este nombre de usuario y escribirte.';

  @override
  String get handleNameHint => 'Tu nombre, o déjalo vacío';

  @override
  String get handleShowMe => 'Mostrarme';

  @override
  String get handleSearchOff => 'Ya no estás en la búsqueda';

  @override
  String handleSearchOn(Object handle) {
    return 'Estás en la búsqueda como @$handle';
  }

  @override
  String get handleRegistryFailed =>
      'No se pudo contactar con el registro. Inténtalo en un minuto.';

  @override
  String get searchPeople => 'Personas';

  @override
  String searchPeopleAsk(Object query) {
    return 'Buscar «$query» entre los nombres de usuario públicos';
  }

  @override
  String get searchPeopleLine =>
      'Se pregunta por Tor. El registro no guarda constancia.';

  @override
  String get searchPeopleNone => 'Ningún nombre de usuario público coincide';

  @override
  String get searchPeopleOffline => 'Tor aún no está listo';

  @override
  String get searchPeopleBusy =>
      'Demasiadas búsquedas ahora. Inténtalo en un momento.';

  @override
  String get searchPeopleUnreachable => 'No se pudo contactar con el registro';

  @override
  String get peopleVerified => 'Nombre de usuario verificado';

  @override
  String get peopleAdd => 'Añadir';

  @override
  String peopleFingerprint(Object fp) {
    return 'Huella de la clave · $fp';
  }

  @override
  String get peopleFingerprintLine =>
      'Comprueba que coincide con lo que ve la otra persona en su app.';

  @override
  String get peopleAdding => 'Añadiendo…';

  @override
  String handleNobodyHasClaimed(Object handle) {
    return 'Nadie ha reservado $handle';
  }

  @override
  String get handleThatHandleIsTaken => 'Ese nombre de usuario ya está en uso';

  @override
  String get pinPickDifferent => 'Elige otro PIN';

  @override
  String get settingsKeptOnWhileLock =>
      'Sigue activado mientras el bloqueo de la app esté activado.';

  @override
  String get lockFingerAfterPin =>
      'Escribe tu PIN una vez para volver a usar tu huella.';

  @override
  String get pinsAdvanced => 'Protección avanzada';

  @override
  String get pinsAdvancedLine =>
      'Para cuando alguien te obliga a desbloquear el teléfono.';

  @override
  String get pinsWipeLine =>
      'Escrito en la pantalla de bloqueo, borra Kryfo de este teléfono.';

  @override
  String get pinsDecoyPin => 'PIN señuelo';

  @override
  String get pinsDecoyLine => 'Abre un Kryfo vacío, como recién instalado.';

  @override
  String get pinsSetADecoyPin => 'Poner un PIN señuelo';

  @override
  String get pinsChangeDecoyPin => 'Cambiar PIN señuelo';

  @override
  String get pinsRemoveTheDecoyPin => '¿Quitar el PIN señuelo?';

  @override
  String get pinsTheDecoyGoes => 'El Kryfo vacío que abre desaparece con él.';

  @override
  String get pinsTurnOffWithDecoy =>
      'Todos los PIN desaparecen, y con ellos el señuelo, su Kryfo y cualquier chat oculto. Cualquiera que tenga tu teléfono abrirá Kryfo como si fuera tú.';

  @override
  String get pinsHowThisWorks => 'Cómo funciona';

  @override
  String get flowEnterYourPin => 'Escribe tu PIN';

  @override
  String get flowEnterYourPinLine => 'El que abre Kryfo.';

  @override
  String get flowWipeTitle => 'Un PIN de borrado';

  @override
  String get flowWipe1 =>
      'Escrito en la pantalla de bloqueo en lugar de tu PIN, borra Kryfo de este teléfono y lo cierra. Para quien esté mirando, la app simplemente se detuvo.';

  @override
  String get flowWipe2 =>
      'Se lleva cada chat y tu identidad, y el señuelo si lo tienes.';

  @override
  String get flowWipeChoose => 'Elige un PIN de borrado';

  @override
  String get flowWipeDone => 'PIN de borrado listo';

  @override
  String get flowWipeDoneLine =>
      'Nada en la pantalla de bloqueo muestra que existe.';

  @override
  String get flowDecoyTitle => 'Un PIN señuelo';

  @override
  String get flowDecoy1 => 'Abre un Kryfo vacío, como recién instalado.';

  @override
  String get flowDecoyFinger =>
      'Tu huella abre tu Kryfo real. Si alguien pudiera obligarte a usarla, desactiva la huella.';

  @override
  String get flowDecoyDigits =>
      'Usa el mismo número de dígitos que tu PIN, porque quien mire puede contar los puntos.';

  @override
  String get flowDecoyShade =>
      'Las notificaciones que ya están en el panel ya se vieron. Mientras el señuelo esté abierto, no aparece ninguna nueva.';

  @override
  String get flowDecoyChoose => 'Elige un PIN señuelo';

  @override
  String get flowDecoyDone => 'PIN señuelo listo';

  @override
  String get flowDecoyDoneLine =>
      'Escríbelo en la pantalla de bloqueo para abrir el Kryfo vacío. Para salir, cambia a otra app y escribe tu PIN.';

  @override
  String get flowLaw =>
      'En algunos países, negarse a desbloquear un teléfono u ocultar datos a las autoridades es un delito en sí mismo. Conoce la ley de los lugares a los que viajas.';

  @override
  String get howWipe =>
      'Escrito en la pantalla de bloqueo, el PIN de borrado borra cada chat, tu identidad y cualquier señuelo, y luego cierra Kryfo. Funciona incluso mientras el teclado está bloqueado tras intentos fallidos.';

  @override
  String get howDecoy =>
      'El PIN señuelo abre un segundo Kryfo, vacío, con sus propias tres palabras. Los mensajes a tu Kryfo real siguen llegando por debajo, en silencio. Para salir del señuelo, cambia a otra app y escribe tu PIN.';

  @override
  String get flowNotSet => 'No se pudo poner. Inténtalo de nuevo.';

  @override
  String get pinsHiddenChats => 'Chats ocultos';

  @override
  String get pinsHiddenLine =>
      'Los chats que elijas quedan fuera de la vista hasta que escribas tu PIN de chats ocultos: ni en la lista, ni en la búsqueda, sin notificaciones.';

  @override
  String get pinsSetUp => 'Configurar';

  @override
  String get pinsChangeHiddenPin => 'Cambiar PIN de chats ocultos';

  @override
  String get pinsHideMoreChats => 'Ocultar más chats';

  @override
  String get pinsRemoveHiddenChats => 'Quitar chats ocultos';

  @override
  String get pinsRemoveHiddenTitle => '¿Quitar los chats ocultos?';

  @override
  String get pinsRemoveHiddenLine =>
      'Vuelven a tu lista de chats, y el PIN de chats ocultos deja de abrir nada.';

  @override
  String get pinsTurnOffHiddenFirst =>
      'Los chats ocultos necesitan el bloqueo de la app. Quítalos primero y volverán a tu lista de chats.';

  @override
  String get flowVaultTitle => 'Chats ocultos';

  @override
  String get flowVault1 =>
      'Elige chats y grupos para ocultar. Tu PIN abre Kryfo sin ellos. Un PIN de chats ocultos lo abre todo, chats ocultos incluidos.';

  @override
  String get flowVault2 =>
      'Mientras están fuera de la vista, nunca avisan ni muestran un contador. Sus mensajes siguen llegando y esperan, sellados, a tu PIN de chats ocultos.';

  @override
  String get flowVaultFinger => 'Tu huella abre Kryfo sin los chats ocultos.';

  @override
  String get flowVaultDigits =>
      'Dale también a tu PIN seis dígitos o más, porque quien mire puede contar los puntos.';

  @override
  String get flowVaultReplace =>
      'Esto sustituye cualquier chat oculto que ya tenga este teléfono.';

  @override
  String get flowVaultChoose => 'Elige un PIN de chats ocultos';

  @override
  String get flowVaultChooseLine => 'Seis dígitos o más.';

  @override
  String get flowEnterHiddenPinLine => 'El que abre tus chats ocultos.';

  @override
  String get flowVaultForgetTitle => 'Recuerda este PIN';

  @override
  String get flowVaultForget =>
      'Si olvidas este PIN, tus chats ocultos se pierden para siempre. Nadie puede recuperarlos, ni siquiera nosotros.';

  @override
  String get flowVaultForgetOk => 'Entendido';

  @override
  String get flowVaultPickTitle => 'Elige chats para ocultar';

  @override
  String get flowVaultPickLine =>
      'Salen de tu lista de chats ahora. Tu PIN de chats ocultos los vuelve a mostrar.';

  @override
  String flowVaultPickButton(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ocultar $countString chats',
      one: 'Ocultar $countString chat',
      zero: 'No ocultar nada por ahora',
    );
    return '$_temp0';
  }

  @override
  String get flowVaultPickEmpty => 'Aún no hay chats para ocultar.';

  @override
  String get flowVaultBackupTitle => '¿Hacer una copia de seguridad ahora?';

  @override
  String get flowVaultBackupLine =>
      'Una copia hecha ahora también guarda tus chats ocultos, bajo su propia frase de contraseña. Si olvidas el PIN de chats ocultos, es la única forma de recuperarlos.';

  @override
  String get flowVaultBackupNow => 'Hacer una copia';

  @override
  String get flowVaultNotNow => 'Ahora no';

  @override
  String get flowVaultDone => 'Chats ocultos listos';

  @override
  String get flowVaultDoneLine =>
      'Escribe tu PIN de chats ocultos en la pantalla de bloqueo para verlos. Cambia a otra app y vuelven a quedar fuera de la vista.';

  @override
  String get flowVaultChanged => 'PIN de chats ocultos cambiado';

  @override
  String get flowVaultChangedLine =>
      'Tus chats ocultos se abren con el nuevo. El antiguo ya no abre nada.';

  @override
  String get howVault =>
      'Tu PIN de chats ocultos abre Kryfo con tus chats ocultos; tu PIN y tu huella, sin ellos. Configurar de nuevo los chats ocultos sustituye los que tiene este teléfono. Si olvidas el PIN de chats ocultos, se pierden para siempre.';

  @override
  String get chatHide => 'Ocultar chat';

  @override
  String get groupHide => 'Ocultar grupo';

  @override
  String get chatHidden => 'Oculto';

  @override
  String get chatHiddenToast => 'Ocultado de tu lista de chats';

  @override
  String get chatShowInList => 'Mostrar en la lista de chats';

  @override
  String get stickerOpen => 'Stickers';

  @override
  String get stickerRecent => 'Recientes';

  @override
  String stickerA11y(String emoji) {
    return 'Sticker $emoji';
  }

  @override
  String get stickerRemoveRecent => 'Quitar de recientes';

  @override
  String get stickerCouldNotLoad => 'No se pudieron cargar los stickers';

  @override
  String get stickerLabel => 'Sticker';

  @override
  String get stickerNewer => 'De un Kryfo más nuevo';

  @override
  String get devLinkMismatch =>
      'Este enlace dice ser Marios, pero su clave no coincide. No se ha añadido.';

  @override
  String get devName => 'Marios';

  @override
  String get devRowTitle => 'Marios · creó Kryfo';

  @override
  String get devWelcome =>
      'Hola, soy Marios, hago Kryfo. Cuéntame lo que sea: errores, ideas, preguntas. Lo leo todo.';

  @override
  String get devPinned => 'Integrado en Kryfo';

  @override
  String get devAnonymous => 'Anónimo';

  @override
  String get devAboutLine =>
      'La clave de Marios viene integrada en Kryfo. Cada mensaje de este chat se comprueba con ella, así que nadie más puede escribir como él.';

  @override
  String get devKeyLabel => 'Su clave';

  @override
  String get devDeleteLine =>
      'Se van todos los mensajes, y el chat no volverá.';

  @override
  String get devDeleteLineAnon =>
      'Se van todos los mensajes y el nombre creado para este chat, y el chat no volverá.';

  @override
  String get settingsWriteToMarios => 'Escribir a Marios';

  @override
  String get settingsWriteToMariosHint => 'Errores, ideas, preguntas';

  @override
  String get seenDevChat => 'El chat con Marios';

  @override
  String get seenDevChatCell => 'Si escribes';

  @override
  String get seenDevChatLine =>
      'Nada hasta que escribas. Después, lo que envías, y tus tres palabras, salvo que escribas de forma anónima.';
}
