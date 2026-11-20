-- "addons\\sardonduyuru\\lua\\sardon_duyuru\\_sh_1ayar.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
--[[
     Sardon Duyuru :: ortak ayarlar, yetki, metin temizleme ve komut çözümleme.

     Gönderme yolları (hepsi sunucuda D.Gonder'den geçer):
       /Duyuru [#tür] [#10dk] [Başlık |] metin   (boş: Shine Admin › Duyuru açılır)
       /DuyuruKaldir                              (süren geri sayımları ve ekrandaki bantları kaldırır)
       Shine Admin › Duyuru                       (önizlemeli form, geçmiş, yeniden gönder)
       sunucu konsolu: sardon_duyuru #sunucu #5dk Yeniden başlatma | Sunucu birazdan yeniden başlayacak
     Türler: #duyuru (varsayılan), #etkinlik, #uyari, #sunucu. "#Ndk" / "#Nsa" geri sayım ekler.
     Yetki: admin ve üstü ya da SAM'den "Sardon - Duyuru" (CAMI) verilen rütbe.
]]

SardonDuyuru = SardonDuyuru or {}
local D = SardonDuyuru

D.NET = "SardonDuyuru"
D.Yetki = "Sardon - Duyuru"

-- sis: bandın zemin rengi (r, g, b); ses: istemcide surface.PlaySound (HL2 tabanı, herkeste var)
D.Turler = {
     { id = "duyuru", ad = "Duyuru", etiket = "DUYURU", renk = Color(214, 176, 96), acik = Color(255, 228, 160), sis = { 14, 10, 4 }, ses = "ambient/levels/canals/windchime2.wav" },
     { id = "etkinlik", ad = "Etkinlik", etiket = "ETKİNLİK", renk = Color(132, 176, 255), acik = Color(198, 222, 255), sis = { 8, 10, 22 }, ses = "ambient/levels/canals/windchime4.wav" },
     { id = "uyari", ad = "Uyarı", etiket = "UYARI", renk = Color(214, 92, 72), acik = Color(255, 160, 138), sis = { 34, 8, 6 }, ses = "buttons/bell1.wav" },
     { id = "sunucu", ad = "Sunucu", etiket = "SUNUCU", renk = Color(178, 192, 214), acik = Color(232, 238, 248), sis = { 8, 11, 16 }, ses = "friends/message.wav" },
}
D.Tur = {}
for i, t in ipairs(D.Turler) do
     t.sira = i
     D.Tur[t.id] = t
end

-- komutta yazılan etiketler (Türkçe harfler ASCII'ye indirgenmiş hâliyle)
D.TurEs = {
     duyuru = "duyuru", genel = "duyuru",
     etkinlik = "etkinlik", event = "etkinlik",
     uyari = "uyari", uyar = "uyari",
     sunucu = "sunucu", server = "sunucu", restart = "sunucu", bakim = "sunucu",
}

D.BaslikEnCok = 64     -- harf
D.MetinEnCok = 400     -- harf
D.SayacEnCok = 240     -- dakika
D.GecmisEnCok = 60     -- saklanan son duyuru
D.Bekleme = 3          -- aynı gönderenin iki duyurusu arası (sn)

-- ekranda kalma süresi (sn): kısa duyuru 8, uzun olan 26 sn'ye kadar
function D.Sure(baslik, metin)
     local n = (utf8.len(metin or "") or #(metin or "")) + (utf8.len(baslik or "") or 0)
     return math.Clamp(6 + n / 15, 8, 26)
end

-- 754 sn → "12:34", 3725 → "1:02:05"
function D.SayacYazi(sn)
     sn = math.max(0, math.ceil(sn or 0))
     local s, d, sa = sn % 60, math.floor(sn / 60) % 60, math.floor(sn / 3600)
     if sa > 0 then return string.format("%d:%02d:%02d", sa, d, s) end
     return string.format("%02d:%02d", d, s)
end

function D.DakikaYazi(dk)
     dk = tonumber(dk) or 0
     if dk >= 60 and dk % 60 == 0 then return (dk / 60) .. " sa" end
     if dk >= 60 then return math.floor(dk / 60) .. " sa " .. (dk % 60) .. " dk" end
     return dk .. " dk"
end

/*
*   Metin temizleme: denetim karakterleri atılır, boşluklar toplanır, harf sınırında kesilir.
*   Satır sonu yalnız gövdede kalır (en çok iki boş satır). Bozuk UTF-8 utf8.force ile onarılır;
*   utf8.offset GMod'da bir ileri saydığı için kesme utf8.codes ile yapılır.
*/
local function UtfKes(s, n)
     local ok, sonuc = pcall(function()
          local i = 0
          for p in utf8.codes(s) do
               i = i + 1
               if i > n then return s:sub(1, p - 1) end
          end
          return s
     end)
     return ok and sonuc or s:sub(1, n)
end

function D.Temiz(s, enCok, satirIzni)
     s = tostring(s or "")
     if utf8.force then s = utf8.force(s) end
     s = s:gsub("\r", "")
     if satirIzni then
          s = s:gsub("[%z\1-\9\11-\31\127]", " ")
          s = s:gsub("[ \t]*\n[ \t]*", "\n")
          s = s:gsub("\n\n\n+", "\n\n")
     else
          s = s:gsub("[%z\1-\31\127]", " ")
     end
     s = s:gsub("[ \t]+", " ")
     s = string.Trim(s)
     if enCok and (utf8.len(s) or #s) > enCok then s = string.Trim(UtfKes(s, enCok)) end
     return s
end

-- etiket karşılaştırması: küçük harf + Türkçe harfler ASCII
local TR = { ["İ"] = "i", ["I"] = "i", ["ı"] = "i", ["Ş"] = "s", ["ş"] = "s", ["Ğ"] = "g", ["ğ"] = "g",
     ["Ü"] = "u", ["ü"] = "u", ["Ö"] = "o", ["ö"] = "o", ["Ç"] = "c", ["ç"] = "c" }
local function Anahtar(s)
     for k, v in pairs(TR) do s = s:gsub(k, v) end
     return s:lower()
end

/*
*   "#etkinlik #15dk Quidditch Maçı | Saha önünde toplanın"
*     → { tur = "etkinlik", dk = 15, baslik = "Quidditch Maçı", metin = "Saha önünde toplanın" }
*   Etiketler yalnız baştadır; tanınmayan "#..." metnin parçası sayılır. "|" yoksa başlık yok.
*/
function D.Coz(ham)
     local t = { tur = "duyuru", dk = 0, baslik = "", metin = "" }
     local s = string.Trim(tostring(ham or ""))
     -- konsoldan tırnakla gelen tüm metin
     if #s >= 2 and s:sub(1, 1) == "\"" and s:sub(-1) == "\"" then s = string.Trim(s:sub(2, -2)) end

     while true do
          local etiket, kalan = s:match("^#(%S+)%s*(.*)$")
          if not etiket then break end
          local a = Anahtar(etiket)
          local dk, sa = a:match("^(%d+)dk$"), a:match("^(%d+)sa$")
          if D.TurEs[a] then
               t.tur = D.TurEs[a]
          elseif dk then
               t.dk = tonumber(dk)
          elseif sa then
               t.dk = tonumber(sa) * 60
          else
               break
          end
          s = kalan
     end

     local b, m = s:match("^(.-)%s*|%s*(.+)$")
     if b then
          t.baslik, t.metin = string.Trim(b), m
     else
          t.metin = s
     end
     return t
end

/*
*   Yetki: admin/superadmin ya da CAMI "Sardon - Duyuru" (SAM rütbe menüsünden verilebilir).
*/
function D.Yetkili(ply)
     if not IsValid(ply) then return false end
     if ply:IsSuperAdmin() or ply:IsAdmin() then return true end
     if CAMI and CAMI.PlayerHasAccess then
          local ok, sonuc = pcall(CAMI.PlayerHasAccess, ply, D.Yetki, nil)
          return ok and sonuc == true
     end
     return false
end

if CAMI and CAMI.RegisterPrivilege then
     CAMI.RegisterPrivilege({ Name = D.Yetki, MinAccess = "admin", Description = "Oyun içi rol dışı duyuru gönderir (/Duyuru, Shine Admin › Duyuru)." })
end

-- Shine Admin paneli açma hakkı (CanOpen kuralları); _sh_core yeniden yüklenince tablo baştan
-- yazıldığı için kural eksikse yeniden eklenir
local function ShineKural()
     if ShineAdmin and ShineAdmin.Access and not ShineAdmin.Access.duyuru then
          ShineAdmin.Access.duyuru = function(ply) return SardonDuyuru.Yetkili(ply) end
     end
end
ShineKural()
timer.Create("SardonDuyuru.ShineKural", 10, 0, ShineKural)

/*
*   Komutlar (Helix; OnRun yalnız sunucuda)
*/
if ix and ix.command then
     ix.command.Add("Duyuru", {
          description = "Rol dışı duyuru: /Duyuru [#etkinlik|#uyari|#sunucu] [#10dk] [Başlık |] metin. Boş bırakırsan Shine Admin › Duyuru açılır.",
          arguments = bit.bor(ix.type.text, ix.type.optional),
          OnCheckAccess = function(_, client) return SardonDuyuru.Yetkili(client) end,
          OnRun = function(_, client, metin)
               if not metin or string.Trim(metin) == "" then
                    client:ConCommand("shine_admin duyuru")
                    return
               end
               local t = SardonDuyuru.Coz(metin)
               t.ses, t.imza = true, true
               local ok, hata = SardonDuyuru.Gonder(client, t)
               if not ok then return hata end
          end
     })

     ix.command.Add("DuyuruKaldir", {
          description = "Süren geri sayımlı duyuruları ve ekrandaki duyuru bantlarını herkesten kaldırır.",
          OnCheckAccess = function(_, client) return SardonDuyuru.Yetkili(client) end,
          OnRun = function(_, client)
               local n = SardonDuyuru.Kaldir(client, 0)
               return n > 0 and (n .. " geri sayım kaldırıldı.") or "Ekrandaki duyurular kaldırıldı."
          end
     })
end
