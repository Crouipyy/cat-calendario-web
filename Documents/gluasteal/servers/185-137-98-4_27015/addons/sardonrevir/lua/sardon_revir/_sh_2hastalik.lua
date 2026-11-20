-- "addons\\sardonrevir\\lua\\sardon_revir\\_sh_2hastalik.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Revir :: Hastalık Defteri verisi (belirtiler, hastalıklar, dolap eşyaları).
--
-- Belirti kaynakları:
--   gorunur  hastaya bakınca görülür (istemcide görsel efekt: R.Belirtiler[id].efekt)
--   soz      hasta "Nasıl hissediyorsun?" sorusunda anlatır
--   muayene  "Muayene et" ile ortaya çıkar
--   tarama   "Asayla tara" ile çevresinde beliren kalıntı rengi
-- Hastalıklar kümeler halinde belirti paylaşır; ayırt eden çoğu zaman tek bir muayene bulgusu ya da
-- kalıntı rengidir. Aynı belirti kümesine sahip iki hastalık olmamalı (yüklemede denetlenir).
--
-- tedavi adımları sırayla: {"buyu", ad} rün çizilir · {"esya", id} dolaptan Accio · {"sevk"} Pomfrey'e
-- baglam: o anki duruma göre seçilme ağırlığı çarpanı (bkz. R.BaglamTopla, sv_3nobet)

local R = SardonRevir

