// SPDX-License-Identifier: GPL-3.0-or-later
// the shield against written samples: ordinary messages in every language
// the app speaks must never fire, and scam openers should. the ordinary set
// leans on the words scams use too: codes, money, links, "now", "team".
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/scam_shield.dart';

const _normal = <String>[
  // en
  'hey, sam gave me your kryfo. climbing thursday? bring the rope, i have the quickdraws.',
  "Hi! We met at the conference last week, I'm the one who asked about Tor bridges.",
  "add me on telegram @lena_b, it's easier for photos",
  'Can you send me the code for the website? I want to see how you did the menu.',
  "What's the wifi password at the cabin? Forgot to write it down.",
  "Drop me a pin when you get there, I'll pick you up right away.",
  "Send me your pin when you're at the station and I'll come get you",
  "I'll send you the money for the tickets right away, thanks for covering!",
  'Can you pay me back for the pizza when you get a chance? No hurry.',
  'The concert tickets were \$45 each, I paid with my card.',
  "Never share your seed phrase with anyone, not even me. Just a reminder since you're new to crypto.",
  'My donation address is bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq if you want to support the project.',
  "Here's the issue: https://github.com/kryfo/kryfo/issues/42",
  'Found a nice café in Munich: https://café-münchen.de/menu',
  "Check https://www.amazon.com.au/dp/B08N5WRWNW, it's on sale",
  'apple.co/3xyz has the keynote if you missed it',
  'pay me at paypal.me/lenab for the shared dinner whenever',
  "I'm so busy right now, can you send me the slides tomorrow?",
  "I'm a huge fan of the Kryfo team's work, thanks for the app!",
  'Is this the official Kryfo app? Found it on F-Droid.',
  'The Kryfo support for Tor bridges works great on my phone.',
  'Ok, the booking confirmation code is ABX42, see you at the hotel.',
  'Text me the door code for the building when you can.',
  'My battery drops 20% a day even when idle, is that normal?',
  'Urgent: the meeting moved to 3pm, room 204.',
  'I need cash for the farmers market tomorrow, is there an ATM near you?',
  'lol telegram is down again',
  "I'm the new neighbour from 4B, your package ended up at my door.",
  'Can I get your number? My Kryfo keeps disconnecting.',
  'This is Anna from the climbing gym, we spoke about the route setting job.',
  "I'm from the support group at the community center, we meet on Fridays.",
  'Hi from the Google Developer Group meetup! Here are the slides.',
  "We are the support act for tonight's show, see you backstage.",
  'Your account was hacked? I got a weird message from you on Instagram.',
  "I paid the deposit for the flat today, so we're all set.",
  'Can you lend me your bike tomorrow?',
  'Bitcoin is up 5% today, crazy.',
  'Let me know if you want to split the Uber, it was 23 euros.',
  'Please forward me the PDF of the contract asap.',
  'Send me the recipe asap, dinner is in an hour!',
  'Guaranteed to be a fun hike, bring water.',
  'We need cash right away for the party, can you bring some?',
  'My recovery from the surgery is going well, thanks for asking.',
  "Do you know how to set a PIN on Kryfo? I can't find it.",
  'I forgot my password again lol, had to reset the app.',
  "Can you share the verification step from the docs? I'm stuck at the QR part.",
  'You can verify your identity at the town hall with your passport.',
  'Send me 5 bucks for the coffee, no rush',
  'Is this the Kryfo team? I wanted to report a bug with voice notes.',
  'The private key stays on your phone, that is the whole point of Kryfo.',
  'Read me the riot act later, I know I was late lol',
  'Hello! Your talk on privacy was great. Do you have the slides?',
  'I can transfer the deposit right now if that works for the landlord.',
  // es
  'Hola, soy Marta, amiga de Lucía. ¿Quedamos el sábado para escalar?',
  '¿Me pasas la receta de la tortilla? La quiero hacer ya mismo.',
  'Te mando el dinero de las entradas ahora mismo, gracias.',
  'El equipo de Kryfo hizo un gran trabajo con la nueva versión.',
  'Nunca compartas tu frase semilla con nadie.',
  '¿Cuál es la contraseña del wifi?',
  'Es urgente: la reunión se mueve al martes.',
  'Te debo 20 euros, te los paso mañana.',
  'Mírate este enlace: https://www.paypal.com/es/home',
  'Me encantó tu charla sobre privacidad, ¿tienes las diapositivas?',
  // pt
  'Oi, sou o Pedro, primo da Ana. Vamos jogar futebol no domingo?',
  'Me passa o link da reunião, por favor?',
  'Eu te mando o dinheiro do aluguel agora mesmo.',
  'Nunca compartilhe sua senha com ninguém.',
  'Qual é a senha do wifi da casa?',
  'Não é urgente, mas me manda as fotos da viagem quando puder.',
  'Fiz um pix de 30 reais pra você ontem.',
  'A equipe do Kryfo está de parabéns pelo app.',
  // fr
  "Salut, c'est Julie, on s'est vues au marché samedi.",
  "Je t'envoie l'argent du resto tout de suite.",
  'Ne donnez jamais votre mot de passe à personne.',
  "C'est urgent : le train est annulé, on se retrouve à la gare.",
  "Tu peux m'envoyer le code source du projet ?",
  "Quel est le code de la porte de l'immeuble ?",
  "Merci pour l'appli, l'équipe Kryfo fait du super boulot.",
  "J'ai payé la caution aujourd'hui.",
  // de
  'Hallo, ich bin Jonas aus dem Kletterkurs. Hast du am Donnerstag Zeit?',
  'Ich überweise dir das Geld sofort, danke fürs Auslegen!',
  'Gib niemals dein Passwort weiter.',
  'Ist das der offizielle Kryfo-Account?',
  'Dringend: Bitte ruf mich zurück, es geht um das Auto.',
  'Kannst du mir den Link zur Wohnung schicken?',
  'Wie lautet das WLAN-Passwort?',
  'Ich hab dir gestern 20 € geschickt.',
  'Ich kann dir morgen die 50 € überweisen, kein Stress.',
  // it
  "Ciao, sono Marco, l'amico di Giulia. Ci vediamo sabato?",
  'Ti mando subito i soldi della cena.',
  'Non condividere mai la tua password con nessuno.',
  'Il team di Kryfo ha fatto un ottimo lavoro.',
  'Mi mandi le foto della gita?',
  'È urgente, il volo è stato cancellato.',
  'Qual è la password del wifi?',
  'Ho pagato la caparra oggi.',
  // ru
  'Привет, это Лена из бассейна, мы вчера говорили про тренера.',
  'Скинь, пожалуйста, фотки с похода.',
  'Никогда никому не говори код из смс.',
  'Переведу тебе деньги прямо сейчас, спасибо!',
  'Это команда Kryfo выпустила новую версию? Классно.',
  'Срочно нужно перенести встречу на завтра.',
  'Сколько стоит билет? Я заплачу сразу.',
  'Какой пароль от вайфая?',
  'Спасибо команде Kryfo за приложение!',
  'Мне нужны деньги на подарок маме, подскажешь идею?',
  // uk
  'Привіт, це Оля з курсів англійської.',
  'Скинь, будь ласка, адресу кафе.',
  "Терміново: зустріч перенесли на п'ятницю.",
  'Ніколи не надсилай нікому свій пароль.',
  'Дякую команді Kryfo за чудовий застосунок.',
  'Я переведу тобі гроші ввечері.',
  // tr
  "Merhaba, ben Ayşe, Can'ın arkadaşıyım. Cumartesi buluşalım mı?",
  'Parayı hemen gönderiyorum, teşekkürler!',
  'Şifreni kimseyle paylaşma.',
  'Acil değil ama fotoğrafları atar mısın?',
  'Kryfo ekibine teşekkürler, uygulama harika.',
  'Wi-Fi şifresi ne?',
  // id
  'Halo, aku Rina, temannya Dewi. Sabtu jadi naik gunung?',
  'Aku tf sekarang ya uangnya, makasih!',
  'Jangan pernah kasih kode OTP ke siapa pun.',
  'Tim Kryfo keren banget, aplikasinya lancar.',
  'Kirim foto liburan kemarin dong.',
  'Segera ya, rapatnya dimajukan jam 2.',
  // vi
  'Chào bạn, mình là Lan, bạn của Hùng. Cuối tuần đi cà phê không?',
  'Mình chuyển tiền cho bạn ngay bây giờ nhé.',
  'Đừng bao giờ chia sẻ mật khẩu của bạn cho ai.',
  'Đội ngũ Kryfo làm tốt lắm.',
  'Gửi mình ảnh chuyến đi nhé.',
  'Gấp: mai họp lúc 8 giờ.',
  // zh
  '你好，我是小林，莉莉的朋友。周六一起爬山吗？',
  '我马上转账给你，谢谢请客！',
  '千万不要把验证码告诉任何人。',
  'Kryfo团队做得真好。',
  '把会议链接发给我吧。',
  '紧急：明天的航班取消了。',
  // zh_Hant
  '你好，我是阿明，週末要不要一起吃飯？',
  '千萬不要把驗證碼給別人。',
  // ar
  'مرحبا، أنا سارة صديقة ليلى. هل نلتقي يوم السبت؟',
  'سأحول لك المبلغ حالا، شكرا!',
  'لا تشارك كلمة المرور مع أي أحد.',
  'فريق Kryfo رائع، شكرا على التطبيق.',
  'عاجل: تم تأجيل الاجتماع إلى الغد.',
  // fa
  'سلام، من مریم هستم، دوست سارا. شنبه همدیگر را ببینیم؟',
  'پول را همین الان برایت واریز می‌کنم.',
  'رمز عبور را به هیچ‌کس نگو.',
  'تیم Kryfo عالی است.',
  'فوری: جلسه به فردا منتقل شد.',
];

