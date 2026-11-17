-- "addons\\sardonmatbaa\\lua\\sardon_matbaa\\sh_config.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Matbaa ayarları. Sunucu ve istemci aynı dosyayı okur (sh_), maliyet/URL kontrolü
-- sunucuda yeniden yapılır -- istemcideki değerler sadece paneli doldurmak için.
SardonMatbaa = SardonMatbaa or {}

SardonMatbaa.Config = {
	-- Bir baskı işinin süresi (saniye): SabitSure + adet * AdetBasinaSure
	SabitSure = 60,
	AdetBasinaSure = 3,

	-- Tek seferde basılabilecek en fazla kopya (kutunun ızgarası da buna göre, bkz. KutuGenislik/Yukseklik)
	MaksAdet = 20,

	-- Mürekkep formülü: formatın uzun kenarı TabanPx'e kadar TabanMurekkep,
	-- her PxAdimi (100 px) fazlası için +AdimMurekkep. Formata "murekkep = n" yazılırsa formül ezilir.
	TabanPx = 600,
	TabanMurekkep = 2,
	PxAdimi = 100,
	AdimMurekkep = 2,

	-- 1 px'in dünyada kaç birim olduğu (asılı poster / yere bırakılan baskı boyutu)
	Olcek = 0.06,

	-- Basılabilecek formatlar. genislik/yukseklik px cinsinden; önizleme ve dünyadaki
	-- boyut bu orandan çıkar. Oyuncuya "önerilen görsel boyutu" olarak da gösterilir.
	-- asilabilir = true olan formatlar "Duvara As" ile duvara asılabilir.
	Formatlar = {
		{ id = "gazete",       ad = "Periódico",       genislik = 420, yukseklik = 600, kagit = 1, model = "models/props_junk/garbage_newspaper001a.mdl", aciklama = "Una página de periódico doblada." },
		{ id = "poster",       ad = "Póster",       genislik = 400, yukseklik = 600, kagit = 1, asilabilir = true, model = "models/props_c17/paper01.mdl", aciklama = "Póster estándar para colgar en la pared." },
		{ id = "buyuk_poster", ad = "Póster grande", genislik = 470, yukseklik = 700, kagit = 1, asilabilir = true, model = "models/props_c17/paper01.mdl", aciklama = "Un póster grande, visible desde lejos." },
		{ id = "afis",         ad = "Cartel",     genislik = 560, yukseklik = 800, kagit = 1, asilabilir = true, model = "models/props_c17/paper01.mdl", aciklama = "Un cartel enorme para plazas y muros." },
	},

	-- Sadece bu alan adlarından (ve alt alan adlarından) gelen doğrudan görsel linkleri kabul edilir
	IzinliAlanlar = {
		"i.imgur.com",
		"iili.io",
		"freeimage.host",
		"i.ibb.co",
		"i.postimg.cc",
		"cdn.discordapp.com",
		"media.discordapp.net",
	},
	IzinliUzantilar = { png = true, jpg = true, jpeg = true },

	-- Kutu (base_bags) ızgarası -- KutuGenislik * KutuYukseklik >= MaksAdet olmalı
	KutuGenislik = 5,
	KutuYukseklik = 4,
	-- Kutu makineden çıktıktan sonra kaç saniye sadece sahibi alabilir (0 = kilit yok)
	KutuSahipKilidi = 300,

	-- Bir karakterin aynı anda asılı tutabileceği poster sayısı
	PosterLimiti = 10,
	-- false: asılı posteri E ile sadece asan kişi söküp envantere alabilir.
	-- Superadminler her posteri C + sağ tık menüsündeki "Posteri Kaldır" ile silebilir.
	PosteriHerkesSokebilir = false,

	-- Modeller
	MakineModel = "models/props_c17/TrapPropeller_Engine.mdl",
	MurekkepModel = "models/props_lab/jar01b.mdl",
	KagitModel = "models/props_c17/paper01.mdl",
	KutuModel = "models/props_junk/cardboard_box003a.mdl",

	-- Kutunun makineye göre çıkacağı yer (makinenin yerel koordinatı)
	KutuOfset = Vector(40, 0, 10),

	Kategori = "Matbaa",
}
