// SPDX-License-Identifier: GPL-3.0-or-later
// words that name the phone, with a computer's own where the meaning differs.
// the phone's words never change: each pair is <key> and <key>Desk
import '../desktop/desktop_mode.dart' show onDesktop;
import 'app_localizations.dart';

/// the keys that have a computer's wording, for the tests
const deskWordKeys = [
  'appearanceWallpaperHint',
  'appAnAttachmentCouldNot',
  'appScanTheirCodeOr',
  'backupACopyToKeep',
  'backupTheFileTakesThis',
  'backupOneEncryptedFileYourIdentityYour',
  'backupMoveReachedTitle',
  'backupMoveReachedLine',
  'backupNoSpace',
  'backupMoveHiddenStay',
  'chatItDisappearsWithNo',
  'chatGifFromPhone',
  'chatJustForYouNever',
  'chatEveryMessageHereIs',
  'chatAlbumItDisappearsWithNo',
  'contactStaysOnThisPhone',
  'contactMessagesAndContactGone',
  'contactEveryMessageAndThe',
  'donateGivesReceipt',
  'groupChatItDisappearsWithNo',
  'groupChatGifFromPhone',
  'groupChatAlbumItDisappearsWithNo',
  'groupInfoEveryMessageHereIs',
  'groupInfoEverythingInItIs',
  'groupInfoLeaveGroupLine',
  'groupInfoLeaveGroupAdmin',
  'groupInfoLeaveRoomMaker',
  'groupInfoEndGroupLine',
  'groupInfoEndGroupDetail',
  'groupAdminGoneLine',
  'handleIsNotYoursOn',
  'handleTheRegistryHoldsIt',
  'handleForgetItOnThis',
  'handleCheckClock',
  'homeScanTheirCodeSend',
  'homeMessagesAndContactGone',
  'homeEveryMessageWithGoes',
  'homeOnlyOnThisPhone',
  'linkNoAppOpens',
  'movedWipeThisPhone',
  'movedKryfoWillCloseNow',
  'movedIsNowOnAnother',
  'movedWipeThisPhone2',
  'notesDeleteAllLine',
  'notesGoneFromThisPhone',
  'notesOnlyOnThisPhone',
  'notesJotAnythingDownIt',
  'notesExportHoldsInstaller',
  'onboardingGeneratedFromAKey',
  'onboardingYourIdentityLivesOn',
  'pairCodeNumberMatches',
  'restoreReplaceTheAccountOn',
  'restoreTheRegistryDidNot',
  'restoreKryfoWillCloseNow',
  'restoreAnythingSentToYou',
  'restoreTheOldPhoneStops',
  'restoreIfThePhoneThis',
  'restoreABackupBringsBack',
  'roomCreateARoomThatEnds',
  'savedChatGone',
  'seenScamShieldRequestsOnly',
  'seenAPreviewIsFetched',
  'seenASeizedUnlockedPhone',
  'seenIfSomeoneHoldsYour',
  'seenHonestAboutTheLast',
  'settingsIdentityMessagesContactsAnd',
  'settingsWipeKryfoFromThis',
  'settingsScamShieldHint',
  'transportNothingHereLeavesThe',
  'transportWithNoContactsThe',
  'whyKryfoNoAccountNoPhone',
  'bootFailedKeysDidNotAnswer',
  'bootFailedStartFreshLine',
  'bootFailedStartFreshSure',
  'torBootSplashMadeOnThisPhone',
  'bridgesPasteTheLineThey',
  'bridgesPasteOrScanALine',
  'languageMatchPhone',
  'languageMatchPhoneValue',
  'videoViewerCannotPlay',
  'searchIntroLine',
  'inviteNotYet',
  'devWhoAnon',
  'devWhoNothingYet',
  'devNamelessLine',
  'nameTakenTombLine',
  'notThemSheetLine',
  'gifOptInWhereToTurnOff',
  'gifSavedOnPhone',
  'gifPhoneTab',
  'gifPhoneLine',
  'voiceNoRoom',
  'translatePackTitle',
  'translatePackLine',
  'translatePackNoLib',
  'translateInstalled',
  'translateNeedsWifi',
  'translateFailNoEngine',
  'translateSettingsHint',
  'translatePrivacyNote',
  'notificationsLead',
  'photoOnlyHere',
  'photoOnlyHereLine',
  'myKryfoPointYourPhonesAt',
  'pinsThePinGoesAnd',
  'pinsTurnOffWithDecoy',
  'pinsAdvancedLine',
  'pinsWipeLine',
  'flowWipe1',
  'flowLaw',
  'flowVaultReplace',
  'howVault',
  'flowVaultPassLine',
  'flowDecoyShade',
  'bridgesThisNetworkWantsA',
];

