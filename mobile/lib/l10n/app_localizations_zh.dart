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
  String get accentYellow => '黄色';

  @override
  String get accentGrey => '灰色';

  @override
  String get accentPurple => '紫色';

  @override
  String get accentLime => '青柠';

  @override
  String get accentVelvet => '丝绒红';

  @override
  String get accentBlue => '蓝色';

  @override
  String get appearancePreview => '你的聊天在这个颜色下的预览';

  @override
  String get appearanceSampleIn => '今晚还照旧吗？';

  @override
  String get appearanceSampleOut => '照旧。八点，老地方。';

  @override
  String get appearanceSampleButton => '回复';

  @override
  String get appearanceAccentHint => '按钮、你自己的消息和链接都会用这个颜色。应用图标保持黄色。';

  @override
  String get appearanceChatWallpaper => '聊天壁纸';

  @override
  String get appearanceEveryChat => '所有聊天';

  @override
  String get appearanceWallpaperHint =>
      '在聊天菜单里为它单独设置的壁纸优先。照片只留在这部手机上，和你的聊天一起加密。';

  @override
  String get appearanceWallpaperHintDesk =>
      '在聊天菜单里为它单独设置的壁纸优先。照片只留在这台电脑上，和你的聊天一起加密。';

  @override
  String get backupThatPassphraseDoesNot => '这个密码短语打不开此文件';

  @override
  String get backupThatFileIsNot => '这个文件不是 Kryfo 备份';

  @override
  String get backupThisBackupIsFrom => '这个备份来自更新版本的 Kryfo。请先更新应用，再试一次';

  @override
  String get backupThisFileIsDamaged => '这个文件已损坏，无法读取';

  @override
  String get backupTheRestoreStoppedPartway => '恢复中途停止了';

  @override
  String get backupCouldNotMakeThe => '无法生成密钥';

  @override
  String get contactCardMessageMeOn => '给我发消息，请用';

  @override
  String get contactCardScanToAdd => '用 Kryfo 扫一扫就能加我。\n除此之外，这张卡片对你一无所知。';

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
  String get appNoRelayReached => '未能连上任何中继';

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
  String get appAnAttachmentCouldNotDesk => '有个附件无法保存到这台电脑上';

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
  String appJoined(Object linkName) {
    return '已加入 $linkName';
  }

  @override
  String get roomJoinWaitingToJoin => '等待加入';

  @override
  String get roomJoinNotAnswering => '没有回应';

  @override
  String roomJoinWaitingFor(Object room) {
    return '正在等待 $room 让你加入…';
  }

  @override
  String get roomJoinWaitingLine => '进入后就可以在这里发消息。';

  @override
  String get roomJoinNoAnswer => '这个聊天室没有回应。';

  @override
  String get roomJoinMayHaveEnded => '它可能已经结束了。';

  @override
  String get roomJoinFullShort => '聊天室已满';

  @override
  String get roomJoinFull => '这个聊天室已满。';

  @override
  String get roomJoinFullLine => '现在没有空位。请稍后再试，或问问分享链接的人。';

  @override
  String get appBooting => '启动中…';

  @override
  String get appSettingUpYourIdentity => '正在设置你的身份…';

  @override
  String get appAddSomeone => '添加联系人';

  @override
  String get appScanTheirCodeOr => '扫描对方的二维码，或粘贴对方给你的内容：链接、@用户名或聊天室链接。';

  @override
  String get appScanTheirCodeOrDesk => '粘贴对方给你的内容：链接、@用户名或聊天室链接。';

  @override
  String get appScanTheirCode => '扫描对方的二维码';

  @override
  String get appAKryfoLinkA => 'Kryfo 链接、聊天室链接或 @name';

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
  String get appStartingTor30s => '正在启动 Tor（约 30 秒）…';

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
  String get appReadyToChatAddressFinishing => '可以聊天了 · 地址即将就绪';

  @override
  String get appTor => 'Tor';

  @override
  String get appTorIsOffTurn => 'Tor 已关闭。打开它才能私密连接。';

  @override
  String get appTheFirstConnectionTakes =>
      '首次连接需要一两分钟，Tor 要先建一条私密路线。之后它会被缓存，以后打开 Kryfo 会快很多。';

  @override
  String get appTorNoRelayYet =>
      'Tor 已启动，但还没有中继响应。Kryfo 会继续尝试，消息会在这里等候，直到有中继响应。';

  @override
  String get appRelayAndFastModes => '快速模式不经过 Tor，所以更快。它在设置的“速度与隐私”里，并说明了代价。';

  @override
  String get appOffline => '离线';

  @override
  String get appTorOff => 'Tor 已关';

  @override
  String get appTorReady => 'Tor 就绪';

  @override
  String get appConnecting2 => '正在连接';

  @override
  String get appWaitingForARelay => '正在等待中继';

  @override
  String appStartingTorPct(Object pct) {
    return '正在启动 Tor · $pct';
  }

  @override
  String get appGettingNewMessages => '正在接收新消息';

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
  String get miuiAutostartOpenSettings => '打开设置';

  @override
  String get miuiAutostartCouldnTOpenIt => '打不开。请在手机设置里找“自启动”';

  @override
  String get batteryGuideHuawei =>
      '华为和荣耀会关闭由系统自动管理的应用。在下一个页面找到 Kryfo，关闭“自动管理”，并保持“允许自启动”“允许关联启动”和“允许后台活动”开启。';

  @override
  String get batteryGuideOppo =>
      'OPPO 和 realme 会停止后台应用。在下一个页面找到 Kryfo，允许“自启动”。再到“电池”里，也允许它在后台运行。';

  @override
  String get batteryGuideVivo =>
      'vivo 会停止后台应用。在下一个页面找到 Kryfo，允许它后台启动。再到“电池”里，也允许它后台高耗电。';

  @override
  String get batteryGuideSamsung =>
      '三星会让它认为不常用的应用进入休眠。在下一个页面打开“后台使用限制”，把 Kryfo 加入“从不休眠的应用”。';

  @override
  String get batteryGuideOnePlus =>
      '一加会停止后台应用。在下一个页面找到 Kryfo，允许“自启动”。再到“电池”里，把它设为“不优化”。';

  @override
  String get batteryGuideXiaomiTitle => '让 Kryfo 保持运行';

  @override
  String get batteryGuideXiaomi => '即使开了自启动，小米也会停止后台应用。如要持续收到消息：';

  @override
  String get batteryGuideXiaomiStep1 => '自启动：为 Kryfo 打开。';

  @override
  String get batteryGuideXiaomiStep2 => '省电策略：把 Kryfo 设为“无限制”。';

  @override
  String get batteryGuideXiaomiStep3 =>
      '最近任务：长按 Kryfo，点一下锁，这样“全部清除”和手机的自动清理都不会关掉它。';

  @override
  String get batteryGuideXiaomiAfter => '如果手机还是停止了 Kryfo，在你重新打开它之前，什么都收不到。';

  @override
  String get notificationsNewEncryptedMessagesFrom => '来自联系人的新加密消息';

  @override
  String get notificationsNewMessage => '新消息';

  @override
  String get notificationsNewEncryptedMessagesFromYourContacts => '来自联系人的新加密消息';

  @override
  String get notificationsNewMessage2 => '新消息';

  @override
  String get notificationsSomeone => '某人';

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
  String scamShieldGivesUsedName(Object shown) {
    return '自称是 $shown，这里已有人用这个名字';
  }

  @override
  String scamShieldWarning(Object noticed) {
    return '$noticed。不要给没见过面的人转钱或发验证码。';
  }

  @override
  String get scamShieldAsksForSecret => '索要验证码、PIN 码或恢复词';

  @override
  String get scamShieldAsksForMoneyFast => '催着要钱';

  @override
  String get scamShieldPromisesProfit => '承诺轻松赚钱';

  @override
  String get scamShieldClaimsSupport => '自称来自 Kryfo 或客服团队';

  @override
  String get scamShieldDismiss => '隐藏';

  @override
  String scamShieldNameMatchesYourContact(Object shown) {
    return '名字和你的联系人 $shown 一样';
  }

  @override
  String get scamShieldLinksToALookalike => '链接指向仿冒的知名网站';

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
  String get avatarPickerPickAFace => '选一个头像';

  @override
  String get commonSave => '保存';

  @override
  String get backupPassphraseMustBeAt => '密码短语至少要 12 个字符';

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
  String get backupACopyToKeepDesk => '留一份副本。这台电脑照常使用。';

  @override
  String get backupMoveToAnotherDevice => '迁移到另一台设备';

  @override
  String get backupTheFileTakesThis =>
      '这个文件会带走这个身份。文件一旦生成，这部手机就停用了：新的东西不会再到这里，从这里发出的任何东西也送不到任何人。';

  @override
  String get backupTheFileTakesThisDesk =>
      '这个文件会带走这个身份。文件一旦生成，这台电脑就停用了：新的东西不会再到这里，从这里发出的任何东西也送不到任何人。';

  @override
  String get backupOneEncryptedFileYour =>
      '一个加密文件：你的身份、你的联系人、每一条消息，以及每一张照片、每一条语音和每一个文件。在另一台设备上用密码短语导入它。在那之前，你仍然可以改变主意，继续留在这部手机上。';

  @override
  String get backupOneEncryptedFileYourIdentityYour =>
      '一个加密文件：你的身份、你的联系人、每一条消息，以及这部手机上此刻的每一张照片、每一条语音和每一个文件。今天之后说的内容不在里面，所以重要的时候请再做一份。恢复时，文件和密码短语两样都要有。';

  @override
  String get backupOneEncryptedFileYourIdentityYourDesk =>
      '一个加密文件：你的身份、你的联系人、每一条消息，以及这台电脑上此刻的每一张照片、每一条语音和每一个文件。今天之后说的内容不在里面，所以重要的时候请再做一份。恢复时，文件和密码短语两样都要有。';

  @override
  String get backupPassphrase => '密码短语';

  @override
  String get backupConfirmPassphrase => '确认密码短语';

  @override
  String backupWriting(Object progress) {
    return '正在写入… $progress';
  }

  @override
  String get backupSaveComesAfter => '文件准备好后，你再选择保存位置。';

  @override
  String get backupSaving => '正在保存…';

  @override
  String backupSavedIn(String place) {
    return '备份已保存到 $place · 请保管好密码短语';
  }

  @override
  String get backupNotSaved => '备份没有保存。文件还在。';

  @override
  String get backupNotSavedNoSpace => '你选择的位置空间不足。文件还在，请换个位置，或释放一些空间。';

  @override
  String get backupShareInstead => '改为分享';

  @override
  String get backupSavedUnchecked => '备份已保存，但 Kryfo 无法检查这份副本';

  @override
  String get backupHandedOver => '备份已交给你选择的应用 · 请确认它已收到';

  @override
  String get backupMoveReachedTitle => '文件已经到新手机上了吗？';

  @override
  String get backupMoveReachedTitleDesk => '文件已经到新设备上了吗？';

  @override
  String get backupMoveReachedLine => '在新手机上打开它之前，请留着这部手机。';

  @override
  String get backupMoveReachedLineDesk => '在新设备上打开它之前，请留着这台电脑。';

  @override
  String get backupFinishTheMove => '完成迁移';

  @override
  String get backupNotYet => '还没有';

  @override
  String get backupCreating => '正在创建…';

  @override
  String get backupMakeTheFileAnd => '生成文件并迁移';

  @override
  String get backupCreateBackup => '创建备份';

  @override
  String get backupNotMade => '备份没能完成。请再试一次。';

  @override
  String get backupNoSpace => '手机可用空间不足，无法完成备份。请清理一些空间后再试一次。';

  @override
  String get backupNoSpaceDesk => '电脑可用空间不足，无法完成备份。请清理一些空间后再试一次。';

  @override
  String get backupHiddenNotIn => '隐藏聊天不在其中。';

  @override
  String get backupHiddenIncluded => '你的隐藏聊天也在其中。';

  @override
  String get backupMoveHiddenStay => '隐藏聊天留在这部手机上，并随它一起抹除。';

  @override
  String get backupMoveHiddenStayDesk => '隐藏聊天留在这台电脑上，并随它一起抹除。';

  @override
  String get backupHiddenGone => 'Kryfo 锁定时，你的隐藏聊天已关闭。用隐藏聊天 PIN 打开它们，再从那里备份。';

  @override
  String get blockedBlocked => '已屏蔽';

  @override
  String get blockedNoOneIsBlocked => '没有屏蔽任何人';

  @override
  String get commonUnblock => '取消屏蔽';

  @override
  String get bridgesConnected => '已连接';

  @override
  String get bridgesFromTheTorProject => '来自 Tor 项目';

  @override
  String get bridgesPasteFromClipboard => '从剪贴板粘贴';

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
  String get bridgesWhenYouAskFor =>
      '你请求网桥时，Tor 项目会看到你的 IP 地址。这很正常：Tor Browser 和所有 Tor 应用都是这样获取网桥的，他们从中只能知道有人请求了网桥，对你的聊天一无所知。';

  @override
  String get cameraNoCameraOnThis => '这部手机没有相机';

  @override
  String get cameraCameraNotAvailable => '相机不可用';

  @override
  String get cameraCameraPermissionIsOff => '相机权限已关闭';

  @override
  String get cameraOpenSettings => '打开设置';

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
  String get cameraTooLongForA => '太长，无法作为消息发送 · 最大 50 MB';

  @override
  String get cameraNeverSavedToYour => '不会保存到你的相册';

  @override
  String get cameraNoExifNeverSaved => '没有 EXIF，也不会保存到你的相册';

  @override
  String get cameraRec => '录制';

  @override
  String get cameraSwitchCamera => '切换相机';

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
  String chatEarlierMessagesArrived(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '收到 $countString 条更早的消息',
    );
    return '$_temp0';
  }

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
  String get chatItDisappearsWithNo => '它会从双方的手机上删除，除非已被保存。此操作无法撤销。';

  @override
  String get chatItDisappearsWithNoDesk => '它会从双方的设备上删除，除非已被保存。此操作无法撤销。';

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
  String get chatHowLongAfterReading => '消息被读后多久焚毁？你发出的从发送时开始计时。';

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
  String get chatGifFromPhoneDesk => '电脑里的 GIF';

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
    return '$humanBytes · 经 Tor 需要$wireEstimate';
  }

  @override
  String get chatBigFilesGoOut => '大文件会拆成加密的小块发出，所以需要一些时间。保持应用打开，它就会一直发下去。';

  @override
  String get chatSendIt => '发送';

  @override
  String get chatCouldNotReadThat => '无法读取这个文件';

  @override
  String get chatCouldNotCleanThat => '无法清理这个视频';

  @override
  String get chatGifTooBig8 => 'GIF 太大 · 最大 8 MB';

  @override
  String get chatCouldNotCleanThatGif => '无法清理这个 GIF';

  @override
  String get chatTorIsNotUp => 'Tor 还没连上 · 不添加链接预览';

  @override
  String get chatCouldnTReachIt => '无法访问该页面 · 不添加链接预览';

  @override
  String get chatNoTitleCameBack => '该页面没有标题 · 不添加链接预览';

  @override
  String get chatCouldnTFetchIt => '无法加载预览';

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
  String get chatJustForYouNeverDesk => '只给你自己看。绝不会发出，也绝不会离开这台电脑。';

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
  String get chatEveryMessageHereIsDesk =>
      '这里的每条消息都会从这台电脑上清除。这只清除你这边的副本——不会动到对方的设备。';

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
  String get chatTheNextPhotoYou => '你发的下一张照片会以受保护方式打开 · Kryfo 会阻止对它截屏';

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
  String get chatWaitsToSend => '等待发送';

  @override
  String get chatTheyMayNotKnow => '对方可能还不知道你已接受';

  @override
  String get chatYouBlockedThisContact => '你已屏蔽这位联系人';

  @override
  String get chatSupporter => '支持者';

  @override
  String get chatEncryptedDirect => '已加密 · 直连';

  @override
  String get chatEncryptedOverTor => '已加密 · 经由 Tor';

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
  String get chatSayHiSoThey => '打个招呼，让对方看到你';

  @override
  String get chatTheyWonTKnow => '在你的第一条消息送达前，对方不会知道已被你添加。';

  @override
  String get chatWave => '挥手';

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
  String get commonSend => '发送';

  @override
  String get chatNoPhotosInThis => '这个聊天里还没有照片';

  @override
  String get chatHoldToRecord => '按住录制语音消息';

  @override
  String get chatSecurityCodeChanged => '安全码已变更';

  @override
  String get chatCompareTitle => '核对安全码';

  @override
  String chatCompareLine(Object peerName) {
    return '三个词可以照抄。要确认这个聊天真的是和 $peerName，请当面或通过通话和对方核对安全码。';
  }

  @override
  String get chatCompareLater => '稍后';

  @override
  String get chatCompareNow => '核对';

  @override
  String chatKeyHeldLine(Object peerName) {
    return '你之前验证过 $peerName。在你核对新的安全码或接受新密钥之前，什么都不会发出。对方的消息仍会收到。';
  }

  @override
  String get chatCheckTheNumber => '核对安全码';

  @override
  String get chatAcceptNewKey => '接受新密钥';

  @override
  String get chatAcceptNewKeyTitle => '接受对方的新密钥？';

  @override
  String chatAcceptNewKeyLine(Object peerName) {
    return '之后 Kryfo 会不经核对就发往新密钥，$peerName 也不再标为已验证。你随时可以重新验证。';
  }

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
  String get cleanNotEnoughRoomOnDesk => '电脑空间不足。';

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
  String get cleanPicturesOver64MbDesk => '超过 64 MB 的图片不会在电脑上清理。没有做任何改动。';

  @override
  String get cleanKryfoCouldNotRead => 'Kryfo 没能把它读完，所以不会说它是干净的。没有生成副本。';

  @override
  String get cleanSomethingInsideIsOf => '里面有它不知道怎么移除的内容，所以没有生成副本。';

  @override
  String get cleanFreeSomeSpaceAnd => '请腾出一些空间再试一次。没有做任何改动。';

  @override
  String get cleanTheAppThatShared => '分享它的应用可能已经把它收回了。请再分享一次。';

  @override
  String get cleanTheAppThatSharedDesk => '它可能已被移动，或被其他应用占用。请再选一次。';

  @override
  String get cleanNoAppOnThis => '这部手机上没有应用接收这个文件。';

  @override
  String get cleanCouldNotSaveIt => '无法保存。请检查手机还有没有空间。';

  @override
  String get cleanCouldNotSaveItDesk => '无法保存。请检查电脑还有没有空间。';

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
  String get cleanSaveToGalleryDesk => '保存干净副本';

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
  String get cleanEverythingStaysOnThisDesk => '一切都留在这台电脑上。';

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
  String get cleanSamePicture => '同样的图片';

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
  String get cleanSavedToYourGalleryDesk => '已保存到你选择的位置。';

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
  String get contactStaysOnThisPhoneDesk => '只保存在这台电脑上。对方永远看不到。';

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
  String get contactMessagesAndContactGoneDesk => '消息和联系人都会从这台电脑上消失';

  @override
  String get contactDeleteThisChat => '删除这个聊天？';

  @override
  String get contactEveryMessageAndThe => '每一条消息和这位联系人都会从这部手机上消失。不会向对方发送任何内容。';

  @override
  String get contactEveryMessageAndTheDesk =>
      '每一条消息和这位联系人都会从这台电脑上消失。不会向对方发送任何内容。';

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
  String get donateBackItAnonymouslyBadge => '匿名支持它。徽章自愿领取。\n*所有隐私功能都免费。*';

  @override
  String get donateAuditTitle => '帮忙资助一次安全审计';

  @override
  String get donateAuditLine => '在这里的捐款会用于一次独立审计。完整报告将会公开。';

  @override
  String get donateCard => '银行卡';

  @override
  String get donateCardOneTime => '在浏览器中进行的一次性捐款，金额由你决定。';

  @override
  String get donateCardMarios => '在我们的财务托管方设立好之前，银行卡付款会直接转给 Marios。';

  @override
  String get donateCardSeesName => '支付公司能看到你的姓名。加密货币才是私密的选择。';

  @override
  String get donateCardPay => '用银行卡支付';

  @override
  String get donateNoBitcoinCard => '没有 Bitcoin？用银行卡支付';

  @override
  String get donateCardNoBadge => '银行卡捐款不会解锁徽章。';

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
      '要验证这条链，我们就得向外部服务获取你的情况，所以我们不验证。你愿意的话照样可以发送。它不会解锁徽章。';

  @override
  String get donateBitcoinBadgesNeedOnion => 'Bitcoin 徽章需要 onion 模式';

  @override
  String get donateSwitchToOnion => '切换到 onion';

  @override
  String get donatePayWithBitcoin => '用 bitcoin 支付  →';

  @override
  String get donateBadgesStartAt20 => '徽章 \$20 起';

  @override
  String get donateShowTheAddress => '显示地址';

  @override
  String donateReviewAmount(String amount) {
    return '$amount，以 bitcoin 支付';
  }

  @override
  String get donateWhatTheBadgeGives => '徽章能给你什么';

  @override
  String get donateGivesMark => '名字旁边的一个标记。给谁看、给不给人看，都由你决定。';

  @override
  String get donateGivesReceipt => '一张保存在这台手机上的签名收据。无需任何账号即可证明徽章。';

  @override
  String get donateGivesReceiptDesk => '一张保存在这台电脑上的签名收据。无需任何账号即可证明徽章。';

  @override
  String get donateGivesFree => '无论有没有徽章，所有隐私功能都一直免费。';

  @override
  String get donateAddressOnTap => '点下方按钮时才会生成地址。它在一小时内都归你，回来时还是同一个。';

  @override
  String get donateBitcoinBusy => 'Bitcoin 现在很忙。请稍后再试，或用银行卡支付。';

  @override
  String get donateBusyPlainAddress => '你仍然可以向下方地址发送 bitcoin，但不会获得徽章。';

  @override
  String get donateSameAddressAgain => '这是你之前打开的地址。如果已经发送，请在这里等待。';

  @override
  String get donateReachingThePaymentService => '正在经由 Tor 连接支付服务…';

  @override
  String get donateThisCanTakeUp => '可能需要一两分钟';

  @override
  String donateSThisCanTake(Object waited) {
    return '$waited 秒 · 可能需要一两分钟';
  }

  @override
  String get donateUseTheAddressInstead => '改用地址';

  @override
  String get donateThePaymentServiceIs =>
      '支付服务是一个 onion 服务，只有 onion 模式才能连上。现在什么都没有发送。';

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
  String get donateNoWallet => '这部手机上没有能打开 bitcoin 链接的应用。请改为复制地址。';

  @override
  String get donateChecking => '正在检查…';

  @override
  String get donateNotSeenYet => '还没看到。付款可能要几分钟才会显示。';

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
  String donateVerifiedBadgeStays(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter': '已在链上验证。感谢你再次支持。你的支持者徽章保持不变。',
      'patron': '已在链上验证。感谢你再次支持。你的赞助人徽章保持不变。',
      'guardian': '已在链上验证。感谢你再次支持。你的守护者徽章保持不变。',
      'other': '已在链上验证。感谢你再次支持。你的支持者徽章保持不变。',
    });
    return '$_temp0';
  }

  @override
  String get donateWearMyBadge => '佩戴我的徽章';

  @override
  String get donateJustGladToHelp => '能帮上忙就好';

  @override
  String get gettingMessagesAlwaysOn => '始终在线';

  @override
  String get gettingMessagesMostPrivate => '最私密';

  @override
  String get gettingMessagesMessagesArriveInstantlyNothing =>
      '最耗电。\n即时送达，任何东西都不会离开 Tor。';

  @override
  String get gettingMessagesArriveInstantlyFast => '最耗电。\n在快速模式下即时送达。';

  @override
  String get gettingMessagesCheckIns => '定时查收';

  @override
  String get gettingMessagesLightest => '最省电';

  @override
  String get gettingMessagesKryfoLooksForMessages =>
      'Kryfo 每 15 分钟查收一次，所以消息可能会晚到。\n省电。';

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
  String get groupChatYou => '你';

  @override
  String get groupChatVoiceMessage => '语音消息';

  @override
  String get groupChatQuotedPhoto => '照片';

  @override
  String get groupChatMessageUnavailable => '消息不可用';

  @override
  String get groupChatTorIsNotUp => 'Tor 还没连上 · 不添加链接预览';

  @override
  String get groupChatCouldnTReachIt => '无法访问该页面 · 不添加链接预览';

  @override
  String get groupChatNoTitleCameBack => '该页面没有标题 · 不添加链接预览';

  @override
  String get groupChatCouldnTFetchIt => '无法加载预览';

  @override
  String get groupChatCamera => '相机';

  @override
  String get groupChatGallery => '相册';

  @override
  String get groupChatVideo => '视频';

  @override
  String get groupChatGifFromPhone => '手机里的 GIF';

  @override
  String get groupChatGifFromPhoneDesk => '电脑里的 GIF';

  @override
  String get groupChatFile => '文件';

  @override
  String get groupChatCouldNotReadThat => '无法读取这个文件';

  @override
  String get groupChatGifTooBig8 => 'GIF 太大 · 最大 8 MB';

  @override
  String get groupChatCouldNotCleanThat => '无法清理这个 GIF';

  @override
  String get groupChatCouldNotCleanThatVideo => '无法清理这个视频';

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
  String get groupChatNewMessagesDisappearOnceRead =>
      '新消息在被读后经过这段时间消失。你发出的从发送时开始计时。';

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
  String get groupChatItDisappearsWithNo => '它会从所有人的手机上删除，除非已被保存。此操作无法撤销。';

  @override
  String get groupChatItDisappearsWithNoDesk => '它会从所有人的设备上删除，除非已被保存。此操作无法撤销。';

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
  String get groupChatEveryoneHereReads => '这里的每个人都能看到你写的内容。';

  @override
  String get groupChatNobodyHereYet => '这里还没有人。';

  @override
  String get groupChatShareTheRoomLink => '分享聊天室链接。加入的人从那时起能看到写下的内容。';

  @override
  String get groupChatNobodyToReadIt => '这里没有其他人能看到。';

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
  String get groupChatSupporter => '支持者';

  @override
  String get groupChatEdited => '已编辑';

  @override
  String get groupChatTapToRetry => '! 点击重试';

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
      other: '已发送 · $countString 人中 $haveString 人已收到',
      zero: '已发送 · 正在送达',
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
      other: '已发送 · $countString 人未收到',
    );
    return '$_temp0';
  }

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
  String get groupInfoResetLink => '重置链接';

  @override
  String get groupInfoResetTheRoomLink => '要重置聊天室链接吗？';

  @override
  String get groupInfoResetLinkLine => '旧链接将失效。聊天室里的人会留下，并收到新链接。';

  @override
  String get groupInfoRemoveRoomLine =>
      '对方仍可通过聊天室链接重新加入。重置链接即可把对方挡在外面。仍在聊天室里的人会收到新链接。';

  @override
  String get groupInfoRemoveAndResetLink => '移除并重置链接';

  @override
  String get groupInfoCouldNotResetLink => '无法重置链接';

  @override
  String get roomLinkNewLinkTheOld => '新链接。旧链接已失效。';

  @override
  String appGroupHoldsUpTo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '一个群组最多 $countString 人',
    );
    return '$_temp0';
  }

  @override
  String get commonRemove => '移除';

  @override
  String get groupInfoClearThisConversation => '清空这段聊天记录？';

  @override
  String get groupInfoEveryMessageHereIs =>
      '这里的每条消息都会从这部手机上清除。这只清除你的副本，其他成员的还在。';

  @override
  String get groupInfoEveryMessageHereIsDesk =>
      '这里的每条消息都会从这台电脑上清除。这只清除你的副本，其他成员的还在。';

  @override
  String get groupInfoClear => '清空';

  @override
  String get groupInfoConversationCleared => '聊天记录已清空';

  @override
  String get groupInfoLeaveRoom => '退出聊天室？';

  @override
  String get groupInfoLeaveGroup => '退出群组？';

  @override
  String get groupInfoEverythingInItIs => '里面的一切会立即从这部手机上抹除，你在这里用过的密钥也会永久消失。';

  @override
  String get groupInfoEverythingInItIsDesk =>
      '里面的一切会立即从这台电脑上抹除，你在这里用过的密钥也会永久消失。';

  @override
  String groupChatYouWereRemovedFrom(Object name) {
    return '你已被移出 $name';
  }

  @override
  String get groupInfoLeaveGroupLine => '你将不再收到它的消息，里面的一切也会从这部手机上抹除。';

  @override
  String get groupInfoLeaveGroupLineDesk => '你将不再收到它的消息，里面的一切也会从这台电脑上抹除。';

  @override
  String get groupInfoLeaveGroupAdmin =>
      '你将不再收到它的消息，里面的一切也会从这部手机上抹除。你是管理员，退出后就没有人能再增减成员或重命名了。';

  @override
  String get groupInfoLeaveGroupAdminDesk =>
      '你将不再收到它的消息，里面的一切也会从这台电脑上抹除。你是管理员，退出后就没有人能再增减成员或重命名了。';

  @override
  String get groupInfoLeaveRoomMaker =>
      '里面的一切会立即从这部手机上抹除，你在这里用过的密钥也会永久消失。这个聊天室是你创建的，你退出后它的链接就不能再让人加入了。';

  @override
  String get groupInfoLeaveRoomMakerDesk =>
      '里面的一切会立即从这台电脑上抹除，你在这里用过的密钥也会永久消失。这个聊天室是你创建的，你退出后它的链接就不能再让人加入了。';

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
  String get handleHintName => 'name';

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
  String handleDeleteTitle(Object handle) {
    return '删除 @$handle？';
  }

  @override
  String get handleDeleteLine => '你的公开页面会消失，任何人都可以认领这个名字。已有的聊天保持不变。';

  @override
  String get handleDeleteYes => '删除用户名';

  @override
  String get handleDeleting => '正在删除…';

  @override
  String get handleChecking => '正在检查…';

  @override
  String get handleAvailable => '✓ 可用';

  @override
  String get handleAlreadyTaken => '已被占用';

  @override
  String get handleNameRule => '3 到 20 个字符：a-z、0-9 或 _';

  @override
  String get handleWhatAHandleDoes => '用户名有什么用';

  @override
  String get handleAnyoneWhoKnowsIt =>
      '任何知道它的人都可以请求给你发消息。这个页面只保存你的邀请和你写的那句话，别无其他，也不会记录谁看过它。你随时可以删除它。';

  @override
  String handleIsNotYoursOn(Object handle) {
    return '在这部手机上，@$handle 不属于你';
  }

  @override
  String handleIsNotYoursOnDesk(Object handle) {
    return '在这台电脑上，@$handle 不属于你';
  }

  @override
  String handleTheRegistryHoldsIt(Object handle) {
    return '登记处用另一把密钥保存着它，很可能是这部手机在恢复之前的身份。添加 @$handle 的人联系不到你。在这里无法释放或更新它。请换一个名字。';
  }

  @override
  String handleTheRegistryHoldsItDesk(Object handle) {
    return '登记处用另一把密钥保存着它，很可能是这台电脑在恢复之前的身份。添加 @$handle 的人联系不到你。在这里无法释放或更新它。请换一个名字。';
  }

  @override
  String get handleForgetItOnThis => '在这部手机上忘掉它';

  @override
  String get handleForgetItOnThisDesk => '在这台电脑上忘掉它';

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
  String get homeKeepWaiting => '继续等待';

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
  String get homeNoKryfosYet => '还没有 Kryfo 联系人。';

  @override
  String get homeScanTheirCodeSend => '扫描对方的二维码、给对方发链接，或者输入对方给你的 @用户名。';

  @override
  String get homeScanTheirCodeSendDesk => '给对方发链接，或者输入对方给你的 @用户名。';

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
  String get homeMessagesAndContactGoneDesk => '消息和联系人都会从这台电脑上消失';

  @override
  String get homeDeleteThisChat => '删除这个聊天？';

  @override
  String homeEveryMessageWithGoes(Object c) {
    return '和 $c 的每一条消息都会删除，对方也不再是你的联系人。这只清除这部手机上的内容——对方的副本还留在对方那里。如果对方再发消息，会进入请求列表。';
  }

  @override
  String homeEveryMessageWithGoesDesk(Object c) {
    return '和 $c 的每一条消息都会删除，对方也不再是你的联系人。这只清除这台电脑上的内容——对方的副本还留在对方那里。如果对方再发消息，会进入请求列表。';
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
  String get homeOnlyOnThisPhoneDesk => '只在这台电脑上';

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
  String introduceIntroduced(Object b, Object c) {
    return '$b 和 $c 现在都有对方的名片了';
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
  String get keyVerificationNewNumber => '此页面打开期间，安全码变更了。这是新的安全码，请再比对一次。';

  @override
  String get keyVerificationKeyMoved => '安全码刚刚变更了，请比对新的安全码。';

  @override
  String keyVerificationNoKeyYet(Object peerName) {
    return '还没有 $peerName 的密钥。对方给你发消息后，安全码就会显示在这里。';
  }

  @override
  String keyVerificationWith(Object peerName) {
    return '与 $peerName';
  }

  @override
  String keyVerificationCompareAll(Object peerName) {
    return '和 $peerName 核对全部 12 组数字，当面或通过你信任的通话。每一组都一致，就说明中间没有别人，你们的消息只属于你们两个人。';
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
  String get lockFileCheckCapitalsAndSpaces => '检查大小写和空格。没有人能重置它。';

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
  String get lockFileEverythingStaysOnThisDesk => '一切都留在这台电脑上。';

  @override
  String get lockFileCouldNotMakeOne => '没能生成。请自己输入一个。';

  @override
  String get lockFileWriteItDownBefore => '锁定文件之前，先把它写下来';

  @override
  String get lockFileNoAppOnThis => '这部手机上没有应用接收这个文件。';

  @override
  String get linkNoAppOpens => '这台手机上没有可以打开此链接的应用。';

  @override
  String get linkNoAppOpensDesk => '这台电脑上没有可以打开此链接的应用。';

  @override
  String get placeStubLocation => '位置';

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
  String get lockFileSaveToFilesDesk => '保存文件';

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
      '任何知道密码的人都能打开它，在 Kryfo 里，或者在任何装了免费工具 age 的电脑上。忘了密码，这个文件就永远打不开了。没有人能重置它。';

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
  String get lockSetupTurningOn => '正在开启…';

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
  String get modesFast => '快速';

  @override
  String get modesNotChanged => '模式没有更改，请重试。';

  @override
  String get modesSwitching => '正在切换…';

  @override
  String get modesSpeed => '速度';

  @override
  String get modesPrivacy => '与隐私';

  @override
  String get movedWipeThisPhone => '要从这部手机上抹除 Kryfo 吗？';

  @override
  String get movedWipeThisPhoneDesk => '要从这台电脑上抹除 Kryfo 吗？';

  @override
  String get movedEverythingKryfoHoldsHere =>
      'Kryfo 在这里保存的一切都会被抹除：消息、联系人、密钥。另一台设备保留着全部内容。此操作无法撤销。';

  @override
  String get movedWipeIt => '抹除';

  @override
  String get movedNotMovingAfterAll => '不迁移了？';

  @override
  String get movedOnlyDoThisIf =>
      '只有在这个备份从未在任何地方导入过时才这么做。如果导入过，现在就有两台设备持有同一个身份，两边都会开始丢失新消息。';

  @override
  String get movedIMStayingHere => '我留在这里';

  @override
  String get movedStayingHere => '留在这里';

  @override
  String movedKryfoWillCloseNow(Object myId) {
    return 'Kryfo 现在会关闭。点击图标，以 $myId 的身份重新打开。';
  }

  @override
  String movedKryfoWillCloseNowDesk(Object myId) {
    return 'Kryfo 现在会关闭。再次启动它，以 $myId 的身份打开。';
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
  String movedIsNowOnAnotherDesk(Object myId) {
    return '$myId 现在在另一台设备上。这台电脑仍能显示这里原有的内容，但不会再收到任何新东西，你从这里发出的任何东西也送不到任何人。';
  }

  @override
  String get movedKeepItToRead => '留着查看';

  @override
  String get movedWipeThisPhone2 => '从这部手机上抹除 Kryfo';

  @override
  String get movedWipeThisPhone2Desk => '从这台电脑上抹除 Kryfo';

  @override
  String get movedIMNotMoving => '我不迁移了';

  @override
  String get myKryfoAHandleIs3 => '用户名由 3 到 20 个字母、数字或 _ 组成';

  @override
  String get myKryfoInviteCopiedClearsIn => '邀请已复制 · 60 秒后清除';

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
  String get myKryfoPointYourPhonesAtDesk => '对方用手机扫描这个二维码。不经过任何服务器。';

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
      '链接里有你的三个词、你的地址和开始聊天所需的密钥。在你到设置里重置它之前，它一直有效。';

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
  String get newGroupNeedsContacts => '群组由你的联系人组成';

  @override
  String get newGroupAddSomeoneFirst => '请先添加联系人。聊天室不需要联系人：有链接的人都能加入。';

  @override
  String get notesDeleteThisNote => '删除这条笔记？';

  @override
  String get notesHoldHint => '长按一条笔记即可复制或删除。';

  @override
  String get notesMenu => '笔记菜单';

  @override
  String get notesDeleteAll => '删除全部笔记';

  @override
  String get notesDeleteAllTitle => '删除全部笔记？';

  @override
  String get notesDeleteAllLine => '这部手机上的所有笔记都会被永久删除。';

  @override
  String get notesDeleteAllLineDesk => '这台电脑上的所有笔记都会被永久删除。';

  @override
  String get notesDeleteAllYes => '全部删除';

  @override
  String get notesThisWeek => '本周';

  @override
  String get notesShowMore => '展开';

  @override
  String get notesShowLess => '收起';

  @override
  String get notesGoneFromThisPhone => '它会从这部手机上永久清除。';

  @override
  String get notesGoneFromThisPhoneDesk => '它会从这台电脑上永久清除。';

  @override
  String get notesNoteToSelf => '给自己的笔记';

  @override
  String get notesOnlyOnThisPhone => '只在这部手机上';

  @override
  String get notesOnlyOnThisPhoneDesk => '只在这台电脑上';

  @override
  String get notesAQuietPlace => '一个安静的角落';

  @override
  String get notesJotAnythingDownIt => '随手记下任何东西。它留在这部手机上，绝不会离开。';

  @override
  String get notesJotAnythingDownItDesk => '随手记下任何东西。它留在这台电脑上，绝不会离开。';

  @override
  String get notesJotSomethingDown => '记点什么…';

  @override
  String get notesExportNotes => '导出笔记';

  @override
  String get notesExport => '导出';

  @override
  String get notesExportWorking => '正在导出…';

  @override
  String notesExportCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 条笔记，从最早的开始。',
    );
    return '$_temp0';
  }

  @override
  String get notesExportZip => '照片和语音会和它们一起放进一个 zip。';

  @override
  String get notesExportText => '纯文本';

  @override
  String get notesExportTextLine => '在哪儿都能打开的 .txt 文件';

  @override
  String get notesExportMarkdown => 'Markdown';

  @override
  String get notesExportMarkdownLine => '带标题的 .md 文件，适合笔记应用';

  @override
  String get notesExportLock => '用密码短语锁定';

  @override
  String get notesExportLockLine => '在“工具”里用“打开锁定的文件”打开，或在电脑上用 age 打开';

  @override
  String get notesExportPlainTitle => '不用密码短语导出？';

  @override
  String get notesExportPlainLine => '任何拿到这个文件的人都能读到内容。';

  @override
  String get notesExportPlainYes => '不加密导出';

  @override
  String get notesExportKeepLock => '保留密码短语';

  @override
  String get notesExportNotSaved => '笔记没有保存。文件还在。';

  @override
  String get notesExportGone => 'Kryfo 锁定时，文件已清除。再导出一次即可生成新文件。';

  @override
  String get notesExportHoldsInstaller => '这份导出里有一个应用安装包，所以不能分享。请改为保存到手机上。';

  @override
  String get notesExportHoldsInstallerDesk =>
      '这份导出里有一个应用安装包，所以不能分享。请改为保存到这台电脑上。';

  @override
  String get notesExportSaved => '笔记已保存';

  @override
  String notesExportSavedIn(String place) {
    return '笔记已保存到 $place';
  }

  @override
  String get notesExportSavedUnchecked => '笔记已保存，但 Kryfo 无法检查这份副本';

  @override
  String get notesExportFailed => '无法导出笔记。什么都没有保存。';

  @override
  String get notesExportTooLarge => '太大了，无法导出。照片和语音加起来有 4 GB 或更多。';

  @override
  String get notesExportSubject => 'Kryfo 笔记';

  @override
  String get onboardingPrivateByDefault => '默认私密';

  @override
  String get onboardingPrivateMessaging => '私密聊天，\n*没有套路*。';

  @override
  String get onboardingYourNameIsThree => '*你的名字就是三个词。*\n不要手机号，不要邮箱，不要通讯录。';

  @override
  String get onboardingNobodyGetsInUnless =>
      '*除非你允许，否则谁也进不来。*\n没有公开的 @名字，谁也搜不到你。\n陌生人只能敲门。';

  @override
  String get onboardingTheFirstConnectionTakes =>
      '*首次连接需要一分钟。*\nKryfo 会先建立一条私密路线。之后就快了。';

  @override
  String get onboardingBegin => '开始';

  @override
  String get onboardingHaveABackupRestore => '有备份？恢复 →';

  @override
  String get onboardingKryfoIsOpenSource => 'Kryfo 是开源的';

  @override
  String get onboardingYourKryfoId => '你的名字';

  @override
  String get onboardingGeneratedFromAKey => '由一把只存在于这部手机上的密钥生成。\n*别人都没有这组词。*';

  @override
  String get onboardingGeneratedFromAKeyDesk =>
      '由一把只存在于这台电脑上的密钥生成。\n*别人都没有这组词。*';

  @override
  String get onboardingTryAnother => '换一个';

  @override
  String get onboardingUseThisName => '用这个名字 →';

  @override
  String get onboardingThreeWords => '三个词。*只属于你。*';

  @override
  String get onboardingContinue => '继续 →';

  @override
  String get onboardingKryfoBuildsAPrivateRouteBefore =>
      'Kryfo 在发送任何内容之前，都会先建立一条私密路线。你离线时，消息会等着，等你回来再送达。';

  @override
  String get onboardingYourIdentityLivesOn => '你的身份保存在这部手机上。\n准备好后，可以在设置里备份它。';

  @override
  String get onboardingYourIdentityLivesOnDesk =>
      '你的身份保存在这台电脑上。\n准备好后，可以在设置里备份它。';

  @override
  String get onboardingSilentAndAtThe => '静音，位于通知栏最底部';

  @override
  String get onboardingItNeverBuzzesTurn => '它从不振动。\n关掉它的话，消息会一直等到你打开 Kryfo。';

  @override
  String get onboardingGotIt => '知道了 →';

  @override
  String get onboardingEveryWayToAdd => '所有添加方式';

  @override
  String get onboardingShowYourCodeSend => '出示你的二维码、分享链接，或者输入对方的 @名字。';

  @override
  String get onboardingScanTheirs => '扫描对方的';

  @override
  String get onboardingPointTheCameraAt => '把相机对准对方的二维码';

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
  String get openLockedItOpensOnThisDesk => '它会在这台电脑上打开。';

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
  String get pairCodeLooking => '正在查找…';

  @override
  String get pairCodeNothingThereYetTrying => '那里还没有 · 正在重试';

  @override
  String get pairCodeNothingAtThatCode => '这个码下面什么都没有。它可能已经焚毁，或者对方还没有分享。';

  @override
  String get pairCodeUnreached => '联系不上中继。请稍后再试。';

  @override
  String get fastRoomsWaitForTor => '聊天室、配对码和首次联系始终通过 Tor，快速模式下也一样。Tor 一连上就能用。';

  @override
  String get pairCodeFailed => '没有成功。请再试一次。';

  @override
  String get pairCodeAddThem => '添加对方';

  @override
  String get pairCodeKeyNumber => '密钥号码';

  @override
  String get pairCodeNotAdded => '未添加。请对方重新生成一个码。';

  @override
  String get pairCodeEightDigits => '八位数字';

  @override
  String get pairCodeTypeTheEightDigits => '输入对方念出的八位数字。';

  @override
  String get pairCodeOldCode => '这个码来自较旧的 Kryfo。两部手机都需要 Kryfo 0.6 或更新版本。';

  @override
  String get pairCodeOldCodeDesk => '这个码来自较旧的 Kryfo。两台设备都需要 Kryfo 0.6 或更新版本。';

  @override
  String get pairCodeBothNeed06 => '两部手机都需要 Kryfo 0.6 或更新版本。';

  @override
  String get pairCodeBothNeed06Desk => '两台设备都需要 Kryfo 0.6 或更新版本。';

  @override
  String get pairCodeWaitingForThem => '正在等待对方…';

  @override
  String get pairCodeStillWaiting => '还在等待。如果对方屏幕显示输入了错误的码，请一起核对数字。';

  @override
  String get pairCodeUnanswered => '没有收到回应。请和对方核对码，然后重新输入。';

  @override
  String get pairCodeTooManyTries => '这个码已经试了三次。请对方重新生成一个。';

  @override
  String get pairCodeRanOut => '这个码已过期。请对方重新生成一个。';

  @override
  String get pairCodeMatched => '码已匹配。要互相添加吗？';

  @override
  String get pairCodeNotThem => '不是对方';

  @override
  String get pairCodePanelReadEightDigitsOut => '把八位数字念出来，你们就能互相添加。其他什么都不需要交换。';

  @override
  String get pairCodePanelOrMakeACode => '或者生成一个码，念给对方';

  @override
  String get pairCodePanelTheyOpenKryfoEight =>
      '对方打开 Kryfo，点“添加”，选择“配对码”，输入这八位数字。下一个人需要你再生成一个新的。';

  @override
  String get pairCodePanelWrongTyped => '对方输入了错误的码。请再慢慢念一遍。';

  @override
  String get pairCodePanelThreeWrong => '错误的码已输入三次，这个码已停止使用。请生成一个新的。';

  @override
  String get pairCodePanelNotAdded => '未添加。对方准备好时再生成一个新码。';

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
  String get photoKnowsVideoCleaner => '视频清理';

  @override
  String get photoKnowsPhotoCleaner => '照片清理';

  @override
  String get photoKnowsRemoveAllOfIt => '全部移除';

  @override
  String get photoKnowsKeepItAsIt => '保持原样';

  @override
  String get photoKnowsReadOnThisPhone => '在这部手机上读取 · 视频哪儿也没去';

  @override
  String get photoKnowsReadOnThisPhoneDesk => '在这台电脑上读取 · 视频哪儿也没去';

  @override
  String get photoKnowsReadOnThisPhoneThePhoto => '在这部手机上读取 · 照片哪儿也没去';

  @override
  String get photoKnowsReadOnThisPhoneThePhotoDesk => '在这台电脑上读取 · 照片哪儿也没去';

  @override
  String get photoKnowsReadingTheFile => '正在读取文件';

  @override
  String photoKnowsOf(Object prettySize, Object prettySize2) {
    return '$prettySize / $prettySize2';
  }

  @override
  String get photoKnowsEverythingStaysOnThis => '一切都留在这部手机上。';

  @override
  String get photoKnowsEverythingStaysOnThisDesk => '一切都留在这台电脑上。';

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
      'PIN 码会被移除，抹除 PIN 和所有隐藏聊天也一起移除。任何拿着你手机的人都能以你的身份打开 Kryfo。';

  @override
  String get pinsThePinGoesAndDesk =>
      'PIN 码会被移除，抹除 PIN 和所有隐藏聊天也一起移除。任何用你电脑的人都能以你的身份打开 Kryfo。';

  @override
  String get pinsUnlockWithFingerprint => '用指纹解锁';

  @override
  String get pinsFingerOpensDecoy => '设置伪装 PIN 后关闭：手指只会打开伪装。';

  @override
  String get pinsWipePin => '抹除 PIN';

  @override
  String get pinsNeedsAPinFirst => '需要先设置 PIN 码';

  @override
  String get pinsSet => '已设置';

  @override
  String get pinsChangeWipePin => '更改抹除 PIN';

  @override
  String get pinsRemove => '移除';

  @override
  String get pinsRemoveTheWipePin => '移除抹除 PIN？';

  @override
  String get pinsTheLockScreenKeeps => '锁屏仍使用你的 PIN 码。抹除 PIN 将不再起任何作用。';

  @override
  String profileCopied(Object what) {
    return '$what已复制';
  }

  @override
  String get profileProfile => '个人资料';

  @override
  String get profileKryfoId => '你的名字';

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
  String get qrMadeOnThisPhoneDesk => '在这台电脑上生成 · 没有网站看到密码';

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
  String get qrCouldNotSaveItDesk => '无法保存。请检查电脑还有没有空间。';

  @override
  String get qrNoAppOnThis => '这部手机上没有应用可以接收这张图片。';

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
  String get requestsRequests => '请求';

  @override
  String get requestsNoRequests => '没有请求';

  @override
  String get requestsMessagesFromPeopleYou => '你还没添加的人发来的消息，会先出现在这里。';

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
  String get restoreReplaceTheAccountOnDesk => '替换这台电脑上的账号？';

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
  String restoreTheRegistryDidNotDesk(Object mine) {
    return '登记处没有响应。如果你继续，@$mine 仍会指向这台电脑即将失去的身份。任何添加它的人发出的消息都没有人会收到，而且这个名字无法再被认领。最好先联网，再试一次。';
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
  String restoreKryfoWillCloseNowDesk(Object haloId) {
    return 'Kryfo 现在会关闭。再次启动它，以 $haloId 的身份打开。';
  }

  @override
  String get restorePrivacyKept => '你的隐私设置会随备份一起回来。PIN 码永远不会随之转移：请在设置里重新设定。';

  @override
  String get restoreCheckProtections => '备份不包含设置。Kryfo 重新打开后，请在设置里检查“你的保护”。';

  @override
  String get restoreReopenKryfo => '重新打开 Kryfo';

  @override
  String get restoreTheRestoreDidNot => '恢复没有完成。没有做任何改动';

  @override
  String get restoreKryfoClosesRestoreAgain =>
      '这里的部分数据已经被替换。Kryfo 现在会关闭。请重新打开，再恢复一次这个文件。';

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
  String get restoreAnythingSentToYouDesk => '旧设备关机期间发给你的任何内容，只要是在十四天内发出的。';

  @override
  String get restoreYourSupporterBadgeIf => '你的支持者徽章（如果有的话）。';

  @override
  String get restoreWhatDoesnT => '不会跟过来的';

  @override
  String get restoreTheOldPhoneStops =>
      '从你在这里发出任何内容的那一刻起，旧手机就不再接收消息。你从这台设备发出的第一条消息，是旧手机能跟上的最后一条；在那之后到达旧手机的任何内容，在那里都无法读取，在这里也不会等着你。';

  @override
  String get restoreTheOldPhoneStopsDesk =>
      '从你在这里发出任何内容的那一刻起，旧设备就不再接收消息。你从这台电脑发出的第一条消息，是旧设备能跟上的最后一条；在那之后到达旧设备的任何内容，在那里都无法读取，在这里也不会等着你。';

  @override
  String get restoreIfThePhoneThis =>
      '如果这个文件来自的那部手机还在使用，请先在那部手机上停用 Kryfo，再继续。两部手机共用一个 Kryfo，两边都会丢消息。';

  @override
  String get restoreIfThePhoneThisDesk =>
      '如果这个文件来自的那台设备还在使用，请先在那台设备上停用 Kryfo，再继续。两台设备共用一个 Kryfo，两边都会丢消息。';

  @override
  String get restoreNotificationsNeedSettingUp => '通知需要在这台设备上重新设置。';

  @override
  String get restoreDeletedComeBack =>
      '这个备份制作之后你删除的聊天会随它回来，那些联系人可能会看到你重新设置了 Kryfo。';

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
  String get restoreABackupBringsBackDesk =>
      '备份能找回你的身份和联系人，以及制作文件时设备上已有的消息。之后说的内容不在里面。';

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
  String get restoreStopRestore => '停止恢复';

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
  String get roomCreateARoomThatEndsDesk =>
      '一个会结束的聊天室。每个人都用专为它生成的密钥加入，结束时任何设备上都不会留下任何东西。';

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
  String roomCreateOffUpTo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '关。任何拿到链接的人，最多 $countString 人',
    );
    return '$_temp0';
  }

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
  String get savedChatGone => '那个聊天已不在这部手机上';

  @override
  String get savedChatGoneDesk => '那个聊天已不在这台电脑上';

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
  String get seenEveryMessengerClaimsPrivacy => '这是按线路列出的清单，也包括薄弱之处。点一行查看原因。';

  @override
  String get seenHonestAboutTheLast =>
      '最后几行正是应用锁、抹除 PIN 和加密存储要应对的，而当有人拿着你已解锁的手机时，没有任何工具能救你。完整的威胁模型在代码仓库的 THREAT_MODEL.md 里，按 LINDDUN 编写。代码是开源的，你可以自己核实这些。';

  @override
  String get seenHonestAboutTheLastDesk =>
      '最后几行正是应用锁、抹除 PIN 和加密存储要应对的，而当有人坐在你已解锁的电脑前时，没有任何工具能救你。完整的威胁模型在代码仓库的 THREAT_MODEL.md 里，按 LINDDUN 编写。代码是开源的，你可以自己核实这些。';

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
      '每段对话都有自己的地址，由双方的密钥推导而来。中继看到的是一个个互不相关的投递点，而不是一对人。在快速模式下，我们的服务器能看到你所用投递点上的 IP 地址；如果对话双方都用快速模式，还能看到两个 IP 地址共用一个投递点。';

  @override
  String get seenWhatYouSay => '你说了什么';

  @override
  String get seenEndToEndEncrypted =>
      '用 Signal 双棘轮端到端加密，然后再用 gift wrap 封装一层。我们读不了。';

  @override
  String get seenYourIpAddress => '你的 IP 地址';

  @override
  String get seenYourContactGraph => '你的联系人关系图';

  @override
  String get seenKryfoDoesNotScan =>
      'Kryfo 不会扫描你的通讯录。这里根本没有手机号可以泄露。在快速模式下，我们的服务器可以根据哪些 IP 地址共用投递点拼凑出其中一部分，但不会留下任何记录。';

  @override
  String get seenIntroducer => '介绍人';

  @override
  String get seenWhenAContactIntroduces =>
      '当一位联系人把你介绍给某人时，这位联系人会知道你们两个现在有联系了。其他人都不会知道。中继看到的是密文，任何服务器都永远看不到关系图。';

  @override
  String get seenTheScamShield => '防骗盾';

  @override
  String get seenScamShieldRequestsOnly =>
      '在你的手机上运行，规则随应用一起提供。不联网，不下载任何名单。它只读取陌生人的消息请求，从不读取联系人或群组发给你的内容。';

  @override
  String get seenScamShieldRequestsOnlyDesk =>
      '在你的电脑上运行，规则随应用一起提供。不联网，不下载任何名单。它只读取陌生人的消息请求，从不读取联系人或群组发给你的内容。';

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
      '预览由发送方经由 Tor 获取，并放在加密消息里一起传送。接收方的手机不会发出任何请求。网站只知道有个用 Tor 的人请求了一个页面，别的都不知道。永远不会加载任何图片，陌生人发来的链接只显示为纯文本。';

  @override
  String get seenAPreviewIsFetchedDesk =>
      '预览由发送方经由 Tor 获取，并放在加密消息里一起传送。接收方的设备不会发出任何请求。网站只知道有个用 Tor 的人请求了一个页面，别的都不知道。永远不会加载任何图片，陌生人发来的链接只显示为纯文本。';

  @override
  String get seenASeizedUnlockedPhone => '被夺走的已解锁手机';

  @override
  String get seenASeizedUnlockedPhoneDesk => '被夺走的已解锁电脑';

  @override
  String get seenIfSomeoneHoldsYour =>
      '如果有人拿着你已解锁的手机，他们就能读你的消息。应用锁、抹除 PIN 和加密存储在那之前有用，在那之后就没用了。';

  @override
  String get seenIfSomeoneHoldsYourDesk =>
      '如果有人坐在你已解锁的电脑前，他们就能读你的消息。应用锁、抹除 PIN 和加密存储在那之前有用，在那之后就没用了。';

  @override
  String get seenTheCryptoItself => '加密本身';

  @override
  String get seenTheRatchetAndStorage =>
      '棘轮层和存储层都是标准实现。连接它们的那一层是我们自己写的，还没有任何独立第三方审查过。这是 alpha 版本。';

  @override
  String get seenFast => '快速';

  @override
  String get settingsWipeKryfo => '抹除 Kryfo？';

  @override
  String get settingsIdentityMessagesContactsAnd =>
      '这部手机上的身份、消息、联系人和设置。除非你有备份，否则将永久消失。';

  @override
  String get settingsIdentityMessagesContactsAndDesk =>
      '这台电脑上的身份、消息、联系人和设置。除非你有备份，否则将永久消失。';

  @override
  String get commonContinue => '继续';

  @override
  String settingsTypeWipeToConfirm(Object word) {
    return '输入“$word”以确认';
  }

  @override
  String get settingsTheLastStepNothing => '最后一步。什么都不会留下。';

  @override
  String get settingsWipeWord => '抹除';

  @override
  String get settingsWipeKryfo2 => '抹除 Kryfo';

  @override
  String get settingsYourProtections => '你的保护';

  @override
  String get settingsTorRouting => 'Tor 路由';

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
  String get settingsOnion3Hops => 'Onion · 3 跳';

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
  String get settingsScamShieldHint => '只在你的手机上检查，什么都不会离开手机';

  @override
  String get settingsScamShieldHintDesk => '只在你的电脑上检查，什么都不会离开电脑';

  @override
  String get typingNow => '正在输入';

  @override
  String get settingsTypingIndicator => '输入状态提示';

  @override
  String get settingsTypingIndicatorHint =>
      '对方在输入时，你们双方都能看到。提示经 Tor 直接发给对方，从不经过中继。';

  @override
  String get settingsTypingOnionOnly => '在 Onion 线路上可用';

  @override
  String get settingsTypingBridgesOff =>
      '使用网桥时关闭：监视你连接的人可能会对上输入提示的信号。关闭网桥后会自动恢复。';

  @override
  String get settingsLightTheme => '浅色主题';

  @override
  String get settingsSameProtectionBrighter => '同样的保护，更明亮';

  @override
  String get settingsAppearance => '外观';

  @override
  String get settingsAccentColour => '强调色';

  @override
  String get settingsColoursAndWallpaper => '颜色和壁纸';

  @override
  String get settingsAppLock2 => '应用锁';

  @override
  String get settingsYourPinAndA => '你的 PIN 码和高级保护';

  @override
  String get settingsPinWipePin => 'PIN 码 · 抹除 PIN';

  @override
  String get settingsBackUpIdentity => '备份身份';

  @override
  String get settingsEncryptedFile => '加密文件';

  @override
  String get settingsRestoreFromBackup => '从备份恢复';

  @override
  String get settingsReplaceCurrent => '替换当前身份';

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
      '任何拿着旧码或旧链接的人，都将无法再通过任何线路联系你。拿到了却从没用过的人，需要你给一个新码。联系人、聊天和历史记录都会保留。';

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
  String get settingsReportAnIssue => '报告问题';

  @override
  String get settingsReportInKryfo => '在 Kryfo 里写';

  @override
  String get settingsReportInKryfoSub => '和 Marios 的聊天。你可以匿名写。';

  @override
  String get settingsReportByEmail => '发送邮件';

  @override
  String get settingsReportByEmailSub => 'gnosiworks@proton.me，用你的邮件应用';

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
      '未经独立审计。Alpha 版——适合测试，还不适合高风险用途。';

  @override
  String get settingsFollowTitle => '关注 GnosiWorks（开发者）';

  @override
  String get settingsFollowBrowserNote => '在你的浏览器中打开，离开 Kryfo。';

  @override
  String get settingsFollowOpen => '打开';

  @override
  String settingsFollowOn(Object name) {
    return '在 $name 关注，离开 Kryfo';
  }

  @override
  String get settingsDangerZone => '危险区';

  @override
  String get settingsWipeKryfoFromThis => '从这部手机上抹除 Kryfo';

  @override
  String get settingsWipeKryfoFromThisDesk => '从这台电脑上抹除 Kryfo';

  @override
  String get toolsMoreTools => '更多工具';

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
  String get toolsEverythingHereHappensOnDesk =>
      '这里的一切都在这台电脑上完成。不上传任何东西，别人也不需要用 Kryfo。';

  @override
  String get toolsPhotoCleaner => '照片清理';

  @override
  String get toolsRemovesHiddenInfo => '清除地点、时间和手机型号等隐藏信息（元数据）';

  @override
  String get toolsPickAPhotoAnd =>
      '选一张照片或一段视频，看看它会泄露什么，然后一键全部去除。也可以从相册分享到 Kryfo。';

  @override
  String get toolsPickAPhotoAndDesk =>
      '选一张照片或一段视频，看看它会泄露什么，然后一键全部去除。也可以拖到这里或直接粘贴。';

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
  String get transportNothingHereLeavesTheDesk =>
      '这里的内容都不会离开电脑。这就是引擎用来决定下一步做什么的状态。';

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
  String get transportWithNoContactsTheDesk =>
      '没有联系人时，应用不会订阅任何中继地址，所以任何消息都到不了你这里。添加一个人就能解决。';

  @override
  String get transportSendAnythingWaitingNow => '立即发送所有待发内容';

  @override
  String get transportSending => '正在发送…';

  @override
  String get transportNothingLeftWaiting => '没有待发内容了';

  @override
  String transportStillWaiting(Object count) {
    return '仍在等待：$count';
  }

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
  String get transportStopKilled => '被系统强制结束';

  @override
  String get transportStopLowMemory => '内存不足';

  @override
  String get transportStopCrashed => '崩溃';

  @override
  String get transportStopNotResponding => '无响应';

  @override
  String get transportStopByYou => '由你停止';

  @override
  String get transportStopByPhone => '由手机停止';

  @override
  String get transportStopBySecurityApp => '由安全应用停止';

  @override
  String get transportStopUpdated => '已更新';

  @override
  String get transportStopBySystem => '由系统停止';

  @override
  String get transportStopTooMuch => '占用过多';

  @override
  String get transportStopPermission => '权限已更改';

  @override
  String get transportStopClosedItself => '自行关闭';

  @override
  String get transportStopOther => '已停止';

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
  String get transportReconnects => '重新连接';

  @override
  String get transportWhyNetwork => '网络变化';

  @override
  String get transportWhyHand => '手动';

  @override
  String get transportWhyRelays => '没有中继回应';

  @override
  String get transportWhyStall => '启动卡住';

  @override
  String get transportWhyTorOff => 'Tor 已关';

  @override
  String get transportWhyDialer => '3 分钟没有中继';

  @override
  String get transportWhyOnion => '回到 Onion';

  @override
  String get transportWhyBridges => '网桥变更';

  @override
  String get transportWhyAuto => '自动';

  @override
  String get transportWhyOffline => '没有网络';

  @override
  String get transportWhyCircuits => '新线路';

  @override
  String get transportWhyOther => '其他';

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
  String get wallpaperDefault => '默认';

  @override
  String get wallpaperNotSet => '壁纸没有设置成功。请再试一次。';

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
  String get whyKryfoRoutedThroughTor => '经由 Tor 路由';

  @override
  String get whyKryfoByDefaultEveryMessage =>
      '默认情况下，每条消息都经由 Tor——一串中继——传送。任何人，无论是我们还是你的网络，都看不到你在和谁聊天、你在哪里。';

  @override
  String get whyKryfoEndToEndEncrypted => '端到端加密';

  @override
  String get whyKryfoMessagesAreSealedWith => '消息用只有你和对方持有的密钥加密。我们读不了。';

  @override
  String get whyKryfoNoServersHoldingYour => '没有服务器保管你的生活';

  @override
  String get whyKryfoNoAccountNoPhone =>
      '没有账号，没有手机号，没有保存你聊天记录的中央服务器。聊天记录保存在这部手机上，以加密形式存储。';

  @override
  String get whyKryfoNoAccountNoPhoneDesk =>
      '没有账号，没有手机号，没有保存你聊天记录的中央服务器。聊天记录保存在这台电脑上，以加密形式存储。';

  @override
  String get whyKryfoNothingLeaks => '什么都不泄露';

  @override
  String get whyKryfoNoReceiptsTyping =>
      '没有已读回执，也不上传联系人列表。你正在输入，只有你在对话的那个人能看到，经 Tor 直接送达，从不经过服务器。大多数应用都会泄露元数据，Kryfo 的设计就是不泄露。';

  @override
  String get whyKryfoVerifyItIsReally => '确认真的是对方';

  @override
  String get whyKryfoCompareASafetyNumber =>
      '当面或通过你信任的渠道比对安全码，这样你就知道没有人在冒充你的联系人。';

  @override
  String get whyKryfoTheHonestPart => '坦白说';

  @override
  String get whyKryfoKryfoIsPreAlpha =>
      'Kryfo 还处于 alpha 阶段，没有经过审计。加密是真的，但还没有外部专家检查过，所以在关系到你人身安全的场合，暂时不要依赖它。';

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
  String get cleanerHdrLayer => 'HDR 图层';

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
  String get bootFailedThisIsAFault => '这是这台设备上的故障，不是网络问题。与 Tor 无关。';

  @override
  String get bootFailedKeysDidNotAnswer => '手机的密钥存储没有响应。关闭并重新打开 Kryfo 通常可以解决。';

  @override
  String get bootFailedKeysDidNotAnswerDesk =>
      '这台电脑的密钥存储没有响应。关闭并重新打开 Kryfo 通常可以解决。';

  @override
  String get bootFailedCloseAndReopen => '关闭并重新打开 Kryfo';

  @override
  String get bootFailedStillStuck => '如果重试也没用';

  @override
  String get bootFailedRestoreBackup => '从备份恢复';

  @override
  String get bootFailedStartFresh => '重新开始';

  @override
  String get bootFailedStartFreshTitle => '要重新开始吗？';

  @override
  String get bootFailedStartFreshLine =>
      '这会抹掉 Kryfo 在这台手机上的一切：聊天、联系人、媒体、隐藏的聊天和你的三个词。保存在别处的备份文件不受影响。';

  @override
  String get bootFailedStartFreshLineDesk =>
      '这会抹掉 Kryfo 在这台电脑上的一切：聊天、联系人、媒体、隐藏的聊天和你的三个词。保存在别处的备份文件不受影响。';

  @override
  String get bootFailedStartFreshNext => '继续';

  @override
  String get bootFailedStartFreshSure => '抹掉这台手机上的一切？';

  @override
  String get bootFailedStartFreshSureDesk => '抹掉这台电脑上的一切？';

  @override
  String get bootFailedStartFreshSureLine => '此操作无法撤销。Kryfo 会关闭，再次打开时如同新安装。';

  @override
  String get bootFailedStartFreshYes => '抹掉并重新开始';

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
  String kryfoLinkTextYouAlreadyHave(Object who) {
    return '你已经有 $who 了';
  }

  @override
  String kryfoLinkTextSomeoneElse(Object who) {
    return '你聊天里有一个人被你叫作 $who。这个链接来自另一个人。只有在你知道链接来源时才添加。';
  }

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
  String get kryfoLinkTextYouJoinUnderA => '你用专为这个聊天室生成的密钥加入。里面的任何人都看不到你的三个词。';

  @override
  String get linkStubFetchedOverTorBy => '经由 Tor 获取 · 由你的设备';

  @override
  String get linkStubFetchedOverTorByTheirDevice => '经由 Tor 获取 · 由对方的设备';

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
  String get mediaBubblesPlaying => '正在播放';

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
  String get motionReadyToChat => '可以聊天了';

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
  String get motionAddressFinishing => '消息已可通过 Tor 发送。你的私密地址正在后台完成设置。';

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
  String get pairCodePanelWorking => '处理中';

  @override
  String get pairCodePanelBurned => '这个码已经焚毁。对方准备好时再生成一个新的。';

  @override
  String get pairCodePanelCodeCopied => '配对码已复制';

  @override
  String pairCodePanelBurnsIn(Object mm, Object ss) {
    return '$mm:$ss 后焚毁';
  }

  @override
  String get pairCodePanelTheyTapAddChoose => '对方点“添加”，选择“配对码”，然后输入这些数字。';

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
  String previewStripFetchedOverTor(Object domainOf) {
    return '$domainOf · 经由 Tor 获取';
  }

  @override
  String get previewStripDropThePreview => '去掉预览';

  @override
  String get previewStripAddPreview => '添加预览';

  @override
  String get previewStripFetchingOverTor => '正在经由 Tor 获取…';

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
  String get torBootSplashMadeOnThisPhoneDesk => '在这台电脑上生成。什么都不会发往任何地方。';

  @override
  String get torBootSplashFirstLaunchTakesA => '首次启动需要一点时间 · 只在启动时';

  @override
  String get torBootSplashTakingLonger => '这比平时要久一些';

  @override
  String get torBootSplashHopEntry => '入口';

  @override
  String get torBootSplashHopMiddle => '中间';

  @override
  String get torBootSplashHopExit => '出口';

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
  String get profileIdentity => '身份';

  @override
  String get avatarPickerShape => '形状';

  @override
  String get avatarPickerColour => '颜色';

  @override
  String get avatarPickerTurn => '旋转';

  @override
  String avatarPickerOption(String what, int n, int count) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$what，第 $nString 个，共 $countString 个';
  }

  @override
  String get avatarPickerYourInitial => '你的首字母';

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
  String get settingsProtectBackup => '备份';

  @override
  String get settingsBackupNotYet => '还没有';

  @override
  String get settingsBackupToday => '今天';

  @override
  String get settingsBackupYesterday => '昨天';

  @override
  String settingsBackupDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 天前',
    );
    return '$_temp0';
  }

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
  String get bridgesFoundAVolunteer => '找到志愿者，正在连接';

  @override
  String get bridgesScanABridgeCode => '扫描网桥 QR 码';

  @override
  String get settingsBridgesForNetworksThat => '网桥，用于封锁 Tor 的网络';

  @override
  String get bridgesCouldNotReachTheTor => '联系不上 Tor 项目';

  @override
  String get torBootSplashConnect => '连接';

  @override
  String get bridgesOffline => '离线';

  @override
  String get bridgesNothingGotThrough => '都没能连上';

  @override
  String get bridgesBridgeFromAFriend => '朋友给的网桥';

  @override
  String get bridgesKryfoCanAskThe => 'Kryfo 可以向 Tor 项目索取网桥，绕过封锁。';

  @override
  String get bridgesNotNeededRightNow => '现在用不到';

  @override
  String get bridgesBuiltInBridges => '内置网桥';

  @override
  String get bridgesKryfoCanGetAround => 'Kryfo 现在能够绕过 Tor 封锁了';

  @override
  String get bridgesThatSNotABridge => '这不是网桥配置';

  @override
  String get transportBridgeError => '上次错误';

  @override
  String get bridgesDirect => '直连';

  @override
  String get bridgesAskingTheTorProject => '正在询问 Tor 项目这里什么方式能用…';

  @override
  String get bridgesNoneOfTheseAre => '这些都不是 Kryfo 能识别的网桥配置。';

  @override
  String get bridgesAutomatic => '自动';

  @override
  String get bridgesStraightToTor => '直连 Tor，无需网桥';

  @override
  String get bridgesKryfoConnectsAsSoon => '你一恢复联网，Kryfo 就会连接。';

  @override
  String get bridgesMore => '更多';

  @override
  String bridgesTryingAnotherWayOf(String attempt, String attempts) {
    return '正在尝试其他方式…（$attempt/$attempts）';
  }

  @override
  String get bridgesLookingForAVolunteer => '正在寻找志愿者';

  @override
  String get bridgesFastestWhereTorIsnt =>
      '在 Tor 没被封锁的地方最快。Kryfo 从不在 Tor 之外建立连接。';

  @override
  String get transportBridgePhase => '阶段';

  @override
  String get bridgesAsleepBetweenCheckIns => '两次查收之间休眠中';

  @override
  String get bridgesThroughABridge => '经由网桥';

  @override
  String get bridgesBuiltIn => '内置';

  @override
  String get bridgesPasteOrScanALineDesk => '粘贴你信任的人给你的网桥配置。';

  @override
  String get bridgesDetails => '详情';

  @override
  String get transportBridgeMode => '网桥';

  @override
  String get bridgesYourBridgeCouldNot => '网桥无法启动';

  @override
  String get bridgesKryfoStaysOfflineRather => 'Kryfo 宁可保持离线，也不会在没有网桥的情况下连接。';

  @override
  String get bridgesSignInToThisWifi => '登录这个 Wi-Fi';

  @override
  String get bridgesThisNetworkWantsA => '这个网络需要先登录。登录后，Kryfo 就会连接。';

  @override
  String get bridgesThisNetworkWantsADesk =>
      '这个网络需要先登录。请在浏览器里登录，或检查电脑的网络连接。登录后，Kryfo 就会连接。';

  @override
  String get bridgesWaitingForWifiSignIn => '等待 Wi-Fi 登录';

  @override
  String get bridgesOpenWifiSettings => '打开 Wi-Fi 设置';

  @override
  String get bridgesUsingBuiltIn => '正在使用内置网桥';

  @override
  String get bridgesUsingSnowflake => '正在使用 Snowflake';

  @override
  String get bridgesUsingTorProject => '正在使用 Tor 项目的网桥';

  @override
  String get bridgesBridgeRemoved => '网桥已移除';

  @override
  String get bridgesUndo => '撤销';

  @override
  String bridgesRemoveBridgeN(String n) {
    return '移除网桥 $n';
  }

  @override
  String get bridgesTurnOnAutomatic => '开启自动';

  @override
  String get bridgesPasteABridgeLine => '粘贴网桥配置';

  @override
  String get bridgesInUse => '正在使用';

  @override
  String get bridgesPasteTheLineThey => '粘贴对方发给你的那一行配置，或者扫码。网桥配置要找你认识的人拿。';

  @override
  String get bridgesYouReOnAMode => '你当前的模式不使用 Tor。切换回来后，这些选择才会生效。';

  @override
  String get bridgesPasteOrScanALine => '粘贴或扫描你信任的人给你的网桥配置。';

  @override
  String get bridgesNothingYet => '暂无';

  @override
  String get torBootSplashIfTorIsBlocked =>
      '如果你那里 Tor 被封锁或监控，Kryfo 可以改为通过网桥启动。';

  @override
  String get bridgesScanACode => '扫码';

  @override
  String get bridgesSwitchToAutomatic => '切换到自动';

  @override
  String get torBootSplashTorIsBlockedHere => '这里 Tor 被封锁或监控';

  @override
  String get torBootSplashStartThroughABridge => '通过网桥启动';

  @override
  String get torBootSplashNeverTriesTorPlainly =>
      '在这里，Kryfo 绝不会直接连接 Tor。它会自己找到可用的网桥，你也可以在下一步选择自己的网桥。';

  @override
  String get bridgesTryingAnotherWay => '正在尝试其他方式…';

  @override
  String get bridgesFindingAWayIn => '正在寻找连接方式…';

  @override
  String get bridgesGoesThroughAVolunteer => '经由志愿者的电脑连接。很难封锁，但启动慢。';

  @override
  String get bridgesTorSeemsBlocked => '这个网络似乎封锁了 Tor';

  @override
  String get bridgesTorIsBlockedOnThis => '这个网络封锁了 Tor';

  @override
  String bridgesKryfoCouldNotRead(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Kryfo 无法读取其中 $countString 条地址',
    );
    return '$_temp0';
  }

  @override
  String get bridgesTorNoBridge => 'Tor，无网桥';

  @override
  String get bridgesKryfoFindsAWay => 'Kryfo 会找出在你那里能用的方式。';

  @override
  String get bridgesThisBridgeIsnTGetting => '这个网桥连不出去';

  @override
  String get bridgesBridgesTheTorProject => 'Tor 项目之前给你的网桥。';

  @override
  String get bridgesConnectingDots => '正在连接…';

  @override
  String get bridgesNotNow => '暂不';

  @override
  String get bridgesObfs4BridgesThatCome => 'Kryfo 自带的网桥（obfs4）。试起来快，但常被封锁。';

  @override
  String get bridgesYourNetworkMayBe => '你的网络可能受到限制';

  @override
  String get bridgesCheckingForMessages => '正在查收消息…';

  @override
  String get bridgesSavedLines => '已保存的地址';

  @override
  String get bridgesPasteTheLineTheyDesk => '粘贴对方发给你的那一行配置。网桥配置要找你认识的人拿。';

  @override
  String get bridgesFromAFriendLower => '来自朋友';

  @override
  String get bridgesAlmostThere => '快好了';

  @override
  String get bridgesUseThisBridge => '使用这个网桥';

  @override
  String bridgesUseTheseBridges(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '使用这 $countString 个网桥',
    );
    return '$_temp0';
  }

  @override
  String get transportBridgeMethod => '方式';

  @override
  String get bridgesPointAtTheBridge => '对准网桥的 QR 码';

  @override
  String get bridgesConnectingThroughYourBridge => '正在通过你的网桥连接…';

  @override
  String get bridgesThisLineIsTooLong => '这行配置太长，Tor 用不了。';

  @override
  String get bridgesAutomaticFindsAWay =>
      'Tor 被封锁时，“自动”会自己找到办法。如果你同意，Kryfo 可能会向 Tor 项目询问网桥。';

  @override
  String get bridgesFromTheTorProjectLower => '来自 Tor 项目';

  @override
  String get bridgesBridgesGoDeadWithout => '网桥可能会毫无预兆地失效。“自动”能找到别的办法。';

  @override
  String get bridgesWhenTorIsBlockedAutomatic =>
      'Tor 被封锁时，“自动”会询问 Tor 项目，在你所在的国家或地区什么方式能用。';

  @override
  String get bridgesPlainAdvice =>
      'Kryfo 会自动选择网桥。Snowflake 和 WebTunnel 在大多数地方都能用。如果一个连不上，就换一个试试，或者向朋友要一条网桥配置。';

  @override
  String get bridgesAskTorProject => '询问 Tor 项目';

  @override
  String get bridgesTooLongForTor => '太长，Tor 用不了';

  @override
  String bridgesMethodFrom(String method, String from) {
    return '$method，$from';
  }

  @override
  String get bridgesKryfoCanTUseThis => 'Kryfo 用不了这行配置';

  @override
  String get bridgesTryAutomatic => '试试自动';

  @override
  String get bridgesNoInternet => '没有网络';

  @override
  String get bridgesConnection => '连接';

  @override
  String get bridgesGetABridge => '获取网桥';

  @override
  String get languageTitle => '语言';

  @override
  String get languageMatchPhone => '跟随手机';

  @override
  String get languageMatchPhoneDesk => '跟随系统';

  @override
  String languageMatchPhoneValue(Object language) {
    return '跟随手机（$language）';
  }

  @override
  String languageMatchPhoneValueDesk(Object language) {
    return '跟随系统（$language）';
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
      '让 Kryfo 保持连接，这样它关闭时加密消息也能送达。关掉这个就会停止接收消息。';

  @override
  String get videoViewerPlay => '播放';

  @override
  String get videoViewerPause => '暂停';

  @override
  String get videoViewerPlayAgain => '重新播放';

  @override
  String get videoViewerCannotPlay => '这部手机无法在这里播放这个视频。';

  @override
  String get videoViewerCannotPlayDesk => '这台电脑无法在这里播放这个视频。';

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
  String get languageNameHi => '印地语';

  @override
  String get languageNamePl => '波兰语';

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
  String get searchIntroLineDesk => '名字、词语、照片、文件和链接。搜索只在这台电脑上进行，不会把任何东西发到别处。';

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
  String get handleRegistryFailed => '联系不上登记处。\n请一分钟后再试。';

  @override
  String get handleStillReaching => '仍在联系登记处。\n通过 Tor 可能需要一些时间。';

  @override
  String get handleSearchNeedsTor => '按用户名搜索需要 Tor。在此之前，可以用 QR 码或链接添加。';

  @override
  String get handleCheckClock => '请检查手机的日期和时间，然后再试一次。';

  @override
  String get handleCheckClockDesk => '请检查电脑的日期和时间，然后再试一次。';

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
  String get lockFingerAfterPin => '输入一次 PIN 码，即可再次使用指纹。';

  @override
  String get lockFingerLockedOut => '指纹尝试次数过多。请使用 PIN 码，或先用手机自己的锁屏解锁一次，指纹即可恢复。';

  @override
  String get lockFingerRefused => '手机未能为 Kryfo 保留指纹解锁，因此已关闭。PIN 码仍然可用。';

  @override
  String get lockFingerTryAgain => '手机刚才正忙。请再试一次指纹，或使用 PIN 码。';

  @override
  String get pinsFingerRefused => '手机未允许为 Kryfo 开启指纹解锁。PIN 码仍然可用。';

  @override
  String get pinsAdvanced => '高级保护';

  @override
  String get pinsAdvancedLine => '用于有人强迫你解锁手机时。';

  @override
  String get pinsAdvancedLineDesk => '用于有人强迫你解锁电脑时。';

  @override
  String get pinsWipeLine => '在锁屏上输入它，会从这部手机上抹除 Kryfo。';

  @override
  String get pinsWipeLineDesk => '在锁屏上输入它，会从这台电脑上抹除 Kryfo。';

  @override
  String get pinsDecoyPin => '伪装 PIN';

  @override
  String get pinsDecoyLine => '打开一个空的 Kryfo，就像刚装好一样。';

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
  String get pinsTurnOffWithDecoyDesk =>
      '所有 PIN 都会被移除，伪装 PIN 和它的 Kryfo 以及所有隐藏聊天也一样。任何用你电脑的人都能以你的身份打开 Kryfo。';

  @override
  String get pinsHowThisWorks => '工作原理';

  @override
  String get flowEnterYourPin => '输入你的 PIN 码';

  @override
  String get flowEnterYourPinLine => '就是打开 Kryfo 的那个。';

  @override
  String get flowWipeTitle => '抹除 PIN';

  @override
  String get flowWipe1 =>
      '在锁屏上代替你的 PIN 码输入，它会从这部手机上抹除 Kryfo 并关闭应用。在旁人看来，应用只是停止了。';

  @override
  String get flowWipe1Desk =>
      '在锁屏上代替你的 PIN 码输入，它会从这台电脑上抹除 Kryfo 并关闭应用。在旁人看来，应用只是停止了。';

  @override
  String get flowWipe2 => '所有聊天和你的身份都会一起抹除，有伪装的话也一样。';

  @override
  String get flowWipeChoose => '选择一个抹除 PIN';

  @override
  String get flowWipeDone => '抹除 PIN 已设置';

  @override
  String get flowWipeDoneLine => '锁屏上没有任何迹象显示它的存在。';

  @override
  String get flowDecoyTitle => '伪装 PIN';

  @override
  String get flowDecoy1 => '打开一个空的 Kryfo，就像刚装好一样。';

  @override
  String get flowDecoyFinger =>
      '设置伪装 PIN 后，这个应用只能用 PIN 码打开。如果在伪装里开启了指纹，手指只会打开伪装，绝不会打开这个应用。';

  @override
  String get flowDecoyDigits => '位数要和你的 PIN 码一样，因为旁边看着的人能数出圆点。';

  @override
  String get flowDecoyShade => '已经在通知栏里的通知被看到了。但伪装打开期间，不会出现新的通知。';

  @override
  String get flowDecoyShadeDesk => '已经在屏幕上的通知被看到了。但伪装打开期间，不会出现新的通知。';

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
  String get flowLawDesk => '在有些国家，拒绝解锁设备或向官方隐藏数据本身就是违法的。出行前了解当地的法律。';

  @override
  String get howWipe =>
      '在锁屏上输入抹除 PIN，会抹除所有聊天、你的身份和任何伪装，然后关闭 Kryfo。即使输错多次后键盘被暂停，它也照样有效。';

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
  String get flowVaultReplaceDesk => '这会替换这台电脑上已有的任何隐藏聊天。';

  @override
  String get flowVaultChoose => '选择一个隐藏聊天 PIN';

  @override
  String get flowVaultChooseLine => '六位或更多。';

  @override
  String get flowEnterHiddenPinLine => '就是打开隐藏聊天的那个。';

  @override
  String get flowVaultForgetTitle => '记住这个 PIN';

  @override
  String get flowVaultForget => '如果你忘了这个 PIN，你的隐藏聊天就永远没了。谁也找不回来。';

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
  String get howVaultDesk =>
      '隐藏聊天 PIN 打开的 Kryfo 带着隐藏聊天，你的 PIN 码打开的则没有。重新设置隐藏聊天，会替换这台电脑上已有的。忘了隐藏聊天 PIN，它们就永远没了。';

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
  String get timedMessageLabel => '限时消息';

  @override
  String get stickerNewer => '来自更新版本的 Kryfo';

  @override
  String get devLinkMismatch => '这个链接自称是 Marios，但它的密钥不匹配，所以没有添加。';

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
      'Marios 的密钥内置在 Kryfo 里。他发来的每一条消息都会用它核对，所以别人没法冒充他发消息。';

  @override
  String get devKeyLabel => '他的密钥';

  @override
  String get devDeleteLine => '每一条消息都会删除，这个聊天也不会再回来。';

  @override
  String get devDeleteLineAnon => '每一条消息和为这个聊天生成的名字都会删除，这个聊天也不会再回来。';

  @override
  String get devDeleteLineBack =>
      '每一条消息都会删除，这个聊天也不会再回来。你发出的消息也会从 Marios 的手机上撤回。';

  @override
  String get devDeleteLineAnonBack =>
      '每一条消息和为这个聊天生成的名字都会删除，这个聊天也不会再回来。你发出的消息也会从 Marios 的手机上撤回。';

  @override
  String devDeleteNotTakenBack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '有 $count 条消息没能从 Marios 的手机上撤回',
    );
    return '$_temp0';
  }

  @override
  String get devDeleteFailed => '无法删除这个聊天。请再试一次。';

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
  String get devWriteAnonymously => '匿名发送';

  @override
  String get devUseMyWords => '用我的三个词';

  @override
  String get devWhoSeesWhat => '工作原理';

  @override
  String get devWhoWords => '用你的三个词，这就是一个普通的聊天：Marios 可以回复你，你的头像和支持者徽章留在你这里。';

  @override
  String get devWhoAnon => '匿名发送时，Kryfo 会专门为这个聊天生成新的名字和密钥。它们只留在这部手机上，绝不会在别处使用。';

  @override
  String get devWhoAnonDesk =>
      '匿名发送时，Kryfo 会专门为这个聊天生成新的名字和密钥。它们只留在这台电脑上，绝不会在别处使用。';

  @override
  String get devWhoNothingYet => '在你发出第一条消息之前，什么都不会离开你的手机。';

  @override
  String get devWhoNothingYetDesk => '在你发出第一条消息之前，什么都不会离开你的电脑。';

  @override
  String get devWhoChoiceStays => '你的选择会一直跟着这个聊天。';

  @override
  String get devUpdateToWrite => '更新 Kryfo 后即可给 Marios 发消息。';

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
  String get devNamelessLine => '为这个聊天生成的名字只留在生成它的手机上，所以这里只能阅读。';

  @override
  String get devNamelessLineDesk => '为这个聊天生成的名字只留在生成它的设备上，所以这里只能阅读。';

  @override
  String get devStartNewLine => '这里的每一条消息都会删除，并打开一个新的聊天。';

  @override
  String get devVoiceDisguised => '在这个聊天里，你的语音会变声';

  @override
  String get devChatOptions => '聊天选项';

  @override
  String get requestsSomeoneNew => '陌生人';

  @override
  String get nameTakenTitle => '有别人在用这三个词';

  @override
  String get nameTakenLine =>
      '这里有人通过请求、介绍或群组得到了这三个词，密钥不同，也没人核对过。词是可以照抄的。如果这个链接来自你认识的人，就用它，然后和对方核对安全码。';

  @override
  String get nameTakenChatLine =>
      '你用这三个词的聊天来自请求、介绍或群组，密钥不同，也没人核对过。词是可以照抄的。如果这个链接来自你认识的人，就用它：那个聊天会被删除，你再在新的聊天里核对安全码。不确定链接从哪来？就保留现有的。';

  @override
  String get nameTakenDeletedLine =>
      '你删除过一个用这三个词的聊天，它用的是另一把密钥。如果这个链接来自你认识的人，就用它，然后和对方核对安全码。';

  @override
  String get nameTakenTombLine =>
      '你曾因为对方不是本人，从这部手机上移除了用这三个词的人。如果这个链接来自你认识的人，就使用这个链接，然后和对方核对安全码。';

  @override
  String get nameTakenTombLineDesk =>
      '你曾因为对方不是本人，从这台电脑上移除了用这三个词的人。如果这个链接来自你认识的人，就使用这个链接，然后和对方核对安全码。';

  @override
  String get nameTakenUse => '使用这个链接';

  @override
  String get nameTakenKeep => '保留现有的';

  @override
  String get appYourOwnInvite => '这是你自己的邀请。分享给别人才能互相连接。';

  @override
  String appLinkNeedsUpdate(Object id) {
    return '$id 需要先更新 Kryfo，你们才能互相添加。';
  }

  @override
  String appLinkWordsTaken(Object id) {
    return '这里已经有人叫 $id，密钥不同。和对方核对安全码，就知道谁是谁。未添加。';
  }

  @override
  String appLinkWordsVerified(Object id) {
    return '你已用另一个密钥验证过 $id。未添加。';
  }

  @override
  String appTheyAreBlocked(Object id) {
    return '你已屏蔽 $id。请在设置的“已屏蔽”中取消屏蔽后再添加。';
  }

  @override
  String get notThemNumbersDiffer => '号码不一致';

  @override
  String get notThemLine => '如果号码确实不一致，可能有人在冒用对方的名字，或者夹在你们中间。';

  @override
  String get notThemButton => '这不是对方本人';

  @override
  String get notThemSheetTitle => '要删除这位联系人并屏蔽其密钥吗？';

  @override
  String get notThemSheetLine =>
      '聊天及其中的消息和文件都会从这部手机上消失。只有你自己添加的链接或码才能再用这三个词。请和你添加的人核对安全码。';

  @override
  String get notThemSheetLineDesk =>
      '聊天及其中的消息和文件都会从这台电脑上消失。只有你自己添加的链接或码才能再用这三个词。请和你添加的人核对安全码。';

  @override
  String get notThemRemove => '删除并屏蔽';

  @override
  String get notThemDone => '已删除，并已屏蔽其密钥';

  @override
  String get groupAdminGoneLine => '这个群的管理员已从这部手机上移除。群组的变更不会再送达给你。';

  @override
  String get groupAdminGoneLineDesk => '这个群的管理员已从这台电脑上移除。群组的变更不会再送达给你。';

  @override
  String get blockedKey => '已屏蔽的密钥';

  @override
  String get appKeyBlocked => '你已屏蔽这个密钥。请在设置的“已屏蔽”中取消屏蔽后再添加。';

  @override
  String get devLinkGone => '你已删除与 Marios 的聊天。要开始新的聊天，请在设置中点按“给 Marios 发消息”。';

  @override
  String lockTooManyTriesFor(Object left) {
    return '尝试次数过多 · $left';
  }

  @override
  String get gifBadge => 'GIF';

  @override
  String get gifPlay => '播放 GIF';

  @override
  String get gifSentInside => '随消息一起发送';

  @override
  String get gifOptInTitle => '私密地搜索 GIF';

  @override
  String get gifOptInLead => 'GIF 搜索需要联网，所以在你需要之前一直关闭。';

  @override
  String get gifOptInOverTor => '通过 Tor 搜索';

  @override
  String get gifOptInThroughKryfo => '通过 Kryfo 搜索';

  @override
  String get gifOptInAsksForYou =>
      'Kryfo 的服务器替你向 GIF 服务查询。该服务永远看不到你，服务器也不会记录你搜了什么。';

  @override
  String get gifOptInAsksForYouFast =>
      'Kryfo 的服务器替你向 GIF 服务查询，所以该服务永远看不到你。在快速模式下，我们的服务器在你搜索时能看到你的 IP 地址，但不会记录它，也不会记录你搜了什么。';

  @override
  String get gifOptInLikeAPhoto => 'GIF 像照片一样加密传送。对方的手机不会下载任何东西。';

  @override
  String get gifOptInOffWhenever => '随时可以关闭';

  @override
  String get gifOptInWhereToTurnOff => '设置、隐私、GIF 搜索。手机里的 GIF 不开它也一直能用。';

  @override
  String get gifOptInWhereToTurnOffDesk => '设置、隐私、GIF 搜索。电脑里的 GIF 不开它也一直能用。';

  @override
  String get gifTurnOn => '开启 GIF 搜索';

  @override
  String get gifNotNow => '暂不';

  @override
  String gifAskOverTor(String brand) {
    return 'GIF 搜索经由 Tor 通过 Kryfo 的服务器进行，$brand 永远看不到你。要开启吗？';
  }

  @override
  String gifAskThroughKryfo(String brand) {
    return 'GIF 搜索直接发到 Kryfo 的服务器，在快速模式下它能看到你的 IP 地址。$brand 永远看不到你。要开启吗？';
  }

  @override
  String get gifAskTurnOn => '开启';

  @override
  String get gifSearchOff => 'GIF 搜索已关闭';

  @override
  String get gifSavedOnPhone => '手机上保存的 GIF 在*这台手机上*标签里。';

  @override
  String get gifSavedOnPhoneDesk => '电脑上保存的 GIF 在*这台电脑上*标签里。';

  @override
  String get gifTab => 'GIF';

  @override
  String get gifPhoneTab => '这台手机上';

  @override
  String get gifPhoneTabDesk => '这台电脑上';

  @override
  String get gifSearchHint => '搜索 GIF';

  @override
  String get gifClear => '清除搜索';

  @override
  String get gifServiceNeverSeesYou => 'GIF 服务永远看不到你';

  @override
  String get gifTrending => '热门';

  @override
  String get gifOffline => 'Tor 还在连接。连上后 GIF 就会出现。';

  @override
  String get gifBusy => '现在搜索太多了，请稍后再试。';

  @override
  String get gifUnreachable => '联系不上 Kryfo 的 GIF 服务。';

  @override
  String get gifNothingFound => '没有找到 GIF。换个词试试。';

  @override
  String get gifCouldNotLoadMore => '无法加载更多';

  @override
  String get gifLoading => '正在加载 GIF';

  @override
  String get gifCouldNotGet => '无法获取这个 GIF，请重试。';

  @override
  String gifPoweredBy(String brand) {
    return 'Powered by $brand';
  }

  @override
  String gifNeverSeesYou(String brand) {
    return '通过 Kryfo 搜索，$brand 永远看不到你。';
  }

  @override
  String gifTileA11y(String number) {
    return 'GIF $number';
  }

  @override
  String get gifPhoneLine => '保存在这台手机上的 GIF。不会联网。';

  @override
  String get gifPhoneLineDesk => '保存在这台电脑上的 GIF。不会联网。';

  @override
  String get gifPhoneChoose => '选择 GIF';

  @override
  String get settingsGifSearch => 'GIF 搜索';

  @override
  String get settingsGifSearchHint =>
      '在你开启前一直关闭。Kryfo 的服务器替你搜索，所以 GIF 服务永远看不到你。';

  @override
  String get shareChooseChat => '选择聊天';

  @override
  String get shareNoChats => '还没有聊天';

  @override
  String get shareNoOne => '没有可以分享的人';

  @override
  String get valveStillConnecting => '仍在连接…连接恢复后，你的消息会立刻发出。';

  @override
  String get valveCouldNotReconnect => 'Kryfo 无法重新连接。重启即可解决，你的消息会保留。';

  @override
  String get valveRestartKryfo => '重启 Kryfo';

  @override
  String get updateAvailable => '有可用更新';

  @override
  String updateReady(String version) {
    return 'Kryfo $version 已可下载';
  }

  @override
  String get settingsCheckForUpdates => '检查更新';

  @override
  String get settingsCheckForUpdatesHint =>
      '每天一次，通过 Tor。只向 kryfo.app 询问最新版本，不发送任何关于你的信息。';

  @override
  String get voiceDisguiseHere => '在这里给我的语音变声';

  @override
  String get chatBlockScreenshots => '禁止截屏';

  @override
  String get chatShotsWhenTheyUpdate => '对方在手机上使用最新版 Kryfo 后即可使用';

  @override
  String get chatShotsWhenTheyUpdateDesk => '可在 Android 版 Kryfo 中使用';

  @override
  String get chatShotsBothPhones =>
      'Kryfo 在两部手机上禁止截屏和录制此聊天，也禁止复制、转发或保存彼此的消息。它挡不住获准读取屏幕的应用，或经过改动来绕过它的手机和应用。';

  @override
  String get chatShotsBlocksBoth =>
      '在两部手机上禁止截屏和录屏，也禁止复制、转发或保存彼此的消息。它挡不住获准读取屏幕的应用，或经过改动来绕过它的手机和应用。';

  @override
  String get chatShotsBlockedHere => 'Kryfo 已在此聊天中禁止截屏';

  @override
  String get chatShotsMenuNote => '此聊天中不能复制、转发或保存对方的消息';

  @override
  String get chatShotsKeptOpen => '此聊天中不能用其他应用打开对方的文件';

  @override
  String searchKeptMatches(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 条结果 · 打开聊天查看',
    );
    return '$_temp0';
  }

  @override
  String get savedKeptInChat => '保存自禁止截屏的聊天 · 打开聊天查看';

  @override
  String get roomShotsMenuNote => '此聊天室中不能复制、转发或保存别人的消息';

  @override
  String get roomShotsKeptOpen => '此聊天室中不能用其他应用打开别人的文件';

  @override
  String get chatShotsYouTurnedOn => '你开启了禁止截屏。复制、转发和保存彼此的消息也已关闭。';

  @override
  String get chatShotsYouTurnedOff => '你关闭了禁止截屏';

  @override
  String get chatNowPostQuantum => '此聊天中的消息现已使用后量子加密';

  @override
  String chatShotsTheyTurnedOn(String name) {
    return '$name 开启了禁止截屏。复制、转发和保存彼此的消息也已关闭。';
  }

  @override
  String chatShotsTheyTurnedOff(String name) {
    return '$name 关闭了禁止截屏';
  }

  @override
  String get roomShotsBlocked =>
      'Kryfo 在这个聊天室的每部手机上禁止截屏和录屏，也禁止复制、转发或保存别人的消息。它挡不住获准读取屏幕的应用，或经过改动来绕过它的手机和应用。';

  @override
  String get roomShotsBlockedDesk =>
      '此聊天室中不能复制、转发或保存彼此的消息。Android 版 Kryfo 还会禁止截屏和录屏。';

  @override
  String get roomShotsAlwaysOn => '聊天室里始终开启，每部手机都一样';

  @override
  String get roomShotsAlwaysOnDesk => '聊天室里始终开启，在 Android 版 Kryfo 中';

  @override
  String get homeShotsPerChat => '禁止截屏现在按聊天设置。';

  @override
  String get homeShotsTurnOnForAll => '要在你的所有聊天中开启吗？';

  @override
  String get homeShotsTurnOn => '全部开启';

  @override
  String get homeShotsLeaveOff => '保持关闭';

  @override
  String get homeShotsTheySeeIt =>
      'Kryfo 也会在对方手机上禁止截屏，并关闭复制、转发和保存彼此的消息。对方会看到是你开启的。';

  @override
  String homeShotsTurnedOn(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Kryfo 现已在 $countString 个聊天中禁止截屏',
    );
    return '$_temp0';
  }

  @override
  String get voiceDisguisedHere => '在这个聊天里，你的语音会变声';

  @override
  String get voiceSlideUpToLock => '上滑锁定';

  @override
  String get voiceStopRecording => '停止录音';

  @override
  String get voiceDeleteNote => '删除语音消息';

  @override
  String get voiceDisguised => '已变声';

  @override
  String get voiceYourVoice => '原声';

  @override
  String get voiceDisguiseThisNote => '给这条语音变声';

  @override
  String get voiceNotDisguised => '这条语音无法变声，所以没有发出';

  @override
  String get voiceNoRoom => '手机可用空间不足。请清理一些空间后再试。';

  @override
  String get voiceNoRoomDesk => '电脑可用空间不足。请清理一些空间后再试。';

  @override
  String get voiceNoRoomNotSent => '空间不足，无法为这条语音变声，所以没有发出';

  @override
  String get voiceDisguising => '正在变声';

  @override
  String get voiceLockedNotSent => 'Kryfo 在语音消息发出前已锁定，所以没有发出';

  @override
  String get voiceNotSent => '你的语音消息没有发出';

  @override
  String get settingsDisguiseByDefault => '默认给我的语音变声';

  @override
  String get settingsDisguiseByDefaultHint => '每个聊天都可以在自己的菜单里更改';

  @override
  String get fileInstallerLine => '这是一个应用安装包。只安装来自你信任的人的应用。';

  @override
  String get fileAppInstaller => '应用安装包';

  @override
  String get fileSaveToDevice => '保存到设备';

  @override
  String get fileOpenHint => '在其他应用中打开';

  @override
  String get fileSaved => '已保存';

  @override
  String fileSavedIn(String place) {
    return '已保存到 $place';
  }

  @override
  String get fileSavedUnchecked => '已保存，但 Kryfo 无法检查这份副本';

  @override
  String get fileNotSaved => '无法保存文件';

  @override
  String get fileNotSavedNoSpace => '未保存：那里空间不足';

  @override
  String fileTooBig(String size, String max) {
    return '这个文件有 $size。文件最大为 $max。';
  }

  @override
  String get fileGoesAsItIs =>
      '这个文件会原样发出。Kryfo 只清理 JPEG、PNG、WebP、HEIC、AVIF、GIF、MP4 和 MOV。';

  @override
  String get voiceStoppedAtLimit => '语音消息最长 30 分钟，已自动停止。听一遍后再发送。';

  @override
  String get gettingMessagesHelperBody =>
      '它的服务器能看到你的 IP 地址和消息到达的时间。\n但从不知道内容。即时且省电。';

  @override
  String get gettingMessagesHelperUseOnion => '切换到 Onion';

  @override
  String get gettingMessagesHelperSetUp => '设置';

  @override
  String get gettingMessagesHelperNote =>
      '其中混有假的唤醒，让辅助应用的服务器更难分辨真消息何时到达。自建的辅助服务器会让我们的中继知道它的地址。隐藏聊天、前几个之后的房间，以及偶尔（大约五个月中有一个月）某位普通联系人，要等 Kryfo 每 15 分钟一次的定时查收。';

  @override
  String get gettingMessagesHelperOnionOnly => '需要私密路线';

  @override
  String get gettingMessagesHelperChecking => '正在检查…';

  @override
  String get gettingMessagesHelperRelayNotYet => '我们的中继暂不支持';

  @override
  String get helperSheetNeedTitle => '你需要一个辅助应用';

  @override
  String get helperSheetNeedLine =>
      '辅助应用为你的所有应用保持一条轻量连接，有消息时唤醒 Kryfo。任何 UnifiedPush 辅助应用都可以，ntfy 是不错的起点。';

  @override
  String get helperSheetGetNtfy => '获取 ntfy';

  @override
  String get helperSheetOtherApps => '其他辅助应用';

  @override
  String get helperSheetPickTitle => '选择辅助应用';

  @override
  String get helperSheetPickLine => 'Kryfo 只请它唤醒应用。你的消息从不经过它。';

  @override
  String helperSheetSetUp(Object name) {
    return '$name 已设置好';
  }

  @override
  String helperSheetNoAnswer(Object name) {
    return '$name 没有回应。请再试一次。';
  }

  @override
  String get homeHelperGoneTitle => '你的辅助应用不见了';

  @override
  String get homeHelperGoneLine => '在你选择其他方式之前，Kryfo 每 15 分钟查收一次。';

  @override
  String get homeHelperGoneChoose => '选择其他方式';

  @override
  String get homeHelperRelayTitle => '中继不再唤醒 Kryfo';

  @override
  String get gettingMessagesHelperRefused =>
      '我们的中继暂时不接受这部手机的部分登记。这些聊天会随每 15 分钟一次的定时查收到达，Kryfo 会继续尝试。换一个辅助应用或服务器也可能有帮助。';

  @override
  String albumLabel(Object count) {
    return '相册，$count 项';
  }

  @override
  String albumCounter(Object at, Object total) {
    return '$at/$total';
  }

  @override
  String albumMore(Object count) {
    return '还有 $count 项';
  }

  @override
  String get albumOnItsWay => '正在传送';

  @override
  String get albumQuoted => '相册';

  @override
  String get albumUnsendTitle => '撤回这个相册？';

  @override
  String get mediaSendAddMore => '添加更多';

  @override
  String get mediaSendRemove => '移除';

  @override
  String get mediaSendProtect => '防止截屏';

  @override
  String get mediaSendProtectedOn => '已保护 · 已阻止截屏';

  @override
  String mediaSendUpTo(Object count) {
    return '一次最多 $count 个';
  }

  @override
  String get mediaSendVideo => '发送视频';

  @override
  String get requestSenderMediaLater => '对方接受你之后，照片和文件才会开放，让你们都更安全。';

  @override
  String get requestReceiverMediaLater => '你接受对方之后，照片和文件才会开放，让你更安全。';

  @override
  String get groupEndedYou => '你结束了这个群组';

  @override
  String groupEndedBy(Object name) {
    return '$name 结束了这个群组';
  }

  @override
  String get groupEndedBar => '这个群组已结束';

  @override
  String get groupInfoEndGroup => '结束群组';

  @override
  String get groupInfoEndThisGroup => '要为所有人结束这个群组吗？';

  @override
  String get groupInfoEndGroupLine => '将为所有人删除：消息和媒体会从每位已更新成员的手机上移除。';

  @override
  String get groupInfoEndGroupLineDesk => '将为所有人删除：消息和媒体会从每位已更新成员的设备上移除。';

  @override
  String get groupInfoDeleteGroup => '删除群组';

  @override
  String get groupInfoDeleteThisGroup => '删除这个群组？';

  @override
  String get groupInfoDeleteGroupLine => '这个已结束的群组会从你的聊天列表中移除。';

  @override
  String get groupEndedOldNotice => '我结束了这个群组，之后谁都不能再在里面发消息。更新 Kryfo 就能看到它已结束。';

  @override
  String get groupInfoEndGroupDetail => 'Kryfo 会从每位已更新的成员手机上移除它。';

  @override
  String get groupInfoEndGroupDetailDesk => 'Kryfo 会从每位已更新的成员设备上移除它。';

  @override
  String get translateAction => '翻译';

  @override
  String get translateShowOriginal => '显示原文';

  @override
  String translateBarTo(Object language) {
    return '翻译成$language';
  }

  @override
  String get translateBarMore => '翻译选项';

  @override
  String translateBarNever(Object language) {
    return '不再为$language提供翻译';
  }

  @override
  String get translateBarHide => '在此聊天中隐藏';

  @override
  String get translateWorking => '正在翻译…';

  @override
  String get translateFailed => '无法翻译';

  @override
  String translateFrom(Object language) {
    return '译自$language';
  }

  @override
  String get translateLangZh => '中文';

  @override
  String translatePackTitle(Object language) {
    return '在这部手机上翻译$language';
  }

  @override
  String translatePackTitleDesk(Object language) {
    return '在这台电脑上翻译$language';
  }

  @override
  String translatePackLine(Object language, Object size) {
    return '消息在这部手机上翻译，从不离开手机。这需要$language语言包，约 $size，通过 Tor 下载一次。';
  }

  @override
  String translatePackLineDesk(Object language, Object size) {
    return '消息在这台电脑上翻译，从不离开电脑。这需要$language语言包，约 $size，通过 Tor 下载一次。';
  }

  @override
  String get translatePackNoLib => '翻译在这部手机上无法使用。';

  @override
  String get translatePackNoLibDesk => '翻译在这台电脑上无法使用。';

  @override
  String translateDownload(Object size) {
    return '下载 · 约 $size';
  }

  @override
  String get translateDownloadAnyway => '仍然立即下载';

  @override
  String get translateResume => '继续下载';

  @override
  String translateProgress(Object done, Object total) {
    return '$done / $total';
  }

  @override
  String get translateFinishing => '正在检查文件…';

  @override
  String translateInstalled(Object size) {
    return '已在这部手机上 · $size';
  }

  @override
  String translateInstalledDesk(Object size) {
    return '已在这台电脑上 · $size';
  }

  @override
  String get translateNeedsWifi => '“仅限 Wi-Fi”已开启，而这部手机没有连接 Wi-Fi。';

  @override
  String get translateNeedsWifiDesk => '“仅限 Wi-Fi”已开启，而这台电脑没有连接 Wi-Fi。';

  @override
  String get translateFailNoTor => 'Tor 还没有连接。语言包只通过 Tor 下载，请在连接后重试。';

  @override
  String get translateFailNetwork => '下载已中断。重试后会从中断处继续。';

  @override
  String get translateFailBadFile => '有一个文件与 Kryfo 预期的不符，已被丢弃。请重试。';

  @override
  String get translateFailNoEngine => '这部手机无法下载语言包。';

  @override
  String get translateFailNoEngineDesk => '这台电脑无法下载语言包。';

  @override
  String translatePaused(Object size) {
    return '已暂停 · 已下载 $size';
  }

  @override
  String get translateSettingsTitle => '翻译';

  @override
  String get translateSettingsRow => '翻译消息';

  @override
  String get translateSettingsHint => '在这部手机上，从不经过服务器';

  @override
  String get translateSettingsHintDesk => '在这台电脑上，从不经过服务器';

  @override
  String get translatePacksSection => '语言包';

  @override
  String translatePackPair(Object language) {
    return '$language和英语';
  }

  @override
  String translateNotDownloaded(Object size) {
    return '未下载 · 约 $size';
  }

  @override
  String get translateDownloading => '正在通过 Tor 下载';

  @override
  String translateDeleteTitle(Object language) {
    return '删除$language语言包？';
  }

  @override
  String translateDeleteLine(Object language) {
    return '在重新下载之前，$language消息将无法翻译。';
  }

  @override
  String get translateLanguagesSection => '语言';

  @override
  String get translateMyLanguages => '我能读的语言';

  @override
  String get translateMyLanguagesHint => '这些语言的消息不会提示翻译。应用的语言始终包括在内。';

  @override
  String get translateInto => '翻译成';

  @override
  String get translateAppLanguage => '应用的语言';

  @override
  String get translateBehaviourSection => '下载与聊天';

  @override
  String get translateAutoDefault => '自动翻译聊天';

  @override
  String get translateAutoDefaultHint => '适用于你没有单独设置的聊天。每个聊天都可以开启或关闭。';

  @override
  String get translateWifiOnly => '仅在 Wi-Fi 下下载语言包';

  @override
  String get translatePrivacyTitle => '哪些内容保持私密';

  @override
  String get translatePrivacyNote =>
      '翻译在这部手机上完成。任何消息都不会被发送到别处去翻译。下载语言包会让服务器知道是哪个语言包。下载经由 Tor，所以服务器不知道是谁请求的。';

  @override
  String get translatePrivacyNoteDesk =>
      '翻译在这台电脑上完成。任何消息都不会被发送到别处去翻译。下载语言包会让服务器知道是哪个语言包。下载经由 Tor，所以服务器不知道是谁请求的。';

  @override
  String get translateAutoInChat => '自动翻译';

  @override
  String get translateAutoInChatHint => '其他语言的消息会显示译文。点一下即可查看原文。';

  @override
  String get translateAlwaysChat => '总是翻译此聊天';

  @override
  String translateNeverDone(Object language) {
    return '$language消息保持原样';
  }

  @override
  String get translateUndo => '撤销';

  @override
  String get translateNeverSection => '不提供翻译的语言';

  @override
  String get translateOfferAgain => '重新提供';

  @override
  String get translateOnHint => '在其他语言的消息下方提供';

  @override
  String get translatePrivacyKept => '译文与所属聊天一起加密保存在这部手机上，并随聊天一起删除。';

  @override
  String get translatePrivacyKeptDesk => '译文与所属聊天一起加密保存在这台电脑上，并随聊天一起删除。';

  @override
  String get translateOffDeletes => '关闭后会删除已保存的译文。';

  @override
  String get bridgesNoneUntilOnion => '开启 Onion 前不使用';

  @override
  String get bridgesRelayThisNetworkSees =>
      '在 Tor 被封锁的地方快速模式也能连通，但这个网络能看到你在连接 Kryfo。';

  @override
  String get settingsLicences => '许可证';

  @override
  String get settingsLicencesValue => 'Kryfo 由什么构成';

  @override
  String get licencesKryfoLine =>
      'Kryfo 是自由软件，采用 GNU 通用公共许可证第 3 版或更高版本。任何人都可以阅读、修改和分享它的代码。';

  @override
  String get licencesSourceCode => '源代码';

  @override
  String get licencesSignalTitle => 'Signal 协议';

  @override
  String licencesSignalLine(String version) {
    return 'Kryfo 包含 Signal 开发的 libsignal $version，采用 GNU Affero 通用公共许可证第 3 版。它的源代码位于 github.com/signalapp/libsignal，每个 Kryfo 版本旁也附有一份。';
  }

  @override
  String get licencesAgplText => 'GNU AGPL 3.0 全文';

  @override
  String get licencesSignalSource => 'libsignal 源代码';

  @override
  String get licencesParts => '开源组件';

  @override
  String get licencesInSignal => 'Signal 库中';

  @override
  String get licencesInApp => '应用中';

  @override
  String licencesPartCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 个组件',
    );
    return '$_temp0';
  }

  @override
  String get licencesGplText => 'GNU GPL 3.0 全文';

  @override
  String get licencesInEngine => '网络引擎中';

  @override
  String get licencesLoadFailed => '无法加载';

  @override
  String get licencesInVoice => '语音转文字中';

  @override
  String get licencesInTranslation => '消息翻译中';

  @override
  String get settingsCopyLinkHint => '复制链接';

  @override
  String get motionNoRelayYet => '暂无中继';

  @override
  String get motionTheRouteIsUp => '路线已建好';

  @override
  String get motionMessagesGoOnceARelay => '一旦有中继通过这条路线响应，消息就会发出。';

  @override
  String get motionOffline => '离线';

  @override
  String get motionNoNetwork => '没有网络';

  @override
  String get motionTorPicksUpAgain => '没有网络时什么都发不出去。网络恢复后，Tor 会继续。';

  @override
  String deliveryModeStateLast(String state, Object last) {
    return '$state · $last';
  }

  @override
  String homeWaitingState(int count, String state) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条待发送 · $state',
    );
    return '$_temp0';
  }

  @override
  String get settingsIconAndNotifications => '图标和通知';

  @override
  String iconSettingsValue(String icon) {
    return '$icon，简洁通知';
  }

  @override
  String get iconSectionTitle => '应用图标';

  @override
  String get iconHint => '主屏幕和应用列表会显示这个图标和名称，而不是 Kryfo。';

  @override
  String get iconHintKryfo => '为主屏幕和应用列表选一个普通的图标和名称。';

  @override
  String get iconWhatChanges => '这会改变什么';

  @override
  String iconConfirmTitle(String name) {
    return '把图标换成$name？';
  }

  @override
  String iconConfirmLine(String name) {
    return 'Kryfo 会关闭再重新打开。如果图标从主屏幕上消失了，请在应用列表里找到$name，再把它放回去。';
  }

  @override
  String get iconConfirmButton => '更换图标';

  @override
  String get iconNoPinLine => '点它的人会看到 Kryfo。设置应用 PIN 码后，他们只会看到 PIN 码键盘。';

  @override
  String get iconSetPin => '设置 PIN 码';

  @override
  String iconChanged(String name) {
    return '图标已换成$name';
  }

  @override
  String iconPreviewLabel(String name) {
    return '主屏幕将显示$name';
  }

  @override
  String iconButtonLabel(String name) {
    return '$name，应用图标';
  }

  @override
  String get notifShowAll => '名字和消息';

  @override
  String get notifShowNew => '只显示“新消息”';

  @override
  String get notifShowPlain => '简洁';

  @override
  String get notifPlainHint => '没有名字，没有消息，没有 Kryfo 的颜色。一个中性的图标和一行字。';

  @override
  String get notifPlainLine => '有新内容';

  @override
  String get notifPlainChannel => '提醒';

  @override
  String get notifHeaderLimit => '每条通知的顶部仍会显示 Kryfo。Android 不允许应用更改这一点。';

  @override
  String get gettingMessagesWhatShows => '通知显示什么';

  @override
  String get iconSheetChangesTitle => '会改变的';

  @override
  String get iconSheetChanges => '主屏幕和应用列表里的图标和名称、分享菜单和最近应用界面。选择简洁时，还有通知显示的内容。';

  @override
  String get iconSheetStaysTitle => '仍是 Kryfo 的';

  @override
  String get iconSheetStays => '每条通知的第一行、手机的设置和电池页面、应用商店，以及有人打开时的 Kryfo 本身。';

  @override
  String get iconSheetGlance => '它经得起别人瞥一眼你的主屏幕。但如果有人翻看手机的设置，它藏不住 Kryfo。';

  @override
  String get iconSheetPrivateSpace => '你的手机可能有自己的隐藏应用方式：设置里的私密空间。';

  @override
  String get iconSheetSecureFolder => '你的手机可能有自己的隐藏应用方式：设置里的安全文件夹。';

  @override
  String get iconSheetXiaomi => '你的手机可能有自己的隐藏应用方式：设置里的隐藏应用。';

  @override
  String get androidIconNotes => '笔记';

  @override
  String get androidIconWeather => '天气';

  @override
  String get androidIconTasks => '待办';

  @override
  String get androidIconNews => '新闻';

  @override
  String get androidServiceTitlePlain => '运行中';

  @override
  String get lockStateUnlockPlain => '解锁';

  @override
  String get iconSheetOthers =>
      '手机上的其他应用仍能看到已安装 Kryfo，Android 自己的对话框和提示也可能显示它的名称。';

  @override
  String get iconSheetSaves =>
      '使用简洁图标时，新的照片、视频和文件会以普通的名称存进手机常用的文件夹。之前保存的内容留在原处。';

  @override
  String get deliveryModeGooglePush => '谷歌推送';

  @override
  String get deliveryModeGoogle => 'Google';

  @override
  String get notificationsLead => '新消息如何送达这部手机、提示音如何、显示什么。你可以随时更改。';

  @override
  String get notificationsLeadDesk => '新消息如何送达这台电脑、提示音如何、显示什么。你可以随时更改。';

  @override
  String get notificationsHowTheyReachYou => '消息如何送达';

  @override
  String get notificationsRecommended => '推荐';

  @override
  String get notificationsGoogleBody =>
      'Google 能看到你的手机何时被唤醒。\n但从不知道是谁写的或说了什么。\n即时且省电。';

  @override
  String get notificationsGoogleStarting => '正在开启…';

  @override
  String get notificationsGoogleNoStart => '谷歌推送没能启动。请检查网络后再试一次。';

  @override
  String get notificationsGoogleNote =>
      '其中混有假的唤醒，让 Google 更难分辨真消息何时到达。我们的中继只保存它无法彼此关联的地址。推送服务运行在我们的第二台服务器上。两台服务器合起来能够把它们关联起来，借助 Google 还能关联到你的 Google 账号。只查扣其中一台做不到，但两台都由我们运营，所以我们能做到。如果你在意这一点，请选择其他方式。隐藏聊天、前几个之后的房间，以及偶尔（大约五个月中有一个月）某位普通联系人，要等 Kryfo 每 15 分钟一次的定时查收。';

  @override
  String get notificationsGoogleRefused =>
      '我们的中继暂时不接受这部手机的部分登记。这些聊天会随每 15 分钟一次的定时查收到达，Kryfo 会继续尝试。';

  @override
  String get notificationsSoundAndVibration => '声音和振动';

  @override
  String get notificationsSoundHint => '在 Android 自己的设置里';

  @override
  String get notificationsEachShows => '每条通知显示';

  @override
  String get notificationsBatteryTips => '省电提示';

  @override
  String get notificationsBatteryAllowed => '已允许';

  @override
  String get notificationsBatteryNotYet => '未允许';

  @override
  String get notificationsMakerSwitch => '手机厂商的开关';

  @override
  String get onboardingHowYourMessages => '你的消息如何*传递*。';

  @override
  String get onboardingRouteLead => '你随时可以在设置里更改。';

  @override
  String get onboardingRoutePrivateCost => '通过 Tor。一条消息需要几秒钟。';

  @override
  String get onboardingRoutePrivateGain => '没有人能知道你的 IP 地址，连我们的服务器也不能。';

  @override
  String get onboardingRouteFastCost =>
      '你连接期间，我们的服务器能看到你的 IP 地址。\n你的网络能看到你在用 Kryfo。';

  @override
  String get onboardingRouteFastGain => '不经过 Tor：更快，也更省电。';

  @override
  String get onboardingRouteBlockedLead =>
      'Kryfo 会留在 Tor 上，需要时通过网桥。\n如有需要，快速模式在设置里。';

  @override
  String get onboardingRouteBlockedGain => '遇到封锁会自己找到出路。';

  @override
  String get onboardingDeliveryHeadline => '消息何时*送达*。';

  @override
  String get onboardingDeliveryLead => '你可以随时在“通知”里更改。';

  @override
  String get homeGoogleTitle => '谷歌推送来了';

  @override
  String get homeGoogleLine => '即时又省电。Google 能看到你的手机何时被唤醒，但从不知道是谁写的或说了什么。';

  @override
  String get homeGoogleUse => '使用';

  @override
  String get homeGoogleOn => '谷歌推送已开启';

  @override
  String get homeGoogleGoneTitle => '谷歌推送不可用';

  @override
  String get appNotificationsLink => '通知 →';

  @override
  String devGooglePushes(int got, int low) {
    return '谷歌推送 $got · 被降级 $low';
  }

  @override
  String get passFieldLabel => '密码短语';

  @override
  String get padUseLetters => '使用字母';

  @override
  String get padUseDigits => '使用数字';

  @override
  String get passWeak => '弱';

  @override
  String get passFair => '中';

  @override
  String get passStrong => '强';

  @override
  String passStrengthIs(Object level) {
    return '强度：$level';
  }

  @override
  String get lockKeyBusy => '手机的安全芯片正忙。请稍后再试。';

  @override
  String get lockKeyLocked => '请先用手机自己的 PIN 码解锁一次，再试一次。';

  @override
  String get lockKeyWaiting => '手机的安全芯片仍在检查';

  @override
  String get lockKeyLost =>
      '这部手机丢失了用来检查你 PIN 码的密钥，所以有些 PIN 码可能打不开。可以重置 Kryfo 并恢复备份。';

  @override
  String get lockKeyReset => '重置 Kryfo';

  @override
  String get lockKeyResetTitle => '要重置 Kryfo 吗？';

  @override
  String get lockKeyResetLine =>
      '这部手机上 Kryfo 的所有内容都会被删除，Kryfo 会关闭。之后你可以恢复备份。隐藏聊天只能从它们打开时做的备份中恢复。';

  @override
  String get lockKeyResetSureTitle => '此操作无法撤销';

  @override
  String get lockKeyResetSureLine => '这部手机上 Kryfo 的所有聊天、密钥和设置会立即删除。';

  @override
  String get lockKeyResetSure => '全部删除';

  @override
  String get flowVaultPassLine => '至少 12 个字符。手机键盘能看到你输入的内容，所以请使用不会学习或同步词语的键盘。';

  @override
  String get flowVaultPassLineDesk => '至少 12 个字符。请使用你在别处都没用过的。';

  @override
  String get flowVaultPassAgain => '再输入一次同样的密码短语';

  @override
  String get cardTitle => '完成安全更新';

  @override
  String get cardLine => '如果你还使用其他 PIN 码，请在这里各输入一次。';

  @override
  String get cardType => '输入 PIN 码';

  @override
  String get cardAnswer => '好了。再输入一个，或在完成后点“完成”。';

  @override
  String get keyLine =>
      '你的 PIN 码只能在这部手机上使用。如果手机丢失了用来检查它们的密钥，你需要重置 Kryfo 并恢复备份。隐藏聊天只能从它们打开时做的备份中恢复。';

  @override
  String get keyLineUnlocked =>
      '你的 PIN 码只能在这部手机上使用，而且只在手机解锁时可用。如果手机丢失了用来检查它们的密钥，你需要重置 Kryfo 并恢复备份。隐藏聊天只能从它们打开时做的备份中恢复。';

  @override
  String get keyLineScreenLock => '请为手机设置屏幕锁，这样手机锁定时这层保护依然有效。';

  @override
  String get fileServerTryLater => '文件服务器暂时已满，请稍后再试。';

  @override
  String fileTooBigUntilUpdate(String size, String max) {
    return '这个文件有 $size。在所有人更新 Kryfo 之前，这个聊天里的文件最大为 $max。';
  }

  @override
  String get fileDayLimit => '你今天已经发送了很多大文件，请明天再试。';

  @override
  String get mediaProgressPreparing => '正在准备 · 请保持应用打开';

  @override
  String get groupShotsBlocksAll =>
      '在这个群组的每部手机上禁止截屏和录屏，也禁止复制、转发或保存彼此的消息。它挡不住获准读取屏幕的应用，或经过改动来绕过它的手机和应用。';

  @override
  String get groupShotsBlocksAllDesk =>
      '在这里关闭复制、转发和保存彼此的消息。Android 版 Kryfo 还会禁止截屏和录屏。';

  @override
  String get groupShotsStartsWhenAll => '正在等待这里的所有人都能在自己的设备上禁止截屏';

  @override
  String get groupShotsOnForAll => '对这里的所有人开启';

  @override
  String get groupShotsOnForAllDesk => '在 Android 版 Kryfo 中开启';

  @override
  String get groupShotsOffAdminOnly => '已关闭。只有管理员能更改';

  @override
  String get groupShotsWaitAdminOnly => '正在等待这里的所有人都能在自己的设备上禁止截屏。只有管理员能更改';

  @override
  String get groupShotsOnAdminOnly => '对这里的所有人开启。只有管理员能更改';

  @override
  String get groupShotsOnAdminOnlyDesk => '在 Android 版 Kryfo 中开启。只有管理员能更改';

  @override
  String groupShotsWaitingFor(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '还在等 $countString 人',
    );
    return '$_temp0';
  }

  @override
  String get groupShotsWaitingTitle => '尚未覆盖';

  @override
  String get groupShotsWaitingHint => '这些人的设备能禁止截屏后，禁止截屏就覆盖所有人。点按某人可将其移出群组。';

  @override
  String get groupShotsNeedsUpdate => '其设备暂时无法禁止截屏，或之后一直未上线';

  @override
  String get groupShotsBlockedByYou => '已被你屏蔽';

  @override
  String get groupShotsYouTurnedOnWait =>
      '你开启了禁止截屏。等这里的所有人都能在自己的设备上禁止截屏后，它会对所有人生效。';

  @override
  String groupShotsTheyTurnedOnWait(String name) {
    return '$name 开启了禁止截屏。等这里的所有人都能在自己的设备上禁止截屏后，它会对所有人生效。';
  }

  @override
  String get groupShotsStarted => '禁止截屏已对这里的所有人开启。复制、转发和保存彼此的消息也已关闭。';

  @override
  String get groupShotsStartedDesk =>
      '禁止截屏已在 Android 版 Kryfo 中开启。复制、转发和保存彼此的消息也已关闭。';

  @override
  String get groupShotsPaused => '这里有人还不能在其设备上禁止截屏。等其可以后，会再次对所有人生效。';

  @override
  String get groupShotsCantYet => '还不能禁止截屏';

  @override
  String get groupShotsAddTitle => '仍要添加吗？';

  @override
  String get groupShotsAddPauses => '在这些人能在自己的设备上禁止截屏之前，禁止截屏不会覆盖这里的所有人。';

  @override
  String get groupShotsLeaveStays => '禁止截屏会保持现状。';

  @override
  String get groupShotsBlockedHere => 'Kryfo 已在此群组中禁止截屏';

  @override
  String get groupShotsBlockedHereDesk => '此群组中不能复制、转发或保存';

  @override
  String get groupShotsMenuNote => '此群组中不能复制、转发或保存别人的消息';

  @override
  String get groupShotsKeptOpen => '此群组中不能用其他应用打开别人的文件';

  @override
  String get groupShotsOldNotice => '我在这个群组开启了禁止截屏。你的 Kryfo 还做不到，请更新一下。';

  @override
  String get captureShotTaken => '已截屏。没有通知任何其他人。';

  @override
  String get captureRecording => '此屏幕正在被录制。没有通知任何其他人。';

  @override
  String get settingsDevices => '设备';

  @override
  String get devicesLinkedDevices => '已关联的设备';

  @override
  String get devicesThisPhoneOnly => '仅这部手机';

  @override
  String get devicesThisPhoneOnlyDesk => '仅这台电脑';

  @override
  String get devicesNameSeparator => '、';

  @override
  String get devicesThisPhone => '这部手机';

  @override
  String get devicesThisPhoneDesk => '这台电脑';

  @override
  String get devicesOnlyThisPhone => '只有这部手机能关联或移除设备';

  @override
  String get devicesOnlyThisPhoneDesk => '只有这台电脑能关联或移除设备';

  @override
  String devicesLinkedOn(Object date) {
    return '$date关联';
  }

  @override
  String get devicesUsedToday => '今天用过';

  @override
  String get devicesUsedThisWeek => '本周用过';

  @override
  String get devicesUsedThisMonth => '本月用过';

  @override
  String get devicesNotUsedYet => '还没用过';

  @override
  String devicesUnlinksSoon(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$daysString 天内不打开就会解除关联',
      one: '明天不打开就会解除关联',
      zero: '今天不打开就会解除关联',
    );
    return '$_temp0';
  }

  @override
  String get devicesEmptyTitle => '在电脑上用 Kryfo';

  @override
  String get devicesEmptyLine => '关联一台电脑，就能在上面读和发消息。除了这部手机，最多再关联五台设备。';

  @override
  String get devicesContactsSeeNothing => '你的联系人的应用不会显示你的设备。';

  @override
  String get devicesUnusedRule => '一台设备 30 天没打开，就会自己解除关联，并抹除上面的聊天。';

  @override
  String get devicesFull => '已关联五台设备。移除一台才能再关联。';

  @override
  String get devicesLinkADevice => '关联设备';

  @override
  String get devicesRemoveAll => '移除其他所有设备';

  @override
  String get devicesRemoveAllTitle => '移除其他所有设备？';

  @override
  String get devicesRemoveAllLine =>
      '等你的联系人的应用收到这项更改后，它们就不会再收到新消息，也不能以你的身份发送。这部手机保留一切。';

  @override
  String get devicesRemoveAllYes => '全部移除';

  @override
  String get devicesRemovedAll => '现在只有这部手机';

  @override
  String devicesRemoveTitle(Object name) {
    return '移除“$name”？';
  }

  @override
  String get devicesRemoveLine =>
      '等你的联系人的应用收到这项更改后，它就不会再收到新消息，也不能以你的身份发送。下次联网时，它会抹除自己上面的聊天。被人动过手脚的设备可能会留下它已有的内容。';

  @override
  String get devicesRemove => '移除';

  @override
  String devicesRemoved(Object name) {
    return '已移除“$name”';
  }

  @override
  String get devicesRename => '重命名';

  @override
  String devicesRenameTitle(Object name) {
    return '重命名“$name”';
  }

  @override
  String get devicesRenameLine => '只有你能看到这个名字，你的联系人永远看不到。';

  @override
  String get devicesNameComputer => '电脑';

  @override
  String get devicesDeviceCode => '设备代码';

  @override
  String get devicesDeviceCodeLine => '同样的代码也会显示在那台设备的设置里。';

  @override
  String get devicesLinkStep1 => '在电脑上打开 Kryfo，它会显示一个二维码。';

  @override
  String get devicesLinkStep2 => '用这部手机扫描它。';

  @override
  String get devicesLinkStep3 => '确认两块屏幕显示的六位数字相同。';

  @override
  String get devicesHistory => '历史记录';

  @override
  String get devicesHistoryCopy => '复制我的聊天';

  @override
  String get devicesHistoryCopyHint => '所有消息，以及最近 30 天的照片和视频。';

  @override
  String get devicesHistoryNone => '仅联系人和群组';

  @override
  String get devicesHistoryNoneHint => '它们会复制过来，不含任何消息。';

  @override
  String get devicesSkipMedia => '跳过照片和视频';

  @override
  String get devicesSkipMediaHint => '只复制文字。更快，设备上存的也更少。';

  @override
  String get devicesHiddenStay => '隐藏聊天和伪装都留在这部手机上。';

  @override
  String get devicesHiddenStayDesk => '隐藏聊天和伪装都留在这台电脑上。';

  @override
  String get devicesScanCode => '扫描二维码';

  @override
  String get devicesLinkReaching => '正在连接设备';

  @override
  String get devicesLinkReachingLine => '两边都保持 Kryfo 打开。通过 Tor 可能需要一分钟。';

  @override
  String get devicesLinkCompare => '数字一致吗？';

  @override
  String get devicesLinkCompareLine => '新设备上也显示六位数字。只有相同时才关联。';

  @override
  String get devicesLinkMatch => '一致';

  @override
  String get devicesLinkNoMatch => '不一致';

  @override
  String get devicesLinkLinking => '正在关联';

  @override
  String get devicesLinkLinkingLine => '正在设置新设备。两边都保持打开。';

  @override
  String get devicesLinkDone => '设备已关联';

  @override
  String get devicesLinkDoneLine => '它显示在“已关联的设备”中，你可以在那里重命名或移除它。';

  @override
  String get devicesLinkUnreached => '无法连接到设备';

  @override
  String get devicesLinkUnreachedLine => '确认新设备上的 Kryfo 已打开并显示二维码，然后重试。';

  @override
  String get devicesLinkStopped => '没有关联任何设备';

  @override
  String get devicesLinkStoppedLine => '数字必须一致。用新的二维码重新开始。';

  @override
  String get devicesLinkInterruptedLine => '关联被中断了。用新的二维码重新开始。';

  @override
  String get scanLinkTitle => '扫描设备的二维码';

  @override
  String get scanLinkPoint => '对准新设备上的二维码';

  @override
  String get scanLinkNotOne => '这不是关联用的二维码';

  @override
  String get onboardingLinkToMyPhone => '关联到我的手机';

  @override
  String get joinTitle => '关联到你的手机';

  @override
  String get joinStep1 => '在手机上打开 Kryfo。';

  @override
  String get joinStep2 => '进入设置，然后“已关联的设备”，然后“关联设备”。';

  @override
  String get joinStep3 => '用手机扫描这个二维码。';

  @override
  String get joinWaiting => '正在等待你的手机';

  @override
  String get joinCodeLife => '二维码十分钟内有效。';

  @override
  String get joinCompareLine => '你的手机上也显示六位数字。只有相同时才继续。';

  @override
  String get joinLinking => '正在关联到你的手机';

  @override
  String get joinLinkingLine => '完成前请保持手机上的 Kryfo 打开。';

  @override
  String get joinDone => '已关联到你的手机';

  @override
  String get joinDoneLine => '新消息现在也会到达这台设备。你账号的密钥号码：';

  @override
  String get joinOpen => '打开 Kryfo';

  @override
  String get joinUnreached => '无法连接到你的手机';

  @override
  String get joinUnreachedLine => '确认手机已联网并打开了 Kryfo，然后换一个新的二维码再试。';

  @override
  String get joinNewCode => '新二维码';

  @override
  String get devicesNewNotice => '已关联新设备';

  @override
  String devicesNewNoticeLine(Object name, Object date) {
    return '$name 于 $date 关联到你的账号。打开“已关联的设备”查看。';
  }

  @override
  String get devicesNewNoticeMany => '已关联几台新设备';

  @override
  String devicesNewNoticeManyLine(Object names) {
    return '$names 已关联到你的账号。打开“已关联的设备”查看。';
  }

  @override
  String get devicesNewNoticeOpen => '打开';

  @override
  String get settingsLinkedToLine => '已关联到你的手机。备份和邀请留在手机上。';

  @override
  String get devicesYourPhone => '你的手机';

  @override
  String get desktopLockTitle => 'Kryfo 已锁定';

  @override
  String get desktopLockBody => '输入这台电脑的密码短语。';

  @override
  String get desktopLockNewTitle => '在这台电脑上锁定 Kryfo';

  @override
  String get desktopLockNewBody =>
      'Kryfo 每次启动都会要求输入这个密码短语。它锁住你在这台电脑上的消息、照片、语音消息、文件、联系人和密钥。';

  @override
  String get desktopLockHonest =>
      '复制了 Kryfo 文件夹的人，可以在自己的电脑上尽其所能地快速尝试密码短语。四个以上的随机单词能扛住，短的密码短语扛不住。';

  @override
  String get desktopLockForgot => '没有密码短语，这里你的任何消息、文件或密钥都打不开，连我们也不行。';

  @override
  String get desktopLockField => '密码短语';

  @override
  String get desktopLockRepeat => '再输入一次相同的密码短语';

  @override
  String get desktopLockSet => '用这个密码短语锁定';

  @override
  String get desktopLockOpen => '打开 Kryfo';

  @override
  String desktopLockShort(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '至少 $countString 个字符';
  }

  @override
  String get desktopLockMismatch => '两次输入的密码短语不一致';

  @override
  String get desktopLockWrong => '密码短语不对';

  @override
  String get desktopLockFailed => 'Kryfo 无法在这里打开它的锁。请重新启动试试。';

  @override
  String get desktopTrayQuit => '退出 Kryfo';

  @override
  String get desktopTrayTip => 'Kryfo 正在运行并接收消息';

  @override
  String get desktopTrayLockedTip => '打开 Kryfo 即可开始接收消息';

  @override
  String get desktopTrayStillRunning => 'Kryfo 仍在系统托盘中运行。要退出，请使用托盘图标。';

  @override
  String get desktopRunSection => '在这台电脑上';

  @override
  String get desktopTrayRow => '在系统托盘中保持运行';

  @override
  String get desktopTrayHint => '关闭窗口后，消息照常到达。';

  @override
  String get desktopTrayOffLine => '关闭窗口会退出 Kryfo。\n再次打开时，消息就会到达。';

  @override
  String get desktopTrayNoneLine => '这个桌面没有托盘图标。\n关闭窗口会退出 Kryfo。';

  @override
  String get desktopStartRow => '随电脑启动';

  @override
  String get desktopStartHint => '登录这台电脑时，Kryfo 会在系统托盘中启动。';

  @override
  String get desktopStartRefused => '这台电脑不允许 Kryfo 随它启动。\n你自己启动时，Kryfo 照常打开。';

  @override
  String get desktopStartHeldOff =>
      'Windows 在启动应用中关闭了 Kryfo。\n请到 Windows 设置、应用、启动中打开它。';

  @override
  String get desktopMicBlocked => '在设置、隐私和安全性、麦克风中允许桌面应用使用麦克风后，Kryfo 即可录音。';

  @override
  String get desktopMicNone => '连接麦克风即可录制语音。';

  @override
  String get desktopNoCamera => 'Kryfo 暂时还不能在这台电脑上使用摄像头。请改用链接或代码。';

  @override
  String get desktopAlreadyOpen => 'Kryfo 已经在这台电脑上打开了。';

  @override
  String get desktopFolderNotYours => 'Kryfo 的文件夹属于这台电脑上的另一个账户，所以 Kryfo 不会打开它。';

  @override
  String get desktopFolderNotPrivate => 'Kryfo 无法把它的文件夹设为只有你能访问，所以不会打开。';

  @override
  String get desktopLockOtherVersion => '这个锁是另一个版本的 Kryfo 创建的，当前版本无法读取。';

  @override
  String get desktopNoMemoryFolder =>
      'Kryfo 运行时需要内存中的一个私有文件夹，而这台电脑没有提供，所以 Kryfo 不会打开。';

  @override
  String get inviteNotYet => '此邀请尚未生效。请检查手机上的时间。';

  @override
  String get inviteNotYetDesk => '此邀请尚未生效。请检查电脑上的时间。';

  @override
  String get inviteExpired => '此邀请已过期。请索取新的邀请。';

  @override
  String get inviteDamaged => '此邀请已损坏。请索取新的邀请。';

  @override
  String get helloSent => '请求已发送。对方上线后就会看到。';

  @override
  String get inviteNeeds06 => '需要 Kryfo 0.6 或更新版本。';

  @override
  String get helloSentOld => '请求已发送。如果对方使用的是旧版 Kryfo，需要先更新。';

  @override
  String get modesPickHow => '选择消息的传送方式。随时都可以更改。';

  @override
  String get modesPrivate => '私密';

  @override
  String get modesPrivateTag => 'Tor · 需要时用网桥';

  @override
  String get modesPrivateLine => '没有人能知道你的 IP 地址或你是谁，连我们的服务器也不能。遇到封锁会自己找到出路。';

  @override
  String get modesDefault => '默认';

  @override
  String get modesFastTag => '直连我们的服务器';

  @override
  String get modesFastLine =>
      '不经过 Tor，消息到得更快，也更省电。我们的服务器只在你连接期间看到你的 IP 地址，从不记录或保存。你的联系人永远看不到它。你的网络能看到你在连接 Kryfo。';

  @override
  String get modesFastConnected => '快速 · 已连接';

  @override
  String get modesFastConnecting => '快速 · 正在连接';

  @override
  String get modesFastDown => '快速 · 我们的服务器没有响应';

  @override
  String get modesBackupReady => '始终有一台备用服务器待命，即使其中一台出问题，你也不会断线。';

  @override
  String get modesDetails => '详情';

  @override
  String get modesBothLine => '两种方式都对每条消息端到端加密。不同的只是谁能看到你的 IP 地址。';

  @override
  String get modesConnectionBridges => '连接与网桥';

  @override
  String get modesWhatServersSee => '我们的服务器能看到什么';

  @override
  String get serversTitle => '快速模式的服务器';

  @override
  String get serversLine => '每条消息同时发往两台服务器。先响应的那台负责送达，一台停了另一台就接手。';

  @override
  String get serversOne => '服务器 1';

  @override
  String get serversTwo => '服务器 2 · 另一家服务商';

  @override
  String get serversConnected => '已连接';

  @override
  String get serversConnecting => '正在连接';

  @override
  String get serversNotAnswering => '没有响应';

  @override
  String serversMs(int ms) {
    return '$ms 毫秒';
  }

  @override
  String get serversQuicker => '更快';

  @override
  String get serversBackups => '公共中继';

  @override
  String get serversBackupsLine =>
      '在服务器 1 停摆期间使用，而且只经 Tor 连接，所以它们永远看不到你的 IP 地址。';

  @override
  String get serversStandingBy => '待命中';

  @override
  String get serversInUse => '使用中';

  @override
  String get homeMergedTitle => '中继和快速现已合二为一';

  @override
  String get homeMergedLine =>
      '你正在使用快速模式。始终有一台备用服务器待命，即使其中一台出问题，你也不会断线。我们的服务器能看到你的 IP 地址，但永远看不到你说了什么。';

  @override
  String get homeMergedGotIt => '知道了';

  @override
  String get homeMergedUsePrivate => '改用私密';

  @override
  String get homeOursDownTitle => '我们的服务器没有响应';

  @override
  String get homeOursDownLine => '几分钟后，只要 Tor 能连通，消息也会走公共中继，我们任意一台服务器一响应就换回来。';

  @override
  String get homeUsePrivate => '使用私密';

  @override
  String get homeSwitchedToPrivate => '已切换到私密';

  @override
  String get homeUseFast => '使用快速';

  @override
  String get homeSwitchedToFastRoute => '已切换到快速';

  @override
  String get bridgesBridgeFirstFastSeen =>
      '让 Kryfo 找一个能连通的网桥。快速模式也行，但这个网络能看到你在连接 Kryfo。';

  @override
  String get appServersNotAnswering => '服务器没有响应';

  @override
  String get settingsPrivateTor => '私密 · Tor';

  @override
  String get seenOurServers => '我们的服务器';

  @override
  String get seenOurServersCould => '我们的服务器可能看到';

  @override
  String get seenIpWhy =>
      '私密模式下一切都经 Tor 发出，我们的服务器看到的是出口节点，永远不是你。快速模式下连接直达我们的两台服务器：你连接期间它们能看到你的 IP 地址，但不留任何记录。第一台停摆期间，快速模式也会使用公共中继，而且只经 Tor 连接。';

  @override
  String get chatAlbumItDisappearsWithNo => '这个相册会从双方的手机上删除，除非已被保存。此操作无法撤销。';

  @override
  String get chatAlbumItDisappearsWithNoDesk =>
      '这个相册会从双方的设备上删除，除非已被保存。此操作无法撤销。';

  @override
  String get groupChatAlbumItDisappearsWithNo =>
      '这个相册会从所有人的手机上删除，除非已被保存。此操作无法撤销。';

  @override
  String get groupChatAlbumItDisappearsWithNoDesk =>
      '这个相册会从所有人的设备上删除，除非已被保存。此操作无法撤销。';

  @override
  String get homeInviteSomeone => '邀请一个人';

  @override
  String get onboardingNameHeadline => '如果你愿意，起一个公开的 *@名字*。';

  @override
  String get onboardingNameLine => '公开的 @名字能让别人找到你。\n跳过会更私密。\n你以后可以再加。';

  @override
  String get onboardingNameSkip => '先跳过 →';

  @override
  String onboardingNameClaim(Object handle) {
    return '使用 @$handle →';
  }

  @override
  String get onboardingInviteHeadline => '现在，*邀请一个人*。';

  @override
  String get onboardingInviteLead => '用任何聊天软件发一个链接。\n它会打开 Kryfo，或告诉对方去哪里下载。';

  @override
  String get onboardingInviteSomeone => '邀请一个人 →';

  @override
  String get onboardingInviteGettingReady => '正在准备你的链接…';

  @override
  String inviteShareText(Object myId, Object link, Object download) {
    return '在 Kryfo 上加我。我的名字是 $myId\n\n点这里加我：\n$link\n\n还没有 Kryfo？在这里下载：\n$download\n\nKryfo 是一款私密通讯应用。不用手机号，不用邮箱。';
  }

  @override
  String get inviteNotReady => '你的链接快好了。稍后再试一次。';

  @override
  String get photoCropTitle => '移动和缩放';

  @override
  String get photoCropUse => '使用照片';

  @override
  String get photoCropLabel => '圆圈里是你的照片。双指缩放，拖动移动';

  @override
  String get photoCouldNotUse => '换一张照片试试。这张无法读取。';

  @override
  String get photoTake => '拍照';

  @override
  String get photoChoose => '从相册选择';

  @override
  String get photoPickFace => '选择头像';

  @override
  String get photoView => '查看照片';

  @override
  String get photoRemove => '移除照片';

  @override
  String get photoYourPhoto => '你的照片';

  @override
  String get photoYourPhotoLine => '只有你的联系人能看到，端到端加密。';

  @override
  String get photoSetTheirs => '设置照片';

  @override
  String get photoChangeTheirs => '更换照片';

  @override
  String get photoOnlyHere => '只在这部手机上';

  @override
  String get photoOnlyHereDesk => '只在这台电脑上';

  @override
  String photoForThem(Object name) {
    return '给$name的照片';
  }

  @override
  String get photoOnlyHereLine => '只有你能看到。只保存在这部手机上。';

  @override
  String get photoOnlyHereLineDesk => '只有你能看到。只保存在这台电脑上。';

  @override
  String photoOf(Object name) {
    return '$name的照片';
  }

  @override
  String get historyChatStaysShots => '此聊天禁止截屏，所以只留在你的手机上。';

  @override
  String chatDeviceReplyFromPhone(String name) {
    return '$name 使用的是较旧版本的 Kryfo。请在手机上回复。';
  }

  @override
  String chatDeviceReplyFromPhoneForNow(String name) {
    return '暂时请在手机上回复 $name。';
  }

  @override
  String get linkedClearHereOnly => '这里的每条消息只会从这台电脑上清除。你的手机会保留它们。';

  @override
  String get linkedDeleteHereOnly => '所有消息和这位联系人只会从这台电脑上移除。你的手机会保留这段聊天。';

  @override
  String get linkedBlockHereOnly =>
      '对方的消息将不再送达这台电脑。对方不会被告知。在手机上屏蔽对方，手机上也不会再收到。';

  @override
  String get historyCopyTitle => '聊天记录';

  @override
  String get historyCopyMaking => '正在准备你的聊天';

  @override
  String get historyCopyMakingLine => '你的手机正在整理要复制的内容，马上开始。';

  @override
  String get historyCopyGoing => '正在复制你的聊天';

  @override
  String get historyCopyGoingLine => '复制完成前，请让两台设备保持在线。';

  @override
  String historyCopySize(Object size) {
    return '共 $size';
  }

  @override
  String get historyCopyWaiting => '正在等待另一台设备';

  @override
  String get historyCopyWaitingLine => '两台设备都在线时，复制会自动继续。';

  @override
  String get historyCopyPaused => '复制稍作停顿';

  @override
  String get historyCopyPausedLine => '一分钟后继续。';

  @override
  String get historyCopyWhole => '所有消息和文件都已复制';

  @override
  String get historyCopyWholeLine => '没有遗漏。';

  @override
  String get historyCopyRows => '你的联系人和群组已复制';

  @override
  String get historyCopyRowsLine => '它们已复制过来，不含任何消息。从现在起，新消息会显示在这台设备上。';

  @override
  String get historyCopyGaps => '大部分聊天已复制';

  @override
  String get historyCopyGapsLine => '这些聊天在新设备上的内容比手机上少。';

  @override
  String historyCopyGapMessages(Object got, Object want) {
    return '消息：$got / $want';
  }

  @override
  String historyCopyGapFiles(Object got, Object want) {
    return '文件：$got / $want';
  }

  @override
  String historyCopyLeft(num count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 项留在你的手机上',
    );
    return '$_temp0';
  }

  @override
  String get historyCopyLeftWhy => '太大或无法读取，无法复制。';

  @override
  String historyCopyLeftChats(num count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 个聊天留在你的手机上',
    );
    return '$_temp0';
  }

  @override
  String get historyCopyEnded => '复制已停止';

  @override
  String get historyCopyEndedLine => '不会再有内容复制过来。重新关联设备即可重新复制。';

  @override
  String get historyCopyFailed => '复制未能完成';

  @override
  String get historyCopyFailedLine => '重新关联设备即可重新复制。';

  @override
  String get historyCopyStays => '留在你的手机上';

  @override
  String get historyCopySee => '查看复制情况';

  @override
  String a11yPinDigits(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 位数字',
      zero: '没有数字',
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
      other: '$countString 个字符',
      zero: '没有字符',
    );
    return '$_temp0';
  }

  @override
  String get a11yBackupProgress => '备份进度';

  @override
  String get a11yRestoreProgress => '恢复进度';

  @override
  String get a11yExportProgress => '导出进度';

  @override
  String get a11yLockFileProgress => '锁定进度';

  @override
  String get a11yCleanProgress => '清理进度';

  @override
  String get a11yMessageActions => '消息操作';

  @override
  String get a11yRecordVoiceNote => '录制语音消息';

  @override
  String get a11yRecording => '正在录音';

  @override
  String a11yPhotoOn(String date) {
    return '照片，$date';
  }

  @override
  String a11yPhotoFrom(String name, String date) {
    return '$name 发来的照片，$date';
  }

  @override
  String a11yVideoOn(String date) {
    return '视频，$date';
  }

  @override
  String a11yVideoFrom(String name, String date) {
    return '$name 发来的视频，$date';
  }

  @override
  String a11yNewMessages(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 条新消息',
      one: '新消息',
    );
    return '$_temp0';
  }

  @override
  String get wideSelectChat => '选择一个聊天';

  @override
  String get wideSelectChatLine => '从列表中选择一个聊天，开始写消息。';

  @override
  String get wideListWidth => '聊天列表宽度';

  @override
  String transferDoneOf(String done, String total) {
    return '$done/$total';
  }

  @override
  String transferDoneLeft(String done, String left) {
    return '$done · $left';
  }

  @override
  String get transferLeftSoon => '剩余不到一分钟';

  @override
  String transferLeftMinutes(String n) {
    return '剩余约 $n 分钟';
  }

  @override
  String transferLeftHours(String n) {
    return '剩余约 $n 小时';
  }

  @override
  String transferSending(String detail) {
    return '正在发送 · $detail';
  }

  @override
  String transferReceiving(String detail) {
    return '正在接收 · $detail';
  }

  @override
  String transferBoth(String detail) {
    return '正在收发 · $detail';
  }

  @override
  String get transferPause => '暂停';

  @override
  String get transferPauseDownload => '暂停下载';

  @override
  String get transferDownload => '下载';

  @override
  String get transferResume => '继续';

  @override
  String get transferOnWifi => '连接 Wi-Fi 时下载';

  @override
  String transferPausedAt(String detail) {
    return '已暂停 · $detail';
  }

  @override
  String get transferTapToDownload => '点按下载';

  @override
  String transferSizeLine(String size, String state) {
    return '$size · $state';
  }

  @override
  String get transferNoteTitle => '文件传输';

  @override
  String get transferChannel => '文件传输';

  @override
  String get transferChannelLine => '在发送或下载文件时显示。绝不显示聊天或文件的名称。';

  @override
  String get autoGetTitle => '自动下载';

  @override
  String get autoGetLine => '文件会按这里的设置自动到达。等待中的文件会在文件服务器上为你保留，最多一周。';

  @override
  String get autoGetPhotos => '照片';

  @override
  String get autoGetVideos => '视频';

  @override
  String get autoGetFiles => '文件';

  @override
  String get autoGetAlways => 'Wi-Fi 和移动数据';

  @override
  String get autoGetWifi => '仅 Wi-Fi';

  @override
  String get autoGetNever => '从不，我点按下载';

  @override
  String get autoGetVoice => '语音消息总是会下载。';

  @override
  String get settingsFiles => '文件';

  @override
  String get fileSheetOpenWith => '用其他应用打开';

  @override
  String get desktopLockAccountBody => 'Kryfo 在这台电脑上保存的所有内容都已加密。它会用你的用户账户打开。';

  @override
  String get desktopLockAddPassphrase => '添加密码短语';

  @override
  String get desktopLockWithoutPassphrase => '没有它，任何使用你的用户账户的人都能打开 Kryfo。';

  @override
  String get desktopLockKeyringRefused =>
      'Kryfo 无法把它的密钥保存在这台电脑的密钥环中。请改为添加密码短语。';

  @override
  String get desktopKeyMissing =>
      '这个用户账户没有 Kryfo 数据的密钥。Kryfo 备份能找回一切。如果你移动过 Kryfo 的文件夹，请在它原来的用户账户上添加密码短语，然后再复制一次。';

  @override
  String get desktopKeyUnreachable =>
      'Kryfo 现在无法取得这台电脑上的密钥。如果电脑提示，请解锁你的密钥环，然后重试。';

  @override
  String get desktopPassRow => '这台电脑上的密码短语';

  @override
  String get desktopPassWindowsAccount => '由你的 Windows 账户锁定';

  @override
  String get desktopPassKeyring => '由你的密钥环锁定';

  @override
  String get desktopPassOffBody => 'Kryfo 会用你的用户账户打开。';

  @override
  String get desktopPassOnBody => 'Kryfo 每次启动时都会询问这个密码短语。';

  @override
  String get desktopPassChange => '更改密码短语';

  @override
  String get desktopPassRemove => '移除密码短语';

  @override
  String get desktopPassCurrent => '当前密码短语';

  @override
  String get desktopPassNew => '新的密码短语';

  @override
  String get desktopPassStays => '这台电脑上没有 Kryfo 能用的密钥环，所以密码短语会保留。';

  @override
  String get desktopPassAdded => '已添加密码短语';

  @override
  String get desktopPassRemoved => '已移除密码短语';

  @override
  String get desktopPassChanged => '已更改密码短语';

  @override
  String get desktopPassRemoveBody => '输入你的密码短语来移除它。之后 Kryfo 会用你的用户账户打开。';

  @override
  String get desktopKeyUnreachableWindows => 'Kryfo 现在无法取得这台电脑安全芯片中的密钥。请稍后重试。';

  @override
  String get desktopLockAccountRefused =>
      'Kryfo 无法用你的 Windows 账户保存它的密钥。请改为添加密码短语。';

  @override
  String get desktopPassStaysWindows =>
      'Kryfo 无法用你的 Windows 账户保存它的密钥，所以密码短语会保留。';

  @override
  String get desktopBackupCardTitle => '留一份 Kryfo 备份';

  @override
  String get desktopBackupCardLine =>
      '这台电脑上的 Windows 账户保管着 Kryfo 的密钥。如果电脑或账户被重置，Kryfo 备份能找回一切。';

  @override
  String get desktopBackupHint => '如果这台电脑被重置，它能找回一切。';

  @override
  String chatHealRestored(Object name) {
    return '$name 重新设置了 Kryfo';
  }

  @override
  String chatHealNewSession(Object name) {
    return '$name 的设备开始了新的安全会话';
  }

  @override
  String chatHealHeldLine(Object name) {
    return '你之前验证过 $name。在你核对安全码或继续聊天之前，什么都不会发出。对方的消息仍会收到。';
  }

  @override
  String get chatKeepChatting => '继续聊天';

  @override
  String chatNeedsUpdateToChat(Object name) {
    return '$name 需要更新 Kryfo 才能继续聊天';
  }

  @override
  String get restoreOlderTitle => '部分聊天将暂停';

  @override
  String restoreOlderOne(Object name) {
    return '$name 使用的是旧版 Kryfo。在对方更新前，你们的聊天会暂停。';
  }

  @override
  String restoreOlderTwo(Object first, Object second) {
    return '$first 和 $second 使用的是旧版 Kryfo。在他们更新前，你和他们的聊天会暂停。';
  }

  @override
  String restoreOlderMany(Object first, Object second, int count) {
    return '$first、$second 和另外 $count 人使用的是旧版 Kryfo。在他们更新前，你和他们的聊天会暂停。';
  }

  @override
  String settingsVersionAlpha(String version) {
    return '$version · alpha 版';
  }

  @override
  String get settingsDeskInTray => '在系统托盘中运行';

  @override
  String get settingsDeskWhileOpen => 'Kryfo 打开期间';

  @override
  String get onboardingDeskRunTitle => 'Kryfo 一直*在线*。';

  @override
  String get onboardingDeskRunLead =>
      '关闭窗口后，Kryfo 会在系统托盘中等候。\n消息照常到达。\n这两项都可以在“设置”的“通知”里更改。';

  @override
  String get savedLongPressAnyMessageDesk => '右键点击任意消息，选“保存”，就能把它留在这里。';

  @override
  String get chatFailedTapToRetryDesk => '失败 · 单击重试';

  @override
  String get groupChatTapToRetryDesk => '! 单击重试';

  @override
  String get chatDropHereToSend => '拖到这里松开即可发送';

  @override
  String get chatDropHereToAdd => '拖到这里松开即可添加';

  @override
  String trayRemove(String name) {
    return '移除 $name';
  }

  @override
  String trayReadyToSend(Object count) {
    return '待发送：$count';
  }

  @override
  String get trayPastedPicture => '粘贴的图片';

  @override
  String get voiceSeeTranscription => '查看文字';

  @override
  String get voiceTranscribing => '正在转成文字…';

  @override
  String get voiceHideTranscription => '收起';

  @override
  String get voiceShowOriginalOnly => '只看原文';

  @override
  String get voiceCouldNotTranscribe => '没能听出内容';

  @override
  String get voiceTranscriptLabel => '文字内容';

  @override
  String get voiceSettingsTitle => '语音转文字';

  @override
  String get voiceOnRow => '把语音消息转成文字';

  @override
  String get voiceOnHint => '在每条语音消息下方提供';

  @override
  String get voiceOffDeletes => '关闭后会删除已保存的文字内容。';

  @override
  String get voiceModelTitle => '语音模型';

  @override
  String voiceModelLine(Object size) {
    return '只需下载一次，约 $size，支持所有语言。';
  }

  @override
  String get voiceModelPrivacy => '通过 Tor 下载并保存在这部手机上。你的语音消息从不离开它。';

  @override
  String get voiceModelPrivacyDesk => '通过 Tor 下载并保存在这台电脑上。你的语音消息从不离开它。';

  @override
  String get voiceModelFailNoTor => 'Tor 还没有连接。模型只通过 Tor 下载，请在连接后重试。';

  @override
  String get voiceModelRemoveTitle => '移除语音模型？';

  @override
  String get voiceModelRemoveLine => '已生成的文字会保留。新的需要再次下载模型。';

  @override
  String get voiceKeptNote => '文字内容与所属聊天一起加密保存在这部手机上，并随聊天一起删除。';

  @override
  String get voiceKeptNoteDesk => '文字内容与所属聊天一起加密保存在这台电脑上，并随聊天一起删除。';

  @override
  String get voiceNotNow => '暂不';

  @override
  String get unlinkedTitle => '这台设备已解除关联';

  @override
  String get unlinkedRemovedLine => '你的手机已把它从账号中移除，所以 Kryfo 抹除了它在这里保存的一切。';

  @override
  String get unlinkedUnusedLine => '它 30 天没被打开，所以 Kryfo 抹除了它在这里保存的一切。';

  @override
  String get unlinkedSilentLine => '它 30 天没有收到你手机的任何消息，所以 Kryfo 抹除了它在这里保存的一切。';

  @override
  String get unlinkedClockLine => '它的时钟被调回了，所以 Kryfo 为保护你的聊天，抹除了它在这里保存的一切。';

  @override
  String get unlinkedBrokenLine =>
      'Kryfo 无法得知它上次是何时被打开的，所以为保护你的聊天，抹除了它在这里保存的一切。';

  @override
  String get unlinkedSelfLine => '你解除了它的关联，所以 Kryfo 抹除了它在这里保存的一切。';

  @override
  String get unlinkedAgainLine => '你的聊天仍在手机上。要在这里再次使用 Kryfo，请把这台设备关联到你的手机。';

  @override
  String get unlinkedClose => '关闭 Kryfo';

  @override
  String get devicesLeave => '解除这台设备的关联';

  @override
  String get devicesLeaveTitle => '解除这台设备的关联？';

  @override
  String get devicesLeaveLine => 'Kryfo 会告诉你的手机，并抹除它在这里保存的一切。你的聊天仍在手机上。';

  @override
  String get devicesLeaveYes => '解除关联并抹除';

  @override
  String get devicesGoneNotice => '设备已移除';

  @override
  String devicesGoneRemovedLine(Object name, Object date) {
    return '$name 于 $date 从你的账号中移除。';
  }

  @override
  String devicesGoneUnusedLine(Object name, Object date) {
    return '$name 30 天没有使用，所以于 $date 从你的账号中移除。';
  }

  @override
  String devicesGoneItselfLine(Object name, Object date) {
    return '$name 于 $date 自己解除了关联，并抹除了上面保存的内容。';
  }

  @override
  String get devicesChangedNotice => '你的设备有变化';

  @override
  String get devicesChangedLine => '打开“已关联的设备”查看变化。';

  @override
  String get devicesUnknownNotice => '在别处关联的设备';

  @override
  String get devicesUnknownLine => '另一份 Kryfo 把一台设备关联到了你的账号。这部手机已把它从你的列表中移除。';

  @override
  String get albumPrevious => '上一个';

  @override
  String get albumNext => '下一个';

  @override
  String get notesHoldHintDesk => '右键点击一条笔记即可复制或删除。';

  @override
  String get pinsNothingPinnedHereYetDesk =>
      '这里还没有置顶内容。右键点击一条消息，选择“置顶”，它就会在这里等着聊天里的每个人。';

  @override
  String get chatGalleryDesk => '图片';

  @override
  String get groupChatGalleryDesk => '图片';

  @override
  String get photoChooseDesk => '选择图片文件';

  @override
  String get wallpaperFromYourPhotosDesk => '从图片文件';

  @override
  String get notificationsSoundAndVibrationDesk => '声音';

  @override
  String get notificationsPlaySound => '播放提示音';

  @override
  String get notificationsPlaySoundHint => '这台电脑上的每条通知都会响';

  @override
  String bridgesShareBridgeN(String n) {
    return '分享网桥 $n';
  }

  @override
  String get bridgesShareThisBridge => '分享这个网桥';

  @override
  String get bridgesShareItPrivately => '请私下分享给你信任的人。不出现在公开页面上的网桥能用得更久。';

  @override
  String get bridgesCopyBridge => '复制网桥';

  @override
  String get bridgesBridgeCopied => '网桥已复制';

  @override
  String get bridgesSendBridgeTo => '把网桥发给';

  @override
  String get linkedAddOnPhone => '在手机上添加联系人。他们也会出现在这里。';

  @override
  String get linkedLinkOnPhone => '在手机上打开这个链接。';

  @override
  String get linkedDoOnPhone => '请在手机上操作。';

  @override
  String get tipsTitle => '支持 Kryfo';

  @override
  String get tipsHeadline => '让 Kryfo *对所有人免费*';

  @override
  String get tipsLine => '没有广告，没有投资人，没有账号。打赏帮忙支付服务器和 Kryfo 的开发工作。';

  @override
  String get tipsLeave => '打赏';

  @override
  String get tipsYours => '已拥有';

  @override
  String get tipsAsking => '正在向 Google Play 询问价格';

  @override
  String get tipsBadgeOnly => '打赏会给你一枚支持者徽章，除此之外什么都没有。不管打不打赏，Kryfo 的一切对所有人都免费。';

  @override
  String get tipsThroughPlay => '付款通过 Google Play 完成。我们永远看不到你的银行卡信息，也看不到你的名字。';

  @override
  String get tipsBadgeStays => '徽章保存在这部手机上。在“我”里，你可以选择是否显示它，以及联系人能否看到它。';

  @override
  String get tipsRestore => '恢复我的徽章';

  @override
  String get tipsRestoreLine => '以前打赏过？在登录同一个 Google 账号的任何手机上，你的徽章都会回来。';

  @override
  String tipsRestored(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter': '你的支持者徽章回来了',
      'patron': '你的赞助人徽章回来了',
      'guardian': '你的守护者徽章回来了',
      'other': '你的支持者徽章回来了',
    });
    return '$_temp0';
  }

  @override
  String get tipsNothingToRestore => '这个 Google 账号还没有打赏过';

  @override
  String get tipsUnavailable =>
      '打赏通过 Google Play 完成。等 Google Play 在这部手机上能用了，打赏就会出现在这里。';

  @override
  String get tipsSoon => '打赏很快就会在这里开放。';

  @override
  String get tipsPending => 'Google Play 还在完成你的付款。付款一通过，你的徽章就会到来。';

  @override
  String get tipsFailed => 'Google Play 没有完成付款。请稍后再试。';

  @override
  String get tipsThanks => '谢谢你';

  @override
  String tipsGranted(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter': '你现在有了支持者徽章。它不会解锁其他任何东西：Kryfo 的一切对所有人都免费。',
      'patron': '你现在有了赞助人徽章。它不会解锁其他任何东西：Kryfo 的一切对所有人都免费。',
      'guardian': '你现在有了守护者徽章。它不会解锁其他任何东西：Kryfo 的一切对所有人都免费。',
      'other': '你现在有了支持者徽章。它不会解锁其他任何东西：Kryfo 的一切对所有人都免费。',
    });
    return '$_temp0';
  }

  @override
  String tipsKept(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter': '谢谢你的打赏。你保留更高的支持者徽章。',
      'patron': '谢谢你的打赏。你保留更高的赞助人徽章。',
      'guardian': '谢谢你的打赏。你保留更高的守护者徽章。',
      'other': '谢谢你的打赏。你保留更高的支持者徽章。',
    });
    return '$_temp0';
  }

  @override
  String get tipsProfileCard => '打赏一下，让 Kryfo 保持独立';

  @override
  String chatDeviceLinked(Object name) {
    return '$name 关联了一台新设备';
  }

  @override
  String chatDeviceRemoved(Object name) {
    return '$name 移除了一台设备';
  }

  @override
  String chatDeviceListUnchecked(Object name) {
    return '无法核对 $name 的设备列表';
  }

  @override
  String get notesDropToKeep => '拖到这里松开即可保存';

  @override
  String get notesOnAllDevices => '在你所有的设备上';

  @override
  String get notesKeepAnything => '在这里保存文字、照片和文件。它们会出现在你所有的设备上。';

  @override
  String get notesGoneEverywhere => '它会从你所有的设备上永久清除。';

  @override
  String get notesDeleteAllEverywhere => '所有笔记都会从你所有的设备上永久删除。';

  @override
  String get notesDeleteAllHereOnly => '所有笔记只会从这台设备上删除。你的手机仍会保留它们。';

  @override
  String get notesAddItem => '添加照片或文件';

  @override
  String get notesVoiceNotKept => '你的语音消息没有保存';

  @override
  String get handleOlderKryfo => '对方使用的是旧版 Kryfo。请对方先更新，然后再添加。';

  @override
  String groupMemberNeedsUpdate(Object name) {
    return '$name 使用的是旧版 Kryfo，需要更新后才能在这里收到消息。';
  }

  @override
  String get groupMembersNeedUpdate => '部分成员使用的是旧版 Kryfo，需要更新后才能在这里收到消息。';

  @override
  String get onboardingAlwaysOnNotice =>
      'Android 需要一条常驻的静音通知，这样 Kryfo 关闭时也能收到消息。';

  @override
  String get toolsSendToAChat => '发送到聊天';

  @override
  String get toolsOneFileAtATime => '一次一个文件';

  @override
  String get toolsLockThisFile => '锁定这个文件';

  @override
  String get toolsLockThisFileLine => 'Kryfo 可以用密码锁定它，只有知道密码的人才能打开。';

  @override
  String get toolsDropHere => '把文件拖到这里，用工具打开';

  @override
  String get toolsCopyPicture => '复制图片';

  @override
  String get toolsPictureCopied => '图片已复制';

  @override
  String get toolsCouldNotCopy => '无法复制图片';

  @override
  String get cleanNotYetHere => '这张图片暂时还不能在这里清理';

  @override
  String get cleanNotYetHereLine => '即将推出的更新会在电脑上清理这样的图片。你的图片原封未动。';
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
  String get accentYellow => '黃色';

  @override
  String get accentGrey => '灰色';

  @override
  String get accentPurple => '紫色';

  @override
  String get accentLime => '青檸';

  @override
  String get accentVelvet => '絲絨紅';

  @override
  String get accentBlue => '藍色';

  @override
  String get appearancePreview => '你的聊天在這個顏色下的預覽';

  @override
  String get appearanceSampleIn => '今晚還照舊嗎？';

  @override
  String get appearanceSampleOut => '照舊。八點，老地方。';

  @override
  String get appearanceSampleButton => '回覆';

  @override
  String get appearanceAccentHint => '按鈕、你自己的訊息和連結都會用這個顏色。應用程式圖示保持黃色。';

  @override
  String get appearanceChatWallpaper => '聊天桌布';

  @override
  String get appearanceEveryChat => '所有聊天';

  @override
  String get appearanceWallpaperHint =>
      '在聊天選單裡為它單獨設定的桌布優先。照片只留在這支手機上，和你的聊天一起加密。';

  @override
  String get appearanceWallpaperHintDesk =>
      '在聊天選單裡為它單獨設定的桌布優先。照片只留在這台電腦上，和你的聊天一起加密。';

  @override
  String get backupThatPassphraseDoesNot => '這組密碼短語打不開這個檔案';

  @override
  String get backupThatFileIsNot => '這個檔案不是 Kryfo 備份';

  @override
  String get backupThisBackupIsFrom => '這份備份來自較新版的 Kryfo。請先更新應用程式，再試一次';

  @override
  String get backupThisFileIsDamaged => '這個檔案已損毀，無法讀取';

  @override
  String get backupTheRestoreStoppedPartway => '還原中途停止了';

  @override
  String get backupCouldNotMakeThe => '無法建立金鑰';

  @override
  String get contactCardMessageMeOn => '傳訊息給我，請用';

  @override
  String get contactCardScanToAdd => '用 Kryfo 掃描即可加我。\n除此之外，這張卡片對你一無所知。';

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
  String get appNoRelayReached => '未能連上任何中繼';

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
  String get appAnAttachmentCouldNotDesk => '有個附件無法儲存到這台電腦';

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
  String appJoined(Object linkName) {
    return '已加入 $linkName';
  }

  @override
  String get roomJoinWaitingToJoin => '等待加入';

  @override
  String get roomJoinNotAnswering => '沒有回應';

  @override
  String roomJoinWaitingFor(Object room) {
    return '正在等待 $room 讓你加入…';
  }

  @override
  String get roomJoinWaitingLine => '進入後就可以在這裡發訊息。';

  @override
  String get roomJoinNoAnswer => '這個聊天室沒有回應。';

  @override
  String get roomJoinMayHaveEnded => '它可能已經結束了。';

  @override
  String get roomJoinFullShort => '聊天室已滿';

  @override
  String get roomJoinFull => '這個聊天室已滿。';

  @override
  String get roomJoinFullLine => '現在沒有空位。請稍後再試，或問問分享連結的人。';

  @override
  String get appBooting => '啟動中…';

  @override
  String get appSettingUpYourIdentity => '正在設定你的身分…';

  @override
  String get appAddSomeone => '新增聯絡人';

  @override
  String get appScanTheirCodeOr => '掃描對方的 QR 碼，或貼上對方給你的內容：連結、@使用者名稱或聊天室連結。';

  @override
  String get appScanTheirCodeOrDesk => '貼上對方給你的內容：連結、@使用者名稱或聊天室連結。';

  @override
  String get appScanTheirCode => '掃描對方的 QR 碼';

  @override
  String get appAKryfoLinkA => 'Kryfo 連結、聊天室連結或 @name';

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
  String get appStartingTor30s => '正在啟動 Tor（約 30 秒）…';

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
  String get appReadyToChatAddressFinishing => '可以聊天了 · 位址即將就緒';

  @override
  String get appTor => 'Tor';

  @override
  String get appTorIsOffTurn => 'Tor 已關閉。開啟它才能私密連線。';

  @override
  String get appTheFirstConnectionTakes =>
      '第一次連線需要一、兩分鐘，讓 Tor 建立一條私密路線。之後路線會被快取，下次開啟 Kryfo 就快多了。';

  @override
  String get appTorNoRelayYet =>
      'Tor 已啟動，但還沒有中繼回應。Kryfo 會繼續嘗試，訊息會在這裡等候，直到有中繼回應。';

  @override
  String get appRelayAndFastModes => '快速模式不經過 Tor，所以更快。它在設定的「速度與隱私」裡，並說明了代價。';

  @override
  String get appOffline => '離線';

  @override
  String get appTorOff => 'Tor 關閉';

  @override
  String get appTorReady => 'Tor 就緒';

  @override
  String get appConnecting2 => '連線中';

  @override
  String get appWaitingForARelay => '正在等待中繼';

  @override
  String appStartingTorPct(Object pct) {
    return '正在啟動 Tor · $pct';
  }

  @override
  String get appGettingNewMessages => '正在接收新訊息';

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
  String get miuiAutostartOpenSettings => '開啟設定';

  @override
  String get miuiAutostartCouldnTOpenIt => '無法開啟。請在手機設定中尋找「自動啟動」';

  @override
  String get batteryGuideHuawei =>
      '華為和榮耀會關閉由系統自動管理的應用程式。請在下一個畫面找到 Kryfo，關閉「自動管理」，並保持「允許自動啟動」「允許關聯啟動」和「允許背景活動」開啟。';

  @override
  String get batteryGuideOppo =>
      'OPPO 和 realme 會停止背景應用程式。請在下一個畫面找到 Kryfo，允許「自動啟動」。再到「電池」裡，也允許它在背景執行。';

  @override
  String get batteryGuideVivo =>
      'vivo 會停止背景應用程式。請在下一個畫面找到 Kryfo，允許它在背景啟動。再到「電池」裡，也允許它在背景高耗電。';

  @override
  String get batteryGuideSamsung =>
      '三星會讓它認為不常用的應用程式進入休眠。請在下一個畫面開啟「背景使用限制」，把 Kryfo 加入「永不休眠的應用程式」。';

  @override
  String get batteryGuideOnePlus =>
      '一加會停止背景應用程式。請在下一個畫面找到 Kryfo，允許「自動啟動」。再到「電池」裡，把它設為「不最佳化」。';

  @override
  String get batteryGuideXiaomiTitle => '讓 Kryfo 保持執行';

  @override
  String get batteryGuideXiaomi => '即使開了自動啟動，小米也會停止背景應用程式。如要持續收到訊息：';

  @override
  String get batteryGuideXiaomiStep1 => '自動啟動：為 Kryfo 打開。';

  @override
  String get batteryGuideXiaomiStep2 => '省電策略：把 Kryfo 設為「無限制」。';

  @override
  String get batteryGuideXiaomiStep3 =>
      '最近使用的應用程式：長按 Kryfo，點一下鎖頭，這樣「全部清除」和手機的自動清理都不會關掉它。';

  @override
  String get batteryGuideXiaomiAfter => '如果手機還是停止了 Kryfo，在你重新開啟它之前，什麼都收不到。';

  @override
  String get notificationsNewEncryptedMessagesFrom => '來自聯絡人的加密新訊息';

  @override
  String get notificationsNewMessage => '新訊息';

  @override
  String get notificationsNewEncryptedMessagesFromYourContacts => '來自聯絡人的加密新訊息';

  @override
  String get notificationsNewMessage2 => '新訊息';

  @override
  String get notificationsSomeone => '某人';

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
  String scamShieldGivesUsedName(Object shown) {
    return '自稱是 $shown，這裡已有人用這個名字';
  }

  @override
  String scamShieldWarning(Object noticed) {
    return '$noticed。不要給沒見過面的人轉錢或傳驗證碼。';
  }

  @override
  String get scamShieldAsksForSecret => '要你提供驗證碼、PIN 碼或復原詞';

  @override
  String get scamShieldAsksForMoneyFast => '催著要錢';

  @override
  String get scamShieldPromisesProfit => '承諾輕鬆賺錢';

  @override
  String get scamShieldClaimsSupport => '自稱來自 Kryfo 或客服團隊';

  @override
  String get scamShieldDismiss => '隱藏';

  @override
  String scamShieldNameMatchesYourContact(Object shown) {
    return '名字和你的聯絡人 $shown 相同';
  }

  @override
  String get scamShieldLinksToALookalike => '附上仿冒知名網站的連結';

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
  String get avatarPickerPickAFace => '選一個頭像';

  @override
  String get commonSave => '儲存';

  @override
  String get backupPassphraseMustBeAt => '密碼短語至少要 12 個字元';

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
  String get backupACopyToKeepDesk => '留一份副本。這台電腦照常使用。';

  @override
  String get backupMoveToAnotherDevice => '移到另一台裝置';

  @override
  String get backupTheFileTakesThis =>
      '這個檔案會帶走這個身分。檔案一建立，這支手機就會停止：這裡不會再收到任何新內容，從這裡傳出的東西也不會送達任何人。';

  @override
  String get backupTheFileTakesThisDesk =>
      '這個檔案會帶走這個身分。檔案一建立，這台電腦就會停止：這裡不會再收到任何新內容，從這裡傳出的東西也不會送達任何人。';

  @override
  String get backupOneEncryptedFileYour =>
      '一個加密檔案：你的身分、聯絡人、每則訊息，以及每張照片、每段語音和每個檔案。在另一台裝置上用密碼短語匯入。在那之前，你仍然可以改變主意，繼續留在這支手機上。';

  @override
  String get backupOneEncryptedFileYourIdentityYour =>
      '一個加密檔案：你的身分、聯絡人、每則訊息，以及此刻這支手機上的每張照片、每段語音和每個檔案。今天之後說的話都不在裡面，所以重要的時候請再做一份。還原時需要檔案和密碼短語，兩者缺一不可。';

  @override
  String get backupOneEncryptedFileYourIdentityYourDesk =>
      '一個加密檔案：你的身分、聯絡人、每則訊息，以及此刻這台電腦上的每張照片、每段語音和每個檔案。今天之後說的話都不在裡面，所以重要的時候請再做一份。還原時需要檔案和密碼短語，兩者缺一不可。';

  @override
  String get backupPassphrase => '密碼短語';

  @override
  String get backupConfirmPassphrase => '確認密碼短語';

  @override
  String backupWriting(Object progress) {
    return '寫入中… $progress';
  }

  @override
  String get backupSaveComesAfter => '檔案準備好後，你再選擇儲存位置。';

  @override
  String get backupSaving => '儲存中…';

  @override
  String backupSavedIn(String place) {
    return '備份已儲存到 $place · 請妥善保管密碼短語';
  }

  @override
  String get backupNotSaved => '備份沒有儲存。檔案還在。';

  @override
  String get backupNotSavedNoSpace => '你選擇的位置空間不足。檔案還在，請換個位置，或釋放一些空間。';

  @override
  String get backupShareInstead => '改為分享';

  @override
  String get backupSavedUnchecked => '備份已儲存，但 Kryfo 無法檢查這份副本';

  @override
  String get backupHandedOver => '備份已交給你選擇的應用程式 · 請確認它已收到';

  @override
  String get backupMoveReachedTitle => '檔案已經到新手機上了嗎？';

  @override
  String get backupMoveReachedTitleDesk => '檔案已經到新裝置上了嗎？';

  @override
  String get backupMoveReachedLine => '在新手機上打開它之前，請留著這支手機。';

  @override
  String get backupMoveReachedLineDesk => '在新裝置上打開它之前，請留著這台電腦。';

  @override
  String get backupFinishTheMove => '完成搬移';

  @override
  String get backupNotYet => '還沒有';

  @override
  String get backupCreating => '建立中…';

  @override
  String get backupMakeTheFileAnd => '建立檔案並搬移';

  @override
  String get backupCreateBackup => '建立備份';

  @override
  String get backupNotMade => '備份沒能完成。請再試一次。';

  @override
  String get backupNoSpace => '手機可用空間不足，無法完成備份。請清理一些空間後再試一次。';

  @override
  String get backupNoSpaceDesk => '電腦可用空間不足，無法完成備份。請清理一些空間後再試一次。';

  @override
  String get backupHiddenNotIn => '隱藏聊天不在其中。';

  @override
  String get backupHiddenIncluded => '你的隱藏聊天也在其中。';

  @override
  String get backupMoveHiddenStay => '隱藏聊天留在這支手機上，並隨它一起抹除。';

  @override
  String get backupMoveHiddenStayDesk => '隱藏聊天留在這台電腦上，並隨它一起抹除。';

  @override
  String get backupHiddenGone => 'Kryfo 鎖定時，你的隱藏聊天已關閉。用隱藏聊天 PIN 開啟它們，再從那裡備份。';

  @override
  String get blockedBlocked => '已封鎖';

  @override
  String get blockedNoOneIsBlocked => '沒有封鎖任何人';

  @override
  String get commonUnblock => '解除封鎖';

  @override
  String get bridgesConnected => '已連線';

  @override
  String get bridgesFromTheTorProject => '來自 Tor 專案';

  @override
  String get bridgesPasteFromClipboard => '從剪貼簿貼上';

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
  String get bridgesWhenYouAskFor =>
      '你請求橋接時，Tor 專案會看到你的 IP 位址。這很正常：Tor Browser 和所有 Tor 應用程式都是這樣取得橋接的，他們從中只能知道有人請求了橋接，對你的聊天一無所知。';

  @override
  String get cameraNoCameraOnThis => '這支手機沒有相機';

  @override
  String get cameraCameraNotAvailable => '無法使用相機';

  @override
  String get cameraCameraPermissionIsOff => '相機權限已關閉';

  @override
  String get cameraOpenSettings => '開啟設定';

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
  String get cameraTooLongForA => '太長了，無法用訊息傳送 · 上限 50 MB';

  @override
  String get cameraNeverSavedToYour => '不會存到你的相簿';

  @override
  String get cameraNoExifNeverSaved => '沒有 EXIF，不會存到你的相簿';

  @override
  String get cameraRec => '錄影';

  @override
  String get cameraSwitchCamera => '切換相機';

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
  String chatEarlierMessagesArrived(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '收到 $countString 則更早的訊息',
    );
    return '$_temp0';
  }

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
  String get chatItDisappearsWithNo => '訊息會從雙方的手機上刪除，除非已被儲存。這個動作無法復原。';

  @override
  String get chatItDisappearsWithNoDesk => '訊息會從雙方的裝置上刪除，除非已被儲存。這個動作無法復原。';

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
  String get chatHowLongAfterReading => '訊息被讀取後要多久焚毀？你傳送的從傳送時開始計時。';

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
  String get chatGifFromPhoneDesk => '電腦裡的 GIF';

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
    return '$humanBytes · 經 Tor 需 $wireEstimate';
  }

  @override
  String get chatBigFilesGoOut => '大檔案會切成加密的小片段送出，所以需要一點時間。保持應用程式開啟，就會持續傳送。';

  @override
  String get chatSendIt => '傳送';

  @override
  String get chatCouldNotReadThat => '無法讀取那個檔案';

  @override
  String get chatCouldNotCleanThat => '無法清理那段影片';

  @override
  String get chatGifTooBig8 => 'GIF 太大 · 上限 8 mb';

  @override
  String get chatCouldNotCleanThatGif => '無法清理那個 GIF';

  @override
  String get chatTorIsNotUp => 'Tor 尚未連上 · 不加入連結預覽';

  @override
  String get chatCouldnTReachIt => '無法連上該頁面 · 不加入連結預覽';

  @override
  String get chatNoTitleCameBack => '該頁面沒有標題 · 不加入連結預覽';

  @override
  String get chatCouldnTFetchIt => '無法載入預覽';

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
  String get chatJustForYouNeverDesk => '只有你看得到。不會傳送，也不會離開這台電腦。';

  @override
  String get chatAQuietReminder => '給自己的小提醒…';

  @override
  String get chatNoteSaved => '備註已儲存';

  @override
  String get chatClearThisConversation => '要清空這段對話嗎？';

  @override
  String get chatEveryMessageHereIs => '這裡的每則訊息都會從這支手機上抹除。這只會清空你的副本，不會動到對方的裝置。';

  @override
  String get chatEveryMessageHereIsDesk =>
      '這裡的每則訊息都會從這台電腦上抹除。這只會清空你的副本，不會動到對方的裝置。';

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
  String get chatTheNextPhotoYou => '你傳送的下一張照片會以保護模式開啟 · Kryfo 會阻止對它截圖';

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
  String get chatWaitsToSend => '等待傳送';

  @override
  String get chatTheyMayNotKnow => '對方可能還不知道你已接受';

  @override
  String get chatYouBlockedThisContact => '你已封鎖這位聯絡人';

  @override
  String get chatSupporter => '支持者';

  @override
  String get chatEncryptedDirect => '已加密 · 直連';

  @override
  String get chatEncryptedOverTor => '已加密 · 經由 Tor';

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
  String get chatSayHiSoThey => '打聲招呼，讓對方看到你';

  @override
  String get chatTheyWonTKnow => '在你的第一則訊息送達前，對方不會知道已被你新增。';

  @override
  String get chatWave => '揮手';

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
  String get commonSend => '傳送';

  @override
  String get chatNoPhotosInThis => '這個聊天裡還沒有照片';

  @override
  String get chatHoldToRecord => '按住即可錄製語音訊息';

  @override
  String get chatSecurityCodeChanged => '安全碼已變更';

  @override
  String get chatCompareTitle => '核對安全碼';

  @override
  String chatCompareLine(Object peerName) {
    return '三個詞可以照抄。要確認這個聊天真的是和 $peerName，請當面或透過通話和對方核對安全碼。';
  }

  @override
  String get chatCompareLater => '稍後';

  @override
  String get chatCompareNow => '核對';

  @override
  String chatKeyHeldLine(Object peerName) {
    return '你之前驗證過 $peerName。在你核對新的安全碼或接受新金鑰之前，什麼都不會送出。對方的訊息仍會收到。';
  }

  @override
  String get chatCheckTheNumber => '核對安全碼';

  @override
  String get chatAcceptNewKey => '接受新金鑰';

  @override
  String get chatAcceptNewKeyTitle => '接受對方的新金鑰？';

  @override
  String chatAcceptNewKeyLine(Object peerName) {
    return '之後 Kryfo 會不經核對就傳送到新金鑰，$peerName 也不再標為已驗證。你隨時可以重新驗證。';
  }

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
  String get cleanNotEnoughRoomOnDesk => '電腦空間不足。';

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
  String get cleanPicturesOver64MbDesk => '超過 64 MB 的圖片不會在電腦上清理。沒有做任何變更。';

  @override
  String get cleanKryfoCouldNotRead => 'Kryfo 無法完整讀到結尾，所以不會說它已清理乾淨。沒有產生任何副本。';

  @override
  String get cleanSomethingInsideIsOf => '裡面有它不知道如何移除的內容，所以沒有產生副本。';

  @override
  String get cleanFreeSomeSpaceAnd => '請釋出一些空間後再試一次。沒有做任何變更。';

  @override
  String get cleanTheAppThatShared => '分享它的應用程式可能已經把它收回。請再分享一次。';

  @override
  String get cleanTheAppThatSharedDesk => '它可能已被移動，或被其他應用程式占用。請再選一次。';

  @override
  String get cleanNoAppOnThis => '這支手機上沒有任何應用程式接收這個檔案。';

  @override
  String get cleanCouldNotSaveIt => '無法儲存。請確認手機還有空間。';

  @override
  String get cleanCouldNotSaveItDesk => '無法儲存。請確認電腦還有空間。';

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
  String get cleanSaveToGalleryDesk => '儲存乾淨副本';

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
  String get cleanEverythingStaysOnThisDesk => '一切都留在這台電腦上。';

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
  String get cleanSamePicture => '同樣的圖片';

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
  String get cleanSavedToYourGalleryDesk => '已儲存到你選擇的位置。';

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
  String get contactStaysOnThisPhoneDesk => '只存在這台電腦上。對方永遠看不到。';

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
  String get contactMessagesAndContactGoneDesk => '訊息和聯絡人都會從這台電腦上消失';

  @override
  String get contactDeleteThisChat => '要刪除這個聊天嗎？';

  @override
  String get contactEveryMessageAndThe => '每則訊息和這位聯絡人都會從這支手機上消失。不會傳送任何東西給對方。';

  @override
  String get contactEveryMessageAndTheDesk =>
      '每則訊息和這位聯絡人都會從這台電腦上消失。不會傳送任何東西給對方。';

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
  String get donateBackItAnonymouslyBadge => '匿名支持。徽章自由選擇。\n*所有隱私功能都免費。*';

  @override
  String get donateAuditTitle => '幫忙資助一次安全稽核';

  @override
  String get donateAuditLine => '在這裡的捐款會用於一次獨立稽核。完整報告將會公開。';

  @override
  String get donateCard => '信用卡／金融卡';

  @override
  String get donateCardOneTime => '在瀏覽器中進行的一次性捐款，金額由你決定。';

  @override
  String get donateCardMarios => '在我們的財務託管方設立好之前，刷卡付款會直接轉給 Marios。';

  @override
  String get donateCardSeesName => '支付公司看得到你的姓名。加密貨幣才是私密的選擇。';

  @override
  String get donateCardPay => '刷卡付款';

  @override
  String get donateNoBitcoinCard => '沒有 Bitcoin？刷卡付款';

  @override
  String get donateCardNoBadge => '刷卡捐款不會解鎖徽章。';

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
  String get donateShowTheAddress => '顯示地址';

  @override
  String donateReviewAmount(String amount) {
    return '$amount，以 bitcoin 付款';
  }

  @override
  String get donateWhatTheBadgeGives => '徽章能給你什麼';

  @override
  String get donateGivesMark => '名字旁的一個標記。給誰看、給不給人看，都由你決定。';

  @override
  String get donateGivesReceipt => '一張保存在這支手機上的簽名收據。不需任何帳號就能證明徽章。';

  @override
  String get donateGivesReceiptDesk => '一張保存在這台電腦上的簽名收據。不需任何帳號就能證明徽章。';

  @override
  String get donateGivesFree => '無論有沒有徽章，所有隱私功能都一直免費。';

  @override
  String get donateAddressOnTap => '點下方按鈕時才會產生地址。它在一小時內都屬於你，回來時還是同一個。';

  @override
  String get donateBitcoinBusy => 'Bitcoin 現在很忙。請稍後再試，或刷卡付款。';

  @override
  String get donateBusyPlainAddress => '你仍然可以向下方地址傳送 bitcoin，但不會獲得徽章。';

  @override
  String get donateSameAddressAgain => '這是你之前開啟的地址。如果已經傳送，請在這裡等候。';

  @override
  String get donateReachingThePaymentService => '正在經由 Tor 連線到付款服務…';

  @override
  String get donateThisCanTakeUp => '可能需要一兩分鐘';

  @override
  String donateSThisCanTake(Object waited) {
    return '$waited 秒 · 可能需要一兩分鐘';
  }

  @override
  String get donateUseTheAddressInstead => '改用地址';

  @override
  String get donateThePaymentServiceIs =>
      '付款服務是 onion 服務，只有 Onion 模式才能連上。現在沒有傳送任何東西。';

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
  String get donateNoWallet => '這支手機上沒有能開啟 bitcoin 連結的 App。請改為複製地址。';

  @override
  String get donateChecking => '檢查中…';

  @override
  String get donateNotSeenYet => '還沒看到。付款可能要幾分鐘才會顯示。';

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
  String donateVerifiedBadgeStays(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter': '已在鏈上驗證。感謝你再次支持。你的支持者徽章維持不變。',
      'patron': '已在鏈上驗證。感謝你再次支持。你的贊助人徽章維持不變。',
      'guardian': '已在鏈上驗證。感謝你再次支持。你的守護者徽章維持不變。',
      'other': '已在鏈上驗證。感謝你再次支持。你的支持者徽章維持不變。',
    });
    return '$_temp0';
  }

  @override
  String get donateWearMyBadge => '佩戴我的徽章';

  @override
  String get donateJustGladToHelp => '能幫上忙就好';

  @override
  String get gettingMessagesAlwaysOn => '始終在線';

  @override
  String get gettingMessagesMostPrivate => '最私密';

  @override
  String get gettingMessagesMessagesArriveInstantlyNothing =>
      '最耗電。\n即時送達，任何東西都不會離開 Tor。';

  @override
  String get gettingMessagesArriveInstantlyFast => '最耗電。\n在快速模式下即時送達。';

  @override
  String get gettingMessagesCheckIns => '定時查收';

  @override
  String get gettingMessagesLightest => '最省電';

  @override
  String get gettingMessagesKryfoLooksForMessages =>
      'Kryfo 每 15 分鐘查收一次，所以訊息可能會晚到。\n省電。';

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
  String get groupChatYou => '你';

  @override
  String get groupChatVoiceMessage => '語音訊息';

  @override
  String get groupChatQuotedPhoto => '照片';

  @override
  String get groupChatMessageUnavailable => '訊息無法顯示';

  @override
  String get groupChatTorIsNotUp => 'Tor 尚未連上 · 不加入連結預覽';

  @override
  String get groupChatCouldnTReachIt => '無法連上該頁面 · 不加入連結預覽';

  @override
  String get groupChatNoTitleCameBack => '該頁面沒有標題 · 不加入連結預覽';

  @override
  String get groupChatCouldnTFetchIt => '無法載入預覽';

  @override
  String get groupChatCamera => '相機';

  @override
  String get groupChatGallery => '相簿';

  @override
  String get groupChatVideo => '影片';

  @override
  String get groupChatGifFromPhone => '手機裡的 GIF';

  @override
  String get groupChatGifFromPhoneDesk => '電腦裡的 GIF';

  @override
  String get groupChatFile => '檔案';

  @override
  String get groupChatCouldNotReadThat => '無法讀取那個檔案';

  @override
  String get groupChatGifTooBig8 => 'GIF 太大 · 上限 8 mb';

  @override
  String get groupChatCouldNotCleanThat => '無法清理那個 GIF';

  @override
  String get groupChatCouldNotCleanThatVideo => '無法清理那段影片';

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
  String get groupChatNewMessagesDisappearOnceRead =>
      '新訊息在被讀取後經過這段時間消失。你傳送的從傳送時開始計時。';

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
  String get groupChatItDisappearsWithNo => '訊息會從所有人的手機上刪除，除非已被儲存。這個動作無法復原。';

  @override
  String get groupChatItDisappearsWithNoDesk =>
      '訊息會從所有人的裝置上刪除，除非已被儲存。這個動作無法復原。';

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
  String get groupChatEveryoneHereReads => '這裡的每個人都能看到你寫的內容。';

  @override
  String get groupChatNobodyHereYet => '這裡還沒有人。';

  @override
  String get groupChatShareTheRoomLink => '分享聊天室連結。加入的人從那時起能看到寫下的內容。';

  @override
  String get groupChatNobodyToReadIt => '這裡沒有其他人能看到。';

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
  String get groupChatSupporter => '支持者';

  @override
  String get groupChatEdited => '已編輯';

  @override
  String get groupChatTapToRetry => '! 點一下重試';

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
      other: '已傳送 · $countString 人中 $haveString 人已收到',
      zero: '已傳送 · 正在送達',
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
      other: '已傳送 · $countString 人未收到',
    );
    return '$_temp0';
  }

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
  String get groupInfoResetLink => '重設連結';

  @override
  String get groupInfoResetTheRoomLink => '要重設聊天室連結嗎？';

  @override
  String get groupInfoResetLinkLine => '舊連結將失效。聊天室裡的人會留下，並收到新連結。';

  @override
  String get groupInfoRemoveRoomLine =>
      '對方仍可透過聊天室連結重新加入。重設連結即可把對方擋在外面。仍在聊天室裡的人會收到新連結。';

  @override
  String get groupInfoRemoveAndResetLink => '移除並重設連結';

  @override
  String get groupInfoCouldNotResetLink => '無法重設連結';

  @override
  String get roomLinkNewLinkTheOld => '新連結。舊連結已失效。';

  @override
  String appGroupHoldsUpTo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '一個群組最多 $countString 人',
    );
    return '$_temp0';
  }

  @override
  String get commonRemove => '移除';

  @override
  String get groupInfoClearThisConversation => '要清空這段對話嗎？';

  @override
  String get groupInfoEveryMessageHereIs =>
      '這裡的每則訊息都會從這支手機上抹除。這只會清空你的副本，其他成員的副本會保留。';

  @override
  String get groupInfoEveryMessageHereIsDesk =>
      '這裡的每則訊息都會從這台電腦上抹除。這只會清空你的副本，其他成員的副本會保留。';

  @override
  String get groupInfoClear => '清空';

  @override
  String get groupInfoConversationCleared => '對話已清空';

  @override
  String get groupInfoLeaveRoom => '要離開聊天室嗎？';

  @override
  String get groupInfoLeaveGroup => '要離開群組嗎？';

  @override
  String get groupInfoEverythingInItIs => '裡面的一切會立即從這支手機上抹除，你在這裡使用的金鑰也會永久消失。';

  @override
  String get groupInfoEverythingInItIsDesk =>
      '裡面的一切會立即從這台電腦上抹除，你在這裡使用的金鑰也會永久消失。';

  @override
  String groupChatYouWereRemovedFrom(Object name) {
    return '你已被移出 $name';
  }

  @override
  String get groupInfoLeaveGroupLine => '你將不再收到它的訊息，裡面的一切也會從這支手機上抹除。';

  @override
  String get groupInfoLeaveGroupLineDesk => '你將不再收到它的訊息，裡面的一切也會從這台電腦上抹除。';

  @override
  String get groupInfoLeaveGroupAdmin =>
      '你將不再收到它的訊息，裡面的一切也會從這支手機上抹除。你是管理員，離開後就沒有人能再增減成員或重新命名了。';

  @override
  String get groupInfoLeaveGroupAdminDesk =>
      '你將不再收到它的訊息，裡面的一切也會從這台電腦上抹除。你是管理員，離開後就沒有人能再增減成員或重新命名了。';

  @override
  String get groupInfoLeaveRoomMaker =>
      '裡面的一切會立即從這支手機上抹除，你在這裡使用的金鑰也會永久消失。這個聊天室是你建立的，你離開後它的連結就不能再讓人加入了。';

  @override
  String get groupInfoLeaveRoomMakerDesk =>
      '裡面的一切會立即從這台電腦上抹除，你在這裡使用的金鑰也會永久消失。這個聊天室是你建立的，你離開後它的連結就不能再讓人加入了。';

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
  String get handleHintName => 'name';

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
  String handleDeleteTitle(Object handle) {
    return '刪除 @$handle？';
  }

  @override
  String get handleDeleteLine => '你的公開頁面會消失，任何人都可以認領這個名稱。現有的聊天維持不變。';

  @override
  String get handleDeleteYes => '刪除使用者名稱';

  @override
  String get handleDeleting => '刪除中…';

  @override
  String get handleChecking => '檢查中…';

  @override
  String get handleAvailable => '✓ 可以使用';

  @override
  String get handleAlreadyTaken => '已被使用';

  @override
  String get handleNameRule => '3 到 20 個字元：a-z、0-9 或 _';

  @override
  String get handleWhatAHandleDoes => '使用者名稱的用途';

  @override
  String get handleAnyoneWhoKnowsIt =>
      '任何知道它的人都能要求傳訊息給你。這個頁面只存放你的邀請和你寫的那一句話，沒有其他東西，也不會記錄誰讀過它。你隨時都可以刪除它。';

  @override
  String handleIsNotYoursOn(Object handle) {
    return '在這支手機上，@$handle 不屬於你';
  }

  @override
  String handleIsNotYoursOnDesk(Object handle) {
    return '在這台電腦上，@$handle 不屬於你';
  }

  @override
  String handleTheRegistryHoldsIt(Object handle) {
    return '註冊處記錄它屬於另一把金鑰，很可能是這支手機還原之前的身分。新增 @$handle 的人聯絡不到你。它無法在這裡釋出或更新。請換一個名字。';
  }

  @override
  String handleTheRegistryHoldsItDesk(Object handle) {
    return '註冊處記錄它屬於另一把金鑰，很可能是這台電腦還原之前的身分。新增 @$handle 的人聯絡不到你。它無法在這裡釋出或更新。請換一個名字。';
  }

  @override
  String get handleForgetItOnThis => '在這支手機上忘記它';

  @override
  String get handleForgetItOnThisDesk => '在這台電腦上忘記它';

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
  String get homeKeepWaiting => '繼續等待';

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
  String get homeNoKryfosYet => '還沒有 Kryfo 聯絡人。';

  @override
  String get homeScanTheirCodeSend => '掃描對方的 QR 碼、傳連結給對方，或輸入對方給你的 @使用者名稱。';

  @override
  String get homeScanTheirCodeSendDesk => '傳連結給對方，或輸入對方給你的 @使用者名稱。';

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
  String get homeMessagesAndContactGoneDesk => '訊息和聯絡人都會從這台電腦上消失';

  @override
  String get homeDeleteThisChat => '要刪除這個聊天嗎？';

  @override
  String homeEveryMessageWithGoes(Object c) {
    return '和 $c 的每則訊息都會刪除，對方也不再是你的聯絡人。這只會清空這支手機，對方的副本仍留在對方那裡。如果對方再傳訊息，會出現在請求中。';
  }

  @override
  String homeEveryMessageWithGoesDesk(Object c) {
    return '和 $c 的每則訊息都會刪除，對方也不再是你的聯絡人。這只會清空這台電腦，對方的副本仍留在對方那裡。如果對方再傳訊息，會出現在請求中。';
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
  String get homeOnlyOnThisPhoneDesk => '只在這台電腦上';

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
  String introduceIntroduced(Object b, Object c) {
    return '$b 和 $c 現在都有對方的名片了';
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
  String get keyVerificationNewNumber => '此頁面開啟期間，安全碼變更了。這是新的安全碼，請再比對一次。';

  @override
  String get keyVerificationKeyMoved => '安全碼剛剛變更了，請比對新的安全碼。';

  @override
  String keyVerificationNoKeyYet(Object peerName) {
    return '還沒有 $peerName 的金鑰。對方傳訊息給你之後，安全碼就會顯示在這裡。';
  }

  @override
  String keyVerificationWith(Object peerName) {
    return '與 $peerName';
  }

  @override
  String keyVerificationCompareAll(Object peerName) {
    return '和 $peerName 核對全部 12 組數字，當面或透過你信任的通話。每一組都一致，就代表中間沒有別人，你們的訊息只屬於你們兩個人。';
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
  String get lockFileCheckCapitalsAndSpaces => '請檢查大小寫和空格。沒有人能重設它。';

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
  String get lockFileEverythingStaysOnThisDesk => '一切都留在這台電腦上。';

  @override
  String get lockFileCouldNotMakeOne => '無法產生。請自己輸入。';

  @override
  String get lockFileWriteItDownBefore => '鎖定檔案前，請先把密碼寫下來';

  @override
  String get lockFileNoAppOnThis => '這支手機上沒有任何應用程式接收這個檔案。';

  @override
  String get linkNoAppOpens => '這支手機上沒有可以開啟此連結的應用程式。';

  @override
  String get linkNoAppOpensDesk => '這台電腦上沒有可以開啟此連結的應用程式。';

  @override
  String get placeStubLocation => '位置';

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
  String get lockFileSaveToFilesDesk => '儲存檔案';

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
      '任何知道密碼的人都能開啟它，無論是在 Kryfo 裡，還是在任何裝有免費工具 age 的電腦上。忘了密碼，檔案就永遠拿不回來了。沒有人能重設它。';

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
  String get lockSetupTurningOn => '正在開啟…';

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
  String get modesFast => '快速';

  @override
  String get modesNotChanged => '模式沒有變更，請再試一次。';

  @override
  String get modesSwitching => '切換中…';

  @override
  String get modesSpeed => '速度';

  @override
  String get modesPrivacy => '與隱私';

  @override
  String get movedWipeThisPhone => '要從這支手機抹除 Kryfo 嗎？';

  @override
  String get movedWipeThisPhoneDesk => '要從這台電腦抹除 Kryfo 嗎？';

  @override
  String get movedEverythingKryfoHoldsHere =>
      'Kryfo 在這裡保存的一切都會消失：訊息、聯絡人、金鑰。另一台裝置會保有這一切。這個動作無法復原。';

  @override
  String get movedWipeIt => '抹除';

  @override
  String get movedNotMovingAfterAll => '最後決定不搬了？';

  @override
  String get movedOnlyDoThisIf =>
      '只有在備份從未匯入任何地方時才這麼做。如果已經匯入過，現在就有兩台裝置持有同一個身分，兩邊都會開始遺失新訊息。';

  @override
  String get movedIMStayingHere => '我要留在這裡';

  @override
  String get movedStayingHere => '留在這裡';

  @override
  String movedKryfoWillCloseNow(Object myId) {
    return 'Kryfo 現在會關閉。點一下圖示，以 $myId 重新開啟。';
  }

  @override
  String movedKryfoWillCloseNowDesk(Object myId) {
    return 'Kryfo 現在會關閉。再次啟動它，以 $myId 開啟。';
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
  String movedIsNowOnAnotherDesk(Object myId) {
    return '$myId 現在在另一台裝置上。這台電腦仍可顯示原本的內容，但不會再收到任何新東西，從這裡傳送的任何內容也不會送達任何人。';
  }

  @override
  String get movedKeepItToRead => '留著閱讀';

  @override
  String get movedWipeThisPhone2 => '從這支手機抹除 Kryfo';

  @override
  String get movedWipeThisPhone2Desk => '從這台電腦抹除 Kryfo';

  @override
  String get movedIMNotMoving => '我最後決定不搬了';

  @override
  String get myKryfoAHandleIs3 => '使用者名稱為 3 到 20 個字母、數字或 _';

  @override
  String get myKryfoInviteCopiedClearsIn => '已複製邀請 · 60 秒後清空';

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
  String get myKryfoPointYourPhonesAtDesk => '對方用手機掃描這個 QR 碼。不會經過任何伺服器。';

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
      '這個連結帶有你的三個詞、你的位址，以及開始聊天所需的金鑰。在你到設定中重設之前，它都有效。';

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
  String get newGroupNeedsContacts => '群組由你的聯絡人組成';

  @override
  String get newGroupAddSomeoneFirst => '請先新增聯絡人。聊天室不需要聯絡人：有連結的人都能加入。';

  @override
  String get notesDeleteThisNote => '要刪除這則筆記嗎？';

  @override
  String get notesHoldHint => '長按一則筆記即可複製或刪除。';

  @override
  String get notesMenu => '筆記選單';

  @override
  String get notesDeleteAll => '刪除全部筆記';

  @override
  String get notesDeleteAllTitle => '刪除全部筆記？';

  @override
  String get notesDeleteAllLine => '這支手機上的所有筆記都會被永久刪除。';

  @override
  String get notesDeleteAllLineDesk => '這台電腦上的所有筆記都會被永久刪除。';

  @override
  String get notesDeleteAllYes => '全部刪除';

  @override
  String get notesThisWeek => '本週';

  @override
  String get notesShowMore => '展開';

  @override
  String get notesShowLess => '收合';

  @override
  String get notesGoneFromThisPhone => '它會從這支手機上永久抹除。';

  @override
  String get notesGoneFromThisPhoneDesk => '它會從這台電腦上永久抹除。';

  @override
  String get notesNoteToSelf => '給自己的筆記';

  @override
  String get notesOnlyOnThisPhone => '只在這支手機上';

  @override
  String get notesOnlyOnThisPhoneDesk => '只在這台電腦上';

  @override
  String get notesAQuietPlace => '一個安靜的角落';

  @override
  String get notesJotAnythingDownIt => '隨手記下任何事。它只留在這支手機上，永遠不會離開。';

  @override
  String get notesJotAnythingDownItDesk => '隨手記下任何事。它只留在這台電腦上，永遠不會離開。';

  @override
  String get notesJotSomethingDown => '記點什麼…';

  @override
  String get notesExportNotes => '匯出筆記';

  @override
  String get notesExport => '匯出';

  @override
  String get notesExportWorking => '正在匯出…';

  @override
  String notesExportCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 則筆記，從最早的開始。',
    );
    return '$_temp0';
  }

  @override
  String get notesExportZip => '照片和語音會和它們一起放進一個 zip。';

  @override
  String get notesExportText => '純文字';

  @override
  String get notesExportTextLine => '在哪裡都能開啟的 .txt 檔案';

  @override
  String get notesExportMarkdown => 'Markdown';

  @override
  String get notesExportMarkdownLine => '帶標題的 .md 檔案，適合筆記 App';

  @override
  String get notesExportLock => '用密碼短語鎖定';

  @override
  String get notesExportLockLine => '在「工具」裡用「開啟鎖定的檔案」開啟，或在電腦上用 age 開啟';

  @override
  String get notesExportPlainTitle => '不用密碼短語匯出？';

  @override
  String get notesExportPlainLine => '任何拿到這個檔案的人都能讀到內容。';

  @override
  String get notesExportPlainYes => '不加密匯出';

  @override
  String get notesExportKeepLock => '保留密碼短語';

  @override
  String get notesExportNotSaved => '筆記沒有儲存。檔案還在。';

  @override
  String get notesExportGone => 'Kryfo 鎖定時，檔案已清除。再匯出一次即可產生新檔案。';

  @override
  String get notesExportHoldsInstaller => '這份匯出裡有一個應用程式安裝檔，所以不能分享。請改為儲存到手機上。';

  @override
  String get notesExportHoldsInstallerDesk =>
      '這份匯出裡有一個應用程式安裝檔，所以不能分享。請改為儲存到這台電腦上。';

  @override
  String get notesExportSaved => '筆記已儲存';

  @override
  String notesExportSavedIn(String place) {
    return '筆記已儲存到 $place';
  }

  @override
  String get notesExportSavedUnchecked => '筆記已儲存，但 Kryfo 無法檢查這份副本';

  @override
  String get notesExportFailed => '無法匯出筆記。什麼都沒有儲存。';

  @override
  String get notesExportTooLarge => '太大了，無法匯出。照片和語音加起來有 4 GB 以上。';

  @override
  String get notesExportSubject => 'Kryfo 筆記';

  @override
  String get onboardingPrivateByDefault => '預設就是私密';

  @override
  String get onboardingPrivateMessaging => '私密通訊，\n*沒有隱藏代價*。';

  @override
  String get onboardingYourNameIsThree => '*你的名字就是三個詞。*\n不用手機號碼，不用電子郵件，不用通訊錄。';

  @override
  String get onboardingNobodyGetsInUnless =>
      '*除非你允許，沒有人能進來。*\n沒有公開的 @名字，就沒有人能搜尋到你。\n陌生人只能敲門。';

  @override
  String get onboardingTheFirstConnectionTakes =>
      '*第一次連線需要一分鐘。*\nKryfo 會先建立私密路線。之後就快了。';

  @override
  String get onboardingBegin => '開始';

  @override
  String get onboardingHaveABackupRestore => '有備份嗎？還原 →';

  @override
  String get onboardingKryfoIsOpenSource => 'Kryfo 開放原始碼';

  @override
  String get onboardingYourKryfoId => '你的名字';

  @override
  String get onboardingGeneratedFromAKey => '由只存在這支手機上的金鑰產生。\n*沒有其他人有這組詞。*';

  @override
  String get onboardingGeneratedFromAKeyDesk => '由只存在這台電腦上的金鑰產生。\n*沒有其他人有這組詞。*';

  @override
  String get onboardingTryAnother => '換一個';

  @override
  String get onboardingUseThisName => '使用這個名字 →';

  @override
  String get onboardingThreeWords => '三個詞。*只屬於你。*';

  @override
  String get onboardingContinue => '繼續 →';

  @override
  String get onboardingKryfoBuildsAPrivateRouteBefore =>
      'Kryfo 在傳送任何東西之前，會先建立一條私密路線。你離線時，訊息會先等著，等你回來再送達。';

  @override
  String get onboardingYourIdentityLivesOn => '你的身分存在這支手機上。\n準備好時，可以從設定中備份。';

  @override
  String get onboardingYourIdentityLivesOnDesk =>
      '你的身分存在這台電腦上。\n準備好時，可以從設定中備份。';

  @override
  String get onboardingSilentAndAtThe => '無聲，放在通知欄最底下';

  @override
  String get onboardingItNeverBuzzesTurn => '它從不震動。\n把它關掉的話，訊息會等到你開啟 Kryfo。';

  @override
  String get onboardingGotIt => '知道了 →';

  @override
  String get onboardingEveryWayToAdd => '所有新增聯絡人的方式';

  @override
  String get onboardingShowYourCodeSend => '出示你的 QR 碼、分享連結，或輸入對方的 @名字。';

  @override
  String get onboardingScanTheirs => '掃描對方的';

  @override
  String get onboardingPointTheCameraAt => '用相機對準對方的 QR 碼';

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
  String get openLockedItOpensOnThisDesk => '它會在這台電腦上開啟。';

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
  String get pairCodeLooking => '尋找中…';

  @override
  String get pairCodeNothingThereYetTrying => '那裡還沒有東西 · 正在重試';

  @override
  String get pairCodeNothingAtThatCode => '這組碼沒有對應任何東西。它可能已經焚毀，或對方還沒分享。';

  @override
  String get pairCodeUnreached => '聯絡不上中繼。請稍後再試。';

  @override
  String get fastRoomsWaitForTor => '聊天室、配對碼和首次聯繫始終透過 Tor，快速模式下也一樣。Tor 一連上就能用。';

  @override
  String get pairCodeFailed => '沒有成功。請再試一次。';

  @override
  String get pairCodeAddThem => '新增對方';

  @override
  String get pairCodeKeyNumber => '金鑰號碼';

  @override
  String get pairCodeNotAdded => '未新增。請對方再產生一組新的碼。';

  @override
  String get pairCodeEightDigits => '八位數字';

  @override
  String get pairCodeTypeTheEightDigits => '輸入對方唸出的八位數字。';

  @override
  String get pairCodeOldCode => '這個碼來自較舊的 Kryfo。兩支手機都需要 Kryfo 0.6 或更新版本。';

  @override
  String get pairCodeOldCodeDesk => '這個碼來自較舊的 Kryfo。兩台裝置都需要 Kryfo 0.6 或更新版本。';

  @override
  String get pairCodeBothNeed06 => '兩支手機都需要 Kryfo 0.6 或更新版本。';

  @override
  String get pairCodeBothNeed06Desk => '兩台裝置都需要 Kryfo 0.6 或更新版本。';

  @override
  String get pairCodeWaitingForThem => '正在等待對方…';

  @override
  String get pairCodeStillWaiting => '還在等待。如果對方螢幕顯示輸入了錯誤的碼，請一起核對數字。';

  @override
  String get pairCodeUnanswered => '沒有收到回應。請和對方核對碼，然後重新輸入。';

  @override
  String get pairCodeTooManyTries => '這個碼已經試了三次。請對方重新產生一個。';

  @override
  String get pairCodeRanOut => '這個碼已過期。請對方重新產生一個。';

  @override
  String get pairCodeMatched => '碼已相符。要互相新增嗎？';

  @override
  String get pairCodeNotThem => '不是對方';

  @override
  String get pairCodePanelReadEightDigitsOut =>
      '大聲唸出八位數字，你們就能互相新增。不需要交換其他任何東西。';

  @override
  String get pairCodePanelOrMakeACode => '或產生一組配對碼唸給對方';

  @override
  String get pairCodePanelTheyOpenKryfoEight =>
      '對方開啟 Kryfo，點「新增」，選擇「配對碼」，再輸入這八位數字。下一個人請再產生一組新的。';

  @override
  String get pairCodePanelWrongTyped => '對方輸入了錯誤的碼。請再慢慢唸一遍。';

  @override
  String get pairCodePanelThreeWrong => '錯誤的碼已輸入三次，這個碼已停止使用。請產生一個新的。';

  @override
  String get pairCodePanelNotAdded => '未新增。對方準備好時再產生一組新的碼。';

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
  String get photoKnowsVideoCleaner => '影片清理';

  @override
  String get photoKnowsPhotoCleaner => '照片清理';

  @override
  String get photoKnowsRemoveAllOfIt => '全部移除';

  @override
  String get photoKnowsKeepItAsIt => '保持原樣';

  @override
  String get photoKnowsReadOnThisPhone => '在這支手機上讀取 · 影片沒有傳到任何地方';

  @override
  String get photoKnowsReadOnThisPhoneDesk => '在這台電腦上讀取 · 影片沒有傳到任何地方';

  @override
  String get photoKnowsReadOnThisPhoneThePhoto => '在這支手機上讀取 · 照片沒有傳到任何地方';

  @override
  String get photoKnowsReadOnThisPhoneThePhotoDesk => '在這台電腦上讀取 · 照片沒有傳到任何地方';

  @override
  String get photoKnowsReadingTheFile => '正在讀取檔案';

  @override
  String photoKnowsOf(Object prettySize, Object prettySize2) {
    return '$prettySize/$prettySize2';
  }

  @override
  String get photoKnowsEverythingStaysOnThis => '一切都留在這支手機上。';

  @override
  String get photoKnowsEverythingStaysOnThisDesk => '一切都留在這台電腦上。';

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
      'PIN 碼會被移除，抹除 PIN 和所有隱藏聊天也會一起移除。任何拿著你手機的人，都能以你的身分開啟 Kryfo。';

  @override
  String get pinsThePinGoesAndDesk =>
      'PIN 碼會被移除，抹除 PIN 和所有隱藏聊天也會一起移除。任何用你電腦的人，都能以你的身分開啟 Kryfo。';

  @override
  String get pinsUnlockWithFingerprint => '用指紋解鎖';

  @override
  String get pinsFingerOpensDecoy => '設定偽裝 PIN 後關閉：手指只會開啟偽裝。';

  @override
  String get pinsWipePin => '抹除 PIN';

  @override
  String get pinsNeedsAPinFirst => '需要先設定 PIN 碼';

  @override
  String get pinsSet => '已設定';

  @override
  String get pinsChangeWipePin => '變更抹除 PIN';

  @override
  String get pinsRemove => '移除';

  @override
  String get pinsRemoveTheWipePin => '要移除抹除 PIN 嗎？';

  @override
  String get pinsTheLockScreenKeeps => '鎖定畫面會保留你的 PIN 碼。抹除 PIN 將不再有任何作用。';

  @override
  String profileCopied(Object what) {
    return '$what已複製';
  }

  @override
  String get profileProfile => '個人檔案';

  @override
  String get profileKryfoId => '你的名字';

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
  String get qrMadeOnThisPhoneDesk => '在這台電腦上產生 · 沒有任何網站看過密碼';

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
  String get qrCouldNotSaveItDesk => '無法儲存。請確認電腦還有空間。';

  @override
  String get qrNoAppOnThis => '這支手機上沒有任何應用程式可以接收這張圖片。';

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
  String get requestsRequests => '請求';

  @override
  String get requestsNoRequests => '沒有請求';

  @override
  String get requestsMessagesFromPeopleYou => '你還沒新增的人傳來的訊息，會先出現在這裡。';

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
  String get restoreReplaceTheAccountOnDesk => '要取代這台電腦上的帳號嗎？';

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
  String restoreTheRegistryDidNotDesk(Object mine) {
    return '註冊處沒有回應。如果你繼續，@$mine 會一直指向這台電腦即將失去的身分。任何新增它的人，訊息都會傳給一個不存在的人，而且這個名稱無法再被認領。最好先連上網路，再試一次。';
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
  String restoreKryfoWillCloseNowDesk(Object haloId) {
    return 'Kryfo 現在會關閉。再次啟動它，以 $haloId 開啟。';
  }

  @override
  String get restorePrivacyKept => '你的隱私設定會隨備份一起回來。PIN 碼永遠不會隨之轉移：請在設定裡重新設定。';

  @override
  String get restoreCheckProtections => '備份不包含設定。Kryfo 重新開啟後，請在設定裡檢查「你的防護」。';

  @override
  String get restoreReopenKryfo => '重新開啟 Kryfo';

  @override
  String get restoreTheRestoreDidNot => '還原沒有完成。沒有做任何變更';

  @override
  String get restoreKryfoClosesRestoreAgain =>
      '這裡的部分資料已經被取代。Kryfo 現在會關閉。請重新開啟，再還原一次這個檔案。';

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
  String get restoreAnythingSentToYouDesk => '舊裝置關機時傳給你的任何內容（傳送後十四天內）。';

  @override
  String get restoreYourSupporterBadgeIf => '你的支持者徽章（如果有的話）。';

  @override
  String get restoreWhatDoesnT => '不會帶過來的';

  @override
  String get restoreTheOldPhoneStops =>
      '你一從這裡傳送任何東西，舊手機就會停止接收。你從這台裝置傳出的第一則訊息，就是舊手機最後能跟上的一則；之後送到舊手機的任何內容，在那裡都無法讀取，也不會在這裡等你。';

  @override
  String get restoreTheOldPhoneStopsDesk =>
      '你一從這裡傳送任何東西，舊裝置就會停止接收。你從這台電腦傳出的第一則訊息，就是舊裝置最後能跟上的一則；之後送到舊裝置的任何內容，在那裡都無法讀取，也不會在這裡等你。';

  @override
  String get restoreIfThePhoneThis =>
      '如果這個檔案原本所在的手機還在使用，請先在那支手機上停止使用 Kryfo，再繼續。兩支手機共用一個 Kryfo，兩邊都會遺失訊息。';

  @override
  String get restoreIfThePhoneThisDesk =>
      '如果這個檔案原本所在的裝置還在使用，請先在那台裝置上停止使用 Kryfo，再繼續。兩台裝置共用一個 Kryfo，兩邊都會遺失訊息。';

  @override
  String get restoreNotificationsNeedSettingUp => '需要在這台裝置上重新設定通知。';

  @override
  String get restoreDeletedComeBack =>
      '這份備份建立之後你刪除的聊天會隨它回來，那些聯絡人可能會看到你重新設定了 Kryfo。';

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
  String get restoreABackupBringsBackDesk =>
      '備份會找回你的身分和聯絡人，以及建立檔案時裝置上的訊息。之後說的任何話都不在裡面。';

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
  String get restoreStopRestore => '停止還原';

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
  String get roomCreateARoomThatEndsDesk =>
      '一個會結束的聊天室。每個人都用專為它產生的金鑰加入，結束時，任何裝置上都不會留下任何東西。';

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
  String roomCreateOffUpTo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '關閉。任何有連結的人都能加入，最多 $countString 人',
    );
    return '$_temp0';
  }

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
  String get savedChatGone => '那個聊天已不在這支手機上';

  @override
  String get savedChatGoneDesk => '那個聊天已不在這台電腦上';

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
      '這是按照傳送路線列出的清單，包括薄弱之處。點一列就能看到原因。';

  @override
  String get seenHonestAboutTheLast =>
      '最後幾列正是應用程式鎖、抹除 PIN 和加密儲存要應對的；如果有人拿著你已解鎖的手機，沒有任何工具救得了你。完整的威脅模型在程式碼庫的 THREAT_MODEL.md 裡，依據 LINDDUN 撰寫。程式碼是公開的，你可以自己查證這些。';

  @override
  String get seenHonestAboutTheLastDesk =>
      '最後幾列正是應用程式鎖、抹除 PIN 和加密儲存要應對的；如果有人坐在你已解鎖的電腦前，沒有任何工具救得了你。完整的威脅模型在程式碼庫的 THREAT_MODEL.md 裡，依據 LINDDUN 撰寫。程式碼是公開的，你可以自己查證這些。';

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
      '每段對話都有自己的位址，由雙方的金鑰推導而來。中繼看到的是一個個互不相關的投遞點，而不是一對人。在快速模式下，我們的伺服器能看到你所用投遞點上的 IP 位址；如果對話雙方都用快速模式，還能看到兩個 IP 位址共用一個投遞點。';

  @override
  String get seenWhatYouSay => '你說了什麼';

  @override
  String get seenEndToEndEncrypted =>
      '使用 Signal 雙棘輪演算法端對端加密，再以 gift wrap 包裝密封一次。我們讀不到。';

  @override
  String get seenYourIpAddress => '你的 IP 位址';

  @override
  String get seenYourContactGraph => '你的聯絡人關係圖';

  @override
  String get seenKryfoDoesNotScan =>
      'Kryfo 不會掃描你的通訊錄。這裡根本沒有手機號碼可以外洩。在快速模式下，我們的伺服器可以根據哪些 IP 位址共用投遞點拼湊出其中一部分，但不會留下任何記錄。';

  @override
  String get seenIntroducer => '介紹人';

  @override
  String get seenWhenAContactIntroduces =>
      '當聯絡人介紹你認識某人時，那位聯絡人會知道你們兩個現在有聯繫。其他人都不會知道。中繼看到的是密文，也沒有任何伺服器看得到關係圖。';

  @override
  String get seenTheScamShield => '防詐盾';

  @override
  String get seenScamShieldRequestsOnly =>
      '在你的手機上執行，使用應用程式內建的規則。不連網路，也不下載任何清單。它只會讀取陌生人的訊息請求，從不讀取聯絡人或群組傳給你的內容。';

  @override
  String get seenScamShieldRequestsOnlyDesk =>
      '在你的電腦上執行，使用應用程式內建的規則。不連網路，也不下載任何清單。它只會讀取陌生人的訊息請求，從不讀取聯絡人或群組傳給你的內容。';

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
      '預覽由傳送者經由 Tor 擷取，並包在加密訊息中傳送。接收的手機不會發出任何請求。網站只會知道有個使用 Tor 的人要求了一個頁面，除此之外一無所知。永遠不會載入任何圖片，陌生人傳來的連結也只會顯示為純文字。';

  @override
  String get seenAPreviewIsFetchedDesk =>
      '預覽由傳送者經由 Tor 擷取，並包在加密訊息中傳送。接收的裝置不會發出任何請求。網站只會知道有個使用 Tor 的人要求了一個頁面，除此之外一無所知。永遠不會載入任何圖片，陌生人傳來的連結也只會顯示為純文字。';

  @override
  String get seenASeizedUnlockedPhone => '被扣押的已解鎖手機';

  @override
  String get seenASeizedUnlockedPhoneDesk => '被扣押的已解鎖電腦';

  @override
  String get seenIfSomeoneHoldsYour =>
      '如果有人拿著你已解鎖的手機，他們就能讀你的訊息。應用程式鎖、抹除 PIN 和加密儲存能在那之前幫上忙，在那之後就不行了。';

  @override
  String get seenIfSomeoneHoldsYourDesk =>
      '如果有人坐在你已解鎖的電腦前，他們就能讀你的訊息。應用程式鎖、抹除 PIN 和加密儲存能在那之前幫上忙，在那之後就不行了。';

  @override
  String get seenTheCryptoItself => '加密技術本身';

  @override
  String get seenTheRatchetAndStorage =>
      '棘輪和儲存層都是標準做法。連接兩者的那一層是我們自己寫的，還沒有任何獨立的第三方審查過。這是 alpha 版本。';

  @override
  String get seenFast => '快速';

  @override
  String get settingsWipeKryfo => '要抹除 Kryfo 嗎？';

  @override
  String get settingsIdentityMessagesContactsAnd =>
      '這支手機上的身分、訊息、聯絡人和設定。除非你有備份，否則會永久消失。';

  @override
  String get settingsIdentityMessagesContactsAndDesk =>
      '這台電腦上的身分、訊息、聯絡人和設定。除非你有備份，否則會永久消失。';

  @override
  String get commonContinue => '繼續';

  @override
  String settingsTypeWipeToConfirm(Object word) {
    return '輸入「$word」以確認';
  }

  @override
  String get settingsTheLastStepNothing => '最後一步。什麼都不會留下。';

  @override
  String get settingsWipeWord => '抹除';

  @override
  String get settingsWipeKryfo2 => '抹除 Kryfo';

  @override
  String get settingsYourProtections => '你的防護';

  @override
  String get settingsTorRouting => 'Tor 路由';

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
  String get settingsOnion3Hops => 'Onion · 3 跳';

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
  String get settingsScamShieldHint => '只在你的手機上檢查，不會有任何東西離開手機';

  @override
  String get settingsScamShieldHintDesk => '只在你的電腦上檢查，不會有任何東西離開電腦';

  @override
  String get typingNow => '正在輸入';

  @override
  String get settingsTypingIndicator => '輸入狀態提示';

  @override
  String get settingsTypingIndicatorHint =>
      '對方在輸入時，你們雙方都看得到。提示經 Tor 直接傳給對方，從不經過中繼。';

  @override
  String get settingsTypingOnionOnly => '在 Onion 路線上可用';

  @override
  String get settingsTypingBridgesOff =>
      '使用橋接時關閉：監視你連線的人可能會對上輸入提示的訊號。關閉橋接後會自動恢復。';

  @override
  String get settingsLightTheme => '淺色主題';

  @override
  String get settingsSameProtectionBrighter => '同樣的防護，更明亮';

  @override
  String get settingsAppearance => '外觀';

  @override
  String get settingsAccentColour => '強調色';

  @override
  String get settingsColoursAndWallpaper => '顏色和桌布';

  @override
  String get settingsAppLock2 => '應用程式鎖';

  @override
  String get settingsYourPinAndA => '你的 PIN 碼和進階保護';

  @override
  String get settingsPinWipePin => 'PIN 碼 · 抹除 PIN';

  @override
  String get settingsBackUpIdentity => '備份身分';

  @override
  String get settingsEncryptedFile => '加密檔案';

  @override
  String get settingsRestoreFromBackup => '從備份還原';

  @override
  String get settingsReplaceCurrent => '取代目前的';

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
      '持有舊 QR 碼或連結的人，無論透過哪種路線，都將無法再聯絡你。拿到了但從沒用過的人，需要你再給一個新碼。聯絡人、聊天和紀錄都會保留。';

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
  String get settingsReportAnIssue => '回報問題';

  @override
  String get settingsReportInKryfo => '在 Kryfo 裡寫';

  @override
  String get settingsReportInKryfoSub => '和 Marios 的聊天。你可以匿名寫。';

  @override
  String get settingsReportByEmail => '傳送電子郵件';

  @override
  String get settingsReportByEmailSub => 'gnosiworks@proton.me，用你的郵件 App';

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
      '尚未經過獨立稽核。目前是 alpha 版：適合測試，還不適合高風險用途。';

  @override
  String get settingsFollowTitle => '追蹤 GnosiWorks（開發者）';

  @override
  String get settingsFollowBrowserNote => '在你的瀏覽器中開啟，離開 Kryfo。';

  @override
  String get settingsFollowOpen => '開啟';

  @override
  String settingsFollowOn(Object name) {
    return '在 $name 追蹤，離開 Kryfo';
  }

  @override
  String get settingsDangerZone => '危險區域';

  @override
  String get settingsWipeKryfoFromThis => '從這支手機抹除 Kryfo';

  @override
  String get settingsWipeKryfoFromThisDesk => '從這台電腦抹除 Kryfo';

  @override
  String get toolsMoreTools => '更多工具';

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
  String get toolsEverythingHereHappensOnDesk =>
      '這裡的一切都在這台電腦上進行。不會上傳任何東西，其他人也不必使用 Kryfo。';

  @override
  String get toolsPhotoCleaner => '照片清理';

  @override
  String get toolsRemovesHiddenInfo => '清除地點、時間和手機型號等隱藏資訊（中繼資料）';

  @override
  String get toolsPickAPhotoAnd =>
      '選一張照片或一段影片，看看它會洩露什麼，然後一鍵全部移除。也可以從相簿分享到 Kryfo。';

  @override
  String get toolsPickAPhotoAndDesk =>
      '選一張照片或一段影片，看看它會洩露什麼，然後一鍵全部移除。也可以拖到這裡或直接貼上。';

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
  String get transportNothingHereLeavesTheDesk =>
      '這裡的任何內容都不會離開電腦。這就是引擎用來決定下一步的同一份狀態。';

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
  String get transportWithNoContactsTheDesk =>
      '沒有聯絡人時，應用程式不會訂閱任何中繼位址，所以任何訊息都無法送達你。新增一個人就能解決。';

  @override
  String get transportSendAnythingWaitingNow => '立即傳送所有等待中的內容';

  @override
  String get transportSending => '傳送中…';

  @override
  String get transportNothingLeftWaiting => '沒有等待中的內容了';

  @override
  String transportStillWaiting(Object count) {
    return '仍在等待：$count';
  }

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
  String get transportStopKilled => '被系統強制結束';

  @override
  String get transportStopLowMemory => '記憶體不足';

  @override
  String get transportStopCrashed => '當機';

  @override
  String get transportStopNotResponding => '沒有回應';

  @override
  String get transportStopByYou => '由你停止';

  @override
  String get transportStopByPhone => '由手機停止';

  @override
  String get transportStopBySecurityApp => '由安全性應用程式停止';

  @override
  String get transportStopUpdated => '已更新';

  @override
  String get transportStopBySystem => '由系統停止';

  @override
  String get transportStopTooMuch => '佔用過多';

  @override
  String get transportStopPermission => '權限已變更';

  @override
  String get transportStopClosedItself => '自行關閉';

  @override
  String get transportStopOther => '已停止';

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
  String get transportReconnects => '重新連線';

  @override
  String get transportWhyNetwork => '網路變更';

  @override
  String get transportWhyHand => '手動';

  @override
  String get transportWhyRelays => '沒有中繼回應';

  @override
  String get transportWhyStall => '啟動卡住';

  @override
  String get transportWhyTorOff => 'Tor 已關閉';

  @override
  String get transportWhyDialer => '3 分鐘沒有中繼';

  @override
  String get transportWhyOnion => '回到 Onion';

  @override
  String get transportWhyBridges => '橋接變更';

  @override
  String get transportWhyAuto => '自動';

  @override
  String get transportWhyOffline => '沒有網路';

  @override
  String get transportWhyCircuits => '新線路';

  @override
  String get transportWhyOther => '其他';

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
  String get wallpaperDefault => '預設';

  @override
  String get wallpaperNotSet => '桌布沒有設定成功。請再試一次。';

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
  String get whyKryfoRoutedThroughTor => '經由 Tor 路由';

  @override
  String get whyKryfoByDefaultEveryMessage =>
      '預設情況下，每則訊息都經由 Tor（一連串的中繼）傳送。沒有人，不論是我們還是你的網路，能看到你在跟誰聊天，或你在哪裡。';

  @override
  String get whyKryfoEndToEndEncrypted => '端對端加密';

  @override
  String get whyKryfoMessagesAreSealedWith => '訊息用只有你和對方持有的金鑰密封。我們讀不到。';

  @override
  String get whyKryfoNoServersHoldingYour => '沒有伺服器掌握你的生活';

  @override
  String get whyKryfoNoAccountNoPhone =>
      '沒有帳號，沒有手機號碼，也沒有儲存你聊天內容的中央伺服器。聊天內容存在這支手機上，並以加密方式存放。';

  @override
  String get whyKryfoNoAccountNoPhoneDesk =>
      '沒有帳號，沒有手機號碼，也沒有儲存你聊天內容的中央伺服器。聊天內容存在這台電腦上，並以加密方式存放。';

  @override
  String get whyKryfoNothingLeaks => '什麼都不外洩';

  @override
  String get whyKryfoNoReceiptsTyping =>
      '沒有已讀回條，也不上傳聯絡人清單。你正在輸入，只有你在對話的那個人看得到，經 Tor 直接送達，從不經過伺服器。大多數應用程式都會外洩中繼資料，Kryfo 的設計就是不外洩。';

  @override
  String get whyKryfoVerifyItIsReally => '確認真的是對方';

  @override
  String get whyKryfoCompareASafetyNumber =>
      '當面或透過你信任的管道比對安全碼，就能確定沒有人在冒充你的聯絡人。';

  @override
  String get whyKryfoTheHonestPart => '老實說';

  @override
  String get whyKryfoKryfoIsPreAlpha =>
      'Kryfo 還在 alpha 階段，也還沒經過稽核。加密技術是真的，但還沒有外部專家檢查過，所以在攸關你人身安全的情況下，暫時不要依賴它。';

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
  String get cleanerHdrLayer => 'HDR 圖層';

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
  String get bootFailedKeysDidNotAnswer => '手機的金鑰儲存區沒有回應。關閉並重新開啟 Kryfo 通常可以解決。';

  @override
  String get bootFailedKeysDidNotAnswerDesk =>
      '這台電腦的金鑰儲存區沒有回應。關閉並重新開啟 Kryfo 通常可以解決。';

  @override
  String get bootFailedCloseAndReopen => '關閉並重新開啟 Kryfo';

  @override
  String get bootFailedStillStuck => '如果重試也沒用';

  @override
  String get bootFailedRestoreBackup => '從備份還原';

  @override
  String get bootFailedStartFresh => '重新開始';

  @override
  String get bootFailedStartFreshTitle => '要重新開始嗎？';

  @override
  String get bootFailedStartFreshLine =>
      '這會清除 Kryfo 在這支手機上的一切：聊天、聯絡人、媒體、隱藏的聊天和你的三個詞。存在別處的備份檔案不受影響。';

  @override
  String get bootFailedStartFreshLineDesk =>
      '這會清除 Kryfo 在這台電腦上的一切：聊天、聯絡人、媒體、隱藏的聊天和你的三個詞。存在別處的備份檔案不受影響。';

  @override
  String get bootFailedStartFreshNext => '繼續';

  @override
  String get bootFailedStartFreshSure => '清除這支手機上的一切？';

  @override
  String get bootFailedStartFreshSureDesk => '清除這台電腦上的一切？';

  @override
  String get bootFailedStartFreshSureLine => '此操作無法復原。Kryfo 會關閉，再次開啟時就像剛安裝。';

  @override
  String get bootFailedStartFreshYes => '清除並重新開始';

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
  String kryfoLinkTextYouAlreadyHave(Object who) {
    return '你已經有 $who 了';
  }

  @override
  String kryfoLinkTextSomeoneElse(Object who) {
    return '你聊天裡有一個人被你叫作 $who。這個連結來自另一個人。只有在你知道連結從哪裡來時，才新增。';
  }

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
  String get kryfoLinkTextYouJoinUnderA => '你會用專為這個聊天室產生的金鑰加入。裡面沒有人看得到你的三個詞。';

  @override
  String get linkStubFetchedOverTorBy => '經由 Tor 擷取 · 由你的裝置';

  @override
  String get linkStubFetchedOverTorByTheirDevice => '經由 Tor 擷取 · 由對方的裝置';

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
  String get mediaBubblesPlaying => '正在播放';

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
  String get motionReadyToChat => '可以聊天了';

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
  String get motionAddressFinishing => '訊息已可透過 Tor 傳送。你的私密位址正在背景完成設定。';

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
  String get pairCodePanelWorking => '處理中';

  @override
  String get pairCodePanelBurned => '這個碼已經焚毀。對方準備好時再產生一個新的。';

  @override
  String get pairCodePanelCodeCopied => '已複製配對碼';

  @override
  String pairCodePanelBurnsIn(Object mm, Object ss) {
    return '$mm:$ss 後焚毀';
  }

  @override
  String get pairCodePanelTheyTapAddChoose => '對方點「新增」，選擇「配對碼」，然後輸入這些數字。';

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
  String previewStripFetchedOverTor(Object domainOf) {
    return '$domainOf · 經由 Tor 擷取';
  }

  @override
  String get previewStripDropThePreview => '移除預覽';

  @override
  String get previewStripAddPreview => '加上預覽';

  @override
  String get previewStripFetchingOverTor => '正在經由 Tor 擷取…';

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
  String get torBootSplashMadeOnThisPhoneDesk => '在這台電腦上產生。不會傳送任何東西到任何地方。';

  @override
  String get torBootSplashFirstLaunchTakesA => '首次啟動需要一點時間 · 只在開啟時';

  @override
  String get torBootSplashTakingLonger => '這比平常久一些';

  @override
  String get torBootSplashHopEntry => '入口';

  @override
  String get torBootSplashHopMiddle => '中間';

  @override
  String get torBootSplashHopExit => '出口';

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
  String get profileIdentity => '身分';

  @override
  String get avatarPickerShape => '形狀';

  @override
  String get avatarPickerColour => '顏色';

  @override
  String get avatarPickerTurn => '旋轉';

  @override
  String avatarPickerOption(String what, int n, int count) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$what，第 $nString 個，共 $countString 個';
  }

  @override
  String get avatarPickerYourInitial => '你的名字首字';

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
  String get settingsProtectBackup => '備份';

  @override
  String get settingsBackupNotYet => '還沒有';

  @override
  String get settingsBackupToday => '今天';

  @override
  String get settingsBackupYesterday => '昨天';

  @override
  String settingsBackupDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 天前',
    );
    return '$_temp0';
  }

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
  String get bridgesFoundAVolunteer => '找到志願者，連線中';

  @override
  String get bridgesScanABridgeCode => '掃描橋接 QR 碼';

  @override
  String get settingsBridgesForNetworksThat => '橋接，適用於封鎖 Tor 的網路';

  @override
  String get bridgesCouldNotReachTheTor => '聯絡不上 Tor 專案';

  @override
  String get torBootSplashConnect => '連線';

  @override
  String get bridgesOffline => '離線';

  @override
  String get bridgesNothingGotThrough => '都沒能連上';

  @override
  String get bridgesBridgeFromAFriend => '朋友給的橋接';

  @override
  String get bridgesKryfoCanAskThe => 'Kryfo 可以向 Tor 專案索取橋接，繞過封鎖。';

  @override
  String get bridgesNotNeededRightNow => '現在用不到';

  @override
  String get bridgesBuiltInBridges => '內建橋接';

  @override
  String get bridgesKryfoCanGetAround => 'Kryfo 現在能夠繞過 Tor 封鎖了';

  @override
  String get bridgesThatSNotABridge => '這不是橋接設定';

  @override
  String get transportBridgeError => '上次錯誤';

  @override
  String get bridgesDirect => '直接連線';

  @override
  String get bridgesAskingTheTorProject => '正在詢問 Tor 專案這裡什麼方式可用…';

  @override
  String get bridgesNoneOfTheseAre => '這些都不是 Kryfo 看得懂的橋接設定。';

  @override
  String get bridgesAutomatic => '自動';

  @override
  String get bridgesStraightToTor => '直接連到 Tor，不需要橋接';

  @override
  String get bridgesKryfoConnectsAsSoon => '你一恢復連網，Kryfo 就會連線。';

  @override
  String get bridgesMore => '更多';

  @override
  String bridgesTryingAnotherWayOf(String attempt, String attempts) {
    return '正在嘗試其他方式…（$attempt/$attempts）';
  }

  @override
  String get bridgesLookingForAVolunteer => '正在尋找志願者';

  @override
  String get bridgesFastestWhereTorIsnt =>
      '在 Tor 沒被封鎖的地方最快。Kryfo 從不在 Tor 之外建立連線。';

  @override
  String get transportBridgePhase => '階段';

  @override
  String get bridgesAsleepBetweenCheckIns => '兩次查收之間休眠中';

  @override
  String get bridgesThroughABridge => '透過橋接';

  @override
  String get bridgesBuiltIn => '內建';

  @override
  String get bridgesPasteOrScanALineDesk => '貼上你信任的人給你的橋接設定。';

  @override
  String get bridgesDetails => '詳情';

  @override
  String get transportBridgeMode => '橋接';

  @override
  String get bridgesYourBridgeCouldNot => '橋接無法啟動';

  @override
  String get bridgesKryfoStaysOfflineRather => 'Kryfo 寧可保持離線，也不會在沒有橋接的情況下連線。';

  @override
  String get bridgesSignInToThisWifi => '登入這個 Wi-Fi';

  @override
  String get bridgesThisNetworkWantsA => '這個網路需要先登入。登入後，Kryfo 就會連線。';

  @override
  String get bridgesThisNetworkWantsADesk =>
      '這個網路需要先登入。請在瀏覽器裡登入，或檢查電腦的網路連線。登入後，Kryfo 就會連線。';

  @override
  String get bridgesWaitingForWifiSignIn => '等待 Wi-Fi 登入';

  @override
  String get bridgesOpenWifiSettings => '開啟 Wi-Fi 設定';

  @override
  String get bridgesUsingBuiltIn => '正在使用內建橋接';

  @override
  String get bridgesUsingSnowflake => '正在使用 Snowflake';

  @override
  String get bridgesUsingTorProject => '正在使用 Tor 專案的橋接';

  @override
  String get bridgesBridgeRemoved => '已移除橋接';

  @override
  String get bridgesUndo => '復原';

  @override
  String bridgesRemoveBridgeN(String n) {
    return '移除橋接 $n';
  }

  @override
  String get bridgesTurnOnAutomatic => '開啟自動';

  @override
  String get bridgesPasteABridgeLine => '貼上橋接設定';

  @override
  String get bridgesInUse => '使用中';

  @override
  String get bridgesPasteTheLineThey => '貼上對方傳給你的設定，或掃描它的 QR 碼。橋接設定請向你認識的人拿。';

  @override
  String get bridgesYouReOnAMode => '你目前的模式不使用 Tor。切換回去後，這些選擇才會生效。';

  @override
  String get bridgesPasteOrScanALine => '貼上或掃描你信任的人給你的橋接設定。';

  @override
  String get bridgesNothingYet => '還沒有';

  @override
  String get torBootSplashIfTorIsBlocked =>
      '如果你那裡 Tor 被封鎖或監控，Kryfo 可以改為透過橋接啟動。';

  @override
  String get bridgesScanACode => '掃描 QR 碼';

  @override
  String get bridgesSwitchToAutomatic => '改用自動';

  @override
  String get torBootSplashTorIsBlockedHere => '這裡 Tor 被封鎖或監控';

  @override
  String get torBootSplashStartThroughABridge => '透過橋接啟動';

  @override
  String get torBootSplashNeverTriesTorPlainly =>
      '在這裡，Kryfo 絕不會直接連線 Tor。它會自己找到可用的橋接，你也可以在下一步選擇自己的橋接。';

  @override
  String get bridgesTryingAnotherWay => '正在嘗試其他方式…';

  @override
  String get bridgesFindingAWayIn => '正在尋找連線方式…';

  @override
  String get bridgesGoesThroughAVolunteer => '經由志願者的電腦連線。很難封鎖，但啟動較慢。';

  @override
  String get bridgesTorSeemsBlocked => '這個網路似乎封鎖了 Tor';

  @override
  String get bridgesTorIsBlockedOnThis => '這個網路封鎖了 Tor';

  @override
  String bridgesKryfoCouldNotRead(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Kryfo 無法讀取其中 $countString 行設定',
    );
    return '$_temp0';
  }

  @override
  String get bridgesTorNoBridge => 'Tor，無橋接';

  @override
  String get bridgesKryfoFindsAWay => 'Kryfo 會找出在你那裡行得通的方式。';

  @override
  String get bridgesThisBridgeIsnTGetting => '這個橋接連不出去';

  @override
  String get bridgesBridgesTheTorProject => 'Tor 專案之前給你的橋接。';

  @override
  String get bridgesConnectingDots => '連線中…';

  @override
  String get bridgesNotNow => '以後再說';

  @override
  String get bridgesObfs4BridgesThatCome => 'Kryfo 內建的橋接（obfs4）。試起來快，但常被封鎖。';

  @override
  String get bridgesYourNetworkMayBe => '你的網路可能受到限制';

  @override
  String get bridgesCheckingForMessages => '正在查收訊息…';

  @override
  String get bridgesSavedLines => '已儲存的設定';

  @override
  String get bridgesPasteTheLineTheyDesk => '貼上對方傳給你的設定。橋接設定請向你認識的人拿。';

  @override
  String get bridgesFromAFriendLower => '來自朋友';

  @override
  String get bridgesAlmostThere => '快好了';

  @override
  String get bridgesUseThisBridge => '使用這個橋接';

  @override
  String bridgesUseTheseBridges(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '使用這 $countString 個橋接',
    );
    return '$_temp0';
  }

  @override
  String get transportBridgeMethod => '方式';

  @override
  String get bridgesPointAtTheBridge => '對準橋接的 QR 碼';

  @override
  String get bridgesConnectingThroughYourBridge => '正在透過你的橋接連線…';

  @override
  String get bridgesThisLineIsTooLong => '這行設定太長，Tor 無法使用。';

  @override
  String get bridgesAutomaticFindsAWay =>
      'Tor 被封鎖時，「自動」會自己找到辦法。如果你同意，Kryfo 可能會向 Tor 專案詢問橋接。';

  @override
  String get bridgesFromTheTorProjectLower => '來自 Tor 專案';

  @override
  String get bridgesBridgesGoDeadWithout => '橋接可能會無預警失效。「自動」能找到別的辦法。';

  @override
  String get bridgesWhenTorIsBlockedAutomatic =>
      'Tor 被封鎖時，「自動」會詢問 Tor 專案，在你所在的國家或地區什麼方式可用。';

  @override
  String get bridgesPlainAdvice =>
      'Kryfo 會自動選擇橋接。Snowflake 和 WebTunnel 在大多數地方都能用。如果一個連不上，就換一個試試，或者向朋友要一條橋接設定。';

  @override
  String get bridgesAskTorProject => '詢問 Tor 專案';

  @override
  String get bridgesTooLongForTor => '太長，Tor 無法使用';

  @override
  String bridgesMethodFrom(String method, String from) {
    return '$method，$from';
  }

  @override
  String get bridgesKryfoCanTUseThis => 'Kryfo 無法使用這行設定';

  @override
  String get bridgesTryAutomatic => '試試自動';

  @override
  String get bridgesNoInternet => '沒有網路';

  @override
  String get bridgesConnection => '連線';

  @override
  String get bridgesGetABridge => '取得橋接';

  @override
  String get languageTitle => '語言';

  @override
  String get languageMatchPhone => '跟隨手機';

  @override
  String get languageMatchPhoneDesk => '跟隨系統';

  @override
  String languageMatchPhoneValue(Object language) {
    return '跟隨手機（$language）';
  }

  @override
  String languageMatchPhoneValueDesk(Object language) {
    return '跟隨系統（$language）';
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
      '讓 Kryfo 保持連線，在它關閉時也能收到加密訊息。關閉這項設定會停止接收訊息。';

  @override
  String get videoViewerPlay => '播放';

  @override
  String get videoViewerPause => '暫停';

  @override
  String get videoViewerPlayAgain => '重新播放';

  @override
  String get videoViewerCannotPlay => '這支手機無法在這裡播放這部影片。';

  @override
  String get videoViewerCannotPlayDesk => '這台電腦無法在這裡播放這部影片。';

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
  String get languageNameHi => '印地語';

  @override
  String get languageNamePl => '波蘭文';

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
  String get searchIntroLineDesk => '名字、詞語、照片、檔案和連結。搜尋只在這台電腦上進行，不會把任何東西傳到別處。';

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
  String get handleRegistryFailed => '聯絡不上註冊處。\n請一分鐘後再試。';

  @override
  String get handleStillReaching => '仍在聯絡註冊處。\n透過 Tor 可能需要一點時間。';

  @override
  String get handleSearchNeedsTor => '以使用者名稱搜尋需要 Tor。在此之前，可以用 QR 碼或連結新增。';

  @override
  String get handleCheckClock => '請檢查手機的日期和時間，然後再試一次。';

  @override
  String get handleCheckClockDesk => '請檢查電腦的日期和時間，然後再試一次。';

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
  String get lockFingerAfterPin => '輸入一次 PIN 碼，即可再次使用指紋。';

  @override
  String get lockFingerLockedOut =>
      '指紋嘗試次數過多。請使用 PIN 碼，或先用手機本身的螢幕鎖定解鎖一次，指紋即可恢復。';

  @override
  String get lockFingerRefused => '手機未能為 Kryfo 保留指紋解鎖，因此已關閉。PIN 碼仍然可用。';

  @override
  String get lockFingerTryAgain => '手機剛才正忙。請再試一次指紋，或使用 PIN 碼。';

  @override
  String get pinsFingerRefused => '手機未允許為 Kryfo 開啟指紋解鎖。PIN 碼仍然可用。';

  @override
  String get pinsAdvanced => '進階保護';

  @override
  String get pinsAdvancedLine => '用於有人強迫你解鎖手機時。';

  @override
  String get pinsAdvancedLineDesk => '用於有人強迫你解鎖電腦時。';

  @override
  String get pinsWipeLine => '在鎖定畫面輸入它，會從這支手機上抹除 Kryfo。';

  @override
  String get pinsWipeLineDesk => '在鎖定畫面輸入它，會從這台電腦上抹除 Kryfo。';

  @override
  String get pinsDecoyPin => '偽裝 PIN';

  @override
  String get pinsDecoyLine => '開啟一個空的 Kryfo，就像剛安裝好一樣。';

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
  String get pinsTurnOffWithDecoyDesk =>
      '所有 PIN 都會被移除，偽裝 PIN 和它的 Kryfo 以及所有隱藏聊天也一樣。任何用你電腦的人，都能以你的身分開啟 Kryfo。';

  @override
  String get pinsHowThisWorks => '運作方式';

  @override
  String get flowEnterYourPin => '輸入你的 PIN 碼';

  @override
  String get flowEnterYourPinLine => '就是開啟 Kryfo 的那一組。';

  @override
  String get flowWipeTitle => '抹除 PIN';

  @override
  String get flowWipe1 =>
      '在鎖定畫面代替你的 PIN 碼輸入，它會從這支手機上抹除 Kryfo 並關閉應用程式。在旁人看來，應用程式只是停止了。';

  @override
  String get flowWipe1Desk =>
      '在鎖定畫面代替你的 PIN 碼輸入，它會從這台電腦上抹除 Kryfo 並關閉應用程式。在旁人看來，應用程式只是停止了。';

  @override
  String get flowWipe2 => '所有聊天和你的身分都會一起抹除，有偽裝的話也一樣。';

  @override
  String get flowWipeChoose => '選擇一組抹除 PIN';

  @override
  String get flowWipeDone => '已設定抹除 PIN';

  @override
  String get flowWipeDoneLine => '鎖定畫面上沒有任何跡象顯示它的存在。';

  @override
  String get flowDecoyTitle => '偽裝 PIN';

  @override
  String get flowDecoy1 => '開啟一個空的 Kryfo，就像剛安裝好一樣。';

  @override
  String get flowDecoyFinger =>
      '設定偽裝 PIN 後，這個應用程式只能用 PIN 碼開啟。如果在偽裝裡開啟了指紋，手指只會開啟偽裝，絕不會開啟這個應用程式。';

  @override
  String get flowDecoyDigits => '位數要跟你的 PIN 碼一樣，因為旁邊看著的人數得出圓點。';

  @override
  String get flowDecoyShade => '已經在通知欄裡的通知被看到了。但偽裝開啟期間，不會出現新的通知。';

  @override
  String get flowDecoyShadeDesk => '已經在螢幕上的通知被看到了。但偽裝開啟期間，不會出現新的通知。';

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
  String get flowLawDesk => '在有些國家，拒絕解鎖裝置或向官方隱藏資料本身就是違法的。出門前先了解當地的法律。';

  @override
  String get howWipe =>
      '在鎖定畫面輸入抹除 PIN，會抹除所有聊天、你的身分和任何偽裝，然後關閉 Kryfo。即使多次輸錯後鍵盤暫停，它也照樣有效。';

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
  String get flowVault2 => '藏起來的時候，它們從不發通知，也不顯示徽章。它們的訊息照樣送達，封存起來，等你輸入隱藏聊天 PIN。';

  @override
  String get flowVaultFinger => '你的指紋開啟的 Kryfo 裡沒有隱藏聊天。';

  @override
  String get flowVaultDigits => '你的 PIN 碼也最好用六位數或更多，因為旁邊看著的人數得出圓點。';

  @override
  String get flowVaultReplace => '這會取代這支手機上已有的任何隱藏聊天。';

  @override
  String get flowVaultReplaceDesk => '這會取代這台電腦上已有的任何隱藏聊天。';

  @override
  String get flowVaultChoose => '選擇一組隱藏聊天 PIN';

  @override
  String get flowVaultChooseLine => '六位數或更多。';

  @override
  String get flowEnterHiddenPinLine => '就是開啟隱藏聊天的那一組。';

  @override
  String get flowVaultForgetTitle => '記住這組 PIN';

  @override
  String get flowVaultForget => '如果你忘了這組 PIN，你的隱藏聊天就永遠沒了。誰也找不回來。';

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
  String get howVaultDesk =>
      '隱藏聊天 PIN 開啟的 Kryfo 帶著隱藏聊天，你的 PIN 碼開啟的則沒有。重新設定隱藏聊天，會取代這台電腦上已有的。忘了隱藏聊天 PIN，它們就永遠沒了。';

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
  String get timedMessageLabel => '限時訊息';

  @override
  String get stickerNewer => '來自較新版的 Kryfo';

  @override
  String get devLinkMismatch => '這個連結自稱是 Marios，但它的金鑰不相符，所以沒有新增。';

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
      'Marios 的金鑰內建在 Kryfo 裡。他傳來的每則訊息都會用它核對，所以別人無法冒充他傳訊息。';

  @override
  String get devKeyLabel => '他的金鑰';

  @override
  String get devDeleteLine => '每則訊息都會刪除，這個聊天也不會再回來。';

  @override
  String get devDeleteLineAnon => '每則訊息和為這個聊天產生的名字都會刪除，這個聊天也不會再回來。';

  @override
  String get devDeleteLineBack =>
      '每則訊息都會刪除，這個聊天也不會再回來。你傳出的訊息也會從 Marios 的手機上收回。';

  @override
  String get devDeleteLineAnonBack =>
      '每則訊息和為這個聊天產生的名字都會刪除，這個聊天也不會再回來。你傳出的訊息也會從 Marios 的手機上收回。';

  @override
  String devDeleteNotTakenBack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '有 $count 則訊息沒能從 Marios 的手機上收回',
    );
    return '$_temp0';
  }

  @override
  String get devDeleteFailed => '無法刪除這個聊天。請再試一次。';

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
  String get devWriteAnonymously => '匿名傳送';

  @override
  String get devUseMyWords => '用我的三個詞';

  @override
  String get devWhoSeesWhat => '運作方式';

  @override
  String get devWhoWords => '用你的三個詞，這就是一個普通的聊天：Marios 可以回覆你，你的頭像和支持者徽章留在你這裡。';

  @override
  String get devWhoAnon => '匿名傳送時，Kryfo 會專門為這個聊天產生新的名字和金鑰。它們只留在這支手機上，絕不會在別處使用。';

  @override
  String get devWhoAnonDesk =>
      '匿名傳送時，Kryfo 會專門為這個聊天產生新的名字和金鑰。它們只留在這台電腦上，絕不會在別處使用。';

  @override
  String get devWhoNothingYet => '在你傳出第一則訊息之前，什麼都不會離開你的手機。';

  @override
  String get devWhoNothingYetDesk => '在你傳出第一則訊息之前，什麼都不會離開你的電腦。';

  @override
  String get devWhoChoiceStays => '你的選擇會一直跟著這個聊天。';

  @override
  String get devUpdateToWrite => '更新 Kryfo 後即可傳訊息給 Marios。';

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
  String get devNamelessLine => '為這個聊天產生的名字只留在產生它的手機上，所以這裡只能閱讀。';

  @override
  String get devNamelessLineDesk => '為這個聊天產生的名字只留在產生它的裝置上，所以這裡只能閱讀。';

  @override
  String get devStartNewLine => '這裡的每則訊息都會刪除，並開啟一個新的聊天。';

  @override
  String get devVoiceDisguised => '在這個聊天裡，你的語音會變聲';

  @override
  String get devChatOptions => '聊天選項';

  @override
  String get requestsSomeoneNew => '陌生人';

  @override
  String get nameTakenTitle => '有別人在用這三個詞';

  @override
  String get nameTakenLine =>
      '這裡有人透過請求、介紹或群組得到了這三個詞，金鑰不同，也沒人核對過。詞是可以照抄的。如果這個連結來自你認識的人，就用它，然後和對方核對安全碼。';

  @override
  String get nameTakenChatLine =>
      '你用這三個詞的聊天來自請求、介紹或群組，金鑰不同，也沒人核對過。詞是可以照抄的。如果這個連結來自你認識的人，就用它：那個聊天會被刪除，你再在新的聊天裡核對安全碼。不確定連結從哪來？就保留現有的。';

  @override
  String get nameTakenDeletedLine =>
      '你刪除過一個用這三個詞的聊天，它用的是另一把金鑰。如果這個連結來自你認識的人，就用它，然後和對方核對安全碼。';

  @override
  String get nameTakenTombLine =>
      '你曾因為對方不是本人，從這支手機上移除了用這三個詞的人。如果這個連結來自你認識的人，就使用這個連結，然後和對方核對安全碼。';

  @override
  String get nameTakenTombLineDesk =>
      '你曾因為對方不是本人，從這台電腦上移除了用這三個詞的人。如果這個連結來自你認識的人，就使用這個連結，然後和對方核對安全碼。';

  @override
  String get nameTakenUse => '使用這個連結';

  @override
  String get nameTakenKeep => '保留現有的';

  @override
  String get appYourOwnInvite => '這是你自己的邀請。分享給別人才能互相連線。';

  @override
  String appLinkNeedsUpdate(Object id) {
    return '$id 需要先更新 Kryfo，你們才能互相新增。';
  }

  @override
  String appLinkWordsTaken(Object id) {
    return '這裡已經有人叫 $id，金鑰不同。和對方核對安全碼，就知道誰是誰。未新增。';
  }

  @override
  String appLinkWordsVerified(Object id) {
    return '你已用另一組金鑰驗證過 $id。未新增。';
  }

  @override
  String appTheyAreBlocked(Object id) {
    return '你已封鎖 $id。請在設定的「已封鎖」中解除封鎖後再新增。';
  }

  @override
  String get notThemNumbersDiffer => '號碼不一致';

  @override
  String get notThemLine => '如果號碼確實不一致，可能有人在冒用對方的名字，或者夾在你們中間。';

  @override
  String get notThemButton => '這不是對方本人';

  @override
  String get notThemSheetTitle => '要刪除這位聯絡人並封鎖其金鑰嗎？';

  @override
  String get notThemSheetLine =>
      '聊天及其中的訊息和檔案都會從這支手機上消失。只有你自己新增的連結或碼才能再用這三個詞。請和你新增的人核對安全碼。';

  @override
  String get notThemSheetLineDesk =>
      '聊天及其中的訊息和檔案都會從這台電腦上消失。只有你自己新增的連結或碼才能再用這三個詞。請和你新增的人核對安全碼。';

  @override
  String get notThemRemove => '刪除並封鎖';

  @override
  String get notThemDone => '已刪除，並已封鎖其金鑰';

  @override
  String get groupAdminGoneLine => '這個群組的管理員已從這支手機上移除。群組的變更不會再送達給你。';

  @override
  String get groupAdminGoneLineDesk => '這個群組的管理員已從這台電腦上移除。群組的變更不會再送達給你。';

  @override
  String get blockedKey => '已封鎖的金鑰';

  @override
  String get appKeyBlocked => '你已封鎖這個金鑰。請在設定的「已封鎖」中解除封鎖後再新增。';

  @override
  String get devLinkGone => '你已刪除與 Marios 的聊天。要開始新的聊天，請在設定中點按「傳訊息給 Marios」。';

  @override
  String lockTooManyTriesFor(Object left) {
    return '嘗試次數過多 · $left';
  }

  @override
  String get gifBadge => 'GIF';

  @override
  String get gifPlay => '播放 GIF';

  @override
  String get gifSentInside => '隨訊息一起傳送';

  @override
  String get gifOptInTitle => '私密地搜尋 GIF';

  @override
  String get gifOptInLead => 'GIF 搜尋需要連網，所以在你需要之前都會關閉。';

  @override
  String get gifOptInOverTor => '透過 Tor 搜尋';

  @override
  String get gifOptInThroughKryfo => '透過 Kryfo 搜尋';

  @override
  String get gifOptInAsksForYou =>
      'Kryfo 的伺服器替你向 GIF 服務查詢。該服務永遠看不到你，伺服器也不會記錄你搜尋了什麼。';

  @override
  String get gifOptInAsksForYouFast =>
      'Kryfo 的伺服器替你向 GIF 服務查詢，所以該服務永遠看不到你。在快速模式下，我們的伺服器在你搜尋時能看到你的 IP 位址，但不會記錄它，也不會記錄你搜尋了什麼。';

  @override
  String get gifOptInLikeAPhoto => 'GIF 像照片一樣加密傳送。對方的手機不會下載任何東西。';

  @override
  String get gifOptInOffWhenever => '隨時可以關閉';

  @override
  String get gifOptInWhereToTurnOff => '設定、隱私、GIF 搜尋。手機裡的 GIF 不開它也一直能用。';

  @override
  String get gifOptInWhereToTurnOffDesk => '設定、隱私、GIF 搜尋。電腦裡的 GIF 不開它也一直能用。';

  @override
  String get gifTurnOn => '開啟 GIF 搜尋';

  @override
  String get gifNotNow => '暫時不要';

  @override
  String gifAskOverTor(String brand) {
    return 'GIF 搜尋經由 Tor 透過 Kryfo 的伺服器進行，$brand 永遠看不到你。要開啟嗎？';
  }

  @override
  String gifAskThroughKryfo(String brand) {
    return 'GIF 搜尋直接送到 Kryfo 的伺服器，在快速模式下它能看到你的 IP 位址。$brand 永遠看不到你。要開啟嗎？';
  }

  @override
  String get gifAskTurnOn => '開啟';

  @override
  String get gifSearchOff => 'GIF 搜尋已關閉';

  @override
  String get gifSavedOnPhone => '手機上儲存的 GIF 在*這支手機上*分頁裡。';

  @override
  String get gifSavedOnPhoneDesk => '電腦上儲存的 GIF 在*這台電腦上*分頁裡。';

  @override
  String get gifTab => 'GIF';

  @override
  String get gifPhoneTab => '這支手機上';

  @override
  String get gifPhoneTabDesk => '這台電腦上';

  @override
  String get gifSearchHint => '搜尋 GIF';

  @override
  String get gifClear => '清除搜尋';

  @override
  String get gifServiceNeverSeesYou => 'GIF 服務永遠看不到你';

  @override
  String get gifTrending => '熱門';

  @override
  String get gifOffline => 'Tor 還在連線。連上後 GIF 就會出現。';

  @override
  String get gifBusy => '現在搜尋太多了，請稍後再試。';

  @override
  String get gifUnreachable => '聯絡不上 Kryfo 的 GIF 服務。';

  @override
  String get gifNothingFound => '找不到 GIF。換個詞試試。';

  @override
  String get gifCouldNotLoadMore => '無法載入更多';

  @override
  String get gifLoading => '正在載入 GIF';

  @override
  String get gifCouldNotGet => '無法取得這個 GIF，請再試一次。';

  @override
  String gifPoweredBy(String brand) {
    return 'Powered by $brand';
  }

  @override
  String gifNeverSeesYou(String brand) {
    return '透過 Kryfo 搜尋，$brand 永遠看不到你。';
  }

  @override
  String gifTileA11y(String number) {
    return 'GIF $number';
  }

  @override
  String get gifPhoneLine => '儲存在這支手機上的 GIF。不會連網。';

  @override
  String get gifPhoneLineDesk => '儲存在這台電腦上的 GIF。不會連網。';

  @override
  String get gifPhoneChoose => '選擇 GIF';

  @override
  String get settingsGifSearch => 'GIF 搜尋';

  @override
  String get settingsGifSearchHint =>
      '在你開啟前都會關閉。Kryfo 的伺服器替你搜尋，所以 GIF 服務永遠看不到你。';

  @override
  String get shareChooseChat => '選擇聊天';

  @override
  String get shareNoChats => '還沒有聊天';

  @override
  String get shareNoOne => '沒有可以分享的人';

  @override
  String get valveStillConnecting => '仍在連線…連線恢復後，你的訊息會立刻送出。';

  @override
  String get valveCouldNotReconnect => 'Kryfo 無法重新連線。重新啟動就能解決，你的訊息會保留。';

  @override
  String get valveRestartKryfo => '重新啟動 Kryfo';

  @override
  String get updateAvailable => '有可用的更新';

  @override
  String updateReady(String version) {
    return 'Kryfo $version 已可下載';
  }

  @override
  String get settingsCheckForUpdates => '檢查更新';

  @override
  String get settingsCheckForUpdatesHint =>
      '每天一次，透過 Tor。只向 kryfo.app 詢問最新版本，不傳送任何關於你的資訊。';

  @override
  String get voiceDisguiseHere => '在這裡給我的語音變聲';

  @override
  String get chatBlockScreenshots => '禁止截圖';

  @override
  String get chatShotsWhenTheyUpdate => '對方在手機上使用最新版 Kryfo 後即可使用';

  @override
  String get chatShotsWhenTheyUpdateDesk => '可在 Android 版 Kryfo 中使用';

  @override
  String get chatShotsBothPhones =>
      'Kryfo 在兩支手機上禁止截圖和錄製此聊天，也禁止複製、轉傳或儲存彼此的訊息。它擋不住獲准讀取螢幕的應用程式，或經過改動來繞過它的手機和應用程式。';

  @override
  String get chatShotsBlocksBoth =>
      '在兩支手機上禁止截圖和螢幕錄影，也禁止複製、轉傳或儲存彼此的訊息。它擋不住獲准讀取螢幕的應用程式，或經過改動來繞過它的手機和應用程式。';

  @override
  String get chatShotsBlockedHere => 'Kryfo 已在此聊天中禁止截圖';

  @override
  String get chatShotsMenuNote => '此聊天中不能複製、轉傳或儲存對方的訊息';

  @override
  String get chatShotsKeptOpen => '此聊天中不能用其他應用程式開啟對方的檔案';

  @override
  String searchKeptMatches(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 則結果 · 打開聊天查看',
    );
    return '$_temp0';
  }

  @override
  String get savedKeptInChat => '儲存自禁止截圖的聊天 · 打開聊天查看';

  @override
  String get roomShotsMenuNote => '此聊天室中不能複製、轉傳或儲存別人的訊息';

  @override
  String get roomShotsKeptOpen => '此聊天室中不能用其他應用程式開啟別人的檔案';

  @override
  String get chatShotsYouTurnedOn => '你開啟了禁止截圖。複製、轉傳和儲存彼此的訊息也已關閉。';

  @override
  String get chatShotsYouTurnedOff => '你關閉了禁止截圖';

  @override
  String get chatNowPostQuantum => '此聊天中的訊息現已使用後量子加密';

  @override
  String chatShotsTheyTurnedOn(String name) {
    return '$name 開啟了禁止截圖。複製、轉傳和儲存彼此的訊息也已關閉。';
  }

  @override
  String chatShotsTheyTurnedOff(String name) {
    return '$name 關閉了禁止截圖';
  }

  @override
  String get roomShotsBlocked =>
      'Kryfo 在這個聊天室的每支手機上禁止截圖和螢幕錄影，也禁止複製、轉傳或儲存別人的訊息。它擋不住獲准讀取螢幕的應用程式，或經過改動來繞過它的手機和應用程式。';

  @override
  String get roomShotsBlockedDesk =>
      '此聊天室中不能複製、轉傳或儲存彼此的訊息。Android 版 Kryfo 還會禁止截圖和螢幕錄影。';

  @override
  String get roomShotsAlwaysOn => '聊天室裡一律開啟，每支手機都一樣';

  @override
  String get roomShotsAlwaysOnDesk => '聊天室裡一律開啟，在 Android 版 Kryfo 中';

  @override
  String get homeShotsPerChat => '禁止截圖現在依聊天設定。';

  @override
  String get homeShotsTurnOnForAll => '要在你的所有聊天中開啟嗎？';

  @override
  String get homeShotsTurnOn => '全部開啟';

  @override
  String get homeShotsLeaveOff => '維持關閉';

  @override
  String get homeShotsTheySeeIt =>
      'Kryfo 也會在對方手機上禁止截圖，並關閉複製、轉傳和儲存彼此的訊息。對方會看到是你開啟的。';

  @override
  String homeShotsTurnedOn(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Kryfo 現已在 $countString 個聊天中禁止截圖',
    );
    return '$_temp0';
  }

  @override
  String get voiceDisguisedHere => '在這個聊天裡，你的語音會變聲';

  @override
  String get voiceSlideUpToLock => '上滑以鎖定';

  @override
  String get voiceStopRecording => '停止錄音';

  @override
  String get voiceDeleteNote => '刪除語音訊息';

  @override
  String get voiceDisguised => '已變聲';

  @override
  String get voiceYourVoice => '原聲';

  @override
  String get voiceDisguiseThisNote => '給這則語音變聲';

  @override
  String get voiceNotDisguised => '這則語音無法變聲，所以沒有送出';

  @override
  String get voiceNoRoom => '手機可用空間不足。請清出一些空間後再試。';

  @override
  String get voiceNoRoomDesk => '電腦可用空間不足。請清出一些空間後再試。';

  @override
  String get voiceNoRoomNotSent => '空間不足，無法為這則語音變聲，所以沒有送出';

  @override
  String get voiceDisguising => '正在變聲';

  @override
  String get voiceLockedNotSent => 'Kryfo 在語音訊息送出前已鎖定，所以沒有送出';

  @override
  String get voiceNotSent => '你的語音訊息沒有送出';

  @override
  String get settingsDisguiseByDefault => '預設給我的語音變聲';

  @override
  String get settingsDisguiseByDefaultHint => '每個聊天都可以在自己的選單裡更改';

  @override
  String get fileInstallerLine => '這是一個應用程式安裝檔。只安裝來自你信任的人的應用程式。';

  @override
  String get fileAppInstaller => '應用程式安裝檔';

  @override
  String get fileSaveToDevice => '儲存到裝置';

  @override
  String get fileOpenHint => '在其他應用程式中開啟';

  @override
  String get fileSaved => '已儲存';

  @override
  String fileSavedIn(String place) {
    return '已儲存到 $place';
  }

  @override
  String get fileSavedUnchecked => '已儲存，但 Kryfo 無法檢查這份副本';

  @override
  String get fileNotSaved => '無法儲存檔案';

  @override
  String get fileNotSavedNoSpace => '未儲存：那裡空間不足';

  @override
  String fileTooBig(String size, String max) {
    return '這個檔案有 $size。檔案最大為 $max。';
  }

  @override
  String get fileGoesAsItIs =>
      '這個檔案會原樣送出。Kryfo 只清理 JPEG、PNG、WebP、HEIC、AVIF、GIF、MP4 和 MOV。';

  @override
  String get voiceStoppedAtLimit => '語音訊息最長 30 分鐘，已自動停止。聽一遍後再傳送。';

  @override
  String get gettingMessagesHelperBody =>
      '它的伺服器能看到你的 IP 位址和訊息送達的時間。\n但從不知道內容。即時且省電。';

  @override
  String get gettingMessagesHelperUseOnion => '改用 Onion';

  @override
  String get gettingMessagesHelperSetUp => '設定';

  @override
  String get gettingMessagesHelperNote =>
      '其中混有假的喚醒，讓輔助應用程式的伺服器更難分辨真訊息何時送達。自架的輔助伺服器會讓我們的中繼知道它的位址。隱藏聊天、前幾個之後的房間，以及偶爾（大約五個月中有一個月）某位一般聯絡人，要等 Kryfo 每 15 分鐘一次的定時查收。';

  @override
  String get gettingMessagesHelperOnionOnly => '需要私密路線';

  @override
  String get gettingMessagesHelperChecking => '檢查中…';

  @override
  String get gettingMessagesHelperRelayNotYet => '我們的中繼暫不支援';

  @override
  String get helperSheetNeedTitle => '你需要一個輔助應用程式';

  @override
  String get helperSheetNeedLine =>
      '輔助應用程式為你所有的應用程式保持一條輕量連線，有東西送達時喚醒 Kryfo。任何 UnifiedPush 輔助應用程式都可以，ntfy 是不錯的起點。';

  @override
  String get helperSheetGetNtfy => '取得 ntfy';

  @override
  String get helperSheetOtherApps => '其他輔助應用程式';

  @override
  String get helperSheetPickTitle => '選擇輔助應用程式';

  @override
  String get helperSheetPickLine => 'Kryfo 只請它喚醒應用程式。你的訊息從不經過它。';

  @override
  String helperSheetSetUp(Object name) {
    return '$name 已設定完成';
  }

  @override
  String helperSheetNoAnswer(Object name) {
    return '$name 沒有回應。請再試一次。';
  }

  @override
  String get homeHelperGoneTitle => '你的輔助應用程式不見了';

  @override
  String get homeHelperGoneLine => '在你選擇其他方式之前，Kryfo 每 15 分鐘查收一次。';

  @override
  String get homeHelperGoneChoose => '選擇其他方式';

  @override
  String get homeHelperRelayTitle => '中繼不再喚醒 Kryfo';

  @override
  String get gettingMessagesHelperRefused =>
      '我們的中繼暫時不接受這支手機的部分登記。這些聊天會隨每 15 分鐘一次的定時查收送達，Kryfo 會繼續嘗試。換一個輔助應用程式或伺服器也可能有幫助。';

  @override
  String albumLabel(Object count) {
    return '相簿，$count 項';
  }

  @override
  String albumCounter(Object at, Object total) {
    return '$at/$total';
  }

  @override
  String albumMore(Object count) {
    return '還有 $count 項';
  }

  @override
  String get albumOnItsWay => '傳送中';

  @override
  String get albumQuoted => '相簿';

  @override
  String get albumUnsendTitle => '收回這個相簿？';

  @override
  String get mediaSendAddMore => '新增更多';

  @override
  String get mediaSendRemove => '移除';

  @override
  String get mediaSendProtect => '防止截圖';

  @override
  String get mediaSendProtectedOn => '已保護 · 已阻止截圖';

  @override
  String mediaSendUpTo(Object count) {
    return '一次最多 $count 個';
  }

  @override
  String get mediaSendVideo => '傳送影片';

  @override
  String get requestSenderMediaLater => '對方接受你之後，照片和檔案才會開放，讓你們都更安全。';

  @override
  String get requestReceiverMediaLater => '你接受對方之後，照片和檔案才會開放，讓你更安全。';

  @override
  String get groupEndedYou => '你結束了這個群組';

  @override
  String groupEndedBy(Object name) {
    return '$name 結束了這個群組';
  }

  @override
  String get groupEndedBar => '這個群組已結束';

  @override
  String get groupInfoEndGroup => '結束群組';

  @override
  String get groupInfoEndThisGroup => '要為所有人結束這個群組嗎？';

  @override
  String get groupInfoEndGroupLine => '將為所有人刪除：訊息和媒體會從每位已更新成員的手機上移除。';

  @override
  String get groupInfoEndGroupLineDesk => '將為所有人刪除：訊息和媒體會從每位已更新成員的裝置上移除。';

  @override
  String get groupInfoDeleteGroup => '刪除群組';

  @override
  String get groupInfoDeleteThisGroup => '要刪除這個群組嗎？';

  @override
  String get groupInfoDeleteGroupLine => '這個已結束的群組會從你的聊天列表中移除。';

  @override
  String get groupEndedOldNotice => '我結束了這個群組，之後誰都不能再在裡面傳訊息。更新 Kryfo 就能看到它已結束。';

  @override
  String get groupInfoEndGroupDetail => 'Kryfo 會從每位已更新的成員手機上移除它。';

  @override
  String get groupInfoEndGroupDetailDesk => 'Kryfo 會從每位已更新的成員裝置上移除它。';

  @override
  String get translateAction => '翻譯';

  @override
  String get translateShowOriginal => '顯示原文';

  @override
  String translateBarTo(Object language) {
    return '翻譯成$language';
  }

  @override
  String get translateBarMore => '翻譯選項';

  @override
  String translateBarNever(Object language) {
    return '不再為$language提供翻譯';
  }

  @override
  String get translateBarHide => '在此聊天中隱藏';

  @override
  String get translateWorking => '正在翻譯…';

  @override
  String get translateFailed => '無法翻譯';

  @override
  String translateFrom(Object language) {
    return '譯自$language';
  }

  @override
  String get translateLangZh => '中文';

  @override
  String translatePackTitle(Object language) {
    return '在這支手機上翻譯$language';
  }

  @override
  String translatePackTitleDesk(Object language) {
    return '在這台電腦上翻譯$language';
  }

  @override
  String translatePackLine(Object language, Object size) {
    return '訊息在這支手機上翻譯，從不離開手機。這需要$language語言包，約 $size，透過 Tor 下載一次。';
  }

  @override
  String translatePackLineDesk(Object language, Object size) {
    return '訊息在這台電腦上翻譯，從不離開電腦。這需要$language語言包，約 $size，透過 Tor 下載一次。';
  }

  @override
  String get translatePackNoLib => '翻譯在這支手機上無法使用。';

  @override
  String get translatePackNoLibDesk => '翻譯在這台電腦上無法使用。';

  @override
  String translateDownload(Object size) {
    return '下載 · 約 $size';
  }

  @override
  String get translateDownloadAnyway => '仍然立即下載';

  @override
  String get translateResume => '繼續下載';

  @override
  String translateProgress(Object done, Object total) {
    return '$done / $total';
  }

  @override
  String get translateFinishing => '正在檢查檔案…';

  @override
  String translateInstalled(Object size) {
    return '已在這支手機上 · $size';
  }

  @override
  String translateInstalledDesk(Object size) {
    return '已在這台電腦上 · $size';
  }

  @override
  String get translateNeedsWifi => '「僅限 Wi-Fi」已開啟，而這支手機沒有連上 Wi-Fi。';

  @override
  String get translateNeedsWifiDesk => '「僅限 Wi-Fi」已開啟，而這台電腦沒有連上 Wi-Fi。';

  @override
  String get translateFailNoTor => 'Tor 還沒有連線。語言包只透過 Tor 下載，請在連線後再試一次。';

  @override
  String get translateFailNetwork => '下載已中斷。再試一次會從中斷處繼續。';

  @override
  String get translateFailBadFile => '有一個檔案與 Kryfo 預期的不符，已被丟棄。請再試一次。';

  @override
  String get translateFailNoEngine => '這支手機無法下載語言包。';

  @override
  String get translateFailNoEngineDesk => '這台電腦無法下載語言包。';

  @override
  String translatePaused(Object size) {
    return '已暫停 · 已下載 $size';
  }

  @override
  String get translateSettingsTitle => '翻譯';

  @override
  String get translateSettingsRow => '翻譯訊息';

  @override
  String get translateSettingsHint => '在這支手機上，從不經過伺服器';

  @override
  String get translateSettingsHintDesk => '在這台電腦上，從不經過伺服器';

  @override
  String get translatePacksSection => '語言包';

  @override
  String translatePackPair(Object language) {
    return '$language和英文';
  }

  @override
  String translateNotDownloaded(Object size) {
    return '未下載 · 約 $size';
  }

  @override
  String get translateDownloading => '正在透過 Tor 下載';

  @override
  String translateDeleteTitle(Object language) {
    return '刪除$language語言包？';
  }

  @override
  String translateDeleteLine(Object language) {
    return '在重新下載之前，$language訊息將無法翻譯。';
  }

  @override
  String get translateLanguagesSection => '語言';

  @override
  String get translateMyLanguages => '我能讀的語言';

  @override
  String get translateMyLanguagesHint => '這些語言的訊息不會提示翻譯。應用程式的語言一律包含在內。';

  @override
  String get translateInto => '翻譯成';

  @override
  String get translateAppLanguage => '應用程式的語言';

  @override
  String get translateBehaviourSection => '下載與聊天';

  @override
  String get translateAutoDefault => '自動翻譯聊天';

  @override
  String get translateAutoDefaultHint => '適用於你沒有個別設定的聊天。每個聊天都可以開啟或關閉。';

  @override
  String get translateWifiOnly => '僅在 Wi-Fi 下下載語言包';

  @override
  String get translatePrivacyTitle => '哪些內容保持私密';

  @override
  String get translatePrivacyNote =>
      '翻譯在這支手機上完成。任何訊息都不會被傳送到別處翻譯。下載語言包會讓伺服器知道是哪個語言包。下載經由 Tor，所以伺服器不知道是誰要求的。';

  @override
  String get translatePrivacyNoteDesk =>
      '翻譯在這台電腦上完成。任何訊息都不會被傳送到別處翻譯。下載語言包會讓伺服器知道是哪個語言包。下載經由 Tor，所以伺服器不知道是誰要求的。';

  @override
  String get translateAutoInChat => '自動翻譯';

  @override
  String get translateAutoInChatHint => '其他語言的訊息會顯示譯文。點一下即可查看原文。';

  @override
  String get translateAlwaysChat => '總是翻譯此聊天';

  @override
  String translateNeverDone(Object language) {
    return '$language訊息保持原樣';
  }

  @override
  String get translateUndo => '復原';

  @override
  String get translateNeverSection => '不提供翻譯的語言';

  @override
  String get translateOfferAgain => '重新提供';

  @override
  String get translateOnHint => '在其他語言的訊息下方提供';

  @override
  String get translatePrivacyKept => '譯文與所屬聊天一起加密保存在這支手機上，並隨聊天一起刪除。';

  @override
  String get translatePrivacyKeptDesk => '譯文與所屬聊天一起加密保存在這台電腦上，並隨聊天一起刪除。';

  @override
  String get translateOffDeletes => '關閉後會刪除已儲存的譯文。';

  @override
  String get bridgesNoneUntilOnion => '開啟 Onion 前不使用';

  @override
  String get bridgesRelayThisNetworkSees =>
      '在 Tor 被封鎖的地方快速模式也能連通，但這個網路能看到你在連線 Kryfo。';

  @override
  String get settingsLicences => '授權條款';

  @override
  String get settingsLicencesValue => 'Kryfo 由什麼構成';

  @override
  String get licencesKryfoLine =>
      'Kryfo 是自由軟體，採用 GNU 通用公共授權條款第 3 版或更新版本。任何人都可以閱讀、修改和分享它的程式碼。';

  @override
  String get licencesSourceCode => '原始碼';

  @override
  String get licencesSignalTitle => 'Signal 協定';

  @override
  String licencesSignalLine(String version) {
    return 'Kryfo 包含 Signal 開發的 libsignal $version，採用 GNU Affero 通用公共授權條款第 3 版。它的原始碼位於 github.com/signalapp/libsignal，每個 Kryfo 版本旁也附有一份。';
  }

  @override
  String get licencesAgplText => 'GNU AGPL 3.0 全文';

  @override
  String get licencesSignalSource => 'libsignal 原始碼';

  @override
  String get licencesParts => '開源元件';

  @override
  String get licencesInSignal => 'Signal 函式庫中';

  @override
  String get licencesInApp => '應用程式中';

  @override
  String licencesPartCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 個元件',
    );
    return '$_temp0';
  }

  @override
  String get licencesGplText => 'GNU GPL 3.0 全文';

  @override
  String get licencesInEngine => '網路引擎中';

  @override
  String get licencesLoadFailed => '無法載入';

  @override
  String get licencesInVoice => '語音轉文字中';

  @override
  String get licencesInTranslation => '訊息翻譯中';

  @override
  String get settingsCopyLinkHint => '複製連結';

  @override
  String get motionNoRelayYet => '尚無中繼';

  @override
  String get motionTheRouteIsUp => '路線已建好';

  @override
  String get motionMessagesGoOnceARelay => '一旦有中繼透過這條路線回應，訊息就會送出。';

  @override
  String get motionOffline => '離線';

  @override
  String get motionNoNetwork => '沒有網路';

  @override
  String get motionTorPicksUpAgain => '沒有網路時什麼都送不出去。網路恢復後，Tor 會繼續。';

  @override
  String deliveryModeStateLast(String state, Object last) {
    return '$state · $last';
  }

  @override
  String homeWaitingState(int count, String state) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 則等待中 · $state',
    );
    return '$_temp0';
  }

  @override
  String get settingsIconAndNotifications => '圖示和通知';

  @override
  String iconSettingsValue(String icon) {
    return '$icon，簡潔通知';
  }

  @override
  String get iconSectionTitle => '應用程式圖示';

  @override
  String get iconHint => '主畫面和應用程式清單會顯示這個圖示和名稱，而不是 Kryfo。';

  @override
  String get iconHintKryfo => '為主畫面和應用程式清單選一個普通的圖示和名稱。';

  @override
  String get iconWhatChanges => '這會改變什麼';

  @override
  String iconConfirmTitle(String name) {
    return '要把圖示換成$name嗎？';
  }

  @override
  String iconConfirmLine(String name) {
    return 'Kryfo 會關閉再重新開啟。如果圖示從主畫面上不見了，請在應用程式中找到$name，再把它放回去。';
  }

  @override
  String get iconConfirmButton => '更換圖示';

  @override
  String get iconNoPinLine => '點它的人會看到 Kryfo。設定應用程式 PIN 碼後，他們只會看到 PIN 碼鍵盤。';

  @override
  String get iconSetPin => '設定 PIN 碼';

  @override
  String iconChanged(String name) {
    return '圖示已換成$name';
  }

  @override
  String iconPreviewLabel(String name) {
    return '主畫面將顯示$name';
  }

  @override
  String iconButtonLabel(String name) {
    return '$name，應用程式圖示';
  }

  @override
  String get notifShowAll => '名字和訊息';

  @override
  String get notifShowNew => '只顯示「新訊息」';

  @override
  String get notifShowPlain => '簡潔';

  @override
  String get notifPlainHint => '沒有名字，沒有訊息，沒有 Kryfo 的顏色。一個中性的圖示和一行字。';

  @override
  String get notifPlainLine => '有新內容';

  @override
  String get notifPlainChannel => '提醒';

  @override
  String get notifHeaderLimit => '每則通知的頂端仍會顯示 Kryfo。Android 不允許應用程式更改這一點。';

  @override
  String get gettingMessagesWhatShows => '通知顯示什麼';

  @override
  String get iconSheetChangesTitle => '會改變的';

  @override
  String get iconSheetChanges =>
      '主畫面和應用程式清單裡的圖示和名稱、分享選單和最近使用的應用程式畫面。選擇簡潔時，還有通知顯示的內容。';

  @override
  String get iconSheetStaysTitle => '仍是 Kryfo 的';

  @override
  String get iconSheetStays => '每則通知的第一行、手機的設定和電池頁面、應用程式商店，以及有人開啟時的 Kryfo 本身。';

  @override
  String get iconSheetGlance => '它經得起別人瞥一眼你的主畫面。但如果有人翻看手機的設定，它藏不住 Kryfo。';

  @override
  String get iconSheetPrivateSpace => '你的手機可能有自己的隱藏應用程式方式：設定裡的私人空間。';

  @override
  String get iconSheetSecureFolder => '你的手機可能有自己的隱藏應用程式方式：設定裡的安全資料夾。';

  @override
  String get iconSheetXiaomi => '你的手機可能有自己的隱藏應用程式方式：設定裡的隱藏應用程式。';

  @override
  String get androidIconNotes => '筆記';

  @override
  String get androidIconWeather => '天氣';

  @override
  String get androidIconTasks => '待辦';

  @override
  String get androidIconNews => '新聞';

  @override
  String get androidServiceTitlePlain => '執行中';

  @override
  String get lockStateUnlockPlain => '解鎖';

  @override
  String get iconSheetOthers =>
      '手機上的其他應用程式仍能看到已安裝 Kryfo，Android 本身的對話框和提示也可能顯示它的名稱。';

  @override
  String get iconSheetSaves =>
      '使用簡潔圖示時，新的照片、影片和檔案會以普通的名稱存進手機常用的資料夾。之前儲存的內容留在原處。';

  @override
  String get deliveryModeGooglePush => 'Google 推播';

  @override
  String get deliveryModeGoogle => 'Google';

  @override
  String get notificationsLead => '新訊息如何送達這支手機、提示音如何、顯示什麼。你可以隨時更改。';

  @override
  String get notificationsLeadDesk => '新訊息如何送達這台電腦、提示音如何、顯示什麼。你可以隨時更改。';

  @override
  String get notificationsHowTheyReachYou => '訊息如何送達';

  @override
  String get notificationsRecommended => '推薦';

  @override
  String get notificationsGoogleBody =>
      'Google 能看到你的手機何時被喚醒。\n但從不知道是誰寫的或說了什麼。\n即時且省電。';

  @override
  String get notificationsGoogleStarting => '正在開啟…';

  @override
  String get notificationsGoogleNoStart => 'Google 推播沒能啟動。請檢查網路後再試一次。';

  @override
  String get notificationsGoogleNote =>
      '其中混有假的喚醒，讓 Google 更難分辨真訊息何時送達。我們的中繼只保存它無法彼此關聯的位址。推播服務執行在我們的第二台伺服器上。兩台伺服器合起來能夠把它們關聯起來，借助 Google 還能關聯到你的 Google 帳號。只查扣其中一台做不到，但兩台都由我們營運，所以我們能做到。如果你在意這一點，請選擇其他方式。隱藏聊天、前幾個之後的房間，以及偶爾（大約五個月中有一個月）某位一般聯絡人，要等 Kryfo 每 15 分鐘一次的定時查收。';

  @override
  String get notificationsGoogleRefused =>
      '我們的中繼暫時不接受這支手機的部分登記。這些聊天會隨每 15 分鐘一次的定時查收送達，Kryfo 會繼續嘗試。';

  @override
  String get notificationsSoundAndVibration => '聲音和震動';

  @override
  String get notificationsSoundHint => '在 Android 自己的設定中';

  @override
  String get notificationsEachShows => '每則通知顯示';

  @override
  String get notificationsBatteryTips => '省電提示';

  @override
  String get notificationsBatteryAllowed => '已允許';

  @override
  String get notificationsBatteryNotYet => '未允許';

  @override
  String get notificationsMakerSwitch => '手機廠商的開關';

  @override
  String get onboardingHowYourMessages => '你的訊息如何*傳遞*。';

  @override
  String get onboardingRouteLead => '你隨時可以在設定中變更。';

  @override
  String get onboardingRoutePrivateCost => '透過 Tor。一則訊息需要幾秒鐘。';

  @override
  String get onboardingRoutePrivateGain => '沒有人能知道你的 IP 位址，連我們的伺服器也不能。';

  @override
  String get onboardingRouteFastCost =>
      '你連線期間，我們的伺服器能看到你的 IP 位址。\n你的網路能看到你在用 Kryfo。';

  @override
  String get onboardingRouteFastGain => '不經過 Tor：更快，也更省電。';

  @override
  String get onboardingRouteBlockedLead =>
      'Kryfo 會留在 Tor 上，需要時透過橋接。\n如有需要，快速模式在設定中。';

  @override
  String get onboardingRouteBlockedGain => '遇到封鎖會自己找到出路。';

  @override
  String get onboardingDeliveryHeadline => '訊息何時*送達*。';

  @override
  String get onboardingDeliveryLead => '你可以隨時在「通知」中更改。';

  @override
  String get homeGoogleTitle => 'Google 推播來了';

  @override
  String get homeGoogleLine => '即時又省電。Google 能看到你的手機何時被喚醒，但從不知道是誰寫的或說了什麼。';

  @override
  String get homeGoogleUse => '使用';

  @override
  String get homeGoogleOn => 'Google 推播已開啟';

  @override
  String get homeGoogleGoneTitle => 'Google 推播無法使用';

  @override
  String get appNotificationsLink => '通知 →';

  @override
  String devGooglePushes(int got, int low) {
    return 'Google 推播 $got · 被降級 $low';
  }

  @override
  String get passFieldLabel => '密碼短語';

  @override
  String get padUseLetters => '使用字母';

  @override
  String get padUseDigits => '使用數字';

  @override
  String get passWeak => '弱';

  @override
  String get passFair => '中';

  @override
  String get passStrong => '強';

  @override
  String passStrengthIs(Object level) {
    return '強度：$level';
  }

  @override
  String get lockKeyBusy => '手機的安全晶片正忙。請稍後再試。';

  @override
  String get lockKeyLocked => '請先用手機本身的 PIN 碼解鎖一次，再試一次。';

  @override
  String get lockKeyWaiting => '手機的安全晶片仍在檢查';

  @override
  String get lockKeyLost =>
      '這支手機遺失了用來檢查你 PIN 碼的金鑰，所以有些 PIN 碼可能打不開。可以重設 Kryfo 並還原備份。';

  @override
  String get lockKeyReset => '重設 Kryfo';

  @override
  String get lockKeyResetTitle => '要重設 Kryfo 嗎？';

  @override
  String get lockKeyResetLine =>
      '這支手機上 Kryfo 的所有內容都會被刪除，Kryfo 會關閉。之後你可以還原備份。隱藏聊天只能從它們開啟時做的備份中還原。';

  @override
  String get lockKeyResetSureTitle => '此操作無法復原';

  @override
  String get lockKeyResetSureLine => '這支手機上 Kryfo 的所有聊天、金鑰和設定會立即刪除。';

  @override
  String get lockKeyResetSure => '全部刪除';

  @override
  String get flowVaultPassLine => '至少 12 個字元。手機鍵盤看得到你輸入的內容，所以請使用不會學習或同步字詞的鍵盤。';

  @override
  String get flowVaultPassLineDesk => '至少 12 個字元。請使用你在別處都沒用過的。';

  @override
  String get flowVaultPassAgain => '再輸入一次同樣的密碼短語';

  @override
  String get cardTitle => '完成安全性更新';

  @override
  String get cardLine => '如果你還使用其他 PIN 碼，請在這裡各輸入一次。';

  @override
  String get cardType => '輸入 PIN 碼';

  @override
  String get cardAnswer => '好了。再輸入一個，或在完成後點「完成」。';

  @override
  String get keyLine =>
      '你的 PIN 碼只能在這支手機上使用。如果手機遺失了用來檢查它們的金鑰，你需要重設 Kryfo 並還原備份。隱藏聊天只能從它們開啟時做的備份中還原。';

  @override
  String get keyLineUnlocked =>
      '你的 PIN 碼只能在這支手機上使用，而且只在手機解鎖時可用。如果手機遺失了用來檢查它們的金鑰，你需要重設 Kryfo 並還原備份。隱藏聊天只能從它們開啟時做的備份中還原。';

  @override
  String get keyLineScreenLock => '請為手機設定螢幕鎖定，這樣手機鎖定時這層保護依然有效。';

  @override
  String get fileServerTryLater => '檔案伺服器暫時已滿，請稍後再試。';

  @override
  String fileTooBigUntilUpdate(String size, String max) {
    return '這個檔案有 $size。在所有人更新 Kryfo 之前，這個聊天裡的檔案最大為 $max。';
  }

  @override
  String get fileDayLimit => '你今天已經傳送了很多大檔案，請明天再試。';

  @override
  String get mediaProgressPreparing => '正在準備 · 請保持 App 開啟';

  @override
  String get groupShotsBlocksAll =>
      '在這個群組的每支手機上禁止截圖和螢幕錄影，也禁止複製、轉傳或儲存彼此的訊息。它擋不住獲准讀取螢幕的應用程式，或經過改動來繞過它的手機和應用程式。';

  @override
  String get groupShotsBlocksAllDesk =>
      '在這裡關閉複製、轉傳和儲存彼此的訊息。Android 版 Kryfo 還會禁止截圖和螢幕錄影。';

  @override
  String get groupShotsStartsWhenAll => '正在等待這裡的所有人都能在自己的裝置上禁止截圖';

  @override
  String get groupShotsOnForAll => '對這裡的所有人開啟';

  @override
  String get groupShotsOnForAllDesk => '在 Android 版 Kryfo 中開啟';

  @override
  String get groupShotsOffAdminOnly => '已關閉。只有管理員能變更';

  @override
  String get groupShotsWaitAdminOnly => '正在等待這裡的所有人都能在自己的裝置上禁止截圖。只有管理員能變更';

  @override
  String get groupShotsOnAdminOnly => '對這裡的所有人開啟。只有管理員能變更';

  @override
  String get groupShotsOnAdminOnlyDesk => '在 Android 版 Kryfo 中開啟。只有管理員能變更';

  @override
  String groupShotsWaitingFor(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '還在等 $countString 人',
    );
    return '$_temp0';
  }

  @override
  String get groupShotsWaitingTitle => '尚未涵蓋';

  @override
  String get groupShotsWaitingHint => '這些人的裝置能禁止截圖後，禁止截圖就涵蓋所有人。點按某人可將其移出群組。';

  @override
  String get groupShotsNeedsUpdate => '其裝置暫時無法禁止截圖，或之後一直未上線';

  @override
  String get groupShotsBlockedByYou => '已被你封鎖';

  @override
  String get groupShotsYouTurnedOnWait =>
      '你開啟了禁止截圖。等這裡的所有人都能在自己的裝置上禁止截圖後，它會對所有人生效。';

  @override
  String groupShotsTheyTurnedOnWait(String name) {
    return '$name 開啟了禁止截圖。等這裡的所有人都能在自己的裝置上禁止截圖後，它會對所有人生效。';
  }

  @override
  String get groupShotsStarted => '禁止截圖已對這裡的所有人開啟。複製、轉傳和儲存彼此的訊息也已關閉。';

  @override
  String get groupShotsStartedDesk =>
      '禁止截圖已在 Android 版 Kryfo 中開啟。複製、轉傳和儲存彼此的訊息也已關閉。';

  @override
  String get groupShotsPaused => '這裡有人還不能在其裝置上禁止截圖。等其可以後，會再次對所有人生效。';

  @override
  String get groupShotsCantYet => '還不能禁止截圖';

  @override
  String get groupShotsAddTitle => '仍要新增嗎？';

  @override
  String get groupShotsAddPauses => '在這些人能在自己的裝置上禁止截圖之前，禁止截圖不會涵蓋這裡的所有人。';

  @override
  String get groupShotsLeaveStays => '禁止截圖會維持現狀。';

  @override
  String get groupShotsBlockedHere => 'Kryfo 已在此群組中禁止截圖';

  @override
  String get groupShotsBlockedHereDesk => '此群組中不能複製、轉傳或儲存';

  @override
  String get groupShotsMenuNote => '此群組中不能複製、轉傳或儲存別人的訊息';

  @override
  String get groupShotsKeptOpen => '此群組中不能用其他應用程式開啟別人的檔案';

  @override
  String get groupShotsOldNotice => '我在這個群組開啟了禁止截圖。你的 Kryfo 還做不到，請更新一下。';

  @override
  String get captureShotTaken => '已截圖。沒有通知任何其他人。';

  @override
  String get captureRecording => '此螢幕正在被錄影。沒有通知任何其他人。';

  @override
  String get settingsDevices => '裝置';

  @override
  String get devicesLinkedDevices => '已連結的裝置';

  @override
  String get devicesThisPhoneOnly => '僅這支手機';

  @override
  String get devicesThisPhoneOnlyDesk => '僅這台電腦';

  @override
  String get devicesNameSeparator => '、';

  @override
  String get devicesThisPhone => '這支手機';

  @override
  String get devicesThisPhoneDesk => '這台電腦';

  @override
  String get devicesOnlyThisPhone => '只有這支手機能連結或移除裝置';

  @override
  String get devicesOnlyThisPhoneDesk => '只有這台電腦能連結或移除裝置';

  @override
  String devicesLinkedOn(Object date) {
    return '$date連結';
  }

  @override
  String get devicesUsedToday => '今天用過';

  @override
  String get devicesUsedThisWeek => '本週用過';

  @override
  String get devicesUsedThisMonth => '本月用過';

  @override
  String get devicesNotUsedYet => '還沒用過';

  @override
  String devicesUnlinksSoon(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$daysString 天內不開啟就會解除連結',
      one: '明天不開啟就會解除連結',
      zero: '今天不開啟就會解除連結',
    );
    return '$_temp0';
  }

  @override
  String get devicesEmptyTitle => '在電腦上用 Kryfo';

  @override
  String get devicesEmptyLine => '連結一台電腦，就能在上面讀取和傳送訊息。除了這支手機，最多再連結五台裝置。';

  @override
  String get devicesContactsSeeNothing => '你的聯絡人的 App 不會顯示你的裝置。';

  @override
  String get devicesUnusedRule => '一台裝置 30 天沒開啟，就會自己解除連結，並抹除上面的聊天。';

  @override
  String get devicesFull => '已連結五台裝置。移除一台才能再連結。';

  @override
  String get devicesLinkADevice => '連結裝置';

  @override
  String get devicesRemoveAll => '移除其他所有裝置';

  @override
  String get devicesRemoveAllTitle => '移除其他所有裝置？';

  @override
  String get devicesRemoveAllLine =>
      '等你的聯絡人的 App 收到這項變更後，它們就不會再收到新訊息，也不能以你的身分傳送。這支手機保留一切。';

  @override
  String get devicesRemoveAllYes => '全部移除';

  @override
  String get devicesRemovedAll => '現在只有這支手機';

  @override
  String devicesRemoveTitle(Object name) {
    return '移除「$name」？';
  }

  @override
  String get devicesRemoveLine =>
      '等你的聯絡人的 App 收到這項變更後，它就不會再收到新訊息，也不能以你的身分傳送。下次連上網路時，它會抹除自己上面的聊天。被人動過手腳的裝置可能會留下它已有的內容。';

  @override
  String get devicesRemove => '移除';

  @override
  String devicesRemoved(Object name) {
    return '已移除「$name」';
  }

  @override
  String get devicesRename => '重新命名';

  @override
  String devicesRenameTitle(Object name) {
    return '重新命名「$name」';
  }

  @override
  String get devicesRenameLine => '只有你能看到這個名稱，你的聯絡人永遠看不到。';

  @override
  String get devicesNameComputer => '電腦';

  @override
  String get devicesDeviceCode => '裝置代碼';

  @override
  String get devicesDeviceCodeLine => '同樣的代碼也會顯示在那台裝置的設定裡。';

  @override
  String get devicesLinkStep1 => '在電腦上開啟 Kryfo，它會顯示一個 QR 碼。';

  @override
  String get devicesLinkStep2 => '用這支手機掃描它。';

  @override
  String get devicesLinkStep3 => '確認兩個螢幕顯示的六位數字相同。';

  @override
  String get devicesHistory => '歷史記錄';

  @override
  String get devicesHistoryCopy => '複製我的聊天';

  @override
  String get devicesHistoryCopyHint => '所有訊息，以及最近 30 天的照片和影片。';

  @override
  String get devicesHistoryNone => '僅聯絡人和群組';

  @override
  String get devicesHistoryNoneHint => '它們會複製過來，不含任何訊息。';

  @override
  String get devicesSkipMedia => '略過照片和影片';

  @override
  String get devicesSkipMediaHint => '只複製文字。更快，裝置上存的也更少。';

  @override
  String get devicesHiddenStay => '隱藏聊天和偽裝都留在這支手機上。';

  @override
  String get devicesHiddenStayDesk => '隱藏聊天和偽裝都留在這台電腦上。';

  @override
  String get devicesScanCode => '掃描 QR 碼';

  @override
  String get devicesLinkReaching => '正在連線到裝置';

  @override
  String get devicesLinkReachingLine => '兩邊都保持 Kryfo 開啟。透過 Tor 可能需要一分鐘。';

  @override
  String get devicesLinkCompare => '數字一致嗎？';

  @override
  String get devicesLinkCompareLine => '新裝置上也顯示六位數字。只有相同時才連結。';

  @override
  String get devicesLinkMatch => '一致';

  @override
  String get devicesLinkNoMatch => '不一致';

  @override
  String get devicesLinkLinking => '正在連結';

  @override
  String get devicesLinkLinkingLine => '正在設定新裝置。兩邊都保持開啟。';

  @override
  String get devicesLinkDone => '裝置已連結';

  @override
  String get devicesLinkDoneLine => '它會顯示在「已連結的裝置」中，你可以在那裡重新命名或移除它。';

  @override
  String get devicesLinkUnreached => '無法連線到裝置';

  @override
  String get devicesLinkUnreachedLine => '確認新裝置上的 Kryfo 已開啟並顯示 QR 碼，然後再試一次。';

  @override
  String get devicesLinkStopped => '沒有連結任何裝置';

  @override
  String get devicesLinkStoppedLine => '數字必須一致。用新的 QR 碼重新開始。';

  @override
  String get devicesLinkInterruptedLine => '連結被中斷了。用新的 QR 碼重新開始。';

  @override
  String get scanLinkTitle => '掃描裝置的 QR 碼';

  @override
  String get scanLinkPoint => '對準新裝置上的 QR 碼';

  @override
  String get scanLinkNotOne => '這不是連結用的 QR 碼';

  @override
  String get onboardingLinkToMyPhone => '連結到我的手機';

  @override
  String get joinTitle => '連結到你的手機';

  @override
  String get joinStep1 => '在手機上開啟 Kryfo。';

  @override
  String get joinStep2 => '前往設定，然後「已連結的裝置」，然後「連結裝置」。';

  @override
  String get joinStep3 => '用手機掃描這個 QR 碼。';

  @override
  String get joinWaiting => '正在等待你的手機';

  @override
  String get joinCodeLife => 'QR 碼十分鐘內有效。';

  @override
  String get joinCompareLine => '你的手機上也顯示六位數字。只有相同時才繼續。';

  @override
  String get joinLinking => '正在連結到你的手機';

  @override
  String get joinLinkingLine => '完成前請保持手機上的 Kryfo 開啟。';

  @override
  String get joinDone => '已連結到你的手機';

  @override
  String get joinDoneLine => '新訊息現在也會送達這台裝置。你帳號的金鑰號碼：';

  @override
  String get joinOpen => '開啟 Kryfo';

  @override
  String get joinUnreached => '無法連線到你的手機';

  @override
  String get joinUnreachedLine => '確認手機已連線並開啟 Kryfo，然後換一個新的 QR 碼再試。';

  @override
  String get joinNewCode => '新 QR 碼';

  @override
  String get devicesNewNotice => '已連結新裝置';

  @override
  String devicesNewNoticeLine(Object name, Object date) {
    return '$name 於 $date 連結到你的帳號。開啟「已連結的裝置」查看。';
  }

  @override
  String get devicesNewNoticeMany => '已連結幾台新裝置';

  @override
  String devicesNewNoticeManyLine(Object names) {
    return '$names 已連結到你的帳號。開啟「已連結的裝置」查看。';
  }

  @override
  String get devicesNewNoticeOpen => '開啟';

  @override
  String get settingsLinkedToLine => '已連結到你的手機。備份和邀請會留在手機上。';

  @override
  String get devicesYourPhone => '你的手機';

  @override
  String get desktopLockTitle => 'Kryfo 已鎖定';

  @override
  String get desktopLockBody => '輸入這台電腦的密碼短語。';

  @override
  String get desktopLockNewTitle => '在這台電腦上鎖定 Kryfo';

  @override
  String get desktopLockNewBody =>
      'Kryfo 每次啟動都會要求輸入這組密碼短語。它鎖住你在這台電腦上的訊息、照片、語音訊息、檔案、聯絡人和金鑰。';

  @override
  String get desktopLockHonest =>
      '複製了 Kryfo 資料夾的人，可以在自己的電腦上盡其所能地快速嘗試密碼短語。四個以上的隨機單字撐得住，短的密碼短語撐不住。';

  @override
  String get desktopLockForgot => '沒有密碼短語，這裡你的任何訊息、檔案或金鑰都打不開，連我們也不行。';

  @override
  String get desktopLockField => '密碼短語';

  @override
  String get desktopLockRepeat => '再輸入一次相同的密碼短語';

  @override
  String get desktopLockSet => '用這組密碼短語鎖定';

  @override
  String get desktopLockOpen => '打開 Kryfo';

  @override
  String desktopLockShort(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '至少 $countString 個字元';
  }

  @override
  String get desktopLockMismatch => '兩次輸入的密碼短語不一致';

  @override
  String get desktopLockWrong => '密碼短語不對';

  @override
  String get desktopLockFailed => 'Kryfo 無法在這裡打開它的鎖。請重新啟動試試。';

  @override
  String get desktopTrayQuit => '結束 Kryfo';

  @override
  String get desktopTrayTip => 'Kryfo 正在執行並接收訊息';

  @override
  String get desktopTrayLockedTip => '打開 Kryfo 即可開始接收訊息';

  @override
  String get desktopTrayStillRunning => 'Kryfo 仍在系統匣中執行。要結束，請使用系統匣圖示。';

  @override
  String get desktopRunSection => '在這台電腦上';

  @override
  String get desktopTrayRow => '在系統匣中保持執行';

  @override
  String get desktopTrayHint => '關閉視窗後，訊息照常送達。';

  @override
  String get desktopTrayOffLine => '關閉視窗會結束 Kryfo。\n再次開啟時，訊息就會送達。';

  @override
  String get desktopTrayNoneLine => '這個桌面沒有系統匣圖示。\n關閉視窗會結束 Kryfo。';

  @override
  String get desktopStartRow => '隨電腦啟動';

  @override
  String get desktopStartHint => '登入這台電腦時，Kryfo 會在系統匣中啟動。';

  @override
  String get desktopStartRefused => '這台電腦不允許 Kryfo 隨它啟動。\n你自己啟動時，Kryfo 照常開啟。';

  @override
  String get desktopStartHeldOff =>
      'Windows 在啟動應用程式中關閉了 Kryfo。\n請到 Windows 設定、應用程式、啟動中開啟它。';

  @override
  String get desktopMicBlocked => '在設定、隱私權與安全性、麥克風中允許桌面應用程式使用麥克風後，Kryfo 即可錄音。';

  @override
  String get desktopMicNone => '連接麥克風即可錄製語音。';

  @override
  String get desktopNoCamera => 'Kryfo 暫時還不能在這台電腦上使用相機。請改用連結或代碼。';

  @override
  String get desktopAlreadyOpen => 'Kryfo 已經在這台電腦上開啟了。';

  @override
  String get desktopFolderNotYours => 'Kryfo 的資料夾屬於這台電腦上的另一個帳戶，所以 Kryfo 不會開啟它。';

  @override
  String get desktopFolderNotPrivate => 'Kryfo 無法把它的資料夾設為只有你能存取，所以不會開啟。';

  @override
  String get desktopLockOtherVersion => '這個鎖是另一個版本的 Kryfo 建立的，目前的版本無法讀取。';

  @override
  String get desktopNoMemoryFolder =>
      'Kryfo 執行時需要記憶體中的一個私有資料夾，而這台電腦沒有提供，所以 Kryfo 不會開啟。';

  @override
  String get inviteNotYet => '此邀請尚未生效。請檢查手機上的時間。';

  @override
  String get inviteNotYetDesk => '此邀請尚未生效。請檢查電腦上的時間。';

  @override
  String get inviteExpired => '此邀請已過期。請索取新的邀請。';

  @override
  String get inviteDamaged => '此邀請已損壞。請索取新的邀請。';

  @override
  String get helloSent => '請求已送出。對方上線後就會看到。';

  @override
  String get inviteNeeds06 => '需要 Kryfo 0.6 或更新版本。';

  @override
  String get helloSentOld => '請求已送出。如果對方使用的是舊版 Kryfo，需要先更新。';

  @override
  String get modesPickHow => '選擇訊息的傳送方式。隨時都可以更改。';

  @override
  String get modesPrivate => '私密';

  @override
  String get modesPrivateTag => 'Tor · 需要時用網橋';

  @override
  String get modesPrivateLine => '沒有人能知道你的 IP 位址或你是誰，連我們的伺服器也不能。遇到封鎖會自己找到出路。';

  @override
  String get modesDefault => '預設';

  @override
  String get modesFastTag => '直連我們的伺服器';

  @override
  String get modesFastLine =>
      '不經過 Tor，訊息到得更快，也更省電。我們的伺服器只在你連線期間看到你的 IP 位址，從不記錄或保存。你的聯絡人永遠看不到它。你的網路能看到你在連線 Kryfo。';

  @override
  String get modesFastConnected => '快速 · 已連線';

  @override
  String get modesFastConnecting => '快速 · 連線中';

  @override
  String get modesFastDown => '快速 · 我們的伺服器沒有回應';

  @override
  String get modesBackupReady => '始終有一台備用伺服器待命，即使其中一台出問題，你也不會斷線。';

  @override
  String get modesDetails => '詳情';

  @override
  String get modesBothLine => '兩種方式都對每則訊息端對端加密。不同的只是誰能看到你的 IP 位址。';

  @override
  String get modesConnectionBridges => '連線與網橋';

  @override
  String get modesWhatServersSee => '我們的伺服器能看到什麼';

  @override
  String get serversTitle => '快速模式的伺服器';

  @override
  String get serversLine => '每則訊息同時送往兩台伺服器。先回應的那台負責送達，一台停了另一台就接手。';

  @override
  String get serversOne => '伺服器 1';

  @override
  String get serversTwo => '伺服器 2 · 另一家服務商';

  @override
  String get serversConnected => '已連線';

  @override
  String get serversConnecting => '連線中';

  @override
  String get serversNotAnswering => '沒有回應';

  @override
  String serversMs(int ms) {
    return '$ms 毫秒';
  }

  @override
  String get serversQuicker => '更快';

  @override
  String get serversBackups => '公共中繼';

  @override
  String get serversBackupsLine =>
      '在伺服器 1 停擺期間使用，而且只經 Tor 連線，所以它們永遠看不到你的 IP 位址。';

  @override
  String get serversStandingBy => '待命中';

  @override
  String get serversInUse => '使用中';

  @override
  String get homeMergedTitle => '中繼和快速現已合而為一';

  @override
  String get homeMergedLine =>
      '你正在使用快速模式。始終有一台備用伺服器待命，即使其中一台出問題，你也不會斷線。我們的伺服器能看到你的 IP 位址，但永遠看不到你說了什麼。';

  @override
  String get homeMergedGotIt => '知道了';

  @override
  String get homeMergedUsePrivate => '改用私密';

  @override
  String get homeOursDownTitle => '我們的伺服器沒有回應';

  @override
  String get homeOursDownLine => '幾分鐘後，只要 Tor 能連通，訊息也會走公共中繼，我們任一台伺服器一回應就換回來。';

  @override
  String get homeUsePrivate => '使用私密';

  @override
  String get homeSwitchedToPrivate => '已切換到私密';

  @override
  String get homeUseFast => '使用快速';

  @override
  String get homeSwitchedToFastRoute => '已切換到快速';

  @override
  String get bridgesBridgeFirstFastSeen =>
      '讓 Kryfo 找一個能連通的橋接。快速模式也行，但這個網路能看到你在連線 Kryfo。';

  @override
  String get appServersNotAnswering => '伺服器沒有回應';

  @override
  String get settingsPrivateTor => '私密 · Tor';

  @override
  String get seenOurServers => '我們的伺服器';

  @override
  String get seenOurServersCould => '我們的伺服器可能看到';

  @override
  String get seenIpWhy =>
      '私密模式下一切都經 Tor 送出，我們的伺服器看到的是出口節點，永遠不是你。快速模式下連線直達我們的兩台伺服器：你連線期間它們能看到你的 IP 位址，但不留任何紀錄。第一台停擺期間，快速模式也會使用公共中繼，而且只經 Tor 連線。';

  @override
  String get chatAlbumItDisappearsWithNo => '這個相簿會從雙方的手機上刪除，除非已被儲存。這個動作無法復原。';

  @override
  String get chatAlbumItDisappearsWithNoDesk =>
      '這個相簿會從雙方的裝置上刪除，除非已被儲存。這個動作無法復原。';

  @override
  String get groupChatAlbumItDisappearsWithNo =>
      '這個相簿會從所有人的手機上刪除，除非已被儲存。這個動作無法復原。';

  @override
  String get groupChatAlbumItDisappearsWithNoDesk =>
      '這個相簿會從所有人的裝置上刪除，除非已被儲存。這個動作無法復原。';

  @override
  String get homeInviteSomeone => '邀請一個人';

  @override
  String get onboardingNameHeadline => '如果你願意，取一個公開的 *@名字*。';

  @override
  String get onboardingNameLine => '公開的 @名字能讓別人找到你。\n跳過會更私密。\n你之後可以再加。';

  @override
  String get onboardingNameSkip => '先跳過 →';

  @override
  String onboardingNameClaim(Object handle) {
    return '使用 @$handle →';
  }

  @override
  String get onboardingInviteHeadline => '現在，*邀請一個人*。';

  @override
  String get onboardingInviteLead => '用任何通訊軟體傳一個連結。\n它會開啟 Kryfo，或告訴對方去哪裡下載。';

  @override
  String get onboardingInviteSomeone => '邀請一個人 →';

  @override
  String get onboardingInviteGettingReady => '正在準備你的連結…';

  @override
  String inviteShareText(Object myId, Object link, Object download) {
    return '在 Kryfo 上加我。我的名字是 $myId\n\n點這裡加我：\n$link\n\n還沒有 Kryfo？在這裡下載：\n$download\n\nKryfo 是一款私密通訊軟體。不需要手機號碼，也不需要電子郵件。';
  }

  @override
  String get inviteNotReady => '你的連結快好了。稍後再試一次。';

  @override
  String get photoCropTitle => '移動和縮放';

  @override
  String get photoCropUse => '使用照片';

  @override
  String get photoCropLabel => '圓圈裡是你的照片。雙指縮放，拖動移動';

  @override
  String get photoCouldNotUse => '換一張照片試試。這張無法讀取。';

  @override
  String get photoTake => '拍照';

  @override
  String get photoChoose => '從相簿選擇';

  @override
  String get photoPickFace => '選擇頭像';

  @override
  String get photoView => '查看照片';

  @override
  String get photoRemove => '移除照片';

  @override
  String get photoYourPhoto => '你的照片';

  @override
  String get photoYourPhotoLine => '只有你的聯絡人看得到，端對端加密。';

  @override
  String get photoSetTheirs => '設定照片';

  @override
  String get photoChangeTheirs => '更換照片';

  @override
  String get photoOnlyHere => '只在這支手機上';

  @override
  String get photoOnlyHereDesk => '只在這台電腦上';

  @override
  String photoForThem(Object name) {
    return '給$name的照片';
  }

  @override
  String get photoOnlyHereLine => '只有你看得到。只存在這支手機上。';

  @override
  String get photoOnlyHereLineDesk => '只有你看得到。只存在這台電腦上。';

  @override
  String photoOf(Object name) {
    return '$name的照片';
  }

  @override
  String get historyChatStaysShots => '此聊天禁止截圖，所以只留在你的手機上。';

  @override
  String chatDeviceReplyFromPhone(String name) {
    return '$name 使用的是較舊版本的 Kryfo。請在手機上回覆。';
  }

  @override
  String chatDeviceReplyFromPhoneForNow(String name) {
    return '暫時請在手機上回覆 $name。';
  }

  @override
  String get linkedClearHereOnly => '這裡的每則訊息只會從這台電腦上抹除。你的手機會保留它們。';

  @override
  String get linkedDeleteHereOnly => '所有訊息和這位聯絡人只會從這台電腦上移除。你的手機會保留這段聊天。';

  @override
  String get linkedBlockHereOnly =>
      '對方的訊息將不再送達這台電腦。對方不會收到通知。在手機上封鎖對方，手機上也不會再收到。';

  @override
  String get historyCopyTitle => '聊天記錄';

  @override
  String get historyCopyMaking => '正在準備你的聊天';

  @override
  String get historyCopyMakingLine => '你的手機正在整理要複製的內容，馬上開始。';

  @override
  String get historyCopyGoing => '正在複製你的聊天';

  @override
  String get historyCopyGoingLine => '複製完成前，請讓兩台裝置保持在線。';

  @override
  String historyCopySize(Object size) {
    return '共 $size';
  }

  @override
  String get historyCopyWaiting => '正在等待另一台裝置';

  @override
  String get historyCopyWaitingLine => '兩台裝置都在線時，複製會自動繼續。';

  @override
  String get historyCopyPaused => '複製稍作停頓';

  @override
  String get historyCopyPausedLine => '一分鐘後繼續。';

  @override
  String get historyCopyWhole => '所有訊息和檔案都已複製';

  @override
  String get historyCopyWholeLine => '沒有遺漏。';

  @override
  String get historyCopyRows => '你的聯絡人和群組已複製';

  @override
  String get historyCopyRowsLine => '它們已複製過來，不含任何訊息。從現在起，新訊息會顯示在這台裝置上。';

  @override
  String get historyCopyGaps => '大部分聊天已複製';

  @override
  String get historyCopyGapsLine => '這些聊天在新裝置上的內容比手機上少。';

  @override
  String historyCopyGapMessages(Object got, Object want) {
    return '訊息：$got / $want';
  }

  @override
  String historyCopyGapFiles(Object got, Object want) {
    return '檔案：$got / $want';
  }

  @override
  String historyCopyLeft(num count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 項留在你的手機上',
    );
    return '$_temp0';
  }

  @override
  String get historyCopyLeftWhy => '太大或無法讀取，無法複製。';

  @override
  String historyCopyLeftChats(num count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 個聊天留在你的手機上',
    );
    return '$_temp0';
  }

  @override
  String get historyCopyEnded => '複製已停止';

  @override
  String get historyCopyEndedLine => '不會再有內容複製過來。重新連結裝置即可重新複製。';

  @override
  String get historyCopyFailed => '複製未能完成';

  @override
  String get historyCopyFailedLine => '重新連結裝置即可重新複製。';

  @override
  String get historyCopyStays => '留在你的手機上';

  @override
  String get historyCopySee => '查看複製情況';

  @override
  String a11yPinDigits(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 位數字',
      zero: '沒有數字',
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
      other: '$countString 個字元',
      zero: '沒有字元',
    );
    return '$_temp0';
  }

  @override
  String get a11yBackupProgress => '備份進度';

  @override
  String get a11yRestoreProgress => '還原進度';

  @override
  String get a11yExportProgress => '匯出進度';

  @override
  String get a11yLockFileProgress => '鎖定進度';

  @override
  String get a11yCleanProgress => '清理進度';

  @override
  String get a11yMessageActions => '訊息操作';

  @override
  String get a11yRecordVoiceNote => '錄製語音訊息';

  @override
  String get a11yRecording => '正在錄音';

  @override
  String a11yPhotoOn(String date) {
    return '照片，$date';
  }

  @override
  String a11yPhotoFrom(String name, String date) {
    return '$name 傳來的照片，$date';
  }

  @override
  String a11yVideoOn(String date) {
    return '影片，$date';
  }

  @override
  String a11yVideoFrom(String name, String date) {
    return '$name 傳來的影片，$date';
  }

  @override
  String a11yNewMessages(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 則新訊息',
      one: '新訊息',
    );
    return '$_temp0';
  }

  @override
  String get wideSelectChat => '選擇一個聊天';

  @override
  String get wideSelectChatLine => '從列表中選擇一個聊天，開始寫訊息。';

  @override
  String get wideListWidth => '聊天列表寬度';

  @override
  String transferDoneOf(String done, String total) {
    return '$done/$total';
  }

  @override
  String transferDoneLeft(String done, String left) {
    return '$done · $left';
  }

  @override
  String get transferLeftSoon => '剩不到一分鐘';

  @override
  String transferLeftMinutes(String n) {
    return '剩約 $n 分鐘';
  }

  @override
  String transferLeftHours(String n) {
    return '剩約 $n 小時';
  }

  @override
  String transferSending(String detail) {
    return '傳送中 · $detail';
  }

  @override
  String transferReceiving(String detail) {
    return '接收中 · $detail';
  }

  @override
  String transferBoth(String detail) {
    return '收發中 · $detail';
  }

  @override
  String get transferPause => '暫停';

  @override
  String get transferPauseDownload => '暫停下載';

  @override
  String get transferDownload => '下載';

  @override
  String get transferResume => '繼續';

  @override
  String get transferOnWifi => '連上 Wi-Fi 時下載';

  @override
  String transferPausedAt(String detail) {
    return '已暫停 · $detail';
  }

  @override
  String get transferTapToDownload => '輕觸即可下載';

  @override
  String transferSizeLine(String size, String state) {
    return '$size · $state';
  }

  @override
  String get transferNoteTitle => '檔案傳輸';

  @override
  String get transferChannel => '檔案傳輸';

  @override
  String get transferChannelLine => '在傳送或下載檔案時顯示。絕不顯示聊天或檔案的名稱。';

  @override
  String get autoGetTitle => '自動下載';

  @override
  String get autoGetLine => '檔案會依這裡的設定自動送達。等待中的檔案會在檔案伺服器上為你保留，最多一週。';

  @override
  String get autoGetPhotos => '照片';

  @override
  String get autoGetVideos => '影片';

  @override
  String get autoGetFiles => '檔案';

  @override
  String get autoGetAlways => 'Wi-Fi 和行動數據';

  @override
  String get autoGetWifi => '僅限 Wi-Fi';

  @override
  String get autoGetNever => '永不，我輕觸下載';

  @override
  String get autoGetVoice => '語音訊息一律會下載。';

  @override
  String get settingsFiles => '檔案';

  @override
  String get fileSheetOpenWith => '用其他 App 開啟';

  @override
  String get desktopLockAccountBody => 'Kryfo 在這台電腦上保存的所有內容都已加密。它會用你的使用者帳戶開啟。';

  @override
  String get desktopLockAddPassphrase => '新增密碼短語';

  @override
  String get desktopLockWithoutPassphrase => '沒有它，任何使用你的使用者帳戶的人都能開啟 Kryfo。';

  @override
  String get desktopLockKeyringRefused =>
      'Kryfo 無法把它的金鑰保存在這台電腦的鑰匙圈中。請改為新增密碼短語。';

  @override
  String get desktopKeyMissing =>
      '這個使用者帳戶沒有 Kryfo 資料的金鑰。Kryfo 備份能找回一切。如果你移動過 Kryfo 的資料夾，請在它原本的使用者帳戶上新增密碼短語，然後再複製一次。';

  @override
  String get desktopKeyUnreachable =>
      'Kryfo 現在無法取得這台電腦上的金鑰。如果電腦提示，請解鎖你的鑰匙圈，然後再試一次。';

  @override
  String get desktopPassRow => '這台電腦上的密碼短語';

  @override
  String get desktopPassWindowsAccount => '由你的 Windows 帳戶鎖定';

  @override
  String get desktopPassKeyring => '由你的鑰匙圈鎖定';

  @override
  String get desktopPassOffBody => 'Kryfo 會用你的使用者帳戶開啟。';

  @override
  String get desktopPassOnBody => 'Kryfo 每次啟動時都會詢問這個密碼短語。';

  @override
  String get desktopPassChange => '變更密碼短語';

  @override
  String get desktopPassRemove => '移除密碼短語';

  @override
  String get desktopPassCurrent => '目前的密碼短語';

  @override
  String get desktopPassNew => '新的密碼短語';

  @override
  String get desktopPassStays => '這台電腦上沒有 Kryfo 能用的鑰匙圈，所以密碼短語會保留。';

  @override
  String get desktopPassAdded => '已新增密碼短語';

  @override
  String get desktopPassRemoved => '已移除密碼短語';

  @override
  String get desktopPassChanged => '已變更密碼短語';

  @override
  String get desktopPassRemoveBody => '輸入你的密碼短語來移除它。之後 Kryfo 會用你的使用者帳戶開啟。';

  @override
  String get desktopKeyUnreachableWindows =>
      'Kryfo 現在無法取得這台電腦安全晶片中的金鑰。請稍後再試一次。';

  @override
  String get desktopLockAccountRefused =>
      'Kryfo 無法用你的 Windows 帳戶保存它的金鑰。請改為新增密碼短語。';

  @override
  String get desktopPassStaysWindows =>
      'Kryfo 無法用你的 Windows 帳戶保存它的金鑰，所以密碼短語會保留。';

  @override
  String get desktopBackupCardTitle => '留一份 Kryfo 備份';

  @override
  String get desktopBackupCardLine =>
      '這台電腦上的 Windows 帳戶保管著 Kryfo 的金鑰。如果電腦或帳戶被重設，Kryfo 備份能找回一切。';

  @override
  String get desktopBackupHint => '如果這台電腦被重設，它能找回一切。';

  @override
  String chatHealRestored(Object name) {
    return '$name 重新設定了 Kryfo';
  }

  @override
  String chatHealNewSession(Object name) {
    return '$name 的裝置開始了新的安全工作階段';
  }

  @override
  String chatHealHeldLine(Object name) {
    return '你之前驗證過 $name。在你核對安全碼或繼續聊天之前，什麼都不會送出。對方的訊息仍會收到。';
  }

  @override
  String get chatKeepChatting => '繼續聊天';

  @override
  String chatNeedsUpdateToChat(Object name) {
    return '$name 需要更新 Kryfo 才能繼續聊天';
  }

  @override
  String get restoreOlderTitle => '部分聊天將暫停';

  @override
  String restoreOlderOne(Object name) {
    return '$name 使用的是舊版 Kryfo。在對方更新前，你們的聊天會暫停。';
  }

  @override
  String restoreOlderTwo(Object first, Object second) {
    return '$first 和 $second 使用的是舊版 Kryfo。在他們更新前，你和他們的聊天會暫停。';
  }

  @override
  String restoreOlderMany(Object first, Object second, int count) {
    return '$first、$second 和另外 $count 人使用的是舊版 Kryfo。在他們更新前，你和他們的聊天會暫停。';
  }

  @override
  String settingsVersionAlpha(String version) {
    return '$version · alpha 版';
  }

  @override
  String get settingsDeskInTray => '在系統匣中執行';

  @override
  String get settingsDeskWhileOpen => 'Kryfo 開啟期間';

  @override
  String get onboardingDeskRunTitle => 'Kryfo 一直*在線*。';

  @override
  String get onboardingDeskRunLead =>
      '關閉視窗後，Kryfo 會在系統匣中等候。\n訊息照常送達。\n這兩項都可以在「設定」的「通知」裡變更。';

  @override
  String get savedLongPressAnyMessageDesk => '在任何訊息上按右鍵，再選「儲存」，就能收藏在這裡。';

  @override
  String get chatFailedTapToRetryDesk => '失敗 · 按一下重試';

  @override
  String get groupChatTapToRetryDesk => '! 按一下重試';

  @override
  String get chatDropHereToSend => '拖到這裡放開即可傳送';

  @override
  String get chatDropHereToAdd => '拖到這裡放開即可加入';

  @override
  String trayRemove(String name) {
    return '移除 $name';
  }

  @override
  String trayReadyToSend(Object count) {
    return '待傳送：$count';
  }

  @override
  String get trayPastedPicture => '貼上的圖片';

  @override
  String get voiceSeeTranscription => '查看文字';

  @override
  String get voiceTranscribing => '正在轉成文字…';

  @override
  String get voiceHideTranscription => '收起';

  @override
  String get voiceShowOriginalOnly => '只看原文';

  @override
  String get voiceCouldNotTranscribe => '沒能聽出內容';

  @override
  String get voiceTranscriptLabel => '文字內容';

  @override
  String get voiceSettingsTitle => '語音轉文字';

  @override
  String get voiceOnRow => '把語音訊息轉成文字';

  @override
  String get voiceOnHint => '在每則語音訊息下方提供';

  @override
  String get voiceOffDeletes => '關閉後會刪除已儲存的文字內容。';

  @override
  String get voiceModelTitle => '語音模型';

  @override
  String voiceModelLine(Object size) {
    return '只需下載一次，約 $size，支援所有語言。';
  }

  @override
  String get voiceModelPrivacy => '透過 Tor 下載並保存在這支手機上。你的語音訊息從不離開它。';

  @override
  String get voiceModelPrivacyDesk => '透過 Tor 下載並保存在這台電腦上。你的語音訊息從不離開它。';

  @override
  String get voiceModelFailNoTor => 'Tor 還沒有連線。模型只透過 Tor 下載，請在連線後再試一次。';

  @override
  String get voiceModelRemoveTitle => '移除語音模型？';

  @override
  String get voiceModelRemoveLine => '已產生的文字會保留。新的需要再次下載模型。';

  @override
  String get voiceKeptNote => '文字內容與所屬聊天一起加密保存在這支手機上，並隨聊天一起刪除。';

  @override
  String get voiceKeptNoteDesk => '文字內容與所屬聊天一起加密保存在這台電腦上，並隨聊天一起刪除。';

  @override
  String get voiceNotNow => '以後再說';

  @override
  String get unlinkedTitle => '這台裝置已解除連結';

  @override
  String get unlinkedRemovedLine => '你的手機已把它從帳號中移除，所以 Kryfo 抹除了它在這裡保存的一切。';

  @override
  String get unlinkedUnusedLine => '它 30 天沒被開啟，所以 Kryfo 抹除了它在這裡保存的一切。';

  @override
  String get unlinkedSilentLine => '它 30 天沒有收到你手機的任何訊息，所以 Kryfo 抹除了它在這裡保存的一切。';

  @override
  String get unlinkedClockLine => '它的時鐘被調回了，所以 Kryfo 為保護你的聊天，抹除了它在這裡保存的一切。';

  @override
  String get unlinkedBrokenLine =>
      'Kryfo 無法得知它上次是何時被開啟的，所以為保護你的聊天，抹除了它在這裡保存的一切。';

  @override
  String get unlinkedSelfLine => '你解除了它的連結，所以 Kryfo 抹除了它在這裡保存的一切。';

  @override
  String get unlinkedAgainLine => '你的聊天仍在手機上。要在這裡再次使用 Kryfo，請把這台裝置連結到你的手機。';

  @override
  String get unlinkedClose => '關閉 Kryfo';

  @override
  String get devicesLeave => '解除這台裝置的連結';

  @override
  String get devicesLeaveTitle => '解除這台裝置的連結？';

  @override
  String get devicesLeaveLine => 'Kryfo 會告訴你的手機，並抹除它在這裡保存的一切。你的聊天仍在手機上。';

  @override
  String get devicesLeaveYes => '解除連結並抹除';

  @override
  String get devicesGoneNotice => '裝置已移除';

  @override
  String devicesGoneRemovedLine(Object name, Object date) {
    return '$name 於 $date 從你的帳號中移除。';
  }

  @override
  String devicesGoneUnusedLine(Object name, Object date) {
    return '$name 30 天沒有使用，所以於 $date 從你的帳號中移除。';
  }

  @override
  String devicesGoneItselfLine(Object name, Object date) {
    return '$name 於 $date 自己解除了連結，並抹除了上面保存的內容。';
  }

  @override
  String get devicesChangedNotice => '你的裝置有變化';

  @override
  String get devicesChangedLine => '開啟「已連結的裝置」查看變化。';

  @override
  String get devicesUnknownNotice => '在別處連結的裝置';

  @override
  String get devicesUnknownLine => '另一份 Kryfo 把一台裝置連結到了你的帳號。這支手機已把它從你的清單中移除。';

  @override
  String get albumPrevious => '上一個';

  @override
  String get albumNext => '下一個';

  @override
  String get notesHoldHintDesk => '在筆記上按右鍵即可複製或刪除。';

  @override
  String get pinsNothingPinnedHereYetDesk =>
      '這裡還沒有置頂的訊息。在一則訊息上按右鍵並選擇「置頂」，它就會在這裡等著聊天中的每個人。';

  @override
  String get chatGalleryDesk => '圖片';

  @override
  String get groupChatGalleryDesk => '圖片';

  @override
  String get photoChooseDesk => '選擇圖片檔案';

  @override
  String get wallpaperFromYourPhotosDesk => '從圖片檔案';

  @override
  String get notificationsSoundAndVibrationDesk => '聲音';

  @override
  String get notificationsPlaySound => '播放提示音';

  @override
  String get notificationsPlaySoundHint => '這台電腦上的每則通知都會響';

  @override
  String bridgesShareBridgeN(String n) {
    return '分享橋接 $n';
  }

  @override
  String get bridgesShareThisBridge => '分享這個橋接';

  @override
  String get bridgesShareItPrivately => '請私下分享給你信任的人。不出現在公開頁面上的橋接能用得更久。';

  @override
  String get bridgesCopyBridge => '複製橋接';

  @override
  String get bridgesBridgeCopied => '已複製橋接';

  @override
  String get bridgesSendBridgeTo => '把橋接傳給';

  @override
  String get linkedAddOnPhone => '在手機上新增聯絡人。他們也會出現在這裡。';

  @override
  String get linkedLinkOnPhone => '在手機上開啟這個連結。';

  @override
  String get linkedDoOnPhone => '請在手機上操作。';

  @override
  String get tipsTitle => '支持 Kryfo';

  @override
  String get tipsHeadline => '讓 Kryfo *對所有人免費*';

  @override
  String get tipsLine => '沒有廣告，沒有投資人，沒有帳號。小費幫忙支付伺服器和 Kryfo 的開發工作。';

  @override
  String get tipsLeave => '給小費';

  @override
  String get tipsYours => '已擁有';

  @override
  String get tipsAsking => '正在向 Google Play 詢問價格';

  @override
  String get tipsBadgeOnly =>
      '小費會給你一枚支持者徽章，除此之外什麼都沒有。不管給不給小費，Kryfo 的一切對所有人都免費。';

  @override
  String get tipsThroughPlay => '付款透過 Google Play 完成。我們永遠看不到你的信用卡資料，也看不到你的名字。';

  @override
  String get tipsBadgeStays => '徽章保存在這支手機上。在「我」裡，你可以選擇是否顯示它，以及聯絡人能否看到它。';

  @override
  String get tipsRestore => '恢復我的徽章';

  @override
  String get tipsRestoreLine => '以前給過小費？在登入同一個 Google 帳號的任何手機上，你的徽章都會回來。';

  @override
  String tipsRestored(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter': '你的支持者徽章回來了',
      'patron': '你的贊助人徽章回來了',
      'guardian': '你的守護者徽章回來了',
      'other': '你的支持者徽章回來了',
    });
    return '$_temp0';
  }

  @override
  String get tipsNothingToRestore => '這個 Google 帳號還沒有給過小費';

  @override
  String get tipsUnavailable =>
      '小費透過 Google Play 完成。等 Google Play 在這支手機上能用了，小費就會出現在這裡。';

  @override
  String get tipsSoon => '小費很快就會在這裡開放。';

  @override
  String get tipsPending => 'Google Play 還在完成你的付款。付款一通過，你的徽章就會到來。';

  @override
  String get tipsFailed => 'Google Play 沒有完成付款。請稍後再試。';

  @override
  String get tipsThanks => '謝謝你';

  @override
  String tipsGranted(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter': '你現在有了支持者徽章。它不會解鎖其他任何東西：Kryfo 的一切對所有人都免費。',
      'patron': '你現在有了贊助人徽章。它不會解鎖其他任何東西：Kryfo 的一切對所有人都免費。',
      'guardian': '你現在有了守護者徽章。它不會解鎖其他任何東西：Kryfo 的一切對所有人都免費。',
      'other': '你現在有了支持者徽章。它不會解鎖其他任何東西：Kryfo 的一切對所有人都免費。',
    });
    return '$_temp0';
  }

  @override
  String tipsKept(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter': '謝謝你的小費。你保留更高的支持者徽章。',
      'patron': '謝謝你的小費。你保留更高的贊助人徽章。',
      'guardian': '謝謝你的小費。你保留更高的守護者徽章。',
      'other': '謝謝你的小費。你保留更高的支持者徽章。',
    });
    return '$_temp0';
  }

  @override
  String get tipsProfileCard => '給點小費，讓 Kryfo 保持獨立';

  @override
  String chatDeviceLinked(Object name) {
    return '$name 連結了一台新裝置';
  }

  @override
  String chatDeviceRemoved(Object name) {
    return '$name 移除了一台裝置';
  }

  @override
  String chatDeviceListUnchecked(Object name) {
    return '無法核對 $name 的裝置清單';
  }

  @override
  String get notesDropToKeep => '拖到這裡放開即可保存';

  @override
  String get notesOnAllDevices => '在你所有的裝置上';

  @override
  String get notesKeepAnything => '在這裡保存文字、照片和檔案。它們會出現在你所有的裝置上。';

  @override
  String get notesGoneEverywhere => '它會從你所有的裝置上永久抹除。';

  @override
  String get notesDeleteAllEverywhere => '所有筆記都會從你所有的裝置上永久刪除。';

  @override
  String get notesDeleteAllHereOnly => '所有筆記只會從這台裝置上刪除。你的手機仍會保留它們。';

  @override
  String get notesAddItem => '新增照片或檔案';

  @override
  String get notesVoiceNotKept => '你的語音訊息沒有保存';

  @override
  String get handleOlderKryfo => '對方使用的是舊版 Kryfo。請對方先更新，然後再新增。';

  @override
  String groupMemberNeedsUpdate(Object name) {
    return '$name 使用的是舊版 Kryfo，需要更新後才能在這裡收到訊息。';
  }

  @override
  String get groupMembersNeedUpdate => '部分成員使用的是舊版 Kryfo，需要更新後才能在這裡收到訊息。';

  @override
  String get onboardingAlwaysOnNotice =>
      'Android 需要一則常駐的無聲通知，這樣 Kryfo 關閉時也能收到訊息。';

  @override
  String get toolsSendToAChat => '傳送到聊天';

  @override
  String get toolsOneFileAtATime => '一次一個檔案';

  @override
  String get toolsLockThisFile => '鎖定這個檔案';

  @override
  String get toolsLockThisFileLine => 'Kryfo 可以用密碼鎖定它，只有知道密碼的人才能開啟。';

  @override
  String get toolsDropHere => '把檔案拖到這裡，用工具開啟';

  @override
  String get toolsCopyPicture => '複製圖片';

  @override
  String get toolsPictureCopied => '圖片已複製';

  @override
  String get toolsCouldNotCopy => '無法複製圖片';

  @override
  String get cleanNotYetHere => '這張圖片目前還不能在這裡清理';

  @override
  String get cleanNotYetHereLine => '即將推出的更新會在電腦上清理這樣的圖片。你的圖片原封未動。';
}
