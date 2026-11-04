// SPDX-License-Identifier: GPL-3.0-or-later
// a computer says computer where the phone says phone. the phone's words stay
// as they were, in every language
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/desktop/desktop_mode.dart';
import 'package:kryfo/l10n/l10n.dart';

typedef _Get = String Function(AppLocalizations);

final _pairs = <(String, _Get, _Get, _Get)>[
  (
    'appearanceWallpaperHint',
    (l) => l.appearanceWallpaperHintShown,
    (l) => l.appearanceWallpaperHint,
    (l) => l.appearanceWallpaperHintDesk,
  ),
  (
    'appAnAttachmentCouldNot',
    (l) => l.appAnAttachmentCouldNotShown,
    (l) => l.appAnAttachmentCouldNot,
    (l) => l.appAnAttachmentCouldNotDesk,
  ),
  (
    'appScanTheirCodeOr',
    (l) => l.appScanTheirCodeOrShown,
    (l) => l.appScanTheirCodeOr,
    (l) => l.appScanTheirCodeOrDesk,
  ),
  (
    'backupACopyToKeep',
    (l) => l.backupACopyToKeepShown,
    (l) => l.backupACopyToKeep,
    (l) => l.backupACopyToKeepDesk,
  ),
  (
    'backupTheFileTakesThis',
    (l) => l.backupTheFileTakesThisShown,
    (l) => l.backupTheFileTakesThis,
    (l) => l.backupTheFileTakesThisDesk,
  ),
  (
    'backupOneEncryptedFileYourIdentityYour',
    (l) => l.backupOneEncryptedFileYourIdentityYourShown,
    (l) => l.backupOneEncryptedFileYourIdentityYour,
    (l) => l.backupOneEncryptedFileYourIdentityYourDesk,
  ),
  (
    'backupMoveReachedTitle',
    (l) => l.backupMoveReachedTitleShown,
    (l) => l.backupMoveReachedTitle,
    (l) => l.backupMoveReachedTitleDesk,
  ),
  (
    'backupMoveReachedLine',
    (l) => l.backupMoveReachedLineShown,
    (l) => l.backupMoveReachedLine,
    (l) => l.backupMoveReachedLineDesk,
  ),
  (
    'backupNoSpace',
    (l) => l.backupNoSpaceShown,
    (l) => l.backupNoSpace,
    (l) => l.backupNoSpaceDesk,
  ),
  (
    'backupMoveHiddenStay',
    (l) => l.backupMoveHiddenStayShown,
    (l) => l.backupMoveHiddenStay,
    (l) => l.backupMoveHiddenStayDesk,
  ),
  (
    'chatItDisappearsWithNo',
    (l) => l.chatItDisappearsWithNoShown,
    (l) => l.chatItDisappearsWithNo,
    (l) => l.chatItDisappearsWithNoDesk,
  ),
  (
    'chatGifFromPhone',
    (l) => l.chatGifFromPhoneShown,
    (l) => l.chatGifFromPhone,
    (l) => l.chatGifFromPhoneDesk,
  ),
  (
    'chatJustForYouNever',
    (l) => l.chatJustForYouNeverShown,
    (l) => l.chatJustForYouNever,
    (l) => l.chatJustForYouNeverDesk,
  ),
  (
    'chatEveryMessageHereIs',
    (l) => l.chatEveryMessageHereIsShown,
    (l) => l.chatEveryMessageHereIs,
    (l) => l.chatEveryMessageHereIsDesk,
  ),
  (
    'chatAlbumItDisappearsWithNo',
    (l) => l.chatAlbumItDisappearsWithNoShown,
    (l) => l.chatAlbumItDisappearsWithNo,
    (l) => l.chatAlbumItDisappearsWithNoDesk,
  ),
  (
    'chatShotsWhenTheyUpdate',
    (l) => l.chatShotsWhenTheyUpdateShown,
    (l) => l.chatShotsWhenTheyUpdate,
    (l) => l.chatShotsWhenTheyUpdateDesk,
  ),
  (
    'roomShotsBlocked',
    (l) => l.roomShotsBlockedShown,
    (l) => l.roomShotsBlocked,
    (l) => l.roomShotsBlockedDesk,
  ),
  (
    'roomShotsAlwaysOn',
    (l) => l.roomShotsAlwaysOnShown,
    (l) => l.roomShotsAlwaysOn,
    (l) => l.roomShotsAlwaysOnDesk,
  ),
  (
    'groupShotsBlocksAll',
    (l) => l.groupShotsBlocksAllShown,
    (l) => l.groupShotsBlocksAll,
    (l) => l.groupShotsBlocksAllDesk,
  ),
  (
    'groupShotsOnForAll',
    (l) => l.groupShotsOnForAllShown,
    (l) => l.groupShotsOnForAll,
    (l) => l.groupShotsOnForAllDesk,
  ),
  (
    'groupShotsOnAdminOnly',
    (l) => l.groupShotsOnAdminOnlyShown,
    (l) => l.groupShotsOnAdminOnly,
    (l) => l.groupShotsOnAdminOnlyDesk,
  ),
  (
    'groupShotsBlockedHere',
    (l) => l.groupShotsBlockedHereShown,
    (l) => l.groupShotsBlockedHere,
    (l) => l.groupShotsBlockedHereDesk,
  ),
  (
    'groupShotsStarted',
    (l) => l.groupShotsStartedShown,
    (l) => l.groupShotsStarted,
    (l) => l.groupShotsStartedDesk,
  ),
  (
    'contactStaysOnThisPhone',
    (l) => l.contactStaysOnThisPhoneShown,
    (l) => l.contactStaysOnThisPhone,
    (l) => l.contactStaysOnThisPhoneDesk,
  ),
  (
    'contactMessagesAndContactGone',
    (l) => l.contactMessagesAndContactGoneShown,
    (l) => l.contactMessagesAndContactGone,
    (l) => l.contactMessagesAndContactGoneDesk,
  ),
  (
    'contactEveryMessageAndThe',
    (l) => l.contactEveryMessageAndTheShown,
    (l) => l.contactEveryMessageAndThe,
    (l) => l.contactEveryMessageAndTheDesk,
  ),
  (
    'donateGivesReceipt',
    (l) => l.donateGivesReceiptShown,
    (l) => l.donateGivesReceipt,
    (l) => l.donateGivesReceiptDesk,
  ),
  (
    'groupChatItDisappearsWithNo',
    (l) => l.groupChatItDisappearsWithNoShown,
    (l) => l.groupChatItDisappearsWithNo,
    (l) => l.groupChatItDisappearsWithNoDesk,
  ),
  (
    'groupChatGifFromPhone',
    (l) => l.groupChatGifFromPhoneShown,
    (l) => l.groupChatGifFromPhone,
    (l) => l.groupChatGifFromPhoneDesk,
  ),
  (
    'groupChatAlbumItDisappearsWithNo',
    (l) => l.groupChatAlbumItDisappearsWithNoShown,
    (l) => l.groupChatAlbumItDisappearsWithNo,
    (l) => l.groupChatAlbumItDisappearsWithNoDesk,
  ),
  (
    'groupInfoEveryMessageHereIs',
    (l) => l.groupInfoEveryMessageHereIsShown,
    (l) => l.groupInfoEveryMessageHereIs,
    (l) => l.groupInfoEveryMessageHereIsDesk,
  ),
  (
    'groupInfoEverythingInItIs',
    (l) => l.groupInfoEverythingInItIsShown,
    (l) => l.groupInfoEverythingInItIs,
    (l) => l.groupInfoEverythingInItIsDesk,
  ),
  (
    'groupInfoLeaveGroupLine',
    (l) => l.groupInfoLeaveGroupLineShown,
    (l) => l.groupInfoLeaveGroupLine,
    (l) => l.groupInfoLeaveGroupLineDesk,
  ),
  (
    'groupInfoLeaveGroupAdmin',
    (l) => l.groupInfoLeaveGroupAdminShown,
    (l) => l.groupInfoLeaveGroupAdmin,
    (l) => l.groupInfoLeaveGroupAdminDesk,
  ),
  (
    'groupInfoLeaveRoomMaker',
    (l) => l.groupInfoLeaveRoomMakerShown,
    (l) => l.groupInfoLeaveRoomMaker,
    (l) => l.groupInfoLeaveRoomMakerDesk,
  ),
  (
    'groupInfoEndGroupLine',
    (l) => l.groupInfoEndGroupLineShown,
    (l) => l.groupInfoEndGroupLine,
    (l) => l.groupInfoEndGroupLineDesk,
  ),
  (
    'groupInfoEndGroupDetail',
    (l) => l.groupInfoEndGroupDetailShown,
    (l) => l.groupInfoEndGroupDetail,
    (l) => l.groupInfoEndGroupDetailDesk,
  ),
  (
    'groupAdminGoneLine',
    (l) => l.groupAdminGoneLineShown,
    (l) => l.groupAdminGoneLine,
    (l) => l.groupAdminGoneLineDesk,
  ),
  (
    'handleIsNotYoursOn',
    (l) => l.handleIsNotYoursOnShown('HANDLE'),
    (l) => l.handleIsNotYoursOn('HANDLE'),
    (l) => l.handleIsNotYoursOnDesk('HANDLE'),
  ),
  (
    'handleTheRegistryHoldsIt',
    (l) => l.handleTheRegistryHoldsItShown('HANDLE'),
    (l) => l.handleTheRegistryHoldsIt('HANDLE'),
    (l) => l.handleTheRegistryHoldsItDesk('HANDLE'),
  ),
  (
    'handleForgetItOnThis',
    (l) => l.handleForgetItOnThisShown,
    (l) => l.handleForgetItOnThis,
    (l) => l.handleForgetItOnThisDesk,
  ),
  (
    'handleCheckClock',
    (l) => l.handleCheckClockShown,
    (l) => l.handleCheckClock,
    (l) => l.handleCheckClockDesk,
  ),
  (
    'homeScanTheirCodeSend',
    (l) => l.homeScanTheirCodeSendShown,
    (l) => l.homeScanTheirCodeSend,
    (l) => l.homeScanTheirCodeSendDesk,
  ),
  (
    'homeMessagesAndContactGone',
    (l) => l.homeMessagesAndContactGoneShown,
    (l) => l.homeMessagesAndContactGone,
    (l) => l.homeMessagesAndContactGoneDesk,
  ),
  (
    'homeEveryMessageWithGoes',
    (l) => l.homeEveryMessageWithGoesShown('C'),
    (l) => l.homeEveryMessageWithGoes('C'),
    (l) => l.homeEveryMessageWithGoesDesk('C'),
  ),
  (
    'homeOnlyOnThisPhone',
    (l) => l.homeOnlyOnThisPhoneShown,
    (l) => l.homeOnlyOnThisPhone,
    (l) => l.homeOnlyOnThisPhoneDesk,
  ),
  (
    'linkNoAppOpens',
    (l) => l.linkNoAppOpensShown,
    (l) => l.linkNoAppOpens,
    (l) => l.linkNoAppOpensDesk,
  ),
  (
    'movedWipeThisPhone',
    (l) => l.movedWipeThisPhoneShown,
    (l) => l.movedWipeThisPhone,
    (l) => l.movedWipeThisPhoneDesk,
  ),
  (
    'movedKryfoWillCloseNow',
    (l) => l.movedKryfoWillCloseNowShown('MYID'),
    (l) => l.movedKryfoWillCloseNow('MYID'),
    (l) => l.movedKryfoWillCloseNowDesk('MYID'),
  ),
  (
    'movedIsNowOnAnother',
    (l) => l.movedIsNowOnAnotherShown('MYID'),
    (l) => l.movedIsNowOnAnother('MYID'),
    (l) => l.movedIsNowOnAnotherDesk('MYID'),
  ),
  (
    'movedWipeThisPhone2',
    (l) => l.movedWipeThisPhone2Shown,
    (l) => l.movedWipeThisPhone2,
    (l) => l.movedWipeThisPhone2Desk,
  ),
  (
    'notesDeleteAllLine',
    (l) => l.notesDeleteAllLineShown,
    (l) => l.notesDeleteAllLine,
    (l) => l.notesDeleteAllLineDesk,
  ),
  (
    'notesGoneFromThisPhone',
    (l) => l.notesGoneFromThisPhoneShown,
    (l) => l.notesGoneFromThisPhone,
    (l) => l.notesGoneFromThisPhoneDesk,
  ),
  (
    'notesOnlyOnThisPhone',
    (l) => l.notesOnlyOnThisPhoneShown,
    (l) => l.notesOnlyOnThisPhone,
    (l) => l.notesOnlyOnThisPhoneDesk,
  ),
  (
    'notesJotAnythingDownIt',
    (l) => l.notesJotAnythingDownItShown,
    (l) => l.notesJotAnythingDownIt,
    (l) => l.notesJotAnythingDownItDesk,
  ),
  (
    'notesExportHoldsInstaller',
    (l) => l.notesExportHoldsInstallerShown,
    (l) => l.notesExportHoldsInstaller,
    (l) => l.notesExportHoldsInstallerDesk,
  ),
  (
    'onboardingGeneratedFromAKey',
    (l) => l.onboardingGeneratedFromAKeyShown,
    (l) => l.onboardingGeneratedFromAKey,
    (l) => l.onboardingGeneratedFromAKeyDesk,
  ),
  (
    'onboardingYourIdentityLivesOn',
    (l) => l.onboardingYourIdentityLivesOnShown,
    (l) => l.onboardingYourIdentityLivesOn,
    (l) => l.onboardingYourIdentityLivesOnDesk,
  ),
  (
    'pairCodeOldCode',
    (l) => l.pairCodeOldCodeShown,
    (l) => l.pairCodeOldCode,
    (l) => l.pairCodeOldCodeDesk,
  ),
  (
    'pairCodeBothNeed06',
    (l) => l.pairCodeBothNeed06Shown,
    (l) => l.pairCodeBothNeed06,
    (l) => l.pairCodeBothNeed06Desk,
  ),
  (
    'restoreReplaceTheAccountOn',
    (l) => l.restoreReplaceTheAccountOnShown,
    (l) => l.restoreReplaceTheAccountOn,
    (l) => l.restoreReplaceTheAccountOnDesk,
  ),
  (
    'restoreTheRegistryDidNot',
    (l) => l.restoreTheRegistryDidNotShown('MINE'),
    (l) => l.restoreTheRegistryDidNot('MINE'),
    (l) => l.restoreTheRegistryDidNotDesk('MINE'),
  ),
  (
    'restoreKryfoWillCloseNow',
    (l) => l.restoreKryfoWillCloseNowShown('HALOID'),
    (l) => l.restoreKryfoWillCloseNow('HALOID'),
    (l) => l.restoreKryfoWillCloseNowDesk('HALOID'),
  ),
  (
    'restoreAnythingSentToYou',
    (l) => l.restoreAnythingSentToYouShown,
    (l) => l.restoreAnythingSentToYou,
    (l) => l.restoreAnythingSentToYouDesk,
  ),
  (
    'restoreTheOldPhoneStops',
    (l) => l.restoreTheOldPhoneStopsShown,
    (l) => l.restoreTheOldPhoneStops,
    (l) => l.restoreTheOldPhoneStopsDesk,
  ),
  (
    'restoreIfThePhoneThis',
    (l) => l.restoreIfThePhoneThisShown,
    (l) => l.restoreIfThePhoneThis,
    (l) => l.restoreIfThePhoneThisDesk,
  ),
  (
    'restoreABackupBringsBack',
    (l) => l.restoreABackupBringsBackShown,
    (l) => l.restoreABackupBringsBack,
    (l) => l.restoreABackupBringsBackDesk,
  ),
  (
    'roomCreateARoomThatEnds',
    (l) => l.roomCreateARoomThatEndsShown,
    (l) => l.roomCreateARoomThatEnds,
    (l) => l.roomCreateARoomThatEndsDesk,
  ),
  (
    'savedChatGone',
    (l) => l.savedChatGoneShown,
    (l) => l.savedChatGone,
    (l) => l.savedChatGoneDesk,
  ),
  (
    'seenScamShieldRequestsOnly',
    (l) => l.seenScamShieldRequestsOnlyShown,
    (l) => l.seenScamShieldRequestsOnly,
    (l) => l.seenScamShieldRequestsOnlyDesk,
  ),
  (
    'seenAPreviewIsFetched',
    (l) => l.seenAPreviewIsFetchedShown,
    (l) => l.seenAPreviewIsFetched,
    (l) => l.seenAPreviewIsFetchedDesk,
  ),
  (
    'seenASeizedUnlockedPhone',
    (l) => l.seenASeizedUnlockedPhoneShown,
    (l) => l.seenASeizedUnlockedPhone,
    (l) => l.seenASeizedUnlockedPhoneDesk,
  ),
  (
    'seenIfSomeoneHoldsYour',
    (l) => l.seenIfSomeoneHoldsYourShown,
    (l) => l.seenIfSomeoneHoldsYour,
    (l) => l.seenIfSomeoneHoldsYourDesk,
  ),
  (
    'seenHonestAboutTheLast',
    (l) => l.seenHonestAboutTheLastShown,
    (l) => l.seenHonestAboutTheLast,
    (l) => l.seenHonestAboutTheLastDesk,
  ),
  (
    'settingsIdentityMessagesContactsAnd',
    (l) => l.settingsIdentityMessagesContactsAndShown,
    (l) => l.settingsIdentityMessagesContactsAnd,
    (l) => l.settingsIdentityMessagesContactsAndDesk,
  ),
  (
    'settingsWipeKryfoFromThis',
    (l) => l.settingsWipeKryfoFromThisShown,
    (l) => l.settingsWipeKryfoFromThis,
    (l) => l.settingsWipeKryfoFromThisDesk,
  ),
  (
    'settingsScamShieldHint',
    (l) => l.settingsScamShieldHintShown,
    (l) => l.settingsScamShieldHint,
    (l) => l.settingsScamShieldHintDesk,
  ),
  (
    'transportNothingHereLeavesThe',
    (l) => l.transportNothingHereLeavesTheShown,
    (l) => l.transportNothingHereLeavesThe,
    (l) => l.transportNothingHereLeavesTheDesk,
  ),
  (
    'transportWithNoContactsThe',
    (l) => l.transportWithNoContactsTheShown,
    (l) => l.transportWithNoContactsThe,
    (l) => l.transportWithNoContactsTheDesk,
  ),
  (
    'whyKryfoNoAccountNoPhone',
    (l) => l.whyKryfoNoAccountNoPhoneShown,
    (l) => l.whyKryfoNoAccountNoPhone,
    (l) => l.whyKryfoNoAccountNoPhoneDesk,
  ),
  (
    'bootFailedKeysDidNotAnswer',
    (l) => l.bootFailedKeysDidNotAnswerShown,
    (l) => l.bootFailedKeysDidNotAnswer,
    (l) => l.bootFailedKeysDidNotAnswerDesk,
  ),
  (
    'bootFailedStartFreshLine',
    (l) => l.bootFailedStartFreshLineShown,
    (l) => l.bootFailedStartFreshLine,
    (l) => l.bootFailedStartFreshLineDesk,
  ),
  (
    'bootFailedStartFreshSure',
    (l) => l.bootFailedStartFreshSureShown,
    (l) => l.bootFailedStartFreshSure,
    (l) => l.bootFailedStartFreshSureDesk,
  ),
  (
    'torBootSplashMadeOnThisPhone',
    (l) => l.torBootSplashMadeOnThisPhoneShown,
    (l) => l.torBootSplashMadeOnThisPhone,
    (l) => l.torBootSplashMadeOnThisPhoneDesk,
  ),
  (
    'bridgesPasteTheLineThey',
    (l) => l.bridgesPasteTheLineTheyShown,
    (l) => l.bridgesPasteTheLineThey,
    (l) => l.bridgesPasteTheLineTheyDesk,
  ),
  (
    'bridgesPasteOrScanALine',
    (l) => l.bridgesPasteOrScanALineShown,
    (l) => l.bridgesPasteOrScanALine,
    (l) => l.bridgesPasteOrScanALineDesk,
  ),
  (
    'languageMatchPhone',
    (l) => l.languageMatchPhoneShown,
    (l) => l.languageMatchPhone,
    (l) => l.languageMatchPhoneDesk,
  ),
  (
    'languageMatchPhoneValue',
    (l) => l.languageMatchPhoneValueShown('LANGUAGE'),
    (l) => l.languageMatchPhoneValue('LANGUAGE'),
    (l) => l.languageMatchPhoneValueDesk('LANGUAGE'),
  ),
  (
    'videoViewerCannotPlay',
    (l) => l.videoViewerCannotPlayShown,
    (l) => l.videoViewerCannotPlay,
    (l) => l.videoViewerCannotPlayDesk,
  ),
  (
    'searchIntroLine',
    (l) => l.searchIntroLineShown,
    (l) => l.searchIntroLine,
    (l) => l.searchIntroLineDesk,
  ),
  (
    'inviteNotYet',
    (l) => l.inviteNotYetShown,
    (l) => l.inviteNotYet,
    (l) => l.inviteNotYetDesk,
  ),
  (
    'devWhoAnon',
    (l) => l.devWhoAnonShown,
    (l) => l.devWhoAnon,
    (l) => l.devWhoAnonDesk,
  ),
  (
    'devWhoNothingYet',
    (l) => l.devWhoNothingYetShown,
    (l) => l.devWhoNothingYet,
    (l) => l.devWhoNothingYetDesk,
  ),
  (
    'devNamelessLine',
    (l) => l.devNamelessLineShown,
    (l) => l.devNamelessLine,
    (l) => l.devNamelessLineDesk,
  ),
  (
    'nameTakenTombLine',
    (l) => l.nameTakenTombLineShown,
    (l) => l.nameTakenTombLine,
    (l) => l.nameTakenTombLineDesk,
  ),
  (
    'notThemSheetLine',
    (l) => l.notThemSheetLineShown,
    (l) => l.notThemSheetLine,
    (l) => l.notThemSheetLineDesk,
  ),
  (
    'gifOptInWhereToTurnOff',
    (l) => l.gifOptInWhereToTurnOffShown,
    (l) => l.gifOptInWhereToTurnOff,
    (l) => l.gifOptInWhereToTurnOffDesk,
  ),
  (
    'gifSavedOnPhone',
    (l) => l.gifSavedOnPhoneShown,
    (l) => l.gifSavedOnPhone,
    (l) => l.gifSavedOnPhoneDesk,
  ),
  (
    'gifPhoneTab',
    (l) => l.gifPhoneTabShown,
    (l) => l.gifPhoneTab,
    (l) => l.gifPhoneTabDesk,
  ),
  (
    'gifPhoneLine',
    (l) => l.gifPhoneLineShown,
    (l) => l.gifPhoneLine,
    (l) => l.gifPhoneLineDesk,
  ),
  (
    'voiceNoRoom',
    (l) => l.voiceNoRoomShown,
    (l) => l.voiceNoRoom,
    (l) => l.voiceNoRoomDesk,
  ),
  (
    'translatePackTitle',
    (l) => l.translatePackTitleShown('LANGUAGE'),
    (l) => l.translatePackTitle('LANGUAGE'),
    (l) => l.translatePackTitleDesk('LANGUAGE'),
  ),
  (
    'translatePackLine',
    (l) => l.translatePackLineShown('LANGUAGE', 'SIZE'),
    (l) => l.translatePackLine('LANGUAGE', 'SIZE'),
    (l) => l.translatePackLineDesk('LANGUAGE', 'SIZE'),
  ),
  (
    'translatePackNoLib',
    (l) => l.translatePackNoLibShown,
    (l) => l.translatePackNoLib,
    (l) => l.translatePackNoLibDesk,
  ),
  (
    'translateInstalled',
    (l) => l.translateInstalledShown('SIZE'),
    (l) => l.translateInstalled('SIZE'),
    (l) => l.translateInstalledDesk('SIZE'),
  ),
  (
    'translateNeedsWifi',
    (l) => l.translateNeedsWifiShown,
    (l) => l.translateNeedsWifi,
    (l) => l.translateNeedsWifiDesk,
  ),
  (
    'translateFailNoEngine',
    (l) => l.translateFailNoEngineShown,
    (l) => l.translateFailNoEngine,
    (l) => l.translateFailNoEngineDesk,
  ),
  (
    'translateSettingsHint',
    (l) => l.translateSettingsHintShown,
    (l) => l.translateSettingsHint,
    (l) => l.translateSettingsHintDesk,
  ),
  (
    'translatePrivacyNote',
    (l) => l.translatePrivacyNoteShown,
    (l) => l.translatePrivacyNote,
    (l) => l.translatePrivacyNoteDesk,
  ),
  (
    'translatePrivacyKept',
    (l) => l.translatePrivacyKeptShown,
    (l) => l.translatePrivacyKept,
    (l) => l.translatePrivacyKeptDesk,
  ),
  (
    'notificationsLead',
    (l) => l.notificationsLeadShown,
    (l) => l.notificationsLead,
    (l) => l.notificationsLeadDesk,
  ),
  (
    'photoOnlyHere',
    (l) => l.photoOnlyHereShown,
    (l) => l.photoOnlyHere,
    (l) => l.photoOnlyHereDesk,
  ),
  (
    'photoOnlyHereLine',
    (l) => l.photoOnlyHereLineShown,
    (l) => l.photoOnlyHereLine,
    (l) => l.photoOnlyHereLineDesk,
  ),
  (
    'myKryfoPointYourPhonesAt',
    (l) => l.myKryfoPointYourPhonesAtShown,
    (l) => l.myKryfoPointYourPhonesAt,
    (l) => l.myKryfoPointYourPhonesAtDesk,
  ),
  (
    'pinsThePinGoesAnd',
    (l) => l.pinsThePinGoesAndShown,
    (l) => l.pinsThePinGoesAnd,
    (l) => l.pinsThePinGoesAndDesk,
  ),
  (
    'pinsTurnOffWithDecoy',
    (l) => l.pinsTurnOffWithDecoyShown,
    (l) => l.pinsTurnOffWithDecoy,
    (l) => l.pinsTurnOffWithDecoyDesk,
  ),
  (
    'pinsAdvancedLine',
    (l) => l.pinsAdvancedLineShown,
    (l) => l.pinsAdvancedLine,
    (l) => l.pinsAdvancedLineDesk,
  ),
  (
    'pinsWipeLine',
    (l) => l.pinsWipeLineShown,
    (l) => l.pinsWipeLine,
    (l) => l.pinsWipeLineDesk,
  ),
  (
    'flowWipe1',
    (l) => l.flowWipe1Shown,
    (l) => l.flowWipe1,
    (l) => l.flowWipe1Desk,
  ),
  ('flowLaw', (l) => l.flowLawShown, (l) => l.flowLaw, (l) => l.flowLawDesk),
  (
    'flowVaultReplace',
    (l) => l.flowVaultReplaceShown,
    (l) => l.flowVaultReplace,
    (l) => l.flowVaultReplaceDesk,
  ),
  (
    'howVault',
    (l) => l.howVaultShown,
    (l) => l.howVault,
    (l) => l.howVaultDesk,
  ),
  (
    'flowVaultPassLine',
    (l) => l.flowVaultPassLineShown,
    (l) => l.flowVaultPassLine,
    (l) => l.flowVaultPassLineDesk,
  ),
  (
    'flowDecoyShade',
    (l) => l.flowDecoyShadeShown,
    (l) => l.flowDecoyShade,
    (l) => l.flowDecoyShadeDesk,
  ),
  (
    'bridgesThisNetworkWantsA',
    (l) => l.bridgesThisNetworkWantsAShown,
    (l) => l.bridgesThisNetworkWantsA,
    (l) => l.bridgesThisNetworkWantsADesk,
  ),
  (
    'devicesThisPhone',
    (l) => l.devicesThisPhoneShown,
    (l) => l.devicesThisPhone,
    (l) => l.devicesThisPhoneDesk,
  ),
  (
    'devicesThisPhoneOnly',
    (l) => l.devicesThisPhoneOnlyShown,
    (l) => l.devicesThisPhoneOnly,
    (l) => l.devicesThisPhoneOnlyDesk,
  ),
  (
    'devicesOnlyThisPhone',
    (l) => l.devicesOnlyThisPhoneShown,
    (l) => l.devicesOnlyThisPhone,
    (l) => l.devicesOnlyThisPhoneDesk,
  ),
  (
    'devicesHiddenStay',
    (l) => l.devicesHiddenStayShown,
    (l) => l.devicesHiddenStay,
    (l) => l.devicesHiddenStayDesk,
  ),
];

