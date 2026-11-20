-- "addons\\sardonyaratik\\lua\\sardon_yaratik\\_sh_1ayar.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- [sardon] yaratik :: genel ayarlar
-- Dosya adı "_" ile başlıyor: SardonUtil alfabetik yüklediği için cl_/sh_/sv_ dosyalarından önce gelir.
-- Süreler saniye, ihtiyaçlar 0..100. Tür verisi _sh_2turler.lua'da, hesaplar _sh_3hesap.lua'da.
--
-- Yaşam döngüsü (yönerge): Yumurta (kuluçka, nadirlik burada belirlenir) → Bebek (karaktere bağlanır,
-- temel eğitim) → Genç (eğitim seviyesiyle ilerler) → Yetişkin (en çok ürün, en zor bakım) → Ölüm
-- (doğumdan en geç 7 gün sonra; ihmal ömrü kısaltır).

SardonYaratik = SardonYaratik or {}
local Y = SardonYaratik

-- canlı yenilemede yerel kopyalar bayat kalmasın diye tablo kimliği korunur
Y.Ayar = Y.Ayar or {}
table.Empty(Y.Ayar)
table.Merge(Y.Ayar, {
     -- yaşam
     Omur = 7 * 86400,              -- doğumdan ölüme en uzun süre (UTC, gerçek zaman)
     BebekMinYas = 12 * 3600,       -- bebek → genç: en az bu yaş ...
     BebekBag = 30,                 -- ... ve en az bu bağ
     GencMinYas = 36 * 3600,        -- genç → yetişkin: en az bu yaş ...
     YetiskinSeviye = 10,           -- ... ve bu eğitim seviyesi
     EnFazlaSeviye = 10,

     -- ihmal cezası: bir ihtiyaç sıfırda kaldığı her saniye ömürden CezaOrani saniye düşer
     CezaOrani = 2,
     YanlisYemCeza = 3600,
     AdimSn = 600,                  -- tembel ilerletmede en uzun adım

     -- ihtiyaç azalma çarpanı evreye göre (yetişkin bakımı en zor)
     EvreAzalma = {[1] = 0.9, [2] = 1.0, [3] = 1.25},

     -- bağ (0..100)
     BagKaybi = 6,                  -- 24 saat hiç ilgilenilmezse günde bu kadar düşer
     IlgiSuresi = 86400,

     -- ürün
     UrunMutluluk = 70,             -- bu mutluluğun üstünde geçen süre ürün biriktirir
     KeseSiniri = 6,                -- kesede tür başına en çok bu kadar ürün birikir

     -- yemlik (sahip yokken açlık bu eşiğin altına inince yemlikten yer)
     YemlikEsik = 45,
     YemlikSiniri = 60,             -- yemlikte yem türü başına en çok

     -- eylem bekleme süreleri (yaratık başına)
     Bekleme = {
          sev = 120,
          firca = 600,
          besle = 30,
          egit = 360,
          isit = 20,
          cevir = 0,                 -- kuluçka süresine göre hesaplanır (Y.CevirAraligi)
     },

     -- kapasite: sahip olunabilecek canlı yaratık (yumurtalar ayrı)
     TemelKapasite = 2,
     KuluckaSiniri = 2,             -- aynı anda kuluçkada / elde en çok yumurta
     AnlikTakip = 1,                -- aynı anda yanında yürüyen
     AnlikOmuz = 1,                 -- aynı anda omzunda

     -- varlık sınırları (128 oyuncu)
     TakipGlobal = 40,
     VivaryumGlobal = 90,
     VivaryumSahipBasina = 8,
     VivaryumPayi = 512,            -- alana bu kadar yakınken sahibinin yaratıkları belirir
     VivaryumBekle = 30,            -- sahibi alandan çıkınca bu kadar sn sonra kaybolurlar

     -- takip
     TakipIzAraligi = 0.25,
     TakipIzMesafe = 20,
     TakipIzSayisi = 48,
     TakipIsinla = 1400,            -- bu kadar uzaklaşınca sahibinin arkasına cisimlenir
     TakipTakilma = 4,              -- bu kadar sn yerinden oynamazsa cisimlenir

     -- etkileşim
     EtkilesimMesafe = 150,
     KafesModel = "models/konnie/diagonalley/misc/owlcage1.mdl",
     YumurtaModel = "models/props_phx/misc/egg.mdl",
     FircaModel = "models/sbs/hogsmeade/hm/hgs_comc_horsebrush.mdl",
     FircaDayanim = 30,        -- [sardon] ekonomi (2026-11-07): fırça kaç fırçalamada aşınıp kırılır (10 G → ~0,33 G/fırçalama)
     YemlikModel = "models/sbs/hogsmeade/hm/hgs_comc_basket.mdl",
     YuvaModel = "models/props_normandy/haybale.mdl",
     -- 2026-11-10: Yakalama Çantası = el bavulunun (gladstone, [sardon] depo) modeli; bodygroup 0 "state" 0 kapalı / 1 açık
     CuvalModel = "models/staylofft/hogwarts_props/staylofft_gladstone_bag.mdl",

     -- kuluçka sıcaklığı
     Kulucka = {
          baslangic = 70,
          taban = 25,
          iyiAlt = 55,
          iyiUst = 85,
          isit = 24,                -- 55'ten ısıtınca iyi aralıkta kalsın
          sogumaPay = 4,            -- 100'den tabana kuluçka süresinin 1/4'ünde iner
          cevirSayisi = 5,          -- kuluçka boyunca beklenen çevirme
          kusursuz = 0.85,          -- bu kalitenin üstünde mutasyon şansı
          mutasyon = 0.05,
     },

     -- SYB (Karakter Gelişimi kategorisi) beceri numaraları
     SYB = "syb",
     Beceri = {
          sezgi = 1,     -- Yaratık Sezgisi: XXX türler, +1 kapasite
          sefkat = 2,    -- Şefkatli Eller: bakım etkisi, ihtiyaçlar yavaş azalır
          egitmen = 3,   -- Sabırlı Eğitmen: eğitim XP
          izsurucu = 4,  -- İz Sürücü: 1 → XXX yakalama, 2 → XXXX türler
          usta = 5,      -- Usta Bakıcı: ürün, +2 kapasite
          binicilik = 6, -- Binicilik
          soy = 7,       -- Soy Bilimci: kuluçka mutasyonu
          magizoolog = 8, -- Magizoolog: XXXXX türler, ömür cezası azalır
          vivaryum = 9   -- Vivaryum Anahtarı (2026-11-10): kendi vivaryumu (ağaçta 2. ile 3. sıra arası, kapı)
     },

     -- kişisel vivaryum (sv_9vivaryum.lua, cl_9vivaryum.lua): her sahibin bahçesi ayrı sanal dünya
     -- ([sardon] sims interior instance'ı, Taban+1 .. Taban+EnCok); giriş Yakalama Çantası'yla
     Viv = {
          Taban = 3000,             -- sims evleriyle çakışmasın (ev numaraları küçük); ağda 12 bit, en çok 4095
          EnCok = 1000,
          Bekleme = 10,             -- çanta açma bekleme süresi (sn)
          HasarBekle = 10,          -- son bu kadar sn içinde hasar alan çantayı açamaz
          IstekSure = 60,           -- ziyaret isteğine cevap süresi
          Ileri = 46,               -- çantanın oyuncunun önüne konduğu uzaklık
          AgizYuksek = 13,          -- çanta ağzının zeminden yüksekliği (çekilme noktası)
          -- giriş zaman çizelgesi (sn, girişin başından): elde açılış, yere koyma, adım, çekilme, kapanış, ışınlanma
          T = {ac = 0.55, koy = 1.0, birak = 1.72, adim = 2.0, adimSure = 0.5, cekil = 2.5, cekilSure = 0.95,
               kapan = 3.5, karar = 3.55, isinla = 3.95, belir = 0.9, belirBekle = 0.15},
          -- çıkış: içeride sütuna çekilme, dışarıda çantadan çıkış, sahip çantayı alır
          C = {cekilSure = 0.9, karar = 0.9, isinla = 1.25, cikSure = 0.9, geri = 0.45, al = 0.8, alSure = 1.43, ziyaretAra = 0.45},
          CikisMesafe = 90,         -- çıkış sütununa E mesafesi
          VarisIleri = 80,          -- içeride varış noktası: çıkışın önünde
     },

     -- yabani yaratıklar ve yakalama (sv_9yabani.lua)
     Yabani = {
          Uyanma = 2600,            -- yaşam alanına bu kadar yakın oyuncu varken yaratıklar bulunur
          Uyuma = 3600,             -- kimse bu kadar yakın değilse kaldırılır (saklanırlar)
          Global = 24,              -- sunucuda en çok yabani varlık
          Yenilenme = {20 * 60, 40 * 60}, -- yakalanınca yerine yenisi (sn)
          Evre = {0.25, 0.45, 0.30},      -- bebek / genç / yetişkin olasılığı
          Nadir = {0.85, 0.13, 0.02},     -- sıradan / nadir / efsanevi
          Fark = {380, 380, 320, 280, 340}, -- tehlike sınıfına göre fark etme mesafesi (birim)
          Comelme = 0.45,           -- çömelerek yaklaşınca fark etme mesafesi çarpanı
          Kosma = 1.35,             -- koşarken
          IzSurucu = 0.15,          -- İz Sürücü kademesi başına fark etme mesafesi indirimi
          Isabet = {1, 1, 1, 2, 3}, -- sersemlemek için gereken isabet (6 sn içinde)
          Sersem = {12, 12, 12, 10, 8}, -- sersem kalma süresi (sn)
          Yakalama = {2, 2.3, 2.8, 3.6, 4.5}, -- E basılı tutma süresi (sn)
          Menzil = 140,             -- yakalarken yaratığa en çok uzaklık
          CantaDayanim = 5,         -- Yakalama Çantası kaç yakalamada yırtılır
          Saldiri = {mesafe = 360, hasar = 22, bekleme = 4}, -- saldırgan türler (Graphorn)
     },

     -- üreme (sv_9ureme.lua): çift Çiftleşme Ağılı'nda Sure kadar huzurlu kalınca yumurta sepete düşer
     Ureme = {
          Bekleme = 24 * 3600,      -- yumurtadan sonra yaratık başına dinlenme
          SonGun = 24 * 3600,       -- ağıl süresi bittiğinde ömründen en az bu kadar kalmalı
          Mutluluk = 55,            -- başlamak için ve ağılda sürenin işlemesi için
          Bag = 40,
          IstekSure = 60,           -- başka oyuncunun onayı için bekleme
          Mesafe = 900,             -- başlarken iki yaratık birbirine en çok bu kadar uzak
          Sure = {24, 24, 36, 48, 48}, -- tehlike sınıfına göre ağılda geçmesi gereken huzurlu süre (saat)
          BagHiz = 0.25,            -- bağ 100 iken süre bu kadar hızlı işler (bağ 50: yarısı)
          Azalma = 0.75,            -- ağılda ihtiyaçlar bu çarpanla azalır
          KaseBekle = 48 * 3600,    -- sepetteki yumurta bu kadar alınmazsa soğur
          Gorus = 2500,             -- ağıla bu kadar yakın biri varken çift / yumurta dünyada görünür
     },

     -- yetenekler (Faz 4, sv_9yetenek.lua); süreler sn, mesafeler birim
     Yetenek = {
          -- Burnuk: yanındayken yakınındaki birinin kesesinden aşırır (kendi kesesine), hazine koklar
          Yankesici = {Mesafe = 170, Bekleme = 1800, KurbanBekleme = 7200, Sans = 0.55, SeviyeSans = 0.035, EnCokSans = 0.9,
               GoruyorCeza = 0.25, Miktar = {3, 8}},
          -- kazı noktası sahibinden 260'tan yakın: takip beyni uzaklaşan yaratığın işini keser
          Hazine = {Aralik = {480, 900}, Gunluk = 6, Mesafe = {120, 230}, Miktar = {2, 6}},
          -- Kneazle: yanındayken tehlike sezer (istemci)
          Sezgi = {Asa = 1200, Kurt = 1500, Graphorn = 900, Bekleme = 20},
          -- Fwooper: susturulmamışsa ara ara öter, yakındakilerde kısa delilik; Silencio 2 gün susturur
          Fwooper = {Aralik = {240, 420}, Mesafe = 700, Sure = 8, Susturma = 2 * 86400},
          -- Ay Yavrusu: gece dansından sonra keseye Gümüş Ay Gübresi (gecede en çok)
          AyDans = {Gece = 2},
          -- Kabuluk (omuzda): Alohomora kilit oyununda yay genişler, hata hakkı, sessiz kilit (ihbar çarpanı)
          Kabuluk = {Alan = 1.4, EkHata = 1, Ihbar = 0.5},
          -- Diricawl (yanında): can bu oranın altına inince sahibini alıp ışınlanır
          Diricawl = {Esik = 0.3, Bekleme = 7200, Mesafe = {350, 600}},
          -- Jobberknoll (yanında / omzunda): yakınında söylenenleri tutar, ölünce tersten haykırır
          Jobberknoll = {Mesafe = {w = 110, ic = 320, me = 320, it = 320, y = 700}, Satir = 30, Haykiris = 10, Duyma = 900},
     },

     -- ağ
     Net = "SardonYaratik",
})

-- Nadirlik (genetik). Sıra önemli: kayıtta sayı olarak tutulur.
Y.Nadirlik = Y.Nadirlik or {}
table.Empty(Y.Nadirlik)
table.Merge(Y.Nadirlik, {
     {id = 1, ad = "Común", etiket = "COMÚN", renk = Color(178, 186, 170), urun = 1.0, binekHiz = 1, binekCan = 1},
     {id = 2, ad = "Raro", etiket = "RARO", renk = Color(110, 168, 232), urun = 1.5, binekHiz = 1.08, binekCan = 1.2},
     {id = 3, ad = "Legendario", etiket = "LEGENDARIO", renk = Color(236, 184, 82), urun = 2.0, binekHiz = 1.15, binekCan = 1.4},
})

Y.Evreler = Y.Evreler or {}
table.Empty(Y.Evreler)
table.Merge(Y.Evreler, {
     [0] = {ad = "Huevo", olcek = 1},
     [1] = {ad = "Bebé", olcek = 0.45},
     [2] = {ad = "Joven", olcek = 0.72},
     [3] = {ad = "Adulto", olcek = 1},
})

-- Yem türleri: "yaratik_yem" eşyasının `yem` verisi bu anahtarlardan biri.
Y.Yemler = Y.Yemler or {}
table.Empty(Y.Yemler)
table.Merge(Y.Yemler, {
     bocek = {ad = "Mezcla de insectos", aclik = 45, model = "models/alchemy/ingredfennelseed.mdl", paket = 6, fiyat = 2},
     et = {ad = "Carne fresca", aclik = 55, model = "models/alchemy/ingredboarmeat.mdl", paket = 4, fiyat = 3},
     ot = {ad = "Semillas y hierba", aclik = 40, model = "models/alchemy/ingredwheat01.mdl", paket = 6, fiyat = 2},
     agacbiti = {ad = "Piojo de árbol", aclik = 50, model = "models/alchemy/ingredspiddalstick.mdl", paket = 6, fiyat = 3},
     genel = {ad = "Pienso general de criaturas", aclik = 28, model = "models/sbs/hogsmeade/hm/hgs_comc_sack_of_stuff1.mdl", paket = 8, fiyat = 3, genel = true},
})
Y.YemSirasi = {"bocek", "et", "ot", "agacbiti", "genel"}

-- Tehlike sınıfı (Sihir Bakanlığı) adları
Y.Siniflar = {
     [1] = {kod = "X", ad = "Aburrida"},
     [2] = {kod = "XX", ad = "Inofensiva / Domesticable"},
     [3] = {kod = "XXX", ad = "Un mago hábil puede lidiar con ella"},
     [4] = {kod = "XXXX", ad = "Peligrosa / Requiere especialización"},
     [5] = {kod = "XXXXX", ad = "Asesina de magos / Indomesticable"},
}

-- Durumlar (tablo kimliği korunur: diğer dosyalardaki `local D = Y.D` kopyaları yeni durumları görsün)
Y.D = Y.D or {}
table.Empty(Y.D)
table.Merge(Y.D, {
     YUMURTA = "yumurta",   -- eşyada (yumurta eşyası), kuluçkaya konmamış
     KULUCKA = "kulucka",   -- vivaryumda kuluçkada
     VIVARYUM = "vivaryum",
     TAKIP = "takip",       -- sahibinin yanında yürüyor
     OMUZ = "omuz",
     BINEK = "binek",       -- biri sırtında (sahibi ya da izinli biri); varlık yok, binicinin altında çizilir
     KAFES = "kafes",       -- taşıma kafesi eşyasında
     AGIL = "agil",         -- Çiftleşme Ağılı'nda eşiyle (k.agil)
     KASE = "kase",         -- ağıldaki sepette bekleyen yumurta (k.kase)
     OLU = "olu",
})

function Y.Yetkili(ply)
     return IsValid(ply) and (ply:IsSuperAdmin() or ply:IsAdmin())
end
