-- "addons\\sardonkitap\\lua\\sardon_kitap\\cl_1tema.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Kitap :: istemci teması, yazı yardımcıları, bildirim kartları, efektler, sunucu verisi,
-- anı kartı (yer keşfi: SHINE Anı Defteri tasarımı, sahne görseli sunucudan parça parça)
-- Fontlar Türkçe harfleri tam gösterenlerden: Georgia (gövde), Playfair Display (başlık),
-- Montserrat SemiBold (etiket), Jim Nightshade (kenar notları el yazısı).
-- Dokular: oyunla gelenler (vgui/gradient-*, sprites/light_glow02_add, effects/spark, particle/*) ve
-- asa menüsünün gömülü kitap dokuları (HpwRewrite.Nocturne.Kitap.Mat); yoksa düz renk.

local SK = SardonKitap

SK.R = {
     deri = Color(58, 34, 24), deriK = Color(34, 20, 14), deriA = Color(84, 52, 34),
     parsomen = Color(234, 221, 190), parsomenK = Color(216, 199, 160), kenar = Color(170, 142, 98),
     murekkep = Color(44, 30, 20), murekkepK = Color(96, 76, 54), soluk = Color(138, 118, 90),
     altin = Color(176, 132, 58), altinA = Color(236, 204, 128),
     iyi = Color(62, 112, 56), kotu = Color(158, 58, 44), uyari = Color(170, 104, 34), mavi = Color(52, 82, 130),
     zemin = Color(8, 6, 4, 215),
     hud = Color(18, 15, 12, 238), hudCizgi = Color(196, 156, 74, 110), hudYazi = Color(238, 228, 206), hudSoluk = Color(176, 164, 142),
}
local R = SK.R

local olcek = 1
function SK.S(x) return math.Round(x * olcek) end

local fontKur = false
function SK.Fontlar(zorla)
     if fontKur and not zorla then return end
     fontKur = true
     olcek = math.Clamp(ScrH() / 1080, 0.72, 1.4)
     local function F(ad, yuz, boy, kalin)
          surface.CreateFont("sk." .. ad, {font = yuz, size = math.max(10, math.Round(boy * olcek)), weight = kalin or 500, extended = true, antialias = true})
     end
     F("dev", "Playfair Display SemiBold", 38, 600)
     F("baslik", "Playfair Display SemiBold", 29, 600)
     F("baslikK", "Playfair Display SemiBold", 21, 600)
     F("metin", "Georgia", 19)
     F("metinK", "Georgia", 16)
     F("italik", "Georgia", 16)
     F("etiket", "Montserrat SemiBold", 14, 600)
     F("ust", "Montserrat SemiBold", 12, 600)
     F("el", "Jim Nightshade", 24)
     F("elK", "Jim Nightshade", 19)
     F("hud", "Montserrat SemiBold", 17, 600)
     F("hudK", "Montserrat Medium", 14, 500)
end

hook.Add("OnScreenSizeChanged", "SardonKitap.Font", function() SK.Fontlar(true) end)

/*
*   yazı
*/
function SK.Yazi(t, font, x, y, c, ax, ay)
     draw.SimpleText(t, "sk." .. font, x, y, c, ax or TEXT_ALIGN_LEFT, ay or TEXT_ALIGN_TOP)
end

function SK.Olc(t, font)
     surface.SetFont("sk." .. font)
     return surface.GetTextSize(t)
end

-- kelime kelime satırlara böler ("\n" yeni paragraf)
function SK.Sar(metin, font, w)
     surface.SetFont("sk." .. font)
     local satirlar = {}
     for paragraf in string.gmatch(tostring(metin or "") .. "\n", "(.-)\n") do
          local satir = ""
          for kelime in string.gmatch(paragraf, "%S+") do
               local dene = satir == "" and kelime or (satir .. " " .. kelime)
               if surface.GetTextSize(dene) > w and satir ~= "" then
                    satirlar[#satirlar + 1] = satir
                    satir = kelime
               else
                    satir = dene
               end
          end
          satirlar[#satirlar + 1] = satir
     end
     return satirlar
end

function SK.SatirYuk(font)
     local _, h = SK.Olc("Ağİ", font)
     return h
end

/*
*   çizim yardımcıları
*/
local grU, grD = Material("vgui/gradient-u"), Material("vgui/gradient-d")
local grL, grR = Material("vgui/gradient-l"), Material("vgui/gradient-r")
local isik = Material("sprites/light_glow02_add")
SK.M = {isik = isik, kivilcim = Material("effects/spark"), duman = Material("particle/smokesprites_0001"),
     halka = Material("particle/particle_ring_wave_additive"), iz = Material("trails/laser"), secim = Material("effects/select_ring")}

function SK.Doku(ad)
     local N = HpwRewrite and HpwRewrite.Nocturne
     local K = N and N.Kitap
     return K and K.Mat and K.Mat(ad) or nil
end

function SK.Kutu(x, y, w, h, c)
     surface.SetDrawColor(c)
     draw.NoTexture()
     surface.DrawRect(x, y, w, h)
end

-- parşömen sayfa: düz zemin, kenarlarda kararan gölge (gradient yönleri: -u üst opak, -l sol opak)
function SK.Parsomen(x, y, w, h, solSirt, sagSirt)
     SK.Kutu(x, y, w, h, R.parsomen)
     local g = SK.S(26)
     surface.SetDrawColor(R.kenar.r, R.kenar.g, R.kenar.b, 70)
     surface.SetMaterial(grU) surface.DrawTexturedRect(x, y, w, g)
     surface.SetMaterial(grD) surface.DrawTexturedRect(x, y + h - g, w, g)
     surface.SetDrawColor(R.kenar.r, R.kenar.g, R.kenar.b, 60)
     surface.SetMaterial(grL) surface.DrawTexturedRect(x, y, g, h)
     surface.SetMaterial(grR) surface.DrawTexturedRect(x + w - g, y, g, h)
     -- sırt tarafı daha koyu (iki sayfanın birleştiği yer)
     local s = SK.S(44)
     surface.SetDrawColor(60, 40, 22, 90)
     if sagSirt then surface.SetMaterial(grR) surface.DrawTexturedRect(x + w - s, y, s, h) end
     if solSirt then surface.SetMaterial(grL) surface.DrawTexturedRect(x, y, s, h) end
     draw.NoTexture()
end

function SK.Deri(x, y, w, h)
     SK.Kutu(x, y, w, h, R.deri)
     local m = SK.Doku("leather_dark")
     if m then
          surface.SetMaterial(m)
          surface.SetDrawColor(255, 255, 255, 120)
          surface.DrawTexturedRectUV(x, y, w, h, 0, 0, w / 512, h / 512)
          draw.NoTexture()
     end
     surface.SetDrawColor(R.altin.r, R.altin.g, R.altin.b, 120)
     surface.DrawOutlinedRect(x + SK.S(6), y + SK.S(6), w - SK.S(12), h - SK.S(12), 1)
end

function SK.Isik(x, y, r, c, a)
     surface.SetMaterial(isik)
     surface.SetDrawColor(c.r, c.g, c.b, a or 255)
     surface.DrawTexturedRect(x - r, y - r, r * 2, r * 2)
     draw.NoTexture()
end

-- düğme alanı (Paint içinde): fare üstünde mi
function SK.Ustunde(pnl, x, y, w, h)
     local mx, my = pnl:CursorPos()
     return mx >= x and mx <= x + w and my >= y and my <= y + h
end

/*
*   bildirim kartları (üst orta)
*/
SK.Kartlar = SK.Kartlar or {}
local TUR_RENK = {iyi = R.iyi, uyari = R.uyari, bilgi = R.mavi, kesif = R.altin}
local TUR_SES = {iyi = "buttons/button9.wav", uyari = "buttons/button10.wav", bilgi = "buttons/button14.wav", kesif = "ambient/levels/forest/dist_birds1.wav"}

function SK.Kart(baslik, alt, tur)
     SK.Fontlar()
     table.insert(SK.Kartlar, 1, {baslik = baslik, alt = alt, tur = tur or "bilgi", t = CurTime()})
     while #SK.Kartlar > 4 do table.remove(SK.Kartlar) end
     local s = TUR_SES[tur or "bilgi"]
     if s then surface.PlaySound(s) end
end

hook.Add("HUDPaint", "SardonKitap.Kartlar", function()
     if #SK.Kartlar == 0 then return end
     SK.Fontlar()
     local y = SK.S(90)
     local w = SK.S(520)
     for i = #SK.Kartlar, 1, -1 do
          local k = SK.Kartlar[i]
          if CurTime() - k.t > 7 then table.remove(SK.Kartlar, i) end
     end
     for _, k in ipairs(SK.Kartlar) do
          local gecen = CurTime() - k.t
          local a = math.Clamp(math.min(gecen * 4, (7 - gecen) * 2), 0, 1)
          local satirlar = k.alt ~= "" and SK.Sar(k.alt, "hudK", w - SK.S(40)) or {}
          local h = SK.S(40) + #satirlar * SK.S(18)
          local x = ScrW() / 2 - w / 2
          surface.SetAlphaMultiplier(a)
          SK.Kutu(x, y, w, h, R.hud)
          local c = TUR_RENK[k.tur] or R.mavi
          SK.Kutu(x, y, SK.S(4), h, c)
          surface.SetDrawColor(R.hudCizgi)
          surface.DrawOutlinedRect(x, y, w, h, 1)
          SK.Yazi(k.baslik, "hud", x + SK.S(20), y + SK.S(10), R.hudYazi)
          for j, s in ipairs(satirlar) do
               SK.Yazi(s, "hudK", x + SK.S(20), y + SK.S(14) + j * SK.S(18), R.hudSoluk)
          end
          surface.SetAlphaMultiplier(1)
          y = y + h + SK.S(8)
     end
end)

/*
*   sunucu verisi
*/
net.Receive("SardonKitap.Ayar", function() SK.AyarUygula(net.ReadTable()) end)

net.Receive("SardonKitap.Metin", function()
     local n = net.ReadUInt(16)
     local veri = net.ReadData(n)
     local t = util.JSONToTable(util.Decompress(veri or "") or "") or {}
     table.Empty(SK.MetinOzel)
     table.Merge(SK.MetinOzel, t)
end)

SK.Harita = SK.Harita or {raflar = {}, tezgahlar = {}}
net.Receive("SardonKitap.Harita", function()
     local h = {raflar = {}, tezgahlar = {}}
     for i = 1, net.ReadUInt(8) do
          h.raflar[i] = {id = net.ReadString(), ad = net.ReadString(), pos = net.ReadVector(), yaw = net.ReadFloat(),
               mn = net.ReadVector(), mx = net.ReadVector(), kitap = net.ReadString()}
     end
     for i = 1, net.ReadUInt(8) do h.tezgahlar[i] = {pos = net.ReadVector(), yaw = net.ReadFloat()} end
     if net.ReadBool() then h.tezgah = {pos = net.ReadVector(), yaw = net.ReadFloat(), mn = net.ReadVector(), mx = net.ReadVector()} end
     SK.Harita = h
end)

net.Receive("SardonKitap.Bildirim", function()
     SK.Kart(net.ReadString(), net.ReadString(), net.ReadString())
end)

/*
*   tekleme / şaka / ustalaşma efektleri
*/
local function Asa(ply)
     local ang = ply:EyeAngles()
     return ply:EyePos() + ang:Forward() * 22 + ang:Right() * 8 - ang:Up() * 10
end

local function Kafa(ply)
     local b = ply:LookupBone("ValveBiped.Bip01_Head1")
     local m = b and ply:GetBoneMatrix(b)
     return m and (m:GetTranslation() + Vector(0, 0, 6)) or (ply:EyePos() + Vector(0, 0, 6))
end

local EFEKT = {}

EFEKT.kivilcim = function(ply, em)
     local p0 = Asa(ply)
     for i = 1, 14 do
          local p = em:Add("effects/spark", p0)
          if p then
               p:SetVelocity(VectorRand() * 70 + ply:GetAimVector() * 40)
               p:SetDieTime(math.Rand(0.4, 0.8))
               p:SetStartAlpha(255) p:SetEndAlpha(0)
               p:SetStartSize(2) p:SetEndSize(0)
               p:SetStartLength(6) p:SetEndLength(1)
               p:SetGravity(Vector(0, 0, -200))
               p:SetColor(255, 220, 150)
          end
     end
     for i = 1, 3 do
          local p = em:Add("particle/smokesprites_0001", p0)
          if p then
               p:SetVelocity(VectorRand() * 10 + Vector(0, 0, 15))
               p:SetDieTime(1.4) p:SetStartAlpha(90) p:SetEndAlpha(0)
               p:SetStartSize(4) p:SetEndSize(14)
               p:SetRoll(math.Rand(0, 360)) p:SetColor(120, 120, 120)
          end
     end
end

EFEKT.duman = function(ply, em)
     local p0 = Kafa(ply)
     for i = 1, 16 do
          local p = em:Add("particle/smokesprites_0001", p0 + VectorRand() * 6)
          if p then
               p:SetVelocity(VectorRand() * 12 + Vector(0, 0, 10))
               p:SetDieTime(math.Rand(2.5, 4)) p:SetStartAlpha(150) p:SetEndAlpha(0)
               p:SetStartSize(8) p:SetEndSize(26)
               p:SetRoll(math.Rand(0, 360)) p:SetRollDelta(math.Rand(-0.5, 0.5))
               p:SetColor(70, 66, 62)
          end
     end
end

EFEKT.hickirik = function(ply, em)
     local p0 = Kafa(ply)
     for i = 1, 6 do
          local p = em:Add("sprites/light_glow02_add", p0 + VectorRand() * 4)
          if p then
               p:SetVelocity(Vector(0, 0, 18) + VectorRand() * 6)
               p:SetDieTime(math.Rand(1.2, 2.2)) p:SetStartAlpha(180) p:SetEndAlpha(0)
               p:SetStartSize(4) p:SetEndSize(1)
               p:SetColor(200, 230, 255)
          end
     end
end

EFEKT.kurbaga = function(ply, em)
     local p0 = Kafa(ply)
     for i = 1, 10 do
          local p = em:Add("sprites/light_glow02_add", p0 + VectorRand() * 8)
          if p then
               p:SetVelocity(VectorRand() * 20)
               p:SetDieTime(math.Rand(1, 2)) p:SetStartAlpha(220) p:SetEndAlpha(0)
               p:SetStartSize(8) p:SetEndSize(2)
               p:SetColor(90, 200, 70)
          end
     end
     local r = em:Add("particle/particle_ring_wave_additive", p0)
     if r then r:SetDieTime(0.8) r:SetStartAlpha(160) r:SetEndAlpha(0) r:SetStartSize(4) r:SetEndSize(40) r:SetColor(90, 200, 70) end
end

EFEKT.renkli = function(ply, em)
     local p0 = Kafa(ply) + Vector(0, 0, 30)
     for i = 1, 40 do
          local p = em:Add("effects/spark", p0 + VectorRand() * 20)
          if p then
               local c = HSVToColor(math.random(0, 360), 0.7, 1)
               p:SetVelocity(VectorRand() * 30 - Vector(0, 0, 20))
               p:SetDieTime(math.Rand(1.5, 3)) p:SetStartAlpha(255) p:SetEndAlpha(0)
               p:SetStartSize(2.5) p:SetEndSize(0.5)
               p:SetStartLength(4) p:SetEndLength(2)
               p:SetGravity(Vector(0, 0, -60))
               p:SetColor(c.r, c.g, c.b)
          end
     end
end

EFEKT.usta = function(ply, em)
     local p0 = ply:GetPos() + Vector(0, 0, 4)
     local r = em:Add("particle/particle_ring_wave_additive", p0)
     if r then r:SetDieTime(1.2) r:SetStartAlpha(200) r:SetEndAlpha(0) r:SetStartSize(10) r:SetEndSize(90) r:SetAngles(Angle(90, 0, 0)) r:SetColor(240, 200, 110) end
     for i = 1, 26 do
          local a = math.rad(i * (360 / 26))
          local p = em:Add("sprites/light_glow02_add", p0 + Vector(math.cos(a) * 20, math.sin(a) * 20, 0))
          if p then
               p:SetVelocity(Vector(0, 0, math.Rand(30, 70)))
               p:SetDieTime(math.Rand(1, 1.8)) p:SetStartAlpha(220) p:SetEndAlpha(0)
               p:SetStartSize(5) p:SetEndSize(1)
               p:SetColor(240, 210, 130)
          end
     end
end

EFEKT.ogrendi = function(ply, em)
     local p0 = Asa(ply)
     for i = 1, 24 do
          local p = em:Add("sprites/light_glow02_add", p0)
          if p then
               p:SetVelocity(VectorRand() * 50)
               p:SetDieTime(math.Rand(0.8, 1.5)) p:SetStartAlpha(230) p:SetEndAlpha(0)
               p:SetStartSize(4) p:SetEndSize(0)
               p:SetColor(170, 210, 255)
          end
     end
end

net.Receive("SardonKitap.Efekt", function()
     local ply, tur = net.ReadEntity(), net.ReadString()
     if not IsValid(ply) or not EFEKT[tur] then return end
     if ply:GetPos():DistToSqr(EyePos()) > 1500 * 1500 then return end
     local em = ParticleEmitter(ply:GetPos())
     if not em then return end
     EFEKT[tur](ply, em)
     em:Finish()
end)

/*
*   anı kartı (yer keşfi) — SHINE Anı Defteri tasarımı: kapalı mühür, iki kapak ortadan dışa kayar,
*   pencerede yerin sahnesi; sonra ters sırayla kapanır. Sahne gelmeden mühür açılmaz (en çok ANI_BEKLE sn).
*   Dokular sunucudan (sv_4dunya) parça parça gelir, data/sardon_kitap/ani/<ad>_<crc>.<uzantı> önbelleğinde kalır.
*   Sınama: sardon_kitap_ani <yer id | hepsi> (yönetici), sardon_kitap_ani_temizle
*/
local ANI = SK.AniDurum or {liste = {}, hazir = {}, mat = {}, parca = {}, istendi = {}, kuyruk = {}}
SK.AniDurum = ANI
local ANI_DIZIN = "sardon_kitap/ani"
local ANI_UI = {"cerceve.png", "kapak_sol.png", "kapak_sag.png"}
local ANI_SURE = {kapali = 0.45, acilis = 0.85, acik = 4.8, kapanis = 0.65, sonme = 0.25}
local ANI_TOPLAM = 0.45 + 0.85 + 4.8 + 0.65 + 0.25
local ANI_BEKLE, ANI_BEKLE_UI = 6, 12
local ANI_SES = "ambient/levels/forest/dist_birds1.wav"
local aniFildisi, aniAltin = Color(231, 222, 192), Color(184, 158, 98)
local aniYesil, aniYesilK = Color(22, 46, 42), Color(14, 30, 27)

local function AniYol(ad, crc)
     local kok, uz = string.match(ad, "^(.-)%.(%a+)$")
     return ANI_DIZIN .. "/" .. kok .. "_" .. string.format("%08x", crc) .. "." .. uz
end

local function AniMat(ad)
     if not ad or not ANI.hazir[ad] then return nil end
     local m = ANI.mat[ad]
     if m == nil then
          local d = ANI.liste[ad]
          m = d and Material("../data/" .. AniYol(ad, d.crc), "smooth mips")
          m = (m and not m:IsError()) and m or false
          ANI.mat[ad] = m
     end
     return m or nil
end

local function AniListeIste()
     if (ANI.listeIstendi or 0) > RealTime() then return end
     ANI.listeIstendi = RealTime() + 11
     net.Start("SardonKitap.AniIste")
     net.WriteUInt(0, 6)
     net.SendToServer()
end

local function AniIste(adlar)
     if not next(ANI.liste) then AniListeIste() return end
     local liste = {}
     for _, ad in ipairs(adlar) do
          if ANI.liste[ad] and not ANI.hazir[ad] and (ANI.istendi[ad] or 0) < RealTime() and #liste < 60 then
               ANI.istendi[ad] = RealTime() + 125
               liste[#liste + 1] = ad
          end
     end
     if #liste == 0 then return end
     net.Start("SardonKitap.AniIste")
     net.WriteUInt(#liste, 6)
     for _, ad in ipairs(liste) do net.WriteString(ad) end
     net.SendToServer()
end

net.Receive("SardonKitap.AniListe", function()
     local liste = {}
     for _ = 1, net.ReadUInt(8) do
          local ad, crc, boyut = net.ReadString(), net.ReadUInt(32), net.ReadUInt(24)
          liste[ad] = {crc = crc, boyut = boyut}
     end
     local hazir = {}
     for ad, d in pairs(liste) do
          local yol = AniYol(ad, d.crc)
          if file.Exists(yol, "DATA") and file.Size(yol, "DATA") == d.boyut then hazir[ad] = true end
     end
     ANI.liste, ANI.hazir, ANI.mat = liste, hazir, {}
     -- çerçeve önden insin; bekleyen kartların sahneleri
     local iste = table.Copy(ANI_UI)
     if ANI.aktif and ANI.aktif.gorsel then iste[#iste + 1] = ANI.aktif.gorsel end
     for _, k in ipairs(ANI.kuyruk) do iste[#iste + 1] = k.gorsel end
     AniIste(iste)
end)

net.Receive("SardonKitap.AniParca", function()
     local ad, crc = net.ReadString(), net.ReadUInt(32)
     local i, n = net.ReadUInt(10), net.ReadUInt(10)
     local veri = net.ReadData(net.ReadUInt(16))
     if not string.match(ad, "^[%w_]+%.%a+$") or n < 1 or i < 1 or i > n then return end
     local p = ANI.parca[ad]
     if not p or p.crc ~= crc or p.n ~= n then
          p = {crc = crc, n = n, gelen = 0, t = {}}
          ANI.parca[ad] = p
     end
     if not p.t[i] then
          p.t[i] = veri or ""
          p.gelen = p.gelen + 1
     end
     if p.gelen < n then return end
     ANI.parca[ad] = nil
     local tum = table.concat(p.t)
     if tonumber(util.CRC(tum)) ~= crc then return end      -- bozuk: 125 sn sonra yeniden istenir
     ANI.liste[ad] = {crc = crc, boyut = #tum}
     local yol = AniYol(ad, crc)
     file.CreateDir(ANI_DIZIN)
     file.Write(yol, tum)
     -- aynı dokunun eski sürümleri
     local kok = string.match(ad, "^(.-)%.")
     for _, f in ipairs(file.Find(ANI_DIZIN .. "/" .. kok .. "_*", "DATA") or {}) do
          if string.match(f, "^" .. string.PatternSafe(kok) .. "_%x+%.%a+$") and ANI_DIZIN .. "/" .. f ~= yol then
               file.Delete(ANI_DIZIN .. "/" .. f)
          end
     end
     ANI.hazir[ad], ANI.mat[ad] = true, nil
end)

local function AniKarakter()
     local c = IsValid(LocalPlayer()) and LocalPlayer().GetCharacter and LocalPlayer():GetCharacter()
     return c and c:GetID() or 0
end

function SK.AniKart(yerId, onizleme)
     local y
     for _, v in ipairs(SK.YERLER or {}) do
          if v.id == yerId then y = v break end
     end
     if not y then return false end
     if ANI.aktif and ANI.aktif.id == yerId then return false end
     for _, k in ipairs(ANI.kuyruk) do
          if k.id == yerId then return false end
     end
     if not onizleme then
          while #ANI.kuyruk >= 7 do table.remove(ANI.kuyruk, 1) end
     end
     local gorsel = y.id .. ".jpg"
     ANI.kuyruk[#ANI.kuyruk + 1] = {id = y.id, ad = y.ad, gorsel = gorsel, char = AniKarakter(), onizleme = onizleme == true,
          gecen = 0, bekleUI = 0, bekle = 0}
     AniIste({gorsel, ANI_UI[1], ANI_UI[2], ANI_UI[3]})
     return true
end

net.Receive("SardonKitap.Ani", function()
     SK.AniKart(net.ReadString(), false)
end)

local function AniCizilir()
     if gui.IsGameUIVisible() then return false end
     if ix and ix.gui and IsValid(ix.gui.characterMenu) then return false end
     return true
end

local function AniUIHazir()
     return AniMat(ANI_UI[1]) and AniMat(ANI_UI[2]) and AniMat(ANI_UI[3])
end

local function Yumusak(v)
     v = math.Clamp(v, 0, 1)
     return v * v * (3 - 2 * v)
end

-- ilerleme (0 kapalı mühür … 1 açık kart), opaklık
local function AniEvre(t)
     local S = ANI_SURE
     local kapanis = S.kapali + S.acilis + S.acik
     local sonme = kapanis + S.kapanis
     if t < S.kapali then return 0, Yumusak(t / 0.2) end
     if t < S.kapali + S.acilis then return Yumusak((t - S.kapali) / S.acilis), 1 end
     if t < kapanis then return 1, 1 end
     if t < sonme then return 1 - Yumusak((t - kapanis) / S.kapanis), 1 end
     return 0, 1 - Yumusak((t - sonme) / S.sonme)
end
SK.AniEvre = AniEvre

hook.Add("Think", "SardonKitap.Ani", function()
     local simdi = RealTime()
     local dt = math.Clamp(simdi - (ANI.sonThink or simdi), 0, 0.25)
     ANI.sonThink = simdi
     local k = ANI.aktif
     if not k then
          if not ANI.kuyruk[1] then return end
          k = table.remove(ANI.kuyruk, 1)
          ANI.aktif = k
     end
     if not k.onizleme and k.char ~= AniKarakter() then
          ANI.aktif = nil
          return
     end
     if not AniCizilir() then return end
     if k.gecen == 0 then
          -- çerçeve henüz inmediyse bekle; inmezse düz çizimle aç
          if not AniUIHazir() and k.bekleUI < ANI_BEKLE_UI then
               k.bekleUI = k.bekleUI + dt
               return
          end
          surface.PlaySound(ANI_SES)
     end
     local t = k.gecen + dt
     -- kapalı mühür sahne gelene dek bekler
     if t > ANI_SURE.kapali and not AniMat(k.gorsel) and k.bekle < ANI_BEKLE then
          k.bekle = k.bekle + dt
          t = math.max(k.gecen, ANI_SURE.kapali)
     end
     k.gecen = math.max(t, 0.0001)
     if k.gecen >= ANI_TOPLAM then ANI.aktif = nil end
end)

-- Ölçü: tasarım birimi = doku pikseli × o (1080p'de o = 0,5 → kart 800×180 px).
-- İncelik: dokuların düz satırlarından bir kısmı atlanır (420 → 360); kapaktaki mühür deseni ve
-- çerçevenin yazı bantları aynen kalır, yalnız sahne penceresi kısalır.
local ANI_OLCEK = 0.5
local ANI_YUK = 360
local ANI_DILIM = {
     cerceve = {{0, 150}, {210, 420}},
     kapak = {{0, 78}, {108, 316}, {346, 420}},
}

local aniDuzen
local function AniDuzen()
     local sw, sh = ScrW(), ScrH()
     if aniDuzen and aniDuzen.sw == sw and aniDuzen.sh == sh then return aniDuzen end
     local o = math.min(ANI_OLCEK * math.Clamp(sh / 1080, 0.8, 2), sw * 0.6 / 1600)
     local w = 1600 * o
     aniDuzen = {sw = sw, sh = sh, w = w, h = ANI_YUK * o, o = o, x = (sw - w) / 2, y = math.floor(sh * 0.1), orta = sw / 2,
          kapaliW = 320 * o, kapakW = 160 * o}
     -- Türkçe harfleri tam olan workshop fontları (Trebuchet MS oyunda "ı" çizmedi)
     surface.CreateFont("sk.aniBaslik", {font = "Playfair Display", size = math.max(18, math.floor(48 * o + 0.5)), weight = 400, antialias = true, extended = true})
     surface.CreateFont("sk.aniYazi", {font = "Montserrat Medium", size = math.max(12, math.floor(30 * o + 0.5)), weight = 500, antialias = true, extended = true})
     return aniDuzen
end

-- dokuyu dikey dilimlerle çizer (atlanan satırlar düz bölgede, ek yeri görünmez)
local function AniDoku(m, dilim, x, y, w, o, a)
     surface.SetMaterial(m)
     surface.SetDrawColor(255, 255, 255, a)
     local bas, top = math.Round(y), 0
     for _, d in ipairs(dilim) do
          top = top + d[2] - d[1]
          local son = math.Round(y + top * o)
          surface.DrawTexturedRectUV(x, bas, w, son - bas, 0, d[1] / 420, 1, d[2] / 420)
          bas = son
     end
end

-- doku inmediyse düz çizim (pencere boş kalır, sahne altında görünür)
local function AniYedekCerceve(x, y, w, h, px, py, pw, ph, a)
     draw.NoTexture()
     surface.SetDrawColor(aniYesil.r, aniYesil.g, aniYesil.b, a)
     surface.DrawRect(x, y, w, py - y)
     surface.DrawRect(x, py + ph, w, y + h - py - ph)
     if px > x then surface.DrawRect(x, py, px - x, ph) end
     if px + pw < x + w then surface.DrawRect(px + pw, py, x + w - px - pw, ph) end
     surface.SetDrawColor(aniAltin.r, aniAltin.g, aniAltin.b, a)
     surface.DrawOutlinedRect(x, y, w, h, 1)
end

local function AniYedekKapak(x, y, w, h, a, sag)
     draw.NoTexture()
     surface.SetDrawColor(aniYesilK.r, aniYesilK.g, aniYesilK.b, a)
     surface.DrawRect(x, y, w, h)
     surface.SetDrawColor(aniAltin.r, aniAltin.g, aniAltin.b, a)
     surface.DrawOutlinedRect(x, y, w, h, 1)
     surface.DrawRect(sag and x or (x + w - 1), y, 1, h)
end

hook.Add("HUDPaint", "SardonKitap.Ani", function()
     local k = ANI.aktif
     if not k or k.gecen <= 0 or not AniCizilir() then return end
     local D = AniDuzen()
     local ilerleme, opak = AniEvre(k.gecen)
     local a = math.floor(opak * 255)
     if a < 1 then return end
     local o = D.o
     local w = D.kapaliW + (D.w - D.kapaliW) * ilerleme
     local x, y = D.orta - w / 2, D.y
     local gx, gy, gw, gh = D.x + D.kapakW, y + 56 * o, D.w - 2 * D.kapakW, (282 - 420 + ANI_YUK) * o
     local acL, acR = x + D.kapakW, x + w - D.kapakW

     if acR > acL then
          render.SetScissorRect(math.floor(acL), math.floor(gy), math.ceil(acR), math.ceil(gy + gh), true)
          local m = AniMat(k.gorsel)
          if m then
               -- 3:1 sahne pencereye esnemeden, ortadan kırpılarak oturur
               local oran = gw / gh
               local u0, v0, u1, v1 = 0, 0, 1, 1
               if oran > 3 then
                    local f = 3 / oran
                    v0, v1 = (1 - f) / 2, (1 + f) / 2
               else
                    local f = oran / 3
                    u0, u1 = (1 - f) / 2, (1 + f) / 2
               end
               surface.SetMaterial(m)
               surface.SetDrawColor(255, 255, 255, a)
               surface.DrawTexturedRectUV(gx, gy, gw, gh, u0, v0, u1, v1)
          else
               draw.NoTexture()
               surface.SetDrawColor(aniYesilK.r, aniYesilK.g, aniYesilK.b, a)
               surface.DrawRect(gx, gy, gw, gh)
          end
          render.SetScissorRect(0, 0, 0, 0, false)
     end

     local cerceve, sol, sag = AniMat(ANI_UI[1]), AniMat(ANI_UI[2]), AniMat(ANI_UI[3])
     if cerceve then AniDoku(cerceve, ANI_DILIM.cerceve, x, y, w, o, a) else AniYedekCerceve(x, y, w, D.h, acL, gy, math.max(0, acR - acL), gh, a) end

     local ya = math.floor(a * Yumusak((ilerleme - 0.55) / 0.45))
     if ya > 0 then
          aniFildisi.a, aniAltin.a = ya, ya
          draw.SimpleText("Anı Defteri", "sk.aniYazi", D.orta, y + 26 * o, aniAltin, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
          draw.SimpleText(k.ad, "sk.aniBaslik", D.orta, y + 300 * o, aniFildisi, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
          draw.SimpleText("Anı defterine kaydedildi", "sk.aniYazi", D.orta, y + 342 * o, aniAltin, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
          aniFildisi.a, aniAltin.a = 255, 255
     end

     if sol then AniDoku(sol, ANI_DILIM.kapak, x, y, D.kapakW, o, a) else AniYedekKapak(x, y, D.kapakW, D.h, a, false) end
     if sag then AniDoku(sag, ANI_DILIM.kapak, x + w - D.kapakW, y, D.kapakW, o, a) else AniYedekKapak(x + w - D.kapakW, y, D.kapakW, D.h, a, true) end
end)

concommand.Add("sardon_kitap_ani", function(_, _, args)
     if not IsValid(LocalPlayer()) or not LocalPlayer():IsAdmin() then return end
     local id = args[1] or "hogwarts"
     if id == "hepsi" then
          for _, y in ipairs(SK.YERLER or {}) do SK.AniKart(y.id, true) end
          return
     end
     if not SK.AniKart(id, true) then
          local ids = {}
          for _, y in ipairs(SK.YERLER or {}) do ids[#ids + 1] = y.id end
          print("[Sardon Kitap] bilinmeyen ya da sırada olan yer: " .. id .. "\n" .. table.concat(ids, " "))
     end
end)

concommand.Add("sardon_kitap_ani_temizle", function()
     ANI.kuyruk, ANI.aktif = {}, nil
end)

hook.Add("InitPostEntity", "SardonKitap.Ani", AniListeIste)
if IsValid(LocalPlayer()) then AniListeIste() end
