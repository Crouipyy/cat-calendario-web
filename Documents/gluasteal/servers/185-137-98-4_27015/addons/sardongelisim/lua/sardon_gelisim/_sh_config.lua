-- "addons\\sardongelisim\\lua\\sardon_gelisim\\_sh_config.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Gelişim :: ayarlar ve ortak kurallar (dal XP'si, dal seviyesi, kademe, ön koşul).
-- Dosya adı "_" ile başlıyor ki SardonUtil'in alfabetik yüklemesinde cl_ dosyalarından önce gelsin.
-- Kategori/beceri verisi _sh_config_veri.lua'da. Sunucu XP motoru sv_xp.lua'da.
--
-- 2026-11-09 yeniden kurgu (plan ~/.claude/plans/fuzzy-splashing-frost.md):
--   * Her dalın kendi XP'si var; o dalın işi yalnız o dalı doldurur.
--   * Dal Seviyesi 1..16; her seviye o dalda 1 kademe hakkı. Bütün dallar 16 kademe.
--     Her dal Sv 1'den başlar: kök yetkinlik (dalı seçmek) hemen açılır — prolog "Yol Danışması" buna dayanır.
--   * Sv'den Sv+1'e 400 + 100 × Sv XP (500 … 1900; Sv 16 için toplam 18.000).
--   * Rol: ilk kademe açılan 2 dal ana (×1, Sv16), 3. dal yan (×0,6, Sv10), gerisi rolsüz (×0,25, Sv3).
--     Boş rol yeri varken rolü olmayan dal sıradaki rolün hızıyla dolar.
--   * İlham: her gün 07:00'de (TR) dal başına +300 (en çok 900); İlham varken XP ×2 (ana/yan dallar).
--   * Yorgunluk: dal başına günlük ham XP 0-1000 ×1, 1000-2000 ×0,5, sonrası ×0,1.
--
-- Kayıt: char:GetData("sardonGelisim") =
--   {v = 2, k = {[dal] = {8 kademe}}, d = {a = {dal, dal}, y = dal}, x = {[dal] = xp},
--    il = {[dal] = {m = kalan, g = gün}}, g = {n = gün, [dal] = bugünkü ham}, ek = {[dal] = yönetici ek puanı},
--    son = {[dal] = {son 10 kazanç}}, pr = {} (doktora/prestij için ayrıldı)}
-- Helix SetData bu tabloyu sahibine kendiliğinden gönderir; istemci aynı işlevlerle okur.

SardonGelisim = SardonGelisim or {}
local G = SardonGelisim

G.VeriAnahtari = "sardonGelisim"
G.VeriSurum = 2
G.AnaDalSayisi = 2
G.SvUst = 16
G.KademeMaliyeti = 1 -- her kademe 1 dal puanı (eski adla geriye uyum)

-- rol çarpanı ve tavan
G.Roller = {
     ana = {ad = "Rama principal", carpan = 1, tavan = 16},
     yan = {ad = "Rama secundaria", carpan = 0.6, tavan = 10},
     rolsuz = {ad = "Rama sin rol", carpan = 0.25, tavan = 3},
}

G.Unvanlar = {
     {en = 1, ad = "Aprendiz"},
     {en = 8, ad = "Oficial"},
     {en = 14, ad = "Maestro"},
}

G.Ilham = {gunluk = 300, ust = 900}
G.Yorgunluk = {{esik = 1000, carpan = 1}, {esik = 2000, carpan = 0.5}, {esik = math.huge, carpan = 0.1}}
G.GunDonumuUTC = 4 * 3600 -- 07:00 TR = 04:00 UTC (Şans ve Revir ile aynı saat)
G.YilCarpani = 2 -- dal XP'si Yıl'a (genel seviye) bu katla yazılır
G.DalPuanXP = 500 -- eski "dal puanı" ödülleri (görev, eski çağrılar) bu kadar XP sayılır