const _scam = <String>[
  // en
  'Hello, this is the Kryfo Support Team. We detected unusual activity. Please send us the 6-digit code you just received to keep your account active.',
  "Hi mum, I lost my phone, this is my new number. Can you send me £450 urgently for the rent? I'll pay you back tomorrow.",
  'Your Kryfo account will be suspended within 24 hours unless you verify it at kryfo-app.com/verify',
  'Verify your wallet here: https://metamask-io.com/restore and enter your 12 words',
  'Someone tried to log in to your account. Reply with the verification code we sent to confirm it is you.',
  'I accidentally sent my WhatsApp code to your number, can you forward it to me please?',
  "Congratulations! You've been selected for our crypto program with guaranteed returns of 30% weekly. Deposit 0.05 BTC to 1BvBMSEYstWetqTFn5Au4m4GFg7xJaNVN2 to start.",
  'Double your bitcoin in 24 hours! Send any amount to bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq and get 2x back. Offer expires today.',
  'Your package is held at customs. Pay the \$2.99 release fee within 12 hours: https://dhl-parcel-track.info',
  'URGENT: your bank account has been locked. Confirm your account at https://secure-login-paypa1.com',
  "Hey, it's Kevin from work, I'm stuck abroad and need help. Can you buy me two \$100 Steam gift cards right now and send me the codes?",
  'Hi dear, I am a crypto trader making 5% daily profit. Let me teach you, risk-free investment.',
  'This is Binance customer support. Your withdrawal is on hold, please share your 2FA code.',
  'Official notice from Kryfo Security: your keys expired. Tap kryfo.app.security-check.ru to renew.',
  "I'm from the Kryfo team, we need your recovery phrase to move your chats to the new server.",
  'send me your seed phrase so I can sync your wallet',
  'Please send 500 USDT to TQ5Nw8bK7pX2mVfJr9hLcYd3aE6uGs4WzR immediately, the opportunity closes soon',
  'Hello, I am from Telegram security team. Tell me the login code you got by SMS.',
  'Login at https://g00gle.com/security to keep your account',
  'Your Apple ID is locked. Unlock it at https://appleid.apple.com.verify-id.co',
  'Grandma it is me, I had an accident. Please wire 2000 dollars to the hospital right now.',
  'Kryfo Support: we noticed a login from a new device. What is the 6 digit code we sent?',
  // es
  'Hola, somos el equipo de soporte de Kryfo. Envíanos el código de verificación que te llegó por SMS.',
  'Mamá, perdí el móvil. Necesito que me hagas un bizum de 300 euros urgente, luego te explico.',
  'Tu cuenta será suspendida en 24 horas. Verifica tu cuenta aquí: https://kryfo-verificar.com',
  'Ganancias garantizadas del 20% semanal invirtiendo en cripto conmigo.',
  // pt
  'Oi, aqui é do suporte do Kryfo. Me passa o código de verificação que chegou no seu celular.',
  'Mãe, troquei de número. Preciso de 800 reais agora mesmo, faz um pix pra mim?',
  'Lucro garantido de 5% ao dia, me chama que te explico.',
  // fr
  'Bonjour, ici le service client de Kryfo. Communiquez-nous le code de vérification reçu par SMS.',
  "Maman, c'est moi, j'ai cassé mon téléphone. Envoie-moi 400 euros en urgence s'il te plaît.",
  'Votre compte sera suspendu sous 24h, vérifiez votre compte ici.',
  // de
  'Hallo, hier ist das Kryfo Support-Team. Bitte nenne uns den Bestätigungscode aus der SMS.',
  'Hallo Papa, mein Handy ist kaputt. Kannst du mir dringend 500 € überweisen?',
  'Garantierte Rendite von 10% pro Woche, nur heute!',
  // it
  'Ciao, sono del team di sicurezza di Kryfo. Dimmi il codice di verifica che hai ricevuto.',
  'Mamma, ho cambiato numero. Mi serve che mi fai un bonifico di 600 euro urgentemente.',
  'Guadagni garantiti con il trading, raddoppia il tuo investimento in una settimana.',
  // ru
  'Здравствуйте, вас беспокоит служба безопасности Kryfo. Продиктуйте код из СМС для подтверждения.',
  'Мам, это я, у меня новый номер. Срочно переведи 15000 рублей на карту, потом объясню.',
  'Ваш аккаунт будет заблокирован. Подтвердите личность по ссылке.',
  'Гарантированный доход от 3% в день, пиши.',
  // uk
  'Вітаємо, це служба підтримки Kryfo. Надішліть код підтвердження з SMS.',
  'Мамо, терміново переведи 5000 грн на цю карту.',
  // tr
  'Merhaba, biz Kryfo destek ekibiyiz. Telefonunuza gelen doğrulama kodunu söyler misiniz?',
  'Anne numaram değişti, acil 2000 TL lazım, hemen gönderebilir misin?',
  'Garantili kazanç! Günlük %5 getiri.',
  // id
  'Halo, kami dari tim dukungan Kryfo. Mohon kirimkan kode OTP yang masuk ke HP Anda.',
  'Bu, ini aku, HP-ku hilang. Tolong transfer 2 juta sekarang juga, darurat.',
  'Akun Anda akan diblokir, verifikasi akun Anda segera.',
  // vi
  'Xin chào, chúng tôi là đội ngũ hỗ trợ Kryfo. Vui lòng gửi mã OTP vừa nhận được.',
  'Mẹ ơi con mất điện thoại, chuyển gấp cho con 5 triệu nhé.',
  'Lợi nhuận đảm bảo, lãi 3% mỗi ngày.',
  // zh
  '您好，这里是Kryfo官方客服。请把收到的验证码发给我们。',
  '妈，我手机丢了，急需转账5000元，马上转给我。',
  '稳赚不赔，日收益10%，带你投资。',
  // ar
  'مرحبا، معك فريق الدعم في Kryfo. أرسل لي رمز التحقق الذي وصلك.',
  'أمي، هاتفي ضاع. أرسل لي 500 دولار فورا من فضلك.',
  'ربح مضمون يوميا، استثمر معنا.',
  // fa
  'سلام، اینجا تیم پشتیبانی Kryfo است. کد تایید را بفرستید.',
  'مامان گوشیم گم شد، فوری ۵ میلیون تومان کارت به کارت کن.',
  'سود تضمینی روزانه، همین الان سرمایه‌گذاری کن.',
];