R.Belirtiler = {
     -- görünür
     kol_bukuk = {ad = "Garip açıyla bükülmüş kol", kaynak = "gorunur", efekt = "kol_bukuk"},
     kol_sarkik = {ad = "Lastik gibi sarkan kol", kaynak = "gorunur", efekt = "kol_sarkik"},
     dumanli_yanik = {ad = "Tüten yanık", kaynak = "gorunur", efekt = "duman_kol"},
     kesik_kan = {ad = "Kanayan yara", kaynak = "gorunur", efekt = "kan"},
     yesil_ten = {ad = "Yeşilimsi ten", kaynak = "gorunur", efekt = "ton_yesil"},
     soluk_ten = {ad = "Buz gibi soluk ten", kaynak = "gorunur", efekt = "ton_mavi"},
     mor_benek = {ad = "Mor benekler", kaynak = "gorunur", efekt = "benek_mor"},
     kivilcim_burun = {ad = "Burundan kıvılcım", kaynak = "gorunur", efekt = "kivilcim_bas"},
     kulak_duman = {ad = "Kulaklardan duman", kaynak = "gorunur", efekt = "duman_bas"},
     kopuk = {ad = "Ağızdan köpük ve kabarcık", kaynak = "gorunur", efekt = "kabarcik_agiz"},
     buz_nefes = {ad = "Buğulanan nefes", kaynak = "gorunur", efekt = "nefes_buz"},
     el_sisik = {ad = "Devasa şişmiş el", kaynak = "gorunur", efekt = "el_buyuk"},
     bas_sisik = {ad = "Balon gibi şişmiş kafa", kaynak = "gorunur", efekt = "bas_buyuk"},
     bacak_dans = {ad = "Durmadan tepinen bacaklar", kaynak = "gorunur", efekt = "bacak_dans"},
     titreme = {ad = "Bütün vücudu titriyor", kaynak = "gorunur", efekt = "titreme"},
     suzulme = {ad = "Yatağın üstünde süzülüyor", kaynak = "gorunur", efekt = "suzulme"},
     pembe_isik = {ad = "Gözlerinde pembe ışıltı", kaynak = "gorunur", efekt = "pembe_bas"},
     bilincsiz = {ad = "Kendinde değil", kaynak = "gorunur", efekt = "bilincsiz"},
     kahkaha = {ad = "Durmadan gülüyor", kaynak = "gorunur", efekt = "kahkaha"},

     -- hastanın anlattıkları
     aci = {ad = "Zonklayan, keskin ağrı", kaynak = "soz"},
     uyusma = {ad = "Uyuşma, karıncalanma", kaynak = "soz"},
     bas_donmesi = {ad = "Baş dönmesi", kaynak = "soz"},
     bulanti = {ad = "Mide bulantısı", kaynak = "soz"},
     kasinti = {ad = "Dayanılmaz kaşıntı", kaynak = "soz"},
     ates = {ad = "Yakıcı ateş", kaynak = "soz"},
     usume = {ad = "İliklere işleyen üşüme", kaynak = "soz"},
     umutsuzluk = {ad = "Umutsuzluk, neşesizlik", kaynak = "soz"},
     kabus = {ad = "Kabuslar", kaynak = "soz"},
     korku = {ad = "Korku nöbetleri", kaynak = "soz"},
     agirlik = {ad = "Uzuvda ağırlık", kaynak = "soz"},
     kontrolsuz = {ad = "Bacaklarını yönetemiyor", kaynak = "soz"},
     konusamiyor = {ad = "Konuşamıyor, yalnız mırıldanıyor", kaynak = "soz"},
     saskinlik = {ad = "Kafa karışıklığı, unutkanlık", kaynak = "soz"},
     saplanti = {ad = "Birine saplantılı hayranlık", kaynak = "soz"},
     tuhaf_istek = {ad = "Tuhaf istekler (süt, çiğ balık)", kaynak = "soz"},
     kulak_cinlama = {ad = "Kulak çınlaması", kaynak = "soz"},
     gulme_aci = {ad = "Gülmekten karın ağrısı", kaynak = "soz"},
     uyuyamama = {ad = "Günlerdir uyuyamamak", kaynak = "soz"},
     guc_yok = {ad = "Halsizlik, dermansızlık", kaynak = "soz"},

     -- muayene bulguları
     kemik_catirti = {ad = "Kemikte çatırtı", kaynak = "muayene"},
     eklem_sis = {ad = "Şişmiş, sıcak eklem", kaynak = "muayene"},
     kemik_yok = {ad = "Kolda kemik hissedilmiyor", kaynak = "muayene"},
     deri_sicak = {ad = "Deri alev gibi sıcak", kaynak = "muayene"},
     deri_buz = {ad = "Deri buz gibi", kaynak = "muayene"},
     duzgun_kesik = {ad = "Dümdüz, keskin kenarlı kesik", kaynak = "muayene"},
     kara_yara = {ad = "Kapanmayan, kenarı kararmış yara", kaynak = "muayene"},
     eksik_parca = {ad = "Koldan bir parça eksik", kaynak = "muayene"},
     kaburga = {ad = "Kaburgada çatlak", kaynak = "muayene"},
     pence_izi = {ad = "Üç paralel pençe izi", kaynak = "muayene"},
     isirik = {ad = "Diş izi, ısırık", kaynak = "muayene"},
     burun_egri = {ad = "Yana eğrilmiş burun", kaynak = "muayene"},
     nabiz_hizli = {ad = "Hızlı nabız", kaynak = "muayene"},
     nabiz_yavas = {ad = "Ağır, yavaş nabız", kaynak = "muayene"},
     goz_buyuk = {ad = "Büyümüş göz bebekleri", kaynak = "muayene"},
     dil_turuncu = {ad = "Dilde turuncu şeker lekesi", kaynak = "muayene"},
     dil_yapisik = {ad = "Dili damağına yapışmış", kaynak = "muayene"},
     dis_uzun = {ad = "Uzamış ön dişler", kaynak = "muayene"},
     ciban = {ad = "Cüppe altında çıbanlar", kaynak = "muayene"},
     damar_kara = {ad = "Kararmış damarlar", kaynak = "muayene"},
     kedi_tuy = {ad = "Kedi tüyleri, çekik gözler", kaynak = "muayene"},
     benek_kabuk = {ad = "Kabuklanan benekler", kaynak = "muayene"},
     goz_kizarik = {ad = "Kızarmış, yorgun gözler", kaynak = "muayene"},
     kas_kasilma = {ad = "Kasılmış, seğiren kaslar", kaynak = "muayene"},
     asa_yanik = {ad = "Asa elinde yanık izi", kaynak = "muayene"},
     el_yazi = {ad = "Elin üstüne kazınmış yazı", kaynak = "muayene"},

     -- tarama (kalıntı)
     k_kirmizi = {ad = "Kızıl kalıntı", kaynak = "tarama", kalinti = "kirmizi"},
     k_yesil = {ad = "Yeşil kalıntı", kaynak = "tarama", kalinti = "yesil"},
     k_mor = {ad = "Mor kalıntı", kaynak = "tarama", kalinti = "mor"},
     k_mavi = {ad = "Mavi kalıntı", kaynak = "tarama", kalinti = "mavi"},
     k_turuncu = {ad = "Turuncu kalıntı", kaynak = "tarama", kalinti = "turuncu"}
}

for id, b in pairs(R.Belirtiler) do b.id = id end

R.KaynakSira = {"gorunur", "soz", "muayene", "tarama"}
R.KaynakAd = {gorunur = "Görünen", soz = "Anlattıkları", muayene = "Muayene", tarama = "Kalıntı"}

