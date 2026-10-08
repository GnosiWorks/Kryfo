// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get atmosphereNone => 'None';

  @override
  String get atmosphereEmber => 'Ember';

  @override
  String get atmosphereDusk => 'Dusk';

  @override
  String get atmosphereMoss => 'Moss';

  @override
  String get atmosphereRose => 'Rose';

  @override
  String get atmosphereDots => 'Dots';

  @override
  String get atmosphereGrid => 'Grid';

  @override
  String get atmosphereWaves => 'Waves';

  @override
  String get atmosphereRain => 'Rain';

  @override
  String get atmosphereLateNight => 'Late night';

  @override
  String get atmosphereWarmAfternoon => 'Warm afternoon';

  @override
  String get atmosphereSnow => 'Snow';

  @override
  String get atmosphereDesert => 'Desert';

  @override
  String get atmospherePaper => 'Paper';

  @override
  String get backupThatPassphraseDoesNot =>
      'That passphrase does not open this file';

  @override
  String get backupThatFileIsNot => 'That file is not a Kryfo backup';

  @override
  String get backupThisBackupIsFrom =>
      'This backup is from a newer Kryfo. Update the app, then try again';

  @override
  String get backupThisFileIsDamaged =>
      'This file is damaged and cannot be read';

  @override
  String get backupTheRestoreStoppedPartway => 'The restore stopped partway';

  @override
  String get backupCouldNotMakeThe => 'Could not make the key';

  @override
  String get contactCardMessageMeOn => 'Message me on';

  @override
  String get contactCardScanItOrType =>
      'Scan it, or type the three words into Kryfo.\nThis card knows nothing about you beyond that.';

  @override
  String contactCardMessageMeOnKryfo(Object haloId) {
    return 'Message me on Kryfo · $haloId';
  }

  @override
  String get contactStatusBlocked => 'Blocked';

  @override
  String get contactStatusKeysVerifiedInPerson => 'Keys verified in person';

  @override
  String get contactStatusWaitingInRequests => 'Waiting in requests';

  @override
  String get contactStatusAddedByHand => 'Added by hand';

  @override
  String get deliveryModeAlwaysOn => 'Always on';

  @override
  String get deliveryModeCheckIns => 'Check-ins';

  @override
  String get deliveryModeThroughAHelperApp => 'Through a helper app';

  @override
  String get deliveryModeNotYet => 'not yet';

  @override
  String get deliveryModeJustNow => 'just now';

  @override
  String deliveryModeMinAgo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString min ago',
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
      other: '$countString hours ago',
      one: '$countString hour ago',
    );
    return '$_temp0';
  }

  @override
  String get deliveryModeYesterday => 'yesterday';

  @override
  String deliveryModeDaysAgo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString days ago',
      one: '$countString day ago',
    );
    return '$_temp0';
  }

  @override
  String get deliveryModeConnected => 'Connected';

  @override
  String get deliveryModeConnecting => 'Connecting';

  @override
  String get deliveryModeNotConnected => 'Not connected';

  @override
  String get deliveryModeCheckingNow => 'Checking now';

  @override
  String deliveryModeLastCheckIn(Object agoLine) {
    return 'last check-in $agoLine';
  }

  @override
  String get deliveryModeNoCheckInYet => 'no check-in yet';

  @override
  String deliveryModeConnectedNow(Object last) {
    return 'Connected now · $last';
  }

  @override
  String deliveryModeConnecting2(Object last) {
    return 'Connecting · $last';
  }

  @override
  String get deliveryModeNoCheckInYet2 => 'No check-in yet';

  @override
  String deliveryModeLastChecked(Object agoLine) {
    return 'Last checked $agoLine';
  }

  @override
  String get deliveryModeAHelperApp => 'a helper app';

  @override
  String deliveryModeWokenByNoWake(Object who) {
    return 'Woken by $who · no wake-up yet';
  }

  @override
  String deliveryModeWokenByLastWake(Object who, Object agoLine) {
    return 'Woken by $who · last wake-up $agoLine';
  }

  @override
  String get introBudgetTomorrow => 'tomorrow';

  @override
  String introBudgetInDays(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'in $countString days',
      one: 'in $countString day',
    );
    return '$_temp0';
  }

  @override
  String get introBudgetInAnHour => 'in an hour';

  @override
  String introBudgetInHours(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'in $countString hours',
      one: 'in $countString hour',
    );
    return '$_temp0';
  }

  @override
  String get introBudgetInAFewMinutes => 'in a few minutes';

  @override
  String get lockStateUnlockKryfo => 'Unlock Kryfo';

  @override
  String get appInvalidUri => 'Invalid uri';

  @override
  String appBundleError(Object e) {
    return 'Bundle error: $e';
  }

  @override
  String appAlreadySaved(Object parsed) {
    return 'Already saved: $parsed';
  }

  @override
  String appAddedYouCanMessage(Object parsed) {
    return 'Added $parsed · you can message them now';
  }

  @override
  String appPeerImportedV1(Object parsed) {
    return 'Peer imported (v1): $parsed';
  }

  @override
  String appLongWindow(Object line) {
    return '$line long window';
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
      other: '$eString events',
      one: '$eString event',
    );
    return '$line ($heldString of $subsString, connect ${c}s, $_temp0, $_temp1)';
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
      other: '$eString events',
      one: '$eString event',
    );
    return '$line (connect ${c}s, $_temp0, $_temp1)';
  }

  @override
  String appSDropped(Object host, Object secs) {
    return '$host ${secs}s dropped';
  }

  @override
  String appS(Object host, Object secs) {
    return '$host ${secs}s';
  }

  @override
  String get appTorWouldNotWake => 'Tor would not wake';

  @override
  String get appCheckStarted => 'Started';

  @override
  String get appTorNotReadyIn => 'Tor not ready in 75s';

  @override
  String get appOk => 'OK';

  @override
  String get appOkNoRelayBegan => 'OK, no relay began';

  @override
  String get appOkCapped => 'OK, capped';

  @override
  String appSBy(Object how, int secs, String why) {
    final intl.NumberFormat secsNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String secsString = secsNumberFormat.format(secs);

    String _temp0 = intl.Intl.selectLogic(why, {
      'push': '$how, ${secsString}s, by push',
      'other': '$how, ${secsString}s, by job',
    });
    return '$_temp0';
  }

  @override
  String get appAnAttachmentCouldNot =>
      'An attachment could not be saved on this phone';

  @override
  String get appGroup2 => 'Group';

  @override
  String get appVoiceMessage => 'Voice message';

  @override
  String get appPhoto => 'Photo';

  @override
  String get appNewRequest => 'New request';

  @override
  String get appSomeoneYouHaveNot => 'Someone you have not added wrote to you';

  @override
  String get appSettingUpYourKeys => 'Setting up your keys';

  @override
  String get appOpeningYourChats => 'Opening your chats';

  @override
  String get appStartingTor => 'Starting Tor';

  @override
  String get appTimedMessagesAreNot =>
      'Timed messages are not clearing. Restart Kryfo';

  @override
  String get appVoiceMessage2 => 'Voice message';

  @override
  String appYou(Object body) {
    return 'You: $body';
  }

  @override
  String get appThisRoomHasAlready => 'This room has already expired';

  @override
  String get appYouAreAlreadyIn => 'You are already in this room';

  @override
  String get appCouldNotMakeA => 'Could not make a room key';

  @override
  String appJoined(Object linkName) {
    return 'Joined $linkName';
  }

  @override
  String get roomJoinWaitingToJoin => 'Waiting to join';

  @override
  String get roomJoinNotAnswering => 'Not answering';

  @override
  String roomJoinWaitingFor(Object room) {
    return 'Waiting for $room to let you in…';
  }

  @override
  String get roomJoinWaitingLine => 'You can write here once you are in.';

  @override
  String get roomJoinNoAnswer => 'This room isn\'t answering.';

  @override
  String get roomJoinMayHaveEnded => 'It may have ended.';

  @override
  String get appBooting => 'Booting...';

  @override
  String get appSettingUpYourIdentity => 'Setting up your identity...';

  @override
  String get appAddSomeone => 'Add someone';

  @override
  String get appScanTheirCodeOr =>
      'Scan their code, or paste what they gave you: a link, an @handle, or a room link.';

  @override
  String get appScanTheirCode => 'Scan their code';

  @override
  String get appAKryfoLinkA => 'A Kryfo link, a room link or @wren';

  @override
  String get appAddThem => 'Add them';

  @override
  String get appEveryWayToAdd => 'Every way to add someone';

  @override
  String get appShowYourCodeSend =>
      'Show your code, send a link, claim a handle';

  @override
  String get appHelloFromTheOther => 'Hello from the other side';

  @override
  String get appIdentityRestored => 'Identity restored';

  @override
  String get appIdentityCreated => 'Identity created';

  @override
  String get appStartingTor30s => 'Starting tor (~30s)...';

  @override
  String get appScanOrImportA => 'Scan or import a peer first';

  @override
  String get appEncryptingSending30s => 'Encrypting + sending (~30s)...';

  @override
  String get appTapStartListeningFirst => 'Tap start listening first';

  @override
  String get appYourKryfo => 'Your Kryfo';

  @override
  String get appUriCopied => 'Uri copied';

  @override
  String get appCopyUri => 'Copy uri';

  @override
  String get appAddAKryfo => 'Add a Kryfo';

  @override
  String get appScanQr => 'Scan qr';

  @override
  String get appPairingCode => 'Pairing code';

  @override
  String get appOrPaste => '- Or paste -';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get appImport => 'Import';

  @override
  String get appDev => 'Dev';

  @override
  String get appYourKryfo2 => 'Your Kryfo:';

  @override
  String get appRestoredFromDisk => 'Restored from disk';

  @override
  String get appStartListening => 'Start listening';

  @override
  String get appListening => 'Listening';

  @override
  String get appShowMyQr => 'Show my qr';

  @override
  String get appImportPeer => 'Import peer';

  @override
  String get appPeer => 'Peer:';

  @override
  String get appMessageWillBeEncrypted => 'Message (will be encrypted)';

  @override
  String get appEncryptSend => 'Encrypt + send';

  @override
  String appStatus(Object status) {
    return 'Status: $status';
  }

  @override
  String get appSpeedPrivacy => 'Speed & privacy →';

  @override
  String get appGettingMessages => 'Getting messages →';

  @override
  String get appDisableAppLock => 'Disable app lock?';

  @override
  String get appThePinWillBe =>
      'The PIN will be removed. Anyone with your phone will see Kryfo when they open it.';

  @override
  String get appDisable => 'Disable';

  @override
  String get appAppLockOn => 'App lock · on →';

  @override
  String get appAppLockOff => 'App lock · off →';

  @override
  String get appTorIsOff => 'Tor is off';

  @override
  String get appConnectedRoutedThrough3 =>
      'Connected · routed through 3 relays';

  @override
  String get appReadyToSendPublishing =>
      'Ready to send · publishing your address';

  @override
  String get appReadyToSendFinishing => 'Ready to send · finishing setup';

  @override
  String appConnecting(Object pct) {
    return 'Connecting · $pct';
  }

  @override
  String get appTor => 'Tor';

  @override
  String get appTorIsOffTurn => 'Tor is off. Turn it on to connect privately.';

  @override
  String get appTheFirstConnectionTakes =>
      'The first connection takes a minute or two while tor builds a private route. After that it is cached, so opening Kryfo later is much faster.';

  @override
  String get appTorNoRelayYet =>
      'Tor is up, but no relay is answering yet. Kryfo keeps trying, and messages wait here until one does.';

  @override
  String get appRelayAndFastModes =>
      'Relay and fast modes skip tor and are quicker. They are in settings, under speed & privacy, and each says what it costs.';

  @override
  String get appViaRelay => 'Via relay';

  @override
  String get appOffline => 'Offline';

  @override
  String get appFast => 'Fast';

  @override
  String get appTorOff => 'Tor off';

  @override
  String get appTorReady => 'Tor ready';

  @override
  String get appConnecting2 => 'Connecting';

  @override
  String mediaProgressSendingKeepTheApp(Object v) {
    return 'Sending · $v · keep the app open';
  }

  @override
  String mediaProgressPausedOfWaitingFor(Object count, Object count2) {
    return 'Paused · $count of $count2 · waiting for the rest';
  }

  @override
  String mediaProgressReceivingMedia(Object v) {
    return 'Receiving media · $v';
  }

  @override
  String get mediaProgressCancelSending => 'Cancel sending';

  @override
  String get metaReaderEndsBeforeItShould => 'ends before it should';

  @override
  String get metaReaderCouldNotBeRead => 'could not be read';

  @override
  String get metaReaderExifThatCannotBe => 'exif that cannot be read';

  @override
  String get metaReaderSamsungTrailer => 'samsung trailer';

  @override
  String metaReaderChunk(Object type) {
    return 'chunk $type';
  }

  @override
  String get metaReaderExifFlagSet => 'exif flag set';

  @override
  String get metaReaderXmpFlagSet => 'xmp flag set';

  @override
  String metaReaderAppBlock(Object id) {
    return 'app block $id';
  }

  @override
  String get metaReaderUuidBox => 'uuid box';

  @override
  String metaReaderBox(Object printable) {
    return '$printable box';
  }

  @override
  String get metaReaderAttachedData => 'attached data';

  @override
  String metaReaderItem(Object printable) {
    return '$printable item';
  }

  @override
  String get miuiAutostartAlreadyAllowedToRun =>
      'Already allowed to run in the background';

  @override
  String get miuiAutostartLetKryfoRunIn => 'Let Kryfo run in the background';

  @override
  String get miuiAutostartYourPhonePausesApps =>
      'Your phone pauses apps to save battery. Without an exception, Kryfo cannot receive messages while it is closed.';

  @override
  String get commonAllow => 'Allow';

  @override
  String get commonSkip => 'Skip';

  @override
  String get miuiAutostartXiaomiTurnsOffBackground =>
      'Xiaomi turns off background apps by default. Without autostart, Kryfo cannot deliver messages when the app is closed. On the next screen, find Kryfo in the list and turn the toggle on.';

  @override
  String get miuiAutostartOpenSettings => 'Open settings';

  @override
  String get miuiAutostartCouldnTOpenIt =>
      'Couldn\'t open it. Look for autostart in phone settings';

  @override
  String get notificationsNewEncryptedMessagesFrom =>
      'New encrypted messages from your contacts';

  @override
  String get notificationsNewMessage => 'New message';

  @override
  String get notificationsNewEncryptedMessagesFromYourContacts =>
      'New encrypted messages from your contacts';

  @override
  String get notificationsNewMessage2 => 'New message';

  @override
  String get notificationsEncrypted => 'Encrypted';

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
  String get rooms24Hours => '24 hours';

  @override
  String roomsDays(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString days',
      one: '$countString day',
    );
    return '$_temp0';
  }

  @override
  String get roomsAnHour => 'an hour';

  @override
  String get roomsAboutAnHour => 'about an hour';

  @override
  String roomsHours(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString hours',
      one: '$countString hour',
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
      other: 'about $countString hours',
      one: 'about $countString hour',
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
  String get roomsAMinute => 'a minute';

  @override
  String get roomsExpired => 'Expired';

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
  String get scamShieldLooksLikeAScam => 'Looks like a scam';

  @override
  String scamShieldThisNameMatches(Object shown) {
    return 'This name matches $shown';
  }

  @override
  String scamShieldNameMatchesYourContact(Object shown) {
    return 'Name matches your contact $shown';
  }

  @override
  String scamShieldSameFaceAsYour(Object shown) {
    return 'Same face as your contact $shown';
  }

  @override
  String get scamShieldContainsACryptoAddress => 'Contains a crypto address';

  @override
  String get scamShieldMentionsMoneyAndUrgency =>
      'Mentions money and urgency together';

  @override
  String get scamShieldAsksYouToMove => 'Asks you to move to another app';

  @override
  String get scamShieldLinksToALookalike =>
      'Links to a lookalike of a well-known site';

  @override
  String get scamShieldALongOpenerFrom =>
      'A long opener from someone with no history';

  @override
  String get scamShieldAsksForACode =>
      'Asks for a code, seed phrase or recovery file';

  @override
  String scamShieldAlso(Object shown) {
    return 'Also: name matches your contact $shown';
  }

  @override
  String get commonBack => 'Back';

  @override
  String get archivedArchived => 'Archived';

  @override
  String get archivedCount0 => 'No';

  @override
  String get archivedCount1 => 'One';

  @override
  String get archivedCount2 => 'Two';

  @override
  String get archivedCount3 => 'Three';

  @override
  String get archivedCount4 => 'Four';

  @override
  String get archivedCount5 => 'Five';

  @override
  String get archivedCount6 => 'Six';

  @override
  String get archivedCount7 => 'Seven';

  @override
  String get archivedCount8 => 'Eight';

  @override
  String get archivedCount9 => 'Nine';

  @override
  String get archivedCount10 => 'Ten';

  @override
  String get archivedChatRestingHereIt =>
      'Chat resting here. It stays quiet until they write, then comes back to the top.';

  @override
  String get archivedChatsRestingHere =>
      'Chats resting here. They stay quiet until someone writes, then come back to the top.';

  @override
  String get archivedNothingArchived => 'Nothing archived';

  @override
  String get archivedArchivedChatsAreStill =>
      'Archived chats are still end-to-end encrypted';

  @override
  String get archivedUnarchive => 'Unarchive';

  @override
  String get avatarPickerThePeopleYouMessage =>
      'The people you message see this too';

  @override
  String get avatarPickerBackToYourInitial => 'Back to your initial';

  @override
  String get avatarPickerThatOneIsYours => 'That one is yours';

  @override
  String get avatarPickerPickAFace => 'Pick a face';

  @override
  String get commonSave => 'Save';

  @override
  String get backupPassphraseMustBeAt =>
      'Passphrase must be at least 6 characters';

  @override
  String get backupPassphrasesDonTMatch => 'Passphrases don\'t match';

  @override
  String get backupBackupSavedKeepThe =>
      'Backup saved · keep the passphrase safe';

  @override
  String get backupKryfoBackup => 'Kryfo backup';

  @override
  String get backupYourEncryptedKryfoBackup =>
      'Your encrypted Kryfo backup. Keep both this file AND your passphrase safe - you need both to restore.';

  @override
  String get backupBackUpKryfo => 'Back up Kryfo';

  @override
  String get backupBackUp => 'Back up';

  @override
  String get backupACopyToKeep =>
      'A copy to keep. This phone carries on as it is.';

  @override
  String get backupMoveToAnotherDevice => 'Move to another device';

  @override
  String get backupTheFileTakesThis =>
      'The file takes this identity with it. Once it is made, this phone stops: nothing new arrives here, and nothing sent from here reaches anyone.';

  @override
  String get backupOneEncryptedFileYour =>
      'One encrypted file: your identity, your contacts, every message, and every photo, voice note and file. Import it on the other device with the passphrase. Until you do, you can still change your mind and stay on this phone.';

  @override
  String get backupOneEncryptedFileYourIdentityYour =>
      'One encrypted file: your identity, your contacts, every message, and every photo, voice note and file on this phone right now. Anything said after today is not in it, so make another when it matters. To restore you need the file and the passphrase, both.';

  @override
  String get backupPassphrase => 'Passphrase';

  @override
  String get backupConfirmPassphrase => 'Confirm passphrase';

  @override
  String backupWriting(Object progress) {
    return 'Writing… $progress';
  }

  @override
  String get backupCreating => 'Creating…';

  @override
  String get backupMakeTheFileAnd => 'Make the file and move';

  @override
  String get backupCreateBackup => 'Create backup';

  @override
  String get backupNotMade => 'The backup could not be made. Try again.';

  @override
  String get backupHiddenNotIn => 'Hidden chats are not in it.';

  @override
  String get backupHiddenIncluded => 'Your hidden chats are in it too.';

  @override
  String get backupMoveHiddenStay =>
      'Hidden chats stay on this phone and are wiped with it.';

  @override
  String get backupHiddenGone =>
      'Your hidden chats closed when Kryfo locked. Open them with their PIN and back up from there.';

  @override
  String get blockedBlocked => 'Blocked';

  @override
  String get blockedNoOneIsBlocked => 'No one is blocked';

  @override
  String get commonUnblock => 'Unblock';

  @override
  String get bridgesThatWasNotIt => 'That was not it. Here is another.';

  @override
  String get bridgesMoatFailed =>
      'Couldn\'t reach the tor project. Try again in a minute, or paste a bridge line below.';

  @override
  String get bridgesGotBridgesSaveTo => 'Got bridges · save to use them';

  @override
  String get bridgesConnected => 'Connected';

  @override
  String get bridgesNotThroughYetTor => 'Not through yet. Tor keeps trying';

  @override
  String get bridgesBridges => 'Bridges';

  @override
  String get bridgesTorIsBlockedWhere => 'Tor is blocked where you are?';

  @override
  String get bridgesBridgesDisguiseYourConnection =>
      'Bridges disguise your connection so it can get out. Pick one way in, save, and tor reconnects through it.';

  @override
  String get bridgesBridgesOnlyChangeHow =>
      'Bridges only change how tor connects, and you are not on onion mode right now. What you set here is saved, it just does nothing until you switch back.';

  @override
  String get bridgesFromTheTorProject => 'From the tor project';

  @override
  String get bridgesNoise => 'Noise';

  @override
  String get bridgesGood => 'Good';

  @override
  String get bridgesMakesTorTrafficLook =>
      'Makes tor traffic look like nothing in particular. The best default for most blocked networks. Answers a captcha, then hands you a few lines.';

  @override
  String get bridgesPrivateBridge => 'Private bridge';

  @override
  String get bridgesALineFromA => 'A line from a friend';

  @override
  String get bridgesWhateverTheLineSays => 'Whatever the line says';

  @override
  String get bridgesDepends => 'Depends';

  @override
  String get bridgesGotABridgeLine =>
      'Got a bridge line from someone you trust, or from bridges.torproject.org? Paste it here. Obfs4 lines only, Kryfo does not speak the others yet.';

  @override
  String get bridgesPasteFromClipboard => 'Paste from clipboard';

  @override
  String get bridgesUseBridges => 'Use bridges';

  @override
  String get bridgesNoLinesYet => 'No lines yet';

  @override
  String bridges1LineSaved(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString lines saved',
      one: '$countString line saved',
    );
    return '$_temp0';
  }

  @override
  String get bridgesRestartingTor => 'Restarting tor…';

  @override
  String bridgesFindingABridgeS(Object elapsed) {
    return 'Finding a bridge… ${elapsed}s';
  }

  @override
  String bridgesStillTryingS(Object elapsed) {
    return 'Still trying… ${elapsed}s';
  }

  @override
  String get bridgesApplying => 'Applying…';

  @override
  String get bridgesSaveAndReconnect => 'Save and reconnect';

  @override
  String get bridgesWhatABridgeIs => 'What a bridge is';

  @override
  String get bridgesATorEntryPoint =>
      'A tor entry point nobody has published, reached through a wrapper so the connection does not look like tor. The rest of the route is the usual three hops.';

  @override
  String get bridgesLooksLike => 'Looks like';

  @override
  String get bridgesSpeed => 'Speed';

  @override
  String get bridgesGetBridges => 'Get bridges';

  @override
  String get bridgesAskTheTorProject =>
      'Ask the tor project directly. You solve a puzzle so bots cannot drain the supply.';

  @override
  String get bridgesTypeWhatYouSee => 'Type what you see. Lowercase is fine.';

  @override
  String get bridgesThisOneRequestDoes =>
      'This one request does not go through tor - it cannot, since tor is what is not working. Whoever runs your network will see you contacting the tor project. If that alone is a problem where you are, get bridges somewhere else and paste them below.';

  @override
  String get bridgesCouldNotDrawThe => 'Could not draw the puzzle';

  @override
  String get bridgesAnswer => 'Answer';

  @override
  String get bridgesAsking => 'Asking…';

  @override
  String get bridgesRequestBridges => 'Request bridges';

  @override
  String get bridgesDifferentPuzzle => 'Different puzzle';

  @override
  String get cameraNoCameraOnThis => 'No camera on this phone';

  @override
  String get cameraCameraNotAvailable => 'Camera not available';

  @override
  String get cameraCameraPermissionIsOff => 'Camera permission is off';

  @override
  String get cameraOpenSettings => 'Open settings';

  @override
  String get cameraCouldNotStripThat =>
      'Could not strip that photo, dropped it';

  @override
  String get cameraNoPhotoCameOut => 'No photo came out';

  @override
  String get cameraCouldNotStartRecording => 'Could not start recording';

  @override
  String get cameraTheRecordingWasLost => 'The recording was lost';

  @override
  String get cameraACopyIsIn => 'A copy is in your photos';

  @override
  String get cameraCouldNotSaveA => 'Could not save a copy on this phone';

  @override
  String get cameraTooLongForA => 'Too long for a message · 8 MB max';

  @override
  String get cameraNeverSavedToYour => 'Never saved to your photos';

  @override
  String get cameraNoExifNeverSaved => 'No EXIF, never saved to your photos';

  @override
  String get cameraRec => 'Rec';

  @override
  String get cameraSwitchCamera => 'Switch camera';

  @override
  String cameraClipSMb(Object secs, Object mb) {
    return 'Clip · ${secs}s · $mb MB';
  }

  @override
  String get cameraStopRecording => 'Stop recording';

  @override
  String get cameraStartRecording => 'Start recording';

  @override
  String get cameraTakeAPhoto => 'Take a photo';

  @override
  String get cameraKeepACopy => 'Keep a copy';

  @override
  String get cameraUseThis => 'Use this';

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
      'You are offline · this sends itself when you reconnect';

  @override
  String get chatStillConnectingToTor =>
      'Still connecting to Tor · it\'ll go out on its own';

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
  String get chatNewMessages => 'New messages';

  @override
  String get chatUnsave => 'Unsave';

  @override
  String get chatForward => 'Forward';

  @override
  String get commonShare => 'Share';

  @override
  String get commonCopied => 'Copied';

  @override
  String get commonCopy => 'Copy';

  @override
  String get chatUnpin => 'Unpin';

  @override
  String get chatPin => 'Pin';

  @override
  String get chatStopSending => 'Stop sending';

  @override
  String get chatUnsend => 'Unsend';

  @override
  String get commonEdit => 'Edit';

  @override
  String get chatYou => 'You';

  @override
  String get chatUnsendMessage => 'Unsend message';

  @override
  String get chatItDisappearsWithNo =>
      'It disappears with no trace. This can\'t be undone.';

  @override
  String chatThisChatHasPins(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'This chat has $countString pins already',
      one: 'This chat has $countString pin already',
    );
    return '$_temp0';
  }

  @override
  String get chatUnpinThisMessage => 'Unpin this message?';

  @override
  String get chatPinThisMessage => 'Pin this message?';

  @override
  String get chatItLeavesThePinned =>
      'It leaves the pinned list for both of you.';

  @override
  String get chatItGoesUnderThe =>
      'It goes under the pin at the top of the chat, for both of you.';

  @override
  String get chatPinIt => 'Pin it';

  @override
  String get chatNotNow => 'Not now';

  @override
  String get chatEditMessage => 'Edit message';

  @override
  String get chat30Seconds => '30 seconds';

  @override
  String get chat1Minute => '1 minute';

  @override
  String get chat5Minutes => '5 minutes';

  @override
  String get chat1Hour => '1 hour';

  @override
  String get chat24Hours => '24 hours';

  @override
  String get chatGhostTimer => 'Timed messages';

  @override
  String get chatHowLongAfterReading =>
      'How long after they\'re read do messages burn? Yours count from when you send them.';

  @override
  String get chatCamera => 'Camera';

  @override
  String get chatNoExifNeverSaved => 'No exif, never saved to your photos';

  @override
  String get chatGallery => 'Gallery';

  @override
  String get chatVideo => 'Video';

  @override
  String get chatGifFromPhone => 'Gif from phone';

  @override
  String get chatFile2 => 'File';

  @override
  String get chatAFewSeconds => 'A few seconds';

  @override
  String get chatUnderAMinute => 'Under a minute';

  @override
  String chatRoughlyMin(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Roughly $countString min',
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
  String get chatSendThis => 'Send this file?';

  @override
  String chatOverTor(Object humanBytes, Object wireEstimate) {
    return '$humanBytes · $wireEstimate over tor';
  }

  @override
  String get chatBigFilesGoOut =>
      'Big files go out in small encrypted pieces, so they take a while. Keep the app open and it keeps going.';

  @override
  String get chatSendIt => 'Send it';

  @override
  String get chatCouldNotReadThat => 'Could not read that file';

  @override
  String get chatFileTooBig8 => 'File too big · 8 mb max';

  @override
  String get chatCouldNotCleanThat => 'Could not clean that video';

  @override
  String get chatCouldNotCleanThatPictureSend =>
      'Could not clean that picture · send it as a photo';

  @override
  String get chatGifTooBig8 => 'Gif too big · 8 mb max';

  @override
  String get chatCouldNotCleanThatGif => 'Could not clean that gif';

  @override
  String get chatTorIsNotUp => 'Tor is not up yet · sending without';

  @override
  String get chatCouldnTReachIt => 'Couldn\'t reach it · sending without';

  @override
  String get chatNoTitleCameBack => 'No title came back · sending without';

  @override
  String get chatCouldnTFetchIt => 'Couldn\'t fetch it · sending without';

  @override
  String get chatNoSignalSessionRe => 'No signal session - re-pair';

  @override
  String get chatMessageUnavailable => 'Message unavailable';

  @override
  String get chatYou2 => 'You';

  @override
  String get chatThem => 'Them';

  @override
  String get chatVoiceMessage => 'Voice message';

  @override
  String get chatQuotedPhoto => 'Photo';

  @override
  String get chatViewContact => 'View contact';

  @override
  String get chatSharedPhotos => 'Shared photos';

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
  String get chatUnmuteNotifications => 'Unmute notifications';

  @override
  String get chatMuteNotifications => 'Mute notifications';

  @override
  String get chatArchiveChat => 'Archive chat';

  @override
  String get chatWallpaper => 'Wallpaper';

  @override
  String get chatClearConversation => 'Clear conversation';

  @override
  String get chatNoteOnThisContact => 'Note on this contact';

  @override
  String get chatPinToTop => 'Pin to top';

  @override
  String get chatBlockContact => 'Block contact';

  @override
  String get chatUnpinned => 'Unpinned';

  @override
  String get chatPinnedToTop => 'Pinned to top';

  @override
  String get chatJustForYouNever =>
      'Just for you. Never sent, never leaves this phone.';

  @override
  String get chatAQuietReminder => 'A quiet reminder…';

  @override
  String get chatNoteSaved => 'Note saved';

  @override
  String get chatClearThisConversation => 'Clear this conversation?';

  @override
  String get chatEveryMessageHereIs =>
      'Every message here is erased from this phone. This only clears your copy - it does not touch their device.';

  @override
  String get chatClear => 'Clear';

  @override
  String get chatBlockThisContact => 'Block this contact?';

  @override
  String get chatTheirMessagesStopArriving =>
      'Their messages stop arriving and they disappear from your chats. They\'re never told. You can unblock anytime from settings.';

  @override
  String get commonBlock => 'Block';

  @override
  String get chatSaved => 'Saved';

  @override
  String get chatRemovedFromSaved => 'Removed from saved';

  @override
  String get chatForwardTo => 'Forward to';

  @override
  String get chatNoContactsToForward => 'No contacts to forward to';

  @override
  String get chatToday => 'Today';

  @override
  String get chatYesterday => 'Yesterday';

  @override
  String get chatThisMessageCanT => 'This message can\'t be shown';

  @override
  String get chatJumpToTheNewest => 'Jump to the newest';

  @override
  String get chatBuildingAPrivateRoute =>
      'Building a private route · first connect is the slow one, later ones are quick. Anything you send now is queued and delivers itself.';

  @override
  String get chatLooksSafeNothingSuspicious =>
      'Looks safe · nothing suspicious in their first message';

  @override
  String get chatTheNextPhotoYou =>
      'The next photo you send opens protected · they cannot screenshot it';

  @override
  String get chatPhotoProtectionOff => 'Photo protection off';

  @override
  String get chatAcceptToReplyThey =>
      'Accept to reply - they get one more message in until you do.';

  @override
  String chatIntroducedYouAcceptTo(Object introducer) {
    return '$introducer introduced you. Accept to reply.';
  }

  @override
  String chatIntroducedYouSayHello(Object vouchNames) {
    return '$vouchNames introduced you. Say hello - they got your card too.';
  }

  @override
  String get chatIntroduceTo => 'Introduce to...';

  @override
  String get chatAcceptThemFirst => 'Accept them first';

  @override
  String get chatMessageRequest => 'Message request';

  @override
  String get chatTheyNeedToAccept =>
      'They need to accept before you can keep chatting.';

  @override
  String get chatWaitingForThemTo => 'Waiting for them to accept your request';

  @override
  String get chatYouBlockedThisContact => 'You blocked this contact';

  @override
  String get chatSupporter => 'Supporter';

  @override
  String get chatEncryptedViaRelay => 'Encrypted · via relay';

  @override
  String get chatEncryptedDirect => 'Encrypted · direct';

  @override
  String get chatEncryptedOverTor => 'Encrypted · over tor';

  @override
  String get chatSearchThisChat => 'Search this chat';

  @override
  String get chatContactOptions => 'Contact options';

  @override
  String get commonClose => 'Close';

  @override
  String get chatFindInConversation => 'Find in conversation';

  @override
  String get chatNoMatches => 'No matches';

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
      other: '*$posString* of $countString matches',
      one: '*$posString* of $countString match',
    );
    return '$_temp0';
  }

  @override
  String get chatPreviousMatch => 'Previous match';

  @override
  String get chatNextMatch => 'Next match';

  @override
  String get chatPhotoUnavailable => 'Photo unavailable';

  @override
  String get chatDelivered => 'Delivered';

  @override
  String get chatEdited => 'Edited';

  @override
  String get chatFailedTapToRetry => 'Failed · tap to retry';

  @override
  String get chatReplyingTo => 'Replying to them';

  @override
  String get chatReplyingToYourself => 'Replying to yourself';

  @override
  String get chatReply => 'Reply';

  @override
  String get chatSayHi => 'Say hi.';

  @override
  String get chatJustTheTwoOf => 'Just the two of you, end-to-end encrypted.';

  @override
  String get chatMicPermissionNeeded => 'Mic permission needed';

  @override
  String get chatTheMicWouldNot => 'The mic would not start. Try again';

  @override
  String get chatReleaseToCancel => 'Release to cancel';

  @override
  String get chatVoiceHiddenSlideTo => 'Voice hidden · slide to cancel';

  @override
  String get chatSlideToCancel => 'Slide to cancel';

  @override
  String get chatGhostMode => 'Timed messages';

  @override
  String chatMessagesBurnAfter(Object humanBurn) {
    return 'burn after $humanBurn';
  }

  @override
  String get chatTimedMessages => 'Timed messages';

  @override
  String get chatOpenTheCamera => 'Open the camera';

  @override
  String get chatAttachAPhoto => 'Attach a photo';

  @override
  String get chatMessage => 'Message';

  @override
  String get chatDisguiseVoice => 'Disguise voice';

  @override
  String get commonSend => 'Send';

  @override
  String get chatNoPhotosInThis => 'No photos in this chat yet';

  @override
  String get chatHoldToRecord => 'Hold to record a voice note';

  @override
  String get chatSendPhoto => 'Send photo';

  @override
  String get chatAddACaption => 'Add a caption…';

  @override
  String get chatSecurityCodeChanged => 'Security code changed';

  @override
  String chatMayHaveReinstalledOr(Object peerName) {
    return '$peerName may have reinstalled, or someone could be impersonating them. Compare safety numbers to be sure.';
  }

  @override
  String get chatOk => 'Ok';

  @override
  String get chatVerify => 'Verify';

  @override
  String get cleanKryfoCanTClean => 'Kryfo can’t clean this kind of file yet.';

  @override
  String get cleanThisIsAMotion => 'This is a motion photo.';

  @override
  String get cleanThisPictureIsToo =>
      'This picture is too large to clean here.';

  @override
  String get cleanThisFileIsDamaged => 'This file is damaged or cut short.';

  @override
  String get cleanKryfoCouldNotMake => 'Kryfo could not make this one clean.';

  @override
  String get cleanNotEnoughRoomOn => 'Not enough room on the phone.';

  @override
  String get cleanKryfoCouldNotOpen => 'Kryfo could not open that file.';

  @override
  String get cleanItCleansJpegPng =>
      'It cleans JPEG, PNG, WebP, HEIC, AVIF, GIF, MP4 and MOV. Nothing was changed.';

  @override
  String get cleanItHoldsAShort =>
      'It holds a short video beside the picture, and Kryfo can’t clean that part yet. Turn motion off in your camera, or send a screenshot of it.';

  @override
  String get cleanPicturesOver64Mb =>
      'Pictures over 64 MB are not cleaned on the phone. Nothing was changed.';

  @override
  String get cleanKryfoCouldNotRead =>
      'Kryfo could not read it to the end, so it won’t call it clean. No copy was made.';

  @override
  String get cleanSomethingInsideIsOf =>
      'Something inside is of a kind it does not know how to remove, so no copy was made.';

  @override
  String get cleanFreeSomeSpaceAnd =>
      'Free some space and try again. Nothing was changed.';

  @override
  String get cleanTheAppThatShared =>
      'The app that shared it may have taken it back. Try sharing it again.';

  @override
  String get cleanNoAppOnThis => 'No app on this phone took the file.';

  @override
  String get cleanCouldNotSaveIt =>
      'Could not save it. Check the phone has room.';

  @override
  String get cleanTheOriginalIsGone =>
      'The original is gone. The clean copy stays.';

  @override
  String get cleanAndroidWouldNotDelete =>
      'Android would not delete it. Remove it from the gallery by hand.';

  @override
  String get cleanCleanCopy => 'Clean copy';

  @override
  String get cleanShareCleanCopy => 'Share clean copy';

  @override
  String get cleanSaveToGallery => 'Save to gallery';

  @override
  String get commonStop => 'Stop';

  @override
  String get cleanReadingTheFile => 'Reading the file';

  @override
  String get cleanCleaning => 'Cleaning';

  @override
  String cleanOf(Object prettySize, Object prettySize2) {
    return '$prettySize of $prettySize2';
  }

  @override
  String get cleanEverythingStaysOnThis => 'Everything stays on this phone.';

  @override
  String get cleanAlreadyClean => 'Already clean.';

  @override
  String get cleanClean => 'Clean.';

  @override
  String get cleanThereWasNothingTo => 'There was nothing to find.';

  @override
  String get cleanNothingLeftToFind => 'Nothing left to find.';

  @override
  String get cleanSameVideoSameQuality => 'Same video, same quality';

  @override
  String get cleanSamePictureSameQuality => 'Same picture, same quality';

  @override
  String cleanRemoved(Object label) {
    return '$label, removed';
  }

  @override
  String get cleanRemoved2 => 'REMOVED';

  @override
  String get cleanWithTheLocationInside =>
      'with the location inside. Anyone who gets that one gets your street.';

  @override
  String get cleanWithEverythingItKnew =>
      'with everything it knew still inside.';

  @override
  String get cleanOriginal => 'ORIGINAL';

  @override
  String get cleanClean2 => 'CLEAN';

  @override
  String get cleanSavedToYourGallery => 'Saved to your gallery.';

  @override
  String cleanTheOriginalIsStill(Object what) {
    return 'The original is still there too, $what';
  }

  @override
  String cleanTheOriginalIsStillWhereIt(Object what) {
    return 'The original is still where it was, $what Kryfo can’t remove it from here, so delete it in the app it came from.';
  }

  @override
  String get cleanDeleteTheOriginal => 'Delete the original';

  @override
  String get cleanKeepBoth => 'Keep both';

  @override
  String get commonDone => 'Done';

  @override
  String get cleanAndroidWillAskYou => 'ANDROID WILL ASK YOU TO CONFIRM';

  @override
  String get contactYourNameForThem => 'Your name for them';

  @override
  String get contactStaysOnThisPhone =>
      'Stays on this phone. They never see it.';

  @override
  String get contactClear => 'Clear';

  @override
  String get contactMessage => 'Message';

  @override
  String get contactKeysVerified => 'Keys verified';

  @override
  String get contactVerifyKeys => 'Verify keys';

  @override
  String get contactVouches => 'Vouches';

  @override
  String get contactUnmute => 'Unmute';

  @override
  String get contactMute => 'Mute';

  @override
  String get contactUnpin => 'Unpin';

  @override
  String get contactPinToTop => 'Pin to top';

  @override
  String get contactArchive => 'Archive';

  @override
  String get contactOutOfTheList => 'Out of the list until they write again';

  @override
  String contactBlock(Object name) {
    return 'Block $name?';
  }

  @override
  String get contactTheirMessagesStopArriving =>
      'Their messages stop arriving. They are not told.';

  @override
  String get contactDeleteChat => 'Delete chat';

  @override
  String get contactMessagesAndContactGone =>
      'Messages and contact, gone from this phone';

  @override
  String get contactDeleteThisChat => 'Delete this chat?';

  @override
  String get contactEveryMessageAndThe =>
      'Every message and the contact, gone from this phone. Nothing is sent to them.';

  @override
  String get commonDelete => 'Delete';

  @override
  String get contactDeleted => 'Deleted';

  @override
  String get contactToday => 'Today';

  @override
  String contactD(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '${count}d',
    );
    return '$_temp0';
  }

  @override
  String contactMo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '${count}mo',
    );
    return '$_temp0';
  }

  @override
  String contactY(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '${count}y',
    );
    return '$_temp0';
  }

  @override
  String get contactVerified => 'Verified';

  @override
  String get contactChatting => 'Chatting';

  @override
  String get contactNothingSharedYet => 'Nothing shared yet';

  @override
  String contactSharedMedia(Object count) {
    return 'Shared media · $count';
  }

  @override
  String get donateBitcoin => 'Bitcoin';

  @override
  String get donateText => '₿';

  @override
  String get donateBadgeUnlocks => 'Badge unlocks';

  @override
  String get donateMonero => 'Monero';

  @override
  String get donateManualNoBadge => 'Manual · no badge';

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
          'Your earlier bitcoin payment was seen · supporter badge unlocked',
      'patron': 'Your earlier bitcoin payment was seen · patron badge unlocked',
      'guardian':
          'Your earlier bitcoin payment was seen · guardian badge unlocked',
      'other':
          'Your earlier bitcoin payment was seen · supporter badge unlocked',
    });
    return '$_temp0';
  }

  @override
  String get donateSupport => 'Support';

  @override
  String get donateKeepKryfo => 'Keep Kryfo *independent*';

  @override
  String get donateNoAdsNoInvestors =>
      'No ads, no investors, nothing to sell. It runs on what backers give.';

  @override
  String get donateBackItAnonymouslyBadge =>
      'Back it anonymously. Badge opt-in.\n*Privacy is never behind a paywall.*';

  @override
  String donateAddressCheckItAgainst(Object coinName) {
    return '$coinName address · check it against your wallet';
  }

  @override
  String get donateAddressCopiedClearsIn => 'Address copied · clears in 60s';

  @override
  String get donateCopyAddress => 'Copy address';

  @override
  String get donateBitcoinIsVerifiedBy =>
      'Bitcoin is verified by our own node, so your badge unlocks by itself once the payment lands.';

  @override
  String get donateWeCanTVerify =>
      'We can\'t verify this chain without asking an outside service about you, so we don\'t. Send it if you like. It won\'t unlock a badge.';

  @override
  String get donateBitcoinBadgesNeedOnion => 'Bitcoin badges need onion mode';

  @override
  String get donateSwitchToOnion => 'Switch to onion';

  @override
  String get donatePayWithBitcoin => 'Pay with bitcoin  →';

  @override
  String get donateBadgesStartAt20 => 'Badges start at \$20';

  @override
  String get donateReachingThePaymentService =>
      'Reaching the payment service over tor…';

  @override
  String get donateThisCanTakeUp => 'This can take up to a minute';

  @override
  String donateSThisCanTake(Object waited) {
    return '${waited}s · this can take up to a minute';
  }

  @override
  String get donateUseTheAddressInstead => 'Use the address instead';

  @override
  String get donateThePaymentServiceIs =>
      'The payment service is an onion, and only onion mode can reach it. Nothing was sent.';

  @override
  String get donateTorWasSlowTo =>
      'Tor was slow to reach the payment service. You can donate to the address below - your badge just won\'t unlock automatically. Try again later for the badge.';

  @override
  String get donateThePaymentServiceIsHavingTrouble =>
      'The payment service is having trouble right now. You can still donate to the address below - your badge just won\'t unlock automatically. Try again later for the badge.';

  @override
  String get commonTryAgain => 'Try again';

  @override
  String donateBtc(Object btc) {
    return '$btc BTC';
  }

  @override
  String donateSendExactlyThisAmount(Object fmtLeft) {
    return 'Send exactly this amount · expires in $fmtLeft';
  }

  @override
  String get donateOpenWallet => 'Open wallet';

  @override
  String get donateThisScreenUpdatesItself =>
      'This screen updates itself the moment your payment is seen.\nKeep it open - nothing is stored, nothing identifies you.';

  @override
  String get donateWatchingTheChainFor => 'Watching the chain for your payment';

  @override
  String get donateThisInvoiceExpired => 'This invoice expired';

  @override
  String get donateInvoicesTimeOutIf =>
      'Invoices time out. If you already sent the payment, keep this open: we ask the service again every minute for a while, and the next time you open support. Start a fresh one whenever you like.';

  @override
  String get donateNewInvoice => 'New invoice';

  @override
  String get donateIPaidCheckAgain => 'I paid, check again';

  @override
  String get donateNoWallet =>
      'No wallet app here opens bitcoin links. Copy the address instead.';

  @override
  String get donateChecking => 'Checking…';

  @override
  String get donateNotSeenYet =>
      'Not seen yet. A payment can take a few minutes to show.';

  @override
  String get donatePaymentConfirmed => 'Payment confirmed';

  @override
  String get donateThankYouForKeeping =>
      'Thank you for keeping Kryfo independent.';

  @override
  String donateVerifiedOnChainYou(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter':
          'Verified on-chain - you\'re a supporter now. No one can take that off you.',
      'patron':
          'Verified on-chain - you\'re a patron now. No one can take that off you.',
      'guardian':
          'Verified on-chain - you\'re a guardian now. No one can take that off you.',
      'other':
          'Verified on-chain - you\'re a supporter now. No one can take that off you.',
    });
    return '$_temp0';
  }

  @override
  String get donateWearMyBadge => 'Wear my badge';

  @override
  String get donateJustGladToHelp => 'Just glad to help';

  @override
  String get gettingMessagesGettingMessages => 'Getting messages';

  @override
  String get gettingMessagesHowNewMessagesReach =>
      'How new messages reach this phone. You can change it whenever you like.';

  @override
  String get gettingMessagesAlwaysOn => 'Always on';

  @override
  String get gettingMessagesMostPrivate => 'Most private';

  @override
  String get gettingMessagesMessagesArriveInstantlyNothing =>
      'Messages arrive instantly. Nothing leaves Tor. Uses the most battery.';

  @override
  String get gettingMessagesCheckIns => 'Check-ins';

  @override
  String get gettingMessagesLightest => 'Lightest';

  @override
  String get gettingMessagesKryfoLooksForMessages =>
      'Kryfo looks for messages every 15 minutes. Easy on battery, but messages can be late.';

  @override
  String get gettingMessagesOnTheLockScreen => 'On the lock screen';

  @override
  String get gettingMessagesHideMessagePreview => 'Hide message preview';

  @override
  String get gettingMessagesAGenericAlertWith =>
      'A generic alert, with no sender and no message text';

  @override
  String get gettingMessagesShowsMessageTextIn =>
      'Shows message text in notifications, even while Kryfo is locked.';

  @override
  String get gettingMessagesWhenThePhoneSits =>
      'When the phone sits still, Android spaces check-ins further apart. The line above shows the real last one. While Kryfo is open it stays connected.';

  @override
  String get groupChatJumpToTheNewest => 'Jump to the newest';

  @override
  String get groupChatBlockedEverywhere => 'Blocked everywhere';

  @override
  String get groupChatYou => 'You';

  @override
  String get groupChatVoiceMessage => 'Voice message';

  @override
  String get groupChatQuotedPhoto => 'Photo';

  @override
  String get groupChatMessageUnavailable => 'Message unavailable';

  @override
  String get groupChatTorIsNotUp => 'Tor is not up yet · sending without';

  @override
  String get groupChatCouldnTReachIt => 'Couldn\'t reach it · sending without';

  @override
  String get groupChatNoTitleCameBack => 'No title came back · sending without';

  @override
  String get groupChatCouldnTFetchIt => 'Couldn\'t fetch it · sending without';

  @override
  String get groupChatCamera => 'Camera';

  @override
  String get groupChatGallery => 'Gallery';

  @override
  String get groupChatVideo => 'Video';

  @override
  String get groupChatGifFromPhone => 'Gif from phone';

  @override
  String get groupChatFile => 'File';

  @override
  String get groupChatCouldNotReadThat => 'Could not read that file';

  @override
  String get groupChatGifTooBig8 => 'Gif too big · 8 mb max';

  @override
  String get groupChatCouldNotCleanThat => 'Could not clean that gif';

  @override
  String get groupChatFileTooBig8 => 'File too big · 8 mb max';

  @override
  String get groupChatCouldNotCleanThatVideo => 'Could not clean that video';

  @override
  String get groupChatCouldNotCleanThatPictureSend =>
      'Could not clean that picture · send it as a photo';

  @override
  String get groupChat30Seconds => '30 seconds';

  @override
  String get groupChat1Minute => '1 minute';

  @override
  String get groupChat5Minutes => '5 minutes';

  @override
  String get groupChat1Hour => '1 hour';

  @override
  String get groupChat24Hours => '24 hours';

  @override
  String get groupChatBurnTimer => 'Timed messages';

  @override
  String get groupChatNewMessagesDisappearOnceRead =>
      'New messages disappear this long after they\'re read. Yours count from when you send them.';

  @override
  String get groupChatToday => 'Today';

  @override
  String get groupChatYesterday => 'Yesterday';

  @override
  String get groupChatYou2 => 'You';

  @override
  String groupChatThisChatHasPins(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'This chat has $countString pins already',
      one: 'This chat has $countString pin already',
    );
    return '$_temp0';
  }

  @override
  String get groupChatUnpinThisMessage => 'Unpin this message?';

  @override
  String get groupChatPinThisMessage => 'Pin this message?';

  @override
  String get groupChatItLeavesThePinned =>
      'It leaves the pinned list for everyone here.';

  @override
  String get groupChatItGoesUnderThe =>
      'It goes under the pin at the top of the chat, for everyone here.';

  @override
  String get groupChatUnpin => 'Unpin';

  @override
  String get groupChatPinIt => 'Pin it';

  @override
  String get groupChatNotNow => 'Not now';

  @override
  String get groupChatSaved => 'Saved';

  @override
  String get groupChatRemovedFromSaved => 'Removed from saved';

  @override
  String get groupChatForwardTo => 'Forward to';

  @override
  String get groupChatNoContactsToForward => 'No contacts to forward to';

  @override
  String get groupChatEditMessage => 'Edit message';

  @override
  String get groupChatUnsendMessage => 'Unsend message';

  @override
  String get groupChatItDisappearsWithNo =>
      'It disappears with no trace. This can\'t be undone.';

  @override
  String get groupChatUnsend => 'Unsend';

  @override
  String groupChatThisRoomAndEverything(Object expiryWords) {
    return 'This room and everything in it disappears in $expiryWords';
  }

  @override
  String groupChatGhostModeOnBurns(Object fmtBurn) {
    return 'Timed messages · burn after $fmtBurn';
  }

  @override
  String get groupChatGroupCreatedSayHi => 'Group created. Say hi.';

  @override
  String get groupChatNoMessagesYet => 'No messages yet.';

  @override
  String get groupChatEveryoneHereReads =>
      'Everyone here reads what you write.';

  @override
  String get groupChatNobodyHereYet => 'Nobody is here yet.';

  @override
  String get groupChatShareTheRoomLink =>
      'Share the room link. Whoever joins reads what is written from then on.';

  @override
  String get groupChatNobodyToReadIt => 'Nobody else is here to read it.';

  @override
  String get groupChatThisMessageCanT => 'This message can\'t be shown';

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
      other: '$time · $countString here',
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
      other: '$countString members',
      one: '$countString member',
    );
    return '$_temp0';
  }

  @override
  String get groupChatSearchThisChat => 'Search this chat';

  @override
  String groupChatReplyingTo(Object name) {
    return 'Replying to $name';
  }

  @override
  String get groupChatReplyingToYou => 'Replying to you';

  @override
  String get groupChatTimedMessages => 'Timed messages';

  @override
  String get groupChatOpenTheCamera => 'Open the camera';

  @override
  String get groupChatAttachAPhoto => 'Attach a photo';

  @override
  String get groupChatMessage => 'Message';

  @override
  String get groupChatDisguiseVoice => 'Disguise voice';

  @override
  String get groupChatSupporter => 'Supporter';

  @override
  String get groupChatEdited => 'Edited';

  @override
  String get groupChatTapToRetry => '! Tap to retry';

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
      other: 'Sent · $haveString of $countString have it',
      one: 'Sent · $haveString of $countString has it',
      zero: 'Sent · on its way',
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
      other: 'Sent · $countString didn\'t get it',
      one: 'Sent · $countString didn\'t get it',
    );
    return '$_temp0';
  }

  @override
  String get groupChatReply => 'Reply';

  @override
  String get groupChatPin => 'Pin';

  @override
  String get groupChatUnsave => 'Unsave';

  @override
  String get groupChatForward => 'Forward';

  @override
  String get groupInfoGroup => 'Group';

  @override
  String get groupInfoRenameGroup => 'Rename group';

  @override
  String get groupInfoRename => 'Rename';

  @override
  String get groupInfoNoContactsToAdd => 'No contacts to add';

  @override
  String get groupInfoCouldNotAdd => 'Could not add';

  @override
  String groupInfoRemove(Object haloId) {
    return 'Remove $haloId?';
  }

  @override
  String get groupInfoTheyWillStopReceiving =>
      'They will stop receiving messages from this group.';

  @override
  String appGroupHoldsUpTo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'A group holds up to $countString people',
      one: 'A group holds up to $countString person',
    );
    return '$_temp0';
  }

  @override
  String get commonRemove => 'Remove';

  @override
  String get groupInfoClearThisConversation => 'Clear this conversation?';

  @override
  String get groupInfoEveryMessageHereIs =>
      'Every message here is erased from this phone. This only clears your copy, other members keep theirs.';

  @override
  String get groupInfoClear => 'Clear';

  @override
  String get groupInfoConversationCleared => 'Conversation cleared';

  @override
  String get groupInfoLeaveRoom => 'Leave room?';

  @override
  String get groupInfoLeaveGroup => 'Leave group?';

  @override
  String get groupInfoEverythingInItIs =>
      'Everything in it is wiped from this phone now, and the key you used here is gone for good.';

  @override
  String groupChatYouWereRemovedFrom(Object name) {
    return 'You were removed from $name';
  }

  @override
  String get groupInfoLeaveGroupLine =>
      'You will stop receiving its messages, and everything in it is wiped from this phone.';

  @override
  String get groupInfoLeaveGroupAdmin =>
      'You will stop receiving its messages, and everything in it is wiped from this phone. You are its admin, so once you leave no one can change who is in it or rename it.';

  @override
  String get groupInfoLeaveRoomMaker =>
      'Everything in it is wiped from this phone now, and the key you used here is gone for good. You made this room, so its link stops letting anyone in.';

  @override
  String get groupInfoLeave => 'Leave';

  @override
  String get groupInfoGroupInfo => 'Group info';

  @override
  String groupInfo1Member(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString members',
      one: '$countString member',
    );
    return '$_temp0';
  }

  @override
  String get groupInfoAdmin => 'Admin';

  @override
  String get groupInfoMembers2 => 'Members';

  @override
  String get groupInfoInvite => 'Invite';

  @override
  String get commonAdd => 'Add';

  @override
  String get groupInfoYou => 'You';

  @override
  String get groupInfoRemoveFromGroup => 'Remove from group';

  @override
  String get groupInfoWallpaper => 'Wallpaper';

  @override
  String get groupInfoSharedMedia => 'Shared media';

  @override
  String get groupInfoClearConversation => 'Clear conversation';

  @override
  String get groupInfoLeaveRoom2 => 'Leave room';

  @override
  String get groupInfoLeaveGroup2 => 'Leave group';

  @override
  String get groupInfoAddMembers => 'Add members';

  @override
  String groupInfoAdd(Object pickedLength) {
    return 'Add $pickedLength';
  }

  @override
  String handleYouAre(Object h) {
    return 'You are @$h';
  }

  @override
  String get handleHandleDeletedThePage => 'Handle deleted · the page is gone';

  @override
  String get handlePublicHandle => 'Public handle';

  @override
  String get handleOptionalYourThreeWords =>
      'Optional. Your three words keep working either way.';

  @override
  String get handleWren => 'wren';

  @override
  String get handleALineAboutYou => 'A line about you · optional';

  @override
  String get handleClaiming => 'Claiming…';

  @override
  String get handleClaimThisHandle => 'Claim this handle';

  @override
  String get handleAnyoneWithThisLink =>
      'Anyone with this link can start a private chat with you. It carries your invite and nothing else.';

  @override
  String get handleLinkCopied => 'Link copied';

  @override
  String get handleDeleteThisHandle => 'Delete this handle';

  @override
  String handleDeleteTitle(Object handle) {
    return 'Delete @$handle?';
  }

  @override
  String get handleDeleteLine =>
      'Your public page goes away and anyone can claim the name. Chats you already have stay as they are.';

  @override
  String get handleDeleteYes => 'Delete handle';

  @override
  String get handleDeleting => 'Deleting…';

  @override
  String get handleChecking => 'Checking…';

  @override
  String get handleAvailable => '✓ Available';

  @override
  String get handleAlreadyTaken => 'Already taken';

  @override
  String get handleNameRule => '3 to 20 characters: a-z, 0-9 or _';

  @override
  String get handleWhatAHandleDoes => 'What a handle does';

  @override
  String get handleAnyoneWhoKnowsIt =>
      'Anyone who knows it can ask to message you, which is the point of having one. The page holds your invite and the line you wrote, nothing else, and keeps no record of who reads it. You can delete it whenever you like.';

  @override
  String handleIsNotYoursOn(Object handle) {
    return '@$handle is not yours on this phone';
  }

  @override
  String handleTheRegistryHoldsIt(Object handle) {
    return 'The registry holds it under a different key, most likely an identity this phone had before a restore. People who add @$handle are not reaching you. It cannot be released or updated from here. Pick another name.';
  }

  @override
  String get handleForgetItOnThis => 'Forget it on this phone';

  @override
  String get homeAddAContact => 'Add a contact';

  @override
  String get commonSettings => 'Settings';

  @override
  String get homeYourKryfo => 'Your Kryfo';

  @override
  String homeDateWeekday(Object weekday) {
    return '$weekday,';
  }

  @override
  String get homeAnHour => 'an hour';

  @override
  String homeHours(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString hours',
      one: '$countString hour',
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
  String get homeKryfoIsOffline => 'Kryfo is offline';

  @override
  String homeTorHasNotBeen(Object howLong) {
    return 'Tor has not been able to connect for $howLong. Nothing can arrive or leave until it does.';
  }

  @override
  String get homeReconnecting => 'Reconnecting';

  @override
  String get homeReconnect => 'Reconnect';

  @override
  String get homeWhatIsWrong => 'What is wrong';

  @override
  String get homeKryfoWillCheckIn => 'Kryfo will check in every 15 minutes';

  @override
  String get homeYourPhoneKeepsStopping => 'Your phone keeps stopping Kryfo';

  @override
  String get homeItHasClosedKryfo =>
      'It has closed Kryfo three times today, so messages were late or waited. Check-ins survive that: Kryfo wakes every 15 minutes instead of staying connected.';

  @override
  String get homeSwitchToCheckIns => 'Switch to check-ins';

  @override
  String get homeNotNow => 'Not now';

  @override
  String get homeNotificationsAreOff => 'Notifications are off';

  @override
  String get homeAndroidIsBlockingThem =>
      'Android is blocking them, so nothing reaches you while Kryfo is closed. Messages still arrive when you open it.';

  @override
  String get homeCouldnTOpenIt =>
      'Couldn\'t open it. Look for Kryfo in phone settings';

  @override
  String get homeTurnThemOn => 'Turn them on';

  @override
  String get homeLeaveThemOff => 'Leave them off';

  @override
  String get homeOurRelayIsQuiet => 'Our relay is quiet';

  @override
  String get homeRelayModeUsesOnly =>
      'Relay mode uses only our own relay, and it is not answering right now. Fast mode adds public relays alongside it, so messages still land. Everything stays sealed either way.';

  @override
  String get homeSwitchedToFast => 'Switched to fast';

  @override
  String get homeUseFastMode => 'Use fast mode';

  @override
  String get homeKeepWaiting => 'Keep waiting';

  @override
  String get homeNotConnecting => 'Not connecting';

  @override
  String get homeBridgesAreOnAnd =>
      'Bridges are on and tor still is not through. Bridges are slower, and some go dead without warning. If your network does not block tor, going direct is faster and more reliable.';

  @override
  String get homeGoingDirectReconnecting => 'Going direct · reconnecting';

  @override
  String get homeTurnBridgesOff => 'Turn bridges off';

  @override
  String get homeStillTrying => 'Still trying';

  @override
  String get homeTorIsNotGetting =>
      'Tor is not getting through. Some networks block it on purpose. Our own relay is one plain connection and usually works anyway - or bridges, which take longer to set up.';

  @override
  String get homeSwitchedToRelay => 'Switched to relay';

  @override
  String get homeUseOurRelay => 'Use our relay';

  @override
  String get homeBridges => 'Bridges';

  @override
  String get homeOffline => 'Offline';

  @override
  String get homeWaiting => 'Waiting';

  @override
  String get homeNothingWaitingToSend => 'Nothing waiting to send';

  @override
  String homeWaitingSendsWhenYou(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString waiting · sends when you\'re back',
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
      other: '$countString waiting · tor is still connecting',
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
      other: '$countString waiting · sending now',
    );
    return '$_temp0';
  }

  @override
  String get commonRetry => 'Retry';

  @override
  String get homeNoKryfosYet => 'No Kryfos yet.';

  @override
  String get homeScanTheirCodeSend =>
      'Scan their code, send them a link, or type the @handle they gave you.';

  @override
  String get homeAddSomeone => 'Add someone';

  @override
  String get homeArchived => 'Archived';

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
  String get homeGroups => 'Groups';

  @override
  String get homeRoom => 'Room';

  @override
  String get homeNew => 'New';

  @override
  String homeRoomExpired(Object expiredRoomName) {
    return '$expiredRoomName · room expired';
  }

  @override
  String get homeMentionedYou => 'Mentioned you';

  @override
  String homeMembers(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString members',
      one: '$countString member',
    );
    return '$_temp0';
  }

  @override
  String get homeSupporter => 'Supporter';

  @override
  String get homeArchivedChats => 'Archived chats';

  @override
  String get homeUnmute => 'Unmute';

  @override
  String get homeMute => 'Mute';

  @override
  String get homeArchive => 'Archive';

  @override
  String get homeDeleteChat => 'Delete chat';

  @override
  String get homeMessagesAndContactGone =>
      'Messages and contact, gone from this phone';

  @override
  String get homeDeleteThisChat => 'Delete this chat?';

  @override
  String homeEveryMessageWithGoes(Object c) {
    return 'Every message with $c goes, and they stop being a contact. It only clears this phone - their copy stays with them. If they message again it lands in requests.';
  }

  @override
  String get homeQueued => 'Queued';

  @override
  String get homeBlocked => 'Blocked';

  @override
  String get homeRoomInvite => 'Room invite';

  @override
  String get homeNow => 'Now';

  @override
  String homeM(Object inMinutes) {
    return '${inMinutes}m';
  }

  @override
  String homeH(Object inHours) {
    return '${inHours}h';
  }

  @override
  String get homeYesterday => 'Yesterday';

  @override
  String homeD(Object inDays) {
    return '${inDays}d';
  }

  @override
  String get homeNoteToSelf => 'Note to self';

  @override
  String get homeOnlyOnThisPhone => 'Only on this phone';

  @override
  String get homeSaved => 'Saved';

  @override
  String get homeKeptFromEveryChat => 'Kept from every chat';

  @override
  String get homeRequests => 'Requests';

  @override
  String home1PersonWantsTo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString people want to reach you',
      one: '$countString person wants to reach you',
    );
    return '$_temp0';
  }

  @override
  String introduceGotItButCould(Object b, Object c) {
    return '$b got it, but $c could not be reached';
  }

  @override
  String introduceGotItButCouldNotBe(Object c, Object b) {
    return '$c got it, but $b could not be reached';
  }

  @override
  String introduceIntroduced(Object b, Object c) {
    return '$b and $c now have each other\'s card';
  }

  @override
  String get introduceCouldNotReachEither =>
      'Could not reach either of them. Try again later';

  @override
  String introduceIntroduceTo(Object peerName) {
    return 'Introduce $peerName to...';
  }

  @override
  String get introduceBothOfThemGet =>
      'Both of them get the other\'s card. Neither sees your name for the other.';

  @override
  String get introduceNoOneElseTo =>
      'No one else to introduce yet. Add another contact first.';

  @override
  String get introduceANoteLikeMy => 'A note, like \"my cousin\" - optional';

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
      other: '$leftString of $maxString introductions left this week',
      one: '$leftString of $maxString introduction left this week',
    );
    return '$_temp0';
  }

  @override
  String introduceNoIntroductionsLeftNext(Object refillPhrase) {
    return 'No introductions left. Next one frees up $refillPhrase';
  }

  @override
  String get introduceIntroduce => 'Introduce';

  @override
  String get keyVerificationSafetyNumber => 'Safety number';

  @override
  String keyVerificationWith(Object peerName) {
    return 'With $peerName';
  }

  @override
  String keyVerificationIfSeesTheSame(Object peerName) {
    return 'If $peerName sees the same number, your messages are private to just the two of you. Comparing in person or over a call you trust is the surest way to be sure - but it is optional, never required to chat.';
  }

  @override
  String get keyVerificationVerified => 'Verified';

  @override
  String get keyVerificationMarkAsVerified => 'Mark as verified';

  @override
  String get lockFileThatPasswordDoesNot => 'That password does not open it.';

  @override
  String get lockFileThisFileIsDamaged => 'This file is damaged.';

  @override
  String get lockFileThisFileWasLocked =>
      'This file was locked to a key, not a password.';

  @override
  String get lockFileThisIsNotA => 'This is not a locked file.';

  @override
  String get lockFileNotEnoughFreeMemory => 'Not enough free memory right now.';

  @override
  String get lockFileStopped => 'Stopped.';

  @override
  String get lockFileItNeedsAPassword => 'It needs a password.';

  @override
  String get lockFileKryfoCouldNotRead =>
      'Kryfo could not read or write the file.';

  @override
  String get lockFileCheckCapitalsAndSpaces =>
      'Check capitals and spaces. Nobody can reset it, us included.';

  @override
  String get lockFileItMayHaveBeen =>
      'It may have been cut short on the way. Ask for it to be sent again. Nothing was saved.';

  @override
  String get lockFileItOpensWithThe =>
      'It opens with the key file of the person it was made for, in the age tool on a computer. Kryfo opens the password kind.';

  @override
  String get lockFileKryfoOpensFilesLocked =>
      'Kryfo opens files locked with age. Those usually end in .age.';

  @override
  String get lockFileCloseAFewApps =>
      'Close a few apps and try again. The password check needs a few hundred megabytes for a moment.';

  @override
  String get lockFileNothingWasSaved => 'Nothing was saved.';

  @override
  String get lockFileTypeOneOrLet =>
      'Type one, or let Kryfo suggest four words.';

  @override
  String get lockFileTheAppThatHolds =>
      'The app that holds it may have taken it back. Pick it again.';

  @override
  String get lockFileHidePassword => 'Hide password';

  @override
  String get lockFileShowPassword => 'Show password';

  @override
  String get lockFileChangeFile => 'Change file';

  @override
  String get lockFileChange => 'Change';

  @override
  String lockFileOf(Object prettySize, Object prettySize2) {
    return '$prettySize of $prettySize2';
  }

  @override
  String get lockFileEverythingStaysOnThis => 'Everything stays on this phone.';

  @override
  String get lockFileCouldNotMakeOne => 'Could not make one. Type your own.';

  @override
  String get lockFileWriteItDownBefore =>
      'Write it down before you lock the file';

  @override
  String get lockFileNoAppOnThis => 'No app on this phone took the file.';

  @override
  String get lockFileSaved => 'Saved';

  @override
  String get lockFileCouldNotSaveIt =>
      'Could not save it there. Try another folder.';

  @override
  String get lockFileLocked => 'Locked';

  @override
  String get lockFileLockAFile => 'Lock a file';

  @override
  String get lockFileMixingThePassword => 'Mixing the password';

  @override
  String get lockFileLocking => 'Locking';

  @override
  String get lockFileSaveToFiles => 'Save to Files';

  @override
  String get lockFileLockFile => 'Lock file';

  @override
  String get lockFileOnePassword => 'One password.';

  @override
  String get lockFileNothingElseOpensIt => 'Nothing else opens it.';

  @override
  String get lockFileFile => 'File';

  @override
  String lockFileFromFiles(Object prettySize) {
    return '$prettySize · from Files';
  }

  @override
  String get lockFileFromFiles2 => 'From Files';

  @override
  String get lockFilePassword => 'Password';

  @override
  String get lockFileSuggestFourWords => 'Suggest four words';

  @override
  String get lockFileTypeItAgain => 'Type it again';

  @override
  String get lockFileTheTwoDoNot => 'The two do not match yet.';

  @override
  String get lockFileHideTheFileName => 'Hide the file name';

  @override
  String lockFileItWillBeCalled(Object name) {
    return 'It will be called “$name”. Tell them what kind of file it is.';
  }

  @override
  String get lockFileTheNameAloneCan =>
      'The name alone can say what is inside.';

  @override
  String get lockFileAnyoneWithThePassword =>
      'Anyone with the password can open it, in Kryfo or on any computer with the free tool age. Forget it and the file is gone for good. Nobody can reset it, us included.';

  @override
  String get lockFileLocked2 => 'Locked.';

  @override
  String get lockFileOnlyThePasswordOpens => 'Only the password opens it.';

  @override
  String lockFileSafeToEmailOr(Object prettySize) {
    return '$prettySize · safe to email or put on a USB stick';
  }

  @override
  String get lockFileNoKryfoOnThe =>
      'No Kryfo on the other side? On a computer:';

  @override
  String get lockFileItAsksForThe =>
      'It asks for the password. age is free at age-encryption.org';

  @override
  String lockTooManyTriesS(Object lockState) {
    return 'Too many tries · ${lockState}s';
  }

  @override
  String get lockNotIt => 'Not it';

  @override
  String get lockYourPin => 'Your PIN';

  @override
  String get lockUseFingerprint => 'Use fingerprint';

  @override
  String get lockSetupUnlockWithFingerprint => 'Unlock with fingerprint?';

  @override
  String get lockSetupThePinStillWorks =>
      'The PIN still works whenever you want it. This is just faster.';

  @override
  String get lockSetupUseFingerprint => 'Use fingerprint';

  @override
  String get lockSetupPinOnly => 'PIN only';

  @override
  String get lockSetupOnceMore => 'Once more';

  @override
  String get lockSetupSetAPin => 'Set a PIN';

  @override
  String get lockSetupThoseWereDifferentFrom =>
      'Those were different. From the top.';

  @override
  String get lockSetupTheSameFourDigits => 'The same digits again';

  @override
  String get lockSetupFourDigitsAnythingYou =>
      'Four digits or more, anything you will remember';

  @override
  String get modesOnion => 'Onion';

  @override
  String get modesFullOnionRoutingThree =>
      'Full onion routing, three hops. A message takes two to five seconds. Nobody sees who you talk to.';

  @override
  String get modesSlower => 'Slower';

  @override
  String get modesRelay => 'Relay';

  @override
  String get modesOneSealedConnectionTo =>
      'One sealed connection to Kryfo\'s own relay, like a vpn with nothing to log. Sends land in about a second, and it works where tor is blocked.';

  @override
  String get modesQuick => 'Quick';

  @override
  String get modesRelayOnly => 'Relay only';

  @override
  String get modesFast => 'Fast';

  @override
  String get modesPlainConnectionsToEvery =>
      'Plain connections to every relay. Near instant, and the least private of the three.';

  @override
  String get modesInstant => 'Instant';

  @override
  String get modesEveryRelayYouUse =>
      'Every relay you use knows the address you connect from, not only ours. Messages are still sealed, but the fact that you sent one is not. Off by default, and off again after a reinstall.';

  @override
  String get modesSpeed => 'Speed';

  @override
  String get modesPrivacy => '& privacy';

  @override
  String get modesChangeGloballyOrPer => 'Change globally, or per chat';

  @override
  String get modesSoon => 'Soon';

  @override
  String get modesActive => 'Active';

  @override
  String get modesSpeed2 => 'SPEED';

  @override
  String get modesHops => 'HOPS';

  @override
  String get modesIp => 'IP';

  @override
  String get modesVisible => 'Visible';

  @override
  String get modesHidden => 'Hidden';

  @override
  String modesHeadsUp(Object warning) {
    return '*Heads up:* $warning';
  }

  @override
  String get modesOnionIsTheDefault =>
      'Onion is the default and stays that way unless you change it. Switching takes effect on the next message.';

  @override
  String get modesFastMode => 'Fast mode';

  @override
  String get modesPlainConnectionsToEveryRelayQuicker =>
      'Plain connections to every relay. Quicker, and the relays can see your ip address. Messages stay end to end encrypted either way.';

  @override
  String get modesTurnOnFastMode => 'Turn on fast mode';

  @override
  String get modesKeepItOff => 'Keep it off';

  @override
  String get movedWipeThisPhone => 'Wipe Kryfo from this phone?';

  @override
  String get movedEverythingKryfoHoldsHere =>
      'Everything Kryfo holds here goes: the messages, the contacts, the keys. The other device keeps all of it. This cannot be undone.';

  @override
  String get movedWipeIt => 'Wipe it';

  @override
  String get movedNotMovingAfterAll => 'Not moving after all?';

  @override
  String get movedOnlyDoThisIf =>
      'Only do this if the backup was never imported anywhere. If it was, two devices now hold one identity, and messages will start going missing on both.';

  @override
  String get movedIMStayingHere => 'I\'m staying here';

  @override
  String get movedStayingHere => 'Staying here';

  @override
  String movedKryfoWillCloseNow(Object myId) {
    return 'Kryfo will close now. Tap the icon to reopen as $myId.';
  }

  @override
  String get movedReopenKryfo => 'Reopen Kryfo';

  @override
  String get movedThisKryfoHasMoved => 'This Kryfo has moved';

  @override
  String movedIsNowOnAnother(Object myId) {
    return '$myId is now on another device. This phone can still show what was here, but nothing new will arrive on it, and anything you send from here won\'t reach anyone.';
  }

  @override
  String get movedKeepItToRead => 'Keep it to read';

  @override
  String get movedWipeThisPhone2 => 'Wipe Kryfo from this phone';

  @override
  String get movedIMNotMoving => 'I\'m not moving after all';

  @override
  String get myKryfoAHandleIs3 => 'A handle is 3 to 20 letters, digits or _';

  @override
  String get myKryfoInviteCopiedClearsIn => 'Invite copied · clears in 60s';

  @override
  String myKryfoAddMeOnKryfo(Object myId, Object uri) {
    return 'Add me on Kryfo. My ID is $myId\n\nTap to add me:\n$uri\n\nKryfo is a private messenger. No phone number, no email.';
  }

  @override
  String get myKryfoAddMeOnKryfo2 => 'Add me on Kryfo';

  @override
  String get myKryfoAddSomeone => 'Add someone';

  @override
  String get myKryfoKryfoDoesnTScan =>
      'Kryfo doesn\'t scan your contacts, that\'s the point.';

  @override
  String get myKryfoIfThisLinkEnds =>
      'If this link ends up somewhere you did not mean, reset it in settings. Everyone who has it needs a new one then.';

  @override
  String get myKryfoAlreadyShareAFriend =>
      'Already share a friend on Kryfo? They can introduce you both from their chat, and you skip the request.';

  @override
  String get myKryfoHandleCopied => 'Handle copied';

  @override
  String get myKryfoTheyReHereWith => 'They\'re here with me';

  @override
  String get myKryfoPointYourPhonesAt =>
      'Point your phones at each other. Nothing goes through a server.';

  @override
  String get myKryfoScanTheirsInstead => 'Scan theirs instead';

  @override
  String get myKryfoTheyReadYouA => 'They read you a code';

  @override
  String get myKryfoTheyReSomewhereElse => 'They\'re somewhere else';

  @override
  String get myKryfoSendThemALink =>
      'Send them a link. It opens straight into add.';

  @override
  String get myKryfoYourLinkAppearsOnce =>
      'Your link appears once you are connected';

  @override
  String get myKryfoTheLinkCarriesYour =>
      'The link carries your id, your address and the keys to start a chat. It works until you reset it in settings.';

  @override
  String get myKryfoSendTheLink => 'Send the link';

  @override
  String get myKryfoAsACard => 'As a card';

  @override
  String get myKryfoAnImageWithThe => 'An image with the qr';

  @override
  String get myKryfoAsAFile => 'As a file';

  @override
  String get myKryfoContactFile => 'Contact file';

  @override
  String get myKryfoIKnowTheirHandle => 'I know their handle';

  @override
  String get myKryfoTypeTheNameThey =>
      'Type the @name they gave you. Works if they claimed one.';

  @override
  String get myKryfoTheLookupAsksFor =>
      'The lookup sends that one name and nothing about you. Your first message to them still arrives as a request.';

  @override
  String get myKryfoLooking => 'Looking…';

  @override
  String get myKryfoFindThem => 'Find them';

  @override
  String get myKryfoYourAddressAppearsOnce =>
      'Your address appears once you are connected';

  @override
  String get myKryfoAPublicHandle => 'A public handle';

  @override
  String get myKryfoPutItInA =>
      'Put it in a bio. Anyone who knows it can find you.';

  @override
  String get myKryfoANamePeopleCan =>
      'A name people can find you by. Off until you claim one.';

  @override
  String get newGroupCouldNotCreate => 'Could not create';

  @override
  String get newGroupNewGroup => 'New group';

  @override
  String get newGroupCreating => 'Creating…';

  @override
  String get newGroupCreate => 'Create';

  @override
  String get newGroupGroupName => 'Group name';

  @override
  String get newGroupMembers => 'Members';

  @override
  String get newGroupPickAtLeastOne => 'Pick at least one';

  @override
  String newGroupSelected(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString selected',
    );
    return '$_temp0';
  }

  @override
  String get newGroupAddAtLeastOne =>
      'Add at least one contact first before creating a group.';

  @override
  String get notesDeleteThisNote => 'Delete this note?';

  @override
  String get notesGoneFromThisPhone => 'It is gone from this phone for good.';

  @override
  String get notesNoteToSelf => 'Note to self';

  @override
  String get notesOnlyOnThisPhone => 'Only on this phone';

  @override
  String get notesAQuietPlace => 'A quiet place';

  @override
  String get notesJotAnythingDownIt =>
      'Jot anything down. It stays on this phone and never leaves.';

  @override
  String get notesJotSomethingDown => 'Jot something down…';

  @override
  String get onboardingPrivateByDefault => 'PRIVATE BY DEFAULT';

  @override
  String get onboardingPrivateMessaging =>
      'Private messaging,\n*without the catch*.';

  @override
  String get onboardingYourNameIsThree =>
      '*Your name is three words.* No phone, no email, no address book.';

  @override
  String get onboardingNobodyGetsInUnless =>
      '*Nobody gets in unless you let them.* No one can look you up unless you claim a public handle. People are added by hand, both ways.';

  @override
  String get onboardingTheFirstConnectionTakes =>
      '*The first connection takes a minute.* Kryfo builds a private route before it sends. Quick after.';

  @override
  String get onboardingBegin => 'Begin';

  @override
  String get onboardingHaveABackupRestore => 'Have a backup? Restore →';

  @override
  String get onboardingKryfoIsOpenSource => 'Kryfo is open source';

  @override
  String get onboardingYourKryfoId => 'YOUR KRYFO ID';

  @override
  String get onboardingGeneratedFromAKey =>
      'Generated from a key that lives only on this phone. *Memorable, unique, yours alone.* No one else has this.';

  @override
  String get onboardingTryAnother => 'Try another';

  @override
  String get onboardingUseThisName => 'Use this name →';

  @override
  String get onboardingThreeWords => 'Three words. *Yours alone.*';

  @override
  String get onboardingPickA => 'Pick a *face*.';

  @override
  String get onboardingDrawnOnThisPhone =>
      'Drawn on this phone from a number, never uploaded. Change it whenever you like.';

  @override
  String get onboardingThePeopleYouMessage =>
      'The people you message see this too';

  @override
  String get onboardingKeepMyInitial => 'Keep my initial';

  @override
  String get onboardingThatOne => 'That one →';

  @override
  String get onboardingContinue => 'Continue →';

  @override
  String get onboardingHowYourMessages => 'How your messages *travel*.';

  @override
  String get onboardingYouCanChangeThis =>
      'You can change this any time in settings, for everyone or for one chat.';

  @override
  String get onboardingOnion => 'Onion';

  @override
  String get onboardingSlowerAMessageTakes =>
      'Slower. A message takes two to five seconds.';

  @override
  String get onboardingHidesYourAddressFrom =>
      'Hides your address from everyone, our relay included.';

  @override
  String get onboardingRelay => 'Relay';

  @override
  String get onboardingOurRelaySeesYour =>
      'Our relay sees your address. Nobody else does.';

  @override
  String get onboardingAboutASecondWorks =>
      'About a second. Works where tor is blocked.';

  @override
  String get onboardingFast => 'Fast';

  @override
  String get onboardingEveryRelayYouUse =>
      'Every relay you use sees your address. The least private of the three.';

  @override
  String get onboardingNearInstant => 'Near instant.';

  @override
  String get onboardingKeepOnion => 'Keep onion →';

  @override
  String get onboardingUseThis => 'Use this →';

  @override
  String get onboardingSkipOnionIsA => 'Skip · onion is a fine default';

  @override
  String get onboardingThreeThingsThen => 'Three things,\nthen *you\'re in*.';

  @override
  String get onboardingEverythingElseTheApp =>
      'Everything else the app will tell you when it matters.';

  @override
  String get onboardingYourNameIsThreeWords => 'Your name is three words';

  @override
  String get onboardingThatIsTheWhole =>
      'That is the whole identity. No number to leak, no email to phish, nothing to look up. People you talk to see these words and the face you picked.';

  @override
  String get onboardingNobodyCanReachYou =>
      'Nobody can reach you until you let them in';

  @override
  String get onboardingAStrangerWithYour =>
      'A stranger with your words can only knock. Their first message waits in requests until you say yes, and you can say no without them ever knowing.';

  @override
  String get onboardingTheFirstConnectionTakesAMinute =>
      'The first connection takes a minute';

  @override
  String get onboardingKryfoBuildsAPrivateRouteBefore =>
      'Kryfo builds a private route before it sends anything. While you are offline, messages wait and arrive when you are back.';

  @override
  String get onboardingYourIdentityLivesOn =>
      'Your identity lives on this phone. Back it up from settings when you are ready.';

  @override
  String get onboardingIUnderstand => 'I understand →';

  @override
  String get onboardingOneQuiet => 'One quiet *notification*.';

  @override
  String get onboardingAndroidNeedsAVisible =>
      'Android needs a visible notification while an app listens in the background. That is how messages reach you when Kryfo is closed.';

  @override
  String get onboardingSilentAndAtThe =>
      'Silent, and at the bottom of the shade';

  @override
  String get onboardingItNeverBuzzesTurn =>
      'It never buzzes. Turn it off and messages wait until you open the app again.';

  @override
  String get onboardingGotIt => 'Got it →';

  @override
  String get onboardingNow => 'Now, *add someone*.';

  @override
  String get onboardingTheAppIsReady =>
      'The app is ready. Nobody can message you until you add them or let them in.';

  @override
  String get onboardingEveryWayToAdd => 'Every way to add someone';

  @override
  String get onboardingShowYourCodeSend =>
      'Show your code, send them a link, or type the @handle they gave you.';

  @override
  String get onboardingScanTheirs => 'Scan theirs';

  @override
  String get onboardingPointTheCameraAt => 'Point the camera at their code';

  @override
  String get onboardingTheAppIsReadyWhenYou => 'The app is ready when you are.';

  @override
  String get onboardingNotNowAddPeople => 'Not now · add people later';

  @override
  String get openLockedOpened => 'Opened';

  @override
  String get openLockedOpenALockedFile => 'Open a locked file';

  @override
  String get openLockedCheckingThePassword => 'Checking the password';

  @override
  String get openLockedOpening => 'Opening';

  @override
  String get openLockedFile => 'File';

  @override
  String get openLockedOpenFile => 'Open file';

  @override
  String get openLockedTypeThePassword => 'Type the password.';

  @override
  String get openLockedItOpensOnThis => 'It opens on this phone.';

  @override
  String get openLockedLockedFile => 'Locked file';

  @override
  String openLockedFromFiles(Object prettySize) {
    return '$prettySize · from Files';
  }

  @override
  String get openLockedFromFiles2 => 'From Files';

  @override
  String get openLockedPassword => 'Password';

  @override
  String get openLockedThePasswordIsChecked =>
      'The password is checked first. Only then does Kryfo ask where to put the opened file, and it goes straight there.';

  @override
  String get openLockedOpened2 => 'Opened.';

  @override
  String get openLockedSavedWhereYouChose => 'Saved where you chose.';

  @override
  String get pairCodePairingCode => 'Pairing code';

  @override
  String get pairCodeShowACode => 'Show a code';

  @override
  String get pairCodeEnterOne => 'Enter one';

  @override
  String get pairCodeSixDigits => 'Six digits';

  @override
  String get pairCodeLooking => 'Looking…';

  @override
  String get pairCodeNothingThereYetTrying =>
      'Nothing there yet · trying again';

  @override
  String get pairCodeNothingAtThatCode =>
      'Nothing at that code. It may have burned, or they have not shared it yet.';

  @override
  String get pairCodeUnreached =>
      'Couldn\'t reach the relays. Try again in a moment.';

  @override
  String get pairCodeFailed => 'That didn\'t work. Try again.';

  @override
  String get pairCodeTypeTheSixDigits => 'Type the six digits they read out.';

  @override
  String get pairCodeAddThem => 'Add them';

  @override
  String get pairCodeUsedTwice =>
      'This code was used twice. Ask for a new one.';

  @override
  String get pairCodeIsThisThem => 'Is this them?';

  @override
  String get pairCodeCheckMatches => 'Check this matches their screen';

  @override
  String get pairCodeNotThem => 'Not them';

  @override
  String get pairCodeNotAdded => 'Not added. Ask them for a new code.';

  @override
  String get panicSetupThoseWereDifferentFrom =>
      'Those were different. From the top.';

  @override
  String get panicSetupOnceMore => 'Once more';

  @override
  String get panicSetupTheSameFourDigits => 'The same digits again';

  @override
  String get photoKnowsEverythingInside => 'Everything inside';

  @override
  String get photoKnowsVideo => 'Video';

  @override
  String get photoKnowsPhoto => 'Photo';

  @override
  String get photoKnowsWhatThisVideoKnows => 'What this video knows';

  @override
  String get photoKnowsWhatThisPhotoKnows => 'What this photo knows';

  @override
  String get photoKnowsRemoveAllOfIt => 'Remove all of it';

  @override
  String get photoKnowsKeepItAsIt => 'Keep it as it is';

  @override
  String get photoKnowsReadOnThisPhone =>
      'READ ON THIS PHONE · THE VIDEO WENT NOWHERE';

  @override
  String get photoKnowsReadOnThisPhoneThePhoto =>
      'READ ON THIS PHONE · THE PHOTO WENT NOWHERE';

  @override
  String get photoKnowsReadingTheFile => 'Reading the file';

  @override
  String photoKnowsOf(Object prettySize, Object prettySize2) {
    return '$prettySize of $prettySize2';
  }

  @override
  String get photoKnowsEverythingStaysOnThis =>
      'Everything stays on this phone.';

  @override
  String photoKnowsMapWithAPin(Object place) {
    return 'Map with a pin. $place';
  }

  @override
  String get photoKnowsDrawnOffline => 'DRAWN OFFLINE';

  @override
  String photoKnowsShowEverything(Object title) {
    return '$title. Show everything';
  }

  @override
  String get pinsAppLock => 'App lock';

  @override
  String get pinsYourPin => 'Your PIN';

  @override
  String get commonOn => 'On';

  @override
  String get commonOff => 'Off';

  @override
  String get pinsOpensKryfoFourDigits =>
      'Opens Kryfo. Asked for when it comes to the front.';

  @override
  String get pinsChangePin => 'Change PIN';

  @override
  String get pinsSetAPin => 'Set a PIN';

  @override
  String get pinsTurnOff => 'Turn off';

  @override
  String get pinsTurnOffTheApp => 'Turn off the app lock?';

  @override
  String get pinsThePinGoesAnd =>
      'The PIN goes, and the wipe PIN and any hidden chats with it. Anyone holding your phone opens Kryfo as you.';

  @override
  String get pinsUnlockWithFingerprint => 'Unlock with fingerprint';

  @override
  String get pinsWipePin => 'Wipe PIN';

  @override
  String get pinsNeedsAPinFirst => 'Needs a PIN first';

  @override
  String get pinsSet => 'Set';

  @override
  String get pinsChangeWipePin => 'Change wipe PIN';

  @override
  String get pinsSetAWipePin => 'Set a wipe PIN';

  @override
  String get pinsRemove => 'Remove';

  @override
  String get pinsRemoveTheWipePin => 'Remove the wipe PIN?';

  @override
  String get pinsTheLockScreenKeeps =>
      'The lock screen keeps your PIN. The wipe PIN stops doing anything.';

  @override
  String profileCopied(Object what) {
    return '$what copied';
  }

  @override
  String get profileProfile => 'Profile';

  @override
  String get profileChangeYourFace => 'Change your face';

  @override
  String get profileKryfoId => 'Kryfo id';

  @override
  String get profileOnionAddress => 'Onion address';

  @override
  String get profileSupporterBadge => 'Supporter badge';

  @override
  String profileYouAreAThank(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter': 'You are a supporter. Thank you.',
      'patron': 'You are a patron. Thank you.',
      'guardian': 'You are a guardian. Thank you.',
      'other': 'You are a supporter. Thank you.',
    });
    return '$_temp0';
  }

  @override
  String get profileShowMyBadge => 'Show my badge';

  @override
  String get profileOnMyOwnScreens => 'On my own screens';

  @override
  String get profileLetContactsSeeIt => 'Let contacts see it';

  @override
  String get profileOffByDefault => 'Off by default';

  @override
  String get profileShareConnect => 'Share & connect';

  @override
  String get profileMyKryfoCode => 'My Kryfo code';

  @override
  String get profileAddContact => 'Add contact';

  @override
  String get profileGiveAgain => 'Give again';

  @override
  String get profileSupportKryfo => 'Support Kryfo';

  @override
  String get profileKryfoRunsOnWhat => 'Kryfo runs on what people give';

  @override
  String get profileKeepKryfoIndependent => 'Keep Kryfo independent';

  @override
  String get qrLink => 'Link';

  @override
  String get qrYourLinkAsTyped => 'YOUR LINK AS TYPED · NO TRACKING REDIRECT';

  @override
  String get qrText => 'Text';

  @override
  String get qrStaysInTheCode => 'STAYS IN THE CODE · NO SERVER HOLDS IT';

  @override
  String get qrWiFi => 'Wi-Fi';

  @override
  String get qrMadeOnThisPhone =>
      'MADE ON THIS PHONE · NO WEBSITE SAW THE PASSWORD';

  @override
  String get qrNetworkName => 'Network name';

  @override
  String get qrPassword => 'Password';

  @override
  String get qrContact => 'Contact';

  @override
  String get qrOnlyWhatYouType =>
      'ONLY WHAT YOU TYPE · NOTHING FROM YOUR CONTACTS';

  @override
  String get qrName => 'Name';

  @override
  String get qrPhone => 'Phone';

  @override
  String get qrEmail => 'Email';

  @override
  String get qrOpensTheirMailApp =>
      'OPENS THEIR MAIL APP · NOTHING SENT FROM HERE';

  @override
  String get qrTo => 'To';

  @override
  String get qrSubject => 'Subject';

  @override
  String get qrANumberNothingElse => 'A NUMBER · NOTHING ELSE';

  @override
  String get qrNumber => 'Number';

  @override
  String get qrSms => 'SMS';

  @override
  String get qrOpensTheirMessagesApp =>
      'OPENS THEIR MESSAGES APP · NOTHING SENT FROM HERE';

  @override
  String get qrMessage => 'Message';

  @override
  String get qrLocation => 'Location';

  @override
  String get qrCoordinatesOnlyNoMap =>
      'COORDINATES ONLY · NO MAP SERVICE ASKED';

  @override
  String get qrLatitude => 'Latitude';

  @override
  String get qrLongitude => 'Longitude';

  @override
  String get qrBitcoin => 'Bitcoin';

  @override
  String get qrAddressAndAmountNo =>
      'ADDRESS AND AMOUNT · NO PAYMENT SITE IN BETWEEN';

  @override
  String get qrAddress => 'Address';

  @override
  String get qrAmountInBtc => 'Amount in BTC';

  @override
  String get qrInk => 'Ink';

  @override
  String get qrAmber => 'Amber';

  @override
  String get qrViolet => 'Violet';

  @override
  String get qrCouldNotDrawThe => 'Could not draw the image.';

  @override
  String get qrSavedToYourGallery => 'Saved to your gallery';

  @override
  String get qrCouldNotSaveIt => 'Could not save it. Check the phone has room.';

  @override
  String get qrNoAppOnThis => 'No app on this phone took the image.';

  @override
  String get qrTooMuchForOne => 'Too much for one code. Make it shorter.';

  @override
  String get qrThisIsALot =>
      'This is a lot for one code. Older cameras may not read it.';

  @override
  String get qrPrivateQrCode => 'Private QR code';

  @override
  String get qrColour => 'Colour';

  @override
  String get qrCopiedItLeavesThe =>
      'Copied. It leaves the clipboard in a minute';

  @override
  String get qrSecurity => 'Security';

  @override
  String get qrNone => 'None';

  @override
  String get qrSaveImage => 'Save image';

  @override
  String qrColour2(Object name) {
    return '$name colour';
  }

  @override
  String get qrTypeBelowAndThe => 'Type below and the\ncode draws itself';

  @override
  String get qrQrCode => 'QR code';

  @override
  String get qrHidePassword => 'Hide password';

  @override
  String get qrShowPassword => 'Show password';

  @override
  String get qrCopyPassword => 'Copy password';

  @override
  String get requestsSentAnAttachment => 'Sent an attachment';

  @override
  String get requestsWantsToConnect => 'Wants to connect';

  @override
  String get requestsAccepted => 'Accepted';

  @override
  String requestsBlock(Object id) {
    return 'Block $id?';
  }

  @override
  String get requestsNothingMoreFromThem =>
      'Nothing more from them reaches you. Their request and its messages go.';

  @override
  String get requestsBlocked => 'Blocked';

  @override
  String get requestsDeleted => 'Deleted';

  @override
  String get requestsRequests => 'Requests';

  @override
  String get requestsNoRequests => 'No requests';

  @override
  String get requestsMessagesFromPeopleYou =>
      'Messages from people you have not added show up here first.';

  @override
  String get requestsLooksSafeNothingSuspicious =>
      'Looks safe · nothing suspicious in their first message';

  @override
  String get commonAccept => 'Accept';

  @override
  String get requestsDecline => 'Decline';

  @override
  String get restoreThatFileIsNot => 'That file is not a Kryfo backup';

  @override
  String get restoreThisFileIsDamaged =>
      'This file is damaged and cannot be read';

  @override
  String get restoreTypeThePassphraseThe =>
      'Type the passphrase the file was made with';

  @override
  String get restoreReplaceTheAccountOn => 'Replace the account on this phone?';

  @override
  String get restoreWhatIsHereNow =>
      'What is here now, its identity, contacts and messages, goes. The file takes its place. This cannot be undone.';

  @override
  String get restoreReplaceIt => 'Replace it';

  @override
  String restoreCouldNotBeReleased(Object mine) {
    return '@$mine could not be released';
  }

  @override
  String restoreTheRegistryDidNot(Object mine) {
    return 'The registry did not answer. If you go on, @$mine stays pointed at the identity this phone is about to lose. Anyone who adds it will be writing to nobody, and the name cannot be claimed again. Better to get online and try once more.';
  }

  @override
  String get restoreRestoreAnyway => 'Restore anyway';

  @override
  String get restoreNotYet => 'Not yet';

  @override
  String get restoreRestored => 'Restored';

  @override
  String restoreKryfoWillCloseNow(Object haloId) {
    return 'Kryfo will close now. Tap the icon to reopen as $haloId.';
  }

  @override
  String get restoreReopenKryfo => 'Reopen Kryfo';

  @override
  String get restoreTheRestoreDidNot =>
      'The restore did not finish. Nothing was changed';

  @override
  String get restoreKryfoClosesRestoreAgain =>
      'Part of what was here is already replaced. Kryfo will close now. Open it again and restore the file once more.';

  @override
  String get restoreThisIdentity => 'this identity';

  @override
  String get restoreMoveYourKryfoHere => 'Move your Kryfo here';

  @override
  String restoreThisBackupIsRestoring(Object name) {
    return 'This backup is $name. Restoring it moves that identity to this device.';
  }

  @override
  String restoreThisBackupMadeOn(Object name, Object date, Object time) {
    return 'This backup is $name, made on $date at $time. Restoring it moves that identity to this device.';
  }

  @override
  String restoreItHoldsOfPhotos(Object mb) {
    return 'It holds $mb of photos, voice notes and files. This may take a few minutes. Keep the app open.';
  }

  @override
  String get restoreWhatFollows => 'What follows';

  @override
  String get restoreYourNameYourCode =>
      'Your name, your code, and every contact.';

  @override
  String get restoreEveryConversationBackTo =>
      'Every conversation, back to the start.';

  @override
  String get restoreYourPhotosVoiceNotes =>
      'Your photos, voice notes and files.';

  @override
  String restoreYourPhotosVoiceNotesCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Your photos, voice notes and files · $countString.',
    );
    return '$_temp0';
  }

  @override
  String get restoreYourOnionAddressSo =>
      'Your onion address, so people who reach you directly keep reaching you.';

  @override
  String get restoreAnythingSentToYou =>
      'Anything sent to you while the old phone was off, for fourteen days after it was sent.';

  @override
  String get restoreYourSupporterBadgeIf =>
      'Your supporter badge, if you have one.';

  @override
  String get restoreWhatDoesnT => 'What doesn\'t';

  @override
  String get restoreTheOldPhoneStops =>
      'The old phone stops receiving the moment you send anything from here. Not gradually. The first message you send from this device is the last one the old phone can follow, and anything that reaches it after that is unreadable there and isn\'t waiting for you here either.';

  @override
  String get restoreIfThePhoneThis =>
      'If the phone this file came from is still in use, stop using Kryfo on it before you carry on. Two phones on one Kryfo lose messages on both.';

  @override
  String get restoreNotificationsNeedSettingUp =>
      'Notifications need setting up again on this device.';

  @override
  String get restoreMoveItHere => 'Move it here';

  @override
  String get restoreNotNow => 'Not now';

  @override
  String get restoreRestore => 'Restore';

  @override
  String get restoreFromABackupFile => 'From a backup file';

  @override
  String get restoreABackupBringsBack =>
      'A backup brings back your identity and your contacts, and the messages that were on the phone when the file was made. Anything said since is not in it.';

  @override
  String get restoreTheFile => 'The file';

  @override
  String get restorePickTheBackupFile => 'Pick the backup file';

  @override
  String get restoreThePassphrase => 'The passphrase';

  @override
  String get restoreTheOneTheFile => 'The one the file was made with';

  @override
  String get restoreWhatComesBack => 'What comes back';

  @override
  String get restoreChecking => 'Checking…';

  @override
  String get restoreCheckTheFile => 'Check the file';

  @override
  String get restoreReleasingYourHandle => 'Releasing your handle…';

  @override
  String restoreMoving(Object progress) {
    return 'Moving… $progress';
  }

  @override
  String get restoreRestoring => 'Restoring…';

  @override
  String get restoreNotThisOne => 'Not this one';

  @override
  String get restoreDateUnknown => 'Date unknown';

  @override
  String get restoreAnIdentity => 'An identity';

  @override
  String get restoreMessagesSentOrReceived =>
      'Messages sent or received after that date are not in this file.';

  @override
  String restoreGb(Object bytes) {
    return '$bytes GB';
  }

  @override
  String restoreMb(Object bytes) {
    return '$bytes MB';
  }

  @override
  String get roomCreateCouldNotCreateThe => 'Could not create the room';

  @override
  String get roomCreateBurnerRoom => 'Burner room';

  @override
  String get roomCreateARoomThatEnds =>
      'A room that ends. Everyone joins under a key made for it, and when it ends nothing is left on any phone.';

  @override
  String get roomCreateRoomName => 'Room name';

  @override
  String get roomCreateEndsAfter => 'Ends after';

  @override
  String get roomCreateMemberCap => 'Member cap';

  @override
  String roomCreateNoOnePastThe(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'No one past the first $countString',
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
      other: 'Off. Anyone with the link, up to $countString',
    );
    return '$_temp0';
  }

  @override
  String roomCreateThisRoomAndEverything(Object expiryWords) {
    return 'This room and everything in it disappears in $expiryWords';
  }

  @override
  String get roomCreateCreating => 'Creating...';

  @override
  String get roomCreateCreateRoom => 'Create room';

  @override
  String get roomLinkSendTheRoomTo => 'Send the room to';

  @override
  String get roomLinkTheyWillKnowThis =>
      'They will know this room came from you. Inside it they are a key like everyone else.';

  @override
  String get roomLinkNoContactsYet => 'No contacts yet';

  @override
  String roomLinkEndsIn(Object time) {
    return 'Ends in $time';
  }

  @override
  String get roomLinkAnyoneWithThisCan =>
      'Anyone with this can join until the room ends. They come in under a key made for this room, and see nothing sent before they arrived.';

  @override
  String get roomLinkRoomLinkCopied => 'Room link copied';

  @override
  String get roomLinkSendToAContact => 'Send to a contact';

  @override
  String get roomLinkCopyRoomLink => 'Copy room link';

  @override
  String get savedVoiceNote => 'Voice note';

  @override
  String get savedPhoto => 'Photo';

  @override
  String get savedSaved => 'Saved';

  @override
  String get savedNothingSavedYet => 'Nothing saved yet';

  @override
  String get savedChatGone => 'That chat is no longer on this phone';

  @override
  String get savedLongPressAnyMessage =>
      'Long-press any message and tap save to keep it here.';

  @override
  String get savedViewInChat => 'View in chat';

  @override
  String get savedPhoto2 => 'Photo';

  @override
  String get scanThatSNotA => 'That\'s not a Kryfo QR · keep pointing';

  @override
  String get scanScanAKryfoQr => 'Scan a Kryfo QR';

  @override
  String get scanFlash => 'Flash';

  @override
  String get scanPointAtAKryfo =>
      'Point at a Kryfo QR · nothing leaves your phone';

  @override
  String get seenWhatWeCanSee => 'What we can see';

  @override
  String get seenEveryMessengerClaimsPrivacy =>
      'Every messenger claims privacy. This is the specific list, by route, including the parts that do not flatter us. Tap a row for the why.';

  @override
  String get seenHonestAboutTheLast =>
      'Honest about the last rows: that is what the app lock, the wipe PIN and encrypted storage are for, and no tool saves you from someone holding your open phone. The full threat model lives in THREAT_MODEL.md in the repo, written against LINDDUN. The code is open, so none of this has to be taken on trust.';

  @override
  String get seenHidden => 'Hidden';

  @override
  String get seenNever => 'Never';

  @override
  String get seenOnDevice => 'On device';

  @override
  String get seenYours => 'Yours';

  @override
  String get seenUnaudited => 'Unaudited';

  @override
  String get seenWhoYouTalkTo => 'Who you talk to';

  @override
  String get seenEachConversationGetsIts =>
      'Each conversation gets its own address, derived from both keys. A relay sees unrelated drop boxes, not a pair of people.';

  @override
  String get seenWhatYouSay => 'What you say';

  @override
  String get seenEndToEndEncrypted =>
      'End to end encrypted with the signal double ratchet, then sealed again inside a gift wrap. We could not read it if we tried.';

  @override
  String get seenYourIpAddress => 'Your ip address';

  @override
  String get seenOurRelay => 'Our relay';

  @override
  String get seenEveryRelay => 'Every relay';

  @override
  String get seenOnOnionEverythingLeaves =>
      'On onion everything leaves through tor and the relay sees an exit node, never you. On relay mode the connection goes straight to our own relay: nothing forwards your address and nothing is written down, but that one connection is ours to see. On fast every public relay learns that you connected, though not to whom or what you said.';

  @override
  String get seenYourContactGraph => 'Your contact graph';

  @override
  String get seenKryfoDoesNotScan =>
      'Kryfo does not scan your contacts. That is the point. No phone number exists here to leak.';

  @override
  String get seenIntroducer => 'Introducer';

  @override
  String get seenWhenAContactIntroduces =>
      'When a contact introduces you to someone, that contact learns the two of you are now connected. Nobody else does. The relay sees ciphertext, and no server ever sees the graph.';

  @override
  String get seenTheScamShield => 'The scam shield';

  @override
  String get seenRunsOnYourPhone =>
      'Runs on your phone with rules that ship in the app. No network, no list downloads. It only reads the first message from a stranger and cannot see anything a contact sends you.';

  @override
  String get seenBurnerRooms => 'Burner rooms';

  @override
  String get seenRoomKeys => 'Room keys';

  @override
  String get seenYouJoinARoom =>
      'You join a room under a key made for it, so the people inside learn nothing that works elsewhere. Late joiners get no history. At expiry the keys, the messages and the media are destroyed.';

  @override
  String get seenLinkPreviews => 'Link previews';

  @override
  String get seenOverTor => 'Over Tor';

  @override
  String get seenAPreviewIsFetched =>
      'A preview is fetched by the sender, over tor, and travels inside the encrypted message. The receiving phone makes no request. The website learns that someone using tor asked for a page, and nothing else. No image is ever loaded, and a stranger\'s link stays plain text.';

  @override
  String get seenASeizedUnlockedPhone => 'A seized unlocked phone';

  @override
  String get seenIfSomeoneHoldsYour =>
      'If someone holds your phone open, they read your messages. The app lock, wipe PIN and encrypted storage help before that point, not after it.';

  @override
  String get seenTheCryptoItself => 'The crypto itself';

  @override
  String get seenTheRatchetAndStorage =>
      'The ratchet and storage layers are standard. The layer joining them is ours and no one independent has reviewed it. Treat this as alpha, because it is.';

  @override
  String get seenOnion => 'Onion';

  @override
  String get seenRelay => 'Relay';

  @override
  String get seenFast => 'Fast';

  @override
  String get settingsWipeKryfo => 'Wipe Kryfo?';

  @override
  String get settingsIdentityMessagesContactsAnd =>
      'Identity, messages, contacts and settings on this phone. Gone for good unless you have a backup.';

  @override
  String get commonContinue => 'Continue';

  @override
  String settingsTypeWipeToConfirm(Object word) {
    return 'Type \'$word\' to confirm';
  }

  @override
  String get settingsTheLastStepNothing =>
      'The last step. Nothing survives it.';

  @override
  String get settingsWipeWord => 'wipe';

  @override
  String get settingsWipeKryfo2 => 'Wipe Kryfo';

  @override
  String get settingsYourProtections => 'Your protections';

  @override
  String get settingsTorRouting => 'Tor routing';

  @override
  String get settingsConnecting => 'Connecting';

  @override
  String get settingsOffMode => 'Off · relay mode';

  @override
  String get settingsOffFastMode => 'Off · fast mode';

  @override
  String get settingsAppLock => 'App lock';

  @override
  String get settingsBlockedByAndroid => 'Blocked by android';

  @override
  String get settingsSpeedPrivacy => 'Speed & privacy';

  @override
  String get settingsFast => 'Fast';

  @override
  String get settingsRelay1Hop => 'Relay · 1 hop';

  @override
  String get settingsOnion3Hops => 'Onion · 3 hops';

  @override
  String get settingsBridges => 'Bridges';

  @override
  String get settingsForNetworksThatBlock => 'For networks that block tor';

  @override
  String get settingsGettingMessages => 'Getting messages';

  @override
  String settingsPreviewHidden(Object deliveryModeName) {
    return '$deliveryModeName · preview hidden';
  }

  @override
  String settingsPreviewShown(Object deliveryModeName) {
    return '$deliveryModeName · preview shown';
  }

  @override
  String get settingsRunInBackground => 'Run in background';

  @override
  String get settingsSoMessagesArrive => 'So messages arrive';

  @override
  String get settingsTransport => 'Transport';

  @override
  String get settingsWhatTheNetworkIs => 'What the network is doing';

  @override
  String get settingsBlocked => 'Blocked';

  @override
  String get settingsAcceptIntroductions => 'Accept introductions';

  @override
  String get settingsFriendsCanIntroduceYou =>
      'Friends can introduce you to theirs';

  @override
  String get settingsScamShield => 'Scam shield';

  @override
  String get settingsChecksStrangersOnYour =>
      'Checks strangers on your phone. Nothing leaves it';

  @override
  String get settingsBlockScreenshots => 'Block screenshots';

  @override
  String get settingsWholeAppHiddenFrom =>
      'Whole app hidden from recents and screenshots · takes effect after the next start';

  @override
  String get settingsWholeAppHiddenFromRecentsAnd =>
      'Whole app hidden from recents and screenshots';

  @override
  String get settingsOnNextStart => 'On · next start';

  @override
  String get settingsOffNextStart => 'Off · next start';

  @override
  String get settingsLightTheme => 'Light theme';

  @override
  String get settingsSameProtectionBrighter => 'Same protection, brighter';

  @override
  String get settingsAppLock2 => 'App lock';

  @override
  String get settingsYourPinAndA => 'Your PIN and Advanced protection';

  @override
  String get settingsPinWipePin => 'PIN · wipe PIN';

  @override
  String get settingsBackUpIdentity => 'Back up identity';

  @override
  String get settingsEncryptedFile => 'Encrypted file';

  @override
  String get settingsRestoreFromBackup => 'Restore from backup';

  @override
  String get settingsReplaceCurrent => 'Replace current';

  @override
  String get settingsDisguiseVoice => 'Disguise voice';

  @override
  String get settingsShiftsYourPitchBefore =>
      'Shifts your pitch before a voice note leaves';

  @override
  String get settingsWhyKryfo => 'Why Kryfo';

  @override
  String get settingsHowItProtectsYou => 'How it protects you';

  @override
  String get settingsResetMyInviteLink => 'Reset my invite link';

  @override
  String get settingsOldLinksAndCodes =>
      'Old links and codes stop working, for everyone';

  @override
  String get settingsResetInviteLink => 'Reset invite link?';

  @override
  String get settingsAnyoneWithAnOld =>
      'Anyone with an old code or link stops being able to reach you, on every route. People who have it but never used it will need a new one from you. Contacts, chats and history stay.';

  @override
  String get settingsReset => 'Reset';

  @override
  String get settingsInviteResetShareThe => 'Invite reset · share the new code';

  @override
  String get settingsWhatWeCanSee => 'What we can see';

  @override
  String get settingsTheHonestList => 'The honest list';

  @override
  String get settingsVersion => 'Version';

  @override
  String get settings030Alpha => '0.5.0 · alpha';

  @override
  String get settingsReportAnIssue => 'Report an issue';

  @override
  String get settingsBugOrSecurityFlaw => 'Bug or security flaw';

  @override
  String get settingsOpenSource => 'Open source';

  @override
  String get settingsLinkCopied => 'Link copied';

  @override
  String get settingsTheOfflineMapIn =>
      'The offline map in Tools is drawn from Natural Earth (public domain). Town names are from GeoNames, geonames.org, under CC BY 4.0.';

  @override
  String get settingsNotIndependentlyAuditedPre =>
      'Not independently audited. Alpha: good for testing, not yet for high-stakes use.';

  @override
  String get settingsDangerZone => 'Danger zone';

  @override
  String get settingsWipeKryfoFromThis => 'Wipe Kryfo from this phone';

  @override
  String get shieldCheckedOnThisPhone =>
      'Checked on this phone. Nothing was sent anywhere.';

  @override
  String get toolsMoreTools => 'More tools';

  @override
  String get toolsCleanAPhotoOr => 'Clean a photo or video';

  @override
  String get toolsOrShareOneTo => 'Or share one to Kryfo from your gallery';

  @override
  String get toolsMakeAPrivateQr => 'Make a private QR code';

  @override
  String get toolsLinksWiFiContacts =>
      'Links, Wi-Fi, contacts and more. Made offline';

  @override
  String get toolsLockAFile => 'Lock a file';

  @override
  String get toolsWithAPasswordOpens =>
      'With a password. Opens anywhere with age';

  @override
  String get toolsOpenALockedFile => 'Open a locked file';

  @override
  String get toolsAnyAgeFileSomeone => 'Any .age file someone sent you';

  @override
  String get toolsWorksOfflineNoContacts =>
      'Works offline · no contacts needed';

  @override
  String get toolsUsefulFrom => 'Useful from';

  @override
  String get toolsTheFirstMinute => 'the first minute.';

  @override
  String get toolsEverythingHereHappensOn =>
      'Everything here happens on this phone. Nothing is uploaded, and nobody else has to be on Kryfo.';

  @override
  String get toolsWhatDoesThisPhoto => 'What does this photo know?';

  @override
  String get toolsPlacePhoneTime => 'Place · phone · time';

  @override
  String get toolsPickAPhotoAnd =>
      'Pick a photo and see what it gives away. Then keep a clean copy.';

  @override
  String get toolsPickAPhoto => 'Pick a photo';

  @override
  String get toolsVideo => 'Video';

  @override
  String get transportTransport => 'Transport';

  @override
  String get transportNothingHereLeavesThe =>
      'Nothing here leaves the phone. It is the same state the engine uses to decide what to do.';

  @override
  String get transportStayingAlive => 'Staying alive';

  @override
  String get transportCanSend => 'Can send';

  @override
  String get commonYes => 'Yes';

  @override
  String get transportNotYet => 'Not yet';

  @override
  String get transportOnline => 'Online';

  @override
  String get transportOffline => 'Offline';

  @override
  String get transportQueuedToSend => 'Queued to send';

  @override
  String get transportOnionPublished => 'Onion published';

  @override
  String transportYes(Object uploads) {
    return 'Yes ($uploads)';
  }

  @override
  String transportTryingS(Object pubFor) {
    return 'Trying ${pubFor}s';
  }

  @override
  String transportBenchedS(Object r) {
    return 'Benched ${r}s';
  }

  @override
  String transportFails(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString fails',
      one: '$countString fail',
    );
    return '$_temp0';
  }

  @override
  String get transportOk => 'OK';

  @override
  String get transportRelaySubscriptions => 'Relay subscriptions';

  @override
  String get transportLastSent => 'Last sent';

  @override
  String get transportNever => 'Never';

  @override
  String transportSAgo(Object sx) {
    return '${sx}s ago';
  }

  @override
  String get transportLastReceived => 'Last received';

  @override
  String transportSAgo2(Object rx) {
    return '${rx}s ago';
  }

  @override
  String get transportWithNoContactsThe =>
      'With no contacts the app subscribes to no relay addresses, so no message can reach you. Scan someone to fix it.';

  @override
  String get transportSendAnythingWaitingNow => 'Send anything waiting, now';

  @override
  String get transportSending => 'Sending…';

  @override
  String get transportNothingLeftWaiting => 'Nothing left waiting';

  @override
  String transportStillWaiting(Object count) {
    return 'Still waiting: $count';
  }

  @override
  String get transportOff => 'Off';

  @override
  String get transportStarting => 'Starting';

  @override
  String get transportBootstrapped => 'Bootstrapped';

  @override
  String get transportPublishingAddress => 'Publishing address';

  @override
  String get transportReachable => 'Reachable';

  @override
  String get transportOurRelayOnion => 'Our relay (onion)';

  @override
  String get transportNever2 => 'never';

  @override
  String get transportJustNow => 'Just now';

  @override
  String transportMAgo(Object inMinutes) {
    return '${inMinutes}m ago';
  }

  @override
  String transportHAgo(Object inHours) {
    return '${inHours}h ago';
  }

  @override
  String transportDAgo(Object inDays) {
    return '${inDays}d ago';
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
  String get transportYesCheckedJustNow => 'Yes · checked just now';

  @override
  String transportNoLast(Object ago) {
    return 'No · last $ago';
  }

  @override
  String get transportLastMessageIn => 'Last message in';

  @override
  String get transportBatteryExemption => 'Battery exemption';

  @override
  String get transportUnknown => 'Unknown';

  @override
  String get transportExempt => 'Exempt';

  @override
  String get transportNotExemptTapTo => 'Not exempt · tap to fix';

  @override
  String get transportProcessUp => 'Process up';

  @override
  String get transportLastStop => 'Last stop';

  @override
  String transportEngine(Object mb, Object mb2) {
    return '$mb · engine $mb2';
  }

  @override
  String get transportLastRelayArrival => 'Last relay arrival';

  @override
  String get transportLastCheckIn => 'Last check-in';

  @override
  String get transportNoneYet => 'None yet';

  @override
  String get transportLastTorReconnect => 'Last Tor reconnect';

  @override
  String get transportCatchUpByRelay => 'Catch-up by relay';

  @override
  String get transportControlPort => 'Control port';

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
      other: '$dialsString dials',
      one: '$dialsString dial',
    );
    String _temp1 = intl.Intl.pluralLogic(
      timeouts,
      locale: localeName,
      other: '$timeoutsString timeouts',
      one: '$timeoutsString timeout',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get transportJobRuns => 'Job runs';

  @override
  String transportLast(Object jobRuns, Object ago) {
    return '$jobRuns · last $ago';
  }

  @override
  String get transportQuietStretches => 'Quiet stretches';

  @override
  String get transportNone => 'None';

  @override
  String get transportClearThisRecord => 'Clear this record';

  @override
  String get transportNothingYetThisProcess => 'Nothing yet this process';

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
    return '$t to $t2';
  }

  @override
  String vouchersVouchedBy(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Vouched by $countString',
      one: 'Vouched by',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperAtmosphere => 'Atmosphere';

  @override
  String get wallpaperJustForYouThey => 'Just for you. They see their own.';

  @override
  String get wallpaperYourPhoto => 'Your photo';

  @override
  String get wallpaperFromYourPhotos => 'From your photos';

  @override
  String get wallpaperKeepIt => 'Keep it';

  @override
  String get whyKryfoWhyKryfo => 'Why Kryfo';

  @override
  String get whyKryfoKryfoKreeFoGreek =>
      'Kryfo · KREE-fo · greek for hidden.\nA quiet place to talk, built so no one is watching.';

  @override
  String get whyKryfoRoutedThroughTor => 'Routed through tor';

  @override
  String get whyKryfoByDefaultEveryMessage =>
      'By default every message travels through tor - a chain of relays. No one, not us and not your network, can see who you talk to or where you are.';

  @override
  String get whyKryfoEndToEndEncrypted => 'End-to-end encrypted';

  @override
  String get whyKryfoMessagesAreSealedWith =>
      'Messages are sealed with keys only you and the person you are talking to hold. We could not read them if we tried.';

  @override
  String get whyKryfoNoServersHoldingYour => 'No servers holding your life';

  @override
  String get whyKryfoNoAccountNoPhone =>
      'No account, no phone number, no central server storing your chats. They live on this phone, encrypted at rest.';

  @override
  String get whyKryfoNothingLeaks => 'Nothing leaks';

  @override
  String get whyKryfoNoReadReceiptsOr =>
      'No read receipts or typing tells handed to anyone, no contact list uploaded. Metadata is what most apps leak - Kryfo is built not to.';

  @override
  String get whyKryfoVerifyItIsReally => 'Verify it is really them';

  @override
  String get whyKryfoCompareASafetyNumber =>
      'Compare a safety number in person or over a channel you trust, so you know no one is impersonating your contact.';

  @override
  String get whyKryfoTheHonestPart => 'The honest part';

  @override
  String get whyKryfoKryfoIsPreAlpha =>
      'Kryfo is in alpha and has not been audited. The crypto is real but no outside expert has checked it yet, so treat it as a work in progress, not something to trust with your life yet.';

  @override
  String get cleanerLocation => 'Location';

  @override
  String get cleanerAlreadyBlankedByAndroid => 'already blanked by Android';

  @override
  String get cleanerPhoneModel => 'Phone model';

  @override
  String get cleanerTimeTaken => 'Time taken';

  @override
  String get cleanerSerialNumber => 'Serial number';

  @override
  String get cleanerOwnerName => 'Owner name';

  @override
  String get cleanerHiddenThumbnail => 'Hidden thumbnail';

  @override
  String get cleanerContentCredentials => 'Content credentials';

  @override
  String get cleanerDataAfterThePicture => 'Data after the picture';

  @override
  String cleaner1OtherField(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString other fields',
      one: '$countString other field',
    );
    return '$_temp0';
  }

  @override
  String get lockWordsFourRandomWordsBeat =>
      'Four random words beat one clever one.';

  @override
  String lockWordsTooShortAtLeast(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Too short. At least $countString characters.',
      one: 'Too short. At least $countString character.',
    );
    return '$_temp0';
  }

  @override
  String get lockWordsWeakWhoeverGetsThe =>
      'Weak. Whoever gets the file can guess as fast as they like.';

  @override
  String get lockWordsFairLongerIsStronger => 'Fair. Longer is stronger.';

  @override
  String get lockWordsStrongFourRandomWords =>
      'Strong. Four random words beat one clever one.';

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
      other: '$countString metres',
      one: '$countString metre',
    );
    return '$_temp0';
  }

  @override
  String get photoStoryFarFromAnyTown => 'Far from any town';

  @override
  String photoStoryNear(Object where) {
    return 'Near $where';
  }

  @override
  String photoStoryAboutKmFrom(Object near, Object where) {
    return 'About $near km from $where';
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
  String get photoStoryNotAKindKryfo => 'Not a kind Kryfo can read.';

  @override
  String get photoStorySoItWillNot => 'So it will not guess.';

  @override
  String get photoStoryThisFileIsDamaged =>
      'This file is damaged or cut short.';

  @override
  String get photoStoryKryfoCouldNotRead =>
      'Kryfo could not read it to the end.';

  @override
  String get photoStoryWhereItWasRecorded => 'Where it was recorded';

  @override
  String get photoStoryWhereItWasTaken => 'Where it was taken';

  @override
  String photoStoryLocation(Object coordsLine) {
    return 'Location: $coordsLine';
  }

  @override
  String photoStoryHeightAboveTheSea(Object fix) {
    return 'Height above the sea: $fix m';
  }

  @override
  String get photoStoryLocationHiddenByAndroid => 'Location hidden by Android';

  @override
  String get photoStoryAndroidBlanksItWhen =>
      'Android blanks it when a photo is picked this way. Sharing it to Kryfo from your gallery often keeps it. The one in your gallery may still have it.';

  @override
  String get photoStoryLocationBlankedByAndroid =>
      'Location: blanked by Android before Kryfo saw it';

  @override
  String photoStoryF(Object r) {
    return 'f/$r';
  }

  @override
  String get photoStoryWhatTookIt => 'What took it';

  @override
  String photoStoryPhoneOrCamera(Object phone) {
    return 'Phone or camera: $phone';
  }

  @override
  String get photoStoryWhenItWasRecorded => 'When it was recorded';

  @override
  String get photoStoryToTheSecondWith => 'To the second, with the time zone';

  @override
  String get photoStoryToTheSecond => 'To the second';

  @override
  String photoStoryTime(Object dateFormat) {
    return 'Time: $dateFormat';
  }

  @override
  String get photoStoryLens => 'Lens';

  @override
  String photoStoryLens2(Object lens) {
    return 'Lens: $lens';
  }

  @override
  String get photoStorySoftware => 'Software';

  @override
  String photoStorySoftware2(Object software) {
    return 'Software: $software';
  }

  @override
  String get photoStorySerialNumber => 'Serial number';

  @override
  String photoStorySerialNumber2(Object serial) {
    return 'Serial number: $serial';
  }

  @override
  String get photoStoryOwnerName => 'Owner name';

  @override
  String photoStoryOwner(Object r) {
    return 'Owner: $r';
  }

  @override
  String get photoStoryHiddenThumbnail => 'Hidden thumbnail';

  @override
  String get photoStoryASmallCopyOf =>
      'A small copy of the picture inside the file. It can show what a crop removed';

  @override
  String get photoStoryMakerNotes => 'Maker notes';

  @override
  String get photoStoryMakerNotesABlock =>
      'Maker notes: a block only the maker can read';

  @override
  String get photoStoryEditingHistory => 'Editing history';

  @override
  String get photoStoryXmpEditingHistoryAnd => 'XMP: editing history and tags';

  @override
  String get photoStoryCaptions => 'Captions';

  @override
  String get photoStoryIptcCaptionsAndCredits => 'IPTC: captions and credits';

  @override
  String get photoStoryComment => 'Comment';

  @override
  String get photoStoryAWrittenComment => 'A written comment';

  @override
  String get photoStoryContentCredentials => 'Content credentials';

  @override
  String get photoStorySecondPicture => 'Second picture';

  @override
  String get photoStoryASecondPictureInside =>
      'A second picture inside the file';

  @override
  String get photoStoryMotionVideo => 'Motion video';

  @override
  String get photoStoryAShortVideoInside => 'A short video inside the file';

  @override
  String get photoStorySaveTime => 'Save time';

  @override
  String get photoStoryTheTimeItWas => 'The time it was last saved';

  @override
  String get photoStoryTimeStamps => 'Time stamps';

  @override
  String get photoStoryCreationTimeStamps => 'Creation time stamps';

  @override
  String get photoStoryDataAfterThePicture => 'Data after the picture';

  @override
  String photoStoryDataAfterTheEnd(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Data after the end of the picture: $countString bytes',
      one: 'Data after the end of the picture: $countString byte',
    );
    return '$_temp0';
  }

  @override
  String photoStoryTextField(Object k) {
    return 'Text field: $k';
  }

  @override
  String photoStoryVideoTag(Object k) {
    return 'Video tag: $k';
  }

  @override
  String photoStoryAlso(Object k) {
    return 'Also: $k';
  }

  @override
  String photoStoryCameraSettingsFlashFocus(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString camera settings (flash, focus, exposure)',
      one: '$countString camera setting (flash, focus, exposure)',
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
      other: '$countString more fields',
      one: '$countString more field',
    );
    return '$_temp0';
  }

  @override
  String get photoStoryCameraSettings => 'Camera settings';

  @override
  String photoStoryAccurateToAbout(Object metres) {
    return 'Accurate to about $metres.';
  }

  @override
  String get photoStoryEnoughToFindThe => 'Enough to find the door.';

  @override
  String get photoStoryEnoughToFindTheStreet => 'Enough to find the street.';

  @override
  String get photoStoryEnoughToFindTheArea => 'Enough to find the area.';

  @override
  String get photoStoryItKnowsWhereYou => 'It knows where you were.';

  @override
  String get photoStoryDownToTheBuilding => 'Down to the building.';

  @override
  String get photoStoryAndroidHidTheLocation => 'Android hid the location.';

  @override
  String get photoStoryTheOriginalMayStill =>
      'The original may still carry it.';

  @override
  String get photoStoryNoLocationInThis => 'No location in this one.';

  @override
  String get photoStoryItStillSaysPlenty => 'It still says plenty.';

  @override
  String get photoStoryThisOneKnowsNothing => 'This one knows nothing.';

  @override
  String get photoStoryNothingToRemove => 'Nothing to remove.';

  @override
  String get qrPayloadOpensALink => 'OPENS A LINK';

  @override
  String qrPayloadOpens(Object host) {
    return 'OPENS $host';
  }

  @override
  String get qrPayloadShowsANote => 'SHOWS A NOTE';

  @override
  String get qrPayloadScanToJoin => 'SCAN TO JOIN';

  @override
  String qrPayloadScanToJoin2(Object oneLine) {
    return 'SCAN TO JOIN · $oneLine';
  }

  @override
  String get qrPayloadANetworkNameIs =>
      'A network name is 32 characters at most.';

  @override
  String get qrPayloadAWiFiPassword =>
      'A Wi-Fi password has at least 8 characters.';

  @override
  String get qrPayloadSavesAContact => 'SAVES A CONTACT';

  @override
  String get qrPayloadWritesAnEmail => 'WRITES AN EMAIL';

  @override
  String get qrPayloadThatDoesNotLook =>
      'That does not look like an email address.';

  @override
  String get qrPayloadCallsANumber => 'CALLS A NUMBER';

  @override
  String get qrPayloadWritesAText => 'WRITES A TEXT';

  @override
  String get qrPayloadOpensAMap => 'OPENS A MAP';

  @override
  String get qrPayloadLatitudeRunsFrom90 =>
      'Latitude runs from -90 to 90, longitude from -180 to 180.';

  @override
  String get qrPayloadPayThisAddress => 'PAY THIS ADDRESS';

  @override
  String get qrPayloadABitcoinAddressIs =>
      'A bitcoin address is letters and digits only.';

  @override
  String get qrPayloadTheAmountIsIn =>
      'The amount is in BTC, with up to 8 decimals.';

  @override
  String vouchTextAnd(Object names, Object names2) {
    return '$names and $names2';
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
      other: '$restString others',
      one: '$restString other',
    );
    return '$names, $names2 and $_temp0 you know';
  }

  @override
  String vouchTextVouchedBy(Object vouchNames) {
    return 'Vouched by $vouchNames';
  }

  @override
  String vouchTextIntroducedBy(Object vouchNames) {
    return 'Introduced by $vouchNames';
  }

  @override
  String vouchTextThisSharesSAddress(Object a, Object b) {
    return 'This shares $a\'s address with $b';
  }

  @override
  String get bootFailedKryfoCouldNotStart => 'Kryfo could not start';

  @override
  String get bootFailedThisIsAFault =>
      'This is a fault on this device, not the network. Tor is not involved.';

  @override
  String get bootFailedKeysDidNotAnswer =>
      'Your phone\'s key storage stopped answering. Closing and reopening Kryfo usually fixes this.';

  @override
  String get bootFailedCloseAndReopen => 'Close and reopen Kryfo';

  @override
  String get kryfoLinkTextThatLinkIsNot =>
      'That link is not one Kryfo can read';

  @override
  String kryfoLinkTextAdd(Object who) {
    return 'Add $who?';
  }

  @override
  String kryfoLinkTextThisIsAnInvite(Object who) {
    return 'This is an invite to talk to $who. Add them only if you know where the link came from.';
  }

  @override
  String get kryfoLinkTextAddThem => 'Add them';

  @override
  String get kryfoLinkTextNotNow => 'Not now';

  @override
  String kryfoLinkTextJoinRoom(Object roomName) {
    return 'Join $roomName?';
  }

  @override
  String get kryfoLinkTextThisIsARoom =>
      'This is an invite to a burner room. Join only if you know where the link came from.';

  @override
  String kryfoLinkTextYouAlreadyHave(Object who) {
    return 'You already have $who';
  }

  @override
  String kryfoLinkTextNotTheOne(Object who) {
    return 'Not the $who in your chats';
  }

  @override
  String kryfoLinkTextSomeoneElse(Object who) {
    return 'You call someone in your chats $who. This link is from someone else. Add them only if you know where it came from.';
  }

  @override
  String kryfoLinkTextJoin(Object roomName) {
    return 'Join $roomName';
  }

  @override
  String get kryfoLinkTextKryfoLink => 'Kryfo link';

  @override
  String kryfoLinkTextAdd2(Object who) {
    return 'Add $who';
  }

  @override
  String get kryfoLinkTextBurnerRoom => 'BURNER ROOM';

  @override
  String get kryfoLinkTextThisRoomHasClosed => 'This room has closed';

  @override
  String kryfoLinkTextClosesIn(Object time) {
    return 'Closes in $time';
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
      other: 'Closes in $time · up to $capString',
    );
    return '$_temp0';
  }

  @override
  String get kryfoLinkTextJoin2 => 'Join';

  @override
  String get kryfoLinkTextYouJoinUnderA =>
      'You join under a key made for this room. Nobody in it sees your Kryfo id.';

  @override
  String get linkStubFetchedOverTorBy => 'Fetched over tor · by your device';

  @override
  String get linkStubFetchedOverTorByTheirDevice =>
      'Fetched over tor · by their device';

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
  String get mediaBubblesAudioUnavailable => 'Audio unavailable';

  @override
  String get mediaBubblesHidden => 'Hidden';

  @override
  String get mediaBubblesPlaying => 'Playing';

  @override
  String get mediaBubblesMicPermissionNeeded => 'Mic permission needed';

  @override
  String get mediaBubblesReleaseToCancel => 'Release to cancel';

  @override
  String get mediaBubblesVoiceHiddenSlideTo => 'Voice hidden · slide to cancel';

  @override
  String get mediaBubblesSlideToCancel => 'Slide to cancel';

  @override
  String get mediaBubblesSendPhoto => 'Send photo';

  @override
  String get mediaBubblesAddACaption => 'Add a caption…';

  @override
  String get motionStandby => 'STANDBY';

  @override
  String get motionConnecting => 'CONNECTING';

  @override
  String get motionBuilding => 'BUILDING';

  @override
  String get motionPublishing => 'PUBLISHING';

  @override
  String get motionReady => 'READY';

  @override
  String get motionPreparingToConnect => 'Preparing to connect';

  @override
  String get motionFindingAPrivatePath => 'Finding a private path';

  @override
  String get motionCarvingThePath => 'Carving the path';

  @override
  String get motionAnnouncingYourArrival => 'Announcing your arrival';

  @override
  String get motionYouReAnonymous => 'You\'re anonymous';

  @override
  String get motionTorIsStartingIn =>
      'Tor is starting in the background. This graph lights up as the connection forms.';

  @override
  String get motionMakingAFreshRoute =>
      'Making a fresh route through anonymous relays.';

  @override
  String get motionBouncingThroughRelaysSo =>
      'Bouncing through relays so no one can trace this back to you.';

  @override
  String get motionTellingTheNetworkYou =>
      'Telling the network you\'re online, without revealing where.';

  @override
  String get motionYourIpIsHidden =>
      'Your ip is hidden. Only people with your Kryfo can reach you.';

  @override
  String get motionBuilding2 => 'building';

  @override
  String get motionOpen => 'open';

  @override
  String get motionLive => 'live';

  @override
  String motionCircuit(Object circuit) {
    return 'Circuit · *$circuit*';
  }

  @override
  String get motionDelivered => 'Delivered';

  @override
  String get motionSent => 'Sent';

  @override
  String get motion1Hop => '1 hop';

  @override
  String get motion3Hops => '3 hops';

  @override
  String get movedStripThisKryfoHasMoved =>
      'This Kryfo has moved to another device. Nothing sent from here reaches anyone.';

  @override
  String get navBarChats => 'Chats';

  @override
  String get navBarTools => 'Tools';

  @override
  String get navBarSupport => 'Support';

  @override
  String get navBarMe => 'Me';

  @override
  String get pairCodePanelPuttingYourInviteIn => 'Putting your invite in place';

  @override
  String get pairCodePanelYourInviteIsNot => 'Your invite is not ready yet';

  @override
  String get pairCodePanelReadSixDigitsOut =>
      'Read six digits out loud and they can add you. Nothing else needs to change hands.';

  @override
  String get pairCodePanelWorking => 'Working';

  @override
  String get pairCodePanelOrMakeASix => 'Or make a six digit code to read out';

  @override
  String get pairCodePanelCodeCopied => 'Code copied';

  @override
  String pairCodePanelBurnsIn(Object mm, Object ss) {
    return 'Burns in $mm:$ss';
  }

  @override
  String get pairCodePanelTheyTapAddChoose =>
      'They tap add, choose code, and type these.';

  @override
  String get pairCodePanelTheyOpenKryfoTap =>
      'They open Kryfo, tap add, choose pairing code and type these six digits. Make a new one for the next person.';

  @override
  String get pairCodePanelYourWords => 'Your three words';

  @override
  String pinsPinnedMessages(Object count) {
    return 'Pinned messages · $count';
  }

  @override
  String get pinsPinnedMessages2 => 'Pinned messages';

  @override
  String get pinsPhoto => 'Photo';

  @override
  String get pinsVoiceMessage => 'Voice message';

  @override
  String get pinsMessage => 'Message';

  @override
  String pinsToday(Object hm) {
    return 'Today · $hm';
  }

  @override
  String get pinsPinned => 'Pinned';

  @override
  String pinsOf(Object pinsLength, Object kMaxPins) {
    return '$pinsLength of $kMaxPins';
  }

  @override
  String get pinsNothingPinnedHereYet =>
      'Nothing pinned here yet. Hold a message and choose Pin, and it waits here for everyone in the chat.';

  @override
  String get pinsJump => 'Jump';

  @override
  String get pinsUnpin => 'Unpin';

  @override
  String previewStripFetchedOverTor(Object domainOf) {
    return '$domainOf · fetched over tor';
  }

  @override
  String get previewStripDropThePreview => 'Drop the preview';

  @override
  String get previewStripAddPreview => 'Add preview';

  @override
  String get previewStripFetchingOverTor => 'Fetching over tor…';

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
  String get torBootSplashNoShortcutsNoTraces => 'No shortcuts, no traces';

  @override
  String get torBootSplashTheNetworkThatKeeps =>
      'The network that keeps you private is warming up';

  @override
  String get torBootSplashMadeOnThisPhone =>
      'Made on this phone. Nothing is sent anywhere.';

  @override
  String get torBootSplashFirstLaunchTakesA =>
      'First launch takes a moment · only on startup';

  @override
  String get torBootSplashTakingLonger => 'This is taking longer than usual';

  @override
  String get videoBubbleNothingHereOpensThat =>
      'Nothing here opens that · sharing instead';

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
  String get notificationsChannelName => 'Messages';

  @override
  String get cameraClose => 'Close';

  @override
  String get cameraFlash => 'Flash';

  @override
  String get cameraPhoto => 'Photo';

  @override
  String get cameraVideo => 'Video';

  @override
  String get cameraRetake => 'Retake';

  @override
  String get seenIntroductions => 'Introductions';

  @override
  String get donateAddress => 'Address';

  @override
  String get donateCopy => 'Copy';

  @override
  String get donateDone => 'Done';

  @override
  String get donateTierSupporter => 'Supporter';

  @override
  String get donateTierPatron => 'Patron';

  @override
  String get donateTierGuardian => 'Guardian';

  @override
  String get chatBlock => 'Block';

  @override
  String get chatDecline => 'Decline';

  @override
  String get chatAccept => 'Accept';

  @override
  String get bridgesConnecting => 'Connecting';

  @override
  String get bridgesSavedTag => 'Saved';

  @override
  String get restoreMade => 'Made';

  @override
  String get restoreContacts => 'Contacts';

  @override
  String get restoreMessages => 'Messages';

  @override
  String get restoreAttachments => 'Attachments';

  @override
  String get restoreHiddenChats => 'Hidden chats';

  @override
  String get restoreHiddenFollow =>
      'Your hidden chats, under a new hidden chats PIN you choose at the end.';

  @override
  String get restoreChooseHiddenPin =>
      'This backup holds hidden chats. Choose a hidden chats PIN for them.';

  @override
  String get restoreHiddenLockFirst =>
      'Hidden chats need the app lock, so Kryfo gets a PIN of its own first.';

  @override
  String get shieldBlock => 'Block';

  @override
  String get shieldDelete => 'Delete';

  @override
  String get shieldIgnore => 'Ignore';

  @override
  String get profileIdentity => 'Identity';

  @override
  String get avatarPickerShape => 'Shape';

  @override
  String get avatarPickerColour => 'Colour';

  @override
  String get avatarPickerTurn => 'Turn';

  @override
  String avatarPickerOption(String what, int n, int count) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$what, $nString of $countString';
  }

  @override
  String get avatarPickerYourInitial => 'Your initial';

  @override
  String get transportStatus => 'Status';

  @override
  String get transportBootstrap => 'Bootstrap';

  @override
  String get transportNetwork => 'Network';

  @override
  String get transportConnectivity => 'Connectivity';

  @override
  String get transportRelays => 'Relays';

  @override
  String get transportTraffic => 'Traffic';

  @override
  String get transportContacts => 'Contacts';

  @override
  String get transportKnown => 'Known';

  @override
  String get transportListening => 'Listening';

  @override
  String get transportMemory => 'Memory';

  @override
  String get settingsConnected => 'Connected';

  @override
  String get settingsScreenshots => 'Screenshots';

  @override
  String get settingsBlocked2 => 'Blocked';

  @override
  String get settingsAllowed => 'Allowed';

  @override
  String get settingsOn => 'On';

  @override
  String get settingsOff => 'Off';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsPrivacy => 'Privacy';

  @override
  String get settingsSecurity => 'Security';

  @override
  String get settingsBackup => 'Backup';

  @override
  String get settingsVoice => 'Voice';

  @override
  String get settingsAbout => 'About';

  @override
  String get wallpaperGradients => 'Gradients';

  @override
  String get wallpaperPatterns => 'Patterns';

  @override
  String get wallpaperMoods => 'Moods';

  @override
  String get confirmSheetKeep => 'Keep';

  @override
  String get confirmSheetSave => 'Save';

  @override
  String get confirmSheetCancel => 'Cancel';

  @override
  String bridgesSaved(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString bridges',
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

    return '$goodString accepted, $badString not understood';
  }

  @override
  String get bridgesNoneUsable =>
      'None of these lines is a usable bridge, so bridges stay off';

  @override
  String get bridgesCouldNotApply =>
      'The bridges could not be applied. Try saving again.';

  @override
  String get languageTitle => 'Language';

  @override
  String get languageMatchPhone => 'Match phone';

  @override
  String languageMatchPhoneValue(Object language) {
    return 'Match phone ($language)';
  }

  @override
  String get languageRedrawLine =>
      'Kryfo redraws in the new language and opens on your chats.';

  @override
  String languageButton(Object language) {
    return 'Language: $language';
  }

  @override
  String get androidServiceTitle => 'Kryfo is on';

  @override
  String get androidServiceText =>
      'Your encrypted line stays open so messages arrive';

  @override
  String get androidChannelName => 'Staying connected';

  @override
  String get androidChannelDescription =>
      'Keeps Kryfo connected so encrypted messages arrive while it is closed. Turning this off stops delivery.';

  @override
  String get videoViewerPlay => 'Play';

  @override
  String get videoViewerPause => 'Pause';

  @override
  String get videoViewerPlayAgain => 'Play again';

  @override
  String get videoViewerCannotPlay => 'This phone can\'t play this video here.';

  @override
  String get videoViewerOpenElsewhere => 'Open in another app';

  @override
  String get photoKnowsLookedFor => 'Looked for';

  @override
  String get photoKnowsNotInIt => 'Not in it';

  @override
  String get languageNameEn => 'English';

  @override
  String get languageNameDe => 'German';

  @override
  String get languageNameFr => 'French';

  @override
  String get languageNameEs => 'Spanish';

  @override
  String get languageNamePt => 'Portuguese (Brazil)';

  @override
  String get languageNameIt => 'Italian';

  @override
  String get languageNameRu => 'Russian';

  @override
  String get languageNameUk => 'Ukrainian';

  @override
  String get languageNameTr => 'Turkish';

  @override
  String get languageNameZh => 'Chinese (Simplified)';

  @override
  String get languageNameZhHant => 'Chinese (Traditional)';

  @override
  String get languageNameVi => 'Vietnamese';

  @override
  String get languageNameId => 'Indonesian';

  @override
  String get languageNameFa => 'Persian';

  @override
  String get languageNameAr => 'Arabic';

  @override
  String get languageLaterLine => 'You can change this any time in settings.';

  @override
  String get pollAttach => 'Poll';

  @override
  String get pollNewTitle => 'New poll';

  @override
  String get pollQuestionHint => 'Ask the group something';

  @override
  String get pollOptionsLabel => 'Options';

  @override
  String pollOptionHint(Object n) {
    return 'Option $n';
  }

  @override
  String get pollAddOption => 'Add an option';

  @override
  String get pollMaxLine => 'Twelve options at most.';

  @override
  String get pollMultiple => 'Several answers';

  @override
  String get pollMultipleLine => 'People can pick more than one.';

  @override
  String get pollSend => 'Send poll';

  @override
  String get pollKind => 'Poll';

  @override
  String get pollKindMulti => 'Poll · several answers';

  @override
  String get pollKindClosed => 'Final result';

  @override
  String pollVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count votes',
      one: '$count vote',
      zero: 'No votes yet',
    );
    return '$_temp0';
  }

  @override
  String get pollVote => 'Vote';

  @override
  String get pollTakeBack => 'Take my vote back';

  @override
  String get pollClose => 'Close poll';

  @override
  String get pollCloseTitle => 'Close this poll?';

  @override
  String get pollCloseLine =>
      'Everyone sees the final result, and nobody can vote after this.';

  @override
  String get pollCloseYes => 'Close it';

  @override
  String pollPreview(Object question) {
    return 'Poll: $question';
  }

  @override
  String get pollWhoVoted => 'Who voted';

  @override
  String get pollNobody => 'Nobody yet';

  @override
  String get pollYou => 'You';

  @override
  String pollOptionA11y(Object option, Object share) {
    return '$option, $share';
  }

  @override
  String get pollPickOne => 'Pick one';

  @override
  String get pollPickSeveral => 'Pick one or more';

  @override
  String get searchOpen => 'Search';

  @override
  String get searchHint => 'Search chats and messages';

  @override
  String get searchFilterAll => 'All';

  @override
  String get searchFilterPhotos => 'Photos';

  @override
  String get searchFilterVideos => 'Videos';

  @override
  String get searchFilterFiles => 'Files';

  @override
  String get searchFilterLinks => 'Links';

  @override
  String get searchChats => 'Chats';

  @override
  String get searchMessages => 'Messages';

  @override
  String get searchIntroTitle => 'Search your chats';

  @override
  String get searchIntroLine =>
      'Names, words, photos, files and links. The search runs on this phone and sends nothing anywhere.';

  @override
  String get searchNothing => 'Nothing found';

  @override
  String get searchNothingLine => 'Try another word, or another filter.';

  @override
  String searchMatches(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count matches',
      one: '$count match',
    );
    return '$_temp0';
  }

  @override
  String searchMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more',
      one: '$count more',
    );
    return '$_temp0';
  }

  @override
  String searchFilling(Object share) {
    return 'Adding older messages · $share';
  }

  @override
  String get searchClear => 'Clear';

  @override
  String get handleShowInSearch => 'Show me in search';

  @override
  String get handleShowInSearchLine =>
      'Anyone can find this handle and message you.';

  @override
  String handleShownAs(Object name) {
    return 'Shown as $name';
  }

  @override
  String get handleNameInSearch => 'Name in search';

  @override
  String get handleNameInSearchLine =>
      'Optional. It shows next to your handle when someone searches. Anyone can find this handle and message you.';

  @override
  String get handleNameHint => 'Your name, or leave it empty';

  @override
  String get handleShowMe => 'Show me';

  @override
  String get handleSearchOff => 'You\'re out of search';

  @override
  String handleSearchOn(Object handle) {
    return 'You\'re in search as @$handle';
  }

  @override
  String get handleRegistryFailed =>
      'Couldn\'t reach the registry. Try again in a minute.';

  @override
  String get handleCheckClock =>
      'Check the phone\'s date and time, then try again.';

  @override
  String get searchPeople => 'People';

  @override
  String searchPeopleAsk(Object query) {
    return 'Look for “$query” among public handles';
  }

  @override
  String get searchPeopleLine =>
      'Asked over Tor. The registry keeps no record of it.';

  @override
  String get searchPeopleNone => 'No public handle matches';

  @override
  String get searchPeopleOffline => 'Tor isn\'t ready yet';

  @override
  String get searchPeopleBusy =>
      'Too many searches right now. Try again in a moment.';

  @override
  String get searchPeopleUnreachable => 'Couldn\'t reach the registry';

  @override
  String get peopleVerified => 'Verified handle';

  @override
  String get peopleAdd => 'Add';

  @override
  String peopleFingerprint(Object fp) {
    return 'Key fingerprint · $fp';
  }

  @override
  String get peopleFingerprintLine =>
      'Check it matches what they see in their app.';

  @override
  String get peopleAdding => 'Adding…';

  @override
  String handleNobodyHasClaimed(Object handle) {
    return 'Nobody has claimed $handle';
  }

  @override
  String get handleThatHandleIsTaken => 'That handle is taken';

  @override
  String get pinPickDifferent => 'Pick a different PIN';

  @override
  String get settingsKeptOnWhileLock => 'Kept on while the app lock is on.';

  @override
  String get lockFingerAfterPin =>
      'Type your PIN once to use your fingerprint again.';

  @override
  String get pinsAdvanced => 'Advanced protection';

  @override
  String get pinsAdvancedLine =>
      'For when someone makes you unlock your phone.';

  @override
  String get pinsWipeLine =>
      'Typed on the lock screen, it wipes Kryfo from this phone.';

  @override
  String get pinsDecoyPin => 'Decoy PIN';

  @override
  String get pinsDecoyLine => 'Opens an empty Kryfo, as if just installed.';

  @override
  String get pinsSetADecoyPin => 'Set a decoy PIN';

  @override
  String get pinsChangeDecoyPin => 'Change decoy PIN';

  @override
  String get pinsRemoveTheDecoyPin => 'Remove the decoy PIN?';

  @override
  String get pinsTheDecoyGoes => 'The empty Kryfo it opens goes with it.';

  @override
  String get pinsTurnOffWithDecoy =>
      'Every PIN goes, the decoy and its Kryfo and any hidden chats with them. Anyone holding your phone opens Kryfo as you.';

  @override
  String get pinsHowThisWorks => 'How this works';

  @override
  String get flowEnterYourPin => 'Enter your PIN';

  @override
  String get flowEnterYourPinLine => 'The one that opens Kryfo.';

  @override
  String get flowWipeTitle => 'A wipe PIN';

  @override
  String get flowWipe1 =>
      'Typed on the lock screen instead of your PIN, it wipes Kryfo from this phone and closes it. To whoever is watching, the app just stopped.';

  @override
  String get flowWipe2 =>
      'It takes every chat and your identity with it, and the decoy if you have one.';

  @override
  String get flowWipeChoose => 'Choose a wipe PIN';

  @override
  String get flowWipeDone => 'Wipe PIN set';

  @override
  String get flowWipeDoneLine =>
      'Nothing on the lock screen shows it is there.';

  @override
  String get flowDecoyTitle => 'A decoy PIN';

  @override
  String get flowDecoy1 => 'Opens an empty Kryfo, as if just installed.';

  @override
  String get flowDecoyFinger =>
      'Your fingerprint opens your real Kryfo. If someone could make you use it, turn fingerprint off.';

  @override
  String get flowDecoyDigits =>
      'Use the same number of digits as your PIN, because anyone watching can count the dots.';

  @override
  String get flowDecoyShade =>
      'Notifications already in the shade were already seen. While the decoy is open, no new ones show.';

  @override
  String get flowDecoyChoose => 'Choose a decoy PIN';

  @override
  String get flowDecoyDone => 'Decoy PIN set';

  @override
  String get flowDecoyDoneLine =>
      'Type it on the lock screen to open the empty Kryfo. To leave it, switch away and enter your PIN.';

  @override
  String get flowLaw =>
      'In some countries, refusing to unlock a phone or hiding data from officials is an offence in itself. Know the law where you travel.';

  @override
  String get howWipe =>
      'Typed on the lock screen, the wipe PIN wipes every chat, your identity and any decoy, then closes Kryfo. It works even while the pad is held after wrong tries.';

  @override
  String get howDecoy =>
      'The decoy PIN opens a second, empty Kryfo with three words of its own. Messages to your real Kryfo keep arriving underneath, silently. To leave the decoy, switch away and enter your PIN.';

  @override
  String get flowNotSet => 'Could not set it. Try again.';

  @override
  String get pinsHiddenChats => 'Hidden chats';

  @override
  String get pinsHiddenLine =>
      'Chosen chats stay out of sight until you enter your hidden chats PIN: not in the list, not in search, no notifications.';

  @override
  String get pinsSetUp => 'Set up';

  @override
  String get pinsChangeHiddenPin => 'Change hidden chats PIN';

  @override
  String get pinsHideMoreChats => 'Hide more chats';

  @override
  String get pinsRemoveHiddenChats => 'Remove hidden chats';

  @override
  String get pinsRemoveHiddenTitle => 'Remove hidden chats?';

  @override
  String get pinsRemoveHiddenLine =>
      'They come back to your chat list, and the hidden chats PIN stops opening anything.';

  @override
  String get pinsTurnOffHiddenFirst =>
      'Hidden chats need the app lock. Remove them first, and they come back to your chat list.';

  @override
  String get flowVaultTitle => 'Hidden chats';

  @override
  String get flowVault1 =>
      'Pick chats and groups to hide. Your PIN opens Kryfo without them. A hidden chats PIN opens everything, hidden chats included.';

  @override
  String get flowVault2 =>
      'While out of sight, they never notify or show a badge. Their messages keep arriving and wait, sealed, for your hidden chats PIN.';

  @override
  String get flowVaultFinger =>
      'Your fingerprint opens Kryfo without hidden chats.';

  @override
  String get flowVaultDigits =>
      'Give your PIN six digits or more too, because anyone watching can count the dots.';

  @override
  String get flowVaultReplace =>
      'This replaces any hidden chats this phone already holds.';

  @override
  String get flowVaultChoose => 'Choose a hidden chats PIN';

  @override
  String get flowVaultChooseLine => 'Six digits or more.';

  @override
  String get flowEnterHiddenPinLine => 'The one that opens your hidden chats.';

  @override
  String get flowVaultForgetTitle => 'Remember this PIN';

  @override
  String get flowVaultForget =>
      'If you forget this PIN, your hidden chats are gone for good. Nobody can get them back, not even us.';

  @override
  String get flowVaultForgetOk => 'I understand';

  @override
  String get flowVaultPickTitle => 'Choose chats to hide';

  @override
  String get flowVaultPickLine =>
      'They leave your chat list now. Your hidden chats PIN brings them back into view.';

  @override
  String flowVaultPickButton(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hide $countString chats',
      one: 'Hide 1 chat',
      zero: 'Hide nothing yet',
    );
    return '$_temp0';
  }

  @override
  String get flowVaultPickEmpty => 'No chats to hide yet.';

  @override
  String get flowVaultBackupTitle => 'Make a backup now?';

  @override
  String get flowVaultBackupLine =>
      'A backup made now holds your hidden chats too, under a passphrase of its own. If you forget the hidden chats PIN, it is the only way back to them.';

  @override
  String get flowVaultBackupNow => 'Make a backup';

  @override
  String get flowVaultNotNow => 'Not now';

  @override
  String get flowVaultDone => 'Hidden chats set up';

  @override
  String get flowVaultDoneLine =>
      'Type your hidden chats PIN on the lock screen to see them. Switch away and they are out of sight again.';

  @override
  String get flowVaultChanged => 'Hidden chats PIN changed';

  @override
  String get flowVaultChangedLine =>
      'Your hidden chats open with the new one. The old one opens nothing now.';

  @override
  String get howVault =>
      'Your hidden chats PIN opens Kryfo with your hidden chats, your PIN and your fingerprint without them. Setting hidden chats up again replaces the ones this phone holds. Forget the hidden chats PIN and they are gone for good.';

  @override
  String get chatHide => 'Hide chat';

  @override
  String get groupHide => 'Hide group';

  @override
  String get chatHidden => 'Hidden';

  @override
  String get chatHiddenToast => 'Hidden from your chat list';

  @override
  String get chatShowInList => 'Show in chat list';

  @override
  String get stickerOpen => 'Stickers';

  @override
  String get stickerRecent => 'Recent';

  @override
  String stickerA11y(String emoji) {
    return 'Sticker $emoji';
  }

  @override
  String get stickerRemoveRecent => 'Remove from recent';

  @override
  String get stickerCouldNotLoad => 'Stickers could not be loaded';

  @override
  String get stickerLabel => 'Sticker';

  @override
  String get timedMessageLabel => 'Timed message';

  @override
  String get stickerNewer => 'From a newer Kryfo';

  @override
  String get devLinkMismatch =>
      'This link says it is Marios, but its key does not match. It was not added.';

  @override
  String get devName => 'Marios';

  @override
  String get devRowTitle => 'Marios · built Kryfo';

  @override
  String get devWelcome =>
      'Hi, I\'m Marios, I build Kryfo. Tell me anything: bugs, ideas, questions. I read everything.';

  @override
  String get devPinned => 'Pinned in Kryfo';

  @override
  String get devAnonymous => 'Anonymous';

  @override
  String get devAboutLine =>
      'Marios\'s key is built into Kryfo. Every message from him is checked against it, so nobody else can write as him.';

  @override
  String get devKeyLabel => 'His key';

  @override
  String get devDeleteLine =>
      'Every message goes, and the chat will not come back.';

  @override
  String get devDeleteLineAnon =>
      'Every message and the name made for this chat go, and the chat will not come back.';

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
  String get settingsWriteToMarios => 'Write to Marios';

  @override
  String get settingsWriteToMariosHint => 'Bugs, ideas, questions';

  @override
  String get seenDevChat => 'The Marios chat';

  @override
  String get seenDevChatCell => 'If you write';

  @override
  String get seenDevChatLine =>
      'Nothing until you write. Then what you send, and your three words unless you write anonymously.';

  @override
  String get devWriteAnonymously => 'Write anonymously';

  @override
  String get devUseMyWords => 'Use my three words';

  @override
  String get devWhoSeesWhat => 'How this works';

  @override
  String get devWhoWords =>
      'With your three words, it is a chat like any other: Marios can write back, and your face and supporter badge stay with you.';

  @override
  String get devWhoAnon =>
      'Anonymously, Kryfo makes a new name and keys for this chat only. They stay on this phone and are never used anywhere else.';

  @override
  String get devWhoNothingYet =>
      'Nothing leaves your phone until you send your first message.';

  @override
  String get devWhoChoiceStays => 'Your choice stays with this chat.';

  @override
  String get devKeyCheckFailed =>
      'Could not check Marios\'s key. Nothing was sent.';

  @override
  String get devLockLine =>
      'Marios will read these. You can write more once he replies.';

  @override
  String get devNewKey => 'Marios has a new key';

  @override
  String get devStartNewChat => 'Start a new chat';

  @override
  String get devKeyRetired =>
      'This key was retired. Nothing more can be sent or received here.';

  @override
  String get devNamelessLine =>
      'The name made for this chat stays on the phone it was made on, so here it can only be read.';

  @override
  String get devStartNewLine =>
      'Every message here goes, and a fresh chat opens.';

  @override
  String get devVoiceDisguised => 'Your voice is disguised in this chat';

  @override
  String get devChatOptions => 'Chat options';

  @override
  String appLinkOtherKey(Object id) {
    return 'This link says it is $id, but its key does not match. It was not added.';
  }

  @override
  String scamShieldSaysItIs(Object shown) {
    return 'Says it is $shown, but its key does not match';
  }

  @override
  String get requestsSomeoneNew => 'Someone new';

  @override
  String get appYourOwnInvite =>
      'This is your own invite. Share it with someone else to connect.';

  @override
  String appTheyAreBlocked(Object id) {
    return 'You blocked $id. Unblock them under Blocked in Settings to add them again.';
  }

  @override
  String get devLinkGone =>
      'You deleted the chat with Marios. To start a new one, tap Write to Marios in Settings.';

  @override
  String lockTooManyTriesFor(Object left) {
    return 'Too many tries · $left';
  }
}
