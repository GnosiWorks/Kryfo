// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"net/http"
	"sort"
	"strconv"
	"strings"
)

// the pages' words in the app's sixteen languages, with the app's wording
// where the two say the same thing
type pageText struct {
	Title       string // the invite page and its preview card
	Line        string
	Open        string
	Missing     string
	NoScript    string
	NewTo       string
	Download    string
	FDroid      string
	Play        string
	Foot        string
	Verified    string
	Fingerprint string
	Busy        string
	BusyLine    string
}

var pageTexts = map[string]pageText{
	"en": {
		Title:       "Message me on Kryfo",
		Line:        "Private messenger, no phone number, open source",
		Open:        "Open in Kryfo",
		Missing:     "This link is missing a part. Ask for a new invite, or get Kryfo below.",
		NoScript:    "Copy this page's link and paste it into Kryfo.",
		NewTo:       "New to Kryfo? It is on Android for now.",
		Download:    "Download from kryfo.app",
		FDroid:      "Get it on F-Droid",
		Play:        "Get it on Google Play",
		Foot:        "This page learns nothing about you · No analytics, no cookies, no logs",
		Verified:    "Verified handle",
		Fingerprint: "Key fingerprint",
		Busy:        "Busy",
		BusyLine:    "Too many people are looking right now. Try again in a minute.",
	},
	"ar": {
		Title:       "راسلني على Kryfo",
		Line:        "تطبيق مراسلة خاص، بلا رقم هاتف، مفتوح المصدر",
		Open:        "افتح في Kryfo",
		Missing:     "هذا الرابط ناقص. اطلب دعوة جديدة، أو احصل على Kryfo من الأسفل.",
		NoScript:    "انسخ رابط هذه الصفحة والصقه في Kryfo.",
		NewTo:       "جديد على Kryfo؟ متوفر على Android حاليًا.",
		Download:    "نزّل من kryfo.app",
		FDroid:      "احصل عليه من F-Droid",
		Play:        "احصل عليه من Google Play",
		Foot:        "هذه الصفحة لا تعرف عنك شيئًا · بلا تحليلات، بلا ملفات تعريف ارتباط، بلا سجلات",
		Verified:    "اسم مستخدم موثّق",
		Fingerprint: "بصمة المفتاح",
		Busy:        "مشغول",
		BusyLine:    "يتصفح عدد كبير من الناس الآن. حاول مجددًا بعد دقيقة.",
	},
	"de": {
		Title:       "Schreib mir auf Kryfo",
		Line:        "Privater Messenger, ohne Telefonnummer, Open Source",
		Open:        "In Kryfo öffnen",
		Missing:     "Diesem Link fehlt ein Teil. Bitte um eine neue Einladung oder hol dir Kryfo unten.",
		NoScript:    "Kopiere den Link dieser Seite und füge ihn in Kryfo ein.",
		NewTo:       "Neu bei Kryfo? Kryfo gibt es vorerst für Android.",
		Download:    "Von kryfo.app herunterladen",
		FDroid:      "Jetzt bei F-Droid",
		Play:        "Jetzt bei Google Play",
		Foot:        "Diese Seite erfährt nichts über dich · Keine Analyse, keine Cookies, keine Logs",
		Verified:    "Bestätigter Benutzername",
		Fingerprint: "Schlüssel-Fingerabdruck",
		Busy:        "Gerade viel los",
		BusyLine:    "Gerade schauen zu viele Leute nach. Versuch es in einer Minute noch mal.",
	},
	"es": {
		Title:       "Escríbeme en Kryfo",
		Line:        "Mensajería privada, sin número de teléfono, de código abierto",
		Open:        "Abrir en Kryfo",
		Missing:     "A este enlace le falta una parte. Pide una invitación nueva o consigue Kryfo abajo.",
		NoScript:    "Copia el enlace de esta página y pégalo en Kryfo.",
		NewTo:       "¿Nuevo en Kryfo? Por ahora está en Android.",
		Download:    "Descargar desde kryfo.app",
		FDroid:      "Disponible en F-Droid",
		Play:        "Disponible en Google Play",
		Foot:        "Esta página no sabe nada de ti · Sin analíticas, sin cookies, sin registros",
		Verified:    "Nombre de usuario verificado",
		Fingerprint: "Huella de la clave",
		Busy:        "Ocupado",
		BusyLine:    "Hay demasiada gente mirando ahora mismo. Vuelve a intentarlo en un minuto.",
	},
	"fa": {
		Title:       "در Kryfo به من پیام دهید",
		Line:        "پیام‌رسان خصوصی، بدون شماره تلفن، متن‌باز",
		Open:        "باز کردن در Kryfo",
		Missing:     "این پیوند کامل نیست. یک دعوت تازه بخواهید، یا Kryfo را از پایین دریافت کنید.",
		NoScript:    "پیوند این صفحه را کپی کنید و در Kryfo بچسبانید.",
		NewTo:       "با Kryfo تازه آشنا شده‌اید؟ فعلاً برای Android است.",
		Download:    "دانلود از kryfo.app",
		FDroid:      "دریافت از F-Droid",
		Play:        "دریافت از Google Play",
		Foot:        "این صفحه چیزی درباره‌ی شما نمی‌فهمد · بدون آمارگیری، بدون کوکی، بدون گزارش",
		Verified:    "نام کاربری تأییدشده",
		Fingerprint: "اثر انگشت کلید",
		Busy:        "شلوغ است",
		BusyLine:    "الان افراد زیادی در حال جست‌وجو هستند. یک دقیقه‌ی دیگر دوباره امتحان کنید.",
	},
	"fr": {
		Title:       "Écrivez-moi sur Kryfo",
		Line:        "Messagerie privée, sans numéro de téléphone, open source",
		Open:        "Ouvrir dans Kryfo",
		Missing:     "Il manque une partie de ce lien. Demandez une nouvelle invitation, ou installez Kryfo ci-dessous.",
		NoScript:    "Copiez le lien de cette page et collez-le dans Kryfo.",
		NewTo:       "Nouveau sur Kryfo ? Il est sur Android pour l’instant.",
		Download:    "Télécharger sur kryfo.app",
		FDroid:      "Disponible sur F-Droid",
		Play:        "Disponible sur Google Play",
		Foot:        "Cette page n’apprend rien sur vous · Pas de statistiques, pas de cookies, pas de journaux",
		Verified:    "Pseudo vérifié",
		Fingerprint: "Empreinte de la clé",
		Busy:        "Occupé",
		BusyLine:    "Trop de monde consulte cette page en ce moment. Réessayez dans une minute.",
	},
	"hi": {
		Title:       "Kryfo पर मुझे मैसेज करें",
		Line:        "निजी मैसेंजर, बिना फ़ोन नंबर, ओपन सोर्स",
		Open:        "Kryfo में खोलें",
		Missing:     "इस लिंक का एक हिस्सा छूट गया है। नया लिंक माँगें, या नीचे से Kryfo पाएँ।",
		NoScript:    "इस पेज का लिंक कॉपी करें और उसे Kryfo में पेस्ट करें।",
		NewTo:       "Kryfo पर नए हैं? अभी यह Android पर है।",
		Download:    "kryfo.app से डाउनलोड करें",
		FDroid:      "F-Droid पर पाएँ",
		Play:        "Google Play पर पाएँ",
		Foot:        "यह पेज आपके बारे में कुछ नहीं जानता · न एनालिटिक्स, न कुकीज़, न लॉग",
		Verified:    "पुष्टि किया हुआ यूज़रनेम",
		Fingerprint: "कुंजी फ़िंगरप्रिंट",
		Busy:        "व्यस्त",
		BusyLine:    "अभी बहुत सारे लोग देख रहे हैं। एक मिनट में फिर कोशिश करें।",
	},
	"id": {
		Title:       "Kirimi aku pesan di Kryfo",
		Line:        "Aplikasi pesan privat, tanpa nomor telepon, sumber terbuka",
		Open:        "Buka di Kryfo",
		Missing:     "Tautan ini kurang satu bagian. Minta undangan baru, atau dapatkan Kryfo di bawah.",
		NoScript:    "Salin tautan halaman ini lalu tempelkan di Kryfo.",
		NewTo:       "Baru kenal Kryfo? Untuk saat ini ada di Android.",
		Download:    "Unduh dari kryfo.app",
		FDroid:      "Dapatkan di F-Droid",
		Play:        "Dapatkan di Google Play",
		Foot:        "Halaman ini tidak mengetahui apa pun tentangmu · Tanpa analitik, tanpa cookie, tanpa log",
		Verified:    "Nama pengguna terverifikasi",
		Fingerprint: "Sidik kunci",
		Busy:        "Sibuk",
		BusyLine:    "Terlalu banyak orang yang melihat sekarang. Coba lagi dalam semenit.",
	},
	"it": {
		Title:       "Scrivimi su Kryfo",
		Line:        "Messenger privato, senza numero di telefono, open source",
		Open:        "Apri in Kryfo",
		Missing:     "A questo link manca una parte. Chiedi un nuovo invito, oppure scarica Kryfo qui sotto.",
		NoScript:    "Copia il link di questa pagina e incollalo in Kryfo.",
		NewTo:       "Nuovo su Kryfo? Per ora è su Android.",
		Download:    "Scarica da kryfo.app",
		FDroid:      "Disponibile su F-Droid",
		Play:        "Disponibile su Google Play",
		Foot:        "Questa pagina non sa nulla di te · Niente analisi, niente cookie, niente log",
		Verified:    "Nome utente verificato",
		Fingerprint: "Impronta della chiave",
		Busy:        "Occupato",
		BusyLine:    "Troppe persone stanno guardando ora. Riprova tra un minuto.",
	},
	"pt": {
		Title:       "Fale comigo no Kryfo",
		Line:        "Mensageiro privado, sem número de telefone, código aberto",
		Open:        "Abrir no Kryfo",
		Missing:     "Falta uma parte deste link. Peça um novo convite ou baixe o Kryfo abaixo.",
		NoScript:    "Copie o link desta página e cole no Kryfo.",
		NewTo:       "Novo no Kryfo? Por enquanto ele está no Android.",
		Download:    "Baixar em kryfo.app",
		FDroid:      "Disponível no F-Droid",
		Play:        "Disponível no Google Play",
		Foot:        "Esta página não sabe nada sobre você · Sem análises, sem cookies, sem registros",
		Verified:    "Nome de usuário verificado",
		Fingerprint: "Impressão digital da chave",
		Busy:        "Ocupado",
		BusyLine:    "Muitas pessoas estão olhando agora. Tente de novo em um minuto.",
	},
	"ru": {
		Title:       "Пиши мне в Kryfo",
		Line:        "Приватный мессенджер, без номера телефона, с открытым кодом",
		Open:        "Открыть в Kryfo",
		Missing:     "В этой ссылке не хватает части. Попроси новое приглашение или установи Kryfo ниже.",
		NoScript:    "Скопируй ссылку на эту страницу и вставь её в Kryfo.",
		NewTo:       "Впервые слышишь о Kryfo? Пока он есть на Android.",
		Download:    "Скачать с kryfo.app",
		FDroid:      "Доступно в F-Droid",
		Play:        "Доступно в Google Play",
		Foot:        "Эта страница ничего о тебе не узнаёт · Без аналитики, без cookie, без логов",
		Verified:    "Подтверждённое имя пользователя",
		Fingerprint: "Отпечаток ключа",
		Busy:        "Занято",
		BusyLine:    "Сейчас слишком много запросов. Попробуй ещё раз через минуту.",
	},
	"tr": {
		Title:       "Bana Kryfo’dan yaz",
		Line:        "Gizli mesajlaşma uygulaması, telefon numarası gerekmez, açık kaynak",
		Open:        "Kryfo’da aç",
		Missing:     "Bu bağlantının bir parçası eksik. Yeni bir davet iste ya da Kryfo’yu aşağıdan edin.",
		NoScript:    "Bu sayfanın bağlantısını kopyala ve Kryfo’ya yapıştır.",
		NewTo:       "Kryfo’da yeni misin? Şimdilik Android’de.",
		Download:    "kryfo.app’ten indir",
		FDroid:      "F-Droid’den edin",
		Play:        "Google Play’den edin",
		Foot:        "Bu sayfa senin hakkında hiçbir şey öğrenmez · Analiz yok, çerez yok, kayıt yok",
		Verified:    "Doğrulanmış kullanıcı adı",
		Fingerprint: "Anahtar parmak izi",
		Busy:        "Yoğun",
		BusyLine:    "Şu anda çok fazla kişi bakıyor. Bir dakika sonra tekrar dene.",
	},
	"uk": {
		Title:       "Напиши мені в Kryfo",
		Line:        "Приватний месенджер, без номера телефону, з відкритим кодом",
		Open:        "Відкрити в Kryfo",
		Missing:     "У цьому посиланні бракує частини. Попроси нове запрошення або встанови Kryfo нижче.",
		NoScript:    "Скопіюй посилання на цю сторінку й встав його в Kryfo.",
		NewTo:       "Вперше чуєш про Kryfo? Поки що він є на Android.",
		Download:    "Завантажити з kryfo.app",
		FDroid:      "Доступно в F-Droid",
		Play:        "Доступно в Google Play",
		Foot:        "Ця сторінка нічого про тебе не дізнається · Без аналітики, без cookie, без журналів",
		Verified:    "Підтверджене ім’я користувача",
		Fingerprint: "Відбиток ключа",
		Busy:        "Зайнято",
		BusyLine:    "Зараз забагато запитів. Спробуй ще раз за хвилину.",
	},
	"vi": {
		Title:       "Nhắn tôi trên Kryfo",
		Line:        "Ứng dụng nhắn tin riêng tư, không cần số điện thoại, mã nguồn mở",
		Open:        "Mở trong Kryfo",
		Missing:     "Liên kết này bị thiếu một phần. Hãy xin lời mời mới, hoặc tải Kryfo ở bên dưới.",
		NoScript:    "Sao chép liên kết của trang này rồi dán vào Kryfo.",
		NewTo:       "Mới biết đến Kryfo? Hiện Kryfo có trên Android.",
		Download:    "Tải từ kryfo.app",
		FDroid:      "Tải trên F-Droid",
		Play:        "Tải trên Google Play",
		Foot:        "Trang này không biết gì về bạn · Không phân tích, không cookie, không nhật ký",
		Verified:    "Tên người dùng đã xác minh",
		Fingerprint: "Dấu vân tay khóa",
		Busy:        "Đang bận",
		BusyLine:    "Hiện có quá nhiều người đang xem. Thử lại sau một phút.",
	},
	"zh": {
		Title:       "在 Kryfo 上给我发消息",
		Line:        "私密通讯应用，不用手机号，开源",
		Open:        "在 Kryfo 中打开",
		Missing:     "这个链接缺了一部分。请对方重新发一个邀请，或在下方获取 Kryfo。",
		NoScript:    "复制这个页面的链接，粘贴到 Kryfo 里。",
		NewTo:       "第一次用 Kryfo？目前只有 Android 版。",
		Download:    "从 kryfo.app 下载",
		FDroid:      "在 F-Droid 获取",
		Play:        "在 Google Play 获取",
		Foot:        "这个页面对你一无所知 · 没有统计，没有 Cookie，没有日志",
		Verified:    "已验证的用户名",
		Fingerprint: "密钥指纹",
		Busy:        "繁忙",
		BusyLine:    "现在查看的人太多了。请一分钟后再试。",
	},
	"zh_Hant": {
		Title:       "在 Kryfo 傳訊息給我",
		Line:        "私密通訊軟體，不需要手機號碼，開放原始碼",
		Open:        "在 Kryfo 中開啟",
		Missing:     "這個連結缺了一部分。請對方重新傳一個邀請，或在下方下載 Kryfo。",
		NoScript:    "複製這個頁面的連結，貼到 Kryfo 裡。",
		NewTo:       "第一次用 Kryfo？目前只有 Android 版。",
		Download:    "從 kryfo.app 下載",
		FDroid:      "在 F-Droid 取得",
		Play:        "在 Google Play 取得",
		Foot:        "這個頁面對你一無所知 · 沒有統計，沒有 Cookie，沒有紀錄",
		Verified:    "已驗證的使用者名稱",
		Fingerprint: "金鑰指紋",
		Busy:        "忙碌中",
		BusyLine:    "現在查看的人太多了。請一分鐘後再試。",
	},
}

