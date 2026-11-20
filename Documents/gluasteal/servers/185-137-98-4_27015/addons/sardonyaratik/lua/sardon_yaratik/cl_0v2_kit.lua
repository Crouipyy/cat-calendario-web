-- "addons\\sardonyaratik\\lua\\sardon_yaratik\\cl_0v2_kit.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- [sardon] yaratik :: V2 arayüz takımı ("Mühür & Kanat", addons/arcana_creature_ui_v2 tasarımı)
--
-- Bakım mührü (cl_4muhur), bakış kartları (cl_4kart) ve binek şeridi (cl_binek_2hud) buradan çizer:
--   * Renkler ve ölçüler design_tokens.json'dan; tasarım tuvali 1920×1080.
--   * Dokular: sunucu dagitim/v2/*.png'leri net ile parça parça yollar (sv_0v2_doku.lua; materyaller
--     oyunculara inmiyor, gluapack yalnız Lua taşıyor). İstemci data/sardon_yaratik_v2/<ad>_<crc>.png
--     olarak saklar. PNG'ler 2'nin kuvveti tuvale sol üstten dolgulu: UV ile kırpılarak çizilir.
--   * Fontlar: tasarımın Georgia / Segoe UI'si Windows'ta sistemde var; yoksa (ölçüyle anlaşılır)
--     Playfair Display / Montserrat'a düşülür.
--   * Parçacıklar yalnız olaylarda (açılış, eylem, değer artışı, kanat çırpışı...): sürekli yayıcı yok.
--   * "sardon_yaratik_sade 1": açılış/geçiş animasyonları ve parçacıklar kapanır.

local Y = SardonYaratik
Y.V2 = Y.V2 or {}
local V = Y.V2

local math_min, math_max, math_floor, math_Clamp, math_cos, math_sin, math_rad, math_sqrt =
     math.min, math.max, math.floor, math.Clamp, math.cos, math.sin, math.rad, math.sqrt
local surface_SetDrawColor, surface_SetMaterial, surface_DrawTexturedRectUV, surface_DrawTexturedRectRotated =
     surface.SetDrawColor, surface.SetMaterial, surface.DrawTexturedRectUV, surface.DrawTexturedRectRotated
local surface_SetFont, surface_GetTextSize, surface_SetTextColor, surface_SetTextPos, surface_DrawText =
     surface.SetFont, surface.GetTextSize, surface.SetTextColor, surface.SetTextPos, surface.DrawText

------------------------------------------------------------------------ renkler

local function Hex(h)
     return Color(tonumber(h:sub(2, 3), 16), tonumber(h:sub(4, 5), 16), tonumber(h:sub(6, 7), 16))
end

V.R = {
     zemin = Hex("#0B1714"), derin = Hex("#07110F"), altin = Hex("#BFA16A"), sonuk = Hex("#766443"),
     yazi = Hex("#E8E1CD"), ikincil = Hex("#A4ADA2"), olumlu = Hex("#8FAF9B"), can = Hex("#C58072"),
     enerji = Hex("#8FB9BD"), bag = Hex("#B8A6CE"), iz = Hex("#304037"), izYumurta = Hex("#34453B"),
     ideal = Hex("#49634D"),
}

-- nadirlik: Sıradan sönük, Nadir su mavisi, Efsanevi altın (V2 paletinde kalır)
V.NadirRenk = {V.R.ikincil, V.R.enerji, V.R.altin}

V.SURE = {giris = 0.18, ustune = 0.11, cikis = 0.10}

local sade = CreateClientConVar("sardon_yaratik_sade", "0", true, false, "1: yaratık arayüzünde animasyon ve parçacık yok")
function V.Sade() return sade:GetBool() end

------------------------------------------------------------------------ ölçek

-- 1920×1080 tasarımı ekrana: dar kenara göre (ultra genişte büyümez)
function V.Olcek()
     return math_min(ScrW() / 1920, ScrH() / 1080)
end

function V.Guvenli()
     return math_max(24, math_floor(math_min(ScrW(), ScrH()) * 0.02))
end

------------------------------------------------------------------------ fontlar

-- rol → aday yüzler (sırayla). ems: yüzün hücre yüksekliği / em (GMod "size" hücre yüksekliğidir),
-- gen: aynı em'de genişlik farkını dengeleyen çarpan
local ROLLER = {
     baslik = {{ad = "Georgia", w = 400, ems = 1.136, gen = 1}, {ad = "Playfair Display", w = 400, ems = 1.333, gen = 1.04}},
     govde = {{ad = "Segoe UI", w = 400, ems = 1.33, gen = 1}, {ad = "Montserrat Medium", w = 400, ems = 1.219, gen = 0.9}},
     kalin = {{ad = "Segoe UI Semibold", w = 600, ems = 1.33, gen = 1}, {ad = "Montserrat SemiBold", w = 600, ems = 1.219, gen = 0.9}},
}
local secilen = {}
local fontlar = {}
local SINAMA = "MMMMWWWW0123456789 ğüşıöçĞÜŞİÖÇ"

local function YuzVarMi(ad, w)
     surface.CreateFont("SYV2_Sina", {font = ad, size = 40, weight = w, antialias = true, extended = true})
     surface.CreateFont("SYV2_SinaYok", {font = "SardonYokFont_x9", size = 40, weight = w, antialias = true, extended = true})
     surface_SetFont("SYV2_Sina")
     local a, b = surface_GetTextSize(SINAMA)
     surface_SetFont("SYV2_SinaYok")
     local c, d = surface_GetTextSize(SINAMA)
     return a ~= c or b ~= d
end

local function YuzSec(rol)
     if secilen[rol] then return secilen[rol] end
     local adaylar = ROLLER[rol]
     for _, y in ipairs(adaylar) do
          if YuzVarMi(y.ad, y.w) then secilen[rol] = y break end
     end
     secilen[rol] = secilen[rol] or adaylar[#adaylar]
     return secilen[rol]
end

-- px: tasarım pikseli (CSS). Ekranda küçük yazılar okunur kalsın diye alt sınır var.
-- Ölçek yalnız çözünürlükle değiştiği için oluşan font sayısı sınırlı (bir kez üretilir, saklanır).
local onbellek = {}
function V.Font(rol, px, s)
     s = s or V.Olcek()
     local r = onbellek[rol]
     if not r then r = {} onbellek[rol] = r end
     local rp = r[px]
     if not rp then rp = {} r[px] = rp end
     local ad = rp[s]
     if ad then return ad end
     local ekran = math_max(px * s, math_min(px, 13))
     local y = YuzSec(rol)
     local boy = math_max(8, math.Round(ekran * y.ems * y.gen))
     ad = "SYV2_" .. rol .. "_" .. boy
     if not fontlar[ad] then
          surface.CreateFont(ad, {font = y.ad, size = boy, weight = y.w, antialias = true, extended = true})
          fontlar[ad] = true
     end
     rp[s] = ad
     return ad
end

-- yüz algılaması bir kez, oyuna girerken (çizim kancasında font üretilmesin)
hook.Add("InitPostEntity", "SardonYaratik.V2Font", function()
     for rol in pairs(ROLLER) do YuzSec(rol) end
end)

hook.Add("OnScreenSizeChanged", "SardonYaratik.V2Font", function()
     table.Empty(onbellek)
     if V.YerlesimSifirla then V.YerlesimSifirla() end
end)

------------------------------------------------------------------------ yazı

-- y: taban çizgisi (tasarımdaki SVG <text y=...> gibi). hiza: 0 sol, 1 orta, 2 sağ. Genişliği döndürür.
function V.Yazi(metin, font, x, y, renk, a, hiza)
     surface_SetFont(font)
     local w, h = surface_GetTextSize(metin)
     local px = x
     if hiza == 1 then px = x - w / 2 elseif hiza == 2 then px = x - w end
     surface_SetTextColor(renk.r, renk.g, renk.b, 255 * (a or 1))
     surface_SetTextPos(math.Round(px), math.Round(y - h * 0.8))
     surface_DrawText(metin)
     return w
end

-- harf aralıklı kısa etiket (yalnız büyük harfli kısa başlıklar)
local HARF = "[%z\1-\127\194-\244][\128-\191]*"
function V.Aralikli(metin, font, x, y, renk, a, aralik, hiza)
     surface_SetFont(font)
     local w, h = surface_GetTextSize(metin)
     local n = utf8.len(metin) or #metin
     aralik = math.Round(aralik or 0)
     local tw = w + aralik * math_max(0, n - 1)
     local px = x
     if hiza == 1 then px = x - tw / 2 elseif hiza == 2 then px = x - tw end
     px = math.Round(px)
     local py = math.Round(y - h * 0.8)
     surface_SetTextColor(renk.r, renk.g, renk.b, 255 * (a or 1))
     for harf in metin:gmatch(HARF) do
          surface_SetTextPos(px, py)
          surface_DrawText(harf)
          px = px + surface_GetTextSize(harf) + aralik
     end
     return tw
end

function V.Olcu(metin, font)
     surface_SetFont(font)
     return surface_GetTextSize(metin)
end

-- sığmayan metni "…" ile kısaltır (UTF-8 güvenli)
function V.Kisalt(metin, font, en)
     surface_SetFont(font)
     if surface_GetTextSize(metin) <= en then return metin end
     local harfler = {}
     for h in metin:gmatch(HARF) do harfler[#harfler + 1] = h end
     for n = #harfler - 1, 1, -1 do
          local dene = table.concat(harfler, "", 1, n) .. "…"
          if surface_GetTextSize(dene) <= en then return dene end
     end
     return "…"
end

-- en çok `satir` satıra sarar; son satır sığmazsa kısaltılır
function V.Sar(metin, font, en, satir)
     surface_SetFont(font)
     local out, sat = {}, ""
     for kelime in tostring(metin or ""):gmatch("%S+") do
          local dene = sat == "" and kelime or (sat .. " " .. kelime)
          if sat ~= "" and surface_GetTextSize(dene) > en then
               out[#out + 1] = sat
               sat = kelime
          else
               sat = dene
          end
     end
     if sat ~= "" then out[#out + 1] = sat end
     if #out > satir then
          local kalan = table.concat(out, " ", satir)
          for i = #out, satir, -1 do out[i] = nil end
          out[satir] = V.Kisalt(kalan, font, en)
     end
     return out
end

------------------------------------------------------------------------ dokular

-- ad = {gerçek genişlik, yükseklik, PNG tuval genişliği, yüksekliği} (doku_hazirla.py çıktısı)
V.DOKU = {
     feed = {128, 128, 128, 128}, heart = {128, 128, 128, 128}, brush = {128, 128, 128, 128},
     train = {128, 128, 128, 128}, collect = {128, 128, 128, 128}, follow = {128, 128, 128, 128},
     ride = {128, 128, 128, 128}, share_ride = {128, 128, 128, 128}, cage = {128, 128, 128, 128},
     feather = {128, 128, 128, 128}, egg = {128, 128, 128, 128}, temperature = {128, 128, 128, 128},
     hatch = {128, 128, 128, 128}, shield = {128, 128, 128, 128}, wing = {128, 128, 128, 128},
     takeoff = {128, 128, 128, 128}, cry = {128, 128, 128, 128}, dismount = {128, 128, 128, 128},
     close = {128, 128, 128, 128}, chevron_right = {128, 128, 128, 128}, hippogriff = {128, 128, 128, 128},
     seal_veil = {256, 256, 256, 256}, feather_card = {400, 250, 512, 256}, egg_card = {420, 250, 512, 256},
     wing_ribbon = {840, 120, 1024, 128}, key_veil = {800, 64, 1024, 64}, keycap = {64, 32, 64, 32},
     glyph_default = {96, 96, 128, 128}, glyph_hover = {96, 96, 128, 128}, glyph_selected = {96, 96, 128, 128},
     glyph_pressed = {96, 96, 128, 128}, glyph_disabled = {96, 96, 128, 128}, glyph_focus = {96, 96, 128, 128},
     seal_orbit = {512, 512, 512, 512}, seal_selected_arc = {512, 512, 512, 512},
     feather_flourish = {80, 192, 128, 256}, wing_flourish_left = {320, 80, 512, 128},
     wing_flourish_right = {320, 80, 512, 128}, bond_rhombus = {64, 64, 64, 64}, star_spark = {32, 32, 32, 32},
     temperature_marker = {24, 24, 32, 32}, egg_progress_track = {128, 160, 128, 256}, fine_divider = {512, 16, 512, 16},
}

V.Mat = V.Mat or {}
local NET = "SardonYaratik.V2Doku"
local KLASOR = "sardon_yaratik_v2/"
local bekleyen = {}
local uyarildi = {}

local function DokuYukle(ad, yol)
     local m = Material("../data/" .. yol, "smooth mips")
     if m and not m:IsError() then V.Mat[ad] = m end
end

function V.Hazir(ad) return V.Mat[ad] ~= nil end

local function Eksik(ad)
     if uyarildi[ad] then return end
     uyarildi[ad] = true
     MsgC(Color(201, 174, 119), "[Yaratık V2] ", color_white, "doku henüz yok, yedek çizim: " .. ad .. "\n")
end

net.Receive(NET, function()
     local op = net.ReadUInt(4)
     if op == 1 then
          local gerek = {}
          for _ = 1, net.ReadUInt(8) do
               local ad, crc, boyut = net.ReadString(), net.ReadString(), net.ReadUInt(32)
               local kok = ad:match("^([%w_]+)%.png$")
               if kok and V.DOKU[kok] then
                    local yol = KLASOR .. kok .. "_" .. crc .. ".png"
                    if file.Exists(yol, "DATA") and file.Size(yol, "DATA") == boyut then
                         DokuYukle(kok, yol)
                    else
                         bekleyen[ad] = {kok = kok, yol = yol, parca = {}, gelen = 0}
                         gerek[#gerek + 1] = ad
                    end
               end
          end
          if #gerek > 0 then
               net.Start(NET)
                    net.WriteUInt(2, 4)
                    net.WriteUInt(#gerek, 8)
                    for _, ad in ipairs(gerek) do net.WriteString(ad) end
               net.SendToServer()
          end
     elseif op == 2 then
          local ad = net.ReadString()
          local sira, toplam = net.ReadUInt(16), net.ReadUInt(16)
          local veri = net.ReadData(net.ReadUInt(16))
          local b = bekleyen[ad]
          if not b or b.parca[sira] then return end
          b.parca[sira] = veri
          b.gelen = b.gelen + 1
          if b.gelen < toplam then return end
          file.CreateDir("sardon_yaratik_v2")
          file.Write(b.yol, table.concat(b.parca))
          bekleyen[ad] = nil
          DokuYukle(b.kok, b.yol)
     end
end)

local function DokulariIste(deneme)
     deneme = deneme or 1
     if util.NetworkStringToID(NET) == 0 then
          if deneme < 30 then timer.Create("SardonYaratik.V2Doku", 3, 1, function() DokulariIste(deneme + 1) end) end
          return
     end
     net.Start(NET)
          net.WriteUInt(1, 4)
     net.SendToServer()
end
hook.Add("InitPostEntity", "SardonYaratik.V2Doku", function() timer.Simple(2, DokulariIste) end)
if IsValid(LocalPlayer()) then timer.Simple(1, DokulariIste) end

-- (x, y, w, h) ekran pikseli; doku gerçek boyutuna kırpılır. Yoksa false (çağıran yedek çizer).
function V.Doku(ad, x, y, w, h, renk, a)
     local m = V.Mat[ad]
     if not m then Eksik(ad) return false end
     local d = V.DOKU[ad]
     surface_SetMaterial(m)
     if renk then
          surface_SetDrawColor(renk.r, renk.g, renk.b, 255 * (a or 1))
     else
          surface_SetDrawColor(255, 255, 255, 255 * (a or 1))
     end
     surface_DrawTexturedRectUV(x, y, w, h, 0, 0, d[1] / d[3], d[2] / d[4])
     return true
end

-- merkezden döndürülmüş (yalnız dolgusuz, kare dokular); aci derece, saat yönünde
function V.DokuDon(ad, cx, cy, w, h, aci, renk, a)
     local m = V.Mat[ad]
     if not m then Eksik(ad) return false end
     surface_SetMaterial(m)
     if renk then
          surface_SetDrawColor(renk.r, renk.g, renk.b, 255 * (a or 1))
     else
          surface_SetDrawColor(255, 255, 255, 255 * (a or 1))
     end
     surface_DrawTexturedRectRotated(cx, cy, w, h, -(aci or 0))
     return true
end

-- beyaz maske ikon, merkezden; renkle tonlanır. Yoksa küçük baklava.
function V.Ikon(ad, cx, cy, boy, renk, a)
     if V.Doku(ad, cx - boy / 2, cy - boy / 2, boy, boy, renk, a) then return end
     V.Baklava(cx, cy, boy * 0.18, renk, a, true)
end

------------------------------------------------------------------------ şekiller

local DORT = {{x = 0, y = 0}, {x = 0, y = 0}, {x = 0, y = 0}, {x = 0, y = 0}}
local function Dort(x1, y1, x2, y2, x3, y3, x4, y4)
     DORT[1].x, DORT[1].y = x1, y1
     DORT[2].x, DORT[2].y = x2, y2
     DORT[3].x, DORT[3].y = x3, y3
     DORT[4].x, DORT[4].y = x4, y4
     surface.DrawPoly(DORT)
end
V.Dort = Dort

-- baklava: dolu ya da (dolu = false) 1 px kenar
function V.Baklava(cx, cy, h, renk, a, dolu)
     draw.NoTexture()
     surface_SetDrawColor(renk.r, renk.g, renk.b, 255 * (a or 1))
     if dolu ~= false then
          Dort(cx, cy - h, cx + h, cy, cx, cy + h, cx - h, cy)
          return
     end
     local k = math_max(1, h * 0.34)
     Dort(cx, cy - h, cx + h, cy, cx + h - k, cy, cx, cy - h + k)
     Dort(cx + h, cy, cx, cy + h, cx, cy + h - k, cx + h - k, cy)
     Dort(cx, cy + h, cx - h, cy, cx - h + k, cy, cx, cy + h - k)
     Dort(cx - h, cy, cx, cy - h, cx, cy - h + k, cx - h + k, cy)
end

-- ince çubuk: zemin izi + oranlı dolgu (köşeler yuvarlatılmadan; 3-4 px'te fark edilmez)
function V.Cubuk(x, y, w, h, oran, renk, a, iz)
     iz = iz or V.R.iz
     draw.NoTexture()
     surface_SetDrawColor(iz.r, iz.g, iz.b, 255 * (a or 1))
     surface.DrawRect(x, y, w, h)
     oran = math_Clamp(oran or 0, 0, 1)
     if oran > 0 then
          surface_SetDrawColor(renk.r, renk.g, renk.b, 255 * (a or 1))
          surface.DrawRect(x, y, math_max(1, w * oran), h)
     end
end

-- yay: merkez, yarıçap, kalınlık, a0 → a1 (radyan, saat yönü, 0 = sağ)
function V.Yay(cx, cy, r, t, a0, a1, renk, a)
     if a1 - a0 <= 0.001 then return end
     draw.NoTexture()
     surface_SetDrawColor(renk.r, renk.g, renk.b, 255 * (a or 1))
     local n = math_max(2, math.ceil(48 * (a1 - a0) / (math.pi * 2)))
     local ic, dis = r - t / 2, r + t / 2
     local c0, s0 = math_cos(a0), math_sin(a0)
     for i = 1, n do
          local b = a0 + (a1 - a0) * i / n
          local c1, s1 = math_cos(b), math_sin(b)
          Dort(cx + c0 * ic, cy + s0 * ic, cx + c0 * dis, cy + s0 * dis, cx + c1 * dis, cy + s1 * dis, cx + c1 * ic, cy + s1 * ic)
          c0, s0 = c1, s1
     end
end

-- kalın çizgi (döndürülmüş dikdörtgen)
function V.Cizgi(x1, y1, x2, y2, t, renk, a)
     local dx, dy = x2 - x1, y2 - y1
     local l = math_sqrt(dx * dx + dy * dy)
     if l < 0.01 then return end
     draw.NoTexture()
     surface_SetDrawColor(renk.r, renk.g, renk.b, 255 * (a or 1))
     surface_DrawTexturedRectRotated((x1 + x2) / 2, (y1 + y2) / 2, l + t * 0.5, t, -math.deg(math.atan2(dy, dx)))
end

------------------------------------------------------------------------ tuş kapağı (tek nine-slice: 4 px kenar)

local KC_U = {0, 4 / 64, 60 / 64, 1}
local KC_V = {0, 4 / 32, 28 / 32, 1}

function V.TusKapagi(x, y, w, h, s, a, dolum, dolumRenk)
     local m = V.Mat.keycap
     local k = math_max(2, math.Round(4 * s))
     x, y, w, h = math.Round(x), math.Round(y), math.Round(w), math.Round(h)
     if m then
          surface_SetMaterial(m)
          surface_SetDrawColor(255, 255, 255, 255 * (a or 1))
          local xs = {x, x + k, x + w - k, x + w}
          local ys = {y, y + k, y + h - k, y + h}
          for i = 1, 3 do
               for j = 1, 3 do
                    surface_DrawTexturedRectUV(xs[i], ys[j], xs[i + 1] - xs[i], ys[j + 1] - ys[j], KC_U[i], KC_V[j], KC_U[i + 1], KC_V[j + 1])
               end
          end
     else
          Eksik("keycap")
          draw.NoTexture()
          surface_SetDrawColor(V.R.zemin.r, V.R.zemin.g, V.R.zemin.b, 255 * (a or 1))
          surface.DrawRect(x, y, w, h)
          surface_SetDrawColor(V.R.sonuk.r, V.R.sonuk.g, V.R.sonuk.b, 255 * (a or 1))
          surface.DrawOutlinedRect(x, y, w, h, 1)
     end
     -- basılı tutma dolumu (ör. kalkış): kapağın içinde soldan sağa
     if dolum and dolum > 0 then
          local c = dolumRenk or V.R.enerji
          draw.NoTexture()
          surface_SetDrawColor(c.r, c.g, c.b, 90 * (a or 1))
          surface.DrawRect(x + 1, y + 1, (w - 2) * math_Clamp(dolum, 0, 1), h - 2)
     end
end

-- tuş adı: bağdan (ör. "+jump") gerçek tuş; fare tuşları Türkçe
local FARE = {MOUSE1 = "SOL TIK", MOUSE2 = "SAĞ TIK", MOUSE3 = "ORTA TIK", MWHEELUP = "TEKER ↑", MWHEELDOWN = "TEKER ↓"}
function V.TusAdi(bag, yedek)
     local ad = input.LookupBinding(bag)
     if not ad or ad == "" then return yedek end
     ad = string.upper(ad)
     return FARE[ad] or ad
end
function V.KodAdi(kod, yedek)
     local ad = kod and kod > 0 and input.GetKeyName(kod)
     if not ad or ad == "" then return yedek end
     ad = string.upper(ad)
     return FARE[ad] or ad
end

-- kapak + yazı: x sol kenar, cy satır ortası; toplam genişliği döner
function V.Ipucu(tus, yazi, x, cy, s, a, yaziRenk, dolum, kapali)
     local f = V.Font("govde", 12, s)
     local tw = V.Olcu(tus, f)
     local w = math_max(25 * s, tw + 16 * s)
     local h = 23 * s
     V.TusKapagi(x, cy - h / 2, w, h, s, a * (kapali and 0.55 or 1), dolum)
     V.Yazi(tus, f, x + w / 2, cy + 5 * s, V.R.yazi, a * (kapali and 0.6 or 1), 1)
     local w2 = 0
     if yazi and yazi ~= "" then
          w2 = 9 * s + V.Yazi(yazi, V.Font("govde", 14, s), x + w + 9 * s, cy + 5 * s, yaziRenk or V.R.yazi, a * (kapali and 0.6 or 1), 0)
     end
     return w + w2
end

------------------------------------------------------------------------ zaman eğrileri

function V.Yumusak(t) t = math_Clamp(t, 0, 1) return t * t * (3 - 2 * t) end
function V.Cikis(t) t = math_Clamp(t, 0, 1) return 1 - (1 - t) ^ 3 end

-- kare hızından bağımsız yaklaşma (hiz: 1/sn)
function V.Yaklas(simdi, hedef, hiz, dt)
     return hedef + (simdi - hedef) * math.exp(-hiz * dt)
end

------------------------------------------------------------------------ 2B parçacıklar (olaylarda)

-- katman: "hud" (HUDPaint'te çizilir) ya da "panel" (açık mühür kendi Paint'inde çizer)
V.Parcaciklar = V.Parcaciklar or {hud = {}, panel = {}}
local P = V.Parcaciklar
local ENCOK = 160

-- p = {x, y, vx, vy, ax, ay, omur, boy, boy2, renk, a, tur = "yildiz"|"isik", don, sur}
function V.Parcacik(katman, p)
     if V.Sade() then return end
     local l = P[katman]
     if #l >= ENCOK then table.remove(l, 1) end
     p.t = RealTime()
     p.vx, p.vy, p.ax, p.ay = p.vx or 0, p.vy or 0, p.ax or 0, p.ay or 0
     p.don = p.don or 0
     p.aci = math.random() * 360
     l[#l + 1] = p
end

-- noktadan saçılan kıvılcımlar. yon (radyan) verilirse o yöne ±yayilim
function V.Kivilcim(katman, x, y, renk, adet, hiz, omur, boy, s, yon, yayilim)
     s = s or V.Olcek()
     -- yıldız dokusu altın renkli: tonlanınca bulanır, o yüzden yalnız altın kıvılcımlarda yıldız
     local altin = renk == V.R.altin
     for i = 1, adet do
          local aci = yon and (yon + (math.random() - 0.5) * (yayilim or 1.2)) or math.random() * math.pi * 2
          local v = (hiz or 60) * (0.45 + math.random() * 0.55) * s
          V.Parcacik(katman, {
               x = x, y = y, vx = math_cos(aci) * v, vy = math_sin(aci) * v, ay = 18 * s,
               omur = (omur or 0.8) * (0.6 + math.random() * 0.4), boy = (boy or 14) * s * (0.7 + math.random() * 0.5), boy2 = 0,
               renk = renk, a = 1, tur = (altin and i % 3 ~= 0) and "yildiz" or "isik", don = (math.random() - 0.5) * 240, sur = 2.2,
          })
     end
end

-- (x0,y0) → (x1,y1) kavisli yolda kuyruklu yıldız; varınca küçük patlama
function V.Kuyruklu(katman, x0, y0, x1, y1, renk, sure, s, bitince)
     if V.Sade() then if bitince then bitince() end return end
     s = s or V.Olcek()
     local dx, dy = x1 - x0, y1 - y0
     local l = math_sqrt(dx * dx + dy * dy)
     local kx, ky = (x0 + x1) / 2 - dy * 0.22, (y0 + y1) / 2 + dx * 0.22 - l * 0.08
     V.Parcacik(katman, {x = x0, y = y0, omur = sure or 0.45, boy = 22 * s, boy2 = 16 * s, renk = renk, a = 1, tur = "kuyruk",
          yol = {x0, y0, kx, ky, x1, y1}, bitince = bitince, s = s, iz = 0})
end

local function Bezier(y, t)
     local u = 1 - t
     return u * u * y[1] + 2 * u * t * y[3] + t * t * y[5], u * u * y[2] + 2 * u * t * y[4] + t * t * y[6]
end

local function IsikCiz(x, y, boy, renk, a)
     if Y.Parilti then Y.Parilti(x, y, boy * 2.2, renk, 255 * a * 0.55) end
end

function V.ParcacikCiz(katman, alfa)
     local l = P[katman]
     if #l == 0 then return end
     local simdi = RealTime()
     local dt = math_min(RealFrameTime(), 0.05)
     alfa = alfa or 1
     local yildiz = V.Mat.star_spark
     local bitenler
     for i = #l, 1, -1 do
          local p = l[i]
          local g = (simdi - p.t) / p.omur
          if g >= 1 then
               table.remove(l, i)
               if p.bitince then bitenler = bitenler or {} bitenler[#bitenler + 1] = p end
          else
               local a = p.a * alfa
               if p.tur == "kuyruk" then
                    local t = V.Cikis(g)
                    p.x, p.y = Bezier(p.yol, t)
                    -- kuyruk: geride sönen küçük kıvılcımlar
                    p.iz = p.iz + dt
                    if p.iz > 0.018 then
                         p.iz = 0
                         V.Parcacik(katman, {x = p.x, y = p.y, vx = (math.random() - 0.5) * 30 * p.s, vy = (math.random() - 0.5) * 30 * p.s,
                              omur = 0.35, boy = p.boy2, boy2 = 0, renk = p.renk, a = 0.8, tur = "isik", don = 180})
                    end
                    IsikCiz(p.x, p.y, p.boy, p.renk, a)
                    if yildiz then
                         render.OverrideBlend(true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)
                         V.DokuDon("star_spark", p.x, p.y, p.boy * 0.8, p.boy * 0.8, simdi * 200 % 360, nil, a)
                         render.OverrideBlend(false)
                    end
               else
                    p.vx, p.vy = p.vx + p.ax * dt, p.vy + p.ay * dt
                    if p.sur then p.vx, p.vy = p.vx * (1 - p.sur * dt), p.vy * (1 - p.sur * dt) end
                    p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt
                    p.aci = p.aci + p.don * dt
                    local boy = Lerp(g, p.boy, p.boy2 or 0)
                    local sol = (g < 0.15 and g / 0.15 or 1) * (1 - g) * a
                    if p.tur == "isik" or not yildiz then
                         IsikCiz(p.x, p.y, boy, p.renk, sol)
                    else
                         render.OverrideBlend(true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)
                         V.DokuDon("star_spark", p.x, p.y, boy, boy, p.aci, nil, sol)
                         render.OverrideBlend(false)
                    end
               end
          end
     end
     if bitenler then
          for _, p in ipairs(bitenler) do p.bitince(p.x, p.y) end
     end
end

hook.Add("HUDPaint", "SardonYaratik.V2Parcacik", function()
     V.ParcacikCiz("hud")
end)

-- açık mühür yokken panel katmanında kalanlar HUD'a devredilir (mühür kapanınca kaybolmasın)
function V.PanelParcaciklariDevret()
     for _, p in ipairs(P.panel) do P.hud[#P.hud + 1] = p end
     table.Empty(P.panel)
end
