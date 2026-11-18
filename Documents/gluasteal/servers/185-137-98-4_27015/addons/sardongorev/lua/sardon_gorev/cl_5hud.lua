-- "addons\\sardongorev\\lua\\sardon_gorev\\cl_5hud.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
/*
*   HUD: görev takipçisi (sol), afiş (görev başladı / bitti / karşılaşma), kısa bildirimler,
*   ekrandaki hedef işareti (kenara yapışan), dünyada ışık sütunu ve halka, E istemleri,
*   toplanacak nesneler ve "E basılı tut" incelemeleri.
*/
local G = SardonGorev
local R, O, F = G.R, G.O, G.F

local function Gizli()
     if G.Sinematik and G.Sinematik() then return true end
     if hook.Run("SardonHUDGizle") then return true end
     local lp = LocalPlayer()
     return not IsValid(lp) or not lp:Alive() or (lp.GetCharacter and not lp:GetCharacter())
end

-- 11-13 opt: "N m" yazısı tam sayı başına önbellekte (her karede birleştirme yok); 300 kayıtta boşalır,
-- 0 ve NaN önbelleğe girmez (±0 aynı anahtar, NaN anahtar olamaz)
local metreYazi, metreSayi = {}, 0
local function Metre(birim)
     local m = math.max(0, math.Round(birim * 0.01905))
     local s = metreYazi[m]
     if s then return s end
     s = m .. " m"
     if m == m and m ~= 0 then
          if metreSayi >= 300 then metreYazi, metreSayi = {}, 0 end
          metreYazi[m] = s
          metreSayi = metreSayi + 1
     end
     return s
end

-- 11-13 opt: Color() ile aynı alan değerleri (math.min(tonumber(x), 255)); yeni tablo yerine verilen ara rengi doldurur
local function RenkDoldur(c, r, g, b, a)
     c.r = math.min(tonumber(r), 255)
     c.g = math.min(tonumber(g), 255)
     c.b = math.min(tonumber(b), 255)
     c.a = math.min(tonumber(a or 255), 255)
     return c
end

-- İşaretin dünyadaki noktası
function G.IsaretNoktasi(is)
     if not is then return end
     if is.aktor then
          local c = G.Aktorler[is.aktor]
          if c and c.cizPos then return c.cizPos + Vector(0, 0, c.gozZ and c.gozZ + 24 or 84), true end
     end
     if isvector(is.pos) then return is.pos end
end

local function TakipHedefi(g)
     if not g then return end
     for _, h in ipairs(g.hedefler or {}) do
          if not h.tamam and h.isaret then return h end
     end
end

/*
*   Takipçi
*/
local takipAlfa = 0
-- 11-13 opt: takipçinin tür etiketi önbelleği (girdi + G.Buyuk işlevi) ve diğer görev satırının ara rengi
local turEtiket = { girdi = nil, fn = false, cikti = nil }
local digerRenk = Color(0, 0, 0, 190)

local function HedefSatiri(h, x, y, w, alfa, renk)
     local font = F(15, "govde")
     -- 11-13 opt: bu çağrıda tekrarlanan O(n) değerleri bir kez okunur (O saf; ScrH çağrı içinde değişmez)
     local o6, o10, o19, o20 = O(6), O(10), O(19), O(20)
     local kutuY = y + o10
     -- durum baklavası
     if h.tamam then
          G.Baklava(x + o6, kutuY, O(5), R.yesil, 230 * alfa)
     else
          G.Baklava(x + o6, kutuY, O(5), renk, 230 * alfa, false)
     end

     local metin = h.metin or ""
     if h.gerek and h.gerek > 1 and not h.sureli then metin = metin .. "  (" .. (h.sayi or 0) .. "/" .. h.gerek .. ")" end
     if h.sureli then
          local kalan = math.max(0, h.sureli - CurTime())
          metin = metin .. "  " .. string.FormattedTime(kalan, "%02i:%02i")
     end
     if h.istege then metin = metin .. "  · opcional" end

     local satirlar = G.Sar(metin, font, w - O(48))
     local yeni = h.yeni and (RealTime() - h.yeni) < 2.5
     local metinRenk = h.tamam and R.soluk or (yeni and R.altinAcik or R.govde)
     for i, s in ipairs(satirlar) do
          G.Yaz(s, font, x + o20, y + o10 + (i - 1) * o19, metinRenk, 0, nil, 0.9, alfa)
     end

     -- uzaklık
     local nokta = not h.tamam and G.IsaretNoktasi(h.isaret)
     if nokta then
          G.Yaz(Metre(LocalPlayer():GetPos():Distance(nokta)), F(13, "govde"), x + w, y + o10, R.soluk, 2, nil, 0.8, alfa)
     end
     return #satirlar * o19 + o6
