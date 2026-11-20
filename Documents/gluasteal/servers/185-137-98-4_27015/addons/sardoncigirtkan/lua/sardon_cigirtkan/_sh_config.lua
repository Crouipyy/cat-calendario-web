-- "addons\\sardoncigirtkan\\lua\\sardon_cigirtkan\\_sh_config.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Çığırtkan (Howler) :: ayarlar ve ortak parçalar.
--
-- AKIŞ
--   1. Gönderen TAB menüsünde oyuncuya "Çığırtkan Gönder" der (envanterinde boş Çığırtkan + baykuş).
--      Kayıt penceresi açılır, bas-konuş tuşuyla en çok Ayar.EnUzun sn konuşur. Bu sırada çevresi onu
--      boğuk duyar ([sardon] ses S.BogukZorla). Ham ses paketleri HolyLib kancasından alınır (sv_1kayit).
--   2. Kayıt ses işleyicisinde (sunucu DIŞI, [sardon] ses/isleyici/cigirtkan.py) MP3'e çevrilir:
--      gürültü temizleme, sessizlik kırpma, seviye + sınırlayıcı (kulak patlatmaz), salon yankısı;
--      anonimde ses bozulur. Gönderen önizler, yeniden kaydeder ya da baykuşa verir.
--   3. Gönderenin baykuşu ([st] pets pet_owl, GMap yolları) alıcıya uçar, pençesinde kırmızı zarf.
--      Baykuş yaklaşırken MP3 alıcının çevresindeki istemcilere parça parça önden yollanır (sv_2aktarim).
--   4. Zarf (sardon_cigirtkan varlığı) alıcının yüzünün önünde süzülür. E ile açılır; Ayar.AcmaSuresi
--      sn açılmazsa kendini açar ve daha geniş alana bağırır. İstemciler MP3'ü zarfın konumunda 3B çalar
--      (sound.PlayFile), zarfın ağzı sesin seviyesine göre açılıp kapanır (cl_4zarf).
--   5. Alıcıya "bir kez daha?" sorulur (E, herkes yine duyar); sonra zarf yırtılıp yanar.
--
-- DİSK: ses sunucuda yalnızca RAM'de ve yalnızca kayıttan zarfın yok oluşuna kadar durur; istemciler
-- dosyayı iş bitince siler. Kalıcı tek kopya Discord kaydındaki MP3 ekidir (moderasyon, sv_4discord).
--
-- YAZILI ÇIĞIRTKAN (sistem tebligatı; ör. Büyü Bakanlığı, C.YaziGonder): ses kaydı yoktur. Bir baykuş
-- aynı kızıl zarfı getirir; zarf açılınca alıcının ekranının altında bir daktilo belirir ve belge harf
-- harf yazılır (C.DaktiloBelge), zarf her vuruşta ağzını şaklatır, tuş / zil / şaryo sesleri zarftan 3B
-- duyulur, sonunda damga basılır. Çevredekiler zarfın üstünde yazılan satırları görür (cl_4zarf).
SardonCigirtkan = SardonCigirtkan or {}
local C = SardonCigirtkan

C.ITEM = "cigirtkan"
C.Sinif = "sardon_cigirtkan"

