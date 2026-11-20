-- "addons\\sardonyaratik\\lua\\sardon_yaratik\\cl_4muhur.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- [sardon] yaratik :: bakım mührü (V2): dokuz düğümlü dairesel büyü mührü
--
-- E: kendi yaratığında mühür açılır. Basılı tutup imleci bir düğüme götürüp bırakmak ya da dokunup
-- tıklamak eylemi uygular; merkez ve düğüm araları nötrdür. Düğümler sabit yerlerdedir (üstten saat
-- yönünde Besle, Sev, Fırçala, Eğit, Topla, Yanıma al, Bin, Binişe aç, Kafese koy); kullanılamayan
-- düğüm sönük kalır, merkezde nedeni yazar. Ek ritüeller (omuz, eşleştirme, türün yeteneği) merkezdeki
-- "Diğer ritüeller" ile açılan alt mühürde; yem ve eş seçimi de alt mühürde aynı halkaya dizilir.
-- Yumurta (Isıt / Çevir), sepetteki yumurta, başkasının bineği ve yemlik aynı mührün sayfalarıdır.
-- Mühür açıkken yaratığın ayaklarının altında aynı yörünge yere izdüşer (3B), seçili yay oraya da döner.
-- Sunucu her eylemi yeniden denetler (sv_6ag.lua); burada sönük olmak güvenlik denetimi değildir.

-- 11-13 opt (kodmod): kare başı kurulan sabitler dosya yereline alındı
local OPT_V_0_0_30 = Vector(0, 0, 30)
local OPT_V_0_0_1p5 = Vector(0, 0, 1.5)
local Y = SardonYaratik
local A = Y.Ayar
local V = Y.V2
local R = V.R

local math_cos, math_sin, math_rad, math_sqrt, math_max, math_min, math_floor, math_Clamp =
     math.cos, math.sin, math.rad, math.sqrt, math.max, math.min, math.floor, math.Clamp

------------------------------------------------------------------------ yerleşim (tasarım px, halka merkezine göre)

local HALKA = 235
local VURUS = 40

-- düğüm i: açı -90 + i·40. Etiket ofseti (düğüm merkezinden) ve hizası tasarımdan (01_muhur_bakim.svg).
local SLOT = {}
for i = 0, 8 do
     local a = math_rad(-90 + i * 40)
     SLOT[i] = {x = math_cos(a) * HALKA, y = math_sin(a) * HALKA, aci = -90 + i * 40}
end
local ETIKET = {
     [0] = {0, -52, 1}, [1] = {78, -24, 0}, [2] = {70, -8, 0}, [3] = {62, 33, 0}, [4] = {23, 66, 1},
     [5] = {-23, 66, 1}, [6] = {-62, 33, 2}, [7] = {-70, -8, 2}, [8] = {-78, -24, 2},
}

local UST, ALT = -430, 465          -- tam düzenin dikey sınırları
local K_UST, K_ALT = -385, 410      -- kompakt düzen (başlık şeridi ve ESC satırı sıkışır)
local YAN = 395

-- ekran yerleşimi: mühür tek parça ölçeklenir; 0,8 kompakt eşiği
local function Yerlesim()
     local sw, sh = ScrW(), ScrH()
     local g = V.Guvenli()
     local s = math_max(V.Olcek(), 0.8)
     local kompakt = (ALT - UST) * s > sh - 2 * g
     local ust, alt = UST, ALT
     if kompakt then
          ust, alt = K_UST, K_ALT
          s = math_min(s, (sh - 2 * g) / (alt - ust))
          s = math_max(s, 0.62)
     end
     local cx = sw - 500 * s
     cx = math_Clamp(cx, g + YAN * s, sw - g - YAN * s)
     local cy = math_Clamp(sh * 0.5185, g - ust * s, sh - g - alt * s)
     return {s = s, cx = cx, cy = cy, kompakt = kompakt, w = sw, h = sh}
end

------------------------------------------------------------------------ yardımcılar

local function Benim(ent) return ent:GetSahip() == LocalPlayer() end

local function KullanTusu()
     local bag = input.LookupBinding("+use") or "e"
     local kod = input.GetKeyCode(bag)
     return kod and kod > 0 and input.IsKeyDown(kod)
end

local function Kalan(k, eylem, sure)
     return Y.EylemKalan and Y.EylemKalan(k, eylem, sure) or 0
end

local function Sure(sn)
     return Y.SureYazi(math.ceil(sn))
end

local function YaratikAdi(ent)
     local tur = ent:TurVeri()
     return (ent:GetAd() ~= "" and ent:GetAd()) or (tur and tur.ad) or "Yaratık"
end

local function AltSatir(ent)
     local tur = ent:TurVeri()
     local evre = (Y.Evreler[ent:GetEvre()] or {}).ad or ""
     local nr = Y.Nadirlik[ent:GetNadir()] or Y.Nadirlik[1]
     return (tur and tur.ad or "?") .. " · " .. evre .. " · " .. nr.ad
end

-- dört bakım şeridi: yüzde büyüdükçe iyi (Tokluk = ih.a: zamanla azalır, besleyince artar)
local function BakimSeritleri(ent, k)
     local a, t, sv = ent:IhtiyacCoz()
     return {
          {ikon = "feed", ad = "Tokluk", deger = a, renk = R.altin},
          {ikon = "brush", ad = "Temizlik", deger = t, renk = R.enerji},
          {ikon = "heart", ad = "Sevgi", deger = sv, renk = R.can},
          {ikon = "bond_rhombus", ad = "Bağ", deger = k and math.Round(k.bag or 0) or nil, renk = R.bag, orijinal = true},
     }
end

------------------------------------------------------------------------ sayfalar

local SAYFA = Y.MuhurSayfa or {}
-- dış sayfalar ([sardon] okul: NPC öğrenciyle konuşma) buraya kaydolur; bkz. Y.MuhurDisAc
Y.MuhurSayfa = SAYFA