end

local function TakipciCiz()
     local g = G.Takipte()
     -- Legacy HUD'un büyük bölge kartı soldaki aynı yeri kullanıyor; o sürede takipçi söner
     local H = SardonHUD
     local bolgeKarti = H and H.BolgeKartiAcik and H.BolgeKartiAcik()
     local hedef = g and not Gizli() and not bolgeKarti and 1 or 0
     takipAlfa = math.Approach(takipAlfa, hedef, FrameTime() * 3)
     if takipAlfa <= 0.01 or not g then return end
     local a = takipAlfa

     local x, y, w = O(28), O(240), O(380)
     -- Legacy'nin sol üst kümesi (altıgen + durum şeridi) uzarsa takipçi altına iner
     if H and H.LegacySecili and H.LegacySecili() and H.Legacy and H.Legacy.SolUstAlt then
          y = math.max(y, H.Legacy.SolUstAlt + O(22))
     end
     local renk = G.TurRenk(g.tur)
     -- 11-13 opt: bu çağrıda tekrarlanan O(n) değerleri bir kez okunur
     local o5, o6, o18 = O(5), O(6), O(18)

     -- arka gölge
     surface.SetMaterial(G.Mat.gradL)
     surface.SetDrawColor(0, 0, 0, 120 * a)
     surface.DrawTexturedRect(0, y - O(16), w + O(120), O(200))
     draw.NoTexture()

     G.Baklava(x + o5, y + o6, o5, renk, 255 * a)
     -- 11-13 opt: G.Buyuk yalnız tür adı ya da G.Buyuk değişince çağrılır (saf işlev; aynı girdi aynı çıktı)
     local turAd = G.Tur(g.tur).ad
     local te = turEtiket
     if te.fn ~= G.Buyuk or te.girdi ~= turAd then te.girdi, te.fn, te.cikti = turAd, G.Buyuk, G.Buyuk(turAd) end
     G.Yaz(te.cikti, F(12, "kalin"), x + o18, y + o6, renk, 0, O(2), 0.8, a)
     G.Yaz(g.ad or "", F(22, "baslik"), x, y + O(32), R.fildisi, 0, nil, 1, a)
     local cy = y + O(48)
     if g.adim and g.adim ~= "" then
          G.Yaz(g.adim, F(13, "italik"), x, cy + O(8), R.soluk, 0, nil, 0.8, a)
          cy = cy + O(18)
     end
     G.AltinCizgi(x, cy + O(4), w, 170 * a, renk)
     cy = cy + O(12)

     for _, h in ipairs(g.hedefler or {}) do
          cy = cy + HedefSatiri(h, x, cy, w, a, renk)
     end

     -- diğer aktif görevler
     local digerleri = 0
     local o14, o20 = O(14), O(20)   -- 11-13 opt: döngüde tekrarlanan O(n)
     for _, d in ipairs(G.D.gorevler or {}) do
          if d ~= g and not d.gizli then
               digerleri = digerleri + 1
               if digerleri <= 2 then
                    local dr = G.TurRenk(d.tur)
                    G.Baklava(x + o6, cy + o14, O(3), dr, 160 * a)
                    -- 11-13 opt: Color(dr.r, dr.g, dr.b, 190) yerine ara renk (G.Yaz yalnız okur, saklamaz)
                    G.Yaz(d.ad or "", F(14, "govde"), x + o18, cy + o14, RenkDoldur(digerRenk, dr.r, dr.g, dr.b, 190), 0, nil, 0.7, a)
                    cy = cy + o20
               end
          end
     end
     if digerleri > 2 then
          G.Yaz("+" .. (digerleri - 2) .. " misiones más  ·  " .. G.GunlukTusAdi(), F(12, "govde"), x + o18, cy + o14, R.soluk, 0, nil, 0.7, a)
          cy = cy + o20
     end
     -- [sardon] huds sol bildirimleri bu kenarın altında kalır (cl_legacy_5bildirim)
     G.TakipciAlt, G.TakipciKare = cy + O(24), FrameNumber()
