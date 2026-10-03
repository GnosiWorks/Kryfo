// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get atmosphereNone => 'Nenhuma';

  @override
  String get atmosphereEmber => 'Brasa';

  @override
  String get atmosphereDusk => 'Crepúsculo';

  @override
  String get atmosphereMoss => 'Musgo';

  @override
  String get atmosphereRose => 'Rosa';

  @override
  String get atmosphereDots => 'Bolinhas';

  @override
  String get atmosphereGrid => 'Grade';

  @override
  String get atmosphereWaves => 'Ondas';

  @override
  String get atmosphereRain => 'Chuva';

  @override
  String get atmosphereLateNight => 'Madrugada';

  @override
  String get atmosphereWarmAfternoon => 'Tarde quente';

  @override
  String get atmosphereSnow => 'Neve';

  @override
  String get atmosphereDesert => 'Deserto';

  @override
  String get atmospherePaper => 'Papel';

  @override
  String get backupThatPassphraseDoesNot =>
      'Essa frase-senha não abre este arquivo';

  @override
  String get backupThatFileIsNot => 'Esse arquivo não é um backup do Kryfo';

  @override
  String get backupThisBackupIsFrom =>
      'Este backup é de um Kryfo mais novo. Atualize o app e tente de novo';

  @override
  String get backupThisFileIsDamaged =>
      'Este arquivo está danificado e não pode ser lido';

  @override
  String get backupTheRestoreStoppedPartway => 'A restauração parou no meio';

  @override
  String get backupCouldNotMakeThe => 'Não foi possível criar a chave';

  @override
  String get contactCardMessageMeOn => 'Fale comigo no';

  @override
  String get contactCardScanItOrType =>
      'Escaneie ou digite as três palavras no Kryfo.\nEste cartão não sabe mais nada sobre você.';

  @override
  String contactCardMessageMeOnKryfo(Object haloId) {
    return 'Fale comigo no Kryfo · $haloId';
  }

  @override
  String get contactStatusBlocked => 'Bloqueado';

  @override
  String get contactStatusKeysVerifiedInPerson =>
      'Chaves verificadas pessoalmente';

  @override
  String get contactStatusWaitingInRequests => 'Esperando nos pedidos';

  @override
  String get contactStatusAddedByHand => 'Adicionado à mão';

  @override
  String get deliveryModeAlwaysOn => 'Sempre ativo';

  @override
  String get deliveryModeCheckIns => 'Consultas';

  @override
  String get deliveryModeThroughAHelperApp => 'Por um app auxiliar';

  @override
  String get deliveryModeNotYet => 'ainda não';

  @override
  String get deliveryModeJustNow => 'agora mesmo';

  @override
  String deliveryModeMinAgo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'há $countString min',
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
      other: 'há $countString horas',
      one: 'há $countString hora',
    );
    return '$_temp0';
  }

  @override
  String get deliveryModeYesterday => 'ontem';

  @override
  String deliveryModeDaysAgo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'há $countString dias',
      one: 'há $countString dia',
    );
    return '$_temp0';
  }

  @override
  String get deliveryModeConnected => 'Conectado';

  @override
  String get deliveryModeConnecting => 'Conectando';

  @override
  String get deliveryModeNotConnected => 'Desconectado';

  @override
  String get deliveryModeCheckingNow => 'Consultando agora';

  @override
  String deliveryModeLastCheckIn(Object agoLine) {
    return 'última consulta $agoLine';
  }

  @override
  String get deliveryModeNoCheckInYet => 'nenhuma consulta ainda';

  @override
  String deliveryModeConnectedNow(Object last) {
    return 'Conectado agora · $last';
  }

  @override
  String deliveryModeConnecting2(Object last) {
    return 'Conectando · $last';
  }

  @override
  String get deliveryModeNoCheckInYet2 => 'Nenhuma consulta ainda';

  @override
  String deliveryModeLastChecked(Object agoLine) {
    return 'Última consulta $agoLine';
  }

  @override
  String get deliveryModeAHelperApp => 'um app auxiliar';

  @override
  String deliveryModeWokenByNoWake(Object who) {
    return 'Acordado por $who · nenhum despertar ainda';
  }

  @override
  String deliveryModeWokenByLastWake(Object who, Object agoLine) {
    return 'Acordado por $who · último despertar $agoLine';
  }

  @override
  String get introBudgetTomorrow => 'amanhã';

  @override
  String introBudgetInDays(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'em $countString dias',
      one: 'em $countString dia',
    );
    return '$_temp0';
  }

  @override
  String get introBudgetInAnHour => 'em uma hora';

  @override
  String introBudgetInHours(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'em $countString horas',
      one: 'em $countString hora',
    );
    return '$_temp0';
  }

  @override
  String get introBudgetInAFewMinutes => 'em alguns minutos';

  @override
  String get lockStateUnlockKryfo => 'Desbloquear o Kryfo';

  @override
  String get appInvalidUri => 'Uri inválida';

  @override
  String appBundleError(Object e) {
    return 'Erro no pacote: $e';
  }

  @override
  String appAlreadySaved(Object parsed) {
    return 'Já salvo: $parsed';
  }

  @override
  String appAddedYouCanMessage(Object parsed) {
    return 'Adicionado: $parsed · você já pode mandar mensagem';
  }

  @override
  String appPeerImportedV1(Object parsed) {
    return 'Contato importado (v1): $parsed';
  }

  @override
  String appLongWindow(Object line) {
    return '$line janela longa';
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
      other: '$pString páginas',
      one: '$pString página',
    );
    String _temp1 = intl.Intl.pluralLogic(
      e,
      locale: localeName,
      other: '$eString eventos',
      one: '$eString evento',
    );
    return '$line ($heldString de $subsString, conexão ${c}s, $_temp0, $_temp1)';
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
      other: '$pString páginas',
      one: '$pString página',
    );
    String _temp1 = intl.Intl.pluralLogic(
      e,
      locale: localeName,
      other: '$eString eventos',
      one: '$eString evento',
    );
    return '$line (conexão ${c}s, $_temp0, $_temp1)';
  }

  @override
  String appSDropped(Object host, Object secs) {
    return '$host ${secs}s caiu';
  }

  @override
  String appS(Object host, Object secs) {
    return '$host ${secs}s';
  }

  @override
  String get appTorWouldNotWake => 'O Tor não quis acordar';

  @override
  String get appCheckStarted => 'Iniciada';

  @override
  String get appTorNotReadyIn => 'Tor não ficou pronto em 75s';

  @override
  String get appOk => 'OK';

  @override
  String get appOkNoRelayBegan => 'OK, sem retransmissor';

  @override
  String get appOkCapped => 'OK, cortada';

  @override
  String appSBy(Object how, int secs, String why) {
    final intl.NumberFormat secsNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String secsString = secsNumberFormat.format(secs);

    String _temp0 = intl.Intl.selectLogic(why, {
      'push': '$how, ${secsString}s, por push',
      'other': '$how, ${secsString}s, por tarefa',
    });
    return '$_temp0';
  }

  @override
  String get appAnAttachmentCouldNot =>
      'Um anexo não pôde ser salvo neste celular';

  @override
  String get appGroup2 => 'Grupo';

  @override
  String get appVoiceMessage => 'Mensagem de voz';

  @override
  String get appPhoto => 'Foto';

  @override
  String get appNewRequest => 'Novo pedido';

  @override
  String get appSomeoneYouHaveNot =>
      'Alguém que você não adicionou escreveu para você';

  @override
  String get appSettingUpYourKeys => 'Preparando suas chaves';

  @override
  String get appOpeningYourChats => 'Abrindo suas conversas';

  @override
  String get appStartingTor => 'Iniciando o Tor';

  @override
  String get appTimedMessagesAreNot =>
      'As mensagens temporárias não estão sumindo. Reinicie o Kryfo';

  @override
  String get appVoiceMessage2 => 'Mensagem de voz';

  @override
  String appYou(Object body) {
    return 'Você: $body';
  }

  @override
  String get appThisRoomHasAlready => 'Esta sala já expirou';

  @override
  String get appYouAreAlreadyIn => 'Você já está nesta sala';

  @override
  String get appCouldNotMakeA => 'Não foi possível criar a chave da sala';

  @override
  String appJoinedButYourHello(Object linkName) {
    return 'Você entrou em $linkName, mas seu oi ficou retido';
  }

  @override
  String appJoined(Object linkName) {
    return 'Você entrou em $linkName';
  }

  @override
  String appJoinedButTheCreator(Object linkName) {
    return 'Você entrou em $linkName, mas ainda não foi possível falar com quem criou a sala';
  }

  @override
  String get appBooting => 'Iniciando...';

  @override
  String get appSettingUpYourIdentity => 'Preparando sua identidade...';

  @override
  String get appAddSomeone => 'Adicionar alguém';

  @override
  String get appScanTheirCodeOr =>
      'Escaneie o código da pessoa ou cole o que ela passou: um link, um @nome de usuário ou um link de sala.';

  @override
  String get appScanTheirCode => 'Escanear o código';

  @override
  String get appAKryfoLinkA => 'Um link do Kryfo, um link de sala ou @wren';

  @override
  String get appAddThem => 'Adicionar';

  @override
  String get appEveryWayToAdd => 'Todas as formas de adicionar';

  @override
  String get appShowYourCodeSend =>
      'Mostre seu código, envie um link, reserve um nome de usuário';

  @override
  String get appHelloFromTheOther => 'Oi do outro lado';

  @override
  String get appIdentityRestored => 'Identidade restaurada';

  @override
  String get appIdentityCreated => 'Identidade criada';

  @override
  String get appStartingTor30s => 'Iniciando o tor (~30s)...';

  @override
  String get appScanOrImportA => 'Escaneie ou importe um contato primeiro';

  @override
  String get appEncryptingSending30s => 'Criptografando + enviando (~30s)...';

  @override
  String get appTapStartListeningFirst => 'Toque em Começar a escutar primeiro';

  @override
  String get appYourKryfo => 'Seu Kryfo';

  @override
  String get appUriCopied => 'Uri copiada';

  @override
  String get appCopyUri => 'Copiar uri';

  @override
  String get appAddAKryfo => 'Adicionar um Kryfo';

  @override
  String get appScanQr => 'Escanear QR';

  @override
  String get appPairingCode => 'Código de pareamento';

  @override
  String get appOrPaste => '- Ou cole -';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get appImport => 'Importar';

  @override
  String get appDev => 'Dev';

  @override
  String get appYourKryfo2 => 'Seu Kryfo:';

  @override
  String get appRestoredFromDisk => 'Restaurado do disco';

  @override
  String get appStartListening => 'Começar a escutar';

  @override
  String get appListening => 'Escutando';

  @override
  String get appShowMyQr => 'Mostrar meu QR';

  @override
  String get appImportPeer => 'Importar contato';

  @override
  String get appPeer => 'Contato:';

  @override
  String get appMessageWillBeEncrypted => 'Mensagem (será criptografada)';

  @override
  String get appEncryptSend => 'Criptografar + enviar';

  @override
  String appStatus(Object status) {
    return 'Status: $status';
  }

  @override
  String get appSpeedPrivacy => 'Velocidade e privacidade →';

  @override
  String get appGettingMessages => 'Receber mensagens →';

  @override
  String get appDisableAppLock => 'Desativar o bloqueio?';

  @override
  String get appThePinWillBe =>
      'O PIN será removido. Qualquer pessoa com seu celular vai ver o Kryfo ao abri-lo.';

  @override
  String get appDisable => 'Desativar';

  @override
  String get appAppLockOn => 'Bloqueio · ativado →';

  @override
  String get appAppLockOff => 'Bloqueio · desativado →';

  @override
  String get appTorIsOff => 'Tor desligado';

  @override
  String get appConnectedRoutedThrough3 =>
      'Conectado · roteado por 3 retransmissores';

  @override
  String get appReadyToSendPublishing =>
      'Pronto para enviar · publicando seu endereço';

  @override
  String get appReadyToSendFinishing =>
      'Pronto para enviar · terminando a configuração';

  @override
  String appConnecting(Object pct) {
    return 'Conectando · $pct';
  }

  @override
  String get appTor => 'Tor';

  @override
  String get appTorIsOffTurn =>
      'O tor está desligado. Ligue-o para se conectar com privacidade.';

  @override
  String get appTheFirstConnectionTakes =>
      'A primeira conexão leva um ou dois minutos enquanto o tor monta uma rota privada. Depois disso ela fica em cache, então abrir o Kryfo mais tarde é bem mais rápido.';

  @override
  String get appTorNoRelayYet =>
      'O tor está ativo, mas nenhum retransmissor respondeu ainda. O Kryfo continua tentando, e as mensagens esperam aqui até que um responda.';

  @override
  String get appRelayAndFastModes =>
      'Os modos retransmissor e rápido pulam o tor e são mais velozes. Eles ficam nas configurações, em velocidade e privacidade, e cada um diz o que custa.';

  @override
  String get appViaRelay => 'Via retransmissor';

  @override
  String get appOffline => 'Offline';

  @override
  String get appFast => 'Rápido';

  @override
  String get appTorOff => 'Tor desligado';

  @override
  String get appTorReady => 'Tor pronto';

  @override
  String get appConnecting2 => 'Conectando';

  @override
  String mediaProgressSendingKeepTheApp(Object v) {
    return 'Enviando · $v · mantenha o app aberto';
  }

  @override
  String mediaProgressPausedOfWaitingFor(Object count, Object count2) {
    return 'Pausado · $count de $count2 · esperando o resto';
  }

  @override
  String mediaProgressReceivingMedia(Object v) {
    return 'Recebendo mídia · $v';
  }

  @override
  String get mediaProgressCancelSending => 'Cancelar envio';

  @override
  String get metaReaderEndsBeforeItShould => 'termina antes do esperado';

  @override
  String get metaReaderCouldNotBeRead => 'não pôde ser lido';

  @override
  String get metaReaderExifThatCannotBe => 'exif que não pode ser lido';

  @override
  String get metaReaderSamsungTrailer => 'trailer da samsung';

  @override
  String metaReaderChunk(Object type) {
    return 'bloco $type';
  }

  @override
  String get metaReaderExifFlagSet => 'flag exif ativada';

  @override
  String get metaReaderXmpFlagSet => 'flag xmp ativada';

  @override
  String metaReaderAppBlock(Object id) {
    return 'bloco de app $id';
  }

  @override
  String get metaReaderUuidBox => 'caixa uuid';

  @override
  String metaReaderBox(Object printable) {
    return 'caixa $printable';
  }

  @override
  String get metaReaderAttachedData => 'dados anexados';

  @override
  String metaReaderItem(Object printable) {
    return 'item $printable';
  }

  @override
  String get miuiAutostartAlreadyAllowedToRun =>
      'Já pode rodar em segundo plano';

  @override
  String get miuiAutostartLetKryfoRunIn =>
      'Deixe o Kryfo rodar em segundo plano';

  @override
  String get miuiAutostartYourPhonePausesApps =>
      'Seu celular pausa apps para economizar bateria. Sem uma exceção, o Kryfo não consegue receber mensagens enquanto está fechado.';

  @override
  String get commonAllow => 'Permitir';

  @override
  String get commonSkip => 'Pular';

  @override
  String get miuiAutostartXiaomiTurnsOffBackground =>
      'A Xiaomi desliga apps em segundo plano por padrão. Sem o início automático, o Kryfo não consegue entregar mensagens quando o app está fechado. Na próxima tela, encontre o Kryfo na lista e ative a opção.';

  @override
  String get miuiAutostartOpenSettings => 'Abrir configurações';

  @override
  String get miuiAutostartCouldnTOpenIt =>
      'Não deu para abrir. Procure início automático nas configurações do celular';

  @override
  String get notificationsNewEncryptedMessagesFrom =>
      'Novas mensagens criptografadas dos seus contatos';

  @override
  String get notificationsNewMessage => 'Nova mensagem';

  @override
  String get notificationsNewEncryptedMessagesFromYourContacts =>
      'Novas mensagens criptografadas dos seus contatos';

  @override
  String get notificationsNewMessage2 => 'Nova mensagem';

  @override
  String get notificationsEncrypted => 'Criptografada';

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
  String get rooms24Hours => '24 horas';

  @override
  String roomsDays(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString dias',
      one: '$countString dia',
    );
    return '$_temp0';
  }

  @override
  String get roomsAnHour => 'uma hora';

  @override
  String get roomsAboutAnHour => 'cerca de uma hora';

  @override
  String roomsHours(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString horas',
      one: '$countString hora',
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
      other: 'cerca de $countString horas',
      one: 'cerca de $countString hora',
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
      other: '$countString minutos',
      one: '$countString minuto',
    );
    return '$_temp0';
  }

  @override
  String get roomsAMinute => 'um minuto';

  @override
  String get roomsExpired => 'Expirada';

  @override
  String roomsDH(Object inDays, Object h) {
    return '${inDays}d ${h}h';
  }

  @override
  String roomsHM(Object inHours, Object m) {
    return '${inHours}h ${m}min';
  }

  @override
  String roomsM(Object inMinutes) {
    return '${inMinutes}min';
  }

  @override
  String get scamShieldLooksLikeAScam => 'Parece golpe';

  @override
  String scamShieldThisNameMatches(Object shown) {
    return 'Este nome é igual a $shown';
  }

  @override
  String scamShieldNameMatchesYourContact(Object shown) {
    return 'O nome é igual ao do seu contato $shown';
  }

  @override
  String scamShieldSameFaceAsYour(Object shown) {
    return 'Mesmo rosto do seu contato $shown';
  }

  @override
  String get scamShieldContainsACryptoAddress =>
      'Contém um endereço de criptomoeda';

  @override
  String get scamShieldMentionsMoneyAndUrgency =>
      'Fala de dinheiro e urgência ao mesmo tempo';

  @override
  String get scamShieldAsksYouToMove => 'Pede para você ir para outro app';

  @override
  String get scamShieldLinksToALookalike =>
      'Tem link para uma imitação de um site conhecido';

  @override
  String get scamShieldALongOpenerFrom =>
      'Uma primeira mensagem longa de alguém sem histórico';

  @override
  String get scamShieldAsksForACode =>
      'Pede um código, frase-semente ou arquivo de recuperação';

  @override
  String scamShieldAlso(Object shown) {
    return 'Também: o nome é igual ao do seu contato $shown';
  }

  @override
  String get commonBack => 'Voltar';

  @override
  String get archivedArchived => 'Arquivadas';

  @override
  String get archivedCount0 => 'Nenhuma';

  @override
  String get archivedCount1 => 'Uma';

  @override
  String get archivedCount2 => 'Duas';

  @override
  String get archivedCount3 => 'Três';

  @override
  String get archivedCount4 => 'Quatro';

  @override
  String get archivedCount5 => 'Cinco';

  @override
  String get archivedCount6 => 'Seis';

  @override
  String get archivedCount7 => 'Sete';

  @override
  String get archivedCount8 => 'Oito';

  @override
  String get archivedCount9 => 'Nove';

  @override
  String get archivedCount10 => 'Dez';

  @override
  String get archivedChatRestingHereIt =>
      'Conversa descansando aqui. Ela fica quieta até a pessoa escrever e aí volta para o topo.';

  @override
  String get archivedChatsRestingHere =>
      'Conversas descansando aqui. Elas ficam quietas até alguém escrever e aí voltam para o topo.';

  @override
  String get archivedNothingArchived => 'Nada arquivado';

  @override
  String get archivedArchivedChatsAreStill =>
      'Conversas arquivadas continuam criptografadas de ponta a ponta';

  @override
  String get archivedUnarchive => 'Desarquivar';

  @override
  String get avatarPickerThePeopleYouMessage =>
      'As pessoas com quem você conversa também veem isso';

  @override
  String get avatarPickerBackToYourInitial => 'Voltar para sua inicial';

  @override
  String get avatarPickerThatOneIsYours => 'Esse é o seu';

  @override
  String get avatarPickerPickAFace => 'Escolha um rosto';

  @override
  String get commonSave => 'Salvar';

  @override
  String get backupPassphraseMustBeAt =>
      'A frase-senha precisa ter pelo menos 6 caracteres';

  @override
  String get backupPassphrasesDonTMatch => 'As frases-senha não são iguais';

  @override
  String get backupBackupSavedKeepThe =>
      'Backup salvo · guarde bem a frase-senha';

  @override
  String get backupKryfoBackup => 'Backup do Kryfo';

  @override
  String get backupYourEncryptedKryfoBackup =>
      'Seu backup criptografado do Kryfo. Guarde bem este arquivo E a sua frase-senha - você precisa dos dois para restaurar.';

  @override
  String get backupBackUpKryfo => 'Fazer backup do Kryfo';

  @override
  String get backupBackUp => 'Fazer backup';

  @override
  String get backupACopyToKeep =>
      'Uma cópia para guardar. Este celular continua como está.';

  @override
  String get backupMoveToAnotherDevice => 'Mudar para outro aparelho';

  @override
  String get backupTheFileTakesThis =>
      'O arquivo leva esta identidade junto. Depois que ele for criado, este celular para: nada novo chega aqui, e nada enviado daqui chega a ninguém.';

  @override
  String get backupOneEncryptedFileYour =>
      'Um arquivo criptografado: sua identidade, seus contatos, todas as mensagens e todas as fotos, áudios e arquivos. Importe no outro aparelho com a frase-senha. Até lá, você ainda pode mudar de ideia e continuar neste celular.';

  @override
  String get backupOneEncryptedFileYourIdentityYour =>
      'Um arquivo criptografado: sua identidade, seus contatos, todas as mensagens e todas as fotos, áudios e arquivos que estão neste celular agora. Nada do que for dito depois de hoje estará nele, então faça outro quando for importante. Para restaurar, você precisa do arquivo e da frase-senha, dos dois.';

  @override
  String get backupPassphrase => 'Frase-senha';

  @override
  String get backupConfirmPassphrase => 'Confirmar frase-senha';

  @override
  String backupWriting(Object progress) {
    return 'Gravando… $progress';
  }

  @override
  String get backupCreating => 'Criando…';

  @override
  String get backupMakeTheFileAnd => 'Criar o arquivo e mudar';

  @override
  String get backupCreateBackup => 'Criar backup';

  @override
  String get backupNotMade => 'Não deu para fazer o backup. Tente de novo.';

  @override
  String get backupHiddenNotIn => 'As conversas ocultas não estão nele.';

  @override
  String get backupHiddenIncluded =>
      'Suas conversas ocultas também estão nele.';

  @override
  String get backupMoveHiddenStay =>
      'As conversas ocultas ficam neste celular e são apagadas com ele.';

  @override
  String get backupHiddenGone =>
      'Suas conversas ocultas se fecharam quando o Kryfo foi bloqueado. Abra-as com o PIN delas e faça o backup por lá.';

  @override
  String get blockedBlocked => 'Bloqueados';

  @override
  String get blockedNoOneIsBlocked => 'Ninguém está bloqueado';

  @override
  String get commonUnblock => 'Desbloquear';

  @override
  String get bridgesThatWasNotIt => 'Não era isso. Aqui vai outro.';

  @override
  String get bridgesMoatFailed =>
      'Não deu para falar com o projeto tor. Tente de novo em um minuto ou cole uma linha de ponte abaixo.';

  @override
  String get bridgesGotBridgesSaveTo => 'Pontes recebidas · salve para usar';

  @override
  String get bridgesConnected => 'Conectado';

  @override
  String get bridgesNotThroughYetTor =>
      'Ainda não passou. O tor continua tentando';

  @override
  String get bridgesBridges => 'Pontes';

  @override
  String get bridgesTorIsBlockedWhere => 'O tor está bloqueado onde você está?';

  @override
  String get bridgesBridgesDisguiseYourConnection =>
      'As pontes disfarçam sua conexão para que ela consiga sair. Escolha uma entrada, salve, e o tor se reconecta por ela.';

  @override
  String get bridgesBridgesOnlyChangeHow =>
      'As pontes só mudam como o tor se conecta, e você não está no modo onion agora. O que você definir aqui fica salvo, só não faz nada até você voltar para ele.';

  @override
  String get bridgesFromTheTorProject => 'Do projeto tor';

  @override
  String get bridgesNoise => 'Ruído';

  @override
  String get bridgesGood => 'Boa';

  @override
  String get bridgesMakesTorTrafficLook =>
      'Faz o tráfego do tor não parecer nada em particular. A melhor opção padrão para a maioria das redes bloqueadas. Você responde um captcha e recebe algumas linhas.';

  @override
  String get bridgesPrivateBridge => 'Ponte privada';

  @override
  String get bridgesALineFromA => 'Uma linha de um amigo';

  @override
  String get bridgesWhateverTheLineSays => 'O que a linha disser';

  @override
  String get bridgesDepends => 'Depende';

  @override
  String get bridgesGotABridgeLine =>
      'Recebeu uma linha de ponte de alguém de confiança ou do bridges.torproject.org? Cole aqui. Só linhas obfs4, o Kryfo ainda não fala as outras.';

  @override
  String get bridgesPasteFromClipboard => 'Colar da área de transferência';

  @override
  String get bridgesUseBridges => 'Usar pontes';

  @override
  String get bridgesNoLinesYet => 'Nenhuma linha ainda';

  @override
  String bridges1LineSaved(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString linhas salvas',
      one: '$countString linha salva',
    );
    return '$_temp0';
  }

  @override
  String get bridgesRestartingTor => 'Reiniciando o tor…';

  @override
  String bridgesFindingABridgeS(Object elapsed) {
    return 'Procurando uma ponte… ${elapsed}s';
  }

  @override
  String bridgesStillTryingS(Object elapsed) {
    return 'Ainda tentando… ${elapsed}s';
  }

  @override
  String get bridgesApplying => 'Aplicando…';

  @override
  String get bridgesSaveAndReconnect => 'Salvar e reconectar';

  @override
  String get bridgesWhatABridgeIs => 'O que é uma ponte';

  @override
  String get bridgesATorEntryPoint =>
      'Uma entrada do tor que ninguém publicou, alcançada por um invólucro para que a conexão não pareça tor. O resto da rota são os três saltos de sempre.';

  @override
  String get bridgesLooksLike => 'Parece';

  @override
  String get bridgesSpeed => 'Velocidade';

  @override
  String get bridgesGetBridges => 'Obter pontes';

  @override
  String get bridgesAskTheTorProject =>
      'Peça direto ao projeto tor. Você resolve um desafio para que robôs não esgotem o estoque.';

  @override
  String get bridgesTypeWhatYouSee =>
      'Digite o que você vê. Minúsculas servem.';

  @override
  String get bridgesThisOneRequestDoes =>
      'Esta única solicitação não passa pelo tor - nem pode, já que o tor é o que não está funcionando. Quem administra sua rede vai ver você contatando o projeto tor. Se só isso já é um problema onde você está, consiga pontes em outro lugar e cole abaixo.';

  @override
  String get bridgesCouldNotDrawThe => 'Não foi possível desenhar o desafio';

  @override
  String get bridgesAnswer => 'Resposta';

  @override
  String get bridgesAsking => 'Pedindo…';

  @override
  String get bridgesRequestBridges => 'Pedir pontes';

  @override
  String get bridgesDifferentPuzzle => 'Outro desafio';

  @override
  String get cameraNoCameraOnThis => 'Nenhuma câmera neste celular';

  @override
  String get cameraCameraNotAvailable => 'Câmera indisponível';

  @override
  String get cameraCameraPermissionIsOff => 'Permissão da câmera desativada';

  @override
  String get cameraOpenSettings => 'Abrir configurações';

  @override
  String get cameraCouldNotStripThat =>
      'Não foi possível limpar essa foto, ela foi descartada';

  @override
  String get cameraNoPhotoCameOut => 'Nenhuma foto saiu';

  @override
  String get cameraCouldNotStartRecording =>
      'Não foi possível começar a gravar';

  @override
  String get cameraTheRecordingWasLost => 'A gravação se perdeu';

  @override
  String get cameraACopyIsIn => 'Tem uma cópia nas suas fotos';

  @override
  String get cameraCouldNotSaveA =>
      'Não foi possível salvar uma cópia neste celular';

  @override
  String get cameraTooLongForA => 'Longo demais para uma mensagem · máx. 8 MB';

  @override
  String get cameraNeverSavedToYour => 'Nunca salvo nas suas fotos';

  @override
  String get cameraNoExifNeverSaved => 'Sem EXIF, nunca salvo nas suas fotos';

  @override
  String get cameraRec => 'Gravar';

  @override
  String get cameraSwitchCamera => 'Trocar câmera';

  @override
  String cameraClipSMb(Object secs, Object mb) {
    return 'Clipe · ${secs}s · $mb MB';
  }

  @override
  String get cameraStopRecording => 'Parar de gravar';

  @override
  String get cameraStartRecording => 'Começar a gravar';

  @override
  String get cameraTakeAPhoto => 'Tirar foto';

  @override
  String get cameraKeepACopy => 'Guardar uma cópia';

  @override
  String get cameraUseThis => 'Usar';

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
  String get chatFile => 'ARQUIVO';

  @override
  String get chatYouAreOfflineThis =>
      'Você está offline · a mensagem sai sozinha quando você se reconectar';

  @override
  String get chatStillConnectingToTor =>
      'Ainda conectando ao Tor · ela vai sair sozinha';

  @override
  String chatS(Object seconds) {
    return '${seconds}s';
  }

  @override
  String chatM(Object seconds) {
    return '${seconds}min';
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
    return '${h}h ${m}min';
  }

  @override
  String chatMS(Object m, Object s) {
    return '${m}min ${s}s';
  }

  @override
  String chatS2(Object s) {
    return '${s}s';
  }

  @override
  String get chatNewMessages => 'Novas mensagens';

  @override
  String get chatUnsave => 'Tirar dos salvos';

  @override
  String get chatForward => 'Encaminhar';

  @override
  String get commonShare => 'Compartilhar';

  @override
  String get commonCopied => 'Copiado';

  @override
  String get commonCopy => 'Copiar';

  @override
  String get chatUnpin => 'Desafixar';

  @override
  String get chatPin => 'Fixar';

  @override
  String get chatStopSending => 'Parar envio';

  @override
  String get chatUnsend => 'Desfazer envio';

  @override
  String get commonEdit => 'Editar';

  @override
  String get chatYou => 'Você';

  @override
  String get chatUnsendMessage => 'Desfazer envio';

  @override
  String get chatItDisappearsWithNo =>
      'Ela some sem deixar rastro. Isso não pode ser desfeito.';

  @override
  String chatThisChatHasPins(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Esta conversa já tem $countString mensagens fixadas',
      one: 'Esta conversa já tem $countString mensagem fixada',
    );
    return '$_temp0';
  }

  @override
  String get chatUnpinThisMessage => 'Desafixar esta mensagem?';

  @override
  String get chatPinThisMessage => 'Fixar esta mensagem?';

  @override
  String get chatItLeavesThePinned =>
      'Ela sai da lista de fixadas para vocês dois.';

  @override
  String get chatItGoesUnderThe =>
      'Ela entra nas fixadas, no topo da conversa, para vocês dois.';

  @override
  String get chatPinIt => 'Fixar';

  @override
  String get chatNotNow => 'Agora não';

  @override
  String get chatEditMessage => 'Editar mensagem';

  @override
  String get chat30Seconds => '30 segundos';

  @override
  String get chat1Minute => '1 minuto';

  @override
  String get chat5Minutes => '5 minutos';

  @override
  String get chat1Hour => '1 hora';

  @override
  String get chat24Hours => '24 horas';

  @override
  String get chatGhostTimer => 'Mensagens temporárias';

  @override
  String get chatHowLongBeforeSent =>
      'Quanto tempo até as mensagens enviadas sumirem?';

  @override
  String get chatCamera => 'Câmera';

  @override
  String get chatNoExifNeverSaved => 'Sem exif, nunca salvo nas suas fotos';

  @override
  String get chatGallery => 'Galeria';

  @override
  String get chatVideo => 'Vídeo';

  @override
  String get chatGifFromPhone => 'Gif do celular';

  @override
  String get chatFile2 => 'Arquivo';

  @override
  String get chatAFewSeconds => 'Alguns segundos';

  @override
  String get chatUnderAMinute => 'Menos de um minuto';

  @override
  String chatRoughlyMin(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Cerca de $countString min',
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
  String get chatSendThis => 'Enviar este arquivo?';

  @override
  String chatOverTor(Object humanBytes, Object wireEstimate) {
    return '$humanBytes · $wireEstimate pelo tor';
  }

  @override
  String get chatBigFilesGoOut =>
      'Arquivos grandes saem em pequenos pedaços criptografados, então demoram um pouco. Mantenha o app aberto e o envio continua.';

  @override
  String get chatSendIt => 'Enviar';

  @override
  String get chatCouldNotReadThat => 'Não foi possível ler esse arquivo';

  @override
  String get chatFileTooBig8 => 'Arquivo grande demais · máx. 8 mb';

  @override
  String get chatCouldNotCleanThat => 'Não foi possível limpar esse vídeo';

  @override
  String get chatCouldNotCleanThatPictureSend =>
      'Não foi possível limpar essa imagem · envie como foto';

  @override
  String get chatGifTooBig8 => 'Gif grande demais · máx. 8 mb';

  @override
  String get chatCouldNotCleanThatGif => 'Não foi possível limpar esse gif';

  @override
  String get chatTorIsNotUp =>
      'O tor ainda não está pronto · enviando sem prévia';

  @override
  String get chatCouldnTReachIt => 'Não deu para acessar · enviando sem prévia';

  @override
  String get chatNoTitleCameBack =>
      'Nenhum título voltou · enviando sem prévia';

  @override
  String get chatCouldnTFetchIt => 'Não deu para buscar · enviando sem prévia';

  @override
  String get chatNoSignalSessionRe => 'Sem sessão Signal - pareie de novo';

  @override
  String get chatMessageUnavailable => 'Mensagem indisponível';

  @override
  String get chatYou2 => 'Você';

  @override
  String get chatThem => 'A pessoa';

  @override
  String get chatVoiceMessage => 'Mensagem de voz';

  @override
  String get chatQuotedPhoto => 'Foto';

  @override
  String get chatViewContact => 'Ver contato';

  @override
  String get chatSharedPhotos => 'Fotos compartilhadas';

  @override
  String chatSharedPhotoCount(int count, Object title) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString fotos',
      one: '$countString foto',
    );
    return '$_temp0 · $title';
  }

  @override
  String get chatUnmuteNotifications => 'Ativar notificações';

  @override
  String get chatMuteNotifications => 'Silenciar notificações';

  @override
  String get chatArchiveChat => 'Arquivar conversa';

  @override
  String get chatWallpaper => 'Papel de parede';

  @override
  String get chatClearConversation => 'Limpar conversa';

  @override
  String get chatNoteOnThisContact => 'Nota sobre este contato';

  @override
  String get chatPinToTop => 'Fixar no topo';

  @override
  String get chatBlockContact => 'Bloquear contato';

  @override
  String get chatUnpinned => 'Desafixada';

  @override
  String get chatPinnedToTop => 'Fixada no topo';

  @override
  String get chatJustForYouNever =>
      'Só para você. Nunca é enviada, nunca sai deste celular.';

  @override
  String get chatAQuietReminder => 'Um lembrete discreto…';

  @override
  String get chatNoteSaved => 'Nota salva';

  @override
  String get chatClearThisConversation => 'Limpar esta conversa?';

  @override
  String get chatEveryMessageHereIs =>
      'Todas as mensagens daqui são apagadas deste celular. Isso só limpa a sua cópia - não mexe no aparelho da pessoa.';

  @override
  String get chatClear => 'Limpar';

  @override
  String get chatBlockThisContact => 'Bloquear este contato?';

  @override
  String get chatTheirMessagesStopArriving =>
      'As mensagens dessa pessoa param de chegar e ela some das suas conversas. Ela nunca fica sabendo. Você pode desbloquear quando quiser nas configurações.';

  @override
  String get commonBlock => 'Bloquear';

  @override
  String get chatSaved => 'Salvo';

  @override
  String get chatRemovedFromSaved => 'Removido dos salvos';

  @override
  String get chatForwardTo => 'Encaminhar para';

  @override
  String get chatNoContactsToForward => 'Nenhum contato para encaminhar';

  @override
  String get chatToday => 'Hoje';

  @override
  String get chatYesterday => 'Ontem';

  @override
  String get chatThisMessageCanT => 'Esta mensagem não pode ser exibida';

  @override
  String get chatJumpToTheNewest => 'Ir para a mais recente';

  @override
  String get chatBuildingAPrivateRoute =>
      'Montando uma rota privada · a primeira conexão é a lenta, as próximas são rápidas. O que você enviar agora fica na fila e é entregue sozinho.';

  @override
  String get chatLooksSafeNothingSuspicious =>
      'Parece seguro · nada suspeito na primeira mensagem';

  @override
  String get chatTheNextPhotoYou =>
      'A próxima foto que você enviar abre protegida · a pessoa não consegue fazer captura de tela dela';

  @override
  String get chatPhotoProtectionOff => 'Proteção de foto desativada';

  @override
  String get chatAcceptToReplyThey =>
      'Aceite para responder - a pessoa só pode mandar mais uma mensagem até você aceitar.';

  @override
  String chatIntroducedYouAcceptTo(Object introducer) {
    return 'Vocês foram apresentados por $introducer. Aceite para responder.';
  }

  @override
  String chatIntroducedYouSayHello(Object vouchNames) {
    return 'Vocês foram apresentados por $vouchNames. Dê um oi - a pessoa também recebeu seu cartão.';
  }

  @override
  String get chatIntroduceTo => 'Apresentar a...';

  @override
  String get chatAcceptThemFirst => 'Aceite a pessoa primeiro';

  @override
  String get chatMessageRequest => 'Pedido de mensagem';

  @override
  String get chatTheyNeedToAccept =>
      'A pessoa precisa aceitar para vocês continuarem conversando.';

  @override
  String get chatWaitingForThemTo => 'Esperando a pessoa aceitar seu pedido';

  @override
  String get chatYouBlockedThisContact => 'Você bloqueou este contato';

  @override
  String get chatSupporter => 'Apoiador';

  @override
  String get chatEncryptedViaRelay => 'Criptografado · via retransmissor';

  @override
  String get chatEncryptedDirect => 'Criptografado · direto';

  @override
  String get chatEncryptedOverTor => 'Criptografado · pelo tor';

  @override
  String get chatSearchThisChat => 'Buscar nesta conversa';

  @override
  String get chatContactOptions => 'Opções do contato';

  @override
  String get commonClose => 'Fechar';

  @override
  String get chatFindInConversation => 'Buscar na conversa';

  @override
  String get chatNoMatches => 'Nenhum resultado';

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
      other: '*$posString* de $countString resultados',
      one: '*$posString* de $countString resultado',
    );
    return '$_temp0';
  }

  @override
  String get chatPreviousMatch => 'Resultado anterior';

  @override
  String get chatNextMatch => 'Próximo resultado';

  @override
  String get chatPhotoUnavailable => 'Foto indisponível';

  @override
  String get chatDelivered => 'Entregue';

  @override
  String get chatEdited => 'Editada';

  @override
  String get chatFailedTapToRetry => 'Falhou · toque para repetir';

  @override
  String get chatReplyingTo => 'Respondendo à pessoa';

  @override
  String get chatReplyingToYourself => 'Respondendo à própria mensagem';

  @override
  String get chatReply => 'Responder';

  @override
  String get chatSayHi => 'Dê um oi.';

  @override
  String get chatJustTheTwoOf =>
      'Só vocês dois, com criptografia de ponta a ponta.';

  @override
  String get chatMicPermissionNeeded => 'Precisa da permissão do microfone';

  @override
  String get chatTheMicWouldNot => 'O microfone não quis ligar. Tente de novo';

  @override
  String get chatReleaseToCancel => 'Solte para cancelar';

  @override
  String get chatVoiceHiddenSlideTo => 'Voz oculta · deslize para cancelar';

  @override
  String get chatSlideToCancel => 'Deslize para cancelar';

  @override
  String get chatGhostMode => 'Mensagens temporárias';

  @override
  String chatMessagesBurnAfter(Object humanBurn) {
    return 'somem após $humanBurn';
  }

  @override
  String get chatTimedMessages => 'Mensagens temporárias';

  @override
  String get chatOpenTheCamera => 'Abrir a câmera';

  @override
  String get chatAttachAPhoto => 'Anexar uma foto';

  @override
  String get chatMessage => 'Mensagem';

  @override
  String get chatDisguiseVoice => 'Disfarçar a voz';

  @override
  String get commonSend => 'Enviar';

  @override
  String get chatNoPhotosInThis => 'Nenhuma foto nesta conversa ainda';

  @override
  String get chatHoldToRecord => 'Segure para gravar uma mensagem de voz';

  @override
  String get chatSendPhoto => 'Enviar foto';

  @override
  String get chatAddACaption => 'Adicionar uma legenda…';

  @override
  String get chatSecurityCodeChanged => 'O código de segurança mudou';

  @override
  String chatMayHaveReinstalledOr(Object peerName) {
    return '$peerName pode ter reinstalado o app, ou alguém pode estar se passando por essa pessoa. Compare os números de segurança para ter certeza.';
  }

  @override
  String get chatOk => 'Ok';

  @override
  String get chatVerify => 'Verificar';

  @override
  String get cleanKryfoCanTClean =>
      'O Kryfo ainda não consegue limpar este tipo de arquivo.';

  @override
  String get cleanThisIsAMotion => 'Esta é uma foto em movimento.';

  @override
  String get cleanThisPictureIsToo =>
      'Esta imagem é grande demais para limpar aqui.';

  @override
  String get cleanThisFileIsDamaged =>
      'Este arquivo está danificado ou incompleto.';

  @override
  String get cleanKryfoCouldNotMake =>
      'O Kryfo não conseguiu deixar este limpo.';

  @override
  String get cleanNotEnoughRoomOn => 'Não há espaço suficiente no celular.';

  @override
  String get cleanKryfoCouldNotOpen =>
      'O Kryfo não conseguiu abrir esse arquivo.';

  @override
  String get cleanItCleansJpegPng =>
      'Ele limpa JPEG, PNG, WebP, HEIC, AVIF, GIF, MP4 e MOV. Nada foi alterado.';

  @override
  String get cleanItHoldsAShort =>
      'Ela guarda um vídeo curto junto da imagem, e o Kryfo ainda não consegue limpar essa parte. Desative o movimento na câmera ou envie uma captura de tela dela.';

  @override
  String get cleanPicturesOver64Mb =>
      'Imagens acima de 64 MB não são limpas no celular. Nada foi alterado.';

  @override
  String get cleanKryfoCouldNotRead =>
      'O Kryfo não conseguiu ler até o fim, então não vai dizer que está limpo. Nenhuma cópia foi feita.';

  @override
  String get cleanSomethingInsideIsOf =>
      'Tem algo dentro de um tipo que ele não sabe remover, então nenhuma cópia foi feita.';

  @override
  String get cleanFreeSomeSpaceAnd =>
      'Libere espaço e tente de novo. Nada foi alterado.';

  @override
  String get cleanTheAppThatShared =>
      'O app que compartilhou pode ter pegado de volta. Tente compartilhar de novo.';

  @override
  String get cleanNoAppOnThis => 'Nenhum app neste celular aceitou o arquivo.';

  @override
  String get cleanCouldNotSaveIt =>
      'Não foi possível salvar. Veja se o celular tem espaço.';

  @override
  String get cleanTheOriginalIsGone =>
      'O original foi excluído. A cópia limpa continua.';

  @override
  String get cleanAndroidWouldNotDelete =>
      'O Android não quis excluí-lo. Remova da galeria manualmente.';

  @override
  String get cleanCleanCopy => 'Cópia limpa';

  @override
  String get cleanShareCleanCopy => 'Compartilhar cópia limpa';

  @override
  String get cleanSaveToGallery => 'Salvar na galeria';

  @override
  String get commonStop => 'Parar';

  @override
  String get cleanReadingTheFile => 'Lendo o arquivo';

  @override
  String get cleanCleaning => 'Limpando';

  @override
  String cleanOf(Object prettySize, Object prettySize2) {
    return '$prettySize de $prettySize2';
  }

  @override
  String get cleanEverythingStaysOnThis => 'Tudo fica neste celular.';

  @override
  String get cleanAlreadyClean => 'Já está limpo.';

  @override
  String get cleanClean => 'Limpo.';

  @override
  String get cleanThereWasNothingTo => 'Não havia nada para achar.';

  @override
  String get cleanNothingLeftToFind => 'Não sobrou nada para achar.';

  @override
  String get cleanSameVideoSameQuality => 'Mesmo vídeo, mesma qualidade';

  @override
  String get cleanSamePictureSameQuality => 'Mesma imagem, mesma qualidade';

  @override
  String cleanRemoved(Object label) {
    return '$label: removido';
  }

  @override
  String get cleanRemoved2 => 'REMOVIDO';

  @override
  String get cleanWithTheLocationInside =>
      'com a localização dentro. Quem receber esse arquivo descobre a sua rua.';

  @override
  String get cleanWithEverythingItKnew => 'com tudo o que sabia ainda dentro.';

  @override
  String get cleanOriginal => 'ORIGINAL';

  @override
  String get cleanClean2 => 'LIMPO';

  @override
  String get cleanSavedToYourGallery => 'Salvo na sua galeria.';

  @override
  String cleanTheOriginalIsStill(Object what) {
    return 'O original ainda está lá também, $what';
  }

  @override
  String cleanTheOriginalIsStillWhereIt(Object what) {
    return 'O original continua onde estava, $what O Kryfo não consegue removê-lo daqui, então exclua no app de onde ele veio.';
  }

  @override
  String get cleanDeleteTheOriginal => 'Excluir o original';

  @override
  String get cleanKeepBoth => 'Manter os dois';

  @override
  String get commonDone => 'Pronto';

  @override
  String get cleanAndroidWillAskYou => 'O ANDROID VAI PEDIR CONFIRMAÇÃO';

  @override
  String get contactYourNameForThem => 'Seu apelido para a pessoa';

  @override
  String get contactStaysOnThisPhone =>
      'Fica neste celular. A pessoa nunca vê.';

  @override
  String get contactClear => 'Limpar';

  @override
  String get contactMessage => 'Mensagem';

  @override
  String get contactKeysVerified => 'Chaves verificadas';

  @override
  String get contactVerifyKeys => 'Verificar chaves';

  @override
  String get contactVouches => 'Recomendações';

  @override
  String get contactUnmute => 'Ativar som';

  @override
  String get contactMute => 'Silenciar';

  @override
  String get contactUnpin => 'Desafixar';

  @override
  String get contactPinToTop => 'Fixar no topo';

  @override
  String get contactArchive => 'Arquivar';

  @override
  String get contactOutOfTheList =>
      'Fora da lista até a pessoa escrever de novo';

  @override
  String contactBlock(Object name) {
    return 'Bloquear $name?';
  }

  @override
  String get contactTheirMessagesStopArriving =>
      'As mensagens dessa pessoa param de chegar. Ela não fica sabendo.';

  @override
  String get contactDeleteChat => 'Excluir conversa';

  @override
  String get contactMessagesAndContactGone =>
      'Mensagens e contato somem deste celular';

  @override
  String get contactDeleteThisChat => 'Excluir esta conversa?';

  @override
  String get contactEveryMessageAndThe =>
      'Todas as mensagens e o contato somem deste celular. Nada é enviado para a pessoa.';

  @override
  String get commonDelete => 'Excluir';

  @override
  String get contactDeleted => 'Excluída';

  @override
  String get contactToday => 'Hoje';

  @override
  String contactD(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dias',
      one: '$count dia',
    );
    return '$_temp0';
  }

  @override
  String contactMo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count meses',
      one: '$count mês',
    );
    return '$_temp0';
  }

  @override
  String contactY(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count anos',
      one: '$count ano',
    );
    return '$_temp0';
  }

  @override
  String get contactVerified => 'Verificado';

  @override
  String get contactChatting => 'Conversando';

  @override
  String get contactNothingSharedYet => 'Nada compartilhado ainda';

  @override
  String contactSharedMedia(Object count) {
    return 'Mídia compartilhada · $count';
  }

  @override
  String get donateBitcoin => 'Bitcoin';

  @override
  String get donateText => '₿';

  @override
  String get donateBadgeUnlocks => 'Libera o selo';

  @override
  String get donateMonero => 'Monero';

  @override
  String get donateManualNoBadge => 'Manual · sem selo';

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
          'Seu pagamento anterior em bitcoin foi encontrado · selo de apoiador liberado',
      'patron':
          'Seu pagamento anterior em bitcoin foi encontrado · selo de mecenas liberado',
      'guardian':
          'Seu pagamento anterior em bitcoin foi encontrado · selo de guardião liberado',
      'other':
          'Seu pagamento anterior em bitcoin foi encontrado · selo de apoiador liberado',
    });
    return '$_temp0';
  }

  @override
  String get donateSupport => 'Apoiar';

  @override
  String get donateKeepKryfo => 'Mantenha o Kryfo *independente*';

  @override
  String get donateNoAdsNoInvestors =>
      'Sem anúncios, sem investidores, nada para vender. Ele se mantém com as doações de quem apoia.';

  @override
  String get donateBackItAnonymouslyBadge =>
      'Apoie de forma anônima. Selo só se você quiser.\n*Privacidade nunca é recurso pago.*';

  @override
  String donateAddressCheckItAgainst(Object coinName) {
    return 'Endereço $coinName · confira com a sua carteira';
  }

  @override
  String get donateAddressCopiedClearsIn => 'Endereço copiado · some em 60s';

  @override
  String get donateCopyAddress => 'Copiar endereço';

  @override
  String get donateBitcoinIsVerifiedBy =>
      'O bitcoin é verificado pelo nosso próprio nó, então seu selo é liberado sozinho assim que o pagamento chegar.';

  @override
  String get donateWeCanTVerify =>
      'Não temos como verificar esta blockchain sem perguntar sobre você a um serviço de fora, então não verificamos. Envie se quiser. Isso não vai liberar um selo.';

  @override
  String get donateBitcoinBadgesNeedOnion =>
      'Selos em bitcoin precisam do modo onion';

  @override
  String get donateSwitchToOnion => 'Mudar para onion';

  @override
  String get donatePayWithBitcoin => 'Pagar com bitcoin  →';

  @override
  String get donateBadgesStartAt20 => 'Selos a partir de US\$ 20';

  @override
  String get donateReachingThePaymentService =>
      'Acessando o serviço de pagamento pelo tor…';

  @override
  String get donateThisCanTakeUp => 'Isso pode levar até um minuto';

  @override
  String donateSThisCanTake(Object waited) {
    return '${waited}s · isso pode levar até um minuto';
  }

  @override
  String get donateUseTheAddressInstead => 'Usar o endereço no lugar';

  @override
  String get donateThePaymentServiceIs =>
      'O serviço de pagamento é um onion, e só o modo onion consegue acessá-lo. Nada foi enviado.';

  @override
  String get donateTorWasSlowTo =>
      'O tor demorou para acessar o serviço de pagamento. Você pode doar para o endereço abaixo - só que seu selo não vai ser liberado automaticamente. Tente de novo mais tarde para ganhar o selo.';

  @override
  String get donateThePaymentServiceIsHavingTrouble =>
      'O serviço de pagamento está com problemas agora. Você ainda pode doar para o endereço abaixo - só que seu selo não vai ser liberado automaticamente. Tente de novo mais tarde para ganhar o selo.';

  @override
  String get commonTryAgain => 'Tentar de novo';

  @override
  String donateBtc(Object btc) {
    return '$btc BTC';
  }

  @override
  String donateSendExactlyThisAmount(Object fmtLeft) {
    return 'Envie exatamente este valor · expira em $fmtLeft';
  }

  @override
  String get donateOpenWallet => 'Abrir carteira';

  @override
  String get donateThisScreenUpdatesItself =>
      'Esta tela se atualiza sozinha assim que seu pagamento for visto.\nDeixe aberta - nada é guardado, nada identifica você.';

  @override
  String get donateWatchingTheChainFor =>
      'Aguardando seu pagamento na blockchain';

  @override
  String get donateThisInvoiceExpired => 'Esta fatura expirou';

  @override
  String get donateInvoicesTimeOutIf =>
      'Faturas expiram. Se você já enviou o pagamento, deixe isto aberto: perguntamos de novo ao serviço a cada minuto por um tempo, e da próxima vez que você abrir Apoiar. Comece uma nova quando quiser.';

  @override
  String get donateNewInvoice => 'Nova fatura';

  @override
  String get donateIPaidCheckAgain => 'Já paguei, verificar de novo';

  @override
  String get donateNoWallet =>
      'Nenhum app deste celular abre links de bitcoin. Copie o endereço.';

  @override
  String get donateChecking => 'Verificando…';

  @override
  String get donateNotSeenYet =>
      'Ainda não apareceu. Um pagamento pode levar alguns minutos para aparecer.';

  @override
  String get donatePaymentConfirmed => 'Pagamento confirmado';

  @override
  String get donateThankYouForKeeping =>
      'Obrigado por manter o Kryfo independente.';

  @override
  String donateVerifiedOnChainYou(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter':
          'Verificado na blockchain - agora você é apoiador. Ninguém pode tirar isso de você.',
      'patron':
          'Verificado na blockchain - agora você é mecenas. Ninguém pode tirar isso de você.',
      'guardian':
          'Verificado na blockchain - agora você é guardião. Ninguém pode tirar isso de você.',
      'other':
          'Verificado na blockchain - agora você é apoiador. Ninguém pode tirar isso de você.',
    });
    return '$_temp0';
  }

  @override
  String get donateWearMyBadge => 'Usar meu selo';

  @override
  String get donateJustGladToHelp => 'Fico feliz só de ajudar';

  @override
  String get gettingMessagesGettingMessages => 'Receber mensagens';

  @override
  String get gettingMessagesHowNewMessagesReach =>
      'Como as novas mensagens chegam a este celular. Você pode mudar quando quiser.';

  @override
  String get gettingMessagesAlwaysOn => 'Sempre ativo';

  @override
  String get gettingMessagesMostPrivate => 'Mais privado';

  @override
  String get gettingMessagesMessagesArriveInstantlyNothing =>
      'As mensagens chegam na hora. Tudo fica dentro do Tor. Gasta mais bateria.';

  @override
  String get gettingMessagesCheckIns => 'Consultas';

  @override
  String get gettingMessagesLightest => 'Mais leve';

  @override
  String get gettingMessagesKryfoLooksForMessages =>
      'O Kryfo procura mensagens a cada 15 minutos. Economiza bateria, mas as mensagens podem atrasar.';

  @override
  String get gettingMessagesOnTheLockScreen => 'Na tela de bloqueio';

  @override
  String get gettingMessagesHideMessagePreview => 'Ocultar prévia da mensagem';

  @override
  String get gettingMessagesAGenericAlertWith =>
      'Um alerta genérico, sem remetente e sem texto da mensagem';

  @override
  String get gettingMessagesShowsMessageTextIn =>
      'Mostra o texto das mensagens nas notificações, mesmo com o Kryfo bloqueado.';

  @override
  String get gettingMessagesWhenThePhoneSits =>
      'Quando o celular fica parado, o Android espaça mais as consultas. A linha acima mostra a última de verdade. Enquanto o Kryfo está aberto, ele fica conectado.';

  @override
  String get groupChatJumpToTheNewest => 'Ir para a mais recente';

  @override
  String get groupChatBlockedEverywhere => 'Bloqueado em todo lugar';

  @override
  String get groupChatYou => 'Você';

  @override
  String get groupChatVoiceMessage => 'Mensagem de voz';

  @override
  String get groupChatQuotedPhoto => 'Foto';

  @override
  String get groupChatMessageUnavailable => 'Mensagem indisponível';

  @override
  String get groupChatTorIsNotUp =>
      'O tor ainda não está pronto · enviando sem prévia';

  @override
  String get groupChatCouldnTReachIt =>
      'Não deu para acessar · enviando sem prévia';

  @override
  String get groupChatNoTitleCameBack =>
      'Nenhum título voltou · enviando sem prévia';

  @override
  String get groupChatCouldnTFetchIt =>
      'Não deu para buscar · enviando sem prévia';

  @override
  String get groupChatCamera => 'Câmera';

  @override
  String get groupChatGallery => 'Galeria';

  @override
  String get groupChatVideo => 'Vídeo';

  @override
  String get groupChatGifFromPhone => 'Gif do celular';

  @override
  String get groupChatFile => 'Arquivo';

  @override
  String get groupChatCouldNotReadThat => 'Não foi possível ler esse arquivo';

  @override
  String get groupChatGifTooBig8 => 'Gif grande demais · máx. 8 mb';

  @override
  String get groupChatCouldNotCleanThat => 'Não foi possível limpar esse gif';

  @override
  String get groupChatFileTooBig8 => 'Arquivo grande demais · máx. 8 mb';

  @override
  String get groupChatCouldNotCleanThatVideo =>
      'Não foi possível limpar esse vídeo';

  @override
  String get groupChatCouldNotCleanThatPictureSend =>
      'Não foi possível limpar essa imagem · envie como foto';

  @override
  String get groupChat30Seconds => '30 segundos';

  @override
  String get groupChat1Minute => '1 minuto';

  @override
  String get groupChat5Minutes => '5 minutos';

  @override
  String get groupChat1Hour => '1 hora';

  @override
  String get groupChat24Hours => '24 horas';

  @override
  String get groupChatBurnTimer => 'Mensagens temporárias';

  @override
  String get groupChatNewMessagesDisappearAfter =>
      'Novas mensagens somem depois desse tempo';

  @override
  String get groupChatToday => 'Hoje';

  @override
  String get groupChatYesterday => 'Ontem';

  @override
  String get groupChatYou2 => 'Você';

  @override
  String groupChatThisChatHasPins(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Esta conversa já tem $countString mensagens fixadas',
      one: 'Esta conversa já tem $countString mensagem fixada',
    );
    return '$_temp0';
  }

  @override
  String get groupChatUnpinThisMessage => 'Desafixar esta mensagem?';

  @override
  String get groupChatPinThisMessage => 'Fixar esta mensagem?';

  @override
  String get groupChatItLeavesThePinned =>
      'Ela sai da lista de fixadas para todos aqui.';

  @override
  String get groupChatItGoesUnderThe =>
      'Ela entra nas fixadas, no topo da conversa, para todos aqui.';

  @override
  String get groupChatUnpin => 'Desafixar';

  @override
  String get groupChatPinIt => 'Fixar';

  @override
  String get groupChatNotNow => 'Agora não';

  @override
  String get groupChatSaved => 'Salvo';

  @override
  String get groupChatRemovedFromSaved => 'Removido dos salvos';

  @override
  String get groupChatForwardTo => 'Encaminhar para';

  @override
  String get groupChatNoContactsToForward => 'Nenhum contato para encaminhar';

  @override
  String get groupChatEditMessage => 'Editar mensagem';

  @override
  String get groupChatUnsendMessage => 'Desfazer envio';

  @override
  String get groupChatItDisappearsWithNo =>
      'Ela some sem deixar rastro. Isso não pode ser desfeito.';

  @override
  String get groupChatUnsend => 'Desfazer envio';

  @override
  String groupChatThisRoomAndEverything(Object expiryWords) {
    return 'Esta sala e tudo o que há nela somem em $expiryWords';
  }

  @override
  String groupChatGhostModeOnBurns(Object fmtBurn) {
    return 'Mensagens temporárias · somem após $fmtBurn';
  }

  @override
  String get groupChatGroupCreatedSayHi => 'Grupo criado. Dê um oi.';

  @override
  String get groupChatNoMessagesYet => 'Nenhuma mensagem ainda.';

  @override
  String get groupChatEveryoneHereReads =>
      'Todos aqui leem o que você escreve.';

  @override
  String get groupChatNobodyHereYet => 'Ainda não há ninguém aqui.';

  @override
  String get groupChatShareTheRoomLink =>
      'Compartilhe o link da sala. Quem entrar lê o que for escrito a partir daí.';

  @override
  String get groupChatNobodyToReadIt => 'Não há mais ninguém aqui para ler.';

  @override
  String get groupChatThisMessageCanT => 'Esta mensagem não pode ser exibida';

  @override
  String groupChatS(Object s) {
    return '${s}s';
  }

  @override
  String groupChatM(Object s) {
    return '${s}min';
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
      other: '$time · $countString aqui',
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
      other: '$countString membros',
      one: '$countString membro',
    );
    return '$_temp0';
  }

  @override
  String get groupChatSearchThisChat => 'Buscar nesta conversa';

  @override
  String groupChatReplyingTo(Object name) {
    return 'Respondendo a $name';
  }

  @override
  String get groupChatReplyingToYou => 'Respondendo a você';

  @override
  String get groupChatTimedMessages => 'Mensagens temporárias';

  @override
  String get groupChatOpenTheCamera => 'Abrir a câmera';

  @override
  String get groupChatAttachAPhoto => 'Anexar uma foto';

  @override
  String get groupChatMessage => 'Mensagem';

  @override
  String get groupChatDisguiseVoice => 'Disfarçar a voz';

  @override
  String get groupChatSupporter => 'Apoiador';

  @override
  String get groupChatEdited => 'Editada';

  @override
  String get groupChatTapToRetry => '! Toque para repetir';

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
      other: 'Enviado · $haveString de $countString já receberam',
      one: 'Enviado · $haveString de $countString já recebeu',
      zero: 'Enviado · a caminho',
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
      other: 'Enviado · $countString não receberam',
      one: 'Enviado · $countString não recebeu',
    );
    return '$_temp0';
  }

  @override
  String get groupChat0s => '0s';

  @override
  String get groupChatReply => 'Responder';

  @override
  String get groupChatPin => 'Fixar';

  @override
  String get groupChatUnsave => 'Tirar dos salvos';

  @override
  String get groupChatForward => 'Encaminhar';

  @override
  String get groupInfoGroup => 'Grupo';

  @override
  String get groupInfoRenameGroup => 'Renomear grupo';

  @override
  String get groupInfoRename => 'Renomear';

  @override
  String get groupInfoNoContactsToAdd => 'Ninguém para adicionar';

  @override
  String get groupInfoCouldNotAdd => 'Falha ao adicionar';

  @override
  String groupInfoRemove(Object haloId) {
    return 'Remover $haloId?';
  }

  @override
  String get groupInfoTheyWillStopReceiving =>
      'A pessoa vai parar de receber mensagens deste grupo.';

  @override
  String appGroupHoldsUpTo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Um grupo comporta até $countString pessoas',
      one: 'Um grupo comporta até $countString pessoa',
    );
    return '$_temp0';
  }

  @override
  String get commonRemove => 'Remover';

  @override
  String get groupInfoClearThisConversation => 'Limpar esta conversa?';

  @override
  String get groupInfoEveryMessageHereIs =>
      'Todas as mensagens daqui são apagadas deste celular. Isso só limpa a sua cópia, os outros membros ficam com as deles.';

  @override
  String get groupInfoClear => 'Limpar';

  @override
  String get groupInfoConversationCleared => 'Conversa limpa';

  @override
  String get groupInfoLeaveRoom => 'Sair da sala?';

  @override
  String get groupInfoLeaveGroup => 'Sair do grupo?';

  @override
  String get groupInfoEverythingInItIs =>
      'Tudo o que está aqui é apagado deste celular agora, e a chave que você usou aqui some para sempre.';

  @override
  String groupChatYouWereRemovedFrom(Object name) {
    return 'Você não faz mais parte de $name';
  }

  @override
  String get groupInfoLeaveGroupLine =>
      'Você vai parar de receber mensagens deste grupo, e tudo o que está nele é apagado deste celular.';

  @override
  String get groupInfoLeaveGroupAdmin =>
      'Você vai parar de receber mensagens deste grupo, e tudo o que está nele é apagado deste celular. Você é o admin, então depois que sair ninguém poderá mudar quem está nele nem renomeá-lo.';

  @override
  String get groupInfoLeaveRoomMaker =>
      'Tudo o que está aqui é apagado deste celular agora, e a chave que você usou aqui some para sempre. Você criou esta sala, então o link dela não vai deixar mais ninguém entrar.';

  @override
  String get groupInfoLeave => 'Sair';

  @override
  String get groupInfoGroupInfo => 'Sobre o grupo';

  @override
  String groupInfo1Member(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString membros',
      one: '$countString membro',
    );
    return '$_temp0';
  }

  @override
  String get groupInfoAdmin => 'Admin';

  @override
  String get groupInfoMembers2 => 'Membros';

  @override
  String get groupInfoInvite => 'Convidar';

  @override
  String get commonAdd => 'Adicionar';

  @override
  String get groupInfoYou => 'Você';

  @override
  String get groupInfoRemoveFromGroup => 'Remover do grupo';

  @override
  String get groupInfoWallpaper => 'Papel de parede';

  @override
  String get groupInfoSharedMedia => 'Mídia compartilhada';

  @override
  String get groupInfoClearConversation => 'Limpar conversa';

  @override
  String get groupInfoLeaveRoom2 => 'Sair da sala';

  @override
  String get groupInfoLeaveGroup2 => 'Sair do grupo';

  @override
  String get groupInfoAddMembers => 'Adicionar membros';

  @override
  String groupInfoAdd(Object pickedLength) {
    return 'Adicionar $pickedLength';
  }

  @override
  String handleYouAre(Object h) {
    return 'Você é @$h';
  }

  @override
  String get handleHandleDeletedThePage =>
      'Nome de usuário excluído · a página saiu do ar';

  @override
  String get handlePublicHandle => 'Nome de usuário público';

  @override
  String get handleOptionalYourThreeWords =>
      'Opcional. Suas três palavras continuam funcionando de qualquer jeito.';

  @override
  String get handleWren => 'sabia';

  @override
  String get handleALineAboutYou => 'Uma linha sobre você · opcional';

  @override
  String get handleClaiming => 'Reservando…';

  @override
  String get handleClaimThisHandle => 'Reservar nome de usuário';

  @override
  String get handleAnyoneWithThisLink =>
      'Qualquer pessoa com este link pode começar uma conversa privada com você. Ele leva o seu convite e mais nada.';

  @override
  String get handleLinkCopied => 'Link copiado';

  @override
  String get handleDeleteThisHandle => 'Excluir este nome de usuário';

  @override
  String handleDeleteTitle(Object handle) {
    return 'Excluir @$handle?';
  }

  @override
  String get handleDeleteLine =>
      'Sua página pública sai do ar e qualquer pessoa pode ficar com o nome. Suas conversas continuam como estão.';

  @override
  String get handleDeleteYes => 'Excluir nome de usuário';

  @override
  String get handleDeleting => 'Excluindo…';

  @override
  String get handleChecking => 'Verificando…';

  @override
  String get handleAvailable => '✓ Disponível';

  @override
  String get handleAlreadyTaken => 'Já está em uso';

  @override
  String get handleNameRule => 'De 3 a 20 caracteres: a-z, 0-9 ou _';

  @override
  String get handleWhatAHandleDoes => 'O que é um nome de usuário';

  @override
  String get handleAnyoneWhoKnowsIt =>
      'Qualquer pessoa que souber o nome pode pedir para falar com você, e é para isso que ele serve. A página guarda o seu convite e a linha que você escreveu, mais nada, e não registra quem a lê. Você pode excluí-lo quando quiser.';

  @override
  String handleIsNotYoursOn(Object handle) {
    return '@$handle não é seu neste celular';
  }

  @override
  String handleTheRegistryHoldsIt(Object handle) {
    return 'O registro guarda esse nome com outra chave, provavelmente uma identidade que este celular tinha antes de uma restauração. Quem adiciona @$handle não está falando com você. Ele não pode ser liberado nem atualizado daqui. Escolha outro nome.';
  }

  @override
  String get handleForgetItOnThis => 'Esquecer neste celular';

  @override
  String get homeAddAContact => 'Adicionar contato';

  @override
  String get commonSettings => 'Configurações';

  @override
  String get homeYourKryfo => 'Seu Kryfo';

  @override
  String homeDateWeekday(Object weekday) {
    return '$weekday,';
  }

  @override
  String get homeAnHour => 'uma hora';

  @override
  String homeHours(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString horas',
      one: '$countString hora',
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
      other: '$countString minutos',
      one: '$countString minuto',
    );
    return '$_temp0';
  }

  @override
  String get homeKryfoIsOffline => 'O Kryfo está offline';

  @override
  String homeTorHasNotBeen(Object howLong) {
    return 'O tor não consegue se conectar há $howLong. Nada pode chegar nem sair até ele conseguir.';
  }

  @override
  String get homeReconnecting => 'Reconectando';

  @override
  String get homeReconnect => 'Reconectar';

  @override
  String get homeWhatIsWrong => 'Qual é o problema';

  @override
  String get homeKryfoWillCheckIn =>
      'O Kryfo vai fazer uma consulta a cada 15 minutos';

  @override
  String get homeYourPhoneKeepsStopping => 'Seu celular fica parando o Kryfo';

  @override
  String get homeItHasClosedKryfo =>
      'Ele fechou o Kryfo três vezes hoje, então as mensagens atrasaram ou ficaram esperando. As consultas resistem a isso: o Kryfo acorda a cada 15 minutos em vez de ficar conectado.';

  @override
  String get homeSwitchToCheckIns => 'Mudar para consultas';

  @override
  String get homeNotNow => 'Agora não';

  @override
  String get homeNotificationsAreOff => 'As notificações estão desativadas';

  @override
  String get homeAndroidIsBlockingThem =>
      'O Android está bloqueando as notificações, então nada chega até você enquanto o Kryfo está fechado. As mensagens ainda chegam quando você abre o app.';

  @override
  String get homeCouldnTOpenIt =>
      'Não deu para abrir. Procure o Kryfo nas configurações do celular';

  @override
  String get homeTurnThemOn => 'Ativar';

  @override
  String get homeLeaveThemOff => 'Deixar desativadas';

  @override
  String get homeOurRelayIsQuiet => 'Retransmissor em silêncio';

  @override
  String get homeRelayModeUsesOnly =>
      'O modo retransmissor usa só o nosso retransmissor, e ele não está respondendo agora. O modo rápido adiciona retransmissores públicos junto com ele, então as mensagens ainda chegam. Tudo continua lacrado de qualquer jeito.';

  @override
  String get homeSwitchedToFast => 'Mudou para rápido';

  @override
  String get homeUseFastMode => 'Usar o modo rápido';

  @override
  String get homeKeepWaiting => 'Esperar';

  @override
  String get homeNotConnecting => 'Não está conectando';

  @override
  String get homeBridgesAreOnAnd =>
      'As pontes estão ativas e o tor ainda não passou. Pontes são mais lentas, e algumas param de funcionar sem aviso. Se a sua rede não bloqueia o tor, ir direto é mais rápido e mais confiável.';

  @override
  String get homeGoingDirectReconnecting => 'Indo direto · reconectando';

  @override
  String get homeTurnBridgesOff => 'Desativar pontes';

  @override
  String get homeStillTrying => 'Ainda tentando';

  @override
  String get homeTorIsNotGetting =>
      'O tor não está conseguindo passar. Algumas redes bloqueiam o tor de propósito. Nosso retransmissor é uma conexão simples e costuma funcionar mesmo assim - ou as pontes, que demoram mais para configurar.';

  @override
  String get homeSwitchedToRelay => 'Mudou para retransmissor';

  @override
  String get homeUseOurRelay => 'Usar retransmissor';

  @override
  String get homeBridges => 'Pontes';

  @override
  String get homeOffline => 'Offline';

  @override
  String get homeWaiting => 'Esperando';

  @override
  String get homeNothingWaitingToSend => 'Nada esperando para enviar';

  @override
  String homeWaitingSendsWhenYou(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString esperando · sai quando você voltar',
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
      other: '$countString esperando · o tor ainda está conectando',
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
      other: '$countString esperando · enviando agora',
    );
    return '$_temp0';
  }

  @override
  String get commonRetry => 'Reenviar';

  @override
  String get homeNoKryfosYet => 'Nenhum Kryfo ainda.';

  @override
  String get homeScanTheirCodeSend =>
      'Escaneie o código da pessoa, envie um link ou digite o @nome de usuário que ela passou.';

  @override
  String get homeAddSomeone => 'Adicionar alguém';

  @override
  String get homeArchived => 'Arquivadas';

  @override
  String home1Chat(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString conversas',
      one: '$countString conversa',
    );
    return '$_temp0';
  }

  @override
  String get homeGroups => 'Grupos';

  @override
  String get homeRoom => 'Sala';

  @override
  String get homeNew => 'Novo';

  @override
  String homeRoomExpired(Object expiredRoomName) {
    return '$expiredRoomName · sala expirada';
  }

  @override
  String get homeMentionedYou => 'Mencionou você';

  @override
  String homeMembers(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString membros',
      one: '$countString membro',
    );
    return '$_temp0';
  }

  @override
  String get homeSupporter => 'Apoiador';

  @override
  String get homeArchivedChats => 'Conversas arquivadas';

  @override
  String get homeUnmute => 'Ativar som';

  @override
  String get homeMute => 'Silenciar';

  @override
  String get homeArchive => 'Arquivar';

  @override
  String get homeDeleteChat => 'Excluir conversa';

  @override
  String get homeMessagesAndContactGone =>
      'Mensagens e contato somem deste celular';

  @override
  String get homeDeleteThisChat => 'Excluir esta conversa?';

  @override
  String homeEveryMessageWithGoes(Object c) {
    return 'Todas as mensagens com $c somem, e a pessoa deixa de ser um contato. Isso só limpa este celular - a cópia dela continua com ela. Se ela mandar mensagem de novo, vai cair nos pedidos.';
  }

  @override
  String get homeQueued => 'Na fila';

  @override
  String get homeBlocked => 'Bloqueado';

  @override
  String get homeRoomInvite => 'Convite para sala';

  @override
  String get homeNow => 'Agora';

  @override
  String homeM(Object inMinutes) {
    return '${inMinutes}min';
  }

  @override
  String homeH(Object inHours) {
    return '${inHours}h';
  }

  @override
  String get homeYesterday => 'Ontem';

  @override
  String homeD(Object inDays) {
    return '${inDays}d';
  }

  @override
  String get homeNoteToSelf => 'Notas';

  @override
  String get homeOnlyOnThisPhone => 'Só neste celular';

  @override
  String get homeSaved => 'Salvos';

  @override
  String get homeKeptFromEveryChat => 'Guardadas de todas as conversas';

  @override
  String get homeRequests => 'Pedidos';

  @override
  String home1PersonWantsTo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString pessoas querem falar com você',
      one: '$countString pessoa quer falar com você',
    );
    return '$_temp0';
  }

  @override
  String introduceGotItButCould(Object b, Object c) {
    return '$b recebeu, mas não deu para falar com $c';
  }

  @override
  String introduceGotItButCouldNotBe(Object c, Object b) {
    return '$c recebeu, mas não deu para falar com $b';
  }

  @override
  String introduceIntroduced(Object b, Object c) {
    return '$b e $c agora têm o cartão um do outro';
  }

  @override
  String get introduceCouldNotReachEither =>
      'Não deu para falar com nenhum dos dois. Tente de novo mais tarde';

  @override
  String introduceIntroduceTo(Object peerName) {
    return 'Apresentar $peerName a...';
  }

  @override
  String get introduceBothOfThemGet =>
      'Os dois recebem o cartão um do outro. Nenhum dos dois vê o nome que você dá ao outro.';

  @override
  String get introduceNoOneElseTo =>
      'Ainda não tem mais ninguém para apresentar. Adicione outro contato primeiro.';

  @override
  String get introduceANoteLikeMy => 'Uma nota, como “meu primo” - opcional';

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
      other: '$leftString de $maxString apresentações disponíveis esta semana',
      one: '$leftString de $maxString apresentação disponível esta semana',
    );
    return '$_temp0';
  }

  @override
  String introduceNoIntroductionsLeftNext(Object refillPhrase) {
    return 'Nenhuma apresentação disponível. A próxima fica livre $refillPhrase';
  }

  @override
  String get introduceIntroduce => 'Apresentar';

  @override
  String get keyVerificationSafetyNumber => 'Número de segurança';

  @override
  String keyVerificationWith(Object peerName) {
    return 'Com $peerName';
  }

  @override
  String keyVerificationIfSeesTheSame(Object peerName) {
    return 'Se $peerName vir o mesmo número, suas mensagens são privadas só entre vocês dois. Comparar pessoalmente ou numa ligação de confiança é o jeito mais seguro de ter certeza - mas é opcional, nunca obrigatório para conversar.';
  }

  @override
  String get keyVerificationVerified => 'Verificado';

  @override
  String get keyVerificationMarkAsVerified => 'Marcar como verificado';

  @override
  String get lockFileThatPasswordDoesNot => 'Essa senha não abre o arquivo.';

  @override
  String get lockFileThisFileIsDamaged => 'Este arquivo está danificado.';

  @override
  String get lockFileThisFileWasLocked =>
      'Este arquivo foi trancado com uma chave, não com uma senha.';

  @override
  String get lockFileThisIsNotA => 'Este não é um arquivo trancado.';

  @override
  String get lockFileNotEnoughFreeMemory =>
      'Não há memória livre suficiente agora.';

  @override
  String get lockFileStopped => 'Parado.';

  @override
  String get lockFileItNeedsAPassword => 'Ele precisa de uma senha.';

  @override
  String get lockFileKryfoCouldNotRead =>
      'O Kryfo não conseguiu ler ou gravar o arquivo.';

  @override
  String get lockFileCheckCapitalsAndSpaces =>
      'Confira maiúsculas e espaços. Ninguém pode redefinir a senha, nem nós.';

  @override
  String get lockFileItMayHaveBeen =>
      'Ele pode ter sido cortado no caminho. Peça para enviarem de novo. Nada foi salvo.';

  @override
  String get lockFileItOpensWithThe =>
      'Ele abre com o arquivo de chave da pessoa para quem foi feito, na ferramenta age num computador. O Kryfo abre o tipo com senha.';

  @override
  String get lockFileKryfoOpensFilesLocked =>
      'O Kryfo abre arquivos trancados com age. Eles geralmente terminam em .age.';

  @override
  String get lockFileCloseAFewApps =>
      'Feche alguns apps e tente de novo. A verificação da senha precisa de algumas centenas de megabytes por um momento.';

  @override
  String get lockFileNothingWasSaved => 'Nada foi salvo.';

  @override
  String get lockFileTypeOneOrLet =>
      'Digite uma, ou deixe o Kryfo sugerir quatro palavras.';

  @override
  String get lockFileTheAppThatHolds =>
      'O app que guarda o arquivo pode ter pegado de volta. Escolha de novo.';

  @override
  String get lockFileHidePassword => 'Ocultar senha';

  @override
  String get lockFileShowPassword => 'Mostrar senha';

  @override
  String get lockFileChangeFile => 'Trocar arquivo';

  @override
  String get lockFileChange => 'Trocar';

  @override
  String lockFileOf(Object prettySize, Object prettySize2) {
    return '$prettySize de $prettySize2';
  }

  @override
  String get lockFileEverythingStaysOnThis => 'Tudo fica neste celular.';

  @override
  String get lockFileCouldNotMakeOne => 'Não deu para criar uma. Digite a sua.';

  @override
  String get lockFileWriteItDownBefore => 'Anote antes de trancar o arquivo';

  @override
  String get lockFileNoAppOnThis =>
      'Nenhum app neste celular aceitou o arquivo.';

  @override
  String get lockFileSaved => 'Salvo';

  @override
  String get lockFileCouldNotSaveIt =>
      'Não deu para salvar aí. Tente outra pasta.';

  @override
  String get lockFileLocked => 'Trancado';

  @override
  String get lockFileLockAFile => 'Trancar um arquivo';

  @override
  String get lockFileMixingThePassword => 'Misturando a senha';

  @override
  String get lockFileLocking => 'Trancando';

  @override
  String get lockFileSaveToFiles => 'Salvar em Arquivos';

  @override
  String get lockFileLockFile => 'Trancar arquivo';

  @override
  String get lockFileOnePassword => 'Uma senha.';

  @override
  String get lockFileNothingElseOpensIt => 'Nada mais abre o arquivo.';

  @override
  String get lockFileFile => 'Arquivo';

  @override
  String lockFileFromFiles(Object prettySize) {
    return '$prettySize · de Arquivos';
  }

  @override
  String get lockFileFromFiles2 => 'De Arquivos';

  @override
  String get lockFilePassword => 'Senha';

  @override
  String get lockFileSuggestFourWords => 'Sugerir quatro palavras';

  @override
  String get lockFileTypeItAgain => 'Digite de novo';

  @override
  String get lockFileTheTwoDoNot => 'As duas ainda não são iguais.';

  @override
  String get lockFileHideTheFileName => 'Ocultar o nome do arquivo';

  @override
  String lockFileItWillBeCalled(Object name) {
    return 'Ele vai se chamar “$name”. Diga à pessoa que tipo de arquivo é.';
  }

  @override
  String get lockFileTheNameAloneCan =>
      'Só o nome já pode dizer o que tem dentro.';

  @override
  String get lockFileAnyoneWithThePassword =>
      'Qualquer pessoa com a senha pode abrir o arquivo, no Kryfo ou em qualquer computador com a ferramenta gratuita age. Se você esquecer a senha, o arquivo se perde para sempre. Ninguém pode redefini-la, nem nós.';

  @override
  String get lockFileLocked2 => 'Trancado.';

  @override
  String get lockFileOnlyThePasswordOpens => 'Só a senha abre o arquivo.';

  @override
  String lockFileSafeToEmailOr(Object prettySize) {
    return '$prettySize · seguro para mandar por e-mail ou pôr num pendrive';
  }

  @override
  String get lockFileNoKryfoOnThe =>
      'A outra pessoa não tem Kryfo? Num computador:';

  @override
  String get lockFileItAsksForThe =>
      'Ele pede a senha. O age é gratuito em age-encryption.org';

  @override
  String lockTooManyTriesS(Object lockState) {
    return 'Tentativas demais · ${lockState}s';
  }

  @override
  String get lockNotIt => 'Não é esse';

  @override
  String get lockYourPin => 'Seu PIN';

  @override
  String get lockUseFingerprint => 'Usar digital';

  @override
  String get lockSetupUnlockWithFingerprint => 'Desbloquear com a digital?';

  @override
  String get lockSetupThePinStillWorks =>
      'O PIN continua funcionando sempre que você quiser. Isso só é mais rápido.';

  @override
  String get lockSetupUseFingerprint => 'Usar digital';

  @override
  String get lockSetupPinOnly => 'Só o PIN';

  @override
  String get lockSetupOnceMore => 'Mais uma vez';

  @override
  String get lockSetupSetAPin => 'Novo PIN';

  @override
  String get lockSetupThoseWereDifferentFrom => 'Eram diferentes. Do começo.';

  @override
  String get lockSetupTheSameFourDigits => 'Os mesmos dígitos de novo';

  @override
  String get lockSetupFourDigitsAnythingYou =>
      'Quatro dígitos ou mais, qualquer coisa que você vá lembrar';

  @override
  String get modesOnion => 'Onion';

  @override
  String get modesFullOnionRoutingThree =>
      'Roteamento onion completo, três saltos. Uma mensagem leva de dois a cinco segundos. Ninguém vê com quem você fala.';

  @override
  String get modesSlower => 'Mais lento';

  @override
  String get modesRelay => 'Retransmissor';

  @override
  String get modesOneSealedConnectionTo =>
      'Uma conexão lacrada com o retransmissor do próprio Kryfo, como uma VPN sem nada para registrar. Os envios chegam em cerca de um segundo, e funciona onde o tor está bloqueado.';

  @override
  String get modesQuick => 'Ágil';

  @override
  String get modesRelayOnly => 'Só retransmissor';

  @override
  String get modesFast => 'Rápido';

  @override
  String get modesPlainConnectionsToEvery =>
      'Conexões simples com cada retransmissor. Quase instantâneo, e o menos privado dos três.';

  @override
  String get modesInstant => 'Instantâneo';

  @override
  String get modesEveryRelayYouUse =>
      'Cada retransmissor que você usa sabe o endereço de onde você se conecta, não só o nosso. As mensagens continuam lacradas, mas o fato de você ter enviado uma, não. Desativado por padrão, e desativado de novo depois de reinstalar.';

  @override
  String get modesSpeed => 'Velocidade';

  @override
  String get modesPrivacy => 'e privacidade';

  @override
  String get modesChangeGloballyOrPer => 'Mude para tudo ou por conversa';

  @override
  String get modesSoon => 'Em breve';

  @override
  String get modesActive => 'Ativo';

  @override
  String get modesSpeed2 => 'VELOCIDADE';

  @override
  String get modesHops => 'SALTOS';

  @override
  String get modesIp => 'IP';

  @override
  String get modesVisible => 'Visível';

  @override
  String get modesHidden => 'Oculto';

  @override
  String modesHeadsUp(Object warning) {
    return '*Atenção:* $warning';
  }

  @override
  String get modesOnionIsTheDefault =>
      'Onion é o padrão e continua assim a não ser que você mude. A troca vale a partir da próxima mensagem.';

  @override
  String get modesFastMode => 'Modo rápido';

  @override
  String get modesPlainConnectionsToEveryRelayQuicker =>
      'Conexões simples com cada retransmissor. Mais rápido, e os retransmissores podem ver seu endereço IP. As mensagens continuam criptografadas de ponta a ponta de qualquer jeito.';

  @override
  String get modesTurnOnFastMode => 'Ativar o modo rápido';

  @override
  String get modesKeepItOff => 'Deixar desativado';

  @override
  String get movedWipeThisPhone => 'Apagar o Kryfo deste celular?';

  @override
  String get movedEverythingKryfoHoldsHere =>
      'Tudo o que o Kryfo guarda aqui vai embora: as mensagens, os contatos, as chaves. O outro aparelho fica com tudo isso. Isso não pode ser desfeito.';

  @override
  String get movedWipeIt => 'Apagar';

  @override
  String get movedNotMovingAfterAll => 'Afinal, não vai mudar?';

  @override
  String get movedOnlyDoThisIf =>
      'Só faça isso se o backup nunca tiver sido importado em lugar nenhum. Se foi, agora dois aparelhos têm a mesma identidade, e as mensagens vão começar a se perder nos dois.';

  @override
  String get movedIMStayingHere => 'Vou ficar aqui';

  @override
  String get movedStayingHere => 'Ficando aqui';

  @override
  String movedKryfoWillCloseNow(Object myId) {
    return 'O Kryfo vai fechar agora. Toque no ícone para abrir de novo como $myId.';
  }

  @override
  String get movedReopenKryfo => 'Reabrir o Kryfo';

  @override
  String get movedThisKryfoHasMoved => 'Este Kryfo se mudou';

  @override
  String movedIsNowOnAnother(Object myId) {
    return '$myId agora está em outro aparelho. Este celular ainda pode mostrar o que havia aqui, mas nada novo vai chegar nele, e nada que você enviar daqui vai chegar a ninguém.';
  }

  @override
  String get movedKeepItToRead => 'Manter para leitura';

  @override
  String get movedWipeThisPhone2 => 'Apagar o Kryfo deste celular';

  @override
  String get movedIMNotMoving => 'Afinal, não vou mudar';

  @override
  String get myKryfoAHandleIs3 =>
      'Um nome de usuário tem de 3 a 20 letras, números ou _';

  @override
  String get myKryfoInviteCopiedClearsIn => 'Convite copiado · some em 60s';

  @override
  String myKryfoAddMeOnKryfo(Object myId, Object uri) {
    return 'Me adicione no Kryfo. Meu ID é $myId\n\nToque para me adicionar:\n$uri\n\nO Kryfo é um mensageiro privado. Sem número de telefone, sem e-mail.';
  }

  @override
  String get myKryfoAddMeOnKryfo2 => 'Me adicione no Kryfo';

  @override
  String get myKryfoAddSomeone => 'Adicionar alguém';

  @override
  String get myKryfoKryfoDoesnTScan =>
      'O Kryfo não lê seus contatos, e é essa a ideia.';

  @override
  String get myKryfoIfThisLinkEnds =>
      'Se este link for parar onde você não queria, redefina nas configurações. Aí todo mundo que tem o link vai precisar de um novo.';

  @override
  String get myKryfoAlreadyShareAFriend =>
      'Já têm alguém em comum no Kryfo? Essa pessoa pode apresentar vocês pela conversa dela, e vocês pulam o pedido.';

  @override
  String get myKryfoHandleCopied => 'Nome de usuário copiado';

  @override
  String get myKryfoTheyReHereWith => 'A pessoa está aqui comigo';

  @override
  String get myKryfoPointYourPhonesAt =>
      'Apontem os celulares um para o outro. Nada passa por um servidor.';

  @override
  String get myKryfoScanTheirsInstead => 'Escanear o da pessoa';

  @override
  String get myKryfoTheyReadYouA => 'A pessoa lê um código para você';

  @override
  String get myKryfoTheyReSomewhereElse => 'A pessoa está em outro lugar';

  @override
  String get myKryfoSendThemALink =>
      'Mande um link. Ele abre direto na tela de adicionar.';

  @override
  String get myKryfoYourLinkAppearsOnce =>
      'Seu link aparece depois que você se conectar';

  @override
  String get myKryfoTheLinkCarriesYour =>
      'O link leva seu ID, seu endereço e as chaves para começar uma conversa. Ele funciona até você redefini-lo nas configurações.';

  @override
  String get myKryfoSendTheLink => 'Enviar o link';

  @override
  String get myKryfoAsACard => 'Como cartão';

  @override
  String get myKryfoAnImageWithThe => 'Uma imagem com o QR';

  @override
  String get myKryfoAsAFile => 'Como arquivo';

  @override
  String get myKryfoContactFile => 'Arquivo de contato';

  @override
  String get myKryfoIKnowTheirHandle => 'Sei o nome de usuário';

  @override
  String get myKryfoTypeTheNameThey =>
      'Digite o @nome que a pessoa passou. Funciona se ela tiver reservado um.';

  @override
  String get myKryfoTheLookupAsksFor =>
      'A busca envia só esse nome e nada sobre você. Sua primeira mensagem ainda chega para a pessoa como pedido.';

  @override
  String get myKryfoLooking => 'Procurando…';

  @override
  String get myKryfoFindThem => 'Encontrar';

  @override
  String get myKryfoYourAddressAppearsOnce =>
      'Seu endereço aparece depois que você se conectar';

  @override
  String get myKryfoAPublicHandle => 'Nome de usuário público';

  @override
  String get myKryfoPutItInA =>
      'Coloque numa bio. Qualquer pessoa que souber pode encontrar você.';

  @override
  String get myKryfoANamePeopleCan =>
      'Um nome pelo qual as pessoas podem encontrar você. Desativado até você reservar um.';

  @override
  String get newGroupCouldNotCreate => 'Não deu para criar';

  @override
  String get newGroupNewGroup => 'Novo grupo';

  @override
  String get newGroupCreating => 'Criando…';

  @override
  String get newGroupCreate => 'Criar';

  @override
  String get newGroupGroupName => 'Nome do grupo';

  @override
  String get newGroupMembers => 'Membros';

  @override
  String get newGroupPickAtLeastOne => 'Escolha pelo menos um';

  @override
  String newGroupSelected(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString selecionados',
      one: '$countString selecionado',
    );
    return '$_temp0';
  }

  @override
  String get newGroupAddAtLeastOne =>
      'Adicione pelo menos um contato antes de criar um grupo.';

  @override
  String get notesDeleteThisNote => 'Excluir esta nota?';

  @override
  String get notesGoneFromThisPhone =>
      'Ela é apagada deste celular para sempre.';

  @override
  String get notesNoteToSelf => 'Notas';

  @override
  String get notesOnlyOnThisPhone => 'Só neste celular';

  @override
  String get notesAQuietPlace => 'Um lugar tranquilo';

  @override
  String get notesJotAnythingDownIt =>
      'Anote o que quiser. Fica neste celular e nunca sai dele.';

  @override
  String get notesJotSomethingDown => 'Anote alguma coisa…';

  @override
  String get onboardingPrivateByDefault => 'PRIVADO POR PADRÃO';

  @override
  String get onboardingPrivateMessaging =>
      'Mensagens privadas,\n*sem pegadinha*.';

  @override
  String get onboardingYourNameIsThree =>
      '*Seu nome são três palavras.* Sem telefone, sem e-mail, sem agenda de contatos.';

  @override
  String get onboardingNobodyGetsInUnless =>
      '*Ninguém entra se você não deixar.* Não existe busca. As pessoas são adicionadas à mão, pelos dois lados.';

  @override
  String get onboardingTheFirstConnectionTakes =>
      '*A primeira conexão leva um minuto.* O Kryfo monta uma rota privada antes de enviar. Depois fica rápido.';

  @override
  String get onboardingBegin => 'Começar';

  @override
  String get onboardingHaveABackupRestore => 'Tem um backup? Restaurar →';

  @override
  String get onboardingKryfoIsOpenSource => 'O Kryfo tem código aberto';

  @override
  String get onboardingYourKryfoId => 'SEU ID DO KRYFO';

  @override
  String get onboardingGeneratedFromAKey =>
      'Gerado a partir de uma chave que só existe neste celular. *Fácil de lembrar, único, só seu.* Ninguém mais tem um igual.';

  @override
  String get onboardingTryAnother => 'Tentar outro';

  @override
  String get onboardingUseThisName => 'Usar este nome →';

  @override
  String get onboardingThreeWords => 'Três palavras. *Só suas.*';

  @override
  String get onboardingPickA => 'Escolha um *rosto*.';

  @override
  String get onboardingDrawnOnThisPhone =>
      'Desenhado neste celular a partir de um número, nunca enviado para lugar nenhum. Mude quando quiser.';

  @override
  String get onboardingThePeopleYouMessage =>
      'As pessoas com quem você conversa também veem isso';

  @override
  String get onboardingKeepMyInitial => 'Manter minha inicial';

  @override
  String get onboardingThatOne => 'Esse →';

  @override
  String get onboardingContinue => 'Continuar →';

  @override
  String get onboardingHowYourMessages => 'Como suas mensagens *viajam*.';

  @override
  String get onboardingYouCanChangeThis =>
      'Você pode mudar isso quando quiser nas configurações, para todos ou para uma conversa.';

  @override
  String get onboardingOnion => 'Onion';

  @override
  String get onboardingSlowerAMessageTakes =>
      'Mais lento. Uma mensagem leva de dois a cinco segundos.';

  @override
  String get onboardingHidesYourAddressFrom =>
      'Esconde seu endereço de todo mundo, inclusive do nosso retransmissor.';

  @override
  String get onboardingRelay => 'Retransmissor';

  @override
  String get onboardingOurRelaySeesYour =>
      'Nosso retransmissor vê seu endereço. Mais ninguém vê.';

  @override
  String get onboardingAboutASecondWorks =>
      'Cerca de um segundo. Funciona onde o tor está bloqueado.';

  @override
  String get onboardingFast => 'Rápido';

  @override
  String get onboardingEveryRelayYouUse =>
      'Cada retransmissor que você usa vê seu endereço. O menos privado dos três.';

  @override
  String get onboardingNearInstant => 'Quase instantâneo.';

  @override
  String get onboardingKeepOnion => 'Manter onion →';

  @override
  String get onboardingUseThis => 'Usar este →';

  @override
  String get onboardingSkipOnionIsA => 'Pular · onion é um bom padrão';

  @override
  String get onboardingThreeThingsThen => 'Três coisas,\ne *você entra*.';

  @override
  String get onboardingEverythingElseTheApp =>
      'Todo o resto o app conta quando for importante.';

  @override
  String get onboardingYourNameIsThreeWords => 'Seu nome são três palavras';

  @override
  String get onboardingThatIsTheWhole =>
      'Essa é a identidade inteira. Nenhum número para vazar, nenhum e-mail para ser alvo de phishing, nada para pesquisar. As pessoas com quem você fala veem essas palavras e o rosto que você escolheu.';

  @override
  String get onboardingNobodyCanReachYou =>
      'Ninguém consegue falar com você até você deixar';

  @override
  String get onboardingAStrangerWithYour =>
      'Alguém que você não conhece e tem as suas palavras só pode bater na porta. A primeira mensagem dessa pessoa espera nos pedidos até você dizer sim, e você pode dizer não sem ela jamais ficar sabendo.';

  @override
  String get onboardingTheFirstConnectionTakesAMinute =>
      'A primeira conexão leva um minuto';

  @override
  String get onboardingKryfoBuildsAPrivateRouteBefore =>
      'O Kryfo monta uma rota privada antes de enviar qualquer coisa. Enquanto você estiver offline, as mensagens esperam e chegam quando você voltar.';

  @override
  String get onboardingYourIdentityLivesOn =>
      'Sua identidade mora neste celular. Faça um backup nas configurações quando quiser.';

  @override
  String get onboardingIUnderstand => 'Entendi →';

  @override
  String get onboardingOneQuiet => 'Uma *notificação* discreta.';

  @override
  String get onboardingAndroidNeedsAVisible =>
      'O Android exige uma notificação visível enquanto um app escuta em segundo plano. É assim que as mensagens chegam quando o Kryfo está fechado.';

  @override
  String get onboardingSilentAndAtThe =>
      'Silenciosa, e lá embaixo nas notificações';

  @override
  String get onboardingItNeverBuzzesTurn =>
      'Ela nunca vibra. Se você desativar, as mensagens esperam até você abrir o app de novo.';

  @override
  String get onboardingGotIt => 'Entendi →';

  @override
  String get onboardingNow => 'Agora, *adicione alguém*.';

  @override
  String get onboardingTheAppIsReady =>
      'O app está pronto. Ninguém pode mandar mensagem para você até você adicionar a pessoa ou deixá-la entrar.';

  @override
  String get onboardingEveryWayToAdd => 'Todas as formas de adicionar';

  @override
  String get onboardingShowYourCodeSend =>
      'Mostre seu código, envie um link ou digite o @nome de usuário que a pessoa passou.';

  @override
  String get onboardingScanTheirs => 'Escanear código';

  @override
  String get onboardingPointTheCameraAt =>
      'Aponte a câmera para o código da pessoa';

  @override
  String get onboardingTheAppIsReadyWhenYou =>
      'O app está pronto quando você estiver.';

  @override
  String get onboardingNotNowAddPeople =>
      'Agora não · adicionar pessoas depois';

  @override
  String get openLockedOpened => 'Aberto';

  @override
  String get openLockedOpenALockedFile => 'Abrir um arquivo trancado';

  @override
  String get openLockedCheckingThePassword => 'Verificando a senha';

  @override
  String get openLockedOpening => 'Abrindo';

  @override
  String get openLockedFile => 'Arquivo';

  @override
  String get openLockedOpenFile => 'Abrir arquivo';

  @override
  String get openLockedTypeThePassword => 'Digite a senha.';

  @override
  String get openLockedItOpensOnThis => 'Ele abre neste celular.';

  @override
  String get openLockedLockedFile => 'Arquivo trancado';

  @override
  String openLockedFromFiles(Object prettySize) {
    return '$prettySize · de Arquivos';
  }

  @override
  String get openLockedFromFiles2 => 'De Arquivos';

  @override
  String get openLockedPassword => 'Senha';

  @override
  String get openLockedThePasswordIsChecked =>
      'A senha é verificada primeiro. Só depois o Kryfo pergunta onde colocar o arquivo aberto, e ele vai direto para lá.';

  @override
  String get openLockedOpened2 => 'Aberto.';

  @override
  String get openLockedSavedWhereYouChose => 'Salvo onde você escolheu.';

  @override
  String get pairCodePairingCode => 'Código de pareamento';

  @override
  String get pairCodeShowACode => 'Mostrar um código';

  @override
  String get pairCodeEnterOne => 'Digitar um';

  @override
  String get pairCodeSixDigits => 'Seis dígitos';

  @override
  String get pairCodeLooking => 'Procurando…';

  @override
  String get pairCodeNothingThereYetTrying => 'Nada ainda · tentando de novo';

  @override
  String get pairCodeNothingAtThatCode =>
      'Nada nesse código. Ele pode ter sumido, ou a pessoa ainda não compartilhou.';

  @override
  String get pairCodeUnreached =>
      'Não foi possível falar com os retransmissores. Tente de novo em instantes.';

  @override
  String get pairCodeFailed => 'Não deu certo. Tente de novo.';

  @override
  String get pairCodeTypeTheSixDigits =>
      'Digite os seis dígitos que a pessoa leu.';

  @override
  String get pairCodeAddThem => 'Adicionar';

  @override
  String get pairCodeUsedTwice =>
      'Este código foi usado duas vezes. Peça um novo.';

  @override
  String get pairCodeIsThisThem => 'É essa pessoa?';

  @override
  String get pairCodeCheckMatches => 'Confira se bate com a tela da pessoa';

  @override
  String get pairCodeNotThem => 'Não é essa pessoa';

  @override
  String get pairCodeNotAdded => 'Nada foi adicionado. Peça um código novo.';

  @override
  String get panicSetupThoseWereDifferentFrom => 'Eram diferentes. Do começo.';

  @override
  String get panicSetupOnceMore => 'Mais uma vez';

  @override
  String get panicSetupTheSameFourDigits => 'Os mesmos dígitos de novo';

  @override
  String get photoKnowsEverythingInside => 'Tudo o que tem dentro';

  @override
  String get photoKnowsVideo => 'Vídeo';

  @override
  String get photoKnowsPhoto => 'Foto';

  @override
  String get photoKnowsWhatThisVideoKnows => 'O que este vídeo sabe';

  @override
  String get photoKnowsWhatThisPhotoKnows => 'O que esta foto sabe';

  @override
  String get photoKnowsRemoveAllOfIt => 'Remover tudo';

  @override
  String get photoKnowsKeepItAsIt => 'Deixar como está';

  @override
  String get photoKnowsReadOnThisPhone =>
      'LIDO NESTE CELULAR · O VÍDEO NÃO FOI PARA LUGAR NENHUM';

  @override
  String get photoKnowsReadOnThisPhoneThePhoto =>
      'LIDO NESTE CELULAR · A FOTO NÃO FOI PARA LUGAR NENHUM';

  @override
  String get photoKnowsReadingTheFile => 'Lendo o arquivo';

  @override
  String photoKnowsOf(Object prettySize, Object prettySize2) {
    return '$prettySize de $prettySize2';
  }

  @override
  String get photoKnowsEverythingStaysOnThis => 'Tudo fica neste celular.';

  @override
  String photoKnowsMapWithAPin(Object place) {
    return 'Mapa com um marcador. $place';
  }

  @override
  String get photoKnowsDrawnOffline => 'DESENHADO OFFLINE';

  @override
  String photoKnowsShowEverything(Object title) {
    return '$title. Mostrar tudo';
  }

  @override
  String get pinsAppLock => 'Bloqueio do app';

  @override
  String get pinsYourPin => 'Seu PIN';

  @override
  String get commonOn => 'Ativado';

  @override
  String get commonOff => 'Desativado';

  @override
  String get pinsOpensKryfoFourDigits =>
      'Abre o Kryfo. Pedido quando o app volta para a tela.';

  @override
  String get pinsChangePin => 'Mudar PIN';

  @override
  String get pinsSetAPin => 'Novo PIN';

  @override
  String get pinsTurnOff => 'Desativar';

  @override
  String get pinsTurnOffTheApp => 'Desativar o bloqueio do app?';

  @override
  String get pinsThePinGoesAnd =>
      'O PIN sai, e junto com ele o PIN de apagamento e qualquer conversa oculta. Qualquer pessoa com seu celular abre o Kryfo como se fosse você.';

  @override
  String get pinsUnlockWithFingerprint => 'Desbloquear com a digital';

  @override
  String get pinsWipePin => 'PIN de apagamento';

  @override
  String get pinsNeedsAPinFirst => 'Precisa de um PIN';

  @override
  String get pinsSet => 'Definido';

  @override
  String get pinsChangeWipePin => 'Mudar PIN de apagamento';

  @override
  String get pinsSetAWipePin => 'Novo PIN de apagamento';

  @override
  String get pinsRemove => 'Remover';

  @override
  String get pinsRemoveTheWipePin => 'Remover o PIN de apagamento?';

  @override
  String get pinsTheLockScreenKeeps =>
      'A tela de bloqueio mantém seu PIN. O PIN de apagamento deixa de funcionar.';

  @override
  String profileCopied(Object what) {
    return '$what copiado';
  }

  @override
  String get profileProfile => 'Perfil';

  @override
  String get profileChangeYourFace => 'Mudar seu rosto';

  @override
  String get profileKryfoId => 'Id do Kryfo';

  @override
  String get profileOnionAddress => 'Endereço onion';

  @override
  String get profileSupporterBadge => 'Selo de apoiador';

  @override
  String profileYouAreAThank(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'supporter': 'Você é apoiador. Obrigado.',
      'patron': 'Você é mecenas. Obrigado.',
      'guardian': 'Você é guardião. Obrigado.',
      'other': 'Você é apoiador. Obrigado.',
    });
    return '$_temp0';
  }

  @override
  String get profileShowMyBadge => 'Mostrar meu selo';

  @override
  String get profileOnMyOwnScreens => 'Nas minhas próprias telas';

  @override
  String get profileLetContactsSeeIt => 'Deixar os contatos verem';

  @override
  String get profileOffByDefault => 'Desativado por padrão';

  @override
  String get profileShareConnect => 'Compartilhar e conectar';

  @override
  String get profileMyKryfoCode => 'Meu código do Kryfo';

  @override
  String get profileAddContact => 'Adicionar contato';

  @override
  String get profileGiveAgain => 'Doar de novo';

  @override
  String get profileSupportKryfo => 'Apoiar o Kryfo';

  @override
  String get profileKryfoRunsOnWhat => 'O Kryfo vive do que as pessoas doam';

  @override
  String get profileKeepKryfoIndependent => 'Mantenha o Kryfo independente';

  @override
  String get qrLink => 'Link';

  @override
  String get qrYourLinkAsTyped =>
      'SEU LINK COMO FOI DIGITADO · SEM REDIRECIONAMENTO DE RASTREIO';

  @override
  String get qrText => 'Texto';

  @override
  String get qrStaysInTheCode => 'FICA NO CÓDIGO · NENHUM SERVIDOR GUARDA';

  @override
  String get qrWiFi => 'Wi-Fi';

  @override
  String get qrMadeOnThisPhone =>
      'FEITO NESTE CELULAR · NENHUM SITE VIU A SENHA';

  @override
  String get qrNetworkName => 'Nome da rede';

  @override
  String get qrPassword => 'Senha';

  @override
  String get qrContact => 'Contato';

  @override
  String get qrOnlyWhatYouType =>
      'SÓ O QUE VOCÊ DIGITAR · NADA DOS SEUS CONTATOS';

  @override
  String get qrName => 'Nome';

  @override
  String get qrPhone => 'Telefone';

  @override
  String get qrEmail => 'E-mail';

  @override
  String get qrOpensTheirMailApp =>
      'ABRE O APP DE E-MAIL DA PESSOA · NADA É ENVIADO DAQUI';

  @override
  String get qrTo => 'Para';

  @override
  String get qrSubject => 'Assunto';

  @override
  String get qrANumberNothingElse => 'UM NÚMERO · MAIS NADA';

  @override
  String get qrNumber => 'Número';

  @override
  String get qrSms => 'SMS';

  @override
  String get qrOpensTheirMessagesApp =>
      'ABRE O APP DE MENSAGENS DA PESSOA · NADA É ENVIADO DAQUI';

  @override
  String get qrMessage => 'Mensagem';

  @override
  String get qrLocation => 'Localização';

  @override
  String get qrCoordinatesOnlyNoMap =>
      'SÓ COORDENADAS · NENHUM SERVIÇO DE MAPA CONSULTADO';

  @override
  String get qrLatitude => 'Latitude';

  @override
  String get qrLongitude => 'Longitude';

  @override
  String get qrBitcoin => 'Bitcoin';

  @override
  String get qrAddressAndAmountNo =>
      'ENDEREÇO E VALOR · NENHUM SITE DE PAGAMENTO NO MEIO';

  @override
  String get qrAddress => 'Endereço';

  @override
  String get qrAmountInBtc => 'Valor em BTC';

  @override
  String get qrInk => 'Tinta';

  @override
  String get qrAmber => 'Âmbar';

  @override
  String get qrViolet => 'Violeta';

  @override
  String get qrCouldNotDrawThe => 'Não foi possível desenhar a imagem.';

  @override
  String get qrSavedToYourGallery => 'Salvo na sua galeria';

  @override
  String get qrCouldNotSaveIt =>
      'Não foi possível salvar. Veja se o celular tem espaço.';

  @override
  String get qrNoAppOnThis => 'Nenhum app neste celular aceitou a imagem.';

  @override
  String get qrTooMuchForOne => 'Demais para um código só. Encurte.';

  @override
  String get qrThisIsALot =>
      'Isso é muito para um código só. Câmeras mais antigas podem não ler.';

  @override
  String get qrPrivateQrCode => 'Código QR privado';

  @override
  String get qrColour => 'Cor';

  @override
  String get qrCopiedItLeavesThe =>
      'Copiado. Sai da área de transferência em um minuto';

  @override
  String get qrSecurity => 'Segurança';

  @override
  String get qrNone => 'Nenhuma';

  @override
  String get qrSaveImage => 'Salvar imagem';

  @override
  String qrColour2(Object name) {
    return 'Cor $name';
  }

  @override
  String get qrTypeBelowAndThe =>
      'Digite abaixo e o\ncódigo se desenha sozinho';

  @override
  String get qrQrCode => 'Código QR';

  @override
  String get qrHidePassword => 'Ocultar senha';

  @override
  String get qrShowPassword => 'Mostrar senha';

  @override
  String get qrCopyPassword => 'Copiar senha';

  @override
  String get requestsSentAnAttachment => 'Enviou um anexo';

  @override
  String get requestsWantsToConnect => 'Quer se conectar';

  @override
  String get requestsAccepted => 'Aceito';

  @override
  String requestsBlock(Object id) {
    return 'Bloquear $id?';
  }

  @override
  String get requestsNothingMoreFromThem =>
      'Nada mais dessa pessoa chega até você. O pedido e as mensagens dela são excluídos.';

  @override
  String get requestsBlocked => 'Bloqueado';

  @override
  String get requestsDeleted => 'Excluído';

  @override
  String get requestsRequests => 'Pedidos';

  @override
  String get requestsNoRequests => 'Nenhum pedido';

  @override
  String get requestsMessagesFromPeopleYou =>
      'Mensagens de pessoas que você não adicionou aparecem aqui primeiro.';

  @override
  String get requestsLooksSafeNothingSuspicious =>
      'Parece seguro · nada suspeito na primeira mensagem';

  @override
  String get commonAccept => 'Aceitar';

  @override
  String get requestsDecline => 'Recusar';

  @override
  String get restoreThatFileIsNot => 'Esse arquivo não é um backup do Kryfo';

  @override
  String get restoreThisFileIsDamaged =>
      'Este arquivo está danificado e não pode ser lido';

  @override
  String get restoreTypeThePassphraseThe =>
      'Digite a frase-senha usada para criar o arquivo';

  @override
  String get restoreReplaceTheAccountOn => 'Substituir a conta deste celular?';

  @override
  String get restoreWhatIsHereNow =>
      'O que está aqui agora, com a identidade, os contatos e as mensagens, vai embora. O arquivo toma o lugar. Isso não pode ser desfeito.';

  @override
  String get restoreReplaceIt => 'Substituir';

  @override
  String restoreCouldNotBeReleased(Object mine) {
    return 'Não foi possível liberar @$mine';
  }

  @override
  String restoreTheRegistryDidNot(Object mine) {
    return 'O registro não respondeu. Se você continuar, @$mine vai continuar apontando para a identidade que este celular está prestes a perder. Quem adicionar esse nome vai escrever para ninguém, e o nome não pode ser reservado de novo. Melhor ficar online e tentar mais uma vez.';
  }

  @override
  String get restoreRestoreAnyway => 'Restaurar mesmo assim';

  @override
  String get restoreNotYet => 'Ainda não';

  @override
  String get restoreRestored => 'Restaurado';

  @override
  String restoreKryfoWillCloseNow(Object haloId) {
    return 'O Kryfo vai fechar agora. Toque no ícone para abrir de novo como $haloId.';
  }

  @override
  String get restoreReopenKryfo => 'Reabrir o Kryfo';

  @override
  String get restoreTheRestoreDidNot =>
      'A restauração não terminou. Nada foi alterado';

  @override
  String get restoreKryfoClosesRestoreAgain =>
      'Parte do que havia aqui já foi substituída. O Kryfo vai fechar agora. Abra de novo e restaure o arquivo mais uma vez.';

  @override
  String get restoreThisIdentity => 'esta identidade';

  @override
  String get restoreMoveYourKryfoHere => 'Traga seu Kryfo para cá';

  @override
  String restoreThisBackupIsRestoring(Object name) {
    return 'Este backup é $name. Restaurar move essa identidade para este aparelho.';
  }

  @override
  String restoreThisBackupMadeOn(Object name, Object date, Object time) {
    return 'Este backup é $name, feito em $date às $time. Restaurar move essa identidade para este aparelho.';
  }

  @override
  String restoreItHoldsOfPhotos(Object mb) {
    return 'Ele tem $mb de fotos, áudios e arquivos. Isso pode levar alguns minutos. Mantenha o app aberto.';
  }

  @override
  String get restoreWhatFollows => 'O que vem junto';

  @override
  String get restoreYourNameYourCode =>
      'Seu nome, seu código e todos os contatos.';

  @override
  String get restoreEveryConversationBackTo =>
      'Todas as conversas, desde o começo.';

  @override
  String get restoreYourPhotosVoiceNotes => 'Suas fotos, áudios e arquivos.';

  @override
  String restoreYourPhotosVoiceNotesCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Suas fotos, áudios e arquivos · $countString.',
    );
    return '$_temp0';
  }

  @override
  String get restoreYourOnionAddressSo =>
      'Seu endereço onion, para que quem chega até você diretamente continue chegando.';

  @override
  String get restoreAnythingSentToYou =>
      'Tudo o que foi enviado para você enquanto o celular antigo estava desligado, por até catorze dias depois do envio.';

  @override
  String get restoreYourSupporterBadgeIf =>
      'Seu selo de apoiador, se você tiver um.';

  @override
  String get restoreWhatDoesnT => 'O que não vem';

  @override
  String get restoreTheOldPhoneStops =>
      'O celular antigo para de receber no momento em que você envia qualquer coisa daqui. Não aos poucos. A primeira mensagem que você enviar deste aparelho é a última que o celular antigo consegue acompanhar, e o que chegar nele depois disso fica ilegível lá e também não fica esperando por você aqui.';

  @override
  String get restoreIfThePhoneThis =>
      'Se o celular de onde veio este arquivo ainda estiver em uso, pare de usar o Kryfo nele antes de continuar. Dois celulares com o mesmo Kryfo perdem mensagens nos dois.';

  @override
  String get restoreNotificationsNeedSettingUp =>
      'As notificações precisam ser configuradas de novo neste aparelho.';

  @override
  String get restoreMoveItHere => 'Trazer para cá';

  @override
  String get restoreNotNow => 'Agora não';

  @override
  String get restoreRestore => 'Restaurar';

  @override
  String get restoreFromABackupFile => 'De um arquivo de backup';

  @override
  String get restoreABackupBringsBack =>
      'Um backup traz de volta sua identidade e seus contatos, e as mensagens que estavam no celular quando o arquivo foi criado. Nada do que foi dito depois está nele.';

  @override
  String get restoreTheFile => 'O arquivo';

  @override
  String get restorePickTheBackupFile => 'Escolha o arquivo de backup';

  @override
  String get restoreThePassphrase => 'A frase-senha';

  @override
  String get restoreTheOneTheFile => 'A que foi usada para criar o arquivo';

  @override
  String get restoreWhatComesBack => 'O que volta';

  @override
  String get restoreChecking => 'Verificando…';

  @override
  String get restoreCheckTheFile => 'Verificar o arquivo';

  @override
  String get restoreReleasingYourHandle => 'Liberando seu nome de usuário…';

  @override
  String restoreMoving(Object progress) {
    return 'Mudando… $progress';
  }

  @override
  String get restoreRestoring => 'Restaurando…';

  @override
  String get restoreNotThisOne => 'Não é este';

  @override
  String get restoreDateUnknown => 'Data desconhecida';

  @override
  String get restoreAnIdentity => 'Uma identidade';

  @override
  String get restoreMessagesSentOrReceived =>
      'Mensagens enviadas ou recebidas depois dessa data não estão neste arquivo.';

  @override
  String restoreGb(Object bytes) {
    return '$bytes GB';
  }

  @override
  String restoreMb(Object bytes) {
    return '$bytes MB';
  }

  @override
  String get roomCreateCouldNotCreateThe => 'Não foi possível criar a sala';

  @override
  String get roomCreateBurnerRoom => 'Sala temporária';

  @override
  String get roomCreateARoomThatEnds =>
      'Uma sala que acaba. Todo mundo entra com uma chave feita para ela, e quando ela acaba não sobra nada em nenhum celular.';

  @override
  String get roomCreateRoomName => 'Nome da sala';

  @override
  String get roomCreateEndsAfter => 'Acaba depois de';

  @override
  String get roomCreateMemberCap => 'Limite de membros';

  @override
  String roomCreateNoOnePastThe(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ninguém além de $countString pessoas',
      one: 'Ninguém além de $countString pessoa',
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
      other: 'Desligado. Qualquer pessoa com o link, até $countString',
    );
    return '$_temp0';
  }

  @override
  String roomCreateThisRoomAndEverything(Object expiryWords) {
    return 'Esta sala e tudo o que há nela somem em $expiryWords';
  }

  @override
  String get roomCreateCreating => 'Criando...';

  @override
  String get roomCreateCreateRoom => 'Criar sala';

  @override
  String get roomLinkSendTheRoomTo => 'Enviar a sala para';

  @override
  String get roomLinkTheyWillKnowThis =>
      'A pessoa vai saber que esta sala veio de você. Lá dentro, ela é uma chave como todo mundo.';

  @override
  String get roomLinkNoContactsYet => 'Nenhum contato ainda';

  @override
  String roomLinkEndsIn(Object time) {
    return 'Acaba em $time';
  }

  @override
  String get roomLinkAnyoneWithThisCan =>
      'Qualquer pessoa com isto pode entrar até a sala acabar. Ela entra com uma chave feita para esta sala e não vê nada do que foi enviado antes de chegar.';

  @override
  String get roomLinkRoomLinkCopied => 'Link da sala copiado';

  @override
  String get roomLinkSendToAContact => 'Enviar para um contato';

  @override
  String get roomLinkCopyRoomLink => 'Copiar link da sala';

  @override
  String get savedVoiceNote => 'Áudio';

  @override
  String get savedPhoto => 'Foto';

  @override
  String get savedSaved => 'Salvos';

  @override
  String get savedNothingSavedYet => 'Nada salvo ainda';

  @override
  String get savedChatGone => 'Essa conversa não está mais neste celular';

  @override
  String get savedLongPressAnyMessage =>
      'Toque e segure qualquer mensagem e toque em salvar para guardá-la aqui.';

  @override
  String get savedViewInChat => 'Ver na conversa';

  @override
  String get savedPhoto2 => 'Foto';

  @override
  String get scanThatSNotA => 'Isso não é um QR do Kryfo · continue apontando';

  @override
  String get scanScanAKryfoQr => 'Escaneie um QR do Kryfo';

  @override
  String get scanFlash => 'Lanterna';

  @override
  String get scanPointAtAKryfo =>
      'Aponte para um QR do Kryfo · nada sai do seu celular';

  @override
  String get seenWhatWeCanSee => 'O que conseguimos ver';

  @override
  String get seenEveryMessengerClaimsPrivacy =>
      'Todo mensageiro diz que é privado. Esta é a lista específica, por rota, incluindo as partes que não nos favorecem. Toque numa linha para ver o porquê.';

  @override
  String get seenHonestAboutTheLast =>
      'Sendo honestos sobre as últimas linhas: é para isso que servem o bloqueio do app, o PIN de apagamento e o armazenamento criptografado, e nenhuma ferramenta protege você de alguém segurando seu celular desbloqueado. O modelo de ameaças completo está em THREAT_MODEL.md no repositório, escrito com base no LINDDUN. O código é aberto, então nada disso precisa ser aceito na base da confiança.';

  @override
  String get seenHidden => 'Oculto';

  @override
  String get seenNever => 'Nunca';

  @override
  String get seenOnDevice => 'No aparelho';

  @override
  String get seenYours => 'Seu';

  @override
  String get seenUnaudited => 'Sem auditoria';

  @override
  String get seenWhoYouTalkTo => 'Com quem você fala';

  @override
  String get seenEachConversationGetsIts =>
      'Cada conversa ganha seu próprio endereço, derivado das duas chaves. Um retransmissor vê caixas de depósito sem relação entre si, não um par de pessoas.';

  @override
  String get seenWhatYouSay => 'O que você diz';

  @override
  String get seenEndToEndEncrypted =>
      'Criptografado de ponta a ponta com o double ratchet do Signal, e depois lacrado de novo dentro de um embrulho (gift wrap). Não conseguiríamos ler nem se tentássemos.';

  @override
  String get seenYourIpAddress => 'Seu endereço IP';

  @override
  String get seenOurRelay => 'Nosso retransm.';

  @override
  String get seenEveryRelay => 'Todo retransm.';

  @override
  String get seenOnOnionEverythingLeaves =>
      'No onion, tudo sai pelo tor e o retransmissor vê um nó de saída, nunca você. No modo retransmissor, a conexão vai direto para o nosso retransmissor: nada repassa seu endereço e nada fica registrado, mas essa conexão nós conseguimos ver. No rápido, todo retransmissor público fica sabendo que você se conectou, mas não com quem nem o que você disse.';

  @override
  String get seenYourContactGraph => 'Sua rede de contatos';

  @override
  String get seenKryfoDoesNotScan =>
      'O Kryfo não lê seus contatos. É essa a ideia. Aqui não existe número de telefone para vazar.';

  @override
  String get seenIntroducer => 'Quem apresenta';

  @override
  String get seenWhenAContactIntroduces =>
      'Quando um contato apresenta você a alguém, esse contato fica sabendo que vocês dois agora estão conectados. Mais ninguém fica. O retransmissor vê texto cifrado, e nenhum servidor jamais vê a rede de contatos.';

  @override
  String get seenTheScamShield => 'O escudo antigolpe';

  @override
  String get seenRunsOnYourPhone =>
      'Roda no seu celular com regras que vêm no app. Sem rede, sem baixar listas. Ele só lê a primeira mensagem de alguém desconhecido e não consegue ver nada que um contato manda para você.';

  @override
  String get seenBurnerRooms => 'Salas temporárias';

  @override
  String get seenRoomKeys => 'Chaves de sala';

  @override
  String get seenYouJoinARoom =>
      'Você entra numa sala com uma chave feita para ela, então as pessoas lá dentro não ficam sabendo de nada que sirva em outro lugar. Quem entra depois não recebe histórico. Quando a sala expira, as chaves, as mensagens e a mídia são destruídas.';

  @override
  String get seenLinkPreviews => 'Prévias de link';

  @override
  String get seenOverTor => 'Pelo Tor';

  @override
  String get seenAPreviewIsFetched =>
      'A prévia é buscada por quem envia, pelo tor, e viaja dentro da mensagem criptografada. O celular que recebe não faz nenhuma solicitação. O site fica sabendo que alguém usando tor pediu uma página, e mais nada. Nenhuma imagem é carregada, nunca, e o link de um desconhecido continua como texto simples.';

  @override
  String get seenASeizedUnlockedPhone => 'Um celular desbloqueado apreendido';

  @override
  String get seenIfSomeoneHoldsYour =>
      'Se alguém está com seu celular aberto, essa pessoa lê suas mensagens. O bloqueio do app, o PIN de apagamento e o armazenamento criptografado ajudam antes disso, não depois.';

  @override
  String get seenTheCryptoItself => 'A criptografia em si';

  @override
  String get seenTheRatchetAndStorage =>
      'As camadas do ratchet e do armazenamento são padrão. A camada que junta as duas é nossa, e ninguém independente a revisou. Trate isto como alfa, porque é.';

  @override
  String get seenOnion => 'Onion';

  @override
  String get seenRelay => 'Retransm.';

  @override
  String get seenFast => 'Rápido';

  @override
  String get settingsWipeKryfo => 'Apagar o Kryfo?';

  @override
  String get settingsIdentityMessagesContactsAnd =>
      'Identidade, mensagens, contatos e configurações deste celular. Somem para sempre, a não ser que você tenha um backup.';

  @override
  String get commonContinue => 'Continuar';

  @override
  String settingsTypeWipeToConfirm(Object word) {
    return 'Digite “$word” para confirmar';
  }

  @override
  String get settingsTheLastStepNothing =>
      'O último passo. Nada sobrevive a ele.';

  @override
  String get settingsWipeWord => 'apagar';

  @override
  String get settingsWipeKryfo2 => 'Apagar o Kryfo';

  @override
  String get settingsYourProtections => 'Suas proteções';

  @override
  String get settingsTorRouting => 'Roteamento pelo tor';

  @override
  String get settingsConnecting => 'Conectando';

  @override
  String get settingsOffMode => 'Desligado · retransmissor';

  @override
  String get settingsOffFastMode => 'Desligado · modo rápido';

  @override
  String get settingsAppLock => 'Bloqueio do app';

  @override
  String get settingsBlockedByAndroid => 'Bloqueadas pelo Android';

  @override
  String get settingsSpeedPrivacy => 'Velocidade e privacidade';

  @override
  String get settingsFast => 'Rápido';

  @override
  String get settingsRelay1Hop => 'Retransmissor · 1 salto';

  @override
  String get settingsOnion3Hops => 'Onion · 3 saltos';

  @override
  String get settingsBridges => 'Pontes';

  @override
  String get settingsForNetworksThatBlock => 'Para redes que bloqueiam o tor';

  @override
  String get settingsGettingMessages => 'Receber mensagens';

  @override
  String settingsPreviewHidden(Object deliveryModeName) {
    return '$deliveryModeName · prévia oculta';
  }

  @override
  String settingsPreviewShown(Object deliveryModeName) {
    return '$deliveryModeName · prévia visível';
  }

  @override
  String get settingsRunInBackground => 'Rodar em segundo plano';

  @override
  String get settingsSoMessagesArrive => 'Para as mensagens chegarem';

  @override
  String get settingsTransport => 'Transporte';

  @override
  String get settingsWhatTheNetworkIs => 'O que a rede está fazendo';

  @override
  String get settingsBlocked => 'Bloqueados';

  @override
  String get settingsAcceptIntroductions => 'Aceitar apresentações';

  @override
  String get settingsFriendsCanIntroduceYou =>
      'Amigos podem apresentar você aos amigos deles';

  @override
  String get settingsScamShield => 'Escudo antigolpe';

  @override
  String get settingsChecksStrangersOnYour =>
      'Verifica desconhecidos no seu celular. Nada sai dele';

  @override
  String get settingsBlockScreenshots => 'Bloquear capturas de tela';

  @override
  String get settingsWholeAppHiddenFrom =>
      'App inteiro oculto dos recentes e das capturas de tela · vale depois de reiniciar';

  @override
  String get settingsWholeAppHiddenFromRecentsAnd =>
      'App inteiro oculto dos recentes e das capturas de tela';

  @override
  String get settingsOnNextStart => 'Ativado · ao reiniciar';

  @override
  String get settingsOffNextStart => 'Desativado · ao reiniciar';

  @override
  String get settingsLightTheme => 'Tema claro';

  @override
  String get settingsSameProtectionBrighter => 'Mesma proteção, mais claro';

  @override
  String get settingsAppLock2 => 'Bloqueio do app';

  @override
  String get settingsYourPinAndA => 'Seu PIN e proteção avançada';

  @override
  String get settingsPinWipePin => 'PIN · PIN de apagamento';

  @override
  String get settingsBackUpIdentity => 'Backup da identidade';

  @override
  String get settingsEncryptedFile => 'Arquivo criptografado';

  @override
  String get settingsRestoreFromBackup => 'Restaurar de um backup';

  @override
  String get settingsReplaceCurrent => 'Substitui a atual';

  @override
  String get settingsDisguiseVoice => 'Disfarçar a voz';

  @override
  String get settingsShiftsYourPitchBefore =>
      'Muda o tom da sua voz antes de um áudio sair';

  @override
  String get settingsWhyKryfo => 'Por que o Kryfo';

  @override
  String get settingsHowItProtectsYou => 'Como ele protege você';

  @override
  String get settingsResetMyInviteLink => 'Redefinir meu link de convite';

  @override
  String get settingsOldLinksAndCodes =>
      'Links e códigos antigos param de funcionar, para todos';

  @override
  String get settingsResetInviteLink => 'Redefinir o link de convite?';

  @override
  String get settingsAnyoneWithAnOld =>
      'Quem tiver um código ou link antigo deixa de conseguir falar com você, por qualquer rota. Quem tem mas nunca usou vai precisar de um novo seu. Contatos, conversas e histórico continuam.';

  @override
  String get settingsReset => 'Redefinir';

  @override
  String get settingsInviteResetShareThe =>
      'Convite redefinido · compartilhe o novo código';

  @override
  String get settingsWhatWeCanSee => 'O que conseguimos ver';

  @override
  String get settingsTheHonestList => 'A lista honesta';

  @override
  String get settingsVersion => 'Versão';

  @override
  String get settings030Alpha => '0.5.0 · alfa';

  @override
  String get settingsReportAnIssue => 'Relatar um problema';

  @override
  String get settingsBugOrSecurityFlaw => 'Bug ou falha de segurança';

  @override
  String get settingsOpenSource => 'Código aberto';

  @override
  String get settingsLinkCopied => 'Link copiado';

  @override
  String get settingsTheOfflineMapIn =>
      'O mapa offline em Ferramentas é desenhado a partir do Natural Earth (domínio público). Os nomes das cidades vêm do GeoNames, geonames.org, sob CC BY 4.0.';

  @override
  String get settingsNotIndependentlyAuditedPre =>
      'Sem auditoria independente. Alfa: bom para testes, ainda não para uso de alto risco.';

  @override
  String get settingsDangerZone => 'Zona de perigo';

  @override
  String get settingsWipeKryfoFromThis => 'Apagar o Kryfo deste celular';

  @override
  String get shieldCheckedOnThisPhone =>
      'Verificado neste celular. Nada foi enviado para lugar nenhum.';

  @override
  String get toolsMoreTools => 'Mais ferramentas';

  @override
  String get toolsCleanAPhotoOr => 'Limpar uma foto ou vídeo';

  @override
  String get toolsOrShareOneTo => 'Ou compartilhe uma com o Kryfo pela galeria';

  @override
  String get toolsMakeAPrivateQr => 'Criar um código QR privado';

  @override
  String get toolsLinksWiFiContacts =>
      'Links, Wi-Fi, contatos e mais. Feito offline';

  @override
  String get toolsLockAFile => 'Trancar um arquivo';

  @override
  String get toolsWithAPasswordOpens =>
      'Com senha. Abre em qualquer lugar com age';

  @override
  String get toolsOpenALockedFile => 'Abrir um arquivo trancado';

  @override
  String get toolsAnyAgeFileSomeone =>
      'Qualquer arquivo .age que alguém enviou para você';

  @override
  String get toolsWorksOfflineNoContacts =>
      'Funciona offline · não precisa de contatos';

  @override
  String get toolsUsefulFrom => 'Útil desde';

  @override
  String get toolsTheFirstMinute => 'o primeiro minuto.';

  @override
  String get toolsEverythingHereHappensOn =>
      'Tudo aqui acontece neste celular. Nada é enviado, e ninguém mais precisa estar no Kryfo.';

  @override
  String get toolsWhatDoesThisPhoto => 'O que esta foto sabe?';

  @override
  String get toolsPlacePhoneTime => 'Lugar · celular · hora';

  @override
  String get toolsPickAPhotoAnd =>
      'Escolha uma foto e veja o que ela entrega. Depois guarde uma cópia limpa.';

  @override
  String get toolsPickAPhoto => 'Escolher uma foto';

  @override
  String get toolsVideo => 'Vídeo';

  @override
  String get transportTransport => 'Transporte';

  @override
  String get transportNothingHereLeavesThe =>
      'Nada daqui sai do celular. É o mesmo estado que o motor usa para decidir o que fazer.';

  @override
  String get transportStayingAlive => 'Mantendo vivo';

  @override
  String get transportCanSend => 'Pode enviar';

  @override
  String get commonYes => 'Sim';

  @override
  String get transportNotYet => 'Ainda não';

  @override
  String get transportOnline => 'Online';

  @override
  String get transportOffline => 'Offline';

  @override
  String get transportQueuedToSend => 'Na fila para enviar';

  @override
  String get transportOnionPublished => 'Onion publicado';

  @override
  String transportYes(Object uploads) {
    return 'Sim ($uploads)';
  }

  @override
  String transportTryingS(Object pubFor) {
    return 'Tentando há ${pubFor}s';
  }

  @override
  String transportBenchedS(Object r) {
    return 'Em pausa ${r}s';
  }

  @override
  String transportFails(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString falhas',
      one: '$countString falha',
    );
    return '$_temp0';
  }

  @override
  String get transportOk => 'OK';

  @override
  String get transportRelaySubscriptions => 'Inscrições em retransmissores';

  @override
  String get transportLastSent => 'Último envio';

  @override
  String get transportNever => 'Nunca';

  @override
  String transportSAgo(Object sx) {
    return 'há ${sx}s';
  }

  @override
  String get transportLastReceived => 'Último recebimento';

  @override
  String transportSAgo2(Object rx) {
    return 'há ${rx}s';
  }

  @override
  String get transportWithNoContactsThe =>
      'Sem contatos, o app não se inscreve em nenhum endereço de retransmissor, então nenhuma mensagem consegue chegar até você. Escaneie alguém para resolver.';

  @override
  String get transportSendAnythingWaitingNow =>
      'Enviar agora o que está esperando';

  @override
  String get transportSending => 'Enviando…';

  @override
  String get transportNothingLeftWaiting => 'Nada mais esperando';

  @override
  String transportStillWaiting(Object count) {
    return 'Ainda esperando: $count';
  }

  @override
  String get transportOff => 'Desligado';

  @override
  String get transportStarting => 'Iniciando';

  @override
  String get transportBootstrapped => 'Inicializado';

  @override
  String get transportPublishingAddress => 'Publicando endereço';

  @override
  String get transportReachable => 'Acessível';

  @override
  String get transportOurRelayOnion => 'Nosso retransmissor (onion)';

  @override
  String get transportNever2 => 'nunca';

  @override
  String get transportJustNow => 'Agora mesmo';

  @override
  String transportMAgo(Object inMinutes) {
    return 'há ${inMinutes}min';
  }

  @override
  String transportHAgo(Object inHours) {
    return 'há ${inHours}h';
  }

  @override
  String transportDAgo(Object inDays) {
    return 'há ${inDays}d';
  }

  @override
  String transportM(Object inMinutes) {
    return '${inMinutes}min';
  }

  @override
  String transportHM(Object inHours, Object d) {
    return '${inHours}h ${d}min';
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
  String get transportYesCheckedJustNow => 'Sim · verificado agora mesmo';

  @override
  String transportNoLast(Object ago) {
    return 'Não · última vez $ago';
  }

  @override
  String get transportLastMessageIn => 'Última mensagem recebida';

  @override
  String get transportBatteryExemption => 'Exceção de bateria';

  @override
  String get transportUnknown => 'Desconhecido';

  @override
  String get transportExempt => 'Com exceção';

  @override
  String get transportNotExemptTapTo => 'Sem exceção · toque para resolver';

  @override
  String get transportProcessUp => 'Processo ativo';

  @override
  String get transportLastStop => 'Última parada';

  @override
  String transportEngine(Object mb, Object mb2) {
    return '$mb · motor $mb2';
  }

  @override
  String get transportLastRelayArrival => 'Última pelo retransmissor';

  @override
  String get transportLastCheckIn => 'Última consulta';

  @override
  String get transportNoneYet => 'Nenhuma ainda';

  @override
  String get transportLastTorReconnect => 'Última reconexão do Tor';

  @override
  String get transportCatchUpByRelay => 'Recuperação via retransmissor';

  @override
  String get transportControlPort => 'Porta de controle';

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
      other: '$dialsString tentativas',
      one: '$dialsString tentativa',
    );
    String _temp1 = intl.Intl.pluralLogic(
      timeouts,
      locale: localeName,
      other: '$timeoutsString tempos esgotados',
      one: '$timeoutsString tempo esgotado',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get transportJobRuns => 'Execuções';

  @override
  String transportLast(Object jobRuns, Object ago) {
    return '$jobRuns · última $ago';
  }

  @override
  String get transportQuietStretches => 'Períodos de silêncio';

  @override
  String get transportNone => 'Nenhum';

  @override
  String get transportClearThisRecord => 'Limpar este registro';

  @override
  String get transportNothingYetThisProcess => 'Nada ainda neste processo';

  @override
  String transportM2(Object mins) {
    return '${mins}min';
  }

  @override
  String transportHM2(Object mins, Object mins2) {
    return '${mins}h ${mins2}min';
  }

  @override
  String transportTo(Object t, Object t2) {
    return '$t a $t2';
  }

  @override
  String vouchersVouchedBy(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Recomendado por $countString',
      one: 'Recomendado por',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperAtmosphere => 'Atmosfera';

  @override
  String get wallpaperJustForYouThey => 'Só para você. A pessoa vê o dela.';

  @override
  String get wallpaperYourPhoto => 'Sua foto';

  @override
  String get wallpaperFromYourPhotos => 'Das suas fotos';

  @override
  String get wallpaperKeepIt => 'Manter';

  @override
  String get whyKryfoWhyKryfo => 'Por que o Kryfo';

  @override
  String get whyKryfoKryfoKreeFoGreek =>
      'Kryfo · KRÍ-fo · do grego, “escondido”.\nUm lugar tranquilo para conversar, feito para que ninguém esteja olhando.';

  @override
  String get whyKryfoRoutedThroughTor => 'Roteado pelo tor';

  @override
  String get whyKryfoByDefaultEveryMessage =>
      'Por padrão, toda mensagem passa pelo tor - uma cadeia de retransmissores. Ninguém, nem nós nem a sua rede, consegue ver com quem você fala ou onde você está.';

  @override
  String get whyKryfoEndToEndEncrypted => 'Criptografado de ponta a ponta';

  @override
  String get whyKryfoMessagesAreSealedWith =>
      'As mensagens são lacradas com chaves que só você e a pessoa com quem você fala têm. Não conseguiríamos ler nem se tentássemos.';

  @override
  String get whyKryfoNoServersHoldingYour =>
      'Nenhum servidor guardando a sua vida';

  @override
  String get whyKryfoNoAccountNoPhone =>
      'Sem conta, sem número de telefone, sem servidor central guardando suas conversas. Elas ficam neste celular, criptografadas no armazenamento.';

  @override
  String get whyKryfoNothingLeaks => 'Nada vaza';

  @override
  String get whyKryfoNoReadReceiptsOr =>
      'Nenhuma confirmação de leitura ou aviso de digitação entregue a ninguém, nenhuma lista de contatos enviada. Metadados são o que a maioria dos apps vaza - o Kryfo é feito para não vazar.';

  @override
  String get whyKryfoVerifyItIsReally => 'Confirme que é mesmo a pessoa';

  @override
  String get whyKryfoCompareASafetyNumber =>
      'Compare um número de segurança pessoalmente ou por um canal de confiança, para saber que ninguém está se passando pelo seu contato.';

  @override
  String get whyKryfoTheHonestPart => 'A parte honesta';

  @override
  String get whyKryfoKryfoIsPreAlpha =>
      'O Kryfo está em alfa e não passou por auditoria. A criptografia é real, mas nenhum especialista de fora a verificou ainda, então trate como um trabalho em andamento, não como algo a que você já possa confiar a sua vida.';

  @override
  String get cleanerLocation => 'Localização';

  @override
  String get cleanerAlreadyBlankedByAndroid => 'já removida pelo Android';

  @override
  String get cleanerPhoneModel => 'Modelo do celular';

  @override
  String get cleanerTimeTaken => 'Hora da captura';

  @override
  String get cleanerSerialNumber => 'Número de série';

  @override
  String get cleanerOwnerName => 'Nome do dono';

  @override
  String get cleanerHiddenThumbnail => 'Miniatura oculta';

  @override
  String get cleanerContentCredentials => 'Credenciais de conteúdo';

  @override
  String get cleanerDataAfterThePicture => 'Dados depois da imagem';

  @override
  String cleaner1OtherField(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString outros campos',
      one: '$countString outro campo',
    );
    return '$_temp0';
  }

  @override
  String get lockWordsFourRandomWordsBeat =>
      'Quatro palavras aleatórias ganham de uma esperta.';

  @override
  String lockWordsTooShortAtLeast(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Curta demais. Pelo menos $countString caracteres.',
      one: 'Curta demais. Pelo menos $countString caractere.',
    );
    return '$_temp0';
  }

  @override
  String get lockWordsWeakWhoeverGetsThe =>
      'Fraca. Quem pegar o arquivo pode chutar tão rápido quanto quiser.';

  @override
  String get lockWordsFairLongerIsStronger =>
      'Razoável. Mais longa é mais forte.';

  @override
  String get lockWordsStrongFourRandomWords =>
      'Forte. Quatro palavras aleatórias ganham de uma esperta.';

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
      other: '$countString metros',
      one: '$countString metro',
    );
    return '$_temp0';
  }

  @override
  String get photoStoryFarFromAnyTown => 'Longe de qualquer cidade';

  @override
  String photoStoryNear(Object where) {
    return 'Perto de $where';
  }

  @override
  String photoStoryAboutKmFrom(Object near, Object where) {
    return 'A cerca de $near km de $where';
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
  String get photoStoryNotAKindKryfo =>
      'Não é um tipo que o Kryfo consegue ler.';

  @override
  String get photoStorySoItWillNot => 'Então ele não vai chutar.';

  @override
  String get photoStoryThisFileIsDamaged =>
      'Este arquivo está danificado ou incompleto.';

  @override
  String get photoStoryKryfoCouldNotRead =>
      'O Kryfo não conseguiu ler até o fim.';

  @override
  String get photoStoryWhereItWasRecorded => 'Onde foi gravado';

  @override
  String get photoStoryWhereItWasTaken => 'Onde foi tirada';

  @override
  String photoStoryLocation(Object coordsLine) {
    return 'Localização: $coordsLine';
  }

  @override
  String photoStoryHeightAboveTheSea(Object fix) {
    return 'Altitude: $fix m';
  }

  @override
  String get photoStoryLocationHiddenByAndroid =>
      'Localização oculta pelo Android';

  @override
  String get photoStoryAndroidBlanksItWhen =>
      'O Android remove a localização quando uma foto é escolhida desse jeito. Compartilhar com o Kryfo pela galeria costuma manter. A que está na sua galeria ainda pode ter.';

  @override
  String get photoStoryLocationBlankedByAndroid =>
      'Localização: removida pelo Android antes de o Kryfo ver';

  @override
  String photoStoryF(Object r) {
    return 'f/$r';
  }

  @override
  String get photoStoryWhatTookIt => 'Com o que foi feita';

  @override
  String photoStoryPhoneOrCamera(Object phone) {
    return 'Celular ou câmera: $phone';
  }

  @override
  String get photoStoryWhenItWasRecorded => 'Quando foi gravado';

  @override
  String get photoStoryToTheSecondWith => 'Até o segundo, com o fuso horário';

  @override
  String get photoStoryToTheSecond => 'Até o segundo';

  @override
  String photoStoryTime(Object dateFormat) {
    return 'Hora: $dateFormat';
  }

  @override
  String get photoStoryLens => 'Lente';

  @override
  String photoStoryLens2(Object lens) {
    return 'Lente: $lens';
  }

  @override
  String get photoStorySoftware => 'Software';

  @override
  String photoStorySoftware2(Object software) {
    return 'Software: $software';
  }

  @override
  String get photoStorySerialNumber => 'Número de série';

  @override
  String photoStorySerialNumber2(Object serial) {
    return 'Número de série: $serial';
  }

  @override
  String get photoStoryOwnerName => 'Nome do dono';

  @override
  String photoStoryOwner(Object r) {
    return 'Dono: $r';
  }

  @override
  String get photoStoryHiddenThumbnail => 'Miniatura oculta';

  @override
  String get photoStoryASmallCopyOf =>
      'Uma cópia pequena da imagem dentro do arquivo. Pode mostrar o que um corte removeu';

  @override
  String get photoStoryMakerNotes => 'Notas do fabricante';

  @override
  String get photoStoryMakerNotesABlock =>
      'Notas do fabricante: um bloco que só o fabricante consegue ler';

  @override
  String get photoStoryEditingHistory => 'Histórico de edição';

  @override
  String get photoStoryXmpEditingHistoryAnd =>
      'XMP: histórico de edição e tags';

  @override
  String get photoStoryCaptions => 'Legendas';

  @override
  String get photoStoryIptcCaptionsAndCredits => 'IPTC: legendas e créditos';

  @override
  String get photoStoryComment => 'Comentário';

  @override
  String get photoStoryAWrittenComment => 'Um comentário escrito';

  @override
  String get photoStoryContentCredentials => 'Credenciais de conteúdo';

  @override
  String get photoStorySecondPicture => 'Segunda imagem';

  @override
  String get photoStoryASecondPictureInside =>
      'Uma segunda imagem dentro do arquivo';

  @override
  String get photoStoryMotionVideo => 'Vídeo de movimento';

  @override
  String get photoStoryAShortVideoInside => 'Um vídeo curto dentro do arquivo';

  @override
  String get photoStorySaveTime => 'Salvo em';

  @override
  String get photoStoryTheTimeItWas =>
      'A hora em que foi salvo pela última vez';

  @override
  String get photoStoryTimeStamps => 'Carimbos de hora';

  @override
  String get photoStoryCreationTimeStamps => 'Carimbos de hora da criação';

  @override
  String get photoStoryDataAfterThePicture => 'Dados depois da imagem';

  @override
  String photoStoryDataAfterTheEnd(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Dados depois do fim da imagem: $countString bytes',
      one: 'Dados depois do fim da imagem: $countString byte',
    );
    return '$_temp0';
  }

  @override
  String photoStoryTextField(Object k) {
    return 'Campo de texto: $k';
  }

  @override
  String photoStoryVideoTag(Object k) {
    return 'Tag de vídeo: $k';
  }

  @override
  String photoStoryAlso(Object k) {
    return 'Também: $k';
  }

  @override
  String photoStoryCameraSettingsFlashFocus(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString ajustes da câmera (flash, foco, exposição)',
      one: '$countString ajuste da câmera (flash, foco, exposição)',
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
      other: 'mais $countString campos',
      one: 'mais $countString campo',
    );
    return '$_temp0';
  }

  @override
  String get photoStoryCameraSettings => 'Ajustes da câmera';

  @override
  String photoStoryAccurateToAbout(Object metres) {
    return 'Precisão de cerca de $metres.';
  }

  @override
  String get photoStoryEnoughToFindThe => 'O suficiente para achar a porta.';

  @override
  String get photoStoryEnoughToFindTheStreet =>
      'O suficiente para achar a rua.';

  @override
  String get photoStoryEnoughToFindTheArea =>
      'O suficiente para achar a região.';

  @override
  String get photoStoryItKnowsWhereYou => 'Sabe onde você estava.';

  @override
  String get photoStoryDownToTheBuilding => 'Até o prédio.';

  @override
  String get photoStoryAndroidHidTheLocation =>
      'O Android escondeu a localização.';

  @override
  String get photoStoryTheOriginalMayStill =>
      'O original ainda pode ter a localização.';

  @override
  String get photoStoryNoLocationInThis => 'Nenhuma localização neste arquivo.';

  @override
  String get photoStoryItStillSaysPlenty => 'Ainda diz bastante coisa.';

  @override
  String get photoStoryThisOneKnowsNothing => 'Este arquivo não sabe nada.';

  @override
  String get photoStoryNothingToRemove => 'Nada para remover.';

  @override
  String get qrPayloadOpensALink => 'ABRE UM LINK';

  @override
  String qrPayloadOpens(Object host) {
    return 'ABRE $host';
  }

  @override
  String get qrPayloadShowsANote => 'MOSTRA UMA NOTA';

  @override
  String get qrPayloadScanToJoin => 'ESCANEIE PARA ENTRAR';

  @override
  String qrPayloadScanToJoin2(Object oneLine) {
    return 'ESCANEIE PARA ENTRAR · $oneLine';
  }

  @override
  String get qrPayloadANetworkNameIs =>
      'Um nome de rede tem no máximo 32 caracteres.';

  @override
  String get qrPayloadAWiFiPassword =>
      'Uma senha de Wi-Fi tem pelo menos 8 caracteres.';

  @override
  String get qrPayloadSavesAContact => 'SALVA UM CONTATO';

  @override
  String get qrPayloadWritesAnEmail => 'ESCREVE UM E-MAIL';

  @override
  String get qrPayloadThatDoesNotLook =>
      'Isso não parece um endereço de e-mail.';

  @override
  String get qrPayloadCallsANumber => 'LIGA PARA UM NÚMERO';

  @override
  String get qrPayloadWritesAText => 'ESCREVE UM SMS';

  @override
  String get qrPayloadOpensAMap => 'ABRE UM MAPA';

  @override
  String get qrPayloadLatitudeRunsFrom90 =>
      'A latitude vai de -90 a 90, a longitude de -180 a 180.';

  @override
  String get qrPayloadPayThisAddress => 'PAGA PARA ESTE ENDEREÇO';

  @override
  String get qrPayloadABitcoinAddressIs =>
      'Um endereço bitcoin só tem letras e números.';

  @override
  String get qrPayloadTheAmountIsIn =>
      'O valor é em BTC, com até 8 casas decimais.';

  @override
  String vouchTextAnd(Object names, Object names2) {
    return '$names e $names2';
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
      other: 'mais $restString pessoas',
      one: 'mais $restString pessoa',
    );
    return '$names, $names2 e $_temp0 que você conhece';
  }

  @override
  String vouchTextVouchedBy(Object vouchNames) {
    return 'Recomendado por $vouchNames';
  }

  @override
  String vouchTextIntroducedBy(Object vouchNames) {
    return 'Apresentado por $vouchNames';
  }

  @override
  String vouchTextThisSharesSAddress(Object a, Object b) {
    return 'Isso compartilha o endereço de $a com $b';
  }

  @override
  String get bootFailedKryfoCouldNotStart => 'O Kryfo não conseguiu iniciar';

  @override
  String get bootFailedThisIsAFault =>
      'Isto é uma falha neste aparelho, não na rede. O tor não tem nada a ver com isso.';

  @override
  String get kryfoLinkTextThatLinkIsNot =>
      'Esse link não é um que o Kryfo consegue ler';

  @override
  String kryfoLinkTextAdd(Object who) {
    return 'Adicionar $who?';
  }

  @override
  String kryfoLinkTextThisIsAnInvite(Object who) {
    return 'Este é um convite para conversar com $who. Só adicione se você souber de onde o link veio.';
  }

  @override
  String get kryfoLinkTextAddThem => 'Adicionar';

  @override
  String get kryfoLinkTextNotNow => 'Agora não';

  @override
  String kryfoLinkTextJoin(Object roomName) {
    return 'Entrar em $roomName';
  }

  @override
  String get kryfoLinkTextKryfoLink => 'Link do Kryfo';

  @override
  String kryfoLinkTextAdd2(Object who) {
    return 'Adicionar $who';
  }

  @override
  String get kryfoLinkTextBurnerRoom => 'SALA TEMPORÁRIA';

  @override
  String get kryfoLinkTextThisRoomHasClosed => 'Esta sala foi fechada';

  @override
  String kryfoLinkTextClosesIn(Object time) {
    return 'Fecha em $time';
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
      other: 'Fecha em $time · até $capString',
    );
    return '$_temp0';
  }

  @override
  String get kryfoLinkTextJoin2 => 'Entrar';

  @override
  String get kryfoLinkTextYouJoinUnderA =>
      'Você entra com uma chave feita para esta sala. Ninguém nela vê o seu ID do Kryfo.';

  @override
  String get linkStubFetchedOverTorBy => 'Buscado via tor · pelo seu aparelho';

  @override
  String get linkStubFetchedOverTorByTheirDevice =>
      'Buscado via tor · pelo aparelho da pessoa';

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
  String get mediaBubblesFile => 'ARQUIVO';

  @override
  String get mediaBubblesAudioUnavailable => 'Áudio indisponível';

  @override
  String get mediaBubblesHidden => 'Oculto';

  @override
  String get mediaBubblesPlaying => 'Reproduzindo';

  @override
  String get mediaBubblesMicPermissionNeeded =>
      'Precisa da permissão do microfone';

  @override
  String get mediaBubblesReleaseToCancel => 'Solte para cancelar';

  @override
  String get mediaBubblesVoiceHiddenSlideTo =>
      'Voz oculta · deslize para cancelar';

  @override
  String get mediaBubblesSlideToCancel => 'Deslize para cancelar';

  @override
  String get mediaBubblesSendPhoto => 'Enviar foto';

  @override
  String get mediaBubblesAddACaption => 'Adicionar uma legenda…';

  @override
  String get motionStandby => 'EM ESPERA';

  @override
  String get motionConnecting => 'CONECTANDO';

  @override
  String get motionBuilding => 'MONTANDO';

  @override
  String get motionPublishing => 'PUBLICANDO';

  @override
  String get motionReady => 'PRONTO';

  @override
  String get motionPreparingToConnect => 'Preparando para conectar';

  @override
  String get motionFindingAPrivatePath => 'Procurando um caminho privado';

  @override
  String get motionCarvingThePath => 'Abrindo o caminho';

  @override
  String get motionAnnouncingYourArrival => 'Anunciando sua chegada';

  @override
  String get motionYouReAnonymous => 'Você está no anonimato';

  @override
  String get motionTorIsStartingIn =>
      'O tor está iniciando em segundo plano. Este gráfico se acende conforme a conexão se forma.';

  @override
  String get motionMakingAFreshRoute =>
      'Criando uma rota nova por retransmissores anônimos.';

  @override
  String get motionBouncingThroughRelaysSo =>
      'Passando por retransmissores para que ninguém consiga rastrear isto até você.';

  @override
  String get motionTellingTheNetworkYou =>
      'Avisando a rede que você está online — sem revelar onde.';

  @override
  String get motionYourIpIsHidden =>
      'Seu IP está oculto. Só quem tem o seu Kryfo consegue falar com você.';

  @override
  String get motionBuilding2 => 'montando';

  @override
  String get motionOpen => 'aberto';

  @override
  String get motionLive => 'ativo';

  @override
  String motionCircuit(Object circuit) {
    return 'Circuito · *$circuit*';
  }

  @override
  String get motionDelivered => 'Entregue';

  @override
  String get motionSent => 'Enviado';

  @override
  String get motion1Hop => '1 salto';

  @override
  String get motion3Hops => '3 saltos';

  @override
  String get movedStripThisKryfoHasMoved =>
      'Este Kryfo mudou para outro aparelho. Nada enviado daqui chega a ninguém.';

  @override
  String get navBarChats => 'Conversas';

  @override
  String get navBarTools => 'Ferramentas';

  @override
  String get navBarSupport => 'Apoiar';

  @override
  String get navBarMe => 'Eu';

  @override
  String get pairCodePanelPuttingYourInviteIn => 'Preparando seu convite';

  @override
  String get pairCodePanelYourInviteIsNot =>
      'Seu convite ainda não está pronto';

  @override
  String get pairCodePanelReadSixDigitsOut =>
      'Leia seis dígitos em voz alta e a pessoa pode adicionar você. Nada mais precisa trocar de mãos.';

  @override
  String get pairCodePanelWorking => 'Trabalhando';

  @override
  String get pairCodePanelOrMakeASix =>
      'Ou crie um código de seis dígitos para ler em voz alta';

  @override
  String get pairCodePanelCodeCopied => 'Código copiado';

  @override
  String pairCodePanelBurnsIn(Object mm, Object ss) {
    return 'Some em $mm:$ss';
  }

  @override
  String get pairCodePanelTheyTapAddChoose =>
      'A pessoa toca em adicionar, escolhe código e digita estes números.';

  @override
  String get pairCodePanelTheyOpenKryfoTap =>
      'A pessoa abre o Kryfo, toca em adicionar, escolhe código de pareamento e digita estes seis dígitos. Crie um novo para a próxima pessoa.';

  @override
  String get pairCodePanelYourWords => 'Suas três palavras';

  @override
  String pinsPinnedMessages(Object count) {
    return 'Mensagens fixadas · $count';
  }

  @override
  String get pinsPinnedMessages2 => 'Mensagens fixadas';

  @override
  String get pinsPhoto => 'Foto';

  @override
  String get pinsVoiceMessage => 'Mensagem de voz';

  @override
  String get pinsMessage => 'Mensagem';

  @override
  String pinsToday(Object hm) {
    return 'Hoje · $hm';
  }

  @override
  String get pinsPinned => 'Fixada';

  @override
  String pinsOf(Object pinsLength, Object kMaxPins) {
    return '$pinsLength de $kMaxPins';
  }

  @override
  String get pinsNothingPinnedHereYet =>
      'Nada fixado aqui ainda. Segure uma mensagem e escolha Fixar, e ela fica aqui esperando por todos na conversa.';

  @override
  String get pinsJump => 'Ir';

  @override
  String get pinsUnpin => 'Desafixar';

  @override
  String powNoteFirstMessageToSomeone(int secs) {
    final intl.NumberFormat secsNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String secsString = secsNumberFormat.format(secs);

    return 'Primeira mensagem para alguém novo · provando que é real · ${secsString}s';
  }

  @override
  String powNoteFirstMessageSlow(int secs) {
    final intl.NumberFormat secsNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String secsString = secsNumberFormat.format(secs);

    return 'Primeira mensagem para alguém novo · provando que é real · ${secsString}s · até um minuto num celular lento';
  }

  @override
  String previewStripFetchedOverTor(Object domainOf) {
    return '$domainOf · buscado pelo tor';
  }

  @override
  String get previewStripDropThePreview => 'Tirar a prévia';

  @override
  String get previewStripAddPreview => 'Adicionar prévia';

  @override
  String get previewStripFetchingOverTor => 'Buscando pelo tor…';

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
  String get torBootSplashNoShortcutsNoTraces => 'Sem atalhos, sem rastros';

  @override
  String get torBootSplashTheNetworkThatKeeps =>
      'A rede que protege sua privacidade está esquentando';

  @override
  String get torBootSplashMadeOnThisPhone =>
      'Feito neste celular. Nada é enviado para lugar nenhum.';

  @override
  String get torBootSplashFirstLaunchTakesA =>
      'A primeira abertura leva um momento · só na inicialização';

  @override
  String get videoBubbleNothingHereOpensThat =>
      'Nada aqui abre isso · compartilhando no lugar';

  @override
  String videoBubbleMb(Object b) {
    return '$b MB';
  }

  @override
  String videoBubbleKb(Object b) {
    return '$b KB';
  }

  @override
  String get videoBubbleVideo => 'Vídeo';

  @override
  String get notificationsChannelName => 'Mensagens';

  @override
  String get cameraClose => 'Fechar';

  @override
  String get cameraFlash => 'Flash';

  @override
  String get cameraPhoto => 'Foto';

  @override
  String get cameraVideo => 'Vídeo';

  @override
  String get cameraRetake => 'Refazer';

  @override
  String get seenIntroductions => 'Apresentações';

  @override
  String get donateAddress => 'Endereço';

  @override
  String get donateCopy => 'Copiar';

  @override
  String get donateDone => 'Pronto';

  @override
  String get donateTierSupporter => 'Apoiador';

  @override
  String get donateTierPatron => 'Mecenas';

  @override
  String get donateTierGuardian => 'Guardião';

  @override
  String get chatBlock => 'Bloquear';

  @override
  String get chatDecline => 'Recusar';

  @override
  String get chatAccept => 'Aceitar';

  @override
  String get bridgesConnecting => 'Conectando';

  @override
  String get bridgesSavedTag => 'Salvo';

  @override
  String get restoreMade => 'Criado';

  @override
  String get restoreContacts => 'Contatos';

  @override
  String get restoreMessages => 'Mensagens';

  @override
  String get restoreAttachments => 'Anexos';

  @override
  String get restoreHiddenChats => 'Conversas ocultas';

  @override
  String get restoreHiddenFollow =>
      'Suas conversas ocultas, com um novo PIN das conversas ocultas que você vai escolher no final.';

  @override
  String get restoreChooseHiddenPin =>
      'Este backup guarda conversas ocultas. Escolha um PIN das conversas ocultas para elas.';

  @override
  String get restoreHiddenLockFirst =>
      'As conversas ocultas precisam do bloqueio do app, então o Kryfo ganha primeiro um PIN próprio.';

  @override
  String get shieldBlock => 'Bloquear';

  @override
  String get shieldDelete => 'Excluir';

  @override
  String get shieldIgnore => 'Ignorar';

  @override
  String get profileIdentity => 'Identidade';

  @override
  String get avatarPickerShape => 'Forma';

  @override
  String get avatarPickerColour => 'Cor';

  @override
  String get avatarPickerTurn => 'Girar';

  @override
  String avatarPickerOption(String what, int n, int count) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$what, $nString de $countString';
  }

  @override
  String get avatarPickerYourInitial => 'Sua inicial';

  @override
  String get transportStatus => 'Status';

  @override
  String get transportBootstrap => 'Inicialização';

  @override
  String get transportNetwork => 'Rede';

  @override
  String get transportConnectivity => 'Conectividade';

  @override
  String get transportRelays => 'Retransmissores';

  @override
  String get transportTraffic => 'Tráfego';

  @override
  String get transportContacts => 'Contatos';

  @override
  String get transportKnown => 'Conhecidos';

  @override
  String get transportListening => 'Escutando';

  @override
  String get transportMemory => 'Memória';

  @override
  String get settingsConnected => 'Conectado';

  @override
  String get settingsScreenshots => 'Capturas de tela';

  @override
  String get settingsBlocked2 => 'Bloqueadas';

  @override
  String get settingsAllowed => 'Permitidas';

  @override
  String get settingsOn => 'Ativado';

  @override
  String get settingsOff => 'Desativado';

  @override
  String get settingsNotifications => 'Notificações';

  @override
  String get settingsPrivacy => 'Privacidade';

  @override
  String get settingsSecurity => 'Segurança';

  @override
  String get settingsBackup => 'Backup';

  @override
  String get settingsVoice => 'Voz';

  @override
  String get settingsAbout => 'Sobre';

  @override
  String get wallpaperGradients => 'Gradientes';

  @override
  String get wallpaperPatterns => 'Padrões';

  @override
  String get wallpaperMoods => 'Climas';

  @override
  String get confirmSheetKeep => 'Manter';

  @override
  String get confirmSheetSave => 'Salvar';

  @override
  String get confirmSheetCancel => 'Cancelar';

  @override
  String bridgesSaved(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString pontes',
      one: '$countString ponte',
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

    return 'aceitas: $goodString, não entendidas: $badString';
  }

  @override
  String get bridgesNoneUsable =>
      'Nenhuma destas linhas é uma ponte utilizável, então as pontes continuam desligadas';

  @override
  String get bridgesCouldNotApply =>
      'Não deu para aplicar as pontes. Tente salvar de novo.';

  @override
  String get languageTitle => 'Idioma';

  @override
  String get languageMatchPhone => 'Igual ao celular';

  @override
  String languageMatchPhoneValue(Object language) {
    return 'Igual ao celular ($language)';
  }

  @override
  String get languageRedrawLine =>
      'O Kryfo se redesenha no novo idioma e abre nas suas conversas.';

  @override
  String languageButton(Object language) {
    return 'Idioma: $language';
  }

  @override
  String get androidServiceTitle => 'O Kryfo está ativo';

  @override
  String get androidServiceText =>
      'Sua linha criptografada fica aberta para as mensagens chegarem';

  @override
  String get androidChannelName => 'Mantendo a conexão';

  @override
  String get androidChannelDescription =>
      'Mantém o Kryfo conectado para que mensagens criptografadas cheguem enquanto ele está fechado. Desativar isto interrompe a entrega.';

  @override
  String get videoViewerPlay => 'Reproduzir';

  @override
  String get videoViewerPause => 'Pausar';

  @override
  String get videoViewerPlayAgain => 'Reproduzir de novo';

  @override
  String get videoViewerCannotPlay =>
      'Este celular não consegue reproduzir este vídeo aqui.';

  @override
  String get videoViewerOpenElsewhere => 'Abrir em outro app';

  @override
  String get photoKnowsLookedFor => 'Procuramos';

  @override
  String get photoKnowsNotInIt => 'Não tem';

  @override
  String get languageNameEn => 'Inglês';

  @override
  String get languageNameDe => 'Alemão';

  @override
  String get languageNameFr => 'Francês';

  @override
  String get languageNameEs => 'Espanhol';

  @override
  String get languageNamePt => 'Português (Brasil)';

  @override
  String get languageNameIt => 'Italiano';

  @override
  String get languageNameRu => 'Russo';

  @override
  String get languageNameUk => 'Ucraniano';

  @override
  String get languageNameTr => 'Turco';

  @override
  String get languageNameZh => 'Chinês (simplificado)';

  @override
  String get languageNameZhHant => 'Chinês (tradicional)';

  @override
  String get languageNameVi => 'Vietnamita';

  @override
  String get languageNameId => 'Indonésio';

  @override
  String get languageNameFa => 'Persa';

  @override
  String get languageNameAr => 'Árabe';

  @override
  String get languageLaterLine =>
      'Você pode mudar isso quando quiser nas configurações.';

  @override
  String get pollAttach => 'Enquete';

  @override
  String get pollNewTitle => 'Nova enquete';

  @override
  String get pollQuestionHint => 'Pergunte algo ao grupo';

  @override
  String get pollOptionsLabel => 'Opções';

  @override
  String pollOptionHint(Object n) {
    return 'Opção $n';
  }

  @override
  String get pollAddOption => 'Adicionar opção';

  @override
  String get pollMaxLine => 'No máximo doze opções.';

  @override
  String get pollMultiple => 'Várias respostas';

  @override
  String get pollMultipleLine => 'Dá para escolher mais de uma.';

  @override
  String get pollSend => 'Enviar enquete';

  @override
  String get pollKind => 'Enquete';

  @override
  String get pollKindMulti => 'Enquete · várias respostas';

  @override
  String get pollKindClosed => 'Resultado final';

  @override
  String pollVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count votos',
      one: '$count voto',
      zero: 'Nenhum voto ainda',
    );
    return '$_temp0';
  }

  @override
  String get pollVote => 'Votar';

  @override
  String get pollTakeBack => 'Retirar meu voto';

  @override
  String get pollClose => 'Encerrar enquete';

  @override
  String get pollCloseTitle => 'Encerrar esta enquete?';

  @override
  String get pollCloseLine =>
      'Todos veem o resultado final, e ninguém pode votar depois disso.';

  @override
  String get pollCloseYes => 'Encerrar';

  @override
  String pollPreview(Object question) {
    return 'Enquete: $question';
  }

  @override
  String get pollWhoVoted => 'Quem votou';

  @override
  String get pollNobody => 'Ninguém ainda';

  @override
  String get pollYou => 'Você';

  @override
  String pollOptionA11y(Object option, Object share) {
    return '$option, $share';
  }

  @override
  String get pollPickOne => 'Escolha uma';

  @override
  String get pollPickSeveral => 'Escolha uma ou mais';

  @override
  String get searchOpen => 'Pesquisar';

  @override
  String get searchHint => 'Pesquisar conversas e mensagens';

  @override
  String get searchFilterAll => 'Tudo';

  @override
  String get searchFilterPhotos => 'Fotos';

  @override
  String get searchFilterVideos => 'Vídeos';

  @override
  String get searchFilterFiles => 'Arquivos';

  @override
  String get searchFilterLinks => 'Links';

  @override
  String get searchChats => 'Conversas';

  @override
  String get searchMessages => 'Mensagens';

  @override
  String get searchIntroTitle => 'Pesquise nas suas conversas';

  @override
  String get searchIntroLine =>
      'Nomes, palavras, fotos, arquivos e links. A pesquisa acontece neste celular e não envia nada a lugar nenhum.';

  @override
  String get searchNothing => 'Nada encontrado';

  @override
  String get searchNothingLine => 'Tente outra palavra ou outro filtro.';

  @override
  String searchMatches(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count resultados',
      one: '$count resultado',
    );
    return '$_temp0';
  }

  @override
  String searchMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'mais $count',
      one: 'mais $count',
    );
    return '$_temp0';
  }

  @override
  String searchFilling(Object share) {
    return 'Adicionando mensagens antigas · $share';
  }

  @override
  String get searchClear => 'Limpar';

  @override
  String get handleShowInSearch => 'Mostrar-me na pesquisa';

  @override
  String get handleShowInSearchLine =>
      'Qualquer pessoa pode encontrar este nome de usuário e te mandar mensagem.';

  @override
  String handleShownAs(Object name) {
    return 'Aparece como $name';
  }

  @override
  String get handleNameInSearch => 'Nome na pesquisa';

  @override
  String get handleNameInSearchLine =>
      'Opcional. Aparece ao lado do seu nome de usuário quando alguém pesquisa. Qualquer pessoa pode encontrar este nome de usuário e te mandar mensagem.';

  @override
  String get handleNameHint => 'Seu nome, ou deixe em branco';

  @override
  String get handleShowMe => 'Mostrar-me';

  @override
  String get handleSearchOff => 'Você saiu da pesquisa';

  @override
  String handleSearchOn(Object handle) {
    return 'Você está na pesquisa como @$handle';
  }

  @override
  String get handleRegistryFailed =>
      'Não foi possível falar com o registro. Tente de novo em um minuto.';

  @override
  String get handleCheckClock =>
      'Confira a data e a hora do celular e tente de novo.';

  @override
  String get searchPeople => 'Pessoas';

  @override
  String searchPeopleAsk(Object query) {
    return 'Procurar “$query” entre os nomes de usuário públicos';
  }

  @override
  String get searchPeopleLine =>
      'Perguntado via Tor. O registro não guarda nenhum registro disso.';

  @override
  String get searchPeopleNone => 'Nenhum nome de usuário público corresponde';

  @override
  String get searchPeopleOffline => 'O Tor ainda não está pronto';

  @override
  String get searchPeopleBusy =>
      'Muitas pesquisas agora. Tente de novo daqui a pouco.';

  @override
  String get searchPeopleUnreachable => 'Não foi possível falar com o registro';

  @override
  String get peopleVerified => 'Nome de usuário verificado';

  @override
  String get peopleAdd => 'Adicionar';

  @override
  String peopleFingerprint(Object fp) {
    return 'Impressão digital da chave · $fp';
  }

  @override
  String get peopleFingerprintLine =>
      'Confira se é a mesma que a pessoa vê no app dela.';

  @override
  String get peopleAdding => 'Adicionando…';

  @override
  String handleNobodyHasClaimed(Object handle) {
    return 'Ninguém reservou $handle';
  }

  @override
  String get handleThatHandleIsTaken => 'Esse nome de usuário já está em uso';

  @override
  String get pinPickDifferent => 'Escolha outro PIN';

  @override
  String get settingsKeptOnWhileLock =>
      'Fica ativado enquanto o bloqueio do app estiver ativado.';

  @override
  String get lockFingerAfterPin =>
      'Digite seu PIN uma vez para usar a digital de novo.';

  @override
  String get pinsAdvanced => 'Proteção avançada';

  @override
  String get pinsAdvancedLine =>
      'Para quando alguém obriga você a desbloquear o celular.';

  @override
  String get pinsWipeLine =>
      'Digitado na tela de bloqueio, apaga o Kryfo deste celular.';

  @override
  String get pinsDecoyPin => 'PIN de disfarce';

  @override
  String get pinsDecoyLine =>
      'Abre um Kryfo vazio, como se acabasse de ser instalado.';

  @override
  String get pinsSetADecoyPin => 'Definir PIN de disfarce';

  @override
  String get pinsChangeDecoyPin => 'Mudar PIN de disfarce';

  @override
  String get pinsRemoveTheDecoyPin => 'Remover o PIN de disfarce?';

  @override
  String get pinsTheDecoyGoes => 'O Kryfo vazio que ele abre vai junto.';

  @override
  String get pinsTurnOffWithDecoy =>
      'Todos os PINs saem, e junto com eles o disfarce, o Kryfo dele e qualquer conversa oculta. Qualquer pessoa com seu celular abre o Kryfo como se fosse você.';

  @override
  String get pinsHowThisWorks => 'Como funciona';

  @override
  String get flowEnterYourPin => 'Digite seu PIN';

  @override
  String get flowEnterYourPinLine => 'O que abre o Kryfo.';

  @override
  String get flowWipeTitle => 'Um PIN de apagamento';

  @override
  String get flowWipe1 =>
      'Digitado na tela de bloqueio no lugar do seu PIN, ele apaga o Kryfo deste celular e o fecha. Para quem estiver olhando, o app só parou.';

  @override
  String get flowWipe2 =>
      'Ele leva cada conversa e sua identidade junto, e o disfarce se você tiver um.';

  @override
  String get flowWipeChoose => 'Escolha um PIN de apagamento';

  @override
  String get flowWipeDone => 'PIN de apagamento definido';

  @override
  String get flowWipeDoneLine =>
      'Nada na tela de bloqueio mostra que ele existe.';

  @override
  String get flowDecoyTitle => 'Um PIN de disfarce';

  @override
  String get flowDecoy1 =>
      'Abre um Kryfo vazio, como se acabasse de ser instalado.';

  @override
  String get flowDecoyFinger =>
      'Sua digital abre seu Kryfo de verdade. Se alguém puder obrigar você a usá-la, desative a digital.';

  @override
  String get flowDecoyDigits =>
      'Use o mesmo número de dígitos do seu PIN, porque quem estiver olhando pode contar os pontos.';

  @override
  String get flowDecoyShade =>
      'As notificações que já estão na barra já foram vistas. Enquanto o disfarce estiver aberto, nenhuma nova aparece.';

  @override
  String get flowDecoyChoose => 'Escolha um PIN de disfarce';

  @override
  String get flowDecoyDone => 'PIN de disfarce definido';

  @override
  String get flowDecoyDoneLine =>
      'Digite-o na tela de bloqueio para abrir o Kryfo vazio. Para sair, troque de app e digite seu PIN.';

  @override
  String get flowLaw =>
      'Em alguns países, recusar-se a desbloquear um celular ou esconder dados das autoridades já é crime por si só. Conheça a lei dos lugares para onde você viaja.';

  @override
  String get howWipe =>
      'Digitado na tela de bloqueio, o PIN de apagamento apaga cada conversa, sua identidade e qualquer disfarce, e depois fecha o Kryfo. Funciona mesmo quando o teclado está travado depois de tentativas erradas.';

  @override
  String get howDecoy =>
      'O PIN de disfarce abre um segundo Kryfo, vazio, com três palavras próprias. As mensagens para o seu Kryfo de verdade continuam chegando por baixo, em silêncio. Para sair do disfarce, troque de app e digite seu PIN.';

  @override
  String get flowNotSet => 'Não deu para definir. Tente de novo.';

  @override
  String get pinsHiddenChats => 'Conversas ocultas';

  @override
  String get pinsHiddenLine =>
      'As conversas escolhidas ficam fora de vista até você digitar o PIN das conversas ocultas: nem na lista, nem na busca, sem notificações.';

  @override
  String get pinsSetUp => 'Configurar';

  @override
  String get pinsChangeHiddenPin => 'Mudar PIN das conversas ocultas';

  @override
  String get pinsHideMoreChats => 'Ocultar mais conversas';

  @override
  String get pinsRemoveHiddenChats => 'Remover conversas ocultas';

  @override
  String get pinsRemoveHiddenTitle => 'Remover as conversas ocultas?';

  @override
  String get pinsRemoveHiddenLine =>
      'Elas voltam para a sua lista de conversas, e o PIN das conversas ocultas deixa de abrir qualquer coisa.';

  @override
  String get pinsTurnOffHiddenFirst =>
      'As conversas ocultas precisam do bloqueio do app. Remova-as primeiro, e elas voltam para a sua lista de conversas.';

  @override
  String get flowVaultTitle => 'Conversas ocultas';

  @override
  String get flowVault1 =>
      'Escolha conversas e grupos para ocultar. Seu PIN abre o Kryfo sem eles. Um PIN das conversas ocultas abre tudo, conversas ocultas incluídas.';

  @override
  String get flowVault2 =>
      'Enquanto estão fora de vista, elas nunca notificam nem mostram contador. As mensagens continuam chegando e esperam, seladas, pelo seu PIN das conversas ocultas.';

  @override
  String get flowVaultFinger =>
      'Sua digital abre o Kryfo sem as conversas ocultas.';

  @override
  String get flowVaultDigits =>
      'Dê também seis dígitos ou mais ao seu PIN, porque quem estiver olhando pode contar os pontos.';

  @override
  String get flowVaultReplace =>
      'Isto substitui qualquer conversa oculta que este celular já tenha.';

  @override
  String get flowVaultChoose => 'Escolha um PIN das conversas ocultas';

  @override
  String get flowVaultChooseLine => 'Seis dígitos ou mais.';

  @override
  String get flowEnterHiddenPinLine => 'O que abre suas conversas ocultas.';

  @override
  String get flowVaultForgetTitle => 'Guarde este PIN';

  @override
  String get flowVaultForget =>
      'Se você esquecer este PIN, suas conversas ocultas somem para sempre. Ninguém consegue recuperá-las, nem mesmo nós.';

  @override
  String get flowVaultForgetOk => 'Entendi';

  @override
  String get flowVaultPickTitle => 'Escolha conversas para ocultar';

  @override
  String get flowVaultPickLine =>
      'Elas saem da sua lista de conversas agora. Seu PIN das conversas ocultas as traz de volta.';

  @override
  String flowVaultPickButton(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ocultar $countString conversas',
      one: 'Ocultar $countString conversa',
      zero: 'Não ocultar nada por enquanto',
    );
    return '$_temp0';
  }

  @override
  String get flowVaultPickEmpty => 'Ainda não há conversas para ocultar.';

  @override
  String get flowVaultBackupTitle => 'Fazer um backup agora?';

  @override
  String get flowVaultBackupLine =>
      'Um backup feito agora guarda também suas conversas ocultas, com uma frase-senha própria. Se você esquecer o PIN das conversas ocultas, ele é o único caminho de volta até elas.';

  @override
  String get flowVaultBackupNow => 'Fazer um backup';

  @override
  String get flowVaultNotNow => 'Agora não';

  @override
  String get flowVaultDone => 'Conversas ocultas configuradas';

  @override
  String get flowVaultDoneLine =>
      'Digite seu PIN das conversas ocultas na tela de bloqueio para vê-las. Troque de app e elas ficam fora de vista de novo.';

  @override
  String get flowVaultChanged => 'PIN das conversas ocultas alterado';

  @override
  String get flowVaultChangedLine =>
      'Suas conversas ocultas abrem com o novo. O antigo não abre mais nada.';

  @override
  String get howVault =>
      'Seu PIN das conversas ocultas abre o Kryfo com as conversas ocultas; seu PIN e sua digital, sem elas. Configurar as conversas ocultas de novo substitui as que este celular tem. Esqueça o PIN das conversas ocultas e elas somem para sempre.';

  @override
  String get chatHide => 'Ocultar conversa';

  @override
  String get groupHide => 'Ocultar grupo';

  @override
  String get chatHidden => 'Oculta';

  @override
  String get chatHiddenToast => 'Oculta da sua lista de conversas';

  @override
  String get chatShowInList => 'Mostrar na lista de conversas';

  @override
  String get stickerOpen => 'Figurinhas';

  @override
  String get stickerRecent => 'Recentes';

  @override
  String stickerA11y(String emoji) {
    return 'Figurinha $emoji';
  }

  @override
  String get stickerRemoveRecent => 'Remover dos recentes';

  @override
  String get stickerCouldNotLoad => 'Não foi possível carregar as figurinhas';

  @override
  String get stickerLabel => 'Figurinha';

  @override
  String get stickerNewer => 'De um Kryfo mais novo';

  @override
  String get devLinkMismatch =>
      'Este link diz que é o Marios, mas a chave dele não corresponde. Não foi adicionado.';

  @override
  String get devName => 'Marios';

  @override
  String get devRowTitle => 'Marios · criou o Kryfo';

  @override
  String get devWelcome =>
      'Oi, eu sou o Marios e faço o Kryfo. Me conte qualquer coisa: bugs, ideias, dúvidas. Eu leio tudo.';

  @override
  String get devPinned => 'Embutido no Kryfo';

  @override
  String get devAnonymous => 'Anônimo';

  @override
  String get devAboutLine =>
      'A chave do Marios vem embutida no Kryfo. Cada mensagem dele é conferida com ela, então ninguém mais consegue escrever como ele.';

  @override
  String get devKeyLabel => 'A chave dele';

  @override
  String get devDeleteLine =>
      'Todas as mensagens somem, e a conversa não volta mais.';

  @override
  String get devDeleteLineAnon =>
      'Todas as mensagens e o nome criado para esta conversa somem, e a conversa não volta mais.';

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
  String get settingsWriteToMarios => 'Escrever para o Marios';

  @override
  String get settingsWriteToMariosHint => 'Bugs, ideias, perguntas';

  @override
  String get seenDevChat => 'A conversa com o Marios';

  @override
  String get seenDevChatCell => 'Se você escrever';

  @override
  String get seenDevChatLine =>
      'Nada até você escrever. Depois, o que você envia, e suas três palavras, a menos que você escreva anonimamente.';

  @override
  String get devWriteAnonymously => 'Escrever anonimamente';

  @override
  String get devUseMyWords => 'Usar minhas três palavras';

  @override
  String get devWhoSeesWhat => 'Como funciona';

  @override
  String get devWhoWords =>
      'Com suas três palavras, é uma conversa como qualquer outra: o Marios pode te responder, e seu rosto e seu selo de apoiador ficam com você.';

  @override
  String get devWhoAnon =>
      'Se você escrever anonimamente, o Kryfo cria um nome e chaves novos só para esta conversa. Eles ficam neste celular e nunca são usados em outro lugar.';

  @override
  String get devWhoNothingYet =>
      'Nada sai do seu celular até você enviar sua primeira mensagem.';

  @override
  String get devWhoChoiceStays =>
      'Sua escolha fica valendo para esta conversa.';

  @override
  String get devKeyCheckFailed =>
      'Não foi possível conferir a chave do Marios. Nada foi enviado.';

  @override
  String get devLockLine =>
      'O Marios vai ler essas mensagens. Você pode escrever mais assim que ele responder.';

  @override
  String get devNewKey => 'O Marios tem uma chave nova';

  @override
  String get devStartNewChat => 'Começar uma nova conversa';

  @override
  String get devKeyRetired =>
      'Esta chave foi desativada. Nada mais pode ser enviado ou recebido aqui.';

  @override
  String get devNamelessLine =>
      'O nome criado para esta conversa fica no celular onde foi criado, então aqui ela só pode ser lida.';

  @override
  String get devStartNewLine =>
      'Todas as mensagens daqui somem, e uma conversa nova se abre.';

  @override
  String get devVoiceDisguised => 'Sua voz vai disfarçada nesta conversa';

  @override
  String get devChatOptions => 'Opções da conversa';

  @override
  String appLinkOtherKey(Object id) {
    return 'Este link diz que é $id, mas a chave dele não corresponde. Não foi adicionado.';
  }

  @override
  String scamShieldSaysItIs(Object shown) {
    return 'Diz que é $shown, mas a chave não corresponde';
  }

  @override
  String get requestsSomeoneNew => 'Alguém novo';

  @override
  String get appYourOwnInvite =>
      'Este é o seu próprio convite. Compartilhe com outra pessoa para se conectar.';

  @override
  String appTheyAreBlocked(Object id) {
    return 'Você bloqueou $id. Desbloqueie em “Bloqueados”, nas Configurações, para adicionar de novo.';
  }

  @override
  String get devLinkGone =>
      'Você apagou a conversa com o Marios. Para começar uma nova, toque em “Escrever para o Marios” nas Configurações.';

  @override
  String lockTooManyTriesFor(Object left) {
    return 'Tentativas demais · $left';
  }
}