-- Canlı yeniden yüklemede tablo YERİNDE güncellenir: diğer dosyalar "local A = C.Ayar" ile bu tabloyu
-- tutuyor; yeni tablo atansaydı henüz yenilenmemiş dosyalar yeni alanları göremezdi.
local AYAR = {
     EnUzun = 30,              -- sn; bundan uzun konuşma kaydedilmez (kayıt kendiliğinden biter)
     EnKisa = 1,               -- sn; bundan kısa kayıt gönderilmez
     KayitZamanAsimi = 240,    -- sn; kayıt penceresi bundan uzun açık kalırsa kapanır
     KayitBoguk = true,        -- kayıt yapan çevresine boğuk duyulsun
     Bekleme = 300,            -- sn; aynı kişi iki çığırtkan arasında bu kadar bekler
     Fiyat = 5,                -- Galleon; Evcil Baykuş Mağazası > Çığırtkan
     UcusZamanAsimi = 120,     -- sn; baykuş bu sürede varamazsa zarf alıcının tepesine düşer
     TakilmaSuresi = 15,       -- sn; baykuş bu kadar süre alıcıya yaklaşamazsa takılmış sayılır (aynı sonuç)
     OnYukleme = 4000,         -- baykuş alıcıya bu kadar yaklaşınca ses çevreye önden yollanmaya başlar
     DusmeSuresi = 1.4,        -- sn; baykuşun bıraktığı zarfın alıcının önüne süzülmesi
     AcmaSuresi = 15,          -- sn; açılmayan zarf bu süre sonunda kendini açar (daha yüksek)
     AcilisPayi = 0.8,         -- sn; açılma animasyonu, ses bundan sonra başlar
     TekrarSoru = 10,          -- sn; "bir kez daha?" sorusunun süresi
     YokOlma = 2.8,            -- sn; yırtılıp yanma
     Uzaklik = 34,             -- zarfın alıcının gözünden uzaklığı
     Menzil = 1800,            -- sesin duyulduğu (verinin yollandığı) yarıçap
     MenzilPatlama = 2600,     -- açılmadan patlayan zarfınki
     SesTam = 380,             -- 3B: bu uzaklığa kadar tam ses
     SesTamPatlama = 650,
     Ses = 1.0,                -- çalma seviyesi (istemci)
     EngelCarpan = 0.45,       -- duvar / kapı arkasındaki dinleyende seviye çarpanı
     Parca = 16000,            -- bayt; ağ parça boyu (0,1 sn'de bir, oyuncu başına bir parça)
     TikButce = 6,             -- 0,1 sn'de TOPLAM en çok bu kadar parça (~7,7 Mbit/sn); kalabalık toplu çığırtkan
                               -- sunucunun çıkışını patlatmasın. Önce alıcılar alır, ses baykuş yoldayken önden iner.

     -- Toplu çığırtkan (kurallar Shine Admin > Çığırtkan'dan; sv_5admin)
     TopluBekleme = 600,       -- sn; toplu gönderimler arası (tekli bekleme süresinden ayrı)
     KumeYaricap = 700,        -- birbirine bu kadar yakın (ve aynı bölgedeki) alıcılar tek zarfı paylaşır
     EnCokKume = 12,           -- bir toplu çığırtkanda en çok bu kadar zarf / okul baykuşu
     GrupOlcek = 1.7,          -- küme zarfının büyüklüğü
     GrupYukseklik = 26,       -- küme zarfı alıcıların göz hizasının bu kadar üstünde süzülür
     MenzilGrup = 2200,
     SesTamGrup = 600,
     GrupAcmaMenzil = 420,     -- küme zarfını açmak / tekrar istemek için en çok uzaklık

     -- Yazılı çığırtkan (daktilo)
     DaktiloSatir = 46,        -- bir satıra en çok bu kadar harf (eşaralıklı; iki tarafta aynı sarılır)
     DaktiloHiz = 0.036,       -- sn; harf başına ortalama vuruş arası
     DaktiloBesleme = 0.9,     -- sn; kâğıt merdaneye takılırken (ilk harften önce)
     DaktiloSatirSonu = 0.32,  -- sn; şaryo dönüşü
     DaktiloOkuma = 4,         -- sn; damgadan sonra belge açık kalır (+ harf başına 0,015; en çok 7)
     DaktiloEnUzun = 45,       -- sn; toplam tavan (uzun metin hızlanır)
     DaktiloMetin = 420,       -- harf; gövde metni tavanı
     DaktiloEkranY = 0.62,     -- alıcının ekranında daktilonun merdanesi (ekran yüksekliğine oran; kâğıt bunun üstünde)
     DaktiloYan = 22,          -- yazarken zarf alıcının bu kadar sağına kayar ki kâğıdın arkasında kalmasın
     DaktiloYukseklik = 3,     -- ... ve göz hizasının bu kadar üstüne
     DaktiloMenzil = 650,      -- çevredekilerin zarfın üstündeki satırları gördüğü uzaklık
}
C.Ayar = C.Ayar or {}
for k, v in pairs(AYAR) do C.Ayar[k] = v end

-- Toplu hedef anahtarı: "f:<faction uniqueID>" | "c:<sınıf uniqueID>"
function C.HedefTablo(anahtar)
     local tur, id = string.match(anahtar or "", "^(%a):(.+)$")
     if tur == "f" then return "faction", ix.faction.teams[id] end
     if tur == "c" then
          for _, c in pairs(ix.class.list) do
               if c.uniqueID == id then return "class", c end
          end
     end
end

-- Ekranda görünen ad: haneler "Gryffindor Evi", diğer faction'lar adıyla, sınıflar adıyla
function C.HedefAd(anahtar)
     local tur, t = C.HedefTablo(anahtar)
     if not t then return tostring(anahtar) end
     if tur == "faction" and isstring(t.category) and string.find(t.category, " Evi$") then return t.category end
     return t.name or tostring(anahtar)
end

-- Kayıt penceresinin durumu (sunucu -> gönderen)
C.K = {KAPALI = 0, KAYIT = 1, ISLENIYOR = 2, ONIZLEME = 3, HATA = 4}

-- Zarfın durumu (varlık)
C.Z = {DUSUS = 1, BEKLE = 2, CAL = 3, SOR = 4, YOK = 5}

-- Pencereden gelen işlemler
C.I = {BITIR = 1, YENIDEN = 2, ANONIM = 3, GONDER = 4, VAZGEC = 5}

function C.SureYazi(sn)
     sn = math.max(0, math.floor(tonumber(sn) or 0))
     return string.format("%d:%02d", math.floor(sn / 60), sn % 60)
end

-- Onaltılık dalga özeti ("a3ff...") -> {0..1, ...}
function C.DalgaCoz(hex)
     local t = {}
     if not isstring(hex) then return t end
     for i = 1, #hex - 1, 2 do
          t[#t + 1] = (tonumber(string.sub(hex, i, i + 1), 16) or 0) / 255
     end
     return t
end

----------------------------------------------------------------------------------------
-- Yazılı çığırtkan: belge düzeni ve daktilo zamanlaması
----------------------------------------------------------------------------------------
-- yazi = {tur = "İhtarname", antet = "BÜYÜ BAKANLIĞI", daire = "...", sayi = "BB/İHT-0007", tarih = "14.10.2026",
--         alici = "Ad Soyad", metin = "...", imza = "Ad Soyad", unvan = "...", damga = "SON İHTAR",
--         renk = {r, g, b}, muhur = "bakanlik"}
-- İki taraf aynı belgeyi kurar: sunucu zarfın süresini (toplam), istemci vuruş zamanlarını buradan alır.
-- Yazı eşaralıklı bir ızgaraya dizilir (satır başına Ayar.DaktiloSatir harf), böylece istemcinin
-- yazı tipi ölçüsünden bağımsızdır.

-- Geçersiz UTF-8'i at, harf sayısıyla kırp
function C.YaziKirp(s, n)
     s = tostring(s or "")
     if not utf8.len(s) then s = string.gsub(s, "[\128-\255]", "") end
     s = string.gsub(s, "[%z\1-\9\11-\31\127]", "")
     if n and (utf8.len(s) or 0) > n then s = string.sub(s, 1, utf8.offset(s, n + 1) - 1) end
     return s
end

local BUYUK = {["i"] = "İ", ["ı"] = "I", ["ç"] = "Ç", ["ş"] = "Ş", ["ğ"] = "Ğ", ["ü"] = "Ü", ["ö"] = "Ö"}
function C.Buyuk(s)
     s = string.gsub(tostring(s or ""), "[%z\1-\127\194-\244][\128-\191]*", function(c) return BUYUK[c] or c end)
     return string.upper(s)
end

local function Harfler(s)
     local t = {}
     for _, kod in utf8.codes(s) do t[#t + 1] = utf8.char(kod) end
     return t
end

local function Uzunluk(s) return utf8.len(s) or #s end

-- Kelime sarma; satırdan uzun kelime n harflik parçalara bölünür. "\n" yeni satır, "\n\n" boş satır
local function Sar(metin, n)
     local satirlar = {}
     for paragraf in string.gmatch(metin .. "\n", "(.-)\n") do
          local satir, uz = "", 0
          local function Kelime(kelime, ku)
               if uz == 0 then
                    satir, uz = kelime, ku
               elseif uz + 1 + ku <= n then
                    satir, uz = satir .. " " .. kelime, uz + 1 + ku
               else
                    satirlar[#satirlar + 1] = satir
                    satir, uz = kelime, ku
               end
          end
          for kelime in string.gmatch(paragraf, "%S+") do
               local h = Harfler(kelime)
               for i = 1, #h, n do
                    Kelime(table.concat(h, "", i, math.min(#h, i + n - 1)), math.min(n, #h - i + 1))
               end
          end
          satirlar[#satirlar + 1] = satir
     end
     return satirlar
end
C.DaktiloSar = Sar

-- Her yerde aynı sonucu veren sözde rastgele (0..1); math.sin platforma göre son bitlerde ayrışabilir
local function Titrek(k)
     return ((k * 1103515245 + 12345) % 2147483648) / 2147483648
end
C.DaktiloTitrek = Titrek

local NOKTALAMA = {["."] = true, [","] = true, [";"] = true, [":"] = true, ["!"] = true, ["?"] = true}

local function Kur(yazi, carpan)
     local N = C.Ayar.DaktiloSatir
     local S = {}
     local function Ekle(s, kirmizi, hiza)
          for _, p in ipairs(Sar(s, N)) do S[#S + 1] = {s = p, kirmizi = kirmizi == true, hiza = hiza or 0} end
     end

     local sol = (yazi.sayi or "") ~= "" and ("Sayı: " .. yazi.sayi) or ""
     local sag = yazi.tarih or ""
     if sol ~= "" or sag ~= "" then
          S[#S + 1] = {s = sol .. string.rep(" ", math.max(1, N - Uzunluk(sol) - Uzunluk(sag))) .. sag, hiza = 0}
          S[#S + 1] = {s = "", hiza = 0}
     end
     if (yazi.tur or "") ~= "" then
          local b = C.Buyuk(yazi.tur)
          local aralikli = table.concat(Harfler(b), " ")
          Ekle(Uzunluk(aralikli) <= N and aralikli or b, true, 1)
          S[#S + 1] = {s = "", hiza = 0}
     end
     if (yazi.alici or "") ~= "" then
          Ekle("Sayın " .. yazi.alici .. ",")
          S[#S + 1] = {s = "", hiza = 0}
     end
     Ekle(yazi.metin or "")
     if (yazi.imza or "") ~= "" or (yazi.unvan or "") ~= "" then
          S[#S + 1] = {s = "", hiza = 0}
          if (yazi.imza or "") ~= "" then Ekle(yazi.imza, false, 2) end
          if (yazi.unvan or "") ~= "" then Ekle(yazi.unvan, false, 2) end
     end
     -- sondaki boş satırlar yazılmaz
     while #S > 0 and S[#S].s == "" do S[#S] = nil end

     local A = C.Ayar
     local olaylar = {{t = 0, tur = "besleme"}}
     local t = A.DaktiloBesleme
     local sayac = 0
     for i, sat in ipairs(S) do
          sat.harfler = Harfler(sat.s)
          local n = #sat.harfler
          sat.sutun = sat.hiza == 1 and math.floor((N - n) / 2) or (sat.hiza == 2 and (N - n) or 0)
          sat.basla = t
          sat.zaman = {}
          for j, h in ipairs(sat.harfler) do
               sayac = sayac + 1
               local d = A.DaktiloHiz * (0.55 + 0.9 * Titrek(sayac)) * carpan
               if sat.kirmizi then d = d * 1.6 end
               if h == " " then d = d * 0.75 end
               if j > 1 and NOKTALAMA[sat.harfler[j - 1]] then d = d + 0.16 * carpan end
               t = t + d
               sat.zaman[j] = t
               olaylar[#olaylar + 1] = {t = t, tur = h == " " and "bosluk" or "harf", satir = i, sira = j}
               if sat.sutun + j == N - 6 then olaylar[#olaylar + 1] = {t = t + 0.03, tur = "zil", satir = i} end
          end
          if n > 0 then t = t + 0.1 * carpan end
          sat.bitis = t
          if i < #S then
               olaylar[#olaylar + 1] = {t = t, tur = "satir", satir = i, bos = n == 0}
               t = t + A.DaktiloSatirSonu * (n == 0 and 0.6 or 1) * math.max(0.6, carpan)
          end
     end

     local damga = t + 0.55
     if (yazi.damga or "") ~= "" then olaylar[#olaylar + 1] = {t = damga, tur = "damga"} end
     local okuma = math.min(7, A.DaktiloOkuma + sayac * 0.015)
     return {satirlar = S, olaylar = olaylar, damga = damga, bitis = damga + 0.5, toplam = damga + 0.5 + okuma, harf = sayac, okuma = okuma}
end

function C.DaktiloBelge(yazi)
     local b = Kur(yazi, 1)
     local tavan = C.Ayar.DaktiloEnUzun
     if b.toplam > tavan then
          b = Kur(yazi, math.max(0.3, (tavan - b.okuma) / b.bitis))
     end
     return b
end

-- Sunucudan gelen / sunucuya verilen yazıyı sınırla
function C.YaziTemizle(y)
     y = istable(y) and y or {}
     local r = istable(y.renk) and y.renk or {}
     return {
          tur = C.YaziKirp(y.tur, 30), antet = C.YaziKirp(y.antet, 40), daire = C.YaziKirp(y.daire, 60),
          sayi = C.YaziKirp(y.sayi, 24), tarih = C.YaziKirp(y.tarih, 24), alici = C.YaziKirp(y.alici, 40),
          metin = C.YaziKirp(y.metin, C.Ayar.DaktiloMetin), imza = C.YaziKirp(y.imza, 40), unvan = C.YaziKirp(y.unvan, 46),
          damga = C.YaziKirp(y.damga, 18), muhur = C.YaziKirp(y.muhur, 16),
          renk = {math.Clamp(tonumber(r[1]) or 150, 0, 255), math.Clamp(tonumber(r[2]) or 22, 0, 255), math.Clamp(tonumber(r[3]) or 28, 0, 255)},
     }
end