end

/*
*   Afiş ve bildirimler
*/
local function AfisCiz()
     local t = G.Afis
     if not t then return end
     local gecen = RealTime() - t.bas
     if gecen > t.sure then G.Afis = nil return end
     local a = math.min(G.Yumusak(gecen / 0.6), G.Yumusak((t.sure - gecen) / 0.8))
     -- rol dışı duyuru bandı ([sardon] duyuru) üst ortadayken afiş onun altına iner (yokken Alt() = 0, konum aynı)
     local duyuruAlt = SardonDuyuru and SardonDuyuru.Alt and SardonDuyuru.Alt() or 0
     local cx, y = ScrW() / 2, math.max(O(150), duyuruAlt + O(30))
     local renk = t.renk or R.altin
     -- 11-13 opt: bu çağrıda tekrarlanan O(n) değerleri bir kez okunur
     local o5, o22, o34, o64 = O(5), O(22), O(34), O(64)

     -- ışık
     G.Parilti(cx, y + o34, O(620), renk, 40 * a)
     local acil = G.Yumusak(gecen / 1.1)
     G.AltinCizgi(cx - O(300) * acil, y + O(4), O(600) * acil, 220 * a, renk)

     G.Yaz(t.ust or "", F(14, "kalin"), cx, y - O(12), renk, 1, o5, 0.9, a)
     G.Yaz(t.baslik or "", F(40, "baslik"), cx, y + o34, R.fildisiAcik, 1, O(1), 1, a)
     G.Baklava(cx, y + o64, o5, renk, 255 * a)
     G.AltinCizgi(cx - O(220) * acil, y + o64, O(440) * acil, 150 * a, renk)

     local yy = y + O(86)
     if t.alt and t.alt ~= "" then
          for _, s in ipairs(G.Sar(t.alt, F(17, "italik"), O(720))) do
               G.Yaz(s, F(17, "italik"), cx, yy, R.govde, 1, nil, 0.9, a)
               yy = yy + o22
          end
     end
     if t.oduller and #t.oduller > 0 then
          yy = yy + O(8)
          G.Yaz("RECOMPENSAS", F(12, "kalin"), cx, yy, R.altin, 1, O(3), 0.8, a)
          yy = yy + o22
          G.Yaz(table.concat(t.oduller, "   ◆   "), F(16, "kalin"), cx, yy, R.fildisi, 1, nil, 0.9, a)
     end
end

local BILDIRIM_RENK = { hedef = "yesil", ilerleme = "altin", odul = "altinAcik", uyari = "kirmizi", ipucu = "gumus", bilgi = "govde" }

local function BildirimCiz()
     local cx = ScrW() / 2
     local duyuruAlt = SardonDuyuru and SardonDuyuru.Alt and SardonDuyuru.Alt() or 0
     local y = G.Afis and (O(330) + math.max(0, duyuruAlt + O(30) - O(150))) or math.max(O(96), duyuruAlt + O(18))
     -- sinema şeridi varken altında kalmasın
     if G.Sinematik and G.Sinematik() then y = math.max(y, math.Round(ScrH() * 0.11) + O(18)) end
     for i = #G.Bildirimler, 1, -1 do
          local b = G.Bildirimler[i]
          if RealTime() - b.bas > b.sure then table.remove(G.Bildirimler, i) end
     end
     local o8, o22 = O(8), O(22)   -- 11-13 opt: döngüde tekrarlanan O(n) bir kez
     for _, b in ipairs(G.Bildirimler) do
          local gecen = RealTime() - b.bas
          local a = math.min(G.Yumusak(gecen / 0.3), G.Yumusak((b.sure - gecen) / 0.5))
          local renk = R[BILDIRIM_RENK[b.tur] or "govde"]
          local font = F(16, b.tur == "ipucu" and "italik" or "kalin")
          local metin = b.metin or ""
          if b.tur == "hedef" then metin = "✓  " .. metin end
          if b.tur == "ilerleme" and b.gerek then metin = metin .. "  " .. (b.sayi or 0) .. "/" .. b.gerek end
          local satirlar = G.Sar(metin, font, O(640))
          local w = 0
          for _, s in ipairs(satirlar) do w = math.max(w, G.Genislik(s, font)) end
          w = w + O(56)
          local h = #satirlar * o22 + O(16)
          G.Pano(cx - w / 2, y, w, h, a * 0.95)
          G.Baklava(cx - w / 2 + O(18), y + h / 2, O(4), renk, 255 * a)
          for j, s in ipairs(satirlar) do
               G.Yaz(s, font, cx + o8, y + o8 + (j - 0.5) * o22, renk, 1, nil, 0.8, a)
          end
          y = y + (h + o8) * a
     end