extension DeskWords on AppLocalizations {
  String get appearanceWallpaperHintShown =>
      onDesktop ? appearanceWallpaperHintDesk : appearanceWallpaperHint;
  String get appAnAttachmentCouldNotShown =>
      onDesktop ? appAnAttachmentCouldNotDesk : appAnAttachmentCouldNot;
  String get appScanTheirCodeOrShown =>
      onDesktop ? appScanTheirCodeOrDesk : appScanTheirCodeOr;
  String get backupACopyToKeepShown =>
      onDesktop ? backupACopyToKeepDesk : backupACopyToKeep;
  String get backupTheFileTakesThisShown =>
      onDesktop ? backupTheFileTakesThisDesk : backupTheFileTakesThis;
  String get backupOneEncryptedFileYourIdentityYourShown => onDesktop
      ? backupOneEncryptedFileYourIdentityYourDesk
      : backupOneEncryptedFileYourIdentityYour;
  String get backupMoveReachedTitleShown =>
      onDesktop ? backupMoveReachedTitleDesk : backupMoveReachedTitle;
  String get backupMoveReachedLineShown =>
      onDesktop ? backupMoveReachedLineDesk : backupMoveReachedLine;
  String get backupNoSpaceShown =>
      onDesktop ? backupNoSpaceDesk : backupNoSpace;
  String get backupMoveHiddenStayShown =>
      onDesktop ? backupMoveHiddenStayDesk : backupMoveHiddenStay;
  String get chatItDisappearsWithNoShown =>
      onDesktop ? chatItDisappearsWithNoDesk : chatItDisappearsWithNo;
  String get chatGifFromPhoneShown =>
      onDesktop ? chatGifFromPhoneDesk : chatGifFromPhone;
  String get chatJustForYouNeverShown =>
      onDesktop ? chatJustForYouNeverDesk : chatJustForYouNever;
  String get chatEveryMessageHereIsShown =>
      onDesktop ? chatEveryMessageHereIsDesk : chatEveryMessageHereIs;
  String get chatAlbumItDisappearsWithNoShown =>
      onDesktop ? chatAlbumItDisappearsWithNoDesk : chatAlbumItDisappearsWithNo;
  String get contactStaysOnThisPhoneShown =>
      onDesktop ? contactStaysOnThisPhoneDesk : contactStaysOnThisPhone;
  String get contactMessagesAndContactGoneShown => onDesktop
      ? contactMessagesAndContactGoneDesk
      : contactMessagesAndContactGone;
  String get contactEveryMessageAndTheShown =>
      onDesktop ? contactEveryMessageAndTheDesk : contactEveryMessageAndThe;
  String get donateGivesReceiptShown =>
      onDesktop ? donateGivesReceiptDesk : donateGivesReceipt;
  String get groupChatItDisappearsWithNoShown =>
      onDesktop ? groupChatItDisappearsWithNoDesk : groupChatItDisappearsWithNo;
  String get groupChatGifFromPhoneShown =>
      onDesktop ? groupChatGifFromPhoneDesk : groupChatGifFromPhone;
  String get groupChatAlbumItDisappearsWithNoShown => onDesktop
      ? groupChatAlbumItDisappearsWithNoDesk
      : groupChatAlbumItDisappearsWithNo;
  String get groupInfoEveryMessageHereIsShown =>
      onDesktop ? groupInfoEveryMessageHereIsDesk : groupInfoEveryMessageHereIs;
  String get groupInfoEverythingInItIsShown =>
      onDesktop ? groupInfoEverythingInItIsDesk : groupInfoEverythingInItIs;
  String get groupInfoLeaveGroupLineShown =>
      onDesktop ? groupInfoLeaveGroupLineDesk : groupInfoLeaveGroupLine;
  String get groupInfoLeaveGroupAdminShown =>
      onDesktop ? groupInfoLeaveGroupAdminDesk : groupInfoLeaveGroupAdmin;
  String get groupInfoLeaveRoomMakerShown =>
      onDesktop ? groupInfoLeaveRoomMakerDesk : groupInfoLeaveRoomMaker;
  String get groupInfoEndGroupLineShown =>
      onDesktop ? groupInfoEndGroupLineDesk : groupInfoEndGroupLine;
  String get groupInfoEndGroupDetailShown =>
      onDesktop ? groupInfoEndGroupDetailDesk : groupInfoEndGroupDetail;
  String get groupAdminGoneLineShown =>
      onDesktop ? groupAdminGoneLineDesk : groupAdminGoneLine;
  String handleIsNotYoursOnShown(Object handle) =>
      onDesktop ? handleIsNotYoursOnDesk(handle) : handleIsNotYoursOn(handle);
  String handleTheRegistryHoldsItShown(Object handle) => onDesktop
      ? handleTheRegistryHoldsItDesk(handle)
      : handleTheRegistryHoldsIt(handle);
  String get handleForgetItOnThisShown =>
      onDesktop ? handleForgetItOnThisDesk : handleForgetItOnThis;
  String get handleCheckClockShown =>
      onDesktop ? handleCheckClockDesk : handleCheckClock;
  String get homeScanTheirCodeSendShown =>
      onDesktop ? homeScanTheirCodeSendDesk : homeScanTheirCodeSend;
  String get homeMessagesAndContactGoneShown =>
      onDesktop ? homeMessagesAndContactGoneDesk : homeMessagesAndContactGone;
  String homeEveryMessageWithGoesShown(Object c) =>
      onDesktop ? homeEveryMessageWithGoesDesk(c) : homeEveryMessageWithGoes(c);
  String get homeOnlyOnThisPhoneShown =>
      onDesktop ? homeOnlyOnThisPhoneDesk : homeOnlyOnThisPhone;
  String get linkNoAppOpensShown =>
      onDesktop ? linkNoAppOpensDesk : linkNoAppOpens;
  String get movedWipeThisPhoneShown =>
      onDesktop ? movedWipeThisPhoneDesk : movedWipeThisPhone;
  String movedKryfoWillCloseNowShown(Object myId) => onDesktop
      ? movedKryfoWillCloseNowDesk(myId)
      : movedKryfoWillCloseNow(myId);
  String movedIsNowOnAnotherShown(Object myId) =>
      onDesktop ? movedIsNowOnAnotherDesk(myId) : movedIsNowOnAnother(myId);
  String get movedWipeThisPhone2Shown =>
      onDesktop ? movedWipeThisPhone2Desk : movedWipeThisPhone2;
  String get notesDeleteAllLineShown =>
      onDesktop ? notesDeleteAllLineDesk : notesDeleteAllLine;
  String get notesGoneFromThisPhoneShown =>
      onDesktop ? notesGoneFromThisPhoneDesk : notesGoneFromThisPhone;
  String get notesOnlyOnThisPhoneShown =>
      onDesktop ? notesOnlyOnThisPhoneDesk : notesOnlyOnThisPhone;
  String get notesJotAnythingDownItShown =>
      onDesktop ? notesJotAnythingDownItDesk : notesJotAnythingDownIt;
  String get notesExportHoldsInstallerShown =>
      onDesktop ? notesExportHoldsInstallerDesk : notesExportHoldsInstaller;
  String get onboardingGeneratedFromAKeyShown =>
      onDesktop ? onboardingGeneratedFromAKeyDesk : onboardingGeneratedFromAKey;
  String get onboardingYourIdentityLivesOnShown => onDesktop
      ? onboardingYourIdentityLivesOnDesk
      : onboardingYourIdentityLivesOn;
  String get pairCodeNumberMatchesShown =>
      onDesktop ? pairCodeNumberMatchesDesk : pairCodeNumberMatches;
  String get restoreReplaceTheAccountOnShown =>
      onDesktop ? restoreReplaceTheAccountOnDesk : restoreReplaceTheAccountOn;
  String restoreTheRegistryDidNotShown(Object mine) => onDesktop
      ? restoreTheRegistryDidNotDesk(mine)
      : restoreTheRegistryDidNot(mine);
  String restoreKryfoWillCloseNowShown(Object haloId) => onDesktop
      ? restoreKryfoWillCloseNowDesk(haloId)
      : restoreKryfoWillCloseNow(haloId);
  String get restoreAnythingSentToYouShown =>
      onDesktop ? restoreAnythingSentToYouDesk : restoreAnythingSentToYou;
  String get restoreTheOldPhoneStopsShown =>
      onDesktop ? restoreTheOldPhoneStopsDesk : restoreTheOldPhoneStops;
  String get restoreIfThePhoneThisShown =>
      onDesktop ? restoreIfThePhoneThisDesk : restoreIfThePhoneThis;
  String get restoreABackupBringsBackShown =>
      onDesktop ? restoreABackupBringsBackDesk : restoreABackupBringsBack;
  String get roomCreateARoomThatEndsShown =>
      onDesktop ? roomCreateARoomThatEndsDesk : roomCreateARoomThatEnds;
  String get savedChatGoneShown =>
      onDesktop ? savedChatGoneDesk : savedChatGone;
  String get seenScamShieldRequestsOnlyShown =>
      onDesktop ? seenScamShieldRequestsOnlyDesk : seenScamShieldRequestsOnly;
  String get seenAPreviewIsFetchedShown =>
      onDesktop ? seenAPreviewIsFetchedDesk : seenAPreviewIsFetched;
  String get seenASeizedUnlockedPhoneShown =>
      onDesktop ? seenASeizedUnlockedPhoneDesk : seenASeizedUnlockedPhone;
  String get seenIfSomeoneHoldsYourShown =>
      onDesktop ? seenIfSomeoneHoldsYourDesk : seenIfSomeoneHoldsYour;
  String get seenHonestAboutTheLastShown =>
      onDesktop ? seenHonestAboutTheLastDesk : seenHonestAboutTheLast;
  String get settingsIdentityMessagesContactsAndShown => onDesktop
      ? settingsIdentityMessagesContactsAndDesk
      : settingsIdentityMessagesContactsAnd;
  String get settingsWipeKryfoFromThisShown =>
      onDesktop ? settingsWipeKryfoFromThisDesk : settingsWipeKryfoFromThis;
  String get settingsScamShieldHintShown =>
      onDesktop ? settingsScamShieldHintDesk : settingsScamShieldHint;
  String get transportNothingHereLeavesTheShown => onDesktop
      ? transportNothingHereLeavesTheDesk
      : transportNothingHereLeavesThe;
  String get transportWithNoContactsTheShown =>
      onDesktop ? transportWithNoContactsTheDesk : transportWithNoContactsThe;
  String get whyKryfoNoAccountNoPhoneShown =>
      onDesktop ? whyKryfoNoAccountNoPhoneDesk : whyKryfoNoAccountNoPhone;
  String get bootFailedKeysDidNotAnswerShown =>
      onDesktop ? bootFailedKeysDidNotAnswerDesk : bootFailedKeysDidNotAnswer;
  String get bootFailedStartFreshLineShown =>
      onDesktop ? bootFailedStartFreshLineDesk : bootFailedStartFreshLine;
  String get bootFailedStartFreshSureShown =>
      onDesktop ? bootFailedStartFreshSureDesk : bootFailedStartFreshSure;
  String get torBootSplashMadeOnThisPhoneShown => onDesktop
      ? torBootSplashMadeOnThisPhoneDesk
      : torBootSplashMadeOnThisPhone;
  String get bridgesPasteTheLineTheyShown =>
      onDesktop ? bridgesPasteTheLineTheyDesk : bridgesPasteTheLineThey;
  String get bridgesPasteOrScanALineShown =>
      onDesktop ? bridgesPasteOrScanALineDesk : bridgesPasteOrScanALine;
  String get languageMatchPhoneShown =>
      onDesktop ? languageMatchPhoneDesk : languageMatchPhone;
  String languageMatchPhoneValueShown(Object language) => onDesktop
      ? languageMatchPhoneValueDesk(language)
      : languageMatchPhoneValue(language);
  String get videoViewerCannotPlayShown =>
      onDesktop ? videoViewerCannotPlayDesk : videoViewerCannotPlay;
  String get searchIntroLineShown =>
      onDesktop ? searchIntroLineDesk : searchIntroLine;
  String get inviteNotYetShown => onDesktop ? inviteNotYetDesk : inviteNotYet;
  String get devWhoAnonShown => onDesktop ? devWhoAnonDesk : devWhoAnon;
  String get devWhoNothingYetShown =>
      onDesktop ? devWhoNothingYetDesk : devWhoNothingYet;
  String get devNamelessLineShown =>
      onDesktop ? devNamelessLineDesk : devNamelessLine;
  String get nameTakenTombLineShown =>
      onDesktop ? nameTakenTombLineDesk : nameTakenTombLine;
  String get notThemSheetLineShown =>
      onDesktop ? notThemSheetLineDesk : notThemSheetLine;
  String get gifOptInWhereToTurnOffShown =>
      onDesktop ? gifOptInWhereToTurnOffDesk : gifOptInWhereToTurnOff;
  String get gifSavedOnPhoneShown =>
      onDesktop ? gifSavedOnPhoneDesk : gifSavedOnPhone;
  String get gifPhoneTabShown => onDesktop ? gifPhoneTabDesk : gifPhoneTab;
  String get gifPhoneLineShown => onDesktop ? gifPhoneLineDesk : gifPhoneLine;
  String get voiceNoRoomShown => onDesktop ? voiceNoRoomDesk : voiceNoRoom;
  String translatePackTitleShown(Object language) => onDesktop
      ? translatePackTitleDesk(language)
      : translatePackTitle(language);
  String translatePackLineShown(Object language, Object size) => onDesktop
      ? translatePackLineDesk(language, size)
      : translatePackLine(language, size);
  String get translatePackNoLibShown =>
      onDesktop ? translatePackNoLibDesk : translatePackNoLib;
  String translateInstalledShown(Object size) =>
      onDesktop ? translateInstalledDesk(size) : translateInstalled(size);
  String get translateNeedsWifiShown =>
      onDesktop ? translateNeedsWifiDesk : translateNeedsWifi;
  String get translateFailNoEngineShown =>
      onDesktop ? translateFailNoEngineDesk : translateFailNoEngine;
  String get translateSettingsHintShown =>
      onDesktop ? translateSettingsHintDesk : translateSettingsHint;
  String get translatePrivacyNoteShown =>
      onDesktop ? translatePrivacyNoteDesk : translatePrivacyNote;
  String get notificationsLeadShown =>
      onDesktop ? notificationsLeadDesk : notificationsLead;
  String get photoOnlyHereShown =>
      onDesktop ? photoOnlyHereDesk : photoOnlyHere;
  String get photoOnlyHereLineShown =>
      onDesktop ? photoOnlyHereLineDesk : photoOnlyHereLine;
  String get myKryfoPointYourPhonesAtShown =>
      onDesktop ? myKryfoPointYourPhonesAtDesk : myKryfoPointYourPhonesAt;
  // the lock, pins, decoy and wipe: the same in the decoy as in the real app
  String get pinsThePinGoesAndShown =>
      onDesktop ? pinsThePinGoesAndDesk : pinsThePinGoesAnd;
  String get pinsTurnOffWithDecoyShown =>
      onDesktop ? pinsTurnOffWithDecoyDesk : pinsTurnOffWithDecoy;
  String get pinsAdvancedLineShown =>
      onDesktop ? pinsAdvancedLineDesk : pinsAdvancedLine;
  String get pinsWipeLineShown => onDesktop ? pinsWipeLineDesk : pinsWipeLine;
  String get flowWipe1Shown => onDesktop ? flowWipe1Desk : flowWipe1;
  String get flowLawShown => onDesktop ? flowLawDesk : flowLaw;
  String get flowVaultReplaceShown =>
      onDesktop ? flowVaultReplaceDesk : flowVaultReplace;
  String get howVaultShown => onDesktop ? howVaultDesk : howVault;
  String get flowVaultPassLineShown =>
      onDesktop ? flowVaultPassLineDesk : flowVaultPassLine;
  String get flowDecoyShadeShown =>
      onDesktop ? flowDecoyShadeDesk : flowDecoyShade;
  String get bridgesThisNetworkWantsAShown =>
      onDesktop ? bridgesThisNetworkWantsADesk : bridgesThisNetworkWantsA;
}