-- Önceki sürümde eklenen Helix attribute'ları (başka sistemler kullanabilir diye korunuyor).
-- Değer artışı için sunucuda: character:UpdateAttrib("botanik", 0.05)
G.YeniAttributelar = {
     botanik = {
          name = "Competencia en Herbología",
          description = "Tu conocimiento de plantas y hierbas mágicas. Cuanto mayor sea, mejor reconocerás y recogerás las plantas."
     },
     baskalasim = {
          name = "Competencia en Transformación",
          description = "Tu dominio de los hechizos de cambio de forma. Cuanto mayor sea, más exitosas serán tus transformaciones."
     },
     lanet = {
          name = "Competencia en Maldiciones",
          description = "Tu dominio de maldiciones y hechizos funestos. Cuanto mayor sea, más poderosas serán tus maldiciones."
     },
     ksks = {
          name = "Competencia en DCAO",
          description = "Defensa contra las Artes Oscuras. Cuanto mayor sea, más resistirás a hechizos y criaturas oscuras."
     }
}

for id, bilgi in pairs(G.YeniAttributelar) do
     if (!ix.attributes.list[id]) then
          local a = table.Copy(bilgi)
          a.noStartBonus = true -- karakter oluştururken puan dağıtılmasın (mevcut beceriler gibi)
          a.sardonGelisim = true
          ix.attributes.list[id] = a
     end
end

----------------------------------------------------------------------------------------
-- Eğri
----------------------------------------------------------------------------------------
-- Sv'den Sv+1'e gereken XP
function G.SeviyeGerek(sv)
     return 400 + 100 * math.max(1, math.floor(sv or 1))
end

-- Sv'ye ulaşmak için gereken toplam XP (Sv 1 = 0 XP)
function G.SeviyeToplam(sv)
     sv = math.Clamp(math.floor(sv or 1), 1, G.SvUst)
     local n = sv - 1
     return 400 * n + 50 * n * sv
end

-- xp -> seviye (1..SvUst), seviye içindeki xp, sonraki seviyenin gereği (tavanda 0)
function G.XPSeviye(xp)
     xp = math.max(0, tonumber(xp) or 0)
     local sv = 1
     while sv < G.SvUst and xp >= G.SeviyeToplam(sv + 1) do sv = sv + 1 end
     if (sv >= G.SvUst) then return G.SvUst, 0, 0 end
     return sv, xp - G.SeviyeToplam(sv), G.SeviyeGerek(sv)
end

function G.Unvan(sv, rol)
     sv = tonumber(sv) or 0
     if (sv < 1) then return "Novato" end
     if (rol == "rolsuz") then return "Curioso" end
     local ad = G.Unvanlar[1].ad
     for _, u in ipairs(G.Unvanlar) do
          if (sv >= u.en) then ad = u.ad end
     end
     return ad
end

-- TR 07:00'de dönen gün numarası
function G.GunNo(t)
     return math.floor(((t or os.time()) - G.GunDonumuUTC) / 86400)
end

-- bir sonraki gün dönümüne kalan saniye
function G.GunDonumuKalan(t)
     t = t or os.time()
     return (G.GunNo(t) + 1) * 86400 + G.GunDonumuUTC - t
end

-- bugün 'bugun' ham XP birikmişken 'ham' kadar daha kazanılınca yorgunluk sonrası miktar
function G.Yorgun(bugun, ham)
     local out, kalan, b = 0, math.max(0, ham or 0), math.max(0, bugun or 0)
     for _, y in ipairs(G.Yorgunluk) do
          if (kalan <= 0) then break end
          if (b < y.esik) then
               local pay = math.min(kalan, y.esik - b)
               out = out + pay * y.carpan
               kalan = kalan - pay
               b = b + pay
          end
     end
     return out
end