-- kendi yaratığın: dokuz düğüm
SAYFA.bakim = function(ent)
     local id = ent:GetKimlik()
     local k = Y.BenimKayit(id)
     local tur = ent:TurVeri() or {rol = {}}
     local evre = ent:GetEvre()
     local agilda = ent:GetDurum() == Y.ENT_AGIL
     local a, t, sv = ent:IhtiyacCoz()
     local simdi = Y.SunucuZamani()
     local d = {}

     -- 0 Besle
     local yemler = Y.YemAdetleri()
     local turler = {}
     for _, yem in ipairs(Y.YemSirasi) do
          if (yemler[yem] or 0) > 0 and Y.Yemler[yem] then turler[#turler + 1] = yem end
     end
     local kb = Kalan(k, "besle", A.Bekleme.besle)
     local n = {ikon = "feed", ad = "Besle", deger = "Tokluk %" .. a, renk = R.altin, op = "besle"}
     if a >= 97 then
          n.neden = "Karnı tok"
     elseif #turler == 0 then
          n.neden = "Çantanda yem yok"
          n.aciklama = "Yaratık Bakıcısı'nın dükkânında satılır"
     elseif kb > 0 then
          n.neden = "Hâlâ çiğniyor · " .. Sure(kb)
     else
          n.aktif = true
          local tek = #turler == 1 and turler[1]
          if tek and Y.YemUygunluk(tur, tek) >= 1 then
               n.ek = tek
               n.aciklama = Y.Yemler[tek].ad .. " · sever"
          else
               n.sayfa = "yem"
               n.aciklama = "Yem seç · çantanda " .. #turler .. " tür"
          end
     end
     d[0] = n

     -- 1 Sev
     local ks = Kalan(k, "sev", A.Bekleme.sev)
     d[1] = {ikon = "heart", ad = "Sev", deger = "Sevgi %" .. sv, renk = R.can, op = "sev", aciklama = "Okşa: sevgi ve bağ artar",
          aktif = ks <= 0, neden = ks > 0 and ("Biraz önce sevildi · " .. Sure(ks)) or nil}

     -- 2 Fırçala
     local kf = Kalan(k, "firca", A.Bekleme.firca)
     local firca = Y.EsyaVarMi("yaratik_firca")
     n = {ikon = "brush", ad = "Fırçala", deger = "Temizlik %" .. t, renk = R.enerji, op = "firca", aciklama = "Kısa fırçalama oyunu"}
     if not firca then n.neden = "Fırça gerekli"
     elseif t >= 95 then n.neden = "Zaten tertemiz"
     elseif kf > 0 then n.neden = "Yeni fırçalandı · " .. Sure(kf)
     else n.aktif = true end
     d[2] = n

     -- 3 Eğit
     local ke = Kalan(k, "egit", A.Bekleme.egit)
     local sev, il = Y.Seviye(k and k.xp)
     n = {ikon = "train", ad = "Eğit", deger = "Seviye " .. sev .. " · %" .. math_floor(il * 100), renk = R.altin, op = "egit",
          aciklama = "Kısa eğitim oyunu; seviye ve bağ artar"}
     if sev >= A.EnFazlaSeviye then n.neden = "Eğitimi tamamladı"
     elseif ke > 0 then n.neden = "Dinleniyor · " .. Sure(ke)
     else n.aktif = true end
     d[3] = n

     -- 4 Topla
     local dolu = k and Y.KeseDolu(k)
     local adet = 0
     for _, x in pairs(k and k.kese or {}) do adet = adet + x end
     local galleon = k and k.keseG or 0
     local icerik = adet > 0 and (adet .. " ürün") or ""
     if galleon > 0 then icerik = (icerik ~= "" and (icerik .. " · ") or "") .. galleon .. " galleon" end
     d[4] = {ikon = "collect", ad = "Topla", deger = dolu and ("Kesede " .. icerik) or "Kese boş", renk = R.altin, op = "topla",
          aciklama = "Kesesindeki ürünler envanterine", aktif = dolu, neden = not dolu and "Kese boş" or nil}

     -- 5 Yanıma al (bağlama göre: gönder / omza al / ağıldan çıkar)
     if agilda then
          local ag = k and k.agil
          local yuzde = ag and (ag.sure or 0) > 0 and math_floor(math_Clamp((ag.huzur or 0) / ag.sure, 0, 1) * 100)
          d[5] = {ikon = "follow", ad = "Ağıldan çıkar", deger = yuzde and ("Ağıl %" .. yuzde) or "Ağılda", renk = R.can, op = "agil_ayir",
               aciklama = "Çift ayrılır, ağıl süresi sıfırlanır", aktif = true, uyari = true}
     elseif not tur.rol.takip and tur.rol.omuz then
          d[5] = {ikon = "follow", ad = "Omzuna al", deger = "Omuzda taşınır", renk = R.olumlu, op = "omuz",
               aciklama = tur.ad .. " yürümez; omzunda gezer", aktif = true}
     elseif k and k.durum == Y.D.TAKIP then
          d[5] = {ikon = "follow", ad = "Gönder", deger = "Yanında", renk = R.olumlu, op = "gonder", aciklama = "Vivaryuma döner", aktif = true}
     else
          local diger = Y.Benim.takip and Y.Benim.takip ~= id and Y.BenimKayit(Y.Benim.takip)
          d[5] = {ikon = "follow", ad = "Yanıma al", deger = "Seni takip eder", renk = R.olumlu, op = "cagir", aktif = tur.rol.takip and true or false,
               aciklama = diger and ((diger.ad or (Y.Turler[diger.tur] or {}).ad or "Yanındaki") .. " vivaryuma döner") or "Gittiğin yere seninle gelir",
               neden = not tur.rol.takip and "Yürüyemez" or nil}
     end

     -- 6 Bin (hipogrif sahibine bağ 85'in altında önce selam ister: o zaman düğüm selamdır)
     local baygin = k and (k.baygin or 0) > simdi and k.baygin - simdi
     n = {ikon = "ride", ad = "Bin", renk = R.altin, op = "bin"}
     if not tur.rol.binek then n.neden = "Binek değil"
     elseif evre < 3 then n.neden = "Yetişkin olmalı"
     elseif agilda then n.neden = "Ağılda"
     elseif baygin then n.neden = "Kendine geliyor · " .. Sure(baygin)
     elseif ent:GetTur() == "hippogriff" and not ((k and (k.bag or 0) >= 85) or (k and (k.selam or 0) > simdi)) then
          n.ad, n.op, n.ikon = "Selam ver", "selam", "hippogriff"
          n.deger = "Bağ %" .. math.Round(k and k.bag or 0) .. " · 85'te gerekmez"
          n.aciklama = "Hipogrif önce selamını ister: göz teması kur, eğil"
          n.aktif = true
     else
          n.aktif = true
          n.deger = k and (k.selam or 0) > simdi and ("Selam geçerli · " .. Sure(k.selam - simdi)) or "Sırtına bin"
          local inTus = Y.BinekInTusu and V.KodAdi(Y.BinekInTusu(), "G") or "G"
          n.aciklama = inTus .. " ile inersin"
     end
     d[6] = n

     -- 7 Binişe aç: başkalarının binme izni (sunucuda tek izin: binisAcik)
     local acik = k and k.binisAcik and true or false
     n = {ikon = "share_ride", ad = acik and "Binişi kapat" or "Binişe aç", alt = acik and "Açık" or "Kapalı", acik = acik,
          renk = R.bag, op = "binis_izin", deger = acik and "Başkaları da binebilir" or "Yalnız sen binebilirsin"}
     if not tur.rol.binek then n.neden, n.alt, n.ad = "Binek değil", nil, "Binişe aç"
     elseif agilda then n.neden = "Ağılda"
     else
          n.aktif = true
          n.aciklama = acik and "İzni kaldır" or (ent:GetTur() == "hippogriff" and "Hipogrif yine de selam bekler" or "Başkaları da binebilsin")
     end
     d[7] = n

     -- 8 Kafese koy
     local kafes = Y.EsyaVarMi("yaratik_kafes", true)
     d[8] = {ikon = "cage", ad = "Kafese koy", renk = R.ikincil, op = "kafes", deger = "Taşı ya da devret",
          aciklama = "Boş bir Taşıma Kafesi'ne girer", aktif = kafes and not agilda,
          neden = agilda and "Ağılda" or (not kafes and "Boş kafes gerekli" or nil)}

     -- ek ritüeller
     local ek = {}
     if tur.rol.omuz and tur.rol.takip and not agilda then
          ek[#ek + 1] = {ikon = "feather", ad = "Omzuna al", deger = "Omuzda taşınır", renk = R.olumlu, op = "omuz", aktif = true,
               aciklama = "Yanında yürümek yerine omzunda gezer"}
     end
     if evre >= 3 and ent:GetTur() ~= "phoenix" and not agilda then
          local esler = Y.EsAdaylari(ent)
          local U = A.Ureme
          local mutlu = (a + t + sv) / 3
          local dinlen = k and (k.sonUreme or 0) + U.Bekleme - simdi or 0
          n = {ikon = "heart", ad = "Eşleştir", renk = R.can, op = "esles", deger = #esler > 0 and (#esler .. " uygun eş yakında") or "Yakında eş yok",
               aciklama = "Çiftleşme Ağılı'nda ~" .. (U.Sure[tur.sinif or 3] or 18) .. " saat kalırlar"}
          if dinlen > 0 then n.neden = "Dinleniyor · " .. Sure(dinlen)
          elseif mutlu < U.Mutluluk then n.neden = "Mutluluk %" .. U.Mutluluk .. " olmalı"
          elseif (k and k.bag or 0) < U.Bag then n.neden = "Bağ %" .. U.Bag .. " olmalı"
          elseif #esler == 0 then n.neden = "Yakında karşı cins yetişkin yok"
          else n.aktif, n.sayfa, n.esler = true, "es", esler end
          ek[#ek + 1] = n
     end
     if evre >= 2 and not agilda then
          local tid = ent:GetTur()
          local YT = A.Yetenek
          if tid == "niffler" then
               local yaninda = k and k.durum == Y.D.TAKIP
               local kal = Kalan(k, "yankesici", YT.Yankesici.Bekleme)
               ek[#ek + 1] = {ikon = "collect", ad = "Yankesicilik", renk = R.altin, op = "yankesici", deger = "Yakınındakinin kesesi",
                    aciklama = "Yakalanırsa sen sorumlusun", aktif = yaninda and kal <= 0,
                    neden = not yaninda and "Yanında olmalı" or (kal > 0 and ("Dinleniyor · " .. Sure(kal)) or nil)}
          elseif tid == "fwooper" then
               local sus = k and ((k.susturma or 0) - simdi) or 0
               ek[#ek + 1] = {ikon = "cry", ad = "Silencio", renk = R.enerji, op = "sustur", deger = sus > 0 and ("Susuk · " .. Sure(sus)) or "Şarkısı delirtir",
                    aciklama = "Asayla iki gün susturur", aktif = sus <= 0, neden = sus > 0 and "Zaten susturulmuş" or nil}
          elseif tid == "jobberknoll" then
               local sayi = k and k.tanikN or 0
               ek[#ek + 1] = {ikon = "cry", ad = "Dinle", renk = R.bag, op = "dinle", deger = sayi > 0 and (sayi .. " satır duydu") or "Bir şey duymadı",
                    aciklama = "Yanında söylenenleri hatırlar", aktif = sayi > 0, neden = sayi <= 0 and "Bir şey duymadı" or nil}
          end
     end

     -- öneri: en düşük bakım ihtiyacı (yalnız yapılabiliyorsa), yoksa dolu kese
     local oneri
     local enDusuk = 60
     for _, o in ipairs({{0, a}, {2, t}, {1, sv}}) do
          if d[o[1]].aktif and o[2] < enDusuk then oneri, enDusuk = o[1], o[2] end
     end
     if not oneri and d[4].aktif then oneri = 4 end

     return {
          ust = agilda and "ÇİFTLEŞME AĞILI" or "YARATIKLA BAĞ KUR", ad = YaratikAdi(ent), alt = AltSatir(ent),
          dugum = d, ek = #ek > 0 and ek or nil, oneri = oneri, serit = BakimSeritleri(ent, k), kapat = "Bağı kapat",
     }
end

-- yem seçimi: çantadaki türler, sevdikleri önce
SAYFA.yem = function(ent)
     local tur = ent:TurVeri()
     local yemler = Y.YemAdetleri()
     local liste = {}
     for _, yem in ipairs(Y.YemSirasi) do
          if (yemler[yem] or 0) > 0 and Y.Yemler[yem] then liste[#liste + 1] = {yem = yem, u = Y.YemUygunluk(tur, yem)} end
     end
     table.sort(liste, function(x, y) return x.u > y.u end)
     local d = {}
     for i, l in ipairs(liste) do
          if i > 9 then break end
          local yv = Y.Yemler[l.yem]
          d[i - 1] = {ikon = "feed", ad = yv.ad, alt = yemler[l.yem] .. " adet", op = "besle", ek = l.yem, aktif = true,
               renk = l.u >= 1 and R.altin or (l.u > 0 and R.ikincil or R.can), uyari = l.u <= 0,
               deger = l.u >= 1 and "Sever" or (l.u > 0 and "Yarım etki" or "Sevmez"),
               aciklama = l.u <= 0 and "Tiksinir; bağ ve sevgi düşer" or ("Tokluk +" .. math_floor(yv.aclik * math_max(l.u, 0)))}
     end
     local a = ent:IhtiyacCoz()
     return {ust = "YEM SEÇ", ad = YaratikAdi(ent), alt = (tur and Y.BesinYazi and Y.BesinYazi(tur)) or AltSatir(ent), dugum = d,
          oneri = (liste[1] and liste[1].u >= 1) and 0 or nil, serit = BakimSeritleri(ent, Y.BenimKayit(ent:GetKimlik())),
          geri = true, kapat = "Geri", bos = {baslik = "Besle", satir = "Tokluk %" .. a}}
end

-- eş seçimi (EsAdaylari: yakındaki aynı tür, karşı cins yetişkinler)
SAYFA.es = function(ent)
     local esler = Y.EsAdaylari(ent)
     local d = {}
     for i, e in ipairs(esler) do
          if i > 9 then break end
          d[i - 1] = {ikon = "heart", ad = e.ad, alt = e.alt, op = "esles", ek = e.ek, aktif = true, renk = R.can,
               deger = e.alt, aciklama = "Ağıla birlikte girerler; yumurta senin olur"}
     end
     return {ust = "EŞ SEÇ", ad = YaratikAdi(ent), alt = AltSatir(ent), dugum = d, geri = true, kapat = "Geri",
          serit = BakimSeritleri(ent, Y.BenimKayit(ent:GetKimlik())), bos = {baslik = "Eşleştir", satir = #esler .. " aday"}}
end

-- ek ritüeller: ana sayfanın listesi sırayla halkaya
SAYFA.diger = function(ent, ebeveyn)
     local d = {}
     for i, n in ipairs(ebeveyn and ebeveyn.ek or {}) do
          if i > 9 then break end
          d[i - 1] = n
     end
     return {ust = "DİĞER RİTÜELLER", ad = YaratikAdi(ent), alt = AltSatir(ent), dugum = d, geri = true, kapat = "Geri",
          serit = BakimSeritleri(ent, Y.BenimKayit(ent:GetKimlik())), bos = {baslik = "Ritüeller", satir = table.Count(d) .. " ritüel"}}
end

-- kuluçkadaki yumurta: Isıt (sol üst), Çevir (sağ üst)
local function YumurtaSeritleri(ent, k)
     local K = A.Kulucka
     local ilerleme = math_Clamp((CurTime() - ent:GetKBas()) / math_max(ent:GetKSure(), 1), 0, 1)
     local sicak = Y.KuluckaSicakNow(ent)
     local cv = k and k.ku and k.ku.cevir or 0
     local kalite = k and k.ku and Y.KuluckaKalite and Y.KuluckaKalite(k)
     return {
          {ikon = "hatch", ad = "Kuluçka", deger = math_floor(ilerleme * 100), renk = R.altin},
          {ikon = "temperature", ad = sicak < K.iyiAlt and "Soğuk" or (sicak > K.iyiUst and "Sıcak" or "İdeal"), deger = math_floor(sicak),
               renk = sicak < K.iyiAlt and R.enerji or (sicak > K.iyiUst and R.can or R.olumlu), sicaklik = true},
          {ikon = "egg", ad = "Çevrildi", deger = cv, en = K.cevirSayisi, renk = R.yazi},
          {ikon = "bond_rhombus", ad = "Kalite", deger = kalite and math_floor(kalite * 100) or nil, renk = R.bag, orijinal = true},
     }
end

SAYFA.yumurta = function(ent)
     local k = Y.BenimKayit(ent:GetKimlik())
     local tur = ent:TurVeri() or {}
     local K = A.Kulucka
     local sicak = Y.KuluckaSicakNow(ent)
     local d = {}
     local kis = Kalan(k, "isit", A.Bekleme.isit)
     d[8] = {ikon = "temperature", ad = "Isıt", renk = R.can, op = "isit", deger = "Sıcaklık " .. math_floor(sicak),
          aciklama = sicak > K.iyiUst and "Zaten sıcak; ideal aralık " .. K.iyiAlt .. "–" .. K.iyiUst or ("Asayla mangaldan ısı aktarır; ideal " .. K.iyiAlt .. "–" .. K.iyiUst),
          aktif = kis <= 0, neden = kis > 0 and ("Biraz bekle · " .. Sure(kis)) or nil, uyari = sicak > K.iyiUst}
     local cv = k and k.ku and k.ku.cevir or 0
     local aralik = math_floor(Y.KuluckaSure({tur = ent:GetTur()}) / (K.cevirSayisi + 1))
     local kc = Kalan(k, "cevir", aralik)
     d[1] = {ikon = "egg", ad = "Çevir", renk = R.altin, op = "cevir", deger = "Çevrildi " .. cv .. "/" .. K.cevirSayisi,
          aciklama = "Düzenli çevirmek kuluçka kalitesini artırır", aktif = kc <= 0 and cv < K.cevirSayisi,
          neden = cv >= K.cevirSayisi and "Yeterince çevrildi" or (kc > 0 and ("Erken · " .. Sure(kc)) or nil)}
     local kalan = math_max(0, ent:GetKBas() + ent:GetKSure() - CurTime())
     local oneri = (d[1].aktif and 1) or ((d[8].aktif and sicak < K.iyiAlt) and 8) or nil
     return {ust = "KULUÇKA", ad = (tur.ad or "?") .. " Yumurtası", alt = kalan > 60 and ("Çatlamaya " .. Sure(kalan)) or "Çatlamak üzere",
          dugum = d, oneri = oneri, serit = YumurtaSeritleri(ent, k), kapat = "Kapat"}
end

-- ağıldaki saman sepetinde bekleyen yumurta
SAYFA.kase = function(ent)
     local k = Y.BenimKayit(ent:GetKimlik())
     local tur = ent:TurVeri() or {}
     local kalan = k and k.kase and math_max(0, (k.kase.z or 0) + A.Ureme.KaseBekle - Y.SunucuZamani())
     local d = {[4] = {ikon = "collect", ad = "Yumurtayı al", renk = R.altin, op = "kase_al", aktif = true, deger = "Envanterine",
          aciklama = kalan and ("Alınmazsa " .. Sure(kalan) .. " sonra soğur") or "Sepette bekliyor"}}
     return {ust = "SAMAN SEPETİ", ad = (tur.ad or "?") .. " Yumurtası", alt = "Çiftleşme Ağılı'nda", dugum = d, oneri = 4, kapat = "Kapat"}
end

-- başkasının bineği: sev, (hipogrifse) selam, bin
SAYFA.yabanci = function(ent)
     local tur = ent:TurVeri() or {rol = {}}
     local sahip = ent:GetSahip()
     local d = {[1] = {ikon = "heart", ad = "Sev", renk = R.can, op = "sev", aktif = true, deger = "Okşa", aciklama = "Başkasının yaratığı: yalnız sevgi gösterirsin"}}
     if tur.rol.binek and ent:GetEvre() >= 3 then
          if ent:GetTur() == "hippogriff" then
               d[7] = {ikon = "hippogriff", ad = "Selam ver", renk = R.altin, op = "selam", aktif = true, deger = "Göz teması + eğil",
                    aciklama = "Selamsız binmeye kalkanı fırlatır"}
          end
          d[6] = {ikon = "ride", ad = "Bin", renk = R.altin, op = "bin", aktif = true, deger = "Sahibi izin verdiyse",
               aciklama = ent:GetTur() == "hippogriff" and "Önce selam vermiş olmalısın" or "Sırtına bin"}
     end
     return {ust = IsValid(sahip) and Y.Buyuk(sahip:Nick()) or "BAŞKASININ YARATIĞI", ad = YaratikAdi(ent), alt = AltSatir(ent), dugum = d, kapat = "Kapat"}
end

-- yemlik: çantadaki yem türleri; tıklanınca o türün sığdığı kadarı yemliğe
SAYFA.yemlik = function()
     local stok = (Y.Benim and Y.Benim.yemlik) or {}
     local canta = Y.YemAdetleri()
     local d, serit = {}, {}
     local i = 0
     for _, yem in ipairs(Y.YemSirasi) do
          local n, st = canta[yem] or 0, stok[yem] or 0
          if (n > 0 or st > 0) and Y.Yemler[yem] then
               d[i] = {ikon = "feed", ad = Y.Yemler[yem].ad, alt = st .. "/" .. A.YemlikSiniri, op = "yemlik_koy", ek = yem, renk = R.altin,
                    deger = "Çantada " .. n, aciklama = "Sığdığı kadarı yemliğe konur",
                    aktif = n > 0 and st < A.YemlikSiniri, neden = n <= 0 and "Çantanda yok" or (st >= A.YemlikSiniri and "Yemlikte dolu" or nil)}
               i = i + 1
               if #serit < 4 then serit[#serit + 1] = {ikon = "feed", ad = Y.Yemler[yem].ad, deger = st, en = A.YemlikSiniri, renk = R.altin} end
          end
     end
     if i == 0 then
          d[0] = {ikon = "feed", ad = "Yem yok", renk = R.ikincil, op = "", neden = "Çantanda yem yok", aciklama = "Yaratık Bakıcısı'nın dükkânında satılır"}
     end
     return {ust = "YEMLİK", ad = "Yemlik", alt = "Senin stoğun · sen yokken yaratıkların buradan yer", dugum = d, serit = #serit > 0 and serit or nil, kapat = "Kapat"}
end

------------------------------------------------------------------------ panel

local PANEL = {}

function PANEL:Init()
     self:SetSize(ScrW(), ScrH())
     self:SetPos(0, 0)
     self:MakePopup()
     self:SetKeyboardInputEnabled(false)
     self.acilis = RealTime()
     self.tutuyor = KullanTusu()
     self.L = Yerlesim()
     self.parlak = {}        -- düğüm başına üzerine gelme geçişi 0..1
     for i = 0, 8 do self.parlak[i] = 0 end
     self.yayAci = nil
     self.sayfaT = RealTime()
     input.SetCursorPos(math.Round(self.L.cx), math.Round(self.L.cy))
     surface.PlaySound("ui/buttonrollover.wav")
end

-- ent: yaratık (yoksa yer: yemlik noktası); tur: sayfa adı
function PANEL:Kur(ent, tur, yer)
     self.ent, self.yer = ent, yer
     self.kok = tur
     self.yigin = {}
     self:SayfaAc(tur, true)
     -- açılış: yörüngede yoğunlaşan birkaç kıvılcım
     if not V.Sade() then
          local L = self.L
          for i = 1, 12 do
               local a = math.random() * math.pi * 2
               local r = HALKA * L.s * (1.05 + math.random() * 0.12)
               V.Parcacik("panel", {x = L.cx + math_cos(a) * r, y = L.cy + math_sin(a) * r, vx = -math_sin(a) * 40 * L.s - math_cos(a) * 30 * L.s,
                    vy = math_cos(a) * 40 * L.s - math_sin(a) * 30 * L.s, omur = 0.7 + math.random() * 0.3, boy = 13 * L.s, boy2 = 0,
                    renk = R.altin, a = 0.9, tur = (i % 3 == 0) and "isik" or "yildiz", don = 90, sur = 2})
          end
     end
end

function PANEL:SayfaAc(tur, ilk)
     if not ilk then self.yigin[#self.yigin + 1] = {tur = self.tur, veri = self.veri} end
     self.tur = tur
     self.ebeveyn = self.veri
     self.secili, self.basili = nil, nil
     self.sayfaT = RealTime()
     self:Yenile()
     if not ilk then surface.PlaySound("ui/buttonclick.wav") end
end

function PANEL:Geri()
     local onceki = table.remove(self.yigin)
     if not onceki then self:Kapat() return end
     self.tur = onceki.tur
     self.secili, self.basili = nil, nil
     self.sayfaT = RealTime()
     self:Yenile()
     surface.PlaySound("ui/buttonclick.wav")
end

function PANEL:Yenile()
     local f = SAYFA[self.tur]
     if not f then return end
     if self.ent ~= nil and not IsValid(self.ent) then return end
     -- alt sayfa ebeveynin taze verisinden kurulur (bekleme süreleri bayatlamasın)
     local ust = self.yigin[#self.yigin]
     local ebeveyn = ust and SAYFA[ust.tur] and SAYFA[ust.tur](self.ent)
     self.veri = f(self.ent, ebeveyn)
     self.yenileT = RealTime()
end

function PANEL:Kapat()
     if self.kapaniyor then return end
     self.kapaniyor = RealTime()
     self:SetMouseInputEnabled(false)
     self:SetKeyboardInputEnabled(false)
     V.PanelParcaciklariDevret()
end

-- (mx, my) altındaki hedef: düğüm (0..8), "ek" (Diğer / Geri) ya da nil. Önce gerçek vuruş alanı:
-- düğüm dairesi (40 px · ölçek) ve etiket dikdörtgeni; birden çoğu tutarsa en yakını.
function PANEL:Bul(mx, my)
     local L, v = self.L, self.veri
     if not v then return end
     local s = L.s
     local enI, enD
     for i = 0, 8 do
          local n = v.dugum[i]
          if n then
               local x, y = L.cx + SLOT[i].x * s, L.cy + SLOT[i].y * s
               local dx, dy = mx - x, my - y
               local d = math_sqrt(dx * dx + dy * dy)
               local icinde = d <= VURUS * s
               if not icinde and n.etiketKutu then
                    local k = n.etiketKutu
                    icinde = mx >= k[1] and mx <= k[3] and my >= k[2] and my <= k[4]
               end
               if icinde and (not enD or d < enD) then enI, enD = i, d end
          end
     end
     if enI then return enI end
     local p = self.ekKutu
     if p and mx >= p[1] and mx <= p[3] and my >= p[2] and my <= p[4] then return "ek" end
end

-- eylemi uygula: tek istek, sonra mühür kapanır (alt sayfa açanlar hariç)
function PANEL:Sec(i)
     if self.kapaniyor or self.gonderildi then return end
     local n
     if i == "ek" then
          local ek = self.veri.ek
          if self.veri.geri then self:Geri() return end
          if not ek then return end
          if #ek > 1 then self:SayfaAc("diger") return end
          n = ek[1]
     else
          n = self.veri and self.veri.dugum[i]
     end
     if not n then return end
     if not n.aktif then
          self.red = {i = i, t = RealTime()}
          surface.PlaySound("buttons/button10.wav")
          return
     end
     if n.sayfa then
          self:SayfaAc(n.sayfa)
          return
     end
     if not n.op or n.op == "" then return end
     self.gonderildi = true
     self.basildi = {i = i, t = RealTime()}
     surface.PlaySound("ui/buttonclickrelease.wav")

     local L = self.L
     local x, y
     if i == "ek" then
          x, y = L.cx, L.cy + 142 * L.s
     else
          x, y = L.cx + SLOT[i].x * L.s, L.cy + SLOT[i].y * L.s
     end
     local renk = n.renk or R.altin
     V.Kivilcim("panel", x, y, R.altin, 8, 90, 0.6, 15, L.s)
     -- eylemin yaratığa ulaştığını gösteren kuyruklu yıldız
     local hedef = self:HedefNokta()
     if hedef then
          V.Kuyruklu("hud", x, y, hedef.x, hedef.y, renk, 0.45, L.s, function(hx, hy)
               V.Kivilcim("hud", hx, hy, renk, 10, 70, 0.7, 14, L.s)
          end)
     end
     Y.V2.ZeminNabiz = RealTime()
     if self.dis then
          self.dis.islem(n, self)
     elseif self.yer then
          Y.Islem(n.op, 0, n.ek)
     else
          Y.Islem(n.op, self.ent:GetKimlik(), n.ek)
     end
     self:Kapat()
end

-- yaratığın (ya da yemliğin) ekrandaki gövde noktası
function PANEL:HedefNokta()
     local p
     if self.yer then
          p = self.yer + OPT_V_0_0_30
     elseif IsValid(self.ent) then
          local _, _, h = Y.VarlikKutu(self.ent)
          p = self.ent:CizimKonumu() + Vector(0, 0, (h or 30) * 0.6)
     end
     if not p then return end
     local sc = p:ToScreen()
     if sc.visible then return sc end
end

function PANEL:Think()
     if self.kapaniyor then
          if RealTime() - self.kapaniyor > V.SURE.cikis then self:Remove() end
          return
     end
     local ply = LocalPlayer()
     if not IsValid(ply) or not ply:Alive() or (Y.Biniyor and Y.Biniyor(ply)) then self:Kapat() return end
     if self.dis then
          -- dış sayfa: hedefin yeri her karede sahibinden (yürüyen aktör); yoksa kapanır
          local p = self.dis.konum and self.dis.konum()
          if not p then self:Kapat() return end
          self.yer = p
     end
     if self.yer then
          if self.yer:Distance(ply:GetPos()) > A.EtkilesimMesafe + 100 then self:Kapat() return end
     elseif not IsValid(self.ent) or not Y.Erisimde(self.ent) then
          self:Kapat()
          return
     end
     if self.tur == "yumurta" and IsValid(self.ent) and self.ent:GetEvre() > 0 then self:Kapat() return end

     -- canlı veri (bekleme süreleri, eşya) dörtte bir saniyede bir
     if RealTime() - (self.yenileT or 0) > 0.25 then self:Yenile() end

     -- ESC: alt sayfada geri, ana sayfada kapat (oyun menüsü açılmasın)
     local esc = input.IsKeyDown(KEY_ESCAPE)
     if esc and not self.escOnce then
          if gui.IsGameUIVisible() then gui.HideGameUI() end
          if #self.yigin > 0 then self:Geri() else self:Kapat() end
     end
     self.escOnce = esc

     -- basılı tut / bırak: seçim üzerinde bırakılırsa uygula; hızlı dokunuşta mühür açık kalır
     if self.tutuyor and not KullanTusu() then
          self.tutuyor = false
          if RealTime() - self.acilis > 0.25 and self.secili ~= nil then self:Sec(self.secili) end
     end
end

function PANEL:OnMousePressed(kod)
     if self.kapaniyor then return end
     if kod == MOUSE_RIGHT then
          if #self.yigin > 0 then self:Geri() else self:Kapat() end
          return
     end
     if kod == MOUSE_LEFT then
          self.tutuyor = false
          self.basili = self.secili
     end
end

function PANEL:OnMouseReleased(kod)
     if kod ~= MOUSE_LEFT or self.kapaniyor then return end
     local b = self.basili
     self.basili = nil
     if b ~= nil and b == self.secili then self:Sec(b) end
end

function PANEL:OnRemove()
     if Y.Radyal == self then Y.Radyal = nil end
     V.PanelParcaciklariDevret()
end

------------------------------------------------------------------------ çizim

local function Alfa(self)
     local simdi = RealTime()
     if self.kapaniyor then return 1 - math_Clamp((simdi - self.kapaniyor) / V.SURE.cikis, 0, 1) end
     if V.Sade() then return 1 end
     return V.Yumusak((simdi - self.acilis) / V.SURE.giris)
end

local GLIF = 88 / 96 -- durum dokusunun düğüm başına boyu (96 px kaynak, 88 px çizim)

local function Glif(ad, x, y, s, a)
     local b = 96 * GLIF * s
     if V.Doku(ad, x - b / 2, y - b / 2, b, b, nil, a) then return end
     -- yedek: koyu daire + ince halka
     local r = 39 * s
     V.Yay(x, y, r * 0.5, r, 0, math.pi * 2, R.zemin, a * 0.8)
     V.Yay(x, y, r, 1, 0, math.pi * 2, ad == "glyph_disabled" and R.sonuk or R.altin, a * 0.6)
end

function PANEL:DugumCiz(i, n, a, dt, gecis)
     local L = self.L
     local s = L.s
     local x, y = L.cx + SLOT[i].x * s, L.cy + SLOT[i].y * s
     local uzerinde = self.secili == i
     self.parlak[i] = V.Sade() and (uzerinde and 1 or 0) or V.Yaklas(self.parlak[i], uzerinde and 1 or 0, 1 / V.SURE.ustune * 2.2, dt)
     local p = self.parlak[i]
     local ga = a * gecis

     -- durum: varsayılan → (öneri: hover) → seçili; basılıyken pressed; kullanılamayan disabled
     if not n.aktif then
          Glif("glyph_disabled", x, y, s, ga)
          if p > 0.01 then Glif("glyph_default", x, y, s, ga * p * 0.6) end
     else
          Glif("glyph_default", x, y, s, ga)
          if self.veri.oneri == i then
               local baska = type(self.secili) == "number" and self.secili ~= i
               Glif("glyph_hover", x, y, s, ga * (1 - p) * (baska and 0.25 or 0.75))
          end
          if self.basili == i and uzerinde then
               Glif("glyph_pressed", x, y, s, ga)
          elseif p > 0.01 then
               Glif("glyph_selected", x, y, s, ga * p)
          end
          -- basılı tutarken bırakınca uygulanacak düğüm
          if uzerinde and self.tutuyor then Glif("glyph_focus", x, y, s, ga * 0.9) end
     end

     -- ikon
     local renk = not n.aktif and R.ikincil or (n.uyari and R.can or R.altin)
     V.Ikon(n.ikon or "feather", x, y, 48 * s, renk, ga * (n.aktif and 1 or 0.85))

     -- izin işareti (Binişe aç): açıkken glifin köşesinde küçük yeşil baklava (alt etiket de "Açık")
     if n.acik and n.alt then
          V.Baklava(x + 26 * s, y - 26 * s, 4 * s, R.olumlu, ga, true)
     end

     -- etiket ve alt etiket
     local e = ETIKET[i]
     local f = V.Font("govde", 19, s)
     local ex, ey = x + e[1] * s, y + e[2] * s
     local yRenk = n.aktif and R.yazi or R.ikincil
     local metin = V.Kisalt(n.ad, f, 170 * s)
     local w = V.Yazi(metin, f, ex, ey, yRenk, ga * (n.aktif and 1 or 0.9), e[3])
     local x0 = e[3] == 1 and ex - w / 2 or (e[3] == 2 and ex - w or ex)
     n.etiketKutu = {x0 - 6 * s, ey - 20 * s, x0 + w + 6 * s, ey + 6 * s}
     if n.alt then
          local f2 = V.Font("govde", 12, s)
          V.Yazi(V.Kisalt(n.alt, f2, 170 * s), f2, ex, ey + 21 * s, n.acik and R.olumlu or R.ikincil, ga, e[3])
          n.etiketKutu[4] = ey + 24 * s
     end

     -- reddedilen tıklama: düğümün çevresinde kısa, sakin bir kırmızı yay (sallama yok)
     local red = self.red
     if red and red.i == i then
          local g = (RealTime() - red.t) / 0.6
          if g < 1 then V.Yay(x, y, 44 * s, 1.5 * s, 0, math.pi * 2, R.can, ga * (1 - g) * 0.8) end
     end
end

function PANEL:MerkezCiz(a)
     local L, v = self.L, self.veri
     local s, cx, cy = L.s, L.cx, L.cy
     local n
     if self.secili == "ek" then
          n = not v.geri and v.ek and #v.ek == 1 and v.ek[1]
     elseif self.secili ~= nil then
          n = v.dugum[self.secili]
     end
     local en = 300 * s

     if n then
          local aktif = n.aktif
          V.Ikon(n.ikon or "feather", cx, cy - 75 * s, 62 * s, aktif and (n.uyari and R.can or R.altin) or R.ikincil, a)
          local fb = V.Font("baslik", 36, s)
          V.Yazi(V.Kisalt(n.baslik or n.ad, fb, en), fb, cx, cy - 8 * s, aktif and R.yazi or R.ikincil, a, 1)
          if n.deger then
               local f = V.Font("govde", 17, s)
               V.Yazi(V.Kisalt(n.deger, f, en), f, cx, cy + 28 * s, R.altin, a, 1)
          end
          if n.aciklama then
               local f = V.Font("govde", 15, s)
               local satirlar = V.Sar(n.aciklama, f, en, 2)
               for j, sat in ipairs(satirlar) do
                    V.Yazi(sat, f, cx, cy + (59 + (j - 1) * 19 - (#satirlar - 1) * 6) * s, R.ikincil, a, 1)
               end
          end
          if not aktif then
               -- gerçek neden (Fırça gerekli, Kese boş, bekleme...)
               local f = V.Font("govde", 15, s)
               local red = self.red and self.red.i == self.secili and RealTime() - self.red.t < 0.6
               V.Yazi(V.Kisalt(n.neden or "Şu an olmaz", f, en), f, cx, cy + 100 * s, red and R.yazi or R.can, a, 1)
          else
               local tus, yazi
               if self.tutuyor then
                    tus, yazi = V.TusAdi("+use", "E"), "Bırak · uygula"
               else
                    tus, yazi = "SOL TIK", n.sayfa and "Seç" or "Uygula"
               end
               local f = V.Font("govde", 12, s)
               local tw = math_max(25 * s, V.Olcu(tus, f) + 16 * s)
               local yw = V.Olcu(yazi, V.Font("govde", 13, s))
               local x0 = cx - (tw + 11 * s + yw) / 2
               V.TusKapagi(x0, cy + 84 * s, tw, 23 * s, s, a)
               V.Yazi(tus, f, x0 + tw / 2, cy + 100 * s, R.yazi, a, 1)
               V.Yazi(yazi, V.Font("govde", 13, s), x0 + tw + 11 * s, cy + 101 * s, R.ikincil, a, 0)
          end
     else
          -- seçim yok: kısa yönlendirme (ve varsa öneri)
          local bos = v.bos or {}
          local o = v.oneri and v.dugum[v.oneri]
          V.Ikon(o and o.ikon or "feather", cx, cy - 66 * s, 44 * s, R.altin, a * 0.75)
          local fb = V.Font("baslik", 30, s)
          V.Yazi(V.Kisalt(bos.baslik or (o and ("Öneri: " .. o.ad)) or "Bakım", fb, en), fb, cx, cy - 4 * s, R.yazi, a * 0.92, 1)
          local f = V.Font("govde", 15, s)
          local satir = bos.satir or (o and o.deger) or (self.tur == "bakim" and "Bütün ihtiyaçları karşılanmış") or nil
          if satir then V.Yazi(V.Kisalt(satir, f, en), f, cx, cy + 26 * s, o and R.altin or R.olumlu, a, 1) end
          V.Yazi(self.tutuyor and "Bir glife götür ve bırak" or "Bir glif seç", f, cx, cy + 54 * s, R.ikincil, a, 1)
     end

     -- Diğer ritüeller / Geri
     self.ekKutu = nil
     if v.ek or v.geri then
          local f = V.Font("govde", 14, s)
          local tek = not v.geri and #v.ek == 1 and v.ek[1]
          local yazi = v.geri and "Geri" or (tek and tek.ad or ("Diğer ritüeller · " .. #v.ek))
          local tw = V.Olcu(yazi, f)
          local w, h = tw + 46 * s, 28 * s
          local x0, y0 = cx - w / 2, cy + 128 * s
          local ust = self.secili == "ek"
          V.TusKapagi(x0, y0, w, h, s, a * (ust and 1 or 0.85) * ((tek and not tek.aktif) and 0.6 or 1))
          if ust then
               draw.NoTexture()
               surface.SetDrawColor(R.altin.r, R.altin.g, R.altin.b, 26 * a)
               surface.DrawRect(x0 + 1, y0 + 1, w - 2, h - 2)
          end
          local ix = v.geri and (x0 + 15 * s) or (x0 + w - 15 * s)
          V.DokuDon("chevron_right", ix, y0 + h / 2, 14 * s, 14 * s, v.geri and 180 or 0, R.altin, a)
          V.Yazi(yazi, f, v.geri and (x0 + 28 * s) or (x0 + 12 * s), y0 + h / 2 + 5 * s, (ust and not (tek and not tek.aktif)) and R.yazi or R.ikincil, a, 0)
          self.ekKutu = {x0, y0, x0 + w, y0 + h}
     end
end

function PANEL:SeritCiz(a)
     local L, v = self.L, self.veri
     local s, cx, cy = L.s, L.cx, L.cy
     local kom = L.kompakt
     local by = cy + (kom and 300 or 347) * s

     -- ince ayırıcı + orta baklava
     draw.NoTexture()
     surface.SetDrawColor(R.altin.r, R.altin.g, R.altin.b, 90 * a)
     surface.DrawRect(cx - 297 * s, by, 262 * s, 1)
     surface.DrawRect(cx + 35 * s, by, 262 * s, 1)
     V.Baklava(cx, by, 4 * s, R.altin, a, false)

     local liste = v.serit
     if liste then
          local ty = by + 40 * s
          for j, st in ipairs(liste) do
               local x = cx + (-301 + (j - 1) * 160) * s
               if st.orijinal then
                    V.Doku(st.ikon, x, ty - 16 * s, 20 * s, 20 * s, nil, a)
               else
                    V.Ikon(st.ikon, x + 10 * s, ty - 6 * s, 20 * s, st.renk, a)
               end
               local f = V.Font("govde", 14, s)
               V.Yazi(V.Kisalt(st.ad, f, 80 * s), f, x + 28 * s, ty, R.ikincil, a, 0)
               local deger
               if st.deger == nil then deger = "—"
               elseif st.en then deger = st.deger .. "/" .. st.en
               elseif st.sicaklik then deger = tostring(st.deger)
               else deger = "%" .. st.deger end
               local dusuk = st.deger and not st.en and not st.sicaklik and st.deger < 20
               V.Yazi(deger, f, x + 140 * s, ty, dusuk and R.can or R.yazi, a, 2)
               local oran = st.deger and (st.en and st.deger / st.en or st.deger / 100) or 0
               V.Cubuk(x, ty + 14 * s, 140 * s, math_max(2, 3 * s), oran, st.renk, a)
               if st.sicaklik then
                    -- ideal aralık işareti çubuğun üstünde
                    local K = A.Kulucka
                    surface.SetDrawColor(R.olumlu.r, R.olumlu.g, R.olumlu.b, 200 * a)
                    surface.DrawRect(x + 140 * s * K.iyiAlt / 100, ty + 12 * s, 1, 7 * s)
                    surface.DrawRect(x + 140 * s * K.iyiUst / 100, ty + 12 * s, 1, 7 * s)
               end
          end
     end

     -- ESC
     local f = V.Font("govde", 12, s)
     local ey = kom and (by + 76 * s) or (cy + 435 * s)
     local tw = math_max(33 * s, V.Olcu("ESC", f) + 14 * s)
     local yazi = v.kapat or "Kapat"
     local yw = V.Olcu(yazi, V.Font("govde", 13, s))
     local x0 = cx - (tw + 11 * s + yw) / 2
     V.TusKapagi(x0, ey, tw, 23 * s, s, a)
     V.Yazi("ESC", f, x0 + tw / 2, ey + 16 * s, R.yazi, a, 1)
     V.Yazi(yazi, V.Font("govde", 13, s), x0 + tw + 11 * s, ey + 16 * s, R.ikincil, a, 0)
end

function PANEL:Paint(w, h)
     local v = self.veri
     if not v then return end
     local simdi = RealTime()
     local dt = math_min(RealFrameTime(), 0.05)
     local a = Alfa(self)
     local L = self.L
     local s = L.s

     -- üzerine gelinen
     if not self.kapaniyor then
          local mx, my = self:CursorPos()
          self.secili = self:Bul(mx, my)
     else
          self.secili = nil
     end

     local cx, cy = L.cx, L.cy

     -- yerel örtü (tüm ekranı karartmaz; kare oran korunur)
     local vb = 1010 * s
     if not V.Doku("seal_veil", cx - vb / 2, cy + 15 * s - vb / 2, vb, vb, nil, a * 0.96) then
          V.Yay(cx, cy, 250 * s, 500 * s, 0, math.pi * 2, R.derin, a * 0.6)
     end

     -- başlık
     local kom = L.kompakt
     if not kom then
          V.Aralikli(v.ust or "", V.Font("govde", 12, s), cx, cy - 411 * s, R.altin, a, 3.5 * s, 1)
     end
     local fAd = V.Font("baslik", 39, s)
     V.Yazi(V.Kisalt(v.ad or "", fAd, 640 * s), fAd, cx, cy - (kom and 350 or 361) * s, R.yazi, a, 1)
     local fAlt = V.Font("govde", 15, s)
     V.Yazi(V.Kisalt(v.alt or "", fAlt, 640 * s), fAlt, cx, cy - (kom and 324 or 332) * s, R.ikincil, a, 1)

     -- yörünge (sabit) ve seçili yay (yalnız seçilene döner)
     local ob = 512 * s
     if not V.Doku("seal_orbit", cx - ob / 2, cy - ob / 2, ob, ob, nil, a) then
          V.Yay(cx, cy, HALKA * s, 1, 0, math.pi * 2, R.altin, a * 0.4)
          V.Yay(cx, cy, 173 * s, 1, 0, math.pi * 2, R.altin, a * 0.2)
     end
     local hedefAci = (type(self.secili) == "number" and SLOT[self.secili].aci) or (v.oneri and SLOT[v.oneri].aci) or nil
     if hedefAci then
          if not self.yayAci or V.Sade() then
               self.yayAci = hedefAci
          else
               local fark = math.NormalizeAngle(hedefAci - self.yayAci)
               self.yayAci = self.yayAci + fark * (1 - math.exp(-dt * 18))
          end
          local ya = type(self.secili) == "number" and 1 or 0.45
          V.DokuDon("seal_selected_arc", cx, cy, ob, ob, self.yayAci + 90, nil, a * ya)
     end
     V.Ortak.yayAci = self.yayAci

     -- düğümler: sayfa değişince 180 ms'de belirir
     local gecis = V.Sade() and 1 or V.Yumusak((simdi - self.sayfaT) / V.SURE.giris)
     for i = 0, 8 do
          local n = v.dugum[i]
          if n then
               self:DugumCiz(i, n, a, dt, gecis)
          else
               -- boş yuva: yörüngede sönük nokta
               V.Baklava(cx + SLOT[i].x * s, cy + SLOT[i].y * s, 3 * s, R.sonuk, a * 0.6, false)
          end
     end

     self:MerkezCiz(a * gecis)
     self:SeritCiz(a)
     V.ParcacikCiz("panel", a)
end

vgui.Register("SardonYaratik.Muhur", PANEL, "EditablePanel")

------------------------------------------------------------------------ açma

V.Ortak = V.Ortak or {}

local function Ac(ent, tur, yer)
     if IsValid(Y.Radyal) then Y.Radyal:Remove() end
     local p = vgui.Create("SardonYaratik.Muhur")
     p:Kur(ent, tur, yer)
     Y.Radyal = p
     return p
end

function Y.RadyalAc(ent, yabanci)
     if yabanci then return Ac(ent, "yabanci") end
     if ent:GetDurum() == Y.ENT_KASE then return Ac(ent, "kase") end
     if ent:GetEvre() == 0 then return Ac(ent, "yumurta") end
     return Ac(ent, "bakim")
end

-- Dış sayfa: tur = Y.MuhurSayfa'ya kaydedilmiş sayfa adı; dis = { konum = function() → Vector | nil,
-- islem = function(dugum, panel) }. Yaratık varlığı yok; seçim dis.islem'e gider, mesafe dis.konum'dan ölçülür.
function Y.MuhurDisAc(tur, dis)
     if not SAYFA[tur] or not istable(dis) or not dis.konum or not dis.islem then return end
     local yer = dis.konum()
     if not yer then return end
     if IsValid(Y.Radyal) then Y.Radyal:Remove() end
     local p = vgui.Create("SardonYaratik.Muhur")
     p.dis = dis
     p:Kur(nil, tur, yer)
     Y.Radyal = p
     return p
end

function Y.YemlikMenuAc(i)
     local p = Y.Alan.yemlik and Y.Alan.yemlik[i]
     if not p then return end
     return Ac(nil, "yemlik", p)
end

function V.YerlesimSifirla()
     if IsValid(Y.Radyal) then Y.Radyal:Kapat() end
end

hook.Add("PlayerBindPress", "SardonYaratik.Etkilesim", function(ply, bind, basildi)
     if not basildi or not string.find(bind, "+use", 1, true) then return end
     if Y.OyunAcik or IsValid(Y.Radyal) or (Y.Biniyor and Y.Biniyor(ply)) then return end
     local ent = Y.Hedef()
     if not ent or not Y.Erisimde(ent) then
          local i = Y.YemlikHedef()
          if i and Y.YemlikErisimde(i) then
               Y.YemlikMenuAc(i)
               return true
          end
          return
     end

     if Y.YabaniMi(ent) then
          if ent:GetDurum() == Y.ENT_SERSEM then
               Y.Islem("yakala", ent:EntIndex(), "bas")
               Y.YakalaTus = true
          else
               Y.Bildirim("Önce sersemlet: Stupefy, Petrificus Totalus, Arresto Momentum, Immobulus...", "hata")
          end
          return true
     end
     if Benim(ent) then
          Y.RadyalAc(ent)
     elseif ent:GetDurum() == Y.ENT_KASE then
          return true
     elseif ent:GetEvre() > 0 and ent:GetDurum() ~= Y.ENT_AGIL and (ent:TurVeri() or {rol = {}}).rol.binek and ent:GetEvre() >= 3 then
          Y.RadyalAc(ent, true)
     elseif ent:GetEvre() > 0 then
          Y.Islem("sev", ent:GetKimlik())
     else
          return
     end
     return true
end)

------------------------------------------------------------------------ 3B: mührün yere izdüşümü

-- Mühür açıkken hedefin altında aynı yörünge; seçili yay ekrandaki yönüne karşılık gelen yere döner.
-- Eylem uygulanınca halka bir an aydınlanır, yerden altın kıvılcımlar yükselir.
local zemin = {a = 0, p = nil, r = 40}

hook.Add("PostDrawTranslucentRenderables", "SardonYaratik.V2Zemin", function(derinlik, gok)
     if gok or derinlik then return end
     local pnl = Y.Radyal
     local acik = IsValid(pnl) and not pnl.kapaniyor
     local dt = math_min(RealFrameTime(), 0.05)
     zemin.a = V.Yaklas(zemin.a, acik and 1 or 0, acik and 10 or 16, dt)
     if IsValid(pnl) then
          if IsValid(pnl.ent) then
               local u, g = Y.VarlikKutu(pnl.ent)
               zemin.p = pnl.ent:CizimKonumu()
               zemin.r = math_max(u or 20, g or 20) * 1.25 + 14
          elseif pnl.yer then
               zemin.p, zemin.r = pnl.yer, 64
          end
     end
     if zemin.a < 0.02 or not zemin.p or not V.Hazir("seal_orbit") then return end

     local nabiz = Y.V2.ZeminNabiz and (RealTime() - Y.V2.ZeminNabiz) or 9
     if Y.V2.ZeminNabiz and zemin.sonNabiz ~= Y.V2.ZeminNabiz and nabiz < 0.3 then
          zemin.sonNabiz = Y.V2.ZeminNabiz
          if Y.Kivilcim and not V.Sade() then
               for i = 1, 10 do
                    local aci = i / 10 * math.pi * 2
                    Y.Kivilcim(zemin.p + Vector(math_cos(aci) * zemin.r * 0.9, math_sin(aci) * zemin.r * 0.9, 2), R.altin, 1, 12, 1.1, 2.4, 36)
               end
          end
     end
     local parla = nabiz < 0.6 and (1 - nabiz / 0.6) or 0

     local olcek = zemin.r * 2 / 512
     local yaw = EyeAngles().y
     cam.Start3D2D(zemin.p + OPT_V_0_0_1p5, Angle(0, yaw - 90, 0), olcek)
          local a = zemin.a * (0.55 + 0.45 * parla)
          V.Doku("seal_orbit", -256, -256, 512, 512, nil, a)
          local yayAci = V.Ortak.yayAci
          if yayAci then V.DokuDon("seal_selected_arc", 0, 0, 512, 512, yayAci + 90, nil, a) end
     cam.End3D2D()
end)