-- Dolap (Accio): istemci uçan eşyayı bu modelle çizer
R.Esyalar = {
     {id = "dittany", ad = "Ditten Özü", aciklama = "Yarım cisimlenmede kopan dokuyu yeniden bağlar.", model = "models/healthvial.mdl", renk = Color(150, 220, 140)},
     {id = "kemik", ad = "Kemik Büyüten Şurup", aciklama = "Yok olmuş kemiği bir gecede yeniden büyütür. Tadı berbattır.", model = "models/props_lab/jar01b.mdl", renk = Color(230, 220, 200)},
     {id = "cikolata", ad = "Çikolata", aciklama = "Ruh Emici ve Boggart sonrası soğukluğu dağıtır. Gerçekten.", model = "models/props_junk/garbage_takeoutcarton001a.mdl", renk = Color(150, 96, 60)},
     {id = "bezoar", ad = "Bezoar Taşı", aciklama = "Keçi midesinden çıkan taş; zehirlerin çoğunu bağlar.", model = "models/props_junk/rock001a.mdl", olcek = 0.22, renk = Color(170, 160, 130)},
     {id = "uyku", ad = "Rüyasız Uyku İksiri", aciklama = "Kabussuz, derin bir uyku. Alışkanlık yapar, az ver.", model = "models/props_lab/jar01a.mdl", renk = Color(170, 150, 230)},
     {id = "murtlap", ad = "Murtlap Özü", aciklama = "Süzülmüş Murtlap dokunacağı; kesik ve kazınmış yaraları yatıştırır.", model = "models/props_junk/glassjug01.mdl", olcek = 0.5, renk = Color(230, 200, 120)}
}
R.EsyaHarita = {}
for i, e in ipairs(R.Esyalar) do e.no = i R.EsyaHarita[e.id] = e end

local function B(...) return {"buyu", ...} end
local function E(id) return {"esya", id} end
local SEVK = {"sevk"}