end

/*
*   Ekrandaki hedef işareti
*/
local function IsaretCiz()
     local g = G.Takipte()
     local h = TakipHedefi(g)
     if not h then return end
     local nokta, aktorMu = G.IsaretNoktasi(h.isaret)
     if not nokta then return end

     local lp = LocalPlayer()
     local d = lp:GetPos():Distance(nokta)
     if aktorMu and d < 260 then return end
     -- hedef bölgesine girince ekran işareti çekilsin (ışık sütunu ve halka kalır)
     if not aktorMu and d < math.min(h.isaret.r or 150, 300) then return end
     local renk = G.TurRenk(g.tur)
     local W, H = ScrW(), ScrH()
     local e = nokta:ToScreen()
     local onde = (nokta - lp:EyePos()):Dot(lp:GetAimVector()) > 0
     local kenar = O(60)

     local x, y = e.x, e.y
     local disarida = not onde or x < kenar or x > W - kenar or y < kenar or y > H - kenar
     if disarida then
          -- ekranın kenarına yapıştır, yön oku
          local yon = Vector(x - W / 2, y - H / 2, 0)
          if not onde then yon = -yon end
          if yon:LengthSqr() < 1 then yon = Vector(0, 1, 0) end
          yon:Normalize()
          local olcek = math.min((W / 2 - kenar) / math.max(math.abs(yon.x), 0.001), (H / 2 - kenar) / math.max(math.abs(yon.y), 0.001))
          x, y = W / 2 + yon.x * olcek, H / 2 + yon.y * olcek
          -- soldaki takipçinin üstüne binmesin
          if takipAlfa > 0.05 and x < O(440) and y > O(200) and y < O(470) then x = O(440) end
          local aci = math.deg(math.atan2(yon.y, yon.x))
          local u = O(14)
          local ok = {
               { x = x + math.cos(math.rad(aci)) * u * 1.6, y = y + math.sin(math.rad(aci)) * u * 1.6 },
               { x = x + math.cos(math.rad(aci + 140)) * u, y = y + math.sin(math.rad(aci + 140)) * u },
               { x = x + math.cos(math.rad(aci - 140)) * u, y = y + math.sin(math.rad(aci - 140)) * u },
          }
          surface.SetDrawColor(renk.r, renk.g, renk.b, 220)
          draw.NoTexture()
          surface.DrawPoly(ok)
     end

     local nab = 0.8 + 0.2 * math.sin(RealTime() * 3)
     G.Parilti(x, y, O(64), renk, 70 * nab)
     G.Baklava(x, y, O(10), R.zeminKoyu, 220)
     G.Baklava(x, y, O(8), renk, 255)
     G.Baklava(x, y, O(3), R.zeminKoyu, 255)
     G.Yaz(Metre(d), F(13, "kalin"), x, y + O(20), R.fildisi, 1, nil, 0.9)
end

/*
*   İstemler: E ile konuş, topla, incele
*/
-- 11-13 opt: tuş kutusunun sabit zemin rengi (her karede Color() yok; G.Kutu yalnız okur)
local ISTEM_ZEMIN = Color(11, 19, 17, 220)

local function Istem(tus, metin, ilerleme)
     local cx, y = ScrW() / 2, ScrH() / 2 + O(70)
     local font = F(16, "kalin")
     local tw = G.Genislik(metin, font)
     local kw = O(30)
     local o12 = O(12)   -- 11-13 opt: iki kez kullanılan O(12) bir kez
     local w = kw + o12 + tw
     local x = cx - w / 2
     G.Kutu(x, y - kw / 2, kw, kw, ISTEM_ZEMIN)
     G.Cerceve(x, y - kw / 2, kw, kw, R.altin, 1)
     G.Yaz(tus, F(15, "cokKalin"), x + kw / 2, y, R.altinAcik, 1)
     G.Yaz(metin, font, x + kw + o12, y, R.fildisi, 0, nil, 1)
     if ilerleme then
          local o3, o6 = O(3), O(6)   -- 11-13 opt: iki kez kullanılanlar bir kez
          surface.SetDrawColor(R.cizgi.r, R.cizgi.g, R.cizgi.b, 160)
          surface.DrawRect(x, y + kw / 2 + o6, w, o3)
          surface.SetDrawColor(R.altinAcik.r, R.altinAcik.g, R.altinAcik.b, 255)
          surface.DrawRect(x, y + kw / 2 + o6, w * ilerleme, o3)
     end
