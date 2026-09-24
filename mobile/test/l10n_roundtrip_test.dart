// SPDX-License-Identifier: GPL-3.0-or-later
// generated from lib/l10n/app_en.arb by the l10n tools: every english key
// renders exactly as the arb says, plurals at 0, 1, 2 and 5.
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';

void main() {
  test('english keys render as app_en.arb says', () {
    final l = l10n;
    expect(l.atmosphereNone, "none");
    expect(l.atmosphereEmber, "ember");
    expect(l.atmosphereDusk, "dusk");
    expect(l.atmosphereMoss, "moss");
    expect(l.atmosphereRose, "rose");
    expect(l.atmosphereDots, "dots");
    expect(l.atmosphereGrid, "grid");
    expect(l.atmosphereWaves, "waves");
    expect(l.atmosphereRain, "rain");
    expect(l.atmosphereLateNight, "Late night");
    expect(l.atmosphereWarmAfternoon, "Warm afternoon");
    expect(l.atmosphereSnow, "snow");
    expect(l.atmosphereDesert, "desert");
    expect(l.atmospherePaper, "paper");
    expect(
      l.backupThatPassphraseDoesNot,
      "That passphrase does not open this file",
    );
    expect(l.backupThatFileIsNot, "That file is not a kryfo backup");
    expect(
      l.backupThisBackupIsFrom,
      "This backup is from a newer kryfo. Update the app, then try again",
    );
    expect(
      l.backupThisFileIsDamaged,
      "This file is damaged and cannot be read",
    );
    expect(l.backupCouldNotMakeThe, "could not make the key");
    expect(l.contactCardMessageMeOn, "Message me on");
    expect(
      l.contactCardScanItOrType,
      "Scan it, or type the three words into kryfo.\nThis card knows nothing about you beyond that.",
    );
    expect(
      l.contactCardMessageMeOnKryfo("<haloId>"),
      "Message me on kryfo · <haloId>",
    );
    expect(l.contactStatusBlocked, "blocked");
    expect(l.contactStatusKeysVerifiedInPerson, "Keys verified in person");
    expect(l.contactStatusWaitingInRequests, "Waiting in requests");
    expect(l.contactStatusAddedByHand, "Added by hand");
    expect(l.deliveryModeAlwaysOn, "Always on");
    expect(l.deliveryModeCheckIns, "Check-ins");
    expect(l.deliveryModeThroughAHelperApp, "Through a helper app");
    expect(l.deliveryModeNotYet, "not yet");
    expect(l.deliveryModeJustNow, "just now");
    expect(l.deliveryModeMinAgo(0), "0 min ago");
    expect(l.deliveryModeMinAgo(1), "1 min ago");
    expect(l.deliveryModeMinAgo(2), "2 min ago");
    expect(l.deliveryModeMinAgo(5), "5 min ago");
    expect(l.deliveryMode1HourAgo(0), "0 hours ago");
    expect(l.deliveryMode1HourAgo(1), "1 hour ago");
    expect(l.deliveryMode1HourAgo(2), "2 hours ago");
    expect(l.deliveryMode1HourAgo(5), "5 hours ago");
    expect(l.deliveryModeYesterday, "yesterday");
    expect(l.deliveryModeDaysAgo(0), "0 days ago");
    expect(l.deliveryModeDaysAgo(1), "1 day ago");
    expect(l.deliveryModeDaysAgo(2), "2 days ago");
    expect(l.deliveryModeDaysAgo(5), "5 days ago");
    expect(l.deliveryModeConnected, "Connected");
    expect(l.deliveryModeConnecting, "Connecting");
    expect(l.deliveryModeNotConnected, "Not connected");
    expect(l.deliveryModeCheckingNow, "Checking now");
    expect(l.deliveryModeLastCheckIn("<agoLine>"), "last check-in <agoLine>");
    expect(l.deliveryModeNoCheckInYet, "no check-in yet");
    expect(l.deliveryModeConnectedNow("<last>"), "Connected now · <last>");
    expect(l.deliveryModeConnecting2("<last>"), "Connecting · <last>");
    expect(l.deliveryModeNoCheckInYet2, "No check-in yet");
    expect(l.deliveryModeLastChecked("<agoLine>"), "Last checked <agoLine>");
    expect(l.deliveryModeAHelperApp, "a helper app");
    expect(
      l.deliveryModeWokenByNoWake("<who>"),
      "Woken by <who> · no wake-up yet",
    );
    expect(
      l.deliveryModeWokenByLastWake("<who>", "<agoLine>"),
      "Woken by <who> · last wake-up <agoLine>",
    );
    expect(l.introBudgetTomorrow, "tomorrow");
    expect(l.introBudgetInDays(0), "in 0 days");
    expect(l.introBudgetInDays(1), "in 1 day");
    expect(l.introBudgetInDays(2), "in 2 days");
    expect(l.introBudgetInDays(5), "in 5 days");
    expect(l.introBudgetInAnHour, "in an hour");
    expect(l.introBudgetInHours(0), "in 0 hours");
    expect(l.introBudgetInHours(1), "in 1 hour");
    expect(l.introBudgetInHours(2), "in 2 hours");
    expect(l.introBudgetInHours(5), "in 5 hours");
    expect(l.introBudgetInAFewMinutes, "in a few minutes");
    expect(l.lockStateUnlockKryfo, "Unlock kryfo");
    expect(l.appInvalidUri, "invalid uri");
    expect(l.appBundleError("<e>"), "Bundle error: <e>");
    expect(l.appAlreadySaved("<parsed>"), "Already saved: <parsed>");
    expect(
      l.appAddedYouCanMessage("<parsed>"),
      "Added <parsed> · you can message them now",
    );
    expect(l.appPeerImportedV1("<parsed>"), "Peer imported (v1): <parsed>");
    expect(l.appLongWindow("<line>"), "<line> long window");
    expect(
      l.appOf("<line>", 0, 0, "<c>", 0, 0),
      "<line> (0 of 0, connect <c>s, 0 pages, 0 events)",
    );
    expect(
      l.appOf("<line>", 0, 0, "<c>", 0, 1),
      "<line> (0 of 0, connect <c>s, 0 pages, 1 event)",
    );
    expect(
      l.appOf("<line>", 0, 0, "<c>", 0, 2),
      "<line> (0 of 0, connect <c>s, 0 pages, 2 events)",
    );
    expect(
      l.appOf("<line>", 0, 0, "<c>", 0, 5),
      "<line> (0 of 0, connect <c>s, 0 pages, 5 events)",
    );
    expect(
      l.appOf("<line>", 0, 0, "<c>", 1, 0),
      "<line> (0 of 0, connect <c>s, 1 page, 0 events)",
    );
    expect(
      l.appOf("<line>", 0, 0, "<c>", 1, 1),
      "<line> (0 of 0, connect <c>s, 1 page, 1 event)",
    );
    expect(
      l.appOf("<line>", 0, 0, "<c>", 1, 2),
      "<line> (0 of 0, connect <c>s, 1 page, 2 events)",
    );
    expect(
      l.appOf("<line>", 0, 0, "<c>", 1, 5),
      "<line> (0 of 0, connect <c>s, 1 page, 5 events)",
    );
    expect(
      l.appOf("<line>", 0, 0, "<c>", 2, 0),
      "<line> (0 of 0, connect <c>s, 2 pages, 0 events)",
    );
    expect(
      l.appOf("<line>", 0, 0, "<c>", 2, 1),
      "<line> (0 of 0, connect <c>s, 2 pages, 1 event)",
    );
    expect(
      l.appOf("<line>", 0, 0, "<c>", 2, 2),
      "<line> (0 of 0, connect <c>s, 2 pages, 2 events)",
    );
    expect(
      l.appOf("<line>", 0, 0, "<c>", 2, 5),
      "<line> (0 of 0, connect <c>s, 2 pages, 5 events)",
    );
    expect(
      l.appOf("<line>", 0, 0, "<c>", 5, 0),
      "<line> (0 of 0, connect <c>s, 5 pages, 0 events)",
    );
    expect(
      l.appOf("<line>", 0, 0, "<c>", 5, 1),
      "<line> (0 of 0, connect <c>s, 5 pages, 1 event)",
    );
    expect(
      l.appOf("<line>", 0, 0, "<c>", 5, 2),
      "<line> (0 of 0, connect <c>s, 5 pages, 2 events)",
    );
    expect(
      l.appOf("<line>", 0, 0, "<c>", 5, 5),
      "<line> (0 of 0, connect <c>s, 5 pages, 5 events)",
    );
    expect(
      l.appConnectSPagesEvents("<line>", "<c>", 0, 0),
      "<line> (connect <c>s, 0 pages, 0 events)",
    );
    expect(
      l.appConnectSPagesEvents("<line>", "<c>", 0, 1),
      "<line> (connect <c>s, 0 pages, 1 event)",
    );
    expect(
      l.appConnectSPagesEvents("<line>", "<c>", 0, 2),
      "<line> (connect <c>s, 0 pages, 2 events)",
    );
    expect(
      l.appConnectSPagesEvents("<line>", "<c>", 0, 5),
      "<line> (connect <c>s, 0 pages, 5 events)",
    );
    expect(
      l.appConnectSPagesEvents("<line>", "<c>", 1, 0),
      "<line> (connect <c>s, 1 page, 0 events)",
    );
    expect(
      l.appConnectSPagesEvents("<line>", "<c>", 1, 1),
      "<line> (connect <c>s, 1 page, 1 event)",
    );
    expect(
      l.appConnectSPagesEvents("<line>", "<c>", 1, 2),
      "<line> (connect <c>s, 1 page, 2 events)",
    );
    expect(
      l.appConnectSPagesEvents("<line>", "<c>", 1, 5),
      "<line> (connect <c>s, 1 page, 5 events)",
    );
    expect(
      l.appConnectSPagesEvents("<line>", "<c>", 2, 0),
      "<line> (connect <c>s, 2 pages, 0 events)",
    );
    expect(
      l.appConnectSPagesEvents("<line>", "<c>", 2, 1),
      "<line> (connect <c>s, 2 pages, 1 event)",
    );
    expect(
      l.appConnectSPagesEvents("<line>", "<c>", 2, 2),
      "<line> (connect <c>s, 2 pages, 2 events)",
    );
    expect(
      l.appConnectSPagesEvents("<line>", "<c>", 2, 5),
      "<line> (connect <c>s, 2 pages, 5 events)",
    );
    expect(
      l.appConnectSPagesEvents("<line>", "<c>", 5, 0),
      "<line> (connect <c>s, 5 pages, 0 events)",
    );
    expect(
      l.appConnectSPagesEvents("<line>", "<c>", 5, 1),
      "<line> (connect <c>s, 5 pages, 1 event)",
    );
    expect(
      l.appConnectSPagesEvents("<line>", "<c>", 5, 2),
      "<line> (connect <c>s, 5 pages, 2 events)",
    );
    expect(
      l.appConnectSPagesEvents("<line>", "<c>", 5, 5),
      "<line> (connect <c>s, 5 pages, 5 events)",
    );
    expect(l.appSDropped("<host>", "<secs>"), "<host> <secs>s dropped");
    expect(l.appS("<host>", "<secs>"), "<host> <secs>s");
    expect(l.appTorWouldNotWake, "tor would not wake");
    expect(l.appCheckStarted, "started");
    expect(l.appTorNotReadyIn, "tor not ready in 75s");
    expect(l.appOk, "ok");
    expect(l.appOkNoRelayBegan, "ok, no relay began");
    expect(l.appOkCapped, "ok, capped");
    expect(l.appSBy("<how>", 0, "push"), "<how>, 0s, by push");
    expect(l.appSBy("<how>", 0, "other"), "<how>, 0s, by job");
    expect(l.appSBy("<how>", 1, "push"), "<how>, 1s, by push");
    expect(l.appSBy("<how>", 1, "other"), "<how>, 1s, by job");
    expect(l.appSBy("<how>", 2, "push"), "<how>, 2s, by push");
    expect(l.appSBy("<how>", 2, "other"), "<how>, 2s, by job");
    expect(l.appSBy("<how>", 5, "push"), "<how>, 5s, by push");
    expect(l.appSBy("<how>", 5, "other"), "<how>, 5s, by job");
    expect(
      l.appAnAttachmentCouldNot,
      "An attachment could not be saved on this phone",
    );
    expect(l.appGroup2, "group");
    expect(l.appVoiceMessage, "Voice message");
    expect(l.appPhoto, "photo");
    expect(l.appNewRequest, "New request");
    expect(l.appSomeoneYouHaveNot, "Someone you have not added wrote to you");
    expect(l.appSettingUpYourKeys, "Setting up your keys");
    expect(l.appOpeningYourChats, "Opening your chats");
    expect(l.appStartingTor, "starting Tor");
    expect(
      l.appTimedMessagesAreNot,
      "Timed messages are not clearing. Restart kryfo",
    );
    expect(l.appVoiceMessage2, "voice message");
    expect(l.appYou("<body>"), "you: <body>");
    expect(l.appThisRoomHasAlready, "This room has already expired");
    expect(l.appYouAreAlreadyIn, "You are already in this room");
    expect(l.appCouldNotMakeA, "could not make a room key");
    expect(
      l.appJoinedButYourHello("<linkName>"),
      "Joined <linkName>, but your hello was held back",
    );
    expect(l.appJoined("<linkName>"), "Joined <linkName>");
    expect(
      l.appJoinedButTheCreator("<linkName>"),
      "Joined <linkName>, but the creator could not be reached yet",
    );
    expect(l.appBooting, "booting...");
    expect(l.appSettingUpYourIdentity, "Setting up your identity...");
    expect(l.appAddSomeone, "Add someone");
    expect(
      l.appScanTheirCodeOr,
      "Scan their code, or paste what they gave you: a link, an @handle, or a room link.",
    );
    expect(l.appScanTheirCode, "Scan their code");
    expect(l.appAKryfoLinkA, "A kryfo link, a room link or @wren");
    expect(l.appAddThem, "Add them");
    expect(l.appEveryWayToAdd, "Every way to add someone");
    expect(
      l.appShowYourCodeSend,
      "Show your code, send a link, claim a handle",
    );
    expect(l.appHelloFromTheOther, "Hello from the other side");
    expect(l.appIdentityRestored, "Identity restored");
    expect(l.appIdentityCreated, "Identity created");
    expect(l.appStartingTor30s, "Starting tor (~30s)...");
    expect(l.appScanOrImportA, "scan or import a peer first");
    expect(l.appEncryptingSending30s, "Encrypting + sending (~30s)...");
    expect(l.appTapStartListeningFirst, "Tap start listening first");
    expect(l.appYourKryfo, "Your kryfo");
    expect(l.appUriCopied, "Uri copied");
    expect(l.appCopyUri, "Copy uri");
    expect(l.appAddAKryfo, "Add a kryfo");
    expect(l.appScanQr, "Scan qr");
    expect(l.appPairingCode, "Pairing code");
    expect(l.appOrPaste, "- or paste -");
    expect(l.commonCancel, "Cancel");
    expect(l.appImport, "Import");
    expect(l.appDev, "Dev");
    expect(l.appYourKryfo2, "Your kryfo:");
    expect(l.appRestoredFromDisk, "Restored from disk");
    expect(l.appStartListening, "Start listening");
    expect(l.appListening, "listening");
    expect(l.appShowMyQr, "Show my qr");
    expect(l.appImportPeer, "Import peer");
    expect(l.appPeer, "peer:");
    expect(l.appMessageWillBeEncrypted, "Message (will be encrypted)");
    expect(l.appEncryptSend, "Encrypt + send");
    expect(l.appStatus("<status>"), "status: <status>");
    expect(l.appSpeedPrivacy, "Speed & privacy →");
    expect(l.appGettingMessages, "Getting messages →");
    expect(l.appDisableAppLock, "Disable app lock?");
    expect(
      l.appThePinWillBe,
      "The pin will be removed. Anyone with your phone will see kryfo when they open it.",
    );
    expect(l.appDisable, "Disable");
    expect(l.appAppLockOn, "App lock · on →");
    expect(l.appAppLockOff, "App lock · off →");
    expect(l.appTorIsOff, "Tor is off");
    expect(l.appConnectedRoutedThrough3, "Connected · routed through 3 relays");
    expect(
      l.appReadyToSendPublishing,
      "Ready to send · publishing your address",
    );
    expect(l.appReadyToSendFinishing, "Ready to send · finishing setup");
    expect(l.appConnecting("<pct>"), "Connecting · <pct>");
    expect(l.appTor, "Tor");
    expect(l.appTorIsOffTurn, "Tor is off. Turn it on to connect privately.");
    expect(
      l.appTheFirstConnectionTakes,
      "The first connection takes a minute or two while tor builds a private route. After that it is cached, so opening kryfo later is much faster.",
    );
    expect(
      l.appRelayAndFastModes,
      "Relay and fast modes skip tor and are quicker. They are in settings, under speed & privacy, and each says what it costs.",
    );
    expect(l.appViaRelay, "Via relay");
    expect(l.appOffline, "offline");
    expect(l.appFast, "Fast");
    expect(l.appTorOff, "Tor off");
    expect(l.appTorReady, "Tor ready");
    expect(l.appConnecting2, "connecting");
    expect(
      l.mediaProgressSendingKeepTheApp("<v>"),
      "Sending · <v> · keep the app open",
    );
    expect(
      l.mediaProgressPausedOfWaitingFor("<count>", "<count2>"),
      "Paused · <count> of <count2> · waiting for the rest",
    );
    expect(l.mediaProgressReceivingMedia("<v>"), "Receiving media · <v>");
    expect(l.mediaProgressCancelSending, "Cancel sending");
    expect(l.metaReaderEndsBeforeItShould, "ends before it should");
    expect(l.metaReaderCouldNotBeRead, "could not be read");
    expect(l.metaReaderExifThatCannotBe, "exif that cannot be read");
    expect(l.metaReaderSamsungTrailer, "samsung trailer");
    expect(l.metaReaderChunk("<type>"), "chunk <type>");
    expect(l.metaReaderExifFlagSet, "exif flag set");
    expect(l.metaReaderXmpFlagSet, "xmp flag set");
    expect(l.metaReaderAppBlock("<id>"), "app block <id>");
    expect(l.metaReaderUuidBox, "uuid box");
    expect(l.metaReaderBox("<printable>"), "<printable> box");
    expect(l.metaReaderAttachedData, "attached data");
    expect(l.metaReaderItem("<printable>"), "<printable> item");
    expect(
      l.miuiAutostartAlreadyAllowedToRun,
      "Already allowed to run in the background",
    );
    expect(l.miuiAutostartLetKryfoRunIn, "Let kryfo run in the background");
    expect(
      l.miuiAutostartYourPhonePausesApps,
      "Your phone pauses apps to save battery. Without an exception, kryfo cannot receive messages while it is closed.",
    );
    expect(l.commonAllow, "Allow");
    expect(l.commonSkip, "Skip");
    expect(
      l.miuiAutostartXiaomiTurnsOffBackground,
      "Xiaomi turns off background apps by default. Without autostart, kryfo cannot deliver messages when the app is closed. On the next screen, find kryfo in the list and turn the toggle on.",
    );
    expect(l.miuiAutostartOpenSettings, "Open settings");
    expect(
      l.miuiAutostartCouldnTOpenIt,
      "couldn't open it. look for autostart in phone settings",
    );
    expect(
      l.notificationsNewEncryptedMessagesFrom,
      "New encrypted messages from your contacts",
    );
    expect(l.notificationsNewMessage, "new message");
    expect(
      l.notificationsNewEncryptedMessagesFromYourContacts,
      "new encrypted messages from your contacts",
    );
    expect(l.notificationsNewMessage2, "New message");
    expect(l.notificationsEncrypted, "encrypted");
    expect(l.rooms24h, "24h");
    expect(l.roomsD("<inDays>"), "<inDays>d");
    expect(l.roomsH("<inHours>"), "<inHours>h");
    expect(l.rooms24Hours, "24 hours");
    expect(l.roomsDays(0), "0 days");
    expect(l.roomsDays(1), "1 day");
    expect(l.roomsDays(2), "2 days");
    expect(l.roomsDays(5), "5 days");
    expect(l.roomsAnHour, "an hour");
    expect(l.roomsAboutAnHour, "about an hour");
    expect(l.roomsHours(0), "0 hours");
    expect(l.roomsHours(1), "1 hour");
    expect(l.roomsHours(2), "2 hours");
    expect(l.roomsHours(5), "5 hours");
    expect(l.roomsAboutHours(0), "about 0 hours");
    expect(l.roomsAboutHours(1), "about 1 hour");
    expect(l.roomsAboutHours(2), "about 2 hours");
    expect(l.roomsAboutHours(5), "about 5 hours");
    expect(l.roomsMinutes(0), "0 minutes");
    expect(l.roomsMinutes(1), "1 minute");
    expect(l.roomsMinutes(2), "2 minutes");
    expect(l.roomsMinutes(5), "5 minutes");
    expect(l.roomsAMinute, "a minute");
    expect(l.roomsExpired, "expired");
    expect(l.roomsDH("<inDays>", "<h>"), "<inDays>d <h>h");
    expect(l.roomsHM("<inHours>", "<m>"), "<inHours>h <m>m");
    expect(l.roomsM("<inMinutes>"), "<inMinutes>m");
    expect(l.scamShieldLooksLikeAScam, "Looks like a scam");
    expect(l.scamShieldThisNameMatches("<shown>"), "This name matches <shown>");
    expect(
      l.scamShieldNameMatchesYourContact("<shown>"),
      "Name matches your contact <shown>",
    );
    expect(
      l.scamShieldSameFaceAsYour("<shown>"),
      "same face as your contact <shown>",
    );
    expect(l.scamShieldContainsACryptoAddress, "Contains a crypto address");
    expect(
      l.scamShieldMentionsMoneyAndUrgency,
      "Mentions money and urgency together",
    );
    expect(l.scamShieldAsksYouToMove, "Asks you to move to another app");
    expect(
      l.scamShieldLinksToALookalike,
      "Links to a lookalike of a well-known site",
    );
    expect(
      l.scamShieldALongOpenerFrom,
      "A long opener from someone with no history",
    );
    expect(
      l.scamShieldAsksForACode,
      "Asks for a code, seed phrase or recovery file",
    );
    expect(
      l.scamShieldAlso("<shown>"),
      "Also: name matches your contact <shown>",
    );
    expect(l.commonBack, "Back");
    expect(l.archivedArchived, "Archived");
    expect(l.archivedCount0, "no");
    expect(l.archivedCount1, "one");
    expect(l.archivedCount2, "two");
    expect(l.archivedCount3, "three");
    expect(l.archivedCount4, "four");
    expect(l.archivedCount5, "five");
    expect(l.archivedCount6, "six");
    expect(l.archivedCount7, "seven");
    expect(l.archivedCount8, "eight");
    expect(l.archivedCount9, "nine");
    expect(l.archivedCount10, "ten");
    expect(
      l.archivedChatRestingHereIt,
      "Chat resting here. It stays quiet until they write, then comes back to the top.",
    );
    expect(
      l.archivedChatsRestingHere,
      "Chats resting here. They stay quiet until someone writes, then come back to the top.",
    );
    expect(l.archivedNothingArchived, "Nothing archived");
    expect(
      l.archivedArchivedChatsAreStill,
      "Archived chats are still end-to-end encrypted",
    );
    expect(l.archivedUnarchive, "Unarchive");
    expect(
      l.avatarPickerThePeopleYouMessage,
      "The people you message see this too",
    );
    expect(l.avatarPickerBackToYourInitial, "back to your initial");
    expect(l.avatarPickerThatOneIsYours, "that one is yours");
    expect(l.avatarPickerPickAFace, "Pick a face");
    expect(l.commonSave, "Save");
    expect(
      l.backupPassphraseMustBeAt,
      "passphrase must be at least 6 characters",
    );
    expect(l.backupPassphrasesDonTMatch, "passphrases don't match");
    expect(
      l.backupBackupSavedKeepThe,
      "Backup saved · keep the passphrase safe",
    );
    expect(l.backupKryfoBackup, "Kryfo backup");
    expect(
      l.backupYourEncryptedKryfoBackup,
      "Your encrypted kryfo backup. Keep both this file AND your passphrase safe - you need both to restore.",
    );
    expect(l.backupBackUpKryfo, "Back up kryfo");
    expect(l.backupBackUp, "Back up");
    expect(
      l.backupACopyToKeep,
      "A copy to keep. This phone carries on as it is.",
    );
    expect(l.backupMoveToAnotherDevice, "Move to another device");
    expect(
      l.backupTheFileTakesThis,
      "The file takes this identity with it. Once it is made, this phone stops: nothing new arrives here, and nothing sent from here reaches anyone.",
    );
    expect(
      l.backupOneEncryptedFileYour,
      "One encrypted file: your identity, your contacts, every message, and every photo, voice note and file. Import it on the other device with the passphrase. Until you do, this phone can still be kept.",
    );
    expect(
      l.backupOneEncryptedFileYourIdentityYour,
      "One encrypted file: your identity, your contacts, every message, and every photo, voice note and file on this phone right now. Anything said after today is not in it, so make another when it matters. To restore you need the file and the passphrase, both.",
    );
    expect(l.backupPassphrase, "Passphrase");
    expect(l.backupConfirmPassphrase, "Confirm passphrase");
    expect(l.backupWriting("<progress>"), "writing… <progress>");
    expect(l.backupCreating, "creating…");
    expect(l.backupMakeTheFileAnd, "Make the file and move");
    expect(l.backupCreateBackup, "Create backup");
    expect(l.blockedBlocked, "Blocked");
    expect(l.blockedNoOneIsBlocked, "No one is blocked");
    expect(l.commonUnblock, "Unblock");
    expect(l.bridgesThatWasNotIt, "That was not it. Here is another.");
    expect(l.bridgesGotBridgesSaveTo, "Got bridges · save to use them");
    expect(l.bridgesConnected, "Connected");
    expect(l.bridgesNotThroughYetTor, "Not through yet. Tor keeps trying");
    expect(l.bridgesBridges, "Bridges");
    expect(l.bridgesTorIsBlockedWhere, "Tor is blocked where you are?");
    expect(
      l.bridgesBridgesDisguiseYourConnection,
      "Bridges disguise your connection so it can get out. Pick one way in, save, and tor reconnects through it.",
    );
    expect(
      l.bridgesBridgesOnlyChangeHow,
      "Bridges only change how tor connects, and you are not on onion mode right now. What you set here is saved, it just does nothing until you switch back.",
    );
    expect(l.bridgesFromTheTorProject, "From the tor project");
    expect(l.bridgesNoise, "noise");
    expect(l.bridgesGood, "good");
    expect(
      l.bridgesMakesTorTrafficLook,
      "Makes tor traffic look like nothing in particular. The best default for most blocked networks. Answers a captcha, then hands you a few lines.",
    );
    expect(l.bridgesPrivateBridge, "Private bridge");
    expect(l.bridgesALineFromA, "A line from a friend");
    expect(l.bridgesWhateverTheLineSays, "Whatever the line says");
    expect(l.bridgesDepends, "depends");
    expect(
      l.bridgesGotABridgeLine,
      "Got a bridge line from someone you trust, or from bridges.torproject.org? Paste it here. Obfs4 lines only, kryfo does not speak the others yet.",
    );
    expect(l.bridgesPasteFromClipboard, "Paste from clipboard");
    expect(l.bridgesUseBridges, "Use bridges");
    expect(l.bridgesNoLinesYet, "No lines yet");
    expect(l.bridges1LineSaved(0), "0 lines saved");
    expect(l.bridges1LineSaved(1), "1 line saved");
    expect(l.bridges1LineSaved(2), "2 lines saved");
    expect(l.bridges1LineSaved(5), "5 lines saved");
    expect(l.bridgesRestartingTor, "Restarting tor…");
    expect(
      l.bridgesFindingABridgeS("<elapsed>"),
      "Finding a bridge… <elapsed>s",
    );
    expect(l.bridgesStillTryingS("<elapsed>"), "Still trying… <elapsed>s");
    expect(l.bridgesApplying, "Applying…");
    expect(l.bridgesSaveAndReconnect, "Save and reconnect");
    expect(l.bridgesWhatABridgeIs, "What a bridge is");
    expect(
      l.bridgesATorEntryPoint,
      "A tor entry point nobody has published, reached through a wrapper so the connection does not look like tor. The rest of the route is the usual three hops.",
    );
    expect(l.bridgesLooksLike, "Looks like");
    expect(l.bridgesSpeed, "speed");
    expect(l.bridgesGetBridges, "Get bridges");
    expect(
      l.bridgesAskTheTorProject,
      "Ask the tor project directly. You solve a puzzle so bots cannot drain the supply.",
    );
    expect(l.bridgesTypeWhatYouSee, "type what you see. lowercase is fine.");
    expect(
      l.bridgesThisOneRequestDoes,
      "This one request does not go through tor - it cannot, since tor is what is not working. Whoever runs your network will see you contacting the tor project. If that alone is a problem where you are, get bridges somewhere else and paste them below.",
    );
    expect(l.bridgesCouldNotDrawThe, "Could not draw the puzzle");
    expect(l.bridgesAnswer, "Answer");
    expect(l.bridgesAsking, "Asking…");
    expect(l.bridgesRequestBridges, "Request bridges");
    expect(l.bridgesDifferentPuzzle, "Different puzzle");
    expect(l.cameraNoCameraOnThis, "No camera on this phone");
    expect(l.cameraCameraNotAvailable, "Camera not available");
    expect(
      l.cameraCameraPermissionIsOff,
      "Camera permission is off · tap to try again",
    );
    expect(l.cameraCouldNotStripThat, "Could not strip that photo, dropped it");
    expect(l.cameraNoPhotoCameOut, "No photo came out");
    expect(l.cameraCouldNotStartRecording, "Could not start recording");
    expect(l.cameraTheRecordingWasLost, "The recording was lost");
    expect(l.cameraACopyIsIn, "A copy is in your photos");
    expect(l.cameraCouldNotSaveA, "Could not save a copy on this phone");
    expect(l.cameraTooLongForA, "Too long for a message · 8 mb max");
    expect(l.cameraNeverSavedToYour, "Never saved to your photos");
    expect(l.cameraNoExifNeverSaved, "No exif, never saved to your photos");
    expect(l.cameraRec, "Rec");
    expect(l.cameraSwitchCamera, "switch camera");
    expect(l.cameraClipSMb("<secs>", "<mb>"), "Clip · <secs>s · <mb> mb");
    expect(l.cameraStopRecording, "Stop recording");
    expect(l.cameraStartRecording, "Start recording");
    expect(l.cameraTakeAPhoto, "Take a photo");
    expect(l.cameraKeepACopy, "keep a copy");
    expect(l.cameraUseThis, "Use this");
    expect(l.chatB("<bytes>"), "<bytes> b");
    expect(l.chatKb("<bytes>"), "<bytes> kb");
    expect(l.chatMb("<bytes>"), "<bytes> mb");
    expect(l.chatFile, "FILE");
    expect(
      l.chatYouAreOfflineThis,
      "you are offline · this sends itself when you reconnect",
    );
    expect(
      l.chatStillConnectingToTor,
      "still connecting to tor · it'll go out on its own",
    );
    expect(l.chatS("<seconds>"), "<seconds>s");
    expect(l.chatM("<seconds>"), "<seconds>m");
    expect(l.chatH("<seconds>"), "<seconds>h");
    expect(l.chatD("<seconds>"), "<seconds>d");
    expect(l.chat0s, "0s");
    expect(l.chatHM("<h>", "<m>"), "<h>h <m>m");
    expect(l.chatMS("<m>", "<s>"), "<m>m <s>s");
    expect(l.chatS2("<s>"), "<s>s");
    expect(l.chatNewMessages, "New messages");
    expect(l.chatUnsave, "Unsave");
    expect(l.chatForward, "Forward");
    expect(l.commonShare, "Share");
    expect(l.commonCopied, "Copied");
    expect(l.commonCopy, "Copy");
    expect(l.chatUnpin, "Unpin");
    expect(l.chatPin, "Pin");
    expect(l.chatStopSending, "Stop sending");
    expect(l.chatUnsend, "Unsend");
    expect(l.commonEdit, "Edit");
    expect(l.chatYou, "You");
    expect(l.chatUnsendMessage, "Unsend message");
    expect(
      l.chatItDisappearsWithNo,
      "It disappears with no trace. This can't be undone.",
    );
    expect(l.chatThisChatHasPins(0), "This chat has 0 pins already");
    expect(l.chatThisChatHasPins(1), "This chat has 1 pin already");
    expect(l.chatThisChatHasPins(2), "This chat has 2 pins already");
    expect(l.chatThisChatHasPins(5), "This chat has 5 pins already");
    expect(l.chatUnpinThisMessage, "Unpin this message?");
    expect(l.chatPinThisMessage, "Pin this message?");
    expect(
      l.chatItLeavesThePinned,
      "It leaves the pinned list for both of you.",
    );
    expect(
      l.chatItGoesUnderThe,
      "It goes under the pin at the top of the chat, for both of you.",
    );
    expect(l.chatPinIt, "Pin it");
    expect(l.chatNotNow, "Not now");
    expect(l.chatEditMessage, "Edit message");
    expect(l.chat30Seconds, "30 seconds");
    expect(l.chat1Minute, "1 minute");
    expect(l.chat5Minutes, "5 minutes");
    expect(l.chat1Hour, "1 hour");
    expect(l.chat24Hours, "24 hours");
    expect(l.chatGhostTimer, "Ghost timer");
    expect(l.chatHowLongBeforeSent, "How long before sent messages burn?");
    expect(l.chatCamera, "Camera");
    expect(l.chatNoExifNeverSaved, "No exif, never saved to your photos");
    expect(l.chatGallery, "Gallery");
    expect(l.chatVideo, "Video");
    expect(l.chatGifFromPhone, "Gif from phone");
    expect(l.chatFile2, "File");
    expect(l.chatAFewSeconds, "A few seconds");
    expect(l.chatUnderAMinute, "Under a minute");
    expect(l.chatRoughlyMin(0), "Roughly 0 min");
    expect(l.chatRoughlyMin(1), "Roughly 1 min");
    expect(l.chatRoughlyMin(2), "Roughly 2 min");
    expect(l.chatRoughlyMin(5), "Roughly 5 min");
    expect(l.chatB2("<b>"), "<b> b");
    expect(l.chatKb2("<b>"), "<b> kb");
    expect(l.chatMb2("<b>"), "<b> mb");
    expect(l.chatSendThis, "Send this file?");
    expect(
      l.chatOverTor("<humanBytes>", "<wireEstimate>"),
      "<humanBytes> · <wireEstimate> over tor",
    );
    expect(
      l.chatBigFilesGoOut,
      "Big files go out in small encrypted pieces, so they take a while. Keep the app open and it keeps going.",
    );
    expect(l.chatSendIt, "Send it");
    expect(l.chatCouldNotReadThat, "Could not read that file");
    expect(l.chatFileTooBig8, "File too big · 8 mb max");
    expect(l.chatCouldNotCleanThat, "Could not clean that video");
    expect(
      l.chatCouldNotCleanThatPictureSend,
      "Could not clean that picture · send it as a photo",
    );
    expect(l.chatGifTooBig8, "Gif too big · 8 mb max");
    expect(l.chatCouldNotCleanThatGif, "Could not clean that gif");
    expect(l.chatTorIsNotUp, "Tor is not up yet · sending without");
    expect(l.chatCouldnTReachIt, "Couldn't reach it · sending without");
    expect(l.chatNoTitleCameBack, "No title came back · sending without");
    expect(l.chatCouldnTFetchIt, "Couldn't fetch it · sending without");
    expect(l.chatNoSignalSessionRe, "No signal session - re-pair");
    expect(l.chatMessageUnavailable, "Message unavailable");
    expect(l.chatYou2, "you");
    expect(l.chatThem, "them");
    expect(l.chatVoiceMessage, "voice message");
    expect(l.chatQuotedPhoto, "photo");
    expect(l.chatViewContact, "View contact");
    expect(l.chatSharedPhotos, "Shared photos");
    expect(l.chatSharedPhotoCount(0, "<title>"), "0 photos · <title>");
    expect(l.chatSharedPhotoCount(1, "<title>"), "1 photo · <title>");
    expect(l.chatSharedPhotoCount(2, "<title>"), "2 photos · <title>");
    expect(l.chatSharedPhotoCount(5, "<title>"), "5 photos · <title>");
    expect(l.chatUnmuteNotifications, "Unmute notifications");
    expect(l.chatMuteNotifications, "Mute notifications");
    expect(l.chatArchiveChat, "Archive chat");
    expect(l.chatWallpaper, "Wallpaper");
    expect(l.chatClearConversation, "Clear conversation");
    expect(l.chatNoteOnThisContact, "Note on this contact");
    expect(l.chatPinToTop, "Pin to top");
    expect(l.chatBlockContact, "Block contact");
    expect(l.chatUnpinned, "Unpinned");
    expect(l.chatPinnedToTop, "Pinned to top");
    expect(
      l.chatJustForYouNever,
      "Just for you. Never sent, never leaves this phone.",
    );
    expect(l.chatAQuietReminder, "A quiet reminder…");
    expect(l.chatNoteSaved, "Note saved");
    expect(l.chatClearThisConversation, "Clear this conversation?");
    expect(
      l.chatEveryMessageHereIs,
      "Every message here is erased from this phone. This only clears your copy - it does not touch their device.",
    );
    expect(l.chatClear, "Clear");
    expect(l.chatBlockThisContact, "Block this contact?");
    expect(
      l.chatTheirMessagesStopArriving,
      "Their messages stop arriving and they disappear from your chats. They're never told. You can unblock anytime from settings.",
    );
    expect(l.commonBlock, "Block");
    expect(l.chatSaved, "Saved");
    expect(l.chatRemovedFromSaved, "Removed from saved");
    expect(l.chatForwardTo, "Forward to");
    expect(l.chatNoContactsToForward, "No contacts to forward to");
    expect(l.chatToday, "today");
    expect(l.chatYesterday, "yesterday");
    expect(l.chatThisMessageCanT, "This message can't be shown");
    expect(l.chatJumpToTheNewest, "Jump to the newest");
    expect(
      l.chatBuildingAPrivateRoute,
      "Building a private route · first connect is the slow one, later ones are quick. Anything you send now is queued and delivers itself.",
    );
    expect(
      l.chatLooksSafeNothingSuspicious,
      "Looks safe · nothing suspicious in their first message",
    );
    expect(
      l.chatTheNextPhotoYou,
      "The next photo you send opens protected · they cannot screenshot it",
    );
    expect(l.chatPhotoProtectionOff, "Photo protection off");
    expect(
      l.chatAcceptToReplyThey,
      "Accept to reply - they get one more message in until you do.",
    );
    expect(
      l.chatIntroducedYouAcceptTo("<introducer>"),
      "<introducer> introduced you. Accept to reply.",
    );
    expect(
      l.chatIntroducedYouSayHello("<vouchNames>"),
      "<vouchNames> introduced you. Say hello - they got your card too.",
    );
    expect(l.chatIntroduceTo, "Introduce to...");
    expect(l.chatAcceptThemFirst, "Accept them first");
    expect(l.chatMessageRequest, "Message request");
    expect(
      l.chatTheyNeedToAccept,
      "They need to accept before you can keep chatting.",
    );
    expect(l.chatWaitingForThemTo, "Waiting for them to accept your request");
    expect(l.chatYouBlockedThisContact, "You blocked this contact");
    expect(l.chatSupporter, "Supporter");
    expect(l.chatEncryptedViaRelay, "Encrypted · via relay");
    expect(l.chatEncryptedDirect, "Encrypted · direct");
    expect(l.chatEncryptedOverTor, "Encrypted · over tor");
    expect(l.chatSearchThisChat, "Search this chat");
    expect(l.chatContactOptions, "Contact options");
    expect(l.commonClose, "Close");
    expect(l.chatFindInConversation, "Find in conversation");
    expect(l.chatNoMatches, "No matches");
    expect(l.chatOf(0, 0), "*0* of 0 matches");
    expect(l.chatOf(0, 1), "*1* of 0 matches");
    expect(l.chatOf(0, 2), "*2* of 0 matches");
    expect(l.chatOf(0, 5), "*5* of 0 matches");
    expect(l.chatOf(1, 0), "*0* of 1 match");
    expect(l.chatOf(1, 1), "*1* of 1 match");
    expect(l.chatOf(1, 2), "*2* of 1 match");
    expect(l.chatOf(1, 5), "*5* of 1 match");
    expect(l.chatOf(2, 0), "*0* of 2 matches");
    expect(l.chatOf(2, 1), "*1* of 2 matches");
    expect(l.chatOf(2, 2), "*2* of 2 matches");
    expect(l.chatOf(2, 5), "*5* of 2 matches");
    expect(l.chatOf(5, 0), "*0* of 5 matches");
    expect(l.chatOf(5, 1), "*1* of 5 matches");
    expect(l.chatOf(5, 2), "*2* of 5 matches");
    expect(l.chatOf(5, 5), "*5* of 5 matches");
    expect(l.chatPreviousMatch, "Previous match");
    expect(l.chatNextMatch, "Next match");
    expect(l.chatPhotoUnavailable, "Photo unavailable");
    expect(l.chatDelivered, "Delivered");
    expect(l.chatEdited, "Edited");
    expect(
      l.chatWaitingForThemToComeOnline,
      "Waiting for them to come online or add you back",
    );
    expect(l.chatFailedTapToRetry, "Failed · tap to retry");
    expect(l.chatReplyingTo, "Replying to them");
    expect(l.chatReplyingToYourself, "Replying to yourself");
    expect(l.chatReply, "Reply");
    expect(l.chatSayHi, "Say hi.");
    expect(l.chatJustTheTwoOf, "Just the two of you, end-to-end encrypted.");
    expect(l.chatMicPermissionNeeded, "Mic permission needed");
    expect(l.chatTheMicWouldNot, "The mic would not start. Try again");
    expect(l.chatReleaseToCancel, "Release to cancel");
    expect(l.chatVoiceHiddenSlideTo, "Voice hidden · slide to cancel");
    expect(l.chatSlideToCancel, "Slide to cancel");
    expect(l.chatGhostMode, "Ghost mode");
    expect(
      l.chatMessagesBurnAfter("<humanBurn>"),
      "Messages burn after <humanBurn>",
    );
    expect(l.chatTimedMessages, "Timed messages");
    expect(l.chatOpenTheCamera, "Open the camera");
    expect(l.chatAttachAPhoto, "Attach a photo");
    expect(l.chatMessage, "Message");
    expect(l.chatDisguiseVoice, "Disguise voice");
    expect(l.commonSend, "Send");
    expect(l.chatNoPhotosInThis, "No photos in this chat yet");
    expect(l.chatSendPhoto, "Send photo");
    expect(l.chatAddACaption, "Add a caption…");
    expect(l.chatSecurityCodeChanged, "Security code changed");
    expect(
      l.chatMayHaveReinstalledOr("<peerName>"),
      "<peerName> may have reinstalled, or someone could be impersonating them. Compare safety numbers to be sure.",
    );
    expect(l.chatOk, "Ok");
    expect(l.chatVerify, "Verify");
    expect(l.cleanKryfoCanTClean, "Kryfo can’t clean this kind of file yet.");
    expect(l.cleanThisIsAMotion, "This is a motion photo.");
    expect(l.cleanThisPictureIsToo, "This picture is too large to clean here.");
    expect(l.cleanThisFileIsDamaged, "This file is damaged or cut short.");
    expect(l.cleanKryfoCouldNotMake, "Kryfo could not make this one clean.");
    expect(l.cleanNotEnoughRoomOn, "Not enough room on the phone.");
    expect(l.cleanKryfoCouldNotOpen, "Kryfo could not open that file.");
    expect(
      l.cleanItCleansJpegPng,
      "It cleans JPEG, PNG, WebP, HEIC, AVIF, GIF, MP4 and MOV. Nothing was changed.",
    );
    expect(
      l.cleanItHoldsAShort,
      "It holds a short video beside the picture, and Kryfo can’t clean that part yet. Turn motion off in your camera, or send a screenshot of it.",
    );
    expect(
      l.cleanPicturesOver64Mb,
      "Pictures over 64 MB are not cleaned on the phone. Nothing was changed.",
    );
    expect(
      l.cleanKryfoCouldNotRead,
      "Kryfo could not read it to the end, so it won’t call it clean. No copy was made.",
    );
    expect(
      l.cleanSomethingInsideIsOf,
      "Something inside is of a kind it does not know how to remove, so no copy was made.",
    );
    expect(
      l.cleanFreeSomeSpaceAnd,
      "Free some space and try again. Nothing was changed.",
    );
    expect(
      l.cleanTheAppThatShared,
      "The app that shared it may have taken it back. Try sharing it again.",
    );
    expect(l.cleanNoAppOnThis, "No app on this phone took the file.");
    expect(
      l.cleanCouldNotSaveIt,
      "Could not save it. Check the phone has room.",
    );
    expect(
      l.cleanTheOriginalIsGone,
      "The original is gone. The clean copy stays.",
    );
    expect(
      l.cleanAndroidWouldNotDelete,
      "Android would not delete it. Remove it from the gallery by hand.",
    );
    expect(l.cleanCleanCopy, "Clean copy");
    expect(l.cleanShareCleanCopy, "Share clean copy");
    expect(l.cleanSaveToGallery, "Save to gallery");
    expect(l.commonStop, "Stop");
    expect(l.cleanReadingTheFile, "Reading the file");
    expect(l.cleanCleaning, "Cleaning");
    expect(
      l.cleanOf("<prettySize>", "<prettySize2>"),
      "<prettySize> of <prettySize2>",
    );
    expect(l.cleanEverythingStaysOnThis, "Everything stays on this phone.");
    expect(l.cleanAlreadyClean, "Already clean.");
    expect(l.cleanClean, "Clean.");
    expect(l.cleanThereWasNothingTo, "There was nothing to find.");
    expect(l.cleanNothingLeftToFind, "Nothing left to find.");
    expect(l.cleanSameVideoSameQuality, "Same video, same quality");
    expect(l.cleanSamePictureSameQuality, "Same picture, same quality");
    expect(l.cleanRemoved("<label>"), "<label>, removed");
    expect(l.cleanRemoved2, "REMOVED");
    expect(
      l.cleanWithTheLocationInside,
      "with the location inside. Anyone who gets that one gets your street.",
    );
    expect(
      l.cleanWithEverythingItKnew,
      "with everything it knew still inside.",
    );
    expect(l.cleanOriginal, "ORIGINAL");
    expect(l.cleanClean2, "CLEAN");
    expect(l.cleanSavedToYourGallery, "Saved to your gallery.");
    expect(
      l.cleanTheOriginalIsStill("<what>"),
      "The original is still there too, <what>",
    );
    expect(
      l.cleanTheOriginalIsStillWhereIt("<what>"),
      "The original is still where it was, <what> Kryfo can’t remove it from here, so delete it in the app it came from.",
    );
    expect(l.cleanDeleteTheOriginal, "Delete the original");
    expect(l.cleanKeepBoth, "Keep both");
    expect(l.commonDone, "Done");
    expect(l.cleanAndroidWillAskYou, "ANDROID WILL ASK YOU TO CONFIRM");
    expect(l.contactYourNameForThem, "Your name for them");
    expect(
      l.contactStaysOnThisPhone,
      "Stays on this phone. They never see it.",
    );
    expect(l.contactClear, "Clear");
    expect(l.contactMessage, "Message");
    expect(l.contactKeysVerified, "Keys verified");
    expect(l.contactVerifyKeys, "Verify keys");
    expect(l.contactVouches, "Vouches");
    expect(l.contactUnmute, "Unmute");
    expect(l.contactMute, "Mute");
    expect(l.contactUnpin, "Unpin");
    expect(l.contactPinToTop, "Pin to top");
    expect(l.contactArchive, "Archive");
    expect(l.contactOutOfTheList, "Out of the list until they write again");
    expect(l.contactBlock("<name>"), "Block <name>?");
    expect(
      l.contactTheirMessagesStopArriving,
      "Their messages stop arriving. They are not told.",
    );
    expect(l.contactDeleteChat, "Delete chat");
    expect(
      l.contactMessagesAndContactGone,
      "Messages and contact, gone from this phone",
    );
    expect(l.contactDeleteThisChat, "Delete this chat?");
    expect(
      l.contactEveryMessageAndThe,
      "Every message and the contact, gone from this phone. Nothing is sent to them.",
    );
    expect(l.commonDelete, "Delete");
    expect(l.contactDeleted, "Deleted");
    expect(l.contactToday, "today");
    expect(l.contactD("<inDays>"), "<inDays>d");
    expect(l.contactMo("<d>"), "<d>mo");
    expect(l.contactY("<d>"), "<d>y");
    expect(l.contactVerified, "Verified");
    expect(l.contactChatting, "Chatting");
    expect(l.contactNothingSharedYet, "nothing shared yet");
    expect(l.contactSharedMedia("<count>"), "shared media · <count>");
    expect(l.donateBitcoin, "Bitcoin");
    expect(l.donateText, "₿");
    expect(l.donateBadgeUnlocks, "badge unlocks");
    expect(l.donateMonero, "Monero");
    expect(l.donateManualNoBadge, "manual · no badge");
    expect(l.donateSolana, "Solana");
    expect(l.donateEthereum, "Ethereum");
    expect(l.donateText2, "Ξ");
    expect(
      l.donateYourEarlierBitcoinPayment("supporter"),
      "Your earlier bitcoin payment was seen · supporter badge unlocked",
    );
    expect(
      l.donateYourEarlierBitcoinPayment("patron"),
      "Your earlier bitcoin payment was seen · patron badge unlocked",
    );
    expect(
      l.donateYourEarlierBitcoinPayment("guardian"),
      "Your earlier bitcoin payment was seen · guardian badge unlocked",
    );
    expect(
      l.donateYourEarlierBitcoinPayment("other"),
      "Your earlier bitcoin payment was seen · supporter badge unlocked",
    );
    expect(l.donateSupport, "Support");
    expect(l.donateKeepKryfo, "Keep kryfo *independent*");
    expect(
      l.donateNoAdsNoInvestors,
      "No ads, no investors, nothing to sell. It runs on what backers give.",
    );
    expect(
      l.donateBackItAnonymouslyBadge,
      "Back it anonymously. Badge opt-in.\n*Privacy is never behind a paywall.*",
    );
    expect(
      l.donateAddressCheckItAgainst("<coinName>"),
      "<coinName> address · check it against your wallet",
    );
    expect(l.donateAddressCopiedClearsIn, "Address copied · clears in 60s");
    expect(l.donateCopyAddress, "Copy address");
    expect(
      l.donateBitcoinIsVerifiedBy,
      "Bitcoin is verified by our own node, so your badge unlocks by itself once the payment lands.",
    );
    expect(
      l.donateWeCanTVerify,
      "we can't verify this chain without asking an outside service about you, so we don't. send it if you like. it won't unlock a badge.",
    );
    expect(l.donateBitcoinBadgesNeedOnion, "Bitcoin badges need onion mode");
    expect(l.donateSwitchToOnion, "Switch to onion");
    expect(l.donatePayWithBitcoin, "Pay with bitcoin  →");
    expect(l.donateBadgesStartAt20, "Badges start at \$20");
    expect(
      l.donateReachingThePaymentService,
      "Reaching the payment service over tor…",
    );
    expect(l.donateThisCanTakeUp, "This can take up to a minute");
    expect(
      l.donateSThisCanTake("<waited>"),
      "<waited>s · this can take up to a minute",
    );
    expect(l.donateUseTheAddressInstead, "Use the address instead");
    expect(
      l.donateThePaymentServiceIs,
      "The payment service is an onion, and only onion mode can reach it. Nothing was sent.",
    );
    expect(
      l.donateTorWasSlowTo,
      "Tor was slow to reach the payment service. You can donate to the address below - your badge just won't unlock automatically. Try again later for the badge.",
    );
    expect(
      l.donateThePaymentServiceIsHavingTrouble,
      "The payment service is having trouble right now. You can still donate to the address below - your badge just won't unlock automatically. Try again later for the badge.",
    );
    expect(l.commonTryAgain, "Try again");
    expect(l.donateBtc("<btc>"), "<btc> BTC");
    expect(
      l.donateSendExactlyThisAmount("<fmtLeft>"),
      "Send exactly this amount · expires in <fmtLeft>",
    );
    expect(l.donateOpenWallet, "open wallet");
    expect(
      l.donateThisScreenUpdatesItself,
      "This screen updates itself the moment your payment is seen.\nKeep it open - nothing is stored, nothing identifies you.",
    );
    expect(l.donateWatchingTheChainFor, "Watching the chain for your payment");
    expect(l.donateThisInvoiceExpired, "This invoice expired");
    expect(
      l.donateInvoicesTimeOutIf,
      "Invoices time out. If you already sent the payment, keep this open: we ask the service again every minute for a while, and the next time you open support. Start a fresh one whenever you like.",
    );
    expect(l.donateNewInvoice, "New invoice");
    expect(l.donateIPaidCheckAgain, "I paid, check again");
    expect(l.donatePaymentConfirmed, "Payment confirmed");
    expect(
      l.donateThankYouForKeeping,
      "Thank you for keeping kryfo independent.",
    );
    expect(
      l.donateVerifiedOnChainYou("supporter"),
      "verified on-chain - you're a supporter now. No one can take that off you.",
    );
    expect(
      l.donateVerifiedOnChainYou("patron"),
      "verified on-chain - you're a patron now. No one can take that off you.",
    );
    expect(
      l.donateVerifiedOnChainYou("guardian"),
      "verified on-chain - you're a guardian now. No one can take that off you.",
    );
    expect(
      l.donateVerifiedOnChainYou("other"),
      "verified on-chain - you're a supporter now. No one can take that off you.",
    );
    expect(l.donateWearMyBadge, "wear my badge");
    expect(l.donateJustGladToHelp, "Just glad to help");
    expect(l.gettingMessagesGettingMessages, "Getting messages");
    expect(
      l.gettingMessagesHowNewMessagesReach,
      "How new messages reach this phone. You can change it whenever you like.",
    );
    expect(l.gettingMessagesAlwaysOn, "Always on");
    expect(l.gettingMessagesMostPrivate, "most private");
    expect(
      l.gettingMessagesMessagesArriveInstantlyNothing,
      "Messages arrive instantly. Nothing leaves Tor. Uses the most battery.",
    );
    expect(l.gettingMessagesCheckIns, "Check-ins");
    expect(l.gettingMessagesLightest, "lightest");
    expect(
      l.gettingMessagesKryfoLooksForMessages,
      "Kryfo looks for messages every 15 minutes. Easy on battery, but messages can be late.",
    );
    expect(l.gettingMessagesOnTheLockScreen, "On the lock screen");
    expect(l.gettingMessagesHideMessagePreview, "Hide message preview");
    expect(
      l.gettingMessagesAGenericAlertWith,
      "A generic alert, with no sender and no message text",
    );
    expect(
      l.gettingMessagesShowsMessageTextIn,
      "Shows message text in notifications, even while Kryfo is locked.",
    );
    expect(
      l.gettingMessagesWhenThePhoneSits,
      "When the phone sits still, Android spaces check-ins further apart. The line above shows the real last one. While Kryfo is open it stays connected.",
    );
    expect(l.groupChatJumpToTheNewest, "Jump to the newest");
    expect(l.groupChatBlockedEverywhere, "Blocked everywhere");
    expect(l.groupChatYou, "you");
    expect(l.groupChatVoiceMessage, "voice message");
    expect(l.groupChatQuotedPhoto, "photo");
    expect(l.groupChatMessageUnavailable, "Message unavailable");
    expect(l.groupChatTorIsNotUp, "Tor is not up yet · sending without");
    expect(l.groupChatCouldnTReachIt, "couldn't reach it · sending without");
    expect(l.groupChatNoTitleCameBack, "No title came back · sending without");
    expect(l.groupChatCouldnTFetchIt, "couldn't fetch it · sending without");
    expect(l.groupChatCamera, "Camera");
    expect(l.groupChatGallery, "Gallery");
    expect(l.groupChatVideo, "Video");
    expect(l.groupChatGifFromPhone, "Gif from phone");
    expect(l.groupChatFile, "File");
    expect(l.groupChatCouldNotReadThat, "Could not read that file");
    expect(l.groupChatGifTooBig8, "Gif too big · 8 mb max");
    expect(l.groupChatCouldNotCleanThat, "Could not clean that gif");
    expect(l.groupChatFileTooBig8, "File too big · 8 mb max");
    expect(l.groupChatCouldNotCleanThatVideo, "Could not clean that video");
    expect(
      l.groupChatCouldNotCleanThatPictureSend,
      "Could not clean that picture · send it as a photo",
    );
    expect(l.groupChat30Seconds, "30 seconds");
    expect(l.groupChat1Minute, "1 minute");
    expect(l.groupChat5Minutes, "5 minutes");
    expect(l.groupChat1Hour, "1 hour");
    expect(l.groupChat24Hours, "24 hours");
    expect(l.groupChatBurnTimer, "Burn timer");
    expect(
      l.groupChatNewMessagesDisappearAfter,
      "New messages disappear after this",
    );
    expect(l.groupChatToday, "today");
    expect(l.groupChatYesterday, "yesterday");
    expect(l.groupChatYou2, "You");
    expect(l.groupChatThisChatHasPins(0), "This chat has 0 pins already");
    expect(l.groupChatThisChatHasPins(1), "This chat has 1 pin already");
    expect(l.groupChatThisChatHasPins(2), "This chat has 2 pins already");
    expect(l.groupChatThisChatHasPins(5), "This chat has 5 pins already");
    expect(l.groupChatUnpinThisMessage, "Unpin this message?");
    expect(l.groupChatPinThisMessage, "Pin this message?");
    expect(
      l.groupChatItLeavesThePinned,
      "It leaves the pinned list for everyone here.",
    );
    expect(
      l.groupChatItGoesUnderThe,
      "It goes under the pin at the top of the chat, for everyone here.",
    );
    expect(l.groupChatUnpin, "Unpin");
    expect(l.groupChatPinIt, "Pin it");
    expect(l.groupChatNotNow, "Not now");
    expect(l.groupChatSaved, "Saved");
    expect(l.groupChatRemovedFromSaved, "Removed from saved");
    expect(l.groupChatForwardTo, "Forward to");
    expect(l.groupChatNoContactsToForward, "No contacts to forward to");
    expect(l.groupChatEditMessage, "Edit message");
    expect(l.groupChatUnsendMessage, "Unsend message");
    expect(
      l.groupChatItDisappearsWithNo,
      "It disappears with no trace. This can't be undone.",
    );
    expect(l.groupChatUnsend, "Unsend");
    expect(
      l.groupChatThisRoomAndEverything("<expiryWords>"),
      "This room and everything in it disappears in <expiryWords>",
    );
    expect(
      l.groupChatGhostModeOnBurns("<fmtBurn>"),
      "Ghost mode on · burns in <fmtBurn>",
    );
    expect(l.groupChatGroupCreatedSayHi, "Group created. Say hi.");
    expect(l.groupChatNoMessagesYet, "No messages yet.");
    expect(l.groupChatThisMessageCanT, "This message can't be shown");
    expect(l.groupChatS("<s>"), "<s>s");
    expect(l.groupChatM("<s>"), "<s>m");
    expect(l.groupChatH("<s>"), "<s>h");
    expect(l.groupChatD("<s>"), "<s>d");
    expect(l.groupChatHere(0, "<time>"), "<time> · 0 here");
    expect(l.groupChatHere(1, "<time>"), "<time> · 1 here");
    expect(l.groupChatHere(2, "<time>"), "<time> · 2 here");
    expect(l.groupChatHere(5, "<time>"), "<time> · 5 here");
    expect(l.groupChatMembers(0), "0 members");
    expect(l.groupChatMembers(1), "1 member");
    expect(l.groupChatMembers(2), "2 members");
    expect(l.groupChatMembers(5), "5 members");
    expect(l.groupChatSearchThisChat, "Search this chat");
    expect(l.groupChatReplyingTo("<name>"), "Replying to <name>");
    expect(l.groupChatReplyingToYou, "Replying to you");
    expect(l.groupChatTimedMessages, "Timed messages");
    expect(l.groupChatOpenTheCamera, "Open the camera");
    expect(l.groupChatAttachAPhoto, "Attach a photo");
    expect(l.groupChatMessage, "Message");
    expect(l.groupChatDisguiseVoice, "Disguise voice");
    expect(l.groupChatSupporter, "Supporter");
    expect(l.groupChatEdited, "Edited");
    expect(l.groupChatTapToRetry, "! tap to retry");
    expect(l.groupChat0s, "0s");
    expect(l.groupChatReply, "Reply");
    expect(l.groupChatPin, "Pin");
    expect(l.groupChatUnsave, "Unsave");
    expect(l.groupChatForward, "Forward");
    expect(l.groupInfoGroup, "group");
    expect(l.groupInfoRenameGroup, "Rename group");
    expect(l.groupInfoRename, "Rename");
    expect(l.groupInfoNoContactsToAdd, "No contacts to add");
    expect(l.groupInfoCouldNotAdd, "Could not add");
    expect(l.groupInfoRemove("<haloId>"), "Remove <haloId>?");
    expect(
      l.groupInfoTheyWillStopReceiving,
      "They will stop receiving messages from this group.",
    );
    expect(l.commonRemove, "Remove");
    expect(l.groupInfoClearThisConversation, "Clear this conversation?");
    expect(
      l.groupInfoEveryMessageHereIs,
      "Every message here is erased from this phone. This only clears your copy, other members keep theirs.",
    );
    expect(l.groupInfoClear, "Clear");
    expect(l.groupInfoConversationCleared, "Conversation cleared");
    expect(l.groupInfoLeaveRoom, "Leave room?");
    expect(l.groupInfoLeaveGroup, "Leave group?");
    expect(
      l.groupInfoEverythingInItIs,
      "Everything in it is wiped from this phone now, and the key you used here is gone for good.",
    );
    expect(
      l.groupInfoYouWillStopReceiving,
      "You will stop receiving messages and other members will see you leave.",
    );
    expect(l.groupInfoLeave, "Leave");
    expect(l.groupInfoGroupInfo, "Group info");
    expect(l.groupInfo1Member(0), "0 members");
    expect(l.groupInfo1Member(1), "1 member");
    expect(l.groupInfo1Member(2), "2 members");
    expect(l.groupInfo1Member(5), "5 members");
    expect(l.groupInfoAdmin, "Admin");
    expect(l.groupInfoMembers2, "Members");
    expect(l.groupInfoInvite, "Invite");
    expect(l.commonAdd, "Add");
    expect(l.groupInfoYou, "You");
    expect(l.groupInfoRemoveFromGroup, "Remove from group");
    expect(l.groupInfoWallpaper, "Wallpaper");
    expect(l.groupInfoSharedMedia, "Shared media");
    expect(l.groupInfoClearConversation, "Clear conversation");
    expect(l.groupInfoLeaveRoom2, "Leave room");
    expect(l.groupInfoLeaveGroup2, "Leave group");
    expect(l.groupInfoAddMembers, "Add members");
    expect(l.groupInfoAdd("<pickedLength>"), "Add <pickedLength>");
    expect(l.handleYouAre("<h>"), "You are @<h>");
    expect(l.handleHandleDeletedThePage, "Handle deleted · the page is gone");
    expect(l.handlePublicHandle, "Public handle");
    expect(
      l.handleOptionalYourThreeWords,
      "Optional. Your three words keep working either way.",
    );
    expect(l.handleWren, "wren");
    expect(l.handleALineAboutYou, "A line about you · optional");
    expect(l.handleClaiming, "Claiming…");
    expect(l.handleClaimThisHandle, "Claim this handle");
    expect(
      l.handleAnyoneWithThisLink,
      "Anyone with this link can start a private chat with you. It carries your invite and nothing else.",
    );
    expect(l.handleLinkCopied, "Link copied");
    expect(l.handleDeleteThisHandle, "Delete this handle");
    expect(l.handleChecking, "Checking…");
    expect(l.handleAvailable, "✓ available");
    expect(l.handleAlreadyTaken, "already taken");
    expect(l.handleWhatAHandleDoes, "What a handle does");
    expect(
      l.handleAnyoneWhoKnowsIt,
      "Anyone who knows it can ask to message you, which is the point of having one. The page holds your invite and the line you wrote, nothing else, and keeps no record of who reads it. You can delete it whenever you like.",
    );
    expect(
      l.handleIsNotYoursOn("<handle>"),
      "@<handle> is not yours on this phone",
    );
    expect(
      l.handleTheRegistryHoldsIt("<handle>"),
      "The registry holds it under a different key, most likely an identity this phone had before a restore. People who add @<handle> are not reaching you. It cannot be released or updated from here. Pick another name.",
    );
    expect(l.handleForgetItOnThis, "Forget it on this phone");
    expect(l.homeAddAContact, "Add a contact");
    expect(l.commonSettings, "Settings");
    expect(l.homeYourKryfo, "Your kryfo");
    expect(l.homeDateWeekday("<weekday>"), "<weekday>,");
    expect(l.homeAnHour, "an hour");
    expect(l.homeHours(0), "0 hours");
    expect(l.homeHours(1), "1 hour");
    expect(l.homeHours(2), "2 hours");
    expect(l.homeHours(5), "5 hours");
    expect(l.homeMinutes(0), "0 minutes");
    expect(l.homeMinutes(1), "1 minute");
    expect(l.homeMinutes(2), "2 minutes");
    expect(l.homeMinutes(5), "5 minutes");
    expect(l.homeKryfoIsOffline, "Kryfo is offline");
    expect(
      l.homeTorHasNotBeen("<howLong>"),
      "Tor has not been able to connect for <howLong>. Nothing can arrive or leave until it does.",
    );
    expect(l.homeReconnecting, "Reconnecting");
    expect(l.homeReconnect, "Reconnect");
    expect(l.homeWhatIsWrong, "What is wrong");
    expect(l.homeKryfoWillCheckIn, "Kryfo will check in every 15 minutes");
    expect(l.homeYourPhoneKeepsStopping, "Your phone keeps stopping kryfo");
    expect(
      l.homeItHasClosedKryfo,
      "It has closed kryfo three times today, so messages were late or waited. Check-ins survive that: kryfo wakes every 15 minutes instead of staying connected.",
    );
    expect(l.homeSwitchToCheckIns, "Switch to check-ins");
    expect(l.homeNotNow, "Not now");
    expect(l.homeNotificationsAreOff, "Notifications are off");
    expect(
      l.homeAndroidIsBlockingThem,
      "Android is blocking them, so nothing reaches you while kryfo is closed. Messages still arrive when you open it.",
    );
    expect(
      l.homeCouldnTOpenIt,
      "Couldn't open it. Look for kryfo in phone settings",
    );
    expect(l.homeTurnThemOn, "Turn them on");
    expect(l.homeLeaveThemOff, "Leave them off");
    expect(l.homeOurRelayIsQuiet, "Our relay is quiet");
    expect(
      l.homeRelayModeUsesOnly,
      "Relay mode uses only our own relay, and it is not answering right now. Fast mode adds public relays alongside it, so messages still land. Everything stays sealed either way.",
    );
    expect(l.homeSwitchedToFast, "Switched to fast");
    expect(l.homeUseFastMode, "Use fast mode");
    expect(l.homeKeepWaiting, "Keep waiting");
    expect(l.homeNotConnecting, "Not connecting");
    expect(
      l.homeBridgesAreOnAnd,
      "Bridges are on and tor still is not through. Bridges are slower, and some go dead without warning. If your network does not block tor, going direct is faster and more reliable.",
    );
    expect(l.homeGoingDirectReconnecting, "Going direct · reconnecting");
    expect(l.homeTurnBridgesOff, "Turn bridges off");
    expect(l.homeStillTrying, "Still trying");
    expect(
      l.homeTorIsNotGetting,
      "Tor is not getting through. Some networks block it on purpose. Our own relay is one plain connection and usually works anyway - or bridges, which take longer to set up.",
    );
    expect(l.homeSwitchedToRelay, "Switched to relay");
    expect(l.homeUseOurRelay, "Use our relay");
    expect(l.homeBridges, "Bridges");
    expect(l.homeOffline, "Offline");
    expect(l.homeWaiting, "Waiting");
    expect(l.homeNothingWaitingToSend, "Nothing waiting to send");
    expect(l.homeWaitingSendsWhenYou(0), "0 waiting · sends when you're back");
    expect(l.homeWaitingSendsWhenYou(1), "1 waiting · sends when you're back");
    expect(l.homeWaitingSendsWhenYou(2), "2 waiting · sends when you're back");
    expect(l.homeWaitingSendsWhenYou(5), "5 waiting · sends when you're back");
    expect(l.homeWaitingTorIsStill(0), "0 waiting · tor is still connecting");
    expect(l.homeWaitingTorIsStill(1), "1 waiting · tor is still connecting");
    expect(l.homeWaitingTorIsStill(2), "2 waiting · tor is still connecting");
    expect(l.homeWaitingTorIsStill(5), "5 waiting · tor is still connecting");
    expect(l.homeWaitingForThemTo(0), "0 waiting · for them to add you back");
    expect(l.homeWaitingForThemTo(1), "1 waiting · for them to add you back");
    expect(l.homeWaitingForThemTo(2), "2 waiting · for them to add you back");
    expect(l.homeWaitingForThemTo(5), "5 waiting · for them to add you back");
    expect(
      l.homeWaitingForThemToAddYou(0, 0),
      "0 waiting · 0 for them to add you back",
    );
    expect(
      l.homeWaitingForThemToAddYou(0, 1),
      "0 waiting · 1 for them to add you back",
    );
    expect(
      l.homeWaitingForThemToAddYou(0, 2),
      "0 waiting · 2 for them to add you back",
    );
    expect(
      l.homeWaitingForThemToAddYou(0, 5),
      "0 waiting · 5 for them to add you back",
    );
    expect(
      l.homeWaitingForThemToAddYou(1, 0),
      "1 waiting · 0 for them to add you back",
    );
    expect(
      l.homeWaitingForThemToAddYou(1, 1),
      "1 waiting · 1 for them to add you back",
    );
    expect(
      l.homeWaitingForThemToAddYou(1, 2),
      "1 waiting · 2 for them to add you back",
    );
    expect(
      l.homeWaitingForThemToAddYou(1, 5),
      "1 waiting · 5 for them to add you back",
    );
    expect(
      l.homeWaitingForThemToAddYou(2, 0),
      "2 waiting · 0 for them to add you back",
    );
    expect(
      l.homeWaitingForThemToAddYou(2, 1),
      "2 waiting · 1 for them to add you back",
    );
    expect(
      l.homeWaitingForThemToAddYou(2, 2),
      "2 waiting · 2 for them to add you back",
    );
    expect(
      l.homeWaitingForThemToAddYou(2, 5),
      "2 waiting · 5 for them to add you back",
    );
    expect(
      l.homeWaitingForThemToAddYou(5, 0),
      "5 waiting · 0 for them to add you back",
    );
    expect(
      l.homeWaitingForThemToAddYou(5, 1),
      "5 waiting · 1 for them to add you back",
    );
    expect(
      l.homeWaitingForThemToAddYou(5, 2),
      "5 waiting · 2 for them to add you back",
    );
    expect(
      l.homeWaitingForThemToAddYou(5, 5),
      "5 waiting · 5 for them to add you back",
    );
    expect(l.homeWaitingSendingNow(0), "0 waiting · sending now");
    expect(l.homeWaitingSendingNow(1), "1 waiting · sending now");
    expect(l.homeWaitingSendingNow(2), "2 waiting · sending now");
    expect(l.homeWaitingSendingNow(5), "5 waiting · sending now");
    expect(l.commonRetry, "Retry");
    expect(l.homeNoKryfosYet, "No kryfos yet.");
    expect(
      l.homeScanTheirCodeSend,
      "Scan their code, send them a link, or type the @handle they gave you.",
    );
    expect(l.homeAddSomeone, "Add someone");
    expect(l.homeArchived, "Archived");
    expect(l.home1Chat(0), "0 chats");
    expect(l.home1Chat(1), "1 chat");
    expect(l.home1Chat(2), "2 chats");
    expect(l.home1Chat(5), "5 chats");
    expect(l.homeGroups, "Groups");
    expect(l.homeRoom, "Room");
    expect(l.homeNew, "New");
    expect(
      l.homeRoomExpired("<expiredRoomName>"),
      "<expiredRoomName> · room expired",
    );
    expect(l.homeMentionedYou, "Mentioned you");
    expect(l.homeMembers(0), "0 members");
    expect(l.homeMembers(1), "1 member");
    expect(l.homeMembers(2), "2 members");
    expect(l.homeMembers(5), "5 members");
    expect(l.homeSupporter, "Supporter");
    expect(l.homeArchivedChats, "Archived chats");
    expect(l.homeUnmute, "Unmute");
    expect(l.homeMute, "Mute");
    expect(l.homeArchive, "Archive");
    expect(l.homeDeleteChat, "Delete chat");
    expect(
      l.homeMessagesAndContactGone,
      "Messages and contact, gone from this phone",
    );
    expect(l.homeDeleteThisChat, "Delete this chat?");
    expect(
      l.homeEveryMessageWithGoes("<c>"),
      "Every message with <c> goes, and they stop being a contact. It only clears this phone - their copy stays with them. If they message again it lands in requests.",
    );
    expect(l.homeQueued, "Queued");
    expect(l.homeBlocked, "blocked");
    expect(l.homeRoomInvite, "Room invite");
    expect(l.homeNow, "now");
    expect(l.homeM("<inMinutes>"), "<inMinutes>m");
    expect(l.homeH("<inHours>"), "<inHours>h");
    expect(l.homeYesterday, "yesterday");
    expect(l.homeD("<inDays>"), "<inDays>d");
    expect(l.homeNoteToSelf, "Note to self");
    expect(l.homeOnlyOnThisPhone, "Only on this phone");
    expect(l.homeSaved, "Saved");
    expect(l.homeKeptFromEveryChat, "Kept from every chat");
    expect(l.homeRequests, "Requests");
    expect(l.home1PersonWantsTo(0), "0 people want to reach you");
    expect(l.home1PersonWantsTo(1), "1 person wants to reach you");
    expect(l.home1PersonWantsTo(2), "2 people want to reach you");
    expect(l.home1PersonWantsTo(5), "5 people want to reach you");
    expect(
      l.introduceGotItButCould("<b>", "<c>"),
      "<b> got it, but <c> could not be reached",
    );
    expect(
      l.introduceGotItButCouldNotBe("<c>", "<b>"),
      "<c> got it, but <b> could not be reached",
    );
    expect(
      l.introduceCouldNotReachEither,
      "Could not reach either of them. Try again later",
    );
    expect(l.introduceIntroduceTo("<peerName>"), "Introduce <peerName> to...");
    expect(
      l.introduceBothOfThemGet,
      "Both of them get the other's card. Neither sees your name for the other.",
    );
    expect(
      l.introduceNoOneElseTo,
      "No one else to introduce yet. Add another contact first.",
    );
    expect(l.introduceANoteLikeMy, "A note, like \"my cousin\" - optional");
    expect(
      l.introduceOfIntroductionsLeftThis(0, 0),
      "0 of 0 introductions left this week",
    );
    expect(
      l.introduceOfIntroductionsLeftThis(0, 1),
      "1 of 0 introductions left this week",
    );
    expect(
      l.introduceOfIntroductionsLeftThis(0, 2),
      "2 of 0 introductions left this week",
    );
    expect(
      l.introduceOfIntroductionsLeftThis(0, 5),
      "5 of 0 introductions left this week",
    );
    expect(
      l.introduceOfIntroductionsLeftThis(1, 0),
      "0 of 1 introduction left this week",
    );
    expect(
      l.introduceOfIntroductionsLeftThis(1, 1),
      "1 of 1 introduction left this week",
    );
    expect(
      l.introduceOfIntroductionsLeftThis(1, 2),
      "2 of 1 introduction left this week",
    );
    expect(
      l.introduceOfIntroductionsLeftThis(1, 5),
      "5 of 1 introduction left this week",
    );
    expect(
      l.introduceOfIntroductionsLeftThis(2, 0),
      "0 of 2 introductions left this week",
    );
    expect(
      l.introduceOfIntroductionsLeftThis(2, 1),
      "1 of 2 introductions left this week",
    );
    expect(
      l.introduceOfIntroductionsLeftThis(2, 2),
      "2 of 2 introductions left this week",
    );
    expect(
      l.introduceOfIntroductionsLeftThis(2, 5),
      "5 of 2 introductions left this week",
    );
    expect(
      l.introduceOfIntroductionsLeftThis(5, 0),
      "0 of 5 introductions left this week",
    );
    expect(
      l.introduceOfIntroductionsLeftThis(5, 1),
      "1 of 5 introductions left this week",
    );
    expect(
      l.introduceOfIntroductionsLeftThis(5, 2),
      "2 of 5 introductions left this week",
    );
    expect(
      l.introduceOfIntroductionsLeftThis(5, 5),
      "5 of 5 introductions left this week",
    );
    expect(
      l.introduceNoIntroductionsLeftNext("<refillPhrase>"),
      "No introductions left. Next one frees up <refillPhrase>",
    );
    expect(l.introduceIntroduce, "Introduce");
    expect(l.keyVerificationSafetyNumber, "Safety number");
    expect(l.keyVerificationWith("<peerName>"), "With <peerName>");
    expect(
      l.keyVerificationIfSeesTheSame("<peerName>"),
      "If <peerName> sees the same number, your messages are private to just the two of you. Comparing in person or over a call you trust is the surest way to be sure - but it is optional, never required to chat.",
    );
    expect(l.keyVerificationVerified, "Verified");
    expect(l.keyVerificationMarkAsVerified, "Mark as verified");
    expect(l.lockFileThatPasswordDoesNot, "That password does not open it.");
    expect(l.lockFileThisFileIsDamaged, "This file is damaged.");
    expect(
      l.lockFileThisFileWasLocked,
      "This file was locked to a key, not a password.",
    );
    expect(l.lockFileThisIsNotA, "This is not a locked file.");
    expect(l.lockFileNotEnoughFreeMemory, "Not enough free memory right now.");
    expect(l.lockFileStopped, "Stopped.");
    expect(l.lockFileItNeedsAPassword, "It needs a password.");
    expect(
      l.lockFileKryfoCouldNotRead,
      "Kryfo could not read or write the file.",
    );
    expect(
      l.lockFileCheckCapitalsAndSpaces,
      "Check capitals and spaces. Nobody can reset it, us included.",
    );
    expect(
      l.lockFileItMayHaveBeen,
      "It may have been cut short on the way. Ask for it to be sent again. Nothing was saved.",
    );
    expect(
      l.lockFileItOpensWithThe,
      "It opens with the key file of the person it was made for, in the age tool on a computer. Kryfo opens the password kind.",
    );
    expect(
      l.lockFileKryfoOpensFilesLocked,
      "Kryfo opens files locked with age. Those usually end in .age.",
    );
    expect(
      l.lockFileCloseAFewApps,
      "Close a few apps and try again. The password check needs a few hundred megabytes for a moment.",
    );
    expect(l.lockFileNothingWasSaved, "Nothing was saved.");
    expect(
      l.lockFileTypeOneOrLet,
      "Type one, or let Kryfo suggest four words.",
    );
    expect(
      l.lockFileTheAppThatHolds,
      "The app that holds it may have taken it back. Pick it again.",
    );
    expect(l.lockFileHidePassword, "Hide password");
    expect(l.lockFileShowPassword, "Show password");
    expect(l.lockFileChangeFile, "Change file");
    expect(l.lockFileChange, "Change");
    expect(
      l.lockFileOf("<prettySize>", "<prettySize2>"),
      "<prettySize> of <prettySize2>",
    );
    expect(l.lockFileEverythingStaysOnThis, "Everything stays on this phone.");
    expect(l.lockFileCouldNotMakeOne, "Could not make one. Type your own.");
    expect(
      l.lockFileWriteItDownBefore,
      "Write it down before you lock the file",
    );
    expect(l.lockFileNoAppOnThis, "No app on this phone took the file.");
    expect(l.lockFileSaved, "Saved");
    expect(
      l.lockFileCouldNotSaveIt,
      "Could not save it there. Try another folder.",
    );
    expect(l.lockFileLocked, "Locked");
    expect(l.lockFileLockAFile, "Lock a file");
    expect(l.lockFileMixingThePassword, "Mixing the password");
    expect(l.lockFileLocking, "Locking");
    expect(l.lockFileSaveToFiles, "Save to Files");
    expect(l.lockFileLockFile, "Lock file");
    expect(l.lockFileOnePassword, "One password.");
    expect(l.lockFileNothingElseOpensIt, "Nothing else opens it.");
    expect(l.lockFileFile, "File");
    expect(l.lockFileFromFiles("<prettySize>"), "<prettySize> · from Files");
    expect(l.lockFileFromFiles2, "From Files");
    expect(l.lockFilePassword, "Password");
    expect(l.lockFileSuggestFourWords, "Suggest four words");
    expect(l.lockFileTypeItAgain, "Type it again");
    expect(l.lockFileTheTwoDoNot, "The two do not match yet.");
    expect(l.lockFileHideTheFileName, "Hide the file name");
    expect(
      l.lockFileItWillBeCalled("<name>"),
      "It will be called “<name>”. Tell them what kind of file it is.",
    );
    expect(l.lockFileTheNameAloneCan, "The name alone can say what is inside.");
    expect(
      l.lockFileAnyoneWithThePassword,
      "Anyone with the password can open it, in Kryfo or on any computer with the free tool age. Forget it and the file is gone for good. Nobody can reset it, us included.",
    );
    expect(l.lockFileLocked2, "Locked.");
    expect(l.lockFileOnlyThePasswordOpens, "Only the password opens it.");
    expect(
      l.lockFileSafeToEmailOr("<prettySize>"),
      "<prettySize> · safe to email or put on a USB stick",
    );
    expect(
      l.lockFileNoKryfoOnThe,
      "No Kryfo on the other side? On a computer:",
    );
    expect(
      l.lockFileItAsksForThe,
      "It asks for the password. age is free at age-encryption.org",
    );
    expect(l.lockTooManyTriesS("<lockState>"), "Too many tries · <lockState>s");
    expect(l.lockNotIt, "Not it");
    expect(l.lockYourPin, "Your pin");
    expect(l.lockUseFingerprint, "Use fingerprint");
    expect(l.lockSetupThatIsYourWipe, "That is your wipe pin. Pick another.");
    expect(l.lockSetupUnlockWithFingerprint, "Unlock with fingerprint?");
    expect(
      l.lockSetupThePinStillWorks,
      "The pin still works whenever you want it. This is just faster.",
    );
    expect(l.lockSetupUseFingerprint, "Use fingerprint");
    expect(l.lockSetupPinOnly, "Pin only");
    expect(l.lockSetupOnceMore, "Once more");
    expect(l.lockSetupSetAPin, "Set a pin");
    expect(
      l.lockSetupThoseWereDifferentFrom,
      "Those were different. From the top.",
    );
    expect(l.lockSetupTheSameFourDigits, "The same four digits");
    expect(
      l.lockSetupFourDigitsAnythingYou,
      "Four digits, anything you will remember",
    );
    expect(l.modesOnion, "Onion");
    expect(
      l.modesFullOnionRoutingThree,
      "Full onion routing, three hops. A message takes two to five seconds. Nobody sees who you talk to.",
    );
    expect(l.modesSlower, "slower");
    expect(l.modesRelay, "Relay");
    expect(
      l.modesOneSealedConnectionTo,
      "One sealed connection to kryfo's own relay, like a vpn with nothing to log. Sends land in about a second, and it works where tor is blocked.",
    );
    expect(l.modesQuick, "quick");
    expect(l.modesRelayOnly, "Relay only");
    expect(l.modesFast, "Fast");
    expect(
      l.modesPlainConnectionsToEvery,
      "Plain connections to every relay. Near instant, and the least private of the three.",
    );
    expect(l.modesInstant, "instant");
    expect(
      l.modesEveryRelayYouUse,
      "Every relay you use knows the address you connect from, not only ours. Messages are still sealed, but the fact that you sent one is not. Off by default, and off again after a reinstall.",
    );
    expect(l.modesSpeed, "Speed");
    expect(l.modesPrivacy, "& privacy");
    expect(l.modesChangeGloballyOrPer, "Change globally, or per chat");
    expect(l.modesSoon, "Soon");
    expect(l.modesActive, "Active");
    expect(l.modesSpeed2, "SPEED");
    expect(l.modesHops, "HOPS");
    expect(l.modesIp, "IP");
    expect(l.modesVisible, "Visible");
    expect(l.modesHidden, "hidden");
    expect(l.modesHeadsUp("<warning>"), "*Heads up:* <warning>");
    expect(
      l.modesOnionIsTheDefault,
      "Onion is the default and stays that way unless you change it. Switching takes effect on the next message.",
    );
    expect(l.modesFastMode, "Fast mode");
    expect(
      l.modesPlainConnectionsToEveryRelayQuicker,
      "Plain connections to every relay. Quicker, and the relays can see your ip address. Messages stay end to end encrypted either way.",
    );
    expect(l.modesTurnOnFastMode, "Turn on fast mode");
    expect(l.modesKeepItOff, "Keep it off");
    expect(l.movedWipeThisPhone, "Wipe this phone?");
    expect(
      l.movedEverythingKryfoHoldsHere,
      "Everything kryfo holds here goes: the messages, the contacts, the keys. The other device keeps all of it. This cannot be undone.",
    );
    expect(l.movedWipeIt, "Wipe it");
    expect(l.movedNotMovingAfterAll, "Not moving after all?");
    expect(
      l.movedOnlyDoThisIf,
      "Only do this if the backup was never imported anywhere. If it was, two devices now hold one identity, and messages will start going missing on both.",
    );
    expect(l.movedIMStayingHere, "I'm staying here");
    expect(l.movedStayingHere, "Staying here");
    expect(
      l.movedKryfoWillCloseNow("<myId>"),
      "Kryfo will close now. Tap the icon to reopen as <myId>.",
    );
    expect(l.movedReopenKryfo, "Reopen kryfo");
    expect(l.movedThisKryfoHasMoved, "This kryfo has moved");
    expect(
      l.movedIsNowOnAnother("<myId>"),
      "<myId> is now on another device. This phone can still show what was here, but nothing new will arrive on it, and anything you send from here won't reach anyone.",
    );
    expect(l.movedKeepItToRead, "Keep it to read");
    expect(l.movedWipeThisPhone2, "Wipe this phone");
    expect(l.movedIMNotMoving, "I'm not moving after all");
    expect(l.myKryfoAHandleIs3, "A handle is 3 to 20 letters, digits or _");
    expect(l.myKryfoInviteCopiedClearsIn, "Invite copied · clears in 60s");
    expect(
      l.myKryfoAddMeOnKryfo("<myId>", "<uri>"),
      "add me on kryfo. my id is <myId>\n\ntap to add me:\n<uri>\n\nkryfo is a private messenger. no phone number, no email.",
    );
    expect(l.myKryfoAddMeOnKryfo2, "Add me on kryfo");
    expect(l.myKryfoAddSomeone, "Add someone");
    expect(
      l.myKryfoKryfoDoesnTScan,
      "kryfo doesn't scan your contacts, that's the point.",
    );
    expect(
      l.myKryfoIfThisLinkEnds,
      "If this link ends up somewhere you did not mean, reset it in settings. Everyone who has it needs a new one then.",
    );
    expect(
      l.myKryfoAlreadyShareAFriend,
      "Already share a friend on kryfo? They can introduce you both from their chat, and you skip the request.",
    );
    expect(l.myKryfoHandleCopied, "Handle copied");
    expect(l.myKryfoTheyReHereWith, "they're here with me");
    expect(
      l.myKryfoPointYourPhonesAt,
      "Point your phones at each other. Nothing goes through a server.",
    );
    expect(l.myKryfoScanTheirsInstead, "Scan theirs instead");
    expect(l.myKryfoTheyReadYouA, "They read you a code");
    expect(l.myKryfoTheyReSomewhereElse, "they're somewhere else");
    expect(
      l.myKryfoSendThemALink,
      "Send them a link. It opens straight into add.",
    );
    expect(
      l.myKryfoYourLinkAppearsOnce,
      "Your link appears once you are connected",
    );
    expect(
      l.myKryfoTheLinkCarriesYour,
      "The link carries your id, your address and the keys to start a chat. It works until you reset it in settings.",
    );
    expect(l.myKryfoSendTheLink, "Send the link");
    expect(l.myKryfoAsACard, "As a card");
    expect(l.myKryfoAnImageWithThe, "An image with the qr");
    expect(l.myKryfoAsAFile, "As a file");
    expect(l.myKryfoContactFile, "Contact file");
    expect(l.myKryfoIKnowTheirHandle, "I know their handle");
    expect(
      l.myKryfoTypeTheNameThey,
      "Type the @name they gave you. Works if they claimed one.",
    );
    expect(l.myKryfoWren, "Wren");
    expect(
      l.myKryfoTheLookupAsksFor,
      "The lookup asks for that one name and nothing about you. Their first message from you still lands as a request on their side.",
    );
    expect(l.myKryfoLooking, "Looking…");
    expect(l.myKryfoFindThem, "Find them");
    expect(
      l.myKryfoYourAddressAppearsOnce,
      "Your address appears once you are connected",
    );
    expect(l.myKryfoAPublicHandle, "A public handle");
    expect(
      l.myKryfoPutItInA,
      "Put it in a bio. Anyone who knows it can find you.",
    );
    expect(
      l.myKryfoANamePeopleCan,
      "A name people can find you by. Off until you claim one.",
    );
    expect(l.newGroupCouldNotCreate, "Could not create");
    expect(l.newGroupNewGroup, "New group");
    expect(l.newGroupCreating, "creating...");
    expect(l.newGroupCreate, "create");
    expect(l.newGroupGroupName, "Group name");
    expect(l.newGroupMembers, "Members");
    expect(l.newGroupPickAtLeastOne, "Pick at least one");
    expect(l.newGroupSelected(0), "0 selected");
    expect(l.newGroupSelected(1), "1 selected");
    expect(l.newGroupSelected(2), "2 selected");
    expect(l.newGroupSelected(5), "5 selected");
    expect(
      l.newGroupAddAtLeastOne,
      "Add at least one contact first before creating a group.",
    );
    expect(l.notesToday, "TODAY");
    expect(l.notesYesterday, "YESTERDAY");
    expect(l.notesNoteToSelf, "Note to self");
    expect(l.notesOnlyOnThisPhone, "Only on this phone");
    expect(l.notesAQuietPlace, "A quiet place");
    expect(
      l.notesJotAnythingDownIt,
      "Jot anything down. It stays on this phone and never leaves.",
    );
    expect(l.notesJotSomethingDown, "Jot something down…");
    expect(l.onboardingPrivateByDefault, "PRIVATE BY DEFAULT");
    expect(
      l.onboardingPrivateMessaging,
      "Private messaging,\n*without the catch*.",
    );
    expect(
      l.onboardingYourNameIsThree,
      "*Your name is three words.* No phone, no email, no address book.",
    );
    expect(
      l.onboardingNobodyGetsInUnless,
      "*Nobody gets in unless you let them.* There is no search. People are added by hand, both ways.",
    );
    expect(
      l.onboardingTheFirstConnectionTakes,
      "*The first connection takes a minute.* Kryfo builds a private route before it sends. Quick after.",
    );
    expect(l.onboardingBegin, "Begin");
    expect(l.onboardingHaveABackupRestore, "Have a backup? Restore →");
    expect(l.onboardingKryfoIsOpenSource, "Kryfo is open source");
    expect(l.onboardingYourKryfoId, "YOUR KRYFO ID");
    expect(
      l.onboardingGeneratedFromAKey,
      "Generated from a key that lives only on this phone. *Memorable, unique, yours alone.* No one else has this.",
    );
    expect(l.onboardingTryAnother, "Try another");
    expect(l.onboardingUseThisName, "Use this name →");
    expect(l.onboardingThreeWords, "Three words. *Yours alone.*");
    expect(l.onboardingPickA, "Pick a *face*.");
    expect(
      l.onboardingDrawnOnThisPhone,
      "Drawn on this phone from a number, never uploaded. Change it whenever you like.",
    );
    expect(
      l.onboardingThePeopleYouMessage,
      "The people you message see this too",
    );
    expect(l.onboardingKeepMyInitial, "Keep my initial");
    expect(l.onboardingThatOne, "That one →");
    expect(l.onboardingContinue, "Continue →");
    expect(l.onboardingHowYourMessages, "How your messages *travel*.");
    expect(
      l.onboardingYouCanChangeThis,
      "You can change this any time in settings, for everyone or for one chat.",
    );
    expect(l.onboardingOnion, "Onion");
    expect(
      l.onboardingSlowerAMessageTakes,
      "Slower. A message takes two to five seconds.",
    );
    expect(
      l.onboardingHidesYourAddressFrom,
      "Hides your address from everyone, our relay included.",
    );
    expect(l.onboardingRelay, "Relay");
    expect(
      l.onboardingOurRelaySeesYour,
      "Our relay sees your address. Nobody else does.",
    );
    expect(
      l.onboardingAboutASecondWorks,
      "About a second. Works where tor is blocked.",
    );
    expect(l.onboardingFast, "Fast");
    expect(
      l.onboardingEveryRelayYouUse,
      "Every relay you use sees your address. The least private of the three.",
    );
    expect(l.onboardingNearInstant, "Near instant.");
    expect(l.onboardingKeepOnion, "Keep onion →");
    expect(l.onboardingUseThis, "Use this →");
    expect(l.onboardingSkipOnionIsA, "Skip · onion is a fine default");
    expect(l.onboardingThreeThingsThen, "Three things,\nthen *you're in*.");
    expect(
      l.onboardingEverythingElseTheApp,
      "Everything else the app will tell you when it matters.",
    );
    expect(l.onboardingYourNameIsThreeWords, "Your name is three words");
    expect(
      l.onboardingThatIsTheWhole,
      "That is the whole identity. No number to leak, no email to phish, nothing to look up. People you talk to see these words and the face you picked.",
    );
    expect(
      l.onboardingNobodyCanReachYou,
      "Nobody can reach you until you let them in",
    );
    expect(
      l.onboardingAStrangerWithYour,
      "A stranger with your words can only knock. Their first message waits in requests until you say yes, and you can say no without them ever knowing.",
    );
    expect(
      l.onboardingTheFirstConnectionTakesAMinute,
      "The first connection takes a minute",
    );
    expect(
      l.onboardingKryfoBuildsAPrivateRouteBefore,
      "Kryfo builds a private route before it sends anything. While you are offline, messages wait and arrive when you are back.",
    );
    expect(
      l.onboardingYourIdentityLivesOn,
      "Your identity lives on this phone. Back it up from settings when you are ready.",
    );
    expect(l.onboardingIUnderstand, "I understand →");
    expect(l.onboardingOneQuiet, "One quiet *notification*.");
    expect(
      l.onboardingAndroidNeedsAVisible,
      "Android needs a visible notification while an app listens in the background. That is how messages reach you when kryfo is closed.",
    );
    expect(
      l.onboardingSilentAndAtThe,
      "Silent, and at the bottom of the shade",
    );
    expect(
      l.onboardingItNeverBuzzesTurn,
      "It never buzzes. Turn it off and messages wait until you open the app again.",
    );
    expect(l.onboardingGotIt, "Got it →");
    expect(l.onboardingNow, "Now, *add someone*.");
    expect(
      l.onboardingTheAppIsReady,
      "The app is ready. Nobody can message you until you add them or let them in.",
    );
    expect(l.onboardingEveryWayToAdd, "Every way to add someone");
    expect(
      l.onboardingShowYourCodeSend,
      "Show your code, send them a link, or type the @handle they gave you.",
    );
    expect(l.onboardingScanTheirs, "Scan theirs");
    expect(l.onboardingPointTheCameraAt, "Point the camera at their code");
    expect(l.onboardingTheAppIsReadyWhenYou, "The app is ready when you are.");
    expect(l.onboardingNotNowAddPeople, "Not now · add people later");
    expect(l.openLockedOpened, "Opened");
    expect(l.openLockedOpenALockedFile, "Open a locked file");
    expect(l.openLockedCheckingThePassword, "Checking the password");
    expect(l.openLockedOpening, "Opening");
    expect(l.openLockedFile, "File");
    expect(l.openLockedOpenFile, "Open file");
    expect(l.openLockedTypeThePassword, "Type the password.");
    expect(l.openLockedItOpensOnThis, "It opens on this phone.");
    expect(l.openLockedLockedFile, "Locked file");
    expect(l.openLockedFromFiles("<prettySize>"), "<prettySize> · from Files");
    expect(l.openLockedFromFiles2, "From Files");
    expect(l.openLockedPassword, "Password");
    expect(
      l.openLockedThePasswordIsChecked,
      "The password is checked first. Only then does Kryfo ask where to put the opened file, and it goes straight there.",
    );
    expect(l.openLockedOpened2, "Opened.");
    expect(l.openLockedSavedWhereYouChose, "Saved where you chose.");
    expect(l.pairCodePairingCode, "Pairing code");
    expect(l.pairCodeShowACode, "Show a code");
    expect(l.pairCodeEnterOne, "Enter one");
    expect(l.pairCodeSixDigits, "Six digits");
    expect(l.pairCodeLooking, "Looking…");
    expect(l.pairCodeNothingThereYetTrying, "Nothing there yet · trying again");
    expect(
      l.pairCodeNothingAtThatCode,
      "Nothing at that code. It may have burned, or they have not shared it yet.",
    );
    expect(l.pairCodeTypeTheSixDigits, "Type the six digits they read out.");
    expect(l.pairCodeAddThem, "Add them");
    expect(
      l.panicSetupThoseWereDifferentFrom,
      "Those were different. From the top.",
    );
    expect(l.panicSetupThatIsYourReal, "That is your real pin. Pick another.");
    expect(l.panicSetupOnceMore, "Once more");
    expect(l.panicSetupSetAWipePin, "Set a wipe pin");
    expect(l.panicSetupTheSameFourDigits, "The same four digits");
    expect(l.panicSetupTheSecondPinWipes, "The second pin wipes everything.");
    expect(l.photoKnowsEverythingInside, "Everything inside");
    expect(l.photoKnowsVideo, "Video");
    expect(l.photoKnowsPhoto, "Photo");
    expect(l.photoKnowsWhatThisVideoKnows, "What this video knows");
    expect(l.photoKnowsWhatThisPhotoKnows, "What this photo knows");
    expect(l.photoKnowsRemoveAllOfIt, "Remove all of it");
    expect(l.photoKnowsKeepItAsIt, "Keep it as it is");
    expect(
      l.photoKnowsReadOnThisPhone,
      "READ ON THIS PHONE · THE VIDEO WENT NOWHERE",
    );
    expect(
      l.photoKnowsReadOnThisPhoneThePhoto,
      "READ ON THIS PHONE · THE PHOTO WENT NOWHERE",
    );
    expect(l.photoKnowsReadingTheFile, "Reading the file");
    expect(
      l.photoKnowsOf("<prettySize>", "<prettySize2>"),
      "<prettySize> of <prettySize2>",
    );
    expect(
      l.photoKnowsEverythingStaysOnThis,
      "Everything stays on this phone.",
    );
    expect(l.photoKnowsMapWithAPin("<place>"), "Map with a pin. <place>");
    expect(l.photoKnowsDrawnOffline, "DRAWN OFFLINE");
    expect(l.photoKnowsShowEverything("<title>"), "<title>. Show everything");
    expect(l.pinsAppLock, "App lock");
    expect(l.pinsTwoPins, "Two pins");
    expect(l.pinsYourPin, "Your pin");
    expect(l.commonOn, "On");
    expect(l.commonOff, "Off");
    expect(
      l.pinsOpensKryfoFourDigits,
      "Opens kryfo. Four digits, asked for when it comes to the front.",
    );
    expect(l.pinsChangePin, "Change pin");
    expect(l.pinsSetAPin, "Set a pin");
    expect(l.pinsTurnOff, "Turn off");
    expect(l.pinsTurnOffTheApp, "Turn off the app lock?");
    expect(
      l.pinsThePinGoesAnd,
      "The pin goes, and the wipe pin with it. Anyone holding your phone opens kryfo as you.",
    );
    expect(l.pinsUnlockWithFingerprint, "Unlock with fingerprint");
    expect(l.pinsWipePin, "Wipe pin");
    expect(l.pinsNeedsAPinFirst, "Needs a pin first");
    expect(l.pinsSet, "Set");
    expect(l.pinsTheSecondPinWipes, "The second pin wipes everything.");
    expect(l.pinsChangeWipePin, "Change wipe pin");
    expect(l.pinsSetAWipePin, "Set a wipe pin");
    expect(l.pinsRemove, "remove");
    expect(l.pinsRemoveTheWipePin, "Remove the wipe pin?");
    expect(
      l.pinsTheLockScreenKeeps,
      "The lock screen keeps your pin. The wipe pin stops doing anything.",
    );
    expect(l.profileCopied("<what>"), "<what> copied");
    expect(l.profileProfile, "Profile");
    expect(l.profileChangeYourFace, "Change your face");
    expect(l.profileKryfoId, "kryfo id");
    expect(l.profileOnionAddress, "onion address");
    expect(l.profileSupporterBadge, "Supporter badge");
    expect(
      l.profileYouAreAThank("supporter"),
      "You are a supporter. Thank you.",
    );
    expect(l.profileYouAreAThank("patron"), "You are a patron. Thank you.");
    expect(l.profileYouAreAThank("guardian"), "You are a guardian. Thank you.");
    expect(l.profileYouAreAThank("other"), "You are a supporter. Thank you.");
    expect(l.profileShowMyBadge, "show my badge");
    expect(l.profileOnMyOwnScreens, "On my own screens");
    expect(l.profileLetContactsSeeIt, "Let contacts see it");
    expect(l.profileOffByDefault, "off by default");
    expect(l.profileShareConnect, "share & connect");
    expect(l.profileMyKryfoCode, "My kryfo code");
    expect(l.profileAddContact, "Add contact");
    expect(l.profileGiveAgain, "Give again");
    expect(l.profileSupportKryfo, "Support kryfo");
    expect(l.profileKryfoRunsOnWhat, "Kryfo runs on what people give");
    expect(l.profileKeepKryfoIndependent, "Keep kryfo independent");
    expect(l.qrLink, "Link");
    expect(l.qrYourLinkAsTyped, "YOUR LINK AS TYPED · NO TRACKING REDIRECT");
    expect(l.qrText, "Text");
    expect(l.qrStaysInTheCode, "STAYS IN THE CODE · NO SERVER HOLDS IT");
    expect(l.qrWiFi, "Wi-Fi");
    expect(
      l.qrMadeOnThisPhone,
      "MADE ON THIS PHONE · NO WEBSITE SAW THE PASSWORD",
    );
    expect(l.qrNetworkName, "Network name");
    expect(l.qrPassword, "Password");
    expect(l.qrContact, "Contact");
    expect(
      l.qrOnlyWhatYouType,
      "ONLY WHAT YOU TYPE · NOTHING FROM YOUR CONTACTS",
    );
    expect(l.qrName, "Name");
    expect(l.qrPhone, "Phone");
    expect(l.qrEmail, "Email");
    expect(
      l.qrOpensTheirMailApp,
      "OPENS THEIR MAIL APP · NOTHING SENT FROM HERE",
    );
    expect(l.qrTo, "To");
    expect(l.qrSubject, "Subject");
    expect(l.qrANumberNothingElse, "A NUMBER · NOTHING ELSE");
    expect(l.qrNumber, "Number");
    expect(l.qrSms, "SMS");
    expect(
      l.qrOpensTheirMessagesApp,
      "OPENS THEIR MESSAGES APP · NOTHING SENT FROM HERE",
    );
    expect(l.qrMessage, "Message");
    expect(l.qrLocation, "Location");
    expect(l.qrCoordinatesOnlyNoMap, "COORDINATES ONLY · NO MAP SERVICE ASKED");
    expect(l.qrLatitude, "Latitude");
    expect(l.qrLongitude, "Longitude");
    expect(l.qrBitcoin, "Bitcoin");
    expect(
      l.qrAddressAndAmountNo,
      "ADDRESS AND AMOUNT · NO PAYMENT SITE IN BETWEEN",
    );
    expect(l.qrAddress, "Address");
    expect(l.qrAmountInBtc, "Amount in BTC");
    expect(l.qrInk, "Ink");
    expect(l.qrAmber, "Amber");
    expect(l.qrViolet, "Violet");
    expect(l.qrCouldNotDrawThe, "Could not draw the image.");
    expect(l.qrSavedToYourGallery, "Saved to your gallery");
    expect(l.qrCouldNotSaveIt, "Could not save it. Check the phone has room.");
    expect(l.qrNoAppOnThis, "No app on this phone took the image.");
    expect(l.qrTooMuchForOne, "Too much for one code. Make it shorter.");
    expect(
      l.qrThisIsALot,
      "This is a lot for one code. Older cameras may not read it.",
    );
    expect(l.qrPrivateQrCode, "Private QR code");
    expect(l.qrColour, "Colour");
    expect(
      l.qrCopiedItLeavesThe,
      "Copied. It leaves the clipboard in a minute",
    );
    expect(l.qrSecurity, "Security");
    expect(l.qrNone, "None");
    expect(l.qrSaveImage, "Save image");
    expect(l.qrColour2("<name>"), "<name> colour");
    expect(l.qrTypeBelowAndThe, "Type below and the\ncode draws itself");
    expect(l.qrQrCode, "QR code");
    expect(l.qrHidePassword, "Hide password");
    expect(l.qrShowPassword, "Show password");
    expect(l.qrCopyPassword, "Copy password");
    expect(l.requestsSentAnAttachment, "Sent an attachment");
    expect(l.requestsWantsToConnect, "Wants to connect");
    expect(l.requestsAccepted, "Accepted");
    expect(l.requestsBlock("<id>"), "Block <id>?");
    expect(
      l.requestsNothingMoreFromThem,
      "Nothing more from them reaches you. Their request and its messages go.",
    );
    expect(l.requestsBlocked, "blocked");
    expect(l.requestsDeleted, "deleted");
    expect(l.requestsRequests, "Requests");
    expect(l.requestsNoRequests, "No requests");
    expect(
      l.requestsMessagesFromPeopleYou,
      "Messages from people you have not added show up here first.",
    );
    expect(
      l.requestsLooksSafeNothingSuspicious,
      "Looks safe · nothing suspicious in their first message",
    );
    expect(l.commonAccept, "Accept");
    expect(l.requestsDecline, "Decline");
    expect(l.restoreThatFileIsNot, "That file is not a kryfo backup");
    expect(
      l.restoreThisFileIsDamaged,
      "This file is damaged and cannot be read",
    );
    expect(
      l.restoreTypeThePassphraseThe,
      "Type the passphrase the file was made with",
    );
    expect(l.restoreReplaceTheAccountOn, "Replace the account on this phone?");
    expect(
      l.restoreWhatIsHereNow,
      "What is here now, its identity, contacts and messages, goes. The file takes its place. This cannot be undone.",
    );
    expect(l.restoreReplaceIt, "Replace it");
    expect(
      l.restoreCouldNotBeReleased("<mine>"),
      "@<mine> could not be released",
    );
    expect(
      l.restoreTheRegistryDidNot("<mine>"),
      "The registry did not answer. If you go on, @<mine> stays pointed at the identity this phone is about to lose. Anyone who adds it will be writing to nobody, and the name cannot be claimed again. Better to get online and try once more.",
    );
    expect(l.restoreRestoreAnyway, "Restore anyway");
    expect(l.restoreNotYet, "Not yet");
    expect(l.restoreRestored, "Restored");
    expect(
      l.restoreKryfoWillCloseNow("<haloId>"),
      "Kryfo will close now. Tap the icon to reopen as <haloId>.",
    );
    expect(l.restoreReopenKryfo, "Reopen kryfo");
    expect(
      l.restoreTheRestoreDidNot,
      "The restore did not finish. Nothing was changed",
    );
    expect(l.restoreThisIdentity, "this identity");
    expect(l.restoreMoveYourKryfoHere, "Move your kryfo here");
    expect(
      l.restoreThisBackupIsRestoring("<name>"),
      "This backup is <name>. Restoring it moves that identity to this device.",
    );
    expect(
      l.restoreThisBackupMadeOn("<name>", "<date>", "<time>"),
      "This backup is <name>, made on <date> at <time>. Restoring it moves that identity to this device.",
    );
    expect(
      l.restoreItHoldsOfPhotos("<mb>"),
      "It holds <mb> of photos, voice notes and files. This may take a few minutes. Keep the app open.",
    );
    expect(l.restoreWhatFollows, "What follows");
    expect(
      l.restoreYourNameYourCode,
      "Your name, your code, and every contact.",
    );
    expect(
      l.restoreEveryConversationBackTo,
      "Every conversation, back to the start.",
    );
    expect(
      l.restoreYourPhotosVoiceNotes,
      "Your photos, voice notes and files.",
    );
    expect(
      l.restoreYourPhotosVoiceNotesCount(0),
      "Your photos, voice notes and files · 0.",
    );
    expect(
      l.restoreYourPhotosVoiceNotesCount(1),
      "Your photos, voice notes and files · 1.",
    );
    expect(
      l.restoreYourPhotosVoiceNotesCount(2),
      "Your photos, voice notes and files · 2.",
    );
    expect(
      l.restoreYourPhotosVoiceNotesCount(5),
      "Your photos, voice notes and files · 5.",
    );
    expect(
      l.restoreYourOnionAddressSo,
      "Your onion address, so people who reach you directly keep reaching you.",
    );
    expect(
      l.restoreAnythingSentToYou,
      "Anything sent to you while the old phone was off, for fourteen days after it was sent.",
    );
    expect(
      l.restoreYourSupporterBadgeIf,
      "Your supporter badge, if you have one.",
    );
    expect(l.restoreWhatDoesnT, "What doesn't");
    expect(
      l.restoreTheOldPhoneStops,
      "The old phone stops receiving the moment you send anything from here. Not gradually. The first message you send from this device is the last one the old phone can follow, and anything that reaches it after that is unreadable there and isn't waiting for you here either.",
    );
    expect(
      l.restoreIfThePhoneThis,
      "If the phone this file came from is still in use, stop using kryfo on it before you carry on. Two phones on one kryfo lose messages on both.",
    );
    expect(
      l.restoreNotificationsNeedSettingUp,
      "Notifications need setting up again on this device.",
    );
    expect(l.restoreMoveItHere, "Move it here");
    expect(l.restoreNotNow, "Not now");
    expect(l.restoreRestore, "Restore");
    expect(l.restoreFromABackupFile, "From a backup file");
    expect(
      l.restoreABackupBringsBack,
      "A backup brings back your identity and your contacts, and the messages that were on the phone when the file was made. Anything said since is not in it.",
    );
    expect(l.restoreTheFile, "The file");
    expect(l.restorePickTheBackupFile, "Pick the backup file");
    expect(l.restoreThePassphrase, "The passphrase");
    expect(l.restoreTheOneTheFile, "The one the file was made with");
    expect(l.restoreWhatComesBack, "What comes back");
    expect(l.restoreChecking, "Checking…");
    expect(l.restoreCheckTheFile, "Check the file");
    expect(l.restoreReleasingYourHandle, "Releasing your handle…");
    expect(l.restoreMoving("<progress>"), "Moving… <progress>");
    expect(l.restoreRestoring, "Restoring…");
    expect(l.restoreNotThisOne, "Not this one");
    expect(l.restoreDateUnknown, "Date unknown");
    expect(l.restoreAnIdentity, "An identity");
    expect(
      l.restoreMessagesSentOrReceived,
      "Messages sent or received after that date are not in this file.",
    );
    expect(l.restoreGb("<bytes>"), "<bytes> GB");
    expect(l.restoreMb("<bytes>"), "<bytes> MB");
    expect(l.roomCreateCouldNotCreateThe, "Could not create the room");
    expect(l.roomCreateBurnerRoom, "Burner room");
    expect(
      l.roomCreateARoomThatEnds,
      "A room that ends. Everyone joins under a key made for it, and when it ends nothing is left on any phone.",
    );
    expect(l.roomCreateRoomName, "Room name");
    expect(l.roomCreateEndsAfter, "Ends after");
    expect(l.roomCreateMemberCap, "Member cap");
    expect(l.roomCreateNoOnePastThe(0), "No one past the first 0");
    expect(l.roomCreateNoOnePastThe(1), "No one past the first 1");
    expect(l.roomCreateNoOnePastThe(2), "No one past the first 2");
    expect(l.roomCreateNoOnePastThe(5), "No one past the first 5");
    expect(l.roomCreateOffAnyoneWithThe, "off. Anyone with the link");
    expect(
      l.roomCreateThisRoomAndEverything("<expiryWords>"),
      "This room and everything in it disappears in <expiryWords>",
    );
    expect(l.roomCreateCreating, "creating...");
    expect(l.roomCreateCreateRoom, "Create room");
    expect(l.roomLinkSendTheRoomTo, "Send the room to");
    expect(
      l.roomLinkTheyWillKnowThis,
      "They will know this room came from you. Inside it they are a key like everyone else.",
    );
    expect(l.roomLinkNoContactsYet, "No contacts yet");
    expect(l.roomLinkEndsIn("<time>"), "Ends in <time>");
    expect(
      l.roomLinkAnyoneWithThisCan,
      "Anyone with this can join until the room ends. They come in under a key made for this room, and see nothing sent before they arrived.",
    );
    expect(l.roomLinkRoomLinkCopied, "Room link copied");
    expect(l.roomLinkSendToAContact, "Send to a contact");
    expect(l.roomLinkCopyRoomLink, "Copy room link");
    expect(l.savedVoiceNote, "voice note");
    expect(l.savedPhoto, "photo");
    expect(l.savedSaved, "Saved");
    expect(l.savedNothingSavedYet, "Nothing saved yet");
    expect(
      l.savedLongPressAnyMessage,
      "long-press any message and tap save to keep it here.",
    );
    expect(l.savedViewInChat, "View in chat");
    expect(l.savedPhoto2, "Photo");
    expect(l.scanThatSNotA, "that's not a kryfo qr · keep pointing");
    expect(l.scanScanAKryfoQr, "Scan a kryfo qr");
    expect(l.scanFlash, "Flash");
    expect(
      l.scanPointAtAKryfo,
      "Point at a kryfo qr · nothing leaves your phone",
    );
    expect(l.seenWhatWeCanSee, "What we can see");
    expect(
      l.seenEveryMessengerClaimsPrivacy,
      "Every messenger claims privacy. This is the specific list, by route, including the parts that do not flatter us. Tap a row for the why.",
    );
    expect(
      l.seenHonestAboutTheLast,
      "Honest about the last rows: that is what the app lock, the wipe pin and encrypted storage are for, and no tool saves you from someone holding your open phone. The full threat model lives in THREAT_MODEL.md in the repo, written against LINDDUN. The code is open, so none of this has to be taken on trust.",
    );
    expect(l.seenHidden, "hidden");
    expect(l.seenNever, "never");
    expect(l.seenOnDevice, "on device");
    expect(l.seenTiming, "timing");
    expect(l.seenYours, "yours");
    expect(l.seenUnaudited, "unaudited");
    expect(l.seenWhoYouTalkTo, "Who you talk to");
    expect(
      l.seenEachConversationGetsIts,
      "Each conversation gets its own address, derived from both keys. A relay sees unrelated drop boxes, not a pair of people.",
    );
    expect(l.seenWhatYouSay, "what you say");
    expect(
      l.seenEndToEndEncrypted,
      "End to end encrypted with the signal double ratchet, then sealed again inside a gift wrap. We could not read it if we tried.",
    );
    expect(l.seenYourIpAddress, "Your ip address");
    expect(l.seenOurRelay, "our relay");
    expect(l.seenEveryRelay, "every relay");
    expect(
      l.seenOnOnionEverythingLeaves,
      "On onion everything leaves through tor and the relay sees an exit node, never you. On relay mode the connection goes straight to our own relay: nothing forwards your address and nothing is written down, but that one connection is ours to see. On fast every public relay learns that you connected, though not to whom or what you said.",
    );
    expect(l.seenYourContactGraph, "Your contact graph");
    expect(
      l.seenKryfoDoesNotScan,
      "Kryfo does not scan your contacts. That is the point. No phone number exists here to leak.",
    );
    expect(l.seenIntroducer, "introducer");
    expect(
      l.seenWhenAContactIntroduces,
      "When a contact introduces you to someone, that contact learns the two of you are now connected. Nobody else does. The relay sees ciphertext, and no server ever sees the graph.",
    );
    expect(l.seenTheScamShield, "The scam shield");
    expect(
      l.seenRunsOnYourPhone,
      "Runs on your phone with rules that ship in the app. No network, no list downloads. It only reads the first message from a stranger and cannot see anything a contact sends you.",
    );
    expect(l.seenBurnerRooms, "burner rooms");
    expect(l.seenRoomKeys, "room keys");
    expect(
      l.seenYouJoinARoom,
      "You join a room under a key made for it, so the people inside learn nothing that works elsewhere. Late joiners get no history. At expiry the keys, the messages and the media are destroyed.",
    );
    expect(l.seenLinkPreviews, "link previews");
    expect(l.seenOverTor, "over tor");
    expect(
      l.seenAPreviewIsFetched,
      "A preview is fetched by the sender, over tor, and travels inside the encrypted message. The receiving phone makes no request. The website learns that someone using tor asked for a page, and nothing else. No image is ever loaded, and a stranger's link stays plain text.",
    );
    expect(l.seenThatADeviceFetched, "That a device fetched mail");
    expect(
      l.seenARelayCanTell,
      "A relay can tell that some address was checked, and when. It cannot tell whose, or from where.",
    );
    expect(l.seenASeizedUnlockedPhone, "A seized unlocked phone");
    expect(
      l.seenIfSomeoneHoldsYour,
      "If someone holds your phone open, they read your messages. The app lock, panic pin and encrypted storage help before that point, not after it.",
    );
    expect(l.seenTheCryptoItself, "The crypto itself");
    expect(
      l.seenTheRatchetAndStorage,
      "The ratchet and storage layers are standard. The layer joining them is ours and no one independent has reviewed it. Treat this as alpha, because it is.",
    );
    expect(l.seenOnion, "Onion");
    expect(l.seenRelay, "Relay");
    expect(l.seenFast, "Fast");
    expect(l.settingsWipeKryfo, "Wipe kryfo?");
    expect(
      l.settingsIdentityMessagesContactsAnd,
      "Identity, messages, contacts and settings on this phone. Gone for good unless you have a backup.",
    );
    expect(l.commonContinue, "Continue");
    expect(l.settingsTypeWipeToConfirm("<word>"), "type '<word>' to confirm");
    expect(l.settingsTheLastStepNothing, "The last step. Nothing survives it.");
    expect(l.settingsWipeWord, "wipe");
    expect(l.settingsWipeKryfo2, "Wipe kryfo");
    expect(l.settingsYourProtections, "Your protections");
    expect(l.settingsTorRouting, "Tor routing");
    expect(l.settingsConnecting, "Connecting");
    expect(l.settingsOffMode, "Off · relay mode");
    expect(l.settingsOffFastMode, "Off · fast mode");
    expect(l.settingsAppLock, "App lock");
    expect(l.settingsBlockedByAndroid, "Blocked by android");
    expect(l.settingsSpeedPrivacy, "Speed & privacy");
    expect(l.settingsFast, "Fast");
    expect(l.settingsRelay1Hop, "Relay · 1 hop");
    expect(l.settingsOnion3Hops, "Onion · 3 hops");
    expect(l.settingsBridges, "Bridges");
    expect(l.settingsForNetworksThatBlock, "For networks that block tor");
    expect(l.settingsGettingMessages, "Getting messages");
    expect(
      l.settingsPreviewHidden("<deliveryModeName>"),
      "<deliveryModeName> · preview hidden",
    );
    expect(
      l.settingsPreviewShown("<deliveryModeName>"),
      "<deliveryModeName> · preview shown",
    );
    expect(l.settingsRunInBackground, "Run in background");
    expect(l.settingsSoMessagesArrive, "So messages arrive");
    expect(l.settingsTransport, "Transport");
    expect(l.settingsWhatTheNetworkIs, "What the network is doing");
    expect(l.settingsBlocked, "Blocked");
    expect(l.settingsAcceptIntroductions, "Accept introductions");
    expect(
      l.settingsFriendsCanIntroduceYou,
      "Friends can introduce you to theirs",
    );
    expect(l.settingsScamShield, "Scam shield");
    expect(
      l.settingsChecksStrangersOnYour,
      "Checks strangers on your phone. Nothing leaves it",
    );
    expect(l.settingsBlockScreenshots, "Block screenshots");
    expect(
      l.settingsWholeAppHiddenFrom,
      "Whole app hidden from recents and screenshots · takes effect after the next start",
    );
    expect(
      l.settingsWholeAppHiddenFromRecentsAnd,
      "Whole app hidden from recents and screenshots",
    );
    expect(l.settingsOnNextStart, "On · next start");
    expect(l.settingsOffNextStart, "Off · next start");
    expect(l.settingsLightTheme, "Light theme");
    expect(l.settingsSameProtectionBrighter, "Same protection, brighter");
    expect(l.settingsAppLock2, "App lock");
    expect(l.settingsYourPinAndA, "Your pin, and a wipe pin");
    expect(l.settingsPinWipePin, "Pin · wipe pin");
    expect(l.settingsBackUpIdentity, "Back up identity");
    expect(l.settingsEncryptedFile, "Encrypted file");
    expect(l.settingsRestoreFromBackup, "Restore from backup");
    expect(l.settingsReplaceCurrent, "Replace current");
    expect(l.settingsDisguiseVoice, "Disguise voice");
    expect(
      l.settingsShiftsYourPitchBefore,
      "Shifts your pitch before a voice note leaves",
    );
    expect(l.settingsWhyKryfo, "Why kryfo");
    expect(l.settingsHowItProtectsYou, "How it protects you");
    expect(l.settingsResetMyInviteLink, "Reset my invite link");
    expect(
      l.settingsOldLinksAndCodes,
      "Old links and codes stop working, for everyone",
    );
    expect(l.settingsResetInviteLink, "Reset invite link?");
    expect(
      l.settingsAnyoneWithAnOld,
      "Anyone with an old code or link stops being able to reach you, on every route. People who have it but never used it will need a new one from you. Contacts, chats and history stay.",
    );
    expect(l.settingsReset, "Reset");
    expect(l.settingsInviteResetShareThe, "Invite reset · share the new code");
    expect(l.settingsWhatWeCanSee, "What we can see");
    expect(l.settingsTheHonestList, "The honest list");
    expect(l.settingsVersion, "Version");
    expect(l.settings030Alpha, "0.3.0 · alpha");
    expect(l.settingsReportAnIssue, "Report an issue");
    expect(l.settingsBugOrSecurityFlaw, "Bug or security flaw");
    expect(l.settingsOpenSource, "Open source");
    expect(l.settingsLinkCopied, "Link copied");
    expect(
      l.settingsTheOfflineMapIn,
      "The offline map in Tools is drawn from Natural Earth (public domain). Town names are from GeoNames, geonames.org, under CC BY 4.0.",
    );
    expect(
      l.settingsNotIndependentlyAuditedPre,
      "Not independently audited. Pre-alpha - good for testing, not yet for high-stakes use.",
    );
    expect(l.settingsDangerZone, "Danger zone");
    expect(l.settingsWipeKryfoFromThis, "Wipe kryfo from this phone");
    expect(
      l.shieldCheckedOnThisPhone,
      "Checked on this phone. Nothing was sent anywhere.",
    );
    expect(l.toolsMoreTools, "More tools");
    expect(l.toolsCleanAPhotoOr, "Clean a photo or video");
    expect(l.toolsOrShareOneTo, "Or share one to Kryfo from your gallery");
    expect(l.toolsMakeAPrivateQr, "Make a private QR code");
    expect(
      l.toolsLinksWiFiContacts,
      "Links, Wi-Fi, contacts and more. Made offline",
    );
    expect(l.toolsLockAFile, "Lock a file");
    expect(
      l.toolsWithAPasswordOpens,
      "With a password. Opens anywhere with age",
    );
    expect(l.toolsOpenALockedFile, "Open a locked file");
    expect(l.toolsAnyAgeFileSomeone, "Any .age file someone sent you");
    expect(l.toolsWorksOfflineNoContacts, "Works offline · no contacts needed");
    expect(l.toolsUsefulFrom, "Useful from");
    expect(l.toolsTheFirstMinute, "the first minute.");
    expect(
      l.toolsEverythingHereHappensOn,
      "Everything here happens on this phone. Nothing is uploaded, and nobody else has to be on Kryfo.",
    );
    expect(l.toolsWhatDoesThisPhoto, "What does this photo know?");
    expect(l.toolsPlacePhoneTime, "Place · phone · time");
    expect(
      l.toolsPickAPhotoAnd,
      "Pick a photo and see what it gives away. Then keep a clean copy.",
    );
    expect(l.toolsPickAPhoto, "Pick a photo");
    expect(l.toolsVideo, "Video");
    expect(l.transportTransport, "Transport");
    expect(
      l.transportNothingHereLeavesThe,
      "Nothing here leaves the phone. It is the same state the engine uses to decide what to do.",
    );
    expect(l.transportStayingAlive, "staying alive");
    expect(l.transportCanSend, "can send");
    expect(l.commonYes, "Yes");
    expect(l.transportNotYet, "Not yet");
    expect(l.transportOnline, "Online");
    expect(l.transportOffline, "Offline");
    expect(l.transportQueuedToSend, "queued to send");
    expect(l.transportOnionPublished, "Onion published");
    expect(l.transportYes("<uploads>"), "Yes (<uploads>)");
    expect(l.transportTryingS("<pubFor>"), "Trying <pubFor>s");
    expect(l.transportBenchedS("<r>"), "Benched <r>s");
    expect(l.transportFails(0), "0 fails");
    expect(l.transportFails(1), "1 fail");
    expect(l.transportFails(2), "2 fails");
    expect(l.transportFails(5), "5 fails");
    expect(l.transportOk, "ok");
    expect(l.transportRelaySubscriptions, "Relay subscriptions");
    expect(l.transportLastSent, "last sent");
    expect(l.transportNever, "Never");
    expect(l.transportSAgo("<sx>"), "<sx>s ago");
    expect(l.transportLastReceived, "last received");
    expect(l.transportSAgo2("<rx>"), "<rx>s ago");
    expect(
      l.transportWithNoContactsThe,
      "With no contacts the app subscribes to no relay addresses, so no message can reach you. Scan someone to fix it.",
    );
    expect(l.transportSendAnythingWaitingNow, "Send anything waiting, now");
    expect(l.transportOff, "off");
    expect(l.transportStarting, "starting");
    expect(l.transportBootstrapped, "bootstrapped");
    expect(l.transportPublishingAddress, "Publishing address");
    expect(l.transportReachable, "reachable");
    expect(l.transportOurRelayOnion, "our relay (onion)");
    expect(l.transportNever2, "never");
    expect(l.transportJustNow, "Just now");
    expect(l.transportMAgo("<inMinutes>"), "<inMinutes>m ago");
    expect(l.transportHAgo("<inHours>"), "<inHours>h ago");
    expect(l.transportDAgo("<inDays>"), "<inDays>d ago");
    expect(l.transportM("<inMinutes>"), "<inMinutes>m");
    expect(l.transportHM("<inHours>", "<d>"), "<inHours>h <d>m");
    expect(l.transportD("<inDays>"), "<inDays>d");
    expect(l.transportMb("<b>"), "<b> mb");
    expect(l.transportYesCheckedJustNow, "Yes · checked just now");
    expect(l.transportNoLast("<ago>"), "No · last <ago>");
    expect(l.transportLastMessageIn, "Last message in");
    expect(l.transportBatteryExemption, "Battery exemption");
    expect(l.transportUnknown, "unknown");
    expect(l.transportExempt, "exempt");
    expect(l.transportNotExemptTapTo, "Not exempt · tap to fix");
    expect(l.transportProcessUp, "process up");
    expect(l.transportLastStop, "last stop");
    expect(l.transportEngine("<mb>", "<mb2>"), "<mb> · engine <mb2>");
    expect(l.transportLastRelayArrival, "Last relay arrival");
    expect(l.transportLastCheckIn, "last check-in");
    expect(l.transportNoneYet, "None yet");
    expect(l.transportLastTorReconnect, "last tor reconnect");
    expect(l.transportCatchUpByRelay, "catch-up by relay");
    expect(l.transportControlPort, "control port");
    expect(l.transportDialsTimeouts(0, 0), "0 dials · 0 timeouts");
    expect(l.transportDialsTimeouts(0, 1), "0 dials · 1 timeout");
    expect(l.transportDialsTimeouts(0, 2), "0 dials · 2 timeouts");
    expect(l.transportDialsTimeouts(0, 5), "0 dials · 5 timeouts");
    expect(l.transportDialsTimeouts(1, 0), "1 dial · 0 timeouts");
    expect(l.transportDialsTimeouts(1, 1), "1 dial · 1 timeout");
    expect(l.transportDialsTimeouts(1, 2), "1 dial · 2 timeouts");
    expect(l.transportDialsTimeouts(1, 5), "1 dial · 5 timeouts");
    expect(l.transportDialsTimeouts(2, 0), "2 dials · 0 timeouts");
    expect(l.transportDialsTimeouts(2, 1), "2 dials · 1 timeout");
    expect(l.transportDialsTimeouts(2, 2), "2 dials · 2 timeouts");
    expect(l.transportDialsTimeouts(2, 5), "2 dials · 5 timeouts");
    expect(l.transportDialsTimeouts(5, 0), "5 dials · 0 timeouts");
    expect(l.transportDialsTimeouts(5, 1), "5 dials · 1 timeout");
    expect(l.transportDialsTimeouts(5, 2), "5 dials · 2 timeouts");
    expect(l.transportDialsTimeouts(5, 5), "5 dials · 5 timeouts");
    expect(l.transportJobRuns, "job runs");
    expect(l.transportLast("<jobRuns>", "<ago>"), "<jobRuns> · last <ago>");
    expect(l.transportQuietStretches, "Quiet stretches");
    expect(l.transportNone, "None");
    expect(l.transportClearThisRecord, "Clear this record");
    expect(l.transportNothingYetThisProcess, "Nothing yet this process");
    expect(l.transportM2("<mins>"), "<mins>m");
    expect(l.transportHM2("<mins>", "<mins2>"), "<mins>h <mins2>m");
    expect(l.transportTo("<t>", "<t2>"), "<t> to <t2>");
    expect(l.vouchersVouchedBy(0), "vouched by 0");
    expect(l.vouchersVouchedBy(1), "vouched by");
    expect(l.vouchersVouchedBy(2), "vouched by 2");
    expect(l.vouchersVouchedBy(5), "vouched by 5");
    expect(l.wallpaperAtmosphere, "Atmosphere");
    expect(l.wallpaperJustForYouThey, "Just for you. They see their own.");
    expect(l.wallpaperYourPhoto, "your photo");
    expect(l.wallpaperFromYourPhotos, "From your photos");
    expect(l.wallpaperKeepIt, "Keep it");
    expect(l.whyKryfoWhyKryfo, "Why kryfo");
    expect(
      l.whyKryfoKryfoKreeFoGreek,
      "Kryfo · KREE-fo · greek for hidden.\nA quiet place to talk, built so no one is watching.",
    );
    expect(l.whyKryfoRoutedThroughTor, "Routed through tor");
    expect(
      l.whyKryfoByDefaultEveryMessage,
      "By default every message travels through tor - a chain of relays. No one, not us and not your network, can see who you talk to or where you are.",
    );
    expect(l.whyKryfoEndToEndEncrypted, "end-to-end encrypted");
    expect(
      l.whyKryfoMessagesAreSealedWith,
      "Messages are sealed with keys only you and the person you are talking to hold. We could not read them if we tried.",
    );
    expect(l.whyKryfoNoServersHoldingYour, "No servers holding your life");
    expect(
      l.whyKryfoNoAccountNoPhone,
      "No account, no phone number, no central server storing your chats. They live on this phone, encrypted at rest.",
    );
    expect(l.whyKryfoNothingLeaks, "nothing leaks");
    expect(
      l.whyKryfoNoReadReceiptsOr,
      "No read receipts or typing tells handed to anyone, no contact list uploaded. Metadata is what most apps leak - kryfo is built not to.",
    );
    expect(l.whyKryfoVerifyItIsReally, "Verify it is really them");
    expect(
      l.whyKryfoCompareASafetyNumber,
      "compare a safety number in person or over a channel you trust, so you know no one is impersonating your contact.",
    );
    expect(l.whyKryfoTheHonestPart, "The honest part");
    expect(
      l.whyKryfoKryfoIsPreAlpha,
      "Kryfo is pre-alpha and has not been audited. The crypto is real but no outside expert has checked it yet, so treat it as a work in progress, not something to trust with your life yet.",
    );
    expect(l.cleanerLocation, "Location");
    expect(l.cleanerAlreadyBlankedByAndroid, "already blanked by Android");
    expect(l.cleanerPhoneModel, "Phone model");
    expect(l.cleanerTimeTaken, "Time taken");
    expect(l.cleanerSerialNumber, "Serial number");
    expect(l.cleanerOwnerName, "Owner name");
    expect(l.cleanerHiddenThumbnail, "Hidden thumbnail");
    expect(l.cleanerContentCredentials, "Content credentials");
    expect(l.cleanerDataAfterThePicture, "Data after the picture");
    expect(l.cleaner1OtherField(0), "0 other fields");
    expect(l.cleaner1OtherField(1), "1 other field");
    expect(l.cleaner1OtherField(2), "2 other fields");
    expect(l.cleaner1OtherField(5), "5 other fields");
    expect(
      l.lockWordsFourRandomWordsBeat,
      "Four random words beat one clever one.",
    );
    expect(l.lockWordsTooShortAtLeast(0), "Too short. At least 0 characters.");
    expect(l.lockWordsTooShortAtLeast(1), "Too short. At least 1 character.");
    expect(l.lockWordsTooShortAtLeast(2), "Too short. At least 2 characters.");
    expect(l.lockWordsTooShortAtLeast(5), "Too short. At least 5 characters.");
    expect(
      l.lockWordsWeakWhoeverGetsThe,
      "Weak. Whoever gets the file can guess as fast as they like.",
    );
    expect(l.lockWordsFairLongerIsStronger, "Fair. Longer is stronger.");
    expect(
      l.lockWordsStrongFourRandomWords,
      "Strong. Four random words beat one clever one.",
    );
    expect(l.photoStoryKm("<m>"), "<m> km");
    expect(l.photoStory1Metre(0), "0 metres");
    expect(l.photoStory1Metre(1), "1 metre");
    expect(l.photoStory1Metre(2), "2 metres");
    expect(l.photoStory1Metre(5), "5 metres");
    expect(l.photoStoryFarFromAnyTown, "Far from any town");
    expect(l.photoStoryNear("<where>"), "Near <where>");
    expect(
      l.photoStoryAboutKmFrom("<near>", "<where>"),
      "About <near> km from <where>",
    );
    expect(l.photoStoryS("<s>"), "<s> s");
    expect(l.photoStory1S("<s>"), "1/<s> s");
    expect(l.photoStoryNotAKindKryfo, "Not a kind Kryfo can read.");
    expect(l.photoStorySoItWillNot, "So it will not guess.");
    expect(l.photoStoryThisFileIsDamaged, "This file is damaged or cut short.");
    expect(
      l.photoStoryKryfoCouldNotRead,
      "Kryfo could not read it to the end.",
    );
    expect(l.photoStoryWhereItWasRecorded, "Where it was recorded");
    expect(l.photoStoryWhereItWasTaken, "Where it was taken");
    expect(l.photoStoryLocation("<coordsLine>"), "Location: <coordsLine>");
    expect(
      l.photoStoryHeightAboveTheSea("<fix>"),
      "Height above the sea: <fix> m",
    );
    expect(l.photoStoryLocationHiddenByAndroid, "Location hidden by Android");
    expect(
      l.photoStoryAndroidBlanksItWhen,
      "Android blanks it when a photo is picked this way. Sharing it to Kryfo from your gallery often keeps it. The one in your gallery may still have it.",
    );
    expect(
      l.photoStoryLocationBlankedByAndroid,
      "Location: blanked by Android before Kryfo saw it",
    );
    expect(l.photoStoryF("<r>"), "f/<r>");
    expect(l.photoStoryWhatTookIt, "What took it");
    expect(l.photoStoryPhoneOrCamera("<phone>"), "Phone or camera: <phone>");
    expect(l.photoStoryWhenItWasRecorded, "When it was recorded");
    expect(l.photoStoryToTheSecondWith, "To the second, with the time zone");
    expect(l.photoStoryToTheSecond, "To the second");
    expect(l.photoStoryTime("<dateFormat>"), "Time: <dateFormat>");
    expect(l.photoStoryLens, "Lens");
    expect(l.photoStoryLens2("<lens>"), "Lens: <lens>");
    expect(l.photoStorySoftware, "Software");
    expect(l.photoStorySoftware2("<software>"), "Software: <software>");
    expect(l.photoStorySerialNumber, "Serial number");
    expect(l.photoStorySerialNumber2("<serial>"), "Serial number: <serial>");
    expect(l.photoStoryOwnerName, "Owner name");
    expect(l.photoStoryOwner("<r>"), "Owner: <r>");
    expect(l.photoStoryHiddenThumbnail, "Hidden thumbnail");
    expect(
      l.photoStoryASmallCopyOf,
      "A small copy of the picture inside the file. It can show what a crop removed",
    );
    expect(l.photoStoryMakerNotes, "Maker notes");
    expect(
      l.photoStoryMakerNotesABlock,
      "Maker notes: a block only the maker can read",
    );
    expect(l.photoStoryEditingHistory, "Editing history");
    expect(l.photoStoryXmpEditingHistoryAnd, "XMP: editing history and tags");
    expect(l.photoStoryCaptions, "Captions");
    expect(l.photoStoryIptcCaptionsAndCredits, "IPTC: captions and credits");
    expect(l.photoStoryComment, "Comment");
    expect(l.photoStoryAWrittenComment, "A written comment");
    expect(l.photoStoryContentCredentials, "Content credentials");
    expect(l.photoStorySecondPicture, "Second picture");
    expect(
      l.photoStoryASecondPictureInside,
      "A second picture inside the file",
    );
    expect(l.photoStoryMotionVideo, "Motion video");
    expect(l.photoStoryAShortVideoInside, "A short video inside the file");
    expect(l.photoStorySaveTime, "Save time");
    expect(l.photoStoryTheTimeItWas, "The time it was last saved");
    expect(l.photoStoryTimeStamps, "Time stamps");
    expect(l.photoStoryCreationTimeStamps, "Creation time stamps");
    expect(l.photoStoryDataAfterThePicture, "Data after the picture");
    expect(
      l.photoStoryDataAfterTheEnd(0),
      "Data after the end of the picture: 0 bytes",
    );
    expect(
      l.photoStoryDataAfterTheEnd(1),
      "Data after the end of the picture: 1 byte",
    );
    expect(
      l.photoStoryDataAfterTheEnd(2),
      "Data after the end of the picture: 2 bytes",
    );
    expect(
      l.photoStoryDataAfterTheEnd(5),
      "Data after the end of the picture: 5 bytes",
    );
    expect(l.photoStoryTextField("<k>"), "Text field: <k>");
    expect(l.photoStoryVideoTag("<k>"), "Video tag: <k>");
    expect(l.photoStoryAlso("<k>"), "Also: <k>");
    expect(
      l.photoStoryCameraSettingsFlashFocus(0),
      "0 camera settings (flash, focus, exposure)",
    );
    expect(
      l.photoStoryCameraSettingsFlashFocus(1),
      "1 camera setting (flash, focus, exposure)",
    );
    expect(
      l.photoStoryCameraSettingsFlashFocus(2),
      "2 camera settings (flash, focus, exposure)",
    );
    expect(
      l.photoStoryCameraSettingsFlashFocus(5),
      "5 camera settings (flash, focus, exposure)",
    );
    expect(l.photoStory1MoreField(0), "0 more fields");
    expect(l.photoStory1MoreField(1), "1 more field");
    expect(l.photoStory1MoreField(2), "2 more fields");
    expect(l.photoStory1MoreField(5), "5 more fields");
    expect(l.photoStoryCameraSettings, "Camera settings");
    expect(
      l.photoStoryAccurateToAbout("<metres>"),
      "Accurate to about <metres>.",
    );
    expect(l.photoStoryEnoughToFindThe, "Enough to find the door.");
    expect(l.photoStoryEnoughToFindTheStreet, "Enough to find the street.");
    expect(l.photoStoryEnoughToFindTheArea, "Enough to find the area.");
    expect(l.photoStoryItKnowsWhereYou, "It knows where you were.");
    expect(l.photoStoryDownToTheBuilding, "Down to the building.");
    expect(l.photoStoryAndroidHidTheLocation, "Android hid the location.");
    expect(l.photoStoryTheOriginalMayStill, "The original may still carry it.");
    expect(l.photoStoryNoLocationInThis, "No location in this one.");
    expect(l.photoStoryItStillSaysPlenty, "It still says plenty.");
    expect(l.photoStoryThisOneKnowsNothing, "This one knows nothing.");
    expect(l.photoStoryNothingToRemove, "Nothing to remove.");
    expect(l.qrPayloadOpensALink, "OPENS A LINK");
    expect(l.qrPayloadOpens("<host>"), "OPENS <host>");
    expect(l.qrPayloadShowsANote, "SHOWS A NOTE");
    expect(l.qrPayloadScanToJoin, "SCAN TO JOIN");
    expect(l.qrPayloadScanToJoin2("<oneLine>"), "SCAN TO JOIN · <oneLine>");
    expect(
      l.qrPayloadANetworkNameIs,
      "A network name is 32 characters at most.",
    );
    expect(
      l.qrPayloadAWiFiPassword,
      "A Wi-Fi password has at least 8 characters.",
    );
    expect(l.qrPayloadSavesAContact, "SAVES A CONTACT");
    expect(l.qrPayloadWritesAnEmail, "WRITES AN EMAIL");
    expect(
      l.qrPayloadThatDoesNotLook,
      "That does not look like an email address.",
    );
    expect(l.qrPayloadCallsANumber, "CALLS A NUMBER");
    expect(l.qrPayloadWritesAText, "WRITES A TEXT");
    expect(l.qrPayloadOpensAMap, "OPENS A MAP");
    expect(
      l.qrPayloadLatitudeRunsFrom90,
      "Latitude runs from -90 to 90, longitude from -180 to 180.",
    );
    expect(l.qrPayloadPayThisAddress, "PAY THIS ADDRESS");
    expect(
      l.qrPayloadABitcoinAddressIs,
      "A bitcoin address is letters and digits only.",
    );
    expect(
      l.qrPayloadTheAmountIsIn,
      "The amount is in BTC, with up to 8 decimals.",
    );
    expect(l.vouchTextAnd("<names>", "<names2>"), "<names> and <names2>");
    expect(
      l.vouchTextAndOtherYouKnow("<names>", "<names2>", 0),
      "<names>, <names2> and 0 others you know",
    );
    expect(
      l.vouchTextAndOtherYouKnow("<names>", "<names2>", 1),
      "<names>, <names2> and 1 other you know",
    );
    expect(
      l.vouchTextAndOtherYouKnow("<names>", "<names2>", 2),
      "<names>, <names2> and 2 others you know",
    );
    expect(
      l.vouchTextAndOtherYouKnow("<names>", "<names2>", 5),
      "<names>, <names2> and 5 others you know",
    );
    expect(l.vouchTextVouchedBy("<vouchNames>"), "Vouched by <vouchNames>");
    expect(
      l.vouchTextIntroducedBy("<vouchNames>"),
      "Introduced by <vouchNames>",
    );
    expect(
      l.vouchTextThisSharesSAddress("<a>", "<b>"),
      "This shares <a>'s address with <b>",
    );
    expect(l.bootFailedKryfoCouldNotStart, "Kryfo could not start");
    expect(
      l.bootFailedThisIsAFault,
      "This is a fault on this device, not the network. Tor is not involved.",
    );
    expect(l.kryfoLinkTextThatLinkIsNot, "That link is not one kryfo can read");
    expect(l.kryfoLinkTextAdd("<who>"), "Add <who>?");
    expect(
      l.kryfoLinkTextThisIsAnInvite("<who>"),
      "This is an invite to talk to <who>. Add them only if you know where the link came from.",
    );
    expect(l.kryfoLinkTextAddThem, "Add them");
    expect(l.kryfoLinkTextNotNow, "Not now");
    expect(l.kryfoLinkTextJoin("<roomName>"), "Join <roomName>");
    expect(l.kryfoLinkTextKryfoLink, "kryfo link");
    expect(l.kryfoLinkTextAdd2("<who>"), "Add <who>");
    expect(l.kryfoLinkTextBurnerRoom, "BURNER ROOM");
    expect(l.kryfoLinkTextThisRoomHasClosed, "This room has closed");
    expect(l.kryfoLinkTextClosesIn("<time>"), "Closes in <time>");
    expect(
      l.kryfoLinkTextClosesInUpTo(0, "<time>"),
      "Closes in <time> · up to 0",
    );
    expect(
      l.kryfoLinkTextClosesInUpTo(1, "<time>"),
      "Closes in <time> · up to 1",
    );
    expect(
      l.kryfoLinkTextClosesInUpTo(2, "<time>"),
      "Closes in <time> · up to 2",
    );
    expect(
      l.kryfoLinkTextClosesInUpTo(5, "<time>"),
      "Closes in <time> · up to 5",
    );
    expect(l.kryfoLinkTextJoin2, "Join");
    expect(
      l.kryfoLinkTextYouJoinUnderA,
      "You join under a key made for this room. Nobody in it sees your kryfo id.",
    );
    expect(l.linkStubFetchedOverTorBy, "Fetched over tor · by your device");
    expect(
      l.linkStubFetchedOverTorByTheirDevice,
      "Fetched over tor · by their device",
    );
    expect(l.mediaBubblesB("<bytes>"), "<bytes> b");
    expect(l.mediaBubblesKb("<bytes>"), "<bytes> kb");
    expect(l.mediaBubblesMb("<bytes>"), "<bytes> mb");
    expect(l.mediaBubblesFile, "FILE");
    expect(l.mediaBubblesAudioUnavailable, "Audio unavailable");
    expect(l.mediaBubblesHidden, "Hidden");
    expect(l.mediaBubblesMicPermissionNeeded, "Mic permission needed");
    expect(l.mediaBubblesReleaseToCancel, "Release to cancel");
    expect(l.mediaBubblesVoiceHiddenSlideTo, "Voice hidden · slide to cancel");
    expect(l.mediaBubblesSlideToCancel, "Slide to cancel");
    expect(l.mediaBubblesSendPhoto, "Send photo");
    expect(l.mediaBubblesAddACaption, "Add a caption…");
    expect(l.motionStandby, "STANDBY");
    expect(l.motionConnecting, "CONNECTING");
    expect(l.motionBuilding, "BUILDING");
    expect(l.motionPublishing, "PUBLISHING");
    expect(l.motionReady, "READY");
    expect(l.motionPreparingToConnect, "Preparing to connect");
    expect(l.motionFindingAPrivatePath, "Finding a private path");
    expect(l.motionCarvingThePath, "Carving the path");
    expect(l.motionAnnouncingYourArrival, "Announcing your arrival");
    expect(l.motionYouReAnonymous, "you're anonymous");
    expect(
      l.motionTorIsStartingIn,
      "Tor is starting in the background. This graph lights up as the connection forms.",
    );
    expect(
      l.motionMakingAFreshRoute,
      "Making a fresh route through anonymous relays.",
    );
    expect(
      l.motionBouncingThroughRelaysSo,
      "Bouncing through relays so no one can trace this back to you.",
    );
    expect(
      l.motionTellingTheNetworkYou,
      "telling the network you're online — without revealing where.",
    );
    expect(
      l.motionYourIpIsHidden,
      "Your ip is hidden. Only people with your kryfo can reach you.",
    );
    expect(l.motionBuilding2, "building");
    expect(l.motionOpen, "open");
    expect(l.motionLive, "live");
    expect(l.motionCircuit("<circuit>"), "Circuit · *<circuit>*");
    expect(l.motionDelivered, "delivered");
    expect(l.motionSent, "sent");
    expect(l.motion1Hop, "1 hop");
    expect(l.motion3Hops, "3 hops");
    expect(
      l.movedStripThisKryfoHasMoved,
      "This kryfo has moved to another device. Nothing sent from here reaches anyone.",
    );
    expect(l.navBarChats, "Chats");
    expect(l.navBarTools, "Tools");
    expect(l.navBarSupport, "Support");
    expect(l.navBarMe, "Me");
    expect(l.pairCodePanelPuttingYourInviteIn, "Putting your invite in place");
    expect(l.pairCodePanelYourInviteIsNot, "Your invite is not ready yet");
    expect(
      l.pairCodePanelReadSixDigitsOut,
      "Read six digits out loud and they can add you. Nothing else needs to change hands.",
    );
    expect(l.pairCodePanelWorking, "Working");
    expect(l.pairCodePanelOrMakeASix, "Or make a six digit code to read out");
    expect(l.pairCodePanelCodeCopied, "Code copied");
    expect(l.pairCodePanelBurnsIn("<mm>", "<ss>"), "Burns in <mm>:<ss>");
    expect(
      l.pairCodePanelTheyTapAddChoose,
      "They tap add, choose code, and type these.",
    );
    expect(
      l.pairCodePanelTheyOpenKryfoTap,
      "They open kryfo, tap add, choose pairing code and type these six digits. Make a new one for the next person.",
    );
    expect(l.pinsPinnedMessages("<count>"), "Pinned messages · <count>");
    expect(l.pinsPinnedMessages2, "Pinned messages");
    expect(l.pinsPhoto, "Photo");
    expect(l.pinsVoiceMessage, "Voice message");
    expect(l.pinsMessage, "Message");
    expect(l.pinsToday("<hm>"), "Today · <hm>");
    expect(l.pinsPinned, "Pinned");
    expect(
      l.pinsOf("<pinsLength>", "<kMaxPins>"),
      "<pinsLength> of <kMaxPins>",
    );
    expect(
      l.pinsNothingPinnedHereYet,
      "Nothing pinned here yet. Hold a message and choose Pin, and it waits here for everyone in the chat.",
    );
    expect(l.pinsJump, "Jump");
    expect(l.pinsUnpin, "Unpin");
    expect(
      l.powNoteFirstMessageToSomeone(0),
      "First message to someone new · proving it is real · 0s",
    );
    expect(
      l.powNoteFirstMessageToSomeone(1),
      "First message to someone new · proving it is real · 1s",
    );
    expect(
      l.powNoteFirstMessageToSomeone(2),
      "First message to someone new · proving it is real · 2s",
    );
    expect(
      l.powNoteFirstMessageToSomeone(5),
      "First message to someone new · proving it is real · 5s",
    );
    expect(
      l.powNoteFirstMessageSlow(0),
      "First message to someone new · proving it is real · 0s · up to a minute on a slow phone",
    );
    expect(
      l.powNoteFirstMessageSlow(1),
      "First message to someone new · proving it is real · 1s · up to a minute on a slow phone",
    );
    expect(
      l.powNoteFirstMessageSlow(2),
      "First message to someone new · proving it is real · 2s · up to a minute on a slow phone",
    );
    expect(
      l.powNoteFirstMessageSlow(5),
      "First message to someone new · proving it is real · 5s · up to a minute on a slow phone",
    );
    expect(
      l.previewStripFetchedOverTor("<domainOf>"),
      "<domainOf> · fetched over tor",
    );
    expect(l.previewStripDropThePreview, "Drop the preview");
    expect(l.previewStripAddPreview, "Add preview");
    expect(l.previewStripFetchingOverTor, "Fetching over tor…");
    expect(l.toolPartsB("<bytes>"), "<bytes> B");
    expect(l.toolPartsKb("<bytes>"), "<bytes> KB");
    expect(l.toolPartsMb("<mb>"), "<mb> MB");
    expect(l.torBootSplashNoShortcutsNoTraces, "No shortcuts, no traces");
    expect(
      l.torBootSplashTheNetworkThatKeeps,
      "The network that keeps you private is warming up",
    );
    expect(
      l.torBootSplashMadeOnThisPhone,
      "Made on this phone. Nothing is sent anywhere.",
    );
    expect(
      l.torBootSplashFirstLaunchTakesA,
      "First launch takes a moment · only on startup",
    );
    expect(
      l.videoBubbleNothingHereOpensThat,
      "Nothing here opens that · sharing instead",
    );
    expect(l.videoBubbleMb("<b>"), "<b> MB");
    expect(l.videoBubbleKb("<b>"), "<b> KB");
    expect(l.videoBubbleVideo, "Video");
    expect(l.notificationsChannelName, "messages");
    expect(l.cameraClose, "close");
    expect(l.cameraFlash, "flash");
    expect(l.cameraPhoto, "photo");
    expect(l.cameraVideo, "video");
    expect(l.cameraRetake, "retake");
    expect(l.seenIntroductions, "introductions");
    expect(l.donateAddress, "address");
    expect(l.donateCopy, "copy");
    expect(l.donateDone, "done");
    expect(l.donateTierSupporter, "supporter");
    expect(l.donateTierPatron, "patron");
    expect(l.donateTierGuardian, "guardian");
    expect(l.chatBlock, "block");
    expect(l.chatDecline, "decline");
    expect(l.chatAccept, "accept");
    expect(l.bridgesConnecting, "connecting");
    expect(l.restoreMade, "made");
    expect(l.restoreContacts, "contacts");
    expect(l.restoreMessages, "messages");
    expect(l.restoreAttachments, "attachments");
    expect(l.shieldBlock, "block");
    expect(l.shieldDelete, "delete");
    expect(l.shieldIgnore, "ignore");
    expect(l.profileIdentity, "identity");
    expect(l.avatarPickerShape, "Shape");
    expect(l.avatarPickerColour, "Colour");
    expect(l.avatarPickerTurn, "Turn");
    expect(l.transportStatus, "status");
    expect(l.transportBootstrap, "bootstrap");
    expect(l.transportNetwork, "network");
    expect(l.transportConnectivity, "connectivity");
    expect(l.transportRelays, "relays");
    expect(l.transportTraffic, "traffic");
    expect(l.transportContacts, "contacts");
    expect(l.transportKnown, "known");
    expect(l.transportListening, "listening");
    expect(l.transportMemory, "memory");
    expect(l.settingsConnected, "Connected");
    expect(l.settingsScreenshots, "Screenshots");
    expect(l.settingsBlocked2, "Blocked");
    expect(l.settingsAllowed, "Allowed");
    expect(l.settingsOn, "On");
    expect(l.settingsOff, "Off");
    expect(l.settingsNotifications, "Notifications");
    expect(l.settingsPrivacy, "Privacy");
    expect(l.settingsSecurity, "Security");
    expect(l.settingsBackup, "Backup");
    expect(l.settingsVoice, "Voice");
    expect(l.settingsAbout, "About");
    expect(l.wallpaperGradients, "gradients");
    expect(l.wallpaperPatterns, "patterns");
    expect(l.confirmSheetKeep, "keep");
    expect(l.confirmSheetSave, "save");
    expect(l.confirmSheetCancel, "cancel");
    expect(l.bridgesSaved(0), "0 bridges");
    expect(l.bridgesSaved(1), "1 bridge");
    expect(l.bridgesSaved(2), "2 bridges");
    expect(l.bridgesSaved(5), "5 bridges");
    expect(l.bridgesSavedSomeBad(0, 0), "0 accepted, 0 not understood");
    expect(l.bridgesSavedSomeBad(0, 1), "0 accepted, 1 not understood");
    expect(l.bridgesSavedSomeBad(0, 2), "0 accepted, 2 not understood");
    expect(l.bridgesSavedSomeBad(0, 5), "0 accepted, 5 not understood");
    expect(l.bridgesSavedSomeBad(1, 0), "1 accepted, 0 not understood");
    expect(l.bridgesSavedSomeBad(1, 1), "1 accepted, 1 not understood");
    expect(l.bridgesSavedSomeBad(1, 2), "1 accepted, 2 not understood");
    expect(l.bridgesSavedSomeBad(1, 5), "1 accepted, 5 not understood");
    expect(l.bridgesSavedSomeBad(2, 0), "2 accepted, 0 not understood");
    expect(l.bridgesSavedSomeBad(2, 1), "2 accepted, 1 not understood");
    expect(l.bridgesSavedSomeBad(2, 2), "2 accepted, 2 not understood");
    expect(l.bridgesSavedSomeBad(2, 5), "2 accepted, 5 not understood");
    expect(l.bridgesSavedSomeBad(5, 0), "5 accepted, 0 not understood");
    expect(l.bridgesSavedSomeBad(5, 1), "5 accepted, 1 not understood");
    expect(l.bridgesSavedSomeBad(5, 2), "5 accepted, 2 not understood");
    expect(l.bridgesSavedSomeBad(5, 5), "5 accepted, 5 not understood");
    expect(l.languageTitle, "Language");
    expect(l.languageMatchPhone, "Match phone");
    expect(l.languageMatchPhoneValue("<language>"), "Match phone (<language>)");
    expect(
      l.languageRedrawLine,
      "Kryfo redraws in the new language and opens on your chats.",
    );
    expect(l.languageButton("<language>"), "Language: <language>");
    expect(l.androidServiceTitle, "kryfo is on");
    expect(
      l.androidServiceText,
      "your encrypted line stays open so messages arrive",
    );
    expect(l.androidChannelName, "staying connected");
    expect(
      l.androidChannelDescription,
      "keeps kryfo connected so encrypted messages arrive while it is closed. turning this off stops delivery.",
    );
    expect(l.videoViewerPlay, "Play");
    expect(l.videoViewerPause, "Pause");
    expect(l.videoViewerPlayAgain, "Play again");
    expect(l.videoViewerCannotPlay, "This phone can't play this video here.");
    expect(l.videoViewerOpenElsewhere, "Open in another app");
  });
}