R.Hastaliklar = {
     ----------------------------------------------------------------- Onarım
     {id = "bludger", ad = "Bludger Kırığı", yol = "onarim", zorluk = 2,
      belirtiler = {"kol_bukuk", "aci", "kemik_catirti", "k_kirmizi"}, tedavi = {B("Ferula")},
      neden = "Hızla gelen bir Bludger'ın çarpması; çoğu zaman ön kol.",
      aciklama = "Kemik kırılmış ama yerinden oynamamıştır. Ferula sargısı kemiği hizalar ve bir gecede kaynatır.",
      uyari = "Episkey yalnız deriyi kapatır, kemik çarpık kaynar.",
      baglam = {quidditch = 4, ders_ucus = 2}},

     {id = "burkulma", ad = "Oynak Merdiven Burkulması", yol = "onarim", zorluk = 1,
      belirtiler = {"aci", "eklem_sis", "k_kirmizi"}, tedavi = {B("Episkey")},
      neden = "Yer değiştiren merdivenlerde ya da kaybolan basamakta yanlış basmak.",
      aciklama = "Eklem burkulmuş, kemik sağlam. Episkey şişliği indirir.",
      uyari = "Kemikte çatırtı varsa bu burkulma değil, kırıktır.",
      baglam = {gece = 1.5}},

     {id = "kemiksiz", ad = "Kemiksiz Kol", yol = "onarim", zorluk = 4,
      belirtiler = {"kol_sarkik", "uyusma", "kemik_yok", "k_mor"}, tedavi = {E("kemik"), B("Sanitatem Totalum")},
      neden = "Ters giden bir kemik onarma büyüsü kolun bütün kemiklerini yok eder.",
      aciklama = "Kemik büyüyü yeniden bağlamak gerekir: önce Kemik Büyüten Şurup, ardından Sanitatem Totalum.",
      uyari = "Ferula sarar ama sarılacak kemik yoktur.",
      baglam = {quidditch = 2}},

     {id = "kazan_yanigi", ad = "Kazan Patlaması Yanığı", yol = "onarim", zorluk = 2,
      belirtiler = {"dumanli_yanik", "aci", "deri_sicak", "k_kirmizi"}, tedavi = {B("Aguamenti"), B("Episkey Duo")},
      neden = "İksir dersinde taşan ya da patlayan kazan.",
      aciklama = "Önce yanık soğutulur (Aguamenti), sonra doku Episkey Duo ile onarılır.",
      uyari = "Sıcak yanığa doğrudan Episkey Duo yapılırsa yanık içe işler.",
      baglam = {ders_iksir = 4}},

     {id = "diffindo", ad = "Diffindo Kesiği", yol = "onarim", zorluk = 1,
      belirtiler = {"kesik_kan", "aci", "duzgun_kesik", "k_kirmizi"}, tedavi = {B("Episkey")},
      neden = "Kesme büyüsünün sekmesi; çoğunlukla düello talimi.",
      aciklama = "Temiz bir kesik. Episkey ile birkaç saniyede kapanır.",
      uyari = "Kenarları kararmışsa bu Diffindo değil.",
      baglam = {duello = 2, ders_tilsim = 2}},

     {id = "sectumsempra", ad = "Sectumsempra Yarası", yol = "onarim", zorluk = 4,
      belirtiler = {"kesik_kan", "titreme", "kara_yara", "k_mor"}, tedavi = {B("Vulnera Sanentur")},
      neden = "Kara büyüyle açılmış derin kesikler.",
      aciklama = "Yara sıradan büyüyle kapanmaz; Vulnera Sanentur şarkı gibi söylenir, yara kendini diker.",
      uyari = "Episkey kanamayı durdurur gibi görünür ama yara içeriden açılmaya devam eder.",
      baglam = {duello = 2, gece = 1.5}},

     {id = "cisimlenme", ad = "Yarım Cisimlenme", yol = "onarim", zorluk = 3,
      belirtiler = {"kesik_kan", "uyusma", "eksik_parca", "k_mavi"}, tedavi = {E("dittany"), B("Episkey Maxima")},
      neden = "Kararlılık, Hedef, Ağırbaşlılık... ve birinin ağırbaşlılığı eksik kalmış.",
      aciklama = "Geride kalan doku Ditten Özü ile bağlanır, sonra Episkey Maxima ile kapatılır.",
      uyari = "Ditten'siz kapatılan yara izi kalıcı olur.",
      baglam = {}},

     {id = "supurge", ad = "Süpürgeden Düşme", yol = "onarim", zorluk = 3,
      belirtiler = {"bas_donmesi", "aci", "kaburga", "k_kirmizi"}, tedavi = {B("Episkey Maxima")},
      neden = "Yüksekten düşüş; kaburgalar çatlar, baş döner.",
      aciklama = "Kaburga çatlağı derindedir; Episkey Maxima gerekir.",
      uyari = "Hasta ayağa kalkmakta ısrar eder. Kalkmasın.",
      baglam = {quidditch = 3, ders_ucus = 4, yagmur = 2}},

     {id = "hipogrif", ad = "Hipogrif Tırmığı", yol = "onarim", zorluk = 2,
      belirtiler = {"kesik_kan", "aci", "pence_izi", "k_kirmizi"}, tedavi = {B("Episkey Duo")},
      neden = "Selam vermeden yaklaşılan bir hipogrif.",
      aciklama = "Pençe izleri derindir ama temizdir. Episkey Duo yeterli.",
      uyari = "Hasta mutlaka 'Öleceğim!' der. Ölmez.",
      baglam = {ders_yaratik = 4}},

     {id = "canavar_kitap", ad = "Canavar Kitap Isırığı", yol = "onarim", zorluk = 1,
      belirtiler = {"aci", "isirik", "k_kirmizi"}, tedavi = {B("Episkey")},
      neden = "Canavarların Canavarca Kitabı'nı sırtını okşamadan açmak.",
      aciklama = "Yüzeysel ısırık. Episkey.",
      uyari = "Isırık izinde ateş ve mor kalıntı varsa bu bir kitap değildir.",
      baglam = {ders_yaratik = 2}},

     {id = "kirik_burun", ad = "Kırık Burun", yol = "onarim", zorluk = 1,
      belirtiler = {"kesik_kan", "burun_egri", "k_kirmizi"}, tedavi = {B("Episkey")},
      neden = "Düello, dirsek, kapı ya da bir Gryffindor'un sevinç kucaklaması.",
      aciklama = "Episkey burnu çıt diye yerine oturtur.",
      uyari = "Hasta aynaya bakmak ister. Önce iyileştir.",
      baglam = {duello = 2, quidditch = 1.5}},

     {id = "ejderha_yanigi", ad = "Ejderha Ateşi Yanığı", yol = "onarim", zorluk = 4,
      belirtiler = {"dumanli_yanik", "titreme", "deri_sicak", "k_turuncu"}, tedavi = {B("Aguamenti"), B("Episkey Totalum")},
      neden = "Bir ejderhayla fazla yakından tanışmak.",
      aciklama = "Yanık büyülüdür ve soğumaz; Aguamenti ile söndürülür, Episkey Totalum ile yeniden örülür.",
      uyari = "Kalıntı turuncuysa sıradan kazan yanığı tedavisi işe yaramaz.",
      baglam = {ders_yaratik = 1.5}},

     {id = "kan_kalemi", ad = "Kan Kalemi Yarası", yol = "onarim", zorluk = 2,
      belirtiler = {"aci", "el_yazi", "k_mor"}, tedavi = {E("murtlap"), B("Episkey")},
      neden = "Cezada saatlerce aynı cümleyi kan kalemiyle yazmak.",
      aciklama = "Murtlap Özü acıyı alır, ardından Episkey kazınmış deriyi kapatır.",
      uyari = "Hasta kimin cezası olduğunu söylemek istemeyebilir. Üsteleme.",
      baglam = {gece = 1.3}},

     {id = "kan_kaybi", ad = "Kan Kaybı Halsizliği", yol = "onarim", zorluk = 3,
      belirtiler = {"kesik_kan", "guc_yok", "nabiz_yavas", "k_kirmizi"}, tedavi = {B("Episkey Totalum")},
      neden = "Geç fark edilen bir yara; vücut fazla kan yitirmiş.",
      aciklama = "Episkey Totalum hem yarayı kapatır hem de kaybedilen kanı yeniler.",
      uyari = "Yalnız yarayı kapatmak halsizliği geçirmez.",
      baglam = {duello = 1.5}},

     ----------------------------------------------------------------- Arındırma
     {id = "tentacula", ad = "Zehirli Tentacula Zehri", yol = "arindirma", zorluk = 2,
      belirtiler = {"yesil_ten", "bas_donmesi", "nabiz_hizli", "k_yesil"}, tedavi = {E("bezoar"), B("Detoxify")},
      neden = "Tentacula'nın dikenli sarmaşığına dokunmak.",
      aciklama = "Bezoar zehri bağlar, Detoxify kalanını temizler.",
      uyari = "Yalnız Detoxify yetmez; zehir geri döner.",
      baglam = {ders_bitki = 4}},

     {id = "kusturan_pastil", ad = "Kusturan Pastil", yol = "arindirma", zorluk = 1,
      belirtiler = {"bulanti", "dil_turuncu", "k_yesil"}, tedavi = {B("Detoxify")},
      neden = "Zonko'nun Şaka Dükkânı'ndan bir 'kaytarma' şekerlemesinin turuncu ucu.",
      aciklama = "Şekerlemenin büyüsü Detoxify ile çözülür. Mor ucu yeseydi geçerdi zaten.",
      uyari = "Hasta 'dersim var mıydı' diye sorarsa bilerek yemiştir.",
      baglam = {}},

     {id = "ates_sekerleme", ad = "Ateş Şekerlemesi", yol = "arindirma", zorluk = 1,
      belirtiler = {"ates", "ciban", "k_yesil"}, tedavi = {B("Sanitatem")},
      neden = "Zonko kaytarma şekerlemesi: ateş ve çıban.",
      aciklama = "Sahte ateş büyülü değil şekerlidir; Sanitatem bedeni toparlar.",
      uyari = "Kalıntı morsa çıbanlar bir uğursuzluktandır.",
      baglam = {}},

     {id = "biberli_iksir", ad = "Biberli İksir Aşırı Dozu", yol = "arindirma", zorluk = 1,
      belirtiler = {"kulak_duman", "deri_sicak", "k_yesil"}, tedavi = {B("Aguamenti")},
      neden = "Soğuk algınlığına karşı içilen Biberli İksir'in fazlası.",
      aciklama = "Biraz su ve sabır. Aguamenti ile serinlet.",
      uyari = "Kulaklardan duman çıkması tek başına zararsızdır; hastayı korkutma.",
      baglam = {kar = 3, yagmur = 2}},

     {id = "benekli_humma", ad = "Benekli Humma", yol = "arindirma", zorluk = 2,
      belirtiler = {"mor_benek", "ates", "benek_kabuk", "k_turuncu"}, tedavi = {B("Sanitatem Beneficia")},
      neden = "Büyücüler arasında bulaşan ateşli bir hastalık (Spattergroit).",
      aciklama = "Benekler kabuklanınca bulaşıcılığı azalır. Sanitatem Beneficia.",
      uyari = "Burundan kıvılcım çıkıyorsa Benekli Humma değil, Ejderha Çiçeği'dir.",
      baglam = {kar = 1.5}},

     {id = "ejderha_cicegi", ad = "Ejderha Çiçeği", yol = "arindirma", zorluk = 3,
      belirtiler = {"mor_benek", "kivilcim_burun", "ates", "k_turuncu"}, tedavi = {B("Sanitatem Maxima")},
      neden = "Ağır, bulaşıcı büyücü hastalığı (Dragon Pox).",
      aciklama = "Sanitatem Maxima. Hastayı diğerlerinden uzak tut.",
      uyari = "Hafif tedavi beneklerini kabuklandırır ama kıvılcımlar sürer.",
      baglam = {}},

     {id = "tarantallegra", ad = "Tarantallegra", yol = "arindirma", zorluk = 1,
      belirtiler = {"bacak_dans", "kontrolsuz", "k_mor"}, tedavi = {B("Finite")},
      neden = "Dans ettiren uğursuzluk; düello taliminin vazgeçilmezi.",
      aciklama = "Finite ile bacaklar durur.",
      uyari = "Hastanın kendisi de durmaktan memnun olmayabilir.",
      baglam = {duello = 3}},

     {id = "langlock", ad = "Langlock", yol = "arindirma", zorluk = 2,
      belirtiler = {"konusamiyor", "dil_yapisik", "k_mor"}, tedavi = {B("Finite Incantatem")},
      neden = "Dili damağa yapıştıran sessizlik uğursuzluğu.",
      aciklama = "Finite Incantatem dili çözer.",
      uyari = "Hasta konuşamaz; belirtilerini muayene ve taramayla bulmalısın.",
      baglam = {duello = 2}},

     {id = "densaugeo", ad = "Densaugeo", yol = "arindirma", zorluk = 1,
      belirtiler = {"aci", "dis_uzun", "k_mor"}, tedavi = {B("Finite")},
      neden = "Ön dişleri durmadan uzatan uğursuzluk.",
      aciklama = "Finite ile dişler eski boyuna döner. Hasta biraz daha kısasını isteyebilir.",
      uyari = "Diş uzunluğunu ayarlamak şifacının işi değildir.",
      baglam = {duello = 2}},

     {id = "furnunculus", ad = "Furnunculus", yol = "arindirma", zorluk = 2,
      belirtiler = {"ciban", "kasinti", "k_mor"}, tedavi = {B("Finite"), B("Episkey")},
      neden = "Çıban uğursuzluğu.",
      aciklama = "Önce Finite ile uğursuzluk kaldırılır, sonra Episkey çıbanları kurutur.",
      uyari = "Uğursuzluk kalkmadan kurutulan çıban geri gelir.",
      baglam = {duello = 2}},

     {id = "engorgio_el", ad = "Engorgio Kazası", yol = "arindirma", zorluk = 1,
      belirtiler = {"el_sisik", "agirlik", "k_mor"}, tedavi = {B("Finite")},
      neden = "Tılsım dersinde büyütülecek şeyin yanlışlıkla insan eli olması.",
      aciklama = "Finite ile el eski boyuna döner.",
      uyari = "Reducio denemek eli küçültür ama fazla küçültür.",
      baglam = {ders_tilsim = 3}},

     {id = "kafa_sisirme", ad = "Kafa Şişirme Uğursuzluğu", yol = "arindirma", zorluk = 2,
      belirtiler = {"bas_sisik", "bas_donmesi", "k_mor"}, tedavi = {B("Finite Incantatem")},
      neden = "Kafayı balon gibi şişiren uğursuzluk.",
      aciklama = "Basit Finite yetmez; Finite Incantatem gerekir.",
      uyari = "Hastayı pencere yanına yatırma.",
      baglam = {duello = 1.5}},

     {id = "kara_buyu", ad = "Kara Büyü Kalıntısı", yol = "arindirma", zorluk = 3,
      belirtiler = {"titreme", "kabus", "damar_kara", "k_mor"}, tedavi = {B("Ubi Vulneribus")},
      neden = "Lanetli bir eşyaya dokunmak ya da kara bir büyünün sıyırması.",
      aciklama = "Ubi Vulneribus kara büyünün acısını söker.",
      uyari = "Damarlar kararmışsa geç kalma; kalıntı yayılır.",
      baglam = {gece = 2, ders_ksks = 2}},

     {id = "cokozlu", ad = "Ters Tepen Çok Özlü İksir", yol = "arindirma", zorluk = 3,
      belirtiler = {"tuhaf_istek", "kedi_tuy", "k_yesil"}, tedavi = {B("Finite Incantatem"), B("Sanitatem Beneficia")},
      neden = "Çok Özlü İksir'e insan yerine kedi kılı katmak.",
      aciklama = "Dönüşüm Finite Incantatem ile durdurulur, beden Sanitatem Beneficia ile toparlanır.",
      uyari = "Hasta kimin kılı olduğunu sanıyordu, sorma.",
      baglam = {ders_iksir = 2}},

     {id = "ask_iksiri", ad = "Aşk İksiri Zehirlenmesi", yol = "arindirma", zorluk = 2,
      belirtiler = {"pembe_isik", "saplanti", "nabiz_hizli", "k_yesil"}, tedavi = {B("Detoxify")},
      neden = "Birinin hediye ettiği 'masum' bir kutu çikolata.",
      aciklama = "Detoxify iksiri söker; hasta ardından genelde çok utanır.",
      uyari = "Hastanın andığı kişiyi revire çağırma.",
      baglam = {ders_iksir = 1.5}},

     {id = "billywig", ad = "Billywig Sokması", yol = "arindirma", zorluk = 2,
      belirtiler = {"suzulme", "bas_donmesi", "k_yesil"}, tedavi = {B("Sanitatem Beneficia")},
      neden = "Avustralya'dan gelen minik mavi böcek; sokunca insan havalanır.",
      aciklama = "Sanitatem Beneficia ile hasta yere iner.",
      uyari = "Hastayı tavana yapışmadan tedavi et.",
      baglam = {ders_yaratik = 3}},

     {id = "salyangoz", ad = "Sümüklüböcek Kusturan Uğursuzluk", yol = "arindirma", zorluk = 2,
      belirtiler = {"kopuk", "bulanti", "k_mor"}, tedavi = {B("Finite Incantatem")},
      neden = "Geri tepen bir uğursuzluk; kırık asayla yapılınca sahibine döner.",
      aciklama = "Finite Incantatem ile durur. Kova hazır olsun.",
      uyari = "Hasta asasının kırık olduğunu kabul etmeyebilir.",
      baglam = {duello = 2}},

     {id = "rictusempra", ad = "Rictusempra", yol = "arindirma", zorluk = 1,
      belirtiler = {"kahkaha", "gulme_aci", "k_mor"}, tedavi = {B("Finite")},
      neden = "Gıdıklama büyüsü; düelloda karşıdakini iki büklüm eder.",
      aciklama = "Finite.",
      uyari = "Gülmesi bulaşıcıdır; çizimini bozmasına izin verme.",
      baglam = {duello = 3}},

     ----------------------------------------------------------------- Koruyucu Şifa
     {id = "mandragora", ad = "Mandragora Çığlığı Baygınlığı", yol = "koruma", zorluk = 1,
      belirtiler = {"bilincsiz", "nabiz_yavas", "k_yesil"}, tedavi = {B("Rennervate")},
      neden = "Kulaklıksız saksı değiştirmek.",
      aciklama = "Genç mandragora bayıltır, öldürmez. Rennervate ile ayılır.",
      uyari = "Hasta uyanınca ilk iş kulaklığını sorar.",
      baglam = {ders_bitki = 4}},

     {id = "sersemletme", ad = "Sersemletme Sonrası", yol = "koruma", zorluk = 1,
      belirtiler = {"bilincsiz", "goz_buyuk", "k_mavi"}, tedavi = {B("Rennervate")},
      neden = "Göğse yiyilen bir Stupefy.",
      aciklama = "Rennervate ile kendine gelir.",
      uyari = "Kalıntı yeşilse bu bir bitki baygınlığıdır.",
      baglam = {duello = 3}},

     {id = "ruh_emici", ad = "Ruh Emici Soğukluğu", yol = "koruma", zorluk = 3,
      belirtiler = {"soluk_ten", "buz_nefes", "umutsuzluk", "k_mavi"}, tedavi = {E("cikolata"), B("Lux Vitae")},
      neden = "Bir Ruh Emici'nin fazla yakınından geçmek.",
      aciklama = "Önce çikolata, sonra Lux Vitae'nin ışığı içindeki soğuğu dağıtır.",
      uyari = "Hasta çikolatayı reddederse ısrar et.",
      baglam = {gece = 1.5}},

     {id = "boggart", ad = "Boggart Şoku", yol = "koruma", zorluk = 2,
      belirtiler = {"titreme", "korku", "nabiz_hizli", "k_mavi"}, tedavi = {B("Lux Vitae")},
      neden = "Dolabı açınca karşısına en büyük korkusunun çıkması.",
      aciklama = "Lux Vitae'nin ışığı korkunun gölgesini dağıtır.",
      uyari = "Hastaya neyden korktuğunu sorma; tekrar görür.",
      baglam = {ders_ksks = 4}},

     {id = "confundus", ad = "Confundus", yol = "koruma", zorluk = 2,
      belirtiler = {"saskinlik", "goz_buyuk", "k_mavi"}, tedavi = {B("Finite Incantatem")},
      neden = "Aklı karıştıran büyü.",
      aciklama = "Finite Incantatem aklın sisini dağıtır.",
      uyari = "Hastanın anlattıklarına güvenme; çoğu doğru değildir.",
      baglam = {duello = 2}},

     {id = "glacius", ad = "Glacius Donması", yol = "koruma", zorluk = 2,
      belirtiler = {"soluk_ten", "usume", "deri_buz", "k_mavi"}, tedavi = {B("Sanitatem")},
      neden = "Dondurma büyüsünün sekmesi ya da gölde fazla kalmak.",
      aciklama = "Sanitatem bedeni içten ısıtır.",
      uyari = "Nefesi buğulanıyor ve umutsuzsa bu bir Ruh Emici'dir.",
      baglam = {kar = 3, yagmur = 1.5}},

     {id = "kurt_isirigi", ad = "Kurt Adam Isırığı", yol = "koruma", zorluk = 3,
      belirtiler = {"isirik", "ates", "kas_kasilma", "k_mor"}, tedavi = {B("Episkey Duo"), SEVK},
      neden = "Dolunay gecesi ormanda dolaşmak.",
      aciklama = "Yarayı Episkey Duo ile kapat; ısırığın kendisi tedavi edilemez. Madam Pomfrey'e bildir.",
      uyari = "Bunu kendi başına çözmeye kalkma. Sevk etmek de şifacılıktır.",
      baglam = {dolunay = 6, gece = 2}},

     {id = "uykusuzluk", ad = "Sınav Uykusuzluğu", yol = "koruma", zorluk = 1,
      belirtiler = {"uyuyamama", "goz_kizarik", "k_mavi"}, tedavi = {E("uyku"), B("Sanitatem")},
      neden = "Sınav haftası, bitmeyen ödevler, bir de kahve.",
      aciklama = "Rüyasız Uyku İksiri ve ardından Sanitatem.",
      uyari = "İksirin alışkanlık yaptığını hastaya söyle.",
      baglam = {gece = 2}},

     {id = "geri_tepen", ad = "Geri Tepen Büyü", yol = "koruma", zorluk = 2,
      belirtiler = {"asa_yanik", "kulak_cinlama", "k_mavi"}, tedavi = {B("Rennervate"), B("Episkey")},
      neden = "Çatlak bir asa ya da fazla hırslı bir büyü.",
      aciklama = "Rennervate sersemliği alır, Episkey asa elindeki yanığı kapatır.",
      uyari = "Hastaya asasını Ollivander'a göstermesini söyle.",
      baglam = {duello = 1.5, ders_tilsim = 1.5}}
}

