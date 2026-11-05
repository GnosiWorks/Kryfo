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
  String get accentYellow => 'Jaune';

  @override
  String get accentGrey => 'Gris';

  @override
  String get accentPurple => 'Violet';

  @override
  String get accentLime => 'Citron vert';

  @override
  String get accentVelvet => 'Velours';

  @override
  String get accentBlue => 'Bleu';

  @override
  String get appearancePreview =>
      'Aperçu de vos discussions dans cette couleur';

  @override
  String get appearanceSampleIn => 'Toujours d’accord pour ce soir ?';

  @override
  String get appearanceSampleOut => 'Oui. À huit heures, au même endroit.';

  @override
  String get appearanceSampleButton => 'Répondre';

  @override
  String get appearanceAccentHint =>
      'Les boutons, vos propres messages et les liens la portent. L’icône de l’appli reste jaune.';

  @override
  String get appearanceChatWallpaper => 'Fond des discussions';

  @override
  String get appearanceEveryChat => 'Toutes les discussions';

  @override
  String get appearanceWallpaperHint =>
      'Le fond propre à une discussion, choisi depuis son menu, passe en premier. Les photos restent sur ce téléphone, chiffrées avec vos discussions.';

  @override
  String get appearanceWallpaperHintDesk =>
      'Le fond propre à une discussion, choisi depuis son menu, passe en premier. Les photos restent sur cet ordinateur, chiffrées avec vos discussions.';

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
  String get backupTheRestoreStoppedPartway =>
      'La restauration s’est arrêtée en cours de route';

  @override
  String get backupCouldNotMakeThe => 'Impossible de créer la clé';

  @override
  String get contactCardMessageMeOn => 'Écrivez-moi sur';

  @override
  String get contactCardScanToAdd =>
      'Scannez-la avec Kryfo pour m’ajouter.\nCette carte ne sait rien d’autre de vous.';

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
  String get appNoRelayReached => 'Aucun relais joint';

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
  String get appAnAttachmentCouldNotDesk =>
      'Une pièce jointe n’a pas pu être enregistrée sur cet ordinateur';

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
  String appJoined(Object linkName) {
    return 'Vous avez rejoint $linkName';
  }

  @override
  String get roomJoinWaitingToJoin => 'En attente d’admission';

  @override
  String get roomJoinNotAnswering => 'Ne répond pas';

  @override
  String roomJoinWaitingFor(Object room) {
    return 'En attente que $room vous laisse entrer…';
  }

  @override
  String get roomJoinWaitingLine => 'Vous pourrez écrire ici dès votre entrée.';

  @override
  String get roomJoinNoAnswer => 'Ce salon ne répond pas.';

  @override
  String get roomJoinMayHaveEnded => 'Il est peut-être terminé.';

  @override
  String get roomJoinFullShort => 'Salon complet';

  @override
  String get roomJoinFull => 'Ce salon est complet.';

  @override
  String get roomJoinFullLine =>
      'Aucune place n’est libre pour l’instant. Réessayez plus tard ou demandez à la personne qui a partagé le lien.';

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
  String get appScanTheirCodeOrDesk =>
      'Collez ce qu’on vous a donné : un lien, un @pseudo ou un lien de salon.';

  @override
  String get appScanTheirCode => 'Scanner son code';

  @override
  String get appAKryfoLinkA => 'Un lien Kryfo, un lien de salon ou @name';

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
  String get appStartingTor30s => 'Démarrage de Tor (~30 s)...';

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
  String get appReadyToChatAddressFinishing =>
      'Prêt à discuter · adresse bientôt prête';

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
      'La première connexion prend une minute ou deux, le temps que Tor trace une route privée. Ensuite elle est gardée en cache, et Kryfo s’ouvre bien plus vite.';

  @override
  String get appTorNoRelayYet =>
      'Tor est lancé, mais aucun relais ne répond encore. Kryfo continue d’essayer, et les messages attendent ici qu’un relais réponde.';

  @override
  String get appRelayAndFastModes =>
      'Rapide se passe de Tor et va plus vite. Il est dans les réglages, sous vitesse et confidentialité, et dit ce qu’il coûte.';

  @override
  String get appOffline => 'Hors ligne';

  @override
  String get appTorOff => 'Tor désactivé';

  @override
  String get appTorReady => 'Tor prêt';

  @override
  String get appConnecting2 => 'Connexion';

  @override
  String get appWaitingForARelay => 'En attente d’un relais';

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
  String get miuiAutostartOpenSettings => 'Ouvrir les paramètres';

  @override
  String get miuiAutostartCouldnTOpenIt =>
      'Impossible de l’ouvrir. Cherchez démarrage automatique dans les paramètres du téléphone';

  @override
  String get batteryGuideHuawei =>
      'Huawei et Honor ferment les applis qu’ils gèrent eux-mêmes. Sur l’écran suivant, trouvez Kryfo, désactivez « Gérer automatiquement » et laissez activés le lancement automatique, le lancement secondaire et l’exécution en arrière-plan.';

  @override
  String get batteryGuideOppo =>
      'Oppo et Realme arrêtent les applis en arrière-plan. Sur l’écran suivant, trouvez Kryfo et autorisez le lancement automatique. Dans Batterie, autorisez aussi son activité en arrière-plan.';

  @override
  String get batteryGuideVivo =>
      'Vivo arrête les applis en arrière-plan. Sur l’écran suivant, trouvez Kryfo et autorisez son démarrage en arrière-plan. Dans Batterie, autorisez aussi une forte consommation en arrière-plan.';

  @override
  String get batteryGuideSamsung =>
      'Samsung met en veille les applis qu’il juge inutilisées. Sur l’écran suivant, ouvrez « Limites d’utilisation en arrière-plan » et ajoutez Kryfo aux « Applis jamais mises en veille ».';

  @override
  String get batteryGuideOnePlus =>
      'OnePlus arrête les applis en arrière-plan. Sur l’écran suivant, trouvez Kryfo et autorisez le lancement automatique. Dans Batterie, choisissez « Ne pas optimiser ».';

  @override
  String get batteryGuideXiaomiTitle => 'Gardez Kryfo actif';

  @override
  String get batteryGuideXiaomi =>
      'Xiaomi arrête les applis en arrière-plan, même avec le démarrage automatique activé. Pour continuer à recevoir les messages :';

  @override
  String get batteryGuideXiaomiStep1 =>
      'Démarrage automatique : activez-le pour Kryfo.';

  @override
  String get batteryGuideXiaomiStep2 =>
      'Économiseur de batterie : réglez Kryfo sur « Aucune restriction ».';

  @override
  String get batteryGuideXiaomiStep3 =>
      'Applis récentes : appuyez longuement sur Kryfo puis sur le cadenas, pour que « Tout effacer » et le nettoyage du téléphone le laissent tourner.';

  @override
  String get batteryGuideXiaomiAfter =>
      'Si votre téléphone arrête Kryfo malgré tout, rien n’arrive tant que vous ne l’ouvrez pas de nouveau.';

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
  String get notificationsSomeone => 'Quelqu\'un';

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
  String scamShieldGivesUsedName(Object shown) {
    return 'Se présente comme $shown, un nom que quelqu’un porte déjà ici';
  }

  @override
  String scamShieldWarning(Object noticed) {
    return '$noticed. N’envoyez ni argent ni code à des personnes que vous n’avez jamais rencontrées.';
  }

  @override
  String get scamShieldAsksForSecret =>
      'Demande un code, un code PIN ou des mots de récupération';

  @override
  String get scamShieldAsksForMoneyFast => 'Demande de l’argent dans l’urgence';

  @override
  String get scamShieldPromisesProfit => 'Promet des gains faciles';

  @override
  String get scamShieldClaimsSupport =>
      'Se présente comme Kryfo ou un service d’assistance';

  @override
  String get scamShieldDismiss => 'Masquer';

  @override
  String scamShieldNameMatchesYourContact(Object shown) {
    return 'Le nom correspond à votre contact $shown';
  }

  @override
  String get scamShieldLinksToALookalike =>
      'Renvoie vers une imitation d’un site connu';

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
      'La phrase secrète doit faire au moins 12 caractères';

  @override
  String get backupPassphrasesDonTMatch => 'Les phrases secrètes diffèrent';

  @override
  String get backupBackupSavedKeepThe =>
      'Sauvegarde enregistrée · gardez la phrase secrète en lieu sûr';

  @override
  String get backupKryfoBackup => 'Sauvegarde Kryfo';

  @override
  String get backupYourEncryptedKryfoBackup =>
      'Votre sauvegarde Kryfo chiffrée. Gardez ce fichier et votre phrase secrète en lieu sûr. Il faut les deux pour restaurer.';

  @override
  String get backupBackUpKryfo => 'Sauvegarder Kryfo';

  @override
  String get backupBackUp => 'Sauvegarder';

  @override
  String get backupACopyToKeep =>
      'Une copie à garder. Ce téléphone continue comme avant.';

  @override
  String get backupACopyToKeepDesk =>
      'Une copie à garder. Cet ordinateur continue comme avant.';

  @override
  String get backupMoveToAnotherDevice => 'Passer sur un autre appareil';

  @override
  String get backupTheFileTakesThis =>
      'Le fichier emporte cette identité. Dès qu’il est créé, ce téléphone s’arrête : plus rien de nouveau n’arrive ici, et rien de ce qui est envoyé d’ici n’atteint personne.';

  @override
  String get backupTheFileTakesThisDesk =>
      'Le fichier emporte cette identité. Dès qu’il est créé, cet ordinateur s’arrête : plus rien de nouveau n’arrive ici, et rien de ce qui est envoyé d’ici n’atteint personne.';

  @override
  String get backupOneEncryptedFileYour =>
      'Un seul fichier chiffré : votre identité, vos contacts, chaque message, et chaque photo, note vocale et fichier. Importez-le sur l’autre appareil avec la phrase secrète. D’ici là, vous pouvez encore changer d’avis et rester sur ce téléphone.';

  @override
  String get backupOneEncryptedFileYourIdentityYour =>
      'Un seul fichier chiffré : votre identité, vos contacts, chaque message, et chaque photo, note vocale et fichier présents sur ce téléphone en ce moment. Ce qui se dira après aujourd’hui n’y sera pas, alors refaites-en une quand ça compte. Pour restaurer, il vous faut le fichier et la phrase secrète, les deux.';

  @override
  String get backupOneEncryptedFileYourIdentityYourDesk =>
      'Un seul fichier chiffré : votre identité, vos contacts, chaque message, et chaque photo, note vocale et fichier présents sur cet ordinateur en ce moment. Ce qui se dira après aujourd’hui n’y sera pas, alors refaites-en une quand ça compte. Pour restaurer, il vous faut le fichier et la phrase secrète, les deux.';

  @override
  String get backupPassphrase => 'Phrase secrète';

  @override
  String get backupConfirmPassphrase => 'Confirmer la phrase secrète';

  @override
  String backupWriting(Object progress) {
    return 'Écriture… $progress';
  }

  @override
  String get backupSaveComesAfter =>
      'Une fois le fichier prêt, vous choisirez où l’enregistrer.';

  @override
  String get backupSaving => 'Enregistrement…';

  @override
  String backupSavedIn(String place) {
    return 'Sauvegarde enregistrée dans $place · gardez la phrase secrète en lieu sûr';
  }

  @override
  String get backupNotSaved =>
      'La sauvegarde n’a pas été enregistrée. Le fichier est toujours là.';

  @override
  String get backupNotSavedNoSpace =>
      'L’emplacement choisi n’avait pas assez d’espace. Le fichier est toujours là : choisissez un autre endroit ou libérez de l’espace.';

  @override
  String get backupShareInstead => 'Partager plutôt';

  @override
  String get backupSavedUnchecked =>
      'Sauvegarde enregistrée, mais Kryfo n’a pas pu vérifier la copie';

  @override
  String get backupHandedOver =>
      'Sauvegarde transmise à l’app choisie · vérifiez qu’elle est bien arrivée';

  @override
  String get backupMoveReachedTitle =>
      'Le fichier est-il arrivé sur votre nouveau téléphone ?';

  @override
  String get backupMoveReachedTitleDesk =>
      'Le fichier est-il arrivé sur votre nouvel appareil ?';

  @override
  String get backupMoveReachedLine =>
      'Gardez ce téléphone jusqu’à ce que vous ayez ouvert le fichier là-bas.';

  @override
  String get backupMoveReachedLineDesk =>
      'Gardez cet ordinateur jusqu’à ce que vous ayez ouvert le fichier là-bas.';

  @override
  String get backupFinishTheMove => 'Finaliser le changement d’appareil';

  @override
  String get backupNotYet => 'Pas encore';

  @override
  String get backupCreating => 'Création…';

  @override
  String get backupMakeTheFileAnd => 'Créer le fichier et partir';

  @override
  String get backupCreateBackup => 'Créer la sauvegarde';

  @override
  String get backupNotMade => 'La sauvegarde n’a pas pu être faite. Réessayez.';

  @override
  String get backupNoSpace =>
      'Il n’y a pas assez d’espace libre sur ce téléphone pour faire la sauvegarde. Libérez de l’espace et réessayez.';

  @override
  String get backupNoSpaceDesk =>
      'Il n’y a pas assez d’espace libre sur cet ordinateur pour faire la sauvegarde. Libérez de l’espace et réessayez.';

  @override
  String get backupHiddenNotIn => 'Les discussions masquées n’y sont pas.';

  @override
  String get backupHiddenIncluded => 'Vos discussions masquées y sont aussi.';

  @override
  String get backupMoveHiddenStay =>
      'Les discussions masquées restent sur ce téléphone et sont effacées avec lui.';

  @override
  String get backupMoveHiddenStayDesk =>
      'Les discussions masquées restent sur cet ordinateur et sont effacées avec lui.';

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
  String get bridgesConnected => 'Connecté';

  @override
  String get bridgesFromTheTorProject => 'Du Projet Tor';

  @override
  String get bridgesPasteFromClipboard => 'Coller depuis le presse-papiers';

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
  String get bridgesWhenYouAskFor =>
      'Quand vous demandez des ponts, le Projet Tor voit votre adresse IP. C’est normal : c’est ainsi que Tor Browser et toutes les applis Tor obtiennent des ponts, et tout ce que cela leur apprend, c’est que quelqu’un a demandé des ponts. Rien sur vos discussions.';

  @override
  String get cameraNoCameraOnThis => 'Pas de caméra sur ce téléphone';

  @override
  String get cameraCameraNotAvailable => 'Caméra indisponible';

  @override
  String get cameraCameraPermissionIsOff => 'Accès à la caméra refusé';

  @override
  String get cameraOpenSettings => 'Ouvrir les paramètres';

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
  String get cameraTooLongForA => 'Trop long pour un message · 50 Mo max';

  @override
  String get cameraNeverSavedToYour => 'Jamais enregistré dans vos photos';

  @override
  String get cameraNoExifNeverSaved =>
      'Pas d’EXIF, jamais enregistré dans vos photos';

  @override
  String get cameraRec => 'Enr';

  @override
  String get cameraSwitchCamera => 'Changer de caméra';

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
  String chatEarlierMessagesArrived(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString messages antérieurs reçus',
      one: '$countString message antérieur reçu',
    );
    return '$_temp0';
  }

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
      'Il sera supprimé des deux téléphones, sauf s’il a déjà été enregistré. C’est irréversible.';

  @override
  String get chatItDisappearsWithNoDesk =>
      'Il sera supprimé des deux appareils, sauf s’il a déjà été enregistré. C’est irréversible.';

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
  String get chatHowLongAfterReading =>
      'Combien de temps après leur lecture les messages disparaissent-ils ? Les vôtres comptent dès leur envoi.';

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
  String get chatGifFromPhoneDesk => 'Gif de l’ordinateur';

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
    return '$humanBytes · $wireEstimate par Tor';
  }

  @override
  String get chatBigFilesGoOut =>
      'Les gros fichiers partent en petits morceaux chiffrés, donc ça prend un moment. Gardez l’appli ouverte et l’envoi continue.';

  @override
  String get chatSendIt => 'Envoyer';

  @override
  String get chatCouldNotReadThat => 'Impossible de lire ce fichier';

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
  String get chatTorIsNotUp =>
      'Tor n’est pas encore connecté · pas d’aperçu du lien';

  @override
  String get chatCouldnTReachIt =>
      'Impossible d’atteindre la page · pas d’aperçu du lien';

  @override
  String get chatNoTitleCameBack =>
      'Cette page n’a pas de titre · pas d’aperçu du lien';

  @override
  String get chatCouldnTFetchIt => 'Impossible de charger l’aperçu';

  @override
  String get chatNoSignalSessionRe =>
      'Pas de session Signal. Appairez à nouveau';

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
  String get chatJustForYouNeverDesk =>
      'Juste pour vous. Jamais envoyée, elle ne quitte jamais cet ordinateur.';

  @override
  String get chatAQuietReminder => 'Un petit rappel…';

  @override
  String get chatNoteSaved => 'Note enregistrée';

  @override
  String get chatClearThisConversation => 'Vider cette discussion ?';

  @override
  String get chatEveryMessageHereIs =>
      'Chaque message ici est effacé de ce téléphone. Cela ne vide que votre copie. Cela ne touche pas à son appareil.';

  @override
  String get chatEveryMessageHereIsDesk =>
      'Chaque message ici est effacé de cet ordinateur. Cela ne vide que votre copie. Cela ne touche pas à son appareil.';

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
  String get chatTheNextPhotoYou =>
      'La prochaine photo que vous envoyez s’ouvre protégée · Kryfo en bloque les captures d’écran';

  @override
  String get chatPhotoProtectionOff => 'Protection photo désactivée';

  @override
  String get chatAcceptToReplyThey =>
      'Acceptez pour répondre. D’ici là, la personne ne peut envoyer qu’un message de plus.';

  @override
  String chatIntroducedYouAcceptTo(Object introducer) {
    return 'Présentés par $introducer. Acceptez pour répondre.';
  }

  @override
  String chatIntroducedYouSayHello(Object vouchNames) {
    return 'Présentés par $vouchNames. Dites bonjour. La personne a aussi reçu votre carte.';
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
  String get chatTheyMayNotKnow =>
      'Cette personne ne sait peut-être pas que vous avez accepté';

  @override
  String get chatYouBlockedThisContact => 'Vous avez bloqué ce contact';

  @override
  String get chatSupporter => 'Soutien';

  @override
  String get chatEncryptedDirect => 'Chiffré · direct';

  @override
  String get chatEncryptedOverTor => 'Chiffré · par Tor';

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
  String get chatSayHiSoThey => 'Dites bonjour pour qu\'on vous voie';

  @override
  String get chatTheyWonTKnow =>
      'Votre contact ne saura rien avant de recevoir votre premier message.';

  @override
  String get chatWave => 'Faire coucou';

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
  String get commonSend => 'Envoyer';

  @override
  String get chatNoPhotosInThis => 'Pas encore de photos dans cette discussion';

  @override
  String get chatHoldToRecord => 'Maintenez pour enregistrer un message vocal';

  @override
  String get chatSecurityCodeChanged => 'Code de sécurité modifié';

  @override
  String get chatCompareTitle => 'Comparez le numéro de sécurité';

  @override
  String chatCompareLine(Object peerName) {
    return 'Trois mots peuvent être copiés. Pour savoir que cette discussion est bien avec $peerName, comparez le numéro de sécurité avec cette personne, en personne ou lors d’un appel.';
  }

  @override
  String get chatCompareLater => 'Plus tard';

  @override
  String get chatCompareFolded => 'Numéro de sécurité pas encore comparé';

  @override
  String get chatCompareNow => 'Comparer';

  @override
  String get chatCompareDismiss => 'Masquer';

  @override
  String chatKeyHeldLine(Object peerName) {
    return 'Vous aviez vérifié $peerName. Rien n’est envoyé tant que vous ne vérifiez pas le nouveau numéro ou n’acceptez pas la nouvelle clé. Ses messages arrivent toujours.';
  }

  @override
  String get chatCheckTheNumber => 'Vérifier le numéro';

  @override
  String get chatAcceptNewKey => 'Accepter la nouvelle clé';

  @override
  String get chatAcceptNewKeyTitle => 'Accepter sa nouvelle clé ?';

  @override
  String chatAcceptNewKeyLine(Object peerName) {
    return 'Kryfo enverra alors vers la nouvelle clé sans vérification, et $peerName ne sera plus marqué comme vérifié. Vous pourrez le vérifier à nouveau à tout moment.';
  }

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
  String get cleanSamePicture => 'Même image';

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
  String get contactStaysOnThisPhoneDesk =>
      'Reste sur cet ordinateur. Ce contact ne le voit jamais.';

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
  String get contactMessagesAndContactGoneDesk =>
      'Messages et contact, supprimés de cet ordinateur';

  @override
  String get contactDeleteThisChat => 'Supprimer cette discussion ?';

  @override
  String get contactEveryMessageAndThe =>
      'Chaque message et le contact, supprimés de ce téléphone. Rien ne lui est envoyé.';

  @override
  String get contactEveryMessageAndTheDesk =>
      'Chaque message et le contact, supprimés de cet ordinateur. Rien ne lui est envoyé.';

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
      'Soutenez-le anonymement. Badge facultatif.\n*Chaque fonction de confidentialité est gratuite.*';

  @override
  String get donateAuditTitle => 'Aidez à financer un audit de sécurité';

  @override
  String get donateAuditLine =>
      'Les dons faits ici comptent pour un audit indépendant. Le rapport complet sera public.';

  @override
  String get donateCard => 'Carte';

  @override
  String get donateCardOneTime =>
      'Un don ponctuel dans votre navigateur. Vous choisissez le montant.';

  @override
  String get donateCardMarios =>
      'Les paiements par carte vont directement à Marios, le temps que notre hôte fiscal soit en place.';

  @override
  String get donateCardSeesName =>
      'La société de paiement voit votre nom. La crypto est l’option privée.';

  @override
  String get donateCardPay => 'Payer par carte';

  @override
  String get donateNoBitcoinCard => 'Pas de bitcoin ? Payer par carte';

  @override
  String get donateCardNoBadge =>
      'Les dons par carte ne débloquent pas de badge.';

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
  String get donateShowTheAddress => 'Afficher l\'adresse';

  @override
  String donateReviewAmount(String amount) {
    return '$amount en bitcoin';
  }

  @override
  String get donateWhatTheBadgeGives => 'Ce que le badge apporte';

  @override
  String get donateGivesMark =>
      'Une marque à côté de votre nom. Vous choisissez qui la voit, ou personne.';

  @override
  String get donateGivesReceipt =>
      'Un reçu signé gardé sur ce téléphone. Il prouve le badge, sans compte.';

  @override
  String get donateGivesReceiptDesk =>
      'Un reçu signé gardé sur cet ordinateur. Il prouve le badge, sans compte.';

  @override
  String get donateGivesFree =>
      'Toutes les fonctions de confidentialité restent gratuites, badge ou pas.';

  @override
  String get donateAddressOnTap =>
      'L\'adresse est créée quand vous touchez le bouton ci-dessous. Elle reste la vôtre pendant une heure : en revenant, vous retrouvez la même.';

  @override
  String get donateBitcoinBusy =>
      'Bitcoin est saturé pour le moment. Réessayez plus tard ou payez par carte.';

  @override
  String get donateBusyPlainAddress =>
      'Vous pouvez toujours envoyer du bitcoin à l\'adresse ci-dessous. Elle ne donne pas de badge.';

  @override
  String get donateSameAddressAgain =>
      'C\'est l\'adresse que vous avez ouverte tout à l\'heure. Si vous avez déjà envoyé, attendez ici.';

  @override
  String get donateReachingThePaymentService =>
      'Connexion au service de paiement par Tor…';

  @override
  String get donateThisCanTakeUp => 'Cela peut prendre une minute ou deux';

  @override
  String donateSThisCanTake(Object waited) {
    return '$waited s · cela peut prendre une minute ou deux';
  }

  @override
  String get donateUseTheAddressInstead => 'Utiliser plutôt l’adresse';

  @override
  String get donateThePaymentServiceIs =>
      'Le service de paiement est un service onion, et seul le mode Onion peut l’atteindre. Rien n’a été envoyé.';

  @override
  String get donateTorWasSlowTo =>
      'Tor a mis trop de temps à joindre le service de paiement. Vous pouvez donner à l’adresse ci-dessous. Votre badge ne se débloquera simplement pas tout seul. Réessayez plus tard pour le badge.';

  @override
  String get donateThePaymentServiceIsHavingTrouble =>
      'Le service de paiement a des soucis en ce moment. Vous pouvez quand même donner à l’adresse ci-dessous. Votre badge ne se débloquera simplement pas tout seul. Réessayez plus tard pour le badge.';

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
      'Cet écran se met à jour dès que votre paiement est vu.\nGardez-le ouvert. Rien n’est stocké, rien ne vous identifie.';

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
  String get donateNoWallet =>
      'Aucune app de ce téléphone n’ouvre les liens bitcoin. Copiez plutôt l’adresse.';

  @override
  String get donateChecking => 'Vérification…';

  @override
  String get donateNotSeenYet =>
      'Pas encore visible. Un paiement peut mettre quelques minutes à apparaître.';

  @override
  String get donatePaymentConfirmed => 'Paiement confirmé';

  @override
  String get donateThankYouForKeeping => 'Merci de garder Kryfo indépendant.';

  @override
  String donateVerifiedOnChainYou(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter':
          'Vérifié sur la chaîne. Vous voilà parmi les soutiens. Personne ne peut vous l’enlever.',
      'patron':
          'Vérifié sur la chaîne. Vous voilà parmi les mécènes. Personne ne peut vous l’enlever.',
      'guardian':
          'Vérifié sur la chaîne. Vous voilà parmi les gardiens. Personne ne peut vous l’enlever.',
      'other':
          'Vérifié sur la chaîne. Vous voilà parmi les soutiens. Personne ne peut vous l’enlever.',
    });
    return '$_temp0';
  }

  @override
  String donateVerifiedBadgeStays(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter':
          'Vérifié sur la chaîne. Merci de donner encore. Vous gardez votre badge de soutien.',
      'patron':
          'Vérifié sur la chaîne. Merci de donner encore. Vous gardez votre badge de mécène.',
      'guardian':
          'Vérifié sur la chaîne. Merci de donner encore. Vous gardez votre badge de gardien.',
      'other':
          'Vérifié sur la chaîne. Merci de donner encore. Vous gardez votre badge de soutien.',
    });
    return '$_temp0';
  }

  @override
  String get donateWearMyBadge => 'Porter mon badge';

  @override
  String get donateJustGladToHelp => 'Aider me suffit';

  @override
  String get gettingMessagesAlwaysOn => 'Toujours actif';

  @override
  String get gettingMessagesMostPrivate => 'Le plus privé';

  @override
  String get gettingMessagesMessagesArriveInstantlyNothing =>
      'Les messages arrivent tout de suite. Rien ne sort de Tor. Consomme le plus de batterie.';

  @override
  String get gettingMessagesArriveInstantlyFast =>
      'Sur Rapide, les messages arrivent tout de suite. Consomme le plus de batterie.';

  @override
  String get gettingMessagesCheckIns => 'Relevés';

  @override
  String get gettingMessagesLightest => 'Le plus léger';

  @override
  String get gettingMessagesKryfoLooksForMessages =>
      'Kryfo cherche les messages toutes les 15 minutes. Économe en batterie, mais les messages peuvent arriver en retard.';

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
  String get groupChatYou => 'Vous';

  @override
  String get groupChatVoiceMessage => 'Message vocal';

  @override
  String get groupChatQuotedPhoto => 'Photo';

  @override
  String get groupChatMessageUnavailable => 'Message indisponible';

  @override
  String get groupChatTorIsNotUp =>
      'Tor n’est pas encore connecté · pas d’aperçu du lien';

  @override
  String get groupChatCouldnTReachIt =>
      'Impossible d’atteindre la page · pas d’aperçu du lien';

  @override
  String get groupChatNoTitleCameBack =>
      'Cette page n’a pas de titre · pas d’aperçu du lien';

  @override
  String get groupChatCouldnTFetchIt => 'Impossible de charger l’aperçu';

  @override
  String get groupChatCamera => 'Caméra';

  @override
  String get groupChatGallery => 'Galerie';

  @override
  String get groupChatVideo => 'Vidéo';

  @override
  String get groupChatGifFromPhone => 'Gif du téléphone';

  @override
  String get groupChatGifFromPhoneDesk => 'Gif de l’ordinateur';

  @override
  String get groupChatFile => 'Fichier';

  @override
  String get groupChatCouldNotReadThat => 'Impossible de lire ce fichier';

  @override
  String get groupChatGifTooBig8 => 'Gif trop gros · 8 Mo max';

  @override
  String get groupChatCouldNotCleanThat => 'Impossible de nettoyer ce gif';

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
  String get groupChatNewMessagesDisappearOnceRead =>
      'Les nouveaux messages disparaissent ce délai après leur lecture. Les vôtres comptent dès leur envoi.';

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
      'Il sera supprimé des téléphones de tout le monde, sauf s’il a déjà été enregistré. C’est irréversible.';

  @override
  String get groupChatItDisappearsWithNoDesk =>
      'Il sera supprimé des appareils de tout le monde, sauf s’il a déjà été enregistré. C’est irréversible.';

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
  String get groupChatEveryoneHereReads =>
      'Tout le monde ici lit ce que vous écrivez.';

  @override
  String get groupChatNobodyHereYet => 'Personne n’est encore là.';

  @override
  String get groupChatShareTheRoomLink =>
      'Partagez le lien du salon. Qui le rejoint lit ce qui s’écrit à partir de ce moment.';

  @override
  String get groupChatNobodyToReadIt =>
      'Personne d’autre n’est là pour le lire.';

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
  String get groupChatSupporter => 'Soutien';

  @override
  String get groupChatEdited => 'Modifié';

  @override
  String get groupChatTapToRetry => '! Réessayer';

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
      other: 'Envoyé · $haveString sur $countString l’ont reçu',
      one: 'Envoyé · $haveString sur $countString l’a reçu',
      zero: 'Envoyé · en route',
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
      other: 'Envoyé · $countString ne l’ont pas reçu',
      one: 'Envoyé · $countString ne l’a pas reçu',
    );
    return '$_temp0';
  }

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
  String get groupInfoResetLink => 'Réinitialiser le lien';

  @override
  String get groupInfoResetTheRoomLink => 'Réinitialiser le lien du salon ?';

  @override
  String get groupInfoResetLinkLine =>
      'L’ancien lien ne fonctionnera plus. Les personnes dans le salon restent et reçoivent le nouveau lien.';

  @override
  String get groupInfoRemoveRoomLine =>
      'Cette personne peut revenir avec le lien du salon. Réinitialisez le lien pour la tenir à l’écart. Les personnes encore dans le salon reçoivent le nouveau.';

  @override
  String get groupInfoRemoveAndResetLink => 'Retirer et réinitialiser le lien';

  @override
  String get groupInfoCouldNotResetLink =>
      'Impossible de réinitialiser le lien';

  @override
  String get roomLinkNewLinkTheOld =>
      'Nouveau lien. L’ancien ne fonctionne plus.';

  @override
  String appGroupHoldsUpTo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Un groupe compte au plus $countString personnes',
      one: 'Un groupe compte au plus $countString personne',
    );
    return '$_temp0';
  }

  @override
  String get commonRemove => 'Retirer';

  @override
  String get groupInfoClearThisConversation => 'Vider cette discussion ?';

  @override
  String get groupInfoEveryMessageHereIs =>
      'Chaque message ici est effacé de ce téléphone. Cela ne vide que votre copie, les autres membres gardent la leur.';

  @override
  String get groupInfoEveryMessageHereIsDesk =>
      'Chaque message ici est effacé de cet ordinateur. Cela ne vide que votre copie, les autres membres gardent la leur.';

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
  String get groupInfoEverythingInItIsDesk =>
      'Tout ce qu’il contient est effacé de cet ordinateur maintenant, et la clé que vous utilisiez ici disparaît pour de bon.';

  @override
  String groupChatYouWereRemovedFrom(Object name) {
    return 'Vous ne faites plus partie de $name';
  }

  @override
  String get groupInfoLeaveGroupLine =>
      'Vous ne recevrez plus ses messages, et tout ce qu’il contient est effacé de ce téléphone.';

  @override
  String get groupInfoLeaveGroupLineDesk =>
      'Vous ne recevrez plus ses messages, et tout ce qu’il contient est effacé de cet ordinateur.';

  @override
  String get groupInfoLeaveGroupAdmin =>
      'Vous ne recevrez plus ses messages, et tout ce qu’il contient est effacé de ce téléphone. Vous en êtes l’admin. Après votre départ, personne ne pourra changer ses membres ni le renommer.';

  @override
  String get groupInfoLeaveGroupAdminDesk =>
      'Vous ne recevrez plus ses messages, et tout ce qu’il contient est effacé de cet ordinateur. Vous en êtes l’admin. Après votre départ, personne ne pourra changer ses membres ni le renommer.';

  @override
  String get groupInfoLeaveRoomMaker =>
      'Tout ce qu’il contient est effacé de ce téléphone maintenant, et la clé que vous utilisiez ici disparaît pour de bon. Vous avez créé ce salon, son lien ne laissera donc plus entrer personne.';

  @override
  String get groupInfoLeaveRoomMakerDesk =>
      'Tout ce qu’il contient est effacé de cet ordinateur maintenant, et la clé que vous utilisiez ici disparaît pour de bon. Vous avez créé ce salon, son lien ne laissera donc plus entrer personne.';

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
  String get handleHintName => 'name';

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
  String handleDeleteTitle(Object handle) {
    return 'Supprimer @$handle ?';
  }

  @override
  String get handleDeleteLine =>
      'Votre page publique disparaît et n’importe qui peut prendre le nom. Vos discussions restent telles quelles.';

  @override
  String get handleDeleteYes => 'Supprimer le pseudo';

  @override
  String get handleDeleting => 'Suppression…';

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
      'Quiconque le connaît peut demander à vous écrire. La page contient votre invitation et la ligne que vous avez écrite, rien d’autre, et ne garde aucune trace de qui la lit. Vous pouvez le supprimer quand vous voulez.';

  @override
  String handleIsNotYoursOn(Object handle) {
    return '@$handle n’est pas à vous sur ce téléphone';
  }

  @override
  String handleIsNotYoursOnDesk(Object handle) {
    return '@$handle n’est pas à vous sur cet ordinateur';
  }

  @override
  String handleTheRegistryHoldsIt(Object handle) {
    return 'Le registre le détient sous une autre clé, très probablement une identité que ce téléphone avait avant une restauration. Les gens qui ajoutent @$handle ne vous joignent pas. Il ne peut être ni libéré ni mis à jour d’ici. Choisissez un autre nom.';
  }

  @override
  String handleTheRegistryHoldsItDesk(Object handle) {
    return 'Le registre le détient sous une autre clé, très probablement une identité que cet ordinateur avait avant une restauration. Les gens qui ajoutent @$handle ne vous joignent pas. Il ne peut être ni libéré ni mis à jour d’ici. Choisissez un autre nom.';
  }

  @override
  String get handleForgetItOnThis => 'L’oublier sur ce téléphone';

  @override
  String get handleForgetItOnThisDesk => 'L’oublier sur cet ordinateur';

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
  String get homeKeepWaiting => 'Attendre encore';

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
  String get homeNoKryfosYet => 'Pas encore de Kryfos.';

  @override
  String get homeScanTheirCodeSend =>
      'Scannez son code, envoyez-lui un lien, ou tapez le @pseudo qu’on vous a donné.';

  @override
  String get homeScanTheirCodeSendDesk =>
      'Envoyez-lui un lien, ou tapez le @pseudo qu’on vous a donné.';

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
  String get homeMessagesAndContactGoneDesk =>
      'Messages et contact, supprimés de cet ordinateur';

  @override
  String get homeDeleteThisChat => 'Supprimer cette discussion ?';

  @override
  String homeEveryMessageWithGoes(Object c) {
    return 'Tous les messages avec $c disparaissent, et cette personne n’est plus un contact. Cela ne vide que ce téléphone. Sa copie reste chez elle. Si elle vous écrit à nouveau, ça arrive dans les demandes.';
  }

  @override
  String homeEveryMessageWithGoesDesk(Object c) {
    return 'Tous les messages avec $c disparaissent, et cette personne n’est plus un contact. Cela ne vide que cet ordinateur. Sa copie reste chez elle. Si elle vous écrit à nouveau, ça arrive dans les demandes.';
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
  String get homeOnlyOnThisPhoneDesk => 'Seulement sur cet ordinateur';

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
  String introduceIntroduced(Object b, Object c) {
    return '$b et $c ont maintenant la carte l’un de l’autre';
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
      'Un mot, comme « ma cousine » (facultatif)';

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
  String get keyVerificationNewNumber =>
      'Le code de sécurité a changé pendant que cette page était ouverte. Voici le nouveau numéro : comparez-le à nouveau.';

  @override
  String get keyVerificationKeyMoved =>
      'Le code de sécurité vient de changer. Comparez le nouveau numéro.';

  @override
  String keyVerificationNoKeyYet(Object peerName) {
    return 'Pas encore de clé de $peerName. Le numéro s’affichera ici dès que $peerName vous aura écrit.';
  }

  @override
  String keyVerificationWith(Object peerName) {
    return 'Avec $peerName';
  }

  @override
  String keyVerificationCompareAll(Object peerName) {
    return 'Comparez les 12 groupes avec $peerName, en personne ou lors d’un appel de confiance. Si chaque groupe correspond, personne ne s’est glissé entre vous et vos messages ne sont que pour vous deux.';
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
      'Vérifiez les majuscules et les espaces. Personne ne peut le réinitialiser.';

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
  String get linkNoAppOpens =>
      'Aucune application de ce téléphone n\'ouvre ce lien.';

  @override
  String get linkNoAppOpensDesk =>
      'Aucune application de cet ordinateur n\'ouvre ce lien.';

  @override
  String get placeStubLocation => 'Position';

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
      'Quiconque a le mot de passe peut l’ouvrir, dans Kryfo ou sur n’importe quel ordinateur avec l’outil gratuit age. Oubliez-le, et le fichier est perdu pour de bon. Personne ne peut le réinitialiser.';

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
  String get lockSetupTurningOn => 'Activation…';

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
  String get modesFast => 'Rapide';

  @override
  String get modesNotChanged => 'Le mode n’a pas changé. Réessayez.';

  @override
  String get modesSwitching => 'Changement…';

  @override
  String get modesSpeed => 'Vitesse';

  @override
  String get modesPrivacy => '& confidentialité';

  @override
  String get movedWipeThisPhone => 'Effacer Kryfo de ce téléphone ?';

  @override
  String get movedWipeThisPhoneDesk => 'Effacer Kryfo de cet ordinateur ?';

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
  String movedKryfoWillCloseNowDesk(Object myId) {
    return 'Kryfo va se fermer. Relancez-le pour l’ouvrir en tant que $myId.';
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
  String movedIsNowOnAnotherDesk(Object myId) {
    return '$myId est maintenant sur un autre appareil. Cet ordinateur peut encore afficher ce qu’il y avait ici, mais plus rien de nouveau n’y arrivera, et rien de ce que vous enverrez d’ici n’atteindra personne.';
  }

  @override
  String get movedKeepItToRead => 'Le garder pour lire';

  @override
  String get movedWipeThisPhone2 => 'Effacer Kryfo de ce téléphone';

  @override
  String get movedWipeThisPhone2Desk => 'Effacer Kryfo de cet ordinateur';

  @override
  String get movedIMNotMoving => 'Finalement, je ne pars pas';

  @override
  String get myKryfoAHandleIs3 =>
      'Un pseudo fait de 3 à 20 lettres, chiffres ou _';

  @override
  String get myKryfoInviteCopiedClearsIn =>
      'Invitation copiée · effacée dans 60 s';

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
  String get myKryfoPointYourPhonesAtDesk =>
      'L’autre personne scanne ce code avec son téléphone. Rien ne passe par un serveur.';

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
      'Le lien contient vos trois mots, votre adresse et les clés pour démarrer une discussion. Il fonctionne jusqu’à ce que vous le réinitialisiez dans les paramètres.';

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
  String get newGroupNeedsContacts => 'Les groupes se font avec vos contacts';

  @override
  String get newGroupAddSomeoneFirst =>
      'Ajoutez d’abord quelqu’un. Un salon n’a pas besoin de contacts : toute personne qui a son lien peut le rejoindre.';

  @override
  String get notesDeleteThisNote => 'Supprimer cette note ?';

  @override
  String get notesHoldHint =>
      'Maintenez une note pour la copier ou la supprimer.';

  @override
  String get notesMenu => 'Menu des notes';

  @override
  String get notesDeleteAll => 'Supprimer toutes les notes';

  @override
  String get notesDeleteAllTitle => 'Supprimer toutes les notes ?';

  @override
  String get notesDeleteAllLine =>
      'Toutes les notes de ce téléphone disparaissent, pour de bon.';

  @override
  String get notesDeleteAllLineDesk =>
      'Toutes les notes de cet ordinateur disparaissent, pour de bon.';

  @override
  String get notesDeleteAllYes => 'Tout supprimer';

  @override
  String get notesThisWeek => 'Cette semaine';

  @override
  String get notesShowMore => 'Afficher plus';

  @override
  String get notesShowLess => 'Afficher moins';

  @override
  String get notesGoneFromThisPhone =>
      'Elle est effacée de ce téléphone pour de bon.';

  @override
  String get notesGoneFromThisPhoneDesk =>
      'Elle est effacée de cet ordinateur pour de bon.';

  @override
  String get notesNoteToSelf => 'Note pour moi';

  @override
  String get notesOnlyOnThisPhone => 'Seulement sur ce téléphone';

  @override
  String get notesOnlyOnThisPhoneDesk => 'Seulement sur cet ordinateur';

  @override
  String get notesAQuietPlace => 'Un coin tranquille';

  @override
  String get notesJotAnythingDownIt =>
      'Notez ce que vous voulez. Ça reste sur ce téléphone et n’en sort jamais.';

  @override
  String get notesJotAnythingDownItDesk =>
      'Notez ce que vous voulez. Ça reste sur cet ordinateur et n’en sort jamais.';

  @override
  String get notesJotSomethingDown => 'Notez quelque chose…';

  @override
  String get notesExportNotes => 'Exporter les notes';

  @override
  String get notesExport => 'Exporter';

  @override
  String get notesExportWorking => 'Exportation…';

  @override
  String notesExportCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString notes, de la plus ancienne à la plus récente.',
      one: 'Une note, de la plus ancienne à la plus récente.',
    );
    return '$_temp0';
  }

  @override
  String get notesExportZip =>
      'Les photos et les notes vocales les accompagnent dans un zip.';

  @override
  String get notesExportText => 'Texte brut';

  @override
  String get notesExportTextLine => 'Un fichier .txt qui s’ouvre partout';

  @override
  String get notesExportMarkdown => 'Markdown';

  @override
  String get notesExportMarkdownLine =>
      'Un fichier .md avec des titres, pour les apps de notes';

  @override
  String get notesExportLock => 'Verrouiller avec une phrase secrète';

  @override
  String get notesExportLockLine =>
      'Ouvrez-le dans Outils avec « Ouvrir un fichier verrouillé », ou avec age sur un ordinateur';

  @override
  String get notesExportPlainTitle => 'Exporter sans phrase secrète ?';

  @override
  String get notesExportPlainLine =>
      'Quiconque obtient ce fichier peut le lire.';

  @override
  String get notesExportPlainYes => 'Exporter sans';

  @override
  String get notesExportKeepLock => 'Garder la phrase secrète';

  @override
  String get notesExportNotSaved =>
      'Les notes n’ont pas été enregistrées. Le fichier est toujours là.';

  @override
  String get notesExportGone =>
      'Le fichier a été effacé quand Kryfo s’est verrouillé. Exportez à nouveau pour en créer un autre.';

  @override
  String get notesExportHoldsInstaller =>
      'Cet export contient le fichier d’installation d’une appli, il ne peut donc pas être partagé. Enregistrez-le plutôt sur votre téléphone.';

  @override
  String get notesExportHoldsInstallerDesk =>
      'Cet export contient le fichier d’installation d’une appli, il ne peut donc pas être partagé. Enregistrez-le plutôt sur cet ordinateur.';

  @override
  String get notesExportSaved => 'Notes enregistrées';

  @override
  String notesExportSavedIn(String place) {
    return 'Notes enregistrées dans $place';
  }

  @override
  String get notesExportSavedUnchecked =>
      'Notes enregistrées, mais Kryfo n’a pas pu vérifier la copie';

  @override
  String get notesExportFailed =>
      'Impossible d’exporter les notes. Rien n’a été enregistré.';

  @override
  String get notesExportTooLarge =>
      'Trop volumineux pour l’export. Les photos et les notes vocales font 4 Go ou plus.';

  @override
  String get notesExportSubject => 'Notes Kryfo';

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
      '*Personne n’entre sans votre accord.* On ne peut vous trouver que si vous réservez un pseudo public. Les gens sont ajoutés à la main, dans les deux sens.';

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
  String get onboardingYourKryfoId => 'VOTRE NOM';

  @override
  String get onboardingGeneratedFromAKey =>
      'Généré à partir d’une clé qui ne vit que sur ce téléphone. *Personne d’autre n’a ces mots.*';

  @override
  String get onboardingGeneratedFromAKeyDesk =>
      'Généré à partir d’une clé qui ne vit que sur cet ordinateur. *Personne d’autre n’a ces mots.*';

  @override
  String get onboardingTryAnother => 'En essayer un autre';

  @override
  String get onboardingUseThisName => 'Prendre ce nom →';

  @override
  String get onboardingThreeWords => 'Trois mots. *Rien qu’à vous.*';

  @override
  String get onboardingContinue => 'Continuer →';

  @override
  String get onboardingKryfoBuildsAPrivateRouteBefore =>
      'Kryfo construit une route privée avant d’envoyer quoi que ce soit. Quand vous êtes hors ligne, les messages attendent et arrivent à votre retour.';

  @override
  String get onboardingYourIdentityLivesOn =>
      'Votre identité vit sur ce téléphone. Sauvegardez-la depuis les paramètres au moment qui vous convient.';

  @override
  String get onboardingYourIdentityLivesOnDesk =>
      'Votre identité vit sur cet ordinateur. Sauvegardez-la depuis les paramètres au moment qui vous convient.';

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
  String get onboardingEveryWayToAdd => 'Toutes les façons d’ajouter quelqu’un';

  @override
  String get onboardingShowYourCodeSend =>
      'Montrez votre code, envoyez-lui un lien, ou tapez le @pseudo qu’on vous a donné.';

  @override
  String get onboardingScanTheirs => 'Scanner le sien';

  @override
  String get onboardingPointTheCameraAt => 'Pointez la caméra vers son code';

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
  String get pairCodeLooking => 'Recherche…';

  @override
  String get pairCodeNothingThereYetTrying =>
      'Rien pour l’instant · nouvel essai';

  @override
  String get pairCodeNothingAtThatCode =>
      'Rien à ce code. Il a peut-être disparu, ou la personne ne l’a pas encore partagé.';

  @override
  String get pairCodeUnreached =>
      'Les relais n’ont pas répondu. Réessayez dans un instant.';

  @override
  String get fastRoomsWaitForTor =>
      'Les salons, les codes d’appairage et les premiers contacts passent toujours par Tor, même sur Rapide. Ils marchent dès que Tor est connecté.';

  @override
  String get pairCodeFailed => 'Ça n’a pas marché. Réessayez.';

  @override
  String get pairCodeAddThem => 'Ajouter';

  @override
  String get pairCodeKeyNumber => 'Numéro de clé';

  @override
  String get pairCodeNotAdded =>
      'Rien n’a été ajouté. Demandez un nouveau code.';

  @override
  String get pairCodeEightDigits => 'Huit chiffres';

  @override
  String get pairCodeTypeTheEightDigits =>
      'Tapez les huit chiffres qu’on vous a lus.';

  @override
  String get pairCodeOldCode =>
      'Ce code vient d’un Kryfo plus ancien. Les deux téléphones ont besoin de Kryfo 0.6 ou plus récent.';

  @override
  String get pairCodeOldCodeDesk =>
      'Ce code vient d’un Kryfo plus ancien. Les deux appareils ont besoin de Kryfo 0.6 ou plus récent.';

  @override
  String get pairCodeBothNeed06 =>
      'Les deux téléphones ont besoin de Kryfo 0.6 ou plus récent.';

  @override
  String get pairCodeBothNeed06Desk =>
      'Les deux appareils ont besoin de Kryfo 0.6 ou plus récent.';

  @override
  String get pairCodeWaitingForThem => 'En attente de l’autre personne…';

  @override
  String get pairCodeStillWaiting =>
      'Toujours en attente. Si son écran indique qu’un code erroné a été tapé, vérifiez les chiffres ensemble.';

  @override
  String get pairCodeUnanswered =>
      'Aucune réponse n’est arrivée. Vérifiez le code avec la personne et tapez-le à nouveau.';

  @override
  String get pairCodeTooManyTries =>
      'Ce code a été essayé trois fois. Demandez-en un nouveau.';

  @override
  String get pairCodeRanOut => 'Ce code a expiré. Demandez-en un nouveau.';

  @override
  String get pairCodeMatched =>
      'Le code correspond. Vous ajouter mutuellement ?';

  @override
  String get pairCodeNotThem => 'Ce n’est pas la bonne personne';

  @override
  String get pairCodePanelReadEightDigitsOut =>
      'Lisez huit chiffres à voix haute et vous vous ajoutez mutuellement. Rien d’autre n’a besoin de changer de mains.';

  @override
  String get pairCodePanelOrMakeACode => 'Ou créez un code à lire à voix haute';

  @override
  String get pairCodePanelTheyOpenKryfoEight =>
      'La personne ouvre Kryfo, touche Ajouter, choisit Code d’appairage et tape ces huit chiffres. Créez-en un nouveau pour la personne suivante.';

  @override
  String get pairCodePanelWrongTyped =>
      'Un code erroné a été tapé. Relisez-le lentement.';

  @override
  String get pairCodePanelThreeWrong =>
      'Un code erroné a été tapé trois fois, celui-ci ne fonctionne donc plus. Créez-en un nouveau.';

  @override
  String get pairCodePanelNotAdded =>
      'Rien n’a été ajouté. Créez un nouveau code quand la personne sera prête.';

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
  String get photoKnowsVideoCleaner => 'Nettoyeur de vidéos';

  @override
  String get photoKnowsPhotoCleaner => 'Nettoyeur de photos';

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
  String get pinsThePinGoesAndDesk =>
      'Le code PIN disparaît, et avec lui le code d’effacement et toutes les discussions masquées. Quiconque est devant votre ordinateur ouvre Kryfo comme si c’était vous.';

  @override
  String get pinsUnlockWithFingerprint => 'Déverrouiller par empreinte';

  @override
  String get pinsFingerOpensDecoy =>
      'Désactivé tant qu’un code leurre est défini : un doigt n’ouvre que le leurre.';

  @override
  String get pinsWipePin => 'Code d’effacement';

  @override
  String get pinsNeedsAPinFirst => 'Code PIN requis';

  @override
  String get pinsSet => 'Défini';

  @override
  String get pinsChangeWipePin => 'Changer le code d’effacement';

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
  String get profileKryfoId => 'Votre nom';

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
      'Votre lien tel que tapé · aucune redirection de pistage';

  @override
  String get qrText => 'Texte';

  @override
  String get qrStaysInTheCode =>
      'Reste dans le code · aucun serveur ne le garde';

  @override
  String get qrWiFi => 'Wi-Fi';

  @override
  String get qrMadeOnThisPhone =>
      'Créé sur ce téléphone · aucun site n’a vu le mot de passe';

  @override
  String get qrNetworkName => 'Nom du réseau';

  @override
  String get qrPassword => 'Mot de passe';

  @override
  String get qrContact => 'Contact';

  @override
  String get qrOnlyWhatYouType =>
      'Seulement ce que vous tapez · rien de vos contacts';

  @override
  String get qrName => 'Nom';

  @override
  String get qrPhone => 'Téléphone';

  @override
  String get qrEmail => 'E-mail';

  @override
  String get qrOpensTheirMailApp =>
      'Ouvre son appli mail · rien n’est envoyé d’ici';

  @override
  String get qrTo => 'À';

  @override
  String get qrSubject => 'Objet';

  @override
  String get qrANumberNothingElse => 'Un numéro · rien d’autre';

  @override
  String get qrNumber => 'Numéro';

  @override
  String get qrSms => 'SMS';

  @override
  String get qrOpensTheirMessagesApp =>
      'Ouvre son appli messages · rien n’est envoyé d’ici';

  @override
  String get qrMessage => 'Message';

  @override
  String get qrLocation => 'Position';

  @override
  String get qrCoordinatesOnlyNoMap =>
      'Coordonnées seulement · aucun service de cartes interrogé';

  @override
  String get qrLatitude => 'Latitude';

  @override
  String get qrLongitude => 'Longitude';

  @override
  String get qrBitcoin => 'Bitcoin';

  @override
  String get qrAddressAndAmountNo =>
      'Adresse et montant · aucun site de paiement entre les deux';

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
  String get requestsRequests => 'Demandes';

  @override
  String get requestsNoRequests => 'Aucune demande';

  @override
  String get requestsMessagesFromPeopleYou =>
      'Les messages de personnes que vous n’avez pas ajoutées arrivent d’abord ici.';

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
  String get restoreReplaceTheAccountOnDesk =>
      'Remplacer le compte sur cet ordinateur ?';

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
  String restoreTheRegistryDidNotDesk(Object mine) {
    return 'Le registre n’a pas répondu. Si vous continuez, @$mine restera lié à l’identité que cet ordinateur s’apprête à perdre. Quiconque l’ajoute écrira à personne, et le nom ne pourra plus être réservé. Mieux vaut vous connecter et réessayer une fois.';
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
  String restoreKryfoWillCloseNowDesk(Object haloId) {
    return 'Kryfo va se fermer. Relancez-le pour l’ouvrir en tant que $haloId.';
  }

  @override
  String get restorePrivacyKept =>
      'Vos paramètres de confidentialité reviennent avec la sauvegarde. Les codes PIN ne sont jamais transférés : définissez-les à nouveau dans Paramètres.';

  @override
  String get restoreCheckProtections =>
      'Les paramètres ne sont pas dans la sauvegarde. À la réouverture de Kryfo, vérifiez « Vos protections » dans Paramètres.';

  @override
  String get restoreReopenKryfo => 'Rouvrir Kryfo';

  @override
  String get restoreTheRestoreDidNot =>
      'La restauration n’a pas abouti. Rien n’a été modifié';

  @override
  String get restoreKryfoClosesRestoreAgain =>
      'Une partie de ce qui était ici est déjà remplacée. Kryfo va se fermer. Rouvrez-le et restaurez le fichier une nouvelle fois.';

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
  String get restoreAnythingSentToYouDesk =>
      'Tout ce qu’on vous a envoyé pendant que l’ancien appareil était éteint, jusqu’à quatorze jours après l’envoi.';

  @override
  String get restoreYourSupporterBadgeIf =>
      'Votre badge de soutien, si vous en avez un.';

  @override
  String get restoreWhatDoesnT => 'Ce qui ne suit pas';

  @override
  String get restoreTheOldPhoneStops =>
      'L’ancien téléphone cesse de recevoir dès que vous envoyez quoi que ce soit d’ici. Le premier message envoyé depuis cet appareil est le dernier que l’ancien téléphone peut suivre, et tout ce qui lui arrive ensuite y est illisible et ne vous attend pas ici non plus.';

  @override
  String get restoreTheOldPhoneStopsDesk =>
      'L’ancien appareil cesse de recevoir dès que vous envoyez quoi que ce soit d’ici. Le premier message envoyé depuis cet ordinateur est le dernier que l’ancien appareil peut suivre, et tout ce qui lui arrive ensuite y est illisible et ne vous attend pas ici non plus.';

  @override
  String get restoreIfThePhoneThis =>
      'Si le téléphone d’où vient ce fichier sert encore, arrêtez d’y utiliser Kryfo avant de continuer. Deux téléphones sur un même Kryfo perdent des messages des deux côtés.';

  @override
  String get restoreIfThePhoneThisDesk =>
      'Si l’appareil d’où vient ce fichier sert encore, arrêtez d’y utiliser Kryfo avant de continuer. Deux appareils sur un même Kryfo perdent des messages des deux côtés.';

  @override
  String get restoreNotificationsNeedSettingUp =>
      'Les notifications doivent être reconfigurées sur cet appareil.';

  @override
  String get restoreDeletedComeBack =>
      'Les discussions supprimées après cette sauvegarde reviennent avec elle, et ces contacts peuvent voir que vous avez de nouveau configuré Kryfo.';

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
  String get restoreABackupBringsBackDesk =>
      'Une sauvegarde ramène votre identité et vos contacts, ainsi que les messages présents sur l’appareil au moment de sa création. Ce qui s’est dit depuis n’y est pas.';

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
  String get restoreStopRestore => 'Arrêter la restauration';

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
  String get roomCreateARoomThatEndsDesk =>
      'Un salon qui prend fin. Chacun le rejoint avec une clé créée pour ce salon, et à la fin, il ne reste rien sur aucun appareil.';

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
  String roomCreateOffUpTo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Désactivée. Quiconque a le lien, jusqu’à $countString',
    );
    return '$_temp0';
  }

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
  String get savedChatGone => 'Cette discussion n’est plus sur ce téléphone';

  @override
  String get savedChatGoneDesk =>
      'Cette discussion n’est plus sur cet ordinateur';

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
      'Voici la liste, par mode d’envoi, points faibles compris. Touchez une ligne pour savoir pourquoi.';

  @override
  String get seenHonestAboutTheLast =>
      'Pour les dernières lignes, il y a le verrouillage, le code d’effacement et le stockage chiffré, et aucun outil ne vous sauve de quelqu’un qui tient votre téléphone ouvert. Le modèle de menace complet se trouve dans THREAT_MODEL.md, dans le dépôt, écrit selon LINDDUN. Le code est ouvert, vous pouvez donc tout vérifier vous-même.';

  @override
  String get seenHonestAboutTheLastDesk =>
      'Pour les dernières lignes, il y a le verrouillage, le code d’effacement et le stockage chiffré, et aucun outil ne vous sauve de quelqu’un assis devant votre ordinateur déverrouillé. Le modèle de menace complet se trouve dans THREAT_MODEL.md, dans le dépôt, écrit selon LINDDUN. Le code est ouvert, vous pouvez donc tout vérifier vous-même.';

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
      'Chaque discussion a sa propre adresse, dérivée des deux clés. Un relais voit des boîtes de dépôt sans lien entre elles, pas deux personnes qui se parlent. En Rapide, nos serveurs voient votre adresse IP sur les boîtes de dépôt que vous utilisez et, si les deux personnes d’une discussion sont en Rapide, que deux adresses IP partagent une boîte.';

  @override
  String get seenWhatYouSay => 'Ce que vous dites';

  @override
  String get seenEndToEndEncrypted =>
      'Chiffré de bout en bout avec le double ratchet de Signal, puis scellé une seconde fois dans un gift wrap. Nous ne pouvons pas le lire.';

  @override
  String get seenYourIpAddress => 'Votre adresse IP';

  @override
  String get seenYourContactGraph => 'Votre graphe de contacts';

  @override
  String get seenKryfoDoesNotScan =>
      'Kryfo ne scanne pas vos contacts. Aucun numéro de téléphone n’existe ici, donc aucun ne peut fuiter. En Rapide, nos serveurs pourraient en reconstituer une partie d’après les adresses IP qui partagent des boîtes. Ils n’en gardent aucune trace.';

  @override
  String get seenIntroducer => 'Qui présente';

  @override
  String get seenWhenAContactIntroduces =>
      'Quand un contact vous présente à quelqu’un, ce contact apprend que vous êtes maintenant en lien tous les deux. Personne d’autre. Le relais voit du texte chiffré, et aucun serveur ne voit jamais le graphe.';

  @override
  String get seenTheScamShield => 'Le bouclier anti-arnaque';

  @override
  String get seenScamShieldRequestsOnly =>
      'Tourne sur votre téléphone avec des règles livrées dans l’appli. Pas de réseau, pas de listes téléchargées. Il ne lit que les demandes de message d’inconnus, jamais ce qu’un contact ou un groupe vous envoie.';

  @override
  String get seenScamShieldRequestsOnlyDesk =>
      'Tourne sur votre ordinateur avec des règles livrées dans l’appli. Pas de réseau, pas de listes téléchargées. Il ne lit que les demandes de message d’inconnus, jamais ce qu’un contact ou un groupe vous envoie.';

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
      'Un aperçu est récupéré par l’expéditeur, par Tor, et voyage dans le message chiffré. Le téléphone qui reçoit ne fait aucune requête. Le site apprend que quelqu’un utilisant Tor a demandé une page, et rien d’autre. Aucune image n’est jamais chargée, et le lien d’un inconnu reste du texte brut.';

  @override
  String get seenAPreviewIsFetchedDesk =>
      'Un aperçu est récupéré par l’expéditeur, par Tor, et voyage dans le message chiffré. L’appareil qui reçoit ne fait aucune requête. Le site apprend que quelqu’un utilisant Tor a demandé une page, et rien d’autre. Aucune image n’est jamais chargée, et le lien d’un inconnu reste du texte brut.';

  @override
  String get seenASeizedUnlockedPhone => 'Un téléphone saisi déverrouillé';

  @override
  String get seenASeizedUnlockedPhoneDesk => 'Un ordinateur saisi déverrouillé';

  @override
  String get seenIfSomeoneHoldsYour =>
      'Si quelqu’un tient votre téléphone ouvert, il lit vos messages. Le verrouillage, le code d’effacement et le stockage chiffré aident avant ce moment, pas après.';

  @override
  String get seenIfSomeoneHoldsYourDesk =>
      'Si quelqu’un s’assoit devant votre ordinateur déverrouillé, il lit vos messages. Le verrouillage, le code d’effacement et le stockage chiffré aident avant ce moment, pas après.';

  @override
  String get seenTheCryptoItself => 'La cryptographie elle-même';

  @override
  String get seenTheRatchetAndStorage =>
      'Les couches ratchet et stockage sont standard. La couche qui les relie est la nôtre et personne d’indépendant ne l’a examinée. C’est un logiciel en alpha.';

  @override
  String get seenFast => 'Rapide';

  @override
  String get settingsWipeKryfo => 'Effacer Kryfo ?';

  @override
  String get settingsIdentityMessagesContactsAnd =>
      'Identité, messages, contacts et paramètres sur ce téléphone. Perdus pour de bon, sauf si vous avez une sauvegarde.';

  @override
  String get settingsIdentityMessagesContactsAndDesk =>
      'Identité, messages, contacts et paramètres sur cet ordinateur. Perdus pour de bon, sauf si vous avez une sauvegarde.';

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
  String get settingsTorRouting => 'Routage Tor';

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
  String get settingsOnion3Hops => 'Onion · 3 sauts';

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
  String get settingsScamShieldHint =>
      'Vérifié uniquement sur votre téléphone, rien n’en sort';

  @override
  String get settingsScamShieldHintDesk =>
      'Vérifié uniquement sur votre ordinateur, rien n’en sort';

  @override
  String get typingNow => 'Écrit';

  @override
  String get settingsTypingIndicator => 'Indicateur de saisie';

  @override
  String get settingsTypingIndicatorHint =>
      'Vous voyez tous les deux quand l’autre écrit. L’info part directement par Tor, jamais par un relais.';

  @override
  String get settingsTypingOnionOnly => 'Disponible sur la route Onion';

  @override
  String get settingsTypingBridgesOff =>
      'Désactivé tant que des ponts sont utilisés : quelqu’un qui surveille votre connexion pourrait recouper les signaux de saisie. Il revient tout seul quand les ponts sont coupés.';

  @override
  String get settingsLightTheme => 'Thème clair';

  @override
  String get settingsSameProtectionBrighter => 'Même protection, plus lumineux';

  @override
  String get settingsAppearance => 'Apparence';

  @override
  String get settingsAccentColour => 'Couleur d’accent';

  @override
  String get settingsColoursAndWallpaper => 'Couleurs et fond d’écran';

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
  String get settingsReportAnIssue => 'Signaler un problème';

  @override
  String get settingsReportInKryfo => 'Écrire dans Kryfo';

  @override
  String get settingsReportInKryfoSub =>
      'La discussion avec Marios. Vous pouvez écrire anonymement.';

  @override
  String get settingsReportByEmail => 'Envoyer un e-mail';

  @override
  String get settingsReportByEmailSub =>
      'gnosiworks@proton.me, depuis votre app de messagerie';

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
      'Pas d’audit indépendant. Alpha : bon pour tester, pas encore pour un usage à fort enjeu.';

  @override
  String get settingsFollowTitle => 'Suivre GnosiWorks (développeur)';

  @override
  String get settingsFollowBrowserNote =>
      'S’ouvre dans votre navigateur, hors de Kryfo.';

  @override
  String get settingsFollowOpen => 'Ouvrir';

  @override
  String settingsFollowOn(Object name) {
    return 'Suivre sur $name, hors de Kryfo';
  }

  @override
  String get settingsDangerZone => 'Zone de danger';

  @override
  String get settingsWipeKryfoFromThis => 'Effacer Kryfo de ce téléphone';

  @override
  String get settingsWipeKryfoFromThisDesk => 'Effacer Kryfo de cet ordinateur';

  @override
  String get toolsMoreTools => 'Plus d’outils';

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
  String get toolsPhotoCleaner => 'Nettoyeur de photos';

  @override
  String get toolsRemovesHiddenInfo =>
      'Supprime les infos cachées (métadonnées) comme le lieu, l’heure et le modèle de téléphone';

  @override
  String get toolsPickAPhotoAnd =>
      'Choisissez une photo ou une vidéo pour voir ce qu’elle révèle, puis retirez tout d’un seul geste. Vous pouvez aussi en partager une vers Kryfo depuis votre galerie.';

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
  String get transportNothingHereLeavesTheDesk =>
      'Rien ici ne quitte l’ordinateur. C’est le même état que celui dont le moteur se sert pour décider quoi faire.';

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
  String get transportWithNoContactsTheDesk =>
      'Sans contacts, l’appli ne s’abonne à aucune adresse de relais, donc aucun message ne peut vous parvenir. Ajoutez quelqu’un pour régler ça.';

  @override
  String get transportSendAnythingWaitingNow =>
      'Envoyer tout ce qui attend, maintenant';

  @override
  String get transportSending => 'Envoi…';

  @override
  String get transportNothingLeftWaiting => 'Plus rien en attente';

  @override
  String transportStillWaiting(Object count) {
    return 'Encore en attente : $count';
  }

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
  String get transportStopKilled => 'Arrêté de force par le système';

  @override
  String get transportStopLowMemory => 'Mémoire faible';

  @override
  String get transportStopCrashed => 'Plantage';

  @override
  String get transportStopNotResponding => 'Ne répondait pas';

  @override
  String get transportStopByYou => 'Arrêté par vous';

  @override
  String get transportStopByPhone => 'Arrêté par le téléphone';

  @override
  String get transportStopBySecurityApp => 'Arrêté par l’app de sécurité';

  @override
  String get transportStopUpdated => 'Mis à jour';

  @override
  String get transportStopBySystem => 'Arrêté par le système';

  @override
  String get transportStopTooMuch => 'Trop de ressources utilisées';

  @override
  String get transportStopPermission => 'Autorisation modifiée';

  @override
  String get transportStopClosedItself => 'Fermé de lui-même';

  @override
  String get transportStopOther => 'Arrêté';

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
  String get transportReconnects => 'Reconnexions';

  @override
  String get transportWhyNetwork => 'Changement de réseau';

  @override
  String get transportWhyHand => 'À la main';

  @override
  String get transportWhyRelays => 'Aucun relais n’a répondu';

  @override
  String get transportWhyStall => 'Démarrage bloqué';

  @override
  String get transportWhyTorOff => 'Tor était désactivé';

  @override
  String get transportWhyDialer => 'Aucun relais depuis 3 minutes';

  @override
  String get transportWhyOnion => 'Retour sur Onion';

  @override
  String get transportWhyBridges => 'Ponts changés';

  @override
  String get transportWhyAuto => 'Automatique';

  @override
  String get transportWhyOffline => 'Pas de réseau';

  @override
  String get transportWhyCircuits => 'Nouveaux circuits';

  @override
  String get transportWhyOther => 'Autre';

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
  String get wallpaperDefault => 'Par défaut';

  @override
  String get wallpaperNotSet =>
      'Le fond d’écran n’a pas été appliqué. Réessayez.';

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
  String get whyKryfoRoutedThroughTor => 'Acheminé par Tor';

  @override
  String get whyKryfoByDefaultEveryMessage =>
      'Par défaut, chaque message passe par Tor, une chaîne de relais. Personne, ni nous ni votre réseau, ne peut voir à qui vous parlez ni où vous êtes.';

  @override
  String get whyKryfoEndToEndEncrypted => 'Chiffré de bout en bout';

  @override
  String get whyKryfoMessagesAreSealedWith =>
      'Les messages sont scellés avec des clés que seuls vous et la personne à qui vous parlez détenez. Nous ne pouvons pas les lire.';

  @override
  String get whyKryfoNoServersHoldingYour =>
      'Aucun serveur ne détient votre vie';

  @override
  String get whyKryfoNoAccountNoPhone =>
      'Pas de compte, pas de numéro de téléphone, pas de serveur central qui stocke vos discussions. Elles vivent sur ce téléphone, chiffrées au repos.';

  @override
  String get whyKryfoNoAccountNoPhoneDesk =>
      'Pas de compte, pas de numéro de téléphone, pas de serveur central qui stocke vos discussions. Elles vivent sur cet ordinateur, chiffrées au repos.';

  @override
  String get whyKryfoNothingLeaks => 'Rien ne fuite';

  @override
  String get whyKryfoNoReceiptsTyping =>
      'Pas d’accusés de lecture, pas de liste de contacts envoyée. Le fait que vous écrivez ne s’affiche que chez la personne à qui vous écrivez, directement par Tor, jamais par un serveur. La plupart des applis laissent fuiter les métadonnées. Kryfo est conçu pour ne pas le faire.';

  @override
  String get whyKryfoVerifyItIsReally => 'Vérifiez son identité';

  @override
  String get whyKryfoCompareASafetyNumber =>
      'Comparez un numéro de sécurité en personne ou par un canal de confiance, pour savoir que personne ne se fait passer pour votre contact.';

  @override
  String get whyKryfoTheHonestPart => 'En toute franchise';

  @override
  String get whyKryfoKryfoIsPreAlpha =>
      'Kryfo est en alpha et n’a pas été audité. La cryptographie est réelle, mais aucun expert extérieur ne l’a encore vérifiée, alors ne comptez pas encore dessus si votre sécurité en dépend.';

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
  String get cleanerHdrLayer => 'Calque HDR';

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
  String get bootFailedKeysDidNotAnswer =>
      'Le stockage des clés de votre téléphone ne répond plus. Fermer puis rouvrir Kryfo règle généralement le problème.';

  @override
  String get bootFailedKeysDidNotAnswerDesk =>
      'Le stockage des clés de cet ordinateur ne répond plus. Fermer puis rouvrir Kryfo règle généralement le problème.';

  @override
  String get bootFailedCloseAndReopen => 'Fermer et rouvrir Kryfo';

  @override
  String get bootFailedStillStuck => 'Si un nouvel essai ne suffit pas';

  @override
  String get bootFailedRestoreBackup => 'Restaurer une sauvegarde';

  @override
  String get bootFailedStartFresh => 'Repartir de zéro';

  @override
  String get bootFailedStartFreshTitle => 'Repartir de zéro ?';

  @override
  String get bootFailedStartFreshLine =>
      'Cela efface tout ce que Kryfo garde sur ce téléphone : discussions, contacts, médias, discussions masquées et vos trois mots. Un fichier de sauvegarde enregistré ailleurs n’est pas touché.';

  @override
  String get bootFailedStartFreshLineDesk =>
      'Cela efface tout ce que Kryfo garde sur cet ordinateur : discussions, contacts, médias, discussions masquées et vos trois mots. Un fichier de sauvegarde enregistré ailleurs n’est pas touché.';

  @override
  String get bootFailedStartFreshNext => 'Continuer';

  @override
  String get bootFailedStartFreshSure => 'Tout effacer sur ce téléphone ?';

  @override
  String get bootFailedStartFreshSureDesk =>
      'Tout effacer sur cet ordinateur ?';

  @override
  String get bootFailedStartFreshSureLine =>
      'C’est irréversible. Kryfo se ferme et se rouvre comme une nouvelle installation.';

  @override
  String get bootFailedStartFreshYes => 'Effacer et repartir de zéro';

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
  String kryfoLinkTextYouAlreadyHave(Object who) {
    return 'Vous avez déjà $who';
  }

  @override
  String kryfoLinkTextSomeoneElse(Object who) {
    return 'Vous appelez $who quelqu’un de vos discussions. Ce lien vient de quelqu’un d’autre. Ne l’ajoutez que si vous savez d’où il vient.';
  }

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
  String get kryfoLinkTextBurnerRoom => 'Salon éphémère';

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
      'Vous rejoignez avec une clé créée pour ce salon. Personne à l’intérieur ne voit vos trois mots.';

  @override
  String get linkStubFetchedOverTorBy =>
      'Récupéré par Tor · par votre appareil';

  @override
  String get linkStubFetchedOverTorByTheirDevice =>
      'Récupéré par Tor · par son appareil';

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
  String get mediaBubblesPlaying => 'Lecture en cours';

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
  String get motionReadyToChat => 'Prêt à discuter';

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
      'On dit au réseau que vous êtes en ligne, sans révéler où.';

  @override
  String get motionYourIpIsHidden =>
      'Votre IP est masquée. Seuls ceux qui ont votre Kryfo peuvent vous joindre.';

  @override
  String get motionAddressFinishing =>
      'Les messages partent déjà via Tor. Votre adresse privée finit de se préparer en arrière-plan.';

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
  String get pairCodePanelWorking => 'En cours';

  @override
  String get pairCodePanelBurned =>
      'Ce code a disparu. Créez-en un nouveau quand la personne sera prête.';

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
  String previewStripFetchedOverTor(Object domainOf) {
    return '$domainOf · récupéré par Tor';
  }

  @override
  String get previewStripDropThePreview => 'Retirer l’aperçu';

  @override
  String get previewStripAddPreview => 'Ajouter l’aperçu';

  @override
  String get previewStripFetchingOverTor => 'Récupération par Tor…';

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
  String get torBootSplashMadeOnThisPhoneDesk =>
      'Créé sur cet ordinateur. Rien n’est envoyé nulle part.';

  @override
  String get torBootSplashFirstLaunchTakesA =>
      'Le premier lancement prend un moment · seulement au démarrage';

  @override
  String get torBootSplashTakingLonger =>
      'Cela prend plus de temps que d’habitude';

  @override
  String get torBootSplashHopEntry => 'Entrée';

  @override
  String get torBootSplashHopMiddle => 'Milieu';

  @override
  String get torBootSplashHopExit => 'Sortie';

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
  String get profileIdentity => 'Identité';

  @override
  String get avatarPickerShape => 'Forme';

  @override
  String get avatarPickerColour => 'Couleur';

  @override
  String get avatarPickerTurn => 'Rotation';

  @override
  String avatarPickerOption(String what, int n, int count) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$what, $nString sur $countString';
  }

  @override
  String get avatarPickerYourInitial => 'Votre initiale';

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
  String get bridgesFoundAVolunteer => 'Bénévole trouvé, connexion';

  @override
  String get bridgesScanABridgeCode => 'Scanner un code de pont';

  @override
  String get settingsBridgesForNetworksThat =>
      'Ponts, pour les réseaux qui bloquent Tor';

  @override
  String get bridgesCouldNotReachTheTor =>
      'Impossible de joindre le Projet Tor';

  @override
  String get torBootSplashConnect => 'Se connecter';

  @override
  String get bridgesOffline => 'Hors ligne';

  @override
  String get bridgesNothingGotThrough => 'Rien n’est passé';

  @override
  String get bridgesBridgeFromAFriend => 'Pont d’un proche';

  @override
  String get bridgesKryfoCanAskThe =>
      'Kryfo peut demander un pont au Projet Tor pour contourner le blocage.';

  @override
  String get bridgesNotNeededRightNow => 'Pas nécessaire pour l’instant';

  @override
  String get bridgesBuiltInBridges => 'Ponts intégrés';

  @override
  String get bridgesKryfoCanGetAround =>
      'Kryfo peut maintenant contourner les blocages de Tor';

  @override
  String get bridgesThatSNotABridge => 'Ce n’est pas une ligne de pont';

  @override
  String get transportBridgeError => 'Dernière erreur';

  @override
  String get bridgesDirect => 'Direct';

  @override
  String get bridgesAskingTheTorProject =>
      'Kryfo demande au Projet Tor ce qui marche ici…';

  @override
  String get bridgesNoneOfTheseAre =>
      'Aucune de ces lignes n’est une ligne de pont que Kryfo comprend.';

  @override
  String get bridgesAutomatic => 'Automatique';

  @override
  String get bridgesStraightToTor => 'Directement vers Tor, pas besoin de pont';

  @override
  String get bridgesKryfoConnectsAsSoon =>
      'Kryfo se connecte dès que vous êtes de nouveau en ligne.';

  @override
  String get bridgesMore => 'Plus';

  @override
  String bridgesTryingAnotherWayOf(String attempt, String attempts) {
    return 'Essai d’un autre moyen… ($attempt sur $attempts)';
  }

  @override
  String get bridgesLookingForAVolunteer => 'Recherche d’un bénévole';

  @override
  String get bridgesFastestWhereTorIsnt =>
      'Le plus rapide là où Tor n’est pas bloqué. Kryfo ne se connecte jamais en dehors de Tor.';

  @override
  String get transportBridgePhase => 'Phase';

  @override
  String get bridgesAsleepBetweenCheckIns => 'En veille entre deux relevés';

  @override
  String get bridgesThroughABridge => 'Par un pont';

  @override
  String get bridgesBuiltIn => 'intégré';

  @override
  String get bridgesPasteOrScanALineDesk =>
      'Collez une ligne donnée par une personne de confiance.';

  @override
  String get bridgesDetails => 'Détails';

  @override
  String get transportBridgeMode => 'Ponts';

  @override
  String get bridgesYourBridgeCouldNot => 'Votre pont n’a pas pu démarrer';

  @override
  String get bridgesKryfoStaysOfflineRather =>
      'Kryfo reste hors ligne plutôt que de se connecter sans lui.';

  @override
  String get bridgesSignInToThisWifi => 'Connectez-vous à ce Wi-Fi';

  @override
  String get bridgesThisNetworkWantsA =>
      'Ce réseau demande d’abord de vous identifier. Une fois que c’est fait, Kryfo se connecte.';

  @override
  String get bridgesThisNetworkWantsADesk =>
      'Ce réseau demande d’abord de vous identifier. Identifiez-vous depuis votre navigateur, ou vérifiez la connexion réseau de l’ordinateur. Une fois que c’est fait, Kryfo se connecte.';

  @override
  String get bridgesWaitingForWifiSignIn => 'En attente de connexion au Wi-Fi';

  @override
  String get bridgesOpenWifiSettings => 'Ouvrir les paramètres Wi-Fi';

  @override
  String get bridgesUsingBuiltIn => 'Via les ponts intégrés';

  @override
  String get bridgesUsingSnowflake => 'Via Snowflake';

  @override
  String get bridgesUsingTorProject => 'Via des ponts du Projet Tor';

  @override
  String get bridgesBridgeRemoved => 'Pont retiré';

  @override
  String get bridgesUndo => 'Annuler';

  @override
  String bridgesRemoveBridgeN(String n) {
    return 'Retirer le pont $n';
  }

  @override
  String get bridgesTurnOnAutomatic => 'Activer le mode automatique';

  @override
  String get bridgesPasteABridgeLine => 'Collez une ligne de pont';

  @override
  String get bridgesInUse => 'Utilisé';

  @override
  String get bridgesPasteTheLineThey =>
      'Collez la ligne qu’on vous a envoyée, ou scannez son code. Prenez les lignes de pont de personnes que vous connaissez.';

  @override
  String get bridgesYouReOnAMode =>
      'Votre mode n’utilise pas Tor. Ces choix s’appliqueront quand vous reviendrez à Tor.';

  @override
  String get bridgesPasteOrScanALine =>
      'Collez ou scannez une ligne donnée par une personne de confiance.';

  @override
  String get bridgesNothingYet => 'Rien pour l’instant';

  @override
  String get torBootSplashIfTorIsBlocked =>
      'Si Tor est bloqué ou surveillé là où vous êtes, Kryfo peut démarrer par un pont à la place.';

  @override
  String get bridgesScanACode => 'Scanner un code';

  @override
  String get bridgesSwitchToAutomatic => 'Passer en automatique';

  @override
  String get torBootSplashTorIsBlockedHere => 'Tor est bloqué ou surveillé ici';

  @override
  String get torBootSplashStartThroughABridge => 'Démarrer par un pont';

  @override
  String get torBootSplashNeverTriesTorPlainly =>
      'Ici, Kryfo n\'essaie jamais Tor directement. Il trouve un pont qui fonctionne, ou vous choisissez le vôtre à l\'étape suivante.';

  @override
  String get bridgesTryingAnotherWay => 'Essai d’un autre moyen…';

  @override
  String get bridgesFindingAWayIn => 'Recherche d’un moyen de connexion…';

  @override
  String get bridgesGoesThroughAVolunteer =>
      'Passe par l’ordinateur d’un bénévole. Difficile à bloquer, lent à démarrer.';

  @override
  String get bridgesTorSeemsBlocked => 'Tor semble bloqué sur ce réseau';

  @override
  String get bridgesTorIsBlockedOnThis => 'Tor est bloqué sur ce réseau';

  @override
  String bridgesKryfoCouldNotRead(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Kryfo n’a pas pu lire $countString de ces lignes',
      one: 'Kryfo n’a pas pu lire $countString de ces lignes',
    );
    return '$_temp0';
  }

  @override
  String get bridgesTorNoBridge => 'Tor, sans pont';

  @override
  String get bridgesKryfoFindsAWay =>
      'Kryfo trouve un moyen qui marche là où vous êtes.';

  @override
  String get bridgesThisBridgeIsnTGetting => 'Ce pont ne passe pas';

  @override
  String get bridgesBridgesTheTorProject =>
      'Ponts que le Projet Tor vous a donnés plus tôt.';

  @override
  String get bridgesConnectingDots => 'Connexion…';

  @override
  String get bridgesNotNow => 'Pas maintenant';

  @override
  String get bridgesObfs4BridgesThatCome =>
      'Ponts fournis avec Kryfo (obfs4). Rapides à essayer, souvent bloqués.';

  @override
  String get bridgesYourNetworkMayBe => 'Votre réseau est peut-être restreint';

  @override
  String get bridgesCheckingForMessages => 'Recherche de messages…';

  @override
  String get bridgesSavedLines => 'Lignes enregistrées';

  @override
  String get bridgesPasteTheLineTheyDesk =>
      'Collez la ligne qu’on vous a envoyée. Prenez les lignes de pont de personnes que vous connaissez.';

  @override
  String get bridgesFromAFriendLower => 'd’un proche';

  @override
  String get bridgesAlmostThere => 'On y est presque';

  @override
  String get bridgesUseThisBridge => 'Utiliser ce pont';

  @override
  String bridgesUseTheseBridges(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Utiliser ces $countString ponts',
    );
    return '$_temp0';
  }

  @override
  String get transportBridgeMethod => 'Méthode';

  @override
  String get bridgesPointAtTheBridge => 'Visez le code QR du pont';

  @override
  String get bridgesConnectingThroughYourBridge => 'Connexion par votre pont…';

  @override
  String get bridgesThisLineIsTooLong =>
      'Cette ligne est trop longue pour Tor.';

  @override
  String get bridgesAutomaticFindsAWay =>
      'Le mode Automatique trouve un moyen tout seul quand Tor est bloqué. Pour trouver un pont, Kryfo peut s’adresser au Projet Tor, avec votre accord.';

  @override
  String get bridgesFromTheTorProjectLower => 'du Projet Tor';

  @override
  String get bridgesBridgesGoDeadWithout =>
      'Les ponts peuvent cesser de marcher sans prévenir. Le mode Automatique peut trouver un autre moyen.';

  @override
  String get bridgesWhenTorIsBlockedAutomatic =>
      'Quand Tor est bloqué, le mode Automatique demande au Projet Tor ce qui marche dans votre pays.';

  @override
  String get bridgesPlainAdvice =>
      'Kryfo choisit les ponts automatiquement. Snowflake et WebTunnel fonctionnent presque partout. Si l’un ne se connecte pas, essayez-en un autre ou demandez une ligne de pont à un proche.';

  @override
  String get bridgesAskTorProject => 'Demander au Projet Tor';

  @override
  String get bridgesTooLongForTor => 'Trop longue pour Tor';

  @override
  String bridgesMethodFrom(String method, String from) {
    return '$method, $from';
  }

  @override
  String get bridgesKryfoCanTUseThis =>
      'Kryfo ne peut pas utiliser cette ligne';

  @override
  String get bridgesTryAutomatic => 'Essayer l’automatique';

  @override
  String get bridgesNoInternet => 'Pas d’internet';

  @override
  String get bridgesConnection => 'Connexion';

  @override
  String get bridgesGetABridge => 'Obtenir un pont';

  @override
  String get languageTitle => 'Langue';

  @override
  String get languageMatchPhone => 'Comme le téléphone';

  @override
  String get languageMatchPhoneDesk => 'Comme le système';

  @override
  String languageMatchPhoneValue(Object language) {
    return 'Comme le téléphone ($language)';
  }

  @override
  String languageMatchPhoneValueDesk(Object language) {
    return 'Comme le système ($language)';
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
  String get videoViewerCannotPlayDesk =>
      'Cet ordinateur ne peut pas lire cette vidéo ici.';

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
  String get languageNameHi => 'Hindi';

  @override
  String get languageNamePl => 'Polonais';

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
  String get searchIntroLineDesk =>
      'Noms, mots, photos, fichiers et liens. La recherche se fait sur cet ordinateur et n’envoie rien nulle part.';

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
  String get handleStillReaching =>
      'Le registre n’a pas encore répondu. Via Tor, cela peut prendre jusqu’à une minute.';

  @override
  String get handleSearchNeedsTor =>
      'La recherche de pseudo a besoin de Tor. En attendant, ajoutez par QR ou par lien.';

  @override
  String get handleCheckClock =>
      'Vérifiez la date et l’heure du téléphone, puis réessayez.';

  @override
  String get handleCheckClockDesk =>
      'Vérifiez la date et l’heure de l’ordinateur, puis réessayez.';

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
  String get lockFingerAfterPin =>
      'Saisissez votre code PIN une fois pour réutiliser votre empreinte.';

  @override
  String get lockFingerLockedOut =>
      'Trop d’essais avec votre empreinte. Utilisez votre code PIN, ou déverrouillez une fois votre téléphone avec son propre verrouillage d’écran pour réutiliser l’empreinte.';

  @override
  String get lockFingerRefused =>
      'Votre téléphone n’a pas conservé le déverrouillage par empreinte pour Kryfo, il est donc désactivé. Votre code PIN fonctionne toujours.';

  @override
  String get lockFingerTryAgain =>
      'Votre téléphone était occupé à ce moment-là. Réessayez avec votre empreinte ou utilisez votre code PIN.';

  @override
  String get pinsFingerRefused =>
      'Votre téléphone n’a pas accepté d’activer le déverrouillage par empreinte pour Kryfo. Votre code PIN fonctionne toujours.';

  @override
  String get pinsAdvanced => 'Protection avancée';

  @override
  String get pinsAdvancedLine =>
      'Pour le cas où quelqu’un vous force à déverrouiller votre téléphone.';

  @override
  String get pinsAdvancedLineDesk =>
      'Pour le cas où quelqu’un vous force à déverrouiller votre ordinateur.';

  @override
  String get pinsWipeLine =>
      'Tapé sur l’écran de verrouillage, il efface Kryfo de ce téléphone.';

  @override
  String get pinsWipeLineDesk =>
      'Tapé sur l’écran de verrouillage, il efface Kryfo de cet ordinateur.';

  @override
  String get pinsDecoyPin => 'Code leurre';

  @override
  String get pinsDecoyLine => 'Ouvre un Kryfo vide, comme tout juste installé.';

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
  String get pinsTurnOffWithDecoyDesk =>
      'Tous les codes disparaissent, et avec eux le leurre, son Kryfo et toutes les discussions masquées. Quiconque est devant votre ordinateur ouvre Kryfo comme si c’était vous.';

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
  String get flowWipe1Desk =>
      'Tapé sur l’écran de verrouillage à la place de votre code PIN, il efface Kryfo de cet ordinateur et le ferme. Pour qui regarde, l’app s’est simplement arrêtée.';

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
      'Tant qu’un code leurre est défini, cette app s’ouvre seulement avec votre code PIN. Si l’empreinte est activée dans le leurre, un doigt ouvre le leurre, jamais cette app.';

  @override
  String get flowDecoyDigits =>
      'Utilisez le même nombre de chiffres que votre code PIN, car quiconque regarde peut compter les points.';

  @override
  String get flowDecoyShade =>
      'Les notifications déjà dans le volet ont déjà été vues. Tant que le leurre est ouvert, aucune nouvelle ne s’affiche.';

  @override
  String get flowDecoyShadeDesk =>
      'Les notifications déjà à l’écran ont déjà été vues. Tant que le leurre est ouvert, aucune nouvelle ne s’affiche.';

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
  String get flowLawDesk =>
      'Dans certains pays, refuser de déverrouiller un appareil ou cacher des données aux autorités est en soi une infraction. Renseignez-vous sur la loi là où vous voyagez.';

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
  String get flowVaultReplaceDesk =>
      'Ceci remplace toutes les discussions masquées que cet ordinateur contient déjà.';

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
      'Si vous oubliez ce code, vos discussions masquées sont perdues pour de bon. Personne ne peut les récupérer.';

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
  String get howVaultDesk =>
      'Votre code des discussions masquées ouvre Kryfo avec vos discussions masquées, votre code PIN sans elles. Configurer à nouveau les discussions masquées remplace celles que cet ordinateur contient. Si vous oubliez le code des discussions masquées, elles sont perdues pour de bon.';

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
  String get timedMessageLabel => 'Message éphémère';

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
  String get devDeleteLineBack =>
      'Tous les messages disparaissent, et la discussion ne reviendra pas. Ce que vous avez envoyé est aussi retiré du téléphone de Marios.';

  @override
  String get devDeleteLineAnonBack =>
      'Tous les messages et le nom créé pour cette discussion disparaissent, et la discussion ne reviendra pas. Ce que vous avez envoyé est aussi retiré du téléphone de Marios.';

  @override
  String devDeleteNotTakenBack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages n’ont pas pu être retirés du téléphone de Marios',
      one: '$count message n’a pas pu être retiré du téléphone de Marios',
    );
    return '$_temp0';
  }

  @override
  String get devDeleteFailed =>
      'La discussion n’a pas pu être supprimée. Réessayez.';

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
  String get devWhoAnonDesk =>
      'Si vous écrivez anonymement, Kryfo crée un nouveau nom et de nouvelles clés pour cette seule discussion. Ils restent sur cet ordinateur et ne servent jamais ailleurs.';

  @override
  String get devWhoNothingYet =>
      'Rien ne quitte votre téléphone tant que vous n’avez pas envoyé votre premier message.';

  @override
  String get devWhoNothingYetDesk =>
      'Rien ne quitte votre ordinateur tant que vous n’avez pas envoyé votre premier message.';

  @override
  String get devWhoChoiceStays =>
      'Votre choix reste attaché à cette discussion.';

  @override
  String get devUpdateToWrite => 'Mettez Kryfo à jour pour écrire à Marios.';

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
  String get devNamelessLineDesk =>
      'Le nom créé pour cette discussion reste sur l’appareil où il a été créé. Ici, la discussion ne peut qu’être lue.';

  @override
  String get devStartNewLine =>
      'Tous les messages d’ici disparaissent, et une nouvelle discussion s’ouvre.';

  @override
  String get devVoiceDisguised =>
      'Votre voix est déguisée dans cette discussion';

  @override
  String get devChatOptions => 'Options de la discussion';

  @override
  String get requestsSomeoneNew => 'Quelqu’un de nouveau';

  @override
  String get nameTakenTitle => 'Quelqu’un d’autre utilise ces mots';

  @override
  String get nameTakenLine =>
      'Quelqu’un ici a reçu ces mots par une demande, une présentation ou un groupe, avec une autre clé, et personne ne les a vérifiés. Des mots peuvent être copiés. Si ce lien vient de la personne que vous connaissez, utilisez-le, puis comparez le numéro de sécurité avec elle.';

  @override
  String get nameTakenChatLine =>
      'Votre discussion sous ces mots vient d’une demande, d’une présentation ou d’un groupe, avec une autre clé, et personne ne l’a vérifiée. Des mots peuvent être copiés. Si ce lien vient de la personne que vous connaissez, utilisez-le : cette discussion est supprimée, et vous comparez le numéro de sécurité dans la nouvelle. Vous ne savez pas d’où vient le lien ? Gardez celui que vous avez.';

  @override
  String get nameTakenDeletedLine =>
      'Vous avez supprimé une discussion sous ces mots, qui utilisait une autre clé. Si ce lien vient de la personne que vous connaissez, utilisez-le, puis comparez le numéro de sécurité avec elle.';

  @override
  String get nameTakenTombLine =>
      'Vous avez retiré de ce téléphone quelqu’un sous ces mots, car ce n’était pas la personne annoncée. Si ce lien vient de la personne que vous connaissez, utilisez-le, puis comparez le numéro de sécurité avec elle.';

  @override
  String get nameTakenTombLineDesk =>
      'Vous avez retiré de cet ordinateur quelqu’un sous ces mots, car ce n’était pas la personne annoncée. Si ce lien vient de la personne que vous connaissez, utilisez-le, puis comparez le numéro de sécurité avec elle.';

  @override
  String get nameTakenUse => 'Utiliser ce lien';

  @override
  String get nameTakenKeep => 'Garder celui que j’ai';

  @override
  String get appYourOwnInvite =>
      'C’est votre propre invitation. Partagez-la avec quelqu’un d’autre pour vous connecter.';

  @override
  String appLinkNeedsUpdate(Object id) {
    return '$id doit mettre Kryfo à jour avant que vous puissiez vous ajouter.';
  }

  @override
  String appLinkWordsTaken(Object id) {
    return 'Quelqu’un ici s’appelle déjà $id, avec une autre clé. Comparez le numéro de sécurité avec cette personne pour savoir qui est qui. Rien n’a été ajouté.';
  }

  @override
  String appLinkWordsVerified(Object id) {
    return 'Vous avez vérifié $id avec une autre clé. Rien n’a été ajouté.';
  }

  @override
  String appTheyAreBlocked(Object id) {
    return 'Vous avez bloqué $id. Débloquez cette personne dans « Bloqués », dans les Paramètres, pour l’ajouter à nouveau.';
  }

  @override
  String get notThemNumbersDiffer => 'Les numéros sont différents';

  @override
  String get notThemLine =>
      'Si les numéros sont vraiment différents, quelqu’un d’autre utilise peut-être son nom ou se trouve entre vous.';

  @override
  String get notThemButton => 'Ce n’est pas cette personne';

  @override
  String get notThemSheetTitle => 'Retirer ce contact et bloquer sa clé ?';

  @override
  String get notThemSheetLine =>
      'La discussion, ses messages et ses fichiers disparaissent de ce téléphone. Seul un lien ou un code que vous ajoutez reprend ses trois mots. Comparez le numéro de sécurité avec la personne que vous ajoutez.';

  @override
  String get notThemSheetLineDesk =>
      'La discussion, ses messages et ses fichiers disparaissent de cet ordinateur. Seul un lien ou un code que vous ajoutez reprend ses trois mots. Comparez le numéro de sécurité avec la personne que vous ajoutez.';

  @override
  String get notThemRemove => 'Retirer et bloquer';

  @override
  String get notThemDone => 'Retiré, et sa clé est bloquée';

  @override
  String get groupAdminGoneLine =>
      'Son admin a été retiré de ce téléphone. Les changements du groupe ne vous parviennent plus.';

  @override
  String get groupAdminGoneLineDesk =>
      'Son admin a été retiré de cet ordinateur. Les changements du groupe ne vous parviennent plus.';

  @override
  String get blockedKey => 'Clé bloquée';

  @override
  String get appKeyBlocked =>
      'Vous avez bloqué cette clé. Débloquez-la dans « Bloqués », dans les Paramètres, pour l’ajouter.';

  @override
  String get devLinkGone =>
      'Vous avez supprimé la discussion avec Marios. Pour en commencer une nouvelle, touchez « Écrire à Marios » dans les Paramètres.';

  @override
  String lockTooManyTriesFor(Object left) {
    return 'Trop d’essais · $left';
  }

  @override
  String get gifBadge => 'GIF';

  @override
  String get gifPlay => 'Lire le GIF';

  @override
  String get gifSentInside => 'Envoyé dans votre message';

  @override
  String get gifOptInTitle => 'Cherchez des GIF, en privé';

  @override
  String get gifOptInLead =>
      'La recherche de GIF a besoin d’internet, elle reste donc désactivée jusqu’à ce que vous la vouliez.';

  @override
  String get gifOptInOverTor => 'Recherche via Tor';

  @override
  String get gifOptInThroughKryfo => 'Recherche via Kryfo';

  @override
  String get gifOptInAsksForYou =>
      'Le serveur de Kryfo interroge le service de GIF pour vous. Le service ne vous voit jamais, et le serveur ne garde aucune trace de vos recherches.';

  @override
  String get gifOptInAsksForYouFast =>
      'Le serveur de Kryfo interroge le service de GIF pour vous, donc le service ne vous voit jamais. Sur Rapide, notre serveur voit votre adresse IP pendant la recherche, et ne garde aucune trace ni d\'elle ni de vos recherches.';

  @override
  String get gifOptInLikeAPhoto =>
      'Le GIF voyage chiffré, comme une photo. Le téléphone de votre ami ne télécharge rien.';

  @override
  String get gifOptInOffWhenever => 'Désactivable à tout moment';

  @override
  String get gifOptInWhereToTurnOff =>
      'Paramètres, Confidentialité, Recherche de GIF. Les GIF de votre téléphone marchent toujours sans elle.';

  @override
  String get gifOptInWhereToTurnOffDesk =>
      'Paramètres, Confidentialité, Recherche de GIF. Les GIF de votre ordinateur marchent toujours sans elle.';

  @override
  String get gifTurnOn => 'Activer la recherche de GIF';

  @override
  String get gifNotNow => 'Pas maintenant';

  @override
  String gifAskOverTor(String brand) {
    return 'La recherche de GIF passe par le serveur de Kryfo via Tor. $brand ne vous voit jamais. L’activer ?';
  }

  @override
  String gifAskThroughKryfo(String brand) {
    return 'La recherche de GIF va directement au serveur de Kryfo, qui voit votre adresse IP sur Rapide. $brand ne vous voit jamais. L’activer ?';
  }

  @override
  String get gifAskTurnOn => 'Activer';

  @override
  String get gifSearchOff => 'La recherche de GIF est désactivée';

  @override
  String get gifSavedOnPhone =>
      'Les GIF enregistrés sur votre téléphone sont dans *Sur ce téléphone*.';

  @override
  String get gifSavedOnPhoneDesk =>
      'Les GIF enregistrés sur votre ordinateur sont dans *Sur cet ordinateur*.';

  @override
  String get gifTab => 'GIF';

  @override
  String get gifPhoneTab => 'Sur ce téléphone';

  @override
  String get gifPhoneTabDesk => 'Sur cet ordinateur';

  @override
  String get gifSearchHint => 'Chercher des GIF';

  @override
  String get gifClear => 'Effacer la recherche';

  @override
  String get gifServiceNeverSeesYou => 'Le service de GIF ne vous voit jamais';

  @override
  String get gifTrending => 'Tendances';

  @override
  String get gifOffline =>
      'Tor se connecte encore. Les GIF arrivent dès qu’il est prêt.';

  @override
  String get gifBusy =>
      'Trop de recherches en ce moment. Réessayez dans un instant.';

  @override
  String get gifUnreachable => 'Le service de GIF de Kryfo n’a pas répondu.';

  @override
  String get gifNothingFound => 'Aucun GIF trouvé. Essayez d’autres mots.';

  @override
  String get gifCouldNotLoadMore => 'Impossible d’en charger plus';

  @override
  String get gifLoading => 'Chargement des GIF';

  @override
  String get gifCouldNotGet => 'Impossible d’obtenir ce GIF. Réessayez.';

  @override
  String gifPoweredBy(String brand) {
    return 'Powered by $brand';
  }

  @override
  String gifNeverSeesYou(String brand) {
    return 'Recherché via Kryfo, $brand ne vous voit jamais.';
  }

  @override
  String gifTileA11y(String number) {
    return 'GIF $number';
  }

  @override
  String get gifPhoneLine =>
      'Les GIF enregistrés sur ce téléphone. Rien ne part en ligne.';

  @override
  String get gifPhoneLineDesk =>
      'Les GIF enregistrés sur cet ordinateur. Rien ne part en ligne.';

  @override
  String get gifPhoneChoose => 'Choisir un GIF';

  @override
  String get settingsGifSearch => 'Recherche de GIF';

  @override
  String get settingsGifSearchHint =>
      'Désactivée jusqu’à ce que vous l’activiez. Le serveur de Kryfo cherche pour vous, le service de GIF ne vous voit donc jamais.';

  @override
  String get shareChooseChat => 'Choisir une discussion';

  @override
  String get shareNoChats => 'Aucune discussion pour l’instant';

  @override
  String get shareNoOne => 'Personne avec qui partager';

  @override
  String get valveStillConnecting =>
      'Toujours en connexion… Vos messages partiront dès que la connexion sera revenue.';

  @override
  String get valveCouldNotReconnect =>
      'Kryfo n’a pas pu se reconnecter. Un redémarrage règle le problème et garde vos messages.';

  @override
  String get valveRestartKryfo => 'Redémarrer Kryfo';

  @override
  String get updateAvailable => 'Mise à jour disponible';

  @override
  String updateReady(String version) {
    return 'Kryfo $version est prêt à être téléchargé';
  }

  @override
  String get settingsCheckForUpdates => 'Rechercher les mises à jour';

  @override
  String get settingsCheckForUpdatesHint =>
      'Une fois par jour via Tor. Demande la dernière version à kryfo.app et n’envoie rien sur vous.';

  @override
  String get voiceDisguiseHere => 'Déguiser ma voix ici';

  @override
  String get chatBlockScreenshots => 'Bloquer les captures';

  @override
  String get chatShotsWhenTheyUpdate =>
      'Disponible quand la personne utilisera la dernière version de Kryfo sur un téléphone';

  @override
  String get chatShotsWhenTheyUpdateDesk =>
      'Disponible dans Kryfo pour Android';

  @override
  String get chatShotsBothPhones =>
      'Kryfo bloque les captures et l’enregistrement d’écran de cette discussion sur les deux téléphones, ainsi que la copie, le transfert et l’enregistrement des messages de l’autre. Il ne peut rien contre les applis autorisées à lire l’écran, ni contre un téléphone ou une appli modifiés pour le contourner.';

  @override
  String get chatShotsBlocksBoth =>
      'Bloque les captures et l’enregistrement d’écran sur les deux téléphones, ainsi que la copie, le transfert et l’enregistrement des messages de l’autre. Il ne peut rien contre les applis autorisées à lire l’écran, ni contre un téléphone ou une appli modifiés pour le contourner.';

  @override
  String get chatShotsBlockedHere =>
      'Kryfo bloque les captures dans cette discussion';

  @override
  String get chatShotsMenuNote =>
      'Copier, transférer et enregistrer ses messages est désactivé dans cette discussion';

  @override
  String get chatShotsKeptOpen =>
      'Ouvrir ses fichiers dans d’autres applis est désactivé dans cette discussion';

  @override
  String searchKeptMatches(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString résultats · ouvrez la discussion pour les voir',
      one: '$countString résultat · ouvrez la discussion pour le voir',
    );
    return '$_temp0';
  }

  @override
  String get savedKeptInChat =>
      'Enregistré dans une discussion qui bloque les captures · ouvrez-la pour le voir';

  @override
  String get roomShotsMenuNote =>
      'Copier, transférer et enregistrer les messages des autres est désactivé dans ce salon';

  @override
  String get roomShotsKeptOpen =>
      'Ouvrir les fichiers des autres dans d’autres applis est désactivé dans ce salon';

  @override
  String get chatShotsYouTurnedOn =>
      'Vous avez activé le blocage des captures. Copier, transférer et enregistrer les messages de l’autre est aussi désactivé.';

  @override
  String get chatShotsYouTurnedOff =>
      'Vous avez désactivé le blocage des captures';

  @override
  String get chatNowPostQuantum =>
      'Les messages de cette discussion utilisent désormais un chiffrement post-quantique';

  @override
  String chatShotsTheyTurnedOn(String name) {
    return '$name a activé le blocage des captures. Copier, transférer et enregistrer les messages de l’autre est aussi désactivé.';
  }

  @override
  String chatShotsTheyTurnedOff(String name) {
    return '$name a désactivé le blocage des captures';
  }

  @override
  String get roomShotsBlocked =>
      'Kryfo bloque les captures et l’enregistrement d’écran de ce salon sur chaque téléphone, ainsi que la copie, le transfert et l’enregistrement des messages des autres. Il ne peut rien contre les applis autorisées à lire l’écran, ni contre un téléphone ou une appli modifiés pour le contourner.';

  @override
  String get roomShotsBlockedDesk =>
      'Copier, transférer et enregistrer les messages des autres est désactivé dans ce salon. Kryfo pour Android y bloque aussi les captures et l’enregistrement d’écran.';

  @override
  String get roomShotsAlwaysOn =>
      'Toujours activé dans un salon, sur chaque téléphone';

  @override
  String get roomShotsAlwaysOnDesk =>
      'Toujours activé dans un salon, dans Kryfo pour Android';

  @override
  String get settingsPerChat => 'Par discussion';

  @override
  String get homeShotsPerChat =>
      'Le blocage des captures se règle maintenant par discussion.';

  @override
  String get homeShotsTurnOnForAll => 'L’activer pour toutes vos discussions ?';

  @override
  String get homeShotsTurnOn => 'Activer partout';

  @override
  String get homeShotsLeaveOff => 'Laisser désactivé';

  @override
  String get homeShotsTheySeeIt =>
      'Kryfo les bloque aussi sur l’autre téléphone, et copier, transférer ou enregistrer les messages de l’autre est désactivé. La personne verra que vous l’avez activé.';

  @override
  String homeShotsTurnedOn(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Kryfo bloque maintenant les captures dans $countString discussions',
      one: 'Kryfo bloque maintenant les captures dans $countString discussion',
    );
    return '$_temp0';
  }

  @override
  String get voiceDisguisedHere =>
      'Votre voix est déguisée dans cette discussion';

  @override
  String get voiceSlideUpToLock => 'Glissez vers le haut pour verrouiller';

  @override
  String get voiceStopRecording => 'Arrêter l’enregistrement';

  @override
  String get voiceDeleteNote => 'Supprimer la note vocale';

  @override
  String get voiceDisguised => 'Déguisée';

  @override
  String get voiceYourVoice => 'Votre voix';

  @override
  String get voiceDisguiseThisNote => 'Déguiser cette note';

  @override
  String get voiceNotDisguised =>
      'Cette note n’a pas pu être déguisée, elle n’a donc pas été envoyée';

  @override
  String get voiceNoRoom =>
      'Il n’y a pas assez d’espace libre sur ce téléphone. Libérez de l’espace, puis réessayez.';

  @override
  String get voiceNoRoomDesk =>
      'Il n’y a pas assez d’espace libre sur cet ordinateur. Libérez de l’espace, puis réessayez.';

  @override
  String get voiceNoRoomNotSent =>
      'Il n’y avait pas assez d’espace pour déguiser cette note, elle n’a donc pas été envoyée';

  @override
  String get voiceDisguising => 'Déguisement en cours';

  @override
  String get voiceLockedNotSent =>
      'Kryfo s’est verrouillé avant l’envoi de votre message vocal, il n’a donc pas été envoyé';

  @override
  String get voiceNotSent => 'Votre message vocal n’a pas été envoyé';

  @override
  String get settingsDisguiseByDefault => 'Déguiser ma voix par défaut';

  @override
  String get settingsDisguiseByDefaultHint =>
      'Chaque discussion peut le changer dans son menu';

  @override
  String get fileInstallerLine =>
      'C’est le fichier d’installation d’une appli. N’installez des applis que de personnes en qui vous avez confiance.';

  @override
  String get fileAppInstaller => 'Fichier d’installation d’appli';

  @override
  String get fileSaveToDevice => 'Enregistrer sur l’appareil';

  @override
  String get fileOpenHint => 'S’ouvre dans une autre appli';

  @override
  String get fileSaved => 'Enregistré';

  @override
  String fileSavedIn(String place) {
    return 'Enregistré dans $place';
  }

  @override
  String get fileSavedUnchecked =>
      'Enregistré, mais Kryfo n’a pas pu vérifier la copie';

  @override
  String get fileNotSaved => 'Impossible d’enregistrer le fichier';

  @override
  String get fileNotSavedNoSpace =>
      'Non enregistré : il n’y a pas assez d’espace à cet endroit';

  @override
  String fileTooBig(String size, String max) {
    return 'Ce fichier fait $size. Les fichiers peuvent faire jusqu’à $max.';
  }

  @override
  String get fileGoesAsItIs =>
      'Ce fichier part tel quel. Kryfo ne nettoie que les JPEG, PNG, WebP, HEIC, AVIF, GIF, MP4 et MOV.';

  @override
  String get fileRawPictureTitle => 'Envoyer cette image telle quelle ?';

  @override
  String get fileRawPictureLine =>
      'Cette image ne peut pas être nettoyée. Des détails comme le lieu de la prise de vue partent avec. Envoyez-la comme photo pour la nettoyer.';

  @override
  String get voiceStoppedAtLimit =>
      'Les messages vocaux s’arrêtent à 30 minutes. Écoutez-le, puis envoyez-le.';

  @override
  String get gettingMessagesHelperBody =>
      'Instantané et léger. Son serveur voit votre IP et quand arrivent les messages, jamais ce qu’ils disent.';

  @override
  String get gettingMessagesHelperUseOnion => 'Passer à Onion';

  @override
  String get gettingMessagesHelperSetUp => 'Configurer';

  @override
  String get gettingMessagesHelperNote =>
      'De faux réveils sont mêlés aux vrais, ce qui rend plus difficile pour le serveur de l’appli auxiliaire de savoir quand arrivent les vrais messages. Un serveur auxiliaire à vous indique son adresse à notre relais. Les discussions masquées, les salons au-delà des premiers, et de temps en temps un contact ordinaire, environ un mois sur cinq, attendent le relevé que Kryfo fait toujours toutes les 15 minutes.';

  @override
  String get gettingMessagesHelperOnionOnly => 'Disponible sur la route Onion';

  @override
  String get gettingMessagesHelperChecking => 'Vérification…';

  @override
  String get gettingMessagesHelperRelayNotYet =>
      'Notre relais ne le propose pas encore';

  @override
  String get helperSheetNeedTitle => 'Il vous faut une appli auxiliaire';

  @override
  String get helperSheetNeedLine =>
      'Une appli auxiliaire garde une connexion légère pour toutes vos applis et réveille Kryfo quand quelque chose arrive. Toute appli UnifiedPush convient, ntfy est un bon début.';

  @override
  String get helperSheetGetNtfy => 'Installer ntfy';

  @override
  String get helperSheetOtherApps => 'Autres applis auxiliaires';

  @override
  String get helperSheetPickTitle => 'Choisissez une appli auxiliaire';

  @override
  String get helperSheetPickLine =>
      'Kryfo lui demande seulement de réveiller l’appli. Vos messages ne passent jamais par elle.';

  @override
  String helperSheetSetUp(Object name) {
    return '$name est prêt';
  }

  @override
  String helperSheetNoAnswer(Object name) {
    return '$name n’a pas répondu. Réessayez.';
  }

  @override
  String get homeHelperGoneTitle => 'Votre appli auxiliaire a disparu';

  @override
  String get homeHelperGoneLine =>
      'Kryfo fait un relevé toutes les 15 minutes jusqu’à ce que vous choisissiez une autre façon.';

  @override
  String get homeHelperGoneChoose => 'Choisir une autre façon';

  @override
  String get homeHelperRelayTitle => 'Le relais ne réveille plus Kryfo';

  @override
  String get gettingMessagesHelperRefused =>
      'Notre relais n’accepte pas certaines inscriptions de ce téléphone pour le moment. Ces discussions arrivent avec le relevé toutes les 15 minutes, et Kryfo continue d’essayer. Choisir une autre appli auxiliaire ou un autre serveur peut aussi aider.';

  @override
  String albumLabel(Object count) {
    return 'Album, $count éléments';
  }

  @override
  String albumCounter(Object at, Object total) {
    return '$at sur $total';
  }

  @override
  String albumMore(Object count) {
    return '$count de plus';
  }

  @override
  String get albumOnItsWay => 'En route';

  @override
  String get albumQuoted => 'Album';

  @override
  String get albumUnsendTitle => 'Annuler l’envoi de cet album ?';

  @override
  String get mediaSendAddMore => 'En ajouter';

  @override
  String get mediaSendRemove => 'Retirer';

  @override
  String get mediaSendProtect => 'Protéger des captures d’écran';

  @override
  String get mediaSendProtectedOn =>
      'Protégées · les captures d’écran sont bloquées';

  @override
  String mediaSendUpTo(Object count) {
    return 'Jusqu’à $count à la fois';
  }

  @override
  String get mediaSendVideo => 'Envoyer la vidéo';

  @override
  String get requestSenderMediaLater =>
      'Les photos et les fichiers se débloquent dès qu’il vous accepte, pour votre sécurité à tous les deux.';

  @override
  String get requestReceiverMediaLater =>
      'Les photos et les fichiers se débloquent dès que vous l’acceptez, pour votre sécurité.';

  @override
  String get groupEndedYou => 'Vous avez mis fin à ce groupe';

  @override
  String groupEndedBy(Object name) {
    return '$name a mis fin à ce groupe';
  }

  @override
  String get groupEndedBar => 'Ce groupe est terminé';

  @override
  String get groupInfoEndGroup => 'Mettre fin au groupe';

  @override
  String get groupInfoEndThisGroup =>
      'Mettre fin à ce groupe pour tout le monde ?';

  @override
  String get groupInfoEndGroupLine =>
      'Il est supprimé pour tout le monde : ses messages et médias sont retirés du téléphone de chaque membre à jour.';

  @override
  String get groupInfoEndGroupLineDesk =>
      'Il est supprimé pour tout le monde : ses messages et médias sont retirés de l’appareil de chaque membre à jour.';

  @override
  String get groupInfoDeleteGroup => 'Supprimer le groupe';

  @override
  String get groupInfoDeleteThisGroup => 'Supprimer ce groupe ?';

  @override
  String get groupInfoDeleteGroupLine =>
      'Le groupe terminé disparaît de votre liste de discussions.';

  @override
  String get groupEndedOldNotice =>
      'J’ai mis fin à ce groupe, plus personne ne peut y écrire. Mettez Kryfo à jour pour le voir comme terminé.';

  @override
  String get groupInfoEndGroupDetail =>
      'Kryfo le retire du téléphone de chaque membre qui a la mise à jour.';

  @override
  String get groupInfoEndGroupDetailDesk =>
      'Kryfo le retire de l’appareil de chaque membre qui a la mise à jour.';

  @override
  String get translateAction => 'Traduire';

  @override
  String get translateShowOriginal => 'Voir l’original';

  @override
  String translateBarTo(Object language) {
    return 'Traduire · $language';
  }

  @override
  String get translateBarMore => 'Options de traduction';

  @override
  String translateBarNever(Object language) {
    return 'Ne plus proposer · $language';
  }

  @override
  String get translateBarHide => 'Masquer dans cette discussion';

  @override
  String get translateWorking => 'Traduction…';

  @override
  String get translateFailed => 'Traduction impossible';

  @override
  String translateFrom(Object language) {
    return 'Traduit · $language';
  }

  @override
  String get translateLangZh => 'Chinois';

  @override
  String translatePackTitle(Object language) {
    return 'Traduction sur ce téléphone : $language';
  }

  @override
  String translatePackTitleDesk(Object language) {
    return 'Traduction sur cet ordinateur : $language';
  }

  @override
  String translatePackLine(Object language, Object size) {
    return 'Les messages sont traduits sur ce téléphone et ne le quittent jamais. Il faut pour cela le pack de langue $language, environ $size, téléchargé une seule fois via Tor.';
  }

  @override
  String translatePackLineDesk(Object language, Object size) {
    return 'Les messages sont traduits sur cet ordinateur et ne le quittent jamais. Il faut pour cela le pack de langue $language, environ $size, téléchargé une seule fois via Tor.';
  }

  @override
  String get translatePackNoLib =>
      'La traduction ne fonctionne pas sur ce téléphone.';

  @override
  String get translatePackNoLibDesk =>
      'La traduction ne fonctionne pas sur cet ordinateur.';

  @override
  String translateDownload(Object size) {
    return 'Télécharger · environ $size';
  }

  @override
  String get translateDownloadAnyway => 'Télécharger quand même';

  @override
  String get translateResume => 'Reprendre le téléchargement';

  @override
  String translateProgress(Object done, Object total) {
    return '$done sur $total';
  }

  @override
  String get translateFinishing => 'Vérification des fichiers…';

  @override
  String translateInstalled(Object size) {
    return 'Sur ce téléphone · $size';
  }

  @override
  String translateInstalledDesk(Object size) {
    return 'Sur cet ordinateur · $size';
  }

  @override
  String get translateNeedsWifi =>
      'L’option « Wi-Fi uniquement » est activée et ce téléphone n’est pas en Wi-Fi.';

  @override
  String get translateNeedsWifiDesk =>
      'L’option « Wi-Fi uniquement » est activée et cet ordinateur n’est pas en Wi-Fi.';

  @override
  String get translateFailNoTor =>
      'Tor n’est pas encore connecté. Les packs se téléchargent uniquement via Tor, réessayez une fois la connexion établie.';

  @override
  String get translateFailNetwork =>
      'Le téléchargement s’est arrêté. Réessayez, il reprendra là où il s’était arrêté.';

  @override
  String get translateFailBadFile =>
      'Un fichier ne correspondait pas à ce qu’attend Kryfo, il a été supprimé. Réessayez.';

  @override
  String get translateFailNoEngine =>
      'Impossible de télécharger des packs de langue sur ce téléphone.';

  @override
  String get translateFailNoEngineDesk =>
      'Impossible de télécharger des packs de langue sur cet ordinateur.';

  @override
  String translatePaused(Object size) {
    return 'En pause · $size pour l’instant';
  }

  @override
  String get translateSettingsTitle => 'Traduction';

  @override
  String get translateSettingsRow => 'Traduire les messages';

  @override
  String get translateSettingsHint => 'Sur ce téléphone, jamais sur un serveur';

  @override
  String get translateSettingsHintDesk =>
      'Sur cet ordinateur, jamais sur un serveur';

  @override
  String get translatePacksSection => 'Packs de langue';

  @override
  String translatePackPair(Object language) {
    return '$language et anglais';
  }

  @override
  String translateNotDownloaded(Object size) {
    return 'Non téléchargé · environ $size';
  }

  @override
  String get translateDownloading => 'Téléchargement via Tor';

  @override
  String translateDeleteTitle(Object language) {
    return 'Supprimer le pack $language ?';
  }

  @override
  String translateDeleteLine(Object language) {
    return 'Les messages en $language ne pourront plus être traduits avant un nouveau téléchargement.';
  }

  @override
  String get translateLanguagesSection => 'Langues';

  @override
  String get translateMyLanguages => 'Langues que je lis';

  @override
  String get translateMyLanguagesHint =>
      'Les messages dans ces langues ne sont pas proposés à la traduction. La langue de l’app en fait toujours partie.';

  @override
  String get translateInto => 'Traduire vers';

  @override
  String get translateAppLanguage => 'La langue de l’app';

  @override
  String get translateBehaviourSection => 'Téléchargements et discussions';

  @override
  String get translateAutoDefault => 'Traduire les discussions automatiquement';

  @override
  String get translateAutoDefaultHint =>
      'Pour les discussions que vous n’avez pas réglées vous-même. Chaque discussion peut l’activer ou le désactiver.';

  @override
  String get translateWifiOnly => 'Télécharger les packs en Wi-Fi uniquement';

  @override
  String get translatePrivacyTitle => 'Ce qui reste privé';

  @override
  String get translatePrivacyNote =>
      'La traduction se fait sur ce téléphone. Aucun message n’est envoyé nulle part pour être traduit. Télécharger un pack indique à l’hébergeur de quel pack il s’agit. Il passe par Tor, l’hébergeur ne sait donc pas qui l’a demandé.';

  @override
  String get translatePrivacyNoteDesk =>
      'La traduction se fait sur cet ordinateur. Aucun message n’est envoyé nulle part pour être traduit. Télécharger un pack indique à l’hébergeur de quel pack il s’agit. Il passe par Tor, l’hébergeur ne sait donc pas qui l’a demandé.';

  @override
  String get translateAutoInChat => 'Traduire automatiquement';

  @override
  String get translateAutoInChatHint =>
      'Les messages dans d’autres langues s’affichent traduits. L’original est à portée de doigt.';

  @override
  String get translateAlwaysChat => 'Toujours traduire cette discussion';

  @override
  String translateNeverDone(Object language) {
    return 'Les messages restent tels quels · $language';
  }

  @override
  String get translateUndo => 'Annuler';

  @override
  String get translateNeverSection => 'Jamais proposées';

  @override
  String get translateOfferAgain => 'Proposer à nouveau';

  @override
  String get translateOnHint =>
      'Proposée sous les messages dans d’autres langues';

  @override
  String get translatePrivacyKept =>
      'Les traductions sont gardées chiffrées avec leur discussion sur ce téléphone et supprimées avec elle.';

  @override
  String get translatePrivacyKeptDesk =>
      'Les traductions sont gardées chiffrées avec leur discussion sur cet ordinateur et supprimées avec elle.';

  @override
  String get translateOffDeletes =>
      'Le désactiver supprime les traductions enregistrées.';

  @override
  String get bridgesNoneUntilOnion => 'Rien tant qu’Onion n’est pas activé';

  @override
  String get bridgesRelayThisNetworkSees =>
      'Rapide passe là où Tor est bloqué, mais ce réseau peut voir que vous vous connectez à Kryfo.';

  @override
  String get settingsLicences => 'Licences';

  @override
  String get settingsLicencesValue => 'Ce dont Kryfo est fait';

  @override
  String get licencesKryfoLine =>
      'Kryfo est un logiciel libre sous licence publique générale GNU, version 3 ou ultérieure. Chacun peut lire, modifier et partager son code.';

  @override
  String get licencesSourceCode => 'Code source';

  @override
  String get licencesSignalTitle => 'Protocole Signal';

  @override
  String licencesSignalLine(String version) {
    return 'Kryfo contient libsignal $version, conçu par Signal, sous licence publique générale GNU Affero, version 3. Son code source se trouve sur github.com/signalapp/libsignal et à côté de chaque version de Kryfo.';
  }

  @override
  String get licencesAgplText => 'GNU AGPL 3.0, texte intégral';

  @override
  String get licencesSignalSource => 'Code source de libsignal';

  @override
  String get licencesParts => 'Composants open source';

  @override
  String get licencesInSignal => 'Dans la bibliothèque Signal';

  @override
  String get licencesInApp => 'Dans l\'app';

  @override
  String licencesPartCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString composants',
      one: '$countString composant',
    );
    return '$_temp0';
  }

  @override
  String get licencesGplText => 'GNU GPL 3.0, texte intégral';

  @override
  String get licencesInEngine => 'Dans le moteur réseau';

  @override
  String get licencesLoadFailed => 'Chargement impossible';

  @override
  String get settingsCopyLinkHint => 'Copier le lien';

  @override
  String get motionNoRelayYet => 'PAS ENCORE DE RELAIS';

  @override
  String get motionTheRouteIsUp => 'La route est tracée';

  @override
  String get motionMessagesGoOnceARelay =>
      'Les messages partent dès qu’un relais répond par cette route.';

  @override
  String get motionOffline => 'HORS LIGNE';

  @override
  String get motionNoNetwork => 'Pas de réseau';

  @override
  String get motionTorPicksUpAgain =>
      'Rien ne part sans réseau. Tor reprend dès que le réseau revient.';

  @override
  String deliveryModeStateLast(String state, Object last) {
    return '$state · $last';
  }

  @override
  String homeWaitingState(int count, String state) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count en attente · $state',
    );
    return '$_temp0';
  }

  @override
  String get settingsIconAndNotifications => 'Icône et notifications';

  @override
  String iconSettingsValue(String icon) {
    return '$icon, notifications neutres';
  }

  @override
  String get iconSectionTitle => 'Icône de l’appli';

  @override
  String get iconHint =>
      'Votre écran d’accueil et votre liste d’applis affichent cette icône et ce nom à la place de Kryfo.';

  @override
  String get iconHintKryfo =>
      'Choisissez une icône et un nom ordinaires pour votre écran d’accueil et votre liste d’applis.';

  @override
  String get iconWhatChanges => 'Ce que cela change';

  @override
  String iconConfirmTitle(String name) {
    return 'Passer à l’icône $name ?';
  }

  @override
  String iconConfirmLine(String name) {
    return 'Kryfo se ferme puis se rouvre. Si l’icône quitte votre écran d’accueil, retrouvez $name parmi vos applis et replacez-la.';
  }

  @override
  String get iconConfirmButton => 'Changer d’icône';

  @override
  String get iconNoPinLine =>
      'Qui la touche voit Kryfo. Avec un code PIN pour l’appli, on voit à la place un pavé de code.';

  @override
  String get iconSetPin => 'Créer un code PIN';

  @override
  String iconChanged(String name) {
    return 'Icône changée pour $name';
  }

  @override
  String iconPreviewLabel(String name) {
    return 'Votre écran d’accueil affichera $name';
  }

  @override
  String iconButtonLabel(String name) {
    return '$name, icône de l’appli';
  }

  @override
  String get notifShowAll => 'Nom et message';

  @override
  String get notifShowNew => 'Seulement « Nouveau message »';

  @override
  String get notifShowPlain => 'Neutres';

  @override
  String get notifPlainHint =>
      'Pas de nom, pas de message, pas les couleurs de Kryfo. Une icône neutre et une ligne.';

  @override
  String get notifPlainLine => 'Du nouveau';

  @override
  String get notifPlainChannel => 'Alertes';

  @override
  String get notifHeaderLimit =>
      'Le haut de chaque notification indique toujours Kryfo. Android ne laisse pas une appli changer cela.';

  @override
  String get gettingMessagesWhatShows => 'Ce que montrent les notifications';

  @override
  String get iconSheetChangesTitle => 'Ce qui change';

  @override
  String get iconSheetChanges =>
      'L’icône et le nom sur votre écran d’accueil et dans votre liste d’applis, le menu de partage et la vue des applis ouvertes. Avec Neutres, ce que montrent les notifications.';

  @override
  String get iconSheetStaysTitle => 'Ce qui reste Kryfo';

  @override
  String get iconSheetStays =>
      'La ligne du haut de chaque notification, les pages de réglages et de batterie de votre téléphone, la boutique d’applis, et Kryfo lui-même quand quelqu’un l’ouvre.';

  @override
  String get iconSheetGlance =>
      'Cela résiste à un coup d’œil sur votre écran d’accueil. Cela ne cache pas Kryfo à quelqu’un qui parcourt les réglages de votre téléphone.';

  @override
  String get iconSheetPrivateSpace =>
      'Votre téléphone a peut-être sa propre façon de masquer des applis : l’espace privé, dans ses réglages.';

  @override
  String get iconSheetSecureFolder =>
      'Votre téléphone a peut-être sa propre façon de masquer des applis : le Dossier sécurisé, dans ses réglages.';

  @override
  String get iconSheetXiaomi =>
      'Votre téléphone a peut-être sa propre façon de masquer des applis : les applis masquées, dans ses réglages.';

  @override
  String get androidIconNotes => 'Notes';

  @override
  String get androidIconWeather => 'Météo';

  @override
  String get androidIconTasks => 'Tâches';

  @override
  String get androidIconNews => 'Actualités';

  @override
  String get androidServiceTitlePlain => 'Actif';

  @override
  String get lockStateUnlockPlain => 'Déverrouiller';

  @override
  String get iconSheetOthers =>
      'Les applis de votre téléphone peuvent toujours voir que Kryfo est installé, et les fenêtres et demandes d’Android peuvent afficher son nom.';

  @override
  String get iconSheetSaves =>
      'Tant qu’une icône neutre est active, les nouvelles photos, vidéos et fichiers sont enregistrés sous des noms ordinaires dans les dossiers habituels de votre téléphone. Ce qui est déjà enregistré reste où il est.';

  @override
  String get deliveryModeGooglePush => 'Push Google';

  @override
  String get deliveryModeGoogle => 'Google';

  @override
  String get notificationsLead =>
      'Comment les nouveaux messages arrivent sur ce téléphone, leur son et ce qu’ils montrent. Vous pouvez changer cela quand vous voulez.';

  @override
  String get notificationsLeadDesk =>
      'Comment les nouveaux messages arrivent sur cet ordinateur, leur son et ce qu’ils montrent. Vous pouvez changer cela quand vous voulez.';

  @override
  String get notificationsHowTheyReachYou =>
      'Comment les messages vous parviennent';

  @override
  String get notificationsRecommended => 'Recommandé';

  @override
  String get notificationsGoogleBody =>
      'Instantané et léger. Google peut voir quand votre téléphone est réveillé, jamais qui a écrit ni ce qui a été dit.';

  @override
  String get notificationsGoogleStarting => 'Activation…';

  @override
  String get notificationsGoogleNoStart =>
      'Le push Google n’a pas pu démarrer. Vérifiez la connexion et réessayez.';

  @override
  String get notificationsGoogleNote =>
      'De faux réveils sont mêlés aux vrais, ce qui rend plus difficile pour Google de savoir quand arrivent les vrais messages. Notre relais ne garde que des adresses qu’il ne peut pas relier entre elles. Le service de push tourne sur notre second serveur. Les deux serveurs ensemble pourraient les relier, et avec l’aide de Google à votre compte Google. En saisir un seul ne suffit pas, mais nous gérons les deux, donc nous le pourrions. Si cela compte pour vous, choisissez un autre moyen. Les discussions masquées, les salons au-delà des premiers, et de temps en temps un contact ordinaire, environ un mois sur cinq, attendent le relevé que Kryfo fait toujours toutes les 15 minutes.';

  @override
  String get notificationsGoogleRefused =>
      'Notre relais n’accepte pas certaines inscriptions de ce téléphone pour le moment. Ces discussions arrivent avec le relevé toutes les 15 minutes, et Kryfo continue d’essayer.';

  @override
  String get notificationsSoundAndVibration => 'Son et vibration';

  @override
  String get notificationsSoundHint => 'Dans les paramètres d’Android';

  @override
  String get notificationsEachShows => 'Chaque notification montre';

  @override
  String get notificationsBatteryTips => 'Conseils batterie';

  @override
  String get notificationsBatteryAllowed => 'Autorisé';

  @override
  String get notificationsBatteryNotYet => 'Non autorisé';

  @override
  String get notificationsMakerSwitch => 'L’interrupteur du fabricant';

  @override
  String get onboardingDeliveryHeadline =>
      'Comment les messages *vous parviennent*.';

  @override
  String get onboardingDeliveryLead =>
      'Vous pouvez changer cela à tout moment dans Notifications.';

  @override
  String get homeGoogleTitle => 'Le push Google est là';

  @override
  String get homeGoogleLine =>
      'Instantané et doux pour la batterie. Google peut voir quand votre téléphone est réveillé, jamais qui a écrit ni ce qui a été dit.';

  @override
  String get homeGoogleUse => 'L’utiliser';

  @override
  String get homeGoogleOn => 'Le push Google est activé';

  @override
  String get homeGoogleGoneTitle => 'Le push Google n’est pas disponible';

  @override
  String get appNotificationsLink => 'Notifications →';

  @override
  String devGooglePushes(int got, int low) {
    return 'Push Google $got · rétrogradés $low';
  }

  @override
  String get passFieldLabel => 'Phrase secrète';

  @override
  String get padUseLetters => 'Utiliser des lettres';

  @override
  String get padUseDigits => 'Utiliser des chiffres';

  @override
  String get passWeak => 'Faible';

  @override
  String get passFair => 'Correcte';

  @override
  String get passStrong => 'Forte';

  @override
  String passStrengthIs(Object level) {
    return 'Solidité : $level';
  }

  @override
  String get lockKeyBusy =>
      'La puce de sécurité du téléphone est occupée. Réessayez dans un instant.';

  @override
  String get lockKeyLocked =>
      'Déverrouillez une fois votre téléphone avec son propre code PIN, puis réessayez.';

  @override
  String get lockKeyWaiting =>
      'La puce de sécurité du téléphone vérifie encore';

  @override
  String get lockKeyLost =>
      'Ce téléphone a perdu la clé qui vérifie vos codes PIN, certains codes PIN risquent donc de ne pas ouvrir. Vous pouvez réinitialiser Kryfo et restaurer une sauvegarde.';

  @override
  String get lockKeyReset => 'Réinitialiser Kryfo';

  @override
  String get lockKeyResetTitle => 'Réinitialiser Kryfo ?';

  @override
  String get lockKeyResetLine =>
      'Tout ce que Kryfo contient sur ce téléphone est effacé et Kryfo se ferme. Vous pourrez ensuite restaurer une sauvegarde. Les discussions masquées ne reviennent que d’une sauvegarde faite pendant qu’elles étaient ouvertes.';

  @override
  String get lockKeyResetSureTitle => 'Impossible de revenir en arrière';

  @override
  String get lockKeyResetSureLine =>
      'Toutes les discussions, clés et réglages de Kryfo sur ce téléphone disparaissent maintenant.';

  @override
  String get lockKeyResetSure => 'Tout effacer';

  @override
  String get flowVaultPassLine =>
      'Au moins 12 caractères. Le clavier du téléphone voit ce que vous tapez : choisissez-en un qui n’apprend ni ne synchronise les mots.';

  @override
  String get flowVaultPassLineDesk =>
      'Au moins 12 caractères. Choisissez-en une que vous n’utilisez nulle part ailleurs.';

  @override
  String get flowVaultPassAgain => 'La même phrase secrète encore une fois';

  @override
  String get cardTitle => 'Terminer la mise à jour de sécurité';

  @override
  String get cardLine =>
      'Si vous utilisez d’autres codes PIN, tapez-les une fois ici.';

  @override
  String get cardType => 'Taper un code PIN';

  @override
  String get cardAnswer =>
      'C’est fait. Tapez-en un autre, ou touchez Terminé quand vous avez fini.';

  @override
  String get keyLine =>
      'Vos codes PIN ne fonctionnent que sur ce téléphone. Si le téléphone perd un jour la clé qui les vérifie, il faudra réinitialiser Kryfo et restaurer une sauvegarde. Les discussions masquées ne reviennent que d’une sauvegarde faite pendant qu’elles étaient ouvertes.';

  @override
  String get keyLineUnlocked =>
      'Vos codes PIN ne fonctionnent que sur ce téléphone, et seulement quand il est déverrouillé. Si le téléphone perd un jour la clé qui les vérifie, il faudra réinitialiser Kryfo et restaurer une sauvegarde. Les discussions masquées ne reviennent que d’une sauvegarde faite pendant qu’elles étaient ouvertes.';

  @override
  String get keyLineScreenLock =>
      'Activez un verrouillage d’écran sur votre téléphone pour que cette protection tienne quand il est verrouillé.';

  @override
  String get fileServerTryLater =>
      'Le serveur de fichiers est plein pour le moment. Réessayez un peu plus tard.';

  @override
  String fileTooBigUntilUpdate(String size, String max) {
    return 'Ce fichier fait $size. Dans cette discussion, les fichiers peuvent faire jusqu’à $max tant que tout le monde n’a pas mis à jour Kryfo.';
  }

  @override
  String get fileDayLimit =>
      'Vous avez déjà envoyé beaucoup de gros fichiers aujourd’hui. Réessayez demain.';

  @override
  String get mediaProgressPreparing => 'Préparation · gardez l’appli ouverte';

  @override
  String get groupShotsBlocksAll =>
      'Bloque les captures et l’enregistrement d’écran sur chaque téléphone de ce groupe, ainsi que la copie, le transfert et l’enregistrement des messages des autres. Il ne peut rien contre les applis autorisées à lire l’écran, ni contre un téléphone ou une appli modifiés pour le contourner.';

  @override
  String get groupShotsBlocksAllDesk =>
      'Désactive ici la copie, le transfert et l’enregistrement des messages des autres. Kryfo pour Android bloque aussi les captures et l’enregistrement d’écran.';

  @override
  String get groupShotsStartsWhenAll =>
      'En attente que tout le monde ici puisse bloquer les captures sur son appareil';

  @override
  String get groupShotsOnForAll => 'Activé pour tout le monde ici';

  @override
  String get groupShotsOnForAllDesk => 'Activé dans Kryfo pour Android';

  @override
  String get groupShotsOffAdminOnly =>
      'Désactivé. Seul l’admin peut changer cela';

  @override
  String get groupShotsWaitAdminOnly =>
      'En attente que tout le monde ici puisse bloquer les captures sur son appareil. Seul l’admin peut changer cela';

  @override
  String get groupShotsOnAdminOnly =>
      'Activé pour tout le monde ici. Seul l’admin peut changer cela';

  @override
  String get groupShotsOnAdminOnlyDesk =>
      'Activé dans Kryfo pour Android. Seul l’admin peut changer cela';

  @override
  String groupShotsWaitingFor(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'En attente de $countString personnes',
      one: 'En attente de $countString personne',
    );
    return '$_temp0';
  }

  @override
  String get groupShotsWaitingTitle => 'Pas encore couverts';

  @override
  String get groupShotsWaitingHint =>
      'Le blocage des captures couvre tout le monde dès que les appareils de ces personnes peuvent bloquer les captures. Touchez quelqu’un pour le retirer du groupe.';

  @override
  String get groupShotsNeedsUpdate =>
      'Ne peut pas encore bloquer les captures sur son appareil, ou n’a pas été en ligne depuis';

  @override
  String get groupShotsBlockedByYou => 'Bloqué par vous';

  @override
  String get groupShotsYouTurnedOnWait =>
      'Vous avez activé le blocage des captures. Il couvre tout le monde dès que chacun ici peut bloquer les captures sur son appareil.';

  @override
  String groupShotsTheyTurnedOnWait(String name) {
    return '$name a activé le blocage des captures. Il couvre tout le monde dès que chacun ici peut bloquer les captures sur son appareil.';
  }

  @override
  String get groupShotsStarted =>
      'Le blocage des captures est activé pour tout le monde ici. Copier, transférer et enregistrer les messages des autres est aussi désactivé.';

  @override
  String get groupShotsStartedDesk =>
      'Le blocage des captures est activé dans Kryfo pour Android. Copier, transférer et enregistrer les messages des autres est aussi désactivé.';

  @override
  String get groupShotsPaused =>
      'Quelqu’un ici ne peut pas encore bloquer les captures sur son appareil. Le blocage couvre de nouveau tout le monde dès que c’est possible.';

  @override
  String get groupShotsCantYet => 'Ne peut pas encore bloquer les captures';

  @override
  String get groupShotsAddTitle => 'Ajouter quand même ?';

  @override
  String get groupShotsAddPauses =>
      'Le blocage des captures ne couvrira pas tout le monde ici tant que ces personnes ne pourront pas bloquer les captures sur leur appareil.';

  @override
  String get groupShotsLeaveStays => 'Le blocage des captures reste tel quel.';

  @override
  String get groupShotsBlockedHere =>
      'Kryfo bloque les captures dans ce groupe';

  @override
  String get groupShotsBlockedHereDesk =>
      'Copier, transférer et enregistrer est désactivé dans ce groupe';

  @override
  String get groupShotsMenuNote =>
      'Copier, transférer et enregistrer les messages des autres est désactivé dans ce groupe';

  @override
  String get groupShotsKeptOpen =>
      'Ouvrir les fichiers des autres dans d’autres applis est désactivé dans ce groupe';

  @override
  String get groupShotsOldNotice =>
      'J’ai activé le blocage des captures dans ce groupe. Votre Kryfo ne le permet pas encore, merci de le mettre à jour.';

  @override
  String get captureShotTaken =>
      'Capture d’écran prise. Personne d’autre n’a été prévenu.';

  @override
  String get captureRecording =>
      'Cet écran est en cours d’enregistrement. Personne d’autre n’a été prévenu.';

  @override
  String get settingsDevices => 'Appareils';

  @override
  String get devicesLinkedDevices => 'Appareils associés';

  @override
  String get devicesThisPhoneOnly => 'Ce téléphone seulement';

  @override
  String get devicesThisPhoneOnlyDesk => 'Cet ordinateur seulement';

  @override
  String get devicesNameSeparator => ', ';

  @override
  String get devicesThisPhone => 'Ce téléphone';

  @override
  String get devicesThisPhoneDesk => 'Cet ordinateur';

  @override
  String get devicesOnlyThisPhone =>
      'Seul ce téléphone peut associer ou retirer des appareils';

  @override
  String get devicesOnlyThisPhoneDesk =>
      'Seul cet ordinateur peut associer ou retirer des appareils';

  @override
  String devicesLinkedOn(Object date) {
    return 'Associé le $date';
  }

  @override
  String get devicesUsedToday => 'Utilisé aujourd’hui';

  @override
  String get devicesUsedThisWeek => 'Utilisé cette semaine';

  @override
  String get devicesUsedThisMonth => 'Utilisé ce mois-ci';

  @override
  String get devicesNotUsedYet => 'Pas encore utilisé';

  @override
  String devicesUnlinksSoon(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Sera dissocié dans $daysString jours si vous ne l’ouvrez pas',
      one: 'Sera dissocié demain si vous ne l’ouvrez pas',
      zero: 'Sera dissocié aujourd’hui si vous ne l’ouvrez pas',
    );
    return '$_temp0';
  }

  @override
  String get devicesEmptyTitle => 'Kryfo sur votre ordinateur';

  @override
  String get devicesEmptyLine =>
      'Associez un ordinateur pour y lire et envoyer vos messages. Jusqu’à cinq appareils en plus de ce téléphone.';

  @override
  String get devicesContactsSeeNothing =>
      'Les applis de vos contacts n’affichent pas vos appareils.';

  @override
  String get devicesUnusedRule =>
      'Un appareil que vous n’ouvrez pas pendant 30 jours se dissocie tout seul et efface vos discussions.';

  @override
  String get devicesFull =>
      'Cinq appareils sont associés. Retirez-en un pour en associer un autre.';

  @override
  String get devicesLinkADevice => 'Associer un appareil';

  @override
  String get devicesRemoveAll => 'Retirer tous les autres appareils';

  @override
  String get devicesRemoveAllTitle => 'Retirer tous les autres appareils ?';

  @override
  String get devicesRemoveAllLine =>
      'Dès que les applis de vos contacts reçoivent le changement, ils ne reçoivent plus de nouveaux messages et ne peuvent plus envoyer en votre nom. Ce téléphone garde tout.';

  @override
  String get devicesRemoveAllYes => 'Tout retirer';

  @override
  String get devicesRemovedAll => 'Plus que ce téléphone';

  @override
  String devicesRemoveTitle(Object name) {
    return 'Retirer $name ?';
  }

  @override
  String get devicesRemoveLine =>
      'Dès que les applis de vos contacts reçoivent le changement, il ne reçoit plus de nouveaux messages et ne peut plus envoyer en votre nom. Il efface vos discussions la prochaine fois qu’il est en ligne. Un appareil que quelqu’un a trafiqué peut garder ce qu’il a déjà.';

  @override
  String get devicesRemove => 'Retirer';

  @override
  String devicesRemoved(Object name) {
    return '$name retiré';
  }

  @override
  String get devicesRename => 'Renommer';

  @override
  String devicesRenameTitle(Object name) {
    return 'Renommer $name';
  }

  @override
  String get devicesRenameLine =>
      'Vous seul voyez ce nom. Vos contacts, jamais.';

  @override
  String get devicesNameComputer => 'Ordinateur';

  @override
  String get devicesDeviceCode => 'Code de l’appareil';

  @override
  String get devicesDeviceCodeLine =>
      'Le même code s’affiche sur l’appareil lui-même, dans les Paramètres.';

  @override
  String get devicesLinkStep1 =>
      'Ouvrez Kryfo sur votre ordinateur. Un code s’affiche.';

  @override
  String get devicesLinkStep2 => 'Scannez le code avec ce téléphone.';

  @override
  String get devicesLinkStep3 =>
      'Vérifiez que les deux écrans affichent les mêmes six chiffres.';

  @override
  String get devicesHistory => 'Historique';

  @override
  String get devicesHistoryCopy => 'Copier mes discussions';

  @override
  String get devicesHistoryCopyHint =>
      'Tous vos messages, avec les photos et vidéos des 30 derniers jours.';

  @override
  String get devicesHistoryNone => 'Contacts et groupes seulement';

  @override
  String get devicesHistoryNoneHint => 'Ils arrivent sans aucun message.';

  @override
  String get devicesSkipMedia => 'Ignorer les photos et vidéos';

  @override
  String get devicesSkipMediaHint =>
      'Seul le texte est copié. Plus rapide, et moins de choses sur l’appareil.';

  @override
  String get devicesHiddenStay =>
      'Les discussions masquées et le leurre restent sur ce téléphone.';

  @override
  String get devicesHiddenStayDesk =>
      'Les discussions masquées et le leurre restent sur cet ordinateur.';

  @override
  String get devicesScanCode => 'Scanner le code';

  @override
  String get devicesLinkReaching => 'Recherche de l’appareil';

  @override
  String get devicesLinkReachingLine =>
      'Gardez Kryfo ouvert sur les deux. Via Tor, cela peut prendre une minute.';

  @override
  String get devicesLinkCompare => 'Les chiffres correspondent ?';

  @override
  String get devicesLinkCompareLine =>
      'Le nouvel appareil affiche aussi six chiffres. Associez-le seulement s’ils sont identiques.';

  @override
  String get devicesLinkMatch => 'Ils correspondent';

  @override
  String get devicesLinkNoMatch => 'Ils ne correspondent pas';

  @override
  String get devicesLinkLinking => 'Association en cours';

  @override
  String get devicesLinkLinkingLine =>
      'Préparation du nouvel appareil. Gardez les deux ouverts.';

  @override
  String get devicesLinkDone => 'Appareil associé';

  @override
  String get devicesLinkDoneLine =>
      'Il figure dans Appareils associés, où vous pouvez le renommer ou le retirer.';

  @override
  String get devicesLinkUnreached => 'Impossible de joindre l’appareil';

  @override
  String get devicesLinkUnreachedLine =>
      'Vérifiez que Kryfo est ouvert sur le nouvel appareil et affiche son code, puis réessayez.';

  @override
  String get devicesLinkStopped => 'Rien n’a été associé';

  @override
  String get devicesLinkStoppedLine =>
      'Les chiffres doivent correspondre. Recommencez avec un nouveau code.';

  @override
  String get devicesLinkInterruptedLine =>
      'Quelque chose a interrompu l’association. Recommencez avec un nouveau code.';

  @override
  String get scanLinkTitle => 'Scanner le code de l’appareil';

  @override
  String get scanLinkPoint => 'Visez le code sur le nouvel appareil';

  @override
  String get scanLinkNotOne => 'Ce n’est pas un code d’association';

  @override
  String get onboardingLinkToMyPhone => 'Associer à mon téléphone';

  @override
  String get joinTitle => 'Associer à votre téléphone';

  @override
  String get joinStep1 => 'Ouvrez Kryfo sur votre téléphone.';

  @override
  String get joinStep2 =>
      'Allez dans Réglages, puis Appareils associés, puis Associer un appareil.';

  @override
  String get joinStep3 => 'Scannez ce code avec votre téléphone.';

  @override
  String get joinWaiting => 'En attente de votre téléphone';

  @override
  String get joinCodeLife => 'Le code reste valable dix minutes.';

  @override
  String get joinCompareLine =>
      'Votre téléphone affiche aussi six chiffres. Continuez seulement s’ils sont identiques.';

  @override
  String get joinLinking => 'Association à votre téléphone';

  @override
  String get joinLinkingLine =>
      'Gardez Kryfo ouvert sur votre téléphone jusqu’à la fin.';

  @override
  String get joinDone => 'Associé à votre téléphone';

  @override
  String get joinDoneLine =>
      'Les nouveaux messages arrivent aussi sur cet appareil. Le numéro de clé de votre compte :';

  @override
  String get joinOpen => 'Ouvrir Kryfo';

  @override
  String get joinUnreached => 'Impossible de joindre votre téléphone';

  @override
  String get joinUnreachedLine =>
      'Vérifiez que votre téléphone est en ligne avec Kryfo ouvert, puis essayez un nouveau code.';

  @override
  String get joinNewCode => 'Nouveau code';

  @override
  String get devicesNewNotice => 'Nouvel appareil associé';

  @override
  String devicesNewNoticeLine(Object name, Object date) {
    return '$name a été associé à votre compte le $date. Ouvrez Appareils associés pour le voir.';
  }

  @override
  String get devicesNewNoticeMany => 'Nouveaux appareils associés';

  @override
  String devicesNewNoticeManyLine(Object names) {
    return '$names ont été associés à votre compte. Ouvrez Appareils associés pour les voir.';
  }

  @override
  String get devicesNewNoticeOpen => 'Ouvrir';

  @override
  String get settingsLinkedToLine =>
      'Associé à votre téléphone. Les sauvegardes et les invitations restent sur le téléphone.';

  @override
  String get devicesYourPhone => 'Votre téléphone';

  @override
  String get desktopLockTitle => 'Kryfo est verrouillé';

  @override
  String get desktopLockBody =>
      'Saisissez la phrase secrète de cet ordinateur.';

  @override
  String get desktopLockNewTitle => 'Verrouiller Kryfo sur cet ordinateur';

  @override
  String get desktopLockNewBody =>
      'Kryfo vous demandera cette phrase secrète à chaque démarrage. Elle verrouille vos messages, photos, messages vocaux, fichiers, contacts et clés sur cet ordinateur.';

  @override
  String get desktopLockHonest =>
      'Quiconque copie le dossier de Kryfo peut essayer des phrases secrètes sur son propre ordinateur, aussi vite que celui-ci le permet. Quatre mots aléatoires ou plus tiennent bon. Une phrase courte, non.';

  @override
  String get desktopLockForgot =>
      'Sans la phrase secrète, aucun de vos messages, fichiers ou clés ici ne peut être ouvert, pas même par nous.';

  @override
  String get desktopLockField => 'Phrase secrète';

  @override
  String get desktopLockRepeat => 'La même phrase secrète, une seconde fois';

  @override
  String get desktopLockSet => 'Verrouiller avec cette phrase';

  @override
  String get desktopLockOpen => 'Ouvrir Kryfo';

  @override
  String desktopLockShort(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Au moins $countString caractères';
  }

  @override
  String get desktopLockMismatch =>
      'Les deux phrases secrètes ne sont pas identiques';

  @override
  String get desktopLockWrong => 'Ce n’est pas la phrase secrète';

  @override
  String get desktopLockFailed =>
      'Kryfo n’a pas pu ouvrir son verrou ici. Essayez de le relancer.';

  @override
  String get desktopTrayQuit => 'Quitter Kryfo';

  @override
  String get desktopTrayTip => 'Kryfo est ouvert et reçoit des messages';

  @override
  String get desktopTrayLockedTip =>
      'Ouvrez Kryfo pour commencer à recevoir des messages';

  @override
  String get desktopTrayStillRunning =>
      'Kryfo reste actif dans la zone de notification. Pour le quitter, passez par son icône dans la zone de notification.';

  @override
  String get desktopRunSection => 'Sur cet ordinateur';

  @override
  String get desktopTrayRow => 'Rester actif dans la zone de notification';

  @override
  String get desktopTrayHint =>
      'Fermer la fenêtre garde Kryfo dans la zone de notification, et les messages continuent d’arriver.';

  @override
  String get desktopTrayOffLine =>
      'Fermer la fenêtre quitte Kryfo. Les messages arrivent quand vous le rouvrez.';

  @override
  String get desktopTrayNoneLine =>
      'Ce bureau n’affiche pas d’icône dans la zone de notification, donc fermer la fenêtre quitte Kryfo.';

  @override
  String get desktopStartRow => 'Lancer au démarrage de l’ordinateur';

  @override
  String get desktopStartHint =>
      'Kryfo démarre dans la zone de notification quand vous vous connectez à cet ordinateur.';

  @override
  String get desktopStartRefused =>
      'Cet ordinateur n’a pas laissé Kryfo se lancer avec lui. Kryfo s’ouvre dès que vous le lancez vous-même.';

  @override
  String get desktopStartHeldOff =>
      'Windows a désactivé Kryfo dans ses applications de démarrage. Activez-le là-bas, dans Paramètres, Applications, Démarrage.';

  @override
  String get desktopNoCamera =>
      'Kryfo ne peut pas encore utiliser de caméra sur cet ordinateur. Utilisez plutôt le lien ou le code.';

  @override
  String get desktopAlreadyOpen => 'Kryfo est déjà ouvert sur cet ordinateur.';

  @override
  String get desktopFolderNotYours =>
      'Le dossier de Kryfo appartient à un autre compte de cet ordinateur, Kryfo ne l’ouvrira donc pas.';

  @override
  String get desktopFolderNotPrivate =>
      'Kryfo n’a pas pu rendre son dossier privé pour vous, il ne s’ouvrira donc pas.';

  @override
  String get desktopLockOtherVersion =>
      'Ce verrou a été créé par une autre version de Kryfo, que celle-ci ne sait pas lire.';

  @override
  String get desktopNoMemoryFolder =>
      'Kryfo a besoin d’un dossier privé en mémoire pendant qu’il fonctionne, et cet ordinateur n’en propose aucun, il ne s’ouvrira donc pas.';

  @override
  String get inviteNotYet =>
      'Cette invitation n\'est pas encore valable. Vérifiez l\'heure de votre téléphone.';

  @override
  String get inviteNotYetDesk =>
      'Cette invitation n\'est pas encore valable. Vérifiez l\'heure de votre ordinateur.';

  @override
  String get inviteExpired =>
      'Cette invitation a expiré. Demandez-en une nouvelle.';

  @override
  String get inviteDamaged =>
      'Cette invitation est endommagée. Demandez-en une nouvelle.';

  @override
  String get helloSent =>
      'Demande envoyée. Elle sera vue dès que la personne sera en ligne.';

  @override
  String get inviteNeeds06 => 'Nécessite Kryfo 0.6 ou plus récent.';

  @override
  String get helloSentOld =>
      'Demande envoyée. Si la personne utilise une ancienne version de Kryfo, elle devra d\'abord la mettre à jour.';

  @override
  String get modesPickHow =>
      'Choisissez comment vos messages voyagent. Vous pouvez changer à tout moment.';

  @override
  String get modesPrivate => 'Privé';

  @override
  String get modesPrivateTag => 'Tor · ponts si besoin';

  @override
  String get modesPrivateLine =>
      'Personne ne connaît votre adresse IP ni qui vous êtes, pas même nos serveurs. Trouve tout seul un moyen de contourner les blocages.';

  @override
  String get modesDefault => 'Par défaut';

  @override
  String get modesFastTag => 'Directement vers nos serveurs';

  @override
  String get modesFastLine =>
      'Sans Tor, les messages arrivent plus vite et usent moins la batterie. Nos serveurs voient votre adresse IP seulement pendant que vous êtes connecté, sans jamais l\'enregistrer ni la garder. Vos contacts ne la voient jamais. Votre réseau peut voir que vous vous connectez à Kryfo.';

  @override
  String get modesFastConnected => 'Rapide · connecté';

  @override
  String get modesFastConnecting => 'Rapide · connexion';

  @override
  String get modesFastDown => 'Rapide · nos serveurs ne répondent pas';

  @override
  String get modesBackupReady =>
      'Un serveur de secours est toujours prêt, vous restez connecté même si l\'un tombe.';

  @override
  String get modesDetails => 'Détails';

  @override
  String get modesBothLine =>
      'Les deux chiffrent chaque message de bout en bout. Seul change qui peut voir votre adresse IP.';

  @override
  String get modesConnectionBridges => 'Connexion et ponts';

  @override
  String get modesWhatServersSee => 'Ce que nos serveurs peuvent voir';

  @override
  String get serversTitle => 'Serveurs de Rapide';

  @override
  String get serversLine =>
      'Chaque message part vers les deux serveurs à la fois. Le premier qui répond le porte, et l\'autre prend le relais si l\'un s\'arrête.';

  @override
  String get serversOne => 'Serveur 1';

  @override
  String get serversTwo => 'Serveur 2 · second hébergeur';

  @override
  String get serversConnected => 'Connecté';

  @override
  String get serversConnecting => 'Connexion';

  @override
  String get serversNotAnswering => 'Ne répond pas';

  @override
  String serversMs(int ms) {
    return '$ms ms';
  }

  @override
  String get serversQuicker => 'Plus rapide';

  @override
  String get serversBackups => 'Relais publics';

  @override
  String get serversBackupsLine =>
      'Utilisés pendant que le Serveur 1 est en panne, et seulement par Tor : ils ne voient jamais votre adresse IP.';

  @override
  String get serversStandingBy => 'En attente';

  @override
  String get serversInUse => 'Utilisés';

  @override
  String get homeMergedTitle => 'Relais et Rapide ne font plus qu’un';

  @override
  String get homeMergedLine =>
      'Vous êtes sur Rapide. Un serveur de secours est toujours prêt, vous restez connecté même si l\'un tombe. Nos serveurs voient votre adresse IP, jamais ce que vous dites.';

  @override
  String get homeMergedGotIt => 'Compris';

  @override
  String get homeMergedUsePrivate => 'Utiliser Privé à la place';

  @override
  String get homeOursDownTitle => 'Nos serveurs ne répondent pas';

  @override
  String get homeOursDownLine =>
      'Après quelques minutes, dès que Tor passe, les messages passent aussi par des relais publics, et reviennent à nos serveurs dès que l\'un répond.';

  @override
  String get homeUsePrivate => 'Utiliser Privé';

  @override
  String get homeSwitchedToPrivate => 'Passé à Privé';

  @override
  String get homeUseFast => 'Utiliser Rapide';

  @override
  String get homeSwitchedToFastRoute => 'Passé à Rapide';

  @override
  String get bridgesBridgeFirstFastSeen =>
      'Laissez Kryfo trouver un pont qui passe. Rapide marche aussi, mais ce réseau peut voir que vous vous connectez à Kryfo.';

  @override
  String get appServersNotAnswering => 'Serveurs muets';

  @override
  String get settingsPrivateTor => 'Privé · Tor';

  @override
  String get seenOurServers => 'Nos serveurs';

  @override
  String get seenOurServersCould => 'Nos serveurs pourraient';

  @override
  String get seenIpWhy =>
      'Sur Privé tout passe par Tor et nos serveurs voient un nœud de sortie, jamais vous. Sur Rapide la connexion va directement vers nos deux serveurs : ils voient votre adresse IP pendant que vous êtes connecté et n\'en gardent aucune trace. Pendant que le premier est en panne, Rapide utilise aussi des relais publics, seulement par Tor.';

  @override
  String get chatAlbumItDisappearsWithNo =>
      'L’album sera supprimé des deux téléphones, sauf s’il a déjà été enregistré. C’est irréversible.';

  @override
  String get chatAlbumItDisappearsWithNoDesk =>
      'L’album sera supprimé des deux appareils, sauf s’il a déjà été enregistré. C’est irréversible.';

  @override
  String get groupChatAlbumItDisappearsWithNo =>
      'L’album sera supprimé des téléphones de tout le monde, sauf s’il a déjà été enregistré. C’est irréversible.';

  @override
  String get groupChatAlbumItDisappearsWithNoDesk =>
      'L’album sera supprimé des appareils de tout le monde, sauf s’il a déjà été enregistré. C’est irréversible.';

  @override
  String get homeInviteSomeone => 'Inviter quelqu’un';

  @override
  String get onboardingNameHeadline => 'Un *@nom* public, si vous voulez.';

  @override
  String get onboardingNameLine =>
      'Un nom public permet aux gens de vous trouver. Passer cette étape vous garde plus discret, vous pourrez toujours en ajouter un plus tard.';

  @override
  String get onboardingNameSkip => 'Passer pour l’instant →';

  @override
  String onboardingNameClaim(Object handle) {
    return 'Prendre @$handle →';
  }

  @override
  String get onboardingInviteHeadline => 'Enfin, *invitez quelqu’un*.';

  @override
  String get onboardingInviteLead =>
      'Envoyez un lien dans n’importe quelle messagerie. Il ouvre Kryfo, ou montre où l’obtenir.';

  @override
  String get onboardingInviteSomeone => 'Inviter quelqu’un →';

  @override
  String get onboardingInviteGettingReady => 'Préparation de votre lien…';

  @override
  String inviteShareText(Object myId, Object link, Object download) {
    return 'Ajoutez-moi sur Kryfo. Mon nom sur Kryfo est $myId\n\nTouchez pour m’ajouter :\n$link\n\nPas encore Kryfo ? Obtenez-le ici :\n$download\n\nKryfo est une messagerie privée. Pas de numéro de téléphone, pas d’e-mail.';
  }

  @override
  String get inviteNotReady =>
      'Votre lien est presque prêt. Réessayez dans un instant.';

  @override
  String get photoCropTitle => 'Déplacer et redimensionner';

  @override
  String get photoCropUse => 'Utiliser la photo';

  @override
  String get photoCropLabel =>
      'Ta photo dans le cercle. Pince pour zoomer, fais glisser pour déplacer';

  @override
  String get photoCouldNotUse =>
      'Essaie une autre photo. Celle-ci n\'a pas pu être lue.';

  @override
  String get photoTake => 'Prendre une photo';

  @override
  String get photoChoose => 'Choisir dans la galerie';

  @override
  String get photoPickFace => 'Choisir un visage';

  @override
  String get photoView => 'Voir la photo';

  @override
  String get photoRemove => 'Retirer la photo';

  @override
  String get photoYourPhoto => 'Ta photo';

  @override
  String get photoYourPhotoLine =>
      'Seuls tes contacts la voient, chiffrée de bout en bout.';

  @override
  String get photoSetTheirs => 'Ajouter une photo';

  @override
  String get photoChangeTheirs => 'Changer la photo';

  @override
  String get photoOnlyHere => 'Seulement sur ce téléphone';

  @override
  String get photoOnlyHereDesk => 'Seulement sur cet ordinateur';

  @override
  String photoForThem(Object name) {
    return 'Une photo pour $name';
  }

  @override
  String get photoOnlyHereLine =>
      'Toi seul la vois. Elle reste sur ce téléphone.';

  @override
  String get photoOnlyHereLineDesk =>
      'Toi seul la vois. Elle reste sur cet ordinateur.';

  @override
  String photoOf(Object name) {
    return 'Photo de $name';
  }

  @override
  String get historyChatStaysShots =>
      'Cette discussion reste sur votre téléphone, car les captures d’écran y sont bloquées.';

  @override
  String chatDeviceReplyFromPhone(String name) {
    return '$name utilise une version plus ancienne de Kryfo. Répondez depuis votre téléphone.';
  }

  @override
  String chatDeviceReplyFromPhoneForNow(String name) {
    return 'Pour l\'instant, répondez à $name depuis votre téléphone.';
  }

  @override
  String get linkedClearHereOnly =>
      'Chaque message ici est effacé de cet ordinateur seulement. Votre téléphone les garde.';

  @override
  String get linkedDeleteHereOnly =>
      'Tous les messages et le contact partent de cet ordinateur seulement. Votre téléphone garde la discussion.';

  @override
  String get linkedBlockHereOnly =>
      'Ses messages n’arrivent plus sur cet ordinateur. Ce contact n’en est pas averti. Bloquez-le sur votre téléphone pour qu’ils s’arrêtent aussi là-bas.';

  @override
  String get historyCopyTitle => 'Historique des discussions';

  @override
  String get historyCopyMaking => 'Préparation de tes discussions';

  @override
  String get historyCopyMakingLine =>
      'Ton téléphone rassemble ce qui sera copié. Ça commence dans un instant.';

  @override
  String get historyCopyGoing => 'Copie de tes discussions';

  @override
  String get historyCopyGoingLine =>
      'Garde les deux appareils en ligne jusqu’à la fin.';

  @override
  String historyCopySize(Object size) {
    return '$size au total';
  }

  @override
  String get historyCopyWaiting => 'En attente de l’autre appareil';

  @override
  String get historyCopyWaitingLine =>
      'La copie reprend d’elle-même quand les deux appareils sont en ligne.';

  @override
  String get historyCopyPaused => 'La copie fait une courte pause';

  @override
  String get historyCopyPausedLine => 'Elle reprend dans une minute.';

  @override
  String get historyCopyWhole => 'Tous les messages et fichiers sont arrivés';

  @override
  String get historyCopyWholeLine => 'Rien ne manque.';

  @override
  String get historyCopyRows => 'Tes contacts et groupes sont arrivés';

  @override
  String get historyCopyRowsLine =>
      'Ils sont arrivés sans aucun message. Les nouveaux messages s\'affichent sur l\'appareil à partir de maintenant.';

  @override
  String get historyCopyGaps => 'La plupart de tes discussions sont arrivées';

  @override
  String get historyCopyGapsLine =>
      'Ces discussions ont moins sur le nouvel appareil que sur ton téléphone.';

  @override
  String historyCopyGapMessages(Object got, Object want) {
    return 'Messages : $got sur $want';
  }

  @override
  String historyCopyGapFiles(Object got, Object want) {
    return 'Fichiers : $got sur $want';
  }

  @override
  String historyCopyLeft(num count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString éléments sont restés sur ton téléphone',
      one: '1 élément est resté sur ton téléphone',
    );
    return '$_temp0';
  }

  @override
  String get historyCopyLeftWhy =>
      'Trop volumineux ou illisibles pour être copiés.';

  @override
  String historyCopyLeftChats(num count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString discussions sont restées sur ton téléphone',
      one: '1 discussion est restée sur ton téléphone',
    );
    return '$_temp0';
  }

  @override
  String get historyCopyEnded => 'La copie s’est arrêtée';

  @override
  String get historyCopyEndedLine =>
      'Plus rien n’arrive. Associe à nouveau l’appareil pour une nouvelle copie.';

  @override
  String get historyCopyFailed => 'La copie n’a pas pu se terminer';

  @override
  String get historyCopyFailedLine =>
      'Associe à nouveau l’appareil pour une nouvelle copie.';

  @override
  String get historyCopyStays => 'Resté sur ton téléphone';

  @override
  String get historyCopySee => 'Voir la copie';

  @override
  String a11yPinDigits(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString chiffres',
      one: '1 chiffre',
      zero: 'Aucun chiffre',
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
      other: '$countString caractères',
      one: '1 caractère',
      zero: 'Aucun caractère',
    );
    return '$_temp0';
  }

  @override
  String get a11yBackupProgress => 'Progression de la sauvegarde';

  @override
  String get a11yRestoreProgress => 'Progression de la restauration';

  @override
  String get a11yExportProgress => 'Progression de l’export';

  @override
  String get a11yLockFileProgress => 'Progression du verrouillage';

  @override
  String get a11yCleanProgress => 'Progression du nettoyage';

  @override
  String get a11yMessageActions => 'Actions sur le message';

  @override
  String get a11yRecordVoiceNote => 'Enregistrer un message vocal';

  @override
  String get a11yRecording => 'Enregistrement en cours';

  @override
  String a11yPhotoOn(String date) {
    return 'Photo, $date';
  }

  @override
  String a11yPhotoFrom(String name, String date) {
    return 'Photo de $name, $date';
  }

  @override
  String a11yVideoOn(String date) {
    return 'Vidéo, $date';
  }

  @override
  String a11yVideoFrom(String name, String date) {
    return 'Vidéo de $name, $date';
  }

  @override
  String a11yNewMessages(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString nouveaux messages',
      one: 'Nouveau message',
    );
    return '$_temp0';
  }

  @override
  String get wideSelectChat => 'Choisissez une discussion';

  @override
  String get wideSelectChatLine =>
      'Choisissez une discussion dans la liste pour commencer à écrire.';

  @override
  String get wideListWidth => 'Largeur de la liste des discussions';

  @override
  String transferDoneOf(String done, String total) {
    return '$done sur $total';
  }

  @override
  String transferDoneLeft(String done, String left) {
    return '$done · $left';
  }

  @override
  String get transferLeftSoon => 'moins d’une minute restante';

  @override
  String transferLeftMinutes(String n) {
    return 'environ $n min restantes';
  }

  @override
  String transferLeftHours(String n) {
    return 'environ $n h restantes';
  }

  @override
  String transferSending(String detail) {
    return 'Envoi · $detail';
  }

  @override
  String transferReceiving(String detail) {
    return 'Réception · $detail';
  }

  @override
  String transferBoth(String detail) {
    return 'Envoi et réception · $detail';
  }

  @override
  String get transferPause => 'Pause';

  @override
  String get transferPauseDownload => 'Mettre le téléchargement en pause';

  @override
  String get transferDownload => 'Télécharger';

  @override
  String get transferResume => 'Reprendre';

  @override
  String get transferOnWifi => 'Se télécharge en Wi-Fi';

  @override
  String transferPausedAt(String detail) {
    return 'En pause · $detail';
  }

  @override
  String get transferTapToDownload => 'Touchez pour télécharger';

  @override
  String transferSizeLine(String size, String state) {
    return '$size · $state';
  }

  @override
  String get transferNoteTitle => 'Transfert de fichiers';

  @override
  String get transferChannel => 'Transferts de fichiers';

  @override
  String get transferChannelLine =>
      'S’affiche pendant l’envoi ou le téléchargement de fichiers. Ne nomme jamais une discussion ni un fichier.';

  @override
  String get autoGetTitle => 'Téléchargement automatique';

  @override
  String get autoGetLine =>
      'Les fichiers arrivent sans toucher, selon vos choix ici. Un fichier en attente reste pour vous sur le serveur de fichiers, une semaine au plus.';

  @override
  String get autoGetPhotos => 'Photos';

  @override
  String get autoGetVideos => 'Vidéos';

  @override
  String get autoGetFiles => 'Fichiers';

  @override
  String get autoGetAlways => 'En Wi-Fi et données mobiles';

  @override
  String get autoGetWifi => 'En Wi-Fi uniquement';

  @override
  String get autoGetNever => 'Jamais, je touche pour télécharger';

  @override
  String get autoGetVoice => 'Les messages vocaux se téléchargent toujours.';

  @override
  String get settingsFiles => 'Fichiers';

  @override
  String get fileSheetOpenWith => 'Ouvrir avec une autre appli';

  @override
  String get desktopLockAccountBody =>
      'Tout ce que Kryfo garde sur cet ordinateur est chiffré. Il s’ouvre avec votre compte utilisateur.';

  @override
  String get desktopLockAddPassphrase => 'Ajouter une phrase secrète';

  @override
  String get desktopLockWithoutPassphrase =>
      'Sans elle, toute personne qui utilise votre compte utilisateur peut ouvrir Kryfo.';

  @override
  String get desktopLockKeyringRefused =>
      'Kryfo n’a pas pu garder sa clé dans le trousseau de clés de cet ordinateur. Ajoutez plutôt une phrase secrète.';

  @override
  String get desktopKeyMissing =>
      'Ce compte utilisateur n’a pas la clé des données de Kryfo. Une sauvegarde Kryfo ramène tout. Si vous avez déplacé le dossier de Kryfo, ajoutez une phrase secrète sur le compte utilisateur d’où il vient, puis copiez-le de nouveau.';

  @override
  String get desktopKeyUnreachable =>
      'Kryfo ne peut pas atteindre sa clé sur cet ordinateur pour le moment. Déverrouillez votre trousseau de clés si l’ordinateur le demande, puis réessayez.';

  @override
  String get desktopPassRow => 'Phrase secrète sur cet ordinateur';

  @override
  String get desktopPassOffBody =>
      'Kryfo s’ouvre avec votre compte utilisateur.';

  @override
  String get desktopPassOnBody =>
      'Kryfo demande cette phrase secrète à chaque démarrage.';

  @override
  String get desktopPassChange => 'Changer la phrase secrète';

  @override
  String get desktopPassRemove => 'Retirer la phrase secrète';

  @override
  String get desktopPassCurrent => 'Phrase secrète actuelle';

  @override
  String get desktopPassNew => 'Nouvelle phrase secrète';

  @override
  String get desktopPassStays =>
      'Cet ordinateur n’a pas de trousseau de clés que Kryfo peut utiliser, la phrase secrète reste donc en place.';

  @override
  String get desktopPassAdded => 'Phrase secrète ajoutée';

  @override
  String get desktopPassRemoved => 'Phrase secrète retirée';

  @override
  String get desktopPassChanged => 'Phrase secrète changée';

  @override
  String get desktopPassRemoveBody =>
      'Saisissez votre phrase secrète pour la retirer. Kryfo s’ouvrira ensuite avec votre compte utilisateur.';

  @override
  String get desktopKeyUnreachableWindows =>
      'Kryfo ne peut pas atteindre sa clé dans la puce de sécurité de cet ordinateur pour le moment. Réessayez dans un instant.';

  @override
  String get desktopLockAccountRefused =>
      'Kryfo n’a pas pu garder sa clé avec votre compte Windows. Ajoutez plutôt une phrase secrète.';

  @override
  String get desktopPassStaysWindows =>
      'Kryfo n’a pas pu garder sa clé avec votre compte Windows, la phrase secrète reste donc en place.';

  @override
  String get desktopBackupCardTitle => 'Gardez une sauvegarde Kryfo';

  @override
  String get desktopBackupCardLine =>
      'Votre compte Windows sur cet ordinateur garde la clé de Kryfo. Une sauvegarde Kryfo ramène tout si l’ordinateur ou le compte est un jour réinitialisé.';

  @override
  String get desktopBackupHint =>
      'Ramène tout si cet ordinateur est un jour réinitialisé.';

  @override
  String chatHealRestored(Object name) {
    return '$name a de nouveau configuré Kryfo';
  }

  @override
  String chatHealNewSession(Object name) {
    return 'L’appareil de $name a ouvert une nouvelle session sécurisée';
  }

  @override
  String chatHealHeldLine(Object name) {
    return 'Vous aviez vérifié $name. Rien n’est envoyé tant que vous ne vérifiez pas le numéro ou ne continuez pas la discussion. Ses messages arrivent toujours.';
  }

  @override
  String get chatKeepChatting => 'Continuer la discussion';

  @override
  String chatNeedsUpdateToChat(Object name) {
    return '$name doit mettre à jour Kryfo pour continuer à discuter';
  }

  @override
  String get restoreOlderTitle => 'Certaines discussions vont faire une pause';

  @override
  String restoreOlderOne(Object name) {
    return '$name utilise une ancienne version de Kryfo. Votre discussion fera une pause jusqu’à sa mise à jour.';
  }

  @override
  String restoreOlderTwo(Object first, Object second) {
    return '$first et $second utilisent une ancienne version de Kryfo. Vos discussions avec eux feront une pause jusqu’à leur mise à jour.';
  }

  @override
  String restoreOlderMany(Object first, Object second, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count autres personnes',
      one: '1 autre personne',
    );
    return '$first, $second et $_temp0 utilisent une ancienne version de Kryfo. Vos discussions avec eux feront une pause jusqu’à leur mise à jour.';
  }

  @override
  String settingsVersionAlpha(String version) {
    return '$version · alpha';
  }

  @override
  String get settingsShotsNotHereYet => 'Pas encore sur cet ordinateur';

  @override
  String get settingsDeskInTray => 'Actif dans la zone de notification';

  @override
  String get settingsDeskWhileOpen => 'Tant que Kryfo est ouvert';

  @override
  String get onboardingDeskRunTitle => 'Kryfo reste *actif*.';

  @override
  String get onboardingDeskRunLead =>
      'Fermez la fenêtre et Kryfo attend dans la zone de notification, les messages continuent d’arriver. Vous pourrez changer les deux plus tard dans Réglages, sous Notifications.';

  @override
  String get savedLongPressAnyMessageDesk =>
      'Faites un clic droit sur un message et choisissez enregistrer pour le garder ici.';

  @override
  String get chatFailedTapToRetryDesk => 'Échec · cliquez pour réessayer';

  @override
  String get groupChatTapToRetryDesk => '! Cliquez pour réessayer';

  @override
  String get chatDropHereToSend => 'Déposez ici pour envoyer';

  @override
  String get notesDropKeepsWords =>
      'Note pour moi garde des mots. Envoie les fichiers dans une discussion.';

  @override
  String get voiceSeeTranscription => 'Voir la transcription';

  @override
  String get voiceTranscribing => 'Transcription…';

  @override
  String get voiceHideTranscription => 'Masquer';

  @override
  String get voiceShowOriginalOnly => 'Voir l’original seul';

  @override
  String get voiceCouldNotTranscribe => 'Impossible de distinguer les mots';

  @override
  String get voiceTranscriptLabel => 'Transcription';

  @override
  String get voiceSettingsTitle => 'Transcription vocale';

  @override
  String get voiceOnRow => 'Transcrire les messages vocaux';

  @override
  String get voiceOnHint => 'Proposée sous chaque message vocal';

  @override
  String get voiceOffDeletes =>
      'Le désactiver supprime les transcriptions enregistrées.';

  @override
  String get voiceModelTitle => 'Modèle vocal';

  @override
  String voiceModelLine(Object size) {
    return 'Un seul téléchargement d’environ $size, pour toutes les langues.';
  }

  @override
  String get voiceModelPrivacy =>
      'Téléchargé via Tor et gardé sur ce téléphone. Vos messages vocaux ne le quittent jamais.';

  @override
  String get voiceModelPrivacyDesk =>
      'Téléchargé via Tor et gardé sur cet ordinateur. Vos messages vocaux ne le quittent jamais.';

  @override
  String get voiceModelFailNoTor =>
      'Tor n’est pas encore connecté. Le modèle se télécharge uniquement via Tor, réessayez une fois la connexion établie.';

  @override
  String get voiceModelRemoveTitle => 'Retirer le modèle vocal ?';

  @override
  String get voiceModelRemoveLine =>
      'Les transcriptions déjà faites restent. Les nouvelles auront de nouveau besoin du modèle.';

  @override
  String get voiceKeptNote =>
      'Les transcriptions sont gardées chiffrées avec leur discussion sur ce téléphone et supprimées avec elle.';

  @override
  String get voiceKeptNoteDesk =>
      'Les transcriptions sont gardées chiffrées avec leur discussion sur cet ordinateur et supprimées avec elle.';

  @override
  String get voiceNotNow => 'Pas maintenant';

  @override
  String get albumPrevious => 'Précédent';

  @override
  String get albumNext => 'Suivant';

  @override
  String get notesHoldHintDesk =>
      'Faites un clic droit sur une note pour la copier ou la supprimer.';

  @override
  String get pinsNothingPinnedHereYetDesk =>
      'Rien d’épinglé ici pour l’instant. Faites un clic droit sur un message et choisissez Épingler : il attendra ici pour tout le monde dans la discussion.';

  @override
  String get chatGalleryDesk => 'Images';

  @override
  String get groupChatGalleryDesk => 'Images';

  @override
  String get photoChooseDesk => 'Choisir un fichier image';

  @override
  String get wallpaperFromYourPhotosDesk => 'Depuis un fichier image';

  @override
  String get notificationsSoundAndVibrationDesk => 'Son';

  @override
  String get notificationsPlaySound => 'Jouer un son';

  @override
  String get notificationsPlaySoundHint =>
      'À chaque notification sur cet ordinateur';

  @override
  String bridgesShareBridgeN(String n) {
    return 'Partager le pont $n';
  }

  @override
  String get bridgesShareThisBridge => 'Partager ce pont';

  @override
  String get bridgesShareItPrivately =>
      'Partage-le en privé, avec des personnes de confiance. Un pont qui reste hors des pages publiques fonctionne plus longtemps.';

  @override
  String get bridgesCopyBridge => 'Copier le pont';

  @override
  String get bridgesBridgeCopied => 'Pont copié';

  @override
  String get bridgesSendBridgeTo => 'Envoyer le pont à';

  @override
  String get linkedAddOnPhone =>
      'Ajoutez des personnes depuis votre téléphone. Elles apparaissent aussi ici.';

  @override
  String get linkedLinkOnPhone => 'Ouvrez ce lien sur votre téléphone.';
}
