-- "addons\\sardoncigirtkan\\lua\\sardon_cigirtkan\\cl_1tema.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Çığırtkan :: istemci ortak parçaları — renkler, yazılar, zarf çizimi (2B arayüz + 3B dünya).
--
-- GÖRSEL DİL: Düşünseli / Karakter Gelişimi (Celestial) ile aynı çerçeve (kömür yeşili zemin, pirinç
-- çizgiler, fildişi başlık); vurgu rengi zarfın kendisi: koyu kızıl kâğıt, mühür mumu.
-- Workshop'ta zarf modeli yok; 3B zarf her karede birkaç düzine üçgenle çizilir. Böylece ağzın
-- (kapak = üst dudak, gövde = alt dudak) sesin seviyesine göre açılıp kapanması tamamen bizde.
-- 11-13 opt (kodmod): kare başı kurulan sabitler dosya yereline alındı
local OPT_V_0_0p8_0 = Vector(0, 0.8, 0)
local C = SardonCigirtkan

C.Renk = {
     zemin = Color(11, 19, 17),
     zeminKoyu = Color(7, 11, 9),
     altin = Color(190, 162, 104),
     altinAcik = Color(223, 193, 128),
     ust = Color(187, 166, 121),
     fildisi = Color(232, 219, 182),
     govde = Color(190, 194, 176),
     soluk = Color(146, 151, 129),
     cizgi = Color(125, 104, 69, 85),
     cizgiGuclu = Color(156, 129, 68, 150),
     kizil = Color(150, 22, 28),
     kizilAcik = Color(214, 64, 52),
     kizilKoyu = Color(84, 12, 16),
     kagit = Color(158, 24, 30),
     kagitAcik = Color(178, 34, 38),
     kagitIc = Color(122, 18, 24),
     agiz = Color(30, 6, 8),               -- ağzın en derini (yanaklar)
     agizIc = Color(96, 14, 18),           -- damak / ağız tabanı
     dudak = Color(206, 56, 54),
     dil = Color(196, 72, 82),
     muhur = Color(98, 10, 14),
     muhurKenar = Color(176, 132, 60),
}
local R = C.Renk

function C.O(x) return math.Round(x * ScrH() / 1080) end

local fontlar = {}
function C.Font(boy, kalin)
     local px = math.max(10, math.Round(boy * ScrH() / 1080))
     local ad = "SardonCigirtkan." .. px .. (kalin and "k" or "n")
     if not fontlar[ad] then
          surface.CreateFont(ad, {
               font = kalin and "Montserrat SemiBold" or "Montserrat Medium",
               size = px, weight = kalin and 600 or 500, extended = true, antialias = true
          })
          fontlar[ad] = true
     end
     return ad
end
hook.Add("OnScreenSizeChanged", "SardonCigirtkan.Font", function() fontlar = {} end)

-- Dünyadaki (3D2D) yazılar sabit boydadır
surface.CreateFont("SardonCigirtkan.Etiket", {font = "Montserrat SemiBold", size = 40, weight = 600, extended = true, antialias = true})
surface.CreateFont("SardonCigirtkan.EtiketAlt", {font = "Montserrat Medium", size = 28, weight = 500, extended = true, antialias = true})

-- C.Buyuk (Türkçe büyük harf) _sh_config'te: sunucu da daktilo belgesini kurarken kullanır