// the visitor's language from Accept-Language: the first of theirs, by
// weight, that the app has. english for anything else
func pageLang(r *http.Request) string {
	type tag struct {
		lang string
		q    float64
	}
	var tags []tag
	for _, part := range strings.Split(r.Header.Get("Accept-Language"), ",") {
		name, params, _ := strings.Cut(strings.TrimSpace(part), ";")
		q := 1.0
		if v, ok := strings.CutPrefix(strings.TrimSpace(params), "q="); ok {
			f, err := strconv.ParseFloat(v, 64)
			if err != nil {
				continue
			}
			q = f
		}
		if l := appLang(name); l != "" && q > 0 {
			tags = append(tags, tag{l, q})
		}
	}
	sort.SliceStable(tags, func(i, j int) bool { return tags[i].q > tags[j].q })
	if len(tags) == 0 {
		return "en"
	}
	return tags[0].lang
}

// a language tag as the app names its languages, or "" when it has none
func appLang(tag string) string {
	t := strings.ToLower(strings.ReplaceAll(strings.TrimSpace(tag), "_", "-"))
	primary, rest, _ := strings.Cut(t, "-")
	if primary == "zh" {
		for _, s := range strings.Split(rest, "-") {
			switch s {
			case "hant", "tw", "hk", "mo":
				return "zh_Hant"
			}
		}
		return "zh"
	}
	if _, ok := pageTexts[primary]; ok {
		return primary
	}
	return ""
}

// the html lang and dir of a page in [lang]
func langAttrs(lang string) string {
	s := "lang=" + strings.ReplaceAll(lang, "_", "-")
	if lang == "ar" || lang == "fa" {
		s += " dir=rtl"
	}
	return s
}

// kryfo.app's download page in [lang], as the app's downloadPageFor
func downloadPage(lang string) string {
	switch lang {
	case "zh_Hant":
		return "https://kryfo.app/zh-hant/download"
	case "en", "hi":
		return "https://kryfo.app/download"
	}
	return "https://kryfo.app/" + lang + "/download"
}
