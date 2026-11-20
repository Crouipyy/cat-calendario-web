-- "addons\\sardongacha\\lua\\sardon_gacha\\cl_1tema.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
/*
*   İstemci teması: SHINE Celestial renkleri (Karakter Gelişimi ekranıyla aynı dil), yazı tipleri,
*   gömülü dokular (cl_0doku), URL'den görsel, 2B toplamalı parıltı, asa modeli çizimi.
*/
-- 11-13 opt (kodmod): kare başı kurulan sabitler dosya yereline alındı
local OPT_V_0_1_0 = Vector(0, 1, 0)
local SG = SardonGacha

SG.R = {
     zemin = Color(7, 12, 10),
     zemin2 = Color(12, 19, 16),
     panel = Color(10, 16, 14, 242),
     panelAcik = Color(18, 27, 23, 250),
     altin = Color(190, 162, 104),
     altinAcik = Color(226, 197, 136),
     altinKoyu = Color(140, 116, 70),
     fildisi = Color(232, 219, 182),
     fildisiAcik = Color(246, 234, 200),
     govde = Color(196, 198, 182),
     soluk = Color(150, 156, 134),
     sonuk = Color(104, 112, 100),
     cizgi = Color(190, 162, 104, 52),
     cizgiSoluk = Color(190, 162, 104, 26),
     hata = Color(222, 128, 112),
     iyi = Color(150, 206, 156),
     krem = Color(240, 230, 204),
     kremKoyu = Color(84, 70, 48),
     siyah = Color(0, 0, 0),
}

/*
*   Yazı tipleri. tur: govde (Montserrat Medium) · orta (SemiBold) · kalin (Bold) · baslik (Cinzel, yoksa SemiBold)
*/
local cinzel
local function CinzelVar()
     if cinzel ~= nil then return cinzel end
     surface.CreateFont("SardonGacha_SinaA", { font = "Cinzel", size = 40, extended = true })
     surface.CreateFont("SardonGacha_SinaB", { font = "SardonGachaYokBoyleFont", size = 40, extended = true })
     surface.SetFont("SardonGacha_SinaA")
     local a = surface.GetTextSize("MMMMMMMMMM0123456789")
     surface.SetFont("SardonGacha_SinaB")
     local b = surface.GetTextSize("MMMMMMMMMM0123456789")
     cinzel = a ~= b
     return cinzel
end

local AILE = { govde = { "Montserrat Medium", 500 }, orta = { "Montserrat SemiBold", 600 }, kalin = { "Montserrat Bold", 700 } }
local fontlar = {}

function SG.F(px, tur)
     px = math.max(9, math.Round(px))
     tur = tur or "govde"
     local ad = "SardonGacha_" .. tur .. "_" .. px
     if not fontlar[ad] then
          local aile = AILE[tur]
          if tur == "baslik" then
               aile = CinzelVar() and { "Cinzel", 600 } or AILE.orta
          end
          aile = aile or AILE.govde
          surface.CreateFont(ad, { font = aile[1], size = px, weight = aile[2], antialias = true, extended = true })
          fontlar[ad] = true
     end
     return ad
end

function SG.Yazi(metin, font, x, y, renk, ax, ay, alfa)
     local c = renk or SG.R.fildisi
     return draw.SimpleText(metin, font, x, y, alfa and Color(c.r, c.g, c.b, c.a * alfa) or c, ax or TEXT_ALIGN_LEFT, ay or TEXT_ALIGN_TOP)
end

function SG.Genislik(metin, font)
     surface.SetFont(font)
     return (surface.GetTextSize(metin))
end