-- Harf aralıklı yazı (büyük harf etiketler). hiza: 0 sol, 1 orta, 2 sağ
function C.Aralikli(metin, font, x, y, renk, aralik, hiza)
     surface.SetFont(font)
     local harfler = {}
     local w = 0
     for _, kod in utf8.codes(metin) do
          local c = utf8.char(kod)
          local cw = surface.GetTextSize(c)
          harfler[#harfler + 1] = {c, cw}
          w = w + cw + aralik
     end
     w = w - aralik
     if hiza == 1 then x = x - w / 2 elseif hiza == 2 then x = x - w end
     surface.SetTextColor(renk.r, renk.g, renk.b, renk.a or 255)
     for _, h in ipairs(harfler) do
          surface.SetTextPos(math.Round(x), math.Round(y))
          surface.DrawText(h[1])
          x = x + h[2] + aralik
     end
     return w
end

-- Baklava süs (◆)
function C.Baklava(x, y, r, renk)
     draw.NoTexture()
     surface.SetDrawColor(renk.r, renk.g, renk.b, renk.a or 255)
     surface.DrawPoly({{x = x, y = y - r}, {x = x + r, y = y}, {x = x, y = y + r}, {x = x - r, y = y}})
end

----------------------------------------------------------------------------------------
-- 2B zarf (arayüz, envanter simgesi, mağaza)
----------------------------------------------------------------------------------------
local function Daire(x, y, r, n)
     local t = {}
     for i = 0, n - 1 do
          local a = i / n * math.pi * 2
          t[#t + 1] = {x = x + math.cos(a) * r, y = y + math.sin(a) * r}
     end
     return t
end

-- agiz: 0 kapalı .. 1 ağzı sonuna kadar açık (kapak yukarı kalkar, içi görünür). titreme: 0..1
function C.ZarfCiz2D(x, y, w, h, agiz, titreme)
     agiz = math.Clamp((agiz or 0) * 1.6, 0, 1)
     if titreme and titreme > 0 then
          x = x + math.Rand(-1, 1) * titreme * 2
          y = y + math.Rand(-1, 1) * titreme * 2
     end
     draw.NoTexture()

     -- gövde
     surface.SetDrawColor(R.kagit.r, R.kagit.g, R.kagit.b, 255)
     surface.DrawRect(x, y, w, h)
     surface.SetDrawColor(R.kizilKoyu.r, R.kizilKoyu.g, R.kizilKoyu.b, 255)
     surface.DrawOutlinedRect(x, y, w, h, math.max(1, math.Round(w / 80)))
     -- alt köşelerden ortaya kıvrım çizgileri
     surface.SetDrawColor(R.kagitIc.r, R.kagitIc.g, R.kagitIc.b, 255)
     surface.DrawLine(x, y + h, x + w / 2, y + h * 0.48)
     surface.DrawLine(x + w, y + h, x + w / 2, y + h * 0.48)

     -- ağzın içi (kapak kalktıkça görünür)
     if agiz > 0.02 then
          local derin = y + h * (0.12 + 0.5 * agiz)
          surface.SetDrawColor(R.agiz.r, R.agiz.g, R.agiz.b, 255)
          surface.DrawPoly({{x = x + 1, y = y + 1}, {x = x + w - 1, y = y + 1}, {x = x + w / 2, y = derin}})
          if agiz > 0.3 then
               local dw, dh = w * 0.18 * agiz, h * 0.08 * agiz
               surface.SetDrawColor(R.dil.r, R.dil.g, R.dil.b, 255)
               surface.DrawPoly(Daire(x + w / 2, derin - dh * 1.2, dw, 12))
          end
     end

     -- kapak: tabanı üst kenar, ucu açıldıkça aşağıdan yukarı döner
     local uc = y + h * 0.56 * math.cos(agiz * math.pi * 0.92)
     local ters = uc < y
     local k = ters and R.kagitIc or R.kagitAcik
     surface.SetDrawColor(k.r, k.g, k.b, 255)
     if ters then
          surface.DrawPoly({{x = x, y = y}, {x = x + w / 2, y = uc}, {x = x + w, y = y}})
     else
          surface.DrawPoly({{x = x + w, y = y}, {x = x + w / 2, y = uc}, {x = x, y = y}})
     end

     -- mühür (kapak kapalıyken ucunda)
     if not ters and agiz < 0.5 then
          local mx, my, mr = x + w / 2, uc - h * 0.04, math.min(w, h) * 0.11
          surface.SetDrawColor(R.muhurKenar.r, R.muhurKenar.g, R.muhurKenar.b, 255)
          surface.DrawPoly(Daire(mx, my, mr * 1.18, 16))
          surface.SetDrawColor(R.muhur.r, R.muhur.g, R.muhur.b, 255)
          surface.DrawPoly(Daire(mx, my, mr, 16))
     end
end

----------------------------------------------------------------------------------------
-- 3B zarf
----------------------------------------------------------------------------------------
-- Yerel eksenler: x ileri (ağzın baktığı yön), y sol, z yukarı. Menteşe (kıvrım) y ekseni boyunca
-- x = 0'da. Alt çene = zarfın gövdesi, üst çene = beşgen kapak; aci (yarım açı, radyan) kadar
-- birbirinden ayrılırlar. Kapalı zarfı karşıdan göstermek için pitch 90 verilir (kapak öne bakar).
-- Her yüz iki katmandır (dış kâğıt / iç), $nocull ile iki yandan da görünür, z-dövüşü olmasın
-- diye katmanlar normal boyunca az ayrık durur.
C.ZarfW, C.ZarfL = 15, 9
local W2, L = C.ZarfW / 2, C.ZarfL
local OMUZ = 0.55              -- kapağın dik kenarlarının bittiği yer (L oranı)
local KAT = 0.06               -- katman aralığı
local UST_KAYMA = 0.25         -- kapalıyken kapak gövdenin üstünde dursun

C.MatKagit = CreateMaterial("SardonCigirtkanKagit1", "UnlitGeneric", {
     ["$basetexture"] = "color/white", ["$vertexcolor"] = 1, ["$nocull"] = 1,
})
C.MatSaydam = CreateMaterial("SardonCigirtkanSaydam1", "UnlitGeneric", {
     ["$basetexture"] = "color/white", ["$vertexcolor"] = 1, ["$vertexalpha"] = 1, ["$nocull"] = 1, ["$translucent"] = 1,
})

local GUNES = Vector(0.35, 0.25, 0.9):GetNormalized()
local tris, tn = {}, 0

local function Uc(a, b, c, renk, golge)
     tn = tn + 1
     local t = tris[tn]
     if not t then t = {} tris[tn] = t end
     t[1], t[2], t[3], t[4], t[5] = a, b, c, renk, golge
end

local function Dortgen(a, b, c, d, renk, golge)
     Uc(a, b, c, renk, golge)
     Uc(a, c, d, renk, golge)
end

local function Lerp3(t, a, b)
     return Color(Lerp(t, a.r, b.r), Lerp(t, a.g, b.g), Lerp(t, a.b, b.b), Lerp(t, a.a or 255, b.a or 255))
end

-- Yerel nokta -> dünya (parçacıklar için). olcek: ölçek
function C.YerelDunya(pos, ang, olcek, v)
     return pos + ang:Forward() * (v.x * olcek) - ang:Right() * (v.y * olcek) + ang:Up() * (v.z * olcek)
end

-- Ağzın ortası (yerel), aci verilince: parıltı / kıvılcım çıkış noktası
function C.AgizMerkez(aci)
     return Vector(L * 0.55 * math.cos(aci), 0, UST_KAYMA * 0.5)
end

-- ops: {dil = 0..1 dilin kalkması, alfa = 0..255, renk = Color (kâğıdı boyar), kapakKapali = true}
function C.ZarfCiz3D(pos, ang, olcek, aci, ops)
     ops = ops or {}
     tn = 0
     local ca, sa = math.cos(aci), math.sin(aci)
     local acik = math.Clamp(aci / 0.22, 0, 1)

     local kagit = ops.renk or R.kagit
     local kagitAcik = ops.renk and Lerp3(0.25, ops.renk, color_white) or R.kagitAcik
     local ic = Lerp3(acik, ops.renk or R.kagitIc, R.agizIc)        -- kapalıyken içi kâğıt, açıldıkça ağız

     -- alt çene: yerel (x, y) -> (x ca, y, -x sa). İç normal (sa, 0, ca)
     local nAltIc = Vector(sa, 0, ca)
     local function Alt(x, y, kat) return Vector(x * ca, y, -x * sa) + nAltIc * kat end
     Dortgen(Alt(0, -W2, KAT), Alt(L, -W2, KAT), Alt(L, W2, KAT), Alt(0, W2, KAT), ic, nAltIc)
     Dortgen(Alt(0, -W2, -KAT), Alt(L, -W2, -KAT), Alt(L, W2, -KAT), Alt(0, W2, -KAT), kagit, -nAltIc)

     -- üst çene (kapak): (x, y) -> (x ca, y, x sa + kayma). Dış normal (-sa, 0, ca)
     local nUstDis = Vector(-sa, 0, ca)
     local kay = Vector(0, 0, UST_KAYMA)
     local function Ust(x, y, kat) return Vector(x * ca, y, x * sa) + kay + nUstDis * kat end
     for _, k in ipairs({{KAT, kagitAcik, nUstDis}, {-KAT, ic, -nUstDis}}) do
          local kk = k[1]
          local p1, p2, p3, p4, p5 = Ust(0, -W2, kk), Ust(L * OMUZ, -W2, kk), Ust(L, 0, kk), Ust(L * OMUZ, W2, kk), Ust(0, W2, kk)
          Uc(p1, p2, p3, k[2], k[3])
          Uc(p1, p3, p5, k[2], k[3])
          Uc(p5, p3, p4, k[2], k[3])
     end

     -- mühür: kapağın dış yüzünde, ucuna yakın
     if not ops.muhursuz then
          local m0 = Ust(L * 0.68, 0, KAT * 2.5)
          local e1, e2 = Vector(ca, 0, sa), Vector(0, 1, 0)
          local n = 12
          for i = 0, n - 1 do
               local a1, a2 = i / n * math.pi * 2, (i + 1) / n * math.pi * 2
               Uc(m0, m0 + (e1 * math.cos(a1) + e2 * math.sin(a1)) * 1.9, m0 + (e1 * math.cos(a2) + e2 * math.sin(a2)) * 1.9, R.muhurKenar, nUstDis)
          end
          local m1 = m0 + nUstDis * KAT
          for i = 0, n - 1 do
               local a1, a2 = i / n * math.pi * 2, (i + 1) / n * math.pi * 2
               Uc(m1, m1 + (e1 * math.cos(a1) + e2 * math.sin(a1)) * 1.45, m1 + (e1 * math.cos(a2) + e2 * math.sin(a2)) * 1.45, ops.muhurRenk or R.muhur, nUstDis)
          end
     end

     if acik > 0.3 then
          -- dudaklar: alt çenenin ucu, kapağın iki eğik kenarı (içte, açık kızıl şerit)
          local d0 = 0.75
          Dortgen(Alt(L - d0, -W2, KAT * 1.6), Alt(L, -W2, KAT * 1.6), Alt(L, W2, KAT * 1.6), Alt(L - d0, W2, KAT * 1.6), R.dudak, nAltIc)
          for _, y in ipairs({-W2, W2}) do
               local i = y > 0 and -1 or 1
               Dortgen(Ust(L * OMUZ, y, -KAT * 1.6), Ust(L, 0, -KAT * 1.6), Ust(L - d0, 0, -KAT * 1.6), Ust(L * OMUZ - d0 * 0.6, y + i * d0, -KAT * 1.6), R.dudak, -nUstDis)
          end
          -- yanaklar: menteşe köşesi, alt dudak köşesi, kapak omzu
          for _, y in ipairs({-W2, W2}) do
               Uc(Vector(0, y, 0), Alt(L, y, 0), Ust(L * OMUZ, y, 0), R.agiz, Vector(0, y > 0 and 1 or -1, 0))
          end
          -- dil: alt çenenin içinde, ucu sesle kalkar
          local d = math.Clamp(ops.dil or 0, 0, 1)
          local dk = Vector(sa, 0, ca) * 0.18
          local b0, b1 = Alt(1.4, -3.1, 0) + dk, Alt(1.4, 3.1, 0) + dk
          local o0, o1 = Alt(L * 0.5, -3.4, 0) + dk, Alt(L * 0.5, 3.4, 0) + dk
          Dortgen(b0, o0, o1, b1, R.dil, nAltIc)
          local kalk = -aci + d * 0.9 - 0.15
          local u = Vector(math.cos(kalk), 0, math.sin(kalk)) * (L * 0.3)
          Dortgen(o0, o0 + u + OPT_V_0_0p8_0, o1 + u - OPT_V_0_0p8_0, o1, R.dil, nAltIc)
     end

     -- çizim
     local amb = render.GetLightColor(pos)
     local parlak = math.Clamp((amb.x + amb.y + amb.z) / 3 * 1.8, 0.32, 1.15)
     local F, Lv, U = ang:Forward(), -ang:Right(), ang:Up()
     local alfa = ops.alfa or 255

     local m = Matrix()
     m:SetTranslation(pos)
     m:SetAngles(ang)
     m:Scale(Vector(olcek, olcek, olcek))

     render.SetMaterial(alfa < 255 and C.MatSaydam or C.MatKagit)
     cam.PushModelMatrix(m)
     mesh.Begin(MATERIAL_TRIANGLES, tn)
     for i = 1, tn do
          local t = tris[i]
          local n = t[5]
          local wn = F * n.x + Lv * n.y + U * n.z
          local g = parlak * (0.62 + 0.38 * math.max(0, wn:Dot(GUNES)))
          local r, gg, b = math.min(255, t[4].r * g), math.min(255, t[4].g * g), math.min(255, t[4].b * g)
          for j = 1, 3 do
               mesh.Position(t[j])
               mesh.Color(r, gg, b, alfa)
               mesh.TexCoord(0, 0, 0)
               mesh.AdvanceVertex()
          end
     end
     mesh.End()
     cam.PopModelMatrix()
end

-- Zarfın köşeleri (yerel, kapalıyken): duman çıkışı için
C.Koseler = {Vector(0, -W2, 0), Vector(0, W2, 0), Vector(L, -W2, 0), Vector(L, W2, 0)}
