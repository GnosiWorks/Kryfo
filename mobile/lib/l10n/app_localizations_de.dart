// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get atmosphereNone => 'keine';

  @override
  String get atmosphereEmber => 'Glut';

  @override
  String get atmosphereDusk => 'Dämmerung';

  @override
  String get atmosphereMoss => 'Moos';

  @override
  String get atmosphereRose => 'Rose';

  @override
  String get atmosphereDots => 'Punkte';

  @override
  String get atmosphereGrid => 'Raster';

  @override
  String get atmosphereWaves => 'Wellen';

  @override
  String get atmosphereRain => 'Regen';

  @override
  String get atmosphereLateNight => 'Späte Stunde';

  @override
  String get atmosphereWarmAfternoon => 'Warmer Nachmittag';

  @override
  String get atmosphereSnow => 'Schnee';

  @override
  String get atmosphereDesert => 'Wüste';

  @override
  String get atmospherePaper => 'Papier';

  @override
  String get backupThatPassphraseDoesNot =>
      'Diese Passphrase öffnet diese Datei nicht';

  @override
  String get backupThatFileIsNot => 'Diese Datei ist kein Kryfo-Backup';

  @override
  String get backupThisBackupIsFrom =>
      'Dieses Backup stammt aus einer neueren Kryfo-Version. Aktualisiere die App und versuche es dann erneut';

  @override
  String get backupThisFileIsDamaged =>
      'Diese Datei ist beschädigt und kann nicht gelesen werden';

  @override
  String get backupCouldNotMakeThe => 'konnte Schlüssel nicht erstellen';

  @override
  String get contactCardMessageMeOn => 'Schreib mir auf';

  @override
  String get contactCardScanItOrType =>
      'Scanne den Code oder gib die drei Wörter in Kryfo ein.\nMehr weiß diese Karte nicht über dich.';

  @override
  String contactCardMessageMeOnKryfo(Object haloId) {
    return 'Schreib mir auf Kryfo · $haloId';
  }

  @override
  String get contactStatusBlocked => 'blockiert';

  @override
  String get contactStatusKeysVerifiedInPerson =>
      'Schlüssel persönlich verifiziert';

  @override
  String get contactStatusWaitingInRequests => 'Wartet in Anfragen';

  @override
  String get contactStatusAddedByHand => 'Von Hand hinzugefügt';

  @override
  String get deliveryModeAlwaysOn => 'Immer an';

  @override
  String get deliveryModeCheckIns => 'Check-ins';

  @override
  String get deliveryModeThroughAHelperApp => 'Über eine Hilfs-App';

  @override
  String get deliveryModeNotYet => 'noch nicht';

  @override
  String get deliveryModeJustNow => 'gerade eben';

  @override
  String deliveryModeMinAgo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vor $countString Min.',
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
      other: 'vor $countString Stunden',
      one: 'vor $countString Stunde',
    );
    return '$_temp0';
  }

  @override
  String get deliveryModeYesterday => 'gestern';

  @override
  String deliveryModeDaysAgo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vor $countString Tagen',
      one: 'vor $countString Tag',
    );
    return '$_temp0';
  }

  @override
  String get deliveryModeConnected => 'Verbunden';

  @override
  String get deliveryModeConnecting => 'Verbinde';

  @override
  String get deliveryModeNotConnected => 'Nicht verbunden';

  @override
  String get deliveryModeCheckingNow => 'Prüfe gerade';

  @override
  String deliveryModeLastCheckIn(Object agoLine) {
    return 'letzter Check-in $agoLine';
  }

  @override
  String get deliveryModeNoCheckInYet => 'noch kein Check-in';

  @override
  String deliveryModeConnectedNow(Object last) {
    return 'Jetzt verbunden · $last';
  }

  @override
  String deliveryModeConnecting2(Object last) {
    return 'Verbinde · $last';
  }

  @override
  String get deliveryModeNoCheckInYet2 => 'Noch kein Check-in';

  @override
  String deliveryModeLastChecked(Object agoLine) {
    return 'Zuletzt geprüft $agoLine';
  }

  @override
  String get deliveryModeAHelperApp => 'einer Hilfs-App';

  @override
  String deliveryModeWokenByNoWake(Object who) {
    return 'Wird von $who geweckt · noch kein Weckruf';
  }

  @override
  String deliveryModeWokenByLastWake(Object who, Object agoLine) {
    return 'Wird von $who geweckt · letzter Weckruf $agoLine';
  }

  @override
  String get introBudgetTomorrow => 'morgen';

  @override
  String introBudgetInDays(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'in $countString Tagen',
      one: 'in $countString Tag',
    );
    return '$_temp0';
  }

  @override
  String get introBudgetInAnHour => 'in einer Stunde';

  @override
  String introBudgetInHours(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'in $countString Stunden',
      one: 'in $countString Stunde',
    );
    return '$_temp0';
  }

  @override
  String get introBudgetInAFewMinutes => 'in ein paar Minuten';

  @override
  String get lockStateUnlockKryfo => 'Kryfo entsperren';

  @override
  String get appInvalidUri => 'ungültige URI';

  @override
  String appBundleError(Object e) {
    return 'Bundle-Fehler: $e';
  }

  @override
  String appAlreadySaved(Object parsed) {
    return 'Schon gespeichert: $parsed';
  }

  @override
  String appAddedYouCanMessage(Object parsed) {
    return '$parsed hinzugefügt · du kannst jetzt schreiben';
  }

  @override
  String appPeerImportedV1(Object parsed) {
    return 'Peer importiert (v1): $parsed';
  }

  @override
  String appLongWindow(Object line) {
    return '$line langes Fenster';
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
      other: '$pString Seiten',
      one: '$pString Seite',
    );
    String _temp1 = intl.Intl.pluralLogic(
      e,
      locale: localeName,
      other: '$eString Ereignisse',
      one: '$eString Ereignis',
    );
    return '$line ($heldString von $subsString, verbinden ${c}s, $_temp0, $_temp1)';
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
      other: '$pString Seiten',
      one: '$pString Seite',
    );
    String _temp1 = intl.Intl.pluralLogic(
      e,
      locale: localeName,
      other: '$eString Ereignisse',
      one: '$eString Ereignis',
    );
    return '$line (verbinden ${c}s, $_temp0, $_temp1)';
  }

  @override
  String appSDropped(Object host, Object secs) {
    return '$host ${secs}s abgebrochen';
  }

  @override
  String appS(Object host, Object secs) {
    return '$host ${secs}s';
  }

  @override
  String get appTorWouldNotWake => 'tor ließ sich nicht wecken';

  @override
  String get appCheckStarted => 'gestartet';

  @override
  String get appTorNotReadyIn => 'tor nach 75s nicht bereit';

  @override
  String get appOk => 'ok';

  @override
  String get appOkNoRelayBegan => 'ok, kein Relais antwortete';

  @override
  String get appOkCapped => 'ok, gekappt';

  @override
  String appSBy(Object how, int secs, String why) {
    final intl.NumberFormat secsNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String secsString = secsNumberFormat.format(secs);

    String _temp0 = intl.Intl.selectLogic(why, {
      'push': '$how, ${secsString}s, per Push',
      'other': '$how, ${secsString}s, per Job',
    });
    return '$_temp0';
  }

  @override
  String get appAnAttachmentCouldNot =>
      'Ein Anhang konnte nicht auf diesem Handy gespeichert werden';

  @override
  String get appGroup2 => 'Gruppe';

  @override
  String get appVoiceMessage => 'Sprachnachricht';

  @override
  String get appPhoto => 'Foto';

  @override
  String get appNewRequest => 'Neue Anfrage';

  @override
  String get appSomeoneYouHaveNot =>
      'Jemand, den du nicht hinzugefügt hast, hat dir geschrieben';

  @override
  String get appSettingUpYourKeys => 'Schlüssel werden eingerichtet';

  @override
  String get appOpeningYourChats => 'Chats werden geöffnet';

  @override
  String get appStartingTor => 'tor startet';

  @override
  String get appTimedMessagesAreNot =>
      'Befristete Nachrichten verschwinden gerade nicht. Starte Kryfo neu';

  @override
  String get appVoiceMessage2 => 'Sprachnachricht';

  @override
  String appYou(Object body) {
    return 'du: $body';
  }

  @override
  String get appThisRoomHasAlready => 'Dieser Raum ist schon abgelaufen';

  @override
  String get appYouAreAlreadyIn => 'Du bist schon in diesem Raum';

  @override
  String get appCouldNotMakeA => 'konnte keinen Raumschlüssel erstellen';

  @override
  String appJoinedButYourHello(Object linkName) {
    return '$linkName beigetreten, aber dein Hallo wurde zurückgehalten';
  }

  @override
  String appJoined(Object linkName) {
    return '$linkName beigetreten';
  }

  @override
  String appJoinedButTheCreator(Object linkName) {
    return '$linkName beigetreten, aber wer den Raum erstellt hat, ist noch nicht erreichbar';
  }

  @override
  String get appBooting => 'startet...';

  @override
  String get appSettingUpYourIdentity => 'Deine Identität wird eingerichtet...';

  @override
  String get appAddSomeone => 'Jemanden hinzufügen';

  @override
  String get appScanTheirCodeOr =>
      'Scanne den Code der Person oder füge ein, was sie dir gegeben hat: einen Link, einen @Benutzernamen oder einen Raumlink.';

  @override
  String get appScanTheirCode => 'Code scannen';

  @override
  String get appAKryfoLinkA => 'Ein Kryfo-Link, ein Raumlink oder @amsel';

  @override
  String get appAddThem => 'Hinzufügen';

  @override
  String get appEveryWayToAdd => 'Alle Wege, jemanden hinzuzufügen';

  @override
  String get appShowYourCodeSend =>
      'Zeig deinen Code, schick einen Link, sichere dir einen Benutzernamen';

  @override
  String get appHelloFromTheOther => 'Hallo von der anderen Seite';

  @override
  String get appIdentityRestored => 'Identität wiederhergestellt';

  @override
  String get appIdentityCreated => 'Identität erstellt';

  @override
  String get appStartingTor30s => 'Tor startet (~30s)...';

  @override
  String get appScanOrImportA => 'scanne oder importiere zuerst einen Peer';

  @override
  String get appEncryptingSending30s => 'Verschlüsseln + Senden (~30s)...';

  @override
  String get appTapStartListeningFirst => 'Tippe zuerst auf „Zuhören starten“';

  @override
  String get appYourKryfo => 'Dein Kryfo';

  @override
  String get appUriCopied => 'URI kopiert';

  @override
  String get appCopyUri => 'URI kopieren';

  @override
  String get appAddAKryfo => 'Kryfo hinzufügen';

  @override
  String get appScanQr => 'QR scannen';

  @override
  String get appPairingCode => 'Kopplungscode';

  @override
  String get appOrPaste => '- oder einfügen -';

  @override
  String get commonCancel => 'Abbrechen';

  @override
  String get appImport => 'Importieren';

  @override
  String get appDev => 'Entwickler';

  @override
  String get appYourKryfo2 => 'Dein Kryfo:';

  @override
  String get appRestoredFromDisk => 'Aus dem Speicher geladen';

  @override
  String get appStartListening => 'Zuhören starten';

  @override
  String get appListening => 'hört zu';

  @override
  String get appShowMyQr => 'Meinen QR zeigen';

  @override
  String get appImportPeer => 'Peer importieren';

  @override
  String get appPeer => 'Peer:';

  @override
  String get appMessageWillBeEncrypted => 'Nachricht (wird verschlüsselt)';

  @override
  String get appEncryptSend => 'Verschlüsseln + senden';

  @override
  String appStatus(Object status) {
    return 'Status: $status';
  }

  @override
  String get appSpeedPrivacy => 'Tempo & Privatsphäre →';

  @override
  String get appGettingMessages => 'Nachrichten empfangen →';

  @override
  String get appDisableAppLock => 'App-Sperre ausschalten?';

  @override
  String get appThePinWillBe =>
      'Die PIN wird entfernt. Wer dein Handy hat, sieht Kryfo beim Öffnen.';

  @override
  String get appDisable => 'Ausschalten';

  @override
  String get appAppLockOn => 'App-Sperre · an →';

  @override
  String get appAppLockOff => 'App-Sperre · aus →';

  @override
  String get appTorIsOff => 'Tor ist aus';

  @override
  String get appConnectedRoutedThrough3 => 'Verbunden · über 3 Relais geleitet';

  @override
  String get appReadyToSendPublishing =>
      'Bereit zum Senden · deine Adresse wird veröffentlicht';

  @override
  String get appReadyToSendFinishing =>
      'Bereit zum Senden · Einrichtung wird abgeschlossen';

  @override
  String appConnecting(Object pct) {
    return 'Verbinde · $pct';
  }

  @override
  String get appTor => 'Tor';

  @override
  String get appTorIsOffTurn =>
      'Tor ist aus. Schalte tor ein, um dich privat zu verbinden.';

  @override
  String get appTheFirstConnectionTakes =>
      'Die erste Verbindung dauert ein, zwei Minuten, während tor eine private Route aufbaut. Danach ist sie zwischengespeichert, und Kryfo öffnet sich später viel schneller.';

  @override
  String get appRelayAndFastModes =>
      'Die Modi Relais und Schnell umgehen tor und sind schneller. Du findest sie in den Einstellungen unter Tempo & Privatsphäre, und bei jedem steht, was er kostet.';

  @override
  String get appViaRelay => 'Über Relais';

  @override
  String get appOffline => 'offline';

  @override
  String get appFast => 'Schnell';

  @override
  String get appTorOff => 'Tor aus';

  @override
  String get appTorReady => 'Tor bereit';

  @override
  String get appConnecting2 => 'verbinde';

  @override
  String mediaProgressSendingKeepTheApp(Object v) {
    return 'Sende · $v · lass die App offen';
  }

  @override
  String mediaProgressPausedOfWaitingFor(Object count, Object count2) {
    return 'Pausiert · $count von $count2 · warte auf den Rest';
  }

  @override
  String mediaProgressReceivingMedia(Object v) {
    return 'Empfange Medien · $v';
  }

  @override
  String get mediaProgressCancelSending => 'Senden abbrechen';

  @override
  String get metaReaderEndsBeforeItShould => 'endet zu früh';

  @override
  String get metaReaderCouldNotBeRead => 'nicht lesbar';

  @override
  String get metaReaderExifThatCannotBe => 'unlesbares EXIF';

  @override
  String get metaReaderSamsungTrailer => 'Samsung-Anhang';

  @override
  String metaReaderChunk(Object type) {
    return 'Chunk $type';
  }

  @override
  String get metaReaderExifFlagSet => 'EXIF-Flag gesetzt';

  @override
  String get metaReaderXmpFlagSet => 'XMP-Flag gesetzt';

  @override
  String metaReaderAppBlock(Object id) {
    return 'App-Block $id';
  }

  @override
  String get metaReaderUuidBox => 'UUID-Box';

  @override
  String metaReaderBox(Object printable) {
    return '$printable-Box';
  }

  @override
  String get metaReaderAttachedData => 'angehängte Daten';

  @override
  String metaReaderItem(Object printable) {
    return '$printable-Eintrag';
  }

  @override
  String get miuiAutostartAlreadyAllowedToRun =>
      'Darf schon im Hintergrund laufen';

  @override
  String get miuiAutostartLetKryfoRunIn => 'Lass Kryfo im Hintergrund laufen';

  @override
  String get miuiAutostartYourPhonePausesApps =>
      'Dein Handy pausiert Apps, um Akku zu sparen. Ohne Ausnahme kann Kryfo keine Nachrichten empfangen, solange es geschlossen ist.';

  @override
  String get commonAllow => 'Erlauben';

  @override
  String get commonSkip => 'Überspringen';

  @override
  String get miuiAutostartXiaomiTurnsOffBackground =>
      'Xiaomi schaltet Hintergrund-Apps standardmäßig ab. Ohne Autostart kann Kryfo keine Nachrichten zustellen, wenn die App geschlossen ist. Such auf dem nächsten Bildschirm Kryfo in der Liste und leg den Schalter um.';

  @override
  String get miuiAutostartOpenSettings => 'Einstellungen öffnen';

  @override
  String get miuiAutostartCouldnTOpenIt =>
      'ließ sich nicht öffnen. such in den Handy-Einstellungen nach Autostart';

  @override
  String get notificationsNewEncryptedMessagesFrom =>
      'Neue verschlüsselte Nachrichten von deinen Kontakten';

  @override
  String get notificationsNewMessage => 'neue Nachricht';

  @override
  String get notificationsNewEncryptedMessagesFromYourContacts =>
      'neue verschlüsselte Nachrichten von deinen Kontakten';

  @override
  String get notificationsNewMessage2 => 'Neue Nachricht';

  @override
  String get notificationsEncrypted => 'verschlüsselt';

  @override
  String get rooms24h => '24 h';

  @override
  String roomsD(Object inDays) {
    return '$inDays T';
  }

  @override
  String roomsH(Object inHours) {
    return '$inHours h';
  }

  @override
  String get rooms24Hours => '24 Stunden';

  @override
  String roomsDays(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString Tagen',
      one: '$countString Tag',
    );
    return '$_temp0';
  }

  @override
  String get roomsAnHour => 'einer Stunde';

  @override
  String get roomsAboutAnHour => 'etwa einer Stunde';

  @override
  String roomsHours(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString Stunden',
      one: '$countString Stunde',
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
      other: 'etwa $countString Stunden',
      one: 'etwa $countString Stunde',
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
      other: '$countString Minuten',
      one: '$countString Minute',
    );
    return '$_temp0';
  }

  @override
  String get roomsAMinute => 'einer Minute';

  @override
  String get roomsExpired => 'abgelaufen';

  @override
  String roomsDH(Object inDays, Object h) {
    return '$inDays T $h h';
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
  String get scamShieldLooksLikeAScam => 'Sieht nach Betrug aus';

  @override
  String scamShieldThisNameMatches(Object shown) {
    return 'Dieser Name gleicht $shown';
  }

  @override
  String scamShieldNameMatchesYourContact(Object shown) {
    return 'Name gleicht deinem Kontakt $shown';
  }

  @override
  String scamShieldSameFaceAsYour(Object shown) {
    return 'gleiches Gesicht wie dein Kontakt $shown';
  }

  @override
  String get scamShieldContainsACryptoAddress => 'Enthält eine Krypto-Adresse';

  @override
  String get scamShieldMentionsMoneyAndUrgency =>
      'Spricht von Geld und Zeitdruck zugleich';

  @override
  String get scamShieldAsksYouToMove =>
      'Will, dass du in eine andere App wechselst';

  @override
  String get scamShieldLinksToALookalike =>
      'Verlinkt eine Nachahmung einer bekannten Website';

  @override
  String get scamShieldALongOpenerFrom =>
      'Eine lange erste Nachricht von jemandem ohne Vorgeschichte';

  @override
  String get scamShieldAsksForACode =>
      'Fragt nach einem Code, einer Seed-Phrase oder einer Wiederherstellungsdatei';

  @override
  String scamShieldAlso(Object shown) {
    return 'Außerdem: Name gleicht deinem Kontakt $shown';
  }

  @override
  String get commonBack => 'Zurück';

  @override
  String get archivedArchived => 'Archiv';

  @override
  String get archivedCount0 => 'keine';

  @override
  String get archivedCount1 => 'ein';

  @override
  String get archivedCount2 => 'zwei';

  @override
  String get archivedCount3 => 'drei';

  @override
  String get archivedCount4 => 'vier';

  @override
  String get archivedCount5 => 'fünf';

  @override
  String get archivedCount6 => 'sechs';

  @override
  String get archivedCount7 => 'sieben';

  @override
  String get archivedCount8 => 'acht';

  @override
  String get archivedCount9 => 'neun';

  @override
  String get archivedCount10 => 'zehn';

  @override
  String get archivedChatRestingHereIt =>
      'Chat ruht hier. Er bleibt still, bis die Person schreibt, und kommt dann wieder nach oben.';

  @override
  String get archivedChatsRestingHere =>
      'Chats ruhen hier. Sie bleiben still, bis jemand schreibt, und kommen dann wieder nach oben.';

  @override
  String get archivedNothingArchived => 'Nichts archiviert';

  @override
  String get archivedArchivedChatsAreStill =>
      'Archivierte Chats sind weiterhin Ende-zu-Ende-verschlüsselt';

  @override
  String get archivedUnarchive => 'Aus Archiv holen';

  @override
  String get avatarPickerThePeopleYouMessage =>
      'Die Leute, denen du schreibst, sehen das auch';

  @override
  String get avatarPickerBackToYourInitial => 'zurück zu deiner Initiale';

  @override
  String get avatarPickerThatOneIsYours => 'das ist deins';

  @override
  String get avatarPickerPickAFace => 'Wähle ein Gesicht';

  @override
  String get commonSave => 'Speichern';

  @override
  String get backupPassphraseMustBeAt =>
      'Passphrase muss mindestens 6 Zeichen haben';

  @override
  String get backupPassphrasesDonTMatch => 'Passphrasen stimmen nicht überein';

  @override
  String get backupBackupSavedKeepThe =>
      'Backup gespeichert · bewahre die Passphrase sicher auf';

  @override
  String get backupKryfoBackup => 'Kryfo-Backup';

  @override
  String get backupYourEncryptedKryfoBackup =>
      'Dein verschlüsseltes Kryfo-Backup. Bewahre diese Datei UND deine Passphrase sicher auf - zum Wiederherstellen brauchst du beides.';

  @override
  String get backupBackUpKryfo => 'Kryfo sichern';

  @override
  String get backupBackUp => 'Sichern';

  @override
  String get backupACopyToKeep =>
      'Eine Kopie zum Aufbewahren. Dieses Handy läuft ganz normal weiter.';

  @override
  String get backupMoveToAnotherDevice => 'Auf ein anderes Gerät umziehen';

  @override
  String get backupTheFileTakesThis =>
      'Die Datei nimmt diese Identität mit. Sobald sie erstellt ist, hört dieses Handy auf: Hier kommt nichts Neues mehr an, und nichts, was von hier gesendet wird, erreicht noch jemanden.';

  @override
  String get backupOneEncryptedFileYour =>
      'Eine verschlüsselte Datei: deine Identität, deine Kontakte, jede Nachricht und jedes Foto, jede Sprachnachricht und jede Datei. Importiere sie mit der Passphrase auf dem anderen Gerät. Bis dahin kannst du es dir noch anders überlegen und auf diesem Handy bleiben.';

  @override
  String get backupOneEncryptedFileYourIdentityYour =>
      'Eine verschlüsselte Datei: deine Identität, deine Kontakte, jede Nachricht und jedes Foto, jede Sprachnachricht und jede Datei, die gerade auf diesem Handy sind. Was nach heute gesagt wird, ist nicht darin, also mach ein neues, wenn es darauf ankommt. Zum Wiederherstellen brauchst du beides: die Datei und die Passphrase.';

  @override
  String get backupPassphrase => 'Passphrase';

  @override
  String get backupConfirmPassphrase => 'Passphrase bestätigen';

  @override
  String backupWriting(Object progress) {
    return 'schreibe… $progress';
  }

  @override
  String get backupCreating => 'erstelle…';

  @override
  String get backupMakeTheFileAnd => 'Datei erstellen und umziehen';

  @override
  String get backupCreateBackup => 'Backup erstellen';

  @override
  String get blockedBlocked => 'Blockiert';

  @override
  String get blockedNoOneIsBlocked => 'Niemand ist blockiert';

  @override
  String get commonUnblock => 'Freigeben';

  @override
  String get bridgesThatWasNotIt => 'Das war es nicht. Hier ist ein anderes.';

  @override
  String get bridgesGotBridgesSaveTo =>
      'Brücken erhalten · speichere, um sie zu nutzen';

  @override
  String get bridgesConnected => 'Verbunden';

  @override
  String get bridgesNotThroughYetTor =>
      'Noch nicht durch. Tor versucht es weiter';

  @override
  String get bridgesBridges => 'Brücken';

  @override
  String get bridgesTorIsBlockedWhere => 'Tor ist bei dir blockiert?';

  @override
  String get bridgesBridgesDisguiseYourConnection =>
      'Brücken tarnen deine Verbindung, damit sie hinauskommt. Wähle einen Zugang, speichere, und tor verbindet sich darüber neu.';

  @override
  String get bridgesBridgesOnlyChangeHow =>
      'Brücken ändern nur, wie tor sich verbindet, und du bist gerade nicht im Onion-Modus. Was du hier einstellst, wird gespeichert, es bewirkt nur nichts, bis du zurückwechselst.';

  @override
  String get bridgesFromTheTorProject => 'Vom tor-Projekt';

  @override
  String get bridgesNoise => 'Rauschen';

  @override
  String get bridgesGood => 'gut';

  @override
  String get bridgesMakesTorTrafficLook =>
      'Lässt tor-Verkehr nach nichts Bestimmtem aussehen. Die beste Wahl für die meisten gesperrten Netze. Du löst ein Captcha und bekommst ein paar Zeilen.';

  @override
  String get bridgesPrivateBridge => 'Private Brücke';

  @override
  String get bridgesALineFromA => 'Eine Zeile von Freunden';

  @override
  String get bridgesWhateverTheLineSays => 'Was die Zeile sagt';

  @override
  String get bridgesDepends => 'je nachdem';

  @override
  String get bridgesGotABridgeLine =>
      'Du hast eine Brückenzeile von jemandem, dem du vertraust, oder von bridges.torproject.org? Füge sie hier ein. Nur obfs4-Zeilen, die anderen versteht Kryfo noch nicht.';

  @override
  String get bridgesPasteFromClipboard => 'Aus Zwischenablage einfügen';

  @override
  String get bridgesUseBridges => 'Brücken nutzen';

  @override
  String get bridgesNoLinesYet => 'Noch keine Zeilen';

  @override
  String bridges1LineSaved(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString Zeilen gespeichert',
      one: '$countString Zeile gespeichert',
    );
    return '$_temp0';
  }

  @override
  String get bridgesRestartingTor => 'Tor startet neu…';

  @override
  String bridgesFindingABridgeS(Object elapsed) {
    return 'Suche eine Brücke… ${elapsed}s';
  }

  @override
  String bridgesStillTryingS(Object elapsed) {
    return 'Versuche es weiter… ${elapsed}s';
  }

  @override
  String get bridgesApplying => 'Wird angewendet…';

  @override
  String get bridgesSaveAndReconnect => 'Speichern und neu verbinden';

  @override
  String get bridgesWhatABridgeIs => 'Was eine Brücke ist';

  @override
  String get bridgesATorEntryPoint =>
      'Ein tor-Eingang, den niemand veröffentlicht hat, erreicht über eine Hülle, damit die Verbindung nicht nach tor aussieht. Der Rest der Route sind die üblichen drei Stationen.';

  @override
  String get bridgesLooksLike => 'Sieht aus wie';

  @override
  String get bridgesSpeed => 'Tempo';

  @override
  String get bridgesGetBridges => 'Brücken holen';

  @override
  String get bridgesAskTheTorProject =>
      'Frag direkt beim tor-Projekt. Du löst ein Rätsel, damit Bots den Vorrat nicht leerräumen können.';

  @override
  String get bridgesTypeWhatYouSee =>
      'tippe ab, was du siehst. Kleinschreibung ist okay.';

  @override
  String get bridgesThisOneRequestDoes =>
      'Diese eine Anfrage läuft nicht über tor - das geht nicht, denn tor ist ja genau das, was nicht funktioniert. Wer dein Netzwerk betreibt, sieht, dass du das tor-Projekt kontaktierst. Wenn schon das bei dir ein Problem ist, hol dir Brücken woanders und füge sie unten ein.';

  @override
  String get bridgesCouldNotDrawThe => 'Rätsel konnte nicht angezeigt werden';

  @override
  String get bridgesAnswer => 'Antwort';

  @override
  String get bridgesAsking => 'Frage an…';

  @override
  String get bridgesRequestBridges => 'Brücken anfordern';

  @override
  String get bridgesDifferentPuzzle => 'Anderes Rätsel';

  @override
  String get cameraNoCameraOnThis => 'Dieses Handy hat keine Kamera';

  @override
  String get cameraCameraNotAvailable => 'Kamera nicht verfügbar';

  @override
  String get cameraCameraPermissionIsOff =>
      'Kamerazugriff ist aus · tippe, um es erneut zu versuchen';

  @override
  String get cameraCouldNotStripThat =>
      'Foto konnte nicht bereinigt werden, verworfen';

  @override
  String get cameraNoPhotoCameOut => 'Kein Foto entstanden';

  @override
  String get cameraCouldNotStartRecording => 'Aufnahme konnte nicht starten';

  @override
  String get cameraTheRecordingWasLost => 'Die Aufnahme ging verloren';

  @override
  String get cameraACopyIsIn => 'Eine Kopie ist in deinen Fotos';

  @override
  String get cameraCouldNotSaveA =>
      'Konnte keine Kopie auf diesem Handy speichern';

  @override
  String get cameraTooLongForA => 'Zu lang für eine Nachricht · max. 8 MB';

  @override
  String get cameraNeverSavedToYour => 'Nie in deinen Fotos gespeichert';

  @override
  String get cameraNoExifNeverSaved =>
      'Kein EXIF, nie in deinen Fotos gespeichert';

  @override
  String get cameraRec => 'Aufn.';

  @override
  String get cameraSwitchCamera => 'Kamera wechseln';

  @override
  String cameraClipSMb(Object secs, Object mb) {
    return 'Clip · ${secs}s · $mb MB';
  }

  @override
  String get cameraStopRecording => 'Aufnahme stoppen';

  @override
  String get cameraStartRecording => 'Aufnahme starten';

  @override
  String get cameraTakeAPhoto => 'Foto aufnehmen';

  @override
  String get cameraKeepACopy => 'Kopie behalten';

  @override
  String get cameraUseThis => 'Verwenden';

  @override
  String chatB(Object bytes) {
    return '$bytes B';
  }

  @override
  String chatKb(Object bytes) {
    return '$bytes KB';
  }

  @override
  String chatMb(Object bytes) {
    return '$bytes MB';
  }

  @override
  String get chatFile => 'DATEI';

  @override
  String get chatYouAreOfflineThis =>
      'du bist offline · wird von selbst gesendet, sobald du wieder verbunden bist';

  @override
  String get chatStillConnectingToTor =>
      'verbinde noch mit tor · wird von selbst gesendet';

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
    return '$seconds T';
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
  String get chatNewMessages => 'Neue Nachrichten';

  @override
  String get chatUnsave => 'Speichern aufheben';

  @override
  String get chatForward => 'Weiterleiten';

  @override
  String get commonShare => 'Teilen';

  @override
  String get commonCopied => 'Kopiert';

  @override
  String get commonCopy => 'Kopieren';

  @override
  String get chatUnpin => 'Loslösen';

  @override
  String get chatPin => 'Anheften';

  @override
  String get chatStopSending => 'Senden stoppen';

  @override
  String get chatUnsend => 'Zurückholen';

  @override
  String get commonEdit => 'Bearbeiten';

  @override
  String get chatYou => 'Du';

  @override
  String get chatUnsendMessage => 'Nachricht zurückholen';

  @override
  String get chatItDisappearsWithNo =>
      'Sie verschwindet spurlos. Das lässt sich nicht rückgängig machen.';

  @override
  String chatThisChatHasPins(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'In diesem Chat sind schon $countString Nachrichten angeheftet',
      one: 'In diesem Chat ist schon $countString Nachricht angeheftet',
    );
    return '$_temp0';
  }

  @override
  String get chatUnpinThisMessage => 'Diese Nachricht loslösen?';

  @override
  String get chatPinThisMessage => 'Diese Nachricht anheften?';

  @override
  String get chatItLeavesThePinned =>
      'Sie verschwindet für euch beide aus der Liste der angehefteten Nachrichten.';

  @override
  String get chatItGoesUnderThe =>
      'Sie erscheint für euch beide oben im Chat bei den angehefteten Nachrichten.';

  @override
  String get chatPinIt => 'Anheften';

  @override
  String get chatNotNow => 'Nicht jetzt';

  @override
  String get chatEditMessage => 'Nachricht bearbeiten';

  @override
  String get chat30Seconds => '30 Sekunden';

  @override
  String get chat1Minute => '1 Minute';

  @override
  String get chat5Minutes => '5 Minuten';

  @override
  String get chat1Hour => '1 Stunde';

  @override
  String get chat24Hours => '24 Stunden';

  @override
  String get chatGhostTimer => 'Befristete Nachrichten';

  @override
  String get chatHowLongBeforeSent =>
      'Wie lange, bis gesendete Nachrichten verschwinden?';

  @override
  String get chatCamera => 'Kamera';

  @override
  String get chatNoExifNeverSaved =>
      'Kein EXIF, nie in deinen Fotos gespeichert';

  @override
  String get chatGallery => 'Galerie';

  @override
  String get chatVideo => 'Video';

  @override
  String get chatGifFromPhone => 'GIF vom Handy';

  @override
  String get chatFile2 => 'Datei';

  @override
  String get chatAFewSeconds => 'Ein paar Sekunden';

  @override
  String get chatUnderAMinute => 'Unter einer Minute';

  @override
  String chatRoughlyMin(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Etwa $countString Min.',
    );
    return '$_temp0';
  }

  @override
  String chatB2(Object b) {
    return '$b B';
  }

  @override
  String chatKb2(Object b) {
    return '$b KB';
  }

  @override
  String chatMb2(Object b) {
    return '$b MB';
  }

  @override
  String get chatSendThis => 'Diese Datei senden?';

  @override
  String chatOverTor(Object humanBytes, Object wireEstimate) {
    return '$humanBytes · $wireEstimate über tor';
  }

  @override
  String get chatBigFilesGoOut =>
      'Große Dateien gehen in kleinen verschlüsselten Stücken raus, deshalb dauert das etwas. Lass die App offen, dann läuft es weiter.';

  @override
  String get chatSendIt => 'Senden';

  @override
  String get chatCouldNotReadThat => 'Konnte die Datei nicht lesen';

  @override
  String get chatFileTooBig8 => 'Datei zu groß · max. 8 MB';

  @override
  String get chatCouldNotCleanThat => 'Konnte das Video nicht bereinigen';

  @override
  String get chatCouldNotCleanThatPictureSend =>
      'Konnte das Bild nicht bereinigen · sende es als Foto';

  @override
  String get chatGifTooBig8 => 'GIF zu groß · max. 8 MB';

  @override
  String get chatCouldNotCleanThatGif => 'Konnte das GIF nicht bereinigen';

  @override
  String get chatTorIsNotUp => 'Tor läuft noch nicht · sende ohne Vorschau';

  @override
  String get chatCouldnTReachIt => 'Nicht erreichbar · sende ohne Vorschau';

  @override
  String get chatNoTitleCameBack => 'Kein Titel erhalten · sende ohne Vorschau';

  @override
  String get chatCouldnTFetchIt => 'Nicht abrufbar · sende ohne Vorschau';

  @override
  String get chatNoSignalSessionRe => 'Keine Signal-Sitzung - neu koppeln';

  @override
  String get chatMessageUnavailable => 'Nachricht nicht verfügbar';

  @override
  String get chatYou2 => 'du';

  @override
  String get chatThem => 'Gegenüber';

  @override
  String get chatVoiceMessage => 'Sprachnachricht';

  @override
  String get chatQuotedPhoto => 'Foto';

  @override
  String get chatViewContact => 'Kontakt ansehen';

  @override
  String get chatSharedPhotos => 'Geteilte Fotos';

  @override
  String chatSharedPhotoCount(int count, Object title) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString Fotos',
      one: '$countString Foto',
    );
    return '$_temp0 · $title';
  }

  @override
  String get chatUnmuteNotifications => 'Stummschaltung aufheben';

  @override
  String get chatMuteNotifications => 'Stummschalten';

  @override
  String get chatArchiveChat => 'Chat archivieren';

  @override
  String get chatWallpaper => 'Hintergrund';

  @override
  String get chatClearConversation => 'Verlauf leeren';

  @override
  String get chatNoteOnThisContact => 'Notiz zu diesem Kontakt';

  @override
  String get chatPinToTop => 'Oben anheften';

  @override
  String get chatBlockContact => 'Kontakt blockieren';

  @override
  String get chatUnpinned => 'Losgelöst';

  @override
  String get chatPinnedToTop => 'Oben angeheftet';

  @override
  String get chatJustForYouNever =>
      'Nur für dich. Wird nie gesendet, verlässt nie dieses Handy.';

  @override
  String get chatAQuietReminder => 'Eine stille Erinnerung…';

  @override
  String get chatNoteSaved => 'Notiz gespeichert';

  @override
  String get chatClearThisConversation => 'Diesen Verlauf leeren?';

  @override
  String get chatEveryMessageHereIs =>
      'Jede Nachricht hier wird von diesem Handy gelöscht. Das leert nur deine Kopie - das Gerät der anderen Person bleibt unberührt.';

  @override
  String get chatClear => 'Leeren';

  @override
  String get chatBlockThisContact => 'Diesen Kontakt blockieren?';

  @override
  String get chatTheirMessagesStopArriving =>
      'Die Nachrichten der Person kommen nicht mehr an, und sie verschwindet aus deinen Chats. Sie erfährt es nie. Du kannst sie jederzeit in den Einstellungen freigeben.';

  @override
  String get commonBlock => 'Blockieren';

  @override
  String get chatSaved => 'Gespeichert';

  @override
  String get chatRemovedFromSaved => 'Aus Gespeichert entfernt';

  @override
  String get chatForwardTo => 'Weiterleiten an';

  @override
  String get chatNoContactsToForward => 'Keine Kontakte zum Weiterleiten';

  @override
  String get chatToday => 'heute';

  @override
  String get chatYesterday => 'gestern';

  @override
  String get chatThisMessageCanT =>
      'Diese Nachricht kann nicht angezeigt werden';

  @override
  String get chatJumpToTheNewest => 'Zur neuesten springen';

  @override
  String get chatBuildingAPrivateRoute =>
      'Baue eine private Route auf · die erste Verbindung dauert, spätere gehen schnell. Alles, was du jetzt sendest, wartet in der Schlange und wird von selbst zugestellt.';

  @override
  String get chatLooksSafeNothingSuspicious =>
      'Sieht sicher aus · nichts Verdächtiges in der ersten Nachricht';

  @override
  String get chatTheNextPhotoYou =>
      'Das nächste Foto, das du sendest, öffnet sich geschützt · die andere Person kann keinen Screenshot davon machen';

  @override
  String get chatPhotoProtectionOff => 'Fotoschutz aus';

  @override
  String get chatAcceptToReplyThey =>
      'Nimm an, um zu antworten - bis dahin kann dir die Person noch eine Nachricht schicken.';

  @override
  String chatIntroducedYouAcceptTo(Object introducer) {
    return 'Vorgestellt von $introducer. Nimm an, um zu antworten.';
  }

  @override
  String chatIntroducedYouSayHello(Object vouchNames) {
    return 'Vorgestellt von $vouchNames. Sag hallo - die Person hat deine Karte auch bekommen.';
  }

  @override
  String get chatIntroduceTo => 'Jemandem vorstellen...';

  @override
  String get chatAcceptThemFirst => 'Nimm zuerst an';

  @override
  String get chatMessageRequest => 'Nachrichtenanfrage';

  @override
  String get chatTheyNeedToAccept =>
      'Die Person muss annehmen, bevor ihr weiterschreiben könnt.';

  @override
  String get chatWaitingForThemTo =>
      'Warte darauf, dass die Person deine Anfrage annimmt';

  @override
  String get chatYouBlockedThisContact => 'Du hast diesen Kontakt blockiert';

  @override
  String get chatSupporter => 'Unterstützer';

  @override
  String get chatEncryptedViaRelay => 'Verschlüsselt · über Relais';

  @override
  String get chatEncryptedDirect => 'Verschlüsselt · direkt';

  @override
  String get chatEncryptedOverTor => 'Verschlüsselt · über tor';

  @override
  String get chatSearchThisChat => 'Diesen Chat durchsuchen';

  @override
  String get chatContactOptions => 'Kontaktoptionen';

  @override
  String get commonClose => 'Schließen';

  @override
  String get chatFindInConversation => 'Im Verlauf suchen';

  @override
  String get chatNoMatches => 'Keine Treffer';

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
      other: '*$posString* von $countString Treffern',
      one: '*$posString* von $countString Treffer',
    );
    return '$_temp0';
  }

  @override
  String get chatPreviousMatch => 'Vorheriger Treffer';

  @override
  String get chatNextMatch => 'Nächster Treffer';

  @override
  String get chatPhotoUnavailable => 'Foto nicht verfügbar';

  @override
  String get chatDelivered => 'Zugestellt';

  @override
  String get chatEdited => 'Bearbeitet';

  @override
  String get chatWaitingForThemToComeOnline =>
      'Warte, bis die Person online ist oder dich auch hinzufügt';

  @override
  String get chatFailedTapToRetry => 'Fehler · tippe zum Wiederholen';

  @override
  String get chatReplyingTo => 'Antwort ans Gegenüber';

  @override
  String get chatReplyingToYourself => 'Antwort an dich selbst';

  @override
  String get chatReply => 'Antworten';

  @override
  String get chatSayHi => 'Sag hallo.';

  @override
  String get chatJustTheTwoOf => 'Nur ihr zwei, Ende-zu-Ende-verschlüsselt.';

  @override
  String get chatMicPermissionNeeded => 'Mikrofonzugriff nötig';

  @override
  String get chatTheMicWouldNot =>
      'Das Mikrofon startet nicht. Versuche es erneut';

  @override
  String get chatReleaseToCancel => 'Loslassen zum Abbrechen';

  @override
  String get chatVoiceHiddenSlideTo =>
      'Stimme verfremdet · zum Abbrechen wischen';

  @override
  String get chatSlideToCancel => 'Zum Abbrechen wischen';

  @override
  String get chatGhostMode => 'Befristete Nachrichten';

  @override
  String chatMessagesBurnAfter(Object humanBurn) {
    return 'verschwinden nach $humanBurn';
  }

  @override
  String get chatTimedMessages => 'Befristete Nachrichten';

  @override
  String get chatOpenTheCamera => 'Kamera öffnen';

  @override
  String get chatAttachAPhoto => 'Foto anhängen';

  @override
  String get chatMessage => 'Nachricht';

  @override
  String get chatDisguiseVoice => 'Stimme verfremden';

  @override
  String get commonSend => 'Senden';

  @override
  String get chatNoPhotosInThis => 'Noch keine Fotos in diesem Chat';

  @override
  String get chatSendPhoto => 'Foto senden';

  @override
  String get chatAddACaption => 'Beschriftung…';

  @override
  String get chatSecurityCodeChanged => 'Sicherheitscode geändert';

  @override
  String chatMayHaveReinstalledOr(Object peerName) {
    return '$peerName hat die App vielleicht neu installiert, oder jemand könnte sich als diese Person ausgeben. Vergleiche die Sicherheitsnummern, um sicherzugehen.';
  }

  @override
  String get chatOk => 'OK';

  @override
  String get chatVerify => 'Verifizieren';

  @override
  String get cleanKryfoCanTClean =>
      'Kryfo kann diese Art von Datei noch nicht bereinigen.';

  @override
  String get cleanThisIsAMotion => 'Das ist ein Bewegungsfoto.';

  @override
  String get cleanThisPictureIsToo =>
      'Dieses Bild ist zu groß, um es hier zu bereinigen.';

  @override
  String get cleanThisFileIsDamaged =>
      'Diese Datei ist beschädigt oder abgeschnitten.';

  @override
  String get cleanKryfoCouldNotMake =>
      'Kryfo konnte diese Datei nicht bereinigen.';

  @override
  String get cleanNotEnoughRoomOn => 'Nicht genug Platz auf dem Handy.';

  @override
  String get cleanKryfoCouldNotOpen => 'Kryfo konnte die Datei nicht öffnen.';

  @override
  String get cleanItCleansJpegPng =>
      'Kryfo bereinigt JPEG, PNG, WebP, HEIC, AVIF, GIF, MP4 und MOV. Es wurde nichts verändert.';

  @override
  String get cleanItHoldsAShort =>
      'Es enthält neben dem Bild ein kurzes Video, und diesen Teil kann Kryfo noch nicht bereinigen. Schalte Bewegung in deiner Kamera aus oder sende einen Screenshot davon.';

  @override
  String get cleanPicturesOver64Mb =>
      'Bilder über 64 MB werden auf dem Handy nicht bereinigt. Es wurde nichts verändert.';

  @override
  String get cleanKryfoCouldNotRead =>
      'Kryfo konnte die Datei nicht bis zum Ende lesen und nennt sie deshalb nicht sauber. Es wurde keine Kopie erstellt.';

  @override
  String get cleanSomethingInsideIsOf =>
      'Darin steckt etwas, das Kryfo nicht zu entfernen weiß, deshalb wurde keine Kopie erstellt.';

  @override
  String get cleanFreeSomeSpaceAnd =>
      'Mach etwas Platz frei und versuche es erneut. Es wurde nichts verändert.';

  @override
  String get cleanTheAppThatShared =>
      'Die App, die sie geteilt hat, hat sie vielleicht zurückgenommen. Versuche, sie noch einmal zu teilen.';

  @override
  String get cleanNoAppOnThis =>
      'Keine App auf diesem Handy hat die Datei angenommen.';

  @override
  String get cleanCouldNotSaveIt =>
      'Konnte sie nicht speichern. Prüfe, ob das Handy genug Platz hat.';

  @override
  String get cleanTheOriginalIsGone =>
      'Das Original ist weg. Die bereinigte Kopie bleibt.';

  @override
  String get cleanAndroidWouldNotDelete =>
      'Android wollte es nicht löschen. Entferne es von Hand aus der Galerie.';

  @override
  String get cleanCleanCopy => 'Bereinigte Kopie';

  @override
  String get cleanShareCleanCopy => 'Bereinigte Kopie teilen';

  @override
  String get cleanSaveToGallery => 'In Galerie speichern';

  @override
  String get commonStop => 'Stopp';

  @override
  String get cleanReadingTheFile => 'Lese die Datei';

  @override
  String get cleanCleaning => 'Bereinige';

  @override
  String cleanOf(Object prettySize, Object prettySize2) {
    return '$prettySize von $prettySize2';
  }

  @override
  String get cleanEverythingStaysOnThis => 'Alles bleibt auf diesem Handy.';

  @override
  String get cleanAlreadyClean => 'Schon sauber.';

  @override
  String get cleanClean => 'Sauber.';

  @override
  String get cleanThereWasNothingTo => 'Da war nichts zu finden.';

  @override
  String get cleanNothingLeftToFind => 'Nichts mehr zu finden.';

  @override
  String get cleanSameVideoSameQuality => 'Gleiches Video, gleiche Qualität';

  @override
  String get cleanSamePictureSameQuality => 'Gleiches Bild, gleiche Qualität';

  @override
  String cleanRemoved(Object label) {
    return '$label, entfernt';
  }

  @override
  String get cleanRemoved2 => 'ENTFERNT';

  @override
  String get cleanWithTheLocationInside =>
      'mit dem Standort darin. Wer dieses bekommt, bekommt deine Straße.';

  @override
  String get cleanWithEverythingItKnew =>
      'mit allem, was es wusste, noch darin.';

  @override
  String get cleanOriginal => 'ORIGINAL';

  @override
  String get cleanClean2 => 'SAUBER';

  @override
  String get cleanSavedToYourGallery => 'In deiner Galerie gespeichert.';

  @override
  String cleanTheOriginalIsStill(Object what) {
    return 'Das Original ist auch noch da, $what';
  }

  @override
  String cleanTheOriginalIsStillWhereIt(Object what) {
    return 'Das Original ist noch dort, wo es war, $what Kryfo kann es von hier aus nicht entfernen, also lösch es in der App, aus der es kam.';
  }

  @override
  String get cleanDeleteTheOriginal => 'Original löschen';

  @override
  String get cleanKeepBoth => 'Beide behalten';

  @override
  String get commonDone => 'Fertig';

  @override
  String get cleanAndroidWillAskYou => 'ANDROID LÄSST DICH BESTÄTIGEN';

  @override
  String get contactYourNameForThem => 'Dein Name für die Person';

  @override
  String get contactStaysOnThisPhone =>
      'Bleibt auf diesem Handy. Die Person sieht ihn nie.';

  @override
  String get contactClear => 'Entfernen';

  @override
  String get contactMessage => 'Schreiben';

  @override
  String get contactKeysVerified => 'Verifiziert';

  @override
  String get contactVerifyKeys => 'Verifizieren';

  @override
  String get contactVouches => 'Empfehlungen';

  @override
  String get contactUnmute => 'Stummschaltung aufheben';

  @override
  String get contactMute => 'Stummschalten';

  @override
  String get contactUnpin => 'Loslösen';

  @override
  String get contactPinToTop => 'Oben anheften';

  @override
  String get contactArchive => 'Archivieren';

  @override
  String get contactOutOfTheList =>
      'Aus der Liste, bis die Person wieder schreibt';

  @override
  String contactBlock(Object name) {
    return '$name blockieren?';
  }

  @override
  String get contactTheirMessagesStopArriving =>
      'Die Nachrichten der Person kommen nicht mehr an. Sie erfährt nichts davon.';

  @override
  String get contactDeleteChat => 'Chat löschen';

  @override
  String get contactMessagesAndContactGone =>
      'Nachrichten und Kontakt, weg von diesem Handy';

  @override
  String get contactDeleteThisChat => 'Diesen Chat löschen?';

  @override
  String get contactEveryMessageAndThe =>
      'Jede Nachricht und der Kontakt, weg von diesem Handy. An die Person wird nichts gesendet.';

  @override
  String get commonDelete => 'Löschen';

  @override
  String get contactDeleted => 'Gelöscht';

  @override
  String get contactToday => 'heute';

  @override
  String contactD(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tage',
      one: '$count Tag',
    );
    return '$_temp0';
  }

  @override
  String contactMo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Monate',
      one: '$count Monat',
    );
    return '$_temp0';
  }

  @override
  String contactY(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Jahre',
      one: '$count Jahr',
    );
    return '$_temp0';
  }

  @override
  String get contactVerified => 'Verifiziert';

  @override
  String get contactChatting => 'Chat seit';

  @override
  String get contactNothingSharedYet => 'noch nichts geteilt';

  @override
  String contactSharedMedia(Object count) {
    return 'geteilte Medien · $count';
  }

  @override
  String get donateBitcoin => 'Bitcoin';

  @override
  String get donateText => '₿';

  @override
  String get donateBadgeUnlocks => 'Abzeichen automatisch';

  @override
  String get donateMonero => 'Monero';

  @override
  String get donateManualNoBadge => 'manuell · kein Abzeichen';

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
          'Deine frühere Bitcoin-Zahlung wurde erkannt · Unterstützer-Abzeichen freigeschaltet',
      'patron':
          'Deine frühere Bitcoin-Zahlung wurde erkannt · Förderer-Abzeichen freigeschaltet',
      'guardian':
          'Deine frühere Bitcoin-Zahlung wurde erkannt · Hüter-Abzeichen freigeschaltet',
      'other':
          'Deine frühere Bitcoin-Zahlung wurde erkannt · Unterstützer-Abzeichen freigeschaltet',
    });
    return '$_temp0';
  }

  @override
  String get donateSupport => 'Unterstützen';

  @override
  String get donateKeepKryfo => 'Halte Kryfo *unabhängig*';

  @override
  String get donateNoAdsNoInvestors =>
      'Keine Werbung, keine Investoren, nichts zu verkaufen. Es läuft mit dem, was Leute beisteuern.';

  @override
  String get donateBackItAnonymouslyBadge =>
      'Unterstütze es anonym. Abzeichen nur, wenn du willst.\n*Privatsphäre steht nie hinter einer Bezahlschranke.*';

  @override
  String donateAddressCheckItAgainst(Object coinName) {
    return '$coinName-Adresse · gleiche sie mit deiner Wallet ab';
  }

  @override
  String get donateAddressCopiedClearsIn =>
      'Adresse kopiert · verschwindet in 60s';

  @override
  String get donateCopyAddress => 'Adresse kopieren';

  @override
  String get donateBitcoinIsVerifiedBy =>
      'Bitcoin wird von unserem eigenen Knoten geprüft, also wird dein Abzeichen von selbst freigeschaltet, sobald die Zahlung ankommt.';

  @override
  String get donateWeCanTVerify =>
      'wir können diese Blockchain nicht prüfen, ohne einen fremden Dienst nach dir zu fragen, also tun wir es nicht. sende gern, wenn du magst. ein Abzeichen schaltet das nicht frei.';

  @override
  String get donateBitcoinBadgesNeedOnion =>
      'Bitcoin-Abzeichen brauchen den Onion-Modus';

  @override
  String get donateSwitchToOnion => 'Zu Onion wechseln';

  @override
  String get donatePayWithBitcoin => 'Mit Bitcoin zahlen  →';

  @override
  String get donateBadgesStartAt20 => 'Abzeichen ab 20 \$';

  @override
  String get donateReachingThePaymentService =>
      'Verbinde mit dem Zahlungsdienst über tor…';

  @override
  String get donateThisCanTakeUp => 'Das kann bis zu einer Minute dauern';

  @override
  String donateSThisCanTake(Object waited) {
    return '${waited}s · das kann bis zu einer Minute dauern';
  }

  @override
  String get donateUseTheAddressInstead => 'Lieber die Adresse nutzen';

  @override
  String get donateThePaymentServiceIs =>
      'Der Zahlungsdienst ist ein Onion-Dienst, und nur der Onion-Modus erreicht ihn. Es wurde nichts gesendet.';

  @override
  String get donateTorWasSlowTo =>
      'Tor hat den Zahlungsdienst zu langsam erreicht. Du kannst an die Adresse unten spenden - dein Abzeichen wird dann nur nicht automatisch freigeschaltet. Versuche es später erneut, um das Abzeichen zu bekommen.';

  @override
  String get donateThePaymentServiceIsHavingTrouble =>
      'Der Zahlungsdienst hat gerade Probleme. Du kannst trotzdem an die Adresse unten spenden - dein Abzeichen wird dann nur nicht automatisch freigeschaltet. Versuche es später erneut, um das Abzeichen zu bekommen.';

  @override
  String get commonTryAgain => 'Erneut versuchen';

  @override
  String donateBtc(Object btc) {
    return '$btc BTC';
  }

  @override
  String donateSendExactlyThisAmount(Object fmtLeft) {
    return 'Sende genau diesen Betrag · läuft in $fmtLeft ab';
  }

  @override
  String get donateOpenWallet => 'Wallet öffnen';

  @override
  String get donateThisScreenUpdatesItself =>
      'Dieser Bildschirm aktualisiert sich, sobald deine Zahlung erkannt wird.\nLass ihn offen - nichts wird gespeichert, nichts identifiziert dich.';

  @override
  String get donateWatchingTheChainFor =>
      'Suche in der Blockchain nach deiner Zahlung';

  @override
  String get donateThisInvoiceExpired => 'Diese Rechnung ist abgelaufen';

  @override
  String get donateInvoicesTimeOutIf =>
      'Rechnungen laufen ab. Wenn du schon bezahlt hast, lass das hier offen: Wir fragen den Dienst eine Weile lang jede Minute erneut, und noch einmal, wenn du „Unterstützen“ das nächste Mal öffnest. Starte eine neue, wann immer du willst.';

  @override
  String get donateNewInvoice => 'Neue Rechnung';

  @override
  String get donateIPaidCheckAgain => 'Bezahlt, nochmal prüfen';

  @override
  String get donatePaymentConfirmed => 'Zahlung bestätigt';

  @override
  String get donateThankYouForKeeping =>
      'Danke, dass du Kryfo unabhängig hältst.';

  @override
  String donateVerifiedOnChainYou(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter':
          'on-chain verifiziert - du unterstützt Kryfo jetzt als Unterstützer. Das kann dir niemand mehr nehmen.',
      'patron':
          'on-chain verifiziert - du unterstützt Kryfo jetzt als Förderer. Das kann dir niemand mehr nehmen.',
      'guardian':
          'on-chain verifiziert - du unterstützt Kryfo jetzt als Hüter. Das kann dir niemand mehr nehmen.',
      'other':
          'on-chain verifiziert - du unterstützt Kryfo jetzt als Unterstützer. Das kann dir niemand mehr nehmen.',
    });
    return '$_temp0';
  }

  @override
  String get donateWearMyBadge => 'Mein Abzeichen zeigen';

  @override
  String get donateJustGladToHelp => 'Ich helfe einfach gern';

  @override
  String get gettingMessagesGettingMessages => 'Nachrichten empfangen';

  @override
  String get gettingMessagesHowNewMessagesReach =>
      'Wie neue Nachrichten auf dieses Handy kommen. Du kannst das jederzeit ändern.';

  @override
  String get gettingMessagesAlwaysOn => 'Immer an';

  @override
  String get gettingMessagesMostPrivate => 'am privatesten';

  @override
  String get gettingMessagesMessagesArriveInstantlyNothing =>
      'Nachrichten kommen sofort an. Nichts verlässt tor. Braucht am meisten Akku.';

  @override
  String get gettingMessagesCheckIns => 'Check-ins';

  @override
  String get gettingMessagesLightest => 'am sparsamsten';

  @override
  String get gettingMessagesKryfoLooksForMessages =>
      'Kryfo sucht alle 15 Minuten nach Nachrichten. Schont den Akku, aber Nachrichten können verspätet ankommen.';

  @override
  String get gettingMessagesOnTheLockScreen => 'Auf dem Sperrbildschirm';

  @override
  String get gettingMessagesHideMessagePreview =>
      'Nachrichtenvorschau verbergen';

  @override
  String get gettingMessagesAGenericAlertWith =>
      'Ein allgemeiner Hinweis, ohne Absender und ohne Nachrichtentext';

  @override
  String get gettingMessagesShowsMessageTextIn =>
      'Zeigt Nachrichtentext in Benachrichtigungen, auch wenn Kryfo gesperrt ist.';

  @override
  String get gettingMessagesWhenThePhoneSits =>
      'Wenn das Handy still liegt, verteilt Android die Check-ins weiter auseinander. Die Zeile oben zeigt den tatsächlich letzten. Solange Kryfo offen ist, bleibt es verbunden.';

  @override
  String get groupChatJumpToTheNewest => 'Zur neuesten springen';

  @override
  String get groupChatBlockedEverywhere => 'Überall blockiert';

  @override
  String get groupChatYou => 'du';

  @override
  String get groupChatVoiceMessage => 'Sprachnachricht';

  @override
  String get groupChatQuotedPhoto => 'Foto';

  @override
  String get groupChatMessageUnavailable => 'Nachricht nicht verfügbar';

  @override
  String get groupChatTorIsNotUp =>
      'Tor läuft noch nicht · sende ohne Vorschau';

  @override
  String get groupChatCouldnTReachIt =>
      'nicht erreichbar · sende ohne Vorschau';

  @override
  String get groupChatNoTitleCameBack =>
      'Kein Titel erhalten · sende ohne Vorschau';

  @override
  String get groupChatCouldnTFetchIt => 'nicht abrufbar · sende ohne Vorschau';

  @override
  String get groupChatCamera => 'Kamera';

  @override
  String get groupChatGallery => 'Galerie';

  @override
  String get groupChatVideo => 'Video';

  @override
  String get groupChatGifFromPhone => 'GIF vom Handy';

  @override
  String get groupChatFile => 'Datei';

  @override
  String get groupChatCouldNotReadThat => 'Konnte die Datei nicht lesen';

  @override
  String get groupChatGifTooBig8 => 'GIF zu groß · max. 8 MB';

  @override
  String get groupChatCouldNotCleanThat => 'Konnte das GIF nicht bereinigen';

  @override
  String get groupChatFileTooBig8 => 'Datei zu groß · max. 8 MB';

  @override
  String get groupChatCouldNotCleanThatVideo =>
      'Konnte das Video nicht bereinigen';

  @override
  String get groupChatCouldNotCleanThatPictureSend =>
      'Konnte das Bild nicht bereinigen · sende es als Foto';

  @override
  String get groupChat30Seconds => '30 Sekunden';

  @override
  String get groupChat1Minute => '1 Minute';

  @override
  String get groupChat5Minutes => '5 Minuten';

  @override
  String get groupChat1Hour => '1 Stunde';

  @override
  String get groupChat24Hours => '24 Stunden';

  @override
  String get groupChatBurnTimer => 'Befristete Nachrichten';

  @override
  String get groupChatNewMessagesDisappearAfter =>
      'Neue Nachrichten verschwinden nach dieser Zeit';

  @override
  String get groupChatToday => 'heute';

  @override
  String get groupChatYesterday => 'gestern';

  @override
  String get groupChatYou2 => 'Du';

  @override
  String groupChatThisChatHasPins(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'In diesem Chat sind schon $countString Nachrichten angeheftet',
      one: 'In diesem Chat ist schon $countString Nachricht angeheftet',
    );
    return '$_temp0';
  }

  @override
  String get groupChatUnpinThisMessage => 'Diese Nachricht loslösen?';

  @override
  String get groupChatPinThisMessage => 'Diese Nachricht anheften?';

  @override
  String get groupChatItLeavesThePinned =>
      'Sie verschwindet für alle hier aus der Liste der angehefteten Nachrichten.';

  @override
  String get groupChatItGoesUnderThe =>
      'Sie erscheint für alle hier oben im Chat bei den angehefteten Nachrichten.';

  @override
  String get groupChatUnpin => 'Loslösen';

  @override
  String get groupChatPinIt => 'Anheften';

  @override
  String get groupChatNotNow => 'Nicht jetzt';

  @override
  String get groupChatSaved => 'Gespeichert';

  @override
  String get groupChatRemovedFromSaved => 'Aus Gespeichert entfernt';

  @override
  String get groupChatForwardTo => 'Weiterleiten an';

  @override
  String get groupChatNoContactsToForward => 'Keine Kontakte zum Weiterleiten';

  @override
  String get groupChatEditMessage => 'Nachricht bearbeiten';

  @override
  String get groupChatUnsendMessage => 'Nachricht zurückholen';

  @override
  String get groupChatItDisappearsWithNo =>
      'Sie verschwindet spurlos. Das lässt sich nicht rückgängig machen.';

  @override
  String get groupChatUnsend => 'Zurückholen';

  @override
  String groupChatThisRoomAndEverything(Object expiryWords) {
    return 'Dieser Raum und alles darin verschwindet in $expiryWords';
  }

  @override
  String groupChatGhostModeOnBurns(Object fmtBurn) {
    return 'Befristete Nachrichten · verschwinden nach $fmtBurn';
  }

  @override
  String get groupChatGroupCreatedSayHi => 'Gruppe erstellt. Sag hallo.';

  @override
  String get groupChatNoMessagesYet => 'Noch keine Nachrichten.';

  @override
  String get groupChatThisMessageCanT =>
      'Diese Nachricht kann nicht angezeigt werden';

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
    return '$s T';
  }

  @override
  String groupChatHere(int count, Object time) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$time · $countString hier',
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
      other: '$countString Mitglieder',
      one: '$countString Mitglied',
    );
    return '$_temp0';
  }

  @override
  String get groupChatSearchThisChat => 'Diesen Chat durchsuchen';

  @override
  String groupChatReplyingTo(Object name) {
    return 'Antwort an $name';
  }

  @override
  String get groupChatReplyingToYou => 'Antwort an dich';

  @override
  String get groupChatTimedMessages => 'Befristete Nachrichten';

  @override
  String get groupChatOpenTheCamera => 'Kamera öffnen';

  @override
  String get groupChatAttachAPhoto => 'Foto anhängen';

  @override
  String get groupChatMessage => 'Nachricht';

  @override
  String get groupChatDisguiseVoice => 'Stimme verfremden';

  @override
  String get groupChatSupporter => 'Unterstützer';

  @override
  String get groupChatEdited => 'Bearbeitet';

  @override
  String get groupChatTapToRetry => '! nochmal tippen';

  @override
  String get groupChat0s => '0 s';

  @override
  String get groupChatReply => 'Antworten';

  @override
  String get groupChatPin => 'Anheften';

  @override
  String get groupChatUnsave => 'Speichern aufheben';

  @override
  String get groupChatForward => 'Weiterleiten';

  @override
  String get groupInfoGroup => 'Gruppe';

  @override
  String get groupInfoRenameGroup => 'Gruppe umbenennen';

  @override
  String get groupInfoRename => 'Umbenennen';

  @override
  String get groupInfoNoContactsToAdd => 'Niemand zum Hinzufügen';

  @override
  String get groupInfoCouldNotAdd => 'Nicht hinzugefügt';

  @override
  String groupInfoRemove(Object haloId) {
    return '$haloId entfernen?';
  }

  @override
  String get groupInfoTheyWillStopReceiving =>
      'Die Person bekommt dann keine Nachrichten mehr aus dieser Gruppe.';

  @override
  String get commonRemove => 'Entfernen';

  @override
  String get groupInfoClearThisConversation => 'Diesen Verlauf leeren?';

  @override
  String get groupInfoEveryMessageHereIs =>
      'Jede Nachricht hier wird von diesem Handy gelöscht. Das leert nur deine Kopie, die anderen Mitglieder behalten ihre.';

  @override
  String get groupInfoClear => 'Leeren';

  @override
  String get groupInfoConversationCleared => 'Verlauf geleert';

  @override
  String get groupInfoLeaveRoom => 'Raum verlassen?';

  @override
  String get groupInfoLeaveGroup => 'Gruppe verlassen?';

  @override
  String get groupInfoEverythingInItIs =>
      'Alles darin wird jetzt von diesem Handy gelöscht, und der Schlüssel, den du hier benutzt hast, ist endgültig weg.';

  @override
  String get groupInfoYouWillStopReceiving =>
      'Du bekommst keine Nachrichten mehr, und die anderen Mitglieder sehen, dass du gehst.';

  @override
  String get groupInfoLeave => 'Verlassen';

  @override
  String get groupInfoGroupInfo => 'Gruppeninfo';

  @override
  String groupInfo1Member(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString Mitglieder',
      one: '$countString Mitglied',
    );
    return '$_temp0';
  }

  @override
  String get groupInfoAdmin => 'Admin';

  @override
  String get groupInfoMembers2 => 'Mitglieder';

  @override
  String get groupInfoInvite => 'Einladen';

  @override
  String get commonAdd => 'Hinzufügen';

  @override
  String get groupInfoYou => 'Du';

  @override
  String get groupInfoRemoveFromGroup => 'Aus Gruppe entfernen';

  @override
  String get groupInfoWallpaper => 'Hintergrund';

  @override
  String get groupInfoSharedMedia => 'Geteilte Medien';

  @override
  String get groupInfoClearConversation => 'Verlauf leeren';

  @override
  String get groupInfoLeaveRoom2 => 'Raum verlassen';

  @override
  String get groupInfoLeaveGroup2 => 'Gruppe verlassen';

  @override
  String get groupInfoAddMembers => 'Mitglieder hinzufügen';

  @override
  String groupInfoAdd(Object pickedLength) {
    return '$pickedLength hinzufügen';
  }

  @override
  String handleYouAre(Object h) {
    return 'Du bist @$h';
  }

  @override
  String get handleHandleDeletedThePage =>
      'Benutzername gelöscht · die Seite ist weg';

  @override
  String get handlePublicHandle => 'Öffentlicher Benutzername';

  @override
  String get handleOptionalYourThreeWords =>
      'Optional. Deine drei Wörter funktionieren so oder so weiter.';

  @override
  String get handleWren => 'amsel';

  @override
  String get handleALineAboutYou => 'Eine Zeile über dich · optional';

  @override
  String get handleClaiming => 'Wird gesichert…';

  @override
  String get handleClaimThisHandle => 'Benutzernamen sichern';

  @override
  String get handleAnyoneWithThisLink =>
      'Wer diesen Link hat, kann einen privaten Chat mit dir beginnen. Er enthält deine Einladung und sonst nichts.';

  @override
  String get handleLinkCopied => 'Link kopiert';

  @override
  String get handleDeleteThisHandle => 'Diesen Benutzernamen löschen';

  @override
  String get handleChecking => 'Prüfe…';

  @override
  String get handleAvailable => '✓ verfügbar';

  @override
  String get handleAlreadyTaken => 'schon vergeben';

  @override
  String get handleWhatAHandleDoes => 'Was ein Benutzername bewirkt';

  @override
  String get handleAnyoneWhoKnowsIt =>
      'Wer ihn kennt, kann anfragen, dir zu schreiben, und genau dafür ist er da. Die Seite enthält deine Einladung und die Zeile, die du geschrieben hast, sonst nichts, und führt kein Protokoll darüber, wer sie liest. Du kannst ihn jederzeit löschen.';

  @override
  String handleIsNotYoursOn(Object handle) {
    return '@$handle gehört auf diesem Handy nicht dir';
  }

  @override
  String handleTheRegistryHoldsIt(Object handle) {
    return 'Das Verzeichnis führt ihn unter einem anderen Schlüssel, höchstwahrscheinlich einer Identität, die dieses Handy vor einer Wiederherstellung hatte. Wer @$handle hinzufügt, erreicht nicht dich. Er kann von hier aus weder freigegeben noch aktualisiert werden. Wähle einen anderen Namen.';
  }

  @override
  String get handleForgetItOnThis => 'Auf diesem Handy vergessen';

  @override
  String get homeAddAContact => 'Kontakt hinzufügen';

  @override
  String get commonSettings => 'Einstellungen';

  @override
  String get homeYourKryfo => 'Dein Kryfo';

  @override
  String homeDateWeekday(Object weekday) {
    return '$weekday,';
  }

  @override
  String get homeAnHour => 'einer Stunde';

  @override
  String homeHours(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString Stunden',
      one: '$countString Stunde',
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
      other: '$countString Minuten',
      one: '$countString Minute',
    );
    return '$_temp0';
  }

  @override
  String get homeKryfoIsOffline => 'Kryfo ist offline';

  @override
  String homeTorHasNotBeen(Object howLong) {
    return 'Tor konnte sich seit $howLong nicht verbinden. Bis es klappt, kann nichts ankommen oder rausgehen.';
  }

  @override
  String get homeReconnecting => 'Verbinde neu';

  @override
  String get homeReconnect => 'Neu verbinden';

  @override
  String get homeWhatIsWrong => 'Was ist los';

  @override
  String get homeKryfoWillCheckIn =>
      'Kryfo macht alle 15 Minuten einen Check-in';

  @override
  String get homeYourPhoneKeepsStopping =>
      'Dein Handy beendet Kryfo immer wieder';

  @override
  String get homeItHasClosedKryfo =>
      'Es hat Kryfo heute dreimal geschlossen, deshalb kamen Nachrichten verspätet oder mussten warten. Check-ins überstehen das: Kryfo wacht alle 15 Minuten auf, statt verbunden zu bleiben.';

  @override
  String get homeSwitchToCheckIns => 'Zu Check-ins wechseln';

  @override
  String get homeNotNow => 'Nicht jetzt';

  @override
  String get homeNotificationsAreOff => 'Benachrichtigungen sind aus';

  @override
  String get homeAndroidIsBlockingThem =>
      'Android blockiert sie, deshalb erreicht dich nichts, solange Kryfo geschlossen ist. Nachrichten kommen trotzdem an, wenn du es öffnest.';

  @override
  String get homeCouldnTOpenIt =>
      'Ließ sich nicht öffnen. Such Kryfo in den Handy-Einstellungen';

  @override
  String get homeTurnThemOn => 'Einschalten';

  @override
  String get homeLeaveThemOff => 'Aus lassen';

  @override
  String get homeOurRelayIsQuiet => 'Unser Relais schweigt';

  @override
  String get homeRelayModeUsesOnly =>
      'Der Relais-Modus nutzt nur unser eigenes Relais, und das antwortet gerade nicht. Der Schnell-Modus nimmt öffentliche Relais dazu, damit Nachrichten trotzdem ankommen. So oder so bleibt alles versiegelt.';

  @override
  String get homeSwitchedToFast => 'Zu Schnell gewechselt';

  @override
  String get homeUseFastMode => 'Schnell-Modus nutzen';

  @override
  String get homeKeepWaiting => 'Weiter warten';

  @override
  String get homeNotConnecting => 'Keine Verbindung';

  @override
  String get homeBridgesAreOnAnd =>
      'Brücken sind an, und tor kommt immer noch nicht durch. Brücken sind langsamer, und manche fallen ohne Vorwarnung aus. Wenn dein Netzwerk tor nicht blockiert, ist eine direkte Verbindung schneller und zuverlässiger.';

  @override
  String get homeGoingDirectReconnecting => 'Direkte Verbindung · verbinde neu';

  @override
  String get homeTurnBridgesOff => 'Brücken ausschalten';

  @override
  String get homeStillTrying => 'Versuche es weiter';

  @override
  String get homeTorIsNotGetting =>
      'Tor kommt nicht durch. Manche Netzwerke blockieren es absichtlich. Unser eigenes Relais ist eine einfache Verbindung und klappt meistens trotzdem - oder Brücken, die länger zum Einrichten brauchen.';

  @override
  String get homeSwitchedToRelay => 'Zu Relais gewechselt';

  @override
  String get homeUseOurRelay => 'Unser Relais nutzen';

  @override
  String get homeBridges => 'Brücken';

  @override
  String get homeOffline => 'Offline';

  @override
  String get homeWaiting => 'Wartet';

  @override
  String get homeNothingWaitingToSend => 'Nichts wartet aufs Senden';

  @override
  String homeWaitingSendsWhenYou(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString warten · gehen raus, sobald du zurück bist',
      one: '$countString wartet · geht raus, sobald du zurück bist',
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
      other: '$countString warten · tor verbindet noch',
      one: '$countString wartet · tor verbindet noch',
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
      other: '$countString warten · bis du auch hinzugefügt wirst',
      one: '$countString wartet · bis du auch hinzugefügt wirst',
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
          '$countString warten · $parkedString davon, bis du auch hinzugefügt wirst',
      one:
          '$countString wartet · $parkedString davon, bis du auch hinzugefügt wirst',
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
      other: '$countString warten · werden gerade gesendet',
      one: '$countString wartet · wird gerade gesendet',
    );
    return '$_temp0';
  }

  @override
  String get commonRetry => 'Wiederholen';

  @override
  String get homeNoKryfosYet => 'Noch keine Kryfos.';

  @override
  String get homeScanTheirCodeSend =>
      'Scanne den Code der Person, schick ihr einen Link oder gib den @Benutzernamen ein, den sie dir gegeben hat.';

  @override
  String get homeAddSomeone => 'Jemanden hinzufügen';

  @override
  String get homeArchived => 'Archiv';

  @override
  String home1Chat(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString Chats',
      one: '$countString Chat',
    );
    return '$_temp0';
  }

  @override
  String get homeGroups => 'Gruppen';

  @override
  String get homeRoom => 'Raum';

  @override
  String get homeNew => 'Neu';

  @override
  String homeRoomExpired(Object expiredRoomName) {
    return '$expiredRoomName · Raum abgelaufen';
  }

  @override
  String get homeMentionedYou => 'Hat dich erwähnt';

  @override
  String homeMembers(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString Mitglieder',
      one: '$countString Mitglied',
    );
    return '$_temp0';
  }

  @override
  String get homeSupporter => 'Unterstützer';

  @override
  String get homeArchivedChats => 'Archivierte Chats';

  @override
  String get homeUnmute => 'Stummschaltung aufheben';

  @override
  String get homeMute => 'Stummschalten';

  @override
  String get homeArchive => 'Archivieren';

  @override
  String get homeDeleteChat => 'Chat löschen';

  @override
  String get homeMessagesAndContactGone =>
      'Nachrichten und Kontakt, weg von diesem Handy';

  @override
  String get homeDeleteThisChat => 'Diesen Chat löschen?';

  @override
  String homeEveryMessageWithGoes(Object c) {
    return 'Jede Nachricht mit $c wird gelöscht, und die Person ist kein Kontakt mehr. Das leert nur dieses Handy - ihre Kopie bleibt bei ihr. Wenn sie wieder schreibt, landet es in den Anfragen.';
  }

  @override
  String get homeQueued => 'Eingereiht';

  @override
  String get homeBlocked => 'blockiert';

  @override
  String get homeRoomInvite => 'Raum-Einladung';

  @override
  String get homeNow => 'jetzt';

  @override
  String homeM(Object inMinutes) {
    return '$inMinutes min';
  }

  @override
  String homeH(Object inHours) {
    return '$inHours h';
  }

  @override
  String get homeYesterday => 'gestern';

  @override
  String homeD(Object inDays) {
    return '$inDays T';
  }

  @override
  String get homeNoteToSelf => 'Notiz an mich';

  @override
  String get homeOnlyOnThisPhone => 'Nur auf diesem Handy';

  @override
  String get homeSaved => 'Gespeichert';

  @override
  String get homeKeptFromEveryChat => 'Aus allen Chats aufbewahrt';

  @override
  String get homeRequests => 'Anfragen';

  @override
  String home1PersonWantsTo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString Personen wollen dich erreichen',
      one: '$countString Person will dich erreichen',
    );
    return '$_temp0';
  }

  @override
  String introduceGotItButCould(Object b, Object c) {
    return '$b hat es bekommen, aber $c war nicht erreichbar';
  }

  @override
  String introduceGotItButCouldNotBe(Object c, Object b) {
    return '$c hat es bekommen, aber $b war nicht erreichbar';
  }

  @override
  String get introduceCouldNotReachEither =>
      'Keiner der beiden war erreichbar. Versuche es später erneut';

  @override
  String introduceIntroduceTo(Object peerName) {
    return '$peerName jemandem vorstellen...';
  }

  @override
  String get introduceBothOfThemGet =>
      'Beide bekommen jeweils die Karte der anderen Person. Keine Seite sieht, wie du die andere genannt hast.';

  @override
  String get introduceNoOneElseTo =>
      'Noch niemand sonst zum Vorstellen. Füge zuerst einen weiteren Kontakt hinzu.';

  @override
  String get introduceANoteLikeMy =>
      'Eine Notiz, z. B. „mein Cousin“ - optional';

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
      other: 'Diese Woche noch $leftString von $maxString Vorstellungen übrig',
      one: 'Diese Woche noch $leftString von $maxString Vorstellung übrig',
    );
    return '$_temp0';
  }

  @override
  String introduceNoIntroductionsLeftNext(Object refillPhrase) {
    return 'Keine Vorstellungen mehr übrig. Die nächste wird $refillPhrase frei';
  }

  @override
  String get introduceIntroduce => 'Vorstellen';

  @override
  String get keyVerificationSafetyNumber => 'Sicherheitsnummer';

  @override
  String keyVerificationWith(Object peerName) {
    return 'Mit $peerName';
  }

  @override
  String keyVerificationIfSeesTheSame(Object peerName) {
    return 'Wenn $peerName dieselbe Nummer sieht, sind eure Nachrichten nur zwischen euch beiden privat. Persönlich oder in einem Anruf, dem du vertraust, zu vergleichen ist der sicherste Weg, um sicherzugehen - aber es ist optional und nie Pflicht zum Chatten.';
  }

  @override
  String get keyVerificationVerified => 'Verifiziert';

  @override
  String get keyVerificationMarkAsVerified => 'Als verifiziert markieren';

  @override
  String get lockFileThatPasswordDoesNot => 'Dieses Passwort öffnet sie nicht.';

  @override
  String get lockFileThisFileIsDamaged => 'Diese Datei ist beschädigt.';

  @override
  String get lockFileThisFileWasLocked =>
      'Diese Datei wurde mit einem Schlüssel verschlossen, nicht mit einem Passwort.';

  @override
  String get lockFileThisIsNotA => 'Das ist keine verschlossene Datei.';

  @override
  String get lockFileNotEnoughFreeMemory =>
      'Gerade ist nicht genug Arbeitsspeicher frei.';

  @override
  String get lockFileStopped => 'Gestoppt.';

  @override
  String get lockFileItNeedsAPassword => 'Sie braucht ein Passwort.';

  @override
  String get lockFileKryfoCouldNotRead =>
      'Kryfo konnte die Datei nicht lesen oder schreiben.';

  @override
  String get lockFileCheckCapitalsAndSpaces =>
      'Achte auf Groß- und Kleinschreibung und Leerzeichen. Niemand kann es zurücksetzen, auch wir nicht.';

  @override
  String get lockFileItMayHaveBeen =>
      'Sie wurde unterwegs vielleicht abgeschnitten. Bitte darum, sie noch einmal zu schicken. Es wurde nichts gespeichert.';

  @override
  String get lockFileItOpensWithThe =>
      'Sie öffnet sich mit der Schlüsseldatei der Person, für die sie gemacht wurde, im age-Programm auf einem Computer. Kryfo öffnet die Art mit Passwort.';

  @override
  String get lockFileKryfoOpensFilesLocked =>
      'Kryfo öffnet Dateien, die mit age verschlossen wurden. Die enden meist auf .age.';

  @override
  String get lockFileCloseAFewApps =>
      'Schließe ein paar Apps und versuche es erneut. Die Passwortprüfung braucht kurz ein paar hundert Megabyte.';

  @override
  String get lockFileNothingWasSaved => 'Es wurde nichts gespeichert.';

  @override
  String get lockFileTypeOneOrLet =>
      'Gib eins ein oder lass dir von Kryfo vier Wörter vorschlagen.';

  @override
  String get lockFileTheAppThatHolds =>
      'Die App, in der sie liegt, hat sie vielleicht zurückgenommen. Wähle sie noch einmal.';

  @override
  String get lockFileHidePassword => 'Passwort verbergen';

  @override
  String get lockFileShowPassword => 'Passwort anzeigen';

  @override
  String get lockFileChangeFile => 'Andere Datei';

  @override
  String get lockFileChange => 'Ändern';

  @override
  String lockFileOf(Object prettySize, Object prettySize2) {
    return '$prettySize von $prettySize2';
  }

  @override
  String get lockFileEverythingStaysOnThis => 'Alles bleibt auf diesem Handy.';

  @override
  String get lockFileCouldNotMakeOne =>
      'Konnte keins erstellen. Gib selbst eins ein.';

  @override
  String get lockFileWriteItDownBefore =>
      'Schreib es auf, bevor du die Datei verschließt';

  @override
  String get lockFileNoAppOnThis =>
      'Keine App auf diesem Handy hat die Datei angenommen.';

  @override
  String get lockFileSaved => 'Gespeichert';

  @override
  String get lockFileCouldNotSaveIt =>
      'Konnte sie dort nicht speichern. Versuche einen anderen Ordner.';

  @override
  String get lockFileLocked => 'Verschlossen';

  @override
  String get lockFileLockAFile => 'Datei verschließen';

  @override
  String get lockFileMixingThePassword => 'Mische das Passwort';

  @override
  String get lockFileLocking => 'Verschließe';

  @override
  String get lockFileSaveToFiles => 'In Dateien speichern';

  @override
  String get lockFileLockFile => 'Verschließen';

  @override
  String get lockFileOnePassword => 'Ein Passwort.';

  @override
  String get lockFileNothingElseOpensIt => 'Nichts anderes öffnet sie.';

  @override
  String get lockFileFile => 'Datei';

  @override
  String lockFileFromFiles(Object prettySize) {
    return '$prettySize · aus Dateien';
  }

  @override
  String get lockFileFromFiles2 => 'Aus Dateien';

  @override
  String get lockFilePassword => 'Passwort';

  @override
  String get lockFileSuggestFourWords => 'Vier Wörter vorschlagen';

  @override
  String get lockFileTypeItAgain => 'Nochmal eingeben';

  @override
  String get lockFileTheTwoDoNot => 'Die beiden stimmen noch nicht überein.';

  @override
  String get lockFileHideTheFileName => 'Dateinamen verbergen';

  @override
  String lockFileItWillBeCalled(Object name) {
    return 'Sie heißt dann „$name“. Sag der Person, was für eine Datei es ist.';
  }

  @override
  String get lockFileTheNameAloneCan =>
      'Schon der Name kann verraten, was drin ist.';

  @override
  String get lockFileAnyoneWithThePassword =>
      'Wer das Passwort hat, kann sie öffnen, in Kryfo oder auf jedem Computer mit dem kostenlosen Tool age. Vergisst du es, ist die Datei für immer verloren. Niemand kann es zurücksetzen, auch wir nicht.';

  @override
  String get lockFileLocked2 => 'Verschlossen.';

  @override
  String get lockFileOnlyThePasswordOpens => 'Nur das Passwort öffnet sie.';

  @override
  String lockFileSafeToEmailOr(Object prettySize) {
    return '$prettySize · sicher für E-Mail oder USB-Stick';
  }

  @override
  String get lockFileNoKryfoOnThe =>
      'Kein Kryfo auf der anderen Seite? Auf einem Computer:';

  @override
  String get lockFileItAsksForThe =>
      'Es fragt nach dem Passwort. age gibt es kostenlos auf age-encryption.org';

  @override
  String lockTooManyTriesS(Object lockState) {
    return 'Zu viele Versuche · ${lockState}s';
  }

  @override
  String get lockNotIt => 'Nicht richtig';

  @override
  String get lockYourPin => 'Deine PIN';

  @override
  String get lockUseFingerprint => 'Fingerabdruck nutzen';

  @override
  String get lockSetupUnlockWithFingerprint => 'Mit Fingerabdruck entsperren?';

  @override
  String get lockSetupThePinStillWorks =>
      'Die PIN funktioniert weiterhin, wann immer du willst. Das hier ist nur schneller.';

  @override
  String get lockSetupUseFingerprint => 'Fingerabdruck nutzen';

  @override
  String get lockSetupPinOnly => 'Nur PIN';

  @override
  String get lockSetupOnceMore => 'Noch einmal';

  @override
  String get lockSetupSetAPin => 'PIN festlegen';

  @override
  String get lockSetupThoseWereDifferentFrom =>
      'Die waren verschieden. Noch mal von vorn.';

  @override
  String get lockSetupTheSameFourDigits => 'Dieselben Ziffern noch einmal';

  @override
  String get lockSetupFourDigitsAnythingYou =>
      'Vier Ziffern oder mehr, die du dir merken kannst';

  @override
  String get modesOnion => 'Onion';

  @override
  String get modesFullOnionRoutingThree =>
      'Volles Onion-Routing, drei Stationen. Eine Nachricht braucht zwei bis fünf Sekunden. Niemand sieht, mit wem du sprichst.';

  @override
  String get modesSlower => 'langsamer';

  @override
  String get modesRelay => 'Relais';

  @override
  String get modesOneSealedConnectionTo =>
      'Eine versiegelte Verbindung zu Kryfos eigenem Relais, wie ein VPN, das nichts zu protokollieren hat. Nachrichten kommen in etwa einer Sekunde an, und es funktioniert, wo tor blockiert ist.';

  @override
  String get modesQuick => 'zügig';

  @override
  String get modesRelayOnly => 'Nur Relais';

  @override
  String get modesFast => 'Schnell';

  @override
  String get modesPlainConnectionsToEvery =>
      'Einfache Verbindungen zu jedem Relais. Fast sofort, und der am wenigsten private der drei Modi.';

  @override
  String get modesInstant => 'sofort';

  @override
  String get modesEveryRelayYouUse =>
      'Jedes Relais, das du nutzt, kennt die Adresse, von der aus du dich verbindest, nicht nur unseres. Nachrichten bleiben versiegelt, aber dass du eine gesendet hast, nicht. Standardmäßig aus, und nach einer Neuinstallation wieder aus.';

  @override
  String get modesSpeed => 'Tempo';

  @override
  String get modesPrivacy => '& Privatsphäre';

  @override
  String get modesChangeGloballyOrPer => 'Global ändern oder pro Chat';

  @override
  String get modesSoon => 'Bald';

  @override
  String get modesActive => 'Aktiv';

  @override
  String get modesSpeed2 => 'TEMPO';

  @override
  String get modesHops => 'STATIONEN';

  @override
  String get modesIp => 'IP';

  @override
  String get modesVisible => 'Sichtbar';

  @override
  String get modesHidden => 'verborgen';

  @override
  String modesHeadsUp(Object warning) {
    return '*Achtung:* $warning';
  }

  @override
  String get modesOnionIsTheDefault =>
      'Onion ist der Standard und bleibt es, solange du es nicht änderst. Ein Wechsel gilt ab der nächsten Nachricht.';

  @override
  String get modesFastMode => 'Schnell-Modus';

  @override
  String get modesPlainConnectionsToEveryRelayQuicker =>
      'Einfache Verbindungen zu jedem Relais. Schneller, und die Relais können deine IP-Adresse sehen. Nachrichten bleiben so oder so Ende-zu-Ende-verschlüsselt.';

  @override
  String get modesTurnOnFastMode => 'Schnell-Modus einschalten';

  @override
  String get modesKeepItOff => 'Aus lassen';

  @override
  String get movedWipeThisPhone => 'Kryfo von diesem Handy löschen?';

  @override
  String get movedEverythingKryfoHoldsHere =>
      'Alles, was Kryfo hier hat, wird gelöscht: die Nachrichten, die Kontakte, die Schlüssel. Das andere Gerät behält alles. Das lässt sich nicht rückgängig machen.';

  @override
  String get movedWipeIt => 'Löschen';

  @override
  String get movedNotMovingAfterAll => 'Doch nicht umziehen?';

  @override
  String get movedOnlyDoThisIf =>
      'Tu das nur, wenn das Backup nirgends importiert wurde. Wenn doch, haben jetzt zwei Geräte dieselbe Identität, und auf beiden werden Nachrichten verloren gehen.';

  @override
  String get movedIMStayingHere => 'Ich bleibe hier';

  @override
  String get movedStayingHere => 'Du bleibst hier';

  @override
  String movedKryfoWillCloseNow(Object myId) {
    return 'Kryfo schließt sich jetzt. Tippe auf das Symbol, um es als $myId wieder zu öffnen.';
  }

  @override
  String get movedReopenKryfo => 'Kryfo wieder öffnen';

  @override
  String get movedThisKryfoHasMoved => 'Dieses Kryfo ist umgezogen';

  @override
  String movedIsNowOnAnother(Object myId) {
    return '$myId ist jetzt auf einem anderen Gerät. Dieses Handy kann noch zeigen, was hier war, aber hier kommt nichts Neues mehr an, und was du von hier sendest, erreicht niemanden.';
  }

  @override
  String get movedKeepItToRead => 'Zum Lesen behalten';

  @override
  String get movedWipeThisPhone2 => 'Kryfo von diesem Handy löschen';

  @override
  String get movedIMNotMoving => 'Ich ziehe doch nicht um';

  @override
  String get myKryfoAHandleIs3 =>
      'Ein Benutzername hat 3 bis 20 Buchstaben, Ziffern oder _';

  @override
  String get myKryfoInviteCopiedClearsIn =>
      'Einladung kopiert · verschwindet in 60s';

  @override
  String myKryfoAddMeOnKryfo(Object myId, Object uri) {
    return 'Füg mich auf Kryfo hinzu. Meine ID ist $myId\n\nTippe, um mich hinzuzufügen:\n$uri\n\nKryfo ist ein privater Messenger. Keine Telefonnummer, keine E-Mail.';
  }

  @override
  String get myKryfoAddMeOnKryfo2 => 'Füg mich auf Kryfo hinzu';

  @override
  String get myKryfoAddSomeone => 'Jemanden hinzufügen';

  @override
  String get myKryfoKryfoDoesnTScan =>
      'Kryfo durchsucht deine Kontakte nicht, genau darum geht es.';

  @override
  String get myKryfoIfThisLinkEnds =>
      'Wenn dieser Link irgendwo landet, wo er nicht hin sollte, setz ihn in den Einstellungen zurück. Alle, die ihn haben, brauchen dann einen neuen.';

  @override
  String get myKryfoAlreadyShareAFriend =>
      'Ihr kennt beide schon jemanden auf Kryfo? Diese Person kann euch aus ihrem Chat einander vorstellen, und ihr überspringt die Anfrage.';

  @override
  String get myKryfoHandleCopied => 'Benutzername kopiert';

  @override
  String get myKryfoTheyReHereWith => 'die Person ist hier bei mir';

  @override
  String get myKryfoPointYourPhonesAt =>
      'Richtet eure Handys aufeinander. Nichts läuft über einen Server.';

  @override
  String get myKryfoScanTheirsInstead => 'Stattdessen Code scannen';

  @override
  String get myKryfoTheyReadYouA => 'Man liest dir einen Code vor';

  @override
  String get myKryfoTheyReSomewhereElse => 'die Person ist woanders';

  @override
  String get myKryfoSendThemALink =>
      'Schick einen Link. Er öffnet direkt das Hinzufügen.';

  @override
  String get myKryfoYourLinkAppearsOnce =>
      'Dein Link erscheint, sobald du verbunden bist';

  @override
  String get myKryfoTheLinkCarriesYour =>
      'Der Link enthält deine ID, deine Adresse und die Schlüssel, um einen Chat zu beginnen. Er funktioniert, bis du ihn in den Einstellungen zurücksetzt.';

  @override
  String get myKryfoSendTheLink => 'Link senden';

  @override
  String get myKryfoAsACard => 'Als Karte';

  @override
  String get myKryfoAnImageWithThe => 'Ein Bild mit dem QR-Code';

  @override
  String get myKryfoAsAFile => 'Als Datei';

  @override
  String get myKryfoContactFile => 'Kontaktdatei';

  @override
  String get myKryfoIKnowTheirHandle => 'Ich kenne den Benutzernamen';

  @override
  String get myKryfoTypeTheNameThey =>
      'Gib den @Namen ein, den du bekommen hast. Klappt, wenn die Person einen gesichert hat.';

  @override
  String get myKryfoWren => 'Amsel';

  @override
  String get myKryfoTheLookupAsksFor =>
      'Die Suche schickt nur diesen einen Namen und nichts über dich. Deine erste Nachricht kommt bei der Person trotzdem als Anfrage an.';

  @override
  String get myKryfoLooking => 'Suche…';

  @override
  String get myKryfoFindThem => 'Finden';

  @override
  String get myKryfoYourAddressAppearsOnce =>
      'Deine Adresse erscheint, sobald du verbunden bist';

  @override
  String get myKryfoAPublicHandle => 'Öffentlicher Benutzername';

  @override
  String get myKryfoPutItInA =>
      'Schreib ihn in eine Bio. Wer ihn kennt, kann dich finden.';

  @override
  String get myKryfoANamePeopleCan =>
      'Ein Name, unter dem man dich finden kann. Aus, bis du einen sicherst.';

  @override
  String get newGroupCouldNotCreate => 'Erstellen fehlgeschlagen';

  @override
  String get newGroupNewGroup => 'Neue Gruppe';

  @override
  String get newGroupCreating => 'Erstelle…';

  @override
  String get newGroupCreate => 'Erstellen';

  @override
  String get newGroupGroupName => 'Gruppenname';

  @override
  String get newGroupMembers => 'Mitglieder';

  @override
  String get newGroupPickAtLeastOne => 'Mindestens eine wählen';

  @override
  String newGroupSelected(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString ausgewählt',
    );
    return '$_temp0';
  }

  @override
  String get newGroupAddAtLeastOne =>
      'Füge zuerst mindestens einen Kontakt hinzu, bevor du eine Gruppe erstellst.';

  @override
  String get notesToday => 'HEUTE';

  @override
  String get notesYesterday => 'GESTERN';

  @override
  String get notesNoteToSelf => 'Notiz an mich';

  @override
  String get notesOnlyOnThisPhone => 'Nur auf diesem Handy';

  @override
  String get notesAQuietPlace => 'Ein stiller Ort';

  @override
  String get notesJotAnythingDownIt =>
      'Schreib auf, was du willst. Es bleibt auf diesem Handy und verlässt es nie.';

  @override
  String get notesJotSomethingDown => 'Schreib etwas auf…';

  @override
  String get onboardingPrivateByDefault => 'PRIVAT VON ANFANG AN';

  @override
  String get onboardingPrivateMessaging =>
      'Private Nachrichten,\n*ohne Haken*.';

  @override
  String get onboardingYourNameIsThree =>
      '*Dein Name besteht aus drei Wörtern.* Keine Telefonnummer, keine E-Mail, kein Adressbuch.';

  @override
  String get onboardingNobodyGetsInUnless =>
      '*Niemand kommt rein, außer du lässt es zu.* Es gibt keine Suche. Leute werden von Hand hinzugefügt, in beide Richtungen.';

  @override
  String get onboardingTheFirstConnectionTakes =>
      '*Die erste Verbindung dauert eine Minute.* Kryfo baut eine private Route auf, bevor es sendet. Danach geht es schnell.';

  @override
  String get onboardingBegin => 'Loslegen';

  @override
  String get onboardingHaveABackupRestore =>
      'Backup vorhanden? Wiederherstellen →';

  @override
  String get onboardingKryfoIsOpenSource => 'Kryfo ist Open Source';

  @override
  String get onboardingYourKryfoId => 'DEINE KRYFO-ID';

  @override
  String get onboardingGeneratedFromAKey =>
      'Erzeugt aus einem Schlüssel, der nur auf diesem Handy liegt. *Einprägsam, einzigartig, nur deins.* Niemand sonst hat diese ID.';

  @override
  String get onboardingTryAnother => 'Andere probieren';

  @override
  String get onboardingUseThisName => 'Diesen Namen nehmen →';

  @override
  String get onboardingThreeWords => 'Drei Wörter. *Nur deine.*';

  @override
  String get onboardingPickA => 'Wähle ein *Gesicht*.';

  @override
  String get onboardingDrawnOnThisPhone =>
      'Auf diesem Handy aus einer Zahl gezeichnet, nie hochgeladen. Ändere es, wann immer du willst.';

  @override
  String get onboardingThePeopleYouMessage =>
      'Die Leute, denen du schreibst, sehen das auch';

  @override
  String get onboardingKeepMyInitial => 'Initiale behalten';

  @override
  String get onboardingThatOne => 'Das hier →';

  @override
  String get onboardingContinue => 'Weiter →';

  @override
  String get onboardingHowYourMessages => 'Wie deine Nachrichten *reisen*.';

  @override
  String get onboardingYouCanChangeThis =>
      'Du kannst das jederzeit in den Einstellungen ändern, für alle oder für einen Chat.';

  @override
  String get onboardingOnion => 'Onion';

  @override
  String get onboardingSlowerAMessageTakes =>
      'Langsamer. Eine Nachricht braucht zwei bis fünf Sekunden.';

  @override
  String get onboardingHidesYourAddressFrom =>
      'Verbirgt deine Adresse vor allen, auch vor unserem Relais.';

  @override
  String get onboardingRelay => 'Relais';

  @override
  String get onboardingOurRelaySeesYour =>
      'Unser Relais sieht deine Adresse. Sonst niemand.';

  @override
  String get onboardingAboutASecondWorks =>
      'Etwa eine Sekunde. Funktioniert, wo tor blockiert ist.';

  @override
  String get onboardingFast => 'Schnell';

  @override
  String get onboardingEveryRelayYouUse =>
      'Jedes Relais, das du nutzt, sieht deine Adresse. Der am wenigsten private der drei.';

  @override
  String get onboardingNearInstant => 'Fast sofort.';

  @override
  String get onboardingKeepOnion => 'Onion behalten →';

  @override
  String get onboardingUseThis => 'Das nehmen →';

  @override
  String get onboardingSkipOnionIsA =>
      'Überspringen · Onion ist ein guter Standard';

  @override
  String get onboardingThreeThingsThen => 'Drei Dinge,\ndann *bist du drin*.';

  @override
  String get onboardingEverythingElseTheApp =>
      'Alles andere sagt dir die App, wenn es wichtig wird.';

  @override
  String get onboardingYourNameIsThreeWords => 'Dein Name sind drei Wörter';

  @override
  String get onboardingThatIsTheWhole =>
      'Das ist die ganze Identität. Keine Nummer, die durchsickern kann, keine E-Mail für Phishing, nichts zum Nachschlagen. Wer mit dir schreibt, sieht diese Wörter und das Gesicht, das du gewählt hast.';

  @override
  String get onboardingNobodyCanReachYou =>
      'Niemand kann dich erreichen, bis du es erlaubst';

  @override
  String get onboardingAStrangerWithYour =>
      'Jemand Fremdes mit deinen Wörtern kann nur anklopfen. Die erste Nachricht wartet in den Anfragen, bis du ja sagst, und du kannst nein sagen, ohne dass die Person es je erfährt.';

  @override
  String get onboardingTheFirstConnectionTakesAMinute =>
      'Die erste Verbindung dauert eine Minute';

  @override
  String get onboardingKryfoBuildsAPrivateRouteBefore =>
      'Kryfo baut eine private Route auf, bevor es etwas sendet. Solange du offline bist, warten Nachrichten und kommen an, wenn du zurück bist.';

  @override
  String get onboardingYourIdentityLivesOn =>
      'Deine Identität liegt auf diesem Handy. Sichere sie in den Einstellungen, wenn du so weit bist.';

  @override
  String get onboardingIUnderstand => 'Verstanden →';

  @override
  String get onboardingOneQuiet => 'Eine stille *Benachrichtigung*.';

  @override
  String get onboardingAndroidNeedsAVisible =>
      'Android verlangt eine sichtbare Benachrichtigung, solange eine App im Hintergrund lauscht. So erreichen dich Nachrichten, wenn Kryfo geschlossen ist.';

  @override
  String get onboardingSilentAndAtThe =>
      'Lautlos und ganz unten in der Benachrichtigungsleiste';

  @override
  String get onboardingItNeverBuzzesTurn =>
      'Sie vibriert nie. Schaltest du sie aus, warten Nachrichten, bis du die App wieder öffnest.';

  @override
  String get onboardingGotIt => 'Alles klar →';

  @override
  String get onboardingNow => 'Jetzt *füge jemanden hinzu*.';

  @override
  String get onboardingTheAppIsReady =>
      'Die App ist bereit. Niemand kann dir schreiben, bis du die Person hinzufügst oder reinlässt.';

  @override
  String get onboardingEveryWayToAdd => 'Alle Wege, jemanden hinzuzufügen';

  @override
  String get onboardingShowYourCodeSend =>
      'Zeig deinen Code, schick einen Link oder gib den @Benutzernamen ein, den du bekommen hast.';

  @override
  String get onboardingScanTheirs => 'Code scannen';

  @override
  String get onboardingPointTheCameraAt =>
      'Richte die Kamera auf den Code der Person';

  @override
  String get onboardingTheAppIsReadyWhenYou =>
      'Die App ist bereit, wenn du es bist.';

  @override
  String get onboardingNotNowAddPeople =>
      'Nicht jetzt · später Leute hinzufügen';

  @override
  String get openLockedOpened => 'Geöffnet';

  @override
  String get openLockedOpenALockedFile => 'Verschlossene Datei öffnen';

  @override
  String get openLockedCheckingThePassword => 'Prüfe das Passwort';

  @override
  String get openLockedOpening => 'Öffne';

  @override
  String get openLockedFile => 'Datei';

  @override
  String get openLockedOpenFile => 'Datei öffnen';

  @override
  String get openLockedTypeThePassword => 'Gib das Passwort ein.';

  @override
  String get openLockedItOpensOnThis => 'Sie wird auf diesem Handy geöffnet.';

  @override
  String get openLockedLockedFile => 'Verschlossene Datei';

  @override
  String openLockedFromFiles(Object prettySize) {
    return '$prettySize · aus Dateien';
  }

  @override
  String get openLockedFromFiles2 => 'Aus Dateien';

  @override
  String get openLockedPassword => 'Passwort';

  @override
  String get openLockedThePasswordIsChecked =>
      'Zuerst wird das Passwort geprüft. Erst dann fragt Kryfo, wohin die geöffnete Datei soll, und sie geht direkt dorthin.';

  @override
  String get openLockedOpened2 => 'Geöffnet.';

  @override
  String get openLockedSavedWhereYouChose => 'Gespeichert, wo du wolltest.';

  @override
  String get pairCodePairingCode => 'Kopplungscode';

  @override
  String get pairCodeShowACode => 'Code zeigen';

  @override
  String get pairCodeEnterOne => 'Code eingeben';

  @override
  String get pairCodeSixDigits => 'Sechs Ziffern';

  @override
  String get pairCodeLooking => 'Suche…';

  @override
  String get pairCodeNothingThereYetTrying =>
      'Noch nichts da · versuche es erneut';

  @override
  String get pairCodeNothingAtThatCode =>
      'Unter diesem Code ist nichts. Er ist vielleicht schon verschwunden, oder die Person hat ihn noch nicht geteilt.';

  @override
  String get pairCodeTypeTheSixDigits =>
      'Gib die sechs Ziffern ein, die dir vorgelesen wurden.';

  @override
  String get pairCodeAddThem => 'Hinzufügen';

  @override
  String get panicSetupThoseWereDifferentFrom =>
      'Die waren verschieden. Noch mal von vorn.';

  @override
  String get panicSetupOnceMore => 'Noch einmal';

  @override
  String get panicSetupTheSameFourDigits => 'Dieselben Ziffern noch einmal';

  @override
  String get photoKnowsEverythingInside => 'Alles, was drin ist';

  @override
  String get photoKnowsVideo => 'Video';

  @override
  String get photoKnowsPhoto => 'Foto';

  @override
  String get photoKnowsWhatThisVideoKnows => 'Was dieses Video weiß';

  @override
  String get photoKnowsWhatThisPhotoKnows => 'Was dieses Foto weiß';

  @override
  String get photoKnowsRemoveAllOfIt => 'Alles entfernen';

  @override
  String get photoKnowsKeepItAsIt => 'So lassen, wie es ist';

  @override
  String get photoKnowsReadOnThisPhone =>
      'AUF DIESEM HANDY GELESEN · DAS VIDEO GING NIRGENDWOHIN';

  @override
  String get photoKnowsReadOnThisPhoneThePhoto =>
      'AUF DIESEM HANDY GELESEN · DAS FOTO GING NIRGENDWOHIN';

  @override
  String get photoKnowsReadingTheFile => 'Lese die Datei';

  @override
  String photoKnowsOf(Object prettySize, Object prettySize2) {
    return '$prettySize von $prettySize2';
  }

  @override
  String get photoKnowsEverythingStaysOnThis =>
      'Alles bleibt auf diesem Handy.';

  @override
  String photoKnowsMapWithAPin(Object place) {
    return 'Karte mit Markierung. $place';
  }

  @override
  String get photoKnowsDrawnOffline => 'OFFLINE GEZEICHNET';

  @override
  String photoKnowsShowEverything(Object title) {
    return '$title. Alles anzeigen';
  }

  @override
  String get pinsAppLock => 'App-Sperre';

  @override
  String get pinsYourPin => 'Deine PIN';

  @override
  String get commonOn => 'An';

  @override
  String get commonOff => 'Aus';

  @override
  String get pinsOpensKryfoFourDigits =>
      'Öffnet Kryfo. Wird abgefragt, wenn es in den Vordergrund kommt.';

  @override
  String get pinsChangePin => 'PIN ändern';

  @override
  String get pinsSetAPin => 'PIN festlegen';

  @override
  String get pinsTurnOff => 'Ausschalten';

  @override
  String get pinsTurnOffTheApp => 'App-Sperre ausschalten?';

  @override
  String get pinsThePinGoesAnd =>
      'Die PIN wird entfernt, und die Lösch-PIN und alle versteckten Chats mit ihr. Wer dein Handy in der Hand hat, öffnet Kryfo als du.';

  @override
  String get pinsUnlockWithFingerprint => 'Mit Fingerabdruck entsperren';

  @override
  String get pinsWipePin => 'Lösch-PIN';

  @override
  String get pinsNeedsAPinFirst => 'Braucht zuerst eine PIN';

  @override
  String get pinsSet => 'Festgelegt';

  @override
  String get pinsChangeWipePin => 'Lösch-PIN ändern';

  @override
  String get pinsSetAWipePin => 'Lösch-PIN festlegen';

  @override
  String get pinsRemove => 'Entfernen';

  @override
  String get pinsRemoveTheWipePin => 'Lösch-PIN entfernen?';

  @override
  String get pinsTheLockScreenKeeps =>
      'Der Sperrbildschirm behält deine PIN. Die Lösch-PIN bewirkt nichts mehr.';

  @override
  String profileCopied(Object what) {
    return '$what kopiert';
  }

  @override
  String get profileProfile => 'Profil';

  @override
  String get profileChangeYourFace => 'Gesicht ändern';

  @override
  String get profileKryfoId => 'Kryfo-ID';

  @override
  String get profileOnionAddress => 'Onion-Adresse';

  @override
  String get profileSupporterBadge => 'Unterstützer-Abzeichen';

  @override
  String profileYouAreAThank(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter': 'Du unterstützt Kryfo als Unterstützer. danke.',
      'patron': 'Du unterstützt Kryfo als Förderer. danke.',
      'guardian': 'Du unterstützt Kryfo als Hüter. danke.',
      'other': 'Du unterstützt Kryfo als Unterstützer. danke.',
    });
    return '$_temp0';
  }

  @override
  String get profileShowMyBadge => 'mein Abzeichen zeigen';

  @override
  String get profileOnMyOwnScreens => 'Auf meinen Bildschirmen';

  @override
  String get profileLetContactsSeeIt => 'Für Kontakte sichtbar';

  @override
  String get profileOffByDefault => 'standardmäßig aus';

  @override
  String get profileShareConnect => 'teilen & verbinden';

  @override
  String get profileMyKryfoCode => 'Mein Kryfo-Code';

  @override
  String get profileAddContact => 'Kontakt hinzufügen';

  @override
  String get profileGiveAgain => 'Erneut spenden';

  @override
  String get profileSupportKryfo => 'Kryfo unterstützen';

  @override
  String get profileKryfoRunsOnWhat => 'Kryfo lebt von dem, was Leute geben';

  @override
  String get profileKeepKryfoIndependent => 'Halte Kryfo unabhängig';

  @override
  String get qrLink => 'Link';

  @override
  String get qrYourLinkAsTyped =>
      'DEIN LINK WIE EINGEGEBEN · KEINE TRACKING-WEITERLEITUNG';

  @override
  String get qrText => 'Text';

  @override
  String get qrStaysInTheCode => 'BLEIBT IM CODE · KEIN SERVER SPEICHERT ES';

  @override
  String get qrWiFi => 'Wi-Fi';

  @override
  String get qrMadeOnThisPhone =>
      'AUF DIESEM HANDY ERSTELLT · KEINE WEBSITE HAT DAS PASSWORT GESEHEN';

  @override
  String get qrNetworkName => 'Netzwerkname';

  @override
  String get qrPassword => 'Passwort';

  @override
  String get qrContact => 'Kontakt';

  @override
  String get qrOnlyWhatYouType =>
      'NUR WAS DU EINGIBST · NICHTS AUS DEINEN KONTAKTEN';

  @override
  String get qrName => 'Name';

  @override
  String get qrPhone => 'Telefon';

  @override
  String get qrEmail => 'E-Mail';

  @override
  String get qrOpensTheirMailApp =>
      'ÖFFNET DIE MAIL-APP DER PERSON · VON HIER WIRD NICHTS GESENDET';

  @override
  String get qrTo => 'An';

  @override
  String get qrSubject => 'Betreff';

  @override
  String get qrANumberNothingElse => 'EINE NUMMER · SONST NICHTS';

  @override
  String get qrNumber => 'Nummer';

  @override
  String get qrSms => 'SMS';

  @override
  String get qrOpensTheirMessagesApp =>
      'ÖFFNET DIE NACHRICHTEN-APP DER PERSON · VON HIER WIRD NICHTS GESENDET';

  @override
  String get qrMessage => 'Nachricht';

  @override
  String get qrLocation => 'Standort';

  @override
  String get qrCoordinatesOnlyNoMap =>
      'NUR KOORDINATEN · KEIN KARTENDIENST GEFRAGT';

  @override
  String get qrLatitude => 'Breitengrad';

  @override
  String get qrLongitude => 'Längengrad';

  @override
  String get qrBitcoin => 'Bitcoin';

  @override
  String get qrAddressAndAmountNo =>
      'ADRESSE UND BETRAG · KEINE ZAHLUNGSSEITE DAZWISCHEN';

  @override
  String get qrAddress => 'Adresse';

  @override
  String get qrAmountInBtc => 'Betrag in BTC';

  @override
  String get qrInk => 'Tinte';

  @override
  String get qrAmber => 'Bernstein';

  @override
  String get qrViolet => 'Violett';

  @override
  String get qrCouldNotDrawThe => 'Das Bild konnte nicht gezeichnet werden.';

  @override
  String get qrSavedToYourGallery => 'In deiner Galerie gespeichert';

  @override
  String get qrCouldNotSaveIt =>
      'Konnte es nicht speichern. Prüfe, ob das Handy genug Platz hat.';

  @override
  String get qrNoAppOnThis =>
      'Keine App auf diesem Handy hat das Bild angenommen.';

  @override
  String get qrTooMuchForOne => 'Zu viel für einen Code. Mach es kürzer.';

  @override
  String get qrThisIsALot =>
      'Das ist viel für einen Code. Ältere Kameras lesen ihn vielleicht nicht.';

  @override
  String get qrPrivateQrCode => 'Privater QR-Code';

  @override
  String get qrColour => 'Farbe';

  @override
  String get qrCopiedItLeavesThe =>
      'Kopiert. In einer Minute verschwindet es aus der Zwischenablage';

  @override
  String get qrSecurity => 'Sicherheit';

  @override
  String get qrNone => 'Keine';

  @override
  String get qrSaveImage => 'Bild speichern';

  @override
  String qrColour2(Object name) {
    return 'Farbe $name';
  }

  @override
  String get qrTypeBelowAndThe =>
      'Tippe unten, und der\nCode zeichnet sich selbst';

  @override
  String get qrQrCode => 'QR-Code';

  @override
  String get qrHidePassword => 'Passwort verbergen';

  @override
  String get qrShowPassword => 'Passwort anzeigen';

  @override
  String get qrCopyPassword => 'Passwort kopieren';

  @override
  String get requestsSentAnAttachment => 'Hat einen Anhang gesendet';

  @override
  String get requestsWantsToConnect => 'Möchte sich verbinden';

  @override
  String get requestsAccepted => 'Angenommen';

  @override
  String requestsBlock(Object id) {
    return '$id blockieren?';
  }

  @override
  String get requestsNothingMoreFromThem =>
      'Von dieser Person erreicht dich nichts mehr. Ihre Anfrage und deren Nachrichten werden gelöscht.';

  @override
  String get requestsBlocked => 'blockiert';

  @override
  String get requestsDeleted => 'gelöscht';

  @override
  String get requestsRequests => 'Anfragen';

  @override
  String get requestsNoRequests => 'Keine Anfragen';

  @override
  String get requestsMessagesFromPeopleYou =>
      'Nachrichten von Leuten, die du nicht hinzugefügt hast, landen zuerst hier.';

  @override
  String get requestsLooksSafeNothingSuspicious =>
      'Sieht sicher aus · nichts Verdächtiges in der ersten Nachricht';

  @override
  String get commonAccept => 'Annehmen';

  @override
  String get requestsDecline => 'Ablehnen';

  @override
  String get restoreThatFileIsNot => 'Diese Datei ist kein Kryfo-Backup';

  @override
  String get restoreThisFileIsDamaged =>
      'Diese Datei ist beschädigt und kann nicht gelesen werden';

  @override
  String get restoreTypeThePassphraseThe =>
      'Gib die Passphrase ein, mit der die Datei erstellt wurde';

  @override
  String get restoreReplaceTheAccountOn =>
      'Das Konto auf diesem Handy ersetzen?';

  @override
  String get restoreWhatIsHereNow =>
      'Was jetzt hier ist, mit Identität, Kontakten und Nachrichten, wird gelöscht. Die Datei tritt an seine Stelle. Das lässt sich nicht rückgängig machen.';

  @override
  String get restoreReplaceIt => 'Ersetzen';

  @override
  String restoreCouldNotBeReleased(Object mine) {
    return '@$mine konnte nicht freigegeben werden';
  }

  @override
  String restoreTheRegistryDidNot(Object mine) {
    return 'Das Verzeichnis hat nicht geantwortet. Wenn du weitermachst, zeigt @$mine weiter auf die Identität, die dieses Handy gleich verliert. Wer ihn hinzufügt, schreibt ins Leere, und der Name kann nicht wieder gesichert werden. Geh lieber online und versuche es noch einmal.';
  }

  @override
  String get restoreRestoreAnyway => 'Trotzdem wiederherstellen';

  @override
  String get restoreNotYet => 'Noch nicht';

  @override
  String get restoreRestored => 'Wiederhergestellt';

  @override
  String restoreKryfoWillCloseNow(Object haloId) {
    return 'Kryfo schließt sich jetzt. Tippe auf das Symbol, um es als $haloId wieder zu öffnen.';
  }

  @override
  String get restoreReopenKryfo => 'Kryfo wieder öffnen';

  @override
  String get restoreTheRestoreDidNot =>
      'Die Wiederherstellung wurde nicht abgeschlossen. Es wurde nichts verändert';

  @override
  String get restoreThisIdentity => 'diese Identität';

  @override
  String get restoreMoveYourKryfoHere => 'Dein Kryfo hierher holen';

  @override
  String restoreThisBackupIsRestoring(Object name) {
    return 'Dieses Backup enthält $name. Beim Wiederherstellen zieht diese Identität auf dieses Gerät um.';
  }

  @override
  String restoreThisBackupMadeOn(Object name, Object date, Object time) {
    return 'Dieses Backup enthält $name, erstellt am $date um $time. Beim Wiederherstellen zieht diese Identität auf dieses Gerät um.';
  }

  @override
  String restoreItHoldsOfPhotos(Object mb) {
    return 'Es enthält $mb an Fotos, Sprachnachrichten und Dateien. Das kann ein paar Minuten dauern. Lass die App offen.';
  }

  @override
  String get restoreWhatFollows => 'Was mitkommt';

  @override
  String get restoreYourNameYourCode =>
      'Dein Name, dein Code und jeder Kontakt.';

  @override
  String get restoreEveryConversationBackTo =>
      'Jedes Gespräch, bis zum Anfang.';

  @override
  String get restoreYourPhotosVoiceNotes =>
      'Deine Fotos, Sprachnachrichten und Dateien.';

  @override
  String restoreYourPhotosVoiceNotesCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Deine Fotos, Sprachnachrichten und Dateien · $countString.',
    );
    return '$_temp0';
  }

  @override
  String get restoreYourOnionAddressSo =>
      'Deine Onion-Adresse, damit Leute, die dich direkt erreichen, dich weiter erreichen.';

  @override
  String get restoreAnythingSentToYou =>
      'Alles, was dir geschickt wurde, während das alte Handy aus war, bis vierzehn Tage nach dem Senden.';

  @override
  String get restoreYourSupporterBadgeIf =>
      'Dein Unterstützer-Abzeichen, falls du eins hast.';

  @override
  String get restoreWhatDoesnT => 'Was nicht mitkommt';

  @override
  String get restoreTheOldPhoneStops =>
      'Das alte Handy empfängt nichts mehr, sobald du von hier aus etwas sendest. Nicht nach und nach. Die erste Nachricht, die du von diesem Gerät sendest, ist die letzte, der das alte Handy folgen kann, und alles, was danach dort ankommt, ist dort unlesbar und wartet auch hier nicht auf dich.';

  @override
  String get restoreIfThePhoneThis =>
      'Wenn das Handy, von dem diese Datei stammt, noch benutzt wird, hör dort auf, Kryfo zu nutzen, bevor du weitermachst. Zwei Handys mit einem Kryfo verlieren auf beiden Nachrichten.';

  @override
  String get restoreNotificationsNeedSettingUp =>
      'Benachrichtigungen müssen auf diesem Gerät neu eingerichtet werden.';

  @override
  String get restoreMoveItHere => 'Hierher holen';

  @override
  String get restoreNotNow => 'Nicht jetzt';

  @override
  String get restoreRestore => 'Wiederherstellen';

  @override
  String get restoreFromABackupFile => 'Aus einer Backup-Datei';

  @override
  String get restoreABackupBringsBack =>
      'Ein Backup bringt deine Identität und deine Kontakte zurück, und die Nachrichten, die beim Erstellen der Datei auf dem Handy waren. Was seitdem gesagt wurde, ist nicht darin.';

  @override
  String get restoreTheFile => 'Die Datei';

  @override
  String get restorePickTheBackupFile => 'Backup-Datei wählen';

  @override
  String get restoreThePassphrase => 'Die Passphrase';

  @override
  String get restoreTheOneTheFile => 'Die, mit der die Datei erstellt wurde';

  @override
  String get restoreWhatComesBack => 'Was zurückkommt';

  @override
  String get restoreChecking => 'Prüfe…';

  @override
  String get restoreCheckTheFile => 'Datei prüfen';

  @override
  String get restoreReleasingYourHandle => 'Gebe deinen Benutzernamen frei…';

  @override
  String restoreMoving(Object progress) {
    return 'Ziehe um… $progress';
  }

  @override
  String get restoreRestoring => 'Stelle wieder her…';

  @override
  String get restoreNotThisOne => 'Nicht diese';

  @override
  String get restoreDateUnknown => 'Datum unbekannt';

  @override
  String get restoreAnIdentity => 'Eine Identität';

  @override
  String get restoreMessagesSentOrReceived =>
      'Nachrichten, die nach diesem Datum gesendet oder empfangen wurden, sind nicht in dieser Datei.';

  @override
  String restoreGb(Object bytes) {
    return '$bytes GB';
  }

  @override
  String restoreMb(Object bytes) {
    return '$bytes MB';
  }

  @override
  String get roomCreateCouldNotCreateThe =>
      'Der Raum konnte nicht erstellt werden';

  @override
  String get roomCreateBurnerRoom => 'Wegwerf-Raum';

  @override
  String get roomCreateARoomThatEnds =>
      'Ein Raum, der endet. Alle treten mit einem eigens dafür erstellten Schlüssel bei, und wenn er endet, bleibt auf keinem Handy etwas zurück.';

  @override
  String get roomCreateRoomName => 'Raumname';

  @override
  String get roomCreateEndsAfter => 'Endet nach';

  @override
  String get roomCreateMemberCap => 'Mitglieder-Limit';

  @override
  String roomCreateNoOnePastThe(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Nur die ersten $countString kommen rein',
      one: 'Nur $countString Person kommt rein',
    );
    return '$_temp0';
  }

  @override
  String get roomCreateOffAnyoneWithThe => 'aus. Alle mit dem Link';

  @override
  String roomCreateThisRoomAndEverything(Object expiryWords) {
    return 'Dieser Raum und alles darin verschwindet in $expiryWords';
  }

  @override
  String get roomCreateCreating => 'erstelle...';

  @override
  String get roomCreateCreateRoom => 'Raum erstellen';

  @override
  String get roomLinkSendTheRoomTo => 'Raum senden an';

  @override
  String get roomLinkTheyWillKnowThis =>
      'Die Person weiß dann, dass dieser Raum von dir kommt. Drinnen ist sie ein Schlüssel wie alle anderen.';

  @override
  String get roomLinkNoContactsYet => 'Noch keine Kontakte';

  @override
  String roomLinkEndsIn(Object time) {
    return 'Endet in $time';
  }

  @override
  String get roomLinkAnyoneWithThisCan =>
      'Wer das hat, kann beitreten, bis der Raum endet. Man kommt mit einem eigens für diesen Raum erstellten Schlüssel herein und sieht nichts, was vor dem Beitritt gesendet wurde.';

  @override
  String get roomLinkRoomLinkCopied => 'Raumlink kopiert';

  @override
  String get roomLinkSendToAContact => 'An einen Kontakt senden';

  @override
  String get roomLinkCopyRoomLink => 'Raumlink kopieren';

  @override
  String get savedVoiceNote => 'Sprachnachricht';

  @override
  String get savedPhoto => 'Foto';

  @override
  String get savedSaved => 'Gespeichert';

  @override
  String get savedNothingSavedYet => 'Noch nichts gespeichert';

  @override
  String get savedLongPressAnyMessage =>
      'halte eine Nachricht gedrückt und tippe auf Speichern, um sie hier aufzubewahren.';

  @override
  String get savedViewInChat => 'Im Chat ansehen';

  @override
  String get savedPhoto2 => 'Foto';

  @override
  String get scanThatSNotA => 'das ist kein Kryfo-QR · weiter draufhalten';

  @override
  String get scanScanAKryfoQr => 'Kryfo-QR scannen';

  @override
  String get scanFlash => 'Blitz';

  @override
  String get scanPointAtAKryfo =>
      'Auf einen Kryfo-QR richten · nichts verlässt dein Handy';

  @override
  String get seenWhatWeCanSee => 'Was wir sehen können';

  @override
  String get seenEveryMessengerClaimsPrivacy =>
      'Jeder Messenger verspricht Privatsphäre. Das hier ist die genaue Liste, nach Route, auch mit den Teilen, die uns nicht gut aussehen lassen. Tippe auf eine Zeile für das Warum.';

  @override
  String get seenHonestAboutTheLast =>
      'Ehrlich zu den letzten Zeilen: Dafür gibt es die App-Sperre, die Lösch-PIN und den verschlüsselten Speicher, und kein Werkzeug schützt dich vor jemandem, der dein entsperrtes Handy in der Hand hält. Das vollständige Bedrohungsmodell steht in THREAT_MODEL.md im Repo, geschrieben nach LINDDUN. Der Code ist offen, also muss man nichts davon einfach glauben.';

  @override
  String get seenHidden => 'verborgen';

  @override
  String get seenNever => 'nie';

  @override
  String get seenOnDevice => 'auf dem Gerät';

  @override
  String get seenTiming => 'Zeitpunkt';

  @override
  String get seenYours => 'deins';

  @override
  String get seenUnaudited => 'nicht auditiert';

  @override
  String get seenWhoYouTalkTo => 'Mit wem du sprichst';

  @override
  String get seenEachConversationGetsIts =>
      'Jedes Gespräch bekommt eine eigene Adresse, abgeleitet aus beiden Schlüsseln. Ein Relais sieht voneinander unabhängige Ablagen, kein Paar von Menschen.';

  @override
  String get seenWhatYouSay => 'was du sagst';

  @override
  String get seenEndToEndEncrypted =>
      'Ende-zu-Ende-verschlüsselt mit dem Double Ratchet von Signal und dann noch einmal in einer Geschenkverpackung versiegelt. Wir könnten es nicht lesen, selbst wenn wir es versuchten.';

  @override
  String get seenYourIpAddress => 'Deine IP-Adresse';

  @override
  String get seenOurRelay => 'unser Relais';

  @override
  String get seenEveryRelay => 'jedes Relais';

  @override
  String get seenOnOnionEverythingLeaves =>
      'Mit Onion geht alles über tor hinaus, und das Relais sieht einen Exit-Knoten, nie dich. Im Relais-Modus geht die Verbindung direkt zu unserem eigenen Relais: Nichts leitet deine Adresse weiter und nichts wird aufgeschrieben, aber diese eine Verbindung sehen wir. Mit Schnell erfährt jedes öffentliche Relais, dass du dich verbunden hast, aber nicht, mit wem, und nicht, was du gesagt hast.';

  @override
  String get seenYourContactGraph => 'Dein Kontaktnetz';

  @override
  String get seenKryfoDoesNotScan =>
      'Kryfo durchsucht deine Kontakte nicht. Genau darum geht es. Hier gibt es keine Telefonnummer, die durchsickern könnte.';

  @override
  String get seenIntroducer => 'wer vorstellt';

  @override
  String get seenWhenAContactIntroduces =>
      'Wenn dich ein Kontakt jemandem vorstellt, erfährt dieser Kontakt, dass ihr beide jetzt verbunden seid. Sonst niemand. Das Relais sieht Chiffretext, und kein Server sieht jemals das Kontaktnetz.';

  @override
  String get seenTheScamShield => 'Der Betrugsschutz';

  @override
  String get seenRunsOnYourPhone =>
      'Läuft auf deinem Handy, mit Regeln, die in der App mitkommen. Kein Netzwerk, keine Listen-Downloads. Er liest nur die erste Nachricht von Fremden und kann nichts sehen, was dir ein Kontakt schickt.';

  @override
  String get seenBurnerRooms => 'Wegwerf-Räume';

  @override
  String get seenRoomKeys => 'Raum-Schlüssel';

  @override
  String get seenYouJoinARoom =>
      'Du trittst einem Raum mit einem eigens dafür erstellten Schlüssel bei, also erfahren die Leute darin nichts, was anderswo funktioniert. Wer später kommt, bekommt keinen Verlauf. Beim Ablauf werden die Schlüssel, die Nachrichten und die Medien vernichtet.';

  @override
  String get seenLinkPreviews => 'Link-Vorschauen';

  @override
  String get seenOverTor => 'über tor';

  @override
  String get seenAPreviewIsFetched =>
      'Eine Vorschau wird vom Absender über tor abgerufen und reist in der verschlüsselten Nachricht mit. Das empfangende Handy stellt keine Anfrage. Die Website erfährt, dass jemand über tor eine Seite abgerufen hat, und sonst nichts. Es wird nie ein Bild geladen, und der Link von Fremden bleibt reiner Text.';

  @override
  String get seenThatADeviceFetched => 'Dass ein Gerät Post abgeholt hat';

  @override
  String get seenARelayCanTell =>
      'Ein Relais kann erkennen, dass eine Adresse abgefragt wurde, und wann. Es kann nicht erkennen, wessen, oder von wo.';

  @override
  String get seenASeizedUnlockedPhone => 'Entsperrtes Handy, beschlagnahmt';

  @override
  String get seenIfSomeoneHoldsYour =>
      'Wenn jemand dein Handy entsperrt in der Hand hält, liest die Person deine Nachrichten. App-Sperre, Lösch-PIN und verschlüsselter Speicher helfen vor diesem Punkt, nicht danach.';

  @override
  String get seenTheCryptoItself => 'Die Kryptografie selbst';

  @override
  String get seenTheRatchetAndStorage =>
      'Die Ratchet- und Speicherschichten sind Standard. Die Schicht, die sie verbindet, ist von uns, und niemand Unabhängiges hat sie geprüft. Behandle das als Alpha, denn das ist es.';

  @override
  String get seenOnion => 'Onion';

  @override
  String get seenRelay => 'Relais';

  @override
  String get seenFast => 'Schnell';

  @override
  String get settingsWipeKryfo => 'Kryfo löschen?';

  @override
  String get settingsIdentityMessagesContactsAnd =>
      'Identität, Nachrichten, Kontakte und Einstellungen auf diesem Handy. Für immer weg, außer du hast ein Backup.';

  @override
  String get commonContinue => 'Weiter';

  @override
  String settingsTypeWipeToConfirm(Object word) {
    return 'tippe „$word“ zum Bestätigen';
  }

  @override
  String get settingsTheLastStepNothing =>
      'Der letzte Schritt. Nichts übersteht ihn.';

  @override
  String get settingsWipeWord => 'löschen';

  @override
  String get settingsWipeKryfo2 => 'Kryfo löschen';

  @override
  String get settingsYourProtections => 'Dein Schutz';

  @override
  String get settingsTorRouting => 'Tor-Routing';

  @override
  String get settingsConnecting => 'Verbinde';

  @override
  String get settingsOffMode => 'Aus · Relais-Modus';

  @override
  String get settingsOffFastMode => 'Aus · Schnell-Modus';

  @override
  String get settingsAppLock => 'App-Sperre';

  @override
  String get settingsBlockedByAndroid => 'Von Android blockiert';

  @override
  String get settingsSpeedPrivacy => 'Tempo & Privatsphäre';

  @override
  String get settingsFast => 'Schnell';

  @override
  String get settingsRelay1Hop => 'Relais · 1 Station';

  @override
  String get settingsOnion3Hops => 'Onion · 3 Stationen';

  @override
  String get settingsBridges => 'Brücken';

  @override
  String get settingsForNetworksThatBlock =>
      'Für Netzwerke, die tor blockieren';

  @override
  String get settingsGettingMessages => 'Nachrichten empfangen';

  @override
  String settingsPreviewHidden(Object deliveryModeName) {
    return '$deliveryModeName · Vorschau verborgen';
  }

  @override
  String settingsPreviewShown(Object deliveryModeName) {
    return '$deliveryModeName · Vorschau sichtbar';
  }

  @override
  String get settingsRunInBackground => 'Im Hintergrund laufen';

  @override
  String get settingsSoMessagesArrive => 'Damit Nachrichten ankommen';

  @override
  String get settingsTransport => 'Transport';

  @override
  String get settingsWhatTheNetworkIs => 'Was das Netzwerk gerade tut';

  @override
  String get settingsBlocked => 'Blockiert';

  @override
  String get settingsAcceptIntroductions => 'Vorstellungen annehmen';

  @override
  String get settingsFriendsCanIntroduceYou =>
      'Freunde können dich ihren Freunden vorstellen';

  @override
  String get settingsScamShield => 'Betrugsschutz';

  @override
  String get settingsChecksStrangersOnYour =>
      'Prüft Fremde auf deinem Handy. Nichts verlässt es';

  @override
  String get settingsBlockScreenshots => 'Screenshots blockieren';

  @override
  String get settingsWholeAppHiddenFrom =>
      'Ganze App in „Zuletzt verwendet“ und auf Screenshots verborgen · gilt ab dem nächsten Start';

  @override
  String get settingsWholeAppHiddenFromRecentsAnd =>
      'Ganze App in „Zuletzt verwendet“ und auf Screenshots verborgen';

  @override
  String get settingsOnNextStart => 'An · nächster Start';

  @override
  String get settingsOffNextStart => 'Aus · nächster Start';

  @override
  String get settingsLightTheme => 'Helles Design';

  @override
  String get settingsSameProtectionBrighter => 'Gleicher Schutz, heller';

  @override
  String get settingsAppLock2 => 'App-Sperre';

  @override
  String get settingsYourPinAndA => 'Deine PIN und erweiterter Schutz';

  @override
  String get settingsPinWipePin => 'PIN · Lösch-PIN';

  @override
  String get settingsBackUpIdentity => 'Identität sichern';

  @override
  String get settingsEncryptedFile => 'Verschlüsselte Datei';

  @override
  String get settingsRestoreFromBackup => 'Aus Backup wiederherstellen';

  @override
  String get settingsReplaceCurrent => 'Ersetzt die aktuelle';

  @override
  String get settingsDisguiseVoice => 'Stimme verfremden';

  @override
  String get settingsShiftsYourPitchBefore =>
      'Verschiebt deine Tonhöhe, bevor eine Sprachnachricht rausgeht';

  @override
  String get settingsWhyKryfo => 'Warum Kryfo';

  @override
  String get settingsHowItProtectsYou => 'Wie es dich schützt';

  @override
  String get settingsResetMyInviteLink => 'Einladungslink zurücksetzen';

  @override
  String get settingsOldLinksAndCodes =>
      'Alte Links und Codes funktionieren nicht mehr, für niemanden';

  @override
  String get settingsResetInviteLink => 'Einladungslink zurücksetzen?';

  @override
  String get settingsAnyoneWithAnOld =>
      'Wer einen alten Code oder Link hat, kann dich über keinen Weg mehr erreichen. Wer ihn hat, aber nie benutzt hat, braucht einen neuen von dir. Kontakte, Chats und Verlauf bleiben.';

  @override
  String get settingsReset => 'Zurücksetzen';

  @override
  String get settingsInviteResetShareThe =>
      'Einladung zurückgesetzt · teile den neuen Code';

  @override
  String get settingsWhatWeCanSee => 'Was wir sehen können';

  @override
  String get settingsTheHonestList => 'Die ehrliche Liste';

  @override
  String get settingsVersion => 'Version';

  @override
  String get settings030Alpha => '0.4.1 · Alpha';

  @override
  String get settingsReportAnIssue => 'Problem melden';

  @override
  String get settingsBugOrSecurityFlaw => 'Fehler oder Sicherheitslücke';

  @override
  String get settingsOpenSource => 'Open Source';

  @override
  String get settingsLinkCopied => 'Link kopiert';

  @override
  String get settingsTheOfflineMapIn =>
      'Die Offline-Karte unter Werkzeuge basiert auf Natural Earth (gemeinfrei). Ortsnamen stammen von GeoNames, geonames.org, unter CC BY 4.0.';

  @override
  String get settingsNotIndependentlyAuditedPre =>
      'Nicht unabhängig auditiert. Pre-Alpha - gut zum Testen, noch nicht für Einsätze, bei denen viel auf dem Spiel steht.';

  @override
  String get settingsDangerZone => 'Gefahrenzone';

  @override
  String get settingsWipeKryfoFromThis => 'Kryfo von diesem Handy löschen';

  @override
  String get shieldCheckedOnThisPhone =>
      'Auf diesem Handy geprüft. Es wurde nichts irgendwohin gesendet.';

  @override
  String get toolsMoreTools => 'Weitere Werkzeuge';

  @override
  String get toolsCleanAPhotoOr => 'Foto oder Video bereinigen';

  @override
  String get toolsOrShareOneTo =>
      'Oder teile eins aus deiner Galerie mit Kryfo';

  @override
  String get toolsMakeAPrivateQr => 'Privaten QR-Code erstellen';

  @override
  String get toolsLinksWiFiContacts =>
      'Links, Wi-Fi, Kontakte und mehr. Offline erstellt';

  @override
  String get toolsLockAFile => 'Datei verschließen';

  @override
  String get toolsWithAPasswordOpens =>
      'Mit einem Passwort. Lässt sich überall mit age öffnen';

  @override
  String get toolsOpenALockedFile => 'Verschlossene Datei öffnen';

  @override
  String get toolsAnyAgeFileSomeone =>
      'Jede .age-Datei, die dir jemand geschickt hat';

  @override
  String get toolsWorksOfflineNoContacts =>
      'Funktioniert offline · keine Kontakte nötig';

  @override
  String get toolsUsefulFrom => 'Nützlich ab';

  @override
  String get toolsTheFirstMinute => 'der ersten Minute.';

  @override
  String get toolsEverythingHereHappensOn =>
      'Alles hier passiert auf diesem Handy. Nichts wird hochgeladen, und niemand sonst muss Kryfo haben.';

  @override
  String get toolsWhatDoesThisPhoto => 'Was weiß dieses Foto?';

  @override
  String get toolsPlacePhoneTime => 'Ort · Handy · Zeit';

  @override
  String get toolsPickAPhotoAnd =>
      'Wähle ein Foto und sieh, was es verrät. Dann behalte eine bereinigte Kopie.';

  @override
  String get toolsPickAPhoto => 'Foto wählen';

  @override
  String get toolsVideo => 'Video';

  @override
  String get transportTransport => 'Transport';

  @override
  String get transportNothingHereLeavesThe =>
      'Nichts hier verlässt das Handy. Es ist derselbe Zustand, nach dem die Engine entscheidet, was sie tut.';

  @override
  String get transportStayingAlive => 'bleibt aktiv';

  @override
  String get transportCanSend => 'kann senden';

  @override
  String get commonYes => 'Ja';

  @override
  String get transportNotYet => 'Noch nicht';

  @override
  String get transportOnline => 'Online';

  @override
  String get transportOffline => 'Offline';

  @override
  String get transportQueuedToSend => 'wartet aufs Senden';

  @override
  String get transportOnionPublished => 'Onion veröffentlicht';

  @override
  String transportYes(Object uploads) {
    return 'Ja ($uploads)';
  }

  @override
  String transportTryingS(Object pubFor) {
    return 'Versuche seit ${pubFor}s';
  }

  @override
  String transportBenchedS(Object r) {
    return 'Pausiert für ${r}s';
  }

  @override
  String transportFails(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString Fehlschläge',
      one: '$countString Fehlschlag',
    );
    return '$_temp0';
  }

  @override
  String get transportOk => 'ok';

  @override
  String get transportRelaySubscriptions => 'Relais-Abonnements';

  @override
  String get transportLastSent => 'zuletzt gesendet';

  @override
  String get transportNever => 'Nie';

  @override
  String transportSAgo(Object sx) {
    return 'vor $sx s';
  }

  @override
  String get transportLastReceived => 'zuletzt empfangen';

  @override
  String transportSAgo2(Object rx) {
    return 'vor $rx s';
  }

  @override
  String get transportWithNoContactsThe =>
      'Ohne Kontakte abonniert die App keine Relais-Adressen, also kann dich keine Nachricht erreichen. Scanne jemanden, um das zu ändern.';

  @override
  String get transportSendAnythingWaitingNow => 'Alles Wartende jetzt senden';

  @override
  String get transportOff => 'aus';

  @override
  String get transportStarting => 'startet';

  @override
  String get transportBootstrapped => 'hochgefahren';

  @override
  String get transportPublishingAddress => 'Veröffentliche Adresse';

  @override
  String get transportReachable => 'erreichbar';

  @override
  String get transportOurRelayOnion => 'unser Relais (Onion)';

  @override
  String get transportNever2 => 'nie';

  @override
  String get transportJustNow => 'Gerade eben';

  @override
  String transportMAgo(Object inMinutes) {
    return 'vor $inMinutes min';
  }

  @override
  String transportHAgo(Object inHours) {
    return 'vor $inHours h';
  }

  @override
  String transportDAgo(Object inDays) {
    return 'vor $inDays T';
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
    return '$inDays T';
  }

  @override
  String transportMb(Object b) {
    return '$b MB';
  }

  @override
  String get transportYesCheckedJustNow => 'Ja · gerade eben geprüft';

  @override
  String transportNoLast(Object ago) {
    return 'Nein · zuletzt $ago';
  }

  @override
  String get transportLastMessageIn => 'Zuletzt empfangen';

  @override
  String get transportBatteryExemption => 'Akku-Ausnahme';

  @override
  String get transportUnknown => 'unbekannt';

  @override
  String get transportExempt => 'ausgenommen';

  @override
  String get transportNotExemptTapTo => 'Keine Ausnahme · zum Beheben tippen';

  @override
  String get transportProcessUp => 'Prozess läuft';

  @override
  String get transportLastStop => 'letzter Stopp';

  @override
  String transportEngine(Object mb, Object mb2) {
    return '$mb · Engine $mb2';
  }

  @override
  String get transportLastRelayArrival => 'Letzter Relais-Eingang';

  @override
  String get transportLastCheckIn => 'letzter Check-in';

  @override
  String get transportNoneYet => 'Noch keiner';

  @override
  String get transportLastTorReconnect => 'letzte tor-Neuverbindung';

  @override
  String get transportCatchUpByRelay => 'Nachholen pro Relais';

  @override
  String get transportControlPort => 'Steuerport';

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
      other: '$dialsString Versuche',
      one: '$dialsString Versuch',
    );
    String _temp1 = intl.Intl.pluralLogic(
      timeouts,
      locale: localeName,
      other: '$timeoutsString Timeouts',
      one: '$timeoutsString Timeout',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get transportJobRuns => 'Job-Läufe';

  @override
  String transportLast(Object jobRuns, Object ago) {
    return '$jobRuns · zuletzt $ago';
  }

  @override
  String get transportQuietStretches => 'Stille Phasen';

  @override
  String get transportNone => 'Keine';

  @override
  String get transportClearThisRecord => 'Protokoll leeren';

  @override
  String get transportNothingYetThisProcess => 'Noch nichts in diesem Prozess';

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
    return '$t bis $t2';
  }

  @override
  String vouchersVouchedBy(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'empfohlen von $countString',
      one: 'empfohlen von',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperAtmosphere => 'Atmosphäre';

  @override
  String get wallpaperJustForYouThey =>
      'Nur für dich. Die anderen sehen ihren eigenen.';

  @override
  String get wallpaperYourPhoto => 'dein Foto';

  @override
  String get wallpaperFromYourPhotos => 'Aus deinen Fotos';

  @override
  String get wallpaperKeepIt => 'Behalten';

  @override
  String get whyKryfoWhyKryfo => 'Warum Kryfo';

  @override
  String get whyKryfoKryfoKreeFoGreek =>
      'Kryfo · KRIE-fo · griechisch für verborgen.\nEin stiller Ort zum Reden, so gebaut, dass niemand zusieht.';

  @override
  String get whyKryfoRoutedThroughTor => 'Über tor geleitet';

  @override
  String get whyKryfoByDefaultEveryMessage =>
      'Standardmäßig reist jede Nachricht durch tor - eine Kette von Relais. Niemand, weder wir noch dein Netzwerk, kann sehen, mit wem du sprichst oder wo du bist.';

  @override
  String get whyKryfoEndToEndEncrypted => 'Ende-zu-Ende-verschlüsselt';

  @override
  String get whyKryfoMessagesAreSealedWith =>
      'Nachrichten werden mit Schlüsseln versiegelt, die nur du und die Person, mit der du sprichst, haben. Wir könnten sie nicht lesen, selbst wenn wir es versuchten.';

  @override
  String get whyKryfoNoServersHoldingYour =>
      'Keine Server, die dein Leben speichern';

  @override
  String get whyKryfoNoAccountNoPhone =>
      'Kein Konto, keine Telefonnummer, kein zentraler Server, der deine Chats speichert. Sie liegen auf diesem Handy, verschlüsselt gespeichert.';

  @override
  String get whyKryfoNothingLeaks => 'nichts sickert durch';

  @override
  String get whyKryfoNoReadReceiptsOr =>
      'Keine Lesebestätigungen oder Tipp-Anzeigen, die an irgendwen gehen, keine hochgeladene Kontaktliste. Metadaten sind das, was die meisten Apps preisgeben - Kryfo ist so gebaut, dass es das nicht tut.';

  @override
  String get whyKryfoVerifyItIsReally => 'Prüfe, ob es wirklich die Person ist';

  @override
  String get whyKryfoCompareASafetyNumber =>
      'vergleiche eine Sicherheitsnummer persönlich oder über einen Kanal, dem du vertraust, damit du weißt, dass sich niemand als dein Kontakt ausgibt.';

  @override
  String get whyKryfoTheHonestPart => 'Der ehrliche Teil';

  @override
  String get whyKryfoKryfoIsPreAlpha =>
      'Kryfo ist Pre-Alpha und wurde nicht auditiert. Die Kryptografie ist echt, aber noch hat sie keine externe Fachperson geprüft, also sieh es als etwas, an dem noch gearbeitet wird, nicht als etwas, dem du schon dein Leben anvertraust.';

  @override
  String get cleanerLocation => 'Standort';

  @override
  String get cleanerAlreadyBlankedByAndroid => 'schon von Android geleert';

  @override
  String get cleanerPhoneModel => 'Handymodell';

  @override
  String get cleanerTimeTaken => 'Aufnahmezeit';

  @override
  String get cleanerSerialNumber => 'Seriennummer';

  @override
  String get cleanerOwnerName => 'Name des Besitzers';

  @override
  String get cleanerHiddenThumbnail => 'Verstecktes Vorschaubild';

  @override
  String get cleanerContentCredentials => 'Inhaltsnachweise';

  @override
  String get cleanerDataAfterThePicture => 'Daten hinter dem Bild';

  @override
  String cleaner1OtherField(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString weitere Felder',
      one: '$countString weiteres Feld',
    );
    return '$_temp0';
  }

  @override
  String get lockWordsFourRandomWordsBeat =>
      'Vier zufällige Wörter schlagen ein cleveres.';

  @override
  String lockWordsTooShortAtLeast(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Zu kurz. Mindestens $countString Zeichen.',
      one: 'Zu kurz. Mindestens $countString Zeichen.',
    );
    return '$_temp0';
  }

  @override
  String get lockWordsWeakWhoeverGetsThe =>
      'Schwach. Wer die Datei hat, kann beliebig schnell raten.';

  @override
  String get lockWordsFairLongerIsStronger => 'Okay. Länger ist stärker.';

  @override
  String get lockWordsStrongFourRandomWords =>
      'Stark. Vier zufällige Wörter schlagen ein cleveres.';

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
      other: '$countString Meter',
      one: '$countString Meter',
    );
    return '$_temp0';
  }

  @override
  String get photoStoryFarFromAnyTown => 'Weit weg von jedem Ort';

  @override
  String photoStoryNear(Object where) {
    return 'Bei $where';
  }

  @override
  String photoStoryAboutKmFrom(Object near, Object where) {
    return 'Etwa $near km von $where';
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
  String get photoStoryNotAKindKryfo => 'Kein Format, das Kryfo lesen kann.';

  @override
  String get photoStorySoItWillNot => 'Deshalb rät es nicht.';

  @override
  String get photoStoryThisFileIsDamaged =>
      'Diese Datei ist beschädigt oder abgeschnitten.';

  @override
  String get photoStoryKryfoCouldNotRead =>
      'Kryfo konnte sie nicht bis zum Ende lesen.';

  @override
  String get photoStoryWhereItWasRecorded => 'Wo es aufgenommen wurde';

  @override
  String get photoStoryWhereItWasTaken => 'Wo es aufgenommen wurde';

  @override
  String photoStoryLocation(Object coordsLine) {
    return 'Standort: $coordsLine';
  }

  @override
  String photoStoryHeightAboveTheSea(Object fix) {
    return 'Höhe über dem Meer: $fix m';
  }

  @override
  String get photoStoryLocationHiddenByAndroid =>
      'Standort von Android verborgen';

  @override
  String get photoStoryAndroidBlanksItWhen =>
      'Android leert ihn, wenn ein Foto auf diesem Weg gewählt wird. Teilst du es aus deiner Galerie mit Kryfo, bleibt er oft erhalten. Das Foto in deiner Galerie hat ihn vielleicht noch.';

  @override
  String get photoStoryLocationBlankedByAndroid =>
      'Standort: von Android geleert, bevor Kryfo ihn gesehen hat';

  @override
  String photoStoryF(Object r) {
    return 'f/$r';
  }

  @override
  String get photoStoryWhatTookIt => 'Aufgenommen mit';

  @override
  String photoStoryPhoneOrCamera(Object phone) {
    return 'Handy oder Kamera: $phone';
  }

  @override
  String get photoStoryWhenItWasRecorded => 'Wann es aufgenommen wurde';

  @override
  String get photoStoryToTheSecondWith => 'Auf die Sekunde, mit Zeitzone';

  @override
  String get photoStoryToTheSecond => 'Auf die Sekunde';

  @override
  String photoStoryTime(Object dateFormat) {
    return 'Zeit: $dateFormat';
  }

  @override
  String get photoStoryLens => 'Objektiv';

  @override
  String photoStoryLens2(Object lens) {
    return 'Objektiv: $lens';
  }

  @override
  String get photoStorySoftware => 'Software';

  @override
  String photoStorySoftware2(Object software) {
    return 'Software: $software';
  }

  @override
  String get photoStorySerialNumber => 'Seriennummer';

  @override
  String photoStorySerialNumber2(Object serial) {
    return 'Seriennummer: $serial';
  }

  @override
  String get photoStoryOwnerName => 'Name des Besitzers';

  @override
  String photoStoryOwner(Object r) {
    return 'Besitzer: $r';
  }

  @override
  String get photoStoryHiddenThumbnail => 'Verstecktes Vorschaubild';

  @override
  String get photoStoryASmallCopyOf =>
      'Eine kleine Kopie des Bildes in der Datei. Sie kann zeigen, was ein Zuschnitt entfernt hat';

  @override
  String get photoStoryMakerNotes => 'Herstellernotizen';

  @override
  String get photoStoryMakerNotesABlock =>
      'Herstellernotizen: ein Block, den nur der Hersteller lesen kann';

  @override
  String get photoStoryEditingHistory => 'Bearbeitungsverlauf';

  @override
  String get photoStoryXmpEditingHistoryAnd =>
      'XMP: Bearbeitungsverlauf und Tags';

  @override
  String get photoStoryCaptions => 'Beschriftung';

  @override
  String get photoStoryIptcCaptionsAndCredits =>
      'IPTC: Beschriftungen und Urheberangaben';

  @override
  String get photoStoryComment => 'Kommentar';

  @override
  String get photoStoryAWrittenComment => 'Ein geschriebener Kommentar';

  @override
  String get photoStoryContentCredentials => 'Inhaltsnachweise';

  @override
  String get photoStorySecondPicture => 'Zweites Bild';

  @override
  String get photoStoryASecondPictureInside => 'Ein zweites Bild in der Datei';

  @override
  String get photoStoryMotionVideo => 'Bewegungsvideo';

  @override
  String get photoStoryAShortVideoInside => 'Ein kurzes Video in der Datei';

  @override
  String get photoStorySaveTime => 'Speicherzeit';

  @override
  String get photoStoryTheTimeItWas => 'Wann sie zuletzt gespeichert wurde';

  @override
  String get photoStoryTimeStamps => 'Zeitstempel';

  @override
  String get photoStoryCreationTimeStamps => 'Erstellungszeitstempel';

  @override
  String get photoStoryDataAfterThePicture => 'Daten hinter dem Bild';

  @override
  String photoStoryDataAfterTheEnd(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Daten hinter dem Ende des Bildes: $countString Byte',
      one: 'Daten hinter dem Ende des Bildes: $countString Byte',
    );
    return '$_temp0';
  }

  @override
  String photoStoryTextField(Object k) {
    return 'Textfeld: $k';
  }

  @override
  String photoStoryVideoTag(Object k) {
    return 'Video-Tag: $k';
  }

  @override
  String photoStoryAlso(Object k) {
    return 'Außerdem: $k';
  }

  @override
  String photoStoryCameraSettingsFlashFocus(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString Kameraeinstellungen (Blitz, Fokus, Belichtung)',
      one: '$countString Kameraeinstellung (Blitz, Fokus, Belichtung)',
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
      other: '$countString weitere Felder',
      one: '$countString weiteres Feld',
    );
    return '$_temp0';
  }

  @override
  String get photoStoryCameraSettings => 'Kameraeinstellungen';

  @override
  String photoStoryAccurateToAbout(Object metres) {
    return 'Auf etwa $metres genau.';
  }

  @override
  String get photoStoryEnoughToFindThe => 'Genug, um die Tür zu finden.';

  @override
  String get photoStoryEnoughToFindTheStreet =>
      'Genug, um die Straße zu finden.';

  @override
  String get photoStoryEnoughToFindTheArea => 'Genug, um die Gegend zu finden.';

  @override
  String get photoStoryItKnowsWhereYou => 'Es weiß, wo du warst.';

  @override
  String get photoStoryDownToTheBuilding => 'Bis aufs Gebäude genau.';

  @override
  String get photoStoryAndroidHidTheLocation =>
      'Android hat den Standort verborgen.';

  @override
  String get photoStoryTheOriginalMayStill =>
      'Das Original hat ihn vielleicht noch.';

  @override
  String get photoStoryNoLocationInThis => 'Hier ist kein Standort drin.';

  @override
  String get photoStoryItStillSaysPlenty => 'Es verrät trotzdem viel.';

  @override
  String get photoStoryThisOneKnowsNothing => 'Dieses weiß nichts.';

  @override
  String get photoStoryNothingToRemove => 'Nichts zu entfernen.';

  @override
  String get qrPayloadOpensALink => 'ÖFFNET EINEN LINK';

  @override
  String qrPayloadOpens(Object host) {
    return 'ÖFFNET $host';
  }

  @override
  String get qrPayloadShowsANote => 'ZEIGT EINE NOTIZ';

  @override
  String get qrPayloadScanToJoin => 'SCANNEN & VERBINDEN';

  @override
  String qrPayloadScanToJoin2(Object oneLine) {
    return 'SCANNEN & VERBINDEN · $oneLine';
  }

  @override
  String get qrPayloadANetworkNameIs =>
      'Ein Netzwerkname hat höchstens 32 Zeichen.';

  @override
  String get qrPayloadAWiFiPassword =>
      'Ein Wi-Fi-Passwort hat mindestens 8 Zeichen.';

  @override
  String get qrPayloadSavesAContact => 'SPEICHERT EINEN KONTAKT';

  @override
  String get qrPayloadWritesAnEmail => 'SCHREIBT EINE E-MAIL';

  @override
  String get qrPayloadThatDoesNotLook =>
      'Das sieht nicht nach einer E-Mail-Adresse aus.';

  @override
  String get qrPayloadCallsANumber => 'RUFT EINE NUMMER AN';

  @override
  String get qrPayloadWritesAText => 'SCHREIBT EINE SMS';

  @override
  String get qrPayloadOpensAMap => 'ÖFFNET EINE KARTE';

  @override
  String get qrPayloadLatitudeRunsFrom90 =>
      'Der Breitengrad reicht von -90 bis 90, der Längengrad von -180 bis 180.';

  @override
  String get qrPayloadPayThisAddress => 'AN DIESE ADRESSE ZAHLEN';

  @override
  String get qrPayloadABitcoinAddressIs =>
      'Eine Bitcoin-Adresse besteht nur aus Buchstaben und Ziffern.';

  @override
  String get qrPayloadTheAmountIsIn =>
      'Der Betrag ist in BTC, mit bis zu 8 Nachkommastellen.';

  @override
  String vouchTextAnd(Object names, Object names2) {
    return '$names und $names2';
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
      other: '$names, $names2 und $restString weiteren Personen, die du kennst',
      one: '$names, $names2 und $restString weiteren Person, die du kennst',
    );
    return '$_temp0';
  }

  @override
  String vouchTextVouchedBy(Object vouchNames) {
    return 'Empfohlen von $vouchNames';
  }

  @override
  String vouchTextIntroducedBy(Object vouchNames) {
    return 'Vorgestellt von $vouchNames';
  }

  @override
  String vouchTextThisSharesSAddress(Object a, Object b) {
    return 'Damit teilst du die Adresse von $a mit $b';
  }

  @override
  String get bootFailedKryfoCouldNotStart => 'Kryfo konnte nicht starten';

  @override
  String get bootFailedThisIsAFault =>
      'Das ist ein Fehler auf diesem Gerät, nicht im Netzwerk. Tor ist nicht beteiligt.';

  @override
  String get kryfoLinkTextThatLinkIsNot => 'Diesen Link kann Kryfo nicht lesen';

  @override
  String kryfoLinkTextAdd(Object who) {
    return '$who hinzufügen?';
  }

  @override
  String kryfoLinkTextThisIsAnInvite(Object who) {
    return 'Das ist eine Einladung zum Gespräch mit $who. Füge die Person nur hinzu, wenn du weißt, woher der Link kommt.';
  }

  @override
  String get kryfoLinkTextAddThem => 'Hinzufügen';

  @override
  String get kryfoLinkTextNotNow => 'Nicht jetzt';

  @override
  String kryfoLinkTextJoin(Object roomName) {
    return '$roomName beitreten';
  }

  @override
  String get kryfoLinkTextKryfoLink => 'Kryfo-Link';

  @override
  String kryfoLinkTextAdd2(Object who) {
    return '$who hinzufügen';
  }

  @override
  String get kryfoLinkTextBurnerRoom => 'WEGWERF-RAUM';

  @override
  String get kryfoLinkTextThisRoomHasClosed => 'Dieser Raum ist geschlossen';

  @override
  String kryfoLinkTextClosesIn(Object time) {
    return 'Schließt in $time';
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
      other: 'Schließt in $time · bis zu $capString',
    );
    return '$_temp0';
  }

  @override
  String get kryfoLinkTextJoin2 => 'Beitreten';

  @override
  String get kryfoLinkTextYouJoinUnderA =>
      'Du trittst mit einem eigens für diesen Raum erstellten Schlüssel bei. Niemand darin sieht deine Kryfo-ID.';

  @override
  String get linkStubFetchedOverTorBy =>
      'Über tor abgerufen · von deinem Gerät';

  @override
  String get linkStubFetchedOverTorByTheirDevice =>
      'Über tor abgerufen · vom Gerät der anderen Person';

  @override
  String mediaBubblesB(Object bytes) {
    return '$bytes B';
  }

  @override
  String mediaBubblesKb(Object bytes) {
    return '$bytes KB';
  }

  @override
  String mediaBubblesMb(Object bytes) {
    return '$bytes MB';
  }

  @override
  String get mediaBubblesFile => 'DATEI';

  @override
  String get mediaBubblesAudioUnavailable => 'Audio nicht verfügbar';

  @override
  String get mediaBubblesHidden => 'Verborgen';

  @override
  String get mediaBubblesMicPermissionNeeded => 'Mikrofonzugriff nötig';

  @override
  String get mediaBubblesReleaseToCancel => 'Loslassen zum Abbrechen';

  @override
  String get mediaBubblesVoiceHiddenSlideTo =>
      'Stimme verfremdet · zum Abbrechen wischen';

  @override
  String get mediaBubblesSlideToCancel => 'Zum Abbrechen wischen';

  @override
  String get mediaBubblesSendPhoto => 'Foto senden';

  @override
  String get mediaBubblesAddACaption => 'Beschriftung…';

  @override
  String get motionStandby => 'WARTET';

  @override
  String get motionConnecting => 'VERBINDE';

  @override
  String get motionBuilding => 'BAUE AUF';

  @override
  String get motionPublishing => 'VERÖFFENTLICHE';

  @override
  String get motionReady => 'BEREIT';

  @override
  String get motionPreparingToConnect => 'Bereite Verbindung vor';

  @override
  String get motionFindingAPrivatePath => 'Suche einen privaten Weg';

  @override
  String get motionCarvingThePath => 'Bahne den Weg';

  @override
  String get motionAnnouncingYourArrival => 'Kündige deine Ankunft an';

  @override
  String get motionYouReAnonymous => 'du bist anonym';

  @override
  String get motionTorIsStartingIn =>
      'Tor startet im Hintergrund. Diese Grafik leuchtet auf, während die Verbindung entsteht.';

  @override
  String get motionMakingAFreshRoute =>
      'Baue eine neue Route über anonyme Relais.';

  @override
  String get motionBouncingThroughRelaysSo =>
      'Springe über Relais, damit niemand das zu dir zurückverfolgen kann.';

  @override
  String get motionTellingTheNetworkYou =>
      'sage dem Netzwerk, dass du online bist, ohne zu verraten, wo.';

  @override
  String get motionYourIpIsHidden =>
      'Deine IP ist verborgen. Nur Leute mit deinem Kryfo können dich erreichen.';

  @override
  String get motionBuilding2 => 'im Aufbau';

  @override
  String get motionOpen => 'offen';

  @override
  String get motionLive => 'aktiv';

  @override
  String motionCircuit(Object circuit) {
    return 'Kanal · *$circuit*';
  }

  @override
  String get motionDelivered => 'zugestellt';

  @override
  String get motionSent => 'gesendet';

  @override
  String get motion1Hop => '1 Station';

  @override
  String get motion3Hops => '3 Stationen';

  @override
  String get movedStripThisKryfoHasMoved =>
      'Dieses Kryfo ist auf ein anderes Gerät umgezogen. Nichts, was von hier gesendet wird, erreicht jemanden.';

  @override
  String get navBarChats => 'Chats';

  @override
  String get navBarTools => 'Werkzeuge';

  @override
  String get navBarSupport => 'Unterstützen';

  @override
  String get navBarMe => 'Ich';

  @override
  String get pairCodePanelPuttingYourInviteIn =>
      'Deine Einladung wird bereitgelegt';

  @override
  String get pairCodePanelYourInviteIsNot =>
      'Deine Einladung ist noch nicht bereit';

  @override
  String get pairCodePanelReadSixDigitsOut =>
      'Lies sechs Ziffern laut vor, und die Person kann dich hinzufügen. Sonst muss nichts ausgetauscht werden.';

  @override
  String get pairCodePanelWorking => 'Einen Moment';

  @override
  String get pairCodePanelOrMakeASix =>
      'Oder erstelle einen sechsstelligen Code zum Vorlesen';

  @override
  String get pairCodePanelCodeCopied => 'Code kopiert';

  @override
  String pairCodePanelBurnsIn(Object mm, Object ss) {
    return 'Verschwindet in $mm:$ss';
  }

  @override
  String get pairCodePanelTheyTapAddChoose =>
      'Die Person tippt auf Hinzufügen, wählt Code und gibt diese ein.';

  @override
  String get pairCodePanelTheyOpenKryfoTap =>
      'Die Person öffnet Kryfo, tippt auf Hinzufügen, wählt Kopplungscode und gibt diese sechs Ziffern ein. Erstelle für die nächste Person einen neuen.';

  @override
  String pinsPinnedMessages(Object count) {
    return 'Angeheftete Nachrichten · $count';
  }

  @override
  String get pinsPinnedMessages2 => 'Angeheftete Nachrichten';

  @override
  String get pinsPhoto => 'Foto';

  @override
  String get pinsVoiceMessage => 'Sprachnachricht';

  @override
  String get pinsMessage => 'Nachricht';

  @override
  String pinsToday(Object hm) {
    return 'Heute · $hm';
  }

  @override
  String get pinsPinned => 'Angeheftet';

  @override
  String pinsOf(Object pinsLength, Object kMaxPins) {
    return '$pinsLength von $kMaxPins';
  }

  @override
  String get pinsNothingPinnedHereYet =>
      'Noch nichts angeheftet. Halte eine Nachricht gedrückt und wähle Anheften, dann wartet sie hier für alle im Chat.';

  @override
  String get pinsJump => 'Springen';

  @override
  String get pinsUnpin => 'Loslösen';

  @override
  String powNoteFirstMessageToSomeone(int secs) {
    final intl.NumberFormat secsNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String secsString = secsNumberFormat.format(secs);

    return 'Erste Nachricht an jemand Neues · Echtheit wird nachgewiesen · ${secsString}s';
  }

  @override
  String powNoteFirstMessageSlow(int secs) {
    final intl.NumberFormat secsNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String secsString = secsNumberFormat.format(secs);

    return 'Erste Nachricht an jemand Neues · Echtheit wird nachgewiesen · ${secsString}s · auf einem langsamen Handy bis zu einer Minute';
  }

  @override
  String previewStripFetchedOverTor(Object domainOf) {
    return '$domainOf · über tor abgerufen';
  }

  @override
  String get previewStripDropThePreview => 'Vorschau weglassen';

  @override
  String get previewStripAddPreview => 'Vorschau hinzufügen';

  @override
  String get previewStripFetchingOverTor => 'Rufe über tor ab…';

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
      'Keine Abkürzungen, keine Spuren';

  @override
  String get torBootSplashTheNetworkThatKeeps =>
      'Das Netzwerk, das dich privat hält, wärmt sich auf';

  @override
  String get torBootSplashMadeOnThisPhone =>
      'Auf diesem Handy erstellt. Nichts wird irgendwohin gesendet.';

  @override
  String get torBootSplashFirstLaunchTakesA =>
      'Der erste Start dauert einen Moment · nur beim Hochfahren';

  @override
  String get videoBubbleNothingHereOpensThat =>
      'Hier kann das nichts öffnen · wird stattdessen geteilt';

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
  String get notificationsChannelName => 'Nachrichten';

  @override
  String get cameraClose => 'Schließen';

  @override
  String get cameraFlash => 'Blitz';

  @override
  String get cameraPhoto => 'Foto';

  @override
  String get cameraVideo => 'Video';

  @override
  String get cameraRetake => 'Neu aufnehmen';

  @override
  String get seenIntroductions => 'Vorstellungen';

  @override
  String get donateAddress => 'Adresse';

  @override
  String get donateCopy => 'Kopieren';

  @override
  String get donateDone => 'Fertig';

  @override
  String get donateTierSupporter => 'Unterstützer';

  @override
  String get donateTierPatron => 'Förderer';

  @override
  String get donateTierGuardian => 'Hüter';

  @override
  String get chatBlock => 'Blockieren';

  @override
  String get chatDecline => 'Ablehnen';

  @override
  String get chatAccept => 'Annehmen';

  @override
  String get bridgesConnecting => 'verbinde';

  @override
  String get restoreMade => 'erstellt';

  @override
  String get restoreContacts => 'Kontakte';

  @override
  String get restoreMessages => 'Nachrichten';

  @override
  String get restoreAttachments => 'Anhänge';

  @override
  String get shieldBlock => 'Blockieren';

  @override
  String get shieldDelete => 'Löschen';

  @override
  String get shieldIgnore => 'Ignorieren';

  @override
  String get profileIdentity => 'Identität';

  @override
  String get avatarPickerShape => 'Form';

  @override
  String get avatarPickerColour => 'Farbe';

  @override
  String get avatarPickerTurn => 'Drehung';

  @override
  String get transportStatus => 'Status';

  @override
  String get transportBootstrap => 'Start';

  @override
  String get transportNetwork => 'Netzwerk';

  @override
  String get transportConnectivity => 'Verbindung';

  @override
  String get transportRelays => 'Relais';

  @override
  String get transportTraffic => 'Datenverkehr';

  @override
  String get transportContacts => 'Kontakte';

  @override
  String get transportKnown => 'bekannt';

  @override
  String get transportListening => 'lauscht';

  @override
  String get transportMemory => 'Speicher';

  @override
  String get settingsConnected => 'Verbunden';

  @override
  String get settingsScreenshots => 'Screenshots';

  @override
  String get settingsBlocked2 => 'Blockiert';

  @override
  String get settingsAllowed => 'Erlaubt';

  @override
  String get settingsOn => 'An';

  @override
  String get settingsOff => 'Aus';

  @override
  String get settingsNotifications => 'Benachrichtigungen';

  @override
  String get settingsPrivacy => 'Privatsphäre';

  @override
  String get settingsSecurity => 'Sicherheit';

  @override
  String get settingsBackup => 'Backup';

  @override
  String get settingsVoice => 'Stimme';

  @override
  String get settingsAbout => 'Über';

  @override
  String get wallpaperGradients => 'Verläufe';

  @override
  String get wallpaperPatterns => 'Muster';

  @override
  String get confirmSheetKeep => 'Behalten';

  @override
  String get confirmSheetSave => 'Speichern';

  @override
  String get confirmSheetCancel => 'Abbrechen';

  @override
  String bridgesSaved(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString Brücken',
      one: '$countString Brücke',
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

    return '$goodString übernommen, $badString nicht verstanden';
  }

  @override
  String get languageTitle => 'Sprache';

  @override
  String get languageMatchPhone => 'Wie das Handy';

  @override
  String languageMatchPhoneValue(Object language) {
    return 'Wie das Handy ($language)';
  }

  @override
  String get languageRedrawLine =>
      'Kryfo baut sich in der neuen Sprache neu auf und öffnet deine Chats.';

  @override
  String languageButton(Object language) {
    return 'Sprache: $language';
  }

  @override
  String get androidServiceTitle => 'Kryfo ist an';

  @override
  String get androidServiceText =>
      'deine verschlüsselte Leitung bleibt offen, damit Nachrichten ankommen';

  @override
  String get androidChannelName => 'verbunden bleiben';

  @override
  String get androidChannelDescription =>
      'hält Kryfo verbunden, damit verschlüsselte Nachrichten ankommen, während es geschlossen ist. wenn du das ausschaltest, stoppt die Zustellung.';

  @override
  String get videoViewerPlay => 'Abspielen';

  @override
  String get videoViewerPause => 'Pause';

  @override
  String get videoViewerPlayAgain => 'Nochmal abspielen';

  @override
  String get videoViewerCannotPlay =>
      'Dieses Handy kann das Video hier nicht abspielen.';

  @override
  String get videoViewerOpenElsewhere => 'In anderer App öffnen';

  @override
  String get photoKnowsLookedFor => 'Gesucht nach';

  @override
  String get photoKnowsNotInIt => 'nicht drin';

  @override
  String get languageNameEn => 'Englisch';

  @override
  String get languageNameDe => 'Deutsch';

  @override
  String get languageNameFr => 'Französisch';

  @override
  String get languageNameEs => 'Spanisch';

  @override
  String get languageNamePt => 'Portugiesisch (Brasilien)';

  @override
  String get languageNameIt => 'Italienisch';

  @override
  String get languageNameRu => 'Russisch';

  @override
  String get languageNameUk => 'Ukrainisch';

  @override
  String get languageNameTr => 'Türkisch';

  @override
  String get languageNameZh => 'Chinesisch (vereinfacht)';

  @override
  String get languageNameZhHant => 'Chinesisch (traditionell)';

  @override
  String get languageNameVi => 'Vietnamesisch';

  @override
  String get languageNameId => 'Indonesisch';

  @override
  String get languageNameFa => 'Persisch';

  @override
  String get languageNameAr => 'Arabisch';

  @override
  String get languageLaterLine =>
      'Du kannst das jederzeit in den Einstellungen ändern.';

  @override
  String get pollAttach => 'Umfrage';

  @override
  String get pollNewTitle => 'Neue Umfrage';

  @override
  String get pollQuestionHint => 'Frag die Gruppe etwas';

  @override
  String get pollOptionsLabel => 'Optionen';

  @override
  String pollOptionHint(Object n) {
    return 'Option $n';
  }

  @override
  String get pollAddOption => 'Option hinzufügen';

  @override
  String get pollMaxLine => 'Höchstens zwölf Optionen.';

  @override
  String get pollMultiple => 'Mehrere Antworten';

  @override
  String get pollMultipleLine => 'Man kann mehr als eine wählen.';

  @override
  String get pollSend => 'Umfrage senden';

  @override
  String get pollKind => 'Umfrage';

  @override
  String get pollKindMulti => 'Umfrage · mehrere Antworten';

  @override
  String get pollKindClosed => 'Endergebnis';

  @override
  String pollVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Stimmen',
      one: '$count Stimme',
      zero: 'Noch keine Stimmen',
    );
    return '$_temp0';
  }

  @override
  String get pollVote => 'Abstimmen';

  @override
  String get pollTakeBack => 'Meine Stimme zurückziehen';

  @override
  String get pollClose => 'Umfrage beenden';

  @override
  String get pollCloseTitle => 'Diese Umfrage beenden?';

  @override
  String get pollCloseLine =>
      'Alle sehen das Endergebnis, und danach kann niemand mehr abstimmen.';

  @override
  String get pollCloseYes => 'Beenden';

  @override
  String pollPreview(Object question) {
    return 'Umfrage: $question';
  }

  @override
  String get pollWhoVoted => 'Wer abgestimmt hat';

  @override
  String get pollNobody => 'Noch niemand';

  @override
  String get pollYou => 'Du';

  @override
  String pollOptionA11y(Object option, Object share) {
    return '$option, $share';
  }

  @override
  String get pollPickOne => 'Wähle eine';

  @override
  String get pollPickSeveral => 'Wähle eine oder mehrere';

  @override
  String get searchOpen => 'Suchen';

  @override
  String get searchHint => 'Chats und Nachrichten durchsuchen';

  @override
  String get searchFilterAll => 'Alle';

  @override
  String get searchFilterPhotos => 'Fotos';

  @override
  String get searchFilterVideos => 'Videos';

  @override
  String get searchFilterFiles => 'Dateien';

  @override
  String get searchFilterLinks => 'Links';

  @override
  String get searchChats => 'Chats';

  @override
  String get searchMessages => 'Nachrichten';

  @override
  String get searchIntroTitle => 'Durchsuche deine Chats';

  @override
  String get searchIntroLine =>
      'Namen, Wörter, Fotos, Dateien und Links. Die Suche läuft auf diesem Handy und schickt nichts irgendwohin.';

  @override
  String get searchNothing => 'Nichts gefunden';

  @override
  String get searchNothingLine =>
      'Versuch ein anderes Wort oder einen anderen Filter.';

  @override
  String searchMatches(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Treffer',
      one: '$count Treffer',
    );
    return '$_temp0';
  }

  @override
  String searchMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weitere',
      one: '$count weiterer',
    );
    return '$_temp0';
  }

  @override
  String searchFilling(Object share) {
    return 'Ältere Nachrichten werden aufgenommen · $share';
  }

  @override
  String get searchClear => 'Leeren';

  @override
  String get handleShowInSearch => 'In der Suche zeigen';

  @override
  String get handleShowInSearchLine =>
      'Jeder kann diesen Benutzernamen finden und dir schreiben.';

  @override
  String handleShownAs(Object name) {
    return 'Angezeigt als $name';
  }

  @override
  String get handleNameInSearch => 'Name in der Suche';

  @override
  String get handleNameInSearchLine =>
      'Optional. Er steht neben deinem Benutzernamen, wenn jemand sucht. Jeder kann diesen Benutzernamen finden und dir schreiben.';

  @override
  String get handleNameHint => 'Dein Name, oder leer lassen';

  @override
  String get handleShowMe => 'Zeigen';

  @override
  String get handleSearchOff => 'Du bist nicht mehr in der Suche';

  @override
  String handleSearchOn(Object handle) {
    return 'Du bist in der Suche als @$handle';
  }

  @override
  String get handleRegistryFailed =>
      'Das Verzeichnis war nicht erreichbar. Versuch es gleich noch mal.';

  @override
  String get searchPeople => 'Personen';

  @override
  String searchPeopleAsk(Object query) {
    return '„$query“ unter öffentlichen Benutzernamen suchen';
  }

  @override
  String get searchPeopleLine =>
      'Über Tor gefragt. Das Verzeichnis merkt sich nichts davon.';

  @override
  String get searchPeopleNone => 'Kein öffentlicher Benutzername passt';

  @override
  String get searchPeopleOffline => 'Tor ist noch nicht bereit';

  @override
  String get searchPeopleBusy =>
      'Gerade zu viele Suchen. Versuch es gleich noch mal.';

  @override
  String get searchPeopleUnreachable => 'Das Verzeichnis war nicht erreichbar';

  @override
  String get peopleVerified => 'Bestätigter Benutzername';

  @override
  String get peopleAdd => 'Hinzufügen';

  @override
  String peopleFingerprint(Object fp) {
    return 'Schlüssel-Fingerabdruck · $fp';
  }

  @override
  String get peopleFingerprintLine =>
      'Prüf, ob er mit dem in ihrer App übereinstimmt.';

  @override
  String get peopleAdding => 'Wird hinzugefügt…';

  @override
  String handleNobodyHasClaimed(Object handle) {
    return 'Niemand hat $handle gesichert';
  }

  @override
  String get handleThatHandleIsTaken =>
      'Dieser Benutzername ist schon vergeben';

  @override
  String get pinPickDifferent => 'Wähl eine andere PIN';

  @override
  String get settingsKeptOnWhileLock =>
      'Bleibt an, solange die App-Sperre an ist.';

  @override
  String get lockFingerAfterPin =>
      'Gib einmal deine PIN ein, dann geht der Fingerabdruck wieder.';

  @override
  String get pinsAdvanced => 'Erweiterter Schutz';

  @override
  String get pinsAdvancedLine =>
      'Für den Fall, dass dich jemand zwingt, dein Handy zu entsperren.';

  @override
  String get pinsWipeLine =>
      'Auf dem Sperrbildschirm eingegeben, löscht sie Kryfo von diesem Handy.';

  @override
  String get pinsDecoyPin => 'Tarn-PIN';

  @override
  String get pinsDecoyLine =>
      'Öffnet ein leeres Kryfo, wie frisch installiert.';

  @override
  String get pinsSetADecoyPin => 'Tarn-PIN festlegen';

  @override
  String get pinsChangeDecoyPin => 'Tarn-PIN ändern';

  @override
  String get pinsRemoveTheDecoyPin => 'Tarn-PIN entfernen?';

  @override
  String get pinsTheDecoyGoes =>
      'Das leere Kryfo, das sie öffnet, verschwindet mit ihr.';

  @override
  String get pinsTurnOffWithDecoy =>
      'Alle PINs werden entfernt, die Tarn-PIN und ihr Kryfo und alle versteckten Chats mit ihnen. Wer dein Handy in der Hand hat, öffnet Kryfo als du.';

  @override
  String get pinsHowThisWorks => 'So funktioniert es';

  @override
  String get flowEnterYourPin => 'Gib deine PIN ein';

  @override
  String get flowEnterYourPinLine => 'Die, mit der sich Kryfo öffnet.';

  @override
  String get flowWipeTitle => 'Eine Lösch-PIN';

  @override
  String get flowWipe1 =>
      'Statt deiner PIN auf dem Sperrbildschirm eingegeben, löscht sie Kryfo von diesem Handy und schließt es. Für alle, die zusehen, hat die App einfach aufgehört.';

  @override
  String get flowWipe2 =>
      'Sie nimmt jeden Chat und deine Identität mit, und die Tarnung, falls du eine hast.';

  @override
  String get flowWipeChoose => 'Wähle eine Lösch-PIN';

  @override
  String get flowWipeDone => 'Lösch-PIN festgelegt';

  @override
  String get flowWipeDoneLine =>
      'Auf dem Sperrbildschirm deutet nichts auf sie hin.';

  @override
  String get flowDecoyTitle => 'Eine Tarn-PIN';

  @override
  String get flowDecoy1 => 'Öffnet ein leeres Kryfo, wie frisch installiert.';

  @override
  String get flowDecoyFinger =>
      'Dein Fingerabdruck öffnet dein echtes Kryfo. Wenn dich jemand zwingen könnte, ihn zu benutzen, schalte den Fingerabdruck aus.';

  @override
  String get flowDecoyDigits =>
      'Nimm genauso viele Ziffern wie bei deiner PIN, denn wer zusieht, kann die Punkte zählen.';

  @override
  String get flowDecoyShade =>
      'Benachrichtigungen, die schon in der Leiste sind, wurden schon gesehen. Solange die Tarnung offen ist, kommen keine neuen.';

  @override
  String get flowDecoyChoose => 'Wähle eine Tarn-PIN';

  @override
  String get flowDecoyDone => 'Tarn-PIN festgelegt';

  @override
  String get flowDecoyDoneLine =>
      'Gib sie auf dem Sperrbildschirm ein, um das leere Kryfo zu öffnen. Zum Verlassen wechsle weg und gib deine PIN ein.';

  @override
  String get flowLaw =>
      'In manchen Ländern ist es schon eine Straftat, ein Handy nicht zu entsperren oder Daten vor Behörden zu verbergen. Kenne das Recht dort, wo du hinreist.';

  @override
  String get howWipe =>
      'Auf dem Sperrbildschirm eingegeben, löscht die Lösch-PIN jeden Chat, deine Identität und jede Tarnung und schließt dann Kryfo. Sie wirkt auch, während das Tastenfeld nach falschen Versuchen gesperrt ist.';

  @override
  String get howDecoy =>
      'Die Tarn-PIN öffnet ein zweites, leeres Kryfo mit eigenen drei Wörtern. Nachrichten an dein echtes Kryfo kommen darunter weiter an, lautlos. Zum Verlassen der Tarnung wechsle weg und gib deine PIN ein.';

  @override
  String get flowNotSet =>
      'Konnte nicht festgelegt werden. Versuch es noch einmal.';

  @override
  String get pinsHiddenChats => 'Versteckte Chats';

  @override
  String get pinsHiddenLine =>
      'Ausgewählte Chats bleiben außer Sicht, bis du deine PIN für versteckte Chats eingibst: nicht in der Liste, nicht in der Suche, keine Benachrichtigungen.';

  @override
  String get pinsSetUp => 'Einrichten';

  @override
  String get pinsChangeHiddenPin => 'PIN für versteckte Chats ändern';

  @override
  String get pinsHideMoreChats => 'Weitere Chats verstecken';

  @override
  String get pinsRemoveHiddenChats => 'Versteckte Chats entfernen';

  @override
  String get pinsRemoveHiddenTitle => 'Versteckte Chats entfernen?';

  @override
  String get pinsRemoveHiddenLine =>
      'Sie kommen zurück in deine Chatliste, und die PIN für versteckte Chats öffnet nichts mehr.';

  @override
  String get pinsTurnOffHiddenFirst =>
      'Versteckte Chats brauchen die App-Sperre. Entferne sie zuerst, dann kommen sie zurück in deine Chatliste.';

  @override
  String get flowVaultTitle => 'Versteckte Chats';

  @override
  String get flowVault1 =>
      'Wähle Chats und Gruppen zum Verstecken. Deine PIN öffnet Kryfo ohne sie. Eine PIN für versteckte Chats öffnet alles, auch die versteckten Chats.';

  @override
  String get flowVault2 =>
      'Solange sie außer Sicht sind, melden sie sich nie und zeigen keinen Zähler. Ihre Nachrichten kommen weiter an und warten versiegelt auf deine PIN für versteckte Chats.';

  @override
  String get flowVaultFinger =>
      'Dein Fingerabdruck öffnet Kryfo ohne versteckte Chats.';

  @override
  String get flowVaultDigits =>
      'Gib auch deiner PIN sechs Ziffern oder mehr, denn wer zusieht, kann die Punkte zählen.';

  @override
  String get flowVaultReplace =>
      'Das ersetzt alle versteckten Chats, die dieses Handy schon hat.';

  @override
  String get flowVaultChoose => 'Wähle eine PIN für versteckte Chats';

  @override
  String get flowVaultChooseLine => 'Sechs Ziffern oder mehr.';

  @override
  String get flowEnterHiddenPinLine =>
      'Die, mit der sich deine versteckten Chats öffnen.';

  @override
  String get flowVaultForgetTitle => 'Merk dir diese PIN';

  @override
  String get flowVaultForget =>
      'Wenn du diese PIN vergisst, sind deine versteckten Chats für immer weg. Niemand kann sie zurückholen, auch wir nicht.';

  @override
  String get flowVaultForgetOk => 'Verstanden';

  @override
  String get flowVaultPickTitle => 'Chats zum Verstecken wählen';

  @override
  String get flowVaultPickLine =>
      'Sie verlassen jetzt deine Chatliste. Deine PIN für versteckte Chats holt sie zurück.';

  @override
  String flowVaultPickButton(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString Chats verstecken',
      one: '1 Chat verstecken',
      zero: 'Noch nichts verstecken',
    );
    return '$_temp0';
  }

  @override
  String get flowVaultPickEmpty => 'Noch keine Chats zum Verstecken.';

  @override
  String get flowVaultBackupTitle => 'Jetzt ein Backup machen?';

  @override
  String get flowVaultBackupLine =>
      'Ein Backup von jetzt enthält auch deine versteckten Chats, unter einer eigenen Passphrase. Wenn du die PIN für versteckte Chats vergisst, ist es der einzige Weg zurück zu ihnen.';

  @override
  String get flowVaultBackupNow => 'Backup machen';

  @override
  String get flowVaultNotNow => 'Nicht jetzt';

  @override
  String get flowVaultDone => 'Versteckte Chats eingerichtet';

  @override
  String get flowVaultDoneLine =>
      'Gib deine PIN für versteckte Chats auf dem Sperrbildschirm ein, um sie zu sehen. Wechsle weg, und sie sind wieder außer Sicht.';

  @override
  String get flowVaultChanged => 'PIN für versteckte Chats geändert';

  @override
  String get flowVaultChangedLine =>
      'Deine versteckten Chats öffnen sich mit der neuen. Die alte öffnet jetzt nichts mehr.';

  @override
  String get howVault =>
      'Deine PIN für versteckte Chats öffnet Kryfo mit deinen versteckten Chats, deine PIN und dein Fingerabdruck ohne sie. Richtest du versteckte Chats neu ein, ersetzt das die, die dieses Handy hat. Vergisst du die PIN für versteckte Chats, sind sie für immer weg.';

  @override
  String get chatHide => 'Chat verstecken';

  @override
  String get groupHide => 'Gruppe verstecken';

  @override
  String get chatHidden => 'Versteckt';

  @override
  String get chatHiddenToast => 'Aus deiner Chatliste versteckt';

  @override
  String get chatShowInList => 'In der Chatliste zeigen';

  @override
  String get stickerOpen => 'Sticker';

  @override
  String get stickerRecent => 'Zuletzt';

  @override
  String stickerA11y(String emoji) {
    return 'Sticker $emoji';
  }

  @override
  String get stickerRemoveRecent => 'Aus „Zuletzt“ entfernen';

  @override
  String get stickerCouldNotLoad => 'Sticker konnten nicht geladen werden';

  @override
  String get stickerLabel => 'Sticker';

  @override
  String get stickerNewer => 'Aus einem neueren Kryfo';
}