end

/*
*   Toplanacak nesneler (yalnız görevin sahibine)
*/
G.Nesneler = G.Nesneler or {}   -- [gorevNo .. ":" .. no] = n

function G.NesneKaldir(gorev, no)
     local k = gorev .. ":" .. no
     local n = G.Nesneler[k]
     if n and IsValid(n.ent) then n.ent:Remove() end
     G.Nesneler[k] = nil
end

function G.NesneleriTemizle(gorev)
     for k, n in pairs(G.Nesneler) do
          if not gorev or n.gorev == gorev then
               if IsValid(n.ent) then n.ent:Remove() end
               G.Nesneler[k] = nil
          end
     end
end

function G.NesneEkle(gorev, n)
     n.gorev = gorev
     n.bas = RealTime()
     G.NesneKaldir(gorev, n.no)
     local model = (isstring(n.model) and file.Exists(n.model, "GAME")) and n.model or "models/props_lab/jar01a.mdl"
     n.ent = ClientsideModel(model, RENDERGROUP_OPAQUE)
     if IsValid(n.ent) then n.ent:SetPos(n.pos + Vector(0, 0, 20)) end
     G.Nesneler[gorev .. ":" .. n.no] = n
end

local yakinNesne, etkilesimHedef, etkilesimBas = nil, nil, nil

hook.Add("Think", "SardonGorev.Nesne", function()
     yakinNesne = nil
     local lp = LocalPlayer()
     if not IsValid(lp) then return end
     local pp = lp:GetPos()
     local t = RealTime()
     for _, n in pairs(G.Nesneler) do
          if IsValid(n.ent) then
               local z = 26 + math.sin(t * 2 + n.no) * 4
               n.ent:SetPos(n.pos + Vector(0, 0, z))
               n.ent:SetAngles(Angle(0, (t * 40 + n.no * 37) % 360, 0))
               if pp:DistToSqr(n.pos) < 90 * 90 then yakinNesne = n end
          end
     end

     -- incele (E basılı tut)
     etkilesimHedef = nil
     for _, gg in ipairs(G.D.gorevler or {}) do
          for _, h in ipairs(gg.hedefler or {}) do
               local is = h.isaret
               if not h.tamam and is and is.etkilesim and isvector(is.pos) and pp:DistToSqr(is.pos) < (is.r or 70) ^ 2 then
                    etkilesimHedef = { g = gg, h = h }
               end
          end
     end
     if etkilesimHedef and lp:KeyDown(IN_USE) and not G.Bakilan and not yakinNesne then
          etkilesimBas = etkilesimBas or t
          if t - etkilesimBas >= (etkilesimHedef.h.isaret.etkilesim.sure or 2.5) then
               local gg, h = etkilesimHedef.g, etkilesimHedef.h
               G.Iste(G.ISTEK.ETKILESIM, function()
                    net.WriteUInt(gg.no or 0, 32)
                    net.WriteUInt(h.i or 0, 8)
               end)
               h.tamam = true
               etkilesimBas = nil
               G.Cal("ilerleme")
          end
     else
          etkilesimBas = nil
     end
end)

hook.Add("KeyPress", "SardonGorev.Nesne", function(ply, tus)
     if tus ~= IN_USE or ply ~= LocalPlayer() or not IsFirstTimePredicted() or not yakinNesne or G.Bakilan then return end
     local n = yakinNesne
     G.Iste(G.ISTEK.TOPLA, function()
          net.WriteUInt(n.gorev, 32)
          net.WriteUInt(n.no, 16)
     end)
     sound.Play("items/ammo_pickup.wav", n.pos, 60, 110, 0.6)
     G.AktorEfekt(n.pos + Vector(0, 0, 10), "isik")
end)