-- bugünkü birikime göre şimdiki yorgunluk çarpanı ve o kademenin bitişi
function G.YorgunlukDurum(bugun)
     bugun = math.max(0, bugun or 0)
     for _, y in ipairs(G.Yorgunluk) do
          if (bugun < y.esik) then return y.carpan, y.esik end
     end
     local son = G.Yorgunluk[#G.Yorgunluk]
     return son.carpan, son.esik
end

----------------------------------------------------------------------------------------
-- Veri okuma
----------------------------------------------------------------------------------------
function G.KategoriBul(katId)
     for i, k in ipairs(G.Kategoriler or {}) do
          if (k.id == katId) then return k, i end
     end
end

function G.Veri(char)
     local v = char and char:GetData(G.VeriAnahtari)
     return istable(v) and v or {}
end

local function Alan(v, ad)
     return istable(v[ad]) and v[ad] or {}
end

function G.Kademe(char, katId, no)
     local k = G.Veri(char).k
     local liste = istable(k) and k[katId]
     return istable(liste) and math.max(0, math.floor(tonumber(liste[no]) or 0)) or 0
end

-- Kategoride açılan kademe ve toplam kademe
function G.KategoriToplam(char, kat)
     local n, ust = 0, 0
     for i, b in ipairs(kat.beceriler) do
          n = n + math.min(G.Kademe(char, kat.id, i), b.enfazla)
          ust = ust + b.enfazla
     end
     return n, ust
end

function G.KategoriUst(kat)
     local ust = 0
     for _, b in ipairs(kat.beceriler) do ust = ust + b.enfazla end
     return ust
end

-- Bütün dallarda açılan kademe (Büyü Ağacı "genel" kilidi bunu okur)
function G.Harcanan(char)
     local n = 0
     for _, kat in ipairs(G.Kategoriler or {}) do
          n = n + G.KategoriToplam(char, kat)
     end
     return n
end

-- Genel seviye (Yıl hesabı için; [sardon] level)
function G.Seviye(char)
     return char and char.GetLVL and math.max(0, math.floor(char:GetLVL() or 0)) or 0
end

----------------------------------------------------------------------------------------
-- Ana / yan dal
----------------------------------------------------------------------------------------
-- {a = {katId...}, y = katId}. Kaydı olmayan karakterde roller açılmış kademelerden türetilir.
function G.Dallar(char)
     local d = G.Veri(char).d
     if (istable(d)) then
          return {a = istable(d.a) and d.a or {}, y = isstring(d.y) and d.y or nil}
     end

     local liste = {}
     for i, kat in ipairs(G.Kategoriler or {}) do
          local n = G.KategoriToplam(char, kat)
          if (n > 0) then liste[#liste + 1] = {id = kat.id, n = n, i = i} end
     end
     table.sort(liste, function(x, y) if (x.n != y.n) then return x.n > y.n end return x.i < y.i end)
     local sonuc = {a = {}}
     for i = 1, math.min(#liste, G.AnaDalSayisi) do sonuc.a[i] = liste[i].id end
     sonuc.y = liste[G.AnaDalSayisi + 1] and liste[G.AnaDalSayisi + 1].id or nil
     return sonuc
end

-- "ana" / "yan" / nil
function G.DalRolu(char, katId)
     local d = G.Dallar(char)
     if (d.y == katId) then return "yan" end
     for _, id in ipairs(d.a) do
          if (id == katId) then return "ana" end
     end
end

-- Rolü olmayan bir dalda ilk kademe açılınca alacağı rol ("ana" / "yan" / nil = boş yer yok)
function G.SiradakiRol(char)
     local d = G.Dallar(char)
     if (#d.a < G.AnaDalSayisi) then return "ana" end
     if (!d.y) then return "yan" end
end

-- XP kazanımında ve tavanda geçerli rol: atanmış rol, yoksa sıradaki boş yer, yoksa rolsüz
function G.EtkinRol(char, katId)
     return G.DalRolu(char, katId) or G.SiradakiRol(char) or "rolsuz"
end

function G.RolBilgi(char, katId)
     return G.Roller[G.EtkinRol(char, katId)] or G.Roller.rolsuz
end

----------------------------------------------------------------------------------------
-- Dal XP'si, seviye, puan
----------------------------------------------------------------------------------------
function G.DalXP(char, katId)
     return math.max(0, tonumber(Alan(G.Veri(char), "x")[katId]) or 0)
end

function G.DalTavan(char, katId)
     return G.RolBilgi(char, katId).tavan
end

-- Dalın seviyesi (rol tavanıyla sınırlı), seviye içindeki xp, gereken
function G.DalSeviye(char, katId)
     local sv, ic, gerek = G.XPSeviye(G.DalXP(char, katId))
     local tavan = G.DalTavan(char, katId)
     if (sv >= tavan) then return tavan, 0, 0 end
     return sv, ic, gerek
end

function G.EkPuan(char, katId)
     return math.floor(tonumber(Alan(G.Veri(char), "ek")[katId]) or 0)
end

-- Dalda harcanabilir puan: seviye + yönetici ek puanı − açılan kademe
function G.DalHak(char, katId)
     local kat = G.KategoriBul(katId)
     if (!char or !kat) then return 0 end
     local sv = G.DalSeviye(char, katId)
     return math.max(0, sv + G.EkPuan(char, katId) - G.KategoriToplam(char, kat))
end

-- Geriye uyum: katId verilirse o dalın puanı, verilmezse bütün dalların toplamı
function G.Puan(char, katId)
     if (!char) then return 0 end
     if (katId) then return G.DalHak(char, katId) end
     local n = 0
     for _, kat in ipairs(G.Kategoriler or {}) do n = n + G.DalHak(char, kat.id) end
     return n
end

-- Eski "dala bağlı puan" artık yok (dal XP'sine çevrildi); çağıranlar bozulmasın diye 0
function G.DalPuan() return 0 end

-- Her kademe 1 puan (eski yan dal / ×4 maliyet kuralı kalktı)
function G.Maliyeti() return G.KademeMaliyeti end
function G.DigerMaliyet() return G.KademeMaliyeti end

-- Bugünkü ham XP ve İlham (istemci de aynı hesabı yapar)
function G.BugunHam(char, katId)
     local g = Alan(G.Veri(char), "g")
     if (tonumber(g.n) != G.GunNo()) then return 0 end
     return math.max(0, tonumber(g[katId]) or 0)
end

function G.IlhamKalan(char, katId)
     if (G.EtkinRol(char, katId) == "rolsuz") then return 0 end
     local il = Alan(G.Veri(char), "il")[katId]
     local bugun = G.GunNo()
     if (!istable(il)) then return G.Ilham.gunluk end
     local gecen = math.max(0, bugun - (tonumber(il.g) or bugun))
     return math.min(G.Ilham.ust, math.max(0, tonumber(il.m) or 0) + gecen * G.Ilham.gunluk)
end

-- Son kazançların ortalaması ve sonraki seviyeye kalan iş sayısı (yaklaşık)
function G.OrtalamaKazanc(char, katId)
     local son = Alan(G.Veri(char), "son")[katId]
     if (!istable(son) or #son == 0) then return nil end
     local t = 0
     for _, n in ipairs(son) do t = t + (tonumber(n) or 0) end
     local o = t / #son
     return o > 0 and o or nil
end

function G.KalanIs(char, katId)
     local sv, ic, gerek = G.DalSeviye(char, katId)
     if (gerek <= 0) then return nil end
     local o = G.OrtalamaKazanc(char, katId)
     if (!o) then return nil end
     return math.max(1, math.ceil((gerek - ic) / o))
end

----------------------------------------------------------------------------------------
-- Ön koşul ve öğrenme
----------------------------------------------------------------------------------------
-- Bağlı becerilerin hepsi tam kademede mi
function G.OnKosulTamam(char, kat, no)
     for _, u in ipairs(kat.beceriler[no].gerek) do
          if (G.Kademe(char, kat.id, u) < kat.beceriler[u].enfazla) then return false end
     end
     return true
end

-- "ogrenildi" (tam kademe) / "acilabilir" (ön koşul tamam) / "kilitli"
function G.Durum(char, kat, no)
     local b = kat.beceriler[no]
     if (G.Kademe(char, kat.id, no) >= b.enfazla) then return "ogrenildi" end
     return G.OnKosulTamam(char, kat, no) and "acilabilir" or "kilitli"
end

function G.OgrenebilirMi(char, katId, no)
     if (!char) then return false, "Primero elige un personaje." end
     local kat = G.KategoriBul(katId)
     local b = kat and kat.beceriler[no]
     if (!b) then return false, "Competencia no válida." end
     if (G.Kademe(char, katId, no) >= b.enfazla) then return false, "Esta competencia ya está completada." end
     if (!G.OnKosulTamam(char, kat, no)) then return false, "Completa antes las competencias vinculadas." end
     if (G.DalHak(char, katId) < 1) then
          local sv = G.DalSeviye(char, katId)
          local tavan = G.DalTavan(char, katId)
          if (sv >= tavan and G.KategoriToplam(char, kat) >= tavan + G.EkPuan(char, katId)) then
               return false, kat.ad .. " en el tope de " .. string.lower(G.RolBilgi(char, katId).ad) .. " (Nv " .. tavan .. ")."
          end
          return false, "No tienes puntos de " .. kat.ad .. ": nivel de rama " .. sv .. ", rangos abiertos " .. G.KategoriToplam(char, kat) .. ". Gana XP haciendo el trabajo de esa rama."
     end
     return true
end
