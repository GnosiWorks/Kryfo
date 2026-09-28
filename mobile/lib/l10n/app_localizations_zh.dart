// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get atmosphereNone => '无';

  @override
  String get atmosphereEmber => '余烬';

  @override
  String get atmosphereDusk => '黄昏';

  @override
  String get atmosphereMoss => '苔藓';

  @override
  String get atmosphereRose => '玫瑰';

  @override
  String get atmosphereDots => '圆点';

  @override
  String get atmosphereGrid => '网格';

  @override
  String get atmosphereWaves => '波浪';

  @override
  String get atmosphereRain => '雨';

  @override
  String get atmosphereLateNight => '深夜';

  @override
  String get atmosphereWarmAfternoon => '温暖午后';

  @override
  String get atmosphereSnow => '雪';

  @override
  String get atmosphereDesert => '沙漠';

  @override
  String get atmospherePaper => '纸张';

  @override
  String get backupThatPassphraseDoesNot => '这个密码短语打不开此文件';

  @override
  String get backupThatFileIsNot => '这个文件不是 Kryfo 备份';

  @override
  String get backupThisBackupIsFrom => '这个备份来自更新版本的 Kryfo。请先更新应用，再试一次';

  @override
  String get backupThisFileIsDamaged => '这个文件已损坏，无法读取';

  @override
  String get backupCouldNotMakeThe => '无法生成密钥';

  @override
  String get contactCardMessageMeOn => '给我发消息，请用';

  @override
  String get contactCardScanItOrType =>
      '扫一扫，或者把这三个词输入 Kryfo。\n除此之外，这张卡片对你一无所知。';

  @override
  String contactCardMessageMeOnKryfo(Object haloId) {
    return '在 Kryfo 上给我发消息 · $haloId';
  }

  @override
  String get contactStatusBlocked => '已屏蔽';

  @override
  String get contactStatusKeysVerifiedInPerson => '已当面验证密钥';

  @override
  String get contactStatusWaitingInRequests => '在请求中等待';

  @override
  String get contactStatusAddedByHand => '手动添加';

  @override
  String get deliveryModeAlwaysOn => '始终在线';

  @override
  String get deliveryModeCheckIns => '定时查收';

  @override
  String get deliveryModeThroughAHelperApp => '通过辅助应用';

  @override
  String get deliveryModeNotYet => '还没有';

  @override
  String get deliveryModeJustNow => '刚刚';

  @override
  String deliveryModeMinAgo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 分钟前',
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
      other: '$countString 小时前',
    );
    return '$_temp0';
  }

  @override
  String get deliveryModeYesterday => '昨天';

  @override
  String deliveryModeDaysAgo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 天前',
    );
    return '$_temp0';
  }

  @override
  String get deliveryModeConnected => '已连接';

  @override
  String get deliveryModeConnecting => '正在连接';

  @override
  String get deliveryModeNotConnected => '未连接';

  @override
  String get deliveryModeCheckingNow => '正在查收';

  @override
  String deliveryModeLastCheckIn(Object agoLine) {
    return '上次查收 $agoLine';
  }

  @override
  String get deliveryModeNoCheckInYet => '还没有查收过';

  @override
  String deliveryModeConnectedNow(Object last) {
    return '已连接 · $last';
  }

  @override
  String deliveryModeConnecting2(Object last) {
    return '正在连接 · $last';
  }

  @override
  String get deliveryModeNoCheckInYet2 => '还没有查收过';

  @override
  String deliveryModeLastChecked(Object agoLine) {
    return '上次查收 $agoLine';
  }

  @override
  String get deliveryModeAHelperApp => '辅助应用';

  @override
  String deliveryModeWokenByNoWake(Object who) {
    return '由 $who 唤醒 · 还没有唤醒过';
  }

  @override
  String deliveryModeWokenByLastWake(Object who, Object agoLine) {
    return '由 $who 唤醒 · 上次唤醒 $agoLine';
  }

  @override
  String get introBudgetTomorrow => '明天';

  @override
  String introBudgetInDays(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 天后',
    );
    return '$_temp0';
  }

  @override
  String get introBudgetInAnHour => '1 小时后';

  @override
  String introBudgetInHours(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 小时后',
    );
    return '$_temp0';
  }

  @override
  String get introBudgetInAFewMinutes => '几分钟后';

  @override
  String get lockStateUnlockKryfo => '解锁 Kryfo';

  @override
  String get appInvalidUri => 'Uri 无效';

  @override
  String appBundleError(Object e) {
    return '密钥包错误：$e';
  }

  @override
  String appAlreadySaved(Object parsed) {
    return '已经保存过：$parsed';
  }

  @override
  String appAddedYouCanMessage(Object parsed) {
    return '已添加 $parsed · 现在可以给对方发消息了';
  }

  @override
  String appPeerImportedV1(Object parsed) {
    return '已导入对端（v1）：$parsed';
  }

  @override
  String appLongWindow(Object line) {
    return '$line，长时段';
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
      other: '$pString 页',
    );
    String _temp1 = intl.Intl.pluralLogic(
      e,
      locale: localeName,
      other: '$eString 个事件',
    );
    return '$line（$heldString/$subsString，连接 $c 秒，$_temp0，$_temp1）';
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
      other: '$pString 页',
    );
    String _temp1 = intl.Intl.pluralLogic(
      e,
      locale: localeName,
      other: '$eString 个事件',
    );
    return '$line（连接 $c 秒，$_temp0，$_temp1）';
  }

  @override
  String appSDropped(Object host, Object secs) {
    return '$host $secs 秒后断开';
  }

  @override
  String appS(Object host, Object secs) {
    return '$host $secs 秒';
  }

  @override
  String get appTorWouldNotWake => 'Tor 无法唤醒';

  @override
  String get appCheckStarted => '已开始';

  @override
  String get appTorNotReadyIn => 'Tor 75 秒内未就绪';

  @override
  String get appOk => '正常';

  @override
  String get appOkNoRelayBegan => '正常，没有中继响应';

  @override
  String get appOkCapped => '正常，已截止';

  @override
  String appSBy(Object how, int secs, String why) {
    final intl.NumberFormat secsNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String secsString = secsNumberFormat.format(secs);

    String _temp0 = intl.Intl.selectLogic(why, {
      'push': '$how，$secsString 秒，推送唤醒',
      'other': '$how，$secsString 秒，后台任务唤醒',
    });
    return '$_temp0';
  }

  @override
  String get appAnAttachmentCouldNot => '有个附件无法保存到这部手机上';

  @override
  String get appGroup2 => '群组';

  @override
  String get appVoiceMessage => '语音消息';

  @override
  String get appPhoto => '照片';

  @override
  String get appNewRequest => '新请求';

  @override
  String get appSomeoneYouHaveNot => '有个你没添加的人给你发了消息';

  @override
  String get appSettingUpYourKeys => '正在设置你的密钥';

  @override
  String get appOpeningYourChats => '正在打开你的聊天';

  @override
  String get appStartingTor => '正在启动 Tor';

  @override
  String get appTimedMessagesAreNot => '限时消息没有按时清除。请重启 Kryfo';

  @override
  String get appVoiceMessage2 => '语音消息';

  @override
  String appYou(Object body) {
    return '你：$body';
  }

  @override
  String get appThisRoomHasAlready => '这个聊天室已经过期了';

  @override
  String get appYouAreAlreadyIn => '你已经在这个聊天室里了';

  @override
  String get appCouldNotMakeA => '无法生成聊天室密钥';

  @override
  String appJoinedButYourHello(Object linkName) {
    return '已加入 $linkName，但你的问候被暂缓发送';
  }

  @override
  String appJoined(Object linkName) {
    return '已加入 $linkName';
  }

  @override
  String appJoinedButTheCreator(Object linkName) {
    return '已加入 $linkName，但暂时还联系不上创建者';
  }

  @override
  String get appBooting => '启动中…';

  @override
  String get appSettingUpYourIdentity => '正在设置你的身份…';

  @override
  String get appAddSomeone => '添加联系人';

  @override
  String get appScanTheirCodeOr => '扫描对方的二维码，或粘贴对方给你的内容：链接、@用户名或聊天室链接。';

  @override
  String get appScanTheirCode => '扫描对方的二维码';

  @override
  String get appAKryfoLinkA => 'Kryfo 链接、聊天室链接或 @wren';

  @override
  String get appAddThem => '添加对方';

  @override
  String get appEveryWayToAdd => '所有添加方式';

  @override
  String get appShowYourCodeSend => '出示你的二维码、发送链接、认领用户名';

  @override
  String get appHelloFromTheOther => '来自另一端的问候';

  @override
  String get appIdentityRestored => '身份已恢复';

  @override
  String get appIdentityCreated => '身份已创建';

  @override
  String get appStartingTor30s => '正在启动 tor（约 30 秒）…';

  @override
  String get appScanOrImportA => '请先扫描或导入一个对端';

  @override
  String get appEncryptingSending30s => '正在加密并发送（约 30 秒）…';

  @override
  String get appTapStartListeningFirst => '请先点“开始监听”';

  @override
  String get appYourKryfo => '你的 Kryfo';

  @override
  String get appUriCopied => 'Uri 已复制';

  @override
  String get appCopyUri => '复制 uri';

  @override
  String get appAddAKryfo => '添加 Kryfo';

  @override
  String get appScanQr => '扫描 QR 码';

  @override
  String get appPairingCode => '配对码';

  @override
  String get appOrPaste => '- 或粘贴 -';

  @override
  String get commonCancel => '取消';

  @override
  String get appImport => '导入';

  @override
  String get appDev => '开发';

  @override
  String get appYourKryfo2 => '你的 Kryfo：';

  @override
  String get appRestoredFromDisk => '已从磁盘恢复';

  @override
  String get appStartListening => '开始监听';

  @override
  String get appListening => '监听中';

  @override
  String get appShowMyQr => '显示我的 QR 码';

  @override
  String get appImportPeer => '导入对端';

  @override
  String get appPeer => '对端：';

  @override
  String get appMessageWillBeEncrypted => '消息（将被加密）';

  @override
  String get appEncryptSend => '加密并发送';

  @override
  String appStatus(Object status) {
    return '状态：$status';
  }

  @override
  String get appSpeedPrivacy => '速度与隐私 →';

  @override
  String get appGettingMessages => '接收消息 →';

  @override
  String get appDisableAppLock => '关闭应用锁？';

  @override
  String get appThePinWillBe => 'PIN 码将被移除。任何拿到你手机的人，打开 Kryfo 就能看到它。';

  @override
  String get appDisable => '关闭';

  @override
  String get appAppLockOn => '应用锁 · 开 →';

  @override
  String get appAppLockOff => '应用锁 · 关 →';

  @override
  String get appTorIsOff => 'Tor 已关闭';

  @override
  String get appConnectedRoutedThrough3 => '已连接 · 经 3 个中继转发';

  @override
  String get appReadyToSendPublishing => '可以发送 · 正在发布你的地址';

  @override
  String get appReadyToSendFinishing => '可以发送 · 正在完成设置';

  @override
  String appConnecting(Object pct) {
    return '正在连接 · $pct';
  }

  @override
  String get appTor => 'Tor';

  @override
  String get appTorIsOffTurn => 'Tor 已关闭。打开它才能私密连接。';

  @override
  String get appTheFirstConnectionTakes =>
      '首次连接需要一两分钟，tor 要先建一条私密路线。之后它会被缓存，以后打开 Kryfo 会快很多。';

  @override
  String get appRelayAndFastModes =>
      '中继模式和快速模式不走 tor，速度更快。它们在设置的“速度与隐私”里，每种模式都写明了代价。';

  @override
  String get appViaRelay => '经由中继';

  @override
  String get appOffline => '离线';

  @override
  String get appFast => '快速';

  @override
  String get appTorOff => 'Tor 已关';

  @override
  String get appTorReady => 'Tor 就绪';

  @override
  String get appConnecting2 => '正在连接';

  @override
  String mediaProgressSendingKeepTheApp(Object v) {
    return '正在发送 · $v · 请保持应用打开';
  }

  @override
  String mediaProgressPausedOfWaitingFor(Object count, Object count2) {
    return '已暂停 · $count/$count2 · 正在等待其余部分';
  }

  @override
  String mediaProgressReceivingMedia(Object v) {
    return '正在接收媒体 · $v';
  }

  @override
  String get mediaProgressCancelSending => '取消发送';

  @override
  String get metaReaderEndsBeforeItShould => '提前结束';

  @override
  String get metaReaderCouldNotBeRead => '无法读取';

  @override
  String get metaReaderExifThatCannotBe => '无法读取的 exif';

  @override
  String get metaReaderSamsungTrailer => '三星尾部数据';

  @override
  String metaReaderChunk(Object type) {
    return '数据块 $type';
  }

  @override
  String get metaReaderExifFlagSet => '已设 exif 标志';

  @override
  String get metaReaderXmpFlagSet => '已设 xmp 标志';

  @override
  String metaReaderAppBlock(Object id) {
    return '应用数据块 $id';
  }

  @override
  String get metaReaderUuidBox => 'uuid 盒';

  @override
  String metaReaderBox(Object printable) {
    return '$printable 盒';
  }

  @override
  String get metaReaderAttachedData => '附加数据';

  @override
  String metaReaderItem(Object printable) {
    return '$printable 项';
  }

  @override
  String get miuiAutostartAlreadyAllowedToRun => '已允许在后台运行';

  @override
  String get miuiAutostartLetKryfoRunIn => '允许 Kryfo 在后台运行';

  @override
  String get miuiAutostartYourPhonePausesApps =>
      '你的手机会暂停应用来省电。不设为例外的话，Kryfo 关闭时就收不到消息。';

  @override
  String get commonAllow => '允许';

  @override
  String get commonSkip => '跳过';

  @override
  String get miuiAutostartXiaomiTurnsOffBackground =>
      '小米默认会关闭后台应用。没有自启动，应用关闭时 Kryfo 就无法投递消息。在下一个页面，从列表里找到 Kryfo，打开它的开关。';

  @override
  String get miuiAutostartOpenSettings => '打开设置';

  @override
  String get miuiAutostartCouldnTOpenIt => '打不开。请在手机设置里找“自启动”';

  @override
  String get notificationsNewEncryptedMessagesFrom => '来自联系人的新加密消息';

  @override
  String get notificationsNewMessage => '新消息';

  @override
  String get notificationsNewEncryptedMessagesFromYourContacts => '来自联系人的新加密消息';

  @override
  String get notificationsNewMessage2 => '新消息';

  @override
  String get notificationsEncrypted => '已加密';

  @override
  String get rooms24h => '24 小时';

  @override
  String roomsD(Object inDays) {
    return '$inDays 天';
  }

  @override
  String roomsH(Object inHours) {
    return '$inHours 小时';
  }

  @override
  String get rooms24Hours => '24 小时';

  @override
  String roomsDays(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 天',
    );
    return '$_temp0';
  }

  @override
  String get roomsAnHour => '1 小时';

  @override
  String get roomsAboutAnHour => '大约 1 小时';

  @override
  String roomsHours(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 小时',
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
      other: '大约 $countString 小时',
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
      other: '$countString 分钟',
    );
    return '$_temp0';
  }

  @override
  String get roomsAMinute => '1 分钟';

  @override
  String get roomsExpired => '已过期';

  @override
  String roomsDH(Object inDays, Object h) {
    return '$inDays 天 $h 小时';
  }

  @override
  String roomsHM(Object inHours, Object m) {
    return '$inHours 小时 $m 分';
  }

  @override
  String roomsM(Object inMinutes) {
    return '$inMinutes 分钟';
  }

  @override
  String get scamShieldLooksLikeAScam => '疑似诈骗';

  @override
  String scamShieldThisNameMatches(Object shown) {
    return '这个名字和 $shown 一样';
  }

  @override
  String scamShieldNameMatchesYourContact(Object shown) {
    return '名字和你的联系人 $shown 一样';
  }

  @override
  String scamShieldSameFaceAsYour(Object shown) {
    return '和你的联系人 $shown 用同一张脸';
  }

  @override
  String get scamShieldContainsACryptoAddress => '含有加密货币地址';

  @override
  String get scamShieldMentionsMoneyAndUrgency => '既提到钱，又催得很急';

  @override
  String get scamShieldAsksYouToMove => '要你换到别的应用聊';

  @override
  String get scamShieldLinksToALookalike => '链接指向仿冒的知名网站';

  @override
  String get scamShieldALongOpenerFrom => '毫无往来的人发来一大段开场白';

  @override
  String get scamShieldAsksForACode => '索要验证码、助记词或恢复文件';

  @override
  String scamShieldAlso(Object shown) {
    return '另外：名字和你的联系人 $shown 一样';
  }

  @override
  String get commonBack => '返回';

  @override
  String get archivedArchived => '已归档';

  @override
  String get archivedCount0 => '没有';

  @override
  String get archivedCount1 => '一个';

  @override
  String get archivedCount2 => '两个';

  @override
  String get archivedCount3 => '三个';

  @override
  String get archivedCount4 => '四个';

  @override
  String get archivedCount5 => '五个';

  @override
  String get archivedCount6 => '六个';

  @override
  String get archivedCount7 => '七个';

  @override
  String get archivedCount8 => '八个';

  @override
  String get archivedCount9 => '九个';

  @override
  String get archivedCount10 => '十个';

  @override
  String get archivedChatRestingHereIt => '聊天在这里歇着。对方发消息之前它会保持安静，之后会回到顶部。';

  @override
  String get archivedChatsRestingHere => '聊天在这里歇着。有人发消息之前它们会保持安静，之后会回到顶部。';

  @override
  String get archivedNothingArchived => '没有归档的聊天';

  @override
  String get archivedArchivedChatsAreStill => '已归档的聊天仍然是端到端加密的';

  @override
  String get archivedUnarchive => '取消归档';

  @override
  String get avatarPickerThePeopleYouMessage => '和你聊天的人也会看到它';

  @override
  String get avatarPickerBackToYourInitial => '改回首字母';

  @override
  String get avatarPickerThatOneIsYours => '这个就是你的';

  @override
  String get avatarPickerPickAFace => '选一张脸';

  @override
  String get commonSave => '保存';

  @override
  String get backupPassphraseMustBeAt => '密码短语至少要 6 个字符';

  @override
  String get backupPassphrasesDonTMatch => '两次输入的密码短语不一致';

  @override
  String get backupBackupSavedKeepThe => '备份已保存 · 请保管好密码短语';

  @override
  String get backupKryfoBackup => 'Kryfo 备份';

  @override
  String get backupYourEncryptedKryfoBackup =>
      '你的加密 Kryfo 备份。这个文件和你的密码短语都要保管好——恢复时两样缺一不可。';

  @override
  String get backupBackUpKryfo => '备份 Kryfo';

  @override
  String get backupBackUp => '备份';

  @override
  String get backupACopyToKeep => '留一份副本。这部手机照常使用。';

  @override
  String get backupMoveToAnotherDevice => '迁移到另一台设备';

  @override
  String get backupTheFileTakesThis =>
      '这个文件会带走这个身份。文件一旦生成，这部手机就停用了：新的东西不会再到这里，从这里发出的任何东西也送不到任何人。';

  @override
  String get backupOneEncryptedFileYour =>
      '一个加密文件：你的身份、你的联系人、每一条消息，以及每一张照片、每一条语音和每一个文件。在另一台设备上用密码短语导入它。在那之前，你仍然可以改变主意，继续留在这部手机上。';

  @override
  String get backupOneEncryptedFileYourIdentityYour =>
      '一个加密文件：你的身份、你的联系人、每一条消息，以及这部手机上此刻的每一张照片、每一条语音和每一个文件。今天之后说的内容不在里面，所以重要的时候请再做一份。恢复时，文件和密码短语两样都要有。';

  @override
  String get backupPassphrase => '密码短语';

  @override
  String get backupConfirmPassphrase => '确认密码短语';

  @override
  String backupWriting(Object progress) {
    return '正在写入… $progress';
  }

  @override
  String get backupCreating => '正在创建…';

  @override
  String get backupMakeTheFileAnd => '生成文件并迁移';

  @override
  String get backupCreateBackup => '创建备份';

  @override
  String get backupHiddenNotIn => '隐藏聊天不在其中。';

  @override
  String get backupHiddenIncluded => '你的隐藏聊天也在其中。';

  @override
  String get backupMoveHiddenStay => '隐藏聊天留在这部手机上，并随它一起抹掉。';

  @override
  String get backupHiddenGone => 'Kryfo 锁定时，你的隐藏聊天已关闭。用隐藏聊天 PIN 打开它们，再从那里备份。';

  @override
  String get blockedBlocked => '已屏蔽';

  @override
  String get blockedNoOneIsBlocked => '没有屏蔽任何人';

  @override
  String get commonUnblock => '取消屏蔽';

  @override
  String get bridgesThatWasNotIt => '不对。换一道给你。';

  @override
  String get bridgesGotBridgesSaveTo => '已拿到网桥 · 保存后即可使用';

  @override
  String get bridgesConnected => '已连接';

  @override
  String get bridgesNotThroughYetTor => '还没连上。Tor 会继续尝试';

  @override
  String get bridgesBridges => '网桥';

  @override
  String get bridgesTorIsBlockedWhere => '你那里封锁了 tor？';

  @override
  String get bridgesBridgesDisguiseYourConnection =>
      '网桥会把你的连接伪装起来，让它能连出去。选一个入口，保存，tor 就会通过它重新连接。';

  @override
  String get bridgesBridgesOnlyChangeHow =>
      '网桥只改变 tor 的连接方式，而你现在没有用 onion 模式。你在这里的设置会保存下来，只是在你切换回去之前不起作用。';

  @override
  String get bridgesFromTheTorProject => '来自 tor 项目';

  @override
  String get bridgesNoise => '噪声';

  @override
  String get bridgesGood => '良好';

  @override
  String get bridgesMakesTorTrafficLook =>
      '让 tor 流量看起来不像任何特定的东西。对大多数被封锁的网络来说是最好的默认选择。先回答一个验证码，然后它会给你几条网桥地址。';

  @override
  String get bridgesPrivateBridge => '私人网桥';

  @override
  String get bridgesALineFromA => '朋友给的地址';

  @override
  String get bridgesWhateverTheLineSays => '取决于地址';

  @override
  String get bridgesDepends => '看情况';

  @override
  String get bridgesGotABridgeLine =>
      '从你信任的人那里，或者从 bridges.torproject.org 拿到了网桥地址？粘贴到这里。只支持 obfs4 地址，Kryfo 暂时还不支持其他类型。';

  @override
  String get bridgesPasteFromClipboard => '从剪贴板粘贴';

  @override
  String get bridgesUseBridges => '使用网桥';

  @override
  String get bridgesNoLinesYet => '还没有地址';

  @override
  String bridges1LineSaved(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已保存 $countString 条地址',
    );
    return '$_temp0';
  }

  @override
  String get bridgesRestartingTor => '正在重启 tor…';

  @override
  String bridgesFindingABridgeS(Object elapsed) {
    return '正在寻找网桥… $elapsed 秒';
  }

  @override
  String bridgesStillTryingS(Object elapsed) {
    return '仍在尝试… $elapsed 秒';
  }

  @override
  String get bridgesApplying => '正在应用…';

  @override
  String get bridgesSaveAndReconnect => '保存并重新连接';

  @override
  String get bridgesWhatABridgeIs => '网桥是什么';

  @override
  String get bridgesATorEntryPoint =>
      '一个没有任何人公开过的 tor 入口，通过一层包装连接，让连接看起来不像 tor。路线的其余部分还是通常的 3 跳。';

  @override
  String get bridgesLooksLike => '看起来像';

  @override
  String get bridgesSpeed => '速度';

  @override
  String get bridgesGetBridges => '获取网桥';

  @override
  String get bridgesAskTheTorProject => '直接向 tor 项目索取。你要解一道谜题，这样机器人就没法把网桥领光。';

  @override
  String get bridgesTypeWhatYouSee => '输入你看到的内容。小写也可以。';

  @override
  String get bridgesThisOneRequestDoes =>
      '只有这一次请求不经过 tor——也不可能经过，因为用不了的正是 tor。管理你所在网络的人会看到你在联系 tor 项目。如果单是这一点在你那里就有问题，请从别处获取网桥，再粘贴到下面。';

  @override
  String get bridgesCouldNotDrawThe => '无法显示谜题';

  @override
  String get bridgesAnswer => '答案';

  @override
  String get bridgesAsking => '正在请求…';

  @override
  String get bridgesRequestBridges => '请求网桥';

  @override
  String get bridgesDifferentPuzzle => '换一道谜题';

  @override
  String get cameraNoCameraOnThis => '这部手机没有相机';

  @override
  String get cameraCameraNotAvailable => '相机不可用';

  @override
  String get cameraCameraPermissionIsOff => '相机权限已关闭 · 点击重试';

  @override
  String get cameraCouldNotStripThat => '无法清除这张照片的元数据，已丢弃';

  @override
  String get cameraNoPhotoCameOut => '没有拍出照片';

  @override
  String get cameraCouldNotStartRecording => '无法开始录制';

  @override
  String get cameraTheRecordingWasLost => '录像丢失了';

  @override
  String get cameraACopyIsIn => '相册里有一份副本';

  @override
  String get cameraCouldNotSaveA => '无法在这部手机上保存副本';

  @override
  String get cameraTooLongForA => '太长，无法作为消息发送 · 最大 8 MB';

  @override
  String get cameraNeverSavedToYour => '不会保存到你的相册';

  @override
  String get cameraNoExifNeverSaved => '没有 exif，也不会保存到你的相册';

  @override
  String get cameraRec => '录制';

  @override
  String get cameraSwitchCamera => '切换相机';

  @override
  String cameraClipSMb(Object secs, Object mb) {
    return '片段 · $secs 秒 · $mb MB';
  }

  @override
  String get cameraStopRecording => '停止录制';

  @override
  String get cameraStartRecording => '开始录制';

  @override
  String get cameraTakeAPhoto => '拍照';

  @override
  String get cameraKeepACopy => '保留副本';

  @override
  String get cameraUseThis => '用这个';

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
  String get chatFile => '文件';

  @override
  String get chatYouAreOfflineThis => '你已离线 · 重新连上后会自动发出';

  @override
  String get chatStillConnectingToTor => '仍在连接 Tor · 连上后会自动发出';

  @override
  String chatS(Object seconds) {
    return '$seconds 秒';
  }

  @override
  String chatM(Object seconds) {
    return '$seconds 分';
  }

  @override
  String chatH(Object seconds) {
    return '$seconds 小时';
  }

  @override
  String chatD(Object seconds) {
    return '$seconds 天';
  }

  @override
  String get chat0s => '0 秒';

  @override
  String chatHM(Object h, Object m) {
    return '$h 小时 $m 分';
  }

  @override
  String chatMS(Object m, Object s) {
    return '$m 分 $s 秒';
  }

  @override
  String chatS2(Object s) {
    return '$s 秒';
  }

  @override
  String get chatNewMessages => '新消息';

  @override
  String get chatUnsave => '取消收藏';

  @override
  String get chatForward => '转发';

  @override
  String get commonShare => '分享';

  @override
  String get commonCopied => '已复制';

  @override
  String get commonCopy => '复制';

  @override
  String get chatUnpin => '取消置顶';

  @override
  String get chatPin => '置顶';

  @override
  String get chatStopSending => '停止发送';

  @override
  String get chatUnsend => '撤回';

  @override
  String get commonEdit => '编辑';

  @override
  String get chatYou => '你';

  @override
  String get chatUnsendMessage => '撤回消息';

  @override
  String get chatItDisappearsWithNo => '它会消失，不留任何痕迹。此操作无法撤销。';

  @override
  String chatThisChatHasPins(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '这个聊天已有 $countString 条置顶',
    );
    return '$_temp0';
  }

  @override
  String get chatUnpinThisMessage => '取消置顶这条消息？';

  @override
  String get chatPinThisMessage => '置顶这条消息？';

  @override
  String get chatItLeavesThePinned => '它会从你们双方的置顶列表中移除。';

  @override
  String get chatItGoesUnderThe => '它会出现在聊天顶部的置顶处，你们双方都能看到。';

  @override
  String get chatPinIt => '置顶';

  @override
  String get chatNotNow => '暂不';

  @override
  String get chatEditMessage => '编辑消息';

  @override
  String get chat30Seconds => '30 秒';

  @override
  String get chat1Minute => '1 分钟';

  @override
  String get chat5Minutes => '5 分钟';

  @override
  String get chat1Hour => '1 小时';

  @override
  String get chat24Hours => '24 小时';

  @override
  String get chatGhostTimer => '限时消息';

  @override
  String get chatHowLongBeforeSent => '发出的消息多久后焚毁？';

  @override
  String get chatCamera => '相机';

  @override
  String get chatNoExifNeverSaved => '没有 exif，也不会保存到你的相册';

  @override
  String get chatGallery => '相册';

  @override
  String get chatVideo => '视频';

  @override
  String get chatGifFromPhone => '手机里的 GIF';

  @override
  String get chatFile2 => '文件';

  @override
  String get chatAFewSeconds => '几秒钟';

  @override
  String get chatUnderAMinute => '不到 1 分钟';

  @override
  String chatRoughlyMin(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '大约 $countString 分钟',
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
  String get chatSendThis => '要发送这个文件吗？';

  @override
  String chatOverTor(Object humanBytes, Object wireEstimate) {
    return '$humanBytes · 经 tor 需要$wireEstimate';
  }

  @override
  String get chatBigFilesGoOut => '大文件会拆成加密的小块发出，所以需要一些时间。保持应用打开，它就会一直发下去。';

  @override
  String get chatSendIt => '发送';

  @override
  String get chatCouldNotReadThat => '无法读取这个文件';

  @override
  String get chatFileTooBig8 => '文件太大 · 最大 8 MB';

  @override
  String get chatCouldNotCleanThat => '无法清理这个视频';

  @override
  String get chatCouldNotCleanThatPictureSend => '无法清理这张图片 · 请作为照片发送';

  @override
  String get chatGifTooBig8 => 'GIF 太大 · 最大 8 MB';

  @override
  String get chatCouldNotCleanThatGif => '无法清理这个 GIF';

  @override
  String get chatTorIsNotUp => 'Tor 还没启动 · 不带预览发送';

  @override
  String get chatCouldnTReachIt => '无法访问 · 不带预览发送';

  @override
  String get chatNoTitleCameBack => '没有取到标题 · 不带预览发送';

  @override
  String get chatCouldnTFetchIt => '无法获取 · 不带预览发送';

  @override
  String get chatNoSignalSessionRe => '没有 Signal 会话——请重新配对';

  @override
  String get chatMessageUnavailable => '消息不可用';

  @override
  String get chatYou2 => '你';

  @override
  String get chatThem => '对方';

  @override
  String get chatVoiceMessage => '语音消息';

  @override
  String get chatQuotedPhoto => '照片';

  @override
  String get chatViewContact => '查看联系人';

  @override
  String get chatSharedPhotos => '共享的照片';

  @override
  String chatSharedPhotoCount(int count, Object title) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 张照片',
    );
    return '$_temp0 · $title';
  }

  @override
  String get chatUnmuteNotifications => '取消通知静音';

  @override
  String get chatMuteNotifications => '通知静音';

  @override
  String get chatArchiveChat => '归档聊天';

  @override
  String get chatWallpaper => '壁纸';

  @override
  String get chatClearConversation => '清空聊天记录';

  @override
  String get chatNoteOnThisContact => '联系人备注';

  @override
  String get chatPinToTop => '置顶聊天';

  @override
  String get chatBlockContact => '屏蔽联系人';

  @override
  String get chatUnpinned => '已取消置顶';

  @override
  String get chatPinnedToTop => '已置顶';

  @override
  String get chatJustForYouNever => '只给你自己看。绝不会发出，也绝不会离开这部手机。';

  @override
  String get chatAQuietReminder => '一条悄悄的提醒…';

  @override
  String get chatNoteSaved => '备注已保存';

  @override
  String get chatClearThisConversation => '清空这段聊天记录？';

  @override
  String get chatEveryMessageHereIs =>
      '这里的每条消息都会从这部手机上清除。这只清除你这边的副本——不会动到对方的设备。';

  @override
  String get chatClear => '清空';

  @override
  String get chatBlockThisContact => '屏蔽这位联系人？';

  @override
  String get chatTheirMessagesStopArriving =>
      '对方的消息将不再送达，对方也会从你的聊天列表中消失。对方不会被告知。你可以随时在设置里取消屏蔽。';

  @override
  String get commonBlock => '屏蔽';

  @override
  String get chatSaved => '已收藏';

  @override
  String get chatRemovedFromSaved => '已取消收藏';

  @override
  String get chatForwardTo => '转发给';

  @override
  String get chatNoContactsToForward => '没有可以转发的联系人';

  @override
  String get chatToday => '今天';

  @override
  String get chatYesterday => '昨天';

  @override
  String get chatThisMessageCanT => '这条消息无法显示';

  @override
  String get chatJumpToTheNewest => '跳到最新';

  @override
  String get chatBuildingAPrivateRoute =>
      '正在建立私密路线 · 首次连接比较慢，之后就快了。现在发送的内容会排队，稍后自动送达。';

  @override
  String get chatLooksSafeNothingSuspicious => '看起来安全 · 对方的第一条消息里没有可疑内容';

  @override
  String get chatTheNextPhotoYou => '你发的下一张照片会以受保护方式打开 · 对方无法截屏';

  @override
  String get chatPhotoProtectionOff => '照片保护已关闭';

  @override
  String get chatAcceptToReplyThey => '接受后才能回复——在你接受之前，对方还能再发一条消息。';

  @override
  String chatIntroducedYouAcceptTo(Object introducer) {
    return '$introducer 介绍你们认识。接受后就能回复。';
  }

  @override
  String chatIntroducedYouSayHello(Object vouchNames) {
    return '$vouchNames 介绍你们认识。打个招呼吧——对方也收到了你的名片。';
  }

  @override
  String get chatIntroduceTo => '介绍给…';

  @override
  String get chatAcceptThemFirst => '请先接受对方';

  @override
  String get chatMessageRequest => '消息请求';

  @override
  String get chatTheyNeedToAccept => '对方接受之后，你们才能继续聊。';

  @override
  String get chatWaitingForThemTo => '正在等待对方接受你的请求';

  @override
  String get chatYouBlockedThisContact => '你已屏蔽这位联系人';

  @override
  String get chatSupporter => '支持者';

  @override
  String get chatEncryptedViaRelay => '已加密 · 经由中继';

  @override
  String get chatEncryptedDirect => '已加密 · 直连';

  @override
  String get chatEncryptedOverTor => '已加密 · 经由 tor';

  @override
  String get chatSearchThisChat => '搜索此聊天';

  @override
  String get chatContactOptions => '联系人选项';

  @override
  String get commonClose => '关闭';

  @override
  String get chatFindInConversation => '在聊天中查找';

  @override
  String get chatNoMatches => '没有匹配';

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
      other: '第 *$posString* 个，共 $countString 个匹配',
      one: '第 *$posString* 个，共 $countString 个匹配',
    );
    return '$_temp0';
  }

  @override
  String get chatPreviousMatch => '上一个匹配';

  @override
  String get chatNextMatch => '下一个匹配';

  @override
  String get chatPhotoUnavailable => '照片不可用';

  @override
  String get chatDelivered => '已送达';

  @override
  String get chatEdited => '已编辑';

  @override
  String get chatWaitingForThemToComeOnline => '等待对方上线或把你加回去';

  @override
  String get chatFailedTapToRetry => '失败 · 点击重试';

  @override
  String get chatReplyingTo => '回复对方';

  @override
  String get chatReplyingToYourself => '回复自己';

  @override
  String get chatReply => '回复';

  @override
  String get chatSayHi => '打个招呼。';

  @override
  String get chatJustTheTwoOf => '只有你们两个人，端到端加密。';

  @override
  String get chatMicPermissionNeeded => '需要麦克风权限';

  @override
  String get chatTheMicWouldNot => '麦克风无法启动。请再试一次';

  @override
  String get chatReleaseToCancel => '松开取消';

  @override
  String get chatVoiceHiddenSlideTo => '已变声 · 滑动取消';

  @override
  String get chatSlideToCancel => '滑动取消';

  @override
  String get chatGhostMode => '限时消息';

  @override
  String chatMessagesBurnAfter(Object humanBurn) {
    return '$humanBurn后焚毁';
  }

  @override
  String get chatTimedMessages => '限时消息';

  @override
  String get chatOpenTheCamera => '打开相机';

  @override
  String get chatAttachAPhoto => '添加照片';

  @override
  String get chatMessage => '消息';

  @override
  String get chatDisguiseVoice => '变声';

  @override
  String get commonSend => '发送';

  @override
  String get chatNoPhotosInThis => '这个聊天里还没有照片';

  @override
  String get chatSendPhoto => '发送照片';

  @override
  String get chatAddACaption => '添加说明…';

  @override
  String get chatSecurityCodeChanged => '安全码已变更';

  @override
  String chatMayHaveReinstalledOr(Object peerName) {
    return '$peerName 可能重装了应用，也可能有人在冒充对方。比对安全码才能确定。';
  }

  @override
  String get chatOk => '好';

  @override
  String get chatVerify => '验证';

  @override
  String get cleanKryfoCanTClean => 'Kryfo 还不能清理这类文件。';

  @override
  String get cleanThisIsAMotion => '这是一张动态照片。';

  @override
  String get cleanThisPictureIsToo => '这张图片太大，无法在这里清理。';

  @override
  String get cleanThisFileIsDamaged => '这个文件已损坏或不完整。';

  @override
  String get cleanKryfoCouldNotMake => 'Kryfo 没能把它清理干净。';

  @override
  String get cleanNotEnoughRoomOn => '手机空间不足。';

  @override
  String get cleanKryfoCouldNotOpen => 'Kryfo 无法打开这个文件。';

  @override
  String get cleanItCleansJpegPng =>
      '它能清理 JPEG、PNG、WebP、HEIC、AVIF、GIF、MP4 和 MOV。没有做任何改动。';

  @override
  String get cleanItHoldsAShort =>
      '它在图片旁边还带着一段短视频，而 Kryfo 暂时还不能清理这部分。请在相机里关掉动态照片，或者发送它的截图。';

  @override
  String get cleanPicturesOver64Mb => '超过 64 MB 的图片不会在手机上清理。没有做任何改动。';

  @override
  String get cleanKryfoCouldNotRead => 'Kryfo 没能把它读完，所以不会说它是干净的。没有生成副本。';

  @override
  String get cleanSomethingInsideIsOf => '里面有它不知道怎么移除的内容，所以没有生成副本。';

  @override
  String get cleanFreeSomeSpaceAnd => '请腾出一些空间再试一次。没有做任何改动。';

  @override
  String get cleanTheAppThatShared => '分享它的应用可能已经把它收回了。请再分享一次。';

  @override
  String get cleanNoAppOnThis => '这部手机上没有应用接收这个文件。';

  @override
  String get cleanCouldNotSaveIt => '无法保存。请检查手机还有没有空间。';

  @override
  String get cleanTheOriginalIsGone => '原件已删除。干净的副本还在。';

  @override
  String get cleanAndroidWouldNotDelete => 'Android 不肯删除它。请手动从相册里删除。';

  @override
  String get cleanCleanCopy => '干净副本';

  @override
  String get cleanShareCleanCopy => '分享干净副本';

  @override
  String get cleanSaveToGallery => '保存到相册';

  @override
  String get commonStop => '停止';

  @override
  String get cleanReadingTheFile => '正在读取文件';

  @override
  String get cleanCleaning => '正在清理';

  @override
  String cleanOf(Object prettySize, Object prettySize2) {
    return '$prettySize / $prettySize2';
  }

  @override
  String get cleanEverythingStaysOnThis => '一切都留在这部手机上。';

  @override
  String get cleanAlreadyClean => '本来就是干净的。';

  @override
  String get cleanClean => '干净了。';

  @override
  String get cleanThereWasNothingTo => '本来就没有什么可找的。';

  @override
  String get cleanNothingLeftToFind => '已经没有可找的了。';

  @override
  String get cleanSameVideoSameQuality => '同样的视频，同样的画质';

  @override
  String get cleanSamePictureSameQuality => '同样的图片，同样的画质';

  @override
  String cleanRemoved(Object label) {
    return '$label，已移除';
  }

  @override
  String get cleanRemoved2 => '已移除';

  @override
  String get cleanWithTheLocationInside => '里面还带着位置信息。任何拿到它的人都能知道你在哪条街。';

  @override
  String get cleanWithEverythingItKnew => '它知道的一切都还在里面。';

  @override
  String get cleanOriginal => '原件';

  @override
  String get cleanClean2 => '干净';

  @override
  String get cleanSavedToYourGallery => '已保存到你的相册。';

  @override
  String cleanTheOriginalIsStill(Object what) {
    return '原件也还在，$what';
  }

  @override
  String cleanTheOriginalIsStillWhereIt(Object what) {
    return '原件还在原来的地方，${what}Kryfo 无法在这里移除它，请到它来自的应用里删除。';
  }

  @override
  String get cleanDeleteTheOriginal => '删除原件';

  @override
  String get cleanKeepBoth => '都保留';

  @override
  String get commonDone => '完成';

  @override
  String get cleanAndroidWillAskYou => '系统会请你确认';

  @override
  String get contactYourNameForThem => '你给对方的备注名';

  @override
  String get contactStaysOnThisPhone => '只保存在这部手机上。对方永远看不到。';

  @override
  String get contactClear => '清除';

  @override
  String get contactMessage => '发消息';

  @override
  String get contactKeysVerified => '密钥已验证';

  @override
  String get contactVerifyKeys => '验证密钥';

  @override
  String get contactVouches => '担保';

  @override
  String get contactUnmute => '取消静音';

  @override
  String get contactMute => '静音';

  @override
  String get contactUnpin => '取消置顶';

  @override
  String get contactPinToTop => '置顶聊天';

  @override
  String get contactArchive => '归档';

  @override
  String get contactOutOfTheList => '从列表中移出，直到对方再次发消息';

  @override
  String contactBlock(Object name) {
    return '屏蔽 $name？';
  }

  @override
  String get contactTheirMessagesStopArriving => '对方的消息将不再送达。对方不会被告知。';

  @override
  String get contactDeleteChat => '删除聊天';

  @override
  String get contactMessagesAndContactGone => '消息和联系人都会从这部手机上消失';

  @override
  String get contactDeleteThisChat => '删除这个聊天？';

  @override
  String get contactEveryMessageAndThe => '每一条消息和这位联系人都会从这部手机上消失。不会向对方发送任何内容。';

  @override
  String get commonDelete => '删除';

  @override
  String get contactDeleted => '已删除';

  @override
  String get contactToday => '今天';

  @override
  String contactD(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 天',
    );
    return '$_temp0';
  }

  @override
  String contactMo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个月',
    );
    return '$_temp0';
  }

  @override
  String contactY(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 年',
    );
    return '$_temp0';
  }

  @override
  String get contactVerified => '已验证';

  @override
  String get contactChatting => '聊天时长';

  @override
  String get contactNothingSharedYet => '还没有共享任何内容';

  @override
  String contactSharedMedia(Object count) {
    return '共享的媒体 · $count';
  }

  @override
  String get donateBitcoin => 'Bitcoin';

  @override
  String get donateText => '₿';

  @override
  String get donateBadgeUnlocks => '可解锁徽章';

  @override
  String get donateMonero => 'Monero';

  @override
  String get donateManualNoBadge => '手动 · 无徽章';

  @override
  String get donateSolana => 'Solana';

  @override
  String get donateEthereum => 'Ethereum';

  @override
  String get donateText2 => 'Ξ';

  @override
  String donateYourEarlierBitcoinPayment(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter': '已检测到你之前的 bitcoin 付款 · 支持者徽章已解锁',
      'patron': '已检测到你之前的 bitcoin 付款 · 赞助人徽章已解锁',
      'guardian': '已检测到你之前的 bitcoin 付款 · 守护者徽章已解锁',
      'other': '已检测到你之前的 bitcoin 付款 · 支持者徽章已解锁',
    });
    return '$_temp0';
  }

  @override
  String get donateSupport => '支持';

  @override
  String get donateKeepKryfo => '让 Kryfo 保持*独立*';

  @override
  String get donateNoAdsNoInvestors => '没有广告，没有投资人，没有东西要卖给你。它靠支持者的捐助运转。';

  @override
  String get donateBackItAnonymouslyBadge => '匿名支持它。徽章自愿领取。\n*隐私永远不设付费门槛。*';

  @override
  String donateAddressCheckItAgainst(Object coinName) {
    return '$coinName 地址 · 请和你的钱包核对';
  }

  @override
  String get donateAddressCopiedClearsIn => '地址已复制 · 60 秒后清除';

  @override
  String get donateCopyAddress => '复制地址';

  @override
  String get donateBitcoinIsVerifiedBy =>
      'Bitcoin 付款由我们自己的节点验证，所以付款一到账，你的徽章就会自动解锁。';

  @override
  String get donateWeCanTVerify =>
      '要验证这条链，我们就得向外部服务打听你的情况，所以我们不验证。你愿意的话照样可以发送。它不会解锁徽章。';

  @override
  String get donateBitcoinBadgesNeedOnion => 'Bitcoin 徽章需要 onion 模式';

  @override
  String get donateSwitchToOnion => '切换到 onion';

  @override
  String get donatePayWithBitcoin => '用 bitcoin 支付  →';

  @override
  String get donateBadgesStartAt20 => '徽章 \$20 起';

  @override
  String get donateReachingThePaymentService => '正在经由 tor 连接支付服务…';

  @override
  String get donateThisCanTakeUp => '最多可能需要 1 分钟';

  @override
  String donateSThisCanTake(Object waited) {
    return '$waited 秒 · 最多可能需要 1 分钟';
  }

  @override
  String get donateUseTheAddressInstead => '改用地址';

  @override
  String get donateThePaymentServiceIs =>
      '支付服务是一个 onion 服务，只有 onion 模式才能连上。什么都没有发送。';

  @override
  String get donateTorWasSlowTo =>
      'Tor 连接支付服务太慢了。你可以向下面的地址捐款——只是徽章不会自动解锁。想要徽章的话，稍后再试。';

  @override
  String get donateThePaymentServiceIsHavingTrouble =>
      '支付服务现在出了点问题。你仍然可以向下面的地址捐款——只是徽章不会自动解锁。想要徽章的话，稍后再试。';

  @override
  String get commonTryAgain => '重试';

  @override
  String donateBtc(Object btc) {
    return '$btc BTC';
  }

  @override
  String donateSendExactlyThisAmount(Object fmtLeft) {
    return '请发送这个准确金额 · $fmtLeft 后过期';
  }

  @override
  String get donateOpenWallet => '打开钱包';

  @override
  String get donateThisScreenUpdatesItself =>
      '一检测到你的付款，这个页面就会自动更新。\n请保持打开——什么都不会被保存，也没有任何信息能识别你。';

  @override
  String get donateWatchingTheChainFor => '正在链上等待你的付款';

  @override
  String get donateThisInvoiceExpired => '这张账单已过期';

  @override
  String get donateInvoicesTimeOutIf =>
      '账单会超时。如果你已经付款，请保持这个页面打开：接下来一段时间里，我们每分钟都会再向服务查询一次，下次你打开“支持”时也会再查。你随时可以新开一张。';

  @override
  String get donateNewInvoice => '新账单';

  @override
  String get donateIPaidCheckAgain => '我已付款，再查一次';

  @override
  String get donatePaymentConfirmed => '付款已确认';

  @override
  String get donateThankYouForKeeping => '谢谢你让 Kryfo 保持独立。';

  @override
  String donateVerifiedOnChainYou(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter': '已在链上验证——你现在是支持者了。谁也拿不走。',
      'patron': '已在链上验证——你现在是赞助人了。谁也拿不走。',
      'guardian': '已在链上验证——你现在是守护者了。谁也拿不走。',
      'other': '已在链上验证——你现在是支持者了。谁也拿不走。',
    });
    return '$_temp0';
  }

  @override
  String get donateWearMyBadge => '佩戴我的徽章';

  @override
  String get donateJustGladToHelp => '能帮上忙就好';

  @override
  String get gettingMessagesGettingMessages => '接收消息';

  @override
  String get gettingMessagesHowNewMessagesReach => '新消息如何到达这部手机。你随时可以更改。';

  @override
  String get gettingMessagesAlwaysOn => '始终在线';

  @override
  String get gettingMessagesMostPrivate => '最私密';

  @override
  String get gettingMessagesMessagesArriveInstantlyNothing =>
      '消息即时到达。任何东西都不会离开 tor。最耗电。';

  @override
  String get gettingMessagesCheckIns => '定时查收';

  @override
  String get gettingMessagesLightest => '最省电';

  @override
  String get gettingMessagesKryfoLooksForMessages =>
      'Kryfo 每 15 分钟查收一次消息。省电，但消息可能会晚到。';

  @override
  String get gettingMessagesOnTheLockScreen => '锁屏上';

  @override
  String get gettingMessagesHideMessagePreview => '隐藏消息预览';

  @override
  String get gettingMessagesAGenericAlertWith => '一条通用提醒，不显示发送者和消息内容';

  @override
  String get gettingMessagesShowsMessageTextIn => '在通知里显示消息内容，即使 Kryfo 已锁定。';

  @override
  String get gettingMessagesWhenThePhoneSits =>
      '手机静置不动时，Android 会拉长查收的间隔。上面那行显示的是真实的上一次查收。Kryfo 打开时会一直保持连接。';

  @override
  String get groupChatJumpToTheNewest => '跳到最新';

  @override
  String get groupChatBlockedEverywhere => '已在各处屏蔽';

  @override
  String get groupChatYou => '你';

  @override
  String get groupChatVoiceMessage => '语音消息';

  @override
  String get groupChatQuotedPhoto => '照片';

  @override
  String get groupChatMessageUnavailable => '消息不可用';

  @override
  String get groupChatTorIsNotUp => 'Tor 还没启动 · 不带预览发送';

  @override
  String get groupChatCouldnTReachIt => '无法访问 · 不带预览发送';

  @override
  String get groupChatNoTitleCameBack => '没有取到标题 · 不带预览发送';

  @override
  String get groupChatCouldnTFetchIt => '无法获取 · 不带预览发送';

  @override
  String get groupChatCamera => '相机';

  @override
  String get groupChatGallery => '相册';

  @override
  String get groupChatVideo => '视频';

  @override
  String get groupChatGifFromPhone => '手机里的 GIF';

  @override
  String get groupChatFile => '文件';

  @override
  String get groupChatCouldNotReadThat => '无法读取这个文件';

  @override
  String get groupChatGifTooBig8 => 'GIF 太大 · 最大 8 MB';

  @override
  String get groupChatCouldNotCleanThat => '无法清理这个 GIF';

  @override
  String get groupChatFileTooBig8 => '文件太大 · 最大 8 MB';

  @override
  String get groupChatCouldNotCleanThatVideo => '无法清理这个视频';

  @override
  String get groupChatCouldNotCleanThatPictureSend => '无法清理这张图片 · 请作为照片发送';

  @override
  String get groupChat30Seconds => '30 秒';

  @override
  String get groupChat1Minute => '1 分钟';

  @override
  String get groupChat5Minutes => '5 分钟';

  @override
  String get groupChat1Hour => '1 小时';

  @override
  String get groupChat24Hours => '24 小时';

  @override
  String get groupChatBurnTimer => '限时消息';

  @override
  String get groupChatNewMessagesDisappearAfter => '新消息会在这段时间后消失';

  @override
  String get groupChatToday => '今天';

  @override
  String get groupChatYesterday => '昨天';

  @override
  String get groupChatYou2 => '你';

  @override
  String groupChatThisChatHasPins(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '这个聊天已有 $countString 条置顶',
    );
    return '$_temp0';
  }

  @override
  String get groupChatUnpinThisMessage => '取消置顶这条消息？';

  @override
  String get groupChatPinThisMessage => '置顶这条消息？';

  @override
  String get groupChatItLeavesThePinned => '它会从这里所有人的置顶列表中移除。';

  @override
  String get groupChatItGoesUnderThe => '它会出现在聊天顶部的置顶处，这里的所有人都能看到。';

  @override
  String get groupChatUnpin => '取消置顶';

  @override
  String get groupChatPinIt => '置顶';

  @override
  String get groupChatNotNow => '暂不';

  @override
  String get groupChatSaved => '已收藏';

  @override
  String get groupChatRemovedFromSaved => '已取消收藏';

  @override
  String get groupChatForwardTo => '转发给';

  @override
  String get groupChatNoContactsToForward => '没有可以转发的联系人';

  @override
  String get groupChatEditMessage => '编辑消息';

  @override
  String get groupChatUnsendMessage => '撤回消息';

  @override
  String get groupChatItDisappearsWithNo => '它会消失，不留任何痕迹。此操作无法撤销。';

  @override
  String get groupChatUnsend => '撤回';

  @override
  String groupChatThisRoomAndEverything(Object expiryWords) {
    return '$expiryWords后，这个聊天室和里面的一切都会消失';
  }

  @override
  String groupChatGhostModeOnBurns(Object fmtBurn) {
    return '限时消息 · $fmtBurn后焚毁';
  }

  @override
  String get groupChatGroupCreatedSayHi => '群组已创建。打个招呼吧。';

  @override
  String get groupChatNoMessagesYet => '还没有消息。';

  @override
  String get groupChatThisMessageCanT => '这条消息无法显示';

  @override
  String groupChatS(Object s) {
    return '$s 秒';
  }

  @override
  String groupChatM(Object s) {
    return '$s 分';
  }

  @override
  String groupChatH(Object s) {
    return '$s 小时';
  }

  @override
  String groupChatD(Object s) {
    return '$s 天';
  }

  @override
  String groupChatHere(int count, Object time) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$time · $countString 人在此',
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
      other: '$countString 位成员',
    );
    return '$_temp0';
  }

  @override
  String get groupChatSearchThisChat => '搜索此聊天';

  @override
  String groupChatReplyingTo(Object name) {
    return '回复 $name';
  }

  @override
  String get groupChatReplyingToYou => '回复你';

  @override
  String get groupChatTimedMessages => '限时消息';

  @override
  String get groupChatOpenTheCamera => '打开相机';

  @override
  String get groupChatAttachAPhoto => '添加照片';

  @override
  String get groupChatMessage => '消息';

  @override
  String get groupChatDisguiseVoice => '变声';

  @override
  String get groupChatSupporter => '支持者';

  @override
  String get groupChatEdited => '已编辑';

  @override
  String get groupChatTapToRetry => '! 点击重试';

  @override
  String get groupChat0s => '0 秒';

  @override
  String get groupChatReply => '回复';

  @override
  String get groupChatPin => '置顶';

  @override
  String get groupChatUnsave => '取消收藏';

  @override
  String get groupChatForward => '转发';

  @override
  String get groupInfoGroup => '群组';

  @override
  String get groupInfoRenameGroup => '重命名群组';

  @override
  String get groupInfoRename => '重命名';

  @override
  String get groupInfoNoContactsToAdd => '没有可添加的联系人';

  @override
  String get groupInfoCouldNotAdd => '无法添加';

  @override
  String groupInfoRemove(Object haloId) {
    return '移除 $haloId？';
  }

  @override
  String get groupInfoTheyWillStopReceiving => '对方将不再收到这个群组的消息。';

  @override
  String get commonRemove => '移除';

  @override
  String get groupInfoClearThisConversation => '清空这段聊天记录？';

  @override
  String get groupInfoEveryMessageHereIs =>
      '这里的每条消息都会从这部手机上清除。这只清除你的副本，其他成员的还在。';

  @override
  String get groupInfoClear => '清空';

  @override
  String get groupInfoConversationCleared => '聊天记录已清空';

  @override
  String get groupInfoLeaveRoom => '退出聊天室？';

  @override
  String get groupInfoLeaveGroup => '退出群组？';

  @override
  String get groupInfoEverythingInItIs => '里面的一切会立即从这部手机上抹掉，你在这里用过的密钥也会永久消失。';

  @override
  String get groupInfoYouWillStopReceiving => '你将不再收到消息，其他成员会看到你退出。';

  @override
  String get groupInfoLeave => '退出';

  @override
  String get groupInfoGroupInfo => '群组信息';

  @override
  String groupInfo1Member(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 位成员',
    );
    return '$_temp0';
  }

  @override
  String get groupInfoAdmin => '管理员';

  @override
  String get groupInfoMembers2 => '成员';

  @override
  String get groupInfoInvite => '邀请';

  @override
  String get commonAdd => '添加';

  @override
  String get groupInfoYou => '你';

  @override
  String get groupInfoRemoveFromGroup => '从群组中移除';

  @override
  String get groupInfoWallpaper => '壁纸';

  @override
  String get groupInfoSharedMedia => '共享的媒体';

  @override
  String get groupInfoClearConversation => '清空聊天记录';

  @override
  String get groupInfoLeaveRoom2 => '退出聊天室';

  @override
  String get groupInfoLeaveGroup2 => '退出群组';

  @override
  String get groupInfoAddMembers => '添加成员';

  @override
  String groupInfoAdd(Object pickedLength) {
    return '添加 $pickedLength 人';
  }

  @override
  String handleYouAre(Object h) {
    return '你是 @$h';
  }

  @override
  String get handleHandleDeletedThePage => '用户名已删除 · 页面已不存在';

  @override
  String get handlePublicHandle => '公开用户名';

  @override
  String get handleOptionalYourThreeWords => '可选。不管有没有，你的三个词都照常可用。';

  @override
  String get handleWren => 'wren';

  @override
  String get handleALineAboutYou => '一句话介绍自己 · 可选';

  @override
  String get handleClaiming => '正在认领…';

  @override
  String get handleClaimThisHandle => '认领这个用户名';

  @override
  String get handleAnyoneWithThisLink => '任何拿到这个链接的人都能和你开始私密聊天。它只带着你的邀请，别无其他。';

  @override
  String get handleLinkCopied => '链接已复制';

  @override
  String get handleDeleteThisHandle => '删除这个用户名';

  @override
  String get handleChecking => '正在检查…';

  @override
  String get handleAvailable => '✓ 可用';

  @override
  String get handleAlreadyTaken => '已被占用';

  @override
  String get handleWhatAHandleDoes => '用户名有什么用';

  @override
  String get handleAnyoneWhoKnowsIt =>
      '任何知道它的人都可以请求给你发消息，这正是用户名的意义。这个页面只保存你的邀请和你写的那句话，别无其他，也不会记录谁看过它。你随时可以删除它。';

  @override
  String handleIsNotYoursOn(Object handle) {
    return '在这部手机上，@$handle 不属于你';
  }

  @override
  String handleTheRegistryHoldsIt(Object handle) {
    return '登记处用另一把密钥保存着它，很可能是这部手机在恢复之前的身份。添加 @$handle 的人联系不到你。在这里无法释放或更新它。请换一个名字。';
  }

  @override
  String get handleForgetItOnThis => '在这部手机上忘掉它';

  @override
  String get homeAddAContact => '添加联系人';

  @override
  String get commonSettings => '设置';

  @override
  String get homeYourKryfo => '你的 Kryfo';

  @override
  String homeDateWeekday(Object weekday) {
    return '$weekday';
  }

  @override
  String get homeAnHour => '1 小时';

  @override
  String homeHours(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 小时',
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
      other: '$countString 分钟',
    );
    return '$_temp0';
  }

  @override
  String get homeKryfoIsOffline => 'Kryfo 已离线';

  @override
  String homeTorHasNotBeen(Object howLong) {
    return 'Tor 已经 $howLong没能连上了。在它连上之前，什么都进不来，也出不去。';
  }

  @override
  String get homeReconnecting => '正在重新连接';

  @override
  String get homeReconnect => '重新连接';

  @override
  String get homeWhatIsWrong => '出了什么问题';

  @override
  String get homeKryfoWillCheckIn => 'Kryfo 会每 15 分钟查收一次';

  @override
  String get homeYourPhoneKeepsStopping => '你的手机一再停止 Kryfo';

  @override
  String get homeItHasClosedKryfo =>
      '今天它已经关掉 Kryfo 三次了，所以消息晚到或一直在等。定时查收不受影响：Kryfo 会每 15 分钟醒来一次，而不是一直保持连接。';

  @override
  String get homeSwitchToCheckIns => '切换到定时查收';

  @override
  String get homeNotNow => '暂不';

  @override
  String get homeNotificationsAreOff => '通知已关闭';

  @override
  String get homeAndroidIsBlockingThem =>
      'Android 正在拦截通知，所以 Kryfo 关闭时，什么都到不了你这里。你打开它时，消息仍会到达。';

  @override
  String get homeCouldnTOpenIt => '打不开。请在手机设置里找到 Kryfo';

  @override
  String get homeTurnThemOn => '打开通知';

  @override
  String get homeLeaveThemOff => '保持关闭';

  @override
  String get homeOurRelayIsQuiet => '我们的中继没有响应';

  @override
  String get homeRelayModeUsesOnly =>
      '中继模式只用我们自己的中继，而它现在没有响应。快速模式会同时加入公共中继，所以消息仍能送达。无论哪种方式，一切都仍是加密的。';

  @override
  String get homeSwitchedToFast => '已切换到快速模式';

  @override
  String get homeUseFastMode => '使用快速模式';

  @override
  String get homeKeepWaiting => '继续等待';

  @override
  String get homeNotConnecting => '连不上';

  @override
  String get homeBridgesAreOnAnd =>
      '网桥已开启，但 tor 仍然没连上。网桥比较慢，有些还会毫无预兆地失效。如果你的网络没有封锁 tor，直连更快也更可靠。';

  @override
  String get homeGoingDirectReconnecting => '改为直连 · 正在重新连接';

  @override
  String get homeTurnBridgesOff => '关闭网桥';

  @override
  String get homeStillTrying => '仍在尝试';

  @override
  String get homeTorIsNotGetting =>
      'Tor 连不出去。有些网络会故意封锁它。我们自己的中继只是一条普通连接，通常照样能用——也可以用网桥，只是设置起来更费时间。';

  @override
  String get homeSwitchedToRelay => '已切换到中继';

  @override
  String get homeUseOurRelay => '使用我们的中继';

  @override
  String get homeBridges => '网桥';

  @override
  String get homeOffline => '离线';

  @override
  String get homeWaiting => '等待中';

  @override
  String get homeNothingWaitingToSend => '没有待发送的内容';

  @override
  String homeWaitingSendsWhenYou(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 条待发送 · 恢复连接后发出',
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
      other: '$countString 条待发送 · tor 仍在连接',
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
      other: '$countString 条待发送 · 等对方把你加回去',
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
      other: '$countString 条待发送 · $parkedString 条在等对方把你加回去',
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
      other: '$countString 条待发送 · 正在发送',
    );
    return '$_temp0';
  }

  @override
  String get commonRetry => '重试';

  @override
  String get homeNoKryfosYet => '还没有 Kryfo 联系人。';

  @override
  String get homeScanTheirCodeSend => '扫描对方的二维码、给对方发链接，或者输入对方给你的 @用户名。';

  @override
  String get homeAddSomeone => '添加联系人';

  @override
  String get homeArchived => '已归档';

  @override
  String home1Chat(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 个聊天',
    );
    return '$_temp0';
  }

  @override
  String get homeGroups => '群组';

  @override
  String get homeRoom => '聊天室';

  @override
  String get homeNew => '新建';

  @override
  String homeRoomExpired(Object expiredRoomName) {
    return '$expiredRoomName · 聊天室已过期';
  }

  @override
  String get homeMentionedYou => '提到了你';

  @override
  String homeMembers(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 位成员',
    );
    return '$_temp0';
  }

  @override
  String get homeSupporter => '支持者';

  @override
  String get homeArchivedChats => '已归档的聊天';

  @override
  String get homeUnmute => '取消静音';

  @override
  String get homeMute => '静音';

  @override
  String get homeArchive => '归档';

  @override
  String get homeDeleteChat => '删除聊天';

  @override
  String get homeMessagesAndContactGone => '消息和联系人都会从这部手机上消失';

  @override
  String get homeDeleteThisChat => '删除这个聊天？';

  @override
  String homeEveryMessageWithGoes(Object c) {
    return '和 $c 的每一条消息都会删除，对方也不再是你的联系人。这只清除这部手机上的内容——对方的副本还留在对方那里。如果对方再发消息，会进入请求列表。';
  }

  @override
  String get homeQueued => '排队中';

  @override
  String get homeBlocked => '已屏蔽';

  @override
  String get homeRoomInvite => '聊天室邀请';

  @override
  String get homeNow => '刚刚';

  @override
  String homeM(Object inMinutes) {
    return '$inMinutes 分钟前';
  }

  @override
  String homeH(Object inHours) {
    return '$inHours 小时前';
  }

  @override
  String get homeYesterday => '昨天';

  @override
  String homeD(Object inDays) {
    return '$inDays 天前';
  }

  @override
  String get homeNoteToSelf => '给自己的笔记';

  @override
  String get homeOnlyOnThisPhone => '只在这部手机上';

  @override
  String get homeSaved => '收藏';

  @override
  String get homeKeptFromEveryChat => '来自每个聊天的收藏';

  @override
  String get homeRequests => '请求';

  @override
  String home1PersonWantsTo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 个人想联系你',
    );
    return '$_temp0';
  }

  @override
  String introduceGotItButCould(Object b, Object c) {
    return '$b 收到了，但联系不上 $c';
  }

  @override
  String introduceGotItButCouldNotBe(Object c, Object b) {
    return '$c 收到了，但联系不上 $b';
  }

  @override
  String get introduceCouldNotReachEither => '两个人都联系不上。请稍后再试';

  @override
  String introduceIntroduceTo(Object peerName) {
    return '把 $peerName 介绍给…';
  }

  @override
  String get introduceBothOfThemGet => '双方都会收到对方的名片。谁也看不到你给另一方起的备注名。';

  @override
  String get introduceNoOneElseTo => '暂时没有其他人可以介绍。请先添加另一位联系人。';

  @override
  String get introduceANoteLikeMy => '附言，比如“我表哥”——可选';

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
      other: '本周还能介绍 $leftString 次（共 $maxString 次）',
    );
    return '$_temp0';
  }

  @override
  String introduceNoIntroductionsLeftNext(Object refillPhrase) {
    return '介绍次数已用完。$refillPhrase会再有一次';
  }

  @override
  String get introduceIntroduce => '介绍';

  @override
  String get keyVerificationSafetyNumber => '安全码';

  @override
  String keyVerificationWith(Object peerName) {
    return '与 $peerName';
  }

  @override
  String keyVerificationIfSeesTheSame(Object peerName) {
    return '如果 $peerName 看到的是同一串数字，你们的消息就只有你们两个人能看到。当面比对，或者通过你信任的通话比对，是最可靠的确认方式——但这是可选的，聊天从不要求这一步。';
  }

  @override
  String get keyVerificationVerified => '已验证';

  @override
  String get keyVerificationMarkAsVerified => '标记为已验证';

  @override
  String get lockFileThatPasswordDoesNot => '这个密码打不开它。';

  @override
  String get lockFileThisFileIsDamaged => '这个文件已损坏。';

  @override
  String get lockFileThisFileWasLocked => '这个文件是用密钥锁定的，不是用密码。';

  @override
  String get lockFileThisIsNotA => '这不是一个锁定的文件。';

  @override
  String get lockFileNotEnoughFreeMemory => '当前可用内存不足。';

  @override
  String get lockFileStopped => '已停止。';

  @override
  String get lockFileItNeedsAPassword => '它需要密码。';

  @override
  String get lockFileKryfoCouldNotRead => 'Kryfo 无法读取或写入这个文件。';

  @override
  String get lockFileCheckCapitalsAndSpaces => '检查大小写和空格。没有人能重置它，包括我们。';

  @override
  String get lockFileItMayHaveBeen => '它可能在传输途中被截断了。请让对方重新发送。没有保存任何东西。';

  @override
  String get lockFileItOpensWithThe =>
      '它要用接收者本人的密钥文件，在电脑上的 age 工具里打开。Kryfo 能打开的是用密码锁定的那种。';

  @override
  String get lockFileKryfoOpensFilesLocked =>
      'Kryfo 能打开用 age 锁定的文件。这些文件通常以 .age 结尾。';

  @override
  String get lockFileCloseAFewApps => '关掉几个应用再试一次。密码校验需要短暂占用几百 MB 内存。';

  @override
  String get lockFileNothingWasSaved => '没有保存任何东西。';

  @override
  String get lockFileTypeOneOrLet => '自己输入一个，或者让 Kryfo 推荐四个词。';

  @override
  String get lockFileTheAppThatHolds => '保存它的应用可能已经把它收回了。请重新选择。';

  @override
  String get lockFileHidePassword => '隐藏密码';

  @override
  String get lockFileShowPassword => '显示密码';

  @override
  String get lockFileChangeFile => '更换文件';

  @override
  String get lockFileChange => '更换';

  @override
  String lockFileOf(Object prettySize, Object prettySize2) {
    return '$prettySize / $prettySize2';
  }

  @override
  String get lockFileEverythingStaysOnThis => '一切都留在这部手机上。';

  @override
  String get lockFileCouldNotMakeOne => '没能生成。请自己输入一个。';

  @override
  String get lockFileWriteItDownBefore => '锁定文件之前，先把它写下来';

  @override
  String get lockFileNoAppOnThis => '这部手机上没有应用接收这个文件。';

  @override
  String get lockFileSaved => '已保存';

  @override
  String get lockFileCouldNotSaveIt => '无法保存到那里。请换个文件夹。';

  @override
  String get lockFileLocked => '已锁定';

  @override
  String get lockFileLockAFile => '锁定文件';

  @override
  String get lockFileMixingThePassword => '正在处理密码';

  @override
  String get lockFileLocking => '正在锁定';

  @override
  String get lockFileSaveToFiles => '保存到“文件”';

  @override
  String get lockFileLockFile => '锁定文件';

  @override
  String get lockFileOnePassword => '一个密码。';

  @override
  String get lockFileNothingElseOpensIt => '别的都打不开它。';

  @override
  String get lockFileFile => '文件';

  @override
  String lockFileFromFiles(Object prettySize) {
    return '$prettySize · 来自“文件”';
  }

  @override
  String get lockFileFromFiles2 => '从“文件”选择';

  @override
  String get lockFilePassword => '密码';

  @override
  String get lockFileSuggestFourWords => '推荐四个词';

  @override
  String get lockFileTypeItAgain => '再输入一次';

  @override
  String get lockFileTheTwoDoNot => '两次输入还不一致。';

  @override
  String get lockFileHideTheFileName => '隐藏文件名';

  @override
  String lockFileItWillBeCalled(Object name) {
    return '它会被命名为“$name”。告诉对方这是什么类型的文件。';
  }

  @override
  String get lockFileTheNameAloneCan => '光是文件名就可能透露里面的内容。';

  @override
  String get lockFileAnyoneWithThePassword =>
      '任何知道密码的人都能打开它，在 Kryfo 里，或者在任何装了免费工具 age 的电脑上。忘了密码，这个文件就永远打不开了。没有人能重置它，包括我们。';

  @override
  String get lockFileLocked2 => '已锁定。';

  @override
  String get lockFileOnlyThePasswordOpens => '只有密码能打开它。';

  @override
  String lockFileSafeToEmailOr(Object prettySize) {
    return '$prettySize · 可以放心用邮件发送或存进 U 盘';
  }

  @override
  String get lockFileNoKryfoOnThe => '对方没有 Kryfo？在电脑上：';

  @override
  String get lockFileItAsksForThe => '它会要求输入密码。age 可在 age-encryption.org 免费获取';

  @override
  String lockTooManyTriesS(Object lockState) {
    return '尝试次数过多 · $lockState 秒';
  }

  @override
  String get lockNotIt => '不对';

  @override
  String get lockYourPin => '你的 PIN 码';

  @override
  String get lockUseFingerprint => '使用指纹';

  @override
  String get lockSetupUnlockWithFingerprint => '用指纹解锁？';

  @override
  String get lockSetupThePinStillWorks => 'PIN 码随时照常可用。这只是更快。';

  @override
  String get lockSetupUseFingerprint => '使用指纹';

  @override
  String get lockSetupPinOnly => '仅用 PIN 码';

  @override
  String get lockSetupOnceMore => '再输一次';

  @override
  String get lockSetupSetAPin => '设置 PIN 码';

  @override
  String get lockSetupThoseWereDifferentFrom => '两次不一样。从头再来。';

  @override
  String get lockSetupTheSameFourDigits => '再输入一次同样的数字';

  @override
  String get lockSetupFourDigitsAnythingYou => '四位或更多数字，选一个你记得住的';

  @override
  String get modesOnion => 'Onion';

  @override
  String get modesFullOnionRoutingThree =>
      '完整的 onion 路由，3 跳。一条消息需要两到五秒。没有人看得到你在和谁聊天。';

  @override
  String get modesSlower => '较慢';

  @override
  String get modesRelay => '中继';

  @override
  String get modesOneSealedConnectionTo =>
      '一条加密连接，直通 Kryfo 自己的中继，就像一个无日志可记的 VPN。消息大约一秒送达，在 tor 被封锁的地方也能用。';

  @override
  String get modesQuick => '快';

  @override
  String get modesRelayOnly => '仅中继';

  @override
  String get modesFast => '快速';

  @override
  String get modesPlainConnectionsToEvery => '与每个中继的普通连接。几乎即时，也是三种模式中最不私密的。';

  @override
  String get modesInstant => '即时';

  @override
  String get modesEveryRelayYouUse =>
      '你用到的每个中继都知道你连接时的地址，而不只是我们的中继。消息仍然是加密的，但你发过消息这件事并没有被加密。默认关闭，重装后也会重新关闭。';

  @override
  String get modesSpeed => '速度';

  @override
  String get modesPrivacy => '与隐私';

  @override
  String get modesChangeGloballyOrPer => '全局更改，或按聊天单独设置';

  @override
  String get modesSoon => '即将推出';

  @override
  String get modesActive => '使用中';

  @override
  String get modesSpeed2 => '速度';

  @override
  String get modesHops => '跳数';

  @override
  String get modesIp => 'IP';

  @override
  String get modesVisible => '可见';

  @override
  String get modesHidden => '已隐藏';

  @override
  String modesHeadsUp(Object warning) {
    return '*注意：*$warning';
  }

  @override
  String get modesOnionIsTheDefault =>
      'Onion 是默认模式，除非你更改，否则一直如此。切换会从下一条消息开始生效。';

  @override
  String get modesFastMode => '快速模式';

  @override
  String get modesPlainConnectionsToEveryRelayQuicker =>
      '与每个中继的普通连接。更快，但中继能看到你的 IP 地址。无论哪种方式，消息都保持端到端加密。';

  @override
  String get modesTurnOnFastMode => '开启快速模式';

  @override
  String get modesKeepItOff => '保持关闭';

  @override
  String get movedWipeThisPhone => '要从这部手机上抹掉 Kryfo 吗？';

  @override
  String get movedEverythingKryfoHoldsHere =>
      'Kryfo 在这里保存的一切都会被抹掉：消息、联系人、密钥。另一台设备保留着全部内容。此操作无法撤销。';

  @override
  String get movedWipeIt => '抹掉';

  @override
  String get movedNotMovingAfterAll => '不迁移了？';

  @override
  String get movedOnlyDoThisIf =>
      '只有在这个备份从未在任何地方导入过时才这么做。如果导入过，现在就有两台设备持有同一个身份，两边的消息都会开始丢失。';

  @override
  String get movedIMStayingHere => '我留在这里';

  @override
  String get movedStayingHere => '留在这里';

  @override
  String movedKryfoWillCloseNow(Object myId) {
    return 'Kryfo 现在会关闭。点击图标，以 $myId 的身份重新打开。';
  }

  @override
  String get movedReopenKryfo => '重新打开 Kryfo';

  @override
  String get movedThisKryfoHasMoved => '这个 Kryfo 已迁移';

  @override
  String movedIsNowOnAnother(Object myId) {
    return '$myId 现在在另一台设备上。这部手机仍能显示这里原有的内容，但不会再收到任何新东西，你从这里发出的任何东西也送不到任何人。';
  }

  @override
  String get movedKeepItToRead => '留着查看';

  @override
  String get movedWipeThisPhone2 => '从这部手机上抹掉 Kryfo';

  @override
  String get movedIMNotMoving => '我不迁移了';

  @override
  String get myKryfoAHandleIs3 => '用户名由 3 到 20 个字母、数字或 _ 组成';

  @override
  String get myKryfoInviteCopiedClearsIn => '邀请已复制 · 60 秒后清除';

  @override
  String myKryfoAddMeOnKryfo(Object myId, Object uri) {
    return '在 Kryfo 上加我。我的 ID 是 $myId\n\n点这里加我：\n$uri\n\nKryfo 是一款私密通讯应用。不用手机号，不用邮箱。';
  }

  @override
  String get myKryfoAddMeOnKryfo2 => '在 Kryfo 上加我';

  @override
  String get myKryfoAddSomeone => '添加联系人';

  @override
  String get myKryfoKryfoDoesnTScan => 'Kryfo 不会扫描你的通讯录，这正是关键。';

  @override
  String get myKryfoIfThisLinkEnds =>
      '如果这个链接流传到了你不希望的地方，请在设置里重置它。到时候，每个拿着它的人都需要一个新链接。';

  @override
  String get myKryfoAlreadyShareAFriend =>
      '你们在 Kryfo 上已经有共同的朋友？对方可以在自己的聊天里介绍你们认识，这样就不用走请求了。';

  @override
  String get myKryfoHandleCopied => '用户名已复制';

  @override
  String get myKryfoTheyReHereWith => '对方就在我身边';

  @override
  String get myKryfoPointYourPhonesAt => '把两部手机对准彼此。不经过任何服务器。';

  @override
  String get myKryfoScanTheirsInstead => '改为扫描对方的';

  @override
  String get myKryfoTheyReadYouA => '对方念一个码给你';

  @override
  String get myKryfoTheyReSomewhereElse => '对方不在身边';

  @override
  String get myKryfoSendThemALink => '给对方发一个链接。打开就直接进入添加。';

  @override
  String get myKryfoYourLinkAppearsOnce => '连接后会显示你的链接';

  @override
  String get myKryfoTheLinkCarriesYour =>
      '链接里有你的 ID、你的地址和开始聊天所需的密钥。在你到设置里重置它之前，它一直有效。';

  @override
  String get myKryfoSendTheLink => '发送链接';

  @override
  String get myKryfoAsACard => '作为名片';

  @override
  String get myKryfoAnImageWithThe => '一张带 QR 码的图片';

  @override
  String get myKryfoAsAFile => '作为文件';

  @override
  String get myKryfoContactFile => '联系人文件';

  @override
  String get myKryfoIKnowTheirHandle => '我知道对方的用户名';

  @override
  String get myKryfoTypeTheNameThey => '输入对方给你的 @名字。对方认领过用户名才有效。';

  @override
  String get myKryfoWren => 'Wren';

  @override
  String get myKryfoTheLookupAsksFor =>
      '查找只发送这一个名字，不带任何关于你的信息。你发给对方的第一条消息仍会作为请求送达。';

  @override
  String get myKryfoLooking => '正在查找…';

  @override
  String get myKryfoFindThem => '查找';

  @override
  String get myKryfoYourAddressAppearsOnce => '连接后会显示你的地址';

  @override
  String get myKryfoAPublicHandle => '公开用户名';

  @override
  String get myKryfoPutItInA => '把它写进个人简介。任何知道它的人都能找到你。';

  @override
  String get myKryfoANamePeopleCan => '一个别人可以用来找到你的名字。认领之前不开启。';

  @override
  String get newGroupCouldNotCreate => '无法创建';

  @override
  String get newGroupNewGroup => '新建群组';

  @override
  String get newGroupCreating => '正在创建…';

  @override
  String get newGroupCreate => '创建';

  @override
  String get newGroupGroupName => '群组名称';

  @override
  String get newGroupMembers => '成员';

  @override
  String get newGroupPickAtLeastOne => '至少选一个';

  @override
  String newGroupSelected(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已选 $countString 个',
    );
    return '$_temp0';
  }

  @override
  String get newGroupAddAtLeastOne => '创建群组之前，请先添加至少一位联系人。';

  @override
  String get notesToday => '今天';

  @override
  String get notesYesterday => '昨天';

  @override
  String get notesNoteToSelf => '给自己的笔记';

  @override
  String get notesOnlyOnThisPhone => '只在这部手机上';

  @override
  String get notesAQuietPlace => '一个安静的角落';

  @override
  String get notesJotAnythingDownIt => '随手记下任何东西。它留在这部手机上，绝不会离开。';

  @override
  String get notesJotSomethingDown => '记点什么…';

  @override
  String get onboardingPrivateByDefault => '默认私密';

  @override
  String get onboardingPrivateMessaging => '私密聊天，\n*没有套路*。';

  @override
  String get onboardingYourNameIsThree => '*你的名字就是三个词。*不要手机号，不要邮箱，不要通讯录。';

  @override
  String get onboardingNobodyGetsInUnless =>
      '*除非你允许，否则谁也进不来。*没有搜索功能。人都是手动添加的，双方都要加。';

  @override
  String get onboardingTheFirstConnectionTakes =>
      '*首次连接需要一分钟。*Kryfo 在发送前会先建立一条私密路线。之后就快了。';

  @override
  String get onboardingBegin => '开始';

  @override
  String get onboardingHaveABackupRestore => '有备份？恢复 →';

  @override
  String get onboardingKryfoIsOpenSource => 'Kryfo 是开源的';

  @override
  String get onboardingYourKryfoId => '你的 KRYFO ID';

  @override
  String get onboardingGeneratedFromAKey =>
      '由一把只存在于这部手机上的密钥生成。*好记，独一无二，只属于你。*别人都没有这个。';

  @override
  String get onboardingTryAnother => '换一个';

  @override
  String get onboardingUseThisName => '用这个名字 →';

  @override
  String get onboardingThreeWords => '三个词。*只属于你。*';

  @override
  String get onboardingPickA => '选一张*脸*。';

  @override
  String get onboardingDrawnOnThisPhone => '在这部手机上根据一个数字画出来，从不上传。随时可以更换。';

  @override
  String get onboardingThePeopleYouMessage => '和你聊天的人也会看到它';

  @override
  String get onboardingKeepMyInitial => '保留我的首字母';

  @override
  String get onboardingThatOne => '就这个 →';

  @override
  String get onboardingContinue => '继续 →';

  @override
  String get onboardingHowYourMessages => '你的消息如何*传递*。';

  @override
  String get onboardingYouCanChangeThis => '你随时可以在设置里更改，对所有人或单个聊天都行。';

  @override
  String get onboardingOnion => 'Onion';

  @override
  String get onboardingSlowerAMessageTakes => '较慢。一条消息需要两到五秒。';

  @override
  String get onboardingHidesYourAddressFrom => '对所有人隐藏你的地址，包括我们的中继。';

  @override
  String get onboardingRelay => '中继';

  @override
  String get onboardingOurRelaySeesYour => '我们的中继能看到你的地址。其他人都看不到。';

  @override
  String get onboardingAboutASecondWorks => '大约一秒。在 tor 被封锁的地方也能用。';

  @override
  String get onboardingFast => '快速';

  @override
  String get onboardingEveryRelayYouUse => '你用到的每个中继都能看到你的地址。三种模式中最不私密的。';

  @override
  String get onboardingNearInstant => '几乎即时。';

  @override
  String get onboardingKeepOnion => '保留 onion →';

  @override
  String get onboardingUseThis => '用这个 →';

  @override
  String get onboardingSkipOnionIsA => '跳过 · onion 就是不错的默认选择';

  @override
  String get onboardingThreeThingsThen => '三件事，\n然后*就可以开始了*。';

  @override
  String get onboardingEverythingElseTheApp => '其他的事，应用会在需要的时候告诉你。';

  @override
  String get onboardingYourNameIsThreeWords => '你的名字就是三个词';

  @override
  String get onboardingThatIsTheWhole =>
      '这就是全部身份。没有号码可泄露，没有邮箱可被钓鱼，没有东西可查。和你聊天的人看到的是这三个词和你选的脸。';

  @override
  String get onboardingNobodyCanReachYou => '在你允许之前，谁也联系不到你';

  @override
  String get onboardingAStrangerWithYour =>
      '知道你三个词的陌生人只能敲门。对方的第一条消息会在请求里等着，直到你同意；你也可以拒绝，而对方永远不会知道。';

  @override
  String get onboardingTheFirstConnectionTakesAMinute => '首次连接需要一分钟';

  @override
  String get onboardingKryfoBuildsAPrivateRouteBefore =>
      'Kryfo 在发送任何内容之前，都会先建立一条私密路线。你离线时，消息会等着，等你回来再送达。';

  @override
  String get onboardingYourIdentityLivesOn => '你的身份保存在这部手机上。准备好后，可以在设置里备份它。';

  @override
  String get onboardingIUnderstand => '我明白了 →';

  @override
  String get onboardingOneQuiet => '一条安静的*通知*。';

  @override
  String get onboardingAndroidNeedsAVisible =>
      '应用在后台监听时，Android 要求显示一条可见的通知。Kryfo 关闭时，消息就是这样送到你这里的。';

  @override
  String get onboardingSilentAndAtThe => '静音，而且在通知栏最底部';

  @override
  String get onboardingItNeverBuzzesTurn => '它从不振动。关掉它的话，消息会一直等到你再次打开应用。';

  @override
  String get onboardingGotIt => '知道了 →';

  @override
  String get onboardingNow => '现在，*添加联系人*。';

  @override
  String get onboardingTheAppIsReady => '应用已准备好。在你添加对方或允许对方进来之前，谁也无法给你发消息。';

  @override
  String get onboardingEveryWayToAdd => '所有添加方式';

  @override
  String get onboardingShowYourCodeSend => '出示你的二维码、给对方发链接，或者输入对方给你的 @用户名。';

  @override
  String get onboardingScanTheirs => '扫描对方的';

  @override
  String get onboardingPointTheCameraAt => '把相机对准对方的二维码';

  @override
  String get onboardingTheAppIsReadyWhenYou => '你准备好了，应用就准备好了。';

  @override
  String get onboardingNotNowAddPeople => '暂不 · 以后再加人';

  @override
  String get openLockedOpened => '已打开';

  @override
  String get openLockedOpenALockedFile => '打开锁定的文件';

  @override
  String get openLockedCheckingThePassword => '正在校验密码';

  @override
  String get openLockedOpening => '正在打开';

  @override
  String get openLockedFile => '文件';

  @override
  String get openLockedOpenFile => '打开文件';

  @override
  String get openLockedTypeThePassword => '输入密码。';

  @override
  String get openLockedItOpensOnThis => '它会在这部手机上打开。';

  @override
  String get openLockedLockedFile => '锁定的文件';

  @override
  String openLockedFromFiles(Object prettySize) {
    return '$prettySize · 来自“文件”';
  }

  @override
  String get openLockedFromFiles2 => '从“文件”选择';

  @override
  String get openLockedPassword => '密码';

  @override
  String get openLockedThePasswordIsChecked =>
      '先校验密码。只有校验通过后，Kryfo 才会问你把打开的文件放在哪里，然后直接存到那里。';

  @override
  String get openLockedOpened2 => '已打开。';

  @override
  String get openLockedSavedWhereYouChose => '已保存到你选的位置。';

  @override
  String get pairCodePairingCode => '配对码';

  @override
  String get pairCodeShowACode => '出示配对码';

  @override
  String get pairCodeEnterOne => '输入配对码';

  @override
  String get pairCodeSixDigits => '六位数字';

  @override
  String get pairCodeLooking => '正在查找…';

  @override
  String get pairCodeNothingThereYetTrying => '那里还没有 · 正在重试';

  @override
  String get pairCodeNothingAtThatCode => '这个码下面什么都没有。它可能已经焚毁，或者对方还没有分享。';

  @override
  String get pairCodeTypeTheSixDigits => '输入对方念出的六位数字。';

  @override
  String get pairCodeAddThem => '添加对方';

  @override
  String get panicSetupThoseWereDifferentFrom => '两次不一样。从头再来。';

  @override
  String get panicSetupOnceMore => '再输一次';

  @override
  String get panicSetupTheSameFourDigits => '再输入一次同样的数字';

  @override
  String get photoKnowsEverythingInside => '里面的一切';

  @override
  String get photoKnowsVideo => '视频';

  @override
  String get photoKnowsPhoto => '照片';

  @override
  String get photoKnowsWhatThisVideoKnows => '这段视频知道什么';

  @override
  String get photoKnowsWhatThisPhotoKnows => '这张照片知道什么';

  @override
  String get photoKnowsRemoveAllOfIt => '全部移除';

  @override
  String get photoKnowsKeepItAsIt => '保持原样';

  @override
  String get photoKnowsReadOnThisPhone => '在这部手机上读取 · 视频哪儿也没去';

  @override
  String get photoKnowsReadOnThisPhoneThePhoto => '在这部手机上读取 · 照片哪儿也没去';

  @override
  String get photoKnowsReadingTheFile => '正在读取文件';

  @override
  String photoKnowsOf(Object prettySize, Object prettySize2) {
    return '$prettySize / $prettySize2';
  }

  @override
  String get photoKnowsEverythingStaysOnThis => '一切都留在这部手机上。';

  @override
  String photoKnowsMapWithAPin(Object place) {
    return '标出位置的地图。$place';
  }

  @override
  String get photoKnowsDrawnOffline => '离线绘制';

  @override
  String photoKnowsShowEverything(Object title) {
    return '$title。显示全部';
  }

  @override
  String get pinsAppLock => '应用锁';

  @override
  String get pinsYourPin => '你的 PIN 码';

  @override
  String get commonOn => '开';

  @override
  String get commonOff => '关';

  @override
  String get pinsOpensKryfoFourDigits => '用来打开 Kryfo。每次切到前台时都会要求输入。';

  @override
  String get pinsChangePin => '更改 PIN 码';

  @override
  String get pinsSetAPin => '设置 PIN 码';

  @override
  String get pinsTurnOff => '关闭';

  @override
  String get pinsTurnOffTheApp => '关闭应用锁？';

  @override
  String get pinsThePinGoesAnd =>
      'PIN 码会被移除，抹掉 PIN 和所有隐藏聊天也一起移除。任何拿着你手机的人都能以你的身份打开 Kryfo。';

  @override
  String get pinsUnlockWithFingerprint => '用指纹解锁';

  @override
  String get pinsWipePin => '抹掉 PIN';

  @override
  String get pinsNeedsAPinFirst => '需要先设置 PIN 码';

  @override
  String get pinsSet => '已设置';

  @override
  String get pinsChangeWipePin => '更改抹掉 PIN';

  @override
  String get pinsSetAWipePin => '设置抹掉 PIN';

  @override
  String get pinsRemove => '移除';

  @override
  String get pinsRemoveTheWipePin => '移除抹掉 PIN？';

  @override
  String get pinsTheLockScreenKeeps => '锁屏仍使用你的 PIN 码。抹掉 PIN 将不再起任何作用。';

  @override
  String profileCopied(Object what) {
    return '$what 已复制';
  }

  @override
  String get profileProfile => '个人资料';

  @override
  String get profileChangeYourFace => '更换你的脸';

  @override
  String get profileKryfoId => 'Kryfo ID';

  @override
  String get profileOnionAddress => 'Onion 地址';

  @override
  String get profileSupporterBadge => '支持者徽章';

  @override
  String profileYouAreAThank(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter': '你是支持者。谢谢你。',
      'patron': '你是赞助人。谢谢你。',
      'guardian': '你是守护者。谢谢你。',
      'other': '你是支持者。谢谢你。',
    });
    return '$_temp0';
  }

  @override
  String get profileShowMyBadge => '显示我的徽章';

  @override
  String get profileOnMyOwnScreens => '在我自己的屏幕上';

  @override
  String get profileLetContactsSeeIt => '让联系人看到';

  @override
  String get profileOffByDefault => '默认关闭';

  @override
  String get profileShareConnect => '分享与添加';

  @override
  String get profileMyKryfoCode => '我的 Kryfo 二维码';

  @override
  String get profileAddContact => '添加联系人';

  @override
  String get profileGiveAgain => '再次捐助';

  @override
  String get profileSupportKryfo => '支持 Kryfo';

  @override
  String get profileKryfoRunsOnWhat => 'Kryfo 靠大家的捐助运转';

  @override
  String get profileKeepKryfoIndependent => '让 Kryfo 保持独立';

  @override
  String get qrLink => '链接';

  @override
  String get qrYourLinkAsTyped => '就是你输入的链接 · 没有跟踪跳转';

  @override
  String get qrText => '文本';

  @override
  String get qrStaysInTheCode => '内容就在码里 · 没有服务器保存它';

  @override
  String get qrWiFi => 'Wi-Fi';

  @override
  String get qrMadeOnThisPhone => '在这部手机上生成 · 没有网站看到密码';

  @override
  String get qrNetworkName => '网络名称';

  @override
  String get qrPassword => '密码';

  @override
  String get qrContact => '联系人';

  @override
  String get qrOnlyWhatYouType => '只有你输入的内容 · 不取用通讯录里的任何东西';

  @override
  String get qrName => '姓名';

  @override
  String get qrPhone => '电话';

  @override
  String get qrEmail => '邮箱';

  @override
  String get qrOpensTheirMailApp => '打开对方的邮件应用 · 不从这里发送任何东西';

  @override
  String get qrTo => '收件人';

  @override
  String get qrSubject => '主题';

  @override
  String get qrANumberNothingElse => '一个号码 · 别无其他';

  @override
  String get qrNumber => '号码';

  @override
  String get qrSms => 'SMS';

  @override
  String get qrOpensTheirMessagesApp => '打开对方的短信应用 · 不从这里发送任何东西';

  @override
  String get qrMessage => '消息';

  @override
  String get qrLocation => '位置';

  @override
  String get qrCoordinatesOnlyNoMap => '只有坐标 · 不询问任何地图服务';

  @override
  String get qrLatitude => '纬度';

  @override
  String get qrLongitude => '经度';

  @override
  String get qrBitcoin => 'Bitcoin';

  @override
  String get qrAddressAndAmountNo => '地址和金额 · 中间没有支付网站';

  @override
  String get qrAddress => '地址';

  @override
  String get qrAmountInBtc => '金额（BTC）';

  @override
  String get qrInk => '墨黑';

  @override
  String get qrAmber => '琥珀';

  @override
  String get qrViolet => '紫罗兰';

  @override
  String get qrCouldNotDrawThe => '无法生成图片。';

  @override
  String get qrSavedToYourGallery => '已保存到你的相册';

  @override
  String get qrCouldNotSaveIt => '无法保存。请检查手机还有没有空间。';

  @override
  String get qrNoAppOnThis => '这部手机上没有应用接收这张图片。';

  @override
  String get qrTooMuchForOne => '内容太多，一个码装不下。请缩短一些。';

  @override
  String get qrThisIsALot => '这些内容对一个码来说有点多。较旧的相机可能读不出来。';

  @override
  String get qrPrivateQrCode => '私密 QR 码';

  @override
  String get qrColour => '颜色';

  @override
  String get qrCopiedItLeavesThe => '已复制。1 分钟后会从剪贴板清除';

  @override
  String get qrSecurity => '安全性';

  @override
  String get qrNone => '无';

  @override
  String get qrSaveImage => '保存图片';

  @override
  String qrColour2(Object name) {
    return '$name色';
  }

  @override
  String get qrTypeBelowAndThe => '在下面输入，\n码会自动生成';

  @override
  String get qrQrCode => 'QR 码';

  @override
  String get qrHidePassword => '隐藏密码';

  @override
  String get qrShowPassword => '显示密码';

  @override
  String get qrCopyPassword => '复制密码';

  @override
  String get requestsSentAnAttachment => '发来一个附件';

  @override
  String get requestsWantsToConnect => '想加你';

  @override
  String get requestsAccepted => '已接受';

  @override
  String requestsBlock(Object id) {
    return '屏蔽 $id？';
  }

  @override
  String get requestsNothingMoreFromThem =>
      '对方的任何东西都不会再到达你这里。对方的请求和其中的消息都会被删除。';

  @override
  String get requestsBlocked => '已屏蔽';

  @override
  String get requestsDeleted => '已删除';

  @override
  String get requestsRequests => '请求';

  @override
  String get requestsNoRequests => '没有请求';

  @override
  String get requestsMessagesFromPeopleYou => '你还没添加的人发来的消息，会先出现在这里。';

  @override
  String get requestsLooksSafeNothingSuspicious => '看起来安全 · 对方的第一条消息里没有可疑内容';

  @override
  String get commonAccept => '接受';

  @override
  String get requestsDecline => '拒绝';

  @override
  String get restoreThatFileIsNot => '这个文件不是 Kryfo 备份';

  @override
  String get restoreThisFileIsDamaged => '这个文件已损坏，无法读取';

  @override
  String get restoreTypeThePassphraseThe => '输入制作这个文件时用的密码短语';

  @override
  String get restoreReplaceTheAccountOn => '替换这部手机上的账号？';

  @override
  String get restoreWhatIsHereNow =>
      '这里现有的一切，包括它的身份、联系人和消息，都会被清除。这个文件会取而代之。此操作无法撤销。';

  @override
  String get restoreReplaceIt => '替换';

  @override
  String restoreCouldNotBeReleased(Object mine) {
    return '无法释放 @$mine';
  }

  @override
  String restoreTheRegistryDidNot(Object mine) {
    return '登记处没有响应。如果你继续，@$mine 仍会指向这部手机即将失去的身份。任何添加它的人发出的消息都没有人会收到，而且这个名字无法再被认领。最好先联网，再试一次。';
  }

  @override
  String get restoreRestoreAnyway => '仍然恢复';

  @override
  String get restoreNotYet => '先不';

  @override
  String get restoreRestored => '已恢复';

  @override
  String restoreKryfoWillCloseNow(Object haloId) {
    return 'Kryfo 现在会关闭。点击图标，以 $haloId 的身份重新打开。';
  }

  @override
  String get restoreReopenKryfo => '重新打开 Kryfo';

  @override
  String get restoreTheRestoreDidNot => '恢复没有完成。没有做任何改动';

  @override
  String get restoreThisIdentity => '这个身份';

  @override
  String get restoreMoveYourKryfoHere => '把你的 Kryfo 迁移到这里';

  @override
  String restoreThisBackupIsRestoring(Object name) {
    return '这个备份属于 $name。恢复它会把那个身份迁移到这台设备上。';
  }

  @override
  String restoreThisBackupMadeOn(Object name, Object date, Object time) {
    return '这个备份属于 $name，制作于 $date $time。恢复它会把那个身份迁移到这台设备上。';
  }

  @override
  String restoreItHoldsOfPhotos(Object mb) {
    return '里面有 $mb 的照片、语音和文件。这可能需要几分钟。请保持应用打开。';
  }

  @override
  String get restoreWhatFollows => '会跟过来的';

  @override
  String get restoreYourNameYourCode => '你的名字、你的二维码，以及每一位联系人。';

  @override
  String get restoreEveryConversationBackTo => '每一段聊天，一直到最开始。';

  @override
  String get restoreYourPhotosVoiceNotes => '你的照片、语音和文件。';

  @override
  String restoreYourPhotosVoiceNotesCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '你的照片、语音和文件 · $countString 个。',
    );
    return '$_temp0';
  }

  @override
  String get restoreYourOnionAddressSo => '你的 onion 地址，这样直接联系你的人仍然能联系到你。';

  @override
  String get restoreAnythingSentToYou => '旧手机关机期间发给你的任何内容，只要是在十四天内发出的。';

  @override
  String get restoreYourSupporterBadgeIf => '你的支持者徽章（如果有的话）。';

  @override
  String get restoreWhatDoesnT => '不会跟过来的';

  @override
  String get restoreTheOldPhoneStops =>
      '从你在这里发出任何内容的那一刻起，旧手机就不再接收消息。不是逐渐停止。你从这台设备发出的第一条消息，是旧手机能跟上的最后一条；在那之后到达旧手机的任何内容，在那里都无法读取，在这里也不会等着你。';

  @override
  String get restoreIfThePhoneThis =>
      '如果这个文件来自的那部手机还在使用，请先在那部手机上停用 Kryfo，再继续。两部手机共用一个 Kryfo，两边都会丢消息。';

  @override
  String get restoreNotificationsNeedSettingUp => '通知需要在这台设备上重新设置。';

  @override
  String get restoreMoveItHere => '迁移到这里';

  @override
  String get restoreNotNow => '暂不';

  @override
  String get restoreRestore => '恢复';

  @override
  String get restoreFromABackupFile => '从备份文件恢复';

  @override
  String get restoreABackupBringsBack =>
      '备份能找回你的身份和联系人，以及制作文件时手机上已有的消息。之后说的内容不在里面。';

  @override
  String get restoreTheFile => '文件';

  @override
  String get restorePickTheBackupFile => '选择备份文件';

  @override
  String get restoreThePassphrase => '密码短语';

  @override
  String get restoreTheOneTheFile => '制作文件时用的那个';

  @override
  String get restoreWhatComesBack => '能找回什么';

  @override
  String get restoreChecking => '正在检查…';

  @override
  String get restoreCheckTheFile => '检查文件';

  @override
  String get restoreReleasingYourHandle => '正在释放你的用户名…';

  @override
  String restoreMoving(Object progress) {
    return '正在迁移… $progress';
  }

  @override
  String get restoreRestoring => '正在恢复…';

  @override
  String get restoreNotThisOne => '不是这个';

  @override
  String get restoreDateUnknown => '日期未知';

  @override
  String get restoreAnIdentity => '一个身份';

  @override
  String get restoreMessagesSentOrReceived => '在那个日期之后收发的消息不在这个文件里。';

  @override
  String restoreGb(Object bytes) {
    return '$bytes GB';
  }

  @override
  String restoreMb(Object bytes) {
    return '$bytes MB';
  }

  @override
  String get roomCreateCouldNotCreateThe => '无法创建聊天室';

  @override
  String get roomCreateBurnerRoom => '临时聊天室';

  @override
  String get roomCreateARoomThatEnds =>
      '一个会结束的聊天室。每个人都用专为它生成的密钥加入，结束时任何手机上都不会留下任何东西。';

  @override
  String get roomCreateRoomName => '聊天室名称';

  @override
  String get roomCreateEndsAfter => '多久后结束';

  @override
  String get roomCreateMemberCap => '人数上限';

  @override
  String roomCreateNoOnePastThe(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '前 $countString 人之后，谁也进不来',
    );
    return '$_temp0';
  }

  @override
  String get roomCreateOffAnyoneWithThe => '关。任何拿到链接的人';

  @override
  String roomCreateThisRoomAndEverything(Object expiryWords) {
    return '$expiryWords后，这个聊天室和里面的一切都会消失';
  }

  @override
  String get roomCreateCreating => '正在创建…';

  @override
  String get roomCreateCreateRoom => '创建聊天室';

  @override
  String get roomLinkSendTheRoomTo => '把聊天室发给';

  @override
  String get roomLinkTheyWillKnowThis =>
      '对方会知道这个聊天室来自你。在聊天室里，对方和其他人一样，显示为一把密钥。';

  @override
  String get roomLinkNoContactsYet => '还没有联系人';

  @override
  String roomLinkEndsIn(Object time) {
    return '$time后结束';
  }

  @override
  String get roomLinkAnyoneWithThisCan =>
      '在聊天室结束之前，任何拿到它的人都能加入。他们用专为这个聊天室生成的密钥进来，看不到他们到来之前发的任何内容。';

  @override
  String get roomLinkRoomLinkCopied => '聊天室链接已复制';

  @override
  String get roomLinkSendToAContact => '发给联系人';

  @override
  String get roomLinkCopyRoomLink => '复制聊天室链接';

  @override
  String get savedVoiceNote => '语音';

  @override
  String get savedPhoto => '照片';

  @override
  String get savedSaved => '收藏';

  @override
  String get savedNothingSavedYet => '还没有收藏';

  @override
  String get savedLongPressAnyMessage => '长按任意消息，点“保存”，就能把它留在这里。';

  @override
  String get savedViewInChat => '在聊天中查看';

  @override
  String get savedPhoto2 => '照片';

  @override
  String get scanThatSNotA => '这不是 Kryfo QR 码 · 继续对准';

  @override
  String get scanScanAKryfoQr => '扫描 Kryfo QR 码';

  @override
  String get scanFlash => '闪光灯';

  @override
  String get scanPointAtAKryfo => '对准 Kryfo QR 码 · 什么都不会离开你的手机';

  @override
  String get seenWhatWeCanSee => '我们能看到什么';

  @override
  String get seenEveryMessengerClaimsPrivacy =>
      '每个通讯应用都声称注重隐私。这是一份具体的清单，按线路列出，也包括对我们不利的部分。点一行查看原因。';

  @override
  String get seenHonestAboutTheLast =>
      '关于最后几行，实话实说：应用锁、抹掉 PIN 和加密存储就是为此准备的，而当有人拿着你已解锁的手机时，没有任何工具能救你。完整的威胁模型在代码仓库的 THREAT_MODEL.md 里，按 LINDDUN 编写。代码是开源的，所以这些都不需要你凭信任接受。';

  @override
  String get seenHidden => '已隐藏';

  @override
  String get seenNever => '从不';

  @override
  String get seenOnDevice => '在设备上';

  @override
  String get seenYours => '你的';

  @override
  String get seenUnaudited => '未审计';

  @override
  String get seenWhoYouTalkTo => '你在和谁聊天';

  @override
  String get seenEachConversationGetsIts =>
      '每段对话都有自己的地址，由双方的密钥推导而来。中继看到的是一个个互不相关的投递点，而不是一对人。';

  @override
  String get seenWhatYouSay => '你说了什么';

  @override
  String get seenEndToEndEncrypted =>
      '用 Signal 双棘轮端到端加密，然后再用 gift wrap 封装一层。我们就算想读，也读不了。';

  @override
  String get seenYourIpAddress => '你的 IP 地址';

  @override
  String get seenOurRelay => '我们的中继';

  @override
  String get seenEveryRelay => '每个中继';

  @override
  String get seenOnOnionEverythingLeaves =>
      '在 onion 模式下，一切都经由 tor 发出，中继看到的是一个出口节点，永远看不到你。在中继模式下，连接直达我们自己的中继：没有任何东西转发你的地址，也不做任何记录，但这一条连接我们看得到。在快速模式下，每个公共中继都会知道你连接过，但不知道你联系了谁，也不知道你说了什么。';

  @override
  String get seenYourContactGraph => '你的联系人关系图';

  @override
  String get seenKryfoDoesNotScan => 'Kryfo 不会扫描你的通讯录。这正是关键。这里根本没有手机号可以泄露。';

  @override
  String get seenIntroducer => '介绍人';

  @override
  String get seenWhenAContactIntroduces =>
      '当一位联系人把你介绍给某人时，这位联系人会知道你们两个现在有联系了。其他人都不会知道。中继看到的是密文，任何服务器都永远看不到关系图。';

  @override
  String get seenTheScamShield => '防骗盾';

  @override
  String get seenRunsOnYourPhone =>
      '在你的手机上运行，规则随应用一起提供。不联网，不下载任何名单。它只读取陌生人的第一条消息，看不到联系人发给你的任何内容。';

  @override
  String get seenBurnerRooms => '临时聊天室';

  @override
  String get seenRoomKeys => '聊天室密钥';

  @override
  String get seenYouJoinARoom =>
      '你用专为这个聊天室生成的密钥加入，所以里面的人得不到任何能在别处用上的信息。后加入的人看不到历史记录。到期时，密钥、消息和媒体都会被销毁。';

  @override
  String get seenLinkPreviews => '链接预览';

  @override
  String get seenOverTor => '经由 Tor';

  @override
  String get seenAPreviewIsFetched =>
      '预览由发送方经由 tor 获取，并放在加密消息里一起传送。接收方的手机不会发出任何请求。网站只知道有个用 tor 的人请求了一个页面，别的都不知道。永远不会加载任何图片，陌生人发来的链接只显示为纯文本。';

  @override
  String get seenASeizedUnlockedPhone => '被夺走的已解锁手机';

  @override
  String get seenIfSomeoneHoldsYour =>
      '如果有人拿着你已解锁的手机，他们就能读你的消息。应用锁、抹掉 PIN 和加密存储在那之前有用，在那之后就没用了。';

  @override
  String get seenTheCryptoItself => '加密本身';

  @override
  String get seenTheRatchetAndStorage =>
      '棘轮层和存储层都是标准实现。连接它们的那一层是我们自己写的，还没有任何独立第三方审查过。请把它当作 alpha 版本，因为它确实是。';

  @override
  String get seenOnion => 'Onion';

  @override
  String get seenRelay => '中继';

  @override
  String get seenFast => '快速';

  @override
  String get settingsWipeKryfo => '抹掉 Kryfo？';

  @override
  String get settingsIdentityMessagesContactsAnd =>
      '这部手机上的身份、消息、联系人和设置。除非你有备份，否则将永久消失。';

  @override
  String get commonContinue => '继续';

  @override
  String settingsTypeWipeToConfirm(Object word) {
    return '输入“$word”以确认';
  }

  @override
  String get settingsTheLastStepNothing => '最后一步。什么都不会留下。';

  @override
  String get settingsWipeWord => '抹掉';

  @override
  String get settingsWipeKryfo2 => '抹掉 Kryfo';

  @override
  String get settingsYourProtections => '你的保护';

  @override
  String get settingsTorRouting => 'Tor 路由';

  @override
  String get settingsConnecting => '正在连接';

  @override
  String get settingsOffMode => '关 · 中继模式';

  @override
  String get settingsOffFastMode => '关 · 快速模式';

  @override
  String get settingsAppLock => '应用锁';

  @override
  String get settingsBlockedByAndroid => '被 Android 拦截';

  @override
  String get settingsSpeedPrivacy => '速度与隐私';

  @override
  String get settingsFast => '快速';

  @override
  String get settingsRelay1Hop => '中继 · 1 跳';

  @override
  String get settingsOnion3Hops => 'Onion · 3 跳';

  @override
  String get settingsBridges => '网桥';

  @override
  String get settingsForNetworksThatBlock => '用于封锁 tor 的网络';

  @override
  String get settingsGettingMessages => '接收消息';

  @override
  String settingsPreviewHidden(Object deliveryModeName) {
    return '$deliveryModeName · 隐藏预览';
  }

  @override
  String settingsPreviewShown(Object deliveryModeName) {
    return '$deliveryModeName · 显示预览';
  }

  @override
  String get settingsRunInBackground => '后台运行';

  @override
  String get settingsSoMessagesArrive => '让消息能送达';

  @override
  String get settingsTransport => '传输';

  @override
  String get settingsWhatTheNetworkIs => '网络在做什么';

  @override
  String get settingsBlocked => '已屏蔽';

  @override
  String get settingsAcceptIntroductions => '接受介绍';

  @override
  String get settingsFriendsCanIntroduceYou => '朋友可以把你介绍给他们的朋友';

  @override
  String get settingsScamShield => '防骗盾';

  @override
  String get settingsChecksStrangersOnYour => '在你的手机上检查陌生人。什么都不会离开手机';

  @override
  String get settingsBlockScreenshots => '禁止截屏';

  @override
  String get settingsWholeAppHiddenFrom => '整个应用不出现在最近任务和截屏中 · 下次启动后生效';

  @override
  String get settingsWholeAppHiddenFromRecentsAnd => '整个应用不出现在最近任务和截屏中';

  @override
  String get settingsOnNextStart => '开 · 下次启动';

  @override
  String get settingsOffNextStart => '关 · 下次启动';

  @override
  String get settingsLightTheme => '浅色主题';

  @override
  String get settingsSameProtectionBrighter => '同样的保护，更明亮';

  @override
  String get settingsAppLock2 => '应用锁';

  @override
  String get settingsYourPinAndA => '你的 PIN 码和高级保护';

  @override
  String get settingsPinWipePin => 'PIN 码 · 抹掉 PIN';

  @override
  String get settingsBackUpIdentity => '备份身份';

  @override
  String get settingsEncryptedFile => '加密文件';

  @override
  String get settingsRestoreFromBackup => '从备份恢复';

  @override
  String get settingsReplaceCurrent => '替换当前身份';

  @override
  String get settingsDisguiseVoice => '变声';

  @override
  String get settingsShiftsYourPitchBefore => '语音发出前改变你的音调';

  @override
  String get settingsWhyKryfo => '为什么选 Kryfo';

  @override
  String get settingsHowItProtectsYou => '它如何保护你';

  @override
  String get settingsResetMyInviteLink => '重置我的邀请链接';

  @override
  String get settingsOldLinksAndCodes => '旧的链接和码对所有人失效';

  @override
  String get settingsResetInviteLink => '重置邀请链接？';

  @override
  String get settingsAnyoneWithAnOld =>
      '任何拿着旧码或旧链接的人，都将无法再通过任何线路联系你。拿到了却从没用过的人，需要你给一个新的。联系人、聊天和历史记录都会保留。';

  @override
  String get settingsReset => '重置';

  @override
  String get settingsInviteResetShareThe => '邀请已重置 · 分享新的码';

  @override
  String get settingsWhatWeCanSee => '我们能看到什么';

  @override
  String get settingsTheHonestList => '诚实的清单';

  @override
  String get settingsVersion => '版本';

  @override
  String get settings030Alpha => '0.4.1 · alpha 版';

  @override
  String get settingsReportAnIssue => '报告问题';

  @override
  String get settingsBugOrSecurityFlaw => 'Bug 或安全漏洞';

  @override
  String get settingsOpenSource => '开源';

  @override
  String get settingsLinkCopied => '链接已复制';

  @override
  String get settingsTheOfflineMapIn =>
      '“工具”里的离线地图基于 Natural Earth（公有领域）绘制。城镇名称来自 GeoNames（geonames.org），采用 CC BY 4.0 许可。';

  @override
  String get settingsNotIndependentlyAuditedPre =>
      '未经独立审计。Pre-alpha 版——适合测试，还不适合高风险用途。';

  @override
  String get settingsDangerZone => '危险区';

  @override
  String get settingsWipeKryfoFromThis => '从这部手机上抹掉 Kryfo';

  @override
  String get shieldCheckedOnThisPhone => '已在这部手机上检查。没有向任何地方发送任何东西。';

  @override
  String get toolsMoreTools => '更多工具';

  @override
  String get toolsCleanAPhotoOr => '清理照片或视频';

  @override
  String get toolsOrShareOneTo => '或者从相册分享到 Kryfo';

  @override
  String get toolsMakeAPrivateQr => '生成私密 QR 码';

  @override
  String get toolsLinksWiFiContacts => '链接、Wi-Fi、联系人等。离线生成';

  @override
  String get toolsLockAFile => '锁定文件';

  @override
  String get toolsWithAPasswordOpens => '用密码锁定。任何有 age 的地方都能打开';

  @override
  String get toolsOpenALockedFile => '打开锁定的文件';

  @override
  String get toolsAnyAgeFileSomeone => '别人发给你的任何 .age 文件';

  @override
  String get toolsWorksOfflineNoContacts => '离线可用 · 不需要联系人';

  @override
  String get toolsUsefulFrom => '从第一分钟起';

  @override
  String get toolsTheFirstMinute => '就能用上。';

  @override
  String get toolsEverythingHereHappensOn =>
      '这里的一切都在这部手机上完成。不上传任何东西，别人也不需要用 Kryfo。';

  @override
  String get toolsWhatDoesThisPhoto => '这张照片知道些什么？';

  @override
  String get toolsPlacePhoneTime => '地点 · 手机 · 时间';

  @override
  String get toolsPickAPhotoAnd => '选一张照片，看看它会泄露什么。然后留一份干净的副本。';

  @override
  String get toolsPickAPhoto => '选一张照片';

  @override
  String get toolsVideo => '视频';

  @override
  String get transportTransport => '传输';

  @override
  String get transportNothingHereLeavesThe =>
      '这里的内容都不会离开手机。这就是引擎用来决定下一步做什么的状态。';

  @override
  String get transportStayingAlive => '保持运行';

  @override
  String get transportCanSend => '可发送';

  @override
  String get commonYes => '是';

  @override
  String get transportNotYet => '还没有';

  @override
  String get transportOnline => '在线';

  @override
  String get transportOffline => '离线';

  @override
  String get transportQueuedToSend => '待发送';

  @override
  String get transportOnionPublished => 'Onion 已发布';

  @override
  String transportYes(Object uploads) {
    return '是（$uploads）';
  }

  @override
  String transportTryingS(Object pubFor) {
    return '正在尝试 $pubFor 秒';
  }

  @override
  String transportBenchedS(Object r) {
    return '暂停 $r 秒';
  }

  @override
  String transportFails(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 次失败',
    );
    return '$_temp0';
  }

  @override
  String get transportOk => '正常';

  @override
  String get transportRelaySubscriptions => '中继订阅';

  @override
  String get transportLastSent => '上次发送';

  @override
  String get transportNever => '从未';

  @override
  String transportSAgo(Object sx) {
    return '$sx 秒前';
  }

  @override
  String get transportLastReceived => '上次接收';

  @override
  String transportSAgo2(Object rx) {
    return '$rx 秒前';
  }

  @override
  String get transportWithNoContactsThe =>
      '没有联系人时，应用不会订阅任何中继地址，所以任何消息都到不了你这里。扫描一个人的二维码就能解决。';

  @override
  String get transportSendAnythingWaitingNow => '立即发送所有待发内容';

  @override
  String get transportOff => '关';

  @override
  String get transportStarting => '启动中';

  @override
  String get transportBootstrapped => '已完成引导';

  @override
  String get transportPublishingAddress => '正在发布地址';

  @override
  String get transportReachable => '可访问';

  @override
  String get transportOurRelayOnion => '我们的中继（onion）';

  @override
  String get transportNever2 => '从未';

  @override
  String get transportJustNow => '刚刚';

  @override
  String transportMAgo(Object inMinutes) {
    return '$inMinutes 分钟前';
  }

  @override
  String transportHAgo(Object inHours) {
    return '$inHours 小时前';
  }

  @override
  String transportDAgo(Object inDays) {
    return '$inDays 天前';
  }

  @override
  String transportM(Object inMinutes) {
    return '$inMinutes 分钟';
  }

  @override
  String transportHM(Object inHours, Object d) {
    return '$inHours 小时 $d 分';
  }

  @override
  String transportD(Object inDays) {
    return '$inDays 天';
  }

  @override
  String transportMb(Object b) {
    return '$b MB';
  }

  @override
  String get transportYesCheckedJustNow => '是 · 刚刚检查过';

  @override
  String transportNoLast(Object ago) {
    return '否 · 上次 $ago';
  }

  @override
  String get transportLastMessageIn => '上次收到消息';

  @override
  String get transportBatteryExemption => '电池优化豁免';

  @override
  String get transportUnknown => '未知';

  @override
  String get transportExempt => '已豁免';

  @override
  String get transportNotExemptTapTo => '未豁免 · 点击修复';

  @override
  String get transportProcessUp => '进程运行时长';

  @override
  String get transportLastStop => '上次停止';

  @override
  String transportEngine(Object mb, Object mb2) {
    return '$mb · 引擎 $mb2';
  }

  @override
  String get transportLastRelayArrival => '上次中继到达';

  @override
  String get transportLastCheckIn => '上次查收';

  @override
  String get transportNoneYet => '暂无';

  @override
  String get transportLastTorReconnect => '上次 Tor 重连';

  @override
  String get transportCatchUpByRelay => '按中继补收';

  @override
  String get transportControlPort => '控制端口';

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
      other: '$dialsString 次连接',
    );
    String _temp1 = intl.Intl.pluralLogic(
      timeouts,
      locale: localeName,
      other: '$timeoutsString 次超时',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get transportJobRuns => '任务运行';

  @override
  String transportLast(Object jobRuns, Object ago) {
    return '$jobRuns · 上次 $ago';
  }

  @override
  String get transportQuietStretches => '静默时段';

  @override
  String get transportNone => '无';

  @override
  String get transportClearThisRecord => '清除这条记录';

  @override
  String get transportNothingYetThisProcess => '本进程中还没有';

  @override
  String transportM2(Object mins) {
    return '$mins 分钟';
  }

  @override
  String transportHM2(Object mins, Object mins2) {
    return '$mins 小时 $mins2 分';
  }

  @override
  String transportTo(Object t, Object t2) {
    return '$t 至 $t2';
  }

  @override
  String vouchersVouchedBy(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 位担保人',
      one: '担保人',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperAtmosphere => '氛围';

  @override
  String get wallpaperJustForYouThey => '只有你看得到。对方看到的是他们自己的。';

  @override
  String get wallpaperYourPhoto => '你的照片';

  @override
  String get wallpaperFromYourPhotos => '从你的照片中选择';

  @override
  String get wallpaperKeepIt => '保留';

  @override
  String get whyKryfoWhyKryfo => '为什么选 Kryfo';

  @override
  String get whyKryfoKryfoKreeFoGreek =>
      'Kryfo · 读作 KREE-fo · 希腊语里的“隐藏”。\n一个安静的聊天之处，从设计上就没有人在看。';

  @override
  String get whyKryfoRoutedThroughTor => '经由 tor 路由';

  @override
  String get whyKryfoByDefaultEveryMessage =>
      '默认情况下，每条消息都经由 tor——一串中继——传送。任何人，无论是我们还是你的网络，都看不到你在和谁聊天、你在哪里。';

  @override
  String get whyKryfoEndToEndEncrypted => '端到端加密';

  @override
  String get whyKryfoMessagesAreSealedWith => '消息用只有你和对方持有的密钥加密。我们就算想读，也读不了。';

  @override
  String get whyKryfoNoServersHoldingYour => '没有服务器保管你的生活';

  @override
  String get whyKryfoNoAccountNoPhone =>
      '没有账号，没有手机号，没有保存你聊天记录的中央服务器。聊天记录保存在这部手机上，以加密形式存储。';

  @override
  String get whyKryfoNothingLeaks => '什么都不泄露';

  @override
  String get whyKryfoNoReadReceiptsOr =>
      '不会把已读回执或“正在输入”提示交给任何人，也不上传联系人列表。元数据是大多数应用泄露的东西——Kryfo 的设计就是不泄露它。';

  @override
  String get whyKryfoVerifyItIsReally => '确认真的是对方';

  @override
  String get whyKryfoCompareASafetyNumber =>
      '当面或通过你信任的渠道比对安全码，这样你就知道没有人在冒充你的联系人。';

  @override
  String get whyKryfoTheHonestPart => '坦白说';

  @override
  String get whyKryfoKryfoIsPreAlpha =>
      'Kryfo 还处于 pre-alpha 阶段，没有经过审计。加密是真的，但还没有外部专家检查过，所以请把它当作一个仍在开发中的作品，暂时还不能托付身家性命。';

  @override
  String get cleanerLocation => '位置';

  @override
  String get cleanerAlreadyBlankedByAndroid => '已被 Android 清空';

  @override
  String get cleanerPhoneModel => '手机型号';

  @override
  String get cleanerTimeTaken => '拍摄时间';

  @override
  String get cleanerSerialNumber => '序列号';

  @override
  String get cleanerOwnerName => '所有者姓名';

  @override
  String get cleanerHiddenThumbnail => '隐藏的缩略图';

  @override
  String get cleanerContentCredentials => '内容凭证';

  @override
  String get cleanerDataAfterThePicture => '图片之后的数据';

  @override
  String cleaner1OtherField(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '另外 $countString 个字段',
    );
    return '$_temp0';
  }

  @override
  String get lockWordsFourRandomWordsBeat => '四个随机的词胜过一个聪明的词。';

  @override
  String lockWordsTooShortAtLeast(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '太短了。至少需要 $countString 个字符。',
    );
    return '$_temp0';
  }

  @override
  String get lockWordsWeakWhoeverGetsThe => '弱。拿到文件的人想猜多快就猜多快。';

  @override
  String get lockWordsFairLongerIsStronger => '一般。越长越强。';

  @override
  String get lockWordsStrongFourRandomWords => '强。四个随机的词胜过一个聪明的词。';

  @override
  String photoStoryKm(Object m) {
    return '$m 公里';
  }

  @override
  String photoStory1Metre(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 米',
    );
    return '$_temp0';
  }

  @override
  String get photoStoryFarFromAnyTown => '远离任何城镇';

  @override
  String photoStoryNear(Object where) {
    return '$where 附近';
  }

  @override
  String photoStoryAboutKmFrom(Object near, Object where) {
    return '距离 $where 约 $near 公里';
  }

  @override
  String photoStoryS(Object s) {
    return '$s 秒';
  }

  @override
  String photoStory1S(Object s) {
    return '1/$s 秒';
  }

  @override
  String get photoStoryNotAKindKryfo => '这不是 Kryfo 能读取的类型。';

  @override
  String get photoStorySoItWillNot => '所以它不会去猜。';

  @override
  String get photoStoryThisFileIsDamaged => '这个文件已损坏或不完整。';

  @override
  String get photoStoryKryfoCouldNotRead => 'Kryfo 没能把它读完。';

  @override
  String get photoStoryWhereItWasRecorded => '录制地点';

  @override
  String get photoStoryWhereItWasTaken => '拍摄地点';

  @override
  String photoStoryLocation(Object coordsLine) {
    return '位置：$coordsLine';
  }

  @override
  String photoStoryHeightAboveTheSea(Object fix) {
    return '海拔：$fix 米';
  }

  @override
  String get photoStoryLocationHiddenByAndroid => '位置已被 Android 隐藏';

  @override
  String get photoStoryAndroidBlanksItWhen =>
      '用这种方式选择照片时，Android 会把它清空。从相册分享到 Kryfo 通常能保留它。你相册里的那张可能仍然带着它。';

  @override
  String get photoStoryLocationBlankedByAndroid =>
      '位置：在 Kryfo 看到之前已被 Android 清空';

  @override
  String photoStoryF(Object r) {
    return 'f/$r';
  }

  @override
  String get photoStoryWhatTookIt => '用什么拍的';

  @override
  String photoStoryPhoneOrCamera(Object phone) {
    return '手机或相机：$phone';
  }

  @override
  String get photoStoryWhenItWasRecorded => '录制时间';

  @override
  String get photoStoryToTheSecondWith => '精确到秒，含时区';

  @override
  String get photoStoryToTheSecond => '精确到秒';

  @override
  String photoStoryTime(Object dateFormat) {
    return '时间：$dateFormat';
  }

  @override
  String get photoStoryLens => '镜头';

  @override
  String photoStoryLens2(Object lens) {
    return '镜头：$lens';
  }

  @override
  String get photoStorySoftware => '软件';

  @override
  String photoStorySoftware2(Object software) {
    return '软件：$software';
  }

  @override
  String get photoStorySerialNumber => '序列号';

  @override
  String photoStorySerialNumber2(Object serial) {
    return '序列号：$serial';
  }

  @override
  String get photoStoryOwnerName => '所有者姓名';

  @override
  String photoStoryOwner(Object r) {
    return '所有者：$r';
  }

  @override
  String get photoStoryHiddenThumbnail => '隐藏的缩略图';

  @override
  String get photoStoryASmallCopyOf => '文件里藏着一份小尺寸的图片副本。它可能会暴露被裁掉的部分';

  @override
  String get photoStoryMakerNotes => '厂商备注';

  @override
  String get photoStoryMakerNotesABlock => '厂商备注：只有厂商才能读取的数据块';

  @override
  String get photoStoryEditingHistory => '编辑历史';

  @override
  String get photoStoryXmpEditingHistoryAnd => 'XMP：编辑历史和标签';

  @override
  String get photoStoryCaptions => '说明文字';

  @override
  String get photoStoryIptcCaptionsAndCredits => 'IPTC：说明文字和署名';

  @override
  String get photoStoryComment => '注释';

  @override
  String get photoStoryAWrittenComment => '一段文字注释';

  @override
  String get photoStoryContentCredentials => '内容凭证';

  @override
  String get photoStorySecondPicture => '第二张图片';

  @override
  String get photoStoryASecondPictureInside => '文件里的第二张图片';

  @override
  String get photoStoryMotionVideo => '动态视频';

  @override
  String get photoStoryAShortVideoInside => '文件里的一段短视频';

  @override
  String get photoStorySaveTime => '保存时间';

  @override
  String get photoStoryTheTimeItWas => '最后一次保存的时间';

  @override
  String get photoStoryTimeStamps => '时间戳';

  @override
  String get photoStoryCreationTimeStamps => '创建时间戳';

  @override
  String get photoStoryDataAfterThePicture => '图片之后的数据';

  @override
  String photoStoryDataAfterTheEnd(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '图片结束后的数据：$countString 字节',
    );
    return '$_temp0';
  }

  @override
  String photoStoryTextField(Object k) {
    return '文本字段：$k';
  }

  @override
  String photoStoryVideoTag(Object k) {
    return '视频标签：$k';
  }

  @override
  String photoStoryAlso(Object k) {
    return '另外：$k';
  }

  @override
  String photoStoryCameraSettingsFlashFocus(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 项相机设置（闪光灯、对焦、曝光）',
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
      other: '还有 $countString 个字段',
    );
    return '$_temp0';
  }

  @override
  String get photoStoryCameraSettings => '相机设置';

  @override
  String photoStoryAccurateToAbout(Object metres) {
    return '精确到约 $metres。';
  }

  @override
  String get photoStoryEnoughToFindThe => '足以找到门口。';

  @override
  String get photoStoryEnoughToFindTheStreet => '足以找到那条街。';

  @override
  String get photoStoryEnoughToFindTheArea => '足以找到那一带。';

  @override
  String get photoStoryItKnowsWhereYou => '它知道你当时在哪里。';

  @override
  String get photoStoryDownToTheBuilding => '精确到楼。';

  @override
  String get photoStoryAndroidHidTheLocation => 'Android 隐藏了位置。';

  @override
  String get photoStoryTheOriginalMayStill => '原件可能仍然带着它。';

  @override
  String get photoStoryNoLocationInThis => '这张没有位置信息。';

  @override
  String get photoStoryItStillSaysPlenty => '它透露的仍然不少。';

  @override
  String get photoStoryThisOneKnowsNothing => '这张什么都不知道。';

  @override
  String get photoStoryNothingToRemove => '没有可移除的。';

  @override
  String get qrPayloadOpensALink => '打开链接';

  @override
  String qrPayloadOpens(Object host) {
    return '打开 $host';
  }

  @override
  String get qrPayloadShowsANote => '显示一段文字';

  @override
  String get qrPayloadScanToJoin => '扫码加入';

  @override
  String qrPayloadScanToJoin2(Object oneLine) {
    return '扫码加入 · $oneLine';
  }

  @override
  String get qrPayloadANetworkNameIs => '网络名称最多 32 个字符。';

  @override
  String get qrPayloadAWiFiPassword => 'Wi-Fi 密码至少要 8 个字符。';

  @override
  String get qrPayloadSavesAContact => '保存联系人';

  @override
  String get qrPayloadWritesAnEmail => '写邮件';

  @override
  String get qrPayloadThatDoesNotLook => '这看起来不像邮箱地址。';

  @override
  String get qrPayloadCallsANumber => '拨打号码';

  @override
  String get qrPayloadWritesAText => '写短信';

  @override
  String get qrPayloadOpensAMap => '打开地图';

  @override
  String get qrPayloadLatitudeRunsFrom90 => '纬度范围是 -90 到 90，经度范围是 -180 到 180。';

  @override
  String get qrPayloadPayThisAddress => '向此地址付款';

  @override
  String get qrPayloadABitcoinAddressIs => 'Bitcoin 地址只能包含字母和数字。';

  @override
  String get qrPayloadTheAmountIsIn => '金额以 BTC 为单位，最多 8 位小数。';

  @override
  String vouchTextAnd(Object names, Object names2) {
    return '$names 和 $names2';
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
      other: '另外 $restString 人',
    );
    return '$names、$names2 和你认识的$_temp0';
  }

  @override
  String vouchTextVouchedBy(Object vouchNames) {
    return '担保人：$vouchNames';
  }

  @override
  String vouchTextIntroducedBy(Object vouchNames) {
    return '介绍人：$vouchNames';
  }

  @override
  String vouchTextThisSharesSAddress(Object a, Object b) {
    return '这会把 $a 的地址分享给 $b';
  }

  @override
  String get bootFailedKryfoCouldNotStart => 'Kryfo 无法启动';

  @override
  String get bootFailedThisIsAFault => '这是这台设备上的故障，不是网络问题。与 tor 无关。';

  @override
  String get kryfoLinkTextThatLinkIsNot => '这个链接 Kryfo 读不了';

  @override
  String kryfoLinkTextAdd(Object who) {
    return '添加 $who？';
  }

  @override
  String kryfoLinkTextThisIsAnInvite(Object who) {
    return '这是一个和 $who 聊天的邀请。只有在你知道链接来源时才添加对方。';
  }

  @override
  String get kryfoLinkTextAddThem => '添加对方';

  @override
  String get kryfoLinkTextNotNow => '暂不';

  @override
  String kryfoLinkTextJoin(Object roomName) {
    return '加入 $roomName';
  }

  @override
  String get kryfoLinkTextKryfoLink => 'Kryfo 链接';

  @override
  String kryfoLinkTextAdd2(Object who) {
    return '添加 $who';
  }

  @override
  String get kryfoLinkTextBurnerRoom => '临时聊天室';

  @override
  String get kryfoLinkTextThisRoomHasClosed => '这个聊天室已关闭';

  @override
  String kryfoLinkTextClosesIn(Object time) {
    return '$time后关闭';
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
      other: '$time后关闭 · 最多 $capString 人',
    );
    return '$_temp0';
  }

  @override
  String get kryfoLinkTextJoin2 => '加入';

  @override
  String get kryfoLinkTextYouJoinUnderA =>
      '你用专为这个聊天室生成的密钥加入。里面的任何人都看不到你的 Kryfo ID。';

  @override
  String get linkStubFetchedOverTorBy => '经由 tor 获取 · 由你的设备';

  @override
  String get linkStubFetchedOverTorByTheirDevice => '经由 tor 获取 · 由对方的设备';

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
  String get mediaBubblesFile => '文件';

  @override
  String get mediaBubblesAudioUnavailable => '音频不可用';

  @override
  String get mediaBubblesHidden => '已隐藏';

  @override
  String get mediaBubblesMicPermissionNeeded => '需要麦克风权限';

  @override
  String get mediaBubblesReleaseToCancel => '松开取消';

  @override
  String get mediaBubblesVoiceHiddenSlideTo => '已变声 · 滑动取消';

  @override
  String get mediaBubblesSlideToCancel => '滑动取消';

  @override
  String get mediaBubblesSendPhoto => '发送照片';

  @override
  String get mediaBubblesAddACaption => '添加说明…';

  @override
  String get motionStandby => '待命';

  @override
  String get motionConnecting => '正在连接';

  @override
  String get motionBuilding => '构建中';

  @override
  String get motionPublishing => '发布中';

  @override
  String get motionReady => '就绪';

  @override
  String get motionPreparingToConnect => '准备连接';

  @override
  String get motionFindingAPrivatePath => '寻找私密路径';

  @override
  String get motionCarvingThePath => '开辟路径';

  @override
  String get motionAnnouncingYourArrival => '宣告你的到来';

  @override
  String get motionYouReAnonymous => '你是匿名的';

  @override
  String get motionTorIsStartingIn => 'Tor 正在后台启动。连接建立时，这张图会逐渐亮起来。';

  @override
  String get motionMakingAFreshRoute => '正在通过匿名中继建立一条新路线。';

  @override
  String get motionBouncingThroughRelaysSo => '在中继之间辗转，让任何人都无法追溯到你。';

  @override
  String get motionTellingTheNetworkYou => '告诉网络你在线——但不透露你在哪里。';

  @override
  String get motionYourIpIsHidden => '你的 IP 已隐藏。只有知道你 Kryfo 的人才能联系到你。';

  @override
  String get motionBuilding2 => '构建中';

  @override
  String get motionOpen => '已打开';

  @override
  String get motionLive => '在线';

  @override
  String motionCircuit(Object circuit) {
    return '线路 · *$circuit*';
  }

  @override
  String get motionDelivered => '已送达';

  @override
  String get motionSent => '已发送';

  @override
  String get motion1Hop => '1 跳';

  @override
  String get motion3Hops => '3 跳';

  @override
  String get movedStripThisKryfoHasMoved =>
      '这个 Kryfo 已迁移到另一台设备。从这里发出的任何东西都送不到任何人。';

  @override
  String get navBarChats => '聊天';

  @override
  String get navBarTools => '工具';

  @override
  String get navBarSupport => '支持';

  @override
  String get navBarMe => '我';

  @override
  String get pairCodePanelPuttingYourInviteIn => '正在准备你的邀请';

  @override
  String get pairCodePanelYourInviteIsNot => '你的邀请还没准备好';

  @override
  String get pairCodePanelReadSixDigitsOut => '把六位数字念出来，对方就能添加你。其他什么都不需要交换。';

  @override
  String get pairCodePanelWorking => '处理中';

  @override
  String get pairCodePanelOrMakeASix => '或者生成一个六位数字的码，念给对方';

  @override
  String get pairCodePanelCodeCopied => '配对码已复制';

  @override
  String pairCodePanelBurnsIn(Object mm, Object ss) {
    return '$mm:$ss 后焚毁';
  }

  @override
  String get pairCodePanelTheyTapAddChoose => '对方点“添加”，选择“配对码”，然后输入这些数字。';

  @override
  String get pairCodePanelTheyOpenKryfoTap =>
      '对方打开 Kryfo，点“添加”，选择“配对码”，输入这六位数字。下一个人需要你再生成一个新的。';

  @override
  String pinsPinnedMessages(Object count) {
    return '置顶消息 · $count';
  }

  @override
  String get pinsPinnedMessages2 => '置顶消息';

  @override
  String get pinsPhoto => '照片';

  @override
  String get pinsVoiceMessage => '语音消息';

  @override
  String get pinsMessage => '消息';

  @override
  String pinsToday(Object hm) {
    return '今天 · $hm';
  }

  @override
  String get pinsPinned => '已置顶';

  @override
  String pinsOf(Object pinsLength, Object kMaxPins) {
    return '$pinsLength/$kMaxPins';
  }

  @override
  String get pinsNothingPinnedHereYet =>
      '这里还没有置顶内容。长按一条消息，选择“置顶”，它就会在这里等着聊天里的每个人。';

  @override
  String get pinsJump => '跳转';

  @override
  String get pinsUnpin => '取消置顶';

  @override
  String powNoteFirstMessageToSomeone(int secs) {
    final intl.NumberFormat secsNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String secsString = secsNumberFormat.format(secs);

    return '给新联系人的第一条消息 · 正在证明它是真实的 · $secsString 秒';
  }

  @override
  String powNoteFirstMessageSlow(int secs) {
    final intl.NumberFormat secsNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String secsString = secsNumberFormat.format(secs);

    return '给新联系人的第一条消息 · 正在证明它是真实的 · $secsString 秒 · 在较慢的手机上最多需要 1 分钟';
  }

  @override
  String previewStripFetchedOverTor(Object domainOf) {
    return '$domainOf · 经由 tor 获取';
  }

  @override
  String get previewStripDropThePreview => '去掉预览';

  @override
  String get previewStripAddPreview => '添加预览';

  @override
  String get previewStripFetchingOverTor => '正在经由 tor 获取…';

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
  String get torBootSplashNoShortcutsNoTraces => '不走捷径，不留痕迹';

  @override
  String get torBootSplashTheNetworkThatKeeps => '保护你隐私的网络正在预热';

  @override
  String get torBootSplashMadeOnThisPhone => '在这部手机上生成。什么都不会发往任何地方。';

  @override
  String get torBootSplashFirstLaunchTakesA => '首次启动需要一点时间 · 只在启动时';

  @override
  String get videoBubbleNothingHereOpensThat => '这里打不开它 · 改为分享';

  @override
  String videoBubbleMb(Object b) {
    return '$b MB';
  }

  @override
  String videoBubbleKb(Object b) {
    return '$b KB';
  }

  @override
  String get videoBubbleVideo => '视频';

  @override
  String get notificationsChannelName => '消息';

  @override
  String get cameraClose => '关闭';

  @override
  String get cameraFlash => '闪光灯';

  @override
  String get cameraPhoto => '照片';

  @override
  String get cameraVideo => '视频';

  @override
  String get cameraRetake => '重拍';

  @override
  String get seenIntroductions => '介绍';

  @override
  String get donateAddress => '地址';

  @override
  String get donateCopy => '复制';

  @override
  String get donateDone => '完成';

  @override
  String get donateTierSupporter => '支持者';

  @override
  String get donateTierPatron => '赞助人';

  @override
  String get donateTierGuardian => '守护者';

  @override
  String get chatBlock => '屏蔽';

  @override
  String get chatDecline => '拒绝';

  @override
  String get chatAccept => '接受';

  @override
  String get bridgesConnecting => '正在连接';

  @override
  String get bridgesSavedTag => '已保存';

  @override
  String get restoreMade => '制作于';

  @override
  String get restoreContacts => '联系人';

  @override
  String get restoreMessages => '消息';

  @override
  String get restoreAttachments => '附件';

  @override
  String get restoreHiddenChats => '隐藏聊天';

  @override
  String get restoreHiddenFollow => '你的隐藏聊天，最后你会为它们选一个新的隐藏聊天 PIN。';

  @override
  String get restoreChooseHiddenPin => '这份备份包含隐藏聊天。为它们选择一个隐藏聊天 PIN。';

  @override
  String get restoreHiddenLockFirst => '隐藏聊天需要应用锁，所以先给 Kryfo 设一个自己的 PIN。';

  @override
  String get shieldBlock => '屏蔽';

  @override
  String get shieldDelete => '删除';

  @override
  String get shieldIgnore => '忽略';

  @override
  String get profileIdentity => '身份';

  @override
  String get avatarPickerShape => '形状';

  @override
  String get avatarPickerColour => '颜色';

  @override
  String get avatarPickerTurn => '旋转';

  @override
  String get transportStatus => '状态';

  @override
  String get transportBootstrap => '引导';

  @override
  String get transportNetwork => '网络';

  @override
  String get transportConnectivity => '连通性';

  @override
  String get transportRelays => '中继';

  @override
  String get transportTraffic => '流量';

  @override
  String get transportContacts => '联系人';

  @override
  String get transportKnown => '已知';

  @override
  String get transportListening => '监听中';

  @override
  String get transportMemory => '内存';

  @override
  String get settingsConnected => '已连接';

  @override
  String get settingsScreenshots => '截屏';

  @override
  String get settingsBlocked2 => '已禁止';

  @override
  String get settingsAllowed => '已允许';

  @override
  String get settingsOn => '开';

  @override
  String get settingsOff => '关';

  @override
  String get settingsNotifications => '通知';

  @override
  String get settingsPrivacy => '隐私';

  @override
  String get settingsSecurity => '安全';

  @override
  String get settingsBackup => '备份';

  @override
  String get settingsVoice => '语音';

  @override
  String get settingsAbout => '关于';

  @override
  String get wallpaperGradients => '渐变';

  @override
  String get wallpaperPatterns => '图案';

  @override
  String get wallpaperMoods => '心情';

  @override
  String get confirmSheetKeep => '保留';

  @override
  String get confirmSheetSave => '保存';

  @override
  String get confirmSheetCancel => '取消';

  @override
  String bridgesSaved(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 个网桥',
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

    return '$goodString 条已接受，$badString 条无法识别';
  }

  @override
  String get languageTitle => '语言';

  @override
  String get languageMatchPhone => '跟随手机';

  @override
  String languageMatchPhoneValue(Object language) {
    return '跟随手机（$language）';
  }

  @override
  String get languageRedrawLine => 'Kryfo 会用新语言重新显示，并打开你的聊天。';

  @override
  String languageButton(Object language) {
    return '语言：$language';
  }

  @override
  String get androidServiceTitle => 'Kryfo 已开启';

  @override
  String get androidServiceText => '你的加密线路保持连接，好让消息送达';

  @override
  String get androidChannelName => '保持连接';

  @override
  String get androidChannelDescription =>
      '让 Kryfo 保持连接，这样它关闭时加密消息也能送达。关掉这个就会停止投递。';

  @override
  String get videoViewerPlay => '播放';

  @override
  String get videoViewerPause => '暂停';

  @override
  String get videoViewerPlayAgain => '重新播放';

  @override
  String get videoViewerCannotPlay => '这部手机无法在这里播放这个视频。';

  @override
  String get videoViewerOpenElsewhere => '用其他应用打开';

  @override
  String get photoKnowsLookedFor => '查找了';

  @override
  String get photoKnowsNotInIt => '没有';

  @override
  String get languageNameEn => '英语';

  @override
  String get languageNameDe => '德语';

  @override
  String get languageNameFr => '法语';

  @override
  String get languageNameEs => '西班牙语';

  @override
  String get languageNamePt => '葡萄牙语（巴西）';

  @override
  String get languageNameIt => '意大利语';

  @override
  String get languageNameRu => '俄语';

  @override
  String get languageNameUk => '乌克兰语';

  @override
  String get languageNameTr => '土耳其语';

  @override
  String get languageNameZh => '简体中文';

  @override
  String get languageNameZhHant => '繁体中文';

  @override
  String get languageNameVi => '越南语';

  @override
  String get languageNameId => '印度尼西亚语';

  @override
  String get languageNameFa => '波斯语';

  @override
  String get languageNameAr => '阿拉伯语';

  @override
  String get languageLaterLine => '你随时可以在设置里更改。';

  @override
  String get pollAttach => '投票';

  @override
  String get pollNewTitle => '新建投票';

  @override
  String get pollQuestionHint => '向群组提个问题';

  @override
  String get pollOptionsLabel => '选项';

  @override
  String pollOptionHint(Object n) {
    return '选项 $n';
  }

  @override
  String get pollAddOption => '添加选项';

  @override
  String get pollMaxLine => '最多十二个选项。';

  @override
  String get pollMultiple => '多选';

  @override
  String get pollMultipleLine => '大家可以选择不止一项。';

  @override
  String get pollSend => '发送投票';

  @override
  String get pollKind => '投票';

  @override
  String get pollKindMulti => '投票 · 多选';

  @override
  String get pollKindClosed => '最终结果';

  @override
  String pollVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 票',
      zero: '还没有人投票',
    );
    return '$_temp0';
  }

  @override
  String get pollVote => '投票';

  @override
  String get pollTakeBack => '撤回我的投票';

  @override
  String get pollClose => '结束投票';

  @override
  String get pollCloseTitle => '要结束这个投票吗？';

  @override
  String get pollCloseLine => '所有人都会看到最终结果，之后谁也不能再投票。';

  @override
  String get pollCloseYes => '结束';

  @override
  String pollPreview(Object question) {
    return '投票：$question';
  }

  @override
  String get pollWhoVoted => '谁投了票';

  @override
  String get pollNobody => '还没有人';

  @override
  String get pollYou => '你';

  @override
  String pollOptionA11y(Object option, Object share) {
    return '$option，$share';
  }

  @override
  String get pollPickOne => '选一项';

  @override
  String get pollPickSeveral => '选一项或多项';

  @override
  String get searchOpen => '搜索';

  @override
  String get searchHint => '搜索聊天和消息';

  @override
  String get searchFilterAll => '全部';

  @override
  String get searchFilterPhotos => '照片';

  @override
  String get searchFilterVideos => '视频';

  @override
  String get searchFilterFiles => '文件';

  @override
  String get searchFilterLinks => '链接';

  @override
  String get searchChats => '聊天';

  @override
  String get searchMessages => '消息';

  @override
  String get searchIntroTitle => '搜索你的聊天';

  @override
  String get searchIntroLine => '名字、词语、照片、文件和链接。搜索只在这台手机上进行，不会把任何东西发到别处。';

  @override
  String get searchNothing => '没有找到';

  @override
  String get searchNothingLine => '换个词或换个筛选试试。';

  @override
  String searchMatches(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条结果',
    );
    return '$_temp0';
  }

  @override
  String searchMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '还有 $count 条',
    );
    return '$_temp0';
  }

  @override
  String searchFilling(Object share) {
    return '正在加入较早的消息 · $share';
  }

  @override
  String get searchClear => '清除';

  @override
  String get handleShowInSearch => '在搜索中显示我';

  @override
  String get handleShowInSearchLine => '任何人都能找到这个用户名并给你发消息。';

  @override
  String handleShownAs(Object name) {
    return '显示为 $name';
  }

  @override
  String get handleNameInSearch => '搜索中的名字';

  @override
  String get handleNameInSearchLine =>
      '可选。有人搜索时，它会显示在你的用户名旁边。任何人都能找到这个用户名并给你发消息。';

  @override
  String get handleNameHint => '你的名字，也可以留空';

  @override
  String get handleShowMe => '显示我';

  @override
  String get handleSearchOff => '你已不在搜索中';

  @override
  String handleSearchOn(Object handle) {
    return '你以 @$handle 出现在搜索中';
  }

  @override
  String get handleRegistryFailed => '联系不上登记处。请一分钟后再试。';

  @override
  String get searchPeople => '人';

  @override
  String searchPeopleAsk(Object query) {
    return '在公开用户名中查找“$query”';
  }

  @override
  String get searchPeopleLine => '通过 Tor 询问。登记处不留任何记录。';

  @override
  String get searchPeopleNone => '没有匹配的公开用户名';

  @override
  String get searchPeopleOffline => 'Tor 还没准备好';

  @override
  String get searchPeopleBusy => '现在搜索太多了，请稍后再试。';

  @override
  String get searchPeopleUnreachable => '联系不上登记处';

  @override
  String get peopleVerified => '已验证的用户名';

  @override
  String get peopleAdd => '添加';

  @override
  String peopleFingerprint(Object fp) {
    return '密钥指纹 · $fp';
  }

  @override
  String get peopleFingerprintLine => '请核对是否与对方应用里显示的一致。';

  @override
  String get peopleAdding => '正在添加…';

  @override
  String handleNobodyHasClaimed(Object handle) {
    return '没有人认领 $handle';
  }

  @override
  String get handleThatHandleIsTaken => '这个用户名已被占用';

  @override
  String get pinPickDifferent => '请换一个 PIN 码';

  @override
  String get settingsKeptOnWhileLock => '应用锁开启时保持开启。';

  @override
  String get lockFingerAfterPin => '输入一次 PIN 码，即可再次使用指纹。';

  @override
  String get pinsAdvanced => '高级保护';

  @override
  String get pinsAdvancedLine => '用于有人逼你解锁手机的时候。';

  @override
  String get pinsWipeLine => '在锁屏上输入它，会从这部手机上抹掉 Kryfo。';

  @override
  String get pinsDecoyPin => '伪装 PIN';

  @override
  String get pinsDecoyLine => '打开一个空的 Kryfo，就像刚装好一样。';

  @override
  String get pinsSetADecoyPin => '设置伪装 PIN';

  @override
  String get pinsChangeDecoyPin => '更改伪装 PIN';

  @override
  String get pinsRemoveTheDecoyPin => '要移除伪装 PIN 吗？';

  @override
  String get pinsTheDecoyGoes => '它打开的那个空 Kryfo 也会一起消失。';

  @override
  String get pinsTurnOffWithDecoy =>
      '所有 PIN 都会被移除，伪装 PIN 和它的 Kryfo 以及所有隐藏聊天也一样。任何拿着你手机的人都能以你的身份打开 Kryfo。';

  @override
  String get pinsHowThisWorks => '工作原理';

  @override
  String get flowEnterYourPin => '输入你的 PIN 码';

  @override
  String get flowEnterYourPinLine => '就是打开 Kryfo 的那个。';

  @override
  String get flowWipeTitle => '抹掉 PIN';

  @override
  String get flowWipe1 =>
      '在锁屏上代替你的 PIN 码输入，它会从这部手机上抹掉 Kryfo 并关闭应用。在旁人看来，应用只是停止了。';

  @override
  String get flowWipe2 => '所有聊天和你的身份都会一起抹掉，有伪装的话也一样。';

  @override
  String get flowWipeChoose => '选择一个抹掉 PIN';

  @override
  String get flowWipeDone => '抹掉 PIN 已设置';

  @override
  String get flowWipeDoneLine => '锁屏上没有任何迹象显示它的存在。';

  @override
  String get flowDecoyTitle => '伪装 PIN';

  @override
  String get flowDecoy1 => '打开一个空的 Kryfo，就像刚装好一样。';

  @override
  String get flowDecoyFinger => '你的指纹会打开真正的 Kryfo。如果有人可能逼你用指纹，请关闭指纹解锁。';

  @override
  String get flowDecoyDigits => '位数要和你的 PIN 码一样，因为旁边看着的人能数出圆点。';

  @override
  String get flowDecoyShade => '已经在通知栏里的通知已经被看到了。伪装打开期间，不会出现新的通知。';

  @override
  String get flowDecoyChoose => '选择一个伪装 PIN';

  @override
  String get flowDecoyDone => '伪装 PIN 已设置';

  @override
  String get flowDecoyDoneLine =>
      '在锁屏上输入它，就能打开那个空的 Kryfo。要离开，切到别的应用，再输入你的 PIN 码。';

  @override
  String get flowLaw => '在有些国家，拒绝解锁手机或向官方隐藏数据本身就是违法的。出行前了解当地的法律。';

  @override
  String get howWipe =>
      '在锁屏上输入抹掉 PIN，会抹掉所有聊天、你的身份和任何伪装，然后关闭 Kryfo。即使输错多次后键盘被暂停，它也照样有效。';

  @override
  String get howDecoy =>
      '伪装 PIN 会打开第二个空的 Kryfo，它有自己的三个词。发给你真正 Kryfo 的消息照样在底下悄悄到达。要离开伪装，切到别的应用，再输入你的 PIN 码。';

  @override
  String get flowNotSet => '没能设置成功，请再试一次。';

  @override
  String get pinsHiddenChats => '隐藏聊天';

  @override
  String get pinsHiddenLine => '选中的聊天会一直藏起来，直到你输入隐藏聊天 PIN：不在列表里，不在搜索里，也没有通知。';

  @override
  String get pinsSetUp => '设置';

  @override
  String get pinsChangeHiddenPin => '更改隐藏聊天 PIN';

  @override
  String get pinsHideMoreChats => '隐藏更多聊天';

  @override
  String get pinsRemoveHiddenChats => '取消隐藏聊天';

  @override
  String get pinsRemoveHiddenTitle => '要取消隐藏聊天吗？';

  @override
  String get pinsRemoveHiddenLine => '它们会回到你的聊天列表，隐藏聊天 PIN 也不再能打开任何东西。';

  @override
  String get pinsTurnOffHiddenFirst => '隐藏聊天需要应用锁。先取消隐藏聊天，它们会回到你的聊天列表。';

  @override
  String get flowVaultTitle => '隐藏聊天';

  @override
  String get flowVault1 =>
      '选择要隐藏的聊天和群组。你的 PIN 码打开的 Kryfo 里没有它们。隐藏聊天 PIN 会打开全部内容，包括隐藏聊天。';

  @override
  String get flowVault2 => '藏起来的时候，它们从不发通知，也不显示角标。它们的消息照样到达，封存起来，等你输入隐藏聊天 PIN。';

  @override
  String get flowVaultFinger => '你的指纹打开的 Kryfo 里没有隐藏聊天。';

  @override
  String get flowVaultDigits => '你的 PIN 码也最好用六位或更多，因为旁边看着的人能数出圆点。';

  @override
  String get flowVaultReplace => '这会替换这部手机上已有的任何隐藏聊天。';

  @override
  String get flowVaultChoose => '选择一个隐藏聊天 PIN';

  @override
  String get flowVaultChooseLine => '六位或更多。';

  @override
  String get flowEnterHiddenPinLine => '就是打开隐藏聊天的那个。';

  @override
  String get flowVaultForgetTitle => '记住这个 PIN';

  @override
  String get flowVaultForget => '如果你忘了这个 PIN，你的隐藏聊天就永远没了。谁也找不回来，我们也不行。';

  @override
  String get flowVaultForgetOk => '我明白了';

  @override
  String get flowVaultPickTitle => '选择要隐藏的聊天';

  @override
  String get flowVaultPickLine => '它们现在会离开你的聊天列表。输入隐藏聊天 PIN 就能再看到它们。';

  @override
  String flowVaultPickButton(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '隐藏 $countString 个聊天',
      zero: '暂不隐藏',
    );
    return '$_temp0';
  }

  @override
  String get flowVaultPickEmpty => '还没有可以隐藏的聊天。';

  @override
  String get flowVaultBackupTitle => '现在备份吗？';

  @override
  String get flowVaultBackupLine =>
      '现在做的备份也包含你的隐藏聊天，用它自己的密码短语保护。如果你忘了隐藏聊天 PIN，这是找回它们的唯一办法。';

  @override
  String get flowVaultBackupNow => '备份';

  @override
  String get flowVaultNotNow => '暂不';

  @override
  String get flowVaultDone => '隐藏聊天已设置';

  @override
  String get flowVaultDoneLine => '在锁屏上输入隐藏聊天 PIN 就能看到它们。切到别的应用，它们就又藏起来了。';

  @override
  String get flowVaultChanged => '隐藏聊天 PIN 已更改';

  @override
  String get flowVaultChangedLine => '你的隐藏聊天现在用新的打开。旧的什么也打不开了。';

  @override
  String get howVault =>
      '隐藏聊天 PIN 打开的 Kryfo 带着隐藏聊天，你的 PIN 码和指纹打开的则没有。重新设置隐藏聊天，会替换这部手机上已有的。忘了隐藏聊天 PIN，它们就永远没了。';

  @override
  String get chatHide => '隐藏此聊天';

  @override
  String get groupHide => '隐藏此群组';

  @override
  String get chatHidden => '已隐藏';

  @override
  String get chatHiddenToast => '已从聊天列表中隐藏';

  @override
  String get chatShowInList => '在聊天列表中显示';

  @override
  String get stickerOpen => '贴纸';

  @override
  String get stickerRecent => '最近使用';

  @override
  String stickerA11y(String emoji) {
    return '贴纸 $emoji';
  }

  @override
  String get stickerRemoveRecent => '从最近使用中移除';

  @override
  String get stickerCouldNotLoad => '无法加载贴纸';

  @override
  String get stickerLabel => '贴纸';

  @override
  String get stickerNewer => '来自更新版本的 Kryfo';

  @override
  String get devLinkMismatch => '此链接自称是 Marios，但其密钥不匹配。未添加。';

  @override
  String get devName => 'Marios';

  @override
  String get devRowTitle => 'Marios · Kryfo 的开发者';

  @override
  String get devWelcome =>
      '你好，我是 Marios，Kryfo 是我做的。什么都可以跟我说：Bug、想法、问题。每一条我都会看。';

  @override
  String get devPinned => '内置于 Kryfo';

  @override
  String get devAnonymous => '匿名';

  @override
  String get devAboutLine =>
      'Marios 的密钥内置在 Kryfo 里。这个聊天里的每一条消息都会用它核对，所以别人没法冒充他发消息。';

  @override
  String get devKeyLabel => '他的密钥';

  @override
  String get devDeleteLine => '每一条消息都会删除，这个聊天也不会再回来。';

  @override
  String get devDeleteLineAnon => '每一条消息和为这个聊天生成的名字都会删除，这个聊天也不会再回来。';

  @override
  String get settingsWriteToMarios => '给 Marios 发消息';

  @override
  String get settingsWriteToMariosHint => 'Bug、想法、问题';

  @override
  String get seenDevChat => '与 Marios 的聊天';

  @override
  String get seenDevChatCell => '你发消息时';

  @override
  String get seenDevChatLine => '你发消息之前，什么都看不到。之后能看到你发送的内容，以及你的三个词，除非你匿名发送。';

  @override
  String get devNoteWords => 'Marios 会看到你的三个词';

  @override
  String get devWriteAnonymously => '匿名发送';

  @override
  String get devNoteAnon => 'Marios 会看到一个专为这个聊天生成的新名字';

  @override
  String get devUseMyWords => '用我的三个词';

  @override
  String get devWhoSeesWhat => '谁能看到什么';

  @override
  String get devWhoWords =>
      '用你的三个词，Marios 能像任何联系人一样回复你。他能看到你的三个词，但看不到你的脸和支持者徽章。';

  @override
  String get devWhoAnon => '匿名时，Kryfo 会只为这个聊天生成新的名字和密钥。它们只留在这部手机上，绝不会在别处使用。';

  @override
  String get devWhoNothingYet => '在你发出第一条消息之前，什么都不会离开你的手机。';

  @override
  String get devWhoChoiceStays => '你的选择会一直跟着这个聊天。';

  @override
  String get devKeyCheckFailed => '无法核对 Marios 的密钥。什么都没有发送。';

  @override
  String get devLockLine => 'Marios 会读到这些消息。等他回复后，你就能继续写。';

  @override
  String get devNewKey => 'Marios 有了新密钥';

  @override
  String get devStartNewChat => '开始新的聊天';

  @override
  String get devKeyRetired => '这个密钥已停用。这里不能再发送或接收任何内容。';

  @override
  String get devVoiceDisguised => '在这个聊天里，你的语音会变声';

  @override
  String get devChatOptions => '聊天选项';
}

/// The translations for Chinese, using the Han script (`zh_Hant`).
class AppLocalizationsZhHant extends AppLocalizationsZh {
  AppLocalizationsZhHant() : super('zh_Hant');

  @override
  String get atmosphereNone => '無';

  @override
  String get atmosphereEmber => '餘燼';

  @override
  String get atmosphereDusk => '黃昏';

  @override
  String get atmosphereMoss => '苔蘚';

  @override
  String get atmosphereRose => '玫瑰';

  @override
  String get atmosphereDots => '圓點';

  @override
  String get atmosphereGrid => '格線';

  @override
  String get atmosphereWaves => '波浪';

  @override
  String get atmosphereRain => '雨';

  @override
  String get atmosphereLateNight => '深夜';

  @override
  String get atmosphereWarmAfternoon => '溫暖午後';

  @override
  String get atmosphereSnow => '雪';

  @override
  String get atmosphereDesert => '沙漠';

  @override
  String get atmospherePaper => '紙張';

  @override
  String get backupThatPassphraseDoesNot => '這組密碼短語打不開這個檔案';

  @override
  String get backupThatFileIsNot => '這個檔案不是 Kryfo 備份';

  @override
  String get backupThisBackupIsFrom => '這份備份來自較新版的 Kryfo。請先更新應用程式，再試一次';

  @override
  String get backupThisFileIsDamaged => '這個檔案已損毀，無法讀取';

  @override
  String get backupCouldNotMakeThe => '無法建立金鑰';

  @override
  String get contactCardMessageMeOn => '傳訊息給我，請用';

  @override
  String get contactCardScanItOrType =>
      '掃描它，或在 Kryfo 裡輸入這三個詞。\n除此之外，這張卡片對你一無所知。';

  @override
  String contactCardMessageMeOnKryfo(Object haloId) {
    return '在 Kryfo 傳訊息給我 · $haloId';
  }

  @override
  String get contactStatusBlocked => '已封鎖';

  @override
  String get contactStatusKeysVerifiedInPerson => '已當面驗證金鑰';

  @override
  String get contactStatusWaitingInRequests => '在請求中等待';

  @override
  String get contactStatusAddedByHand => '手動新增';

  @override
  String get deliveryModeAlwaysOn => '始終在線';

  @override
  String get deliveryModeCheckIns => '定時查收';

  @override
  String get deliveryModeThroughAHelperApp => '透過輔助應用程式';

  @override
  String get deliveryModeNotYet => '尚未';

  @override
  String get deliveryModeJustNow => '剛剛';

  @override
  String deliveryModeMinAgo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 分鐘前',
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
      other: '$countString 小時前',
    );
    return '$_temp0';
  }

  @override
  String get deliveryModeYesterday => '昨天';

  @override
  String deliveryModeDaysAgo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 天前',
    );
    return '$_temp0';
  }

  @override
  String get deliveryModeConnected => '已連線';

  @override
  String get deliveryModeConnecting => '連線中';

  @override
  String get deliveryModeNotConnected => '未連線';

  @override
  String get deliveryModeCheckingNow => '正在查收';

  @override
  String deliveryModeLastCheckIn(Object agoLine) {
    return '上次查收：$agoLine';
  }

  @override
  String get deliveryModeNoCheckInYet => '尚未查收';

  @override
  String deliveryModeConnectedNow(Object last) {
    return '目前已連線 · $last';
  }

  @override
  String deliveryModeConnecting2(Object last) {
    return '連線中 · $last';
  }

  @override
  String get deliveryModeNoCheckInYet2 => '尚未查收';

  @override
  String deliveryModeLastChecked(Object agoLine) {
    return '上次查收：$agoLine';
  }

  @override
  String get deliveryModeAHelperApp => '輔助應用程式';

  @override
  String deliveryModeWokenByNoWake(Object who) {
    return '由 $who 喚醒 · 尚未喚醒過';
  }

  @override
  String deliveryModeWokenByLastWake(Object who, Object agoLine) {
    return '由 $who 喚醒 · 上次喚醒：$agoLine';
  }

  @override
  String get introBudgetTomorrow => '明天';

  @override
  String introBudgetInDays(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 天後',
    );
    return '$_temp0';
  }

  @override
  String get introBudgetInAnHour => '一小時後';

  @override
  String introBudgetInHours(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 小時後',
    );
    return '$_temp0';
  }

  @override
  String get introBudgetInAFewMinutes => '幾分鐘後';

  @override
  String get lockStateUnlockKryfo => '解鎖 Kryfo';

  @override
  String get appInvalidUri => '無效的 uri';

  @override
  String appBundleError(Object e) {
    return '資料包錯誤：$e';
  }

  @override
  String appAlreadySaved(Object parsed) {
    return '已儲存過：$parsed';
  }

  @override
  String appAddedYouCanMessage(Object parsed) {
    return '已新增 $parsed · 現在可以傳訊息給對方了';
  }

  @override
  String appPeerImportedV1(Object parsed) {
    return '已匯入對等端（v1）：$parsed';
  }

  @override
  String appLongWindow(Object line) {
    return '$line 長時段';
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
      other: '$pString 頁',
    );
    String _temp1 = intl.Intl.pluralLogic(
      e,
      locale: localeName,
      other: '$eString 個事件',
    );
    return '$line（$heldString/$subsString，連線 $c 秒，$_temp0，$_temp1）';
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
      other: '$pString 頁',
    );
    String _temp1 = intl.Intl.pluralLogic(
      e,
      locale: localeName,
      other: '$eString 個事件',
    );
    return '$line（連線 $c 秒，$_temp0，$_temp1）';
  }

  @override
  String appSDropped(Object host, Object secs) {
    return '$host $secs 秒，已中斷';
  }

  @override
  String appS(Object host, Object secs) {
    return '$host $secs 秒';
  }

  @override
  String get appTorWouldNotWake => 'Tor 無法喚醒';

  @override
  String get appCheckStarted => '已開始';

  @override
  String get appTorNotReadyIn => 'Tor 75 秒內未就緒';

  @override
  String get appOk => '正常';

  @override
  String get appOkNoRelayBegan => '正常，沒有中繼開始回應';

  @override
  String get appOkCapped => '正常，已達時限';

  @override
  String appSBy(Object how, int secs, String why) {
    final intl.NumberFormat secsNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String secsString = secsNumberFormat.format(secs);

    String _temp0 = intl.Intl.selectLogic(why, {
      'push': '$how，$secsString 秒，推播觸發',
      'other': '$how，$secsString 秒，排程觸發',
    });
    return '$_temp0';
  }

  @override
  String get appAnAttachmentCouldNot => '有個附件無法儲存到這支手機';

  @override
  String get appGroup2 => '群組';

  @override
  String get appVoiceMessage => '語音訊息';

  @override
  String get appPhoto => '照片';

  @override
  String get appNewRequest => '新請求';

  @override
  String get appSomeoneYouHaveNot => '有個你還沒新增的人傳訊息給你';

  @override
  String get appSettingUpYourKeys => '正在設定你的金鑰';

  @override
  String get appOpeningYourChats => '正在開啟你的聊天';

  @override
  String get appStartingTor => '正在啟動 Tor';

  @override
  String get appTimedMessagesAreNot => '限時訊息沒有被清除。請重新啟動 Kryfo';

  @override
  String get appVoiceMessage2 => '語音訊息';

  @override
  String appYou(Object body) {
    return '你：$body';
  }

  @override
  String get appThisRoomHasAlready => '這個聊天室已經過期';

  @override
  String get appYouAreAlreadyIn => '你已經在這個聊天室裡了';

  @override
  String get appCouldNotMakeA => '無法建立聊天室金鑰';

  @override
  String appJoinedButYourHello(Object linkName) {
    return '已加入 $linkName，但你的招呼尚未送出';
  }

  @override
  String appJoined(Object linkName) {
    return '已加入 $linkName';
  }

  @override
  String appJoinedButTheCreator(Object linkName) {
    return '已加入 $linkName，但暫時還聯絡不到建立者';
  }

  @override
  String get appBooting => '啟動中…';

  @override
  String get appSettingUpYourIdentity => '正在設定你的身分…';

  @override
  String get appAddSomeone => '新增聯絡人';

  @override
  String get appScanTheirCodeOr => '掃描對方的 QR 碼，或貼上對方給你的內容：連結、@使用者名稱或聊天室連結。';

  @override
  String get appScanTheirCode => '掃描對方的 QR 碼';

  @override
  String get appAKryfoLinkA => 'Kryfo 連結、聊天室連結或 @wren';

  @override
  String get appAddThem => '新增對方';

  @override
  String get appEveryWayToAdd => '所有新增聯絡人的方式';

  @override
  String get appShowYourCodeSend => '出示你的 QR 碼、傳送連結、認領使用者名稱';

  @override
  String get appHelloFromTheOther => '來自另一端的問候';

  @override
  String get appIdentityRestored => '已還原身分';

  @override
  String get appIdentityCreated => '已建立身分';

  @override
  String get appStartingTor30s => '正在啟動 tor（約 30 秒）…';

  @override
  String get appScanOrImportA => '請先掃描或匯入對等端';

  @override
  String get appEncryptingSending30s => '正在加密並傳送（約 30 秒）…';

  @override
  String get appTapStartListeningFirst => '請先點「開始監聽」';

  @override
  String get appYourKryfo => '你的 Kryfo';

  @override
  String get appUriCopied => '已複製 uri';

  @override
  String get appCopyUri => '複製 uri';

  @override
  String get appAddAKryfo => '新增 Kryfo';

  @override
  String get appScanQr => '掃描 QR 碼';

  @override
  String get appPairingCode => '配對碼';

  @override
  String get appOrPaste => '- 或貼上 -';

  @override
  String get commonCancel => '取消';

  @override
  String get appImport => '匯入';

  @override
  String get appDev => '開發';

  @override
  String get appYourKryfo2 => '你的 Kryfo：';

  @override
  String get appRestoredFromDisk => '已從儲存空間還原';

  @override
  String get appStartListening => '開始監聽';

  @override
  String get appListening => '監聽中';

  @override
  String get appShowMyQr => '顯示我的 QR 碼';

  @override
  String get appImportPeer => '匯入對等端';

  @override
  String get appPeer => '對等端：';

  @override
  String get appMessageWillBeEncrypted => '訊息（將會加密）';

  @override
  String get appEncryptSend => '加密並傳送';

  @override
  String appStatus(Object status) {
    return '狀態：$status';
  }

  @override
  String get appSpeedPrivacy => '速度與隱私 →';

  @override
  String get appGettingMessages => '接收訊息 →';

  @override
  String get appDisableAppLock => '要停用應用程式鎖嗎？';

  @override
  String get appThePinWillBe => 'PIN 碼將被移除。任何拿到你手機的人，一打開 Kryfo 就能看到裡面的內容。';

  @override
  String get appDisable => '停用';

  @override
  String get appAppLockOn => '應用程式鎖 · 開啟 →';

  @override
  String get appAppLockOff => '應用程式鎖 · 關閉 →';

  @override
  String get appTorIsOff => 'Tor 已關閉';

  @override
  String get appConnectedRoutedThrough3 => '已連線 · 經由 3 個中繼轉送';

  @override
  String get appReadyToSendPublishing => '可以傳送 · 正在發布你的位址';

  @override
  String get appReadyToSendFinishing => '可以傳送 · 正在完成設定';

  @override
  String appConnecting(Object pct) {
    return '連線中 · $pct';
  }

  @override
  String get appTor => 'Tor';

  @override
  String get appTorIsOffTurn => 'Tor 已關閉。開啟它才能私密連線。';

  @override
  String get appTheFirstConnectionTakes =>
      '第一次連線需要一、兩分鐘，讓 tor 建立一條私密路線。之後路線會被快取，下次開啟 Kryfo 就快多了。';

  @override
  String get appRelayAndFastModes =>
      '中繼和快速模式會略過 tor，速度更快。它們在設定的「速度與隱私」裡，每種模式都會說明代價。';

  @override
  String get appViaRelay => '經由中繼';

  @override
  String get appOffline => '離線';

  @override
  String get appFast => '快速';

  @override
  String get appTorOff => 'Tor 關閉';

  @override
  String get appTorReady => 'Tor 就緒';

  @override
  String get appConnecting2 => '連線中';

  @override
  String mediaProgressSendingKeepTheApp(Object v) {
    return '傳送中 · $v · 請保持應用程式開啟';
  }

  @override
  String mediaProgressPausedOfWaitingFor(Object count, Object count2) {
    return '已暫停 · $count/$count2 · 等待其餘部分';
  }

  @override
  String mediaProgressReceivingMedia(Object v) {
    return '正在接收媒體 · $v';
  }

  @override
  String get mediaProgressCancelSending => '取消傳送';

  @override
  String get metaReaderEndsBeforeItShould => '提前結束';

  @override
  String get metaReaderCouldNotBeRead => '無法讀取';

  @override
  String get metaReaderExifThatCannotBe => '無法讀取的 EXIF';

  @override
  String get metaReaderSamsungTrailer => '三星尾端資料';

  @override
  String metaReaderChunk(Object type) {
    return '區塊 $type';
  }

  @override
  String get metaReaderExifFlagSet => '已設 EXIF 旗標';

  @override
  String get metaReaderXmpFlagSet => '已設 XMP 旗標';

  @override
  String metaReaderAppBlock(Object id) {
    return '應用程式區塊 $id';
  }

  @override
  String get metaReaderUuidBox => 'uuid 容器';

  @override
  String metaReaderBox(Object printable) {
    return '$printable 容器';
  }

  @override
  String get metaReaderAttachedData => '附加資料';

  @override
  String metaReaderItem(Object printable) {
    return '$printable 項目';
  }

  @override
  String get miuiAutostartAlreadyAllowedToRun => '已允許在背景執行';

  @override
  String get miuiAutostartLetKryfoRunIn => '讓 Kryfo 在背景執行';

  @override
  String get miuiAutostartYourPhonePausesApps =>
      '你的手機會暫停應用程式來省電。如果不設為例外，Kryfo 關閉時就無法接收訊息。';

  @override
  String get commonAllow => '允許';

  @override
  String get commonSkip => '略過';

  @override
  String get miuiAutostartXiaomiTurnsOffBackground =>
      '小米預設會關閉背景應用程式。沒有開啟自動啟動，Kryfo 在應用程式關閉時就無法傳遞訊息。請在下一個畫面的清單中找到 Kryfo，然後打開開關。';

  @override
  String get miuiAutostartOpenSettings => '開啟設定';

  @override
  String get miuiAutostartCouldnTOpenIt => '無法開啟。請在手機設定中尋找「自動啟動」';

  @override
  String get notificationsNewEncryptedMessagesFrom => '來自聯絡人的加密新訊息';

  @override
  String get notificationsNewMessage => '新訊息';

  @override
  String get notificationsNewEncryptedMessagesFromYourContacts => '來自聯絡人的加密新訊息';

  @override
  String get notificationsNewMessage2 => '新訊息';

  @override
  String get notificationsEncrypted => '已加密';

  @override
  String get rooms24h => '24 小時';

  @override
  String roomsD(Object inDays) {
    return '$inDays 天';
  }

  @override
  String roomsH(Object inHours) {
    return '$inHours 小時';
  }

  @override
  String get rooms24Hours => '24 小時';

  @override
  String roomsDays(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 天',
    );
    return '$_temp0';
  }

  @override
  String get roomsAnHour => '1 小時';

  @override
  String get roomsAboutAnHour => '約 1 小時';

  @override
  String roomsHours(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 小時',
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
      other: '約 $countString 小時',
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
      other: '$countString 分鐘',
    );
    return '$_temp0';
  }

  @override
  String get roomsAMinute => '1 分鐘';

  @override
  String get roomsExpired => '已過期';

  @override
  String roomsDH(Object inDays, Object h) {
    return '$inDays 天 $h 小時';
  }

  @override
  String roomsHM(Object inHours, Object m) {
    return '$inHours 小時 $m 分';
  }

  @override
  String roomsM(Object inMinutes) {
    return '$inMinutes 分鐘';
  }

  @override
  String get scamShieldLooksLikeAScam => '看起來像詐騙';

  @override
  String scamShieldThisNameMatches(Object shown) {
    return '這個名字和 $shown 相同';
  }

  @override
  String scamShieldNameMatchesYourContact(Object shown) {
    return '名字和你的聯絡人 $shown 相同';
  }

  @override
  String scamShieldSameFaceAsYour(Object shown) {
    return '臉和你的聯絡人 $shown 相同';
  }

  @override
  String get scamShieldContainsACryptoAddress => '含有加密貨幣地址';

  @override
  String get scamShieldMentionsMoneyAndUrgency => '同時提到錢和急迫';

  @override
  String get scamShieldAsksYouToMove => '要你改用別的應用程式';

  @override
  String get scamShieldLinksToALookalike => '附上仿冒知名網站的連結';

  @override
  String get scamShieldALongOpenerFrom => '沒有往來紀錄的人傳來長篇開場白';

  @override
  String get scamShieldAsksForACode => '要你提供代碼、助記詞或復原檔案';

  @override
  String scamShieldAlso(Object shown) {
    return '另外：名字和你的聯絡人 $shown 相同';
  }

  @override
  String get commonBack => '返回';

  @override
  String get archivedArchived => '已封存';

  @override
  String get archivedCount0 => '沒有';

  @override
  String get archivedCount1 => '一';

  @override
  String get archivedCount2 => '兩';

  @override
  String get archivedCount3 => '三';

  @override
  String get archivedCount4 => '四';

  @override
  String get archivedCount5 => '五';

  @override
  String get archivedCount6 => '六';

  @override
  String get archivedCount7 => '七';

  @override
  String get archivedCount8 => '八';

  @override
  String get archivedCount9 => '九';

  @override
  String get archivedCount10 => '十';

  @override
  String get archivedChatRestingHereIt => '這個聊天在這裡休息。對方傳訊息之前它都會保持安靜，之後會回到最上方。';

  @override
  String get archivedChatsRestingHere => '這些聊天在這裡休息。有人傳訊息之前都會保持安靜，之後會回到最上方。';

  @override
  String get archivedNothingArchived => '沒有封存的聊天';

  @override
  String get archivedArchivedChatsAreStill => '封存的聊天仍然是端對端加密';

  @override
  String get archivedUnarchive => '取消封存';

  @override
  String get avatarPickerThePeopleYouMessage => '跟你傳訊息的人也會看到這個';

  @override
  String get avatarPickerBackToYourInitial => '改回名字首字';

  @override
  String get avatarPickerThatOneIsYours => '這個是你的';

  @override
  String get avatarPickerPickAFace => '選一張臉';

  @override
  String get commonSave => '儲存';

  @override
  String get backupPassphraseMustBeAt => '密碼短語至少要 6 個字元';

  @override
  String get backupPassphrasesDonTMatch => '密碼短語不一致';

  @override
  String get backupBackupSavedKeepThe => '備份已儲存 · 請妥善保管密碼短語';

  @override
  String get backupKryfoBackup => 'Kryfo 備份';

  @override
  String get backupYourEncryptedKryfoBackup =>
      '你的 Kryfo 加密備份。這個檔案和密碼短語都要妥善保管，兩個都有才能還原。';

  @override
  String get backupBackUpKryfo => '備份 Kryfo';

  @override
  String get backupBackUp => '備份';

  @override
  String get backupACopyToKeep => '留一份副本。這支手機照常使用。';

  @override
  String get backupMoveToAnotherDevice => '移到另一台裝置';

  @override
  String get backupTheFileTakesThis =>
      '這個檔案會帶走這個身分。檔案一建立，這支手機就會停止：這裡不會再收到任何新內容，從這裡傳出的東西也不會送達任何人。';

  @override
  String get backupOneEncryptedFileYour =>
      '一個加密檔案：你的身分、聯絡人、每則訊息，以及每張照片、每段語音和每個檔案。在另一台裝置上用密碼短語匯入。在那之前，你仍然可以改變主意，繼續留在這支手機上。';

  @override
  String get backupOneEncryptedFileYourIdentityYour =>
      '一個加密檔案：你的身分、聯絡人、每則訊息，以及此刻這支手機上的每張照片、每段語音和每個檔案。今天之後說的話都不在裡面，所以重要的時候請再做一份。還原時需要檔案和密碼短語，兩者缺一不可。';

  @override
  String get backupPassphrase => '密碼短語';

  @override
  String get backupConfirmPassphrase => '確認密碼短語';

  @override
  String backupWriting(Object progress) {
    return '寫入中… $progress';
  }

  @override
  String get backupCreating => '建立中…';

  @override
  String get backupMakeTheFileAnd => '建立檔案並搬移';

  @override
  String get backupCreateBackup => '建立備份';

  @override
  String get backupHiddenNotIn => '隱藏聊天不在其中。';

  @override
  String get backupHiddenIncluded => '你的隱藏聊天也在其中。';

  @override
  String get backupMoveHiddenStay => '隱藏聊天留在這支手機上，並隨它一起清除。';

  @override
  String get backupHiddenGone => 'Kryfo 鎖定時，你的隱藏聊天已關閉。用隱藏聊天 PIN 開啟它們，再從那裡備份。';

  @override
  String get blockedBlocked => '已封鎖';

  @override
  String get blockedNoOneIsBlocked => '沒有封鎖任何人';

  @override
  String get commonUnblock => '解除封鎖';

  @override
  String get bridgesThatWasNotIt => '答案不對。換一題給你。';

  @override
  String get bridgesGotBridgesSaveTo => '已取得橋接 · 儲存後即可使用';

  @override
  String get bridgesConnected => '已連線';

  @override
  String get bridgesNotThroughYetTor => '還沒連通。Tor 會繼續嘗試';

  @override
  String get bridgesBridges => '橋接';

  @override
  String get bridgesTorIsBlockedWhere => '你所在的地方封鎖了 Tor？';

  @override
  String get bridgesBridgesDisguiseYourConnection =>
      '橋接會掩飾你的連線，讓它連得出去。選一種連入方式並儲存，tor 就會透過它重新連線。';

  @override
  String get bridgesBridgesOnlyChangeHow =>
      '橋接只會改變 tor 的連線方式，而你現在沒有使用 Onion 模式。這裡的設定會保存下來，只是在你切換回去之前不會有作用。';

  @override
  String get bridgesFromTheTorProject => '來自 tor 專案';

  @override
  String get bridgesNoise => '雜訊';

  @override
  String get bridgesGood => '良好';

  @override
  String get bridgesMakesTorTrafficLook =>
      '讓 tor 流量看起來不像任何特定的東西。對大多數被封鎖的網路來說，這是最好的預設選擇。先回答一個驗證碼，就會拿到幾行設定。';

  @override
  String get bridgesPrivateBridge => '私人橋接';

  @override
  String get bridgesALineFromA => '朋友給的一行設定';

  @override
  String get bridgesWhateverTheLineSays => '依設定內容而定';

  @override
  String get bridgesDepends => '看情況';

  @override
  String get bridgesGotABridgeLine =>
      '從你信任的人或 bridges.torproject.org 拿到了橋接設定？貼在這裡。目前只支援 obfs4，Kryfo 還不支援其他類型。';

  @override
  String get bridgesPasteFromClipboard => '從剪貼簿貼上';

  @override
  String get bridgesUseBridges => '使用橋接';

  @override
  String get bridgesNoLinesYet => '還沒有任何設定';

  @override
  String bridges1LineSaved(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已儲存 $countString 行',
    );
    return '$_temp0';
  }

  @override
  String get bridgesRestartingTor => '正在重新啟動 tor…';

  @override
  String bridgesFindingABridgeS(Object elapsed) {
    return '正在尋找橋接… $elapsed 秒';
  }

  @override
  String bridgesStillTryingS(Object elapsed) {
    return '仍在嘗試… $elapsed 秒';
  }

  @override
  String get bridgesApplying => '套用中…';

  @override
  String get bridgesSaveAndReconnect => '儲存並重新連線';

  @override
  String get bridgesWhatABridgeIs => '什麼是橋接';

  @override
  String get bridgesATorEntryPoint =>
      '一個沒有人公開過的 tor 入口，透過一層包裝連上，讓連線看起來不像 tor。其餘路線還是一般的 3 跳。';

  @override
  String get bridgesLooksLike => '看起來像';

  @override
  String get bridgesSpeed => '速度';

  @override
  String get bridgesGetBridges => '取得橋接';

  @override
  String get bridgesAskTheTorProject => '直接向 tor 專案索取。你需要解一道謎題，這樣機器人才無法把橋接拿光。';

  @override
  String get bridgesTypeWhatYouSee => '輸入你看到的內容。小寫也可以。';

  @override
  String get bridgesThisOneRequestDoes =>
      '只有這一個請求不經過 tor，也不可能經過，因為無法運作的正是 tor。管理你所在網路的人會看到你在聯絡 tor 專案。如果光是這樣在你那裡就會出問題，請從別的地方取得橋接，再貼到下方。';

  @override
  String get bridgesCouldNotDrawThe => '無法顯示謎題';

  @override
  String get bridgesAnswer => '答案';

  @override
  String get bridgesAsking => '索取中…';

  @override
  String get bridgesRequestBridges => '索取橋接';

  @override
  String get bridgesDifferentPuzzle => '換一道謎題';

  @override
  String get cameraNoCameraOnThis => '這支手機沒有相機';

  @override
  String get cameraCameraNotAvailable => '無法使用相機';

  @override
  String get cameraCameraPermissionIsOff => '相機權限已關閉 · 點一下再試一次';

  @override
  String get cameraCouldNotStripThat => '無法清除那張照片的中繼資料，已捨棄';

  @override
  String get cameraNoPhotoCameOut => '沒有拍出照片';

  @override
  String get cameraCouldNotStartRecording => '無法開始錄影';

  @override
  String get cameraTheRecordingWasLost => '錄影遺失了';

  @override
  String get cameraACopyIsIn => '你的相簿裡有一份副本';

  @override
  String get cameraCouldNotSaveA => '無法在這支手機上儲存副本';

  @override
  String get cameraTooLongForA => '太長了，無法用訊息傳送 · 上限 8 mb';

  @override
  String get cameraNeverSavedToYour => '不會存到你的相簿';

  @override
  String get cameraNoExifNeverSaved => '沒有 EXIF，不會存到你的相簿';

  @override
  String get cameraRec => '錄影';

  @override
  String get cameraSwitchCamera => '切換相機';

  @override
  String cameraClipSMb(Object secs, Object mb) {
    return '片段 · $secs 秒 · $mb mb';
  }

  @override
  String get cameraStopRecording => '停止錄影';

  @override
  String get cameraStartRecording => '開始錄影';

  @override
  String get cameraTakeAPhoto => '拍照';

  @override
  String get cameraKeepACopy => '保留副本';

  @override
  String get cameraUseThis => '使用這個';

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
  String get chatFile => '檔案';

  @override
  String get chatYouAreOfflineThis => '你目前離線 · 重新連線後會自動傳送';

  @override
  String get chatStillConnectingToTor => '仍在連線到 Tor · 之後會自動送出';

  @override
  String chatS(Object seconds) {
    return '$seconds 秒';
  }

  @override
  String chatM(Object seconds) {
    return '$seconds 分鐘';
  }

  @override
  String chatH(Object seconds) {
    return '$seconds 小時';
  }

  @override
  String chatD(Object seconds) {
    return '$seconds 天';
  }

  @override
  String get chat0s => '0 秒';

  @override
  String chatHM(Object h, Object m) {
    return '$h 小時 $m 分';
  }

  @override
  String chatMS(Object m, Object s) {
    return '$m 分 $s 秒';
  }

  @override
  String chatS2(Object s) {
    return '$s 秒';
  }

  @override
  String get chatNewMessages => '新訊息';

  @override
  String get chatUnsave => '取消收藏';

  @override
  String get chatForward => '轉傳';

  @override
  String get commonShare => '分享';

  @override
  String get commonCopied => '已複製';

  @override
  String get commonCopy => '複製';

  @override
  String get chatUnpin => '取消置頂';

  @override
  String get chatPin => '置頂';

  @override
  String get chatStopSending => '停止傳送';

  @override
  String get chatUnsend => '收回';

  @override
  String get commonEdit => '編輯';

  @override
  String get chatYou => '你';

  @override
  String get chatUnsendMessage => '收回訊息';

  @override
  String get chatItDisappearsWithNo => '訊息會消失，不留任何痕跡。這個動作無法復原。';

  @override
  String chatThisChatHasPins(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '這個聊天已經有 $countString 則置頂訊息',
    );
    return '$_temp0';
  }

  @override
  String get chatUnpinThisMessage => '要取消置頂這則訊息嗎？';

  @override
  String get chatPinThisMessage => '要置頂這則訊息嗎？';

  @override
  String get chatItLeavesThePinned => '它會從你們雙方的置頂清單中移除。';

  @override
  String get chatItGoesUnderThe => '它會放在聊天頂端的置頂區，你們雙方都看得到。';

  @override
  String get chatPinIt => '置頂';

  @override
  String get chatNotNow => '以後再說';

  @override
  String get chatEditMessage => '編輯訊息';

  @override
  String get chat30Seconds => '30 秒';

  @override
  String get chat1Minute => '1 分鐘';

  @override
  String get chat5Minutes => '5 分鐘';

  @override
  String get chat1Hour => '1 小時';

  @override
  String get chat24Hours => '24 小時';

  @override
  String get chatGhostTimer => '限時訊息';

  @override
  String get chatHowLongBeforeSent => '已傳送的訊息要多久後焚毀？';

  @override
  String get chatCamera => '相機';

  @override
  String get chatNoExifNeverSaved => '沒有 EXIF，不會存到你的相簿';

  @override
  String get chatGallery => '相簿';

  @override
  String get chatVideo => '影片';

  @override
  String get chatGifFromPhone => '手機裡的 GIF';

  @override
  String get chatFile2 => '檔案';

  @override
  String get chatAFewSeconds => '幾秒鐘';

  @override
  String get chatUnderAMinute => '不到一分鐘';

  @override
  String chatRoughlyMin(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '大約 $countString 分鐘',
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
  String get chatSendThis => '要傳送這個檔案嗎？';

  @override
  String chatOverTor(Object humanBytes, Object wireEstimate) {
    return '$humanBytes · 經 tor 需 $wireEstimate';
  }

  @override
  String get chatBigFilesGoOut => '大檔案會切成加密的小片段送出，所以需要一點時間。保持應用程式開啟，就會持續傳送。';

  @override
  String get chatSendIt => '傳送';

  @override
  String get chatCouldNotReadThat => '無法讀取那個檔案';

  @override
  String get chatFileTooBig8 => '檔案太大 · 上限 8 mb';

  @override
  String get chatCouldNotCleanThat => '無法清理那段影片';

  @override
  String get chatCouldNotCleanThatPictureSend => '無法清理那張圖片 · 請改用照片傳送';

  @override
  String get chatGifTooBig8 => 'GIF 太大 · 上限 8 mb';

  @override
  String get chatCouldNotCleanThatGif => '無法清理那個 GIF';

  @override
  String get chatTorIsNotUp => 'Tor 尚未啟動 · 不附預覽直接傳送';

  @override
  String get chatCouldnTReachIt => '連不上 · 不附預覽直接傳送';

  @override
  String get chatNoTitleCameBack => '沒有取得標題 · 不附預覽直接傳送';

  @override
  String get chatCouldnTFetchIt => '無法擷取 · 不附預覽直接傳送';

  @override
  String get chatNoSignalSessionRe => '沒有 Signal 工作階段，請重新配對';

  @override
  String get chatMessageUnavailable => '訊息無法顯示';

  @override
  String get chatYou2 => '你';

  @override
  String get chatThem => '對方';

  @override
  String get chatVoiceMessage => '語音訊息';

  @override
  String get chatQuotedPhoto => '照片';

  @override
  String get chatViewContact => '查看聯絡人';

  @override
  String get chatSharedPhotos => '分享的照片';

  @override
  String chatSharedPhotoCount(int count, Object title) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 張照片',
    );
    return '$_temp0 · $title';
  }

  @override
  String get chatUnmuteNotifications => '取消通知靜音';

  @override
  String get chatMuteNotifications => '將通知靜音';

  @override
  String get chatArchiveChat => '封存聊天';

  @override
  String get chatWallpaper => '桌布';

  @override
  String get chatClearConversation => '清空對話';

  @override
  String get chatNoteOnThisContact => '這位聯絡人的備註';

  @override
  String get chatPinToTop => '置頂';

  @override
  String get chatBlockContact => '封鎖聯絡人';

  @override
  String get chatUnpinned => '已取消置頂';

  @override
  String get chatPinnedToTop => '已置頂';

  @override
  String get chatJustForYouNever => '只有你看得到。不會傳送，也不會離開這支手機。';

  @override
  String get chatAQuietReminder => '給自己的小提醒…';

  @override
  String get chatNoteSaved => '備註已儲存';

  @override
  String get chatClearThisConversation => '要清空這段對話嗎？';

  @override
  String get chatEveryMessageHereIs => '這裡的每則訊息都會從這支手機上抹除。這只會清空你的副本，不會動到對方的裝置。';

  @override
  String get chatClear => '清空';

  @override
  String get chatBlockThisContact => '要封鎖這位聯絡人嗎？';

  @override
  String get chatTheirMessagesStopArriving =>
      '對方的訊息將不再送達，對方也會從你的聊天清單中消失。對方不會收到任何通知。你隨時可以在設定中解除封鎖。';

  @override
  String get commonBlock => '封鎖';

  @override
  String get chatSaved => '已收藏';

  @override
  String get chatRemovedFromSaved => '已從收藏移除';

  @override
  String get chatForwardTo => '轉傳給';

  @override
  String get chatNoContactsToForward => '沒有可轉傳的聯絡人';

  @override
  String get chatToday => '今天';

  @override
  String get chatYesterday => '昨天';

  @override
  String get chatThisMessageCanT => '這則訊息無法顯示';

  @override
  String get chatJumpToTheNewest => '跳到最新';

  @override
  String get chatBuildingAPrivateRoute =>
      '正在建立私密路線 · 第一次連線比較慢，之後就快了。現在傳送的任何內容都會先排隊，之後自動送達。';

  @override
  String get chatLooksSafeNothingSuspicious => '看起來安全 · 對方的第一則訊息沒有可疑之處';

  @override
  String get chatTheNextPhotoYou => '你傳送的下一張照片會以保護模式開啟 · 對方無法截圖';

  @override
  String get chatPhotoProtectionOff => '照片保護已關閉';

  @override
  String get chatAcceptToReplyThey => '接受後才能回覆。在你接受之前，對方只能再傳一則訊息。';

  @override
  String chatIntroducedYouAcceptTo(Object introducer) {
    return '$introducer 介紹你們認識。接受後就能回覆。';
  }

  @override
  String chatIntroducedYouSayHello(Object vouchNames) {
    return '$vouchNames 介紹你們認識。打個招呼吧，對方也收到了你的名片。';
  }

  @override
  String get chatIntroduceTo => '介紹給…';

  @override
  String get chatAcceptThemFirst => '請先接受對方';

  @override
  String get chatMessageRequest => '訊息請求';

  @override
  String get chatTheyNeedToAccept => '對方需要先接受，你們才能繼續聊天。';

  @override
  String get chatWaitingForThemTo => '正在等對方接受你的請求';

  @override
  String get chatYouBlockedThisContact => '你已封鎖這位聯絡人';

  @override
  String get chatSupporter => '支持者';

  @override
  String get chatEncryptedViaRelay => '已加密 · 經由中繼';

  @override
  String get chatEncryptedDirect => '已加密 · 直連';

  @override
  String get chatEncryptedOverTor => '已加密 · 經由 tor';

  @override
  String get chatSearchThisChat => '搜尋這個聊天';

  @override
  String get chatContactOptions => '聯絡人選項';

  @override
  String get commonClose => '關閉';

  @override
  String get chatFindInConversation => '在對話中尋找';

  @override
  String get chatNoMatches => '沒有符合的結果';

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
      other: '第 *$posString* 筆，共 $countString 筆',
      one: '第 *$posString* 筆，共 $countString 筆',
    );
    return '$_temp0';
  }

  @override
  String get chatPreviousMatch => '上一筆';

  @override
  String get chatNextMatch => '下一筆';

  @override
  String get chatPhotoUnavailable => '照片無法顯示';

  @override
  String get chatDelivered => '已送達';

  @override
  String get chatEdited => '已編輯';

  @override
  String get chatWaitingForThemToComeOnline => '正在等對方上線，或把你加回來';

  @override
  String get chatFailedTapToRetry => '失敗 · 點一下重試';

  @override
  String get chatReplyingTo => '回覆對方';

  @override
  String get chatReplyingToYourself => '回覆自己';

  @override
  String get chatReply => '回覆';

  @override
  String get chatSayHi => '打聲招呼吧。';

  @override
  String get chatJustTheTwoOf => '只有你們兩個，端對端加密。';

  @override
  String get chatMicPermissionNeeded => '需要麥克風權限';

  @override
  String get chatTheMicWouldNot => '麥克風無法啟動。請再試一次';

  @override
  String get chatReleaseToCancel => '放開即可取消';

  @override
  String get chatVoiceHiddenSlideTo => '聲音已隱藏 · 滑動以取消';

  @override
  String get chatSlideToCancel => '滑動以取消';

  @override
  String get chatGhostMode => '限時訊息';

  @override
  String chatMessagesBurnAfter(Object humanBurn) {
    return '$humanBurn後焚毀';
  }

  @override
  String get chatTimedMessages => '限時訊息';

  @override
  String get chatOpenTheCamera => '開啟相機';

  @override
  String get chatAttachAPhoto => '附加照片';

  @override
  String get chatMessage => '訊息';

  @override
  String get chatDisguiseVoice => '變聲';

  @override
  String get commonSend => '傳送';

  @override
  String get chatNoPhotosInThis => '這個聊天裡還沒有照片';

  @override
  String get chatSendPhoto => '傳送照片';

  @override
  String get chatAddACaption => '加上說明…';

  @override
  String get chatSecurityCodeChanged => '安全碼已變更';

  @override
  String chatMayHaveReinstalledOr(Object peerName) {
    return '$peerName 可能重新安裝了應用程式，也可能有人在冒充對方。請比對安全碼來確認。';
  }

  @override
  String get chatOk => '好';

  @override
  String get chatVerify => '驗證';

  @override
  String get cleanKryfoCanTClean => 'Kryfo 目前還無法清理這類檔案。';

  @override
  String get cleanThisIsAMotion => '這是一張動態照片。';

  @override
  String get cleanThisPictureIsToo => '這張圖片太大，無法在這裡清理。';

  @override
  String get cleanThisFileIsDamaged => '這個檔案已損毀或不完整。';

  @override
  String get cleanKryfoCouldNotMake => 'Kryfo 無法把這個檔案清理乾淨。';

  @override
  String get cleanNotEnoughRoomOn => '手機空間不足。';

  @override
  String get cleanKryfoCouldNotOpen => 'Kryfo 無法開啟那個檔案。';

  @override
  String get cleanItCleansJpegPng =>
      '它可以清理 JPEG、PNG、WebP、HEIC、AVIF、GIF、MP4 和 MOV。沒有做任何變更。';

  @override
  String get cleanItHoldsAShort =>
      '它在圖片旁附帶一段短影片，而 Kryfo 目前還無法清理那個部分。請在相機中關閉動態照片，或改傳它的截圖。';

  @override
  String get cleanPicturesOver64Mb => '超過 64 MB 的圖片不會在手機上清理。沒有做任何變更。';

  @override
  String get cleanKryfoCouldNotRead => 'Kryfo 無法完整讀到結尾，所以不會說它已清理乾淨。沒有產生任何副本。';

  @override
  String get cleanSomethingInsideIsOf => '裡面有它不知道如何移除的內容，所以沒有產生副本。';

  @override
  String get cleanFreeSomeSpaceAnd => '請釋出一些空間後再試一次。沒有做任何變更。';

  @override
  String get cleanTheAppThatShared => '分享它的應用程式可能已經把它收回。請再分享一次。';

  @override
  String get cleanNoAppOnThis => '這支手機上沒有任何應用程式接收這個檔案。';

  @override
  String get cleanCouldNotSaveIt => '無法儲存。請確認手機還有空間。';

  @override
  String get cleanTheOriginalIsGone => '原始檔案已刪除。乾淨的副本會保留。';

  @override
  String get cleanAndroidWouldNotDelete => 'Android 不肯刪除它。請手動從相簿中移除。';

  @override
  String get cleanCleanCopy => '乾淨副本';

  @override
  String get cleanShareCleanCopy => '分享乾淨副本';

  @override
  String get cleanSaveToGallery => '儲存到相簿';

  @override
  String get commonStop => '停止';

  @override
  String get cleanReadingTheFile => '正在讀取檔案';

  @override
  String get cleanCleaning => '清理中';

  @override
  String cleanOf(Object prettySize, Object prettySize2) {
    return '$prettySize/$prettySize2';
  }

  @override
  String get cleanEverythingStaysOnThis => '一切都留在這支手機上。';

  @override
  String get cleanAlreadyClean => '已經是乾淨的。';

  @override
  String get cleanClean => '乾淨了。';

  @override
  String get cleanThereWasNothingTo => '本來就沒有東西可找。';

  @override
  String get cleanNothingLeftToFind => '已經找不到任何東西。';

  @override
  String get cleanSameVideoSameQuality => '同樣的影片，同樣的畫質';

  @override
  String get cleanSamePictureSameQuality => '同樣的圖片，同樣的畫質';

  @override
  String cleanRemoved(Object label) {
    return '$label，已移除';
  }

  @override
  String get cleanRemoved2 => '已移除';

  @override
  String get cleanWithTheLocationInside => '裡面還帶著位置。任何拿到它的人，都能知道你在哪條街。';

  @override
  String get cleanWithEverythingItKnew => '它知道的一切都還在裡面。';

  @override
  String get cleanOriginal => '原始';

  @override
  String get cleanClean2 => '乾淨';

  @override
  String get cleanSavedToYourGallery => '已儲存到你的相簿。';

  @override
  String cleanTheOriginalIsStill(Object what) {
    return '原始檔案也還在，$what';
  }

  @override
  String cleanTheOriginalIsStillWhereIt(Object what) {
    return '原始檔案仍在原處，${what}Kryfo 無法從這裡移除它，請到它原本所在的應用程式中刪除。';
  }

  @override
  String get cleanDeleteTheOriginal => '刪除原始檔案';

  @override
  String get cleanKeepBoth => '兩個都保留';

  @override
  String get commonDone => '完成';

  @override
  String get cleanAndroidWillAskYou => 'ANDROID 會要求你確認';

  @override
  String get contactYourNameForThem => '你給對方的暱稱';

  @override
  String get contactStaysOnThisPhone => '只存在這支手機上。對方永遠看不到。';

  @override
  String get contactClear => '清空';

  @override
  String get contactMessage => '傳訊息';

  @override
  String get contactKeysVerified => '金鑰已驗證';

  @override
  String get contactVerifyKeys => '驗證金鑰';

  @override
  String get contactVouches => '擔保';

  @override
  String get contactUnmute => '取消靜音';

  @override
  String get contactMute => '靜音';

  @override
  String get contactUnpin => '取消置頂';

  @override
  String get contactPinToTop => '置頂';

  @override
  String get contactArchive => '封存';

  @override
  String get contactOutOfTheList => '在對方再次傳訊息之前，不會出現在清單中';

  @override
  String contactBlock(Object name) {
    return '要封鎖 $name 嗎？';
  }

  @override
  String get contactTheirMessagesStopArriving => '對方的訊息將不再送達。對方不會收到通知。';

  @override
  String get contactDeleteChat => '刪除聊天';

  @override
  String get contactMessagesAndContactGone => '訊息和聯絡人都會從這支手機上消失';

  @override
  String get contactDeleteThisChat => '要刪除這個聊天嗎？';

  @override
  String get contactEveryMessageAndThe => '每則訊息和這位聯絡人都會從這支手機上消失。不會傳送任何東西給對方。';

  @override
  String get commonDelete => '刪除';

  @override
  String get contactDeleted => '已刪除';

  @override
  String get contactToday => '今天';

  @override
  String contactD(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 天',
    );
    return '$_temp0';
  }

  @override
  String contactMo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個月',
    );
    return '$_temp0';
  }

  @override
  String contactY(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 年',
    );
    return '$_temp0';
  }

  @override
  String get contactVerified => '已驗證';

  @override
  String get contactChatting => '往來';

  @override
  String get contactNothingSharedYet => '還沒有分享任何東西';

  @override
  String contactSharedMedia(Object count) {
    return '分享的媒體 · $count';
  }

  @override
  String get donateBitcoin => 'Bitcoin';

  @override
  String get donateText => '₿';

  @override
  String get donateBadgeUnlocks => '可解鎖徽章';

  @override
  String get donateMonero => 'Monero';

  @override
  String get donateManualNoBadge => '手動 · 無徽章';

  @override
  String get donateSolana => 'Solana';

  @override
  String get donateEthereum => 'Ethereum';

  @override
  String get donateText2 => 'Ξ';

  @override
  String donateYourEarlierBitcoinPayment(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter': '已偵測到你先前的 bitcoin 付款 · 支持者徽章已解鎖',
      'patron': '已偵測到你先前的 bitcoin 付款 · 贊助人徽章已解鎖',
      'guardian': '已偵測到你先前的 bitcoin 付款 · 守護者徽章已解鎖',
      'other': '已偵測到你先前的 bitcoin 付款 · 支持者徽章已解鎖',
    });
    return '$_temp0';
  }

  @override
  String get donateSupport => '支持';

  @override
  String get donateKeepKryfo => '讓 Kryfo 保持*獨立*';

  @override
  String get donateNoAdsNoInvestors => '沒有廣告，沒有投資人，也沒有要賣的東西。全靠支持者的捐助運作。';

  @override
  String get donateBackItAnonymouslyBadge => '匿名支持。徽章自由選擇。\n*隱私永遠不設付費門檻。*';

  @override
  String donateAddressCheckItAgainst(Object coinName) {
    return '$coinName 地址 · 請和你的錢包核對';
  }

  @override
  String get donateAddressCopiedClearsIn => '已複製地址 · 60 秒後清空';

  @override
  String get donateCopyAddress => '複製地址';

  @override
  String get donateBitcoinIsVerifiedBy =>
      'Bitcoin 付款由我們自己的節點驗證，所以款項一到帳，你的徽章就會自動解鎖。';

  @override
  String get donateWeCanTVerify =>
      '要驗證這條鏈，就得向外部服務查詢關於你的資訊，所以我們不這麼做。想捐還是可以捐。這不會解鎖徽章。';

  @override
  String get donateBitcoinBadgesNeedOnion => 'Bitcoin 徽章需要 Onion 模式';

  @override
  String get donateSwitchToOnion => '切換到 Onion';

  @override
  String get donatePayWithBitcoin => '用 bitcoin 付款  →';

  @override
  String get donateBadgesStartAt20 => '徽章從 \$20 起';

  @override
  String get donateReachingThePaymentService => '正在經由 tor 連線到付款服務…';

  @override
  String get donateThisCanTakeUp => '最多可能需要一分鐘';

  @override
  String donateSThisCanTake(Object waited) {
    return '$waited 秒 · 最多可能需要一分鐘';
  }

  @override
  String get donateUseTheAddressInstead => '改用地址';

  @override
  String get donateThePaymentServiceIs =>
      '付款服務是 onion 服務，只有 Onion 模式才能連上。沒有傳送任何東西。';

  @override
  String get donateTorWasSlowTo =>
      'Tor 連到付款服務太慢了。你可以捐款到下方的地址，只是徽章不會自動解鎖。想要徽章的話，請稍後再試。';

  @override
  String get donateThePaymentServiceIsHavingTrouble =>
      '付款服務目前出了點問題。你還是可以捐款到下方的地址，只是徽章不會自動解鎖。想要徽章的話，請稍後再試。';

  @override
  String get commonTryAgain => '再試一次';

  @override
  String donateBtc(Object btc) {
    return '$btc BTC';
  }

  @override
  String donateSendExactlyThisAmount(Object fmtLeft) {
    return '請傳送剛好這個金額 · $fmtLeft 後到期';
  }

  @override
  String get donateOpenWallet => '開啟錢包';

  @override
  String get donateThisScreenUpdatesItself =>
      '一偵測到你的付款，這個畫面就會自動更新。\n請保持開啟。不會儲存任何東西，也沒有任何東西能識別你。';

  @override
  String get donateWatchingTheChainFor => '正在區塊鏈上等候你的付款';

  @override
  String get donateThisInvoiceExpired => '這張付款單已過期';

  @override
  String get donateInvoicesTimeOutIf =>
      '付款單會逾時。如果你已經付款，請保持這個畫面開啟：我們會在一段時間內每分鐘再向服務查詢一次，下次你開啟「支持」時也會再查。你隨時可以開一張新的。';

  @override
  String get donateNewInvoice => '新付款單';

  @override
  String get donateIPaidCheckAgain => '我付了，再檢查一次';

  @override
  String get donatePaymentConfirmed => '付款已確認';

  @override
  String get donateThankYouForKeeping => '謝謝你讓 Kryfo 保持獨立。';

  @override
  String donateVerifiedOnChainYou(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter': '已在鏈上驗證：你現在是支持者了。沒有人能把這拿走。',
      'patron': '已在鏈上驗證：你現在是贊助人了。沒有人能把這拿走。',
      'guardian': '已在鏈上驗證：你現在是守護者了。沒有人能把這拿走。',
      'other': '已在鏈上驗證：你現在是支持者了。沒有人能把這拿走。',
    });
    return '$_temp0';
  }

  @override
  String get donateWearMyBadge => '佩戴我的徽章';

  @override
  String get donateJustGladToHelp => '能幫上忙就好';

  @override
  String get gettingMessagesGettingMessages => '接收訊息';

  @override
  String get gettingMessagesHowNewMessagesReach => '新訊息如何送到這支手機。你隨時都可以更改。';

  @override
  String get gettingMessagesAlwaysOn => '始終在線';

  @override
  String get gettingMessagesMostPrivate => '最私密';

  @override
  String get gettingMessagesMessagesArriveInstantlyNothing =>
      '訊息即時送達。任何東西都不會離開 Tor。最耗電。';

  @override
  String get gettingMessagesCheckIns => '定時查收';

  @override
  String get gettingMessagesLightest => '最省電';

  @override
  String get gettingMessagesKryfoLooksForMessages =>
      'Kryfo 每 15 分鐘查收一次訊息。省電，但訊息可能會晚到。';

  @override
  String get gettingMessagesOnTheLockScreen => '在鎖定畫面上';

  @override
  String get gettingMessagesHideMessagePreview => '隱藏訊息預覽';

  @override
  String get gettingMessagesAGenericAlertWith => '只顯示一般提醒，不顯示傳送者和訊息內容';

  @override
  String get gettingMessagesShowsMessageTextIn =>
      '在通知中顯示訊息內容，即使 Kryfo 已鎖定也會顯示。';

  @override
  String get gettingMessagesWhenThePhoneSits =>
      '手機靜置不動時，Android 會拉長查收的間隔。上面那一行顯示的是實際的上次查收。Kryfo 開著的時候會保持連線。';

  @override
  String get groupChatJumpToTheNewest => '跳到最新';

  @override
  String get groupChatBlockedEverywhere => '已全面封鎖';

  @override
  String get groupChatYou => '你';

  @override
  String get groupChatVoiceMessage => '語音訊息';

  @override
  String get groupChatQuotedPhoto => '照片';

  @override
  String get groupChatMessageUnavailable => '訊息無法顯示';

  @override
  String get groupChatTorIsNotUp => 'Tor 尚未啟動 · 不附預覽直接傳送';

  @override
  String get groupChatCouldnTReachIt => '連不上 · 不附預覽直接傳送';

  @override
  String get groupChatNoTitleCameBack => '沒有取得標題 · 不附預覽直接傳送';

  @override
  String get groupChatCouldnTFetchIt => '無法擷取 · 不附預覽直接傳送';

  @override
  String get groupChatCamera => '相機';

  @override
  String get groupChatGallery => '相簿';

  @override
  String get groupChatVideo => '影片';

  @override
  String get groupChatGifFromPhone => '手機裡的 GIF';

  @override
  String get groupChatFile => '檔案';

  @override
  String get groupChatCouldNotReadThat => '無法讀取那個檔案';

  @override
  String get groupChatGifTooBig8 => 'GIF 太大 · 上限 8 mb';

  @override
  String get groupChatCouldNotCleanThat => '無法清理那個 GIF';

  @override
  String get groupChatFileTooBig8 => '檔案太大 · 上限 8 mb';

  @override
  String get groupChatCouldNotCleanThatVideo => '無法清理那段影片';

  @override
  String get groupChatCouldNotCleanThatPictureSend => '無法清理那張圖片 · 請改用照片傳送';

  @override
  String get groupChat30Seconds => '30 秒';

  @override
  String get groupChat1Minute => '1 分鐘';

  @override
  String get groupChat5Minutes => '5 分鐘';

  @override
  String get groupChat1Hour => '1 小時';

  @override
  String get groupChat24Hours => '24 小時';

  @override
  String get groupChatBurnTimer => '限時訊息';

  @override
  String get groupChatNewMessagesDisappearAfter => '新訊息會在這段時間後消失';

  @override
  String get groupChatToday => '今天';

  @override
  String get groupChatYesterday => '昨天';

  @override
  String get groupChatYou2 => '你';

  @override
  String groupChatThisChatHasPins(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '這個聊天已經有 $countString 則置頂訊息',
    );
    return '$_temp0';
  }

  @override
  String get groupChatUnpinThisMessage => '要取消置頂這則訊息嗎？';

  @override
  String get groupChatPinThisMessage => '要置頂這則訊息嗎？';

  @override
  String get groupChatItLeavesThePinned => '它會從這裡所有人的置頂清單中移除。';

  @override
  String get groupChatItGoesUnderThe => '它會放在聊天頂端的置頂區，這裡的所有人都看得到。';

  @override
  String get groupChatUnpin => '取消置頂';

  @override
  String get groupChatPinIt => '置頂';

  @override
  String get groupChatNotNow => '以後再說';

  @override
  String get groupChatSaved => '已收藏';

  @override
  String get groupChatRemovedFromSaved => '已從收藏移除';

  @override
  String get groupChatForwardTo => '轉傳給';

  @override
  String get groupChatNoContactsToForward => '沒有可轉傳的聯絡人';

  @override
  String get groupChatEditMessage => '編輯訊息';

  @override
  String get groupChatUnsendMessage => '收回訊息';

  @override
  String get groupChatItDisappearsWithNo => '訊息會消失，不留任何痕跡。這個動作無法復原。';

  @override
  String get groupChatUnsend => '收回';

  @override
  String groupChatThisRoomAndEverything(Object expiryWords) {
    return '這個聊天室和裡面的一切都會在 $expiryWords後消失';
  }

  @override
  String groupChatGhostModeOnBurns(Object fmtBurn) {
    return '限時訊息 · $fmtBurn後焚毀';
  }

  @override
  String get groupChatGroupCreatedSayHi => '群組已建立。打聲招呼吧。';

  @override
  String get groupChatNoMessagesYet => '還沒有訊息。';

  @override
  String get groupChatThisMessageCanT => '這則訊息無法顯示';

  @override
  String groupChatS(Object s) {
    return '$s 秒';
  }

  @override
  String groupChatM(Object s) {
    return '$s 分鐘';
  }

  @override
  String groupChatH(Object s) {
    return '$s 小時';
  }

  @override
  String groupChatD(Object s) {
    return '$s 天';
  }

  @override
  String groupChatHere(int count, Object time) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$time · $countString 人在這裡',
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
      other: '$countString 位成員',
    );
    return '$_temp0';
  }

  @override
  String get groupChatSearchThisChat => '搜尋這個聊天';

  @override
  String groupChatReplyingTo(Object name) {
    return '回覆 $name';
  }

  @override
  String get groupChatReplyingToYou => '回覆你';

  @override
  String get groupChatTimedMessages => '限時訊息';

  @override
  String get groupChatOpenTheCamera => '開啟相機';

  @override
  String get groupChatAttachAPhoto => '附加照片';

  @override
  String get groupChatMessage => '訊息';

  @override
  String get groupChatDisguiseVoice => '變聲';

  @override
  String get groupChatSupporter => '支持者';

  @override
  String get groupChatEdited => '已編輯';

  @override
  String get groupChatTapToRetry => '! 點一下重試';

  @override
  String get groupChat0s => '0 秒';

  @override
  String get groupChatReply => '回覆';

  @override
  String get groupChatPin => '置頂';

  @override
  String get groupChatUnsave => '取消收藏';

  @override
  String get groupChatForward => '轉傳';

  @override
  String get groupInfoGroup => '群組';

  @override
  String get groupInfoRenameGroup => '重新命名群組';

  @override
  String get groupInfoRename => '重新命名';

  @override
  String get groupInfoNoContactsToAdd => '沒有可新增的聯絡人';

  @override
  String get groupInfoCouldNotAdd => '無法新增';

  @override
  String groupInfoRemove(Object haloId) {
    return '要移除 $haloId 嗎？';
  }

  @override
  String get groupInfoTheyWillStopReceiving => '對方將不再收到這個群組的訊息。';

  @override
  String get commonRemove => '移除';

  @override
  String get groupInfoClearThisConversation => '要清空這段對話嗎？';

  @override
  String get groupInfoEveryMessageHereIs =>
      '這裡的每則訊息都會從這支手機上抹除。這只會清空你的副本，其他成員的副本會保留。';

  @override
  String get groupInfoClear => '清空';

  @override
  String get groupInfoConversationCleared => '對話已清空';

  @override
  String get groupInfoLeaveRoom => '要離開聊天室嗎？';

  @override
  String get groupInfoLeaveGroup => '要離開群組嗎？';

  @override
  String get groupInfoEverythingInItIs => '裡面的一切會立即從這支手機上清除，你在這裡使用的金鑰也會永久消失。';

  @override
  String get groupInfoYouWillStopReceiving => '你將不再收到訊息，其他成員會看到你離開。';

  @override
  String get groupInfoLeave => '離開';

  @override
  String get groupInfoGroupInfo => '群組資訊';

  @override
  String groupInfo1Member(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 位成員',
    );
    return '$_temp0';
  }

  @override
  String get groupInfoAdmin => '管理員';

  @override
  String get groupInfoMembers2 => '成員';

  @override
  String get groupInfoInvite => '邀請';

  @override
  String get commonAdd => '新增';

  @override
  String get groupInfoYou => '你';

  @override
  String get groupInfoRemoveFromGroup => '從群組移除';

  @override
  String get groupInfoWallpaper => '桌布';

  @override
  String get groupInfoSharedMedia => '分享的媒體';

  @override
  String get groupInfoClearConversation => '清空對話';

  @override
  String get groupInfoLeaveRoom2 => '離開聊天室';

  @override
  String get groupInfoLeaveGroup2 => '離開群組';

  @override
  String get groupInfoAddMembers => '新增成員';

  @override
  String groupInfoAdd(Object pickedLength) {
    return '新增 $pickedLength 位';
  }

  @override
  String handleYouAre(Object h) {
    return '你是 @$h';
  }

  @override
  String get handleHandleDeletedThePage => '使用者名稱已刪除 · 頁面已移除';

  @override
  String get handlePublicHandle => '公開使用者名稱';

  @override
  String get handleOptionalYourThreeWords => '非必填。無論如何，你的三個詞都能繼續使用。';

  @override
  String get handleWren => 'wren';

  @override
  String get handleALineAboutYou => '一句關於你的介紹 · 非必填';

  @override
  String get handleClaiming => '認領中…';

  @override
  String get handleClaimThisHandle => '認領這個使用者名稱';

  @override
  String get handleAnyoneWithThisLink =>
      '任何拿到這個連結的人都能和你開始私密聊天。它只帶有你的邀請，沒有其他任何東西。';

  @override
  String get handleLinkCopied => '已複製連結';

  @override
  String get handleDeleteThisHandle => '刪除這個使用者名稱';

  @override
  String get handleChecking => '檢查中…';

  @override
  String get handleAvailable => '✓ 可以使用';

  @override
  String get handleAlreadyTaken => '已被使用';

  @override
  String get handleWhatAHandleDoes => '使用者名稱的用途';

  @override
  String get handleAnyoneWhoKnowsIt =>
      '任何知道它的人都能要求傳訊息給你，這正是擁有使用者名稱的意義。這個頁面只存放你的邀請和你寫的那一句話，沒有其他東西，也不會記錄誰讀過它。你隨時都可以刪除它。';

  @override
  String handleIsNotYoursOn(Object handle) {
    return '在這支手機上，@$handle 不屬於你';
  }

  @override
  String handleTheRegistryHoldsIt(Object handle) {
    return '註冊處記錄它屬於另一把金鑰，很可能是這支手機還原之前的身分。新增 @$handle 的人聯絡不到你。它無法在這裡釋出或更新。請換一個名字。';
  }

  @override
  String get handleForgetItOnThis => '在這支手機上忘記它';

  @override
  String get homeAddAContact => '新增聯絡人';

  @override
  String get commonSettings => '設定';

  @override
  String get homeYourKryfo => '你的 Kryfo';

  @override
  String homeDateWeekday(Object weekday) {
    return '$weekday';
  }

  @override
  String get homeAnHour => '1 小時';

  @override
  String homeHours(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 小時',
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
      other: '$countString 分鐘',
    );
    return '$_temp0';
  }

  @override
  String get homeKryfoIsOffline => 'Kryfo 目前離線';

  @override
  String homeTorHasNotBeen(Object howLong) {
    return 'Tor 已經 $howLong無法連線。連上之前，任何東西都收不到，也送不出去。';
  }

  @override
  String get homeReconnecting => '正在重新連線';

  @override
  String get homeReconnect => '重新連線';

  @override
  String get homeWhatIsWrong => '出了什麼問題';

  @override
  String get homeKryfoWillCheckIn => 'Kryfo 會每 15 分鐘查收一次';

  @override
  String get homeYourPhoneKeepsStopping => '你的手機一直在停止 Kryfo';

  @override
  String get homeItHasClosedKryfo =>
      '它今天已經關掉 Kryfo 三次，所以訊息延遲了或卡住了。定時查收不受影響：Kryfo 會每 15 分鐘醒來一次，而不是一直保持連線。';

  @override
  String get homeSwitchToCheckIns => '改用定時查收';

  @override
  String get homeNotNow => '以後再說';

  @override
  String get homeNotificationsAreOff => '通知已關閉';

  @override
  String get homeAndroidIsBlockingThem =>
      'Android 正在阻擋通知，所以 Kryfo 關閉時，你什麼都不會收到。打開 Kryfo 時訊息還是會送達。';

  @override
  String get homeCouldnTOpenIt => '無法開啟。請在手機設定中尋找 Kryfo';

  @override
  String get homeTurnThemOn => '開啟通知';

  @override
  String get homeLeaveThemOff => '保持關閉';

  @override
  String get homeOurRelayIsQuiet => '我們的中繼沒有回應';

  @override
  String get homeRelayModeUsesOnly =>
      '中繼模式只使用我們自己的中繼，而它現在沒有回應。快速模式會同時加入公共中繼，讓訊息仍能送達。無論哪種模式，一切都保持密封。';

  @override
  String get homeSwitchedToFast => '已切換到快速';

  @override
  String get homeUseFastMode => '使用快速模式';

  @override
  String get homeKeepWaiting => '繼續等待';

  @override
  String get homeNotConnecting => '無法連線';

  @override
  String get homeBridgesAreOnAnd =>
      '橋接已開啟，但 tor 仍然連不上。橋接比較慢，有些還會無預警失效。如果你的網路沒有封鎖 tor，直接連線更快也更穩定。';

  @override
  String get homeGoingDirectReconnecting => '改為直接連線 · 正在重新連線';

  @override
  String get homeTurnBridgesOff => '關閉橋接';

  @override
  String get homeStillTrying => '仍在嘗試';

  @override
  String get homeTorIsNotGetting =>
      'Tor 連不出去。有些網路會刻意封鎖它。我們自己的中繼只是一條普通連線，通常還是能用；或者改用橋接，不過設定比較費時。';

  @override
  String get homeSwitchedToRelay => '已切換到中繼';

  @override
  String get homeUseOurRelay => '使用我們的中繼';

  @override
  String get homeBridges => '橋接';

  @override
  String get homeOffline => '離線';

  @override
  String get homeWaiting => '等待中';

  @override
  String get homeNothingWaitingToSend => '沒有待傳送的內容';

  @override
  String homeWaitingSendsWhenYou(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 則等待中 · 你恢復連線後傳送',
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
      other: '$countString 則等待中 · tor 仍在連線',
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
      other: '$countString 則等待中 · 等對方把你加回來',
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
      other: '$countString 則等待中 · $parkedString 則在等對方把你加回來',
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
      other: '$countString 則等待中 · 正在傳送',
    );
    return '$_temp0';
  }

  @override
  String get commonRetry => '重試';

  @override
  String get homeNoKryfosYet => '還沒有 Kryfo 聯絡人。';

  @override
  String get homeScanTheirCodeSend => '掃描對方的 QR 碼、傳連結給對方，或輸入對方給你的 @使用者名稱。';

  @override
  String get homeAddSomeone => '新增聯絡人';

  @override
  String get homeArchived => '已封存';

  @override
  String home1Chat(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 個聊天',
    );
    return '$_temp0';
  }

  @override
  String get homeGroups => '群組';

  @override
  String get homeRoom => '聊天室';

  @override
  String get homeNew => '新增';

  @override
  String homeRoomExpired(Object expiredRoomName) {
    return '$expiredRoomName · 聊天室已過期';
  }

  @override
  String get homeMentionedYou => '提到了你';

  @override
  String homeMembers(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 位成員',
    );
    return '$_temp0';
  }

  @override
  String get homeSupporter => '支持者';

  @override
  String get homeArchivedChats => '封存的聊天';

  @override
  String get homeUnmute => '取消靜音';

  @override
  String get homeMute => '靜音';

  @override
  String get homeArchive => '封存';

  @override
  String get homeDeleteChat => '刪除聊天';

  @override
  String get homeMessagesAndContactGone => '訊息和聯絡人都會從這支手機上消失';

  @override
  String get homeDeleteThisChat => '要刪除這個聊天嗎？';

  @override
  String homeEveryMessageWithGoes(Object c) {
    return '和 $c 的每則訊息都會刪除，對方也不再是你的聯絡人。這只會清空這支手機，對方的副本仍留在對方那裡。如果對方再傳訊息，會出現在請求中。';
  }

  @override
  String get homeQueued => '排隊中';

  @override
  String get homeBlocked => '已封鎖';

  @override
  String get homeRoomInvite => '聊天室邀請';

  @override
  String get homeNow => '剛剛';

  @override
  String homeM(Object inMinutes) {
    return '$inMinutes 分鐘';
  }

  @override
  String homeH(Object inHours) {
    return '$inHours 小時';
  }

  @override
  String get homeYesterday => '昨天';

  @override
  String homeD(Object inDays) {
    return '$inDays 天';
  }

  @override
  String get homeNoteToSelf => '給自己的筆記';

  @override
  String get homeOnlyOnThisPhone => '只在這支手機上';

  @override
  String get homeSaved => '收藏';

  @override
  String get homeKeptFromEveryChat => '收藏自每個聊天';

  @override
  String get homeRequests => '請求';

  @override
  String home1PersonWantsTo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 個人想聯絡你',
    );
    return '$_temp0';
  }

  @override
  String introduceGotItButCould(Object b, Object c) {
    return '$b 已收到，但聯絡不到 $c';
  }

  @override
  String introduceGotItButCouldNotBe(Object c, Object b) {
    return '$c 已收到，但聯絡不到 $b';
  }

  @override
  String get introduceCouldNotReachEither => '兩個人都聯絡不到。請稍後再試';

  @override
  String introduceIntroduceTo(Object peerName) {
    return '把 $peerName 介紹給…';
  }

  @override
  String get introduceBothOfThemGet => '他們都會收到對方的名片。雙方都看不到你給對方取的暱稱。';

  @override
  String get introduceNoOneElseTo => '目前沒有其他人可以介紹。請先新增另一位聯絡人。';

  @override
  String get introduceANoteLikeMy => '附註，例如「我表哥」，非必填';

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
      other: '本週還剩 $leftString 次介紹（共 $maxString 次）',
    );
    return '$_temp0';
  }

  @override
  String introduceNoIntroductionsLeftNext(Object refillPhrase) {
    return '介紹次數已用完。下次名額：$refillPhrase';
  }

  @override
  String get introduceIntroduce => '介紹';

  @override
  String get keyVerificationSafetyNumber => '安全碼';

  @override
  String keyVerificationWith(Object peerName) {
    return '與 $peerName';
  }

  @override
  String keyVerificationIfSeesTheSame(Object peerName) {
    return '如果 $peerName 看到的是同一組號碼，你們的訊息就只有你們兩個人看得到。當面比對，或透過你信任的通話比對，是最可靠的確認方式，但這是選擇性的，聊天從來不需要它。';
  }

  @override
  String get keyVerificationVerified => '已驗證';

  @override
  String get keyVerificationMarkAsVerified => '標記為已驗證';

  @override
  String get lockFileThatPasswordDoesNot => '這個密碼打不開它。';

  @override
  String get lockFileThisFileIsDamaged => '這個檔案已損毀。';

  @override
  String get lockFileThisFileWasLocked => '這個檔案是用金鑰鎖定的，不是用密碼。';

  @override
  String get lockFileThisIsNotA => '這不是鎖定的檔案。';

  @override
  String get lockFileNotEnoughFreeMemory => '目前可用記憶體不足。';

  @override
  String get lockFileStopped => '已停止。';

  @override
  String get lockFileItNeedsAPassword => '需要密碼。';

  @override
  String get lockFileKryfoCouldNotRead => 'Kryfo 無法讀取或寫入這個檔案。';

  @override
  String get lockFileCheckCapitalsAndSpaces => '請檢查大小寫和空格。沒有人能重設它，包括我們。';

  @override
  String get lockFileItMayHaveBeen => '它可能在傳送途中被截斷了。請對方再傳一次。沒有儲存任何東西。';

  @override
  String get lockFileItOpensWithThe =>
      '它要用收件人的金鑰檔案，在電腦上的 age 工具中開啟。Kryfo 能開啟的是用密碼鎖定的那種。';

  @override
  String get lockFileKryfoOpensFilesLocked =>
      'Kryfo 可以開啟用 age 鎖定的檔案。這類檔名通常以 .age 結尾。';

  @override
  String get lockFileCloseAFewApps => '請關閉幾個應用程式後再試一次。檢查密碼時，會短暫需要幾百 MB 的記憶體。';

  @override
  String get lockFileNothingWasSaved => '沒有儲存任何東西。';

  @override
  String get lockFileTypeOneOrLet => '自己輸入一組，或讓 Kryfo 建議四個詞。';

  @override
  String get lockFileTheAppThatHolds => '存放它的應用程式可能已經把它收回。請再選一次。';

  @override
  String get lockFileHidePassword => '隱藏密碼';

  @override
  String get lockFileShowPassword => '顯示密碼';

  @override
  String get lockFileChangeFile => '更換檔案';

  @override
  String get lockFileChange => '更換';

  @override
  String lockFileOf(Object prettySize, Object prettySize2) {
    return '$prettySize/$prettySize2';
  }

  @override
  String get lockFileEverythingStaysOnThis => '一切都留在這支手機上。';

  @override
  String get lockFileCouldNotMakeOne => '無法產生。請自己輸入。';

  @override
  String get lockFileWriteItDownBefore => '鎖定檔案前，請先把密碼寫下來';

  @override
  String get lockFileNoAppOnThis => '這支手機上沒有任何應用程式接收這個檔案。';

  @override
  String get lockFileSaved => '已儲存';

  @override
  String get lockFileCouldNotSaveIt => '無法儲存到那裡。請換一個資料夾。';

  @override
  String get lockFileLocked => '已鎖定';

  @override
  String get lockFileLockAFile => '鎖定檔案';

  @override
  String get lockFileMixingThePassword => '正在混合密碼';

  @override
  String get lockFileLocking => '鎖定中';

  @override
  String get lockFileSaveToFiles => '儲存到檔案';

  @override
  String get lockFileLockFile => '鎖定檔案';

  @override
  String get lockFileOnePassword => '一組密碼。';

  @override
  String get lockFileNothingElseOpensIt => '除此之外，什麼都打不開。';

  @override
  String get lockFileFile => '檔案';

  @override
  String lockFileFromFiles(Object prettySize) {
    return '$prettySize · 來自檔案';
  }

  @override
  String get lockFileFromFiles2 => '從檔案選取';

  @override
  String get lockFilePassword => '密碼';

  @override
  String get lockFileSuggestFourWords => '建議四個詞';

  @override
  String get lockFileTypeItAgain => '再輸入一次';

  @override
  String get lockFileTheTwoDoNot => '兩次輸入還不一致。';

  @override
  String get lockFileHideTheFileName => '隱藏檔名';

  @override
  String lockFileItWillBeCalled(Object name) {
    return '它會被命名為「$name」。記得告訴對方這是什麼檔案。';
  }

  @override
  String get lockFileTheNameAloneCan => '光是檔名就可能透露裡面的內容。';

  @override
  String get lockFileAnyoneWithThePassword =>
      '任何知道密碼的人都能開啟它，無論是在 Kryfo 裡，還是在任何裝有免費工具 age 的電腦上。忘了密碼，檔案就永遠拿不回來了。沒有人能重設它，包括我們。';

  @override
  String get lockFileLocked2 => '已鎖定。';

  @override
  String get lockFileOnlyThePasswordOpens => '只有密碼能開啟它。';

  @override
  String lockFileSafeToEmailOr(Object prettySize) {
    return '$prettySize · 可以放心用電子郵件寄出，或存到 USB 隨身碟';
  }

  @override
  String get lockFileNoKryfoOnThe => '對方沒有 Kryfo？在電腦上：';

  @override
  String get lockFileItAsksForThe => '它會要求輸入密碼。age 可在 age-encryption.org 免費取得';

  @override
  String lockTooManyTriesS(Object lockState) {
    return '嘗試次數過多 · $lockState 秒';
  }

  @override
  String get lockNotIt => '不對';

  @override
  String get lockYourPin => '你的 PIN 碼';

  @override
  String get lockUseFingerprint => '使用指紋';

  @override
  String get lockSetupUnlockWithFingerprint => '要用指紋解鎖嗎？';

  @override
  String get lockSetupThePinStillWorks => '你隨時都還是可以用 PIN 碼解鎖。這只是比較快。';

  @override
  String get lockSetupUseFingerprint => '使用指紋';

  @override
  String get lockSetupPinOnly => '只用 PIN 碼';

  @override
  String get lockSetupOnceMore => '再一次';

  @override
  String get lockSetupSetAPin => '設定 PIN 碼';

  @override
  String get lockSetupThoseWereDifferentFrom => '兩次不一樣。從頭再來。';

  @override
  String get lockSetupTheSameFourDigits => '再輸入一次同樣的數字';

  @override
  String get lockSetupFourDigitsAnythingYou => '四位或更多數字，選一組你記得住的';

  @override
  String get modesOnion => 'Onion';

  @override
  String get modesFullOnionRoutingThree =>
      '完整的 onion 路由，3 跳。一則訊息需要兩到五秒。沒有人看得到你在和誰聊天。';

  @override
  String get modesSlower => '較慢';

  @override
  String get modesRelay => '中繼';

  @override
  String get modesOneSealedConnectionTo =>
      '一條密封連線，直通 Kryfo 自己的中繼，就像一個沒有東西可記錄的 VPN。訊息大約一秒送達，在 tor 被封鎖的地方也能用。';

  @override
  String get modesQuick => '較快';

  @override
  String get modesRelayOnly => '只用中繼';

  @override
  String get modesFast => '快速';

  @override
  String get modesPlainConnectionsToEvery => '以普通連線直接連到每個中繼。幾乎即時，也是三種模式中最不私密的。';

  @override
  String get modesInstant => '即時';

  @override
  String get modesEveryRelayYouUse =>
      '你使用的每個中繼都會知道你連線的來源位址，不只是我們的中繼。訊息仍然是密封的，但「你傳了訊息」這件事不是。預設關閉，重新安裝後也會再次關閉。';

  @override
  String get modesSpeed => '速度';

  @override
  String get modesPrivacy => '與隱私';

  @override
  String get modesChangeGloballyOrPer => '可全域變更，或依聊天個別設定';

  @override
  String get modesSoon => '即將推出';

  @override
  String get modesActive => '使用中';

  @override
  String get modesSpeed2 => '速度';

  @override
  String get modesHops => '跳數';

  @override
  String get modesIp => 'IP';

  @override
  String get modesVisible => '可見';

  @override
  String get modesHidden => '隱藏';

  @override
  String modesHeadsUp(Object warning) {
    return '*注意：*$warning';
  }

  @override
  String get modesOnionIsTheDefault =>
      'Onion 是預設模式，除非你更改，否則會一直維持。切換會從下一則訊息開始生效。';

  @override
  String get modesFastMode => '快速模式';

  @override
  String get modesPlainConnectionsToEveryRelayQuicker =>
      '以普通連線直接連到每個中繼。比較快，而且中繼看得到你的 IP 位址。無論如何，訊息都保持端對端加密。';

  @override
  String get modesTurnOnFastMode => '開啟快速模式';

  @override
  String get modesKeepItOff => '保持關閉';

  @override
  String get movedWipeThisPhone => '要從這支手機清除 Kryfo 嗎？';

  @override
  String get movedEverythingKryfoHoldsHere =>
      'Kryfo 在這裡保存的一切都會消失：訊息、聯絡人、金鑰。另一台裝置會保有這一切。這個動作無法復原。';

  @override
  String get movedWipeIt => '清除';

  @override
  String get movedNotMovingAfterAll => '最後決定不搬了？';

  @override
  String get movedOnlyDoThisIf =>
      '只有在備份從未匯入任何地方時才這麼做。如果已經匯入過，現在就有兩台裝置持有同一個身分，兩邊的訊息都會開始遺失。';

  @override
  String get movedIMStayingHere => '我要留在這裡';

  @override
  String get movedStayingHere => '留在這裡';

  @override
  String movedKryfoWillCloseNow(Object myId) {
    return 'Kryfo 現在會關閉。點一下圖示，以 $myId 重新開啟。';
  }

  @override
  String get movedReopenKryfo => '重新開啟 Kryfo';

  @override
  String get movedThisKryfoHasMoved => '這個 Kryfo 已經搬走了';

  @override
  String movedIsNowOnAnother(Object myId) {
    return '$myId 現在在另一台裝置上。這支手機仍可顯示原本的內容，但不會再收到任何新東西，從這裡傳送的任何內容也不會送達任何人。';
  }

  @override
  String get movedKeepItToRead => '留著閱讀';

  @override
  String get movedWipeThisPhone2 => '從這支手機清除 Kryfo';

  @override
  String get movedIMNotMoving => '我最後決定不搬了';

  @override
  String get myKryfoAHandleIs3 => '使用者名稱為 3 到 20 個字母、數字或 _';

  @override
  String get myKryfoInviteCopiedClearsIn => '已複製邀請 · 60 秒後清空';

  @override
  String myKryfoAddMeOnKryfo(Object myId, Object uri) {
    return '在 Kryfo 上加我。我的 ID 是 $myId\n\n點這裡加我：\n$uri\n\nKryfo 是一款私密通訊軟體。不需要手機號碼，也不需要電子郵件。';
  }

  @override
  String get myKryfoAddMeOnKryfo2 => '在 Kryfo 上加我';

  @override
  String get myKryfoAddSomeone => '新增聯絡人';

  @override
  String get myKryfoKryfoDoesnTScan => 'Kryfo 不會掃描你的通訊錄，這正是重點。';

  @override
  String get myKryfoIfThisLinkEnds =>
      '如果這個連結流傳到你不希望的地方，請到設定中重設。之後所有持有它的人都需要新的連結。';

  @override
  String get myKryfoAlreadyShareAFriend =>
      '你們在 Kryfo 上有共同的朋友嗎？對方可以在聊天中介紹你們認識，你們就不用送出請求。';

  @override
  String get myKryfoHandleCopied => '已複製使用者名稱';

  @override
  String get myKryfoTheyReHereWith => '對方就在我身邊';

  @override
  String get myKryfoPointYourPhonesAt => '把你們的手機對準彼此。不會經過任何伺服器。';

  @override
  String get myKryfoScanTheirsInstead => '改掃描對方的';

  @override
  String get myKryfoTheyReadYouA => '對方唸一組碼給你';

  @override
  String get myKryfoTheyReSomewhereElse => '對方在別的地方';

  @override
  String get myKryfoSendThemALink => '傳連結給對方。點開就會直接進入新增畫面。';

  @override
  String get myKryfoYourLinkAppearsOnce => '連線後就會顯示你的連結';

  @override
  String get myKryfoTheLinkCarriesYour =>
      '這個連結帶有你的 ID、你的位址，以及開始聊天所需的金鑰。在你到設定中重設之前，它都有效。';

  @override
  String get myKryfoSendTheLink => '傳送連結';

  @override
  String get myKryfoAsACard => '做成名片';

  @override
  String get myKryfoAnImageWithThe => '附 QR 碼的圖片';

  @override
  String get myKryfoAsAFile => '做成檔案';

  @override
  String get myKryfoContactFile => '聯絡人檔案';

  @override
  String get myKryfoIKnowTheirHandle => '我知道對方的使用者名稱';

  @override
  String get myKryfoTypeTheNameThey => '輸入對方給你的 @名稱。對方有認領名稱才有效。';

  @override
  String get myKryfoWren => 'Wren';

  @override
  String get myKryfoTheLookupAsksFor =>
      '查詢只會送出那一個名稱，不含任何關於你的資訊。你傳給對方的第一則訊息仍會以請求的形式送達。';

  @override
  String get myKryfoLooking => '尋找中…';

  @override
  String get myKryfoFindThem => '尋找對方';

  @override
  String get myKryfoYourAddressAppearsOnce => '連線後就會顯示你的位址';

  @override
  String get myKryfoAPublicHandle => '公開的使用者名稱';

  @override
  String get myKryfoPutItInA => '放進個人簡介裡。任何知道它的人都能找到你。';

  @override
  String get myKryfoANamePeopleCan => '一個讓別人能找到你的名稱。在你認領之前都是關閉的。';

  @override
  String get newGroupCouldNotCreate => '無法建立';

  @override
  String get newGroupNewGroup => '新群組';

  @override
  String get newGroupCreating => '建立中…';

  @override
  String get newGroupCreate => '建立';

  @override
  String get newGroupGroupName => '群組名稱';

  @override
  String get newGroupMembers => '成員';

  @override
  String get newGroupPickAtLeastOne => '至少選一位';

  @override
  String newGroupSelected(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已選 $countString 位',
    );
    return '$_temp0';
  }

  @override
  String get newGroupAddAtLeastOne => '建立群組前，請先新增至少一位聯絡人。';

  @override
  String get notesToday => '今天';

  @override
  String get notesYesterday => '昨天';

  @override
  String get notesNoteToSelf => '給自己的筆記';

  @override
  String get notesOnlyOnThisPhone => '只在這支手機上';

  @override
  String get notesAQuietPlace => '一個安靜的角落';

  @override
  String get notesJotAnythingDownIt => '隨手記下任何事。它只留在這支手機上，永遠不會離開。';

  @override
  String get notesJotSomethingDown => '記點什麼…';

  @override
  String get onboardingPrivateByDefault => '預設就是私密';

  @override
  String get onboardingPrivateMessaging => '私密通訊，\n*沒有隱藏代價*。';

  @override
  String get onboardingYourNameIsThree => '*你的名字就是三個詞。*不用手機號碼，不用電子郵件，不用通訊錄。';

  @override
  String get onboardingNobodyGetsInUnless =>
      '*除非你允許，沒有人能進來。*沒有搜尋功能。聯絡人都由雙方親手新增。';

  @override
  String get onboardingTheFirstConnectionTakes =>
      '*第一次連線需要一分鐘。*Kryfo 會先建立私密路線再傳送。之後就快了。';

  @override
  String get onboardingBegin => '開始';

  @override
  String get onboardingHaveABackupRestore => '有備份嗎？還原 →';

  @override
  String get onboardingKryfoIsOpenSource => 'Kryfo 開放原始碼';

  @override
  String get onboardingYourKryfoId => '你的 KRYFO ID';

  @override
  String get onboardingGeneratedFromAKey =>
      '由只存在這支手機上的金鑰產生。*好記、獨一無二、只屬於你。*沒有其他人有這組詞。';

  @override
  String get onboardingTryAnother => '換一個';

  @override
  String get onboardingUseThisName => '使用這個名字 →';

  @override
  String get onboardingThreeWords => '三個詞。*只屬於你。*';

  @override
  String get onboardingPickA => '選一張*臉*。';

  @override
  String get onboardingDrawnOnThisPhone => '在這支手機上根據一個數字畫出來，從不上傳。隨時都可以更換。';

  @override
  String get onboardingThePeopleYouMessage => '跟你傳訊息的人也會看到這個';

  @override
  String get onboardingKeepMyInitial => '保留名字首字';

  @override
  String get onboardingThatOne => '就這張 →';

  @override
  String get onboardingContinue => '繼續 →';

  @override
  String get onboardingHowYourMessages => '你的訊息如何*傳遞*。';

  @override
  String get onboardingYouCanChangeThis => '你隨時可以在設定中更改，套用到所有人或單一聊天。';

  @override
  String get onboardingOnion => 'Onion';

  @override
  String get onboardingSlowerAMessageTakes => '較慢。一則訊息需要兩到五秒。';

  @override
  String get onboardingHidesYourAddressFrom => '對所有人隱藏你的位址，包括我們的中繼。';

  @override
  String get onboardingRelay => '中繼';

  @override
  String get onboardingOurRelaySeesYour => '我們的中繼看得到你的位址。其他人都看不到。';

  @override
  String get onboardingAboutASecondWorks => '大約一秒。在 tor 被封鎖的地方也能用。';

  @override
  String get onboardingFast => '快速';

  @override
  String get onboardingEveryRelayYouUse => '你使用的每個中繼都看得到你的位址。三種之中最不私密。';

  @override
  String get onboardingNearInstant => '幾乎即時。';

  @override
  String get onboardingKeepOnion => '保持 Onion →';

  @override
  String get onboardingUseThis => '使用這個 →';

  @override
  String get onboardingSkipOnionIsA => '略過 · Onion 是不錯的預設';

  @override
  String get onboardingThreeThingsThen => '三件事，\n之後*就可以開始了*。';

  @override
  String get onboardingEverythingElseTheApp => '其他的事，應用程式會在需要時告訴你。';

  @override
  String get onboardingYourNameIsThreeWords => '你的名字就是三個詞';

  @override
  String get onboardingThatIsTheWhole =>
      '這就是你的全部身分。沒有號碼會外洩，沒有電子郵件能被拿來釣魚，也沒有任何東西可以查。和你聊天的人會看到這些詞和你選的臉。';

  @override
  String get onboardingNobodyCanReachYou => '除非你讓對方進來，否則沒有人能聯絡到你';

  @override
  String get onboardingAStrangerWithYour =>
      '知道你這三個詞的陌生人只能敲門。對方的第一則訊息會在請求中等待，直到你答應；你也可以拒絕，對方永遠不會知道。';

  @override
  String get onboardingTheFirstConnectionTakesAMinute => '第一次連線需要一分鐘';

  @override
  String get onboardingKryfoBuildsAPrivateRouteBefore =>
      'Kryfo 在傳送任何東西之前，會先建立一條私密路線。你離線時，訊息會先等著，等你回來再送達。';

  @override
  String get onboardingYourIdentityLivesOn => '你的身分存在這支手機上。準備好時，可以從設定中備份。';

  @override
  String get onboardingIUnderstand => '我了解了 →';

  @override
  String get onboardingOneQuiet => '一則安靜的*通知*。';

  @override
  String get onboardingAndroidNeedsAVisible =>
      '應用程式在背景監聽時，Android 需要顯示一則通知。Kryfo 關閉時，訊息就是這樣送到你手上的。';

  @override
  String get onboardingSilentAndAtThe => '無聲，而且放在通知欄最底下';

  @override
  String get onboardingItNeverBuzzesTurn => '它從不震動。把它關掉的話，訊息會等到你再次開啟應用程式。';

  @override
  String get onboardingGotIt => '知道了 →';

  @override
  String get onboardingNow => '現在，*新增聯絡人*。';

  @override
  String get onboardingTheAppIsReady => '應用程式準備好了。除非你新增對方或讓對方進來，否則沒有人能傳訊息給你。';

  @override
  String get onboardingEveryWayToAdd => '所有新增聯絡人的方式';

  @override
  String get onboardingShowYourCodeSend => '出示你的 QR 碼、傳連結給對方，或輸入對方給你的 @使用者名稱。';

  @override
  String get onboardingScanTheirs => '掃描對方的';

  @override
  String get onboardingPointTheCameraAt => '用相機對準對方的 QR 碼';

  @override
  String get onboardingTheAppIsReadyWhenYou => '你準備好了，應用程式就準備好了。';

  @override
  String get onboardingNotNowAddPeople => '以後再說 · 稍後再新增聯絡人';

  @override
  String get openLockedOpened => '已開啟';

  @override
  String get openLockedOpenALockedFile => '開啟鎖定的檔案';

  @override
  String get openLockedCheckingThePassword => '正在檢查密碼';

  @override
  String get openLockedOpening => '開啟中';

  @override
  String get openLockedFile => '檔案';

  @override
  String get openLockedOpenFile => '開啟檔案';

  @override
  String get openLockedTypeThePassword => '輸入密碼。';

  @override
  String get openLockedItOpensOnThis => '它會在這支手機上開啟。';

  @override
  String get openLockedLockedFile => '鎖定的檔案';

  @override
  String openLockedFromFiles(Object prettySize) {
    return '$prettySize · 來自檔案';
  }

  @override
  String get openLockedFromFiles2 => '從檔案選取';

  @override
  String get openLockedPassword => '密碼';

  @override
  String get openLockedThePasswordIsChecked =>
      '會先檢查密碼。確認之後，Kryfo 才會詢問要把開啟的檔案放在哪裡，然後直接存到那裡。';

  @override
  String get openLockedOpened2 => '已開啟。';

  @override
  String get openLockedSavedWhereYouChose => '已儲存到你選擇的位置。';

  @override
  String get pairCodePairingCode => '配對碼';

  @override
  String get pairCodeShowACode => '顯示配對碼';

  @override
  String get pairCodeEnterOne => '輸入配對碼';

  @override
  String get pairCodeSixDigits => '六位數字';

  @override
  String get pairCodeLooking => '尋找中…';

  @override
  String get pairCodeNothingThereYetTrying => '那裡還沒有東西 · 正在重試';

  @override
  String get pairCodeNothingAtThatCode => '這組碼沒有對應任何東西。它可能已經焚毀，或對方還沒分享。';

  @override
  String get pairCodeTypeTheSixDigits => '輸入對方唸出的六位數字。';

  @override
  String get pairCodeAddThem => '新增對方';

  @override
  String get panicSetupThoseWereDifferentFrom => '兩次不一樣。從頭再來。';

  @override
  String get panicSetupOnceMore => '再一次';

  @override
  String get panicSetupTheSameFourDigits => '再輸入一次同樣的數字';

  @override
  String get photoKnowsEverythingInside => '裡面的一切';

  @override
  String get photoKnowsVideo => '影片';

  @override
  String get photoKnowsPhoto => '照片';

  @override
  String get photoKnowsWhatThisVideoKnows => '這段影片知道什麼';

  @override
  String get photoKnowsWhatThisPhotoKnows => '這張照片知道什麼';

  @override
  String get photoKnowsRemoveAllOfIt => '全部移除';

  @override
  String get photoKnowsKeepItAsIt => '保持原樣';

  @override
  String get photoKnowsReadOnThisPhone => '在這支手機上讀取 · 影片沒有傳到任何地方';

  @override
  String get photoKnowsReadOnThisPhoneThePhoto => '在這支手機上讀取 · 照片沒有傳到任何地方';

  @override
  String get photoKnowsReadingTheFile => '正在讀取檔案';

  @override
  String photoKnowsOf(Object prettySize, Object prettySize2) {
    return '$prettySize/$prettySize2';
  }

  @override
  String get photoKnowsEverythingStaysOnThis => '一切都留在這支手機上。';

  @override
  String photoKnowsMapWithAPin(Object place) {
    return '有標記的地圖。$place';
  }

  @override
  String get photoKnowsDrawnOffline => '離線繪製';

  @override
  String photoKnowsShowEverything(Object title) {
    return '$title。顯示全部';
  }

  @override
  String get pinsAppLock => '應用程式鎖';

  @override
  String get pinsYourPin => '你的 PIN 碼';

  @override
  String get commonOn => '開啟';

  @override
  String get commonOff => '關閉';

  @override
  String get pinsOpensKryfoFourDigits => '用來開啟 Kryfo。每次 Kryfo 回到前景時都會詢問。';

  @override
  String get pinsChangePin => '變更 PIN 碼';

  @override
  String get pinsSetAPin => '設定 PIN 碼';

  @override
  String get pinsTurnOff => '關閉';

  @override
  String get pinsTurnOffTheApp => '要關閉應用程式鎖嗎？';

  @override
  String get pinsThePinGoesAnd =>
      'PIN 碼會被移除，清除 PIN 和所有隱藏聊天也會一起移除。任何拿著你手機的人，都能以你的身分開啟 Kryfo。';

  @override
  String get pinsUnlockWithFingerprint => '用指紋解鎖';

  @override
  String get pinsWipePin => '清除 PIN';

  @override
  String get pinsNeedsAPinFirst => '需要先設定 PIN 碼';

  @override
  String get pinsSet => '已設定';

  @override
  String get pinsChangeWipePin => '變更清除 PIN';

  @override
  String get pinsSetAWipePin => '設定清除 PIN';

  @override
  String get pinsRemove => '移除';

  @override
  String get pinsRemoveTheWipePin => '要移除清除 PIN 嗎？';

  @override
  String get pinsTheLockScreenKeeps => '鎖定畫面會保留你的 PIN 碼。清除 PIN 將不再有任何作用。';

  @override
  String profileCopied(Object what) {
    return '已複製 $what';
  }

  @override
  String get profileProfile => '個人檔案';

  @override
  String get profileChangeYourFace => '更換你的臉';

  @override
  String get profileKryfoId => 'Kryfo ID';

  @override
  String get profileOnionAddress => 'Onion 位址';

  @override
  String get profileSupporterBadge => '支持者徽章';

  @override
  String profileYouAreAThank(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter': '你是支持者。謝謝你。',
      'patron': '你是贊助人。謝謝你。',
      'guardian': '你是守護者。謝謝你。',
      'other': '你是支持者。謝謝你。',
    });
    return '$_temp0';
  }

  @override
  String get profileShowMyBadge => '顯示我的徽章';

  @override
  String get profileOnMyOwnScreens => '在我自己的畫面上';

  @override
  String get profileLetContactsSeeIt => '讓聯絡人看到';

  @override
  String get profileOffByDefault => '預設關閉';

  @override
  String get profileShareConnect => '分享與聯繫';

  @override
  String get profileMyKryfoCode => '我的 Kryfo QR 碼';

  @override
  String get profileAddContact => '新增聯絡人';

  @override
  String get profileGiveAgain => '再捐一次';

  @override
  String get profileSupportKryfo => '支持 Kryfo';

  @override
  String get profileKryfoRunsOnWhat => 'Kryfo 靠大家的捐助運作';

  @override
  String get profileKeepKryfoIndependent => '讓 Kryfo 保持獨立';

  @override
  String get qrLink => '連結';

  @override
  String get qrYourLinkAsTyped => '就是你輸入的連結 · 沒有追蹤轉址';

  @override
  String get qrText => '文字';

  @override
  String get qrStaysInTheCode => '內容只在 QR 碼裡 · 沒有伺服器保存它';

  @override
  String get qrWiFi => 'Wi-Fi';

  @override
  String get qrMadeOnThisPhone => '在這支手機上產生 · 沒有任何網站看過密碼';

  @override
  String get qrNetworkName => '網路名稱';

  @override
  String get qrPassword => '密碼';

  @override
  String get qrContact => '聯絡人';

  @override
  String get qrOnlyWhatYouType => '只有你輸入的內容 · 不含通訊錄中的任何資料';

  @override
  String get qrName => '姓名';

  @override
  String get qrPhone => '電話';

  @override
  String get qrEmail => '電子郵件';

  @override
  String get qrOpensTheirMailApp => '開啟對方的郵件應用程式 · 不會從這裡寄出任何東西';

  @override
  String get qrTo => '收件人';

  @override
  String get qrSubject => '主旨';

  @override
  String get qrANumberNothingElse => '只有號碼 · 沒有其他東西';

  @override
  String get qrNumber => '號碼';

  @override
  String get qrSms => 'SMS';

  @override
  String get qrOpensTheirMessagesApp => '開啟對方的簡訊應用程式 · 不會從這裡傳送任何東西';

  @override
  String get qrMessage => '訊息';

  @override
  String get qrLocation => '位置';

  @override
  String get qrCoordinatesOnlyNoMap => '只有座標 · 沒有詢問任何地圖服務';

  @override
  String get qrLatitude => '緯度';

  @override
  String get qrLongitude => '經度';

  @override
  String get qrBitcoin => 'Bitcoin';

  @override
  String get qrAddressAndAmountNo => '地址和金額 · 中間沒有任何付款網站';

  @override
  String get qrAddress => '地址';

  @override
  String get qrAmountInBtc => '金額（BTC）';

  @override
  String get qrInk => '墨色';

  @override
  String get qrAmber => '琥珀';

  @override
  String get qrViolet => '紫羅蘭';

  @override
  String get qrCouldNotDrawThe => '無法繪製圖片。';

  @override
  String get qrSavedToYourGallery => '已儲存到你的相簿';

  @override
  String get qrCouldNotSaveIt => '無法儲存。請確認手機還有空間。';

  @override
  String get qrNoAppOnThis => '這支手機上沒有任何應用程式接收這張圖片。';

  @override
  String get qrTooMuchForOne => '內容太多，一個 QR 碼放不下。請縮短一點。';

  @override
  String get qrThisIsALot => '對一個 QR 碼來說，這內容很多。較舊的相機可能讀不出來。';

  @override
  String get qrPrivateQrCode => '私密 QR 碼';

  @override
  String get qrColour => '顏色';

  @override
  String get qrCopiedItLeavesThe => '已複製。一分鐘後會從剪貼簿移除';

  @override
  String get qrSecurity => '安全性';

  @override
  String get qrNone => '無';

  @override
  String get qrSaveImage => '儲存圖片';

  @override
  String qrColour2(Object name) {
    return '顏色：$name';
  }

  @override
  String get qrTypeBelowAndThe => '在下方輸入，\nQR 碼就會自動產生';

  @override
  String get qrQrCode => 'QR 碼';

  @override
  String get qrHidePassword => '隱藏密碼';

  @override
  String get qrShowPassword => '顯示密碼';

  @override
  String get qrCopyPassword => '複製密碼';

  @override
  String get requestsSentAnAttachment => '傳送了一個附件';

  @override
  String get requestsWantsToConnect => '想和你聯繫';

  @override
  String get requestsAccepted => '已接受';

  @override
  String requestsBlock(Object id) {
    return '要封鎖 $id 嗎？';
  }

  @override
  String get requestsNothingMoreFromThem => '對方的任何東西都不會再送到你這裡。對方的請求和其中的訊息都會刪除。';

  @override
  String get requestsBlocked => '已封鎖';

  @override
  String get requestsDeleted => '已刪除';

  @override
  String get requestsRequests => '請求';

  @override
  String get requestsNoRequests => '沒有請求';

  @override
  String get requestsMessagesFromPeopleYou => '你還沒新增的人傳來的訊息，會先出現在這裡。';

  @override
  String get requestsLooksSafeNothingSuspicious => '看起來安全 · 對方的第一則訊息沒有可疑之處';

  @override
  String get commonAccept => '接受';

  @override
  String get requestsDecline => '拒絕';

  @override
  String get restoreThatFileIsNot => '這個檔案不是 Kryfo 備份';

  @override
  String get restoreThisFileIsDamaged => '這個檔案已損毀，無法讀取';

  @override
  String get restoreTypeThePassphraseThe => '輸入建立這個檔案時使用的密碼短語';

  @override
  String get restoreReplaceTheAccountOn => '要取代這支手機上的帳號嗎？';

  @override
  String get restoreWhatIsHereNow =>
      '這裡現有的一切，包括身分、聯絡人和訊息，都會消失。檔案內容會取而代之。這個動作無法復原。';

  @override
  String get restoreReplaceIt => '取代';

  @override
  String restoreCouldNotBeReleased(Object mine) {
    return '無法釋出 @$mine';
  }

  @override
  String restoreTheRegistryDidNot(Object mine) {
    return '註冊處沒有回應。如果你繼續，@$mine 會一直指向這支手機即將失去的身分。任何新增它的人，訊息都會傳給一個不存在的人，而且這個名稱無法再被認領。最好先連上網路，再試一次。';
  }

  @override
  String get restoreRestoreAnyway => '仍要還原';

  @override
  String get restoreNotYet => '先不要';

  @override
  String get restoreRestored => '已還原';

  @override
  String restoreKryfoWillCloseNow(Object haloId) {
    return 'Kryfo 現在會關閉。點一下圖示，以 $haloId 重新開啟。';
  }

  @override
  String get restoreReopenKryfo => '重新開啟 Kryfo';

  @override
  String get restoreTheRestoreDidNot => '還原沒有完成。沒有做任何變更';

  @override
  String get restoreThisIdentity => '這個身分';

  @override
  String get restoreMoveYourKryfoHere => '把你的 Kryfo 搬到這裡';

  @override
  String restoreThisBackupIsRestoring(Object name) {
    return '這份備份是 $name。還原後，那個身分會搬到這台裝置上。';
  }

  @override
  String restoreThisBackupMadeOn(Object name, Object date, Object time) {
    return '這份備份是 $name，建立於 $date $time。還原後，那個身分會搬到這台裝置上。';
  }

  @override
  String restoreItHoldsOfPhotos(Object mb) {
    return '其中包含 $mb 的照片、語音和檔案。這可能需要幾分鐘。請保持應用程式開啟。';
  }

  @override
  String get restoreWhatFollows => '會帶過來的';

  @override
  String get restoreYourNameYourCode => '你的名字、你的 QR 碼，以及每位聯絡人。';

  @override
  String get restoreEveryConversationBackTo => '每段對話，從最開始到現在。';

  @override
  String get restoreYourPhotosVoiceNotes => '你的照片、語音和檔案。';

  @override
  String restoreYourPhotosVoiceNotesCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '你的照片、語音和檔案 · $countString。',
    );
    return '$_temp0';
  }

  @override
  String get restoreYourOnionAddressSo => '你的 onion 位址，讓直接聯絡你的人仍然聯絡得到你。';

  @override
  String get restoreAnythingSentToYou => '舊手機關機時傳給你的任何內容（傳送後十四天內）。';

  @override
  String get restoreYourSupporterBadgeIf => '你的支持者徽章（如果有的話）。';

  @override
  String get restoreWhatDoesnT => '不會帶過來的';

  @override
  String get restoreTheOldPhoneStops =>
      '你一從這裡傳送任何東西，舊手機就會停止接收。不是慢慢停止。你從這台裝置傳出的第一則訊息，就是舊手機最後能跟上的一則；之後送到舊手機的任何內容，在那裡都無法讀取，也不會在這裡等你。';

  @override
  String get restoreIfThePhoneThis =>
      '如果這個檔案原本所在的手機還在使用，請先在那支手機上停止使用 Kryfo，再繼續。兩支手機共用一個 Kryfo，兩邊都會遺失訊息。';

  @override
  String get restoreNotificationsNeedSettingUp => '需要在這台裝置上重新設定通知。';

  @override
  String get restoreMoveItHere => '搬到這裡';

  @override
  String get restoreNotNow => '以後再說';

  @override
  String get restoreRestore => '還原';

  @override
  String get restoreFromABackupFile => '從備份檔案';

  @override
  String get restoreABackupBringsBack =>
      '備份會找回你的身分和聯絡人，以及建立檔案時手機上的訊息。之後說的任何話都不在裡面。';

  @override
  String get restoreTheFile => '檔案';

  @override
  String get restorePickTheBackupFile => '選擇備份檔案';

  @override
  String get restoreThePassphrase => '密碼短語';

  @override
  String get restoreTheOneTheFile => '建立檔案時使用的那一組';

  @override
  String get restoreWhatComesBack => '會找回的內容';

  @override
  String get restoreChecking => '檢查中…';

  @override
  String get restoreCheckTheFile => '檢查檔案';

  @override
  String get restoreReleasingYourHandle => '正在釋出你的使用者名稱…';

  @override
  String restoreMoving(Object progress) {
    return '搬移中… $progress';
  }

  @override
  String get restoreRestoring => '還原中…';

  @override
  String get restoreNotThisOne => '不是這個';

  @override
  String get restoreDateUnknown => '日期不明';

  @override
  String get restoreAnIdentity => '一個身分';

  @override
  String get restoreMessagesSentOrReceived => '在那個日期之後傳送或收到的訊息，不在這個檔案裡。';

  @override
  String restoreGb(Object bytes) {
    return '$bytes GB';
  }

  @override
  String restoreMb(Object bytes) {
    return '$bytes MB';
  }

  @override
  String get roomCreateCouldNotCreateThe => '無法建立聊天室';

  @override
  String get roomCreateBurnerRoom => '臨時聊天室';

  @override
  String get roomCreateARoomThatEnds =>
      '一個會結束的聊天室。每個人都用專為它產生的金鑰加入，結束時，任何手機上都不會留下任何東西。';

  @override
  String get roomCreateRoomName => '聊天室名稱';

  @override
  String get roomCreateEndsAfter => '多久後結束';

  @override
  String get roomCreateMemberCap => '人數上限';

  @override
  String roomCreateNoOnePastThe(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '只限前 $countString 位',
    );
    return '$_temp0';
  }

  @override
  String get roomCreateOffAnyoneWithThe => '關閉。任何有連結的人都能加入';

  @override
  String roomCreateThisRoomAndEverything(Object expiryWords) {
    return '這個聊天室和裡面的一切都會在 $expiryWords後消失';
  }

  @override
  String get roomCreateCreating => '建立中…';

  @override
  String get roomCreateCreateRoom => '建立聊天室';

  @override
  String get roomLinkSendTheRoomTo => '把聊天室傳給';

  @override
  String get roomLinkTheyWillKnowThis =>
      '對方會知道這個聊天室是你傳的。在聊天室裡，對方和其他人一樣，只是一把金鑰。';

  @override
  String get roomLinkNoContactsYet => '還沒有聯絡人';

  @override
  String roomLinkEndsIn(Object time) {
    return '$time後結束';
  }

  @override
  String get roomLinkAnyoneWithThisCan =>
      '在聊天室結束之前，任何持有這個連結的人都能加入。他們會用專為這個聊天室產生的金鑰進入，也看不到他們加入之前傳送的任何內容。';

  @override
  String get roomLinkRoomLinkCopied => '已複製聊天室連結';

  @override
  String get roomLinkSendToAContact => '傳給聯絡人';

  @override
  String get roomLinkCopyRoomLink => '複製聊天室連結';

  @override
  String get savedVoiceNote => '語音';

  @override
  String get savedPhoto => '照片';

  @override
  String get savedSaved => '收藏';

  @override
  String get savedNothingSavedYet => '還沒有收藏任何東西';

  @override
  String get savedLongPressAnyMessage => '長按任何訊息，再點「儲存」，就能收藏在這裡。';

  @override
  String get savedViewInChat => '在聊天中查看';

  @override
  String get savedPhoto2 => '照片';

  @override
  String get scanThatSNotA => '這不是 Kryfo QR 碼 · 請繼續對準';

  @override
  String get scanScanAKryfoQr => '掃描 Kryfo QR 碼';

  @override
  String get scanFlash => '閃光燈';

  @override
  String get scanPointAtAKryfo => '對準 Kryfo QR 碼 · 不會有任何東西離開你的手機';

  @override
  String get seenWhatWeCanSee => '我們看得到什麼';

  @override
  String get seenEveryMessengerClaimsPrivacy =>
      '每個通訊軟體都說自己重視隱私。這是按照傳送路線列出的具體清單，包括對我們不利的部分。點一列就能看到原因。';

  @override
  String get seenHonestAboutTheLast =>
      '老實說最後幾列：應用程式鎖、清除 PIN 和加密儲存正是為此而設；如果有人拿著你已解鎖的手機，沒有任何工具救得了你。完整的威脅模型在程式碼庫的 THREAT_MODEL.md 裡，依據 LINDDUN 撰寫。程式碼是公開的，所以這些都不必靠信任。';

  @override
  String get seenHidden => '隱藏';

  @override
  String get seenNever => '從不';

  @override
  String get seenOnDevice => '在裝置上';

  @override
  String get seenYours => '你的';

  @override
  String get seenUnaudited => '未經稽核';

  @override
  String get seenWhoYouTalkTo => '你在跟誰聊天';

  @override
  String get seenEachConversationGetsIts =>
      '每段對話都有自己的位址，由雙方的金鑰推導而來。中繼看到的是一個個互不相關的投遞點，而不是一對人。';

  @override
  String get seenWhatYouSay => '你說了什麼';

  @override
  String get seenEndToEndEncrypted =>
      '使用 Signal 雙棘輪演算法端對端加密，再以 gift wrap 包裝密封一次。就算我們想讀，也讀不到。';

  @override
  String get seenYourIpAddress => '你的 IP 位址';

  @override
  String get seenOurRelay => '我們的中繼';

  @override
  String get seenEveryRelay => '每個中繼';

  @override
  String get seenOnOnionEverythingLeaves =>
      '在 Onion 模式下，一切都經由 tor 送出，中繼看到的是出口節點，永遠不會是你。在中繼模式下，連線會直接連到我們自己的中繼：沒有任何東西會轉送你的位址，也不會留下任何紀錄，但這條連線我們看得到。在快速模式下，每個公共中繼都會知道你連線了，但不知道你和誰聯絡，也不知道你說了什麼。';

  @override
  String get seenYourContactGraph => '你的聯絡人關係圖';

  @override
  String get seenKryfoDoesNotScan => 'Kryfo 不會掃描你的通訊錄。這正是重點。這裡根本沒有手機號碼可以外洩。';

  @override
  String get seenIntroducer => '介紹人';

  @override
  String get seenWhenAContactIntroduces =>
      '當聯絡人介紹你認識某人時，那位聯絡人會知道你們兩個現在有聯繫。其他人都不會知道。中繼看到的是密文，也沒有任何伺服器看得到關係圖。';

  @override
  String get seenTheScamShield => '防詐盾';

  @override
  String get seenRunsOnYourPhone =>
      '在你的手機上執行，使用應用程式內建的規則。不連網路，也不下載任何清單。它只會讀取陌生人的第一則訊息，看不到聯絡人傳給你的任何內容。';

  @override
  String get seenBurnerRooms => '臨時聊天室';

  @override
  String get seenRoomKeys => '聊天室金鑰';

  @override
  String get seenYouJoinARoom =>
      '你用專為聊天室產生的金鑰加入，所以裡面的人得不到任何能在別處使用的資訊。晚加入的人看不到之前的紀錄。到期時，金鑰、訊息和媒體都會被銷毀。';

  @override
  String get seenLinkPreviews => '連結預覽';

  @override
  String get seenOverTor => '經由 Tor';

  @override
  String get seenAPreviewIsFetched =>
      '預覽由傳送者經由 tor 擷取，並包在加密訊息中傳送。接收的手機不會發出任何請求。網站只會知道有個使用 tor 的人要求了一個頁面，除此之外一無所知。永遠不會載入任何圖片，陌生人傳來的連結也只會顯示為純文字。';

  @override
  String get seenASeizedUnlockedPhone => '被扣押的已解鎖手機';

  @override
  String get seenIfSomeoneHoldsYour =>
      '如果有人拿著你已解鎖的手機，他們就能讀你的訊息。應用程式鎖、清除 PIN 和加密儲存能在那之前幫上忙，在那之後就不行了。';

  @override
  String get seenTheCryptoItself => '加密技術本身';

  @override
  String get seenTheRatchetAndStorage =>
      '棘輪和儲存層都是標準做法。連接兩者的那一層是我們自己寫的，還沒有任何獨立的第三方審查過。請把它當作 alpha 版本，因為它確實是。';

  @override
  String get seenOnion => 'Onion';

  @override
  String get seenRelay => '中繼';

  @override
  String get seenFast => '快速';

  @override
  String get settingsWipeKryfo => '要清除 Kryfo 嗎？';

  @override
  String get settingsIdentityMessagesContactsAnd =>
      '這支手機上的身分、訊息、聯絡人和設定。除非你有備份，否則會永久消失。';

  @override
  String get commonContinue => '繼續';

  @override
  String settingsTypeWipeToConfirm(Object word) {
    return '輸入「$word」以確認';
  }

  @override
  String get settingsTheLastStepNothing => '最後一步。什麼都不會留下。';

  @override
  String get settingsWipeWord => '清除';

  @override
  String get settingsWipeKryfo2 => '清除 Kryfo';

  @override
  String get settingsYourProtections => '你的防護';

  @override
  String get settingsTorRouting => 'Tor 路由';

  @override
  String get settingsConnecting => '連線中';

  @override
  String get settingsOffMode => '關閉 · 中繼模式';

  @override
  String get settingsOffFastMode => '關閉 · 快速模式';

  @override
  String get settingsAppLock => '應用程式鎖';

  @override
  String get settingsBlockedByAndroid => '被 Android 阻擋';

  @override
  String get settingsSpeedPrivacy => '速度與隱私';

  @override
  String get settingsFast => '快速';

  @override
  String get settingsRelay1Hop => '中繼 · 1 跳';

  @override
  String get settingsOnion3Hops => 'Onion · 3 跳';

  @override
  String get settingsBridges => '橋接';

  @override
  String get settingsForNetworksThatBlock => '適用於封鎖 tor 的網路';

  @override
  String get settingsGettingMessages => '接收訊息';

  @override
  String settingsPreviewHidden(Object deliveryModeName) {
    return '$deliveryModeName · 隱藏預覽';
  }

  @override
  String settingsPreviewShown(Object deliveryModeName) {
    return '$deliveryModeName · 顯示預覽';
  }

  @override
  String get settingsRunInBackground => '在背景執行';

  @override
  String get settingsSoMessagesArrive => '讓訊息能送達';

  @override
  String get settingsTransport => '傳輸';

  @override
  String get settingsWhatTheNetworkIs => '網路目前的狀況';

  @override
  String get settingsBlocked => '已封鎖';

  @override
  String get settingsAcceptIntroductions => '接受介紹';

  @override
  String get settingsFriendsCanIntroduceYou => '朋友可以把你介紹給他們的朋友';

  @override
  String get settingsScamShield => '防詐盾';

  @override
  String get settingsChecksStrangersOnYour => '在你的手機上檢查陌生人。不會有任何東西離開手機';

  @override
  String get settingsBlockScreenshots => '禁止截圖';

  @override
  String get settingsWholeAppHiddenFrom => '在最近使用畫面和截圖中隱藏整個應用程式 · 下次啟動後生效';

  @override
  String get settingsWholeAppHiddenFromRecentsAnd => '在最近使用畫面和截圖中隱藏整個應用程式';

  @override
  String get settingsOnNextStart => '開啟 · 下次啟動';

  @override
  String get settingsOffNextStart => '關閉 · 下次啟動';

  @override
  String get settingsLightTheme => '淺色主題';

  @override
  String get settingsSameProtectionBrighter => '同樣的防護，更明亮';

  @override
  String get settingsAppLock2 => '應用程式鎖';

  @override
  String get settingsYourPinAndA => '你的 PIN 碼和進階保護';

  @override
  String get settingsPinWipePin => 'PIN 碼 · 清除 PIN';

  @override
  String get settingsBackUpIdentity => '備份身分';

  @override
  String get settingsEncryptedFile => '加密檔案';

  @override
  String get settingsRestoreFromBackup => '從備份還原';

  @override
  String get settingsReplaceCurrent => '取代目前的';

  @override
  String get settingsDisguiseVoice => '變聲';

  @override
  String get settingsShiftsYourPitchBefore => '在語音送出前改變你的音調';

  @override
  String get settingsWhyKryfo => '為什麼選 Kryfo';

  @override
  String get settingsHowItProtectsYou => '它如何保護你';

  @override
  String get settingsResetMyInviteLink => '重設我的邀請連結';

  @override
  String get settingsOldLinksAndCodes => '舊的連結和 QR 碼會對所有人失效';

  @override
  String get settingsResetInviteLink => '要重設邀請連結嗎？';

  @override
  String get settingsAnyoneWithAnOld =>
      '持有舊 QR 碼或連結的人，無論透過哪種路線，都將無法再聯絡你。拿到了但從沒用過的人，需要你再給一個新的。聯絡人、聊天和紀錄都會保留。';

  @override
  String get settingsReset => '重設';

  @override
  String get settingsInviteResetShareThe => '邀請已重設 · 分享新的 QR 碼';

  @override
  String get settingsWhatWeCanSee => '我們看得到什麼';

  @override
  String get settingsTheHonestList => '誠實清單';

  @override
  String get settingsVersion => '版本';

  @override
  String get settings030Alpha => '0.4.1 · alpha 版';

  @override
  String get settingsReportAnIssue => '回報問題';

  @override
  String get settingsBugOrSecurityFlaw => '錯誤或安全漏洞';

  @override
  String get settingsOpenSource => '開放原始碼';

  @override
  String get settingsLinkCopied => '已複製連結';

  @override
  String get settingsTheOfflineMapIn =>
      '「工具」中的離線地圖以 Natural Earth（公有領域）繪製。城鎮名稱來自 GeoNames（geonames.org），採用 CC BY 4.0 授權。';

  @override
  String get settingsNotIndependentlyAuditedPre =>
      '尚未經過獨立稽核。目前是 pre-alpha 版：適合測試，還不適合高風險用途。';

  @override
  String get settingsDangerZone => '危險區域';

  @override
  String get settingsWipeKryfoFromThis => '從這支手機清除 Kryfo';

  @override
  String get shieldCheckedOnThisPhone => '在這支手機上檢查。沒有傳送任何東西到任何地方。';

  @override
  String get toolsMoreTools => '更多工具';

  @override
  String get toolsCleanAPhotoOr => '清理照片或影片';

  @override
  String get toolsOrShareOneTo => '或從相簿分享到 Kryfo';

  @override
  String get toolsMakeAPrivateQr => '製作私密 QR 碼';

  @override
  String get toolsLinksWiFiContacts => '連結、Wi-Fi、聯絡人等等。離線製作';

  @override
  String get toolsLockAFile => '鎖定檔案';

  @override
  String get toolsWithAPasswordOpens => '用密碼鎖定。任何有 age 的地方都能開啟';

  @override
  String get toolsOpenALockedFile => '開啟鎖定的檔案';

  @override
  String get toolsAnyAgeFileSomeone => '別人傳給你的任何 .age 檔案';

  @override
  String get toolsWorksOfflineNoContacts => '離線可用 · 不需要聯絡人';

  @override
  String get toolsUsefulFrom => '打開就能用，';

  @override
  String get toolsTheFirstMinute => '從第一分鐘開始。';

  @override
  String get toolsEverythingHereHappensOn =>
      '這裡的一切都在這支手機上進行。不會上傳任何東西，其他人也不必使用 Kryfo。';

  @override
  String get toolsWhatDoesThisPhoto => '這張照片知道些什麼？';

  @override
  String get toolsPlacePhoneTime => '地點 · 手機 · 時間';

  @override
  String get toolsPickAPhotoAnd => '選一張照片，看看它洩漏了什麼。然後保留一份乾淨的副本。';

  @override
  String get toolsPickAPhoto => '選擇照片';

  @override
  String get toolsVideo => '影片';

  @override
  String get transportTransport => '傳輸';

  @override
  String get transportNothingHereLeavesThe =>
      '這裡的任何內容都不會離開手機。這就是引擎用來決定下一步的同一份狀態。';

  @override
  String get transportStayingAlive => '保持運作';

  @override
  String get transportCanSend => '可以傳送';

  @override
  String get commonYes => '是';

  @override
  String get transportNotYet => '還沒';

  @override
  String get transportOnline => '在線';

  @override
  String get transportOffline => '離線';

  @override
  String get transportQueuedToSend => '待傳送';

  @override
  String get transportOnionPublished => 'Onion 已發布';

  @override
  String transportYes(Object uploads) {
    return '是（$uploads）';
  }

  @override
  String transportTryingS(Object pubFor) {
    return '已嘗試 $pubFor 秒';
  }

  @override
  String transportBenchedS(Object r) {
    return '暫停使用 $r 秒';
  }

  @override
  String transportFails(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 次失敗',
    );
    return '$_temp0';
  }

  @override
  String get transportOk => '正常';

  @override
  String get transportRelaySubscriptions => '中繼訂閱';

  @override
  String get transportLastSent => '上次傳送';

  @override
  String get transportNever => '從未';

  @override
  String transportSAgo(Object sx) {
    return '$sx 秒前';
  }

  @override
  String get transportLastReceived => '上次接收';

  @override
  String transportSAgo2(Object rx) {
    return '$rx 秒前';
  }

  @override
  String get transportWithNoContactsThe =>
      '沒有聯絡人時，應用程式不會訂閱任何中繼位址，所以任何訊息都無法送達你。掃描某人的 QR 碼就能解決。';

  @override
  String get transportSendAnythingWaitingNow => '立即傳送所有等待中的內容';

  @override
  String get transportOff => '關閉';

  @override
  String get transportStarting => '啟動中';

  @override
  String get transportBootstrapped => '已完成啟動';

  @override
  String get transportPublishingAddress => '正在發布位址';

  @override
  String get transportReachable => '可連線';

  @override
  String get transportOurRelayOnion => '我們的中繼（onion）';

  @override
  String get transportNever2 => '從未';

  @override
  String get transportJustNow => '剛剛';

  @override
  String transportMAgo(Object inMinutes) {
    return '$inMinutes 分鐘前';
  }

  @override
  String transportHAgo(Object inHours) {
    return '$inHours 小時前';
  }

  @override
  String transportDAgo(Object inDays) {
    return '$inDays 天前';
  }

  @override
  String transportM(Object inMinutes) {
    return '$inMinutes 分鐘';
  }

  @override
  String transportHM(Object inHours, Object d) {
    return '$inHours 小時 $d 分';
  }

  @override
  String transportD(Object inDays) {
    return '$inDays 天';
  }

  @override
  String transportMb(Object b) {
    return '$b MB';
  }

  @override
  String get transportYesCheckedJustNow => '是 · 剛剛檢查過';

  @override
  String transportNoLast(Object ago) {
    return '否 · 上次：$ago';
  }

  @override
  String get transportLastMessageIn => '上次收到訊息';

  @override
  String get transportBatteryExemption => '電池最佳化豁免';

  @override
  String get transportUnknown => '不明';

  @override
  String get transportExempt => '已豁免';

  @override
  String get transportNotExemptTapTo => '未豁免 · 點一下修正';

  @override
  String get transportProcessUp => '程序運作';

  @override
  String get transportLastStop => '上次停止';

  @override
  String transportEngine(Object mb, Object mb2) {
    return '$mb · 引擎 $mb2';
  }

  @override
  String get transportLastRelayArrival => '上次從中繼收到';

  @override
  String get transportLastCheckIn => '上次查收';

  @override
  String get transportNoneYet => '還沒有';

  @override
  String get transportLastTorReconnect => '上次 Tor 重新連線';

  @override
  String get transportCatchUpByRelay => '各中繼補收';

  @override
  String get transportControlPort => '控制埠';

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
      other: '$dialsString 次連線',
    );
    String _temp1 = intl.Intl.pluralLogic(
      timeouts,
      locale: localeName,
      other: '$timeoutsString 次逾時',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get transportJobRuns => '排程執行次數';

  @override
  String transportLast(Object jobRuns, Object ago) {
    return '$jobRuns · 上次：$ago';
  }

  @override
  String get transportQuietStretches => '靜默時段';

  @override
  String get transportNone => '無';

  @override
  String get transportClearThisRecord => '清空這份紀錄';

  @override
  String get transportNothingYetThisProcess => '這次執行還沒有紀錄';

  @override
  String transportM2(Object mins) {
    return '$mins 分鐘';
  }

  @override
  String transportHM2(Object mins, Object mins2) {
    return '$mins 小時 $mins2 分';
  }

  @override
  String transportTo(Object t, Object t2) {
    return '$t 到 $t2';
  }

  @override
  String vouchersVouchedBy(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 位擔保人',
      one: '擔保人',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperAtmosphere => '氛圍';

  @override
  String get wallpaperJustForYouThey => '只有你看得到。對方看到的是自己的。';

  @override
  String get wallpaperYourPhoto => '你的照片';

  @override
  String get wallpaperFromYourPhotos => '從你的相簿';

  @override
  String get wallpaperKeepIt => '保留';

  @override
  String get whyKryfoWhyKryfo => '為什麼選 Kryfo';

  @override
  String get whyKryfoKryfoKreeFoGreek =>
      'Kryfo · KREE-fo · 希臘文「隱藏」的意思。\n一個安靜的聊天空間，打造成沒有任何人在監看。';

  @override
  String get whyKryfoRoutedThroughTor => '經由 tor 路由';

  @override
  String get whyKryfoByDefaultEveryMessage =>
      '預設情況下，每則訊息都經由 tor（一連串的中繼）傳送。沒有人，不論是我們還是你的網路，能看到你在跟誰聊天，或你在哪裡。';

  @override
  String get whyKryfoEndToEndEncrypted => '端對端加密';

  @override
  String get whyKryfoMessagesAreSealedWith => '訊息用只有你和對方持有的金鑰密封。就算我們想讀，也讀不到。';

  @override
  String get whyKryfoNoServersHoldingYour => '沒有伺服器掌握你的生活';

  @override
  String get whyKryfoNoAccountNoPhone =>
      '沒有帳號，沒有手機號碼，也沒有儲存你聊天內容的中央伺服器。聊天內容存在這支手機上，並以加密方式存放。';

  @override
  String get whyKryfoNothingLeaks => '什麼都不外洩';

  @override
  String get whyKryfoNoReadReceiptsOr =>
      '不會把已讀回條或正在輸入的提示交給任何人，也不會上傳聯絡人清單。中繼資料是大多數應用程式會外洩的東西，而 Kryfo 的設計就是不外洩。';

  @override
  String get whyKryfoVerifyItIsReally => '確認真的是對方';

  @override
  String get whyKryfoCompareASafetyNumber =>
      '當面或透過你信任的管道比對安全碼，就能確定沒有人在冒充你的聯絡人。';

  @override
  String get whyKryfoTheHonestPart => '老實說';

  @override
  String get whyKryfoKryfoIsPreAlpha =>
      'Kryfo 還在 pre-alpha 階段，也還沒經過稽核。加密技術是真的，但還沒有外部專家檢查過，所以請把它當作開發中的作品，暫時還不能把性命託付給它。';

  @override
  String get cleanerLocation => '位置';

  @override
  String get cleanerAlreadyBlankedByAndroid => '已被 Android 清空';

  @override
  String get cleanerPhoneModel => '手機型號';

  @override
  String get cleanerTimeTaken => '拍攝時間';

  @override
  String get cleanerSerialNumber => '序號';

  @override
  String get cleanerOwnerName => '擁有者名稱';

  @override
  String get cleanerHiddenThumbnail => '隱藏的縮圖';

  @override
  String get cleanerContentCredentials => '內容憑證';

  @override
  String get cleanerDataAfterThePicture => '圖片之後的資料';

  @override
  String cleaner1OtherField(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '其他 $countString 個欄位',
    );
    return '$_temp0';
  }

  @override
  String get lockWordsFourRandomWordsBeat => '四個隨機的詞，勝過一個聰明的詞。';

  @override
  String lockWordsTooShortAtLeast(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '太短了。至少要 $countString 個字元。',
    );
    return '$_temp0';
  }

  @override
  String get lockWordsWeakWhoeverGetsThe => '弱。拿到檔案的人想猜多快就能猜多快。';

  @override
  String get lockWordsFairLongerIsStronger => '普通。越長越強。';

  @override
  String get lockWordsStrongFourRandomWords => '強。四個隨機的詞，勝過一個聰明的詞。';

  @override
  String photoStoryKm(Object m) {
    return '$m 公里';
  }

  @override
  String photoStory1Metre(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 公尺',
    );
    return '$_temp0';
  }

  @override
  String get photoStoryFarFromAnyTown => '遠離任何城鎮';

  @override
  String photoStoryNear(Object where) {
    return '$where 附近';
  }

  @override
  String photoStoryAboutKmFrom(Object near, Object where) {
    return '距離 $where 約 $near 公里';
  }

  @override
  String photoStoryS(Object s) {
    return '$s 秒';
  }

  @override
  String photoStory1S(Object s) {
    return '1/$s 秒';
  }

  @override
  String get photoStoryNotAKindKryfo => '這不是 Kryfo 能讀取的格式。';

  @override
  String get photoStorySoItWillNot => '所以它不會亂猜。';

  @override
  String get photoStoryThisFileIsDamaged => '這個檔案已損毀或不完整。';

  @override
  String get photoStoryKryfoCouldNotRead => 'Kryfo 無法完整讀到結尾。';

  @override
  String get photoStoryWhereItWasRecorded => '錄製地點';

  @override
  String get photoStoryWhereItWasTaken => '拍攝地點';

  @override
  String photoStoryLocation(Object coordsLine) {
    return '位置：$coordsLine';
  }

  @override
  String photoStoryHeightAboveTheSea(Object fix) {
    return '海拔高度：$fix 公尺';
  }

  @override
  String get photoStoryLocationHiddenByAndroid => '位置已被 Android 隱藏';

  @override
  String get photoStoryAndroidBlanksItWhen =>
      '用這種方式選照片時，Android 會把它清空。從相簿分享到 Kryfo 通常能保留它。相簿裡的那張可能還帶有位置。';

  @override
  String get photoStoryLocationBlankedByAndroid =>
      '位置：在 Kryfo 看到之前已被 Android 清空';

  @override
  String photoStoryF(Object r) {
    return 'f/$r';
  }

  @override
  String get photoStoryWhatTookIt => '拍攝裝置';

  @override
  String photoStoryPhoneOrCamera(Object phone) {
    return '手機或相機：$phone';
  }

  @override
  String get photoStoryWhenItWasRecorded => '錄製時間';

  @override
  String get photoStoryToTheSecondWith => '精確到秒，包含時區';

  @override
  String get photoStoryToTheSecond => '精確到秒';

  @override
  String photoStoryTime(Object dateFormat) {
    return '時間：$dateFormat';
  }

  @override
  String get photoStoryLens => '鏡頭';

  @override
  String photoStoryLens2(Object lens) {
    return '鏡頭：$lens';
  }

  @override
  String get photoStorySoftware => '軟體';

  @override
  String photoStorySoftware2(Object software) {
    return '軟體：$software';
  }

  @override
  String get photoStorySerialNumber => '序號';

  @override
  String photoStorySerialNumber2(Object serial) {
    return '序號：$serial';
  }

  @override
  String get photoStoryOwnerName => '擁有者名稱';

  @override
  String photoStoryOwner(Object r) {
    return '擁有者：$r';
  }

  @override
  String get photoStoryHiddenThumbnail => '隱藏的縮圖';

  @override
  String get photoStoryASmallCopyOf => '檔案裡藏著一份圖片的小副本。它可能會露出被裁掉的部分';

  @override
  String get photoStoryMakerNotes => '製造商註記';

  @override
  String get photoStoryMakerNotesABlock => '製造商註記：只有製造商能讀取的區塊';

  @override
  String get photoStoryEditingHistory => '編輯紀錄';

  @override
  String get photoStoryXmpEditingHistoryAnd => 'XMP：編輯紀錄和標籤';

  @override
  String get photoStoryCaptions => '說明文字';

  @override
  String get photoStoryIptcCaptionsAndCredits => 'IPTC：說明文字和署名';

  @override
  String get photoStoryComment => '註解';

  @override
  String get photoStoryAWrittenComment => '一段文字註解';

  @override
  String get photoStoryContentCredentials => '內容憑證';

  @override
  String get photoStorySecondPicture => '第二張圖片';

  @override
  String get photoStoryASecondPictureInside => '檔案裡的第二張圖片';

  @override
  String get photoStoryMotionVideo => '動態影片';

  @override
  String get photoStoryAShortVideoInside => '檔案裡的一段短影片';

  @override
  String get photoStorySaveTime => '儲存時間';

  @override
  String get photoStoryTheTimeItWas => '最後一次儲存的時間';

  @override
  String get photoStoryTimeStamps => '時間戳記';

  @override
  String get photoStoryCreationTimeStamps => '建立時間戳記';

  @override
  String get photoStoryDataAfterThePicture => '圖片之後的資料';

  @override
  String photoStoryDataAfterTheEnd(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '圖片結尾之後的資料：$countString 位元組',
    );
    return '$_temp0';
  }

  @override
  String photoStoryTextField(Object k) {
    return '文字欄位：$k';
  }

  @override
  String photoStoryVideoTag(Object k) {
    return '影片標籤：$k';
  }

  @override
  String photoStoryAlso(Object k) {
    return '另外：$k';
  }

  @override
  String photoStoryCameraSettingsFlashFocus(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 項相機設定（閃光燈、對焦、曝光）',
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
      other: '還有 $countString 個欄位',
    );
    return '$_temp0';
  }

  @override
  String get photoStoryCameraSettings => '相機設定';

  @override
  String photoStoryAccurateToAbout(Object metres) {
    return '精確到約 $metres。';
  }

  @override
  String get photoStoryEnoughToFindThe => '足以找到門口。';

  @override
  String get photoStoryEnoughToFindTheStreet => '足以找到那條街。';

  @override
  String get photoStoryEnoughToFindTheArea => '足以找到那一帶。';

  @override
  String get photoStoryItKnowsWhereYou => '它知道你當時在哪裡。';

  @override
  String get photoStoryDownToTheBuilding => '精確到那棟建築。';

  @override
  String get photoStoryAndroidHidTheLocation => 'Android 隱藏了位置。';

  @override
  String get photoStoryTheOriginalMayStill => '原始檔案可能還帶有位置。';

  @override
  String get photoStoryNoLocationInThis => '這張沒有位置資訊。';

  @override
  String get photoStoryItStillSaysPlenty => '它還是透露了不少。';

  @override
  String get photoStoryThisOneKnowsNothing => '這張什麼都不知道。';

  @override
  String get photoStoryNothingToRemove => '沒有可移除的東西。';

  @override
  String get qrPayloadOpensALink => '開啟連結';

  @override
  String qrPayloadOpens(Object host) {
    return '開啟 $host';
  }

  @override
  String get qrPayloadShowsANote => '顯示一段文字';

  @override
  String get qrPayloadScanToJoin => '掃描即可加入';

  @override
  String qrPayloadScanToJoin2(Object oneLine) {
    return '掃描即可加入 · $oneLine';
  }

  @override
  String get qrPayloadANetworkNameIs => '網路名稱最多 32 個字元。';

  @override
  String get qrPayloadAWiFiPassword => 'Wi-Fi 密碼至少要 8 個字元。';

  @override
  String get qrPayloadSavesAContact => '儲存聯絡人';

  @override
  String get qrPayloadWritesAnEmail => '撰寫電子郵件';

  @override
  String get qrPayloadThatDoesNotLook => '這看起來不像電子郵件地址。';

  @override
  String get qrPayloadCallsANumber => '撥打電話';

  @override
  String get qrPayloadWritesAText => '撰寫簡訊';

  @override
  String get qrPayloadOpensAMap => '開啟地圖';

  @override
  String get qrPayloadLatitudeRunsFrom90 => '緯度範圍是 -90 到 90，經度是 -180 到 180。';

  @override
  String get qrPayloadPayThisAddress => '付款到這個地址';

  @override
  String get qrPayloadABitcoinAddressIs => 'Bitcoin 地址只包含字母和數字。';

  @override
  String get qrPayloadTheAmountIsIn => '金額以 BTC 為單位，最多 8 位小數。';

  @override
  String vouchTextAnd(Object names, Object names2) {
    return '$names 和 $names2';
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
      other: '$restString 人',
    );
    return '$names、$names2，以及你認識的另外 $_temp0';
  }

  @override
  String vouchTextVouchedBy(Object vouchNames) {
    return '由 $vouchNames 擔保';
  }

  @override
  String vouchTextIntroducedBy(Object vouchNames) {
    return '由 $vouchNames 介紹';
  }

  @override
  String vouchTextThisSharesSAddress(Object a, Object b) {
    return '這會把 $a 的位址分享給 $b';
  }

  @override
  String get bootFailedKryfoCouldNotStart => 'Kryfo 無法啟動';

  @override
  String get bootFailedThisIsAFault => '這是這台裝置上的故障，不是網路問題。和 Tor 無關。';

  @override
  String get kryfoLinkTextThatLinkIsNot => '這個連結不是 Kryfo 能讀取的';

  @override
  String kryfoLinkTextAdd(Object who) {
    return '要新增 $who 嗎？';
  }

  @override
  String kryfoLinkTextThisIsAnInvite(Object who) {
    return '這是和 $who 聊天的邀請。只有在你知道連結從哪裡來時，才新增對方。';
  }

  @override
  String get kryfoLinkTextAddThem => '新增對方';

  @override
  String get kryfoLinkTextNotNow => '以後再說';

  @override
  String kryfoLinkTextJoin(Object roomName) {
    return '加入 $roomName';
  }

  @override
  String get kryfoLinkTextKryfoLink => 'Kryfo 連結';

  @override
  String kryfoLinkTextAdd2(Object who) {
    return '新增 $who';
  }

  @override
  String get kryfoLinkTextBurnerRoom => '臨時聊天室';

  @override
  String get kryfoLinkTextThisRoomHasClosed => '這個聊天室已關閉';

  @override
  String kryfoLinkTextClosesIn(Object time) {
    return '$time後關閉';
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
      other: '$time後關閉 · 最多 $capString 人',
    );
    return '$_temp0';
  }

  @override
  String get kryfoLinkTextJoin2 => '加入';

  @override
  String get kryfoLinkTextYouJoinUnderA =>
      '你會用專為這個聊天室產生的金鑰加入。裡面沒有人看得到你的 Kryfo ID。';

  @override
  String get linkStubFetchedOverTorBy => '經由 tor 擷取 · 由你的裝置';

  @override
  String get linkStubFetchedOverTorByTheirDevice => '經由 tor 擷取 · 由對方的裝置';

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
  String get mediaBubblesFile => '檔案';

  @override
  String get mediaBubblesAudioUnavailable => '音訊無法播放';

  @override
  String get mediaBubblesHidden => '已隱藏';

  @override
  String get mediaBubblesMicPermissionNeeded => '需要麥克風權限';

  @override
  String get mediaBubblesReleaseToCancel => '放開即可取消';

  @override
  String get mediaBubblesVoiceHiddenSlideTo => '聲音已隱藏 · 滑動以取消';

  @override
  String get mediaBubblesSlideToCancel => '滑動以取消';

  @override
  String get mediaBubblesSendPhoto => '傳送照片';

  @override
  String get mediaBubblesAddACaption => '加上說明…';

  @override
  String get motionStandby => '待命';

  @override
  String get motionConnecting => '連線中';

  @override
  String get motionBuilding => '建立中';

  @override
  String get motionPublishing => '發布中';

  @override
  String get motionReady => '就緒';

  @override
  String get motionPreparingToConnect => '準備連線';

  @override
  String get motionFindingAPrivatePath => '尋找私密路徑';

  @override
  String get motionCarvingThePath => '開闢路徑';

  @override
  String get motionAnnouncingYourArrival => '宣告你的到來';

  @override
  String get motionYouReAnonymous => '你已匿名';

  @override
  String get motionTorIsStartingIn => 'Tor 正在背景啟動。連線建立時，這張圖會逐漸亮起來。';

  @override
  String get motionMakingAFreshRoute => '正在透過匿名中繼建立一條新路線。';

  @override
  String get motionBouncingThroughRelaysSo => '在中繼之間跳轉，讓任何人都無法追溯到你。';

  @override
  String get motionTellingTheNetworkYou => '告訴網路你上線了，但不透露你在哪裡。';

  @override
  String get motionYourIpIsHidden => '你的 IP 已隱藏。只有拿到你 Kryfo 的人才能聯絡你。';

  @override
  String get motionBuilding2 => '建立中';

  @override
  String get motionOpen => '已開通';

  @override
  String get motionLive => '運作中';

  @override
  String motionCircuit(Object circuit) {
    return '線路 · *$circuit*';
  }

  @override
  String get motionDelivered => '已送達';

  @override
  String get motionSent => '已傳送';

  @override
  String get motion1Hop => '1 跳';

  @override
  String get motion3Hops => '3 跳';

  @override
  String get movedStripThisKryfoHasMoved =>
      '這個 Kryfo 已經搬到另一台裝置。從這裡傳送的任何內容都不會送達任何人。';

  @override
  String get navBarChats => '聊天';

  @override
  String get navBarTools => '工具';

  @override
  String get navBarSupport => '支持';

  @override
  String get navBarMe => '我';

  @override
  String get pairCodePanelPuttingYourInviteIn => '正在準備你的邀請';

  @override
  String get pairCodePanelYourInviteIsNot => '你的邀請還沒準備好';

  @override
  String get pairCodePanelReadSixDigitsOut => '大聲唸出六位數字，對方就能新增你。不需要交換其他任何東西。';

  @override
  String get pairCodePanelWorking => '處理中';

  @override
  String get pairCodePanelOrMakeASix => '或產生一組六位數的配對碼唸給對方';

  @override
  String get pairCodePanelCodeCopied => '已複製配對碼';

  @override
  String pairCodePanelBurnsIn(Object mm, Object ss) {
    return '$mm:$ss 後焚毀';
  }

  @override
  String get pairCodePanelTheyTapAddChoose => '對方點「新增」，選擇「配對碼」，然後輸入這些數字。';

  @override
  String get pairCodePanelTheyOpenKryfoTap =>
      '對方開啟 Kryfo，點「新增」，選擇「配對碼」，再輸入這六位數字。下一個人請再產生一組新的。';

  @override
  String pinsPinnedMessages(Object count) {
    return '置頂訊息 · $count';
  }

  @override
  String get pinsPinnedMessages2 => '置頂訊息';

  @override
  String get pinsPhoto => '照片';

  @override
  String get pinsVoiceMessage => '語音訊息';

  @override
  String get pinsMessage => '訊息';

  @override
  String pinsToday(Object hm) {
    return '今天 · $hm';
  }

  @override
  String get pinsPinned => '已置頂';

  @override
  String pinsOf(Object pinsLength, Object kMaxPins) {
    return '$pinsLength/$kMaxPins';
  }

  @override
  String get pinsNothingPinnedHereYet =>
      '這裡還沒有置頂的訊息。按住一則訊息並選擇「置頂」，它就會在這裡等著聊天中的每個人。';

  @override
  String get pinsJump => '跳至';

  @override
  String get pinsUnpin => '取消置頂';

  @override
  String powNoteFirstMessageToSomeone(int secs) {
    final intl.NumberFormat secsNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String secsString = secsNumberFormat.format(secs);

    return '傳給新對象的第一則訊息 · 正在證明它是真的 · $secsString 秒';
  }

  @override
  String powNoteFirstMessageSlow(int secs) {
    final intl.NumberFormat secsNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String secsString = secsNumberFormat.format(secs);

    return '傳給新對象的第一則訊息 · 正在證明它是真的 · $secsString 秒 · 在較慢的手機上最多需要一分鐘';
  }

  @override
  String previewStripFetchedOverTor(Object domainOf) {
    return '$domainOf · 經由 tor 擷取';
  }

  @override
  String get previewStripDropThePreview => '移除預覽';

  @override
  String get previewStripAddPreview => '加上預覽';

  @override
  String get previewStripFetchingOverTor => '正在經由 tor 擷取…';

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
  String get torBootSplashNoShortcutsNoTraces => '不走捷徑，不留痕跡';

  @override
  String get torBootSplashTheNetworkThatKeeps => '保護你隱私的網路正在暖機';

  @override
  String get torBootSplashMadeOnThisPhone => '在這支手機上產生。不會傳送任何東西到任何地方。';

  @override
  String get torBootSplashFirstLaunchTakesA => '首次啟動需要一點時間 · 只在開啟時';

  @override
  String get videoBubbleNothingHereOpensThat => '這裡打不開它 · 改用分享';

  @override
  String videoBubbleMb(Object b) {
    return '$b MB';
  }

  @override
  String videoBubbleKb(Object b) {
    return '$b KB';
  }

  @override
  String get videoBubbleVideo => '影片';

  @override
  String get notificationsChannelName => '訊息';

  @override
  String get cameraClose => '關閉';

  @override
  String get cameraFlash => '閃光燈';

  @override
  String get cameraPhoto => '照片';

  @override
  String get cameraVideo => '影片';

  @override
  String get cameraRetake => '重拍';

  @override
  String get seenIntroductions => '介紹';

  @override
  String get donateAddress => '地址';

  @override
  String get donateCopy => '複製';

  @override
  String get donateDone => '完成';

  @override
  String get donateTierSupporter => '支持者';

  @override
  String get donateTierPatron => '贊助人';

  @override
  String get donateTierGuardian => '守護者';

  @override
  String get chatBlock => '封鎖';

  @override
  String get chatDecline => '拒絕';

  @override
  String get chatAccept => '接受';

  @override
  String get bridgesConnecting => '連線中';

  @override
  String get bridgesSavedTag => '已儲存';

  @override
  String get restoreMade => '建立於';

  @override
  String get restoreContacts => '聯絡人';

  @override
  String get restoreMessages => '訊息';

  @override
  String get restoreAttachments => '附件';

  @override
  String get restoreHiddenChats => '隱藏聊天';

  @override
  String get restoreHiddenFollow => '你的隱藏聊天，最後你會為它們選一組新的隱藏聊天 PIN。';

  @override
  String get restoreChooseHiddenPin => '這份備份包含隱藏聊天。為它們選擇一組隱藏聊天 PIN。';

  @override
  String get restoreHiddenLockFirst => '隱藏聊天需要應用程式鎖，所以先給 Kryfo 設一組自己的 PIN。';

  @override
  String get shieldBlock => '封鎖';

  @override
  String get shieldDelete => '刪除';

  @override
  String get shieldIgnore => '忽略';

  @override
  String get profileIdentity => '身分';

  @override
  String get avatarPickerShape => '形狀';

  @override
  String get avatarPickerColour => '顏色';

  @override
  String get avatarPickerTurn => '旋轉';

  @override
  String get transportStatus => '狀態';

  @override
  String get transportBootstrap => '啟動';

  @override
  String get transportNetwork => '網路';

  @override
  String get transportConnectivity => '連線狀態';

  @override
  String get transportRelays => '中繼';

  @override
  String get transportTraffic => '流量';

  @override
  String get transportContacts => '聯絡人';

  @override
  String get transportKnown => '已知';

  @override
  String get transportListening => '監聽中';

  @override
  String get transportMemory => '記憶體';

  @override
  String get settingsConnected => '已連線';

  @override
  String get settingsScreenshots => '截圖';

  @override
  String get settingsBlocked2 => '已禁止';

  @override
  String get settingsAllowed => '已允許';

  @override
  String get settingsOn => '開啟';

  @override
  String get settingsOff => '關閉';

  @override
  String get settingsNotifications => '通知';

  @override
  String get settingsPrivacy => '隱私';

  @override
  String get settingsSecurity => '安全性';

  @override
  String get settingsBackup => '備份';

  @override
  String get settingsVoice => '語音';

  @override
  String get settingsAbout => '關於';

  @override
  String get wallpaperGradients => '漸層';

  @override
  String get wallpaperPatterns => '圖案';

  @override
  String get wallpaperMoods => '心情';

  @override
  String get confirmSheetKeep => '保留';

  @override
  String get confirmSheetSave => '儲存';

  @override
  String get confirmSheetCancel => '取消';

  @override
  String bridgesSaved(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 個橋接',
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

    return '已接受 $goodString 個，$badString 個無法辨識';
  }

  @override
  String get languageTitle => '語言';

  @override
  String get languageMatchPhone => '跟隨手機';

  @override
  String languageMatchPhoneValue(Object language) {
    return '跟隨手機（$language）';
  }

  @override
  String get languageRedrawLine => 'Kryfo 會以新語言重新顯示，並開啟你的聊天。';

  @override
  String languageButton(Object language) {
    return '語言：$language';
  }

  @override
  String get androidServiceTitle => 'Kryfo 運作中';

  @override
  String get androidServiceText => '你的加密線路保持開啟，讓訊息能送達';

  @override
  String get androidChannelName => '保持連線';

  @override
  String get androidChannelDescription =>
      '讓 Kryfo 保持連線，在它關閉時也能收到加密訊息。關閉這項設定會停止傳遞訊息。';

  @override
  String get videoViewerPlay => '播放';

  @override
  String get videoViewerPause => '暫停';

  @override
  String get videoViewerPlayAgain => '重新播放';

  @override
  String get videoViewerCannotPlay => '這支手機無法在這裡播放這部影片。';

  @override
  String get videoViewerOpenElsewhere => '用其他應用程式開啟';

  @override
  String get photoKnowsLookedFor => '查找了';

  @override
  String get photoKnowsNotInIt => '沒有';

  @override
  String get languageNameEn => '英文';

  @override
  String get languageNameDe => '德文';

  @override
  String get languageNameFr => '法文';

  @override
  String get languageNameEs => '西班牙文';

  @override
  String get languageNamePt => '葡萄牙文（巴西）';

  @override
  String get languageNameIt => '義大利文';

  @override
  String get languageNameRu => '俄文';

  @override
  String get languageNameUk => '烏克蘭文';

  @override
  String get languageNameTr => '土耳其文';

  @override
  String get languageNameZh => '簡體中文';

  @override
  String get languageNameZhHant => '繁體中文';

  @override
  String get languageNameVi => '越南文';

  @override
  String get languageNameId => '印尼文';

  @override
  String get languageNameFa => '波斯文';

  @override
  String get languageNameAr => '阿拉伯文';

  @override
  String get languageLaterLine => '你隨時可以在設定中更改。';

  @override
  String get pollAttach => '投票';

  @override
  String get pollNewTitle => '新增投票';

  @override
  String get pollQuestionHint => '向群組提個問題';

  @override
  String get pollOptionsLabel => '選項';

  @override
  String pollOptionHint(Object n) {
    return '選項 $n';
  }

  @override
  String get pollAddOption => '新增選項';

  @override
  String get pollMaxLine => '最多十二個選項。';

  @override
  String get pollMultiple => '多選';

  @override
  String get pollMultipleLine => '大家可以選擇不只一項。';

  @override
  String get pollSend => '送出投票';

  @override
  String get pollKind => '投票';

  @override
  String get pollKindMulti => '投票 · 多選';

  @override
  String get pollKindClosed => '最終結果';

  @override
  String pollVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 票',
      zero: '還沒有人投票',
    );
    return '$_temp0';
  }

  @override
  String get pollVote => '投票';

  @override
  String get pollTakeBack => '撤回我的投票';

  @override
  String get pollClose => '結束投票';

  @override
  String get pollCloseTitle => '要結束這個投票嗎？';

  @override
  String get pollCloseLine => '所有人都會看到最終結果，之後誰也不能再投票。';

  @override
  String get pollCloseYes => '結束';

  @override
  String pollPreview(Object question) {
    return '投票：$question';
  }

  @override
  String get pollWhoVoted => '誰投了票';

  @override
  String get pollNobody => '還沒有人';

  @override
  String get pollYou => '你';

  @override
  String pollOptionA11y(Object option, Object share) {
    return '$option，$share';
  }

  @override
  String get pollPickOne => '選一項';

  @override
  String get pollPickSeveral => '選一項或多項';

  @override
  String get searchOpen => '搜尋';

  @override
  String get searchHint => '搜尋聊天和訊息';

  @override
  String get searchFilterAll => '全部';

  @override
  String get searchFilterPhotos => '照片';

  @override
  String get searchFilterVideos => '影片';

  @override
  String get searchFilterFiles => '檔案';

  @override
  String get searchFilterLinks => '連結';

  @override
  String get searchChats => '聊天';

  @override
  String get searchMessages => '訊息';

  @override
  String get searchIntroTitle => '搜尋你的聊天';

  @override
  String get searchIntroLine => '名字、詞語、照片、檔案和連結。搜尋只在這支手機上進行，不會把任何東西傳到別處。';

  @override
  String get searchNothing => '找不到結果';

  @override
  String get searchNothingLine => '換個詞或換個篩選試試。';

  @override
  String searchMatches(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 筆結果',
    );
    return '$_temp0';
  }

  @override
  String searchMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '還有 $count 筆',
    );
    return '$_temp0';
  }

  @override
  String searchFilling(Object share) {
    return '正在加入較早的訊息 · $share';
  }

  @override
  String get searchClear => '清除';

  @override
  String get handleShowInSearch => '在搜尋中顯示我';

  @override
  String get handleShowInSearchLine => '任何人都能找到這個使用者名稱並傳訊息給你。';

  @override
  String handleShownAs(Object name) {
    return '顯示為 $name';
  }

  @override
  String get handleNameInSearch => '搜尋中的名字';

  @override
  String get handleNameInSearchLine =>
      '可選。有人搜尋時，它會顯示在你的使用者名稱旁邊。任何人都能找到這個使用者名稱並傳訊息給你。';

  @override
  String get handleNameHint => '你的名字，也可以留空';

  @override
  String get handleShowMe => '顯示我';

  @override
  String get handleSearchOff => '你已不在搜尋中';

  @override
  String handleSearchOn(Object handle) {
    return '你以 @$handle 出現在搜尋中';
  }

  @override
  String get handleRegistryFailed => '聯絡不上註冊處。請一分鐘後再試。';

  @override
  String get searchPeople => '人';

  @override
  String searchPeopleAsk(Object query) {
    return '在公開使用者名稱中尋找「$query」';
  }

  @override
  String get searchPeopleLine => '透過 Tor 詢問。註冊處不留任何紀錄。';

  @override
  String get searchPeopleNone => '沒有相符的公開使用者名稱';

  @override
  String get searchPeopleOffline => 'Tor 還沒準備好';

  @override
  String get searchPeopleBusy => '現在搜尋太多了，請稍後再試。';

  @override
  String get searchPeopleUnreachable => '聯絡不上註冊處';

  @override
  String get peopleVerified => '已驗證的使用者名稱';

  @override
  String get peopleAdd => '新增';

  @override
  String peopleFingerprint(Object fp) {
    return '金鑰指紋 · $fp';
  }

  @override
  String get peopleFingerprintLine => '請核對是否與對方應用程式裡顯示的一致。';

  @override
  String get peopleAdding => '正在新增…';

  @override
  String handleNobodyHasClaimed(Object handle) {
    return '沒有人認領 $handle';
  }

  @override
  String get handleThatHandleIsTaken => '這個使用者名稱已被使用';

  @override
  String get pinPickDifferent => '請換一組 PIN 碼';

  @override
  String get settingsKeptOnWhileLock => '應用程式鎖開啟時保持開啟。';

  @override
  String get lockFingerAfterPin => '輸入一次 PIN 碼，即可再次使用指紋。';

  @override
  String get pinsAdvanced => '進階保護';

  @override
  String get pinsAdvancedLine => '用於有人逼你解鎖手機的時候。';

  @override
  String get pinsWipeLine => '在鎖定畫面輸入它，會從這支手機上清除 Kryfo。';

  @override
  String get pinsDecoyPin => '偽裝 PIN';

  @override
  String get pinsDecoyLine => '開啟一個空的 Kryfo，就像剛安裝好一樣。';

  @override
  String get pinsSetADecoyPin => '設定偽裝 PIN';

  @override
  String get pinsChangeDecoyPin => '變更偽裝 PIN';

  @override
  String get pinsRemoveTheDecoyPin => '要移除偽裝 PIN 嗎？';

  @override
  String get pinsTheDecoyGoes => '它開啟的那個空 Kryfo 也會一起消失。';

  @override
  String get pinsTurnOffWithDecoy =>
      '所有 PIN 都會被移除，偽裝 PIN 和它的 Kryfo 以及所有隱藏聊天也一樣。任何拿著你手機的人，都能以你的身分開啟 Kryfo。';

  @override
  String get pinsHowThisWorks => '運作方式';

  @override
  String get flowEnterYourPin => '輸入你的 PIN 碼';

  @override
  String get flowEnterYourPinLine => '就是開啟 Kryfo 的那一組。';

  @override
  String get flowWipeTitle => '清除 PIN';

  @override
  String get flowWipe1 =>
      '在鎖定畫面代替你的 PIN 碼輸入，它會從這支手機上清除 Kryfo 並關閉應用程式。在旁人看來，應用程式只是停止了。';

  @override
  String get flowWipe2 => '所有聊天和你的身分都會一起清除，有偽裝的話也一樣。';

  @override
  String get flowWipeChoose => '選擇一組清除 PIN';

  @override
  String get flowWipeDone => '已設定清除 PIN';

  @override
  String get flowWipeDoneLine => '鎖定畫面上沒有任何跡象顯示它的存在。';

  @override
  String get flowDecoyTitle => '偽裝 PIN';

  @override
  String get flowDecoy1 => '開啟一個空的 Kryfo，就像剛安裝好一樣。';

  @override
  String get flowDecoyFinger => '你的指紋會開啟真正的 Kryfo。如果有人可能逼你用指紋，請關閉指紋解鎖。';

  @override
  String get flowDecoyDigits => '位數要跟你的 PIN 碼一樣，因為旁邊看著的人數得出圓點。';

  @override
  String get flowDecoyShade => '已經在通知欄裡的通知已經被看到了。偽裝開啟期間，不會出現新的通知。';

  @override
  String get flowDecoyChoose => '選擇一組偽裝 PIN';

  @override
  String get flowDecoyDone => '已設定偽裝 PIN';

  @override
  String get flowDecoyDoneLine =>
      '在鎖定畫面輸入它，就能開啟那個空的 Kryfo。要離開，切換到別的應用程式，再輸入你的 PIN 碼。';

  @override
  String get flowLaw => '在有些國家，拒絕解鎖手機或向官方隱藏資料本身就是違法的。出門前先了解當地的法律。';

  @override
  String get howWipe =>
      '在鎖定畫面輸入清除 PIN，會清除所有聊天、你的身分和任何偽裝，然後關閉 Kryfo。即使多次輸錯後鍵盤暫停，它也照樣有效。';

  @override
  String get howDecoy =>
      '偽裝 PIN 會開啟第二個空的 Kryfo，它有自己的三個詞。傳給你真正 Kryfo 的訊息照樣在底下悄悄送達。要離開偽裝，切換到別的應用程式，再輸入你的 PIN 碼。';

  @override
  String get flowNotSet => '沒能設定成功，請再試一次。';

  @override
  String get pinsHiddenChats => '隱藏聊天';

  @override
  String get pinsHiddenLine => '選中的聊天會一直藏起來，直到你輸入隱藏聊天 PIN：不在列表裡，不在搜尋裡，也沒有通知。';

  @override
  String get pinsSetUp => '設定';

  @override
  String get pinsChangeHiddenPin => '變更隱藏聊天 PIN';

  @override
  String get pinsHideMoreChats => '隱藏更多聊天';

  @override
  String get pinsRemoveHiddenChats => '取消隱藏聊天';

  @override
  String get pinsRemoveHiddenTitle => '要取消隱藏聊天嗎？';

  @override
  String get pinsRemoveHiddenLine => '它們會回到你的聊天列表，隱藏聊天 PIN 也不再能開啟任何東西。';

  @override
  String get pinsTurnOffHiddenFirst => '隱藏聊天需要應用程式鎖。先取消隱藏聊天，它們會回到你的聊天列表。';

  @override
  String get flowVaultTitle => '隱藏聊天';

  @override
  String get flowVault1 =>
      '選擇要隱藏的聊天和群組。你的 PIN 碼開啟的 Kryfo 裡沒有它們。隱藏聊天 PIN 會開啟全部內容，包括隱藏聊天。';

  @override
  String get flowVault2 => '藏起來的時候，它們從不發通知，也不顯示標記。它們的訊息照樣送達，封存起來，等你輸入隱藏聊天 PIN。';

  @override
  String get flowVaultFinger => '你的指紋開啟的 Kryfo 裡沒有隱藏聊天。';

  @override
  String get flowVaultDigits => '你的 PIN 碼也最好用六位數或更多，因為旁邊看著的人數得出圓點。';

  @override
  String get flowVaultReplace => '這會取代這支手機上已有的任何隱藏聊天。';

  @override
  String get flowVaultChoose => '選擇一組隱藏聊天 PIN';

  @override
  String get flowVaultChooseLine => '六位數或更多。';

  @override
  String get flowEnterHiddenPinLine => '就是開啟隱藏聊天的那一組。';

  @override
  String get flowVaultForgetTitle => '記住這組 PIN';

  @override
  String get flowVaultForget => '如果你忘了這組 PIN，你的隱藏聊天就永遠沒了。誰也找不回來，我們也不行。';

  @override
  String get flowVaultForgetOk => '我明白了';

  @override
  String get flowVaultPickTitle => '選擇要隱藏的聊天';

  @override
  String get flowVaultPickLine => '它們現在會離開你的聊天列表。輸入隱藏聊天 PIN 就能再看到它們。';

  @override
  String flowVaultPickButton(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '隱藏 $countString 個聊天',
      zero: '暫不隱藏',
    );
    return '$_temp0';
  }

  @override
  String get flowVaultPickEmpty => '還沒有可以隱藏的聊天。';

  @override
  String get flowVaultBackupTitle => '現在備份嗎？';

  @override
  String get flowVaultBackupLine =>
      '現在做的備份也包含你的隱藏聊天，用它自己的密碼短語保護。如果你忘了隱藏聊天 PIN，這是找回它們的唯一辦法。';

  @override
  String get flowVaultBackupNow => '備份';

  @override
  String get flowVaultNotNow => '以後再說';

  @override
  String get flowVaultDone => '已設定隱藏聊天';

  @override
  String get flowVaultDoneLine => '在鎖定畫面輸入隱藏聊天 PIN 就能看到它們。切換到別的應用程式，它們就又藏起來了。';

  @override
  String get flowVaultChanged => '已變更隱藏聊天 PIN';

  @override
  String get flowVaultChangedLine => '你的隱藏聊天現在用新的開啟。舊的什麼也打不開了。';

  @override
  String get howVault =>
      '隱藏聊天 PIN 開啟的 Kryfo 帶著隱藏聊天，你的 PIN 碼和指紋開啟的則沒有。重新設定隱藏聊天，會取代這支手機上已有的。忘了隱藏聊天 PIN，它們就永遠沒了。';

  @override
  String get chatHide => '隱藏此聊天';

  @override
  String get groupHide => '隱藏此群組';

  @override
  String get chatHidden => '已隱藏';

  @override
  String get chatHiddenToast => '已從聊天列表中隱藏';

  @override
  String get chatShowInList => '在聊天列表中顯示';

  @override
  String get stickerOpen => '貼圖';

  @override
  String get stickerRecent => '最近使用';

  @override
  String stickerA11y(String emoji) {
    return '貼圖 $emoji';
  }

  @override
  String get stickerRemoveRecent => '從最近使用中移除';

  @override
  String get stickerCouldNotLoad => '無法載入貼圖';

  @override
  String get stickerLabel => '貼圖';

  @override
  String get stickerNewer => '來自較新版的 Kryfo';

  @override
  String get devLinkMismatch => '此連結自稱是 Marios，但其金鑰不相符。未新增。';

  @override
  String get devName => 'Marios';

  @override
  String get devRowTitle => 'Marios · Kryfo 的開發者';

  @override
  String get devWelcome => '你好，我是 Marios，Kryfo 是我做的。什麼都可以跟我說：錯誤、想法、問題。每一則我都會看。';

  @override
  String get devPinned => '內建於 Kryfo';

  @override
  String get devAnonymous => '匿名';

  @override
  String get devAboutLine =>
      'Marios 的金鑰內建在 Kryfo 裡。這個聊天裡的每則訊息都會用它核對，所以別人無法冒充他傳訊息。';

  @override
  String get devKeyLabel => '他的金鑰';

  @override
  String get devDeleteLine => '每則訊息都會刪除，這個聊天也不會再回來。';

  @override
  String get devDeleteLineAnon => '每則訊息和為這個聊天產生的名字都會刪除，這個聊天也不會再回來。';

  @override
  String get settingsWriteToMarios => '傳訊息給 Marios';

  @override
  String get settingsWriteToMariosHint => '錯誤、想法、問題';

  @override
  String get seenDevChat => '與 Marios 的聊天';

  @override
  String get seenDevChatCell => '你傳訊息時';

  @override
  String get seenDevChatLine => '你傳訊息之前，什麼都看不到。之後能看到你傳送的內容，以及你的三個詞，除非你匿名傳送。';

  @override
  String get devNoteWords => 'Marios 會看到你的三個詞';

  @override
  String get devWriteAnonymously => '匿名傳送';

  @override
  String get devNoteAnon => 'Marios 會看到一個專為這個聊天產生的新名字';

  @override
  String get devUseMyWords => '用我的三個詞';

  @override
  String get devWhoSeesWhat => '誰能看到什麼';

  @override
  String get devWhoWords =>
      '用你的三個詞，Marios 能像任何聯絡人一樣回覆你。他能看到你的三個詞，但看不到你的臉和支持者徽章。';

  @override
  String get devWhoAnon => '匿名時，Kryfo 會只為這個聊天產生新的名字和金鑰。它們只留在這支手機上，絕不會在別處使用。';

  @override
  String get devWhoNothingYet => '在你傳出第一則訊息之前，什麼都不會離開你的手機。';

  @override
  String get devWhoChoiceStays => '你的選擇會一直跟著這個聊天。';

  @override
  String get devKeyCheckFailed => '無法核對 Marios 的金鑰。什麼都沒有傳送。';

  @override
  String get devLockLine => 'Marios 會讀到這些訊息。等他回覆後，你就能繼續寫。';

  @override
  String get devNewKey => 'Marios 有了新金鑰';

  @override
  String get devStartNewChat => '開始新的聊天';

  @override
  String get devKeyRetired => '這個金鑰已停用。這裡不能再傳送或接收任何內容。';

  @override
  String get devVoiceDisguised => '在這個聊天裡，你的語音會變聲';

  @override
  String get devChatOptions => '聊天選項';
}