-- Sözcük kaydırma (UTF-8 güvenli; çok uzun sözcük satıra tek başına kalır)
function SG.Sar(metin, font, w)
     surface.SetFont(font)
     local satirlar = {}
     for paragraf in (tostring(metin or "") .. "\n"):gmatch("(.-)\n") do
          local satir = ""
          for soz in paragraf:gmatch("%S+") do
               local dene = satir == "" and soz or (satir .. " " .. soz)
               if surface.GetTextSize(dene) > w and satir ~= "" then
                    satirlar[#satirlar + 1] = satir
                    satir = soz
               else
                    satir = dene
               end
          end
          satirlar[#satirlar + 1] = satir
     end
     while #satirlar > 0 and satirlar[#satirlar] == "" do satirlar[#satirlar] = nil end
     return satirlar
end

local BUYUK = { ["i"] = "İ", ["ı"] = "I", ["ç"] = "Ç", ["ş"] = "Ş", ["ğ"] = "Ğ", ["ü"] = "Ü", ["ö"] = "Ö" }
function SG.Buyuk(s)
     s = tostring(s or ""):gsub("[%z\1-\127\194-\244][\128-\191]*", function(c) return BUYUK[c] or c end)
     return s:upper()
end

function SG.Kolay(t) t = math.Clamp(t, 0, 1) return 1 - (1 - t) ^ 3 end
function SG.Yumusak(t) t = math.Clamp(t, 0, 1) return t * t * (3 - 2 * t) end

/*
*   Gömülü dokular (cl_0doku_NN.lua → data/sardon_gacha/)
*/
local dokular = {}
function SG.Doku(ad)
     local m = dokular[ad]
     if m ~= nil then return m or nil end
     m = false
     local veri = SG.DokuVeri and SG.DokuVeri[ad]
     if veri then
          local yol = "sardon_gacha/" .. ad .. "_" .. (SG.DokuSurum[ad] or "0") .. ".png"
          if not file.Exists(yol, "DATA") then
               file.CreateDir("sardon_gacha")
               local ikili = util.Base64Decode(veri)
               if ikili then file.Write(yol, ikili) end
          end
          local mat = Material("../data/" .. yol, "smooth mips")
          if not mat:IsError() then m = mat end
     end
     dokular[ad] = m
     return m or nil
end

function SG.Ikon(ad, x, y, boy, alfa, renk)
     local m = SG.Doku(ad)
     if not m then return false end
     surface.SetMaterial(m)
     local c = renk or color_white
     surface.SetDrawColor(c.r, c.g, c.b, 255 * (alfa or 1))
     surface.DrawTexturedRect(x, y, boy, boy)
     return true
end

-- Nadirlik yıldızları; hiza 0 sol, 1 orta, 2 sağ. adim: kaçıncı yıldıza kadar göründüğü (animasyon)
function SG.Yildizlar(x, y, adet, boy, renk, alfa, hiza, gorunen)
     local ara = boy * 1.02
     local w = adet * ara
     local bx = hiza == 1 and x - w / 2 or hiza == 2 and x - w or x
     local m = SG.Doku("yildiz")
     for i = 1, adet do
          local g = gorunen and math.Clamp(gorunen - (i - 1), 0, 1) or 1
          if g > 0 then
               local b = boy * (0.6 + 0.4 * SG.Kolay(g)) * (g < 1 and (1 + 0.5 * math.sin(g * math.pi)) or 1)
               local cx, cy = bx + (i - 1) * ara + boy / 2, y + boy / 2
               if m then
                    surface.SetMaterial(m)
                    surface.SetDrawColor(renk.r, renk.g, renk.b, 255 * (alfa or 1) * math.min(1, g * 2))
                    surface.DrawTexturedRect(cx - b / 2, cy - b / 2, b, b)
               else
                    draw.SimpleText("★", SG.F(boy), cx, cy, ColorAlpha(renk, 255 * (alfa or 1)), 1, 1)
               end
          end
     end
     return w
end

/*
*   2B toplamalı parıltı: sprites/* surface ile çizilmiyor; siyah zeminde radyal gri bir RT dokusu
*   bir kez çizilir ve BLEND_ONE/ONE ile toplanır (Ollivander kartıyla aynı yöntem).
*/
local parMat
local function ParlakDokuCiz()
     local rt = GetRenderTargetEx("sardon_gacha_parilti", 128, 128, RT_SIZE_LITERAL, MATERIAL_RT_DEPTH_NONE, 4 + 8 + 256, 0, IMAGE_FORMAT_RGB888)
     render.PushRenderTarget(rt)
     render.Clear(0, 0, 0, 255, true, true)
     cam.Start2D()
     draw.NoTexture()
     for py = 0, 127 do
          for px = 0, 127 do
               local d = math.sqrt((px - 63.5) ^ 2 + (py - 63.5) ^ 2) / 64
               if d < 1 then
                    local v = 0.7 * (1 - d * d) ^ 3 + 0.3 * (1 - d) ^ 8
                    local c = math.floor(v * 255 + 0.5)
                    if c > 0 then
                         surface.SetDrawColor(c, c, c, 255)
                         surface.DrawRect(px, py, 1, 1)
                    end
               end
          end
     end
     cam.End2D()
     render.PopRenderTarget()
     parMat = parMat or CreateMaterial("sardon_gacha_parilti_m", "UnlitGeneric", { ["$basetexture"] = rt:GetName(), ["$vertexcolor"] = 1, ["$vertexalpha"] = 1 })
     parMat:SetTexture("$basetexture", rt)
end
local parHazir = false
hook.Add("PreRender", "SardonGacha.Parilti", function()
     if parHazir then return end
     parHazir = true
     ParlakDokuCiz()
end)
hook.Add("OnScreenSizeChanged", "SardonGacha.Parilti", function() parHazir = false end)

function SG.Parilti(x, y, w, h, renk, alfa)
     if not parMat then return end
     h = h or w
     local k = math.Clamp((alfa or 255) / 255, 0, 1) * (SG.ParAlfa or 1)
     if k <= 0 then return end
     render.OverrideBlend(true, BLEND_ONE, BLEND_ONE, BLENDFUNC_ADD)
     surface.SetMaterial(parMat)
     surface.SetDrawColor(renk.r * k, renk.g * k, renk.b * k, 255)
     surface.DrawTexturedRect(x - w / 2, y - h / 2, w, h)
     render.OverrideBlend(false)
end

-- Dönük parıltı (meteor kuyruğu, ışın)
function SG.PariltiDonuk(x, y, w, h, aci, renk, alfa)
     if not parMat then return end
     local k = math.Clamp((alfa or 255) / 255, 0, 1) * (SG.ParAlfa or 1)
     if k <= 0 then return end
     render.OverrideBlend(true, BLEND_ONE, BLEND_ONE, BLENDFUNC_ADD)
     surface.SetMaterial(parMat)
     surface.SetDrawColor(renk.r * k, renk.g * k, renk.b * k, 255)
     surface.DrawTexturedRectRotated(x, y, w, h, aci)
     render.OverrideBlend(false)
end

-- Dört köşeli kıvılcım (iki ince dönük parıltı)
function SG.Kivilcim(x, y, boy, renk, alfa, aci)
     aci = aci or 0
     SG.PariltiDonuk(x, y, boy, boy * 0.12, aci, renk, alfa)
     SG.PariltiDonuk(x, y, boy, boy * 0.12, aci + 90, renk, alfa)
     SG.Parilti(x, y, boy * 0.35, nil, renk, (alfa or 255) * 0.8)
end

/*
*   Yıldız alanı (sabit tohumlu; her çizimde aynı)
*/
local yildizAlani = {}
do
     local tohum = 1337
     local function R()
          tohum = (tohum * 1103515245 + 12345) % 2147483648
          return tohum / 2147483648
     end
     for i = 1, 220 do
          yildizAlani[i] = { x = R(), y = R(), b = 0.4 + R() * 1.6, f = R() * 6.28, h = 0.4 + R() * 1.4, a = 0.25 + R() * 0.75 }
     end
end

function SG.Yildizli(x, y, w, h, alfa, olcek)
     alfa = alfa or 1
     olcek = olcek or 1
     local t = RealTime()
     draw.NoTexture()
     for _, s in ipairs(yildizAlani) do
          local a = s.a * (0.55 + 0.45 * math.sin(t * s.h + s.f)) * alfa
          local b = math.max(1, s.b * olcek)
          surface.SetDrawColor(236, 226, 196, 255 * a)
          surface.DrawRect(x + s.x * w, y + s.y * h, b, b)
     end
end

-- Celestial zemin: Karakter Gelişimi'nin gömülü arka planı varsa o, yoksa koyu gradyan + yıldızlar
function SG.Zemin(x, y, w, h, alfa)
     alfa = alfa or 1
     local G = SardonGelisim
     local mat = G and G.Doku and G.Doku("background")
     surface.SetDrawColor(SG.R.zemin.r, SG.R.zemin.g, SG.R.zemin.b, 255 * alfa)
     surface.DrawRect(x, y, w, h)
     if mat then
          local iw, ih = 1672, 941
          if G.DokuOlcu then iw, ih = G.DokuOlcu("background") end
          SG.Kapla(mat, x, y, w, h, alfa, iw, ih)
     else
          SG.Parilti(x + w * 0.7, y + h * 0.2, w * 0.9, h * 0.9, Color(40, 52, 70), 120 * alfa)
          SG.Parilti(x + w * 0.2, y + h * 0.9, w * 0.8, h * 0.6, Color(52, 44, 30), 90 * alfa)
          SG.Yildizli(x, y, w, h, alfa)
     end
end

/*
*   Görseli kutuya "kaplayarak" (taşan kısım kırpılır) çiz. iw/ih verilmezse URL önbelleğinden.
*/
function SG.Kapla(mat, x, y, w, h, alfa, iw, ih, odakX, odakY)
     if not mat then return end
     local boy = SG.UrlBoyut[mat]
     iw = iw or (boy and boy[1]) or mat:Width()
     ih = ih or (boy and boy[2]) or mat:Height()
     if iw <= 0 or ih <= 0 or w <= 0 or h <= 0 then return end
     local u0, v0, u1, v1 = 0, 0, 1, 1
     local ia, ba = iw / ih, w / h
     if ia > ba then
          local f = ba / ia
          u0 = (1 - f) * (odakX or 0.5)
          u1 = u0 + f
     else
          local f = ia / ba
          v0 = (1 - f) * (odakY or 0.5)
          v1 = v0 + f
     end
     surface.SetMaterial(mat)
     surface.SetDrawColor(255, 255, 255, 255 * (alfa or 1))
     surface.DrawTexturedRectUV(x, y, w, h, u0, v0, u1, v1)
end

/*
*   URL'den görsel (afiş teması). Önce doğrudan, olmazsa DuckDuckGo vekili; data/sardon_gacha/url'e yazılır.
*/
local URLDIR = "sardon_gacha/url"
file.CreateDir(URLDIR)
SG.UrlOnbellek = SG.UrlOnbellek or {}
SG.UrlBoyut = SG.UrlBoyut or setmetatable({}, { __mode = "k" })

local function be16(s, i)
     local a, b = s:byte(i, i + 1)
     return (a or 0) * 256 + (b or 0)
end

local function Boyut(govde)
     if not govde then return end
     if govde:sub(1, 8) == "\137PNG\r\n\26\n" then
          return be16(govde, 17) * 65536 + be16(govde, 19), be16(govde, 21) * 65536 + be16(govde, 23)
     end
     if govde:sub(1, 2) == "\255\216" then
          local i, n = 3, #govde
          while i + 8 <= n do
               if govde:byte(i) ~= 0xFF then return end
               local m = govde:byte(i + 1)
               if m >= 0xC0 and m <= 0xCF and m ~= 0xC4 and m ~= 0xC8 and m ~= 0xCC then
                    return be16(govde, i + 7), be16(govde, i + 5)
               end
               i = i + 2 + be16(govde, i + 2)
          end
     end
end

local function Tur(govde)
     if govde:sub(1, 8) == "\137PNG\r\n\26\n" then return "png" end
     if govde:sub(1, 3) == "\255\216\255" then return "jpg" end
end

local function MatAc(yol)
     local mat = Material("../data/" .. yol, "smooth mips")
     if mat and not mat:IsError() then
          local w, h = Boyut(file.Read(yol, "DATA"))
          if w and h and w > 0 and h > 0 then SG.UrlBoyut[mat] = { w, h } end
          return mat
     end
end

local function UrlKodla(s)
     return (s:gsub("[^%w%-%._~]", function(c) return string.format("%%%02X", string.byte(c)) end))
end

local function Indir(kayit, url, kaynaklar, i)
     local src = kaynaklar[i]
     if not src then kayit.durum = "yok" return end
     http.Fetch(src, function(govde, _, _, kod)
          local uz = kod == 200 and #govde <= 12 * 1024 * 1024 and Tur(govde)
          if not uz then Indir(kayit, url, kaynaklar, i + 1) return end
          local yol = URLDIR .. "/" .. util.CRC(url) .. "." .. uz
          file.Write(yol, govde)
          kayit.mat = MatAc(yol)
          kayit.durum = kayit.mat and "tamam" or "yok"
     end, function() Indir(kayit, url, kaynaklar, i + 1) end)
end

-- Döner: Material ya da nil, durum ("iniyor" / "tamam" / "yok")
function SG.UrlMat(url)
     if not isstring(url) or url == "" then return nil, "yok" end
     local k = SG.UrlOnbellek[url]
     if k then return k.mat, k.durum end
     k = { durum = "iniyor" }
     SG.UrlOnbellek[url] = k
     local taban = URLDIR .. "/" .. util.CRC(url)
     for _, uz in ipairs({ "png", "jpg" }) do
          if file.Exists(taban .. "." .. uz, "DATA") then
               k.mat = MatAc(taban .. "." .. uz)
               if k.mat then k.durum = "tamam" return k.mat, "tamam" end
          end
     end
     Indir(k, url, { url, "https://proxy.duckduckgo.com/iu/?u=" .. UrlKodla(url) }, 1)
     return nil, "iniyor"
end

-- Yönetim "yeniden indir" için
function SG.UrlUnut(url)
     SG.UrlOnbellek[url] = nil
     local taban = URLDIR .. "/" .. util.CRC(url or "")
     for _, uz in ipairs({ "png", "jpg" }) do file.Delete(taban .. "." .. uz) end
end

/*
*   Asa modeli: ekran dikdörtgenine (mutlak koordinat) uzun ekseni "aci" derece eğik, kendi ekseni
*   etrafında dönerek çizilir. Modeller önbellekte (çizilmez, yalnız elle).
*/
SG.Modeller = SG.Modeller or {}

function SG.Model(yol)
     yol = yol or "models/hpwrewrite/w_magicwand.mdl"
     local e = SG.Modeller[yol]
     if IsValid(e) then
          e.sgSon = RealTime()
          return e
     end
     e = ClientsideModel(yol, RENDERGROUP_OPAQUE)
     if not IsValid(e) then return nil end
     e:SetNoDraw(true)
     e.sgMn, e.sgMx = e:GetModelBounds()
     e.sgSon = RealTime()
     SG.Modeller[yol] = e
     return e
end

-- Bir dakikadır çizilmeyen modeller silinir (asa seçici yüzlerce model açabiliyor)
timer.Create("SardonGacha.ModelTemizle", 30, 0, function()
     local simdi = RealTime()
     for yol, e in pairs(SG.Modeller) do
          if not IsValid(e) then
               SG.Modeller[yol] = nil
          elseif simdi - (e.sgSon or 0) > 60 then
               e:Remove()
               SG.Modeller[yol] = nil
          end
     end
end)

local function UzunEksen(mn, mx)
     local s = mx - mn
     if s.x >= s.y and s.x >= s.z then return 1, s.x end
     if s.y >= s.z then return 2, s.y end
     return 3, s.z
end

local function YonlendirAci(eksen, yon, ust)
     local m = Matrix()
     local X, Yv, Z
     if eksen == 1 then X = yon Z = ust Yv = Z:Cross(X)
     elseif eksen == 2 then Yv = yon Z = ust X = Yv:Cross(Z)
     else Z = yon X = ust Yv = Z:Cross(X) end
     m:SetForward(X)
     m:SetRight(-Yv)
     m:SetUp(Z)
     return m:GetAngles()
end

-- o: { aci (ekranda eğim, derece; 0 = yatay), donus (kendi ekseni derece), dolu (asa boyunun
--      kutu genişliğine oranı, 0..1), isik (Color), alfa, ters (uç sola) }
function SG.AsaCiz(yol, x, y, w, h, o)
     o = o or {}
     local ent = SG.Model(yol)
     if not IsValid(ent) or w < 4 or h < 4 then return end
     local mn, mx = ent.sgMn, ent.sgMx
     local eks, uz = UzunEksen(mn, mx)
     if uz <= 0 then return end

     local egim = math.rad(o.aci or 0)
     local yon = Vector(math.cos(egim), 0, math.sin(egim))
     if o.ters then yon = -yon end
     local dr = math.rad(o.donus or 0)
     local dik = Vector(-math.sin(egim), 0, math.cos(egim))
     local ust = dik * math.cos(dr) + OPT_V_0_1_0 * math.sin(dr)
     ent:SetAngles(YonlendirAci(eks, yon, ust))
     ent:SetPos(vector_origin)
     local merkez = ent:LocalToWorld((mn + mx) / 2)
     ent:SetPos(-merkez)

     local fov = 30
     local dolu = o.dolu or 0.9
     -- yatay fov: kutu genişliğinin "dolu" kadarını asanın ekrandaki yatay izdüşümü kaplasın;
     -- dik kutularda yükseklik de sınır olsun
     local yatay = math.max(math.abs(math.cos(egim)) * uz, 0.01)
     local dikey = math.max(math.abs(math.sin(egim)) * uz, 0.01)
     local tanX = math.tan(math.rad(fov / 2))
     local d1 = (yatay / dolu / 2) / tanX
     local d2 = (dikey / dolu / 2) / (tanX * h / w)
     local d = math.max(d1, d2)

     local isik = o.isik or SG.R.fildisi
     cam.Start3D(Vector(0, -d, 0), Angle(0, 90, 0), fov, x, y, w, h, 1, 5000)
          render.ClearDepth()
          render.SuppressEngineLighting(true)
          render.SetLightingOrigin(vector_origin)
          render.ResetModelLighting(0.5, 0.48, 0.46)
          render.SetModelLighting(BOX_TOP, 1.35, 1.3, 1.25)
          render.SetModelLighting(BOX_FRONT, 1.15, 1.1, 1.05)
          render.SetModelLighting(BOX_BACK, isik.r / 255, isik.g / 255, isik.b / 255)
          render.SetModelLighting(BOX_LEFT, isik.r / 330, isik.g / 330, isik.b / 330)
          render.SetModelLighting(BOX_RIGHT, 0.8, 0.8, 0.85)
          render.SetBlend((o.alfa or 1) * (SG.ParAlfa or 1))
          ent:DrawModel()
          render.SetBlend(1)
          render.SuppressEngineLighting(false)
     cam.End3D()
end

/*
*   Küçük çizim yardımcıları
*/
function SG.Kutu(x, y, w, h, renk, alfa)
     surface.SetDrawColor(renk.r, renk.g, renk.b, renk.a * (alfa or 1))
     surface.DrawRect(x, y, w, h)
end

function SG.Cerceve(x, y, w, h, renk, alfa, kalin)
     surface.SetDrawColor(renk.r, renk.g, renk.b, renk.a * (alfa or 1))
     surface.DrawOutlinedRect(x, y, w, h, kalin or 1)
end

-- Köşe süsleri (Celestial çerçeve)
function SG.Koseler(x, y, w, h, boy, renk, alfa)
     surface.SetDrawColor(renk.r, renk.g, renk.b, renk.a * (alfa or 1))
     surface.DrawRect(x, y, boy, 1) surface.DrawRect(x, y, 1, boy)
     surface.DrawRect(x + w - boy, y, boy, 1) surface.DrawRect(x + w - 1, y, 1, boy)
     surface.DrawRect(x, y + h - 1, boy, 1) surface.DrawRect(x, y + h - boy, 1, boy)
     surface.DrawRect(x + w - boy, y + h - 1, boy, 1) surface.DrawRect(x + w - 1, y + h - boy, 1, boy)
end

-- Baklava (dolu ya da çerçeve)
function SG.Baklava(cx, cy, r, renk, alfa, dolu)
     draw.NoTexture()
     surface.SetDrawColor(renk.r, renk.g, renk.b, renk.a * (alfa or 1))
     if dolu then
          surface.DrawPoly({ { x = cx, y = cy - r }, { x = cx + r, y = cy }, { x = cx, y = cy + r }, { x = cx - r, y = cy } })
     else
          surface.DrawLine(cx, cy - r, cx + r, cy)
          surface.DrawLine(cx + r, cy, cx, cy + r)
          surface.DrawLine(cx, cy + r, cx - r, cy)
          surface.DrawLine(cx - r, cy, cx, cy - r)
     end
end

-- Kesik çizgi
function SG.Kesik(x, y, w, renk, alfa, parca, bosluk)
     parca, bosluk = parca or 6, bosluk or 5
     surface.SetDrawColor(renk.r, renk.g, renk.b, renk.a * (alfa or 1))
     local cx = x
     while cx < x + w do
          surface.DrawRect(cx, y, math.min(parca, x + w - cx), 1)
          cx = cx + parca + bosluk
     end
end

-- Yatay gradyan dikdörtgen (soldan sağa alfa a0 → a1)
local gradR = Material("vgui/gradient-r")
local gradL = Material("vgui/gradient-l")
local gradU = Material("vgui/gradient-u")
local gradD = Material("vgui/gradient-d")
function SG.Gradyan(x, y, w, h, renk, yon, alfa)
     local m = yon == "sag" and gradR or yon == "sol" and gradL or yon == "ust" and gradU or gradD
     surface.SetMaterial(m)
     surface.SetDrawColor(renk.r, renk.g, renk.b, renk.a * (alfa or 1))
     surface.DrawTexturedRect(x, y, w, h)
end

-- Yuvarlak uçlu hap düğme zemini
function SG.Hap(x, y, w, h, zemin, cizgi, alfa)
     alfa = alfa or 1
     local r = math.floor(h / 2)
     draw.RoundedBox(r, x, y, w, h, Color(zemin.r, zemin.g, zemin.b, zemin.a * alfa))
     if cizgi then
          -- ince çerçeve: biraz büyük kutu + içi
          draw.RoundedBox(r, x, y, w, h, Color(cizgi.r, cizgi.g, cizgi.b, cizgi.a * alfa))
          draw.RoundedBox(r - 2, x + 2, y + 2, w - 4, h - 4, Color(zemin.r, zemin.g, zemin.b, zemin.a * alfa))
     end
end

-- Sesler
SG.Ses = {
     tik = "ui/buttonclick.wav",
     uzerinde = "ui/buttonrollover.wav",
     meteor = "weapons/mortar/mortar_shell_incomming1.wav",
     parlama = "ambient/energy/whiteflash.wav",
     [3] = "garrysmod/content_downloaded.wav",
     [4] = "ambient/levels/canals/windchime2.wav",
     [5] = "ambient/machines/teleport1.wav",
     yildiz = "buttons/lightswitch2.wav",
}
function SG.Cal(ad)
     local s = SG.Ses[ad] or ad
     if s then surface.PlaySound(s) end
end
