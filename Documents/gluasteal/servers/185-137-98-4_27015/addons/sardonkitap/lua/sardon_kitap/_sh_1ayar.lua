-- "addons\\sardonkitap\\lua\\sardon_kitap\\_sh_1ayar.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Kitap :: ortak tanımlar (kitaplar, ayarlar, karakter verisi okuma, bölüm listesi).
-- Yükleme sırası (alfabetik): _sh_1ayar → _sh_2metin_a/b → _sh_3runler → _sh_4esya → cl_*/sv_*
--
-- Kararlar (kullanıcı): kitaptan öğrenme Büyü Ağacı fiyatından en az %20 indirimli (2026-11-05; önce %50; 11-15 aşağı yuvarlanır, en az 1 puan); acemi
-- (ilk 20 kullanım %35 tekleme, bir kısmı şaka); ders/Akran/profesör denetimi ustalaştırır.
--
-- Karakter verisi char:GetData("sardonKitap"):
--   o   = {["kitap:bolum"] = true}            okunan bölümler
--   i   = {["kitap:bolum"] = saniye}          yarım kalan okuma
--   a   = {[büyü] = {n = kullanım}}           kitaptan öğrenilmiş, henüz acemi büyüler
--   u   = {[büyü] = "ders"|"akran"|"denetim"|"alisma"}  ustalaşmış kitap büyüleri
--   yk  = eski küsurat kredisi (11-15'ten beri kullanılmıyor, kitap alımında 0 yazılır)
--   s   = {bitki = {[ad]=t}, yaratik = {["y:tur"|"h:tur"]=t}, yer = {[id]=t}}  keşif sayfaları
--   y   = son mektup verilen yıl · sv = {[yıl] = true} geçilen sınavlar · st = son sınav denemesi (os.time)

SardonKitap = SardonKitap or {}
local SK = SardonKitap

SK.ESYA_ON = "kitap_"
SK.MEKTUP = "hogwarts_mektubu"
SK.KAZAN = "okul_kazani"
SK.KAYIS = "kitap_kayisi"
SK.KAYIS_W, SK.KAYIS_H = 4, 2
SK.KAZAN_MODEL = "models/staylofft/hogwarts_cauldrons/staylofft_sanctuary_pewter.mdl" -- Kalay (11-06; eski: models/aoc_objects/cauldron_01.mdl)
SK.TEZGAH_MODEL = "models/sbs/hogsmeade/hm/hgs_fb_book_pile_12.mdl"
SK.KAYIS_MODEL = "models/props_c17/BriefCase001a.mdl"

-- spine: kitap sırtı rengi · harf: sırt yazısı rengi
-- model/hl: St_prop3 HL kitap modeli (11-05 kullanıcı kararı K4); hl = SardonKitapAnim kimliği (okurken elde açılır)
SK.KITAPLAR = {
     {id = "goshawk1", ad = "Standart Büyüler Kitabı, 1. Sınıf", en = "The Standard Book of Spells, Grade 1", yazar = "Miranda Goshawk",
          yil = 1, spine = Color(112, 34, 42), harf = Color(232, 206, 140), model = "models/staylofft/hogwarts_books/staylofft_charms_book.mdl", hl = "charms_book",
          ders = {"Eski Tılsımlar", "Büyücülük", "Kitap Okuma"}, ozet = "Asa tutuşundan ilk tılsımlara: büyüler kitaptan Büyü Ağacı fiyatının %20 altına öğrenilir."},
     {id = "switch", ad = "Biçim Değiştirmeye Giriş", en = "A Beginner's Guide to Transfiguration", yazar = "Emeric Switch",
          yil = 1, spine = Color(34, 70, 58), harf = Color(222, 214, 170), model = "models/staylofft/hogwarts_books/staylofft_transfiguration_book.mdl", hl = "transfiguration_book",
          ders = {"Metamorfoz", "Simya"}, ozet = "Biçim değiştirmenin yasaları ve ilk dönüşümler."},
     {id = "trimble", ad = "Karanlık Güçler: Kendini Koruma Rehberi", en = "The Dark Forces: A Guide to Self-Protection", yazar = "Quentin Trimble",
          yil = 1, spine = Color(30, 38, 62), harf = Color(196, 206, 228), model = "models/staylofft/hogwarts_books/staylofft_dark_magic_tome.mdl", hl = "dark_magic_tome",
          ders = {"Karanlık Sanatlara Karşı Savunma", "Düello", "Karanlık Sanatlar"}, ozet = "Korunma büyüleri ve karanlığa karşı ilk dersler."},
     {id = "jigger", ad = "Büyülü Karışımlar ve İksirler", en = "Magical Drafts and Potions", yazar = "Arsenius Jigger",
          yil = 1, spine = Color(120, 88, 30), harf = Color(246, 228, 176), model = "models/staylofft/hogwarts_books/staylofft_medical_book.mdl", hl = "medical_book",
          ders = {"Iksir"}, ozet = "Kazan başında güvenlik; bitirene Temel iksir tarifleri açılır.", dinamik = "tarif"},
     {id = "spore", ad = "Bin Büyülü Bitki ve Mantar", en = "One Thousand Magical Herbs and Fungi", yazar = "Phyllida Spore",
          yil = 1, spine = Color(62, 92, 40), harf = Color(232, 226, 170), model = "models/staylofft/hogwarts_books/staylofft_simple_book.mdl", hl = "simple_book",
          ders = {"Botanik"}, ozet = "Yetiştirip hasat ettiğin her bitkinin sayfası kendiliğinden dolar.", dinamik = "bitki"},
     {id = "scamander", ad = "Fantastik Canavarlar ve Nerede Bulunurlar", en = "Fantastic Beasts and Where to Find Them", yazar = "Newt Scamander",
          yil = 1, spine = Color(84, 52, 36), harf = Color(236, 210, 160), model = "models/staylofft/hogwarts_books/staylofft_living_book.mdl", hl = "living_book",
          ders = {"Sihirli Yaratıkların Bakımı"}, ozet = "Karşılaştığın yaratıkların sayfası açılır; kenarlarda Newt'ün notları.", dinamik = "yaratik"},
     {id = "bagshot", ad = "Sihir Tarihi", en = "A History of Magic", yazar = "Bathilda Bagshot",
          yil = 1, spine = Color(74, 46, 84), harf = Color(226, 206, 232), model = "models/staylofft/hogwarts_books/staylofft_ancient_magic_book.mdl", hl = "ancient_magic_book",
          ders = {"Tarih", "Büyü Tarihi"}, ozet = "Gittiğin her önemli yerin tarihi kitaba eklenir.", dinamik = "yer"},
     {id = "waffling", ad = "Sihir Kuramı", en = "Magical Theory", yazar = "Adalbert Waffling",
          yil = 1, spine = Color(36, 84, 90), harf = Color(206, 230, 226), model = "models/staylofft/hogwarts_books/staylofft_divination_book.mdl", hl = "divination_book",
          ders = {"Büyücülük", "Metafiziksel Büyüler", "Aritmansi"}, ozet = "Büyünün kuramı; kendi asanın ağacı ve özü altın varakla.", dinamik = "asa"},
}

-- sonraki yılların Standart Büyüler Kitabı ciltleri (bölümleri Büyü Ağacı'ndan üretilir; birinci yıl gibi öğretir)
-- 11-05 kullanıcı kararı: 2.-7. yıl = St_prop3 Locksley serisi (aynı tasarım, altı renk). Duran model açılamadığı için
-- okurken elde rengine en yakın açılabilen HL kitabı (hl) görünür.
local UST_YIL = {
     [2] = {"locksley_a", "bragbor_journal", Color(128, 32, 30)},        -- kırmızı
     [3] = {"locksley_b", "salazar_journal", Color(30, 74, 46)},         -- yeşil
     [4] = {"locksley_c", "charms_book", Color(38, 50, 104)},            -- mavi
     [5] = {"locksley_d", "ancient_magic_book", Color(78, 42, 92)},      -- mor
     [6] = {"locksley_e", "dark_magic_tome", Color(30, 42, 36)},         -- koyu
     [7] = {"locksley_f", "restricted_e_animated", Color(118, 54, 34)},  -- kızıl kahve
}
for n = 2, 7 do
     local u = UST_YIL[n]
     SK.KITAPLAR[#SK.KITAPLAR + 1] = {
          id = "goshawk" .. n, ad = "Standart Büyüler Kitabı, " .. n .. ". Sınıf", en = "The Standard Book of Spells, Grade " .. n,
          yazar = "Miranda Goshawk", yil = n, spine = u[3], harf = Color(232, 206, 140),
          model = "models/staylofft/hogwarts_books/staylofft_" .. u[1] .. ".mdl", hl = u[2],
          ders = {"Eski Tılsımlar", "Büyücülük", "Kitap Okuma"}, cilt = n,
          ozet = n .. ". yılın büyüleri. Okuyup rünü çizen, büyüyü Büyü Ağacı fiyatının %20 altına öğrenir.",
     }
end

SK.Kitap = {}
for i, k in ipairs(SK.KITAPLAR) do
     k.sira = i
     SK.Kitap[k.id] = k
end

function SK.EsyaId(kitapId) return SK.ESYA_ON .. kitapId end
function SK.EsyadanKitap(uid)
     if not isstring(uid) or string.sub(uid, 1, #SK.ESYA_ON) ~= SK.ESYA_ON then return nil end
     return SK.Kitap[string.sub(uid, #SK.ESYA_ON + 1)]
end

function SK.YilKitaplari(yil)
     local t = {}
     for _, k in ipairs(SK.KITAPLAR) do
          if k.yil == yil then t[#t + 1] = k end
     end
     return t
end

/*
*   ayarlar (Shine Admin › Kitaplar › Ayarlar)
*/
SK.AyarAlanlari = {
     {"okumaSn", "Bölüm okuma süresi (sn)", 15, 600, 75},
     {"buyuOkumaSn", "Büyü bölümü okuma süresi (sn)", 15, 900, 120},
     {"yerCarpani", "Kütüphane / ortak salonda okuma hızı (×)", 1, 4, 2},
     {"teklemeYuzde", "Acemi büyü tekleme şansı (%)", 0, 80, 35},
     {"sakaYuzde", "Teklemelerin şaka etkisi olan kısmı (%)", 0, 100, 25},
     {"acemiKullanim", "Acemilik kaç kullanım sürer", 1, 60, 20},
     {"akranMesafe", "Ustalaştıran 5. yıl+ öğrenci en uzak (birim)", 80, 800, 250},
     {"denetimBarem", "Profesör denetimi başarı baremi (%)", 20, 100, 60},
     {"denetimSure", "Denetimde çizim süresi (sn)", 8, 60, 20},
     {"fiyat", "Yeni birinci yıl kitabı (Galleon)", 0, 60, 4},
     {"ciltFiyat", "Üst yıl cildi (Galleon)", 0, 80, 6},
     {"kayisFiyat", "Kitap kayışı (Galleon)", 0, 60, 3},
     {"satisYuzde", "Kitapçıya satışta ödenen (%)", 0, 100, 50},
     {"ikinciElYuzde", "İkinci el satış fiyatı (%)", 10, 100, 60},
     {"dersCezaYuzde", "Kitapsız gelenin kesilen ders puanı (%)", 0, 100, 50},
     {"sinavSoru", "Sınavdaki soru sayısı", 3, 20, 10},
     {"sinavGecme", "Sınavı geçme oranı (%)", 30, 100, 70},
     {"sinavBekleme", "Sınav tekrar bekleme (dk)", 0, 240, 30},
     {"kazanDakika", "Kurulan okul kazanı kaç dk durur", 3, 120, 20},
     {"notUzunluk", "Kenar notu en çok harf", 20, 300, 160},
}
SK.AyarAnahtarlari = {
     {"teklemeAcik", "Acemi büyüler teklesin", true},
     {"jiggerTarif", "Jigger'ı bitirene Temel iksir tarifleri", true},
     {"notlarAcik", "Kenar notları açık", true},
     {"yillikMektup", "Her yıl baykuşla yeni liste", true},
     {"sinavAcik", "Yıl sonu sınavı açık", true},
     {"dersCeza", "Kitapsız gelenin ders puanı kesilsin", true},
}

SK.Varsayilan = {}
for _, a in ipairs(SK.AyarAlanlari) do SK.Varsayilan[a[1]] = a[5] end
for _, a in ipairs(SK.AyarAnahtarlari) do SK.Varsayilan[a[1]] = a[3] end

SK.Ayar = SK.Ayar or table.Copy(SK.Varsayilan)
for k, v in pairs(SK.Varsayilan) do
     if SK.Ayar[k] == nil then SK.Ayar[k] = v end
end

function SK.AyarTemizle(t)
     local out = {}
     t = istable(t) and t or {}
     for _, a in ipairs(SK.AyarAlanlari) do
          out[a[1]] = math.Clamp(math.floor(tonumber(t[a[1]]) or a[5]), a[3], a[4])
     end
     for _, a in ipairs(SK.AyarAnahtarlari) do
          if t[a[1]] == nil then out[a[1]] = a[3] else out[a[1]] = t[a[1]] == true end
     end
     return out
end

-- yerinde güncelle (başka dosyalardaki local kopyalar bayat kalmasın)
function SK.AyarUygula(t)
     local temiz = SK.AyarTemizle(t)
     table.Empty(SK.Ayar)
     table.Merge(SK.Ayar, temiz)
end

-- okuma hızını artıran alanlar (Helix alan adında geçen parça, küçük harf)
SK.OKUMA_YERLERI = {"kütüphane", "kütüpane", "ortak salon", "ortak alan", "ravenclaw hanesi", "hufflepuff hanesi", "slytherin yatakhanesi"}
SK.KITAPCI_ALANI = {"hogsmade kitapcı", "hogsmade kitapçı"}

/*
*   Türkçe küçük/büyük harf
*/
local KUCUK = {["İ"] = "i", ["I"] = "ı", ["Ç"] = "ç", ["Ğ"] = "ğ", ["Ö"] = "ö", ["Ş"] = "ş", ["Ü"] = "ü"}
local BUYUK = {["i"] = "İ", ["ı"] = "I", ["ç"] = "Ç", ["ğ"] = "Ğ", ["ö"] = "Ö", ["ş"] = "Ş", ["ü"] = "Ü"}

function SK.Kucuk(s)
     s = tostring(s or "")
     s = string.gsub(s, "[%z\1-\127\194-\244][\128-\191]*", function(c) return KUCUK[c] or c end)
     return string.lower(s)
end

function SK.Buyuk(s)
     s = tostring(s or "")
     s = string.gsub(s, "[%z\1-\127\194-\244][\128-\191]*", function(c) return BUYUK[c] or c end)
     return string.upper(s)
end

local function Icerir(alan, desenler)
     alan = SK.Kucuk(alan or "")
     if alan == "" then return false end
     for _, p in ipairs(desenler) do
          if string.find(alan, p, 1, true) then return true end
     end
     return false
end

function SK.OkumaYeri(alan) return Icerir(alan, SK.OKUMA_YERLERI) end
function SK.KitapciAlani(alan) return Icerir(alan, SK.KITAPCI_ALANI) end

-- Sihir Tarihi yer sayfası (SK.YERLER _sh_2metin_b'de)
function SK.YerBul(alan)
     if not SK.YERLER then return nil end
     for _, y in ipairs(SK.YERLER) do
          if Icerir(alan, y.desen) then return y end
     end
end

/*
*   karakter verisi
*/
function SK.Veri(char)
     local v = char and char.GetData and char:GetData("sardonKitap")
     return istable(v) and v or {}
end

function SK.Anahtar(k, b) return tostring(k) .. ":" .. tostring(b) end

function SK.Okundu(char, k, b)
     local o = SK.Veri(char).o
     return istable(o) and o[SK.Anahtar(k, b)] == true
end

function SK.Acemi(char, buyu)
     local a = SK.Veri(char).a
     return istable(a) and istable(a[buyu]) and a[buyu] or nil
end

function SK.Yil(char)
     if not char then return 1 end
     if SardonAkran and SardonAkran.Yil and SardonAkran.Seviye then
          return math.Clamp(SardonAkran.Yil(SardonAkran.Seviye(char)), 1, 8)
     end
     local lvl = char.GetLVL and tonumber(char:GetLVL()) or 0
     return math.Clamp(math.floor(lvl / 5) + 1, 1, 8)
end

/*
*   bölümler
*   Statik metin _sh_2metin_*.lua'da (SK.Metin[kitap] = {bölüm, ...}); Shine'dan düzenlenen
*   başlık/sayfalar SK.MetinOzel[kitap][bölüm] ile üstüne yazılır. Üst yıl ciltleri Büyü Ağacı'ndan.
*/
SK.Metin = SK.Metin or {}
SK.MetinOzel = SK.MetinOzel or {}

local CILT_KADEME = {[2] = 2, [3] = 2, [4] = 3, [5] = 3, [6] = 4, [7] = 4}
local ciltOnbellek = {}

local function BuyuAciklama(buyu)
     local spell = HpwRewrite and HpwRewrite.GetSpell and HpwRewrite:GetSpell(buyu)
     local a = spell and spell.Description and string.Trim(string.gsub(tostring(spell.Description), "%s+", " ")) or ""
     return a ~= "" and a or nil
end

local function CiltBolumleri(n)
     if ciltOnbellek[n] then return ciltOnbellek[n] end
     local BA = SardonBuyuAgaci
     local kademe = CILT_KADEME[n]
     if not BA or not BA.Agaclar or not kademe then return {} end

     local adaylar = {}
     for _, agac in ipairs(BA.Agaclar) do
          for _, d in ipairs(agac.dugumler or {}) do
               if d.kademe == kademe then adaylar[#adaylar + 1] = {buyu = d.buyu, agac = agac.ad} end
          end
     end
     table.sort(adaylar, function(a, b) return a.buyu < b.buyu end)

     -- aynı kademeyi paylaşan iki yıl: çift sıradakiler bir cilde, tekler ötekine
     local secilen = {}
     local tek = n % 2
     for i, a in ipairs(adaylar) do
          if i % 2 == tek and #secilen < 8 then secilen[#secilen + 1] = a end
     end

     local agacAdlari = {}
     for _, agac in ipairs(BA.Agaclar) do agacAdlari[#agacAdlari + 1] = agac.ad end

     local kad = BA.Kademeler and BA.Kademeler[kademe] and BA.Kademeler[kademe].ad or (kademe .. ". kademe")
     local out = {
          {id = "onsoz", baslik = "Önsöz", sayfalar = {
               "Bu cilt, " .. n .. ". yıl öğrencilerinin karşılaşacağı " .. kad .. " anlatır. Her bölümü okuyan ve büyünün rününü sayfanın kenarına temiz çizen öğrenci, büyüyü kitaptan öğrenebilir.",
               "Kitaptan öğrenilen büyü Büyü Ağacı'nın kurallarına uyar: kademe kilidi açık ve önceki büyü biliniyor olmalıdır. Bedeli ağaçtakinden %20 düşüktür ama büyü bir süre acemi kalır; bir derste ya da tecrübeli bir öğrencinin yanında kullanmak onu ustalaştırır."
          }, soru = {"Kitaptan öğrenilen bir büyünün bedeli nedir?", {"Büyü Ağacı'ndakinden %20 ucuz", "Ağaçtakinin iki katı", "Bedava"}, 1}},
     }
     for _, a in ipairs(secilen) do
          local acik = BuyuAciklama(a.buyu) or (a.buyu .. ", bu yılın öğrencilerinden beklenen büyülerdendir.")
          local yanlis = {}
          for _, ad in ipairs(agacAdlari) do
               if ad ~= a.agac and #yanlis < 2 then yanlis[#yanlis + 1] = ad end
          end
          out[#out + 1] = {
               id = "k_" .. string.gsub(SK.Kucuk(a.buyu), "[^%w]", ""), baslik = a.buyu, buyu = a.buyu,
               sayfalar = {
                    acik,
                    a.buyu .. " " .. a.agac .. " ağacındandır. Okumayı bitirince rünü sayfanın kenarına tek hamlede çiz; çizgin yeterince temizse büyü senin olur.",
               },
               soru = {a.buyu .. " hangi büyü ağacındadır?", {a.agac, yanlis[1] or "Hiçbiri", yanlis[2] or "Bilinmiyor"}, 1},
          }
     end
     ciltOnbellek[n] = out
     return out
end

-- Büyü Ağacı yeniden yüklenirse ciltler yeniden üretilsin
function SK.CiltOnbellekSil() ciltOnbellek = {} end

function SK.Bolumler(kitapId)
     local k = SK.Kitap[kitapId]
     if not k then return {} end
     local ham = k.cilt and CiltBolumleri(k.cilt) or (SK.Metin[kitapId] or {})
     local ozel = SK.MetinOzel[kitapId]
     if not ozel then return ham end

     local out = {}
     for i, b in ipairs(ham) do
          local o = ozel[b.id]
          if istable(o) then
               local yeni = table.Copy(b)
               if isstring(o.baslik) and o.baslik ~= "" then yeni.baslik = o.baslik end
               if istable(o.sayfalar) and #o.sayfalar > 0 then yeni.sayfalar = o.sayfalar end
               out[i] = yeni
          else
               out[i] = b
          end
     end
     return out
end

function SK.BolumBul(kitapId, bolumId)
     for i, b in ipairs(SK.Bolumler(kitapId)) do
          if b.id == bolumId then return b, i end
     end
end

-- bölümün öğrettiği büyü sunucuda kayıtlı mı (değilse bölüm yalnız okunur)
function SK.BuyuVar(buyu)
     return isstring(buyu) and HpwRewrite ~= nil and HpwRewrite.GetSpell ~= nil and HpwRewrite:GetSpell(buyu) ~= nil
end

function SK.BolumSure(b)
     if not b then return 0 end
     if b.sure then return b.sure end
     return (b.buyu and SK.Ayar.buyuOkumaSn) or SK.Ayar.okumaSn
end

-- kitabın bütün (statik) bölümleri okundu mu
function SK.KitapBitti(char, kitapId)
     local liste = SK.Bolumler(kitapId)
     if #liste == 0 then return false end
     for _, b in ipairs(liste) do
          if not SK.Okundu(char, kitapId, b.id) then return false end
     end
     return true
end

-- hane (char:GetHouse sayı döndürür)
SK.HANELER = {
     {id = "gryffindor", ad = "Gryffindor", renk = Color(174, 42, 46)},
     {id = "ravenclaw", ad = "Ravenclaw", renk = Color(46, 84, 160)},
     {id = "slytherin", ad = "Slytherin", renk = Color(38, 120, 70)},
     {id = "hufflepuff", ad = "Hufflepuff", renk = Color(214, 172, 48)},
}
function SK.Hane(char)
     local h = char and char.GetHouse and char:GetHouse()
     return h and SK.HANELER[h] or nil
end
function SK.HaneBul(ad)
     for _, h in ipairs(SK.HANELER) do
          if h.ad == ad then return h end
     end
end

/*
*   kitap indirimi: Büyü Ağacı maliyetinin en az %20 altı (2026-11-05 kullanıcı kararı; önce %50).
*   11-15: ağaç fiyatları küçüldü (2/3/4/6/10), yukarı yuvarlama indirimi yiyordu (2 → 1,6 → 2).
*   Artık aşağı yuvarlanır ve ağaçtakinden en az 1 puan ucuzdur: 2→1, 3→2, 4→3, 6→4, 10→8.
*   Küsurat kredisi (yk) kalktı; eski kredi ilk kitap alımında sıfırlanır.
*   Döner: ödenecek puan, kredi (hep 0; eski çağıranlar için), ağaçtaki fiyat.
*/
SK.KITAP_INDIRIM = 0.20

function SK.KitapMaliyeti(char, buyu)
     local BA = SardonBuyuAgaci
     local tam = (BA and BA.Maliyet) and BA.Maliyet(buyu) or 1
     if tam <= 1 then return math.max(0, tam), 0, tam end
     return math.Clamp(math.floor(tam * (1 - SK.KITAP_INDIRIM) + 1e-6), 1, tam - 1), 0, tam
end
