// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get atmosphereNone => 'Aucune';

  @override
  String get atmosphereEmber => 'Braise';

  @override
  String get atmosphereDusk => 'Crépuscule';

  @override
  String get atmosphereMoss => 'Mousse';

  @override
  String get atmosphereRose => 'Rose';

  @override
  String get atmosphereDots => 'Points';

  @override
  String get atmosphereGrid => 'Grille';

  @override
  String get atmosphereWaves => 'Vagues';

  @override
  String get atmosphereRain => 'Pluie';

  @override
  String get atmosphereLateNight => 'Tard le soir';

  @override
  String get atmosphereWarmAfternoon => 'Après-midi doré';

  @override
  String get atmosphereSnow => 'Neige';

  @override
  String get atmosphereDesert => 'Désert';

  @override
  String get atmospherePaper => 'Papier';

  @override
  String get backupThatPassphraseDoesNot =>
      'Cette phrase secrète n’ouvre pas ce fichier';

  @override
  String get backupThatFileIsNot => 'Ce fichier n’est pas une sauvegarde Kryfo';

  @override
  String get backupThisBackupIsFrom =>
      'Cette sauvegarde vient d’un Kryfo plus récent. Mettez l’appli à jour, puis réessayez';

  @override
  String get backupThisFileIsDamaged =>
      'Ce fichier est endommagé et ne peut pas être lu';

  @override
  String get backupCouldNotMakeThe => 'Impossible de créer la clé';

  @override
  String get contactCardMessageMeOn => 'Écrivez-moi sur';

  @override
  String get contactCardScanItOrType =>
      'Scannez-la, ou tapez les trois mots dans Kryfo.\nCette carte ne sait rien d’autre de vous.';

  @override
  String contactCardMessageMeOnKryfo(Object haloId) {
    return 'Écrivez-moi sur Kryfo · $haloId';
  }

  @override
  String get contactStatusBlocked => 'Bloqué';

  @override
  String get contactStatusKeysVerifiedInPerson => 'Clés vérifiées en personne';

  @override
  String get contactStatusWaitingInRequests => 'En attente dans les demandes';

  @override
  String get contactStatusAddedByHand => 'Ajouté à la main';

  @override
  String get deliveryModeAlwaysOn => 'Toujours actif';

  @override
  String get deliveryModeCheckIns => 'Relevés';

  @override
  String get deliveryModeThroughAHelperApp => 'Via une appli auxiliaire';

  @override
  String get deliveryModeNotYet => 'pas encore';

  @override
  String get deliveryModeJustNow => 'à l’instant';

  @override
  String deliveryModeMinAgo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $countString min',
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
      other: 'il y a $countString heures',
      one: 'il y a $countString heure',
    );
    return '$_temp0';
  }

  @override
  String get deliveryModeYesterday => 'hier';

  @override
  String deliveryModeDaysAgo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $countString jours',
      one: 'il y a $countString jour',
    );
    return '$_temp0';
  }

  @override
  String get deliveryModeConnected => 'Connecté';

  @override
  String get deliveryModeConnecting => 'Connexion';

  @override
  String get deliveryModeNotConnected => 'Non connecté';

  @override
  String get deliveryModeCheckingNow => 'Relevé en cours';

  @override
  String deliveryModeLastCheckIn(Object agoLine) {
    return 'dernier relevé $agoLine';
  }

  @override
  String get deliveryModeNoCheckInYet => 'pas encore de relevé';

  @override
  String deliveryModeConnectedNow(Object last) {
    return 'Connecté maintenant · $last';
  }

  @override
  String deliveryModeConnecting2(Object last) {
    return 'Connexion · $last';
  }

  @override
  String get deliveryModeNoCheckInYet2 => 'Pas encore de relevé';

  @override
  String deliveryModeLastChecked(Object agoLine) {
    return 'Dernier relevé $agoLine';
  }

  @override
  String get deliveryModeAHelperApp => 'une appli auxiliaire';

  @override
  String deliveryModeWokenByNoWake(Object who) {
    return 'Réveillé par $who · pas encore de réveil';
  }

  @override
  String deliveryModeWokenByLastWake(Object who, Object agoLine) {
    return 'Réveillé par $who · dernier réveil $agoLine';
  }

  @override
  String get introBudgetTomorrow => 'demain';

  @override
  String introBudgetInDays(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'dans $countString jours',
      one: 'dans $countString jour',
    );
    return '$_temp0';
  }

  @override
  String get introBudgetInAnHour => 'dans une heure';

  @override
  String introBudgetInHours(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'dans $countString heures',
      one: 'dans $countString heure',
    );
    return '$_temp0';
  }

  @override
  String get introBudgetInAFewMinutes => 'dans quelques minutes';

  @override
  String get lockStateUnlockKryfo => 'Déverrouiller Kryfo';

  @override
  String get appInvalidUri => 'Uri invalide';

  @override
  String appBundleError(Object e) {
    return 'Erreur de bundle : $e';
  }

  @override
  String appAlreadySaved(Object parsed) {
    return 'Déjà enregistré : $parsed';
  }

  @override
  String appAddedYouCanMessage(Object parsed) {
    return '$parsed ajouté · vous pouvez lui écrire';
  }

  @override
  String appPeerImportedV1(Object parsed) {
    return 'Pair importé (v1) : $parsed';
  }

  @override
  String appLongWindow(Object line) {
    return '$line fenêtre longue';
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
      other: '$pString pages',
      one: '$pString page',
    );
    String _temp1 = intl.Intl.pluralLogic(
      e,
      locale: localeName,
      other: '$eString événements',
      one: '$eString événement',
    );
    return '$line ($heldString sur $subsString, connexion $c s, $_temp0, $_temp1)';
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
      other: '$pString pages',
      one: '$pString page',
    );
    String _temp1 = intl.Intl.pluralLogic(
      e,
      locale: localeName,
      other: '$eString événements',
      one: '$eString événement',
    );
    return '$line (connexion $c s, $_temp0, $_temp1)';
  }

  @override
  String appSDropped(Object host, Object secs) {
    return '$host $secs s, abandonné';
  }

  @override
  String appS(Object host, Object secs) {
    return '$host $secs s';
  }

  @override
  String get appTorWouldNotWake => 'Tor ne s’est pas réveillé';

  @override
  String get appCheckStarted => 'Démarré';

  @override
  String get appTorNotReadyIn => 'Tor pas prêt en 75 s';

  @override
  String get appOk => 'OK';

  @override
  String get appOkNoRelayBegan => 'OK, aucun relais n’a démarré';

  @override
  String get appOkCapped => 'OK, écourté';

  @override
  String appSBy(Object how, int secs, String why) {
    final intl.NumberFormat secsNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String secsString = secsNumberFormat.format(secs);

    String _temp0 = intl.Intl.selectLogic(why, {
      'push': '$how, $secsString s, par push',
      'other': '$how, $secsString s, par tâche de fond',
    });
    return '$_temp0';
  }

  @override
  String get appAnAttachmentCouldNot =>
      'Une pièce jointe n’a pas pu être enregistrée sur ce téléphone';

  @override
  String get appGroup2 => 'Groupe';

  @override
  String get appVoiceMessage => 'Message vocal';

  @override
  String get appPhoto => 'Photo';

  @override
  String get appNewRequest => 'Nouvelle demande';

  @override
  String get appSomeoneYouHaveNot =>
      'Quelqu’un que vous n’avez pas ajouté vous a écrit';

  @override
  String get appSettingUpYourKeys => 'Préparation de vos clés';

  @override
  String get appOpeningYourChats => 'Ouverture de vos discussions';

  @override
  String get appStartingTor => 'Démarrage de Tor';

  @override
  String get appTimedMessagesAreNot =>
      'Les messages éphémères ne s’effacent pas. Redémarrez Kryfo';

  @override
  String get appVoiceMessage2 => 'Message vocal';

  @override
  String appYou(Object body) {
    return 'Vous : $body';
  }

  @override
  String get appThisRoomHasAlready => 'Ce salon a déjà expiré';

  @override
  String get appYouAreAlreadyIn => 'Vous êtes déjà dans ce salon';

  @override
  String get appCouldNotMakeA => 'Impossible de créer une clé de salon';

  @override
  String appJoinedButYourHello(Object linkName) {
    return 'Vous avez rejoint $linkName, mais votre bonjour a été retenu';
  }

  @override
  String appJoined(Object linkName) {
    return 'Vous avez rejoint $linkName';
  }

  @override
  String appJoinedButTheCreator(Object linkName) {
    return 'Vous avez rejoint $linkName, mais le créateur n’a pas encore pu être joint';
  }

  @override
  String get appBooting => 'Démarrage...';

  @override
  String get appSettingUpYourIdentity => 'Préparation de votre identité...';

  @override
  String get appAddSomeone => 'Ajouter quelqu’un';

  @override
  String get appScanTheirCodeOr =>
      'Scannez son code, ou collez ce qu’on vous a donné : un lien, un @pseudo ou un lien de salon.';

  @override
  String get appScanTheirCode => 'Scanner son code';

  @override
  String get appAKryfoLinkA => 'Un lien Kryfo, un lien de salon ou @merle';

  @override
  String get appAddThem => 'Ajouter';

  @override
  String get appEveryWayToAdd => 'Toutes les façons d’ajouter quelqu’un';

  @override
  String get appShowYourCodeSend =>
      'Montrez votre code, envoyez un lien, réservez un pseudo';

  @override
  String get appHelloFromTheOther => 'Bonjour de l’autre côté';

  @override
  String get appIdentityRestored => 'Identité restaurée';

  @override
  String get appIdentityCreated => 'Identité créée';

  @override
  String get appStartingTor30s => 'Démarrage de tor (~30 s)...';

  @override
  String get appScanOrImportA => 'Scannez ou importez d’abord un pair';

  @override
  String get appEncryptingSending30s => 'Chiffrement + envoi (~30 s)...';

  @override
  String get appTapStartListeningFirst =>
      'Touchez d’abord « Commencer l’écoute »';

  @override
  String get appYourKryfo => 'Votre Kryfo';

  @override
  String get appUriCopied => 'Uri copiée';

  @override
  String get appCopyUri => 'Copier l’uri';

  @override
  String get appAddAKryfo => 'Ajouter un Kryfo';

  @override
  String get appScanQr => 'Scanner un QR';

  @override
  String get appPairingCode => 'Code d’appairage';

  @override
  String get appOrPaste => '- Ou collez -';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get appImport => 'Importer';

  @override
  String get appDev => 'Dév';

  @override
  String get appYourKryfo2 => 'Votre Kryfo :';

  @override
  String get appRestoredFromDisk => 'Restauré depuis le disque';

  @override
  String get appStartListening => 'Commencer l’écoute';

  @override
  String get appListening => 'À l’écoute';

  @override
  String get appShowMyQr => 'Afficher mon QR';

  @override
  String get appImportPeer => 'Importer un pair';

  @override
  String get appPeer => 'Pair :';

  @override
  String get appMessageWillBeEncrypted => 'Message (sera chiffré)';

  @override
  String get appEncryptSend => 'Chiffrer + envoyer';

  @override
  String appStatus(Object status) {
    return 'État : $status';
  }

  @override
  String get appSpeedPrivacy => 'Vitesse & confidentialité →';

  @override
  String get appGettingMessages => 'Réception des messages →';

  @override
  String get appDisableAppLock => 'Désactiver le verrouillage ?';

  @override
  String get appThePinWillBe =>
      'Le code PIN sera supprimé. Quiconque a votre téléphone verra Kryfo en l’ouvrant.';

  @override
  String get appDisable => 'Désactiver';

  @override
  String get appAppLockOn => 'Verrouillage · activé →';

  @override
  String get appAppLockOff => 'Verrouillage · désactivé →';

  @override
  String get appTorIsOff => 'Tor est désactivé';

  @override
  String get appConnectedRoutedThrough3 => 'Connecté · acheminé par 3 relais';

  @override
  String get appReadyToSendPublishing =>
      'Prêt à envoyer · publication de votre adresse';

  @override
  String get appReadyToSendFinishing =>
      'Prêt à envoyer · fin de la configuration';

  @override
  String appConnecting(Object pct) {
    return 'Connexion · $pct';
  }

  @override
  String get appTor => 'Tor';

  @override
  String get appTorIsOffTurn =>
      'Tor est désactivé. Activez-le pour vous connecter en privé.';

  @override
  String get appTheFirstConnectionTakes =>
      'La première connexion prend une minute ou deux, le temps que tor trace une route privée. Ensuite elle est gardée en cache, et Kryfo s’ouvre bien plus vite.';

  @override
  String get appRelayAndFastModes =>
      'Les modes Relais et Rapide se passent de tor et vont plus vite. Ils sont dans les paramètres, sous vitesse & confidentialité, et chacun dit ce qu’il coûte.';

  @override
  String get appViaRelay => 'Via relais';

  @override
  String get appOffline => 'Hors ligne';

  @override
  String get appFast => 'Rapide';

  @override
  String get appTorOff => 'Tor désactivé';

  @override
  String get appTorReady => 'Tor prêt';

  @override
  String get appConnecting2 => 'Connexion';

  @override
  String mediaProgressSendingKeepTheApp(Object v) {
    return 'Envoi · $v · gardez l’appli ouverte';
  }

  @override
  String mediaProgressPausedOfWaitingFor(Object count, Object count2) {
    return 'En pause · $count sur $count2 · en attente du reste';
  }

  @override
  String mediaProgressReceivingMedia(Object v) {
    return 'Réception du média · $v';
  }

  @override
  String get mediaProgressCancelSending => 'Interrompre l’envoi';

  @override
  String get metaReaderEndsBeforeItShould => 'se termine trop tôt';

  @override
  String get metaReaderCouldNotBeRead => 'illisible';

  @override
  String get metaReaderExifThatCannotBe => 'exif illisible';

  @override
  String get metaReaderSamsungTrailer => 'bloc final samsung';

  @override
  String metaReaderChunk(Object type) {
    return 'bloc $type';
  }

  @override
  String get metaReaderExifFlagSet => 'drapeau exif levé';

  @override
  String get metaReaderXmpFlagSet => 'drapeau xmp levé';

  @override
  String metaReaderAppBlock(Object id) {
    return 'bloc app $id';
  }

  @override
  String get metaReaderUuidBox => 'boîte uuid';

  @override
  String metaReaderBox(Object printable) {
    return 'boîte $printable';
  }

  @override
  String get metaReaderAttachedData => 'données jointes';

  @override
  String metaReaderItem(Object printable) {
    return 'élément $printable';
  }

  @override
  String get miuiAutostartAlreadyAllowedToRun =>
      'Déjà autorisé à fonctionner en arrière-plan';

  @override
  String get miuiAutostartLetKryfoRunIn =>
      'Laissez Kryfo fonctionner en arrière-plan';

  @override
  String get miuiAutostartYourPhonePausesApps =>
      'Votre téléphone met les applis en pause pour économiser la batterie. S’il n’en est pas exempté, Kryfo ne peut pas recevoir de messages quand il est fermé.';

  @override
  String get commonAllow => 'Autoriser';

  @override
  String get commonSkip => 'Passer';

  @override
  String get miuiAutostartXiaomiTurnsOffBackground =>
      'Par défaut, Xiaomi coupe les applis en arrière-plan. Sans démarrage automatique, Kryfo ne peut pas distribuer les messages quand l’appli est fermée. Sur l’écran suivant, trouvez Kryfo dans la liste et activez l’interrupteur.';

  @override
  String get miuiAutostartOpenSettings => 'Ouvrir les paramètres';

  @override
  String get miuiAutostartCouldnTOpenIt =>
      'Impossible de l’ouvrir. Cherchez démarrage automatique dans les paramètres du téléphone';

  @override
  String get notificationsNewEncryptedMessagesFrom =>
      'Nouveaux messages chiffrés de vos contacts';

  @override
  String get notificationsNewMessage => 'Nouveau message';

  @override
  String get notificationsNewEncryptedMessagesFromYourContacts =>
      'Nouveaux messages chiffrés de vos contacts';

  @override
  String get notificationsNewMessage2 => 'Nouveau message';

  @override
  String get notificationsEncrypted => 'Chiffré';

  @override
  String get rooms24h => '24 h';

  @override
  String roomsD(Object inDays) {
    return '$inDays j';
  }

  @override
  String roomsH(Object inHours) {
    return '$inHours h';
  }

  @override
  String get rooms24Hours => '24 heures';

  @override
  String roomsDays(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString jours',
      one: '$countString jour',
    );
    return '$_temp0';
  }

  @override
  String get roomsAnHour => 'une heure';

  @override
  String get roomsAboutAnHour => 'environ une heure';

  @override
  String roomsHours(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString heures',
      one: '$countString heure',
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
      other: 'environ $countString heures',
      one: 'environ $countString heure',
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
      other: '$countString minutes',
      one: '$countString minute',
    );
    return '$_temp0';
  }

  @override
  String get roomsAMinute => 'une minute';

  @override
  String get roomsExpired => 'Expiré';

  @override
  String roomsDH(Object inDays, Object h) {
    return '$inDays j $h h';
  }

  @override
  String roomsHM(Object inHours, Object m) {
    return '$inHours h $m min';
  }

  @override
  String roomsM(Object inMinutes) {
    return '$inMinutes min';
  }

  @override
  String get scamShieldLooksLikeAScam => 'On dirait une arnaque';

  @override
  String scamShieldThisNameMatches(Object shown) {
    return 'Ce nom correspond à $shown';
  }

  @override
  String scamShieldNameMatchesYourContact(Object shown) {
    return 'Le nom correspond à votre contact $shown';
  }

  @override
  String scamShieldSameFaceAsYour(Object shown) {
    return 'Même visage que votre contact $shown';
  }

  @override
  String get scamShieldContainsACryptoAddress => 'Contient une adresse crypto';

  @override
  String get scamShieldMentionsMoneyAndUrgency =>
      'Parle d’argent et d’urgence à la fois';

  @override
  String get scamShieldAsksYouToMove =>
      'Vous demande de passer sur une autre appli';

  @override
  String get scamShieldLinksToALookalike =>
      'Renvoie vers une imitation d’un site connu';

  @override
  String get scamShieldALongOpenerFrom =>
      'Un long premier message de quelqu’un sans historique';

  @override
  String get scamShieldAsksForACode =>
      'Demande un code, une phrase de récupération ou un fichier de secours';

  @override
  String scamShieldAlso(Object shown) {
    return 'Aussi : le nom correspond à votre contact $shown';
  }

  @override
  String get commonBack => 'Retour';

  @override
  String get archivedArchived => 'Archivées';

  @override
  String get archivedCount0 => 'Aucune';

  @override
  String get archivedCount1 => 'Une';

  @override
  String get archivedCount2 => 'Deux';

  @override
  String get archivedCount3 => 'Trois';

  @override
  String get archivedCount4 => 'Quatre';

  @override
  String get archivedCount5 => 'Cinq';

  @override
  String get archivedCount6 => 'Six';

  @override
  String get archivedCount7 => 'Sept';

  @override
  String get archivedCount8 => 'Huit';

  @override
  String get archivedCount9 => 'Neuf';

  @override
  String get archivedCount10 => 'Dix';

  @override
  String get archivedChatRestingHereIt =>
      'Discussion au repos ici. Elle reste silencieuse jusqu’à ce qu’on y écrive, puis revient en haut.';

  @override
  String get archivedChatsRestingHere =>
      'Discussions au repos ici. Elles restent silencieuses jusqu’à ce que quelqu’un écrive, puis reviennent en haut.';

  @override
  String get archivedNothingArchived => 'Rien d’archivé';

  @override
  String get archivedArchivedChatsAreStill =>
      'Les discussions archivées restent chiffrées de bout en bout';

  @override
  String get archivedUnarchive => 'Désarchiver';

  @override
  String get avatarPickerThePeopleYouMessage =>
      'Les personnes à qui vous écrivez le voient aussi';

  @override
  String get avatarPickerBackToYourInitial => 'Revenir à votre initiale';

  @override
  String get avatarPickerThatOneIsYours => 'C’est le vôtre';

  @override
  String get avatarPickerPickAFace => 'Choisir un visage';

  @override
  String get commonSave => 'Enregistrer';

  @override
  String get backupPassphraseMustBeAt =>
      'La phrase secrète doit faire au moins 6 caractères';

  @override
  String get backupPassphrasesDonTMatch => 'Les phrases secrètes diffèrent';

  @override
  String get backupBackupSavedKeepThe =>
      'Sauvegarde enregistrée · gardez la phrase secrète en lieu sûr';

  @override
  String get backupKryfoBackup => 'Sauvegarde Kryfo';

  @override
  String get backupYourEncryptedKryfoBackup =>
      'Votre sauvegarde Kryfo chiffrée. Gardez ce fichier ET votre phrase secrète en lieu sûr - il faut les deux pour restaurer.';

  @override
  String get backupBackUpKryfo => 'Sauvegarder Kryfo';

  @override
  String get backupBackUp => 'Sauvegarder';

  @override
  String get backupACopyToKeep =>
      'Une copie à garder. Ce téléphone continue comme avant.';

  @override
  String get backupMoveToAnotherDevice => 'Passer sur un autre appareil';

  @override
  String get backupTheFileTakesThis =>
      'Le fichier emporte cette identité. Dès qu’il est créé, ce téléphone s’arrête : plus rien de nouveau n’arrive ici, et rien de ce qui est envoyé d’ici n’atteint personne.';

  @override
  String get backupOneEncryptedFileYour =>
      'Un seul fichier chiffré : votre identité, vos contacts, chaque message, et chaque photo, note vocale et fichier. Importez-le sur l’autre appareil avec la phrase secrète. D’ici là, vous pouvez encore changer d’avis et rester sur ce téléphone.';

  @override
  String get backupOneEncryptedFileYourIdentityYour =>
      'Un seul fichier chiffré : votre identité, vos contacts, chaque message, et chaque photo, note vocale et fichier présents sur ce téléphone en ce moment. Ce qui se dira après aujourd’hui n’y sera pas, alors refaites-en une quand ça compte. Pour restaurer, il vous faut le fichier et la phrase secrète, les deux.';

  @override
  String get backupPassphrase => 'Phrase secrète';

  @override
  String get backupConfirmPassphrase => 'Confirmer la phrase secrète';

  @override
  String backupWriting(Object progress) {
    return 'Écriture… $progress';
  }

  @override
  String get backupCreating => 'Création…';

  @override
  String get backupMakeTheFileAnd => 'Créer le fichier et partir';

  @override
  String get backupCreateBackup => 'Créer la sauvegarde';

  @override
  String get backupHiddenNotIn => 'Les discussions masquées n’y sont pas.';

  @override
  String get backupHiddenIncluded => 'Vos discussions masquées y sont aussi.';

  @override
  String get backupMoveHiddenStay =>
      'Les discussions masquées restent sur ce téléphone et sont effacées avec lui.';

  @override
  String get backupHiddenGone =>
      'Vos discussions masquées se sont fermées quand Kryfo s’est verrouillé. Ouvrez-les avec leur code et faites la sauvegarde à partir de là.';

  @override
  String get blockedBlocked => 'Bloqués';

  @override
  String get blockedNoOneIsBlocked => 'Personne n’est bloqué';

  @override
  String get commonUnblock => 'Débloquer';

  @override
  String get bridgesThatWasNotIt => 'Ce n’était pas ça. En voici une autre.';

  @override
  String get bridgesGotBridgesSaveTo =>
      'Ponts reçus · enregistrez pour les utiliser';

  @override
  String get bridgesConnected => 'Connecté';

  @override
  String get bridgesNotThroughYetTor =>
      'Pas encore passé. Tor continue d’essayer';

  @override
  String get bridgesBridges => 'Ponts';

  @override
  String get bridgesTorIsBlockedWhere => 'Tor est bloqué là où vous êtes ?';

  @override
  String get bridgesBridgesDisguiseYourConnection =>
      'Les ponts déguisent votre connexion pour qu’elle puisse sortir. Choisissez une entrée, enregistrez, et tor se reconnecte par elle.';

  @override
  String get bridgesBridgesOnlyChangeHow =>
      'Les ponts ne changent que la façon dont tor se connecte, et vous n’êtes pas en mode Onion en ce moment. Ce que vous réglez ici est enregistré, mais ne sert à rien tant que vous ne repassez pas en mode Onion.';

  @override
  String get bridgesFromTheTorProject => 'Du projet tor';

  @override
  String get bridgesNoise => 'Du bruit';

  @override
  String get bridgesGood => 'Bonne';

  @override
  String get bridgesMakesTorTrafficLook =>
      'Fait passer le trafic tor pour rien de particulier. Le meilleur choix par défaut pour la plupart des réseaux bloqués. Après une image à déchiffrer, vous recevez quelques lignes.';

  @override
  String get bridgesPrivateBridge => 'Pont privé';

  @override
  String get bridgesALineFromA => 'Une ligne d’un proche';

  @override
  String get bridgesWhateverTheLineSays => 'Ce que dit la ligne';

  @override
  String get bridgesDepends => 'Ça dépend';

  @override
  String get bridgesGotABridgeLine =>
      'Une personne de confiance vous a donné une ligne de pont, ou vous en avez une de bridges.torproject.org ? Collez-la ici. Lignes obfs4 uniquement, Kryfo ne parle pas encore les autres.';

  @override
  String get bridgesPasteFromClipboard => 'Coller depuis le presse-papiers';

  @override
  String get bridgesUseBridges => 'Utiliser des ponts';

  @override
  String get bridgesNoLinesYet => 'Pas encore de ligne';

  @override
  String bridges1LineSaved(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString lignes enregistrées',
      one: '$countString ligne enregistrée',
    );
    return '$_temp0';
  }

  @override
  String get bridgesRestartingTor => 'Redémarrage de tor…';

  @override
  String bridgesFindingABridgeS(Object elapsed) {
    return 'Recherche d’un pont… $elapsed s';
  }

  @override
  String bridgesStillTryingS(Object elapsed) {
    return 'On essaie encore… $elapsed s';
  }

  @override
  String get bridgesApplying => 'Mise en place…';

  @override
  String get bridgesSaveAndReconnect => 'Enregistrer et reconnecter';

  @override
  String get bridgesWhatABridgeIs => 'Ce qu’est un pont';

  @override
  String get bridgesATorEntryPoint =>
      'Un point d’entrée tor que personne n’a publié, atteint à travers une enveloppe pour que la connexion ne ressemble pas à tor. Le reste de la route, ce sont les trois sauts habituels.';

  @override
  String get bridgesLooksLike => 'Ressemble à';

  @override
  String get bridgesSpeed => 'Vitesse';

  @override
  String get bridgesGetBridges => 'Obtenir des ponts';

  @override
  String get bridgesAskTheTorProject =>
      'Demandez directement au projet tor. Vous déchiffrez une image, pour que des robots ne puissent pas vider la réserve.';

  @override
  String get bridgesTypeWhatYouSee =>
      'Tapez ce que vous voyez. Minuscules acceptées.';

  @override
  String get bridgesThisOneRequestDoes =>
      'Cette seule demande ne passe pas par tor - elle ne le peut pas, puisque c’est justement tor qui ne marche pas. Quiconque gère votre réseau vous verra contacter le projet tor. Si cela seul pose problème là où vous êtes, procurez-vous des ponts ailleurs et collez-les ci-dessous.';

  @override
  String get bridgesCouldNotDrawThe => 'Impossible d’afficher l’image';

  @override
  String get bridgesAnswer => 'Réponse';

  @override
  String get bridgesAsking => 'Demande…';

  @override
  String get bridgesRequestBridges => 'Demander des ponts';

  @override
  String get bridgesDifferentPuzzle => 'Autre image';

  @override
  String get cameraNoCameraOnThis => 'Pas de caméra sur ce téléphone';

  @override
  String get cameraCameraNotAvailable => 'Caméra indisponible';

  @override
  String get cameraCameraPermissionIsOff =>
      'Accès à la caméra refusé · touchez pour réessayer';

  @override
  String get cameraCouldNotStripThat =>
      'Impossible de nettoyer cette photo, elle a été écartée';

  @override
  String get cameraNoPhotoCameOut => 'Aucune photo obtenue';

  @override
  String get cameraCouldNotStartRecording =>
      'Impossible de lancer l’enregistrement';

  @override
  String get cameraTheRecordingWasLost => 'L’enregistrement a été perdu';

  @override
  String get cameraACopyIsIn => 'Une copie est dans vos photos';

  @override
  String get cameraCouldNotSaveA =>
      'Impossible d’enregistrer une copie sur ce téléphone';

  @override
  String get cameraTooLongForA => 'Trop long pour un message · 8 Mo max';

  @override
  String get cameraNeverSavedToYour => 'Jamais enregistré dans vos photos';

  @override
  String get cameraNoExifNeverSaved =>
      'Pas d’exif, jamais enregistré dans vos photos';

  @override
  String get cameraRec => 'Enr';

  @override
  String get cameraSwitchCamera => 'Changer de caméra';

  @override
  String cameraClipSMb(Object secs, Object mb) {
    return 'Vidéo · $secs s · $mb Mo';
  }

  @override
  String get cameraStopRecording => 'Arrêter la vidéo';

  @override
  String get cameraStartRecording => 'Démarrer la vidéo';

  @override
  String get cameraTakeAPhoto => 'Prendre une photo';

  @override
  String get cameraKeepACopy => 'Garder une copie';

  @override
  String get cameraUseThis => 'Utiliser';

  @override
  String chatB(Object bytes) {
    return '$bytes o';
  }

  @override
  String chatKb(Object bytes) {
    return '$bytes Ko';
  }

  @override
  String chatMb(Object bytes) {
    return '$bytes Mo';
  }

  @override
  String get chatFile => 'FICHIER';

  @override
  String get chatYouAreOfflineThis =>
      'Vous êtes hors ligne · ceci partira tout seul à la reconnexion';

  @override
  String get chatStillConnectingToTor =>
      'Connexion à Tor en cours · il partira tout seul';

  @override
  String chatS(Object seconds) {
    return '$seconds s';
  }

  @override
  String chatM(Object seconds) {
    return '$seconds min';
  }

  @override
  String chatH(Object seconds) {
    return '$seconds h';
  }

  @override
  String chatD(Object seconds) {
    return '$seconds j';
  }

  @override
  String get chat0s => '0 s';

  @override
  String chatHM(Object h, Object m) {
    return '$h h $m min';
  }

  @override
  String chatMS(Object m, Object s) {
    return '$m min $s s';
  }

  @override
  String chatS2(Object s) {
    return '$s s';
  }

  @override
  String get chatNewMessages => 'Nouveaux messages';

  @override
  String get chatUnsave => 'Retirer';

  @override
  String get chatForward => 'Transférer';

  @override
  String get commonShare => 'Partager';

  @override
  String get commonCopied => 'Copié';

  @override
  String get commonCopy => 'Copier';

  @override
  String get chatUnpin => 'Désépingler';

  @override
  String get chatPin => 'Épingler';

  @override
  String get chatStopSending => 'Arrêter l’envoi';

  @override
  String get chatUnsend => 'Annuler l’envoi';

  @override
  String get commonEdit => 'Modifier';

  @override
  String get chatYou => 'Vous';

  @override
  String get chatUnsendMessage => 'Annuler l’envoi du message';

  @override
  String get chatItDisappearsWithNo =>
      'Il disparaît sans laisser de trace. C’est irréversible.';

  @override
  String chatThisChatHasPins(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Cette discussion a déjà $countString messages épinglés',
      one: 'Cette discussion a déjà $countString message épinglé',
    );
    return '$_temp0';
  }

  @override
  String get chatUnpinThisMessage => 'Désépingler ce message ?';

  @override
  String get chatPinThisMessage => 'Épingler ce message ?';

  @override
  String get chatItLeavesThePinned =>
      'Il quitte la liste des messages épinglés, pour vous deux.';

  @override
  String get chatItGoesUnderThe =>
      'Il rejoint les messages épinglés en haut de la discussion, pour vous deux.';

  @override
  String get chatPinIt => 'Épingler';

  @override
  String get chatNotNow => 'Pas maintenant';

  @override
  String get chatEditMessage => 'Modifier le message';

  @override
  String get chat30Seconds => '30 secondes';

  @override
  String get chat1Minute => '1 minute';

  @override
  String get chat5Minutes => '5 minutes';

  @override
  String get chat1Hour => '1 heure';

  @override
  String get chat24Hours => '24 heures';

  @override
  String get chatGhostTimer => 'Messages éphémères';

  @override
  String get chatHowLongBeforeSent =>
      'Combien de temps avant que les messages envoyés disparaissent ?';

  @override
  String get chatCamera => 'Caméra';

  @override
  String get chatNoExifNeverSaved =>
      'Pas d’exif, jamais enregistré dans vos photos';

  @override
  String get chatGallery => 'Galerie';

  @override
  String get chatVideo => 'Vidéo';

  @override
  String get chatGifFromPhone => 'Gif du téléphone';

  @override
  String get chatFile2 => 'Fichier';

  @override
  String get chatAFewSeconds => 'Quelques secondes';

  @override
  String get chatUnderAMinute => 'Moins d’une minute';

  @override
  String chatRoughlyMin(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Environ $countString min',
    );
    return '$_temp0';
  }

  @override
  String chatB2(Object b) {
    return '$b o';
  }

  @override
  String chatKb2(Object b) {
    return '$b Ko';
  }

  @override
  String chatMb2(Object b) {
    return '$b Mo';
  }

  @override
  String get chatSendThis => 'Envoyer ce fichier ?';

  @override
  String chatOverTor(Object humanBytes, Object wireEstimate) {
    return '$humanBytes · $wireEstimate par tor';
  }

  @override
  String get chatBigFilesGoOut =>
      'Les gros fichiers partent en petits morceaux chiffrés, donc ça prend un moment. Gardez l’appli ouverte et l’envoi continue.';

  @override
  String get chatSendIt => 'Envoyer';

  @override
  String get chatCouldNotReadThat => 'Impossible de lire ce fichier';

  @override
  String get chatFileTooBig8 => 'Fichier trop gros · 8 Mo max';

  @override
  String get chatCouldNotCleanThat => 'Impossible de nettoyer cette vidéo';

  @override
  String get chatCouldNotCleanThatPictureSend =>
      'Impossible de nettoyer cette image · envoyez-la comme photo';

  @override
  String get chatGifTooBig8 => 'Gif trop gros · 8 Mo max';

  @override
  String get chatCouldNotCleanThatGif => 'Impossible de nettoyer ce gif';

  @override
  String get chatTorIsNotUp => 'Tor n’est pas encore prêt · envoi sans aperçu';

  @override
  String get chatCouldnTReachIt =>
      'Impossible de l’atteindre · envoi sans aperçu';

  @override
  String get chatNoTitleCameBack => 'Aucun titre reçu · envoi sans aperçu';

  @override
  String get chatCouldnTFetchIt =>
      'Impossible de le récupérer · envoi sans aperçu';

  @override
  String get chatNoSignalSessionRe =>
      'Pas de session Signal - appairez à nouveau';

  @override
  String get chatMessageUnavailable => 'Message indisponible';

  @override
  String get chatYou2 => 'Vous';

  @override
  String get chatThem => 'L’autre';

  @override
  String get chatVoiceMessage => 'Message vocal';

  @override
  String get chatQuotedPhoto => 'Photo';

  @override
  String get chatViewContact => 'Voir le contact';

  @override
  String get chatSharedPhotos => 'Photos partagées';

  @override
  String chatSharedPhotoCount(int count, Object title) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString photos',
      one: '$countString photo',
    );
    return '$_temp0 · $title';
  }

  @override
  String get chatUnmuteNotifications => 'Réactiver les notifications';

  @override
  String get chatMuteNotifications => 'Couper les notifications';

  @override
  String get chatArchiveChat => 'Archiver';

  @override
  String get chatWallpaper => 'Fond d’écran';

  @override
  String get chatClearConversation => 'Vider la discussion';

  @override
  String get chatNoteOnThisContact => 'Note sur ce contact';

  @override
  String get chatPinToTop => 'Épingler en haut';

  @override
  String get chatBlockContact => 'Bloquer le contact';

  @override
  String get chatUnpinned => 'Désépinglée';

  @override
  String get chatPinnedToTop => 'Épinglée en haut';

  @override
  String get chatJustForYouNever =>
      'Juste pour vous. Jamais envoyée, elle ne quitte jamais ce téléphone.';

  @override
  String get chatAQuietReminder => 'Un petit rappel…';

  @override
  String get chatNoteSaved => 'Note enregistrée';

  @override
  String get chatClearThisConversation => 'Vider cette discussion ?';

  @override
  String get chatEveryMessageHereIs =>
      'Chaque message ici est effacé de ce téléphone. Cela ne vide que votre copie - cela ne touche pas à son appareil.';

  @override
  String get chatClear => 'Vider';

  @override
  String get chatBlockThisContact => 'Bloquer ce contact ?';

  @override
  String get chatTheirMessagesStopArriving =>
      'Ses messages n’arrivent plus et ce contact disparaît de vos discussions. Il n’en est jamais averti. Vous pouvez le débloquer quand vous voulez depuis les paramètres.';

  @override
  String get commonBlock => 'Bloquer';

  @override
  String get chatSaved => 'Enregistré';

  @override
  String get chatRemovedFromSaved => 'Retiré des enregistrés';

  @override
  String get chatForwardTo => 'Transférer à';

  @override
  String get chatNoContactsToForward => 'Aucun contact à qui transférer';

  @override
  String get chatToday => 'Aujourd’hui';

  @override
  String get chatYesterday => 'Hier';

  @override
  String get chatThisMessageCanT => 'Ce message ne peut pas être affiché';

  @override
  String get chatJumpToTheNewest => 'Aller au plus récent';

  @override
  String get chatBuildingAPrivateRoute =>
      'Construction d’une route privée · la première connexion est lente, les suivantes sont rapides. Ce que vous envoyez maintenant est mis en attente et partira tout seul.';

  @override
  String get chatLooksSafeNothingSuspicious =>
      'Semble sûr · rien de suspect dans son premier message';

  @override
  String get chatTheNextPhotoYou =>
      'La prochaine photo que vous envoyez s’ouvre protégée · la personne ne pourra pas en faire de capture d’écran';

  @override
  String get chatPhotoProtectionOff => 'Protection photo désactivée';

  @override
  String get chatAcceptToReplyThey =>
      'Acceptez pour répondre - d’ici là, la personne ne peut envoyer qu’un message de plus.';

  @override
  String chatIntroducedYouAcceptTo(Object introducer) {
    return 'Présentés par $introducer. Acceptez pour répondre.';
  }

  @override
  String chatIntroducedYouSayHello(Object vouchNames) {
    return 'Présentés par $vouchNames. Dites bonjour - la personne a aussi reçu votre carte.';
  }

  @override
  String get chatIntroduceTo => 'Présenter à...';

  @override
  String get chatAcceptThemFirst => 'Acceptez d’abord la demande';

  @override
  String get chatMessageRequest => 'Demande de message';

  @override
  String get chatTheyNeedToAccept =>
      'La personne doit accepter avant que vous puissiez continuer à discuter.';

  @override
  String get chatWaitingForThemTo =>
      'En attente de l’acceptation de votre demande';

  @override
  String get chatYouBlockedThisContact => 'Vous avez bloqué ce contact';

  @override
  String get chatSupporter => 'Soutien';

  @override
  String get chatEncryptedViaRelay => 'Chiffré · via relais';

  @override
  String get chatEncryptedDirect => 'Chiffré · direct';

  @override
  String get chatEncryptedOverTor => 'Chiffré · par tor';

  @override
  String get chatSearchThisChat => 'Rechercher';

  @override
  String get chatContactOptions => 'Options du contact';

  @override
  String get commonClose => 'Fermer';

  @override
  String get chatFindInConversation => 'Chercher dans la discussion';

  @override
  String get chatNoMatches => 'Aucun résultat';

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
      other: '*$posString* sur $countString résultats',
      one: '*$posString* sur $countString résultat',
    );
    return '$_temp0';
  }

  @override
  String get chatPreviousMatch => 'Résultat précédent';

  @override
  String get chatNextMatch => 'Résultat suivant';

  @override
  String get chatPhotoUnavailable => 'Photo indisponible';

  @override
  String get chatDelivered => 'Distribué';

  @override
  String get chatEdited => 'Modifié';

  @override
  String get chatWaitingForThemToComeOnline =>
      'En attente que la personne se connecte ou vous ajoute à son tour';

  @override
  String get chatFailedTapToRetry => 'Échec · touchez pour réessayer';

  @override
  String get chatReplyingTo => 'Réponse à son message';

  @override
  String get chatReplyingToYourself => 'Réponse à votre message';

  @override
  String get chatReply => 'Répondre';

  @override
  String get chatSayHi => 'Dites bonjour.';

  @override
  String get chatJustTheTwoOf => 'Juste vous deux, chiffré de bout en bout.';

  @override
  String get chatMicPermissionNeeded => 'Accès au micro requis';

  @override
  String get chatTheMicWouldNot => 'Le micro n’a pas démarré. Réessayez';

  @override
  String get chatReleaseToCancel => 'Relâchez pour annuler';

  @override
  String get chatVoiceHiddenSlideTo => 'Voix déguisée · glissez pour annuler';

  @override
  String get chatSlideToCancel => 'Glissez pour annuler';

  @override
  String get chatGhostMode => 'Messages éphémères';

  @override
  String chatMessagesBurnAfter(Object humanBurn) {
    return 'disparaissent après $humanBurn';
  }

  @override
  String get chatTimedMessages => 'Messages éphémères';

  @override
  String get chatOpenTheCamera => 'Ouvrir la caméra';

  @override
  String get chatAttachAPhoto => 'Joindre une photo';

  @override
  String get chatMessage => 'Message';

  @override
  String get chatDisguiseVoice => 'Déguiser la voix';

  @override
  String get commonSend => 'Envoyer';

  @override
  String get chatNoPhotosInThis => 'Pas encore de photos dans cette discussion';

  @override
  String get chatSendPhoto => 'Envoyer la photo';

  @override
  String get chatAddACaption => 'Ajouter une légende…';

  @override
  String get chatSecurityCodeChanged => 'Code de sécurité modifié';

  @override
  String chatMayHaveReinstalledOr(Object peerName) {
    return '$peerName a peut-être réinstallé l’appli, ou quelqu’un se fait peut-être passer pour cette personne. Comparez les numéros de sécurité pour vous en assurer.';
  }

  @override
  String get chatOk => 'OK';

  @override
  String get chatVerify => 'Vérifier';

  @override
  String get cleanKryfoCanTClean =>
      'Kryfo ne peut pas encore nettoyer ce type de fichier.';

  @override
  String get cleanThisIsAMotion => 'C’est une photo animée.';

  @override
  String get cleanThisPictureIsToo =>
      'Cette image est trop grande pour être nettoyée ici.';

  @override
  String get cleanThisFileIsDamaged => 'Ce fichier est endommagé ou tronqué.';

  @override
  String get cleanKryfoCouldNotMake => 'Kryfo n’a pas pu nettoyer celui-ci.';

  @override
  String get cleanNotEnoughRoomOn => 'Pas assez de place sur le téléphone.';

  @override
  String get cleanKryfoCouldNotOpen => 'Kryfo n’a pas pu ouvrir ce fichier.';

  @override
  String get cleanItCleansJpegPng =>
      'Kryfo nettoie les JPEG, PNG, WebP, HEIC, AVIF, GIF, MP4 et MOV. Rien n’a été modifié.';

  @override
  String get cleanItHoldsAShort =>
      'Elle contient une courte vidéo à côté de l’image, et Kryfo ne peut pas encore nettoyer cette partie. Désactivez les photos animées dans votre appareil photo, ou envoyez-en une capture d’écran.';

  @override
  String get cleanPicturesOver64Mb =>
      'Les images de plus de 64 Mo ne sont pas nettoyées sur le téléphone. Rien n’a été modifié.';

  @override
  String get cleanKryfoCouldNotRead =>
      'Kryfo n’a pas pu le lire jusqu’au bout, alors il ne le déclarera pas propre. Aucune copie n’a été faite.';

  @override
  String get cleanSomethingInsideIsOf =>
      'Il contient quelque chose d’un type que Kryfo ne sait pas retirer, donc aucune copie n’a été faite.';

  @override
  String get cleanFreeSomeSpaceAnd =>
      'Libérez de la place et réessayez. Rien n’a été modifié.';

  @override
  String get cleanTheAppThatShared =>
      'L’appli qui l’a partagé l’a peut-être repris. Essayez de le partager à nouveau.';

  @override
  String get cleanNoAppOnThis =>
      'Aucune appli de ce téléphone n’a pris le fichier.';

  @override
  String get cleanCouldNotSaveIt =>
      'Impossible de l’enregistrer. Vérifiez qu’il reste de la place sur le téléphone.';

  @override
  String get cleanTheOriginalIsGone =>
      'L’original a disparu. La copie propre reste.';

  @override
  String get cleanAndroidWouldNotDelete =>
      'Android a refusé de le supprimer. Retirez-le de la galerie à la main.';

  @override
  String get cleanCleanCopy => 'Copie propre';

  @override
  String get cleanShareCleanCopy => 'Partager la copie propre';

  @override
  String get cleanSaveToGallery => 'Enregistrer dans la galerie';

  @override
  String get commonStop => 'Arrêter';

  @override
  String get cleanReadingTheFile => 'Lecture du fichier';

  @override
  String get cleanCleaning => 'Nettoyage';

  @override
  String cleanOf(Object prettySize, Object prettySize2) {
    return '$prettySize sur $prettySize2';
  }

  @override
  String get cleanEverythingStaysOnThis => 'Tout reste sur ce téléphone.';

  @override
  String get cleanAlreadyClean => 'Déjà propre.';

  @override
  String get cleanClean => 'Propre.';

  @override
  String get cleanThereWasNothingTo => 'Il n’y avait rien à trouver.';

  @override
  String get cleanNothingLeftToFind => 'Plus rien à trouver.';

  @override
  String get cleanSameVideoSameQuality => 'Même vidéo, même qualité';

  @override
  String get cleanSamePictureSameQuality => 'Même image, même qualité';

  @override
  String cleanRemoved(Object label) {
    return '$label, retiré';
  }

  @override
  String get cleanRemoved2 => 'RETIRÉ';

  @override
  String get cleanWithTheLocationInside =>
      'avec la position dedans. Quiconque l’obtient connaît votre rue.';

  @override
  String get cleanWithEverythingItKnew =>
      'avec tout ce qu’il savait encore dedans.';

  @override
  String get cleanOriginal => 'ORIGINALE';

  @override
  String get cleanClean2 => 'PROPRE';

  @override
  String get cleanSavedToYourGallery => 'Enregistré dans votre galerie.';

  @override
  String cleanTheOriginalIsStill(Object what) {
    return 'L’original est toujours là, lui aussi, $what';
  }

  @override
  String cleanTheOriginalIsStillWhereIt(Object what) {
    return 'L’original est toujours là où il était, $what Kryfo ne peut pas le supprimer d’ici, alors supprimez-le dans l’appli d’où il vient.';
  }

  @override
  String get cleanDeleteTheOriginal => 'Supprimer l’original';

  @override
  String get cleanKeepBoth => 'Garder les deux';

  @override
  String get commonDone => 'Terminé';

  @override
  String get cleanAndroidWillAskYou => 'ANDROID VOUS DEMANDERA DE CONFIRMER';

  @override
  String get contactYourNameForThem => 'Votre surnom pour ce contact';

  @override
  String get contactStaysOnThisPhone =>
      'Reste sur ce téléphone. Ce contact ne le voit jamais.';

  @override
  String get contactClear => 'Effacer';

  @override
  String get contactMessage => 'Écrire';

  @override
  String get contactKeysVerified => 'Clés vérifiées';

  @override
  String get contactVerifyKeys => 'Vérifier les clés';

  @override
  String get contactVouches => 'Recommandations';

  @override
  String get contactUnmute => 'Remettre le son';

  @override
  String get contactMute => 'Couper le son';

  @override
  String get contactUnpin => 'Désépingler';

  @override
  String get contactPinToTop => 'Épingler en haut';

  @override
  String get contactArchive => 'Archiver';

  @override
  String get contactOutOfTheList =>
      'Hors de la liste jusqu’à son prochain message';

  @override
  String contactBlock(Object name) {
    return 'Bloquer $name ?';
  }

  @override
  String get contactTheirMessagesStopArriving =>
      'Ses messages n’arrivent plus. Ce contact n’en est pas averti.';

  @override
  String get contactDeleteChat => 'Supprimer la discussion';

  @override
  String get contactMessagesAndContactGone =>
      'Messages et contact, supprimés de ce téléphone';

  @override
  String get contactDeleteThisChat => 'Supprimer cette discussion ?';

  @override
  String get contactEveryMessageAndThe =>
      'Chaque message et le contact, supprimés de ce téléphone. Rien ne lui est envoyé.';

  @override
  String get commonDelete => 'Supprimer';

  @override
  String get contactDeleted => 'Supprimée';

  @override
  String get contactToday => 'Auj.';

  @override
  String contactD(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours',
      one: '$count jour',
    );
    return '$_temp0';
  }

  @override
  String contactMo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mois',
    );
    return '$_temp0';
  }

  @override
  String contactY(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ans',
      one: '$count an',
    );
    return '$_temp0';
  }

  @override
  String get contactVerified => 'Vérifié';

  @override
  String get contactChatting => 'En contact';

  @override
  String get contactNothingSharedYet => 'Pas encore de partage';

  @override
  String contactSharedMedia(Object count) {
    return 'Médias partagés · $count';
  }

  @override
  String get donateBitcoin => 'Bitcoin';

  @override
  String get donateText => '₿';

  @override
  String get donateBadgeUnlocks => 'Débloque un badge';

  @override
  String get donateMonero => 'Monero';

  @override
  String get donateManualNoBadge => 'Manuel · sans badge';

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
          'Votre paiement bitcoin précédent a été vu · badge soutien débloqué',
      'patron':
          'Votre paiement bitcoin précédent a été vu · badge mécène débloqué',
      'guardian':
          'Votre paiement bitcoin précédent a été vu · badge gardien débloqué',
      'other':
          'Votre paiement bitcoin précédent a été vu · badge soutien débloqué',
    });
    return '$_temp0';
  }

  @override
  String get donateSupport => 'Soutenir';

  @override
  String get donateKeepKryfo => 'Gardez Kryfo *indépendant*';

  @override
  String get donateNoAdsNoInvestors =>
      'Pas de pub, pas d’investisseurs, rien à vendre. Kryfo vit de ce que donnent ceux qui le soutiennent.';

  @override
  String get donateBackItAnonymouslyBadge =>
      'Soutenez-le anonymement. Badge facultatif.\n*La vie privée n’est jamais payante.*';

  @override
  String donateAddressCheckItAgainst(Object coinName) {
    return 'Adresse $coinName · vérifiez-la dans votre portefeuille';
  }

  @override
  String get donateAddressCopiedClearsIn =>
      'Adresse copiée · effacée dans 60 s';

  @override
  String get donateCopyAddress => 'Copier l’adresse';

  @override
  String get donateBitcoinIsVerifiedBy =>
      'Le bitcoin est vérifié par notre propre nœud : votre badge se débloque tout seul dès que le paiement arrive.';

  @override
  String get donateWeCanTVerify =>
      'Nous ne pouvons pas vérifier cette chaîne sans interroger un service extérieur à votre sujet, alors nous ne le faisons pas. Envoyez si vous voulez. Cela ne débloquera pas de badge.';

  @override
  String get donateBitcoinBadgesNeedOnion =>
      'Les badges bitcoin demandent le mode Onion';

  @override
  String get donateSwitchToOnion => 'Passer en mode Onion';

  @override
  String get donatePayWithBitcoin => 'Payer en bitcoin  →';

  @override
  String get donateBadgesStartAt20 => 'Badges dès 20 \$';

  @override
  String get donateReachingThePaymentService =>
      'Connexion au service de paiement par tor…';

  @override
  String get donateThisCanTakeUp => 'Cela peut prendre jusqu’à une minute';

  @override
  String donateSThisCanTake(Object waited) {
    return '$waited s · cela peut prendre jusqu’à une minute';
  }

  @override
  String get donateUseTheAddressInstead => 'Utiliser plutôt l’adresse';

  @override
  String get donateThePaymentServiceIs =>
      'Le service de paiement est un service onion, et seul le mode Onion peut l’atteindre. Rien n’a été envoyé.';

  @override
  String get donateTorWasSlowTo =>
      'Tor a mis trop de temps à joindre le service de paiement. Vous pouvez donner à l’adresse ci-dessous - votre badge ne se débloquera simplement pas tout seul. Réessayez plus tard pour le badge.';

  @override
  String get donateThePaymentServiceIsHavingTrouble =>
      'Le service de paiement a des soucis en ce moment. Vous pouvez quand même donner à l’adresse ci-dessous - votre badge ne se débloquera simplement pas tout seul. Réessayez plus tard pour le badge.';

  @override
  String get commonTryAgain => 'Réessayer';

  @override
  String donateBtc(Object btc) {
    return '$btc BTC';
  }

  @override
  String donateSendExactlyThisAmount(Object fmtLeft) {
    return 'Envoyez exactement ce montant · expire dans $fmtLeft';
  }

  @override
  String get donateOpenWallet => 'Ouvrir le portefeuille';

  @override
  String get donateThisScreenUpdatesItself =>
      'Cet écran se met à jour dès que votre paiement est vu.\nGardez-le ouvert - rien n’est stocké, rien ne vous identifie.';

  @override
  String get donateWatchingTheChainFor =>
      'On guette votre paiement sur la chaîne';

  @override
  String get donateThisInvoiceExpired => 'Cette facture a expiré';

  @override
  String get donateInvoicesTimeOutIf =>
      'Les factures expirent. Si vous avez déjà envoyé le paiement, gardez cet écran ouvert : nous redemandons au service chaque minute pendant un moment, puis la prochaine fois que vous ouvrez Soutenir. Créez-en une nouvelle quand vous voulez.';

  @override
  String get donateNewInvoice => 'Nouvelle facture';

  @override
  String get donateIPaidCheckAgain => 'J’ai payé, revérifier';

  @override
  String get donatePaymentConfirmed => 'Paiement confirmé';

  @override
  String get donateThankYouForKeeping => 'Merci de garder Kryfo indépendant.';

  @override
  String donateVerifiedOnChainYou(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter':
          'Vérifié sur la chaîne - vous voilà parmi les soutiens. Personne ne peut vous l’enlever.',
      'patron':
          'Vérifié sur la chaîne - vous voilà parmi les mécènes. Personne ne peut vous l’enlever.',
      'guardian':
          'Vérifié sur la chaîne - vous voilà parmi les gardiens. Personne ne peut vous l’enlever.',
      'other':
          'Vérifié sur la chaîne - vous voilà parmi les soutiens. Personne ne peut vous l’enlever.',
    });
    return '$_temp0';
  }

  @override
  String get donateWearMyBadge => 'Porter mon badge';

  @override
  String get donateJustGladToHelp => 'Aider me suffit';

  @override
  String get gettingMessagesGettingMessages => 'Réception des messages';

  @override
  String get gettingMessagesHowNewMessagesReach =>
      'Comment les nouveaux messages arrivent sur ce téléphone. Vous pouvez changer quand vous voulez.';

  @override
  String get gettingMessagesAlwaysOn => 'Toujours actif';

  @override
  String get gettingMessagesMostPrivate => 'Le plus privé';

  @override
  String get gettingMessagesMessagesArriveInstantlyNothing =>
      'Les messages arrivent tout de suite. Rien ne sort de Tor. Consomme le plus de batterie.';

  @override
  String get gettingMessagesCheckIns => 'Relevés';

  @override
  String get gettingMessagesLightest => 'Le plus léger';

  @override
  String get gettingMessagesKryfoLooksForMessages =>
      'Kryfo cherche les messages toutes les 15 minutes. Économe en batterie, mais les messages peuvent arriver en retard.';

  @override
  String get gettingMessagesOnTheLockScreen => 'Sur l’écran de verrouillage';

  @override
  String get gettingMessagesHideMessagePreview =>
      'Masquer l’aperçu des messages';

  @override
  String get gettingMessagesAGenericAlertWith =>
      'Une alerte neutre, sans expéditeur ni texte du message';

  @override
  String get gettingMessagesShowsMessageTextIn =>
      'Affiche le texte des messages dans les notifications, même quand Kryfo est verrouillé.';

  @override
  String get gettingMessagesWhenThePhoneSits =>
      'Quand le téléphone ne bouge pas, Android espace les relevés. La ligne au-dessus montre le vrai dernier relevé. Tant que Kryfo est ouvert, il reste connecté.';

  @override
  String get groupChatJumpToTheNewest => 'Aller au plus récent';

  @override
  String get groupChatBlockedEverywhere => 'Bloqué partout';

  @override
  String get groupChatYou => 'Vous';

  @override
  String get groupChatVoiceMessage => 'Message vocal';

  @override
  String get groupChatQuotedPhoto => 'Photo';

  @override
  String get groupChatMessageUnavailable => 'Message indisponible';

  @override
  String get groupChatTorIsNotUp =>
      'Tor n’est pas encore prêt · envoi sans aperçu';

  @override
  String get groupChatCouldnTReachIt =>
      'Impossible de l’atteindre · envoi sans aperçu';

  @override
  String get groupChatNoTitleCameBack => 'Aucun titre reçu · envoi sans aperçu';

  @override
  String get groupChatCouldnTFetchIt =>
      'Impossible de le récupérer · envoi sans aperçu';

  @override
  String get groupChatCamera => 'Caméra';

  @override
  String get groupChatGallery => 'Galerie';

  @override
  String get groupChatVideo => 'Vidéo';

  @override
  String get groupChatGifFromPhone => 'Gif du téléphone';

  @override
  String get groupChatFile => 'Fichier';

  @override
  String get groupChatCouldNotReadThat => 'Impossible de lire ce fichier';

  @override
  String get groupChatGifTooBig8 => 'Gif trop gros · 8 Mo max';

  @override
  String get groupChatCouldNotCleanThat => 'Impossible de nettoyer ce gif';

  @override
  String get groupChatFileTooBig8 => 'Fichier trop gros · 8 Mo max';

  @override
  String get groupChatCouldNotCleanThatVideo =>
      'Impossible de nettoyer cette vidéo';

  @override
  String get groupChatCouldNotCleanThatPictureSend =>
      'Impossible de nettoyer cette image · envoyez-la comme photo';

  @override
  String get groupChat30Seconds => '30 secondes';

  @override
  String get groupChat1Minute => '1 minute';

  @override
  String get groupChat5Minutes => '5 minutes';

  @override
  String get groupChat1Hour => '1 heure';

  @override
  String get groupChat24Hours => '24 heures';

  @override
  String get groupChatBurnTimer => 'Messages éphémères';

  @override
  String get groupChatNewMessagesDisappearAfter =>
      'Les nouveaux messages disparaissent après ce délai';

  @override
  String get groupChatToday => 'Aujourd’hui';

  @override
  String get groupChatYesterday => 'Hier';

  @override
  String get groupChatYou2 => 'Vous';

  @override
  String groupChatThisChatHasPins(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Cette discussion a déjà $countString messages épinglés',
      one: 'Cette discussion a déjà $countString message épinglé',
    );
    return '$_temp0';
  }

  @override
  String get groupChatUnpinThisMessage => 'Désépingler ce message ?';

  @override
  String get groupChatPinThisMessage => 'Épingler ce message ?';

  @override
  String get groupChatItLeavesThePinned =>
      'Il quitte la liste des messages épinglés, pour tout le monde ici.';

  @override
  String get groupChatItGoesUnderThe =>
      'Il rejoint les messages épinglés en haut de la discussion, pour tout le monde ici.';

  @override
  String get groupChatUnpin => 'Désépingler';

  @override
  String get groupChatPinIt => 'Épingler';

  @override
  String get groupChatNotNow => 'Pas maintenant';

  @override
  String get groupChatSaved => 'Enregistré';

  @override
  String get groupChatRemovedFromSaved => 'Retiré des enregistrés';

  @override
  String get groupChatForwardTo => 'Transférer à';

  @override
  String get groupChatNoContactsToForward => 'Aucun contact à qui transférer';

  @override
  String get groupChatEditMessage => 'Modifier le message';

  @override
  String get groupChatUnsendMessage => 'Annuler l’envoi du message';

  @override
  String get groupChatItDisappearsWithNo =>
      'Il disparaît sans laisser de trace. C’est irréversible.';

  @override
  String get groupChatUnsend => 'Annuler l’envoi';

  @override
  String groupChatThisRoomAndEverything(Object expiryWords) {
    return 'Ce salon et tout ce qu’il contient disparaîtront dans $expiryWords';
  }

  @override
  String groupChatGhostModeOnBurns(Object fmtBurn) {
    return 'Messages éphémères · disparaissent après $fmtBurn';
  }

  @override
  String get groupChatGroupCreatedSayHi => 'Groupe créé. Dites bonjour.';

  @override
  String get groupChatNoMessagesYet => 'Pas encore de messages.';

  @override
  String get groupChatThisMessageCanT => 'Ce message ne peut pas être affiché';

  @override
  String groupChatS(Object s) {
    return '$s s';
  }

  @override
  String groupChatM(Object s) {
    return '$s min';
  }

  @override
  String groupChatH(Object s) {
    return '$s h';
  }

  @override
  String groupChatD(Object s) {
    return '$s j';
  }

  @override
  String groupChatHere(int count, Object time) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$time · $countString ici',
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
      other: '$countString membres',
      one: '$countString membre',
    );
    return '$_temp0';
  }

  @override
  String get groupChatSearchThisChat => 'Rechercher';

  @override
  String groupChatReplyingTo(Object name) {
    return 'Réponse à $name';
  }

  @override
  String get groupChatReplyingToYou => 'Réponse à votre message';

  @override
  String get groupChatTimedMessages => 'Messages éphémères';

  @override
  String get groupChatOpenTheCamera => 'Ouvrir la caméra';

  @override
  String get groupChatAttachAPhoto => 'Joindre une photo';

  @override
  String get groupChatMessage => 'Message';

  @override
  String get groupChatDisguiseVoice => 'Déguiser la voix';

  @override
  String get groupChatSupporter => 'Soutien';

  @override
  String get groupChatEdited => 'Modifié';

  @override
  String get groupChatTapToRetry => '! Réessayer';

  @override
  String get groupChat0s => '0 s';

  @override
  String get groupChatReply => 'Répondre';

  @override
  String get groupChatPin => 'Épingler';

  @override
  String get groupChatUnsave => 'Retirer';

  @override
  String get groupChatForward => 'Transférer';

  @override
  String get groupInfoGroup => 'Groupe';

  @override
  String get groupInfoRenameGroup => 'Renommer le groupe';

  @override
  String get groupInfoRename => 'Renommer';

  @override
  String get groupInfoNoContactsToAdd => 'Aucun contact à ajouter';

  @override
  String get groupInfoCouldNotAdd => 'Ajout impossible';

  @override
  String groupInfoRemove(Object haloId) {
    return 'Retirer $haloId ?';
  }

  @override
  String get groupInfoTheyWillStopReceiving =>
      'Cette personne ne recevra plus les messages de ce groupe.';

  @override
  String get commonRemove => 'Retirer';

  @override
  String get groupInfoClearThisConversation => 'Vider cette discussion ?';

  @override
  String get groupInfoEveryMessageHereIs =>
      'Chaque message ici est effacé de ce téléphone. Cela ne vide que votre copie, les autres membres gardent la leur.';

  @override
  String get groupInfoClear => 'Vider';

  @override
  String get groupInfoConversationCleared => 'Discussion vidée';

  @override
  String get groupInfoLeaveRoom => 'Quitter le salon ?';

  @override
  String get groupInfoLeaveGroup => 'Quitter le groupe ?';

  @override
  String get groupInfoEverythingInItIs =>
      'Tout ce qu’il contient est effacé de ce téléphone maintenant, et la clé que vous utilisiez ici disparaît pour de bon.';

  @override
  String get groupInfoYouWillStopReceiving =>
      'Vous ne recevrez plus les messages et les autres membres vous verront partir.';

  @override
  String get groupInfoLeave => 'Quitter';

  @override
  String get groupInfoGroupInfo => 'Infos du groupe';

  @override
  String groupInfo1Member(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString membres',
      one: '$countString membre',
    );
    return '$_temp0';
  }

  @override
  String get groupInfoAdmin => 'Admin';

  @override
  String get groupInfoMembers2 => 'Membres';

  @override
  String get groupInfoInvite => 'Inviter';

  @override
  String get commonAdd => 'Ajouter';

  @override
  String get groupInfoYou => 'Vous';

  @override
  String get groupInfoRemoveFromGroup => 'Retirer du groupe';

  @override
  String get groupInfoWallpaper => 'Fond d’écran';

  @override
  String get groupInfoSharedMedia => 'Médias partagés';

  @override
  String get groupInfoClearConversation => 'Vider la discussion';

  @override
  String get groupInfoLeaveRoom2 => 'Quitter le salon';

  @override
  String get groupInfoLeaveGroup2 => 'Quitter le groupe';

  @override
  String get groupInfoAddMembers => 'Ajouter des membres';

  @override
  String groupInfoAdd(Object pickedLength) {
    return 'Ajouter $pickedLength';
  }

  @override
  String handleYouAre(Object h) {
    return 'Vous êtes @$h';
  }

  @override
  String get handleHandleDeletedThePage =>
      'Pseudo supprimé · la page n’existe plus';

  @override
  String get handlePublicHandle => 'Pseudo public';

  @override
  String get handleOptionalYourThreeWords =>
      'Facultatif. Vos trois mots marchent dans tous les cas.';

  @override
  String get handleWren => 'merle';

  @override
  String get handleALineAboutYou => 'Une ligne sur vous · facultatif';

  @override
  String get handleClaiming => 'Réservation…';

  @override
  String get handleClaimThisHandle => 'Réserver ce pseudo';

  @override
  String get handleAnyoneWithThisLink =>
      'Quiconque a ce lien peut ouvrir une discussion privée avec vous. Il contient votre invitation et rien d’autre.';

  @override
  String get handleLinkCopied => 'Lien copié';

  @override
  String get handleDeleteThisHandle => 'Supprimer ce pseudo';

  @override
  String get handleChecking => 'Vérification…';

  @override
  String get handleAvailable => '✓ Disponible';

  @override
  String get handleAlreadyTaken => 'Déjà pris';

  @override
  String get handleNameRule => '3 à 20 caractères : a-z, 0-9 ou _';

  @override
  String get handleWhatAHandleDoes => 'À quoi sert un pseudo';

  @override
  String get handleAnyoneWhoKnowsIt =>
      'Quiconque le connaît peut demander à vous écrire, c’est tout l’intérêt d’en avoir un. La page contient votre invitation et la ligne que vous avez écrite, rien d’autre, et ne garde aucune trace de qui la lit. Vous pouvez le supprimer quand vous voulez.';

  @override
  String handleIsNotYoursOn(Object handle) {
    return '@$handle n’est pas à vous sur ce téléphone';
  }

  @override
  String handleTheRegistryHoldsIt(Object handle) {
    return 'Le registre le détient sous une autre clé, très probablement une identité que ce téléphone avait avant une restauration. Les gens qui ajoutent @$handle ne vous joignent pas. Il ne peut être ni libéré ni mis à jour d’ici. Choisissez un autre nom.';
  }

  @override
  String get handleForgetItOnThis => 'L’oublier sur ce téléphone';

  @override
  String get homeAddAContact => 'Ajouter un contact';

  @override
  String get commonSettings => 'Paramètres';

  @override
  String get homeYourKryfo => 'Votre Kryfo';

  @override
  String homeDateWeekday(Object weekday) {
    return '$weekday,';
  }

  @override
  String get homeAnHour => 'une heure';

  @override
  String homeHours(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString heures',
      one: '$countString heure',
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
      other: '$countString minutes',
      one: '$countString minute',
    );
    return '$_temp0';
  }

  @override
  String get homeKryfoIsOffline => 'Kryfo est hors ligne';

  @override
  String homeTorHasNotBeen(Object howLong) {
    return 'Tor n’arrive pas à se connecter depuis $howLong. Rien ne peut arriver ni partir tant que ce n’est pas fait.';
  }

  @override
  String get homeReconnecting => 'Reconnexion';

  @override
  String get homeReconnect => 'Reconnecter';

  @override
  String get homeWhatIsWrong => 'Ce qui ne va pas';

  @override
  String get homeKryfoWillCheckIn =>
      'Kryfo fera un relevé toutes les 15 minutes';

  @override
  String get homeYourPhoneKeepsStopping =>
      'Votre téléphone arrête sans cesse Kryfo';

  @override
  String get homeItHasClosedKryfo =>
      'Il a fermé Kryfo trois fois aujourd’hui, donc des messages sont arrivés en retard ou ont attendu. Les relevés résistent à ça : Kryfo se réveille toutes les 15 minutes au lieu de rester connecté.';

  @override
  String get homeSwitchToCheckIns => 'Passer aux relevés';

  @override
  String get homeNotNow => 'Pas maintenant';

  @override
  String get homeNotificationsAreOff => 'Notifications désactivées';

  @override
  String get homeAndroidIsBlockingThem =>
      'Android les bloque, donc rien ne vous parvient quand Kryfo est fermé. Les messages arrivent quand même à l’ouverture.';

  @override
  String get homeCouldnTOpenIt =>
      'Impossible de l’ouvrir. Cherchez Kryfo dans les paramètres du téléphone';

  @override
  String get homeTurnThemOn => 'Les activer';

  @override
  String get homeLeaveThemOff => 'Laisser ainsi';

  @override
  String get homeOurRelayIsQuiet => 'Notre relais est muet';

  @override
  String get homeRelayModeUsesOnly =>
      'Le mode Relais n’utilise que notre propre relais, et il ne répond pas en ce moment. Le mode Rapide ajoute des relais publics à côté, donc les messages arrivent quand même. Tout reste scellé dans les deux cas.';

  @override
  String get homeSwitchedToFast => 'Mode Rapide activé';

  @override
  String get homeUseFastMode => 'Passer en Rapide';

  @override
  String get homeKeepWaiting => 'Attendre encore';

  @override
  String get homeNotConnecting => 'Pas de connexion';

  @override
  String get homeBridgesAreOnAnd =>
      'Les ponts sont activés et tor ne passe toujours pas. Les ponts sont plus lents, et certains tombent sans prévenir. Si votre réseau ne bloque pas tor, une connexion directe est plus rapide et plus fiable.';

  @override
  String get homeGoingDirectReconnecting => 'Connexion directe · reconnexion';

  @override
  String get homeTurnBridgesOff => 'Désactiver les ponts';

  @override
  String get homeStillTrying => 'On essaie encore';

  @override
  String get homeTorIsNotGetting =>
      'Tor ne passe pas. Certains réseaux le bloquent exprès. Notre propre relais est une simple connexion et marche en général quand même - ou les ponts, plus longs à mettre en place.';

  @override
  String get homeSwitchedToRelay => 'Mode Relais activé';

  @override
  String get homeUseOurRelay => 'Utiliser notre relais';

  @override
  String get homeBridges => 'Ponts';

  @override
  String get homeOffline => 'Hors ligne';

  @override
  String get homeWaiting => 'En attente';

  @override
  String get homeNothingWaitingToSend => 'Rien en attente d’envoi';

  @override
  String homeWaitingSendsWhenYou(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString en attente · envoi dès votre retour',
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
      other: '$countString en attente · tor se connecte encore',
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
      other: '$countString en attente · jusqu’à ce qu’on vous ajoute en retour',
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
          '$countString en attente · $parkedString jusqu’à ce qu’on vous ajoute en retour',
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
      other: '$countString en attente · envoi en cours',
    );
    return '$_temp0';
  }

  @override
  String get commonRetry => 'Réessayer';

  @override
  String get homeNoKryfosYet => 'Pas encore de Kryfos.';

  @override
  String get homeScanTheirCodeSend =>
      'Scannez son code, envoyez-lui un lien, ou tapez le @pseudo qu’on vous a donné.';

  @override
  String get homeAddSomeone => 'Ajouter quelqu’un';

  @override
  String get homeArchived => 'Archivées';

  @override
  String home1Chat(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString discussions',
      one: '$countString discussion',
    );
    return '$_temp0';
  }

  @override
  String get homeGroups => 'Groupes';

  @override
  String get homeRoom => 'Salon';

  @override
  String get homeNew => 'Nouveau';

  @override
  String homeRoomExpired(Object expiredRoomName) {
    return '$expiredRoomName · salon expiré';
  }

  @override
  String get homeMentionedYou => 'Vous a mentionné';

  @override
  String homeMembers(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString membres',
      one: '$countString membre',
    );
    return '$_temp0';
  }

  @override
  String get homeSupporter => 'Soutien';

  @override
  String get homeArchivedChats => 'Discussions archivées';

  @override
  String get homeUnmute => 'Remettre le son';

  @override
  String get homeMute => 'Couper le son';

  @override
  String get homeArchive => 'Archiver';

  @override
  String get homeDeleteChat => 'Supprimer la discussion';

  @override
  String get homeMessagesAndContactGone =>
      'Messages et contact, supprimés de ce téléphone';

  @override
  String get homeDeleteThisChat => 'Supprimer cette discussion ?';

  @override
  String homeEveryMessageWithGoes(Object c) {
    return 'Tous les messages avec $c disparaissent, et cette personne n’est plus un contact. Cela ne vide que ce téléphone - sa copie reste chez elle. Si elle vous écrit à nouveau, ça arrive dans les demandes.';
  }

  @override
  String get homeQueued => 'En file';

  @override
  String get homeBlocked => 'Bloqué';

  @override
  String get homeRoomInvite => 'Invitation à un salon';

  @override
  String get homeNow => 'À l’instant';

  @override
  String homeM(Object inMinutes) {
    return '$inMinutes min';
  }

  @override
  String homeH(Object inHours) {
    return '$inHours h';
  }

  @override
  String get homeYesterday => 'Hier';

  @override
  String homeD(Object inDays) {
    return '$inDays j';
  }

  @override
  String get homeNoteToSelf => 'Note pour moi';

  @override
  String get homeOnlyOnThisPhone => 'Seulement sur ce téléphone';

  @override
  String get homeSaved => 'Enregistrés';

  @override
  String get homeKeptFromEveryChat => 'Gardés de chaque discussion';

  @override
  String get homeRequests => 'Demandes';

  @override
  String home1PersonWantsTo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString personnes veulent vous joindre',
      one: '$countString personne veut vous joindre',
    );
    return '$_temp0';
  }

  @override
  String introduceGotItButCould(Object b, Object c) {
    return '$b l’a reçue, mais impossible de joindre $c';
  }

  @override
  String introduceGotItButCouldNotBe(Object c, Object b) {
    return '$c l’a reçue, mais impossible de joindre $b';
  }

  @override
  String get introduceCouldNotReachEither =>
      'Ni l’un ni l’autre n’a pu être joint. Réessayez plus tard';

  @override
  String introduceIntroduceTo(Object peerName) {
    return 'Présenter $peerName à...';
  }

  @override
  String get introduceBothOfThemGet =>
      'Chacun reçoit la carte de l’autre. Aucun ne voit le surnom que vous donnez à l’autre.';

  @override
  String get introduceNoOneElseTo =>
      'Personne d’autre à présenter pour l’instant. Ajoutez d’abord un autre contact.';

  @override
  String get introduceANoteLikeMy =>
      'Un mot, comme « ma cousine » - facultatif';

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
      other: 'Encore $leftString sur $maxString présentations cette semaine',
      one: 'Encore $leftString sur $maxString présentation cette semaine',
    );
    return '$_temp0';
  }

  @override
  String introduceNoIntroductionsLeftNext(Object refillPhrase) {
    return 'Plus de présentations. La prochaine se libère $refillPhrase';
  }

  @override
  String get introduceIntroduce => 'Présenter';

  @override
  String get keyVerificationSafetyNumber => 'Numéro de sécurité';

  @override
  String keyVerificationWith(Object peerName) {
    return 'Avec $peerName';
  }

  @override
  String keyVerificationIfSeesTheSame(Object peerName) {
    return 'Si $peerName voit le même numéro, vos messages restent privés, rien qu’entre vous deux. Comparer en personne ou lors d’un appel de confiance est le moyen le plus sûr de s’en assurer - mais c’est facultatif, jamais obligatoire pour discuter.';
  }

  @override
  String get keyVerificationVerified => 'Vérifié';

  @override
  String get keyVerificationMarkAsVerified => 'Marquer comme vérifié';

  @override
  String get lockFileThatPasswordDoesNot => 'Ce mot de passe ne l’ouvre pas.';

  @override
  String get lockFileThisFileIsDamaged => 'Ce fichier est endommagé.';

  @override
  String get lockFileThisFileWasLocked =>
      'Ce fichier a été verrouillé avec une clé, pas un mot de passe.';

  @override
  String get lockFileThisIsNotA => 'Ce n’est pas un fichier verrouillé.';

  @override
  String get lockFileNotEnoughFreeMemory =>
      'Pas assez de mémoire libre en ce moment.';

  @override
  String get lockFileStopped => 'Arrêté.';

  @override
  String get lockFileItNeedsAPassword => 'Il faut un mot de passe.';

  @override
  String get lockFileKryfoCouldNotRead =>
      'Kryfo n’a pas pu lire ou écrire le fichier.';

  @override
  String get lockFileCheckCapitalsAndSpaces =>
      'Vérifiez les majuscules et les espaces. Personne ne peut le réinitialiser, nous compris.';

  @override
  String get lockFileItMayHaveBeen =>
      'Il a peut-être été tronqué en route. Demandez qu’on vous le renvoie. Rien n’a été enregistré.';

  @override
  String get lockFileItOpensWithThe =>
      'Il s’ouvre avec le fichier de clé de la personne à qui il est destiné, dans l’outil age sur un ordinateur. Kryfo ouvre ceux à mot de passe.';

  @override
  String get lockFileKryfoOpensFilesLocked =>
      'Kryfo ouvre les fichiers verrouillés avec age. Leur nom finit en général par .age.';

  @override
  String get lockFileCloseAFewApps =>
      'Fermez quelques applis et réessayez. La vérification du mot de passe a besoin de quelques centaines de mégaoctets pendant un instant.';

  @override
  String get lockFileNothingWasSaved => 'Rien n’a été enregistré.';

  @override
  String get lockFileTypeOneOrLet =>
      'Tapez-en un, ou laissez Kryfo proposer quatre mots.';

  @override
  String get lockFileTheAppThatHolds =>
      'L’appli qui le contient l’a peut-être repris. Choisissez-le à nouveau.';

  @override
  String get lockFileHidePassword => 'Masquer le mot de passe';

  @override
  String get lockFileShowPassword => 'Afficher le mot de passe';

  @override
  String get lockFileChangeFile => 'Changer de fichier';

  @override
  String get lockFileChange => 'Changer';

  @override
  String lockFileOf(Object prettySize, Object prettySize2) {
    return '$prettySize sur $prettySize2';
  }

  @override
  String get lockFileEverythingStaysOnThis => 'Tout reste sur ce téléphone.';

  @override
  String get lockFileCouldNotMakeOne =>
      'Impossible d’en créer un. Tapez le vôtre.';

  @override
  String get lockFileWriteItDownBefore =>
      'Notez-le avant de verrouiller le fichier';

  @override
  String get lockFileNoAppOnThis =>
      'Aucune appli de ce téléphone n’a pris le fichier.';

  @override
  String get lockFileSaved => 'Enregistré';

  @override
  String get lockFileCouldNotSaveIt =>
      'Impossible de l’enregistrer là. Essayez un autre dossier.';

  @override
  String get lockFileLocked => 'Verrouillé';

  @override
  String get lockFileLockAFile => 'Verrouiller un fichier';

  @override
  String get lockFileMixingThePassword => 'Brassage du mot de passe';

  @override
  String get lockFileLocking => 'Verrouillage';

  @override
  String get lockFileSaveToFiles => 'Enregistrer';

  @override
  String get lockFileLockFile => 'Verrouiller';

  @override
  String get lockFileOnePassword => 'Un mot de passe.';

  @override
  String get lockFileNothingElseOpensIt => 'Rien d’autre ne l’ouvre.';

  @override
  String get lockFileFile => 'Fichier';

  @override
  String lockFileFromFiles(Object prettySize) {
    return '$prettySize · depuis Fichiers';
  }

  @override
  String get lockFileFromFiles2 => 'Depuis Fichiers';

  @override
  String get lockFilePassword => 'Mot de passe';

  @override
  String get lockFileSuggestFourWords => 'Proposer quatre mots';

  @override
  String get lockFileTypeItAgain => 'Retapez-le';

  @override
  String get lockFileTheTwoDoNot => 'Les deux ne correspondent pas encore.';

  @override
  String get lockFileHideTheFileName => 'Masquer le nom du fichier';

  @override
  String lockFileItWillBeCalled(Object name) {
    return 'Il s’appellera « $name ». Dites à la personne quel type de fichier c’est.';
  }

  @override
  String get lockFileTheNameAloneCan =>
      'Le nom seul peut dire ce qu’il contient.';

  @override
  String get lockFileAnyoneWithThePassword =>
      'Quiconque a le mot de passe peut l’ouvrir, dans Kryfo ou sur n’importe quel ordinateur avec l’outil gratuit age. Oubliez-le, et le fichier est perdu pour de bon. Personne ne peut le réinitialiser, nous compris.';

  @override
  String get lockFileLocked2 => 'Verrouillé.';

  @override
  String get lockFileOnlyThePasswordOpens => 'Seul le mot de passe l’ouvre.';

  @override
  String lockFileSafeToEmailOr(Object prettySize) {
    return '$prettySize · sans risque par e-mail ou sur une clé USB';
  }

  @override
  String get lockFileNoKryfoOnThe =>
      'Pas de Kryfo de l’autre côté ? Sur un ordinateur :';

  @override
  String get lockFileItAsksForThe =>
      'Il demande le mot de passe. age est gratuit sur age-encryption.org';

  @override
  String lockTooManyTriesS(Object lockState) {
    return 'Trop d’essais · $lockState s';
  }

  @override
  String get lockNotIt => 'Pas le bon';

  @override
  String get lockYourPin => 'Votre code PIN';

  @override
  String get lockUseFingerprint => 'Utiliser l’empreinte';

  @override
  String get lockSetupUnlockWithFingerprint => 'Déverrouiller par empreinte ?';

  @override
  String get lockSetupThePinStillWorks =>
      'Le code PIN marche toujours, quand vous voulez. C’est juste plus rapide.';

  @override
  String get lockSetupUseFingerprint => 'Utiliser l’empreinte';

  @override
  String get lockSetupPinOnly => 'Code PIN seul';

  @override
  String get lockSetupOnceMore => 'Encore une fois';

  @override
  String get lockSetupSetAPin => 'Créer un code PIN';

  @override
  String get lockSetupThoseWereDifferentFrom =>
      'Les deux diffèrent. On recommence.';

  @override
  String get lockSetupTheSameFourDigits =>
      'Les mêmes chiffres, encore une fois';

  @override
  String get lockSetupFourDigitsAnythingYou =>
      'Quatre chiffres ou plus, dont vous vous souviendrez';

  @override
  String get modesOnion => 'Onion';

  @override
  String get modesFullOnionRoutingThree =>
      'Routage onion complet, trois sauts. Un message met deux à cinq secondes. Personne ne voit à qui vous parlez.';

  @override
  String get modesSlower => 'Plus lent';

  @override
  String get modesRelay => 'Relais';

  @override
  String get modesOneSealedConnectionTo =>
      'Une seule connexion scellée vers le relais de Kryfo, comme un vpn qui n’a rien à consigner. Les envois arrivent en une seconde environ, et ça marche là où tor est bloqué.';

  @override
  String get modesQuick => 'Rapide';

  @override
  String get modesRelayOnly => 'Relais seul';

  @override
  String get modesFast => 'Rapide';

  @override
  String get modesPlainConnectionsToEvery =>
      'Des connexions ordinaires vers chaque relais. Presque instantané, et le moins privé des trois.';

  @override
  String get modesInstant => 'Instantané';

  @override
  String get modesEveryRelayYouUse =>
      'Chaque relais que vous utilisez connaît l’adresse d’où vous vous connectez, pas seulement le nôtre. Les messages restent scellés, mais le fait que vous en ayez envoyé un ne l’est pas. Désactivé par défaut, et de nouveau désactivé après une réinstallation.';

  @override
  String get modesSpeed => 'Vitesse';

  @override
  String get modesPrivacy => '& confidentialité';

  @override
  String get modesChangeGloballyOrPer =>
      'Pour tout, ou discussion par discussion';

  @override
  String get modesSoon => 'Bientôt';

  @override
  String get modesActive => 'Actif';

  @override
  String get modesSpeed2 => 'VITESSE';

  @override
  String get modesHops => 'SAUTS';

  @override
  String get modesIp => 'IP';

  @override
  String get modesVisible => 'Visible';

  @override
  String get modesHidden => 'Masquée';

  @override
  String modesHeadsUp(Object warning) {
    return '*Attention :* $warning';
  }

  @override
  String get modesOnionIsTheDefault =>
      'Onion est le mode par défaut et le reste tant que vous ne le changez pas. Le changement s’applique au prochain message.';

  @override
  String get modesFastMode => 'Mode Rapide';

  @override
  String get modesPlainConnectionsToEveryRelayQuicker =>
      'Des connexions ordinaires vers chaque relais. Plus rapide, et les relais peuvent voir votre adresse IP. Les messages restent chiffrés de bout en bout dans tous les cas.';

  @override
  String get modesTurnOnFastMode => 'Activer le mode Rapide';

  @override
  String get modesKeepItOff => 'Laisser désactivé';

  @override
  String get movedWipeThisPhone => 'Effacer Kryfo de ce téléphone ?';

  @override
  String get movedEverythingKryfoHoldsHere =>
      'Tout ce que Kryfo garde ici disparaît : les messages, les contacts, les clés. L’autre appareil garde tout. C’est irréversible.';

  @override
  String get movedWipeIt => 'Effacer';

  @override
  String get movedNotMovingAfterAll => 'Finalement, vous ne partez pas ?';

  @override
  String get movedOnlyDoThisIf =>
      'Ne faites cela que si la sauvegarde n’a jamais été importée nulle part. Sinon, deux appareils ont maintenant une même identité, et des messages vont commencer à disparaître sur les deux.';

  @override
  String get movedIMStayingHere => 'Je reste ici';

  @override
  String get movedStayingHere => 'On reste ici';

  @override
  String movedKryfoWillCloseNow(Object myId) {
    return 'Kryfo va se fermer. Touchez l’icône pour le rouvrir en tant que $myId.';
  }

  @override
  String get movedReopenKryfo => 'Rouvrir Kryfo';

  @override
  String get movedThisKryfoHasMoved => 'Ce Kryfo a déménagé';

  @override
  String movedIsNowOnAnother(Object myId) {
    return '$myId est maintenant sur un autre appareil. Ce téléphone peut encore afficher ce qu’il y avait ici, mais plus rien de nouveau n’y arrivera, et rien de ce que vous enverrez d’ici n’atteindra personne.';
  }

  @override
  String get movedKeepItToRead => 'Le garder pour lire';

  @override
  String get movedWipeThisPhone2 => 'Effacer Kryfo de ce téléphone';

  @override
  String get movedIMNotMoving => 'Finalement, je ne pars pas';

  @override
  String get myKryfoAHandleIs3 =>
      'Un pseudo fait de 3 à 20 lettres, chiffres ou _';

  @override
  String get myKryfoInviteCopiedClearsIn =>
      'Invitation copiée · effacée dans 60 s';

  @override
  String myKryfoAddMeOnKryfo(Object myId, Object uri) {
    return 'Ajoutez-moi sur Kryfo. Mon ID Kryfo est $myId\n\nTouchez pour m’ajouter :\n$uri\n\nKryfo est une messagerie privée. Pas de numéro de téléphone, pas d’e-mail.';
  }

  @override
  String get myKryfoAddMeOnKryfo2 => 'Ajoutez-moi sur Kryfo';

  @override
  String get myKryfoAddSomeone => 'Ajouter quelqu’un';

  @override
  String get myKryfoKryfoDoesnTScan =>
      'Kryfo ne scanne pas vos contacts, c’est tout l’intérêt.';

  @override
  String get myKryfoIfThisLinkEnds =>
      'Si ce lien se retrouve là où vous ne vouliez pas, réinitialisez-le dans les paramètres. Tous ceux qui l’ont auront alors besoin d’un nouveau.';

  @override
  String get myKryfoAlreadyShareAFriend =>
      'Vous avez un contact en commun sur Kryfo ? Cette personne peut vous présenter l’un à l’autre depuis sa discussion, et vous évitez la demande.';

  @override
  String get myKryfoHandleCopied => 'Pseudo copié';

  @override
  String get myKryfoTheyReHereWith => 'On est ensemble';

  @override
  String get myKryfoPointYourPhonesAt =>
      'Pointez vos téléphones l’un vers l’autre. Rien ne passe par un serveur.';

  @override
  String get myKryfoScanTheirsInstead => 'Scanner plutôt le sien';

  @override
  String get myKryfoTheyReadYouA => 'On vous dicte un code';

  @override
  String get myKryfoTheyReSomewhereElse => 'On est à distance';

  @override
  String get myKryfoSendThemALink =>
      'Envoyez-lui un lien. Il ouvre directement l’ajout.';

  @override
  String get myKryfoYourLinkAppearsOnce =>
      'Votre lien apparaît dès que la connexion est établie';

  @override
  String get myKryfoTheLinkCarriesYour =>
      'Le lien contient votre ID, votre adresse et les clés pour démarrer une discussion. Il fonctionne jusqu’à ce que vous le réinitialisiez dans les paramètres.';

  @override
  String get myKryfoSendTheLink => 'Envoyer le lien';

  @override
  String get myKryfoAsACard => 'En carte';

  @override
  String get myKryfoAnImageWithThe => 'Une image avec le QR';

  @override
  String get myKryfoAsAFile => 'En fichier';

  @override
  String get myKryfoContactFile => 'Fichier de contact';

  @override
  String get myKryfoIKnowTheirHandle => 'Je connais son pseudo';

  @override
  String get myKryfoTypeTheNameThey =>
      'Tapez le @nom qu’on vous a donné. Marche si la personne en a réservé un.';

  @override
  String get myKryfoWren => 'Merle';

  @override
  String get myKryfoTheLookupAsksFor =>
      'La recherche n’envoie que ce nom, et rien sur vous. Votre premier message arrive quand même comme une demande.';

  @override
  String get myKryfoLooking => 'Recherche…';

  @override
  String get myKryfoFindThem => 'Trouver';

  @override
  String get myKryfoYourAddressAppearsOnce =>
      'Votre adresse apparaît dès que la connexion est établie';

  @override
  String get myKryfoAPublicHandle => 'Un pseudo public';

  @override
  String get myKryfoPutItInA =>
      'Mettez-le dans une bio. Quiconque le connaît peut vous trouver.';

  @override
  String get myKryfoANamePeopleCan =>
      'Un nom par lequel on peut vous trouver. Désactivé tant que vous n’en réservez pas un.';

  @override
  String get newGroupCouldNotCreate => 'Création impossible';

  @override
  String get newGroupNewGroup => 'Nouveau groupe';

  @override
  String get newGroupCreating => 'Création…';

  @override
  String get newGroupCreate => 'Créer';

  @override
  String get newGroupGroupName => 'Nom du groupe';

  @override
  String get newGroupMembers => 'Membres';

  @override
  String get newGroupPickAtLeastOne => 'Choisissez-en au moins un';

  @override
  String newGroupSelected(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString sélectionnés',
      one: '$countString sélectionné',
    );
    return '$_temp0';
  }

  @override
  String get newGroupAddAtLeastOne =>
      'Ajoutez d’abord au moins un contact avant de créer un groupe.';

  @override
  String get notesToday => 'AUJOURD’HUI';

  @override
  String get notesYesterday => 'HIER';

  @override
  String get notesNoteToSelf => 'Note pour moi';

  @override
  String get notesOnlyOnThisPhone => 'Seulement sur ce téléphone';

  @override
  String get notesAQuietPlace => 'Un coin tranquille';

  @override
  String get notesJotAnythingDownIt =>
      'Notez ce que vous voulez. Ça reste sur ce téléphone et n’en sort jamais.';

  @override
  String get notesJotSomethingDown => 'Notez quelque chose…';

  @override
  String get onboardingPrivateByDefault => 'PRIVÉ PAR DÉFAUT';

  @override
  String get onboardingPrivateMessaging =>
      'Une messagerie privée,\n*sans piège*.';

  @override
  String get onboardingYourNameIsThree =>
      '*Votre nom, c’est trois mots.* Pas de téléphone, pas d’e-mail, pas de carnet d’adresses.';

  @override
  String get onboardingNobodyGetsInUnless =>
      '*Personne n’entre sans votre accord.* Il n’y a pas de recherche. Les gens sont ajoutés à la main, dans les deux sens.';

  @override
  String get onboardingTheFirstConnectionTakes =>
      '*La première connexion prend une minute.* Kryfo construit une route privée avant d’envoyer. Rapide ensuite.';

  @override
  String get onboardingBegin => 'Commencer';

  @override
  String get onboardingHaveABackupRestore => 'Une sauvegarde ? Restaurer →';

  @override
  String get onboardingKryfoIsOpenSource => 'Kryfo est open source';

  @override
  String get onboardingYourKryfoId => 'VOTRE ID KRYFO';

  @override
  String get onboardingGeneratedFromAKey =>
      'Généré à partir d’une clé qui ne vit que sur ce téléphone. *Facile à retenir, unique, rien qu’à vous.* Personne d’autre ne l’a.';

  @override
  String get onboardingTryAnother => 'En essayer un autre';

  @override
  String get onboardingUseThisName => 'Prendre ce nom →';

  @override
  String get onboardingThreeWords => 'Trois mots. *Rien qu’à vous.*';

  @override
  String get onboardingPickA => 'Choisir un *visage*.';

  @override
  String get onboardingDrawnOnThisPhone =>
      'Dessiné sur ce téléphone à partir d’un nombre, jamais mis en ligne. Changez-le quand vous voulez.';

  @override
  String get onboardingThePeopleYouMessage =>
      'Les personnes à qui vous écrivez le voient aussi';

  @override
  String get onboardingKeepMyInitial => 'Garder mon initiale';

  @override
  String get onboardingThatOne => 'Celui-là →';

  @override
  String get onboardingContinue => 'Continuer →';

  @override
  String get onboardingHowYourMessages => 'Comment vos messages *voyagent*.';

  @override
  String get onboardingYouCanChangeThis =>
      'Vous pouvez changer ça à tout moment dans les paramètres, pour tout le monde ou pour une discussion.';

  @override
  String get onboardingOnion => 'Onion';

  @override
  String get onboardingSlowerAMessageTakes =>
      'Plus lent. Un message met deux à cinq secondes.';

  @override
  String get onboardingHidesYourAddressFrom =>
      'Cache votre adresse à tout le monde, notre relais compris.';

  @override
  String get onboardingRelay => 'Relais';

  @override
  String get onboardingOurRelaySeesYour =>
      'Notre relais voit votre adresse. Personne d’autre.';

  @override
  String get onboardingAboutASecondWorks =>
      'Environ une seconde. Marche là où tor est bloqué.';

  @override
  String get onboardingFast => 'Rapide';

  @override
  String get onboardingEveryRelayYouUse =>
      'Chaque relais que vous utilisez voit votre adresse. Le moins privé des trois.';

  @override
  String get onboardingNearInstant => 'Presque instantané.';

  @override
  String get onboardingKeepOnion => 'Garder Onion →';

  @override
  String get onboardingUseThis => 'Prendre celui-ci →';

  @override
  String get onboardingSkipOnionIsA =>
      'Passer · Onion est un bon choix par défaut';

  @override
  String get onboardingThreeThingsThen => 'Trois choses,\npuis *vous y êtes*.';

  @override
  String get onboardingEverythingElseTheApp =>
      'Pour le reste, l’appli vous le dira au bon moment.';

  @override
  String get onboardingYourNameIsThreeWords => 'Votre nom, c’est trois mots';

  @override
  String get onboardingThatIsTheWhole =>
      'C’est toute votre identité. Pas de numéro qui puisse fuiter, pas d’e-mail à hameçonner, rien à chercher. Les personnes avec qui vous parlez voient ces mots et le visage que vous avez choisi.';

  @override
  String get onboardingNobodyCanReachYou =>
      'Personne ne peut vous joindre tant que vous n’ouvrez pas la porte';

  @override
  String get onboardingAStrangerWithYour =>
      'Un inconnu qui a vos mots peut seulement frapper. Son premier message attend dans les demandes jusqu’à ce que vous disiez oui, et vous pouvez dire non sans qu’il le sache jamais.';

  @override
  String get onboardingTheFirstConnectionTakesAMinute =>
      'La première connexion prend une minute';

  @override
  String get onboardingKryfoBuildsAPrivateRouteBefore =>
      'Kryfo construit une route privée avant d’envoyer quoi que ce soit. Quand vous êtes hors ligne, les messages attendent et arrivent à votre retour.';

  @override
  String get onboardingYourIdentityLivesOn =>
      'Votre identité vit sur ce téléphone. Sauvegardez-la depuis les paramètres au moment qui vous convient.';

  @override
  String get onboardingIUnderstand => 'J’ai compris →';

  @override
  String get onboardingOneQuiet => 'Une *notification* discrète.';

  @override
  String get onboardingAndroidNeedsAVisible =>
      'Android exige une notification visible quand une appli écoute en arrière-plan. C’est ainsi que les messages vous parviennent quand Kryfo est fermé.';

  @override
  String get onboardingSilentAndAtThe => 'Silencieuse, et tout en bas du volet';

  @override
  String get onboardingItNeverBuzzesTurn =>
      'Elle ne vibre jamais. Désactivez-la, et les messages attendront que vous rouvriez l’appli.';

  @override
  String get onboardingGotIt => 'Compris →';

  @override
  String get onboardingNow => 'Enfin, *ajoutez quelqu’un*.';

  @override
  String get onboardingTheAppIsReady =>
      'L’appli est prête. Personne ne peut vous écrire tant que vous ne l’avez pas ajouté ou laissé entrer.';

  @override
  String get onboardingEveryWayToAdd => 'Toutes les façons d’ajouter quelqu’un';

  @override
  String get onboardingShowYourCodeSend =>
      'Montrez votre code, envoyez-lui un lien, ou tapez le @pseudo qu’on vous a donné.';

  @override
  String get onboardingScanTheirs => 'Scanner le sien';

  @override
  String get onboardingPointTheCameraAt => 'Pointez la caméra vers son code';

  @override
  String get onboardingTheAppIsReadyWhenYou =>
      'L’appli est prête quand vous l’êtes.';

  @override
  String get onboardingNotNowAddPeople =>
      'Pas maintenant · ajouter des gens plus tard';

  @override
  String get openLockedOpened => 'Ouvert';

  @override
  String get openLockedOpenALockedFile => 'Ouvrir un fichier verrouillé';

  @override
  String get openLockedCheckingThePassword => 'Vérification du mot de passe';

  @override
  String get openLockedOpening => 'Ouverture';

  @override
  String get openLockedFile => 'Fichier';

  @override
  String get openLockedOpenFile => 'Ouvrir le fichier';

  @override
  String get openLockedTypeThePassword => 'Tapez le mot de passe.';

  @override
  String get openLockedItOpensOnThis => 'Il s’ouvre sur ce téléphone.';

  @override
  String get openLockedLockedFile => 'Fichier verrouillé';

  @override
  String openLockedFromFiles(Object prettySize) {
    return '$prettySize · depuis Fichiers';
  }

  @override
  String get openLockedFromFiles2 => 'Depuis Fichiers';

  @override
  String get openLockedPassword => 'Mot de passe';

  @override
  String get openLockedThePasswordIsChecked =>
      'Le mot de passe est vérifié d’abord. Ensuite seulement, Kryfo demande où mettre le fichier ouvert, et il y va directement.';

  @override
  String get openLockedOpened2 => 'Ouvert.';

  @override
  String get openLockedSavedWhereYouChose => 'Enregistré à l’endroit choisi.';

  @override
  String get pairCodePairingCode => 'Code d’appairage';

  @override
  String get pairCodeShowACode => 'Afficher un code';

  @override
  String get pairCodeEnterOne => 'En saisir un';

  @override
  String get pairCodeSixDigits => 'Six chiffres';

  @override
  String get pairCodeLooking => 'Recherche…';

  @override
  String get pairCodeNothingThereYetTrying =>
      'Rien pour l’instant · nouvel essai';

  @override
  String get pairCodeNothingAtThatCode =>
      'Rien à ce code. Il a peut-être disparu, ou la personne ne l’a pas encore partagé.';

  @override
  String get pairCodeTypeTheSixDigits =>
      'Tapez les six chiffres qu’on vous a lus.';

  @override
  String get pairCodeAddThem => 'Ajouter';

  @override
  String get pairCodeUsedTwice =>
      'Ce code a été utilisé deux fois. Demandez-en un nouveau.';

  @override
  String get pairCodeIsThisThem => 'Est-ce bien cette personne ?';

  @override
  String get pairCodeCheckMatches => 'Vérifiez que cela correspond à son écran';

  @override
  String get pairCodeNotThem => 'Pas cette personne';

  @override
  String get pairCodeNotAdded =>
      'Rien n’a été ajouté. Demandez un nouveau code.';

  @override
  String get panicSetupThoseWereDifferentFrom =>
      'Les deux diffèrent. On recommence.';

  @override
  String get panicSetupOnceMore => 'Encore une fois';

  @override
  String get panicSetupTheSameFourDigits =>
      'Les mêmes chiffres, encore une fois';

  @override
  String get photoKnowsEverythingInside => 'Tout ce qu’il y a dedans';

  @override
  String get photoKnowsVideo => 'Vidéo';

  @override
  String get photoKnowsPhoto => 'Photo';

  @override
  String get photoKnowsWhatThisVideoKnows => 'Ce que sait cette vidéo';

  @override
  String get photoKnowsWhatThisPhotoKnows => 'Ce que sait cette photo';

  @override
  String get photoKnowsRemoveAllOfIt => 'Tout retirer';

  @override
  String get photoKnowsKeepItAsIt => 'La garder telle quelle';

  @override
  String get photoKnowsReadOnThisPhone =>
      'LU SUR CE TÉLÉPHONE · LA VIDÉO N’EST ALLÉE NULLE PART';

  @override
  String get photoKnowsReadOnThisPhoneThePhoto =>
      'LU SUR CE TÉLÉPHONE · LA PHOTO N’EST ALLÉE NULLE PART';

  @override
  String get photoKnowsReadingTheFile => 'Lecture du fichier';

  @override
  String photoKnowsOf(Object prettySize, Object prettySize2) {
    return '$prettySize sur $prettySize2';
  }

  @override
  String get photoKnowsEverythingStaysOnThis => 'Tout reste sur ce téléphone.';

  @override
  String photoKnowsMapWithAPin(Object place) {
    return 'Carte avec un repère. $place';
  }

  @override
  String get photoKnowsDrawnOffline => 'DESSINÉE HORS LIGNE';

  @override
  String photoKnowsShowEverything(Object title) {
    return '$title. Tout afficher';
  }

  @override
  String get pinsAppLock => 'Verrouillage';

  @override
  String get pinsYourPin => 'Votre code PIN';

  @override
  String get commonOn => 'Activé';

  @override
  String get commonOff => 'Désactivé';

  @override
  String get pinsOpensKryfoFourDigits =>
      'Ouvre Kryfo. Demandé quand il revient au premier plan.';

  @override
  String get pinsChangePin => 'Changer le code PIN';

  @override
  String get pinsSetAPin => 'Créer un code PIN';

  @override
  String get pinsTurnOff => 'Désactiver';

  @override
  String get pinsTurnOffTheApp => 'Désactiver le verrouillage ?';

  @override
  String get pinsThePinGoesAnd =>
      'Le code PIN disparaît, et avec lui le code d’effacement et toutes les discussions masquées. Quiconque tient votre téléphone ouvre Kryfo comme si c’était vous.';

  @override
  String get pinsUnlockWithFingerprint => 'Déverrouiller par empreinte';

  @override
  String get pinsWipePin => 'Code d’effacement';

  @override
  String get pinsNeedsAPinFirst => 'Code PIN requis';

  @override
  String get pinsSet => 'Défini';

  @override
  String get pinsChangeWipePin => 'Changer le code d’effacement';

  @override
  String get pinsSetAWipePin => 'Créer un code d’effacement';

  @override
  String get pinsRemove => 'Retirer';

  @override
  String get pinsRemoveTheWipePin => 'Retirer le code d’effacement ?';

  @override
  String get pinsTheLockScreenKeeps =>
      'L’écran de verrouillage garde votre code PIN. Le code d’effacement ne fait plus rien.';

  @override
  String profileCopied(Object what) {
    return 'Copié : $what';
  }

  @override
  String get profileProfile => 'Profil';

  @override
  String get profileChangeYourFace => 'Changer de visage';

  @override
  String get profileKryfoId => 'ID Kryfo';

  @override
  String get profileOnionAddress => 'Adresse onion';

  @override
  String get profileSupporterBadge => 'Badge de soutien';

  @override
  String profileYouAreAThank(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter': 'Vous faites partie des soutiens. Merci.',
      'patron': 'Vous faites partie des mécènes. Merci.',
      'guardian': 'Vous faites partie des gardiens. Merci.',
      'other': 'Vous faites partie des soutiens. Merci.',
    });
    return '$_temp0';
  }

  @override
  String get profileShowMyBadge => 'Afficher mon badge';

  @override
  String get profileOnMyOwnScreens => 'Sur mes propres écrans';

  @override
  String get profileLetContactsSeeIt => 'Le montrer à mes contacts';

  @override
  String get profileOffByDefault => 'Désactivé par défaut';

  @override
  String get profileShareConnect => 'Partage & connexion';

  @override
  String get profileMyKryfoCode => 'Mon code Kryfo';

  @override
  String get profileAddContact => 'Ajouter un contact';

  @override
  String get profileGiveAgain => 'Donner encore';

  @override
  String get profileSupportKryfo => 'Soutenir Kryfo';

  @override
  String get profileKryfoRunsOnWhat => 'Kryfo vit de ce que les gens donnent';

  @override
  String get profileKeepKryfoIndependent => 'Gardez Kryfo indépendant';

  @override
  String get qrLink => 'Lien';

  @override
  String get qrYourLinkAsTyped =>
      'VOTRE LIEN TEL QUE TAPÉ · AUCUNE REDIRECTION DE PISTAGE';

  @override
  String get qrText => 'Texte';

  @override
  String get qrStaysInTheCode =>
      'RESTE DANS LE CODE · AUCUN SERVEUR NE LE GARDE';

  @override
  String get qrWiFi => 'Wi-Fi';

  @override
  String get qrMadeOnThisPhone =>
      'CRÉÉ SUR CE TÉLÉPHONE · AUCUN SITE N’A VU LE MOT DE PASSE';

  @override
  String get qrNetworkName => 'Nom du réseau';

  @override
  String get qrPassword => 'Mot de passe';

  @override
  String get qrContact => 'Contact';

  @override
  String get qrOnlyWhatYouType =>
      'SEULEMENT CE QUE VOUS TAPEZ · RIEN DE VOS CONTACTS';

  @override
  String get qrName => 'Nom';

  @override
  String get qrPhone => 'Téléphone';

  @override
  String get qrEmail => 'E-mail';

  @override
  String get qrOpensTheirMailApp =>
      'OUVRE SON APPLI MAIL · RIEN N’EST ENVOYÉ D’ICI';

  @override
  String get qrTo => 'À';

  @override
  String get qrSubject => 'Objet';

  @override
  String get qrANumberNothingElse => 'UN NUMÉRO · RIEN D’AUTRE';

  @override
  String get qrNumber => 'Numéro';

  @override
  String get qrSms => 'SMS';

  @override
  String get qrOpensTheirMessagesApp =>
      'OUVRE SON APPLI MESSAGES · RIEN N’EST ENVOYÉ D’ICI';

  @override
  String get qrMessage => 'Message';

  @override
  String get qrLocation => 'Position';

  @override
  String get qrCoordinatesOnlyNoMap =>
      'COORDONNÉES SEULEMENT · AUCUN SERVICE DE CARTES INTERROGÉ';

  @override
  String get qrLatitude => 'Latitude';

  @override
  String get qrLongitude => 'Longitude';

  @override
  String get qrBitcoin => 'Bitcoin';

  @override
  String get qrAddressAndAmountNo =>
      'ADRESSE ET MONTANT · AUCUN SITE DE PAIEMENT ENTRE LES DEUX';

  @override
  String get qrAddress => 'Adresse';

  @override
  String get qrAmountInBtc => 'Montant en BTC';

  @override
  String get qrInk => 'Encre';

  @override
  String get qrAmber => 'Ambre';

  @override
  String get qrViolet => 'Violet';

  @override
  String get qrCouldNotDrawThe => 'Impossible de dessiner l’image.';

  @override
  String get qrSavedToYourGallery => 'Enregistré dans votre galerie';

  @override
  String get qrCouldNotSaveIt =>
      'Impossible de l’enregistrer. Vérifiez qu’il reste de la place sur le téléphone.';

  @override
  String get qrNoAppOnThis => 'Aucune appli de ce téléphone n’a pris l’image.';

  @override
  String get qrTooMuchForOne => 'Trop long pour un seul code. Raccourcissez.';

  @override
  String get qrThisIsALot =>
      'C’est beaucoup pour un seul code. Les appareils photo anciens risquent de ne pas le lire.';

  @override
  String get qrPrivateQrCode => 'Code QR privé';

  @override
  String get qrColour => 'Couleur';

  @override
  String get qrCopiedItLeavesThe =>
      'Copié. Il quitte le presse-papiers dans une minute';

  @override
  String get qrSecurity => 'Sécurité';

  @override
  String get qrNone => 'Aucune';

  @override
  String get qrSaveImage => 'Enregistrer';

  @override
  String qrColour2(Object name) {
    return 'Couleur $name';
  }

  @override
  String get qrTypeBelowAndThe =>
      'Tapez ci-dessous et le\ncode se dessine tout seul';

  @override
  String get qrQrCode => 'Code QR';

  @override
  String get qrHidePassword => 'Masquer le mot de passe';

  @override
  String get qrShowPassword => 'Afficher le mot de passe';

  @override
  String get qrCopyPassword => 'Copier le mot de passe';

  @override
  String get requestsSentAnAttachment => 'A envoyé une pièce jointe';

  @override
  String get requestsWantsToConnect => 'Veut entrer en contact';

  @override
  String get requestsAccepted => 'Acceptée';

  @override
  String requestsBlock(Object id) {
    return 'Bloquer $id ?';
  }

  @override
  String get requestsNothingMoreFromThem =>
      'Plus rien de cette personne ne vous parviendra. Sa demande et ses messages disparaissent.';

  @override
  String get requestsBlocked => 'Bloqué';

  @override
  String get requestsDeleted => 'Supprimé';

  @override
  String get requestsRequests => 'Demandes';

  @override
  String get requestsNoRequests => 'Aucune demande';

  @override
  String get requestsMessagesFromPeopleYou =>
      'Les messages de personnes que vous n’avez pas ajoutées arrivent d’abord ici.';

  @override
  String get requestsLooksSafeNothingSuspicious =>
      'Semble sûr · rien de suspect dans son premier message';

  @override
  String get commonAccept => 'Accepter';

  @override
  String get requestsDecline => 'Refuser';

  @override
  String get restoreThatFileIsNot =>
      'Ce fichier n’est pas une sauvegarde Kryfo';

  @override
  String get restoreThisFileIsDamaged =>
      'Ce fichier est endommagé et ne peut pas être lu';

  @override
  String get restoreTypeThePassphraseThe =>
      'Tapez la phrase secrète avec laquelle le fichier a été créé';

  @override
  String get restoreReplaceTheAccountOn =>
      'Remplacer le compte sur ce téléphone ?';

  @override
  String get restoreWhatIsHereNow =>
      'Ce qui est ici maintenant, son identité, ses contacts et ses messages, disparaît. Le fichier prend sa place. C’est irréversible.';

  @override
  String get restoreReplaceIt => 'Le remplacer';

  @override
  String restoreCouldNotBeReleased(Object mine) {
    return '@$mine n’a pas pu être libéré';
  }

  @override
  String restoreTheRegistryDidNot(Object mine) {
    return 'Le registre n’a pas répondu. Si vous continuez, @$mine restera lié à l’identité que ce téléphone s’apprête à perdre. Quiconque l’ajoute écrira à personne, et le nom ne pourra plus être réservé. Mieux vaut vous connecter et réessayer une fois.';
  }

  @override
  String get restoreRestoreAnyway => 'Restaurer quand même';

  @override
  String get restoreNotYet => 'Pas encore';

  @override
  String get restoreRestored => 'Restauré';

  @override
  String restoreKryfoWillCloseNow(Object haloId) {
    return 'Kryfo va se fermer. Touchez l’icône pour le rouvrir en tant que $haloId.';
  }

  @override
  String get restoreReopenKryfo => 'Rouvrir Kryfo';

  @override
  String get restoreTheRestoreDidNot =>
      'La restauration n’a pas abouti. Rien n’a été modifié';

  @override
  String get restoreThisIdentity => 'cette identité';

  @override
  String get restoreMoveYourKryfoHere => 'Transférer votre Kryfo ici';

  @override
  String restoreThisBackupIsRestoring(Object name) {
    return 'Cette sauvegarde contient $name. La restaurer déplace cette identité sur cet appareil.';
  }

  @override
  String restoreThisBackupMadeOn(Object name, Object date, Object time) {
    return 'Cette sauvegarde contient $name, et date du $date à $time. La restaurer déplace cette identité sur cet appareil.';
  }

  @override
  String restoreItHoldsOfPhotos(Object mb) {
    return 'Elle contient $mb de photos, notes vocales et fichiers. Cela peut prendre quelques minutes. Gardez l’appli ouverte.';
  }

  @override
  String get restoreWhatFollows => 'Ce qui suit';

  @override
  String get restoreYourNameYourCode =>
      'Votre nom, votre code, et chaque contact.';

  @override
  String get restoreEveryConversationBackTo =>
      'Chaque discussion, depuis le début.';

  @override
  String get restoreYourPhotosVoiceNotes =>
      'Vos photos, notes vocales et fichiers.';

  @override
  String restoreYourPhotosVoiceNotesCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Vos photos, notes vocales et fichiers · $countString.',
    );
    return '$_temp0';
  }

  @override
  String get restoreYourOnionAddressSo =>
      'Votre adresse onion, pour que ceux qui vous joignent directement continuent de vous joindre.';

  @override
  String get restoreAnythingSentToYou =>
      'Tout ce qu’on vous a envoyé pendant que l’ancien téléphone était éteint, jusqu’à quatorze jours après l’envoi.';

  @override
  String get restoreYourSupporterBadgeIf =>
      'Votre badge de soutien, si vous en avez un.';

  @override
  String get restoreWhatDoesnT => 'Ce qui ne suit pas';

  @override
  String get restoreTheOldPhoneStops =>
      'L’ancien téléphone cesse de recevoir dès que vous envoyez quoi que ce soit d’ici. Pas progressivement. Le premier message envoyé depuis cet appareil est le dernier que l’ancien téléphone peut suivre, et tout ce qui lui arrive ensuite y est illisible et ne vous attend pas ici non plus.';

  @override
  String get restoreIfThePhoneThis =>
      'Si le téléphone d’où vient ce fichier sert encore, arrêtez d’y utiliser Kryfo avant de continuer. Deux téléphones sur un même Kryfo perdent des messages des deux côtés.';

  @override
  String get restoreNotificationsNeedSettingUp =>
      'Les notifications doivent être reconfigurées sur cet appareil.';

  @override
  String get restoreMoveItHere => 'Transférer ici';

  @override
  String get restoreNotNow => 'Pas maintenant';

  @override
  String get restoreRestore => 'Restaurer';

  @override
  String get restoreFromABackupFile => 'Depuis une sauvegarde';

  @override
  String get restoreABackupBringsBack =>
      'Une sauvegarde ramène votre identité et vos contacts, ainsi que les messages présents sur le téléphone au moment de sa création. Ce qui s’est dit depuis n’y est pas.';

  @override
  String get restoreTheFile => 'Le fichier';

  @override
  String get restorePickTheBackupFile => 'Choisir le fichier de sauvegarde';

  @override
  String get restoreThePassphrase => 'La phrase secrète';

  @override
  String get restoreTheOneTheFile =>
      'Celle avec laquelle le fichier a été créé';

  @override
  String get restoreWhatComesBack => 'Ce qui revient';

  @override
  String get restoreChecking => 'Vérification…';

  @override
  String get restoreCheckTheFile => 'Vérifier le fichier';

  @override
  String get restoreReleasingYourHandle => 'Libération de votre pseudo…';

  @override
  String restoreMoving(Object progress) {
    return 'Transfert… $progress';
  }

  @override
  String get restoreRestoring => 'Restauration…';

  @override
  String get restoreNotThisOne => 'Pas celui-ci';

  @override
  String get restoreDateUnknown => 'Date inconnue';

  @override
  String get restoreAnIdentity => 'Une identité';

  @override
  String get restoreMessagesSentOrReceived =>
      'Les messages envoyés ou reçus après cette date ne sont pas dans ce fichier.';

  @override
  String restoreGb(Object bytes) {
    return '$bytes Go';
  }

  @override
  String restoreMb(Object bytes) {
    return '$bytes Mo';
  }

  @override
  String get roomCreateCouldNotCreateThe => 'Impossible de créer le salon';

  @override
  String get roomCreateBurnerRoom => 'Salon éphémère';

  @override
  String get roomCreateARoomThatEnds =>
      'Un salon qui prend fin. Chacun le rejoint avec une clé créée pour ce salon, et à la fin, il ne reste rien sur aucun téléphone.';

  @override
  String get roomCreateRoomName => 'Nom du salon';

  @override
  String get roomCreateEndsAfter => 'Se termine après';

  @override
  String get roomCreateMemberCap => 'Limite de membres';

  @override
  String roomCreateNoOnePastThe(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Personne au-delà de $countString membres',
      one: 'Personne au-delà de $countString membre',
    );
    return '$_temp0';
  }

  @override
  String get roomCreateOffAnyoneWithThe => 'Désactivée. Quiconque a le lien';

  @override
  String roomCreateThisRoomAndEverything(Object expiryWords) {
    return 'Ce salon et tout ce qu’il contient disparaîtront dans $expiryWords';
  }

  @override
  String get roomCreateCreating => 'Création...';

  @override
  String get roomCreateCreateRoom => 'Créer le salon';

  @override
  String get roomLinkSendTheRoomTo => 'Envoyer le salon à';

  @override
  String get roomLinkTheyWillKnowThis =>
      'La personne saura que ce salon vient de vous. À l’intérieur, elle n’est qu’une clé comme les autres.';

  @override
  String get roomLinkNoContactsYet => 'Pas encore de contacts';

  @override
  String roomLinkEndsIn(Object time) {
    return 'Se termine dans $time';
  }

  @override
  String get roomLinkAnyoneWithThisCan =>
      'Quiconque a ceci peut rejoindre jusqu’à la fin du salon. On y entre avec une clé créée pour ce salon, sans rien voir de ce qui a été envoyé avant son arrivée.';

  @override
  String get roomLinkRoomLinkCopied => 'Lien du salon copié';

  @override
  String get roomLinkSendToAContact => 'Envoyer à un contact';

  @override
  String get roomLinkCopyRoomLink => 'Copier le lien';

  @override
  String get savedVoiceNote => 'Note vocale';

  @override
  String get savedPhoto => 'Photo';

  @override
  String get savedSaved => 'Enregistrés';

  @override
  String get savedNothingSavedYet => 'Rien d’enregistré';

  @override
  String get savedLongPressAnyMessage =>
      'Appuyez longuement sur un message et touchez enregistrer pour le garder ici.';

  @override
  String get savedViewInChat => 'Aller au message';

  @override
  String get savedPhoto2 => 'Photo';

  @override
  String get scanThatSNotA => 'Ce n’est pas un QR Kryfo · continuez de viser';

  @override
  String get scanScanAKryfoQr => 'Scanner un QR Kryfo';

  @override
  String get scanFlash => 'Flash';

  @override
  String get scanPointAtAKryfo =>
      'Visez un QR Kryfo · rien ne quitte votre téléphone';

  @override
  String get seenWhatWeCanSee => 'Ce que nous pouvons voir';

  @override
  String get seenEveryMessengerClaimsPrivacy =>
      'Toutes les messageries promettent la confidentialité. Voici la liste précise, par mode d’envoi, y compris ce qui ne nous flatte pas. Touchez une ligne pour savoir pourquoi.';

  @override
  String get seenHonestAboutTheLast =>
      'Franchise sur les dernières lignes : c’est à ça que servent le verrouillage, le code d’effacement et le stockage chiffré, et aucun outil ne vous sauve de quelqu’un qui tient votre téléphone ouvert. Le modèle de menace complet se trouve dans THREAT_MODEL.md, dans le dépôt, écrit selon LINDDUN. Le code est ouvert, donc rien de tout cela n’est à croire sur parole.';

  @override
  String get seenHidden => 'Masqué';

  @override
  String get seenNever => 'Jamais';

  @override
  String get seenOnDevice => 'Sur l’appareil';

  @override
  String get seenYours => 'À vous';

  @override
  String get seenUnaudited => 'Non audité';

  @override
  String get seenWhoYouTalkTo => 'À qui vous parlez';

  @override
  String get seenEachConversationGetsIts =>
      'Chaque discussion a sa propre adresse, dérivée des deux clés. Un relais voit des boîtes de dépôt sans lien entre elles, pas deux personnes qui se parlent.';

  @override
  String get seenWhatYouSay => 'Ce que vous dites';

  @override
  String get seenEndToEndEncrypted =>
      'Chiffré de bout en bout avec le double ratchet de Signal, puis scellé une seconde fois dans un gift wrap. Nous ne pourrions pas le lire même en essayant.';

  @override
  String get seenYourIpAddress => 'Votre adresse IP';

  @override
  String get seenOurRelay => 'Notre relais';

  @override
  String get seenEveryRelay => 'Chaque relais';

  @override
  String get seenOnOnionEverythingLeaves =>
      'En Onion, tout sort par tor et le relais voit un nœud de sortie, jamais vous. En mode Relais, la connexion va directement à notre propre relais : rien ne transmet votre adresse et rien n’est noté, mais cette connexion-là, nous pouvons la voir. En Rapide, chaque relais public apprend votre connexion, mais pas à qui vous parlez ni ce que vous dites.';

  @override
  String get seenYourContactGraph => 'Votre graphe de contacts';

  @override
  String get seenKryfoDoesNotScan =>
      'Kryfo ne scanne pas vos contacts. C’est tout l’intérêt. Aucun numéro de téléphone n’existe ici, donc aucun ne peut fuiter.';

  @override
  String get seenIntroducer => 'Qui présente';

  @override
  String get seenWhenAContactIntroduces =>
      'Quand un contact vous présente à quelqu’un, ce contact apprend que vous êtes maintenant en lien tous les deux. Personne d’autre. Le relais voit du texte chiffré, et aucun serveur ne voit jamais le graphe.';

  @override
  String get seenTheScamShield => 'Le bouclier anti-arnaque';

  @override
  String get seenRunsOnYourPhone =>
      'Tourne sur votre téléphone avec des règles livrées dans l’appli. Pas de réseau, pas de listes téléchargées. Il ne lit que le premier message d’un inconnu et ne peut rien voir de ce qu’un contact vous envoie.';

  @override
  String get seenBurnerRooms => 'Salons éphémères';

  @override
  String get seenRoomKeys => 'Clés de salon';

  @override
  String get seenYouJoinARoom =>
      'Vous rejoignez un salon avec une clé créée pour lui, donc les gens à l’intérieur n’apprennent rien qui serve ailleurs. Ceux qui arrivent tard n’ont pas l’historique. À l’expiration, les clés, les messages et les médias sont détruits.';

  @override
  String get seenLinkPreviews => 'Aperçus de liens';

  @override
  String get seenOverTor => 'Par Tor';

  @override
  String get seenAPreviewIsFetched =>
      'Un aperçu est récupéré par l’expéditeur, par tor, et voyage dans le message chiffré. Le téléphone qui reçoit ne fait aucune requête. Le site apprend que quelqu’un utilisant tor a demandé une page, et rien d’autre. Aucune image n’est jamais chargée, et le lien d’un inconnu reste du texte brut.';

  @override
  String get seenASeizedUnlockedPhone => 'Un téléphone saisi déverrouillé';

  @override
  String get seenIfSomeoneHoldsYour =>
      'Si quelqu’un tient votre téléphone ouvert, il lit vos messages. Le verrouillage, le code d’effacement et le stockage chiffré aident avant ce moment, pas après.';

  @override
  String get seenTheCryptoItself => 'La cryptographie elle-même';

  @override
  String get seenTheRatchetAndStorage =>
      'Les couches ratchet et stockage sont standard. La couche qui les relie est la nôtre et personne d’indépendant ne l’a examinée. Considérez ceci comme une alpha, parce que c’en est une.';

  @override
  String get seenOnion => 'Onion';

  @override
  String get seenRelay => 'Relais';

  @override
  String get seenFast => 'Rapide';

  @override
  String get settingsWipeKryfo => 'Effacer Kryfo ?';

  @override
  String get settingsIdentityMessagesContactsAnd =>
      'Identité, messages, contacts et paramètres sur ce téléphone. Perdus pour de bon, sauf si vous avez une sauvegarde.';

  @override
  String get commonContinue => 'Continuer';

  @override
  String settingsTypeWipeToConfirm(Object word) {
    return 'Tapez « $word » pour confirmer';
  }

  @override
  String get settingsTheLastStepNothing => 'Dernière étape. Rien n’y survit.';

  @override
  String get settingsWipeWord => 'effacer';

  @override
  String get settingsWipeKryfo2 => 'Effacer Kryfo';

  @override
  String get settingsYourProtections => 'Vos protections';

  @override
  String get settingsTorRouting => 'Routage tor';

  @override
  String get settingsConnecting => 'Connexion';

  @override
  String get settingsOffMode => 'Désactivé · mode Relais';

  @override
  String get settingsOffFastMode => 'Désactivé · mode Rapide';

  @override
  String get settingsAppLock => 'Verrouillage';

  @override
  String get settingsBlockedByAndroid => 'Bloqué par Android';

  @override
  String get settingsSpeedPrivacy => 'Vitesse & confidentialité';

  @override
  String get settingsFast => 'Rapide';

  @override
  String get settingsRelay1Hop => 'Relais · 1 saut';

  @override
  String get settingsOnion3Hops => 'Onion · 3 sauts';

  @override
  String get settingsBridges => 'Ponts';

  @override
  String get settingsForNetworksThatBlock =>
      'Pour les réseaux qui bloquent tor';

  @override
  String get settingsGettingMessages => 'Réception des messages';

  @override
  String settingsPreviewHidden(Object deliveryModeName) {
    return '$deliveryModeName · aperçu masqué';
  }

  @override
  String settingsPreviewShown(Object deliveryModeName) {
    return '$deliveryModeName · aperçu visible';
  }

  @override
  String get settingsRunInBackground => 'Fonctionner en arrière-plan';

  @override
  String get settingsSoMessagesArrive => 'Pour que les messages arrivent';

  @override
  String get settingsTransport => 'Transport';

  @override
  String get settingsWhatTheNetworkIs => 'Ce que fait le réseau';

  @override
  String get settingsBlocked => 'Bloqués';

  @override
  String get settingsAcceptIntroductions => 'Accepter les présentations';

  @override
  String get settingsFriendsCanIntroduceYou =>
      'Vos contacts peuvent vous présenter aux leurs';

  @override
  String get settingsScamShield => 'Bouclier anti-arnaque';

  @override
  String get settingsChecksStrangersOnYour =>
      'Vérifie les inconnus sur votre téléphone. Rien n’en sort';

  @override
  String get settingsBlockScreenshots => 'Bloquer les captures';

  @override
  String get settingsWholeAppHiddenFrom =>
      'Toute l’appli masquée des récents et des captures · effet au prochain démarrage';

  @override
  String get settingsWholeAppHiddenFromRecentsAnd =>
      'Toute l’appli masquée des récents et des captures';

  @override
  String get settingsOnNextStart => 'Activé au redémarrage';

  @override
  String get settingsOffNextStart => 'Désactivé au redémarrage';

  @override
  String get settingsLightTheme => 'Thème clair';

  @override
  String get settingsSameProtectionBrighter => 'Même protection, plus lumineux';

  @override
  String get settingsAppLock2 => 'Verrouillage';

  @override
  String get settingsYourPinAndA => 'Votre code PIN et la protection avancée';

  @override
  String get settingsPinWipePin => 'Code PIN · code d’effacement';

  @override
  String get settingsBackUpIdentity => 'Sauvegarder l’identité';

  @override
  String get settingsEncryptedFile => 'Fichier chiffré';

  @override
  String get settingsRestoreFromBackup => 'Restaurer une sauvegarde';

  @override
  String get settingsReplaceCurrent => 'Remplace l’actuelle';

  @override
  String get settingsDisguiseVoice => 'Déguiser la voix';

  @override
  String get settingsShiftsYourPitchBefore =>
      'Change la hauteur de votre voix avant qu’une note vocale parte';

  @override
  String get settingsWhyKryfo => 'Pourquoi Kryfo';

  @override
  String get settingsHowItProtectsYou => 'Comment il vous protège';

  @override
  String get settingsResetMyInviteLink => 'Réinitialiser mon lien';

  @override
  String get settingsOldLinksAndCodes =>
      'Les anciens liens et codes cessent de marcher, pour tout le monde';

  @override
  String get settingsResetInviteLink => 'Réinitialiser le lien d’invitation ?';

  @override
  String get settingsAnyoneWithAnOld =>
      'Quiconque a un ancien code ou lien ne peut plus vous joindre, par aucune route. Ceux qui l’ont sans l’avoir utilisé auront besoin d’un nouveau de votre part. Les contacts, les discussions et l’historique restent.';

  @override
  String get settingsReset => 'Réinitialiser';

  @override
  String get settingsInviteResetShareThe =>
      'Invitation réinitialisée · partagez le nouveau code';

  @override
  String get settingsWhatWeCanSee => 'Ce que nous pouvons voir';

  @override
  String get settingsTheHonestList => 'La liste honnête';

  @override
  String get settingsVersion => 'Version';

  @override
  String get settings030Alpha => '0.5.0 · alpha';

  @override
  String get settingsReportAnIssue => 'Signaler un problème';

  @override
  String get settingsBugOrSecurityFlaw => 'Bug ou faille de sécurité';

  @override
  String get settingsOpenSource => 'Code source ouvert';

  @override
  String get settingsLinkCopied => 'Lien copié';

  @override
  String get settingsTheOfflineMapIn =>
      'La carte hors ligne des Outils est dessinée à partir de Natural Earth (domaine public). Les noms de villes viennent de GeoNames, geonames.org, sous licence CC BY 4.0.';

  @override
  String get settingsNotIndependentlyAuditedPre =>
      'Pas d’audit indépendant. Pré-alpha - bon pour tester, pas encore pour un usage à fort enjeu.';

  @override
  String get settingsDangerZone => 'Zone de danger';

  @override
  String get settingsWipeKryfoFromThis => 'Effacer Kryfo de ce téléphone';

  @override
  String get shieldCheckedOnThisPhone =>
      'Vérifié sur ce téléphone. Rien n’a été envoyé nulle part.';

  @override
  String get toolsMoreTools => 'Plus d’outils';

  @override
  String get toolsCleanAPhotoOr => 'Nettoyer une photo ou une vidéo';

  @override
  String get toolsOrShareOneTo =>
      'Ou partagez-en une vers Kryfo depuis votre galerie';

  @override
  String get toolsMakeAPrivateQr => 'Créer un code QR privé';

  @override
  String get toolsLinksWiFiContacts =>
      'Liens, Wi-Fi, contacts et plus. Créé hors ligne';

  @override
  String get toolsLockAFile => 'Verrouiller un fichier';

  @override
  String get toolsWithAPasswordOpens =>
      'Avec un mot de passe. S’ouvre partout avec age';

  @override
  String get toolsOpenALockedFile => 'Ouvrir un fichier verrouillé';

  @override
  String get toolsAnyAgeFileSomeone =>
      'N’importe quel fichier .age qu’on vous a envoyé';

  @override
  String get toolsWorksOfflineNoContacts =>
      'Marche hors ligne · aucun contact requis';

  @override
  String get toolsUsefulFrom => 'Utile dès';

  @override
  String get toolsTheFirstMinute => 'la première minute.';

  @override
  String get toolsEverythingHereHappensOn =>
      'Tout ici se passe sur ce téléphone. Rien n’est mis en ligne, et personne d’autre n’a besoin d’être sur Kryfo.';

  @override
  String get toolsWhatDoesThisPhoto => 'Que sait cette photo ?';

  @override
  String get toolsPlacePhoneTime => 'Lieu · téléphone · heure';

  @override
  String get toolsPickAPhotoAnd =>
      'Choisissez une photo et voyez ce qu’elle révèle. Puis gardez une copie propre.';

  @override
  String get toolsPickAPhoto => 'Choisir une photo';

  @override
  String get toolsVideo => 'Vidéo';

  @override
  String get transportTransport => 'Transport';

  @override
  String get transportNothingHereLeavesThe =>
      'Rien ici ne quitte le téléphone. C’est le même état que celui dont le moteur se sert pour décider quoi faire.';

  @override
  String get transportStayingAlive => 'Maintien en vie';

  @override
  String get transportCanSend => 'Peut envoyer';

  @override
  String get commonYes => 'Oui';

  @override
  String get transportNotYet => 'Pas encore';

  @override
  String get transportOnline => 'En ligne';

  @override
  String get transportOffline => 'Hors ligne';

  @override
  String get transportQueuedToSend => 'En attente d’envoi';

  @override
  String get transportOnionPublished => 'Adresse onion publiée';

  @override
  String transportYes(Object uploads) {
    return 'Oui ($uploads)';
  }

  @override
  String transportTryingS(Object pubFor) {
    return 'Essai depuis $pubFor s';
  }

  @override
  String transportBenchedS(Object r) {
    return 'Écarté $r s';
  }

  @override
  String transportFails(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString échecs',
      one: '$countString échec',
    );
    return '$_temp0';
  }

  @override
  String get transportOk => 'OK';

  @override
  String get transportRelaySubscriptions => 'Abonnements aux relais';

  @override
  String get transportLastSent => 'Dernier envoi';

  @override
  String get transportNever => 'Jamais';

  @override
  String transportSAgo(Object sx) {
    return 'il y a $sx s';
  }

  @override
  String get transportLastReceived => 'Dernière réception';

  @override
  String transportSAgo2(Object rx) {
    return 'il y a $rx s';
  }

  @override
  String get transportWithNoContactsThe =>
      'Sans contacts, l’appli ne s’abonne à aucune adresse de relais, donc aucun message ne peut vous parvenir. Scannez quelqu’un pour régler ça.';

  @override
  String get transportSendAnythingWaitingNow =>
      'Envoyer tout ce qui attend, maintenant';

  @override
  String get transportOff => 'Désactivé';

  @override
  String get transportStarting => 'Démarrage';

  @override
  String get transportBootstrapped => 'Amorcé';

  @override
  String get transportPublishingAddress => 'Publication de l’adresse';

  @override
  String get transportReachable => 'Joignable';

  @override
  String get transportOurRelayOnion => 'Notre relais (onion)';

  @override
  String get transportNever2 => 'jamais';

  @override
  String get transportJustNow => 'À l’instant';

  @override
  String transportMAgo(Object inMinutes) {
    return 'il y a $inMinutes min';
  }

  @override
  String transportHAgo(Object inHours) {
    return 'il y a $inHours h';
  }

  @override
  String transportDAgo(Object inDays) {
    return 'il y a $inDays j';
  }

  @override
  String transportM(Object inMinutes) {
    return '$inMinutes min';
  }

  @override
  String transportHM(Object inHours, Object d) {
    return '$inHours h $d min';
  }

  @override
  String transportD(Object inDays) {
    return '$inDays j';
  }

  @override
  String transportMb(Object b) {
    return '$b Mo';
  }

  @override
  String get transportYesCheckedJustNow => 'Oui · vérifié à l’instant';

  @override
  String transportNoLast(Object ago) {
    return 'Non · vérifié $ago';
  }

  @override
  String get transportLastMessageIn => 'Dernier message reçu';

  @override
  String get transportBatteryExemption => 'Exemption batterie';

  @override
  String get transportUnknown => 'Inconnu';

  @override
  String get transportExempt => 'Exempté';

  @override
  String get transportNotExemptTapTo => 'Non exempté · touchez pour régler';

  @override
  String get transportProcessUp => 'Processus actif';

  @override
  String get transportLastStop => 'Dernier arrêt';

  @override
  String transportEngine(Object mb, Object mb2) {
    return '$mb · moteur $mb2';
  }

  @override
  String get transportLastRelayArrival => 'Dernière arrivée par relais';

  @override
  String get transportLastCheckIn => 'Dernier relevé';

  @override
  String get transportNoneYet => 'Pas encore';

  @override
  String get transportLastTorReconnect => 'Dernière reconnexion Tor';

  @override
  String get transportCatchUpByRelay => 'Rattrapage par relais';

  @override
  String get transportControlPort => 'Port de contrôle';

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
      other: '$dialsString tentatives',
      one: '$dialsString tentative',
    );
    String _temp1 = intl.Intl.pluralLogic(
      timeouts,
      locale: localeName,
      other: '$timeoutsString délais dépassés',
      one: '$timeoutsString délai dépassé',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get transportJobRuns => 'Tâches lancées';

  @override
  String transportLast(Object jobRuns, Object ago) {
    return '$jobRuns · la dernière $ago';
  }

  @override
  String get transportQuietStretches => 'Périodes de silence';

  @override
  String get transportNone => 'Aucune';

  @override
  String get transportClearThisRecord => 'Vider cet historique';

  @override
  String get transportNothingYetThisProcess =>
      'Rien pour l’instant dans ce processus';

  @override
  String transportM2(Object mins) {
    return '$mins min';
  }

  @override
  String transportHM2(Object mins, Object mins2) {
    return '$mins h $mins2 min';
  }

  @override
  String transportTo(Object t, Object t2) {
    return '$t à $t2';
  }

  @override
  String vouchersVouchedBy(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Recommandé par $countString',
      one: 'Recommandé par',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperAtmosphere => 'Ambiance';

  @override
  String get wallpaperJustForYouThey => 'Juste pour vous. Chacun voit le sien.';

  @override
  String get wallpaperYourPhoto => 'Votre photo';

  @override
  String get wallpaperFromYourPhotos => 'Depuis vos photos';

  @override
  String get wallpaperKeepIt => 'Garder';

  @override
  String get whyKryfoWhyKryfo => 'Pourquoi Kryfo';

  @override
  String get whyKryfoKryfoKreeFoGreek =>
      'Kryfo · KRI-fo · « caché » en grec.\nUn endroit tranquille pour parler, conçu pour que personne n’observe.';

  @override
  String get whyKryfoRoutedThroughTor => 'Acheminé par tor';

  @override
  String get whyKryfoByDefaultEveryMessage =>
      'Par défaut, chaque message passe par tor - une chaîne de relais. Personne, ni nous ni votre réseau, ne peut voir à qui vous parlez ni où vous êtes.';

  @override
  String get whyKryfoEndToEndEncrypted => 'Chiffré de bout en bout';

  @override
  String get whyKryfoMessagesAreSealedWith =>
      'Les messages sont scellés avec des clés que seuls vous et la personne à qui vous parlez détenez. Nous ne pourrions pas les lire même en essayant.';

  @override
  String get whyKryfoNoServersHoldingYour =>
      'Aucun serveur ne détient votre vie';

  @override
  String get whyKryfoNoAccountNoPhone =>
      'Pas de compte, pas de numéro de téléphone, pas de serveur central qui stocke vos discussions. Elles vivent sur ce téléphone, chiffrées au repos.';

  @override
  String get whyKryfoNothingLeaks => 'Rien ne fuite';

  @override
  String get whyKryfoNoReadReceiptsOr =>
      'Pas d’accusés de lecture ni d’indicateurs de saisie donnés à qui que ce soit, pas de liste de contacts envoyée. Les métadonnées, c’est ce que la plupart des applis laissent fuiter - Kryfo est conçu pour ne pas le faire.';

  @override
  String get whyKryfoVerifyItIsReally => 'Vérifiez son identité';

  @override
  String get whyKryfoCompareASafetyNumber =>
      'Comparez un numéro de sécurité en personne ou par un canal de confiance, pour savoir que personne ne se fait passer pour votre contact.';

  @override
  String get whyKryfoTheHonestPart => 'En toute franchise';

  @override
  String get whyKryfoKryfoIsPreAlpha =>
      'Kryfo est en pré-alpha et n’a pas été audité. La cryptographie est réelle, mais aucun expert extérieur ne l’a encore vérifiée, alors considérez-le comme un travail en cours, pas encore comme quelque chose à qui confier votre vie.';

  @override
  String get cleanerLocation => 'Position';

  @override
  String get cleanerAlreadyBlankedByAndroid => 'déjà vidée par Android';

  @override
  String get cleanerPhoneModel => 'Modèle de téléphone';

  @override
  String get cleanerTimeTaken => 'Heure de la prise';

  @override
  String get cleanerSerialNumber => 'Numéro de série';

  @override
  String get cleanerOwnerName => 'Propriétaire';

  @override
  String get cleanerHiddenThumbnail => 'Miniature cachée';

  @override
  String get cleanerContentCredentials => 'Identifiants de contenu';

  @override
  String get cleanerDataAfterThePicture => 'Données après l’image';

  @override
  String cleaner1OtherField(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString autres champs',
      one: '$countString autre champ',
    );
    return '$_temp0';
  }

  @override
  String get lockWordsFourRandomWordsBeat =>
      'Quatre mots au hasard valent mieux qu’un seul mot astucieux.';

  @override
  String lockWordsTooShortAtLeast(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Trop court. Au moins $countString caractères.',
      one: 'Trop court. Au moins $countString caractère.',
    );
    return '$_temp0';
  }

  @override
  String get lockWordsWeakWhoeverGetsThe =>
      'Faible. Quiconque obtient le fichier peut deviner aussi vite qu’il veut.';

  @override
  String get lockWordsFairLongerIsStronger =>
      'Correct. Plus long, c’est plus solide.';

  @override
  String get lockWordsStrongFourRandomWords =>
      'Solide. Quatre mots au hasard valent mieux qu’un seul mot astucieux.';

  @override
  String photoStoryKm(Object m) {
    return '$m km';
  }

  @override
  String photoStory1Metre(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString mètres',
      one: '$countString mètre',
    );
    return '$_temp0';
  }

  @override
  String get photoStoryFarFromAnyTown => 'Loin de toute ville';

  @override
  String photoStoryNear(Object where) {
    return 'Près de $where';
  }

  @override
  String photoStoryAboutKmFrom(Object near, Object where) {
    return 'À environ $near km de $where';
  }

  @override
  String photoStoryS(Object s) {
    return '$s s';
  }

  @override
  String photoStory1S(Object s) {
    return '1/$s s';
  }

  @override
  String get photoStoryNotAKindKryfo => 'Un type que Kryfo ne sait pas lire.';

  @override
  String get photoStorySoItWillNot => 'Alors il ne devinera pas.';

  @override
  String get photoStoryThisFileIsDamaged =>
      'Ce fichier est endommagé ou tronqué.';

  @override
  String get photoStoryKryfoCouldNotRead =>
      'Kryfo n’a pas pu le lire jusqu’au bout.';

  @override
  String get photoStoryWhereItWasRecorded => 'Où elle a été filmée';

  @override
  String get photoStoryWhereItWasTaken => 'Où elle a été prise';

  @override
  String photoStoryLocation(Object coordsLine) {
    return 'Position : $coordsLine';
  }

  @override
  String photoStoryHeightAboveTheSea(Object fix) {
    return 'Altitude : $fix m';
  }

  @override
  String get photoStoryLocationHiddenByAndroid =>
      'Position masquée par Android';

  @override
  String get photoStoryAndroidBlanksItWhen =>
      'Android retire la position quand une photo est choisie de cette façon. Partager la photo vers Kryfo depuis votre galerie la garde souvent. Celle de votre galerie l’a peut-être encore.';

  @override
  String get photoStoryLocationBlankedByAndroid =>
      'Position : vidée par Android avant que Kryfo la voie';

  @override
  String photoStoryF(Object r) {
    return 'f/$r';
  }

  @override
  String get photoStoryWhatTookIt => 'Ce qui l’a prise';

  @override
  String photoStoryPhoneOrCamera(Object phone) {
    return 'Téléphone ou appareil photo : $phone';
  }

  @override
  String get photoStoryWhenItWasRecorded => 'Quand elle a été filmée';

  @override
  String get photoStoryToTheSecondWith =>
      'À la seconde près, avec le fuseau horaire';

  @override
  String get photoStoryToTheSecond => 'À la seconde près';

  @override
  String photoStoryTime(Object dateFormat) {
    return 'Heure : $dateFormat';
  }

  @override
  String get photoStoryLens => 'Objectif';

  @override
  String photoStoryLens2(Object lens) {
    return 'Objectif : $lens';
  }

  @override
  String get photoStorySoftware => 'Logiciel';

  @override
  String photoStorySoftware2(Object software) {
    return 'Logiciel : $software';
  }

  @override
  String get photoStorySerialNumber => 'Numéro de série';

  @override
  String photoStorySerialNumber2(Object serial) {
    return 'Numéro de série : $serial';
  }

  @override
  String get photoStoryOwnerName => 'Propriétaire';

  @override
  String photoStoryOwner(Object r) {
    return 'Propriétaire : $r';
  }

  @override
  String get photoStoryHiddenThumbnail => 'Miniature cachée';

  @override
  String get photoStoryASmallCopyOf =>
      'Une petite copie de l’image, dans le fichier. Elle peut montrer ce qu’un recadrage a retiré';

  @override
  String get photoStoryMakerNotes => 'Notes du fabricant';

  @override
  String get photoStoryMakerNotesABlock =>
      'Notes du fabricant : un bloc que seul le fabricant sait lire';

  @override
  String get photoStoryEditingHistory => 'Historique d’édition';

  @override
  String get photoStoryXmpEditingHistoryAnd =>
      'XMP : historique d’édition et mots-clés';

  @override
  String get photoStoryCaptions => 'Légendes';

  @override
  String get photoStoryIptcCaptionsAndCredits => 'IPTC : légendes et crédits';

  @override
  String get photoStoryComment => 'Commentaire';

  @override
  String get photoStoryAWrittenComment => 'Un commentaire écrit';

  @override
  String get photoStoryContentCredentials => 'Identifiants de contenu';

  @override
  String get photoStorySecondPicture => 'Seconde image';

  @override
  String get photoStoryASecondPictureInside =>
      'Une seconde image dans le fichier';

  @override
  String get photoStoryMotionVideo => 'Vidéo animée';

  @override
  String get photoStoryAShortVideoInside => 'Une courte vidéo dans le fichier';

  @override
  String get photoStorySaveTime => 'Heure d’enregistrement';

  @override
  String get photoStoryTheTimeItWas => 'L’heure du dernier enregistrement';

  @override
  String get photoStoryTimeStamps => 'Horodatages';

  @override
  String get photoStoryCreationTimeStamps => 'Horodatages de création';

  @override
  String get photoStoryDataAfterThePicture => 'Données après l’image';

  @override
  String photoStoryDataAfterTheEnd(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Données après la fin de l’image : $countString octets',
      one: 'Données après la fin de l’image : $countString octet',
    );
    return '$_temp0';
  }

  @override
  String photoStoryTextField(Object k) {
    return 'Champ texte : $k';
  }

  @override
  String photoStoryVideoTag(Object k) {
    return 'Balise vidéo : $k';
  }

  @override
  String photoStoryAlso(Object k) {
    return 'Aussi : $k';
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
          '$countString réglages de l’appareil (flash, mise au point, exposition)',
      one:
          '$countString réglage de l’appareil (flash, mise au point, exposition)',
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
      other: '$countString champs de plus',
      one: '$countString champ de plus',
    );
    return '$_temp0';
  }

  @override
  String get photoStoryCameraSettings => 'Réglages de l’appareil';

  @override
  String photoStoryAccurateToAbout(Object metres) {
    return 'Précision : environ $metres.';
  }

  @override
  String get photoStoryEnoughToFindThe => 'De quoi trouver la porte.';

  @override
  String get photoStoryEnoughToFindTheStreet => 'De quoi trouver la rue.';

  @override
  String get photoStoryEnoughToFindTheArea => 'De quoi trouver le quartier.';

  @override
  String get photoStoryItKnowsWhereYou => 'Elle sait où vous étiez.';

  @override
  String get photoStoryDownToTheBuilding => 'Au bâtiment près.';

  @override
  String get photoStoryAndroidHidTheLocation => 'Android a masqué la position.';

  @override
  String get photoStoryTheOriginalMayStill =>
      'L’original l’a peut-être encore.';

  @override
  String get photoStoryNoLocationInThis => 'Pas de position dans celle-ci.';

  @override
  String get photoStoryItStillSaysPlenty => 'Elle en dit quand même beaucoup.';

  @override
  String get photoStoryThisOneKnowsNothing => 'Celle-ci ne sait rien.';

  @override
  String get photoStoryNothingToRemove => 'Rien à retirer.';

  @override
  String get qrPayloadOpensALink => 'OUVRE UN LIEN';

  @override
  String qrPayloadOpens(Object host) {
    return 'OUVRE $host';
  }

  @override
  String get qrPayloadShowsANote => 'AFFICHE UNE NOTE';

  @override
  String get qrPayloadScanToJoin => 'SCANNEZ POUR REJOINDRE';

  @override
  String qrPayloadScanToJoin2(Object oneLine) {
    return 'SCANNEZ POUR REJOINDRE · $oneLine';
  }

  @override
  String get qrPayloadANetworkNameIs =>
      'Un nom de réseau fait 32 caractères au plus.';

  @override
  String get qrPayloadAWiFiPassword =>
      'Un mot de passe Wi-Fi fait au moins 8 caractères.';

  @override
  String get qrPayloadSavesAContact => 'ENREGISTRE UN CONTACT';

  @override
  String get qrPayloadWritesAnEmail => 'ÉCRIT UN E-MAIL';

  @override
  String get qrPayloadThatDoesNotLook =>
      'Ça ne ressemble pas à une adresse e-mail.';

  @override
  String get qrPayloadCallsANumber => 'APPELLE UN NUMÉRO';

  @override
  String get qrPayloadWritesAText => 'ÉCRIT UN SMS';

  @override
  String get qrPayloadOpensAMap => 'OUVRE UNE CARTE';

  @override
  String get qrPayloadLatitudeRunsFrom90 =>
      'La latitude va de -90 à 90, la longitude de -180 à 180.';

  @override
  String get qrPayloadPayThisAddress => 'PAYER CETTE ADRESSE';

  @override
  String get qrPayloadABitcoinAddressIs =>
      'Une adresse bitcoin ne contient que des lettres et des chiffres.';

  @override
  String get qrPayloadTheAmountIsIn =>
      'Le montant est en BTC, avec 8 décimales au plus.';

  @override
  String vouchTextAnd(Object names, Object names2) {
    return '$names et $names2';
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
      other: '$restString autres personnes que vous connaissez',
      one: '$restString autre personne que vous connaissez',
    );
    return '$names, $names2 et $_temp0';
  }

  @override
  String vouchTextVouchedBy(Object vouchNames) {
    return 'Recommandé par $vouchNames';
  }

  @override
  String vouchTextIntroducedBy(Object vouchNames) {
    return 'Présenté par $vouchNames';
  }

  @override
  String vouchTextThisSharesSAddress(Object a, Object b) {
    return 'Cela partage l’adresse de $a avec $b';
  }

  @override
  String get bootFailedKryfoCouldNotStart => 'Kryfo n’a pas pu démarrer';

  @override
  String get bootFailedThisIsAFault =>
      'C’est une panne sur cet appareil, pas sur le réseau. Tor n’est pas en cause.';

  @override
  String get kryfoLinkTextThatLinkIsNot => 'Kryfo ne sait pas lire ce lien';

  @override
  String kryfoLinkTextAdd(Object who) {
    return 'Ajouter $who ?';
  }

  @override
  String kryfoLinkTextThisIsAnInvite(Object who) {
    return 'C’est une invitation à parler avec $who. Ne l’ajoutez que si vous savez d’où vient le lien.';
  }

  @override
  String get kryfoLinkTextAddThem => 'Ajouter';

  @override
  String get kryfoLinkTextNotNow => 'Pas maintenant';

  @override
  String kryfoLinkTextJoin(Object roomName) {
    return 'Rejoindre $roomName';
  }

  @override
  String get kryfoLinkTextKryfoLink => 'Lien Kryfo';

  @override
  String kryfoLinkTextAdd2(Object who) {
    return 'Ajouter $who';
  }

  @override
  String get kryfoLinkTextBurnerRoom => 'SALON ÉPHÉMÈRE';

  @override
  String get kryfoLinkTextThisRoomHasClosed => 'Ce salon est fermé';

  @override
  String kryfoLinkTextClosesIn(Object time) {
    return 'Ferme dans $time';
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
      other: 'Ferme dans $time · jusqu’à $capString personnes',
      one: 'Ferme dans $time · jusqu’à $capString personne',
    );
    return '$_temp0';
  }

  @override
  String get kryfoLinkTextJoin2 => 'Rejoindre';

  @override
  String get kryfoLinkTextYouJoinUnderA =>
      'Vous rejoignez avec une clé créée pour ce salon. Personne à l’intérieur ne voit votre ID Kryfo.';

  @override
  String get linkStubFetchedOverTorBy =>
      'Récupéré par tor · par votre appareil';

  @override
  String get linkStubFetchedOverTorByTheirDevice =>
      'Récupéré par tor · par son appareil';

  @override
  String mediaBubblesB(Object bytes) {
    return '$bytes o';
  }

  @override
  String mediaBubblesKb(Object bytes) {
    return '$bytes Ko';
  }

  @override
  String mediaBubblesMb(Object bytes) {
    return '$bytes Mo';
  }

  @override
  String get mediaBubblesFile => 'FICHIER';

  @override
  String get mediaBubblesAudioUnavailable => 'Audio indisponible';

  @override
  String get mediaBubblesHidden => 'Masqué';

  @override
  String get mediaBubblesMicPermissionNeeded => 'Accès au micro requis';

  @override
  String get mediaBubblesReleaseToCancel => 'Relâchez pour annuler';

  @override
  String get mediaBubblesVoiceHiddenSlideTo =>
      'Voix déguisée · glissez pour annuler';

  @override
  String get mediaBubblesSlideToCancel => 'Glissez pour annuler';

  @override
  String get mediaBubblesSendPhoto => 'Envoyer la photo';

  @override
  String get mediaBubblesAddACaption => 'Ajouter une légende…';

  @override
  String get motionStandby => 'EN ATTENTE';

  @override
  String get motionConnecting => 'CONNEXION';

  @override
  String get motionBuilding => 'CONSTRUCTION';

  @override
  String get motionPublishing => 'PUBLICATION';

  @override
  String get motionReady => 'PRÊT';

  @override
  String get motionPreparingToConnect => 'Préparation de la connexion';

  @override
  String get motionFindingAPrivatePath => 'Recherche d’un chemin privé';

  @override
  String get motionCarvingThePath => 'Tracé du chemin';

  @override
  String get motionAnnouncingYourArrival => 'Annonce de votre arrivée';

  @override
  String get motionYouReAnonymous => 'Vous êtes anonyme';

  @override
  String get motionTorIsStartingIn =>
      'Tor démarre en arrière-plan. Ce graphe s’allume à mesure que la connexion se forme.';

  @override
  String get motionMakingAFreshRoute =>
      'Création d’une nouvelle route à travers des relais anonymes.';

  @override
  String get motionBouncingThroughRelaysSo =>
      'Rebonds entre relais pour que personne ne puisse remonter jusqu’à vous.';

  @override
  String get motionTellingTheNetworkYou =>
      'On dit au réseau que vous êtes en ligne — sans révéler où.';

  @override
  String get motionYourIpIsHidden =>
      'Votre IP est masquée. Seuls ceux qui ont votre Kryfo peuvent vous joindre.';

  @override
  String get motionBuilding2 => 'construction';

  @override
  String get motionOpen => 'ouvert';

  @override
  String get motionLive => 'actif';

  @override
  String motionCircuit(Object circuit) {
    return 'Circuit · *$circuit*';
  }

  @override
  String get motionDelivered => 'Distribué';

  @override
  String get motionSent => 'Envoyé';

  @override
  String get motion1Hop => '1 saut';

  @override
  String get motion3Hops => '3 sauts';

  @override
  String get movedStripThisKryfoHasMoved =>
      'Ce Kryfo a déménagé sur un autre appareil. Rien de ce qui est envoyé d’ici n’atteint personne.';

  @override
  String get navBarChats => 'Discussions';

  @override
  String get navBarTools => 'Outils';

  @override
  String get navBarSupport => 'Soutenir';

  @override
  String get navBarMe => 'Moi';

  @override
  String get pairCodePanelPuttingYourInviteIn =>
      'Mise en place de votre invitation';

  @override
  String get pairCodePanelYourInviteIsNot =>
      'Votre invitation n’est pas encore prête';

  @override
  String get pairCodePanelReadSixDigitsOut =>
      'Lisez six chiffres à voix haute et la personne pourra vous ajouter. Rien d’autre n’a besoin de changer de mains.';

  @override
  String get pairCodePanelWorking => 'En cours';

  @override
  String get pairCodePanelOrMakeASix =>
      'Ou créez un code à six chiffres à lire à voix haute';

  @override
  String get pairCodePanelCodeCopied => 'Code copié';

  @override
  String pairCodePanelBurnsIn(Object mm, Object ss) {
    return 'Disparaît dans $mm:$ss';
  }

  @override
  String get pairCodePanelTheyTapAddChoose =>
      'La personne touche Ajouter, choisit Code, et tape ces chiffres.';

  @override
  String get pairCodePanelTheyOpenKryfoTap =>
      'La personne ouvre Kryfo, touche Ajouter, choisit Code d’appairage et tape ces six chiffres. Créez-en un nouveau pour la personne suivante.';

  @override
  String get pairCodePanelYourWords => 'Vos trois mots';

  @override
  String pinsPinnedMessages(Object count) {
    return 'Messages épinglés · $count';
  }

  @override
  String get pinsPinnedMessages2 => 'Messages épinglés';

  @override
  String get pinsPhoto => 'Photo';

  @override
  String get pinsVoiceMessage => 'Message vocal';

  @override
  String get pinsMessage => 'Message';

  @override
  String pinsToday(Object hm) {
    return 'Aujourd’hui · $hm';
  }

  @override
  String get pinsPinned => 'Épinglé';

  @override
  String pinsOf(Object pinsLength, Object kMaxPins) {
    return '$pinsLength sur $kMaxPins';
  }

  @override
  String get pinsNothingPinnedHereYet =>
      'Rien d’épinglé ici pour l’instant. Maintenez un message et choisissez Épingler : il attendra ici pour tout le monde dans la discussion.';

  @override
  String get pinsJump => 'Aller';

  @override
  String get pinsUnpin => 'Désépingler';

  @override
  String powNoteFirstMessageToSomeone(int secs) {
    final intl.NumberFormat secsNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String secsString = secsNumberFormat.format(secs);

    return 'Premier message à quelqu’un de nouveau · preuve qu’il est réel · $secsString s';
  }

  @override
  String powNoteFirstMessageSlow(int secs) {
    final intl.NumberFormat secsNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String secsString = secsNumberFormat.format(secs);

    return 'Premier message à quelqu’un de nouveau · preuve qu’il est réel · $secsString s · jusqu’à une minute sur un téléphone lent';
  }

  @override
  String previewStripFetchedOverTor(Object domainOf) {
    return '$domainOf · récupéré par tor';
  }

  @override
  String get previewStripDropThePreview => 'Retirer l’aperçu';

  @override
  String get previewStripAddPreview => 'Ajouter l’aperçu';

  @override
  String get previewStripFetchingOverTor => 'Récupération par tor…';

  @override
  String toolPartsB(Object bytes) {
    return '$bytes o';
  }

  @override
  String toolPartsKb(Object bytes) {
    return '$bytes Ko';
  }

  @override
  String toolPartsMb(Object mb) {
    return '$mb Mo';
  }

  @override
  String get torBootSplashNoShortcutsNoTraces =>
      'Pas de raccourcis, pas de traces';

  @override
  String get torBootSplashTheNetworkThatKeeps =>
      'Le réseau qui préserve votre vie privée se met en route';

  @override
  String get torBootSplashMadeOnThisPhone =>
      'Créé sur ce téléphone. Rien n’est envoyé nulle part.';

  @override
  String get torBootSplashFirstLaunchTakesA =>
      'Le premier lancement prend un moment · seulement au démarrage';

  @override
  String get videoBubbleNothingHereOpensThat =>
      'Rien ici n’ouvre ça · partage à la place';

  @override
  String videoBubbleMb(Object b) {
    return '$b Mo';
  }

  @override
  String videoBubbleKb(Object b) {
    return '$b Ko';
  }

  @override
  String get videoBubbleVideo => 'Vidéo';

  @override
  String get notificationsChannelName => 'Messages';

  @override
  String get cameraClose => 'Fermer';

  @override
  String get cameraFlash => 'Flash';

  @override
  String get cameraPhoto => 'Photo';

  @override
  String get cameraVideo => 'Vidéo';

  @override
  String get cameraRetake => 'Reprendre';

  @override
  String get seenIntroductions => 'Présentations';

  @override
  String get donateAddress => 'Adresse';

  @override
  String get donateCopy => 'Copier';

  @override
  String get donateDone => 'Terminé';

  @override
  String get donateTierSupporter => 'Soutien';

  @override
  String get donateTierPatron => 'Mécène';

  @override
  String get donateTierGuardian => 'Gardien';

  @override
  String get chatBlock => 'Bloquer';

  @override
  String get chatDecline => 'Refuser';

  @override
  String get chatAccept => 'Accepter';

  @override
  String get bridgesConnecting => 'Connexion';

  @override
  String get bridgesSavedTag => 'Enregistré';

  @override
  String get restoreMade => 'Créée';

  @override
  String get restoreContacts => 'Contacts';

  @override
  String get restoreMessages => 'Messages';

  @override
  String get restoreAttachments => 'Pièces jointes';

  @override
  String get restoreHiddenChats => 'Discussions masquées';

  @override
  String get restoreHiddenFollow =>
      'Vos discussions masquées, avec un nouveau code des discussions masquées que vous choisirez à la fin.';

  @override
  String get restoreChooseHiddenPin =>
      'Cette sauvegarde contient des discussions masquées. Choisissez un code des discussions masquées pour elles.';

  @override
  String get restoreHiddenLockFirst =>
      'Les discussions masquées ont besoin du verrouillage, alors Kryfo reçoit d’abord son propre code PIN.';

  @override
  String get shieldBlock => 'Bloquer';

  @override
  String get shieldDelete => 'Supprimer';

  @override
  String get shieldIgnore => 'Ignorer';

  @override
  String get profileIdentity => 'Identité';

  @override
  String get avatarPickerShape => 'Forme';

  @override
  String get avatarPickerColour => 'Couleur';

  @override
  String get avatarPickerTurn => 'Rotation';

  @override
  String get transportStatus => 'État';

  @override
  String get transportBootstrap => 'Amorçage';

  @override
  String get transportNetwork => 'Réseau';

  @override
  String get transportConnectivity => 'Connectivité';

  @override
  String get transportRelays => 'Relais';

  @override
  String get transportTraffic => 'Trafic';

  @override
  String get transportContacts => 'Contacts';

  @override
  String get transportKnown => 'Connus';

  @override
  String get transportListening => 'À l’écoute';

  @override
  String get transportMemory => 'Mémoire';

  @override
  String get settingsConnected => 'Connecté';

  @override
  String get settingsScreenshots => 'Captures d’écran';

  @override
  String get settingsBlocked2 => 'Bloquées';

  @override
  String get settingsAllowed => 'Autorisées';

  @override
  String get settingsOn => 'Activé';

  @override
  String get settingsOff => 'Désactivé';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsPrivacy => 'Confidentialité';

  @override
  String get settingsSecurity => 'Sécurité';

  @override
  String get settingsBackup => 'Sauvegarde';

  @override
  String get settingsVoice => 'Voix';

  @override
  String get settingsAbout => 'À propos';

  @override
  String get wallpaperGradients => 'Dégradés';

  @override
  String get wallpaperPatterns => 'Motifs';

  @override
  String get wallpaperMoods => 'Humeurs';

  @override
  String get confirmSheetKeep => 'Garder';

  @override
  String get confirmSheetSave => 'Enregistrer';

  @override
  String get confirmSheetCancel => 'Annuler';

  @override
  String bridgesSaved(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString ponts',
      one: '$countString pont',
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

    return 'Acceptés : $goodString, non compris : $badString';
  }

  @override
  String get languageTitle => 'Langue';

  @override
  String get languageMatchPhone => 'Comme le téléphone';

  @override
  String languageMatchPhoneValue(Object language) {
    return 'Comme le téléphone ($language)';
  }

  @override
  String get languageRedrawLine =>
      'Kryfo se redessine dans la nouvelle langue et s’ouvre sur vos discussions.';

  @override
  String languageButton(Object language) {
    return 'Langue : $language';
  }

  @override
  String get androidServiceTitle => 'Kryfo est actif';

  @override
  String get androidServiceText =>
      'Votre ligne chiffrée reste ouverte pour que les messages arrivent';

  @override
  String get androidChannelName => 'Connexion maintenue';

  @override
  String get androidChannelDescription =>
      'Garde Kryfo connecté pour que les messages chiffrés arrivent quand il est fermé. Le désactiver coupe la distribution.';

  @override
  String get videoViewerPlay => 'Lire';

  @override
  String get videoViewerPause => 'Pause';

  @override
  String get videoViewerPlayAgain => 'Relire';

  @override
  String get videoViewerCannotPlay =>
      'Ce téléphone ne peut pas lire cette vidéo ici.';

  @override
  String get videoViewerOpenElsewhere => 'Ouvrir dans une autre appli';

  @override
  String get photoKnowsLookedFor => 'Recherché';

  @override
  String get photoKnowsNotInIt => 'Absent';

  @override
  String get languageNameEn => 'Anglais';

  @override
  String get languageNameDe => 'Allemand';

  @override
  String get languageNameFr => 'Français';

  @override
  String get languageNameEs => 'Espagnol';

  @override
  String get languageNamePt => 'Portugais (Brésil)';

  @override
  String get languageNameIt => 'Italien';

  @override
  String get languageNameRu => 'Russe';

  @override
  String get languageNameUk => 'Ukrainien';

  @override
  String get languageNameTr => 'Turc';

  @override
  String get languageNameZh => 'Chinois (simplifié)';

  @override
  String get languageNameZhHant => 'Chinois (traditionnel)';

  @override
  String get languageNameVi => 'Vietnamien';

  @override
  String get languageNameId => 'Indonésien';

  @override
  String get languageNameFa => 'Persan';

  @override
  String get languageNameAr => 'Arabe';

  @override
  String get languageLaterLine =>
      'Vous pouvez la changer à tout moment dans les paramètres.';

  @override
  String get pollAttach => 'Sondage';

  @override
  String get pollNewTitle => 'Nouveau sondage';

  @override
  String get pollQuestionHint => 'Posez une question au groupe';

  @override
  String get pollOptionsLabel => 'Réponses';

  @override
  String pollOptionHint(Object n) {
    return 'Réponse $n';
  }

  @override
  String get pollAddOption => 'Ajouter une réponse';

  @override
  String get pollMaxLine => 'Douze réponses au maximum.';

  @override
  String get pollMultiple => 'Plusieurs réponses';

  @override
  String get pollMultipleLine => 'Chacun peut en choisir plusieurs.';

  @override
  String get pollSend => 'Envoyer le sondage';

  @override
  String get pollKind => 'Sondage';

  @override
  String get pollKindMulti => 'Sondage · plusieurs réponses';

  @override
  String get pollKindClosed => 'Résultat final';

  @override
  String pollVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count votes',
      one: '$count vote',
      zero: 'Aucun vote pour l’instant',
    );
    return '$_temp0';
  }

  @override
  String get pollVote => 'Voter';

  @override
  String get pollTakeBack => 'Retirer mon vote';

  @override
  String get pollClose => 'Clore le sondage';

  @override
  String get pollCloseTitle => 'Clore ce sondage ?';

  @override
  String get pollCloseLine =>
      'Tout le monde voit le résultat final, et plus personne ne peut voter ensuite.';

  @override
  String get pollCloseYes => 'Le clore';

  @override
  String pollPreview(Object question) {
    return 'Sondage : $question';
  }

  @override
  String get pollWhoVoted => 'Qui a voté';

  @override
  String get pollNobody => 'Personne pour l’instant';

  @override
  String get pollYou => 'Vous';

  @override
  String pollOptionA11y(Object option, Object share) {
    return '$option, $share';
  }

  @override
  String get pollPickOne => 'Choisissez-en une';

  @override
  String get pollPickSeveral => 'Choisissez-en une ou plusieurs';

  @override
  String get searchOpen => 'Rechercher';

  @override
  String get searchHint => 'Rechercher dans les discussions et les messages';

  @override
  String get searchFilterAll => 'Tout';

  @override
  String get searchFilterPhotos => 'Photos';

  @override
  String get searchFilterVideos => 'Vidéos';

  @override
  String get searchFilterFiles => 'Fichiers';

  @override
  String get searchFilterLinks => 'Liens';

  @override
  String get searchChats => 'Discussions';

  @override
  String get searchMessages => 'Messages';

  @override
  String get searchIntroTitle => 'Cherchez dans vos discussions';

  @override
  String get searchIntroLine =>
      'Noms, mots, photos, fichiers et liens. La recherche se fait sur ce téléphone et n’envoie rien nulle part.';

  @override
  String get searchNothing => 'Rien trouvé';

  @override
  String get searchNothingLine => 'Essayez un autre mot, ou un autre filtre.';

  @override
  String searchMatches(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count résultats',
      one: '$count résultat',
    );
    return '$_temp0';
  }

  @override
  String searchMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de plus',
      one: '$count de plus',
    );
    return '$_temp0';
  }

  @override
  String searchFilling(Object share) {
    return 'Ajout des anciens messages · $share';
  }

  @override
  String get searchClear => 'Effacer';

  @override
  String get handleShowInSearch => 'Me montrer dans la recherche';

  @override
  String get handleShowInSearchLine =>
      'N’importe qui peut trouver ce pseudo et vous écrire.';

  @override
  String handleShownAs(Object name) {
    return 'Affiché comme $name';
  }

  @override
  String get handleNameInSearch => 'Nom dans la recherche';

  @override
  String get handleNameInSearchLine =>
      'Facultatif. Il apparaît à côté de votre pseudo quand quelqu’un cherche. N’importe qui peut trouver ce pseudo et vous écrire.';

  @override
  String get handleNameHint => 'Votre nom, ou laissez vide';

  @override
  String get handleShowMe => 'Me montrer';

  @override
  String get handleSearchOff => 'Vous n’êtes plus dans la recherche';

  @override
  String handleSearchOn(Object handle) {
    return 'Vous êtes dans la recherche en tant que @$handle';
  }

  @override
  String get handleRegistryFailed =>
      'Le registre n’a pas répondu. Réessayez dans une minute.';

  @override
  String get handleCheckClock =>
      'Vérifiez la date et l’heure du téléphone, puis réessayez.';

  @override
  String get searchPeople => 'Personnes';

  @override
  String searchPeopleAsk(Object query) {
    return 'Chercher « $query » parmi les pseudos publics';
  }

  @override
  String get searchPeopleLine =>
      'Demandé via Tor. Le registre n’en garde aucune trace.';

  @override
  String get searchPeopleNone => 'Aucun pseudo public ne correspond';

  @override
  String get searchPeopleOffline => 'Tor n’est pas encore prêt';

  @override
  String get searchPeopleBusy =>
      'Trop de recherches en ce moment. Réessayez dans un instant.';

  @override
  String get searchPeopleUnreachable => 'Le registre n’a pas répondu';

  @override
  String get peopleVerified => 'Pseudo vérifié';

  @override
  String get peopleAdd => 'Ajouter';

  @override
  String peopleFingerprint(Object fp) {
    return 'Empreinte de la clé · $fp';
  }

  @override
  String get peopleFingerprintLine =>
      'Vérifiez qu’elle correspond à ce qu’ils voient dans leur appli.';

  @override
  String get peopleAdding => 'Ajout…';

  @override
  String handleNobodyHasClaimed(Object handle) {
    return 'Personne n’a réservé $handle';
  }

  @override
  String get handleThatHandleIsTaken => 'Ce pseudo est déjà pris';

  @override
  String get pinPickDifferent => 'Choisissez un autre code PIN';

  @override
  String get settingsKeptOnWhileLock =>
      'Reste activé tant que le verrouillage est activé.';

  @override
  String get lockFingerAfterPin =>
      'Saisissez votre code PIN une fois pour réutiliser votre empreinte.';

  @override
  String get pinsAdvanced => 'Protection avancée';

  @override
  String get pinsAdvancedLine =>
      'Pour le cas où quelqu’un vous force à déverrouiller votre téléphone.';

  @override
  String get pinsWipeLine =>
      'Tapé sur l’écran de verrouillage, il efface Kryfo de ce téléphone.';

  @override
  String get pinsDecoyPin => 'Code leurre';

  @override
  String get pinsDecoyLine => 'Ouvre un Kryfo vide, comme tout juste installé.';

  @override
  String get pinsSetADecoyPin => 'Définir un code leurre';

  @override
  String get pinsChangeDecoyPin => 'Changer le code leurre';

  @override
  String get pinsRemoveTheDecoyPin => 'Supprimer le code leurre ?';

  @override
  String get pinsTheDecoyGoes =>
      'Le Kryfo vide qu’il ouvre disparaît avec lui.';

  @override
  String get pinsTurnOffWithDecoy =>
      'Tous les codes disparaissent, et avec eux le leurre, son Kryfo et toutes les discussions masquées. Quiconque tient votre téléphone ouvre Kryfo comme si c’était vous.';

  @override
  String get pinsHowThisWorks => 'Comment ça marche';

  @override
  String get flowEnterYourPin => 'Saisissez votre code PIN';

  @override
  String get flowEnterYourPinLine => 'Celui qui ouvre Kryfo.';

  @override
  String get flowWipeTitle => 'Un code d’effacement';

  @override
  String get flowWipe1 =>
      'Tapé sur l’écran de verrouillage à la place de votre code PIN, il efface Kryfo de ce téléphone et le ferme. Pour qui regarde, l’app s’est simplement arrêtée.';

  @override
  String get flowWipe2 =>
      'Il emporte chaque discussion et votre identité, et le leurre si vous en avez un.';

  @override
  String get flowWipeChoose => 'Choisissez un code d’effacement';

  @override
  String get flowWipeDone => 'Code d’effacement défini';

  @override
  String get flowWipeDoneLine =>
      'Rien sur l’écran de verrouillage ne montre qu’il existe.';

  @override
  String get flowDecoyTitle => 'Un code leurre';

  @override
  String get flowDecoy1 => 'Ouvre un Kryfo vide, comme tout juste installé.';

  @override
  String get flowDecoyFinger =>
      'Votre empreinte ouvre votre vrai Kryfo. Si quelqu’un pouvait vous forcer à l’utiliser, désactivez l’empreinte.';

  @override
  String get flowDecoyDigits =>
      'Utilisez le même nombre de chiffres que votre code PIN, car quiconque regarde peut compter les points.';

  @override
  String get flowDecoyShade =>
      'Les notifications déjà dans le volet ont déjà été vues. Tant que le leurre est ouvert, aucune nouvelle ne s’affiche.';

  @override
  String get flowDecoyChoose => 'Choisissez un code leurre';

  @override
  String get flowDecoyDone => 'Code leurre défini';

  @override
  String get flowDecoyDoneLine =>
      'Tapez-le sur l’écran de verrouillage pour ouvrir le Kryfo vide. Pour en sortir, passez à une autre app et saisissez votre code PIN.';

  @override
  String get flowLaw =>
      'Dans certains pays, refuser de déverrouiller un téléphone ou cacher des données aux autorités est en soi une infraction. Renseignez-vous sur la loi là où vous voyagez.';

  @override
  String get howWipe =>
      'Tapé sur l’écran de verrouillage, le code d’effacement efface chaque discussion, votre identité et tout leurre, puis ferme Kryfo. Il fonctionne même quand le clavier est bloqué après des erreurs.';

  @override
  String get howDecoy =>
      'Le code leurre ouvre un second Kryfo, vide, avec ses propres trois mots. Les messages pour votre vrai Kryfo continuent d’arriver en dessous, sans bruit. Pour quitter le leurre, passez à une autre app et saisissez votre code PIN.';

  @override
  String get flowNotSet => 'Impossible de le définir. Réessayez.';

  @override
  String get pinsHiddenChats => 'Discussions masquées';

  @override
  String get pinsHiddenLine =>
      'Les discussions choisies restent hors de vue jusqu’à ce que vous saisissiez votre code des discussions masquées : absentes de la liste et de la recherche, sans notification.';

  @override
  String get pinsSetUp => 'Configurer';

  @override
  String get pinsChangeHiddenPin => 'Changer le code des discussions masquées';

  @override
  String get pinsHideMoreChats => 'Masquer d’autres discussions';

  @override
  String get pinsRemoveHiddenChats => 'Retirer les discussions masquées';

  @override
  String get pinsRemoveHiddenTitle => 'Retirer les discussions masquées ?';

  @override
  String get pinsRemoveHiddenLine =>
      'Elles reviennent dans votre liste de discussions, et le code des discussions masquées n’ouvre plus rien.';

  @override
  String get pinsTurnOffHiddenFirst =>
      'Les discussions masquées ont besoin du verrouillage. Retirez-les d’abord, et elles reviennent dans votre liste de discussions.';

  @override
  String get flowVaultTitle => 'Discussions masquées';

  @override
  String get flowVault1 =>
      'Choisissez des discussions et des groupes à masquer. Votre code PIN ouvre Kryfo sans eux. Un code des discussions masquées ouvre tout, discussions masquées comprises.';

  @override
  String get flowVault2 =>
      'Tant qu’elles sont hors de vue, elles n’envoient aucune notification et n’affichent aucune pastille. Leurs messages continuent d’arriver et attendent, scellés, votre code des discussions masquées.';

  @override
  String get flowVaultFinger =>
      'Votre empreinte ouvre Kryfo sans les discussions masquées.';

  @override
  String get flowVaultDigits =>
      'Donnez aussi six chiffres ou plus à votre code PIN, car quiconque regarde peut compter les points.';

  @override
  String get flowVaultReplace =>
      'Ceci remplace toutes les discussions masquées que ce téléphone contient déjà.';

  @override
  String get flowVaultChoose => 'Choisissez un code des discussions masquées';

  @override
  String get flowVaultChooseLine => 'Six chiffres ou plus.';

  @override
  String get flowEnterHiddenPinLine =>
      'Celui qui ouvre vos discussions masquées.';

  @override
  String get flowVaultForgetTitle => 'Retenez ce code';

  @override
  String get flowVaultForget =>
      'Si vous oubliez ce code, vos discussions masquées sont perdues pour de bon. Personne ne peut les récupérer, pas même nous.';

  @override
  String get flowVaultForgetOk => 'J’ai compris';

  @override
  String get flowVaultPickTitle => 'Choisissez les discussions à masquer';

  @override
  String get flowVaultPickLine =>
      'Elles quittent votre liste de discussions maintenant. Votre code des discussions masquées les fait réapparaître.';

  @override
  String flowVaultPickButton(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Masquer $countString discussions',
      one: 'Masquer $countString discussion',
      zero: 'Ne rien masquer pour l’instant',
    );
    return '$_temp0';
  }

  @override
  String get flowVaultPickEmpty =>
      'Aucune discussion à masquer pour l’instant.';

  @override
  String get flowVaultBackupTitle => 'Faire une sauvegarde maintenant ?';

  @override
  String get flowVaultBackupLine =>
      'Une sauvegarde faite maintenant contient aussi vos discussions masquées, sous sa propre phrase secrète. Si vous oubliez le code des discussions masquées, c’est le seul moyen de les retrouver.';

  @override
  String get flowVaultBackupNow => 'Faire une sauvegarde';

  @override
  String get flowVaultNotNow => 'Pas maintenant';

  @override
  String get flowVaultDone => 'Discussions masquées configurées';

  @override
  String get flowVaultDoneLine =>
      'Tapez votre code des discussions masquées sur l’écran de verrouillage pour les voir. Passez à une autre app, et elles sont de nouveau hors de vue.';

  @override
  String get flowVaultChanged => 'Code des discussions masquées changé';

  @override
  String get flowVaultChangedLine =>
      'Vos discussions masquées s’ouvrent avec le nouveau. L’ancien n’ouvre plus rien.';

  @override
  String get howVault =>
      'Votre code des discussions masquées ouvre Kryfo avec vos discussions masquées, votre code PIN et votre empreinte sans elles. Configurer à nouveau les discussions masquées remplace celles que ce téléphone contient. Si vous oubliez le code des discussions masquées, elles sont perdues pour de bon.';

  @override
  String get chatHide => 'Masquer la discussion';

  @override
  String get groupHide => 'Masquer le groupe';

  @override
  String get chatHidden => 'Masquée';

  @override
  String get chatHiddenToast => 'Masquée de votre liste de discussions';

  @override
  String get chatShowInList => 'Afficher dans la liste des discussions';

  @override
  String get stickerOpen => 'Stickers';

  @override
  String get stickerRecent => 'Récents';

  @override
  String stickerA11y(String emoji) {
    return 'Sticker $emoji';
  }

  @override
  String get stickerRemoveRecent => 'Retirer des récents';

  @override
  String get stickerCouldNotLoad => 'Impossible de charger les stickers';

  @override
  String get stickerLabel => 'Sticker';

  @override
  String get stickerNewer => 'D’un Kryfo plus récent';

  @override
  String get devLinkMismatch =>
      'Ce lien se présente comme Marios, mais sa clé ne correspond pas. Il n’a pas été ajouté.';

  @override
  String get devName => 'Marios';

  @override
  String get devRowTitle => 'Marios · a créé Kryfo';

  @override
  String get devWelcome =>
      'Bonjour, je suis Marios, je développe Kryfo. Dites-moi tout : bugs, idées, questions. Je lis tout.';

  @override
  String get devPinned => 'Intégré à Kryfo';

  @override
  String get devAnonymous => 'Anonyme';

  @override
  String get devAboutLine =>
      'La clé de Marios est intégrée à Kryfo. Chaque message de sa part est vérifié avec elle, donc personne d’autre ne peut écrire en son nom.';

  @override
  String get devKeyLabel => 'Sa clé';

  @override
  String get devDeleteLine =>
      'Tous les messages disparaissent, et la discussion ne reviendra pas.';

  @override
  String get devDeleteLineAnon =>
      'Tous les messages et le nom créé pour cette discussion disparaissent, et la discussion ne reviendra pas.';

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
  String get settingsWriteToMarios => 'Écrire à Marios';

  @override
  String get settingsWriteToMariosHint => 'Bugs, idées, questions';

  @override
  String get seenDevChat => 'La discussion avec Marios';

  @override
  String get seenDevChatCell => 'Si vous écrivez';

  @override
  String get seenDevChatLine =>
      'Rien tant que vous n’écrivez pas. Ensuite, ce que vous envoyez, et vos trois mots, sauf si vous écrivez anonymement.';

  @override
  String get devWriteAnonymously => 'Écrire anonymement';

  @override
  String get devUseMyWords => 'Utiliser mes trois mots';

  @override
  String get devWhoSeesWhat => 'Comment ça marche';

  @override
  String get devWhoWords =>
      'Avec vos trois mots, c’est une discussion comme les autres : Marios peut vous répondre, et votre visage et votre badge de soutien restent chez vous.';

  @override
  String get devWhoAnon =>
      'Si vous écrivez anonymement, Kryfo crée un nouveau nom et de nouvelles clés pour cette seule discussion. Ils restent sur ce téléphone et ne servent jamais ailleurs.';

  @override
  String get devWhoNothingYet =>
      'Rien ne quitte votre téléphone tant que vous n’avez pas envoyé votre premier message.';

  @override
  String get devWhoChoiceStays =>
      'Votre choix reste attaché à cette discussion.';

  @override
  String get devKeyCheckFailed =>
      'Impossible de vérifier la clé de Marios. Rien n’a été envoyé.';

  @override
  String get devLockLine =>
      'Marios les lira. Vous pourrez écrire davantage dès qu’il aura répondu.';

  @override
  String get devNewKey => 'Marios a une nouvelle clé';

  @override
  String get devStartNewChat => 'Commencer une nouvelle discussion';

  @override
  String get devKeyRetired =>
      'Cette clé a été retirée. Plus rien ne peut être envoyé ni reçu ici.';

  @override
  String get devNamelessLine =>
      'Le nom créé pour cette discussion reste sur le téléphone où il a été créé. Ici, la discussion ne peut qu’être lue.';

  @override
  String get devStartNewLine =>
      'Tous les messages d’ici disparaissent, et une nouvelle discussion s’ouvre.';

  @override
  String get devVoiceDisguised =>
      'Votre voix est déguisée dans cette discussion';

  @override
  String get devChatOptions => 'Options de la discussion';

  @override
  String appLinkOtherKey(Object id) {
    return 'Ce lien se présente comme $id, mais sa clé ne correspond pas. Il n’a pas été ajouté.';
  }

  @override
  String scamShieldSaysItIs(Object shown) {
    return 'Se présente comme $shown, mais sa clé ne correspond pas';
  }

  @override
  String get requestsSomeoneNew => 'Quelqu’un de nouveau';
}
