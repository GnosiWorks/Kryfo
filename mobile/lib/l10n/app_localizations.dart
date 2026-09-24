import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// atmosphere.dart
  ///
  /// In en, this message translates to:
  /// **'none'**
  String get atmosphereNone;

  /// atmosphere.dart
  ///
  /// In en, this message translates to:
  /// **'ember'**
  String get atmosphereEmber;

  /// atmosphere.dart
  ///
  /// In en, this message translates to:
  /// **'dusk'**
  String get atmosphereDusk;

  /// atmosphere.dart
  ///
  /// In en, this message translates to:
  /// **'moss'**
  String get atmosphereMoss;

  /// atmosphere.dart
  ///
  /// In en, this message translates to:
  /// **'rose'**
  String get atmosphereRose;

  /// atmosphere.dart
  ///
  /// In en, this message translates to:
  /// **'dots'**
  String get atmosphereDots;

  /// atmosphere.dart
  ///
  /// In en, this message translates to:
  /// **'grid'**
  String get atmosphereGrid;

  /// atmosphere.dart
  ///
  /// In en, this message translates to:
  /// **'waves'**
  String get atmosphereWaves;

  /// atmosphere.dart
  ///
  /// In en, this message translates to:
  /// **'rain'**
  String get atmosphereRain;

  /// atmosphere.dart
  ///
  /// In en, this message translates to:
  /// **'Late night'**
  String get atmosphereLateNight;

  /// atmosphere.dart
  ///
  /// In en, this message translates to:
  /// **'Warm afternoon'**
  String get atmosphereWarmAfternoon;

  /// atmosphere.dart
  ///
  /// In en, this message translates to:
  /// **'snow'**
  String get atmosphereSnow;

  /// atmosphere.dart
  ///
  /// In en, this message translates to:
  /// **'desert'**
  String get atmosphereDesert;

  /// atmosphere.dart
  ///
  /// In en, this message translates to:
  /// **'paper'**
  String get atmospherePaper;

  /// backup.dart
  ///
  /// In en, this message translates to:
  /// **'That passphrase does not open this file'**
  String get backupThatPassphraseDoesNot;

  /// backup.dart
  ///
  /// In en, this message translates to:
  /// **'That file is not a kryfo backup'**
  String get backupThatFileIsNot;

  /// backup.dart
  ///
  /// In en, this message translates to:
  /// **'This backup is from a newer kryfo. Update the app, then try again'**
  String get backupThisBackupIsFrom;

  /// backup.dart
  ///
  /// In en, this message translates to:
  /// **'This file is damaged and cannot be read'**
  String get backupThisFileIsDamaged;

  /// backup.dart
  ///
  /// In en, this message translates to:
  /// **'could not make the key'**
  String get backupCouldNotMakeThe;

  /// contact_card.dart
  ///
  /// In en, this message translates to:
  /// **'Message me on'**
  String get contactCardMessageMeOn;

  /// contact_card.dart
  ///
  /// In en, this message translates to:
  /// **'Scan it, or type the three words into kryfo.\nThis card knows nothing about you beyond that.'**
  String get contactCardScanItOrType;

  /// contact_card.dart
  ///
  /// In en, this message translates to:
  /// **'Message me on kryfo · {haloId}'**
  String contactCardMessageMeOnKryfo(Object haloId);

  /// contact_status.dart
  ///
  /// In en, this message translates to:
  /// **'blocked'**
  String get contactStatusBlocked;

  /// contact_status.dart
  ///
  /// In en, this message translates to:
  /// **'Keys verified in person'**
  String get contactStatusKeysVerifiedInPerson;

  /// contact_status.dart
  ///
  /// In en, this message translates to:
  /// **'Waiting in requests'**
  String get contactStatusWaitingInRequests;

  /// contact_status.dart
  ///
  /// In en, this message translates to:
  /// **'Added by hand'**
  String get contactStatusAddedByHand;

  /// delivery_mode.dart
  ///
  /// In en, this message translates to:
  /// **'Always on'**
  String get deliveryModeAlwaysOn;

  /// delivery_mode.dart
  ///
  /// In en, this message translates to:
  /// **'Check-ins'**
  String get deliveryModeCheckIns;

  /// delivery_mode.dart
  ///
  /// In en, this message translates to:
  /// **'Through a helper app'**
  String get deliveryModeThroughAHelperApp;

  /// delivery_mode.dart
  ///
  /// In en, this message translates to:
  /// **'not yet'**
  String get deliveryModeNotYet;

  /// delivery_mode.dart
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get deliveryModeJustNow;

  /// delivery_mode.dart
  ///
  /// In en, this message translates to:
  /// **'{min} min ago'**
  String deliveryModeMinAgo(Object min);

  /// delivery_mode.dart
  ///
  /// In en, this message translates to:
  /// **'1 hour ago'**
  String get deliveryMode1HourAgo;

  /// delivery_mode.dart
  ///
  /// In en, this message translates to:
  /// **'{h} hours ago'**
  String deliveryModeHoursAgo(Object h);

  /// delivery_mode.dart
  ///
  /// In en, this message translates to:
  /// **'yesterday'**
  String get deliveryModeYesterday;

  /// delivery_mode.dart
  ///
  /// In en, this message translates to:
  /// **'{days} days ago'**
  String deliveryModeDaysAgo(Object days);

  /// delivery_mode.dart
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get deliveryModeConnected;

  /// delivery_mode.dart
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get deliveryModeConnecting;

  /// delivery_mode.dart
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get deliveryModeNotConnected;

  /// delivery_mode.dart
  ///
  /// In en, this message translates to:
  /// **'Checking now'**
  String get deliveryModeCheckingNow;

  /// delivery_mode.dart
  ///
  /// In en, this message translates to:
  /// **'last check-in {agoLine}'**
  String deliveryModeLastCheckIn(Object agoLine);

  /// delivery_mode.dart
  ///
  /// In en, this message translates to:
  /// **'no check-in yet'**
  String get deliveryModeNoCheckInYet;

  /// delivery_mode.dart
  ///
  /// In en, this message translates to:
  /// **'Connected now · {last}'**
  String deliveryModeConnectedNow(Object last);

  /// delivery_mode.dart
  ///
  /// In en, this message translates to:
  /// **'Connecting · {last}'**
  String deliveryModeConnecting2(Object last);

  /// delivery_mode.dart
  ///
  /// In en, this message translates to:
  /// **'No check-in yet'**
  String get deliveryModeNoCheckInYet2;

  /// delivery_mode.dart
  ///
  /// In en, this message translates to:
  /// **'Last checked {agoLine}'**
  String deliveryModeLastChecked(Object agoLine);

  /// delivery_mode.dart
  ///
  /// In en, this message translates to:
  /// **'a helper app'**
  String get deliveryModeAHelperApp;

  /// delivery_mode.dart
  ///
  /// In en, this message translates to:
  /// **'Woken by {who} · no wake-up yet'**
  String deliveryModeWokenByNoWake(Object who);

  /// delivery_mode.dart
  ///
  /// In en, this message translates to:
  /// **'Woken by {who} · last wake-up {agoLine}'**
  String deliveryModeWokenByLastWake(Object who, Object agoLine);

  /// intro_budget.dart
  ///
  /// In en, this message translates to:
  /// **'tomorrow'**
  String get introBudgetTomorrow;

  /// intro_budget.dart
  ///
  /// In en, this message translates to:
  /// **'in {d} days'**
  String introBudgetInDays(Object d);

  /// intro_budget.dart
  ///
  /// In en, this message translates to:
  /// **'in an hour'**
  String get introBudgetInAnHour;

  /// intro_budget.dart
  ///
  /// In en, this message translates to:
  /// **'in {h} hours'**
  String introBudgetInHours(Object h);

  /// intro_budget.dart
  ///
  /// In en, this message translates to:
  /// **'in a few minutes'**
  String get introBudgetInAFewMinutes;

  /// lock_state.dart
  ///
  /// In en, this message translates to:
  /// **'Unlock kryfo'**
  String get lockStateUnlockKryfo;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'HaloStartListener'**
  String get appHalostartlistener;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'HaloHandleCheck'**
  String get appHalohandlecheck;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'HaloHandleClaim'**
  String get appHalohandleclaim;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'HaloHandleRelease'**
  String get appHalohandlerelease;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'HaloTorPost'**
  String get appHalotorpost;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'HaloTorGetJSON'**
  String get appHalotorgetjson;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'HaloRoomSend'**
  String get appHaloroomsend;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'HaloRoomSendFirstContact'**
  String get appHaloroomsendfirstcontact;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'HaloRoomSubscribe'**
  String get appHaloroomsubscribe;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'HaloRoomSubscribeFirstContact'**
  String get appHaloroomsubscribefirstcontact;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'HaloRoomUnsubscribe'**
  String get appHaloroomunsubscribe;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'HaloNostrSend'**
  String get appHalonostrsend;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'HaloSendTo'**
  String get appHalosendto;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'room_priv TEXT'**
  String get appRoomPrivText;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'room_pub TEXT'**
  String get appRoomPubText;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'expires_at INTEGER'**
  String get appExpiresAtInteger;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'creator_pub TEXT'**
  String get appCreatorPubText;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'fc_pk TEXT'**
  String get appFcPkText;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'member_cap INTEGER'**
  String get appMemberCapInteger;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'room_seen INTEGER NOT NULL DEFAULT 0'**
  String get appRoomSeenIntegerNot;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'invalid uri'**
  String get appInvalidUri;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'Bundle error: {e}'**
  String appBundleError(Object e);

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'pair: v{parsed} invite, no first-contact addr'**
  String appPairVInviteNo(Object parsed);

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'pair: v{parsed} invite carries first-contact addr'**
  String appPairVInviteCarries(Object parsed);

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'Already saved: {parsed}'**
  String appAlreadySaved(Object parsed);

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'Added {parsed} · you can message them now'**
  String appAddedYouCanMessage(Object parsed);

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'Peer imported (v1): {parsed}'**
  String appPeerImportedV1(Object parsed);

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **' long window'**
  String get appLongWindow;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'{dropped} of {subs}, '**
  String appOf(Object dropped, Object subs);

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **' ({of}connect {c}s, {p} pages, {e} events)'**
  String appConnectSPagesEvents(Object of, Object c, Object p, Object e);

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'{host} {secs}s dropped{long}{why}'**
  String appSDropped(Object host, Object secs, Object long, Object why);

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'{host} {secs}s{long}{why}'**
  String appS(Object host, Object secs, Object long, Object why);

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'HaloTorStop'**
  String get appHalotorstop;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'HaloTorResume'**
  String get appHalotorresume;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'tor would not wake'**
  String get appTorWouldNotWake;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'tor not ready in 75s'**
  String get appTorNotReadyIn;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **', no relay began'**
  String get appNoRelayBegan;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **', capped'**
  String get appCapped;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'ok{tail}'**
  String appOk(Object tail);

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'{how}, {dateTime}s, by {why}'**
  String appSBy(Object how, Object dateTime, Object why);

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'group:{groupId}'**
  String appGroup(Object groupId);

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'An attachment could not be saved on this phone'**
  String get appAnAttachmentCouldNot;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'group'**
  String get appGroup2;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'Voice message'**
  String get appVoiceMessage;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'photo'**
  String get appPhoto;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'New request'**
  String get appNewRequest;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'Someone you have not added wrote to you'**
  String get appSomeoneYouHaveNot;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'_pending_back_pair_'**
  String get appPendingBackPair;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'Setting up your keys'**
  String get appSettingUpYourKeys;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'Opening your chats'**
  String get appOpeningYourChats;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'starting Tor'**
  String get appStartingTor;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'Timed messages are not clearing. Restart kryfo'**
  String get appTimedMessagesAreNot;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'voice message'**
  String get appVoiceMessage2;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'you: {body}'**
  String appYou(Object body);

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'send: no first-contact addr for {memberId} (v2 invite?)'**
  String appSendNoFirstContact(Object memberId);

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'send: racing onion + relay + first-contact for {memberId}'**
  String appSendRacingOnionRelay(Object memberId);

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'Firstcontact'**
  String get appFirstcontact;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'halo/1:'**
  String get appHalo1;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'This room has already expired'**
  String get appThisRoomHasAlready;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'You are already in this room'**
  String get appYouAreAlreadyIn;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'could not make a room key'**
  String get appCouldNotMakeA;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'Joined {linkName}, but your hello was held back'**
  String appJoinedButYourHello(Object linkName);

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'Joined {linkName}'**
  String appJoined(Object linkName);

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'Joined {linkName}, but the creator could not be reached yet'**
  String appJoinedButTheCreator(Object linkName);

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'booting...'**
  String get appBooting;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'Setting up your identity...'**
  String get appSettingUpYourIdentity;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'Add someone'**
  String get appAddSomeone;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'Scan their code, or paste what they gave you: a link, an @handle, or a room link.'**
  String get appScanTheirCodeOr;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'Scan their code'**
  String get appScanTheirCode;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'A kryfo link, a room link or @wren'**
  String get appAKryfoLinkA;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'Add them'**
  String get appAddThem;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'Every way to add someone'**
  String get appEveryWayToAdd;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'Show your code, send a link, claim a handle'**
  String get appShowYourCodeSend;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'Hello from the other side'**
  String get appHelloFromTheOther;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'Identity restored'**
  String get appIdentityRestored;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'Identity created'**
  String get appIdentityCreated;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'Starting tor (~30s)...'**
  String get appStartingTor30s;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'scan or import a peer first'**
  String get appScanOrImportA;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'Encrypting + sending (~30s)...'**
  String get appEncryptingSending30s;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'Tap start listening first'**
  String get appTapStartListeningFirst;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'Your kryfo'**
  String get appYourKryfo;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'Uri copied'**
  String get appUriCopied;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'Copy uri'**
  String get appCopyUri;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'Add a kryfo'**
  String get appAddAKryfo;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'Scan qr'**
  String get appScanQr;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'Pairing code'**
  String get appPairingCode;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'- or paste -'**
  String get appOrPaste;

  /// main.dart, media_progress.dart, screens/chat_screen.dart, screens/group_chat_screen.dart, screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get appImport;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'Dev'**
  String get appDev;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'Your kryfo:'**
  String get appYourKryfo2;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'Restored from disk'**
  String get appRestoredFromDisk;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'Start listening'**
  String get appStartListening;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'listening'**
  String get appListening;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'Show my qr'**
  String get appShowMyQr;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'Import peer'**
  String get appImportPeer;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'peer:'**
  String get appPeer;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'Message (will be encrypted)'**
  String get appMessageWillBeEncrypted;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'Encrypt + send'**
  String get appEncryptSend;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'status: {status}'**
  String appStatus(Object status);

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'Speed & privacy →'**
  String get appSpeedPrivacy;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'Getting messages →'**
  String get appGettingMessages;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'Disable app lock?'**
  String get appDisableAppLock;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'The pin will be removed. Anyone with your phone will see kryfo when they open it.'**
  String get appThePinWillBe;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get appDisable;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'App lock · on →'**
  String get appAppLockOn;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'App lock · off →'**
  String get appAppLockOff;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'Tor is off'**
  String get appTorIsOff;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'Connected · routed through 3 relays'**
  String get appConnectedRoutedThrough3;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'Ready to send · publishing your address'**
  String get appReadyToSendPublishing;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'Ready to send · finishing setup'**
  String get appReadyToSendFinishing;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'Connecting · {pct}%'**
  String appConnecting(Object pct);

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'Tor'**
  String get appTor;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'Tor is off. Turn it on to connect privately.'**
  String get appTorIsOffTurn;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'The first connection takes a minute or two while tor builds a private route. After that it is cached, so opening kryfo later is much faster.'**
  String get appTheFirstConnectionTakes;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'Relay and fast modes skip tor and are quicker. They are in settings, under speed & privacy, and each says what it costs.'**
  String get appRelayAndFastModes;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'Via relay'**
  String get appViaRelay;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'offline'**
  String get appOffline;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'Fast'**
  String get appFast;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'Tor off'**
  String get appTorOff;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'Tor ready'**
  String get appTorReady;

  /// main.dart
  ///
  /// In en, this message translates to:
  /// **'connecting'**
  String get appConnecting2;

  /// media_progress.dart
  ///
  /// In en, this message translates to:
  /// **'Sending · {v}% · keep the app open'**
  String mediaProgressSendingKeepTheApp(Object v);

  /// media_progress.dart
  ///
  /// In en, this message translates to:
  /// **'Paused · {count} of {count2} · waiting for the rest'**
  String mediaProgressPausedOfWaitingFor(Object count, Object count2);

  /// media_progress.dart
  ///
  /// In en, this message translates to:
  /// **'Receiving media · {v}%'**
  String mediaProgressReceivingMedia(Object v);

  /// media_progress.dart
  ///
  /// In en, this message translates to:
  /// **'Cancel sending'**
  String get mediaProgressCancelSending;

  /// meta/meta_reader.dart
  ///
  /// In en, this message translates to:
  /// **'ends before it should'**
  String get metaReaderEndsBeforeItShould;

  /// meta/meta_reader.dart
  ///
  /// In en, this message translates to:
  /// **'could not be read'**
  String get metaReaderCouldNotBeRead;

  /// meta/meta_reader.dart
  ///
  /// In en, this message translates to:
  /// **'exif that cannot be read'**
  String get metaReaderExifThatCannotBe;

  /// meta/meta_reader.dart
  ///
  /// In en, this message translates to:
  /// **'S'**
  String get metaReaderS;

  /// meta/meta_reader.dart
  ///
  /// In en, this message translates to:
  /// **'W'**
  String get metaReaderW;

  /// meta/meta_reader.dart
  ///
  /// In en, this message translates to:
  /// **'Photoshop 3.0'**
  String get metaReaderPhotoshop30;

  /// meta/meta_reader.dart
  ///
  /// In en, this message translates to:
  /// **'Adobe'**
  String get metaReaderAdobe;

  /// meta/meta_reader.dart
  ///
  /// In en, this message translates to:
  /// **'app{m}'**
  String metaReaderApp(Object m);

  /// meta/meta_reader.dart
  ///
  /// In en, this message translates to:
  /// **'samsung trailer'**
  String get metaReaderSamsungTrailer;

  /// meta/meta_reader.dart
  ///
  /// In en, this message translates to:
  /// **'chunk {type}'**
  String metaReaderChunk(Object type);

  /// meta/meta_reader.dart
  ///
  /// In en, this message translates to:
  /// **'exif flag set'**
  String get metaReaderExifFlagSet;

  /// meta/meta_reader.dart
  ///
  /// In en, this message translates to:
  /// **'xmp flag set'**
  String get metaReaderXmpFlagSet;

  /// meta/meta_reader.dart
  ///
  /// In en, this message translates to:
  /// **'app block {id}'**
  String metaReaderAppBlock(Object id);

  /// meta/meta_reader.dart
  ///
  /// In en, this message translates to:
  /// **'uuid box'**
  String get metaReaderUuidBox;

  /// meta/meta_reader.dart
  ///
  /// In en, this message translates to:
  /// **'{printable} box'**
  String metaReaderBox(Object printable);

  /// meta/meta_reader.dart
  ///
  /// In en, this message translates to:
  /// **'attached data'**
  String get metaReaderAttachedData;

  /// meta/meta_reader.dart
  ///
  /// In en, this message translates to:
  /// **'{printable} item'**
  String metaReaderItem(Object printable);

  /// miui_autostart.dart
  ///
  /// In en, this message translates to:
  /// **'Already allowed to run in the background'**
  String get miuiAutostartAlreadyAllowedToRun;

  /// miui_autostart.dart
  ///
  /// In en, this message translates to:
  /// **'Let kryfo run in the background'**
  String get miuiAutostartLetKryfoRunIn;

  /// miui_autostart.dart
  ///
  /// In en, this message translates to:
  /// **'Your phone pauses apps to save battery. Without an exception, kryfo cannot receive messages while it is closed.'**
  String get miuiAutostartYourPhonePausesApps;

  /// miui_autostart.dart
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get commonAllow;

  /// miui_autostart.dart
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get commonSkip;

  /// miui_autostart.dart
  ///
  /// In en, this message translates to:
  /// **'Xiaomi turns off background apps by default. Without autostart, kryfo cannot deliver messages when the app is closed. On the next screen, find kryfo in the list and turn the toggle on.'**
  String get miuiAutostartXiaomiTurnsOffBackground;

  /// miui_autostart.dart
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get miuiAutostartOpenSettings;

  /// miui_autostart.dart
  ///
  /// In en, this message translates to:
  /// **'couldn\'t open it. look for autostart in phone settings'**
  String get miuiAutostartCouldnTOpenIt;

  /// notifications.dart
  ///
  /// In en, this message translates to:
  /// **'New encrypted messages from your contacts'**
  String get notificationsNewEncryptedMessagesFrom;

  /// notifications.dart
  ///
  /// In en, this message translates to:
  /// **'new message'**
  String get notificationsNewMessage;

  /// notifications.dart
  ///
  /// In en, this message translates to:
  /// **'new encrypted messages from your contacts'**
  String get notificationsNewEncryptedMessagesFromYourContacts;

  /// notifications.dart
  ///
  /// In en, this message translates to:
  /// **'New message'**
  String get notificationsNewMessage2;

  /// notifications.dart
  ///
  /// In en, this message translates to:
  /// **'encrypted'**
  String get notificationsEncrypted;

  /// rooms.dart
  ///
  /// In en, this message translates to:
  /// **'24h'**
  String get rooms24h;

  /// rooms.dart
  ///
  /// In en, this message translates to:
  /// **'{inDays}d'**
  String roomsD(Object inDays);

  /// rooms.dart
  ///
  /// In en, this message translates to:
  /// **'{inHours}h'**
  String roomsH(Object inHours);

  /// rooms.dart
  ///
  /// In en, this message translates to:
  /// **'24 hours'**
  String get rooms24Hours;

  /// rooms.dart
  ///
  /// In en, this message translates to:
  /// **'{inDays} days'**
  String roomsDays(Object inDays);

  /// rooms.dart
  ///
  /// In en, this message translates to:
  /// **'an hour'**
  String get roomsAnHour;

  /// rooms.dart
  ///
  /// In en, this message translates to:
  /// **'about an hour'**
  String get roomsAboutAnHour;

  /// rooms.dart
  ///
  /// In en, this message translates to:
  /// **'{inHours} hours'**
  String roomsHours(Object inHours);

  /// rooms.dart
  ///
  /// In en, this message translates to:
  /// **'about {inHours} hours'**
  String roomsAboutHours(Object inHours);

  /// rooms.dart
  ///
  /// In en, this message translates to:
  /// **'{inMinutes} minutes'**
  String roomsMinutes(Object inMinutes);

  /// rooms.dart
  ///
  /// In en, this message translates to:
  /// **'a minute'**
  String get roomsAMinute;

  /// rooms.dart
  ///
  /// In en, this message translates to:
  /// **'expired'**
  String get roomsExpired;

  /// rooms.dart
  ///
  /// In en, this message translates to:
  /// **'{inDays}d {h}h'**
  String roomsDH(Object inDays, Object h);

  /// rooms.dart
  ///
  /// In en, this message translates to:
  /// **'{inHours}h {m}m'**
  String roomsHM(Object inHours, Object m);

  /// rooms.dart
  ///
  /// In en, this message translates to:
  /// **'{inMinutes}m'**
  String roomsM(Object inMinutes);

  /// scam_shield.dart
  ///
  /// In en, this message translates to:
  /// **'Looks like a scam'**
  String get scamShieldLooksLikeAScam;

  /// scam_shield.dart
  ///
  /// In en, this message translates to:
  /// **'This name matches'**
  String get scamShieldThisNameMatches;

  /// scam_shield.dart
  ///
  /// In en, this message translates to:
  /// **'Name matches your contact {shown}'**
  String scamShieldNameMatchesYourContact(Object shown);

  /// scam_shield.dart
  ///
  /// In en, this message translates to:
  /// **'same face as your contact {shown}'**
  String scamShieldSameFaceAsYour(Object shown);

  /// scam_shield.dart
  ///
  /// In en, this message translates to:
  /// **'Contains a crypto address'**
  String get scamShieldContainsACryptoAddress;

  /// scam_shield.dart
  ///
  /// In en, this message translates to:
  /// **'Mentions money and urgency together'**
  String get scamShieldMentionsMoneyAndUrgency;

  /// scam_shield.dart
  ///
  /// In en, this message translates to:
  /// **'Asks you to move to another app'**
  String get scamShieldAsksYouToMove;

  /// scam_shield.dart
  ///
  /// In en, this message translates to:
  /// **'Links to a lookalike of a well-known site'**
  String get scamShieldLinksToALookalike;

  /// scam_shield.dart
  ///
  /// In en, this message translates to:
  /// **'A long opener from someone with no history'**
  String get scamShieldALongOpenerFrom;

  /// scam_shield.dart
  ///
  /// In en, this message translates to:
  /// **'Asks for a code, seed phrase or recovery file'**
  String get scamShieldAsksForACode;

  /// scam_shield.dart
  ///
  /// In en, this message translates to:
  /// **'Also: {h}{h2}'**
  String scamShieldAlso(Object h, Object h2);

  /// screens/archived_screen.dart, screens/blocked_screen.dart, screens/chat_screen.dart, screens/clean_screen.dart, screens/getting_messages_screen.dart, screens/group_chat_screen.dart, screens/group_info_screen.dart, screens/key_verification_screen.dart, screens/modes_screen.dart, screens/new_group_screen.dart, screens/pair_code_screen.dart, screens/photo_knows_screen.dart, screens/scan_screen.dart, widgets/media_bubbles.dart, widgets/tool_parts.dart
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// screens/archived_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get archivedArchived;

  /// screens/archived_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Chat resting here. It stays quiet until they write, then comes back to the top.'**
  String get archivedChatRestingHereIt;

  /// screens/archived_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Chats resting here. They stay quiet until someone writes, then come back to the top.'**
  String get archivedChatsRestingHereThey;

  /// screens/archived_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Nothing archived'**
  String get archivedNothingArchived;

  /// screens/archived_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Archived chats are still end-to-end encrypted'**
  String get archivedArchivedChatsAreStill;

  /// screens/archived_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Unarchive'**
  String get archivedUnarchive;

  /// screens/avatar_picker_screen.dart
  ///
  /// In en, this message translates to:
  /// **'The people you message see this too'**
  String get avatarPickerThePeopleYouMessage;

  /// screens/avatar_picker_screen.dart
  ///
  /// In en, this message translates to:
  /// **'back to your initial'**
  String get avatarPickerBackToYourInitial;

  /// screens/avatar_picker_screen.dart
  ///
  /// In en, this message translates to:
  /// **'that one is yours'**
  String get avatarPickerThatOneIsYours;

  /// screens/avatar_picker_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Pick a face'**
  String get avatarPickerPickAFace;

  /// screens/avatar_picker_screen.dart, screens/chat_screen.dart, screens/contact_screen.dart, screens/group_chat_screen.dart, screens/notes_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// screens/backup_screen.dart
  ///
  /// In en, this message translates to:
  /// **'passphrase must be at least 6 characters'**
  String get backupPassphraseMustBeAt;

  /// screens/backup_screen.dart
  ///
  /// In en, this message translates to:
  /// **'passphrases don\'t match'**
  String get backupPassphrasesDonTMatch;

  /// screens/backup_screen.dart
  ///
  /// In en, this message translates to:
  /// **'kryfo-backup-{ts}.kryfo'**
  String backupKryfoBackupKryfo(Object ts);

  /// screens/backup_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Backup saved · keep the passphrase safe'**
  String get backupBackupSavedKeepThe;

  /// screens/backup_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Kryfo backup'**
  String get backupKryfoBackup;

  /// screens/backup_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Your encrypted kryfo backup. Keep both this file AND your passphrase safe - you need both to restore.'**
  String get backupYourEncryptedKryfoBackup;

  /// screens/backup_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Back up kryfo'**
  String get backupBackUpKryfo;

  /// screens/backup_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Back up'**
  String get backupBackUp;

  /// screens/backup_screen.dart
  ///
  /// In en, this message translates to:
  /// **'A copy to keep. This phone carries on as it is.'**
  String get backupACopyToKeep;

  /// screens/backup_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Move to another device'**
  String get backupMoveToAnotherDevice;

  /// screens/backup_screen.dart
  ///
  /// In en, this message translates to:
  /// **'The file takes this identity with it. Once it is made, this phone stops: nothing new arrives here, and nothing sent from here reaches anyone.'**
  String get backupTheFileTakesThis;

  /// screens/backup_screen.dart
  ///
  /// In en, this message translates to:
  /// **'One encrypted file: your identity, your contacts, every message, and every photo, voice note and file. Import it on the other device with the passphrase. Until you do, this phone can still be kept.'**
  String get backupOneEncryptedFileYour;

  /// screens/backup_screen.dart
  ///
  /// In en, this message translates to:
  /// **'One encrypted file: your identity, your contacts, every message, and every photo, voice note and file on this phone right now. Anything said after today is not in it, so make another when it matters. To restore you need the file and the passphrase, both.'**
  String get backupOneEncryptedFileYourIdentityYour;

  /// screens/backup_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Passphrase'**
  String get backupPassphrase;

  /// screens/backup_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Confirm passphrase'**
  String get backupConfirmPassphrase;

  /// screens/backup_screen.dart
  ///
  /// In en, this message translates to:
  /// **'writing… {progress}%'**
  String backupWriting(Object progress);

  /// screens/backup_screen.dart
  ///
  /// In en, this message translates to:
  /// **'creating…'**
  String get backupCreating;

  /// screens/backup_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Make the file and move'**
  String get backupMakeTheFileAnd;

  /// screens/backup_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Create backup'**
  String get backupCreateBackup;

  /// screens/blocked_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get blockedBlocked;

  /// screens/blocked_screen.dart
  ///
  /// In en, this message translates to:
  /// **'No one is blocked'**
  String get blockedNoOneIsBlocked;

  /// screens/blocked_screen.dart, screens/chat_screen.dart, screens/contact_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get commonUnblock;

  /// screens/bridges_screen.dart
  ///
  /// In en, this message translates to:
  /// **'That was not it. Here is another.'**
  String get bridgesThatWasNotIt;

  /// screens/bridges_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Got bridges · save to use them'**
  String get bridgesGotBridgesSaveTo;

  /// screens/bridges_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get bridgesConnected;

  /// screens/bridges_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Not through yet. Tor keeps trying'**
  String get bridgesNotThroughYetTor;

  /// screens/bridges_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Bridges'**
  String get bridgesBridges;

  /// screens/bridges_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Tor is blocked where you are?'**
  String get bridgesTorIsBlockedWhere;

  /// screens/bridges_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Bridges disguise your connection so it can get out. Pick one way in, save, and tor reconnects through it.'**
  String get bridgesBridgesDisguiseYourConnection;

  /// screens/bridges_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Bridges only change how tor connects, and you are not on onion mode right now. What you set here is saved, it just does nothing until you switch back.'**
  String get bridgesBridgesOnlyChangeHow;

  /// screens/bridges_screen.dart
  ///
  /// In en, this message translates to:
  /// **'From the tor project'**
  String get bridgesFromTheTorProject;

  /// screens/bridges_screen.dart
  ///
  /// In en, this message translates to:
  /// **'noise'**
  String get bridgesNoise;

  /// screens/bridges_screen.dart
  ///
  /// In en, this message translates to:
  /// **'good'**
  String get bridgesGood;

  /// screens/bridges_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Makes tor traffic look like nothing in particular. The best default for most blocked networks. Answers a captcha, then hands you a few lines.'**
  String get bridgesMakesTorTrafficLook;

  /// screens/bridges_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Private bridge'**
  String get bridgesPrivateBridge;

  /// screens/bridges_screen.dart
  ///
  /// In en, this message translates to:
  /// **'A line from a friend'**
  String get bridgesALineFromA;

  /// screens/bridges_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Whatever the line says'**
  String get bridgesWhateverTheLineSays;

  /// screens/bridges_screen.dart
  ///
  /// In en, this message translates to:
  /// **'depends'**
  String get bridgesDepends;

  /// screens/bridges_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Got a bridge line from someone you trust, or from bridges.torproject.org? Paste it here. Obfs4 lines only, kryfo does not speak the others yet.'**
  String get bridgesGotABridgeLine;

  /// screens/bridges_screen.dart
  ///
  /// In en, this message translates to:
  /// **'obfs4 1.2.3.4:443 FINGERPRINT cert=… iat-mode=0'**
  String get bridgesObfs4123;

  /// screens/bridges_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Paste from clipboard'**
  String get bridgesPasteFromClipboard;

  /// screens/bridges_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Use bridges'**
  String get bridgesUseBridges;

  /// screens/bridges_screen.dart
  ///
  /// In en, this message translates to:
  /// **'No lines yet'**
  String get bridgesNoLinesYet;

  /// screens/bridges_screen.dart
  ///
  /// In en, this message translates to:
  /// **'1 line saved'**
  String get bridges1LineSaved;

  /// screens/bridges_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{n} lines saved'**
  String bridgesLinesSaved(Object n);

  /// screens/bridges_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Restarting tor…'**
  String get bridgesRestartingTor;

  /// screens/bridges_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Finding a bridge… {elapsed}s'**
  String bridgesFindingABridgeS(Object elapsed);

  /// screens/bridges_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Still trying… {elapsed}s'**
  String bridgesStillTryingS(Object elapsed);

  /// screens/bridges_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Applying…'**
  String get bridgesApplying;

  /// screens/bridges_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Save and reconnect'**
  String get bridgesSaveAndReconnect;

  /// screens/bridges_screen.dart
  ///
  /// In en, this message translates to:
  /// **'What a bridge is'**
  String get bridgesWhatABridgeIs;

  /// screens/bridges_screen.dart
  ///
  /// In en, this message translates to:
  /// **'A tor entry point nobody has published, reached through a wrapper so the connection does not look like tor. The rest of the route is the usual three hops.'**
  String get bridgesATorEntryPoint;

  /// screens/bridges_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Looks like'**
  String get bridgesLooksLike;

  /// screens/bridges_screen.dart
  ///
  /// In en, this message translates to:
  /// **'speed'**
  String get bridgesSpeed;

  /// screens/bridges_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Get bridges'**
  String get bridgesGetBridges;

  /// screens/bridges_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Ask the tor project directly. You solve a puzzle so bots cannot drain the supply.'**
  String get bridgesAskTheTorProject;

  /// screens/bridges_screen.dart
  ///
  /// In en, this message translates to:
  /// **'type what you see. lowercase is fine.'**
  String get bridgesTypeWhatYouSee;

  /// screens/bridges_screen.dart
  ///
  /// In en, this message translates to:
  /// **'This one request does not go through tor - it cannot, since tor is what is not working. Whoever runs your network will see you contacting the tor project. If that alone is a problem where you are, get bridges somewhere else and paste them below.'**
  String get bridgesThisOneRequestDoes;

  /// screens/bridges_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Could not draw the puzzle'**
  String get bridgesCouldNotDrawThe;

  /// screens/bridges_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Answer'**
  String get bridgesAnswer;

  /// screens/bridges_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Asking…'**
  String get bridgesAsking;

  /// screens/bridges_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Request bridges'**
  String get bridgesRequestBridges;

  /// screens/bridges_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Different puzzle'**
  String get bridgesDifferentPuzzle;

  /// screens/camera_screen.dart
  ///
  /// In en, this message translates to:
  /// **'No camera on this phone'**
  String get cameraNoCameraOnThis;

  /// screens/camera_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Camera not available'**
  String get cameraCameraNotAvailable;

  /// screens/camera_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Camera permission is off · tap to try again'**
  String get cameraCameraPermissionIsOff;

  /// screens/camera_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Could not strip that photo, dropped it'**
  String get cameraCouldNotStripThat;

  /// screens/camera_screen.dart
  ///
  /// In en, this message translates to:
  /// **'No photo came out'**
  String get cameraNoPhotoCameOut;

  /// screens/camera_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Could not start recording'**
  String get cameraCouldNotStartRecording;

  /// screens/camera_screen.dart
  ///
  /// In en, this message translates to:
  /// **'The recording was lost'**
  String get cameraTheRecordingWasLost;

  /// screens/camera_screen.dart
  ///
  /// In en, this message translates to:
  /// **'kryfo_{ts}.jpg'**
  String cameraKryfoJpg(Object ts);

  /// screens/camera_screen.dart
  ///
  /// In en, this message translates to:
  /// **'kryfo_{ts}.mp4'**
  String cameraKryfoMp4(Object ts);

  /// screens/camera_screen.dart
  ///
  /// In en, this message translates to:
  /// **'A copy is in your photos'**
  String get cameraACopyIsIn;

  /// screens/camera_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Could not save a copy on this phone'**
  String get cameraCouldNotSaveA;

  /// screens/camera_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Too long for a message · 8 mb max'**
  String get cameraTooLongForA;

  /// screens/camera_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Never saved to your photos'**
  String get cameraNeverSavedToYour;

  /// screens/camera_screen.dart
  ///
  /// In en, this message translates to:
  /// **'No exif, never saved to your photos'**
  String get cameraNoExifNeverSaved;

  /// screens/camera_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Rec'**
  String get cameraRec;

  /// screens/camera_screen.dart
  ///
  /// In en, this message translates to:
  /// **'switch camera'**
  String get cameraSwitchCamera;

  /// screens/camera_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Clip · {secs}s · {mb} mb'**
  String cameraClipSMb(Object secs, Object mb);

  /// screens/camera_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Stop recording'**
  String get cameraStopRecording;

  /// screens/camera_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Start recording'**
  String get cameraStartRecording;

  /// screens/camera_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get cameraTakeAPhoto;

  /// screens/camera_screen.dart
  ///
  /// In en, this message translates to:
  /// **'keep a copy'**
  String get cameraKeepACopy;

  /// screens/camera_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Use this'**
  String get cameraUseThis;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{bytes} b'**
  String chatB(Object bytes);

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{bytes} kb'**
  String chatKb(Object bytes);

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{bytes} mb'**
  String chatMb(Object bytes);

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'FILE'**
  String get chatFile;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'you are offline · this sends itself when you reconnect'**
  String get chatYouAreOfflineThis;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'still connecting to tor · it\'ll go out on its own'**
  String get chatStillConnectingToTor;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'jan'**
  String get chatJan;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'feb'**
  String get chatFeb;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'mar'**
  String get chatMar;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'apr'**
  String get chatApr;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'may'**
  String get chatMay;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'jun'**
  String get chatJun;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'jul'**
  String get chatJul;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'aug'**
  String get chatAug;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'sep'**
  String get chatSep;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'oct'**
  String get chatOct;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'nov'**
  String get chatNov;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'dec'**
  String get chatDec;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String chatS(Object seconds);

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{seconds}m'**
  String chatM(Object seconds);

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{seconds}h'**
  String chatH(Object seconds);

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{seconds}d'**
  String chatD(Object seconds);

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'0s'**
  String get chat0s;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{h}h {m}m'**
  String chatHM(Object h, Object m);

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{m}m {s}s'**
  String chatMS(Object m, Object s);

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{s}s'**
  String chatS2(Object s);

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'New messages'**
  String get chatNewMessages;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Unsave'**
  String get chatUnsave;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get chatForward;

  /// screens/chat_screen.dart, screens/group_chat_screen.dart, screens/lock_file_screen.dart, screens/qr_screen.dart, screens/room_link_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get commonShare;

  /// screens/chat_screen.dart, screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get commonCopied;

  /// screens/chat_screen.dart, screens/group_chat_screen.dart, screens/my_kryfo_screen.dart, widgets/boot_failed.dart
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get commonCopy;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get chatUnpin;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get chatPin;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Stop sending'**
  String get chatStopSending;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Unsend'**
  String get chatUnsend;

  /// screens/chat_screen.dart, screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get chatYou;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Unsend message'**
  String get chatUnsendMessage;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'It disappears with no trace. This can\'t be undone.'**
  String get chatItDisappearsWithNo;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'This chat has {kMaxPins} pins already'**
  String chatThisChatHasPins(Object kMaxPins);

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Unpin this message?'**
  String get chatUnpinThisMessage;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Pin this message?'**
  String get chatPinThisMessage;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'It leaves the pinned list for both of you.'**
  String get chatItLeavesThePinned;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'It goes under the pin at the top of the chat, for both of you.'**
  String get chatItGoesUnderThe;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Pin it'**
  String get chatPinIt;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get chatNotNow;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Edit message'**
  String get chatEditMessage;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'30 seconds'**
  String get chat30Seconds;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'1 minute'**
  String get chat1Minute;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'5 minutes'**
  String get chat5Minutes;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'1 hour'**
  String get chat1Hour;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'24 hours'**
  String get chat24Hours;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Ghost timer'**
  String get chatGhostTimer;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'How long before sent messages burn?'**
  String get chatHowLongBeforeSent;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get chatCamera;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'No exif, never saved to your photos'**
  String get chatNoExifNeverSaved;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get chatGallery;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get chatVideo;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Gif from phone'**
  String get chatGifFromPhone;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get chatFile2;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'A few seconds'**
  String get chatAFewSeconds;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Under a minute'**
  String get chatUnderAMinute;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Roughly {mins} min'**
  String chatRoughlyMin(Object mins);

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{b} b'**
  String chatB2(Object b);

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{b} kb'**
  String chatKb2(Object b);

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{b} mb'**
  String chatMb2(Object b);

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Send this {what}?'**
  String chatSendThis(Object what);

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{humanBytes} · {wireEstimate} over tor'**
  String chatOverTor(Object humanBytes, Object wireEstimate);

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Big files go out in small encrypted pieces, so they take a while. Keep the app open and it keeps going.'**
  String get chatBigFilesGoOut;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Send it'**
  String get chatSendIt;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Could not read that file'**
  String get chatCouldNotReadThat;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'File too big · 8 mb max'**
  String get chatFileTooBig8;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Could not clean that video'**
  String get chatCouldNotCleanThat;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Could not clean that picture · send it as a photo'**
  String get chatCouldNotCleanThatPictureSend;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Gif too big · 8 mb max'**
  String get chatGifTooBig8;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Could not clean that gif'**
  String get chatCouldNotCleanThatGif;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Tor is not up yet · sending without'**
  String get chatTorIsNotUp;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach it · sending without'**
  String get chatCouldnTReachIt;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'No title came back · sending without'**
  String get chatNoTitleCameBack;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t fetch it · sending without'**
  String get chatCouldnTFetchIt;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'No signal session - re-pair'**
  String get chatNoSignalSessionRe;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'r{rowid}'**
  String chatR(Object rowid);

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Message unavailable'**
  String get chatMessageUnavailable;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'you'**
  String get chatYou2;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'them'**
  String get chatThem;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'voice message'**
  String get chatVoiceMessage;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'View contact'**
  String get chatViewContact;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Shared photos'**
  String get chatSharedPhotos;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Unmute notifications'**
  String get chatUnmuteNotifications;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Mute notifications'**
  String get chatMuteNotifications;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Archive chat'**
  String get chatArchiveChat;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Wallpaper'**
  String get chatWallpaper;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Clear conversation'**
  String get chatClearConversation;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Note on this contact'**
  String get chatNoteOnThisContact;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Pin to top'**
  String get chatPinToTop;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Block contact'**
  String get chatBlockContact;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Unpinned'**
  String get chatUnpinned;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Pinned to top'**
  String get chatPinnedToTop;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Just for you. Never sent, never leaves this phone.'**
  String get chatJustForYouNever;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'A quiet reminder…'**
  String get chatAQuietReminder;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Note saved'**
  String get chatNoteSaved;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Clear this conversation?'**
  String get chatClearThisConversation;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Every message here is erased from this phone. This only clears your copy - it does not touch their device.'**
  String get chatEveryMessageHereIs;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get chatClear;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Block this contact?'**
  String get chatBlockThisContact;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Their messages stop arriving and they disappear from your chats. They\'re never told. You can unblock anytime from settings.'**
  String get chatTheirMessagesStopArriving;

  /// screens/chat_screen.dart, screens/contact_screen.dart, screens/requests_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get commonBlock;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get chatSaved;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Removed from saved'**
  String get chatRemovedFromSaved;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Forward to'**
  String get chatForwardTo;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'No contacts to forward to'**
  String get chatNoContactsToForward;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'today'**
  String get chatToday;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'yesterday'**
  String get chatYesterday;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'This message can\'t be shown'**
  String get chatThisMessageCanT;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Jump to the newest'**
  String get chatJumpToTheNewest;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Building a private route · first connect is the slow one, later ones are quick. Anything you send now is queued and delivers itself.'**
  String get chatBuildingAPrivateRoute;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Looks safe · nothing suspicious in their first message'**
  String get chatLooksSafeNothingSuspicious;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'The next photo you send opens protected · they cannot screenshot it'**
  String get chatTheNextPhotoYou;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Photo protection off'**
  String get chatPhotoProtectionOff;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Accept to reply - they get one more message in until you do.'**
  String get chatAcceptToReplyThey;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{introducer} introduced you. Accept to reply.'**
  String chatIntroducedYouAcceptTo(Object introducer);

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{vouchNames} introduced you. Say hello - they got your card too.'**
  String chatIntroducedYouSayHello(Object vouchNames);

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Introduce to...'**
  String get chatIntroduceTo;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Accept them first'**
  String get chatAcceptThemFirst;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Message request'**
  String get chatMessageRequest;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'They need to accept before you can keep chatting.'**
  String get chatTheyNeedToAccept;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Waiting for them to accept your request'**
  String get chatWaitingForThemTo;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'You blocked this contact'**
  String get chatYouBlockedThisContact;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'face-{avatarSeed}'**
  String chatFace(Object avatarSeed);

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Supporter'**
  String get chatSupporter;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Encrypted · via relay'**
  String get chatEncryptedViaRelay;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Encrypted · direct'**
  String get chatEncryptedDirect;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Encrypted · over tor'**
  String get chatEncryptedOverTor;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Search this chat'**
  String get chatSearchThisChat;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Contact options'**
  String get chatContactOptions;

  /// screens/chat_screen.dart, screens/group_chat_screen.dart, widgets/media_bubbles.dart
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Find in conversation'**
  String get chatFindInConversation;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get chatNoMatches;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **' of {matchCount} {widget}'**
  String chatOf(Object matchCount, Object widget);

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Previous match'**
  String get chatPreviousMatch;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Next match'**
  String get chatNextMatch;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Photo unavailable'**
  String get chatPhotoUnavailable;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get chatDelivered;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Edited'**
  String get chatEdited;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Waiting for them to come online or add you back'**
  String get chatWaitingForThemToComeOnline;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Failed · tap to retry'**
  String get chatFailedTapToRetry;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Replying to {target}'**
  String chatReplyingTo(Object target);

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get chatReply;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Say hi.'**
  String get chatSayHi;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Just the two of you, end-to-end encrypted.'**
  String get chatJustTheTwoOf;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Mic permission needed'**
  String get chatMicPermissionNeeded;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{path}/vn_{dateTime}.wav'**
  String chatVnWav(Object path, Object dateTime);

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'The mic would not start. Try again'**
  String get chatTheMicWouldNot;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Release to cancel'**
  String get chatReleaseToCancel;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Voice hidden · slide to cancel'**
  String get chatVoiceHiddenSlideTo;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Slide to cancel'**
  String get chatSlideToCancel;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Ghost mode'**
  String get chatGhostMode;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Messages burn after {humanBurn}'**
  String chatMessagesBurnAfter(Object humanBurn);

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Timed messages'**
  String get chatTimedMessages;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Open the camera'**
  String get chatOpenTheCamera;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Attach a photo'**
  String get chatAttachAPhoto;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get chatMessage;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Disguise voice'**
  String get chatDisguiseVoice;

  /// screens/chat_screen.dart, screens/group_chat_screen.dart, widgets/media_bubbles.dart
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get commonSend;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'No photos in this chat yet'**
  String get chatNoPhotosInThis;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Send photo'**
  String get chatSendPhoto;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Add a caption…'**
  String get chatAddACaption;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Security code changed'**
  String get chatSecurityCodeChanged;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{peerName} may have reinstalled, or someone could be impersonating them. Compare safety numbers to be sure.'**
  String chatMayHaveReinstalledOr(Object peerName);

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Ok'**
  String get chatOk;

  /// screens/chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get chatVerify;

  /// screens/clean_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Kryfo can’t clean this kind of file yet.'**
  String get cleanKryfoCanTClean;

  /// screens/clean_screen.dart
  ///
  /// In en, this message translates to:
  /// **'This is a motion photo.'**
  String get cleanThisIsAMotion;

  /// screens/clean_screen.dart
  ///
  /// In en, this message translates to:
  /// **'This picture is too large to clean here.'**
  String get cleanThisPictureIsToo;

  /// screens/clean_screen.dart
  ///
  /// In en, this message translates to:
  /// **'This file is damaged or cut short.'**
  String get cleanThisFileIsDamaged;

  /// screens/clean_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Kryfo could not make this one clean.'**
  String get cleanKryfoCouldNotMake;

  /// screens/clean_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Not enough room on the phone.'**
  String get cleanNotEnoughRoomOn;

  /// screens/clean_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Kryfo could not open that file.'**
  String get cleanKryfoCouldNotOpen;

  /// screens/clean_screen.dart
  ///
  /// In en, this message translates to:
  /// **'It cleans JPEG, PNG, WebP, HEIC, AVIF, GIF, MP4 and MOV. Nothing was changed.'**
  String get cleanItCleansJpegPng;

  /// screens/clean_screen.dart
  ///
  /// In en, this message translates to:
  /// **'It holds a short video beside the picture, and Kryfo can’t clean that part yet. Turn motion off in your camera, or send a screenshot of it.'**
  String get cleanItHoldsAShort;

  /// screens/clean_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Pictures over 64 MB are not cleaned on the phone. Nothing was changed.'**
  String get cleanPicturesOver64Mb;

  /// screens/clean_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Kryfo could not read it to the end, so it won’t call it clean. No copy was made.'**
  String get cleanKryfoCouldNotRead;

  /// screens/clean_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Something inside is of a kind it does not know how to remove, so no copy was made.'**
  String get cleanSomethingInsideIsOf;

  /// screens/clean_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Free some space and try again. Nothing was changed.'**
  String get cleanFreeSomeSpaceAnd;

  /// screens/clean_screen.dart
  ///
  /// In en, this message translates to:
  /// **'The app that shared it may have taken it back. Try sharing it again.'**
  String get cleanTheAppThatShared;

  /// screens/clean_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{path}/tools_out'**
  String cleanToolsOut(Object path);

  /// screens/clean_screen.dart
  ///
  /// In en, this message translates to:
  /// **'No app on this phone took the file.'**
  String get cleanNoAppOnThis;

  /// screens/clean_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Could not save it. Check the phone has room.'**
  String get cleanCouldNotSaveIt;

  /// screens/clean_screen.dart
  ///
  /// In en, this message translates to:
  /// **'The original is gone. The clean copy stays.'**
  String get cleanTheOriginalIsGone;

  /// screens/clean_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Android would not delete it. Remove it from the gallery by hand.'**
  String get cleanAndroidWouldNotDelete;

  /// screens/clean_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Clean copy'**
  String get cleanCleanCopy;

  /// screens/clean_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Share clean copy'**
  String get cleanShareCleanCopy;

  /// screens/clean_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Save to gallery'**
  String get cleanSaveToGallery;

  /// screens/clean_screen.dart, screens/lock_file_screen.dart, screens/open_locked_screen.dart, screens/photo_knows_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get commonStop;

  /// screens/clean_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Reading the file'**
  String get cleanReadingTheFile;

  /// screens/clean_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Cleaning'**
  String get cleanCleaning;

  /// screens/clean_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{prettySize} of {prettySize2}'**
  String cleanOf(Object prettySize, Object prettySize2);

  /// screens/clean_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Everything stays on this phone.'**
  String get cleanEverythingStaysOnThis;

  /// screens/clean_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Already clean.'**
  String get cleanAlreadyClean;

  /// screens/clean_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Clean.'**
  String get cleanClean;

  /// screens/clean_screen.dart
  ///
  /// In en, this message translates to:
  /// **'There was nothing to find.'**
  String get cleanThereWasNothingTo;

  /// screens/clean_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Nothing left to find.'**
  String get cleanNothingLeftToFind;

  /// screens/clean_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Same video, same quality'**
  String get cleanSameVideoSameQuality;

  /// screens/clean_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Same picture, same quality'**
  String get cleanSamePictureSameQuality;

  /// screens/clean_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{label}, removed'**
  String cleanRemoved(Object label);

  /// screens/clean_screen.dart
  ///
  /// In en, this message translates to:
  /// **'REMOVED'**
  String get cleanRemoved2;

  /// screens/clean_screen.dart
  ///
  /// In en, this message translates to:
  /// **'with the location inside. Anyone who gets that one gets your street.'**
  String get cleanWithTheLocationInside;

  /// screens/clean_screen.dart
  ///
  /// In en, this message translates to:
  /// **'with everything it knew still inside.'**
  String get cleanWithEverythingItKnew;

  /// screens/clean_screen.dart
  ///
  /// In en, this message translates to:
  /// **'ORIGINAL'**
  String get cleanOriginal;

  /// screens/clean_screen.dart
  ///
  /// In en, this message translates to:
  /// **'CLEAN'**
  String get cleanClean2;

  /// screens/clean_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Saved to your gallery.'**
  String get cleanSavedToYourGallery;

  /// screens/clean_screen.dart
  ///
  /// In en, this message translates to:
  /// **'The original is still there too, {what}'**
  String cleanTheOriginalIsStill(Object what);

  /// screens/clean_screen.dart
  ///
  /// In en, this message translates to:
  /// **'The original is still where it was, {what} Kryfo can’t remove it from here, so delete it in the app it came from.'**
  String cleanTheOriginalIsStillWhereIt(Object what);

  /// screens/clean_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Delete the original'**
  String get cleanDeleteTheOriginal;

  /// screens/clean_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Keep both'**
  String get cleanKeepBoth;

  /// screens/clean_screen.dart, screens/open_locked_screen.dart, screens/photo_knows_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// screens/clean_screen.dart
  ///
  /// In en, this message translates to:
  /// **'ANDROID WILL ASK YOU TO CONFIRM'**
  String get cleanAndroidWillAskYou;

  /// screens/contact_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Your name for them'**
  String get contactYourNameForThem;

  /// screens/contact_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Stays on this phone. They never see it.'**
  String get contactStaysOnThisPhone;

  /// screens/contact_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get contactClear;

  /// screens/contact_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get contactMessage;

  /// screens/contact_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Keys verified'**
  String get contactKeysVerified;

  /// screens/contact_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Verify keys'**
  String get contactVerifyKeys;

  /// screens/contact_screen.dart
  ///
  /// In en, this message translates to:
  /// **'face-{avatarSeed}'**
  String contactFace(Object avatarSeed);

  /// screens/contact_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Vouches'**
  String get contactVouches;

  /// screens/contact_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get contactUnmute;

  /// screens/contact_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get contactMute;

  /// screens/contact_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get contactUnpin;

  /// screens/contact_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Pin to top'**
  String get contactPinToTop;

  /// screens/contact_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get contactArchive;

  /// screens/contact_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Out of the list until they write again'**
  String get contactOutOfTheList;

  /// screens/contact_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Block {name}?'**
  String contactBlock(Object name);

  /// screens/contact_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Their messages stop arriving. They are not told.'**
  String get contactTheirMessagesStopArriving;

  /// screens/contact_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Delete chat'**
  String get contactDeleteChat;

  /// screens/contact_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Messages and contact, gone from this phone'**
  String get contactMessagesAndContactGone;

  /// screens/contact_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Delete this chat?'**
  String get contactDeleteThisChat;

  /// screens/contact_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Every message and the contact, gone from this phone. Nothing is sent to them.'**
  String get contactEveryMessageAndThe;

  /// screens/contact_screen.dart, screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// screens/contact_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get contactDeleted;

  /// screens/contact_screen.dart
  ///
  /// In en, this message translates to:
  /// **'today'**
  String get contactToday;

  /// screens/contact_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{inDays}d'**
  String contactD(Object inDays);

  /// screens/contact_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{d}mo'**
  String contactMo(Object d);

  /// screens/contact_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{d}y'**
  String contactY(Object d);

  /// screens/contact_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get contactVerified;

  /// screens/contact_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Chatting'**
  String get contactChatting;

  /// screens/contact_screen.dart
  ///
  /// In en, this message translates to:
  /// **'nothing shared yet'**
  String get contactNothingSharedYet;

  /// screens/contact_screen.dart
  ///
  /// In en, this message translates to:
  /// **'shared media · {count}'**
  String contactSharedMedia(Object count);

  /// screens/donate_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Bitcoin'**
  String get donateBitcoin;

  /// screens/donate_screen.dart
  ///
  /// In en, this message translates to:
  /// **'₿'**
  String get donateText;

  /// screens/donate_screen.dart
  ///
  /// In en, this message translates to:
  /// **'badge unlocks'**
  String get donateBadgeUnlocks;

  /// screens/donate_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Monero'**
  String get donateMonero;

  /// screens/donate_screen.dart
  ///
  /// In en, this message translates to:
  /// **'manual · no badge'**
  String get donateManualNoBadge;

  /// screens/donate_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Solana'**
  String get donateSolana;

  /// screens/donate_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Ethereum'**
  String get donateEthereum;

  /// screens/donate_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Ξ'**
  String get donateText2;

  /// screens/donate_screen.dart
  ///
  /// In en, this message translates to:
  /// **'4ApyZS72ZYCG3z8rtwwX6JgdjSdAcphHSFRxiKrL5yLnYYz8fvXQayWMyw79AxFoQ7BXLfzEExk5f7Z2xPdEPWyRBXtVwiD'**
  String
  get donate4apyzs72zycg3z8rtwwx6jgdjsdacphhsfrxikrl5ylnyyz8fvxqaywmyw79axfo;

  /// screens/donate_screen.dart
  ///
  /// In en, this message translates to:
  /// **'DrxaQPM8wD63EErdGN9GrazGVnxwiCB9Pc6RYR3v2x4a'**
  String get donateDrxaqpm8wd63eerdgn9grazgvnxwicb9pc6ryr3v2x4a;

  /// screens/donate_screen.dart
  ///
  /// In en, this message translates to:
  /// **'0x55014AF792d54E4350b7f4bfc7be7D62EbbCfE43'**
  String get donate0x55014af792d54e4350b7f4bfc7be7d62ebbcfe43;

  /// screens/donate_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Your earlier bitcoin payment was seen · {tierName} badge unlocked'**
  String donateYourEarlierBitcoinPayment(Object tierName);

  /// screens/donate_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get donateSupport;

  /// screens/donate_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Keep kryfo '**
  String get donateKeepKryfo;

  /// screens/donate_screen.dart
  ///
  /// In en, this message translates to:
  /// **'independent'**
  String get donateIndependent;

  /// screens/donate_screen.dart
  ///
  /// In en, this message translates to:
  /// **'No ads, no investors, nothing to sell. It runs on what backers give.'**
  String get donateNoAdsNoInvestors;

  /// screens/donate_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Back it anonymously. Badge opt-in.\n'**
  String get donateBackItAnonymouslyBadge;

  /// screens/donate_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Privacy is never behind a paywall.'**
  String get donatePrivacyIsNeverBehind;

  /// screens/donate_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{coinName} address · check it against your wallet'**
  String donateAddressCheckItAgainst(Object coinName);

  /// screens/donate_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Address copied · clears in 60s'**
  String get donateAddressCopiedClearsIn;

  /// screens/donate_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Copy address'**
  String get donateCopyAddress;

  /// screens/donate_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Bitcoin is verified by our own node, so your badge unlocks by itself once the payment lands.'**
  String get donateBitcoinIsVerifiedBy;

  /// screens/donate_screen.dart
  ///
  /// In en, this message translates to:
  /// **'we can\'t verify this chain without asking an outside service about you, so we don\'t. send it if you like. it won\'t unlock a badge.'**
  String get donateWeCanTVerify;

  /// screens/donate_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Bitcoin badges need onion mode'**
  String get donateBitcoinBadgesNeedOnion;

  /// screens/donate_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Switch to onion'**
  String get donateSwitchToOnion;

  /// screens/donate_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Pay with bitcoin  →'**
  String get donatePayWithBitcoin;

  /// screens/donate_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Badges start at \$20'**
  String get donateBadgesStartAt20;

  /// screens/donate_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Reaching the payment service over tor…'**
  String get donateReachingThePaymentService;

  /// screens/donate_screen.dart
  ///
  /// In en, this message translates to:
  /// **'This can take up to a minute'**
  String get donateThisCanTakeUp;

  /// screens/donate_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{waited}s · this can take up to a minute'**
  String donateSThisCanTake(Object waited);

  /// screens/donate_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Use the address instead'**
  String get donateUseTheAddressInstead;

  /// screens/donate_screen.dart
  ///
  /// In en, this message translates to:
  /// **'The payment service is an onion, and only onion mode can reach it. Nothing was sent.'**
  String get donateThePaymentServiceIs;

  /// screens/donate_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Tor was slow to reach the payment service. You can donate to the address below - your badge just won\'t unlock automatically. Try again later for the badge.'**
  String get donateTorWasSlowTo;

  /// screens/donate_screen.dart
  ///
  /// In en, this message translates to:
  /// **'The payment service is having trouble right now. You can still donate to the address below - your badge just won\'t unlock automatically. Try again later for the badge.'**
  String get donateThePaymentServiceIsHavingTrouble;

  /// screens/donate_screen.dart, widgets/boot_failed.dart
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get commonTryAgain;

  /// screens/donate_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{btc} BTC'**
  String donateBtc(Object btc);

  /// screens/donate_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Send exactly this amount · expires in {fmtLeft}'**
  String donateSendExactlyThisAmount(Object fmtLeft);

  /// screens/donate_screen.dart
  ///
  /// In en, this message translates to:
  /// **'open wallet'**
  String get donateOpenWallet;

  /// screens/donate_screen.dart
  ///
  /// In en, this message translates to:
  /// **'This screen updates itself the moment your payment is seen.\nKeep it open - nothing is stored, nothing identifies you.'**
  String get donateThisScreenUpdatesItself;

  /// screens/donate_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Watching the chain for your payment'**
  String get donateWatchingTheChainFor;

  /// screens/donate_screen.dart
  ///
  /// In en, this message translates to:
  /// **'This invoice expired'**
  String get donateThisInvoiceExpired;

  /// screens/donate_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Invoices time out. If you already sent the payment, keep this open: we ask the service again every minute for a while, and the next time you open support. Start a fresh one whenever you like.'**
  String get donateInvoicesTimeOutIf;

  /// screens/donate_screen.dart
  ///
  /// In en, this message translates to:
  /// **'New invoice'**
  String get donateNewInvoice;

  /// screens/donate_screen.dart
  ///
  /// In en, this message translates to:
  /// **'I paid, check again'**
  String get donateIPaidCheckAgain;

  /// screens/donate_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Payment confirmed'**
  String get donatePaymentConfirmed;

  /// screens/donate_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Thank you for keeping kryfo independent.'**
  String get donateThankYouForKeeping;

  /// screens/donate_screen.dart
  ///
  /// In en, this message translates to:
  /// **'verified on-chain - you\'re a {tierName} now. No one can take that off you.'**
  String donateVerifiedOnChainYou(Object tierName);

  /// screens/donate_screen.dart
  ///
  /// In en, this message translates to:
  /// **'wear my badge'**
  String get donateWearMyBadge;

  /// screens/donate_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Just glad to help'**
  String get donateJustGladToHelp;

  /// screens/getting_messages_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Getting messages'**
  String get gettingMessagesGettingMessages;

  /// screens/getting_messages_screen.dart
  ///
  /// In en, this message translates to:
  /// **'How new messages reach this phone. You can change it whenever you like.'**
  String get gettingMessagesHowNewMessagesReach;

  /// screens/getting_messages_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Always on'**
  String get gettingMessagesAlwaysOn;

  /// screens/getting_messages_screen.dart
  ///
  /// In en, this message translates to:
  /// **'most private'**
  String get gettingMessagesMostPrivate;

  /// screens/getting_messages_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Messages arrive instantly. Nothing leaves Tor. Uses the most battery.'**
  String get gettingMessagesMessagesArriveInstantlyNothing;

  /// screens/getting_messages_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Check-ins'**
  String get gettingMessagesCheckIns;

  /// screens/getting_messages_screen.dart
  ///
  /// In en, this message translates to:
  /// **'lightest'**
  String get gettingMessagesLightest;

  /// screens/getting_messages_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Kryfo looks for messages every 15 minutes. Easy on battery, but messages can be late.'**
  String get gettingMessagesKryfoLooksForMessages;

  /// screens/getting_messages_screen.dart
  ///
  /// In en, this message translates to:
  /// **'On the lock screen'**
  String get gettingMessagesOnTheLockScreen;

  /// screens/getting_messages_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Hide message preview'**
  String get gettingMessagesHideMessagePreview;

  /// screens/getting_messages_screen.dart
  ///
  /// In en, this message translates to:
  /// **'A generic alert, with no sender and no message text'**
  String get gettingMessagesAGenericAlertWith;

  /// screens/getting_messages_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Shows message text in notifications, even while Kryfo is locked.'**
  String get gettingMessagesShowsMessageTextIn;

  /// screens/getting_messages_screen.dart
  ///
  /// In en, this message translates to:
  /// **'When the phone sits still, Android spaces check-ins further apart. The line above shows the real last one. While Kryfo is open it stays connected.'**
  String get gettingMessagesWhenThePhoneSits;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'group:{groupId}'**
  String groupChatGroup(Object groupId);

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Jump to the newest'**
  String get groupChatJumpToTheNewest;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Blocked everywhere'**
  String get groupChatBlockedEverywhere;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'you'**
  String get groupChatYou;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'voice message'**
  String get groupChatVoiceMessage;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Message unavailable'**
  String get groupChatMessageUnavailable;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'r{rowid}'**
  String groupChatR(Object rowid);

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Tor is not up yet · sending without'**
  String get groupChatTorIsNotUp;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'couldn\'t reach it · sending without'**
  String get groupChatCouldnTReachIt;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'No title came back · sending without'**
  String get groupChatNoTitleCameBack;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'couldn\'t fetch it · sending without'**
  String get groupChatCouldnTFetchIt;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get groupChatCamera;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get groupChatGallery;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get groupChatVideo;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Gif from phone'**
  String get groupChatGifFromPhone;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get groupChatFile;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Could not read that file'**
  String get groupChatCouldNotReadThat;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Gif too big · 8 mb max'**
  String get groupChatGifTooBig8;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Could not clean that gif'**
  String get groupChatCouldNotCleanThat;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'File too big · 8 mb max'**
  String get groupChatFileTooBig8;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Could not clean that video'**
  String get groupChatCouldNotCleanThatVideo;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Could not clean that picture · send it as a photo'**
  String get groupChatCouldNotCleanThatPictureSend;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'30 seconds'**
  String get groupChat30Seconds;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'1 minute'**
  String get groupChat1Minute;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'5 minutes'**
  String get groupChat5Minutes;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'1 hour'**
  String get groupChat1Hour;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'24 hours'**
  String get groupChat24Hours;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Burn timer'**
  String get groupChatBurnTimer;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'New messages disappear after this'**
  String get groupChatNewMessagesDisappearAfter;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'today'**
  String get groupChatToday;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'yesterday'**
  String get groupChatYesterday;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'jan'**
  String get groupChatJan;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'feb'**
  String get groupChatFeb;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'mar'**
  String get groupChatMar;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'apr'**
  String get groupChatApr;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'may'**
  String get groupChatMay;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'jun'**
  String get groupChatJun;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'jul'**
  String get groupChatJul;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'aug'**
  String get groupChatAug;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'sep'**
  String get groupChatSep;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'oct'**
  String get groupChatOct;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'nov'**
  String get groupChatNov;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'dec'**
  String get groupChatDec;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get groupChatYou2;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'This chat has {kMaxPins} pins already'**
  String groupChatThisChatHasPins(Object kMaxPins);

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Unpin this message?'**
  String get groupChatUnpinThisMessage;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Pin this message?'**
  String get groupChatPinThisMessage;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'It leaves the pinned list for everyone here.'**
  String get groupChatItLeavesThePinned;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'It goes under the pin at the top of the chat, for everyone here.'**
  String get groupChatItGoesUnderThe;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get groupChatUnpin;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Pin it'**
  String get groupChatPinIt;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get groupChatNotNow;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get groupChatSaved;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Removed from saved'**
  String get groupChatRemovedFromSaved;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Forward to'**
  String get groupChatForwardTo;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'No contacts to forward to'**
  String get groupChatNoContactsToForward;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Edit message'**
  String get groupChatEditMessage;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Unsend message'**
  String get groupChatUnsendMessage;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'It disappears with no trace. This can\'t be undone.'**
  String get groupChatItDisappearsWithNo;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Unsend'**
  String get groupChatUnsend;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'This room and everything in it disappears in {expiryWords}'**
  String groupChatThisRoomAndEverything(Object expiryWords);

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Ghost mode on · burns in {fmtBurn}'**
  String groupChatGhostModeOnBurns(Object fmtBurn);

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Group created. Say hi.'**
  String get groupChatGroupCreatedSayHi;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'No messages yet.'**
  String get groupChatNoMessagesYet;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'This message can\'t be shown'**
  String get groupChatThisMessageCanT;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{s}s'**
  String groupChatS(Object s);

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{s}m'**
  String groupChatM(Object s);

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{s}h'**
  String groupChatH(Object s);

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{s}d'**
  String groupChatD(Object s);

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'group-{groupId}'**
  String groupChatGroup2(Object groupId);

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **' · {memberCount} here'**
  String groupChatHere(Object memberCount);

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{memberCount} members'**
  String groupChatMembers(Object memberCount);

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Search this chat'**
  String get groupChatSearchThisChat;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Replying to {target}'**
  String groupChatReplyingTo(Object target);

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Timed messages'**
  String get groupChatTimedMessages;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Open the camera'**
  String get groupChatOpenTheCamera;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Attach a photo'**
  String get groupChatAttachAPhoto;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get groupChatMessage;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Disguise voice'**
  String get groupChatDisguiseVoice;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Supporter'**
  String get groupChatSupporter;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Edited '**
  String get groupChatEdited;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'! tap to retry'**
  String get groupChatTapToRetry;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'0s'**
  String get groupChat0s;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get groupChatReply;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get groupChatPin;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Unsave'**
  String get groupChatUnsave;

  /// screens/group_chat_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get groupChatForward;

  /// screens/group_info_screen.dart
  ///
  /// In en, this message translates to:
  /// **'group'**
  String get groupInfoGroup;

  /// screens/group_info_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Rename group'**
  String get groupInfoRenameGroup;

  /// screens/group_info_screen.dart
  ///
  /// In en, this message translates to:
  /// **'rename'**
  String get groupInfoRename;

  /// screens/group_info_screen.dart
  ///
  /// In en, this message translates to:
  /// **'No contacts to add'**
  String get groupInfoNoContactsToAdd;

  /// screens/group_info_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Could not add'**
  String get groupInfoCouldNotAdd;

  /// screens/group_info_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Remove {haloId}?'**
  String groupInfoRemove(Object haloId);

  /// screens/group_info_screen.dart
  ///
  /// In en, this message translates to:
  /// **'They will stop receiving messages from this group.'**
  String get groupInfoTheyWillStopReceiving;

  /// screens/group_info_screen.dart, screens/pins_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get commonRemove;

  /// screens/group_info_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Clear this conversation?'**
  String get groupInfoClearThisConversation;

  /// screens/group_info_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Every message here is erased from this phone. This only clears your copy, other members keep theirs.'**
  String get groupInfoEveryMessageHereIs;

  /// screens/group_info_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get groupInfoClear;

  /// screens/group_info_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Conversation cleared'**
  String get groupInfoConversationCleared;

  /// screens/group_info_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Leave room?'**
  String get groupInfoLeaveRoom;

  /// screens/group_info_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Leave group?'**
  String get groupInfoLeaveGroup;

  /// screens/group_info_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Everything in it is wiped from this phone now, and the key you used here is gone for good.'**
  String get groupInfoEverythingInItIs;

  /// screens/group_info_screen.dart
  ///
  /// In en, this message translates to:
  /// **'You will stop receiving messages and other members will see you leave.'**
  String get groupInfoYouWillStopReceiving;

  /// screens/group_info_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get groupInfoLeave;

  /// screens/group_info_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Group info'**
  String get groupInfoGroupInfo;

  /// screens/group_info_screen.dart
  ///
  /// In en, this message translates to:
  /// **'1 member'**
  String get groupInfo1Member;

  /// screens/group_info_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{membersLength} members'**
  String groupInfoMembers(Object membersLength);

  /// screens/group_info_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get groupInfoAdmin;

  /// screens/group_info_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get groupInfoMembers2;

  /// screens/group_info_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Invite'**
  String get groupInfoInvite;

  /// screens/group_info_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// screens/group_info_screen.dart
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get groupInfoYou;

  /// screens/group_info_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Remove from group'**
  String get groupInfoRemoveFromGroup;

  /// screens/group_info_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Wallpaper'**
  String get groupInfoWallpaper;

  /// screens/group_info_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Shared media'**
  String get groupInfoSharedMedia;

  /// screens/group_info_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Clear conversation'**
  String get groupInfoClearConversation;

  /// screens/group_info_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Leave room'**
  String get groupInfoLeaveRoom2;

  /// screens/group_info_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Leave group'**
  String get groupInfoLeaveGroup2;

  /// screens/group_info_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Add members'**
  String get groupInfoAddMembers;

  /// screens/group_info_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Add {pickedLength}'**
  String groupInfoAdd(Object pickedLength);

  /// screens/handle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'You are @{h}'**
  String handleYouAre(Object h);

  /// screens/handle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Handle deleted · the page is gone'**
  String get handleHandleDeletedThePage;

  /// screens/handle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Public handle'**
  String get handlePublicHandle;

  /// screens/handle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Optional. Your three words keep working either way.'**
  String get handleOptionalYourThreeWords;

  /// screens/handle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'wren'**
  String get handleWren;

  /// screens/handle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'A line about you · optional'**
  String get handleALineAboutYou;

  /// screens/handle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Claiming…'**
  String get handleClaiming;

  /// screens/handle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Claim this handle'**
  String get handleClaimThisHandle;

  /// screens/handle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Anyone with this link can start a private chat with you. It carries your invite and nothing else.'**
  String get handleAnyoneWithThisLink;

  /// screens/handle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get handleLinkCopied;

  /// screens/handle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Delete this handle'**
  String get handleDeleteThisHandle;

  /// screens/handle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get handleChecking;

  /// screens/handle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'✓ available'**
  String get handleAvailable;

  /// screens/handle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'already taken'**
  String get handleAlreadyTaken;

  /// screens/handle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'What a handle does'**
  String get handleWhatAHandleDoes;

  /// screens/handle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Anyone who knows it can ask to message you, which is the point of having one. The page holds your invite and the line you wrote, nothing else, and keeps no record of who reads it. You can delete it whenever you like.'**
  String get handleAnyoneWhoKnowsIt;

  /// screens/handle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'@{handle} is not yours on this phone'**
  String handleIsNotYoursOn(Object handle);

  /// screens/handle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'The registry holds it under a different key, most likely an identity this phone had before a restore. People who add @{handle} are not reaching you. It cannot be released or updated from here. Pick another name.'**
  String handleTheRegistryHoldsIt(Object handle);

  /// screens/handle_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Forget it on this phone'**
  String get handleForgetItOnThis;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get homeMonday;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get homeTuesday;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get homeWednesday;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get homeThursday;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get homeFriday;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get homeSaturday;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get homeSunday;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'January'**
  String get homeJanuary;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'February'**
  String get homeFebruary;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'March'**
  String get homeMarch;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'April'**
  String get homeApril;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get homeMay;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'June'**
  String get homeJune;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'July'**
  String get homeJuly;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'August'**
  String get homeAugust;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'September'**
  String get homeSeptember;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'October'**
  String get homeOctober;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'November'**
  String get homeNovember;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'December'**
  String get homeDecember;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Add a contact'**
  String get homeAddAContact;

  /// screens/home_screen.dart, screens/profile_screen.dart, screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get commonSettings;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Your kryfo'**
  String get homeYourKryfo;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'an hour'**
  String get homeAnHour;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{h} hours'**
  String homeHours(Object h);

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{inMinutes} minutes'**
  String homeMinutes(Object inMinutes);

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Kryfo is offline'**
  String get homeKryfoIsOffline;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Tor has not been able to connect for {howLong}. Nothing can arrive or leave until it does.'**
  String homeTorHasNotBeen(Object howLong);

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Reconnecting'**
  String get homeReconnecting;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get homeReconnect;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'What is wrong'**
  String get homeWhatIsWrong;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Kryfo will check in every 15 minutes'**
  String get homeKryfoWillCheckIn;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Your phone keeps stopping kryfo'**
  String get homeYourPhoneKeepsStopping;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'It has closed kryfo three times today, so messages were late or waited. Check-ins survive that: kryfo wakes every 15 minutes instead of staying connected.'**
  String get homeItHasClosedKryfo;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Switch to check-ins'**
  String get homeSwitchToCheckIns;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get homeNotNow;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Notifications are off'**
  String get homeNotificationsAreOff;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Android is blocking them, so nothing reaches you while kryfo is closed. Messages still arrive when you open it.'**
  String get homeAndroidIsBlockingThem;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open it. Look for kryfo in phone settings'**
  String get homeCouldnTOpenIt;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Turn them on'**
  String get homeTurnThemOn;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Leave them off'**
  String get homeLeaveThemOff;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Our relay is quiet'**
  String get homeOurRelayIsQuiet;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Relay mode uses only our own relay, and it is not answering right now. Fast mode adds public relays alongside it, so messages still land. Everything stays sealed either way.'**
  String get homeRelayModeUsesOnly;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Switched to fast'**
  String get homeSwitchedToFast;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Use fast mode'**
  String get homeUseFastMode;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Keep waiting'**
  String get homeKeepWaiting;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Not connecting'**
  String get homeNotConnecting;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Bridges are on and tor still is not through. Bridges are slower, and some go dead without warning. If your network does not block tor, going direct is faster and more reliable.'**
  String get homeBridgesAreOnAnd;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Going direct · reconnecting'**
  String get homeGoingDirectReconnecting;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Turn bridges off'**
  String get homeTurnBridgesOff;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Still trying'**
  String get homeStillTrying;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Tor is not getting through. Some networks block it on purpose. Our own relay is one plain connection and usually works anyway - or bridges, which take longer to set up.'**
  String get homeTorIsNotGetting;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Switched to relay'**
  String get homeSwitchedToRelay;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Use our relay'**
  String get homeUseOurRelay;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Bridges'**
  String get homeBridges;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get homeOffline;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get homeWaiting;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Nothing waiting to send'**
  String get homeNothingWaitingToSend;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{n} waiting · sends when you\'re back'**
  String homeWaitingSendsWhenYou(Object n);

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{n} waiting · tor is still connecting'**
  String homeWaitingTorIsStill(Object n);

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{n} waiting · for them to add you back'**
  String homeWaitingForThemTo(Object n);

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{n} waiting · {p} for them to add you back'**
  String homeWaitingForThemToAddYou(Object n, Object p);

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{n} waiting · sending now'**
  String homeWaitingSendingNow(Object n);

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'No kryfos yet.'**
  String get homeNoKryfosYet;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Scan their code, send them a link, or type the @handle they gave you.'**
  String get homeScanTheirCodeSend;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Add someone'**
  String get homeAddSomeone;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get homeArchived;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'1 chat'**
  String get home1Chat;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{count} chats'**
  String homeChats(Object count);

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get homeGroups;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Room'**
  String get homeRoom;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get homeNew;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{expiredRoomName} · room expired'**
  String homeRoomExpired(Object expiredRoomName);

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'group-{groupId}'**
  String homeGroup(Object groupId);

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Mentioned you'**
  String get homeMentionedYou;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{memberCount} members'**
  String homeMembers(Object memberCount);

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Supporter'**
  String get homeSupporter;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Archived chats'**
  String get homeArchivedChats;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get homeUnmute;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get homeArchive;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Delete chat'**
  String get homeDeleteChat;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Messages and contact, gone from this phone'**
  String get homeMessagesAndContactGone;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Delete this chat?'**
  String get homeDeleteThisChat;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Every message with {c} goes, and they stop being a contact. It only clears this phone - their copy stays with them. If they message again it lands in requests.'**
  String homeEveryMessageWithGoes(Object c);

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'face-{avatarSeed}'**
  String homeFace(Object avatarSeed);

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get homeQueued;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'blocked'**
  String get homeBlocked;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Room invite'**
  String get homeRoomInvite;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get homeNow;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{inMinutes}m'**
  String homeM(Object inMinutes);

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{inHours}h'**
  String homeH(Object inHours);

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'yesterday'**
  String get homeYesterday;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{inDays}d'**
  String homeD(Object inDays);

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Jan'**
  String get homeJan;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Feb'**
  String get homeFeb;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Mar'**
  String get homeMar;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Apr'**
  String get homeApr;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Jun'**
  String get homeJun;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Jul'**
  String get homeJul;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Aug'**
  String get homeAug;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Sep'**
  String get homeSep;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Oct'**
  String get homeOct;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Nov'**
  String get homeNov;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Dec'**
  String get homeDec;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Note to self'**
  String get homeNoteToSelf;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Only on this phone'**
  String get homeOnlyOnThisPhone;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get homeSaved;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Kept from every chat'**
  String get homeKeptFromEveryChat;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get homeRequests;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'1 person wants to reach you'**
  String get home1PersonWantsTo;

  /// screens/home_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{count} people want to reach you'**
  String homePeopleWantToReach(Object count);

  /// screens/introduce_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'{b} got it, but {c} could not be reached'**
  String introduceGotItButCould(Object b, Object c);

  /// screens/introduce_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'{c} got it, but {b} could not be reached'**
  String introduceGotItButCouldNotBe(Object c, Object b);

  /// screens/introduce_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Could not reach either of them. Try again later'**
  String get introduceCouldNotReachEither;

  /// screens/introduce_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Introduce {peerName} to...'**
  String introduceIntroduceTo(Object peerName);

  /// screens/introduce_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Both of them get the other\'s card. Neither sees your name for the other.'**
  String get introduceBothOfThemGet;

  /// screens/introduce_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'No one else to introduce yet. Add another contact first.'**
  String get introduceNoOneElseTo;

  /// screens/introduce_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'A note, like \"my cousin\" - optional'**
  String get introduceANoteLikeMy;

  /// screens/introduce_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'{left} of {introBudgetMax} introductions left this week'**
  String introduceOfIntroductionsLeftThis(Object left, Object introBudgetMax);

  /// screens/introduce_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'No introductions left. Next one frees up {refillPhrase}'**
  String introduceNoIntroductionsLeftNext(Object refillPhrase);

  /// screens/introduce_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Introduce'**
  String get introduceIntroduce;

  /// screens/key_verification_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Safety number'**
  String get keyVerificationSafetyNumber;

  /// screens/key_verification_screen.dart
  ///
  /// In en, this message translates to:
  /// **'With {peerName}'**
  String keyVerificationWith(Object peerName);

  /// screens/key_verification_screen.dart
  ///
  /// In en, this message translates to:
  /// **'If {peerName} sees the same number, your messages are private to just the two of you. Comparing in person or over a call you trust is the surest way to be sure - but it is optional, never required to chat.'**
  String keyVerificationIfSeesTheSame(Object peerName);

  /// screens/key_verification_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get keyVerificationVerified;

  /// screens/key_verification_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Mark as verified'**
  String get keyVerificationMarkAsVerified;

  /// screens/lock_file_screen.dart
  ///
  /// In en, this message translates to:
  /// **'That password does not open it.'**
  String get lockFileThatPasswordDoesNot;

  /// screens/lock_file_screen.dart
  ///
  /// In en, this message translates to:
  /// **'This file is damaged.'**
  String get lockFileThisFileIsDamaged;

  /// screens/lock_file_screen.dart
  ///
  /// In en, this message translates to:
  /// **'This file was locked to a key, not a password.'**
  String get lockFileThisFileWasLocked;

  /// screens/lock_file_screen.dart
  ///
  /// In en, this message translates to:
  /// **'This is not a locked file.'**
  String get lockFileThisIsNotA;

  /// screens/lock_file_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Not enough free memory right now.'**
  String get lockFileNotEnoughFreeMemory;

  /// screens/lock_file_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Stopped.'**
  String get lockFileStopped;

  /// screens/lock_file_screen.dart
  ///
  /// In en, this message translates to:
  /// **'It needs a password.'**
  String get lockFileItNeedsAPassword;

  /// screens/lock_file_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Kryfo could not read or write the file.'**
  String get lockFileKryfoCouldNotRead;

  /// screens/lock_file_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Check capitals and spaces. Nobody can reset it, us included.'**
  String get lockFileCheckCapitalsAndSpaces;

  /// screens/lock_file_screen.dart
  ///
  /// In en, this message translates to:
  /// **'It may have been cut short on the way. Ask for it to be sent again. Nothing was saved.'**
  String get lockFileItMayHaveBeen;

  /// screens/lock_file_screen.dart
  ///
  /// In en, this message translates to:
  /// **'It opens with the key file of the person it was made for, in the age tool on a computer. Kryfo opens the password kind.'**
  String get lockFileItOpensWithThe;

  /// screens/lock_file_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Kryfo opens files locked with age. Those usually end in .age.'**
  String get lockFileKryfoOpensFilesLocked;

  /// screens/lock_file_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Close a few apps and try again. The password check needs a few hundred megabytes for a moment.'**
  String get lockFileCloseAFewApps;

  /// screens/lock_file_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Nothing was saved.'**
  String get lockFileNothingWasSaved;

  /// screens/lock_file_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Type one, or let Kryfo suggest four words.'**
  String get lockFileTypeOneOrLet;

  /// screens/lock_file_screen.dart
  ///
  /// In en, this message translates to:
  /// **'The app that holds it may have taken it back. Pick it again.'**
  String get lockFileTheAppThatHolds;

  /// screens/lock_file_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get lockFileHidePassword;

  /// screens/lock_file_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get lockFileShowPassword;

  /// screens/lock_file_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Change file'**
  String get lockFileChangeFile;

  /// screens/lock_file_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get lockFileChange;

  /// screens/lock_file_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{prettySize} of {prettySize2}'**
  String lockFileOf(Object prettySize, Object prettySize2);

  /// screens/lock_file_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Everything stays on this phone.'**
  String get lockFileEverythingStaysOnThis;

  /// screens/lock_file_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Could not make one. Type your own.'**
  String get lockFileCouldNotMakeOne;

  /// screens/lock_file_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Write it down before you lock the file'**
  String get lockFileWriteItDownBefore;

  /// screens/lock_file_screen.dart
  ///
  /// In en, this message translates to:
  /// **'No app on this phone took the file.'**
  String get lockFileNoAppOnThis;

  /// screens/lock_file_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get lockFileSaved;

  /// screens/lock_file_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Could not save it there. Try another folder.'**
  String get lockFileCouldNotSaveIt;

  /// screens/lock_file_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get lockFileLocked;

  /// screens/lock_file_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Lock a file'**
  String get lockFileLockAFile;

  /// screens/lock_file_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Mixing the password'**
  String get lockFileMixingThePassword;

  /// screens/lock_file_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Locking'**
  String get lockFileLocking;

  /// screens/lock_file_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Save to Files'**
  String get lockFileSaveToFiles;

  /// screens/lock_file_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Lock file'**
  String get lockFileLockFile;

  /// screens/lock_file_screen.dart
  ///
  /// In en, this message translates to:
  /// **'One password.'**
  String get lockFileOnePassword;

  /// screens/lock_file_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Nothing else opens it.'**
  String get lockFileNothingElseOpensIt;

  /// screens/lock_file_screen.dart
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get lockFileFile;

  /// screens/lock_file_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{prettySize} · from Files'**
  String lockFileFromFiles(Object prettySize);

  /// screens/lock_file_screen.dart
  ///
  /// In en, this message translates to:
  /// **'From Files'**
  String get lockFileFromFiles2;

  /// screens/lock_file_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get lockFilePassword;

  /// screens/lock_file_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Suggest four words'**
  String get lockFileSuggestFourWords;

  /// screens/lock_file_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Type it again'**
  String get lockFileTypeItAgain;

  /// screens/lock_file_screen.dart
  ///
  /// In en, this message translates to:
  /// **'The two do not match yet.'**
  String get lockFileTheTwoDoNot;

  /// screens/lock_file_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Hide the file name'**
  String get lockFileHideTheFileName;

  /// screens/lock_file_screen.dart
  ///
  /// In en, this message translates to:
  /// **'It will be called “locked file.age”. Tell them what kind of file it is.'**
  String get lockFileItWillBeCalled;

  /// screens/lock_file_screen.dart
  ///
  /// In en, this message translates to:
  /// **'The name alone can say what is inside.'**
  String get lockFileTheNameAloneCan;

  /// screens/lock_file_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Anyone with the password can open it, in Kryfo or on any computer with the free tool age. Forget it and the file is gone for good. Nobody can reset it, us included.'**
  String get lockFileAnyoneWithThePassword;

  /// screens/lock_file_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Locked.'**
  String get lockFileLocked2;

  /// screens/lock_file_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Only the password opens it.'**
  String get lockFileOnlyThePasswordOpens;

  /// screens/lock_file_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{prettySize} · safe to email or put on a USB stick'**
  String lockFileSafeToEmailOr(Object prettySize);

  /// screens/lock_file_screen.dart
  ///
  /// In en, this message translates to:
  /// **'No Kryfo on the other side? On a computer:'**
  String get lockFileNoKryfoOnThe;

  /// screens/lock_file_screen.dart
  ///
  /// In en, this message translates to:
  /// **'\$ age -d \"{name}\" > \"{plain}\"'**
  String lockFileAgeD(Object name, Object plain);

  /// screens/lock_file_screen.dart
  ///
  /// In en, this message translates to:
  /// **'It asks for the password. age is free at age-encryption.org'**
  String get lockFileItAsksForThe;

  /// screens/lock_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Too many tries · {lockState}s'**
  String lockTooManyTriesS(Object lockState);

  /// screens/lock_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Not it'**
  String get lockNotIt;

  /// screens/lock_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Your pin'**
  String get lockYourPin;

  /// screens/lock_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Use fingerprint'**
  String get lockUseFingerprint;

  /// screens/lock_setup_screen.dart
  ///
  /// In en, this message translates to:
  /// **'That is your wipe pin. Pick another.'**
  String get lockSetupThatIsYourWipe;

  /// screens/lock_setup_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Unlock with fingerprint?'**
  String get lockSetupUnlockWithFingerprint;

  /// screens/lock_setup_screen.dart
  ///
  /// In en, this message translates to:
  /// **'The pin still works whenever you want it. This is just faster.'**
  String get lockSetupThePinStillWorks;

  /// screens/lock_setup_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Use fingerprint'**
  String get lockSetupUseFingerprint;

  /// screens/lock_setup_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Pin only'**
  String get lockSetupPinOnly;

  /// screens/lock_setup_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Once more'**
  String get lockSetupOnceMore;

  /// screens/lock_setup_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Set a pin'**
  String get lockSetupSetAPin;

  /// screens/lock_setup_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Those were different. From the top.'**
  String get lockSetupThoseWereDifferentFrom;

  /// screens/lock_setup_screen.dart
  ///
  /// In en, this message translates to:
  /// **'The same four digits'**
  String get lockSetupTheSameFourDigits;

  /// screens/lock_setup_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Four digits, anything you will remember'**
  String get lockSetupFourDigitsAnythingYou;

  /// screens/modes_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Onion'**
  String get modesOnion;

  /// screens/modes_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Full onion routing, three hops. A message takes two to five seconds. Nobody sees who you talk to.'**
  String get modesFullOnionRoutingThree;

  /// screens/modes_screen.dart
  ///
  /// In en, this message translates to:
  /// **'slower'**
  String get modesSlower;

  /// screens/modes_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Relay'**
  String get modesRelay;

  /// screens/modes_screen.dart
  ///
  /// In en, this message translates to:
  /// **'One sealed connection to kryfo\'s own relay, like a vpn with nothing to log. Sends land in about a second, and it works where tor is blocked.'**
  String get modesOneSealedConnectionTo;

  /// screens/modes_screen.dart
  ///
  /// In en, this message translates to:
  /// **'quick'**
  String get modesQuick;

  /// screens/modes_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Relay only'**
  String get modesRelayOnly;

  /// screens/modes_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Fast'**
  String get modesFast;

  /// screens/modes_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Plain connections to every relay. Near instant, and the least private of the three.'**
  String get modesPlainConnectionsToEvery;

  /// screens/modes_screen.dart
  ///
  /// In en, this message translates to:
  /// **'instant'**
  String get modesInstant;

  /// screens/modes_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Every relay you use knows the address you connect from, not only ours. Messages are still sealed, but the fact that you sent one is not. Off by default, and off again after a reinstall.'**
  String get modesEveryRelayYouUse;

  /// screens/modes_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get modesSpeed;

  /// screens/modes_screen.dart
  ///
  /// In en, this message translates to:
  /// **'& privacy'**
  String get modesPrivacy;

  /// screens/modes_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Change globally, or per chat'**
  String get modesChangeGloballyOrPer;

  /// screens/modes_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Soon'**
  String get modesSoon;

  /// screens/modes_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get modesActive;

  /// screens/modes_screen.dart
  ///
  /// In en, this message translates to:
  /// **'speed'**
  String get modesSpeed2;

  /// screens/modes_screen.dart
  ///
  /// In en, this message translates to:
  /// **'hops'**
  String get modesHops;

  /// screens/modes_screen.dart
  ///
  /// In en, this message translates to:
  /// **'ip'**
  String get modesIp;

  /// screens/modes_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Visible'**
  String get modesVisible;

  /// screens/modes_screen.dart
  ///
  /// In en, this message translates to:
  /// **'hidden'**
  String get modesHidden;

  /// screens/modes_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Heads up: '**
  String get modesHeadsUp;

  /// screens/modes_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Onion is the default and stays that way unless you change it. Switching takes effect on the next message.'**
  String get modesOnionIsTheDefault;

  /// screens/modes_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Fast mode'**
  String get modesFastMode;

  /// screens/modes_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Plain connections to every relay. Quicker, and the relays can see your ip address. Messages stay end to end encrypted either way.'**
  String get modesPlainConnectionsToEveryRelayQuicker;

  /// screens/modes_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Turn on fast mode'**
  String get modesTurnOnFastMode;

  /// screens/modes_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Keep it off'**
  String get modesKeepItOff;

  /// screens/moved_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Wipe this phone?'**
  String get movedWipeThisPhone;

  /// screens/moved_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Everything kryfo holds here goes: the messages, the contacts, the keys. The other device keeps all of it. This cannot be undone.'**
  String get movedEverythingKryfoHoldsHere;

  /// screens/moved_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Wipe it'**
  String get movedWipeIt;

  /// screens/moved_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Not moving after all?'**
  String get movedNotMovingAfterAll;

  /// screens/moved_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Only do this if the backup was never imported anywhere. If it was, two devices now hold one identity, and messages will start going missing on both.'**
  String get movedOnlyDoThisIf;

  /// screens/moved_screen.dart
  ///
  /// In en, this message translates to:
  /// **'I\'m staying here'**
  String get movedIMStayingHere;

  /// screens/moved_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Staying here'**
  String get movedStayingHere;

  /// screens/moved_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Kryfo will close now. Tap the icon to reopen as {myId}.'**
  String movedKryfoWillCloseNow(Object myId);

  /// screens/moved_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Reopen kryfo'**
  String get movedReopenKryfo;

  /// screens/moved_screen.dart
  ///
  /// In en, this message translates to:
  /// **'This kryfo has moved'**
  String get movedThisKryfoHasMoved;

  /// screens/moved_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{myId} is now on another device. This phone can still show what was here, but nothing new will arrive on it, and anything you send from here won\'t reach anyone.'**
  String movedIsNowOnAnother(Object myId);

  /// screens/moved_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Keep it to read'**
  String get movedKeepItToRead;

  /// screens/moved_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Wipe this phone'**
  String get movedWipeThisPhone2;

  /// screens/moved_screen.dart
  ///
  /// In en, this message translates to:
  /// **'I\'m not moving after all'**
  String get movedIMNotMoving;

  /// screens/my_kryfo_screen.dart
  ///
  /// In en, this message translates to:
  /// **'A handle is 3 to 20 letters, digits or _'**
  String get myKryfoAHandleIs3;

  /// screens/my_kryfo_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Invite copied · clears in 60s'**
  String get myKryfoInviteCopiedClearsIn;

  /// screens/my_kryfo_screen.dart
  ///
  /// In en, this message translates to:
  /// **'add me on kryfo. my id is {myId}\n\ntap to add me:\n{uri}\n\nkryfo is a private messenger. no phone number, no email.'**
  String myKryfoAddMeOnKryfo(Object myId, Object uri);

  /// screens/my_kryfo_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Add me on kryfo'**
  String get myKryfoAddMeOnKryfo2;

  /// screens/my_kryfo_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Add someone'**
  String get myKryfoAddSomeone;

  /// screens/my_kryfo_screen.dart
  ///
  /// In en, this message translates to:
  /// **'kryfo doesn\'t scan your contacts, that\'s the point.'**
  String get myKryfoKryfoDoesnTScan;

  /// screens/my_kryfo_screen.dart
  ///
  /// In en, this message translates to:
  /// **'If this link ends up somewhere you did not mean, reset it in settings. Everyone who has it needs a new one then.'**
  String get myKryfoIfThisLinkEnds;

  /// screens/my_kryfo_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Already share a friend on kryfo? They can introduce you both from their chat, and you skip the request.'**
  String get myKryfoAlreadyShareAFriend;

  /// screens/my_kryfo_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Handle copied'**
  String get myKryfoHandleCopied;

  /// screens/my_kryfo_screen.dart
  ///
  /// In en, this message translates to:
  /// **'they\'re here with me'**
  String get myKryfoTheyReHereWith;

  /// screens/my_kryfo_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Point your phones at each other. Nothing goes through a server.'**
  String get myKryfoPointYourPhonesAt;

  /// screens/my_kryfo_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Scan theirs instead'**
  String get myKryfoScanTheirsInstead;

  /// screens/my_kryfo_screen.dart
  ///
  /// In en, this message translates to:
  /// **'They read you a code'**
  String get myKryfoTheyReadYouA;

  /// screens/my_kryfo_screen.dart
  ///
  /// In en, this message translates to:
  /// **'they\'re somewhere else'**
  String get myKryfoTheyReSomewhereElse;

  /// screens/my_kryfo_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Send them a link. It opens straight into add.'**
  String get myKryfoSendThemALink;

  /// screens/my_kryfo_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Your link appears once you are connected'**
  String get myKryfoYourLinkAppearsOnce;

  /// screens/my_kryfo_screen.dart
  ///
  /// In en, this message translates to:
  /// **'The link carries your id, your address and the keys to start a chat. It works until you reset it in settings.'**
  String get myKryfoTheLinkCarriesYour;

  /// screens/my_kryfo_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Send the link'**
  String get myKryfoSendTheLink;

  /// screens/my_kryfo_screen.dart
  ///
  /// In en, this message translates to:
  /// **'As a card'**
  String get myKryfoAsACard;

  /// screens/my_kryfo_screen.dart
  ///
  /// In en, this message translates to:
  /// **'An image with the qr'**
  String get myKryfoAnImageWithThe;

  /// screens/my_kryfo_screen.dart
  ///
  /// In en, this message translates to:
  /// **'As a file'**
  String get myKryfoAsAFile;

  /// screens/my_kryfo_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Contact file'**
  String get myKryfoContactFile;

  /// screens/my_kryfo_screen.dart
  ///
  /// In en, this message translates to:
  /// **'I know their handle'**
  String get myKryfoIKnowTheirHandle;

  /// screens/my_kryfo_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Type the @name they gave you. Works if they claimed one.'**
  String get myKryfoTypeTheNameThey;

  /// screens/my_kryfo_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Wren'**
  String get myKryfoWren;

  /// screens/my_kryfo_screen.dart
  ///
  /// In en, this message translates to:
  /// **'The lookup asks for that one name and nothing about you. Their first message from you still lands as a request on their side.'**
  String get myKryfoTheLookupAsksFor;

  /// screens/my_kryfo_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Looking…'**
  String get myKryfoLooking;

  /// screens/my_kryfo_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Find them'**
  String get myKryfoFindThem;

  /// screens/my_kryfo_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Your address appears once you are connected'**
  String get myKryfoYourAddressAppearsOnce;

  /// screens/my_kryfo_screen.dart
  ///
  /// In en, this message translates to:
  /// **'A public handle'**
  String get myKryfoAPublicHandle;

  /// screens/my_kryfo_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Put it in a bio. Anyone who knows it can find you.'**
  String get myKryfoPutItInA;

  /// screens/my_kryfo_screen.dart
  ///
  /// In en, this message translates to:
  /// **'A name people can find you by. Off until you claim one.'**
  String get myKryfoANamePeopleCan;

  /// screens/new_group_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Could not create'**
  String get newGroupCouldNotCreate;

  /// screens/new_group_screen.dart
  ///
  /// In en, this message translates to:
  /// **'New group'**
  String get newGroupNewGroup;

  /// screens/new_group_screen.dart
  ///
  /// In en, this message translates to:
  /// **'creating...'**
  String get newGroupCreating;

  /// screens/new_group_screen.dart
  ///
  /// In en, this message translates to:
  /// **'create'**
  String get newGroupCreate;

  /// screens/new_group_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get newGroupGroupName;

  /// screens/new_group_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get newGroupMembers;

  /// screens/new_group_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Pick at least one'**
  String get newGroupPickAtLeastOne;

  /// screens/new_group_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{selectedLength} selected'**
  String newGroupSelected(Object selectedLength);

  /// screens/new_group_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Add at least one contact first before creating a group.'**
  String get newGroupAddAtLeastOne;

  /// screens/notes_screen.dart
  ///
  /// In en, this message translates to:
  /// **'_notes_self_'**
  String get notesNotesSelf;

  /// screens/notes_screen.dart
  ///
  /// In en, this message translates to:
  /// **'TODAY'**
  String get notesToday;

  /// screens/notes_screen.dart
  ///
  /// In en, this message translates to:
  /// **'YESTERDAY'**
  String get notesYesterday;

  /// screens/notes_screen.dart
  ///
  /// In en, this message translates to:
  /// **'jan'**
  String get notesJan;

  /// screens/notes_screen.dart
  ///
  /// In en, this message translates to:
  /// **'feb'**
  String get notesFeb;

  /// screens/notes_screen.dart
  ///
  /// In en, this message translates to:
  /// **'mar'**
  String get notesMar;

  /// screens/notes_screen.dart
  ///
  /// In en, this message translates to:
  /// **'apr'**
  String get notesApr;

  /// screens/notes_screen.dart
  ///
  /// In en, this message translates to:
  /// **'may'**
  String get notesMay;

  /// screens/notes_screen.dart
  ///
  /// In en, this message translates to:
  /// **'jun'**
  String get notesJun;

  /// screens/notes_screen.dart
  ///
  /// In en, this message translates to:
  /// **'jul'**
  String get notesJul;

  /// screens/notes_screen.dart
  ///
  /// In en, this message translates to:
  /// **'aug'**
  String get notesAug;

  /// screens/notes_screen.dart
  ///
  /// In en, this message translates to:
  /// **'sep'**
  String get notesSep;

  /// screens/notes_screen.dart
  ///
  /// In en, this message translates to:
  /// **'oct'**
  String get notesOct;

  /// screens/notes_screen.dart
  ///
  /// In en, this message translates to:
  /// **'nov'**
  String get notesNov;

  /// screens/notes_screen.dart
  ///
  /// In en, this message translates to:
  /// **'dec'**
  String get notesDec;

  /// screens/notes_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Note to self'**
  String get notesNoteToSelf;

  /// screens/notes_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Only on this phone'**
  String get notesOnlyOnThisPhone;

  /// screens/notes_screen.dart
  ///
  /// In en, this message translates to:
  /// **'A quiet place'**
  String get notesAQuietPlace;

  /// screens/notes_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Jot anything down. It stays on this phone and never leaves.'**
  String get notesJotAnythingDownIt;

  /// screens/notes_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Jot something down…'**
  String get notesJotSomethingDown;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'PRIVATE BY DEFAULT'**
  String get onboardingPrivateByDefault;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Private messaging,\n'**
  String get onboardingPrivateMessaging;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'without the catch'**
  String get onboardingWithoutTheCatch;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Your name is three words.'**
  String get onboardingYourNameIsThree;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'No phone, no email, no address book.'**
  String get onboardingNoPhoneNoEmail;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Nobody gets in unless you let them.'**
  String get onboardingNobodyGetsInUnless;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'There is no search. People are added by hand, both ways.'**
  String get onboardingThereIsNoSearch;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'The first connection takes a minute.'**
  String get onboardingTheFirstConnectionTakes;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Kryfo builds a private route before it sends. Quick after.'**
  String get onboardingKryfoBuildsAPrivate;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Begin'**
  String get onboardingBegin;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Have a backup? Restore →'**
  String get onboardingHaveABackupRestore;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Kryfo is open source'**
  String get onboardingKryfoIsOpenSource;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'YOUR KRYFO ID'**
  String get onboardingYourKryfoId;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Generated from a key that lives only on this phone. '**
  String get onboardingGeneratedFromAKey;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Memorable, unique, yours alone.'**
  String get onboardingMemorableUniqueYoursAlone;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **' No one else has this.'**
  String get onboardingNoOneElseHas;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Try another'**
  String get onboardingTryAnother;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Use this name →'**
  String get onboardingUseThisName;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Three words. '**
  String get onboardingThreeWords;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Yours alone.'**
  String get onboardingYoursAlone;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'·'**
  String get onboardingText;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Pick a '**
  String get onboardingPickA;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Drawn on this phone from a number, never uploaded. Change it whenever you like.'**
  String get onboardingDrawnOnThisPhone;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'The people you message see this too'**
  String get onboardingThePeopleYouMessage;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Keep my initial'**
  String get onboardingKeepMyInitial;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'That one →'**
  String get onboardingThatOne;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Continue →'**
  String get onboardingContinue;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'How your messages '**
  String get onboardingHowYourMessages;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'You can change this any time in settings, for everyone or for one chat.'**
  String get onboardingYouCanChangeThis;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Onion'**
  String get onboardingOnion;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Slower. A message takes two to five seconds.'**
  String get onboardingSlowerAMessageTakes;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Hides your address from everyone, our relay included.'**
  String get onboardingHidesYourAddressFrom;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Relay'**
  String get onboardingRelay;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Our relay sees your address. Nobody else does.'**
  String get onboardingOurRelaySeesYour;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'About a second. Works where tor is blocked.'**
  String get onboardingAboutASecondWorks;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Fast'**
  String get onboardingFast;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Every relay you use sees your address. The least private of the three.'**
  String get onboardingEveryRelayYouUse;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Near instant.'**
  String get onboardingNearInstant;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Keep onion →'**
  String get onboardingKeepOnion;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Use this →'**
  String get onboardingUseThis;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Skip · onion is a fine default'**
  String get onboardingSkipOnionIsA;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Three things,\nthen '**
  String get onboardingThreeThingsThen;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'you\'re in'**
  String get onboardingYouReIn;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Everything else the app will tell you when it matters.'**
  String get onboardingEverythingElseTheApp;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Your name is three words'**
  String get onboardingYourNameIsThreeWords;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'That is the whole identity. No number to leak, no email to phish, nothing to look up. People you talk to see these words and the face you picked.'**
  String get onboardingThatIsTheWhole;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Nobody can reach you until you let them in'**
  String get onboardingNobodyCanReachYou;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'A stranger with your words can only knock. Their first message waits in requests until you say yes, and you can say no without them ever knowing.'**
  String get onboardingAStrangerWithYour;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'The first connection takes a minute'**
  String get onboardingTheFirstConnectionTakesAMinute;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Kryfo builds a private route before it sends anything. While you are offline, messages wait and arrive when you are back.'**
  String get onboardingKryfoBuildsAPrivateRouteBefore;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Your identity lives on this phone. Back it up from settings when you are ready.'**
  String get onboardingYourIdentityLivesOn;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'I understand →'**
  String get onboardingIUnderstand;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'One quiet '**
  String get onboardingOneQuiet;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Android needs a visible notification while an app listens in the background. That is how messages reach you when kryfo is closed.'**
  String get onboardingAndroidNeedsAVisible;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Silent, and at the bottom of the shade'**
  String get onboardingSilentAndAtThe;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'It never buzzes. Turn it off and messages wait until you open the app again.'**
  String get onboardingItNeverBuzzesTurn;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Got it →'**
  String get onboardingGotIt;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Now, '**
  String get onboardingNow;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'add someone'**
  String get onboardingAddSomeone;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'The app is ready. Nobody can message you until you add them or let them in.'**
  String get onboardingTheAppIsReady;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Every way to add someone'**
  String get onboardingEveryWayToAdd;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Show your code, send them a link, or type the @handle they gave you.'**
  String get onboardingShowYourCodeSend;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Scan theirs'**
  String get onboardingScanTheirs;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Point the camera at their code'**
  String get onboardingPointTheCameraAt;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'The app is ready when you are.'**
  String get onboardingTheAppIsReadyWhenYou;

  /// screens/onboarding_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Not now · add people later'**
  String get onboardingNotNowAddPeople;

  /// screens/open_locked_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Opened'**
  String get openLockedOpened;

  /// screens/open_locked_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Open a locked file'**
  String get openLockedOpenALockedFile;

  /// screens/open_locked_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Checking the password'**
  String get openLockedCheckingThePassword;

  /// screens/open_locked_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Opening'**
  String get openLockedOpening;

  /// screens/open_locked_screen.dart
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get openLockedFile;

  /// screens/open_locked_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Open file'**
  String get openLockedOpenFile;

  /// screens/open_locked_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Type the password.'**
  String get openLockedTypeThePassword;

  /// screens/open_locked_screen.dart
  ///
  /// In en, this message translates to:
  /// **'It opens on this phone.'**
  String get openLockedItOpensOnThis;

  /// screens/open_locked_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Locked file'**
  String get openLockedLockedFile;

  /// screens/open_locked_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{prettySize} · from Files'**
  String openLockedFromFiles(Object prettySize);

  /// screens/open_locked_screen.dart
  ///
  /// In en, this message translates to:
  /// **'From Files'**
  String get openLockedFromFiles2;

  /// screens/open_locked_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get openLockedPassword;

  /// screens/open_locked_screen.dart
  ///
  /// In en, this message translates to:
  /// **'The password is checked first. Only then does Kryfo ask where to put the opened file, and it goes straight there.'**
  String get openLockedThePasswordIsChecked;

  /// screens/open_locked_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Opened.'**
  String get openLockedOpened2;

  /// screens/open_locked_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Saved where you chose.'**
  String get openLockedSavedWhereYouChose;

  /// screens/pair_code_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Pairing code'**
  String get pairCodePairingCode;

  /// screens/pair_code_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Show a code'**
  String get pairCodeShowACode;

  /// screens/pair_code_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Enter one'**
  String get pairCodeEnterOne;

  /// screens/pair_code_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Six digits'**
  String get pairCodeSixDigits;

  /// screens/pair_code_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Looking…'**
  String get pairCodeLooking;

  /// screens/pair_code_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Nothing there yet · trying again'**
  String get pairCodeNothingThereYetTrying;

  /// screens/pair_code_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Nothing at that code. It may have burned, or they have not shared it yet.'**
  String get pairCodeNothingAtThatCode;

  /// screens/pair_code_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Type the six digits they read out.'**
  String get pairCodeTypeTheSixDigits;

  /// screens/pair_code_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Add them'**
  String get pairCodeAddThem;

  /// screens/panic_setup_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Those were different. From the top.'**
  String get panicSetupThoseWereDifferentFrom;

  /// screens/panic_setup_screen.dart
  ///
  /// In en, this message translates to:
  /// **'That is your real pin. Pick another.'**
  String get panicSetupThatIsYourReal;

  /// screens/panic_setup_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Once more'**
  String get panicSetupOnceMore;

  /// screens/panic_setup_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Set a wipe pin'**
  String get panicSetupSetAWipePin;

  /// screens/panic_setup_screen.dart
  ///
  /// In en, this message translates to:
  /// **'The same four digits'**
  String get panicSetupTheSameFourDigits;

  /// screens/panic_setup_screen.dart
  ///
  /// In en, this message translates to:
  /// **'The second pin wipes everything.'**
  String get panicSetupTheSecondPinWipes;

  /// screens/photo_knows_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Everything inside'**
  String get photoKnowsEverythingInside;

  /// screens/photo_knows_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get photoKnowsVideo;

  /// screens/photo_knows_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get photoKnowsPhoto;

  /// screens/photo_knows_screen.dart
  ///
  /// In en, this message translates to:
  /// **'What this video knows'**
  String get photoKnowsWhatThisVideoKnows;

  /// screens/photo_knows_screen.dart
  ///
  /// In en, this message translates to:
  /// **'What this photo knows'**
  String get photoKnowsWhatThisPhotoKnows;

  /// screens/photo_knows_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Remove all of it'**
  String get photoKnowsRemoveAllOfIt;

  /// screens/photo_knows_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Keep it as it is'**
  String get photoKnowsKeepItAsIt;

  /// screens/photo_knows_screen.dart
  ///
  /// In en, this message translates to:
  /// **'READ ON THIS PHONE · THE VIDEO WENT NOWHERE'**
  String get photoKnowsReadOnThisPhone;

  /// screens/photo_knows_screen.dart
  ///
  /// In en, this message translates to:
  /// **'READ ON THIS PHONE · THE PHOTO WENT NOWHERE'**
  String get photoKnowsReadOnThisPhoneThePhoto;

  /// screens/photo_knows_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Reading the file'**
  String get photoKnowsReadingTheFile;

  /// screens/photo_knows_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{prettySize} of {prettySize2}'**
  String photoKnowsOf(Object prettySize, Object prettySize2);

  /// screens/photo_knows_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Everything stays on this phone.'**
  String get photoKnowsEverythingStaysOnThis;

  /// screens/photo_knows_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Map with a pin. {place}'**
  String photoKnowsMapWithAPin(Object place);

  /// screens/photo_knows_screen.dart
  ///
  /// In en, this message translates to:
  /// **'DRAWN OFFLINE'**
  String get photoKnowsDrawnOffline;

  /// screens/photo_knows_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{title}. Show everything'**
  String photoKnowsShowEverything(Object title);

  /// screens/pins_screen.dart
  ///
  /// In en, this message translates to:
  /// **'App lock'**
  String get pinsAppLock;

  /// screens/pins_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Two pins'**
  String get pinsTwoPins;

  /// screens/pins_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Your pin'**
  String get pinsYourPin;

  /// screens/pins_screen.dart, screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get commonOn;

  /// screens/pins_screen.dart, screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get commonOff;

  /// screens/pins_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Opens kryfo. Four digits, asked for when it comes to the front.'**
  String get pinsOpensKryfoFourDigits;

  /// screens/pins_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Change pin'**
  String get pinsChangePin;

  /// screens/pins_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Set a pin'**
  String get pinsSetAPin;

  /// screens/pins_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Turn off'**
  String get pinsTurnOff;

  /// screens/pins_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Turn off the app lock?'**
  String get pinsTurnOffTheApp;

  /// screens/pins_screen.dart
  ///
  /// In en, this message translates to:
  /// **'The pin goes, and the wipe pin with it. Anyone holding your phone opens kryfo as you.'**
  String get pinsThePinGoesAnd;

  /// screens/pins_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Unlock with fingerprint'**
  String get pinsUnlockWithFingerprint;

  /// screens/pins_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Wipe pin'**
  String get pinsWipePin;

  /// screens/pins_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Needs a pin first'**
  String get pinsNeedsAPinFirst;

  /// screens/pins_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get pinsSet;

  /// screens/pins_screen.dart
  ///
  /// In en, this message translates to:
  /// **'The second pin wipes everything.'**
  String get pinsTheSecondPinWipes;

  /// screens/pins_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Change wipe pin'**
  String get pinsChangeWipePin;

  /// screens/pins_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Set a wipe pin'**
  String get pinsSetAWipePin;

  /// screens/pins_screen.dart
  ///
  /// In en, this message translates to:
  /// **'remove'**
  String get pinsRemove;

  /// screens/pins_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Remove the wipe pin?'**
  String get pinsRemoveTheWipePin;

  /// screens/pins_screen.dart
  ///
  /// In en, this message translates to:
  /// **'The lock screen keeps your pin. The wipe pin stops doing anything.'**
  String get pinsTheLockScreenKeeps;

  /// screens/profile_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{what} copied'**
  String profileCopied(Object what);

  /// screens/profile_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileProfile;

  /// screens/profile_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Change your face'**
  String get profileChangeYourFace;

  /// screens/profile_screen.dart
  ///
  /// In en, this message translates to:
  /// **'kryfo id'**
  String get profileKryfoId;

  /// screens/profile_screen.dart
  ///
  /// In en, this message translates to:
  /// **'onion address'**
  String get profileOnionAddress;

  /// screens/profile_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Supporter badge'**
  String get profileSupporterBadge;

  /// screens/profile_screen.dart
  ///
  /// In en, this message translates to:
  /// **'You are a {tierName}. thank you.'**
  String profileYouAreAThank(Object tierName);

  /// screens/profile_screen.dart
  ///
  /// In en, this message translates to:
  /// **'show my badge'**
  String get profileShowMyBadge;

  /// screens/profile_screen.dart
  ///
  /// In en, this message translates to:
  /// **'On my own screens'**
  String get profileOnMyOwnScreens;

  /// screens/profile_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Let contacts see it'**
  String get profileLetContactsSeeIt;

  /// screens/profile_screen.dart
  ///
  /// In en, this message translates to:
  /// **'off by default'**
  String get profileOffByDefault;

  /// screens/profile_screen.dart
  ///
  /// In en, this message translates to:
  /// **'share & connect'**
  String get profileShareConnect;

  /// screens/profile_screen.dart
  ///
  /// In en, this message translates to:
  /// **'My kryfo code'**
  String get profileMyKryfoCode;

  /// screens/profile_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Add contact'**
  String get profileAddContact;

  /// screens/profile_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Give again'**
  String get profileGiveAgain;

  /// screens/profile_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Support kryfo'**
  String get profileSupportKryfo;

  /// screens/profile_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Kryfo runs on what people give'**
  String get profileKryfoRunsOnWhat;

  /// screens/profile_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Keep kryfo independent'**
  String get profileKeepKryfoIndependent;

  /// screens/qr_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get qrLink;

  /// screens/qr_screen.dart
  ///
  /// In en, this message translates to:
  /// **'YOUR LINK AS TYPED · NO TRACKING REDIRECT'**
  String get qrYourLinkAsTyped;

  /// screens/qr_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get qrText;

  /// screens/qr_screen.dart
  ///
  /// In en, this message translates to:
  /// **'STAYS IN THE CODE · NO SERVER HOLDS IT'**
  String get qrStaysInTheCode;

  /// screens/qr_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi'**
  String get qrWiFi;

  /// screens/qr_screen.dart
  ///
  /// In en, this message translates to:
  /// **'MADE ON THIS PHONE · NO WEBSITE SAW THE PASSWORD'**
  String get qrMadeOnThisPhone;

  /// screens/qr_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Network name'**
  String get qrNetworkName;

  /// screens/qr_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get qrPassword;

  /// screens/qr_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get qrContact;

  /// screens/qr_screen.dart
  ///
  /// In en, this message translates to:
  /// **'ONLY WHAT YOU TYPE · NOTHING FROM YOUR CONTACTS'**
  String get qrOnlyWhatYouType;

  /// screens/qr_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get qrName;

  /// screens/qr_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get qrPhone;

  /// screens/qr_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get qrEmail;

  /// screens/qr_screen.dart
  ///
  /// In en, this message translates to:
  /// **'OPENS THEIR MAIL APP · NOTHING SENT FROM HERE'**
  String get qrOpensTheirMailApp;

  /// screens/qr_screen.dart
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get qrTo;

  /// screens/qr_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get qrSubject;

  /// screens/qr_screen.dart
  ///
  /// In en, this message translates to:
  /// **'A NUMBER · NOTHING ELSE'**
  String get qrANumberNothingElse;

  /// screens/qr_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Number'**
  String get qrNumber;

  /// screens/qr_screen.dart
  ///
  /// In en, this message translates to:
  /// **'SMS'**
  String get qrSms;

  /// screens/qr_screen.dart
  ///
  /// In en, this message translates to:
  /// **'OPENS THEIR MESSAGES APP · NOTHING SENT FROM HERE'**
  String get qrOpensTheirMessagesApp;

  /// screens/qr_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get qrMessage;

  /// screens/qr_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get qrLocation;

  /// screens/qr_screen.dart
  ///
  /// In en, this message translates to:
  /// **'COORDINATES ONLY · NO MAP SERVICE ASKED'**
  String get qrCoordinatesOnlyNoMap;

  /// screens/qr_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Latitude'**
  String get qrLatitude;

  /// screens/qr_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Longitude'**
  String get qrLongitude;

  /// screens/qr_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Bitcoin'**
  String get qrBitcoin;

  /// screens/qr_screen.dart
  ///
  /// In en, this message translates to:
  /// **'ADDRESS AND AMOUNT · NO PAYMENT SITE IN BETWEEN'**
  String get qrAddressAndAmountNo;

  /// screens/qr_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get qrAddress;

  /// screens/qr_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Amount in BTC'**
  String get qrAmountInBtc;

  /// screens/qr_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Ink'**
  String get qrInk;

  /// screens/qr_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Amber'**
  String get qrAmber;

  /// screens/qr_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Violet'**
  String get qrViolet;

  /// screens/qr_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{path}/tools_out'**
  String qrToolsOut(Object path);

  /// screens/qr_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Could not draw the image.'**
  String get qrCouldNotDrawThe;

  /// screens/qr_screen.dart
  ///
  /// In en, this message translates to:
  /// **'qr code.png'**
  String get qrQrCodePng;

  /// screens/qr_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Saved to your gallery'**
  String get qrSavedToYourGallery;

  /// screens/qr_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Could not save it. Check the phone has room.'**
  String get qrCouldNotSaveIt;

  /// screens/qr_screen.dart
  ///
  /// In en, this message translates to:
  /// **'No app on this phone took the image.'**
  String get qrNoAppOnThis;

  /// screens/qr_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Too much for one code. Make it shorter.'**
  String get qrTooMuchForOne;

  /// screens/qr_screen.dart
  ///
  /// In en, this message translates to:
  /// **'This is a lot for one code. Older cameras may not read it.'**
  String get qrThisIsALot;

  /// screens/qr_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Private QR code'**
  String get qrPrivateQrCode;

  /// screens/qr_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get qrColour;

  /// screens/qr_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Copied. It leaves the clipboard in a minute'**
  String get qrCopiedItLeavesThe;

  /// screens/qr_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get qrSecurity;

  /// screens/qr_screen.dart
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get qrNone;

  /// screens/qr_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Save image'**
  String get qrSaveImage;

  /// screens/qr_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{name} colour'**
  String qrColour2(Object name);

  /// screens/qr_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Type below and the\ncode draws itself'**
  String get qrTypeBelowAndThe;

  /// screens/qr_screen.dart
  ///
  /// In en, this message translates to:
  /// **'QR code'**
  String get qrQrCode;

  /// screens/qr_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get qrHidePassword;

  /// screens/qr_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get qrShowPassword;

  /// screens/qr_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Copy password'**
  String get qrCopyPassword;

  /// screens/requests_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Sent an attachment'**
  String get requestsSentAnAttachment;

  /// screens/requests_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Wants to connect'**
  String get requestsWantsToConnect;

  /// screens/requests_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get requestsAccepted;

  /// screens/requests_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Block {id}?'**
  String requestsBlock(Object id);

  /// screens/requests_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Nothing more from them reaches you. Their request and its messages go.'**
  String get requestsNothingMoreFromThem;

  /// screens/requests_screen.dart
  ///
  /// In en, this message translates to:
  /// **'blocked'**
  String get requestsBlocked;

  /// screens/requests_screen.dart
  ///
  /// In en, this message translates to:
  /// **'deleted'**
  String get requestsDeleted;

  /// screens/requests_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get requestsRequests;

  /// screens/requests_screen.dart
  ///
  /// In en, this message translates to:
  /// **'No requests'**
  String get requestsNoRequests;

  /// screens/requests_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Messages from people you have not added show up here first.'**
  String get requestsMessagesFromPeopleYou;

  /// screens/requests_screen.dart
  ///
  /// In en, this message translates to:
  /// **'face-{haloId}'**
  String requestsFace(Object haloId);

  /// screens/requests_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Looks safe · nothing suspicious in their first message'**
  String get requestsLooksSafeNothingSuspicious;

  /// screens/requests_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get commonAccept;

  /// screens/requests_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get requestsDecline;

  /// screens/restore_screen.dart
  ///
  /// In en, this message translates to:
  /// **'That file is not a kryfo backup'**
  String get restoreThatFileIsNot;

  /// screens/restore_screen.dart
  ///
  /// In en, this message translates to:
  /// **'This file is damaged and cannot be read'**
  String get restoreThisFileIsDamaged;

  /// screens/restore_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Type the passphrase the file was made with'**
  String get restoreTypeThePassphraseThe;

  /// screens/restore_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Replace the account on this phone?'**
  String get restoreReplaceTheAccountOn;

  /// screens/restore_screen.dart
  ///
  /// In en, this message translates to:
  /// **'What is here now, its identity, contacts and messages, goes. The file takes its place. This cannot be undone.'**
  String get restoreWhatIsHereNow;

  /// screens/restore_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Replace it'**
  String get restoreReplaceIt;

  /// screens/restore_screen.dart
  ///
  /// In en, this message translates to:
  /// **'@{mine} could not be released'**
  String restoreCouldNotBeReleased(Object mine);

  /// screens/restore_screen.dart
  ///
  /// In en, this message translates to:
  /// **'The registry did not answer. If you go on, @{mine} stays pointed at the identity this phone is about to lose. Anyone who adds it will be writing to nobody, and the name cannot be claimed again. Better to get online and try once more.'**
  String restoreTheRegistryDidNot(Object mine);

  /// screens/restore_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Restore anyway'**
  String get restoreRestoreAnyway;

  /// screens/restore_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Not yet'**
  String get restoreNotYet;

  /// screens/restore_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Restored'**
  String get restoreRestored;

  /// screens/restore_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Kryfo will close now. Tap the icon to reopen as {haloId}.'**
  String restoreKryfoWillCloseNow(Object haloId);

  /// screens/restore_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Reopen kryfo'**
  String get restoreReopenKryfo;

  /// screens/restore_screen.dart
  ///
  /// In en, this message translates to:
  /// **'The restore did not finish. Nothing was changed'**
  String get restoreTheRestoreDidNot;

  /// screens/restore_screen.dart
  ///
  /// In en, this message translates to:
  /// **', made on {day} {summaryCard} at {when}:{when2}'**
  String restoreMadeOnAt(
    Object day,
    Object summaryCard,
    Object when,
    Object when2,
  );

  /// screens/restore_screen.dart
  ///
  /// In en, this message translates to:
  /// **'this identity'**
  String get restoreThisIdentity;

  /// screens/restore_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Move your kryfo here'**
  String get restoreMoveYourKryfoHere;

  /// screens/restore_screen.dart
  ///
  /// In en, this message translates to:
  /// **'This backup is {name}{made}. Restoring it moves that identity to this device.'**
  String restoreThisBackupIsRestoring(Object name, Object made);

  /// screens/restore_screen.dart
  ///
  /// In en, this message translates to:
  /// **'It holds {mb} of photos, voice notes and files. This may take a few minutes. Keep the app open.'**
  String restoreItHoldsOfPhotos(Object mb);

  /// screens/restore_screen.dart
  ///
  /// In en, this message translates to:
  /// **'What follows'**
  String get restoreWhatFollows;

  /// screens/restore_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Your name, your code, and every contact.'**
  String get restoreYourNameYourCode;

  /// screens/restore_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Every conversation, back to the start.'**
  String get restoreEveryConversationBackTo;

  /// screens/restore_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Your photos, voice notes and files{s}.'**
  String restoreYourPhotosVoiceNotes(Object s);

  /// screens/restore_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Your onion address, so people who reach you directly keep reaching you.'**
  String get restoreYourOnionAddressSo;

  /// screens/restore_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Anything sent to you while the old phone was off, for fourteen days after it was sent.'**
  String get restoreAnythingSentToYou;

  /// screens/restore_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Your supporter badge, if you have one.'**
  String get restoreYourSupporterBadgeIf;

  /// screens/restore_screen.dart
  ///
  /// In en, this message translates to:
  /// **'What doesn\'t'**
  String get restoreWhatDoesnT;

  /// screens/restore_screen.dart
  ///
  /// In en, this message translates to:
  /// **'The old phone stops receiving the moment you send anything from here. Not gradually. The first message you send from this device is the last one the old phone can follow, and anything that reaches it after that is unreadable there and isn\'t waiting for you here either.'**
  String get restoreTheOldPhoneStops;

  /// screens/restore_screen.dart
  ///
  /// In en, this message translates to:
  /// **'If the phone this file came from is still in use, stop using kryfo on it before you carry on. Two phones on one kryfo lose messages on both.'**
  String get restoreIfThePhoneThis;

  /// screens/restore_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Notifications need setting up again on this device.'**
  String get restoreNotificationsNeedSettingUp;

  /// screens/restore_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Move it here'**
  String get restoreMoveItHere;

  /// screens/restore_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get restoreNotNow;

  /// screens/restore_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restoreRestore;

  /// screens/restore_screen.dart
  ///
  /// In en, this message translates to:
  /// **'From a backup file'**
  String get restoreFromABackupFile;

  /// screens/restore_screen.dart
  ///
  /// In en, this message translates to:
  /// **'A backup brings back your identity and your contacts, and the messages that were on the phone when the file was made. Anything said since is not in it.'**
  String get restoreABackupBringsBack;

  /// screens/restore_screen.dart
  ///
  /// In en, this message translates to:
  /// **'The file'**
  String get restoreTheFile;

  /// screens/restore_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Pick the backup file'**
  String get restorePickTheBackupFile;

  /// screens/restore_screen.dart
  ///
  /// In en, this message translates to:
  /// **'The passphrase'**
  String get restoreThePassphrase;

  /// screens/restore_screen.dart
  ///
  /// In en, this message translates to:
  /// **'The one the file was made with'**
  String get restoreTheOneTheFile;

  /// screens/restore_screen.dart
  ///
  /// In en, this message translates to:
  /// **'What comes back'**
  String get restoreWhatComesBack;

  /// screens/restore_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get restoreChecking;

  /// screens/restore_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Check the file'**
  String get restoreCheckTheFile;

  /// screens/restore_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Releasing your handle…'**
  String get restoreReleasingYourHandle;

  /// screens/restore_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Moving… {progress}%'**
  String restoreMoving(Object progress);

  /// screens/restore_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Restoring…'**
  String get restoreRestoring;

  /// screens/restore_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Not this one'**
  String get restoreNotThisOne;

  /// screens/restore_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Date unknown'**
  String get restoreDateUnknown;

  /// screens/restore_screen.dart
  ///
  /// In en, this message translates to:
  /// **'An identity'**
  String get restoreAnIdentity;

  /// screens/restore_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Messages sent or received after that date are not in this file.'**
  String get restoreMessagesSentOrReceived;

  /// screens/restore_screen.dart
  ///
  /// In en, this message translates to:
  /// **'jun'**
  String get restoreJun;

  /// screens/restore_screen.dart
  ///
  /// In en, this message translates to:
  /// **'jul'**
  String get restoreJul;

  /// screens/restore_screen.dart
  ///
  /// In en, this message translates to:
  /// **'aug'**
  String get restoreAug;

  /// screens/restore_screen.dart
  ///
  /// In en, this message translates to:
  /// **'sep'**
  String get restoreSep;

  /// screens/restore_screen.dart
  ///
  /// In en, this message translates to:
  /// **'oct'**
  String get restoreOct;

  /// screens/restore_screen.dart
  ///
  /// In en, this message translates to:
  /// **'nov'**
  String get restoreNov;

  /// screens/restore_screen.dart
  ///
  /// In en, this message translates to:
  /// **'dec'**
  String get restoreDec;

  /// screens/restore_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{bytes} GB'**
  String restoreGb(Object bytes);

  /// screens/restore_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{bytes} MB'**
  String restoreMb(Object bytes);

  /// screens/room_create_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Could not create the room'**
  String get roomCreateCouldNotCreateThe;

  /// screens/room_create_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Burner room'**
  String get roomCreateBurnerRoom;

  /// screens/room_create_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'A room that ends. Everyone joins under a key made for it, and when it ends nothing is left on any phone.'**
  String get roomCreateARoomThatEnds;

  /// screens/room_create_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Room name'**
  String get roomCreateRoomName;

  /// screens/room_create_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Ends after'**
  String get roomCreateEndsAfter;

  /// screens/room_create_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Member cap'**
  String get roomCreateMemberCap;

  /// screens/room_create_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'No one past the first {cap}'**
  String roomCreateNoOnePastThe(Object cap);

  /// screens/room_create_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'off. Anyone with the link'**
  String get roomCreateOffAnyoneWithThe;

  /// screens/room_create_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'This room and everything in it disappears in {expiryWords}'**
  String roomCreateThisRoomAndEverything(Object expiryWords);

  /// screens/room_create_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'creating...'**
  String get roomCreateCreating;

  /// screens/room_create_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Create room'**
  String get roomCreateCreateRoom;

  /// screens/room_link_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Send the room to'**
  String get roomLinkSendTheRoomTo;

  /// screens/room_link_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'They will know this room came from you. Inside it they are a key like everyone else.'**
  String get roomLinkTheyWillKnowThis;

  /// screens/room_link_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'No contacts yet'**
  String get roomLinkNoContactsYet;

  /// screens/room_link_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Ends in '**
  String get roomLinkEndsIn;

  /// screens/room_link_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Anyone with this can join until the room ends. They come in under a key made for this room, and see nothing sent before they arrived.'**
  String get roomLinkAnyoneWithThisCan;

  /// screens/room_link_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Room link copied'**
  String get roomLinkRoomLinkCopied;

  /// screens/room_link_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Send to a contact'**
  String get roomLinkSendToAContact;

  /// screens/room_link_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Copy room link'**
  String get roomLinkCopyRoomLink;

  /// screens/saved_screen.dart
  ///
  /// In en, this message translates to:
  /// **'voice note'**
  String get savedVoiceNote;

  /// screens/saved_screen.dart
  ///
  /// In en, this message translates to:
  /// **'photo'**
  String get savedPhoto;

  /// screens/saved_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get savedSaved;

  /// screens/saved_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Nothing saved yet'**
  String get savedNothingSavedYet;

  /// screens/saved_screen.dart
  ///
  /// In en, this message translates to:
  /// **'long-press any message and tap save to keep it here.'**
  String get savedLongPressAnyMessage;

  /// screens/saved_screen.dart
  ///
  /// In en, this message translates to:
  /// **'View in chat'**
  String get savedViewInChat;

  /// screens/saved_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get savedPhoto2;

  /// screens/scan_screen.dart
  ///
  /// In en, this message translates to:
  /// **'that\'s not a kryfo qr · keep pointing'**
  String get scanThatSNotA;

  /// screens/scan_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Scan a kryfo qr'**
  String get scanScanAKryfoQr;

  /// screens/scan_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Flash'**
  String get scanFlash;

  /// screens/scan_screen.dart
  ///
  /// In en, this message translates to:
  /// **'default'**
  String get scanDefault;

  /// screens/scan_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Point at a kryfo qr · nothing leaves your phone'**
  String get scanPointAtAKryfo;

  /// screens/seen_screen.dart
  ///
  /// In en, this message translates to:
  /// **'What we can see'**
  String get seenWhatWeCanSee;

  /// screens/seen_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Every messenger claims privacy. This is the specific list, by route, including the parts that do not flatter us. Tap a row for the why.'**
  String get seenEveryMessengerClaimsPrivacy;

  /// screens/seen_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Honest about the last rows: that is what the app lock, the wipe pin and encrypted storage are for, and no tool saves you from someone holding your open phone. The full threat model lives in THREAT_MODEL.md in the repo, written against LINDDUN. The code is open, so none of this has to be taken on trust.'**
  String get seenHonestAboutTheLast;

  /// screens/seen_screen.dart
  ///
  /// In en, this message translates to:
  /// **'hidden'**
  String get seenHidden;

  /// screens/seen_screen.dart
  ///
  /// In en, this message translates to:
  /// **'never'**
  String get seenNever;

  /// screens/seen_screen.dart
  ///
  /// In en, this message translates to:
  /// **'on device'**
  String get seenOnDevice;

  /// screens/seen_screen.dart
  ///
  /// In en, this message translates to:
  /// **'timing'**
  String get seenTiming;

  /// screens/seen_screen.dart
  ///
  /// In en, this message translates to:
  /// **'yours'**
  String get seenYours;

  /// screens/seen_screen.dart
  ///
  /// In en, this message translates to:
  /// **'unaudited'**
  String get seenUnaudited;

  /// screens/seen_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Who you talk to'**
  String get seenWhoYouTalkTo;

  /// screens/seen_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Each conversation gets its own address, derived from both keys. A relay sees unrelated drop boxes, not a pair of people.'**
  String get seenEachConversationGetsIts;

  /// screens/seen_screen.dart
  ///
  /// In en, this message translates to:
  /// **'what you say'**
  String get seenWhatYouSay;

  /// screens/seen_screen.dart
  ///
  /// In en, this message translates to:
  /// **'End to end encrypted with the signal double ratchet, then sealed again inside a gift wrap. We could not read it if we tried.'**
  String get seenEndToEndEncrypted;

  /// screens/seen_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Your ip address'**
  String get seenYourIpAddress;

  /// screens/seen_screen.dart
  ///
  /// In en, this message translates to:
  /// **'our relay'**
  String get seenOurRelay;

  /// screens/seen_screen.dart
  ///
  /// In en, this message translates to:
  /// **'every relay'**
  String get seenEveryRelay;

  /// screens/seen_screen.dart
  ///
  /// In en, this message translates to:
  /// **'On onion everything leaves through tor and the relay sees an exit node, never you. On relay mode the connection goes straight to our own relay: nothing forwards your address and nothing is written down, but that one connection is ours to see. On fast every public relay learns that you connected, though not to whom or what you said.'**
  String get seenOnOnionEverythingLeaves;

  /// screens/seen_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Your contact graph'**
  String get seenYourContactGraph;

  /// screens/seen_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Kryfo does not scan your contacts. That is the point. No phone number exists here to leak.'**
  String get seenKryfoDoesNotScan;

  /// screens/seen_screen.dart
  ///
  /// In en, this message translates to:
  /// **'introducer'**
  String get seenIntroducer;

  /// screens/seen_screen.dart
  ///
  /// In en, this message translates to:
  /// **'When a contact introduces you to someone, that contact learns the two of you are now connected. Nobody else does. The relay sees ciphertext, and no server ever sees the graph.'**
  String get seenWhenAContactIntroduces;

  /// screens/seen_screen.dart
  ///
  /// In en, this message translates to:
  /// **'The scam shield'**
  String get seenTheScamShield;

  /// screens/seen_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Runs on your phone with rules that ship in the app. No network, no list downloads. It only reads the first message from a stranger and cannot see anything a contact sends you.'**
  String get seenRunsOnYourPhone;

  /// screens/seen_screen.dart
  ///
  /// In en, this message translates to:
  /// **'burner rooms'**
  String get seenBurnerRooms;

  /// screens/seen_screen.dart
  ///
  /// In en, this message translates to:
  /// **'room keys'**
  String get seenRoomKeys;

  /// screens/seen_screen.dart
  ///
  /// In en, this message translates to:
  /// **'You join a room under a key made for it, so the people inside learn nothing that works elsewhere. Late joiners get no history. At expiry the keys, the messages and the media are destroyed.'**
  String get seenYouJoinARoom;

  /// screens/seen_screen.dart
  ///
  /// In en, this message translates to:
  /// **'link previews'**
  String get seenLinkPreviews;

  /// screens/seen_screen.dart
  ///
  /// In en, this message translates to:
  /// **'over tor'**
  String get seenOverTor;

  /// screens/seen_screen.dart
  ///
  /// In en, this message translates to:
  /// **'A preview is fetched by the sender, over tor, and travels inside the encrypted message. The receiving phone makes no request. The website learns that someone using tor asked for a page, and nothing else. No image is ever loaded, and a stranger\'s link stays plain text.'**
  String get seenAPreviewIsFetched;

  /// screens/seen_screen.dart
  ///
  /// In en, this message translates to:
  /// **'That a device fetched mail'**
  String get seenThatADeviceFetched;

  /// screens/seen_screen.dart
  ///
  /// In en, this message translates to:
  /// **'A relay can tell that some address was checked, and when. It cannot tell whose, or from where.'**
  String get seenARelayCanTell;

  /// screens/seen_screen.dart
  ///
  /// In en, this message translates to:
  /// **'A seized unlocked phone'**
  String get seenASeizedUnlockedPhone;

  /// screens/seen_screen.dart
  ///
  /// In en, this message translates to:
  /// **'If someone holds your phone open, they read your messages. The app lock, panic pin and encrypted storage help before that point, not after it.'**
  String get seenIfSomeoneHoldsYour;

  /// screens/seen_screen.dart
  ///
  /// In en, this message translates to:
  /// **'The crypto itself'**
  String get seenTheCryptoItself;

  /// screens/seen_screen.dart
  ///
  /// In en, this message translates to:
  /// **'The ratchet and storage layers are standard. The layer joining them is ours and no one independent has reviewed it. Treat this as alpha, because it is.'**
  String get seenTheRatchetAndStorage;

  /// screens/seen_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Onion'**
  String get seenOnion;

  /// screens/seen_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Relay'**
  String get seenRelay;

  /// screens/seen_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Fast'**
  String get seenFast;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Wipe kryfo?'**
  String get settingsWipeKryfo;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Identity, messages, contacts and settings on this phone. Gone for good unless you have a backup.'**
  String get settingsIdentityMessagesContactsAnd;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'type \'wipe\' to confirm'**
  String get settingsTypeWipeToConfirm;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'The last step. Nothing survives it.'**
  String get settingsTheLastStepNothing;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Wipe'**
  String get settingsWipe;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Wipe kryfo'**
  String get settingsWipeKryfo2;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Your protections'**
  String get settingsYourProtections;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'tor routing'**
  String get settingsTorRouting;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'connecting'**
  String get settingsConnecting;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'off · {appState} mode'**
  String settingsOffMode(Object appState);

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'app lock'**
  String get settingsAppLock;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'blocked by android'**
  String get settingsBlockedByAndroid;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Speed & privacy'**
  String get settingsSpeedPrivacy;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'fast'**
  String get settingsFast;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Relay · 1 hop'**
  String get settingsRelay1Hop;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Onion · 3 hops'**
  String get settingsOnion3Hops;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Bridges'**
  String get settingsBridges;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'For networks that block tor'**
  String get settingsForNetworksThatBlock;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Getting messages'**
  String get settingsGettingMessages;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{deliveryModeName} · preview hidden'**
  String settingsPreviewHidden(Object deliveryModeName);

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{deliveryModeName} · preview shown'**
  String settingsPreviewShown(Object deliveryModeName);

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Run in background'**
  String get settingsRunInBackground;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'So messages arrive'**
  String get settingsSoMessagesArrive;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get settingsTransport;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'What the network is doing'**
  String get settingsWhatTheNetworkIs;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get settingsBlocked;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Accept introductions'**
  String get settingsAcceptIntroductions;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Friends can introduce you to theirs'**
  String get settingsFriendsCanIntroduceYou;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Scam shield'**
  String get settingsScamShield;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Checks strangers on your phone. Nothing leaves it'**
  String get settingsChecksStrangersOnYour;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Block screenshots'**
  String get settingsBlockScreenshots;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Whole app hidden from recents and screenshots · takes effect after the next start'**
  String get settingsWholeAppHiddenFrom;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Whole app hidden from recents and screenshots'**
  String get settingsWholeAppHiddenFromRecentsAnd;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'On · next start'**
  String get settingsOnNextStart;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Off · next start'**
  String get settingsOffNextStart;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Light theme'**
  String get settingsLightTheme;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Same protection, brighter'**
  String get settingsSameProtectionBrighter;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'App lock'**
  String get settingsAppLock2;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Your pin, and a wipe pin'**
  String get settingsYourPinAndA;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Pin · wipe pin'**
  String get settingsPinWipePin;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Back up identity'**
  String get settingsBackUpIdentity;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Encrypted file'**
  String get settingsEncryptedFile;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Restore from backup'**
  String get settingsRestoreFromBackup;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Replace current'**
  String get settingsReplaceCurrent;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Disguise voice'**
  String get settingsDisguiseVoice;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Shifts your pitch before a voice note leaves'**
  String get settingsShiftsYourPitchBefore;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Why kryfo'**
  String get settingsWhyKryfo;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'How it protects you'**
  String get settingsHowItProtectsYou;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Reset my invite link'**
  String get settingsResetMyInviteLink;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Old links and codes stop working, for everyone'**
  String get settingsOldLinksAndCodes;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Reset invite link?'**
  String get settingsResetInviteLink;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Anyone with an old code or link stops being able to reach you, on every route. People who have it but never used it will need a new one from you. Contacts, chats and history stay.'**
  String get settingsAnyoneWithAnOld;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get settingsReset;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Invite reset · share the new code'**
  String get settingsInviteResetShareThe;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'What we can see'**
  String get settingsWhatWeCanSee;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'The honest list'**
  String get settingsTheHonestList;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsVersion;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'0.3.0 · alpha'**
  String get settings030Alpha;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Report an issue'**
  String get settingsReportAnIssue;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Bug or security flaw'**
  String get settingsBugOrSecurityFlaw;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Open source'**
  String get settingsOpenSource;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get settingsLinkCopied;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'The offline map in Tools is drawn from Natural Earth (public domain). Town names are from GeoNames, geonames.org, under CC BY 4.0.'**
  String get settingsTheOfflineMapIn;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Not independently audited. Pre-alpha - good for testing, not yet for high-stakes use.'**
  String get settingsNotIndependentlyAuditedPre;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'danger zone'**
  String get settingsDangerZone;

  /// screens/settings_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Wipe kryfo from this phone'**
  String get settingsWipeKryfoFromThis;

  /// screens/shield_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Checked on this phone. Nothing was sent anywhere.'**
  String get shieldCheckedOnThisPhone;

  /// screens/tools_screen.dart
  ///
  /// In en, this message translates to:
  /// **'More tools'**
  String get toolsMoreTools;

  /// screens/tools_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Clean a photo or video'**
  String get toolsCleanAPhotoOr;

  /// screens/tools_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Or share one to Kryfo from your gallery'**
  String get toolsOrShareOneTo;

  /// screens/tools_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Make a private QR code'**
  String get toolsMakeAPrivateQr;

  /// screens/tools_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Links, Wi-Fi, contacts and more. Made offline'**
  String get toolsLinksWiFiContacts;

  /// screens/tools_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Lock a file'**
  String get toolsLockAFile;

  /// screens/tools_screen.dart
  ///
  /// In en, this message translates to:
  /// **'With a password. Opens anywhere with age'**
  String get toolsWithAPasswordOpens;

  /// screens/tools_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Open a locked file'**
  String get toolsOpenALockedFile;

  /// screens/tools_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Any .age file someone sent you'**
  String get toolsAnyAgeFileSomeone;

  /// screens/tools_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Works offline · no contacts needed'**
  String get toolsWorksOfflineNoContacts;

  /// screens/tools_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Useful from'**
  String get toolsUsefulFrom;

  /// screens/tools_screen.dart
  ///
  /// In en, this message translates to:
  /// **'the first minute.'**
  String get toolsTheFirstMinute;

  /// screens/tools_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Everything here happens on this phone. Nothing is uploaded, and nobody else has to be on Kryfo.'**
  String get toolsEverythingHereHappensOn;

  /// screens/tools_screen.dart
  ///
  /// In en, this message translates to:
  /// **'What does this photo know?'**
  String get toolsWhatDoesThisPhoto;

  /// screens/tools_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Place · phone · time'**
  String get toolsPlacePhoneTime;

  /// screens/tools_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Pick a photo and see what it gives away. Then keep a clean copy.'**
  String get toolsPickAPhotoAnd;

  /// screens/tools_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Pick a photo'**
  String get toolsPickAPhoto;

  /// screens/tools_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get toolsVideo;

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get transportTransport;

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Nothing here leaves the phone. It is the same state the engine uses to decide what to do.'**
  String get transportNothingHereLeavesThe;

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'staying alive'**
  String get transportStayingAlive;

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'can send'**
  String get transportCanSend;

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get commonYes;

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Not yet'**
  String get transportNotYet;

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get transportOnline;

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get transportOffline;

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'queued to send'**
  String get transportQueuedToSend;

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Onion published'**
  String get transportOnionPublished;

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Yes ({uploads})'**
  String transportYes(Object uploads);

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Trying {pubFor}s'**
  String transportTryingS(Object pubFor);

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Benched {r}s'**
  String transportBenchedS(Object r);

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{r} fails'**
  String transportFails(Object r);

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'ok'**
  String get transportOk;

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Relay subscriptions'**
  String get transportRelaySubscriptions;

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'last sent'**
  String get transportLastSent;

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get transportNever;

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{sx}s ago'**
  String transportSAgo(Object sx);

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'last received'**
  String get transportLastReceived;

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{rx}s ago'**
  String transportSAgo2(Object rx);

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'With no contacts the app subscribes to no relay addresses, so no message can reach you. Scan someone to fix it.'**
  String get transportWithNoContactsThe;

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Send anything waiting, now'**
  String get transportSendAnythingWaitingNow;

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'off'**
  String get transportOff;

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'starting'**
  String get transportStarting;

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'bootstrapped'**
  String get transportBootstrapped;

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Publishing address'**
  String get transportPublishingAddress;

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'reachable'**
  String get transportReachable;

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'our relay (onion)'**
  String get transportOurRelayOnion;

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'never'**
  String get transportNever2;

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get transportJustNow;

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{inMinutes}m ago'**
  String transportMAgo(Object inMinutes);

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{inHours}h ago'**
  String transportHAgo(Object inHours);

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{inDays}d ago'**
  String transportDAgo(Object inDays);

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{inMinutes}m'**
  String transportM(Object inMinutes);

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{inHours}h {d}m'**
  String transportHM(Object inHours, Object d);

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{inDays}d'**
  String transportD(Object inDays);

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{b} mb'**
  String transportMb(Object b);

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Yes · checked just now'**
  String get transportYesCheckedJustNow;

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'No · last {ago}'**
  String transportNoLast(Object ago);

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Last message in'**
  String get transportLastMessageIn;

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Battery exemption'**
  String get transportBatteryExemption;

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get transportUnknown;

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'exempt'**
  String get transportExempt;

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Not exempt · tap to fix'**
  String get transportNotExemptTapTo;

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'process up'**
  String get transportProcessUp;

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'last stop'**
  String get transportLastStop;

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{mb} · engine {mb2}'**
  String transportEngine(Object mb, Object mb2);

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Last relay arrival'**
  String get transportLastRelayArrival;

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'last check-in'**
  String get transportLastCheckIn;

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'None yet'**
  String get transportNoneYet;

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'last tor reconnect'**
  String get transportLastTorReconnect;

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'catch-up by relay'**
  String get transportCatchUpByRelay;

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'control port'**
  String get transportControlPort;

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{ctrl} dials · {ctrl2} timeouts'**
  String transportDialsTimeouts(Object ctrl, Object ctrl2);

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'job runs'**
  String get transportJobRuns;

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{jobRuns} · last {ago}'**
  String transportLast(Object jobRuns, Object ago);

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Quiet stretches'**
  String get transportQuietStretches;

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get transportNone;

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Clear this record'**
  String get transportClearThisRecord;

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Nothing yet this process'**
  String get transportNothingYetThisProcess;

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{mins}m'**
  String transportM2(Object mins);

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'{mins}h {mins2}m'**
  String transportHM2(Object mins, Object mins2);

  /// screens/transport_screen.dart
  ///
  /// In en, this message translates to:
  /// **'  {t} to {t2}'**
  String transportTo(Object t, Object t2);

  /// screens/vouchers_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'vouched by'**
  String get vouchersVouchedBy;

  /// screens/vouchers_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'vouched by {rowsLength}'**
  String vouchersVouchedBy2(Object rowsLength);

  /// screens/wallpaper_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Atmosphere'**
  String get wallpaperAtmosphere;

  /// screens/wallpaper_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Just for you. They see their own.'**
  String get wallpaperJustForYouThey;

  /// screens/wallpaper_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'your photo'**
  String get wallpaperYourPhoto;

  /// screens/wallpaper_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'From your photos'**
  String get wallpaperFromYourPhotos;

  /// screens/wallpaper_sheet.dart
  ///
  /// In en, this message translates to:
  /// **'Keep it'**
  String get wallpaperKeepIt;

  /// screens/why_kryfo_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Why kryfo'**
  String get whyKryfoWhyKryfo;

  /// screens/why_kryfo_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Kryfo · KREE-fo · greek for hidden.\nA quiet place to talk, built so no one is watching.'**
  String get whyKryfoKryfoKreeFoGreek;

  /// screens/why_kryfo_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Routed through tor'**
  String get whyKryfoRoutedThroughTor;

  /// screens/why_kryfo_screen.dart
  ///
  /// In en, this message translates to:
  /// **'By default every message travels through tor - a chain of relays. No one, not us and not your network, can see who you talk to or where you are.'**
  String get whyKryfoByDefaultEveryMessage;

  /// screens/why_kryfo_screen.dart
  ///
  /// In en, this message translates to:
  /// **'end-to-end encrypted'**
  String get whyKryfoEndToEndEncrypted;

  /// screens/why_kryfo_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Messages are sealed with keys only you and the person you are talking to hold. We could not read them if we tried.'**
  String get whyKryfoMessagesAreSealedWith;

  /// screens/why_kryfo_screen.dart
  ///
  /// In en, this message translates to:
  /// **'No servers holding your life'**
  String get whyKryfoNoServersHoldingYour;

  /// screens/why_kryfo_screen.dart
  ///
  /// In en, this message translates to:
  /// **'No account, no phone number, no central server storing your chats. They live on this phone, encrypted at rest.'**
  String get whyKryfoNoAccountNoPhone;

  /// screens/why_kryfo_screen.dart
  ///
  /// In en, this message translates to:
  /// **'nothing leaks'**
  String get whyKryfoNothingLeaks;

  /// screens/why_kryfo_screen.dart
  ///
  /// In en, this message translates to:
  /// **'No read receipts or typing tells handed to anyone, no contact list uploaded. Metadata is what most apps leak - kryfo is built not to.'**
  String get whyKryfoNoReadReceiptsOr;

  /// screens/why_kryfo_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Verify it is really them'**
  String get whyKryfoVerifyItIsReally;

  /// screens/why_kryfo_screen.dart
  ///
  /// In en, this message translates to:
  /// **'compare a safety number in person or over a channel you trust, so you know no one is impersonating your contact.'**
  String get whyKryfoCompareASafetyNumber;

  /// screens/why_kryfo_screen.dart
  ///
  /// In en, this message translates to:
  /// **'The honest part'**
  String get whyKryfoTheHonestPart;

  /// screens/why_kryfo_screen.dart
  ///
  /// In en, this message translates to:
  /// **'Kryfo is pre-alpha and has not been audited. The crypto is real but no outside expert has checked it yet, so treat it as a work in progress, not something to trust with your life yet.'**
  String get whyKryfoKryfoIsPreAlpha;

  /// supporter.dart
  ///
  /// In en, this message translates to:
  /// **'supporter'**
  String get supporterSupporter;

  /// supporter.dart
  ///
  /// In en, this message translates to:
  /// **'patron'**
  String get supporterPatron;

  /// supporter.dart
  ///
  /// In en, this message translates to:
  /// **'guardian'**
  String get supporterGuardian;

  /// tools/cleaner.dart
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get cleanerLocation;

  /// tools/cleaner.dart
  ///
  /// In en, this message translates to:
  /// **'already blanked by Android'**
  String get cleanerAlreadyBlankedByAndroid;

  /// tools/cleaner.dart
  ///
  /// In en, this message translates to:
  /// **'Phone model'**
  String get cleanerPhoneModel;

  /// tools/cleaner.dart
  ///
  /// In en, this message translates to:
  /// **'Time taken'**
  String get cleanerTimeTaken;

  /// tools/cleaner.dart
  ///
  /// In en, this message translates to:
  /// **'Serial number'**
  String get cleanerSerialNumber;

  /// tools/cleaner.dart
  ///
  /// In en, this message translates to:
  /// **'Owner name'**
  String get cleanerOwnerName;

  /// tools/cleaner.dart
  ///
  /// In en, this message translates to:
  /// **'Hidden thumbnail'**
  String get cleanerHiddenThumbnail;

  /// tools/cleaner.dart
  ///
  /// In en, this message translates to:
  /// **'Content credentials'**
  String get cleanerContentCredentials;

  /// tools/cleaner.dart
  ///
  /// In en, this message translates to:
  /// **'Data after the picture'**
  String get cleanerDataAfterThePicture;

  /// tools/cleaner.dart
  ///
  /// In en, this message translates to:
  /// **'1 other field'**
  String get cleaner1OtherField;

  /// tools/cleaner.dart
  ///
  /// In en, this message translates to:
  /// **'{other} other fields'**
  String cleanerOtherFields(Object other);

  /// tools/lock_words.dart
  ///
  /// In en, this message translates to:
  /// **'Four random words beat one clever one.'**
  String get lockWordsFourRandomWordsBeat;

  /// tools/lock_words.dart
  ///
  /// In en, this message translates to:
  /// **'Too short. At least {kMinPassLength} characters.'**
  String lockWordsTooShortAtLeast(Object kMinPassLength);

  /// tools/lock_words.dart
  ///
  /// In en, this message translates to:
  /// **'Weak. Whoever gets the file can guess as fast as they like.'**
  String get lockWordsWeakWhoeverGetsThe;

  /// tools/lock_words.dart
  ///
  /// In en, this message translates to:
  /// **'Fair. Longer is stronger.'**
  String get lockWordsFairLongerIsStronger;

  /// tools/lock_words.dart
  ///
  /// In en, this message translates to:
  /// **'Strong. Four random words beat one clever one.'**
  String get lockWordsStrongFourRandomWords;

  /// tools/lock_words.dart
  ///
  /// In en, this message translates to:
  /// **'{neutral}.age'**
  String lockWordsAge(Object neutral);

  /// tools/lock_words.dart
  ///
  /// In en, this message translates to:
  /// **'{cut}.age'**
  String lockWordsAge2(Object cut);

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'{m} km'**
  String photoStoryKm(Object m);

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'{m} metres'**
  String photoStoryMetres(Object m);

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'1 metre'**
  String get photoStory1Metre;

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'{r} metres'**
  String photoStoryMetres2(Object r);

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'Far from any town'**
  String get photoStoryFarFromAnyTown;

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'Near {where}'**
  String photoStoryNear(Object where);

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'About {near} km from {where}'**
  String photoStoryAboutKmFrom(Object near, Object where);

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'{s} s'**
  String photoStoryS(Object s);

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'1/{s} s'**
  String photoStory1S(Object s);

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'Not a kind Kryfo can read.'**
  String get photoStoryNotAKindKryfo;

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'So it will not guess.'**
  String get photoStorySoItWillNot;

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'This file is damaged or cut short.'**
  String get photoStoryThisFileIsDamaged;

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'Kryfo could not read it to the end.'**
  String get photoStoryKryfoCouldNotRead;

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'Where it was recorded'**
  String get photoStoryWhereItWasRecorded;

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'Where it was taken'**
  String get photoStoryWhereItWasTaken;

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'Location: {coordsLine}'**
  String photoStoryLocation(Object coordsLine);

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'Height above the sea: {fix} m'**
  String photoStoryHeightAboveTheSea(Object fix);

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'Location hidden by Android'**
  String get photoStoryLocationHiddenByAndroid;

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'Android blanks it when a photo is picked this way. Sharing it to Kryfo from your gallery often keeps it. The one in your gallery may still have it.'**
  String get photoStoryAndroidBlanksItWhen;

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'Location: blanked by Android before Kryfo saw it'**
  String get photoStoryLocationBlankedByAndroid;

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'f/{r}'**
  String photoStoryF(Object r);

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'What took it'**
  String get photoStoryWhatTookIt;

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'Phone or camera: {phone}'**
  String photoStoryPhoneOrCamera(Object phone);

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'When it was recorded'**
  String get photoStoryWhenItWasRecorded;

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'To the second, with the time zone'**
  String get photoStoryToTheSecondWith;

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'To the second'**
  String get photoStoryToTheSecond;

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'Time: {dateFormat}'**
  String photoStoryTime(Object dateFormat);

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'Lens'**
  String get photoStoryLens;

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'Lens: {lens}'**
  String photoStoryLens2(Object lens);

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'Software'**
  String get photoStorySoftware;

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'Software: {software}'**
  String photoStorySoftware2(Object software);

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'Serial number'**
  String get photoStorySerialNumber;

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'Serial number: {serial}'**
  String photoStorySerialNumber2(Object serial);

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'Owner name'**
  String get photoStoryOwnerName;

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'Owner: {r}'**
  String photoStoryOwner(Object r);

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'Hidden thumbnail'**
  String get photoStoryHiddenThumbnail;

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'A small copy of the picture inside the file. It can show what a crop removed'**
  String get photoStoryASmallCopyOf;

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'Maker notes'**
  String get photoStoryMakerNotes;

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'Maker notes: a block only the maker can read'**
  String get photoStoryMakerNotesABlock;

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'Editing history'**
  String get photoStoryEditingHistory;

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'XMP: editing history and tags'**
  String get photoStoryXmpEditingHistoryAnd;

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'Captions'**
  String get photoStoryCaptions;

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'IPTC: captions and credits'**
  String get photoStoryIptcCaptionsAndCredits;

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get photoStoryComment;

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'A written comment'**
  String get photoStoryAWrittenComment;

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'Content credentials'**
  String get photoStoryContentCredentials;

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'Second picture'**
  String get photoStorySecondPicture;

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'A second picture inside the file'**
  String get photoStoryASecondPictureInside;

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'Motion video'**
  String get photoStoryMotionVideo;

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'A short video inside the file'**
  String get photoStoryAShortVideoInside;

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'Save time'**
  String get photoStorySaveTime;

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'The time it was last saved'**
  String get photoStoryTheTimeItWas;

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'Time stamps'**
  String get photoStoryTimeStamps;

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'Creation time stamps'**
  String get photoStoryCreationTimeStamps;

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'Data after the picture'**
  String get photoStoryDataAfterThePicture;

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'Data after the end of the picture: {trailingBytes} bytes'**
  String photoStoryDataAfterTheEnd(Object trailingBytes);

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'Text field: {k}'**
  String photoStoryTextField(Object k);

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'Video tag: {k}'**
  String photoStoryVideoTag(Object k);

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'Also: {k}'**
  String photoStoryAlso(Object k);

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'{otherExifTags} camera settings (flash, focus, exposure)'**
  String photoStoryCameraSettingsFlashFocus(Object otherExifTags);

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'1 more field'**
  String get photoStory1MoreField;

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'{more} more fields'**
  String photoStoryMoreFields(Object more);

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'Camera settings'**
  String get photoStoryCameraSettings;

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'Accurate to about {metres}.'**
  String photoStoryAccurateToAbout(Object metres);

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'Enough to find the door.'**
  String get photoStoryEnoughToFindThe;

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'Enough to find the street.'**
  String get photoStoryEnoughToFindTheStreet;

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'Enough to find the area.'**
  String get photoStoryEnoughToFindTheArea;

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'It knows where you were.'**
  String get photoStoryItKnowsWhereYou;

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'Down to the building.'**
  String get photoStoryDownToTheBuilding;

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'Android hid the location.'**
  String get photoStoryAndroidHidTheLocation;

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'The original may still carry it.'**
  String get photoStoryTheOriginalMayStill;

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'No location in this one.'**
  String get photoStoryNoLocationInThis;

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'It still says plenty.'**
  String get photoStoryItStillSaysPlenty;

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'This one knows nothing.'**
  String get photoStoryThisOneKnowsNothing;

  /// tools/photo_story.dart
  ///
  /// In en, this message translates to:
  /// **'Nothing to remove.'**
  String get photoStoryNothingToRemove;

  /// tools/qr_payload.dart
  ///
  /// In en, this message translates to:
  /// **'OPENS A LINK'**
  String get qrPayloadOpensALink;

  /// tools/qr_payload.dart
  ///
  /// In en, this message translates to:
  /// **'OPENS {host}'**
  String qrPayloadOpens(Object host);

  /// tools/qr_payload.dart
  ///
  /// In en, this message translates to:
  /// **'SHOWS A NOTE'**
  String get qrPayloadShowsANote;

  /// tools/qr_payload.dart
  ///
  /// In en, this message translates to:
  /// **'SCAN TO JOIN'**
  String get qrPayloadScanToJoin;

  /// tools/qr_payload.dart
  ///
  /// In en, this message translates to:
  /// **'SCAN TO JOIN · {oneLine}'**
  String qrPayloadScanToJoin2(Object oneLine);

  /// tools/qr_payload.dart
  ///
  /// In en, this message translates to:
  /// **'A network name is 32 characters at most.'**
  String get qrPayloadANetworkNameIs;

  /// tools/qr_payload.dart
  ///
  /// In en, this message translates to:
  /// **'A Wi-Fi password has at least 8 characters.'**
  String get qrPayloadAWiFiPassword;

  /// tools/qr_payload.dart
  ///
  /// In en, this message translates to:
  /// **'P:{escapeWifi};'**
  String qrPayloadP(Object escapeWifi);

  /// tools/qr_payload.dart
  ///
  /// In en, this message translates to:
  /// **'WIFI:T:{type};S:{escapeWifi};{p};'**
  String qrPayloadWifiTS(Object type, Object escapeWifi, Object p);

  /// tools/qr_payload.dart
  ///
  /// In en, this message translates to:
  /// **'SAVES A CONTACT'**
  String get qrPayloadSavesAContact;

  /// tools/qr_payload.dart
  ///
  /// In en, this message translates to:
  /// **'VERSION:3.0'**
  String get qrPayloadVersion30;

  /// tools/qr_payload.dart
  ///
  /// In en, this message translates to:
  /// **'N:{escapeVcard};;;;'**
  String qrPayloadN(Object escapeVcard);

  /// tools/qr_payload.dart
  ///
  /// In en, this message translates to:
  /// **'FN:{escapeVcard}'**
  String qrPayloadFn(Object escapeVcard);

  /// tools/qr_payload.dart
  ///
  /// In en, this message translates to:
  /// **'TEL;TYPE=CELL:{tel}'**
  String qrPayloadTelTypeCell(Object tel);

  /// tools/qr_payload.dart
  ///
  /// In en, this message translates to:
  /// **'EMAIL:{escapeVcard}'**
  String qrPayloadEmail(Object escapeVcard);

  /// tools/qr_payload.dart
  ///
  /// In en, this message translates to:
  /// **'END:VCARD'**
  String get qrPayloadEndVcard;

  /// tools/qr_payload.dart
  ///
  /// In en, this message translates to:
  /// **'WRITES AN EMAIL'**
  String get qrPayloadWritesAnEmail;

  /// tools/qr_payload.dart
  ///
  /// In en, this message translates to:
  /// **'That does not look like an email address.'**
  String get qrPayloadThatDoesNotLook;

  /// tools/qr_payload.dart
  ///
  /// In en, this message translates to:
  /// **'?subject={uri}'**
  String qrPayloadSubject(Object uri);

  /// tools/qr_payload.dart
  ///
  /// In en, this message translates to:
  /// **'CALLS A NUMBER'**
  String get qrPayloadCallsANumber;

  /// tools/qr_payload.dart
  ///
  /// In en, this message translates to:
  /// **'WRITES A TEXT'**
  String get qrPayloadWritesAText;

  /// tools/qr_payload.dart
  ///
  /// In en, this message translates to:
  /// **'SMSTO:{n}'**
  String qrPayloadSmsto(Object n);

  /// tools/qr_payload.dart
  ///
  /// In en, this message translates to:
  /// **'SMSTO:{n}:{body}'**
  String qrPayloadSmsto2(Object n, Object body);

  /// tools/qr_payload.dart
  ///
  /// In en, this message translates to:
  /// **'OPENS A MAP'**
  String get qrPayloadOpensAMap;

  /// tools/qr_payload.dart
  ///
  /// In en, this message translates to:
  /// **'Latitude runs from -90 to 90, longitude from -180 to 180.'**
  String get qrPayloadLatitudeRunsFrom90;

  /// tools/qr_payload.dart
  ///
  /// In en, this message translates to:
  /// **'geo:{trim},{trim2}'**
  String qrPayloadGeo(Object trim, Object trim2);

  /// tools/qr_payload.dart
  ///
  /// In en, this message translates to:
  /// **'PAY THIS ADDRESS'**
  String get qrPayloadPayThisAddress;

  /// tools/qr_payload.dart
  ///
  /// In en, this message translates to:
  /// **'A bitcoin address is letters and digits only.'**
  String get qrPayloadABitcoinAddressIs;

  /// tools/qr_payload.dart
  ///
  /// In en, this message translates to:
  /// **'bitcoin:{addr}'**
  String qrPayloadBitcoin(Object addr);

  /// tools/qr_payload.dart
  ///
  /// In en, this message translates to:
  /// **'The amount is in BTC, with up to 8 decimals.'**
  String get qrPayloadTheAmountIsIn;

  /// tools/qr_payload.dart
  ///
  /// In en, this message translates to:
  /// **'bitcoin:{addr}?amount={raw}'**
  String qrPayloadBitcoinAmount(Object addr, Object raw);

  /// vouch_text.dart
  ///
  /// In en, this message translates to:
  /// **'{names} and {names2}'**
  String vouchTextAnd(Object names, Object names2);

  /// vouch_text.dart
  ///
  /// In en, this message translates to:
  /// **'{names}, {names2} and {rest} other{rest2} you know'**
  String vouchTextAndOtherYouKnow(
    Object names,
    Object names2,
    Object rest,
    Object rest2,
  );

  /// vouch_text.dart
  ///
  /// In en, this message translates to:
  /// **'Vouched by {vouchNames}'**
  String vouchTextVouchedBy(Object vouchNames);

  /// vouch_text.dart
  ///
  /// In en, this message translates to:
  /// **'Introduced by {vouchNames}'**
  String vouchTextIntroducedBy(Object vouchNames);

  /// vouch_text.dart
  ///
  /// In en, this message translates to:
  /// **'this shares {a}\'s address with {b}'**
  String vouchTextThisSharesSAddress(Object a, Object b);

  /// widgets/boot_failed.dart
  ///
  /// In en, this message translates to:
  /// **'Kryfo could not start'**
  String get bootFailedKryfoCouldNotStart;

  /// widgets/boot_failed.dart
  ///
  /// In en, this message translates to:
  /// **'This is a fault on this device, not the network. Tor is not involved.'**
  String get bootFailedThisIsAFault;

  /// widgets/kryfo_link_text.dart
  ///
  /// In en, this message translates to:
  /// **'That link is not one kryfo can read'**
  String get kryfoLinkTextThatLinkIsNot;

  /// widgets/kryfo_link_text.dart
  ///
  /// In en, this message translates to:
  /// **'Add {who}?'**
  String kryfoLinkTextAdd(Object who);

  /// widgets/kryfo_link_text.dart
  ///
  /// In en, this message translates to:
  /// **'This is an invite to talk to {who}. Add them only if you know where the link came from.'**
  String kryfoLinkTextThisIsAnInvite(Object who);

  /// widgets/kryfo_link_text.dart
  ///
  /// In en, this message translates to:
  /// **'Add them'**
  String get kryfoLinkTextAddThem;

  /// widgets/kryfo_link_text.dart
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get kryfoLinkTextNotNow;

  /// widgets/kryfo_link_text.dart
  ///
  /// In en, this message translates to:
  /// **'Join {roomName}'**
  String kryfoLinkTextJoin(Object roomName);

  /// widgets/kryfo_link_text.dart
  ///
  /// In en, this message translates to:
  /// **'kryfo link'**
  String get kryfoLinkTextKryfoLink;

  /// widgets/kryfo_link_text.dart
  ///
  /// In en, this message translates to:
  /// **'Add {who}'**
  String kryfoLinkTextAdd2(Object who);

  /// widgets/kryfo_link_text.dart
  ///
  /// In en, this message translates to:
  /// **'BURNER ROOM'**
  String get kryfoLinkTextBurnerRoom;

  /// widgets/kryfo_link_text.dart
  ///
  /// In en, this message translates to:
  /// **'This room has closed'**
  String get kryfoLinkTextThisRoomHasClosed;

  /// widgets/kryfo_link_text.dart
  ///
  /// In en, this message translates to:
  /// **'Closes in {countdownLabel}{room}'**
  String kryfoLinkTextClosesIn(Object countdownLabel, Object room);

  /// widgets/kryfo_link_text.dart
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get kryfoLinkTextJoin2;

  /// widgets/kryfo_link_text.dart
  ///
  /// In en, this message translates to:
  /// **'You join under a key made for this room. Nobody in it sees your kryfo id.'**
  String get kryfoLinkTextYouJoinUnderA;

  /// widgets/link_stub.dart
  ///
  /// In en, this message translates to:
  /// **'Fetched over tor · by your device'**
  String get linkStubFetchedOverTorBy;

  /// widgets/link_stub.dart
  ///
  /// In en, this message translates to:
  /// **'Fetched over tor · by their device'**
  String get linkStubFetchedOverTorByTheirDevice;

  /// widgets/media_bubbles.dart
  ///
  /// In en, this message translates to:
  /// **'{bytes} b'**
  String mediaBubblesB(Object bytes);

  /// widgets/media_bubbles.dart
  ///
  /// In en, this message translates to:
  /// **'{bytes} kb'**
  String mediaBubblesKb(Object bytes);

  /// widgets/media_bubbles.dart
  ///
  /// In en, this message translates to:
  /// **'{bytes} mb'**
  String mediaBubblesMb(Object bytes);

  /// widgets/media_bubbles.dart
  ///
  /// In en, this message translates to:
  /// **'FILE'**
  String get mediaBubblesFile;

  /// widgets/media_bubbles.dart
  ///
  /// In en, this message translates to:
  /// **'Audio unavailable'**
  String get mediaBubblesAudioUnavailable;

  /// widgets/media_bubbles.dart
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get mediaBubblesHidden;

  /// widgets/media_bubbles.dart
  ///
  /// In en, this message translates to:
  /// **'Mic permission needed'**
  String get mediaBubblesMicPermissionNeeded;

  /// widgets/media_bubbles.dart
  ///
  /// In en, this message translates to:
  /// **'{path}/vn_{dateTime}.wav'**
  String mediaBubblesVnWav(Object path, Object dateTime);

  /// widgets/media_bubbles.dart
  ///
  /// In en, this message translates to:
  /// **'Release to cancel'**
  String get mediaBubblesReleaseToCancel;

  /// widgets/media_bubbles.dart
  ///
  /// In en, this message translates to:
  /// **'Voice hidden · slide to cancel'**
  String get mediaBubblesVoiceHiddenSlideTo;

  /// widgets/media_bubbles.dart
  ///
  /// In en, this message translates to:
  /// **'Slide to cancel'**
  String get mediaBubblesSlideToCancel;

  /// widgets/media_bubbles.dart
  ///
  /// In en, this message translates to:
  /// **'Send photo'**
  String get mediaBubblesSendPhoto;

  /// widgets/media_bubbles.dart
  ///
  /// In en, this message translates to:
  /// **'Add a caption…'**
  String get mediaBubblesAddACaption;

  /// widgets/motion.dart
  ///
  /// In en, this message translates to:
  /// **'STANDBY'**
  String get motionStandby;

  /// widgets/motion.dart
  ///
  /// In en, this message translates to:
  /// **'CONNECTING'**
  String get motionConnecting;

  /// widgets/motion.dart
  ///
  /// In en, this message translates to:
  /// **'BUILDING'**
  String get motionBuilding;

  /// widgets/motion.dart
  ///
  /// In en, this message translates to:
  /// **'PUBLISHING'**
  String get motionPublishing;

  /// widgets/motion.dart
  ///
  /// In en, this message translates to:
  /// **'READY'**
  String get motionReady;

  /// widgets/motion.dart
  ///
  /// In en, this message translates to:
  /// **'Preparing to connect'**
  String get motionPreparingToConnect;

  /// widgets/motion.dart
  ///
  /// In en, this message translates to:
  /// **'Finding a private path'**
  String get motionFindingAPrivatePath;

  /// widgets/motion.dart
  ///
  /// In en, this message translates to:
  /// **'Carving the path'**
  String get motionCarvingThePath;

  /// widgets/motion.dart
  ///
  /// In en, this message translates to:
  /// **'Announcing your arrival'**
  String get motionAnnouncingYourArrival;

  /// widgets/motion.dart
  ///
  /// In en, this message translates to:
  /// **'you\'re anonymous'**
  String get motionYouReAnonymous;

  /// widgets/motion.dart
  ///
  /// In en, this message translates to:
  /// **'Tor is starting in the background. This graph lights up as the connection forms.'**
  String get motionTorIsStartingIn;

  /// widgets/motion.dart
  ///
  /// In en, this message translates to:
  /// **'Making a fresh route through anonymous relays.'**
  String get motionMakingAFreshRoute;

  /// widgets/motion.dart
  ///
  /// In en, this message translates to:
  /// **'Bouncing through relays so no one can trace this back to you.'**
  String get motionBouncingThroughRelaysSo;

  /// widgets/motion.dart
  ///
  /// In en, this message translates to:
  /// **'telling the network you\'re online — without revealing where.'**
  String get motionTellingTheNetworkYou;

  /// widgets/motion.dart
  ///
  /// In en, this message translates to:
  /// **'Your ip is hidden. Only people with your kryfo can reach you.'**
  String get motionYourIpIsHidden;

  /// widgets/motion.dart
  ///
  /// In en, this message translates to:
  /// **'building'**
  String get motionBuilding2;

  /// widgets/motion.dart
  ///
  /// In en, this message translates to:
  /// **'open'**
  String get motionOpen;

  /// widgets/motion.dart
  ///
  /// In en, this message translates to:
  /// **'live'**
  String get motionLive;

  /// widgets/motion.dart
  ///
  /// In en, this message translates to:
  /// **'Circuit · '**
  String get motionCircuit;

  /// widgets/motion.dart
  ///
  /// In en, this message translates to:
  /// **'delivered'**
  String get motionDelivered;

  /// widgets/motion.dart
  ///
  /// In en, this message translates to:
  /// **'sent'**
  String get motionSent;

  /// widgets/motion.dart
  ///
  /// In en, this message translates to:
  /// **'1 hop'**
  String get motion1Hop;

  /// widgets/motion.dart
  ///
  /// In en, this message translates to:
  /// **'3 hops'**
  String get motion3Hops;

  /// widgets/moved_strip.dart
  ///
  /// In en, this message translates to:
  /// **'This kryfo has moved to another device. Nothing sent from here reaches anyone.'**
  String get movedStripThisKryfoHasMoved;

  /// widgets/nav_bar.dart
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get navBarChats;

  /// widgets/nav_bar.dart
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get navBarTools;

  /// widgets/nav_bar.dart
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get navBarSupport;

  /// widgets/nav_bar.dart
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get navBarMe;

  /// widgets/pair_code_panel.dart
  ///
  /// In en, this message translates to:
  /// **'Putting your invite in place'**
  String get pairCodePanelPuttingYourInviteIn;

  /// widgets/pair_code_panel.dart
  ///
  /// In en, this message translates to:
  /// **'Your invite is not ready yet'**
  String get pairCodePanelYourInviteIsNot;

  /// widgets/pair_code_panel.dart
  ///
  /// In en, this message translates to:
  /// **'Read six digits out loud and they can add you. Nothing else needs to change hands.'**
  String get pairCodePanelReadSixDigitsOut;

  /// widgets/pair_code_panel.dart
  ///
  /// In en, this message translates to:
  /// **'Working'**
  String get pairCodePanelWorking;

  /// widgets/pair_code_panel.dart
  ///
  /// In en, this message translates to:
  /// **'Or make a six digit code to read out'**
  String get pairCodePanelOrMakeASix;

  /// widgets/pair_code_panel.dart
  ///
  /// In en, this message translates to:
  /// **'Code copied'**
  String get pairCodePanelCodeCopied;

  /// widgets/pair_code_panel.dart
  ///
  /// In en, this message translates to:
  /// **'Burns in {mm}:{ss}'**
  String pairCodePanelBurnsIn(Object mm, Object ss);

  /// widgets/pair_code_panel.dart
  ///
  /// In en, this message translates to:
  /// **'They tap add, choose code, and type these.'**
  String get pairCodePanelTheyTapAddChoose;

  /// widgets/pair_code_panel.dart
  ///
  /// In en, this message translates to:
  /// **'They open kryfo, tap add, choose pairing code and type these six digits. Make a new one for the next person.'**
  String get pairCodePanelTheyOpenKryfoTap;

  /// widgets/pins.dart
  ///
  /// In en, this message translates to:
  /// **'Pinned messages · {count}'**
  String pinsPinnedMessages(Object count);

  /// widgets/pins.dart
  ///
  /// In en, this message translates to:
  /// **'Pinned messages'**
  String get pinsPinnedMessages2;

  /// widgets/pins.dart
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get pinsPhoto;

  /// widgets/pins.dart
  ///
  /// In en, this message translates to:
  /// **'Voice message'**
  String get pinsVoiceMessage;

  /// widgets/pins.dart
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get pinsMessage;

  /// widgets/pins.dart
  ///
  /// In en, this message translates to:
  /// **'Jan'**
  String get pinsJan;

  /// widgets/pins.dart
  ///
  /// In en, this message translates to:
  /// **'Feb'**
  String get pinsFeb;

  /// widgets/pins.dart
  ///
  /// In en, this message translates to:
  /// **'Mar'**
  String get pinsMar;

  /// widgets/pins.dart
  ///
  /// In en, this message translates to:
  /// **'Apr'**
  String get pinsApr;

  /// widgets/pins.dart
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get pinsMay;

  /// widgets/pins.dart
  ///
  /// In en, this message translates to:
  /// **'Jun'**
  String get pinsJun;

  /// widgets/pins.dart
  ///
  /// In en, this message translates to:
  /// **'Jul'**
  String get pinsJul;

  /// widgets/pins.dart
  ///
  /// In en, this message translates to:
  /// **'Aug'**
  String get pinsAug;

  /// widgets/pins.dart
  ///
  /// In en, this message translates to:
  /// **'Sep'**
  String get pinsSep;

  /// widgets/pins.dart
  ///
  /// In en, this message translates to:
  /// **'Oct'**
  String get pinsOct;

  /// widgets/pins.dart
  ///
  /// In en, this message translates to:
  /// **'Nov'**
  String get pinsNov;

  /// widgets/pins.dart
  ///
  /// In en, this message translates to:
  /// **'Dec'**
  String get pinsDec;

  /// widgets/pins.dart
  ///
  /// In en, this message translates to:
  /// **'Today · {hm}'**
  String pinsToday(Object hm);

  /// widgets/pins.dart
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get pinsPinned;

  /// widgets/pins.dart
  ///
  /// In en, this message translates to:
  /// **'{pinsLength} of {kMaxPins}'**
  String pinsOf(Object pinsLength, Object kMaxPins);

  /// widgets/pins.dart
  ///
  /// In en, this message translates to:
  /// **'Nothing pinned here yet. Hold a message and choose Pin, and it waits here for everyone in the chat.'**
  String get pinsNothingPinnedHereYet;

  /// widgets/pins.dart
  ///
  /// In en, this message translates to:
  /// **'Jump'**
  String get pinsJump;

  /// widgets/pins.dart
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get pinsUnpin;

  /// widgets/pow_note.dart
  ///
  /// In en, this message translates to:
  /// **'First message to someone new · proving it is real · {s}s{s2}'**
  String powNoteFirstMessageToSomeone(Object s, Object s2);

  /// widgets/preview_strip.dart
  ///
  /// In en, this message translates to:
  /// **'{domainOf} · fetched over tor'**
  String previewStripFetchedOverTor(Object domainOf);

  /// widgets/preview_strip.dart
  ///
  /// In en, this message translates to:
  /// **'Drop the preview'**
  String get previewStripDropThePreview;

  /// widgets/preview_strip.dart
  ///
  /// In en, this message translates to:
  /// **'Add preview'**
  String get previewStripAddPreview;

  /// widgets/preview_strip.dart
  ///
  /// In en, this message translates to:
  /// **'Fetching over tor…'**
  String get previewStripFetchingOverTor;

  /// widgets/tool_parts.dart
  ///
  /// In en, this message translates to:
  /// **'{bytes} B'**
  String toolPartsB(Object bytes);

  /// widgets/tool_parts.dart
  ///
  /// In en, this message translates to:
  /// **'{bytes} KB'**
  String toolPartsKb(Object bytes);

  /// widgets/tool_parts.dart
  ///
  /// In en, this message translates to:
  /// **'{mb} MB'**
  String toolPartsMb(Object mb);

  /// widgets/tor_boot_splash.dart
  ///
  /// In en, this message translates to:
  /// **'No shortcuts, no traces'**
  String get torBootSplashNoShortcutsNoTraces;

  /// widgets/tor_boot_splash.dart
  ///
  /// In en, this message translates to:
  /// **'The network that keeps you private is warming up'**
  String get torBootSplashTheNetworkThatKeeps;

  /// widgets/tor_boot_splash.dart
  ///
  /// In en, this message translates to:
  /// **'Made on this phone. Nothing is sent anywhere.'**
  String get torBootSplashMadeOnThisPhone;

  /// widgets/tor_boot_splash.dart
  ///
  /// In en, this message translates to:
  /// **'First launch takes a moment · only on startup'**
  String get torBootSplashFirstLaunchTakesA;

  /// widgets/video_bubble.dart
  ///
  /// In en, this message translates to:
  /// **'Nothing here opens that · sharing instead'**
  String get videoBubbleNothingHereOpensThat;

  /// widgets/video_bubble.dart
  ///
  /// In en, this message translates to:
  /// **'{b} MB'**
  String videoBubbleMb(Object b);

  /// widgets/video_bubble.dart
  ///
  /// In en, this message translates to:
  /// **'{b} KB'**
  String videoBubbleKb(Object b);

  /// widgets/video_bubble.dart
  ///
  /// In en, this message translates to:
  /// **'v:{path}'**
  String videoBubbleV(Object path);

  /// widgets/video_bubble.dart
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get videoBubbleVideo;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