/*
*   Dünyada: ışık sütunu, halka, nesne parıltısı
*/
local matIsin = Material("effects/lamp_beam")
local matHalka = Material("effects/select_ring")
local matParilti = Material("sprites/light_glow02_add")
-- 11-13 opt: kare başı sabit vektörler / renk (yalnız işlenen ya da render.* girdisi; hiç değiştirilmez)
-- ve değişken saydamlıklı renkler için tek ara renk (render.* çağrıları sırayla, renk saklanmaz)
local ISIN_ALT, ISIN_UST, ISIN_PARILTI = Vector(0, 0, 2), Vector(0, 0, 340), Vector(0, 0, 8)
local HALKA_UST, HALKA_NORMAL, NESNE_UST = Vector(0, 0, 3), Vector(0, 0, 1), Vector(0, 0, 6)
local NESNE_PARILTI = Color(255, 230, 170, 160)
local dunyaRenk = Color(255, 255, 255)

hook.Add("PostDrawTranslucentRenderables", "SardonGorev.Dunya", function(_, gok)
     if gok then return end
     local lp = LocalPlayer()
     if not IsValid(lp) then return end
     local t = RealTime()

     if not Gizli() then
          local g = G.Takipte()
          local h = TakipHedefi(g)
          if h and h.isaret and isvector(h.isaret.pos) and not h.isaret.aktor then
               local p = h.isaret.pos
               local d = lp:GetPos():Distance(p)
               if d < 6000 and d > 40 then
                    local renk = G.TurRenk(g.tur)
                    local a = math.Clamp(d / 400, 0.25, 1)
                    render.SetMaterial(matIsin)
                    render.DrawBeam(p + ISIN_ALT, p + ISIN_UST, 46, 0, 0.98, RenkDoldur(dunyaRenk, renk.r, renk.g, renk.b, 90 * a))
                    render.SetMaterial(matParilti)
                    render.DrawSprite(p + ISIN_PARILTI, 90, 50, RenkDoldur(dunyaRenk, renk.r, renk.g, renk.b, 140 * a))
                    local r = math.Clamp(h.isaret.r or 120, 40, 900)
                    render.SetMaterial(matHalka)
                    render.DrawQuadEasy(p + HALKA_UST, HALKA_NORMAL, r * 2, r * 2, RenkDoldur(dunyaRenk, renk.r, renk.g, renk.b, 120 + 40 * math.sin(t * 2)), (t * 12) % 360)
               end
          end
     end

     for _, n in pairs(G.Nesneler) do
          if n.parilti ~= false and IsValid(n.ent) then
               render.SetMaterial(matParilti)
               render.DrawSprite(n.ent:GetPos() + NESNE_UST, 48 + 8 * math.sin(t * 3 + n.no), 48, NESNE_PARILTI)
          end
     end
end)

/*
*   Çizim
*/
-- 11-13 opt: istem metinleri (a .. b) girdi değişmedikçe yeniden birleştirilmez (yer başına son girdi / çıktı);
-- dize olmayan girdi önbelleğe girmez
local istemMetin = { {}, {}, {} }
local function Birlestir(yer, a, b)
     if not isstring(a) or not isstring(b) then return a .. b end
     local t = istemMetin[yer]
     if t.a ~= a or t.b ~= b then t.a, t.b, t.s = a, b, a .. b end
     return t.s
end

hook.Add("HUDPaint", "SardonGorev.HUD", function()
     if not IsValid(LocalPlayer()) then return end
     local gizli = Gizli()
     if not gizli then
          TakipciCiz()
          IsaretCiz()
          if G.Bakilan and not (G.DiyalogAcik and G.DiyalogAcik()) and not hook.Run("SardonGorevKonusGizle", G.Bakilan) then
               Istem("E", Birlestir(1, "Hablar con ", G.Bakilan.veri.ad or ""))
          elseif yakinNesne then
               Istem("E", Birlestir(2, "Recoger · ", yakinNesne.ad or "Objeto"))
          elseif etkilesimHedef then
               local is = etkilesimHedef.h.isaret
               local il = etkilesimBas and math.Clamp((RealTime() - etkilesimBas) / (is.etkilesim.sure or 2.5), 0, 1) or nil
               Istem("E", Birlestir(3, is.etkilesim.eylem or "Examinar", " (mantener pulsado)"), il)
          end
     else
          takipAlfa = 0
     end
     AfisCiz()
     BildirimCiz()
end)

function G.GunlukTusAdi()
     local tus = SardonConfig and SardonConfig.Options and SardonConfig.Options.gorev_gunluk and SardonConfig:Get("gorev_gunluk") or KEY_M
     return string.upper(input.GetKeyName(tus) or "M")
end