// scams these rules let through: nothing in them is sure on its own
const _missed = <String>[
  // a warm opener that asks for nothing yet
  "Hi, sorry, wrong number? You look like my friend's cousin. Where are you from?",
  // romance: no money, no code, no link in the first message
  'Hello dear, I saw your profile and felt we have a connection. I am a doctor on a UN mission.',
  // a task "job" with no promise worded as one
  'We are hiring remote workers, earn 300 a day liking videos. Interested?',
];

// a second set, written after the first one passed
const _normalLater = <String>[
  'Could you send me the money for the Airbnb by Friday? The host wants it before check-in.',
  'Hurry up, the movie starts in 10 minutes!',
  "I need 20 dollars for the taxi, I'll pay you back tonight",
  'What is your Kryfo ID? Mine is amber-fox-river.',
  'Tell me the code word for the surprise party lol',
  'Our team at Signal Hill Coffee says hi!',
  'I am on the Apple support forum and found a fix for your issue',
  'This is the support team schedule for next week: Mon Anna, Tue Ben.',
  'We are the Google team from the hackathon, want to join?',
  "Emergency at work, can't make it tonight, sorry!",
  "Send me your address and I'll mail the book.",
  'Can you share your screen? The PIN pad on my app looks weird.',
  'My bank sent me a verification code but it expired, so annoying.',
  "Don't forget to bring cash for the parking, it's urgent they only take coins.",
  "I'll transfer you the rent immediately after payday.",
  'Do you want to buy a gift card for Tom together? His birthday is tomorrow.',
  'The seed phrase backup feature in my wallet is confusing, how do you store yours?',
  'Reply with your availability for the meeting asap.',
  'Paypal fees are crazy, use Wise next time.',
  'Look at this: https://signal.org/blog/',
  'lol my cousin works on the WhatsApp team in London',
  '¿Me puedes enviar las fotos ahora mismo? Las necesito para la presentación.',
  'Necesito 50 euros para el regalo de Ana, ¿pones tu parte?',
  'Soy del equipo de fútbol del barrio, ¿te apuntas?',
  'Preciso de ajuda urgente com a mudança, você pode vir?',
  'Sou da equipe de marketing da empresa, prazer!',
  "Je suis de l'équipe de foot du quartier, tu viens jouer ?",
  "Envoie-moi l'adresse tout de suite, je suis perdu.",
  'Wir sind das Support-Team vom Sportverein, Training ist morgen um 18 Uhr.',
  'Schick mir bitte sofort die Fotos!',
  "Mandami subito il numero dell'idraulico, è un'emergenza.",
  'Siamo il team di assistenza del condominio.',
  'Срочно скинь фото с праздника, бабушка ждёт.',
  'Это поддержка нашего клуба, напоминаем про тренировку.',
  'Нужны деньги на подарок учительнице срочно, скидываемся по 500?',
  'Терміново потрібна допомога з переїздом у суботу.',
  'Acil, toplantı yarına ertelendi, haber verir misin?',
  'Butuh uang buat beli kado, patungan yuk.',
  'Mình cần gấp file báo cáo, gửi giúp mình nhé.',
  '我需要马上回家，明天再聊。',
  '我们是公司的技术支持团队，下周升级系统。',
  'أحتاج المساعدة في نقل الأثاث غدا.',
  'پول ناهار را فردا می‌دهم.',
];

