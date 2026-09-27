// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get atmosphereNone => 'không có';

  @override
  String get atmosphereEmber => 'than hồng';

  @override
  String get atmosphereDusk => 'hoàng hôn';

  @override
  String get atmosphereMoss => 'rêu';

  @override
  String get atmosphereRose => 'hồng';

  @override
  String get atmosphereDots => 'chấm bi';

  @override
  String get atmosphereGrid => 'lưới';

  @override
  String get atmosphereWaves => 'sóng';

  @override
  String get atmosphereRain => 'mưa';

  @override
  String get atmosphereLateNight => 'Đêm khuya';

  @override
  String get atmosphereWarmAfternoon => 'Chiều ấm';

  @override
  String get atmosphereSnow => 'tuyết';

  @override
  String get atmosphereDesert => 'sa mạc';

  @override
  String get atmospherePaper => 'giấy';

  @override
  String get backupThatPassphraseDoesNot =>
      'Cụm mật khẩu đó không mở được tệp này';

  @override
  String get backupThatFileIsNot => 'Tệp đó không phải bản sao lưu Kryfo';

  @override
  String get backupThisBackupIsFrom =>
      'Bản sao lưu này đến từ một bản Kryfo mới hơn. Hãy cập nhật ứng dụng rồi thử lại';

  @override
  String get backupThisFileIsDamaged => 'Tệp này bị hỏng và không thể đọc được';

  @override
  String get backupCouldNotMakeThe => 'Không tạo được khóa';

  @override
  String get contactCardMessageMeOn => 'Nhắn tôi trên';

  @override
  String get contactCardScanItOrType =>
      'Quét mã, hoặc nhập ba từ vào Kryfo.\nNgoài ba từ đó, thẻ này không biết gì về bạn.';

  @override
  String contactCardMessageMeOnKryfo(Object haloId) {
    return 'Nhắn tôi trên Kryfo · $haloId';
  }

  @override
  String get contactStatusBlocked => 'đã chặn';

  @override
  String get contactStatusKeysVerifiedInPerson => 'Đã xác minh khóa trực tiếp';

  @override
  String get contactStatusWaitingInRequests => 'Đang chờ ở mục yêu cầu';

  @override
  String get contactStatusAddedByHand => 'Đã thêm thủ công';

  @override
  String get deliveryModeAlwaysOn => 'Luôn bật';

  @override
  String get deliveryModeCheckIns => 'Kiểm tra định kỳ';

  @override
  String get deliveryModeThroughAHelperApp => 'Qua ứng dụng trợ giúp';

  @override
  String get deliveryModeNotYet => 'chưa có';

  @override
  String get deliveryModeJustNow => 'vừa xong';

  @override
  String deliveryModeMinAgo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString phút trước',
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
      other: '$countString giờ trước',
    );
    return '$_temp0';
  }

  @override
  String get deliveryModeYesterday => 'hôm qua';

  @override
  String deliveryModeDaysAgo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString ngày trước',
    );
    return '$_temp0';
  }

  @override
  String get deliveryModeConnected => 'Đã kết nối';

  @override
  String get deliveryModeConnecting => 'Đang kết nối';

  @override
  String get deliveryModeNotConnected => 'Chưa kết nối';

  @override
  String get deliveryModeCheckingNow => 'Đang kiểm tra';

  @override
  String deliveryModeLastCheckIn(Object agoLine) {
    return 'lần kiểm tra cuối $agoLine';
  }

  @override
  String get deliveryModeNoCheckInYet => 'chưa kiểm tra lần nào';

  @override
  String deliveryModeConnectedNow(Object last) {
    return 'Hiện đã kết nối · $last';
  }

  @override
  String deliveryModeConnecting2(Object last) {
    return 'Đang kết nối · $last';
  }

  @override
  String get deliveryModeNoCheckInYet2 => 'Chưa kiểm tra lần nào';

  @override
  String deliveryModeLastChecked(Object agoLine) {
    return 'Kiểm tra lần cuối $agoLine';
  }

  @override
  String get deliveryModeAHelperApp => 'ứng dụng trợ giúp';

  @override
  String deliveryModeWokenByNoWake(Object who) {
    return 'Được $who đánh thức · chưa có lần nào';
  }

  @override
  String deliveryModeWokenByLastWake(Object who, Object agoLine) {
    return 'Được $who đánh thức · lần cuối $agoLine';
  }

  @override
  String get introBudgetTomorrow => 'ngày mai';

  @override
  String introBudgetInDays(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'sau $countString ngày',
    );
    return '$_temp0';
  }

  @override
  String get introBudgetInAnHour => 'sau một giờ';

  @override
  String introBudgetInHours(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'sau $countString giờ',
    );
    return '$_temp0';
  }

  @override
  String get introBudgetInAFewMinutes => 'sau vài phút';

  @override
  String get lockStateUnlockKryfo => 'Mở khóa Kryfo';

  @override
  String get appInvalidUri => 'uri không hợp lệ';

  @override
  String appBundleError(Object e) {
    return 'Lỗi gói: $e';
  }

  @override
  String appAlreadySaved(Object parsed) {
    return 'Đã lưu rồi: $parsed';
  }

  @override
  String appAddedYouCanMessage(Object parsed) {
    return 'Đã thêm $parsed · giờ bạn có thể nhắn tin cho họ';
  }

  @override
  String appPeerImportedV1(Object parsed) {
    return 'Đã nhập peer (v1): $parsed';
  }

  @override
  String appLongWindow(Object line) {
    return '$line khung thời gian dài';
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
      other: '$pString trang',
    );
    String _temp1 = intl.Intl.pluralLogic(
      e,
      locale: localeName,
      other: '$eString sự kiện',
    );
    return '$line ($heldString trên $subsString, kết nối ${c}s, $_temp0, $_temp1)';
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
      other: '$pString trang',
    );
    String _temp1 = intl.Intl.pluralLogic(
      e,
      locale: localeName,
      other: '$eString sự kiện',
    );
    return '$line (kết nối ${c}s, $_temp0, $_temp1)';
  }

  @override
  String appSDropped(Object host, Object secs) {
    return '$host ${secs}s bị ngắt';
  }

  @override
  String appS(Object host, Object secs) {
    return '$host ${secs}s';
  }

  @override
  String get appTorWouldNotWake => 'tor không khởi động được';

  @override
  String get appCheckStarted => 'đã bắt đầu';

  @override
  String get appTorNotReadyIn => 'tor chưa sẵn sàng sau 75s';

  @override
  String get appOk => 'ok';

  @override
  String get appOkNoRelayBegan => 'ok, không relay nào trả lời';

  @override
  String get appOkCapped => 'ok, bị cắt ngang';

  @override
  String appSBy(Object how, int secs, String why) {
    final intl.NumberFormat secsNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String secsString = secsNumberFormat.format(secs);

    String _temp0 = intl.Intl.selectLogic(why, {
      'push': '$how, ${secsString}s, do push',
      'other': '$how, ${secsString}s, do tác vụ nền',
    });
    return '$_temp0';
  }

  @override
  String get appAnAttachmentCouldNot =>
      'Không lưu được một tệp đính kèm trên điện thoại này';

  @override
  String get appGroup2 => 'nhóm';

  @override
  String get appVoiceMessage => 'Tin nhắn thoại';

  @override
  String get appPhoto => 'ảnh';

  @override
  String get appNewRequest => 'Yêu cầu mới';

  @override
  String get appSomeoneYouHaveNot =>
      'Một người mà bạn chưa thêm đã nhắn tin cho bạn';

  @override
  String get appSettingUpYourKeys => 'Đang thiết lập khóa của bạn';

  @override
  String get appOpeningYourChats => 'Đang mở các cuộc trò chuyện';

  @override
  String get appStartingTor => 'đang khởi động Tor';

  @override
  String get appTimedMessagesAreNot =>
      'Tin nhắn tự hủy không được xóa. Hãy khởi động lại Kryfo';

  @override
  String get appVoiceMessage2 => 'tin nhắn thoại';

  @override
  String appYou(Object body) {
    return 'bạn: $body';
  }

  @override
  String get appThisRoomHasAlready => 'Phòng này đã hết hạn';

  @override
  String get appYouAreAlreadyIn => 'Bạn đã ở trong phòng này rồi';

  @override
  String get appCouldNotMakeA => 'không tạo được khóa phòng';

  @override
  String appJoinedButYourHello(Object linkName) {
    return 'Đã vào $linkName, nhưng lời chào của bạn bị giữ lại';
  }

  @override
  String appJoined(Object linkName) {
    return 'Đã vào $linkName';
  }

  @override
  String appJoinedButTheCreator(Object linkName) {
    return 'Đã vào $linkName, nhưng chưa liên lạc được với người tạo phòng';
  }

  @override
  String get appBooting => 'đang khởi động...';

  @override
  String get appSettingUpYourIdentity => 'Đang thiết lập danh tính của bạn...';

  @override
  String get appAddSomeone => 'Thêm người';

  @override
  String get appScanTheirCodeOr =>
      'Quét mã của họ, hoặc dán thứ họ đưa cho bạn: một liên kết, một @tên người dùng, hoặc một liên kết phòng.';

  @override
  String get appScanTheirCode => 'Quét mã của họ';

  @override
  String get appAKryfoLinkA => 'Liên kết Kryfo, liên kết phòng hoặc @wren';

  @override
  String get appAddThem => 'Thêm họ';

  @override
  String get appEveryWayToAdd => 'Mọi cách để thêm người';

  @override
  String get appShowYourCodeSend =>
      'Hiện mã của bạn, gửi liên kết, đăng ký tên người dùng';

  @override
  String get appHelloFromTheOther => 'Xin chào từ phía bên kia';

  @override
  String get appIdentityRestored => 'Đã khôi phục danh tính';

  @override
  String get appIdentityCreated => 'Đã tạo danh tính';

  @override
  String get appStartingTor30s => 'Đang khởi động tor (~30s)...';

  @override
  String get appScanOrImportA => 'hãy quét hoặc nhập một peer trước';

  @override
  String get appEncryptingSending30s => 'Đang mã hóa + gửi (~30s)...';

  @override
  String get appTapStartListeningFirst => 'Hãy chạm “Bắt đầu nghe” trước';

  @override
  String get appYourKryfo => 'Kryfo của bạn';

  @override
  String get appUriCopied => 'Đã sao chép uri';

  @override
  String get appCopyUri => 'Sao chép uri';

  @override
  String get appAddAKryfo => 'Thêm một Kryfo';

  @override
  String get appScanQr => 'Quét QR';

  @override
  String get appPairingCode => 'Mã ghép nối';

  @override
  String get appOrPaste => '- hoặc dán -';

  @override
  String get commonCancel => 'Hủy';

  @override
  String get appImport => 'Nhập';

  @override
  String get appDev => 'Dev';

  @override
  String get appYourKryfo2 => 'Kryfo của bạn:';

  @override
  String get appRestoredFromDisk => 'Đã khôi phục từ bộ nhớ';

  @override
  String get appStartListening => 'Bắt đầu nghe';

  @override
  String get appListening => 'đang nghe';

  @override
  String get appShowMyQr => 'Hiện QR của tôi';

  @override
  String get appImportPeer => 'Nhập peer';

  @override
  String get appPeer => 'peer:';

  @override
  String get appMessageWillBeEncrypted => 'Tin nhắn (sẽ được mã hóa)';

  @override
  String get appEncryptSend => 'Mã hóa + gửi';

  @override
  String appStatus(Object status) {
    return 'trạng thái: $status';
  }

  @override
  String get appSpeedPrivacy => 'Tốc độ & riêng tư →';

  @override
  String get appGettingMessages => 'Nhận tin nhắn →';

  @override
  String get appDisableAppLock => 'Tắt khóa ứng dụng?';

  @override
  String get appThePinWillBe =>
      'Mã PIN sẽ bị gỡ bỏ. Bất kỳ ai có điện thoại của bạn cũng sẽ thấy Kryfo khi họ mở nó.';

  @override
  String get appDisable => 'Tắt';

  @override
  String get appAppLockOn => 'Khóa ứng dụng · bật →';

  @override
  String get appAppLockOff => 'Khóa ứng dụng · tắt →';

  @override
  String get appTorIsOff => 'Tor đang tắt';

  @override
  String get appConnectedRoutedThrough3 =>
      'Đã kết nối · định tuyến qua 3 relay';

  @override
  String get appReadyToSendPublishing =>
      'Sẵn sàng gửi · đang công bố địa chỉ của bạn';

  @override
  String get appReadyToSendFinishing =>
      'Sẵn sàng gửi · đang hoàn tất thiết lập';

  @override
  String appConnecting(Object pct) {
    return 'Đang kết nối · $pct';
  }

  @override
  String get appTor => 'Tor';

  @override
  String get appTorIsOffTurn =>
      'Tor đang tắt. Hãy bật lên để kết nối riêng tư.';

  @override
  String get appTheFirstConnectionTakes =>
      'Lần kết nối đầu tiên mất một hai phút trong lúc tor dựng một tuyến đường riêng tư. Sau đó tuyến này được lưu lại, nên những lần mở Kryfo sau sẽ nhanh hơn nhiều.';

  @override
  String get appRelayAndFastModes =>
      'Chế độ relay và chế độ nhanh bỏ qua tor và nhanh hơn. Chúng nằm trong cài đặt, mục tốc độ & riêng tư, và mỗi chế độ đều nói rõ cái giá phải trả.';

  @override
  String get appViaRelay => 'Qua relay';

  @override
  String get appOffline => 'ngoại tuyến';

  @override
  String get appFast => 'Nhanh';

  @override
  String get appTorOff => 'Tor tắt';

  @override
  String get appTorReady => 'Tor sẵn sàng';

  @override
  String get appConnecting2 => 'đang kết nối';

  @override
  String mediaProgressSendingKeepTheApp(Object v) {
    return 'Đang gửi · $v · hãy để ứng dụng mở';
  }

  @override
  String mediaProgressPausedOfWaitingFor(Object count, Object count2) {
    return 'Tạm dừng · $count trên $count2 · đang chờ phần còn lại';
  }

  @override
  String mediaProgressReceivingMedia(Object v) {
    return 'Đang nhận tệp · $v';
  }

  @override
  String get mediaProgressCancelSending => 'Hủy gửi';

  @override
  String get metaReaderEndsBeforeItShould => 'kết thúc sớm bất thường';

  @override
  String get metaReaderCouldNotBeRead => 'không đọc được';

  @override
  String get metaReaderExifThatCannotBe => 'exif không đọc được';

  @override
  String get metaReaderSamsungTrailer => 'phần đuôi samsung';

  @override
  String metaReaderChunk(Object type) {
    return 'khối $type';
  }

  @override
  String get metaReaderExifFlagSet => 'có cờ exif';

  @override
  String get metaReaderXmpFlagSet => 'có cờ xmp';

  @override
  String metaReaderAppBlock(Object id) {
    return 'khối app $id';
  }

  @override
  String get metaReaderUuidBox => 'hộp uuid';

  @override
  String metaReaderBox(Object printable) {
    return 'hộp $printable';
  }

  @override
  String get metaReaderAttachedData => 'dữ liệu đính kèm';

  @override
  String metaReaderItem(Object printable) {
    return 'mục $printable';
  }

  @override
  String get miuiAutostartAlreadyAllowedToRun => 'Đã được phép chạy nền';

  @override
  String get miuiAutostartLetKryfoRunIn => 'Cho phép Kryfo chạy nền';

  @override
  String get miuiAutostartYourPhonePausesApps =>
      'Điện thoại của bạn tạm dừng các ứng dụng để tiết kiệm pin. Nếu không có ngoại lệ, Kryfo không thể nhận tin nhắn khi đang đóng.';

  @override
  String get commonAllow => 'Cho phép';

  @override
  String get commonSkip => 'Bỏ qua';

  @override
  String get miuiAutostartXiaomiTurnsOffBackground =>
      'Xiaomi mặc định tắt các ứng dụng chạy nền. Không có tự khởi động, Kryfo không thể chuyển tin nhắn khi ứng dụng đang đóng. Ở màn hình tiếp theo, hãy tìm Kryfo trong danh sách và bật công tắc lên.';

  @override
  String get miuiAutostartOpenSettings => 'Mở cài đặt';

  @override
  String get miuiAutostartCouldnTOpenIt =>
      'không mở được. hãy tìm mục tự khởi động trong cài đặt điện thoại';

  @override
  String get notificationsNewEncryptedMessagesFrom =>
      'Tin nhắn mới từ các liên hệ của bạn, được mã hóa';

  @override
  String get notificationsNewMessage => 'tin nhắn mới';

  @override
  String get notificationsNewEncryptedMessagesFromYourContacts =>
      'tin nhắn mới từ các liên hệ của bạn, được mã hóa';

  @override
  String get notificationsNewMessage2 => 'Tin nhắn mới';

  @override
  String get notificationsEncrypted => 'được mã hóa';

  @override
  String get rooms24h => '24 giờ';

  @override
  String roomsD(Object inDays) {
    return '$inDays ngày';
  }

  @override
  String roomsH(Object inHours) {
    return '$inHours giờ';
  }

  @override
  String get rooms24Hours => '24 giờ';

  @override
  String roomsDays(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString ngày',
    );
    return '$_temp0';
  }

  @override
  String get roomsAnHour => 'một giờ';

  @override
  String get roomsAboutAnHour => 'khoảng một giờ';

  @override
  String roomsHours(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString giờ',
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
      other: 'khoảng $countString giờ',
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
      other: '$countString phút',
    );
    return '$_temp0';
  }

  @override
  String get roomsAMinute => 'một phút';

  @override
  String get roomsExpired => 'đã hết hạn';

  @override
  String roomsDH(Object inDays, Object h) {
    return '$inDays ngày $h giờ';
  }

  @override
  String roomsHM(Object inHours, Object m) {
    return '$inHours giờ $m phút';
  }

  @override
  String roomsM(Object inMinutes) {
    return '$inMinutes phút';
  }

  @override
  String get scamShieldLooksLikeAScam => 'Có vẻ là lừa đảo';

  @override
  String scamShieldThisNameMatches(Object shown) {
    return 'Tên này trùng với $shown';
  }

  @override
  String scamShieldNameMatchesYourContact(Object shown) {
    return 'Tên trùng với liên hệ $shown của bạn';
  }

  @override
  String scamShieldSameFaceAsYour(Object shown) {
    return 'cùng khuôn mặt với liên hệ $shown của bạn';
  }

  @override
  String get scamShieldContainsACryptoAddress => 'Có chứa địa chỉ tiền mã hóa';

  @override
  String get scamShieldMentionsMoneyAndUrgency =>
      'Vừa nhắc đến tiền vừa hối thúc';

  @override
  String get scamShieldAsksYouToMove => 'Đề nghị bạn chuyển sang ứng dụng khác';

  @override
  String get scamShieldLinksToALookalike =>
      'Dẫn tới trang nhái một trang web nổi tiếng';

  @override
  String get scamShieldALongOpenerFrom =>
      'Lời mở đầu dài từ một người chưa từng trò chuyện';

  @override
  String get scamShieldAsksForACode =>
      'Hỏi mã, cụm từ khôi phục ví (seed phrase) hoặc tệp khôi phục';

  @override
  String scamShieldAlso(Object shown) {
    return 'Ngoài ra: tên trùng với liên hệ $shown của bạn';
  }

  @override
  String get commonBack => 'Quay lại';

  @override
  String get archivedArchived => 'Đã lưu trữ';

  @override
  String get archivedCount0 => 'không';

  @override
  String get archivedCount1 => 'một';

  @override
  String get archivedCount2 => 'hai';

  @override
  String get archivedCount3 => 'ba';

  @override
  String get archivedCount4 => 'bốn';

  @override
  String get archivedCount5 => 'năm';

  @override
  String get archivedCount6 => 'sáu';

  @override
  String get archivedCount7 => 'bảy';

  @override
  String get archivedCount8 => 'tám';

  @override
  String get archivedCount9 => 'chín';

  @override
  String get archivedCount10 => 'mười';

  @override
  String get archivedChatRestingHereIt =>
      'Cuộc trò chuyện đang nghỉ ở đây. Nó sẽ im lặng cho đến khi người kia nhắn, rồi trở lại đầu danh sách.';

  @override
  String get archivedChatsRestingHere =>
      'Cuộc trò chuyện đang nghỉ ở đây. Chúng sẽ im lặng cho đến khi có người nhắn, rồi trở lại đầu danh sách.';

  @override
  String get archivedNothingArchived => 'Chưa lưu trữ gì';

  @override
  String get archivedArchivedChatsAreStill =>
      'Cuộc trò chuyện đã lưu trữ vẫn được mã hóa đầu cuối';

  @override
  String get archivedUnarchive => 'Bỏ lưu trữ';

  @override
  String get avatarPickerThePeopleYouMessage =>
      'Những người mà bạn nhắn tin cũng thấy khuôn mặt này';

  @override
  String get avatarPickerBackToYourInitial => 'dùng lại chữ cái đầu';

  @override
  String get avatarPickerThatOneIsYours => 'bạn đang dùng cái này';

  @override
  String get avatarPickerPickAFace => 'Chọn khuôn mặt';

  @override
  String get commonSave => 'Lưu';

  @override
  String get backupPassphraseMustBeAt => 'Cụm mật khẩu phải có ít nhất 6 ký tự';

  @override
  String get backupPassphrasesDonTMatch => 'Cụm mật khẩu không khớp';

  @override
  String get backupBackupSavedKeepThe =>
      'Đã lưu bản sao lưu · hãy giữ kỹ cụm mật khẩu';

  @override
  String get backupKryfoBackup => 'Bản sao lưu Kryfo';

  @override
  String get backupYourEncryptedKryfoBackup =>
      'Bản sao lưu Kryfo được mã hóa của bạn. Hãy giữ an toàn cả tệp này VÀ cụm mật khẩu - bạn cần cả hai để khôi phục.';

  @override
  String get backupBackUpKryfo => 'Sao lưu Kryfo';

  @override
  String get backupBackUp => 'Sao lưu';

  @override
  String get backupACopyToKeep =>
      'Một bản để cất giữ. Điện thoại này vẫn hoạt động như bình thường.';

  @override
  String get backupMoveToAnotherDevice => 'Chuyển sang thiết bị khác';

  @override
  String get backupTheFileTakesThis =>
      'Tệp này mang theo danh tính này. Khi tệp được tạo xong, điện thoại này sẽ ngừng: không có gì mới đến đây nữa, và không gì gửi từ đây đến được với ai.';

  @override
  String get backupOneEncryptedFileYour =>
      'Một tệp được mã hóa: danh tính, các liên hệ, mọi tin nhắn, cùng mọi ảnh, tin nhắn thoại và tệp của bạn. Hãy nhập nó trên thiết bị kia bằng cụm mật khẩu. Trước khi làm vậy, bạn vẫn có thể đổi ý và ở lại trên điện thoại này.';

  @override
  String get backupOneEncryptedFileYourIdentityYour =>
      'Một tệp được mã hóa: danh tính, các liên hệ, mọi tin nhắn, cùng mọi ảnh, tin nhắn thoại và tệp đang có trên điện thoại này của bạn. Những gì nói sau hôm nay sẽ không có trong đó, nên hãy tạo bản khác khi cần. Để khôi phục, bạn cần cả tệp lẫn cụm mật khẩu.';

  @override
  String get backupPassphrase => 'Cụm mật khẩu';

  @override
  String get backupConfirmPassphrase => 'Xác nhận cụm mật khẩu';

  @override
  String backupWriting(Object progress) {
    return 'Đang ghi… $progress';
  }

  @override
  String get backupCreating => 'Đang tạo…';

  @override
  String get backupMakeTheFileAnd => 'Tạo tệp và chuyển đi';

  @override
  String get backupCreateBackup => 'Tạo bản sao lưu';

  @override
  String get backupHiddenNotIn => 'Trò chuyện ẩn không có trong tệp này.';

  @override
  String get backupHiddenIncluded =>
      'Trò chuyện ẩn của bạn cũng có trong tệp này.';

  @override
  String get backupMoveHiddenStay =>
      'Trò chuyện ẩn ở lại trên điện thoại này và bị xóa cùng với nó.';

  @override
  String get backupHiddenGone =>
      'Trò chuyện ẩn của bạn đã đóng khi Kryfo khóa. Hãy mở chúng bằng mã PIN trò chuyện ẩn rồi sao lưu từ đó.';

  @override
  String get blockedBlocked => 'Đã chặn';

  @override
  String get blockedNoOneIsBlocked => 'Không ai bị chặn';

  @override
  String get commonUnblock => 'Bỏ chặn';

  @override
  String get bridgesThatWasNotIt => 'Chưa đúng. Đây là một câu đố khác.';

  @override
  String get bridgesGotBridgesSaveTo => 'Đã có cầu nối · lưu lại để dùng';

  @override
  String get bridgesConnected => 'Đã kết nối';

  @override
  String get bridgesNotThroughYetTor => 'Chưa kết nối được. Tor vẫn đang thử';

  @override
  String get bridgesBridges => 'Cầu nối';

  @override
  String get bridgesTorIsBlockedWhere => 'Tor bị chặn ở nơi bạn đang ở?';

  @override
  String get bridgesBridgesDisguiseYourConnection =>
      'Cầu nối ngụy trang kết nối của bạn để nó thoát ra được. Chọn một lối vào, lưu lại, và tor sẽ kết nối lại qua đó.';

  @override
  String get bridgesBridgesOnlyChangeHow =>
      'Cầu nối chỉ thay đổi cách tor kết nối, mà hiện bạn không ở chế độ onion. Những gì bạn đặt ở đây vẫn được lưu, chỉ là không có tác dụng cho đến khi bạn chuyển lại.';

  @override
  String get bridgesFromTheTorProject => 'Từ dự án tor';

  @override
  String get bridgesNoise => 'nhiễu';

  @override
  String get bridgesGood => 'tốt';

  @override
  String get bridgesMakesTorTrafficLook =>
      'Làm lưu lượng tor trông chẳng giống thứ gì cụ thể. Lựa chọn mặc định tốt nhất cho hầu hết các mạng bị chặn. Trả lời một captcha, rồi nhận về vài dòng.';

  @override
  String get bridgesPrivateBridge => 'Cầu nối riêng';

  @override
  String get bridgesALineFromA => 'Dòng từ một người bạn';

  @override
  String get bridgesWhateverTheLineSays => 'Tùy theo dòng đó';

  @override
  String get bridgesDepends => 'tùy';

  @override
  String get bridgesGotABridgeLine =>
      'Có dòng cầu nối từ người bạn tin tưởng, hoặc từ bridges.torproject.org? Dán vào đây. Chỉ nhận dòng obfs4, Kryfo chưa hiểu các loại khác.';

  @override
  String get bridgesPasteFromClipboard => 'Dán từ bộ nhớ tạm';

  @override
  String get bridgesUseBridges => 'Dùng cầu nối';

  @override
  String get bridgesNoLinesYet => 'Chưa có dòng nào';

  @override
  String bridges1LineSaved(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Đã lưu $countString dòng',
    );
    return '$_temp0';
  }

  @override
  String get bridgesRestartingTor => 'Đang khởi động lại tor…';

  @override
  String bridgesFindingABridgeS(Object elapsed) {
    return 'Đang tìm cầu nối… ${elapsed}s';
  }

  @override
  String bridgesStillTryingS(Object elapsed) {
    return 'Vẫn đang thử… ${elapsed}s';
  }

  @override
  String get bridgesApplying => 'Đang áp dụng…';

  @override
  String get bridgesSaveAndReconnect => 'Lưu và kết nối lại';

  @override
  String get bridgesWhatABridgeIs => 'Cầu nối là gì';

  @override
  String get bridgesATorEntryPoint =>
      'Một điểm vào tor chưa ai công bố, được kết nối qua một lớp bọc để kết nối trông không giống tor. Phần còn lại của tuyến đường vẫn là ba chặng như thường lệ.';

  @override
  String get bridgesLooksLike => 'Trông giống';

  @override
  String get bridgesSpeed => 'tốc độ';

  @override
  String get bridgesGetBridges => 'Lấy cầu nối';

  @override
  String get bridgesAskTheTorProject =>
      'Hỏi thẳng dự án tor. Bạn giải một câu đố để bot không thể vét cạn nguồn cầu nối.';

  @override
  String get bridgesTypeWhatYouSee =>
      'Nhập những gì bạn thấy. Chữ thường cũng được.';

  @override
  String get bridgesThisOneRequestDoes =>
      'Riêng yêu cầu này không đi qua tor - nó không thể, vì chính tor đang không hoạt động. Người vận hành mạng bạn đang dùng sẽ thấy bạn liên hệ với dự án tor. Nếu chỉ riêng điều đó đã là vấn đề ở nơi bạn ở, hãy lấy cầu nối ở chỗ khác rồi dán vào bên dưới.';

  @override
  String get bridgesCouldNotDrawThe => 'Không hiển thị được câu đố';

  @override
  String get bridgesAnswer => 'Câu trả lời';

  @override
  String get bridgesAsking => 'Đang hỏi…';

  @override
  String get bridgesRequestBridges => 'Xin cầu nối';

  @override
  String get bridgesDifferentPuzzle => 'Câu đố khác';

  @override
  String get cameraNoCameraOnThis => 'Điện thoại này không có máy ảnh';

  @override
  String get cameraCameraNotAvailable => 'Không dùng được máy ảnh';

  @override
  String get cameraCameraPermissionIsOff =>
      'Quyền máy ảnh đang tắt · chạm để thử lại';

  @override
  String get cameraCouldNotStripThat =>
      'Không làm sạch được ảnh đó nên đã bỏ nó';

  @override
  String get cameraNoPhotoCameOut => 'Không chụp được ảnh';

  @override
  String get cameraCouldNotStartRecording => 'Không bắt đầu quay được';

  @override
  String get cameraTheRecordingWasLost => 'Đoạn quay đã bị mất';

  @override
  String get cameraACopyIsIn => 'Một bản đã vào thư viện ảnh';

  @override
  String get cameraCouldNotSaveA =>
      'Không lưu được bản sao trên điện thoại này';

  @override
  String get cameraTooLongForA => 'Quá dài cho một tin nhắn · tối đa 8 mb';

  @override
  String get cameraNeverSavedToYour => 'Không bao giờ lưu vào thư viện ảnh';

  @override
  String get cameraNoExifNeverSaved =>
      'Không có exif, không bao giờ lưu vào thư viện ảnh';

  @override
  String get cameraRec => 'Quay';

  @override
  String get cameraSwitchCamera => 'đổi máy ảnh';

  @override
  String cameraClipSMb(Object secs, Object mb) {
    return 'Đoạn quay · ${secs}s · $mb mb';
  }

  @override
  String get cameraStopRecording => 'Dừng quay';

  @override
  String get cameraStartRecording => 'Bắt đầu quay';

  @override
  String get cameraTakeAPhoto => 'Chụp ảnh';

  @override
  String get cameraKeepACopy => 'Giữ một bản';

  @override
  String get cameraUseThis => 'Dùng bản này';

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
  String get chatFile => 'TỆP';

  @override
  String get chatYouAreOfflineThis =>
      'bạn đang ngoại tuyến · tin này sẽ tự gửi khi bạn kết nối lại';

  @override
  String get chatStillConnectingToTor =>
      'vẫn đang kết nối với tor · tin sẽ tự gửi đi';

  @override
  String chatS(Object seconds) {
    return '$seconds giây';
  }

  @override
  String chatM(Object seconds) {
    return '$seconds phút';
  }

  @override
  String chatH(Object seconds) {
    return '$seconds giờ';
  }

  @override
  String chatD(Object seconds) {
    return '$seconds ngày';
  }

  @override
  String get chat0s => '0s';

  @override
  String chatHM(Object h, Object m) {
    return '${h}h ${m}p';
  }

  @override
  String chatMS(Object m, Object s) {
    return '${m}p ${s}s';
  }

  @override
  String chatS2(Object s) {
    return '${s}s';
  }

  @override
  String get chatNewMessages => 'Tin nhắn mới';

  @override
  String get chatUnsave => 'Bỏ lưu';

  @override
  String get chatForward => 'Chuyển tiếp';

  @override
  String get commonShare => 'Chia sẻ';

  @override
  String get commonCopied => 'Đã sao chép';

  @override
  String get commonCopy => 'Sao chép';

  @override
  String get chatUnpin => 'Bỏ ghim';

  @override
  String get chatPin => 'Ghim';

  @override
  String get chatStopSending => 'Dừng gửi';

  @override
  String get chatUnsend => 'Thu hồi';

  @override
  String get commonEdit => 'Sửa';

  @override
  String get chatYou => 'Bạn';

  @override
  String get chatUnsendMessage => 'Thu hồi tin nhắn';

  @override
  String get chatItDisappearsWithNo =>
      'Tin nhắn biến mất không để lại dấu vết. Không thể hoàn tác việc này.';

  @override
  String chatThisChatHasPins(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Cuộc trò chuyện này đã có $countString tin nhắn được ghim',
    );
    return '$_temp0';
  }

  @override
  String get chatUnpinThisMessage => 'Bỏ ghim tin nhắn này?';

  @override
  String get chatPinThisMessage => 'Ghim tin nhắn này?';

  @override
  String get chatItLeavesThePinned =>
      'Tin nhắn sẽ rời khỏi danh sách ghim ở cả hai phía.';

  @override
  String get chatItGoesUnderThe =>
      'Tin nhắn sẽ nằm ở mục ghim trên đầu cuộc trò chuyện, ở cả hai phía.';

  @override
  String get chatPinIt => 'Ghim';

  @override
  String get chatNotNow => 'Để sau';

  @override
  String get chatEditMessage => 'Sửa tin nhắn';

  @override
  String get chat30Seconds => '30 giây';

  @override
  String get chat1Minute => '1 phút';

  @override
  String get chat5Minutes => '5 phút';

  @override
  String get chat1Hour => '1 giờ';

  @override
  String get chat24Hours => '24 giờ';

  @override
  String get chatGhostTimer => 'Tin nhắn tự hủy';

  @override
  String get chatHowLongBeforeSent => 'Tin nhắn đã gửi sẽ tự hủy sau bao lâu?';

  @override
  String get chatCamera => 'Máy ảnh';

  @override
  String get chatNoExifNeverSaved =>
      'Không có exif, không bao giờ lưu vào thư viện ảnh';

  @override
  String get chatGallery => 'Thư viện';

  @override
  String get chatVideo => 'Video';

  @override
  String get chatGifFromPhone => 'Gif từ điện thoại';

  @override
  String get chatFile2 => 'Tệp';

  @override
  String get chatAFewSeconds => 'Vài giây';

  @override
  String get chatUnderAMinute => 'Dưới một phút';

  @override
  String chatRoughlyMin(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Khoảng $countString phút',
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
  String get chatSendThis => 'Gửi tệp này?';

  @override
  String chatOverTor(Object humanBytes, Object wireEstimate) {
    return '$humanBytes · $wireEstimate qua tor';
  }

  @override
  String get chatBigFilesGoOut =>
      'Tệp lớn được gửi đi thành từng mảnh nhỏ được mã hóa, nên sẽ mất một lúc. Cứ để ứng dụng mở là việc gửi sẽ tiếp tục.';

  @override
  String get chatSendIt => 'Gửi';

  @override
  String get chatCouldNotReadThat => 'Không đọc được tệp đó';

  @override
  String get chatFileTooBig8 => 'Tệp quá lớn · tối đa 8 mb';

  @override
  String get chatCouldNotCleanThat => 'Không làm sạch được video đó';

  @override
  String get chatCouldNotCleanThatPictureSend =>
      'Không làm sạch được hình đó · hãy gửi dưới dạng ảnh';

  @override
  String get chatGifTooBig8 => 'Gif quá lớn · tối đa 8 mb';

  @override
  String get chatCouldNotCleanThatGif => 'Không làm sạch được gif đó';

  @override
  String get chatTorIsNotUp => 'Tor chưa sẵn sàng · gửi không kèm xem trước';

  @override
  String get chatCouldnTReachIt =>
      'Không truy cập được · gửi không kèm xem trước';

  @override
  String get chatNoTitleCameBack =>
      'Không lấy được tiêu đề · gửi không kèm xem trước';

  @override
  String get chatCouldnTFetchIt => 'Không tải được · gửi không kèm xem trước';

  @override
  String get chatNoSignalSessionRe =>
      'Không có phiên Signal - hãy ghép nối lại';

  @override
  String get chatMessageUnavailable => 'Tin nhắn không khả dụng';

  @override
  String get chatYou2 => 'bạn';

  @override
  String get chatThem => 'họ';

  @override
  String get chatVoiceMessage => 'tin nhắn thoại';

  @override
  String get chatQuotedPhoto => 'ảnh';

  @override
  String get chatViewContact => 'Xem liên hệ';

  @override
  String get chatSharedPhotos => 'Ảnh đã chia sẻ';

  @override
  String chatSharedPhotoCount(int count, Object title) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString ảnh',
    );
    return '$_temp0 · $title';
  }

  @override
  String get chatUnmuteNotifications => 'Bật lại thông báo';

  @override
  String get chatMuteNotifications => 'Tắt thông báo';

  @override
  String get chatArchiveChat => 'Lưu trữ trò chuyện';

  @override
  String get chatWallpaper => 'Hình nền';

  @override
  String get chatClearConversation => 'Xóa hết tin nhắn';

  @override
  String get chatNoteOnThisContact => 'Ghi chú về liên hệ này';

  @override
  String get chatPinToTop => 'Ghim lên đầu';

  @override
  String get chatBlockContact => 'Chặn liên hệ';

  @override
  String get chatUnpinned => 'Đã bỏ ghim';

  @override
  String get chatPinnedToTop => 'Đã ghim lên đầu';

  @override
  String get chatJustForYouNever =>
      'Chỉ dành cho bạn. Không bao giờ được gửi, không bao giờ rời khỏi điện thoại này.';

  @override
  String get chatAQuietReminder => 'Một lời nhắc nhỏ…';

  @override
  String get chatNoteSaved => 'Đã lưu ghi chú';

  @override
  String get chatClearThisConversation => 'Xóa hết tin nhắn ở đây?';

  @override
  String get chatEveryMessageHereIs =>
      'Mọi tin nhắn ở đây sẽ bị xóa khỏi điện thoại này. Việc này chỉ xóa bản của bạn - không động đến thiết bị của họ.';

  @override
  String get chatClear => 'Xóa hết';

  @override
  String get chatBlockThisContact => 'Chặn liên hệ này?';

  @override
  String get chatTheirMessagesStopArriving =>
      'Tin nhắn của họ sẽ không đến nữa và họ biến mất khỏi danh sách trò chuyện của bạn. Họ không bao giờ được báo. Bạn có thể bỏ chặn bất cứ lúc nào trong cài đặt.';

  @override
  String get commonBlock => 'Chặn';

  @override
  String get chatSaved => 'Đã lưu';

  @override
  String get chatRemovedFromSaved => 'Đã bỏ khỏi mục Đã lưu';

  @override
  String get chatForwardTo => 'Chuyển tiếp tới';

  @override
  String get chatNoContactsToForward => 'Không có liên hệ nào để chuyển tiếp';

  @override
  String get chatToday => 'hôm nay';

  @override
  String get chatYesterday => 'hôm qua';

  @override
  String get chatThisMessageCanT => 'Không thể hiển thị tin nhắn này';

  @override
  String get chatJumpToTheNewest => 'Đến tin mới nhất';

  @override
  String get chatBuildingAPrivateRoute =>
      'Đang dựng tuyến đường riêng tư · lần kết nối đầu tiên chậm, các lần sau sẽ nhanh. Mọi thứ bạn gửi lúc này sẽ vào hàng chờ và tự được gửi đi.';

  @override
  String get chatLooksSafeNothingSuspicious =>
      'Có vẻ an toàn · tin nhắn đầu tiên của họ không có gì đáng ngờ';

  @override
  String get chatTheNextPhotoYou =>
      'Ảnh tiếp theo bạn gửi sẽ mở ở chế độ bảo vệ · họ không thể chụp màn hình ảnh đó';

  @override
  String get chatPhotoProtectionOff => 'Đã tắt bảo vệ ảnh';

  @override
  String get chatAcceptToReplyThey =>
      'Chấp nhận để trả lời - trước khi bạn làm vậy, họ chỉ gửi được thêm một tin nữa.';

  @override
  String chatIntroducedYouAcceptTo(Object introducer) {
    return '$introducer đã giới thiệu bạn. Chấp nhận để trả lời.';
  }

  @override
  String chatIntroducedYouSayHello(Object vouchNames) {
    return '$vouchNames đã giới thiệu hai bạn với nhau. Hãy chào đi - người kia cũng đã nhận được thẻ của bạn.';
  }

  @override
  String get chatIntroduceTo => 'Giới thiệu với...';

  @override
  String get chatAcceptThemFirst => 'Hãy chấp nhận họ trước';

  @override
  String get chatMessageRequest => 'Yêu cầu nhắn tin';

  @override
  String get chatTheyNeedToAccept =>
      'Họ cần chấp nhận thì bạn mới trò chuyện tiếp được.';

  @override
  String get chatWaitingForThemTo => 'Đang chờ họ chấp nhận yêu cầu của bạn';

  @override
  String get chatYouBlockedThisContact => 'Bạn đã chặn liên hệ này';

  @override
  String get chatSupporter => 'Người ủng hộ';

  @override
  String get chatEncryptedViaRelay => 'Được mã hóa · qua relay';

  @override
  String get chatEncryptedDirect => 'Được mã hóa · trực tiếp';

  @override
  String get chatEncryptedOverTor => 'Được mã hóa · qua tor';

  @override
  String get chatSearchThisChat => 'Tìm trong cuộc trò chuyện';

  @override
  String get chatContactOptions => 'Tùy chọn liên hệ';

  @override
  String get commonClose => 'Đóng';

  @override
  String get chatFindInConversation => 'Tìm trong cuộc trò chuyện';

  @override
  String get chatNoMatches => 'Không có kết quả';

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
      other: '*$posString* trên $countString kết quả',
      one: '*$posString* trên $countString kết quả',
    );
    return '$_temp0';
  }

  @override
  String get chatPreviousMatch => 'Kết quả trước';

  @override
  String get chatNextMatch => 'Kết quả tiếp';

  @override
  String get chatPhotoUnavailable => 'Ảnh không khả dụng';

  @override
  String get chatDelivered => 'Đã nhận';

  @override
  String get chatEdited => 'Đã sửa';

  @override
  String get chatWaitingForThemToComeOnline =>
      'Đang chờ họ trực tuyến hoặc thêm lại bạn';

  @override
  String get chatFailedTapToRetry => 'Thất bại · chạm để thử lại';

  @override
  String get chatReplyingTo => 'Đang trả lời họ';

  @override
  String get chatReplyingToYourself => 'Đang trả lời chính bạn';

  @override
  String get chatReply => 'Trả lời';

  @override
  String get chatSayHi => 'Gửi lời chào.';

  @override
  String get chatJustTheTwoOf => 'Chỉ hai bạn với nhau, được mã hóa đầu cuối.';

  @override
  String get chatMicPermissionNeeded => 'Cần quyền micrô';

  @override
  String get chatTheMicWouldNot => 'Micrô không khởi động được. Hãy thử lại';

  @override
  String get chatReleaseToCancel => 'Thả tay để hủy';

  @override
  String get chatVoiceHiddenSlideTo => 'Giọng đã được che · trượt để hủy';

  @override
  String get chatSlideToCancel => 'Trượt để hủy';

  @override
  String get chatGhostMode => 'Tin nhắn tự hủy';

  @override
  String chatMessagesBurnAfter(Object humanBurn) {
    return 'tự hủy sau $humanBurn';
  }

  @override
  String get chatTimedMessages => 'Tin nhắn tự hủy';

  @override
  String get chatOpenTheCamera => 'Mở máy ảnh';

  @override
  String get chatAttachAPhoto => 'Đính kèm ảnh';

  @override
  String get chatMessage => 'Tin nhắn';

  @override
  String get chatDisguiseVoice => 'Đổi giọng';

  @override
  String get commonSend => 'Gửi';

  @override
  String get chatNoPhotosInThis => 'Chưa có ảnh nào trong cuộc trò chuyện này';

  @override
  String get chatSendPhoto => 'Gửi ảnh';

  @override
  String get chatAddACaption => 'Thêm chú thích…';

  @override
  String get chatSecurityCodeChanged => 'Mã bảo mật đã thay đổi';

  @override
  String chatMayHaveReinstalledOr(Object peerName) {
    return '$peerName có thể đã cài lại ứng dụng, hoặc cũng có thể có người đang mạo danh họ. Hãy so sánh số an toàn để chắc chắn.';
  }

  @override
  String get chatOk => 'OK';

  @override
  String get chatVerify => 'Xác minh';

  @override
  String get cleanKryfoCanTClean => 'Kryfo chưa làm sạch được loại tệp này.';

  @override
  String get cleanThisIsAMotion => 'Đây là ảnh chuyển động.';

  @override
  String get cleanThisPictureIsToo => 'Ảnh này quá lớn để làm sạch ở đây.';

  @override
  String get cleanThisFileIsDamaged => 'Tệp này bị hỏng hoặc bị cắt cụt.';

  @override
  String get cleanKryfoCouldNotMake => 'Kryfo không làm sạch được tệp này.';

  @override
  String get cleanNotEnoughRoomOn => 'Điện thoại không đủ dung lượng.';

  @override
  String get cleanKryfoCouldNotOpen => 'Kryfo không mở được tệp đó.';

  @override
  String get cleanItCleansJpegPng =>
      'Kryfo làm sạch được JPEG, PNG, WebP, HEIC, AVIF, GIF, MP4 và MOV. Không có gì bị thay đổi.';

  @override
  String get cleanItHoldsAShort =>
      'Ảnh này chứa một đoạn video ngắn bên cạnh hình, và Kryfo chưa làm sạch được phần đó. Hãy tắt chế độ chuyển động trong máy ảnh, hoặc gửi ảnh chụp màn hình của nó.';

  @override
  String get cleanPicturesOver64Mb =>
      'Ảnh trên 64 MB không được làm sạch trên điện thoại. Không có gì bị thay đổi.';

  @override
  String get cleanKryfoCouldNotRead =>
      'Kryfo không đọc được tệp đến cuối, nên sẽ không coi là đã sạch. Không có bản sao nào được tạo.';

  @override
  String get cleanSomethingInsideIsOf =>
      'Bên trong có thứ mà Kryfo không biết cách gỡ bỏ, nên không có bản sao nào được tạo.';

  @override
  String get cleanFreeSomeSpaceAnd =>
      'Hãy giải phóng bớt dung lượng rồi thử lại. Không có gì bị thay đổi.';

  @override
  String get cleanTheAppThatShared =>
      'Ứng dụng đã chia sẻ tệp có thể đã lấy lại nó. Hãy thử chia sẻ lại.';

  @override
  String get cleanNoAppOnThis =>
      'Không ứng dụng nào trên điện thoại này nhận tệp.';

  @override
  String get cleanCouldNotSaveIt =>
      'Không lưu được. Hãy kiểm tra xem điện thoại còn dung lượng không.';

  @override
  String get cleanTheOriginalIsGone => 'Bản gốc đã bị xóa. Bản sạch vẫn còn.';

  @override
  String get cleanAndroidWouldNotDelete =>
      'Android không chịu xóa nó. Hãy tự xóa nó khỏi thư viện ảnh.';

  @override
  String get cleanCleanCopy => 'Bản sạch';

  @override
  String get cleanShareCleanCopy => 'Chia sẻ bản sạch';

  @override
  String get cleanSaveToGallery => 'Lưu vào thư viện';

  @override
  String get commonStop => 'Dừng';

  @override
  String get cleanReadingTheFile => 'Đang đọc tệp';

  @override
  String get cleanCleaning => 'Đang làm sạch';

  @override
  String cleanOf(Object prettySize, Object prettySize2) {
    return '$prettySize trên $prettySize2';
  }

  @override
  String get cleanEverythingStaysOnThis =>
      'Mọi thứ đều ở lại trên điện thoại này.';

  @override
  String get cleanAlreadyClean => 'Đã sạch sẵn.';

  @override
  String get cleanClean => 'Đã sạch.';

  @override
  String get cleanThereWasNothingTo => 'Không có gì để tìm.';

  @override
  String get cleanNothingLeftToFind => 'Không còn gì để tìm.';

  @override
  String get cleanSameVideoSameQuality => 'Vẫn video đó, vẫn chất lượng đó';

  @override
  String get cleanSamePictureSameQuality => 'Vẫn ảnh đó, vẫn chất lượng đó';

  @override
  String cleanRemoved(Object label) {
    return '$label, đã gỡ bỏ';
  }

  @override
  String get cleanRemoved2 => 'ĐÃ GỠ BỎ';

  @override
  String get cleanWithTheLocationInside =>
      'kèm vị trí bên trong. Ai có được bản đó sẽ biết con phố của bạn.';

  @override
  String get cleanWithEverythingItKnew =>
      'kèm mọi thứ nó biết vẫn còn bên trong.';

  @override
  String get cleanOriginal => 'BẢN GỐC';

  @override
  String get cleanClean2 => 'BẢN SẠCH';

  @override
  String get cleanSavedToYourGallery => 'Đã lưu vào thư viện ảnh.';

  @override
  String cleanTheOriginalIsStill(Object what) {
    return 'Bản gốc cũng vẫn còn đó, $what';
  }

  @override
  String cleanTheOriginalIsStillWhereIt(Object what) {
    return 'Bản gốc vẫn ở chỗ cũ, $what Kryfo không thể xóa nó từ đây, nên hãy xóa nó trong ứng dụng gốc.';
  }

  @override
  String get cleanDeleteTheOriginal => 'Xóa bản gốc';

  @override
  String get cleanKeepBoth => 'Giữ cả hai';

  @override
  String get commonDone => 'Xong';

  @override
  String get cleanAndroidWillAskYou => 'ANDROID SẼ HỎI BẠN XÁC NHẬN';

  @override
  String get contactYourNameForThem => 'Biệt danh bạn đặt cho họ';

  @override
  String get contactStaysOnThisPhone =>
      'Ở lại trên điện thoại này. Họ không bao giờ thấy nó.';

  @override
  String get contactClear => 'Xóa';

  @override
  String get contactMessage => 'Nhắn tin';

  @override
  String get contactKeysVerified => 'Đã xác minh khóa';

  @override
  String get contactVerifyKeys => 'Xác minh khóa';

  @override
  String get contactVouches => 'Bảo chứng';

  @override
  String get contactUnmute => 'Bật tiếng';

  @override
  String get contactMute => 'Tắt tiếng';

  @override
  String get contactUnpin => 'Bỏ ghim';

  @override
  String get contactPinToTop => 'Ghim lên đầu';

  @override
  String get contactArchive => 'Lưu trữ';

  @override
  String get contactOutOfTheList => 'Ẩn khỏi danh sách cho đến khi họ nhắn lại';

  @override
  String contactBlock(Object name) {
    return 'Chặn $name?';
  }

  @override
  String get contactTheirMessagesStopArriving =>
      'Tin nhắn của họ sẽ không đến nữa. Họ không được báo.';

  @override
  String get contactDeleteChat => 'Xóa cuộc trò chuyện';

  @override
  String get contactMessagesAndContactGone =>
      'Tin nhắn và liên hệ, bị xóa khỏi điện thoại này';

  @override
  String get contactDeleteThisChat => 'Xóa cuộc trò chuyện này?';

  @override
  String get contactEveryMessageAndThe =>
      'Mọi tin nhắn và liên hệ này sẽ bị xóa khỏi điện thoại này. Không có gì được gửi cho họ.';

  @override
  String get commonDelete => 'Xóa';

  @override
  String get contactDeleted => 'Đã xóa';

  @override
  String get contactToday => 'hôm nay';

  @override
  String contactD(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ngày',
    );
    return '$_temp0';
  }

  @override
  String contactMo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tháng',
    );
    return '$_temp0';
  }

  @override
  String contactY(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count năm',
    );
    return '$_temp0';
  }

  @override
  String get contactVerified => 'Đã xác minh';

  @override
  String get contactChatting => 'Đã trò chuyện';

  @override
  String get contactNothingSharedYet => 'chưa chia sẻ gì';

  @override
  String contactSharedMedia(Object count) {
    return 'tệp đã chia sẻ · $count';
  }

  @override
  String get donateBitcoin => 'Bitcoin';

  @override
  String get donateText => '₿';

  @override
  String get donateBadgeUnlocks => 'mở khóa huy hiệu';

  @override
  String get donateMonero => 'Monero';

  @override
  String get donateManualNoBadge => 'thủ công · không huy hiệu';

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
          'Đã thấy khoản thanh toán bitcoin trước đó của bạn · đã mở khóa huy hiệu người ủng hộ',
      'patron':
          'Đã thấy khoản thanh toán bitcoin trước đó của bạn · đã mở khóa huy hiệu nhà bảo trợ',
      'guardian':
          'Đã thấy khoản thanh toán bitcoin trước đó của bạn · đã mở khóa huy hiệu người bảo hộ',
      'other':
          'Đã thấy khoản thanh toán bitcoin trước đó của bạn · đã mở khóa huy hiệu người ủng hộ',
    });
    return '$_temp0';
  }

  @override
  String get donateSupport => 'Ủng hộ';

  @override
  String get donateKeepKryfo => 'Giữ Kryfo *độc lập*';

  @override
  String get donateNoAdsNoInvestors =>
      'Không quảng cáo, không nhà đầu tư, không bán thứ gì. Kryfo sống nhờ những gì người ủng hộ đóng góp.';

  @override
  String get donateBackItAnonymouslyBadge =>
      'Ủng hộ ẩn danh. Huy hiệu tùy chọn.\n*Quyền riêng tư không bao giờ cần trả phí.*';

  @override
  String donateAddressCheckItAgainst(Object coinName) {
    return 'Địa chỉ $coinName · hãy đối chiếu với ví của bạn';
  }

  @override
  String get donateAddressCopiedClearsIn =>
      'Đã sao chép địa chỉ · tự xóa sau 60s';

  @override
  String get donateCopyAddress => 'Sao chép địa chỉ';

  @override
  String get donateBitcoinIsVerifiedBy =>
      'Bitcoin được xác minh bằng node của chính chúng tôi, nên huy hiệu của bạn tự mở khóa ngay khi khoản thanh toán đến.';

  @override
  String get donateWeCanTVerify =>
      'Chúng tôi không thể xác minh chuỗi này mà không hỏi một dịch vụ bên ngoài về bạn, nên chúng tôi không làm. Cứ gửi nếu bạn muốn. Việc này sẽ không mở khóa huy hiệu.';

  @override
  String get donateBitcoinBadgesNeedOnion =>
      'Huy hiệu bitcoin cần chế độ onion';

  @override
  String get donateSwitchToOnion => 'Chuyển sang onion';

  @override
  String get donatePayWithBitcoin => 'Trả bằng bitcoin  →';

  @override
  String get donateBadgesStartAt20 => 'Huy hiệu từ \$20';

  @override
  String get donateReachingThePaymentService =>
      'Đang kết nối tới dịch vụ thanh toán qua tor…';

  @override
  String get donateThisCanTakeUp => 'Có thể mất tới một phút';

  @override
  String donateSThisCanTake(Object waited) {
    return '${waited}s · có thể mất tới một phút';
  }

  @override
  String get donateUseTheAddressInstead => 'Dùng địa chỉ thay thế';

  @override
  String get donateThePaymentServiceIs =>
      'Dịch vụ thanh toán là một địa chỉ onion, và chỉ chế độ onion mới tới được. Không có gì được gửi đi.';

  @override
  String get donateTorWasSlowTo =>
      'Tor kết nối tới dịch vụ thanh toán quá chậm. Bạn có thể ủng hộ qua địa chỉ bên dưới - chỉ là huy hiệu sẽ không tự mở khóa. Hãy thử lại sau để nhận huy hiệu.';

  @override
  String get donateThePaymentServiceIsHavingTrouble =>
      'Dịch vụ thanh toán đang gặp trục trặc. Bạn vẫn có thể ủng hộ qua địa chỉ bên dưới - chỉ là huy hiệu sẽ không tự mở khóa. Hãy thử lại sau để nhận huy hiệu.';

  @override
  String get commonTryAgain => 'Thử lại';

  @override
  String donateBtc(Object btc) {
    return '$btc BTC';
  }

  @override
  String donateSendExactlyThisAmount(Object fmtLeft) {
    return 'Gửi đúng số tiền này · hết hạn sau $fmtLeft';
  }

  @override
  String get donateOpenWallet => 'Mở ví';

  @override
  String get donateThisScreenUpdatesItself =>
      'Màn hình này tự cập nhật ngay khi thấy khoản thanh toán của bạn.\nHãy để mở - không có gì được lưu, không có gì nhận diện được bạn.';

  @override
  String get donateWatchingTheChainFor =>
      'Đang theo dõi chuỗi để tìm khoản thanh toán của bạn';

  @override
  String get donateThisInvoiceExpired => 'Hóa đơn này đã hết hạn';

  @override
  String get donateInvoicesTimeOutIf =>
      'Hóa đơn có thời hạn. Nếu bạn đã gửi thanh toán, hãy để màn hình này mở: chúng tôi sẽ hỏi lại dịch vụ mỗi phút trong một lúc, và cả lần tới khi bạn mở mục ủng hộ. Bạn có thể tạo hóa đơn mới bất cứ lúc nào.';

  @override
  String get donateNewInvoice => 'Hóa đơn mới';

  @override
  String get donateIPaidCheckAgain => 'Tôi đã trả, kiểm tra lại';

  @override
  String get donatePaymentConfirmed => 'Đã xác nhận thanh toán';

  @override
  String get donateThankYouForKeeping =>
      'Cảm ơn bạn đã giúp Kryfo giữ được sự độc lập.';

  @override
  String donateVerifiedOnChainYou(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter':
          'đã xác minh trên chuỗi - giờ bạn là người ủng hộ. Không ai có thể lấy đi điều đó.',
      'patron':
          'đã xác minh trên chuỗi - giờ bạn là nhà bảo trợ. Không ai có thể lấy đi điều đó.',
      'guardian':
          'đã xác minh trên chuỗi - giờ bạn là người bảo hộ. Không ai có thể lấy đi điều đó.',
      'other':
          'đã xác minh trên chuỗi - giờ bạn là người ủng hộ. Không ai có thể lấy đi điều đó.',
    });
    return '$_temp0';
  }

  @override
  String get donateWearMyBadge => 'Đeo huy hiệu của tôi';

  @override
  String get donateJustGladToHelp => 'Vui vì giúp được';

  @override
  String get gettingMessagesGettingMessages => 'Nhận tin nhắn';

  @override
  String get gettingMessagesHowNewMessagesReach =>
      'Cách tin nhắn mới đến điện thoại này. Bạn có thể đổi bất cứ lúc nào.';

  @override
  String get gettingMessagesAlwaysOn => 'Luôn bật';

  @override
  String get gettingMessagesMostPrivate => 'riêng tư nhất';

  @override
  String get gettingMessagesMessagesArriveInstantlyNothing =>
      'Tin nhắn đến ngay lập tức. Không có gì rời khỏi Tor. Tốn pin nhất.';

  @override
  String get gettingMessagesCheckIns => 'Kiểm tra định kỳ';

  @override
  String get gettingMessagesLightest => 'nhẹ nhất';

  @override
  String get gettingMessagesKryfoLooksForMessages =>
      'Kryfo tìm tin nhắn mới mỗi 15 phút. Tiết kiệm pin, nhưng tin nhắn có thể đến muộn.';

  @override
  String get gettingMessagesOnTheLockScreen => 'Trên màn hình khóa';

  @override
  String get gettingMessagesHideMessagePreview => 'Ẩn xem trước tin nhắn';

  @override
  String get gettingMessagesAGenericAlertWith =>
      'Một thông báo chung, không có người gửi và không có nội dung tin nhắn';

  @override
  String get gettingMessagesShowsMessageTextIn =>
      'Hiện nội dung tin nhắn trong thông báo, kể cả khi Kryfo đang khóa.';

  @override
  String get gettingMessagesWhenThePhoneSits =>
      'Khi điện thoại nằm yên, Android sẽ giãn các lần kiểm tra thưa hơn. Dòng phía trên cho thấy lần kiểm tra thực tế gần nhất. Khi Kryfo đang mở, ứng dụng luôn giữ kết nối.';

  @override
  String get groupChatJumpToTheNewest => 'Đến tin mới nhất';

  @override
  String get groupChatBlockedEverywhere => 'Đã chặn ở mọi nơi';

  @override
  String get groupChatYou => 'bạn';

  @override
  String get groupChatVoiceMessage => 'tin nhắn thoại';

  @override
  String get groupChatQuotedPhoto => 'ảnh';

  @override
  String get groupChatMessageUnavailable => 'Tin nhắn không khả dụng';

  @override
  String get groupChatTorIsNotUp =>
      'Tor chưa sẵn sàng · gửi không kèm xem trước';

  @override
  String get groupChatCouldnTReachIt =>
      'không truy cập được · gửi không kèm xem trước';

  @override
  String get groupChatNoTitleCameBack =>
      'Không lấy được tiêu đề · gửi không kèm xem trước';

  @override
  String get groupChatCouldnTFetchIt =>
      'không tải được · gửi không kèm xem trước';

  @override
  String get groupChatCamera => 'Máy ảnh';

  @override
  String get groupChatGallery => 'Thư viện';

  @override
  String get groupChatVideo => 'Video';

  @override
  String get groupChatGifFromPhone => 'Gif từ điện thoại';

  @override
  String get groupChatFile => 'Tệp';

  @override
  String get groupChatCouldNotReadThat => 'Không đọc được tệp đó';

  @override
  String get groupChatGifTooBig8 => 'Gif quá lớn · tối đa 8 mb';

  @override
  String get groupChatCouldNotCleanThat => 'Không làm sạch được gif đó';

  @override
  String get groupChatFileTooBig8 => 'Tệp quá lớn · tối đa 8 mb';

  @override
  String get groupChatCouldNotCleanThatVideo => 'Không làm sạch được video đó';

  @override
  String get groupChatCouldNotCleanThatPictureSend =>
      'Không làm sạch được hình đó · hãy gửi dưới dạng ảnh';

  @override
  String get groupChat30Seconds => '30 giây';

  @override
  String get groupChat1Minute => '1 phút';

  @override
  String get groupChat5Minutes => '5 phút';

  @override
  String get groupChat1Hour => '1 giờ';

  @override
  String get groupChat24Hours => '24 giờ';

  @override
  String get groupChatBurnTimer => 'Tin nhắn tự hủy';

  @override
  String get groupChatNewMessagesDisappearAfter =>
      'Tin nhắn mới sẽ biến mất sau khoảng thời gian này';

  @override
  String get groupChatToday => 'hôm nay';

  @override
  String get groupChatYesterday => 'hôm qua';

  @override
  String get groupChatYou2 => 'Bạn';

  @override
  String groupChatThisChatHasPins(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Cuộc trò chuyện này đã có $countString tin nhắn được ghim',
    );
    return '$_temp0';
  }

  @override
  String get groupChatUnpinThisMessage => 'Bỏ ghim tin nhắn này?';

  @override
  String get groupChatPinThisMessage => 'Ghim tin nhắn này?';

  @override
  String get groupChatItLeavesThePinned =>
      'Tin nhắn sẽ rời khỏi danh sách ghim với mọi người ở đây.';

  @override
  String get groupChatItGoesUnderThe =>
      'Tin nhắn sẽ nằm ở mục ghim trên đầu cuộc trò chuyện, với mọi người ở đây.';

  @override
  String get groupChatUnpin => 'Bỏ ghim';

  @override
  String get groupChatPinIt => 'Ghim';

  @override
  String get groupChatNotNow => 'Để sau';

  @override
  String get groupChatSaved => 'Đã lưu';

  @override
  String get groupChatRemovedFromSaved => 'Đã bỏ khỏi mục Đã lưu';

  @override
  String get groupChatForwardTo => 'Chuyển tiếp tới';

  @override
  String get groupChatNoContactsToForward =>
      'Không có liên hệ nào để chuyển tiếp';

  @override
  String get groupChatEditMessage => 'Sửa tin nhắn';

  @override
  String get groupChatUnsendMessage => 'Thu hồi tin nhắn';

  @override
  String get groupChatItDisappearsWithNo =>
      'Tin nhắn biến mất không để lại dấu vết. Không thể hoàn tác việc này.';

  @override
  String get groupChatUnsend => 'Thu hồi';

  @override
  String groupChatThisRoomAndEverything(Object expiryWords) {
    return 'Phòng này và mọi thứ trong đó sẽ biến mất sau $expiryWords';
  }

  @override
  String groupChatGhostModeOnBurns(Object fmtBurn) {
    return 'Tin nhắn tự hủy · tự hủy sau $fmtBurn';
  }

  @override
  String get groupChatGroupCreatedSayHi => 'Đã tạo nhóm. Gửi lời chào.';

  @override
  String get groupChatNoMessagesYet => 'Chưa có tin nhắn nào.';

  @override
  String get groupChatThisMessageCanT => 'Không thể hiển thị tin nhắn này';

  @override
  String groupChatS(Object s) {
    return '$s giây';
  }

  @override
  String groupChatM(Object s) {
    return '$s phút';
  }

  @override
  String groupChatH(Object s) {
    return '$s giờ';
  }

  @override
  String groupChatD(Object s) {
    return '$s ngày';
  }

  @override
  String groupChatHere(int count, Object time) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$time · $countString người ở đây',
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
      other: '$countString thành viên',
    );
    return '$_temp0';
  }

  @override
  String get groupChatSearchThisChat => 'Tìm trong cuộc trò chuyện';

  @override
  String groupChatReplyingTo(Object name) {
    return 'Đang trả lời $name';
  }

  @override
  String get groupChatReplyingToYou => 'Đang trả lời bạn';

  @override
  String get groupChatTimedMessages => 'Tin nhắn tự hủy';

  @override
  String get groupChatOpenTheCamera => 'Mở máy ảnh';

  @override
  String get groupChatAttachAPhoto => 'Đính kèm ảnh';

  @override
  String get groupChatMessage => 'Tin nhắn';

  @override
  String get groupChatDisguiseVoice => 'Đổi giọng';

  @override
  String get groupChatSupporter => 'Người ủng hộ';

  @override
  String get groupChatEdited => 'Đã sửa';

  @override
  String get groupChatTapToRetry => '! chạm để thử lại';

  @override
  String get groupChat0s => '0 giây';

  @override
  String get groupChatReply => 'Trả lời';

  @override
  String get groupChatPin => 'Ghim';

  @override
  String get groupChatUnsave => 'Bỏ lưu';

  @override
  String get groupChatForward => 'Chuyển tiếp';

  @override
  String get groupInfoGroup => 'nhóm';

  @override
  String get groupInfoRenameGroup => 'Đổi tên nhóm';

  @override
  String get groupInfoRename => 'Đổi tên';

  @override
  String get groupInfoNoContactsToAdd => 'Không có liên hệ nào để thêm';

  @override
  String get groupInfoCouldNotAdd => 'Không thêm được';

  @override
  String groupInfoRemove(Object haloId) {
    return 'Gỡ $haloId khỏi nhóm?';
  }

  @override
  String get groupInfoTheyWillStopReceiving =>
      'Họ sẽ không nhận được tin nhắn từ nhóm này nữa.';

  @override
  String get commonRemove => 'Gỡ bỏ';

  @override
  String get groupInfoClearThisConversation => 'Xóa hết tin nhắn ở đây?';

  @override
  String get groupInfoEveryMessageHereIs =>
      'Mọi tin nhắn ở đây sẽ bị xóa khỏi điện thoại này. Việc này chỉ xóa bản của bạn, các thành viên khác vẫn giữ bản của họ.';

  @override
  String get groupInfoClear => 'Xóa hết';

  @override
  String get groupInfoConversationCleared => 'Đã xóa hết tin nhắn';

  @override
  String get groupInfoLeaveRoom => 'Rời phòng?';

  @override
  String get groupInfoLeaveGroup => 'Rời nhóm?';

  @override
  String get groupInfoEverythingInItIs =>
      'Mọi thứ trong đó sẽ bị xóa sạch khỏi điện thoại này ngay bây giờ, và khóa bạn dùng ở đây sẽ mất vĩnh viễn.';

  @override
  String get groupInfoYouWillStopReceiving =>
      'Bạn sẽ không nhận tin nhắn nữa và các thành viên khác sẽ thấy bạn rời đi.';

  @override
  String get groupInfoLeave => 'Rời đi';

  @override
  String get groupInfoGroupInfo => 'Thông tin nhóm';

  @override
  String groupInfo1Member(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString thành viên',
    );
    return '$_temp0';
  }

  @override
  String get groupInfoAdmin => 'Quản trị viên';

  @override
  String get groupInfoMembers2 => 'Thành viên';

  @override
  String get groupInfoInvite => 'Mời';

  @override
  String get commonAdd => 'Thêm';

  @override
  String get groupInfoYou => 'Bạn';

  @override
  String get groupInfoRemoveFromGroup => 'Gỡ khỏi nhóm';

  @override
  String get groupInfoWallpaper => 'Hình nền';

  @override
  String get groupInfoSharedMedia => 'Tệp đã chia sẻ';

  @override
  String get groupInfoClearConversation => 'Xóa hết tin nhắn';

  @override
  String get groupInfoLeaveRoom2 => 'Rời phòng';

  @override
  String get groupInfoLeaveGroup2 => 'Rời nhóm';

  @override
  String get groupInfoAddMembers => 'Thêm thành viên';

  @override
  String groupInfoAdd(Object pickedLength) {
    return 'Thêm $pickedLength';
  }

  @override
  String handleYouAre(Object h) {
    return 'Bạn là @$h';
  }

  @override
  String get handleHandleDeletedThePage =>
      'Đã xóa tên người dùng · trang đã bị gỡ';

  @override
  String get handlePublicHandle => 'Tên người dùng công khai';

  @override
  String get handleOptionalYourThreeWords =>
      'Không bắt buộc. Ba từ của bạn vẫn hoạt động dù thế nào.';

  @override
  String get handleWren => 'wren';

  @override
  String get handleALineAboutYou => 'Một dòng về bạn · không bắt buộc';

  @override
  String get handleClaiming => 'Đang đăng ký…';

  @override
  String get handleClaimThisHandle => 'Đăng ký tên này';

  @override
  String get handleAnyoneWithThisLink =>
      'Bất kỳ ai có liên kết này đều có thể bắt đầu trò chuyện riêng với bạn. Liên kết chỉ chứa lời mời của bạn, không có gì khác.';

  @override
  String get handleLinkCopied => 'Đã sao chép liên kết';

  @override
  String get handleDeleteThisHandle => 'Xóa tên người dùng này';

  @override
  String get handleChecking => 'Đang kiểm tra…';

  @override
  String get handleAvailable => '✓ còn trống';

  @override
  String get handleAlreadyTaken => 'đã có người dùng';

  @override
  String get handleWhatAHandleDoes => 'Tên người dùng để làm gì';

  @override
  String get handleAnyoneWhoKnowsIt =>
      'Bất kỳ ai biết tên này đều có thể xin nhắn tin cho bạn, đó chính là mục đích của nó. Trang này chỉ chứa lời mời của bạn và dòng bạn đã viết, không có gì khác, và không lưu lại ai đã đọc nó. Bạn có thể xóa nó bất cứ lúc nào.';

  @override
  String handleIsNotYoursOn(Object handle) {
    return '@$handle không thuộc về bạn trên điện thoại này';
  }

  @override
  String handleTheRegistryHoldsIt(Object handle) {
    return 'Nơi đăng ký đang giữ tên này dưới một khóa khác, nhiều khả năng là danh tính mà điện thoại này có trước khi khôi phục. Những người thêm @$handle sẽ không liên lạc được với bạn. Không thể nhả hoặc cập nhật tên này từ đây. Hãy chọn tên khác.';
  }

  @override
  String get handleForgetItOnThis => 'Quên nó trên điện thoại này';

  @override
  String get homeAddAContact => 'Thêm liên hệ';

  @override
  String get commonSettings => 'Cài đặt';

  @override
  String get homeYourKryfo => 'Kryfo của bạn';

  @override
  String homeDateWeekday(Object weekday) {
    return '$weekday,';
  }

  @override
  String get homeAnHour => 'một giờ';

  @override
  String homeHours(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString giờ',
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
      other: '$countString phút',
    );
    return '$_temp0';
  }

  @override
  String get homeKryfoIsOffline => 'Kryfo đang ngoại tuyến';

  @override
  String homeTorHasNotBeen(Object howLong) {
    return 'Tor đã không kết nối được trong $howLong. Không gì có thể đến hoặc đi cho đến khi tor kết nối lại.';
  }

  @override
  String get homeReconnecting => 'Đang kết nối lại';

  @override
  String get homeReconnect => 'Kết nối lại';

  @override
  String get homeWhatIsWrong => 'Có vấn đề gì';

  @override
  String get homeKryfoWillCheckIn => 'Kryfo sẽ kiểm tra mỗi 15 phút';

  @override
  String get homeYourPhoneKeepsStopping => 'Điện thoại của bạn cứ dừng Kryfo';

  @override
  String get homeItHasClosedKryfo =>
      'Hôm nay nó đã đóng Kryfo ba lần, nên tin nhắn đến muộn hoặc phải chờ. Kiểm tra định kỳ không bị ảnh hưởng: Kryfo thức dậy mỗi 15 phút thay vì luôn giữ kết nối.';

  @override
  String get homeSwitchToCheckIns => 'Chuyển sang kiểm tra định kỳ';

  @override
  String get homeNotNow => 'Để sau';

  @override
  String get homeNotificationsAreOff => 'Thông báo đang tắt';

  @override
  String get homeAndroidIsBlockingThem =>
      'Android đang chặn thông báo, nên không có gì đến được với bạn khi Kryfo đang đóng. Tin nhắn vẫn đến khi bạn mở ứng dụng.';

  @override
  String get homeCouldnTOpenIt =>
      'Không mở được. Hãy tìm Kryfo trong cài đặt điện thoại';

  @override
  String get homeTurnThemOn => 'Bật thông báo';

  @override
  String get homeLeaveThemOff => 'Cứ để tắt';

  @override
  String get homeOurRelayIsQuiet => 'Relay của chúng tôi im lặng';

  @override
  String get homeRelayModeUsesOnly =>
      'Chế độ relay chỉ dùng relay riêng của chúng tôi, và hiện nó không phản hồi. Chế độ nhanh thêm các relay công cộng bên cạnh, nên tin nhắn vẫn đến được. Dù thế nào mọi thứ vẫn được mã hóa kín.';

  @override
  String get homeSwitchedToFast => 'Đã chuyển sang Nhanh';

  @override
  String get homeUseFastMode => 'Dùng chế độ nhanh';

  @override
  String get homeKeepWaiting => 'Tiếp tục chờ';

  @override
  String get homeNotConnecting => 'Không kết nối được';

  @override
  String get homeBridgesAreOnAnd =>
      'Cầu nối đang bật mà tor vẫn chưa kết nối được. Cầu nối chậm hơn, và một số cầu nối ngừng hoạt động mà không báo trước. Nếu mạng của bạn không chặn tor, kết nối trực tiếp sẽ nhanh và ổn định hơn.';

  @override
  String get homeGoingDirectReconnecting =>
      'Chuyển sang trực tiếp · đang kết nối lại';

  @override
  String get homeTurnBridgesOff => 'Tắt cầu nối';

  @override
  String get homeStillTrying => 'Vẫn đang thử';

  @override
  String get homeTorIsNotGetting =>
      'Tor không kết nối được. Một số mạng cố tình chặn nó. Relay riêng của chúng tôi chỉ là một kết nối thông thường và thường vẫn hoạt động - hoặc dùng cầu nối, vốn mất nhiều thời gian thiết lập hơn.';

  @override
  String get homeSwitchedToRelay => 'Đã chuyển sang Relay';

  @override
  String get homeUseOurRelay => 'Dùng relay của Kryfo';

  @override
  String get homeBridges => 'Cầu nối';

  @override
  String get homeOffline => 'Ngoại tuyến';

  @override
  String get homeWaiting => 'Đang chờ';

  @override
  String get homeNothingWaitingToSend => 'Không có gì chờ gửi';

  @override
  String homeWaitingSendsWhenYou(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString đang chờ · sẽ gửi khi bạn trực tuyến lại',
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
      other: '$countString đang chờ · tor vẫn đang kết nối',
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
      other: '$countString đang chờ · chờ họ thêm lại bạn',
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
      other: '$countString đang chờ · $parkedString chờ họ thêm lại bạn',
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
      other: '$countString đang chờ · đang gửi',
    );
    return '$_temp0';
  }

  @override
  String get commonRetry => 'Thử lại';

  @override
  String get homeNoKryfosYet => 'Chưa có Kryfo nào.';

  @override
  String get homeScanTheirCodeSend =>
      'Quét mã của họ, gửi cho họ một liên kết, hoặc nhập @tên người dùng họ đưa cho bạn.';

  @override
  String get homeAddSomeone => 'Thêm người';

  @override
  String get homeArchived => 'Đã lưu trữ';

  @override
  String home1Chat(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString cuộc trò chuyện',
    );
    return '$_temp0';
  }

  @override
  String get homeGroups => 'Nhóm';

  @override
  String get homeRoom => 'Phòng';

  @override
  String get homeNew => 'Mới';

  @override
  String homeRoomExpired(Object expiredRoomName) {
    return '$expiredRoomName · phòng đã hết hạn';
  }

  @override
  String get homeMentionedYou => 'Đã nhắc đến bạn';

  @override
  String homeMembers(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString thành viên',
    );
    return '$_temp0';
  }

  @override
  String get homeSupporter => 'Người ủng hộ';

  @override
  String get homeArchivedChats => 'Trò chuyện đã lưu trữ';

  @override
  String get homeUnmute => 'Bật tiếng';

  @override
  String get homeMute => 'Tắt tiếng';

  @override
  String get homeArchive => 'Lưu trữ';

  @override
  String get homeDeleteChat => 'Xóa cuộc trò chuyện';

  @override
  String get homeMessagesAndContactGone =>
      'Tin nhắn và liên hệ, bị xóa khỏi điện thoại này';

  @override
  String get homeDeleteThisChat => 'Xóa cuộc trò chuyện này?';

  @override
  String homeEveryMessageWithGoes(Object c) {
    return 'Mọi tin nhắn với $c sẽ bị xóa, và họ không còn là liên hệ nữa. Việc này chỉ xóa trên điện thoại này - bản của họ vẫn ở chỗ họ. Nếu họ nhắn lại, tin nhắn sẽ vào mục yêu cầu.';
  }

  @override
  String get homeQueued => 'Đang chờ gửi';

  @override
  String get homeBlocked => 'đã chặn';

  @override
  String get homeRoomInvite => 'Lời mời vào phòng';

  @override
  String get homeNow => 'vừa xong';

  @override
  String homeM(Object inMinutes) {
    return '$inMinutes phút';
  }

  @override
  String homeH(Object inHours) {
    return '$inHours giờ';
  }

  @override
  String get homeYesterday => 'hôm qua';

  @override
  String homeD(Object inDays) {
    return '$inDays ngày';
  }

  @override
  String get homeNoteToSelf => 'Ghi chú riêng';

  @override
  String get homeOnlyOnThisPhone => 'Chỉ trên điện thoại này';

  @override
  String get homeSaved => 'Đã lưu';

  @override
  String get homeKeptFromEveryChat => 'Giữ lại từ mọi cuộc trò chuyện';

  @override
  String get homeRequests => 'Yêu cầu';

  @override
  String home1PersonWantsTo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString người muốn liên lạc với bạn',
    );
    return '$_temp0';
  }

  @override
  String introduceGotItButCould(Object b, Object c) {
    return '$b đã nhận, nhưng không liên lạc được với $c';
  }

  @override
  String introduceGotItButCouldNotBe(Object c, Object b) {
    return '$c đã nhận, nhưng không liên lạc được với $b';
  }

  @override
  String get introduceCouldNotReachEither =>
      'Không liên lạc được với ai trong hai người. Hãy thử lại sau';

  @override
  String introduceIntroduceTo(Object peerName) {
    return 'Giới thiệu $peerName với...';
  }

  @override
  String get introduceBothOfThemGet =>
      'Cả hai sẽ nhận được thẻ của người kia. Không ai thấy biệt danh bạn đặt cho người kia.';

  @override
  String get introduceNoOneElseTo =>
      'Chưa có ai khác để giới thiệu. Hãy thêm một liên hệ khác trước.';

  @override
  String get introduceANoteLikeMy =>
      'Ghi chú, như “em họ tôi” - không bắt buộc';

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
      other: 'Còn $leftString trên $maxString lượt giới thiệu trong tuần này',
    );
    return '$_temp0';
  }

  @override
  String introduceNoIntroductionsLeftNext(Object refillPhrase) {
    return 'Hết lượt giới thiệu. Lượt tiếp theo sẽ có $refillPhrase';
  }

  @override
  String get introduceIntroduce => 'Giới thiệu';

  @override
  String get keyVerificationSafetyNumber => 'Số an toàn';

  @override
  String keyVerificationWith(Object peerName) {
    return 'Với $peerName';
  }

  @override
  String keyVerificationIfSeesTheSame(Object peerName) {
    return 'Nếu $peerName thấy cùng một số, tin nhắn của bạn chỉ riêng hai người biết. So sánh trực tiếp hoặc qua một cuộc gọi bạn tin tưởng là cách chắc chắn nhất - nhưng việc này không bắt buộc, không bao giờ là điều kiện để trò chuyện.';
  }

  @override
  String get keyVerificationVerified => 'Đã xác minh';

  @override
  String get keyVerificationMarkAsVerified => 'Đánh dấu đã xác minh';

  @override
  String get lockFileThatPasswordDoesNot => 'Mật khẩu đó không mở được tệp.';

  @override
  String get lockFileThisFileIsDamaged => 'Tệp này bị hỏng.';

  @override
  String get lockFileThisFileWasLocked =>
      'Tệp này được khóa bằng khóa mã hóa, không phải bằng mật khẩu.';

  @override
  String get lockFileThisIsNotA => 'Đây không phải tệp đã khóa.';

  @override
  String get lockFileNotEnoughFreeMemory => 'Hiện không đủ bộ nhớ trống.';

  @override
  String get lockFileStopped => 'Đã dừng.';

  @override
  String get lockFileItNeedsAPassword => 'Cần có mật khẩu.';

  @override
  String get lockFileKryfoCouldNotRead => 'Kryfo không đọc hoặc ghi được tệp.';

  @override
  String get lockFileCheckCapitalsAndSpaces =>
      'Hãy kiểm tra chữ hoa và dấu cách. Không ai có thể đặt lại mật khẩu, kể cả chúng tôi.';

  @override
  String get lockFileItMayHaveBeen =>
      'Có thể tệp đã bị cắt cụt trên đường gửi. Hãy nhờ gửi lại. Không có gì được lưu.';

  @override
  String get lockFileItOpensWithThe =>
      'Tệp này mở bằng tệp khóa của người nhận, trong công cụ age trên máy tính. Kryfo mở loại dùng mật khẩu.';

  @override
  String get lockFileKryfoOpensFilesLocked =>
      'Kryfo mở các tệp được khóa bằng age. Những tệp đó thường có đuôi .age.';

  @override
  String get lockFileCloseAFewApps =>
      'Hãy đóng bớt vài ứng dụng rồi thử lại. Việc kiểm tra mật khẩu cần vài trăm megabyte trong chốc lát.';

  @override
  String get lockFileNothingWasSaved => 'Không có gì được lưu.';

  @override
  String get lockFileTypeOneOrLet => 'Hãy tự nhập, hoặc để Kryfo gợi ý bốn từ.';

  @override
  String get lockFileTheAppThatHolds =>
      'Ứng dụng chứa tệp có thể đã lấy lại nó. Hãy chọn lại.';

  @override
  String get lockFileHidePassword => 'Ẩn mật khẩu';

  @override
  String get lockFileShowPassword => 'Hiện mật khẩu';

  @override
  String get lockFileChangeFile => 'Đổi tệp';

  @override
  String get lockFileChange => 'Đổi';

  @override
  String lockFileOf(Object prettySize, Object prettySize2) {
    return '$prettySize trên $prettySize2';
  }

  @override
  String get lockFileEverythingStaysOnThis =>
      'Mọi thứ đều ở lại trên điện thoại này.';

  @override
  String get lockFileCouldNotMakeOne => 'Không tạo được. Hãy tự nhập.';

  @override
  String get lockFileWriteItDownBefore => 'Hãy ghi lại trước khi khóa tệp';

  @override
  String get lockFileNoAppOnThis =>
      'Không ứng dụng nào trên điện thoại này nhận tệp.';

  @override
  String get lockFileSaved => 'Đã lưu';

  @override
  String get lockFileCouldNotSaveIt =>
      'Không lưu được vào đó. Hãy thử thư mục khác.';

  @override
  String get lockFileLocked => 'Đã khóa';

  @override
  String get lockFileLockAFile => 'Khóa tệp';

  @override
  String get lockFileMixingThePassword => 'Đang trộn mật khẩu';

  @override
  String get lockFileLocking => 'Đang khóa';

  @override
  String get lockFileSaveToFiles => 'Lưu vào Tệp';

  @override
  String get lockFileLockFile => 'Khóa tệp';

  @override
  String get lockFileOnePassword => 'Một mật khẩu.';

  @override
  String get lockFileNothingElseOpensIt => 'Không gì khác mở được nó.';

  @override
  String get lockFileFile => 'Tệp';

  @override
  String lockFileFromFiles(Object prettySize) {
    return '$prettySize · từ Tệp';
  }

  @override
  String get lockFileFromFiles2 => 'Từ Tệp';

  @override
  String get lockFilePassword => 'Mật khẩu';

  @override
  String get lockFileSuggestFourWords => 'Gợi ý bốn từ';

  @override
  String get lockFileTypeItAgain => 'Nhập lại';

  @override
  String get lockFileTheTwoDoNot => 'Hai mật khẩu chưa khớp.';

  @override
  String get lockFileHideTheFileName => 'Ẩn tên tệp';

  @override
  String lockFileItWillBeCalled(Object name) {
    return 'Tệp sẽ có tên “$name”. Hãy cho họ biết đó là loại tệp gì.';
  }

  @override
  String get lockFileTheNameAloneCan =>
      'Chỉ riêng cái tên cũng có thể tiết lộ bên trong có gì.';

  @override
  String get lockFileAnyoneWithThePassword =>
      'Bất kỳ ai có mật khẩu đều mở được tệp, trong Kryfo hoặc trên bất kỳ máy tính nào có công cụ miễn phí age. Quên mật khẩu là mất tệp vĩnh viễn. Không ai có thể đặt lại nó, kể cả chúng tôi.';

  @override
  String get lockFileLocked2 => 'Đã khóa.';

  @override
  String get lockFileOnlyThePasswordOpens => 'Chỉ mật khẩu mới mở được nó.';

  @override
  String lockFileSafeToEmailOr(Object prettySize) {
    return '$prettySize · an toàn để gửi email hoặc chép vào USB';
  }

  @override
  String get lockFileNoKryfoOnThe => 'Bên kia không có Kryfo? Trên máy tính:';

  @override
  String get lockFileItAsksForThe =>
      'Công cụ sẽ hỏi mật khẩu. age miễn phí tại age-encryption.org';

  @override
  String lockTooManyTriesS(Object lockState) {
    return 'Quá nhiều lần thử · ${lockState}s';
  }

  @override
  String get lockNotIt => 'Không đúng';

  @override
  String get lockYourPin => 'Mã PIN của bạn';

  @override
  String get lockUseFingerprint => 'Dùng vân tay';

  @override
  String get lockSetupUnlockWithFingerprint => 'Mở khóa bằng vân tay?';

  @override
  String get lockSetupThePinStillWorks =>
      'Mã PIN vẫn dùng được bất cứ khi nào bạn muốn. Cách này chỉ nhanh hơn thôi.';

  @override
  String get lockSetupUseFingerprint => 'Dùng vân tay';

  @override
  String get lockSetupPinOnly => 'Chỉ mã PIN';

  @override
  String get lockSetupOnceMore => 'Thêm lần nữa';

  @override
  String get lockSetupSetAPin => 'Đặt mã PIN';

  @override
  String get lockSetupThoseWereDifferentFrom =>
      'Hai lần nhập khác nhau. Làm lại từ đầu nhé.';

  @override
  String get lockSetupTheSameFourDigits => 'Nhập lại đúng các chữ số đó';

  @override
  String get lockSetupFourDigitsAnythingYou =>
      'Bốn chữ số trở lên, bất cứ số nào bạn sẽ nhớ được';

  @override
  String get modesOnion => 'Onion';

  @override
  String get modesFullOnionRoutingThree =>
      'Định tuyến onion đầy đủ, ba chặng. Mỗi tin nhắn mất từ hai đến năm giây. Không ai thấy bạn nói chuyện với ai.';

  @override
  String get modesSlower => 'chậm hơn';

  @override
  String get modesRelay => 'Relay';

  @override
  String get modesOneSealedConnectionTo =>
      'Một kết nối được mã hóa kín tới relay riêng của Kryfo, như một vpn không có gì để ghi nhật ký. Tin gửi đi đến nơi trong khoảng một giây, và chế độ này hoạt động cả ở nơi tor bị chặn.';

  @override
  String get modesQuick => 'nhanh';

  @override
  String get modesRelayOnly => 'Chỉ relay';

  @override
  String get modesFast => 'Nhanh';

  @override
  String get modesPlainConnectionsToEvery =>
      'Kết nối thông thường tới mọi relay. Gần như tức thì, và kém riêng tư nhất trong ba chế độ.';

  @override
  String get modesInstant => 'tức thì';

  @override
  String get modesEveryRelayYouUse =>
      'Mọi relay bạn dùng đều biết địa chỉ bạn kết nối từ đó, không chỉ relay của chúng tôi. Tin nhắn vẫn được mã hóa kín, nhưng việc bạn đã gửi tin thì không được che giấu. Mặc định tắt, và tắt lại sau khi cài đặt lại.';

  @override
  String get modesSpeed => 'Tốc độ';

  @override
  String get modesPrivacy => '& riêng tư';

  @override
  String get modesChangeGloballyOrPer =>
      'Đổi cho tất cả, hoặc cho từng cuộc trò chuyện';

  @override
  String get modesSoon => 'Sắp có';

  @override
  String get modesActive => 'Đang dùng';

  @override
  String get modesSpeed2 => 'TỐC ĐỘ';

  @override
  String get modesHops => 'CHẶNG';

  @override
  String get modesIp => 'IP';

  @override
  String get modesVisible => 'Bị lộ';

  @override
  String get modesHidden => 'ẩn';

  @override
  String modesHeadsUp(Object warning) {
    return '*Lưu ý:* $warning';
  }

  @override
  String get modesOnionIsTheDefault =>
      'Onion là chế độ mặc định và sẽ giữ nguyên trừ khi bạn thay đổi. Việc chuyển đổi có hiệu lực từ tin nhắn tiếp theo.';

  @override
  String get modesFastMode => 'Chế độ nhanh';

  @override
  String get modesPlainConnectionsToEveryRelayQuicker =>
      'Kết nối thông thường tới mọi relay. Nhanh hơn, và các relay có thể thấy địa chỉ IP của bạn. Dù thế nào tin nhắn vẫn được mã hóa đầu cuối.';

  @override
  String get modesTurnOnFastMode => 'Bật chế độ nhanh';

  @override
  String get modesKeepItOff => 'Cứ để tắt';

  @override
  String get movedWipeThisPhone => 'Xóa sạch Kryfo khỏi điện thoại này?';

  @override
  String get movedEverythingKryfoHoldsHere =>
      'Mọi thứ Kryfo lưu ở đây sẽ bị xóa: tin nhắn, liên hệ, khóa. Thiết bị kia vẫn giữ tất cả. Không thể hoàn tác việc này.';

  @override
  String get movedWipeIt => 'Xóa sạch';

  @override
  String get movedNotMovingAfterAll => 'Rốt cuộc không chuyển nữa?';

  @override
  String get movedOnlyDoThisIf =>
      'Chỉ làm việc này nếu bản sao lưu chưa từng được nhập ở đâu. Nếu đã nhập, hai thiết bị sẽ cùng giữ một danh tính, và tin nhắn sẽ bắt đầu thất lạc trên cả hai.';

  @override
  String get movedIMStayingHere => 'Tôi sẽ ở lại đây';

  @override
  String get movedStayingHere => 'Ở lại đây';

  @override
  String movedKryfoWillCloseNow(Object myId) {
    return 'Kryfo sẽ đóng ngay bây giờ. Chạm vào biểu tượng để mở lại với tư cách $myId.';
  }

  @override
  String get movedReopenKryfo => 'Mở lại Kryfo';

  @override
  String get movedThisKryfoHasMoved => 'Kryfo này đã chuyển đi';

  @override
  String movedIsNowOnAnother(Object myId) {
    return '$myId giờ đã ở trên thiết bị khác. Điện thoại này vẫn hiện được những gì đã có ở đây, nhưng sẽ không có gì mới đến nữa, và mọi thứ bạn gửi từ đây sẽ không đến được với ai.';
  }

  @override
  String get movedKeepItToRead => 'Giữ để đọc';

  @override
  String get movedWipeThisPhone2 => 'Xóa sạch Kryfo khỏi điện thoại này';

  @override
  String get movedIMNotMoving => 'Rốt cuộc tôi không chuyển nữa';

  @override
  String get myKryfoAHandleIs3 =>
      'Tên người dùng gồm 3 đến 20 chữ cái, chữ số hoặc _';

  @override
  String get myKryfoInviteCopiedClearsIn =>
      'Đã sao chép lời mời · tự xóa sau 60s';

  @override
  String myKryfoAddMeOnKryfo(Object myId, Object uri) {
    return 'Thêm tôi trên Kryfo. ID của tôi là $myId\n\nChạm để thêm tôi:\n$uri\n\nKryfo là ứng dụng nhắn tin riêng tư. Không cần số điện thoại, không cần email.';
  }

  @override
  String get myKryfoAddMeOnKryfo2 => 'Thêm tôi trên Kryfo';

  @override
  String get myKryfoAddSomeone => 'Thêm người';

  @override
  String get myKryfoKryfoDoesnTScan =>
      'Kryfo không quét danh bạ của bạn, đó chính là mục đích.';

  @override
  String get myKryfoIfThisLinkEnds =>
      'Nếu liên kết này lọt tới nơi bạn không định, hãy đặt lại nó trong cài đặt. Khi đó, mọi người đã có liên kết sẽ cần liên kết mới.';

  @override
  String get myKryfoAlreadyShareAFriend =>
      'Đã có bạn chung trên Kryfo? Người đó có thể giới thiệu hai bạn từ cuộc trò chuyện của họ, và bạn không cần gửi yêu cầu.';

  @override
  String get myKryfoHandleCopied => 'Đã sao chép tên người dùng';

  @override
  String get myKryfoTheyReHereWith => 'Họ đang ở cạnh tôi';

  @override
  String get myKryfoPointYourPhonesAt =>
      'Hướng hai điện thoại vào nhau. Không có gì đi qua máy chủ.';

  @override
  String get myKryfoScanTheirsInstead => 'Hoặc quét mã của họ';

  @override
  String get myKryfoTheyReadYouA => 'Họ đọc mã cho bạn';

  @override
  String get myKryfoTheyReSomewhereElse => 'Họ đang ở nơi khác';

  @override
  String get myKryfoSendThemALink =>
      'Gửi cho họ một liên kết. Liên kết mở thẳng vào màn hình thêm liên hệ.';

  @override
  String get myKryfoYourLinkAppearsOnce =>
      'Liên kết của bạn sẽ hiện khi đã kết nối';

  @override
  String get myKryfoTheLinkCarriesYour =>
      'Liên kết chứa ID, địa chỉ của bạn và các khóa để bắt đầu trò chuyện. Nó dùng được cho đến khi bạn đặt lại trong cài đặt.';

  @override
  String get myKryfoSendTheLink => 'Gửi liên kết';

  @override
  String get myKryfoAsACard => 'Dạng thẻ';

  @override
  String get myKryfoAnImageWithThe => 'Ảnh có mã QR';

  @override
  String get myKryfoAsAFile => 'Dạng tệp';

  @override
  String get myKryfoContactFile => 'Tệp liên hệ';

  @override
  String get myKryfoIKnowTheirHandle => 'Tôi biết tên người dùng của họ';

  @override
  String get myKryfoTypeTheNameThey =>
      'Nhập @tên họ đưa cho bạn. Dùng được nếu họ đã đăng ký một tên.';

  @override
  String get myKryfoWren => 'Wren';

  @override
  String get myKryfoTheLookupAsksFor =>
      'Việc tra cứu chỉ gửi đúng tên đó và không gì về bạn. Tin nhắn đầu tiên của bạn vẫn đến họ dưới dạng yêu cầu.';

  @override
  String get myKryfoLooking => 'Đang tìm…';

  @override
  String get myKryfoFindThem => 'Tìm họ';

  @override
  String get myKryfoYourAddressAppearsOnce =>
      'Địa chỉ của bạn sẽ hiện khi đã kết nối';

  @override
  String get myKryfoAPublicHandle => 'Tên người dùng công khai';

  @override
  String get myKryfoPutItInA =>
      'Đặt nó vào phần giới thiệu. Ai biết tên này đều có thể tìm thấy bạn.';

  @override
  String get myKryfoANamePeopleCan =>
      'Một cái tên để mọi người tìm bạn. Tắt cho đến khi bạn đăng ký.';

  @override
  String get newGroupCouldNotCreate => 'Không tạo được';

  @override
  String get newGroupNewGroup => 'Nhóm mới';

  @override
  String get newGroupCreating => 'Đang tạo…';

  @override
  String get newGroupCreate => 'Tạo';

  @override
  String get newGroupGroupName => 'Tên nhóm';

  @override
  String get newGroupMembers => 'Thành viên';

  @override
  String get newGroupPickAtLeastOne => 'Chọn ít nhất một người';

  @override
  String newGroupSelected(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Đã chọn $countString',
    );
    return '$_temp0';
  }

  @override
  String get newGroupAddAtLeastOne =>
      'Hãy thêm ít nhất một liên hệ trước khi tạo nhóm.';

  @override
  String get notesToday => 'HÔM NAY';

  @override
  String get notesYesterday => 'HÔM QUA';

  @override
  String get notesNoteToSelf => 'Ghi chú riêng';

  @override
  String get notesOnlyOnThisPhone => 'Chỉ trên điện thoại này';

  @override
  String get notesAQuietPlace => 'Một góc yên tĩnh';

  @override
  String get notesJotAnythingDownIt =>
      'Ghi lại bất cứ điều gì. Nó ở lại trên điện thoại này và không bao giờ rời đi.';

  @override
  String get notesJotSomethingDown => 'Ghi lại điều gì đó…';

  @override
  String get onboardingPrivateByDefault => 'RIÊNG TƯ MẶC ĐỊNH';

  @override
  String get onboardingPrivateMessaging =>
      'Nhắn tin riêng tư,\n*không có cạm bẫy*.';

  @override
  String get onboardingYourNameIsThree =>
      '*Tên bạn là ba từ.* Không số điện thoại, không email, không danh bạ.';

  @override
  String get onboardingNobodyGetsInUnless =>
      '*Không ai vào được trừ khi bạn cho phép.* Không có tìm kiếm. Mọi người được thêm thủ công, từ cả hai phía.';

  @override
  String get onboardingTheFirstConnectionTakes =>
      '*Lần kết nối đầu tiên mất một phút.* Kryfo dựng một tuyến đường riêng tư trước khi gửi. Sau đó sẽ nhanh.';

  @override
  String get onboardingBegin => 'Bắt đầu';

  @override
  String get onboardingHaveABackupRestore => 'Có bản sao lưu? Khôi phục →';

  @override
  String get onboardingKryfoIsOpenSource => 'Kryfo là mã nguồn mở';

  @override
  String get onboardingYourKryfoId => 'ID KRYFO CỦA BẠN';

  @override
  String get onboardingGeneratedFromAKey =>
      'Được tạo từ một khóa chỉ nằm trên điện thoại này. *Dễ nhớ, độc nhất, của riêng bạn.* Không ai khác có tên này.';

  @override
  String get onboardingTryAnother => 'Thử cái khác';

  @override
  String get onboardingUseThisName => 'Dùng tên này →';

  @override
  String get onboardingThreeWords => 'Ba từ. *Của riêng bạn.*';

  @override
  String get onboardingPickA => 'Chọn một *khuôn mặt*.';

  @override
  String get onboardingDrawnOnThisPhone =>
      'Được vẽ trên điện thoại này từ một con số, không bao giờ tải lên. Đổi bất cứ lúc nào bạn muốn.';

  @override
  String get onboardingThePeopleYouMessage =>
      'Những người mà bạn nhắn tin cũng thấy khuôn mặt này';

  @override
  String get onboardingKeepMyInitial => 'Giữ chữ cái đầu';

  @override
  String get onboardingThatOne => 'Cái này →';

  @override
  String get onboardingContinue => 'Tiếp tục →';

  @override
  String get onboardingHowYourMessages => 'Cách tin nhắn của bạn *đi*.';

  @override
  String get onboardingYouCanChangeThis =>
      'Bạn có thể đổi bất cứ lúc nào trong cài đặt, cho mọi người hoặc cho một cuộc trò chuyện.';

  @override
  String get onboardingOnion => 'Onion';

  @override
  String get onboardingSlowerAMessageTakes =>
      'Chậm hơn. Mỗi tin nhắn mất từ hai đến năm giây.';

  @override
  String get onboardingHidesYourAddressFrom =>
      'Ẩn địa chỉ của bạn với tất cả mọi người, kể cả relay của chúng tôi.';

  @override
  String get onboardingRelay => 'Relay';

  @override
  String get onboardingOurRelaySeesYour =>
      'Relay của chúng tôi thấy địa chỉ của bạn. Ngoài ra không ai thấy.';

  @override
  String get onboardingAboutASecondWorks =>
      'Khoảng một giây. Hoạt động cả ở nơi tor bị chặn.';

  @override
  String get onboardingFast => 'Nhanh';

  @override
  String get onboardingEveryRelayYouUse =>
      'Mọi relay bạn dùng đều thấy địa chỉ của bạn. Kém riêng tư nhất trong ba chế độ.';

  @override
  String get onboardingNearInstant => 'Gần như tức thì.';

  @override
  String get onboardingKeepOnion => 'Giữ onion →';

  @override
  String get onboardingUseThis => 'Dùng chế độ này →';

  @override
  String get onboardingSkipOnionIsA => 'Bỏ qua · onion là mặc định tốt';

  @override
  String get onboardingThreeThingsThen => 'Ba điều thôi,\nrồi *vào luôn*.';

  @override
  String get onboardingEverythingElseTheApp =>
      'Mọi thứ khác, ứng dụng sẽ cho bạn biết khi cần.';

  @override
  String get onboardingYourNameIsThreeWords => 'Tên bạn là ba từ';

  @override
  String get onboardingThatIsTheWhole =>
      'Đó là toàn bộ danh tính. Không có số điện thoại để bị lộ, không có email để bị lừa đảo, không có gì để tra cứu. Những người trò chuyện với bạn sẽ thấy ba từ này và khuôn mặt bạn đã chọn.';

  @override
  String get onboardingNobodyCanReachYou =>
      'Không ai liên lạc được với bạn cho đến khi bạn cho phép';

  @override
  String get onboardingAStrangerWithYour =>
      'Người lạ biết ba từ của bạn chỉ có thể gõ cửa. Tin nhắn đầu tiên của họ chờ trong mục yêu cầu cho đến khi bạn đồng ý, và bạn có thể từ chối mà họ không bao giờ biết.';

  @override
  String get onboardingTheFirstConnectionTakesAMinute =>
      'Lần kết nối đầu tiên mất một phút';

  @override
  String get onboardingKryfoBuildsAPrivateRouteBefore =>
      'Kryfo dựng một tuyến đường riêng tư trước khi gửi bất cứ thứ gì. Khi bạn ngoại tuyến, tin nhắn sẽ chờ và đến khi bạn trực tuyến lại.';

  @override
  String get onboardingYourIdentityLivesOn =>
      'Danh tính của bạn nằm trên điện thoại này. Hãy sao lưu nó trong cài đặt khi bạn sẵn sàng.';

  @override
  String get onboardingIUnderstand => 'Tôi hiểu rồi →';

  @override
  String get onboardingOneQuiet => 'Một *thông báo* lặng lẽ.';

  @override
  String get onboardingAndroidNeedsAVisible =>
      'Android cần một thông báo hiển thị khi ứng dụng lắng nghe ở chế độ nền. Nhờ vậy tin nhắn đến được với bạn khi Kryfo đang đóng.';

  @override
  String get onboardingSilentAndAtThe => 'Im lặng, và nằm cuối bảng thông báo';

  @override
  String get onboardingItNeverBuzzesTurn =>
      'Nó không bao giờ rung. Tắt nó đi thì tin nhắn sẽ chờ đến khi bạn mở lại ứng dụng.';

  @override
  String get onboardingGotIt => 'Đã hiểu →';

  @override
  String get onboardingNow => 'Giờ thì, *thêm một người*.';

  @override
  String get onboardingTheAppIsReady =>
      'Ứng dụng đã sẵn sàng. Không ai nhắn tin được cho bạn cho đến khi bạn thêm họ hoặc cho họ vào.';

  @override
  String get onboardingEveryWayToAdd => 'Mọi cách để thêm người';

  @override
  String get onboardingShowYourCodeSend =>
      'Hiện mã của bạn, gửi cho họ một liên kết, hoặc nhập @tên người dùng họ đưa cho bạn.';

  @override
  String get onboardingScanTheirs => 'Quét mã của họ';

  @override
  String get onboardingPointTheCameraAt => 'Hướng máy ảnh vào mã của họ';

  @override
  String get onboardingTheAppIsReadyWhenYou =>
      'Ứng dụng sẵn sàng bất cứ khi nào bạn muốn.';

  @override
  String get onboardingNotNowAddPeople => 'Để sau · thêm người sau';

  @override
  String get openLockedOpened => 'Đã mở';

  @override
  String get openLockedOpenALockedFile => 'Mở tệp đã khóa';

  @override
  String get openLockedCheckingThePassword => 'Đang kiểm tra mật khẩu';

  @override
  String get openLockedOpening => 'Đang mở';

  @override
  String get openLockedFile => 'Tệp';

  @override
  String get openLockedOpenFile => 'Mở tệp';

  @override
  String get openLockedTypeThePassword => 'Nhập mật khẩu.';

  @override
  String get openLockedItOpensOnThis => 'Tệp được mở trên điện thoại này.';

  @override
  String get openLockedLockedFile => 'Tệp đã khóa';

  @override
  String openLockedFromFiles(Object prettySize) {
    return '$prettySize · từ Tệp';
  }

  @override
  String get openLockedFromFiles2 => 'Từ Tệp';

  @override
  String get openLockedPassword => 'Mật khẩu';

  @override
  String get openLockedThePasswordIsChecked =>
      'Mật khẩu được kiểm tra trước. Chỉ sau đó Kryfo mới hỏi nơi lưu tệp đã mở, và tệp được lưu thẳng vào đó.';

  @override
  String get openLockedOpened2 => 'Đã mở.';

  @override
  String get openLockedSavedWhereYouChose => 'Đã lưu vào nơi bạn chọn.';

  @override
  String get pairCodePairingCode => 'Mã ghép nối';

  @override
  String get pairCodeShowACode => 'Hiện mã';

  @override
  String get pairCodeEnterOne => 'Nhập mã';

  @override
  String get pairCodeSixDigits => 'Sáu chữ số';

  @override
  String get pairCodeLooking => 'Đang tìm…';

  @override
  String get pairCodeNothingThereYetTrying => 'Chưa có gì · đang thử lại';

  @override
  String get pairCodeNothingAtThatCode =>
      'Không có gì ở mã đó. Có thể mã đã tự hủy, hoặc họ chưa chia sẻ.';

  @override
  String get pairCodeTypeTheSixDigits => 'Nhập sáu chữ số họ đọc cho bạn.';

  @override
  String get pairCodeAddThem => 'Thêm họ';

  @override
  String get panicSetupThoseWereDifferentFrom =>
      'Hai lần nhập khác nhau. Làm lại từ đầu nhé.';

  @override
  String get panicSetupOnceMore => 'Thêm lần nữa';

  @override
  String get panicSetupTheSameFourDigits => 'Nhập lại đúng các chữ số đó';

  @override
  String get photoKnowsEverythingInside => 'Mọi thứ bên trong';

  @override
  String get photoKnowsVideo => 'Video';

  @override
  String get photoKnowsPhoto => 'Ảnh';

  @override
  String get photoKnowsWhatThisVideoKnows => 'Video này biết gì';

  @override
  String get photoKnowsWhatThisPhotoKnows => 'Ảnh này biết gì';

  @override
  String get photoKnowsRemoveAllOfIt => 'Gỡ bỏ tất cả';

  @override
  String get photoKnowsKeepItAsIt => 'Giữ nguyên';

  @override
  String get photoKnowsReadOnThisPhone =>
      'ĐỌC TRÊN ĐIỆN THOẠI NÀY · VIDEO KHÔNG ĐI ĐÂU CẢ';

  @override
  String get photoKnowsReadOnThisPhoneThePhoto =>
      'ĐỌC TRÊN ĐIỆN THOẠI NÀY · ẢNH KHÔNG ĐI ĐÂU CẢ';

  @override
  String get photoKnowsReadingTheFile => 'Đang đọc tệp';

  @override
  String photoKnowsOf(Object prettySize, Object prettySize2) {
    return '$prettySize trên $prettySize2';
  }

  @override
  String get photoKnowsEverythingStaysOnThis =>
      'Mọi thứ đều ở lại trên điện thoại này.';

  @override
  String photoKnowsMapWithAPin(Object place) {
    return 'Bản đồ có ghim vị trí. $place';
  }

  @override
  String get photoKnowsDrawnOffline => 'VẼ NGOẠI TUYẾN';

  @override
  String photoKnowsShowEverything(Object title) {
    return '$title. Hiện tất cả';
  }

  @override
  String get pinsAppLock => 'Khóa ứng dụng';

  @override
  String get pinsYourPin => 'Mã PIN của bạn';

  @override
  String get commonOn => 'Bật';

  @override
  String get commonOff => 'Tắt';

  @override
  String get pinsOpensKryfoFourDigits =>
      'Mở Kryfo. Được hỏi mỗi khi Kryfo quay lại màn hình.';

  @override
  String get pinsChangePin => 'Đổi mã PIN';

  @override
  String get pinsSetAPin => 'Đặt mã PIN';

  @override
  String get pinsTurnOff => 'Tắt';

  @override
  String get pinsTurnOffTheApp => 'Tắt khóa ứng dụng?';

  @override
  String get pinsThePinGoesAnd =>
      'Mã PIN sẽ bị gỡ, kéo theo cả mã PIN xóa sạch và mọi trò chuyện ẩn. Bất kỳ ai cầm điện thoại của bạn đều mở được Kryfo với tư cách là bạn.';

  @override
  String get pinsUnlockWithFingerprint => 'Mở khóa bằng vân tay';

  @override
  String get pinsWipePin => 'Mã PIN xóa sạch';

  @override
  String get pinsNeedsAPinFirst => 'Cần đặt mã PIN trước';

  @override
  String get pinsSet => 'Đã đặt';

  @override
  String get pinsChangeWipePin => 'Đổi mã PIN xóa sạch';

  @override
  String get pinsSetAWipePin => 'Đặt mã PIN xóa sạch';

  @override
  String get pinsRemove => 'Gỡ bỏ';

  @override
  String get pinsRemoveTheWipePin => 'Gỡ mã PIN xóa sạch?';

  @override
  String get pinsTheLockScreenKeeps =>
      'Màn hình khóa vẫn giữ mã PIN của bạn. Mã PIN xóa sạch sẽ không còn tác dụng gì.';

  @override
  String profileCopied(Object what) {
    return 'Đã sao chép $what';
  }

  @override
  String get profileProfile => 'Hồ sơ';

  @override
  String get profileChangeYourFace => 'Đổi khuôn mặt';

  @override
  String get profileKryfoId => 'ID Kryfo';

  @override
  String get profileOnionAddress => 'Địa chỉ onion';

  @override
  String get profileSupporterBadge => 'Huy hiệu người ủng hộ';

  @override
  String profileYouAreAThank(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter': 'Bạn là người ủng hộ. cảm ơn bạn.',
      'patron': 'Bạn là nhà bảo trợ. cảm ơn bạn.',
      'guardian': 'Bạn là người bảo hộ. cảm ơn bạn.',
      'other': 'Bạn là người ủng hộ. cảm ơn bạn.',
    });
    return '$_temp0';
  }

  @override
  String get profileShowMyBadge => 'Hiện huy hiệu của tôi';

  @override
  String get profileOnMyOwnScreens => 'Trên màn hình của tôi';

  @override
  String get profileLetContactsSeeIt => 'Cho các liên hệ thấy';

  @override
  String get profileOffByDefault => 'Mặc định tắt';

  @override
  String get profileShareConnect => 'Chia sẻ & kết nối';

  @override
  String get profileMyKryfoCode => 'Mã Kryfo của tôi';

  @override
  String get profileAddContact => 'Thêm liên hệ';

  @override
  String get profileGiveAgain => 'Ủng hộ thêm';

  @override
  String get profileSupportKryfo => 'Ủng hộ Kryfo';

  @override
  String get profileKryfoRunsOnWhat =>
      'Kryfo sống nhờ những gì mọi người đóng góp';

  @override
  String get profileKeepKryfoIndependent => 'Giữ Kryfo độc lập';

  @override
  String get qrLink => 'Liên kết';

  @override
  String get qrYourLinkAsTyped =>
      'ĐÚNG LIÊN KẾT BẠN NHẬP · KHÔNG CHUYỂN HƯỚNG THEO DÕI';

  @override
  String get qrText => 'Văn bản';

  @override
  String get qrStaysInTheCode => 'NẰM TRONG MÃ · KHÔNG MÁY CHỦ NÀO GIỮ NÓ';

  @override
  String get qrWiFi => 'Wi-Fi';

  @override
  String get qrMadeOnThisPhone =>
      'TẠO TRÊN ĐIỆN THOẠI NÀY · KHÔNG TRANG WEB NÀO THẤY MẬT KHẨU';

  @override
  String get qrNetworkName => 'Tên mạng';

  @override
  String get qrPassword => 'Mật khẩu';

  @override
  String get qrContact => 'Liên hệ';

  @override
  String get qrOnlyWhatYouType =>
      'CHỈ NHỮNG GÌ BẠN NHẬP · KHÔNG LẤY GÌ TỪ DANH BẠ';

  @override
  String get qrName => 'Tên';

  @override
  String get qrPhone => 'Điện thoại';

  @override
  String get qrEmail => 'Email';

  @override
  String get qrOpensTheirMailApp =>
      'MỞ ỨNG DỤNG THƯ CỦA HỌ · KHÔNG GỬI GÌ TỪ ĐÂY';

  @override
  String get qrTo => 'Đến';

  @override
  String get qrSubject => 'Tiêu đề';

  @override
  String get qrANumberNothingElse => 'MỘT CON SỐ · KHÔNG GÌ KHÁC';

  @override
  String get qrNumber => 'Số điện thoại';

  @override
  String get qrSms => 'SMS';

  @override
  String get qrOpensTheirMessagesApp =>
      'MỞ ỨNG DỤNG TIN NHẮN CỦA HỌ · KHÔNG GỬI GÌ TỪ ĐÂY';

  @override
  String get qrMessage => 'Tin nhắn';

  @override
  String get qrLocation => 'Vị trí';

  @override
  String get qrCoordinatesOnlyNoMap =>
      'CHỈ TỌA ĐỘ · KHÔNG HỎI DỊCH VỤ BẢN ĐỒ NÀO';

  @override
  String get qrLatitude => 'Vĩ độ';

  @override
  String get qrLongitude => 'Kinh độ';

  @override
  String get qrBitcoin => 'Bitcoin';

  @override
  String get qrAddressAndAmountNo =>
      'ĐỊA CHỈ VÀ SỐ TIỀN · KHÔNG QUA TRANG THANH TOÁN NÀO';

  @override
  String get qrAddress => 'Địa chỉ';

  @override
  String get qrAmountInBtc => 'Số tiền (BTC)';

  @override
  String get qrInk => 'Mực';

  @override
  String get qrAmber => 'Hổ phách';

  @override
  String get qrViolet => 'Tím';

  @override
  String get qrCouldNotDrawThe => 'Không vẽ được hình ảnh.';

  @override
  String get qrSavedToYourGallery => 'Đã lưu vào thư viện ảnh';

  @override
  String get qrCouldNotSaveIt =>
      'Không lưu được. Hãy kiểm tra xem điện thoại còn dung lượng không.';

  @override
  String get qrNoAppOnThis =>
      'Không ứng dụng nào trên điện thoại này nhận hình ảnh.';

  @override
  String get qrTooMuchForOne => 'Quá nhiều cho một mã. Hãy rút ngắn lại.';

  @override
  String get qrThisIsALot =>
      'Nội dung khá nhiều cho một mã. Máy ảnh đời cũ có thể không đọc được.';

  @override
  String get qrPrivateQrCode => 'Mã QR riêng tư';

  @override
  String get qrColour => 'Màu';

  @override
  String get qrCopiedItLeavesThe =>
      'Đã sao chép. Sẽ tự xóa khỏi bộ nhớ tạm sau một phút';

  @override
  String get qrSecurity => 'Bảo mật';

  @override
  String get qrNone => 'Không có';

  @override
  String get qrSaveImage => 'Lưu ảnh';

  @override
  String qrColour2(Object name) {
    return 'Màu $name';
  }

  @override
  String get qrTypeBelowAndThe => 'Nhập bên dưới và\nmã sẽ tự hiện ra';

  @override
  String get qrQrCode => 'Mã QR';

  @override
  String get qrHidePassword => 'Ẩn mật khẩu';

  @override
  String get qrShowPassword => 'Hiện mật khẩu';

  @override
  String get qrCopyPassword => 'Sao chép mật khẩu';

  @override
  String get requestsSentAnAttachment => 'Đã gửi một tệp đính kèm';

  @override
  String get requestsWantsToConnect => 'Muốn kết nối';

  @override
  String get requestsAccepted => 'Đã chấp nhận';

  @override
  String requestsBlock(Object id) {
    return 'Chặn $id?';
  }

  @override
  String get requestsNothingMoreFromThem =>
      'Bạn sẽ không nhận được gì từ họ nữa. Yêu cầu của họ và các tin nhắn trong đó sẽ bị xóa.';

  @override
  String get requestsBlocked => 'đã chặn';

  @override
  String get requestsDeleted => 'đã xóa';

  @override
  String get requestsRequests => 'Yêu cầu';

  @override
  String get requestsNoRequests => 'Chưa có yêu cầu';

  @override
  String get requestsMessagesFromPeopleYou =>
      'Tin nhắn từ những người mà bạn chưa thêm sẽ hiện ở đây trước.';

  @override
  String get requestsLooksSafeNothingSuspicious =>
      'Có vẻ an toàn · tin nhắn đầu tiên của họ không có gì đáng ngờ';

  @override
  String get commonAccept => 'Chấp nhận';

  @override
  String get requestsDecline => 'Từ chối';

  @override
  String get restoreThatFileIsNot => 'Tệp đó không phải bản sao lưu Kryfo';

  @override
  String get restoreThisFileIsDamaged =>
      'Tệp này bị hỏng và không thể đọc được';

  @override
  String get restoreTypeThePassphraseThe =>
      'Nhập cụm mật khẩu đã dùng khi tạo tệp';

  @override
  String get restoreReplaceTheAccountOn =>
      'Thay thế tài khoản trên điện thoại này?';

  @override
  String get restoreWhatIsHereNow =>
      'Những gì đang có ở đây, gồm danh tính, liên hệ và tin nhắn, sẽ bị xóa. Tệp sẽ thế vào chỗ đó. Không thể hoàn tác việc này.';

  @override
  String get restoreReplaceIt => 'Thay thế';

  @override
  String restoreCouldNotBeReleased(Object mine) {
    return 'Không nhả được @$mine';
  }

  @override
  String restoreTheRegistryDidNot(Object mine) {
    return 'Nơi đăng ký không phản hồi. Nếu bạn tiếp tục, @$mine sẽ vẫn trỏ tới danh tính mà điện thoại này sắp mất. Ai thêm tên đó sẽ nhắn tới hư không, và tên đó không thể đăng ký lại. Tốt hơn là hãy kết nối mạng và thử lại lần nữa.';
  }

  @override
  String get restoreRestoreAnyway => 'Vẫn khôi phục';

  @override
  String get restoreNotYet => 'Chưa';

  @override
  String get restoreRestored => 'Đã khôi phục';

  @override
  String restoreKryfoWillCloseNow(Object haloId) {
    return 'Kryfo sẽ đóng ngay bây giờ. Chạm vào biểu tượng để mở lại với tư cách $haloId.';
  }

  @override
  String get restoreReopenKryfo => 'Mở lại Kryfo';

  @override
  String get restoreTheRestoreDidNot =>
      'Khôi phục chưa hoàn tất. Không có gì bị thay đổi';

  @override
  String get restoreThisIdentity => 'danh tính này';

  @override
  String get restoreMoveYourKryfoHere => 'Chuyển Kryfo của bạn sang đây';

  @override
  String restoreThisBackupIsRestoring(Object name) {
    return 'Bản sao lưu này là $name. Khôi phục nó sẽ chuyển danh tính đó sang thiết bị này.';
  }

  @override
  String restoreThisBackupMadeOn(Object name, Object date, Object time) {
    return 'Bản sao lưu này là $name, tạo ngày $date lúc $time. Khôi phục nó sẽ chuyển danh tính đó sang thiết bị này.';
  }

  @override
  String restoreItHoldsOfPhotos(Object mb) {
    return 'Bản sao lưu chứa $mb ảnh, tin nhắn thoại và tệp. Việc này có thể mất vài phút. Hãy để ứng dụng mở.';
  }

  @override
  String get restoreWhatFollows => 'Những gì đi theo';

  @override
  String get restoreYourNameYourCode => 'Tên, mã của bạn, và mọi liên hệ.';

  @override
  String get restoreEveryConversationBackTo =>
      'Mọi cuộc trò chuyện, từ lúc bắt đầu.';

  @override
  String get restoreYourPhotosVoiceNotes =>
      'Ảnh, tin nhắn thoại và tệp của bạn.';

  @override
  String restoreYourPhotosVoiceNotesCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ảnh, tin nhắn thoại và tệp của bạn · $countString.',
    );
    return '$_temp0';
  }

  @override
  String get restoreYourOnionAddressSo =>
      'Địa chỉ onion của bạn, để những người liên lạc trực tiếp với bạn vẫn tiếp tục liên lạc được.';

  @override
  String get restoreAnythingSentToYou =>
      'Mọi thứ được gửi cho bạn khi điện thoại cũ đang tắt, trong vòng mười bốn ngày kể từ khi được gửi.';

  @override
  String get restoreYourSupporterBadgeIf =>
      'Huy hiệu người ủng hộ của bạn, nếu có.';

  @override
  String get restoreWhatDoesnT => 'Những gì ở lại';

  @override
  String get restoreTheOldPhoneStops =>
      'Điện thoại cũ sẽ ngừng nhận ngay khi bạn gửi bất cứ thứ gì từ đây. Không phải từ từ. Tin nhắn đầu tiên bạn gửi từ thiết bị này là tin cuối cùng điện thoại cũ còn theo được, và mọi thứ đến điện thoại cũ sau đó sẽ không đọc được ở đó và cũng không chờ bạn ở đây.';

  @override
  String get restoreIfThePhoneThis =>
      'Nếu điện thoại tạo ra tệp này vẫn đang được dùng, hãy ngừng dùng Kryfo trên đó trước khi tiếp tục. Hai điện thoại dùng chung một Kryfo sẽ mất tin nhắn trên cả hai.';

  @override
  String get restoreNotificationsNeedSettingUp =>
      'Cần thiết lập lại thông báo trên thiết bị này.';

  @override
  String get restoreMoveItHere => 'Chuyển sang đây';

  @override
  String get restoreNotNow => 'Để sau';

  @override
  String get restoreRestore => 'Khôi phục';

  @override
  String get restoreFromABackupFile => 'Từ tệp sao lưu';

  @override
  String get restoreABackupBringsBack =>
      'Bản sao lưu mang lại danh tính, các liên hệ của bạn, và những tin nhắn có trên điện thoại lúc tạo tệp. Những gì nói sau đó không có trong đó.';

  @override
  String get restoreTheFile => 'Tệp';

  @override
  String get restorePickTheBackupFile => 'Chọn tệp sao lưu';

  @override
  String get restoreThePassphrase => 'Cụm mật khẩu';

  @override
  String get restoreTheOneTheFile => 'Cụm đã dùng khi tạo tệp';

  @override
  String get restoreWhatComesBack => 'Những gì được khôi phục';

  @override
  String get restoreChecking => 'Đang kiểm tra…';

  @override
  String get restoreCheckTheFile => 'Kiểm tra tệp';

  @override
  String get restoreReleasingYourHandle => 'Đang nhả tên người dùng…';

  @override
  String restoreMoving(Object progress) {
    return 'Đang chuyển… $progress';
  }

  @override
  String get restoreRestoring => 'Đang khôi phục…';

  @override
  String get restoreNotThisOne => 'Không phải tệp này';

  @override
  String get restoreDateUnknown => 'Không rõ ngày';

  @override
  String get restoreAnIdentity => 'Một danh tính';

  @override
  String get restoreMessagesSentOrReceived =>
      'Tin nhắn gửi hoặc nhận sau ngày đó không có trong tệp này.';

  @override
  String restoreGb(Object bytes) {
    return '$bytes GB';
  }

  @override
  String restoreMb(Object bytes) {
    return '$bytes MB';
  }

  @override
  String get roomCreateCouldNotCreateThe => 'Không tạo được phòng';

  @override
  String get roomCreateBurnerRoom => 'Phòng tạm';

  @override
  String get roomCreateARoomThatEnds =>
      'Một căn phòng có hồi kết. Mọi người tham gia bằng một khóa tạo riêng cho phòng, và khi phòng kết thúc, không còn gì trên bất kỳ điện thoại nào.';

  @override
  String get roomCreateRoomName => 'Tên phòng';

  @override
  String get roomCreateEndsAfter => 'Kết thúc sau';

  @override
  String get roomCreateMemberCap => 'Số người tối đa';

  @override
  String roomCreateNoOnePastThe(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Không ai vào được sau $countString người đầu tiên',
    );
    return '$_temp0';
  }

  @override
  String get roomCreateOffAnyoneWithThe => 'tắt. Bất kỳ ai có liên kết';

  @override
  String roomCreateThisRoomAndEverything(Object expiryWords) {
    return 'Phòng này và mọi thứ trong đó sẽ biến mất sau $expiryWords';
  }

  @override
  String get roomCreateCreating => 'đang tạo...';

  @override
  String get roomCreateCreateRoom => 'Tạo phòng';

  @override
  String get roomLinkSendTheRoomTo => 'Gửi phòng cho';

  @override
  String get roomLinkTheyWillKnowThis =>
      'Họ sẽ biết phòng này đến từ bạn. Bên trong phòng, họ chỉ là một khóa như mọi người khác.';

  @override
  String get roomLinkNoContactsYet => 'Chưa có liên hệ nào';

  @override
  String roomLinkEndsIn(Object time) {
    return 'Kết thúc sau $time';
  }

  @override
  String get roomLinkAnyoneWithThisCan =>
      'Bất kỳ ai có liên kết này đều có thể tham gia cho đến khi phòng kết thúc. Họ vào bằng một khóa tạo riêng cho phòng này, và không thấy gì được gửi trước khi họ đến.';

  @override
  String get roomLinkRoomLinkCopied => 'Đã sao chép liên kết';

  @override
  String get roomLinkSendToAContact => 'Gửi cho một liên hệ';

  @override
  String get roomLinkCopyRoomLink => 'Sao chép liên kết';

  @override
  String get savedVoiceNote => 'tin nhắn thoại';

  @override
  String get savedPhoto => 'ảnh';

  @override
  String get savedSaved => 'Đã lưu';

  @override
  String get savedNothingSavedYet => 'Chưa lưu gì';

  @override
  String get savedLongPressAnyMessage =>
      'nhấn giữ một tin nhắn bất kỳ rồi chạm lưu để giữ nó ở đây.';

  @override
  String get savedViewInChat => 'Xem trong trò chuyện';

  @override
  String get savedPhoto2 => 'Ảnh';

  @override
  String get scanThatSNotA =>
      'Đó không phải mã QR Kryfo · tiếp tục hướng máy ảnh';

  @override
  String get scanScanAKryfoQr => 'Quét mã QR Kryfo';

  @override
  String get scanFlash => 'Đèn flash';

  @override
  String get scanPointAtAKryfo =>
      'Hướng vào mã QR Kryfo · không có gì rời khỏi điện thoại của bạn';

  @override
  String get seenWhatWeCanSee => 'Chúng tôi thấy được gì';

  @override
  String get seenEveryMessengerClaimsPrivacy =>
      'Ứng dụng nhắn tin nào cũng tự nhận là riêng tư. Đây là danh sách cụ thể, theo từng đường đi, kể cả những phần chẳng hay ho gì cho chúng tôi. Chạm vào một dòng để xem lý do.';

  @override
  String get seenHonestAboutTheLast =>
      'Nói thật về mấy dòng cuối: đó là lý do có khóa ứng dụng, mã PIN xóa sạch và bộ nhớ được mã hóa, và không công cụ nào cứu được bạn khỏi người đang cầm điện thoại đã mở khóa của bạn. Mô hình mối đe dọa đầy đủ nằm trong THREAT_MODEL.md trong kho mã, viết theo LINDDUN. Mã nguồn mở, nên bạn không phải tin suông bất cứ điều gì ở đây.';

  @override
  String get seenHidden => 'ẩn';

  @override
  String get seenNever => 'không bao giờ';

  @override
  String get seenOnDevice => 'trên máy';

  @override
  String get seenTiming => 'thời điểm';

  @override
  String get seenYours => 'của bạn';

  @override
  String get seenUnaudited => 'chưa kiểm định';

  @override
  String get seenWhoYouTalkTo => 'Bạn nói chuyện với ai';

  @override
  String get seenEachConversationGetsIts =>
      'Mỗi cuộc trò chuyện có địa chỉ riêng, được suy ra từ khóa của cả hai bên. Relay chỉ thấy những điểm thả không liên quan đến nhau, không thấy một cặp người.';

  @override
  String get seenWhatYouSay => 'Những gì bạn nói';

  @override
  String get seenEndToEndEncrypted =>
      'Được mã hóa đầu cuối bằng double ratchet của Signal, rồi được niêm phong thêm lần nữa trong một lớp bọc gift wrap. Dù có cố, chúng tôi cũng không đọc được.';

  @override
  String get seenYourIpAddress => 'Địa chỉ IP của bạn';

  @override
  String get seenOurRelay => 'relay của Kryfo';

  @override
  String get seenEveryRelay => 'mọi relay';

  @override
  String get seenOnOnionEverythingLeaves =>
      'Ở chế độ onion, mọi thứ đi ra qua tor và relay chỉ thấy một nút thoát, không bao giờ thấy bạn. Ở chế độ relay, kết nối đi thẳng tới relay riêng của chúng tôi: không có gì chuyển tiếp địa chỉ của bạn và không có gì được ghi lại, nhưng riêng kết nối đó thì chúng tôi thấy được. Ở chế độ nhanh, mọi relay công cộng đều biết bạn đã kết nối, nhưng không biết bạn nói chuyện với ai hay nói gì.';

  @override
  String get seenYourContactGraph => 'Mạng liên hệ của bạn';

  @override
  String get seenKryfoDoesNotScan =>
      'Kryfo không quét danh bạ của bạn. Đó chính là mục đích. Ở đây không có số điện thoại nào để bị lộ.';

  @override
  String get seenIntroducer => 'người giới thiệu';

  @override
  String get seenWhenAContactIntroduces =>
      'Khi một liên hệ giới thiệu bạn với ai đó, liên hệ đó biết hai người giờ đã kết nối. Ngoài ra không ai biết. Relay chỉ thấy bản mã, và không máy chủ nào từng thấy mạng liên hệ.';

  @override
  String get seenTheScamShield => 'Lá chắn chống lừa đảo';

  @override
  String get seenRunsOnYourPhone =>
      'Chạy trên điện thoại của bạn với các quy tắc có sẵn trong ứng dụng. Không dùng mạng, không tải danh sách. Nó chỉ đọc tin nhắn đầu tiên từ người lạ và không thể thấy bất cứ thứ gì một liên hệ gửi cho bạn.';

  @override
  String get seenBurnerRooms => 'Phòng tạm';

  @override
  String get seenRoomKeys => 'khóa phòng';

  @override
  String get seenYouJoinARoom =>
      'Bạn vào phòng bằng một khóa tạo riêng cho phòng đó, nên những người bên trong không biết được gì dùng được ở nơi khác. Người vào muộn không thấy lịch sử. Khi hết hạn, khóa, tin nhắn và tệp đa phương tiện đều bị hủy.';

  @override
  String get seenLinkPreviews => 'Xem trước liên kết';

  @override
  String get seenOverTor => 'qua tor';

  @override
  String get seenAPreviewIsFetched =>
      'Bản xem trước do người gửi tải về, qua tor, và đi bên trong tin nhắn được mã hóa. Điện thoại nhận không gửi yêu cầu nào. Trang web chỉ biết có ai đó dùng tor đã yêu cầu một trang, ngoài ra không biết gì. Không bao giờ có hình ảnh nào được tải, và liên kết từ người lạ vẫn chỉ là văn bản thường.';

  @override
  String get seenThatADeviceFetched => 'Việc một thiết bị đã lấy thư';

  @override
  String get seenARelayCanTell =>
      'Relay có thể biết một địa chỉ nào đó đã được kiểm tra, và vào lúc nào. Relay không thể biết đó là của ai, hay từ đâu.';

  @override
  String get seenASeizedUnlockedPhone => 'Điện thoại bị thu giữ lúc mở khóa';

  @override
  String get seenIfSomeoneHoldsYour =>
      'Nếu ai đó cầm điện thoại đang mở khóa của bạn, họ đọc được tin nhắn của bạn. Khóa ứng dụng, mã PIN xóa sạch và bộ nhớ được mã hóa giúp ích trước thời điểm đó, không phải sau đó.';

  @override
  String get seenTheCryptoItself => 'Bản thân mật mã';

  @override
  String get seenTheRatchetAndStorage =>
      'Lớp ratchet và lớp lưu trữ là chuẩn. Lớp nối chúng lại là của chúng tôi và chưa có bên độc lập nào kiểm tra. Hãy coi đây là bản alpha, vì đúng là vậy.';

  @override
  String get seenOnion => 'Onion';

  @override
  String get seenRelay => 'Relay';

  @override
  String get seenFast => 'Nhanh';

  @override
  String get settingsWipeKryfo => 'Xóa sạch Kryfo?';

  @override
  String get settingsIdentityMessagesContactsAnd =>
      'Danh tính, tin nhắn, liên hệ và cài đặt trên điện thoại này. Mất vĩnh viễn trừ khi bạn có bản sao lưu.';

  @override
  String get commonContinue => 'Tiếp tục';

  @override
  String settingsTypeWipeToConfirm(Object word) {
    return 'Nhập “$word” để xác nhận';
  }

  @override
  String get settingsTheLastStepNothing =>
      'Bước cuối cùng. Không gì còn lại sau bước này.';

  @override
  String get settingsWipeWord => 'xóa';

  @override
  String get settingsWipeKryfo2 => 'Xóa sạch Kryfo';

  @override
  String get settingsYourProtections => 'Lớp bảo vệ của bạn';

  @override
  String get settingsTorRouting => 'Định tuyến tor';

  @override
  String get settingsConnecting => 'Đang kết nối';

  @override
  String get settingsOffMode => 'Tắt · chế độ relay';

  @override
  String get settingsOffFastMode => 'Tắt · chế độ nhanh';

  @override
  String get settingsAppLock => 'Khóa ứng dụng';

  @override
  String get settingsBlockedByAndroid => 'Bị Android chặn';

  @override
  String get settingsSpeedPrivacy => 'Tốc độ & riêng tư';

  @override
  String get settingsFast => 'Nhanh';

  @override
  String get settingsRelay1Hop => 'Relay · 1 chặng';

  @override
  String get settingsOnion3Hops => 'Onion · 3 chặng';

  @override
  String get settingsBridges => 'Cầu nối';

  @override
  String get settingsForNetworksThatBlock => 'Cho các mạng chặn tor';

  @override
  String get settingsGettingMessages => 'Nhận tin nhắn';

  @override
  String settingsPreviewHidden(Object deliveryModeName) {
    return '$deliveryModeName · ẩn xem trước';
  }

  @override
  String settingsPreviewShown(Object deliveryModeName) {
    return '$deliveryModeName · hiện xem trước';
  }

  @override
  String get settingsRunInBackground => 'Chạy nền';

  @override
  String get settingsSoMessagesArrive => 'Để tin nhắn đến được';

  @override
  String get settingsTransport => 'Truyền tải';

  @override
  String get settingsWhatTheNetworkIs => 'Mạng đang làm gì';

  @override
  String get settingsBlocked => 'Đã chặn';

  @override
  String get settingsAcceptIntroductions => 'Nhận lời giới thiệu';

  @override
  String get settingsFriendsCanIntroduceYou =>
      'Bạn bè có thể giới thiệu bạn với bạn bè của họ';

  @override
  String get settingsScamShield => 'Lá chắn chống lừa đảo';

  @override
  String get settingsChecksStrangersOnYour =>
      'Kiểm tra người lạ ngay trên điện thoại của bạn. Không có gì rời khỏi máy';

  @override
  String get settingsBlockScreenshots => 'Chặn chụp màn hình';

  @override
  String get settingsWholeAppHiddenFrom =>
      'Toàn bộ ứng dụng được ẩn khỏi danh sách gần đây và ảnh chụp màn hình · có hiệu lực sau lần khởi động tới';

  @override
  String get settingsWholeAppHiddenFromRecentsAnd =>
      'Toàn bộ ứng dụng được ẩn khỏi danh sách gần đây và ảnh chụp màn hình';

  @override
  String get settingsOnNextStart => 'Bật · lần mở tới';

  @override
  String get settingsOffNextStart => 'Tắt · lần mở tới';

  @override
  String get settingsLightTheme => 'Giao diện sáng';

  @override
  String get settingsSameProtectionBrighter => 'Vẫn bảo vệ như vậy, sáng hơn';

  @override
  String get settingsAppLock2 => 'Khóa ứng dụng';

  @override
  String get settingsYourPinAndA => 'Mã PIN và bảo vệ nâng cao';

  @override
  String get settingsPinWipePin => 'PIN · PIN xóa sạch';

  @override
  String get settingsBackUpIdentity => 'Sao lưu danh tính';

  @override
  String get settingsEncryptedFile => 'Tệp được mã hóa';

  @override
  String get settingsRestoreFromBackup => 'Khôi phục từ bản sao lưu';

  @override
  String get settingsReplaceCurrent => 'Thay thế hiện tại';

  @override
  String get settingsDisguiseVoice => 'Đổi giọng';

  @override
  String get settingsShiftsYourPitchBefore =>
      'Đổi cao độ giọng bạn trước khi tin nhắn thoại được gửi đi';

  @override
  String get settingsWhyKryfo => 'Vì sao chọn Kryfo';

  @override
  String get settingsHowItProtectsYou => 'Cách Kryfo bảo vệ bạn';

  @override
  String get settingsResetMyInviteLink => 'Đặt lại liên kết mời';

  @override
  String get settingsOldLinksAndCodes =>
      'Liên kết và mã cũ sẽ ngừng hoạt động, với tất cả mọi người';

  @override
  String get settingsResetInviteLink => 'Đặt lại liên kết mời?';

  @override
  String get settingsAnyoneWithAnOld =>
      'Bất kỳ ai có mã hoặc liên kết cũ sẽ không liên lạc được với bạn nữa, trên mọi đường đi. Những người có nhưng chưa từng dùng sẽ cần bạn gửi mã mới. Liên hệ, cuộc trò chuyện và lịch sử vẫn giữ nguyên.';

  @override
  String get settingsReset => 'Đặt lại';

  @override
  String get settingsInviteResetShareThe =>
      'Đã đặt lại lời mời · hãy chia sẻ mã mới';

  @override
  String get settingsWhatWeCanSee => 'Chúng tôi thấy được gì';

  @override
  String get settingsTheHonestList => 'Danh sách thật thà';

  @override
  String get settingsVersion => 'Phiên bản';

  @override
  String get settings030Alpha => '0.4.1 · alpha';

  @override
  String get settingsReportAnIssue => 'Báo lỗi';

  @override
  String get settingsBugOrSecurityFlaw => 'Lỗi hoặc lỗ hổng bảo mật';

  @override
  String get settingsOpenSource => 'Mã nguồn mở';

  @override
  String get settingsLinkCopied => 'Đã sao chép liên kết';

  @override
  String get settingsTheOfflineMapIn =>
      'Bản đồ ngoại tuyến trong Công cụ được vẽ từ Natural Earth (phạm vi công cộng). Tên địa danh lấy từ GeoNames, geonames.org, theo giấy phép CC BY 4.0.';

  @override
  String get settingsNotIndependentlyAuditedPre =>
      'Chưa được kiểm định độc lập. Bản tiền alpha - phù hợp để thử nghiệm, chưa dành cho mục đích hệ trọng.';

  @override
  String get settingsDangerZone => 'Vùng nguy hiểm';

  @override
  String get settingsWipeKryfoFromThis => 'Xóa sạch Kryfo khỏi điện thoại này';

  @override
  String get shieldCheckedOnThisPhone =>
      'Được kiểm tra trên điện thoại này. Không có gì được gửi đi đâu cả.';

  @override
  String get toolsMoreTools => 'Thêm công cụ';

  @override
  String get toolsCleanAPhotoOr => 'Làm sạch ảnh hoặc video';

  @override
  String get toolsOrShareOneTo => 'Hoặc chia sẻ vào Kryfo từ thư viện ảnh';

  @override
  String get toolsMakeAPrivateQr => 'Tạo mã QR riêng tư';

  @override
  String get toolsLinksWiFiContacts =>
      'Liên kết, Wi-Fi, liên hệ và nhiều thứ khác. Tạo ngoại tuyến';

  @override
  String get toolsLockAFile => 'Khóa tệp';

  @override
  String get toolsWithAPasswordOpens =>
      'Bằng mật khẩu. Mở được ở bất cứ đâu có age';

  @override
  String get toolsOpenALockedFile => 'Mở tệp đã khóa';

  @override
  String get toolsAnyAgeFileSomeone =>
      'Bất kỳ tệp .age nào người khác gửi cho bạn';

  @override
  String get toolsWorksOfflineNoContacts =>
      'Hoạt động ngoại tuyến · không cần liên hệ nào';

  @override
  String get toolsUsefulFrom => 'Hữu ích ngay từ';

  @override
  String get toolsTheFirstMinute => 'phút đầu tiên.';

  @override
  String get toolsEverythingHereHappensOn =>
      'Mọi thứ ở đây diễn ra trên điện thoại này. Không có gì được tải lên, và người khác không cần dùng Kryfo.';

  @override
  String get toolsWhatDoesThisPhoto => 'Ảnh này biết gì?';

  @override
  String get toolsPlacePhoneTime => 'Địa điểm · máy · giờ';

  @override
  String get toolsPickAPhotoAnd =>
      'Chọn một ảnh và xem nó tiết lộ những gì. Sau đó giữ lại một bản sạch.';

  @override
  String get toolsPickAPhoto => 'Chọn ảnh';

  @override
  String get toolsVideo => 'Video';

  @override
  String get transportTransport => 'Truyền tải';

  @override
  String get transportNothingHereLeavesThe =>
      'Không có gì ở đây rời khỏi điện thoại. Đây chính là trạng thái mà bộ máy dùng để quyết định việc cần làm.';

  @override
  String get transportStayingAlive => 'duy trì hoạt động';

  @override
  String get transportCanSend => 'gửi được';

  @override
  String get commonYes => 'Có';

  @override
  String get transportNotYet => 'Chưa';

  @override
  String get transportOnline => 'Trực tuyến';

  @override
  String get transportOffline => 'Ngoại tuyến';

  @override
  String get transportQueuedToSend => 'chờ gửi';

  @override
  String get transportOnionPublished => 'Đã công bố onion';

  @override
  String transportYes(Object uploads) {
    return 'Có ($uploads)';
  }

  @override
  String transportTryingS(Object pubFor) {
    return 'Đang thử ${pubFor}s';
  }

  @override
  String transportBenchedS(Object r) {
    return 'Tạm nghỉ ${r}s';
  }

  @override
  String transportFails(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString lần lỗi',
    );
    return '$_temp0';
  }

  @override
  String get transportOk => 'ok';

  @override
  String get transportRelaySubscriptions => 'Đăng ký relay';

  @override
  String get transportLastSent => 'gửi lần cuối';

  @override
  String get transportNever => 'Chưa bao giờ';

  @override
  String transportSAgo(Object sx) {
    return '${sx}s trước';
  }

  @override
  String get transportLastReceived => 'nhận lần cuối';

  @override
  String transportSAgo2(Object rx) {
    return '${rx}s trước';
  }

  @override
  String get transportWithNoContactsThe =>
      'Khi không có liên hệ nào, ứng dụng không đăng ký địa chỉ relay nào, nên không tin nhắn nào đến được với bạn. Hãy quét mã của ai đó để khắc phục.';

  @override
  String get transportSendAnythingWaitingNow =>
      'Gửi mọi thứ đang chờ, ngay bây giờ';

  @override
  String get transportOff => 'tắt';

  @override
  String get transportStarting => 'đang khởi động';

  @override
  String get transportBootstrapped => 'đã khởi tạo xong';

  @override
  String get transportPublishingAddress => 'Đang công bố địa chỉ';

  @override
  String get transportReachable => 'liên lạc được';

  @override
  String get transportOurRelayOnion => 'relay của Kryfo (onion)';

  @override
  String get transportNever2 => 'chưa bao giờ';

  @override
  String get transportJustNow => 'Vừa xong';

  @override
  String transportMAgo(Object inMinutes) {
    return '$inMinutes phút trước';
  }

  @override
  String transportHAgo(Object inHours) {
    return '$inHours giờ trước';
  }

  @override
  String transportDAgo(Object inDays) {
    return '$inDays ngày trước';
  }

  @override
  String transportM(Object inMinutes) {
    return '$inMinutes phút';
  }

  @override
  String transportHM(Object inHours, Object d) {
    return '$inHours giờ $d phút';
  }

  @override
  String transportD(Object inDays) {
    return '$inDays ngày';
  }

  @override
  String transportMb(Object b) {
    return '$b mb';
  }

  @override
  String get transportYesCheckedJustNow => 'Có · vừa kiểm tra';

  @override
  String transportNoLast(Object ago) {
    return 'Không · lần cuối $ago';
  }

  @override
  String get transportLastMessageIn => 'Tin nhắn đến gần nhất';

  @override
  String get transportBatteryExemption => 'Miễn tối ưu pin';

  @override
  String get transportUnknown => 'không rõ';

  @override
  String get transportExempt => 'được miễn';

  @override
  String get transportNotExemptTapTo => 'Chưa được miễn · chạm để sửa';

  @override
  String get transportProcessUp => 'tiến trình đã chạy';

  @override
  String get transportLastStop => 'lần dừng cuối';

  @override
  String transportEngine(Object mb, Object mb2) {
    return '$mb · bộ máy $mb2';
  }

  @override
  String get transportLastRelayArrival => 'Lần cuối nhận từ relay';

  @override
  String get transportLastCheckIn => 'lần kiểm tra cuối';

  @override
  String get transportNoneYet => 'Chưa có';

  @override
  String get transportLastTorReconnect => 'lần cuối tor kết nối lại';

  @override
  String get transportCatchUpByRelay => 'bắt kịp theo relay';

  @override
  String get transportControlPort => 'cổng điều khiển';

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
      other: '$dialsString lần kết nối',
    );
    String _temp1 = intl.Intl.pluralLogic(
      timeouts,
      locale: localeName,
      other: '$timeoutsString lần quá giờ',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get transportJobRuns => 'lượt chạy tác vụ';

  @override
  String transportLast(Object jobRuns, Object ago) {
    return '$jobRuns · lần cuối $ago';
  }

  @override
  String get transportQuietStretches => 'Những quãng im lặng';

  @override
  String get transportNone => 'Không có';

  @override
  String get transportClearThisRecord => 'Xóa bản ghi này';

  @override
  String get transportNothingYetThisProcess =>
      'Chưa có gì trong tiến trình này';

  @override
  String transportM2(Object mins) {
    return '$mins phút';
  }

  @override
  String transportHM2(Object mins, Object mins2) {
    return '$mins giờ $mins2 phút';
  }

  @override
  String transportTo(Object t, Object t2) {
    return '$t đến $t2';
  }

  @override
  String vouchersVouchedBy(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'được bảo chứng bởi $countString người',
      one: 'được bảo chứng bởi',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperAtmosphere => 'Khung cảnh';

  @override
  String get wallpaperJustForYouThey =>
      'Chỉ dành cho bạn. Họ thấy hình nền của riêng họ.';

  @override
  String get wallpaperYourPhoto => 'ảnh của bạn';

  @override
  String get wallpaperFromYourPhotos => 'Từ thư viện ảnh';

  @override
  String get wallpaperKeepIt => 'Giữ lại';

  @override
  String get whyKryfoWhyKryfo => 'Vì sao chọn Kryfo';

  @override
  String get whyKryfoKryfoKreeFoGreek =>
      'Kryfo · KREE-fo · tiếng Hy Lạp nghĩa là ẩn giấu.\nMột nơi yên tĩnh để trò chuyện, được làm ra để không ai theo dõi.';

  @override
  String get whyKryfoRoutedThroughTor => 'Định tuyến qua tor';

  @override
  String get whyKryfoByDefaultEveryMessage =>
      'Theo mặc định, mọi tin nhắn đi qua tor - một chuỗi các relay. Không ai, kể cả chúng tôi hay bên vận hành mạng của bạn, có thể thấy bạn nói chuyện với ai hay bạn đang ở đâu.';

  @override
  String get whyKryfoEndToEndEncrypted => 'Được mã hóa đầu cuối';

  @override
  String get whyKryfoMessagesAreSealedWith =>
      'Tin nhắn được mã hóa bằng những khóa mà chỉ bạn và người đang trò chuyện với bạn nắm giữ. Dù có cố, chúng tôi cũng không đọc được.';

  @override
  String get whyKryfoNoServersHoldingYour =>
      'Không máy chủ nào nắm giữ cuộc sống của bạn';

  @override
  String get whyKryfoNoAccountNoPhone =>
      'Không tài khoản, không số điện thoại, không máy chủ trung tâm lưu các cuộc trò chuyện của bạn. Chúng nằm trên điện thoại này, được mã hóa khi lưu trữ.';

  @override
  String get whyKryfoNothingLeaks => 'Không gì bị lộ';

  @override
  String get whyKryfoNoReadReceiptsOr =>
      'Không trao cho ai thông báo đã đọc hay dấu hiệu đang gõ, không tải danh bạ lên. Siêu dữ liệu là thứ hầu hết ứng dụng để lộ - Kryfo được xây dựng để không như vậy.';

  @override
  String get whyKryfoVerifyItIsReally => 'Xác minh đúng là họ';

  @override
  String get whyKryfoCompareASafetyNumber =>
      'So sánh số an toàn trực tiếp hoặc qua một kênh bạn tin tưởng, để biết chắc không ai đang mạo danh liên hệ của bạn.';

  @override
  String get whyKryfoTheHonestPart => 'Phần nói thật';

  @override
  String get whyKryfoKryfoIsPreAlpha =>
      'Kryfo đang ở giai đoạn tiền alpha và chưa được kiểm định. Mật mã là thật nhưng chưa chuyên gia bên ngoài nào kiểm tra, nên hãy coi đây là sản phẩm đang hoàn thiện, chưa phải thứ để giao phó tính mạng của bạn.';

  @override
  String get cleanerLocation => 'Vị trí';

  @override
  String get cleanerAlreadyBlankedByAndroid => 'đã bị Android xóa trắng';

  @override
  String get cleanerPhoneModel => 'Mẫu điện thoại';

  @override
  String get cleanerTimeTaken => 'Thời điểm chụp';

  @override
  String get cleanerSerialNumber => 'Số sê-ri';

  @override
  String get cleanerOwnerName => 'Tên chủ sở hữu';

  @override
  String get cleanerHiddenThumbnail => 'Ảnh thu nhỏ ẩn';

  @override
  String get cleanerContentCredentials => 'Thông tin xác thực nội dung';

  @override
  String get cleanerDataAfterThePicture => 'Dữ liệu sau phần ảnh';

  @override
  String cleaner1OtherField(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString trường khác',
    );
    return '$_temp0';
  }

  @override
  String get lockWordsFourRandomWordsBeat =>
      'Bốn từ ngẫu nhiên tốt hơn một từ khéo léo.';

  @override
  String lockWordsTooShortAtLeast(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Quá ngắn. Ít nhất $countString ký tự.',
    );
    return '$_temp0';
  }

  @override
  String get lockWordsWeakWhoeverGetsThe =>
      'Yếu. Ai có được tệp đều có thể đoán nhanh tùy thích.';

  @override
  String get lockWordsFairLongerIsStronger => 'Tạm được. Càng dài càng mạnh.';

  @override
  String get lockWordsStrongFourRandomWords =>
      'Mạnh. Bốn từ ngẫu nhiên tốt hơn một từ khéo léo.';

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
      other: '$countString mét',
    );
    return '$_temp0';
  }

  @override
  String get photoStoryFarFromAnyTown => 'Xa mọi thị trấn';

  @override
  String photoStoryNear(Object where) {
    return 'Gần $where';
  }

  @override
  String photoStoryAboutKmFrom(Object near, Object where) {
    return 'Cách $where khoảng $near km';
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
  String get photoStoryNotAKindKryfo => 'Kryfo không đọc được loại này.';

  @override
  String get photoStorySoItWillNot => 'Nên sẽ không đoán mò.';

  @override
  String get photoStoryThisFileIsDamaged => 'Tệp này bị hỏng hoặc bị cắt cụt.';

  @override
  String get photoStoryKryfoCouldNotRead =>
      'Kryfo không đọc được đến cuối tệp.';

  @override
  String get photoStoryWhereItWasRecorded => 'Nơi quay';

  @override
  String get photoStoryWhereItWasTaken => 'Nơi chụp';

  @override
  String photoStoryLocation(Object coordsLine) {
    return 'Vị trí: $coordsLine';
  }

  @override
  String photoStoryHeightAboveTheSea(Object fix) {
    return 'Độ cao so với mực nước biển: $fix m';
  }

  @override
  String get photoStoryLocationHiddenByAndroid => 'Vị trí bị Android ẩn đi';

  @override
  String get photoStoryAndroidBlanksItWhen =>
      'Android xóa trắng thông tin này khi ảnh được chọn theo cách này. Chia sẻ ảnh vào Kryfo từ thư viện ảnh thường giữ lại được. Ảnh trong thư viện của bạn có thể vẫn còn thông tin này.';

  @override
  String get photoStoryLocationBlankedByAndroid =>
      'Vị trí: đã bị Android xóa trắng trước khi Kryfo thấy';

  @override
  String photoStoryF(Object r) {
    return 'f/$r';
  }

  @override
  String get photoStoryWhatTookIt => 'Thiết bị chụp';

  @override
  String photoStoryPhoneOrCamera(Object phone) {
    return 'Điện thoại hoặc máy ảnh: $phone';
  }

  @override
  String get photoStoryWhenItWasRecorded => 'Thời điểm quay';

  @override
  String get photoStoryToTheSecondWith => 'Đến từng giây, kèm múi giờ';

  @override
  String get photoStoryToTheSecond => 'Đến từng giây';

  @override
  String photoStoryTime(Object dateFormat) {
    return 'Thời gian: $dateFormat';
  }

  @override
  String get photoStoryLens => 'Ống kính';

  @override
  String photoStoryLens2(Object lens) {
    return 'Ống kính: $lens';
  }

  @override
  String get photoStorySoftware => 'Phần mềm';

  @override
  String photoStorySoftware2(Object software) {
    return 'Phần mềm: $software';
  }

  @override
  String get photoStorySerialNumber => 'Số sê-ri';

  @override
  String photoStorySerialNumber2(Object serial) {
    return 'Số sê-ri: $serial';
  }

  @override
  String get photoStoryOwnerName => 'Tên chủ sở hữu';

  @override
  String photoStoryOwner(Object r) {
    return 'Chủ sở hữu: $r';
  }

  @override
  String get photoStoryHiddenThumbnail => 'Ảnh thu nhỏ ẩn';

  @override
  String get photoStoryASmallCopyOf =>
      'Một bản nhỏ của ảnh nằm trong tệp. Nó có thể cho thấy phần đã bị cắt đi';

  @override
  String get photoStoryMakerNotes => 'Ghi chú của hãng';

  @override
  String get photoStoryMakerNotesABlock =>
      'Ghi chú của hãng: một khối dữ liệu chỉ hãng sản xuất đọc được';

  @override
  String get photoStoryEditingHistory => 'Lịch sử chỉnh sửa';

  @override
  String get photoStoryXmpEditingHistoryAnd => 'XMP: lịch sử chỉnh sửa và thẻ';

  @override
  String get photoStoryCaptions => 'Chú thích';

  @override
  String get photoStoryIptcCaptionsAndCredits => 'IPTC: chú thích và ghi công';

  @override
  String get photoStoryComment => 'Nhận xét';

  @override
  String get photoStoryAWrittenComment => 'Một lời nhận xét';

  @override
  String get photoStoryContentCredentials => 'Thông tin xác thực nội dung';

  @override
  String get photoStorySecondPicture => 'Ảnh thứ hai';

  @override
  String get photoStoryASecondPictureInside => 'Một ảnh thứ hai nằm trong tệp';

  @override
  String get photoStoryMotionVideo => 'Video chuyển động';

  @override
  String get photoStoryAShortVideoInside => 'Một đoạn video ngắn nằm trong tệp';

  @override
  String get photoStorySaveTime => 'Thời điểm lưu';

  @override
  String get photoStoryTheTimeItWas => 'Thời điểm tệp được lưu lần cuối';

  @override
  String get photoStoryTimeStamps => 'Dấu thời gian';

  @override
  String get photoStoryCreationTimeStamps => 'Dấu thời gian tạo';

  @override
  String get photoStoryDataAfterThePicture => 'Dữ liệu sau phần ảnh';

  @override
  String photoStoryDataAfterTheEnd(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Dữ liệu sau phần cuối ảnh: $countString byte',
    );
    return '$_temp0';
  }

  @override
  String photoStoryTextField(Object k) {
    return 'Trường văn bản: $k';
  }

  @override
  String photoStoryVideoTag(Object k) {
    return 'Thẻ video: $k';
  }

  @override
  String photoStoryAlso(Object k) {
    return 'Ngoài ra: $k';
  }

  @override
  String photoStoryCameraSettingsFlashFocus(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString thiết lập máy ảnh (đèn flash, lấy nét, phơi sáng)',
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
      other: '$countString trường nữa',
    );
    return '$_temp0';
  }

  @override
  String get photoStoryCameraSettings => 'Thiết lập máy ảnh';

  @override
  String photoStoryAccurateToAbout(Object metres) {
    return 'Chính xác trong khoảng $metres.';
  }

  @override
  String get photoStoryEnoughToFindThe => 'Đủ để tìm đến tận cửa.';

  @override
  String get photoStoryEnoughToFindTheStreet => 'Đủ để tìm ra con phố.';

  @override
  String get photoStoryEnoughToFindTheArea => 'Đủ để tìm ra khu vực.';

  @override
  String get photoStoryItKnowsWhereYou => 'Nó biết bạn đã ở đâu.';

  @override
  String get photoStoryDownToTheBuilding => 'Chính xác đến từng tòa nhà.';

  @override
  String get photoStoryAndroidHidTheLocation => 'Android đã ẩn vị trí.';

  @override
  String get photoStoryTheOriginalMayStill =>
      'Bản gốc có thể vẫn còn chứa vị trí.';

  @override
  String get photoStoryNoLocationInThis => 'Ảnh này không có vị trí.';

  @override
  String get photoStoryItStillSaysPlenty => 'Nó vẫn nói lên khá nhiều.';

  @override
  String get photoStoryThisOneKnowsNothing => 'Ảnh này không biết gì cả.';

  @override
  String get photoStoryNothingToRemove => 'Không có gì để gỡ bỏ.';

  @override
  String get qrPayloadOpensALink => 'MỞ MỘT LIÊN KẾT';

  @override
  String qrPayloadOpens(Object host) {
    return 'MỞ $host';
  }

  @override
  String get qrPayloadShowsANote => 'HIỆN MỘT GHI CHÚ';

  @override
  String get qrPayloadScanToJoin => 'QUÉT ĐỂ KẾT NỐI';

  @override
  String qrPayloadScanToJoin2(Object oneLine) {
    return 'QUÉT ĐỂ KẾT NỐI · $oneLine';
  }

  @override
  String get qrPayloadANetworkNameIs => 'Tên mạng dài tối đa 32 ký tự.';

  @override
  String get qrPayloadAWiFiPassword =>
      'Mật khẩu Wi-Fi phải có ít nhất 8 ký tự.';

  @override
  String get qrPayloadSavesAContact => 'LƯU MỘT LIÊN HỆ';

  @override
  String get qrPayloadWritesAnEmail => 'SOẠN MỘT EMAIL';

  @override
  String get qrPayloadThatDoesNotLook => 'Đó không giống địa chỉ email.';

  @override
  String get qrPayloadCallsANumber => 'GỌI MỘT SỐ';

  @override
  String get qrPayloadWritesAText => 'SOẠN MỘT TIN NHẮN';

  @override
  String get qrPayloadOpensAMap => 'MỞ BẢN ĐỒ';

  @override
  String get qrPayloadLatitudeRunsFrom90 =>
      'Vĩ độ từ -90 đến 90, kinh độ từ -180 đến 180.';

  @override
  String get qrPayloadPayThisAddress => 'TRẢ TIỀN CHO ĐỊA CHỈ NÀY';

  @override
  String get qrPayloadABitcoinAddressIs =>
      'Địa chỉ bitcoin chỉ gồm chữ cái và chữ số.';

  @override
  String get qrPayloadTheAmountIsIn =>
      'Số tiền tính bằng BTC, tối đa 8 chữ số thập phân.';

  @override
  String vouchTextAnd(Object names, Object names2) {
    return '$names và $names2';
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
      other: '$restString người khác',
    );
    return '$names, $names2 và $_temp0 mà bạn biết';
  }

  @override
  String vouchTextVouchedBy(Object vouchNames) {
    return 'Được bảo chứng bởi $vouchNames';
  }

  @override
  String vouchTextIntroducedBy(Object vouchNames) {
    return 'Do $vouchNames giới thiệu';
  }

  @override
  String vouchTextThisSharesSAddress(Object a, Object b) {
    return 'Việc này sẽ chia sẻ địa chỉ của $a với $b';
  }

  @override
  String get bootFailedKryfoCouldNotStart => 'Kryfo không khởi động được';

  @override
  String get bootFailedThisIsAFault =>
      'Đây là lỗi trên thiết bị này, không phải do mạng. Tor không liên quan.';

  @override
  String get kryfoLinkTextThatLinkIsNot => 'Kryfo không đọc được liên kết đó';

  @override
  String kryfoLinkTextAdd(Object who) {
    return 'Thêm $who?';
  }

  @override
  String kryfoLinkTextThisIsAnInvite(Object who) {
    return 'Đây là lời mời trò chuyện với $who. Chỉ thêm họ nếu bạn biết liên kết này đến từ đâu.';
  }

  @override
  String get kryfoLinkTextAddThem => 'Thêm họ';

  @override
  String get kryfoLinkTextNotNow => 'Để sau';

  @override
  String kryfoLinkTextJoin(Object roomName) {
    return 'Tham gia $roomName';
  }

  @override
  String get kryfoLinkTextKryfoLink => 'liên kết Kryfo';

  @override
  String kryfoLinkTextAdd2(Object who) {
    return 'Thêm $who';
  }

  @override
  String get kryfoLinkTextBurnerRoom => 'PHÒNG TẠM';

  @override
  String get kryfoLinkTextThisRoomHasClosed => 'Phòng này đã đóng';

  @override
  String kryfoLinkTextClosesIn(Object time) {
    return 'Đóng sau $time';
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
      other: 'Đóng sau $time · tối đa $capString người',
    );
    return '$_temp0';
  }

  @override
  String get kryfoLinkTextJoin2 => 'Tham gia';

  @override
  String get kryfoLinkTextYouJoinUnderA =>
      'Bạn tham gia bằng một khóa tạo riêng cho phòng này. Không ai trong phòng thấy ID Kryfo của bạn.';

  @override
  String get linkStubFetchedOverTorBy => 'Tải qua tor · bởi thiết bị của bạn';

  @override
  String get linkStubFetchedOverTorByTheirDevice =>
      'Tải qua tor · bởi thiết bị của họ';

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
  String get mediaBubblesFile => 'TỆP';

  @override
  String get mediaBubblesAudioUnavailable => 'Âm thanh không khả dụng';

  @override
  String get mediaBubblesHidden => 'Đã ẩn';

  @override
  String get mediaBubblesMicPermissionNeeded => 'Cần quyền micrô';

  @override
  String get mediaBubblesReleaseToCancel => 'Thả tay để hủy';

  @override
  String get mediaBubblesVoiceHiddenSlideTo =>
      'Giọng đã được che · trượt để hủy';

  @override
  String get mediaBubblesSlideToCancel => 'Trượt để hủy';

  @override
  String get mediaBubblesSendPhoto => 'Gửi ảnh';

  @override
  String get mediaBubblesAddACaption => 'Thêm chú thích…';

  @override
  String get motionStandby => 'CHỜ';

  @override
  String get motionConnecting => 'ĐANG KẾT NỐI';

  @override
  String get motionBuilding => 'ĐANG DỰNG';

  @override
  String get motionPublishing => 'ĐANG CÔNG BỐ';

  @override
  String get motionReady => 'SẴN SÀNG';

  @override
  String get motionPreparingToConnect => 'Đang chuẩn bị kết nối';

  @override
  String get motionFindingAPrivatePath => 'Đang tìm đường riêng tư';

  @override
  String get motionCarvingThePath => 'Đang mở đường';

  @override
  String get motionAnnouncingYourArrival => 'Đang báo bạn đã đến';

  @override
  String get motionYouReAnonymous => 'bạn đang ẩn danh';

  @override
  String get motionTorIsStartingIn =>
      'Tor đang khởi động ở chế độ nền. Biểu đồ này sẽ sáng lên khi kết nối hình thành.';

  @override
  String get motionMakingAFreshRoute =>
      'Đang tạo một tuyến đường mới qua các relay ẩn danh.';

  @override
  String get motionBouncingThroughRelaysSo =>
      'Đi vòng qua các relay để không ai lần ngược được về bạn.';

  @override
  String get motionTellingTheNetworkYou =>
      'đang báo với mạng rằng bạn trực tuyến — mà không tiết lộ bạn ở đâu.';

  @override
  String get motionYourIpIsHidden =>
      'IP của bạn được ẩn. Chỉ những người có Kryfo của bạn mới liên lạc được với bạn.';

  @override
  String get motionBuilding2 => 'đang dựng';

  @override
  String get motionOpen => 'mở';

  @override
  String get motionLive => 'hoạt động';

  @override
  String motionCircuit(Object circuit) {
    return 'Mạch · *$circuit*';
  }

  @override
  String get motionDelivered => 'đã nhận';

  @override
  String get motionSent => 'đã gửi';

  @override
  String get motion1Hop => '1 chặng';

  @override
  String get motion3Hops => '3 chặng';

  @override
  String get movedStripThisKryfoHasMoved =>
      'Kryfo này đã chuyển sang thiết bị khác. Không gì gửi từ đây đến được với ai.';

  @override
  String get navBarChats => 'Trò chuyện';

  @override
  String get navBarTools => 'Công cụ';

  @override
  String get navBarSupport => 'Ủng hộ';

  @override
  String get navBarMe => 'Tôi';

  @override
  String get pairCodePanelPuttingYourInviteIn =>
      'Đang chuẩn bị lời mời của bạn';

  @override
  String get pairCodePanelYourInviteIsNot => 'Lời mời của bạn chưa sẵn sàng';

  @override
  String get pairCodePanelReadSixDigitsOut =>
      'Đọc to sáu chữ số là họ có thể thêm bạn. Không cần trao đổi gì khác.';

  @override
  String get pairCodePanelWorking => 'Đang xử lý';

  @override
  String get pairCodePanelOrMakeASix => 'Hoặc tạo mã sáu chữ số để đọc to';

  @override
  String get pairCodePanelCodeCopied => 'Đã sao chép mã';

  @override
  String pairCodePanelBurnsIn(Object mm, Object ss) {
    return 'Tự hủy sau $mm:$ss';
  }

  @override
  String get pairCodePanelTheyTapAddChoose =>
      'Họ chạm Thêm, chọn Mã, rồi nhập các số này.';

  @override
  String get pairCodePanelTheyOpenKryfoTap =>
      'Họ mở Kryfo, chạm Thêm, chọn Mã ghép nối rồi nhập sáu chữ số này. Hãy tạo mã mới cho người tiếp theo.';

  @override
  String pinsPinnedMessages(Object count) {
    return 'Tin nhắn đã ghim · $count';
  }

  @override
  String get pinsPinnedMessages2 => 'Tin nhắn đã ghim';

  @override
  String get pinsPhoto => 'Ảnh';

  @override
  String get pinsVoiceMessage => 'Tin nhắn thoại';

  @override
  String get pinsMessage => 'Tin nhắn';

  @override
  String pinsToday(Object hm) {
    return 'Hôm nay · $hm';
  }

  @override
  String get pinsPinned => 'Đã ghim';

  @override
  String pinsOf(Object pinsLength, Object kMaxPins) {
    return '$pinsLength trên $kMaxPins';
  }

  @override
  String get pinsNothingPinnedHereYet =>
      'Chưa có gì được ghim ở đây. Nhấn giữ một tin nhắn và chọn Ghim, tin nhắn sẽ nằm ở đây cho mọi người trong cuộc trò chuyện.';

  @override
  String get pinsJump => 'Đi tới';

  @override
  String get pinsUnpin => 'Bỏ ghim';

  @override
  String powNoteFirstMessageToSomeone(int secs) {
    final intl.NumberFormat secsNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String secsString = secsNumberFormat.format(secs);

    return 'Tin nhắn đầu tiên tới người mới · đang chứng minh là thật · ${secsString}s';
  }

  @override
  String powNoteFirstMessageSlow(int secs) {
    final intl.NumberFormat secsNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String secsString = secsNumberFormat.format(secs);

    return 'Tin nhắn đầu tiên tới người mới · đang chứng minh là thật · ${secsString}s · có thể tới một phút trên máy chậm';
  }

  @override
  String previewStripFetchedOverTor(Object domainOf) {
    return '$domainOf · tải qua tor';
  }

  @override
  String get previewStripDropThePreview => 'Bỏ xem trước';

  @override
  String get previewStripAddPreview => 'Thêm xem trước';

  @override
  String get previewStripFetchingOverTor => 'Đang tải qua tor…';

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
  String get torBootSplashNoShortcutsNoTraces => 'Không lối tắt, không dấu vết';

  @override
  String get torBootSplashTheNetworkThatKeeps =>
      'Mạng lưới giữ riêng tư cho bạn đang khởi động';

  @override
  String get torBootSplashMadeOnThisPhone =>
      'Được tạo trên điện thoại này. Không có gì được gửi đi đâu cả.';

  @override
  String get torBootSplashFirstLaunchTakesA =>
      'Lần mở đầu tiên mất một lúc · chỉ khi khởi động';

  @override
  String get videoBubbleNothingHereOpensThat =>
      'Không có gì ở đây mở được tệp đó · chuyển sang chia sẻ';

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
  String get notificationsChannelName => 'tin nhắn';

  @override
  String get cameraClose => 'Đóng';

  @override
  String get cameraFlash => 'đèn flash';

  @override
  String get cameraPhoto => 'ảnh';

  @override
  String get cameraVideo => 'video';

  @override
  String get cameraRetake => 'Chụp lại';

  @override
  String get seenIntroductions => 'Lời giới thiệu';

  @override
  String get donateAddress => 'địa chỉ';

  @override
  String get donateCopy => 'Sao chép';

  @override
  String get donateDone => 'Xong';

  @override
  String get donateTierSupporter => 'người ủng hộ';

  @override
  String get donateTierPatron => 'nhà bảo trợ';

  @override
  String get donateTierGuardian => 'người bảo hộ';

  @override
  String get chatBlock => 'Chặn';

  @override
  String get chatDecline => 'Từ chối';

  @override
  String get chatAccept => 'Chấp nhận';

  @override
  String get bridgesConnecting => 'đang kết nối';

  @override
  String get restoreMade => 'ngày tạo';

  @override
  String get restoreContacts => 'liên hệ';

  @override
  String get restoreMessages => 'tin nhắn';

  @override
  String get restoreAttachments => 'tệp đính kèm';

  @override
  String get restoreHiddenChats => 'trò chuyện ẩn';

  @override
  String get restoreHiddenFollow =>
      'Trò chuyện ẩn của bạn, với mã PIN trò chuyện ẩn mới mà bạn sẽ chọn ở bước cuối.';

  @override
  String get restoreChooseHiddenPin =>
      'Bản sao lưu này có trò chuyện ẩn. Hãy chọn mã PIN trò chuyện ẩn cho chúng.';

  @override
  String get restoreHiddenLockFirst =>
      'Trò chuyện ẩn cần khóa ứng dụng, nên trước tiên Kryfo sẽ có mã PIN riêng.';

  @override
  String get shieldBlock => 'Chặn';

  @override
  String get shieldDelete => 'Xóa';

  @override
  String get shieldIgnore => 'Bỏ qua';

  @override
  String get profileIdentity => 'Danh tính';

  @override
  String get avatarPickerShape => 'Hình dạng';

  @override
  String get avatarPickerColour => 'Màu';

  @override
  String get avatarPickerTurn => 'Xoay';

  @override
  String get transportStatus => 'trạng thái';

  @override
  String get transportBootstrap => 'khởi tạo';

  @override
  String get transportNetwork => 'mạng';

  @override
  String get transportConnectivity => 'kết nối';

  @override
  String get transportRelays => 'relay';

  @override
  String get transportTraffic => 'lưu lượng';

  @override
  String get transportContacts => 'liên hệ';

  @override
  String get transportKnown => 'đã biết';

  @override
  String get transportListening => 'đang nghe';

  @override
  String get transportMemory => 'bộ nhớ';

  @override
  String get settingsConnected => 'Đã kết nối';

  @override
  String get settingsScreenshots => 'Chụp màn hình';

  @override
  String get settingsBlocked2 => 'Đã chặn';

  @override
  String get settingsAllowed => 'Cho phép';

  @override
  String get settingsOn => 'Bật';

  @override
  String get settingsOff => 'Tắt';

  @override
  String get settingsNotifications => 'Thông báo';

  @override
  String get settingsPrivacy => 'Quyền riêng tư';

  @override
  String get settingsSecurity => 'Bảo mật';

  @override
  String get settingsBackup => 'Sao lưu';

  @override
  String get settingsVoice => 'Giọng nói';

  @override
  String get settingsAbout => 'Giới thiệu';

  @override
  String get wallpaperGradients => 'chuyển màu';

  @override
  String get wallpaperPatterns => 'họa tiết';

  @override
  String get wallpaperMoods => 'tâm trạng';

  @override
  String get confirmSheetKeep => 'Giữ';

  @override
  String get confirmSheetSave => 'Lưu';

  @override
  String get confirmSheetCancel => 'Hủy';

  @override
  String bridgesSaved(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString cầu nối',
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

    return '$goodString được chấp nhận, $badString không hiểu được';
  }

  @override
  String get languageTitle => 'Ngôn ngữ';

  @override
  String get languageMatchPhone => 'Theo điện thoại';

  @override
  String languageMatchPhoneValue(Object language) {
    return 'Theo điện thoại ($language)';
  }

  @override
  String get languageRedrawLine =>
      'Kryfo sẽ hiển thị lại bằng ngôn ngữ mới và mở ở màn hình trò chuyện.';

  @override
  String languageButton(Object language) {
    return 'Ngôn ngữ: $language';
  }

  @override
  String get androidServiceTitle => 'Kryfo đang bật';

  @override
  String get androidServiceText =>
      'đường truyền được mã hóa của bạn luôn mở để tin nhắn đến được';

  @override
  String get androidChannelName => 'duy trì kết nối';

  @override
  String get androidChannelDescription =>
      'giữ Kryfo kết nối để tin nhắn được mã hóa vẫn đến khi ứng dụng đang đóng. tắt mục này sẽ dừng việc nhận tin.';

  @override
  String get videoViewerPlay => 'Phát';

  @override
  String get videoViewerPause => 'Tạm dừng';

  @override
  String get videoViewerPlayAgain => 'Phát lại';

  @override
  String get videoViewerCannotPlay =>
      'Điện thoại này không phát được video này ở đây.';

  @override
  String get videoViewerOpenElsewhere => 'Mở bằng ứng dụng khác';

  @override
  String get photoKnowsLookedFor => 'Đã tìm';

  @override
  String get photoKnowsNotInIt => 'không có';

  @override
  String get languageNameEn => 'Tiếng Anh';

  @override
  String get languageNameDe => 'Tiếng Đức';

  @override
  String get languageNameFr => 'Tiếng Pháp';

  @override
  String get languageNameEs => 'Tiếng Tây Ban Nha';

  @override
  String get languageNamePt => 'Tiếng Bồ Đào Nha (Brazil)';

  @override
  String get languageNameIt => 'Tiếng Ý';

  @override
  String get languageNameRu => 'Tiếng Nga';

  @override
  String get languageNameUk => 'Tiếng Ukraina';

  @override
  String get languageNameTr => 'Tiếng Thổ Nhĩ Kỳ';

  @override
  String get languageNameZh => 'Tiếng Trung (Giản thể)';

  @override
  String get languageNameZhHant => 'Tiếng Trung (Phồn thể)';

  @override
  String get languageNameVi => 'Tiếng Việt';

  @override
  String get languageNameId => 'Tiếng Indonesia';

  @override
  String get languageNameFa => 'Tiếng Ba Tư';

  @override
  String get languageNameAr => 'Tiếng Ả Rập';

  @override
  String get languageLaterLine =>
      'Bạn có thể đổi bất cứ lúc nào trong cài đặt.';

  @override
  String get pollAttach => 'Bình chọn';

  @override
  String get pollNewTitle => 'Cuộc bình chọn mới';

  @override
  String get pollQuestionHint => 'Hỏi nhóm một điều gì đó';

  @override
  String get pollOptionsLabel => 'Các lựa chọn';

  @override
  String pollOptionHint(Object n) {
    return 'Lựa chọn $n';
  }

  @override
  String get pollAddOption => 'Thêm lựa chọn';

  @override
  String get pollMaxLine => 'Tối đa mười hai lựa chọn.';

  @override
  String get pollMultiple => 'Nhiều câu trả lời';

  @override
  String get pollMultipleLine => 'Mọi người có thể chọn nhiều hơn một.';

  @override
  String get pollSend => 'Gửi bình chọn';

  @override
  String get pollKind => 'Bình chọn';

  @override
  String get pollKindMulti => 'Bình chọn · nhiều câu trả lời';

  @override
  String get pollKindClosed => 'Kết quả cuối cùng';

  @override
  String pollVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count phiếu',
      zero: 'Chưa có phiếu nào',
    );
    return '$_temp0';
  }

  @override
  String get pollVote => 'Bình chọn';

  @override
  String get pollTakeBack => 'Rút lại phiếu của tôi';

  @override
  String get pollClose => 'Kết thúc bình chọn';

  @override
  String get pollCloseTitle => 'Kết thúc cuộc bình chọn này?';

  @override
  String get pollCloseLine =>
      'Mọi người sẽ thấy kết quả cuối cùng và không ai có thể bình chọn nữa.';

  @override
  String get pollCloseYes => 'Kết thúc';

  @override
  String pollPreview(Object question) {
    return 'Bình chọn: $question';
  }

  @override
  String get pollWhoVoted => 'Ai đã bình chọn';

  @override
  String get pollNobody => 'Chưa có ai';

  @override
  String get pollYou => 'Bạn';

  @override
  String pollOptionA11y(Object option, Object share) {
    return '$option, $share';
  }

  @override
  String get pollPickOne => 'Chọn một';

  @override
  String get pollPickSeveral => 'Chọn một hoặc nhiều';

  @override
  String get searchOpen => 'Tìm kiếm';

  @override
  String get searchHint => 'Tìm trong cuộc trò chuyện và tin nhắn';

  @override
  String get searchFilterAll => 'Tất cả';

  @override
  String get searchFilterPhotos => 'Ảnh';

  @override
  String get searchFilterVideos => 'Video';

  @override
  String get searchFilterFiles => 'Tệp';

  @override
  String get searchFilterLinks => 'Liên kết';

  @override
  String get searchChats => 'Cuộc trò chuyện';

  @override
  String get searchMessages => 'Tin nhắn';

  @override
  String get searchIntroTitle => 'Tìm trong các cuộc trò chuyện';

  @override
  String get searchIntroLine =>
      'Tên, từ ngữ, ảnh, tệp và liên kết. Việc tìm kiếm diễn ra trên điện thoại này và không gửi gì đi đâu cả.';

  @override
  String get searchNothing => 'Không tìm thấy gì';

  @override
  String get searchNothingLine => 'Thử một từ khác hoặc một bộ lọc khác.';

  @override
  String searchMatches(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kết quả',
    );
    return '$_temp0';
  }

  @override
  String searchMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'thêm $count',
    );
    return '$_temp0';
  }

  @override
  String searchFilling(Object share) {
    return 'Đang thêm các tin nhắn cũ · $share';
  }

  @override
  String get searchClear => 'Xóa';

  @override
  String get handleShowInSearch => 'Hiện tôi trong tìm kiếm';

  @override
  String get handleShowInSearchLine =>
      'Bất kỳ ai cũng có thể tìm thấy tên người dùng này và nhắn tin cho bạn.';

  @override
  String handleShownAs(Object name) {
    return 'Hiển thị là $name';
  }

  @override
  String get handleNameInSearch => 'Tên trong tìm kiếm';

  @override
  String get handleNameInSearchLine =>
      'Không bắt buộc. Tên này hiện cạnh tên người dùng của bạn khi có người tìm kiếm. Bất kỳ ai cũng có thể tìm thấy tên người dùng này và nhắn tin cho bạn.';

  @override
  String get handleNameHint => 'Tên của bạn, hoặc để trống';

  @override
  String get handleShowMe => 'Hiện tôi';

  @override
  String get handleSearchOff => 'Bạn đã rời khỏi tìm kiếm';

  @override
  String handleSearchOn(Object handle) {
    return 'Bạn có trong tìm kiếm là @$handle';
  }

  @override
  String get handleRegistryFailed =>
      'Không liên lạc được với nơi đăng ký. Hãy thử lại sau một phút.';

  @override
  String get searchPeople => 'Mọi người';

  @override
  String searchPeopleAsk(Object query) {
    return 'Tìm “$query” trong các tên người dùng công khai';
  }

  @override
  String get searchPeopleLine => 'Hỏi qua Tor. Nơi đăng ký không lưu lại gì.';

  @override
  String get searchPeopleNone => 'Không có tên người dùng công khai nào khớp';

  @override
  String get searchPeopleOffline => 'Tor chưa sẵn sàng';

  @override
  String get searchPeopleBusy =>
      'Lúc này có quá nhiều lượt tìm. Hãy thử lại sau giây lát.';

  @override
  String get searchPeopleUnreachable => 'Không liên lạc được với nơi đăng ký';

  @override
  String get peopleVerified => 'Tên người dùng đã xác minh';

  @override
  String get peopleAdd => 'Thêm';

  @override
  String peopleFingerprint(Object fp) {
    return 'Dấu vân tay khóa · $fp';
  }

  @override
  String get peopleFingerprintLine =>
      'Hãy kiểm tra nó khớp với những gì người kia thấy trong ứng dụng.';

  @override
  String get peopleAdding => 'Đang thêm…';

  @override
  String handleNobodyHasClaimed(Object handle) {
    return 'Chưa ai đăng ký $handle';
  }

  @override
  String get handleThatHandleIsTaken => 'Tên người dùng này đã có người dùng';

  @override
  String get pinPickDifferent => 'Hãy chọn mã PIN khác';

  @override
  String get settingsKeptOnWhileLock => 'Luôn bật khi khóa ứng dụng đang bật.';

  @override
  String get lockFingerAfterPin => 'Nhập mã PIN một lần để dùng lại vân tay.';

  @override
  String get pinsAdvanced => 'Bảo vệ nâng cao';

  @override
  String get pinsAdvancedLine =>
      'Dành cho lúc có người bắt bạn mở khóa điện thoại.';

  @override
  String get pinsWipeLine =>
      'Nhập ở màn hình khóa, mã này sẽ xóa Kryfo khỏi điện thoại này.';

  @override
  String get pinsDecoyPin => 'Mã PIN ngụy trang';

  @override
  String get pinsDecoyLine => 'Mở một Kryfo trống, như vừa mới cài.';

  @override
  String get pinsSetADecoyPin => 'Đặt mã PIN ngụy trang';

  @override
  String get pinsChangeDecoyPin => 'Đổi mã PIN ngụy trang';

  @override
  String get pinsRemoveTheDecoyPin => 'Gỡ mã PIN ngụy trang?';

  @override
  String get pinsTheDecoyGoes => 'Kryfo trống mà nó mở cũng mất theo.';

  @override
  String get pinsTurnOffWithDecoy =>
      'Mọi mã PIN đều bị gỡ, kể cả mã ngụy trang, Kryfo của nó và mọi trò chuyện ẩn. Bất kỳ ai cầm điện thoại của bạn đều mở được Kryfo với tư cách là bạn.';

  @override
  String get pinsHowThisWorks => 'Cách hoạt động';

  @override
  String get flowEnterYourPin => 'Nhập mã PIN của bạn';

  @override
  String get flowEnterYourPinLine => 'Mã dùng để mở Kryfo.';

  @override
  String get flowWipeTitle => 'Mã PIN xóa sạch';

  @override
  String get flowWipe1 =>
      'Nhập ở màn hình khóa thay cho mã PIN của bạn, mã này sẽ xóa Kryfo khỏi điện thoại này rồi đóng lại. Với người đang nhìn, ứng dụng chỉ như vừa dừng.';

  @override
  String get flowWipe2 =>
      'Mọi cuộc trò chuyện và danh tính của bạn sẽ mất theo, cả phần ngụy trang nếu bạn có.';

  @override
  String get flowWipeChoose => 'Chọn mã PIN xóa sạch';

  @override
  String get flowWipeDone => 'Đã đặt mã PIN xóa sạch';

  @override
  String get flowWipeDoneLine =>
      'Màn hình khóa không để lộ gì cho thấy nó tồn tại.';

  @override
  String get flowDecoyTitle => 'Mã PIN ngụy trang';

  @override
  String get flowDecoy1 => 'Mở một Kryfo trống, như vừa mới cài.';

  @override
  String get flowDecoyFinger =>
      'Vân tay của bạn mở Kryfo thật. Nếu có người có thể ép bạn dùng nó, hãy tắt vân tay.';

  @override
  String get flowDecoyDigits =>
      'Dùng cùng số chữ số với mã PIN của bạn, vì ai đang nhìn cũng có thể đếm các dấu chấm.';

  @override
  String get flowDecoyShade =>
      'Thông báo đã nằm trong bảng thông báo thì đã bị thấy rồi. Khi phần ngụy trang đang mở, không có thông báo mới nào hiện ra.';

  @override
  String get flowDecoyChoose => 'Chọn mã PIN ngụy trang';

  @override
  String get flowDecoyDone => 'Đã đặt mã PIN ngụy trang';

  @override
  String get flowDecoyDoneLine =>
      'Nhập mã này ở màn hình khóa để mở Kryfo trống. Để thoát, chuyển sang ứng dụng khác rồi nhập mã PIN của bạn.';

  @override
  String get flowLaw =>
      'Ở một số nước, từ chối mở khóa điện thoại hoặc giấu dữ liệu khỏi nhà chức trách tự nó đã là vi phạm. Hãy nắm luật ở nơi bạn đến.';

  @override
  String get howWipe =>
      'Nhập ở màn hình khóa, mã PIN xóa sạch sẽ xóa mọi cuộc trò chuyện, danh tính của bạn và mọi phần ngụy trang, rồi đóng Kryfo. Nó vẫn hoạt động cả khi bàn phím đang bị tạm khóa sau những lần nhập sai.';

  @override
  String get howDecoy =>
      'Mã PIN ngụy trang mở một Kryfo thứ hai, trống, với ba từ riêng. Tin nhắn gửi đến Kryfo thật của bạn vẫn đến bên dưới, lặng lẽ. Để thoát khỏi phần ngụy trang, chuyển sang ứng dụng khác rồi nhập mã PIN của bạn.';

  @override
  String get flowNotSet => 'Không đặt được. Hãy thử lại.';

  @override
  String get pinsHiddenChats => 'Trò chuyện ẩn';

  @override
  String get pinsHiddenLine =>
      'Các cuộc trò chuyện bạn chọn sẽ khuất khỏi tầm mắt cho đến khi bạn nhập mã PIN trò chuyện ẩn: không có trong danh sách, không có trong tìm kiếm, không có thông báo.';

  @override
  String get pinsSetUp => 'Thiết lập';

  @override
  String get pinsChangeHiddenPin => 'Đổi mã PIN trò chuyện ẩn';

  @override
  String get pinsHideMoreChats => 'Ẩn thêm cuộc trò chuyện';

  @override
  String get pinsRemoveHiddenChats => 'Bỏ trò chuyện ẩn';

  @override
  String get pinsRemoveHiddenTitle => 'Bỏ trò chuyện ẩn?';

  @override
  String get pinsRemoveHiddenLine =>
      'Chúng sẽ quay lại danh sách trò chuyện của bạn, và mã PIN trò chuyện ẩn sẽ không mở gì nữa.';

  @override
  String get pinsTurnOffHiddenFirst =>
      'Trò chuyện ẩn cần khóa ứng dụng. Hãy bỏ chúng trước, chúng sẽ quay lại danh sách trò chuyện của bạn.';

  @override
  String get flowVaultTitle => 'Trò chuyện ẩn';

  @override
  String get flowVault1 =>
      'Chọn các cuộc trò chuyện và nhóm cần ẩn. Mã PIN của bạn mở Kryfo mà không có chúng. Mã PIN trò chuyện ẩn mở tất cả, kể cả trò chuyện ẩn.';

  @override
  String get flowVault2 =>
      'Khi đang bị ẩn, chúng không bao giờ gửi thông báo hay hiện số đếm. Tin nhắn của chúng vẫn đến và chờ, được niêm phong, cho đến khi bạn nhập mã PIN trò chuyện ẩn.';

  @override
  String get flowVaultFinger =>
      'Vân tay của bạn mở Kryfo mà không có trò chuyện ẩn.';

  @override
  String get flowVaultDigits =>
      'Mã PIN của bạn cũng nên có từ sáu chữ số trở lên, vì ai đang nhìn cũng có thể đếm các dấu chấm.';

  @override
  String get flowVaultReplace =>
      'Việc này thay thế mọi trò chuyện ẩn mà điện thoại này đang có.';

  @override
  String get flowVaultChoose => 'Chọn mã PIN trò chuyện ẩn';

  @override
  String get flowVaultChooseLine => 'Sáu chữ số trở lên.';

  @override
  String get flowEnterHiddenPinLine => 'Mã dùng để mở trò chuyện ẩn của bạn.';

  @override
  String get flowVaultForgetTitle => 'Hãy nhớ mã PIN này';

  @override
  String get flowVaultForget =>
      'Nếu bạn quên mã PIN này, trò chuyện ẩn của bạn sẽ mất vĩnh viễn. Không ai lấy lại được, kể cả chúng tôi.';

  @override
  String get flowVaultForgetOk => 'Tôi hiểu';

  @override
  String get flowVaultPickTitle => 'Chọn cuộc trò chuyện cần ẩn';

  @override
  String get flowVaultPickLine =>
      'Chúng sẽ rời khỏi danh sách trò chuyện ngay bây giờ. Mã PIN trò chuyện ẩn sẽ cho chúng hiện lại.';

  @override
  String flowVaultPickButton(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ẩn $countString cuộc trò chuyện',
      zero: 'Chưa ẩn gì cả',
    );
    return '$_temp0';
  }

  @override
  String get flowVaultPickEmpty => 'Chưa có cuộc trò chuyện nào để ẩn.';

  @override
  String get flowVaultBackupTitle => 'Tạo bản sao lưu ngay bây giờ?';

  @override
  String get flowVaultBackupLine =>
      'Bản sao lưu tạo lúc này cũng chứa trò chuyện ẩn của bạn, với cụm mật khẩu riêng. Nếu bạn quên mã PIN trò chuyện ẩn, đó là cách duy nhất để lấy lại chúng.';

  @override
  String get flowVaultBackupNow => 'Tạo bản sao lưu';

  @override
  String get flowVaultNotNow => 'Để sau';

  @override
  String get flowVaultDone => 'Đã thiết lập trò chuyện ẩn';

  @override
  String get flowVaultDoneLine =>
      'Nhập mã PIN trò chuyện ẩn ở màn hình khóa để xem chúng. Chuyển sang ứng dụng khác là chúng lại khuất đi.';

  @override
  String get flowVaultChanged => 'Đã đổi mã PIN trò chuyện ẩn';

  @override
  String get flowVaultChangedLine =>
      'Trò chuyện ẩn của bạn giờ mở bằng mã mới. Mã cũ không còn mở được gì.';

  @override
  String get howVault =>
      'Mã PIN trò chuyện ẩn mở Kryfo cùng trò chuyện ẩn của bạn; mã PIN và vân tay của bạn mở mà không có chúng. Thiết lập lại trò chuyện ẩn sẽ thay thế những trò chuyện ẩn mà điện thoại này đang có. Quên mã PIN trò chuyện ẩn là chúng mất vĩnh viễn.';

  @override
  String get chatHide => 'Ẩn trò chuyện';

  @override
  String get groupHide => 'Ẩn nhóm';

  @override
  String get chatHidden => 'Đã ẩn';

  @override
  String get chatHiddenToast => 'Đã ẩn khỏi danh sách trò chuyện';

  @override
  String get chatShowInList => 'Hiện trong danh sách trò chuyện';

  @override
  String get stickerOpen => 'Nhãn dán';

  @override
  String get stickerRecent => 'Gần đây';

  @override
  String stickerA11y(String emoji) {
    return 'Nhãn dán $emoji';
  }

  @override
  String get stickerRemoveRecent => 'Xóa khỏi gần đây';

  @override
  String get stickerCouldNotLoad => 'Không thể tải nhãn dán';

  @override
  String get stickerLabel => 'Nhãn dán';

  @override
  String get stickerNewer => 'Từ một bản Kryfo mới hơn';
}