Locale _locale(String tag) {
  final p = tag.split('_');
  return Locale.fromSubtags(
    languageCode: p[0],
    scriptCode: p.length > 1 ? p[1] : null,
  );
}

void main() {
  final langs = [
    for (final f in Directory('lib/l10n').listSync())
      if (f.path.endsWith('.arb'))
        f.uri.pathSegments.last.replaceAll(RegExp(r'^app_|\.arb$'), ''),
  ];

  tearDown(() => onDesktop = false);

  test('every key with a computer wording is checked here', () {
    expect(_pairs.map((p) => p.$1).toList(), deskWordKeys);
  });

  for (final lang in langs) {
    test('$lang: the phone keeps its words, the computer gets its own', () {
      final l = lookupAppLocalizations(_locale(lang));
      for (final (key, shown, phone, desk) in _pairs) {
        onDesktop = false;
        expect(shown(l), phone(l), reason: '$lang $key on the phone');
        onDesktop = true;
        expect(shown(l), desk(l), reason: '$lang $key on a computer');
        expect(desk(l), isNot(phone(l)), reason: '$lang $key');
      }
      onDesktop = false;
    });
  }

  test('the english computer words name no phone, camera or scan', () {
    final l = lookupAppLocalizations(const Locale('en'));
    onDesktop = true;
    for (final (key, shown, _, _) in _pairs) {
      final s = shown(l)
          .toLowerCase()
          .replaceAll('phone number', '')
          .replaceAll('with their phone', '')
          .replaceAll('they scan this code', '');
      for (final w in ['phone', 'camera', 'scan']) {
        expect(s, isNot(contains(w)), reason: key);
      }
    }
  });

  test('a computer\'s group and room screens never say it blocks '
      'screenshots; the copy limits are still named', () {
    final l = lookupAppLocalizations(const Locale('en'));
    addTearDown(() => onDesktop = false);
    onDesktop = true;
    final said = [
      l.roomShotsBlockedShown,
      l.roomShotsAlwaysOnShown,
      l.groupShotsBlocksAllShown,
      l.groupShotsOnForAllShown,
      l.groupShotsOnAdminOnlyShown,
      l.groupShotsBlockedHereShown,
      l.groupShotsStartedShown,
    ];
    for (final s in said) {
      final lower = s.toLowerCase();
      expect(lower, isNot(startsWith('kryfo blocks')), reason: s);
      expect(lower, isNot(startsWith('blocks screenshots')), reason: s);
      expect(lower, isNot(contains('on every')), reason: s);
      expect(lower, isNot(contains('for everyone')), reason: s);
      // what a phone does is said of Kryfo for Android, never of here
      if (lower.contains('screenshot')) {
        expect(s, contains('Kryfo for Android'), reason: s);
      }
    }
    for (final s in [
      l.roomShotsBlockedShown,
      l.groupShotsBlocksAllShown,
      l.groupShotsBlockedHereShown,
      l.groupShotsStartedShown,
    ]) {
      expect(s.toLowerCase(), contains('copying, forwarding and saving'));
    }
    onDesktop = false;
    expect(
      l.groupShotsBlockedHereShown,
      'Kryfo blocks screenshots in this group',
    );
    expect(l.groupShotsOnForAllShown, 'On for everyone here');
  });

  test('the asked-for wording', () {
    final l = lookupAppLocalizations(const Locale('en'));
    onDesktop = true;
    expect(l.homeOnlyOnThisPhoneShown, 'Only on this computer');
    expect(
      l.homeScanTheirCodeSendShown,
      'Send them a link, or type the @handle they gave you.',
    );
    onDesktop = false;
    expect(l.homeOnlyOnThisPhoneShown, 'Only on this phone');
    expect(
      l.homeScanTheirCodeSendShown,
      'Scan their code, send them a link, or type the @handle they gave you.',
    );
  });

  test('every computer string is in sentence case and has no em dash', () {
    for (final lang in langs) {
      final arb =
          jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync())
              as Map<String, dynamic>;
      for (final k in deskWordKeys) {
        final s = arb['${k}Desk'] as String;
        // a line that opens on a name or a handle starts as it is
        if (!RegExp(r'^[\u2066-\u2069]*@?\{').hasMatch(s)) {
          final first = s.replaceAll(RegExp(r'^[^\p{L}]+', unicode: true), '');
          expect(first[0], first[0].toUpperCase(), reason: '$lang $k');
        }
        final phone = arb[k] as String;
        if (!phone.contains('\u2014')) {
          expect(s, isNot(contains('\u2014')), reason: '$lang $k');
        }
      }
    }
  });

  test('no camera scan is offered on a computer', () {
    for (final (f, label) in [
      ('lib/app/shell.dart', 'appScanTheirCode,'),
      ('lib/screens/my_kryfo_screen.dart', 'myKryfoScanTheirsInstead'),
      ('lib/screens/onboarding_screen.dart', 'onboardingScanTheirs'),
      ('lib/screens/bridge_sheets.dart', 'bridgesScanACode'),
    ]) {
      final s = File(f).readAsStringSync();
      final at = s.indexOf('l10n.$label');
      expect(at, greaterThan(0), reason: f);
      final before = s.substring(at < 900 ? 0 : at - 900, at);
      expect(before, contains('if (!onDesktop)'), reason: f);
    }
  });
}