const _scamLater = <String>[
  'Dear user, your Kryfo wallet will be frozen today. Validate your wallet at kryfo-secure.net',
  'Hi, Kryfo admin here. We need you to confirm your recovery words.',
  'Send 0.2 ETH to 0x52908400098527886E0F7030069857D2E4169EE7 within 1 hour to claim your airdrop.',
  "I'm stuck at the airport, please send me 300 euros right away via Western Union.",
  'Earn guaranteed profits daily with our trading bot!',
  'Hello from Coinbase Support. To restore access, tell us your seed phrase.',
  'Can you read me the code that just came to your phone? I typed your number by mistake.',
  'Привет! Это служба поддержки Kryfo, ваш аккаунт будет заблокирован. Сообщите код из СМС.',
  'Hola, te escribe el equipo de seguridad de Binance. Envíanos tu frase semilla para verificar.',
  'Bonjour, vous avez gagné ! Payez 2 € de frais immédiatement pour recevoir le colis.',
];

void main() {
  test('ordinary messages never fire', () {
    final fired = [
      for (final m in _normal)
        if (scanRequest(m).flagged)
          '${scanRequest(m).hits.map((h) => h.code).join(',')}: $m',
    ];
    // ignore: avoid_print
    print('ordinary: ${_normal.length} samples, ${fired.length} fired');
    expect(fired, isEmpty);
    expect(_normal.length, greaterThanOrEqualTo(100));
  });

  test('a second set', () {
    final fired = [
      for (final m in _normalLater)
        if (scanRequest(m).flagged)
          '${scanRequest(m).hits.map((h) => h.code).join(',')}: $m',
    ];
    final quiet = [
      for (final m in _scamLater)
        if (!scanRequest(m).flagged) m,
    ];
    // ignore: avoid_print
    print(
      'second set: ordinary ${_normalLater.length}, ${fired.length} fired; '
      'scams ${_scamLater.length}, ${_scamLater.length - quiet.length} caught',
    );
    for (final f in [...fired, ...quiet]) {
      // ignore: avoid_print
      print('  $f');
    }
    expect(fired, isEmpty);
  });

  test('scam openers fire', () {
    final quiet = [
      for (final m in _scam)
        if (!scanRequest(m).flagged) m,
    ];
    final missed = [
      for (final m in _missed)
        if (!scanRequest(m).flagged) m,
    ];
    final all = _scam.length + _missed.length;
    // ignore: avoid_print
    print(
      'scams: ${all - quiet.length - missed.length} of $all caught, '
      '${quiet.length + missed.length} missed',
    );
    expect(quiet, isEmpty);
    expect(missed, _missed);
  });
}