R.HastalikHarita = {}
for i, h in ipairs(R.Hastaliklar) do
     h.no = i
     R.HastalikHarita[h.id] = h
     h.belirtiSet = {}
     for _, b in ipairs(h.belirtiler) do
          if (!R.Belirtiler[b]) then ErrorNoHalt("[Sardon Revir] " .. h.id .. ": bilinmeyen belirti " .. b .. "\n") end
          h.belirtiSet[b] = true
     end
     for _, a in ipairs(h.tedavi) do
          if (a[1] == "esya" and !R.EsyaHarita[a[2]]) then ErrorNoHalt("[Sardon Revir] " .. h.id .. ": bilinmeyen eşya " .. a[2] .. "\n") end
     end
end

-- aynı belirti kümesine sahip iki hastalık ayırt edilemez
do
     local gorulen = {}
     for _, h in ipairs(R.Hastaliklar) do
          local k = table.Copy(h.belirtiler)
          table.sort(k)
          local anahtar = table.concat(k, ",")
          if (gorulen[anahtar]) then ErrorNoHalt("[Sardon Revir] aynı belirtiler: " .. h.id .. " / " .. gorulen[anahtar] .. "\n") end
          gorulen[anahtar] = h.id
     end
end

function R.Hastalik(id) return R.HastalikHarita[id] end
function R.Esya(id) return R.EsyaHarita[id] end

-- hastalığın kalıntı rengi
function R.HastalikKalinti(h)
     for _, b in ipairs(h.belirtiler) do
          local bel = R.Belirtiler[b]
          if (bel.kalinti) then return bel.kalinti end
     end
end

-- tedavide geçen bütün büyüler (sırasız, tekil)
function R.TedaviBuyuleri()
     local t, s = {}, {}
     for _, h in ipairs(R.Hastaliklar) do
          for _, a in ipairs(h.tedavi) do
               if (a[1] == "buyu" and !s[a[2]]) then s[a[2]] = true t[#t + 1] = a[2] end
          end
     end
     table.sort(t)
     return t
end

-- adımın oyuncuya yazılışı
function R.AdimYaz(a)
     if (!a) then return "" end
     if (a[1] == "buyu") then return a[2] end
     if (a[1] == "esya") then local e = R.Esya(a[2]) return "Dolaptan: " .. (e and e.ad or a[2]) end
     return "Madam Pomfrey'e sevk"
end
