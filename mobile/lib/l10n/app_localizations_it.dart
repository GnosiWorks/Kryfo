// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get atmosphereNone => 'Nessuna';

  @override
  String get atmosphereEmber => 'Brace';

  @override
  String get atmosphereDusk => 'Crepuscolo';

  @override
  String get atmosphereMoss => 'Muschio';

  @override
  String get atmosphereRose => 'Rosa';

  @override
  String get atmosphereDots => 'Punti';

  @override
  String get atmosphereGrid => 'Griglia';

  @override
  String get atmosphereWaves => 'Onde';

  @override
  String get atmosphereRain => 'Pioggia';

  @override
  String get atmosphereLateNight => 'Notte fonda';

  @override
  String get atmosphereWarmAfternoon => 'Pomeriggio caldo';

  @override
  String get atmosphereSnow => 'Neve';

  @override
  String get atmosphereDesert => 'Deserto';

  @override
  String get atmospherePaper => 'Carta';

  @override
  String get backupThatPassphraseDoesNot =>
      'Questa passphrase non apre il file';

  @override
  String get backupThatFileIsNot => 'Questo file non è un backup di Kryfo';

  @override
  String get backupThisBackupIsFrom =>
      'Questo backup viene da un Kryfo più recente. Aggiorna l\'app, poi riprova';

  @override
  String get backupThisFileIsDamaged =>
      'Questo file è danneggiato e non si può leggere';

  @override
  String get backupCouldNotMakeThe => 'Impossibile creare la chiave';

  @override
  String get contactCardMessageMeOn => 'Scrivimi su';

  @override
  String get contactCardScanItOrType =>
      'Scansionalo, o scrivi le tre parole in Kryfo.\nQuesto biglietto non sa nient\'altro di te.';

  @override
  String contactCardMessageMeOnKryfo(Object haloId) {
    return 'Scrivimi su Kryfo · $haloId';
  }

  @override
  String get contactStatusBlocked => 'Bloccato';

  @override
  String get contactStatusKeysVerifiedInPerson =>
      'Chiavi verificate di persona';

  @override
  String get contactStatusWaitingInRequests => 'In attesa tra le richieste';

  @override
  String get contactStatusAddedByHand => 'Aggiunto a mano';

  @override
  String get deliveryModeAlwaysOn => 'Sempre attivo';

  @override
  String get deliveryModeCheckIns => 'Controlli';

  @override
  String get deliveryModeThroughAHelperApp => 'Tramite un\'app di supporto';

  @override
  String get deliveryModeNotYet => 'non ancora';

  @override
  String get deliveryModeJustNow => 'adesso';

  @override
  String deliveryModeMinAgo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString min fa',
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
      other: '$countString ore fa',
      one: '$countString ora fa',
    );
    return '$_temp0';
  }

  @override
  String get deliveryModeYesterday => 'ieri';

  @override
  String deliveryModeDaysAgo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString giorni fa',
      one: '$countString giorno fa',
    );
    return '$_temp0';
  }

  @override
  String get deliveryModeConnected => 'Connesso';

  @override
  String get deliveryModeConnecting => 'In connessione';

  @override
  String get deliveryModeNotConnected => 'Non connesso';

  @override
  String get deliveryModeCheckingNow => 'Controllo in corso';

  @override
  String deliveryModeLastCheckIn(Object agoLine) {
    return 'ultimo controllo $agoLine';
  }

  @override
  String get deliveryModeNoCheckInYet => 'ancora nessun controllo';

  @override
  String deliveryModeConnectedNow(Object last) {
    return 'Connesso ora · $last';
  }

  @override
  String deliveryModeConnecting2(Object last) {
    return 'In connessione · $last';
  }

  @override
  String get deliveryModeNoCheckInYet2 => 'Ancora nessun controllo';

  @override
  String deliveryModeLastChecked(Object agoLine) {
    return 'Ultimo controllo $agoLine';
  }

  @override
  String get deliveryModeAHelperApp => 'un\'app di supporto';

  @override
  String deliveryModeWokenByNoWake(Object who) {
    return 'Svegliato da $who · ancora nessun risveglio';
  }

  @override
  String deliveryModeWokenByLastWake(Object who, Object agoLine) {
    return 'Svegliato da $who · ultimo risveglio $agoLine';
  }

  @override
  String get introBudgetTomorrow => 'domani';

  @override
  String introBudgetInDays(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'tra $countString giorni',
      one: 'tra $countString giorno',
    );
    return '$_temp0';
  }

  @override
  String get introBudgetInAnHour => 'tra un\'ora';

  @override
  String introBudgetInHours(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'tra $countString ore',
      one: 'tra $countString ora',
    );
    return '$_temp0';
  }

  @override
  String get introBudgetInAFewMinutes => 'tra qualche minuto';

  @override
  String get lockStateUnlockKryfo => 'Sblocca Kryfo';

  @override
  String get appInvalidUri => 'Uri non valido';

  @override
  String appBundleError(Object e) {
    return 'Errore del bundle: $e';
  }

  @override
  String appAlreadySaved(Object parsed) {
    return 'Già salvato: $parsed';
  }

  @override
  String appAddedYouCanMessage(Object parsed) {
    return 'Hai aggiunto $parsed · ora potete scrivervi';
  }

  @override
  String appPeerImportedV1(Object parsed) {
    return 'Peer importato (v1): $parsed';
  }

  @override
  String appLongWindow(Object line) {
    return '$line finestra lunga';
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
      other: '$pString pagine',
      one: '$pString pagina',
    );
    String _temp1 = intl.Intl.pluralLogic(
      e,
      locale: localeName,
      other: '$eString eventi',
      one: '$eString evento',
    );
    return '$line ($heldString di $subsString, connessione $c s, $_temp0, $_temp1)';
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
      other: '$pString pagine',
      one: '$pString pagina',
    );
    String _temp1 = intl.Intl.pluralLogic(
      e,
      locale: localeName,
      other: '$eString eventi',
      one: '$eString evento',
    );
    return '$line (connessione $c s, $_temp0, $_temp1)';
  }

  @override
  String appSDropped(Object host, Object secs) {
    return '$host $secs s interrotto';
  }

  @override
  String appS(Object host, Object secs) {
    return '$host $secs s';
  }

  @override
  String get appTorWouldNotWake => 'Tor non si è svegliato';

  @override
  String get appCheckStarted => 'Avviato';

  @override
  String get appTorNotReadyIn => 'Tor non pronto in 75 s';

  @override
  String get appOk => 'OK';

  @override
  String get appOkNoRelayBegan => 'OK, nessun relay ha risposto';

  @override
  String get appOkCapped => 'OK, troncato';

  @override
  String appSBy(Object how, int secs, String why) {
    final intl.NumberFormat secsNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String secsString = secsNumberFormat.format(secs);

    String _temp0 = intl.Intl.selectLogic(why, {
      'push': '$how, $secsString s, tramite push',
      'other': '$how, $secsString s, tramite job',
    });
    return '$_temp0';
  }

  @override
  String get appAnAttachmentCouldNot =>
      'Impossibile salvare un allegato su questo telefono';

  @override
  String get appGroup2 => 'Gruppo';

  @override
  String get appVoiceMessage => 'Messaggio vocale';

  @override
  String get appPhoto => 'Foto';

  @override
  String get appNewRequest => 'Nuova richiesta';

  @override
  String get appSomeoneYouHaveNot =>
      'Ti ha scritto qualcuno che non hai aggiunto';

  @override
  String get appSettingUpYourKeys => 'Preparazione delle chiavi';

  @override
  String get appOpeningYourChats => 'Apertura delle chat';

  @override
  String get appStartingTor => 'Avvio di Tor';

  @override
  String get appTimedMessagesAreNot =>
      'I messaggi a tempo non spariscono. Riavvia Kryfo';

  @override
  String get appVoiceMessage2 => 'Messaggio vocale';

  @override
  String appYou(Object body) {
    return 'Tu: $body';
  }

  @override
  String get appThisRoomHasAlready => 'Questa stanza è già scaduta';

  @override
  String get appYouAreAlreadyIn => 'Sei già in questa stanza';

  @override
  String get appCouldNotMakeA => 'Impossibile creare una chiave per la stanza';

  @override
  String appJoinedButYourHello(Object linkName) {
    return 'Sei in $linkName, ma il tuo saluto è rimasto in sospeso';
  }

  @override
  String appJoined(Object linkName) {
    return 'Sei in $linkName';
  }

  @override
  String appJoinedButTheCreator(Object linkName) {
    return 'Sei in $linkName, ma chi l\'ha creata non è ancora raggiungibile';
  }

  @override
  String get appBooting => 'Avvio...';

  @override
  String get appSettingUpYourIdentity => 'Preparazione della tua identità...';

  @override
  String get appAddSomeone => 'Aggiungi qualcuno';

  @override
  String get appScanTheirCodeOr =>
      'Scansiona il suo codice, o incolla quello che ti ha dato: un link, un @nome utente o il link di una stanza.';

  @override
  String get appScanTheirCode => 'Scansiona il suo codice';

  @override
  String get appAKryfoLinkA => 'Un link Kryfo, il link di una stanza o @merlo';

  @override
  String get appAddThem => 'Aggiungi';

  @override
  String get appEveryWayToAdd => 'Tutti i modi per aggiungere qualcuno';

  @override
  String get appShowYourCodeSend =>
      'Mostra il tuo codice, invia un link, registra un nome utente';

  @override
  String get appHelloFromTheOther => 'Ciao dall\'altra parte';

  @override
  String get appIdentityRestored => 'Identità ripristinata';

  @override
  String get appIdentityCreated => 'Identità creata';

  @override
  String get appStartingTor30s => 'Avvio di tor (~30 s)...';

  @override
  String get appScanOrImportA => 'Prima scansiona o importa un peer';

  @override
  String get appEncryptingSending30s => 'Cifratura + invio (~30 s)...';

  @override
  String get appTapStartListeningFirst => 'Prima tocca Inizia ascolto';

  @override
  String get appYourKryfo => 'Il tuo Kryfo';

  @override
  String get appUriCopied => 'Uri copiato';

  @override
  String get appCopyUri => 'Copia uri';

  @override
  String get appAddAKryfo => 'Aggiungi un Kryfo';

  @override
  String get appScanQr => 'Scansiona qr';

  @override
  String get appPairingCode => 'Codice di abbinamento';

  @override
  String get appOrPaste => '- O incolla -';

  @override
  String get commonCancel => 'Annulla';

  @override
  String get appImport => 'Importa';

  @override
  String get appDev => 'Dev';

  @override
  String get appYourKryfo2 => 'Il tuo Kryfo:';

  @override
  String get appRestoredFromDisk => 'Ripristinato dal disco';

  @override
  String get appStartListening => 'Inizia ascolto';

  @override
  String get appListening => 'In ascolto';

  @override
  String get appShowMyQr => 'Mostra il mio qr';

  @override
  String get appImportPeer => 'Importa peer';

  @override
  String get appPeer => 'Peer:';

  @override
  String get appMessageWillBeEncrypted => 'Messaggio (verrà cifrato)';

  @override
  String get appEncryptSend => 'Cifra + invia';

  @override
  String appStatus(Object status) {
    return 'Stato: $status';
  }

  @override
  String get appSpeedPrivacy => 'Velocità e privacy →';

  @override
  String get appGettingMessages => 'Ricezione messaggi →';

  @override
  String get appDisableAppLock => 'Disattivare il blocco app?';

  @override
  String get appThePinWillBe =>
      'Il PIN verrà rimosso. Chiunque abbia il tuo telefono vedrà Kryfo quando lo apre.';

  @override
  String get appDisable => 'Disattiva';

  @override
  String get appAppLockOn => 'Blocco app · attivo →';

  @override
  String get appAppLockOff => 'Blocco app · disattivato →';

  @override
  String get appTorIsOff => 'Tor è spento';

  @override
  String get appConnectedRoutedThrough3 =>
      'Connesso · instradato attraverso 3 relay';

  @override
  String get appReadyToSendPublishing =>
      'Pronto a inviare · pubblicazione del tuo indirizzo';

  @override
  String get appReadyToSendFinishing => 'Pronto a inviare · ultimi preparativi';

  @override
  String appConnecting(Object pct) {
    return 'Connessione · $pct';
  }

  @override
  String get appTor => 'Tor';

  @override
  String get appTorIsOffTurn =>
      'Tor è spento. Attivalo per connetterti in modo privato.';

  @override
  String get appTheFirstConnectionTakes =>
      'La prima connessione richiede un minuto o due, mentre tor costruisce un percorso privato. Poi resta in memoria, quindi aprire Kryfo in seguito è molto più rapido.';

  @override
  String get appRelayAndFastModes =>
      'Le modalità relay e veloce saltano tor e sono più rapide. Le trovi nelle impostazioni, in velocità e privacy, e ognuna dice cosa ti costa.';

  @override
  String get appViaRelay => 'Tramite relay';

  @override
  String get appOffline => 'Offline';

  @override
  String get appFast => 'Veloce';

  @override
  String get appTorOff => 'Tor spento';

  @override
  String get appTorReady => 'Tor pronto';

  @override
  String get appConnecting2 => 'In connessione';

  @override
  String mediaProgressSendingKeepTheApp(Object v) {
    return 'Invio · $v · tieni l\'app aperta';
  }

  @override
  String mediaProgressPausedOfWaitingFor(Object count, Object count2) {
    return 'In pausa · $count di $count2 · in attesa del resto';
  }

  @override
  String mediaProgressReceivingMedia(Object v) {
    return 'Ricezione media · $v';
  }

  @override
  String get mediaProgressCancelSending => 'Annulla invio';

  @override
  String get metaReaderEndsBeforeItShould => 'finisce prima del dovuto';

  @override
  String get metaReaderCouldNotBeRead => 'illeggibile';

  @override
  String get metaReaderExifThatCannotBe => 'exif illeggibile';

  @override
  String get metaReaderSamsungTrailer => 'coda samsung';

  @override
  String metaReaderChunk(Object type) {
    return 'blocco $type';
  }

  @override
  String get metaReaderExifFlagSet => 'flag exif attivo';

  @override
  String get metaReaderXmpFlagSet => 'flag xmp attivo';

  @override
  String metaReaderAppBlock(Object id) {
    return 'segmento app $id';
  }

  @override
  String get metaReaderUuidBox => 'box uuid';

  @override
  String metaReaderBox(Object printable) {
    return 'box $printable';
  }

  @override
  String get metaReaderAttachedData => 'dati allegati';

  @override
  String metaReaderItem(Object printable) {
    return 'elemento $printable';
  }

  @override
  String get miuiAutostartAlreadyAllowedToRun =>
      'Può già funzionare in background';

  @override
  String get miuiAutostartLetKryfoRunIn =>
      'Lascia che Kryfo funzioni in background';

  @override
  String get miuiAutostartYourPhonePausesApps =>
      'Il telefono mette in pausa le app per risparmiare batteria. Senza un\'eccezione, Kryfo non può ricevere messaggi mentre è chiuso.';

  @override
  String get commonAllow => 'Consenti';

  @override
  String get commonSkip => 'Salta';

  @override
  String get miuiAutostartXiaomiTurnsOffBackground =>
      'Xiaomi spegne le app in background per impostazione predefinita. Senza l\'avvio automatico, Kryfo non può consegnare messaggi quando l\'app è chiusa. Nella prossima schermata trova Kryfo nell\'elenco e attiva l\'interruttore.';

  @override
  String get miuiAutostartOpenSettings => 'Apri impostazioni';

  @override
  String get miuiAutostartCouldnTOpenIt =>
      'Non si è aperto. Cerca «avvio automatico» nelle impostazioni del telefono';

  @override
  String get notificationsNewEncryptedMessagesFrom =>
      'Nuovi messaggi cifrati dai tuoi contatti';

  @override
  String get notificationsNewMessage => 'Nuovo messaggio';

  @override
  String get notificationsNewEncryptedMessagesFromYourContacts =>
      'Nuovi messaggi cifrati dai tuoi contatti';

  @override
  String get notificationsNewMessage2 => 'Nuovo messaggio';

  @override
  String get notificationsEncrypted => 'Cifrato';

  @override
  String get rooms24h => '24 h';

  @override
  String roomsD(Object inDays) {
    return '$inDays g';
  }

  @override
  String roomsH(Object inHours) {
    return '$inHours h';
  }

  @override
  String get rooms24Hours => '24 ore';

  @override
  String roomsDays(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString giorni',
      one: '$countString giorno',
    );
    return '$_temp0';
  }

  @override
  String get roomsAnHour => 'un\'ora';

  @override
  String get roomsAboutAnHour => 'circa un\'ora';

  @override
  String roomsHours(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString ore',
      one: '$countString ora',
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
      other: 'circa $countString ore',
      one: 'circa $countString ora',
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
      other: '$countString minuti',
      one: '$countString minuto',
    );
    return '$_temp0';
  }

  @override
  String get roomsAMinute => 'un minuto';

  @override
  String get roomsExpired => 'Scaduta';

  @override
  String roomsDH(Object inDays, Object h) {
    return '$inDays g $h h';
  }

  @override
  String roomsHM(Object inHours, Object m) {
    return '$inHours h $m min';
  }

  @override
  String roomsM(Object inMinutes) {
    return '$inMinutes min';
  }

  @override
  String get scamShieldLooksLikeAScam => 'Sembra una truffa';

  @override
  String scamShieldThisNameMatches(Object shown) {
    return 'Questo nome coincide con $shown';
  }

  @override
  String scamShieldNameMatchesYourContact(Object shown) {
    return 'Il nome coincide con il tuo contatto $shown';
  }

  @override
  String scamShieldSameFaceAsYour(Object shown) {
    return 'Stesso volto del tuo contatto $shown';
  }

  @override
  String get scamShieldContainsACryptoAddress => 'Contiene un indirizzo crypto';

  @override
  String get scamShieldMentionsMoneyAndUrgency =>
      'Parla di soldi e di urgenza insieme';

  @override
  String get scamShieldAsksYouToMove => 'Ti chiede di passare a un\'altra app';

  @override
  String get scamShieldLinksToALookalike =>
      'Rimanda a un sito che imita uno famoso';

  @override
  String get scamShieldALongOpenerFrom =>
      'Un lungo primo messaggio da qualcuno senza storico';

  @override
  String get scamShieldAsksForACode =>
      'Chiede un codice, una seed phrase o un file di recupero';

  @override
  String scamShieldAlso(Object shown) {
    return 'Inoltre: il nome coincide con il tuo contatto $shown';
  }

  @override
  String get commonBack => 'Indietro';

  @override
  String get archivedArchived => 'Archiviate';

  @override
  String get archivedCount0 => 'Nessuna';

  @override
  String get archivedCount1 => 'Una';

  @override
  String get archivedCount2 => 'Due';

  @override
  String get archivedCount3 => 'Tre';

  @override
  String get archivedCount4 => 'Quattro';

  @override
  String get archivedCount5 => 'Cinque';

  @override
  String get archivedCount6 => 'Sei';

  @override
  String get archivedCount7 => 'Sette';

  @override
  String get archivedCount8 => 'Otto';

  @override
  String get archivedCount9 => 'Nove';

  @override
  String get archivedCount10 => 'Dieci';

  @override
  String get archivedChatRestingHereIt =>
      'Chat a riposo qui. Resta in silenzio finché non ti scrivono, poi torna in cima.';

  @override
  String get archivedChatsRestingHere =>
      'Chat a riposo qui. Restano in silenzio finché qualcuno non scrive, poi tornano in cima.';

  @override
  String get archivedNothingArchived => 'Niente in archivio';

  @override
  String get archivedArchivedChatsAreStill =>
      'Le chat archiviate restano cifrate end-to-end';

  @override
  String get archivedUnarchive => 'Estrai';

  @override
  String get avatarPickerThePeopleYouMessage =>
      'Lo vedono anche le persone a cui scrivi';

  @override
  String get avatarPickerBackToYourInitial => 'Torna alla tua iniziale';

  @override
  String get avatarPickerThatOneIsYours => 'Quello è il tuo';

  @override
  String get avatarPickerPickAFace => 'Scegli un volto';

  @override
  String get commonSave => 'Salva';

  @override
  String get backupPassphraseMustBeAt =>
      'La passphrase deve avere almeno 6 caratteri';

  @override
  String get backupPassphrasesDonTMatch => 'Le passphrase non coincidono';

  @override
  String get backupBackupSavedKeepThe =>
      'Backup salvato · custodisci la passphrase';

  @override
  String get backupKryfoBackup => 'Backup di Kryfo';

  @override
  String get backupYourEncryptedKryfoBackup =>
      'Il tuo backup cifrato di Kryfo. Conserva al sicuro questo file E la tua passphrase - per ripristinare servono entrambi.';

  @override
  String get backupBackUpKryfo => 'Backup di Kryfo';

  @override
  String get backupBackUp => 'Fai il backup';

  @override
  String get backupACopyToKeep =>
      'Una copia da conservare. Questo telefono continua come prima.';

  @override
  String get backupMoveToAnotherDevice => 'Passa a un altro dispositivo';

  @override
  String get backupTheFileTakesThis =>
      'Il file porta con sé questa identità. Appena è creato, questo telefono si ferma: qui non arriva più niente, e niente di ciò che viene inviato da qui arriva a nessuno.';

  @override
  String get backupOneEncryptedFileYour =>
      'Un solo file cifrato: la tua identità, i tuoi contatti, ogni messaggio e ogni foto, nota vocale e file. Importalo sull\'altro dispositivo con la passphrase. Fino ad allora puoi ancora cambiare idea e restare su questo telefono.';

  @override
  String get backupOneEncryptedFileYourIdentityYour =>
      'Un solo file cifrato: la tua identità, i tuoi contatti, ogni messaggio e ogni foto, nota vocale e file presenti ora su questo telefono. Quello che viene detto dopo oggi non c\'è, quindi fanne un altro quando conta. Per ripristinare ti servono il file e la passphrase, entrambi.';

  @override
  String get backupPassphrase => 'Passphrase';

  @override
  String get backupConfirmPassphrase => 'Conferma passphrase';

  @override
  String backupWriting(Object progress) {
    return 'Scrittura… $progress';
  }

  @override
  String get backupCreating => 'Creazione…';

  @override
  String get backupMakeTheFileAnd => 'Crea il file e trasferisci';

  @override
  String get backupCreateBackup => 'Crea backup';

  @override
  String get backupHiddenNotIn => 'Le chat nascoste non ci sono.';

  @override
  String get backupHiddenIncluded => 'Ci sono anche le tue chat nascoste.';

  @override
  String get backupMoveHiddenStay =>
      'Le chat nascoste restano su questo telefono e vengono cancellate insieme a lui.';

  @override
  String get backupHiddenGone =>
      'Le tue chat nascoste si sono chiuse quando Kryfo si è bloccato. Aprile con il loro PIN e fai il backup da lì.';

  @override
  String get blockedBlocked => 'Bloccati';

  @override
  String get blockedNoOneIsBlocked => 'Nessuno è bloccato';

  @override
  String get commonUnblock => 'Sblocca';

  @override
  String get bridgesThatWasNotIt => 'Non era quello. Eccone un altro.';

  @override
  String get bridgesGotBridgesSaveTo => 'Bridge ricevuti · salva per usarli';

  @override
  String get bridgesConnected => 'Connesso';

  @override
  String get bridgesNotThroughYetTor =>
      'Non ancora collegato. Tor continua a provare';

  @override
  String get bridgesBridges => 'Bridge';

  @override
  String get bridgesTorIsBlockedWhere => 'Tor è bloccato dove ti trovi?';

  @override
  String get bridgesBridgesDisguiseYourConnection =>
      'I bridge camuffano la tua connessione così può uscire. Scegli una via d\'accesso, salva, e tor si riconnette attraverso quella.';

  @override
  String get bridgesBridgesOnlyChangeHow =>
      'I bridge cambiano solo il modo in cui tor si connette, e ora non sei in modalità onion. Quello che imposti qui viene salvato, solo che non ha effetto finché non torni alla modalità onion.';

  @override
  String get bridgesFromTheTorProject => 'Dal progetto tor';

  @override
  String get bridgesNoise => 'Rumore';

  @override
  String get bridgesGood => 'Buona';

  @override
  String get bridgesMakesTorTrafficLook =>
      'Fa sembrare il traffico tor nulla di particolare. La scelta migliore per la maggior parte delle reti bloccate. Rispondi a un captcha, poi ti dà qualche riga.';

  @override
  String get bridgesPrivateBridge => 'Bridge privato';

  @override
  String get bridgesALineFromA => 'Una riga da un amico';

  @override
  String get bridgesWhateverTheLineSays => 'Quello che dice la riga';

  @override
  String get bridgesDepends => 'Dipende';

  @override
  String get bridgesGotABridgeLine =>
      'Hai una riga bridge da qualcuno di cui ti fidi, o da bridges.torproject.org? Incollala qui. Solo righe obfs4: Kryfo non parla ancora gli altri tipi.';

  @override
  String get bridgesPasteFromClipboard => 'Incolla dagli appunti';

  @override
  String get bridgesUseBridges => 'Usa i bridge';

  @override
  String get bridgesNoLinesYet => 'Ancora nessuna riga';

  @override
  String bridges1LineSaved(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString righe salvate',
      one: '$countString riga salvata',
    );
    return '$_temp0';
  }

  @override
  String get bridgesRestartingTor => 'Riavvio di tor…';

  @override
  String bridgesFindingABridgeS(Object elapsed) {
    return 'Cerco un bridge… $elapsed s';
  }

  @override
  String bridgesStillTryingS(Object elapsed) {
    return 'Ci provo ancora… $elapsed s';
  }

  @override
  String get bridgesApplying => 'Applico…';

  @override
  String get bridgesSaveAndReconnect => 'Salva e riconnetti';

  @override
  String get bridgesWhatABridgeIs => 'Cos\'è un bridge';

  @override
  String get bridgesATorEntryPoint =>
      'Un punto d\'ingresso a tor che nessuno ha pubblicato, raggiunto attraverso un involucro perché la connessione non sembri tor. Il resto del percorso sono i soliti tre salti.';

  @override
  String get bridgesLooksLike => 'Sembra';

  @override
  String get bridgesSpeed => 'Velocità';

  @override
  String get bridgesGetBridges => 'Ottieni bridge';

  @override
  String get bridgesAskTheTorProject =>
      'Chiedili direttamente al progetto tor. Risolvi un rompicapo, così i bot non possono esaurire la scorta.';

  @override
  String get bridgesTypeWhatYouSee =>
      'Scrivi quello che vedi. Vanno bene le minuscole.';

  @override
  String get bridgesThisOneRequestDoes =>
      'Questa sola richiesta non passa per tor - non può, visto che è proprio tor a non funzionare. Chi gestisce la tua rete vedrà che contatti il progetto tor. Se già questo è un problema dove ti trovi, procurati i bridge altrove e incollali qui sotto.';

  @override
  String get bridgesCouldNotDrawThe => 'Impossibile disegnare il rompicapo';

  @override
  String get bridgesAnswer => 'Risposta';

  @override
  String get bridgesAsking => 'Richiesta…';

  @override
  String get bridgesRequestBridges => 'Richiedi bridge';

  @override
  String get bridgesDifferentPuzzle => 'Altro rompicapo';

  @override
  String get cameraNoCameraOnThis => 'Questo telefono non ha fotocamera';

  @override
  String get cameraCameraNotAvailable => 'Fotocamera non disponibile';

  @override
  String get cameraCameraPermissionIsOff =>
      'Permesso fotocamera disattivato · tocca per riprovare';

  @override
  String get cameraCouldNotStripThat =>
      'Impossibile ripulire la foto, scartata';

  @override
  String get cameraNoPhotoCameOut => 'Non è uscita nessuna foto';

  @override
  String get cameraCouldNotStartRecording =>
      'Impossibile avviare la registrazione';

  @override
  String get cameraTheRecordingWasLost => 'La registrazione è andata persa';

  @override
  String get cameraACopyIsIn => 'Una copia è nelle tue foto';

  @override
  String get cameraCouldNotSaveA =>
      'Impossibile salvare una copia su questo telefono';

  @override
  String get cameraTooLongForA => 'Troppo lungo per un messaggio · max 8 mb';

  @override
  String get cameraNeverSavedToYour => 'Non finisce mai nelle tue foto';

  @override
  String get cameraNoExifNeverSaved =>
      'Niente exif, non finisce mai nelle tue foto';

  @override
  String get cameraRec => 'Rec';

  @override
  String get cameraSwitchCamera => 'Cambia fotocamera';

  @override
  String cameraClipSMb(Object secs, Object mb) {
    return 'Clip · $secs s · $mb mb';
  }

  @override
  String get cameraStopRecording => 'Ferma registrazione';

  @override
  String get cameraStartRecording => 'Avvia registrazione';

  @override
  String get cameraTakeAPhoto => 'Scatta una foto';

  @override
  String get cameraKeepACopy => 'Tieni una copia';

  @override
  String get cameraUseThis => 'Usa questa';

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
      'Sei offline · parte da solo quando ti riconnetti';

  @override
  String get chatStillConnectingToTor =>
      'Connessione a Tor in corso · partirà da solo';

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
    return '$seconds h';
  }

  @override
  String chatD(Object seconds) {
    return '$seconds g';
  }

  @override
  String get chat0s => '0 s';

  @override
  String chatHM(Object h, Object m) {
    return '$h h $m min';
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
  String get chatNewMessages => 'Nuovi messaggi';

  @override
  String get chatUnsave => 'Togli dai salvati';

  @override
  String get chatForward => 'Inoltra';

  @override
  String get commonShare => 'Condividi';

  @override
  String get commonCopied => 'Copiato';

  @override
  String get commonCopy => 'Copia';

  @override
  String get chatUnpin => 'Sfissa';

  @override
  String get chatPin => 'Fissa';

  @override
  String get chatStopSending => 'Interrompi invio';

  @override
  String get chatUnsend => 'Ritira';

  @override
  String get commonEdit => 'Modifica';

  @override
  String get chatYou => 'Tu';

  @override
  String get chatUnsendMessage => 'Ritira messaggio';

  @override
  String get chatItDisappearsWithNo =>
      'Sparisce senza lasciare traccia. Non si può annullare.';

  @override
  String chatThisChatHasPins(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Questa chat ha già $countString messaggi fissati',
      one: 'Questa chat ha già $countString messaggio fissato',
    );
    return '$_temp0';
  }

  @override
  String get chatUnpinThisMessage => 'Sfissare questo messaggio?';

  @override
  String get chatPinThisMessage => 'Fissare questo messaggio?';

  @override
  String get chatItLeavesThePinned =>
      'Esce dall\'elenco dei fissati per entrambi.';

  @override
  String get chatItGoesUnderThe =>
      'Va tra i fissati in cima alla chat, per entrambi.';

  @override
  String get chatPinIt => 'Fissalo';

  @override
  String get chatNotNow => 'Non ora';

  @override
  String get chatEditMessage => 'Modifica messaggio';

  @override
  String get chat30Seconds => '30 secondi';

  @override
  String get chat1Minute => '1 minuto';

  @override
  String get chat5Minutes => '5 minuti';

  @override
  String get chat1Hour => '1 ora';

  @override
  String get chat24Hours => '24 ore';

  @override
  String get chatGhostTimer => 'Messaggi a tempo';

  @override
  String get chatHowLongBeforeSent =>
      'Dopo quanto spariscono i messaggi inviati?';

  @override
  String get chatCamera => 'Fotocamera';

  @override
  String get chatNoExifNeverSaved =>
      'Niente exif, non finisce mai nelle tue foto';

  @override
  String get chatGallery => 'Galleria';

  @override
  String get chatVideo => 'Video';

  @override
  String get chatGifFromPhone => 'Gif dal telefono';

  @override
  String get chatFile2 => 'File';

  @override
  String get chatAFewSeconds => 'Pochi secondi';

  @override
  String get chatUnderAMinute => 'Meno di un minuto';

  @override
  String chatRoughlyMin(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Circa $countString min',
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
  String get chatSendThis => 'Inviare questo file?';

  @override
  String chatOverTor(Object humanBytes, Object wireEstimate) {
    return '$humanBytes · $wireEstimate via tor';
  }

  @override
  String get chatBigFilesGoOut =>
      'I file grandi partono in piccoli pezzi cifrati, quindi ci vuole un po\'. Tieni l\'app aperta e l\'invio va avanti.';

  @override
  String get chatSendIt => 'Invia';

  @override
  String get chatCouldNotReadThat => 'Impossibile leggere il file';

  @override
  String get chatFileTooBig8 => 'File troppo grande · max 8 mb';

  @override
  String get chatCouldNotCleanThat => 'Impossibile ripulire il video';

  @override
  String get chatCouldNotCleanThatPictureSend =>
      'Impossibile ripulire l\'immagine · inviala come foto';

  @override
  String get chatGifTooBig8 => 'Gif troppo grande · max 8 mb';

  @override
  String get chatCouldNotCleanThatGif => 'Impossibile ripulire la gif';

  @override
  String get chatTorIsNotUp =>
      'Tor non è ancora pronto · invio senza anteprima';

  @override
  String get chatCouldnTReachIt =>
      'Sito irraggiungibile · invio senza anteprima';

  @override
  String get chatNoTitleCameBack =>
      'Nessun titolo ricevuto · invio senza anteprima';

  @override
  String get chatCouldnTFetchIt =>
      'Impossibile scaricarla · invio senza anteprima';

  @override
  String get chatNoSignalSessionRe =>
      'Nessuna sessione signal - abbina di nuovo';

  @override
  String get chatMessageUnavailable => 'Messaggio non disponibile';

  @override
  String get chatYou2 => 'Tu';

  @override
  String get chatThem => 'Contatto';

  @override
  String get chatVoiceMessage => 'Messaggio vocale';

  @override
  String get chatQuotedPhoto => 'Foto';

  @override
  String get chatViewContact => 'Vedi contatto';

  @override
  String get chatSharedPhotos => 'Foto condivise';

  @override
  String chatSharedPhotoCount(int count, Object title) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString foto',
      one: '$countString foto',
    );
    return '$_temp0 · $title';
  }

  @override
  String get chatUnmuteNotifications => 'Riattiva notifiche';

  @override
  String get chatMuteNotifications => 'Silenzia notifiche';

  @override
  String get chatArchiveChat => 'Archivia chat';

  @override
  String get chatWallpaper => 'Sfondo';

  @override
  String get chatClearConversation => 'Svuota conversazione';

  @override
  String get chatNoteOnThisContact => 'Nota su questo contatto';

  @override
  String get chatPinToTop => 'Fissa in alto';

  @override
  String get chatBlockContact => 'Blocca contatto';

  @override
  String get chatUnpinned => 'Sfissata';

  @override
  String get chatPinnedToTop => 'Fissata in alto';

  @override
  String get chatJustForYouNever =>
      'Solo per te. Mai inviata, non lascia mai questo telefono.';

  @override
  String get chatAQuietReminder => 'Un promemoria discreto…';

  @override
  String get chatNoteSaved => 'Nota salvata';

  @override
  String get chatClearThisConversation => 'Svuotare questa conversazione?';

  @override
  String get chatEveryMessageHereIs =>
      'Ogni messaggio qui viene cancellato da questo telefono. Svuota solo la tua copia - non tocca il dispositivo dell\'altra persona.';

  @override
  String get chatClear => 'Svuota';

  @override
  String get chatBlockThisContact => 'Bloccare questo contatto?';

  @override
  String get chatTheirMessagesStopArriving =>
      'I suoi messaggi non arrivano più e il contatto sparisce dalle tue chat. Non viene mai avvisato. Puoi sbloccare quando vuoi dalle impostazioni.';

  @override
  String get commonBlock => 'Blocca';

  @override
  String get chatSaved => 'Salvato';

  @override
  String get chatRemovedFromSaved => 'Tolto dai salvati';

  @override
  String get chatForwardTo => 'Inoltra a';

  @override
  String get chatNoContactsToForward => 'Nessun contatto a cui inoltrare';

  @override
  String get chatToday => 'Oggi';

  @override
  String get chatYesterday => 'Ieri';

  @override
  String get chatThisMessageCanT => 'Questo messaggio non si può mostrare';

  @override
  String get chatJumpToTheNewest => 'Vai ai più recenti';

  @override
  String get chatBuildingAPrivateRoute =>
      'Costruzione di un percorso privato · la prima connessione è quella lenta, le altre sono rapide. Quello che invii ora va in coda e parte da solo.';

  @override
  String get chatLooksSafeNothingSuspicious =>
      'Sembra sicuro · niente di sospetto nel primo messaggio';

  @override
  String get chatTheNextPhotoYou =>
      'La prossima foto che invii si apre protetta · non se ne può fare uno screenshot';

  @override
  String get chatPhotoProtectionOff => 'Protezione foto disattivata';

  @override
  String get chatAcceptToReplyThey =>
      'Accetta per rispondere - finché non lo fai, può mandarti solo un altro messaggio.';

  @override
  String chatIntroducedYouAcceptTo(Object introducer) {
    return '$introducer vi ha presentati. Accetta per rispondere.';
  }

  @override
  String chatIntroducedYouSayHello(Object vouchNames) {
    return 'Presentati da $vouchNames. Saluta - anche l\'altra persona ha ricevuto il tuo biglietto.';
  }

  @override
  String get chatIntroduceTo => 'Presenta a...';

  @override
  String get chatAcceptThemFirst => 'Prima accetta la richiesta';

  @override
  String get chatMessageRequest => 'Richiesta di messaggio';

  @override
  String get chatTheyNeedToAccept =>
      'Deve accettare prima che possiate continuare a scrivervi.';

  @override
  String get chatWaitingForThemTo => 'In attesa che accetti la tua richiesta';

  @override
  String get chatYouBlockedThisContact => 'Hai bloccato questo contatto';

  @override
  String get chatSupporter => 'Sostenitore';

  @override
  String get chatEncryptedViaRelay => 'Cifrato · tramite relay';

  @override
  String get chatEncryptedDirect => 'Cifrato · diretto';

  @override
  String get chatEncryptedOverTor => 'Cifrato · via tor';

  @override
  String get chatSearchThisChat => 'Cerca in questa chat';

  @override
  String get chatContactOptions => 'Opzioni contatto';

  @override
  String get commonClose => 'Chiudi';

  @override
  String get chatFindInConversation => 'Trova nella conversazione';

  @override
  String get chatNoMatches => 'Nessun risultato';

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
      other: '*$posString* di $countString risultati',
      one: '*$posString* di $countString risultato',
    );
    return '$_temp0';
  }

  @override
  String get chatPreviousMatch => 'Risultato precedente';

  @override
  String get chatNextMatch => 'Risultato successivo';

  @override
  String get chatPhotoUnavailable => 'Foto non disponibile';

  @override
  String get chatDelivered => 'Consegnato';

  @override
  String get chatEdited => 'Modificato';

  @override
  String get chatWaitingForThemToComeOnline =>
      'In attesa che si connetta o ti aggiunga a sua volta';

  @override
  String get chatFailedTapToRetry => 'Non inviato · tocca per riprovare';

  @override
  String get chatReplyingTo => 'In risposta al contatto';

  @override
  String get chatReplyingToYourself => 'In risposta a te';

  @override
  String get chatReply => 'Rispondi';

  @override
  String get chatSayHi => 'Saluta.';

  @override
  String get chatJustTheTwoOf => 'Solo voi due, cifrato end-to-end.';

  @override
  String get chatMicPermissionNeeded => 'Serve il permesso del microfono';

  @override
  String get chatTheMicWouldNot => 'Il microfono non è partito. Riprova';

  @override
  String get chatReleaseToCancel => 'Rilascia per annullare';

  @override
  String get chatVoiceHiddenSlideTo => 'Voce nascosta · scorri per annullare';

  @override
  String get chatSlideToCancel => 'Scorri per annullare';

  @override
  String get chatGhostMode => 'Messaggi a tempo';

  @override
  String chatMessagesBurnAfter(Object humanBurn) {
    return 'spariscono dopo $humanBurn';
  }

  @override
  String get chatTimedMessages => 'Messaggi a tempo';

  @override
  String get chatOpenTheCamera => 'Apri la fotocamera';

  @override
  String get chatAttachAPhoto => 'Allega una foto';

  @override
  String get chatMessage => 'Messaggio';

  @override
  String get chatDisguiseVoice => 'Camuffa la voce';

  @override
  String get commonSend => 'Invia';

  @override
  String get chatNoPhotosInThis => 'Ancora nessuna foto in questa chat';

  @override
  String get chatSendPhoto => 'Invia foto';

  @override
  String get chatAddACaption => 'Aggiungi didascalia…';

  @override
  String get chatSecurityCodeChanged => 'Codice di sicurezza cambiato';

  @override
  String chatMayHaveReinstalledOr(Object peerName) {
    return '$peerName potrebbe aver reinstallato l\'app, oppure qualcuno potrebbe spacciarsi per questa persona. Confronta i numeri di sicurezza per averne la certezza.';
  }

  @override
  String get chatOk => 'Ok';

  @override
  String get chatVerify => 'Verifica';

  @override
  String get cleanKryfoCanTClean =>
      'Kryfo non può ancora ripulire questo tipo di file.';

  @override
  String get cleanThisIsAMotion => 'Questa è una foto in movimento.';

  @override
  String get cleanThisPictureIsToo =>
      'Questa immagine è troppo grande per ripulirla qui.';

  @override
  String get cleanThisFileIsDamaged =>
      'Questo file è danneggiato o incompleto.';

  @override
  String get cleanKryfoCouldNotMake =>
      'Kryfo non è riuscito a ripulire questo file.';

  @override
  String get cleanNotEnoughRoomOn => 'Non c\'è abbastanza spazio sul telefono.';

  @override
  String get cleanKryfoCouldNotOpen =>
      'Kryfo non è riuscito ad aprire il file.';

  @override
  String get cleanItCleansJpegPng =>
      'Ripulisce JPEG, PNG, WebP, HEIC, AVIF, GIF, MP4 e MOV. Non è stato modificato niente.';

  @override
  String get cleanItHoldsAShort =>
      'Contiene un breve video accanto all\'immagine, e Kryfo non può ancora ripulire quella parte. Disattiva il movimento nella fotocamera, oppure inviane uno screenshot.';

  @override
  String get cleanPicturesOver64Mb =>
      'Le immagini oltre 64 MB non vengono ripulite sul telefono. Non è stato modificato niente.';

  @override
  String get cleanKryfoCouldNotRead =>
      'Kryfo non è riuscito a leggerlo fino in fondo, quindi non lo dichiara pulito. Non è stata fatta nessuna copia.';

  @override
  String get cleanSomethingInsideIsOf =>
      'Dentro c\'è qualcosa di un tipo che non sa rimuovere, quindi non è stata fatta nessuna copia.';

  @override
  String get cleanFreeSomeSpaceAnd =>
      'Libera un po\' di spazio e riprova. Non è stato modificato niente.';

  @override
  String get cleanTheAppThatShared =>
      'L\'app che l\'ha condiviso potrebbe averlo ripreso. Prova a condividerlo di nuovo.';

  @override
  String get cleanNoAppOnThis =>
      'Nessuna app su questo telefono ha preso il file.';

  @override
  String get cleanCouldNotSaveIt =>
      'Impossibile salvarlo. Controlla che il telefono abbia spazio.';

  @override
  String get cleanTheOriginalIsGone =>
      'L\'originale non c\'è più. La copia pulita resta.';

  @override
  String get cleanAndroidWouldNotDelete =>
      'Android non l\'ha eliminato. Rimuovilo dalla galleria a mano.';

  @override
  String get cleanCleanCopy => 'Copia pulita';

  @override
  String get cleanShareCleanCopy => 'Condividi copia pulita';

  @override
  String get cleanSaveToGallery => 'Salva in galleria';

  @override
  String get commonStop => 'Interrompi';

  @override
  String get cleanReadingTheFile => 'Lettura del file';

  @override
  String get cleanCleaning => 'Pulizia';

  @override
  String cleanOf(Object prettySize, Object prettySize2) {
    return '$prettySize di $prettySize2';
  }

  @override
  String get cleanEverythingStaysOnThis => 'Tutto resta su questo telefono.';

  @override
  String get cleanAlreadyClean => 'Già pulito.';

  @override
  String get cleanClean => 'Pulito.';

  @override
  String get cleanThereWasNothingTo => 'Non c\'era niente da trovare.';

  @override
  String get cleanNothingLeftToFind => 'Non è rimasto niente da trovare.';

  @override
  String get cleanSameVideoSameQuality => 'Stesso video, stessa qualità';

  @override
  String get cleanSamePictureSameQuality => 'Stessa immagine, stessa qualità';

  @override
  String cleanRemoved(Object label) {
    return '$label, non c\'è più';
  }

  @override
  String get cleanRemoved2 => 'RIMOSSO';

  @override
  String get cleanWithTheLocationInside =>
      'con dentro la posizione. Chiunque lo riceva conosce la tua via.';

  @override
  String get cleanWithEverythingItKnew =>
      'con dentro ancora tutto ciò che sapeva.';

  @override
  String get cleanOriginal => 'ORIGINALE';

  @override
  String get cleanClean2 => 'PULITO';

  @override
  String get cleanSavedToYourGallery => 'Salvato nella tua galleria.';

  @override
  String cleanTheOriginalIsStill(Object what) {
    return 'Anche l\'originale è ancora lì, $what';
  }

  @override
  String cleanTheOriginalIsStillWhereIt(Object what) {
    return 'L\'originale è ancora dov\'era, $what Kryfo non può rimuoverlo da qui, quindi eliminalo nell\'app da cui proviene.';
  }

  @override
  String get cleanDeleteTheOriginal => 'Elimina l\'originale';

  @override
  String get cleanKeepBoth => 'Tieni entrambi';

  @override
  String get commonDone => 'Fatto';

  @override
  String get cleanAndroidWillAskYou => 'ANDROID TI CHIEDERÀ DI CONFERMARE';

  @override
  String get contactYourNameForThem => 'Soprannome del contatto';

  @override
  String get contactStaysOnThisPhone =>
      'Resta su questo telefono. Il contatto non lo vede mai.';

  @override
  String get contactClear => 'Rimuovi';

  @override
  String get contactMessage => 'Scrivi';

  @override
  String get contactKeysVerified => 'Chiavi verificate';

  @override
  String get contactVerifyKeys => 'Verifica chiavi';

  @override
  String get contactVouches => 'Referenze';

  @override
  String get contactUnmute => 'Riattiva';

  @override
  String get contactMute => 'Silenzia';

  @override
  String get contactUnpin => 'Sfissa';

  @override
  String get contactPinToTop => 'Fissa in alto';

  @override
  String get contactArchive => 'Archivia';

  @override
  String get contactOutOfTheList => 'Fuori dall\'elenco finché non ti riscrive';

  @override
  String contactBlock(Object name) {
    return 'Bloccare $name?';
  }

  @override
  String get contactTheirMessagesStopArriving =>
      'I suoi messaggi non arrivano più. Non riceve nessun avviso.';

  @override
  String get contactDeleteChat => 'Elimina chat';

  @override
  String get contactMessagesAndContactGone =>
      'Messaggi e contatto, eliminati da questo telefono';

  @override
  String get contactDeleteThisChat => 'Eliminare questa chat?';

  @override
  String get contactEveryMessageAndThe =>
      'Ogni messaggio e il contatto, eliminati da questo telefono. Al contatto non viene inviato niente.';

  @override
  String get commonDelete => 'Elimina';

  @override
  String get contactDeleted => 'Eliminata';

  @override
  String get contactToday => 'Oggi';

  @override
  String contactD(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count giorni',
      one: '$count giorno',
    );
    return '$_temp0';
  }

  @override
  String contactMo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mesi',
      one: '$count mese',
    );
    return '$_temp0';
  }

  @override
  String contactY(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count anni',
      one: '$count anno',
    );
    return '$_temp0';
  }

  @override
  String get contactVerified => 'Verificato';

  @override
  String get contactChatting => 'In chat da';

  @override
  String get contactNothingSharedYet => 'Ancora niente di condiviso';

  @override
  String contactSharedMedia(Object count) {
    return 'Media condivisi · $count';
  }

  @override
  String get donateBitcoin => 'Bitcoin';

  @override
  String get donateText => '₿';

  @override
  String get donateBadgeUnlocks => 'Sblocca il badge';

  @override
  String get donateMonero => 'Monero';

  @override
  String get donateManualNoBadge => 'Manuale · niente badge';

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
          'Il tuo precedente pagamento in bitcoin è stato rilevato · badge sostenitore sbloccato',
      'patron':
          'Il tuo precedente pagamento in bitcoin è stato rilevato · badge mecenate sbloccato',
      'guardian':
          'Il tuo precedente pagamento in bitcoin è stato rilevato · badge custode sbloccato',
      'other':
          'Il tuo precedente pagamento in bitcoin è stato rilevato · badge sostenitore sbloccato',
    });
    return '$_temp0';
  }

  @override
  String get donateSupport => 'Sostieni';

  @override
  String get donateKeepKryfo => 'Mantieni Kryfo *indipendente*';

  @override
  String get donateNoAdsNoInvestors =>
      'Niente pubblicità, niente investitori, niente da vendere. Va avanti con quello che danno i sostenitori.';

  @override
  String get donateBackItAnonymouslyBadge =>
      'Sostienilo in modo anonimo. Badge solo se vuoi.\n*La privacy non è mai a pagamento.*';

  @override
  String donateAddressCheckItAgainst(Object coinName) {
    return 'Indirizzo $coinName · confrontalo con il tuo wallet';
  }

  @override
  String get donateAddressCopiedClearsIn =>
      'Indirizzo copiato · rimosso tra 60 s';

  @override
  String get donateCopyAddress => 'Copia indirizzo';

  @override
  String get donateBitcoinIsVerifiedBy =>
      'I bitcoin vengono verificati dal nostro nodo, quindi il badge si sblocca da solo appena arriva il pagamento.';

  @override
  String get donateWeCanTVerify =>
      'Non possiamo verificare questa blockchain senza chiedere di te a un servizio esterno, quindi non lo facciamo. Invia pure se vuoi. Non sblocca nessun badge.';

  @override
  String get donateBitcoinBadgesNeedOnion =>
      'I badge bitcoin richiedono la modalità onion';

  @override
  String get donateSwitchToOnion => 'Passa a onion';

  @override
  String get donatePayWithBitcoin => 'Paga in bitcoin  →';

  @override
  String get donateBadgesStartAt20 => 'Badge a partire da \$20';

  @override
  String get donateReachingThePaymentService =>
      'Contatto il servizio di pagamento via tor…';

  @override
  String get donateThisCanTakeUp => 'Può richiedere fino a un minuto';

  @override
  String donateSThisCanTake(Object waited) {
    return '$waited s · può richiedere fino a un minuto';
  }

  @override
  String get donateUseTheAddressInstead => 'Usa l\'indirizzo';

  @override
  String get donateThePaymentServiceIs =>
      'Il servizio di pagamento è un onion, e solo la modalità onion può raggiungerlo. Non è stato inviato niente.';

  @override
  String get donateTorWasSlowTo =>
      'Tor ci ha messo troppo a raggiungere il servizio di pagamento. Puoi donare all\'indirizzo qui sotto - solo che il badge non si sbloccherà in automatico. Riprova più tardi per il badge.';

  @override
  String get donateThePaymentServiceIsHavingTrouble =>
      'Il servizio di pagamento ha problemi in questo momento. Puoi comunque donare all\'indirizzo qui sotto - solo che il badge non si sbloccherà in automatico. Riprova più tardi per il badge.';

  @override
  String get commonTryAgain => 'Riprova';

  @override
  String donateBtc(Object btc) {
    return '$btc BTC';
  }

  @override
  String donateSendExactlyThisAmount(Object fmtLeft) {
    return 'Invia esattamente questo importo · scade tra $fmtLeft';
  }

  @override
  String get donateOpenWallet => 'Apri wallet';

  @override
  String get donateThisScreenUpdatesItself =>
      'Questa schermata si aggiorna appena il pagamento viene rilevato.\nTienila aperta - non si salva niente, niente ti identifica.';

  @override
  String get donateWatchingTheChainFor =>
      'Controllo la blockchain per il tuo pagamento';

  @override
  String get donateThisInvoiceExpired => 'Questa fattura è scaduta';

  @override
  String get donateInvoicesTimeOutIf =>
      'Le fatture scadono. Se hai già inviato il pagamento, tieni aperta questa schermata: chiediamo di nuovo al servizio ogni minuto per un po\', e la prossima volta che apri Sostieni. Creane una nuova quando vuoi.';

  @override
  String get donateNewInvoice => 'Nuova fattura';

  @override
  String get donateIPaidCheckAgain => 'Ho pagato, ricontrolla';

  @override
  String get donatePaymentConfirmed => 'Pagamento confermato';

  @override
  String get donateThankYouForKeeping =>
      'Grazie per mantenere Kryfo indipendente.';

  @override
  String donateVerifiedOnChainYou(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter':
          'Verificato on-chain - ora sei tra i sostenitori. Nessuno può togliertelo.',
      'patron':
          'Verificato on-chain - ora sei tra i mecenati. Nessuno può togliertelo.',
      'guardian':
          'Verificato on-chain - ora sei tra i custodi. Nessuno può togliertelo.',
      'other':
          'Verificato on-chain - ora sei tra i sostenitori. Nessuno può togliertelo.',
    });
    return '$_temp0';
  }

  @override
  String get donateWearMyBadge => 'Mostra il mio badge';

  @override
  String get donateJustGladToHelp => 'Felice di aiutare';

  @override
  String get gettingMessagesGettingMessages => 'Ricezione messaggi';

  @override
  String get gettingMessagesHowNewMessagesReach =>
      'Come arrivano i nuovi messaggi su questo telefono. Puoi cambiarlo quando vuoi.';

  @override
  String get gettingMessagesAlwaysOn => 'Sempre attivo';

  @override
  String get gettingMessagesMostPrivate => 'Il più privato';

  @override
  String get gettingMessagesMessagesArriveInstantlyNothing =>
      'I messaggi arrivano subito. Niente esce da Tor. Consuma più batteria di tutti.';

  @override
  String get gettingMessagesCheckIns => 'Controlli';

  @override
  String get gettingMessagesLightest => 'Il più leggero';

  @override
  String get gettingMessagesKryfoLooksForMessages =>
      'Kryfo cerca messaggi ogni 15 minuti. Leggero sulla batteria, ma i messaggi possono arrivare in ritardo.';

  @override
  String get gettingMessagesOnTheLockScreen => 'Sulla schermata di blocco';

  @override
  String get gettingMessagesHideMessagePreview => 'Nascondi anteprima';

  @override
  String get gettingMessagesAGenericAlertWith =>
      'Un avviso generico, senza mittente né testo';

  @override
  String get gettingMessagesShowsMessageTextIn =>
      'Mostra il testo dei messaggi nelle notifiche, anche mentre Kryfo è bloccato.';

  @override
  String get gettingMessagesWhenThePhoneSits =>
      'Quando il telefono resta fermo, Android distanzia di più i controlli. La riga sopra mostra l\'ultimo reale. Mentre Kryfo è aperto, resta connesso.';

  @override
  String get groupChatJumpToTheNewest => 'Vai ai più recenti';

  @override
  String get groupChatBlockedEverywhere => 'Bloccato ovunque';

  @override
  String get groupChatYou => 'Tu';

  @override
  String get groupChatVoiceMessage => 'Messaggio vocale';

  @override
  String get groupChatQuotedPhoto => 'Foto';

  @override
  String get groupChatMessageUnavailable => 'Messaggio non disponibile';

  @override
  String get groupChatTorIsNotUp =>
      'Tor non è ancora pronto · invio senza anteprima';

  @override
  String get groupChatCouldnTReachIt =>
      'Sito irraggiungibile · invio senza anteprima';

  @override
  String get groupChatNoTitleCameBack =>
      'Nessun titolo ricevuto · invio senza anteprima';

  @override
  String get groupChatCouldnTFetchIt =>
      'Impossibile scaricarla · invio senza anteprima';

  @override
  String get groupChatCamera => 'Fotocamera';

  @override
  String get groupChatGallery => 'Galleria';

  @override
  String get groupChatVideo => 'Video';

  @override
  String get groupChatGifFromPhone => 'Gif dal telefono';

  @override
  String get groupChatFile => 'File';

  @override
  String get groupChatCouldNotReadThat => 'Impossibile leggere il file';

  @override
  String get groupChatGifTooBig8 => 'Gif troppo grande · max 8 mb';

  @override
  String get groupChatCouldNotCleanThat => 'Impossibile ripulire la gif';

  @override
  String get groupChatFileTooBig8 => 'File troppo grande · max 8 mb';

  @override
  String get groupChatCouldNotCleanThatVideo => 'Impossibile ripulire il video';

  @override
  String get groupChatCouldNotCleanThatPictureSend =>
      'Impossibile ripulire l\'immagine · inviala come foto';

  @override
  String get groupChat30Seconds => '30 secondi';

  @override
  String get groupChat1Minute => '1 minuto';

  @override
  String get groupChat5Minutes => '5 minuti';

  @override
  String get groupChat1Hour => '1 ora';

  @override
  String get groupChat24Hours => '24 ore';

  @override
  String get groupChatBurnTimer => 'Messaggi a tempo';

  @override
  String get groupChatNewMessagesDisappearAfter =>
      'I nuovi messaggi spariscono dopo questo tempo';

  @override
  String get groupChatToday => 'Oggi';

  @override
  String get groupChatYesterday => 'Ieri';

  @override
  String get groupChatYou2 => 'Tu';

  @override
  String groupChatThisChatHasPins(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Questa chat ha già $countString messaggi fissati',
      one: 'Questa chat ha già $countString messaggio fissato',
    );
    return '$_temp0';
  }

  @override
  String get groupChatUnpinThisMessage => 'Sfissare questo messaggio?';

  @override
  String get groupChatPinThisMessage => 'Fissare questo messaggio?';

  @override
  String get groupChatItLeavesThePinned =>
      'Esce dall\'elenco dei fissati per tutti qui.';

  @override
  String get groupChatItGoesUnderThe =>
      'Va tra i fissati in cima alla chat, per tutti qui.';

  @override
  String get groupChatUnpin => 'Sfissa';

  @override
  String get groupChatPinIt => 'Fissalo';

  @override
  String get groupChatNotNow => 'Non ora';

  @override
  String get groupChatSaved => 'Salvato';

  @override
  String get groupChatRemovedFromSaved => 'Tolto dai salvati';

  @override
  String get groupChatForwardTo => 'Inoltra a';

  @override
  String get groupChatNoContactsToForward => 'Nessun contatto a cui inoltrare';

  @override
  String get groupChatEditMessage => 'Modifica messaggio';

  @override
  String get groupChatUnsendMessage => 'Ritira messaggio';

  @override
  String get groupChatItDisappearsWithNo =>
      'Sparisce senza lasciare traccia. Non si può annullare.';

  @override
  String get groupChatUnsend => 'Ritira';

  @override
  String groupChatThisRoomAndEverything(Object expiryWords) {
    return 'Questa stanza e tutto ciò che contiene spariscono tra $expiryWords';
  }

  @override
  String groupChatGhostModeOnBurns(Object fmtBurn) {
    return 'Messaggi a tempo · spariscono dopo $fmtBurn';
  }

  @override
  String get groupChatGroupCreatedSayHi => 'Gruppo creato. Saluta.';

  @override
  String get groupChatNoMessagesYet => 'Ancora nessun messaggio.';

  @override
  String get groupChatThisMessageCanT => 'Questo messaggio non si può mostrare';

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
    return '$s h';
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
      other: '$time · $countString presenti',
      one: '$time · $countString presente',
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
      other: '$countString membri',
      one: '$countString membro',
    );
    return '$_temp0';
  }

  @override
  String get groupChatSearchThisChat => 'Cerca in questa chat';

  @override
  String groupChatReplyingTo(Object name) {
    return 'In risposta a $name';
  }

  @override
  String get groupChatReplyingToYou => 'In risposta a te';

  @override
  String get groupChatTimedMessages => 'Messaggi a tempo';

  @override
  String get groupChatOpenTheCamera => 'Apri la fotocamera';

  @override
  String get groupChatAttachAPhoto => 'Allega una foto';

  @override
  String get groupChatMessage => 'Messaggio';

  @override
  String get groupChatDisguiseVoice => 'Camuffa la voce';

  @override
  String get groupChatSupporter => 'Sostenitore';

  @override
  String get groupChatEdited => 'Modificato';

  @override
  String get groupChatTapToRetry => '! Tocca per riprovare';

  @override
  String get groupChat0s => '0 s';

  @override
  String get groupChatReply => 'Rispondi';

  @override
  String get groupChatPin => 'Fissa';

  @override
  String get groupChatUnsave => 'Togli dai salvati';

  @override
  String get groupChatForward => 'Inoltra';

  @override
  String get groupInfoGroup => 'Gruppo';

  @override
  String get groupInfoRenameGroup => 'Rinomina gruppo';

  @override
  String get groupInfoRename => 'Rinomina';

  @override
  String get groupInfoNoContactsToAdd => 'Nessuno da aggiungere';

  @override
  String get groupInfoCouldNotAdd => 'Impossibile aggiungere';

  @override
  String groupInfoRemove(Object haloId) {
    return 'Rimuovere $haloId?';
  }

  @override
  String get groupInfoTheyWillStopReceiving =>
      'Non riceverà più messaggi da questo gruppo.';

  @override
  String get commonRemove => 'Rimuovi';

  @override
  String get groupInfoClearThisConversation => 'Svuotare questa conversazione?';

  @override
  String get groupInfoEveryMessageHereIs =>
      'Ogni messaggio qui viene cancellato da questo telefono. Svuota solo la tua copia, gli altri membri tengono la loro.';

  @override
  String get groupInfoClear => 'Svuota';

  @override
  String get groupInfoConversationCleared => 'Conversazione svuotata';

  @override
  String get groupInfoLeaveRoom => 'Uscire dalla stanza?';

  @override
  String get groupInfoLeaveGroup => 'Uscire dal gruppo?';

  @override
  String get groupInfoEverythingInItIs =>
      'Tutto ciò che contiene viene cancellato subito da questo telefono, e la chiave che hai usato qui sparisce per sempre.';

  @override
  String get groupInfoYouWillStopReceiving =>
      'Non riceverai più messaggi e gli altri membri vedranno la tua uscita.';

  @override
  String get groupInfoLeave => 'Esci';

  @override
  String get groupInfoGroupInfo => 'Info gruppo';

  @override
  String groupInfo1Member(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString membri',
      one: '$countString membro',
    );
    return '$_temp0';
  }

  @override
  String get groupInfoAdmin => 'Admin';

  @override
  String get groupInfoMembers2 => 'Membri';

  @override
  String get groupInfoInvite => 'Invita';

  @override
  String get commonAdd => 'Aggiungi';

  @override
  String get groupInfoYou => 'Tu';

  @override
  String get groupInfoRemoveFromGroup => 'Rimuovi dal gruppo';

  @override
  String get groupInfoWallpaper => 'Sfondo';

  @override
  String get groupInfoSharedMedia => 'Media condivisi';

  @override
  String get groupInfoClearConversation => 'Svuota conversazione';

  @override
  String get groupInfoLeaveRoom2 => 'Esci dalla stanza';

  @override
  String get groupInfoLeaveGroup2 => 'Esci dal gruppo';

  @override
  String get groupInfoAddMembers => 'Aggiungi membri';

  @override
  String groupInfoAdd(Object pickedLength) {
    return 'Aggiungi $pickedLength';
  }

  @override
  String handleYouAre(Object h) {
    return 'Sei @$h';
  }

  @override
  String get handleHandleDeletedThePage =>
      'Nome utente eliminato · la pagina non c\'è più';

  @override
  String get handlePublicHandle => 'Nome utente pubblico';

  @override
  String get handleOptionalYourThreeWords =>
      'Facoltativo. Le tue tre parole funzionano comunque.';

  @override
  String get handleWren => 'merlo';

  @override
  String get handleALineAboutYou => 'Una riga su di te · facoltativa';

  @override
  String get handleClaiming => 'Registrazione…';

  @override
  String get handleClaimThisHandle => 'Registra questo nome utente';

  @override
  String get handleAnyoneWithThisLink =>
      'Chiunque abbia questo link può iniziare una chat privata con te. Contiene il tuo invito e nient\'altro.';

  @override
  String get handleLinkCopied => 'Link copiato';

  @override
  String get handleDeleteThisHandle => 'Elimina questo nome utente';

  @override
  String get handleChecking => 'Controllo…';

  @override
  String get handleAvailable => '✓ Disponibile';

  @override
  String get handleAlreadyTaken => 'Già preso';

  @override
  String get handleNameRule => 'Da 3 a 20 caratteri: a-z, 0-9 o _';

  @override
  String get handleWhatAHandleDoes => 'A cosa serve un nome utente';

  @override
  String get handleAnyoneWhoKnowsIt =>
      'Chiunque lo conosca può chiedere di scriverti, ed è proprio questo lo scopo. La pagina contiene il tuo invito e la riga che hai scritto, nient\'altro, e non registra chi la legge. Puoi eliminarlo quando vuoi.';

  @override
  String handleIsNotYoursOn(Object handle) {
    return '@$handle non è tuo su questo telefono';
  }

  @override
  String handleTheRegistryHoldsIt(Object handle) {
    return 'Il registro lo associa a un\'altra chiave, molto probabilmente un\'identità che questo telefono aveva prima di un ripristino. Chi aggiunge @$handle non raggiunge te. Non si può liberare né aggiornare da qui. Scegli un altro nome.';
  }

  @override
  String get handleForgetItOnThis => 'Dimenticalo su questo telefono';

  @override
  String get homeAddAContact => 'Aggiungi un contatto';

  @override
  String get commonSettings => 'Impostazioni';

  @override
  String get homeYourKryfo => 'Il tuo Kryfo';

  @override
  String homeDateWeekday(Object weekday) {
    return '$weekday,';
  }

  @override
  String get homeAnHour => 'un\'ora';

  @override
  String homeHours(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString ore',
      one: '$countString ora',
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
      other: '$countString minuti',
      one: '$countString minuto',
    );
    return '$_temp0';
  }

  @override
  String get homeKryfoIsOffline => 'Kryfo è offline';

  @override
  String homeTorHasNotBeen(Object howLong) {
    return 'Tor non riesce a connettersi da $howLong. Finché non ci riesce, non può arrivare né partire niente.';
  }

  @override
  String get homeReconnecting => 'Riconnessione';

  @override
  String get homeReconnect => 'Riconnetti';

  @override
  String get homeWhatIsWrong => 'Cosa non va';

  @override
  String get homeKryfoWillCheckIn => 'Kryfo farà un controllo ogni 15 minuti';

  @override
  String get homeYourPhoneKeepsStopping =>
      'Il telefono continua a fermare Kryfo';

  @override
  String get homeItHasClosedKryfo =>
      'Oggi ha chiuso Kryfo tre volte, quindi i messaggi sono arrivati in ritardo o sono rimasti in attesa. I controlli resistono a questo: Kryfo si sveglia ogni 15 minuti invece di restare connesso.';

  @override
  String get homeSwitchToCheckIns => 'Passa ai controlli';

  @override
  String get homeNotNow => 'Non ora';

  @override
  String get homeNotificationsAreOff => 'Notifiche disattivate';

  @override
  String get homeAndroidIsBlockingThem =>
      'Android le sta bloccando, quindi mentre Kryfo è chiuso non ti arriva niente. I messaggi arrivano comunque quando lo apri.';

  @override
  String get homeCouldnTOpenIt =>
      'Non si è aperto. Cerca Kryfo nelle impostazioni del telefono';

  @override
  String get homeTurnThemOn => 'Attivale';

  @override
  String get homeLeaveThemOff => 'Lasciale spente';

  @override
  String get homeOurRelayIsQuiet => 'Il nostro relay tace';

  @override
  String get homeRelayModeUsesOnly =>
      'La modalità relay usa solo il nostro relay, che ora non risponde. La modalità veloce aggiunge anche relay pubblici, così i messaggi arrivano comunque. In entrambi i casi tutto resta sigillato.';

  @override
  String get homeSwitchedToFast => 'Passato a veloce';

  @override
  String get homeUseFastMode => 'Usa modalità veloce';

  @override
  String get homeKeepWaiting => 'Aspetta ancora';

  @override
  String get homeNotConnecting => 'Non si connette';

  @override
  String get homeBridgesAreOnAnd =>
      'I bridge sono attivi e tor non è ancora collegato. I bridge sono più lenti, e alcuni smettono di funzionare senza preavviso. Se la tua rete non blocca tor, la connessione diretta è più veloce e affidabile.';

  @override
  String get homeGoingDirectReconnecting =>
      'Connessione diretta · riconnessione';

  @override
  String get homeTurnBridgesOff => 'Disattiva i bridge';

  @override
  String get homeStillTrying => 'Continuo a provare';

  @override
  String get homeTorIsNotGetting =>
      'Tor non riesce a passare. Alcune reti lo bloccano di proposito. Il nostro relay è una semplice connessione e di solito funziona comunque - oppure i bridge, che richiedono più tempo per la configurazione.';

  @override
  String get homeSwitchedToRelay => 'Passato al relay';

  @override
  String get homeUseOurRelay => 'Usa il nostro relay';

  @override
  String get homeBridges => 'Bridge';

  @override
  String get homeOffline => 'Offline';

  @override
  String get homeWaiting => 'In attesa';

  @override
  String get homeNothingWaitingToSend => 'Niente in attesa di invio';

  @override
  String homeWaitingSendsWhenYou(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString in attesa · partono quando torni online',
      one: '$countString in attesa · parte quando torni online',
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
      other: '$countString in attesa · tor si sta ancora connettendo',
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
      other: '$countString in attesa · finché non ti aggiungono',
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
      other: '$countString in attesa · $parkedString finché non ti aggiungono',
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
      other: '$countString in attesa · invio in corso',
    );
    return '$_temp0';
  }

  @override
  String get commonRetry => 'Riprova';

  @override
  String get homeNoKryfosYet => 'Ancora nessun Kryfo.';

  @override
  String get homeScanTheirCodeSend =>
      'Scansiona il suo codice, mandagli un link o scrivi il @nome utente che ti ha dato.';

  @override
  String get homeAddSomeone => 'Aggiungi qualcuno';

  @override
  String get homeArchived => 'Archiviate';

  @override
  String home1Chat(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString chat',
      one: '$countString chat',
    );
    return '$_temp0';
  }

  @override
  String get homeGroups => 'Gruppi';

  @override
  String get homeRoom => 'Stanza';

  @override
  String get homeNew => 'Nuovo';

  @override
  String homeRoomExpired(Object expiredRoomName) {
    return '$expiredRoomName · stanza scaduta';
  }

  @override
  String get homeMentionedYou => 'Ti ha menzionato';

  @override
  String homeMembers(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString membri',
      one: '$countString membro',
    );
    return '$_temp0';
  }

  @override
  String get homeSupporter => 'Sostenitore';

  @override
  String get homeArchivedChats => 'Chat archiviate';

  @override
  String get homeUnmute => 'Riattiva';

  @override
  String get homeMute => 'Silenzia';

  @override
  String get homeArchive => 'Archivia';

  @override
  String get homeDeleteChat => 'Elimina chat';

  @override
  String get homeMessagesAndContactGone =>
      'Messaggi e contatto, eliminati da questo telefono';

  @override
  String get homeDeleteThisChat => 'Eliminare questa chat?';

  @override
  String homeEveryMessageWithGoes(Object c) {
    return 'Tutti i messaggi con $c vengono eliminati, e non sarà più un tuo contatto. Svuota solo questo telefono - la copia dell\'altra persona resta sua. Se ti riscrive, finisce nelle richieste.';
  }

  @override
  String get homeQueued => 'In coda';

  @override
  String get homeBlocked => 'Bloccato';

  @override
  String get homeRoomInvite => 'Invito a una stanza';

  @override
  String get homeNow => 'Ora';

  @override
  String homeM(Object inMinutes) {
    return '$inMinutes min';
  }

  @override
  String homeH(Object inHours) {
    return '$inHours h';
  }

  @override
  String get homeYesterday => 'Ieri';

  @override
  String homeD(Object inDays) {
    return '$inDays g';
  }

  @override
  String get homeNoteToSelf => 'Note';

  @override
  String get homeOnlyOnThisPhone => 'Solo su questo telefono';

  @override
  String get homeSaved => 'Salvati';

  @override
  String get homeKeptFromEveryChat => 'Conservati da tutte le chat';

  @override
  String get homeRequests => 'Richieste';

  @override
  String home1PersonWantsTo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString persone vogliono contattarti',
      one: '$countString persona vuole contattarti',
    );
    return '$_temp0';
  }

  @override
  String introduceGotItButCould(Object b, Object c) {
    return '$b l\'ha ricevuto, ma $c non è raggiungibile';
  }

  @override
  String introduceGotItButCouldNotBe(Object c, Object b) {
    return '$c l\'ha ricevuto, ma $b non è raggiungibile';
  }

  @override
  String get introduceCouldNotReachEither =>
      'Nessuno dei due è raggiungibile. Riprova più tardi';

  @override
  String introduceIntroduceTo(Object peerName) {
    return 'Presenta $peerName a...';
  }

  @override
  String get introduceBothOfThemGet =>
      'Ognuno riceve il biglietto dell\'altro. Nessuno dei due vede il soprannome che hai dato all\'altro.';

  @override
  String get introduceNoOneElseTo =>
      'Ancora nessun altro da presentare. Prima aggiungi un altro contatto.';

  @override
  String get introduceANoteLikeMy =>
      'Una nota, tipo «mio cugino» - facoltativa';

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
      other:
          'Presentazioni rimaste questa settimana: $leftString su $maxString',
      one: 'Presentazioni rimaste questa settimana: $leftString su $maxString',
    );
    return '$_temp0';
  }

  @override
  String introduceNoIntroductionsLeftNext(Object refillPhrase) {
    return 'Nessuna presentazione rimasta. La prossima si libera $refillPhrase';
  }

  @override
  String get introduceIntroduce => 'Presenta';

  @override
  String get keyVerificationSafetyNumber => 'Numero di sicurezza';

  @override
  String keyVerificationWith(Object peerName) {
    return 'Con $peerName';
  }

  @override
  String keyVerificationIfSeesTheSame(Object peerName) {
    return 'Se $peerName vede lo stesso numero, i vostri messaggi sono privati, solo tra voi due. Confrontarlo di persona o durante una chiamata di cui ti fidi è il modo più sicuro per esserne certi - ma è facoltativo, mai necessario per scrivervi.';
  }

  @override
  String get keyVerificationVerified => 'Verificato';

  @override
  String get keyVerificationMarkAsVerified => 'Segna come verificato';

  @override
  String get lockFileThatPasswordDoesNot => 'Questa password non lo apre.';

  @override
  String get lockFileThisFileIsDamaged => 'Questo file è danneggiato.';

  @override
  String get lockFileThisFileWasLocked =>
      'Questo file è stato protetto con una chiave, non con una password.';

  @override
  String get lockFileThisIsNotA => 'Questo non è un file protetto.';

  @override
  String get lockFileNotEnoughFreeMemory =>
      'Memoria libera insufficiente in questo momento.';

  @override
  String get lockFileStopped => 'Interrotto.';

  @override
  String get lockFileItNeedsAPassword => 'Serve una password.';

  @override
  String get lockFileKryfoCouldNotRead =>
      'Kryfo non è riuscito a leggere o scrivere il file.';

  @override
  String get lockFileCheckCapitalsAndSpaces =>
      'Controlla maiuscole e spazi. Nessuno può reimpostarla, nemmeno noi.';

  @override
  String get lockFileItMayHaveBeen =>
      'Potrebbe essersi interrotto durante il trasferimento. Chiedi che te lo rimandino. Non è stato salvato niente.';

  @override
  String get lockFileItOpensWithThe =>
      'Si apre con il file della chiave della persona a cui era destinato, con lo strumento age su un computer. Kryfo apre quelli con password.';

  @override
  String get lockFileKryfoOpensFilesLocked =>
      'Kryfo apre i file protetti con age. Di solito finiscono in .age.';

  @override
  String get lockFileCloseAFewApps =>
      'Chiudi qualche app e riprova. Il controllo della password richiede qualche centinaio di megabyte per un momento.';

  @override
  String get lockFileNothingWasSaved => 'Non è stato salvato niente.';

  @override
  String get lockFileTypeOneOrLet =>
      'Scrivine una, o lascia che Kryfo suggerisca quattro parole.';

  @override
  String get lockFileTheAppThatHolds =>
      'L\'app che lo contiene potrebbe averlo ripreso. Sceglilo di nuovo.';

  @override
  String get lockFileHidePassword => 'Nascondi password';

  @override
  String get lockFileShowPassword => 'Mostra password';

  @override
  String get lockFileChangeFile => 'Cambia file';

  @override
  String get lockFileChange => 'Cambia';

  @override
  String lockFileOf(Object prettySize, Object prettySize2) {
    return '$prettySize di $prettySize2';
  }

  @override
  String get lockFileEverythingStaysOnThis => 'Tutto resta su questo telefono.';

  @override
  String get lockFileCouldNotMakeOne =>
      'Impossibile generarla. Scrivine una tua.';

  @override
  String get lockFileWriteItDownBefore =>
      'Annotala da qualche parte prima di proteggere il file';

  @override
  String get lockFileNoAppOnThis =>
      'Nessuna app su questo telefono ha preso il file.';

  @override
  String get lockFileSaved => 'Salvato';

  @override
  String get lockFileCouldNotSaveIt =>
      'Impossibile salvarlo lì. Prova un\'altra cartella.';

  @override
  String get lockFileLocked => 'Protetto';

  @override
  String get lockFileLockAFile => 'Proteggi un file';

  @override
  String get lockFileMixingThePassword => 'Elaborazione password';

  @override
  String get lockFileLocking => 'Protezione';

  @override
  String get lockFileSaveToFiles => 'Salva in File';

  @override
  String get lockFileLockFile => 'Proteggi file';

  @override
  String get lockFileOnePassword => 'Una password.';

  @override
  String get lockFileNothingElseOpensIt => 'Nient\'altro lo apre.';

  @override
  String get lockFileFile => 'File';

  @override
  String lockFileFromFiles(Object prettySize) {
    return '$prettySize · da File';
  }

  @override
  String get lockFileFromFiles2 => 'Da File';

  @override
  String get lockFilePassword => 'Password';

  @override
  String get lockFileSuggestFourWords => 'Suggerisci quattro parole';

  @override
  String get lockFileTypeItAgain => 'Riscrivila';

  @override
  String get lockFileTheTwoDoNot => 'Le due non coincidono ancora.';

  @override
  String get lockFileHideTheFileName => 'Nascondi il nome del file';

  @override
  String lockFileItWillBeCalled(Object name) {
    return 'Si chiamerà «$name». Di\' a chi lo riceve che tipo di file è.';
  }

  @override
  String get lockFileTheNameAloneCan =>
      'Già il nome può dire cosa c\'è dentro.';

  @override
  String get lockFileAnyoneWithThePassword =>
      'Chiunque abbia la password può aprirlo, in Kryfo o su qualsiasi computer con lo strumento gratuito age. Se la dimentichi, il file è perso per sempre. Nessuno può reimpostarla, nemmeno noi.';

  @override
  String get lockFileLocked2 => 'Protetto.';

  @override
  String get lockFileOnlyThePasswordOpens => 'Solo la password lo apre.';

  @override
  String lockFileSafeToEmailOr(Object prettySize) {
    return '$prettySize · sicuro da mandare per email o mettere su una chiavetta USB';
  }

  @override
  String get lockFileNoKryfoOnThe =>
      'Niente Kryfo dall\'altra parte? Su un computer:';

  @override
  String get lockFileItAsksForThe =>
      'Chiede la password. age è gratuito su age-encryption.org';

  @override
  String lockTooManyTriesS(Object lockState) {
    return 'Troppi tentativi · $lockState s';
  }

  @override
  String get lockNotIt => 'Non è questo';

  @override
  String get lockYourPin => 'Il tuo PIN';

  @override
  String get lockUseFingerprint => 'Usa l\'impronta';

  @override
  String get lockSetupUnlockWithFingerprint => 'Sbloccare con l\'impronta?';

  @override
  String get lockSetupThePinStillWorks =>
      'Il PIN funziona sempre, quando vuoi. Questo è solo più veloce.';

  @override
  String get lockSetupUseFingerprint => 'Usa l\'impronta';

  @override
  String get lockSetupPinOnly => 'Solo PIN';

  @override
  String get lockSetupOnceMore => 'Ancora una volta';

  @override
  String get lockSetupSetAPin => 'Imposta un PIN';

  @override
  String get lockSetupThoseWereDifferentFrom => 'Erano diversi. Da capo.';

  @override
  String get lockSetupTheSameFourDigits => 'Le stesse cifre, di nuovo';

  @override
  String get lockSetupFourDigitsAnythingYou =>
      'Quattro cifre o più, quelle che vuoi, purché le ricordi';

  @override
  String get modesOnion => 'Onion';

  @override
  String get modesFullOnionRoutingThree =>
      'Instradamento onion completo, tre salti. Un messaggio impiega da due a cinque secondi. Nessuno vede con chi parli.';

  @override
  String get modesSlower => 'Più lento';

  @override
  String get modesRelay => 'Relay';

  @override
  String get modesOneSealedConnectionTo =>
      'Una sola connessione sigillata al relay di Kryfo, come una vpn senza niente da registrare. Gli invii arrivano in circa un secondo, e funziona dove tor è bloccato.';

  @override
  String get modesQuick => 'Rapido';

  @override
  String get modesRelayOnly => 'Solo relay';

  @override
  String get modesFast => 'Veloce';

  @override
  String get modesPlainConnectionsToEvery =>
      'Connessioni dirette a ogni relay. Quasi istantaneo, e il meno privato dei tre.';

  @override
  String get modesInstant => 'Istantaneo';

  @override
  String get modesEveryRelayYouUse =>
      'Ogni relay che usi conosce l\'indirizzo da cui ti connetti, non solo il nostro. I messaggi restano sigillati, ma il fatto che tu ne abbia inviato uno no. Disattivata di default, e di nuovo disattivata dopo una reinstallazione.';

  @override
  String get modesSpeed => 'Velocità';

  @override
  String get modesPrivacy => 'e privacy';

  @override
  String get modesChangeGloballyOrPer =>
      'Cambiala per tutte le chat o per una sola';

  @override
  String get modesSoon => 'Presto';

  @override
  String get modesActive => 'Attiva';

  @override
  String get modesSpeed2 => 'VELOCITÀ';

  @override
  String get modesHops => 'SALTI';

  @override
  String get modesIp => 'IP';

  @override
  String get modesVisible => 'Visibile';

  @override
  String get modesHidden => 'Nascosto';

  @override
  String modesHeadsUp(Object warning) {
    return '*Attenzione:* $warning';
  }

  @override
  String get modesOnionIsTheDefault =>
      'Onion è la modalità predefinita e resta tale finché non la cambi. Il cambio vale dal prossimo messaggio.';

  @override
  String get modesFastMode => 'Modalità veloce';

  @override
  String get modesPlainConnectionsToEveryRelayQuicker =>
      'Connessioni dirette a ogni relay. Più rapido, e i relay possono vedere il tuo indirizzo ip. In ogni caso i messaggi restano cifrati end-to-end.';

  @override
  String get modesTurnOnFastMode => 'Attiva la modalità veloce';

  @override
  String get modesKeepItOff => 'Lasciala spenta';

  @override
  String get movedWipeThisPhone => 'Cancellare Kryfo da questo telefono?';

  @override
  String get movedEverythingKryfoHoldsHere =>
      'Tutto ciò che Kryfo conserva qui viene cancellato: i messaggi, i contatti, le chiavi. L\'altro dispositivo li tiene tutti. Non si può annullare.';

  @override
  String get movedWipeIt => 'Cancella';

  @override
  String get movedNotMovingAfterAll => 'Alla fine non ti trasferisci?';

  @override
  String get movedOnlyDoThisIf =>
      'Fallo solo se il backup non è mai stato importato da nessuna parte. Se lo è stato, ora due dispositivi hanno la stessa identità, e i messaggi inizieranno a perdersi su entrambi.';

  @override
  String get movedIMStayingHere => 'Resto qui';

  @override
  String get movedStayingHere => 'Resto qui';

  @override
  String movedKryfoWillCloseNow(Object myId) {
    return 'Ora Kryfo si chiude. Tocca l\'icona per riaprirlo come $myId.';
  }

  @override
  String get movedReopenKryfo => 'Riapri Kryfo';

  @override
  String get movedThisKryfoHasMoved => 'Questo Kryfo si è trasferito';

  @override
  String movedIsNowOnAnother(Object myId) {
    return '$myId ora è su un altro dispositivo. Questo telefono può ancora mostrare ciò che c\'era, ma non ci arriverà più niente di nuovo, e qualsiasi cosa invii da qui non arriverà a nessuno.';
  }

  @override
  String get movedKeepItToRead => 'Tienilo per leggere';

  @override
  String get movedWipeThisPhone2 => 'Cancella Kryfo da questo telefono';

  @override
  String get movedIMNotMoving => 'Alla fine non mi trasferisco';

  @override
  String get myKryfoAHandleIs3 =>
      'Un nome utente ha da 3 a 20 lettere, cifre o _';

  @override
  String get myKryfoInviteCopiedClearsIn => 'Invito copiato · rimosso tra 60 s';

  @override
  String myKryfoAddMeOnKryfo(Object myId, Object uri) {
    return 'Aggiungimi su Kryfo. Il mio ID è $myId\n\nTocca per aggiungermi:\n$uri\n\nKryfo è un messenger privato. Niente numero di telefono, niente email.';
  }

  @override
  String get myKryfoAddMeOnKryfo2 => 'Aggiungimi su Kryfo';

  @override
  String get myKryfoAddSomeone => 'Aggiungi qualcuno';

  @override
  String get myKryfoKryfoDoesnTScan =>
      'Kryfo non scansiona i tuoi contatti, ed è proprio questo il punto.';

  @override
  String get myKryfoIfThisLinkEnds =>
      'Se questo link finisce dove non volevi, reimpostalo nelle impostazioni. A quel punto chi ce l\'ha avrà bisogno di uno nuovo.';

  @override
  String get myKryfoAlreadyShareAFriend =>
      'Avete già un amico in comune su Kryfo? Può presentarvi dalla sua chat, e saltate la richiesta.';

  @override
  String get myKryfoHandleCopied => 'Nome utente copiato';

  @override
  String get myKryfoTheyReHereWith => 'È qui con me';

  @override
  String get myKryfoPointYourPhonesAt =>
      'Puntate i telefoni l\'uno verso l\'altro. Niente passa da un server.';

  @override
  String get myKryfoScanTheirsInstead => 'Scansiona il suo';

  @override
  String get myKryfoTheyReadYouA => 'Ti legge un codice';

  @override
  String get myKryfoTheyReSomewhereElse => 'È da un\'altra parte';

  @override
  String get myKryfoSendThemALink =>
      'Mandagli un link. Si apre direttamente su Aggiungi.';

  @override
  String get myKryfoYourLinkAppearsOnce =>
      'Il tuo link compare appena ti connetti';

  @override
  String get myKryfoTheLinkCarriesYour =>
      'Il link contiene il tuo id, il tuo indirizzo e le chiavi per iniziare una chat. Funziona finché non lo reimposti nelle impostazioni.';

  @override
  String get myKryfoSendTheLink => 'Invia il link';

  @override
  String get myKryfoAsACard => 'Come biglietto';

  @override
  String get myKryfoAnImageWithThe => 'Un\'immagine con il qr';

  @override
  String get myKryfoAsAFile => 'Come file';

  @override
  String get myKryfoContactFile => 'File contatto';

  @override
  String get myKryfoIKnowTheirHandle => 'Conosco il suo nome utente';

  @override
  String get myKryfoTypeTheNameThey =>
      'Scrivi il @nome che ti ha dato. Funziona se ne ha registrato uno.';

  @override
  String get myKryfoWren => 'Merlo';

  @override
  String get myKryfoTheLookupAsksFor =>
      'La ricerca invia solo quel nome e niente su di te. Il tuo primo messaggio arriva comunque come richiesta.';

  @override
  String get myKryfoLooking => 'Ricerca…';

  @override
  String get myKryfoFindThem => 'Trova';

  @override
  String get myKryfoYourAddressAppearsOnce =>
      'Il tuo indirizzo compare appena ti connetti';

  @override
  String get myKryfoAPublicHandle => 'Un nome utente pubblico';

  @override
  String get myKryfoPutItInA =>
      'Mettilo in una bio. Chiunque lo conosca può trovarti.';

  @override
  String get myKryfoANamePeopleCan =>
      'Un nome con cui le persone possono trovarti. Disattivato finché non ne registri uno.';

  @override
  String get newGroupCouldNotCreate => 'Impossibile creare';

  @override
  String get newGroupNewGroup => 'Nuovo gruppo';

  @override
  String get newGroupCreating => 'Creazione…';

  @override
  String get newGroupCreate => 'Crea';

  @override
  String get newGroupGroupName => 'Nome del gruppo';

  @override
  String get newGroupMembers => 'Membri';

  @override
  String get newGroupPickAtLeastOne => 'Scegline almeno uno';

  @override
  String newGroupSelected(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString selezionati',
      one: '$countString selezionato',
    );
    return '$_temp0';
  }

  @override
  String get newGroupAddAtLeastOne =>
      'Prima di creare un gruppo, aggiungi almeno un contatto.';

  @override
  String get notesToday => 'OGGI';

  @override
  String get notesYesterday => 'IERI';

  @override
  String get notesNoteToSelf => 'Note';

  @override
  String get notesOnlyOnThisPhone => 'Solo su questo telefono';

  @override
  String get notesAQuietPlace => 'Un posto tranquillo';

  @override
  String get notesJotAnythingDownIt =>
      'Annota qualsiasi cosa. Resta su questo telefono e non lo lascia mai.';

  @override
  String get notesJotSomethingDown => 'Annota qualcosa…';

  @override
  String get onboardingPrivateByDefault => 'PRIVATO DI SERIE';

  @override
  String get onboardingPrivateMessaging =>
      'Messaggi privati,\n*senza fregature*.';

  @override
  String get onboardingYourNameIsThree =>
      '*Il tuo nome: tre parole.* Niente telefono, niente email, niente rubrica.';

  @override
  String get onboardingNobodyGetsInUnless =>
      '*Nessuno entra se non lo fai entrare tu.* Non c\'è ricerca. Le persone si aggiungono a mano, da entrambe le parti.';

  @override
  String get onboardingTheFirstConnectionTakes =>
      '*La prima connessione richiede un minuto.* Kryfo costruisce un percorso privato prima di inviare. Poi è veloce.';

  @override
  String get onboardingBegin => 'Inizia';

  @override
  String get onboardingHaveABackupRestore => 'Hai un backup? Ripristina →';

  @override
  String get onboardingKryfoIsOpenSource => 'Kryfo è open source';

  @override
  String get onboardingYourKryfoId => 'IL TUO ID KRYFO';

  @override
  String get onboardingGeneratedFromAKey =>
      'Generato da una chiave che esiste solo su questo telefono. *Facile da ricordare, unico, solo tuo.* Nessun altro ce l\'ha.';

  @override
  String get onboardingTryAnother => 'Provane un altro';

  @override
  String get onboardingUseThisName => 'Usa questo nome →';

  @override
  String get onboardingThreeWords => 'Tre parole. *Solo tue.*';

  @override
  String get onboardingPickA => 'Scegli un *volto*.';

  @override
  String get onboardingDrawnOnThisPhone =>
      'Disegnato su questo telefono a partire da un numero, mai caricato online. Cambialo quando vuoi.';

  @override
  String get onboardingThePeopleYouMessage =>
      'Lo vedono anche le persone a cui scrivi';

  @override
  String get onboardingKeepMyInitial => 'Tieni la mia iniziale';

  @override
  String get onboardingThatOne => 'Questo →';

  @override
  String get onboardingContinue => 'Continua →';

  @override
  String get onboardingHowYourMessages => 'Come *viaggiano* i tuoi messaggi.';

  @override
  String get onboardingYouCanChangeThis =>
      'Puoi cambiarlo quando vuoi nelle impostazioni, per tutti o per una sola chat.';

  @override
  String get onboardingOnion => 'Onion';

  @override
  String get onboardingSlowerAMessageTakes =>
      'Più lento. Un messaggio impiega da due a cinque secondi.';

  @override
  String get onboardingHidesYourAddressFrom =>
      'Nasconde il tuo indirizzo a tutti, compreso il nostro relay.';

  @override
  String get onboardingRelay => 'Relay';

  @override
  String get onboardingOurRelaySeesYour =>
      'Il nostro relay vede il tuo indirizzo. Nessun altro lo vede.';

  @override
  String get onboardingAboutASecondWorks =>
      'Circa un secondo. Funziona dove tor è bloccato.';

  @override
  String get onboardingFast => 'Veloce';

  @override
  String get onboardingEveryRelayYouUse =>
      'Ogni relay che usi vede il tuo indirizzo. Il meno privato dei tre.';

  @override
  String get onboardingNearInstant => 'Quasi istantaneo.';

  @override
  String get onboardingKeepOnion => 'Tieni onion →';

  @override
  String get onboardingUseThis => 'Usa questo →';

  @override
  String get onboardingSkipOnionIsA =>
      'Salta · onion va benissimo come predefinito';

  @override
  String get onboardingThreeThingsThen => 'Tre cose,\npoi *sei dentro*.';

  @override
  String get onboardingEverythingElseTheApp =>
      'Tutto il resto te lo dirà l\'app quando serve.';

  @override
  String get onboardingYourNameIsThreeWords => 'Il tuo nome: tre parole';

  @override
  String get onboardingThatIsTheWhole =>
      'Questa è tutta la tua identità. Nessun numero che possa trapelare, nessuna email da prendere di mira col phishing, niente da cercare. Le persone con cui parli vedono queste parole e il volto che hai scelto.';

  @override
  String get onboardingNobodyCanReachYou =>
      'Nessuno può raggiungerti finché non lo fai entrare';

  @override
  String get onboardingAStrangerWithYour =>
      'Uno sconosciuto con le tue parole può solo bussare. Il suo primo messaggio aspetta nelle richieste finché non dici di sì, e puoi dire di no senza che lo sappia mai.';

  @override
  String get onboardingTheFirstConnectionTakesAMinute =>
      'La prima connessione richiede un minuto';

  @override
  String get onboardingKryfoBuildsAPrivateRouteBefore =>
      'Kryfo costruisce un percorso privato prima di inviare qualsiasi cosa. Mentre sei offline, i messaggi aspettano e arrivano quando torni.';

  @override
  String get onboardingYourIdentityLivesOn =>
      'La tua identità vive su questo telefono. Fanne un backup dalle impostazioni quando te la senti.';

  @override
  String get onboardingIUnderstand => 'Ho capito →';

  @override
  String get onboardingOneQuiet => 'Una *notifica* discreta.';

  @override
  String get onboardingAndroidNeedsAVisible =>
      'Android richiede una notifica visibile mentre un\'app resta in ascolto in background. È così che i messaggi ti raggiungono quando Kryfo è chiuso.';

  @override
  String get onboardingSilentAndAtThe => 'Silenziosa, e in fondo alla tendina';

  @override
  String get onboardingItNeverBuzzesTurn =>
      'Non vibra mai. Se la disattivi, i messaggi aspettano finché non riapri l\'app.';

  @override
  String get onboardingGotIt => 'Capito →';

  @override
  String get onboardingNow => 'Ora *aggiungi qualcuno*.';

  @override
  String get onboardingTheAppIsReady =>
      'L\'app è pronta. Nessuno può scriverti finché non lo aggiungi o non lo fai entrare.';

  @override
  String get onboardingEveryWayToAdd => 'Tutti i modi per aggiungere qualcuno';

  @override
  String get onboardingShowYourCodeSend =>
      'Mostra il tuo codice, mandagli un link o scrivi il @nome utente che ti ha dato.';

  @override
  String get onboardingScanTheirs => 'Scansiona il suo';

  @override
  String get onboardingPointTheCameraAt => 'Inquadra il suo codice';

  @override
  String get onboardingTheAppIsReadyWhenYou =>
      'L\'app è pronta quando lo sei tu.';

  @override
  String get onboardingNotNowAddPeople =>
      'Non ora · aggiungi persone più tardi';

  @override
  String get openLockedOpened => 'Aperto';

  @override
  String get openLockedOpenALockedFile => 'Apri un file protetto';

  @override
  String get openLockedCheckingThePassword => 'Controllo della password';

  @override
  String get openLockedOpening => 'Apertura';

  @override
  String get openLockedFile => 'File';

  @override
  String get openLockedOpenFile => 'Apri file';

  @override
  String get openLockedTypeThePassword => 'Scrivi la password.';

  @override
  String get openLockedItOpensOnThis => 'Si apre su questo telefono.';

  @override
  String get openLockedLockedFile => 'File protetto';

  @override
  String openLockedFromFiles(Object prettySize) {
    return '$prettySize · da File';
  }

  @override
  String get openLockedFromFiles2 => 'Da File';

  @override
  String get openLockedPassword => 'Password';

  @override
  String get openLockedThePasswordIsChecked =>
      'Prima viene controllata la password. Solo dopo Kryfo chiede dove mettere il file aperto, e ci finisce direttamente.';

  @override
  String get openLockedOpened2 => 'Aperto.';

  @override
  String get openLockedSavedWhereYouChose => 'Salvato dove hai scelto.';

  @override
  String get pairCodePairingCode => 'Codice di abbinamento';

  @override
  String get pairCodeShowACode => 'Mostra un codice';

  @override
  String get pairCodeEnterOne => 'Inseriscine uno';

  @override
  String get pairCodeSixDigits => 'Sei cifre';

  @override
  String get pairCodeLooking => 'Ricerca…';

  @override
  String get pairCodeNothingThereYetTrying => 'Ancora niente · riprovo';

  @override
  String get pairCodeNothingAtThatCode =>
      'Niente con quel codice. Potrebbe essere sparito, o non l\'hanno ancora condiviso.';

  @override
  String get pairCodeTypeTheSixDigits =>
      'Scrivi le sei cifre che ti hanno letto.';

  @override
  String get pairCodeAddThem => 'Aggiungi';

  @override
  String get pairCodeUsedTwice =>
      'Questo codice è stato usato due volte. Chiedine uno nuovo.';

  @override
  String get pairCodeIsThisThem => 'È questa persona?';

  @override
  String get pairCodeCheckMatches => 'Controlla che corrisponda al suo schermo';

  @override
  String get pairCodeNotThem => 'Non è questa persona';

  @override
  String get pairCodeNotAdded => 'Non aggiunto. Chiedi un nuovo codice.';

  @override
  String get panicSetupThoseWereDifferentFrom => 'Erano diversi. Da capo.';

  @override
  String get panicSetupOnceMore => 'Ancora una volta';

  @override
  String get panicSetupTheSameFourDigits => 'Le stesse cifre, di nuovo';

  @override
  String get photoKnowsEverythingInside => 'Tutto quello che contiene';

  @override
  String get photoKnowsVideo => 'Video';

  @override
  String get photoKnowsPhoto => 'Foto';

  @override
  String get photoKnowsWhatThisVideoKnows => 'Cosa sa questo video';

  @override
  String get photoKnowsWhatThisPhotoKnows => 'Cosa sa questa foto';

  @override
  String get photoKnowsRemoveAllOfIt => 'Rimuovi tutto';

  @override
  String get photoKnowsKeepItAsIt => 'Lascia com\'è';

  @override
  String get photoKnowsReadOnThisPhone =>
      'LETTO SU QUESTO TELEFONO · IL VIDEO È RIMASTO QUI';

  @override
  String get photoKnowsReadOnThisPhoneThePhoto =>
      'LETTA SU QUESTO TELEFONO · LA FOTO È RIMASTA QUI';

  @override
  String get photoKnowsReadingTheFile => 'Lettura del file';

  @override
  String photoKnowsOf(Object prettySize, Object prettySize2) {
    return '$prettySize di $prettySize2';
  }

  @override
  String get photoKnowsEverythingStaysOnThis =>
      'Tutto resta su questo telefono.';

  @override
  String photoKnowsMapWithAPin(Object place) {
    return 'Mappa con un segnaposto. $place';
  }

  @override
  String get photoKnowsDrawnOffline => 'DISEGNATA OFFLINE';

  @override
  String photoKnowsShowEverything(Object title) {
    return '$title. Mostra tutto';
  }

  @override
  String get pinsAppLock => 'Blocco app';

  @override
  String get pinsYourPin => 'Il tuo PIN';

  @override
  String get commonOn => 'Attivo';

  @override
  String get commonOff => 'Disattivato';

  @override
  String get pinsOpensKryfoFourDigits =>
      'Apre Kryfo. Richiesto quando torna in primo piano.';

  @override
  String get pinsChangePin => 'Cambia PIN';

  @override
  String get pinsSetAPin => 'Imposta un PIN';

  @override
  String get pinsTurnOff => 'Disattiva';

  @override
  String get pinsTurnOffTheApp => 'Disattivare il blocco app?';

  @override
  String get pinsThePinGoesAnd =>
      'Il PIN viene rimosso, e con lui il PIN di cancellazione e tutte le chat nascoste. Chiunque abbia in mano il tuo telefono apre Kryfo al posto tuo.';

  @override
  String get pinsUnlockWithFingerprint => 'Sblocca con l\'impronta';

  @override
  String get pinsWipePin => 'PIN di cancellazione';

  @override
  String get pinsNeedsAPinFirst => 'Prima serve un PIN';

  @override
  String get pinsSet => 'Impostato';

  @override
  String get pinsChangeWipePin => 'Cambia PIN di cancellazione';

  @override
  String get pinsSetAWipePin => 'Imposta PIN di cancellazione';

  @override
  String get pinsRemove => 'Rimuovi';

  @override
  String get pinsRemoveTheWipePin => 'Rimuovere il PIN di cancellazione?';

  @override
  String get pinsTheLockScreenKeeps =>
      'La schermata di blocco tiene il tuo PIN. Il PIN di cancellazione non fa più niente.';

  @override
  String profileCopied(Object what) {
    return '$what copiato';
  }

  @override
  String get profileProfile => 'Profilo';

  @override
  String get profileChangeYourFace => 'Cambia il tuo volto';

  @override
  String get profileKryfoId => 'Id Kryfo';

  @override
  String get profileOnionAddress => 'Indirizzo onion';

  @override
  String get profileSupporterBadge => 'Badge sostenitore';

  @override
  String profileYouAreAThank(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter': 'Sei tra i sostenitori. Grazie.',
      'patron': 'Sei tra i mecenati. Grazie.',
      'guardian': 'Sei tra i custodi. Grazie.',
      'other': 'Sei tra i sostenitori. Grazie.',
    });
    return '$_temp0';
  }

  @override
  String get profileShowMyBadge => 'Mostra il mio badge';

  @override
  String get profileOnMyOwnScreens => 'Sulle mie schermate';

  @override
  String get profileLetContactsSeeIt => 'Fallo vedere ai contatti';

  @override
  String get profileOffByDefault => 'Disattivato di default';

  @override
  String get profileShareConnect => 'Condividi e connetti';

  @override
  String get profileMyKryfoCode => 'Il mio codice Kryfo';

  @override
  String get profileAddContact => 'Aggiungi contatto';

  @override
  String get profileGiveAgain => 'Dona ancora';

  @override
  String get profileSupportKryfo => 'Sostieni Kryfo';

  @override
  String get profileKryfoRunsOnWhat =>
      'Kryfo va avanti con quello che dà la gente';

  @override
  String get profileKeepKryfoIndependent => 'Mantieni Kryfo indipendente';

  @override
  String get qrLink => 'Link';

  @override
  String get qrYourLinkAsTyped =>
      'IL TUO LINK COM\'È · NESSUN REDIRECT DI TRACCIAMENTO';

  @override
  String get qrText => 'Testo';

  @override
  String get qrStaysInTheCode => 'RESTA NEL CODICE · NESSUN SERVER LO CONSERVA';

  @override
  String get qrWiFi => 'Wi-Fi';

  @override
  String get qrMadeOnThisPhone =>
      'CREATO SU QUESTO TELEFONO · NESSUN SITO HA VISTO LA PASSWORD';

  @override
  String get qrNetworkName => 'Nome della rete';

  @override
  String get qrPassword => 'Password';

  @override
  String get qrContact => 'Contatto';

  @override
  String get qrOnlyWhatYouType =>
      'SOLO QUELLO CHE SCRIVI · NIENTE DAI TUOI CONTATTI';

  @override
  String get qrName => 'Nome';

  @override
  String get qrPhone => 'Telefono';

  @override
  String get qrEmail => 'Email';

  @override
  String get qrOpensTheirMailApp =>
      'APRE LA SUA APP DI POSTA · NIENTE PARTE DA QUI';

  @override
  String get qrTo => 'A';

  @override
  String get qrSubject => 'Oggetto';

  @override
  String get qrANumberNothingElse => 'UN NUMERO · NIENT\'ALTRO';

  @override
  String get qrNumber => 'Numero';

  @override
  String get qrSms => 'SMS';

  @override
  String get qrOpensTheirMessagesApp =>
      'APRE LA SUA APP DEI MESSAGGI · NIENTE PARTE DA QUI';

  @override
  String get qrMessage => 'Messaggio';

  @override
  String get qrLocation => 'Posizione';

  @override
  String get qrCoordinatesOnlyNoMap =>
      'SOLO COORDINATE · NESSUN SERVIZIO MAPPE CONSULTATO';

  @override
  String get qrLatitude => 'Latitudine';

  @override
  String get qrLongitude => 'Longitudine';

  @override
  String get qrBitcoin => 'Bitcoin';

  @override
  String get qrAddressAndAmountNo =>
      'INDIRIZZO E IMPORTO · NESSUN SITO DI PAGAMENTO IN MEZZO';

  @override
  String get qrAddress => 'Indirizzo';

  @override
  String get qrAmountInBtc => 'Importo in BTC';

  @override
  String get qrInk => 'Inchiostro';

  @override
  String get qrAmber => 'Ambra';

  @override
  String get qrViolet => 'Viola';

  @override
  String get qrCouldNotDrawThe => 'Impossibile disegnare l\'immagine.';

  @override
  String get qrSavedToYourGallery => 'Salvato nella tua galleria';

  @override
  String get qrCouldNotSaveIt =>
      'Impossibile salvarlo. Controlla che il telefono abbia spazio.';

  @override
  String get qrNoAppOnThis =>
      'Nessuna app su questo telefono ha preso l\'immagine.';

  @override
  String get qrTooMuchForOne => 'Troppo per un solo codice. Accorcialo.';

  @override
  String get qrThisIsALot =>
      'È tanto per un solo codice. Le fotocamere più vecchie potrebbero non leggerlo.';

  @override
  String get qrPrivateQrCode => 'Codice QR privato';

  @override
  String get qrColour => 'Colore';

  @override
  String get qrCopiedItLeavesThe => 'Copiato. Esce dagli appunti tra un minuto';

  @override
  String get qrSecurity => 'Sicurezza';

  @override
  String get qrNone => 'Nessuna';

  @override
  String get qrSaveImage => 'Salva immagine';

  @override
  String qrColour2(Object name) {
    return 'Colore $name';
  }

  @override
  String get qrTypeBelowAndThe =>
      'Scrivi qui sotto e il\ncodice si disegna da solo';

  @override
  String get qrQrCode => 'Codice QR';

  @override
  String get qrHidePassword => 'Nascondi password';

  @override
  String get qrShowPassword => 'Mostra password';

  @override
  String get qrCopyPassword => 'Copia password';

  @override
  String get requestsSentAnAttachment => 'Ha inviato un allegato';

  @override
  String get requestsWantsToConnect => 'Vuole entrare in contatto';

  @override
  String get requestsAccepted => 'Accettata';

  @override
  String requestsBlock(Object id) {
    return 'Bloccare $id?';
  }

  @override
  String get requestsNothingMoreFromThem =>
      'Da questa persona non ti arriverà più niente. La sua richiesta e i relativi messaggi vengono eliminati.';

  @override
  String get requestsBlocked => 'Bloccato';

  @override
  String get requestsDeleted => 'Eliminata';

  @override
  String get requestsRequests => 'Richieste';

  @override
  String get requestsNoRequests => 'Nessuna richiesta';

  @override
  String get requestsMessagesFromPeopleYou =>
      'I messaggi di chi non hai aggiunto arrivano prima qui.';

  @override
  String get requestsLooksSafeNothingSuspicious =>
      'Sembra sicuro · niente di sospetto nel primo messaggio';

  @override
  String get commonAccept => 'Accetta';

  @override
  String get requestsDecline => 'Rifiuta';

  @override
  String get restoreThatFileIsNot => 'Questo file non è un backup di Kryfo';

  @override
  String get restoreThisFileIsDamaged =>
      'Questo file è danneggiato e non si può leggere';

  @override
  String get restoreTypeThePassphraseThe =>
      'Scrivi la passphrase con cui è stato creato il file';

  @override
  String get restoreReplaceTheAccountOn =>
      'Sostituire l\'account su questo telefono?';

  @override
  String get restoreWhatIsHereNow =>
      'Quello che c\'è ora, con la sua identità, i contatti e i messaggi, viene eliminato. Il file ne prende il posto. Non si può annullare.';

  @override
  String get restoreReplaceIt => 'Sostituisci';

  @override
  String restoreCouldNotBeReleased(Object mine) {
    return 'Impossibile liberare @$mine';
  }

  @override
  String restoreTheRegistryDidNot(Object mine) {
    return 'Il registro non ha risposto. Se vai avanti, @$mine resta collegato all\'identità che questo telefono sta per perdere. Chi lo aggiunge scriverà a nessuno, e il nome non potrà più essere registrato. Meglio connettersi e riprovare.';
  }

  @override
  String get restoreRestoreAnyway => 'Ripristina comunque';

  @override
  String get restoreNotYet => 'Non ancora';

  @override
  String get restoreRestored => 'Ripristinato';

  @override
  String restoreKryfoWillCloseNow(Object haloId) {
    return 'Ora Kryfo si chiude. Tocca l\'icona per riaprirlo come $haloId.';
  }

  @override
  String get restoreReopenKryfo => 'Riapri Kryfo';

  @override
  String get restoreTheRestoreDidNot =>
      'Il ripristino non è terminato. Non è stato modificato niente';

  @override
  String get restoreThisIdentity => 'questa identità';

  @override
  String get restoreMoveYourKryfoHere => 'Trasferisci qui il tuo Kryfo';

  @override
  String restoreThisBackupIsRestoring(Object name) {
    return 'Questo backup è $name. Ripristinarlo trasferisce quell\'identità su questo dispositivo.';
  }

  @override
  String restoreThisBackupMadeOn(Object name, Object date, Object time) {
    return 'Questo backup è $name, creato il $date alle $time. Ripristinarlo trasferisce quell\'identità su questo dispositivo.';
  }

  @override
  String restoreItHoldsOfPhotos(Object mb) {
    return 'Contiene $mb di foto, note vocali e file. Potrebbe richiedere qualche minuto. Tieni l\'app aperta.';
  }

  @override
  String get restoreWhatFollows => 'Cosa arriva';

  @override
  String get restoreYourNameYourCode =>
      'Il tuo nome, il tuo codice e ogni contatto.';

  @override
  String get restoreEveryConversationBackTo =>
      'Ogni conversazione, fin dall\'inizio.';

  @override
  String get restoreYourPhotosVoiceNotes => 'Le tue foto, note vocali e file.';

  @override
  String restoreYourPhotosVoiceNotesCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Le tue foto, note vocali e file · $countString.',
    );
    return '$_temp0';
  }

  @override
  String get restoreYourOnionAddressSo =>
      'Il tuo indirizzo onion, così chi ti raggiunge direttamente continua a raggiungerti.';

  @override
  String get restoreAnythingSentToYou =>
      'Quello che ti è stato inviato mentre il vecchio telefono era spento, fino a quattordici giorni dall\'invio.';

  @override
  String get restoreYourSupporterBadgeIf =>
      'Il tuo badge sostenitore, se ne hai uno.';

  @override
  String get restoreWhatDoesnT => 'Cosa no';

  @override
  String get restoreTheOldPhoneStops =>
      'Il vecchio telefono smette di ricevere nel momento in cui invii qualcosa da qui. Non gradualmente. Il primo messaggio che invii da questo dispositivo è l\'ultimo che il vecchio telefono può seguire, e tutto ciò che gli arriva dopo è illeggibile lì e non ti aspetta nemmeno qui.';

  @override
  String get restoreIfThePhoneThis =>
      'Se il telefono da cui viene questo file è ancora in uso, smetti di usarci Kryfo prima di andare avanti. Due telefoni con lo stesso Kryfo perdono messaggi entrambi.';

  @override
  String get restoreNotificationsNeedSettingUp =>
      'Le notifiche vanno riconfigurate su questo dispositivo.';

  @override
  String get restoreMoveItHere => 'Trasferiscilo qui';

  @override
  String get restoreNotNow => 'Non ora';

  @override
  String get restoreRestore => 'Ripristina';

  @override
  String get restoreFromABackupFile => 'Da un file di backup';

  @override
  String get restoreABackupBringsBack =>
      'Un backup riporta la tua identità e i tuoi contatti, e i messaggi che erano sul telefono quando è stato creato il file. Quello che è stato detto dopo non c\'è.';

  @override
  String get restoreTheFile => 'Il file';

  @override
  String get restorePickTheBackupFile => 'Scegli il file di backup';

  @override
  String get restoreThePassphrase => 'La passphrase';

  @override
  String get restoreTheOneTheFile => 'Quella con cui è stato creato il file';

  @override
  String get restoreWhatComesBack => 'Cosa torna';

  @override
  String get restoreChecking => 'Controllo…';

  @override
  String get restoreCheckTheFile => 'Controlla il file';

  @override
  String get restoreReleasingYourHandle => 'Rilascio del nome utente…';

  @override
  String restoreMoving(Object progress) {
    return 'Trasferimento… $progress';
  }

  @override
  String get restoreRestoring => 'Ripristino…';

  @override
  String get restoreNotThisOne => 'Non questo';

  @override
  String get restoreDateUnknown => 'Data sconosciuta';

  @override
  String get restoreAnIdentity => 'Un\'identità';

  @override
  String get restoreMessagesSentOrReceived =>
      'I messaggi inviati o ricevuti dopo quella data non sono in questo file.';

  @override
  String restoreGb(Object bytes) {
    return '$bytes GB';
  }

  @override
  String restoreMb(Object bytes) {
    return '$bytes MB';
  }

  @override
  String get roomCreateCouldNotCreateThe => 'Impossibile creare la stanza';

  @override
  String get roomCreateBurnerRoom => 'Stanza effimera';

  @override
  String get roomCreateARoomThatEnds =>
      'Una stanza che finisce. Tutti entrano con una chiave creata apposta, e quando finisce non resta niente su nessun telefono.';

  @override
  String get roomCreateRoomName => 'Nome della stanza';

  @override
  String get roomCreateEndsAfter => 'Finisce dopo';

  @override
  String get roomCreateMemberCap => 'Limite membri';

  @override
  String roomCreateNoOnePastThe(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Nessuno oltre i primi $countString',
      one: 'Nessuno oltre il primo',
    );
    return '$_temp0';
  }

  @override
  String get roomCreateOffAnyoneWithThe =>
      'Disattivato. Chiunque abbia il link';

  @override
  String roomCreateThisRoomAndEverything(Object expiryWords) {
    return 'Questa stanza e tutto ciò che contiene spariscono tra $expiryWords';
  }

  @override
  String get roomCreateCreating => 'Creazione...';

  @override
  String get roomCreateCreateRoom => 'Crea stanza';

  @override
  String get roomLinkSendTheRoomTo => 'Invia la stanza a';

  @override
  String get roomLinkTheyWillKnowThis =>
      'Sapranno che la stanza arriva da te. Dentro, sono una chiave come tutti gli altri.';

  @override
  String get roomLinkNoContactsYet => 'Ancora nessun contatto';

  @override
  String roomLinkEndsIn(Object time) {
    return 'Finisce tra $time';
  }

  @override
  String get roomLinkAnyoneWithThisCan =>
      'Chiunque abbia questo link può entrare finché la stanza non finisce. Entra con una chiave creata per questa stanza, e non vede niente di ciò che è stato inviato prima del suo arrivo.';

  @override
  String get roomLinkRoomLinkCopied => 'Link della stanza copiato';

  @override
  String get roomLinkSendToAContact => 'Invia a un contatto';

  @override
  String get roomLinkCopyRoomLink => 'Copia link stanza';

  @override
  String get savedVoiceNote => 'Nota vocale';

  @override
  String get savedPhoto => 'Foto';

  @override
  String get savedSaved => 'Salvati';

  @override
  String get savedNothingSavedYet => 'Ancora niente di salvato';

  @override
  String get savedLongPressAnyMessage =>
      'Tieni premuto un messaggio e tocca salva per tenerlo qui.';

  @override
  String get savedViewInChat => 'Vedi nella chat';

  @override
  String get savedPhoto2 => 'Foto';

  @override
  String get scanThatSNotA =>
      'Questo non è un QR di Kryfo · continua a inquadrare';

  @override
  String get scanScanAKryfoQr => 'Scansiona un qr Kryfo';

  @override
  String get scanFlash => 'Flash';

  @override
  String get scanPointAtAKryfo =>
      'Inquadra un qr Kryfo · niente lascia il tuo telefono';

  @override
  String get seenWhatWeCanSee => 'Cosa possiamo vedere';

  @override
  String get seenEveryMessengerClaimsPrivacy =>
      'Ogni app di messaggi dice di essere privata. Questo è l\'elenco preciso, per percorso, comprese le parti che non ci fanno onore. Tocca una riga per il perché.';

  @override
  String get seenHonestAboutTheLast =>
      'Sinceri sulle ultime righe: a questo servono il blocco app, il PIN di cancellazione e l\'archiviazione cifrata, e nessuno strumento ti salva da chi ha in mano il tuo telefono sbloccato. Il modello di minaccia completo è in THREAT_MODEL.md nel repository, scritto secondo LINDDUN. Il codice è aperto, quindi niente di tutto questo va preso sulla fiducia.';

  @override
  String get seenHidden => 'Nascosto';

  @override
  String get seenNever => 'Mai';

  @override
  String get seenOnDevice => 'In locale';

  @override
  String get seenYours => 'Tocca a te';

  @override
  String get seenUnaudited => 'Senza audit';

  @override
  String get seenWhoYouTalkTo => 'Con chi parli';

  @override
  String get seenEachConversationGetsIts =>
      'Ogni conversazione ha un proprio indirizzo, derivato da entrambe le chiavi. Un relay vede depositi scollegati tra loro, non una coppia di persone.';

  @override
  String get seenWhatYouSay => 'Cosa dici';

  @override
  String get seenEndToEndEncrypted =>
      'Cifrato end-to-end con il double ratchet di signal, poi sigillato di nuovo dentro un gift wrap. Non potremmo leggerlo nemmeno volendo.';

  @override
  String get seenYourIpAddress => 'Il tuo indirizzo ip';

  @override
  String get seenOurRelay => 'Nostro relay';

  @override
  String get seenEveryRelay => 'Ogni relay';

  @override
  String get seenOnOnionEverythingLeaves =>
      'In onion tutto esce attraverso tor e il relay vede un nodo di uscita, mai te. In modalità relay la connessione va dritta al nostro relay: niente inoltra il tuo indirizzo e niente viene annotato, ma quella connessione possiamo vederla noi. In veloce ogni relay pubblico viene a sapere che ti sei connesso, ma non con chi parli né cosa hai detto.';

  @override
  String get seenYourContactGraph => 'La tua rete di contatti';

  @override
  String get seenKryfoDoesNotScan =>
      'Kryfo non scansiona i tuoi contatti. È proprio questo il punto. Qui non esiste nessun numero di telefono che possa trapelare.';

  @override
  String get seenIntroducer => 'Chi presenta';

  @override
  String get seenWhenAContactIntroduces =>
      'Quando un contatto ti presenta a qualcuno, quel contatto sa che ora voi due siete in contatto. Nessun altro lo sa. Il relay vede testo cifrato, e nessun server vede mai la rete dei contatti.';

  @override
  String get seenTheScamShield => 'Lo scudo antitruffa';

  @override
  String get seenRunsOnYourPhone =>
      'Funziona sul tuo telefono con regole incluse nell\'app. Niente rete, niente download di elenchi. Legge solo il primo messaggio di uno sconosciuto e non può vedere niente di ciò che ti manda un contatto.';

  @override
  String get seenBurnerRooms => 'Stanze effimere';

  @override
  String get seenRoomKeys => 'Chiavi stanza';

  @override
  String get seenYouJoinARoom =>
      'Entri in una stanza con una chiave creata apposta, quindi chi è dentro non scopre niente che funzioni altrove. Chi arriva dopo non riceve la cronologia. Alla scadenza le chiavi, i messaggi e i media vengono distrutti.';

  @override
  String get seenLinkPreviews => 'Anteprime dei link';

  @override
  String get seenOverTor => 'Via Tor';

  @override
  String get seenAPreviewIsFetched =>
      'L\'anteprima la scarica chi invia, via tor, e viaggia dentro il messaggio cifrato. Il telefono che riceve non fa nessuna richiesta. Il sito viene a sapere che qualcuno che usa tor ha chiesto una pagina, e nient\'altro. Non viene mai caricata nessuna immagine, e il link di uno sconosciuto resta testo semplice.';

  @override
  String get seenASeizedUnlockedPhone => 'Un telefono sequestrato e sbloccato';

  @override
  String get seenIfSomeoneHoldsYour =>
      'Se qualcuno ha in mano il tuo telefono sbloccato, legge i tuoi messaggi. Il blocco app, il PIN di cancellazione e l\'archiviazione cifrata aiutano prima di quel momento, non dopo.';

  @override
  String get seenTheCryptoItself => 'La crittografia in sé';

  @override
  String get seenTheRatchetAndStorage =>
      'I livelli del ratchet e dell\'archiviazione sono standard. Il livello che li unisce è nostro e nessuno di indipendente l\'ha revisionato. Consideralo un\'alpha, perché lo è.';

  @override
  String get seenOnion => 'Onion';

  @override
  String get seenRelay => 'Relay';

  @override
  String get seenFast => 'Veloce';

  @override
  String get settingsWipeKryfo => 'Cancellare Kryfo?';

  @override
  String get settingsIdentityMessagesContactsAnd =>
      'Identità, messaggi, contatti e impostazioni su questo telefono. Persi per sempre, a meno che tu non abbia un backup.';

  @override
  String get commonContinue => 'Continua';

  @override
  String settingsTypeWipeToConfirm(Object word) {
    return 'Scrivi «$word» per confermare';
  }

  @override
  String get settingsTheLastStepNothing =>
      'L\'ultimo passo. Non sopravvive niente.';

  @override
  String get settingsWipeWord => 'cancella';

  @override
  String get settingsWipeKryfo2 => 'Cancella Kryfo';

  @override
  String get settingsYourProtections => 'Le tue protezioni';

  @override
  String get settingsTorRouting => 'Instradamento tor';

  @override
  String get settingsConnecting => 'In connessione';

  @override
  String get settingsOffMode => 'Spento · modalità relay';

  @override
  String get settingsOffFastMode => 'Spento · modalità veloce';

  @override
  String get settingsAppLock => 'Blocco app';

  @override
  String get settingsBlockedByAndroid => 'Bloccate da android';

  @override
  String get settingsSpeedPrivacy => 'Velocità e privacy';

  @override
  String get settingsFast => 'Veloce';

  @override
  String get settingsRelay1Hop => 'Relay · 1 salto';

  @override
  String get settingsOnion3Hops => 'Onion · 3 salti';

  @override
  String get settingsBridges => 'Bridge';

  @override
  String get settingsForNetworksThatBlock => 'Per le reti che bloccano tor';

  @override
  String get settingsGettingMessages => 'Ricezione messaggi';

  @override
  String settingsPreviewHidden(Object deliveryModeName) {
    return '$deliveryModeName · anteprima nascosta';
  }

  @override
  String settingsPreviewShown(Object deliveryModeName) {
    return '$deliveryModeName · anteprima visibile';
  }

  @override
  String get settingsRunInBackground => 'Funziona in background';

  @override
  String get settingsSoMessagesArrive => 'Così i messaggi arrivano';

  @override
  String get settingsTransport => 'Trasporto';

  @override
  String get settingsWhatTheNetworkIs => 'Cosa sta facendo la rete';

  @override
  String get settingsBlocked => 'Bloccati';

  @override
  String get settingsAcceptIntroductions => 'Accetta presentazioni';

  @override
  String get settingsFriendsCanIntroduceYou =>
      'Gli amici possono presentarti i loro';

  @override
  String get settingsScamShield => 'Scudo antitruffa';

  @override
  String get settingsChecksStrangersOnYour =>
      'Controlla gli sconosciuti sul tuo telefono. Non ne esce niente';

  @override
  String get settingsBlockScreenshots => 'Blocca screenshot';

  @override
  String get settingsWholeAppHiddenFrom =>
      'Tutta l\'app nascosta dalle app recenti e dagli screenshot · vale dal prossimo avvio';

  @override
  String get settingsWholeAppHiddenFromRecentsAnd =>
      'Tutta l\'app nascosta dalle app recenti e dagli screenshot';

  @override
  String get settingsOnNextStart => 'Attivo · dal riavvio';

  @override
  String get settingsOffNextStart => 'Disattivato · dal riavvio';

  @override
  String get settingsLightTheme => 'Tema chiaro';

  @override
  String get settingsSameProtectionBrighter =>
      'Stessa protezione, più luminoso';

  @override
  String get settingsAppLock2 => 'Blocco app';

  @override
  String get settingsYourPinAndA => 'Il tuo PIN e la protezione avanzata';

  @override
  String get settingsPinWipePin => 'PIN · PIN di cancellazione';

  @override
  String get settingsBackUpIdentity => 'Backup dell\'identità';

  @override
  String get settingsEncryptedFile => 'File cifrato';

  @override
  String get settingsRestoreFromBackup => 'Ripristina da backup';

  @override
  String get settingsReplaceCurrent => 'Sostituisce l\'attuale';

  @override
  String get settingsDisguiseVoice => 'Camuffa la voce';

  @override
  String get settingsShiftsYourPitchBefore =>
      'Cambia il tono della voce prima che una nota vocale parta';

  @override
  String get settingsWhyKryfo => 'Perché Kryfo';

  @override
  String get settingsHowItProtectsYou => 'Come ti protegge';

  @override
  String get settingsResetMyInviteLink => 'Reimposta il mio link di invito';

  @override
  String get settingsOldLinksAndCodes =>
      'I vecchi link e codici smettono di funzionare, per tutti';

  @override
  String get settingsResetInviteLink => 'Reimpostare il link di invito?';

  @override
  String get settingsAnyoneWithAnOld =>
      'Chiunque abbia un vecchio codice o link non potrà più raggiungerti, su nessun percorso. Chi ce l\'ha ma non l\'ha mai usato avrà bisogno di uno nuovo da te. Contatti, chat e cronologia restano.';

  @override
  String get settingsReset => 'Reimposta';

  @override
  String get settingsInviteResetShareThe =>
      'Invito reimpostato · condividi il nuovo codice';

  @override
  String get settingsWhatWeCanSee => 'Cosa possiamo vedere';

  @override
  String get settingsTheHonestList => 'L\'elenco onesto';

  @override
  String get settingsVersion => 'Versione';

  @override
  String get settings030Alpha => '0.5.0 · alpha';

  @override
  String get settingsReportAnIssue => 'Segnala un problema';

  @override
  String get settingsBugOrSecurityFlaw => 'Bug o falla di sicurezza';

  @override
  String get settingsOpenSource => 'Open source';

  @override
  String get settingsLinkCopied => 'Link copiato';

  @override
  String get settingsTheOfflineMapIn =>
      'La mappa offline in Strumenti è disegnata con Natural Earth (pubblico dominio). I nomi delle località vengono da GeoNames, geonames.org, con licenza CC BY 4.0.';

  @override
  String get settingsNotIndependentlyAuditedPre =>
      'Nessun audit indipendente. Pre-alpha - va bene per i test, non ancora per usi ad alto rischio.';

  @override
  String get settingsDangerZone => 'Zona pericolosa';

  @override
  String get settingsWipeKryfoFromThis => 'Cancella Kryfo da questo telefono';

  @override
  String get shieldCheckedOnThisPhone =>
      'Controllato su questo telefono. Non è stato inviato niente da nessuna parte.';

  @override
  String get toolsMoreTools => 'Altri strumenti';

  @override
  String get toolsCleanAPhotoOr => 'Ripulisci foto o video';

  @override
  String get toolsOrShareOneTo =>
      'Oppure condividine uno con Kryfo dalla galleria';

  @override
  String get toolsMakeAPrivateQr => 'Crea un codice QR privato';

  @override
  String get toolsLinksWiFiContacts =>
      'Link, Wi-Fi, contatti e altro. Creati offline';

  @override
  String get toolsLockAFile => 'Proteggi un file';

  @override
  String get toolsWithAPasswordOpens =>
      'Con una password. Si apre ovunque con age';

  @override
  String get toolsOpenALockedFile => 'Apri un file protetto';

  @override
  String get toolsAnyAgeFileSomeone =>
      'Qualsiasi file .age che ti hanno mandato';

  @override
  String get toolsWorksOfflineNoContacts =>
      'Funziona offline · senza bisogno di contatti';

  @override
  String get toolsUsefulFrom => 'Utile fin';

  @override
  String get toolsTheFirstMinute => 'dal primo minuto.';

  @override
  String get toolsEverythingHereHappensOn =>
      'Qui tutto avviene su questo telefono. Non viene caricato niente, e nessun altro deve essere su Kryfo.';

  @override
  String get toolsWhatDoesThisPhoto => 'Cosa sa questa foto?';

  @override
  String get toolsPlacePhoneTime => 'Luogo · telefono · ora';

  @override
  String get toolsPickAPhotoAnd =>
      'Scegli una foto e guarda cosa rivela. Poi tieni una copia pulita.';

  @override
  String get toolsPickAPhoto => 'Scegli una foto';

  @override
  String get toolsVideo => 'Video';

  @override
  String get transportTransport => 'Trasporto';

  @override
  String get transportNothingHereLeavesThe =>
      'Niente di tutto questo lascia il telefono. È lo stesso stato che il motore usa per decidere cosa fare.';

  @override
  String get transportStayingAlive => 'Resta attivo';

  @override
  String get transportCanSend => 'Può inviare';

  @override
  String get commonYes => 'Sì';

  @override
  String get transportNotYet => 'Non ancora';

  @override
  String get transportOnline => 'Online';

  @override
  String get transportOffline => 'Offline';

  @override
  String get transportQueuedToSend => 'In coda per l\'invio';

  @override
  String get transportOnionPublished => 'Onion pubblicato';

  @override
  String transportYes(Object uploads) {
    return 'Sì ($uploads)';
  }

  @override
  String transportTryingS(Object pubFor) {
    return 'In prova da $pubFor s';
  }

  @override
  String transportBenchedS(Object r) {
    return 'In pausa per $r s';
  }

  @override
  String transportFails(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString errori',
      one: '$countString errore',
    );
    return '$_temp0';
  }

  @override
  String get transportOk => 'OK';

  @override
  String get transportRelaySubscriptions => 'Iscrizioni ai relay';

  @override
  String get transportLastSent => 'Ultimo invio';

  @override
  String get transportNever => 'Mai';

  @override
  String transportSAgo(Object sx) {
    return '$sx s fa';
  }

  @override
  String get transportLastReceived => 'Ultima ricezione';

  @override
  String transportSAgo2(Object rx) {
    return '$rx s fa';
  }

  @override
  String get transportWithNoContactsThe =>
      'Senza contatti l\'app non si iscrive a nessun indirizzo sui relay, quindi nessun messaggio può raggiungerti. Scansiona qualcuno per risolvere.';

  @override
  String get transportSendAnythingWaitingNow =>
      'Invia subito ciò che è in attesa';

  @override
  String get transportOff => 'Spento';

  @override
  String get transportStarting => 'Avvio';

  @override
  String get transportBootstrapped => 'Avviato';

  @override
  String get transportPublishingAddress => 'Pubblicazione indirizzo';

  @override
  String get transportReachable => 'Raggiungibile';

  @override
  String get transportOurRelayOnion => 'Nostro relay (onion)';

  @override
  String get transportNever2 => 'mai';

  @override
  String get transportJustNow => 'Adesso';

  @override
  String transportMAgo(Object inMinutes) {
    return '$inMinutes min fa';
  }

  @override
  String transportHAgo(Object inHours) {
    return '$inHours h fa';
  }

  @override
  String transportDAgo(Object inDays) {
    return '$inDays g fa';
  }

  @override
  String transportM(Object inMinutes) {
    return '$inMinutes min';
  }

  @override
  String transportHM(Object inHours, Object d) {
    return '$inHours h $d min';
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
  String get transportYesCheckedJustNow => 'Sì · controllato adesso';

  @override
  String transportNoLast(Object ago) {
    return 'No · ultimo $ago';
  }

  @override
  String get transportLastMessageIn => 'Ultimo ricevuto';

  @override
  String get transportBatteryExemption => 'Esenzione batteria';

  @override
  String get transportUnknown => 'Sconosciuto';

  @override
  String get transportExempt => 'Esente';

  @override
  String get transportNotExemptTapTo => 'Non esente · tocca per risolvere';

  @override
  String get transportProcessUp => 'Processo attivo';

  @override
  String get transportLastStop => 'Ultimo arresto';

  @override
  String transportEngine(Object mb, Object mb2) {
    return '$mb · motore $mb2';
  }

  @override
  String get transportLastRelayArrival => 'Ultimo arrivo dai relay';

  @override
  String get transportLastCheckIn => 'Ultimo controllo';

  @override
  String get transportNoneYet => 'Ancora nessuno';

  @override
  String get transportLastTorReconnect => 'Ultima riconnessione Tor';

  @override
  String get transportCatchUpByRelay => 'Recupero per relay';

  @override
  String get transportControlPort => 'Porta di controllo';

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
      other: '$dialsString tentativi',
      one: '$dialsString tentativo',
    );
    String _temp1 = intl.Intl.pluralLogic(
      timeouts,
      locale: localeName,
      other: '$timeoutsString timeout',
      one: '$timeoutsString timeout',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get transportJobRuns => 'Esecuzioni job';

  @override
  String transportLast(Object jobRuns, Object ago) {
    return '$jobRuns · ultima $ago';
  }

  @override
  String get transportQuietStretches => 'Periodi di silenzio';

  @override
  String get transportNone => 'Nessuno';

  @override
  String get transportClearThisRecord => 'Svuota questo registro';

  @override
  String get transportNothingYetThisProcess =>
      'Ancora niente in questo processo';

  @override
  String transportM2(Object mins) {
    return '$mins min';
  }

  @override
  String transportHM2(Object mins, Object mins2) {
    return '$mins h $mins2 min';
  }

  @override
  String transportTo(Object t, Object t2) {
    return 'da $t a $t2';
  }

  @override
  String vouchersVouchedBy(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Garantito da $countString',
      one: 'Garantito da',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperAtmosphere => 'Atmosfera';

  @override
  String get wallpaperJustForYouThey =>
      'Solo per te. Gli altri vedono il loro.';

  @override
  String get wallpaperYourPhoto => 'La tua foto';

  @override
  String get wallpaperFromYourPhotos => 'Dalle tue foto';

  @override
  String get wallpaperKeepIt => 'Tienilo';

  @override
  String get whyKryfoWhyKryfo => 'Perché Kryfo';

  @override
  String get whyKryfoKryfoKreeFoGreek =>
      'Kryfo · KRI-fo · in greco vuol dire nascosto.\nUn posto tranquillo per parlare, fatto perché nessuno guardi.';

  @override
  String get whyKryfoRoutedThroughTor => 'Instradato attraverso tor';

  @override
  String get whyKryfoByDefaultEveryMessage =>
      'Di default ogni messaggio viaggia attraverso tor - una catena di relay. Nessuno, né noi né la tua rete, può vedere con chi parli o dove ti trovi.';

  @override
  String get whyKryfoEndToEndEncrypted => 'Cifrato end-to-end';

  @override
  String get whyKryfoMessagesAreSealedWith =>
      'I messaggi sono sigillati con chiavi che avete solo tu e la persona con cui parli. Non potremmo leggerli nemmeno volendo.';

  @override
  String get whyKryfoNoServersHoldingYour =>
      'Nessun server che custodisce la tua vita';

  @override
  String get whyKryfoNoAccountNoPhone =>
      'Nessun account, nessun numero di telefono, nessun server centrale che conserva le tue chat. Vivono su questo telefono, cifrate a riposo.';

  @override
  String get whyKryfoNothingLeaks => 'Non trapela niente';

  @override
  String get whyKryfoNoReadReceiptsOr =>
      'Nessuna conferma di lettura o indicatore di scrittura consegnato a qualcuno, nessuna rubrica caricata. I metadati sono ciò che la maggior parte delle app lascia trapelare - Kryfo è fatto per non farlo.';

  @override
  String get whyKryfoVerifyItIsReally => 'Verifica che sia davvero chi dice';

  @override
  String get whyKryfoCompareASafetyNumber =>
      'Confronta un numero di sicurezza di persona o su un canale di cui ti fidi, così sai che nessuno si sta spacciando per il tuo contatto.';

  @override
  String get whyKryfoTheHonestPart => 'La parte onesta';

  @override
  String get whyKryfoKryfoIsPreAlpha =>
      'Kryfo è in pre-alpha e non è stato sottoposto ad audit. La crittografia è vera, ma nessun esperto esterno l\'ha ancora controllata, quindi consideralo un lavoro in corso, non ancora qualcosa a cui affidare la tua vita.';

  @override
  String get cleanerLocation => 'Posizione';

  @override
  String get cleanerAlreadyBlankedByAndroid => 'già azzerata da Android';

  @override
  String get cleanerPhoneModel => 'Modello telefono';

  @override
  String get cleanerTimeTaken => 'Ora dello scatto';

  @override
  String get cleanerSerialNumber => 'Numero di serie';

  @override
  String get cleanerOwnerName => 'Nome proprietario';

  @override
  String get cleanerHiddenThumbnail => 'Miniatura nascosta';

  @override
  String get cleanerContentCredentials => 'Credenziali del contenuto';

  @override
  String get cleanerDataAfterThePicture => 'Dati dopo l\'immagine';

  @override
  String cleaner1OtherField(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString altri campi',
      one: '$countString altro campo',
    );
    return '$_temp0';
  }

  @override
  String get lockWordsFourRandomWordsBeat =>
      'Quattro parole a caso battono una parola astuta.';

  @override
  String lockWordsTooShortAtLeast(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Troppo corta. Almeno $countString caratteri.',
      one: 'Troppo corta. Almeno $countString carattere.',
    );
    return '$_temp0';
  }

  @override
  String get lockWordsWeakWhoeverGetsThe =>
      'Debole. Chi ottiene il file può tentare alla velocità che vuole.';

  @override
  String get lockWordsFairLongerIsStronger =>
      'Discreta. Più è lunga, più è forte.';

  @override
  String get lockWordsStrongFourRandomWords =>
      'Forte. Quattro parole a caso battono una parola astuta.';

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
      other: '$countString metri',
      one: '$countString metro',
    );
    return '$_temp0';
  }

  @override
  String get photoStoryFarFromAnyTown => 'Lontano da ogni paese';

  @override
  String photoStoryNear(Object where) {
    return 'Vicino a $where';
  }

  @override
  String photoStoryAboutKmFrom(Object near, Object where) {
    return 'A circa $near km da $where';
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
  String get photoStoryNotAKindKryfo =>
      'Non è un tipo di file che Kryfo sa leggere.';

  @override
  String get photoStorySoItWillNot => 'Quindi non tira a indovinare.';

  @override
  String get photoStoryThisFileIsDamaged =>
      'Questo file è danneggiato o incompleto.';

  @override
  String get photoStoryKryfoCouldNotRead =>
      'Kryfo non è riuscito a leggerlo fino in fondo.';

  @override
  String get photoStoryWhereItWasRecorded => 'Dove è stato registrato';

  @override
  String get photoStoryWhereItWasTaken => 'Dove è stata scattata';

  @override
  String photoStoryLocation(Object coordsLine) {
    return 'Posizione: $coordsLine';
  }

  @override
  String photoStoryHeightAboveTheSea(Object fix) {
    return 'Altezza sul livello del mare: $fix m';
  }

  @override
  String get photoStoryLocationHiddenByAndroid =>
      'Posizione nascosta da Android';

  @override
  String get photoStoryAndroidBlanksItWhen =>
      'Android la azzera quando una foto viene scelta in questo modo. Se la condividi con Kryfo dalla galleria, spesso resta. Quella nella tua galleria potrebbe averla ancora.';

  @override
  String get photoStoryLocationBlankedByAndroid =>
      'Posizione: azzerata da Android prima che Kryfo la vedesse';

  @override
  String photoStoryF(Object r) {
    return 'f/$r';
  }

  @override
  String get photoStoryWhatTookIt => 'Dispositivo usato';

  @override
  String photoStoryPhoneOrCamera(Object phone) {
    return 'Telefono o fotocamera: $phone';
  }

  @override
  String get photoStoryWhenItWasRecorded => 'Quando è stato registrato';

  @override
  String get photoStoryToTheSecondWith => 'Al secondo, con il fuso orario';

  @override
  String get photoStoryToTheSecond => 'Al secondo';

  @override
  String photoStoryTime(Object dateFormat) {
    return 'Ora: $dateFormat';
  }

  @override
  String get photoStoryLens => 'Obiettivo';

  @override
  String photoStoryLens2(Object lens) {
    return 'Obiettivo: $lens';
  }

  @override
  String get photoStorySoftware => 'Software';

  @override
  String photoStorySoftware2(Object software) {
    return 'Software: $software';
  }

  @override
  String get photoStorySerialNumber => 'Numero di serie';

  @override
  String photoStorySerialNumber2(Object serial) {
    return 'Numero di serie: $serial';
  }

  @override
  String get photoStoryOwnerName => 'Nome proprietario';

  @override
  String photoStoryOwner(Object r) {
    return 'Proprietario: $r';
  }

  @override
  String get photoStoryHiddenThumbnail => 'Miniatura nascosta';

  @override
  String get photoStoryASmallCopyOf =>
      'Una piccola copia dell\'immagine dentro il file. Può mostrare ciò che un ritaglio ha tolto';

  @override
  String get photoStoryMakerNotes => 'Note del produttore';

  @override
  String get photoStoryMakerNotesABlock =>
      'Note del produttore: un blocco che solo il produttore sa leggere';

  @override
  String get photoStoryEditingHistory => 'Cronologia modifiche';

  @override
  String get photoStoryXmpEditingHistoryAnd =>
      'XMP: cronologia delle modifiche e tag';

  @override
  String get photoStoryCaptions => 'Didascalie';

  @override
  String get photoStoryIptcCaptionsAndCredits => 'IPTC: didascalie e crediti';

  @override
  String get photoStoryComment => 'Commento';

  @override
  String get photoStoryAWrittenComment => 'Un commento scritto';

  @override
  String get photoStoryContentCredentials => 'Credenziali del contenuto';

  @override
  String get photoStorySecondPicture => 'Seconda immagine';

  @override
  String get photoStoryASecondPictureInside =>
      'Una seconda immagine dentro il file';

  @override
  String get photoStoryMotionVideo => 'Video del movimento';

  @override
  String get photoStoryAShortVideoInside => 'Un breve video dentro il file';

  @override
  String get photoStorySaveTime => 'Ora salvataggio';

  @override
  String get photoStoryTheTimeItWas => 'L\'ora dell\'ultimo salvataggio';

  @override
  String get photoStoryTimeStamps => 'Date e ore';

  @override
  String get photoStoryCreationTimeStamps => 'Date e ore di creazione';

  @override
  String get photoStoryDataAfterThePicture => 'Dati dopo l\'immagine';

  @override
  String photoStoryDataAfterTheEnd(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Dati dopo la fine dell\'immagine: $countString byte',
      one: 'Dati dopo la fine dell\'immagine: $countString byte',
    );
    return '$_temp0';
  }

  @override
  String photoStoryTextField(Object k) {
    return 'Campo di testo: $k';
  }

  @override
  String photoStoryVideoTag(Object k) {
    return 'Tag video: $k';
  }

  @override
  String photoStoryAlso(Object k) {
    return 'Inoltre: $k';
  }

  @override
  String photoStoryCameraSettingsFlashFocus(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$countString impostazioni della fotocamera (flash, messa a fuoco, esposizione)',
      one:
          '$countString impostazione della fotocamera (flash, messa a fuoco, esposizione)',
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
      other: '$countString altri campi',
      one: '$countString altro campo',
    );
    return '$_temp0';
  }

  @override
  String get photoStoryCameraSettings => 'Impostazioni fotocamera';

  @override
  String photoStoryAccurateToAbout(Object metres) {
    return 'Precisa a circa $metres.';
  }

  @override
  String get photoStoryEnoughToFindThe => 'Basta per trovare la porta.';

  @override
  String get photoStoryEnoughToFindTheStreet => 'Basta per trovare la via.';

  @override
  String get photoStoryEnoughToFindTheArea => 'Basta per trovare la zona.';

  @override
  String get photoStoryItKnowsWhereYou => 'Sa dove eri.';

  @override
  String get photoStoryDownToTheBuilding => 'Fino all\'edificio.';

  @override
  String get photoStoryAndroidHidTheLocation =>
      'Android ha nascosto la posizione.';

  @override
  String get photoStoryTheOriginalMayStill =>
      'L\'originale potrebbe ancora contenerla.';

  @override
  String get photoStoryNoLocationInThis => 'Qui non c\'è nessuna posizione.';

  @override
  String get photoStoryItStillSaysPlenty => 'Dice comunque parecchio.';

  @override
  String get photoStoryThisOneKnowsNothing => 'Questo file non sa niente.';

  @override
  String get photoStoryNothingToRemove => 'Niente da rimuovere.';

  @override
  String get qrPayloadOpensALink => 'APRE UN LINK';

  @override
  String qrPayloadOpens(Object host) {
    return 'APRE $host';
  }

  @override
  String get qrPayloadShowsANote => 'MOSTRA UNA NOTA';

  @override
  String get qrPayloadScanToJoin => 'SCANSIONA PER CONNETTERTI';

  @override
  String qrPayloadScanToJoin2(Object oneLine) {
    return 'SCANSIONA PER CONNETTERTI · $oneLine';
  }

  @override
  String get qrPayloadANetworkNameIs =>
      'Un nome di rete ha al massimo 32 caratteri.';

  @override
  String get qrPayloadAWiFiPassword =>
      'Una password Wi-Fi ha almeno 8 caratteri.';

  @override
  String get qrPayloadSavesAContact => 'SALVA UN CONTATTO';

  @override
  String get qrPayloadWritesAnEmail => 'SCRIVE UN\'EMAIL';

  @override
  String get qrPayloadThatDoesNotLook => 'Non sembra un indirizzo email.';

  @override
  String get qrPayloadCallsANumber => 'CHIAMA UN NUMERO';

  @override
  String get qrPayloadWritesAText => 'SCRIVE UN SMS';

  @override
  String get qrPayloadOpensAMap => 'APRE UNA MAPPA';

  @override
  String get qrPayloadLatitudeRunsFrom90 =>
      'La latitudine va da -90 a 90, la longitudine da -180 a 180.';

  @override
  String get qrPayloadPayThisAddress => 'PAGA QUESTO INDIRIZZO';

  @override
  String get qrPayloadABitcoinAddressIs =>
      'Un indirizzo bitcoin contiene solo lettere e cifre.';

  @override
  String get qrPayloadTheAmountIsIn =>
      'L\'importo è in BTC, con al massimo 8 decimali.';

  @override
  String vouchTextAnd(Object names, Object names2) {
    return '$names e $names2';
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
      other: 'altre $restString persone che conosci',
      one: '$restString altra persona che conosci',
    );
    return '$names, $names2 e $_temp0';
  }

  @override
  String vouchTextVouchedBy(Object vouchNames) {
    return 'Garantito da $vouchNames';
  }

  @override
  String vouchTextIntroducedBy(Object vouchNames) {
    return 'Presentato da $vouchNames';
  }

  @override
  String vouchTextThisSharesSAddress(Object a, Object b) {
    return 'Così condividi l\'indirizzo di $a con $b';
  }

  @override
  String get bootFailedKryfoCouldNotStart => 'Kryfo non è riuscito ad avviarsi';

  @override
  String get bootFailedThisIsAFault =>
      'È un guasto su questo dispositivo, non della rete. Tor non c\'entra.';

  @override
  String get kryfoLinkTextThatLinkIsNot => 'Kryfo non sa leggere questo link';

  @override
  String kryfoLinkTextAdd(Object who) {
    return 'Aggiungere $who?';
  }

  @override
  String kryfoLinkTextThisIsAnInvite(Object who) {
    return 'Questo è un invito a parlare con $who. Aggiungi solo se sai da dove viene il link.';
  }

  @override
  String get kryfoLinkTextAddThem => 'Aggiungi';

  @override
  String get kryfoLinkTextNotNow => 'Non ora';

  @override
  String kryfoLinkTextJoin(Object roomName) {
    return 'Entra in $roomName';
  }

  @override
  String get kryfoLinkTextKryfoLink => 'Link Kryfo';

  @override
  String kryfoLinkTextAdd2(Object who) {
    return 'Aggiungi $who';
  }

  @override
  String get kryfoLinkTextBurnerRoom => 'STANZA EFFIMERA';

  @override
  String get kryfoLinkTextThisRoomHasClosed => 'Questa stanza è chiusa';

  @override
  String kryfoLinkTextClosesIn(Object time) {
    return 'Si chiude tra $time';
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
      other: 'Si chiude tra $time · fino a $capString',
    );
    return '$_temp0';
  }

  @override
  String get kryfoLinkTextJoin2 => 'Entra';

  @override
  String get kryfoLinkTextYouJoinUnderA =>
      'Entri con una chiave creata per questa stanza. Nessuno lì dentro vede il tuo ID Kryfo.';

  @override
  String get linkStubFetchedOverTorBy =>
      'Scaricata via tor · dal tuo dispositivo';

  @override
  String get linkStubFetchedOverTorByTheirDevice =>
      'Scaricata via tor · dal suo dispositivo';

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
  String get mediaBubblesAudioUnavailable => 'Audio non disponibile';

  @override
  String get mediaBubblesHidden => 'Nascosto';

  @override
  String get mediaBubblesMicPermissionNeeded =>
      'Serve il permesso del microfono';

  @override
  String get mediaBubblesReleaseToCancel => 'Rilascia per annullare';

  @override
  String get mediaBubblesVoiceHiddenSlideTo =>
      'Voce nascosta · scorri per annullare';

  @override
  String get mediaBubblesSlideToCancel => 'Scorri per annullare';

  @override
  String get mediaBubblesSendPhoto => 'Invia foto';

  @override
  String get mediaBubblesAddACaption => 'Aggiungi didascalia…';

  @override
  String get motionStandby => 'IN ATTESA';

  @override
  String get motionConnecting => 'CONNESSIONE';

  @override
  String get motionBuilding => 'COSTRUZIONE';

  @override
  String get motionPublishing => 'PUBBLICAZIONE';

  @override
  String get motionReady => 'PRONTO';

  @override
  String get motionPreparingToConnect => 'Preparazione alla connessione';

  @override
  String get motionFindingAPrivatePath => 'Ricerca di un percorso privato';

  @override
  String get motionCarvingThePath => 'Tracciamento del percorso';

  @override
  String get motionAnnouncingYourArrival => 'Annuncio del tuo arrivo';

  @override
  String get motionYouReAnonymous => 'Anonimato attivo';

  @override
  String get motionTorIsStartingIn =>
      'Tor si sta avviando in background. Questo grafico si illumina mentre la connessione prende forma.';

  @override
  String get motionMakingAFreshRoute =>
      'Creazione di un nuovo percorso attraverso relay anonimi.';

  @override
  String get motionBouncingThroughRelaysSo =>
      'Rimbalzo tra i relay perché nessuno possa risalire a te.';

  @override
  String get motionTellingTheNetworkYou =>
      'Comunico alla rete che sei online — senza rivelare dove.';

  @override
  String get motionYourIpIsHidden =>
      'Il tuo ip è nascosto. Solo chi ha il tuo Kryfo può raggiungerti.';

  @override
  String get motionBuilding2 => 'costruzione';

  @override
  String get motionOpen => 'aperto';

  @override
  String get motionLive => 'attivo';

  @override
  String motionCircuit(Object circuit) {
    return 'Circuito · *$circuit*';
  }

  @override
  String get motionDelivered => 'Consegnato';

  @override
  String get motionSent => 'Inviato';

  @override
  String get motion1Hop => '1 salto';

  @override
  String get motion3Hops => '3 salti';

  @override
  String get movedStripThisKryfoHasMoved =>
      'Questo Kryfo si è trasferito su un altro dispositivo. Niente di ciò che viene inviato da qui arriva a nessuno.';

  @override
  String get navBarChats => 'Chat';

  @override
  String get navBarTools => 'Strumenti';

  @override
  String get navBarSupport => 'Sostieni';

  @override
  String get navBarMe => 'Io';

  @override
  String get pairCodePanelPuttingYourInviteIn => 'Preparazione del tuo invito';

  @override
  String get pairCodePanelYourInviteIsNot =>
      'Il tuo invito non è ancora pronto';

  @override
  String get pairCodePanelReadSixDigitsOut =>
      'Leggi sei cifre ad alta voce e l\'altra persona potrà aggiungerti. Non serve scambiarsi nient\'altro.';

  @override
  String get pairCodePanelWorking => 'In corso';

  @override
  String get pairCodePanelOrMakeASix =>
      'Oppure crea un codice di sei cifre da leggere';

  @override
  String get pairCodePanelCodeCopied => 'Codice copiato';

  @override
  String pairCodePanelBurnsIn(Object mm, Object ss) {
    return 'Sparisce tra $mm:$ss';
  }

  @override
  String get pairCodePanelTheyTapAddChoose =>
      'L\'altra persona tocca aggiungi, sceglie codice e scrive queste cifre.';

  @override
  String get pairCodePanelTheyOpenKryfoTap =>
      'L\'altra persona apre Kryfo, tocca aggiungi, sceglie codice di abbinamento e scrive queste sei cifre. Creane uno nuovo per la persona successiva.';

  @override
  String get pairCodePanelYourWords => 'Le tue tre parole';

  @override
  String pinsPinnedMessages(Object count) {
    return 'Messaggi fissati · $count';
  }

  @override
  String get pinsPinnedMessages2 => 'Messaggi fissati';

  @override
  String get pinsPhoto => 'Foto';

  @override
  String get pinsVoiceMessage => 'Messaggio vocale';

  @override
  String get pinsMessage => 'Messaggio';

  @override
  String pinsToday(Object hm) {
    return 'Oggi · $hm';
  }

  @override
  String get pinsPinned => 'Fissato';

  @override
  String pinsOf(Object pinsLength, Object kMaxPins) {
    return '$pinsLength di $kMaxPins';
  }

  @override
  String get pinsNothingPinnedHereYet =>
      'Ancora niente di fissato qui. Tieni premuto un messaggio e scegli Fissa: resterà qui per tutti nella chat.';

  @override
  String get pinsJump => 'Vai';

  @override
  String get pinsUnpin => 'Sfissa';

  @override
  String powNoteFirstMessageToSomeone(int secs) {
    final intl.NumberFormat secsNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String secsString = secsNumberFormat.format(secs);

    return 'Primo messaggio a una persona nuova · prova che è autentico · $secsString s';
  }

  @override
  String powNoteFirstMessageSlow(int secs) {
    final intl.NumberFormat secsNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String secsString = secsNumberFormat.format(secs);

    return 'Primo messaggio a una persona nuova · prova che è autentico · $secsString s · fino a un minuto su un telefono lento';
  }

  @override
  String previewStripFetchedOverTor(Object domainOf) {
    return '$domainOf · scaricata via tor';
  }

  @override
  String get previewStripDropThePreview => 'Togli l\'anteprima';

  @override
  String get previewStripAddPreview => 'Aggiungi anteprima';

  @override
  String get previewStripFetchingOverTor => 'Scaricamento via tor…';

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
      'Niente scorciatoie, niente tracce';

  @override
  String get torBootSplashTheNetworkThatKeeps =>
      'La rete che protegge la tua privacy si sta scaldando';

  @override
  String get torBootSplashMadeOnThisPhone =>
      'Creato su questo telefono. Non viene inviato niente da nessuna parte.';

  @override
  String get torBootSplashFirstLaunchTakesA =>
      'Il primo avvio richiede un momento · solo all\'accensione';

  @override
  String get videoBubbleNothingHereOpensThat =>
      'Qui niente può aprirlo · lo condivido';

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
  String get notificationsChannelName => 'Messaggi';

  @override
  String get cameraClose => 'Chiudi';

  @override
  String get cameraFlash => 'Flash';

  @override
  String get cameraPhoto => 'Foto';

  @override
  String get cameraVideo => 'Video';

  @override
  String get cameraRetake => 'Rifai';

  @override
  String get seenIntroductions => 'Presentazioni';

  @override
  String get donateAddress => 'Indirizzo';

  @override
  String get donateCopy => 'Copia';

  @override
  String get donateDone => 'Fatto';

  @override
  String get donateTierSupporter => 'Sostenitore';

  @override
  String get donateTierPatron => 'Mecenate';

  @override
  String get donateTierGuardian => 'Custode';

  @override
  String get chatBlock => 'Blocca';

  @override
  String get chatDecline => 'Rifiuta';

  @override
  String get chatAccept => 'Accetta';

  @override
  String get bridgesConnecting => 'In connessione';

  @override
  String get bridgesSavedTag => 'Salvato';

  @override
  String get restoreMade => 'Creato';

  @override
  String get restoreContacts => 'Contatti';

  @override
  String get restoreMessages => 'Messaggi';

  @override
  String get restoreAttachments => 'Allegati';

  @override
  String get restoreHiddenChats => 'Chat nascoste';

  @override
  String get restoreHiddenFollow =>
      'Le tue chat nascoste, con un nuovo PIN delle chat nascoste che sceglierai alla fine.';

  @override
  String get restoreChooseHiddenPin =>
      'Questo backup contiene chat nascoste. Scegli un PIN delle chat nascoste per loro.';

  @override
  String get restoreHiddenLockFirst =>
      'Le chat nascoste hanno bisogno del blocco app, quindi prima Kryfo riceve un PIN tutto suo.';

  @override
  String get shieldBlock => 'Blocca';

  @override
  String get shieldDelete => 'Elimina';

  @override
  String get shieldIgnore => 'Ignora';

  @override
  String get profileIdentity => 'Identità';

  @override
  String get avatarPickerShape => 'Forma';

  @override
  String get avatarPickerColour => 'Colore';

  @override
  String get avatarPickerTurn => 'Ruota';

  @override
  String get transportStatus => 'Stato';

  @override
  String get transportBootstrap => 'Avvio';

  @override
  String get transportNetwork => 'Rete';

  @override
  String get transportConnectivity => 'Connettività';

  @override
  String get transportRelays => 'Relay';

  @override
  String get transportTraffic => 'Traffico';

  @override
  String get transportContacts => 'Contatti';

  @override
  String get transportKnown => 'Noti';

  @override
  String get transportListening => 'In ascolto';

  @override
  String get transportMemory => 'Memoria';

  @override
  String get settingsConnected => 'Connesso';

  @override
  String get settingsScreenshots => 'Screenshot';

  @override
  String get settingsBlocked2 => 'Bloccati';

  @override
  String get settingsAllowed => 'Consentiti';

  @override
  String get settingsOn => 'Attivo';

  @override
  String get settingsOff => 'Disattivato';

  @override
  String get settingsNotifications => 'Notifiche';

  @override
  String get settingsPrivacy => 'Privacy';

  @override
  String get settingsSecurity => 'Sicurezza';

  @override
  String get settingsBackup => 'Backup';

  @override
  String get settingsVoice => 'Voce';

  @override
  String get settingsAbout => 'Informazioni';

  @override
  String get wallpaperGradients => 'Sfumature';

  @override
  String get wallpaperPatterns => 'Motivi';

  @override
  String get wallpaperMoods => 'Umori';

  @override
  String get confirmSheetKeep => 'Tieni';

  @override
  String get confirmSheetSave => 'Salva';

  @override
  String get confirmSheetCancel => 'Annulla';

  @override
  String bridgesSaved(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString bridge',
      one: '$countString bridge',
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

    return '$goodString accettati, $badString non riconosciuti';
  }

  @override
  String get languageTitle => 'Lingua';

  @override
  String get languageMatchPhone => 'Come il telefono';

  @override
  String languageMatchPhoneValue(Object language) {
    return 'Come il telefono ($language)';
  }

  @override
  String get languageRedrawLine =>
      'Kryfo si ridisegna nella nuova lingua e si apre sulle tue chat.';

  @override
  String languageButton(Object language) {
    return 'Lingua: $language';
  }

  @override
  String get androidServiceTitle => 'Kryfo è attivo';

  @override
  String get androidServiceText =>
      'La tua linea cifrata resta aperta perché arrivino i messaggi';

  @override
  String get androidChannelName => 'Connessione attiva';

  @override
  String get androidChannelDescription =>
      'Tiene Kryfo connesso perché i messaggi cifrati arrivino mentre è chiuso. Se lo disattivi, la consegna si ferma.';

  @override
  String get videoViewerPlay => 'Riproduci';

  @override
  String get videoViewerPause => 'Pausa';

  @override
  String get videoViewerPlayAgain => 'Riproduci di nuovo';

  @override
  String get videoViewerCannotPlay =>
      'Questo telefono non riesce a riprodurre il video qui.';

  @override
  String get videoViewerOpenElsewhere => 'Apri in un’altra app';

  @override
  String get photoKnowsLookedFor => 'Cercato';

  @override
  String get photoKnowsNotInIt => 'Assente';

  @override
  String get languageNameEn => 'Inglese';

  @override
  String get languageNameDe => 'Tedesco';

  @override
  String get languageNameFr => 'Francese';

  @override
  String get languageNameEs => 'Spagnolo';

  @override
  String get languageNamePt => 'Portoghese (Brasile)';

  @override
  String get languageNameIt => 'Italiano';

  @override
  String get languageNameRu => 'Russo';

  @override
  String get languageNameUk => 'Ucraino';

  @override
  String get languageNameTr => 'Turco';

  @override
  String get languageNameZh => 'Cinese (semplificato)';

  @override
  String get languageNameZhHant => 'Cinese (tradizionale)';

  @override
  String get languageNameVi => 'Vietnamita';

  @override
  String get languageNameId => 'Indonesiano';

  @override
  String get languageNameFa => 'Persiano';

  @override
  String get languageNameAr => 'Arabo';

  @override
  String get languageLaterLine =>
      'Puoi cambiarla quando vuoi nelle impostazioni.';

  @override
  String get pollAttach => 'Sondaggio';

  @override
  String get pollNewTitle => 'Nuovo sondaggio';

  @override
  String get pollQuestionHint => 'Chiedi qualcosa al gruppo';

  @override
  String get pollOptionsLabel => 'Opzioni';

  @override
  String pollOptionHint(Object n) {
    return 'Opzione $n';
  }

  @override
  String get pollAddOption => 'Aggiungi un’opzione';

  @override
  String get pollMaxLine => 'Al massimo dodici opzioni.';

  @override
  String get pollMultiple => 'Più risposte';

  @override
  String get pollMultipleLine => 'Si può sceglierne più di una.';

  @override
  String get pollSend => 'Invia sondaggio';

  @override
  String get pollKind => 'Sondaggio';

  @override
  String get pollKindMulti => 'Sondaggio · più risposte';

  @override
  String get pollKindClosed => 'Risultato finale';

  @override
  String pollVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count voti',
      one: '$count voto',
      zero: 'Ancora nessun voto',
    );
    return '$_temp0';
  }

  @override
  String get pollVote => 'Vota';

  @override
  String get pollTakeBack => 'Ritira il mio voto';

  @override
  String get pollClose => 'Chiudi sondaggio';

  @override
  String get pollCloseTitle => 'Chiudere questo sondaggio?';

  @override
  String get pollCloseLine =>
      'Tutti vedono il risultato finale e nessuno potrà più votare.';

  @override
  String get pollCloseYes => 'Chiudilo';

  @override
  String pollPreview(Object question) {
    return 'Sondaggio: $question';
  }

  @override
  String get pollWhoVoted => 'Chi ha votato';

  @override
  String get pollNobody => 'Ancora nessuno';

  @override
  String get pollYou => 'Tu';

  @override
  String pollOptionA11y(Object option, Object share) {
    return '$option, $share';
  }

  @override
  String get pollPickOne => 'Scegline una';

  @override
  String get pollPickSeveral => 'Scegline una o più';

  @override
  String get searchOpen => 'Cerca';

  @override
  String get searchHint => 'Cerca in chat e messaggi';

  @override
  String get searchFilterAll => 'Tutto';

  @override
  String get searchFilterPhotos => 'Foto';

  @override
  String get searchFilterVideos => 'Video';

  @override
  String get searchFilterFiles => 'File';

  @override
  String get searchFilterLinks => 'Link';

  @override
  String get searchChats => 'Chat';

  @override
  String get searchMessages => 'Messaggi';

  @override
  String get searchIntroTitle => 'Cerca nelle tue chat';

  @override
  String get searchIntroLine =>
      'Nomi, parole, foto, file e link. La ricerca avviene su questo telefono e non invia niente da nessuna parte.';

  @override
  String get searchNothing => 'Nessun risultato';

  @override
  String get searchNothingLine => 'Prova un’altra parola o un altro filtro.';

  @override
  String searchMatches(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count risultati',
      one: '$count risultato',
    );
    return '$_temp0';
  }

  @override
  String searchMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'altri $count',
      one: '$count altro',
    );
    return '$_temp0';
  }

  @override
  String searchFilling(Object share) {
    return 'Aggiungo i messaggi più vecchi · $share';
  }

  @override
  String get searchClear => 'Cancella';

  @override
  String get handleShowInSearch => 'Mostrami nella ricerca';

  @override
  String get handleShowInSearchLine =>
      'Chiunque può trovare questo nome utente e scriverti.';

  @override
  String handleShownAs(Object name) {
    return 'Mostrato come $name';
  }

  @override
  String get handleNameInSearch => 'Nome nella ricerca';

  @override
  String get handleNameInSearchLine =>
      'Facoltativo. Appare accanto al tuo nome utente quando qualcuno cerca. Chiunque può trovare questo nome utente e scriverti.';

  @override
  String get handleNameHint => 'Il tuo nome, o lascia vuoto';

  @override
  String get handleShowMe => 'Mostrami';

  @override
  String get handleSearchOff => 'Non sei più nella ricerca';

  @override
  String handleSearchOn(Object handle) {
    return 'Sei nella ricerca come @$handle';
  }

  @override
  String get handleRegistryFailed =>
      'Il registro non ha risposto. Riprova tra un minuto.';

  @override
  String get handleCheckClock =>
      'Controlla data e ora del telefono, poi riprova.';

  @override
  String get searchPeople => 'Persone';

  @override
  String searchPeopleAsk(Object query) {
    return 'Cerca «$query» tra i nomi utente pubblici';
  }

  @override
  String get searchPeopleLine =>
      'Chiesto tramite Tor. Il registro non ne tiene traccia.';

  @override
  String get searchPeopleNone => 'Nessun nome utente pubblico corrisponde';

  @override
  String get searchPeopleOffline => 'Tor non è ancora pronto';

  @override
  String get searchPeopleBusy =>
      'Troppe ricerche in questo momento. Riprova tra poco.';

  @override
  String get searchPeopleUnreachable => 'Il registro non ha risposto';

  @override
  String get peopleVerified => 'Nome utente verificato';

  @override
  String get peopleAdd => 'Aggiungi';

  @override
  String peopleFingerprint(Object fp) {
    return 'Impronta della chiave · $fp';
  }

  @override
  String get peopleFingerprintLine =>
      'Controlla che corrisponda a quella che vede nella sua app.';

  @override
  String get peopleAdding => 'Aggiungo…';

  @override
  String handleNobodyHasClaimed(Object handle) {
    return 'Nessuno ha registrato $handle';
  }

  @override
  String get handleThatHandleIsTaken => 'Quel nome utente è già preso';

  @override
  String get pinPickDifferent => 'Scegli un altro PIN';

  @override
  String get settingsKeptOnWhileLock =>
      'Resta attivo finché il blocco app è attivo.';

  @override
  String get lockFingerAfterPin =>
      'Digita il PIN una volta per usare di nuovo l\'impronta.';

  @override
  String get pinsAdvanced => 'Protezione avanzata';

  @override
  String get pinsAdvancedLine =>
      'Per quando qualcuno ti costringe a sbloccare il telefono.';

  @override
  String get pinsWipeLine =>
      'Digitato nella schermata di blocco, cancella Kryfo da questo telefono.';

  @override
  String get pinsDecoyPin => 'PIN esca';

  @override
  String get pinsDecoyLine => 'Apre un Kryfo vuoto, come appena installato.';

  @override
  String get pinsSetADecoyPin => 'Imposta un PIN esca';

  @override
  String get pinsChangeDecoyPin => 'Cambia PIN esca';

  @override
  String get pinsRemoveTheDecoyPin => 'Rimuovere il PIN esca?';

  @override
  String get pinsTheDecoyGoes => 'Il Kryfo vuoto che apre se ne va con lui.';

  @override
  String get pinsTurnOffWithDecoy =>
      'Tutti i PIN vengono rimossi, e con loro l\'esca, il suo Kryfo e tutte le chat nascoste. Chiunque abbia in mano il tuo telefono apre Kryfo al posto tuo.';

  @override
  String get pinsHowThisWorks => 'Come funziona';

  @override
  String get flowEnterYourPin => 'Inserisci il tuo PIN';

  @override
  String get flowEnterYourPinLine => 'Quello che apre Kryfo.';

  @override
  String get flowWipeTitle => 'Un PIN di cancellazione';

  @override
  String get flowWipe1 =>
      'Digitato nella schermata di blocco al posto del tuo PIN, cancella Kryfo da questo telefono e lo chiude. Per chi guarda, l\'app si è semplicemente fermata.';

  @override
  String get flowWipe2 =>
      'Porta con sé ogni chat e la tua identità, e l\'esca se ce l\'hai.';

  @override
  String get flowWipeChoose => 'Scegli un PIN di cancellazione';

  @override
  String get flowWipeDone => 'PIN di cancellazione impostato';

  @override
  String get flowWipeDoneLine =>
      'Nulla nella schermata di blocco mostra che esiste.';

  @override
  String get flowDecoyTitle => 'Un PIN esca';

  @override
  String get flowDecoy1 => 'Apre un Kryfo vuoto, come appena installato.';

  @override
  String get flowDecoyFinger =>
      'La tua impronta apre il tuo vero Kryfo. Se qualcuno potesse costringerti a usarla, disattiva l\'impronta.';

  @override
  String get flowDecoyDigits =>
      'Usa lo stesso numero di cifre del tuo PIN, perché chi guarda può contare i puntini.';

  @override
  String get flowDecoyShade =>
      'Le notifiche già nella tendina sono già state viste. Finché l\'esca è aperta, non ne compaiono di nuove.';

  @override
  String get flowDecoyChoose => 'Scegli un PIN esca';

  @override
  String get flowDecoyDone => 'PIN esca impostato';

  @override
  String get flowDecoyDoneLine =>
      'Digitalo nella schermata di blocco per aprire il Kryfo vuoto. Per uscirne, passa a un\'altra app e inserisci il tuo PIN.';

  @override
  String get flowLaw =>
      'In alcuni paesi rifiutarsi di sbloccare un telefono o nascondere dati alle autorità è di per sé un reato. Informati sulla legge dei posti in cui viaggi.';

  @override
  String get howWipe =>
      'Digitato nella schermata di blocco, il PIN di cancellazione cancella ogni chat, la tua identità e ogni esca, poi chiude Kryfo. Funziona anche mentre il tastierino è bloccato dopo tentativi sbagliati.';

  @override
  String get howDecoy =>
      'Il PIN esca apre un secondo Kryfo, vuoto, con tre parole sue. I messaggi al tuo vero Kryfo continuano ad arrivare sotto, in silenzio. Per uscire dall\'esca, passa a un\'altra app e inserisci il tuo PIN.';

  @override
  String get flowNotSet => 'Non è stato possibile impostarlo. Riprova.';

  @override
  String get pinsHiddenChats => 'Chat nascoste';

  @override
  String get pinsHiddenLine =>
      'Le chat scelte restano fuori vista finché non inserisci il PIN delle chat nascoste: non nell\'elenco, non nella ricerca, nessuna notifica.';

  @override
  String get pinsSetUp => 'Configura';

  @override
  String get pinsChangeHiddenPin => 'Cambia PIN delle chat nascoste';

  @override
  String get pinsHideMoreChats => 'Nascondi altre chat';

  @override
  String get pinsRemoveHiddenChats => 'Rimuovi chat nascoste';

  @override
  String get pinsRemoveHiddenTitle => 'Rimuovere le chat nascoste?';

  @override
  String get pinsRemoveHiddenLine =>
      'Tornano nel tuo elenco delle chat, e il PIN delle chat nascoste non apre più nulla.';

  @override
  String get pinsTurnOffHiddenFirst =>
      'Le chat nascoste hanno bisogno del blocco app. Rimuovile prima, e torneranno nel tuo elenco delle chat.';

  @override
  String get flowVaultTitle => 'Chat nascoste';

  @override
  String get flowVault1 =>
      'Scegli chat e gruppi da nascondere. Il tuo PIN apre Kryfo senza di loro. Un PIN delle chat nascoste apre tutto, chat nascoste comprese.';

  @override
  String get flowVault2 =>
      'Finché sono fuori vista, non mandano mai notifiche né mostrano contatori. I loro messaggi continuano ad arrivare e aspettano, sigillati, il tuo PIN delle chat nascoste.';

  @override
  String get flowVaultFinger =>
      'La tua impronta apre Kryfo senza le chat nascoste.';

  @override
  String get flowVaultDigits =>
      'Dai anche al tuo PIN sei cifre o più, perché chi guarda può contare i puntini.';

  @override
  String get flowVaultReplace =>
      'Questo sostituisce tutte le chat nascoste che questo telefono ha già.';

  @override
  String get flowVaultChoose => 'Scegli un PIN delle chat nascoste';

  @override
  String get flowVaultChooseLine => 'Sei cifre o più.';

  @override
  String get flowEnterHiddenPinLine => 'Quello che apre le tue chat nascoste.';

  @override
  String get flowVaultForgetTitle => 'Ricorda questo PIN';

  @override
  String get flowVaultForget =>
      'Se dimentichi questo PIN, le tue chat nascoste sono perse per sempre. Nessuno può recuperarle, nemmeno noi.';

  @override
  String get flowVaultForgetOk => 'Ho capito';

  @override
  String get flowVaultPickTitle => 'Scegli le chat da nascondere';

  @override
  String get flowVaultPickLine =>
      'Lasciano ora il tuo elenco delle chat. Il tuo PIN delle chat nascoste le riporta in vista.';

  @override
  String flowVaultPickButton(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Nascondi $countString chat',
      one: 'Nascondi $countString chat',
      zero: 'Non nascondere niente per ora',
    );
    return '$_temp0';
  }

  @override
  String get flowVaultPickEmpty => 'Ancora nessuna chat da nascondere.';

  @override
  String get flowVaultBackupTitle => 'Fare un backup adesso?';

  @override
  String get flowVaultBackupLine =>
      'Un backup fatto adesso contiene anche le tue chat nascoste, con una passphrase tutta sua. Se dimentichi il PIN delle chat nascoste, è l\'unico modo per ritrovarle.';

  @override
  String get flowVaultBackupNow => 'Fai un backup';

  @override
  String get flowVaultNotNow => 'Non ora';

  @override
  String get flowVaultDone => 'Chat nascoste configurate';

  @override
  String get flowVaultDoneLine =>
      'Digita il tuo PIN delle chat nascoste nella schermata di blocco per vederle. Passa a un\'altra app e tornano fuori vista.';

  @override
  String get flowVaultChanged => 'PIN delle chat nascoste cambiato';

  @override
  String get flowVaultChangedLine =>
      'Le tue chat nascoste si aprono con il nuovo. Il vecchio ora non apre più nulla.';

  @override
  String get howVault =>
      'Il tuo PIN delle chat nascoste apre Kryfo con le chat nascoste; il tuo PIN e la tua impronta, senza. Configurare di nuovo le chat nascoste sostituisce quelle che questo telefono ha. Se dimentichi il PIN delle chat nascoste, sono perse per sempre.';

  @override
  String get chatHide => 'Nascondi chat';

  @override
  String get groupHide => 'Nascondi gruppo';

  @override
  String get chatHidden => 'Nascosta';

  @override
  String get chatHiddenToast => 'Nascosta dal tuo elenco delle chat';

  @override
  String get chatShowInList => 'Mostra nell\'elenco delle chat';

  @override
  String get stickerOpen => 'Sticker';

  @override
  String get stickerRecent => 'Recenti';

  @override
  String stickerA11y(String emoji) {
    return 'Sticker $emoji';
  }

  @override
  String get stickerRemoveRecent => 'Rimuovi dai recenti';

  @override
  String get stickerCouldNotLoad => 'Impossibile caricare gli sticker';

  @override
  String get stickerLabel => 'Sticker';

  @override
  String get stickerNewer => 'Da un Kryfo più recente';

  @override
  String get devLinkMismatch =>
      'Questo link dice di essere Marios, ma la sua chiave non corrisponde. Non è stato aggiunto.';

  @override
  String get devName => 'Marios';

  @override
  String get devRowTitle => 'Marios · ha creato Kryfo';

  @override
  String get devWelcome =>
      'Ciao, sono Marios, sviluppo Kryfo. Scrivimi di tutto: bug, idee, domande. Leggo tutto.';

  @override
  String get devPinned => 'Integrato in Kryfo';

  @override
  String get devAnonymous => 'Anonimo';

  @override
  String get devAboutLine =>
      'La chiave di Marios è integrata in Kryfo. Ogni suo messaggio viene controllato con essa, quindi nessun altro può scrivere al posto suo.';

  @override
  String get devKeyLabel => 'La sua chiave';

  @override
  String get devDeleteLine =>
      'Tutti i messaggi vengono eliminati, e la chat non tornerà.';

  @override
  String get devDeleteLineAnon =>
      'Tutti i messaggi e il nome creato per questa chat vengono eliminati, e la chat non tornerà.';

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
  String get settingsWriteToMarios => 'Scrivi a Marios';

  @override
  String get settingsWriteToMariosHint => 'Bug, idee, domande';

  @override
  String get seenDevChat => 'La chat con Marios';

  @override
  String get seenDevChatCell => 'Se scrivi';

  @override
  String get seenDevChatLine =>
      'Niente finché non scrivi. Poi quello che invii, e le tue tre parole, a meno che tu non scriva in forma anonima.';

  @override
  String get devWriteAnonymously => 'Scrivi in forma anonima';

  @override
  String get devUseMyWords => 'Usa le mie tre parole';

  @override
  String get devWhoSeesWhat => 'Come funziona';

  @override
  String get devWhoWords =>
      'Con le tue tre parole è una chat come le altre: Marios può risponderti, e il tuo volto e il tuo badge sostenitore restano con te.';

  @override
  String get devWhoAnon =>
      'Se scrivi in forma anonima, Kryfo crea un nuovo nome e nuove chiavi solo per questa chat. Restano su questo telefono e non vengono mai usati altrove.';

  @override
  String get devWhoNothingYet =>
      'Niente lascia il tuo telefono finché non invii il primo messaggio.';

  @override
  String get devWhoChoiceStays => 'La tua scelta resta legata a questa chat.';

  @override
  String get devKeyCheckFailed =>
      'Impossibile verificare la chiave di Marios. Non è stato inviato nulla.';

  @override
  String get devLockLine =>
      'Marios li leggerà. Potrai scrivere ancora appena ti risponde.';

  @override
  String get devNewKey => 'Marios ha una nuova chiave';

  @override
  String get devStartNewChat => 'Inizia una nuova chat';

  @override
  String get devKeyRetired =>
      'Questa chiave è stata ritirata. Qui non si può più inviare né ricevere nulla.';

  @override
  String get devNamelessLine =>
      'Il nome creato per questa chat resta sul telefono dove è stato creato, quindi qui la chat si può solo leggere.';

  @override
  String get devStartNewLine =>
      'Tutti i messaggi qui vengono eliminati, e si apre una nuova chat.';

  @override
  String get devVoiceDisguised => 'La tua voce è camuffata in questa chat';

  @override
  String get devChatOptions => 'Opzioni della chat';

  @override
  String appLinkOtherKey(Object id) {
    return 'Questo link dice di essere $id, ma la sua chiave non corrisponde. Non è stato aggiunto.';
  }

  @override
  String scamShieldSaysItIs(Object shown) {
    return 'Dice di essere $shown, ma la sua chiave non corrisponde';
  }

  @override
  String get requestsSomeoneNew => 'Qualcuno di nuovo';
}
