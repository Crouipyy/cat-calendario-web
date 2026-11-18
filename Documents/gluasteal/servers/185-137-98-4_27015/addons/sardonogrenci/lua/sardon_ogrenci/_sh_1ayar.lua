-- "addons\\sardonogrenci\\lua\\sardon_ogrenci\\_sh_1ayar.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Öğrenci :: ayarlar. Hogwarts Legacy öğrenci gövdeleri (St_oprop_1-5, ws 3827850936 / 3827855119 /
-- 3827859550 / 3827863710 / 3827868549) ve onların HLStudents kütüphanesi (addons/periciogrenci) üzerine Helix.
--
-- AKIŞ
--   Görünüm (char data "ogrenciGorunum", v = 2): HLStudents ayarlarının kıyafetsiz kısmı (gender, hair, skin,
--   brow, colors, flex, eyes, scar, marks, makeup, height). Kıyafet bu kayıtta DEĞİL: giyili giysi eşyalarından
--   (ogr_<kimlik>; veri l = renk/görünüm, h = kapüşon) sunucuda türetilir, hane rengi fraksiyondan gelir. Giyili =
--   karakterin "sardon_kiyafet" ekipman envanterinde (aksesuar gibi; TAB'da sağdaki yuvalar). Oyuncuda ağ
--   HLStudents'ınki: NW2 "hl_gear" / "hl_face" / "hl_col_*" (istemciler bonemerge parçalarını kendileri kurar).
--   _sh_2katalog.lua : giysi kataloğu (üretilmiş; bir kimlik = bir Helix eşyası)
--   _sh_3durum.lua   : doğrulama (Temizle), varsayılan/rastgele, HLStudents ayar tablosu (Ayarlar), başlangıç takımı
--   _sh_4helix.lua   : yaratma değişkeni (index 3.5), model değişkeni sarması, IsFemale
--   _sh_5esya.lua    : giysi eşyaları (taban + katalog), ekipman envanteri tipi, Giy / Çıkar / Kapüşon
--   _sh_9magaza.lua  : Madam Malkin kıyafet tezgâhı fiyatları
--   sv_1kayit.lua    : uygula, ragdoll kopyası, /Gorunum, v1 (Staylofft tabanı) kaydını taşıma, komutlar
--   sv_2kiyafet.lua  : ekipman envanteri, giy/çıkar/takas, kapüşon, uzlaştırma, başlangıç takımı, komutlar
--   sv_5magaza.lua   : satın alma, karşılama cüppesi (Madam'ın "Túnicani al" seçeneği)
--   cl_2giydir.lua   : önizleme / karakter kartı / gardırop giydirme (dükkân denemesi), ragdoll'lar, parıltı
--   cl_3sahne.lua    : Görünüm Aynası 3B stüdyosu (ışık, rün çemberi, parçacık, kamera)
--   cl_4ayna.lua     : arayüz
--   cl_5baglanti.lua : Helix yaratma akışı, /Gorunum düzenleme, giysi renk seçici
--   cl_9kiyafet.lua  : istemci yardımcıları (yerel giysiler, giy/çıkar istekleri, yuva ikonları)
--   cl_9magaza.lua   : Madam Malkin dükkânının "Túnica & Ropa" bölümü ([sardon] aksesuar cl_2magaza.lua barındırır)
-- TAB yuvaları [sardon] karakter cl_4gardrop.lua'da (sağ ray), ızgaraya bırakma cl_5esyalar.lua'da.
-- HLStudents RP kipinde (periciogrenci autorun'unda HLStudents.RP): serbest menü, istemcinin ayar göndermesi ve
-- boy ölçeği kapalı. Oyuncunun ölçeğini [sardon] boy verir (taban x O.BoyCarpani).
SardonOgrenci = SardonOgrenci or {}
local O = SardonOgrenci

O.SURUM = 2
O.VERI = "ogrenciGorunum"
O.ESYA_TABAN = "base_ogrenci_giysi"
O.ESYA_ONEK = "ogr_"
O.ESKI_ESYA = "ogrenci_kiyafet"

O.Ayar = O.Ayar or {}
table.Empty(O.Ayar)
table.Merge(O.Ayar, {
     -- görünümü olan karakterin yeniden düzenlemesi: "ilk" (yalnız görünümü olmayan) | "serbest" | "yetkili"
     -- (yetkili /GorunumIzni ile bir karaktere tek seferlik izin verebilir)
     Duzenleme = "ilk",
     -- bu fraksiyonların karakterleri öğrenci gövdesini kullanır (uniqueID)
     -- evisiz = dump TR; nuevos = Aeterna "Estudiantes Nuevos" (default al crear)
     Fraksiyonlar = {
          evisiz = true, nuevos = true,
          gryffindor = true, hufflepuff = true, ravenclaw = true, slytherin = true,
     },
     -- fraksiyon -> HLStudents hane sırası (Config.Houses: 1 Gryffindor, 2 Slytherin, 3 Ravenclaw, 4 Hufflepuff);
     -- hane renkli giysi görünümleri bu haneyle boyanır
     Hane = {gryffindor = 1, slytherin = 2, ravenclaw = 3, hufflepuff = 4},
     -- hanesiz fraksiyonda hane renkli görünümlerin hanesi
     HanesizHane = 1,
     -- giysi rengini kim değiştirebilir: "serbest" | "yetkili" | "kapali". 2026-10-28 kullanıcı kararı: renk
     -- satın alırken seçilir ve kalıcıdır; başka renk ayrıca satın alınır
     RenkDegistir = "kapali",
     -- görünüm kaydedilince oyuncunun üstünde parçacık efekti ("" = yok). 2026-11-01 kullanıcı kararı: kuaför vb.
     -- sonrası hpw_apparation_white_impact çıkmasın
     DegisimEfekti = "",
})

-- Yeni yaratma ekranını kim görür: "herkes" | "yetkili". Konsoldan değiştirilebilir, kalıcı.
O.Erisim = CreateConVar("sardon_ogrenci_erisim", "herkes", {FCVAR_ARCHIVE, FCVAR_REPLICATED},
     "Espejo de apariencia (crear estudiante): todos | staff")

-- Görünümü ilk kez oluşturulan karakterin (yaratma ya da /Gorunum) aldığı takım: Hogwarts Legacy başlangıç
-- kıyafeti. ust: başlangıç kıyafetinin 12 rengi. alt / ayakkabi: seçilebilen sabit renkli görünümler
-- {görünüm, ad, renk}. eslesme[i]: üstün i. rengiyle takım olan alt (kızda HL'nin kendi takımı: okul eteğinin
-- 6+i. görünümü; erkekte dokulardan en yakın pantolon rengi). corap: ayakkabıyla giyilen varsayılan çorap.
O.Baslangic = {
     m = {
          ust = "upp_avatarintro",
          alt = {giysi = "low_highpants01", eslesme = {26, 23, 22, 26, 26, 22, 24, 24, 23, 22, 26, 26}, secenek = {
               {26, "Negro a rayas", Color(44, 46, 44)}, {23, "Azul noche", Color(38, 42, 74)},
               {22, "Marrón oscuro", Color(64, 47, 28)}, {24, "Rosa viejo", Color(124, 90, 82)},
               {21, "Verde a cuadros", Color(56, 86, 76)}, {25, "Verde moteado", Color(62, 82, 76)}}},
          ayakkabi = {giysi = "shoes_stushoes03", secenek = {
               {23, "Negro", Color(36, 36, 34)}, {20, "Marrón", Color(94, 72, 46)},
               {17, "Canela", Color(122, 92, 62)}, {24, "Gris oscuro", Color(72, 70, 64)}}},
          corap = {giysi = "socks_socks01", gorunum = 22},
     },
     f = {
          ust = "upp_avatarintro",
          alt = {giysi = "low_stuuni03", eslesme = {7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18}, secenek = {
               {7, "Rojo", Color(150, 34, 28)}, {8, "Azul noche", Color(62, 58, 92)},
               {9, "Mostaza", Color(150, 122, 62)}, {10, "Antracita", Color(52, 54, 52)},
               {11, "Petróleo", Color(22, 100, 106)}, {12, "Caqui", Color(92, 74, 34)},
               {13, "Azul hielo", Color(112, 150, 152)}, {14, "Rosa viejo", Color(170, 120, 104)},
               {15, "Ceniza", Color(140, 150, 140)}, {16, "Canela", Color(160, 110, 62)},
               {17, "Café", Color(102, 60, 16)}, {18, "Negro", Color(42, 42, 44)}}},
          ayakkabi = {giysi = "shoes_stushoes03", secenek = {
               {10, "Negro", Color(40, 40, 38)}, {9, "Marrón", Color(112, 86, 56)},
               {11, "Ceniza", Color(102, 92, 78)}, {13, "Azul noche", Color(62, 72, 94)}}},
          corap = {giysi = "socks_socks01", gorunum = 25},
     },
}

-- Eski karakterin /Gorunum ile ilk geçişinde hane öğrencisine verilen okul takımı (hane renkli görünüm 1).
-- Hanesiz fraksiyon başlangıç takımını alır.
O.HaneTakimi = {
     m = {{"upp_stuuni01", 1}, {"low_highpants01", 1}, {"robe_sturobe01", 1}, {"acc_stuscarf01u", 1}, {"shoes_stushoes03", 1}},
     f = {{"upp_stuuni01", 1}, {"low_stuuni01", 1}, {"robe_sturobe01", 1}, {"acc_stuscarf01u", 1}, {"shoes_stushoes03", 1}},
}

O.SlotAd = {
     robe = "Túnica / abrigo", upper = "Superior", lower = "Inferior", shoes = "Calzado", socks = "Calcetines", hat = "Sombrero",
     face = "Gafas / máscara", scarf = "Bufanda / collar", hands = "Guantes",
}
O.SlotKategori = {
     robe = "Túnicas y abrigos", upper = "Prendas superiores", lower = "Prendas inferiores", shoes = "Calzado", socks = "Calcetines",
     hat = "Sombreros", face = "Gafas y máscaras", scarf = "Bufandas y collares", hands = "Guantes",
}

-- Giyili giysiler karakterin ayrı ekipman envanterinde (aksesuardaki gibi; ızgarada yer kaplamaz): 9 yuva + 1 takas
-- hücresi. Envantere giriş/çıkış yalnız O.Giy / O.Cikar ile (sv_2kiyafet.lua).
O.EKIPMAN = "sardon_kiyafet"
O.EKIPMAN_W = 10

-- TAB yuvaları (baştan ayağa), kısa adları ve öğrenci paketinin yuva ikonları (materials/hl_students/ui/ic_*.png)
O.YuvaSira = {"hat", "face", "scarf", "robe", "upper", "hands", "lower", "socks", "shoes"}
O.YuvaKisa = {
     hat = "Sombrero", face = "Gafas", scarf = "Bufanda", robe = "Túnica", upper = "Superior", hands = "Guantes", lower = "Inferior",
     socks = "Calcetines", shoes = "Calzado",
}
O.YuvaIkon = {
     hat = "headwear", face = "glasses", scarf = "neck", robe = "back", upper = "outfit", hands = "hands",
     lower = "trousers", socks = "socks", shoes = "shoes",
}

-- Dinlenme ifadesi: yüzün oyunda hep taşıdığı hafif mimik (modelin ifade morfları; iki öğrencide aynı).
-- {denetleyici, ad, en çok}. Konuşma (jaw_drop, *_part, *_mouth_drop) motorun, göz kırpma (blink)
-- HLStudents'ın: burada yok. Ağız kenarı iki yönlü tek kaydırıcı (mouth_left / mouth_right).
O.IfadeGrup = {
     {ad = "Boca", liste = {
          {"smile", "Sonrisa", 0.7}, {"cheek_raise", "Elevar mejillas", 0.6}, {"dimple", "Hoyuelo", 0.7},
          {"frown", "Comisuras abajo", 0.6}, {"sneer", "Labio torcido", 0.5}, {"lips_press", "Labios apretados", 0.6},
          {"lips_stretch", "Labios estirados", 0.5}, {"chin_raise", "Elevar mentón", 0.5},
          {"smile_open", "Sonrisa abierta", 0.4}, {"lips_narrow", "Labios fruncidos", 0.5}}},
     {ad = "Ojos y cejas", liste = {
          {"brow_raise", "Subir cejas", 0.6}, {"brow_lower", "Bajar cejas", 0.6}, {"brow_squeeze", "Fruncir cejas", 0.6},
          {"squint", "Entrecerrar ojos", 0.6}, {"eye_wide", "Apertura de ojos", 0.6}, {"brow_scrunch", "Arrugar cejas", 0.5}}},
     {ad = "Otros", liste = {{"nose_sneer", "Arrugar nariz", 0.5}, {"suck", "Hundir mejillas", 0.5}}},
}
O.IfadeYan = {"mouth_left", "mouth_right", 0.5}

-- denetleyici -> en çok (doğrulama ve uygulama bu listeyle)
O.IfadeEnCok = {}
for _, g in ipairs(O.IfadeGrup) do
     for _, it in ipairs(g.liste) do O.IfadeEnCok[it[1]] = it[3] end
end
O.IfadeEnCok[O.IfadeYan[1]] = O.IfadeYan[3]
O.IfadeEnCok[O.IfadeYan[2]] = O.IfadeYan[3]

O.IfadeHazir = {
     {"Neutral", {}},
     {"Sonrisa suave", {smile = 0.22, cheek_raise = 0.1}},
     {"Alegre", {smile = 0.45, cheek_raise = 0.3, dimple = 0.3, squint = 0.12}},
     {"Serio", {brow_lower = 0.2, brow_squeeze = 0.15, lips_press = 0.25}},
     {"Curioso", {brow_raise = 0.35, eye_wide = 0.2}},
     {"Soberbio", {sneer = 0.18, mouth_left = 0.18, squint = 0.15, brow_raise = 0.08}},
     {"Burlón", {smile = 0.2, mouth_right = 0.3, brow_raise = 0.12}},
     {"Somnoliento", {squint = 0.45, brow_raise = 0.05}},
     {"Mohíno", {frown = 0.35, brow_lower = 0.2, lips_press = 0.15}},
     {"Preocupado", {brow_squeeze = 0.3, brow_raise = 0.2, lips_stretch = 0.15}},
     {"Mirada dura", {brow_lower = 0.35, squint = 0.25, lips_press = 0.2}},
     {"Avergonzado", {brow_raise = 0.2, smile = 0.15, squint = 0.1, chin_raise = 0.1}},
}

-- Hazır yüz hatları: şekil kaydırıcılarının birleşimleri; seçilen yalnız kendi kaydırıcılarını yazar (birleşebilir)
O.YuzHazir = {
     {"Rasgos suaves", {cheek_fullness = 0.4, jaw_angle = -0.4, chin_width = 0.2, nose_bridge = -0.2, cheekbone = -0.2}},
     {"Rasgos afilados", {cheekbone = 0.5, jaw_angle = 0.5, cheek_fullness = -0.4, chin_forward = 0.2, nose_bridge = 0.3}},
     {"Cara redonda", {face_width = 0.4, cheek_fullness = 0.5, jaw_width = 0.3, chin_length = -0.3}},
     {"Cara alargada", {face_width = -0.3, chin_length = 0.5, jaw_width = -0.2, cheek_fullness = -0.2}},
     {"Mandíbula ancha", {jaw_width = 0.6, jaw_angle = 0.3, chin_width = 0.4}},
     {"Delicado", {face_width = -0.3, jaw_width = -0.4, chin_width = -0.3, nose_size = -0.3, mouth_width = -0.2}},
     {"Nariz aguileña", {nose_bridge = 0.6, nose_length = 0.3, nose_tip_height = -0.3, nose_size = 0.2}},
     {"Nariz respingona", {nose_tip_height = 0.5, nose_length = -0.3, nose_bridge = -0.3, nostril_width = 0.2}},
     {"Labios carnosos", {upper_lip = 0.5, lower_lip = 0.6, mouth_width = 0.1}},
     {"Ojos grandes", {eye_size = 0.5, eye_spacing = 0.1, brow_height = 0.2}},
}

function O.Yetkili(ply)
     return IsValid(ply) and ply:IsAdmin()
end

-- Yeni yaratma ekranını bu oyuncu kullanabilir mi
function O.Erisebilir(ply)
     return O.Erisim:GetString() == "herkes" or O.Yetkili(ply)
end

-- HLStudents (periciogrenci) yüklü mü
function O.Hazir()
     return HLStudents ~= nil and HLStudents.Config ~= nil and HLStudents.Gear ~= nil and HLStudents.Sanitize ~= nil
end

local function fraksiyon(faction)
     if isnumber(faction) then return ix.faction.indices[faction] end
     if isstring(faction) then return ix.faction.teams[faction] end
end

-- Fraksiyon (index ya da uniqueID) öğrenci gövdesini kullanıyor mu
function O.FraksiyonUygun(faction)
     local f = fraksiyon(faction)
     return f ~= nil and O.Ayar.Fraksiyonlar[f.uniqueID] == true
end

-- Fraksiyonun HLStudents hane numarası (hane renkli giysi görünümleri)
function O.HaneNo(faction)
     local f = fraksiyon(faction)
     return f and O.Ayar.Hane[f.uniqueID] or O.Ayar.HanesizHane
end

function O.HaneFraksiyonu(faction)
     local f = fraksiyon(faction)
     return f ~= nil and O.Ayar.Hane[f.uniqueID] ~= nil
end
